---
date: 2026-04-01
session_objective: Extend research-meta-analysis skill with experiment corpus health checks, rename to corpus-meta-analysis
packages:
  - swift-institute
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: corpus-meta-analysis
    description: "Added [META-022]–[META-026], expanded [META-017], updated [META-019]/[META-013] phase numbering, renamed from research-meta-analysis"
  - type: skill_update
    target: skill-lifecycle
    description: "Reinforce: lifecycle compliance (provenance, classification, sync script) must be front-loaded, not retrofitted"
  - type: doc
    target: swift-institute
    description: "Phase renumbering in META-019 is a breaking change — any documentation referencing old phase numbers (e.g., 'phase 10') needs updating"
---

# Corpus Meta-Analysis — Closing the Experiment Coverage Gap

## What Happened

Gap analysis of the research-meta-analysis skill against the experiment-process
skill revealed that experiment lifecycle was only partially covered. The skill had
5 experiment-related sections (META-006/007/008/009/018) but missed 5 categories of
experiment-specific health checks that experiment-process defines or implies.

## Gap Analysis

| Gap | experiment-process IDs | What was missing |
|-----|------------------------|------------------|
| Experiment staleness | [EXP-008] lifecycle | No equivalent of META-001/002 for experiments stuck in Active state |
| Source-change revalidation | [EXP-006a] promotion | META-006 only triggered on toolchain changes, not package source changes |
| Investigation consolidation | [EXP-018] | META-016 covered research consolidation, not experiment consolidation |
| Discovery coverage | [EXP-012]–[EXP-017] | No check for milestone packages missing discovery experiments |
| Claim/assumption inventory | [EXP-013], [EXP-014] | No check for stale/orphaned [CLAIM-*]/[ASSUMP-*] IDs |

## Design Decision: Extend, Don't Split

Considered creating a separate experiment-meta-analysis skill. Rejected because:
- The existing skill already covered experiments at 5 checkpoints
- Splitting would create routing ambiguity (which meta skill to invoke?)
- META-019's sweep phases interleave research and experiment checks — splitting breaks sequencing
- Research–experiment linkage (META-018) is inherently bidirectional

## Changes Made

### Classification per [SKILL-LIFE-003]

| Change | Classification | Rationale |
|--------|---------------|-----------|
| META-022 through META-026 | **Additive** | New requirements; no existing code or process violates them |
| META-017 experiment scope migration tables | **Clarifying** | The old text said "also applies to experiments" — spelled out what that means |
| META-019 phase renumbering (10→13 phases) | **Breaking** | Existing phase numbers changed; references to "phase 10" now incorrect |
| META-013 report structure expansion | **Breaking** | Report sections changed to match new phase numbering |
| Rename research-meta-analysis → corpus-meta-analysis | **Breaking** | Skill name, directory, symlink, and all 12 cross-references changed |

The breaking changes (rename, phase renumbering) were discussed and approved by the
user before implementation. The rename was explicitly requested. The phase
renumbering was a necessary consequence of inserting new experiment phases into the
sweep sequence.

### Files Modified

- `swift-institute/Skills/corpus-meta-analysis/SKILL.md` — all content changes
- `Developer/CLAUDE.md` — routing table
- `swift-institute/Skills/swift-institute-core/SKILL.md` — skill index + loading order
- `swift-institute/Skills/audit/SKILL.md` — cross-reference
- `swift-institute/Skills/skill-lifecycle/SKILL.md` — 3 cross-references
- `swift-institute/Research/Reflections/2026-03-24-generalized-audit-skill-design.md` — triage target
- `swift-institute/Research/Reflections/2026-03-20-skill-system-overhaul-architecture.md` — 2 references
- `swift-institute/Research/generalized-audit-skill-design.md` — cross-reference

## What Surprised Me

The skill-lifecycle process was not followed during the initial implementation —
provenance wasn't cited, changes weren't classified, and the sync script was
bypassed for manual symlink creation. This was caught during self-review when the
user asked "did you follow /skill-lifecycle". The remediation (this reflection,
sync script run, full verification) was done retroactively. The lesson: lifecycle
compliance should be front-loaded, not retrofitted.

## Patterns Worth Remembering

**Extend-don't-split for tightly coupled domains**: When a skill covers domain A
partially and domain B fully, and A and B have bidirectional linkage, extending is
better than splitting. The routing cost of a second skill outweighs the organizational
clarity.

**Phase renumbering is a breaking change**: Inserting new phases into an ordered
sweep sequence breaks all downstream phase references. This is analogous to inserting
enum cases — it changes the meaning of existing values.
