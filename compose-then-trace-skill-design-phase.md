---
title: Compose-Then-Trace Phase for Skill Design
version: 0.1.0
status: IN_PROGRESS
tier: 3
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-institute
  - skill-lifecycle
---

# Context

The agent-workflow cluster audit (handoff / supervise / reflect-session /
skill-lifecycle) produced 26 findings in one pass, of which the highest-value
were composition gaps — questions with no answer in any single skill
that only became visible once two skills were composed and a workflow
was traced end-to-end. Example: "supervisor in absentia" (what the
subordinate does when the principal's session has ended) had no
first-principles answer until `/supervise` and `/handoff` were both in
play. The audit caught this reactively. A proactive phase in
`skill-lifecycle` — placed between `[SKILL-CREATE-006]` (content) and
`[SKILL-CREATE-007]` (integration) — could prevent the gap from
existing in the first place for skills that compose with siblings.

# Question

Should `skill-lifecycle` gain a `[SKILL-CREATE-006a]` "Compose-then-trace"
phase, and if so what is its precise procedure? Specifically:

- What triggers the phase? (Explicit cross-references in the skill?
  Shared requirement ID prefix? User declaration?)
- How many workflows must be traced? (The audit used an implicit
  threshold of "2-3 end-to-end workflows" — is that the right default?)
- What's the output artifact — an explicit trace in the skill, a
  research doc, an audit finding?
- How does the phase interact with `[SKILL-CREATE-006]`'s internal
  consistency pass (which was added in the same session)?

# Prior Work

- `swift-institute/Research/agent-workflow-skill-consistency-audit.md`
- `swift-institute/Skills/skill-lifecycle/SKILL.md` — current phases
- `swift-institute/Skills/supervise/SKILL.md` — `[SUPER-014a]`
  supervisor in absentia (the worked example)
- Source reflection: `swift-institute/Research/Reflections/2026-04-15-agent-workflow-cluster-audit-and-fixes.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does the pattern apply only to workflow skills, or to all composing
  skills (e.g., `code-surface` + `implementation`)?
- Can the trace be automated (grep-based cross-reference walk) or does
  it need human-authored prose?
- What does "2-3 workflows" mean operationally — what counts as a
  workflow boundary?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-institute/Research/Reflections/2026-04-15-agent-workflow-cluster-audit-and-fixes.md` action item.
