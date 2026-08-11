# Incoming Queue Concurrency Model

<!--
---
version: 1.0.0
last_updated: 2026-04-29
status: DECISION
tier: 2
---
-->

## Context

Bartlett's 2026-04-29 walkthrough of `DefaultActorImpl::defaultActorDrain`
([X post](https://x.com/jacobtechtavern/status/2049489712209862750))
documents the runtime's two-queue actor architecture:

1. **Lock-free linked-list "incoming" queue.** Producers from any pool
   worker append via atomic CAS push without taking the actor's main
   lock. Documented in `swiftlang/swift/stdlib/public/Concurrency/Actor.cpp`
   under the `defaultActorDrain` / `processIncomingQueue` paths.
2. **"Executing" priority queue.** Drained under the actor's lock,
   bucketed by `JobPriority`. The `processIncomingQueue()` call at the
   end of each drain iteration moves the lock-free linked list into
   the priority queue for execution.

The lock-free incoming queue is the throughput-critical mechanism: with
millions of actors and tens of pool worker threads, lock-free push
avoids producer-side contention with the drainer's lock. Only the
drainer takes the lock once per drain pass to scoop the linked list
into the priority queue.

Our `Executor.Job.Queue`
(`swift-primitives/swift-executor-primitives/Sources/Executor Job Queue Primitives/Executor.Job.Queue.swift:22-31`
[Verified: 2026-04-29]) is a `Deque<UnownedJob>` requiring
caller-supplied synchronization (the type's docstring at line 21:
*"Caller supplies the lock / synchronization. This type is the storage
primitive only — not itself locked."*). `Executor.Cooperative` and
`Kernel.Thread.Executor` wrap it with `Executor.Wait.Condvar` (mutex +
condvar):

- **Enqueue**: producer takes the mutex, enqueues, releases, signals
  the condvar.
- **Drain**: drainer takes the mutex, swaps the deque into a buffer
  via `swap(&jobs, &drainBuffer)`, releases, executes the buffer
  outside the lock.

The structural difference relative to the runtime is real: the runtime
uses a lock-free linked list for the producer-side; we use a
mutex-protected deque. This research scopes whether
swift-executor-primitives (or swift-executors) should pursue the
runtime's lock-free MPSC linked-list pattern.

## Question

Should `swift-executor-primitives` introduce a lock-free MPSC
linked-list queue (atomic-CAS push, single-consumer drain) for use as
the producer-side of an actor's incoming queue, matching the Swift
runtime's `DefaultActorImpl` design?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| Ecosystem queue contract: caller-held lock | `swift-async-primitives/Sources/Async Waiter Primitives/Async.Waiter.Queue.swift:25-32` documented as *"Queue types are NOT internally synchronized... All queue operations MUST be called while holding the caller's mutex"* [Verified: 2026-04-29] | Adding self-synchronizing queues diverges from a documented ecosystem contract |
| `Queue.Linked` is single-threaded | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.Linked.swift:46-107` — arena-based linked-list FIFO, ~Copyable, COW for Copyable elements [Verified: 2026-04-29] | No existing primitive provides MPSC semantics |
| Atomics are reserved for state-machine transitions | grep verification 2026-04-29: `Async.Completion`, `Async.Broadcast`, `Async.Waiter`, `Async.Bridge` use atomics for state, never queue head/tail | No queue head/tail uses atomics in the current ecosystem |
| swift-executors target executors are dedicated- or donated-thread | `Kernel.Thread.Executor` (own thread), `Executor.Cooperative` (donated thread) | Producer concurrency per executor is bounded (low) |
| Runtime lock-free design serves libdispatch-pool model | `Actor.cpp` and libdispatch design — millions of actors, shared worker pool | Different scale from the executors this package targets |
| Lock-free linked-list MPSC requires ABA protection | hazard pointers / epoch reclamation | Substantial code surface (~1000+ lines, real-time-safety edge cases) |
| Existing batch-swap pattern produces no contention beyond brief enqueue serialization | `Executor.Cooperative.swift:182` (`swap(&jobs, &drainBuffer)`); `Executor.Job.Queue.drain(into:)` at queue line 62-64 [Verified: 2026-04-29] | Drainer takes lock once per drain pass to swap; executes outside lock |

## Analysis

### Why the runtime needs lock-free MPSC

`DefaultActorImpl` instances are rented onto libdispatch's shared
worker pool. Worker threads pick up `ProcessOutOfLineJob` instances
and become the actor's drainer for one drain pass. Producers from any
pool worker may enqueue to any actor's incoming queue. With
potentially millions of actors and tens of pool workers, lock-free
push on each actor's incoming queue avoids producer-side contention
with the drainer's lock. The lock-free CAS push is amortized O(1) and
never blocks producers.

This design is calibrated for: (a) actor-as-resource, where any thread
in the pool may produce for any actor; (b) actor count vastly exceeding
worker count; (c) sub-µs producer latency target.

### Why swift-executors does not need it

`Kernel.Thread.Executor` owns one thread per executor; producer
concurrency per executor is bounded by the number of concurrent
producers in the application calling `enqueue`. For typical executor
populations (a handful of sharded pools, a few dedicated kernel-thread
executors), producer contention is low.

`Executor.Cooperative` runs on the donated thread; producers from
other threads enqueue while the donator drives the drain. Producer
concurrency is similarly bounded by the application's producer count.

Neither approaches the libdispatch-pool scale where every worker can
be a producer for every actor. The current batch-swap-under-mutex
pattern produces no measurable contention at the target executor
scale.

### Cost of introducing lock-free MPSC

| Dimension | Cost |
|-----------|------|
| New primitive surface (per [RES-018]) | New ecosystem type with ABA protection, Sendable analysis, `~Copyable` interaction |
| Ecosystem contract divergence | Conflicts with documented "caller-supplied lock" contract; consumers can mistakenly mix the two |
| Implementation surface | Hazard pointers / epoch reclamation: 1000+ lines, real-time-safety edge cases |
| Maintenance | Each ecosystem change must consider the lock-free invariants |
| Benefit at swift-executors target scale | Negligible — bounded producer concurrency means contention savings are unmeasurable |

### [RES-018] Premature Primitive check

- *Why not compose existing?* The existing primitives
  (`Queue.DoubleEnded`, `Queue.Linked`, `Queue.Bounded`,
  `Async.Waiter.Queue`) all advertise external-mutex semantics.
  Lock-free MPSC is a different concurrency model that cannot be
  assembled from these via composition.
- *Second consumer?* No. The motivating consumer is "match the
  runtime's actor incoming queue" — a hypothetical future executor
  shape (runtime-pool-driven actor implementation), not present in v1
  / v2 / v3 plans. No second consumer in the existing ecosystem.

[RES-018] fails on the second-consumer check.

### Prior art

| System | Incoming-queue model |
|--------|----------------------|
| Apple Swift runtime `DefaultActorImpl` | Lock-free linked-list MPSC ([Bartlett 2026-04-29](https://x.com/jacobtechtavern/status/2049489712209862750); `Actor.cpp`) |
| libdispatch | Per-queue lock-free MPSC where contended; mutex elsewhere |
| Tokio (Rust) | MPSC channel via crossbeam segmented buffer |
| Go runtime | Per-P run queue with stealing; not lock-free MPSC |
| swift-async-primitives `Async.Waiter.Queue` | Caller-supplied mutex; deliberate per documentation |

The pattern of pursuing lock-free MPSC correlates with the system's
actor-pool model (millions of actors, shared worker pool).
General-purpose executor toolkits without that model use
mutex-protected queues.

**Per [RES-021] contextualization:** the runtimes that pursue lock-free
MPSC do so because their concurrency model demands it; the runtimes
that don't, don't. Universal adoption would not imply universal
necessity — and adoption is not universal in any case.

## Outcome

**Status: DECISION — do not pursue.**

`swift-executor-primitives` and `swift-executors` will NOT introduce a
lock-free MPSC linked-list queue for v1, v2, or v3 absent a future
executor model that demonstrably requires it. The current
batch-swap-under-mutex pattern is sufficient for the executor scale
this package targets (sharded pools, kernel-thread executors,
cooperative-donated executors).

**Rationale summary:**

1. **Ecosystem contract.** All queue and async primitives in
   swift-primitives advertise "caller supplies the lock." Adding a
   self-synchronizing queue diverges from a documented contract,
   inviting consumers to mix the two and produce undefined behaviour.
2. **[RES-018] failure.** No second consumer exists in the ecosystem;
   the only candidate is "match the runtime's design," which is not a
   demonstrated need.
3. **Scale mismatch.** The runtime's lock-free design is calibrated
   for the libdispatch-pool model (millions of actors). swift-executors
   targets bounded-concurrency executors where the contention savings
   are unmeasurable.
4. **Implementation cost.** ABA protection, hazard pointers, ~1000
   lines of unsafe code with real-time-safety edge cases — no
   measurable benefit at the target scale.

**Documented as deliberate scoping.** This decision is referenced from
the swift-executors README and from this Research/ corpus. Future
readers asking "why don't we model the runtime's actor incoming queue?"
get an answer rooted in scale and ecosystem-contract compatibility,
not silent omission.

**Re-evaluate when:** a swift-executors-style runtime-pool-driven actor
implementation enters the v3+ roadmap (i.e., the package starts
targeting libdispatch-equivalent actor scale rather than thread-bound
executors). At that point the decision is revisited; until then,
do not pursue.

**Escalation note** per [RES-004b]: this analysis touches
swift-queue-primitives and swift-async-primitives (the documented
ecosystem-contract sources). The decision applies to swift-executors;
the ecosystem contract it relies on is in those upstream packages. If
those packages ever change their concurrency contract (e.g., introduce
a lock-free family alongside the mutex-protected family), this
decision should be re-evaluated.

## References

### Internal
- `swift-primitives/swift-queue-primitives/Sources/Queue Primitives Core/Queue.Linked.swift:46-107` — current linked queue (single-threaded, ~Copyable arena) [Verified: 2026-04-29].
- `swift-primitives/swift-async-primitives/Sources/Async Waiter Primitives/Async.Waiter.Queue.swift:25-32` — explicit "caller holds lock" contract documentation [Verified: 2026-04-29].
- `swift-primitives/swift-executor-primitives/Sources/Executor Job Queue Primitives/Executor.Job.Queue.swift:22-65` — current Deque-backed job queue + batch-swap drain pattern [Verified: 2026-04-29].
- `swift-foundations/swift-executors/Sources/Executors/Executor.Cooperative.swift:182, :188-190` — current batch-swap drain at runtime [Verified: 2026-04-29].
- `priority-escalation-policy.md` v0.6.0 (DECISION, 2026-04-16) — orthogonal axis (M3 thread QoS, not queue concurrency).

### External
- Bartlett, J. — ["How Swift uses your hardware to guarantee actor isolation"](https://x.com/jacobtechtavern/status/2049489712209862750), 2026-04-29 — describes runtime's lock-free incoming queue and processIncomingQueue pattern.
- `swiftlang/swift` — [`stdlib/public/Concurrency/Actor.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Actor.cpp): `:1526` (`scheduleActorProcessJob`), `:1697-1717` (drain loop with `processIncomingQueue`).

### Production runtimes
- Tokio — [`tokio/src/sync/mpsc/`](https://github.com/tokio-rs/tokio/blob/master/tokio/src/sync/mpsc/) (crossbeam-backed MPSC channels).
- Go runtime — [`runtime/proc.go`](https://github.com/golang/go/blob/master/src/runtime/proc.go) (per-P run queue, work-stealing — not lock-free MPSC).
