# IO.blocking() Executor Binding: Preference vs Mandatory

<!--
---
version: 4.0.0
last_updated: 2026-04-14
status: RECOMMENDATION
tier: 2
related:
  - swift-io/Research/io-witness-design-literature-study.md
  - swift-io/Research/io-context-actor-analysis.md
  - swift-io/HANDOFF-actor-runner-investigation.md
  - SE-0417 Task Executor Preference
  - SE-0392 Custom Actor Executors
  - SE-0430 `sending` parameter and result values
  - SE-0461 Run nonisolated async functions on caller's actor by default
  - Point-Free #362 "Isolation: Actor Enqueuing"
  - /Users/coen/Developer/pointfreeco/TCA26 (shared-executor pattern, production)
  - /Users/coen/Developer/swift-primitives/swift-standard-library-extensions/Sources/Standard Library Extensions/Actor.swift
changelog:
  - v4.0: Recommendation refined to **Shape B**. v3.0 made `IO` itself an actor
    (Option F / Shape A). That required storing `any SerialExecutor` on the public
    type to accommodate future Events/Completions strategies with different
    executor types, and had awkward interaction with the `@Witness` macro (designed
    for structs, not actors). Shape B: `IO` stays a `@Witness` struct of async
    closures; each strategy's implementation is an internal actor holding its own
    concrete executor type. Consumer API unchanged (`try await io.read(...)`);
    capability theory alignment upgrades from B to A- (value-type capability vs
    ref-type); `@Witness` testing helpers generated publicly at no extra cost.
    Prototype verified in `Experiments/witness-over-actor/`.
  - v3.0: Recommendation refined to Option F (Shape A). v2.0's Option B (Actor.run
    with `@Sendable` body) is viable but imposes Sendable capture restrictions
    consumers experience as viral. Option F made `IO` itself the actor — no body
    closure, no `@Sendable`. A second factory overload `IO.blocking(on:)` enabled
    the shared-executor pattern (TCA26 precedent) for zero-hop co-location. v2.0's
    code sample had a latent bug (`Sharded` used as `SerialExecutor`); v3.0 pinned
    one shard per `IO` at factory time. Full analysis in HANDOFF-actor-runner-investigation.md.
  - v2.0: Reversed recommendation from v1.0. Dismissed Option B on `@Sendable`
    grounds which was incorrect in isolation — `@Sendable` on the body is a
    single-point requirement, not viral propagation. Typical I/O values
    (Kernel.Descriptor, Memory.Buffer) are already Sendable.
---
-->

## Context

`IO.blocking()` currently dispatches the user's body to a dedicated OS thread via
`Task(executorPreference: kernelThreadExecutor)`. External review flagged this as
a "time bomb" under load — if the preference isn't honored, the sync blocking I/O
syscalls in the body would run on the cooperative pool and could deadlock it.

SE-0417 confirms: the preference is advisory. Documented override cases include
`Task.sleep`/`Task.yield` (swift#74395, OPEN), `@MainActor` calls, custom-executor
actors, and unstructured `Task { }`.

## Question

How should `IO.blocking()` ensure the user's async body executes on a dedicated
OS thread (not the cooperative pool), such that sync I/O syscalls in the body
never block cooperative threads — under all load conditions?

## Prior Art

### SE-0417 Task Executor Preference (Accepted)

Execution priority:
```
Isolation requirements > Actor's custom SerialExecutor > Task's preferred TaskExecutor > Global concurrent pool
```

"Preference" is load-bearing terminology. Cases where preference is NOT honored:

| Scenario | Behavior |
|----------|----------|
| Body awaits `Task.sleep(...)` | Resumes on global pool (bug swift#74395, OPEN) |
| Body awaits `Task.yield()` | Resumes on global pool (bug swift#74395, OPEN) |
| Body calls `@MainActor` member | Hops to main thread |
| Body calls actor with custom `unownedExecutor` | Hops to that actor's executor |
| Body spawns `Task { }` without re-passing preference | Child runs on global pool |

### SE-0392 Custom Actor Executors (Accepted)

Actors with custom `unownedExecutor` have **mandatory** binding via isolation.
The language enforces it, not a runtime heuristic.

### Point-Free #362 "Isolation: Actor Enqueuing" (2026-04-13)

Establishes the `Actor.run` pattern: `try await actor.run { isolated actor in ... }`.

- **Single suspension** to enter the actor's isolation domain.
- **Sync synchronous access** inside the body (the `isolated` parameter proves
  isolation to Swift, enabling sync method calls).
- **Auto re-hop** after any `await` inside — re-entering the actor forces back
  onto its executor.

The `@Sendable` requirement on the body captures VALUES crossing the isolation
boundary (into the actor). Once inside, access to actor state is unrestricted.

### Ecosystem: stdlib extensions `Actor.run`

```swift
extension Actor {
    public func run<R, Failure: Error>(
        _ body: @Sendable (isolated Self) async throws(Failure) -> sending R
    ) async throws(Failure) -> sending R {
        try await body(self)
    }
}
```

Four overloads exist (sync/async × Copyable/~Copyable return). Directly applicable
to IO if the runner is an actor.

## Analysis

### Option A: `Task(executorPreference:)` (current)

See prior art — advisory. Breaks under documented conditions.

**Pros**: Zero complexity, @Witness Context API preserved unchanged, no Sendable
requirements.

**Cons**: Silent failure modes. `Task.sleep`, `Task.yield`, `@MainActor` calls,
stray unstructured tasks all dispatch to cooperative pool → may block it.

### Option B: Actor Runner with Custom Executor + `Actor.run` body (v2.0 proposal)

Runner is an actor whose `unownedExecutor` is the blocking thread executor.
Operations are isolated methods. Context remains `@Witness` internally. A
`run(_:)` method takes a `@Sendable (isolated Runner) async -> R` body per
Point-Free's pattern.

```swift
public actor Runner {
    let executor: Kernel.Thread.Executor   // NOT Sharded — see v3.0 below
    let context: Context

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    public func read(from descriptor: borrowing Kernel.Descriptor,
                     into buffer: Memory.Buffer.Mutable)
        throws(IO.Error) -> Int { try context._read(descriptor, buffer) }

    public func run<R, E: Error>(
        _ body: @Sendable (isolated Runner) async throws(E) -> sending R
    ) async throws(E) -> sending R { try await body(self) }
}
```

Consumer:
```swift
try await IO.run(.blocking()) { runner in
    let n = try runner.read(from: fd, into: buf)    // sync, on blocking thread
    await someOtherWork()                             // may hop
    let m = try runner.write(to: fd, from: buf)      // re-enters actor
}
```

**Pros**:
- **Mandatory** binding — Swift enforces isolation, not runtime heuristic
- **Auto re-hop** after any suspension inside body
- **`@Witness` Context preserved** — actor uses Context internally
- **Sync fast-path inside body** — isolated method calls elide hop

**Cons**:
- Body MUST be `@Sendable`. Captures must be Sendable. This is **confirmed** by
  experiment (HANDOFF Q2): `sending` cannot replace `@Sendable` on bodies with
  `isolated Self` due to Swift 6.3 region-checker limitations. Consumer code that
  mixes I/O with non-Sendable framework state (loggers, custom client classes,
  non-`@Sendable` closures) cannot use the body-closure form without refactoring
  those captures — which is a viral cost, contrary to v2.0's framing.
- `~Copyable` descriptors held by the caller must be **consumed** into the body
  (`[consumed = consume fd]`) — the descriptor is gone from the caller after
  the run. Breaking change from Option A's borrow-across-scope ergonomic.
- v2.0's code sample stores `Kernel.Thread.Executor.Sharded` on the actor and
  calls `executor.asUnownedSerialExecutor()`. `Sharded` does NOT conform to
  `SerialExecutor` — that method doesn't exist on it. The snippet does not
  compile. Fix: bind one `Kernel.Thread.Executor` (one shard) per actor at
  factory time.
- Actor reentrancy across `await` inside body breaks the "atomic multi-call"
  pitch (v2.0 overstates this; io-context-actor-analysis.md:59 says "Multiple
  I/O calls within `run` are atomic" which is only true when no `await`
  intervenes).

### Option C: Dual Conformance (SerialExecutor + TaskExecutor)

From SE-0417, one type can conform to both. Mandatory path via actor, ergonomic
path via `withTaskExecutorPreference`.

**Cons**: Complex dual-protocol implementation. No structural advantage over B
alone if actor is the mandatory path.

### Option D: Direct `Kernel.Thread.spawn`

Body is async but runs on a dedicated OS thread. Requires an event loop on that
thread to drive async work.

**Cons**: Reinvents TaskExecutor. Can't use structured concurrency inside body.
Architecturally regressive.

### Option E: Sync-body only

Consumer can't await other async work inside. Too limiting.

### Option F / Shape A: `IO` is an actor (v3.0 intermediate proposal)

The first refinement made `IO` itself a public actor. Full analysis preserved
in the v3.0 edit of this file; superseded by Shape B because of two issues:
(1) requires `any SerialExecutor` storage on the public type to accommodate
Events/Completions strategies with different executor types;
(2) awkward interaction with the `@Witness` macro (designed for structs).

### Shape B (chosen): `@Witness struct IO` over internal actor implementations

`IO` stays a `@Witness` struct of async throwing closures — value-type
capability in the Brachthaeuser sense, and a natural `@Witness` target.
Each strategy's implementation is an **internal actor** holding its own
concrete executor type. The witness closures forward to isolated methods on
the impl actor, which runs on that actor's executor.

Consumer API unchanged from Shape A: `try await io.read(...)`. The distinction
between the two shapes is internal, but the architectural layering is cleaner
under Shape B: the witness IS the capability (Brachthaeuser); the impl actor
IS the runner (Ahman & Bauer). Two distinct theoretical roles, two distinct
types.

```swift
// Public witness — struct of async throwing closures.
@Witness
public struct IO: Sendable {
    let _read:  @Sendable (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    let _write: @Sendable (_ to:   borrowing Kernel.Descriptor, _ from: Memory.Buffer)         async throws(IO.Error) -> Int
    let _accept:@Sendable (_ on:   borrowing Kernel.Descriptor)                                 async throws(IO.Error) -> Kernel.Descriptor
    let _close: @Sendable (_ descriptor: consuming Kernel.Descriptor) async -> Void
    let _unownedExecutor: @Sendable () -> UnownedSerialExecutor
}

// Public forwarding methods — what consumers call.
extension IO {
    @inlinable public func read(from fd: borrowing Kernel.Descriptor,
                                into buf: Memory.Buffer.Mutable)
        async throws(IO.Error) -> Int { try await _read(fd, buf) }

    @inlinable public func write(to fd: borrowing Kernel.Descriptor,
                                 from buf: Memory.Buffer)
        async throws(IO.Error) -> Int { try await _write(fd, buf) }

    @inlinable public func accept(on fd: borrowing Kernel.Descriptor)
        async throws(IO.Error) -> Kernel.Descriptor { try await _accept(fd) }

    @inlinable public func close(_ fd: consuming Kernel.Descriptor) async {
        await _close(consume fd)
    }

    @inlinable public var unownedExecutor: UnownedSerialExecutor {
        _unownedExecutor()
    }
}

// Internal actor impl — concrete executor type, not any SerialExecutor.
internal actor Actor {
    let executor: Kernel.Thread.Executor

    init(executor: Kernel.Thread.Executor) { self.executor = executor }

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    func read(from fd: borrowing Kernel.Descriptor,
              into buf: Memory.Buffer.Mutable)
        throws(IO.Error) -> Int { /* direct POSIX syscall on executor thread */ }

    func write(to fd: borrowing Kernel.Descriptor,
               from buf: Memory.Buffer)
        throws(IO.Error) -> Int { /* ... */ }

    func accept(on fd: borrowing Kernel.Descriptor)
        throws(IO.Error) -> Kernel.Descriptor { /* ... */ }

    func close(_ fd: consuming Kernel.Descriptor) { /* ... */ }
}

// Factories — wire up impl and return the witness.
extension IO {
    public static func blocking(_ pool: Blocking = .shared) -> IO {
        blocking(on: pool._executors.next())
    }

    public static func blocking(on executor: Kernel.Thread.Executor) -> IO {
        let impl = Actor(executor: executor)
        return IO(
            read:  { (fd, buf) async throws(IO.Error) in try await impl.read(from: fd, into: buf) },
            write: { (fd, buf) async throws(IO.Error) in try await impl.write(to: fd, from: buf) },
            accept:{ (fd)      async throws(IO.Error) in try await impl.accept(on: fd) },
            close: { fd in await impl.close(consume fd) },
            unownedExecutor: { impl.unownedExecutor }
        )
    }
}
```

Phase 2 extends the pattern:

```swift
internal actor EventsImpl {
    let loop: Kernel.Event.Loop   // different concrete type — no existential!
    // ... isolated methods ...
}

internal actor CompletionsImpl {
    let ring: Kernel.Completion.Ring   // yet another concrete type
    // ... isolated methods ...
}

extension IO {
    public static func events(_ loop: Events = .shared) -> IO { /* ... */ }
    public static func events(on loop: Kernel.Event.Loop) -> IO { /* ... */ }
    public static func completions(_ ring: Completions = .shared) -> IO { /* ... */ }
    public static func completions(on ring: Kernel.Completion.Ring) -> IO { /* ... */ }
    public static func platformBest(_ options: IO.Options = .init()) -> IO { /* ... */ }
}
```

Consumer API — identical across strategies:

```swift
let io = IO.blocking()   // or .events() / .completions() / .platformBest()
let n = try await io.read(from: fd, into: buf)
try await io.write(to: fd, from: buf)
```

Shared-executor pattern (TCA26 precedent):

```swift
actor MyServer {
    let executor: Kernel.Thread.Executor = .init()
    let io: IO
    init() { self.io = IO.blocking(on: executor) }
    nonisolated var unownedExecutor: UnownedSerialExecutor { io.unownedExecutor }
    func handle() async throws(IO.Error) -> Int {
        try await io.read(...)   // runtime elides hop — shared executor
    }
}
```

Testing — `@Witness` generates public helpers at no extra cost:

```swift
let io = IO.observe { recorder in /* records every op */ }
try await io.read(from: fd, into: buf)
#expect(recorder.calls.contains(.read(...)))
```

**Pros (Shape B over Shape A)**:
- **No existential** on the public type. Each impl has a concrete executor type.
- **`@Witness` works out of the box** — public `IO.unimplemented()`,
  `IO.fake(...)`, `IO.observe(...)` generated automatically. No wrapper factories.
- **Value-type capability**. Struct of closures, not ref-type actor.
  Brachthaeuser grade upgrades from B (ref-type weakening) to A-.
- **Cleaner theoretical layering**. Witness = capability; impl actor = runner.
  Two distinct Ahman & Bauer roles, two distinct types.
- **Strategy impls fully encapsulated**. Events can use a hybrid event-loop
  executor; Completions can use a ring-backed executor; Blocking uses a thread
  executor. None of this leaks into the public `IO` type.

**Costs**:
- One closure indirection per op (witness closure → actor method). The closure
  call itself is a few ns; dominated by the ~3.9 µs actor hop. Negligible.
- Factory sites need explicit typed-throws annotations on the wrapping closures
  (`{ (fd, buf) async throws(IO.Error) in ... }`) — the compiler widens
  typed throws through actor isolation otherwise. Small ceremony at factory
  implementation time, invisible to consumers.

**Pros (Shape B over v2.0 Option B / Actor.run)**:
All of Option B's problems (viral `@Sendable`, consume-into-body,
latent `Sharded` bug) remain avoided, same as they were in Shape A.
Shape B additionally doesn't conflate capability and runner concepts.

**Cons (Shape B vs Option A / current)**:
- **One `await` per I/O operation, always.** No sync closure pattern at the
  consumer level.
- **Per-op hop cost** when the caller does NOT share the executor — measured
  at ~3.9 µs on Apple M-series. Small vs. a 10–100 µs blocking syscall;
  proportionally larger for event-driven / completion-driven strategies where
  the operation itself is faster. Consumers opt into the shared-executor
  pattern for hot paths (~11 ns/op once shared).
- **Atomicity across calls is not provided.** Consumers who need atomic
  multi-op sequences build them at a higher level (e.g. a per-connection
  actor that holds an `IO`). Matches Option A which also has no atomicity
  guarantee.

## Comparison

| Criterion | A (current) | B (Actor.run) | Shape A (actor IO) | **Shape B (chosen)** |
|-----------|-------------|---------------|-------------------|-------------------|
| Mandatory binding | **No** | **Yes** | Yes | **Yes** |
| `@Sendable` body required | No | **Yes** | No | **No** |
| Borrow-across-scope for fd | Yes | No (consume only) | Yes | **Yes** |
| Public API surface | `IO.run` + `Context` | `IO.run` + `Runner` | `IO` actor | **`IO` @Witness struct** |
| Sync vs async per op | Sync closure | Sync inside body | Async (hop) | Async (hop) |
| Zero-hop fast path | N/A | Inside body | Shared executor | **Shared executor** |
| Survives `Task.sleep`/`@MainActor` | **No** | Yes | Yes | **Yes** |
| Atomicity across `await` | No | Only until next `await` | No | No |
| Executor type on public IO | N/A | `Runner.executor` | `any SerialExecutor` | **None (hidden in impl)** |
| `@Witness` fit | N/A | Poor | Awkward | **Natural** |
| Capability theory grade | N/A | N/A | B (ref-type) | **A- (value-type)** |
| Consumer modes | 1 | 1 | 1 | **1** |

## Constraints

1. **Single public API** — no multiple modes for the consumer. One way to do
   I/O per strategy.
2. **Public IO witness implementations from each of Blocking/Events/Completions** —
   `IO` is the public `@Witness` struct; strategy-specific impl actors are internal.
3. **Shared executors across actors supported** — the design must enable the
   TCA26 co-location pattern without a separate API mode.
4. **`@Witness` testing helpers PUBLIC on `IO`** — consumers use
   `IO.unimplemented()`, `IO.fake(...)`, `IO.observe(...)` generated by the macro
   directly; no wrapper factories.
5. **No platform imports** — stay within Kernel abstractions.

## Outcome

**Status: RECOMMENDATION — Shape B (`@Witness struct IO` + per-strategy internal actor impls)**

### Rationale

1. **Mandatory binding is the correct default** for blocking I/O. Advisory
   binding (Option A) has silent failure modes under `Task.sleep`/`@MainActor`
   that are hard to diagnose. The whole point of this investigation is to move
   away from that. Shape B's impl actors guarantee executor affinity via
   `unownedExecutor`.

2. **No `@Sendable` on the consumer API.** v2.0's body-closure form imposes
   Sendable capture restrictions that are viral in practice (any framework
   object captured — logger, parser, metrics collector — needs to be refactored
   to Sendable). Shape B has no body closure, so there are no captures to
   restrict. Consumer code that today looks like
   `try await IO.run(.blocking()) { ctx in try ctx.read(...) }` becomes
   `let io = IO.blocking(); try await io.read(...)`.

3. **Borrow ergonomic preserved.** `Kernel.Descriptor` stays with the caller
   across every I/O call. The witness closures pass `borrowing Kernel.Descriptor`
   through to the impl actor's isolated methods (compile-verified in
   `Experiments/witness-over-actor/`). v2.0 Option B required consuming
   descriptors into the body — a breaking change Shape B avoids.

4. **Zero-hop path via shared executor** — production precedent in TCA26
   (`/Users/coen/Developer/pointfreeco/TCA26/Sources/ComposableArchitecture2/StoreActor.swift:198`).
   Consumers opt in explicitly by constructing their own
   `Kernel.Thread.Executor` and passing it to both their actor and
   `IO.blocking(on:)`. The witness forwards `unownedExecutor` from the impl.

5. **Single API across strategies.** `IO.blocking(_:)` / `IO.blocking(on:)` is
   the same shape as `IO.events(_:)` / `IO.events(on:)` and
   `IO.completions(_:)` / `IO.completions(on:)` in Phase 2. Each strategy's impl
   holds its own concrete executor type (`Kernel.Thread.Executor`,
   `Kernel.Event.Loop`, `Kernel.Completion.Ring`) — NO existential on the
   public `IO` type. Consumer writes identical call sites regardless of strategy.

6. **`@Witness` applied directly to public IO**. Testing helpers
   (`IO.unimplemented()`, `IO.fake(...)`, `IO.observe(...)`, `IO.Calls` enum,
   prisms) generated by the macro as public API at no extra cost. No wrapper
   factory ceremony needed.

7. **Cleaner theoretical layering**. Witness = capability (Brachthaeuser,
   value-type); impl actor = runner (Ahman & Bauer). Two distinct theoretical
   roles, two distinct types. Shape A (actor IO) conflated them. Shape B
   upgrades Effects-as-Capabilities alignment from B (ref-type weakening) to A-.

### Implementation Path

1. Replace current `public struct IO` (sync-closure Context + Runner pairing)
   with `@Witness public struct IO` holding async throwing closures. Delete
   `IO.Context`, `IO.Runner`, and `IO.Runner._Box`.
2. For Blocking: create `internal actor Actor` in `IO Blocking/`,
   storing `executor: Kernel.Thread.Executor`. Isolated methods perform the
   POSIX syscalls directly.
3. Two factory overloads per strategy: `blocking(_ pool: Blocking = .shared)`
   for round-robin and `blocking(on: Kernel.Thread.Executor)` for explicit
   sharing. Same pattern for Events and Completions in Phase 2. Add
   `IO.platformBest(_:)` meta-factory.
4. Rewrite `Tests/IO Blocking Tests/IO.Blocking.Run.Tests.swift`: each
   `try await IO.run(.blocking()) { ctx in ... }` becomes
   `let io = IO.blocking(); ...` with `await` on each `io.read` / `io.write`.
5. Add regression tests:
   - Mandatory binding: `Task.sleep(for: .milliseconds(10))` between two
     `await io.read(...)` calls — assert both reads execute on the same
     blocking thread. Today's Option A can fail this due to swift#74395.
   - Shared-executor elision: two `IO` witnesses sharing one
     `Kernel.Thread.Executor` — assert both ops land on the same OS thread.
   - Zero-hop from app actor: an actor whose `unownedExecutor == io.unownedExecutor`
     — benchmark cross-hop (~11 ns shared vs ~3.9 µs unshared).
6. Verify `@Witness` macro generates working test helpers for async+throwing
   closures. Add tests using `IO.unimplemented()` and `IO.observe(...)`.
   `@Witness(.mock)` is intentionally NOT enabled — the macro's mock-closure
   generator at `swift-witnesses/Sources/Witnesses Macros Implementation/
   WitnessMacro.swift:493` (`closureParameterList(named: false)`) drops the
   `borrowing`/`consuming` ownership annotations, so `mock(accept: ...)`
   cannot synthesize a `borrowing Kernel.Descriptor` parameter and fails
   to compile with "parameter of noncopyable type 'Kernel.Descriptor' must
   specify ownership". Construct test doubles via the public `IO(read:
   write: accept: close: unownedExecutor:)` init when needed. Note also
   that `IO.unimplemented()` traps on call (uses `fatalError`) rather than
   throwing, because `IO.Error` has no "unimplemented" variant —
   constructed `IO.Error` would require choosing a domain case, defeating
   the macro's "you forgot to override this" semantics.
7. Lifecycle docs: the shared pool has process lifetime; explicit executors
   passed to `(on:)` factories are owned by the caller. Impl actor does not
   shut down the executor.

### Revisit When

- Swift fixes the `sending` + `isolated Self` region-checker limitation
  (HANDOFF Q2). At that point an Actor.run-style fast-path could be added
  additively without `@Sendable` — but the shared-executor pattern likely
  makes it redundant.
- Benchmarks show per-op hop cost dominating for a target workload. First
  measure, then consider whether the remedy is API (batched ops like
  `io.drain(from:into:)`) or convention (push consumers toward shared-executor
  co-location).

## References

### Swift Evolution
- [SE-0417: Task Executor Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor-preference.md)
- [SE-0392: Custom Actor Executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md)
- [SE-0430: `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [SE-0461: Run nonisolated async functions on caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0338: Clarify Execution of Non-Actor-Isolated Async Functions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md)

### Bug Tracking
- [swiftlang/swift#74395 — Task.yield/sleep don't respect task executor preference](https://github.com/swiftlang/swift/issues/74395) (OPEN)

### Ecosystem
- `/Users/coen/Developer/swift-primitives/swift-standard-library-extensions/Sources/Standard Library Extensions/Actor.swift` — `Actor.run` pattern (4 overloads)
- `/Users/coen/Developer/pointfreeco/TCA26/Sources/ComposableArchitecture2/StoreActor.swift:198` — `unownedExecutor` forwarded to a shared isolation actor (production precedent)
- `/Users/coen/Developer/swift-foundations/swift-io/HANDOFF-actor-runner-investigation.md` — full experimental evidence and Q&A for Option F
- `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking/IO.Blocking.Run.swift` — existing `Task(executorPreference:)` pattern

### Video
- Point-Free #362, "Isolation: Actor Enqueuing" (2026-04-13)
