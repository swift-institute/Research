# `@inlinable` + `@_spi` Transitive-Reach Semantics

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

Swift's `@_spi`-in-`@inlinable` rule has been understood ecosystem-wide as a constraint that propagates through call graphs: an `@inlinable` body that calls a function which itself eventually reaches an `@_spi` member would inherit the SPI restriction. The 2026-04-24 cycle-3-close investigation (Doc 1, Option 5 amended Cons paragraph) empirically established that this understanding is wrong: Swift's `@_spi`-in-`@inlinable` rule is a *direct-reference* rule, not a transitive-call-graph rule. Composing `@inlinable` through a public non-`@inlinable` entry point severs the cascade — the public entry point provides a stable boundary that the `@inlinable` consumer can call without inheriting any downstream `@_spi` constraints.

The corrected semantic understanding has implications for cross-package consumer migration patterns, error-conversion layering, and overall API-layer design. This Doc captures the empirical finding and the corrected mental model.

## Question

What is the precise scope of Swift's `@_spi`-in-`@inlinable` constraint propagation? When does an `@inlinable` declaration transitively inherit an SPI restriction, and when does the rule terminate at a public boundary?

## Analysis

### Empirical observation (2026-04-24)

The cycle-3-close investigation (per `swift-institute/Audits/audit.md` post-Cycle-3 verification) showed:

1. **Direct reference is constrained**: an `@inlinable public func` that directly calls an `@_spi(X) public func` MUST be marked `@_spi(X)` itself.
2. **Transitive reference is NOT constrained**: an `@inlinable public func` that calls a public non-inlinable function which internally calls `@_spi(X)` is fine. The public-non-inlinable function is the boundary.

The earlier inferential extension — that the SPI cascade propagates through call graphs — was incorrect. The 2026-04-20 `l2-l3-same-signature-latent-ambiguity` reflection seeded the misunderstanding by treating the rule as transitive.

### Implications

| Pattern | Old understanding | Corrected understanding |
|---------|-------------------|-------------------------|
| `@inlinable public func A()` calls `@_spi(X) func B()` | A must be `@_spi(X)` | A must be `@_spi(X)` (unchanged) |
| `@inlinable public func A()` calls public non-inlinable `func B()` which internally calls `@_spi(X) func C()` | A must be `@_spi(X)` (transitive) | A is fine; B is the boundary |
| Cross-package consumer needs `@inlinable` performance through an SPI surface | Restructure to make consumer `@_spi` too | Restructure to interpose a public non-inlinable boundary |

### Open analysis

| Question | Status |
|----------|--------|
| Are there compiler-version edge cases where transitive propagation fires? | TODO — empirical sweep across Swift 6.3.x revisions |
| Does the boundary-as-public-non-inlinable pattern require any specific shape (return-type-erasure, witness-protocol, etc.) for the cascade to terminate? | TODO — direct experimental investigation |
| What's the relationship to `@_spi`-stripped `.swiftinterface` per [INFRA-026] / [RES-021]? | TODO — these are separate mechanisms but may interact |

## Outcome

**Status**: IN_PROGRESS

**Held finding**: `@_spi`-in-`@inlinable` is a direct-reference rule. Composing `@inlinable` through a public non-inlinable boundary severs the cascade. Earlier transitive-propagation framings (in `2026-04-20-l2-l3-same-signature-latent-ambiguity.md` and adjacent docs) are corrected by this finding.

**Pending empirical work**:

1. Sweep adjacent reflections / research that cite the transitive-propagation framing and amend with a pointer to this Doc
2. Build a minimal experiment package validating the boundary-pattern empirically across Swift 6.3.x
3. Document the pattern as a guideline in the implementation skill once empirically pinned

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. The corrected mental model affects API-layer design across the ecosystem; the empirical pin is needed before promoting to RECOMMENDATION.

## References

- Reflection: [Research/Reflections/2026-04-24-cycle-3-close-and-inlinable-spi-cascade-non-fire.md](Reflections/2026-04-24-cycle-3-close-and-inlinable-spi-cascade-non-fire.md) — origin finding (Doc 1 Option 5 amended Cons paragraph)
- Reflection (corrected): `2026-04-20-l2-l3-same-signature-latent-ambiguity.md` — seeded the incorrect transitive-propagation framing
- Skills: [INFRA-026], [RES-021] — adjacent SPI/SDK-availability rules (different mechanism)
