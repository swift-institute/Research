# Skill Creation Process

<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: SUPERSEDED
---
-->

## Context

The Swift Institute skill system now includes 16 skills across 4 layers (meta, architecture, implementation, process). Adding a new skill correctly requires touching multiple files across multiple repos: the SKILL.md itself, swift-institute-core's index, CLAUDE.md files, and running the sync script.

Without a documented process, skill creation is error-prone: missing YAML fields, incorrect requirement ID prefixes, forgotten CLAUDE.md updates, broken dependency DAGs.

This research designs a `skill-creation` skill that guides Claude through adding new skills correctly.

## Question

What should a `skill-creation` skill contain to ensure new skills are added correctly and completely?

## Analysis

### Requirements Inventory

Based on the current infrastructure, skill creation involves:

**1. SKILL.md authoring**
- YAML frontmatter with required fields: `name`, `description`, `layer`, `requires`, `applies_to`
- Optional fields: `migrated_from`, `migration_date`
- Markdown content with requirement sections using `### [ID-CODE] Title` format
- Each requirement needs: Statement, code examples, rationale, cross-references

**2. Requirement ID assignment**
- Must be unique across all skills
- Must follow established prefix patterns or establish a new prefix
- Format: `[PREFIX-SECTION-NUMBER]` or `[PREFIX-NUMBER]`

**3. Dependency management**
- `requires:` must form a valid DAG (no cycles)
- Parent skills must exist before child skills can require them
- Minimum requirement: `swift-institute` or `swift-institute-core`

**4. Layer classification**
- `meta`: System manifest only (rare)
- `architecture`: Foundational conventions
- `implementation`: Code rules
- `process`: Workflows

**5. swift-institute-core updates**
- Add skill to Skill Index section
- Update Loading Order section if skill has dependents

**6. CLAUDE.md updates**
- Update `/Users/coen/Developer/CLAUDE.md` Skill Routing table
- Update relevant repo CLAUDE.md "Before Writing Code" sections

**7. Sync infrastructure**
- Run `sync-skills.sh` after creating the skill
- For self-managing repos (swift-institute, swift-primitives, swift-foundations): update relative symlinks and commit
- For script-synced repos (swift-standards): script handles it

**8. Verification**
- Symlink exists and resolves
- Skill can be invoked via `Skill` tool
- All cross-references valid

### Option A: Checklist-Only Skill

A skill that provides a comprehensive checklist without automation guidance.

**Structure:**
- List all steps in order
- Reference file paths
- Document gotchas

**Pros:**
- Simple to write
- Easy to maintain
- Human-readable

**Cons:**
- No validation logic
- Easy to miss steps
- No automation hints for Claude

### Option B: Procedure-Oriented Skill

A skill organized as a procedure with clear phases, validation checkpoints, and Claude-actionable instructions.

**Structure:**
- Phase 1: Planning (decide layer, ID prefix, dependencies)
- Phase 2: Authoring (SKILL.md structure with templates)
- Phase 3: Integration (swift-institute-core, CLAUDE.md updates)
- Phase 4: Sync (run script, verify symlinks)
- Phase 5: Verification (test invocation)

**Pros:**
- Phased approach reduces errors
- Checkpoints catch mistakes early
- Templates reduce authoring friction

**Cons:**
- More complex document
- More maintenance when infra changes

### Option C: Template + Rules Skill

A skill that provides a complete SKILL.md template plus rules for each decision point.

**Structure:**
- Complete YAML template with all fields
- Complete Markdown template with requirement structure
- Decision rules for layer, ID prefix, dependencies
- Integration checklist (kept minimal)

**Pros:**
- Template ensures structural correctness
- Decision rules reduce ambiguity
- Balance of guidance and simplicity

**Cons:**
- Template can drift from practice
- Rules may not cover edge cases

### Comparison

| Criterion | Option A: Checklist | Option B: Procedure | Option C: Template |
|-----------|---------------------|---------------------|-------------------|
| Completeness | Medium | High | High |
| Maintainability | High | Medium | Medium |
| Error prevention | Low | High | Medium |
| Authoring speed | Slow | Medium | Fast |
| Flexibility | High | Low | Medium |
| Claude-actionable | Low | High | Medium |

### Constraints

1. **Must be self-contained** — The skill should work without requiring external documentation
2. **Must handle both institute and repo-specific skills** — Different paths, same process
3. **Must integrate with existing sync infrastructure** — Not replace it
4. **Should promote consistency** — Same structure across all skills

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: **skill-creation** skill [SKILL-CREATE-*]
This research was absorbed into the skill-creation skill. It remains as historical rationale.

**Previous Status**: RECOMMENDATION

**Recommendation**: Option B (Procedure-Oriented) with Option C's template included.

A phased procedure provides the clearest guidance for Claude, with explicit checkpoints that prevent errors. Including a complete template (from Option C) addresses the authoring speed concern.

### Proposed Skill Structure

```yaml
---
name: skill-creation
description: |
  Process for adding new skills to the Swift Institute ecosystem.
  Apply when creating a new skill or converting documentation to a skill.

layer: process

requires:
  - swift-institute-core

applies_to:
  - skills
  - documentation
  - swift-institute
---
```

### Proposed Requirement IDs

Use prefix `[SKILL-CREATE-*]`:
- `[SKILL-CREATE-001]` Planning phase
- `[SKILL-CREATE-002]` Layer classification
- `[SKILL-CREATE-003]` Requirement ID assignment
- `[SKILL-CREATE-004]` Dependency declaration
- `[SKILL-CREATE-005]` SKILL.md authoring (with template)
- `[SKILL-CREATE-006]` swift-institute-core integration
- `[SKILL-CREATE-007]` CLAUDE.md integration
- `[SKILL-CREATE-008]` Sync and verification
- `[SKILL-CREATE-009]` Repo-specific skills (primitives pattern)

### Next Steps

1. Create `/Users/coen/Developer/swift-institute/Skills/skill-creation/SKILL.md`
2. Add to swift-institute-core Skill Index
3. Update workspace CLAUDE.md Skill Routing table
4. Run sync-skills.sh
5. Verify invocation

## References

- Existing skills in `/Users/coen/Developer/swift-institute/Skills/`
- `sync-skills.sh` script
- `swift-institute-core/SKILL.md` for index and loading order patterns
