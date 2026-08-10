# Multi-Format Codable Readiness

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

The institute's family-Codable convention shipped 2026-05-14 as a `RECOMMENDATION` Research doc (`family-codable-convention.md` v1.0.0, commit `8c7a981`), formalising a structural pattern that emerged across W1–W5 + T1–T2 + J1 arcs: *canonical attachment protocols* (`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`, `Serializer_Primitives_Core.Serializable`) reserved for spec-value types with one inherent canonical codec, plus *format-specific sibling attachment protocols* (`JSON.Serializable`) for stdlib and user-defined types whose representation is format-dependent. The ASCII unification follow-up (`ascii-codable-unification.md` v1.0.0, also 2026-05-14) enumerates a seven-phase migration (Φ.1–Φ.7) bringing `ASCII.Parseable` and the canonical stdlib-integer pinnings into structural alignment.

At end-of-arc the principal pushed back: the convention is *theoretical for any non-JSON format*. The user statement: *"we want to be able to serialize to and parse from various formats … I am not confident the current setup is perfect in that respect."* The handoff brief (`HANDOFF-multi-format-codable-readiness.md`) listed five gaps (G1–G5) plus two cross-cutting findings (CROSS-1 language-mechanism premise; CROSS-2 V4 D naming-convention finding) and required a literature-review section grounding the institute's structural calls against Rust serde, Haskell type-class libraries, Foundation Codable (SE-0166/SE-0167), Swift Forums threads, and third-party Swift libraries.

The investigation immediately surfaced **a load-bearing empirical correction to the brief's "N=1" framing**: workspace-wide grep returned not one but **three production sibling format-Codable protocols** following the convention's shape — `JSON.Serializable` (the documented exemplar), `Plist.Serializable` (`swift-foundations/swift-plist`), and `XML.Serializable` (`swift-foundations/swift-xml`). All three follow the same structural pattern: top-level under their format namespace, no `associatedtype`, `static func serialize(_:) -> Format` + `static func deserialize(_:) throws(Format.Error) -> Self`, format-natural Optional null-sentinel semantics, conformances on `String`/`Int`/`Double`/`Bool`/`Array`/`Dictionary`/`Optional`. This is convergent evidence — Plist.Serializable and XML.Serializable predate the J1d formalisation but arrived at the same shape independently. The brief's framing was empirically incomplete; the multi-format Codable story is structurally validated by three tree-intermediate siblings, with the structural contrast (a non-tree byte-stream sibling) remaining the live forcing-function target.

This document resolves the eight scope items against that empirical state.

## Question

Is the institute's multi-format Codable story structurally and empirically ready for adoption beyond JSON, or does it carry unresolved structural / ergonomic gaps that must close before a second non-trivial format-Codable ships?

Sub-questions, each resolved in the Analysis:

1. (G1) What does *the pattern is validated* require beyond JSON? Pick a forcing-function candidate (originally framed in the brief as `Binary.LittleEndian.Codable`; corrected during v1.1.0 drafting to the Binary split-pair sibling — `Binary.Parseable` NEW + enhanced `Binary.Serializable` with `Binary.Endianness` operation parameter; see §1 + [FAM-005]) and identify which currently-CONFIRMED items get re-classified.
2. (G2) Stdlib lock-in via canonical conformances — what's the empirical scope after Φ has been queued?
3. (G3) Bidirectional ASCII in family #2 — do any Φ decisions become brittle under a second-format adoption?
4. (G4) User-type multi-format ergonomics — what is the structurally-correct macro strategy?
5. (G5) W2 combinator catalog at user-level — when does authoring via combinators beat method bodies?
6. (CROSS-1) Language-mechanism premise — codify the associated-type-trap as a load-bearing convention premise; audit the canonical attachment protocols' `associatedtype` exposure.
7. (CROSS-2) V4 D naming-convention finding — codify the format-specific accessor + non-generic-wins call-site rule.
8. (External) State of the art — ground each structural call against Rust serde, Haskell type-class encoding, Foundation Codable (SE-0166/SE-0167), Swift Forums, and third-party Swift libraries.

## Analysis

### 0. Empirical baseline — the convention is N≥3, not N=1

Workspace grep for `extension <stdlib>:.*\.(Parseable|Serializable|Codable)\b`:

| Sibling protocol | Package | Shape |
|---|---|---|
| `JSON.Serializable` | `swift-foundations/swift-json` (J1d, commit `0307edc`) | `static serialize(_:) -> JSON`; `static deserialize(_:) throws(JSON.Error) -> Self`; `static deserialize(events: inout JSON.Span.EventStream)` — event-grain fast path |
| `Plist.Serializable` | `swift-foundations/swift-plist` (`Plist.Serializable.swift:3`) | `static serialize(_:) -> Plist`; `static deserialize(_:) throws(Plist.Error) -> Self`; `Sendable` refinement |
| `XML.Serializable` | `swift-foundations/swift-xml` (`XML.Serializable.swift:36`) | `static serialize(_:) -> XML`; `static deserialize(_:) throws(XML.Error) -> Self`; `Sendable` refinement |

Conformances on `String`, `Int`, `Double`, `Bool`, `Array<E: F.Serializable>`, `Dictionary<String, V: F.Serializable>`, `Optional<W: F.Serializable>` exist on all three. Optional handling is format-natural per sibling (`JSON.null` literal at `JSON.Serializable.swift:556`; `.null` at `Plist.Serializable.swift:178`; `XML.Element(name: "null")` at `XML.Serializable.swift:161`).

`Binary.Serializable` at L1 (`swift-binary-primitives/Binary.Serializable.swift:37`) is a fourth sibling but with a different shape: generic over `Buffer: RangeReplaceableCollection where Buffer.Element == UInt8`, serialize-only on the protocol body, no `deserialize` peer (parsing lives on `Parser.Protocol` instances).

**Empirical reading**: the family-Codable convention is *not* N=1 — JSON / Plist / XML are convergent evidence of the same tree-intermediate sibling shape. The user's stated concern (*"I am not confident the current setup is perfect"*) is still valid because none of these three is structurally different from JSON: all three use a tree-shaped intermediate format, all three carry the same Optional-null-sentinel pattern, all three escape the canonical-Codable lockout in the same way. **The genuine forcing function is a non-tree-intermediate sibling** (byte-stream, fixed-width, no null primitive). The brief originally named this candidate as `Binary.LittleEndian.Codable`; during v1.1.0 drafting both peer reviewers independently flagged the naming as wrong (compound identifier violating [API-NAME-001]; endianness over-modeled as sibling format). The corrected forcing function is the Binary split-pair sibling — `Binary.Parseable` NEW + enhanced `Binary.Serializable` with `Binary.Endianness` operation parameter. See §1 for the analysis; [FAM-005] for the codified rule.

### 0a. Resolution of the multiple-conformance question

**Question**: can a single type — stdlib or user-defined — carry multiple sibling format-Codable conformances simultaneously, without conflict?

**Answer**: yes. Both the structural argument and the empirical experiment confirm it. The solution is one extension per format, with independent format-natural representation in each.

**Structural derivation** (why it works):

1. Sibling protocols (`JSON.Serializable`, `Plist.Serializable`, `XML.Serializable`, `Binary.Serializable`) are *independent* — none refines another. No single canonical commitment is forced ecosystem-wide.
2. Sibling protocols carry NO `associatedtype` requirements (audit in §6). Swift's same-named-associated-type-anchor mechanism (which would unify `JSON.Serializable.Foo` and `Plist.Serializable.Foo` into a single binding if both protocols declared `associatedtype Foo`) cannot fire because there are no associated types to unify.
3. Each sibling's `serialize`/`deserialize` methods take format-specific input/output types (`-> JSON` vs `-> Plist` vs `into: inout Buffer`). Overload resolution at consumer call sites disambiguates by return type / parameter shape (CROSS-2 §7).

**Empirical evidence** (V1–V3 of the `double-json-binary-dual-conformance` experiment, 2026-05-14):

- `Double` carries `JSON.Serializable` (declared in `swift-foundations/swift-json`) AND `Binary.Serializable` (declared retroactively in a separate Probe package). Both conformances coexist without diagnostic. Compile clean in debug and release.
- JSON round-trip lossless on finite values; Binary round-trip lossless including NaN and ±∞ (bit-pattern equality).
- Witness-function generic coercion `func witnessJSON<T: JSON.Serializable>(_:)` and `func witnessBinary<T: Binary.Serializable>(_:)` both accept `Double.self`.

**Production evidence** (workspace-grep, §0):

- `Int`, `Double`, `String`, `Bool`, `Array<E>`, `Dictionary<String, V>`, `Optional<W>` all carry `JSON.Serializable` + `Plist.Serializable` + `XML.Serializable` simultaneously in shipping code. The pattern is in active use.

**What it looks like in code** (worked user-defined-type example):

```swift
struct User: Sendable {
    var name: String
    var age: Int
}

extension User: JSON.Serializable {
    static func serialize(_ u: User) -> JSON {
        .object(["name": u.name.json, "age": u.age.json])
    }
    static func deserialize(_ j: JSON) throws(JSON.Error) -> User { /* ... */ }
}

extension User: Plist.Serializable {
    static func serialize(_ u: User) -> Plist {
        .dictionary([("name", u.name.plist), ("age", u.age.plist)])
    }
    static func deserialize(_ p: Plist) throws(Plist.Error) -> User { /* ... */ }
}

extension User: Binary.Serializable, Binary.Parseable {   // byte-stream split-shape (Binary.Parseable is the new peer to be authored)
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ u: User, endianness: Binary.Endianness = .little, into buffer: inout Buffer
    ) where Buffer.Element == UInt8 { /* ... */ }
    static func parse(
        from input: inout Binary.Input, endianness: Binary.Endianness = .little
    ) throws(Binary.Error) -> User { /* ... */ }
}
```

Each `extension` body is independent. Each picks the format-natural representation (JSON object node vs Plist dictionary vs little-endian byte sequence). The three conformances coexist on `User` by construction — no shared state, no shared associatedtype slot, no conflict.

**Call-site disambiguation** (the consumer-facing API):

```swift
let json:  JSON    = user.json     // JSON.Serializable instance accessor
let plist: Plist   = user.plist    // Plist.Serializable instance accessor
let xml:   XML     = user.xml      // XML.Serializable instance accessor
let bytes: [UInt8] = user.bytes    // Binary.Serializable instance accessor; endianness defaulted (or passed explicitly)
```

Format-specific instance accessors are unambiguous regardless of which siblings are in scope. The bare-static-form (`User.serialize(user)`) without explicit return-type context is the one shape to avoid — per V4 D (§7), Swift's overload resolution picks something deterministic but not always obvious. The convention's recommendation is "always use format-specific accessors at call sites."

**What is empirically proven vs still ahead**:

| Case | Evidence | State |
|---|---|---|
| Two siblings, one stdlib type, two packages, cross-package retroactive | V1–V3 dual-conformance experiment | CONFIRMED |
| Three siblings on stdlib primitives in production | JSON + Plist + XML workspace-grep (§0) | CONFIRMED |
| Non-tree (byte-stream) sibling alongside tree siblings on `Double` | V1–V3 experiment (JSON + Binary) | CONFIRMED |
| Non-tree sibling alongside tree siblings on `Int`/`String` (canonical-pin currently blocks) | Φ.3 unblocks per `ascii-codable-unification.md:309–319` | RECOMMENDED-FOR-MIGRATION |
| Three siblings on a user-defined type, manual conformance | Structurally identical to the stdlib case; not yet exercised | DEFERRED-PENDING-EMPIRICAL-VALIDATION (manual labour, not a research question) |

**Summary**: multiple-conformance is structurally resolved by sibling-not-refinement + method-based (no associatedtype). Empirically validated for stdlib primitives and one stdlib floating-point case across packages. The remaining unproven case (user-defined-type with three siblings) is hand-writing the conformances — no research question remains.

### 1. G1 — Forcing-function analysis with the Binary split-pair sibling

**Candidate (corrected per mid-investigation naming refinement, 2026-05-14)**: the split byte-stream sibling pair — `Binary.Parseable` (NEW, to be authored, parallel to `ASCII.Parseable`) plus the existing `Binary.Serializable` (enhanced with `Binary.Endianness` as an operation parameter).

> **Naming/architecture correction**: this section originally framed the forcing function as a per-endianness protocol `Binary.LittleEndian.Codable`. Both peer reviewers (Claude peer + ChatGPT) independently flagged this as the wrong abstraction boundary — `LittleEndian` is a compound identifier violating [API-NAME-001], and endianness is a byte-order *policy* inside binary encoding rather than a separate sibling format. The corrected framing: **endianness is an operation parameter via the existing `Binary.Endianness` enum**, NOT a sibling format namespace. The forcing function becomes the missing Parseable half plus the endianness-parameter enhancement to the existing Serializable. Codified as [FAM-005] in the convention v1.1.0.

**Structural differences from JSON/Plist/XML**:

| Property | JSON / Plist / XML | Binary (split pair) |
|---|---|---|
| Intermediate representation | Tree (`JSON`, `Plist`, `XML` values) | Byte stream (`[UInt8]` / `Buffer`) |
| Optional null primitive | Format-native (`null`, `.null`, element-absence) | None — depends on outer framing or sentinel byte |
| Integer encoding | Tagged tree node | Fixed-width bytes; byte order via `Binary.Endianness` parameter |
| String encoding | Format-native (UTF-8 text node) | Length-prefixed or null-terminated — depends on convention |
| Sibling shape | Bidirectional in one protocol | Split: `Binary.Serializable` + `Binary.Parseable` peer (mirrors ASCII split-shape) |
| Composability | Tree builder (method calls) | Byte appender (combinator builders natural — see G5) |

**Forcing-function table** — which currently-CONFIRMED items get re-classified when the Binary split-pair sibling ships:

| Convention item | Pre-Binary-pair | Post-Binary-pair | Why |
|---|---|---|---|
| Sibling shape (`F.Serializable: Sendable` + `static serialize/deserialize`) | CONFIRMED for tree-intermediate | RECOMMENDED-FOR-MIGRATION — two-shape catalog (tree-builder bidirectional vs byte-appender split) | Binary has no canonical tree intermediate; serialize is naturally infallible (just append bytes), parse is naturally fallible. The split shape mirrors ASCII's pattern: Serializable + Parseable as separate peer protocols. Codified at convention §1 + §7. |
| `static func serialize(_:) -> Format` requirement | CONFIRMED for tree-intermediate | DEFERRED for byte-stream — natural shape is `serialize(_:, endianness:, into: inout Buffer)` | Binary's natural signature is byte-appender with endianness as a runtime parameter. Two distinct method shapes (one per direction) on two distinct protocols (Serializable + Parseable). Format-natural per convention §1 two-shape catalog. |
| Format-natural Optional semantics | CONFIRMED | CONFIRMED (extends naturally) | Binary's "no bytes for nil" matches `Serializer.Optionally` semantics at L1 (`Optional+Serializable.swift:21`). Format-natural — no convention change needed. |
| Composition through canonical leaf | CONFIRMED (JSON via `JSON.Decode.Implementation.parse`) | CONFIRMED — extends naturally | Each leaf serializer/parser instance (e.g., `Int.LengthPrefixed.Serializer`, `UInt32` serialize body with endianness switch) composes via the existing `Serializer.Protocol` / `Parser.Protocol` infrastructure. Composition is structurally identical. |
| Per-format accessor (`.json`, `.plist`, `.xml`) | CONFIRMED | CONFIRMED — `.bytes` already exists | `Binary.Serializable` already provides `var bytes: [UInt8]` (`Binary.Serializable.swift:60`); enhanced version takes optional endianness. Binary.Parseable provides `init(bytes:endianness:)` via extension. |
| V4 D non-generic-wins rule | CONFIRMED (empirically verified in dual-conformance experiment) | Becomes load-bearing | Once two siblings coexist on a single type without explicit type context, the rule fires. Binary's generic-extension shapes will lose to JSON.Serializable's non-generic deterministically. Convention sidesteps via instance-accessor rule [FAM-004] rather than relying on V4 D. |
| Per-endianness sibling namespaces | Implicitly considered (Binary.LittleEndian.Codable, Binary.BigEndian.Codable) | REJECTED per [FAM-005] | Endianness is a parameter via `Binary.Endianness`, not a sibling format dimension. Per-endianness protocols would create a compile-time selection mechanism competing with the existing runtime enum — over-modeled. Codified at convention §5 + §7. |

**Implication**: the family-Codable convention v1.0.0 is **structurally insufficient as written** for byte-stream formats, but the gap is bounded and the correct framing is the two-shape catalog with split shape for byte streams (per [FAM-005] codified in v1.1.0). Both shapes follow the structural rules (sibling-not-refinement, method-based, no-associatedtype, format-natural Optional, format-specific accessor). This is NOT a class-(c) escalation per the supervisor block — it does not require modifying the canonical attachment protocols or the convention's structural argument. It is an additive clarification.

**Status**: RECOMMENDED-FOR-MIGRATION (convention doc amendment v1.1.0 — landed) + DEFERRED-PENDING-EMPIRICAL-VALIDATION (the `Binary.Parseable` peer must be authored to complete the split-pair empirical baseline).

### 2. G2 — Stdlib lock-in via canonical conformances

**Empirical scope** (workspace grep, filtered to canonical pinnings only):

```
swift-primitives/swift-ascii-parser-primitives/.../FixedWidthInteger+Parseable.swift:11:
  extension Int: ASCII.Parseable, @retroactive Parseable {
swift-primitives/swift-ascii-parser-primitives/.../FixedWidthInteger+Parseable.swift:15:
  extension UInt: ASCII.Parseable, @retroactive Parseable {
swift-primitives/swift-ascii-serializer-primitives/.../FixedWidthInteger+Serializable.swift:8:
  extension Int: @retroactive Serializable {
swift-primitives/swift-ascii-serializer-primitives/.../FixedWidthInteger+Serializable.swift:12:
  extension UInt: @retroactive Serializable {
swift-primitives/swift-binary-primitives/.../Binary.Serializable.swift:307:
  extension Array: Binary.Serializable where Element == UInt8 {
swift-primitives/swift-binary-primitives/.../Binary.Serializable.swift:347:
  extension ArraySlice: Binary.Serializable where Element == UInt8 {
```

**Classification**:

| # | Conformance | Class | Disposition |
|---|---|---|---|
| 1 | `Int: @retroactive Parseable` (ASCII pin) | Canonical lockout | RECOMMENDED-FOR-MIGRATION — Φ.3 covers (`ascii-codable-unification.md:309–319`) |
| 2 | `UInt: @retroactive Parseable` (ASCII pin) | Canonical lockout | RECOMMENDED-FOR-MIGRATION — Φ.3 covers |
| 3 | `Int: @retroactive Serializable` (ASCII pin) | Canonical lockout | RECOMMENDED-FOR-MIGRATION — Φ.3 covers |
| 4 | `UInt: @retroactive Serializable` (ASCII pin) | Canonical lockout | RECOMMENDED-FOR-MIGRATION — Φ.3 covers |
| 5 | `Array<UInt8>: Binary.Serializable` | Format-sibling conformance (NOT canonical lockout — `Binary` IS a format namespace, sibling at L1) | CONFIRMED |
| 6 | `ArraySlice<UInt8>: Binary.Serializable` | Same as #5 | CONFIRMED |

Of the 13 raw grep hits in the unfiltered output (`Plist.Serializable` ×7, `XML.Serializable` ×6 over stdlib types), all 13 are format-namespaced siblings (NOT canonical lockouts) — they validate the convention rather than violate it.

**Genuine canonical-lockout scope: 4 entries**, all on Φ.3's migration path. After Φ.3 lands the stdlib-integer pins move from canonical `Serializable`/`Parseable` to `ASCII.Serializable`/`ASCII.Parseable` (non-refining siblings), unblocking `Int: Binary.Parseable` (post-authoring of the new peer) and `Int: MessagePack.Serializable` / `MessagePack.Parseable` futures.

**Status**: CONFIRMED scope (4 entries) + RECOMMENDED-FOR-MIGRATION (already on Φ.3 plan). No new dispatch required from this investigation.

### 3. G3 — Bidirectional ASCII cross-check against multi-format pressure

The Φ plan was analysed against the forcing-function pressure of a second non-trivial format-Codable (G1's Binary split-pair sibling candidate — `Binary.Parseable` + enhanced `Binary.Serializable`). Per-phase brittleness check:

| Phase | Decision | Brittle under second-format? |
|---|---|---|
| Φ.1 | Author non-refining `ASCII.Serializable`; drop `ASCII.Parseable`'s refinement of `Parser_Primitives_Core.Parseable` | No — directly unblocks second-format adoption |
| Φ.2 | Re-author `ASCII.RawRepresentable`, `ASCII.Wrapper`, literal defaults on the new sibling | No — orthogonal to second-format (ASCII-specific ergonomics) |
| Φ.3 | Stdlib integer conformances: drop canonical `@retroactive Serializable` / `@retroactive Parseable` pins; conform to ASCII-namespaced siblings only | No — this IS the path-clearance for second-format |
| Φ.4 | Re-author StringProtocol bridge | No — orthogonal |
| Φ.5 | Verify consumers (workspace-grep) | No — orthogonal |
| Φ.6 | Resolve residual family-codable items | No — orthogonal |
| Φ.7 | DELETE `Binary.ASCII.Serializable` legacy | No — orthogonal |

**Status**: CONFIRMED. No Φ decision becomes brittle under second-format pressure. Φ EXISTS to clear the path; the path-clearance is structurally forward-compatible.

### 4. G4 — User-type multi-format ergonomics

Three options the brief named:

**Option (a) — Manual per-format conformances**

```swift
extension User: JSON.Serializable { /* serialize/deserialize body */ }
extension User: Plist.Serializable { /* serialize/deserialize body */ }
extension User: Binary.Serializable, Binary.Parseable { /* serialize/parse with endianness param */ }
```

Analysis:
- **Pros**: each conformance is explicit about its format-natural representation (Int → JSON.number vs Plist.integer vs Binary little-endian bytes); no compiler magic; transparent to readers.
- **Cons**: for a user-type with N fields and M formats, the conformance body is O(N) per format = O(NM) total. At N=20 fields × M=4 formats = 80 method bodies. Maintenance cost is real.
- **Verdict**: structurally correct floor. Always available. Recommended for types with 1–2 formats OR types whose representation differs substantively per format (e.g., a `Currency` type that encodes as JSON string vs Binary fixed-width integer vs Plist real).

**Option (b) — Per-format macros (`@JSONCodable`, `@PlistCodable`, `@MessagePackCodable`, ...)**

```swift
@JSONCodable
@PlistCodable
@BinaryCodable    // one macro covering both Binary.Serializable + Binary.Parseable
struct User: Sendable { var name: String; var age: Int }
```

Analysis:
- **Pros**: each macro synthesises ONE sibling's conformance; conformances compose at the macro-decorator level; per-format representation choices remain visible per macro (the macro author picks format-natural defaults for each format's null-handling, integer-encoding, string-encoding). User overrides per macro (`@JSONCodable(optional: .omit)`) work cleanly because each macro's parameter surface is its own.
- **Cons**: N macros required (one per format). The institute's macro infrastructure (swift-dual, swift-defunctionalize, swift-witness, swift-html-rendering) demonstrates capacity, but each macro is a separate authoring effort.
- **Structural alignment**: this option matches the convention's *"each format has its own slot"* principle exactly. Each macro corresponds to one sibling protocol.
- **Verdict**: structurally correct fit for types with 3+ formats AND uniform memberwise structure across formats. Recommended.

**Option (c) — Cross-format synthesis macro (`@MultiFormatCodable(formats: [.json, .plist, .binary])`)**

```swift
@MultiFormatCodable(formats: [.json, .plist, .messagepack])
struct User: Sendable { var name: String; var age: Int }
```

Analysis:
- **Pros**: single decorator; one parameter site (the format list).
- **Cons**: format-natural representation choices either get baked into the macro's defaults (lossy — Currency can't override per-format) OR get exposed as macro parameters (verbose — `@MultiFormatCodable(formats: [...], jsonOptional: .nullSentinel, binaryOptional: .omit, ...)`). The latter shape is structurally equivalent to option (b) with worse ergonomics.
- **Architecture concern**: this option re-introduces Foundation Codable's failure mode — a single decorator commits the type to one synthesis path. The convention's *"sibling-not-refinement"* rule explicitly rejects this because format-specific representation is a type-author decision, not a one-shot macro decision.
- **Verdict**: REJECTED on structural-correctness grounds. Aliasing one decorator over multiple per-format macros is a packaging convenience, not a separate architecture.

**Recommendation (principal decision, 2026-05-14)**: adopt option (a) ONLY at this time. Both option (b) and option (c) are DEFERRED.

1. **Option (a) is the sole synthesis strategy at this time**. Manual per-format conformances. The convention does not require, recommend, or anticipate macros in its current revision.
2. **Option (b) is DEFERRED** to a future arc. Trigger condition: empirical measurement of manual-conformance cost (lines authored, error rate, drift between conformance bodies) on at least one user-defined type carrying 3+ siblings shows the cost is materially limiting adoption. Speculative pre-authoring is forbidden.
3. **Option (c) remains REJECTED** on structural grounds (single-decorator commits the type to one synthesis path, re-introducing Foundation Codable's lockout). The rejection holds regardless of timing.

**Rationale for deferring (b)**: macros are tooling, not structure. The convention's correctness does not depend on them — `JSON.Serializable`, `Plist.Serializable`, `XML.Serializable` already shipped manually and the manual cost was empirically tolerable. The "second format-Codable" forcing function (G1) can be tested without macros. Macros are easier to add later than to remove; pre-authoring commits the convention to a specific synthesis shape that might not match what users actually need once a non-trivial conformer corpus exists. Apple's Codable-successor proposal includes per-format macros (§8.0) — when that proposal lands a formal Evolution pitch, the institute MAY adopt or align with that macro shape rather than authoring an independent one.

**Cost honesty**: for a user-type with N fields × M formats, option (a) is O(NM) hand-written lines. At N=20 fields × M=4 formats = 80 method bodies, this is real. The deferral bets that current consumer demand sits well below that threshold (the existing N=3 production siblings cover stdlib primitives only, which are typically 4–10 lines per format per type — tractable).

The brief MUST-NOT clause (*"do not recommend sibling-type workarounds for protocol-level questions"*) is honoured: this deferral operates at the conformance-generation layer, not the protocol-shape layer. The structural call (siblings-not-refinements) is independent of the synthesis strategy and stands regardless of macros.

**Status**: RECOMMENDATION. Manual conformances only at this time. (b) and (c) DEFERRED with explicit trigger conditions.

### 5. G5 — W2 combinator catalog at user-level

**Current state**: combinators (`Serializer.Sequence`, `Serializer.Many.Separated`, `Serializer.Optionally`, etc.) live in `swift-serializer-primitives` as leaf-coder infrastructure. They are NOT exposed as user-level conformance-authoring APIs in the existing tree-format siblings.

**Empirical observation**: tree-format siblings (JSON, Plist, XML) use method-call composition naturally:

```swift
// JSON.Serializable conformance body — tree builder via method calls
static func serialize(_ value: User) -> JSON {
    .object(["name": value.name.json, "age": value.age.json])
}
```

Byte-stream siblings (Binary.Serializable + Binary.Parseable split pair) would benefit from combinator composition because byte order and field ordering matter:

```swift
// Hypothetical Binary.Serializable conformance — combinator-based; endianness as runtime parameter
static func serialize<Buffer: RangeReplaceableCollection>(
    _ value: User, endianness: Binary.Endianness, into buffer: inout Buffer
) where Buffer.Element == UInt8 {
    UInt32.serialize(value.id, endianness: endianness, into: &buffer)
    String.LengthPrefixed.serialize(value.name, into: &buffer)
    Int64.serialize(value.age, endianness: endianness, into: &buffer)
}
```

The combinator shape mirrors the existing leaf-serializer infrastructure (`ASCII.Decimal.Serializer<T>` is a `Serializer.Protocol` conformer; combinators are higher-order builders). For byte-stream formats the ordering is essential, and the builder DSL is a natural fit.

**Conditional recommendation**:
- **Tree-intermediate siblings** (JSON, Plist, XML): method-call composition is sufficient and concise. Combinators MAY be introduced for ergonomic builders (`JSON.Object.Builder { ... }`) but are not load-bearing.
- **Byte-stream siblings** (Binary, MessagePack, CBOR): combinator-based authoring is recommended for non-trivial conformances. The convention should provide `Serializer.Sequence`-style builders as the canonical user-level API.

**Realistic user-type examples**:

| Format | Conformance body shape |
|---|---|
| `Currency: JSON.Serializable` | Method body: `.string("\(amount) \(code)")` (4 LOC) |
| `Currency: Binary.Serializable, Binary.Parseable` | Method body with endianness parameter; field-by-field composition (5–8 LOC per direction; readable, reorderable) |
| `Currency: Binary.Serializable, Binary.Parseable` (manual byte-append, no helpers) | Manual byte-append (10–20 LOC per direction; error-prone for non-trivial layouts) |

**Status**: RECOMMENDATION. Combinators are recommended at user-level for byte-stream conformances; method bodies remain idiomatic for tree-intermediate conformances. The decision per-format is the sibling author's call; the convention SHOULD codify the heuristic (intermediate-shape → composition strategy) rather than mandate one path.

### 6. CROSS-1 — Language-mechanism premise (associated-type-trap)

The family-Codable convention's *"siblings, not refinements"* recommendation is structurally correct ONLY IF siblings carry no `associatedtype` OR carry `@_implements` stamps at every conformer site. The blog post `2026-04-20-associated-type-trap.md` documents the load-bearing language mechanism: Swift's `AssociatedTypeDecl::getAssociatedTypeAnchor` (in `lib/AST/Decl.cpp`) unifies same-named associated types across protocols a single type conforms to. The unification is unconditional — SE-0491 module selectors, `@retroactive`, and `MemberImportVisibility` do NOT disambiguate.

**Audit of the convention's protocols**:

| Protocol | `associatedtype`? | At-risk? |
|---|---|---|
| `JSON.Serializable` (`JSON.Serializable.swift:94`) | NO — method-only | Safe |
| `Plist.Serializable` (`Plist.Serializable.swift:3`) | NO — method-only | Safe |
| `XML.Serializable` (`XML.Serializable.swift:36`) | NO — method-only | Safe |
| `Binary.Serializable` (`Binary.Serializable.swift:37`) | NO — method-only (generic on `Buffer` at the static method level, not protocol level) | Safe |
| `Coder_Primitives.Codable` (canonical, `Codable.swift:26`) | YES — `associatedtype Coder: Coder_Primitives.Coder.Protocol` | Latent risk |
| `Parser_Primitives_Core.Parseable` (canonical, `Parseable.swift:19`) | YES — `associatedtype Parser: Parser_Primitives_Core.Parser.Protocol` | Latent risk |
| `Serializer_Primitives_Core.Serializable` (canonical, `Serializable.swift:19`) | YES — `associatedtype Serializer: Serializer_Primitives_Core.Serializer.Protocol` | Latent risk |

**Three canonical attachment protocols carry `associatedtype`**. The risk is LATENT, not active, because:
1. Canonical attachment is reserved for *spec-value types* with one inherent canonical codec (`family-codable-convention.md:104`).
2. Spec-value types are sparse — `RFC_8259.Value` is the only current conformer of `Coder_Primitives.Codable`.
3. By definition, a spec-value type with one inherent canonical codec does NOT conform to a second canonical-attachment sibling — the anchor-unification trap requires two same-named associatedtype slots on one type.

**Activation scenario** (hypothetical): if a spec-value type ever needs two canonical codecs — e.g., `RFC_8259.Value` conforming both to `Coder_Primitives.Codable` (`Coder = JSON.Coder`) AND to a hypothetical `MessagePack_Primitives.Codable` (`Coder = MessagePack.Coder`) where both protocols declare `associatedtype Coder` — the anchor-unification mechanism would force `RFC_8259.Value.Coder` to a single concrete type. JSON.Coder ≠ MessagePack.Coder; the constraint is unsatisfiable.

**Mitigation if scenario activates**:
- Local fix (per blog post): `@_implements(Coder_Primitives.Codable, Coder)` + `@_implements(MessagePack_Primitives.Codable, Coder)` stamps at the conformer site. The stamps split the requirements; both bindings co-exist. This is the production pattern documented in the blog (`HTML.Document` carrying two `Body` requirements via two `@_implements` stamps).
- Per the blog: `BASELINE_LANGUAGE_FEATURE(AssociatedTypeImplements, 0, ...)` — always-on baseline; stable in practice; underscored in status.

**Class-(c) escalation check**: the supervisor block specifies *"ask: if the investigation surfaces a class-(c) ecosystem question that would require modifying the canonical attachment protocols themselves (e.g., 'Codable/Serializable/Parseable should drop their associatedtype's'), STOP and escalate to the user."* This investigation does NOT recommend that. The canonical attachment protocols' `associatedtype` is deliberate — it expresses "this type has one inherent canonical codec" via the type system. Dropping it would weaken the canonical-attachment contract. The recommendation is to **codify the latent risk + the local `@_implements` escape hatch** in the convention doc, NOT to revise the protocols.

**Recommendation for convention doc amendment**:
1. Add an explicit §X *"Language-mechanism premise"* section citing the associated-type-trap blog post.
2. Codify the structural rule: *"Format-specific sibling attachment protocols MUST NOT carry `associatedtype` requirements. Canonical attachment protocols MAY carry `associatedtype` requirements because they are reserved for spec-value types with one inherent canonical codec."*
3. Document the `@_implements` escape hatch for the latent-risk scenario.
4. NO action on the canonical attachment protocols themselves.

**Status**: CONFIRMED (load-bearing premise; latent risk on canonical-attachment associatedtype is bounded by sparse-use; local escape hatch documented).

### 7. CROSS-2 — V4 D naming-convention finding

**Empirical fact** (from `double-json-binary-dual-conformance` experiment, 2026-05-14, CONFIRMED in debug + release):

```swift
let mystery = Double.serialize(3.14)   // No return-type context
// → type(of: mystery) == JSON.self     (NOT ambiguity error)
```

Swift's overload resolution favours JSON.Serializable's non-generic `static serialize(_:) -> JSON` over Binary.Serializable's generic protocol-extension `static serialize<Bytes>(_:) -> Bytes where Bytes: RangeReplaceableCollection<UInt8>`. Deterministic, not ambiguous — but surprising.

**Disambiguation surface (V4 A/B/C)**:

| Context | Selected | Pattern |
|---|---|---|
| `let x: JSON = T.serialize(v)` | JSON.Serializable | Return-type-as-JSON |
| `T.serialize(v, into: &buf)` | Binary.Serializable | `into:` parameter |
| `let x: [UInt8] = T.serialize(v)` | Binary.Serializable | Return-type-as-`[UInt8]` |

Three orthogonal disambiguation paths exist; consumers do not need fully-qualified calls.

**Empirical naming in the workspace** (consistent across siblings):

| Sibling | Type-level entry | Instance accessor |
|---|---|---|
| JSON.Serializable | `serialize(_:)` / `deserialize(_:)` | `.json: JSON` |
| Plist.Serializable | `serialize(_:)` / `deserialize(_:)` | `.plist: Plist` |
| XML.Serializable | `serialize(_:)` / `deserialize(_:)` | `.xml: XML` |
| Binary.Serializable | `serialize<Buffer>(_:, into:)` / `.bytes` (extension) | `.bytes: [UInt8]` |

The convention ALREADY follows the empirical practice: type-level entries share the `serialize`/`deserialize` name; instance accessors are format-specific.

**Recommendation for convention doc amendment**:
1. Codify the type-level naming rule: *"Sibling protocols MAY use `serialize` / `deserialize` as the static requirement names. Consistency across siblings is desirable; format-specific naming at the type-level (`asJSON(_:)` etc.) is not required."*
2. Codify the instance accessor rule: *"Sibling protocols MUST provide format-specific instance accessors (`.json`, `.plist`, `.xml`, `.bytes`, future `.msgpack`) as the consumer-facing ergonomic API. These accessors are unambiguous regardless of in-scope siblings."*
3. Codify the V4 D non-generic-wins rule: *"In overloaded call sites where multiple sibling protocols are in scope and no return-type context is provided, Swift's overload resolution selects the non-generic candidate over the generic protocol-extension candidate. The selection is deterministic but surprising. Format-Codable authors using generic-extension shapes (Binary.Serializable's `serialize<Bytes>(_:) -> Bytes`) MUST provide explicit typed entry points (`Self.bytes` instance accessor) and MUST NOT rely on bare `T.serialize(v)` resolving to their protocol when other siblings are in scope."*

**Status**: CONFIRMED. Both rules already match the empirical practice; the convention doc amendment is purely codification.

### 8. External — State of the art

**Six external references, each grounding one of our structural calls. The Apple/Foundation Codable-successor proposal (§8.0) is the most load-bearing — it independently converges on the same architecture as the institute's family-Codable convention.**

#### 8.0 Apple/Foundation Codable successor proposal (Kevin Perry, March 2025) — load-bearing convergent external

[*The future of serialization & deserialization APIs*](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585), Swift Forums Evolution discussion phase, opened by Kevin Perry on 2025-03-17, still active across 9+ pages as of this writing.

Architecture (per Perry's opening post + #33 + #77 replies):

- **Format-agnostic protocols** in parallel with format-specialized protocols. Format-agnostic protocols enable "currency" types owned by frameworks/libraries to compose with application-level serialisable types — directly addressing the structural problem the institute calls *spec-value types with one inherent canonical codec*.
- **Format-specialized protocols** (`JSONCodable`, `PropertyListCodable`, etc.) that "should have full freedom to craft their interface around each format's individual needs and specialties." Each format protocol is independent — directly the institute's *siblings, not refinements* call.
- **Per-format macros** as the synthesis strategy: "each format and specialized protocol will need to provide its own main macro." Macros enable "attribute-like macros as targeted customization mechanisms" that compiler-built Codable synthesis could not.
- **Rust Serde-inspired visitor pattern**: "the parser drives the deserialization process instead of being required to service requests from the client" — eliminates Codable's intermediate-tree-allocation performance ceiling. The institute's JSON.Serializable event-grain `deserialize(events:)` fast path (`JSON.Serializable.swift:111`) is the structurally-equivalent shape.
- **Backward compatibility**: "we encourage all encoders and decoders to not only accept types conforming only to the new format-agnostic protocols, but also Encodable and Decodable types, if possible." Codable is expected to be "largely supplanted" long-term.

**Structural alignment with the institute's convention** (point-by-point):

| Institute's family-Codable convention | Apple Codable-successor proposal |
|---|---|
| Canonical attachment (`Coder_Primitives.Codable`) for spec-value types | "Format-agnostic protocols in parallel with the format-specialized ones … 'currency' types owned by frameworks/libraries" |
| Format-specific sibling protocols (`JSON.Serializable`, `Plist.Serializable`, `XML.Serializable`) | "Format-specialized protocols (`JSONCodable`, `PropertyListCodable`)" |
| Per-format ergonomic surface — type-author chooses representation | "Full freedom to craft their interface around each format's individual needs and specialties" |
| G4 option (b): per-format macros (`@JSONCodable`, `@PlistCodable`, ...) — **architecturally aligned, timing-deferred per §4 principal decision (2026-05-14)** | "Each format and specialized protocol will need to provide its own main macro" |
| JSON.Serializable's event-grain `deserialize(events:)` fast path | "Parser drives the deserialization process" — visitor pattern |
| Composition through canonical leaf (Coder/Parser/Serializer.Protocol) | (Not yet specified in proposal; institute is ahead here) |
| CROSS-1 `@_implements` escape hatch for canonical-attachment associatedtype trap | (Not addressed in proposal; institute has the stronger answer for spec-value types with multiple canonical codables) |
| CROSS-2 V4 D non-generic-wins call-site rule | (Not raised in proposal; institute identified empirically via dual-conformance experiment) |

**Community concerns from the thread that the institute's convention already addresses**:

- **Jon Shier**: *"how do these APIs compose together if I want the same type to support both JSON and XML serialization?"* — institute's answer: explicit conformance composition `extension Foo: JSON.Serializable, XML.Serializable, Binary.Serializable, Binary.Parseable`. Per-format macros stack as decorators. The V4 D finding (CROSS-2) documents the call-site behaviour when both are in scope; convention sidesteps via the instance-accessor rule [FAM-004].
- **fclout**: *"what does `CodingFormat(.iso8601)` mean in a property list encoder?"* — institute's answer: format-specific representation choices are per-sibling-protocol decisions, not cross-format parameters. Each macro carries its own format-natural defaults.
- **Dave DeLong**: *"99.9% of the time, developers … are doing so to a single, well-known format. Format-specific packages (`JSONCodable`, `CSVCodable`, etc.) rather than a monolithic solution"* — exact institute pattern: per-format siblings in their format-namespaced packages (`swift-json` ships `JSON.Serializable`; `swift-plist` ships `Plist.Serializable`; etc.).
- **Async/streaming concerns (YOCKOW, Bouniol)**: institute's `JSON.Span.EventStream` streaming-deserialize path (per `JSON.Serializable.swift:111` + parse-performance-architecture.md Tier-4) is the structurally-equivalent answer.
- **Cyclical references, type information (Lockwood)**: NOT addressed by either the Apple proposal or the institute's convention; remains a gap for both.

**Status of the proposal** (as of search date):

> Current phase: community feedback collection. Planned: official stdlib API pitch → swift-foundation evolution proposals for JSON and PropertyList protocols → macro definition proposals. Macro implementations remain speculative.

The proposal is in discussion phase; no formal Swift Evolution pitch has been submitted as of the search date. The institute's family-Codable convention is, in effect, an early production exploration of the same architecture Apple is proposing for Codable's successor. The Plist.Serializable, XML.Serializable, JSON.Serializable trio is the empirical N=3 baseline (§0) for the architecture.

**Implications for the institute's convention**:

1. **Strongest possible external validation** of the structural calls. Sibling-not-refinement, format-specific protocols, parser-driven visitor — three of the four are aligned with Apple's proposed direction. The fourth (per-format macros) is *architecturally* aligned but *timing-deferred* on the institute side per the §4 principal decision; if and when the institute adopts macros, the structural shape will match Apple's.
2. **Convention doc amendment SHOULD cite Apple's thread** as the external SoA anchor; this Research doc's §8.0 is sufficient citation pending the amended `family-codable-convention.md` v1.1.0.
3. **Where the institute is ahead**: CROSS-1 `@_implements` escape hatch, CROSS-2 V4 D empirical validation, composition through canonical leaf, N=3 production siblings already shipping. These are not addressed in the Apple proposal and are the institute's distinctive contribution.
4. **Where Apple's proposal may be ahead**: (a) the visitor-pattern API surface for streaming deserialization — the institute has `JSON.Span.EventStream` for JSON, but the cross-format equivalent (a single visitor abstraction usable from any format) is not yet specified in the convention; (b) per-format synthesis macros — Apple's proposal includes them as a first-class feature, while the institute has deferred per §4 principal decision. When Apple's formal pitch lands, the institute SHOULD review both surfaces for adoption.
5. **Risk to the institute**: if Apple's proposal lands and ships in Foundation as the canonical Swift serialization story, the institute's convention competes with stdlib. The institute's asymmetric advantage is the empirical anchor (N=3 production siblings, dual-conformance experimental validation, ~1 year of production use across the JSON / Plist / XML cluster). The institute's weaker point is naming overlap (Apple's `JSONCodable` vs institute's `JSON.Serializable` — different sibling names for the same architecture) AND the missing macro surface. Naming convergence and macro adoption are candidate skill-lifecycle items once Apple's pitch lands.

**Sources**: [Apple/Foundation Codable successor thread (page 1)](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585), [#33 reply](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585/33), [#77 reply](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585/77), [Michael Tsai's blog summary](https://mjtsai.com/blog/2025/03/26/the-future-of-swift-serialization-and-deserialization-apis/).



#### 8.1 Rust serde — the canonical multi-format encoding ecosystem

Architecture: two traits (`Serialize`, `Deserialize`) on the data side; two traits (`Serializer`, `Deserializer`) on the format side. The Serde data model categorises every Rust data type into one of 29 possible types; each `Serializer` trait method corresponds to one data-model type. Format crates (`serde_json`, `serde_yaml`, `serde_messagepack`, `bincode`) implement the format-side traits; user types derive `#[derive(Serialize, Deserialize)]` once and work across all formats automatically.

**Comparison to our convention**:
- **Same call**: serde's `Serialize` is conceptually our `Codable` canonical attachment — one trait, format-independent. Both express "this type knows how to be encoded."
- **Opposite call**: serde DOES use a single trait per direction with format-INSTANCE dispatch (the `Serializer` trait parameter at call time picks the format). Our convention REJECTS this in favour of per-format sibling protocols at type-author level. The structural difference reflects a different bet: serde bets that types HAVE one canonical Serde-data-model encoding and format crates handle the format-specific representation. Our convention bets that types DO NOT have one canonical encoding — `Int` is JSON-numeric AND ASCII-decimal AND little-endian-binary simultaneously, and the type author should choose per format.
- **Why we deviated**: serde works because Rust's type system lacks Swift's same-named-associated-type-anchor mechanism. Rust traits with the same name from different crates are nominally distinct (different `TypeId`s); the trait-bounded dispatch always picks the right one. Swift's `associatedtype` anchor unification (per CROSS-1) makes the serde pattern structurally harder in Swift — Foundation Codable hit exactly this trap (single `Codable` protocol → one encoding per type → format-specific representation choices baked into the Encoder/Decoder dispatch layer).
- **Derive macro lesson**: serde's `#[derive]` macro is the dominant ergonomic win. Its synthesis works because the trait does not encode format-specific representation choices — the format crate decides. Our convention's per-format-macro recommendation (G4 option (b)) is the analogous shape under our structural constraints; serde's cross-format `#[derive]` is the structurally-different shape.

**Sources**: [Serde overview](https://serde.rs/), [Serializer trait](https://docs.rs/serde/latest/serde/ser/trait.Serializer.html), [data model](https://serde.rs/data-model.html).

#### 8.2 Haskell type-class encoding libraries (aeson, cassava, binary, cereal, yaml)

Architecture: each format gets its own type class (`Aeson.ToJSON`/`FromJSON`, `Cassava.ToRecord`/`FromRecord`, `Binary.Binary`, `Cereal.Serialize`, `Yaml.ToJSON`). User types define one `instance ToJSON Foo where ...` per format.

**Comparison**: Haskell's pattern is EXACTLY our sibling-not-refinement convention. Each library's type class is independent; types compose conformances by declaring multiple instances. The trap we worried about (same-named associated types unifying) does not fire because Haskell type classes with the same name from different libraries are nominally distinct (the library namespace is part of the class identity).

**Quote from Haskell community thread**: *"The fundamental issue is that Haskell doesn't natively admit a way to express 'try this constraint, and if it fails, try this other constraint'. This makes supporting multiple serialization formats simultaneously (aeson, cereal, binary, yaml) challenging with a single type class instance approach."* — confirms the structural call we made (don't try; each format is its own class) is the same call Haskell made.

**Lesson for CROSS-1**: the trap is Swift-specific (associated-type-anchor unification is a Swift compiler choice). Haskell-style independent type classes — which our siblings model — are the structurally-correct shape under both type systems. The blog post's `@_implements` escape hatch is Swift's way of recovering the Haskell property locally.

**Source**: [aeson docs](https://hackage-content.haskell.org/package/aeson-2.2.5.0/docs/Data-Aeson.html); [community discussion](https://www.iankduncan.com/engineering/2023-08-29-one-serialization-class-to-rule-them-all).

#### 8.3 Foundation Codable (SE-0166, SE-0167) — the architecturally-opposite call

Architecture: single protocol `Codable = Encodable + Decodable`. One `encode(to:)` requirement per type; format-specific dispatch happens INSIDE the `Encoder`/`Decoder` instances (JSONEncoder, PropertyListEncoder, future YAMLEncoder, ...). Synthesis is built into the compiler — `Codable` conformance is auto-synthesized for memberwise types.

**Comparison to our convention**:
- **Opposite call**: Codable bets that types HAVE one canonical encoding (the `CodingKey`-keyed memberwise shape) and that format-specific representation choices live in the encoder/decoder. The convention REJECTS this.
- **Synthesis win**: Codable's compiler-built synthesis is the dominant ergonomic feature — users get conformance for free. Our convention has no equivalent; G4's per-format-macro recommendation is the path toward parity, but each macro is a separate authoring effort.
- **Codable's known costs**:
  - Format-specific representation choices are baked into the Encoder/Decoder, not type-author-visible. A type that should encode as JSON `{ "x": 1 }` but Binary `[0x01]` cannot express this through Codable — the type-author writes ONE `encode(to:)` body using `CodingKey`s, and the format decision is one-way (the Encoder picks).
  - The Foundation Codable's `JSONEncoder.OutputFormatting` / `DateEncodingStrategy` / `KeyEncodingStrategy` are the workaround surface — they let consumers override per-format behaviour at the call site, not at the type-author site. The convention's per-format sibling moves these decisions to the type-author per format-natural Optional/integer/string handling — strictly more expressive.
  - The Swift Forums threads ([10207](https://forums.swift.org/t/writing-new-encoders-and-decoders/10207), [11836](https://forums.swift.org/t/codable-encoder-and-decoder-implementations-for-other-formats-yaml-xml/11836)) document the load-bearing complaint: *"there is a lot of code duplication required in order to write a new Encoder / Decoder implementation"*. The Foundation team acknowledged *"we think this can be done better, especially for the benefit of third parties"* — but the architectural call cannot be revised post-shipping. Codable's shape is locked.
- **Why we deviated**: our convention serves the case Codable cannot serve — types whose representation differs structurally per format. Currency-as-JSON-string vs Currency-as-fixed-width-bytes is the canonical example; Codable cannot express this without the type author baking one choice into `encode(to:)` (which then leaks to all encoders) or writing per-encoder workarounds (which defeat synthesis).
- **G4 macro question**: Foundation Codable solves G4 via auto-synthesis at the cost of single-canonical-encoding lockout. Our per-format-macro recommendation (G4 option b) preserves the per-format representation freedom at the cost of N macros instead of 1.

**Latent risk shared**: Codable's `associatedtype CodingKeys: CodingKey` is the same trap CROSS-1 describes — the synthesised CodingKeys binding unifies across multiple Codable conformances. Codable doesn't hit the trap because there's only ONE Codable protocol; if a future ecosystem ever wanted two `Codable`-shaped protocols (e.g., versioned Codable v1 and v2), the trap would fire.

**Sources**: [SE-0167 proposal](https://github.com/apple/swift-evolution/blob/master/proposals/0167-swift-encoders.md), [Swift Forums multi-format thread](https://forums.swift.org/t/codable-encoder-and-decoder-implementations-for-other-formats-yaml-xml/11836), [Swift Forums new-encoder thread](https://forums.swift.org/t/writing-new-encoders-and-decoders/10207).

#### 8.4 Swift Forums discussions

Three relevant threads:

1. **[Writing new Encoders and Decoders](https://forums.swift.org/t/writing-new-encoders-and-decoders/10207)** (2018-ongoing) — load-bearing complaint that custom encoders require extensive code duplication; Foundation team acknowledged the gap; community proposed intermediate-value representations (`MessagePackValue`) rather than direct encoder/decoder authoring — exactly the tree-intermediate shape our JSON/Plist/XML siblings use.
2. **[Codable encoder/decoder implementations for other formats (YAML, XML)](https://forums.swift.org/t/codable-encoder-and-decoder-implementations-for-other-formats-yaml-xml/11836)** — surfaces platform inconsistency (`PropertyListDecoder` Darwin-only) and missing YAML/XML implementations; pragmatic recommendations to use third-party libraries (`Yams`). Treats the issue as resource allocation, not architectural defect — community has not converged on a structural critique of Codable's shape.
3. **[SE-0491 (module selectors) review](https://forums.swift.org/t/se-0491-module-selectors/...)** — referenced in the associated-type-trap blog post; explicitly documents that module selectors do NOT disambiguate same-named associated types. Quote: *"a member type of a type parameter must not be qualified by a module selector ... it will always encompass both of them."* — confirms CROSS-1's load-bearing premise at the compiler-team level.

#### 8.5 Third-party Swift libraries

**Vapor `Content` protocol** ([docs](https://docs.vapor.codes/basics/content/)): conforms to `Codable`; dispatch is by HTTP content-type negotiation. `ContentEncoder` / `ContentDecoder` protocols define the encoder/decoder side. Format dispatch happens INSIDE the request handler — the consumer hands the request an `Encoder`/`Decoder` instance matching the HTTP `Content-Type` header. Same architectural shape as Foundation Codable (single Codable + per-format encoder instances), with HTTP-content-type as the dispatch criterion.

**swift-protobuf** ([API.md](https://github.com/apple/swift-protobuf/blob/main/Documentation/API.md)): generated `Message` protocol with per-format methods (`serializedBytes()` for binary, `jsonUTF8Data()` for JSON). This is the closest external analog to our per-format sibling shape — each format has its own method on the generated type. Differences: (1) protobuf's `Message` is a single protocol, not multiple siblings; (2) the format dispatch is method-name (`jsonUTF8Data()` vs `serializedBytes()`) not protocol-conformance; (3) `Message` is restricted to types in proto schema files — not a general user-type ergonomics layer.

**Apollo iOS `JSONEncodable`** ([docs](https://www.apollographql.com/docs/ios/v0-legacy/api/Apollo/protocols/JSONEncodable)): per-format protocol explicitly named `JSONEncodable` (matching our `JSON.Serializable` sibling shape, naming-convention-wise). Apollo iOS does NOT use Foundation's Codable for GraphQL response mapping — uses its own `SelectionSet` protocol + `GraphQLExecutor` for runtime parsing. This is a partial sibling-pattern alignment — Apollo authored one format-specific encoder protocol because Codable's shape did not fit GraphQL's needs.

**Aggregate lesson**: three Swift third-party libraries (Vapor, swift-protobuf, Apollo) demonstrate that the family-Codable convention's structural call (per-format sibling protocols, format-specific accessor names, no single canonical encoding) ALREADY exists in production Swift codebases — just not under one named convention. The institute's family-Codable convention is the explicit codification of an emergent pattern, not a novel architecture.

## Comparison

**Readiness table** (per gap, per supervisor brief format):

| Gap | Question | Status | Evidence |
|---|---|---|---|
| §0 | Empirical N? | CONFIRMED (N=3 tree-intermediate siblings) | JSON.Serializable, Plist.Serializable, XML.Serializable workspace-grep |
| G1 | Forcing-function under Binary split-pair sibling (Serializable + Parseable; endianness as parameter) | RECOMMENDED-FOR-MIGRATION (convention amendment v1.1.0: two-shape catalog landed; [FAM-005] codified) + DEFERRED-PENDING-EMPIRICAL-VALIDATION (Binary.Parseable peer to be authored) | §1 |
| G2 | Stdlib lock-in scope | CONFIRMED (4 entries) + RECOMMENDED-FOR-MIGRATION (Φ.3 covers) | §2 |
| G3 | Φ cross-check | CONFIRMED (no decision brittle) | §3 |
| G4 | User-type macro ergonomics | RECOMMENDATION (option a manual conformances ONLY at this time; options b + c DEFERRED with explicit trigger conditions — principal decision 2026-05-14) | §4 |
| G5 | Combinators at user-level | RECOMMENDATION (heuristic by intermediate-shape) | §5 |
| CROSS-1 | Language-mechanism premise | CONFIRMED (codify premise; canonical-attachment associatedtype is latent-bounded; @_implements escape hatch documented) | §6 |
| CROSS-2 | V4 D naming-convention | CONFIRMED (codify three rules — type-level shared name, instance accessor format-specific, non-generic-wins) | §7 |
| External | State of the art | CONFIRMED (institute's structural calls converge with the Apple/Foundation Codable-successor proposal of March 2025 — same dual-protocol architecture, same per-format macros, same parser-driven visitor pattern; institute is ahead on CROSS-1 `@_implements` escape hatch + CROSS-2 V4 D empirical validation + composition through canonical leaf; institute is behind on cross-format visitor abstraction. Foundation Codable made the architecturally-opposite call — single Codable + per-format encoder dispatch — at the cost of single-canonical-encoding lockout, which both the institute and Apple's successor proposal reject) | §8 |

**Forcing-function table for G1** (which currently-CONFIRMED items get re-classified under the Binary split-pair forcing function):

| Currently-CONFIRMED item | Re-classification under Binary split-pair | Why |
|---|---|---|
| Sibling shape `static serialize(_:) -> Format` | RECOMMENDED-FOR-MIGRATION (two-shape catalog: tree-builder bidirectional vs byte-appender split) | Binary has no tree intermediate; split-shape (Serializable + Parseable) reflects serialize/parse asymmetry; signature is `serialize(_:, endianness:, into: Buffer)` |
| Format-natural Optional semantics | CONFIRMED (extends naturally) | Binary's "no bytes for nil" or 1-byte sentinel matches existing `Serializer.Optionally` precedent |
| Composition through canonical leaf | CONFIRMED (extends naturally) | Binary leaf serializers/parsers compose through `Serializer.Protocol` / `Parser.Protocol` exactly like JSON.Coder composes through `Coder.Protocol` |
| Per-format accessor | CONFIRMED (`.bytes` already exists at L1) | No change needed; endianness can be passed via accessor variant or default |
| V4 D non-generic-wins rule | Becomes load-bearing | Binary's generic-extension signatures will lose to JSON.Serializable's non-generic at bare call sites — convention sidesteps via [FAM-004] instance-accessor rule (V4 D not relied upon normatively) |
| Per-endianness sibling namespaces | REJECTED per [FAM-005] | Endianness is a parameter via `Binary.Endianness`, not a sibling format dimension |

## Outcome

**Status**: RECOMMENDATION

**Conclusion**: the institute's multi-format Codable story is **structurally sound, empirically validated by N=3 production tree-intermediate siblings (JSON, Plist, XML), AND structurally convergent with the Apple/Foundation Codable-successor proposal of March 2025** (Kevin Perry et al.; §8.0). The Apple proposal explicitly names format-specialized protocols (`JSONCodable`, `PropertyListCodable`) in parallel with format-agnostic protocols, per-format macros, and parser-driven visitor patterns — three of these four structural pillars match the institute's convention. The institute is empirically ahead on three independent points (N=3 production siblings already shipping; CROSS-1 `@_implements` escape hatch identified for the canonical-attachment latent risk; CROSS-2 V4 D non-generic-wins call-site rule empirically verified via dual-conformance experiment). The institute is intentionally behind on per-format macros — the principal decision (2026-05-14) is to defer macros entirely and rely on manual per-format conformances at this time (§4). The remaining gap (cross-format visitor abstraction) is paced by Apple's proposal cadence, not by the institute. The convention v1.1.0 amendment has landed (2026-05-14); the next empirical close-out is the Binary split-pair sibling (`Binary.Parseable` NEW + enhanced `Binary.Serializable` with `Binary.Endianness` operation parameter) — endianness is a parameter, NOT a sibling format namespace per [FAM-005]. None of the eight scope items surfaces a structural defect requiring class-(c) escalation; all are codifications, additive clarifications, or follow-on arcs already on the Φ migration path.

**Multiple-conformance question — resolved.** §0a anchors the answer: yes, a single type can carry multiple sibling format-Codable conformances simultaneously; the solution is one extension per format with independent format-natural representation; both the structural argument (no associatedtype on siblings → no anchor-unification trap) and the empirical evidence (V1–V3 dual-conformance experiment + N=3 production siblings on stdlib primitives) confirm it. No remaining research question.

**Convention doc amendments needed** (RECOMMENDED-FOR-MIGRATION — author one amended `family-codable-convention.md` v1.1.0):

1. **Two-shape catalog** (§1): document tree-builder shape (`static serialize(_:) -> Format`) vs byte-appender shape (`static serialize(_:, into: inout Buffer)`); both follow the structural rules; the choice is format-natural.
2. **Language-mechanism premise** (§6): cite associated-type-trap blog; codify "sibling protocols MUST NOT carry associatedtype" rule; document canonical-attachment latent-risk + `@_implements` escape hatch.
3. **V4 D naming-convention** (§7): codify type-level `serialize`/`deserialize` shared naming, format-specific instance accessors, non-generic-wins call-site rule.
4. **G4 manual-only synthesis policy** (§4): codify option (a) manual per-format conformances as the SOLE synthesis strategy at this time; explicitly DEFER option (b) per-format macros with stated trigger conditions; explicitly REJECT option (c) cross-format synthesis on structural grounds. Principal decision 2026-05-14.
5. **G5 combinator heuristic** (§5): codify "method bodies for tree intermediates; combinators for byte streams" recommendation.
6. **External SoA citation** (§8.0): cite the Apple/Foundation Codable-successor proposal as the convergent external anchor; cite Plist.Serializable and XML.Serializable as N=2 + N=3 empirical-baseline siblings (the J1d header currently anchors only on JSON.Serializable as the exemplar; the broader convergent evidence is load-bearing for the convention's external defensibility).
7. **Multiple-conformance worked example** (§0a): codify the structural answer (one extension per format with independent format-natural representation) + worked code example + call-site disambiguation rule (format-specific instance accessors). This consolidates threads currently scattered across §0 / §6 / §7 into one cited answer-section.

**Φ migration items** (already in flight, no new dispatch — reference only):

- Φ.1 (author ASCII.Serializable + drop ASCII.Parseable refinement)
- Φ.3 (migrate stdlib integer canonical pinnings)

These two clear all G2 canonical-lockout entries on the path; the remaining Φ phases (Φ.2 ergonomic affordances, Φ.4 StringProtocol bridge, Φ.5 consumer verify, Φ.6 residual cleanup, Φ.7 DELETE legacy) are orthogonal to multi-format readiness.

**Empirical-validation prerequisite**: the Binary split-pair sibling MUST ship — specifically `Binary.Parseable` (NEW peer to be authored, parallel to `ASCII.Parseable`) plus the existing `Binary.Serializable` enhanced with the `endianness: Binary.Endianness` operation parameter — before items marked DEFERRED-PENDING-EMPIRICAL-VALIDATION in §1 can be elevated. Paper analysis covers the structural call; actual conformer authoring will surface ergonomic refinements (per-field encoding strategies, length-prefix conventions, error-type granularity) that this Research doc cannot pre-resolve.

**Ordered execution sequence** (this doc does NOT dispatch any work):

1. Φ.1 + Φ.3 (clears canonical-pin lockouts; unblocks per-stdlib-type adoption)
2. Convention doc amendment (`family-codable-convention.md` v1.1.0) — codifies §1 two-shape catalog, §6 language-mechanism premise, §7 V4 D rules, §4 manual-only synthesis policy, §5 combinator heuristic, §8.0 Apple-proposal citation + N=3 empirical baseline, §0a multiple-conformance worked example
3. Author `Binary.Parseable` (new L1 protocol parallel to `ASCII.Parseable`) AND enhance existing `Binary.Serializable` with the `endianness: Binary.Endianness` operation parameter — empirically validates §1 DEFERRED items; serves as the byte-stream empirical anchor. Conformances on stdlib primitives (Int, UInt, String, Optional, Array<UInt8>) are hand-written per the manual-only policy. Endianness is a parameter, NOT a sibling format namespace per [FAM-005].
4. Promote this Research doc from `swift-json/Research/` to `swift-institute/Research/` per [RES-002a] (second non-trivial format-Codable lands → promotion trigger fires per `family-codable-convention.md:204–205`)
5. CROSS-1 latent-risk: passive — no action unless a spec-value type ever needs two canonical codables; if so, apply `@_implements` per blog post
6. **Monitor Apple proposal**: when Apple's Codable-successor pitch transitions from discussion to formal Swift Evolution pitch, the institute SHOULD review the visitor-protocol shape, naming alignment (institute's `JSON.Serializable` vs proposal's `JSONCodable`), and the macro definition surface for potential adoption or alignment work. The institute's no-macros-now decision (§4) means Apple's macro shape is candidate-for-adoption rather than candidate-for-comparison. This is NOT a dispatched arc — it's a passive watch driven by Apple's proposal cadence. Triggers a separate handoff if the proposal materially diverges from §8.0's architecture summary or if the macro question re-opens per §4 deferral trigger conditions.

**Deferred** (not on the execution sequence; trigger conditions named per §4):

- G4 option (b) per-format macros — DEFERRED until empirical measurement of manual-conformance cost on at least one user-defined type carrying 3+ siblings shows the cost is materially limiting adoption, OR until Apple's Codable-successor formal pitch lands with a macro shape worth aligning to. Whichever comes first.

**Class-(c) escalation check** (per supervisor block):

- Does the investigation require modifying canonical attachment protocols themselves? **NO**. CROSS-1's recommendation is to codify the language-mechanism premise + document the `@_implements` escape hatch, NOT to drop `associatedtype` from canonical attachments. The associatedtype is deliberately load-bearing for the canonical-attachment contract (single-canonical-codec semantics).
- Does G1's forcing-function reveal a blocking defect in the convention? **NO**. The two-shape catalog is an additive clarification; the convention's structural argument (sibling-not-refinement, top-level naming-symmetry, composition through canonical leaf, format-natural Optional, format-specific accessors) holds under both tree-intermediate and byte-stream shapes.

**Both class-(c) triggers are clear**.

**Implementation state**:

| Element | Status | Evidence |
|---|---|---|
| Multi-format Codable N≥3 empirical baseline | CONFIRMED | JSON.Serializable, Plist.Serializable, XML.Serializable workspace-grep (§0) |
| Dual-conformance experiment (V1–V4) | CONFIRMED | `swift-foundations/swift-json/Experiments/double-json-binary-dual-conformance/Sources/double-json-binary-dual-conformance/main.swift` (2026-05-14) |
| G1 forcing-function analysis (Binary split-pair: Serializable + Parseable; endianness as parameter) | RECOMMENDED-FOR-MIGRATION (convention amendment v1.1.0 landed; [FAM-005] codified) | §1 |
| G2 canonical-lockout scope (4 entries) | CONFIRMED + RECOMMENDED-FOR-MIGRATION (Φ.3) | §2 |
| G3 Φ cross-check | CONFIRMED (no brittle decision) | §3 |
| G4 user-type synthesis strategy | RECOMMENDATION (option a manual-only at this time; b + c deferred per principal decision 2026-05-14) | §4 |
| G5 combinator user-level heuristic | RECOMMENDATION (intermediate-shape conditional) | §5 |
| CROSS-1 language-mechanism premise | CONFIRMED (codify + @_implements escape hatch) | §6 |
| CROSS-2 V4 D naming-convention rules | CONFIRMED (codify three rules) | §7 |
| External SoA grounding | CONFIRMED (Rust serde, Haskell aeson, Foundation Codable, Vapor Content, swift-protobuf, Apollo JSONEncodable) | §8 |

**Promotion trigger**: per `family-codable-convention.md:204–205`, this Research doc lives in `swift-json/Research/` until a second non-trivial format-Codable lands empirically, at which point it promotes to `swift-institute/Research/` per [RES-002a]'s "multiple packages, no clear owner, or spanning layers" criterion. The convention doc amendment (`family-codable-convention.md` v1.1.0) is the dispatched follow-up; the actual second-format implementation is a separate arc.

## References

**Primary internal sources**:

- `swift-foundations/swift-json/Research/family-codable-convention.md` v1.0.0 (RECOMMENDATION, 2026-05-14, commit `8c7a981`) — anchor convention doc
- `swift-foundations/swift-ascii/Research/ascii-codable-unification.md` v1.0.0 (RECOMMENDATION, 2026-05-14) — Φ migration plan
- `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` — language-mechanism premise for CROSS-1
- `swift-foundations/swift-json/Experiments/double-json-binary-dual-conformance/Sources/double-json-binary-dual-conformance/main.swift` (2026-05-14) — V1–V4 empirical validation; CROSS-2 V4 D origin
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` (commit `0307edc`, J1d) — convention exemplar (`:94–129`)
- `swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift` — second tree-intermediate sibling (§0)
- `swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift` — third tree-intermediate sibling (§0)
- `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift` — L1 byte-stream sibling at `:37`
- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:26` — canonical attachment with `associatedtype` (CROSS-1 audit)
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:19` — canonical attachment with `associatedtype`
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19` — canonical attachment with `associatedtype`
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift:11,15` — G2 canonical lockouts
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift:8,12` — G2 canonical lockouts

**Skills + user-memory anchors**:

- Convention skill: `swift-institute/Skills/research-process/SKILL.md` ([RES-002], [RES-002a], [RES-003], [RES-003c], [RES-018], [RES-022])
- Handoff skill: `swift-institute/Skills/handoff/SKILL.md` ([HANDOFF-021], [HANDOFF-047])
- Supervise skill: `swift-institute/Skills/supervise/SKILL.md` ([SUPER-002], [SUPER-011])
- User memory: `project_parser_serializer_coder_system_framing.md` — framing memo locking in sibling-not-refinement
- User memory: `feedback_no_sibling_type_workarounds.md` — honoured in §4 (G4 macros operate at conformance-generation, not at protocol-shape)
- User memory: `feedback_correctness_and_evergreen.md` — honoured throughout (structural correctness + evergreen, not [RES-018] consumer-demand thresholds)

**External sources** (per supervisor brief's State of the Art requirement):

- **§8.0 Apple/Foundation Codable successor proposal (most load-bearing)**:
  - [The future of serialization & deserialization APIs](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585) — Swift Forums Evolution discussion, Kevin Perry, 2025-03-17 → ongoing (9+ pages)
  - [Reply #33](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585/33) — format-specialized-protocols discussion
  - [Reply #77](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585/77) — currency-types problem + format-agnostic-protocols introduction
  - [Michael Tsai blog summary](https://mjtsai.com/blog/2025/03/26/the-future-of-swift-serialization-and-deserialization-apis/) — external recap with key quotes
- [Serde overview](https://serde.rs/), [Serializer trait docs](https://docs.rs/serde/latest/serde/ser/trait.Serializer.html), [data model](https://serde.rs/data-model.html) — Rust multi-format encoding
- [aeson Hackage docs](https://hackage-content.haskell.org/package/aeson-2.2.5.0/docs/Data-Aeson.html), [community discussion](https://www.iankduncan.com/engineering/2023-08-29-one-serialization-class-to-rule-them-all) — Haskell type-class encoding
- [SE-0167 proposal](https://github.com/apple/swift-evolution/blob/master/proposals/0167-swift-encoders.md), [SE-0166 (Codable)](https://github.com/apple/swift-evolution/blob/main/proposals/0166-swift-archival-serialization.md) — Foundation Codable
- [Swift Forums — Writing new Encoders and Decoders](https://forums.swift.org/t/writing-new-encoders-and-decoders/10207) — Codable extension pain points
- [Swift Forums — Codable encoder/decoder implementations for other formats (YAML, XML)](https://forums.swift.org/t/codable-encoder-and-decoder-implementations-for-other-formats-yaml-xml/11836) — multi-format gap
- [Swift Forums — Why do we prohibit redundant declarations of conformance](https://forums.swift.org/t/why-do-we-prohibit-redundant-declarations-of-conformance-to-a-protocol/70882) — adjacent
- [Vapor Content docs](https://docs.vapor.codes/basics/content/) — single-Codable + ContentEncoder dispatch
- [swift-protobuf API.md](https://github.com/apple/swift-protobuf/blob/main/Documentation/API.md) — per-format methods on Message
- [Apollo JSONEncodable](https://www.apollographql.com/docs/ios/v0-legacy/api/Apollo/protocols/JSONEncodable) — per-format sibling-shape precedent in third-party Swift

## Appendix A — G2 raw grep transcript

Command (per [HANDOFF-021], executed at investigation start):

```bash
cd /Users/coen/Developer
grep -rn "extension \(Int\|UInt\|String\|Bool\|Double\|Float\|Array\|Dictionary\|Optional\|Date\|UUID\|Data\)[A-Za-z]*:.*\(Parseable\|Serializable\|Codable\)\b" \
  swift-primitives/*/Sources swift-foundations/*/Sources swift-standards/*/Sources 2>/dev/null \
  | grep -v "@retroactive\|JSON\.\|ASCII\.\|Binary\." | head -50
```

Raw output (13 lines):

```
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:44:extension String: Plist.Serializable {
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:61:extension Int: Plist.Serializable {
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:96:extension Double: Plist.Serializable {
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:117:extension Bool: Plist.Serializable {
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:134:extension Array: Plist.Serializable where Element: Plist.Serializable {
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:156:extension Dictionary: Plist.Serializable where Key == String, Value: Plist.Serializable {
swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:178:extension Optional: Plist.Serializable where Wrapped: Plist.Serializable {
swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:90:extension String: XML.Serializable {
swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:104:extension Int: XML.Serializable {
swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:121:extension Double: XML.Serializable {
swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:138:extension Bool: XML.Serializable {
swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:161:extension Optional: XML.Serializable where Wrapped: XML.Serializable {
swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:183:extension Array: XML.Serializable where Element: XML.Serializable {
```

Classification: all 13 entries are format-namespaced sibling conformances (`Plist.Serializable` ×7 + `XML.Serializable` ×6). NONE are canonical-attachment lockouts. The grep's `grep -v "@retroactive\|JSON\.\|ASCII\.\|Binary\."` filter excluded format prefixes `@retroactive`, `JSON.`, `ASCII.`, `Binary.` — but `Plist.` and `XML.` slipped through, surfacing exactly the §0 empirical baseline finding.

A tighter grep (excluding ALL format namespaces) returns the genuine G2 scope:

```
swift-primitives/swift-ascii-parser-primitives/.../FixedWidthInteger+Parseable.swift:11: extension Int: ASCII.Parseable, @retroactive Parseable
swift-primitives/swift-ascii-parser-primitives/.../FixedWidthInteger+Parseable.swift:15: extension UInt: ASCII.Parseable, @retroactive Parseable
swift-primitives/swift-ascii-serializer-primitives/.../FixedWidthInteger+Serializable.swift:8: extension Int: @retroactive Serializable
swift-primitives/swift-ascii-serializer-primitives/.../FixedWidthInteger+Serializable.swift:12: extension UInt: @retroactive Serializable
swift-primitives/swift-binary-primitives/.../Binary.Serializable.swift:307: extension Array: Binary.Serializable where Element == UInt8
swift-primitives/swift-binary-primitives/.../Binary.Serializable.swift:347: extension ArraySlice: Binary.Serializable where Element == UInt8
```

Lines 5–6 (Array/ArraySlice on Binary.Serializable) are NOT canonical-attachment lockouts — `Binary.Serializable` IS a format sibling (at L1, in `swift-binary-primitives`); these conformances are format-namespaced, not canonical. Genuine canonical lockouts: 4 entries (lines 1–4), all on Φ.3's migration path per `ascii-codable-unification.md:309–319`.
