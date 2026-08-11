# Bit Pack Primitives — `rawValue` → `underlying` and `Carrier.Protocol` Migration Audit

**Date:** 2026-05-03
**Scope:** `swift-bit-pack-primitives` (tier 10a downstream of carrier/tagged renames)
**Upstream commits:**
- `swift-carrier-primitives` `2b57aac` — `Carrier` → namespace enum; canonical `Carrier.\`Protocol\``; `raw` → `underlying`.
- `swift-tagged-primitives` `46ded75` — `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `.rawValue` → `.underlying`; `init(rawValue:)` → `init(_:)`; `init(_unchecked: ())` → `init(_unchecked:)`.

## Summary

`swift-bit-pack-primitives` is **migration-neutral**. It declares no `Carrier.\`Protocol\`` conformer, no `Tagged` instantiation, no `public let rawValue`, no `init(rawValue:)`, and no `init(_unchecked:)`. The package consumes higher-level Index/Ordinal/Cardinal/Affine APIs whose renames have already been applied upstream (bit-index@`4c1aa30`, transitive deps green). This audit therefore covers the four checklist questions and finds nothing to change in this package.

## Inventory

Source target: `Bit Pack Primitives` (6 files, ~140 LoC):

- `Bit.Pack.swift` — `Bit.Pack<Word>` struct; word/bit field projections; `bitWidth` typed constant.
- `Bit.Pack.Location.swift` — `Bit.Pack.Location` struct; `word: Index<Word>`, `bit: Index<Bit>.Offset`, `mask: Word`.
- `Bit.Pack.Words.swift` — `Bit.Pack.Words` struct wrapping `Index<Word>.Count`.
- `Bit.Pack.Bits.swift` — `Bit.Pack.Bits` struct wrapping `Bit.Index.Count`.
- `Bit.Index+Pack.swift` — `Bit.Index.location(bitsPerWord:)` accessor.
- `exports.swift` — `@_exported import Bit_Primitives` / `Bit_Index_Primitives`.

Grep audit (entire `Sources/` and `Tests/`):

```
$ grep -rn -E "rawValue|RawValue|Carrier|Tagged|_unchecked|some Carrier|any Carrier" Sources Tests
(no matches)
```

## Q1 — Own `public let rawValue` types?

**None.** No type in this package declares its own `rawValue` storage. The structs hold typed fields (`Index<Word>`, `Index<Bit>.Offset`, `Bit.Index.Count`, `Word`) that are themselves carriers/cardinals defined upstream. The renames to `.underlying` / `Carrier.\`Protocol\`` have already landed in those upstream types; this package merely passes the values through.

**Verdict:** no rename work in this package. Pre-authorized rename does not apply.

## Q2 — Editorial public surface that could move to a sibling target / SLI?

**None.** All public surface is load-bearing for the bit-packing layout vocabulary:

- `Bit.Pack<Word>` — the layout witness type. Core domain.
- `Bit.Pack.Location` / `.Words` / `.Bits` — derived projections. Core domain.
- `Bit.Index.location(bitsPerWord:)` — the bridge from typed bit index to physical location. Core domain.

Nothing here is editorial / convenience / Foundation-bridge / Standard-Library-Integration-shaped. There is no candidate for a sibling target or SLI carve-out.

**Verdict:** no escalation.

## Q3 — Three-consumer rule

The package's mission statement is "what is the bit-packing layout (location/words/bits projections) for a typed `Bit.Index` over a `Word` storage?" The exposed types (`Pack`, `Pack.Location`, `Pack.Words`, `Pack.Bits`, `Bit.Index.location(_:)`) form a small, cohesive vocabulary and are expected to be consumed by:

1. Bit-buffer / bitset implementations (storage that actually owns `[Word]` and uses `Location` to index into it).
2. Bit-vector / packed-array primitives at L3 that compose this layout.
3. Higher-level structures (e.g. compressed sets, succinct data structures) that need to compute word/bit decomposition without owning a buffer.

The surface is small enough that a per-type three-consumer audit is not productive at this tier; every type either projects layout (Words/Bits) or names a position (Location) — both are needed by any consumer that actually packs bits into words.

**Verdict:** no escalation.

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

Walked all six source files. Findings:

- All public types are nested under `Bit` / `Bit.Pack` (specification-mirroring nesting per [API-NAME-001]).
- No compound type names (`BitPackLocation`, etc.) — clean namespacing.
- No compound method or property names — `bit.location(bitsPerWord:)`, `pack.words.count`, `pack.bits.unused` all use nested accessors per [API-NAME-002].
- No `*Tag`-suffixed phantom types.
- No throwing functions (so [API-ERR-001] typed-throws not in scope).
- One type per file ([API-IMPL-005]) holds: `Bit.Pack.swift` declares `Bit.Pack`; `Bit.Pack.Location.swift` declares `Bit.Pack.Location`; `Bit.Pack.Words.swift` declares `Bit.Pack.Words`; `Bit.Pack.Bits.swift` declares `Bit.Pack.Bits`; `Bit.Index+Pack.swift` is an extension file (allowed). `exports.swift` is the SwiftPM-required re-export shim.
- No Foundation imports ([PRIM-FOUND-001]).
- `Affine_Primitives` / `Index_Primitives` / `Bit_Primitives` / `Bit_Index_Primitives` use the underscore-module convention.

**Verdict:** no violations, no escalation.

## Phase 1 verdict

Migration is a **no-op** in this package. Proceed to Phase 2 build verification; if green, commit this design note alone with the "no-op" message.

## Phase 2 result

```bash
$ swift package update    # ok — all transitive deps resolved
$ rm -rf .build
$ swift build             # Build complete! (11.28s)
```

Clean build from a fresh `.build` against the renamed `swift-carrier-primitives@2b57aac` / `swift-tagged-primitives@46ded75` (and the already-migrated `swift-bit-primitives@b69b617`, `swift-bit-index-primitives@4c1aa30`, plus all transitive cardinal/ordinal/affine/index packages). No source change required.

**Commit:** design note only, message: `Audit: Tagged.underlying + Carrier.\`Protocol\` migration is a no-op`. No tag, no push.
