---
date: 2026-05-17
session_objective: Continue byte-ecosystem work after byte arc closed; land R4 ASCII.Code experiment as first non-Byte capability-marker conformer
packages:
  - swift-byte-primitives
  - swift-byte-parser-primitives
  - swift-parser-primitives
  - swift-parser-machine-primitives
  - swift-ascii-parser-primitives
  - swift-ascii-primitives
status: pending
---

# Byte Arc Continuation: ASCII.Code Landing and Triage-Roadmap Authorship

## What Happened

Session resumed the byte-ecosystem work after the byte arc's main wave closed
2026-05-15/16 (Byte primitive extraction, LargerDomain.Subdomain naming,
Per-Domain Capability-Marker Protocol promotion, Parser.Input.* sister cleanup,
cohort rename via SwiftPM `exclude` ICE workaround).

Concrete outputs of this session:

1. **Three handoffs authored at workspace root**:
   - `HANDOFF.md` (sequential) — byte-ecosystem continuation, tiered Next Steps by bandwidth, 7 cemented decisions, dead-ends, open questions, constraints, copy-pastable resume prompt per [HANDOFF-011]
   - `HANDOFF-byte-arc-followups.md` — 9-item deferred queue (items 2 + 7 marked RESOLVED in-session, 7 live)
   - `HANDOFF-byte-arc-next-phase-triage.md` — 21-item triage matrix, KEEP/DROP/DEFER per item, parallel groups A–D, dispatch order
   - Prior unrelated `HANDOFF.md` (swift-linter rule corpus Wave 6) preserved as `HANDOFF-rule-corpus-iteration-waves-1-6.md` per [HANDOFF-009] unrelated-prior-task collision branch
   - Two deleted on landing: `HANDOFF-byte-extraction-arc.md` (original 3-wave plan, state preserved in git + research docs), `HANDOFF-byte-protocol-capability-marker.md` (Tier 3 question, superseded by Research doc)

2. **R4 dispatched and landed**: ASCII.Byte renamed to ASCII.Code, adopts Byte.Protocol via one-line conformance. Subordinate landed at `be7c1fe` on swift-ascii-primitives. The rename also retired `rawValue` field in favor of `underlying` (per Carrier.Protocol sibling form), with audit doc retired at `04d2035`.

3. **Naming axis adjudicated**: subordinate surfaced the ASCII.Byte vs ASCII.Code question late in the arc. Principal settled on ASCII.Code (avoids semantic collision with the new Byte primitive — ASCII codes are *encoded* in bytes but are not themselves the byte primitive's domain).

4. **Triage-table errors documented**: HANDOFF-byte-arc-next-phase-triage.md gained a `## D2 final cost trajectory` section recording two wrong classifications (S → M-cohort → L-investigation arc), the empirical refutation of Path A and Path A-revised, and the institutional lessons for triage discipline.

5. **Dep-surface tier shift**: swift-ascii-primitives now depends on swift-byte-primitives (`.package(path: "../swift-byte-primitives")`). This is a non-obvious side effect of capability-marker conformance — adopting Byte.Protocol shifts the conforming package's tier in the primitives DAG.

## What Worked and What Didn't

**Worked**:
- **Tiered Next Steps by bandwidth** in HANDOFF.md (~30 min experiment / ~half day arc / ~multi-day arc) gave principal clear bandwidth-matched decision matrix; principal picked R4 cleanly.
- **Triage matrix with parallel groups** (KEEP/DROP/DEFER × Groups A–D) made dispatch sequencing legible without requiring re-investigation of each item's scope.
- **Subordinate's question-of-the-day pattern** (commit-shape Q, scope-refinement Q, ASCII.Byte naming Q) caught defects in orchestrator scope-definitions early. Subordinate refused to silently disambiguate.
- **Capability-marker recipe [API-NAME-001c] survived first stress test**: ASCII.Code conformance landed in one line without recipe amendment. The Byte.Protocol sibling-form refactor (Carrier sibling, Domain associatedtype, byte: Byte accessor + init) holds for a non-Byte conformer.
- **HANDOFF-009 unrelated-prior-task branch worked smoothly**: prior unrelated HANDOFF.md preserved via topic-rename, new HANDOFF.md written for current task, dead-end note in new file pointing at the rename.

**Didn't work**:
- **Three orchestrator recommendations were structurally wrong** before subordinate validation: Path A (ICE workaround via file-split), Path A-revised (file-split with restored typealias, file-private Cursor), Option 4 (separate library target for parser declarations). Each was caught — first two by subordinate empirical testing, third by principal's [MOD-DOMAIN] veto. The orchestrator was reasoning from a model (file-scope trigger, separate-target acceptable) that didn't match empirical reality (target-wide trigger, [MOD-DOMAIN] violation).
- **Triage cost underestimation**: D2 classified as S/single-subagent/Group A. Actual cost was M-cohort across 3 packages, then L when the ICE investigation surfaced. Pattern: triage based on single-package surface inspection misses cross-package shared-scaffolding consumers.
- **ASCII.Byte vs ASCII.Code question surfaced late**: should have been part of original R4 scope-definition in the triage matrix, not a subordinate clarification question after dispatch. The triage row "R4: ASCII.Code conformance to Byte.Protocol" baked in the name without considering the semantic-collision question.

## Patterns and Root Causes

**Orchestrator-vs-subordinate verification asymmetry**. The orchestrator reasons from architectural models (file-scope vs target-wide, [MOD-DOMAIN] applicability, capability-marker recipe shape). The subordinate reasons from local empirical tests (does this file-split actually eliminate the ICE? does this target-creation actually pass [MOD-DOMAIN]?). When the orchestrator's model is wrong, only the subordinate's empirical test catches it. This session had three model-error catches (Path A, Path A-revised, Option 4); the cost in each case was an investigation re-run that the right discipline would have avoided. The discipline: orchestrator MUST mark architectural recommendations as "pending subordinate empirical validation" and MUST NOT bake them into next-wave dispatches until validation lands.

**Triage cost classification systematically underestimates cross-package shared-scaffolding work**. The S/single-subagent classification assumed single-package surface. The actual surface was a 3-package cohort sharing the parameterized-typealias scaffolding pattern. When the underlying scaffolding is shared across consumers, the cost is consumer-count × per-consumer cost, plus the cost of discovering which consumers are affected. The triage rule needs a "cross-consumer grep" step before assigning S vs M.

**Dep-surface tier shift as non-obvious capability-marker side effect**. Conforming X to Byte.Protocol shifts X's package tier downstream in the primitives DAG. swift-ascii-primitives moved from Tier 0 (no byte-primitives dep) to Tier 2 (depends on swift-byte-primitives via swift-tagged-primitives or directly). This is structurally inherent to the recipe — capability-markers carry their domain types as associated types, which carry their owning packages as dependencies — but it's not flagged in [API-NAME-001c]'s research doc. Future capability-marker conformers will trigger the same tier shift; the research doc should call this out so adopters can plan around the structural dep their adoption introduces.

## Action Items

- [ ] **[skill]** issue-investigation: Codify orchestrator-vs-subordinate empirical-recommendations discipline. When orchestrator recommends a workaround or architectural change based on an architectural model (file-scope trigger, structural acceptability, etc.), the recommendation MUST be marked "pending subordinate empirical validation" and MUST NOT be baked into next-wave dispatches until validation lands. Three wrong recommendations this session (Path A, Path A-revised, Option 4) all caught by subordinate or principal; the cost was investigation re-runs. Provenance: this reflection.
- [ ] **[skill]** experiment-process OR research-process: Add "cross-consumer grep" step to S→M triage classification. Single-package surface inspection systematically underestimates cost when the item touches cross-package shared scaffolding (parser-input, byte-primitives, parameterized-typealias patterns). D2 cost trajectory in `HANDOFF-byte-arc-next-phase-triage.md` (S → M-cohort → L-investigation) is the canonical case study. Provenance: this reflection.
- [ ] **[doc]** `swift-institute/Research/byte-protocol-capability-marker.md`: Amend v1.1.0 with dep-surface tier shift pattern. Conforming X to Byte.Protocol shifts X's package tier downstream in the primitives DAG (e.g., swift-ascii-primitives Tier 0 → Tier 2 after ASCII.Code adoption). Structurally inherent to the recipe but non-obvious to first-time adopters. Should be flagged in [API-NAME-001c]-adjacent research so adopters can plan around the dep their adoption introduces.
