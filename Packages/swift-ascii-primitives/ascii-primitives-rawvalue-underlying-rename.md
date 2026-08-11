# swift-ascii-primitives — Tagged.underlying + Carrier.`Protocol` migration audit

> **Superseded by**: ASCII.Code structural-shape implementation arc 2026-05-16
> (commit `be7c1fe` on swift-ascii-primitives; RECOMMENDATION at
> `swift-institute/Research/ascii-code-structural-shape.md` v1.0.0 Shape (a)).
> Reason: the Q1 pre-authorized `rawValue → underlying` rename for
> `ASCII.Byte` landed as part of the structural-shape arc (file renamed
> to `ASCII.Code.swift`; storage now `public let underlying: UInt8` with
> `init(_ underlying: consuming UInt8)`; conforms `Byte.Protocol` +
> `Carrier.Protocol<UInt8>` per the per-domain capability-marker recipe
> [API-NAME-001c]). Doc retained as historical audit record covering Q1
> (rename verdict), Q2 (no editorial moves), Q3 (consumer count), and Q4
> (latent compound-identifier debt for `hexValue`/`digitValue` — still
> open as a future code-surface pass).

**Date**: 2026-05-03
**Cycle**: Downstream leaf-package verification for ecosystem-wide
`Tagged.rawValue → underlying` rename and `Carrier.Protocol` canonicalization.

## Inputs

- Package: `/Users/coen/Developer/swift-primitives/swift-ascii-primitives`
- Direct deps in `Package.swift`: **none** (zero `.package(path:)` and zero
  `.package(url:)` entries).
- Tagged / Carrier import surface: **none** — verified by grep across
  `Sources/` and `Package.swift`. No `import Tagged*`, no `Carrier`, no
  `Tag` suffix anywhere in the package.

## Q1. Own `public let rawValue` types?

**Yes, exactly one**: `ASCII.Byte` in
`Sources/ASCII Primitives/ASCII.Byte.swift:24-31`:

```swift
public struct Byte: Sendable {
    public let rawValue: UInt8

    @_transparent
    public init(rawValue: UInt8) { self.rawValue = rawValue }
}
```

This is a hand-rolled wrapper, not a `Tagged<...>` typealias. It is the only
`public let rawValue` declaration in the package (verified by grep).

Per the brief, hand-rolled `public let rawValue` types are pre-authorized
for the rename. No other types qualify; no other rename action required.

The internal call sites that read `rawValue` (in `ASCII.Byte+Parsing.swift`,
`ASCII.Byte+Classification.swift`, `UInt8+ASCII.swift`) will move with the
rename if/when the umbrella migration choreographs `ASCII.Byte` specifically.
Within the closed leaf, the rename is mechanical and self-contained.

## Q2. Editorial public surface — sibling target / SLI candidates?

**No movement recommended.**

The package has a single product, `ASCII Primitives`, with one target. The
public surface is uniformly INCITS 4-1986 vocabulary:

- `ASCII` namespace (Byte, Character, Case, Classification, Parsing,
  Validation, Serialization, Decimal, Hexadecimal, SPACE, Line.Ending,
  Case.Conversion, Character.Control, Character.Graphic).
- Two convenience accessor targets: `Character+ASCII.swift` and
  `UInt8+ASCII.swift` extending stdlib types.

The two stdlib-extension files (`Character+ASCII.swift`, `UInt8+ASCII.swift`)
are the only candidates that *could* be argued for SLI extraction — they
extend stdlib types directly. However:

1. They are tiny (one nested `ASCII` struct on `Character` and a callable
   accessor on `UInt8`) and carry no allocation / no unsafe / no extra
   protocol-conformance surface beyond a bridge to `ASCII.Byte`.
2. They are the *primary public ergonomic affordance* of the package
   (`UInt8.ascii.A`, `byte.ascii.isLetter`, `"x".ascii?.isWhitespace`).
   Splitting them out would require every consumer to add an extra
   import for the convenience layer that is the package's whole point.
3. There is no [MEM-SAFE-001] carve-out trigger here (no Array/Dict
   conformance, no unchecked Sendable, no @_rawLayout) — so the SLI
   pattern's normal justification is absent.

**Verdict**: keep the two extension files in the main target.

## Q3. Three-consumer rule.

**Comfortably exceeded.** Cross-ecosystem grep for
`import ASCII_Primitives` outside `swift-ascii-primitives` itself returns
at least these primary-source consumers (excluding `.build` artefacts):

- `swift-primitives/swift-ascii-serializer-primitives`
- `swift-primitives/swift-ascii-parser-primitives`
- `swift-primitives/swift-base62-primitives`
- `swift-primitives/swift-lexer-primitives`
- `swift-primitives/swift-terminal-primitives`
- `swift-primitives/swift-glob-primitives`
- `swift-primitives/swift-loader-primitives`
- `swift-foundations/swift-parsers`

Eight first-class downstream consumers — far above the three-consumer
existence threshold. No re-scoping action recommended.

## Q4. Compound identifiers / `*Tag` suffixes / code-surface violations.

- **`*Tag` suffixes**: none. Grep is empty.
- **Tagged usage**: none.
- **Compound type names**: none — every public type sits inside the `ASCII`
  namespace or a stdlib-type extension nest.
- **Compound method/property names**: the `is*` family
  (`isASCII`, `isWhitespace`, `isControl`, `isVisible`, `isPrintable`,
  `isDigit`, `isHexDigit`, `isLetter`, `isAlphanumeric`, `isUppercase`,
  `isLowercase`) is present on `ASCII.Byte` and on the `Character.ASCII`
  nested struct. These mirror Swift stdlib precedent
  (`Unicode.Scalar.isASCII`, `Character.isWhitespace`, etc.) and are the
  conventional shape for boolean classification predicates. Strict
  reading of [API-NAME-002] would flag them, but the stdlib-mirroring
  carve-out applies (no reasonable nest-and-accessor refactor exists
  without breaking consumer call-sites that mirror stdlib idioms).
- **`hexValue` / `digitValue`** (`ASCII.Byte+Parsing.swift`): these *are*
  compound and have no stdlib precedent. Candidate for `byte.hex.value`
  / `byte.digit.value` nest-and-accessor refactor. **Out of scope for
  the current downstream Tagged-migration cycle — flagged for a future
  code-surface pass.**

No blocking violations for the current migration.

## Verdict

**No-op**, as predicted by the brief.

- Q1: one hand-rolled `rawValue` type (`ASCII.Byte`) — pre-authorized,
  but the rename is *not* part of this cycle's scope (no Tagged
  consumer to drive it). Rename can be sequenced into a future code-
  surface pass alongside `hexValue` / `digitValue`.
- Q2: no editorial moves recommended.
- Q3: 8 consumers, well past threshold.
- Q4: only one minor latent compound-identifier debt (`hexValue`,
  `digitValue`) — does not block this migration cycle.

No code changes required. Build/test should pass green.
