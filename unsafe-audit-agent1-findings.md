<!--
agent: 1
scope: swift-threads, swift-executors, swift-kernel, swift-witnesses, swift-dependencies
phase: 1 (classification only — no Sources edits)
status: COMPLETE
-->

# Agent 1 Findings — Threads / Executors / Kernel / Witnesses / Dependencies

## Summary

- Total hits classified: 17
- Category A (synchronized): 14
- Category B (ownership transfer): 1
- Category C (thread-confined, skip): 0
- Category D candidates (flagged to queue): 1
- Low-confidence flags (<90%): 1
- Preexisting warnings noted (not classified): 8

Excluded per handoff: `Kernel.Thread.Synchronization<N>` (already committed at `da86a35`).

## Scope breakdown (hits per repo)

| Repo | Hits | Notes |
|------|:----:|-------|
| swift-threads | 3 | Barrier / Gate / Semaphore (Synchronization excluded) |
| swift-executors | 7 | Executor + Stealing + Worker + Polling + Main + Cooperative + Scheduled |
| swift-kernel | 1 | Kernel.Thread.Handle.Reference |
| swift-witnesses | 5 | Values._Storage / Sequence / Cycle / Preparation.Store / Recording |
| swift-dependencies | 1 | `_Accessor` enum (flagged D) |
| **Total** | **17** | |

## Classifications

| # | File:Line | Type | Category | Reasoning | Draft docstring or // WHY: |
|---|-----------|------|----------|-----------|----------------------------|
| 1 | `swift-threads/Sources/Thread Barrier/Kernel.Thread.Barrier.swift:30` | `Kernel.Thread.Barrier` | A | Holds `sync = SingleSync()` (= `Synchronization<1>` — mutex + 1 condvar). All access to `_arrived`, `target`, `released` serialized through `sync.lock()` / `sync.withLock`. Classic Cat A. | See Appendix #1 |
| 2 | `swift-threads/Sources/Thread Gate/Kernel.Thread.Gate.swift:43` | `Kernel.Thread.Gate` | A | Holds `sync = SingleSync()`. `_isOpen` flag read/written exclusively under mutex; waiters sleep on condition variable. Classic Cat A. | See Appendix #2 |
| 3 | `swift-threads/Sources/Thread Semaphore/Kernel.Thread.Semaphore.swift:37` | `Kernel.Thread.Semaphore` | A | Holds `sync: Kernel.Thread.DualSync` (mutex + 2 condvars: `available` / `shutdown`). All `_state` mutations serialized through `sync.withLock` / `sync.lock`/`unlock`. Classic Cat A. | See Appendix #3 |
| 4 | `swift-executors/Sources/Executors/Kernel.Thread.Executor.swift:42` | `Kernel.Thread.Executor` | A | Holds `wait: Executor.Wait.Condvar` serializing `jobs` and `_shutdown`. Every enqueue / runLoop / shutdown access goes through `wait.withLock`. Owns a single OS thread; join is lifecycle-bound (shutdown()). Cat A. | See Appendix #4 |
| 5 | `swift-executors/Sources/Executors/Kernel.Thread.Executor.Stealing.swift:20` | `Kernel.Thread.Executor.Stealing` | A | Holds `Atomic<Index<Kernel.Thread>>` cursor + `_shutdown: Shutdown.Flag` (atomic). Per-worker deques guarded by per-worker condvars — all shared state mediated by atomic/condvar primitives. Cat A. | See Appendix #5 |
| 6 | `swift-executors/Sources/Executors/Kernel.Thread.Executor.Stealing.Worker.swift:7` | `Kernel.Thread.Executor.Stealing.Worker` | A | Holds `wait: Executor.Wait.Condvar`. All deque push/pop/steal operations serialized through `wait.withLock`. `handle: Thread.Handle?` is mutated only at lifecycle boundaries (`start` / `join`) on non-worker threads. Cat A. | See Appendix #6 |
| 7 | `swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift:37` | `Kernel.Thread.Executor.Polling` | A | Holds `queueLock: Kernel.Thread.Mutex` guarding `jobs` / `drainBuffer`. `_shutdown` is an atomic Shutdown.Flag. `waitSource` is a kernel event source whose wakeup is MPSC-safe. Cat A. | See Appendix #7 |
| 8 | `swift-executors/Sources/Executors/Executor.Main.swift:24` | `Executor.Main` | A | On Darwin delegates to `DispatchQueue.main` (serial). On Linux/Windows holds `wait: Condvar` serializing `jobs` and `_shutdown`. Cat A under both platforms. | See Appendix #8 |
| 9 | `swift-executors/Sources/Executors/Executor.Cooperative.swift:20` | `Executor.Cooperative` | A | Holds `wait: Condvar` guarding `jobs` and `_shutdown`. Run loop blocks on condvar, producers enqueue under `wait.withLock`. Cat A. | See Appendix #9 |
| 10 | `swift-executors/Sources/Executors/Executor.Scheduled.swift:15` | `Executor.Scheduled<Base>` | A | Holds `wait: Condvar` guarding `priority: Executor.Job.Priority` + `_shutdown`. Timer thread blocks on condvar on head-deadline; producers wake via `wait.wake()`. Cat A. `Base: Sendable` constraint makes the generic parameter sound. | See Appendix #10 |
| 11 | `swift-kernel/Sources/Kernel Thread/Kernel.Thread.Handle.Reference.swift:40` | `Kernel.Thread.Handle.Reference` | B | Wraps a `~Copyable` `Kernel.Thread.Handle`. No mutex, no atomic. Sendable via exactly-once join semantics: `inner.take()` consumes the handle; `deinit` preconditions `inner == nil` (leak detection). Cat B: ownership transfer of the wrapped non-Copyable handle across threads, with exactly-once join at the other end. | See Appendix #11 |
| 12 | `swift-witnesses/Sources/Witnesses/Witness.Values.swift:43` | `Witness.Values._Storage` (internal) | **LOW_CONFIDENCE** (leaning B via COW, not ~Copyable) | Heap class backing a COW `struct Values: Sendable`. No mutex. Mutation gated by `_ensureUnique()` (isKnownUniquelyReferenced + copy). The Sendable claim rests on the COW discipline at the `Values` layer — each isolation domain owns its unique `_Storage` after first write. Not Cat A (no runtime synchronization), not classic Cat B (no `~Copyable`). Possible Cat D (structural workaround) if we treat COW as a caller-enforced ownership invariant the compiler cannot check. Escalation needed. | See Appendix #12 |
| 13 | `swift-witnesses/Sources/Witnesses/Witness.Sequence.swift:37` | `Witness.Sequence<T>` | A | Holds `_index: Mutex<Int>` (stdlib `Synchronization.Mutex`). Every `callAsFunction()` mutates the index under `_index.withLock`. `values: [T]` is read-only after init. `T: Sendable` constraint closes the remaining element-Sendable gap. Classic Cat A. | See Appendix #13 |
| 14 | `swift-witnesses/Sources/Witnesses/Witness.Cycle.swift:36` | `Witness.Cycle<T>` | A | Structurally identical to `Witness.Sequence` — holds `_index: Mutex<Int>`, read-only `values: [T]`, serializes every call under `_index.withLock`. Classic Cat A. | See Appendix #14 |
| 15 | `swift-witnesses/Sources/Witnesses/Witness.Preparation.Store.swift:37` | `Witness.Preparation.Store` | A | Holds `lock: Mutex<Void>` serializing all reads (`get` / `withValue`) and writes (`set` / `remove`) of the `[ObjectIdentifier: UnsafeRawPointer]` storage. `deinit` releases retained boxes. Classic Cat A. | See Appendix #15 |
| 16 | `swift-witnesses/Sources/Witnesses/Witness.Recording.swift:46` | `Witness.Recording<Args>` | A | Holds `_calls: Mutex<[Args]>` (stdlib `Mutex`). Every `record` / `reset` / accessor routes through `_calls.withLock`. `Args: Sendable` closes the generic. Classic Cat A. | See Appendix #16 |
| 17 | `swift-dependencies/Sources/Dependencies/Dependency.swift:116` | `_Accessor<Value: Sendable>` (internal enum) | **D candidate** | `enum _Accessor<Value: Sendable>` with `.keyPath(KeyPath<__DependencyValues, Value>)` and `.closure(@Sendable (__DependencyValues) -> Value)`. `__DependencyValues` is `Sendable`. The `@unchecked` exists because the compiler does NOT derive structural `Sendable` for an enum holding `KeyPath<Root, Value>` from `Root: Sendable, Value: Sendable`. No runtime synchronization, no `~Copyable`, no caller invariant — pure phantom/inference gap. | See Appendix #17 and D queue |

## Appendix — Draft Docstrings / Annotations

### Hit #1 — `Kernel.Thread.Barrier`

```
/// A barrier for synchronizing multiple threads.
///
/// All threads wait at `arrive()` until the target count arrives,
/// then all proceed together.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: every access
/// to `_arrived`, `target`, `released`, and the shared condition variable is
/// serialized by `Kernel.Thread.SingleSync` (a single-condition
/// mutex+condvar wrapper). The caller MUST route every access through the
/// provided `arrive(timeout:)` / `arrived` API; reaching into the stored
/// state outside the mutex is undefined behaviour. The `@unsafe` annotation
/// makes this assertion explicit at the conformance site.
///
/// ## Intended Use
///
/// - Rendezvous coordination for a fixed team of threads (parallel
///   benchmarks, phased computation, simulation steps).
/// - Cross-isolation transfer where producers and consumers need one-shot
///   "everyone arrived" synchronization before proceeding together.
/// - Replacement for ad-hoc atomic counters + condvar plumbing at the
///   kernel-thread layer.
///
/// ## Non-Goals
///
/// - Not a reusable barrier phaser. Once the target count is reached and
///   `released` is set, the barrier stays released. Construct a new
///   `Barrier` for each generation.
/// - Not lock-free. Every `arrive` pays for mutex acquisition; unsuitable
///   for hot paths where atomic primitives suffice.
/// - Not a substitute for Swift `Task` group semantics. For async
///   coordination use the structured-concurrency primitives; `Barrier`
///   exists at the thread layer underneath.
///
/// ## Usage
/// ```swift
/// let barrier = Kernel.Thread.Barrier(count: 3)
///
/// // Thread 1, 2, 3
/// let success = barrier.arrive(timeout: .seconds(5))
/// // All threads released simultaneously when 3rd arrives
/// ```
public final class Barrier: @unsafe @unchecked Sendable {
```

### Hit #2 — `Kernel.Thread.Gate`

```
/// A one-shot blocking synchronization primitive.
///
/// Gate provides a simple rendezvous point where threads block until
/// the gate is opened. Once opened, the gate stays open permanently
/// and all current and future waiters proceed immediately.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: the
/// `_isOpen` flag and the associated condition variable live behind a
/// `Kernel.Thread.SingleSync` (mutex + condvar). Every transition —
/// opening the gate, checking `isOpen`, and waiting — is serialized under
/// the mutex. The caller MUST drive all state transitions through the
/// documented `open()` / `wait()` / `wait(timeout:)` / `isOpen` API.
///
/// ## Intended Use
///
/// - One-shot "ready" signal between a setup thread and one or more
///   consumer threads (e.g., pool warm-up, lazy initialization completion).
/// - Kernel-thread-layer rendezvous where a reusable barrier is overkill
///   and the signal is monotonic (once open, stays open).
/// - Cross-isolation pattern: the signaler and the waiters live in
///   different domains but both hold a reference to the same gate.
///
/// ## Non-Goals
///
/// - Not a reusable barrier. Once `open()` is called, the gate is latched
///   permanently. For reusable synchronization use `Kernel.Thread.Barrier`.
/// - Not a lock-free primitive. Every operation pays for mutex acquisition.
/// - Not a one-to-one promise/future. Gates signal *state*, not values.
///
/// ## Usage
/// ```swift
/// let ready = Kernel.Thread.Gate()
///
/// // Thread 1 (waiter)
/// ready.wait()  // Blocks until opened
///
/// // Thread 2 (signaler)
/// ready.open()  // Releases all waiters
/// ```
public final class Gate: @unsafe @unchecked Sendable {
```

### Hit #3 — `Kernel.Thread.Semaphore`

```
/// A thread-blocking counting semaphore.
///
/// Semaphore limits concurrent access to a resource by maintaining a count
/// of available permits. Threads acquire a permit before accessing the
/// resource and release it when done. When no permits are available,
/// acquiring threads block until a permit is released.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: the entire
/// `_state` struct (permit counts, waiter counts, metrics, lifecycle) is
/// protected by `Kernel.Thread.DualSync` — a single mutex paired with two
/// condition variables (`available` and `shutdown`). Every path — acquire,
/// release, shutdown, wait, metrics snapshot — serializes on the mutex and
/// signals/broadcasts the appropriate condition under the lock. The caller
/// MUST route every access through the documented public API; touching
/// `_state` outside the lock is undefined behaviour.
///
/// ## Intended Use
///
/// - Bounding concurrency over a shared resource at the kernel-thread
///   layer (e.g., "no more than N in-flight requests", "at most K open
///   file handles").
/// - Graceful shutdown with outstanding-permit draining via
///   `shutdown.wait()`.
/// - Metrics-bearing coordination point where acquire/release/reject/
///   timeout counters are observable.
///
/// ## Non-Goals
///
/// - Not an actor. Semaphore does not suspend Swift concurrency tasks;
///   it blocks threads. For async permit acquisition use an actor or a
///   Swift-concurrency-native primitive.
/// - Not a lock-free semaphore. Every acquire/release pays for mutex
///   acquisition; the DualSync layout optimizes for condvar fan-out,
///   not uncontended throughput.
/// - Not reentrant. A thread holding a permit and calling `acquire`
///   again does not recursively succeed; it blocks.
///
/// ## Usage
/// ```swift
/// let semaphore = Kernel.Thread.Semaphore(capacity: 3)
///
/// // Scoped acquire/release
/// let result = try semaphore.run { expensiveWork() }
///
/// // With timeout
/// let result = try semaphore.run.timeout(.seconds(5)) { work() }
///
/// // Graceful shutdown
/// semaphore.shutdown.wait()
/// ```
public final class Semaphore: @unsafe @unchecked Sendable {
```

### Hit #4 — `Kernel.Thread.Executor`

```
/// A serial executor backed by a single dedicated OS thread.
///
/// Conforms to both `SerialExecutor` (for actor pinning via `unownedExecutor`)
/// and `TaskExecutor` (for `withTaskExecutorPreference`).
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: the job
/// queue (`jobs`), the shutdown flag (`_shutdown`), and the stored thread
/// handle (`threadHandle`) are all mutated exclusively under
/// `wait: Executor.Wait.Condvar` — a mutex + condition variable wrapper.
/// `enqueue`, `runLoop`, and `shutdown` each route their state accesses
/// through `wait.withLock`, and cross-thread wake-ups go through
/// `wait.wake()` / `wait.wake.all()`. The caller MUST interact with the
/// executor only through its public API (`enqueue`, `shutdown`, the
/// unowned-executor accessors); reaching into the stored state otherwise
/// is undefined behaviour.
///
/// ## Intended Use
///
/// - Pinning Swift actors to a dedicated OS thread via `unownedExecutor`
///   (`.serial` mode).
/// - Running jobs under `withTaskExecutorPreference` with a task-executor
///   identity (`.task` mode).
/// - Workloads that need deterministic OS-level thread identity (e.g.,
///   thread-local state, TLS-backed subsystems, priority pinning).
///
/// ## Non-Goals
///
/// - Not a work-stealing pool. For fan-out across N threads with stealing
///   use `Kernel.Thread.Executor.Stealing`.
/// - Not safe to shutdown from its own thread. Doing so deadlocks — the
///   implementation detects the case and detaches instead of joining.
/// - Not idempotent on shutdown. `shutdown()` must be called exactly once
///   before the executor is deallocated; a second call traps.
///
/// ## Run Identity
///
/// The executor reports the correct identity when running jobs (otherwise
/// the Swift Concurrency runtime re-enqueues indefinitely):
/// - `.serial` (default): `runSynchronously(on: serialExecutor)` — use
///   for actor pinning via `unownedExecutor`.
/// - `.task`: `runSynchronously(on: taskExecutor)` — use with
///   `withTaskExecutorPreference`.
public final class Executor: SerialExecutor, TaskExecutor, @unsafe @unchecked Sendable {
```

### Hit #5 — `Kernel.Thread.Executor.Stealing`

```
/// N-owned-threads with per-thread deques and work-stealing.
///
/// Each worker owns its `Executor.Job.Deque`. Workers steal from each other
/// when their own deque is empty. Unlike `Sharded`, jobs are not pinned to a
/// specific thread — any worker can run any job — so only `TaskExecutor`
/// conformance is appropriate (stealing violates serial execution order).
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization. The
/// cross-worker state it owns is limited to:
/// - `cursor: Atomic<Index<Kernel.Thread>>` — round-robin dispatcher
///   index, mutated only by `advance(within:)`.
/// - `_shutdown: Shutdown.Flag` — atomic boolean.
/// - `workers: [Worker]` — an immutable-after-init array of
///   independently-synchronized `Worker` instances (see the Worker type's
///   own safety invariant).
///
/// All producer/enqueue paths hit the atomic cursor and then a per-worker
/// condvar. The caller MUST interact only through the public API
/// (`enqueue`, `shutdown`, the unowned-task-executor accessor); touching
/// `workers` or `cursor` directly is undefined behaviour.
///
/// ## Intended Use
///
/// - Fan-out task execution across N OS threads with automatic load
///   balancing via work-stealing.
/// - `withTaskExecutorPreference` for CPU-bound parallel workloads where
///   serial ordering is NOT required.
/// - Default "general pool" task executor at the kernel-thread layer.
///
/// ## Non-Goals
///
/// - Not a SerialExecutor. Stealing violates serial execution order;
///   Swift actor semantics cannot be honored here.
/// - Not safe to shutdown from a worker thread. Must be called from
///   outside the pool.
/// - Not a substitute for `Kernel.Thread.Executor` when actor pinning is
///   required.
public final class Stealing: TaskExecutor, @unsafe @unchecked Sendable {
```

### Hit #6 — `Kernel.Thread.Executor.Stealing.Worker`

```
// package-visible class; no public docstring mandate.

/// A single work-stealing worker owning one OS thread and one deque.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: the deque
/// (`deque`) and the thread handle (`handle`) are mutated exclusively
/// under `wait: Executor.Wait.Condvar`. The enqueue / pop / steal / wake
/// / join paths all serialize through `wait.withLock`. Cross-worker steal
/// attempts touch the victim's deque under the victim's own `wait` lock —
/// never under the stealer's. The caller (the parent `Stealing` pool)
/// MUST route all operations through the package-visible API.
///
/// ## Intended Use
///
/// - Internal building block of `Kernel.Thread.Executor.Stealing` —
///   one Worker per OS thread in the pool.
/// - Hosts the work-stealing run loop: drain own deque, then attempt to
///   steal from peer workers, then block on condvar.
///
/// ## Non-Goals
///
/// - Not a public API. Consumers use `Kernel.Thread.Executor.Stealing`,
///   not `Worker` directly.
/// - Not safe to use outside a `Stealing` pool — lifetime and shutdown
///   semantics are owned by the pool.
package final class Worker: @unsafe @unchecked Sendable {
```

### Hit #7 — `Kernel.Thread.Executor.Polling`

```
/// Single-thread executor whose wait primitive is a kernel event source.
///
/// One OS thread, one job queue, one `Executor.Wait.Event.Source`. The run
/// loop interleaves drain-jobs with a blocking poll on the event source,
/// then passes received events to a consumer-supplied tick body.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization. Cross-
/// thread mutable state is guarded as follows:
/// - `jobs` / `drainBuffer` : protected by `queueLock: Kernel.Thread.Mutex`.
///   Every `enqueue` / `drainJobs` operation serializes through
///   `queueLock.withLock`.
/// - `_shutdown` : atomic `Shutdown.Flag`.
/// - `waitSource` : the kernel event source's wakeup channel is MPSC-safe
///   by construction (POSIX `eventfd` / kqueue-signal equivalents); reads
///   of the event buffer happen exclusively on the executor's own thread
///   inside `runLoop`.
/// - `threadHandle` : mutated only at construction and shutdown boundaries.
///
/// The `tick` closure fires on the executor's own thread — the same
/// thread that dispatches actor jobs — so domain state touched by `tick`
/// is single-threaded w.r.t. that executor's actor jobs.
///
/// The caller MUST interact with the executor only through the public
/// API (`enqueue`, `shutdown`, the unowned-executor accessors, the
/// `source` coroutine-scoped accessor); reaching into stored state
/// otherwise is undefined behaviour.
///
/// ## Intended Use
///
/// - Event-loop executors where actor jobs and kernel events must be
///   interleaved on the same thread (e.g., epoll/kqueue-driven I/O).
/// - Foundation-layer reactor threads that multiplex timers, descriptor
///   readiness, and actor work on one OS thread.
///
/// ## Non-Goals
///
/// - Not a Windows executor. Depends on `Kernel.Event.Source` which
///   requires epoll (Linux) or kqueue (Darwin). A future
///   `Kernel.Thread.Executor.IOCP` sibling will serve the Windows role.
/// - Not idempotent on shutdown in the usual sense — safe to call from
///   any thread (including the executor's own thread), but not from
///   inside the `tick` callback at the same moment.
/// - Not a work-stealing executor. Single-threaded by design.
public final class Polling: SerialExecutor, TaskExecutor, @unsafe @unchecked Sendable {
```

### Hit #8 — `Executor.Main`

```
/// Main-thread serial executor.
///
/// On Darwin, delegates to `DispatchQueue.main` for automatic main-thread
/// integration. On Linux/Windows, provides a condvar-based pump that the
/// consumer must drive via `run()`.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization:
/// - On Darwin, all enqueue paths dispatch into `DispatchQueue.main`,
///   which owns its own lock-free MPSC enqueue primitive and is
///   architecturally Sendable.
/// - On Linux / Windows, the job queue (`jobs`), condition variable
///   (`wait`), and shutdown flag (`_shutdown`) are mutated exclusively
///   under `wait: Executor.Wait.Condvar` — a mutex + condvar wrapper.
///   `enqueue`, `run`, and `shutdown` route state accesses through
///   `wait.withLock`.
///
/// The caller MUST interact with the executor only through its public
/// API. Do not read or mutate the platform-specific stored state
/// directly.
///
/// ## Intended Use
///
/// - Pinning actors to the OS main thread via `Executor.Main.shared`.
/// - Providing a SerialExecutor target on platforms without an ambient
///   main run loop (Linux, Windows) by manually driving `run()` from
///   the main thread.
///
/// ## Non-Goals
///
/// - Not a TaskExecutor. Main-thread dispatch implies serial ordering;
///   task-executor semantics are not offered.
/// - Not a substitute for `DispatchMain()`. On Linux/Windows the pump
///   blocks only until `shutdown()`; there is no ambient integration
///   with OS run loops.
/// - Not multi-instance. The type is exposed only via
///   `Executor.Main.shared`.
public final class Main: SerialExecutor, @unsafe @unchecked Sendable {
```

### Hit #9 — `Executor.Cooperative`

```
/// Runs on the caller's thread; no OS thread spawned.
///
/// Caller drives the run loop explicitly via `run()`. Closest analogs:
/// Tokio `current_thread`, futures-rs `LocalPool`, Apple `CooperativeExecutor`.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: the
/// job queue (`jobs`), condition variable (`wait`), and shutdown flag
/// (`_shutdown`) are mutated exclusively under `wait: Executor.Wait.Condvar`
/// — a mutex + condvar wrapper. `enqueue`, `run`, and `shutdown` route
/// state accesses through `wait.withLock`. The caller MUST interact with
/// the executor only through its public API; touching the stored state
/// directly is undefined behaviour.
///
/// ## Intended Use
///
/// - Single-threaded cooperative task execution on the caller's thread
///   (e.g., test harnesses, deterministic simulation, REPL drivers).
/// - Unit tests that need a drain-to-completion executor without
///   spawning an OS thread.
///
/// ## Non-Goals
///
/// - Not a TaskExecutor. Cooperative scheduling implies serial actor
///   identity; task-executor semantics are not offered.
/// - Not multi-thread. Enqueues from other threads are allowed, but
///   execution is always on the `run()` caller.
/// - Not reentrant within `run()`. Shutdown must be driven from another
///   context (or via a job that calls `shutdown()`).
///
/// ## Usage
/// ```swift
/// let executor = Executor.Cooperative()
/// // From another task:
/// executor.enqueue(job)
/// // On the calling thread:
/// executor.run()   // blocks until shutdown() is called
/// ```
public final class Cooperative: SerialExecutor, @unsafe @unchecked Sendable {
```

### Hit #10 — `Executor.Scheduled<Base>`

```
/// Adds deadline-scheduled enqueue to any underlying serial executor.
///
/// Owns an `Executor.Job.Priority` queue plus a timer thread that blocks
/// on the priority queue's head deadline. When the head fires, the job is
/// moved onto the `Base` executor via `Base.enqueue`. Delegation model.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization: the
/// priority queue (`priority`), condition variable (`wait`), and shutdown
/// flag (`_shutdown`) are mutated exclusively under `wait: Executor.Wait.Condvar`
/// — a mutex + condvar wrapper. The timer thread blocks on `wait` waiting
/// for the head deadline; producers wake it via `wait.wake()`. The stored
/// `base: Base` is itself `SerialExecutor & Sendable`. The caller MUST
/// interact with the executor only through the public API
/// (`enqueue`, `enqueue(_:after:)`, `shutdown`, the unowned-executor
/// accessors); reaching into stored state otherwise is undefined behaviour.
///
/// ## Intended Use
///
/// - Layering timer-driven (delayed) enqueue on top of an existing
///   `SerialExecutor` without rewriting its state machine.
/// - Uniform deadline semantics across different base executor kinds
///   (dedicated-thread, main, cooperative).
///
/// ## Non-Goals
///
/// - Not a full scheduler. Deadlines are monotonic continuous-clock
///   absolute; priority between same-deadline jobs is implementation-defined.
/// - Not a replacement for `Base`. Immediate `enqueue` forwards to
///   `Base.enqueue`; `Scheduled` adds only the deadline-queued overload.
/// - Shutdown shuts only the timer thread, not the base executor.
public final class Scheduled<Base: SerialExecutor & Sendable>: SerialExecutor, @unsafe @unchecked Sendable {
```

### Hit #11 — `Kernel.Thread.Handle.Reference`

```
/// Reference wrapper for storing ~Copyable handle in arrays.
///
/// This class allows storing `Kernel.Thread.Handle` (which is `~Copyable`) in
/// arrays and other Copyable containers. The reference type is Copyable,
/// but the inner handle enforces exactly-once join semantics.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of ownership transfer, not internal
/// locking. It wraps a `~Copyable` `Kernel.Thread.Handle` in `inner:
/// Kernel.Thread.Handle?`, and every live-state transition consumes the
/// handle exactly once:
/// - `join()` uses `inner.take()` to consume the handle; a second call
///   traps (`join() called twice`).
/// - `deinit` preconditions `inner == nil` — deallocation without join
///   traps, surfacing thread leaks at the earliest deterministic point.
///
/// The caller's obligation is to guarantee that `join()` is driven from
/// exactly one thread at exactly one point in the lifecycle, before the
/// wrapper is deallocated. Cross-isolation transfer is sound because the
/// wrapped handle's ownership invariant (exactly-once join) is honored
/// by the wrapper, not by memcpy of bytes.
///
/// ## Intended Use
///
/// - Storing an array of in-flight thread handles at the orchestration
///   layer (e.g., pool drivers, multi-thread lifecycle managers) where
///   the `~Copyable` handle cannot be held in a `[T]` directly.
/// - Producer / consumer handoff: one context spawns the thread and
///   moves the `Reference` to a lifecycle-management context that joins
///   all threads during shutdown.
///
/// ## Non-Goals
///
/// - Not a retain-on-clone handle. The wrapper is `Copyable` at the
///   class-reference layer, but the *thread-join obligation is still
///   exactly-once* — cloning the reference does not clone the obligation.
/// - Not safe to `join()` concurrently from multiple threads. The second
///   call traps.
/// - Not a substitute for `Kernel.Thread.Handle` where a direct
///   `~Copyable` value suffices.
///
/// ## Usage
/// ```swift
/// var threads: [Kernel.Thread.Handle.Reference] = []
/// let handle = Kernel.Thread.trap { ... }
/// threads.append(Reference(handle))
///
/// // Later: join all threads
/// for thread in threads { thread.join() }
/// ```
public final class Reference: @unsafe @unchecked Sendable {
```

### Hit #12 — `Witness.Values._Storage` (LOW_CONFIDENCE)

```
/// (Draft pending adjudication — see Low-Confidence Flags section.)
///
/// If classified B (recommended): Category B via COW ownership discipline.
/// The backing class is Sendable because the enclosing COW struct
/// `Witness.Values` enforces unique ownership via `_ensureUnique()` before
/// any mutation; concurrent writers each end up with their own unique
/// `_Storage` after the first write. Reads never call `_ensureUnique()`;
/// they expect the storage to be either uniquely owned (safe) or frozen
/// after publication.
///
/// If classified D: structural workaround — the compiler cannot prove
/// Sendable through a class holding an UnsafeRawPointer dictionary, but
/// at runtime the COW enclosing struct provides the single-owner
/// guarantee.
```

### Hit #13 — `Witness.Sequence<T>`

```
/// Returns values from a sequence in order, staying on the last value when exhausted.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization. The
/// read-only `values: [T]` array is initialized once in `init` and never
/// mutated thereafter. The cursor `_index: Mutex<Int>` is the only
/// mutable state, and every read/write goes through `_index.withLock`.
/// `T: Sendable` closes the remaining element-Sendable gap. The caller
/// MUST drive all interactions through `callAsFunction()`; touching
/// `values` or `_index` directly is undefined behaviour.
///
/// ## Intended Use
///
/// - Mock witnesses for tests that need deterministic, sequential return
///   values without hand-rolled mutable state.
/// - Scripted-response fixtures where "first call → A, second → B, then
///   latched to last" semantics match test needs.
/// - Cross-isolation fixture sharing (a single `Sequence` used by
///   multiple test actors sharing the mock).
///
/// ## Non-Goals
///
/// - Not a thread-safe iterator protocol adopter. The API is a function
///   call, not `IteratorProtocol`.
/// - Not a substitute for `Witness.Recording` when inputs need to be
///   captured rather than responses issued.
/// - Not lock-free. Every call pays for `Mutex` acquisition.
///
/// ## Usage
/// ```swift
/// let responses = Witness.Sequence(["first", "second", "third"])
/// print(responses())  // "first"
/// print(responses())  // "second"
/// print(responses())  // "third"
/// print(responses())  // "third" (stays on last)
/// ```
public final class Sequence<T: Sendable>: @unsafe @unchecked Sendable {
```

### Hit #14 — `Witness.Cycle<T>`

```
/// Cycles through values forever, wrapping around when exhausted.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization. The
/// read-only `values: [T]` array is initialized once in `init` and never
/// mutated thereafter. The cursor `_index: Mutex<Int>` is the only
/// mutable state, and every read/write goes through `_index.withLock`.
/// `T: Sendable` closes the remaining element-Sendable gap. The caller
/// MUST drive all interactions through `callAsFunction()`; touching
/// `values` or `_index` directly is undefined behaviour.
///
/// ## Intended Use
///
/// - Mock witnesses for retry-logic or state-machine tests requiring
///   repeating response patterns.
/// - Deterministic fixtures for cycle-based behaviour (e.g., pending →
///   processing → complete → pending → ...).
/// - Cross-isolation fixture sharing in concurrent test suites.
///
/// ## Non-Goals
///
/// - Not a bounded sequence. Cycles forever — use `Witness.Sequence` for
///   "latched to last" semantics.
/// - Not lock-free. Every call pays for `Mutex` acquisition.
/// - Not a substitute for `Witness.Recording` when the test captures
///   inputs rather than scripts outputs.
///
/// ## Usage
/// ```swift
/// let statuses = Witness.Cycle(["pending", "processing", "complete"])
/// print(statuses())  // "pending"
/// print(statuses())  // "processing"
/// print(statuses())  // "complete"
/// print(statuses())  // "pending" (cycles back)
/// ```
public final class Cycle<T: Sendable>: @unsafe @unchecked Sendable {
```

### Hit #15 — `Witness.Preparation.Store`

```
/// Thread-safe store for prepared witness values.
///
/// `Store` provides type-safe storage for witnesses that are prepared
/// ahead of time, typically during app startup.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization. The
/// storage dictionary (`storage: [ObjectIdentifier: UnsafeRawPointer]`)
/// is mutated exclusively under `lock: Mutex<Void>`. Every `get` /
/// `withValue` / `set` / `remove` path routes through `lock.withLock`.
/// `deinit` unconditionally releases retained boxes after the Mutex is
/// no longer accessible. The caller MUST drive all interactions through
/// the public API; touching `storage` directly is undefined behaviour.
///
/// ## Intended Use
///
/// - Carrying pre-resolved witness values across `@TaskLocal` boundaries
///   (per [API-IMPL-010]).
/// - App-startup preparation step where dependencies are constructed
///   once and then looked up without re-resolution per access.
/// - Mocking path shared across a test suite — one store prepared at
///   set-up, queried under `Witness.Context.mode`.
///
/// ## Non-Goals
///
/// - Not a general key-value cache. The storage uses raw-pointer boxing
///   of `Ownership.Shared` values and is not intended for arbitrary
///   object graphs.
/// - Not lock-free. Every access pays for `Mutex` acquisition; call
///   sites should batch reads when possible.
/// - Not a substitute for `Witness.Values` at the task-level API; this
///   is the prepared-values store beneath it.
///
/// ## Usage
/// ```swift
/// let store = Witness.Preparation.Store()
/// store.set(FileSystem.self, value: .darwin)
/// let fs = store.get(FileSystem.self)  // FileSystem?
/// ```
@safe
public final class Store: @unsafe @unchecked Sendable {
```

### Hit #16 — `Witness.Recording<Args>`

```
/// Records all calls for later inspection.
///
/// ## Safety Invariant
///
/// This type is `Sendable` by virtue of internal synchronization. The
/// call log (`_calls: Mutex<[Args]>`) is the only mutable state, and
/// every mutator (`record`, `reset`) and accessor (`calls`, `count`,
/// `isEmpty`, `last`, `first`) routes through `_calls.withLock`.
/// `Args: Sendable` closes the remaining element-Sendable gap. The
/// caller MUST drive all interactions through the public API.
///
/// ## Intended Use
///
/// - Test doubles / mock witnesses that capture invocation arguments
///   for verification in `#expect` assertions.
/// - Cross-isolation call capture — multiple test actors sharing the
///   same recording to verify cross-actor invocation sequences.
/// - Tuple-based recording for witnesses with multiple arguments.
///
/// ## Non-Goals
///
/// - Not an ordered stream with back-pressure. The log grows unbounded
///   unless `reset()` is called.
/// - Not lock-free. Every operation pays for `Mutex` acquisition.
/// - Not a replacement for `Witness.Sequence` when the test scripts
///   *responses* rather than capturing *inputs*.
///
/// ## Usage
/// ```swift
/// let recording = Witness.Recording<String>()
/// recording.record("Hello")
/// recording.record("World")
/// #expect(recording.calls == ["Hello", "World"])
/// ```
public final class Recording<Args: Sendable>: @unsafe @unchecked Sendable {
```

### Hit #17 — `_Accessor<Value>` (D candidate — entry also in D queue)

```
// WHY: Category D — structural Sendable workaround.
// WHY: `_Accessor<Value: Sendable>` is an enum with a `KeyPath<__DependencyValues,
// WHY: Value>` case and an `@Sendable (__DependencyValues) -> Value` case.
// WHY: `__DependencyValues` is `Sendable` and `Value: Sendable`, so the KeyPath
// WHY: *should* be Sendable — but the compiler does not derive structural
// WHY: `Sendable` for an enum containing a `KeyPath<Root, Value>` case from
// WHY: `Root: Sendable, Value: Sendable`.  No caller invariant to uphold —
// WHY: data is pure value bytes; no runtime synchronization; no ~Copyable.
// WHEN TO REMOVE: Swift compiler gains structural Sendable inference
// WHEN TO REMOVE: through KeyPath generic parameters, OR explicit conditional
// WHEN TO REMOVE: Sendable propagation is adopted for enums.
// TRACKING: unsafe-audit-findings.md Category D; tagged-structural-sendable.md.
```

## Low-Confidence Flags

### Hit #12 — `Witness.Values._Storage` (internal class inside a public COW Sendable struct)

**Declaration**: `swift-witnesses/Sources/Witnesses/Witness.Values.swift:43`

**What's confusing**: This is the storage class for a Copy-on-Write value type (`Witness.Values: Sendable`). The class itself has no mutex, no atomic, and no `~Copyable` — but the enclosing struct's writes all go through `_ensureUnique()` (`isKnownUniquelyReferenced(&_storage)` + copy). Mutations on a uniquely-owned `_Storage` are safe; sharing across isolation domains is expected to go through the struct's COW protocol, not through the class directly.

**Why it doesn't fit A cleanly**: No runtime synchronization exists inside `_Storage`. The `set` method and `dict` access are plainly unsynchronized.

**Why it doesn't fit B cleanly**: `_Storage` is `Copyable` (a regular `class`). The "ownership transfer" is not enforced by the type system — it's enforced by the COW discipline at the `Values` layer.

**Why it's arguably D**: The compiler can't see the COW discipline; the `@unchecked` is a structural escape hatch saying "trust the enclosing pattern."

**What I'd recommend**: Classify **B** (ownership transfer via COW — the single-owner guarantee is real, just indirectly enforced), but this is a judgment call. If principal prefers to keep D strictly for phantom-type inference gaps (the original Tagged definition), this could be reclassified as a new Category E (COW-backed Sendable) or handled individually with a longer note in `// WHY:`.

**Decision requested**: Principal-level adjudication. Mark as B with COW-specific invariant, mark as D, or carve out new treatment.

## Preexisting Warnings Noted

Per task-scope rule, these are **NOT** my concern to fix — flagged for Phase 2 separate treatment:

The stdlib bridge methods `asUnownedSerialExecutor()` / `asUnownedTaskExecutor()` construct `UnownedSerialExecutor(ordinary: self)` / `UnownedTaskExecutor(ordinary: self)`, which are flagged by `.strictMemorySafety()` because the stdlib initializers are themselves `@unsafe`. Sites in my scope (8 total across swift-executors):

| File | Line(s) | Method |
|------|:-------:|--------|
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.swift` | 101 | `asUnownedSerialExecutor()` |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.Stealing.swift` | 51 | `asUnownedTaskExecutor()` |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift` | 100 | `asUnownedSerialExecutor()` |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift` | 108 | `asUnownedTaskExecutor()` |
| `swift-executors/Sources/Executors/Executor.Main.swift` | 65 | `asUnownedSerialExecutor()` |
| `swift-executors/Sources/Executors/Executor.Cooperative.swift` | 45 | `asUnownedSerialExecutor()` |
| `swift-executors/Sources/Executors/Executor.Scheduled.swift` | 45 | `asUnownedSerialExecutor()` (delegates to base) |
| `swift-executors/Sources/Executors/Executor.Scheduled.swift` | 53 | `asUnownedTaskExecutor()` (delegates to base) |

The call sites already use `unsafe UnownedSerialExecutor(ordinary: self)` / `unsafe UnownedTaskExecutor(ordinary: self)` expression-keyword form, but per the pilot note these still generate strict-memory warnings at the method-surface level. Phase 2 must decide whether these methods receive `@unsafe` attribute propagation or accept the warning as documented cross-boundary propagation.

**Recommendation**: Separate handoff for stdlib-bridge propagation — out of Agent 1's scope.
