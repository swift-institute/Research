# Stream Isolation Propagation

<!--
---
version: 1.1.0
last_updated: 2026-02-25
status: IN_PROGRESS
tier: 2
trigger: Pointfree #355 analysis — isolation propagation as foundation for deterministic execution
---
-->

## Context

Pointfree #355 (Feb 23, 2026) demonstrated that **isolation propagation is the key to deterministic, synchronous execution** in Swift concurrency. When caller isolation flows through every layer of a call chain, no thread hops occur, and effects execute synchronously. When isolation breaks — via `@Sendable` closures, new `Task` creations, actor boundaries, or task groups — thread hops and non-determinism are introduced.

Our `Async.Stream` at `/Users/coen/Developer/swift-foundations/swift-async/` provides 40+ operators that compose into pipelines. The fundamental question is: at each step in a composed pipeline, does isolation propagate from the caller, or does it break?

This matters because if a `@MainActor` caller writes:
```swift
stream.map { updateUI($0) }.filter { $0.isValid }
```
...they expect both closures to run on the main actor. If isolation breaks, those closures run on arbitrary executors, causing data races or requiring explicit `@MainActor` annotations at every closure.

## Question

How does isolation propagate through composed `Async.Stream` pipelines, and where does it break?

## Experiment Validation

Empirical testing in `swift-institute/Experiments/nonsending-blocker-validation/` and `swift-institute/Experiments/nonsending-blocker-validation-negative/` revealed critical constraints that refine the original analysis.

### Key Finding: `nonisolated(nonsending)` is async-only

The Swift compiler rejects `nonisolated(nonsending)` on non-async function types with the diagnostic: "cannot use 'nonisolated(nonsending)' on non-async function type". This means synchronous closures — the kind used by `map`, `filter`, `scan`, `compactMap`, `reduce`, `distinctUntilChanged`, and all other sync operator variants — **cannot be made nonsending**. The `nonisolated(nonsending)` mechanism only applies to `async` function types.

This has three consequences:

1. **Sync operator closures are permanently isolation-breaking.** There is no language mechanism, current or proposed, that would allow a synchronous closure parameter to inherit caller isolation. The original analysis identified `@Sendable` on `_next` as the root cause; the experiment reveals a second, independent root cause: sync closures cannot carry isolation context regardless of how `_next` is declared.

2. **Only async operator variants could theoretically benefit.** `map(async:)`, `filter(async:)`, `compactMap(async:)`, and `flatMap` accept async closures that could in principle be `nonisolated(nonsending)`. However, they remain blocked by the `Iterator._next: @Sendable` root cause (Layer 1 in the analysis below).

3. **A nonsending stream variant would require all-async closures.** Even if `_next` were made nonsending, a hypothetical isolation-preserving stream could only accept async closures for transforms and predicates. This is a significant ergonomic penalty — users would write `stream.map { await transform($0) }` instead of `stream.map { transform($0) }` — and it undermines the primary use case where sync closures are the common path.

### Correction: Continuation and cancellation handler isolation

The original analysis implicitly included `withCheckedContinuation` and `withTaskCancellationHandler` in the isolation-breaking chain. Empirical testing confirms these already propagate caller isolation correctly — `withCheckedContinuation` uses `#isolation` and `withTaskCancellationHandler` uses `nonisolated(nonsending)` for its operation closure. The isolation breaks occur at actor boundaries and `@Sendable` closures, not at continuation or cancellation handler call sites.

## Analysis

### Core Stream Type

The fundamental design of `Async.Stream` is built on two `@Sendable` closures:

**`Async.Stream` (line 50-66 of `Async.Stream.swift`):**
```swift
public struct Stream<Element: Sendable>: AsyncSequence, Sendable {
    let _makeIterator: @Sendable () -> Iterator

    public init(_ makeIterator: @escaping @Sendable () -> Iterator) {
        self._makeIterator = makeIterator
    }
}
```

**`Async.Stream.Iterator` (line 18-29 of `Async.Stream.Iterator.swift`):**
```swift
public struct Iterator: AsyncIteratorProtocol, Sendable {
    let _next: @Sendable () async -> Element?

    public init(_ next: @escaping @Sendable () async -> Element?) {
        self._next = next
    }
}
```

**Critical observation**: Both the iterator factory (`_makeIterator`) and the iteration function (`_next`) are `@Sendable` closures. This is the root of all isolation breaks.

A `@Sendable` closure cannot capture mutable state from an isolation domain. More critically for our analysis, a `@Sendable` closure **severs the caller's isolation context**. When the caller invokes `_next()`, the closure executes in a **nonisolated context**, not in the caller's isolation domain.

**`Async.Stream.Iterator.Box` (line 37 of `Async.Stream.Iterator.Box.swift`):**
```swift
typealias Box<I: AsyncIteratorProtocol> = Ownership.Mutable<I>.Unchecked
```

This uses `@unchecked Sendable` to bypass the compiler's Sendable checking, allowing non-Sendable iterators to be captured in `@Sendable` closures. The safety contract is "single-consumer only" — a runtime invariant with no compiler enforcement. This is the escape hatch that makes the entire `@Sendable` closure design work, but it means the compiler cannot reason about isolation flow through the Box.

### Operator Classification

#### Isolation Behavior Categories

**ISOLATION-BREAKING (always)**: Creates a new isolation domain. Caller's isolation does not flow through.

**ISOLATION-BREAKING via `@Sendable`**: The closure parameter is `@Sendable`, which severs the caller's isolation even if no actor or task is involved. The closure runs in a nonisolated context.

**ISOLATION-BREAKING via actor**: State is held in an internal actor. Calls to `await state.next()` hop to the actor's executor.

**ISOLATION-BREAKING via Task**: Creates a new unstructured `Task`, which inherits the actor context but creates a new task context.

**ISOLATION-BREAKING via TaskGroup**: Uses `withTaskGroup`/`withThrowingTaskGroup`, creating child tasks on potentially different executors.

#### Complete Operator Table

| Operator | Category | Isolation Behavior | Mechanism | Nonsending Fixable? |
|----------|----------|-------------------|-----------|---------------------|
| **Simple Transforms** | | | | |
| `map` (sync) | Transform | **BREAKS** | `@Sendable` closure + `@Sendable` `_next` | **No** — sync closures cannot be nonsending |
| `map` (async) | Transform | **BREAKS** | `@Sendable` closure + `@Sendable` `_next` | Blocked by `@Sendable` `_next` |
| `filter` (sync) | Transform | **BREAKS** | `@Sendable` closure + `@Sendable` `_next` | **No** — sync closures cannot be nonsending |
| `filter` (async) | Transform | **BREAKS** | `@Sendable` closure + `@Sendable` `_next` | Blocked by `@Sendable` `_next` |
| `compactMap` (sync) | Transform | **BREAKS** | `@Sendable` closure + `@Sendable` `_next` | **No** — sync closures cannot be nonsending |
| `compactMap` (async) | Transform | **BREAKS** | `@Sendable` closure + `@Sendable` `_next` | Blocked by `@Sendable` `_next` |
| `reduce` | Terminal | **BREAKS** | `@Sendable` closure | **No** — sync closure cannot be nonsending |
| **Stateful Transforms** | | | | |
| `scan` | Stateful | **BREAKS** | `@Sendable` closure + actor `State` | **No** — sync closure + actor hop |
| `distinctUntilChanged` | Stateful | **BREAKS** | `@Sendable` predicate + actor `State` | **No** — sync predicate + actor hop |
| `distinctUntilChanged(by:)` | Stateful | **BREAKS** | `@Sendable` key fn + actor `State` | **No** — sync key fn + actor hop |
| `transduce` | Stateful | **BREAKS** | `@Sendable` closures + actor `Run` | **No** — sync closures + actor hop |
| **Subsequence** | | | |
| `drop(count)` | Subsequence | **BREAKS** | actor `Drop.Count` |
| `drop.while` | Subsequence | **BREAKS** | `@Sendable` predicate + actor `Drop.While` |
| `prefix(count)` | Subsequence | **BREAKS** | actor `Prefix.Count` |
| `prefix.while` | Subsequence | **BREAKS** | `@Sendable` predicate + actor `Prefix.While` |
| `first()` | Subsequence | **BREAKS** | Composes `prefix(1)` |
| `first(where:)` | Subsequence | **BREAKS** | Composes `filter` + `first()` |
| `last()` | Subsequence | **BREAKS** | actor `Last.State` |
| `last(where:)` | Subsequence | **BREAKS** | Composes `filter` + `last()` |
| **Multi-Stream** | | | |
| `merge` | Combinator | **BREAKS** | 2x `Task` + actor `Merge.State` |
| `zip` | Combinator | **BREAKS** | `async let` (child tasks) |
| `combineLatest` | Combinator | **BREAKS** | 2x `Task` + actor `CombineLatest.State` |
| `concat` | Combinator | **BREAKS** | actor `Concat.State` |
| `withLatestFrom` | Combinator | **BREAKS** | `Task` + actor `WithLatestFrom.State` |
| `sample.on` | Combinator | **BREAKS** | `Task` + actor `Sample.State` |
| **FlatMap** | | | |
| `flatMap` (sync) | FlatMap | **BREAKS** | `@Sendable` closure + actor `FlatMap.State` |
| `flatMap` (async) | FlatMap | **BREAKS** | `@Sendable` closure + actor `FlatMap.State.Async` |
| `flatMapLatest` (sync) | FlatMap | **BREAKS** | `@Sendable` closure + `Task` + actor `FlatMap.Latest.State` |
| `flatMapLatest` (async) | FlatMap | **BREAKS** | `@Sendable` closure + `Task` + actor `FlatMap.Latest.State.Async` |
| **Temporal** | | | |
| `debounce` | Temporal | **BREAKS** | `withTaskGroup` + `Task.sleep` + actor `Debounce.State` |
| `throttle` | Temporal | **BREAKS** | `ContinuousClock` + actor `Throttle.State` |
| `delay` | Temporal | **BREAKS** | `Task.sleep` in `@Sendable` `_next` |
| `timeout` | Temporal | **BREAKS** | `withThrowingTaskGroup` + `Task.sleep` |
| `buffer.time` | Temporal | **BREAKS** | `withTaskGroup` + `Task.sleep` + actor `Buffer.Time.State` |
| `buffer.countOrTime` | Temporal | **BREAKS** | `withTaskGroup` + `Task.sleep` + actor `Buffer.CountOrTime.State` |
| **Sharing** | | | |
| `share` | Sharing | **BREAKS** | `Task` + `Broadcast` (crosses isolation) |
| `multicast` | Sharing | **BREAKS** | `Task` (in `connect()`) + `Broadcast` |
| `replay` | Sharing | **BREAKS** | `Task` + actor `Replay.State` + actor `Replay.Subscription` |
| **Buffering** | | | |
| `buffer.count` | Buffering | **BREAKS** | actor `Buffer.Count.State` |
| **Generators** | | | |
| `interval` | Generator | **BREAKS** | `Task.sleep` + actor `Interval.State` |
| `timer` | Generator | **BREAKS** | `Task.sleep` + actor `Timer.State` |
| `repeating` | Generator | **BREAKS** | actor `Repeat.State` |
| `repeating(every:)` | Generator | **BREAKS** | `Task.sleep` + actor `Repeat.Interval.State` |
| `unfold` | Generator | **BREAKS** | `@Sendable` closure + actor `Unfold.State` |
| `generate` | Generator | **BREAKS** | `@Sendable` closure |
| **Bridges** | | | |
| `init(from: Broadcast)` | Bridge | **BREAKS** | `Broadcast` subscription (actor-backed) |
| `init(from: Channel)` | Bridge | **BREAKS** | Channel receiver (actor-backed) |
| `forward(to:)` | Bridge | **BREAKS** | `Task` + channel/broadcast send |

**Result: Every single operator breaks isolation.** There are zero isolation-preserving operators in the current design.

### Isolation Flow Diagram

```
@MainActor func setup() {
    let stream = Async.Stream.interval(.seconds(1))
                      |
                      |  <-- actor Interval.State (own executor)
                      |  <-- Task.sleep (cooperative pool)
                      |  <-- @Sendable _next closure (nonisolated)
                      v
                 .map { process($0) }
                      |
                      |  <-- @Sendable transform closure (nonisolated)
                      |  <-- @Sendable _next closure (nonisolated)
                      |  <-- Box<Iterator> bypasses Sendable checking
                      v
                 .filter { $0.isValid }
                      |
                      |  <-- @Sendable predicate closure (nonisolated)
                      |  <-- @Sendable _next closure (nonisolated)
                      v
                 .debounce(.seconds(1))
                      |
                      |  <-- actor Debounce.State (own executor)
                      |  <-- withTaskGroup (child tasks on cooperative pool)
                      |  <-- Task.sleep (cooperative pool)
                      v
                 .share()
                      |
                      |  <-- Task { for await ... } (cooperative pool)
                      |  <-- Broadcast (actor-backed)
                      |  <-- Subscription iterator (actor-backed)
                      v
                 for await item in stream { ... }
                      |
                      |  Caller is @MainActor, but every _next()
                      |  call enters a nonisolated @Sendable closure.
                      |  The closure may await actor-isolated state,
                      |  causing hops to various executors.
                      |
                      |  Caller's @MainActor isolation is SEVERED
                      |  at the very first .map { } closure.
                      v
}
```

**The pipeline above has at least 7 isolation boundary crossings:**
1. `interval` -> actor `Interval.State` executor
2. `map` -> nonisolated `@Sendable` closure
3. `filter` -> nonisolated `@Sendable` closure
4. `debounce` -> actor `Debounce.State` executor + child task executors
5. `share` -> new `Task` executor + `Broadcast` actor executor
6. Each `_next()` call -> nonisolated via `@Sendable`
7. Return to `for await` -> back to `@MainActor`

### Root Cause Analysis

There are **three layers** of isolation breakage:

#### Layer 1: The Iterator's `@Sendable` closure

```swift
// Async.Stream.Iterator.swift, line 20
let _next: @Sendable () async -> Element?
```

This is the foundational break. Every `_next()` call enters a nonisolated context. Even the simplest `map` cannot preserve isolation because both the transform closure and the `_next` closure are `@Sendable`.

In Swift 6.2's terminology (SE-0461), this would need to be a `nonsending` closure to preserve isolation:
```swift
// Hypothetical isolation-preserving design:
let _next: () async -> Element?  // nonsending — inherits caller isolation
```

But this is incompatible with `Sendable` conformance on `Iterator`, because a nonsending closure cannot be stored in a `Sendable` type (it captures the caller's isolation domain, which is not sendable).

#### Layer 2: Actor-based state management

Almost every stateful operator uses an internal actor:
```swift
// Typical pattern (e.g., Async.Stream.Scan.State)
@usableFromInline
actor State<Result: Sendable> { ... }
```

Actors have their own serial executor. Calling `await state.next()` hops from the caller's executor to the actor's executor. This is a second, independent source of isolation breakage that would exist even if the `@Sendable` closure issue were resolved.

#### Layer 3: Unstructured Tasks and TaskGroups

Operators like `merge`, `combineLatest`, `share`, `replay`, `flatMapLatest`, `withLatestFrom`, and `sample` create unstructured `Task` instances:
```swift
// Async.Stream.Merge.swift, lines 44-56
let task1 = Task {
    for await element in a {
        await state.send(element)
    }
    await state.complete()
}
```

These tasks inherit the caller's actor context but execute as independent tasks on the cooperative thread pool. The temporal operators (`debounce`, `timeout`, `buffer.time`, `buffer.countOrTime`) use `withTaskGroup`, which creates child tasks that also execute on the cooperative pool.

### Feasibility of Nonsending Stream Variant

#### Option A: Dual-mode Stream (Sendable + Nonsending)

The idea: provide both `Async.Stream` (current, Sendable, isolation-breaking) and `Async.Stream.Isolated` (nonsending, isolation-preserving).

**Fundamental problem**: A nonsending stream cannot be `Sendable`. If the stream preserves caller isolation, it is tied to a specific isolation domain and cannot cross task boundaries. This means:

- Cannot store it in `Sendable` structs
- Cannot pass it across actor boundaries
- Cannot use it with `Task { }` or `TaskGroup`
- Multi-stream operators (`merge`, `zip`, `combineLatest`) become impossible because they require consuming multiple streams concurrently

A nonsending stream would be limited to single-consumer, single-task, linear pipelines. However, experiment results (see "Experiment Validation" above) reveal a further constraint: `nonisolated(nonsending)` only works on async function types. This means a nonsending stream variant could only accept **async** closures for transforms and predicates — `stream.map { await transform($0) }` — not the natural sync closures users expect. The sync operators (`map`, `filter`, `compactMap`, `scan`, `reduce`, `distinctUntilChanged`, `transduce`) cannot be made isolation-preserving by any current language mechanism.

The viable operator set shrinks from ~10 to only the async variants of linear operators: `map(async:)`, `filter(async:)`, `compactMap(async:)`, and `flatMap`. This is a much weaker value proposition than originally assessed.

**Viability**: Marginally viable. The useful operator set is limited to async-closure variants of linear operators — a small fraction of the full API surface with significant ergonomic cost.

#### Option B: Replace actors with `Mutex`/`Lock`

If stateful operators used `Mutex<State>` instead of actors, the `await` hop could be eliminated. Combined with nonsending closures, this could preserve isolation for simple stateful operators.

**Problem**: `Mutex` is synchronous. If the upstream `_next()` is `async` (which it must be for an `AsyncSequence`), the mutex must be released before awaiting, creating a window for concurrent access. This would require careful state-machine design per operator.

**Viability**: Possible for purely sequential operators where the lock is held only around state mutation, not across await points. Not viable for operators that race multiple streams or time-based triggers.

#### Option C: `#isolation`-based forwarding

Swift 6.0 introduced `#isolation` for forwarding the caller's isolation context. A hypothetical design:

```swift
public func map<U: Sendable>(
    _ transform: (Element) -> U,  // nonsending
    isolation: isolated (any Actor)? = #isolation
) -> Async.Stream<U>
```

**Problem**: The returned `Async.Stream<U>` stores a `@Sendable` closure. The nonsending transform cannot be captured in a `@Sendable` closure. The isolation parameter helps at the call site but cannot propagate through stored closures.

**Viability**: Not viable without changing the core `Stream`/`Iterator` storage model.

#### Option D: Accept the break, document the contract

The current design accepts that `Async.Stream` is a concurrency primitive that **by definition** crosses isolation boundaries. This is consistent with how `AsyncStream`, `AsyncThrowingStream`, channels, and broadcasts work in the Swift ecosystem.

The contract becomes:
1. All closures passed to stream operators must be `@Sendable`
2. Caller isolation is not preserved through the pipeline
3. If you need caller-isolated execution, use `for await` and perform isolated work in the loop body
4. The pipeline is a data-flow graph, not an isolation-preserving call chain

**Viability**: This is the current reality. It is consistent and honest. The question is whether it is acceptable.

**Strengthened by experiment results**: The `nonsending-blocker-validation` experiments confirm that isolation breakage is deeper than originally understood. It is not merely a consequence of `@Sendable` on `_next` (which could theoretically be changed) — it is also a consequence of the fundamental inability to make sync closures nonsending. Even a hypothetical redesign that solved the `_next` problem would still break isolation for every sync operator closure. This makes Option D the only realistic path: accept that stream pipelines are concurrency boundaries and document the contract explicitly.

#### Assessment

The `@Sendable` iterator design is **fundamentally incompatible** with isolation propagation. This is not a bug — it is a consequence of a deliberate architectural choice: `Async.Stream` is `Sendable`, which means it can be shared across isolation domains, which means its internals cannot assume any particular isolation domain.

Experiment validation reveals a **second, independent root cause**: `nonisolated(nonsending)` only applies to async function types. Sync closures — the natural form for `map`, `filter`, `compactMap`, `scan`, `reduce`, and `distinctUntilChanged` — cannot carry isolation context regardless of how `_next` is declared. This means isolation breakage has two irreducible causes, not one:

1. `@Sendable` on `Iterator._next` (affects all operators)
2. Sync closures cannot be nonsending (affects all sync operator variants, independently of cause 1)

The Pointfree #355 insight applies to **synchronous call chains and simple async sequences**, not to type-erased, multi-consumer stream combinators. The two patterns serve different use cases:

| Property | Isolation-preserving | Async.Stream |
|----------|---------------------|--------------|
| Sendable | No | Yes |
| Multi-consumer | No | Yes |
| Multi-stream operators | Impossible | Full support |
| Temporal operators | Impossible | Full support |
| Deterministic execution | Yes | No |
| Thread hops | Zero | Frequent |
| Closure requirement | nonsending (async only) | `@Sendable` |
| Sync closures | Cannot be nonsending | `@Sendable` |

A **practical middle ground** would be:
1. Keep `Async.Stream` as-is for the full operator set
2. Provide documentation that isolation breaks at the stream boundary
3. For isolation-sensitive code, recommend using stdlib `AsyncSequence` with dedicated types (where the compiler can track isolation through concrete types) rather than type-erased streams
4. Monitor Swift Evolution for potential `nonsending AsyncSequence` proposals that could enable a future isolation-preserving variant — noting that even such proposals would be limited to async closures

## Outcome

**Status**: IN_PROGRESS

**Finding**: Every operator in `Async.Stream` breaks isolation. The root cause is architectural: the `@Sendable () async -> Element?` closure stored in `Iterator` severs the caller's isolation context at every `_next()` call. This is compounded by pervasive actor-based state management and unstructured `Task` creation in multi-stream and temporal operators.

**Count**: 0 of 40+ operators preserve isolation. 100% isolation breakage rate.

**Root causes** (four independent layers, updated per experiment validation):
1. `@Sendable` closure storage in `Iterator._next` — severs caller isolation
2. Sync closures cannot be `nonisolated(nonsending)` — compiler rejects nonsending on non-async function types, making sync operator closures permanently isolation-breaking
3. Internal actors for state management — introduces executor hops
4. Unstructured `Task` creation — introduces concurrent execution contexts

**Recommendation**: A nonsending stream variant is feasible only for async-closure variants of linear, single-consumer operators — a smaller subset than originally assessed. Sync operator closures (the common path) cannot be made isolation-preserving by any current language mechanism. The full operator set (merge, combineLatest, debounce, share, etc.) requires concurrency by definition and cannot preserve isolation. The practical path forward is Option D:
1. Document this as an explicit contract: `Async.Stream` is a concurrency boundary
2. Ensure all user-facing closures remain `@Sendable` (already the case)
3. Track Swift Evolution proposals around `nonsending` async sequences — noting they would only help async closures
4. For isolation-sensitive code, recommend concrete `AsyncSequence` types over type-erased streams

## References

- Pointfree #355: Beyond Basics: Isolation, ~Copyable, ~Escapable (Feb 23, 2026)
- SE-0461: Isolation regions and `nonsending` closures
- `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.swift` — Core stream type
- `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Iterator.swift` — Iterator with `@Sendable` `_next`
- `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/Async.Stream.Iterator.Box.swift` — `@unchecked Sendable` bypass
- `/Users/coen/Developer/swift-primitives/swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Mutable.Unchecked.swift` — Sendable bypass mechanism
- `/Users/coen/Developer/swift-institute/Experiments/nonsending-blocker-validation/` — Empirical validation: nonsending async closures, continuation/cancellation handler isolation
- `/Users/coen/Developer/swift-institute/Experiments/nonsending-blocker-validation-negative/` — Negative validation: compiler rejects nonsending on sync function types
