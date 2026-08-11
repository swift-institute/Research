---
date: 2026-04-15
session_objective: Complete Phase 3 of the swift-executors complete-toolkit migration — Event.Loop and Completion.Loop consolidated onto shared executor primitives.
packages:
  - swift-executor-primitives
  - swift-executors
  - swift-io
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Executor Toolkit Phase 3 Completion

## What Happened

Session objective: complete Phase 3 of the swift-executors migration plan per `executor-package-design.md`. The phase spans two swift-io consumers — `IO.Event.Loop` (reactor, kqueue/epoll) and `IO.Completion.Loop` (proactor, io_uring).

**Phase 3a — Event.Loop migration** (committed: swift-primitives `678d5aa`, swift-executors `e41aded`, swift-io `12b7903b`):
- Revised `Kernel.Thread.Executor.Polling` API. Before: `tick: @Sendable () -> Outcome` with run loop `while { drainJobs(); tick() }` — a busy-spin stub since tick contained the blocking call by contract. After: `tick: @Sendable (UnsafeBufferPointer<Kernel.Event>) -> Outcome` with run loop calling `waitSource.wait()`. Supervisor review caught the busy-spin.
- Rewrote `IO.Event.Loop.swift` (341 → 145 LOC) as a thin wrapper holding Polling. SerialExecutor/TaskExecutor conformance delegates to Polling. All executor machinery (jobs, sync, drainBuffer, isRunning, threadHandle, wakeup channel) removed.
- User feedback mid-session pushed back on `withSource` closure pattern: "we already use ~Escapable in our ecosystem." Replaced throwing+non-throwing `withSource` overloads across all three layers (L1 `Executor.Wait.Event.Source`, L3 Polling, IO.Event.Loop) with a single `source` property using `_read`/`_modify` coroutine accessors. Three actor call sites collapsed from `executor.withSource { source in ... }` to `executor.source.xxx` direct access.

**Phase 3b — Completion.Loop executor unification** (implemented by subordinate in separate session, verified here, not yet committed):
- Wrote supervisor ground-rules block per `/supervise` skill: MUST write research doc first; MUST NOT assume Polling adapter is the answer; ask for user approval if Option A chosen.
- Subordinate's research doc (`swift-io/Research/completion-loop-executor-unification.md`) discovered a concrete deadlock path in the Polling adapter approach (Option A): flush-before-wait ordering problem. Polling's run loop is `drain → wait → tick`; Completion.Loop requires `drain → cancel → flush → wait → drain CQEs → dispatch`. SQEs submitted during drainJobs never reach the kernel before the next blocking wait, and the eventfd never fires — deadlock.
- Recommendation: Option B (primitives-only refactor). Replace ad-hoc executor machinery with L1 primitives (`Executor.Job.Queue`, `Executor.Shutdown.Flag`, `Kernel.Thread.Mutex`); keep the 5-phase run loop and `notification.wait()` blocking.
- Implementation: 362 → ~280 LOC. Tests green on macOS. No driver witness ABI change.

**Ancillary changes (external during session)**: `Polling.shutdownNow()` renamed to `shutdown()` with `isCurrent`-based join/detach. `IO.Event.Loop` updated to call `shutdown()`. Addresses part of Code Surface audit finding #1.

## What Worked and What Didn't

**What worked:**
- **Supervisor ground rules prevented a correctness bug.** The original Phase 3b dispatch said "same pattern as Event.Loop, use Polling." The ground-rule `MUST write research doc before implementation; MUST NOT assume Option A is the answer` forced honest evaluation. The subordinate found the flush-before-wait deadlock. Had Option A been implemented per the original dispatch, the result would have either deadlocked in production or required the submit-path wakeup workaround (extra syscall per submit, coupling submit to adapter wake mechanism).
- **User feedback on API direction was decisive.** I added a throwing `withSource` variant as a stopgap, describing `~Escapable` as "future." The user corrected: `Lifetimes` is enabled across the ecosystem; coroutine accessors are current. Within minutes the migration collapsed two overloads to one property and eliminated three closure call sites.
- **Reactor/proactor mismatch recognized before implementation.** The session's initial handoff analysis noted that Polling requires `Kernel.Event.Source` (reactor) but `IO.Completion.Driver.poll` blocks on eventfd (proactor). Escalated as Phase 3a/3b split before touching Completion.Loop.

**What didn't work:**
- **I framed `~Escapable` as a future feature.** Wrote "Once the lifetime checker handles `~Escapable` through class stored properties, all of these collapse to direct property access." The user's correction was immediate. This was memory drift — `feedback_escapable_over_with_closures.md` now corrects it, but the mistake reached committed code before the correction.
- **The original Phase 3b dispatch assumed adapter.** Research doc `executor-package-design.md` V2 (written before the reactor/proactor mismatch was surfaced) proposed `driver.asEventSource(handle)` as the bridge. The mismatch was real but only partially understood at the handoff. The subordinate's research, not the handoff author's, produced the decisive argument (flush-before-wait).
- **Initial Polling design had "tick must block" in its contract.** Offloading the blocking responsibility to the consumer looked clean in the design doc but produced a busy-spin stub. Supervisor caught this during Phase 2 review. The fix (run-loop-owned blocking) is retrospectively obvious but wasn't until the first real consumer (Event.Loop) tried to use the API.

## Patterns and Root Causes

**1. Executor shape follows concurrency paradigm; unification is at the primitives level, not the executor shell.**

Event.Loop (reactor) and Completion.Loop (proactor) differ structurally: different blocking primitives (epoll_wait vs eventfd read), different event sources (poll return vs separate ring buffer), different phase orderings. The complete-toolkit mission originally framed both as consumers of Polling. The flush-before-wait analysis and the ignored-events design smell showed this was over-unification. The right abstraction boundary is the L1 primitives (`Executor.Job.Queue`, `Executor.Shutdown.Flag`, `Kernel.Thread.Mutex`) — both loops use them. The run-loop shape is paradigm-specific and should stay that way. This matches [PATTERN-013]: protocols require 3+ concrete conformers; forcing two genuinely different paradigms under one executor shell is premature unification.

**2. Ground-rule-mandated research is a cheap insurance policy against dispatches that are wrong.**

The Phase 3b dispatch was written before the blocking-mechanism mismatch was fully understood. A confident-sounding handoff propagates its assumptions into the subordinate's work unless explicit ground rules force verification. The `MUST write research first; MUST NOT assume Option A` pattern cost one extra step in the subordinate's workflow and saved a deadlock-prone implementation. When the dispatched approach might be wrong — when the principal is handing off with remaining doubt — the first ground rule should be a research gate, not an implementation directive.

**3. API contracts with "consumer must do X" are design smells.**

Polling's initial contract: "tick body MUST include a blocking wait — a non-blocking tick will busy-spin." This offloaded a correctness property to the consumer. The revision moved the blocking into the run loop itself; consumers now provide only domain-specific dispatch. The pattern: when the type's doc comment has to say "consumers MUST do X or else busy-spin/deadlock/leak," the type's API is incomplete. Either the behavior moves inside, or the type's API shape prevents incorrect use.

**4. `with*` closures vs `_read`/`_modify` coroutine properties is a genuine convention choice; the ecosystem's direction is the latter.**

The throwing `withSource<R, E: Swift.Error>` overload I added in Phase 3a was backward drift. Each new `with*` overload (throwing/non-throwing, error-generic/concrete) is surface area that the coroutine accessor eliminates with one property. The `Lifetimes` experimental feature is enabled across the ecosystem; class-stored-property access via `_read`/`_modify` works. When an existing API is already a `with*` closure, migrating to a coroutine property is pure simplification at all three layers (the storage primitive, the composing executor, and the domain wrapper all get simpler).

## Action Items

- [ ] **[skill]** implementation: Add requirement (e.g., [IMPL-084]) that coroutine `_read`/`_modify` property accessors are preferred over `with*` closure APIs for borrowed access to `~Copyable` resources stored in classes. Reference the `Executor.Wait.Event.Source` → Polling → Event.Loop migration as the canonical example. Complements existing [IMPL-021], [IMPL-071].

- [ ] **[research]** swift-executors: Document the reactor/proactor paradigm distinction in `executor-package-design.md`. Add a post-Phase-3 section capturing: Option B decision for Completion.Loop, Criterion #8 revision ("Completion.Loop uses L1 primitives to eliminate ad-hoc machinery. Polling reserved for reactor-pattern loops"), and the flush-before-wait deadlock as the concrete argument against over-unification.

- [ ] **[skill]** supervise: Add guidance that when a handoff's dispatched approach rests on an incompletely-understood assumption, the principal's first ground-rules entry SHOULD be a research gate ("MUST write research doc before implementation; MUST NOT assume the dispatched approach"). The Phase 3b supervision validated this pattern by catching a correctness bug the original dispatch would have shipped.
