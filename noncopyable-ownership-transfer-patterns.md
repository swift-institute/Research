# ~Copyable Ownership Transfer Patterns

<!--
---
version: 1.0.0
last_updated: 2026-03-31
status: DECISION
tier: 2
workflow: Investigation [RES-001]
trigger: Ecosystem-wide ~Copyable usage through Mutex closures needs canonical patterns
scope: All ~Copyable code across swift-primitives, swift-standards, swift-foundations
---
-->

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

## Future-Proofing

| Compiler Improvement | Layer 0 | Layer 1 | Layer 2 |
|---------------------|---------|---------|---------|
| Consuming closures / once-only closures | Eliminated | `withLock(consuming:)` impl simplifies (no Optional) | **API unchanged** |
| ~Copyable continuations | — | Void-signal → element-carrying | **API unchanged** |
| Implicit ~Copyable on extensions | — | Remove `where Value: ~Copyable` | **API unchanged** |
| Better Optional<~Copyable> unwrapping | `.take()!` → direct unwrap | Impl simplifies | **API unchanged** |

Layer 2 API never changes. The entire purpose of the layer model is that internal improvements don't propagate to consumers.

## Outcome

**Status**: DECISION

Three canonical ownership transfer patterns for `~Copyable` values through `Mutex.withLock`:

1. **Always-Consume** ([MEM-OWN-010]) — `withLock(consuming:body:)`, body gets consuming parameter
2. **Maybe-Consume** ([MEM-OWN-011]) — state machine takes `inout Element?`, decides per-path
3. **Borrow-Only** — standard `withLock`, no special infrastructure

Cross-cutting: **Action Enum Dispatch** ([MEM-OWN-012]) — lock produces `~Copyable` action, `switch consume` outside lock.

Governed by **Layer Model** ([IMPL-070]) — `.take()!` confined to Layer 0/1 infrastructure, never at Layer 2 call sites.

## References

### Stdlib Prior Art (verified 2026-03-31)
- `Mutex.withLock` — `inout sending` parameter, `unsafe body(&value._address.pointee)`
- `Result._consumingMap` — `(consuming Success) -> NewSuccess` as closure parameter type
- `CooperativeExecutor.forEachReadyJob` — `(consuming ExecutorJob) -> ()` as closure parameter type

### Ecosystem Prior Art
- `Async.Bridge.push()` — Pattern 1 (always-consume via `withLock(consuming:body:)`)
- `Async.Channel.Unbounded.Sender.send()` — Pattern 2 (maybe-consume via `state.send(&opt)`)
- `Async.Channel.Bounded.Sender.send()` — Pattern 2
- `Async.Bridge.next()` — Action enum dispatch (`_Take`)
- swift-system `Mach.Port` — `discard self` for consuming, `withBorrowedName(body:)` for borrowing

### Research
- `noncopyable-ergonomics-compiler-state.md` — Compiler investigation, 5/6 pain points permanent
- `bridge-noncopyable-ownership` experiment — 9 variants, all CONFIRMED
- `inout-noncopyable-optional-closure-capture` experiment — `inout Element?` pattern validated
- `optional-noncopyable-unwrap` experiment — `_read`/`_modify` projection pattern

### Community
- [Swift Forums: Missing reinitialization of closure capture after consume](https://forums.swift.org/t/missing-reinitialization-of-closure-capture-after-consume-for-closures-executed-only-once/76864) (Dec 2024)
