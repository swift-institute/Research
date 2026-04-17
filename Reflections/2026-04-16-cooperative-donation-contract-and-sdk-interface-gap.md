---
date: 2026-04-16
session_objective: Complete handoff items (Sharded isolation, research promotions), then implement Cooperative donation contract
packages:
  - swift-executors
status: pending
---

# Cooperative Donation Contract Landing and SDK Interface Gap Discovery

## What Happened

Session started from a handoff prescribing three items: promote
`work-stealing-scheduler-design.md` and `polling-executor-queue-design.md`
to DECISION, and implement `isIsolatingCurrentContext()` on
`Kernel.Thread.Executor.Sharded`. All three completed in the first commit
(`d4b4b88`), including landing the full v1 research corpus (7 notes + 2
reflections) as untracked files.

Continued with `Executor.Cooperative` donation contract: `runUntil(_:)`
with snapshot-drain (the stdlib pattern post-bugfix), `stop()` as
non-destructive exit, `run()` refactored to delegate to `runUntil { false }`.
Added `enqueue(_:after:)` with `Executor.Job.Priority` integration and
timed condvar waits in the drain loop. Mirrored all changes to
`Executor.Main`'s non-Darwin path. Promoted `cooperative-donation-contract.md`
to DECISION. 4 commits total, 28/28 tests pass.

The session's major finding: `RunLoopExecutor`, `SchedulingExecutor`, and
`MainExecutor` are absent from the macOS 26.4 SDK `.swiftinterface`. Only
`Executor`, `SerialExecutor`, `TaskExecutor` ship. The protocols exist in
`swiftlang/swift` stdlib source but are not included in the compiled binary
interface. `@_spi(ExperimentalCustomExecutors) import _Concurrency` compiles
with a warning ("will not include any SPI symbols") and `RunLoopExecutor`
remains unresolvable. `SchedulingExecutor` (which is NOT SPI — it's public
in the source) is equally absent.

## What Worked and What Didn't

**Worked well:** The handoff-driven start was efficient — verification took
minutes, then straight into implementation. The snapshot-drain pattern
(learned from stdlib bugfix history) was correct on first implementation.
The `Cooperator` actor pattern for testing a `SerialExecutor` (pinning an
actor to the executor) solved the "can't create ExecutorJob from a closure"
problem cleanly.

**Didn't work:** Both protocol conformances (`RunLoopExecutor`,
`SchedulingExecutor`) were attempted and failed at compile time. The
research notes had classified these as achievable ("public-not-SPI" for
SchedulingExecutor, "SPI risk is bounded" for RunLoopExecutor). The gap
between "exists in stdlib source" and "ships in SDK binary interface" was
not anticipated by the research.

**Confidence assessment:** High confidence on the implementation code — the
donation contract, snapshot-drain, and scheduled integration are
straightforward concurrent patterns. Low confidence on when the SDK gap
will close — no visibility into Apple's SDK interface generation pipeline.

## Patterns and Root Causes

**"Public in source" ≠ "available in SDK."** This is the core lesson. The
research notes verified protocol existence against `swiftlang/swift` source
(`Executor.swift:64`, `:561`). The source is authoritative for semantics
but not for availability. The `.swiftinterface` file is what external
packages compile against, and it can strip symbols that are `public` in
source — either because the build system filters them, or because
availability annotations exclude them from the interface at the target
deployment version.

This pattern will recur for any stdlib protocol that is "new in 6.3" —
the protocol may exist in the 6.3 toolchain's source but not ship in the
SDK until a future Xcode release. The check is mechanical: `grep` the
`.swiftinterface` file before planning conformances.

**Infrastructure-ready, conformance-deferred** is the correct v1 posture.
All three cases (RunLoopExecutor, SchedulingExecutor on Cooperative,
SchedulingExecutor on Scheduled) followed the same pattern: implement the
methods with matching signatures, document the blocker, note that
conformance is a one-line addition. This preserves all implementation
value while acknowledging the platform constraint.

## Action Items

- [ ] **[skill]** existing-infrastructure: Add a decision-tree entry "Before conforming to a stdlib protocol" — check the SDK `.swiftinterface`, not just the source, for protocol availability
- [ ] **[skill]** research-process: Add verification step to the contextualization protocol — "Is the type/protocol present in the target SDK's .swiftinterface?" alongside the existing source-level verification
- [ ] **[research]** When do new stdlib protocols appear in SDK .swiftinterface? Is it tied to Xcode version, deployment target, or something else? A spike against multiple SDK versions would answer this.
