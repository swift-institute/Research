---
date: 2026-05-07
session_objective: Supervise the swift-linter ecosystem cohort sequence (modularization + architecture + cleanup + Day 3 streams + research + v1 fix) and dispatch the inventory + planning successor handoff
packages:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-primitives/swift-manifest-primitives
  - swift-primitives/swift-linter-primitives
  - swift-primitives/swift-tagged-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: skill_update
    target: supervise
    description: "[SUPER-031] CI-Failure Attribution from Aggregator Output added"
  - type: skill_update
    target: handoff
    description: "[HANDOFF-043] Multi-Cohort Orchestration Pattern added"
  - type: informational
    target: release-readiness
    description: "Code-sample-compile gate research subsumed by [RELEASE-007] Empirical Example-Compile Gate"
---

# Supervisor Seat — swift-linter Cohort Orchestration (2-day sprint)

## What Happened

Two-day intensive supervisor seat orchestrating the swift-linter ecosystem cohort sequence. Three sequential cohorts shipped:

1. **Modularization cohort** (Phase 2 file-based-canonical migration): 17 commits across 4 repos. Single-file Lint.swift consumer + parent-chain inheritance via `// parent:` URL.
2. **Architecture cohort** (Phase A PoC + B.1 decouple + B.4 wave-1 migration): 11 commits across 8 repos. Engine decoupled from rule packs; Lint/ nested SwiftPM package mechanism; consumer's Lint/ executable IS the linter binary.
3. **Code-surface cleanup cohort** (5 flags): 8 commits across 6 repos. `_ParentBox` → `Reference<T>`, compound-name renames, unused imports, Resolver test backfill, production `compound_identifier` violation suppressed-with-citation.

Plus Day 3 streams (parallel-capable):
- Stream 1: removed per-package lint workflow from tagged-primitives (~10 min).
- Stream 2: 4 polish items (skill update + 3 readmes + research doc on canonical-tier rule activation).
- Stream 3: Tier 2 research dispatch on consumer-facing syntax + v1 implementation fix (drop redundant Manifest declaration in PoC; ~50 lines deleted).

Total: 30+ commits across 8 repos shipped over 2 days. AI-harness mission's first concrete catalog landed: 11 institute rules (R1-R5 carry-forward + ResultBuilder + 7 wave-1 from skills/memory) + 1 domain-aware custom rule. R5 = 27-hit invariant on swift-tagged-primitives preserved end-to-end across every phase boundary (8+ verification gates).

Final dispatch: pre-publishable inventory + planning investigation (read-only, ~5h subordinate work). Surfaced 4 critical pre-publishable defects (READMEs non-compiling, Lint.Driver workspace-path hardcode, missing READMEs, parent URL points to private repo) + 2 predicate-quality issues (Cardinal.Count scope-blindness, CompoundIdentifier description-exemption inconsistency) + 4 strategic A/B/C decisions for principal adjudication + recommended D1-D9 dispatch sequence.

Closing: succeeded the supervisor seat to the inventory chat (which becomes the next orchestrator). Wrote the role-transition instruction.

## What Worked and What Didn't

### What worked

- **Per-action authorization for public actions** held throughout. Every `gh repo create`, GitHub rename, push wave got an explicit user signal. This was the load-bearing safety net under deadline pressure.
- **Inter-phase intervention discipline** ([SUPER-007] boundary-triggered): supervisor reads subordinate report → verifies per [SUPER-009] → signs off or pushes back → subordinate resumes. The cohort's velocity came from compressing this loop while keeping each verification step honest.
- **Verification per [SUPER-009] read-the-artifact-not-the-summary**: caught real issues throughout. Phase 3a's `Lint.swift` literal in `evalParent` temp path; Phase 2.5b's helper duplication across two packages; Stream 3's leading-dot template defect. Each would have been silent regressions had verification been delegated to the subordinate's self-report.
- **Mid-cohort architectural insight handled correctly**: discovered the rules-as-first-class-plugin-packages pattern + Lint/ nested package shape during the modularization cohort; carved as separate architecture cohort rather than expanding modularization scope.
- **User's strict scope discipline** ("PRIVATE repos by default", "no tags", "per-action authorization") forced me to surface decisions explicitly rather than batch them. Slowed the cohort by maybe 10% and prevented at least 3 meaningful errors.

### What didn't work

- **CI failure attribution mistake**: when the user surfaced a failed GH Actions run, I read the aggregator JSON output (`{"lint": "success", ...}`) and concluded "our swift-linter workflow passed." User had to push back with a screenshot showing `swift-linter (Phase 1, advisory) FAILED`. The aggregator's `"lint"` entry was SwiftLint (existing institute tool), not swift-linter (our new tool). Names colliding with established tools demand explicit disambiguation; I rationalized "aggregator says lint passed" instead of reading the failed job's actual log.
- **Initial cost estimate for SwiftLint+swift-format absorption was wrong by ~10x**: I anchored on "build from scratch" instead of "copy and adapt from open source." User pushed back correctly; I reset to ~3-4 months for human-facing parity. Anchor-bias under the prior question's framing.
- **Scope expansion rationalization**: the 327-repo `.gitignore` propagation during PoC pivot was framed as "defense-in-depth ecosystem-wide canonical sync." I accepted-and-flagged rather than pushing back hard. The right move was reverting the 327-repo propagation cleanly + keeping only the canonical edit. User's pushback was correct.
- **Premise correction caught by subordinate**: research dispatch (Stream 3) discovered that BOTH `Lint.Manifest` AND `Lint.Configuration` types coexist by design at HEAD — my dispatching brief described only the older init-kwargs Manifest shape. The empirical state correction came from subordinate's grep, not from my own pre-dispatch verification.

## Patterns and Root Causes

### Pattern 1: under self-imposed deadline, scope discipline matters MORE not less

The user imposed a 2-day deadline at the architecture cohort's authorization moment. My instinct under deadline was to compress verification + accept scope expansions ("it works, ship it"). The user's per-action authorization discipline counteracted that pull. Without their explicit YES PUSH WAVE / YES CREATE PRIVATE / YES RENAME signals, I would have rubber-stamped at least 2-3 scope-expansions (the 327-repo propagation; the workflow-fires-red-on-every-push; the GH Actions live-test premature-ship). The discipline worked because it was *external* to the supervisor seat — the user held the rate-limit, not me.

This generalizes: when self-imposed deadlines compress decision time, the supervisor's verification-and-authorization gate is the structural compensation. Relaxing the gate to "make the deadline" inverts the relationship — you make a deadline you wouldn't have wanted to make if you'd seen what it cost.

### Pattern 2: aggregator output is summary, not evidence

The CI failure attribution mistake was a [SUPER-009] read-the-artifact-not-the-summary failure at supervisor level, applied to my own work. Aggregator JSON is a summary. The summary's terms ("lint") were ambiguous. The artifact (failed-job log) is unambiguous. I should have read the failed-job log first and only consulted aggregator JSON for cross-checks.

This generalizes to any supervised system where multiple components share generic names (lint vs SwiftLint vs swift-linter; build vs swift build vs xcodebuild; test vs swift test vs xctest). When verification depends on attribution, read the SPECIFIC failed-component's log; don't trust the aggregator's category label.

### Pattern 3: pre-publishable defects compound

The inventory dispatch surfaced 4 critical defects + 2 predicate-quality issues. None were architectural; all were authored under deadline pressure during the cohorts and would have hit first adopters. Worst was the README compile failures — every customer-facing example was broken. The cohort sequence prioritized correctness at the architectural level (R5 = 27-hit invariant preserved through 8+ verification gates) but READMEs got swept into the "polish" bucket without verification of the embedded code samples.

Lesson: deadline-mode "polish" passes need a code-sample-compile gate analogous to architectural verification. If the README has a code block, that code block compiles or it's a defect.

## Action Items

- [ ] **[skill]** supervise: codify the CI-failure-attribution rule — when reading aggregated CI output, the attribution step requires reading the specific FAILED JOB's log, not the aggregator's category labels. Adds [SUPER-XXX]: "When supervised work reports CI failure, supervisor MUST identify which specific job failed by reading that job's log directly. Aggregated outputs (job summaries, JSON dumps) use generic category labels (`lint`, `build`, `test`) that may collide with the names of distinct tools or matrix entries; trusting the aggregator label causes misattribution."
- [ ] **[skill]** handoff: codify the multi-cohort orchestration pattern that worked over the 2-day sprint — sequential cohorts with explicit terminal stamps + per-phase sign-off + carry-forwards table that names what each successor cohort inherits. The pattern delivered 30+ commits across 8 repos in 2 days with R5 invariant preserved end-to-end; worth capturing as a [HANDOFF-XXX] or [SUPER-XXX] entry.
- [ ] **[research]** Should pre-publishable polish dispatches include a code-sample-compile gate? Every swept-in README authored under deadline pressure had non-compiling code examples. Investigate: what's the cheapest mechanical check (swift -parse on extracted code blocks, doctest-style harness, or a CI step that fails on non-compiling code-fence content)?
