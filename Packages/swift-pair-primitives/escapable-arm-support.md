# ~Escapable Arm Support

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 1
scope: package
trigger: forums-review of swift-either-primitives raised the cohort question. Per-package operationalization for Pair of the ecosystem-wide research at `swift-institute/Research/escapable-support-pair-either-product.md`.
related:
  - swift-institute/Research/escapable-support-pair-either-product.md
  - swift-institute/Research/nonescapable-ecosystem-state.md
  - swift-either-primitives/Research/escapable-arm-support.md (sibling)
empirical_validation: Experiments/escapable-arm-support/
---
-->

## Question

Should Pair admit `~Escapable` arms? Which functor methods can be extended? What's the cost (type-level upgrade, lifetime annotations, conditional conformances)?

## Empirical results

Pair underwent a **type-level upgrade**: the type now carries `~Copyable & ~Escapable` at both type-parameter level and type level itself. Conditional `Copyable` / `Escapable` / `Sendable` / `Codable` conformances explicitly state the orthogonal axis (e.g., `where First: Copyable & ~Escapable, Second: Copyable & ~Escapable {}`). The init carries `@_lifetime(copy first, copy second)`.

`Experiments/escapable-arm-support/Sources/EscapableArmSupport/EscapableArmSupport.swift` validates each shape on Swift 6.3.1 + Swift 6.4-dev nightly 2026-05-07-a + Embedded.

| Method | ~Escapable support | Lifetime annotation | Status |
|---|---|---|---|
| `Pair.init(_:_:)` | Both arms `~Escapable & ~Copyable` | `@_lifetime(copy first, copy second)` | CONFIRMED |
| `Pair.swapped(_:)` static | Both arms `~Escapable & ~Copyable` | `@_lifetime(copy pair)` | CONFIRMED |
| `Pair.swapped()` instance | Both arms `~Escapable & ~Copyable` | `@_lifetime(copy self)` | CONFIRMED |
| `Pair.apply(_:_:)` static + instance | Both arms `~Escapable & ~Copyable` | — (R is consumer-provided) | CONFIRMED |
| `Pair.map(_:first:)` static / instance | `Second` (un-transformed) `~Escapable & ~Copyable`; `First` and `NewFirst` Escapable | `@_lifetime(copy pair)` | CONFIRMED |
| `Pair.map(_:second:)` static / instance | `First` (un-transformed) `~Escapable & ~Copyable`; `Second` and `NewSecond` Escapable | `@_lifetime(copy pair)` | CONFIRMED |
| `Pair.map(_:first:second:)` | Both arms must be Escapable | — | BLOCKED — Gap A |
| Equation/Hash/Comparison.Protocol institute conformances | Both arms `Equation/Hash/Comparison.Protocol & ~Copyable & ~Escapable` | — | CONFIRMED (after upstream protocol upgrade in swift-equation/hash/comparison-primitives `3495e50` / `0e5708e` / `a4fd209`) |
| Stdlib `Equatable` / `Hashable` / `Comparable` / `Codable` conformances | Both arms must be Escapable | — | INTRINSICALLY BLOCKED — stdlib protocols require Escapable |

## Body-shape note

Functor method bodies use **direct field access** on the consuming parameter (`pair.first`, `pair.second`) — intermediate `let consumed = consume pair` triggers the move-checker bug "copy of noncopyable typed value" on generic `~Copyable & ~Escapable` types (cross-reference: `pack-expand-on-consuming-param-property.md` memory entry, originally observed on swift-product-primitives during the consuming-method consolidation).

## What's BLOCKED and why

**Gap A** (per `nonescapable-ecosystem-state.md` §5): `map(first:second:)` transforms BOTH arms via closures. The result lifetime can't be inferred when both closures produce ~Escapable values. `map(first:second:)` therefore stays Escapable-only.

**Stdlib `Equatable`/`Hashable`/`Comparable`/`Codable`**: these protocols require Escapable. Adding `& ~Escapable` to their conditional-conformance constraint produces:

```
error: composition cannot contain '~Escapable' when another member requires 'Escapable'
```

Verified empirically on Swift 6.4-dev nightly 2026-05-07-a. The institute `Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol` admit ~Escapable conformers because we upgraded their declarations upstream.

## Decision

Ship the type-level ~Escapable upgrade plus the CONFIRMED method extensions. Defer `map(first:second:)` pending Gap A resolution. Stdlib conformances stay Escapable-only intrinsically.

The type-level upgrade is **source-additive** for existing consumers — Copyable + Escapable types still satisfy the new constraints (suppressions are permissive).

## Cross-references

- Empirical reproduction: `Experiments/escapable-arm-support/`
- Ecosystem-wide research: `swift-institute/Research/escapable-support-pair-either-product.md`
- Sibling-package research (Either): `swift-either-primitives/Research/escapable-arm-support.md`
- Upstream institute protocol upgrades: swift-equation-primitives `3495e50`, swift-hash-primitives `0e5708e`, swift-comparison-primitives `a4fd209`
