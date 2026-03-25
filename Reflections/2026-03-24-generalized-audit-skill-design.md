---
date: 2026-03-24
session_objective: Design and create a generalized /audit skill to eliminate orphan audit files and standardize audit output
packages:
  - swift-institute
status: pending
---

# Generalized Audit Skill — From 82 Orphans to One Canonical Location

## What Happened

Session set out to research, design, and create a generalized `/audit` skill. Started with a full ecosystem survey: 82 audit files across 7 naming patterns, 6 confirmed orphans, version pairs running backwards (v3.0.0 superseded by v2.0.0), prompt/result intermingling, and broken delta cross-references.

Produced a Tier 2 research document (`swift-institute/Research/generalized-audit-skill-design.md`) analyzing 5 design dimensions: output location, document structure, invocation/integration, lifecycle, and migration. Created the skill with 15 requirements [AUDIT-001–015].

Key design decisions:
- Single `audit.md` per scope level, sections per target skill, updated in place
- `/audit regarding /{skill}` loads requirement IDs and checks systematically
- Scope boundary: audits check compliance against requirement IDs; investigative work is Discovery research
- Broad-then-narrow routing for ecosystem-wide audits
- Consolidate-on-contact for migrating old files (no big-bang migration)

Deleted 12 files (3 workspace orphans, 6 prompt files, 3 scratch files). ~70 remaining old files migrate incrementally when their package is next audited.

## What Worked and What Didn't

**Worked well**: The self-review pass after initial drafting caught 5 substantive issues that would have been problems in practice: ecosystem two-level routing gap, scope boundary ambiguity, exemplar tension (swift-file-system audit.md is a refactoring journal, not a compliance table), unstated file scoping, unstated multi-skill output behavior. Writing the document first and then challenging it produced a better result than trying to get it right in one pass.

**Worked well**: The user's pushback on "remediation" terminology exposed that the two-level routing was framed around the wrong concept. The trigger for per-package audit.md isn't "fixing code" — it's "scoping a follow-up audit." Small terminology fix, large conceptual clarification.

**Didn't work**: Initial instinct was to batch-migrate all 82 files immediately. The user correctly identified that consolidate-on-contact is lower risk and wastes no effort on packages that may never be re-audited. Over-eagerness to "clean up everything now" would have produced a high-volume change with uncertain value.

## Patterns and Root Causes

**Process skill design follows a consistent pattern**: research-process, experiment-process, blog-process, and now audit all share the same structural DNA — location triage from [RES-002], index maintenance from [RES-003c], lifecycle states, and cross-skill integration points. The audit skill was designed faster because these patterns are now institutional. This is the skill ecosystem maturing: new skills compose from established infrastructure rather than inventing from scratch.

**The "regarding" parameter is a novel integration pattern**: No other process skill takes another skill as input. Research and experiments are self-contained. Audit is the first skill that *composes* with other skills at runtime — it loads a target skill's requirement IDs and uses them as evaluation criteria. This is a new kind of skill relationship (consumer, not dependency) that may apply elsewhere.

**Consolidate-on-contact vs big-bang migration**: The session initially leaned toward batch migration, then shifted to on-contact. The underlying pattern: when migrating from an unstructured to a structured system, prefer incremental migration triggered by use over upfront migration triggered by existence. This applies beyond audits — any time we introduce a new canonical location for existing scattered content.

## Action Items

- [ ] **[skill]** audit: After first real `/audit` run, verify [AUDIT-015] consolidate-on-contact works in practice — the procedure for reading old files, extracting findings, and deleting may need refinement based on the variety of old formats encountered
- [ ] **[skill]** research-meta-analysis: Add [META-*] check for audit.md staleness per [AUDIT-010] — meta-analysis currently doesn't know about audit sections
- [ ] **[research]** Should the "regarding" composition pattern (skill-as-input) be generalized? Other process skills could benefit — e.g., `/research regarding /memory` to scope research to memory-related concerns
