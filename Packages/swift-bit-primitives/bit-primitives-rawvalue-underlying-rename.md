# bit-primitives — `rawValue` → `underlying` rename design audit

**Date**: 2026-05-03
**Cycle**: Tier 8a downstream migration (Tagged 46ded75 + Carrier 2b57aac)
**Scope**: `/Users/coen/Developer/swift-primitives/swift-bit-primitives`

## Context

Three breaking renames cascade into this package via its dep set
(cardinal `ac7f308`, carrier `2b57aac`, finite `ed5353b`, hash `6565134`,
tagged `46ded75`):

1. **Carrier**: `Carrier` → namespace `enum`; canonical capability spelled
   `Carrier.\`Protocol\``; member `raw` → `underlying`.
2. **Tagged**: `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`;
   `.rawValue` → `.underlying`; `init(rawValue:)` → `init(_:)`;
   `init(_unchecked: ())` → `init(_unchecked:)`.
3. **Cardinal/Ordinal/Vector precedent** — own-field `rawValue` →
   `Carrier.\`Protocol\`` adoption with `_storage` + `underlying` accessor.

The Pass-1 commit (`4d9d3b3`) referenced in the brief is not present in
this clone — origin/main is at `f1c32fe` (the latest `Migrate FixedWidthInteger+Cardinal shifts to Carrier<Cardinal>` chain ends at `7c70ebe`). Treat
this Pass as a fresh migration, not an extension of partial Pass-1 work.

## Q1 — Own `public let rawValue` types?

**Audit method**: full grep across `Sources/` for `rawValue` declaration
and storage shapes (`@usableFromInline let _storage`,
`public let rawValue`).

**Result**: **NONE.**

The package's three named-storage struct types do *not* use a
Carrier-shaped `rawValue` field:

| Type | Storage | Shape |
|------|---------|-------|
| `Bit.Set<Word>` | `@usableFromInline let word: Word` | concrete-typed field, not Carrier-conforming |
| `Bit.Mask<Word>` | (empty — `Word` is purely phantom) | no storage at all |
| `Bit.Order.Value<Payload>` | `Tagged<Bit.Order, Payload>` typealias | inherits Tagged's storage |

The package's two `enum`s are:

| Type | Backing | Origin of `rawValue` |
|------|---------|---------------------|
| `Bit` | `UInt8` (stdlib `RawRepresentable`) | stdlib synthesised — **NOT** Carrier |
| `Bit.Order` | (no rawValue) | plain enum; not RawRepresentable |
| `Bit.Order` (`Codable` impl) | string-encoded "msb"/"lsb" | n/a |

`Bit.rawValue` is the stdlib `RawRepresentable.rawValue` and **must not be
renamed** by the cascade. Likewise `init(rawValue: UInt8)` on `Bit` is the
stdlib synthesised initialiser.

**Verdict**: No cardinal/ordinal/vector-style own-field rename is
required in this package.

## Q2 — Editorial public surface?

Reviewed all six target products. Nothing surfaces that would warrant
moving to a sibling target or to SLI:

- `Bit Primitives Core` — `Bit`, `Bit.Order` (canonical types).
- `Bit Boolean Primitives` — Z₂-ring operators on `Bit`.
- `Bit Field Primitives` — `Algebra.Field where Element == Bit` witness.
- `Bit Primitives Standard Library Integration` — already houses the
  stdlib-touching surfaces (`Bit.Set<Word>`, `Bit.Mask<Word>`, the
  `<<`/`>>` overloads against `Carrier<Cardinal>`, `Comparable`,
  `Codable`, `ExpressibleByIntegerLiteral`, …).
- `Bit Primitives` — umbrella with `Bit.Value<Payload>` and the
  protocol-conformance shims (`Equation.\`Protocol\``,
  `Comparison.\`Protocol\``, `Hash.\`Protocol\``,
  `Finite.Enumerable`).
- `Bit Primitives Test Support` — fixtures.

The split is already clean: the only stdlib-bound code lives in SLI.
No code motion recommended.

## Q3 — Three-consumer rule

The split is fine-grained. Each variant target carries a focused
mission and is reachable independently. No new variant proposed and no
existing variant suggests merging.

The umbrella `Bit Primitives` and SLI exports respect the standard
ecosystem layering. No change.

## Q4 — Compound identifiers / `*Tag` suffix / code-surface violations?

Audit results:

- **No compound type names.** All type names are properly nested:
  `Bit.Set`, `Bit.Mask`, `Bit.Order`, `Bit.Value`, `Bit.Order.Value`,
  `Algebra.Field`.
- **No `*Tag` suffix.** `Bit.Order` is the phantom-tag concept used by
  `Tagged<Bit.Order, Payload>` and is named `Order`, not `OrderTag`.
- **No compound methods.** Methods such as `Bit.adding`, `Bit.flipped`,
  `bits.set.rank(below:)` are properly nested-accessor style.
- **No `Foundation` imports.**
- **Typed throws / specification mirroring**: not relevant here — the
  one throwing surface (`Field.z2.reciprocal`) carries the
  WORKAROUND-typed-throws annotation already noted in
  `Algebra.Field+Bit.swift`, and that closure is a no-op error type by
  contract.

Nothing flagged.

## Phase-2 plan (mechanical changes)

The only Carrier-`rawValue` access in the package is in
`Bit+Finite.Enumerable.swift` line 25 — `ordinal.rawValue` →
`ordinal.underlying` (Ordinal is now `Carrier.\`Protocol\``-conforming).

The only generic constraint touching `Carrier` is in
`FixedWidthInteger+Cardinal.swift`:

```swift
rhs: some Carrier<Cardinal>
```

→ rewrite to `some Carrier.\`Protocol\`<Cardinal>` (four sites in this
file).

The generic-parameter name `RawValue: FixedWidthInteger` in
`FixedWidthInteger+Cardinal.swift` is a *local generic placeholder* and
unrelated to Carrier's old `RawValue` associated type. Although the
mechanical regex `\bRawValue\b` would rewrite it to `Underlying`, doing
so confuses the reader (the generic stands for the integer being
shifted, not for a Carrier underlying). **Decision: leave it as
`RawValue`** — the rename is a Carrier-cascade concern, and this is a
pre-existing local generic-parameter spelling. Avoid drive-by rename.

The stdlib `RawRepresentable` `Bit(rawValue:)` and `bit.rawValue` calls
in `Bit+Comparable.swift`, `Bitwise Operators.swift`,
`Bit+Normalizing.swift`, and the `Self(rawValue:)` call inside
`Bit+Finite.Enumerable.swift` line 25's RHS **must be preserved**. They
are stdlib API, not Carrier API.

## Verdict

**Q1**: No own-field rename. **No escalation.**
**Q2**: No code motion. **No escalation.**
**Q3**: No regrouping. **No escalation.**
**Q4**: No code-surface violations. **No escalation.**

Proceed to Phase-2 mechanical migration without principal review.
