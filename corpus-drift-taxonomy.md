# Corpus Drift Taxonomy

<!--
---
version: 0.1.0
last_updated: 2026-05-10
status: IN_PROGRESS
---
-->

## Context

The `/corpus-meta-analysis` skill enumerates ~12 phases (1–12) covering distinct integrity checks across the Swift Institute corpus (Skills, Research, Experiments, Audits, Reflections, Documentation.docc, Blog). Each phase encodes one or more *checks* that detect a particular failure mode — e.g., orphaned files, stale `last_reviewed`, format-version mismatch, missing index entries.

The 2026-04-30 corpus-meta-analysis sweep (reflection: `Reflections/2026-04-30-corpus-meta-analysis-and-phase-11-completion.md`) surfaced and fixed at least five distinct drift modes in one session. The session's structural observation was that the skill's organization is **by phase** (when the check runs in the sweep) rather than **by drift class** (what the check is detecting). When a sweep surfaces drift, the writer must mentally reverse-engineer "which phase covers this?" — and the reverse mapping is not always 1:1.

This research enumerates the distinct drift classes observed in production corpus-meta-analysis runs to date, maps each to its detection mechanism and existing `[META-*]` rule, and identifies gaps where a drift class is observed but not yet covered by any phase.

## Question

**Primary**: What is the canonical taxonomy of corpus-drift modes across the Swift Institute corpus? For each drift class, what is the earliest signal (where it first surfaces), the canonical detection mechanism (regex / find / diff / parser), and the responsible `[META-*]` rule?

**Secondary**: Which drift classes are observed in production but lack a `[META-*]` rule? Which `[META-*]` rules cover hypothetical drift classes that have never been observed? Should the corpus-meta-analysis skill be reorganized by drift class instead of by phase?

## Analysis

### Observed drift classes (initial inventory from 2026-04-30 sweep)

| # | Drift class | Where first surfaced | Detection mechanism | Existing [META-*] rule | Status |
|---|-------------|---------------------|---------------------|------------------------|--------|
| 1 | Index-vs-disk drift | Phase 10 (Reflections index) | `diff <(ls *.md) <(jq -r '.reflections[].file' _index.json)` | [META-021] (Reflections index integrity) — partial; rule names file-presence but not the diff procedure | OBSERVED — fix landed via Python backfill in same session |
| 2 | YAML-status-vs-index-status drift | Phase 10 (Reflections index) | Per-file YAML parse + index status compare | None directly; subsumed under [META-021] in practice | OBSERVED — same backfill pass |
| 3 | Layer-level container forbidden | Phase 5 (Research relocation) | `find swift-{primitives,standards,foundations}/Research -type f` (anything found = violation) | [RES-002] forbids; [META-005] phase-5 covers detection | OBSERVED — `swift-primitives/Experiments/` orphan; rm in same session |
| 4 | Format-version drift (`_index.md` legacy) | Phase 5 / Phase 1a | `find . -name '_index.md' -path '*/Research/*'` | [RES-003c] forbids `_index.md`; [META-005] phase-5 covers detection | OBSERVED — 2 ecosystem repos still on `_index.md`; migrated to `_index.json` |
| 5 | Forbidden subdirectory | Phase 5 (Research relocation) | `find Research/_work -type f` | [RES-002] / [RES-002a] | OBSERVED — `meta-analysis-audit-2026-04-16.md` in `Research/_work/`; relocated to `Audits/` |
| 6 | ID-uniqueness violation | (cross-cutting; surfaces during edits) | `grep -hE '^### \[<PREFIX>-\d+[a-z]?\]' Skills/<skill>/SKILL.md \| sort \| uniq -d` | [REFL-PROC-016] (pre-commit ID-uniqueness scan) | OBSERVED — pre-existing `[EXP-017]` / `[EXP-018]` duplicates surfaced; renumber + ref-update |
| 7 | Stale `last_reviewed` | Phase 4 (Skills review) | Compare git mtime vs YAML `last_reviewed` field | [SKILL-LIFE-004] discipline; [SKILL-LIFE-005] mechanical check | OBSERVED — 17 skills with content newer than metadata after 2026-04-24 reflections-processing run |
| 8 | Stale IN_PROGRESS research | Phase 1a (Research staleness triage) | Date arithmetic on `last_updated` field; threshold-based | [META-002] blocker + resumption-trigger discipline | OBSERVED — 7 stale IN_PROGRESS docs; 1 promoted to RECOMMENDATION + 6 DEFERRED |
| 9 | Missing audit-doc home | Phase 5 (Audits surface) | `find . -name '*audit*.md' -not -path '*/Audits/*'` | [AUDIT-*] rules cover authoring; [META-005] phase-5 covers location | OBSERVED — same `Research/_work/` instance |
| 10 | Routing-table-vs-skill drift | Phase 12 inline (audit refresh) | Compare CLAUDE.md routing table IDs vs actual skill IDs | None directly; ad-hoc | OBSERVED — `[PATTERN-009-053]` cited; actual IDs are `[COPY-FIX-003]`–`[COPY-FIX-010]` |
| 11 | Cross-anchor-set divergence (handoff vs skill vs canonical) | (cross-cutting) | Compare regex variants across documents purporting to enforce same predicate | None | OBSERVED — `[META-022]` `// Result:` only; `[EXP-007a]` `(Toolchain\|Status\|Result\|Revalidated)`; handoff used third variant `(Result\|Status\|Revalidated\|Outcome)` |
| 12 | Parallel-session contamination | (cross-cutting) | Inspect git diff for files not edited in current session | [HANDOFF-023] reactive isolation discipline | OBSERVED — PID 81299 contamination on 9 files; isolated via specific paths |

### Initial observations

**Phase organization is mostly orthogonal to class**: phases 5 (relocation) and 10 (reflections index) each cover multiple drift classes (3, 4, 5 share phase 5; 1, 2 share phase 10). A class-organized skill would split these into separate sub-rules with distinct detection mechanisms.

**Some classes are cross-cutting and have no phase home**: ID-uniqueness violations (class 6), routing-table-vs-skill drift (class 10), cross-anchor-set divergence (class 11), and parallel-session contamination (class 12) surface anywhere — they don't fit the linear-phase model.

**Two patterns of [META-*] coverage**:
- **Direct**: a [META-*] rule exists and the detection mechanism is documented (classes 6, 7, 8 → [REFL-PROC-016], [SKILL-LIFE-005], [META-002]).
- **Subsumed**: a [META-*] rule exists at a phase level but the specific drift-class detection is implicit in the phase narrative (classes 1, 2 → [META-021]; classes 3, 4, 5 → [META-005] phase-5).
- **Gap**: no [META-*] rule covers the class (classes 9, 10, 11, 12).

### Open questions

**Q1**: Should [META-*] be reorganized by drift class? Or should the skill keep its phase organization and add a *cross-reference table* mapping drift class → phase that owns its detection?

**Q2**: Class 11 (cross-anchor-set divergence) is itself a meta-drift — three documents disagree on what the predicate is. Is this a single [META-*] rule (canonical authority enforcement) or a cross-skill discipline (every regex anchor MUST cite a single canonical authority)? Provenance suggests the latter, given the pattern reproduces across handoff/skill/canonical-authority triples.

**Q3**: Class 12 (parallel-session contamination) is currently covered reactively by [HANDOFF-023]. Should there be a proactive [META-*] rule (e.g., "before staging, diff against pre-session baseline")? Or is reactive isolation structurally sufficient given the multi-agent system has no inter-session signaling?

**Q4**: Are there drift classes observed pre-2026-04-30 that this initial inventory misses? The 2026-04-24 reflection (`meta-process-cascade-reflections-to-handoff`) and the 2026-04-15 collaborative-discussion reflection both touched corpus-health concerns; their drift classes should be folded in before this research closes IN_PROGRESS.

## Outcome

**Status**: IN_PROGRESS

**Initial inventory complete (12 classes)**. Open questions Q1–Q4 remain. Conversion to DECISION pending: (a) inventory pass against pre-2026-04-30 reflections (Q4), (b) decision on phase-vs-class organization (Q1), (c) gap-rule authoring for classes 9, 10, 11, 12.

**Resumption trigger**: this research advances when the next `/corpus-meta-analysis` run completes (which will surface either new classes or ratify the inventory) OR when a new skill update introduces a previously-unknown drift class.

## References

- Reflection: `swift-institute/Research/Reflections/2026-04-30-corpus-meta-analysis-and-phase-11-completion.md` (Pattern 3 — corpus-drift-comes-in-many-distinct-flavors)
- Reflection: `swift-institute/Research/Reflections/2026-04-30-phase-1b-stale-triage-and-deferred-fixed-codification.md` (Pattern 1 — detection-tooling drift between skills and handoffs; class 11)
- Skill: `Skills/corpus-meta-analysis/SKILL.md` (current phase organization)
- Skill: `Skills/skill-lifecycle/SKILL.md` ([SKILL-LIFE-004], [SKILL-LIFE-005] cover class 7)
- Skill: `Skills/reflections-processing/SKILL.md` ([REFL-PROC-016] covers class 6)
- Skill: `Skills/handoff/SKILL.md` ([HANDOFF-023] reactive coverage of class 12)
- Skill: `Skills/research-process/SKILL.md` ([RES-002], [RES-002a], [RES-003c] cover classes 3, 4, 5)
