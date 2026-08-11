# Audit: `Tagged.underlying` + `Carrier.\`Protocol\`` Migration in `swift-bit-index-primitives`

**Date**: 2026-05-03
**Scope**: `/Users/coen/Developer/swift-primitives/swift-bit-index-primitives`
**Migration cycle**: ecosystem-wide rename `Tagged.rawValue` → `Tagged.underlying` and `Carrier` → `Carrier.\`Protocol\``.

## TL;DR

This package is a **no-op** for the migration cycle. It declares **no own types**, holds **no `rawValue`/`RawValue` surface**, and has **zero direct `Tagged_Primitives` or `Carrier_Primitives` imports**. The four source files are entirely composed of (a) one typealias (`Bit.Index = Index<Bit>`), (b) extension static constants on `Affine.Discrete.Ratio`, and (c) one cross-domain `init` lifting a byte index to a bit index via `Count`-chain arithmetic. None of these surfaces participate in the rename.

## Source inventory

```
Sources/Bit Index Primitives/
├── Bit.Index.swift                       # typealias Bit.Index = Index<Bit>
├── Bit+Affine.Discrete.Ratio.swift       # extension constants: bitWidth, bitsPerByte, bitsPerWord
├── Bit.Index+Byte.swift                  # cross-domain init: Bit.Index from Index<UInt8>
└── exports.swift                         # @_exported import { Bit, Index, Affine }_Primitives
```

Total: 4 files, ≈ 150 SLOC.

## Migration-relevant grep results

```
grep -rn "rawValue\|RawValue\|Tagged\|Carrier\|Underlying" Sources/   →  (no matches)
grep -rn "rawValue\|RawValue\|Tagged\|Carrier"            Tests/      →  (no matches)
```

The package consumes upstream Tagged-backed types (`Index<Bit>`, `Affine.Discrete.Ratio<From, To>`) only through their public, post-rename-clean APIs (`init(_:)`, `*`, `+`, `.zero`, `.bitWidth`). It never reaches into `.rawValue` or constrains on `RawValue` / `Carrier` directly.

## Audit questions

### Q1 — Own `public let rawValue` types?

**None.** This package declares zero own `struct`/`class`/`enum`/`actor`. All public surface is one typealias and a handful of extension members on upstream types. The pre-authorized rename of `public let rawValue` storage is not applicable here.

### Q2 — Editorial public surface that could move to a sibling target / SLI?

**No editorial concerns.** The three semantic aliases on `Affine.Discrete.Ratio<From, To>` (`bitWidth`, `bitsPerByte`, `bitsPerWord`) are domain-essential vocabulary for a bit-index package — they are the package's only reason to exist alongside the typealias. Nothing reads as a candidate for an SLI carve-out or sibling target.

### Q3 — Three-consumer rule

**Not triggered.** The rule applies to candidate L1 type declarations, of which this package has zero. The typealias `Bit.Index = Index<Bit>` is a convergence point, not a new type.

### Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

**None found.**

- All names follow `Nest.Name` (`Bit.Index`, `Affine.Discrete.Ratio`).
- No `*Tag` suffix anywhere; `Bit` is the phantom-typed concept, used directly as a generic argument (`Index<Bit>`, `Ratio<From, Bit>`).
- One file per type/extension family. Module name is space-cased (`Bit Index Primitives`), imported with underscores (`Bit_Index_Primitives`), per ecosystem convention.
- `public import` is used uniformly for re-exposed dependencies.

## Verdict

**Phase 1 verdict**: clean. Nothing to escalate.

**Phase 2 expectation**: build is expected to be green out of the box, because the package never references the renamed identifiers. The fresh dependency-resolution against the post-rename pinned versions of `bit`, `index`, `affine`, `ordinal` is the only mechanical action required.

If the build is unexpectedly red, that is upstream contamination (a renamed identifier leaking through `@_exported` re-exports of upstream APIs we touch), not local debt — and the cascade-drop residual fixes (`Cardinal(_:)` lift, bare-type-vs-`Carrier` overload split) called out in the brief would apply.
