# Priority Escalation Policy

<!--
---
version: 0.8.0
last_updated: 2026-04-29
status: DECISION
tier: 2
---
-->

## Context

The Swift runtime propagates priority through a structured-concurrency tree and
escalates the stored priority of a task when a higher-priority caller awaits on
its result (implicit) or when `Task.escalatePriority(to:)` is invoked
(explicit, `Task+PriorityEscalation.swift:46` [Verified: 2026-04-16]). For a
task that is already running, escalation on Darwin drives
`swift_dispatch_lock_override_start_with_debounce` on the thread holding the
task's execution lock (`TaskStatus.cpp:1044` [Verified: 2026-04-16]), which
raises that thread's pthread QoS class. On non-Darwin platforms the whole
machinery is gated by `SWIFT_CONCURRENCY_ENABLE_PRIORITY_ESCALATION`, currently
disabled in public Linux/Windows builds.

The runtime leaves two questions explicitly open where custom executors come in:

1. **Enqueued (not running) tasks.** The TODO at `TaskStatus.cpp:1050–1057`
   reads [Verified: 2026-04-16]:

   > // TODO (rokhinip): Add a stealer to escalate the thread request for
   > //  the task. Still mark the task has having been escalated so that the
   > //  thread will self override when it starts draining the task
   > //
   > // TODO (rokhinip): Add a signpost to flag that this is a potential
   > //  priority inversion

   When a task is waiting in *some* executor's queue, escalation updates only
   the task's stored priority; whether the executor surfaces that change on
   its side is the executor's problem.

2. **Default-actor stealer jobs.** `Actor.cpp:1632, 1638, 1723, 2147` schedule
   an extra `ProcessOutOfLineJob` at the raised priority so that the actor's
   queue drains at the new priority. The identical comments at lines 1632 and
   1723 read [Verified: 2026-04-16]:

   > // We are scheduling a stealer for an actor due to priority override.

   Line 1663 frames this as an explicit workaround:

   > // Until we figure out how to safely enqueue a stealer and rendevouz
   > // with the original job so that we don't double-invoke the job, we
   > // shall simply escalate the actor's max priority to match the new one.

   Line 2147 documents the related race: stealers can be observed and then
   become redundant when the actor unlocks.

`swift-executors` is downstream of this: the runtime hands our executors jobs
whose `ExecutorJob.priority` (accessible via `_jobGetPriority`,
`PartialAsyncTask.swift:228–236` [Verified: 2026-04-16]) reflects the current
stored priority and may mutate under us through the escalation path. Our
taxonomy — `Kernel.Thread.Executor.{Polling, Sharded, Stealing}`,
`Executor.{Cooperative, Scheduled, Main}` — must decide what to do with that
information. The stdlib does not solve this for us; the `DefaultActorImpl`
machinery is internal to the runtime and its "stealer job" pattern does not
generalize to every executor shape in our taxonomy (Polling is single-thread;
Stealing already has a distinct, orthogonal meaning for "stealer"; Cooperative
donates the caller's thread rather than spawning its own).

This document scopes the question, applies priority-inversion theory
(Sha, Rajkumar & Lehoczky 1990), and records initial per-executor policies.
It will reach `DECISION` when (1) each of the five executor shapes has a
locked priority policy, (2) the Linux/Windows thread-QoS story is resolved
to either "opt-in policy" or "out of scope for v1," and (3) the interaction
with work-stealing and NUMA sharding is reconciled.

## Question

What does each executor in the swift-executors v1 taxonomy do when it receives
(or holds) a job whose priority differs from the executor's current
disposition?

Five axes, none independent of the others:

1. **Enqueue-time ordering.** Does the executor insert new jobs by priority,
   or by arrival (FIFO/LIFO)?
2. **Drain-time selection.** Does the executor pick the next job by priority,
   or by the queue's native order?
3. **Executing-thread QoS.** Does the executor raise the OS priority of the
   thread running a job when that job's priority is raised?
4. **Scheduled-but-not-running escalation.** Does the executor add a "stealer"
   (extra processing job at higher priority) to drain faster, as stdlib does
   for `DefaultActorImpl`?
5. **Escalation notification.** Does the executor observe the runtime's
   escalation handlers (`Task+PriorityEscalation.swift:111`
   `withTaskPriorityEscalationHandler` [Verified: 2026-04-16]), or only the
   post-hoc priority field?

The axes interact. Choosing (2) priority-ordered drain implies a
priority-queue data structure, which rules out O(1) enqueue/dequeue and
breaks Chase-Lev's wait-free owner invariant for `Stealing`. Choosing (3)
thread QoS bump assumes a cheap syscall (Darwin) or privileged-capability
access (Linux `CAP_SYS_NICE`). Choosing (4) assumes multiple worker threads
to steal *on*, so it does not apply to single-thread executors.

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| `ExecutorJob.priority` available to user executors | `PartialAsyncTask.swift:228–236` [Verified: 2026-04-16] | Priority is readable at enqueue time and at drain time; no per-escalation callback by default |
| Darwin QoS API: `pthread_override_qos_class_start_np(pthread_t, qos_class_t, int)` returning `pthread_override_t` | `<pthread/qos.h>:213–293` [Verified: 2026-04-16] | Unprivileged, nestable, public SDK; must be paired with `_end_np` or "target thread will be permanently executed at an inappropriately elevated QOS class" |
| `swift_dispatch_lock_override_start_with_debounce` is a Darwin-only Swift-runtime shim | `include/swift/Runtime/DispatchShims.h` [Verified: 2026-04-16] | Wraps Apple-internal `dispatch_lock_override_start_with_debounce` (not in `swift-corelibs-libdispatch` and not in public/SPI dispatch headers); `__builtin_available(macOS 13.0, iOS 16.0, …)` gated |
| Linux SCHED_FIFO/SCHED_RR: requires `CAP_SYS_NICE` or raised `RLIMIT_RTPRIO` | sched(7), pthread_setschedparam(3) [Verified: 2026-04-16] | SCHED_OTHER is reachable unprivileged (per sched(7): "The only change that an unprivileged thread can make is to set the SCHED_OTHER policy"); real-time classes are not |
| Linux unprivileged nice floor = `20 − RLIMIT_NICE` | setpriority(2), getrlimit(2) [Verified: 2026-04-16] | Default `RLIMIT_NICE` is 0 on systemd-based distros, giving a nice floor of +20 — effectively [0, 19] reachable unprivileged |
| Linux autogroup changes the semantics of nice | sched(7) [Verified: 2026-04-16] | With autogroup enabled (default on various distros), "employing setpriority(2) or nice(1) on a process has an effect only for scheduling relative to other processes executed in the same session" — so even the permitted nice direction is weaker than the kernel priority numbers suggest |
| Linux `sched_setattr` SCHED_DEADLINE: requires `CAP_SYS_NICE` | sched(7) [Verified: 2026-04-16] | EDF-capable class, but capability-gated |
| Windows `SetThreadPriority`: works | processthreadsapi.h | Semantic mapping `TaskPriority` → `THREAD_PRIORITY_*` is a policy choice; not explored in depth in this document |
| Embedded Swift: no OS priority model | `@_unavailableInEmbedded` runtime APIs | Any thread-QoS strategy is unavailable on Embedded; must degrade cleanly |
| `Executor.Job.Queue` = FIFO `Deque<UnownedJob>`, O(1) ends | `swift-executor-primitives/…/Executor.Job.Queue.swift` [Verified: 2026-04-16] | Priority reordering requires a different primitive (`Executor.Job.Priority`, or a new bucketed structure) |
| `Executor.Job.Priority` keyed by deadline, not priority | `swift-executor-primitives/…/Executor.Job.Priority.swift:45` [Verified: 2026-04-16] | Cannot reuse as a `TaskPriority`-ordered queue without repurposing or duplicating |
| Chase-Lev deque in `Stealing` is wait-free at owner | `work-stealing-scheduler-design.md` Q1 | A priority-ordered local structure would destroy that property |
| `executor-package-design.md` v1 toolkit mission: "complete, no-brainer, theoretical-perfect" | `executor-package-design.md` | "No-brainer" does not require matching stdlib's DefaultActor on every axis; it requires correctness under the priority-inversion bound and clean composition |

## Prior Art Survey

### Sha, Rajkumar & Lehoczky (1990) — Priority Inheritance Protocols

The paper — *Priority inheritance protocols: an approach to real-time
synchronization*, IEEE Transactions on Computers, 39(9), 1175–1185,
September 1990, [DOI: 10.1109/12.57058](https://ieeexplore.ieee.org/document/57058)
[Verified: 2026-04-16] — introduces **two** protocols for bounding priority
inversion:

- **Basic Priority Inheritance Protocol (PIP).** When a high-priority task
  waits for a resource held by a lower-priority task, the holder inherits the
  waiter's priority for the duration of the wait. The paper's body theorem
  bounds worst-case blocking of a task `T_h` to the cumulative duration of
  lower-priority critical sections that `T_h` may encounter (roughly, the sum
  over each lower-priority task of the longest critical section on a shared
  resource). Does *not* prevent deadlock.

- **Priority Ceiling Protocol (PCP).** Each resource has a static *ceiling*
  priority (the highest priority of any task that may lock it). A task can
  acquire a resource only if its own priority strictly exceeds the ceiling of
  every resource currently held system-wide. The abstract states the stronger
  bound directly [Verified: 2026-04-16 from IEEE Xplore abstract]:

  > The priority ceiling protocol solves this uncontrolled priority inversion
  > problem particularly well; it reduces the worst-case task-blocking time
  > to at most the duration of execution of a single critical section of a
  > lower-priority task. This protocol also prevents the formation of
  > deadlocks.

**Contextualization in Swift.** Swift actors are the natural analogue of a
resource. A task awaiting an actor-bound job is the analogue of a task
waiting for a resource. The stdlib's Darwin path implements PIP via the
pthread QoS lattice: `dispatch_lock_override_start_with_debounce` at
`Actor.cpp:1629` bumps the drainer thread to the awaiter's priority while
the actor is locked. PCP requires static knowledge of which jobs may run on
which actor — which Swift's dynamic dispatch does not provide without
whole-program scope.

**Implication for swift-executors.** The achievable bound is the PIP bound,
not the PCP bound. Options in §Analysis are all variants of PIP implemented
at different layers (thread-QoS, job-reordering, stealer-injection). Our
task is to pick layers consistent with each executor's structure.

### Darwin thread QoS primitives

- `<pthread/qos.h>:213–293` defines `pthread_override_qos_class_start_np` and
  `_end_np` [Verified: 2026-04-16]. The header states:

  > While overrides are in effect, the specified target thread will execute at
  > the maximum QOS class and relative priority of all overrides and of the
  > QOS class requested by the thread itself.

  The API is unprivileged, available `macos(10.10), ios(8.0)`, nestable, and
  returns an opaque `pthread_override_t` that must be freed with `_end_np`.
  An override only boosts a thread's scheduling priority; it has **no wake
  semantics** — per the header, it "expresses that an item of pending work …
  depends on the completion of the work currently being executed by the
  thread." A thread blocked on `pthread_cond_wait` stays blocked until
  signaled, and then runs at the elevated QoS [Verified: 2026-04-16].

- `dispatch_lock_override_start_with_debounce` is **not** a public Apple API
  and **not** in `swift-corelibs-libdispatch`; it is internal to Apple's
  closed-source libdispatch. Swift's stdlib calls it via a Darwin-only shim
  (`include/swift/Runtime/DispatchShims.h`), gated on
  `SWIFT_CONCURRENCY_ENABLE_PRIORITY_ESCALATION` and
  `__builtin_available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)`
  [Verified: 2026-04-16].

- **QoS inheritance on `dispatch_async`.** The rule is nuanced (the resolved
  QoS is the maximum of submitter QoS, queue QoS-floor, and block-captured
  QoS, subject to `DISPATCH_BLOCK_{ENFORCE,INHERIT}_QOS_CLASS`); see
  `dispatch_queue_attr_make_with_qos_class(3)`. This document does not rely
  on the exact rule. The narrower claim that this document does rely on is
  that **dedicated `pthread_create` threads do not participate in libdispatch
  QoS propagation** — they start at whatever QoS `pthread_attr_set_qos_class_np`
  set at creation and do not inherit submitter QoS across `enqueue`.

### Linux thread priority primitives

- `pthread_setschedparam(thread, SCHED_FIFO, …)` requires `CAP_SYS_NICE` or
  raised `RLIMIT_RTPRIO`. sched(7) [Verified: 2026-04-16]:

  > Before Linux 2.6.12, only privileged (CAP_SYS_NICE) threads can set a
  > nonzero static priority (i.e., set a real-time scheduling policy). Since
  > Linux 2.6.12, the RLIMIT_RTPRIO resource limit defines a ceiling on an
  > unprivileged thread's static priority for the SCHED_RR and SCHED_FIFO
  > policies.

  The default `RLIMIT_RTPRIO` on systemd-based distros is 0 (nonzero
  real-time priority denied).

- `setpriority(2)` nice floor for unprivileged callers is `20 − RLIMIT_NICE`
  (from getrlimit(2), [Verified: 2026-04-16]). Default `RLIMIT_NICE` on
  systemd-based distros is 0, giving a nice floor of +20 — so unprivileged
  callers can only set nice in `[0, 19]`. Beyond that, with autogroup
  enabled (default on various distros), sched(7) notes:

  > if autogrouping is enabled … employing setpriority(2) or nice(1) on a
  > process has an effect only for scheduling relative to other processes
  > executed in the same session.

  So even the permitted range is scoped to the session's CPU share, not
  system-wide priority.

- `sched_setattr` / `SCHED_DEADLINE` requires `CAP_SYS_NICE` per sched(7).

**Practical Linux upshot.** Any priority-raising strategy assumes failure by
default and must degrade to the "no-op, retain FIFO" branch. There is no
unprivileged userspace equivalent of `pthread_override_qos_class_start_np`.

### Tokio (Rust) — per-runtime granularity, no per-task priority

The multi-thread runtime's task `Header` struct at
`tokio/src/runtime/task/core.rs:168–194` (as of 2026-04-16 master)
[Verified: 2026-04-16] contains `state`, `queue_next`, `vtable`, `owner_id`,
`tracing_id` — no priority field. The stealer `Steal::steal_into` at
`scheduler/multi_thread/queue.rs` makes no priority decisions. The
`Runtime::Builder` exposes no per-task priority API; the idiomatic way to
express priority is to run separate Tokio runtimes with different worker
counts or different OS-level thread priorities (the latter being a user-land
pattern outside Tokio's API surface, not a Tokio feature).

### Go runtime — no goroutine priority

`type g struct` at `runtime/runtime2.go:471–596` (Go master HEAD)
[Verified: 2026-04-16] has no priority field. The scheduler is
preemption-based; fairness is driven by `_Gpreempted`, `preempt bool`, and
work-stealing, not by priority ordering. `runtime.LockOSThread`
(`proc.go:5637–5651`) pins a goroutine to its OS thread, after which a user
may `setpriority(2)` that thread — but this is a user-land idiom, not a
runtime-provided API.

### Java ForkJoinPool — no per-task priority

`ForkJoinTask.java` has zero occurrences of "priority"/"Priority"; there is
no per-task priority field [Verified: 2026-04-16]. `ForkJoinWorkerThread.java`
has no `setPriority` calls — workers use `Thread.NORM_PRIORITY` by default.
`ManagedBlocker` / `compensate` (`ForkJoinPool.java:1551, 2231, 2717`) handle
the "block without starving" problem orthogonally.

Doug Lea's paper ["A Java Fork/Join Framework"](https://gee.cs.oswego.edu/dl/papers/fj.pdf)
§3.2 does discuss worker-thread priority — but as a *back-off mechanism*, not
a per-task priority: a worker that fails to steal lowers its thread priority
and yields between attempts. This is a distinct mechanism; the paper does
not argue for or against per-task priority as a feature.

### .NET TPL ThreadPool — no per-task priority exposed

`Task.cs` mentions "priority" only in internal comments about blocking
recovery [Verified: 2026-04-16]. `ThreadPoolTaskScheduler.QueueTask` enqueues
via `ThreadPool.UnsafeQueueUserWorkItemInternal(task, preferLocal)` with no
priority path. `TaskCreationOptions.PreferFairness` forces the global queue
over the local LIFO; `LongRunning` spawns a dedicated thread. Internally,
`ThreadPoolWorkQueue` maintains a `highPriorityWorkItems` queue used by the
blocking-recovery path (`Task.cs:3157` calls
`TransferAllLocalWorkItemsToHighPriorityGlobalQueue` when a worker blocks),
but this is not exposed as a per-task priority API.

### libdispatch global queues — pool-selection by QoS

`_dispatch_root_queues[]` at `swift-corelibs-libdispatch/src/init.c:304–369`
defines **12 root queues** — six QoS classes (MAINTENANCE, BACKGROUND,
UTILITY, DEFAULT, USER_INITIATED, USER_INTERACTIVE) × two flavours
(non-overcommit, overcommit) [Verified: 2026-04-16]. QoS selection at
enqueue time is done by `dispatch_get_global_queue` (`init.c:376–396`) via
`_dispatch_qos_from_queue_priority`. Worker threads within each pool run at
the matching pthread QoS. There is no per-job reordering inside a pool.

### Pattern observations

| Pattern | Adopted by |
|---------|------------|
| No per-task priority field; pool-level QoS only | Tokio, Go, ForkJoinPool, .NET TPL, libdispatch global queues [all Verified: 2026-04-16] |
| Per-task priority with priority-ordered dispatch | None of the surveyed general-purpose runtimes |
| PIP via thread-QoS override on lock acquisition | Darwin Swift stdlib (via `dispatch_lock_override_start_with_debounce`); Apple libdispatch internals |
| PIP via auxiliary high-priority scheduler job | Swift stdlib `DefaultActorImpl` ("stealer job") |

**Per [RES-021] contextualization step.** Universal adoption of pool-level
QoS (not per-task priority) across surveyed runtimes is direct evidence the
per-task model is expensive and often ineffective. Swift is unusual in that
`TaskPriority` is surfaced to users and to the runtime's escalation
machinery, and cheap on Darwin because the whole pthread QoS apparatus is
thread-local and syscall-free. On Linux the apparatus does not exist without
privilege. Therefore the right default for swift-executors v1 is to track
the surveyed majority: pool-level QoS (set at thread creation), no per-task
reordering, with Darwin-only opt-in for thread-QoS override. Matching
stdlib's `DefaultActorImpl` "stealer job" is an actor-specific mechanism
implemented inside the runtime; reproducing it at the executor layer is not
required for our executors to be correct under the PIP bound, because the
bound is satisfied whenever *some* path — runtime-level or executor-level —
elevates the holder.

## Analysis

### Mechanisms

Four orthogonal mechanisms an executor may implement:

| Mechanism | Where it acts | Cost | Effect |
|-----------|---------------|------|--------|
| M1. Enqueue-time reordering | Insert into priority-ordered structure | O(log n) enqueue | Next-drained job is highest priority |
| M2. Drain-time selection | Scan pending for highest priority | O(n) per drain (or O(log n) via heap) | Same effect as M1, different locus |
| M3. Thread QoS bump | `pthread_override_qos_class_start_np` / `SetThreadPriority` | O(1) syscall on Darwin; requires `CAP_SYS_NICE` on Linux | Running job runs at elevated OS priority |
| M4. Auxiliary high-priority enqueue | Schedule extra processing job at new priority | O(1) extra job; visible overhang | OS-level thread pool drains the queue at the new priority (only meaningful for executors that dispatch *onto* a pool) |

For each executor, the question is which subset of {M1, M2, M3, M4} applies.

### Per-Executor Analysis

#### `Kernel.Thread.Executor.Polling` (single thread, single FIFO)

Structure: one OS thread, one `Executor.Job.Queue`, one
`Executor.Wait.Event.Source`. The thread's priority is set once at
construction.

| Mechanism | Applicable? | Notes |
|-----------|-------------|-------|
| M1 reorder | Technically possible (swap to `Executor.Job.Priority`-style) | Breaks FIFO contract; O(log n) on hot enqueue path |
| M2 select | As above | Same trade-off |
| M3 thread QoS bump | Yes on Darwin | On Linux: unprivileged in the direction `nice` → lower priority only; no cheap way to raise |
| M4 aux stealer | **N/A** — single-thread, no pool to dispatch onto |

Trade-off: reordering a single-thread FIFO buys nothing unless the thread's
QoS also matches the highest-priority job. Without M3, M1+M2 reorder the
sequence of work on a thread whose OS priority is fixed — the high-priority
job just runs *sooner on the same low-priority thread*, which the scheduler
sees as identical total priority.

**Initial recommendation.** M3-only, Darwin-only, opt-in via an
`Options.priorityTracking: Bool = false` construction flag. M1/M2 rejected
for v1 on FIFO-contract and hot-path-cost grounds. On Linux/Windows the
flag is a no-op; documented as such. The Polling executor continues to
honor FIFO; user code that needs priority-ordered dispatch composes
`Kernel.Thread.Executor.Sharded` with one shard per priority class, or
uses `DispatchQueue` directly.

#### `Kernel.Thread.Executor.Sharded` (N threads, per-thread FIFOs, round-robin assignment)

Structure: each shard is a Polling-like single-thread-with-FIFO; the
sharding layer picks which shard to enqueue onto.

| Mechanism | Applicable? | Notes |
|-----------|-------------|-------|
| M1 reorder (per-shard) | Same trade-off as Polling | Rejected per Polling reasoning |
| M2 select (per-shard) | Same | Rejected |
| M3 thread QoS bump (per-shard) | Yes on Darwin | Opt-in same as Polling |
| M4 aux stealer | **Requires a thread pool to re-dispatch onto** | N/A — we *are* the thread pool; no upstream to bump |

Additional consideration: **shard selection by priority.** The sharding
policy could select a shard by priority class (e.g., high-priority → shard
0, low-priority → shard N-1) with each shard thread running at the
corresponding OS QoS. This is libdispatch's design, and it composes
cleanly with M3: each shard thread has its own fixed QoS set at creation;
no per-job adjustment needed. Deferred to `numa-aware-sharding.md` because
the shard-selection policy is that document's territory; priority-sharding
is one option in that design space.

**Initial recommendation.** Identical to Polling (M3-only, Darwin, opt-in),
with shard-selection-by-priority deferred to the NUMA/sharding note as a
future policy option.

#### `Kernel.Thread.Executor.Stealing` (N threads, per-thread Chase-Lev deques)

Structure: each worker owns a Chase-Lev deque; idle workers steal from
peers. Per `work-stealing-scheduler-design.md` the deque is wait-free at
the owner; priority ordering would destroy this.

| Mechanism | Applicable? | Notes |
|-----------|-------------|-------|
| M1 reorder (per-deque) | **Rejected**: destroys Chase-Lev wait-free invariant |
| M2 select (per-deque) | **Rejected**: same reason |
| M3 thread QoS bump (per-worker) | Yes on Darwin; risk of QoS de-escalation oscillation on rapid steals |
| M4 aux stealer | Conceptually collides with existing "stealer" terminology. What it *would* mean: enqueue a duplicate job at a higher priority so that an idle worker picks it up faster. Not useful: idle workers steal anyway, and the Chase-Lev FIFO-at-stealer discipline already means oldest jobs migrate to new workers first |

An extra consideration: **stolen-job QoS inversion.** A high-priority job
enqueued onto worker 0 may be stolen by worker 1, which was running at a
low QoS. Without M3, the high-priority job now executes on a low-QoS
thread. With M3, worker 1 bumps its QoS when it starts the stolen job and
reverts on completion. This is the direct analogue of PIP.

**Interaction with the parked-worker wakeup path.** A worker parked on a
condvar (or futex) is *not* woken by `pthread_override_qos_class_start_np`
[Verified: 2026-04-16 from `<pthread/qos.h>` header]. The wakeup remains the
responsibility of the existing wakeup primitive in the idle policy (see
`work-stealing-scheduler-design.md` Q3). M3 only affects the QoS a thread
runs *at*, not whether it runs. That is why the two mechanisms are
complementary, not overlapping.

**Initial recommendation.** M3-only, Darwin-only, gated by the same
`Options.priorityTracking` flag. Worker threads start at a neutral QoS
(e.g., `QOS_CLASS_USER_INITIATED`, configurable); a worker issues
`pthread_override_qos_class_start_np` when it starts a job and `_end_np`
on completion. The wait-free deque invariant is preserved because priority
lives in the job metadata, not the deque structure.

Reconcile with `work-stealing-scheduler-design.md` Q5: Stealing is
`TaskExecutor`-only. The priority-tracking opt-in does not change this —
`TaskExecutor` jobs carry their own `ExecutorJob.priority`; we use it for
M3, not for actor dispatch.

#### `Executor.Scheduled<Base>` (deadline-ordered min-heap + base executor)

Structure: a min-heap of `(UnownedJob, deadline)` entries; a timer thread
pops when the head deadline is reached and hands the job to the base
executor. Priority is not part of the heap key.

| Mechanism | Applicable? | Notes |
|-----------|-------------|-------|
| M1 reorder | **Rejected**: deadline is the canonical order. Priority is meaningful only as tie-break for same-deadline jobs |
| M2 select | Same | Implicit: the heap already selects by deadline |
| M3 thread QoS bump | **Passes through** to base executor | Scheduled does not own workers; the base does |
| M4 aux stealer | N/A | Scheduled is a single-timer-thread dispatcher; no pool |

**The tie-break question.** Today `Executor.Job.Priority.schedule(_:at:)`
(`swift-executor-primitives/Sources/Executor Job Priority Primitives/Executor.Job.Priority.swift:45`
[Verified: 2026-04-16]) keys only on `deadline`. Same-deadline jobs break
ties by heap insertion order, not by `TaskPriority`. This is acceptable
because deadline dominates priority for a scheduled executor by
construction; users who care about priority for same-deadline work should
use the base executor's ordering (which is FIFO per above).

**Initial recommendation.** M1/M2/M4 rejected. M3 is the base executor's
concern, not Scheduled's. No changes required for v1; the escalation
contract is: the job's stored `ExecutorJob.priority` reflects the current
value at the moment the base executor sees it — the common path for every
executor.

Deferred to `scheduled-executor-policy.md`: whether `Executor.Job.Priority`
should gain a secondary key (`TaskPriority`) for same-deadline tie-break.

#### `Executor.Cooperative.runUntil` (caller-thread donation)

Structure: the caller synchronously donates its own thread by running a
job loop until a condition is met. No worker thread of its own.

| Mechanism | Applicable? | Notes |
|-----------|-------------|-------|
| M1 reorder | Trade-off as Polling | Under the donation model, the donator's pending work often *is* the priority signal — rejected for v1 |
| M2 select | Same | Rejected |
| M3 thread QoS bump | **The donator thread is not ours to bump.** An executor that bumps its caller's thread QoS and then returns without reverting is a bug magnet |
| M4 aux stealer | N/A — no pool |

The subtlety: the caller may already have the correct QoS (they are
running a high-priority task that chose to donate), in which case no bump
is needed. If they don't, bumping-and-reverting must bracket every job
execution — feasible, but the consequence of a revert failure is that the
caller's post-`runUntil` work runs at an elevated priority. That is
materially worse than the "no priority tracking" default.

**Initial recommendation.** M3 rejected. The Cooperative executor's
priority disposition *is* the caller's thread disposition; the runtime's
existing `swift_task_escalateImpl` Darwin path handles the "escalate the
thread currently running this task" case by structural invariant:
`swift_job_run` → `runJobInEstablishedExecutorContext` (`Actor.cpp:233`)
→ `task->flagAsRunning()` → `ActiveTaskStatus.withRunning(true)` →
`dispatch_lock_value_for_self()` (`TaskPrivate.h:616` [Verified:
2026-04-16]) — records `pthread_self()` into the task's `ExecutionLock`
for every job dispatched through `swift_job_run`, regardless of executor
type. After completion, `swift_dispatch_thread_reset_override_self`
(`Actor.cpp:241`) cleans up.

This is a **structural dependency on `swift_job_run`'s universal path**,
not a coincidence. It is also not a protocol contract — it is an
implementation detail. Document as: "Assumed runtime invariant: verify
per Swift release."

Coordinate with `cooperative-donation-contract.md`: the donation contract
must declare priority as "caller-owned, not executor-managed." That note's
scope subsumes this finding.

#### `Executor.Main` (main-thread executor)

Structure: on Darwin, dispatches onto `dispatch_get_main_queue()` which
participates in libdispatch QoS; on Linux/Windows, a condvar-pumped run
loop on the process's main thread.

| Mechanism | Applicable? | Notes |
|-----------|-------------|-------|
| M1 reorder | **Rejected**: main-thread contract is FIFO |
| M2 select | **Rejected**: same |
| M3 thread QoS bump | Darwin: libdispatch-provided. Linux/Windows: the main thread's QoS is set at process start and bumping it has app-level side effects |
| M4 aux stealer | N/A |

**Initial recommendation.** No explicit priority tracking. On Darwin,
libdispatch already handles it. On Linux/Windows, main-thread priority is
an application-level concern outside the executor's responsibility.

### Cross-cutting: escalation handlers

`withTaskPriorityEscalationHandler` (`Task+PriorityEscalation.swift:111`
[Verified: 2026-04-16]) lets user code observe an escalation event on a
specific task. The handler runs concurrently to the task's operation. This
is orthogonal to the executor — it fires on the runtime's escalation path,
independently of which executor the task runs on.

**Implication for swift-executors.** None direct. Our executors do not
register escalation handlers on jobs they hold; the runtime registers them
against tasks. A task running on our executor that uses
`withTaskPriorityEscalationHandler` gets correct behavior "for free."

No v1 API is needed to surface this; if a future v2 wanted "executor-level
observation of escalation events across all held jobs," it would require a
new runtime SPI that does not exist today.

## Theoretical Grounding

### The PIP bound (Sha, Rajkumar & Lehoczky 1990)

The basic Priority Inheritance Protocol bounds the blocking time of a
high-priority task by the sum of the longest critical-section durations
across lower-priority tasks that share a resource with it (Theorem in §III
of the 1990 paper). The PCP bound is stronger (a single critical section)
but requires static resource-ceiling assignment, which Swift's dispatch
cannot provide.

**For our executors.** The "resources" are actor-bound dispatch contexts
and the OS thread itself. A high-priority task's blocking time on a
Polling/Sharded executor is bounded by the longest currently-running job on
the executor (since we're FIFO, all pending jobs are "blocking" the new
one). Without M3, the running job executes at whatever priority the thread
started at; *with* M3, the running job is elevated to the highest pending
priority — which is exactly PIP.

The bound is respected as long as *some* layer — runtime-level via
`swift_task_escalateImpl`, executor-level via M3, or libdispatch-level via
QoS inheritance — propagates the priority to the actually-running thread.
The Darwin path has all three layers cooperating; the Linux path has none
above the runtime's (currently disabled) gate.

### FIFO head-of-line blocking latency model

Every thread-owning executor in v1 uses FIFO dispatch. M3 (thread QoS
bump) elevates the OS scheduling priority of the thread, satisfying the
PIP bound. But a high-priority task enqueued behind N low-priority tasks
waits for all N to complete — M3 does not reorder. Worst-case task
latency is `Σ duration(pending_job_i)`. For event-loop executors where
jobs are microsecond-scale, this is acceptable. For executors hosting
long-running jobs (millisecond-scale I/O, serialization), this could
be significant. Users needing priority-ordered dispatch should use
`DispatchQueue` (which implements priority-ordered actor drain) or a
future M1+M2 v2 extension.

### Live-mutated priority field — constraint on future M1/M2

`ExecutorJob.priority` is runtime-mutated via `swift_task_escalateImpl`
while the job sits in our queue. For FIFO this is harmless (order
doesn't change). Any future M1/M2 implementation (priority-ordered
queue) must handle invalidation or re-insertion when the stored priority
changes after enqueue — the priority field is not stable. This is a
structural constraint on v2 work, not a v1 concern.

### Why not full M1+M2 priority queues

The per-task cost is not the issue. The issue is that M1+M2 without M3
yields **no** priority-inversion bound improvement: the highest-priority
pending job runs sooner in our queue, but on the same thread at the same
OS priority, so the wall-clock moment at which it actually executes is
barely moved. The only benefit is microsecond-scale reordering within a
single executor's queue, which is dominated by scheduling noise. Our
executors' mission per `executor-package-design.md` is "no-brainer" — M1+M2
without M3 is machinery without payoff.

With M3 *plus* M1+M2, we approach stdlib's `DefaultActorImpl` semantics.
That is a legitimate future direction; the relevant open question is
whether users who want that reach for `DispatchQueue` or
`DefaultActorImpl` already, and whether adding a third API layered on our
executors would be a net win.

### What stdlib's "stealer job" actually is

`Actor.cpp:1632, 1638, 1723, 2147` describe scheduling a
`ProcessOutOfLineJob` at an elevated priority when an actor's enqueued
priority is bumped. The dispatch path is `scheduleActorProcessJob`
(`Actor.cpp:1526`), which either enqueues on a user-provided
`TaskExecutor` or, by default, `swift_task_enqueueGlobal` (the global
dispatch queue, i.e. libdispatch). This is M4 at the runtime level,
targeting a pool above the actor machinery. It works because libdispatch
then selects a QoS-appropriate thread. It does **not** work at our layer
because our executors *are* the pool — there is no global pool above us
that would re-dispatch at higher priority.

Equivalent generalization for us: if a worker thread is running at a lower
QoS than a pending job now requires, either **reassign the job to a worker
whose current QoS is sufficient** or **bump the running worker's QoS via
M3**. The second option is strictly simpler and is exactly what the
`pthread_override` API is designed for. This is further evidence for the
"M3-only, Darwin-only, opt-in" recommendation across the thread-owning
executors.

## Outcome

**Status:** `DECISION`.

### Locked recommendations

| Executor | Mechanism | Platform | Default |
|----------|-----------|:---:|:---:|
| `Polling` | M3 (thread QoS bump) | Darwin | off; opt-in via `Options.priorityTracking` |
| `Sharded` | M3 per shard | Darwin | off; opt-in |
| `Stealing` | M3 per worker, bump at job-start / revert at job-end | Darwin | off; opt-in |
| `Scheduled` | pass-through to base executor | N/A | N/A |
| `Cooperative` | none; caller owns QoS | N/A | N/A |
| `Main` | libdispatch-provided on Darwin; none elsewhere | Darwin via libdispatch | always on via libdispatch |

Across all thread-owning executors: **no M1, no M2, no M4 in v1**. Priority
tracking is a Darwin-only thread-QoS bump, off by default.

### Rationale summary

1. M1+M2 without M3 buys nothing measurable; adding the priority-queue
   primitive to swift-executor-primitives would be machinery serving a
   non-goal.
2. M3 is cheap on Darwin (853 ns/cycle per spike;
   `pthread_override_qos_class_start_np`, unprivileged per
   `<pthread/qos.h>:213–293`), unreliable on Linux
   (`CAP_SYS_NICE` required for real-time classes; unprivileged nice bound
   is `20 − RLIMIT_NICE`, effectively `[0, 19]` on default systemd distros;
   autogroup further restricts nice's scope to per-session CPU share).
   Making it opt-in keeps Darwin users from being surprised by a wall of
   failed `pthread` calls on Linux in v1. Linux-capable M3 is a v2 story
   once the `embedded-swift-scoping.md` and Linux-capability-probing
   design is established.
3. M4 is a runtime-level mechanism that depends on a pool above the
   executor. Our executors *are* the pool; M4 has no generalization here.

### Validated by spike (2026-04-16)

`Experiments/priority-override-spike/` — 3 variants, ALL PASS on
Apple Swift 6.3 / macOS 26 arm64:

- **V1 (nesting):** 3 overrides at different QoS classes started and
  ended in non-LIFO order (C, A, B). All `_end_np` calls returned 0.
  Confirms any-order teardown, not stack-like.
- **V2 (rapid cycle):** 100k start/end cycles in 85.4 ms — **853
  ns/cycle (< 1 µs)**. Validates per-job-use viability.
- **V3 (cross-thread non-wake):** Override applied to a condvar-parked
  worker thread. Worker did NOT wake from the override alone; only woke
  on `pthread_cond_signal`. Confirms override and wakeup are independent
  mechanisms, matching `<pthread/qos.h>:220–223`.

**Lifecycle finding:** `_end_np` MUST be called while the target thread
is alive. Calling after `pthread_join` returns ESRCH (3). For the
executor M3 pattern this is inherently satisfied: override starts at
job-start and ends at job-end; the worker thread outlives both by
construction.

**Swift bridge note:** `pthread_override_t` imports as non-optional
`OpaquePointer` in Swift. The C NULL-return case (if any) would crash
at the Swift bridge; for valid threads and QoS classes, failure is not
expected. Production code should not nil-check.

### Locked surface (2026-04-16)

The v1 opt-in flag is **`priorityTracking: Bool`**, default **`false`**,
exposed as a stored property on each thread-owning executor's `Options`
struct. Locked across `Kernel.Thread.Executor.{Sharded,Stealing}.Options`;
`Kernel.Thread.Executor.Polling` currently constructs via direct
parameters, so the flag lands as an init parameter with the same name,
type, and default until a `Polling.Options` struct is introduced.

```swift
// Sharded and Stealing
public struct Options: Sendable {
    public var count: Kernel.Thread.Count
    public var priorityTracking: Bool = false
    public init(count: Kernel.Thread.Count? = nil, priorityTracking: Bool = false)
}

// Polling (no Options struct yet)
public init(
    source: consuming Kernel.Event.Source,
    maxEventsPerPoll: Int = 256,
    priorityTracking: Bool = false,
    tick: sending @escaping ... -> Outcome
)
```

**Semantics (per platform).** When `priorityTracking` is `true`,
each worker thread brackets job execution with the platform's
`Kernel.Thread.Priority.Override` per
`qos-bracketing-platform-layering.md` v2.0.0 (RECOMMENDATION):

1. **Darwin** — `pthread_override_qos_class_start_np` at job-start,
   `pthread_override_qos_class_end_np` at job-end. Full override
   semantics: nestable, deinit-ends, ~853 ns/cycle (spike-validated
   2026-04-16).
2. **Linux** — `setpriority(PRIO_PROCESS, gettid(), nice)` save-restore.
   Lowering (utility, background) succeeds unprivileged. Raising
   (default and above) requires `CAP_SYS_NICE` and silently no-ops
   without it. Best-effort contract documented at the L3-unifier API.
3. **Windows** — `SetThreadPriority(GetCurrentThread(), priority)`
   with `GetThreadPriority` save-restore. Unprivileged within the
   process's priority class.
4. **Embedded** — **no-op** (no OS thread-priority concept; see
   `embedded-swift-scoping.md`).
5. **FreeBSD / other POSIX** — `Linux.Kernel.Thread.Priority.Override`
   may be reused if setpriority semantics match; otherwise no-op until
   a per-platform L3-policy is added.

**Documentation tone requirement (revised v0.8.0).** DocC on
`priorityTracking` MUST state per-platform semantics honestly. No
platform is described as no-op; Linux's asymmetric ceiling is
called out explicitly. A concrete template:

> /// Enables per-job thread-priority tracking.
> ///
> /// When `true`, each worker thread's OS-level priority is bumped
> /// to match the current job's priority for the duration of job
> /// execution, then reverted at job-end. This is the M3 mechanism
> /// of the priority-inversion policy
> /// (`Research/priority-escalation-policy.md`); it implements the
> /// PIP bound for the running job.
> ///
> /// **Per-platform behaviour:**
> /// - **Darwin:** `pthread_override_qos_class_start_np` /
> ///   `_end_np`. Full override semantics, nestable, sub-µs cost.
> /// - **Linux:** `setpriority(2)` save-restore on the calling
> ///   thread's tid. Lowering (utility, background) succeeds
> ///   unprivileged; raising (default and above) requires
> ///   `CAP_SYS_NICE` and silently no-ops without it.
> /// - **Windows:** `SetThreadPriority` save-restore. Unprivileged
> ///   within the calling process's priority class.
> /// - **Embedded:** No-op. No OS thread-priority concept.
> ///
> /// See `qos-bracketing-platform-layering.md` for the layering
> /// rationale and per-platform contract.
> ///
> /// Default: `false` for v1. Will default to `true` on all
> /// supported platforms in v2 once the override lifecycle is
> /// validated in production.

**Rationale for the surface.**

- Single `Bool` rather than a `PriorityTrackingPolicy` enum: the
  mechanism space collapsed to {off, M3} after rejecting M1/M2/M4.
  An enum would advertise choices that do not exist.
- `Options`-level rather than per-enqueue: per-enqueue control would
  require the executor to branch on each job, re-reading the flag; the
  Options field lets construction-time branching produce a specialized
  drain path.
- Shared name across executors: one mental model, one audit site. A
  future v2 that adds per-executor policies can diverge at that point.
- `priorityTracking` (not `priorityInversion` or `qosTracking`): the
  mechanism is broader than just inversion mitigation (it also tracks
  escalation from `Task.escalatePriority`); "tracking" captures both.

### Next steps before promotion to DECISION

1. ~~**Lock the `Options.priorityTracking` flag surface.**~~ **DONE** —
   see "Locked surface" subsection above. Flag name, type, default,
   per-platform no-op contract, and documentation template all recorded.
2. ~~**Prototype the Darwin M3 path.**~~ **DONE** —
   `Experiments/priority-override-spike/` CONFIRMED on Swift 6.3 / macOS
   26 arm64. Nesting, sub-µs cost, and cross-thread non-wake all
   validated. Linux null-op behavior needs no spike.
3. ~~**Coordinate with `work-stealing-scheduler-design.md`**~~ **DONE** —
   that DECISION-status note's Q3 (idle policy) is orthogonal to M3:
   spike V3 confirmed a parked worker is NOT woken by a QoS override,
   so the wakeup primitive in Q3 remains the sole wake channel. No
   amendment required; the cross-reference lives in this note only,
   matching the mutual-defer pattern with `scheduled-executor-policy`.
4. ~~**Coordinate with `scheduled-executor-policy.md`**~~ **DONE** —
   that note rejects `TaskPriority` as a secondary key for v1, matching
   our "no priority tracking in v1" recommendation. Mutual-defer
   recorded.
5. ~~**Coordinate with `cooperative-donation-contract.md`**~~ **DONE** —
   that DECISION-status note states "caller-owned priority" as part of
   the donation contract (the caller's thread runs jobs at its own QoS,
   not an executor-managed one). M3 does not apply to Cooperative
   because the thread is not ours to bracket. Cross-reference lives in
   Cooperative's analysis section ("`Executor.Cooperative.runUntil`")
   below; no amendment to the DECISION note required.
6. ~~**Resolve the Linux thread-QoS story for v2** (not v1).~~
   **DONE for v1** as of 2026-04-29. Per
   `qos-bracketing-platform-layering.md` v2.0.0 (RECOMMENDATION) and
   the principal directive "all our packages MUST support darwin,
   linux, windows equally", Linux M3 is in v1 scope with
   best-effort semantics: `setpriority(2)` on the calling thread's
   tid; lowering (utility / background) succeeds unprivileged;
   raising (default and above) requires `CAP_SYS_NICE` and silently
   no-ops without it. The wrapper is `Linux.Kernel.Thread.Priority.Override`
   in swift-linux (L3-policy). Same direction for Windows, which
   gets `Windows.Kernel.Thread.Priority.Override` via
   `SetThreadPriority`/`GetThreadPriority` save-restore. The L1
   "no-op outside Darwin" contract from the v0.6.0 Locked Surface
   is superseded: priorityTracking now does meaningful work on all
   three platforms (modulo Linux's documented asymmetric ceiling).
7. **Flip `Options.priorityTracking` default to `true` on Darwin in
   v2.** The v1 default is `false` because the override lifecycle code
   is new. Once validated in production, v2 should default to `true` on
   Darwin (where the mechanism is cheap and unprivileged) and `false`
   elsewhere. Users who want Darwin priority-inversion mitigation in v1
   must set `Options.priorityTracking = true` explicitly. Deferred to
   v2 — not blocking DECISION.
8. **Implement the bracketed QoS override at the drain path.** Not
   blocking DECISION because the surface is locked and the mechanism
   is spike-validated. Implementation is a downstream follow-up:
   introduce `Polling.Options` (or keep the init parameter) and
   propagate `priorityTracking` through the worker loop. The
   **layering** of the syscall implementation is locked by
   `qos-bracketing-platform-layering.md` (RECOMMENDATION,
   2026-04-29): the `pthread_override_*_np` calls live at L2
   (swift-darwin-standard) as `Darwin.Kernel.Thread.Priority.Override`,
   with cross-platform unification at L3-unifier (swift-kernel) via
   `Kernel.Thread.Priority.Override` typealias / no-op struct, and
   swift-executors consumes the unified API with no `#if
   canImport(Darwin)` and no `import Darwin`. The
   originally-prescribed "gate behind `#if canImport(Darwin)` inside
   swift-executors" approach was superseded once the platform skill
   ([PLAT-ARCH-008a], [PLAT-ARCH-008c], [PLAT-ARCH-008d],
   [PLAT-ARCH-008h]) was applied — the M3 mechanism's substance
   (Darwin-only QoS bump, opt-in flag, no-op elsewhere) is unchanged;
   only the layering of where the syscalls live moves. See
   `qos-bracketing-platform-layering.md` for the full analysis.

### Escalation note

Per [RES-004b]: this analysis touches `swift-executor-primitives` (L1)
insofar as it decides *not* to add a `TaskPriority`-ordered primitive,
and `swift-executors` (L3) for the per-executor policies. Scope is
cross-package within `swift-foundations` + `swift-primitives`. No
escalation to `swift-institute` is required. Re-evaluate if the Embedded
interaction (pending in `embedded-swift-scoping.md`) changes the
Darwin-only recommendation.

## References

### Priority-inversion theory

- Sha, L., Rajkumar, R., & Lehoczky, J. P. (1990). [Priority inheritance
  protocols: an approach to real-time
  synchronization](https://ieeexplore.ieee.org/document/57058). *IEEE
  Transactions on Computers*, 39(9), 1175–1185. DOI: `10.1109/12.57058`.

### Platform QoS primitives

- `<pthread/qos.h>:213–293` (macOS SDK; Apple's public declaration of
  `pthread_override_qos_class_start_np` and `_end_np`).
- `dispatch_queue_attr_make_with_qos_class(3)` (Darwin man page) — the
  authoritative statement of QoS propagation semantics.
- [apple/swift-corelibs-libdispatch
  `src/init.c`](https://github.com/apple/swift-corelibs-libdispatch/blob/main/src/init.c) —
  `_dispatch_root_queues[]` definition (12 QoS-keyed root queues).
- Linux [sched(7)](https://man7.org/linux/man-pages/man7/sched.7.html),
  [pthread_setschedparam(3)](https://man7.org/linux/man-pages/man3/pthread_setschedparam.3.html),
  [setpriority(2)](https://man7.org/linux/man-pages/man2/setpriority.2.html),
  [getrlimit(2)](https://man7.org/linux/man-pages/man2/getrlimit.2.html),
  [sched_setattr(2)](https://man7.org/linux/man-pages/man2/sched_setattr.2.html).

### Swift runtime context (cited above)

- `swiftlang/swift` —
  [`stdlib/public/Concurrency/TaskStatus.cpp:993`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/TaskStatus.cpp)
  (`swift_task_escalateImpl`), `:1044` (Darwin thread-QoS override),
  `:1050–1057` (open TODO: "Add a stealer to escalate the thread request
  for the task").
- `swiftlang/swift` —
  [`stdlib/public/Concurrency/Actor.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Actor.cpp):
  `:1526` (`scheduleActorProcessJob`), `:1620–1644` (stealer job on
  priority override), `:1710–1728` (same path in `enqueueStealer`),
  `:2140–2174` (stealer race tolerance documentation).
- `swiftlang/swift` —
  [`stdlib/public/Concurrency/Task+PriorityEscalation.swift:46`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Task%2BPriorityEscalation.swift)
  (`Task.escalatePriority(to:)`), `:111`
  (`withTaskPriorityEscalationHandler`).
- `swiftlang/swift` —
  [`stdlib/public/Concurrency/PartialAsyncTask.swift:228–236`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/PartialAsyncTask.swift)
  (`ExecutorJob.priority` accessor).
- `swiftlang/swift` —
  [`include/swift/Runtime/DispatchShims.h`](https://github.com/swiftlang/swift/blob/main/include/swift/Runtime/DispatchShims.h)
  (declaration of `swift_dispatch_lock_override_start_with_debounce` shim).
- [SE-0462: Task Priority Escalation
  APIs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0462-task-priority-escalation-apis.md)
  (Konrad Malawski; no executor-protocol obligation).

### Production runtimes (pool-level QoS only)

- Tokio —
  [`tokio/src/runtime/task/core.rs`](https://github.com/tokio-rs/tokio/blob/master/tokio/src/runtime/task/core.rs)
  (task `Header` struct, no priority field).
- Go runtime —
  [`runtime/runtime2.go`](https://github.com/golang/go/blob/master/src/runtime/runtime2.go)
  (`type g struct`, no priority field);
  [`runtime/proc.go`](https://github.com/golang/go/blob/master/src/runtime/proc.go)
  (`LockOSThread`).
- Java `ForkJoinPool` —
  [`ForkJoinTask.java`](https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/util/concurrent/ForkJoinTask.java),
  [`ForkJoinPool.java`](https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/util/concurrent/ForkJoinPool.java);
  Lea, D., ["A Java Fork/Join
  Framework"](https://gee.cs.oswego.edu/dl/papers/fj.pdf) (workers adjust
  *thread* priority as an idle back-off; does not introduce per-task
  priority).
- .NET runtime —
  [`Task.cs`](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Private.CoreLib/src/System/Threading/Tasks/Task.cs),
  [`ThreadPoolTaskScheduler.cs`](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Private.CoreLib/src/System/Threading/Tasks/ThreadPoolTaskScheduler.cs).

### Internal references

- `executor-package-design.md` (locked taxonomy; mission statement)
- `work-stealing-scheduler-design.md` (coordination on Chase-Lev
  invariant, Q3 idle policy, Q5 `TaskExecutor`-only)
- `sync-handoff-to-actors.md` (precedent: decision-style document;
  channel-based handoff mechanism also avoids per-message priority
  questions)
- `scheduled-executor-policy.md` (coordination on tie-break question)
- `cooperative-donation-contract.md` (coordination on "caller-owned
  priority" declaration)
- `embedded-swift-scoping.md` (coordination on Embedded degradation)
- `qos-bracketing-platform-layering.md` (locks the implementation
  layering of Next Step #8 — pthread_override at L2, unified at
  L3-unifier, consumed at L3-domain with no platform conditionals)
- `executor-job-deadline-naming.md` (frees the `Priority` name from
  the deadline-keyed queue so the L1 typed `Executor.Job.Priority`
  enum from the layering doc can occupy it)

## Changelog

- **v0.8.0 (2026-04-29).** Next Step #6 closed for v1: Linux M3 no
  longer deferred to v2. Per `qos-bracketing-platform-layering.md`
  v2.0.0 and the principal directive "all our packages MUST support
  darwin, linux, windows equally", all three platforms have real
  L3-policy bracketing wrappers in v1: pthread_override on Darwin
  (full semantics), setpriority on Linux (best-effort lower-only
  unprivileged; full with `CAP_SYS_NICE`), SetThreadPriority on
  Windows (full save-restore). The v0.6.0 "no-op outside Darwin"
  contract on `priorityTracking` is superseded.
- **v0.7.0 (2026-04-29).** Next Step #8 amended: the
  `pthread_override_*` implementation layering is delegated to
  `qos-bracketing-platform-layering.md` (RECOMMENDATION). The M3
  mechanism's substance is unchanged; only the location of the
  syscall implementation moves from `#if canImport(Darwin)` inside
  swift-executors to L2 swift-darwin-standard with L3-unifier
  composition. Driven by application of the platform skill
  ([PLAT-ARCH-008a], [PLAT-ARCH-008c], [PLAT-ARCH-008d],
  [PLAT-ARCH-008h]) and the principal directive "all platform-specific
  code must be placed at L2 packages." References added to
  `qos-bracketing-platform-layering.md` and
  `executor-job-deadline-naming.md`.
- **v0.6.0 (2026-04-16).** DECISION reached. M3-only Darwin opt-in
  via `priorityTracking: Bool`; M1/M2/M4 rejected for v1; per-executor
  policies locked; spike-validated.
