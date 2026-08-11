# Swift Primitives Insights

<!--
---
title: Swift Primitives Insights
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-primitives]
normative: false
---
-->
Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-primitives]`.

---

## Documentation Drift as Technical Debt

**Date**: 2026-01-21

**Context**: Updating Primitives Tiers.md from 9-tier to 16-tier structure after verification revealed significant divergence between documentation and implementation.

### The Discovery

The Primitives Tiers documentation stated "nine-tier dependency hierarchy" while the actual package dependencies formed a sixteen-tier DAG (tiers 0-15). This wasn't a small discrepancy—the documentation was missing seven tiers and had incorrect package assignments throughout.

The gap didn't happen through negligence. It accumulated as packages were added, refactored, and reorganized. Each change was small; the cumulative effect was documentation that described a different system than the one that existed.

### The Lesson About Tier Verification

Tier assignment isn't semantic—it's mechanical. A package's tier is determined by the maximum tier of its dependencies plus one. The tier definitions table ("Tier 6: Collections/Shapes") describes semantic clusters that emerged from the dependency structure, not categories that were designed first.

This inverted relationship matters: the DAG determines the tiers; the documentation describes what we observe. When packages change dependencies, tiers shift automatically. Documentation that treats tiers as fixed categories will drift as dependencies evolve.

### The Audit Pattern

The fix required complete regeneration, not incremental updates. The verified tier list came from analyzing every Package.swift file and computing dependency depth. Partial updates would have perpetuated errors.

For documentation describing mechanical relationships (dependencies, tiers, counts), periodic full regeneration from source of truth is more reliable than incremental maintenance.

**Applies to**: Primitives Tiers.md maintenance.

---

## The "Most Depended-Upon" Metric

**Date**: 2026-01-21

**Context**: Adding dependency impact information to tier documentation.

### Why This Metric Matters

The tier documentation includes a table of most-depended-upon packages:

| Package | Dependents |
|---------|------------|
| index-primitives | 21 |
| collection-primitives | 16 |
| input-primitives | 12 |

This isn't decorative. These numbers represent change propagation scope. A breaking change to `index-primitives` forces recompilation of 21 packages. A bug in `collection-primitives` potentially affects 16 downstream consumers.

### Practical Application

When planning API changes, consult this list first. Packages with many dependents warrant more careful review, more extensive testing, and explicit migration guidance. Packages with few dependents can evolve more freely.

The tier number tells you where a package sits. The dependent count tells you how much its changes matter.

### The Inverse Relationship

Interestingly, the most-depended-upon packages are all in lower tiers (index at tier 1, collection at tier 2). This is structural: lower-tier packages can be depended upon by more packages (everything above them). Higher-tier packages can only be depended upon by the few packages above them.

This confirms the architectural intent: foundational packages should be stable; specialized packages can evolve.

**Applies to**: Change impact analysis and API stability decisions.

---

## Documentation Drift and Automated Verification

**Date**: 2026-01-22

**Context**: Performing a systematic tier audit of all 105 swift-primitives packages, discovering the documented 16-tier structure didn't match actual dependencies.

### The Scale of Drift

The Primitives Tiers document (v2.0.0) specified a 16-tier hierarchy (0-15). A complete dependency scan of all Package.swift files revealed the actual structure requires only 13 tiers (0-12). Packages were scattered across incorrect tiers—some 3-4 tiers away from their correct position. This wasn't isolated errors; it was systemic drift affecting over 30% of packages.

The drift accumulated through incremental changes. Each Package.swift modification was locally correct, but no one ran a global verification. The documentation became a historical artifact rather than a living specification.

### Computational Truth

A 30-line Python script computed the correct tier for every package in seconds:

```
tier[pkg] = max(tier[dep] for dep in pkg.dependencies) + 1
```

This trivial algorithm exposed months of accumulated drift. The lesson: for any property that can be computed from source, the documentation should either be generated or verified automatically. Human curation of derived information cannot scale.

### Recommended Practice

Primitives Tiers.md should include a verification step in CI: compute tiers from Package.swift files, compare to documented tiers, fail if they diverge. The document's version should increment only when computed tiers change. Human judgment belongs in tier *naming* and *description*, not tier *assignment*.

**Applies to**: All mechanically-derived documentation.

---

## Semantic Tier Names vs Mechanical Tier Numbers

**Date**: 2026-01-21

**Context**: Observing tension between tier names ("Atomic", "Foundation") and tier positions (0, 1, ..., 15).

### The Naming Problem

The tier documentation assigns names to tiers: "Tier 5: Bit/Dimension", "Tier 9: Complex Structures". These names describe the packages currently at those tiers—they're descriptive, not prescriptive.

When a package's dependencies change, its tier number shifts mechanically. If `parser-primitives` adds a dependency on a tier 10 package, it moves to tier 11 (at minimum). The "Tier 9: Complex Structures" name no longer accurately describes what's at tier 9.

### Why Keep Names At All

Tier names serve cognitive function. "Tier 7" is opaque; "Advanced Numerical" suggests what kinds of packages belong there. The names are a snapshot of current semantic clustering, useful for orientation but not for rule enforcement.

The documentation should treat names as commentary: "As of this version, tier 7 contains linear algebra and input handling packages." Not: "Tier 7 is for advanced numerical packages."

### The Verification Cadence

This suggests a maintenance pattern: when running full tier verification (as done today), also verify that tier names still describe their contents. Names may need updating even if package assignments are correct.

**Applies to**: Primitives Tiers.md maintenance and naming decisions.

---

## Related

- Primitives-Tiers
- Primitives-Layering
