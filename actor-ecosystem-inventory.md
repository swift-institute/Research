# Actor Ecosystem Inventory

Survey date: 2026-04-13  
Scope: swift-primitives, swift-standards, swift-foundations, swift-law, swift-nl-wetgever, rule-law

---

## 1. Actor Type Declarations

No `distributed actor` declarations found in any repo.

### swift-primitives

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-ordering-primitives/Tests/Ordering Primitives Tests/OrderingTests.swift` | 364 | `actor TestActor` | Local test actor, verifies Comparator is usable across actor boundary |
| `swift-ordering-primitives/Tests/Ordering Primitives Tests/OrderingTests.swift` | 378 | `actor TestActor` | Local test actor, verifies Ordering.Direction mutation is actor-safe |
| `swift-rendering-primitives/Sources/Rendering Async Primitives/Rendering.Async.Sink.Chunked.swift` | 10 | `actor Chunked` | Internal (no access modifier) actor; holds `[UInt8]` buffer + chunk size + `AsyncStream` continuation |
| `swift-rendering-primitives/Sources/Rendering Async Primitives/Rendering.Async.Sink.Buffered.swift` | 32 | `public actor Buffered: Rendering.Async.Sink.Protocol` | Public actor; holds `Async.Channel.Bounded.Sender`, `[UInt8]` buffer, chunk size — the channel-backed buffered sink |
| `swift-comparison-primitives/experiments/Sources/ComparisonExperiments/main.swift` | 308 | `actor TestActor` | Experiment file; tests Comparison.Result mutation across actor |
| `swift-comparison-primitives/Tests/Comparison Primitives Tests/ComparisonTests.swift` | 210 | `actor TestActor` | Test actor; verifies Comparison value round-trips through actor |

### swift-standards

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-postgresql-standard/Tests/Support/ValidateSQL.swift` | 20 | `private actor SharedValidationClient` | Test-support actor; lazily initialises `PostgresClient`, serialises connection setup |

### swift-foundations

**swift-async (production — Async.Stream operators)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-async/Sources/Async Stream/Async.Stream.Buffer.Time.State.swift` | 20 | `actor State` | Time-window buffer state |
| `swift-async/Sources/Async Stream/Async.Stream.Timer.State.swift` | 18 | `actor State` | Timer delay + fired flag |
| `swift-async/Sources/Async Stream/Async.Stream.Map.Flat.Latest.State.swift` | 23 | `actor State<U: Sendable>` | FlatMapLatest: outer box, inner task, transform |
| `swift-async/Sources/Async Stream/Async.Stream.Unfold.State.swift` | 17 | `actor State<S: Sendable>` | Unfold: mutable state + next function |
| `swift-async/Sources/Async Stream/Async.Stream.Buffer.Window.State.swift` | 20 | `actor State` | Window buffer state |
| `swift-async/Sources/Async Stream/Async.Stream.Distinct.State.swift` | 36 | `actor State` | Distinct: previous-element comparison guard |
| `swift-async/Sources/Async Stream/Async.Stream.Replay.Cursor.swift` | 17 | `actor Cursor` | Replay cursor; holds `Replay.State` + optional `Subscription` |
| `swift-async/Sources/Async Stream/Async.Stream.Sample.State.swift` | 18 | `actor State<Trigger: Sendable>` | Sample: latest element + source task + trigger box |
| `swift-async/Sources/Async Stream/Async.Stream.Combine.Latest.State.swift` | 17 | `actor State<A: Sendable, B: Sendable>` | CombineLatest: latest A, latest B, pending queue |
| `swift-async/Sources/Async Stream/Async.Stream.Repeat.Interval.State.swift` | 18 | `actor State` | Repeat-at-interval: value, interval, remaining count |
| `swift-async/Sources/Async Stream/Async.Stream.Prefix.Count.swift` | 18 | `actor Count` | Prefix-by-count state |
| `swift-async/Sources/Async Stream/Async.Stream.Concat.State.swift` | 18 | `actor State` | Concat sequencing state |
| `swift-async/Sources/Async Stream/Async.Stream.Timer.Value.State.swift` | 18 | `actor State` | Timer-value state |
| `swift-async/Sources/Async Stream/Async.Stream.Drop.While.swift` | 18 | `actor While` | DropWhile predicate state |
| `swift-async/Sources/Async Stream/Async.Stream.Replay.State.swift` | 19 | `actor State` | Replay main state (buffer + subscribers) |
| `swift-async/Sources/Async Stream/Async.Stream.Throttle.State.swift` | 20 | `actor State` | Throttle: timing + pending element |
| `swift-async/Sources/Async Stream/Async.Stream.Replay.Subscription.swift` | 17 | `actor Subscription` | Replay per-subscriber subscription |
| `swift-async/Sources/Async Stream/Async.Stream.Map.Flat.State.swift` | 18 | `actor State<U: Sendable>` | FlatMap: outer box + inner tasks |
| `swift-async/Sources/Async Stream/Async.Stream.Drop.Count.swift` | 18 | `actor Count` | DropCount state |
| `swift-async/Sources/Async Stream/Async.Stream.Repeat.State.swift` | 17 | `actor State` | Repeat state |
| `swift-async/Sources/Async Stream/Async.Stream.Prefix.While.swift` | 18 | `actor While` | PrefixWhile predicate state |
| `swift-async/Sources/Async Stream/Async.Stream.Interval.State.swift` | 18 | `actor State` | Interval: fired tracking |
| `swift-async/Sources/Async Stream/Async.Stream.Buffer.Count.State.swift` | 20 | `actor State` | Count-bounded buffer state |
| `swift-async/Sources/Async Stream/Async.Stream.Debounce.State.swift` | 19 | `actor State` | Debounce: pending element + timer |
| `swift-async/Sources/Async Stream/Async.Stream.Merge.State.swift` | 17 | `actor State` | Merge: completion tracking across sources |
| `swift-async/Sources/Async Stream/Async.Stream.Scan.State.swift` | 18 | `actor State<Result: Sendable>` | Scan: accumulated result |
| `swift-async/Sources/Async Stream/Async.Stream.Last.State.swift` | 18 | `actor State` | Last element accumulator |
| `swift-async/Sources/Async Stream/Async.Stream.Latest.From.State.swift` | 18 | `actor State<Other: Sendable>` | LatestFrom: latest other-stream value |
| `swift-async/Sources/Async Stream/Async.Stream.Transducer.State.swift` | 14 | `actor Run: Sendable` | Transducer run state; explicit `Sendable` conformance |
| `swift-async/Sources/Async Stream Core/Async.Stream.State.swift` | 17 | `actor State` | Core stream state (the root) |

**swift-async (tests)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-async/Tests/Async Stream Tests/Async.Stream.Remaining Tests.swift` | 17 | `private actor Counter` | Test counter actor for remaining-element tests |

**swift-io (production)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-io/Sources/IO Events/IO.Event.Runtime.swift` | 34 | `package actor Runtime` | **Core production actor.** Pinned to `IO.Event.Loop` via `unownedExecutor`. Serialises register/deregister/arm/modify. |
| `swift-io/Sources/IO Events/IO.Event.Selector+shared.swift` | 37 | `private actor SharedSelector` | Process-scoped lazy singleton for shared `IO.Event.Selector` |

**swift-tests (production support)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-tests/Sources/Tests Core/Test.Exclusion.Controller.swift` | 15 | `public actor Controller` | Singleton serialises test group exclusion; tracks running groups + continuation waiters |

**swift-html-rendering (tests)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-html-rendering/Tests/HTML Rendering Core Tests/AsyncChannel Tests.swift` | 305 | `actor RenderingState` | Local test actor; tracks producer/consumer state for async channel tests |

**swift-dependencies (tests)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `swift-dependencies/Tests/Dependencies Tests/Edge Cases Tests.swift` | 193 | `actor DependentActor` | Local test actor; verifies dependencies are accessible from actor context |

**Experiments (not production)**

| File | Line | Declaration | Context |
|------|------|-------------|---------|
| `Experiments/noncopyable-actor-driver-ownership/Sources/main.swift` | 33 | `actor Owner` | Owns `~Copyable Resource` via `consuming init` |
| `Experiments/noncopyable-actor-driver-ownership/Sources/main.swift` | 72 | `actor Runtime` | Owns `Driver?` (Optional for `.take()` pattern) |
| `Experiments/noncopyable-actor-driver-ownership/Sources/main.swift` | 111 | `actor PinnedRuntime` | Custom executor pin via `unownedExecutor` override; owns `~Copyable Driver` |
| `Experiments/runtime-noncopyable-shutdown/Sources/main.swift` | 34 | `actor MockRuntime2` | Shutdown variant 2 |
| `Experiments/runtime-noncopyable-shutdown/Sources/main.swift` | 61 | `actor MockRuntime3` | Shutdown variant 3 |
| `swift-io/Experiments/actor-state-inline-fallback-repro/Sources/main.swift` | 128 | `actor Runtime` | Repro for actor-isolated `@_rawLayout` inline storage fallback bug |
| `swift-io/Experiments/actor-state-cross-thread-inline/Sources/main.swift` | 167 | `actor Runtime` | Cross-thread actor + inline storage repro |
| `swift-io/Experiments/tilde-sendable-thread-confined/Sources/main.swift` | 91 | `actor Worker` | ~Sendable thread-confinement experiment |

### swift-law, swift-nl-wetgever, rule-law

No actor declarations found in any of these repos.

---

## 2. SerialExecutor Conformances and `unownedExecutor` Overrides

### Production conformances

| File | Line | Declaration | Notes |
|------|------|-------------|-------|
| `swift-foundations/swift-io/Sources/IO Events/IO.Event.Loop.swift` | 40 | `public final class Loop: SerialExecutor, TaskExecutor, @unchecked Sendable` | The canonical I/O event loop executor. Runs actor jobs and kernel polling in interleaved phases. `runSynchronously` at line 156; `asUnownedSerialExecutor` at line 162. |
| `swift-foundations/swift-executors/Sources/Executors/Kernel.Thread.Executor.swift` | 74 | `public final class Executor: SerialExecutor, TaskExecutor, @unchecked Sendable` | Thread-based executor for actor pinning. `asUnownedSerialExecutor` at line 164; job drain at line 152 and 195. |

### `unownedExecutor` overrides (production actors)

| File | Line | Override |
|------|------|---------|
| `swift-foundations/swift-io/Sources/IO Events/IO.Event.Runtime.swift` | 41 | `nonisolated package var unownedExecutor: UnownedSerialExecutor` — delegates to `executor.asUnownedSerialExecutor()` (pins `Runtime` to `IO.Event.Loop`) |

### Test support

| File | Line | Declaration |
|------|------|-------------|
| `swift-foundations/swift-tests/Sources/Tests Core/SerialExecutor.swift` | 28/43 | `withSerialExecutor` — utility that redirects task enqueues to the main actor for deterministic async tests; uses `@isolated(any)` on the async overload |

### Experiment conformances (not production)

| File | Lines | Class |
|------|-------|-------|
| `swift-foundations/Experiments/noncopyable-actor-driver-ownership/Sources/main.swift` | 100, 106–107, 115–116 | `final class SimpleExecutor: SerialExecutor` + `actor PinnedRuntime` with `unownedExecutor` override |
| `swift-foundations/swift-io/Experiments/actor-state-inline-fallback-repro/Sources/main.swift` | 22, 84–85, 137–138 | `final class Loop: SerialExecutor` + `actor Runtime` with `unownedExecutor` override |
| `swift-foundations/swift-io/Experiments/actor-state-cross-thread-inline/Sources/main.swift` | 88, 149–150, 182–183 | `final class TestLoop: SerialExecutor` + `actor Runtime` with `unownedExecutor` override |

---

## 3. `isolated` Parameter Usage

### `isolated (any Actor)?` — existential isolation parameter (SE-0420)

Used exclusively in `swift-async` to propagate caller isolation into async closures, avoiding spurious `Sendable` constraints on non-Sendable transforms.

| File | Line | Usage |
|------|------|-------|
| `swift-foundations/swift-async/Sources/Async Sequence/Async.Map.swift` | 59 | `isolation actor: isolated (any Actor)? = #isolation` — map transform closure |
| `swift-foundations/swift-async/Sources/Async Sequence/Async.Filter.swift` | 58 | `isolation actor: isolated (any Actor)? = #isolation` — filter predicate closure |
| `swift-foundations/swift-async/Sources/Async Sequence/Async.CompactMap.swift` | 62 | `isolation actor: isolated (any Actor)? = #isolation` — compactMap transform closure |
| `swift-foundations/swift-async/Sources/Async Sequence/Async.FlatMap.swift` | 67 | `isolation actor: isolated (any Actor)? = #isolation` — flatMap transform closure |
| `swift-foundations/swift-async/Tests/Async Sequence Tests/Produce.swift` | 28 | `isolation actor: isolated (any Actor)? = #isolation` — test producer helper |

Pattern rationale (from inline comments): the `isolation actor` parameter allows the closure to capture non-Sendable actor-isolated state. Claiming `Sendable` on these closures would be a type-system lie.

### `@isolated(any)` — closure type attribute

| File | Line | Usage |
|------|------|-------|
| `swift-foundations/swift-tests/Sources/Tests Core/SerialExecutor.swift` | 29 | `operation: @isolated(any) () async throws(E) -> Void` — the `@MainActor withSerialExecutor` overload accepts any-isolated operation |

---

## 4. `nonisolated` Patterns (selected highlights)

The following production patterns are notable:

| File | Line | Pattern |
|------|------|---------|
| `swift-foundations/swift-io/Sources/IO Events/IO.Event.Runtime.swift` | 41 | `nonisolated package var unownedExecutor` — standard actor executor pin |
| `swift-primitives/swift-pool-primitives/Sources/Pool Bounded Primitives/Pool.Bounded.Acquire.swift` | 87–89 | `nonisolated(nonsending)` on `withAcquire` — preserves caller isolation through async boundary |
| `swift-primitives/swift-pool-primitives/Sources/Pool Bounded Primitives/Pool.Bounded.Shutdown.swift` | 176 | `nonisolated(nonsending)` on shutdown — same pattern |
| `swift-primitives/swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Scope.swift` | 143–146 | `nonisolated(nonsending)` on `withScope` — isolation preservation |
| `swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Context.swift` | 135–152 | `nonisolated(nonsending)` on both `run` overloads |
| `swift-primitives/swift-clock-primitives/Sources/Clock Primitives/Clock.Any.swift` | 55 | `nonisolated(nonsending) @Sendable` stored closure — type annotation on function-valued property |
| `swift-primitives/swift-memory-primitives/Sources/Memory Buffer Primitives/Memory.Buffer.swift` | 29, 37 | `nonisolated(unsafe)` on module-level empty-buffer sentinels |

---

## 5. Summary Statistics

| Category | Count |
|----------|-------|
| Actor declarations (production) | 36 |
| Actor declarations (tests only) | 9 |
| Actor declarations (experiments) | 8 |
| Distributed actor declarations | 0 |
| `SerialExecutor` conformances (production) | 2 |
| `SerialExecutor` conformances (experiments) | 3 |
| `unownedExecutor` overrides (production actors) | 1 (`IO.Event.Runtime`) |
| `unownedExecutor` overrides (experiment actors) | 3 |
| `isolated (any Actor)?` parameter sites | 5 |
| `@isolated(any)` closure type sites | 1 |

### Key observations

1. **Dominant pattern — actor as operator state**: The overwhelming majority of actor declarations (≈30 out of 36 production) are anonymous `actor State` / `actor Cursor` types nested inside `swift-async` stream operator implementations. These are small, internal actors serialising mutable state for a single stream operator.

2. **Single pinned production actor**: `IO.Event.Runtime` (line 34, `swift-io/Sources/IO Events/IO.Event.Runtime.swift`) is the only production actor with a custom `unownedExecutor` override, pinning it to `IO.Event.Loop` — the only production `SerialExecutor` implementation outside of `Kernel.Thread.Executor`.

3. **No distributed actors**: Zero `distributed actor` declarations anywhere in the corpus.

4. **`isolated (any Actor)?` confined to swift-async sequences**: The SE-0420 `#isolation` / `isolated (any Actor)?` pattern is used exclusively in `swift-async`'s `AsyncSequence` operator closures (Map, Filter, CompactMap, FlatMap) plus one test helper.

5. **`nonisolated(nonsending)` is the primary isolation-preservation tool at L1**: Used in `swift-pool-primitives`, `swift-effect-primitives`, `swift-dependency-primitives`, and `swift-clock-primitives` to thread caller isolation through async `withX` boundaries.

6. **Legal repos are actor-free**: `swift-law`, `swift-nl-wetgever`, and `rule-law` contain zero actor declarations, consistent with their synchronous encoding model.
