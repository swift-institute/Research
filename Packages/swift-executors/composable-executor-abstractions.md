# Composable Executor Abstractions

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: RECOMMENDATION
tier: 2
---
-->

## Question

Can `swift-executors` provide primitive abstractions such that `IO.Event.Loop` and
`IO.Completion.Loop` (and any future polling-style L3 consumer) compose with
`swift-executors` instead of implementing `SerialExecutor` / `TaskExecutor`
conformances independently?

The triage at `swift-io/Research/executor-conformance-triage.md` concluded
**Option D — keep duplication** on the grounds that direct composition with the
existing `Kernel.Thread.Executor` is impossible (the condvar-blocking and
poll-blocking models do not share a wait primitive, and a held-executor
arrangement re-creates a data race on the loops' domain state). This document
re-asks the question one level up: rather than holding `Kernel.Thread.Executor`,
could the loops hold a **new, purpose-built primitive in `swift-executors`** that
captures the executor-generic shape of a poll-blocking loop?

## Context

The triage's load-bearing finding is that you cannot share a thread between
condvar-blocking and poll-blocking dispatch: the IO loops park in
`kevent`/`epoll_wait`/`io_uring_enter` (kernel-level wait, no lock held), and
the wake mechanism is a kernel-level wakeup channel
(`EVFILT_USER`/`eventfd`/`PostQueuedCompletionStatus`). `Kernel.Thread.Executor`
parks in `pthread_cond_wait` (lock held) and wakes via condvar broadcast.
These are two different categories of executor.

The triage's narrower follow-up (Option C) was to extract a `PollingJobQueue`
helper that absorbs the queue + lock + drain mechanics shared between the two
IO loops. It quantified the savings as ~60 LOC and the cost as ~50–60 LOC
(roughly break-even), and concluded the abstraction was not worth the extra
public surface.

This document re-opens the same question with a wider lens. The user's
counter-hypothesis is that the right abstraction is not "extract the queue
helper" but "provide a poll-blocking executor primitive that the loops can
delegate their `SerialExecutor` conformance to entirely." If
`swift-executors` shipped such a primitive, the IO loops would stop conforming
to `SerialExecutor`/`TaskExecutor` themselves and instead hold the new
primitive — and the current 110 LOC of executor-generic code per loop would
be retired to a single shared implementation.

The correctness constraint from the triage stands: any design that re-creates
the run-loop / actor-method race (different threads touching the loops'
domain state) is disqualified before further evaluation.

## Prior Art

### Production frameworks

**Swift NIO** (`NIOCore.EventLoop`, `NIOPosix.SelectableEventLoop`,
`NIOPosix.Selector`). NIO factors the polling-executor pattern into three
layers: `EventLoop` is the protocol surface (execute, scheduleTask,
makeFuture); `SelectableEventLoop` is the concrete poll-blocking implementation
that wraps a `Selector`; `Selector<Reg>` is generic over a backend-specific
registration type and dispatches the wait primitive to kqueue / epoll / io_uring
(in newer versions). NIO does **not** abstract the run-loop body itself — there
is effectively one `SelectableEventLoop` body, parameterized by the `Selector`,
that handles all NIO use cases. Per-loop polymorphism happens above the
`EventLoop` protocol (in channels and pipelines), not inside it.

**Tokio** (Rust). Tokio's `Runtime` is built by composing `Builder` steps that
enable the io driver, time driver, and signal driver. The conceptual primitive
is a "park / unpark" pair: `park()` blocks until work is ready or unpark fires;
`unpark()` is thread-safe and idempotent. Each driver implements park/unpark
(io::Driver parks in epoll_wait; time::Driver parks in a timer wheel until
the next deadline; signal::Driver parks on a signalfd). The runtime composes
these via a "composite driver" that calls each driver's poll in turn during
park. The scheduler (current_thread or multi_thread) is decoupled from the
drivers — both schedulers reuse the same driver composition.

**OCaml Eio** (`eio_main.run`, backends `eio_linux` for io_uring,
`eio_posix` for epoll/kqueue). Eio is effect-based: the runtime is largely
monolithic per backend, but the public surface is capability-based interfaces
(network, file system, clock, etc.) that the backend instantiates. The
backend selection is the polymorphism axis; the run-loop body is per-backend.

**Swift stdlib `SerialExecutor` / `TaskExecutor` / `SchedulableExecutor`**.
The protocols are minimal: `enqueue(_: ExecutorJob)`, `asUnownedSerialExecutor()`,
`asUnownedTaskExecutor()`, `checkIsolated()`, `isIsolatingCurrentContext()`,
plus `enqueue(_:after:tolerance:clock:)` on `SchedulableExecutor`. The standard
provides **no** infrastructure: no queue, no thread, no run-loop helper.
Implementors provide everything. This is by design — the protocols define
identity and dispatch contracts, not implementation strategy.

**Rust `futures::executor`** (`LocalPool`, `ThreadPool`, `block_on`).
`LocalPool` is thread-confined and exposes manual drive points
(`run`, `run_until_stalled`, `try_run_one`). The shared infrastructure is
the spawner/queue pair. There is no notion of a "polling executor" — the
abstractions are oriented at executing futures, not at composing with kernel
wait primitives.

### Shared infrastructure identified

Across these systems, the **universally present** machinery in any
single-thread polling-executor is:

1. **A job queue** (Deque/array of work items, with a cross-thread enqueue path).
2. **A lock or atomic guarding the queue** — minimal contention is preferred;
   the polling thread typically batches drains rather than dequeue-one-at-a-time.
3. **An OS thread** dedicated to the executor.
4. **A wakeup primitive** — a kernel-level mechanism (eventfd / kqueue user
   filter / IOCP sentinel / pipe) that the polling thread parks on alongside
   real I/O, so an enqueue from another thread can interrupt the park.
5. **A two-step shutdown** — set a halt flag (from inside the run loop's own
   work), wake the park, then join the thread externally.

The **polymorphic** axes are:

1. **The wait primitive** — what the polling thread parks in
   (`kevent`/`epoll_wait`/`io_uring_enter`/`GetQueuedCompletionStatusEx`).
2. **The wake primitive's exact mechanism** — but its *interface* is uniformly
   "fire once from any thread, idempotent under coalescing."
3. **The event-dispatch logic** — what the run loop does with the events
   returned by the wait primitive (NIO dispatches via channel pipelines;
   Tokio resolves pending I/O futures; the Swift IO loops resolve channel
   sends or completion entries).
4. **Domain state** — registrations, in-flight entries, source ownership.

The pattern across all four production systems (NIO, Tokio, Eio, futures-rs)
is that **shared infrastructure 1–5 is provided by the framework**, and
**polymorphism axes 1–4 are provided by the consumer/backend**. None of these
systems makes the consumer reimplement the queue-thread-wakeup-shutdown
machinery for every backend.

The Swift stdlib stands apart — it provides no infrastructure at all, leaving
the consumer to implement everything. This is appropriate for the stdlib
(which deliberately stays minimal) but leaves a clear opening one layer up
for a Swift-Institute-style infrastructure package to fill.

**Caveat per [RES-021]**: prior art universally factors out the queue-thread-
wakeup-shutdown machinery, but universal adoption does not imply universal
necessity. The Swift ecosystem's current state — exactly two poll-based
executor consumers, both in `swift-io`, owned by the same author — is a small
sample. A factored abstraction pays off either when the duplication count
grows past 2 or when the duplicated code drifts in subtle ways. Neither is
the case today.

## Current State Inventory

The following table compares the three executors in `swift-executors` and
`swift-io` along the eight axes the brief enumerated:

| Axis                | `Kernel.Thread.Executor`                                     | `IO.Event.Loop`                                               | `IO.Completion.Loop`                                                      |
|---------------------|--------------------------------------------------------------|---------------------------------------------------------------|--------------------------------------------------------------------------|
| Job queue           | `Job.Queue` — Deque<UnownedJob>, dequeue-one                 | `ContiguousArray<UnownedJob>` + drain-buffer swap (batch)     | `ContiguousArray<UnownedJob>` + drain-buffer swap (batch)                |
| Lock / sync         | `Kernel.Thread.Synchronization<1>` — mutex + 1 condvar (used) | `Kernel.Thread.Synchronization<1>` — mutex only (condvar unused) | `Kernel.Thread.Synchronization<1>` — mutex only (condvar unused)        |
| Thread spawn        | `Kernel.Thread.trap(Retained(self)) { runLoop() }`           | `Kernel.Thread.trap(Retained(self)) { runLoop() }`            | `Kernel.Thread.trap(Retained(self)) { runLoop() }`                       |
| Wait primitive      | `sync.wait()` — condvar, **lock held**                       | `source.poll(deadline:into:)` — `kevent`/`epoll_wait`, **no lock** | `driver.poll(handle, deadline:into:)` — `io_uring_enter`/IOCP, **no lock** |
| Wake primitive      | `sync.signal()` / `sync.broadcast()`                         | `wakeup.wake()` — kernel wakeup (EVFILT_USER / eventfd / IOCP sentinel) | `wakeup.wake()` — same family, may include `IORING_OP_NOP`               |
| Run-loop body       | `dequeue-one-under-lock → runJob`                            | `drainJobs → check shouldHalt → poll → dispatchEvents`        | `drainJobs → checkCancellations → flush → poll → dispatchCQEs`           |
| `enqueue(_:)` shape | `withLock { append; check isRunning }; if alive then signal else runInline` | `withLock { append; check isRunning }; if alive then wake else runInline` | `withLock { append; check isRunning }; if alive then wake else runInline` |
| Shutdown shape      | One-step: `withLock { isRunning = false }; broadcast(); join()` | Two-step: actor enqueues a job that sets `shouldHalt = true`; caller calls `loop.shutdown()` | Two-step: actor enqueues a job that calls `requestHalt()`; caller calls `loop.shutdown()` |
| `unownedExecutor`   | `UnownedSerialExecutor(ordinary: self)`                      | `UnownedSerialExecutor(ordinary: self)`                       | `UnownedSerialExecutor(ordinary: self)`                                  |
| Domain state        | None                                                         | `source: Kernel.Event.Source?`, `registrations: [ID: Registration]`, `wakeup`, `shouldHalt` | `driver: IO.Completion.Driver`, `handle: ...?`, `entries: [ID: Entry]`, `wakeup`, `shouldHalt` |

The two IO loops share the executor-generic shape across all axes except the
domain-specific tick body (poll-and-dispatch). They differ from
`Kernel.Thread.Executor` on every executor-mechanical axis except `unownedExecutor`
and the thread-spawn line. The triage's quantification holds: ~55 LOC per IO
loop is executor-generic; ~100 LOC per loop is domain-specific.

## Design Alternatives

Each design below is sketched at 20–50 LOC of skeleton (not full
implementation) and evaluated against the six brief criteria in the
**Analysis** section.

The naming throughout uses `Kernel.Thread.Polling.*` because the new types,
if added, are nested under the existing `Kernel.Thread.*` namespace where
`Kernel.Thread.Executor` already lives. `Polling` reads as the variant axis
("the polling-style variant of Kernel.Thread infrastructure"), parallel to
`Kernel.Thread.Executor.Sharded` (the sharded variant of the executor).
Per [API-NAME-001], `Polling` is the Nest, not a standalone concept; the
concrete types live underneath it.

Per [API-ERR-001] all throwing surfaces in the sketches use typed throws
where applicable. The sketches keep `Sendable`/ownership annotations
faithful to the existing executors' shape.

---

### Design 1 — `Kernel.Thread.Polling.Executor` with closure body

A new public class in `swift-executors` that **is** a `SerialExecutor +
TaskExecutor`. It owns the queue, lock, OS thread, and lifecycle. The
**poll-and-dispatch body** is supplied by the consumer as a closure passed at
init. The wake primitive is also a closure. The IO loops stop conforming to
`SerialExecutor` themselves; they hold a `Polling.Executor` and forward
`unownedExecutor` to it.

#### Skeleton — new types in `swift-executors`

```swift
extension Kernel.Thread {
    public enum Polling { }
}

extension Kernel.Thread.Polling {
    /// A serial + task executor whose run loop blocks in a consumer-supplied
    /// poll, with cross-thread wakeup also consumer-supplied.
    ///
    /// One OS thread. One job queue. The consumer's body runs once per
    /// iteration after the queue is drained, and decides whether to continue
    /// or halt. The body MUST execute on the executor's own thread — that is
    /// the only thread the executor's run loop calls it from.
    public final class Executor: SerialExecutor, TaskExecutor, @unchecked Sendable {
        public enum Outcome { case `continue`; case halt }

        private let sync: Kernel.Thread.Synchronization<1>
        private var jobs: ContiguousArray<UnownedJob> = []
        private var drainBuffer: ContiguousArray<UnownedJob> = []
        private var isRunning: Bool = true
        private var threadHandle: Kernel.Thread.Handle?
        private let wake: @Sendable () -> Void
        private let body: @Sendable () -> Outcome

        public init(
            wake: @escaping @Sendable () -> Void,
            body: @escaping @Sendable () -> Outcome
        ) {
            self.sync = Kernel.Thread.Synchronization()
            self.wake = wake
            self.body = body
            self.threadHandle = unsafe Kernel.Thread.trap(Ownership.Transfer.Retained(self)) { retained in
                let exec = retained.take()
                exec.runLoop()
            }
        }

        public func enqueue(_ job: UnownedJob) {
            let runInline: Bool = sync.withLock {
                guard isRunning else { return true }
                jobs.append(job)
                return false
            }
            if runInline { unsafe job.runSynchronously(on: asUnownedSerialExecutor()) }
            else         { wake() }
        }

        public func enqueue(_ job: consuming ExecutorJob) { enqueue(UnownedJob(job)) }

        public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
            unsafe UnownedSerialExecutor(ordinary: self)
        }

        public func shutdown() { /* mark !isRunning, wake, join */ }

        private func runLoop() {
            while true {
                drainJobs()
                if case .halt = body() { break }
            }
            sync.withLock { isRunning = false }
        }

        private func drainJobs() {
            while true {
                sync.withLock { swap(&jobs, &drainBuffer) }
                guard !drainBuffer.isEmpty else { return }
                for job in drainBuffer {
                    unsafe job.runSynchronously(on: asUnownedSerialExecutor())
                }
                drainBuffer.removeAll(keepingCapacity: true)
            }
        }
    }
}
```

#### Skeleton — IO.Event.Loop after migration

```swift
extension IO.Event {
    public final class Loop: @unchecked Sendable {  // NOTE: no longer SerialExecutor/TaskExecutor
        private var executor: Kernel.Thread.Polling.Executor!
        private let wakeup: IO.Event.Wakeup.Channel
        private var source: Kernel.Event.Source?
        var registrations: [IO.Event.ID: Registration] = [:]
        var shouldHalt: Bool = false

        init(source: consuming Kernel.Event.Source) {
            self.wakeup = IO.Event.Wakeup.Channel(source.wakeup)
            self.source = consume source
            self.executor = Kernel.Thread.Polling.Executor(
                wake: { [weak self] in self?.wakeup.wake() },
                body: { [weak self] in self?.tick() ?? .halt }
            )
        }

        public var unownedExecutor: UnownedSerialExecutor {
            executor.asUnownedSerialExecutor()
        }

        private func tick() -> Kernel.Thread.Polling.Executor.Outcome {
            if shouldHalt { return .halt }
            var buf = Array<Kernel.Event>(repeating: .empty, count: 256)
            do throws(Kernel.Event.Driver.Error) {
                let n = try source!.poll(deadline: nil, into: &buf)
                if n > 0 { dispatchEvents(buffer: &buf, count: n) }
            } catch { /* EINTR / ENOMEM / EAGAIN handling, identical to today */ }
            return .continue
        }

        // dispatchEvents, withSource — unchanged in shape
    }
}
```

#### Layering

`Kernel.Thread.Polling.Executor` lives in `swift-executors`'s `Executors`
target. New file: `Sources/Executors/Kernel.Thread.Polling.Executor.swift`,
plus a one-line namespace declaration `Kernel.Thread.Polling.swift`. No new
package dependencies — the implementation needs only what
`Kernel.Thread.Executor` already imports
(`Kernel`, `Thread Synchronization`).

`swift-io`'s `IO Events` and `IO Completions` targets gain a dependency on
`Executors`. Today they do not depend on it (only `IO Blocking` does). This is
the same architectural change the triage flagged for Option C; it is
unavoidable for any design that moves machinery to `swift-executors`.

Per [PLAT-ARCH-001] this respects layering: `swift-executors` is L3, depends
on L1 (`Kernel_Primitives` via `Kernel`) and L1 (`Thread Synchronization`).
The IO loops that hold the new primitive are also L3. No upward or lateral
dependency violation. No Foundation import.

#### Variance / genericity

The polymorphic axes (wait primitive, dispatch logic, error propagation) live
**inside** the `body` closure, which captures whatever the consumer needs.
The `Polling.Executor` itself is non-generic — there are no type parameters
on the executor class. This trades genericity for ABI stability and
implementation simplicity.

Per [IMPL-COMPILE], the consumer's invariant ("I poll on this kernel
primitive, I dispatch to those entries") is expressed in the closure body and
verified by the closure's own typed throws. The executor enforces nothing
about the body — it just runs it on the executor thread. This is weaker
than a generic constraint but stronger than an existential erasure: the
closure type is `@Sendable () -> Outcome`, monomorphic per call site.

A `@Witness`-style alternative (passing a `Polling.Body` witness struct
holding `_tick` and `_wake` closures) would be functionally equivalent to
the closure pair. The closure pair is simpler at the call site and skips the
indirection through a witness wrapper — for a 2-method "protocol," a witness
is heavier than its payload.

#### Race-safety

The closures are invoked from a single thread — the OS thread spawned in
`Polling.Executor.init`. The consumer's `body` runs on that thread; the
consumer's `wake` runs on whatever thread invokes `enqueue`. The Loop's
domain state (`source`, `registrations`, `entries`) is touched only from
inside `body` (poll dispatch) and from actor methods pinned to the
`Polling.Executor` (which run on the same OS thread because the actor is
pinned to the executor's identity). Same-thread access → no race.

This passes the triage's race check explicitly. The held-executor failure
mode the triage identified (Loop on thread A, held executor on thread B,
both touching `source`/`registrations`) does **not** apply here, because the
Loop holds no thread of its own — the executor's thread is the only thread
touching domain state.

#### Per-op overhead

Compared to today's hand-rolled `IO.Event.Loop`:

| Operation                              | Today                              | Design 1                                    | Δ               |
|----------------------------------------|------------------------------------|---------------------------------------------|-----------------|
| `enqueue(UnownedJob)` cross-thread     | direct `withLock`+wake             | direct `withLock`+wake (same body, on `Polling.Executor`) | ≈ 0 ns          |
| `enqueue` runtime call to `unownedExecutor` | direct call                  | direct call (target now `Polling.Executor`) | ≈ 0 ns          |
| Per-tick body invocation               | direct method on `Loop`            | indirect call through `@Sendable` closure   | +3–5 ns / iter  |
| Per-tick wake                          | direct method on wakeup            | indirect call through `@Sendable` closure   | +3–5 ns / wake  |
| Per-iteration drain                    | inline in `runLoop`                | inline in `Polling.Executor.runLoop`        | ≈ 0 ns          |

Iteration latency is bounded by the kernel poll syscall — `epoll_wait` ≥ 500 ns
unblocked, microseconds typical. ~10 ns / iteration overhead is
~0.1–2% in the hot path, ~0% with realistic I/O wait. **Acceptable** under
the brief's <50 ns target. Should be confirmed with the io-bench suite
before merge.

#### Naming

- `Kernel.Thread.Polling` — namespace (empty enum)
- `Kernel.Thread.Polling.Executor` — the executor class
- `Kernel.Thread.Polling.Executor.Outcome` — return type for `body`

All names are nested per [API-NAME-001]; no compound identifiers per
[API-NAME-002]. `Outcome` (rather than `Result`) avoids stdlib collision.

#### Error strategy

The `body` closure's return type is `Outcome` — non-throwing. Errors that
arise inside the body are the consumer's responsibility to handle (the IO
loops catch `Kernel.Event.Driver.Error` and `IO.Completion.Error` inside
their tick functions and continue/halt accordingly, exactly as they do
today). The executor itself does not throw; `init` does not throw; `enqueue`
does not throw. `shutdown` does not throw (failures inside join are
unrecoverable — same trap-on-error semantics as `Kernel.Thread.Executor`
today).

Per [API-ERR-001], any future throwing surface introduced on the executor
would use typed throws with a nested `Kernel.Thread.Polling.Executor.Error`
enum. None is needed today.

#### Pros and cons

Pros:
- Loops stop conforming to `SerialExecutor` / `TaskExecutor`. Conformance
  duplication is fully eliminated for the polling case.
- ~110 LOC removed from the IO loops (~55 per loop: queue/lock/drain/enqueue/
  asUnownedSerialExecutor/threadHandle/shutdown).
- A single audit-able place for the poll-blocking executor's semantics. Future
  poll-based executors compose by holding a `Polling.Executor` and supplying
  body+wake.
- Future "structured" wait primitives (e.g., a Linux signalfd-folded variant,
  a hypothetical `IO.Signal.Loop`) get the same scaffolding for free.

Cons:
- Adds ~150 LOC to `swift-executors` (executor body + tests + docs). Net LOC
  change: roughly +90 across both packages.
- Public API surface in `swift-executors` grows by 1 type, 1 nested enum,
  ~6 methods.
- Actor identity for `IO.Events.Actor` and `IO.Completions.Actor` shifts from
  the Loop to the held `Polling.Executor`. `unownedExecutor` continues to
  return a valid identity, but tools/inspectors/profilers that key on
  executor type names will see `Polling.Executor` instead of `Loop`.
- `[weak self]` capture in body / wake. Lifecycle: Loop strongly holds
  Polling.Executor; Polling.Executor weakly captures Loop via closures.
  Loop.shutdown sets `shouldHalt`, which causes `tick()` to return `.halt`,
  which lets the executor's run loop exit cleanly, after which Loop.deinit
  drops the executor (executor's deinit joins the thread if not yet joined).
  This is workable but more delicate than today's "Loop is the executor"
  model. Documented and tested patterns mitigate.
- Closure-typed body / wake means **no compile-time guarantee** that the
  consumer's body in fact only runs on the executor thread. The contract is
  documented but not type-enforced. ([IMPL-COMPILE] cannot help here without
  a richer mechanism — see Open Question 2.)

---

### Design 2 — `Kernel.Thread.Polling.JobQueue` helper (queue-only)

The narrower extraction the triage proposed as Option C: a public helper in
`swift-executors` that absorbs the queue + lock + drain mechanics. The Loop
still owns the OS thread and **still conforms to** `SerialExecutor` /
`TaskExecutor`; it forwards `enqueue` and `drain` to the helper.

#### Skeleton — new types in `swift-executors`

```swift
extension Kernel.Thread.Polling {
    /// Shared queue + drain mechanics for poll-blocking executors.
    ///
    /// Thread-safe enqueue. Single-thread drain (caller MUST be on the
    /// owning executor thread). The owning class still conforms to
    /// `SerialExecutor` itself; this helper provides only the queue.
    public final class JobQueue: @unchecked Sendable {
        private let sync: Kernel.Thread.Synchronization<1>
        private var jobs: ContiguousArray<UnownedJob> = []
        private var drainBuffer: ContiguousArray<UnownedJob> = []
        private var isRunning: Bool = true
        private let wake: @Sendable () -> Void

        public init(wake: @escaping @Sendable () -> Void) {
            self.sync = Kernel.Thread.Synchronization()
            self.wake = wake
        }

        /// Enqueue. Returns `true` if the executor has shut down and the
        /// caller should run the job inline.
        public func enqueue(_ job: UnownedJob) -> Bool {
            let runInline: Bool = sync.withLock {
                guard isRunning else { return true }
                jobs.append(job)
                return false
            }
            if !runInline { wake() }
            return runInline
        }

        public func drain(_ runJob: (UnownedJob) -> Void) {
            while true {
                sync.withLock { swap(&jobs, &drainBuffer) }
                guard !drainBuffer.isEmpty else { return }
                for job in drainBuffer { runJob(job) }
                drainBuffer.removeAll(keepingCapacity: true)
            }
        }

        public func markShutdown() { sync.withLock { isRunning = false } }
    }
}
```

#### Skeleton — IO.Event.Loop after migration

```swift
extension IO.Event {
    public final class Loop: SerialExecutor, TaskExecutor, @unchecked Sendable {  // STILL conforms
        private let queue: Kernel.Thread.Polling.JobQueue
        private let wakeup: IO.Event.Wakeup.Channel
        private var source: Kernel.Event.Source?
        private var threadHandle: Kernel.Thread.Handle?
        var registrations: [IO.Event.ID: Registration] = [:]
        var shouldHalt: Bool = false

        init(source: consuming Kernel.Event.Source) {
            self.wakeup = IO.Event.Wakeup.Channel(source.wakeup)
            self.source = consume source
            let wakeup = self.wakeup
            self.queue = Kernel.Thread.Polling.JobQueue(wake: { wakeup.wake() })
            self.threadHandle = unsafe Kernel.Thread.trap(Ownership.Transfer.Retained(self)) { r in
                let loop = r.take(); loop.runLoop()
            }
        }

        public func enqueue(_ job: UnownedJob) {
            if queue.enqueue(job) {
                unsafe job.runSynchronously(on: asUnownedSerialExecutor())
            }
        }

        public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
            unsafe UnownedSerialExecutor(ordinary: self)
        }

        private func runLoop() {
            var buf = Array<Kernel.Event>(repeating: .empty, count: 256)
            while true {
                queue.drain { unsafe $0.runSynchronously(on: asUnownedSerialExecutor()) }
                if shouldHalt { break }
                // poll + dispatchEvents — unchanged from today
            }
            queue.markShutdown()
        }
        // shutdown(), deinit, dispatchEvents, withSource — unchanged
    }
}
```

#### Layering, variance, race-safety

Same as Design 1 for layering and race-safety. Variance: even simpler — the
`wake` closure is the only polymorphic surface; `drain` takes a closure for
how to run each job (which is always `runSynchronously(on: asUnownedSerialExecutor())`).

Race-safety: identical analysis to today's hand-rolled implementation. The
helper does not introduce any cross-thread invariants the Loop did not
already enforce.

#### Per-op overhead

| Operation                              | Today                              | Design 2                                    | Δ               |
|----------------------------------------|------------------------------------|---------------------------------------------|-----------------|
| `enqueue` (queue path)                 | direct `withLock`+wake             | indirect via JobQueue: same body            | +1–2 ns / call  |
| Per-iteration drain                    | inline                             | indirect via `queue.drain { closure }`      | +3–5 ns / iter  |
| Wake invocation                        | direct                             | indirect via stored closure                 | +3–5 ns / wake  |

Smaller delta than Design 1 because the run-loop body is not closure-wrapped.
Same conclusion: **acceptable**.

#### Naming, error strategy

- `Kernel.Thread.Polling.JobQueue` — the helper class
- No new error types. `markShutdown` cannot fail.

#### Pros and cons

Pros:
- Smallest API addition (1 class, 4 methods).
- Smallest LOC delta (~+50 in `swift-executors`, ~−60 in `swift-io`,
  net ≈ −10).
- Loops keep their `SerialExecutor` / `TaskExecutor` conformance and identity
  — zero observable change to consumers.
- No tricky lifecycle (no weak captures, no body closure).

Cons:
- **Does not answer the user's framing question.** The Loops still conform to
  `SerialExecutor` independently. Conformance duplication remains; only the
  queue mechanics are shared.
- Net LOC near break-even. The triage already explored this at the same
  conclusion.
- Adds a public type whose only consumers (today) are two IO loops in the same
  package, owned by the same author. Public-API cost vs. shared-implementation
  benefit is borderline.

---

### Design 3 — `Polling` macro generating SerialExecutor scaffolding

A `@Polling` macro in `swift-executors` (or a sibling package) that, when
applied to a `final class`, synthesizes:

1. The `SerialExecutor + TaskExecutor + @unchecked Sendable` conformance
2. The queue / lock / thread / shutdown machinery
3. The `enqueue(_:)`, `asUnownedSerialExecutor()`, `enqueue(_: ExecutorJob)` impls
4. A required protocol-level `tick()` and `wake()` for the consumer to
   implement

The conformer writes only domain code.

#### Skeleton

```swift
// In swift-executors (or a swift-executors-macros sibling):
public protocol PollingRunLoop: AnyObject, Sendable {
    func wake()
    func tick() -> Kernel.Thread.Polling.Outcome
}

@attached(member, names: arbitrary)
@attached(extension, conformances: SerialExecutor, TaskExecutor)
public macro Polling() = #externalMacro(module: "ExecutorsMacros", type: "PollingMacro")

// Consumer:
@Polling
public final class IO.Event.Loop: PollingRunLoop {
    private let wakeup: IO.Event.Wakeup.Channel
    private var source: Kernel.Event.Source?
    var registrations: [IO.Event.ID: Registration] = [:]
    var shouldHalt: Bool = false

    public func wake() { wakeup.wake() }
    public func tick() -> Kernel.Thread.Polling.Outcome {
        if shouldHalt { return .halt }
        // poll + dispatch
        return .continue
    }
}
```

The macro expansion synthesizes the queue, drain buffer, sync, isRunning,
threadHandle, the `enqueue` overloads, `asUnownedSerialExecutor`, the
`runLoop` private method (which calls `self.tick()` per iteration), and the
public `shutdown()`.

#### Layering

The macro requires a sibling target `ExecutorsMacros` (compiler plugin
target) added to `swift-executors`'s package. The runtime portion
(`PollingRunLoop` protocol, `Polling.Outcome` enum) lives in `Executors`
target. Macro plugins are SwiftPM-supported and impose modest build-time
cost.

#### Variance, race-safety, overhead

Variance is via the `PollingRunLoop` protocol: 2 methods. Race-safety is
identical to Design 1 (the macro-generated run loop calls `tick()` on the
executor thread; consumer state mutations happen there or in actor methods
pinned to the executor's identity, which is the macro-generated identity).

Overhead: 1 protocol-witness call per iteration (`tick()`), 1 protocol-witness
call per wake. Comparable to Design 1's closure overhead (+3–8 ns / op).

#### Pros and cons

Pros:
- Most ergonomic for the consumer: write only `wake()` and `tick()`,
  everything else is synthesized.
- Identity stays on the conforming class (the macro adds the conformance
  inline).
- Eliminates conformance duplication structurally — the duplication moves
  into macro expansion, where it is generated, not maintained.

Cons:
- **Highest engineering investment.** Macros are complex to author, test,
  and maintain. Diagnostic quality on macro-expansion failures is poor.
- Adds a sibling target for the macro plugin, with its own SwiftSyntax
  dependency — a significant build-time cost across every consumer.
- Macros are opaque to readers ("what does this expand to?"). Tooling
  (`-Xfrontend -dump-macro-expansions`) helps but is not standard practice.
- Locks consumers into the macro's queue/thread choices. A consumer who
  needs a different queue type (e.g., bounded, priority-ordered) cannot
  customize without forking the macro.
- For two consumers, the build cost and authoring cost likely exceed the
  ergonomics win. Macros pay off at higher consumer counts.

---

### Design 4 — Status quo (duplication preserved)

The triage's recommended Option D: do nothing in `swift-executors`. Both IO
loops continue to roll their own `SerialExecutor + TaskExecutor` conformance.
Each carries ~110 LOC of executor-generic code that is mechanically similar
across the two loops and structurally distinct from `Kernel.Thread.Executor`.

#### Pros and cons

Pros:
- Zero LOC change. Zero public API change. Zero consumer migration.
- Preserves today's race-free architecture by construction (Loop *is* the
  executor, single thread).
- The two duplicates are owned by the same author in the same superrepo;
  drift risk is minimal.
- No new public surface in `swift-executors` to maintain across versions.

Cons:
- Conformance duplication remains. Future poll-based executors will copy
  this pattern again, accumulating boilerplate.
- The "shape of a poll-blocking executor" is folklore in the codebase, not
  encoded in a type. New contributors must read existing loops to
  reconstruct the pattern.
- Does not answer the user's framing question.

---

## Analysis

| Criterion                                                | Design 1 (Polling.Executor) | Design 2 (JobQueue helper) | Design 3 (Polling macro) | Design 4 (Status quo) |
|----------------------------------------------------------|:---:|:---:|:---:|:---:|
| Covers Event + Completion?                               | Yes | Yes | Yes | Yes (today) |
| Kernel.Thread.Executor fits same abstraction?            | No  | No  | No  | N/A |
| Per-op overhead vs today                                 | +3–10 ns / iter | +3–7 ns / iter | +3–8 ns / iter | 0 |
| Public API growth in swift-executors                     | 1 type + nested enum, ~6 methods | 1 type, 4 methods | 1 macro + 1 protocol + 1 enum + macros target | 0 |
| `@Witness` ecosystem compatibility                       | Indirect — closures (could be re-shaped as witness) | Indirect — closures | Low — protocol-based, not witness-based | N/A |
| Race-safe (passes triage's run-loop / actor-method check)? | Yes — verified | Yes — identical to today | Yes — verified | Yes (today) |
| Net LOC delta (`swift-executors` + `swift-io`)           | ≈ +90 | ≈ −10 | ≈ +200 (macro impl + plugin) | 0 |
| **Loops stop conforming to `SerialExecutor` themselves?** | **Yes** | **No** | **Yes** (via macro) | **No** |

The last row is the operative one for the user's question. Designs 1 and 3
deliver the framing ("loops compose with swift-executors instead of
implementing SerialExecutor independently"). Designs 2 and 4 do not.

**Note on Kernel.Thread.Executor fit**: none of the polling-oriented designs
fit `Kernel.Thread.Executor` because its wait primitive is condvar-blocking
inside a held lock — a fundamentally different category, as the triage
established. Forcing it through the polling abstraction would require
exposing the queue's mutex so a condvar consumer can wait on it (Java-style
`synchronized` + `wait`/`notify`), which is uglier than today's separate
implementation. The right read is that `Kernel.Thread.Executor` and
`Polling.Executor` are sibling executor categories under
`Kernel.Thread.Executor`, not specializations of one abstraction. Treating
them as sibling categories is consistent with how the existing
`Kernel.Thread.Executor.Sharded` is a sibling variant of
`Kernel.Thread.Executor`.

## Recommendation

**Recommend Design 1 (`Kernel.Thread.Polling.Executor`) IF the user's
priority is structural composition, OR Design 4 (status quo) IF the priority
is minimal change. Reject Designs 2 and 3.**

The recommendation splits because the answer depends on a question the
research cannot decide for the user.

**Reject Design 2.** It saves only the queue mechanics, which is the same
narrow extraction the triage explored at break-even cost. It does not deliver
the user's stated framing (loops still conform to `SerialExecutor`
independently). If the goal is "share the queue," the triage's existing
recommendation against it stands. This research surfaces no new evidence to
overturn it.

**Reject Design 3.** Macros are the heaviest tool available, and the
ergonomics win is marginal at two consumers. The build-time cost of a macro
plugin target — adding SwiftSyntax to every transitive build that depends on
`swift-executors` — is disproportionate to the duplicated code being
eliminated. Macro-based scaffolding pays off when the consumer count climbs
into the dozens; for two same-author consumers, it is overengineered.

**Design 1 is the design that answers the user's framing.** It does so at
real but bounded cost:

- **Cost in `swift-executors`**: ~150 LOC for `Polling.Executor` + tests +
  docs, ~1 new namespace enum, 1 nested `Outcome` enum, 6 public methods.
  Net LOC delta across both packages: ~+90.
- **Cost in `swift-io`**: each Loop loses its `SerialExecutor + TaskExecutor`
  conformance and its ~55 LOC of executor-generic machinery. Each Loop adds
  a stored `Polling.Executor` and a `var unownedExecutor` forwarding accessor.
  Actor identity for `IO.Events.Actor` and `IO.Completions.Actor` migrates
  from the Loop to the held executor — observable in profilers and crash
  reports, not in user-visible API.
- **Cost in benchmarks**: tick-callback overhead is ~3–10 ns per iteration,
  dominated by syscall latency in any realistic workload. Should be confirmed
  with the existing io-bench suite before merge but is very unlikely to
  surface as a regression.

**Design 4 (status quo) remains principled** if the user's view is that:
- The duplication is mechanical, the two loops are co-owned, drift risk is
  low (per the triage).
- Future poll-based executors are not anticipated. The set "poll-based
  executors in this ecosystem" stays at 2.
- The public API cost in `swift-executors` is not justified by structural
  cleanliness alone — `swift-executors` should grow only when there is
  external demand for the abstraction.

The triage already weighed these and concluded Design 4. **This research
adds one observation that may shift the calculus**: the abstraction the
user is asking for is not the queue helper (Option C / Design 2) but the
**executor primitive itself** (Design 1). The triage rejected the queue
helper at break-even. Design 1 is a different shape — it saves more code
(structural conformance, not just queue mechanics) at higher API cost. The
trade-off is real and not a re-litigation of the triage's analysis.

The honest summary: if `swift-executors` is intended to grow into a real
executor toolkit (multiple executor variants, multiple consumers across
packages), Design 1 is a foundational addition that future executors will
want. If `swift-executors` is intended to stay narrow (a place for
`Kernel.Thread.Executor` and a few targeted variants, not a general-purpose
toolkit), Design 4 is principled. The user's answer to "what is
`swift-executors` for?" decides between them.

## Open Questions

1. **What is `swift-executors`'s mission?** The recommendation between
   Design 1 and Design 4 turns on whether `swift-executors` grows into a
   general toolkit (1) or stays a narrow home for the existing executor
   variants (4). Stated mission would let this research close to a single
   recommendation.

2. **Should the `body` closure in Design 1 be type-enforced to run on the
   executor's thread?** Today the contract is documented but not compile-time
   enforced. A `@isolated` parameter or a future `IsolatedTo<E>` marker could
   make it explicit. None exists today; the closure-based contract is the
   pragmatic choice. Worth revisiting if Swift gains the relevant primitive.

3. **Should `Polling.Executor` be `@Witness` rather than a class with stored
   closures?** `@Witness` is the ecosystem's preferred witness pattern, but
   `Polling.Executor` needs class identity for `SerialExecutor` conformance
   (`UnownedSerialExecutor(ordinary:)` requires a reference type). The class
   is structurally required; `@Witness` does not apply to the executor
   itself. The `body` and `wake` closures could be wrapped into a `@Witness
   Polling.Body` struct for stylistic consistency, but the wrapping adds a
   level of indirection without any compile-time gain. Recommend closures
   directly.

4. **Does Design 1 enable `Kernel.Thread.Executor.Sharded`-style sharding for
   poll-based executors?** A `Polling.Executor.Sharded` variant analogous to
   `Kernel.Thread.Executor.Sharded` would distribute work across N polling
   threads. Possible, but each shard would need its own poll source. Out of
   scope for this research; flagged as a natural follow-up if Design 1 lands.

5. **Should the wakeup channels (`IO.Event.Wakeup.Channel`,
   `IO.Completion.Wakeup.Channel`) consolidate?** The triage flagged this as
   open. Under Design 1, both loops pass `wakeup.wake` as the executor's
   `wake` closure. The two channel types are structurally similar but
   distinct (one is a plain `struct`, the other is `@Witness`). Design 1
   does not require their consolidation — the executor accepts any
   `@Sendable () -> Void`. But if Design 1 lands, the natural follow-up is
   to extract a shared `Kernel.Wakeup.Channel` primitive that both IO
   namespaces adopt.

## References

- `swift-io/Research/executor-conformance-triage.md` — prior triage that
  concluded Option D (keep duplication) under direct composition with
  `Kernel.Thread.Executor`.
- `swift-io/Research/executor-conformance-inventory.md` — inventory of all
  three SerialExecutor conformances in scope.
- `swift-foundations/swift-executors/Sources/Executors/Kernel.Thread.Executor.swift`
  — the existing condvar-blocking executor.
- `swift-foundations/swift-io/Sources/IO Events/IO.Event.Loop.swift` —
  IO.Event.Loop poll-blocking executor.
- `swift-foundations/swift-io/Sources/IO Completions/IO.Completion.Loop.swift`
  — IO.Completion.Loop poll-blocking executor.
- Swift Evolution: SE-0392 (Custom Actor Executors), SE-0417 (Task Executor
  Preference). Define `SerialExecutor` / `TaskExecutor` protocols.
  No infrastructure provided.
- Swift NIO: `Sources/NIOCore/EventLoop.swift`, `Sources/NIOPosix/Selector.swift`
  — the EventLoop / Selector / Registration pattern this research draws on.
- Tokio (Rust): runtime + driver composition pattern. Conceptual basis for
  the park/unpark / drive-poll separation discussed in Prior Art.
- OCaml Eio: backend-pluggable polling runtime; effect-based capabilities.
