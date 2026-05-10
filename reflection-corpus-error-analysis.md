# Reflection Corpus Error Analysis

<!--
---
version: 1.0.0
last_updated: 2026-05-10
status: REFERENCE
tier: 2
scope: cross-package
---
-->

## Context

Recommendation #3 of `agent-harness-engineering-comparative-analysis.md`
v1.1.0 narrowed the v1.0.0 "eval harness seed" recommendation to a
single deliverable: *error-analysis on the reflection corpus* (Husain;
survey §3.16). Per [BET-EVAL] in `swift-institute-core`, the workspace
explicitly rejects LLM-as-judge eval, benchmarks against its own
harness, and any auto-mutation loop. Error-analysis on real traces —
where the *real traces* are `Research/Reflections/*.md` — is the only
form of measurement the workspace authorizes.

This document captures:
1. The analysis tool (`Scripts/reflection-corpus-analysis.py`).
2. The baseline snapshot (2026-05-10).
3. Findings the snapshot surfaces, including the most-actionable one.

## Question

What does the reflection corpus look like in aggregate, and what
signals does it carry about the [REFL-PROC-011] convergence-monitoring
discipline?

## Analysis

### The tool

`Scripts/reflection-corpus-analysis.py` reads
`Research/Reflections/*.md` (excluding `_`-prefixed files), parses YAML
frontmatter, and computes:

| Metric | What it measures |
|--------|------------------|
| Triage-outcome category frequency | Distribution of `triage_outcomes[].type` values across the whole corpus |
| Skill-update target distribution | When `type == skill_update`, which skills are most-targeted |
| Package frequency | Which packages the reflections most reference |
| Status distribution | `processed` vs `pending` vs other |
| Processing latency | Days from reflection `date` to `processed_date` |
| Convergence health (last 10) | [REFL-PROC-011] signals on the rolling-window of the last 10 processed entries |
| Unprocessed reflections | Entries where `status != "processed"` |
| Cadence-log integration | Cross-references the Wave-2 `.cadence.log` against captured reflections |

Output forms: default markdown to stdout; `--json` for machine
consumption; `--quiet` for an exit-code-only health check.

Exit code: 0 if all convergence signals are OK; 1 if any WARN per
[REFL-PROC-011].

### Baseline snapshot (2026-05-10)

Reflections analyzed: **278** (corpus has 312 markdown files; 34 are
non-reflection markup like `_index.json`, `_pre-pass-*.md`, or files
without parseable frontmatter).

| Outcome type | Count | Form |
|--------------|------:|------|
| `skill_update` | 169 | Canonical |
| `no_action` | 48 | Canonical |
| `package_insight` | 43 | Canonical |
| `mixed` | 39 | Canonical (single-line summary form for multi-outcome reflections) |
| `research_topic` | 38 | Canonical |
| `SkillUpdate` | 12 | **Drift** — PascalCase variant of `skill_update` |
| `informational` | 11 | **Drift** — non-canonical type |
| `experiment_topic` | 8 | Canonical |
| `ResearchTopic` | 5 | **Drift** — PascalCase |
| `NoAction` | 5 | **Drift** — PascalCase |
| `doc_improvement` | 4 | Canonical |
| `research_update` | 4 | **Drift** |
| `PackageInsight` | 3 | **Drift** — PascalCase |
| `blog_idea` | 2 | Canonical |
| `research` | 2 | **Drift** |
| `doc`, `package_research`, `feedback_memory`, `research_complete`, `package_action`, `doc_update` | 1 each | **Drift** |

Top skill-update targets: `implementation` (30), `handoff` (15),
`code-surface` (14), `audit` (12), `supervise` (12), `memory-safety`
(10), `skill-lifecycle` (9). These five carry the largest evolutionary
load.

Top reflected packages: `swift-io` (55), `swift-institute` (47),
`swift-iso-9945` (46), `swift-kernel` (40), `swift-kernel-primitives`
(34). Active-focus areas through 2026-04 / 2026-05.

Status: 269 processed, 8 pending, 1 SUPERSEDED (one entry tombstoned).

Processing latency: median 2 days, mean 2.73 days, range 0–14 days,
same-day-processing 24.5%. Within the [REFL-PROC-001] cadence
expectation (process at 3+ pending, MUST NOT during active
implementation).

Convergence health on the last 10 processed entries:

- ⚠ `skill_update` fraction 0% (floor 10%)
- ⚠ 63 consecutive entries without `research_topic` (threshold 10)
- ✔ `no_action` fraction 0% (cap 50%)

### Most-actionable finding

**Triage-outcome type taxonomy has drifted.** 21 distinct type strings
appear across the corpus where the [REFL-PROC-003] canonical set names
8 (skill_update, doc_improvement, research_topic, package_insight,
blog_idea, experiment_topic, no_action, mixed). 13 of the 21 are
non-canonical: PascalCase variants (`SkillUpdate`, `ResearchTopic`,
`NoAction`, `PackageInsight`) and ad-hoc types (`informational`,
`research_update`, `feedback_memory`, `package_action`,
`research_complete`, `doc`, `package_research`, `doc_update`,
`research`).

**Why this matters for convergence monitoring**: the WARN signals on
the last-10-window — `skill_update` fraction 0% and 63 entries without
`research_topic` — are partially **measurement artifact**. Recent
reflections use the single-line "`type: mixed` + multi-outcome
description" form. Inside the description text are
`SkillUpdate [BLOG-023]`-style mentions that the script does not count
because it only reads the structured `type:` field. The convergence
signals are honest about what the structured fields say but
under-represent what the corpus actually contains.

**Two correct responses**:

1. *Forward*: refactor reflect-session output to either (a) always emit
   one structured outcome per skill/research/package event and reserve
   `mixed` for genuinely cross-cutting cases, or (b) parse the
   description text for canonical outcome mentions. Option (a) is
   cheaper and more robust.

2. *Backward*: a one-time canonicalization pass would normalize the 13
   non-canonical type strings — but per [BET-EVAL] this should be
   human-driven via reflections-processing, not script-driven.

### Cadence-log integration (Wave 2 #2 ↔ Wave 3 #3)

The script reads `Research/Reflections/.cadence.log` (Wave 2 SessionEnd
hook output) and cross-references its entries against captured
reflections by date. As of the baseline snapshot, the cadence log
contains exactly 1 entry — the smoke-test entry from when the hook
script was first installed. Production data accrues from the next
session-close onward.

The cross-reference logic is the substrate for a future signal:
*"sessions ending without reflection capture exceeding {threshold}
warrants reflect-session invocation"*. Out of scope for the present
analysis; deferred to a Wave-4 follow-up if the signal becomes
load-bearing.

## Outcome

**Status: REFERENCE.**

The analysis tool is now the workspace's first error-analysis
substrate per Husain. It reads real traces (the reflection corpus),
emits structured signals (frequency tables + convergence WARNs),
remains decision-support not decision-replacement, and composes with
the Wave-2 cadence log without binding either side.

**Direction items surfaced (each pending user authorization)**:

1. *reflect-session canonicalization rule.* The 13 non-canonical type
   strings indicate a discipline gap in `[REFL-001]` or
   `[REFL-PROC-003]` enforcement at reflection-write time. A single
   skill rule could canonicalize: *"`triage_outcomes[].type` MUST be
   one of {canonical 8}; multi-outcome reflections MUST emit one
   structured outcome per discrete event, with `mixed` reserved for
   genuinely cross-cutting cases."*

2. *9 backlog reflections.* Pending entries from 2026-03-22 →
   2026-05-04 (oldest 49 days). Above the [REFL-PROC-001] threshold of
   3 pending. A reflections-processing run is overdue.

3. *Periodic re-run of analysis.* Per [REFL-PROC-013] (every 20+
   processed entries), the absorptive-capacity audit becomes
   automatable via the script. A SkillUpdate to
   `reflections-processing` could cite the script as the canonical
   tool for this audit.

These three are direction items, not auto-actions. Per [BET-EVAL] the
script informs human decisions; it does not drive them.

## References

- `agent-harness-engineering-comparative-analysis.md` v1.3.0
  Recommendation #3 (narrowed scope per v1.1.0).
- `agent-harness-engineering-state-of-the-art.md` §3.16 (Husain on
  error-analysis on real traces).
- `swift-institute/Skills/reflect-session/SKILL.md` [REFL-001].
- `swift-institute/Skills/reflections-processing/SKILL.md`
  [REFL-PROC-003], [REFL-PROC-011], [REFL-PROC-013].
- `swift-institute/Skills/swift-institute-core/SKILL.md` [BET-EVAL].
- `Scripts/reflection-corpus-analysis.py` (the tool).
- `Research/Reflections/.cadence.log` (Wave 2 SessionEnd hook output).
