# Ecosystem-wide associatedtype Error triage — inventory + triage

<!--
---
version: 1.0.0
last_updated: 2026-05-20
status: RECOMMENDATION
---
-->

## Context

The byte-discipline arc (2026-05-19/2026-05-20) redesigned `Byte.\`Protocol\``
around an `associatedtype Error: Swift.Error = Never` pattern:

```swift
public protocol `Protocol` {
    associatedtype Error: Swift.Error = Never
    init(_ byte: Byte) throws(Self.Error)
}
```

Per [API-BYTE-001] / [API-NAME-001c] the structural property is:

- Universal-domain conformers (`Byte`, `Tagged<Tag, Byte>`) take the default
  `Error == Never`. `throws(Never)` is treated as non-throwing at call sites,
  so existing call sites compile unchanged.
- Refined-domain conformers (`ASCII.Code`, whose valid range is `0x00–0x7F`)
  declare a concrete `Error` and throw on invalid input.
- Default impls that depend on totality (`zero`, `max`, `init(integerLiteral:)`,
  the universal-bitwise operators) are gated `where Error == Never` so refined
  conformers can't silently lift an out-of-range byte.

This document inventories every institute-owned protocol in
`swift-primitives` / `swift-standards` / `swift-foundations` whose surface
could conceivably benefit from the same redesign, then triages each per the
rubric. The deliverable is the input to a future per-protocol execution arc;
no source changes are proposed here.

## Methodology

**Pass 1 — Inventory**. Two parallel Explore subagents enumerated every
`public protocol` declaration across:

- `/Users/coen/Developer/swift-primitives/` (~70 packages, ~265 protocols)
- `/Users/coen/Developer/swift-standards/` (~25 packages)
- `/Users/coen/Developer/swift-foundations/` (~120 packages, ~25 protocols)

Out-of-scope per the dispatching handoff: `Tests/`, `Experiments/`,
`Examples/`, DocC catalogs, and spec-implementation packages
(`swift-rfc-*`, `swift-iso-*`, `swift-ietf-*`, `swift-incits-*`) which
conform to rather than define protocols of this shape.

Of the ~290 protocols found, the rule fires (requires triage) for protocols
that EITHER declare an `init` requirement OR have a method/property
requirement whose semantics could partial-fail for some refined conformer.
The vast majority (rendering protocols, marker protocols, key protocols,
view-tree protocols, handler-linking protocols) carry no init and no
fallible methods, and are out of triage scope.

**Pass 2 — Triage**. For each in-scope protocol, the rubric (from the
dispatching handoff) maps onto one of six verdicts:

| Verdict | When |
|---|---|
| **FITS cleanly** | Init/method requirement + ≥1 plausible refined conformer + universal-conformer benefits from `Error == Never` |
| **ALREADY typed** | Protocol already uses typed throws with sensible Error (or `Failure`) AT |
| **DOES NOT FIT — no refined conformers** | Universal parameter space IS the conformer's value space; default `Error == Never` would always apply |
| **DOES NOT FIT — failure is structural** | Partial-failure is not value-based (I/O, allocation, RNG); typed but structural |
| **DEFER — needs deeper investigation** | Candidate properties present but conformer landscape unclear |
| **DEFER — ecosystem ripple too large** | Pattern fits but cohort + downstream consumer count makes execution a class-(c) arc |

## Reference (the originating arc)

The byte-discipline arc landed the pattern at:

| Commit | Package | Protocol |
|---|---|---|
| `3f3b44a` | swift-byte-primitives | `Byte.\`Protocol\`` |
| `68605eb` | swift-ascii-primitives | `ASCII.Code` (conformer side) |

Reference files:

- `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift:85` — protocol declaration with associatedtype Error
- `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Tagged+Byte.Protocol.swift:27` — recursive Tagged propagation pattern (`typealias Error = Underlying.Error`)
- `swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Byte.Protocol.swift:37` — refined-conformer pattern with concrete Error, throwing init, own `.zero` / `.max` / `init(integerLiteral:)`

Skill anchors: [API-BYTE-001…007] in `byte-discipline`; [API-NAME-001c]
capability-marker recipe in `code-surface`. Research anchors:
`byte-protocol-capability-marker.md` v1.1.0;
`byte-arithmetic-conformance.md` v1.0.0.

## Pass 1 — Inventory

The full enumeration found ~290 public protocols across the three layers.
For triage, the structural cut is:

- **In scope for triage** (init or fallible method): ~30 protocols across L1/L3
- **Out of triage scope** (no init, no fallible method): ~260 protocols

Below is the in-scope set, capturing per-protocol structural facts.
Out-of-scope protocols are listed only by package for completeness; they
share a uniform verdict (DOES NOT FIT — failure is structural OR no
init/fallible-method requirements).

### A. Reference protocols (already implementing the pattern)

#### A.1 — `Byte.\`Protocol\`` (swift-byte-primitives)

| Field | Value |
|---|---|
| Package | swift-byte-primitives |
| File | `Sources/Byte Primitives/Byte.Protocol.swift:85` |
| Init requirements | `init(_ byte: Byte) throws(Self.Error)` |
| Fallible method requirements | none beyond init |
| Existing universal conformer | `Byte` (Error = Never) |
| Existing refined conformer | `ASCII.Code` (Error = `ASCII.Code.Error`) via swift-ascii-primitives |
| Hypothetical refined conformers | `Latin1.Byte`, `UTF8.Code_Unit`, per-RFC octet types |
| Current failure handling | typed throws via associatedtype Error = Never |

This is the reference; no triage entry below.

#### A.2 — Sibling-shape protocols already using an Error/Failure associatedtype

The following protocols already implement the pattern (or a near-equivalent).
They are listed here for completeness; the triage verdict for each is
**ALREADY typed** (see Pass 2).

| Protocol | Package | File:line | AT name | Default? | Notes |
|---|---|---|---|---|---|
| `Parser.\`Protocol\`` | swift-parser-primitives | `Sources/Parser Primitives Core/Parser.Parser.swift:90` | `Failure` | `= Never` | Combinator parser core |
| `Serializer.\`Protocol\`` | swift-serializer-primitives | `Sources/Serializer Primitives Core/Serializer.Protocol.swift:34` | `Failure` | `= Never` | Combinator serializer core |
| `Coder.\`Protocol\`` | swift-coder-primitives | `Sources/Coder Primitives/Coder.Protocol.swift:48` | `Failure` (inherited) | n/a | Refines Parser + Serializer; Failure unified |
| `Command.\`Protocol\`` | swift-arguments | `Sources/Command Schema/Command.Protocol.swift:60` | `Failure` | `= Command.Error` | CLI command async run |
| `Command.Schema.Visitor` | swift-arguments | `Sources/Command Schema/Command.Schema.Visitor.swift:29` | `Failure` | `= Never` | Visitor over schema nodes |
| `Memory.Allocator.\`Protocol\`` | swift-memory-primitives | `Sources/Memory Allocation Primitives/Memory.Allocator.Protocol.swift:23` | `Error` | none | Allocate/deallocate w/ alignment |
| `Lexer.Pull.Tokens` | swift-lexer-primitives | `Sources/Lexer Primitives/Lexer.Pull.Tokens.swift:41` | `Error` | none | Format-specific token witness |
| `Formatter.\`Protocol\`` | swift-formatter-primitives | `Sources/Formatter Primitives/Formatter.Protocol.swift:53` | `Failure` | none | Value-to-output formatter |
| `Binary.ASCII.Serializable` | swift-ascii-serializer-primitives | `Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift:16` | `Error` | none | DEPRECATED (W4) |

### B. Candidate sibling-form value-domain protocols

#### B.1 — `Ordinal.\`Protocol\``

| Field | Value |
|---|---|
| Package | swift-ordinal-primitives |
| File | `Sources/Ordinal Primitives Core/Ordinal.Protocol.swift:57` |
| Init requirements | `init(_ ordinal: Ordinal)` — NO throws |
| Fallible method requirements | none |
| Existing universal conformer | `Ordinal` (self-conformance) |
| Existing refined conformer | none direct; `Tagged<Tag, R: Ordinal.\`Protocol\`>` is universal-shape |
| Hypothetical refined conformers | `Cyclic.Group.Static<n>.Element` (currently a separate type wrapping Ordinal but bounded to 0..<n); any bounded-Ordinal newtype |
| Current failure handling | none — total construction by design today |

The protocol is the operator-ergonomics sibling to `Carrier.\`Protocol\`<Ordinal>`
(per file header). The file header makes the parallel to `Byte.\`Protocol\``
explicit and lists future refined conformers as a possibility.

#### B.2 — `Color.\`Protocol\``

| Field | Value |
|---|---|
| Package | swift-color-standard |
| File | `Sources/Color Standard/Color.Protocol.swift:51` |
| Init requirements | `init(_ color: Color)` — NO throws |
| Fallible method requirements | `func canonical() -> Color` — total, but reverse `init(_:Color)` is conceptually partial for restricted-gamut conformers |
| Existing universal conformer | `Color` itself (self-conformance) |
| Existing refined conformer | `IEC_61966.\`2\`.\`1\`.sRGB` and other per-IEC/ISO color-space types (in spec packages, out-of-scope for the layer but conform downstream) |
| Hypothetical refined conformers | Any narrow-gamut representation (sRGB, P3, Rec.2020, CMYK, lab-restricted), per the doc comment which explicitly enumerates lossy-conversion shapes |
| Current failure handling | silent clipping — the doc comment explicitly notes "Colors outside the target's gamut during reverse conversion may be clipped" |

This is a textbook FITS shape: the protocol's own documentation acknowledges
the partial-failure mode and currently handles it via silent clipping. The
canonical Color value space is broader than any single refined color space's
gamut; `Color(canonicalColor)` for `IEC_61966.\`2\`.\`1\`.sRGB` partial-fails
for out-of-sRGB-gamut canonical colors.

#### B.3 — `TernaryLogic.\`Protocol\``

| Field | Value |
|---|---|
| Package | swift-standards |
| File | `Sources/TernaryLogic/TernaryLogic.swift:54` |
| Init requirements | `init(_ bool: Bool?)` — NO throws |
| Fallible method requirements | none |
| Existing universal conformer | the canonical TernaryLogic value type (per package) |
| Existing refined conformer | none observed |
| Hypothetical refined conformers | none plausible — `Bool?` has exactly three valid states (`true`, `false`, `nil`) and all three are valid for any conformer of three-valued logic |
| Current failure handling | none required — domain is total |

### C. Sibling-form format-Codable protocols (already typed with FIXED Error type)

The following protocols already use typed throws with a FIXED concrete error
type (not an associatedtype). Each is symmetric across many conformers,
which share the format's error vocabulary.

#### C.1 — `JSON.Serializable`

| Field | Value |
|---|---|
| Package | swift-json |
| File | `Sources/JSON/JSON.Serializable.swift:97` |
| Init requirements | none direct; `init(json:)` / `init(jsonString:)` / `init(jsonBytes:)` via convenience extensions all `throws(JSON.Error)` |
| Fallible method requirements | `static func deserialize(_ json: JSON) throws(JSON.Error) -> Self`; `static func deserialize(events:) throws(JSON.Error) -> Self` |
| Existing universal conformer | `JSON` (identity) |
| Existing refined conformer(s) | `String`, `Bool`, `Int`, `Int64`, `Double`, `Array<E: JSON.Serializable>`, `Dictionary<String, V: JSON.Serializable>`, `Optional<W: JSON.Serializable>` and every user-defined conformer |
| Hypothetical refined conformers | every Swift type that has a JSON representation |
| Current failure handling | fixed typed throws `throws(JSON.Error)` — error vocabulary is JSON-domain (`.typeMismatch`, `.missingKey`, `.invalidSyntax`, `.unknown`) |

#### C.2 — `Plist.Serializable`

| Field | Value |
|---|---|
| Package | swift-plist |
| File | `Sources/Plist Core/Plist.Serializable.swift:3` |
| Init requirements | `init(plist:) throws(Plist.Error)` via convenience extension |
| Fallible method requirements | `static func deserialize(_ plist: Plist) throws(Plist.Error) -> Self` |
| Existing universal conformer | `Plist` (identity) |
| Existing refined conformer(s) | `String`, `Int`, `Int64`, `Double`, `Bool`, `Array`, `Dictionary`, `Optional` |
| Current failure handling | fixed typed throws `throws(Plist.Error)` |

#### C.3 — `XML.Serializable`

| Field | Value |
|---|---|
| Package | swift-xml |
| File | `Sources/XML/XML.Serializable.swift:36` |
| Init requirements | `init(xml:) throws(XML.Error)`, `init(xmlString:) throws(XML.Error)`, `init(xmlBytes:) throws(XML.Error)` via convenience extensions |
| Fallible method requirements | `static func deserialize(_ xml: XML) throws(XML.Error) -> Self` |
| Existing refined conformer(s) | `String`, `Int`, `Double`, `Bool`, `Optional`, `Array` |
| Current failure handling | fixed typed throws `throws(XML.Error)` |

#### C.4 — `Binary.Parseable`

| Field | Value |
|---|---|
| Package | swift-binary-parser-primitives |
| File | `Sources/Binary Parseable Primitives/Binary.Parseable.swift:61` |
| Init requirements | none on the protocol; the deserialize is the static `parse(from:)` |
| Fallible method requirements | `static func parse<Source>(from: inout Source) throws(Binary.Parse.Failure) -> Self where Source.Element == Byte` |
| Existing universal conformer | none — every conformer can partial-fail (insufficient bytes, malformed content) |
| Existing refined conformer(s) | every `Binary.Parseable` conformer (e.g., `UInt32` integer types, per-RFC types) |
| Current failure handling | fixed typed throws `throws(Binary.Parse.Failure)` |

The file header explicitly states "Siblings are flat top-level protocols per
family-Codable convention [FAM-001/006]: no associated types, no refinement
of canonical-attachment protocols." Per-conformer Error AT is intentionally
absent here.

### D. Canonical-attachment protocols (delegate Error to a Coder/Formatter)

#### D.1 — `Coder_Primitives.Codable`

| Field | Value |
|---|---|
| Package | swift-coder-primitives |
| File | `Sources/Coder Primitives/Codable.swift:29` |
| Init requirements | `init(decoding input:) throws(Coder.Failure)` via convenience extension |
| Fallible method requirements | encoder methods delegate to `Self.coder.{serialize,parse}` which throws Coder.Failure |
| Has Error AT directly | no — but has `associatedtype Coder: Coder.\`Protocol\``, and Coder's Failure is propagated to call sites via the convenience extensions |

Pattern: canonical attachment to a Coder. The Error type lives one
indirection away (on `Self.Coder.Failure`), not on Self.

#### D.2 — `Formattable`

| Field | Value |
|---|---|
| Package | swift-formatter-primitives |
| File | `Sources/Formatter Primitives/Formattable.swift:25` |
| Init requirements | none |
| Fallible method requirements | `func formatted() throws(Formatter.Failure) -> Formatter.Output` (via extension) |
| Has Error AT directly | no — but has `associatedtype Formatter: Formatter.\`Protocol\``; Failure delegated |

### E. Argument-domain protocols

#### E.1 — `Argument.Parseable`

| Field | Value |
|---|---|
| Package | swift-arguments |
| File | `Sources/Argument Standard Library Integration/Argument.Parseable.swift:43` |
| Init requirements | `init?(argument: String)` — Optional return, not throws |
| Fallible method requirements | none beyond the Optional init |
| Existing refined conformer(s) | every type with a stringly-parseable form (stdlib Int, Bool, String, Path, etc.) |
| Current failure handling | `nil` return; downstream `Command.Schema.Visitor` converts nil → `Command.Error.invalidValue` |

#### E.2 — `Argument.Codable`

| Field | Value |
|---|---|
| Package | swift-arguments |
| File | `Sources/Argument Standard Library Integration/Argument.Codable.swift:54` |
| Composition | refines `Argument.Parseable` + `Argument.Serializable` |
| Current failure handling | inherits from parents (Optional from Parseable; no failure from Serializable) |

### F. Carrier-shape protocols (universal parameter space IS the conformer's value space)

#### F.1 — `Carrier.\`Protocol\`` (hoisted `_CarrierProtocol`)

| Field | Value |
|---|---|
| Package | swift-carrier-primitives |
| File | `Sources/Carrier Primitives/_CarrierProtocol.swift:26` |
| Init requirements | `init(_ underlying: consuming Underlying)` — NO throws |
| Fallible method requirements | none |
| Universal parameter space | `Underlying` — the type's own associatedtype |
| Refined conformers possible? | no — every conformer's `Underlying` defines its value space; there is no broader space to partial-fail from |

This is the rubric's "DOES NOT FIT — no refined conformers" archetype.

### G. Structural-failure-domain protocols

| Protocol | Package | File:line | Failure type | Why structural |
|---|---|---|---|---|
| `Random.Generator` | swift-random-primitives | `Sources/Random Primitives/Random.Generator.swift:25` | `Random.Error` | OS RNG / hardware failure |
| `Input.Stream.\`Protocol\`` | swift-input-primitives | `Sources/Input Stream Primitives/Input.Stream.Protocol.swift:63` | `Input.Stream.Error.empty` | empty-cursor; not value-domain |
| `Memory.Allocator.\`Protocol\`` | swift-memory-primitives | (see A.2 above) | per-conformer Error AT | OS allocator failure |
| `Memory.ContiguousProtocol` | swift-memory-primitives | `Sources/Memory Contiguous Primitives/Memory.ContiguousProtocol.swift:90` | typed | contiguous-storage access |
| `__SetProtocol` | swift-set-primitives | `Sources/Set Primitives Core/Set.Protocol.swift:17` | typed | set insertion (capacity-bound) |

### H. Out-of-triage-scope protocols (no init, no fallible-method requirement)

The following categories carry public protocols that are NOT in scope for
the triage. For brevity, only the category and example protocols are
listed here.

- **Capability-marker siblings** without init/fallible-method requirements:
  `Hash.\`Protocol\``, `Equation.\`Protocol\``, `Comparison.\`Protocol\``,
  `Cardinal+Carrier`, `Carrier.\`Protocol\`` family — these define hash /
  equality / comparison surfaces, not partial-construction.
- **Marker / capability protocols**: `Sendable`-adjacent markers, layout
  markers, `Argument.Serializable`, `ASCII.Parseable` (empty marker),
  `PostgreSQLType`, `EffectWithHandler`.
- **View / rendering protocols**: `HTML.View`, `PDF.View`, `SVG.View`,
  `HTML.Document.\`Protocol\``, `ChartDataset`, `ChartPlugin`, `ChartLoader`,
  `Scale`, `FontAwesomeLoader`, `Attribute`, `BorderSideProperty`,
  `PDF.HTML.Style.Modifier`, `PDF.HTML.Style.Context.Modifier`.
- **Dimension / coordinate-space protocols**: `Spatial`, `Orientation`,
  `Quantized`, `Enumerable`, `FormatStyle<FormatInput, FormatOutput>`.
- **Witness / key / DI protocols**: `Witness.Key`, `Witness.Key.Test`,
  `Dependency.Key.Strict`.
- **Schema / visitor scaffolding** (already typed via parent's Failure):
  `Command.Schema.Node`, `Command.Subcommand.Binding`,
  `Argument.Schema.Node`, `Argument.Schema.Visitor`,
  `Lexer.Pull.Assemble.Strategy`, `Parser.Printer`,
  `Test.__TestContentRecordContainer`, `Plot.\`Protocol\``.

## Pass 2 — Triage

### Verdicts per in-scope protocol

#### B.1 — `Ordinal.\`Protocol\``

| Field | Value |
|---|---|
| Verdict | **FITS cleanly** |
| Rationale | Strongest direct parallel to `Byte.\`Protocol\``. The protocol has `init(_ ordinal: Ordinal)`; today it is total (no throws), but refined conformers exist conceptually (any bounded-ordinal newtype like `Cyclic.Group.Static<n>.Element` whose valid range is `0..<n`). The file header makes the parallel to `Byte.\`Protocol\`` explicit by listing the sibling-shape relationship to `Carrier.\`Protocol\``. Universal conformer `Ordinal` would take `Error == Never` (non-throwing call sites preserved); a future `Cyclic.Group.Static.Element: Ordinal.\`Protocol\`` would declare its own Error and validate the value against the static bound. |
| Conformer impact | Current direct conformers: 2 (Ordinal, Tagged<Tag, R: Ordinal.\`Protocol\`>). Estimated call sites needing `try`: zero today (universal conformers' Error stays Never). Future refined conformers: 1–N (Cyclic.Group.Static<n>.Element if migrated; bounded-ordinal newtypes the ecosystem may add). |
| Recommended sequencing | Lands cleanly as a standalone arc with low ripple. Can be done before or after the Carrier reshape (the two are siblings, not refinements). Recommended cohort entry point because the rubric calibration was developed on this exact shape (Byte). |
| Notes | The `Tagged<Tag, R: Ordinal.\`Protocol\`>` recursive conformance must declare `typealias Error = R.Error` (same pattern as `Tagged+Byte.Protocol.swift`); not a structural blocker. |

#### B.2 — `Color.\`Protocol\``

| Field | Value |
|---|---|
| Verdict | **FITS cleanly** |
| Rationale | The protocol's own doc comment explicitly enumerates the partial-failure modes that the pattern is designed to surface: "Gamut limitations", "Precision loss", "Model differences". Today these are handled by silent clipping ("Colors outside the target's gamut during reverse conversion may be clipped") — exactly the anti-pattern the byte-discipline arc rejects. The canonical `Color` value space is broader than any refined color space's gamut; `Color(canonicalColor)` for sRGB / P3 / Rec.2020 / CMYK partial-fails for out-of-gamut canonical colors. Universal conformer `Color` (self-conformance, total) takes `Error == Never`; refined per-IEC color spaces declare a concrete Error and throw on out-of-gamut. |
| Conformer impact | Estimated existing refined conformers: depends on swift-color-standard ecosystem; the protocol is referenced from `IEC_61966.\`2\`.\`1\`.sRGB` and likely other IEC/ISO color types (out-of-layer-scope but downstream conformers). Estimated call sites needing `try`: at the `Color(canonicalColor)` call sites only for refined color types; the `canonical()` direction is total and unaffected. |
| Recommended sequencing | After Ordinal.\`Protocol\` (smaller, rubric-calibrating arc lands first). Color is the largest non-Byte FITS in the inventory and a good second target. |
| Notes | The `canonical()` direction is total (every refined color produces a canonical), so only the `init(_:Color)` direction grows the throws clause. This is a one-direction migration; the protocol's symmetry is preserved (lossy direction = throws; lossless direction = no throws). |

#### B.3 — `TernaryLogic.\`Protocol\``

| Field | Value |
|---|---|
| Verdict | **DOES NOT FIT — no refined conformers** |
| Rationale | `Bool?` has exactly three valid states and all three are valid for any conformer of three-valued logic. No partial-construction is possible; the default `Error == Never` would always apply, making the redesign zero-value. |
| Conformer impact | n/a |
| Recommended sequencing | n/a |
| Notes | The protocol's surface is structurally complete in its present form. |

#### A.2 — Sibling-shape protocols already using an Error/Failure AT

All entries in A.2 receive a single verdict.

| Field | Value |
|---|---|
| Verdict | **ALREADY typed** |
| Rationale | Each already declares an `associatedtype Failure: Swift.Error` (Parser/Serializer/Coder/Command/Command.Schema.Visitor/Formatter) or `associatedtype Error: Swift.Error` (Memory.Allocator/Lexer.Pull.Tokens/Binary.ASCII.Serializable) and the throwing requirements use the AT. The pattern is structurally already in place. |
| Notes / sub-recommendations | (a) Three of these — `Memory.Allocator.\`Protocol\``, `Lexer.Pull.Tokens`, `Formatter.\`Protocol\`` — have NO `= Never` default on the Error AT. Adding the default is a minor refinement that would let infallible conformers omit the typealias and take advantage of the `throws(Never)` ≡ non-throwing identity at call sites. This is a cosmetic-only change and need not be a separate execution arc; it can ride on any future touch of these files. (b) `Command.\`Protocol\``'s `= Command.Error` default differs from the canonical `= Never` default; this is intentional per its design — every command can plausibly fail. (c) `Binary.ASCII.Serializable` is marked deprecated (W4); no action. |

#### C.1–C.4 — Format-Codable protocols (JSON / Plist / XML / Binary.Parseable)

All four receive a single grouped verdict.

| Field | Value |
|---|---|
| Verdict | **DOES NOT FIT — no refined conformers** (with a sub-classification) |
| Rationale | Each protocol's error vocabulary is at the FORMAT level (`JSON.Error`, `Plist.Error`, `XML.Error`, `Binary.Parse.Failure`), not the conformer level. Every conformer of `JSON.Serializable` (`String`, `Int`, user types, ...) shares the same error vocabulary: `.typeMismatch`, `.missingKey`, `.invalidSyntax`. There is no per-conformer reason for one to throw a different error vocabulary than another — the error model is the format's, not the value's. Refined-vs-universal distinction does not apply: every conformer's relationship to the format is the same partial-failure shape (parse / decode failure). |
| Sub-classification | The institute's family-Codable convention [FAM-001/006] explicitly states "no associated types, no refinement of canonical-attachment protocols" — this is the codified position. The protocols are structurally complete in their present form for their layer. |
| Conformer impact | n/a |
| Notes | A conformer that wants its OWN error type ON TOP of the format's error vocabulary should compose: declare `Plist.Error.invalidValue(reason:)` or wrap in `try Self.deserialize(plist)`'s catch site. The protocol-level error is the format's contract; per-conformer additions live at call-site validation, not protocol surface. |

#### D.1–D.2 — Canonical-attachment protocols (Codable / Formattable)

| Field | Value |
|---|---|
| Verdict | **ALREADY typed** (via delegation) |
| Rationale | The error type lives one indirection away (on `Self.Coder.Failure` / `Self.Formatter.Failure`). The convenience extensions propagate the typed throws correctly. Hoisting an `associatedtype Error` onto Codable itself would duplicate `Self.Coder.Failure` for zero structural benefit. |
| Notes | This is the canonical-attachment pattern: per-type attachment to a Coder/Formatter instance. The error type rides on the attached instance, not on the attachment protocol. The byte-discipline pattern does not apply structurally. |

#### E.1 — `Argument.Parseable`

| Field | Value |
|---|---|
| Verdict | **DOES NOT FIT — design decision (Optional-return matches stdlib precedent)** |
| Rationale | The protocol uses `init?(argument: String)` — Optional return — by design, mirroring `Swift.Int.init?(_:)`, `Swift.Double.init?(_:)`. The doc comment explicitly documents this choice: "Returning `nil` from `init(argument:)` is the standard failure signal — schema-driven parsing converts a `nil` outcome into a typed `Command.Error.invalidValue` carrying the offending argv string." Converting to `init(argument:) throws(Self.Error)` would break the stdlib-mirror property and force every conformer to either declare a per-conformer Error or use a shared one (defeating the per-conformer-error rationale of the pattern). |
| Conformer impact | n/a |
| Notes | The pattern's value over Optional return WOULD be richer error reporting at the conformer level, but the downstream schema-driven parsing already produces typed errors (Command.Error.invalidValue) — the typed-error surface lives at the schema layer, not the protocol layer. Composition is intentional. |

#### E.2 — `Argument.Codable`

| Field | Value |
|---|---|
| Verdict | **DOES NOT FIT — refinement of Parseable + Serializable** |
| Rationale | Inherits its failure model from `Argument.Parseable` (Optional) and `Argument.Serializable` (total). Adding an Error AT to Codable while Parseable stays Optional would introduce structural inconsistency in the family. |
| Notes | Tied to E.1's verdict — if Parseable's design ever shifts (unlikely), Codable would follow. |

#### F.1 — `Carrier.\`Protocol\``

| Field | Value |
|---|---|
| Verdict | **DOES NOT FIT — no refined conformers** |
| Rationale | The protocol's `Underlying` IS an associatedtype: every conformer's value space is exactly `Underlying`. There is no broader "raw" space from which the conformer's value space is a refined subset; the rubric's partial-failure shape (universal injection from Byte → refined ASCII.Code) does not apply. `Tagged<Tag, U>.init(_:U)` is the canonical wrapping shape — total by construction. Refined conformers like `ASCII.Code` carry their refinement on the SIBLING `Byte.\`Protocol\`` (where the universal-vs-refined distinction lives), not on Carrier. |
| Conformer impact | n/a |
| Notes | The handoff identified Carrier as the "strongest a-priori candidate." On structural inspection that turns out wrong: Carrier's role is the universal-wrapper interface, and per the Q1 sibling-form recommendation in `byte-protocol-capability-marker.md` v1.1.0, the per-domain refinement layer is the SIBLING protocol (`Byte.\`Protocol\``, `Ordinal.\`Protocol\``, future `Char.\`Protocol\``, etc.), not Carrier itself. Carrier's universality is the WHOLE point — it must NOT carry per-conformer error machinery, because doing so would dissolve the sibling-form discipline that motivates the per-domain protocols. The "FITS" verdict goes to the SIBLING protocols (B.1 Ordinal, B.2 Color), not to Carrier. |

#### G — Structural-failure-domain protocols

| Protocol | Verdict | Rationale |
|---|---|---|
| `Random.Generator` | DOES NOT FIT — failure is structural | Failure is OS/hardware (RNG unavailable), not value-domain; typed `Random.Error` already captures it |
| `Input.Stream.\`Protocol\`` | DOES NOT FIT — failure is structural | Empty-cursor failure is structural (insufficient input), not value-validation; typed `Input.Stream.Error.empty` is fixed |
| `Memory.Allocator.\`Protocol\`` | ALREADY typed (and structural) | Has per-conformer Error AT; failure is OS-domain (allocator-specific) — per-conformer Error AT is appropriate because different allocators have different failure modes (system-OOM vs arena-exhausted vs pool-empty) |
| `Memory.ContiguousProtocol` | DOES NOT FIT — failure is structural | Contiguous-storage-access failure is structural |
| `__SetProtocol` | DEFER — needs deeper investigation | Insertion may have per-conformer failure modes (bounded vs unbounded). The current shape was researched in `set-insert-error-divergence.md`. |

## Cross-cutting observations

### 1. The sibling-form pattern is the FITS shape, not the refinement form

Every FITS verdict in this inventory (`Byte.\`Protocol\`` (reference),
`Ordinal.\`Protocol\``, `Color.\`Protocol\``) is a SIBLING protocol — not a
refinement of `Carrier.\`Protocol\``. This validates the structural finding
of `byte-protocol-capability-marker.md` v1.1.0: the per-domain refinement
layer where partial-failure machinery lives MUST be the sibling, not
Carrier itself.

### 2. The "already-typed" set divides on `= Never` default presence

Among the ALREADY-typed protocols (A.2), three sub-shapes emerge:

| Default | Protocols | Implication |
|---|---|---|
| `associatedtype Failure: Swift.Error = Never` | Parser, Serializer, Command.Schema.Visitor | Universal conformers omit typealias; call sites infallible at non-throwing default — same property as Byte.Protocol's Error AT |
| `associatedtype Failure: Swift.Error = Command.Error` | Command.\`Protocol\` | Domain-tuned default (every command can plausibly fail) |
| `associatedtype Error: Swift.Error` (no default) | Memory.Allocator, Lexer.Pull.Tokens, Formatter, Binary.ASCII.Serializable | Every conformer must declare Error explicitly |

Adding `= Never` defaults to the third group is a cosmetic-only change with
positive ergonomic effect for hypothetical never-fail conformers. None of
these protocols block correct typed-throws today — the change would let
infallible conformers omit a `typealias Error = Never` line.

### 3. The format-Codable family is intentionally not per-conformer-typed

JSON.Serializable, Plist.Serializable, XML.Serializable, and
Binary.Parseable all use a FIXED concrete error type, not an
associatedtype. This is codified by family-Codable convention [FAM-001/006]
on `Binary.Parseable` and reflected in the others. The byte-discipline
pattern does not apply to format-Codable family because the error vocabulary
is the FORMAT's, not the conformer's. Cross-conformer error consistency is
a feature, not a limitation.

### 4. The Carrier-Sibling split is structural, not stylistic

The handoff's "Carrier.\`Protocol\` is the closest analog to Byte.\`Protocol\`"
expectation does not survive structural inspection. Carrier owns the
universal-wrapper interface (Underlying associatedtype IS the value space);
the per-domain sibling protocols (`Byte.\`Protocol\``, `Ordinal.\`Protocol\``,
future `Char.\`Protocol\``, etc.) are where the FITS pattern applies. The
typed-throws-Error machinery belongs at the sibling layer because that is
where the universal-vs-refined value-domain distinction lives.

### 5. Canonical-attachment protocols delegate, they don't carry

Coder.Codable and Formattable have `associatedtype Coder` and
`associatedtype Formatter` respectively. The Error/Failure comes from the
attached instance via convenience extensions. Hoisting an Error AT onto
the attachment protocol would duplicate the inner Failure for no structural
gain.

## Recommended execution plan

The triage produces TWO FITS verdicts. Both are independent of each other
and of the byte-discipline arc that originated the pattern. Suggested
ordering:

### Arc 1 (small, rubric-calibrating): `Ordinal.\`Protocol\``

| Property | Value |
|---|---|
| Scope | Add `associatedtype Error: Swift.Error = Never` to `Ordinal.\`Protocol\`` per `Byte.\`Protocol\``'s shape; add `init(_ ordinal: Ordinal) throws(Self.Error)`; gate any default impls that depend on totality with `where Error == Never`; add `typealias Error = R.Error` to the recursive Tagged conformance |
| Risk | Low — direct parallel to a landed arc; the shape is mechanically reproducible from `Byte.Protocol.swift` |
| Downstream consumer ripple | Universal-conformer call sites: zero (Error defaults to Never; `throws(Never)` is non-throwing). Refined conformer migration is optional and per-package (e.g., Cyclic.Group.Static.Element migration would be a separate sub-arc). |
| Dependencies | None — independent of any other proposed arc |
| Estimated wave count | 1–2 waves (protocol shape + Tagged extension; optional Cyclic.Group.Static.Element wave deferred) |

### Arc 2 (larger, downstream-conformer-heavy): `Color.\`Protocol\``

| Property | Value |
|---|---|
| Scope | Add `associatedtype Error: Swift.Error = Never` to `Color.\`Protocol\``; convert `init(_ color: Color)` to `init(_ color: Color) throws(Self.Error)`; for refined-gamut conformers (sRGB, P3, CMYK, etc.) declare concrete Error and replace silent clipping with explicit throws |
| Risk | Higher — touches every per-color-standard conformer in spec packages (IEC/ISO color spaces) |
| Downstream consumer ripple | Every call site `OtherColor(canonicalColor)` for refined conformers needs `try`; `Color(otherColor)` direction unchanged (Color is universal-conformer). The `converted(to:)` convenience extension needs `throws(Target.Error)` (or `where Target.Error == Never` for total cases). |
| Dependencies | None on Arc 1 — independent. Could land before, after, or in parallel. |
| Estimated wave count | 3–5 waves: (a) protocol shape; (b) convert silent-clip sites in refined conformers to throws; (c) update `converted(to:)` extension; (d) consumer-site `try` additions across downstream color packages; (e) optional documentation / example sweep |

### Deferred / not-recommended arcs

- **All A.2 ALREADY-typed protocols** — no execution recommended; optional `= Never` defaults can ride on future touches
- **All C.* format-Codable protocols** — design decision per family-Codable convention; do not migrate
- **All D.* canonical-attachment protocols** — structurally delegate to attached instance; do not migrate
- **F.1 Carrier.\`Protocol\`** — structural mismatch; do not migrate
- **G.* structural-failure-domain protocols** — failure is not value-domain; pattern does not apply

## Open questions for principal

### Q1 — Confirm Ordinal.\`Protocol\` FITS-verdict on the refined-conformer landscape

The inventory found no current refined-Ordinal conformer in scope; the FITS
verdict rests on the hypothetical `Cyclic.Group.Static<n>.Element` plus any
future bounded-ordinal newtype. Is this hypothetical conformer count enough
to motivate a per-protocol arc, or should Ordinal wait for the first refined
conformer to actually arrive before the protocol is reshaped?

If "wait for the first refined conformer": the arc is DEFERRED rather than
FITS-now. If "redesign now in anticipation of the cohort": the arc is
authorized as recommended.

### Q2 — Confirm Color.\`Protocol\` arc scope and dependency on swift-standards

`Color.\`Protocol\`` lives in `swift-color-standard` (L2). Conformers live in
sibling spec packages (IEC color spaces, ISO color spaces, etc.) — some of
those are out-of-scope for the dispatching handoff. The cascade affects
those packages.

Is the principal authorizing a multi-package cascade across the
color-standard ecosystem, or should the protocol-side change land first
and conformer migration be queued as a separate cohort arc?

### Q3 — Confirm `= Never` default addition for Memory.Allocator / Lexer.Pull.Tokens / Formatter

These three protocols already have an Error AT but no `= Never` default.
Adding the default is a cosmetic-only change that improves ergonomics for
infallible conformers. Should this be a separate micro-arc, or should it
ride on any future touch of these files?

The recommended default position is "ride on future touches" (per
[ARCH-LAYER-008] pre-1.0 reshaping discipline), but the principal may
prefer explicit per-protocol arcs for visibility.

### Q4 — Confirm format-Codable family verdict

This inventory concludes that JSON.Serializable / Plist.Serializable /
XML.Serializable / Binary.Parseable should NOT migrate to per-conformer
Error ATs because the error vocabulary is at the format level and
cross-conformer consistency is intentional per family-Codable convention.

This rests on the structural argument that no refined conformer needs a
different error vocabulary than `JSON.Error` / `Plist.Error` / etc. If the
principal sees a future format-Codable conformer whose semantic error
domain transcends the format's error vocabulary, this verdict needs
revisiting.

### Q5 — The "DEFER — deeper investigation" cases

`__SetProtocol` was flagged DEFER pending the disposition of
`set-insert-error-divergence.md`. Is the principal ready to take that
research's RECOMMENDATION and re-triage, or should it remain DEFERRED?

## References

- Skill: `byte-discipline` ([API-BYTE-001…007]) — sibling-form vs
  refinement-form discrimination, default-impl gating pattern
- Skill: `code-surface` — [API-NAME-001c] capability-marker protocol recipe
- Skill: `research-process` — [RES-019] Step-0 internal grep
- Research: `byte-protocol-capability-marker.md` v1.1.0 — Q1 sibling-form
  identity (RECOMMENDATION 2026-05-15)
- Research: `byte-arithmetic-conformance.md` v1.0.0 — Q3 Byte ≢ arithmetic
  (RECOMMENDATION 2026-05-19)
- Research: `typed-throws-standards-inventory.md` v1.0.0 — adjacent
  (Codable/Clock untyped-throws inventory; orthogonal scope)
- Research: `codable-untyped-throws-disposition.md` — related typed-throws
  position on canonical-attachment
- Research: `set-insert-error-divergence.md` — open Set.insert error model
  research (referenced from Q5)
- Originating commits: `swift-byte-primitives@3f3b44a`,
  `swift-ascii-primitives@68605eb`
- Reference files (already cited above):
  `swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift`,
  `Tagged+Byte.Protocol.swift`,
  `swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Byte.Protocol.swift`
