# Completion Executor Composition

<!--
---
version: 1.1.0
last_updated: 2026-04-16
status: DECISION
tier: 2
changelog:
  - 1.1.0 (2026-04-16): name locked as `Kernel.Thread.Executor.Completion`
    (was `Kernel.Thread.Executor.Proactor` — rejected as a pattern name,
    not a mechanism name, asymmetric with `Polling`). Three open
    questions resolved: one bundled commit; coroutine `_read`/`_modify`
    `kernel` accessor; `maxCompletionsPerPoll` default 256. Status:
    DECISION.
  - 1.0.0 (2026-04-16): initial RECOMMENDATION with
    `Kernel.Thread.Executor.Proactor` name.
---
-->

## Context

Phase 1 of the IO Completions delegation refactor landed (commit `7b7fca41` in
swift-io): `IO.Completion` became a typealias of `Kernel.Completion`, the L3
witness cascade was deleted, and `IO.Completion.Loop` internally uses L1
executor primitives (`Executor.Job.Queue`, `Executor.Shutdown.Flag`) from
`swift-executor-primitives`. `IO.Completion.Loop` is still itself the
`SerialExecutor + TaskExecutor` — the domain-specific run loop, the kernel
completion resource, and the executor machinery all live together on the Loop
class.

For `IO.Event.Loop`, the equivalent work went one layer further: the Loop
holds a `Kernel.Thread.Executor.Polling` (L3 composition in swift-executors)
and forwards `unownedExecutor` to it. The Loop is no longer an executor. See
[executor-package-design.md](./executor-package-design.md) V1 and the
`2026-04-15-polling-tick-isolation-checkisolated-landing.md` reflection.

The user's request is the symmetric step for `IO.Completion.Loop`: "For IO
Events we did two things. we deferred to Kernel Event for witness, and defer
to swift-executors for the executor. I want to do the same for IO Completion
re the executor." The witness delegation is done (Phase 1). This research
addresses the executor delegation.

### Layering contract (load-bearing)

Per the IO Events README §10 ("What this target does NOT own") and IO
Completions README §2 ("Vertical stack"), the ecosystem treats platform
unification as a **Kernel-layer** responsibility, not an executor-layer
responsibility:

- **Kernel.Event** (L1) — unified reactor vocabulary across kqueue, epoll, and
  any future readiness backend. `Kernel.Event.Source.platform()` at L3
  swift-kernel is the ONE place `#if os(...)` appears.
- **Kernel.Completion** (L1) — unified proactor vocabulary across io_uring,
  any future IOCP fit, and any other submit-then-await-completion backend.
  `Kernel.Completion.platform()` at L3 swift-kernel is similarly the ONE
  place platform conditionals live.
- **swift-executors** (L3) — takes the unified Kernel primitive as input.
  `Kernel.Thread.Executor.Polling` accepts `Kernel.Event.Source`; it has no
  `#if os(...)`, no knowledge of kqueue vs epoll, no mention of any platform
  backend.

The symmetric rule MUST apply to any proactor executor composition:
**`swift-executors` executors MUST NOT have ANY knowledge of specific
proactor backends (IOCP, io_uring, or any other).** They accept
`Kernel.Completion` — the unified proactor primitive — and operate on it
generically. If a backend does not fit `Kernel.Completion`'s contract, that
is a question for the Kernel Completion layer (swift-kernel-primitives +
swift-kernel), not for this executor.

This principle reshapes the question: "does Completion exist?" is now
"does the unified `Kernel.Completion` primitive warrant its own executor
composition, symmetric to how `Kernel.Event.Source` warrants
`Kernel.Thread.Executor.Polling`?"

### What does not apply

The prior session at
[2026-04-15-completion-loop-proactor-reactor-boundary.md](../../swift-io/Research/Reflections/2026-04-15-completion-loop-proactor-reactor-boundary.md)
rejected adapting `Kernel.Completion` through `Kernel.Thread.Executor.Polling`
on two grounds: (1) a flush-before-wait deadlock because Polling's run loop
is `drain → wait → tick` and the proactor requires flush BEFORE the blocking
wait; (2) [IMPL-090]: the reactor shell's tick emits `Kernel.Event` buffers a
proactor consumer would ignore. That rejection was about **reusing Polling's
shell for Kernel.Completion consumers** — not about proactor executors in
general. This research takes it as given and builds atop it.

The Tier-3 research
[proactor-generalization-iocp-windows.md](../../Research/proactor-generalization-iocp-windows.md)
tracks whether the proactor *pattern* generalizes to Windows IOCP — and
specifically whether IOCP fits the `Kernel.Completion` contract or needs a
distinct Kernel-layer primitive. **That question is Kernel.Completion's, not
this research's.** If IOCP does fit `Kernel.Completion`, the Completion
executor proposed here works for IOCP unchanged (same as Polling works for
any future readiness backend). If IOCP does NOT fit `Kernel.Completion`, the
answer is a Kernel-layer addition (e.g., a distinct `Kernel.IOCP` unifying
primitive), which would then get its own executor composition. This research
scopes strictly to the executor that consumes `Kernel.Completion`.

## Question

Should `swift-executors` add a `Kernel.Thread.Executor.Completion` composition
— a sibling to `Kernel.Thread.Executor.Polling` — that accepts a
`Kernel.Completion` resource (the unified proactor primitive) and absorbs
the executor-generic machinery currently in `IO.Completion.Loop` (OS thread,
job queue, wakeup, shutdown, kernel-completion ownership)?

If yes: **`IO.Completion.Loop` is deleted entirely**, along with the
`IO.Completions` struct wrapper and the internal `IO.Completions.Actor`.
The target's public entry point collapses to a single public
`IO.Completion.Actor` that holds the Completion executor directly — structurally
identical to how `IO.Event.Actor` holds `Kernel.Thread.Executor.Polling`
today, and parallel to `IO.Blocking`'s single-layer public shape. This is
the full equivalent of what Events did in its executor delegation; nothing
less.

Sub-questions:

1. Does the proactor's flush-before-wait constraint embed cleanly into an
   executor shell without leaking backend knowledge?
2. What should the tick closure's shape be so that the executor hides the
   ordering — mirroring Polling's single-thunk shape to the extent possible?
3. Is the consumer story (one consumer today via `Kernel.Completion.platform()`
   on Linux; any future `Kernel.Completion` backend automatically covered)
   sufficient to justify the named composition?

## Prior Art

**Per [RES-021]**: survey of how adjacent ecosystems factor a proactor's
thread/queue/shutdown machinery from its I/O submission+completion logic.

### Swift NIO — no proactor layer today

NIO's `EventLoop`/`Selector` abstraction covers readiness-based I/O only.
Recent versions added io_uring support via a new `Selector` variant, but NIO
consumes io_uring through the readiness-style CQE-drain-on-fd-ready pattern
— not as a native proactor. The `Selector` still produces a buffer of events
per cycle; NIO's event loop body is unchanged. Reading: NIO treats io_uring
as a readiness backend, folding completion semantics into the reactor shell
at the cost of per-CQE indirection. **Lesson**: NIO's choice is viable, but
it's the Option A that was already rejected in the boundary reflection —
data-contract mismatch paid for at runtime.

### Tokio (Rust) — io-driver pattern

Tokio's `tokio::runtime::Builder` composes an io-driver, a time-driver, and a
scheduler. The io-driver (`tokio::net`, `tokio::fs` on Linux via `io_uring`
when `tokio-uring` is enabled) owns a kernel-completion resource. The
scheduler is either `current_thread` (single-thread) or `multi_thread`
(work-stealing). The io-driver's `park`/`unpark` pair integrates with the
scheduler: `park(duration)` blocks on the kernel (io_uring_enter with a
timeout) OR on a condvar when there's no I/O work; `unpark` either submits a
`IORING_OP_NOP` SQE (to wake an io_uring_enter-blocked thread) or signals
the condvar.

Tokio's factoring is **thread-on-scheduler, resource-on-driver**. The
proactor machinery (flush+wait+drain) lives entirely on the io-driver; the
scheduler doesn't know whether it's driving a reactor, a proactor, or
neither. The price is a park/unpark boundary between scheduler and driver —
an extra closure invocation per wake. Tokio accepts it.

**Lesson**: the scheduler and the kernel-completion resource can be
independent primitives, integrated by a park/unpark contract. Apply the
idea here: `Kernel.Thread.Executor.Completion` is the scheduler (owns thread +
queue + shutdown); the `Kernel.Completion` resource is separate; integration
is a tick closure that knows how to flush/drain/wait against the resource.

### OCaml Eio — monolithic per-backend

`eio_linux` (the io_uring backend) is a monolithic runtime. The backend
implementation is ~3000 lines; there is no "executor" that composes with a
separate "I/O driver." When io_uring is the backend, the whole runtime is
io_uring. When epoll is the backend (`eio_posix`), the whole runtime is
epoll. Backend selection is a compile-time choice via `eio_main.run`.

**Lesson**: monolithic-per-backend is a legitimate design when (a) consumers
never mix backends at runtime, (b) the runtime is application-facing (not a
reusable primitive). Our mission is opposite (reusable primitive composable
across packages), so this is the alternative we are NOT taking. It informs
the "no" side of "is the abstraction worth the cost" — if the consumer count
stays at one, monolithic-per-backend is defensible.

### libuv — unified event loop across backends

libuv exposes one `uv_loop_t` type. On Linux + kernel 5.1+ it uses io_uring
internally (as of libuv 1.45); on older Linux, epoll; on Darwin, kqueue; on
Windows, IOCP. The public API is the same across all four. Internally, the
loop dispatches to per-backend callbacks during its run cycle. libuv does NOT
expose a proactor abstraction to consumers — the io_uring internals are
hidden behind the uv_loop API.

**Lesson**: hiding the proactor/reactor distinction inside the loop
implementation is a valid strategy IF the loop owns all I/O primitives (file
I/O, network I/O, timers, signals). Our mission is narrower — swift-io only
provides the proactor side — so libuv's shape doesn't map. But it confirms
that "the proactor is the loop" is a coherent design when the abstraction
layer is application-facing rather than primitive.

### Java NIO.2 + AsynchronousChannelGroup

Java's asynchronous I/O (`java.nio.channels.AsynchronousChannel`) dispatches
completion callbacks via a `CompletionHandler` interface, backed by an
`AsynchronousChannelGroup`. The group owns a thread pool; each thread in the
pool runs a loop that blocks on the platform's completion mechanism (IOCP
on Windows, epoll on Linux, kqueue on Darwin) and dispatches completions to
handlers.

The `AsynchronousChannelGroup` IS the proactor executor. It is a first-class
public type; users can construct one with a custom thread pool or use a
shared default. The API is thread-pool-shaped (N threads, round-robin or
stealing) — which is fundamentally different from Swift's single-thread
serial-executor model for actor pinning.

**Lesson**: Java pays an API cost (explicit `CompletionHandler` callbacks,
explicit group construction) for the flexibility of N-thread proactor
dispatch. Swift's actor-pinned model argues for single-thread proactor
(matching how `Kernel.Thread.Executor.Polling` is single-thread). A
hypothetical `Kernel.Thread.Executor.Completion.Pool` (N-thread variant) is a
future sibling — not a v1 concern for one single-thread consumer.

### Contextualization per [RES-021]

Prior art confirms the pattern: **all proactor-supporting systems factor the
thread/queue/shutdown machinery separately from the kernel-completion
resource, and integrate them via a tick/callback contract.** The exception
(Eio) corresponds to monolithic-per-backend designs whose mission differs
from ours.

The [RES-021] contextualization step: concretize the proposed abstraction in
our type system. `Kernel.Thread.Executor.Completion` would mirror
`Kernel.Thread.Executor.Polling` exactly in structure — same base primitives
(`Executor.Job.Queue`, `Executor.Shutdown.Flag`, `Kernel.Thread.Mutex`,
`Kernel.Thread.Handle`), same `SerialExecutor + TaskExecutor + @unsafe
@unchecked Sendable` shape, same `isIsolatingCurrentContext` /
`checkIsolated` pattern. The only divergences are (a) the owned resource
(`Kernel.Completion` vs `Kernel.Event.Source`) and (b) the tick closure's
shape.

Universal prior-art adoption does not imply necessity: even with the
structural parallelism, if the consumer count never exceeds one, the
abstraction is vocabulary overhead. Decision #6 of executor-package-design.md
deferred IOCP-Polling on similar reasoning (ship the composition when the
consumer lands). The analogue here: ship the Completion executor now (one consumer exists)
or defer (wait for IOCP's proactor to arrive as a second consumer).

## Analysis

### Evaluation Criteria

| Criterion | Weight | Notes |
|-----------|--------|-------|
| Answers the user's framing | High | Loops stop conforming to SerialExecutor themselves (per the explicit request) |
| Respects flush-before-wait | Mandatory | Completion I/O correctness — [IMPL-090] |
| Consumer count justifies cost | High | [PATTERN-013] / [IMPL-087] / [PATTERN-054]: do not mint a type for one consumer unless the domain is complete |
| Compile-time correctness | High | [IMPL-COMPILE]: the type system expresses who owns what |
| Tick closure is intent-readable | Medium | [IMPL-INTENT]: consumer code reads as flush/drain/dispatch, not mechanism |
| Per-op overhead ≤5 ns beyond raw syscall | Medium | Matches executor-package-design.md V6 budget |
| Naming compliance | Mandatory | [API-NAME-001], [API-NAME-002] — nested, no compounds |
| No upward/lateral dep violation | Mandatory | [PLAT-ARCH-001]; swift-executors is L3, io is L3 — this is a lateral add that goes through `swift-executors → swift-kernel` L1→L1 dep that's already accepted (Decision #2) |

### Option A — `Kernel.Thread.Executor.Completion` with a Polling-symmetric single-thunk tick

**Shape**: a new L3 composition in `swift-executors` that accepts a
`Kernel.Completion` resource and exposes exactly the same tick contract as
`Kernel.Thread.Executor.Polling` — a single `wait` thunk that either yields
the cycle's completion events or throws the Kernel-layer error. The
executor, not the consumer, owns the flush-before-wait ordering: internally
it runs `flush → drain → (if empty) notification.wait → drain`, then calls
tick with the materialised buffer of `Kernel.Completion.Event`.

```swift
extension Kernel.Thread.Executor {
    public final class Completion: SerialExecutor, TaskExecutor,
                                 @unsafe @unchecked Sendable {
        public enum Outcome: Sendable { case `continue`, halt }

        private var jobs: Executor_Primitives.Executor.Job.Queue
        private var drainBuffer: Executor_Primitives.Executor.Job.Queue
        private let queueLock: Kernel.Thread.Mutex
        private var _kernel: Kernel.Completion?
        private let _shutdown: Executor_Primitives.Executor.Shutdown.Flag
        private var threadHandle: Kernel.Thread.Handle?
        private let maxCompletionsPerPoll: Int
        private let tick: (
            () throws(Kernel.Completion.Error) -> UnsafeBufferPointer<Kernel.Completion.Event>
        ) -> Outcome

        public init(
            kernel: consuming Kernel.Completion,
            maxCompletionsPerPoll: Int = 256,
            tick: sending @escaping (
                () throws(Kernel.Completion.Error) -> UnsafeBufferPointer<Kernel.Completion.Event>
            ) -> Outcome
        )

        public func enqueue(_ job: consuming ExecutorJob)
        public func enqueue(_ job: UnownedJob)
        public func asUnownedSerialExecutor() -> UnownedSerialExecutor
        public func asUnownedTaskExecutor() -> UnownedTaskExecutor
        public func isIsolatingCurrentContext() -> Bool?
        public func checkIsolated()
        public func shutdown()

        /// Coroutine-scoped access to the kernel for submit/cancel from
        /// actor methods pinned to this executor. Mirrors Polling's
        /// `source` accessor.
        public var kernel: Kernel.Completion {
            _read { yield _kernel! }
            _modify { yield &_kernel! }
        }

        private func runLoop() {
            var eventBuffer = Array<Kernel.Completion.Event>(
                repeating: .empty, count: maxCompletionsPerPoll
            )
            while !_shutdown.isSet {
                drainJobs()
                if _shutdown.isSet { break }

                // Completion phase ordering — owned by the executor, invisible
                // to the consumer. Flush, then drain, then (if nothing was
                // drained) block on notification, then drain again.
                let count: Int
                let waitError: Kernel.Completion.Error?
                do throws(Kernel.Completion.Error) {
                    _ = try _kernel!.flush()
                    var drained = 0
                    _kernel!.drain { event in
                        if drained < eventBuffer.count {
                            eventBuffer[drained] = event
                        }
                        drained += 1
                    }
                    if drained == 0 {
                        _kernel!.notification?.wait()
                        _kernel!.drain { event in
                            if drained < eventBuffer.count {
                                eventBuffer[drained] = event
                            }
                            drained += 1
                        }
                    }
                    count = min(drained, eventBuffer.count)
                    waitError = nil
                } catch {
                    count = 0
                    waitError = error
                }
                if _shutdown.isSet { break }

                // Region-materialise the result into a sendable local
                // before crossing the tick boundary — same pattern Polling
                // uses per [IMPL-091].
                let outcome = unsafe eventBuffer.withUnsafeBufferPointer { base in
                    unsafe tick { () throws(Kernel.Completion.Error) -> UnsafeBufferPointer<Kernel.Completion.Event> in
                        if let waitError { throw waitError }
                        return unsafe UnsafeBufferPointer<Kernel.Completion.Event>(
                            start: base.baseAddress, count: count
                        )
                    }
                }
                if case .halt = outcome { _shutdown.set(); break }
            }
            drainJobs()
        }
    }
}
```

**IO Completions post-migration** collapses to a single public actor,
mirroring `IO.Event.Actor` exactly. The old three-layer shape
(`IO.Completions` struct wrapper + internal `IO.Completions.Actor` +
`IO.Completion.Loop` class) is flattened into one:

```swift
extension IO.Completion {
    public actor Actor {
        nonisolated private let proactor: Kernel.Thread.Executor.Completion
        private var entries: Dictionary<Kernel.Completion.Token, Entry> = .init()
        private var state: State = .running
        private var _nextID: UInt64 = 1

        /// Fresh proactor via the platform factory.
        public init() throws(Kernel.Completion.Error) {
            let kernel = try Kernel.Completion.platform()
            try self.init(kernel: consume kernel)
        }

        /// Inject a kernel resource (fake driver, pre-built source, etc.).
        public init(kernel: consuming Kernel.Completion) {
            let handle = Handle()
            self.proactor = Kernel.Thread.Executor.Completion(
                kernel: consume kernel,
                tick: Self.makeTick(for: handle)
            )
            handle.actor = self
        }

        /// Process-shared proactor.
        public static func shared() throws(Kernel.Completion.Error) -> Actor {
            try _shared.get()
        }
        private static let _shared: Result<Actor, Kernel.Completion.Error> = {
            do throws(Kernel.Completion.Error) {
                return .success(try Actor())
            } catch { return .failure(error) }
        }()

        nonisolated public var unownedExecutor: UnownedSerialExecutor {
            proactor.asUnownedSerialExecutor()
        }

        deinit { proactor.shutdown() }
    }
}

// MARK: - Tick construction (Handle weak-box per [IMPL-083])

extension IO.Completion.Actor {
    private static func makeTick(
        for handle: Handle
    ) -> @Sendable (
        () throws(Kernel.Completion.Error) -> UnsafeBufferPointer<Kernel.Completion.Event>
    ) -> Kernel.Thread.Executor.Completion.Outcome {
        return { wait in
            guard let actor = handle.actor else { return .halt }

            // Materialise outside assumeIsolated per [IMPL-091].
            let events: UnsafeBufferPointer<Kernel.Completion.Event>
            let waitError: Kernel.Completion.Error?
            do throws(Kernel.Completion.Error) {
                events = unsafe try wait()
                waitError = nil
            } catch {
                events = UnsafeBufferPointer(start: nil, count: 0)
                waitError = error
            }

            return actor.assumeIsolated { isolated in
                guard isolated.state == .running else { return .halt }
                if let err = waitError {
                    return isolated.retryDecision(for: err)
                }
                isolated.checkCancellations()
                unsafe isolated.dispatch(events)
                return .continue
            }
        }
    }
}

// MARK: - Witness operations (read / write / close / ready)

extension IO.Completion.Actor {
    func read(from fd: borrowing Kernel.Descriptor,
              into buffer: Memory.Buffer.Mutable) async throws(IO.Error) -> Int {
        // ... build Operation, then:
        //     try proactor.kernel.submit(submission, target: descriptor)
        // entries.set(id, consume entry)
        // suspend; dispatch resolves the entry; resume; decode outcome
    }
    // write / close / ready / cancel-handshake awaitOperation — same shape
    // as today's IO.Completions.Actor, just with proactor.kernel for submit.
}
```

The Handle weak-box (`IO.Completion.Actor.Handle`) is the same
init-order-trap solution Events uses — a local class captured by the tick
closure, its `weak var actor` filled at the tail of `init` after `proactor`
is assigned. See [IMPL-083]. No `[weak self]` on the tick closure (the
binding doesn't exist yet when the closure is constructed).

**Files deleted from swift-io's IO Completions target**:

| File | Reason |
|------|--------|
| `IO.Completion.Loop.swift` | Executor machinery moved entirely to `Kernel.Thread.Executor.Completion` |
| `IO.Completions.swift` | Struct wrapper collapsed; `IO.Completion.Actor` is the public handle |
| `IO.Completions.Actor.swift` | Internal actor renamed/promoted to public `IO.Completion.Actor` |
| `IO.Completion.Wakeup.swift` + `.Channel.swift` | Wakeup ownership moves to `Kernel.Completion.wakeup` inside the Completion; L3 wrapper no longer needed |

**Files added**:

| File | Contents |
|------|----------|
| `IO.Completion.Actor.swift` | The public actor (init + deinit + unownedExecutor + makeTick) |
| `IO.Completion.Actor.Handle.swift` | Weak-box class, [IMPL-083] pattern |
| `IO.Completion.Actor.State.swift` | `.running` / `.shuttingDown` — mirrors `IO.Event.Actor.State` |

**Files retained**:

| File | Role |
|------|------|
| `IO.Completion.swift`, `.Kind.swift`, `.Flags.swift`, `.ID.swift` | Typealiases to Kernel types (Phase 1) |
| `IO.Completion.Outcome.swift`, `.Success.swift` | Outcome taxonomy + `init(from:kind:)` translation |
| `IO.Completion.Operation.swift`, `.Operation.Storage.swift` | Typed Operation factory + retained-storage slot |
| `IO.Completion.Entry.swift` | In-flight record with continuation — now held in the actor's `entries` table |
| `IO.Completion.Cancellation.Flag.swift` | Atomic flag shared with `onCancel` handler (the nesting `Cancellation` namespace may flatten per [API-NAME-001a] — Phase 3 cleanup) |
| `IO+Completions.swift` | Factory rewired: `IO.completions(on: IO.Completion.Actor)` |

**Shape parallel after the migration**:

| | Fresh instance | Shared instance |
|--|---------------|-----------------|
| Blocking | `IO.Blocking()` | `IO.Blocking.shared` |
| Events | `try IO.Event.Actor()` | `try IO.Event.Actor.shared()` |
| Completions | `try IO.Completion.Actor()` | `try IO.Completion.Actor.shared()` |

All three strategies expose a single-layer public entry point. No struct
wrappers, no intermediate Loop classes. Identical factory shape.

**Flush-before-wait correctness**: the executor's runLoop ALWAYS does
`drainJobs → flush → drain → (if empty) notification.wait → drain → tick`
in that exact order. SQEs submitted during drainJobs (by actor methods
calling `executor.kernel.submit(...)`) are flushed before any blocking wait.
The consumer's tick body sees only the events buffer. **Ordering is encoded
by the executor and cannot be got wrong by the consumer.**

**Data-contract alignment per [IMPL-090]**: the consumer reads the tick
thunk's result and dispatches every event. The consumer does NOT ignore the
executor's core output (unlike the rejected Polling-adapter path).

**Backend neutrality**: the Completion type references `Kernel.Completion`,
`Kernel.Completion.Error`, `Kernel.Completion.Event`. It does not name
`io_uring`, `IOCP`, `eventfd`, `GetQueuedCompletionStatusEx`, or any backend
primitive. If `Kernel.Completion` in swift-kernel gains a Windows backend
tomorrow, the Completion executor serves it without any change — mirroring how Polling
would serve a future Windows readiness backend if one were plumbed through
`Kernel.Event.Source`.

**State ownership split**:

| State | Owner | Rationale |
|-------|-------|-----------|
| OS thread | Completion | Executor-generic |
| Job queue + drain buffer | Completion | Executor-generic |
| Mutex / shutdown flag | Completion | Executor-generic |
| `Kernel.Completion` resource | Completion | Tied to executor lifecycle; flush/drain/wait are executor-thread-confined |
| Entries table | Loop | Domain — keyed by `Kernel.Completion.Token`, contains continuations |
| Cancellation handshake coordinator | Actor | Cross-thread coordination outside executor |

**Tick closure shape**: thunks-as-parameters mirrors Polling's `wait` thunk
per [IMPL-092] (throws-thunk over Result). The consumer calls each thunk in
the proactor-correct order. The shape encodes:

- `flush` throws `Kernel.Completion.Error` — consumer chooses retry vs halt.
- `drainAndWait` is non-throwing (per current `kernel.drain` + non-throwing
  `notification.wait()` signatures). Returns drained count for diagnostics.
- Both thunks capture the kernel reference — valid only during the tick call
  (the kernel is not available during drainJobs).

**Kernel access via coroutine `_read`/`_modify`**: `submit` (called from
actor methods pinned to the Completion executor) reaches the kernel via
`executor.kernel.submit(...)`. The coroutine accessor yields a borrow of
the wrapped `Kernel.Completion`, mirroring Polling's `source` accessor
pattern.

**Pros**:

- Answers the user's framing: `IO.Completion.Loop` stops conforming to
  `SerialExecutor` / `TaskExecutor`.
- Structural parallel to `IO.Event.Loop → Polling`. Consumer migration
  pattern is identical: actor owns executor, forwards `unownedExecutor`,
  supplies a tick closure that handles error / dispatch / halt.
- Backend-neutral: Completion references only `Kernel.Completion` +
  `Kernel.Completion.Error` + `Kernel.Completion.Event`. No platform
  conditionals, no backend names. Any future `Kernel.Completion`
  backend is served without touching `swift-executors`.
- Flush-before-wait is owned by the executor. Consumers cannot get the
  ordering wrong. The tick closure matches Polling's single-thunk shape
  exactly, so the consumer's migration shape from Events carries over.
- `Kernel.Completion` lifecycle moves inside the executor (single owner,
  single-thread access). Eliminates the take-restore bookkeeping the
  Phase 1 Loop has for `Optional<Kernel.Completion>` stored on a class.
- Future `Kernel.Completion` consumers (test harnesses, embedded
  proactor scenarios, a hypothetical second swift-io-style package)
  compose by holding `Completion` and supplying tick — same story as
  Polling.

**Cons**:

- Adds ~180 LOC to `swift-executors`: Completion class + tests + docs. Net
  LOC delta across packages: roughly +50 (the Loop loses ~130 LOC of
  executor-generic machinery, but Completion is wider than that, plus
  test surface).
- Public API surface in `swift-executors` grows by 1 type, 1 nested enum,
  ~8 methods.
- Actor identity for `IO.Completions.Actor` shifts from `IO.Completion.Loop`
  to the held `Completion` — observable in profilers and crash reports, not
  in user-visible API. Same trade-off Events made.
- `[weak self]` + nil-coalesce-`.halt` pattern at the tick site, same
  as Events — workable but a known-delicate lifecycle (Loop strongly holds
  Completion; Completion weakly captures Loop via tick).
- The proactor-shaped run loop (`flush → drain → maybe-wait → drain`)
  assumes `Kernel.Completion.drain` + `Kernel.Completion.notification`
  is sufficient for any unified backend. If a future backend's
  unification at Kernel requires a different run-loop shape (e.g. a
  single blocking call that bundles wait+drain), the Completion executor's run loop
  would need either parameterisation or a sibling composition. That's
  a speculative future problem, scoped to the Kernel Completion layer,
  not to this research.

### Option B — status quo (primitives-only refactor, already landed)

`IO.Completion.Loop` is itself `SerialExecutor + TaskExecutor + @unsafe
@unchecked Sendable`, uses L1 primitives for the queue / shutdown / mutex,
and directly owns the `Kernel.Completion` resource. Phase 1 refactor
already landed this shape (commit `7b7fca41`).

**Pros**:

- Zero additional LOC, zero new public API.
- Today's race-free architecture preserved (Loop IS the executor; single
  thread).
- Composable-executor-abstractions.md's Design 4 (status quo) reasoning
  applies directly to proactors too: the two-consumer argument was for
  Polling; the proactor has one consumer (io_uring on Linux).
- Matches [IMPL-087] discipline: don't create a component because
  framework convention suggests one; create it because a consumer's
  data contract requires it.

**Cons**:

- **Does not answer the user's request.** The Loop still conforms to
  `SerialExecutor` / `TaskExecutor` independently. The user's framing
  ("defer to swift-executors for the executor") is unmet.
- Asymmetric with Events post-Phase-1 (Event.Loop delegates; Completion.Loop
  conforms). New contributors have to recognize that the proactor path
  took a different structural choice.
- If IOCP (future) does warrant an executor shell of its own, the
  pattern of "each proactor backend rolls its own executor" proliferates.
  Option A at least establishes a canonical io_uring-serving Completion executor that a
  future IOCP executor can sibling under `Kernel.Thread.Executor.*`.

### Option C — `Kernel.Thread.Executor.Driven` (minimal thread+queue)

A generic thread+queue+shutdown executor with a closure-based tick (no
owned resource). Consumer owns the kernel-completion or event-source
resource directly and does everything in tick. Polling becomes a special
case: Polling = Driven + Kernel.Event.Source integration.

```swift
extension Kernel.Thread.Executor {
    public final class Driven: SerialExecutor, TaskExecutor, ... {
        public init(
            wake: @escaping @Sendable () -> Void,
            tick: sending @escaping @Sendable () -> Outcome
        )
        // queue + shutdown + thread + enqueue + unownedExecutor
    }
}
```

This is essentially Design 1 from composable-executor-abstractions.md —
the design that was superseded by the locked taxonomy in
executor-package-design.md.

**Pros**:

- Maximally generic: one executor shell serves reactor, proactor, and
  any future poll-based variant.
- Minimal public surface: one new type, no Wait.X variants.
- Consumer fully controls phase ordering.

**Cons**:

- Reduces Polling's existing abstraction value. Polling today owns
  `Kernel.Event.Source` and calls `waitSource.wait()` inline; refactoring
  Polling to use Driven pushes the wait back to the consumer's tick —
  regressing Event.Loop's migration.
- Loses the structural analogy between "executor owns wait primitive"
  and "Polling : Kernel.Event.Source :: Completion executor : Kernel.Completion." That
  analogy is what makes the taxonomy legible per the
  executor-package-design.md V7 naming compliance table.
- The wake closure is opaque — the executor has no visibility into
  whether the wake mechanism is a kernel eventfd, a condvar, or
  something else. Polling and Completion, by owning the wait primitive,
  have a typed wake channel (`waitSource.wakeup.wake()`).
- Rejected by executor-package-design.md V8's analysis: the polymorphism
  question was resolved in favor of sibling variants (Polling vs.
  future Completion) rather than a single parameterized shell.

### Option D — generalize Polling with a conditional proactor mode

Add a `flush: (() throws -> Int)? = nil` parameter to Polling. If non-nil,
Polling's runLoop inserts a `try? flush()` call BEFORE the blocking wait.
Same `Kernel.Event.Source`-based wait; just reorders phases.

**Pros**:

- Zero new public type.
- Minimal surface add (one optional parameter).

**Cons**:

- **Data contract mismatch per [IMPL-090] persists.** Polling's tick
  receives `UnsafeBufferPointer<Kernel.Event>` — the events from the
  wait. A proactor consumer's tick would ignore that buffer. The
  boundary reflection rejected exactly this: "the consumer ignores the
  shell's core output."
- Requires an adapter (the rejected `driver.asEventSource(handle)`)
  to turn `Kernel.Completion.notification` into a `Kernel.Event.Source`.
  That adapter was flagged as feasible on io_uring (via epoll-on-uring-fd)
  but not on IOCP — so the generalization fails for the second
  hypothetical consumer.
- Re-opens the question executor-package-design.md V8 resolved. Would
  need new rationale; none offered here.

This option is listed for completeness but rejected on first reading.

### Comparison

| Criterion                                | Option A (Completion) | Option B (status quo) | Option C (Driven) | Option D (Polling+flush) |
|------------------------------------------|:---:|:---:|:---:|:---:|
| Answers the user's framing?              | Yes | No  | Yes | Yes |
| Flush-before-wait correct?               | Yes — executor-owned | Yes — today | Yes — consumer-controlled | Yes — executor-forced |
| Respects [IMPL-090] (data-contract)?     | Yes | Yes | Yes | **No** |
| Mentions any backend (io_uring / IOCP)?  | **No** — takes `Kernel.Completion` | No | No | **Yes** — requires Kernel.Event.Source adapter over io_uring fd |
| Consumer story                           | Any `Kernel.Completion` backend (today: Linux io_uring; tomorrow: any Kernel-layer addition) | Same | Same | io_uring only via adapter |
| Public API add (swift-executors)         | 1 type + 1 enum + ~8 methods | 0 | 1 type + 1 enum + 1 protocol | 1 param on existing type |
| Net LOC Δ across packages                | ~+50 | 0 | ~−300 (replaces Polling) | ~+10 |
| Parallel to Events structure?            | Yes — single-thunk tick, `kernel` accessor mirror `source` | No | Yes (both use Driven) | Mixed |
| Preserves executor-package-design.md V8  | Yes | Yes | **No** — re-opens resolved decision | Yes |
| Kernel-layer unification honored         | Yes — executor neutral to `Kernel.Completion` backends | Yes | Yes | **No** — Polling-via-eventfd leaks io_uring knowledge into adapter |

Designs that fail [IMPL-090] or re-open V8 (C, D) are rejected without
further analysis. A and B are viable.

## Constraints

- **Flush-before-wait**: any proactor design MUST permit flush BEFORE the
  blocking wait, period. This is a correctness constraint established by the
  boundary reflection. Options A and B comply; C complies (consumer-controlled);
  D complies (executor-forced) but fails a different constraint.

- **Single consumer to date**: one Linux io_uring consumer
  (`IO.Completion.Loop`). Windows IOCP is deferred per
  `executor-package-design.md` Decision #6. [PATTERN-013] requires 3+
  conformers for a PROTOCOL; it does not apply to concrete types. But
  [IMPL-087] and [PATTERN-054] caution against minting a new type for one
  consumer if the domain can be expressed otherwise.

- **Actor identity migration**: any design that strips
  `IO.Completion.Loop`'s `SerialExecutor` conformance shifts the
  actor-pinning identity to a held executor. This is observable in
  profilers/crash-reports (not in user API). Events already took this hit at
  its Phase refactor. The cost is one-time.

- **No Sendable elevation**: neither option introduces `@unchecked Sendable`
  beyond the existing `@unsafe @unchecked Sendable` on the Completion class
  itself (inherited from the Polling pattern). The Loop's domain state
  remains non-Sendable; only the executor reference crosses isolation
  boundaries.

- **[PLAT-ARCH-001] layering**: `swift-executors` is L3; `swift-io` is L3. A
  lateral L3→L3 dep is forbidden. Option A routes through
  `swift-executors → swift-kernel` (L3→L3 is fine — both are in the
  swift-foundations superrepo as per the existing `IO Events` pattern).
  **Confirmed viable** in the executor-package-design.md migration plan.

- **L1 dep: `swift-executor-primitives → swift-kernel-primitives`**:
  accepted in executor-package-design.md Decision #2. No new dep needed for
  Option A (Completion owns a `Kernel.Completion` reference — the resource
  type is already accessible to executors via the existing dep chain).

## Outcome

**Status**: RECOMMENDATION

**Recommend Option A** (`Kernel.Thread.Executor.Completion`).

### Rationale

The user's stated aspiration — symmetry with Events' executor delegation —
is the deciding factor. Option A respects flush-before-wait, passes
[IMPL-090] (consumer uses the executor's output), mirrors Polling's
single-thunk tick shape exactly, and — most importantly — stays at the
correct layer. Completion references only `Kernel.Completion`,
`Kernel.Completion.Error`, `Kernel.Completion.Event`; it names no backend.
That matches how Polling references only `Kernel.Event.Source` and names
no backend. Unification is a Kernel-layer responsibility; swift-executors
consumes the unified primitive.

The [PATTERN-013] / [IMPL-087] pushback — "don't create a type for one
consumer" — has weight but is outweighed by three considerations:

1. **The abstraction already exists in primitive form** (`Executor.Job.Queue`,
   `Executor.Shutdown.Flag`, `Kernel.Thread.Mutex`,
   `Kernel.Completion`). The Completion executor is not a new concept; it is a known
   composition of known primitives with one additional coordination (the
   proactor-ordered run loop + tick invocation).

2. **The alternative (Option B) is already written and committed**.
   Refusing to factor leaves a permanent asymmetry: Event.Loop is a
   data-plane class, Completion.Loop is a full executor. Two nominally
   sibling components in the same target with diverging structure. The
   ecosystem convention (executor composition via swift-executors) is the
   conventional answer; departing from it needs stronger justification
   than "one consumer."

3. **The executor is consumer-count-invariant by design**. Because
   the Completion executor accepts any `Kernel.Completion`, the number of "consumers" is
   really the number of `Kernel.Completion` backends the Kernel layer
   unifies. Today that is one (io_uring on Linux). When a future backend
   plugs into `Kernel.Completion.platform()`, the Completion executor serves it without
   change. The "one consumer" concern is really "one Kernel.Completion
   backend" — a moving number tracked at the Kernel layer, not
   swift-executors.

### The naming holds: `Kernel.Thread.Executor.Completion`

The name reflects the classical reactor/proactor taxonomy (Schmidt et al.,
*Patterns for Concurrent and Networked Objects*, Chapter 4): this executor
drives the proactor pattern regardless of backend. The backend identity is
encoded in the `Kernel.Completion` resource it holds — exactly how Polling
is backend-neutral because backend identity lives in the `Kernel.Event.Source`
it holds.

If a future backend's Kernel-layer unification diverges so far from
`Kernel.Completion`'s contract that it needs its own primitive (e.g., a
`Kernel.IOCP` or `Kernel.CompletionPort` if IOCP turns out not to fit), the
response is a new Kernel-layer primitive + a new swift-executors sibling
composition named after THAT primitive — not a refactor of Completion. That
is the same policy Polling would follow if a new readiness mechanism needed
a distinct Kernel-layer primitive.

### Tick signature: single-thunk, Polling-symmetric

The first draft of this research considered a dual-thunk tick (separate
`flush` and `drainAndWait` parameters) that would expose the proactor
phases to the consumer. That shape was wrong: it pushed proactor phase
ordering into user code, asymmetric with Polling, and the "allow the
consumer to skip flush" micro-optimisation it enabled is not compelling
against the correctness cost of an orderable invariant in tick bodies.

The recommended shape is the Polling-symmetric single thunk:

```swift
tick: sending @escaping (
    () throws(Kernel.Completion.Error) -> UnsafeBufferPointer<Kernel.Completion.Event>
) -> Outcome
```

The consumer's tick body calls `try wait()` the same way Events' tick
calls it. The proactor's `flush → drain → maybe-wait → drain` sequence is
encapsulated inside Completion's runLoop and invisible to the consumer. The
consumer's only responsibilities are: dispatch the events, decide
continue/halt, handle the typed throws from wait.

### Implementation Sketch (for a DECISION phase)

A DECISION phase would produce:

1. **New file** `swift-executors/Sources/Executors/Kernel.Thread.Executor.Completion.swift`
   (~190 LOC + docs), structured identically to
   `Kernel.Thread.Executor.Polling.swift`. Takes a `consuming Kernel.Completion`
   and the single-thunk tick closure. Public API: 1 class + 1 nested enum
   (`Outcome`) + `kernel` coroutine accessor + standard executor methods
   (`enqueue × 2`, `asUnownedSerialExecutor`, `asUnownedTaskExecutor`,
   `isIsolatingCurrentContext`, `checkIsolated`, `shutdown`).

2. **Package.swift update** in swift-executors: no new product dep. The
   existing `Kernel` product transitively provides `Kernel.Completion`;
   same provenance as Polling's `Kernel.Event.Source`.

3. **swift-io Package.swift update**: IO Completions target already depends
   on swift-executor-primitives. Add `Executors` product dep (currently
   only IO Events and IO Blocking have it).

4. **swift-io IO Completions rewrite** — the collapsed shape described
   above:
   - DELETE `IO.Completion.Loop.swift`, `IO.Completions.swift`,
     `IO.Completions.Actor.swift`, `IO.Completion.Wakeup.swift`,
     `IO.Completion.Wakeup.Channel.swift`
   - ADD `IO.Completion.Actor.swift` (public actor, mirrors
     `IO.Event.Actor.swift` structure), `IO.Completion.Actor.Handle.swift`
     (weak-box), `IO.Completion.Actor.State.swift` (lifecycle enum)
   - UPDATE `IO+Completions.swift` factory to accept
     `IO.Completion.Actor`; `IO.completions()` calls `Actor.shared()`
   - UPDATE tests (`IO.Completions.Smoke.Tests.swift` and
     `Sockets.TCP.Listener.Tests.swift`): `try IO.Completions()` →
     `try IO.Completion.Actor()`

5. **Swift build + swift test validation** on macOS (compile-only for
   `#if os(Linux)`-guarded paths) and Linux (full run). The existing IO
   Completions smoke tests are Linux-only; they must pass unchanged (the
   migration is internal restructuring — public API shape of `IO` witness
   does not change).

6. **No new experiments required**: all primitives are already validated
   (Polling is the structural reference; the Handle weak-box is [IMPL-083]'s
   reference implementation in `IO.Event.Actor.Handle`; the `kernel`
   coroutine accessor mirrors Polling's `source` accessor).

Estimated net LOC across all packages:

| Package | LOC Δ |
|---------|-------|
| swift-executors (add Completion) | +190 |
| swift-io IO Completions (delete Loop + struct + internal actor + Wakeup wrapper; add Actor + Handle + State) | −260 |
| swift-io Tests + swift-sockets Tests (mechanical rename) | ≈0 |
| **Total** | **≈ −70** |

The migration is LOC-negative: removing Loop's executor machinery + the
struct/internal-actor indirection + the Wakeup.Channel wrapper outweighs
the Completion-executor addition in swift-executors.

### Locked Decisions

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | Executor name | **`Kernel.Thread.Executor.Completion`** | Mechanism word, not a pattern word. Mirrors `Polling`'s role (mechanism, not I/O-pattern). "Completion" is the industry-standard term for this mechanism (I/O Completion Port, completion queue). Type path `Kernel.Thread.Executor.Completion` disambiguates from the L1 resource `Kernel.Completion`. |
| 2 | Commit granularity | **One bundled commit** | swift-executors addition and swift-io collapse are structurally coupled: swift-io can't build without the new type; the new type has no meaningful consumer without swift-io's migration. Easier than orchestrating ordered cross-repo merges. |
| 3 | `kernel` accessor | **Coroutine `_read` / `_modify`** | Parallel to Polling's `source` coroutine accessor. Zero-hop borrow access from actor methods. `withKernel { }` closure alternative rejected as less ergonomic. |
| 4 | `maxCompletionsPerPoll` default | **256** | Matches Polling's `maxEventsPerPoll` default. Tunable via parameter. |

### Follow-up to revisit during implementation

**Single-inhabitant namespaces**: the collapse exposes
`IO.Completion.Cancellation` as a namespace-with-only-`.Flag`. Per
[API-NAME-001a] this is a variant label, not a namespace. Candidate
resolutions:

- Flatten to `IO.Completion.Actor.CancellationFlag` if the flag can become
  actor-private (check: `onCancel` handler captures it via @Sendable
  closure; currently public).
- Keep the namespace and its single inhabitant as today, noting that
  Phase 3 cleanup can revisit once all accidental-decomposition cases
  are catalogued.

Not a blocker for the Completion-executor migration. Resolve in a
follow-up commit or during Phase 3 (accidental-decomposition cleanup).

## References

- [composable-executor-abstractions.md](./composable-executor-abstractions.md)
  — the Design 1 precedent that became `Kernel.Thread.Executor.Polling`
- [executor-package-design.md](./executor-package-design.md) — the locked
  seven-composition taxonomy and Decision #6 (IOCP deferral)
- [proactor-generalization-iocp-windows.md](../../Research/proactor-generalization-iocp-windows.md)
  — Tier-3 research tracking the broader IOCP question (DRAFT)
- [2026-04-15-completion-loop-proactor-reactor-boundary.md](../../swift-io/Research/Reflections/2026-04-15-completion-loop-proactor-reactor-boundary.md)
  — the reflection that established the flush-before-wait rejection of
  Option A (Polling absorbs proactor)
- swift-io commit `7b7fca41` — Phase 1 delegation-first refactor of IO
  Completions (witness delegation done; executor delegation deferred to
  this research)
- swift-executors `Kernel.Thread.Executor.Polling.swift` — the structural
  reference implementation this design mirrors
- Schmidt, Stal, Rohnert, Buschmann. *Pattern-Oriented Software
  Architecture, Volume 2: Patterns for Concurrent and Networked Objects.*
  Chapter 3 (Reactor) and Chapter 4 (Proactor). The classical
  reactor/proactor distinction that motivates the separate executor
  composition.
- [Swift NIO SelectableEventLoop](https://github.com/apple/swift-nio/blob/main/Sources/NIOPosix/SelectableEventLoop.swift)
  — io_uring-through-reactor adaptation pattern (what we chose NOT to do)
- [Tokio io-driver park/unpark](https://docs.rs/tokio/latest/tokio/runtime/index.html)
  — scheduler-on-driver separation pattern
- [libuv uv_loop_t](https://github.com/libuv/libuv) — unified event loop
  across reactor/proactor backends
- [API-NAME-001] — Nest.Name pattern
- [API-NAME-001a] — single-type-no-namespace rule (naming option 2 above)
- [API-NAME-003] — specification-mirroring names
- [IMPL-087] — question whether the component needs to exist
- [IMPL-090] — abstraction-seam validity requires data-contract alignment
- [IMPL-092] — `throws(E)` thunk parameters over `Result<T, E>`
- [IMPL-COMPILE] — compiler as primary correctness mechanism
- [PATTERN-013] — protocol threshold
- [PATTERN-054] — verify academic grounding before minting a named type
- [PLAT-ARCH-001] — four-level platform stack
- [RES-021] — prior art survey with contextualization step
