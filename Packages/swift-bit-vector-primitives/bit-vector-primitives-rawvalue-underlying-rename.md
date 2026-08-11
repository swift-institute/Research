# Bit Vector Primitives — `rawValue` → `underlying` Rename Audit

**Date**: 2026-05-03
**Cycle**: Carrier/Tagged downstream migration, tier 11
**Upstream pins**:
- `swift-carrier-primitives` `2b57aac` — `Carrier` namespace + `Carrier.\`Protocol\``; `raw` → `underlying`
- `swift-tagged-primitives` `46ded75` — `Tagged<Tag, Underlying>`, `.underlying`, `init(_:)`, `init(_unchecked:)`
- `swift-bit-primitives` `b69b617`, `swift-bit-pack-primitives` `103128e`, `swift-property-primitives` `c4bce7f`, `swift-sequence-primitives` `87e200e` (all migrated, green)

## Q1 — Own `public let rawValue` types? (Pre-authorized for rename)

**Finding**: None.

`grep -rn "rawValue\|RawValue\|Carrier\|Tagged" Sources Tests --include="*.swift"` returns zero matches across the entire package. No own-field rawValue types, no Carrier.\`Protocol\` conformances, no direct Tagged usage.

The package is purely structural: nested namespace types (`Bit.Vector`, `Bit.Vector.Bounded`, `Bit.Vector.Inline<n>`, `Bit.Vector.Static<n>`, `Bit.Vector.Dynamic`, plus per-variant `Ones`/`Zeros` view structs and `All`/`Capacity`/`Statistic`/`Clear`/`Set`/`Pop` namespaces) backed by `Bit.Pack<UInt>` storage from `Bit_Pack_Primitives` and `Index<UInt>` (which IS `Tagged<UInt, Ordinal>` upstream, but used only via its public arithmetic API).

**Verdict**: No own-field renames apply. Cardinal/Ordinal/Vector precedent is not invoked here.

## Q2 — Editorial public surface that could move to a sibling target / SLI?

**Finding**: None worth flagging.

The package already segregates per-variant code into separate targets (`Bit Vector Primitives Core`, plus `Static`/`Bounded`/`Inline`/`Dynamic` variants and an umbrella product). `IteratorProtocol` and `Sequence` conformances are stdlib-bridge code but live in `+Sequence.swift` files within each variant target — already consistent with the implicit-SLI split convention. No Foundation, no extra integrations.

**Verdict**: No editorial moves recommended.

## Q3 — Three-consumer rule

**Finding**: Not in scope for this migration.

This is a leaf primitive with internal variants; consumer count is governed by the higher-tier audit, not this rename cycle.

**Verdict**: No action.

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

**Finding**: None surfaced during the migration audit.

The package strictly uses nested namespaces (`Bit.Vector.Inline.Capacity.View`, `Bit.Vector.Bounded.All`, `Bit.Vector.Ones.View.Iterator`, etc.). Internal-only error enum names use the `__BitVector*Error` hoisted-internal pattern, which is the established package-internal convention for typed-throws machinery and is not a code-surface violation at the public level (the error is exposed as `Bit.Vector.<variant>.Error` typealias / nested `Error`).

**Verdict**: No action.

## Phase 1 verdict

Q1/Q2/Q3/Q4 are all clean. No design-level escalation. The migration reduces to a **cascade-residual fix**: one downstream overload-resolution issue surfaced after the upstream Carrier/Tagged rename — see Phase 2.

## Phase 2 — Cascade-residual: `Index<UInt> += .one` overload ambiguity

The only build failures in this package post-migration come from variant target sites that import `Affine_Primitives` and write `w += .one` where `w: Index<UInt>` (i.e. `Tagged<UInt, Ordinal>`):

- `Sources/Bit Vector Inline Primitives/Bit.Vector.Inline+mutating.swift:55`
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+mutating.swift:55`
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+protocols.swift:23, 40`
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+conversions.swift:38`

Two `+=` operators are visible at these call sites:

1. `Ordinal.\`Protocol\` where Count: Carrier.\`Protocol\`<Cardinal>` — `+= (Self, Count)` — non-throwing, RHS = `Tagged<UInt, Cardinal>`.
2. `<O: Ordinal.\`Protocol\`, V> += (O, V) throws(Ordinal.Error) where V: Carrier.\`Protocol\`, V.Underlying == Affine.Discrete.Vector` — `@_disfavoredOverload`, throwing.

After the migration (`Affine.Discrete.Vector: Carrier.\`Protocol\`` instead of the old `Vector.Protocol`), both `Tagged<UInt, Cardinal>` and `Tagged<UInt, Affine.Discrete.Vector>` expose `.one` via the `Carrier.\`Protocol\`` `.one` re-anchor extensions. The compiler now resolves `.one` toward overload (2) and reports the throwing call as an unhandled error.

**Fix per brief's "Cascade-drop residuals" guidance**: lift `.one` to its disambiguated form at each call site so overload (1) is uniquely selected. The minimal mechanical change is `w += .one` → `w += Index<UInt>.Count.one` (or equivalently `Tagged<UInt, Cardinal>.one`).

This is not an own-field rename and not a public-surface change; it is a five-site call-site disambiguation under the existing Tagged/Ordinal/Cardinal API.

## Files touched

Cascade-residual call-site disambiguation (`+= .one` → `+= Index<UInt>.Count.one`):
- `Sources/Bit Vector Inline Primitives/Bit.Vector.Inline+mutating.swift`
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+mutating.swift`
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+protocols.swift` (two sites)
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+conversions.swift`

Mechanical Tagged-init rename (`__unchecked: ()` → `_unchecked:`):
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+ones.swift` (one site)
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+zeros.swift` (one site)

## Build / test status

- `swift build`: green.
- `swift test`: 70 tests across 11 suites pass.

