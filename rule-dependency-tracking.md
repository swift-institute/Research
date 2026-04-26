# Rule Dependency Tracking — Skill Rules and Implicit Assumptions

Date: 2026-04-26
Scope: ecosystem-wide (all skill rules with non-trivial dependencies on assumptions, prior rules, or external artifacts)
Tier: 2 (cross-skill, infrastructure proposal, reversible precedent)
Status: IN_PROGRESS — failure-mode evidence collected; mechanism proposal pending design review
Provenance: Reflection `2026-04-24-meta-process-cascade-reflections-to-handoff.md` action item H2 (rule-about-rules staleness; [META-005] obsoleted by 2026-04-18 JSON-index migration without auto-detection).

---

## Context

Skill rules in the swift-institute corpus accumulate two kinds of dependencies:

1. **Rule-to-rule cross-references** — explicit citations between rules (`[FOO-001]` references `[BAR-002]`). Skills already track these via the `Cross-references:` field in each rule.
2. **Rule-to-assumption dependencies** — implicit assumptions about ecosystem state: catalog views (`ls` output, JSON-index structure), tooling availability (sync scripts, build infrastructure), file-layout conventions, naming conventions in dependent packages. Skills do NOT currently track these.

The 2026-04-24 corpus-meta-analysis sweep surfaced the cost of untracked assumption dependencies. `[META-005]` (introduced 2026-03-10) was a rule about archival of SUPERSEDED research docs based on `_archived/` subdirectory threshold-based promotion. The rule rested on an implicit assumption: that `ls swift-institute/Research/` was the canonical view consumers would use to navigate the corpus, and that visual-noise reduction was the design goal.

On 2026-04-18, the JSON-index migration (`08c3ef1`) replaced `ls`-based navigation with `_index.json`-driven catalog navigation. The migration made `status` a first-class filter dimension; SUPERSEDED docs no longer create visual noise because consumers filter by status. `[META-005]`'s underlying assumption was obsoleted. The rule was not re-read because nobody applied it for 40 days; staleness was caught only when the corpus-meta-analysis sweep mechanically tested the rule against current ecosystem state.

Cross-references would not have caught this. `[META-005]` had no explicit citation to "the `ls` view" or "the visual-noise model"; the assumption was implicit. The 40-day staleness window is the cost of untracked assumption dependencies.

---

## Question

Should skill rules declare explicit rule-to-assumption dependencies, and what mechanism would the declaration use?

Sub-questions:

1. What kinds of assumptions are load-bearing enough to track? (Catalog views, naming conventions, tooling presence, schema versions, ...)
2. What's the declaration syntax? (Frontmatter field, in-rule field, side-table, ...)
3. What's the change-detection mechanism? (Manual review on assumption change, mechanical script, CI check, ...)
4. How does the system handle dependency discovery for existing rules? (Backfill pass, on-touch annotation, defer to future incidents, ...)

---

## Analysis (stub)

### Failure modes the system would catch

| Assumption type | Example | Catch mechanism |
|----------------|---------|-----------------|
| Catalog view | `ls`-based vs JSON-indexed | When the catalog mechanism changes, all rules depending on the old view auto-flag |
| Tooling presence | `sync-skills.sh` script availability | When the script is renamed/replaced, rules depending on it auto-flag |
| Schema version | `_index.json` schema 1.0 vs 2.0 | When schema changes, rules referencing schema 1.0 auto-flag |
| Naming convention | `Array.Static<let capacity: Int>` vs `<let N: Int>` | When the convention is codified differently (per `value-generic-parameter-naming-convention.md`), dependent rules auto-flag |

### Candidate mechanisms

| Mechanism | Where | How |
|-----------|-------|-----|
| (a) Frontmatter `depends_on_assumption:` field | Top of each SKILL.md | Each skill declares the assumptions its rules rest on; declarations name an assumption ID + canonical doc |
| (b) Per-rule `**Assumes**:` field | Inside each rule | Rule-by-rule precision; tighter coupling but more authorship cost |
| (c) `Scripts/check-rule-assumptions.sh` | Workspace-wide | Greps for named assumptions; when an assumption artifact changes, flags dependent rules; runs on schedule or on-demand |
| (d) Formal dependency graph in `swift-institute-core` | Meta-skill | Centralized registry of assumptions; rules declare which assumptions they depend on by ID |

Combinations are plausible: (b) declarations + (c) script for checking + (d) registry for discovery.

### Implicit-assumption candidates to consider

| Assumption | Currently implicit in | Proposed ID |
|-----------|----------------------|-------------|
| `_index.json` is the canonical catalog view | `[META-005]` (now obsolete), `[RES-003c]`, `[AUDIT-009]` | `ASSUMPTION-CATALOG-001: JSON-indexed corpus navigation` |
| `sync-skills.sh` exists and runs from swift-institute | Multiple `[SKILL-CREATE-*]` rules | `ASSUMPTION-TOOLING-001: skill sync infrastructure` |
| Multi-file skills use `Skills/<skill>/*.md` layout | `[SKILL-CREATE-005a]` | `ASSUMPTION-LAYOUT-001: multi-file skill structure` |

Authoring assumption IDs feels heavyweight; the cost is real and recurrent. The alternative (untracked assumptions, manual sweeps catch staleness eventually) is the current ecosystem state, and its cost is also real (40-day staleness window per the [META-005] incident).

---

## Outcome (placeholder)

Pending design review. Expected recommendation shape options:

| Option | Mechanism | Authoring cost | Detection cost |
|--------|-----------|----------------|----------------|
| Lightest | Optional `**Assumes**:` field per rule (no enforcement); manual sweep on assumption change | Near-zero | High (manual sweeps) |
| Medium | `depends_on_assumption:` frontmatter field (whole-skill); `Scripts/check-rule-assumptions.sh` flags drift | Low (one declaration per skill) | Low (script runs on demand) |
| Heaviest | Formal dependency graph in `swift-institute-core`; per-rule `assumptions:` field; CI check on every assumption change | High (rule-level authoring) | Lowest (mechanical detection on every change) |

The medium option likely strikes the best balance — assumption declarations at the skill level (not per-rule) with a script-based check that runs on demand. The lightest option preserves status quo with optional documentation; the heaviest is overengineered for the current corpus size.

The recommendation's load-bearing decision factor is the cost of authoring rule-level assumptions across the existing 35 skills (one-time backfill); if that cost is bounded (say, 1-2 hours per skill), the medium option is viable. If it's higher, the lightest option (optional documentation, no enforcement) is the floor.

---

## Cross-references

- Reflection: `2026-04-24-meta-process-cascade-reflections-to-handoff.md` (Pattern 1 — rules-about-rules are most staleness-prone; [META-005] origin incident)
- Skill rule (related): [SKILL-LIFE-005] Mechanical `last_reviewed` Drift Check (mechanical-check approach for skill-level drift; analogous mechanism class for rule-level drift)
- Companion: `corpus-meta-analysis` skill ([META-*]) — currently the catch-all detection mechanism for staleness; this Doc proposes an earlier-firing alternative.
- Catalog migration that obsoleted `[META-005]`: 2026-04-18 JSON-index migration (`08c3ef1`)
