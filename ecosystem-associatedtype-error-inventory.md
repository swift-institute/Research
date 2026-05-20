# Ecosystem-wide associatedtype Error triage — inventory + triage

<!--
---
version: 1.1.0
last_updated: 2026-05-21
status: RECOMMENDATION
---
-->

<!--
## Changelog

- v1.1.0 (2026-05-21): Deep-dive on the two FITS candidates (Ordinal /
  Color) replaces speculative framing with verified file:line evidence.
  Pre-existing infrastructure surfaced for both arcs: Cyclic.Group.Static
  .Element already has the EXACT migration-shape init signature; Color
  .Error already exists with `.outOfGamut` / `.invalidComponent` cases.
  Migration sketches added for both. Conformer counts now grounded
  (Ordinal: 1 refined conformer landed; Color: 7 conformers — 2 throwing
  candidates, 5 universal-domain). Q1 and Q2 in §"Open questions" updated
  to reflect verified state.
- v1.0.0 (2026-05-20): Initial inventory + triage.
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
| Existing universal conformer | `Ordinal` (self-conformance, line 83) |
| Existing refined conformer (verified) | `Cyclic.Group.Static<n>.Element` — exists today in `swift-cyclic-primitives/Sources/Cyclic Group Static Element Primitives/Cyclic.Group.Static.Element.swift:46` BUT does NOT currently declare `: Ordinal.\`Protocol\`` conformance; the protocol-conformance hookup is missing |
| Existing refined conformer's init signature | `public init(_ position: Ordinal) throws(Self.Error)` (Cyclic.Group.Static.Element.swift:56) — IDENTICAL to the byte-discipline pattern's `init(_ byte: Byte) throws(Self.Error)` shape, modulo type names |
| Existing refined conformer's Error type | `Cyclic.Group.Static.Element.Error` (Cyclic.Group.Static.Element.Error.swift:17) — typed enum with `.invalidModulus` and `.outOfBounds(Int)` cases, ready to slot in as the protocol's associated Error |
| Existing Ordinal→Element direction | `extension Ordinal { public init<let N: Int>(_ element: Cyclic.Group.Static<N>.Element) }` (Cyclic.Group.Static.Element+Ordinal.swift:25) — TOTAL (every Element produces an Ordinal); current asymmetry: Ordinal-from-Element is total, Element-from-Ordinal is partial. Matches `Byte` ↔ `ASCII.Code` asymmetry exactly. |
| Hypothetical further refined conformers | any future bounded-ordinal newtype (e.g., `Index<T>.Bounded<N>`, `Finite.Element<N>`) |
| Current failure handling on Element side | typed throws already in place; the only missing piece is the protocol-side AT |

**Verification stamp (v1.1.0)**: The refined-conformer landscape is NOT
speculative. `Cyclic.Group.Static.Element` exists, has the partial-failure
init, has the typed Error enum, has the `position: Ordinal` accessor that
maps to the protocol's required `ordinal: Ordinal { get }` getter. The
migration's only structural work is wiring three pieces that already exist
into a conformance declaration that does not yet exist.

#### B.2 — `Color.\`Protocol\``

| Field | Value |
|---|---|
| Package | swift-color-standard |
| File | `Sources/Color Standard/Color.Protocol.swift:51` |
| Init requirements | `init(_ color: Color)` — NO throws |
| Fallible method requirements | `func canonical() -> Color` — total; the reverse `init(_:Color)` is partial for restricted-gamut conformers |
| Conformer count (verified, all in-scope) | **7** total conformers, all declared in `swift-color-standard` itself |
| Conformer breakdown | (1) `Color` self-conformance — identity, total — `Color.Protocol.swift:90`; (2) `IEC_61966.\`2\`.\`1\`.sRGB` — restricted gamut, silently clamps — `Color+sRGB.swift:9`; (3) `IEC_61966.\`2\`.\`1\`.LinearSRGB` — restricted gamut, silently clamps — `Color+sRGB.swift:92`; (4) `Color.LAB` — universal gamut (every canonical Color maps in), but internal clamp on Lightness — `Color+LAB.swift:8`; (5) `Color.LCH` — universal gamut — `Color+LCH.swift:6`; (6) `Color.Oklab` — universal gamut — `Color+Oklab.swift:8`; (7) `Color.Oklch` — universal gamut — `Color+Oklch.swift:6` |
| Conformers needing throwing init | **2 of 7**: sRGB + LinearSRGB. Their `init(_ color: Color)` implementations silently clamp out-of-gamut colors (`Color+sRGB.swift:32–34` calls `Color._toSRGB` which "Create linear sRGB (clamping values)" — file:line 83). Doc comment explicitly states: "Colors outside the sRGB gamut will be clipped to the nearest representable color." |
| Conformers staying `Error == Never` | **5 of 7**: Color, LAB, LCH, Oklab, Oklch. Their canonical Color → Self direction is structurally universal (every canonical Color produces a valid wide-gamut representation). |
| Pre-existing error infrastructure | **`Color.Error` already exists** at `Color.Error.swift:8` with `.outOfGamut`, `.unsupportedColorSpace`, `.invalidComponent(component:value:)` cases — the error type is in the codebase, just not yet wired into the protocol. **`Color.LAB.Lightness.Error`** also exists (`Color.LAB.swift:105`) — typed-throws error already in place for the typed Lightness component. |
| Current failure handling | silent clipping at `_toSRGB` / `_fromRGB` boundaries; documented in protocol doc comment as a structural feature of the protocol's signature |

**Verification stamp (v1.1.0)**: The refined-conformer landscape is NOT
speculative. Seven conformers exist today (all in `swift-color-standard`),
two of which carry the exact silent-clipping anti-pattern the
byte-discipline arc rejected. The error type the migration would use
(`Color.Error.outOfGamut`) already exists. The pattern's payoff at the
sRGB / LinearSRGB sites is concrete: silent clipping replaced with
explicit `throws(Color.Error)`, while the five universal-gamut conformers
preserve non-throwing call sites via `Error == Never` default.

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
| Verdict | **FITS cleanly** (verified) |
| Rationale | Strongest direct parallel to `Byte.\`Protocol\``. The refined conformer (`Cyclic.Group.Static.Element`) ALREADY EXISTS with the byte-discipline pattern's exact init shape (`init(_ position: Ordinal) throws(Self.Error)`) and a typed Error enum (`.invalidModulus`, `.outOfBounds(Int)`). The protocol-conformance hookup is the only missing piece — the partial-failure infrastructure is already in place on the conformer side. Universal conformer `Ordinal` takes `Error == Never` (non-throwing call sites preserved); refined conformer `Cyclic.Group.Static.Element` declares its existing Error and gets connected to the protocol it should always have conformed to. |
| Conformer impact | Current direct conformers post-migration: 3 (Ordinal — Never, Tagged<Tag, R: Ordinal.\`Protocol\`> — propagates R.Error, Cyclic.Group.Static.Element — concrete Error). Estimated call sites needing `try`: zero new (the Element's `init(_:Ordinal)` already throws; existing call sites already write `try` or use `init(__unchecked:)` / `init(wrapping:)` alternates). Future refined conformers: any future bounded-ordinal newtype (Index<T>.Bounded<N>, Finite.Element<N>) plugs in trivially. |
| Recommended sequencing | Standalone arc with low ripple. Independent of Color arc. Recommended FIRST because (a) rubric calibration matches Byte exactly; (b) refined conformer already shipped — this is connecting existing wiring, not new design; (c) Cyclic.Group.Static.Element gains "first-class ordinal" status that consumer-side generic algorithms over `some Ordinal.\`Protocol\`` can use. |
| Notes | The `Tagged<Tag, R: Ordinal.\`Protocol\`>` recursive conformance must declare `typealias Error = R.Error` (same pattern as `Tagged+Byte.Protocol.swift`); mechanical. The Element's `var position: Ordinal` and the protocol's `var ordinal: Ordinal { get }` requirement have different names — the conformance declaration provides a `var ordinal: Ordinal { position }` adapter, OR rename `position` to `ordinal` for symmetry. Decision deferred to execution-time. |

#### B.2 — `Color.\`Protocol\``

| Field | Value |
|---|---|
| Verdict | **FITS cleanly** (verified, more concrete than Ordinal) |
| Rationale | Seven verified conformers in-scope (all in swift-color-standard). Two carry the silent-clipping anti-pattern (sRGB + LinearSRGB) — their `init(_ color: Color)` is documented to "Clip to the nearest representable color." The migration replaces silent clipping with explicit `throws(Color.Error)`. The Color.Error enum already exists with the right cases (`.outOfGamut`, `.invalidComponent(component:value:)`). The five wide-gamut conformers (Color, LAB, LCH, Oklab, Oklch) take `Error == Never` and remain non-throwing at call sites — call-site impact bounded to sRGB/LinearSRGB consumers. |
| Conformer impact | Throwing migrations: 2 (sRGB, LinearSRGB). Non-throwing (Error = Never) migrations: 5 (Color, LAB, LCH, Oklab, Oklch). Existing `converted<Target: Color.\`Protocol\`>(to:)` extension at `Color.Protocol.swift:83` becomes `throws(Target.Error)` and is non-throwing when Target.Error == Never (5 of 7 cases). Consumer-site ripple: every `IEC_61966.\`2\`.\`1\`.sRGB(canonicalColor)` and `LinearSRGB(canonicalColor)` call site needs `try`; estimated single-digit count in foundations layer (one verified hit in `swift-pdf-html-render/.../PDF.Color.swift:13`). |
| Recommended sequencing | Second (after Ordinal), or in parallel. The two arcs share zero overlap. Color has more conformer files to touch (8 source files) but no cross-package cascade because all conformers live in swift-color-standard. The `Color.Error` enum is the only existing error type that needs no work — already shaped right. |
| Notes | The `canonical()` direction stays total (Self → canonical Color always succeeds — refined values are subsets of canonical). Only the inverse direction grows the throws clause, and only for restricted-gamut conformers. The protocol's symmetry is preserved: lossless direction = no throws; lossy direction = typed throws with default Never. |

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

### Arc 1 (small, mechanical): `Ordinal.\`Protocol\``

| Property | Value |
|---|---|
| Scope | (a) Add `associatedtype Error: Swift.Error = Never` to `Ordinal.\`Protocol\``; (b) change `init(_ ordinal: Ordinal)` to `init(_ ordinal: Ordinal) throws(Self.Error)`; (c) gate any default impls that depend on totality with `where Error == Never`; (d) add `typealias Error = R.Error` to the recursive Tagged conformance in `Tagged: Ordinal.\`Protocol\`` extension; (e) wire `Cyclic.Group.Static.Element: Ordinal.\`Protocol\`` conformance with `typealias Error = Cyclic.Group.Static.Element.Error` and `var ordinal: Ordinal { position }` (or rename `position` to `ordinal`) |
| Risk | Low — refined conformer already throws in its init; existing infrastructure connects rather than rebuilds |
| Downstream consumer ripple | Universal-conformer call sites: zero new `try`s (Ordinal stays Never; Tagged propagates Never when wrapping Ordinal). Cyclic.Group.Static.Element call sites: already use `try` (the init already throws); the conformance hookup is API-positive (Element gains generic-algorithm participation) |
| Dependencies | None — independent of Color arc |
| Estimated wave count | 2 waves: (W1) protocol shape + Tagged extension in swift-ordinal-primitives; (W2) Element conformance in swift-cyclic-primitives |
| Files touched (estimated) | 3-4 files: `Ordinal.Protocol.swift`, `Tagged+Ordinal.Protocol.swift`-adjacent, `Cyclic.Group.Static.Element.swift` (or a new sibling `Cyclic.Group.Static.Element+Ordinal.Protocol.swift`) |

#### Migration sketch — Ordinal.\`Protocol\`

```swift
// swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift

extension Ordinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        associatedtype Count: Carrier.`Protocol`<Cardinal>
        associatedtype Error: Swift.Error = Never  // NEW

        var ordinal: Ordinal { get }
        init(_ ordinal: Ordinal) throws(Self.Error)  // CHANGED: throws clause
    }
}

extension Ordinal: Ordinal.`Protocol` {
    public typealias Domain = Never
    public typealias Count = Cardinal
    // Error defaults to Never — no typealias needed; throws(Never) ≡ non-throwing
    @inlinable public var ordinal: Ordinal { self }
    @inlinable public init(_ ordinal: Ordinal) { self = ordinal }
}

extension Tagged: Ordinal.`Protocol`
where Underlying: Ordinal.`Protocol`, Tag: ~Copyable {
    public typealias Domain = Tag
    public typealias Count = Tagged<Tag, Cardinal>
    public typealias Error = Underlying.Error  // NEW: propagate
    @inlinable public var ordinal: Ordinal { underlying.ordinal }
    @_disfavoredOverload
    @inlinable
    public init(_ ordinal: Ordinal) throws(Underlying.Error) {  // CHANGED
        self.init(_unchecked: try Underlying(ordinal))
    }
}
```

```swift
// swift-cyclic-primitives — new file or extension on Element

extension Cyclic.Group.Static.Element: Ordinal.`Protocol` {
    public typealias Domain = Never
    public typealias Count = Cardinal
    // Error is already defined on the type via Cyclic.Group.Static.Element.Error.swift
    // The associated-type witness resolves to the nested enum.

    @inlinable public var ordinal: Ordinal { position }
    // init(_ ordinal: Ordinal) throws(Self.Error) already exists at file:line
    // Cyclic.Group.Static.Element.swift:56 — no change needed.
}
```

### Arc 2 (medium, conformer-heavy but self-contained): `Color.\`Protocol\``

| Property | Value |
|---|---|
| Scope | (a) Add `associatedtype Error: Swift.Error = Never` to `Color.\`Protocol\``; (b) change `init(_ color: Color)` to `init(_ color: Color) throws(Self.Error)`; (c) for sRGB + LinearSRGB declare `typealias Error = Color.Error` (already exists) and replace silent-clamp `Color._toSRGB` with throwing variant that raises `.outOfGamut`; (d) the 5 wide-gamut conformers (Color, LAB, LCH, Oklab, Oklch) take Error = Never — no behavioral change; (e) update `converted<Target: Color.\`Protocol\`>(to:)` to `throws(Target.Error)`; (f) consumer-site `try` additions where sRGB/LinearSRGB are constructed from canonical Color |
| Risk | Medium — multi-conformer arc but ALL conformers live in swift-color-standard (no cross-package cascade); Color.Error already exists |
| Downstream consumer ripple | foundations-layer: spot-verified one site in `swift-pdf-html-render/.../PDF.Color.swift:13` already uses optional-return failure shape (`guard let srgb = sRGB(color) else`); most consumers expecting non-throwing today need to add `try` only for sRGB/LinearSRGB |
| Dependencies | None on Arc 1 — independent |
| Estimated wave count | 3-4 waves: (W1) protocol shape + Color/LAB/LCH/Oklab/Oklch wide-gamut conformer typealiases; (W2) sRGB + LinearSRGB throwing inits + Color.Error wiring; (W3) `converted(to:)` extension update; (W4) consumer-site sweep in foundations |
| Files touched (estimated) | 8 files in swift-color-standard: `Color.Protocol.swift`, `Color+sRGB.swift` (2 conformances), `Color+LAB.swift`, `Color+LCH.swift`, `Color+Oklab.swift`, `Color+Oklch.swift`. `Color.Error.swift` unchanged (already shaped). Plus 1-N consumer files in swift-foundations. |

#### Migration sketch — Color.\`Protocol\`

```swift
// swift-color-standard/Sources/Color Standard/Color.Protocol.swift

extension Color {
    public protocol `Protocol`: Sendable {
        associatedtype Error: Swift.Error = Never  // NEW

        func canonical() -> Color
        init(_ color: Color) throws(Self.Error)  // CHANGED: throws clause
    }
}

extension Color.`Protocol` {
    // Generic conversion gains throws(Target.Error) — when Target.Error == Never,
    // call sites infer non-throwing automatically.
    public func converted<Target: Color.`Protocol`>(
        to targetType: Target.Type
    ) throws(Target.Error) -> Target {
        try Target(self.canonical())
    }
}

// Self-conformance — Error defaults to Never
extension Color: Color.`Protocol` {
    public func canonical() -> Color { self }
    public init(_ color: Color) { self = color }
}
```

```swift
// swift-color-standard/Sources/Color Standard/Color+sRGB.swift (updated)

extension IEC_61966.`2`.`1`.sRGB: Color.`Protocol` {
    public typealias Error = Color.Error  // NEW — already exists in Color.Error.swift

    public func canonical() -> Color { Color._fromSRGB(self) }

    public init(_ color: Color) throws(Color.Error) {  // CHANGED
        // Throwing version of _toSRGB: validate that linear RGB ∈ [0, 1]^3
        // rather than silently clamping.
        guard let srgb = Color._toSRGBThrowing(color) else {
            throw .outOfGamut
        }
        self = srgb
    }
}
```

```swift
// Wide-gamut conformers (LAB / LCH / Oklab / Oklch): no behavioral change,
// just signature alignment.

extension Color.LAB: Color.`Protocol` {
    // Error defaults to Never — every canonical Color produces a valid LAB
    public func canonical() -> Color { Color._fromLAB(self) }
    public init(_ color: Color) { self = Color._toLAB(color) }
}
```

### Deferred / not-recommended arcs

- **All A.2 ALREADY-typed protocols** — no execution recommended; optional `= Never` defaults can ride on future touches
- **All C.* format-Codable protocols** — design decision per family-Codable convention; do not migrate
- **All D.* canonical-attachment protocols** — structurally delegate to attached instance; do not migrate
- **F.1 Carrier.\`Protocol\`** — structural mismatch; do not migrate
- **G.* structural-failure-domain protocols** — failure is not value-domain; pattern does not apply

## Open questions for principal

### Q1 — Confirm Ordinal.\`Protocol\` arc execution (v1.1.0: refined-conformer verified)

**v1.0.0 framing**: hypothetical refined conformer ("wait for the first
one"). **v1.1.0 update**: the refined conformer (`Cyclic.Group.Static
.Element`) already exists with the exact partial-failure init shape and
typed Error enum — it just isn't conformed to `Ordinal.\`Protocol\`` yet
(see §B.1). The arc is "connect existing wiring", not "design new
machinery".

Two sub-questions for execution:

- **Q1.a**: Adopt the `var ordinal: Ordinal { position }` accessor adapter,
  OR rename `Cyclic.Group.Static.Element.position` to `ordinal` for symmetry
  with the protocol requirement? The rename is more consistent
  ecosystem-wide (Byte → `byte`, Ordinal → `ordinal`) but breaks one type's
  existing public API. The adapter preserves API but introduces a small
  naming asymmetry.
- **Q1.b**: Should Arc 1 also audit other "almost-Ordinal" types in the
  ecosystem (e.g., `Index<T>` direct users, `Finite.Element<N>` if exists)
  for opt-in conformance, OR keep Arc 1 strictly to Ordinal + Element +
  Tagged and queue the rest as follow-up? The minimal scope recommendation
  is the latter.

### Q2 — Confirm Color.\`Protocol\` arc execution (v1.1.0: cascade fully in-scope)

**v1.0.0 framing**: cascade spans IEC/ISO spec packages (out-of-scope
fear). **v1.1.0 update**: all 7 Color.\`Protocol\` conformers are declared
INSIDE `swift-color-standard` itself (extension declarations on
IEC_61966 types still live in swift-color-standard, not in the IEC
spec package). The cascade does NOT cross into out-of-scope spec
packages (see §B.2). The arc is single-package on the
protocol-+-conformer side; consumer-site `try` additions ripple out to
swift-foundations layer (verified one hit; estimated single-digit count
ecosystem-wide).

One sub-question for execution:

- **Q2.a**: Should sRGB-clipping behavior be PRESERVED behind an explicit
  alternative init (e.g., `init(clamping color: Color)` ↔ throwing `init(_:Color)`),
  mirroring the precedent set by `Color.LAB.Lightness` which has both
  `init(_:) throws(Error)` and `init(clamping:)` (file:line
  `Color.LAB.swift:87, 97`)? This preserves the existing silent-clip
  behavior for callers who genuinely want clamping (display-pipeline
  use cases) while making the throwing version the documented default.
  Recommended: YES — both inits is the established pattern at the
  component level; lifting it to the color-level matches.

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
