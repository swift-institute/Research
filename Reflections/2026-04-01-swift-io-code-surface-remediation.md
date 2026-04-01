---
date: 2026-04-01
session_objective: Strict code-surface audit and full remediation of swift-io (40 findings, 5 phases)
packages:
  - swift-io
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: code-surface
    description: Added [API-NAME-004a] namespace adoption typealiases vs rename bridges
  - type: skill_update
    target: implementation
    description: Added [IMPL-082] scope resolution on extension extraction
  - type: package_insight
    target: swift-io
    description: Post-code-surface-remediation testing required (~120 files, 7 modules)
---

# swift-io Code Surface Audit and 5-Phase Remediation

## What Happened

Ran a strict `/audit regarding /code-surface` on swift-io (275 source files, 7 modules). Found 40 findings: 12 HIGH, 24 MEDIUM, 4 LOW. Dominant issue was [API-NAME-002] compound identifiers (101 total across all visibility levels) — [IMPL-024] was explicitly disabled, making all compound names violations regardless of visibility.

Executed a 5-phase remediation plan across 8 commits (~120 files touched):

- **Phase 1**: Structural — type body extraction (Selector.swift, Queue.Runtime.swift, 9 others), multi-type file extraction (Operation.Storage, Lane+threads), file naming fixes (3 renames, 2 header fixes). Hit scope resolution errors when moving methods from nested `extension IO.Event { struct Selector { } }` to `extension IO.Event.Selector { }` — sibling types lost implicit scope.

- **Phase 2**: Error/enum — EnqueueError → State.Error (1 call site), Backend cases `eventDriven` → `event` / `completionBased` → `completion`, Capabilities booleans → `Triggering`/`Model` enums + `Features` OptionSet.

- **Phase 3**: Public renames — Policy sub-structs (`lane.queue.limit`), `createWakeupChannel` → `wakeupChannel`, Backend `has*` → `available.*`, Threads public compound names.

- **Phase 4**: Internal renames — Metrics (14 properties → 5 nested sub-structs), Runtime.State methods, Selector.Runtime methods, Executor internals (~25), Blocking internals (~13), Blocking Threads remaining (~14). One agent took 24 minutes / 199 tool calls for the Executor + Threads batch.

- **Phase 5**: Typealias removal — Deadline cascade (4 typealiases, 44 call sites → `Clock.Suspending.Instant` / `Kernel.Time.Deadline`), IO.Pool / IO.Lane.Count / Deadline.Next removed. IO.Event initially converted to namespace enum, then **reverted** to typealias after research decision.

The IO.Event revert was the session's most significant design moment. Research document (`io-event-namespace-typealias-vs-enum.md`) analyzed 3 options. Decision: `IO.Event = Kernel.Event` is namespace adoption (permitted), not a rename bridge (forbidden). This creates a new convention distinction not previously in [API-NAME-004].

## What Worked and What Didn't

**Worked well**:
- Parallel agent launches for independent modules — Phase 1 completed 4 sub-tasks simultaneously
- Building after each phase caught errors early (scope resolution, missing Deadline refs)
- The phased plan (structural → error → public → internal → typealiases) was correct dependency order — no phase required undoing prior work

**Didn't work well**:
- Agent scope for Phase 4 was too large — the Executor+Threads agent did 199 tool calls over 24 minutes. Should have been split into 2 agents.
- Phase 5b (IO.Event enum conversion) was attempted by an agent that partially modified files before being rejected, leaving the build broken. The partial-modification-before-rejection pattern is a recurring risk with agents doing multi-file changes.
- Several agents missed scope resolution issues (sibling types losing implicit scope when moved to explicit extensions). This required manual fixup after each phase. The instruction "use FULL NAMES to disambiguate" was needed as a correction.

**Confidence assessment**: High confidence on Phases 1-4 (mechanical, well-understood patterns). Low confidence on Phase 5 (typealias policy) — the session oscillated between "remove all typealiases" and "namespace adoption is fine" before settling on the distinction via research.

## Patterns and Root Causes

**Pattern: Namespace adoption vs rename bridge**. The session surfaced a distinction that [API-NAME-004] doesn't make: `IO.Event = Kernel.Event` builds 52 types on a kernel concept (adoption), while `IO.Deadline = Clock.Suspending.Instant` just saves keystrokes (bridge). The convention should distinguish these. This is the session's most durable insight.

**Pattern: Scope resolution after extraction**. Moving code from `extension Outer { struct Inner { method() } }` to `extension Outer.Inner { method() }` loses implicit resolution of sibling types in `Outer`. This bit us twice (Selector.swift, Options.swift). The fix is always "use full names" — but agents don't anticipate this unless told explicitly. Root cause: Swift's name resolution depends on the lexical nesting depth of the extension, not just the fully-qualified type path.

**Pattern: Agent blast radius control**. Agents doing 100+ file changes in a single invocation are slow and fragile. The sweet spot is ~20-30 files per agent. Phase 4's Executor+Threads agent (199 tool calls) should have been 2 agents. The IO Events agent (Phase 4c+4d) was rejected by the user for taking too long, confirming this threshold.

## Action Items

- [ ] **[skill]** code-surface: Add [API-NAME-004a] distinguishing namespace adoption typealiases (extend a type's concept with domain behavior, permitted) from rename bridges (convenience renames, forbidden). Reference `swift-io/Research/io-event-namespace-typealias-vs-enum.md`.
- [ ] **[skill]** implementation: Add guidance on scope resolution when extracting methods from nested extension bodies to explicit `extension Outer.Inner { }` — sibling types need full qualification.
- [ ] **[package]** swift-io: Run `swift test` post-remediation and fix any test failures from the 120-file rename.
