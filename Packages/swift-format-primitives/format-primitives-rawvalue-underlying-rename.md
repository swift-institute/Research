# Format Primitives — `rawValue` → `underlying` / `Carrier.\`Protocol\`` Rename

**Date:** 2026-05-03
**Tier:** 14 (downstream of carrier/tagged renames)
**Upstream pins:** carrier `2b57aac`, tagged `46ded75`, string `7a60ebf` (not consumed)

## Scope

This package depends on `Standard Library Extensions` and `Tagged Primitives`. The
carrier rename does not transit through SLE (no Carrier surface), so the only
mechanical exposure is the Tagged extension in `Tagged+Format.swift`.

## Phase 1 — Design Audit

### Q1. Own `public let rawValue` types? (Pre-authorized for rename.)

**No.** The package does not declare any types with `public let rawValue` storage
following the cardinal/ordinal/vector pattern. Public stored properties are:

- `Format.Decimal.shouldRound: Bool`
- `Format.Decimal.precisionDigits: Int?`
- `Format.Case.Insensitive.value: String`

None of these is a `rawValue` field — they are domain-named fields on plain
`Sendable` value types. **No own-field rename applies.**

### Q2. Editorial public surface that could move to a sibling target / SLI?

**None identified.** Every public declaration is a Format-domain concept:
`Format`, `Format.Decimal`, `Format.Numeric`, `Format.Numeric.Sign`,
`Format.Numeric.Notation`, `Format.Numeric.Separator`, `Format.Case`,
`Format.Case.Insensitive`, `Format.Style` (protocol), and the
`BinaryFloatingPoint`/`StringProtocol`/`Tagged`-extension `formatted(_:)` /
`caseInsensitive` accessors. All belong to this package's mission.

### Q3. Three-consumer rule.

The package mission is the `Format` namespace itself. The three-consumer rule
triggers on *speculative* infrastructure carved out for unspecified consumers;
it does not gate the namespace owner from existing. **No issue.**

### Q4. Compound identifiers / `*Tag` suffixes / code-surface violations.

Spot-checked all sources:

- No `*Tag` suffixes (no phantom-type tag declarations).
- No compound public identifiers — every type sits under `Format.*`.
- File naming follows `One.Type.Per.File.swift` convention.
- `Tagged+Format.swift` is a single extension on `Tagged`; permissible per
  ecosystem convention for cross-module add-ons.

**No code-surface violations.**

### Verdict

**No escalation.** Q2/Q3/Q4 produce nothing non-trivial. Proceed to Phase 2 with
mechanical rename of the single Tagged extension site.

## Phase 2 — Touch Plan

Single-file mechanical rename in `Sources/Format Primitives/Tagged+Format.swift`:

- `RawValue: BinaryFloatingPoint` → `Underlying: BinaryFloatingPoint`
- `format.format(rawValue)` → `format.format(underlying)`

No other files reference `rawValue` / `RawValue` / `Carrier` / `init(rawValue:)`.
