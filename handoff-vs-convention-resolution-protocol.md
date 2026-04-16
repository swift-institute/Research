---
title: Handoff-vs-Convention Resolution Protocol
version: 0.1.0
status: IN_PROGRESS
tier: 3
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-institute
  - handoff
  - supervise
  - skill-lifecycle
---

# Context

The `/supervise` skill creation session was nearly derailed by a
literal-handoff-path compliance error: the handoff brief specified
`~/.claude/skills/supervise/` as the destination, but the established
skill-location convention requires `swift-institute/Skills/` with
symlinks created by `Scripts/sync-skills.sh`. The agent followed the
handoff until the user interrupted with "should it not be put here?"
pointing at the canonical location. The resolution — skills override
handoff specifications — is not currently written down anywhere. The
feedback memory `feedback_skills_follow_institute_convention.md`
encodes the specific case (skills live in `swift-institute/Skills/`),
but the *general* rule (conventions beat handoff specifications in
structural disputes) has no codification. Without it, every structural
disagreement between a handoff and a convention re-litigates the same
pattern.

# Question

What is the canonical resolution protocol when a handoff document
specifies a structural choice (file path, naming, location, pattern)
that conflicts with an established skill convention? Specifically:

- Is the rule unconditional ("skills always win") or conditional (e.g.,
  "skills win unless the handoff explicitly overrides with a named
  requirement ID")?
- How should handoff authors signal structural intent that deliberately
  diverges from convention (e.g., a one-off experiment)?
- How should the receiving agent surface the conflict — escalate to
  the principal, follow the skill silently, document in the findings
  section?
- Where does this rule live — `handoff`, `supervise`, `skill-lifecycle`,
  or a new cross-cutting skill?

# Prior Work

- `swift-institute/Skills/handoff/SKILL.md`
- `swift-institute/Skills/supervise/SKILL.md`
- `swift-institute/Skills/skill-lifecycle/SKILL.md`
- `feedback_skills_follow_institute_convention.md` (user memory)
- `/Users/coen/Developer/CLAUDE.md` — "Skills are the canonical source
  for all requirement IDs and implementation rules. Skills override
  any memorized patterns."
- Source reflection: `swift-institute/Research/Reflections/2026-04-15-supervise-skill-creation-from-handoff.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does CLAUDE.md's "skills override memorized patterns" extend by
  analogy to "skills override handoff specifications," or does
  "memorized patterns" specifically exclude explicit handoff
  instructions?
- What does the symmetric case look like — convention specifies one
  thing, a newer skill update specifies another? Which wins?
- How does this compose with `/supervise`'s ground-rules block
  (explicit MUST NOTs from the principal)?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-institute/Research/Reflections/2026-04-15-supervise-skill-creation-from-handoff.md` action item.
