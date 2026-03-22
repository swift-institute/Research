# Async.Callback.Isolated — Nonsending Callback for Dependency Injection

<!--
---
version: 3.1.0
last_updated: 2026-03-22
status: IMPLEMENTED
tier: 2
trigger: nonsending-adoption-audit.md identified Callback as primary dual-mode candidate (P1–P5)
experiment: callback-isolated-prototype (5 approaches, 15 tests — C with callAsFunction confirmed)
implementation:
  commits:
    - swift-async-primitives abddd918: Replace Async.Callback with nonsending direct-style type
    - swift-test-primitives 39f1351: Migrate Snapshot.Strategy to new Async.Callback direct-style API
    - swift-async-primitives db8f4aa3: Add Async.Callback test suite — 23 tests
  files_changed:
    - swift-async-primitives/.../Async.Callback.swift (complete rewrite, 164 → 135 lines)
    - swift-test-primitives/.../Test.Snapshot.Strategy.swift (4 call site migrations)
    - swift-async-primitives/Tests/.../Async.Callback Tests.swift (new, 255 lines)
changelog:
  - 3.1.0: NOTE — nonsending-compiler-patterns.md discovered the stdlib has DEPRECATED
    isolation: parameter overloads in favor of nonisolated(nonsending) on the function itself.
    Our callAsFunction(isolation:) uses the deprecated pattern. Future migration recommended:
    replace with `nonisolated(nonsending) func callAsFunction() async -> Value`.
  - 3.0.0: IMPLEMENTED. Async.Callback replaced in swift-async-primitives. Test.Snapshot.Strategy
    migrated in swift-test-primitives. 23 tests added (11 unit, 7 edge case, 6 integration/isolation).
    All 88 async-primitives tests pass. CPS bridge `init(wrapping:)` provided for legacy callers.
  - 2.1.0: callAsFunction(isolation:) replaces getValue(isolation:). `await callback()` reads
    as intent per [IMPL-INTENT]. 12 subtests (T15a-T15h) all pass. map/flatMap use `await self()`.
  - 2.0.0: Experiment validated. Issue #83812 confirmed — method wrapper required. Replacement
    feasibility assessed (user directive). Approach C (isolated parameter) recommended.
    Implementation sketch revised. Type name recommendation changed from Isolated to replacement.
  - 1.0.0: Initial research — feasibility, type design, API surface, implementation sketch.
---
-->

## Context

The `nonsending-adoption-audit.md` identified `Async.Callback<Value>` as the primary candidate for a nonsending variant. The existing type uses `@Sendable` closures throughout, which is correct for cross-isolation usage (OS callbacks, network completions) but forces unnecessary thread hops for same-isolation usage (dependency injection, deterministic testing).

Point-Free episode #355 ("Beyond Basics: Isolation, ~Copyable, ~Escapable", Feb 23, 2026) demonstrated the pattern: dependency closures marked `nonisolated(nonsending)` inherit the caller's isolation context, enabling synchronous execution from `@MainActor` with no thread hops — the foundation for 100% deterministic testing.

The **prior** `Async.Callback<Value>` (now replaced) had the following CPS-based API surface:

```swift
// REPLACED — shown for reference only
public struct Callback<Value: Sendable>: Sendable {
    public let run: @Sendable (@escaping @Sendable (Value) -> Void) -> Void
    public init(run: @escaping @Sendable (_ callback: @escaping @Sendable (Value) -> Void) -> Void)
    public init(value: Value)
    public func map<NewValue: Sendable>(_ transform: @escaping @Sendable (Value) -> NewValue) -> Callback<NewValue>
    public func flatMap<NewValue: Sendable>(_ transform: @escaping @Sendable (Value) -> Callback<NewValue>) -> Callback<NewValue>
    public var value: Value { get async }
    public static func async(isolation:_:) -> Self
}
```

All five closure sites (P1–P5 in the audit) used `@Sendable`, and `Value` was constrained to `Sendable`. This was correct for cross-isolation usage but prevented isolation-preserving dependency injection.

## Question

What is the optimal design for a nonsending variant of `Async.Callback` that enables isolation-preserving dependency injection?

## Analysis

### 1. Feasibility of @escaping nonisolated(nonsending) Closures

**Status: CONFIRMED WORKING for async closure types.**

Experiment `nonsending-closure-type-constraints` (at `swift-institute/Experiments/nonsending-closure-type-constraints/`) validates:

| Test | Pattern | Result |
|------|---------|--------|
| B1a | `nonisolated(nonsending) @escaping (Int) async -> Int` stored in struct | **Works** |
| B1b | Same closure stored in actor | **Works** |
| B1d | `nonisolated(nonsending)` on sync closure type | **Rejected** — "cannot use 'nonisolated(nonsending)' on non-async function type" |

The experiment code (lines 31–57 of `main.swift`) demonstrates both struct and actor storage:

```swift
struct StoredNonsendingAsync {
    let operation: nonisolated(nonsending) (Int) async -> Int
    init(_ operation: nonisolated(nonsending) @escaping (Int) async -> Int) {
        self.operation = operation
    }
}

actor NonsendingOperatorState {
    let transform: nonisolated(nonsending) (Int) async -> Int
    init(_ transform: nonisolated(nonsending) @escaping (Int) async -> Int) {
        self.transform = transform
    }
}
```

**Critical constraint**: `nonisolated(nonsending)` ONLY applies to **async** function types. The compiler rejects it on sync function types. This eliminates direct translation of the existing CPS-style `Callback.run`.

### 2. Design Divergence: CPS vs Direct Style

The existing `Callback<Value>` uses CPS (continuation-passing style):

```swift
// Existing — CPS style (sync function type)
public let run: @Sendable (@escaping @Sendable (Value) -> Void) -> Void
```

The `run` property is a **synchronous** function that takes a callback. Since sync function types cannot be `nonisolated(nonsending)`, a direct translation to nonsending CPS is impossible.

The isolated variant MUST use **direct async/await style**:

```swift
// Isolated — direct style (async function type)
let operation: nonisolated(nonsending) () async -> Value
```

This is not a limitation — it is the correct design. The Point-Free dependency injection pattern uses direct-style `nonisolated(nonsending)` async closures, not CPS. The async closure inherits the caller's isolation. If the body is synchronous, no suspension occurs — the call completes synchronously on the caller's executor.

| Aspect | Callback (CPS) | Callback.Isolated (Direct) |
|--------|----------------|----------------------------|
| Stored closure type | `@Sendable (() -> Void) -> Void` (sync) | `nonisolated(nonsending) () async -> Value` |
| Execution model | Invoke with callback; callback fires later | `await value` returns directly |
| Isolation | Severs caller isolation (`@Sendable`) | Inherits caller isolation (nonsending) |
| Thread behavior | May fire on any thread | Runs on caller's executor |
| Sendable | Type is `Sendable`; `Value: Sendable` | Type is NOT `Sendable`; `Value` unconstrained |
| Deterministic testing | Requires threading infrastructure | Synchronous from test's isolation domain |

### 3. Type Name Options

#### Option A: `Async.Callback.Isolated<Value>`

Nested inside existing `Callback`, communicating "isolated variant of Callback."

- Per [API-NAME-001]: `Async` (domain) → `Callback` (subdomain) → `Isolated` (variant). Correct Nest.Name form.
- "Isolated" has established meaning in Swift concurrency (`isolated` parameters, actor isolation).
- Clear semantic relationship to the parent type.
- **Problem (D6)**: `Callback<Value: Sendable>` is generic. Nesting inside a generic type requires specifying the outer generic: `Async.Callback<Never>.Isolated<Int>`. The `<Never>` is meaningless — the inner type has its own generic parameter. Experiment T13 confirmed this compiles but is ergonomically poor.

#### Option B: `Async.Callback.Local<Value>`

Same nesting, alternative name.

- "Local" is ambiguous: local variable? local storage? local network?
- Does not leverage established Swift concurrency terminology.
- Same nesting problem as Option A (D6).

#### Option C: Dual-mode `Callback` via Overloads

Add nonsending overloads to the existing `Callback` type.

- **Not possible.** `Callback` is `Sendable` and requires `Value: Sendable`. A nonsending closure cannot be stored in a `Sendable` type. The constraints are mutually exclusive — overloads cannot resolve this.

#### Option D: `Async.IsolatedCallback<Value>`

Separate type at the `Async` namespace level.

- Violates [API-NAME-002]: `IsolatedCallback` is a compound identifier.
- Loses the semantic relationship to `Callback`.

#### Option E: Replace `Async.Callback<Value>` entirely (Recommended)

Remove the CPS-based `Callback` and introduce a new direct-style `Async.Callback<Value>` using `nonisolated(nonsending)`.

- **Name**: Same `Async.Callback<Value>` — no naming overhead, no awkward nesting.
- **Justification**: The experiment (T11) confirmed that a nonsending callback can wrap cross-isolation CPS work via `withCheckedContinuation`. The new type serves ALL existing use cases:
  - Same-isolation (direct closure) — primary use case.
  - Cross-isolation (CPS wrapping) — `init { await withCheckedContinuation { c in os_callback { c.resume(returning: $0) } } }`.
- **Migration path**: The CPS `run` property is not exposed on the new type. Callers use `await callback.value` instead of `callback.run { ... }`.

The experiment result D6 (nesting requires meaningless outer generic) makes Options A and B unergonomic. Option E avoids the naming problem entirely by replacing rather than coexisting.

#### Comparison

| Criterion | A: Callback.Isolated | B: Callback.Local | C: Overloads | D: IsolatedCallback | E: Replace Callback |
|-----------|---------------------|-------------------|--------------|---------------------|---------------------|
| [API-NAME-001] Nest.Name | Correct | Correct | N/A | Violates | Correct |
| [API-NAME-002] No compounds | Correct | Correct | N/A | Violates | Correct |
| Semantic clarity | "Isolated variant" | Ambiguous | Not possible | Clear but flat | "The callback type" |
| Swift terminology | Established | Novel | — | Established | — |
| Nesting ergonomics (D6) | Poor: `Callback<Never>.Isolated` | Poor | N/A | N/A | N/A |
| Cross-isolation support (T11) | Via bridge init | Via bridge init | N/A | Via bridge init | Native: CPS in init closure |
| Non-Sendable Value (T8) | Yes | Yes | No | Yes | Yes |

### 4. Sendable Constraint Analysis

The existing `Callback<Value: Sendable>: Sendable` carries two Sendable constraints:

1. **`Value: Sendable`** — the value crosses isolation boundaries (callback fires on arbitrary thread).
2. **Struct is `Sendable`** — the callback itself can be passed across isolation boundaries.

For `Callback.Isolated<Value>`:

1. **`Value` does NOT need `Sendable`.** The value is produced and consumed within the caller's isolation domain. It never crosses an isolation boundary.
2. **The struct is NOT `Sendable`.** The stored `nonisolated(nonsending)` closure is tied to an isolation domain and cannot cross boundaries.

Relaxing `Value: Sendable` is a significant expressiveness win:

| Use case | `Callback<V: Sendable>` | `Callback.Isolated<V>` |
|----------|------------------------|------------------------|
| Non-Sendable model objects | Cannot | Can |
| Reference types without `@unchecked Sendable` | Cannot | Can |
| `@MainActor`-isolated types | Cannot | Can |
| Types with internal mutable state | Cannot | Can |

### 5. API Surface

> **v2.1 revision**: `callAsFunction(isolation:)` replaces `getValue(isolation:)`. The invocation syntax `await callback()` reads as intent per [IMPL-INTENT] — a callback's purpose IS to be called. A computed property (`var value`) does not compile for non-Sendable `Value` (D1, D5). `callAsFunction` is the method wrapper that propagates isolation via SE-0420's `#isolation` default parameter.
>
> `map`/`flatMap` use `await self()` internally — a method call that propagates isolation (D3), unlike `self.operation()` which does NOT (D2, #83812). Validated by T15 (12 subtests: basic invocation, map isolation at every chaining level, flatMap, non-Sendable Value, deferred execution — all pass).

#### Core (Option E — replacement type)

```swift
extension Async {
    public struct Callback<Value> {
        @usableFromInline
        let operation: nonisolated(nonsending) () async -> Value

        /// Creates a callback with a deferred computation.
        ///
        /// The operation inherits the caller's isolation context and executes
        /// on the caller's executor. If the operation body is synchronous,
        /// no suspension occurs.
        public init(
            _ operation: nonisolated(nonsending) @escaping () async -> Value
        )

        /// Creates a callback with an immediate value.
        public init(value: Value)

        /// Executes the computation and returns the value.
        ///
        /// Uses `callAsFunction` with SE-0420 isolated parameter so the
        /// invocation syntax is `await callback()` — reads as intent.
        /// Required instead of a computed property because the region checker
        /// rejects non-Sendable returns from nonisolated async property
        /// getters (D1, D5).
        public func callAsFunction(
            isolation: isolated (any Actor)? = #isolation
        ) async -> Value
    }
}
```

**Design decisions**:
- **`operation` is NOT public.** `callAsFunction` is the execution mechanism. No CPS `run` is needed.
- **`callAsFunction`, not `var value` property.** Property getters trigger the region checker for non-Sendable returns (D1). `callAsFunction` with `#isolation` propagates caller isolation correctly (T4-C, T15). The syntax `await callback()` reads as intent per [IMPL-INTENT].
- **`Value` is unconstrained.** No `Sendable` requirement — the value never crosses isolation boundaries (T8).
- **Struct is NOT `Sendable`.** The stored `nonisolated(nonsending)` closure is tied to an isolation domain.

#### Transforms

```swift
extension Async.Callback {
    /// Transforms the computed value.
    ///
    /// The transform is a plain synchronous closure — not `@Sendable`,
    /// not `async`. It executes within the caller's isolation context
    /// because map's init closure calls `await self()` (callAsFunction,
    /// which propagates isolation), NOT `self.operation()` (a stored
    /// closure that does NOT propagate isolation per issue #83812).
    public func map<NewValue>(
        _ transform: @escaping (Value) -> NewValue
    ) -> Async.Callback<NewValue>

    /// Chains a dependent computation.
    public func flatMap<NewValue>(
        _ transform: @escaping (Value) -> Async.Callback<NewValue>
    ) -> Async.Callback<NewValue>
}
```

**Critical implementation constraint (D2, D3)**: `map` and `flatMap` MUST call `await self()` — never `self.operation()`. The experiment proved that stored nonsending closure called from another nonsending closure loses caller isolation (#83812), but a method call (`callAsFunction`) propagates it. Approaches A, B, E call `self.operation()` directly in map and FAIL T4. Approach C calls `await self()` and PASSES T4 and all T15 subtests.

**Transform closures are plain sync `@escaping` closures.** Not `@Sendable`, not `nonisolated(nonsending)`, not `async`. They are captured inside a `nonisolated(nonsending) () async -> NewValue` closure and execute in the caller's isolation domain.

This works because:
1. The `map` method is called from the caller's isolation domain (e.g., `@MainActor`).
2. The transform closure literal is created in that same isolation domain.
3. The transform is captured inside the init's `nonisolated(nonsending)` async closure.
4. When that async closure is invoked (via `await callback()`), it inherits the caller's isolation.
5. `callAsFunction` calls `self.operation()` via a method wrapper — isolation propagates through methods (D3, D7).
6. The sync transform is called from within that nonsending async context — it executes inline on the current executor.

Experiment T4-C, T15 (12 subtests including chained maps at 3 levels), and Test K (`stream-isolation-preservation`) confirm this end-to-end.

#### Bridge: Legacy CPS → Callback

```swift
extension Async.Callback where Value: Sendable {
    /// Bridges a legacy CPS-style completion handler to the direct-style callback.
    ///
    /// Use when wrapping OS callbacks, network completions, or other
    /// code that fires a completion handler on an arbitrary thread.
    public init(
        wrapping cps: @escaping @Sendable (
            @escaping @Sendable (Value) -> Void
        ) -> Void
    )
}
```

This requires `Value: Sendable` because CPS completions may fire on arbitrary threads. The implementation uses `withCheckedContinuation` (T9, T11).

#### Absent: `.async(isolation:_:)` and `.run`

- **No `.async(isolation:_:)`**: That method uses `Task {}`, which crosses isolation boundaries — antithetical to the type's purpose.
- **No public `.run`**: CPS-style `run` is not exposed. `callAsFunction` is the execution mechanism.
- **No CPS consumption**: Passing non-Sendable closures to nonisolated methods is rejected by the compiler (T12). CPS consumption would need isolated parameter or nonsending annotation — not needed in the direct-style design.

### 6. Implementation Sketch (Approach C — callAsFunction with isolated parameter)

> **v2.1**: `callAsFunction(isolation:)` replaces `getValue(isolation:)`.
> `await callback()` reads as intent per [IMPL-INTENT]. `map`/`flatMap`
> use `await self()` — a method call that propagates isolation (D3, D7).

```swift
extension Async {
    public struct Callback<Value> {
        @usableFromInline
        let operation: nonisolated(nonsending) () async -> Value

        @inlinable
        public init(
            _ operation: nonisolated(nonsending) @escaping () async -> Value
        ) {
            self.operation = operation
        }

        @inlinable
        public init(value: Value) {
            self.operation = { value }
        }

        /// Executes the computation and returns the value.
        ///
        /// `await callback()` — reads as intent. A callback's purpose
        /// IS to be called. Uses SE-0420 `#isolation` to propagate the
        /// caller's isolation context. Required instead of a computed
        /// property because the region checker rejects non-Sendable
        /// returns from nonisolated async getters (D1).
        @inlinable
        public func callAsFunction(
            isolation: isolated (any Actor)? = #isolation
        ) async -> Value {
            await operation()
        }

        /// Transforms the computed value with a synchronous closure.
        ///
        /// CRITICAL: Calls `await self()` (callAsFunction), NOT
        /// `self.operation()`. Stored closure-in-closure does not
        /// propagate isolation (#83812). Method call does (D3, D7).
        @inlinable
        public func map<NewValue>(
            _ transform: @escaping (Value) -> NewValue
        ) -> Async.Callback<NewValue> {
            .init { transform(await self()) }
        }

        /// Chains a dependent computation.
        @inlinable
        public func flatMap<NewValue>(
            _ transform: @escaping (Value) -> Async.Callback<NewValue>
        ) -> Async.Callback<NewValue> {
            .init { await transform(await self())() }
        }
    }
}

// Bridge from legacy CPS completion handlers
#if !hasFeature(Embedded)
extension Async.Callback where Value: Sendable {
    @inlinable
    public init(
        wrapping cps: @escaping @Sendable (
            @escaping @Sendable (Value) -> Void
        ) -> Void
    ) {
        self.init {
            await withCheckedContinuation { continuation in
                cps { value in
                    continuation.resume(returning: value)
                }
            }
        }
    }
}
#endif
```

### 7. File Organization

Per [API-IMPL-005] (one type per file). Option E (replacement) changes the file layout:

| File | Contents | Notes |
|------|----------|-------|
| `Async.Callback.swift` | `Callback` struct with `init(_:)`, `init(value:)`, `callAsFunction(isolation:)`, `map`, `flatMap` | Replaces existing CPS-based file |
| `Async.Callback+CPS.swift` | Bridge `init(wrapping:)` for legacy CPS | Conditional: `#if !hasFeature(Embedded)` |

**Migration note**: The existing `Async.Callback.swift` (164 lines) is replaced entirely. The CPS-based `Callback` with `@Sendable` closures and `run` property is removed. The new type is source-incompatible — callers must change from `callback.run { value in ... }` to `await callback()`. This is intentional: the new type has fundamentally different execution semantics.

Module: `Async Primitives` (existing module in swift-async-primitives).

### 8. Interaction with Async.Stream Operators

The `nonsending-adoption-audit.md` (v1.2.0) concluded that stream operator closures are NOT viable for nonsending adoption (0 of 52 sites viable). This research does not change that conclusion.

However, the underlying feasibility finding — `@escaping nonisolated(nonsending)` async closures can be stored and invoked — directly supports the concrete operator types approach recommended in `stream-isolation-preserving-operators.md`. Both patterns rely on the same mechanism: nonsending async closures preserving caller isolation.

| Pattern | Mechanism | Status |
|---------|-----------|--------|
| **Callback.Isolated** | Stored nonsending async closure | **FEASIBLE** (this research) |
| **Concrete stream operators** | Nonsending async `next()` calling stored transforms | **FEASIBLE** (stream experiment) |
| Type-erased stream operators | Nonsending closures in `@Sendable` `_next` | **NOT FEASIBLE** (audit v1.2.0) |

### 9. Compiler Issue #83812: Confirmed, Workaround Documented

> **v2.0**: Issue #83812 is now CONFIRMED by the experiment (D2). The workaround is documented and validated (D3, T4).

Swift issue [#83812](https://github.com/swiftlang/swift/issues/83812) reports that `nonisolated(nonsending)` closures called from `nonisolated(nonsending)` functions may not always inherit the caller actor.

**Experiment confirmation (D2)**: The experiment conclusively proved this. In `map`, when the new closure calls `self.operation()` (a stored nonsending closure), the sync transform runs on the cooperative pool — NOT on MainActor. Approaches A, B, E all FAIL T4 because they call `self.operation()` directly in map.

**Workaround (D3, D7)**: Method calls DO propagate isolation. `callAsFunction(isolation:)` wraps the stored closure call in a method. When map's closure calls `await self()` instead of `self.operation()`, the sync transform correctly runs on MainActor. T4 passes for C; T15 confirms all subtests pass with `callAsFunction`.

| Pattern | Propagates isolation? | Example |
|---------|-----------------------|---------|
| Closure → stored closure | **NO** (#83812) | `.init { f(await self.operation()) }` |
| Closure → callAsFunction → stored closure | **YES** | `.init { f(await self()) }` |

**Impact on design**: `callAsFunction` is not just an API convenience — it is a required indirection to work around #83812. Every composition method (`map`, `flatMap`) MUST call `await self()`. This makes `callAsFunction` structurally necessary, not merely ergonomic.

**Future**: If #83812 is fixed, the method wrapper remains correct (it's the right API shape regardless). The indirection could become unnecessary for implementation but remains semantically appropriate.

## Outcome

**Status**: IMPLEMENTED (2026-02-25)

### Summary

The CPS-based `Async.Callback<Value: Sendable>: Sendable` has been replaced entirely with a direct-style `Async.Callback<Value>` using `nonisolated(nonsending)` closures and `callAsFunction(isolation:)` (Option E, Approach C). This enables Point-Free-style deterministic dependency injection with non-Sendable value support.

The experiment (`callback-isolated-prototype`) tested 5 approaches across 15 test scenarios. Approaches C and D are the only correct implementations — both pass all isolation tests. Approach C was implemented because `#isolation` is the standard Swift pattern (SE-0420).

> **v3.1 note**: `nonsending-compiler-patterns.md` (2026-03-22) discovered that the Swift stdlib has **deprecated** `isolation: isolated (any Actor)?` parameter overloads across all concurrency primitives (`withCheckedContinuation`, `withTaskCancellationHandler`, etc.) in favor of `nonisolated(nonsending)` on the function itself. Our `callAsFunction(isolation:)` uses the deprecated pattern. The stdlib migration uses `@_disfavoredOverload` + `@available(*, deprecated)` on the old overload. A future migration should replace `callAsFunction(isolation:)` with `nonisolated(nonsending) func callAsFunction() async -> Value`. This would remove the `isolation:` implementation detail from the public API and align with the compiler's canonical direction. Requires experiment validation that `await self()` in `map`/`flatMap` still propagates isolation with the method-level annotation.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Type name | `Async.Callback<Value>` (replacement) | Option E — nesting is awkward (D6/T13); single type serves all use cases (T11) |
| Execution style | Direct async/await | CPS uses sync function types; `nonisolated(nonsending)` requires async |
| Invocation | `callAsFunction(isolation:)` | `await callback()` reads as intent [IMPL-INTENT]; property getter fails for non-Sendable (D1/D5); method propagates isolation (D3/D7) |
| `Value` constraint | No `Sendable` requirement | Value never crosses isolation boundaries (T8) |
| Struct Sendable | NOT `Sendable` | Nonsending closure is tied to isolation domain |
| Transform closures | Plain sync `@escaping` | Called from nonsending async context; isolation preserved (T4-C/D) |
| Composition indirection | `await self()`, never `self.operation()` | #83812 confirmed: stored closure-in-closure loses isolation (D2/D3/D7) |
| Cross-isolation | `init(wrapping:)` bridge for CPS | Legacy CPS completion handlers wrapped via withCheckedContinuation (T9/T11) |
| `.async` / `.run` | Not included | `.async` uses `Task {}`; no CPS needed |

### Experiment Evidence

| Test | Finding | Significance |
|------|---------|-------------|
| T1 | All 5 approaches compile and return correct values | Core feasibility confirmed |
| T2 | Init closure runs on MainActor for all approaches | Isolation inherited at construction |
| T4 | A,B,E FAIL map isolation; C,D PASS | #83812 confirmed; method wrapper required |
| T8 | Non-Sendable Value works (B,C,D,E) | Major expressiveness win over existing Callback |
| T11 | Nonsending callback wraps CPS cross-isolation work | Replacement feasibility confirmed |
| T13 | Nesting compiles but requires `Callback<Never>.Isolated<T>` | Motivates Option E (replacement) |
| T14 | @unchecked Sendable preserves creation-time isolation | Soundness of nonsending closures |
| T15 | `callAsFunction(isolation:)` — all 12 subtests pass | `await callback()` syntax works; isolation propagates through `await self()` in map/flatMap at all levels |

### Implementation Record

All recommended steps have been completed:

1. **Implemented** (`swift-async-primitives` commit `abddd918`):
   - `Async.Callback.swift` — complete rewrite (164 → 135 lines). Struct with `init(_:)`, `init(value:)`, `callAsFunction(isolation:)`, `map`, `flatMap`. All public API `@inlinable` with `@usableFromInline` storage.
   - CPS bridge `init(wrapping:)` included in same file (guarded by `#if !hasFeature(Embedded)`). Separate file not needed — bridge is 13 lines.

2. **Tested** (`swift-async-primitives` commit `db8f4aa3`):
   - 23 tests in `Async.Callback Tests.swift` (255 lines), ported from experiment T1–T15.
   - Unit (11): init, deferred laziness, map, flatMap, non-Sendable Value, CPS bridge.
   - EdgeCase (7): Void, nested flatMap, identity map, multiple invocations, monad laws, async CPS.
   - Integration (6): isolation preservation verified via `pthread_main_np()` on `@MainActor` — init closure, map, chained maps, flatMap, post-await caller, CPS bridge.
   - All 88 async-primitives tests pass (65 existing + 23 new).

3. **Migrated callers** (`swift-test-primitives` commit `39f1351`):
   - `Test.Snapshot.Strategy.swift` — 4 call sites updated: `asyncPullback` CPS chain → await chaining, `capture` `.value` → `()`, doc example CPS → `withCheckedContinuation`, doc comments updated.
   - No other callers exist. Pool, cache, and foundations packages import `Async_Primitives` for channels/promises/bridges but do not use `Async.Callback`.

4. **Documentation**: This research document updated to IMPLEMENTED status. Production code includes full doc comments with usage examples.

## References

### Direct Dependencies

- `nonsending-adoption-audit.md` — Identified Callback as primary dual-mode candidate (P1–P5, lines 165–239)
- `stream-isolation-propagation.md` — Established `Async.Stream` as architectural concurrency boundary (Option D)
- `stream-isolation-preserving-operators.md` — Concrete operator types preserve isolation (related pattern)

### Experiments

- `swift-institute/Experiments/callback-isolated-prototype/` — **Primary validation**: 5 approaches, 14 tests, 6 discoveries. Approaches C/D confirmed. Issue #83812 confirmed with method wrapper workaround.
- `swift-institute/Experiments/nonsending-closure-type-constraints/` — Confirmed `@escaping nonisolated(nonsending)` async closure storage (B1a, B1b) and sync restriction (B1d)
- `swift-institute/Experiments/nonescapable-closure-storage/` — Confirmed ~Escapable closure storage patterns
- `swift-institute/Experiments/stream-isolation-preservation/` — Confirmed sync closures preserve isolation when called from nonsending async context (Test K)

### Swift Evolution

- [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md): Run nonisolated async functions on the caller's actor by default
- [SE-0421](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0421-generalize-async-sequence.md): Generalize AsyncSequence and AsyncIteratorProtocol
- [SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-of-nonisolated-async.md): `nonisolated(nonsending)` function types

### Compiler Issues

- [#83812](https://github.com/swiftlang/swift/issues/83812): Nonisolated nonsending closure called from nonisolated nonsending function does not inherit caller actor

### Prior Art

- Point-Free #355: Beyond Basics: Isolation, ~Copyable, ~Escapable (Feb 23, 2026)
- TCA 2.0: nonisolated(nonsending) dependency closures for deterministic testing
