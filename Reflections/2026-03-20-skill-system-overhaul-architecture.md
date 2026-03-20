---
date: 2026-03-20
session_objective: Overhaul the Swift Institute skill system — add enforcement, simplify routing, formalize lifecycle
packages:
  - swift-institute
status: processed
processed_date: 2026-03-20
triage_outcomes:
  - type: experiment_topic
    target: swift-institute
    description: "Test skill @-imports (composite SKILL.md referencing another) for non-destructive composition"
  - type: no_action
    description: "[META-020] Skill Health Check already exists in research-meta-analysis skill"
  - type: no_action
    description: "last_reviewed frontmatter already applied to all reviewed skills during overhaul session"
---

# Skill System Overhaul — Application Gap, Research-Grounded Restructuring

## What Happened

Session began with a narrow question: does the /implementation skill mention preferring ecosystem dependencies over ad-hoc implementations? It didn't. Created [IMPL-060] and absorbed the design skill into implementation. This triggered a broader question: are the skills correctly organized?

Conducted a systematic analysis:
1. **Research phase**: Investigated LLM instruction following literature (IFScale 2025, Anthropic Context Engineering 2025, Lost-in-the-Middle 2024). Found: linear degradation per instruction for Claude, routing errors are the key failure mode, industry convergence on modular on-demand loading.
2. **Cross-reference analysis**: Mapped all 11 implementation-adjacent skills. Found 3 natural clusters with 2.2 average cross-references — not a dense web, but with over-decomposed clusters (naming/errors/code-org always co-relevant at 134/131/201 lines each).
3. **Full overhaul**: Three tracks executed in one session:
   - **Track 1**: Post-Implementation Checklists (PICs) added to 6 skills — enforcement via recency bias
   - **Track 2**: Cluster merges (code-surface, memory, conversions) + CLAUDE.md routing table rewritten from 32 flat rows to 4 grouped sections
   - **Track 3**: skill-lifecycle skill created with update/review/deprecate phases [SKILL-LIFE-001–022]

Total: 2 skills deleted, 5 superseded, 2 new skills created, 6 skills modified, CLAUDE.md and swift-institute-core rewritten.

## What Worked and What Didn't

**Worked well:**
- The outside-consultant framing produced a genuine architectural assessment rather than incremental tweaks. The diagnosis ("the gap is application, not organization") reframed the entire approach.
- Research grounding was valuable. IFScale's finding that Claude follows linear degradation per instruction provided a concrete reason to reduce routing targets. The U-shaped attention curve justified PICs at the end of skills.
- Parallel agent dispatch for PICs and merges was highly efficient — 8 agents running concurrently for independent edits.
- The primitives-composition question ("can we apply the same principle to skills?") led to the insight that the principle already applied — the issue was the routing mechanism, not the decomposition.

**Didn't work as well:**
- The composite skill idea (@-import mechanism) was proposed but had to be deferred — no evidence it works in Claude Code's skill loading. Straight merges were the pragmatic choice. This is an open question worth an experiment.
- The session was long and context-heavy. By the end, file reads were needed for files already read earlier. The overhaul probably should have been split across 2 sessions — research/design in one, implementation in the next.

## Patterns and Root Causes

**Pattern: Enforcement gaps are invisible until you look for them.** The skill system had sophisticated knowledge capture (research → experiment → reflect → skills) but no verification that skills were actually followed during implementation. This is the "building code without an inspector" anti-pattern. PICs are a lightweight inspector — they exploit the LLM's tendency to attend more to the end of documents.

**Pattern: Over-decomposition creates routing tax.** naming (134 lines), errors (131 lines), and code-organization (201 lines) were separate skills that were always loaded together. The decision cost of routing to three separate skills exceeded the value of their separation. The absorption criteria in [SKILL-LIFE-021] now formalize when this threshold is crossed: always co-loaded + <200 lines + proper subset.

**Pattern: Research grounds decisions that would otherwise be opinion.** "Should we merge or keep separate?" is an opinion war. "IFScale shows linear degradation per instruction, and these three skills add 3 routing decisions for 465 lines of always-co-relevant content" is a grounded argument. The research phase paid for itself.

## Action Items

- [ ] **[experiment]** Test whether skill @-imports work in Claude Code (composite SKILL.md that references another SKILL.md) — determines whether composition can be non-destructive
- [ ] **[skill]** research-meta-analysis: Add [META-020] Skill Health Check (staleness by last_reviewed, instability by update frequency, superseded retention)
- [ ] **[skill]** all active skills: Add `last_reviewed: 2026-03-20` to YAML frontmatter for skills reviewed during this overhaul
