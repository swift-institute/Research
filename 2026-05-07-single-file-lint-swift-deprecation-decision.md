---
title: Single-File Lint.swift Consumer Form — Keep, Deprecate, or Remove?
version: 0.2.0
status: SUPERSEDED
supersededBy: 2026-05-12-swift-linter-unified-consumer-manifest.md
tier: 2
created: 2026-05-07
last_updated: 2026-05-31
applies_to:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - all consumer packages adopting swift-linter
---

> **SUPERSEDED (2026-05-31, per [META-002]).** This doc's open keep/deprecate/remove question (Options A/B/C; Outcome was "Pending investigation") is resolved by [`2026-05-12-swift-linter-unified-consumer-manifest.md`](2026-05-12-swift-linter-unified-consumer-manifest.md), which adds **Option D** (unify deps + activations in a single `Lint.swift` = Shape γ) and states "A/B/C all collapse." Retained in place per [META-005] as historical rationale.

# Context

The 2026-05-07 architecture cohort decoupled `swift-linter` from
`swift-linter-rules`: the engine ships zero rules; consumers register
rules via either (a) the nested-package `Lint/` shape (consumer's
`Lint/Sources/Lint/main.swift` enumerates rule TYPES + activates per
manifest), or (b) the single-file `Lint.swift` form with parent-chain
inheritance via `// parent: <URL>` directive.

Phase B.1 (engine decouple) left the single-file `Lint.swift` path
**inert** at the post-decouple state — without consumer-side rule
registration, the single-file form yields zero findings. The Lint/
nested-package shape is the working consumer pattern.

D1' execution preserved the `## Inheritance via // parent: directive`
section in the swift-linter README per a deliberate `ask:`
adjudication, AND stripped the "Single-file Lint.swift form"
documentation as inert. The README now documents `Lint/` as the
working consumer shape AND the `// parent:` inheritance mechanism, but
no longer presents single-file as a forward-looking option.

The question this leaves unresolved: is the single-file form a
**future-facing sugar form** (worth preserving at the engine layer
even though currently inert), or a **deprecated path** (worth
removing entirely from the engine + tooling + docs)?

# Question

Should the institute preserve, formally deprecate, or completely
remove the single-file `Lint.swift` consumer form?

Sub-questions:

1. **Preserve** — what would the future-facing version look like? A
   sugar form that auto-imports a default rule pack (e.g., the Tier 1
   canonical preset) so single-file consumers don't manually enumerate
   rules? A typed-DSL evolution of the current shape that subsumes the
   need for a separate Lint/ package for simple cases?
2. **Deprecate** — what's the migration path for any existing
   single-file consumers (none currently public, but Tier 1/Tier 2
   canonical scaffolds DO use single-file form per
   `canonical-tier-rule-activation-design.md`)? What's the
   deprecation timeline?
3. **Remove** — what's the removal cost? Engine code path, tooling
   support, doc surface area, downstream consumer churn (zero current
   external consumers; some institute scaffolds).

# Prior Work

- `swift-foundations/swift-linter/Research/2026-05-07-canonical-tier-rule-activation-design.md`
  (covers the Tier 1/Tier 2 canonical chain — current scaffolds use
  single-file form).
- Reflection `2026-05-07-swift-linter-architecture-cohort-execution.md`
  (Phase B.1 inert-fallback observation).
- Reflection `2026-05-07-swift-linter-modularization-cohort-completion.md`
  (the file-based-canonical migration that established the
  parent-chain inheritance mechanism).
- Reflection `2026-05-07-d1-readme-and-driver-repair.md`
  (post-decision README cleanup; explicit Decision 1=B = "strip
  inert single-file documentation").
- Research `2026-05-07-swift-linter-consumer-syntax.md` v1.0.1
  (covers the typed-DSL Lint.Configuration shape used by Lint/
  consumers).

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- What's the actual cost of supporting two consumer shapes (engine
  branches on Lint/-detection vs. single-file form)?
- Does the future-facing typed-DSL evolution (per consumer-syntax
  research) make single-file form ergonomically equivalent to Lint/?
  If yes, single-file form may be worth preserving as the "simple
  case" sugar.
- Is the canonical-tier rule activation cascade (Tier 1 / Tier 2)
  better served by single-file scaffolds OR Lint/ packages? The
  canonical-tier research recommends single-file; if single-file is
  removed, the canonical-tier scaffolds need to migrate.

# Options Considered

| Option | Shape | Implication |
|--------|-------|-------------|
| A — Preserve as future-facing sugar | Engine retains Lint.swift detection; single-file form becomes typed-DSL sugar with default rule-pack import | Two consumer shapes ecosystem-wide; complexity tax in engine |
| B — Formally deprecate with migration path | Engine retains detection but emits deprecation warning; canonical-tier scaffolds migrate to Lint/ over N releases | Bounded migration cost; cleaner long-term |
| C — Remove entirely | Engine drops Lint.swift detection branch; canonical-tier scaffolds migrate immediately; "Lint/ is the only consumer shape" | Cleanest; biggest immediate scaffold migration cost |

# Outcome

_Pending investigation._

# Cross-References

- `swift-foundations/swift-linter/Research/2026-05-07-canonical-tier-rule-activation-design.md`
- `swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md`
- Reflection `2026-05-07-d1-readme-and-driver-repair.md`

# Provenance

Reflection `2026-05-07-d1-readme-and-driver-repair.md` (action item 3).
