# swift-executors Package Design — Research

<!--
---
version: 1.1.0
last_updated: 2026-04-15
status: DECISION
tier: 2
changelog:
  - 1.1.0 (2026-04-15): post-supervision amendments — 8 open questions resolved, V8 finding accepted, taxonomy refined (`Wait.EventSource` → `Wait.Event.Source`; `Wait.Primitive` is namespace-level, not a type). See **Decisions (Post-Supervision)**.
  - 1.0.0 (2026-04-15): initial validation pass.
---
-->

## Question

Validate the locked taxonomy for the swift-executors toolkit: one L1 primitives package (swift-executor-primitives) + seven named compositions in swift-executors. Is the taxonomy consistent, complete, and implementable without showstoppers?

## Mission (user-confirmed)

swift-executors is the ecosystem's complete, no-brainer, theoretical-perfect executors toolkit. Primitives compose. All seven named compositions ship in v1 regardless of current consumer demand. Completeness is the mission.

## Context

Prior research: `swift-io/Research/executor-conformance-triage.md` (Option-A race analysis — why `IO.Event.Loop` cannot safely conform to `SerialExecutor` by enqueueing to a held `Kernel.Thread.Executor`) and `swift-executors/Research/composable-executor-abstractions.md` (identified Design 1 = `Kernel.Thread.Executor.Polling` — a single-thread executor whose wait primitive is a kernel event source rather than a condvar).

Today swift-executors ships three public types under `Kernel.Thread.Executor.*`: the single-thread serial executor, the sharded round-robin pool, and the internal `Job.Queue`. `swift-io` holds two independent loops — `IO.Event.Loop` (kqueue/epoll) and `IO.Completion.Loop` (io_uring / future IOCP) — that each implement their own run loop plus a candidate `SerialExecutor` conformance whose direct-composition variant fails Swift's run-identity race model.

The locked plan: factor the three repeating pieces (job container, wait primitive, shutdown coordination) into a new L1 package; rebuild swift-executors on top; absorb the two IO loops as data-plane consumers of a new `Kernel.Thread.Executor.Polling` composition whose wait primitive is a kernel event source.

## Locked Taxonomy

**swift-executor-primitives (L1)** — new package. All types under `Executor.*` namespace.

```
Executor.Job.Queue              thread-safe FIFO of ExecutorJob/UnownedJob
Executor.Job.Deque              thread-safe double-ended (for work-stealing)
Executor.Job.Priority           deadline-ordered priority queue (for Scheduled)

Executor.Wait                   namespace (enum) — no own type; conceptual contract
Executor.Wait.Condvar           pthread_cond-based wait primitive
Executor.Wait.Event.Source      kernel-event-source-based wait primitive

Executor.Shutdown.Flag          atomic coordination primitive
```

**swift-executors (L3)** — seven named compositions, all ship in v1.

```
Executor.Cooperative                        borrowed caller thread (Tokio current_thread analog)
Executor.Main                               main-thread integration
Executor.Scheduled<Base>                    deadline-ordered wrapper over any Base

Kernel.Thread.Executor                      single owned thread, condvar wait, FIFO (EXISTS)
Kernel.Thread.Executor.Sharded              N owned threads, per-thread queues, round-robin (EXISTS)
Kernel.Thread.Executor.Stealing             N owned threads, per-thread deques, work-stealing (NEW)
Kernel.Thread.Executor.Polling              single owned thread, kernel-event-source wait (NEW, absorbs IO.Event.Loop + IO.Completion.Loop)
```

**Deferred**: `Executor.Global` — wait for the Swift Evolution global-executor SE to land.

> **Post-research note**: the original "locked taxonomy" listed `Executor.Wait.Primitive` as a protocol/witness type. V8 established this cannot be a Swift type (Condvar and Event.Source signatures are categorically divergent). `Executor.Wait` is a namespace only; the concrete sibling types (`.Condvar`, `.Event.Source`) satisfy the conceptual contract statically. See **Decisions (Post-Supervision)** below.

## Locked Naming Rules

1. **Single-type-no-namespace** — a namespace with only one type is a variant label, not a namespace. Nest under parent.
2. **Stealing** (not `WorkStealing`) — `.Stealing` alone is unambiguous in executor design.
3. **Scheduled is a variant** (`Executor.Scheduled<Base>`). Promote to `Scheduled.*` namespace only if associated types (`Trigger`, `Policy`, `Deadline`) emerge. Non-breaking promotion via typealias.
4. **Main is `Executor.Main`** (Option A): swift-threads depends on swift-executors so Main can't live there; swift-kernel-primitives lacks Main namespace; single-type rule blocks speculative namespace creation. Migration to `Kernel.Thread.Main.Executor` is non-breaking if swift-kernel-primitives later grows Main primitives.
5. **Apple's swift-platform-executors is a capability data point, not a naming guide**. Compound names, backend-first grouping, mixed axes — do not mirror.

---

## Primitives — swift-executor-primitives (L1)

### Executor.Job

**Namespace enum.** No own type; groups the three job-container variants below.

```swift
extension Executor {
    public enum Job { }
}
```

`Executor.Job.Queue`, `Executor.Job.Deque`, and `Executor.Job.Priority` live at the `Executor.Job.*` level. The stdlib's `UnownedJob` / `ExecutorJob` are the element type across all three; no new "Job" type is introduced — the existing stdlib types are reused.

### Executor.Job.Queue

**Thread-safe FIFO.** Deque-backed, O(1) enqueue + dequeue, unbounded growth. Replaces the current internal `Kernel.Thread.Executor.Job.Queue`; now public at L1.

**Consumers**: `Kernel.Thread.Executor` (FIFO), `Kernel.Thread.Executor.Sharded` (per-shard), `Kernel.Thread.Executor.Polling` (pending-job queue drained per iteration). Not used by `.Stealing` (uses Deque) or `.Scheduled` (uses Priority).

```swift
extension Executor.Job {
    /// Thread-safe unbounded FIFO of executor jobs.
    ///
    /// O(1) enqueue + dequeue. Caller supplies the lock / synchronization.
    /// This type is the storage primitive only — not itself locked.
    public struct Queue: ~Copyable {
        @usableFromInline
        internal var _storage: Deque<UnownedJob>

        public init() {
            self._storage = Deque()
            self._storage.reserve(try! .init(64))
        }
    }
}

extension Executor.Job.Queue {
    public var count: Index<UnownedJob>.Count { _storage.count }
    public var isEmpty: Bool { _storage.isEmpty }

    public mutating func enqueue(_ job: consuming UnownedJob) {
        _storage.push(job, to: .back)
    }

    public mutating func dequeue() -> UnownedJob? {
        _storage.take(from: .front)
    }

    /// Move every pending job into `other`, leaving `self` empty. O(1) via swap.
    /// Used by the batch-drain pattern in `Kernel.Thread.Executor.Polling`.
    public mutating func drain(into other: inout Executor.Job.Queue) {
        swap(&self._storage, &other._storage)
    }
}
```

**Justification**: three compositions need this exact shape. Making it L1 rather than internal to swift-executors (a) lets the Polling composition use the same container, (b) lets any downstream package reuse it without paying the L3 swift-executors dependency for a container, (c) passes the [MOD-DOMAIN] test: a thread-safe job FIFO is a coherent semantic domain, not "shared code for convenience."

### Executor.Job.Deque

**Thread-safe double-ended queue.** Used exclusively by work-stealing executors: owner pushes/pops on one end (LIFO for cache locality), stealers take from the other end (FIFO for fairness). Each thread owns its own Deque; stealing is cross-Deque.

**Consumers**: `Kernel.Thread.Executor.Stealing` only.

```swift
extension Executor.Job {
    /// Thread-safe double-ended queue for work-stealing executors.
    ///
    /// Push / pop on the owner end (back); steal from the thief end (front).
    /// Caller supplies synchronization between owner and thieves.
    public struct Deque: ~Copyable {
        @usableFromInline
        internal var _storage: Queue_DoubleEnded_Primitives.Deque<UnownedJob>

        public init() {
            self._storage = .init()
            self._storage.reserve(try! .init(256))
        }
    }
}

extension Executor.Job.Deque {
    public var count: Index<UnownedJob>.Count { _storage.count }
    public var isEmpty: Bool { _storage.isEmpty }

    /// Owner-side: LIFO for cache locality.
    public mutating func push(_ job: consuming UnownedJob) { _storage.push(job, to: .back) }
    public mutating func pop() -> UnownedJob? { _storage.take(from: .back) }

    /// Thief-side: FIFO from the opposite end to reduce contention with owner.
    public mutating func steal() -> UnownedJob? { _storage.take(from: .front) }
}
```

**Justification**: Chase-Lev work-stealing deques are a well-studied primitive; factoring this into L1 gives future packages (e.g., a hypothetical `swift-fork-join`) access to the same container. Consumer list is one today, but [MOD-DOMAIN] allows L1 existence based on domain completeness, not consumer count — see feedback_domain_completeness_not_consumers.md.

### Executor.Job.Priority

**Deadline-ordered priority queue.** Min-heap keyed by absolute deadline (`ContinuousClock.Instant`). Used by `Executor.Scheduled<Base>` to order jobs by wake time.

**Consumers**: `Executor.Scheduled<Base>` only.

```swift
extension Executor.Job {
    /// Deadline-ordered priority queue of executor jobs.
    ///
    /// Min-heap keyed by absolute deadline. `peek` returns the next-to-fire
    /// deadline without removing; `popReady` removes all jobs whose deadline
    /// is ≤ `now`.
    public struct Priority: ~Copyable {
        public struct Entry: ~Copyable {
            public let job: UnownedJob
            public let deadline: ContinuousClock.Instant
        }
        @usableFromInline
        internal var _storage: Heap_Min_Primitives.Heap<Entry>
        // Entry compared by deadline — requires Comparable conformance in the
        // adjacent +Comparable file.

        public init() { self._storage = .init() }
    }
}

extension Executor.Job.Priority {
    public var count: Index<Entry>.Count { _storage.count }
    public var isEmpty: Bool { _storage.isEmpty }

    public mutating func schedule(_ job: consuming UnownedJob, at deadline: ContinuousClock.Instant) {
        _storage.insert(Entry(job: job, deadline: deadline))
    }

    /// Earliest deadline without removal. `nil` if empty.
    public func peek() -> ContinuousClock.Instant? { _storage.min?.deadline }

    /// Pop the head if its deadline has elapsed; otherwise `nil`.
    public mutating func popReady(now: ContinuousClock.Instant) -> UnownedJob? {
        guard let head = _storage.min, head.deadline <= now else { return nil }
        return _storage.removeMin()!.job
    }
}
```

**Justification**: Scheduled executors need deadline-ordered dispatch. The min-heap backing is universal across every scheduling executor I've surveyed (NIO's `ScheduledTask`, Tokio's `Wheel`, Java's `ScheduledThreadPoolExecutor.DelayedWorkQueue`). L1 placement means `swift-scheduled-tasks` or similar future packages share the same container.

### Executor.Wait

**Namespace enum.** Groups the wait-primitive protocol and its implementations.

```swift
extension Executor {
    public enum Wait { }
}
```

### Executor.Wait.Primitive

**The polymorphism axis** between condvar-blocking and poll-blocking executors. See "Wait.Primitive Mechanism" section for the justified choice (witness struct, per [IMPL-COMPILE]).

**Consumers**: every owned-thread composition — `Kernel.Thread.Executor` (Condvar), `Kernel.Thread.Executor.Sharded` (Condvar per shard), `Kernel.Thread.Executor.Stealing` (Condvar per worker), `Kernel.Thread.Executor.Polling` (EventSource).

### Executor.Wait.Condvar

**pthread_cond wait primitive.** Binds an `Executor.Wait.Primitive` witness around `Kernel.Thread.Synchronization<1>`. The lock the condvar rides on is the same lock that guards the job queue, so `wait()` atomically releases and re-acquires it.

**Consumers**: `Kernel.Thread.Executor`, `Kernel.Thread.Executor.Sharded`, `Kernel.Thread.Executor.Stealing`.

```swift
extension Executor.Wait {
    /// Wait primitive backed by pthread_cond_wait.
    ///
    /// The lock IS the queue-protecting lock. `wait` releases it atomically;
    /// `wake` signals; `shutdown` broadcasts (to unblock a closing executor).
    public struct Condvar: Sendable {
        @usableFromInline
        internal let sync: Kernel.Thread.Synchronization<1>
        public init() { self.sync = .init() }
    }
}

extension Executor.Wait.Condvar {
    /// Access the underlying lock so the queue drain can run under it.
    public func withLock<R, E: Swift.Error>(
        _ body: () throws(E) -> R
    ) throws(E) -> R { try sync.withLock(body) }

    /// Wait. Caller must already hold the lock (via withLock); wait releases
    /// it atomically and re-acquires on return.
    public func wait() { sync.wait() }

    /// Wake a single waiter. Thread-safe; does not require holding the lock.
    public func wake() { sync.signal() }

    /// Wake every waiter. Used on shutdown to force all workers to re-check
    /// the shutdown flag.
    public func wakeAll() { sync.broadcast() }
}
```

### Executor.Wait.EventSource

**Kernel-event-source wait primitive.** Binds an `Executor.Wait.Primitive` witness around `Kernel.Event.Source` (kqueue / epoll / io_uring / IOCP). Wait = `source.poll(deadline:into:)`. Wake = `source.wakeup.wake()`. No lock is held across the wait.

**Consumers**: `Kernel.Thread.Executor.Polling` — which in turn is held by `swift-io`'s `IO.Event.Loop` and `IO.Completion.Loop` (after migration).

```swift
extension Executor.Wait {
    /// Wait primitive backed by a kernel event source.
    ///
    /// Holds the `~Copyable` source; exposes `wakeup` (Sendable) for cross-
    /// thread wake. `wait` polls the source with no lock held. Consumers are
    /// expected to handle the returned events (this type is transport, not
    /// dispatch — dispatch happens in the executor's tick body).
    public struct EventSource: ~Copyable {
        @usableFromInline
        internal var _source: Kernel.Event.Source?
        public let wakeup: Kernel.Wakeup.Channel

        public init(source: consuming Kernel.Event.Source) {
            self.wakeup = source.wakeup
            self._source = consume source
        }

        deinit {
            if let s = _source.take() { s.close() }
        }
    }
}

extension Executor.Wait.EventSource {
    /// Block until an event arrives or wakeup fires. Returns the number of
    /// events written into `buffer`.
    public mutating func wait(
        deadline: Kernel.Time.Deadline?,
        into buffer: inout [Kernel.Event]
    ) throws(Kernel.Event.Driver.Error) -> Int {
        try _source!.poll(deadline: deadline, into: &buffer)
    }

    public mutating func withSource<R>(
        _ body: (inout Kernel.Event.Source) -> R
    ) -> R { body(&_source!) }
}
```

**Shape note**: `Condvar`'s `wait()` takes no parameter and returns void; `EventSource`'s `wait(deadline:into:)` takes a deadline and an output buffer and returns an event count. These do NOT share a protocol signature. This is the crux of the polymorphism decision — see "Wait.Primitive Mechanism" below. The decision: no common protocol. The two types coexist under the `Executor.Wait` namespace as *sibling variants*, not protocol conformers. The term `Executor.Wait.Primitive` in the locked taxonomy is thus a *documentation name* for the conceptual contract, not a Swift protocol. Compositions that pick a wait primitive pick one concrete variant by storage type, not via polymorphism.

### Executor.Shutdown

**Namespace enum.** Groups the shutdown-coordination primitives. Currently one type.

```swift
extension Executor {
    public enum Shutdown { }
}
```

Per locked rule #1 (single-type-no-namespace), a one-type namespace is a variant label. `Executor.Shutdown.Flag` is kept as-is because it is designed to grow: a future `Executor.Shutdown.Latch` (cooperating-shutdown barrier for pools) and `Executor.Shutdown.Timeout` (timed-shutdown helper) are anticipated. The namespace is a deliberate forward investment — documented — rather than speculative premature nesting.

### Executor.Shutdown.Flag

**Atomic coordination primitive.** Cross-thread flag for "should the run loop exit?" semantics. Distinct from `Mutex<Bool>` because the flag is checked on the hot path (every iteration / every enqueue) — an Atomic load is 1-3ns, a Mutex acquire is 30-100ns.

**Consumers**: every composed executor — `Kernel.Thread.Executor` (shutdown check inside locked wait), `Kernel.Thread.Executor.Sharded` (per-shard), `Kernel.Thread.Executor.Stealing` (global halt signal), `Kernel.Thread.Executor.Polling` (halt between poll cycles), `Executor.Cooperative` (run-until-halt), `Executor.Main` (run-until-halt).

```swift
extension Executor.Shutdown {
    /// Atomic boolean coordinating run-loop shutdown.
    ///
    /// Relaxed load on the hot path (run-loop predicate check), release
    /// store on shutdown (publishes any preceding writes to the observing
    /// run-loop thread).
    public struct Flag: Sendable {
        @usableFromInline
        internal let _atomic: Atomic<Bool>
        public init() { self._atomic = .init(false) }
    }
}

extension Executor.Shutdown.Flag {
    public var isSet: Bool { _atomic.load(ordering: .relaxed) }
    public func set() { _atomic.store(true, ordering: .releasing) }
}
```

**Justification**: every composed executor needs this exact shape. A bare `Atomic<Bool>` would work; wrapping it gives (a) a name that reads as intent (`shutdown.isSet` vs `atomic.load(ordering: .relaxed)`), (b) enforces the ordering conventions at one site rather than seven, (c) a natural extension point for `Latch`/`Timeout` siblings.

---

## Composed Executors — swift-executors (L3)

### Executor.Cooperative

**Borrowed-caller-thread serial executor.** Runs on the caller's thread — no OS thread is spawned. Caller drives the run loop explicitly via `run()` or `runUntil(deadline:)`. Closest analog: Tokio's `current_thread` runtime, NIO's `MultiThreadedEventLoopGroup` with one thread in a foreground test harness, Rust `futures::executor::LocalPool`.

**Primitives composed**: `Executor.Job.Queue`, `Executor.Shutdown.Flag`, `Executor.Wait.Condvar` (for blocking `run()` mode when the queue is empty but shutdown not yet signalled).

**Conformances**: `SerialExecutor`.

**Why a consumer would pick it**: single-threaded testing / deterministic execution; embedding in a host run-loop (e.g., under a main() that manages its own thread); scenarios where you cannot spawn threads (Embedded Swift, some sandboxes).

```swift
extension Executor {
    /// Runs on the caller's thread; no OS thread spawned.
    public final class Cooperative: SerialExecutor, @unchecked Sendable {
        @usableFromInline internal var jobs: Executor.Job.Queue
        @usableFromInline internal let wait: Executor.Wait.Condvar
        @usableFromInline internal let shutdown: Executor.Shutdown.Flag
        public init() {
            self.jobs = .init()
            self.wait = .init()
            self.shutdown = .init()
        }
    }
}

extension Executor.Cooperative {
    public func enqueue(_ job: consuming ExecutorJob) {
        wait.withLock { jobs.enqueue(UnownedJob(job)) }
        wait.wake()
    }
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }

    /// Drive the run loop on the caller's thread. Returns when `shutdown.set()`.
    public func run() {
        while !shutdown.isSet {
            let job: UnownedJob? = wait.withLock {
                while jobs.isEmpty && !shutdown.isSet { wait.wait() }
                return jobs.dequeue()
            }
            guard let job else { return }
            unsafe job.runSynchronously(on: asUnownedSerialExecutor())
        }
    }
    public func shutdownNow() { shutdown.set(); wait.wakeAll() }
}
```

### Executor.Main

**Main-thread integration.** On Darwin, integrates with CFRunLoop / the main dispatch queue so that actor jobs pinned to Main run on the main thread. On Linux/Windows v1 — see Open Question below — a custom condvar-based pumping primitive on the main thread (no OS-level main-run-loop to integrate with), equivalent in semantics but not in platform idiom.

**Primitives composed**: `Executor.Job.Queue`, `Executor.Shutdown.Flag`, `Executor.Wait.Condvar` (Linux/Windows) OR a platform-specific bridge (Darwin).

**Conformances**: `SerialExecutor`. Represents `MainActor`'s executor at the `swift-executors` layer; the actual MainActor binding happens higher up (stdlib).

**Why a consumer would pick it**: UI integration (AppKit/UIKit on Darwin); legacy main-thread APIs; testing that something runs on the main thread.

**Showstopper flag**: see "Open Questions". Linux/Windows Main executor has no natural platform mechanism — the locked taxonomy implies v1 ships all seven; this may need either Linux to use a custom implementation that is not really "Main" in the platform sense, or for `Executor.Main` to be Darwin-only in v1 with a compile-time `#if os(Darwin)` gate on its availability.

```swift
extension Executor {
    /// Main-thread serial executor. Platform-specific.
    public final class Main: SerialExecutor, @unchecked Sendable {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        // Darwin: delegates to main dispatch queue.
        @usableFromInline internal let queue: DispatchQueue = .main
        #else
        // Linux/Windows: condvar-based main pump.
        @usableFromInline internal var jobs: Executor.Job.Queue
        @usableFromInline internal let wait: Executor.Wait.Condvar
        @usableFromInline internal let shutdown: Executor.Shutdown.Flag
        #endif
        public static let shared: Main = .init()
        private init() { /* ... platform setup ... */ }
    }
}

extension Executor.Main {
    public func enqueue(_ job: consuming ExecutorJob) { /* platform-specific */ }
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
    /// Linux/Windows only: caller must drive the main pump.
    public func runMainLoop() { /* sync.wait loop like Cooperative.run */ }
}
```

### Executor.Scheduled<Base>

**Deadline-ordered wrapper over any `Base` executor.** `Scheduled` owns an `Executor.Job.Priority` plus a timer thread that blocks on the priority queue's head deadline; when the head fires, the job is moved onto the `Base` executor via `Base.enqueue`. Delegation model, not conformance composition. Naming per locked rule #3 — promotes to `Scheduled.*` namespace (with associated `Trigger`/`Policy` types) if those axes grow.

**Primitives composed**: `Executor.Job.Priority`, `Executor.Shutdown.Flag`, `Executor.Wait.Condvar` (for the timer-thread deadline wait — pthread_cond supports timed wait).

**Conformances**: `SerialExecutor` + `TaskExecutor` (delegated to `Base`) + `SchedulableExecutor` (the whole point). `Base` conforms to at least `SerialExecutor` or `TaskExecutor`.

**Why a consumer would pick it**: actor executors that need Task.sleep ordering; scheduler support for `enqueue(_:after:tolerance:clock:)` on a base executor that only provides `enqueue`.

```swift
extension Executor {
    /// Adds deadline-scheduled enqueue to any underlying executor.
    public final class Scheduled<Base: SerialExecutor & Sendable>: SerialExecutor, SchedulableExecutor, @unchecked Sendable {
        @usableFromInline internal let base: Base
        @usableFromInline internal var priority: Executor.Job.Priority
        @usableFromInline internal let wait: Executor.Wait.Condvar
        @usableFromInline internal let shutdown: Executor.Shutdown.Flag
        @usableFromInline internal var timerThread: Kernel.Thread.Handle?
        public init(base: Base) {
            self.base = base
            self.priority = .init()
            self.wait = .init()
            self.shutdown = .init()
            self.timerThread = unsafe Kernel.Thread.trap(Ownership.Transfer.Retained(self)) { r in
                r.take().runTimerLoop()
            }
        }
    }
}

extension Executor.Scheduled {
    public func enqueue(_ job: consuming ExecutorJob) { base.enqueue(consume job) }
    public func enqueue(
        _ job: consuming ExecutorJob,
        after delay: Duration,
        tolerance: Duration?,
        clock: some Clock
    ) {
        let deadline = ContinuousClock.now.advanced(by: delay)
        wait.withLock {
            priority.schedule(UnownedJob(consume job), at: deadline)
        }
        wait.wake()
    }
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        base.asUnownedSerialExecutor()
    }
    private func runTimerLoop() {
        while !shutdown.isSet {
            wait.withLock {
                while !shutdown.isSet {
                    guard let head = priority.peek() else {
                        wait.wait(); continue
                    }
                    let now = ContinuousClock.now
                    if head <= now {
                        if let job = priority.popReady(now: now) {
                            base.enqueue(UnownedJob(job) /* consuming */)
                        }
                    } else {
                        _ = wait.wait(timeout: now.duration(to: head))
                    }
                }
            }
        }
    }
}
```

### Kernel.Thread.Executor (existing)

**Single-thread serial executor.** Today: pthread + condvar wait + FIFO queue + one-step shutdown.

**Refactoring required**: small. The public surface is unchanged. Internally: `sync: Kernel.Thread.Synchronization<1>` + `jobs: Job.Queue` + `isRunning: Bool` become `wait: Executor.Wait.Condvar` + `jobs: Executor.Job.Queue` + `shutdown: Executor.Shutdown.Flag`. The run loop body is identical in structure. The `.serial` / `.task` mode toggle stays. See V3 for the exact before/after.

**Conformances**: `SerialExecutor`, `TaskExecutor` — unchanged.

**Why a consumer would pick it**: one actor, one owned OS thread, serial execution order. Simple actor pinning; no kernel event integration needed.

### Kernel.Thread.Executor.Sharded (existing)

**N-owned-threads with round-robin dispatch.** Today: `[Kernel.Thread.Executor]` + `Atomic<UInt64>` counter.

**Refactoring required**: negligible. Internally reuses `Kernel.Thread.Executor` (now rebuilt on new primitives). The counter can optionally move to `Executor.Shutdown.Flag`-adjacent primitives (no — keep it local; it's an ordinary counter, not a shutdown primitive).

**Conformances**: none at the pool level — `next()` returns a `Kernel.Thread.Executor`, which is the conforming type.

**Why a consumer would pick it**: serial-per-shard parallelism (actor-per-shard models); bounded thread count with round-robin fairness.

### Kernel.Thread.Executor.Stealing (new)

**N-owned-threads with per-thread deques and work-stealing.** Each worker owns its `Executor.Job.Deque`; workers steal from each other when their own deque is empty. Unlike `Sharded`, jobs are not pinned to a specific thread — any worker can run any job — so only `TaskExecutor` conformance is appropriate, not `SerialExecutor` (stealing violates serial execution order per-identity).

**Primitives composed**: `Executor.Job.Deque` (per worker), `Executor.Shutdown.Flag`, `Executor.Wait.Condvar` (per worker — wait when every deque is empty).

**Conformances**: `TaskExecutor` only. NOT a `SerialExecutor`. Jobs can run on any worker — not serial per identity.

**Why a consumer would pick it**: parallel Task dispatch with load balancing (CPU-bound workloads where some tasks are much longer than others); as the `.globalConcurrentExecutor` in a custom runtime.

```swift
extension Kernel.Thread.Executor {
    /// N-owned-threads with per-thread deques and work-stealing.
    public final class Stealing: TaskExecutor, @unchecked Sendable {
        public struct Options: Sendable {
            public var count: Kernel.Thread.Count
            public init(count: Kernel.Thread.Count = .systemDefault) { self.count = count }
        }
        @usableFromInline internal let workers: [Worker]
        @usableFromInline internal let shutdown: Executor.Shutdown.Flag
        @usableFromInline internal let nextVictim: Atomic<UInt64>

        public init(_ options: Options = .init()) {
            self.shutdown = .init()
            self.nextVictim = .init(0)
            self.workers = (0..<Int(options.count)).map { i in Worker(id: i) }
            for w in workers { w.start(pool: self) }
        }
    }
}

extension Kernel.Thread.Executor.Stealing {
    public func enqueue(_ job: consuming ExecutorJob) {
        // Pick a worker (current-thread's worker if we're on one, else round-robin)
        let worker = currentWorker() ?? workers[Int(nextVictim.wrappingAdd(1, ordering: .relaxed).oldValue) % workers.count]
        worker.push(UnownedJob(consume job))
    }
    public func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        unsafe UnownedTaskExecutor(ordinary: self)
    }
    public func shutdown() { shutdown.set(); for w in workers { w.wake() }; for w in workers { w.join() } }
}

extension Kernel.Thread.Executor.Stealing {
    @usableFromInline internal final class Worker: @unchecked Sendable {
        @usableFromInline internal var deque: Executor.Job.Deque
        @usableFromInline internal let wait: Executor.Wait.Condvar
        @usableFromInline internal var handle: Kernel.Thread.Handle?
        // workerRunLoop: pop own; steal from victim; wait when all empty.
    }
}
```

### Kernel.Thread.Executor.Polling (new — absorbs IO.Event.Loop + IO.Completion.Loop)

**Single-owned-thread serial executor whose wait primitive is a kernel event source.** One OS thread, one job queue, one `Executor.Wait.EventSource`. The run loop interleaves drain-jobs with poll-events; events are dispatched by a consumer-supplied tick body. Absorbs `IO.Event.Loop` and `IO.Completion.Loop` as data-plane consumers.

**Primitives composed**: `Executor.Job.Queue`, `Executor.Shutdown.Flag`, `Executor.Wait.EventSource`.

**Conformances**: `SerialExecutor`, `TaskExecutor`.

**Why a consumer would pick it**: reactor or proactor I/O (kqueue, epoll, io_uring, IOCP); integration of actor job dispatch with kernel event polling on the same thread.

**Race-safety**: the consumer's tick body executes on the executor's own thread (the same thread that dispatches actor jobs), so domain state — `registrations`, `entries`, the source — is touched by a single thread. See V5.

```swift
extension Kernel.Thread.Executor {
    /// Single-thread executor whose wait primitive is a kernel event source.
    public final class Polling: SerialExecutor, TaskExecutor, @unchecked Sendable {
        public enum Outcome: Sendable { case `continue`, halt }
        @usableFromInline internal var jobs: Executor.Job.Queue
        @usableFromInline internal var drainBuffer: Executor.Job.Queue
        @usableFromInline internal let queueLock: Kernel.Thread.Mutex
        @usableFromInline internal var waitSource: Executor.Wait.EventSource
        @usableFromInline internal let shutdown: Executor.Shutdown.Flag
        @usableFromInline internal var threadHandle: Kernel.Thread.Handle?
        @usableFromInline internal let tick: @Sendable () -> Outcome

        public init(
            source: consuming Kernel.Event.Source,
            tick: @escaping @Sendable () -> Outcome
        ) {
            self.jobs = .init(); self.drainBuffer = .init()
            self.queueLock = .init()
            self.waitSource = .init(source: consume source)
            self.shutdown = .init()
            self.tick = tick
            self.threadHandle = unsafe Kernel.Thread.trap(Ownership.Transfer.Retained(self)) { r in
                r.take().runLoop()
            }
        }
    }
}

extension Kernel.Thread.Executor.Polling {
    public func enqueue(_ job: consuming ExecutorJob) { enqueue(UnownedJob(consume job)) }
    public func enqueue(_ job: UnownedJob) {
        let runInline: Bool = queueLock.withLock {
            guard !shutdown.isSet else { return true }
            jobs.enqueue(job); return false
        }
        if runInline { unsafe job.runSynchronously(on: asUnownedSerialExecutor()) }
        else { waitSource.wakeup.wake() }
    }
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
    public func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        unsafe UnownedTaskExecutor(ordinary: self)
    }
    public func withSource<R>(_ body: (inout Kernel.Event.Source) -> R) -> R {
        waitSource.withSource(body)
    }
    public func shutdownNow() {
        shutdown.set()
        waitSource.wakeup.wake()
        threadHandle.take()?.join()
    }
    private func runLoop() {
        while !shutdown.isSet {
            drainJobs()
            if shutdown.isSet { break }
            if case .halt = tick() { shutdown.set(); break }
        }
        drainJobs()
    }
    private func drainJobs() {
        while true {
            queueLock.withLock { jobs.drain(into: &drainBuffer) }
            guard !drainBuffer.isEmpty else { return }
            while let j = drainBuffer.dequeue() {
                unsafe j.runSynchronously(on: asUnownedSerialExecutor())
            }
        }
    }
}
```

The `tick` body is the consumer's poll-and-dispatch logic. For `IO.Event.Loop`, it becomes `source.poll → dispatchEvents`. For `IO.Completion.Loop`, `checkCancellations → flush → poll → dispatchCQEs`. See V1/V2.

---

## Wait.Primitive Mechanism

**Decision**: two independent sibling types under `Executor.Wait` — `Condvar` and `EventSource` — sharing the namespace but **NOT a Swift protocol**. Compositions pick one concrete type by construction; there is no dynamic or generic dispatch between them.

**Four candidates considered**:

| Mechanism | Compile-time dispatch | Inlinable | Zero alloc | Property.View fit | Verdict |
|-----------|-----------------------|-----------|-----------|-------------------|---------|
| **Protocol** (`protocol Wait.Primitive { func wait(); func wake() }`) | No (existential) | No | Boxing | N/A | Rejected — see below |
| **Generic** (`Executor.Polling<W: Wait.Primitive>`) | Yes (monomorphized) | Yes | Yes | N/A | Rejected — see below |
| **@Witness struct** | Yes | Yes | Yes if witness is `consuming` | Natural | Rejected — see below |
| **Sibling variants (no polymorphism)** | Yes (static dispatch on concrete type) | Yes | Yes | N/A | **Chosen** |

**Why no protocol**: the two implementations' `wait` signatures don't match. `Condvar.wait()` takes no arguments, returns nothing, and requires the caller to hold the lock. `EventSource.wait(deadline:into:)` takes a deadline and an output buffer, returns an event count, throws `Kernel.Event.Driver.Error`, and requires the caller NOT to hold any lock. There is no minimal protocol contract they both satisfy without either lying by omission or erasing the useful signature information. [IMPL-COMPILE] prefers the type system to express invariants — here the invariants diverge, so the types should diverge.

**Why no generic parameter**: a `Kernel.Thread.Executor.Polling<W: Wait.Primitive>` would require a protocol to be the `W`'s constraint, and we just eliminated that. Even if we invented a protocol, it would have two conformers today and no third conformer in prospect — per [PATTERN-013] "Protocols MUST NOT be designed before having 3+ concrete conformers." A protocol here would be speculative.

**Why no @Witness struct**: `@Witness` is the right pattern for one protocol shape across multiple platform backends (e.g., `IO.Completion.Driver` across io_uring/IOCP). It is not the right pattern when the "protocol" does not exist. Per feedback_language_features_over_custom_types.md: "Use borrowing/consuming/~Copyable for ownership fixes; never invent shadow types." The compositions that use Condvar know they use Condvar; the one composition that uses EventSource knows it uses EventSource. Inventing a witness to paper over a non-existent shared contract adds indirection without adding compile-time enforcement.

**Why sibling variants**: each composition lists its concrete wait-primitive type as a stored property. `Kernel.Thread.Executor` stores `wait: Executor.Wait.Condvar`. `Kernel.Thread.Executor.Polling` stores `waitSource: Executor.Wait.EventSource`. Calls to `wait.wait()` and `waitSource.wait(deadline:into:)` are statically dispatched to the concrete type's methods. The compiler inlines them (both types are `@usableFromInline` structs with trivial bodies). Zero allocation. No type erasure.

**Implication for the locked taxonomy**: the taxonomy lists `Executor.Wait.Primitive` as if it were a type. It is not. It is a documentation name for the conceptual "wait primitive contract." The L1 package exposes `Executor.Wait.Condvar` and `Executor.Wait.EventSource` as concrete sibling types; `Executor.Wait` is a namespace enum; there is no `Executor.Wait.Primitive` type. I recommend the locked taxonomy be updated accordingly — see Open Questions.

**Consequence for v1**: every composition specifies its wait-primitive type directly. If a future fifth wait-primitive emerges (e.g., signalfd-fused condvar on Linux), it becomes a new sibling `Executor.Wait.*` type — no migration required in existing types.

---

## Validation

### V1: IO.Event.Loop rewrite (≤50 LOC of domain-specific code)

After migration, `IO.Event.Loop` becomes a data-plane wrapper around `Kernel.Thread.Executor.Polling`. The Loop no longer conforms to `SerialExecutor` itself; it forwards `unownedExecutor` to its held executor. Entire file drops from ~340 LOC (incl. docs) to ~90 LOC; the domain-specific tick body is ~40 LOC.

```swift
extension IO.Event {
    public final class Loop: @unchecked Sendable {
        @usableFromInline internal var executor: Kernel.Thread.Executor.Polling!
        @usableFromInline internal var registrations: [IO.Event.ID: Registration] = [:]
        @usableFromInline internal var shouldHalt: Bool = false
        @usableFromInline internal static let maxEvents = 256

        public init(source: consuming Kernel.Event.Source) {
            self.executor = nil
            self.executor = Kernel.Thread.Executor.Polling(source: consume source) { [weak self] in
                self?.tick() ?? .halt
            }
        }
        public var unownedExecutor: UnownedSerialExecutor {
            executor.asUnownedSerialExecutor()
        }
        private func tick() -> Kernel.Thread.Executor.Polling.Outcome {
            if shouldHalt { return .halt }
            var buffer: [Kernel.Event] = .init(repeating: .empty, count: Self.maxEvents)
            do throws(Kernel.Event.Driver.Error) {
                let n = try executor.withSource { try $0.poll(deadline: nil, into: &buffer) }
                if n > 0 { dispatchEvents(buffer: &buffer, count: n) }
                return .continue
            } catch {
                let ioErr = IO.Event.Error(error)
                switch ioErr {
                case .platform(let c) where c == .POSIX.EINTR,
                     .platform(let c) where c == .POSIX.ENOMEM,
                     .platform(let c) where Kernel.Error.Code.POSIX.isEAGAIN(c):
                    if case .platform(let c) = ioErr, c == .POSIX.ENOMEM { Kernel.Thread.yield() }
                    return .continue
                default:
                    closeAll(error: ioErr); return .halt
                }
            }
        }
        private func dispatchEvents(buffer: inout [Kernel.Event], count: Int) { /* unchanged */ }
        private func closeAll(error: IO.Event.Error) { /* unchanged */ }
    }
}
```

Domain LOC: ~40. Executor-generic machinery (queue, lock, drain, thread spawn, shutdown join, enqueue, asUnownedSerialExecutor, isRunning checks) — ~140 LOC of deletion from today's Loop. Passes the ≤50 LOC budget.

### V2: IO.Completion.Loop rewrite

Same structure as V1. Loop holds a `Kernel.Thread.Executor.Polling` over a `Kernel.Event.Source` adapted from the `IO.Completion.Driver`. Today's `~360 LOC` file compresses to ~110 LOC; domain-specific tick is ~50 LOC (one more phase than Event.Loop: `checkCancellations` and `flush`).

```swift
extension IO.Completion {
    public final class Loop: @unchecked Sendable {
        @usableFromInline internal var executor: Kernel.Thread.Executor.Polling!
        @usableFromInline internal let driver: IO.Completion.Driver
        @usableFromInline internal var handle: IO.Completion.Driver.Handle?
        @usableFromInline internal var entries: [IO.Completion.ID: IO.Completion.Entry] = [:]
        @usableFromInline internal var eventBuffer: [IO.Completion.Event] = []
        @usableFromInline internal var shouldHalt: Bool = false

        public init(driver: IO.Completion.Driver) throws(IO.Completion.Error) {
            self.driver = driver
            let handle = try driver.create()
            let source = try driver.asEventSource(handle)   // adapter to Kernel.Event.Source
            self.handle = consume handle
            self.executor = nil
            self.executor = Kernel.Thread.Executor.Polling(source: consume source) { [weak self] in
                self?.tick() ?? .halt
            }
        }
        public var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }
        private func tick() -> Kernel.Thread.Executor.Polling.Outcome {
            if shouldHalt { return .halt }
            checkCancellations()
            do throws(IO.Completion.Error) { _ = try driver.flush(handle!) } catch { /* retry */ }
            do throws(IO.Completion.Error) {
                _ = try driver.poll(handle!, deadline: nil, into: &eventBuffer)
                eventBuffer.drain { event in
                    if let entry = entries.remove(event.id) { entry.resolve(with: event) }
                }
            } catch { /* retry */ }
            return .continue
        }
        private func checkCancellations() { /* unchanged */ }
        // deinit: handle consumed by driver.close
    }
}
```

Domain LOC: ~50. Total file ~110 LOC. Budget met. The adapter `driver.asEventSource(handle)` is a new method on `IO.Completion.Driver` that returns a `Kernel.Event.Source` whose poll calls `driver.poll(handle, ...)`; this is non-trivial on io_uring (because io_uring's FD is itself pollable via `epoll_wait` on Linux) but known-feasible — the existing `IO.Completion.Wakeup.Channel` already proves kernel-level wake semantics transfer.

**Caveat**: on IOCP (Windows), there is no `Kernel.Event.Source`-shaped adapter because IOCP does not expose itself as a pollable FD. On IOCP, the `Polling.Executor` would need a generalization to accept *any* `wait` function, not just `Kernel.Event.Source`. See Open Questions.

### V3: Kernel.Thread.Executor fit

**Verdict**: small refactor. Public surface unchanged. Internal fields re-typed.

**Before** (today):
```swift
private let sync: Kernel.Thread.Synchronization<1>
private var jobs: Job.Queue
private var isRunning: Bool = true
private var threadHandle: Kernel.Thread.Handle?
```

**After**:
```swift
private let wait: Executor.Wait.Condvar
private var jobs: Executor.Job.Queue
private let shutdown: Executor.Shutdown.Flag
private var threadHandle: Kernel.Thread.Handle?
```

Run loop body, before:
```swift
let job: UnownedJob? = sync.withLock {
    while jobs.isEmpty && isRunning { sync.wait() }
    guard isRunning || !jobs.isEmpty else { return nil }
    return jobs.dequeue()
}
```

After:
```swift
let job: UnownedJob? = wait.withLock {
    while jobs.isEmpty && !shutdown.isSet { wait.wait() }
    guard !shutdown.isSet || !jobs.isEmpty else { return nil }
    return jobs.dequeue()
}
```

Identical structure. `isRunning` → `shutdown.isSet` (semantic inversion). `sync.wait()` → `wait.wait()`. `sync.withLock` → `wait.withLock`. The internal `Job.Queue` type (currently a nested private struct) moves out and is replaced by the public L1 `Executor.Job.Queue`. Zero public API change. Binary compat: the class's memory layout changes, so any `@_fixed_layout` consumers would break — there are none.

### V4: Hypothetical third consumer (Windows IOCP loop)

**Claim**: the 7-composition framing accommodates a hypothetical `Windows.IO.Completion.Loop` that dispatches via IOCP.

**Slot**: the Windows IOCP loop becomes another consumer of `Kernel.Thread.Executor.Polling`, with two adjustments:

1. **Adapter**: IOCP is not a file descriptor; it is a completion port handle. The `Polling.Executor`'s `Executor.Wait.EventSource` is kqueue/epoll-shaped. For IOCP, we need an `Executor.Wait.*` variant — call it `Executor.Wait.CompletionPort` — that wraps the IOCP handle and whose `wait` calls `GetQueuedCompletionStatusEx`. This is a new sibling under `Executor.Wait`, paralleling the `EventSource` type.

2. **Executor variant**: either `Polling` becomes generic over its wait-primitive type (re-opening the polymorphism question — tempting but rejected above), OR a new composition `Kernel.Thread.Executor.Polling.CompletionPort` is added. The preferred answer: add a new L3 composition type, not a generic parameter. Net: 8 named compositions instead of 7 when Windows lands.

**Alternative**: make `Kernel.Thread.Executor.Polling` a generic `Polling<W: Wait.*>` (which forces a `Wait` protocol, rejected above), OR make `Polling` hold a closure `wait: (Deadline?, inout [Event]) throws -> Int` instead of a concrete `Executor.Wait.EventSource` — lose the typed buffer shape but gain flexibility. This is closer to Design 1 in the prior research (closure-parameterized). Pure sibling-variant approach (new composition per wait-primitive type) keeps the type story clean; closure approach keeps the count of compositions low. **Recommended for v1**: sibling approach. If more than one non-EventSource wait primitive emerges, revisit.

**SpliceLoop case**: a hypothetical `swift-pipes` SpliceLoop (Linux splice syscall) would poll a pipe's readiness — that IS a kqueue/epoll event source, so it slots in as a data-plane `IO.Event.Loop`-style consumer without any new primitives. No new composition. Confirms the taxonomy's coverage.

### V5: Race-safety arguments (per composed type)

| Composed Type | Thread Topology | Domain State Ownership | Race Argument | Pass/Fail |
|---------------|-----------------|-----------------------|---------------|-----------|
| `Executor.Cooperative` | Caller's thread only | Jobs in `Executor.Job.Queue`, protected by `Condvar.withLock`. No other state. | Single data-plane lock. `enqueue` acquires; `run` acquires-on-dequeue. Classic condvar discipline. | Pass |
| `Executor.Main` (Darwin) | DispatchQueue.main — one thread | Queue managed by libdispatch | Delegated to libdispatch | Pass |
| `Executor.Main` (Linux/Windows) | Caller's main-thread | `Executor.Job.Queue` under Condvar | Same as Cooperative | Pass (if shipped) |
| `Executor.Scheduled<Base>` | Timer thread + Base's thread(s) | `Job.Priority` owned by timer thread; `Base` is black-boxed | Timer thread is the only writer into `Job.Priority`; enqueue path is lock-guarded in `wait.withLock`. Delegated enqueue to `Base` is `Base`'s race problem. | Pass |
| `Kernel.Thread.Executor` | One owned thread | `Job.Queue` under Condvar; `shutdown.Flag` atomic | Condvar discipline identical to today | Pass |
| `Kernel.Thread.Executor.Sharded` | N owned threads | Per-thread `Job.Queue` + per-thread `Condvar`. Round-robin counter is `Atomic<UInt64>` relaxed. | Each shard is a `Kernel.Thread.Executor`; inter-shard state is the atomic counter only. | Pass |
| `Kernel.Thread.Executor.Stealing` | N owned threads | Per-worker `Executor.Job.Deque`; cross-worker steal is the sole cross-thread contention | Chase-Lev deque semantics: owner uses LIFO (back), thief uses FIFO (front). `Executor.Job.Deque`'s `Queue_DoubleEnded_Primitives.Deque` backing must either be lock-guarded per-worker (simple but slower) or truly lock-free (faster, complex). For v1: lock-guarded per-worker. Performance delta documented. | Pass (lock-guarded v1) |
| `Kernel.Thread.Executor.Polling` | One owned thread | `Job.Queue` under `queueLock` (mutex-only, no condvar); `Kernel.Event.Source` thread-confined to the executor thread; `shutdown.Flag` atomic; consumer's domain (`registrations`/`entries`) thread-confined | The triage's Option-A race: consumer's state touched from two threads (actor methods on Base executor's thread; runLoop on Polling's thread). Eliminated here because actor methods are pinned to `Polling.asUnownedSerialExecutor()`, which IS the polling thread. Single-thread access to domain state. | **Pass — specifically addresses the triage disqualifier.** |

All seven pass. The `Polling` argument is the critical one; it is the exact race the triage's Option A failed on, and here it does not arise because the Loop (consumer) forwards its `unownedExecutor` to the Polling executor rather than to a separately-threaded `Kernel.Thread.Executor`.

### V6: Performance estimate

**Baseline**: io-bench measures ~0.95× raw syscall for the shared-executor path on the current `IO.Event.Loop` (per `io-performance-ceiling-measurement.md`).

**Post-migration per-op overhead**:

| Operation | Today | Post-Migration | Δ |
|-----------|-------|----------------|---|
| `enqueue` cross-thread | withLock + wake | withLock + wake (same mechanism, now on Polling) | ≈ 0 ns |
| Per-tick closure call | direct method on Loop | indirect via `@Sendable` closure | +3-5 ns / iter |
| Per-tick wake | direct method on channel | direct method on wakeup (unchanged) | ≈ 0 ns |
| Per-job dispatch inside drain | direct | direct (Polling does it) | ≈ 0 ns |
| Per-job acquisition (queue drain) | direct inline | delegated to `Executor.Job.Queue.drain(into:)` (swap — O(1)) | ≈ 0 ns |

Total overhead: ~3-5 ns per polling iteration (one closure call). At 1e6 events/sec that's ~3-5 ms/s overhead (~0.3-0.5% CPU). At 10e6 events/sec (synthetic), ~3-5% — worst case. Real workloads are dominated by syscall latency (`epoll_wait` ≥ 500 ns idle, microseconds typical). **Budget**: <50 ns above raw syscall. **Actual**: ~5 ns per iteration. **Pass.**

The closure indirection is the only measurable cost. If it showed up as >5% in bench, the fix is to drop the closure and generalize via a protocol on Loop (or make `tick` a generic type parameter) — the lowest-cost change that keeps the composition story.

### V7: Naming compliance

Each proposed type, Decision test from [API-NAME-001]: "is X a kind of Y / does X belong to Y?"

| Proposed name | Decision test reading | Passes [API-NAME-001]? | Passes [API-NAME-002]? | Notes |
|---------------|----------------------|------------------------|------------------------|-------|
| `Executor` (namespace) | — (root) | Pass | — | root |
| `Executor.Job` | "a Job in the Executor domain" | Pass | — | namespace |
| `Executor.Job.Queue` | "a Queue of Jobs in the Executor domain" | Pass | Pass | |
| `Executor.Job.Deque` | "a Deque of Jobs in the Executor domain" | Pass | Pass | |
| `Executor.Job.Priority` | "a Priority-queue of Jobs in the Executor domain" | Pass | Pass | "Priority" reads as role, not compound |
| `Executor.Wait` | "the Wait concept within the Executor domain" | Pass | — | namespace |
| `Executor.Wait.Condvar` | "a Condvar wait primitive" | Pass | Pass | spec-mirroring: "condvar" is POSIX term |
| `Executor.Wait.EventSource` | "an EventSource wait primitive" | **Fail on its face** — "EventSource" is compound | **See below** | |
| `Executor.Shutdown` | "the Shutdown concept" | Pass | — | namespace |
| `Executor.Shutdown.Flag` | "a shutdown Flag" | Pass | Pass | |
| `Executor.Cooperative` | "a Cooperative Executor" | Pass | Pass | |
| `Executor.Main` | "a Main Executor" | Pass | Pass | |
| `Executor.Scheduled` | "a Scheduled Executor" | Pass | Pass | generic over Base |
| `Kernel.Thread.Executor` | "an Executor for Kernel.Threads" | Pass | Pass | |
| `Kernel.Thread.Executor.Sharded` | "a Sharded Executor" | Pass | Pass | |
| `Kernel.Thread.Executor.Stealing` | "a Stealing Executor" | Pass | Pass | locked rule #2 |
| `Kernel.Thread.Executor.Polling` | "a Polling Executor" | Pass | Pass | |

**The `Executor.Wait.EventSource` concern**: "EventSource" reads as two concepts compounded. The underlying type IS `Kernel.Event.Source`. A cleaner nested form is `Executor.Wait.Event.Source` — a Source of Events for Waiting — or simply rename `EventSource` to match the Kernel term, `Kernel.Event.Source`, and have `Executor.Wait` be a namespace whose members are wait primitives.

**Recommendation**: rename `Executor.Wait.EventSource` to `Executor.Wait.Event` (namespace) containing `Executor.Wait.Event.Source`, mirroring the existing `Kernel.Event.Source` structure. Reading: "a Source of Events for Waiting in the Executor domain." Passes [API-NAME-001]. Note the locked taxonomy uses "EventSource" as a single word — this is a **non-locked implementation detail** (the locked rule is that the PRIMITIVE exists, not its exact compound spelling). Flagging for the user.

**The `Executor.Wait.Condvar` check**: "Condvar" is the POSIX-specification term (pthread_cond_t, "condition variable," conventionally "condvar"). Per [API-NAME-003], specification-mirroring names are permitted. Pass.

Overall: **17 of 18 type names pass; 1 is a locked-taxonomy renaming candidate that the user should decide on.** No compound identifiers in methods or properties.

### V8: Polymorphism mechanism justification

**Chosen**: concrete sibling types (no protocol, no generic parameter, no witness) for `Executor.Wait.Condvar` and `Executor.Wait.EventSource`.

**Per [IMPL-COMPILE]**: the type system should express invariants. The two wait primitives have divergent invariants (lock held vs no lock; no arguments vs deadline+buffer; non-throwing vs throwing; non-consuming vs consuming). A common protocol forces the less-restrictive type to lie about its constraints, or the more-restrictive to drop information. Neither lets the compiler do more work — it lets it do less.

**Per [PATTERN-013]**: protocols require 3+ concrete conformers. We have 2 wait-primitive types today. A protocol would be speculative.

**Per feedback_language_features_over_custom_types.md**: "Use borrowing/consuming/~Copyable for ownership fixes; never invent Raw/Borrow shadow types." A witness struct for a non-existent protocol is an invented shadow layer.

**Per feedback_no_gratuitous_l3_delegation.md**: "Don't delegate L3→L2 when it adds allocation/unsafe overhead for no benefit." Any indirection layer (witness, generic, protocol) adds closure capture or vtable dispatch cost for the benefit of uniting two types that never occur in the same expression. The unification has no downstream consumer — no algorithm takes `some Wait.Primitive`; no generic function dispatches on it.

**Consequence**: compositions statically select their wait primitive. No polymorphism. When a third wait primitive appears, it's a new sibling type, not a protocol conformance.

---

## Prior Art Survey (focused)

### Swift NIO EventLoop

NIO factors the polling-executor pattern into three layers: `EventLoop` (protocol surface — `execute`, `scheduleTask`, `makeFuture`); `SelectableEventLoop` (concrete poll-blocking implementation wrapping a `Selector`); `Selector<Reg>` (backend-specific registration + dispatch — kqueue / epoll / io_uring in newer versions). There is effectively **one** `SelectableEventLoop` body; per-loop polymorphism happens above it (in channels and pipelines), not inside.

**Lesson for our taxonomy**: NIO confirms that the "polling executor body" is better factored as a single non-generic implementation plus a polymorphic wait primitive, not as many executor variants. Our `Kernel.Thread.Executor.Polling` mirrors `SelectableEventLoop`'s role; our `Executor.Wait.EventSource` (`.Event.Source` if renamed) mirrors `Selector`'s role. NIO does NOT have a `Cooperative`, `Stealing`, or `Main` — those are outside its mission (NIO is server-side, not a general executors kit). The 7-composition framing correctly expands beyond NIO's scope, which is what a "complete toolkit" mission implies.

### Tokio Runtime

Tokio composes `Builder` steps enabling an io driver, time driver, signal driver. The conceptual primitive is a **park/unpark pair**: `park()` blocks until work is ready or unpark fires; `unpark()` is thread-safe and idempotent. Each driver implements park/unpark; a "composite driver" calls each in turn. The scheduler (`current_thread` or `multi_thread`) is decoupled from the drivers — both reuse the same driver composition.

**Lesson**: Tokio confirms the axes we split: wait primitive (park/unpark) is orthogonal to scheduler (current_thread/multi_thread). Our `Executor.Cooperative` = Tokio `current_thread`; our `.Stealing` = Tokio `multi_thread`; our `.Polling` fuses scheduler + io-driver (Tokio decouples them, we bundle because a single thread does both). The decision to bundle is defensible for single-thread executors where the run loop IS the scheduler — but it means Tokio-style composability (adding a signal driver without changing the scheduler) requires us to add a new composition. The locked taxonomy accepts this trade: completeness over compositional n-ways.

### Java java.util.concurrent

`Executors` factory (`newFixedThreadPool`, `newSingleThreadExecutor`, `newScheduledThreadPool`); `ForkJoinPool` for work-stealing; `ScheduledExecutorService` as a `ScheduledThreadPoolExecutor` providing deadline-ordered task dispatch. `DelayedWorkQueue` is a min-heap priority queue, identical in role to our `Executor.Job.Priority`.

**Lesson**: Java confirms all three of: single-thread (`SingleThreadExecutor` = `Kernel.Thread.Executor`), fixed-pool (`FixedThreadPool` ≈ `Sharded`), work-stealing (`ForkJoinPool` = `Stealing`), scheduled (`ScheduledExecutor` = `Scheduled<Base>`) are durable, named compositions — not transient implementation details. Java's naming (`ForkJoinPool` for stealing) is compound per Java convention; our `Stealing` is cleaner. Java has no direct `Cooperative` or `Polling` analog because Java's threading model doesn't expose kernel event sources at this level.

### Apple GCD / libdispatch

GCD's executor model: global queues (`DispatchQueue.global(qos:)` — work-stealing), serial queues (`DispatchQueue.init(label:)` — single-thread), main queue (`DispatchQueue.main`). No explicit "scheduled" queue — async-after is a method on any queue. No cooperative (runs on the caller) — GCD always dispatches.

**Lesson**: GCD confirms main-thread integration is a first-class concept (`DispatchQueue.main`). On Darwin, our `Executor.Main` likely delegates to `DispatchQueue.main` (see skeleton). GCD's absence of a "polling" executor is because polling is done inside the framework and is not consumer-visible; our ecosystem exposes polling as a first-class composition because `swift-io` is a consumer that wants to own its poll strategy. Different missions, different exposure.

### Apple swift-platform-executors

Capability survey (not naming guide, per locked rule #5). Types exposed on Darwin: `Dispatch.Executor` (wrapper over DispatchQueue), `DispatchMainExecutor` (main dispatch queue wrapper), `DispatchSerialExecutor`, `DispatchGlobalExecutor`. On Linux: `PThreadExecutor`, `CooperativeExecutor`, `LinuxMainExecutor`.

**Lesson**: confirms the axis of named-per-backend compositions is a recognized pattern — but the compound names (`DispatchMainExecutor` is `Dispatch` + `Main` + `Executor` concatenated) violate our [API-NAME-001]. Our taxonomy's flat `.Main` / `.Cooperative` / `.Polling` reads better because our namespace hierarchy carries the Kernel.Thread / Executor context. Confirms the `Main` is a universally-expected composition. Confirms `Cooperative` is a universally-expected composition (Apple ships one). **Confirms** the 7-composition target is not over-engineered — Apple covers the same ground with compound names.

### Rust futures-rs

`LocalPool` (thread-confined, manual drive: `run`, `run_until_stalled`, `try_run_one`); `ThreadPool` (work-stealing); `block_on` (ad-hoc single-future executor).

**Lesson**: futures-rs is oriented at executing futures (user-space tasks), not at composing with kernel wait primitives — a different layer than our `swift-executors`. `LocalPool` confirms the value of an explicit manual-drive executor (our `Cooperative`). `ThreadPool` confirms work-stealing.

### OCaml Eio

Eio is effect-based: the runtime is monolithic per backend (`eio_linux` = io_uring, `eio_posix` = epoll/kqueue). Public surface is capability interfaces (network, file system, clock); the backend instantiates them. Polymorphism is at backend-selection, not within the executor.

**Lesson**: Eio confirms that "everything is one backend-selected monolith" is a valid design when the mission is application-facing capabilities, not reusable executor primitives. Our mission is the opposite — factor primitives so that multiple higher-layer packages (swift-io, swift-pipes, future packages) can compose their own executors. Eio informs us of the alternative we are explicitly NOT taking. The framing contrast clarifies our primitives-first choice.

### Go runtime P/M/G

Go's scheduler: P = logical processor (GOMAXPROCS count), M = OS thread, G = goroutine. P holds a local run queue; M acquires a P to run G's; work-stealing between P's when empty. Network poller is a dedicated M that polls epoll/kqueue and enqueues G's whose network I/O is ready onto any P.

**Lesson**: Go's P/M/G confirms the design pattern of separating (a) work-bearing threads (`M` = our owned threads), (b) work containers (`P.runq` = our per-thread `Executor.Job.Deque`), (c) a dedicated poller thread that enqueues into the same containers (our `.Polling` is conceptually "one M that polls"). Go's network poller and scheduler are on different M's, cooperating via the shared run queues. Our `.Polling` fuses them into one thread — appropriate for single-actor-per-loop consumers like `IO.Event.Loop`, less appropriate for large-scale I/O (where you'd want a poller M feeding many scheduler M's). **Implication**: v1 ships the fused `.Polling`; a future `Kernel.Thread.Executor.Reactive` (dedicated poller M feeding a `Stealing` pool) might be a post-v1 addition. Not a v1 showstopper.

---

## Migration Plan

**Order of operations**:

1. **Create swift-executor-primitives (L1)** — new superrepo target.
   - New files: namespace enums (`Executor`, `Executor.Job`, `Executor.Wait`, `Executor.Shutdown`), concrete primitives, exports.
   - Dependencies: `swift-queue-primitives` (Queue.Dynamic, Queue.DoubleEnded), `swift-heap-primitives` (Heap.Min), `swift-synchronization` (Atomic), `swift-kernel-primitives` (for `Kernel.Event.Source` + `Kernel.Wakeup.Channel` — an L1→L1 dep; see Open Questions).
   - Estimated new LOC: ~350 (9 public types × ~40 LOC each, plus exports, plus docs).

2. **Refactor swift-executors (L3)** — in place.
   - Update `Package.swift` to depend on `swift-executor-primitives`.
   - `Kernel.Thread.Executor.Job.Queue.swift` — **delete** (now L1 `Executor.Job.Queue`). Remove `Kernel.Thread.Executor.Job` typealias if users confirmed it's not consumed externally.
   - `Kernel.Thread.Executor.swift` — **rewrite** internals per V3: replace `Synchronization<1>` + `Job.Queue` + `isRunning` with `Executor.Wait.Condvar` + `Executor.Job.Queue` + `Executor.Shutdown.Flag`. Public API unchanged.
   - `Kernel.Thread.Executor.Sharded.swift` — **minor refactor**: no structural changes, just follow internal renames in `.Executor`.
   - **New files**:
     - `Kernel.Thread.Executor.Stealing.swift` (+ `.Options.swift` + `.Worker.swift`) — ~200 LOC
     - `Kernel.Thread.Executor.Polling.swift` — ~120 LOC
     - `Executor.Cooperative.swift` — ~80 LOC
     - `Executor.Main.swift` — ~120 LOC (platform-conditional)
     - `Executor.Scheduled.swift` — ~120 LOC
   - Estimated LOC delta: +640 new, -40 removed, net +600.

3. **swift-io consumers migrate** — in place.
   - `swift-io/Package.swift`: `IO Events` and `IO Completions` targets gain dep on `swift-executors` (currently only `IO Blocking` has this; the triage and composable-executor-abstractions both flagged this dep addition as expected).
   - `IO.Event.Loop.swift` — rewrite per V1: from ~340 LOC to ~90 LOC. Loop no longer conforms to `SerialExecutor`/`TaskExecutor`. `unownedExecutor` forwards to held `Polling` executor. Domain state (`registrations`, `shouldHalt`) stays.
   - `IO.Completion.Loop.swift` — rewrite per V2: from ~360 LOC to ~110 LOC.
   - Actor-side (`IO.Events.Actor`, `IO.Completions.Actor`) — unchanged (`unownedExecutor` still returns a valid UnownedSerialExecutor; identity shifts from Loop to Polling, but actor-method isolation is preserved because the Loop holds the Polling and forwards unownedExecutor to it).
   - Estimated LOC delta: ~-500 removed from swift-io.

**Breaking-change analysis**:

- `Kernel.Thread.Executor` public API unchanged (init signatures, `shutdown`, `enqueue`, `asUnownedSerialExecutor`). Internal fields change but these are `private`/`fileprivate`. ABI-wise: class layout changes, but per project convention swift-executors is not `@frozen`/`@_fixed_layout`. No consumer break.
- `Kernel.Thread.Executor.Job` was a public typealias for `UnownedJob`. Verify no consumers rely on `Kernel.Thread.Executor.Job` vs `Executor.Job` — if any, provide a deprecated typealias bridge for one release.
- `Kernel.Thread.Executor.Job.Queue` was documented as internal (package-private); verify in the as-built package. If public, make the L1 `Executor.Job.Queue` the canonical and ship a deprecated typealias for one release.
- swift-io: the Loops lose their `SerialExecutor`/`TaskExecutor` conformance at the class level, but they gain a `unownedExecutor` property that acts identically for actor-pinning purposes. Consumers that stored an `IO.Event.Loop` as a `SerialExecutor` existential break. Unlikely at L3 (most consumers hold the Loop as a concrete type), but worth a grep of downstream repos. If found, either preserve the conformance (Loop delegates every method to its Polling) or publish a migration note.

**LOC estimates**:

| Package | New LOC | Moved LOC | Removed LOC | Net |
|---------|--------:|----------:|------------:|----:|
| swift-executor-primitives (new) | +350 | 0 | 0 | +350 |
| swift-executors | +640 | 40 (Job.Queue → L1) | −40 (Job.Queue removed) | +600 |
| swift-io (IO.Event.Loop) | +90 | 0 | −340 | −250 |
| swift-io (IO.Completion.Loop) | +110 | 0 | −360 | −250 |
| **Total** | **+1190** | **40** | **−740** | **+450** |

---

## Open Questions

- **`Executor.Wait.EventSource` naming vs. `Executor.Wait.Event.Source`.** The locked taxonomy's "EventSource" reads as compound. Mirroring `Kernel.Event.Source` (dot-separated) gives `Executor.Wait.Event.Source`. Recommended: rename. User decides.

- **Does `Executor.Wait.EventSource` depend on `swift-kernel-primitives` at L1?** The current sketch stores a `Kernel.Event.Source`. That forces an L1→L1 dep from `swift-executor-primitives` on `swift-kernel-primitives`. Alternative: parameterize by a generic `Source` type with a known-shape interface, OR move `Executor.Wait.EventSource` to L3 (swift-executors) and leave only `Condvar`-shaped primitives at L1. **Recommendation**: accept the L1→L1 dep; `Kernel.Event.Source` is a primitive concept that belongs at the same layer as the executor wait primitives. Precedent: `swift-io-primitives` already depends on `swift-kernel-primitives` at L1.

- **`Executor.Scheduled<Base>` base constraint.** Today's sketch requires `Base: SerialExecutor & Sendable`. Should it also support `Base: TaskExecutor`? Concretely: a Scheduled-over-Stealing for deadline-ordered submission into a work-stealing pool. Recommendation: yes — make `Scheduled<Base>` generic over `Base: _Executor & Sendable` (a common bound) via two overloads — one for `SerialExecutor`, one for `TaskExecutor`. Complicates the type but matches real usage (stdlib Task scheduling allows both). User confirms whether this complexity is in-scope for v1 or deferred.

- **`Executor.Main` on Linux/Windows.** No kernel-level main-run-loop exists. Options: (a) ship a condvar-pumped Main that runs only when the consumer calls `runMainLoop()` — semantically equivalent but not "automatic"; (b) Linux/Windows availability via `#if os(Darwin)` only, with `Executor.Main` unavailable on other platforms in v1 (breaks the "all seven ship in v1" mission); (c) delegate to `Dispatch.main` (libdispatch on Linux is available but not ubiquitous). **Recommendation**: option (a). Explicit-drive Main pump on Linux/Windows, automatic on Darwin. Document the platform difference in Main's doc comments. **This is not a showstopper** — it is a platform-asymmetry that the user should confirm is acceptable.

- **`Kernel.Thread.Executor.Stealing` counter atomics.** Locked question: stdlib `Atomic<UInt64>` (Synchronization module) or a kernel-primitives atomic? **Recommendation**: stdlib `Atomic<UInt64>` from `Synchronization` — already used by `.Sharded` counter today; no reason to diverge. kernel-primitives atomics are CPU-architecture-specific (L2 CPU ISA specs); stdlib is the right layer for executor state.

- **`IO.Completion.Loop` EventSource adapter.** V2 assumes `IO.Completion.Driver.asEventSource(handle)` can produce a `Kernel.Event.Source`-shaped wait on top of io_uring (Linux: yes, io_uring FD is epoll-pollable) and IOCP (Windows: no). For v1, consider shipping Polling only for kqueue/epoll/io_uring and deferring IOCP Polling to a future `Kernel.Thread.Executor.Polling.CompletionPort` sibling. User decides.

- **Swift Evolution global-executor SE.** The locked taxonomy defers `Executor.Global` pending a stdlib SE. Track which SE — I've seen multiple drafts — so when it lands we know which shape to implement.

- **Upgrading `Executor.Wait` from "namespace of concrete types" to "namespace with a protocol."** If a third wait-primitive variant lands (e.g., signalfd-fused condvar on Linux to unify condvar + fd-wait), we'd have 3 conformers and the [PATTERN-013] threshold crosses. User should know: the upgrade path is non-breaking (add a protocol; concrete types retroactively conform; compositions stay statically dispatched unless they explicitly generalize).

---

## Recommendation

**Ratify the locked taxonomy with three caveats and proceed to implementation.**

The seven-composition framing is consistent (all seven have independent mission + distinct primitive usage + distinct consumer story), complete (covers every axis surveyed in prior art: single-thread, sharded, stealing, polling, cooperative, main, scheduled), and implementable without a showstopper. V1-V6 pass. V7 has one renaming candidate (`Executor.Wait.EventSource` → `Executor.Wait.Event.Source`). V8 picks sibling-variant polymorphism with justification.

**Caveats**:

1. **`Executor.Wait.Primitive` is a documentation name, not a type.** The locked taxonomy's wording implies a Swift protocol or type under that name; the validated design has no such type. `Executor.Wait` is a namespace; the concrete types are `.Condvar` and `.EventSource` (or `.Event.Source` after rename). The locked taxonomy's "primitive" label should be read as "the conceptual contract that these sibling types satisfy."

2. **`Executor.Main` on Linux/Windows is a custom pump, not a platform main loop.** The user should confirm this platform asymmetry is in mission scope. If it isn't, `Executor.Main` should be Darwin-only in v1 and Linux/Windows deferred — which contradicts "all seven ship in v1."

3. **IOCP Polling is blocked on an EventSource adapter that likely does not exist.** For v1, ship `Kernel.Thread.Executor.Polling` on kqueue/epoll/io_uring backends; defer IOCP. Alternatively, generalize `Polling` to hold any wait function (closure-parameterized per prior research Design 1 variant). The latter reintroduces the polymorphism question; the former ships only three of four backends in v1.

None of the three is a hard showstopper. Each is a deliberate v1-scoping decision the user should confirm.

**No other showstoppers identified.** Proceed.

---

## Decisions (Post-Supervision)

User-delivered decisions after the research pass completed (2026-04-15). Each resolves an Open Question or accepts a validation finding. These decisions are the authoritative ground rules for the implementation phase.

### V8 finding — accepted

`Executor.Wait.Primitive` is a **documentation name** for the conceptual contract, not a Swift type. The L1 package exposes `Executor.Wait` as a namespace enum containing concrete sibling types (`Executor.Wait.Condvar`, `Executor.Wait.Event.Source`). Compositions statically select which concrete wait type they embed — no protocol, no witness, no generic parameter. Matches [PATTERN-013]: protocols require 3+ concrete conformers. If a third wait primitive lands (e.g., a signalfd-fused condvar on Linux), the upgrade to a protocol is non-breaking (retroactive conformance + typealias bridge).

### Resolved open questions

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | `Executor.Wait.EventSource` → `Executor.Wait.Event.Source`? | **Yes — rename** | Non-compound per [API-NAME-001]; mirrors `Kernel.Event.Source`. Apply throughout implementation. |
| 2 | `swift-executor-primitives` → `swift-kernel-primitives` L1→L1 dep? | **Yes** | Allowed by tier rules; precedent in `swift-io-primitives` L1→L1 dep on `swift-kernel-primitives`. `Kernel.Event.Source` is a primitive concept that belongs at the same layer. |
| 3 | `Executor.Scheduled<Base>` — `SerialExecutor` only, or also `TaskExecutor`? | **Both — two overloads** | "Complete and perfect" mission implies full stdlib protocol coverage. Real usage (stdlib Task scheduling) allows both. |
| 4 | `Executor.Main` Linux/Windows strategy? | **Option (a) — accept asymmetry** | Darwin: automatic via `DispatchQueue.main`. Linux/Windows: custom condvar pump; consumer calls `runMainLoop()` explicitly. Document the asymmetry in the type's doc comment. Cross-platform mainloop integration is inherently asymmetric; honest asymmetry beats refusing to ship on non-Darwin. |
| 5 | `Kernel.Thread.Executor.Stealing` counter atomics? | **stdlib `Atomic`** (from `Synchronization` module) | Matches `Kernel.Thread.Executor.Sharded`'s existing choice. Consistency beats a minor primitives-independence gain. |
| 6 | IOCP Polling v1 — defer or closure-generalize? | **Defer** | A dedicated `Kernel.Thread.Executor.IOCP` is the future sibling, not a generalized `Polling`. Windows v1 supports `Thread.Executor`, `.Sharded`, `.Stealing`, `Cooperative`, `Main`, `Scheduled`; `.Polling` is Linux+Darwin-only until IOCP-Polling ships as a separate composition. Document the gap. |
| 7 | Swift Evolution tracking for `Executor.Global`? | **Agent tracks** | Informational follow-up only. No decision needed. Open Questions remains the tracking site; when the SE lands, update the tracking note with the SE number. |
| 8 | Upgrade path from sibling-variants to `Wait.Primitive` protocol? | **Accept the plan** | Typealias bridge when 3rd conformer lands. Standard non-breaking evolution per [RES-008]. |

### Operational follow-ups (non-design)

- **Subagent Write/Edit permissions**: settings.json wart — the research subagent hit Write/Edit denials and fell back to bash heredoc. Must be resolved before the implementation phase dispatches (the implementation agent writes dozens of files; heredoc fallback does not scale). Tracked separately.
- **`Research/_index.json`**: per [RES-003c], now required (swift-executors has ≥2 research docs). Cleanup write authorized.

### What these decisions do NOT change

- The seven-composition framing in the Locked Taxonomy. All seven ship in v1 (with IOCP-Polling as the one documented v1 gap, coming in a future 8th composition).
- The L1 split. `swift-executor-primitives` earns its weight per the rule-of-three check in the body.
- The race-safety arguments for all seven composed types (V5).
- The ≤50 ns-over-syscall performance budget (V6).

### Implementation ground rules (derived)

1. First public surface uses `Executor.Wait.Event.Source`, never `Executor.Wait.EventSource`.
2. No `Executor.Wait.Primitive` type exists in any emitted Swift file. `Executor.Wait` is an empty enum (namespace).
3. `Kernel.Thread.Executor.Polling`'s wait is typed `Executor.Wait.Event.Source`, not a generic parameter and not `any` of a protocol.
4. `Executor.Main` availability: all platforms. Body behavior differs (document in the type's doc comment). No `#if os(...)` on the public surface.
5. `Kernel.Thread.Executor.Polling` on Windows: **not shipped in v1**. Windows users needing completion-port dispatch wait for the planned `Kernel.Thread.Executor.IOCP` sibling. No stub, no throw, no fatalError — the type simply does not exist on Windows (`#if !os(Windows)` at the package boundary).

---

## References

- [executor-conformance-triage.md](../../swift-io/Research/executor-conformance-triage.md) — prior Option-A race analysis
- [composable-executor-abstractions.md](./composable-executor-abstractions.md) — prior Design 1 analysis
- [io-performance-ceiling-measurement.md](../../swift-io/Research/io-performance-ceiling-measurement.md) — 0.95× syscall baseline
- [Swift NIO SelectableEventLoop](https://github.com/apple/swift-nio/blob/main/Sources/NIOPosix/SelectableEventLoop.swift)
- [Tokio Runtime park/unpark](https://docs.rs/tokio/latest/tokio/runtime/)
- [Java ForkJoinPool javadoc](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ForkJoinPool.html)
- [Java ScheduledThreadPoolExecutor javadoc](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ScheduledThreadPoolExecutor.html)
- [Apple swift-platform-executors](https://github.com/swiftlang/swift-platform-executors)
- [OCaml Eio backends](https://github.com/ocaml-multicore/eio)
- [Go runtime P/M/G scheduler design document](https://golang.org/s/go11sched)
- [Chase-Lev work-stealing deque (Chase & Lev 2005)](https://dl.acm.org/doi/10.1145/1073970.1073974) — Chase-Lev deque algorithm
- [SE-0392 Custom Actor Executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md) — SerialExecutor protocol definition
- [API-NAME-001] Nest.Name pattern (code-surface skill)
- [PATTERN-013] Protocol threshold (implementation skill)
- [IMPL-COMPILE] Compiler as primary correctness mechanism (implementation skill)
- [MOD-DOMAIN] Factor the law, not the module (modularization skill)
- [PLAT-ARCH-001] Four-level platform stack (platform skill)
