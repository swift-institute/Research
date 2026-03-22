# Nonsending Compiler Patterns

<!--
---
version: 1.0.0
last_updated: 2026-03-22
status: RECOMMENDATION
tier: 2
trigger: Discovery — explore how the Swift compiler uses nonisolated(nonsending) internally to extract patterns applicable to our ecosystem
---
-->

## Context

The Swift Institute ecosystem has adopted `nonisolated(nonsending)` across several primitives (see `nonsending-adoption-audit.md`, `callback-isolated-nonsending-design.md`). Our adoption is informed by Point-Free #355 and our own experiments but has not systematically examined how the Swift compiler and stdlib themselves use the feature internally.

The Swift compiler source at `/Users/coen/Developer/swiftlang/swift` is the canonical reference for `nonisolated(nonsending)` semantics. By studying the compiler's type system representation, the stdlib's API migration patterns, and the test suite's edge cases, we can validate our existing patterns and discover opportunities we missed.

## Question

What patterns does the Swift compiler use for `nonisolated(nonsending)` that are applicable to our ecosystem, and where do our current patterns diverge from the compiler's canonical usage?

## Analysis

### 1. The `isolation:` Parameter is Deprecated

The stdlib has moved away from `isolation: isolated (any Actor)? = #isolation` parameters in favor of `nonisolated(nonsending)` on the function itself.

**Stdlib pattern** (`CheckedContinuation.swift:304-332`):

```swift
// NEW — primary API
@_disfavoredOverload  // (on the deprecated one, not this)
public nonisolated(nonsending) func withCheckedContinuation<T>(
    function: String = #function,
    _ body: (CheckedContinuation<T, Never>) -> Void
) async -> sending T

// OLD — deprecated
@_disfavoredOverload
@available(*, deprecated, message: "Replaced by nonisolated(nonsending) overload")
public func withCheckedContinuation<T>(
    isolation: isolated (any Actor)?,
    function: String = #function,
    _ body: (CheckedContinuation<T, Never>) -> Void
) async -> sending T
```

This pattern is replicated identically across:
- `withCheckedThrowingContinuation` (`CheckedContinuation.swift:392`)
- `withUnsafeContinuation` (`PartialAsyncTask.swift:898`)
- `withUnsafeThrowingContinuation` (`PartialAsyncTask.swift:950`)
- `withTaskCancellationHandler` (`TaskCancellation.swift:77`)
- `withTaskPriorityEscalationHandler` (`Task+PriorityEscalation.swift:111`)

**Our current pattern** — `Async.Callback`:

```swift
// Our API — uses the deprecated isolation: parameter
public func callAsFunction(
    isolation: isolated (any Actor)? = #isolation
) async -> Value {
    await operation()
}
```

**Gap**: Our `Async.Callback.callAsFunction(isolation:)` uses the pattern the stdlib has deprecated. The stored `operation` closure is already `nonisolated(nonsending)`, so `callAsFunction` itself should be `nonisolated(nonsending)` — no `isolation:` parameter needed.

**Why the stdlib deprecated it**: The `isolation:` parameter approach has two problems:
1. It's an **implementation detail** visible in the API surface (callers must see `#isolation` in signatures)
2. It requires an extra parameter slot, complicating overload resolution

With `nonisolated(nonsending)`, the compiler inserts an implicit `Builtin.ImplicitActor` parameter at the SIL level (`SILGenConcurrency.cpp:77-90`). The caller's isolation is propagated automatically — no visible API parameter.

### 2. `sending` Return Types

The stdlib pairs `nonisolated(nonsending)` with `-> sending T` when the returned value will cross isolation boundaries:

```swift
public nonisolated(nonsending) func withCheckedContinuation<T>(...) async -> sending T
```

**Semantic**: `sending T` means the return value is **disconnected from any actor's isolation region**. The region checker (`RegionAnalysis.cpp`) verifies the value doesn't carry references to actor-isolated state.

**Representation**: Bit 14 in `ASTExtInfoBuilder` (`ExtInfo.h:539`):

```cpp
SendingResultMask = 1 << 14
```

**Where applicable in our ecosystem**:
- `Async.Callback.callAsFunction()` — returns `Value` which is produced within the caller's isolation domain. Since the callback is `nonisolated(nonsending)`, the value is produced and consumed within the same isolation. `sending` is NOT needed here — the value never crosses a boundary.
- `Async.Callback.init(wrapping:)` — the CPS bridge. Here `Value: Sendable` is already constrained because the CPS completion fires on an arbitrary thread. `sending` would be redundant but semantically correct.

**Takeaway**: Our ecosystem's `Async.Callback` does NOT need `sending` return types because its design keeps values within the caller's isolation domain. The stdlib uses `sending` because continuations are inherently cross-isolation (the continuation body may resume from any thread).

### 3. No `@concurrent` in the Stdlib

Searching the entire `stdlib/public/Concurrency/` directory reveals **zero uses of `@concurrent`**. The stdlib uses:
- `nonisolated(nonsending)` for functions that should inherit caller isolation
- Unmodified `nonisolated` for functions that must hop to the generic executor
- Actor isolation for functions that must run on a specific executor

**Implication for our `concurrent-expansion-audit.md`**: The stdlib's absence of `@concurrent` suggests it's intended as an explicit opt-out for user code, not a standard annotation. Our audit found 8 `@concurrent` sites in `IO.Blocking.Lane` — these are correct (thread pool dispatch is a genuine executor change) but `@concurrent` should remain rare and exceptional.

### 4. The Implicit Actor Parameter (SIL Level)

The compiler transforms `nonisolated(nonsending)` functions by adding an implicit parameter:

```
@sil_isolated @sil_implicit_leading_param @guaranteed Builtin.ImplicitActor
```

This parameter carries the caller's isolation context. At call sites:
1. The caller's actor is captured into this parameter
2. At suspension points, `hop_to_executor` instructions ensure the function returns to the caller's executor
3. Consecutive calls to nonsending functions with the same actor can DCE redundant hops (`optimize_hop_to_executor.sil:320-372`)

**Implication**: This confirms our `callAsFunction` workaround for issue #83812. When `map` calls `await self()` (a method call), the compiler generates a proper thunk that preserves the implicit actor parameter. When `map` calls `self.operation()` (stored closure), the implicit parameter is NOT forwarded — confirming the bug.

### 5. Operation Closure Pattern

The `withTaskCancellationHandler` function demonstrates a double-nonsending pattern:

```swift
public nonisolated(nonsending) func withTaskCancellationHandler<Return, Failure>(
    operation: nonisolated(nonsending) () async throws(Failure) -> Return,
    onCancel handler: sending () -> Void
) async throws(Failure) -> Return
```

Both the outer function AND its `operation` closure are `nonisolated(nonsending)`. The `onCancel` handler is `sending` (not nonsending) because it fires from the runtime's cancellation machinery on an arbitrary executor.

**Pattern**: When a function takes an operation closure that should inherit caller isolation, both the function and the closure parameter should be `nonisolated(nonsending)`. When a callback fires from external/arbitrary context, use `sending`.

**Our ecosystem parallel**: `Async.Callback.init(_:)` already takes a `nonisolated(nonsending) @escaping () async -> Value` closure. The function itself (the init) is synchronous, so it cannot be `nonisolated(nonsending)` (sync restriction). The stored closure IS properly annotated. This is correct.

### 6. Function Type Conversion Lattice

The test suite (`attr_execution/conversions.swift:21-163`) documents the conversion rules:

| From → To | Allowed? | Sendable Required? |
|-----------|----------|-------------------|
| `nonisolated(nonsending)` → `@concurrent` | Yes (downcast) | No |
| `@concurrent` → `nonisolated(nonsending)` | Yes (upcast) | No |
| `@MainActor` → `nonisolated(nonsending)` | Yes | No |
| `nonisolated(nonsending)` → `@MainActor` | Yes | Yes (crosses boundary) |
| `nonisolated(nonsending)` → `@isolated(any)` | No | — |
| `@concurrent` → `@isolated(any)` | No | — |

**Key insight**: `nonisolated(nonsending)` and `@concurrent` are freely interconvertible because nonsending is a subset of nonisolated. But converting TO a specific actor isolation requires Sendable because the value crosses an isolation boundary.

**Implication for our ecosystem**: When our code converts between closure types (e.g., in `pullback` transforms), the closures stay within the same isolation domain. The conversion lattice confirms that plain (non-`@Sendable`) closures within nonsending context are safe — no Sendable checking needed. This validates `non-sendable-strategy-isolation-design.md`'s recommendation.

### 7. The Conformance Trap (Compiler Evidence)

The compiler test `nonisolated_nonsending_by_default.swift:12-24` directly demonstrates the conformance trap:

```swift
protocol TestWitnessFixIts {
    func test(_: @concurrent () async -> Void)
}

struct Test: TestWitnessFixIts {
    func test(_: () async -> Void) {}
    // Error: nonisolated(nonsending) doesn't match @concurrent
}
```

Under `NonisolatedNonsendingByDefault`, the implementation's parameter is implicitly `nonisolated(nonsending)`, but the protocol (compiled without the feature) requires `@concurrent`. The witness thunk mediates this mismatch (`protocols_silgen.swift:21-168`).

**Implication**: Our `isolation-preserving-entry-point-api.md` already discovered this and solved it with direct `next(isolation:)` implementation. The compiler evidence confirms this is the correct approach — the witness thunk handles the protocol/implementation mismatch, but only when the `next(isolation:)` overload is used (which bypasses the trap entirely).

### 8. `#isolation` Returns nil in Detached Tasks

The runtime test `isolated_macro_in_nonisolated_nonsending_func.swift:56-74` confirms:

```swift
nonisolated(nonsending) func foo() async {
    let outerIsolation = #isolation  // Returns caller's actor

    await Task {
        let iso = #isolation  // Returns nil — NOT inherited
    }.value
}
```

**Implication**: `nonisolated(nonsending)` isolation does NOT propagate into `Task {}`. This confirms our design decision in `Async.Callback` to NOT include `.async(isolation:_:)` — that factory used `Task {}`, which severs isolation.

### 9. ObjC Interop Forces Nil Isolation

The test `nonisolated_nonsending_objc.swift:27-47` shows that ObjC callbacks lose isolation context because the C ABI cannot represent the implicit actor parameter. The bridge thunk creates a nil `Builtin.ImplicitActor`.

**Implication**: Our `Async.Callback.init(wrapping:)` CPS bridge correctly constrains `Value: Sendable` for this reason — CPS completions from OS/ObjC callbacks fire without isolation context. The bridge wraps via `withCheckedContinuation`, which is itself `nonisolated(nonsending)` and handles the nil isolation case.

## Outcome

**Status**: RECOMMENDATION

### Findings Summary

| # | Finding | Impact | Action |
|---|---------|--------|--------|
| 1 | `isolation:` parameter deprecated in stdlib | Our `Async.Callback.callAsFunction(isolation:)` uses the deprecated pattern | **Migrate**: replace with `nonisolated(nonsending)` on `callAsFunction()` |
| 2 | `sending` return types for cross-isolation values | Our values stay within caller isolation — not applicable | None |
| 3 | No `@concurrent` in stdlib | Confirms `@concurrent` is exceptional, not standard | Validates our audit |
| 4 | Implicit actor parameter at SIL level | Explains why method calls propagate isolation but stored closures don't (#83812) | Documents root cause |
| 5 | Double-nonsending pattern (function + closure param) | Our `Async.Callback.init` closure is already correct | None |
| 6 | Conversion lattice allows nonsending ↔ concurrent | Plain closures in nonsending context are safe | Validates Strategy non-Sendable design |
| 7 | Conformance trap is known, tested in compiler | `next(isolation:)` is the correct workaround | Validates our approach |
| 8 | `#isolation` is nil in `Task {}` | Confirms our `.async` removal was correct | None |
| 9 | ObjC forces nil isolation | CPS bridge correctly requires Sendable | Validates init(wrapping:) |

### Recommended Action: Migrate `Async.Callback.callAsFunction`

The primary actionable finding is #1. Our `callAsFunction(isolation:)` should be replaced with a `nonisolated(nonsending)` method:

**Current** (deprecated pattern):
```swift
public func callAsFunction(
    isolation: isolated (any Actor)? = #isolation
) async -> Value {
    await operation()
}
```

**Proposed** (compiler-canonical pattern):
```swift
public nonisolated(nonsending) func callAsFunction() async -> Value {
    await operation()
}
```

Benefits:
- Removes `isolation:` implementation detail from public API
- Aligns with stdlib's canonical direction
- The compiler's implicit actor parameter handles isolation propagation automatically
- Simplifies `map`/`flatMap` — `await self()` still works, and may even resolve #83812 if the compiler generates proper thunks for the implicit parameter

Risk: Requires verifying that the `nonisolated(nonsending)` method annotation works identically to `isolation: #isolation` for our use cases — specifically that `map`'s internal `await self()` call still propagates isolation. This should be validated with an experiment before production migration.

### Secondary Finding: Migration Pattern

If we do migrate, the stdlib's three-layer deprecation pattern is directly applicable:

1. **New API**: `nonisolated(nonsending) func callAsFunction() async -> Value`
2. **Deprecated overload**: `@_disfavoredOverload @available(*, deprecated) func callAsFunction(isolation:) async -> Value`
3. **Both call the same stored `operation` closure**

However, since we control all consumers and this is Layer 1 infrastructure, a clean break (remove old, add new) is more appropriate than the stdlib's backwards-compatibility approach. Our `callback-isolated-nonsending-design.md` already established that source-incompatible changes are acceptable for fundamental semantic shifts.

## References

### Compiler Source (swiftlang/swift)

| Component | File | Key Lines |
|-----------|------|-----------|
| Type system representation | `include/swift/AST/ExtInfo.h` | 50-107 (FunctionTypeIsolation::Kind), 519-605 (bitfield) |
| Declaration attribute | `include/swift/AST/AttrKind.h` | 123-128 (NonIsolatedModifier) |
| Type repr | `include/swift/AST/TypeRepr.h` | 1266-1290 (CallerIsolatedTypeRepr) |
| Isolation inference | `lib/Sema/TypeCheckConcurrency.cpp` | 5081-5103, 6170-6245 |
| Function type encoding | `lib/Sema/TypeCheckConcurrency.cpp` | 7907-7979 |
| SILGen executor setup | `lib/SILGen/SILGenConcurrency.cpp` | 77-90 |
| Hop optimization | `lib/SILOptimizer/Mandatory/OptimizeHopToExecutor.cpp` | 120-139 |
| Region analysis | `lib/SILOptimizer/Analysis/RegionAnalysis.cpp` | 71-83 |

### Stdlib Patterns

| API | File | Pattern |
|-----|------|---------|
| withCheckedContinuation | `stdlib/public/Concurrency/CheckedContinuation.swift:304` | `nonisolated(nonsending)` + `-> sending T` |
| withTaskCancellationHandler | `stdlib/public/Concurrency/TaskCancellation.swift:77` | double-nonsending (func + closure) |
| withSerialExecutor | `stdlib/public/Concurrency/Executor.swift:133` | nonsending closure parameter |
| Deprecation pattern | `stdlib/public/Concurrency/CheckedContinuation.swift:315-332` | `@_disfavoredOverload` + `@backDeployed` |

### Test Patterns

| Test | File | Pattern |
|------|------|---------|
| Reabstraction thunks | `test/Concurrency/nonisolated_nonsending.swift:9-47` | Partial application preserves implicit actor |
| Conformance trap | `test/Concurrency/attr_execution/nonisolated_nonsending_by_default.swift:12-24` | Protocol/impl mismatch |
| Conversion lattice | `test/Concurrency/attr_execution/conversions.swift:21-163` | nonsending ↔ concurrent rules |
| Runtime isolation | `test/Concurrency/Runtime/isolated_macro_in_nonisolated_nonsending_func.swift:56-74` | #isolation nil in Task {} |
| Witness thunks | `test/Concurrency/attr_execution/protocols_silgen.swift:21-168` | Protocol witness adaptation |

### Internal Research

- `nonsending-adoption-audit.md` — @Sendable site inventory
- `callback-isolated-nonsending-design.md` — Async.Callback redesign (IMPLEMENTED)
- `non-sendable-strategy-isolation-design.md` — Strategy non-Sendable design
- `isolation-preserving-entry-point-api.md` — Conformance trap workaround
- `concurrent-expansion-audit.md` — @concurrent placement
- `swift-institute/Experiments/nonsending-closure-type-constraints/` — Closure type applicability
- `swift-institute/Experiments/stdlib-concurrency-isolation/` — Continuation isolation
