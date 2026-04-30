# Recurring Handoff Triage as a Skill Candidate

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

The 2026-04-29 bulk-triage cycle executed a six-phase framework on 32 `HANDOFF-*.md` files at workspace root: metadata gathering → rubric → disposition matrix → extraction → deletion (gated on YES) → annotation → final report. The cycle ran end-to-end with explicit principal authorization on the deletion batch and produced a 43% reduction in workspace-root handoff churn (35 → 20 files; 15 deleted + 1 extracted + 6 annotated + 11 untouched + self-deletion of brief).

The framework was clean to execute, robust to scope drift, and exercised many existing skills ([HANDOFF-021], [HANDOFF-016], [HANDOFF-029], [REFL-009], [REFL-012], [AUDIT-005], [AUDIT-009], [AUDIT-002]) in sequence. The principal's advice during the cycle was that bulk triage should be roughly recurring at ~2-week cadence (per Path X completion timing). At that cadence, the brief-authoring cost each iteration is significant; a reusable codified version would amortize the framework's authoring across iterations.

This Doc scopes the question of whether to codify the framework as a skill (or absorb into an existing skill), and if so, what surface and shape.

## Question

Should the recurring-handoff-triage framework be codified as a skill (or absorbed into an existing skill)? If yes:

1. Where does it fit best — extension of an existing skill, or new skill of its own?
2. What is the skill's surface — what rules / procedures / dispositions does it codify?
3. How does it compose with the existing skill ecosystem?

## Analysis

### The framework's structure (observed)

The 2026-04-29 cycle's six-phase framework:

| Phase | Output | Skills exercised |
|-------|--------|------------------|
| 1. Metadata gathering | Per-file `lines` / `bytes` / `mtime` / refs | [HANDOFF-021] enumeration command |
| 2. Rubric | Q1–Q5 evaluation per file | [HANDOFF-016] work-staleness axes |
| 3. Disposition matrix | A / C / D / E / F / G classification per file | [REFL-009] cleanup-authority + [SUPER-014] block-location |
| 4. Extraction | Audit doc / research doc updates | [AUDIT-005] update-in-place + [AUDIT-002] location triage; [HANDOFF-032] extraction-time material check |
| 5. Deletion | Bulk `rm` (gated on YES) | [HANDOFF-029] pre-fire re-check; [REFL-012] state-check after |
| 6. Annotation | F-file `## Triage Status` sections | [REFL-009] status-update procedure |
| 7. Final report + self-deletion | Summary + counts; brief deletes self | [REFL-009] standard rule |

The framework is a sequenced composition of existing skills; no individual skill carries the whole framework, but each contributes a sub-procedure that the framework composes.

### Three options

#### Option A — Absorb into `handoff` skill as a `[HANDOFF-bulk-triage-*]` rules family

Add a new section to the handoff skill codifying the six-phase framework as a sequence of rules.

| Pro | Con |
|-----|-----|
| Handoff is the natural home for handoff-related operations | Bulk-triage is broader than single-handoff handling; may bloat the handoff skill's surface |
| Reuses handoff's existing audience (any agent doing handoff work) | The framework crosses into [REFL-*] (cleanup authority), [AUDIT-*] (extraction destinations); pulling those rules into handoff creates cross-skill coupling |
| Single skill addressable via existing routing | The framework is not a property of a single handoff; it's a multi-handoff orchestration |

#### Option B — Extend `reflect-session` with a bulk-triage variant

Extend [REFL-009] (Handoff Cleanup) with bulk-triage operating mode rules.

| Pro | Con |
|-----|-----|
| [REFL-009] already codifies single-handoff cleanup; bulk-triage is the multi-handoff extension | Reflect-session is invoked at session end; bulk-triage is a dedicated session type, not an end-of-session step |
| Cleanup authority discipline already lives here | Bulk-triage extracts to audit/research, not just cleanup; that's beyond reflect-session's existing scope |

#### Option C — Author a new skill (e.g., `bulk-handoff-triage`)

Create a dedicated skill with `[BHT-*]` rule prefix codifying the six-phase framework end-to-end.

| Pro | Con |
|-----|-----|
| Captures the framework's identity as a distinct workflow (not a property of single handoffs or a sub-step of reflection) | One more skill to route to and load |
| Allows codifying the framework's matrix (A–G dispositions, Q1–Q5 rubric, override priority rules) without polluting other skills | Marginal extra skill if the cycle is rare enough that ad-hoc dispatch suffices |
| Cleanly cross-references existing skills without absorbing them | Framework is currently observed once; codification might over-fit |

### Open analysis

| Question | Status |
|----------|--------|
| What is the actual cadence? "Roughly 2 weeks" was the principal's estimate; verify against subsequent cycles. | TODO — collect 2–3 more cycles before deciding |
| How much of the framework is universal vs cycle-specific? E.g., the brief's special-case override clause was unique to the 2026-04-29 context — is that part of the framework or part of that brief? | TODO — partition universal vs cycle-specific elements |
| Does the framework warrant codification before observing a second iteration? Premature codification is its own anti-pattern. | TODO — apply [RES-018] premature-primitive heuristic to skill creation |

## Outcome

**Status**: IN_PROGRESS

**Recommendation (preliminary)**: Defer codification until a second bulk-triage cycle is observed. The framework executed cleanly once; that's necessary but not sufficient evidence to codify. A second cycle will (a) test the framework's reproducibility, (b) surface the universal-vs-cycle-specific partition, and (c) confirm or refute the ~2-week cadence. The action items from the 2026-04-29 cycle ([REFL-009a] in-flight-file conservativism + [HANDOFF-032] extraction-time material check) are codified now; the framework-as-a-whole codification waits for the second iteration.

If after the second cycle the framework is still durable, Option C (new skill) is the preliminary preference because the framework crosses [REFL-*], [HANDOFF-*], and [AUDIT-*] without naturally fitting any single existing skill's surface.

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. Codifying or not codifying the framework affects skill discoverability for bulk-triage operations but is reversible (the framework can always be authored as a brief if no skill exists, and a poorly-fit skill can be deprecated).

### Update 2026-04-30 — Prevention-side complement landed

A second-cycle investigation landed today, but on the *prevention* side
rather than the *response* side: `swift-institute/Research/handoff-lifecycle-and-retention.md`
(v1.0.0 RECOMMENDATION) diagnosed why `[REFL-009]` does not prevent
HANDOFF-*.md accumulation in the first place (bounded-cleanup-authority
orphan zone is the dominant cause; HYP3/HYP4 sub-classes are real;
HYP1/HYP5 are partial/amplifiers) and shipped three skill amendments:

- `[HANDOFF-038]` HANDOFF Staleness Threshold (cadence rule, analog `[META-022]`).
- `[HANDOFF-039]` Predecessor Retirement at Dispatch (writer-side discipline).
- `[REFL-009]` stale-override exception clause.

These are prevention rules; this Doc's framework is a response framework.
They are complementary, not redundant. **Effect on this Doc's recommendation**:
the prevention rules reduce the cadence at which the bulk-triage framework
needs to fire. The principal's "~2-week cadence" estimate was based on the
pre-prevention orphan-zone growth rate; with `[HANDOFF-038]`/`[HANDOFF-039]`
catching accumulation at source, the framework's natural firing cadence
should slow toward "ecosystem-wide audit pass at semi-annual cadence or
major milestone" — not a routine 2-week sweep.

**Revised codification priority**: lower. The framework still has value for
ecosystem-wide periodic audits and as a one-time response when prevention
fails (e.g., a multi-month period where /reflect-session was skipped on
many sessions). But its primary use case (routine 2-week cleanup) is being
absorbed by the prevention rules. The decision to codify as a skill (Option C)
should wait until empirical observation: if the framework fires zero times
in the next 6 months under the new prevention rules, codification's value
proposition collapses and the doc should resolve as DECISION ("framework
remains an ad-hoc brief; not codified as a skill"). If it fires once or
twice in a way that's not adequately served by prevention, the codification
question reopens with cleaner evidence.

**Cross-reference**: `swift-institute/Research/handoff-lifecycle-and-retention.md`
v1.0.0 (2026-04-30, RECOMMENDATION) is the prevention-side complement;
neither doc supersedes the other.

## References

- Reflection: [Research/Reflections/2026-04-29-handoff-triage-cycle-and-d-to-a-reclassification.md](Reflections/2026-04-29-handoff-triage-cycle-and-d-to-a-reclassification.md) — origin instance; six-phase framework executed end-to-end on 32 `HANDOFF-*.md` files.
- Reflection: [Research/Reflections/2026-04-30-handoff-lifecycle-execution.md](Reflections/2026-04-30-handoff-lifecycle-execution.md) — prevention-side execution; the 2026-04-30 update above.
- Research: [handoff-lifecycle-and-retention.md](handoff-lifecycle-and-retention.md) — prevention-side complement (RECOMMENDATION v1.0.0).
- Triage table: `/Users/coen/Developer/HANDOFF-handoff-files-triage-and-cleanup-table.md` — durable record of the 2026-04-29 cycle.
- Skills: [REFL-009], [REFL-009a], [HANDOFF-013a], [HANDOFF-021], [HANDOFF-029], [HANDOFF-032], [HANDOFF-038], [HANDOFF-039], [AUDIT-005]
- Anti-pattern: [RES-018] premature-primitive heuristic
