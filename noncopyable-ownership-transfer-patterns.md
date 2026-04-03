# ~Copyable Ownership Transfer Patterns

<!--
---
version: 2.0.0
last_updated: 2026-03-31
status: SUPERSEDED
superseded_by: noncopyable-ecosystem-state.md
tier: 2
workflow: Investigation [RES-001]
trigger: Ecosystem-wide ~Copyable usage through Mutex closures needs canonical patterns
scope: All ~Copyable code across swift-primitives, swift-standards, swift-foundations
changelog:
  - v2.0.0 (2026-03-31): Coroutine-capable struct Mutex eliminates closures. nonmutating _modify on ~Copyable Locked view enables direct property access with let binding. Closure patterns (withLock(consuming:)) become backward compat, not end state. Future-proofing table updated.
  - v1.0.0 (2026-03-31): Three closure-based patterns codified.
---
-->

> **SUPERSEDED** (2026-04-02) by [noncopyable-ecosystem-state.md](noncopyable-ecosystem-state.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

The ecosystem uses `~Copyable` extensively — Bridge, Channel, Waiter, File.Descriptor, Memory.Lock.Token, Witness.Scope. These types frequently transfer ownership through `Mutex.withLock` closures. Swift 6.3 closures capture by reference (not ownership), so consuming a captured variable requires reinitialization at closure exit. The stdlib handles this by making consuming values into closure *parameters*, not *captures*.

This document codifies the three ownership transfer patterns observed in the ecosystem, aligned with stdlib prior art and governed by [IMPL-INTENT] (intent over mechanism) and [IMPL-000] (call-site-first design).

## Question

What are the canonical patterns for transferring `~Copyable` values through `Mutex.withLock` closures?

## Analysis

### The Mechanism Layer

Swift 6.3 requires an `Optional` wrapper to move a consuming `~Copyable` value into a closure:

```swift
// This is MECHANISM — it belongs inside infrastructure, never at call sites
var slot: V? = value
mutex.withLock { state in
    let v = slot.take()!  // provably safe: just deposited
    // use v...
}
```

This is not a workaround — it's the only pattern Swift supports, and it aligns with how the stdlib handles the same problem (`Mutex.withLock` uses `unsafe body(&value._address.pointee)` internally; `Result._consumingMap` takes `(consuming Success) -> NewSuccess` as a closure parameter; `CooperativeExecutor.forEachReadyJob` takes `(consuming ExecutorJob) -> ()`).

The principle: **consuming values enter closures as parameters, not captures.**

### Pattern 1: Always-Consume [MEM-OWN-010]

**When**: Every code path consumes the value (buffer it, deliver it, or drop it).

**API**: `Mutex.withLock(consuming:body:)` — body receives `consuming V` as a parameter.

**Call site** (reads as intent):
```swift
public func push(_ element: consuming sending Element) {
    let continuationToResume =
        _state.withLock(consuming: element) { state, element in
            guard !state.isFinished else {
                _ = consume element  // drop
                return nil
            }
            state.buffer.push(consume element, to: .back)
            // resume continuation if waiting...
        }
    continuationToResume?.resume()
}
```

**Infrastructure** (mechanism confined here):
```swift
extension Mutex where Value: ~Copyable {
    public func withLock<V: ~Copyable & Sendable, T: ~Copyable, E: Error>(
        consuming value: consuming sending V,
        body: (inout sending Value, consuming V) throws(E) -> sending T
    ) throws(E) -> sending T {
        var slot: V? = value
        return try withLock { (state: inout sending Value) throws(E) -> T in
            try body(&state, slot.take()!)
            // WORKAROUND: Optional wrapper for closure capture of consuming ~Copyable
            // WHY: Swift closures capture by reference; consuming requires reinitialization
            // WHEN TO REMOVE: When Swift gains consuming closure parameters or once-only closures
            // TRACKING: forums.swift.org/t/76864
        }
    }
}
```

**Used by**: `Async.Bridge.push()`

### Pattern 2: Maybe-Consume [MEM-OWN-011]

**When**: A state machine decides per-path whether to consume the value. Some paths take it (deliver, buffer); others leave it (suspend, reject).

**API**: State machine method takes `inout Element?`. Call site passes `&slot`. The state machine uses `.take()!` on consume paths and leaves the Optional populated on non-consume paths.

**Call site** (reads as intent):
```swift
public func send(_ element: consuming sending Element) throws(Error) {
    let slot = Ownership.Slot(consume element)
    let action = storage.withLock { state in
        var opt: Element? = slot.take()
        let a = state.send(&opt)
        if let remaining = opt.take() {
            _ = slot.store(remaining)
        }
        return a
    }
    switch consume action {
    case .give(let cont, let element): // deliver
    case .keep:                         // buffered
    case .shut:                         // closed
    }
}
```

**State machine** (mechanism confined here):
```swift
mutating func send(_ element: inout Element?) -> Send.Action {
    guard !_closed else { return .shut }
    switch self.slot {
    case .wait(let cont):
        self.slot = .none
        return .give(cont, element.take()!)  // consume: deliver
    case .none, .cancelled:
        buffer.push(element.take()!, to: .back)  // consume: buffer
        return .keep
    }
}
```

**Used by**: `Async.Channel.Unbounded.Sender.send()`, `Async.Channel.Bounded.Sender.send()`

### Pattern 3: Borrow-Only

**When**: No ownership transfer — read or mutate state, return a Copyable result.

**API**: Standard `withLock { state in ... }`. No special infrastructure needed.

**Call site**:
```swift
public func finish() {
    let continuationToResume = _state.withLock { state in
        state.isFinished = true
        // extract continuation if present...
    }
    continuationToResume?.resume()
}
```

**Used by**: `Bridge.finish()`, `Bridge.isFinished`, all query operations.

### Action Enum Dispatch [MEM-OWN-012]

Cross-cutting convention for all three patterns:

1. **Lock produces a `~Copyable` action enum** — the state machine returns what the caller should do, not what to do internally.
2. **`switch consume action` outside the lock** — side effects happen after lock release.
3. **Continuations resumed post-lock** — prevents reentrancy and deadlock.

```swift
// Inside lock: pure state transition, returns action
let action: _Take = _state.withLock { state in
    if let element = state.buffer.pop(from: .front) { return .element(element) }
    if state.isFinished { return .finished }
    return .suspend
}

// Outside lock: side effects
switch consume action {
case .element(let element): return element
case .finished: return nil
case .suspend: break  // fall through to slow path
}
```

### Decision Procedure

```
Is a ~Copyable value being transferred into a Mutex.withLock closure?
│
├─ Does every code path consume the value?
│   YES → Pattern 1: Always-Consume [MEM-OWN-010]
│         Use withLock(consuming:body:)
│
├─ Does a state machine decide per-path?
│   YES → Pattern 2: Maybe-Consume [MEM-OWN-011]
│         State machine takes inout Element?
│
└─ Is it read/mutate only?
    YES → Pattern 3: Borrow-Only
          Standard withLock { state in ... }
```

## Layer Model [IMPL-070]

```
Layer 0: var slot: V? = value + .take()!     — inside Mutex extension only
Layer 1: withLock(consuming:), withLock(deposit:), Ownership.Slot  — general tooling
Layer 2: Bridge.push(), Channel.send()        — domain API (call site)
```

**Rule**: `.take()!` and `var slot: V?` MUST NOT appear at Layer 2 call sites. They are mechanism per [IMPL-INTENT]. If a Layer 2 method needs to transfer ownership through a lock, it MUST use Layer 1 infrastructure.

**Detection**: During code review, any `.take()!` at a Layer 2 call site is a compliance violation. The fix is to route through `withLock(consuming:body:)`, `withLock(deposit:body:)`, or a state machine method taking `inout Element?`.

## Coroutine Accessor: The End State

The `mutex-coroutine-rawlayout` experiment (2026-03-31) proves that the closure-based patterns above are **transitional, not permanent**. A struct Mutex with `@_rawLayout` inline storage and `nonmutating _modify` on a `~Copyable` Locked view eliminates closures entirely:

```swift
// End state — no closure, no Optional, no .take()!, direct property access:
_state.locked.value.buffer.push(consume element, to: .back)
```

**Architecture**:
- `@_rawLayout` inner structs for value and lock (ecosystem Memory.Inline pattern)
- `nonmutating _modify` on `Locked.value` — pointer-based interior mutability
- `_read` only on `StructMutex.locked` — borrows self, works with `let`
- `borrowing func withLock` coexists for backward compatibility

**Performance parity** with `Synchronization.Mutex`: struct, `@_rawLayout` inline storage, `let` binding, zero heap allocation, same `os_unfair_lock`. Plus coroutine accessor.

**`~Escapable` limitation**: The `Locked` view uses `~Copyable` only (not `~Escapable`). The `~Escapable` lifetime checker rejects `~Escapable` views accessed through class stored properties. `~Copyable` alone is sufficient — the `_read` coroutine scope prevents escape, `~Copyable` prevents aliasing.

**Migration path**: Existing `withLock` call sites continue working. New code uses `locked` accessor. The closure-based patterns ([MEM-OWN-010], [MEM-OWN-011]) remain valid for backward compatibility but are no longer the recommended approach for new code.

## Layer Model [IMPL-070]

**Closure-based (backward compatibility)**:
```
Layer 0: var slot: V? = value + .take()!     — inside Mutex extension only
Layer 1: withLock(consuming:), withLock(deposit:), Ownership.Slot  — general tooling
Layer 2: Bridge.push(), Channel.send()        — domain API (call site)
```

**Coroutine-based (end state)**:
```
Layer 1: StructMutex with @_rawLayout + Locked view with nonmutating _modify
Layer 2: _state.locked.value.field = consume element  — direct property access
```

No Layer 0. No `.take()!` anywhere. No closures. The mechanism is inside the Mutex implementation (`_read` coroutine + `os_unfair_lock`). The call site reads as pure intent.

## Future-Proofing

| Improvement | Closure path | Coroutine path |
|-------------|-------------|----------------|
| Consuming closures | Layer 0 simplified | N/A (no closures) |
| ~Copyable continuations | Void-signal → element-carrying | Same benefit |
| Implicit ~Copyable on extensions | Remove annotations | Same benefit |
| ~Escapable on class stored properties | N/A | Add `~Escapable` to Locked (stronger safety) |

## Outcome

**Status**: DECISION

**End-state pattern**: Coroutine-capable struct Mutex with `@_rawLayout` inline storage and `nonmutating _modify` Locked view. Direct property access through `_state.locked.value`. Zero closures, zero Optional wrappers, zero `.take()!`, zero heap allocation. Performance parity with `Synchronization.Mutex`.

**Backward compatibility**: Closure-based patterns ([MEM-OWN-010–012]) remain for existing code. `withLock` coexists on the same Mutex.

**Governed by**: [IMPL-070] — mechanism confined to Mutex internals, intent at call sites.

## References

### Stdlib Prior Art (verified 2026-03-31)
- `Synchronization.Mutex` — `@_rawLayout` `_Cell`, `borrowing func withLock`, `os_unfair_lock`
- `Result._consumingMap` — `(consuming Success) -> NewSuccess` closure parameter
- `CooperativeExecutor.forEachReadyJob` — `(consuming ExecutorJob) -> ()` closure parameter

### Ecosystem Prior Art
- `Memory.Inline<E, N>` — `@_rawLayout` inner `_Raw` struct, pointer via `withUnsafePointer(to: _storage)`
- `Property.View` — `~Copyable, ~Escapable` view with `mutating _read`/`_modify`
- `Async.Bridge.push()` — closure pattern (withLock(consuming:body:))
- `Async.Channel.Unbounded.Sender.send()` — state machine `inout Element?` pattern
- swift-system `Mach.Port` — `discard self`, `withBorrowedName(body:)`

### Experiments
- `mutex-coroutine-rawlayout` — 6/6 CONFIRMED: struct, let, @_rawLayout, nonmutating _modify, concurrent safety
- `mutex-coroutine-realistic` — 8/8 CONFIRMED: class Mutex with os_unfair_lock (superseded by rawlayout)
- `mutex-escapable-accessor` — 4/5 CONFIRMED: ~Escapable works but not with Synchronization.Mutex
- `bridge-noncopyable-ownership` — 9/9 CONFIRMED: closure-based Mutex extensions
- `inout-noncopyable-optional-closure-capture` — inout Element? pattern
- `optional-noncopyable-unwrap` — `_read`/`_modify` projection pattern
- `noncopyable-ergonomics-compiler-state.md` — compiler source investigation

### Community
- [Swift Forums: Missing reinitialization of closure capture after consume](https://forums.swift.org/t/missing-reinitialization-of-closure-capture-after-consume-for-closures-executed-only-once/76864) (Dec 2024)
