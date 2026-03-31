# ~Copyable Ergonomics: Compiler State and Outlook

<!--
---
version: 1.0.0
last_updated: 2026-03-31
status: DECISION
tier: 2
workflow: Investigation [RES-001]
trigger: bridge-noncopyable-ownership experiment revealed 6 ergonomic pain points in ~Copyable ownership transfer through Mutex closures
scope: Ecosystem-wide — affects all ~Copyable code across swift-primitives, swift-standards, swift-foundations
---
-->

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

**Current state**: Non-escaping closures capture by reference/address, not by value ownership transfer. There is no mechanism for a `consuming` parameter to be passed into a closure. The compiler wraps noncopyable captures via `eliminateMoveOnlyWrapper` logic (`lib/SILGen/SILGenFunction.cpp:782-910`) to make them compatible with closure machinery.

**Workaround**: Wrap in `var slot: Element? = element`, capture the mutable Optional, use `.take()!` or `switch consume` inside the closure.

**Compiler evidence**: `test/SILOptimizer/moveonly_self_captures.swift:68-79` — "noncopyable 'self' cannot be consumed when captured by an escaping closure." No TODOs or proposals address non-escaping consuming capture.

**Outlook**: **Fundamental architectural limitation.** Closure capture works via reference/storage access. A `consuming` capture would require a different calling convention for closures. No proposals exist. The Optional wrapper pattern is the indefinite solution.

**Ecosystem action**: The `Mutex.withLock(consuming:body:)` and `Mutex.withLock(deposit:body:)` extensions from the experiment encapsulate the workaround. Consider adding these as ecosystem infrastructure if the pattern recurs.

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

| Pain Point | Nature | Fixable? | Workaround | Permanent? |
|------------|--------|----------|------------|------------|
| Consuming closure capture | Architectural | No | Optional wrapper + `.take()!` | Yes |
| Implicit Copyable on extensions | Deliberate (SE-0427) | No | `where Value: ~Copyable` | Yes |
| Force unwrap IRGen crash | Bug | Yes | `.take()!` | No (file bug) |
| Continuations require Copyable | Deep runtime | No | Void-signal pattern | Yes |
| `switch consume` required | Deliberate (SE-0432) | No | Write `switch consume` | Yes |
| All Optional access consuming | Deliberate | No | `_read`/`_modify` projection | Yes |

## Outcome

**Status**: DECISION

### Summary

Of the 6 pain points, **5 are permanent by design** and **1 is a compiler bug**:

1. The Optional wrapper dance for closure capture is an architectural consequence of how Swift closures work. No proposals or FIXMEs suggest change. **Accept and encapsulate** — the `Mutex.withLock(deposit:body:)` extension is a clean API over the workaround.

2. The implicit Copyable on extensions is SE-0427's deliberate design. **Accept and enforce** — add to copyable-remediation skill.

3. The force-unwrap IRGen crash is a bug with a known workaround (`.take()!`). **File upstream** with the minimal repro.

4. Continuations will not support `~Copyable` in the foreseeable future. **The void-signal pattern is permanent architecture**, not a workaround.

5. `switch consume` is the correct ownership-aware pattern. **Accept and standardize.**

6. `_read`/`_modify` projection is the safe accessor pattern for `Optional<~Copyable>`. **Confine `!` to accessor bodies.**

### Recommended Ecosystem Patterns

For transferring a `consuming ~Copyable` value into a `Mutex.withLock` closure:

```swift
// Pattern A: Caller-owned slot (no extension, simplest)
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

### Compiler Source (verified 2026-03-31)
- `lib/SILGen/SILGenFunction.cpp:782-910` — Move-only wrapper elimination for closure captures
- `lib/AST/Requirement.cpp:367-387` — `InverseRequirement::expandDefaults()` (implicit Copyable)
- `lib/Sema/TypeCheckDeclPrimary.cpp:163-183` — Extension constraint rationale
- `lib/SILGen/SILGenApply.cpp:3246-3391` — Force-unwrap forwarding fix
- `stdlib/public/core/Optional.swift:449-453` — `.take()` for noncopyable
- `stdlib/public/Concurrency/PartialAsyncTask.swift:694` — `UnsafeContinuation` declaration
- `stdlib/public/Concurrency/CheckedContinuation.swift:126` — `CheckedContinuation` declaration
