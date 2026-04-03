# TCA26 Patterns: Async Ecosystem Application

<!--
---
version: 1.1.0
last_updated: 2026-04-02
status: RECOMMENDATION
tier: 2
---
-->

## Context

This document applies the findings from `tca26-isolation-patterns-investigation.md` to the two async infrastructure packages in the Swift Institute ecosystem:

- **swift-async-primitives** (`/Users/coen/Developer/swift-primitives/swift-async-primitives/`) — Layer 1 primitives: Mutex, Callback, Continuation, Bridge, Channel, Broadcast, Promise/Gate, Barrier, Waiter, Publication, Completion, Timer.Wheel, Lifecycle. 12 targets, ~95 source files.
- **swift-async** (`/Users/coen/Developer/swift-foundations/swift-async/`) — Layer 3 foundations: Async.Stream (concrete type-erased stream), Async.Stream operators (~40 operators: merge, zip, combine.latest, debounce, throttle, scan, flatMap, etc.), isolation-preserving AsyncSequence operators (Map, Filter, CompactMap, FlatMap). 4 targets, ~90 source files.

Both packages have `NonisolatedNonsendingByDefault` enabled. The TCA26 investigation identified 10 patterns; this document evaluates each against the actual source of both packages, with code citations.

**Prior art in our corpus**: `callback-isolated-nonsending-design.md` (v3.1, IMPLEMENTED), `sending-expansion-audit.md` (ALL COMPLETE), `stream-isolation-preserving-operators.md`, `async-stream-sendable-requirement.md`, `modern-concurrency-conventions.md`, `nonsending-adoption-audit.md`, `ownership-transfer-conventions.md`.

## Question

For each TCA26 pattern (F1-F3 and patterns 4-9), is it already adopted in swift-async-primitives and swift-async? If not, is it applicable? Would adoption require breaking changes?

## Analysis

### F1: Isolation Unification via Protocol Abstraction

**TCA26 approach**: A single `_Core<State, Action>` protocol works under both `@MainActor Store` and custom `actor StoreActor`. The core manages state, children, hooks, and tasks. The isolation surface is plugged in separately via `isolation: (any Actor)?`.

**swift-async-primitives status: NOT APPLICABLE (domain mismatch)**

swift-async-primitives types are synchronization primitives (Mutex, Channel, Bridge, Promise, Barrier, Broadcast, Completion). They do not have an "isolation surface" that needs to be pluggable. Their isolation model is fundamentally different from TCA26:

- **Mutex, Bridge, Channel, Promise, Barrier, Broadcast, Publication**: Use internal `Async.Mutex<State>` (os_unfair_lock) for thread-safe state access. They are `Sendable` types accessed from any isolation domain. There is no "owning actor" to abstract over.
- **Completion**: Uses `Atomic<State>` (CAS machine) + `Async.Mutex<Continuation?>`. Again, no owning isolation.

These types are inherently cross-domain — they bridge between isolation domains rather than living within one. A protocol abstracting "which isolation domain owns this primitive" would be meaningless; the whole point is that any domain can use them.

**swift-async status: PARTIALLY APPLICABLE, PARTIALLY ADOPTED**

swift-async has a two-tier architecture that parallels TCA26's dual-surface pattern:

| Tier | Type | Closure Sendability | Isolation | Parallel to TCA26 |
|------|------|--------------------|-----------|--------------------|
| Concrete operators | `Async.Map<Base, Output>`, `Async.Filter<Base>`, etc. | Non-`@Sendable` (plain closures) | Caller-isolated via `#isolation` | `Store` surface (confined) |
| Type-erased stream | `Async.Stream<Element>` | `@Sendable` required | Concurrent (any isolation) | `StoreActor` surface (cross-domain) |

This is documented explicitly in the source:

```
// Async.Map is intentionally non-Sendable. The transform closures are
// nonisolated(nonsending) — they inherit the caller's isolation and may
// capture non-Sendable actor-isolated state. Claiming Sendable would be
// unsound. For Sendable pipelines, use Async.Stream.map (which
// requires @Sendable closures).
```
(`Async.Map.swift:85-89`, `Async.Filter.swift:88-92`)

However, unlike TCA26's shared `_Core` protocol, the two tiers do not share a protocol. Each concrete operator (`Async.Map`, `Async.Filter`, `Async.CompactMap`, `Async.FlatMap`) is an independent struct conforming to `AsyncSequence`, while `Async.Stream` is a separate type-erased concrete type. There is no shared "operator core" protocol that both tiers implement.

**Verdict**: The two-tier architecture is already in place. A shared protocol would add abstraction without benefit — `AsyncSequence` already serves as the unifying protocol. The concrete operators and `Async.Stream` serve fundamentally different roles (isolation-preserving vs concurrent), and unifying them would blur this intentional distinction.

---

### F2: Non-Sendable Closures for Confined Work

**TCA26 approach**: ALL internal closures (`postProcessingHooks`, `_QueuedTask.operation`, etc.) are plain closures, NOT `@Sendable`. Only boundary closures carry Sendable annotations.

**swift-async-primitives status: CORRECTLY DIVERGENT**

swift-async-primitives *correctly* uses `@Sendable` on all stored closures and callback parameters, because its types are cross-domain synchronization primitives. Every stored closure in this package genuinely crosses isolation boundaries:

| Type | Stored closure | `@Sendable`? | Justification |
|------|---------------|-------------|---------------|
| `Async.Continuation` | `callback: @Sendable (sending T) -> Void` | Yes | Continuation resumed from arbitrary thread after lock release |
| `Async.Continuation.Storage` | `.callback(@Sendable (sending T) -> Void)` | Yes | Same — stored in Mutex, resumed outside lock |
| `Async.Waiter.Resumption` | `_resume: @Sendable () -> Void` | Yes | Deferred resumption thunk, explicitly designed to run outside lock |
| `Async.Promise.wait` | `callback: @escaping @Sendable (sending Value) -> Void` | Yes | Callback invoked on fulfilling thread |
| `Async.Barrier.arrive` | `callback: @escaping @Sendable () -> Void` | Yes | Callback invoked when last party arrives (arbitrary thread) |
| `Async.Callback.init(wrapping:)` | `cps: @escaping @Sendable (...)` | Yes | CPS bridge — OS callback on arbitrary thread |

The one **non-Sendable** closure in swift-async-primitives is `Async.Callback.operation`:

```swift
let operation: nonisolated(nonsending) () async -> Value
```
(`Async.Callback.swift:45`)

This is the exact TCA26 F2 pattern — a confined closure that inherits caller isolation. The callback's `callAsFunction()` is `nonisolated(nonsending)` and the stored closure is `nonisolated(nonsending)`, so the entire chain preserves caller isolation without requiring Sendable.

The `map` and `flatMap` on `Async.Callback` also store plain closures:

```swift
public func map<NewValue>(
    _ transform: @escaping (Value) -> NewValue
) -> Async.Callback<NewValue> { ... }
```
(`Async.Callback.swift:89-93`)

**Verdict**: swift-async-primitives correctly applies `@Sendable` to genuinely boundary-crossing closures and correctly avoids it on `Async.Callback` (the one confined closure). This is the F2 pattern applied with domain-appropriate granularity. No changes needed.

**swift-async status: ADOPTED (two-tier architecture)**

The concrete `Async.Map`, `Async.Filter`, `Async.CompactMap`, `Async.FlatMap` operators store plain closures:

```swift
enum Transform {
    case sync((Base.Element) -> Output)
    case async((Base.Element) async -> Output)
}
```
(`Async.Map.swift:30-33`)

No `@Sendable` on the enum payloads. These closures are confined — they run on the caller's isolation domain via the `#isolation` parameter:

```swift
public mutating func next(
    isolation actor: isolated (any Actor)? = #isolation
) async -> Output? {
    guard let element = try? await baseIterator.next(isolation: actor) else { ... }
    switch transform {
    case .sync(let f): return f(element)
    case .async(let f): return await f(element)
    }
}
```
(`Async.Map.swift:57-68`)

Meanwhile, `Async.Stream` operators require `@Sendable` closures because `Async.Stream<Element>` is itself `Sendable` and operators create child tasks:

```swift
public func callAsFunction<U: Sendable>(
    _ transform: @escaping @Sendable (Element) -> U
) -> Async.Stream<U> { ... }
```
(`Async.Stream.Map.swift:52-54`)

The `Async.Stream.Transducer` stores three `@Sendable` closures (`initial`, `step`, `complete`) because the transducer itself is `Sendable` and its closures run inside task groups.

**Verdict**: Fully adopted. The non-Sendable/Sendable split aligns exactly with TCA26's pattern of confined vs boundary closures.

---

### F3: Synchronous Mutation with Async Task Collection

**TCA26 approach**: `send()` synchronously routes and mutates state, then `runHooks()` drains the task queue in a two-phase loop, collecting returned tasks. Caller awaits via `[Task].all`.

**swift-async-primitives status: ADOPTED (deferred resumption pattern)**

All swift-async-primitives types follow a pattern that is structurally identical to F3:

1. **Synchronous mutation under lock** — compute state transition and collect side effects
2. **Side effects executed outside lock** — resume continuations, invoke callbacks

This is formalized in the `Async.Waiter.Resumption` type:

```
// INVARIANT: Continuations are NEVER resumed while holding a lock.
// Under lock, compute outcomes and create Resumption instances.
// After releasing the lock, call resume() on each instance.
```
(`Async.Waiter.Resumption.swift:17-19`)

Concrete examples:

**Async.Bridge.push** (synchronous mutation + deferred continuation resume):
```swift
public func push(_ element: consuming sending Element) {
    let continuationToResume: CheckedContinuation<Void, Never>? =
        _state.withLock(consuming: element) { state, element in
            // ... synchronous state mutation ...
            return cont  // collected for outside-lock resume
        }
    continuationToResume?.resume()  // side effect outside lock
}
```
(`Async.Bridge.swift:88-106`)

**Async.Channel.Bounded.State** (pure state machine returning action enums):
```swift
mutating func send(_ element: inout Element?) -> Send.Decision {
    // Purely synchronous state transition — no side effects
    switch status {
    case .open:
        if let receiver = receiver { return .deliverToReceiver(...) }
        if buffer.count < capacity { return .buffered }
        return .suspend(flag: ...)
    case .closed, .finished:
        return .rejectClosed
    }
}
```
(`Async.Channel.Bounded.State.swift:192-213`)

The Channel's state machine is particularly aligned with F3: it returns `Decision` and `Action` enums that the caller interprets outside the lock. The `Storage.handleReceive` and `Storage.handleSend` static methods consume these actions and perform side effects (resume continuations, store elements in slots).

**Async.Completion** uses an even more granular approach: Atomic CAS for state transitions + Mutex for continuation storage:
```swift
public func complete(_ value: sending Success) throws(Transition.Error) {
    let (exchanged, _) = _state.compareExchange(...)  // synchronous CAS
    guard exchanged else { throw .alreadyDone }
    let cont = _continuation.withLock { ... }  // extract under lock
    cont?.resume(returning: .success(value))   // side effect outside lock
}
```
(`Async.Completion.swift:111-124`)

**Verdict**: This pattern is deeply embedded in the architecture. The Channel's `State` type with its `Decision`/`Action` enum return pattern is more rigorous than TCA26's approach — it enforces the separation structurally (pure state machine returns value types, caller performs effects) rather than procedurally (drain loop).

**swift-async status: ADOPTED (actor-based variant)**

swift-async stream operators use actors as state containers, where the actor itself provides the serialization guarantee:

```swift
actor State {
    var queue: Queue<Element>.Small<4> = .init()
    var continuation: CheckedContinuation<Element?, Never>?
    // ...
    func send(_ element: sending Element) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: element)  // resume inside actor
        } else {
            queue.enqueue(element)
        }
    }
}
```
(`Async.Stream.Merge.State.swift:36-44`)

This differs from the primitives layer: actors resume continuations *inside* the isolation boundary, which is safe because actor reentrancy is cooperative. This is the same trade-off TCA26 makes — their hooks and tasks run within the core's isolation domain.

---

### Pattern 4: `nonisolated(nonsending)` on Public API Methods

**TCA26 approach**: Public methods like `callAsFunction`, `receive`, `dismount` are annotated `nonisolated(nonsending)` to inherit caller isolation.

**swift-async-primitives status: ADOPTED (all async entry points)**

Every async public method in swift-async-primitives uses `nonisolated(nonsending)`:

| Method | File | Line |
|--------|------|------|
| `Async.Bridge.next()` | `Async.Bridge.swift` | 118 |
| `Async.Promise.value()` | `Async.Promise.swift` | 152 |
| `Async.Gate.wait()` | `Async.Gate.swift` | 77 |
| `Async.Barrier.arrive()` | `Async.Barrier.swift` | 152 |
| `Async.Callback.callAsFunction()` | `Async.Callback.swift` | 77 |
| `Async.Channel.Bounded.Sender.send()` | `Async.Channel.Bounded.Sender.swift` | 105 |
| `Async.Channel.Bounded.Receiver.receive()` | `Async.Channel.Bounded.Receiver.swift` | 71 |
| `Async.Channel.Unbounded.Receiver.receive()` | `Async.Channel.Unbounded.Receiver.swift` | 71 |
| `Async.Channel.Bounded.Elements.Iterator.next()` | `Async.Channel.Bounded.Elements.Iterator.swift` | 31 |
| `Async.Channel.Unbounded.Elements.Iterator.next()` | `Async.Channel.Unbounded.Elements.Iterator.swift` | 31 |
| `Async.Broadcast.Subscription.AsyncIterator.next()` | `Async.Broadcast.Subscription.AsyncIterator.swift` | 29 |

`Async.Callback` also stores its closure with the `nonisolated(nonsending)` annotation:
```swift
let operation: nonisolated(nonsending) () async -> Value
```
(`Async.Callback.swift:45`)

**swift-async status: ADOPTED (correctly uses protocol requirement signature)**

The concrete `AsyncSequence` operators use the `isolation:` parameter:

```swift
public mutating func next(
    isolation actor: isolated (any Actor)? = #isolation
) async -> Output? { ... }
```
(`Async.Map.swift:57-59`, `Async.Filter.swift:57-59`, `Async.CompactMap.swift:61-63`, `Async.FlatMap.swift:66-68`)

This is NOT the deprecated `isolation:` pattern — it is the `AsyncIteratorProtocol` requirement signature. The protocol defines `next(isolation actor: isolated (any Actor)? = #isolation)` as its witness. Conforming types MUST use this signature. The "deprecated `isolation:` parameter" finding from `nonsending-ecosystem-migration-audit.md` applies to free functions and non-protocol methods (e.g., `Async.Callback.callAsFunction` before its migration), not to `AsyncIteratorProtocol` conformances.

The `#isolation` parameter is threaded through to `baseIterator.next(isolation: actor)`, ensuring the entire chain preserves caller isolation. This is the correct and canonical approach for `AsyncIteratorProtocol` implementations.

The `Async.Stream.Iterator.next()` method has no special annotation — it delegates to the stored `@Sendable () async -> Element?` closure, so isolation preservation is not applicable (it runs on the cooperative pool).

**Verdict**: Both packages are fully adopted. swift-async-primitives uses `nonisolated(nonsending)` on non-protocol async methods. swift-async's concrete operators correctly use the `AsyncIteratorProtocol` witness signature with `#isolation` parameter forwarding.

---

### Pattern 5: `sending @escaping @isolated(any)` + `@_inheritActorContext(always)` for Task Creation

**TCA26 approach**: Task-creating APIs use `sending @escaping @isolated(any)` closures combined with `@_inheritActorContext(always)` to ensure the task inherits the caller's isolation.

**swift-async-primitives status: NOT USED, NOT APPLICABLE**

swift-async-primitives does not create tasks. It provides primitives that *support* task coordination (continuations, channels, barriers), but the task creation is left to the consumer. This is architecturally correct — a Layer 1 primitive should not mandate task creation patterns.

**swift-async status: NOT USED, POTENTIALLY APPLICABLE**

`Async.Stream` operators that spawn child tasks use bare `Task { ... }`:

```swift
let task1 = Task {
    for await element in a {
        await state.send(element)
    }
    await state.complete()
}
```
(`Async.Stream.Merge.swift:44-48`)

These tasks are created inside `@Sendable () -> Iterator` closures (the `_makeIterator` closure), which means they inherit no isolation — they run on the cooperative pool. This is intentional: `Async.Stream` is `Sendable` and its operators are designed for concurrent execution. Using `@_inheritActorContext` would be incorrect here; it would confine stream iteration to the creating actor.

**Verdict**: Not applicable. The `Async.Stream` operators need concurrent task execution, not isolation inheritance. The concrete `Async.Map`/`Async.Filter` operators achieve isolation inheritance through `#isolation` parameter forwarding, not through task creation.

---

### Pattern 7: `LockIsolated` with `inout sending` Return for Lock-Protected Value Transfer

**TCA26 approach**: Values behind locks are returned with `inout sending` to enable safe transfer out of the locked scope.

**swift-async-primitives status: ADOPTED (Mutex.withLock signature)**

`Async.Mutex.withLock` uses the exact `inout sending` pattern:

```swift
public borrowing func withLock<T: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending T
) throws(E) -> sending T { ... }
```
(`Async.Mutex.swift:117-119`)

This is the canonical pattern: the body receives the protected value as `inout sending` (exclusive mutable access with send permission) and returns `sending T` (the return value is safe to transfer out of the lock scope).

The ownership extensions go further:

```swift
public func withLock<V: ~Copyable & Sendable, T: ~Copyable, E: Error>(
    consuming value: consuming sending V,
    body: (inout sending Value, consuming V) throws(E) -> sending T
) throws(E) -> sending T { ... }
```
(`Async.Mutex+Ownership.swift:65-68`)

This combines `inout sending` for the locked state with `consuming sending` for an additional value transferred into the lock scope — a richer pattern than TCA26's `LockIsolated`.

**Async.Channel.Bounded.Storage** and **Async.Channel.Unbounded.Storage** both forward the `inout sending` pattern:

```swift
func withLock<T: ~Copyable, E: Swift.Error>(
    _ body: (inout sending Async.Channel<Element>.Bounded.State) throws(E) -> sending T
) throws(E) -> sending T { ... }
```
(`Async.Channel.Bounded.Storage.swift:44`)

**Verdict**: Fully adopted, with extensions beyond what TCA26 does (ownership transfer variants).

---

### Pattern 9: Conservative ~Copyable (Only on Return Types)

**TCA26 approach**: ~Copyable is used conservatively — only on `withState<R: ~Copyable>` return type, no `consuming`/`borrowing` annotations.

**swift-async-primitives status: FAR BEYOND TCA26 (extensive ~Copyable adoption)**

swift-async-primitives uses ~Copyable pervasively, not conservatively:

| Type | `~Copyable` | Purpose |
|------|-------------|---------|
| `Async.Mutex<Value: ~Copyable>` | Generic parameter + self | Protects ~Copyable values |
| `Async.Mutex._Value` | Struct | Raw storage for ~Copyable value |
| `Async.Mutex._Lock` | Struct | Raw storage for lock |
| `Async.Bridge<Element: ~Copyable & Sendable>` | Generic parameter | Supports ~Copyable element transfer |
| `Async.Bridge.State` | Struct | Internal state is move-only |
| `Async.Bridge._Take` | Enum | Consume-once dequeue result |
| `Async.Channel.Bounded` | Struct | Channel identity is move-only |
| `Async.Channel.Bounded.State` | Struct | State machine is move-only |
| `Async.Channel.Bounded.State.Send.Decision` | Enum | Consumed exactly once |
| `Async.Channel.Bounded.State.Send.Action` | Enum | Consumed exactly once |
| `Async.Channel.Bounded.State.Receive.Action` | Enum | Consumed exactly once |
| `Async.Timer.Wheel<C>` | Struct | Timer wheel is move-only |
| `Async.Timer.Wheel.Storage` | Struct | Storage is move-only |
| `Async.Waiter.Resumption` | Struct | Consumed exactly once (`consuming func resume()`) |

The ownership annotations are also extensively used:

```swift
public func push(_ element: consuming sending Element)           // Bridge
public func send(_ element: consuming sending Element)           // Channel
public init(_ value: consuming sending Value)                     // Mutex
consuming func take() -> Take                                     // Channel.Bounded
public consuming func resume()                                    // Waiter.Resumption
```

The three canonical ownership patterns from `ownership-transfer-conventions.md` are all represented:
- **Always-Consume**: `Async.Waiter.Resumption.resume()` — consumed on every path
- **Maybe-Consume**: `Async.Bridge.push()` — element consumed on success, dropped on finished
- **Borrow-Only**: `Async.Mutex.withLock` body parameter — borrows for mutation

**Verdict**: swift-async-primitives is far more advanced than TCA26 in ~Copyable adoption. This is expected — TCA26 is an application framework where State/Action are user-defined (and may not be ~Copyable), while swift-async-primitives is infrastructure where move-only semantics provide correctness guarantees.

**swift-async status: NOT ADOPTED (Sendable constraint prevents it)**

`Async.Stream<Element: Sendable>` requires `Element: Sendable`, which implies `Element: Copyable` in practice (since ~Copyable types that are also Sendable are rare). The concrete operators (`Async.Map`, etc.) have no ~Copyable usage.

This is architecturally consistent: `Async.Stream` is a type-erased concurrent stream where elements are shared across tasks. The concrete operators could theoretically support ~Copyable elements, but this would require the `stream-isolation-preserving-operators` design to be fully implemented first.

---

### Other Patterns

**Pattern 4 (nonisolated(nonsending))**: Covered above. Fully adopted in both packages — primitives use `nonisolated(nonsending)` on non-protocol methods, swift-async correctly uses the `AsyncIteratorProtocol` witness signature with `#isolation` parameter forwarding.

**Pattern 5 (@isolated(any) + @_inheritActorContext)**: Not applicable (see above).

**Pattern 6 (PostProcessingHooks as plain closures)**: Not directly applicable — swift-async-primitives has no hook system. The closest analog is `Async.Waiter.Resumption`, which is a ~Copyable value type consumed once (stronger guarantee than TCA26's plain closures).

**Pattern 8 (Two-phase drain loop)**: Adopted structurally in the deferred resumption pattern. The Channel state machine's `Decision`/`Action` enum return pattern is more rigorous than TCA26's procedural drain loop.

**Pattern 10 (No isolated(any) on internal types)**: Adopted. Neither package uses `isolated(any)` on internal types. swift-async-primitives uses `Mutex` for synchronization, not actor isolation. swift-async uses plain actors for stream operator state.

## Comparison Matrix

| Pattern | Description | swift-async-primitives | swift-async |
|---------|-------------|----------------------|-------------|
| **F1** | Isolation unification via protocol | NOT APPLICABLE | ADOPTED (two-tier, no shared protocol needed) |
| **F2** | Non-Sendable closures for confined work | ADOPTED (`Async.Callback`); correctly `@Sendable` elsewhere | ADOPTED (concrete operators: non-Sendable; Stream: @Sendable) |
| **F3** | Synchronous mutation + async task collection | ADOPTED (deferred resumption pattern) | ADOPTED (actor-based variant) |
| **P4** | `nonisolated(nonsending)` on public API | ADOPTED (all 11 async entry points) | ADOPTED (`#isolation` is the `AsyncIteratorProtocol` requirement) |
| **P5** | `@isolated(any)` + `@_inheritActorContext` | NOT APPLICABLE (no task creation) | NOT APPLICABLE (concurrent tasks intentional) |
| **P7** | `inout sending` for lock value transfer | ADOPTED (Mutex.withLock + ownership extensions) | N/A (no Mutex usage) |
| **P9** | ~Copyable adoption | FAR BEYOND TCA26 (16+ types) | NOT ADOPTED (Sendable constraint) |
| **P6** | Plain closure hooks | NOT APPLICABLE (no hooks) | N/A |
| **P8** | Two-phase drain loop | ADOPTED (Decision/Action enums, stronger) | N/A |
| **P10** | No `isolated(any)` on internals | ADOPTED | ADOPTED |

## Outcome

**RECOMMENDATION**

Both async packages are highly aligned with TCA26 patterns — in several cases (F3 deferred resumption, P7 ownership extensions, P9 ~Copyable) they exceed TCA26's sophistication. swift-async's two-tier architecture (concrete isolation-preserving operators vs type-erased concurrent stream) is a domain-appropriate application of F1/F2. No code changes are recommended.

No actionable code changes emerge. The original R-1 (migrate concrete operators from `#isolation` to `nonisolated(nonsending)`) was **incorrect**: the `isolation actor: isolated (any Actor)? = #isolation` parameter on `next()` is the `AsyncIteratorProtocol` requirement signature, not a deprecated convention. Removing it would break protocol conformance. The `#isolation` parameter forwarding through `baseIterator.next(isolation: actor)` is the correct and canonical pattern for `AsyncIteratorProtocol` implementations.

### R-1: WITHDRAWN (protocol requirement, not deprecated pattern)

The `isolation:` parameter on `Async.Map.Iterator.next()`, `Async.Filter.Iterator.next()`, `Async.CompactMap.Iterator.next()`, and `Async.FlatMap.Iterator.next()` is the `AsyncIteratorProtocol` witness signature. It is NOT the deprecated `isolation:` parameter pattern. The deprecated pattern applies to free functions and non-protocol methods (e.g., `Async.Callback.callAsFunction` before its migration to `nonisolated(nonsending)`). Protocol conformance signatures must match the protocol requirement.

**Distinction**: `nonisolated(nonsending) func next()` CAN satisfy `AsyncIteratorProtocol.next(isolation:)` via witness thunk (confirmed 2026-03-31), but the explicit `isolation:` parameter is the canonical approach for protocol conformances. It is clearer, avoids thunk overhead, and explicitly threads isolation through to downstream `next()` calls on base iterators.

### R-2: No further F2 changes needed

Both packages correctly partition `@Sendable` vs plain closures. swift-async-primitives applies `@Sendable` only to genuinely boundary-crossing closures (continuations, callbacks invoked from arbitrary threads). `Async.Callback` correctly uses `nonisolated(nonsending)` for its stored closure. swift-async's two-tier architecture correctly uses plain closures for isolation-preserving operators and `@Sendable` closures for concurrent stream operators.

### R-3: No F1 unification protocol needed

The two-tier architecture in swift-async (concrete operators + Async.Stream) does not benefit from a shared protocol. `AsyncSequence` already serves as the unifying protocol. Adding a domain-specific "operator core" protocol would add abstraction without payoff.

### R-4: No F3 changes needed

The deferred resumption pattern in swift-async-primitives is more rigorous than TCA26's procedural drain loop. The Channel state machine's `Decision`/`Action` enum approach enforces the mutation/effect separation structurally via the type system.

### R-5: ~Copyable in swift-async deferred to stream redesign

`Async.Stream` requires `Element: Sendable` (which effectively requires Copyable). Adding ~Copyable support is blocked by the broader stream isolation redesign tracked in `async-stream-sendable-requirement.md` and `concrete-async-operator-types.md`. This is not a TCA26-motivated change; it is driven by the stream isolation preservation work.

## References

- `tca26-isolation-patterns-investigation.md` — Source investigation (10 patterns, this document's input)
- `callback-isolated-nonsending-design.md` (v3.1) — Async.Callback nonsending design, IMPLEMENTED
- `nonsending-adoption-audit.md` — Ecosystem-wide `nonisolated(nonsending)` audit
- `sending-expansion-audit.md` — 16 `sending` sites in swift-async-primitives, ALL COMPLETE
- `modern-concurrency-conventions.md` — Isolation hierarchy, Sendable minimization
- `ownership-transfer-conventions.md` — Three canonical ~Copyable ownership patterns
- `async-stream-sendable-requirement.md` — Stream Element Sendable constraint investigation
- `stream-isolation-preserving-operators.md` — Two-tier concrete/erased operator architecture
- `concrete-async-operator-types.md` — Option C concrete operator types design
- `noncopyable-ecosystem-state.md` — ~Copyable compiler state consolidation
