# ~Copyable Ergonomics: Compiler State and Outlook

<!--
---
version: 3.0.0
last_updated: 2026-03-31
status: SUPERSEDED
superseded_by: noncopyable-ecosystem-state.md
tier: 2
workflow: Investigation [RES-001]
trigger: bridge-noncopyable-ownership experiment revealed 6 ergonomic pain points in ~Copyable ownership transfer through Mutex closures
scope: Ecosystem-wide — affects all ~Copyable code across swift-primitives, swift-standards, swift-foundations
changelog:
  - v3.0.0 (2026-03-31): Coroutine-capable struct Mutex with @_rawLayout eliminates closures entirely. nonmutating _modify on ~Copyable Locked view enables let binding + direct property access. Parity with Synchronization.Mutex. Closure-based patterns (withLock(consuming:)) remain as backward compat, not the end state.
  - v2.0.0 (2026-03-31): Reframed Pain Point 1 after ecosystem prior art survey (stdlib, swift-system, swift-nio, Swift Forums). The Optional wrapper is not a "workaround" — it's the stdlib-endorsed pattern. The correct framing: make consuming values closure parameters, not captures.
  - v1.0.0 (2026-03-31): Initial compiler source investigation.
---
-->

> **SUPERSEDED** (2026-04-02) by [noncopyable-ecosystem-state.md](noncopyable-ecosystem-state.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

The `bridge-noncopyable-ownership` experiment (2026-03-31) tested ownership transfer of `~Copyable` values through `Mutex.withLock` closures. All 9 variants compiled and ran correctly, but the required ceremony is substantial:

- **4-statement slot dance** to move a consuming value into a closure: `var slot → var tmp → slot = nil → switch consume tmp`
- **Implicit Copyable on extensions** forces `where Value: ~Copyable` on every extension
- **Force unwrap (`!`) crashes IRGen** on `var Optional<~Copyable>` into generic consuming parameter — requires `.take()!` workaround
- **Continuations require `T: Copyable`** — forces void-signal pattern and 3-lock slow path
- **Pattern matching requires `switch consume`** — bare `switch` on `Optional<Optional<~Copyable>>` borrows the inner value
- **All Optional access is consuming** — `if let`, `guard let`, `switch .some(var)`, `!`, and `?.` all consume; only `_read` coroutine borrows

This research investigates the Swift compiler source (`/Users/coen/Developer/swiftlang/swift`) to determine which pain points are fundamental, which are known bugs, and which have improvement paths.

## Question

What is the current compiler state for each ~Copyable ergonomic limitation, and what is the realistic outlook for improvement?

## Analysis

### Pain Point 1: Closure Capture of Consuming ~Copyable Values

**Current state**: Non-escaping closures capture by reference/address, not by value ownership transfer. Consuming a captured variable requires reinitialization at closure exit because the compiler treats all closures as potentially callable multiple times — there is no "once-only closure" concept in the type system.

**Ecosystem prior art survey** (Verified: 2026-03-31):

The stdlib **never** consumes through closure capture. Instead, it uses two patterns:

1. **`inout sending` parameters** — `Mutex.withLock` passes `inout sending Value` to the closure (`stdlib/public/Synchronization/Mutex/Mutex.swift:87-97`). The value stays in place; the closure mutates through a reference. Internally, Mutex uses `_Cell<Value>` with `@_rawLayout` and `unsafe body(&value._address.pointee)` — raw pointer access, no Optional wrapping.

2. **`consuming` closure parameters** — `ExecutorJob` uses `(consuming ExecutorJob) -> ()` as a closure *parameter type* (`stdlib/public/Concurrency/CooperativeExecutor.swift:131`). `Result._consumingMap` takes `(consuming Success) -> NewSuccess` (`stdlib/public/core/Result.swift:88-97`). The value enters through the parameter, not through capture.

The distinction is critical: **consuming a closure parameter works. Consuming a captured variable requires reinitialization.** The fix is to make the value a parameter, not a capture.

**Community consensus**: The Swift Forums thread ["Missing reinitialization of closure capture after consume for closures executed only once"](https://forums.swift.org/t/missing-reinitialization-of-closure-capture-after-consume-for-closures-executed-only-once/76864) (Dec 2024) documents this as a known intentional constraint. The `Optional` + `.take()` pattern is the accepted workaround. A "consuming closure" or "once-only closure" concept would be the natural fix but has not been formally proposed.

**swift-system**: Uses `~Copyable` for `Mach.Port<RightType>` with `withBorrowedName(body:)` — borrowing closure, no consuming capture (`swift-system/Sources/System/MachPort.swift`).

**swift-nio**: Does not use `~Copyable`. Uses `NIOLockedValueBox` with `withLockedValue(body:)` — reference-counted lock box, sidesteps ownership entirely (`swift-nio/Sources/NIOConcurrencyHelpers/NIOLockedValueBox.swift`).

**Outlook**: **Deliberate design, not a bug.** The reinitialization requirement follows from closures being re-invocable. The stdlib-endorsed pattern is: convert captured consuming values into closure parameters. Our `Mutex.withLock(consuming:body:)` extension does exactly this — the body receives `consuming V` as a parameter, matching `Result._consumingMap` and `CooperativeExecutor.forEachReadyJob`.

**Ecosystem action**: The `Mutex.withLock(consuming:body:)` and `Mutex.withLock(deposit:body:)` extensions are the closure-based pattern, aligned with stdlib. However, the `mutex-coroutine-rawlayout` experiment (2026-03-31) proves that a struct Mutex with `@_rawLayout` inline storage and `nonmutating _modify` on a `~Copyable` Locked view eliminates closures entirely. The coroutine-based `locked` accessor provides direct property access: `_state.locked.value.buffer.push(consume element, to: .back)` — no closure, no Optional, no `.take()!`. This works with `let` binding and achieves parity with `Synchronization.Mutex` on every performance axis. The closure-based extensions remain as backward compatibility, not the end state.

### Pain Point 2: Implicit Copyable Constraint on Extensions

**Current state**: `extension Mutex { ... }` implicitly constrains `Value: Copyable`. This is implemented in `lib/AST/Requirement.cpp:367-387` — `InverseRequirement::expandDefaults()` adds conformances to all invertible protocols (Copyable, Escapable) for every generic parameter.

**Compiler evidence**: This is a deliberate design choice from SE-0427 (Noncopyable Generics). `lib/Sema/TypeCheckDeclPrimary.cpp:163-183` has an explicit comment explaining the rationale. Test file `test/Generics/inverse_extension_signatures.swift` documents the expected behavior. A feature flag `SE427NoInferenceOnExtension` exists but only for `.swiftinterface` files.

**Outlook**: **Deliberate permanent design.** The Swift team chose consistency: every generic context gets the same defaulting rules. There is no proposal to change this. Writing `where Value: ~Copyable` is the intended pattern.

**Ecosystem action**: Accept as permanent. Ensure all ecosystem extensions on `~Copyable`-generic types include the constraint. Add to the copyable-remediation skill as a standard check.

### Pain Point 3: Force Unwrap (`!`) on Optional<~Copyable>

**Current state**: The IRGen crash when using `o!` to pass into a generic `consuming T` parameter was partially addressed in Swift 6.0 — commit `ae767daf517` ("Treat Optional `x!` force unwrapping as a forwarding operation", `lib/SILGen/SILGenApply.cpp:3246-3391`, merged May 2024, rdar://127459955). However, the specific crash we observed on Swift 6.3 (`Invalid bitcast, address space 64`) suggests either a regression or an uncovered edge case in the interaction between force-unwrap forwarding and generic consuming parameters.

**Workaround**: `.take()!` instead of `!`. The `.take()` method was generalized for noncopyable payloads in November 2024 (`stdlib/public/core/Optional.swift:449-453`).

**Outlook**: **Bug, likely fixable.** The infrastructure for treating `!` as a forwarding operation exists. The remaining crash is a corner case. Filing a bug report with the minimal repro would be valuable.

**Ecosystem action**: Use `.take()!` universally. Consider filing the minimal repro from the `inout-noncopyable-optional-closure-capture` experiment (2026-03-27) as a Swift bug.

### Pain Point 4: Continuations Require `T: Copyable`

**Current state**: Both `UnsafeContinuation<T, E>` (`stdlib/public/Concurrency/PartialAsyncTask.swift:694`) and `CheckedContinuation<T, E>` (`stdlib/public/Concurrency/CheckedContinuation.swift:126`) declare `T` without `~Copyable`. The implicit Copyable default applies. All wrapper functions (`withCheckedContinuation`, `withUnsafeContinuation`) inherit the same constraint.

**Compiler evidence**: No TODOs, no FIXMEs, no comments about adding `~Copyable` support. Only `Job` and `ExecutorJob` in the concurrency module use `~Copyable`. Async getters on noncopyable types are forbidden (`test/SILGen/moveonly_restrictions.swift`).

**Outlook**: **No improvement path visible.** The concurrency runtime likely stores continuation values in ways that assume copyability (e.g., task-local storage, cancellation handlers). Adding `~Copyable` to continuations would require deep runtime changes. No proposals exist.

**Ecosystem action**: The void-signal pattern (continuation carries `Void`, element transferred via mutex-protected buffer) is the correct permanent architecture. The 3-lock slow path is fundamental — document it as inherent, not as a workaround.

### Pain Point 5: Pattern Matching Requires `switch consume`

**Current state**: SE-0432 (Noncopyable Switch) enables pattern matching on noncopyable enums. But the ownership default for `switch` is borrowing. For nested `Optional<Optional<~Copyable>>`, `switch result` borrows the inner value — you must write `switch consume result` to take ownership.

**Outlook**: **Deliberate design.** Borrowing is the safe default; consuming is the explicit opt-in. This is consistent with Swift's ownership model. No proposals to change this.

**Ecosystem action**: Always `switch consume` when the matched value will be moved. The `_Take` enum remains superior to `Element??` because its cases are self-documenting and the `switch consume` requirement applies equally to both.

### Pain Point 6: All Optional Access is Consuming

**Current state**: Confirmed by the `optional-noncopyable-unwrap` experiment (2026-02-12). `if let`, `guard let`, `switch .some(var)`, `!`, and `?.` all consume the Optional. Only `_read` coroutine projection yields a borrow.

**Workaround patterns** (from that experiment):
- **Mutating methods**: Optional chaining (`_heapBuffer?.method()`) — zero force unwraps
- **Value-returning**: `if let result = _heapBuffer?.method() { return result }` — optional propagation IS the nil check
- **Non-mutating access**: `_read`/`_modify` projection confines `!` to one accessor pair; call sites use clean `heap.method()` syntax

**Outlook**: **Deliberate design.** Optional unwrap is an ownership transfer. Borrowing through Optional would require coroutine-based accessors (which `_read`/`_modify` already provide, but they're underscored/unstable).

**Ecosystem action**: The `_read`/`_modify` projection pattern is the primary solution. Optional chaining for mutating access. Accept that `!` or `.take()!` is confined to accessor bodies, not scattered across call sites.

## Comparison

| Pain Point | Nature | Stdlib Pattern | Permanent? |
|------------|--------|----------------|------------|
| Consuming closure capture | Deliberate (re-invocable closures) | Coroutine accessor eliminates closures; `nonmutating _modify` provides direct access | **Solved** |
| Implicit Copyable on extensions | Deliberate (SE-0427) | `where Value: ~Copyable` | Yes |
| Force unwrap IRGen crash | Bug | `.take()!` | No (file bug) |
| Continuations require Copyable | Deep runtime | Void-signal pattern | Yes |
| `switch consume` required | Deliberate (SE-0432) | Write `switch consume` | Yes |
| All Optional access consuming | Deliberate | `_read`/`_modify` projection | Yes |

## Outcome

**Status**: DECISION

### Summary

Of the 6 pain points, **5 are permanent by design** and **1 is a compiler bug**. The most important reframing: the closure capture limitation is not a workaround — it's the intended model. The stdlib pattern is to convert consuming captures into consuming parameters.

1. **Closure capture**: The stdlib never consumes through capture. `Mutex.withLock` uses `inout sending` parameters. `Result._consumingMap` and `CooperativeExecutor.forEachReadyJob` use consuming closure parameters. Our `withLock(consuming:body:)` extension follows the same pattern — it converts the captured value into a body parameter. This is not a workaround; it's the correct approach.

2. The implicit Copyable on extensions is SE-0427's deliberate design. **Accept and enforce** — add to copyable-remediation skill.

3. The force-unwrap IRGen crash is a bug with a known workaround (`.take()!`). **File upstream** with the minimal repro.

4. Continuations will not support `~Copyable` in the foreseeable future. **The void-signal pattern is permanent architecture**, not a workaround.

5. `switch consume` is the correct ownership-aware pattern. **Accept and standardize.**

6. `_read`/`_modify` projection is the safe accessor pattern for `Optional<~Copyable>`. **Confine `!` to accessor bodies.**

### Recommended Ecosystem Patterns

For transferring a `consuming ~Copyable` value into a `Mutex.withLock` closure:

```swift
// Pattern A (preferred): withLock(consuming:body:)
// Matches stdlib pattern: consuming value as closure parameter
let result = mutex.withLock(consuming: element) { state, element in
    state.buffer.push(consume element, to: .back)
}

// Pattern B: Caller-owned slot (no extension needed)
var slot: Element? = element
let result = mutex.withLock { state in
    let el = slot.take()!
    // use el...
}

// Pattern B: Mutex.withLock(consuming:body:) extension
// (cleanest call site, every path must consume)
let result = mutex.withLock(consuming: element) { state, el in
    // el is consuming — use or drop on every path
}

// Pattern C: Mutex.withLock(deposit:body:) extension
// (most general, body can leave element unconsumed)
let result = mutex.withLock(deposit: element) { state, slot in
    let el = slot.take()!
    // use el...
}
```

For `Optional<~Copyable>` access without force unwrap:

```swift
// Mutating: optional chaining
_storage?.append(element)

// Value-returning: if-let on optional chain
if let result = _storage?.removeFirst() { return result }

// Non-mutating projection: _read/_modify accessor pair
var storage: Storage {
    _read { yield _storage! }
    _modify { yield &_storage! }
}
// Call sites: storage.count (no ! visible)
```

For async handoff of `~Copyable` elements (Bridge/Channel pattern):

```swift
// Void-signal continuation + mutex-protected buffer
// This is permanent architecture, not a workaround
await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
    // store continuation in mutex-protected state
}
// after resume: take element from buffer under separate lock
```

## References

### Experiments
- `swift-primitives/Experiments/bridge-noncopyable-ownership/` — Mutex extension variants (2026-03-31)
- `swift-primitives/swift-async-primitives/Experiments/inout-noncopyable-optional-closure-capture/` — inout Element? pattern (2026-03-27)
- `swift-primitives/Experiments/optional-noncopyable-unwrap/` — Safe unwrap alternatives (2026-02-12)

### Swift Evolution
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable Generics (implicit Copyable defaults)
- SE-0429: Partial Consumption of Noncopyable Values
- SE-0430: `sending` parameter and result values
- SE-0432: Borrowing and consuming pattern matching for noncopyable types

### Stdlib Prior Art (verified 2026-03-31)
- `stdlib/public/Synchronization/Mutex/Mutex.swift:87-97` — `withLock` uses `inout sending Value`, raw pointer access via `_Cell`
- `stdlib/public/Synchronization/Cell.swift:17-38` — `@_rawLayout(like: Value, movesAsLike)` storage primitive
- `stdlib/public/Concurrency/CooperativeExecutor.swift:131` — `(consuming ExecutorJob) -> ()` as closure parameter type
- `stdlib/public/core/Result.swift:88-97` — `_consumingMap` with `(consuming Success) -> NewSuccess`
- `stdlib/public/core/Optional.swift:449-453` — `.take()` generalized for noncopyable payloads

### Ecosystem Prior Art (verified 2026-03-31)
- swift-system `Mach.Port<RightType>: ~Copyable` — `withBorrowedName(body:)`, `consuming func relinquish()` with `discard self`
- swift-nio `NIOLockedValueBox` — `withLockedValue(body:)`, reference-counted lock box, no ~Copyable
- swift-collections — no ~Copyable usage

### Community
- [Missing reinitialization of closure capture after consume for closures executed only once](https://forums.swift.org/t/missing-reinitialization-of-closure-capture-after-consume-for-closures-executed-only-once/76864) (Dec 2024) — canonical thread documenting the limitation
- [Escaping Consuming Functions](https://forums.swift.org/t/escaping-consuming-functions/69807) (2024)
- [Capturing a noncopyable type in an async closure](https://forums.swift.org/t/capturing-a-noncopyable-type-in-an-async-closure/68118)

### Compiler Source (verified 2026-03-31)
- `lib/SILGen/SILGenFunction.cpp:782-910` — Move-only wrapper elimination for closure captures
- `lib/AST/Requirement.cpp:367-387` — `InverseRequirement::expandDefaults()` (implicit Copyable)
- `lib/Sema/TypeCheckDeclPrimary.cpp:163-183` — Extension constraint rationale
- `lib/SILGen/SILGenApply.cpp:3246-3391` — Force-unwrap forwarding fix
- `stdlib/public/Concurrency/PartialAsyncTask.swift:694` — `UnsafeContinuation` declaration
- `stdlib/public/Concurrency/CheckedContinuation.swift:126` — `CheckedContinuation` declaration
