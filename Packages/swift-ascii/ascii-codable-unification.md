# ASCII Codable Unification

<!--
---
version: 1.0.0
last_updated: 2026-05-14
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

ASCII bidirectional codec functionality currently splits across two structurally-incompatible protocol families:

- **Family #1 — Procedural / refinement-shape** (legacy, post-W4 deprecated but still load-bearing): `Binary.Serializable` (in `swift-binary-primitives`) + `Binary.ASCII.Serializable: Binary.Serializable` (in `swift-ascii-serializer-primitives`). Carries bidirectional `serialize(ascii:into:)` + `init(ascii:in:)`, typed-Error-per-conformer, Context-per-conformer (defaulting to `Void`), plus `Binary.ASCII.RawRepresentable` auto-derivation (three flavors: `String`, `[UInt8]`, `LosslessStringConvertible`), `Binary.ASCII.Wrapper<Wrapped>` instance accessor, `ExpressibleByStringLiteral` / `IntegerLiteral` / `FloatLiteral` defaults, `CustomStringConvertible` defaults, and concrete conformances on `Int / Int64 / UInt / UInt64` (`swift-foundations/swift-ascii/Sources/ASCII/Int+ASCII.Serializable.swift:103, 123, 145, 165`).

- **Family #2 — Attachment-based** (new, post-W1/W2/W5/J1): `Serializer_Primitives_Core.Serializable` (canonical, declared at `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19–25`) + `JSON.Serializable` (sibling exemplar, `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:94–129`, commit `0307edc`). One-direction-only on this protocol (serialize only — parsing lives on `Parser_Primitives_Core.Parseable` and its `ASCII` refinement). Uses `Serializer.Protocol`-conforming leaf serializers via `static var serializer: SomeSerializer`. `FixedWidthInteger+Serializable.swift` already pins `Int.serializer = ASCII.Decimal.Serializer<Int>` on canonical `Serializable` (`swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift:8–10`) — a parallel implementation of `Int → ASCII decimal` that does NOT compose with family #1.

The family-Codable convention Research doc (`swift-foundations/swift-json/Research/family-codable-convention.md` v1.0.0, commit `8c7a981`) establishes family #2 as the institute's go-forward pattern (siblings, not refinements; top-level naming-symmetry; composition through canonical leaf). Family #1's deprecation message at `Binary.ASCII.Serializable.swift:7` reads: *"Use `Binary.Serializable` / `Parser.Protocol` conformances directly; legacy Serialization namespace was removed in W4"* (commit `52ea620` — W4d-followup, "Update stale deprecation message referencing removed Serialization namespace"). The deprecation signals retreat intent but family #1 still carries substantial functionality with NO equivalent on the family #2 side.

This document scopes the unification per `[RES-002a]` triage: the analysis is `swift-ascii`-bounded in destination (the stdlib integer conformances live in `swift-foundations/swift-ascii`), but the protocol shape decisions reach back into `swift-ascii-serializer-primitives` and `swift-ascii-parser-primitives`, and the family-Codable convention they instantiate is ecosystem-wide. The doc lives in `swift-ascii/Research/` because the integer conformances and the ergonomic surface migration weight the analysis toward swift-ascii; promotion to `swift-institute/Research/` is appropriate once a second non-trivial format-Codable (e.g., MessagePack, Binary.LittleEndian) materializes per the cross-package promotion clause in `family-codable-convention.md:204–205`.

## Question

What is the minimum-loss migration path from family #1 (refinement-shaped, deprecated `Binary.ASCII.Serializable`) to family #2 (sibling-shaped, canonical `Serializable` + `Parser_Primitives_Core.Parseable` siblings) for ASCII?

Sub-questions, each of which the Analysis section resolves:

1. (R2) Feature-by-feature: what does family #1 provide, and what is the family #2 equivalent (or lack thereof) for each?
2. (R3) Does the family #2 split (`Serializable` + `Parseable`) cover what family #1's bidirectional `Binary.ASCII.Serializable` did, or does ASCII need a new bidirectional codec protocol? If yes, which of three shapes — `ASCII.Codable` (B1), per-sub-format codables `ASCII.Decimal.Codable` etc. (B3), or non-refining `ASCII.Serializable` + `ASCII.Parseable` siblings (B2) — is structurally correct?
3. (R4) Does family #1's `associatedtype Error` / `associatedtype Context` carry semantic load family #2 misses? Audit current Context use.
4. (R5) Is the family #1 ergonomic surface (RawRepresentable auto-derivation, Wrapper, Literal defaults) actually used in production? Empirical conformer count.
5. (R6) How is the `Int / Int64 / UInt / UInt64` dual-conformance — family #1 bidirectional vs family #2 canonical-Serializable-pinned — resolved?
6. (R7) Phased migration plan (Φ.1 – Φ.7).

## Analysis

### 1. Feature-by-feature disposition matrix (R2)

Citations are by file:line; family #2 column reflects empirical state at this writing date.

| # | Feature | Family #1 location | Family #2 equivalent | Disposition |
|---|---------|---------------------|----------------------|-------------|
| 1 | Bidirectional protocol in one shape | `Binary.ASCII.Serializable.swift:8–22` | Split: `Serializable.swift:19–25` (serialize) + `Parseable.swift:19–25` (parse) | **MIGRATE** to family #2 split — see §2 |
| 2 | Static `serialize(ascii: Self, into: &Buffer)` requirement | `Binary.ASCII.Serializable.swift:9–13` | `Serializer.Protocol.serialize(_:into:)` (`Serializer.Protocol.swift:81`) on the canonical serializer instance | **MIGRATE** — re-author on `Serializer.Protocol`-conforming leaf serializers (the existing `ASCII.Decimal.Serializer` is the model) |
| 3 | Failable `init(ascii: Bytes, in: Context)` requirement | `Binary.ASCII.Serializable.swift:17–20` | `Parser.Protocol.parse(_:)` on the canonical parser instance (per `Parseable.swift:19–25`, accessed via `.parser`) | **MIGRATE** — re-author on `Parser.Protocol`-conforming leaf parsers |
| 4 | Typed `associatedtype Error: Swift.Error` per conformer | `Binary.ASCII.Serializable.swift:14` | `Parser.Protocol.Failure` on parser instance (`Parser.Protocol`) / `Serializer.Protocol.Failure` (`Serializer.Protocol.swift:59`) on serializer instance | **MIGRATE** — error type slot moves from conformer protocol to leaf parser/serializer; conformers still get typed-throws via Parser/Serializer.Failure |
| 5 | `associatedtype Context: Sendable = Void` per conformer | `Binary.ASCII.Serializable.swift:15` | none on canonical `Serializable` / `Parseable` | **DROP** — empirical audit (§3) shows zero non-`Void` Context usage in production (only test fixture); the slot is speculative |
| 6 | `Binary.ASCII.RawRepresentable` auto-derivation, `RawValue == String` flavor | `Binary.ASCII.RawRepresentable.swift:12–24` | none | **RE-AUTHOR** on the new `ASCII.Serializable` sibling in Φ.2 (§4 — zero in-tree conformers but the affordance is load-bearing for downstream consumers per the deprecation message's "retain Binary.ASCII.Serializable, recommend new path" pattern) |
| 7 | `Binary.ASCII.RawRepresentable` auto-derivation, `RawValue == [UInt8]` flavor | `Binary.ASCII.RawRepresentable.swift:28–40` | none | **RE-AUTHOR** on the new sibling (same rationale) |
| 8 | `Binary.ASCII.RawRepresentable` auto-derivation, `RawValue: LosslessStringConvertible` flavor | `Binary.ASCII.RawRepresentable.swift:44–57` | none | **RE-AUTHOR** on the new sibling (same rationale) |
| 9 | `Binary.ASCII.Wrapper<Wrapped>` instance accessor (`.ascii`) | `Binary.ASCII.Wrapper.swift:7–15`, accessor at `:62–67` | none | **RE-AUTHOR** as `ASCII.Wrapper<Wrapped>` over the new sibling — the `.ascii` instance accessor is the format-ergonomic-surface signature, retained one-to-one |
| 10 | `ExpressibleByStringLiteral` default via `init(stringLiteral:)` → `try! init(value)` | `Binary.ASCII.Serializable.swift:123–130` | none | **RE-AUTHOR** on the new sibling — retains parseable-string-literal ergonomics for ASCII conformers |
| 11 | `ExpressibleByIntegerLiteral` default | `Binary.ASCII.Serializable.swift:132–138` | none | **RE-AUTHOR** on the new sibling |
| 12 | `ExpressibleByFloatLiteral` default | `Binary.ASCII.Serializable.swift:140–146` | none | **RE-AUTHOR** on the new sibling |
| 13 | `CustomStringConvertible` defaults (three flavors) | `Binary.ASCII.Serializable.swift:97–119` | none | **RE-AUTHOR** on the new sibling |
| 14 | `Array(ascii: Serializable)` / `String(ascii: Serializable)` initializers | `Binary.ASCII.Serializable.swift:53–57`, `:89–93` | none | **RE-AUTHOR** on the new sibling |
| 15 | `RangeReplaceableCollection.append(ascii:)` | `Binary.ASCII.Serializable.swift:148–154` | none | **RE-AUTHOR** on the new sibling |
| 16 | `Int / Int64 / UInt / UInt64` bidirectional conformances | `Int+ASCII.Serializable.swift:103, 123, 145, 165` | One-direction-only: `FixedWidthInteger+Serializable.swift:8, 13, 17, 21, 25, 29, 33, 37, 41, 45` pins canonical `Serializable.serializer = ASCII.Decimal.Serializer<T>`; parse-side analog at `swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift:11–49` pins `ASCII.Parseable.parser` (refinement-shape, per family-codable convention's RECOMMENDED-FOR-MIGRATION) | **MIGRATE** in Φ.3 — see §5 |
| 17 | `StringProtocol` bridge (`init(ascii: Serializable)`, `init?(ascii: [UInt8])`, `init?(ascii: UInt8)`, `init(decoding:)`, `init<T>(_ value: T)` for Binary.ASCII.Serializable) | `StringProtocol+INCITS_4_1986.swift:175–198`, `:221–223` | Partially: `Binary.Serializable` extension at `swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:172–175` provides `StringProtocol.init<T: Binary.Serializable>(_ value: T)` | **MIGRATE** in Φ.4 — re-author the family-#1-specific overloads on the new ASCII sibling |
| 18 | `parseSigned` / `parseUnsigned` byte-parser primitives | `Int+ASCII.Serializable.swift:34–98` (internal) | `ASCII.Decimal.Serializer.swift:32–70` (serialize side); parse side at `ASCII.Decimal.Parser` (per `family-codable-convention.md:296`) | **DROP-AS-DUPLICATE** in Φ.3 — `ASCII.Decimal.Parser`/`Serializer` are the family #2 leaf instances; the internal `parseSigned`/`parseUnsigned` helpers in `Int+ASCII.Serializable.swift` are duplicated work that the family #2 path replaces |
| 19 | `Binary.ASCII.Decimal.Error` typed-error namespace | `Int+ASCII.Serializable.swift:17–27` | TBD — likely lives on the `ASCII.Decimal.Parser`'s `Failure` type (verify in Φ.1) | **MIGRATE** — preserve the `.empty` / `.invalidByte(position:found:)` cases as the parser's `Failure` |

**Summary**: 19 distinct features. Of these:
- **1 MIGRATE-as-protocol-shape** (#1)
- **2 MIGRATE-as-mechanism** to family #2 split (#2, #3)
- **2 MIGRATE-with-relocation** (#4 to parser/serializer instance Failure; #17 to new sibling)
- **1 DROP** (#5 Context — zero production use)
- **8 RE-AUTHOR on new sibling** (#6–8 RawRepresentable, #9 Wrapper, #10–12 Literal, #13 CustomStringConvertible, #14–15 collection ergonomics)
- **1 MIGRATE** (#16 stdlib integer conformances)
- **1 DROP-AS-DUPLICATE** (#18)
- **1 MIGRATE-TYPE** (#19)

### 2. The bidirectional-shape question (R3)

The core architectural call is: what's the family #2 equivalent of `Binary.ASCII.Serializable: Binary.Serializable` (bidirectional, refinement-shape)?

#### Sub-question (a): Does `Coder.Protocol` apply at the ASCII level?

`Coder.Protocol` (`swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift:45–86`) is *"one Coder per format × value pair"* (per `Coder.Protocol.swift:24–26`). The JSON exemplar (`JSON.Coder` at `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:48–63`, commit `3500d18`) is one Coder serving the `RFC_8259.Value` value — *one* canonical pair.

For ASCII, the question is whether `(T, ASCII)` is similarly a one-canonical-codec pair for some unifying `T`, OR whether ASCII is a family of independent sub-formats (decimal, hexadecimal, base-62, ...) where the "ASCII" namespace is the wrapper, not the format.

The empirical evidence points to the latter:

- `ASCII.Decimal.Serializer<T: FixedWidthInteger>` (`swift-primitives/swift-ascii-serializer-primitives/Sources/ASCII Decimal Serializer Primitives/ASCII.Decimal.Serializer.swift:20–24`) — a sub-format leaf serializer.
- `ASCII.Hexadecimal.Serializer` exists as a sibling sub-format (per `Package.swift:25–27` and `Package.swift:73–78`).
- `UInt8.Base62.Serializing` (`swift-primitives/swift-base62-primitives/Sources/Base62 Primitives/UInt8.Base62.Serializing.swift:7`) explicitly notes: *"Follows the pattern established by Binary.ASCII.Serializable in INCITS_4_1986"* — base-62 is yet another ASCII sub-format.
- The codec is not `(T, ASCII)` — `Int` has TWO valid canonical ASCII codecs already in production (decimal, hexadecimal), and a third (base-62) by extension.

**Conclusion (a)**: `Coder.Protocol` does NOT apply at the ASCII level for stdlib types. It applies at the `ASCII.Decimal`, `ASCII.Hexadecimal`, `ASCII.Base62`, ... sub-format levels. ASCII the namespace groups codecs whose substrate is ASCII bytes, not codecs operating on one canonical (T, ASCII) pair.

This is the SAME structural property that motivates the family-Codable convention's stdlib-type carve-out: *"stdlib types … have NO inherent canonical codec — `Int` is JSON-numeric, ASCII-decimal, big-endian-binary, little-endian-binary, MessagePack-int-family, etc., simultaneously"* (`family-codable-convention.md:77`). ASCII is itself a node where the inherent-canonical-codec property fails for stdlib types.

#### Sub-question (b): Three shape options for the family #2 analog of `Binary.ASCII.Serializable`

Three options for expressing "this type is ASCII-codable":

**Option B1 — `ASCII.Codable` (sibling to `Coder_Primitives.Codable`) + `ASCII.Coder<T>: Coder.Protocol` leaves per `(T, ASCII-format)` pair (parallel to JSON.Coder/Codable)**

```swift
extension ASCII {
    public protocol Codable {
        associatedtype Coder: Coder_Primitives.Coder.`Protocol`
        static var coder: Coder { get }
    }
}

// Stdlib types pin per-format Coders
extension Int: @retroactive ASCII.Codable {
    public static var coder: ASCII.Decimal.Coder<Int> { .init() }
}
```

**Analysis**:
- Mirrors the JSON canonical pattern (`JSON.Coder: Coder.Protocol` + `RFC_8259.Value: Coder_Primitives.Codable` with `Coder = JSON.Coder`) — `JSON.Coder.swift:110–116`.
- But forces ONE coder per `(T, ASCII)` pair — exactly the lockout the family-Codable convention's "stdlib types have no canonical codec" rule rejects. If `Int.coder = ASCII.Decimal.Coder<Int>`, then `Int` cannot independently express its `ASCII.Hexadecimal.Coder<Int>` shape on the same `ASCII.Codable` protocol slot.
- Adding multiple `ASCII.Codable` sibling refinements (`ASCII.Decimal.Codable`, `ASCII.Hexadecimal.Codable`) per sub-format would reduce B1 to B3 (below) anyway.
- Verdict: **REJECTED** — replays exactly the failure mode the family-Codable convention's sibling-not-refinement rule was designed to avoid (`family-codable-convention.md:73–81`).

**Option B2 — Keep ASCII split: `ASCII.Parseable` (already exists, currently refining) + `ASCII.Serializable` (to author, sibling-shape). Conformers carry both.**

```swift
// ASCII.Parseable — already exists; migrate to non-refining sibling
extension ASCII {
    public protocol Parseable {
        associatedtype Parser: Parser_Primitives_Core.Parser.`Protocol`
        static var parser: Parser { get }
    }
}

// ASCII.Serializable — author as non-refining sibling
extension ASCII {
    public protocol Serializable {
        associatedtype Serializer: Serializer_Primitives_Core.Serializer.`Protocol`
        static var serializer: Serializer { get }
    }
}

// Conformers carry both:
extension Int: ASCII.Parseable, ASCII.Serializable {
    public static var parser: ASCII.Decimal.Parser<Parser.Input.Bytes, Int> { .init() }
    public static var serializer: ASCII.Decimal.Serializer<Int> { .init() }
}
```

**Analysis**:
- Matches the family-Codable convention's *"siblings, not refinements"* mandate (`family-codable-convention.md:263`).
- Reuses existing `ASCII.Parseable` (already declared at `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:10–18`, commit `747c28a`); the only change there is dropping the refinement of `Parser_Primitives_Core.Parseable`, matching `family-codable-convention.md:279` RECOMMENDED-FOR-MIGRATION.
- Symmetric with `JSON.Serializable` — `JSON.Serializable` carries `serialize`/`deserialize` together because JSON-the-tree is the canonical intermediate. ASCII has no canonical intermediate (the bytes ARE the intermediate); split shape is structurally honest.
- Each sub-format (decimal, hexadecimal, base-62) provides its own `ASCII.Decimal.Parser` / `ASCII.Decimal.Serializer` leaf, which the conformer pins via `static var parser/serializer`.
- A conformer can be ASCII-parseable but not ASCII-serializable (e.g., a parse-only adapter); the split honors this.
- Verdict: **STRUCTURALLY CORRECT** under the family-Codable convention. Adopted.

**Option B3 — Author `ASCII.Decimal.Codable` + `ASCII.Hexadecimal.Codable` + … (one per sub-format) plus a per-conformer mixing trait**

```swift
extension ASCII.Decimal {
    public protocol Codable {
        associatedtype Coder: Coder_Primitives.Coder.`Protocol`
        static var coder: Coder { get }
    }
}

extension Int: ASCII.Decimal.Codable {
    public static var coder: ASCII.Decimal.Coder<Int> { .init() }
}
// Plus: Int: ASCII.Hexadecimal.Codable { static var coder: ASCII.Hexadecimal.Coder<Int> }
```

**Analysis**:
- Aligns *most* closely with the family-Codable convention's "one Coder per format × value pair" tenet, where format here is `ASCII.Decimal` (not just `ASCII`).
- BUT: requires authoring N codable protocols (one per sub-format) AND N coder leaves. Currently only `ASCII.Decimal` and `ASCII.Hexadecimal` exist; base-62 lives in a separate package. The N-protocols sprawl carries maintenance cost.
- The bidirectional pairing for ASCII sub-formats may not always be wanted: an ASCII parser can compose with a non-ASCII serializer (e.g., parse decimal, serialize MessagePack) — the Coder.Protocol pair forces them together.
- Verdict: **DEFERRED** as a Φ.6+ refinement of B2 once a second non-trivial sub-format expresses Coder-shape demand. B2 doesn't preclude B3; conformers can carry `ASCII.Parseable` (pinning `ASCII.Decimal.Parser`) AND `ASCII.Decimal.Codable` (pinning `ASCII.Decimal.Coder`) simultaneously when both are useful.

#### Sub-question (c): Existing leaf-coder picture

Empirical facts:

- `ASCII.Decimal.Serializer<T: FixedWidthInteger>: Serializer.Protocol` exists (`ASCII.Decimal.Serializer.swift:20–71`, `Output = T`, `Buffer = [UInt8]`, `Failure = Never`).
- `ASCII.Decimal.Parser<Bytes, T>` is referenced from `FixedWidthInteger+Parseable.swift:12` etc. — exists in `swift-ascii-parser-primitives`.
- `ASCII.Hexadecimal.Serializer` exists as a product (`Package.swift:25–27`).
- NO `ASCII.Decimal.Coder<T>` exists at this writing (not in the package's product list, not in any imports).

The parser and serializer halves exist independently; the unified `Coder` shape does NOT yet exist for ASCII sub-formats. B2 is the cheapest option (no new Coder authoring); B3 would require authoring `ASCII.Decimal.Coder<T>` per sub-format from scratch.

#### Sub-question (d): Does family #1's bidirectional-in-one-protocol shape carry semantic load that the split would lose?

Family #1's `associatedtype Error` is shared between serialize and parse halves. In family #2's split shape, the parse half's failure type (`ASCII.Decimal.Parser.Failure`) and the serialize half's failure type (`ASCII.Decimal.Serializer.Failure` — typically `Never`) are independent.

**Does the family-#1 shared Error carry semantic value?**

Examining the in-tree conformers and the test fixtures:

- `Int / Int64 / UInt / UInt64`: `Error = Binary.ASCII.Decimal.Error` (`Int+ASCII.Serializable.swift:104, 124, 146, 166`). This error type is **parse-direction only** — both `.empty` and `.invalidByte` are parse failures (serialize is infallible per `serialize(ascii:into:)` semantics). The shared-Error shape lets serialize be infallible while declaring the parse-direction error; the family #2 split has `Serializer.Failure = Never` and `Parser.Failure = Binary.ASCII.Decimal.Error` (or equivalent rename) — same semantic content.
- Test fixture `Token` (`UInt8.ASCII.Serializable Tests.swift:53–65`): `Error = Token.Error` (`:46–50`), parse-direction.
- Test fixture `DelimitedMessage` (`:85–137`): `Error = DelimitedMessage.Error` (`:112–114`), parse-direction.

In all cases the shared-Error slot is used parse-direction-only. Splitting the Error to the parser instance preserves all observed semantics. The "bidirectional in one protocol" shape carries no semantic load beyond protocol-level coupling.

**Conclusion (R3)**: **Adopt Option B2** — non-refining `ASCII.Serializable` sibling (to author) + `ASCII.Parseable` migration from refinement to sibling (already RECOMMENDED-FOR-MIGRATION per family-codable-convention.md:279). The bidirectional-shape is preserved by carrying both conformances on the same type. The split is structurally honest because ASCII bytes ARE the intermediate (no canonical tree like JSON); the parse-direction failure and serialize-direction infallibility express naturally on independent halves.

### 3. Error / Context disposition (R4)

**Error**: family #2's expressiveness is sufficient. The parse-direction error moves from `associatedtype Error: Swift.Error` on the conformer to `associatedtype Failure: Swift.Error` on the parser leaf (per `Parser.Protocol`-conforming `ASCII.Decimal.Parser`). The serialize-direction error is independent and typically `Never` (per the existing `ASCII.Decimal.Serializer.Failure = Never` at `ASCII.Decimal.Serializer.swift:29`). Conformers retain typed-throws via `try Int.parser.parse(&input)` — the parser's `Failure` is `Binary.ASCII.Decimal.Error` (or the renamed equivalent under family #2).

**Context audit** (empirical):

- All four in-tree integer conformances (`Int / Int64 / UInt / UInt64`): `Context = Void` (default), per `Int+ASCII.Serializable.swift:118, 138, 160, 180`.
- Test fixture `Token`: `Context = Void` (`UInt8.ASCII.Serializable Tests.swift:56`).
- Test fixture `DelimitedMessage`: `Context = DelimitedMessage.Context { let delimiter: UInt8 }` — the ONLY non-`Void` Context in the workspace (`UInt8.ASCII.Serializable Tests.swift:108–110, 116`).

**Production conformer count for non-`Void` Context: 0.** (The single non-`Void` Context lives in test fixtures only.)

The Context-per-conformer slot is **speculative** — it was authored to support parameterized ASCII parsing (locale-sensitive radix, base-N where N varies) but no production conformer materialized to use it.

**Disposition**: **DROP** Context entirely in the family #2 sibling. If parameterized parsing is needed in the future, the right mechanism is per-format leaf-parser instances (e.g., `ASCII.Delimited.Parser(delimiter: UInt8)`) that take the parameter at parser-construction time. This composes with `Parser.Protocol` cleanly; the conformer would carry `.parser` returning the parameterized parser instance.

The supervisor's class-(c) trigger for "Context turns out load-bearing >3 real usages" is NOT met (the production count is 0).

### 4. Ergonomic extension surface audit (R5)

Empirical conformer counts (grep-validated across `swift-primitives/`, `swift-standards/`, `swift-foundations/`):

| Affordance | Production conformers | Test fixture conformers | Verdict |
|------------|----------------------|-------------------------|---------|
| `Binary.ASCII.Serializable` | 4 (`Int / Int64 / UInt / UInt64`) | 3 (`Token`, `DelimitedMessage`, `CorrectEmailAddress`) | LOW — only stdlib integers |
| `Binary.ASCII.RawRepresentable` | 0 | 1 (`CorrectEmailAddress` per `UInt8.ASCII.Serializable Tests.swift:626`) | UNUSED in production |
| `Binary.ASCII.Wrapper` instance accessor (`.ascii`) | Indirect: usable by any `Binary.ASCII.Serializable & Sendable` (`Binary.ASCII.Wrapper.swift:62–67`) — but no production call-site grep hits | 0 direct | UNUSED in production |
| `ExpressibleByStringLiteral` default | Indirect: enables string-literal init for any `Binary.ASCII.Serializable & ExpressibleByStringLiteral & Context==Void` | 1 (`Token` per `UInt8.ASCII.Serializable Tests.swift:69`) | UNUSED in production conformers |
| `ExpressibleByIntegerLiteral` default | 0 production conformers declaring this | 0 | UNUSED |
| `ExpressibleByFloatLiteral` default | 0 production conformers declaring this | 0 | UNUSED |
| `CustomStringConvertible` defaults (3 flavors) | 0 production conformers using this default chain | 1 (`Token`) | UNUSED |
| `Array(ascii:)` / `String(ascii:)` initializers | Indirect: usable by any caller with a Binary.ASCII.Serializable — uses at `StringProtocol+INCITS_4_1986.swift:221–223` | several test sites | RETAINED indirectly via cross-package use of `String(ascii: ...)`  |
| `RangeReplaceableCollection.append(ascii:)` | 0 grep hits in production | 0 | UNUSED |

**Conclusion**: The ergonomic extension surface is **substantially unused in production**. The only production conformer set is the four stdlib integer types. The bulk of the family-#1 affordance surface is dead-code-equivalent today.

This LOWERS the migration cost: instead of "re-author 8 affordances on the new sibling", the realistic migration is "preserve the affordances on the new sibling so future external consumers downstream of the institute can adopt the new pattern with the same ergonomics." There is no need to migrate any production conformer of the affordances (because none exist).

The supervisor's class-(c) trigger for "ergonomic surface heavily used such that re-authoring is a substantial sub-arc on its own" is NOT met (the surface is unused in production; the re-author cost is just protocol-extension re-authoring on the new sibling).

The recommendation is to **RE-AUTHOR the affordances on the new sibling** (per the disposition matrix in §1) rather than DROP them. The re-authoring cost is one-time and the affordances are part of the institute's external-facing API design even if internally unused.

### 5. Int / Int64 / UInt / UInt64 dual-conformance resolution (R6)

The current dual-conformance state:

- `swift-foundations/swift-ascii/Sources/ASCII/Int+ASCII.Serializable.swift:103` — `extension Int: @retroactive Binary.Serializable, Binary.ASCII.Serializable` (family #1, bidirectional). Pins `Error = Binary.ASCII.Decimal.Error`. Inline implements `serialize(ascii:into:)` (calls `INCITS_4_1986.Numeric.Serialization.serializeDecimal`) and `init(ascii:in:)` (calls internal `Binary.ASCII.Decimal.parseSigned`).
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift:8` — `extension Int: @retroactive Serializable` (family #2, canonical). Pins `Int.serializer = ASCII.Decimal.Serializer<Int>`.
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift:11` — `extension Int: ASCII.Parseable, @retroactive Parseable` (family #2, refinement-shape per family-codable-convention.md:279). Pins `Int.parser = ASCII.Decimal.Parser<Parser.Input.Bytes, Int>`.

Three independent code paths produce the same bytes (ASCII decimal). Disposition options:

**Option C1 — Keep family #2 canonical Serializable; drop family #1 bidirectional**
- Requires family #2 parse-side to provide the equivalent `init(ascii:in:)` ergonomics — already provided by `Parseable.init(ascii:)` (per `Parseable.swift:38–42`).
- Drops the redundant `Int+ASCII.Serializable.swift` integer conformances (4 types × 2 sides = 8 methods).
- BUT: family-codable convention's "no canonical conformance on stdlib types" rule (`family-codable-convention.md:104`) flags the canonical `Int: Serializable` (with `serializer = ASCII.Decimal.Serializer`) as RECOMMENDED-FOR-MIGRATION — exactly because it commits `Int.serializer` ecosystem-wide to ASCII decimal, lockout-style.
- Verdict: Partially correct (drops family #1 redundancy) but doesn't reach the structurally-correct end state.

**Option C2 — Keep family #1 bidirectional; drop family #2 canonical Serializable**
- Contradicts the family-codable convention's deprecation of refinement-shape (`family-codable-convention.md:264`).
- Verdict: REJECTED.

**Option C3 (RECOMMENDED) — Drop BOTH and move to the new ASCII.Serializable / ASCII.Parseable siblings, dropping canonical Serializable / Parseable conformances**

The structurally-correct end state per family-codable convention §6 option (b):

- `extension Int: ASCII.Serializable, ASCII.Parseable { static var serializer = ASCII.Decimal.Serializer<Int>; static var parser = ASCII.Decimal.Parser<Parser.Input.Bytes, Int> }` — both on non-refining ASCII-namespaced siblings.
- DROP `extension Int: @retroactive Serializable` (the canonical lockout-style conformance from `FixedWidthInteger+Serializable.swift`).
- DROP `extension Int: @retroactive Parseable` (the refinement-shape canonical lockout from `FixedWidthInteger+Parseable.swift`).
- DROP `extension Int: @retroactive Binary.Serializable, Binary.ASCII.Serializable` (family #1).

This preserves all functional behavior (bytes-in, bytes-out) via the new sibling protocols, while removing all three lockout-style global commitments. Future `Int: Binary.LittleEndian.Codable` or `Int: MessagePack.Codable` slots remain free.

The migration order matters: the new `ASCII.Serializable` sibling MUST exist (Φ.1) and the ergonomic affordances MUST be re-authored on it (Φ.2) before the integer conformances move (Φ.3). Otherwise, mid-migration there would be production-broken state.

**Disposition**: Adopt C3 as the Φ.3 target. Acknowledge that the Φ.3 move ALSO retires the canonical-`Serializable` `Int` pin — this is the family-codable convention's RECOMMENDED-FOR-MIGRATION in `family-codable-convention.md:280` for the canonical-Serializable side, and the symmetric retirement of `@retroactive Parseable` is its parser-side mirror.

### 6. Phased migration plan (R7)

Each phase is scoped to a tractable wave. Phases are gated on the prior phase's verification; the Research doc enumerates them but does NOT dispatch them.

#### Φ.1 — Author the new `ASCII.Serializable` sibling

**Scope**: Add `ASCII.Serializable` non-refining-sibling protocol at the appropriate package level. Mirror the existing `ASCII.Parseable` declaration shape (`ASCII.Parseable.swift:10–18`). Update `ASCII.Parseable` to drop its refinement of `Parser_Primitives_Core.Parseable` (per family-codable-convention.md:279 RECOMMENDED-FOR-MIGRATION).

**Location**: New file in `swift-primitives/swift-ascii-serializer-primitives/Sources/ASCII Serializer Primitives Core/ASCII.Serializable.swift` (parallel to `swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift`). Module `ASCII Serializer Primitives Core` already exists per `swift-ascii-serializer-primitives/Package.swift:21–23`.

**Acceptance**: Build green; no production conformer migrations yet.

#### Φ.2 — Re-author the ergonomic affordance surface on the new sibling

**Scope**: Re-author the 8 ergonomic affordances (§1 disposition matrix items #6–#15) ON `ASCII.Serializable` / `ASCII.Parseable`:
- `ASCII.RawRepresentable` (three RawValue flavors: String, [UInt8], LosslessStringConvertible)
- `ASCII.Wrapper<Wrapped>` + `.ascii` instance accessor
- `ExpressibleByStringLiteral` / `IntegerLiteral` / `FloatLiteral` defaults
- `CustomStringConvertible` defaults (three flavors)
- `Array(ascii:)` / `String(ascii:)` initializers
- `RangeReplaceableCollection.append(ascii:)`

**Location**: New files in `swift-ascii-serializer-primitives/Sources/ASCII Serializer Primitives Core/` and/or sibling targets. One type per file per `[API-IMPL-005]`.

**Acceptance**: Build green; no production conformer migrations yet; family #1 affordances still present (unused in production but retained for the deprecation-window contract).

#### Φ.3 — Migrate `Int / Int64 / UInt / UInt64` conformances

**Scope**: Adopt R6 option C3.
- Add `extension Int: ASCII.Serializable, ASCII.Parseable { ... }` (and equivalents for Int64 / UInt / UInt64) pinning `ASCII.Decimal.Serializer<T>` and `ASCII.Decimal.Parser<Parser.Input.Bytes, T>`.
- REMOVE `extension Int: @retroactive Serializable` from `FixedWidthInteger+Serializable.swift` and equivalents for Int64 / UInt / UInt64 and other widths (the canonical-Serializable pin retires per family-codable-convention.md:280).
- REMOVE `extension Int: ASCII.Parseable, @retroactive Parseable` and replace with `extension Int: ASCII.Parseable` (drop the canonical-Parseable pin per family-codable-convention.md:280; the ASCII.Parseable conformance is retained but no longer refines `Parser_Primitives_Core.Parseable` after Φ.1).
- REMOVE `extension Int: @retroactive Binary.Serializable, Binary.ASCII.Serializable` from `Int+ASCII.Serializable.swift` and equivalents.
- Migrate the `Binary.ASCII.Decimal.Error` typed-error to live on the parser leaf's `Failure`.
- DROP the internal `parseSigned` / `parseUnsigned` helpers (disposition #18 — replaced by `ASCII.Decimal.Parser`).

**Acceptance**: Build green; round-trip tests pass on new code path; no consumer breaks (consumers were using `init(ascii:)` from `Parseable`'s extension already, which now resolves to the non-refining `ASCII.Parseable`'s equivalent extension).

#### Φ.4 — Migrate StringProtocol bridge

**Scope**: Re-author `StringProtocol.init<T: Binary.ASCII.Serializable>(_ value: T)` (`StringProtocol+INCITS_4_1986.swift:221–223`) on the new ASCII.Serializable sibling. The `Binary.Serializable`-side `StringProtocol.init` at `Binary.Serializable.swift:172–175` is independent (different protocol) and may stay.

**Acceptance**: Build green; existing `String(value: T)` call sites continue to work (T now `ASCII.Serializable`); update any in-tree call site to import the new module.

#### Φ.5 — Verify swift-foundations/swift-ascii consumers

**Scope**: Audit grep results for `Binary.ASCII.Serializable`, `Binary.ASCII.RawRepresentable`, `Binary.ASCII.Wrapper`, and `init(ascii:)` (family-#1-shape) across `swift-primitives/`, `swift-standards/`, `swift-foundations/`. Per §4 audit: production conformer count is **4** (stdlib integers, already migrated by Φ.3). Consumer call sites of `init(ascii:)` are routed through `Parseable.init(ascii:)` extension (not family #1) — no consumer migration needed.

**Acceptance**: Workspace-wide grep confirms no production conformers remain (test fixtures retained for parallel testing during the deprecation window).

#### Φ.6 — Resolve the parser-side family-codable Research-doc-flagged migration

**Scope**: Resolve the residual items from `family-codable-convention.md:279–280` not yet covered by Φ.1–Φ.5:
- `ASCII.Parseable: Parser_Primitives_Core.Parseable` refinement → already addressed in Φ.1.
- Stdlib integer `@retroactive Parseable` (`FixedWidthInteger+Parseable.swift:11`) — already addressed in Φ.3.
- Stdlib integer `@retroactive Serializable` (`FixedWidthInteger+Serializable.swift:8`) — already addressed in Φ.3.

If by the time Φ.6 fires a second non-trivial format-Codable has landed (e.g., MessagePack, Binary.LittleEndian) and demanded ASCII.Decimal.Codable / ASCII.Hexadecimal.Codable sub-format-Coder leaves, this phase ALSO authors them per R3 option B3-as-supplement (B2 conformers continue to work; new B3 conformers add). This is the bidirectional-pair-when-useful refinement deferred earlier.

**Acceptance**: Build green; family-codable convention's "RECOMMENDED-FOR-MIGRATION" items resolved.

#### Φ.7 — DELETE `Binary.ASCII.Serializable` and its extension files

**Scope**: After Φ.1–Φ.6 are stable, delete:
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift`
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.RawRepresentable.swift`
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Wrapper.swift`
- The `Binary ASCII Serializable Primitives` target (`Package.swift:91–96`).
- The umbrella re-export at `Package.swift:106`.
- The umbrella re-export at `swift-foundations/swift-ascii/Sources/ASCII/exports.swift:8`.
- The `Binary.ASCII.Decimal` namespace declaration in `Int+ASCII.Serializable.swift` (if Φ.3 moved the contents elsewhere — verify).

Per `[HANDOFF-035]`: workspace-wide grep verification including `Package.swift` declarations.

**Acceptance**: Workspace-wide build green; zero `Binary.ASCII.Serializable` / `Binary.ASCII.RawRepresentable` / `Binary.ASCII.Wrapper` grep hits.

### 7. Open phasing observations

- **Phases are independent of `[HANDOFF-035]` workspace-grep-verification cadence**: each phase has its own internal grep scope. Φ.7 is the only one carrying the workspace-wide deletion-verification per `[HANDOFF-035]`.
- **No semantic-content loss across the migration**: every family-#1 affordance has an explicit disposition (MIGRATE / RE-AUTHOR / DROP-AS-DUPLICATE / DROP) in the matrix at §1. Net behavior preserved for every observed production use.
- **Two RECOMMENDED-FOR-MIGRATION items from family-codable-convention.md:279–280 are addressed by Φ.1 and Φ.3 in this plan**, not deferred. This brings the parser side into structural alignment with the convergent framing as a side-effect of the ASCII unification, not as a follow-up arc.
- **Promotion trigger**: when this Research doc completes Φ.1–Φ.7 (or substantially completes through Φ.6), the doc SHOULD be promoted from `swift-ascii/Research/` to `swift-institute/Research/` per `[RES-002a]`'s "multiple packages, no clear owner, or spanning layers" criterion — the analysis at this level touches three packages (swift-ascii, swift-ascii-serializer-primitives, swift-ascii-parser-primitives) and the convention it instantiates is ecosystem-wide.

## Comparison

The three shape options for R3 (the load-bearing architectural call) side-by-side:

| Criterion | B1: `ASCII.Codable` + Coder | B2: split `ASCII.Serializable` + `ASCII.Parseable` siblings | B3: per-sub-format `ASCII.Decimal.Codable` etc. |
|-----------|------------------------------|-----------------------------------------------------------|------------------------------------------------|
| Mirrors family-codable convention's siblings-not-refinements | NO — refinement-shape on `Coder_Primitives.Codable` AND lockout-style commits `(T, ASCII)` pair | YES — non-refining siblings | YES (each sub-format protocol is a sibling at `ASCII.Decimal` / `ASCII.Hexadecimal` namespace) |
| Reuses existing infrastructure | Parser side (`ASCII.Parseable`) NO; Coder side N/A — would need ASCII.Coder built | YES — `ASCII.Parseable` exists; `ASCII.Decimal.Serializer`/`Parser` exist | NO — would need to author N Coder leaves per sub-format |
| Stdlib type freedom | LOCKED — one canonical ASCII codec per stdlib type | FREE — `Int: ASCII.Serializable` independent of any other format-Serializable | FREE per sub-format |
| Supports parse-only / serialize-only conformers | NO — Coder is bidirectional | YES — type may conform to just one half | NO — Coder is bidirectional |
| Number of new protocols to author | 1 (ASCII.Codable) + N leaves | 1 (ASCII.Serializable — ASCII.Parseable already exists) | N (one Codable per sub-format) + N Coder leaves |
| Symmetric with JSON's exemplar (JSON.Serializable as sibling) | NO — uses Coder | YES — JSON.Serializable IS bidirectional in one sibling protocol; ASCII split would diverge structurally | NO |
| Aligns with R3 sub-question (a) finding ("ASCII is a family of sub-formats, not a one-codec format") | Replays the lockout failure mode | Honors the sub-format multiplicity at the conformer-level (`Int: ASCII.Serializable` with `ASCII.Decimal.Serializer`) | Reifies sub-formats as independent protocols (most "honest" but heaviest) |

**Tradeoff resolution per `[RES-022]` (structural correctness over diff-size)**:

B1 is rejected on structural grounds (lockout failure mode). B3 is structurally finer-grained than B2 but adds N-protocols sprawl when only two leaves (`ASCII.Decimal`, `ASCII.Hexadecimal`) exist today; the protocol multiplication is not justified by current consumer count. B2 is the minimum-loss option that preserves family-codable structural correctness and uses only existing infrastructure.

A divergence-from-JSON-exemplar concern for B2: JSON.Serializable carries `serialize` + `deserialize` together (`JSON.Serializable.swift:94–129`) because JSON-the-tree is the canonical intermediate. ASCII has no canonical intermediate; the bytes ARE the intermediate. The asymmetry is structurally honest, not architectural drift. The family-codable convention's *"composition through the canonical leaf"* rule (`family-codable-convention.md:84–97`) is preserved: each ASCII conformer composes through its leaf parser AND its leaf serializer instances, both of which are independent `Parser.Protocol` / `Serializer.Protocol` conformers.

## Outcome

**Status**: RECOMMENDATION

**Conclusion**: The ASCII unification under the family-Codable convention is structurally tractable. The minimum-loss migration path is:

1. **R3 architectural call**: Adopt Option B2 — non-refining `ASCII.Serializable` sibling (to author) + `ASCII.Parseable` migration from refinement to sibling (already RECOMMENDED-FOR-MIGRATION per the family-codable-convention Research doc).
2. **R2 feature dispositions** (19-row matrix): 1 MIGRATE-as-protocol-shape, 2 MIGRATE-as-mechanism, 2 MIGRATE-with-relocation, 1 DROP (Context), 8 RE-AUTHOR on new sibling, 1 MIGRATE (stdlib integers), 1 DROP-AS-DUPLICATE, 1 MIGRATE-TYPE.
3. **R4 Error/Context**: Error migrates from conformer protocol to leaf parser/serializer `Failure` (semantic content preserved); Context drops (zero production usage).
4. **R5 Ergonomic surface**: substantially unused in production (only 4 stdlib integer conformers; 0 RawRepresentable / Wrapper / Literal-default production conformers). RE-AUTHOR on new sibling rather than DROP, for external-consumer continuity.
5. **R6 Stdlib integer dual-conformance**: Adopt option C3 — drop family #1 bidirectional, drop the family #2 canonical-Serializable / canonical-Parseable pins, move to `Int: ASCII.Serializable, ASCII.Parseable` on the new non-refining siblings. This simultaneously resolves the family-codable Research doc's RECOMMENDED-FOR-MIGRATION items for stdlib integers.
6. **R7 Phases**: Φ.1 author new sibling + drop ASCII.Parseable refinement; Φ.2 re-author affordances; Φ.3 migrate stdlib integer conformances; Φ.4 StringProtocol bridge; Φ.5 verify consumers (zero production conformers expected to need source-level changes); Φ.6 resolve residual family-codable items; Φ.7 DELETE legacy.

**Structural state by phase**:

| Element | Pre-Φ | Φ.1 | Φ.3 | Φ.7 |
|---------|-------|-----|-----|-----|
| `Binary.ASCII.Serializable` protocol | DEPRECATED, present | DEPRECATED, present | DEPRECATED, present (stdlib integers no longer conform) | DELETED |
| `ASCII.Parseable` shape | refinement | sibling | sibling | sibling |
| `ASCII.Serializable` shape | absent | non-refining sibling, no conformers | non-refining sibling, stdlib integers conform | non-refining sibling |
| `Int: @retroactive Serializable` (canonical) | present, pinned | present | REMOVED | absent |
| `Int: @retroactive Parseable` (canonical) | present, pinned | present | REMOVED | absent |
| `Int: @retroactive Binary.Serializable, Binary.ASCII.Serializable` (family #1) | present | present | REMOVED | absent |
| `Int: ASCII.Serializable, ASCII.Parseable` (new siblings) | absent | absent | present | present |

**Implementation notes**:

- The Research doc DOES NOT dispatch any phase. Each Φ phase is a separate handoff, gated on the prior phase's verification per `[SUPER-014]` / `[HANDOFF-019]`.
- The plan is consistent with the family-codable-convention Research doc's RECOMMENDED-FOR-MIGRATION items (`family-codable-convention.md:279–280`) — Φ.1 addresses the `ASCII.Parseable` refinement; Φ.3 addresses the stdlib integer canonical pins.
- No class-(c) trigger fires:
    - R3's bidirectional-shape question resolves to ASCII-local authoring (`ASCII.Serializable`) plus a pre-existing already-RECOMMENDED `ASCII.Parseable` migration — NOT a new ecosystem-wide protocol revision.
    - R4's Context audit shows zero production usages (well below the >3 trigger threshold).
    - R5's ergonomic surface audit shows 0 production conformers of the affordances — re-authoring is one-time protocol-extension work, not a sub-arc.

**Implementation state**:

| Element | Status | Evidence |
|---------|--------|----------|
| Family #1 deprecation message | CONFIRMED | `Binary.ASCII.Serializable.swift:7`, commit `52ea620` |
| Family #2 canonical `Serializable` | CONFIRMED | `swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19–25` |
| Family #2 canonical `Parseable` | CONFIRMED | `swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:19–25` |
| Family #2 `JSON.Serializable` sibling exemplar | CONFIRMED | `swift-json/Sources/JSON/JSON.Serializable.swift:94–129`, commit `0307edc` |
| Family-codable convention Research doc | CONFIRMED (RECOMMENDATION) | `swift-json/Research/family-codable-convention.md` v1.0.0, commit `8c7a981` |
| ASCII.Parseable as refinement | CONFIRMED — RECOMMENDED-FOR-MIGRATION per family-codable convention | `swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:10–18`, commit `747c28a` |
| Stdlib integer dual-pinning (canonical Serializable + canonical Parseable) | CONFIRMED — RECOMMENDED-FOR-MIGRATION per family-codable convention | `FixedWidthInteger+Serializable.swift:8–10`, `FixedWidthInteger+Parseable.swift:11–13` (commit `68e02d7`) |
| Family #1 stdlib integer conformances | CONFIRMED | `Int+ASCII.Serializable.swift:103, 123, 145, 165` |
| Φ.1 — author ASCII.Serializable sibling + ASCII.Parseable de-refinement | RECOMMENDED | this doc |
| Φ.2 — re-author ergonomic affordances | RECOMMENDED | this doc |
| Φ.3 — migrate stdlib integer conformances | RECOMMENDED | this doc |
| Φ.4 — StringProtocol bridge migration | RECOMMENDED | this doc |
| Φ.5 — verify consumers | RECOMMENDED | this doc |
| Φ.6 — resolve parser-side residuals | RECOMMENDED | this doc |
| Φ.7 — DELETE family #1 | RECOMMENDED | this doc |

## References

**Family #1 — current legacy state**:
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift` (deprecation commit `52ea620`)
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.RawRepresentable.swift`
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Wrapper.swift`
- `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift`
- `swift-foundations/swift-ascii/Sources/ASCII/Int+ASCII.Serializable.swift`
- `swift-foundations/swift-ascii/Sources/ASCII/StringProtocol+INCITS_4_1986.swift`
- `swift-foundations/swift-ascii/Tests/ASCII Tests/UInt8.ASCII.Serializable Tests.swift` (Context + RawRepresentable test fixtures)

**Family #2 — canonical attachment protocols + JSON exemplar**:
- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift` (canonical Coder-attachment protocol)
- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift` (operational Coder protocol)
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift` (canonical Parser-attachment protocol)
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift` (canonical Serializer-attachment protocol)
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializer.Protocol.swift` (operational Serializer protocol)
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` (commit `0307edc`, sibling exemplar)
- `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift` (commit `3500d18`, canonical Coder for RFC_8259.Value)

**Family #2 — ASCII-substrate leaves**:
- `swift-primitives/swift-ascii-serializer-primitives/Sources/ASCII Decimal Serializer Primitives/ASCII.Decimal.Serializer.swift`
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift`
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift` (commit `747c28a`)
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift` (commit `68e02d7`)
- `swift-primitives/swift-ascii-serializer-primitives/Package.swift` (target structure including the deprecated `Binary ASCII Serializable Primitives` shim)

**Authoritative family-Codable convention anchor**:
- `swift-foundations/swift-json/Research/family-codable-convention.md` v1.0.0 (RECOMMENDATION, 2026-05-14, commit `8c7a981`)

**Consumers (verified to use `Parseable.init(ascii:)` from canonical Parseable, NOT family #1)**:
- `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Semantic+Parseable.swift` (commit `3b4eb5d`)
- `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Calendar+Parseable.swift`
- `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Tools+Parseable.swift`
- `swift-primitives/swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern+Parseable.swift`
- `swift-standards/swift-emailaddress-standard/Sources/EmailAddress Standard/RFC_2822+RFC_6531.swift`

**Adjacent prior art**:
- User memory: `project_parser_serializer_coder_system_framing.md` (framing memo locking in sibling-not-refinement)
- `swift-foundations/swift-json/Research/family-codable-convention.md` §6 (parser-side refinement-vs-siblings tension, the source of Φ.1 / Φ.3's RECOMMENDED-FOR-MIGRATION items)
