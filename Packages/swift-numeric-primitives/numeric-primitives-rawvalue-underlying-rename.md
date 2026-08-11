# Numeric Primitives — `Tagged.underlying` + `Carrier.\`Protocol\`` Migration Audit

**Date**: 2026-05-03
**Scope**: `swift-numeric-primitives` (deps: `swift-tagged-primitives` @ `46ded75`)
**Verdict**: **No-op migration** — package does not consume the renamed surface.

## Q1. Own `public let rawValue` types?

**None.** Verified by `grep -rn "public let rawValue\|init(rawValue:" Sources/ Tests/`.

`swift-numeric-primitives` declares its public surface via the namespace
enums `Numeric`, `Numeric.Integer`, `Numeric.Relaxed`, `Numeric.Math`,
`Numeric.Fraction`, `Numeric.Rounding`, `Numeric.Transcendental`, etc. — none
of these are tagged-primitives `Tagged` types and none expose a `rawValue`
let-property. The closest contact with `Tagged` is a single re-export:

```swift
// Sources/Numeric Primitives Core/exports.swift
@_exported import struct Tagged_Primitives.Tagged
```

This re-export survives the rename unchanged (it does not reference
`rawValue` or `Underlying`).

## Q2. Editorial public surface that could move to a sibling target / SLI?

**None surfaced by this audit.** The package is already split into
five well-scoped targets (`Numeric Primitives Core`, `Real Primitives`,
`Numeric Relaxed Primitives`, `Integer Primitives`, plus the umbrella
`Numeric Primitives`) and a separate `Numeric Primitives Test Support`
target. The relaxed/transcendental SLI carve-out was already executed
(per `Package.swift` comments — `Numeric Relaxed Primitives` exists
specifically so `public import _Shims` does not leak through `Real Primitives`).

No new SLI candidate emerges from the rename audit.

## Q3. Three-consumer rule

**Out of scope for this audit.** The three-consumer rule applies when
proposing new shared infrastructure; this package's public surface
predates the rename and is not being expanded. No new types are added
by the migration.

## Q4. Compound identifiers / `*Tag` suffixes / code-surface violations

- **`*Tag` suffixes**: zero matches in `Sources/` or `Tests/`.
- **Compound identifiers**: pre-existing public methods `multiplyAdd`
  (`Numeric.Relaxed.swift:72,94`) are technically compound but are
  unrelated to the rename and out of scope. `callAsFunction` is the
  Swift call-operator method, not a compound identifier.
- **`Carrier`/`Carrying`**: zero matches; this package never adopted the
  pre-rename `Carrier` protocol surface.
- **`rawValue`/`RawValue`**: zero matches in `Sources/` and `Tests/`
  (modulo the single re-export of `Tagged` itself, which is unaffected).

No code-surface violations introduced or surfaced by this migration.

## Verdict

`Tagged.underlying` + `Carrier.\`Protocol\`` migration is a **no-op** for
`swift-numeric-primitives`. No source edits, no cascade-drop residuals.
The single point of contact with the renamed module is the
`@_exported import struct Tagged_Primitives.Tagged` line in
`Numeric Primitives Core/exports.swift`, which is purely a re-export of
the type itself and references neither `rawValue`/`Underlying` nor
`Carrier`/`Carrying` symbols.

Phase 2 expectation: `swift package update` + clean build pass with
zero edits.
