---
date: 2026-04-16
session_objective: Continue swift-executors v1 research initiative — convert 7 DRAFT topics to substantive research notes; validate critical claims via experiment spikes; produce a converged Executor.Job.Deque design; hand off to an implementing agent
packages:
  - swift-executors
  - swift-executor-primitives
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# V1 Research Corpus Completion and Deque Implementation

## What Happened

Resumed from a prior-session HANDOFF with 7 DRAFT research topics in the
swift-executors v1 "Proposed Research" backlog. All 7 were converted to
IN_PROGRESS research notes with verified citations, the Proposed Research
section in `_index.md` is now empty.

The first note (`priority-escalation-policy.md`) was written without
source verification — confident claims about Tokio, Go, Java FJ, Sha-
Rajkumar-Lehoczky 1990, and `pthread_override_qos_class_start_np` were
generated from training data, not from primary sources. The user
corrected this immediately: "don't just dream up some stuff. do actual
research first. quote sources." This triggered a methodological shift for
the entire session: all subsequent work used parallel subagent dispatch
(4-6 agents per topic) to fetch and verify primary sources before writing.

Two experiment spikes were built and run:
- **priority-override-spike**: ALL PASS. Validated `pthread_override`
  nesting (any-order teardown), sub-µs cost (853 ns/cycle), and
  cross-thread non-wake (override does not wake condvar-parked workers).
  Also discovered: `_end_np` MUST be called while the target thread is
  alive (ESRCH on post-join call).
- **alignment-spike**: Discovered that `@_alignment(128)` is NOT possible
  in Swift (compiler max is 16). This blocked the `CacheLine.Padded<T>`
  design; `posix_memalign(128)` is the viable alternative. Also verified
  Worker instances are 192 bytes (safe from cross-worker false sharing).

A peer review was conducted by instructing a second agent as a "tenured
professor." The review caught: FIFO head-of-line blocking latency not
quantified, re-entrancy bug inherited from stdlib's CooperativeExecutor,
`Scheduled<Cooperative>` is a category error (spawns a thread for a
user who chose no-threading), and the runtime escalation path question
(does `swift_task_escalateImpl` fire for custom executors?). All findings
were traced against the stdlib source and resolved:
`TaskPrivate.h:616` `dispatch_lock_value_for_self()` confirms the
escalation path is executor-agnostic.

The Executor.Job.Deque design was converged via a design discussion with
the professor agent. The implementing agent built it, the professor
supervised, and all 25 tests pass. The production Chase-Lev deque is
now in `swift-executor-primitives`.

## What Worked and What Didn't

**Worked: parallel subagent research.** Dispatching 4-6 agents per topic
to fetch primary sources (stdlib file:line, man pages, academic papers,
runtime source) produced verified findings in 60-180 seconds per agent.
The verification quality was consistently high — agents quoted verbatim
from the sources and flagged claims they couldn't verify as UNVERIFIED.
This pattern should be the default for all Tier 2+ research.

**Worked: the peer-review-by-agent pattern.** The professor agent caught
issues the authoring agent missed: re-entrancy, the
Scheduled<Cooperative> category error, and the FIFO latency model.
Framing the reviewer as a "tenured professor" with specific expertise
produced genuinely challenging review rather than rubber-stamping.

**Worked: spike-before-commit.** Both spikes caught real issues: the
priority-override spike validated the M3 recommendation's viability; the
alignment spike killed a design (`@_alignment(128)`) that would have
failed at compile time. The alignment spike was the reviewer's
recommendation — it paid for itself immediately.

**Didn't work: first draft without verification.** The initial
priority-escalation-policy.md contained fabricated claims about Doug
Lea's position on per-task priorities (his paper says the opposite),
wrong libdispatch queue count (6 instead of 12), and an imprecise
Sha-Rajkumar-Lehoczky bound attribution (conflated PIP and PCP).
These would have been propagated into design decisions if not caught.

**Didn't work: SE number from the handoff.** The handoff cited SE-0470
for priority escalation; it's actually SE-0462 (SE-0470 is
global-actor isolated conformances). Propagated into v0.1.0 and v0.2.0
before being caught by a verification agent. Handoff claims need the
same verification discipline as everything else.

## Patterns and Root Causes

**Pattern: training-data confidence vs. primary-source accuracy.** The
AI generates plausible-sounding claims about well-known systems (Tokio,
Go, Java) with high confidence. Several of these were wrong or imprecise.
The root cause is not hallucination per se — it's that the training data
contains secondary sources (blog posts, summaries, course notes) that
themselves contain errors, and the model reproduces those errors
confidently. The fix is structural: always verify against primary sources
(the actual source code, the actual paper, the actual man page) before
committing claims to a research note. The `[Verified: YYYY-MM-DD]` tag
pattern enforces this.

**Pattern: peer review surfaces architectural blindspots.** The authoring
agent designed `Executor.Cooperative` as a simple condvar drain loop
without `runUntil` or `SchedulingExecutor` conformance. The peer review
identified that (a) `runUntil` IS the direct backend for
`swift_task_donateThreadToGlobalExecutorUntilImpl`, so not having it
makes the executor invisible to the runtime's donation path, and (b) not
conforming to `SchedulingExecutor` makes `Scheduled<Cooperative>` spawn
a thread the user didn't want. Both are architectural — you don't see
them from inside the implementation; you see them from the perspective
of a system integrator.

**Pattern: spikes kill bad designs cheaply.** The alignment spike was
12 lines of Swift and took 2 minutes to write/run. It killed a design
(`CacheLine.Padded<T>` via `@_alignment(128)`) that would have consumed
hours of implementation before failing at the same compile error. The
cost-benefit ratio of small spikes is extreme.

## Action Items

- [ ] **[skill]** research-process: Add guidance that Tier 2+ prior art surveys MUST use parallel subagent verification against primary sources before writing claims. The `[Verified: YYYY-MM-DD]` tag on each load-bearing claim should be a MUST, not a SHOULD. Cite this session's correction as provenance.
- [ ] **[package]** swift-executor-primitives: File a Swift compiler issue for raising `@_alignment` above 16. The ecosystem needs `@_alignment(64)` minimum (x86 cache lines) and `@_alignment(128)` (Apple Silicon). Current cap of 16 forces `posix_memalign` workarounds.
- [ ] **[research]** Investigate whether the `Scheduled<Cooperative>` SchedulingExecutor conformance (Q6 in cooperative-donation-contract.md) can reuse the existing `Executor.Job.Priority` min-heap, or needs a two-clock variant matching the scheduled-executor-policy clock-generality recommendation.
