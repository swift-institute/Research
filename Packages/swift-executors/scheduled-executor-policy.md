# Scheduled Executor Policy

<!--
---
version: 0.3.0
last_updated: 2026-04-16
status: DECISION
tier: 2
---
-->

## Context

`Executor.Scheduled<Base>` ships today at
`swift-foundations/swift-executors/Sources/Executors/Executor.Scheduled.swift`
as a thin wrapper over a base executor, with a timer thread that drives a
min-heap keyed on `ContinuousClock.Instant`. Several decisions from the
original design sketch in `executor-package-design.md` (lines 489–491) were
not yet locked when the class shipped [Verified: 2026-04-16]:

| Aspect | Design sketch | Shipped |
|--------|---------------|---------|
| `SchedulableExecutor` conformance | Yes | No |
| Enqueue signature | `after: C.Duration, tolerance: C.Duration?, clock: C` | `after delay: Duration` |
| Clock | `some Clock` | Hard-coded `ContinuousClock` |
| Tolerance | `Duration?` | Absent |
| Tiebreaker | Unspecified | Heap-order (undefined) |

The gap is not arbitrary: the v1 executor-package-design research
acknowledged these as open questions and deferred them to this note
(`executor-package-design.md:460, 467, 489–491` [Verified: 2026-04-16]).

The stdlib side of the question has moved. `SchedulingExecutor` is no
longer the `@_spi(ExperimentalCustomExecutors)` protocol the v1 handoff
brief described; it is a *public* protocol at
`StdlibDeploymentTarget 6.3`, declared at
`stdlib/public/Concurrency/Executor.swift:63–111` [Verified: 2026-04-16].
The SPI gate covers only the enclosing machinery (`RunLoopExecutor`,
`MainExecutor`, `ExecutorFactory`, `_createExecutors`, and the
`MainActor.executor` / `Task.defaultExecutor` setters at lines 559–624).

The shape of `SchedulingExecutor` is not frozen, however: **SE-0505
"Delayed Enqueuing for Executors"** — the proposal that formally defines
it — is *returned for revision*. Swift-Evolution PR #2654 ("Custom main
and global executors") is open and renames the protocol to
**`SchedulableExecutor`** in its pitched form. Both proposals are
unresolved as of 2026-04-16.

Non-conformance is not neutral. Every `Task.sleep` and clock-wait path in
the stdlib routes through `asSchedulingExecutor`:

- `ExecutorImpl.swift:96, 121, 128` — `swift_task_enqueueGlobalWithDelay`
  / `WithDeadline` force-unwrap
  `Task.defaultExecutor.asSchedulingExecutor!`.
- `SuspendingClock.swift:200, 213`, `ContinuousClock.swift:222, 235` —
  `Task.currentSchedulingExecutor` then `asSchedulingExecutor` on the
  found executor.
- `TaskSleep.swift:33, 277`, `TaskSleepDuration.swift:121` — same.
- `Executor.swift:741, 745, 749, 752` — `currentSchedulingExecutor` walk:
  active executor → preferred → current task → default, filtering via
  `asSchedulingExecutor` [all Verified: 2026-04-16].

The practical consequence: a task running on a `TaskExecutor` preference
of our `Executor.Scheduled<Base>` whose body calls `Task.sleep` will
*silently bypass* our scheduler and hit `Task.defaultExecutor` instead.
The scheduled executor becomes invisible for every clock-wait.

This document scopes five coupled decisions and records initial
recommendations. It reaches `DECISION` when (1) SchedulingExecutor
conformance is committed (with rename-migration strategy), (2) the
clock-generality question is resolved (prototype or type-erasure
decision), (3) tolerance semantics are locked, and (4) the same-deadline
tiebreaker is locked (coordinating with
`priority-escalation-policy.md`).

## Question

Lock the v1 policy for `Executor.Scheduled<Base>` along five axes:

1. **Dispatch policy.** Is the scheduled executor an EDF *scheduler* in
   the Liu–Layland sense (admission control + overrun isolation), or an
   earliest-deadline-first *dispatcher* that simply fires ready timers in
   deadline order? RM / fixed-priority variants?
2. **`SchedulingExecutor` conformance.** Conform today (accepting the
   future `SchedulableExecutor` rename) or stay independent?
3. **Clock generality.** Keep the hardcoded `ContinuousClock`, support a
   second hardcoded clock (`SuspendingClock`), or generalize to `some
   Clock` via type erasure or per-clock-kind heaps?
4. **Tolerance semantics.** Adopt the stdlib protocol's `tolerance:
   C.Duration?` parameter? What semantics (coalescing window, energy
   saving, or strict firing floor)?
5. **Same-deadline tiebreaker.** Undefined (current), FIFO via monotonic
   sequencer (Java STPE pattern), or `TaskPriority`-keyed (coordinating
   with `priority-escalation-policy.md`)?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| `SchedulingExecutor` is public, not SPI, `@available(StdlibDeploymentTarget 6.3, *)` | `Executor.swift:63–111` [Verified: 2026-04-16] | Conforming does not expose us to `@_spi(ExperimentalCustomExecutors)` ABI risk |
| SE-0505 defining `SchedulingExecutor` is *returned for revision*; PR #2654 renames to `SchedulableExecutor` | `swiftlang/swift-evolution` tree [Verified: 2026-04-16] | Conformance today carries a known rename migration |
| Non-conformance bypasses our executor for every `Task.sleep` | `ExecutorImpl.swift:96, 121, 128`; `SuspendingClock.swift:200, 213`; `ContinuousClock.swift:222, 235`; `TaskSleep.swift:33, 277`; `TaskSleepDuration.swift:121` [Verified: 2026-04-16] | Non-conformance is silently wrong, not just "missing a feature" |
| Default extension cross-dispatches `enqueue(..., after:, ...)` ↔ `enqueue(..., at:, ...)` | `Executor.swift:184–212` [Verified: 2026-04-16] | Only one implementation required |
| Current `Executor.Scheduled` uses hardcoded `ContinuousClock.Instant` throughout | `Executor.Scheduled.swift` (deadline type, timer loop, enqueue) [Verified: 2026-04-16] | Generalization to `some Clock` is a non-trivial refactor |
| `Executor.Job.Priority.Entry` has `{ deadline: ContinuousClock.Instant, job: UnownedJob }`, no priority field, no sequence number | `swift-executor-primitives/.../Executor.Job.Priority.Entry.swift` [Verified: 2026-04-16] | Tiebreaker requires an Entry-level change; scope includes L1 primitive |
| Stdlib `DispatchMainExecutor`, `DispatchGlobalTaskExecutor`, `CooperativeExecutor` all conform to `SchedulingExecutor` | `DispatchExecutor.swift:28, 81`, `CooperativeExecutor.swift:248` [Verified: 2026-04-16] | Established precedent: every stdlib-shipped scheduling executor conforms |
| Stdlib `Task.defaultExecutor.asSchedulingExecutor!` is force-unwrapped | `ExecutorImpl.swift:96` [Verified: 2026-04-16] | Being usable as a default executor *requires* conformance |
| Liu–Layland EDF optimality holds only under A1–A5 (periodic, deadline=period, independent tasks, constant run-time, preemptive single-processor) | [Liu & Layland 1973](https://dl.acm.org/doi/10.1145/321738.321743), §3 lines 109–120 [Verified: 2026-04-16] | Swift's tasks are sporadic and unbounded; the classical bound does not apply without admission control |
| Linux `SCHED_DEADLINE` requires `CAP_SYS_NICE` and admits only if `Σ(runtime/period) ≤ M CPUs`; EBUSY otherwise | sched(7), sched_setattr(2) [Verified: 2026-04-16] | OS-level EDF is inaccessible from unprivileged Swift apps; we cannot delegate downward |
| Darwin has no EDF class; `THREAD_TIME_CONSTRAINT_POLICY` is the closest analog (used by CoreAudio), not a general EDF scheduler | Darwin `mach/thread_policy.h` [Secondary-source confirmation, 2026-04-16] | Cross-platform EDF is not available even in principle |

## Prior Art Survey

### Liu & Layland (1973) — the foundational paper

[Scheduling Algorithms for Multiprogramming in a Hard-Real-Time
Environment](https://dl.acm.org/doi/10.1145/321738.321743), *Journal of
the ACM*, 20(1), 46–61. DOI: `10.1145/321738.321743` [Verified:
2026-04-16 from PDF via `pdftotext`].

Two policies, both proven optimal in their respective classes:

- **Rate-Monotonic (RM).** Static priority assignment with shorter-period
  tasks getting higher priority. **Theorem 5** [Verified verbatim,
  line 479–480]:

  > For a set of m tasks with fixed priority order, the least upper
  > bound to processor utilization is U = m(2^{1/m} − 1).

  The bound approaches `ln 2 ≈ 0.693` as `m → ∞` (§6 line 507). RM is
  optimum among fixed-priority assignments (Theorem 2, line 279).

- **Earliest Deadline First (EDF, "deadline driven").** Dynamic-priority
  assignment. **Theorem 7** [Verified verbatim, line 582–584]:

  > For a given set of m tasks, the deadline driven scheduling algorithm
  > is feasible if and only if (C₁/T₁) + (C₂/T₂) + … + (Cₘ/Tₘ) ≤ 1.

  EDF is optimum among *all* priority assignments (line 682–684):

  > the deadline driven scheduling algorithm is optimum in the sense
  > that if a set of tasks can be scheduled by any algorithm, it can be
  > scheduled by the deadline driven scheduling algorithm.

**Assumptions A1–A5** [Verified verbatim, §3 lines 109–120]: (A1)
periodic task arrivals, (A2) deadlines equal periods ("run-ability
constraints only"), (A3) independent tasks, (A4) constant per-task
run-time, (A5) non-periodic tasks are limited to init/recovery and do
not have hard deadlines. Zero switching cost is absorbed into `C_i`
rather than stated as a separate axiom (§3 lines 131–133).

**Contextualization in Swift** per [RES-021]. Swift `Task` arrivals are
not periodic (A1 violated), do not have bounded run-times known a priori
(A4 violated), and can depend on each other through structured
concurrency and actor isolation (A3 violated). Adopting Liu–Layland as
the dispatch rule without abandoning the theorem's assumptions is
category-incoherent. Applying EDF *dispatch* (fire earliest-deadline
first) without claiming Liu–Layland EDF's optimality bound is what every
surveyed production runtime does — see below.

### Linux `SCHED_DEADLINE` — the closest deployed Liu–Layland EDF

From sched(7) [Verified: 2026-04-16]:

> This policy is currently implemented using GEDF (Global Earliest
> Deadline First) in conjunction with CBS (Constant Bandwidth Server).

CBS (Abeni & Buttazzo, 19th IEEE RTSS 1998) adds overrun isolation — a
task that exceeds its declared `runtime` within a `period` is throttled
rather than permitted to steal bandwidth from other deadline tasks.
`struct sched_attr` carries `{ sched_runtime, sched_deadline,
sched_period }` [verbatim from sched_setattr(2)]. Admission control:

> The kernel thus performs an admittance test when setting or changing
> SCHED_DEADLINE policy and attributes. This admission test calculates
> whether the change is feasible; if it is not, sched_setattr(2) fails
> with the error EBUSY.

Capability requirement: **`CAP_SYS_NICE`** (sched(7)). Real-world
deployment is effectively research/specialist-grade — LWN tutorials
(Articles/743740, 743946) are pedagogical; no mainstream consumer
application ships a hard dependency. Stable kernel feature since 3.14
(2014).

**Contextualization.** Even if we wanted to delegate scheduling to
`SCHED_DEADLINE`, an unprivileged Swift application cannot open that
interface. Embedded Swift has no equivalent. Cross-platform
Liu–Layland-faithful EDF is not available at any OS layer we can
target.

### Darwin — no EDF equivalent

No Darwin scheduling class provides EDF. The closest primitive is
`THREAD_TIME_CONSTRAINT_POLICY` via `thread_policy_set`, carrying
`{ period, computation, constraint, preemptible }` — used by CoreAudio
for real-time audio threads. It is a priority-boost + quantum-shape
mechanism, not an EDF scheduler with admission control. `DISPATCH_WALLTIME`
is a wall-clock absolute-time reference for `dispatch_after`, not a
scheduling-class primitive.

### Java `ScheduledThreadPoolExecutor` — the closest language precedent

OpenJDK implementation: `DelayedWorkQueue`, a binary min-heap keyed by
`ScheduledFutureTask.compareTo`. Ordering is **deadline first, then FIFO
via a monotonic `AtomicLong sequencer`** [Verified: 2026-04-16 from
`ScheduledThreadPoolExecutor.java:183, 253–267`]:

```java
private static final AtomicLong sequencer = new AtomicLong();
...
public int compareTo(Delayed other) {
  long diff = time - x.time;
  if (diff < 0) return -1;
  else if (diff > 0) return 1;
  else if (sequenceNumber < x.sequenceNumber) return -1;
  else return 1;
}
```

No task priority on the timer itself. Same-deadline ordering is strictly
FIFO by enqueue. Heap implementation at
`DelayedWorkQueue.siftUp / siftDown` (`ScheduledThreadPoolExecutor.java:951, 969`).

### Tokio timer (Rust)

Hierarchical hashed timing wheel: 6 levels × 64 slots, 1 ms base
resolution, ~2 yr range [Verified: 2026-04-16 from
`tokio/src/runtime/time/wheel/mod.rs:22–48`]:

```rust
/// * 1 ms slots / 64 ms range
/// ...
/// * ~ 12 day slots / ~ 2 yr range
const NUM_LEVELS: usize = 6;
pub(super) const MAX_DURATION: u64 = (1 << (6 * NUM_LEVELS)) - 1;
```

Each slot is an intrusive `EntryList`. Ordering within a 1 ms slot is
unspecified; no priority field, no tolerance parameter.

### Go `time.AfterFunc` / `Timer` / `Ticker`

Per-P **4-ary min-heap** keyed on `when` [Verified: 2026-04-16 from
`runtime/time.go:1343, 167–179`]:

```go
const timerHeapN = 4
...
case tw.when < other.when: return true
case tw.when > other.when: return false
default: return tw.timer.rand < other.timer.rand  // only under fake time
```

Same-deadline order is effectively insertion/heap-index determined in
real time; the random tiebreak only applies under the test harness's
fake-time clock. No task priority on timers, no tolerance parameter.

### libdispatch `dispatch_source_t` timer

Per-`(clock, QoS-class)` bucket, each with a `dispatch_timer_heap_s`
(per `swift-corelibs-libdispatch/src/source.c:681–684`) drained by the
workloop. The heap is armed via **`EVFILT_TIMER` kevents**, with QoS
encoded as `NOTE_CRITICAL` / `NOTE_BACKGROUND` fflags
(`src/event/event_kevent.c:64–77, 98, 125–126, 610`) [Verified:
2026-04-16].

**The only surveyed precedent for a tolerance parameter.**
`dispatch_source_set_timer(ds, start, interval, leeway)` caps leeway at
`interval / 2` (`src/source.c:1218–1219`) and stores
`dtc_timer.deadline = target + leeway` (`src/source.c:1225–1226, 1281`).
Swift stdlib's `SchedulingExecutor.tolerance: C.Duration` derives from
this lineage.

### Pattern observations

| Runtime | Data structure | Tiebreaker | Tolerance | Liu–Layland EDF? |
|---------|----------------|------------|:---:|:---:|
| Java `ScheduledThreadPoolExecutor` | Binary min-heap | Monotonic FIFO sequencer | No | No |
| Tokio | Hashed timing wheel (6×64, 1 ms) | Unordered within slot | No | No |
| Go | 4-ary min-heap | Insertion order (real time) | No | No |
| libdispatch timer | Per-(clock,QoS) heap + EVFILT_TIMER | — | Yes (leeway ≤ interval/2) | No |
| Linux `SCHED_DEADLINE` | GEDF + CBS | Deadline | Admission (EBUSY) | Yes (OS-level) |

**Per [RES-021] contextualization.** Every surveyed general-purpose
runtime implements earliest-deadline-first *dispatch* against an ordered
structure, without admission control or overrun isolation. The only
Liu–Layland-faithful implementation is an OS scheduling class that
requires privileged capabilities. The right default for
`Executor.Scheduled<Base>` is to match the surveyed majority: EDF
dispatch with the best tiebreaker of the group (Java STPE's FIFO
sequencer), the only existing tolerance precedent (libdispatch's
leeway), and explicit non-claims about Liu–Layland optimality.

## Analysis

### Q1: Dispatch policy (EDF / RM / fixed-priority)

| Option | Description | Applicability |
|--------|-------------|---------------|
| A. **EDF dispatch** | Earliest-deadline-first, no admission control, no overrun isolation | Matches Java STPE, Tokio, Go, libdispatch |
| B. RM | Shorter-period first, fixed priority | Requires period information; we have only a single deadline per enqueue |
| C. Fixed-priority | `TaskPriority`-ordered | Priority is a runtime-mutated field (escalation); priority queue invalidates on every escalation |
| D. Fixed-priority + deadline | Lexicographic (priority, deadline) | Same priority-mutation issue; collapses to D on tie |
| E. Liu–Layland EDF scheduler | EDF dispatch + admission + overrun isolation | Requires WCET and period per task; Swift tasks provide neither |

**Initial recommendation: A.** The current code already implements A (as
"earliest deadline wins, ties undefined"). Upgrading to a
Liu–Layland-faithful EDF scheduler would require per-task WCET and
period, neither of which Swift's task model provides. RM is
inappropriate because Swift tasks are not periodic.

Locking this also means **the research note and documentation must not
claim "EDF" without the "dispatch" qualifier.** Liu–Layland EDF is a
precise technical term and our executor does not meet it.

### Q2: `SchedulingExecutor` conformance

| Option | Pros | Cons |
|--------|------|------|
| **A. Conform** | Visible to `asSchedulingExecutor` walks; `Task.sleep` on this executor works; matches stdlib precedent (Cooperative, Dispatch) | Tracks SE-0505 revision + PR #2654 rename |
| B. Don't conform | Zero stdlib ABI coupling | Silently bypassed on every `Task.sleep`; inconsistent with executor-package-design.md sketch |
| C. Conform behind SPI flag | Conservative | Conformance is binary at callsite — SPI flag doesn't help the stdlib walk |

**Initial recommendation: A.** The stdlib's `asSchedulingExecutor`
filter is not cosmetic — it is the single dispatch point for every
`Task.sleep` and clock-wait path. Non-conformance means our
`Executor.Scheduled<Base>` is invisible to the very workload it is built
for.

The rename from `SchedulingExecutor` → `SchedulableExecutor` (PR #2654)
is a one-line source break resolvable with a local typealias or a
version-gated extension; this is not an ABI-stable crystallization risk.
Override `asSchedulingExecutor` to `self` per the documented fast-path
convention, avoiding the runtime cast.

**Implementation finding (2026-04-16):** `SchedulingExecutor` is absent
from the macOS 26.4 SDK `.swiftinterface` — only `Executor`,
`SerialExecutor`, and `TaskExecutor` ship. The protocol exists in stdlib
source (`Executor.swift:64`) but is not included in the compiled binary
interface. Same root cause affects `RunLoopExecutor` and
`MainExecutor`. External packages cannot conform until the protocol
ships. Concrete `enqueue(_:after:)` methods matching the protocol
signature are implemented on `Executor.Cooperative` and
`Executor.Main` (non-Darwin); formal conformance is a one-line addition
when the gate lifts. This finding does NOT change the recommendation
(still A — conform) but defers the implementation timeline.

### Q3: Clock generality

| Option | Description | Cost |
|--------|-------------|------|
| A. Keep hardcoded `ContinuousClock` | Status quo | `SchedulingExecutor` conformance requires converting arbitrary `C.Instant` to `ContinuousClock.Instant` — unsound across clock differences (e.g., `SuspendingClock` pauses while device is suspended) |
| B. Hardcode a second clock (`SuspendingClock`) | Two heaps + two timer threads | Doubles resource cost; covers ~99 % of use; tractable |
| C. Generic over `some Clock` via type erasure | Storage holds `(any Clock, Instant)` pair | Dynamic dispatch per tick; single timer thread cannot wait on arbitrary clocks without polling |
| D. Per-clock-kind heap, opened lazily | Timer thread per observed clock kind | libdispatch pattern; lowest ongoing cost once warm, higher steady-state complexity |

**Initial recommendation: B for v1, C/D deferred.** `ContinuousClock`
and `SuspendingClock` cover the two stdlib-concrete clocks. Any other
clock is user-defined and rare. Two timer threads, each waiting on the
matching clock's condition, is a small multiplier on a system already
paying for one timer thread. Option (A) alone cannot satisfy
`SchedulingExecutor` soundly because a `SuspendingClock` deadline that
arrives while the device is suspended cannot be converted to a valid
`ContinuousClock.Instant` without drift.

Promotion to C or D requires a dedicated spike under
`Experiments/scheduled-clock-erasure-spike/` to measure the dynamic-
dispatch tax. Deferred.

### Q4: Tolerance semantics

libdispatch's `leeway` is the only existing precedent. Adopting:

- Semantics: the timer thread may fire the job any time in
  `[deadline, deadline + tolerance]`. Tolerance defaults to `nil`
  (no coalescing; strict firing at `deadline`).
- Drain discipline: when the timer wakes at or after the head deadline,
  drain every entry whose deadline is ≤ `now + tolerance(head)` in one
  batch, reducing wakeups under bursty schedules.
- `nil` vs `Duration.zero`: `nil` means "the caller declines to allow
  batching"; the stdlib's protocol lets us use `nil` as the precise
  "strict" sentinel.

**Initial recommendation: adopt `tolerance: C.Duration?`** as the
`SchedulingExecutor` protocol specifies. Default `nil`. Document the
batching semantics explicitly: deadline is a *lower* bound on fire
time; tolerance is the *upper slack*. No leeway/interval cap (we don't
have the libdispatch interval model).

### Q5: Same-deadline tiebreaker

| Option | Precedent | Cost |
|--------|-----------|------|
| A. Undefined (heap-order) | Current | Zero-cost; observably non-deterministic |
| **B. FIFO via monotonic sequencer** | Java STPE | One additional `UInt64` per Entry; one `AtomicSequence` on the executor |
| C. TaskPriority-keyed | stdlib DefaultActor `prioritizedJobs` | Requires Entry change + priority field; coordinates with `priority-escalation-policy.md`, which defers here |
| D. Insertion-order within millisecond bucket | Tokio | Incompatible with our heap structure |

**Initial recommendation: B, FIFO via monotonic sequencer.** Java STPE
is our closest structural analog (binary heap + sequencer) and the
guarantee is straightforward to reason about: among entries with
identical deadlines, earlier `schedule(_:at:)` calls fire first. The
sequencer is a single atomic-increment per enqueue; cost is below
measurement threshold on the timer-thread hot path.

Reject C for v1. Priority-keyed tiebreaking would require storing
`JobPriority` on `Executor.Job.Priority.Entry`, promoting the L1
primitive's ABI. Per `priority-escalation-policy.md` v0.2.1 the
executors do not track priority in v1; making it the secondary key here
contradicts that decision. Revisit in v2 when the full priority story
is reopened.

## Theoretical Grounding

### What Liu–Layland gives us and what it does not

Theorems 5 and 7 of the 1973 paper bound utilization under their
periodic-task model: RM admits utilization up to `m(2^{1/m} − 1)`, EDF
admits utilization up to 1. These bounds do not apply to our
executor because the bounds are about **schedulability** — whether a
given task set can meet all deadlines under the policy — and Swift's
task model is sporadic, not periodic. Neither WCET `C_i` nor period
`T_i` is available to our executor.

What Liu–Layland *does* give us: the proof that if every task is
periodic with `C_i / T_i ≤ 1`, then earliest-deadline-first dispatch
meets all deadlines. Our code observes this property in reverse: if a
hypothetical deadline set is over-utilized, EDF dispatch will still
order firings by deadline; it just cannot prevent misses. Documentation
should make this explicit: "EDF dispatch, not EDF scheduling; no
admission control."

### Why admission control is out of scope

Admission control would require the executor to reject a
`schedule(_:at:)` call that cannot be met without causing other
deadlines to be missed. Rejection needs:

1. Utilization accounting per task (C_i, T_i).
2. A system-wide bandwidth cap (the `M` in SCHED_DEADLINE).
3. A rejection error path on `enqueue`.

None of these fit the stdlib `SchedulingExecutor` protocol's
contract, which has no rejection mechanism. Adding admission control
would require a protocol extension — outside swift-executors scope.

### Dispatch-only correctness is sufficient for the workload

The workloads `Executor.Scheduled<Base>` serves — `Task.sleep`,
debounce, retry-with-backoff, cron-like periodics — do not have hard
deadlines; they have soft ones. Every missed deadline manifests as
"the task ran a few ms later than asked," not as system failure. EDF
dispatch is the right policy for soft deadlines; Liu–Layland EDF is
the policy for hard ones. We are in the soft-deadline regime.

## Outcome

**Status:** `DECISION`.

### Locked recommendations

| Question | Decision |
|----------|----------|
| Q1: Dispatch policy | EDF dispatch (no admission control, no overrun isolation); documentation must not claim "EDF" without the "dispatch" qualifier |
| Q2: `SchedulingExecutor` conformance | Conform; override `asSchedulingExecutor` to `self`; track PR #2654 rename |
| Q3: Clock generality | Two hardcoded clocks (`ContinuousClock` + `SuspendingClock`) for v1; generic-over-`some Clock` deferred pending spike |
| Q4: Tolerance | Adopt `tolerance: C.Duration?` per stdlib protocol; default `nil`; drain batch within `[deadline, deadline + tolerance]` |
| Q5: Tiebreaker | FIFO via monotonic sequencer (Java STPE pattern); TaskPriority tiebreak rejected for v1 |

### Rationale summary

1. Every surveyed production runtime — Java STPE, Tokio, Go, libdispatch
   — implements EDF dispatch without admission control. The Liu–Layland
   EDF scheduler exists only at OS scheduling-class level
   (`SCHED_DEADLINE`, `CAP_SYS_NICE`-gated). Our role is dispatch, not
   scheduling.
2. Conforming to `SchedulingExecutor` is mandatory for `Task.sleep`
   visibility, not optional. The rename risk is bounded (one typealias).
3. Two-clock support covers the two concrete stdlib clocks; third-party
   clocks remain a spike-gated v2 question.
4. Tolerance follows libdispatch's lineage, the only prior art. Default
   `nil` keeps current semantics for callers that don't opt in.
5. FIFO sequencer matches Java STPE and resolves the "undefined"
   semantics without coupling to the priority story that
   `priority-escalation-policy.md` already resolved as "executors do not
   track priority in v1."

### Locked rename-migration strategy (2026-04-16)

PR #2654 renames `SchedulingExecutor` → `SchedulableExecutor`. The
protocol is currently absent from the macOS 26.4 SDK `.swiftinterface`
(SDK finding, above), so no conformance ships today. When the protocol
ships — whether under the current name or the renamed one — the
conformance lands behind a **compiler-version gate**, not a runtime
gate. Locked idiom:

```swift
#if compiler(>=6.4) && hasFeature(SchedulableExecutor)
extension Executor.Scheduled: SchedulableExecutor {
    public func enqueue(
        _ job: consuming ExecutorJob,
        at instant: ContinuousClock.Instant,
        tolerance: ContinuousClock.Duration? = nil,
        clock: ContinuousClock
    ) { ... }

    public func asSchedulingExecutor() -> (any SchedulingExecutor)? { self }
}
#elseif compiler(>=6.3) && hasFeature(SchedulingExecutor)
extension Executor.Scheduled: SchedulingExecutor {
    public func enqueue(
        _ job: consuming ExecutorJob,
        at instant: ContinuousClock.Instant,
        tolerance: ContinuousClock.Duration? = nil,
        clock: ContinuousClock
    ) { ... }

    public func asSchedulingExecutor() -> (any SchedulingExecutor)? { self }
}
#endif
```

**Rationale.**

- **`hasFeature` + `compiler` double-gate:** the `hasFeature` check
  responds to the actual stdlib surface (feature flag present iff the
  protocol ships); the `compiler` floor prevents parser errors on
  older toolchains where the feature flag name itself is unrecognized.
  Matches the pattern stdlib uses for SE-gated APIs
  (e.g., `hasFeature(NonescapableTypes)`).
- **Two arms rather than one fallback:** when the rename lands in 6.4,
  6.3 clients still need the old-name conformance to remain valid on
  6.3 toolchains. The two `#elseif`-separated arms keep both working
  until the 6.3 support window closes.
- **No runtime typealias:** a `public typealias SchedulingExecutor = SchedulableExecutor`
  at the swift-executors layer would shadow the stdlib protocol and
  produce confusing diagnostics ("two types named …"). Source migration
  is a compile-time concern and belongs in compile-time conditionals.
- **Feature-flag names TBD:** the concrete `hasFeature(…)` spelling
  depends on the feature flag(s) Apple ships with the protocol. The
  sample above uses the protocol names as placeholders. Pattern
  validated against `Synchronization.Mutex`'s feature gating
  (`hasFeature(SuppressedAssociatedTypes)`); the exact spelling is
  recorded once the protocol lands in a tagged SDK.

**When to act.**

The conformance (and this gating idiom) land in a follow-up commit
when the protocol ships in the `.swiftinterface`. The research note
reaches DECISION with the idiom locked; implementation timing depends
on SDK evolution, not on this note.

### Validated by spike (2026-04-16)

`Experiments/scheduled-two-clock-spike/` — 4 variants, ALL PASS on
Apple Swift 6.3 / macOS 26 arm64:

- **V1 (single-clock baseline):** One `ContinuousClock` timer thread
  fires a 50 ms-deadline job within ~60 ms; shutdown clean. Confirms
  the harness.
- **V2 (two-clock parallel drain):** Two timer threads drain their
  own heaps in FIFO order; neither thread fires the other's jobs.
  `continuous=[10, 11] suspending=[20, 21]` confirms heap isolation.
- **V3 (shutdown race, both parked):** Both timer threads parked on
  `pthread_cond_timedwait` with 60-second future deadlines. Shutdown
  flag + broadcast on both condvars unblocks both in < 1 ms; neither
  far-future job fires. Confirms shared-flag + per-condvar-broadcast
  pattern is correct and race-free.
- **V4 (many-pending shutdown):** 100 pending jobs across both clocks
  at shutdown time. Shutdown completes in < 1 ms; no deadlock.

**Finding: no generic-over-Clock unification in v1.** The spike
initially modelled the timer as `PerClockTimer<C: Clock>`; Swift 6.3's
`SendNonSendable` SIL pass crashes when a generic class is referenced
from a `@convention(c)` pthread entry closure. The production
implementation must either (a) keep `Executor.Scheduled`'s timer
class non-generic and carry two concrete timer classes (duplication
acceptable at the spike scale, manageable at production scale), or
(b) emit the pthread entry function outside the generic class body.
Option B matches the idiom already used in `Kernel.Thread.trap(...)`
callers, which pass a retained pointer into a non-generic thread
entry. No ABI-level blocker.

**Finding: `clock_gettime(CLOCK_REALTIME)` + duration delta is
sufficient** for deadline conversion into `pthread_cond_timedwait`'s
timespec on both clocks. SuspendingClock does not suspend the process
in this harness (device is not put to sleep during the spike), so the
CLOCK_REALTIME-relative wait is equivalent to the CLOCK_MONOTONIC-
relative wait a production implementation might use via
`pthread_condattr_setclock(CLOCK_MONOTONIC)`. Production code should
prefer a monotonic clock for the wait to avoid wall-clock-jump
surprises.

### Next steps before promotion to DECISION

1. ~~**Prototype the two-clock split**~~ **DONE** (2026-04-16) — see
   "Validated by spike" subsection above. 4 variants ALL PASS; shared
   shutdown flag + per-clock condvar broadcast pattern confirmed
   race-free and deadlock-free; shutdown unblocks both parked threads
   in < 1 ms. Generic-over-Clock unification blocked by a Swift 6.3
   compiler crash in the `SendNonSendable` SIL pass; production can
   work around by emitting the pthread entry function outside the
   generic class body.
2. ~~**Update `Executor.Job.Priority.Entry`**~~ **DONE** (2026-04-16) —
   `swift-executor-primitives` Entry now carries a monotonic
   `UInt64 sequence`; `Priority.schedule(_:at:)` increments a
   per-queue `_nextSequence` counter inside the caller's lock; the
   `Comparison` conformance breaks ties by sequence. Three new FIFO
   ordering tests added to `Executor.Job.Priority Tests.swift`
   (28/28 pass at L1).
3. **Draft the `SchedulingExecutor` conformance** for
   `Executor.Scheduled`. Blocked by the SDK finding below — the
   protocol is absent from macOS 26.4 SDK `.swiftinterface`, so no
   conformance ships today. The conformance template is locked in
   "Locked rename-migration strategy" above; implementation is a
   one-commit follow-up when the SDK gate lifts.
4. ~~**Lock the rename-migration strategy.**~~ **DONE** (2026-04-16) —
   see "Locked rename-migration strategy" subsection above.
   Double-gated `hasFeature` + `compiler` conditional idiom with
   separate arms for pre- and post-rename protocol names.
5. ~~**Coordinate with `priority-escalation-policy.md`**~~ **DONE** —
   mutual-defer recorded in both notes (both rule out priority-keyed
   scheduling for v1).
6. ~~**Coordinate with `embedded-swift-scoping.md`**~~ **DONE** — that
   note's verdict for `Scheduled` is NO (ContinuousClock unavailable);
   `SchedulingExecutor` conformance is inherently `#if !$Embedded`
   because the protocol's generic `enqueue<C: Clock>` overloads are
   stdlib-gated behind `!$Embedded` (`Executor.swift:66, 109, 187, 211`
   [Verified: 2026-04-16]). The `hasFeature` gate recorded above
   subsumes the Embedded gate because neither the feature nor the
   protocol will be present under `$Embedded`.

### Review findings (2026-04-16, post peer review)

**Base-executor-shutdown contract.** If the base executor shuts down
after `Scheduled` has accepted delayed jobs, the timer thread pops a
job and calls `base.enqueue(job)` on a dead base. The base may run the
job inline (Polling) or drop it. **Requirement:** document as a
precondition: "Base MUST NOT shut down while Scheduled holds pending
jobs." Alternatively, `Scheduled.shutdown()` must drain or reject all
pending timer entries before releasing the base.

**Periodic scheduling is a v1 non-goal.** Java STPE's
`scheduleAtFixedRate` / `scheduleWithFixedDelay` are deliberate
omissions. Document as a conscious non-goal to prevent feature-request
PRs. Periodic scheduling is a composition concern (the caller
re-enqueues on completion), not a primitive concern.

**`Scheduled<Cooperative>` spawns a timer thread.** `Scheduled<Base>`
always spawns its own timer thread, regardless of whether `Base`
spawns threads. If `Base` is `Cooperative`, the composition silently
introduces a thread — contradicting the user's intent. The stdlib's
`CooperativeExecutor` handles timers internally without a separate
thread. Recommendation: `Cooperative` should conform to
`SchedulingExecutor` directly (see `cooperative-donation-contract.md`
Q6), making `Scheduled<Cooperative>` redundant. Document: "When `Base`
conforms to `SchedulingExecutor`, prefer using `Base` directly."

### Escalation note

Per [RES-004b]: this analysis touches `swift-executor-primitives` (L1)
— a proposed Entry change for the FIFO sequencer — and `swift-executors`
(L3) for the per-executor conformance and clock-generality decisions.
Scope is cross-package within `swift-foundations` + `swift-primitives`.
No escalation to `swift-institute` required. Re-evaluate if PR #2654
lands a protocol shape that invalidates these recommendations.

## References

### Academic foundations

- Liu, C. L., & Layland, J. W. (1973). [Scheduling Algorithms for
  Multiprogramming in a Hard-Real-Time
  Environment](https://dl.acm.org/doi/10.1145/321738.321743). *Journal
  of the ACM*, 20(1), 46–61. DOI: `10.1145/321738.321743`.
- Abeni, L., & Buttazzo, G. (1998). [Integrating Multimedia Applications
  in Hard Real-Time
  Systems](https://ieeexplore.ieee.org/document/740255). *19th IEEE
  RTSS*. CBS, cited by the Linux SCHED_DEADLINE documentation.
- Baruah, S., Mok, A., & Rosier, L. (1990). [Preemptively scheduling
  hard-real-time sporadic tasks on one
  processor](https://ieeexplore.ieee.org/document/128747). *11th IEEE
  RTSS*, 182–190. EDF optimality for sporadic task sets (extending
  Liu–Layland beyond periodic).

### Stdlib surface

- `swiftlang/swift` —
  [`stdlib/public/Concurrency/Executor.swift:63–111`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Executor.swift)
  (`SchedulingExecutor` protocol, public at 6.3).
- `swiftlang/swift` — `Executor.swift:184–212` (default cross-dispatch
  extension).
- `swiftlang/swift` — `Executor.swift:559–624`
  (`@_spi(ExperimentalCustomExecutors)` region:
  `RunLoopExecutor`, `MainExecutor`, `ExecutorFactory`).
- `swiftlang/swift` — `stdlib/public/Concurrency/ExecutorImpl.swift:96,
  121, 128` (force-unwrap of
  `Task.defaultExecutor.asSchedulingExecutor`).
- `swiftlang/swift` — `stdlib/public/Concurrency/SuspendingClock.swift:200,
  213`, `ContinuousClock.swift:222, 235` (`Task.currentSchedulingExecutor`
  use in clock-wait paths).
- `swiftlang/swift` — `stdlib/public/Concurrency/TaskSleep.swift:33, 277`,
  `TaskSleepDuration.swift:121` (`Task.sleep` routes through
  `currentSchedulingExecutor`).
- `swiftlang/swift` — `stdlib/public/Concurrency/DispatchExecutor.swift:28,
  81` (`DispatchMainExecutor`, `DispatchGlobalTaskExecutor` conformances).
- `swiftlang/swift` — `stdlib/public/Concurrency/CooperativeExecutor.swift:248`
  (Cooperative conformance).

### Swift Evolution

- [SE-0505: Delayed Enqueuing for
  Executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0505-delayed-enqueuing.md)
  — defines `SchedulingExecutor`; *returned for revision*.
- [swift-evolution PR #2654: Custom main and global
  executors](https://github.com/swiftlang/swift-evolution/pull/2654) —
  stabilization effort; renames `SchedulingExecutor` →
  `SchedulableExecutor`; open.
- [SE-0417: Task Executor
  Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor.md)
  (implemented 6.0).
- [SE-0462: Task Priority Escalation
  APIs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0462-task-priority-escalation-apis.md)
  (implemented 6.2; no executor-protocol obligation).

### OS scheduling-class references

- Linux
  [sched(7)](https://man7.org/linux/man-pages/man7/sched.7.html) and
  [sched_setattr(2)](https://man7.org/linux/man-pages/man2/sched_setattr.2.html)
  — `SCHED_DEADLINE` interface, admission control, `CAP_SYS_NICE`
  gating.
- Linux kernel
  [Documentation/scheduler/sched-deadline.rst](https://www.kernel.org/doc/Documentation/scheduler/sched-deadline.rst)
  — GEDF + CBS.

### Production runtimes

- OpenJDK
  [`ScheduledThreadPoolExecutor.java`](https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/util/concurrent/ScheduledThreadPoolExecutor.java)
  (binary min-heap, FIFO sequencer tiebreak).
- Tokio
  [`tokio/src/runtime/time/wheel/mod.rs`](https://github.com/tokio-rs/tokio/blob/master/tokio/src/runtime/time/wheel/mod.rs)
  (hashed timing wheel, 6 levels × 64 slots, 1 ms).
- Go runtime
  [`runtime/time.go`](https://github.com/golang/go/blob/master/src/runtime/time.go)
  (4-ary min-heap; random tiebreak only under fake time).
- Apple
  [`swift-corelibs-libdispatch/src/source.c`](https://github.com/apple/swift-corelibs-libdispatch/blob/main/src/source.c)
  (per-(clock, QoS) heap, EVFILT_TIMER, `leeway ≤ interval/2`).

### Internal references

- `executor-package-design.md` — design sketch at lines 460, 467,
  489–491 (v1 Scheduled signature sketch; deferrals resolved here).
- `priority-escalation-policy.md` v0.2.1 — mutual-defer on the
  same-deadline priority-tiebreak question.
- `work-stealing-scheduler-design.md` — precedent for this document's
  coordination structure.
- `embedded-swift-scoping.md` — coordination on `!$Embedded` gating of
  `SchedulingExecutor` conformance.
