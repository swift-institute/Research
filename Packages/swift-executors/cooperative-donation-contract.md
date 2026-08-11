# Cooperative Donation Contract

<!--
---
version: 0.1.0
last_updated: 2026-04-16
status: DECISION
tier: 2
---
-->

## Context

`Executor.Cooperative` is the only executor in the swift-executors v1
taxonomy that does not spawn an OS thread. The caller of `run()` donates
its own thread to the executor's drain loop. This is the same model as
the stdlib's `CooperativeExecutor` (the default executor on wasm32
Embedded) and the non-Darwin path in `Executor.Main`.

The stdlib carries an unresolved TODO that captures the core contract
question. At `CooperativeGlobalExecutor.cpp:250` [Verified: 2026-04-16]:

> // TODO: should the donator have some say in this?

The comment sits inside `claimNextFromCooperativeGlobalQueue()`, in the
branch where the ready queue is empty but delayed jobs exist. The
executor sleeps the donated thread via raw `nanosleep` until the earliest
delayed-job deadline. The donator has zero input into whether or how long
the thread sleeps.

The modern stdlib `CooperativeExecutor` (`CooperativeExecutor.swift`)
replaces the C++ path and conforms to `RunLoopExecutor` with `run()`,
`runUntil(_:)`, and `stop()`. The `runUntil` implementation is the direct
backend for `swift_task_donateThreadToGlobalExecutorUntilImpl` — the
runtime's thread-donation entry point (`ExecutorImpl.swift:39–52`
[Verified: 2026-04-16]):

```swift
@_silgen_name("swift_task_donateThreadToGlobalExecutorUntilImpl")
internal func donateToGlobalExecutor(
  condition: @convention(c) (_ ctx: UnsafeMutableRawPointer) -> CBool,
  context: UnsafeMutableRawPointer
) {
  if let runnableExecutor = Task.defaultExecutor as? RunLoopExecutor {
    try! runnableExecutor.runUntil { unsafe Bool(condition(context)) }
  } else {
    fatalError("Global executor does not support thread donation")
  }
}
```

Our `Executor.Cooperative` today (`Executor.Cooperative.swift`
[Verified: 2026-04-16]) has:
- `run()` — condvar-based drain loop, blocks until `shutdown()`
- `enqueue(_:)` — lock → enqueue → condvar wake
- `shutdown()` — one-way flag + wake-all
- **No** `runUntil(_:)`, **no** `RunLoopExecutor` conformance, **no**
  `stop()`, **no** priority-ordered drain

This note locks the donation contract: what the caller may expect, what
the executor may do with the donated thread, and how the contract
composes with the stdlib's `RunLoopExecutor` protocol.

## Question

Lock the donation contract for `Executor.Cooperative` along five axes:

1. **Yield policy.** Does the donated thread yield to other work between
   the caller's condition checks, or does it drain all pending jobs
   before re-checking?
2. **Revocation.** Can the donator take its thread back before the
   condition is met? What is the latency bound?
3. **Completion guarantee.** Is the donator guaranteed to get the thread
   back?
4. **Priority disposition.** Does the executor adjust the donated
   thread's OS priority?
5. **`RunLoopExecutor` conformance.** Should our `Cooperative` adopt the
   stdlib's `RunLoopExecutor` protocol?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| `RunLoopExecutor` is `@_spi(ExperimentalCustomExecutors)` | `Executor.swift:559` [Verified: 2026-04-16] | Conforming exposes us to SPI ABI risk, unlike `SchedulingExecutor` which is public |
| `runUntil` IS the backend for `swift_task_donateThreadToGlobalExecutorUntilImpl` | `ExecutorImpl.swift:39–52` [Verified: 2026-04-16] | Not implementing `runUntil` means our executor cannot participate in the runtime's thread-donation path |
| Stdlib `CooperativeExecutor.runUntil` sleeps via raw `_sleep` (nanosleep), no condvar, no wake-on-enqueue during sleep | `CooperativeExecutor.swift:323–324`, `Clock.cpp:221–257` [Verified: 2026-04-16] | Our condvar-based wait is strictly better: enqueue wakes the sleeping thread immediately |
| Stdlib `CooperativeExecutor.stop()` sets a flag but does NOT wake a sleeping thread | `CooperativeExecutor.swift:339` [Verified: 2026-04-16] | `stop()` latency is bounded by the current sleep duration. Our condvar `wake.all()` can do better |
| Stdlib `CooperativeExecutor.runUntil` resets `shouldStop = false` at entry — clobbers any prior `stop()` signal | `CooperativeExecutor.swift:292` [Verified: 2026-04-16] | Nested `run()` is unsound in the stdlib implementation (no re-entrancy guard) |
| Stdlib's cooperative drain is priority-ordered (`PriorityQueue`) | `CooperativeExecutor.swift:236` [Verified: 2026-04-16] | Our FIFO drain diverges from stdlib precedent |
| Our `Cooperative.run()` is identical to `Main.run()` on non-Darwin | `Executor.Cooperative.swift:80–89`, `Executor.Main.swift:97–118` [Verified: 2026-04-16] | Any contract decision for Cooperative applies to the non-Darwin Main path |
| Priority disposition: "caller-owned, not executor-managed" | `priority-escalation-policy.md` v0.3.0 §Cooperative analysis | M3 rejected for Cooperative; the caller's thread QoS is not ours to adjust |
| Embedded: Cooperative is SHIP-WITH-GUARDS; condvar reduces to busy-wait/WFI | `embedded-swift-scoping.md` v0.1.0 §Cooperative | Donation contract must not assume condvar; the `Wait` backend is platform-variable |

## Prior Art Survey

### libdispatch `dispatch_main()`

From `dispatch/queue.h` (apple/swift-corelibs-libdispatch) [Verified:
2026-04-16]:

> This function "parks" the main thread and waits for blocks to be
> submitted to the main queue. This function never returns.

Contract: **irrevocable, permanent, never returns**. The caller donates
the main thread for the lifetime of the process.

### Java `ForkJoinPool.managedBlock(ManagedBlocker)`

From OpenJDK JDK 21 Javadoc [Verified: 2026-04-16]:

> Runs the given possibly blocking task. When running in a ForkJoinPool,
> this method possibly arranges for a spare thread to be activated if
> necessary to ensure sufficient parallelism.

The `ManagedBlocker` polls `isReleasable()` (can we avoid blocking?)
and `block()` (actually block). The pool compensates by expanding worker
count before the thread blocks.

Contract: **conditional loan, compensated, condition-driven return**.
The richest donation model surveyed.

### Tokio `Runtime::block_on(future)`

From `docs.rs/tokio` [Verified: 2026-04-16]:

> This runs the given future on the current thread, blocking until it is
> complete, and yielding its resolved result.

The caller donates its thread to drive a single future. Spawned tasks
run on worker threads, not on the donated thread. Panics if called from
async context.

Contract: **scoped, single-future, thread returned on completion**.

### Go `runtime.LockOSThread`

From `pkg.go.dev/runtime` [Verified: 2026-04-16]:

> LockOSThread wires the calling goroutine to its current operating
> system thread. … If the calling goroutine exits without unlocking
> the thread, the thread will be terminated.

Contract: **exclusive bilateral binding, ref-counted unlock, thread
destroyed if leaked**.

### Rust `futures::executor::block_on`

From `futures-executor/src/local_pool.rs` [Verified: 2026-04-16]:

```rust
pub fn block_on<F: Future>(f: F) -> F::Output {
    let mut f = pin!(f);
    run_executor(|cx| f.as_mut().poll(cx))
}
```

Uses thread park/unpark for wait. Waker calls `thread.unpark()` when
progress is possible.

Contract: **park/unpark, single-future, thread returned on completion**.

### Pattern observations

| Dimension | libdispatch | ForkJoinPool | Tokio | Go | futures |
|-----------|:-----------:|:------------:|:-----:|:--:|:-------:|
| Yield to other work | Yes (main queue) | Compensated | No (own future only) | No (exclusive binding) | No (own future only) |
| Revocation | None (permanent) | Conditional (`isReleasable`) | None (runs to completion) | Ref-counted | None (runs to completion) |
| Completion guarantee | Never | Yes | Yes | Only if unlocked | Yes |
| Priority change | UNVERIFIED | UNVERIFIED | No | No | No |
| Compensation | N/A | Yes (new workers) | No | New threads | No |

**Per [RES-021] contextualization.** Priority propagation is universally
absent or undocumented in all surveyed donation models. This aligns
with `priority-escalation-policy.md`'s recommendation: "caller-owned,
not executor-managed." Our executor need not invent priority adjustment
for donated threads.

The critical contract axis is **revocation vs. permanence**. Our
`Cooperative` sits in the middle: not permanent (the caller can shut
down), not scoped-to-one-future (drains arbitrary work). The closest
analog is Java's `managedBlock` — condition-driven, with the caller
expressing a "done?" predicate. The stdlib's `runUntil(_: () -> Bool)`
implements exactly this model.

## Analysis

### Q1: Yield policy

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. **Snapshot-then-check** | Drain a snapshot of pending jobs, then re-check condition | Bounded work per condition-check; matches stdlib post-fix semantics | One batch of jobs runs before condition check; latency = batch duration |
| B. Per-job check | Check condition after every single job | Lowest latency for condition satisfaction | Overhead: one closure call per job execution |
| C. Drain-all-then-check | Drain all pending jobs before checking | Current `run()` behavior with condvar | Unbounded delay if jobs enqueue more jobs |

**Initial recommendation: A.** The stdlib's `CooperativeExecutor` adopted
snapshot-then-check after two bugfixes (`0fbd382e9ca` "Fix
CooperativeExecutor to not loop forever"; `bd27a14ea00` "Fix cooperative
executor to return only after all jobs run" [Verified: 2026-04-16]). The
infinite-drain risk of option C is real; the stdlib hit it. Option B is
correct but the per-job closure overhead is unnecessary given that the
donation model is "best effort, not real-time."

Implementation: replace the current inner drain loop with
`jobs.drain(into: &drainBuffer)` (existing primitive), drain buffer, then
re-check condition.

### Q2: Revocation

| Option | Description |
|--------|-------------|
| A. **Condition callback** | `runUntil(_ condition: () -> Bool)` — caller provides a predicate; executor re-checks per snapshot |
| B. `stop()` method | External signal to abort; flag-checked at loop head |
| C. Both | Condition for donator-side revocation; `stop()` for executor-side shutdown |

**Initial recommendation: C.** `runUntil` with condition callback handles
the donator's "I want my thread back when X" case. `stop()` handles the
executor's "I'm shutting down" case. The current `shutdown()` is one-way
(sets flag, wakes all); a `stop()` that is nestable (per `RunLoopExecutor`
contract: "stop the innermost `run()` invocation") is a refinement.

Revocation latency: bounded by the longest single job execution on the
donated thread, not by sleep duration (because our condvar-based wait
wakes on enqueue, unlike the stdlib's raw nanosleep).

### Q3: Completion guarantee

**Yes — always.** Both `run()` and `runUntil` return when their exit
condition is met. The donated thread is never permanently captured (unlike
`dispatch_main()`). `shutdown()` forces exit; `stop()` stops the
innermost invocation.

Document the guarantee explicitly: `run()` blocks until `shutdown()` or
`stop()`; `runUntil(_:)` blocks until the condition returns `true`, or
`stop()`/`shutdown()` is called.

### Q4: Priority disposition

Per `priority-escalation-policy.md` v0.3.0 §`Executor.Cooperative.runUntil`:

> The Cooperative executor's priority disposition IS the caller's thread
> disposition; the runtime's existing `swift_task_escalateImpl` Darwin
> path already handles the "escalate the thread currently running this
> task" case when `runUntil` is itself called from within a `Task`.

**Initial recommendation: no priority tracking.** The executor does not
call `pthread_override_qos_class_start_np` or adjust thread priority.
FIFO drain order for v1 (matching our current implementation). Priority-
ordered drain (like stdlib's `PriorityQueue`) is a v2 option; note
that adding it would require switching from `Executor.Job.Queue` (FIFO
deque) to `Executor.Job.Priority` (heap), which changes the L1 primitive
dependency.

Declaration for documentation: "Priority is caller-owned. The donated
thread runs at the OS priority of the donating context. The executor
does not adjust it."

### Q5: `RunLoopExecutor` conformance

| Option | Pros | Cons |
|--------|------|------|
| **A. Conform** | Participates in runtime donation path; stdlib precedent (CooperativeExecutor conforms) | `@_spi(ExperimentalCustomExecutors)` — SPI risk |
| B. Don't conform | No SPI exposure | Cannot participate in `swift_task_donateThreadToGlobalExecutorUntilImpl`; users who use our Cooperative as `Task.defaultExecutor` cannot donate |
| C. Implement methods without formal conformance | API-compatible without SPI import | Runtime cast in `ExecutorImpl.swift:45` (`as? RunLoopExecutor`) fails; donation still broken |

**Initial recommendation: A, gated by availability and SPI import.**
The SPI risk is real but bounded: the protocol is 3 methods (`run`,
`runUntil`, `stop`) whose shapes are unlikely to change. The
consequence of non-conformance — silently broken thread donation — is
worse than tracking a potential SPI rename.

Import the SPI conditionally:
```swift
#if canImport(_Concurrency)
@_spi(ExperimentalCustomExecutors)
extension Executor.Cooperative: RunLoopExecutor { ... }
#endif
```

This isolates the SPI exposure to a single extension. If the SPI
stabilizes (PR #2654 trajectory), the `@_spi` annotation is removed.

**Implementation finding (2026-04-16):** Option A is architecturally
correct but platform-blocked. The SDK's `.swiftinterface` for
`_Concurrency` strips `@_spi(ExperimentalCustomExecutors)` symbols
entirely. `@_spi(ExperimentalCustomExecutors) import _Concurrency`
compiles but produces a warning: *"'@_spi' import of '_Concurrency'
will not include any SPI symbols; '_Concurrency' was built from the
public interface."* `RunLoopExecutor` is then unresolvable — the
conformance cannot compile from any external package, regardless of
import strategy.

**Effective status: Option C** (methods without formal conformance) is
the v1 reality. `run()`, `runUntil(_:)`, and `stop()` are implemented
with matching signatures. The runtime's `as? RunLoopExecutor` cast
(`ExecutorImpl.swift:45`) will fail for our executor until the protocol
stabilizes to public. Conformance is a one-line addition
(`extension Executor.Cooperative: RunLoopExecutor {}`) when the gate
lifts. Track via PR #2654 trajectory.

### Cross-cutting: Embedded variant

Per `embedded-swift-scoping.md`, Embedded Cooperative is
SHIP-WITH-GUARDS. The condvar-based `Wait` is unavailable on bare-metal;
the Embedded variant needs an alternate `Wait` backend:

- **Option E1**: `#if $Embedded` busy-wait loop with `_wfi()` / `yield`
  between iterations.
- **Option E2**: Trait-based `Wait` strategy — the executor accepts a
  platform-provided wait closure at construction. This is the more
  composable design but adds API surface.

Deferred to v2; the current `Executor.Wait.Condvar` is the v1 backend.
The donation contract (yield policy, revocation, priority) is
independent of the wait mechanism and does not change.

### Cross-cutting: Non-Darwin `Main` identity

`Executor.Main.run()` on non-Darwin is character-identical to
`Executor.Cooperative.run()` [Verified: 2026-04-16]. The donation
contract established here applies to both. When `runUntil` and `stop()`
are added to `Cooperative`, the same additions should be mirrored (or
factored out) in `Main`'s non-Darwin path.

## Outcome

**Status:** `DECISION`.

### Locked recommendations

| Question | Recommendation |
|----------|----------------|
| Q1: Yield policy | Snapshot-then-check (stdlib pattern post-bugfix) |
| Q2: Revocation | Condition callback (`runUntil`) + `stop()` method |
| Q3: Completion guarantee | Always; document explicitly |
| Q4: Priority disposition | Caller-owned; no executor adjustment; FIFO drain for v1 |
| Q5: `RunLoopExecutor` conformance | Conform, gated by `@_spi(ExperimentalCustomExecutors)` |

### Rationale summary

1. Snapshot-then-check prevents the infinite-drain bug the stdlib
   already hit and fixed.
2. `runUntil` + `stop()` maps directly to the stdlib's `RunLoopExecutor`
   contract and the runtime's `swift_task_donateThreadToGlobalExecutorUntilImpl`
   bridge.
3. Priority-ordered drain is deferred to v2 to avoid coupling the
   donation contract to the priority story (which
   `priority-escalation-policy.md` already locked as "no priority
   tracking in v1").
4. `RunLoopExecutor` conformance is the cost of participating in the
   runtime's donation path. The SPI risk is bounded by the protocol's
   simplicity (3 methods).

### Review findings (2026-04-16, post peer review)

**Re-entrancy prohibition.** The stdlib's `CooperativeExecutor` has a
`shouldStop = false` clobber on re-entry (`CooperativeExecutor.swift:292`
[Verified: 2026-04-16]). If a job calls `runUntil` recursively, the
outer invocation's `stop()` signal is lost. Our implementation must add
a re-entrancy guard: `precondition(!isRunning, "nested runUntil is not
supported")` at `runUntil` entry. The `RunLoopExecutor` protocol permits
nesting ("Nested calls to run() may be permitted") — but also says "you
must not call [runUntil] unless you *know* that it is supported." A
precondition is within the protocol's latitude and avoids the clobber
bug. Nested-run support may be added in v2 via a depth counter.

**`stop()` vs `shutdown()` priority.** `shutdown()` dominates. If both
are in flight, the executor exits permanently. `stop()` alone halts the
innermost `runUntil`; `shutdown()` halts everything and is irreversible.
Document this ordering explicitly.

**Q6: `SchedulingExecutor` conformance (new axis).** The stdlib's
`CooperativeExecutor` conforms to `SchedulingExecutor` directly,
handling deadline-ordered waits in the donated thread's drain loop
without a separate timer thread. Our `Cooperative` should do the same:
incorporate a deadline-ordered internal queue (reuse
`Executor.Job.Priority` from L1), wait on the donated thread until the
earliest deadline, drain, check condition, repeat. This makes
`Scheduled<Cooperative>` a redundant wrapper (the base already handles
scheduling) and preserves the single-thread contract users chose
Cooperative for. Gate the conformance `#if !$Embedded` per
`embedded-swift-scoping.md`. This changes Q5's scope from
"RunLoopExecutor conformance" to "RunLoopExecutor + SchedulingExecutor
conformance."

**Runtime escalation is structural, not coincidental.** The runtime's
priority-escalation path fires for all executors by structural invariant:
`swift_job_run` → `runJobInEstablishedExecutorContext` → `flagAsRunning`
→ `dispatch_lock_value_for_self()` records `pthread_self()` into the
task's `ExecutionLock` (`TaskPrivate.h:616` [Verified: 2026-04-16]).
Document as: "Assumed runtime invariant: verify per Swift release."

### Next steps before promotion to DECISION

1. ~~**Implement `runUntil(_:)` and `stop()` on `Executor.Cooperative`.**~~
   **DONE** — `Executor.Cooperative.swift`. `run()` delegates to
   `runUntil { false }`. Snapshot-drain via `swap(&jobs, &drainBuffer)`.
   `stop()` is non-destructive (condvar wake, not nanosleep). Re-entrancy
   precondition on `_isRunning`.
2. ~~**Add the `RunLoopExecutor` conformance extension**, `@_spi`-gated.~~
   **BLOCKED** — SDK `.swiftinterface` strips `@_spi(ExperimentalCustomExecutors)`
   symbols. External packages cannot conform to `RunLoopExecutor` until
   the protocol stabilizes to public. Methods (`run`, `runUntil`, `stop`)
   implemented with matching signatures; conformance deferred.
3. ~~**Add `SchedulingExecutor` conformance** (Q6), incorporating
   `Executor.Job.Priority` for deadline-ordered waits in the donated
   thread.~~ **PARTIALLY DONE** — `Executor.Job.Priority` integrated into
   `runUntil` drain loop (timed condvar waits on next deadline).
   `enqueue(_:after:)` implemented as concrete method matching
   `SchedulingExecutor`'s signature. Formal conformance BLOCKED:
   `SchedulingExecutor` is absent from macOS 26.4 SDK `.swiftinterface`
   (exists in stdlib source at `Executor.swift:64` but not shipped).
   Same root cause as RunLoopExecutor — protocol source ≠ protocol in
   SDK. Conformance is a one-line addition when the protocol ships.
4. ~~**Mirror changes to `Executor.Main` non-Darwin path.**~~ **DONE** —
   `Executor.Main.swift` non-Darwin path now has `runUntil`, `stop()`,
   `enqueue(_:after:)`, snapshot-drain with scheduled integration.
   Duplication is two types (Cooperative + Main non-Darwin); factoring
   deferred until a third consumer emerges.
5. ~~**Write tests.**~~ **DONE** — 7 tests in `Executor.Cooperative Tests.swift`:
   create-and-shutdown, stop-without-run, runUntil-immediate-return,
   run-returns-on-shutdown, stop-causes-run-to-return,
   stop-from-other-thread, actor-method-runs-on-donated-thread,
   shutdown-dominates-stop. Uses `Cooperator` actor pinned to the
   executor for enqueue-via-actor tests.
6. ~~**Document the contract** in the type's docstring.~~ **DONE** —
   full donation contract documented: yield policy, revocation, completion
   guarantee, priority, re-entrancy, stop/shutdown priority.

### Escalation note

Per [RES-004b]: this analysis now touches `swift-executor-primitives`
(L1) — `Executor.Job.Priority` for the SchedulingExecutor conformance —
and `swift-executors` (L3) for the donation contract, `RunLoopExecutor`,
and `SchedulingExecutor` conformances. No escalation to `swift-institute`.
Re-evaluate if priority-ordered drain is adopted in v2.

## References

### Stdlib context (cited above)

- `swiftlang/swift` — `stdlib/public/Concurrency/CooperativeGlobalExecutor.cpp:250`
  (unresolved TODO: "should the donator have some say in this?").
- `swiftlang/swift` — `stdlib/public/Concurrency/CooperativeExecutor.swift:236`
  (priority-ordered drain), `:286–341` (`RunLoopExecutor` conformance),
  `:292` (`shouldStop` clobber on re-entry).
- `swiftlang/swift` — `stdlib/public/Concurrency/ExecutorImpl.swift:39–52`
  (`runUntil` as the `swift_task_donateThreadToGlobalExecutorUntilImpl`
  backend).
- `swiftlang/swift` — `stdlib/public/Concurrency/Executor.swift:559–589`
  (`RunLoopExecutor` protocol, `@_spi(ExperimentalCustomExecutors)`).
- Commits: `0fbd382e9ca` (fix infinite drain); `bd27a14ea00` (fix
  premature exit) [Verified: 2026-04-16 from git log].

### Production runtimes

- Apple `dispatch/queue.h` — `dispatch_main()` (permanent donation).
- OpenJDK `ForkJoinPool.java` — `managedBlock(ManagedBlocker)`
  (conditional, compensated).
- Tokio `runtime/runtime.rs` — `block_on(future)` (scoped, single-future).
- Go `runtime` — `LockOSThread` (exclusive bilateral binding).
- Rust `futures-executor/src/local_pool.rs` — `block_on`
  (park/unpark, single-future).

### Internal references

- `executor-package-design.md` — locked taxonomy; Cooperative section
  at lines 365–411.
- `priority-escalation-policy.md` v0.3.0 — "caller-owned priority"
  declaration for Cooperative.
- `embedded-swift-scoping.md` v0.1.0 — SHIP-WITH-GUARDS verdict;
  Embedded `Wait` backend deferred.
- `scheduled-executor-policy.md` — no direct coupling (Scheduled wraps
  a base; the base may be Cooperative, but the scheduling contract is
  independent).
