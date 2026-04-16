---
title: Scope-Annotation Protocol for CONVERGED Design Outcomes
version: 0.1.0
status: IN_PROGRESS
tier: 3
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-institute
  - collaborative-discussion
  - research-process
---

# Context

The IO design review cycle reopened Shape B's `/collaborative-discussion`
CONVERGED outcome three times. Each reopening happened because the
scope had widened: Shape B converged on "advisory vs mandatory binding
for `.blocking()`", but subsequent sessions applied the convergence to
"full swift-io public API redesign" and "layered capability framing"
— scopes the original discussion did not cover. Treating CONVERGED as
permanent at the outcome level created false confidence; the convergence
was only valid within the scope that had been discussed. The
generalization: a CONVERGED record should signal what question converged,
not just the answer. When subsequent work extends scope beyond that
question, the skill should prompt re-verification rather than defer to
the prior convergence. The same shape appears in pragmatic REDEFINE
decisions (kernel-type-relocation's "no external consumers" rationale
became a time-bomb when strict-mission principle was applied six days
later).

# Question

What is the scope-annotation protocol for CONVERGED design outcomes,
and where does it live? Specifically:

- Should CONVERGED outcomes explicitly record the specific question
  that converged (e.g., "converged on advisory-vs-mandatory binding
  for `.blocking()`")?
- What triggers re-verification — any subsequent work that references
  the outcome, or only work whose scope demonstrably extends beyond
  the recorded question?
- Who owns the scope-annotation — `collaborative-discussion` for
  convergence records, `research-process` for research outcomes, or
  a new cross-cutting skill?
- How does this compose with "stale research" detection in
  `corpus-meta-analysis` (staleness is a temporal concept; scope
  annotation is a semantic one)?

# Prior Work

- `swift-institute/Skills/collaborative-discussion/SKILL.md`
- `swift-institute/Skills/research-process/SKILL.md`
- `swift-institute/Skills/corpus-meta-analysis/SKILL.md`
- `swift-foundations/Research/kernel-type-relocation.md` (the REDEFINE-as-time-bomb case)
- Source reflection: `swift-io/Research/Reflections/2026-04-14-io-design-review-cycle.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does the same pattern apply to skill decisions (e.g., `/skill-lifecycle`
  decisions marked as "decided" that get re-opened on scope change)?
- Is the scope annotation a required field on all CONVERGED outcomes,
  or an optional extension?
- What's the re-audit protocol when a new session references a
  CONVERGED outcome — automatic prompt, manual check, CI-enforced?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-foundations/swift-io/Research/Reflections/2026-04-14-io-design-review-cycle.md` action item.
