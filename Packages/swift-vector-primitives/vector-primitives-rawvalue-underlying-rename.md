# vector-primitives — rawValue → underlying rename, design audit

**Tier**: 8b (downstream of carrier@2b57aac, tagged@46ded75, cardinal/ordinal/vector precedent)
**Date**: 2026-05-03
**Scope**: `/Users/coen/Developer/swift-primitives/swift-vector-primitives` only.

## Context

Three breaking renames cascade into this package:

1. **swift-carrier-primitives** `2b57aac` — `Carrier` enum namespace; `Carrier.\`Protocol\`` is the
   capability protocol; `raw` → `underlying`.
2. **swift-tagged-primitives** `46ded75` — `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`;
   `.rawValue` → `.underlying`; `init(rawValue:)` → `init(_:)`; `init(_unchecked: ())` →
   `init(_unchecked:)`. Tagged conforms to `Carrier.\`Protocol\`` unconditionally.
3. **Cardinal/Ordinal/Vector own-field precedent** — own-field `let rawValue` types adopt
   `_storage` + `Carrier.\`Protocol\`` extension shape.

Per v3 handoff Open Questions: own-field rawValue renames are **pre-authorized**.

## Audit Questions

### Q1. Own `public let rawValue` types?

**Answer: NONE.**

```bash
grep -rn "public let rawValue\|public var rawValue\|@usableFromInline let _storage" Sources Tests
# → no matches
```

`Vector` is a higher-order container: it stores `start: Index`, `end: Index`,
`_count: Index.Count`, and a `transform: @Sendable (Index) -> Bound` closure. None of
these are own-field rawValue carriers. All `.rawValue` and `.position.rawValue` access
sites in this package read from `Index_Primitives.Index` (= `Tagged<Element, Ordinal>`)
or from `Distance` types in transitive deps — never from a Vector-defined type.

Vector has no Carrier conformance to migrate, only consumer-side `.rawValue` accesses
that get mechanically rewritten to `.underlying`.

**Verdict: nothing to do for Q1; mechanical rename suffices.**

### Q2. Editorial public surface that could move to a sibling target / SLI?

**Answer: NONE that warrant relocation.**

Public-facing Vector API across `Vector Primitives Core`:

- `Vector<Bound: ~Copyable>` — core container type
- `Vector.Index` typealias (= `Index_Primitives.Index<Vector<Bound>>`)
- `Vector.ForEach`, `Vector.Drain` — tag enums (no `Tag` suffix — compliant)
- `Vector.Error` — typed-throws error namespace
- `Vector.Iterator`, `Vector.Reversed`, `Vector.Reversed.Iterator` — nested types
- `Vector.Prefix`, `Vector.Drop`, `Vector.Reversed.Prefix`, `Vector.Reversed.Drop` —
  view types
- Property accessors: `forEach`, `drain` (per-instance and per-Reversed)
- `init(count:transform:)`, `init(start:end:transform:)` (typed-throws)
- `count`, `start`, `end`, `isEmpty`
- `makeIterator() -> Iterator`, `reversed() -> Reversed`

The `Standard Library Integration` target carries `UnsafeRawPointer+Index`,
`UnsafeMutableRawPointer+Index`, `UnsafeRawBufferPointer+Index`,
`UnsafeMutableRawBufferPointer+Index` extensions — these are stdlib bridges and
correctly live in the SLI per [PRIM-SLI-*] / [MEM-SAFE-001] convention.

The `Vector Primitives Test Support` target carries test-only convenience inits
(`Vector(_ range: Swift.Range<UInt>)` etc.) — also correctly placed.

**Verdict: surface partition is already correct. Nothing to relocate.**

### Q3. Three-consumer rule

**Answer: vacuous in this package; rule applies upstream only.**

Vector is itself a three-consumer-type primitive (consumed by tier 9+ packages
already in green state — buffer, ring, etc.). Within this package, the
infrastructure consumed includes:

- `Index_Primitives.Index` — used as `Vector.Index` (= `Tagged<Vector<Bound>, Ordinal>`)
- `Property_Primitives.Property<Tag, Self>` — used for `.forEach`, `.drain` accessors
- `Cyclic_Primitives` — used by ordinal arithmetic chain transitively
- `Sequence_Primitives.Sequence.\`Protocol\`` — Vector's conditional conformance

All four deps are already in the green pre-rename state at the SHAs listed in the
brief. No new types are being introduced in this tier; no three-consumer
question is opened.

**Verdict: no three-consumer concerns.**

### Q4. Compound identifiers / `*Tag` suffixes / code-surface violations

**Answer: clean.**

- `Vector.ForEach`, `Vector.Drain` — Tag enums, no `Tag` suffix (compliant per
  [feedback_no_tag_suffix]).
- `forEach`, `drain` — single-word property accessors, not compound.
- `isEmpty`, `makeIterator`, `reversed` — stdlib-mirroring single concepts.
- `_borrowingForEach`, `_consumingDrain` — internal `_`-prefixed implementation
  details, called via Property.View; not public surface.
- File names: `Vector.swift`, `Vector.Prefix.swift`, `Vector.Reversed.Drop.swift` —
  all `Outer.Nested.swift` form per [API-IMPL-005] one-type-per-file.
- No `init(rawValue:)` on Vector itself — it carries no Carrier conformance.

**Verdict: code-surface compliant.**

## Verdict

All four questions resolve trivially. **Phase 1 surfaces no escalation.**

Proceed to Phase 2 mechanical migration:

- 5 occurrences of `.rawValue` → `.underlying` in test code
- 6 occurrences of `Vector<X>.Index(__unchecked: (), V)` → `Vector<X>.Index(_unchecked: V)`
  (these are `Tagged.init(_unchecked:)` calls via the `Index<T> = Tagged<T, Ordinal>`
  typealias; not Vector's own internal `init(__unchecked: Void, ...)` which remains
  package-internal as-is)

No own-field rename to apply. No Carrier conformance to update. No new types.
