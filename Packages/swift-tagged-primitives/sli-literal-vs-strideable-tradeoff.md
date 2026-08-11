# SLI Trade-off — `ExpressibleBy*Literal` vs `Strideable`

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

The per-protocol principled-absence catalog (2026-04-30) classified both `Tagged: Strideable` and the `ExpressibleBy*Literal` family as candidates for the `Tagged Primitives Standard Library Integration` (SLI) target — both are structurally authorable on Swift 6.3.1 (verified empirically in `Experiments/tagged-no-strideable/` and `Experiments/tagged-no-niche-protocols/`).

However, the literal-conformance research established a **footgun pattern**:

> _"Without `Strideable`, the literal-conformance footgun is dormant; with it, the footgun reactivates."_
>
> — [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md)

The misfire: `.map(Bit.Index.init)` over a `Range<Byte.Index>` resolves to a cross-domain integer-literal init (`Bit.Index(integerLiteral: byteIndex.underlying)`) instead of the domain-correct init. `@_disfavoredOverload` does not fully prevent it — the attribute affects ranking among eligible candidates, not eligibility itself.

The footgun requires **both** ingredients in the same compilation unit:
1. `Tagged` is `ExpressibleByIntegerLiteral` (the literal-init candidate)
2. `Tagged` is `Strideable` (enabling `Range<Tagged>` patterns + `.map(.init)` over them)

If we ship both in SLI, every SLI-importing production consumer is exposed to the footgun. The package-level granularity of SLI imports means consumers cannot opt into one without the other.

This document records the trade-off decision.

**Trigger**: User direction 2026-04-30 — explicit preference for `ExpressibleBy*Literal` over `Strideable` in SLI when only one can ship without footgun.

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

When `Strideable` and `ExpressibleBy*Literal` are individually authorable in SLI but combine into a footgun, which should ship in SLI?

## Analysis

### Value-per-import comparison

| Conformance | Use frequency | Ergonomic value | Substitutability |
|---|---|---|---|
| `ExpressibleByIntegerLiteral` (and family) | Universal — every Tagged consumer reaches for `let user: User.ID = 42` | Massive — replaces `Tagged(_unchecked: 42)` boilerplate at every call site | Hard for consumers to author cleanly without `@_disfavoredOverload` discipline |
| `Strideable` (Tagged-generic) | Niche — useful for stride-aware Tagged types | Moderate — `for u in start...end` and `distance/advanced` operations | Already covered per-domain in `swift-index-primitives` (`Index: Strideable where Tag: ~Copyable`); consumer authoring of generic-Tagged Strideable is a 6-line extension |

The asymmetry: literals carry roughly an order of magnitude more value-per-import than generic Strideable, because (a) literal usage is universal across consumers; (b) consumers cannot easily replicate the literal-conformance discipline themselves.

### Footgun blast-radius comparison

| Choice | Footgun status |
|---|---|
| Both in SLI (originally planned) | Active for every SLI consumer |
| Strideable in SLI; literals in Test Support (current state, before this decision) | Dormant in production scope; bounded to test-only contexts |
| **Literals in SLI; Strideable removed from SLI** (this decision) | Dormant unless the consumer ALSO imports a package that adds `Strideable` to a Tagged-aliased type (e.g. `swift-index-primitives` for `Index: Strideable`). When that happens, the footgun fires on *Index types specifically*, not on arbitrary Tagged types — narrower blast radius than "all SLI consumers". |
| Neither in SLI | Both literals and Strideable require per-domain authoring; high friction for the universal literal case |

### Substitutability check

If we exclude Strideable from SLI, consumers who genuinely want stride semantics on a Tagged type:

1. **Index types** — already covered by `swift-index-primitives/Research/Strideable Index Design.md` (DECISION 2026-01-28). `Index: Strideable where Tag: ~Copyable` is the approved per-domain pattern. No SLI dependency needed.
2. **Other Tagged-aliased types** — author a 6-line extension on the consumer side:
   ```swift
   extension Tagged: Strideable
   where Tag: ~Copyable & ~Escapable,
         Underlying: Strideable & Comparable & Equatable & Escapable {
       public func distance(to other: Tagged) -> Underlying.Stride {
           underlying.distance(to: other.underlying)
       }
       public func advanced(by n: Underlying.Stride) -> Tagged {
           Tagged(_unchecked: underlying.advanced(by: n))
       }
   }
   ```
   The consumer accepts the literal-conformance footgun reactivation explicitly when they author this — a cost that's currently invisible to SLI consumers.

If we exclude literals from SLI (the current state before this decision), consumers who want literal ergonomics:

1. Use `Tagged Primitives Test Support` — but this target is for test code; production use is structurally inappropriate.
2. Author per-domain `ExpressibleByIntegerLiteral` on each domain's typealias — requires `@_disfavoredOverload` discipline and per-Underlying-type effort.

The Strideable case has a clean per-domain pattern (already approved in swift-index-primitives) and a cheap consumer-side extension. The literal case has neither — Test Support is the only real alternative, and it's not production-grade.

## Outcome

**Status**: DECISION — Ship `ExpressibleBy*Literal` conformances in SLI; remove `Strideable` from SLI.

### What ships in SLI

| Module | Contents |
|---|---|
| `Tagged Primitives Standard Library Integration` | exports.swift + 7 `Tagged+ExpressibleBy*Literal.swift` files (Integer/Float/Boolean/UnicodeScalar/ExtendedGraphemeCluster/String/StringInterpolation) + Tagged+Identifiable + Tagged+LosslessStringConvertible + Tagged+Sequence + Tagged+Collection |

### Test Support changes

The literal conformances move from `Tagged Primitives Test Support` to SLI. Test Support gains a `@_exported public import Tagged_Primitives_Standard_Library_Integration` so that test code keeps the literal ergonomics it had before.

### Strideable disposition

`Tagged: Strideable` is removed from SLI. The Strideable principled-absence research doc updates from "SOFT (SLI-eligible)" to "SOFT structurally + SLI-excluded-by-policy". The empirically-verified constraint shape from `tagged-no-strideable` remains the canonical authorability template — consumers who want generic-Tagged Strideable copy the 6-line extension into their own codebase explicitly.

### Footgun residual

After the swap:

- A consumer importing only `Tagged Primitives Standard Library Integration` and using non-Strideable Tagged types: **footgun dormant**.
- A consumer importing both SLI and `swift-index-primitives` (or any package that adds `Strideable` to a Tagged-aliased type): footgun active for those Tagged types specifically. The narrower blast radius (specific types, not all Tagged) makes the misfire easier to detect and bound in code review.

The residual risk is documented per `[HERITAGE-006]`-style transparency: SLI consumers who add Strideable elsewhere accept the footgun knowingly, with the rationale captured in this doc and `tagged-literal-conformances-fresh-perspective.md`.

## References

- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — the original footgun analysis.
- [`principled-absence-strideable.md`](./principled-absence-strideable.md) — Strideable's per-protocol absence doc; updated alongside this decision to reflect SLI-exclusion-by-policy.
- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.4 — pointfreeco's blanket literal conformances + the silent-overload-resolution issue.
- `swift-index-primitives/Research/Strideable Index Design.md` (DECISION 2026-01-28) — per-domain Strideable approved at the Index layer.
