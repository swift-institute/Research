# `sending` Annotation Expansion Audit

<!--
---
date: 2026-02-25
scope: swift-async (foundations), swift-async-primitives (primitives)
status: COMPLETE
---
-->

## Background

The `sending` keyword annotates parameters and return values that transfer ownership across isolation boundaries. It enables the compiler to verify that values passed into or out of an actor are not retained by the caller after the transfer, preventing data races without requiring `Sendable` conformance in all cases.

### Existing Usage Baseline

`sending` is already applied in ~24 sites:

- **swift-effect-primitives**: `Effect.Continuation` resume methods (One, Multi)
- **swift-async-primitives**: `Async.Publication.init`, `Async.Publication.publish`
- **swift-async (Async Stream)**: `Merge.State.send`, `CombineLatest.State.updateA/updateB`, `FlatMap.Latest.State.receiveInner`, `Sample.State.updateLatest`, `WithLatestFrom.State.updateLatestOther`, `Replay.State.send`, `Replay.Subscription.receive/_receive`

### Audit Criteria

For each actor method, check whether:
1. A value crosses an isolation boundary (enters or exits the actor)
2. The parameter or return is not already annotated with `sending`
3. Adding `sending` would strengthen the ownership transfer contract

---

## Part 1: Async Stream State Actors (swift-async)

### 1.1 `Async.Stream.Scan.State` -- init takes `initial` without `sending`

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Scan.State.swift`
**Line**: 34

**Current signature**:
```swift
init(stream: Async.Stream<Element>, initial: Result, accumulator: @escaping @Sendable (Result, Element) -> Result)
```

**Why `sending` is appropriate**: The `initial` value is created outside the actor and transferred into actor-isolated storage (`self.state = initial`). The caller relinquishes ownership at the call site. Annotating `initial` as `sending` makes this transfer explicit and lets the compiler verify the caller does not retain a reference.

**Recommended**:
```swift
init(stream: Async.Stream<Element>, initial: sending Result, accumulator: @escaping @Sendable (Result, Element) -> Result)
```

**Public API propagation**: The public `scan(_:_:)` method at line 66 passes `initial` through to the actor init. It should also be annotated:
```swift
public func scan<Result: Sendable>(_ initial: sending Result, _ accumulator: ...) -> Async.Stream<Result>
```

---

### 1.2 `Async.Stream.Scan.State.next()` -- return crosses isolation boundary

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Scan.State.swift`
**Line**: 44

**Current signature**:
```swift
func next() async -> Result?
```

**Why `sending` is appropriate**: The `Result?` value is produced inside the actor and returned to the caller outside the actor. This is an isolation-boundary-crossing return. The actor should not retain exclusive access to the returned value after it leaves.

**Recommended**:
```swift
func next() async -> sending Result?
```

**Note**: This pattern applies broadly to ALL `next()` methods on ALL State actors. However, because `Element` is constrained to `Sendable` in `Async.Stream<Element: Sendable>`, the compiler already knows these values are safe to share. The `sending` annotation on returns is therefore **redundant for Sendable-constrained types** -- the compiler does not require it. This finding is **informational only** and does not require action for `next()` returns where `Element: Sendable`.

---

### 1.3 `Async.Stream.FlatMap.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.FlatMap.State.swift`

The `init` receives a `stream` and `transform` closure. The stream is `Sendable` (it's `Async.Stream<Element>` which is already `Sendable`). The transform closure is `@Sendable`. No non-Sendable values cross the boundary. **No action needed.**

---

### 1.4 `Async.Stream.FlatMap.State.Async` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.FlatMap.State.Async.swift`

Same analysis as 1.3. All values crossing the boundary are already `Sendable`-constrained. **No action needed.**

---

### 1.5 `Async.Stream.FlatMap.Latest.State.Async.receiveInner` -- MISSING `sending`

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.FlatMap.Latest.State.Async.swift`
**Line**: 91

**Current signature**:
```swift
func receiveInner(_ element: U) async
```

**Why `sending` is appropriate**: This method receives elements from a child `Task` (line 76-78) that iterates an inner stream. The element crosses from the child task's isolation into this actor. The sync counterpart `FlatMap.Latest.State.receiveInner` at line 96 of `Async.Stream.FlatMap.Latest.State.swift` already has `sending`. This is an inconsistency.

**Recommended**:
```swift
func receiveInner(_ element: sending U) async
```

---

### 1.6 `Async.Stream.Debounce.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Debounce.State.swift`

The `init` receives `stream` (Sendable) and `duration` (value type). The `next()` method operates within the actor. Elements flow through `box.next()` which already handles the isolation boundary via the `Iterator.Box` pattern. **No action needed.**

---

### 1.7 `Async.Stream.Throttle.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Throttle.State.swift`

Same pattern as Debounce. All init parameters are Sendable or value types. **No action needed.**

---

### 1.8 `Async.Stream.Buffer.Count.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Buffer.Count.State.swift`

Init receives stream (Sendable) and count (Int). **No action needed.**

---

### 1.9 `Async.Stream.Concat.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Concat.State.swift`

Init receives two streams, both Sendable. **No action needed.**

---

### 1.10 `Async.Stream.Distinct.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Distinct.State.swift`

Init receives stream (Sendable) and `areEqual` closure (@Sendable). **No action needed.**

---

### 1.11 `Async.Stream.Last.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Last.State.swift`

Init receives stream (Sendable). Element storage is internal to the actor. **No action needed.**

---

### 1.12 `Async.Stream.Unfold.State` -- init takes `initial` without `sending`

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Unfold.State.swift`
**Line**: 30

**Current signature**:
```swift
init(initial: S, next: @escaping @Sendable (S) async -> (Element, S)?)
```

**Why `sending` is appropriate**: The `initial` state value is created outside the actor and transferred into actor-isolated storage (`self.state = initial`). This is the same pattern as `Scan.State.init`. The caller relinquishes ownership.

**Recommended**:
```swift
init(initial: sending S, next: @escaping @Sendable (S) async -> (Element, S)?)
```

**Public API propagation**: The public `unfold(_:_:)` method at line 67 should also annotate:
```swift
public static func unfold<State: Sendable>(_ initial: sending State, _ next: ...) -> Self
```

---

### 1.13 `Async.Stream.Transducer.Run` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Transducer.State.swift`

The `init` receives `upstream` (Sendable stream) and `transducer` (Sendable struct with Sendable closures). All values crossing the boundary satisfy Sendable. **No action needed.**

---

### 1.14 `Async.Stream.State` -- init takes `elements` without `sending`

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.State.swift`
**Line**: 25

**Current signature**:
```swift
init(_ elements: [Element])
```

**Why `sending` is appropriate**: The array of elements is created outside the actor and stored in actor-isolated state. The caller transfers ownership.

**Recommended**:
```swift
init(_ elements: sending [Element])
```

**Note**: Since `Element: Sendable`, `[Element]` is also `Sendable`, so the compiler does not strictly require this annotation. This is a **low-priority, correctness-documentation** improvement.

---

### 1.15 `Async.Stream.Repeat.State` -- no missing annotations

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Repeat.State.swift`

Init receives `value` (Element, which is Sendable) and `count` (Int?). **No action needed.**

---

### 1.16 `Async.Stream.Replay.State` -- already has `sending` on `send`

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Replay.State.swift`

`send(_ element: sending Element)` at line 39 is already annotated. `subscribe()` returns a Subscription reference (Sendable actor). **No action needed.**

---

### 1.17 `Async.Stream.Merge.State` -- already has `sending` on `send`

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Merge.State.swift`

`send(_ element: sending Element)` at line 37 is already annotated. **No action needed.**

---

### 1.18 `Async.Stream.CombineLatest.State` -- already has `sending` on updates

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.CombineLatest.State.swift`

`updateA(_ value: sending A)` at line 43 and `updateB(_ value: sending B)` at line 49 are already annotated. **No action needed.**

---

### 1.19 `Async.Stream.Sample.State` -- already has `sending` on updateLatest

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Sample.State.swift`

`updateLatest(_ element: sending Element)` at line 59 is already annotated. **No action needed.**

---

### 1.20 `Async.Stream.WithLatestFrom.State` -- already has `sending` on updateLatestOther

**File**: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.WithLatestFrom.State.swift`

`updateLatestOther(_ element: sending Other)` at line 55 is already annotated. **No action needed.**

---

## Part 2: Async Primitives (swift-async-primitives)

### 2.1 `Async.Bridge` -- `push(_:)` missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Bridge.swift`
**Line**: 84

**Current signature**:
```swift
public func push(_ element: Element)
```

**Why `sending` is appropriate**: `push` transfers an element from the caller's isolation domain (synchronous, potentially any thread) into the bridge's internal mutex-protected buffer. The element then exits through `next()` into a different isolation domain (the async consumer). The caller should relinquish ownership at the call site.

**Recommended**:
```swift
public func push(_ element: sending Element)
```

**Note**: Since `Element: Sendable`, the compiler does not require this. However, the semantic intent -- "the caller transfers this value and must not retain exclusive access" -- is precisely what `sending` documents. This is **medium-priority** given Bridge's role as a sync-to-async handoff point where ownership transfer is the core contract.

---

### 2.2 `Async.Bridge` -- `push(_: [Element])` missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Bridge.swift`
**Line**: 110

**Current signature**:
```swift
public func push(_ elements: borrowing [Element])
```

**Why `sending` is NOT appropriate here**: This parameter is `borrowing`, meaning the caller explicitly retains ownership. The bridge copies elements into its buffer. `sending` and `borrowing` are mutually exclusive ownership annotations. **No action needed.**

---

### 2.3 `Async.Promise` -- `fulfill(_:)` missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Promise.swift`
**Line**: 83

**Current signature**:
```swift
public func fulfill(_ value: Value) -> Bool
```

**Why `sending` is appropriate**: `fulfill` transfers a value from the caller into the promise, which then delivers it to all waiting continuations in potentially different isolation domains. This is a classic ownership transfer -- the producer gives up the value, and one or more consumers receive it. The value crosses isolation boundaries.

**Recommended**:
```swift
public func fulfill(_ value: sending Value) -> Bool
```

---

### 2.4 `Async.Barrier` -- no missing annotations

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Barrier.swift`

`Barrier` coordinates via `Void` signals -- `arrive()` and `arrive(_:)` carry no payload values. The callback parameter is `@Sendable`. **No action needed.**

---

### 2.5 `Async.Channel.Bounded.Sender.send(_:)` -- missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Channel.Bounded.Sender.swift`
**Line**: 103

**Current signature**:
```swift
public func send(_ element: Element, isolation: isolated (any Actor)? = #isolation) async throws(Async.Channel<Element>.Error)
```

**Why `sending` is appropriate**: The sender transfers an element into the channel. The element may be delivered directly to a waiting receiver (different isolation domain) or buffered for later delivery. The caller relinquishes ownership at the send site. This is the fundamental ownership transfer operation of a channel.

**Recommended**:
```swift
public func send(_ element: sending Element, isolation: isolated (any Actor)? = #isolation) async throws(Async.Channel<Element>.Error)
```

---

### 2.6 `Async.Channel.Bounded.Sender.Send.immediate(_:)` -- missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Channel.Bounded.Sender.swift`
**Line**: 190

**Current signature**:
```swift
public func immediate(_ element: Element) throws(Async.Channel<Element>.Error)
```

**Why `sending` is appropriate**: Same rationale as `send(_:)` -- element transfers across isolation boundaries.

**Recommended**:
```swift
public func immediate(_ element: sending Element) throws(Async.Channel<Element>.Error)
```

---

### 2.7 `Async.Channel.Unbounded.Sender.send(_:)` -- missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Channel.Unbounded.Sender.swift`
**Line**: 66

**Current signature**:
```swift
public func send(_ element: Element) throws(Async.Channel<Element>.Error)
```

**Why `sending` is appropriate**: Same rationale as bounded send -- element transfers into the channel for delivery to a different isolation domain.

**Recommended**:
```swift
public func send(_ element: sending Element) throws(Async.Channel<Element>.Error)
```

---

### 2.8 `Async.Broadcast.send(_:)` -- missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Broadcast.swift`
**Line**: 111

**Current signature**:
```swift
public func send(_ element: Element)
```

**Why `sending` is appropriate**: The broadcast delivers the element to multiple subscribers across different isolation domains. The caller relinquishes ownership; each subscriber receives the value independently.

**Recommended**:
```swift
public func send(_ element: sending Element)
```

---

### 2.9 `Async.Completion.complete(_:)` -- missing `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Completion.swift`
**Line**: 166

**Current signature**:
```swift
public func complete(_ value: Success) throws(Transition.Error)
```

**Why `sending` is appropriate**: `complete` transfers a success value from the producer into the completion, which resumes a continuation in a different isolation domain. This is the same produce-and-transfer pattern as `Promise.fulfill`.

**Recommended**:
```swift
public func complete(_ value: sending Success) throws(Transition.Error)
```

---

### 2.10 `Async.Publication` -- already has `sending`

**File**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Publication.swift`

`init(_ initial: sending Value?)` at line 78 and `publish(_ value: sending Value)` at line 92 are already annotated. **No action needed.**

---

## Summary

### Findings Requiring Action

| # | File | Line | Method | Priority |
|---|------|------|--------|----------|
| 1 | `Async.Stream.Scan.State.swift` | 34 | `init(... initial: Result ...)` | Medium |
| 2 | `Async.Stream.FlatMap.Latest.State.Async.swift` | 91 | `receiveInner(_ element: U)` | High |
| 3 | `Async.Stream.Unfold.State.swift` | 30 | `init(initial: S ...)` | Medium |
| 4 | `Async.Bridge.swift` | 84 | `push(_ element: Element)` | Medium |
| 5 | `Async.Promise.swift` | 83 | `fulfill(_ value: Value)` | High |
| 6 | `Async.Channel.Bounded.Sender.swift` | 103 | `send(_ element: Element ...)` | High |
| 7 | `Async.Channel.Bounded.Sender.swift` | 190 | `immediate(_ element: Element)` | High |
| 8 | `Async.Channel.Unbounded.Sender.swift` | 66 | `send(_ element: Element)` | High |
| 9 | `Async.Broadcast.swift` | 111 | `send(_ element: Element)` | High |
| 10 | `Async.Completion.swift` | 166 | `complete(_ value: Success)` | Medium |

### Findings -- Informational Only (No Action Required)

| # | File | Line | Method | Reason |
|---|------|------|--------|--------|
| 11 | `Async.Stream.State.swift` | 25 | `init(_ elements: [Element])` | Element: Sendable makes [Element] Sendable; low value |
| 12 | All State actors | various | `next() -> T?` returns | Element: Sendable makes return Sendable; compiler does not require sending on return |

### Priority Rationale

- **High**: Inconsistency with existing patterns (finding 2), or core channel/broadcast/promise transfer operations where `sending` documents the fundamental ownership contract (findings 5-9).
- **Medium**: Actor init parameters where `sending` strengthens the contract but all types are already Sendable-constrained (findings 1, 3, 4, 10).

### Propagation Notes

When adding `sending` to internal actor methods, the corresponding public API entry points should also be updated to propagate the annotation through the call chain:

- `Async.Stream.scan(_:_:)` (line 66 of Scan.State.swift) -- `initial` parameter
- `Async.Stream.unfold(_:_:)` (line 67 of Unfold.State.swift) -- `initial` parameter
- Channel send methods are already public-facing (no propagation needed)
