# Research: Skill-Based Documentation Architecture

## Question

How should Swift Institute documentation be organized to optimize for both human understanding and LLM consumption?

## Context

The original documentation structure mixed normative rules, explanatory content, and process workflows in a single Documentation.docc directory. This caused:
- LLMs had difficulty finding specific rules
- Humans had difficulty distinguishing requirements from guidance
- Content was duplicated across documents

## Architecture Model

| Artifact | Purpose | Authority |
|----------|---------|-----------|
| Skills/ | Rules, requirements, workflows | CANONICAL (WHAT) |
| Research/ | Rationale, trade-offs, history | AUTHORITATIVE (WHY) |
| Documentation.docc/ | Explanation, onboarding | NON-NORMATIVE (HOW) |

This mirrors code philosophy:
- Skills = interfaces + invariants
- Research = design notes
- Docs = guides

## Skill Schema

```yaml
---
name: {skill-name}
description: |
  Brief description.
  When to apply this skill.

layer: meta | architecture | implementation | process

requires:
  - {dependency-skill}

applies_to:
  - swift
  - primitives
---
```

## Loading Mechanism

Skills are loaded via symlinks in `/Users/coen/Developer/.claude/skills/` pointing to skill directories in repositories.

## Recommendation

Adopted this architecture. Skills are the canonical source for rules. Documentation.docc becomes explanatory-only.

## Implementation

See plan: `/Users/coen/.claude/plans/rustling-booping-seal.md`
