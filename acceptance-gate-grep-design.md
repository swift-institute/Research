---
title: Canonical Acceptance-Gate Grep Design
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-institute
  - all ecosystem superrepos
  - CI integration
---

# Context

The ecosystem `@unsafe` audit applied `@unsafe` + three-section
docstrings to 218 `@unchecked Sendable` sites across three superrepos.
The Phase 2 acceptance gate used a naive grep to verify "every site has
`@unsafe`": `rg "@unchecked Sendable" | rg -v "@unsafe|WHY:"`. It
produced false positives from docstring comments, `.build/checkouts/`
paths, and `.claude/worktrees/` directories. A second pass with
explicit exclusions was needed. The gate should have been designed
with these exclusions from the start. The pattern — "verify every
occurrence of X is annotated with Y, excluding noise" — recurs across
ecosystem audits (typed throws migration, namespace migrations,
@_exported removals). A canonical gate script with the right
exclusions would save the re-derivation cost and be suitable for CI
integration.

# Question

What is the canonical design of an acceptance-gate grep script for
ecosystem-wide code-pattern audits? Specifically:

- What's the exhaustive list of exclusions? (Docstrings — `///`, `/**`;
  build artifacts — `.build/`, `DerivedData/`; worktrees —
  `.claude/worktrees/`; Experiments/; third-party vendored code; CI
  caches.)
- What's the input interface — positive pattern, negative pattern,
  required-context pattern? Does it take a single "X must be followed
  by Y" expression, or a pair?
- Does it produce a count, a list, or a diff-against-baseline?
- Where does it live — `swift-institute/Scripts/`, a GitHub Action,
  both?

# Prior Work

- `swift-institute/Research/Reflections/2026-04-15-ecosystem-unsafe-audit.md`
- `swift-institute/Research/unsafe-audit-findings.md`
- `swift-institute/Skills/audit/SKILL.md` — `/audit` scope is code-vs-skill compliance
- Existing `swift-institute/Scripts/` (if any acceptance-gate infrastructure exists)

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- How does ripgrep's `--glob` pattern compose with the recursive
  exclusion list — is one regex enough or do we need a multi-pass
  pipeline?
- Does the gate need to distinguish "docstring example" (a `@unchecked
  Sendable` shown as a counterexample in documentation) from
  "accidental match"?
- Can the design be parameterized so the same script runs for
  `@unchecked Sendable`, `any Error`, `throws` (untyped), etc.?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-institute/Research/Reflections/2026-04-15-ecosystem-unsafe-audit.md` action item.
