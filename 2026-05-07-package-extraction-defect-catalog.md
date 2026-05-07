---
title: Package-Extraction Defect Catalog
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-05-07
last_updated: 2026-05-07
applies_to:
  - all institute multi-package extractions
  - swift-institute/Skills/modularization (potential consumer)
---

# Context

The 2026-05-07 swift-linter modularization cohort executed four
sequential pure-structural extractions: Manifest.Resolver
extraction, sanitize/tempPath ecosystem promotion, swift-linter-rules
package extraction, wave-1 AI-harness rule encoding. R5 = 27-hit
invariant on swift-tagged-primitives preserved end-to-end across all
four phases. Three reusable defect-detection patterns surfaced during
the cohort, each caught by per-phase verification:

1. **Helper-duplication-after-extraction**: when a package extraction
   moves a generic component, helpers that were single-source in the
   pre-extraction package may end up duplicated across the
   extracted-and-original packages. Phase 2.5b caught `sanitize` +
   `tempPath` existing in BOTH `Lint.Driver` AND `Manifest.Resolver`
   after Phase 3a; one ecosystem-promotion pass migrated both to the
   right L1/L3 home.

2. **Concrete-string-leak-in-generic**: when a generic is extracted
   from a specific, every concrete reference must be parameterized,
   not just the obvious type-level ones. The `"Lint.swift"` string in
   `Manifest.Resolver.evalParent(...)` was a generic leak caught only
   by `grep -rn "Lint\." swift-manifests/Sources/`.

3. **AST tokenKind discriminator under generic syntax types**:
   SwiftSyntax models multiple keyword-effects (`throws`, `rethrows`)
   under a single syntax type (`ThrowsClauseSyntax`). Rules that
   target one specific keyword must discriminate on
   `tokenKind == .keyword(.<specific>)`, not just visit the syntax
   type. The defect mode is silent — the rule appears to work but
   fires on the wrong keyword.

These three patterns are reusable across future extractions; they're
not specific to swift-linter's domain.

# Question

What is the canonical catalog of pure-structural-extraction
defect-detection patterns the institute should apply at every
multi-package extraction, with detection procedures and false-positive
avoidance criteria?

Sub-questions:

1. **Pattern enumeration**: are there other defect classes the
   2026-05-07 cohort didn't surface but other extractions have hit?
   Specifically: import-graph defects (post-extraction missing
   imports per [HANDOFF-013b]), test-fixture path-rooting changes
   (extracted package's tests reference paths relative to the
   extracted-from package's root), namespace-collision-on-extraction
   (extracted type's namespace path no longer unique after
   extraction).
2. **Detection automation**: can each pattern be detected by a
   mechanical script (grep-based or AST-based) at extraction-completion
   time? The three above are all amenable to grep recipes.
3. **Where the catalog lives**: a research doc (this one) for prose
   and rationale, OR a section in the modularization skill for
   normative discipline, OR a script in `swift-institute/Scripts/`
   for mechanical execution? Likely all three: skill rule for
   discipline, script for automation, research doc for the audit
   trail.
4. **Ordering of the catalog**: each pattern should have detection
   procedure + past instance(s) + false-positive avoidance + fix
   pattern. Order by frequency of occurrence (highest-frequency
   first) so future extraction sessions hit the most-likely defects
   earliest.

# Prior Work

- Reflection `2026-05-07-swift-linter-modularization-cohort-completion.md`
  (the cohort that surfaced the three patterns).
- `swift-institute/Skills/modularization/SKILL.md` [MOD-022]
  (Mechanical Coupling Inventory Before Scope Estimation — adjacent
  discipline).
- `swift-institute/Skills/modularization/SKILL.md` [MOD-024]
  (Test Support Spine Discipline — adjacent discipline; the
  spine-completion gap pattern in [MOD-025] is a related
  defect-detection pattern).
- `swift-institute/Skills/handoff/SKILL.md` [HANDOFF-013b]
  (Build-Level Visibility Pre-Flight for Deletion-Without-Adoption
  — related discipline for delete-public-type sequences).
- `feedback_cross_package_api_sweep.md` (related discipline:
  workspace-grep before changing protocol API surface).

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- For each of the three 2026-05-07 patterns, formalize the detection
  recipe (`grep -rn ...` shape) + the false-positive criteria + the
  fix pattern.
- Survey other recent extraction reflections for patterns this catalog
  doesn't yet enumerate.
- Determine the right home: a new `[MOD-026] Package-Extraction
  Defect Catalog` rule that points at this research doc as the audit
  trail? A standalone catalog at this doc's location with cross-refs
  from [MOD-022]? Both?

# Options Considered

_To be expanded._

| Option | Shape |
|--------|-------|
| A — Catalog as standalone research doc | This doc; modularization skill cross-refs it |
| B — Catalog absorbed into [MOD-026] rule | Discipline lives in skill; this doc is provisional |
| C — Catalog as Script + skill rule | Script automates detection; skill rule mandates running it; this doc is the design doc |

# Outcome

_Pending investigation._

# Cross-References

- Reflection `2026-05-07-swift-linter-modularization-cohort-completion.md`
- [MOD-022], [MOD-024], [MOD-025]
- [HANDOFF-013b], [HANDOFF-035]

# Provenance

Reflection `2026-05-07-swift-linter-modularization-cohort-completion.md` (action item 2).
