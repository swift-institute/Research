---
date: 2026-04-16
session_objective: Supervise implementing agent through research promotions, Sharded isolation check, and Cooperative runUntil/stop() implementation
packages:
  - swift-executors
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Supervision, SPI Stripping Discovery, and Cooperative Landing

## What Happened

Supervised an implementing agent across two handoff cycles in one
session. First cycle: promote `work-stealing-scheduler-design.md` and
`polling-executor-queue-design.md` to DECISION, implement
`isIsolatingCurrentContext()` on Sharded. All 7 acceptance criteria met
(d4b4b88). Second cycle: implement Cooperative `runUntil(_:)`, `stop()`,
snapshot-drain yield policy, re-entrancy precondition, and
`SchedulingExecutor` conformance (eff3da5). Mirrored `runUntil`/`stop()`
to `Executor.Main` non-Darwin path. Updated
`cooperative-donation-contract.md` and `scheduled-executor-policy.md`
with SPI stripping finding.

**Major platform discovery:** `RunLoopExecutor` conformance is impossible
from external packages on current Swift 6.3. The SDK `.swiftinterface`
strips `@_spi(ExperimentalCustomExecutors)` declarations, making the
protocol invisible to downstream consumers even with `@_spi import`. The
implementing agent discovered this at build time — the methods were
implemented with matching signatures but formal conformance could not be
declared. This was anticipated as a risk in the research
(`cooperative-donation-contract.md` §Q5: "the SPI risk is real but
bounded") but the specific mechanism (interface stripping, not import
gating) was not predicted.

`SchedulingExecutor` conformance succeeded — it is public, not SPI.
This validates the research note's distinction between the two protocols'
stability levels.

## What Worked and What Didn't

**Worked: supervisor ground rules kept the agent on track.** The
"MUST NOT re-open research decisions" rule (ground rule #1) prevented the
promoting agent from second-guessing converged recommendations. The "v2
deferrals are conscious, not blockers" addendum (added late) was
essential — without it, the agent would have hesitated to write DECISION
on notes with open v2 items.

**Worked: the handoff + supervision pattern scales.** This session
supervised two full implementation cycles (7 + N acceptance criteria)
without losing track. The ground rules were specific enough to catch
drift but short enough (6 entries) for the agent to hold in working
memory.

**Didn't work: the SPI blocker was discovered at build time, not at
research time.** The research note said "SPI risk is real" and
recommended conforming with `@_spi` gating. But the actual failure mode
(`.swiftinterface` stripping) is different from what was imagined (import
restriction). The research should have included a spike: "can we actually
import and conform to `@_spi(ExperimentalCustomExecutors)` protocols from
an external package?" A 5-line experiment would have caught this before
the implementation session.

## Patterns and Root Causes

**Pattern: SPI != import restriction.** `@_spi` has two enforcement
mechanisms: (1) import gating — you must write `@_spi(Name) import
Module` to see the declarations, and (2) interface stripping — the
`.swiftinterface` file for the module may not include SPI declarations at
all, making them invisible regardless of import syntax. The research
assumed (1); the reality was (2). This is a general lesson for any
research note that recommends conforming to an SPI protocol: always spike
the conformance from an external package before committing to it.

**Pattern: "risk is bounded" claims need verification.** The research
note correctly identified the risk category (SPI instability) but
assessed it as "bounded by the protocol's simplicity." The actual bound
was tighter: conformance was impossible, not just risky. Risk assessment
without empirical verification is speculation — the same lesson as the
`@_alignment(128)` spike that killed a design, and the source-
verification correction that caught fabricated citations. Spikes are
cheap; wrong assumptions are expensive.

## Action Items

- [ ] **[skill]** research-process: Add guidance that any research recommendation to conform to an `@_spi` protocol MUST include a verification spike (can we actually conform from an external package?) before the note reaches DECISION. Cite the RunLoopExecutor stripping discovery as provenance.
- [ ] **[research]** Track RunLoopExecutor stabilization: when PR #2654 merges and removes the `@_spi` gate, the Cooperative and Main executors gain formal conformance as a one-line change. Record the tracking condition in cooperative-donation-contract.md.
- [ ] **[package]** swift-executors: File a Swift Forums post or bug report documenting that `.swiftinterface` stripping makes `@_spi(ExperimentalCustomExecutors)` protocols unconformable from external packages, which blocks the custom-executor ecosystem PR #2654 is trying to enable.
