<!--
---
title: Skill-as-Input Composition Pattern
version: 1.1.0
status: DEFERRED
created: 2026-03-26
last_updated: 2026-04-30
tier: 2
scope: ecosystem-wide
applies_to: [audit, research-process, experiment-process, blog-process]
normative: false
---
-->

# Should the "Regarding" Composition Pattern Be Generalized?

## Context

The audit skill ([AUDIT-*]) introduced a novel integration pattern: `/audit regarding /implementation` loads another skill's requirement IDs as evaluation criteria. No other process skill currently takes a skill as input — research, experiments, and blog posts are self-contained.

**Source**: Reflection `2026-03-24-generalized-audit-skill-design.md`.

## Question

Should the "regarding" composition pattern (skill-as-input) be generalized to other process skills? Potential applications:

| Process | Example | What the target skill provides |
|---------|---------|-------------------------------|
| Audit | `/audit regarding /memory-safety` | Requirement IDs as evaluation criteria |
| Research | `/research regarding /memory-safety` | Scope boundary — focus research on memory-safety-adjacent concerns |
| Meta-analysis | `/meta-analysis regarding /implementation` | Filter corpus sweep to one skill's downstream artifacts |

## Analysis

*Stub — to be completed during a dedicated research session.*

### Considerations

1. **Audit's use is structural**: The target skill's requirement IDs become the audit's evaluation criteria. This is a tight, well-defined coupling.
2. **Research's use would be advisory**: Scoping research to a skill's domain is softer — the skill provides context, not criteria. Whether this is valuable enough to formalize is unclear.
3. **Risk of over-generalization**: Adding `regarding` to every process skill could create coupling where none is needed.

## Outcome

**Status**: DEFERRED (2026-04-30)

**Disposition**: Investigation never advanced past the three-considerations stub. The audit skill's `regarding /` pattern remains the only ecosystem instance of skill-as-input composition; no second skill has surfaced demand for the pattern, and the over-generalization risk identified in Consideration 3 currently outweighs the speculative benefit.

**Blocker**: The question is intentionally premature — generalizing a one-instance pattern is exactly the [RES-018] premature-primitive anti-pattern. The pattern needs a second consumer to pay rent before generalization is warranted.

**Resumption trigger** (any of):
- A second process skill (research-process, experiment-process, blog-process, or other) surfaces a concrete need for skill-as-input composition with a structural — not advisory — coupling
- The `corpus-meta-analysis` or `release-readiness` skill flow develops a `regarding /` pattern in practice (informally, in users' invocations), giving evidence the pattern generalizes
- The skill-lifecycle infrastructure adds typed-input metadata to skills (e.g., a YAML field declaring "this skill consumes other skills' rule IDs"), which would make the pattern a first-class concern rather than ad-hoc

**Held finding**: The audit-skill instance works because the coupling is structural (target skill's rule IDs become the audit's evaluation criteria). Future generalization should require the same structural-coupling test before adopting.
