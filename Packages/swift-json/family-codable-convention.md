# Family-Codable Convention

<!--
---
version: 1.2.1
last_updated: 2026-05-15
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

> **Status of this amendment (v1.2.x)**
>
> v1.2.1 (2026-06-30): **[FAM-012] parse-shape locked (minimal-B) + evergreen composition.** The parse verb **names its `Failure`**: Binary keeps a *fixed concrete* `Binary.Parse.Failure` (wire failures are structural); ASCII/text carries a per-type *rich* `associatedtype Failure` (a single fixed-per-type error is appropriately a marker associatedtype; per-call-varying Variant/Context stay witness VALUES). Dual-parse conformers (IPv4/IPv6) add an explicit `typealias Failure` as the disambiguation — an `@_implements` is equally valid (neither is forbidden; the iterator domain uses `@_implements` freely). **[FAM-001] refined**: it keeps Variant/Context off the marker for the *semantic* reason that they vary per-call (a type-level associatedtype names only one and can't be selected at the call site), NOT to avoid `@_implements`; a single fixed parse `Failure` is the one associatedtype a marker may carry. **Composition (evergreen)**: a composite's format verb composes its re-cut sub-parts' same-format **verbs** directly (`SubPart.serialize(_:into:)`) — never a `[Byte]`-detour, never reaching into a sub-part's `rawValue`. Parse-verb requirement + transitional-default removal land **seal-last**.
>
> v1.2.0 (2026-06-30): codifies **[FAM-012]** — self-contained format siblings each carry a static universal verb `serialize<Buffer: RangeReplaceableCollection>(_ value: borrowing Self, into:) where Buffer.Element == <FormatElement>` (+ dual `parse`); a type conforms to EXACTLY the siblings it has (|siblings|=1 IS "single inherent codec", |siblings|≥2 IS multi-representation, both ordinary); variants + parse-context are witness VALUES passed in (serde DeserializeSeed shape, never an `associatedtype` on the flat marker); accessors additive; the **canonical operational tier is RETIRED**; the ASCII→binary bridge is **DELETED**; sink = `RangeReplaceableCollection` default + `OutputSpan<E>` perf path. **Re-cuts [FAM-002]** (no canonical operational tier — "single inherent codec" is the degenerate |siblings|=1), **[FAM-003]** (conform exactly the spec's siblings; format-bounded generics, no canonical gate), **[FAM-005]** (variants are `Serializer.\`Protocol\`` witness VALUES); **ABSORBS [FAM-010]** (vacuous once the canonical tier is gone — nothing to refine). Principal-ratified 2026-06-30: D1 (model) + D2 **(a) full retire** — accepting the bounded `Tagged`/`Optional` per-format-forwarder fan-out and creating `JSON.Parseable` for `RFC_8259.Value`'s re-home. Full derivation + 6 build-truth probes + conformer inventory (57 conformers / 22 packages; 53 clean single-sibling re-homes): `swift-institute/Research/serialize-parse-codec-attachment-model.md` (§12).
>
> v1.1.0 (2026-05-14): adds five codified rules ([FAM-001]–[FAM-005]) plus confidence tiers, two-shape catalog, [FAM-005] sibling-namespace rule, status box, and Apple Codable-successor proposal citation.
>
> v1.1.1 (2026-05-14, same-session follow-on): adds [FAM-006] codifying the operational-vs-attachment refinement asymmetry. The current attachment-layer shape (Codable standalone, no refinement of Parseable + Serializable) is CONFIRMED; the proposed operational-layer shape (`Coder.Protocol: Parser.Protocol, Serializer.Protocol where Parsed == Serialized`) is RECOMMENDED-FOR-MIGRATION as a separate source-code arc (currently swift-coder-primitives has no dependency on swift-parser-primitives / swift-serializer-primitives; the refinement requires adding those edges).
>
> v1.1.3 (2026-05-15, finalization follow-on): codifies [FAM-007] sub-sibling carve-out — sub-sibling protocols (refinements of a sibling-without-associatedtype, e.g., `UInt8.Base62.Serializable: Binary.Serializable`) MAY declare domain-specific associated types provided their names don't collide with operational-layer slots (`Failure`, `Input`, `Output`, `Buffer`, `Body`). Bridge-type collisions between two sub-siblings handled at the conforming type via `@_implements` per [BLOG-IDEA-031]. Rationale: [FAM-001]'s anchor-unification rationale doesn't trigger by the sub-sibling's existence — only by collision with another sub-sibling's same-named associatedtype on a conforming type; per [BLOG-IDEA-031] that collision is solved at the bridge type, not at the protocol-level by removing domain-meaningful associatedtypes. The sub-sibling tension flagged as OPEN in v1.1.2's State-of-Workspace table is hereby RESOLVED. Existing instance `UInt8.Base62.Serializable` is now explicitly sanctioned. The deprecated `Binary.ASCII.Serializable` remains deprecated for its own reasons (W4 namespace consolidation, not the sub-sibling pattern per se).
>
> v1.1.4 (2026-05-15, same-session follow-on): codifies [FAM-008] the canonical operational-layer family shape — `Family` root is a `public enum`, the operational protocol nests as `Family.Protocol`, the closure-backed witness nests as `Family.Witness<...>` as one combinator type among many, and combinator types nest as `Family.Map<...>`, `Family.Filter<...>`, `Family.Literal<...>`, etc. Reverts the earlier same-session attempt (C6 / W6) to make `Family` itself a generic-struct witness with a hoisted module-level protocol (`__FamilyProtocol` + `extension Family { typealias Protocol = __FamilyProtocol }`). The 4-step pattern compiled and tests passed, but combinator namespacing under a generic struct forces outer-generic binding at every nested-type reference site (`Serializer<O,B,F>.Literal<B>(...)` requires O,B,F at every use), which surfaced as call-site ergonomics friction during W6 combinator integration. First-principles re-examination — including review of `pointfreeco/swift-parsing` as prior art (Parser is protocol-only; `Parsers` is a plural-namespace enum for combinators; `AnyParser` is a separate top-level type) — converged on the enum-namespace shape. Validated by `family-as-enum-namespace-witness-nested` experiment (CONFIRMED 6/6) and applied across `swift-coder-primitives` (`0077e0d`), `swift-serializer-primitives` (`1a22dba`), `swift-parser-primitives` (`3be9124`). The shape is strictly better than swift-parsing's pattern on 5 of 6 design axes (single namespace root, no plural-enum deviation, clean combinator nesting, one call-site form per type, institute Nest.Name conformance) and equal on witness-construction verbosity. Closes the V8/V9 protocol-hoisting design path validated in `parser-as-witness-namespace-collision` — those patterns remain technically valid but are NOT the canonical institute shape. [FAM-006]'s operational-layer refinement (`Coder.Protocol: Parser.Protocol, Serializer.Protocol`) was applied during this same session as part of C6 and survives the revert: Coder.Protocol now nests under `enum Coder` and refines the now-nested `Serializer.Protocol` + `Parser.Protocol`. [FAM-006] is CONFIRMED IN PRODUCTION as of `0077e0d`.

> v1.1.2 (2026-05-14, same-session follow-on): follow [BLOG-IDEA-031] defensive-naming lesson; remove ecosystem rename. The v1.1.1 recommendation to rename `Parser.Protocol.Output → Parsed` and `Serializer.Protocol.Output → Serialized` ecosystem-wide is withdrawn. Same-name unification of `Output` across `Coder.Protocol`'s refinement of `Parser.Protocol` + `Serializer.Protocol` is INTENDED — Swift's refinement mechanism unifies `Output` on both refined protocols into a single binding on the conforming Coder, which is exactly the desired bidirectional constraint. The rare bridge-type collision case (a non-codec type that conforms independently to both `Parser.Protocol` AND `Serializer.Protocol` with DIFFERENT value types in each role) is handled at the bridge type via `@_implements(Parser.\`Protocol\`, Output)` per `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` ([BLOG-IDEA-031]). [FAM-006]'s abstract description (`MAY refine ... where Parsed == Serialized`) is unchanged; only the concrete instantiation guidance changes — the Swift-native form uses `Output` on both protocols and relies on same-name unification, not on protocol-level renaming. Same-name unification also applies to `Failure`: Coder.Protocol's unified `Failure` slot is typed as `Either<DecodeFailure, EncodeFailure>` from `swift-either-primitives` for codecs with distinct decode/encode failure types, collapsing automatically when one direction is `Never` via `Either+Never.swift`. This surfaces a new dependency edge: `swift-coder-primitives` depends on `swift-either-primitives` alongside parser+serializer primitives when [FAM-006] is implemented.
>
> This amendment resolves the sibling-protocol structure and multiple-conformance model. It authorizes second-format work after Φ.3 (per `swift-foundations/swift-ascii/Research/ascii-codable-unification.md`). It does NOT claim byte-stream ergonomics, macro synthesis, cross-format consistency, or a generic visitor abstraction are solved.
>
> **Next empirical validator**: the split byte-stream sibling pair — `Binary.Parseable` (NEW, parallel to `ASCII.Parseable`) plus the existing `Binary.Serializable` (enhanced with `Binary.Endianness` as an operation parameter), after Φ.3 removes the remaining canonical pins on stdlib integers. Endianness is a *parameter* on binary operations via the existing `Binary.Endianness` enum — NOT a sibling format namespace. Until the `Binary.Parseable` half lands, byte-stream support is structurally specified but **empirically pending**.

## Context

Between 2026-05-13 and 2026-05-14, a focused review of `swift-foundations/swift-json`'s Codable surface converged on a load-bearing pattern across five packages: `swift-coder-primitives`, `swift-serializer-primitives`, `swift-parser-primitives`, `swift-ascii-parser-primitives` / `swift-ascii-serializer-primitives`, and `swift-foundations/swift-json` itself. The convergent design — the *family-Codable convention* — was reached empirically across waves W1–W5 (serializer-primitives buildout), T1–T2 (typed-throws and streaming integration), and J1 (JSON.Coder + Codable attachment + in-source documentation pass).

**v1.1.0 amendment (2026-05-14)**: a follow-on readiness audit (`multi-format-codable-readiness.md` v1.0.0) reviewed the convention against eight scope items, ran the dual-conformance experiment (V1–V4), and surfaced an empirical baseline of **three production tree-intermediate sibling protocols** (JSON.Serializable + Plist.Serializable + XML.Serializable) — not the N=1 framing the audit's brief assumed. A peer review involving an independent Claude assessor and a ChatGPT cross-check converged on a set of refinements: confidence-calibration tiers, a semantic-level convention rule (above the signature-shape level), a hard rule on sibling `associatedtype`s, a guarded-use rule for canonical attachments, V4 D as explanation (not normative rule), and an explicit out-of-scope statement on cross-format round-trip equivalence. The v1.1.0 amendment integrates these refinements without altering the structural argument shipped in v1.0.0.

**Naming/architecture refinement during v1.1.0 drafting (2026-05-14)**: the drafting initially named `Binary.LittleEndian.Codable` as the byte-stream-shape exemplar. Two peer reviewers (Claude peer + ChatGPT) independently flagged this as the wrong abstraction boundary: `LittleEndian` is a compound identifier violating [API-NAME-001], AND endianness is a byte-order policy *inside* binary encoding rather than a separate sibling format. The corrected framing — adopted in this v1.1.0 amendment — is the split byte-stream sibling pair `Binary.Serializable` + `Binary.Parseable`, with `Binary.Endianness` as a runtime operation parameter (matching the existing enum's role).

**v1.1.1 follow-on (2026-05-14, same session)**: ChatGPT surfaced a separate architectural question about the relationship between operational protocols (`Parser.Protocol` / `Serializer.Protocol` / `Coder.Protocol`) and attachment protocols (`Parseable` / `Serializable` / `Codable`). Analysis converged on a refinement-layer asymmetry: operational protocols MAY refine each other (specifically `Coder.Protocol: Parser.Protocol, Serializer.Protocol where Parsed == Serialized` is recommended), but attachment protocols MUST NOT refine each other (the three attachment associated-type slots — `Coder`, `Parser`, `Serializer` — are conceptually independent and forcing them into one hierarchy creates mechanical noise without semantic gain). Codified as [FAM-006] in §3a. Current attachment-layer state already CONFIRMED (Codable is standalone); operational-layer refinement is RECOMMENDED-FOR-MIGRATION as a separate source-code arc (swift-coder-primitives currently has no dependency on swift-parser-primitives / swift-serializer-primitives).

The triggering question (v1.0.0) was: *"should `JSON.Serializable` be phased out in favor of the canonical `Coder_Primitives.Codable`?"* The convergent answer remains: `JSON.Serializable` is the JSON sibling of the format-Codable family — siblings, not refinements, of `Coder_Primitives.Codable`. The canonical attachment is reserved for types-with-one-inherent-canonical-codec (e.g., `RFC_8259.Value`), while format-specific siblings handle the per-format dimension for types whose codec is format-dependent.

## Question

How should the ecosystem express "this type is codable in format F" across multiple unrelated formats (JSON, Binary, MessagePack, XML, URL-form-encoded, ...) when stdlib and user-defined types have no single inherent canonical codec, while spec-value types (`RFC_8259.Value`, `RFC_3986.URI`) DO have one?

## Confidence tiers (v1.1.0)

The convention spans claims of varying empirical strength. v1.1.0 segregates these into three tiers so consumers know exactly what is settled, what is testable, and what is open.

| Tier | What it means | Items |
|---|---|---|
| **Resolved** | Structurally derived AND empirically validated. Safe to depend on. | Sibling protocol structure (§1); no-associatedtype rule for siblings (§2 + §4); multiple-conformance feasibility (§2 + §6); instance-accessor disambiguation at call sites (§5); endianness-as-parameter for byte-stream siblings (§7). |
| **Ready to test** | Structurally specified. Awaits empirical validation through a non-tree-intermediate sibling. | Two-shape catalog as semantic-level rule (§7); the `Binary.Parseable` + `Binary.Serializable` split pair as next empirical validator; byte-appender ergonomics at user-type scale (§13 worked example). |
| **Deferred** | Acknowledged structurally; not part of this revision. | Synthesis macros (§10); cross-format synthesis macros (§10); cross-format round-trip consistency (§11); generic visitor abstraction (§7); streaming/event-emitter shape (§7); cross-format-interop currency-type protocol — institute analog of Apple's `CommonCodable` (§9, §11). |

The tier classification is normative: consumers MAY rely on Resolved items as stable convention; they MUST treat Ready-to-test items as empirically pending; they MUST NOT assume Deferred items will be solved by this convention.

## Analysis

### 1. The convention

The family-Codable convention has three structural elements: **canonical attachment protocols** (top-level), **operational protocols** (nested), and **format-specific sibling attachment protocols** (top-level, namespaced to the format).

The convention is defined at the **semantic level**, not at the signature level. The semantic rule (v1.1.0 codification):

> **A format-Codable sibling defines the format-natural serialization and parsing surface for a representation family, while avoiding associated-type anchors and avoiding canonical representation lock-in.** Tree-intermediate formats may return a representation value (`static serialize(_:) -> Format`). Byte-stream formats may append into an encoder, writer, or output buffer (`static serialize(_:, into: inout Buffer)`). Streaming/event-emitter formats consume or produce event streams. These are distinct operational shapes of the same convention, not separate conventions.

Implementation-level heuristic for picking a shape:

| Property of the format | Convention shape |
|---|---|
| Has a canonical tree intermediate (JSON value, plist value, XML element) | Tree-builder shape — bidirectional in one protocol (e.g. `JSON.Serializable`) |
| Has byte-stream semantics with no canonical intermediate (binary encoding, byte-appender) | Byte-appender shape — split into Serializable + Parseable pair (e.g. `Binary.Serializable` + `Binary.Parseable`; `ASCII.Serializable` + `ASCII.Parseable`) |
| Has event-emitter / streaming semantics (gRPC streaming, MessagePack streaming) | Third shape — DEFERRED; see §7 |

#### Canonical attachment protocols (top-level of their packages)

These declare a type's *single inherent canonical codec/parser/serializer*. They are top-level in their packages and named in the noun form (`Codable`, `Parseable`, `Serializable`) — they shadow `Swift.Codable` etc. by design.

| Protocol | Declares | File:line |
|----------|----------|-----------|
| `Coder_Primitives.Codable` | A type that has one canonical bidirectional `Coder` | `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:26–32` |
| `Parser_Primitives_Core.Parseable` | A type that has one canonical `Parser` | `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:19–25` |
| `Serializer_Primitives_Core.Serializable` | A type that has one canonical `Serializer` | `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19–25` |

Each carries a single `associatedtype` (`Coder` / `Parser` / `Serializer`) refining the operational `.Protocol` nested type, and a single static accessor (`.coder` / `.parser` / `.serializer`).

#### Operational protocols (nested under their namespaces)

These describe the *verb*: what it means to be a coder/parser/serializer. They are nested under their namespace (`Coder`, `Parser`, `Serializer`) with the `Protocol` member name.

#### Format-specific sibling attachment protocols (top-level, namespaced)

For each format `F`, a sibling protocol `F.Serializable` / `F.Parseable` (or for tree-intermediate formats, a bidirectional `F.Serializable`) lives top-level within the format's namespace, at the same conceptual rank as the canonical protocol — NOT as a refinement.

**Empirical baseline (v1.1.0 finding)**: the workspace contains **one formal exemplar** (`JSON.Serializable`, authored against the J1d formalization) **and two pre-existing shape-compatible siblings** (`Plist.Serializable`, `XML.Serializable`, predating the J1d formalization but matching it shape-for-shape). Together, they show that the convention shape was not invented solely for JSON — three independent authors arrived at the same structural pattern. The shape-compatible siblings count as evidence the convention captures a natural pattern; they do NOT count as convention-authored implementations.

| Sibling | File | Authoring relation to convention |
|---|---|---|
| `JSON.Serializable` | `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:94` | Formal exemplar; authored against J1d formalization (commit `0307edc`); tree-builder shape (bidirectional in one protocol) |
| `Plist.Serializable` | `swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:3` | Shape-compatible; predates J1d; tree-builder shape |
| `XML.Serializable` | `swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:36` | Shape-compatible; predates J1d; tree-builder shape |
| `Binary.Serializable` | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:37` | L1 byte-stream sibling; byte-appender shape (half of split pair; needs `Binary.Parseable` peer to complete) |
| `ASCII.Parseable` | `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:17` | L1 byte-stream sibling; byte-reader shape (half of split pair; needs `ASCII.Serializable` peer per Φ.1) |

### 2. The structural argument: why siblings, not refinements

Swift's `associatedtype` semantics impose a categorical constraint: a type can have only ONE conformance of a given protocol per program. A `Codable` conformance commits to ONE `associatedtype Coder` value. Refining `Codable` into `JSON.Codable: Coder_Primitives.Codable` therefore forces a global commitment that the type's nature does not support.

**Siblings** sidestep this by living at the same conceptual rank as `Codable`: `Int: JSON.Serializable` and `Int: Binary.Serializable` and `Int: MessagePack.Serializable` (future) all coexist freely because they are independent protocols, each with its OWN slot. The ecosystem-wide canonical `Coder_Primitives.Codable` remains *unconformed* by `Int`, accurately reflecting that `Int` has no single inherent canonical codec.

#### Language-mechanism premise (v1.1.0 codification, [Resolved])

The associated-type-trap blog post (`swift-institute/Blog/Published/2026-04-20-associated-type-trap.md`) documents the load-bearing language mechanism: Swift's `AssociatedTypeDecl::getAssociatedTypeAnchor` (in `lib/AST/Decl.cpp`) unifies same-named associated types across protocols a single type conforms to. The unification is unconditional — SE-0491 module selectors, `@retroactive`, and `MemberImportVisibility` do NOT disambiguate.

The convention's "siblings, not refinements" rule is structurally correct ONLY IF siblings carry no `associatedtype`. v1.1.0 codifies this as a hard rule:

> **[FAM-001] Top-level format-specific sibling protocols MUST NOT declare associated types.** Associated types belong only in canonical attachment protocols (where they enforce single-codec semantics for spec-value types) or in lower-level parser/serializer/coder abstractions (where they parameterize the operational protocol). Sub-siblings (refinements of a top-level sibling) MAY carry associated types under [FAM-007] — see v1.1.3 carve-out below.

The local escape hatch (per the blog post) is `@_implements(Protocol, Name)` — applied at a conformer site when two protocols with same-named associated types must coexist on one type. The convention does NOT rely on this escape hatch at the top-level-sibling layer (top-level siblings carry no associatedtype, so the trap cannot fire). It IS relied upon at sub-siblings carrying associated types per [FAM-007] — bridge types that conform to two sub-siblings with name-colliding associated types use `@_implements` at the conformer site.

### 3. Composition rule: format-specific siblings compose through the canonical leaf

A format-specific sibling does NOT carry a parallel grammar. It is the *ergonomic surface* over the same canonical leaf.

Concrete trace:

| Call site | Routes through |
|-----------|----------------|
| `JSON.Coder.decode(_:)` | `JSON.Decode.Implementation.parse` — `JSON.Coder.swift:86` |
| `JSON.Serializable.init(jsonBytes:)` | `JSON.parse(jsonBytes)` → `JSON.Decode.Implementation.parse` |
| `RFC_8259.Value(decoding: &input)` | `JSON.Coder.decode(_:)` (via `Codable` extension default) |

All three converge on `JSON.Decode.Implementation.parse`. The sibling protocol is NOT a re-implementation; it is a JSON-specific public surface over the canonical leaf.

### 3a. Operational vs attachment refinement asymmetry (v1.1.1 NEW)

Refinement between protocols is permitted at the **operational layer** but FORBIDDEN at the **attachment layer**. These two layers serve different roles, and Swift's same-name-associated-type-anchor mechanism (which the convention treats as a *trap to avoid* at the attachment layer per [FAM-001]) is the *intentional enforcement tool* at the operational layer.

#### [FAM-006] Refinement-layer asymmetry

> **[FAM-006] Operational protocols (`Parser.Protocol`, `Serializer.Protocol`, `Coder.Protocol`) MAY refine each other when the semantic relationship demands it and the associated-type unification is the desired constraint.** Specifically, `Coder.Protocol` SHOULD refine `Parser.Protocol, Serializer.Protocol where Parsed == Serialized` — the bidirectional codec is by definition a parser AND serializer sharing one value type.
>
> **Attachment protocols (`Parseable`, `Serializable`, `Codable`) MUST NOT refine each other.** Each attaches its own canonical operational instance via a distinct associated-type slot (`Parser`, `Serializer`, `Coder`). The slots are conceptually independent: a type with a canonical Coder reaches the parser/serializer surface through `T.coder`, which by [FAM-006] operational-layer refinement conforms to both `Parser.Protocol` and `Serializer.Protocol`. Attachment-level refinement would couple three associated-type surfaces for no semantic gain.

#### Operational layer (refinement allowed, recommended for Coder)

The recommended operational-layer hierarchy uses the Swift-native form — `Output` on BOTH `Parser.Protocol` and `Serializer.Protocol` (matching current ecosystem reality), with `Coder.Protocol` refining both WITHOUT an explicit `where Output == Output` clause (same-name unification is automatic in Swift's refinement mechanism):

```swift
extension Parser {
    public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output
        associatedtype Failure: Swift.Error
        borrowing func parse(_ input: inout Input) throws(Failure) -> Output
    }
}

extension Serializer {
    public protocol `Protocol`<Output, Buffer, Failure>: ~Copyable {
        associatedtype Output            // VALUE being serialized — same name as Parser.Output
        associatedtype Buffer            // BUFFER appended to — distinct name from Parser.Input
        associatedtype Failure: Swift.Error
        borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
    }
}

extension Coder {
    public protocol `Protocol`: Parser.`Protocol`, Serializer.`Protocol` {
        // Same-name unification of `Output` across both refined protocols
        // gives the bidirectional constraint automatically. No explicit
        // `where Parser.Output == Serializer.Output` clause is needed — Swift's
        // refinement mechanism already unifies same-named associated types
        // into a single binding on conforming types.
    }
}
```

Same-name unification is what Swift's refinement mechanism gives us automatically — `Output` on both refined protocols unifies into one binding on the conforming Coder type. This is the desired behavior here, exactly per [BLOG-IDEA-031]. No protocol-level rename is needed.

**Why distinct names (`Parsed` / `Serialized`) at the protocol declaration are NOT recommended**:

Distinct names at the protocol declaration are the "defensive naming" anti-pattern explicitly called out in `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` ([BLOG-IDEA-031]): *"Defensive naming at the protocol declaration is optimizing for the wrong thing. Same-named-associated-type collisions are a property of individual conforming types — solve them there."*

For `Coder.Protocol`'s bidirectional case, same-name unification of `Output` IS the desired constraint — it is exactly what `where Parsed == Serialized` was trying to express, and Swift's refinement mechanism provides it for free. Renaming the protocol-level associated types to avoid unification would optimize for the *rare* independent dual-conformer case (a non-codec type that conforms to BOTH `Parser.Protocol` AND `Serializer.Protocol` separately — NOT via `Coder.Protocol` — with DIFFERENT value types in each role) at the cost of every Coder author and every refinement-chain consumer paying a renaming tax for a same-name unification they actively want.

The correct fix for the rare bridge-type collision is local, per the blog: apply `@_implements(Parser.\`Protocol\`, Output)` (or `@_implements(Serializer.\`Protocol\`, Output)`) at the bridge type to map the bridge's distinct concrete typealiases onto each protocol's `Output` slot independently. This pays the rename cost ONCE, at the conforming type that actually collides — not across every Coder conformer ecosystem-wide.

#### Coder.Protocol's `Failure` slot: `Either<DecodeFailure, EncodeFailure>` from `Either_Primitives`

Same-name unification across the refinement applies to `Failure` too: `Parser.Failure` and `Serializer.Failure` unify into one `Failure` binding on `Coder.Protocol`. For codecs whose decode and encode directions share one error type (most format codecs), the unified `Failure` is that single error type and no further machinery is needed.

For codecs whose decode and encode directions throw **different** error types, the unified `Failure` slot is naturally typed as `Either<DecodeFailure, EncodeFailure>` from `swift-either-primitives` (`Either_Primitives.Either`):

```swift
struct SomeCodec: Coder.`Protocol` {
    typealias Output  = SomeValue
    typealias Input   = Binary.Bytes.Input        // inherited from Parser.`Protocol`
    typealias Buffer  = [UInt8]                    // inherited from Serializer.`Protocol`
    typealias Failure = Either<DecodeError, EncodeError>

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
        // ... throws .left(DecodeError(...))
    }

    borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
        // ... throws .right(EncodeError(...))
    }
}
```

When one direction is infallible (decode might fail but encode is `Never`, or vice versa), `Either+Never.swift` collapses unconditionally: `Either<DecodeError, Never>.value` extracts `DecodeError` directly. This means a JSON-shaped codec where encode is infallible has `Failure == Either<RFC_8259.Parse.Error, Never>`, callers reading `.value` get the parse error directly, and the `Never` arm carries zero runtime cost. `Either` already admits `~Copyable & ~Escapable` arms (`swift-either-primitives/Sources/Either Primitives/Either.swift`), so `~Copyable` `Error` types compose without friction.

This pattern preserves split decode/encode error semantics in the codec's domain model while satisfying the refinement's required unification of `Failure`. The alternative — renaming `Parser.Failure` and `Serializer.Failure` to distinct names at the protocol declaration so they don't unify — is the same defensive-naming anti-pattern that [BLOG-IDEA-031] warns against, scaled to a second associated-type slot.

**Caller-side ergonomic trade-off (acknowledged)**: when `Failure == Either<D, E>` and neither arm is `Never`, callers of `parse(_:)` or `serialize(_:into:)` see a static thrown type of `Either<D, E>` and must either pattern-match both arms or rely on direction-knowledge to extract the inhabited arm. The `Either<X, Never>` collapse via `.value` makes this clean for codecs with one infallible direction (e.g., `Binary.Coder` where `EncodeFailure == Never` → callers of `parse` get `Either<Fault, Never>.value` → `Fault` directly). For codecs where BOTH directions can fail with distinct types (e.g., `JSON.Coder`), callers receive `Either<DecodeFailure, EncodeFailure>` and the direct-error ergonomics are lost.

**Mitigation options for the both-fallible case**:
1. **Unify the codec's error types**: collapse `DecodeFailure` and `EncodeFailure` into one umbrella error enum (e.g., `JSON.Error` with `.decode(...)` and `.encode(...)` cases). Eliminates the `Either` wrapper entirely. Best for codecs where the error types overlap conceptually.
2. **Accept the `Either` static type**: callers of a both-fallible codec catch `Either<D, E>` and pattern-match. Lose direct typing; gain mechanical clarity (the static type encodes that either direction could throw the relevant error).
3. **Direction-specific view accessors** (optional convenience): a default `var parser: some Parser.\`Protocol\`<Input, Output, DecodeFailure> { get }` extension on `Coder.\`Protocol\`` exposing the parse direction as a narrow-typed view. Useful for call sites that already know which direction they're using and want direct typed-throws to `DecodeFailure` without the `Either` wrapper. (Symmetric `var serializer: some Serializer.\`Protocol\`` for the encode direction.)

This recommendation surfaces a dependency: `swift-coder-primitives` will depend on `swift-either-primitives` (alongside `swift-parser-primitives` and `swift-serializer-primitives`) when [FAM-006]'s operational refinement is implemented.

#### Attachment layer (refinement forbidden)

Attachment protocols stay flat:

```swift
public protocol Codable {
    associatedtype Coder: Coder_Primitives.Coder.`Protocol`
    static var coder: Coder { get }
}

public protocol Parseable {
    associatedtype Parser: Parser_Primitives_Core.Parser.`Protocol`
    static var parser: Parser { get }
}

public protocol Serializable {
    associatedtype Serializer: Serializer_Primitives_Core.Serializer.`Protocol`
    static var serializer: Serializer { get }
}
```

A `Codable` conformer (e.g., `RFC_8259.Value`) exposes ONE canonical Coder via `static var coder: JSON.Coder`. That Coder, by [FAM-006] operational-layer refinement, IS a Parser and IS a Serializer at the operational layer. Consumers wanting the parser/serializer view reach it through `T.coder`; no parallel attachment slot is required.

```swift
// Consumer code over a generic Parseable type
func decodeAny<T: Parseable>(_ type: T.Type, from source: inout T.Parser.Source) throws -> T.Parser.Parsed {
    try T.parser.parse(from: &source)
}

// A Codable type IS NOT a Parseable type at the attachment layer.
// But its .coder IS a Parser at the operational layer.
// Consumer code that wants to parse a Codable type:
func decodeAny<T: Codable>(_ type: T.Type, from source: inout T.Coder.Source) throws -> T.Coder.Parsed {
    try T.coder.parse(from: &source)  // .coder conforms to Parser.Protocol via [FAM-006]
}
```

These two `decodeAny` functions are similar but DISTINCT — they accept different protocol bounds (`T: Parseable` vs `T: Codable`) and reach the operational layer via different attachment slots (`T.parser` vs `T.coder`). The convention does NOT collapse them into one bound by making `Codable: Parseable`.

#### Vocabulary clarification: not Decodable / Encodable

The institute's vocabulary (`Parseable` / `Serializable` / `Codable` at the attachment layer; `Parser.Protocol` / `Serializer.Protocol` / `Coder.Protocol` at the operational layer) is **more precise than** Apple's Foundation `Decodable` / `Encodable` / `Codable`. Apple's protocols couple type-attachment with operational logic (`init(from decoder: Decoder)`); the institute's separation of attachment from operation is sharper.

The convention does NOT introduce `Decodable` / `Encodable` aliases. The institute's attachment terms (`Parseable`, `Serializable`) declare "this type HAS a canonical parser/serializer" — narrower and more concrete than Apple's "this type CAN parse/serialize itself via an abstract decoder/encoder."

#### State of the workspace (v1.1.2 — post-rollout)

| Element | Status | Notes |
|---|---|---|
| Attachment-layer non-refinement (Codable standalone) | LANDED | Matches [FAM-006] |
| Operational-layer refinement (`Coder.Protocol: Parser.Protocol, Serializer.Protocol`) | LANDED | `swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift` collapsed to a 1-line refinement (2026-05-14) |
| swift-coder-primitives dependencies on swift-parser-primitives / swift-serializer-primitives / swift-either-primitives | LANDED | Three deps added in `swift-coder-primitives/Package.swift` (2026-05-14) |
| Associated-type names on Parser.Protocol / Serializer.Protocol | UNCHANGED — `Output` on both | Same-name unification across [FAM-006] refinement is INTENDED per [BLOG-IDEA-031]. Bridge-type collisions (non-codec dual-conformers) handled via `@_implements` at the conforming type. |
| Coder.Protocol's `Failure` slot model | LANDED — `Either<D, E>` pattern in production | JSON.Coder uses `Either<RFC_8259.Error, JSON.Encode.Error>`; Binary.Coder uses `Either<Binary.Bytes.Machine.Fault, Never>` (latter collapses via `Either+Never.swift`'s `.value` accessor). |
| Binary split-pair sibling (Binary.Parseable peer of Binary.Serializable) | LANDED | New protocol at `swift-binary-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift` plus `Binary.Parse.Failure` error type (2026-05-14) |
| ASCII.Parseable refinement-to-sibling migration (Φ.1+Φ.3) | LANDED | No longer refines `Parser_Primitives_Core.Parseable`; now a flat marker protocol (2026-05-14). 10 stdlib integer conformances migrated. |
| Decodable / Encodable aliases | NOT present | None — convention forbids alias introduction |
| Sub-sibling protocols carrying associated types (e.g., `UInt8.Base62.Serializable: Binary.Serializable` with `Error`/`Context`) | RESOLVED v1.1.3 — explicitly carved out under [FAM-007] | Sub-siblings (refinements of a top-level sibling without associatedtypes) MAY carry domain-specific associated types whose names do not collide with operational-layer slots. Bridge-type collisions between two sub-siblings handled at the conformer via `@_implements` per [BLOG-IDEA-031]. `UInt8.Base62.Serializable` is sanctioned. `Binary.ASCII.Serializable` remains DEPRECATED for W4 namespace-consolidation reasons (not the sub-sibling pattern per se). |

The source-code arc to implement [FAM-006]'s operational refinement was executed 2026-05-14 (working tree pending commit at time of writing). For the historical migration sequence:

1. Document the `@_implements` pattern in convention guidance for any future bridge types that need independent Parser+Serializer conformance with distinct value types in each role. Reference [BLOG-IDEA-031] (`swift-institute/Blog/Published/2026-04-20-associated-type-trap.md`). No ecosystem-wide rename of `Output` is required — same-name unification across the refinement is intended.
2. Add swift-parser-primitives, swift-serializer-primitives, and swift-either-primitives as dependencies of swift-coder-primitives in `Package.swift`. (Either is needed for the unified-Failure pattern `Either<DecodeFailure, EncodeFailure>` when decode/encode failures differ.)
3. Update `Coder.Protocol` declaration to `: Parser.Protocol, Serializer.Protocol` (no explicit `where` clause — same-name `Output` unification is automatic; `Failure` likewise unifies, and conformers populate the slot with `Either<D, E>` or a single shared error type per their domain model).
4. Verify existing Coder conformers (JSON.Coder) satisfy the refined protocol; add explicit typealiases if needed. For codecs with infallible directions, exploit `Either<X, Never>` collapse via `Either+Never.swift`'s `.value` accessor.
5. Default-implementation extensions on `Codable` providing parser/serializer access through `.coder` (for ergonomic consumer code that uses parse/serialize on Codable types without going through Parseable/Serializable).

### 3b. Sub-sibling carve-out (v1.1.3 NEW)

[FAM-001] applies to **top-level** format-attachment siblings — protocols that sit at the same nesting level as `Codable` / `Parseable` / `Serializable` and represent a whole-format marker (`JSON.Serializable`, `Binary.Serializable`, `ASCII.Parseable`, etc.). A **sub-sibling** is a refinement of a top-level sibling that specializes the encoding pattern further — e.g., `UInt8.Base62.Serializable: Binary.Serializable`, which marks "this type has a canonical Base62 round-trip representation" (a specific encoding within the byte-stream-serialization family).

Sub-siblings often want domain-specific associated types: a per-conformer `Error` for parse failures, a `Context` for parse-time configuration, etc. These names are unique to the sub-sibling and don't collide with the parent sibling (which has no associatedtype) or with operational-layer slots (`Failure`, `Input`, `Output`, `Buffer`, `Body`).

#### [FAM-007] Sub-sibling associated-type carve-out

> **[FAM-007] Sub-sibling protocols — protocols that refine a top-level format-attachment sibling carrying no associated types — MAY declare domain-specific associated types** provided:
> 1. **Unique naming**: the sub-sibling's associatedtype names do NOT collide with operational-layer associated-type slots (`Failure`, `Input`, `Output`, `Buffer`, `Body`) or with the canonical attachment slot names (`Coder`, `Parser`, `Serializer`). Use domain-meaningful names like `Error`, `Context`, `Alphabet`, `Encoding` instead.
> 2. **Bridge-type collisions** between two sub-siblings sharing an associated-type name (e.g., a future `UInt8.Base64.Serializable` that also declares `associatedtype Error`) are resolved at the conforming type via `@_implements(SubSibling, AssociatedTypeName)` per [BLOG-IDEA-031]. The convention does NOT defensively rename at the sub-sibling protocol declaration.
> 3. **Parent-sibling shape preserved**: the sub-sibling MUST provide a default-implementation bridge to its parent sibling's required method (e.g., `UInt8.Base62.Serializable` provides a default `Binary.Serializable.serialize(_:into:)` that delegates to `serialize(base62:into:)`). This preserves the parent-sibling abstraction's promise to its callers.

**Rationale**: [FAM-001]'s anchor-unification trap fires when same-named associatedtypes from *independent* siblings collide on a *conforming* type. A sub-sibling refining a sibling-without-associatedtype doesn't trigger the trap by its own existence — it only triggers by collision with another sub-sibling's same-named associatedtype on a type that conforms to both. Per [BLOG-IDEA-031], that collision is properly solved at the bridge type via `@_implements`, NOT by removing the domain-meaningful associatedtype from the protocol declaration. Removing the associatedtype would force every sub-sibling conformer to drop type precision for a collision that almost never fires in practice — exactly the defensive-naming anti-pattern [BLOG-IDEA-031] warns against.

**Current instances**:
- `UInt8.Base62.Serializable: Binary.Serializable` at `swift-base62-primitives/Sources/Base62 Primitives/UInt8.Base62.Serializing.swift` — declares `associatedtype Error: Swift.Error` (parse-failure type) and `associatedtype Context: Sendable = Void` (parse context). PASSES [FAM-007]: names don't collide; provides default `Binary.Serializable.serialize` bridge at line 132.
- `Binary.ASCII.Serializable: Binary.Serializable` at `swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift` — DEPRECATED for W4 namespace-consolidation reasons (orthogonal to [FAM-007]); structurally would also PASS [FAM-007].

**Example sub-sibling shape**:
```swift
extension UInt8.Base62 {
    public protocol Serializable: Binary.Serializable {
        // Required method with domain-specific labeling.
        static func serialize<Buffer: RangeReplaceableCollection>(
            base62 serializable: Self,
            into buffer: inout Buffer
        ) where Buffer.Element == UInt8

        // Sub-sibling-specific associated types per [FAM-007]:
        associatedtype Error: Swift.Error            // unique name; not `Failure`
        associatedtype Context: Sendable = Void      // unique name; not in operational slot list

        // Parse-side requirement with sub-sibling-specific error type.
        init<Bytes: Collection>(
            base62 bytes: Bytes,
            in context: Context
        ) throws(Error) where Bytes.Element == UInt8

        static var alphabet: Base62_Primitives.Alphabet { get }
    }
}

// REQUIRED by [FAM-007]: default bridge to parent sibling's required method.
extension UInt8.Base62.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ serializable: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        Self.serialize(base62: serializable, into: &buffer)
    }
}
```

The bridge extension at the bottom is the load-bearing piece — it ensures that callers of `Binary.Serializable.serialize(_:into:)` (i.e., generic algorithms over the parent sibling) get the sub-sibling's specialized behavior automatically.

### 3c. Canonical operational-layer family shape (v1.1.4 NEW)

The operational-layer family roots (`Parser`, `Serializer`, `Coder`) follow a single canonical structural shape. This shape was finalized after a same-session trajectory (W6/C6 generic-struct-witness attempt → first-principles re-examination → enum-namespace + nested-Witness shape adopted) validated by the `family-as-enum-namespace-witness-nested` spike (CONFIRMED 6/6) and applied across all three packages on 2026-05-15.

> **[FAM-008] Operational-layer family root MUST be a `public enum` namespace; the operational protocol MUST nest as `Family.\`Protocol\``; the closure-backed witness MUST nest as `Family.Witness<...>` as one combinator type among many; all combinator types (`Family.Map`, `Family.Filter`, `Family.Literal`, `Family.Sequence`, etc.) MUST nest under the namespace.** The shape is non-negotiable across `Parser`, `Serializer`, `Coder`.

**Canonical exemplar** (replace `Family` with `Parser` / `Serializer` / `Coder`):

```swift
public enum Family {}

extension Family {
    public protocol `Protocol`<…>: ~Copyable {
        associatedtype …
        // ... requirements (parse/serialize) + Body associated type per [FAM-006]
    }
}

extension Family {
    // Closure-backed witness — ONE combinator among many, NOT a privileged "the witness".
    public struct Witness<…>: Family.`Protocol` {
        var _operation: (...) throws(Failure) -> ...
        public init(_ operation: ...) { ... }
        // delegating method satisfies Family.Protocol's requirement
    }

    // Other combinators nest the same way:
    public struct Map<Upstream: Family.`Protocol`, …>: Family.`Protocol` { ... }
    public struct Filter<Upstream: Family.`Protocol`>: Family.`Protocol` { ... }
    public struct Literal<Buffer>: Family.`Protocol` where ... { ... }
    // ...
}
```

**Production state** (as of 2026-05-15):

| Package | Latest on origin/main | Status |
|---------|----------------------|--------|
| swift-coder-primitives | `0077e0d` (C6 revert) | CONFORMS |
| swift-serializer-primitives | `1a22dba` (W6 revert) | CONFORMS |
| swift-parser-primitives | `3be9124` (P6 Parser.Witness greenfield) | CONFORMS |

**Why this shape**:

1. **Combinator namespace conflict structurally resolved.** Generic-struct-witness root forces outer-generic binding at every nested-type reference site (`Serializer<O,B,F>.Literal<B>(...)`); enum namespace eliminates the outer generics, so combinator types nest cleanly without per-call-site binding.
2. **Single namespace root.** No `Families` plural enum (the swift-parsing pattern) or `__FamilyX` hoisted module-level types are required. Discoverable via `Family.<TAB>` autocomplete.
3. **Closure-backed witness is one combinator among many.** Named `.Witness` to describe its role in the witness pattern; structurally peer to `Literal` / `Map` / `Filter`. NOT a privileged "the witness" type that also serves as the namespace.
4. **One call-site form per type.** No "four-forms decision tree" (which `Self.X` + `Serializers.X` + full-bind + `__FamilyX` introduced under the W6 design).
5. **Institute `Nest.Name` conformance** ([API-NAME-001]). All combinator types follow `Family.X` naming.
6. **Comparison to `pointfreeco/swift-parsing`**: strictly better on 5 of 6 design axes (single namespace root vs `Parser`+`Parsers`+`AnyParser` triplet; no plural-enum deviation; clean combinator nesting; one call-site form per type; Nest.Name conformance); equal on witness-construction verbosity (`Family.Witness<...>(...)` vs `AnyParser(...)`).

**Rejected dead ends** (do NOT retread):

- `Family<O,B,F>` as generic struct + namespace for combinators — structurally impossible (outer generics must bind at every nested-type reference). Confirmed by W6 call-site ergonomics issue.
- `Families` plural enum as combinator namespace — works (swift-parsing uses exactly this) but creates two namespaces for one concept. Rejected.
- `__FamilyProtocol` / `__FamilyX` underscored hoisted types in public API — leaks implementation-detail naming into consumer code. Rejected after `__SerializerSequence.Two(...)` surfaced in internal Builder code.
- `Self.X` (typealiases on `Family.Protocol` via `extension Family.Protocol { typealias X = __FamilyX }`) — works inside conformer bodies, fails for free functions / internal builder code / tests outside conformer scope. Insufficient.

**Reference implementations**:

- Spike: `swift-institute/Experiments/family-as-enum-namespace-witness-nested/`
- Multi-target verification: `swift-institute/Experiments/witness-multi-target-namespace-collision/`
- Superseded historical: `swift-institute/Experiments/parser-as-witness-namespace-collision/` (status `SUPERSEDED`, supersededBy `family-as-enum-namespace-witness-nested`)

### 4. When canonical Codable applies vs format-specific siblings

The asymmetry is **intentional**, not a defect to be defended (v1.1.0 reframing).

> **[FAM-002] The associatedtype on canonical attachment protocols is the structural enforcement of "exactly one inherent codec per spec-value type."** It commits the conforming type to a single `Coder` / `Parser` / `Serializer`. Sibling protocols escape this commitment by carrying no `associatedtype` (per [FAM-001]). The asymmetry IS the convention's structural intent: canonical attachments commit, sibling attachments don't.

| Type class | Canonical `Codable` | Format-specific sibling |
|-----------|---------------------|-------------------------|
| Spec-value types (`RFC_8259.Value`, `RFC_3986.URI`, `RFC_4122.UUID` future) — ONE inherent canonical codec | **YES** — the associatedtype commits the type to its single codec | Optional — same type MAY also conform to a sibling if it has an ergonomic JSON-specific surface |
| Stdlib types (`Int`, `String`, `Optional`, `Array`, `Dictionary`) — NO inherent canonical codec | **NO** — refusing the canonical conformance is the correct stance | **YES** — conform to per-format siblings |
| User-defined value types (`User`, `Product`, ...) — NO inherent canonical codec | **NO** — same reasoning as stdlib types | **YES** — conform to per-format siblings; the user chooses which formats their type supports |

#### Guarded-use rule for canonical attachments (v1.1.0 codification, [Resolved])

> **[FAM-003] Direct conformances to canonical attachment protocols (`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`, `Serializer_Primitives_Core.Serializable`) on public/specification value types require an explicit justification comment in the extension.** Types expected to support multiple independent format representations MUST prefer format-specific siblings. Lint-rule enforcement is a follow-on arc; documentation is the v1.1.0 floor.

Example:
```swift
// In swift-rfc-8259, conforming RFC_8259.Value to canonical Codable:
extension RFC_8259.Value: @retroactive Coder_Primitives.Codable {
    /// CANONICAL-ATTACHMENT JUSTIFICATION [FAM-003]:
    /// RFC_8259.Value has exactly one inherent canonical codec — JSON.
    /// The associatedtype commitment to JSON.Coder is structurally correct
    /// because RFC_8259.Value cannot meaningfully be encoded as anything
    /// other than its JSON representation; it IS the JSON tree value type.
    typealias Coder = JSON.Coder
}
```

### 5. Naming-symmetry rule and call-site disambiguation

The canonical naming-symmetry is unchanged from v1.0.0:

| Rank | Position | Names |
|------|----------|-------|
| Top-level (canonical attachment) | Top-level of the primitives package | `Codable`, `Parseable`, `Serializable` |
| Top-level (format-specific sibling) | Top-level within the format's namespace | `JSON.Serializable`, `Plist.Serializable`, `XML.Serializable`, `Binary.Serializable`, `Binary.Parseable`, `ASCII.Parseable`, `ASCII.Serializable` (future per Φ.1) |
| Nested (operational) | Inside the corresponding namespace | `Coder.Protocol`, `Parser.Protocol`, `Serializer.Protocol` |

**Naming rule for sub-format dimensions** (v1.1.0 codification): sub-format dimensions (endianness for Binary; decimal/hexadecimal/base-62 for ASCII; etc.) are NOT separate sibling-protocol namespaces. They are *parameters* on the operations OR distinct leaf-parser/serializer instances. Concretely:

- **Endianness in Binary**: parameter on serialize/parse methods via the existing `Binary.Endianness` enum (runtime selection). NOT a per-endianness protocol namespace. The compound name `Binary.LittleEndian.Codable` violates [API-NAME-001] and additionally over-models a parameter as a sibling format.
- **Sub-format radix in ASCII**: distinct leaf serializers/parsers (`ASCII.Decimal.Serializer<T>`, `ASCII.Hexadecimal.Serializer`, `UInt8.Base62.Serializing`). The sibling protocol is `ASCII.Parseable` / `ASCII.Serializable`; the leaf instance carries the radix.

The rule: **sibling namespaces correspond to format-level distinctions**; sub-format dimensions are operation parameters or leaf-instance selections.

#### Call-site disambiguation rule (v1.1.0 codification, [Resolved])

The dual-conformance experiment (V1–V4, 2026-05-14) verified that multiple sibling conformances on a single type compose without conflict. V4 D additionally found that bare `T.serialize(v)` with no return-type context selects the non-generic protocol requirement deterministically (JSON.Serializable's `serialize(_:) -> JSON` wins over Binary.Serializable's `serialize<Bytes>(_:) -> Bytes` generic extension).

The convention does NOT rely on V4 D as a normative rule. Instead, v1.1.0 codifies:

> **[FAM-004] At consumer call sites where multiple sibling protocols may be in scope, use format-specific instance accessors** (`u.json`, `u.plist`, `u.xml`, `u.bytes`). These accessors are unambiguous regardless of which siblings are in scope, by construction. The bare static form (`T.serialize(v)`) is permitted but its overload resolution is Swift-language territory, not convention scope; consumers relying on bare static form accept Swift's overload-resolution rules (which V4 D documents but the convention does not normatively endorse).

Empirical naming in the workspace:

| Sibling | Type-level entry | Instance accessor |
|---|---|---|
| JSON.Serializable | `serialize(_:)` / `deserialize(_:)` | `.json: JSON` |
| Plist.Serializable | `serialize(_:)` / `deserialize(_:)` | `.plist: Plist` |
| XML.Serializable | `serialize(_:)` / `deserialize(_:)` | `.xml: XML` |
| Binary.Serializable | `serialize<Buffer>(_:, into:)` (endianness param to be added) | `.bytes: [UInt8]` |
| Binary.Parseable (future) | `parse(from:, endianness:)` | `init(bytes: [UInt8], endianness:)` via extension |

### 6. The parser-side refinement-vs-siblings tension

The serializer/coder side empirically follows the sibling-not-refinement convention. The parser side currently has a refinement-shape exception (`ASCII.Parseable: Parser_Primitives_Core.Parseable`) plus canonical `@retroactive Parseable` pins on stdlib integers — these are RECOMMENDED-FOR-MIGRATION per `ascii-codable-unification.md` Φ.1 + Φ.3.

**v1.1.0 status**: this tension is unchanged from v1.0.0. The closing arc is Φ.1 + Φ.3 (per the ascii-codable-unification migration plan). After Φ.3 lands, stdlib-integer canonical pins are removed and the path is clear for second-format-Codable adoption on those types.

### 7. Future sibling protocols and shape variants

Anticipated future siblings (not prescribed — slots reserved):

| Format | Sibling protocol(s) (anticipated) | Shape category |
|--------|----------------------------------|----------------|
| Binary | `Binary.Parseable` (NEW — to be authored, parallel to ASCII.Parseable) + existing `Binary.Serializable` (enhanced with `endianness: Binary.Endianness` parameter) | Byte-appender / split-pair — **next empirical validator pair** |
| MessagePack | `MessagePack.Serializable` + `MessagePack.Parseable` (compact tagged byte format) | Byte-appender / split-pair |
| URL form-encoded | `URL.FormEncoded.Serializable` | Tree-builder |
| ASCII (post-Φ.1) | `ASCII.Serializable` (NEW per Φ.1) + existing `ASCII.Parseable` | Byte-appender / split-pair |
| CBOR | `CBOR.Serializable` + `CBOR.Parseable` | Byte-appender / split-pair |
| Streaming protobuf-like / event-emitter | **DEFERRED** — third shape | Streaming/event-emitter |

#### Why byte-stream formats use the split shape (v1.1.0 [Resolved])

Tree-intermediate formats (JSON, Plist, XML) naturally fit a single bidirectional sibling protocol because the tree value (`JSON.Value`, `Plist.Value`, `XML.Value`) is a SYMMETRIC type — serialize and deserialize operate over the same intermediate. Byte streams have no symmetric intermediate; serialize is naturally infallible (just append bytes), parse is naturally fallible (validate, bounds-check, propagate errors). The split shape (Serializable + Parseable) reflects this asymmetry directly:

```swift
extension UInt32: Binary.Serializable, Binary.Parseable {
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: UInt32,
        endianness: Binary.Endianness = .native,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        switch endianness {
        case .little: /* LE bytes */
        case .big: /* BE bytes */
        }
    }

    static func parse(
        from input: inout Binary.Input,
        endianness: Binary.Endianness = .native
    ) throws(Binary.Error) -> UInt32 {
        // mirror
    }
}
```

#### Endianness-as-parameter design (v1.1.0 [Resolved])

`Binary.Endianness` is a closed runtime enum with `.little` and `.big` cases (`Binary.Endianness.swift:24`). Its purpose is runtime endianness selection. Treating endianness at the protocol level (separate `Binary.LittleEndian.Serializable` vs `Binary.BigEndian.Serializable`) would create a SECOND endianness-selection mechanism (compile-time) competing with the existing runtime one. The convention chooses **one mechanism**: endianness is a runtime parameter passed via the existing `Binary.Endianness` enum. Compound names like `Binary.LittleEndian.X` are forbidden by [API-NAME-001] anyway; the additional rationale here is that they over-model a parameter as a sibling format.

This is consistent with the existing `Binary.Endianness.swift:17` doc-comment example: `value.bytes(endianness: .big)` — endianness is already an operation parameter on integer primitives.

#### Streaming/event-emitter as third shape (v1.1.0 [Deferred])

A third operational shape — streaming/event-emitter — is acknowledged but not specified by v1.1.0. The in-production precedent is `JSON.Span.EventStream` (per `JSON.Serializable.swift:111`, the event-grain `deserialize(events:)` fast path) for the parse direction. The emit-direction equivalent (a cross-format streaming serialization API) is NOT specified. Streaming formats (gRPC, MessagePack streaming, large-payload JSON streaming) will require this third shape; v1.1.0 defers the specification to a future amendment.

### 8. Per-format Optional semantics

Optional handling is **format-natural per sibling** — a property of each sibling's representation choice, not a convention invariant. The three in-production tree-intermediate siblings plus the L1 byte-stream sibling demonstrate the diversity:

| Format | Optional nil encoding |
|--------|----------------------|
| Binary (`Serializer.Optionally`) | No bytes — assumes outer framing carries optionality |
| JSON (`JSON.Serializable`) | `null` literal — JSON has an explicit null grammar |
| Plist (`Plist.Serializable`) | `.null` enum case — plist has a null primitive |
| XML (`XML.Serializable`) | `XML.Element(name: "null")` — XML uses element-naming convention |
| MessagePack (future) | `0xC0` byte — MessagePack has an explicit nil tag |

The two existing serializer-primitive Optional conformances (`Optional+Serializable.swift:21` and `JSON.Serializable.swift:556`) coexist without conflict precisely because they are on sibling protocols, not refinements.

### 9. External anchors and structural convergence (v1.1.0 NEW)

v1.1.0 adds an external SoA anchor: Apple/Foundation's proposed Codable successor.

**Apple/Foundation Codable-successor proposal** ([Kevin Perry, opened 2025-03-17, ongoing discussion](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585)) — verified by direct thread read of opening post + reply #33 on 2026-05-14:

The proposal converges with the family-Codable convention on three of four axes (verified by direct quote):

**Axis 1 — Format-specialized + format-agnostic dual-protocol layer: CONFIRMED with structural nuance.**
Direct quote (Perry, opening post): *"we should encourage each serialization format that has native support for data types that aren't represented in the format-agnostic interface to produce its own protocol variant that includes explicit support for these types, e.g. `JSONCodable` or `PropertyListCodable`."*
The institute's `JSON.Serializable` / `Plist.Serializable` / `XML.Serializable` matches Apple's format-specialized layer (`JSONCodable` / `PropertyListCodable`) directly. **Structural nuance**: Apple's *format-agnostic* protocol (working name `CommonCodable`) addresses cross-format interop for currency types (Perry, reply #33: *"Range and CGRect can, in similar fashion to Codable, describe their serializable members abstractly, allowing a specific encoder/decoder to interpret those instructions."*) — this is a DIFFERENT semantic from the institute's *canonical attachment* protocols (which commit to ONE inherent codec via associatedtype). The institute's convention currently LACKS an analog of Apple's format-agnostic layer for currency-type cross-format interop; see §11 out-of-scope.

**Axis 2 — Per-format synthesis via macros: CONFIRMED.**
Direct quote (Perry, opening post): *"In this new design I aim to leverage Swift's macro features to meet or exceed Serde's level of support for customization of synthesized conformances... `@JSONCodable` struct BlogPost..."*. The institute's deferred per-format macros (§10) are *architecturally* aligned with this. *Timing* differs: institute defers, Apple proposes.

**Axis 3 — Parser-driven visitor pattern: CONFIRMED.**
Direct quote (Perry, opening post): *"Serde's deserialization design employs a Visitor pattern which allows the parser to drive the deserialization process instead of being required to service requests from the client in arbitrary orders."* The institute's `JSON.Span.EventStream` (parse direction) is structurally equivalent; the cross-format emit-direction visitor is in the [Deferred] tier (§7).

**Axis 4 — Rejection of single-canonical-encoding lockout: PARTIAL.**
Apple's proposal *expands beyond* Codable's lockout via the dual-protocol design (format-agnostic + format-specialized) rather than *rejecting* the lockout outright. v1.1.0 honestly describes this as expansion-not-rejection. The institute's convention is more strict — sibling-not-refinement explicitly forbids the lockout for stdlib + user-defined types; Apple's design accommodates types that prefer cross-format interop via format-agnostic.

**Overall convergence**: structurally aligned on 3 axes (format-specialized + per-format macros + parser-driven visitor); structurally distinct on 1 axis (canonical-attachment vs format-agnostic semantics); partially aligned on Codable-lockout response. This is meaningful convergence, not full alignment.

**Where the institute is ahead**:
1. Three production sibling protocols already shipping (JSON, Plist, XML); plus byte-stream sibling at L1 (Binary.Serializable). Empirical baseline established.
2. CROSS-1 `@_implements` escape hatch identified for canonical-attachment latent risk.
3. CROSS-2 V4 D non-generic-wins behaviour empirically verified via dual-conformance experiment.
4. Composition through canonical leaf made explicit in §3.

**Where Apple's proposal may be ahead**:
1. Format-agnostic protocol (`CommonCodable`) for currency-type cross-format interop — institute lacks an analog.
2. Per-format synthesis macros — institute defers.
3. Generic visitor abstraction for cross-format streaming — institute has only JSON.Span.EventStream.

**Risk**: when Apple's proposal lands a formal Swift Evolution pitch and ships in Foundation, the institute's convention competes with stdlib on naming (institute's `JSON.Serializable` vs proposal's `JSONCodable`) and on ergonomics (institute manual vs Apple macros). Naming alignment is a candidate skill-lifecycle item once the formal pitch lands.

### 10. Synthesis strategy (v1.1.0 NEW)

The convention's synthesis strategy for v1.1.0 is **manual per-format conformances**. Per-format macros are deferred (NOT rejected — see triggers below).

**Manual conformance** is the only synthesis path documented by v1.1.0:

```swift
extension User: JSON.Serializable {
    static func serialize(_ u: User) -> JSON { /* ... */ }
    static func deserialize(_ j: JSON) throws(JSON.Error) -> User { /* ... */ }
}
```

This is the **current adoption mode, not the ideal future ergonomic layer.** Apple's Codable-successor proposal includes per-format macros as a first-class feature; when that proposal lands, the institute will re-evaluate.

#### Deferral trigger conditions (v1.1.0 codification, [Deferred])

The no-macros deferral remains in force until **any one** of the following fires:

1. A production user-defined type adds a third format-Codable sibling conformance — triggers a 30-day re-evaluation window.
2. Manual LOC / duplication on the above type exceeds an agreed threshold (institute to set at first-trigger time).
3. Apple's Codable-successor proposal reaches formal Swift Evolution pitch status (currently discussion phase as of 2026-05-14).
4. The institute has at least two implemented non-JSON siblings (so any future macro design is grounded in real repeated structure, not JSON-only inference).

**Rationale**: macros are tooling, not structure. The convention's structural correctness does not depend on them. Manual conformances are tractable for the current empirical scope (3 production siblings on stdlib primitives, ~4–10 lines per format per type). Adding macros prematurely commits the institute to a synthesis shape that might not match Apple's eventually-shipping macro surface.

### 11. Out of scope for v1.1.0 (NEW)

The following are explicitly out of the convention's scope at this revision:

1. **Cross-format round-trip equivalence**. The property that a value encoded in one sibling's format decodes back to a semantically-equivalent value through another sibling's format is NOT a convention invariant. It is a property of the type author's per-format representation choices. The convention guarantees per-format round-trip safety within each sibling's own format only.

2. **Per-format macros**. Deferred per §10 deferral triggers.

3. **Cross-format synthesis macros** (`@MultiFormatCodable`). REJECTED on structural grounds — a single decorator commits the type to one synthesis path, re-introducing the lockout the convention was designed to escape.

4. **Generic visitor abstraction**. Acknowledged per §9 Apple-proposal alignment but deferred.

5. **Streaming/event-emitter shape** (third operational shape). Acknowledged per §7 but deferred.

6. **Cross-format-interop protocol for currency types** (institute analog of Apple's format-agnostic `CommonCodable`). Acknowledged per §9 but deferred. Currency types currently use per-format sibling conformances (one per format).

7. **Lint-rule enforcement of [FAM-003] canonical-attachment guarded use**. Follow-on arc; v1.1.0 ships documentation-only enforcement.

### 12. User-level conformance authoring (v1.1.0 NEW)

#### Tree-intermediate siblings: method-body composition is idiomatic

```swift
extension User: JSON.Serializable {
    static func serialize(_ u: User) -> JSON {
        .object(["name": u.name.json, "age": u.age.json])
    }
}
```

Tree-builder formats (JSON, Plist, XML) compose naturally via method calls on the format's tree-value type. The convention does not prescribe a builder DSL for tree formats — method bodies are sufficient.

#### Byte-stream siblings: combinator authoring expected but not normatively codified

For byte-stream formats (Binary, MessagePack, CBOR), the leaf-serializer infrastructure already supports combinator composition (`Serializer.Sequence`, `Serializer.Many.Separated`, `Serializer.Optionally`). The convention notes — but does NOT mandate — that byte-stream conformances are expected to benefit from combinator authoring:

```swift
// Hypothetical user-type binary serializable conformance via combinators
static func serialize<Buffer>(
    _ value: User, endianness: Binary.Endianness, into buffer: inout Buffer
) where Buffer: RangeReplaceableCollection, Buffer.Element == UInt8 {
    UInt32.serialize(value.id, endianness: endianness, into: &buffer)
    String.LengthPrefixed.serialize(value.name, into: &buffer)
    Int64.serialize(value.age, endianness: endianness, into: &buffer)
}
```

**Implementation note (not normative)**: the empirical validator for byte-stream user-level ergonomics is `Binary.Parseable` landing as the peer of `Binary.Serializable`. Until then, combinator authoring at user-level is plausible-but-untested.

### 13. Worked examples (v1.1.0 NEW)

#### Small example: 2 fields × 3 tree-intermediate formats

```swift
struct User: Sendable {
    var name: String
    var age: Int
}

extension User: JSON.Serializable {
    static func serialize(_ u: User) -> JSON {
        .object(["name": u.name.json, "age": u.age.json])
    }
    static func deserialize(_ j: JSON) throws(JSON.Error) -> User {
        guard let obj = j.asObject,
              let name = try obj["name"].map(String.deserialize),
              let age = try obj["age"].map(Int.deserialize) else {
            throw .typeMismatch(expected: "object with name + age", got: j.typeName)
        }
        return User(name: name, age: age)
    }
}

extension User: Plist.Serializable {
    static func serialize(_ u: User) -> Plist {
        .dictionary([("name", u.name.plist), ("age", u.age.plist)])
    }
    static func deserialize(_ p: Plist) throws(Plist.Error) -> User { /* ... */ }
}

extension User: XML.Serializable {
    static func serialize(_ u: User) -> XML {
        .element("user", children: [.element("name", text: u.name), .element("age", text: String(u.age))])
    }
    static func deserialize(_ x: XML) throws(XML.Error) -> User { /* ... */ }
}
```

Three conformances coexist on `User` by construction. Each picks format-natural representation. ~6 method bodies × ~5 LOC each = ~30 LOC of conformance code. Tractable by hand.

#### Byte-stream example: User with Binary split-pair conformance

```swift
extension User: Binary.Serializable, Binary.Parseable {
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: User, endianness: Binary.Endianness = .little, into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        String.LengthPrefixed.serialize(value.name, endianness: endianness, into: &buffer)
        Int.serialize(value.age, endianness: endianness, into: &buffer)
    }

    static func parse(
        from input: inout Binary.Input,
        endianness: Binary.Endianness = .little
    ) throws(Binary.Error) -> User {
        let name = try String.LengthPrefixed.parse(from: &input, endianness: endianness)
        let age = try Int.parse(from: &input, endianness: endianness)
        return User(name: name, age: age)
    }
}
```

Endianness flows through the call chain as a runtime parameter. Type author writes ONE serialize body and ONE parse body covering both endiannesses — Swift switch-statement on `endianness` inside primitive conformances handles the per-byte-order detail at the leaf level.

#### Medium example: 8–12 fields × 3 formats (manual cost surface)

A realistic medium-sized user-defined type with three tree-intermediate format conformances:

```swift
struct Order: Sendable {
    var id: UUID
    var customerName: String
    var customerEmail: String
    var items: [LineItem]
    var subtotal: Decimal
    var tax: Decimal
    var total: Decimal
    var placedAt: Date
    var notes: String?
    var status: Status
}

extension Order: JSON.Serializable {
    static func serialize(_ o: Order) -> JSON {
        .object([
            "id": o.id.json, "customer_name": o.customerName.json,
            "customer_email": o.customerEmail.json, "items": o.items.json,
            "subtotal": o.subtotal.json, "tax": o.tax.json, "total": o.total.json,
            "placed_at": o.placedAt.json, "notes": o.notes.json, "status": o.status.json,
        ])
    }
    static func deserialize(_ j: JSON) throws(JSON.Error) -> Order { /* ~30 LOC field extraction */ }
}

extension Order: Plist.Serializable { /* analogous, ~50 LOC total */ }
extension Order: XML.Serializable { /* analogous, ~50 LOC total */ }
```

Empirical cost: ~150 LOC of conformance code per such type for 3 formats. Adding a binary pair (`Order: Binary.Serializable, Binary.Parseable`) brings it to ~220 LOC for 4 formats (the binary serialize + parse pair is ~70 LOC for a 10-field type because primitive serializations are one-liners). The deferral trigger §10.1–§10.2 fires when this cost is measured as adoption-limiting on a real consumer. v1.1.0 ships with this scale documented but unmeasured.

## Comparison

Refinement (Codable-style locked-in) vs Siblings (current convention) vs Apple's Codable-successor (dual format-agnostic + format-specialized):

| Criterion | Refinement (Foundation Codable) | Siblings (this convention v1.1.0) | Apple's Codable-successor proposal (Mar 2025) |
|-----------|------------------------------------------------------|-------------------------------------------|----------------------------------------|
| Stdlib type freedom | LOCKED — one canonical encoding per type | FREE — parallel sibling conformances coexist | Compromise — format-specialized for format-native, format-agnostic for interop |
| Synthesis | Compiler-built | Manual (macros deferred) | Per-format macros |
| Cross-format interop layer | Single Codable protocol | None at convention level — manual per-format conformance | Format-agnostic protocol (`CommonCodable`) |
| Sub-format dimensions (endianness, radix) | Hidden behind encoder config | Operation parameters or leaf-instance selections (NOT separate sibling namespaces) | Operation parameters via encoder config |
| Future-extensibility | BLOCKED on stdlib types | UNBLOCKED — each sibling owns its slot | UNBLOCKED — dual-protocol |
| Empirical adoption | Foundation-wide | 3 tree-intermediate siblings (JSON, Plist, XML) + 1 byte-stream sibling (Binary, half of split pair) + experiment validation | Discussion phase only |

## Outcome

**Status**: RECOMMENDATION (unchanged from v1.0.0; v1.1.0 is a refinement, not a re-decision)

**Conclusion**: The family-Codable convention is **structurally sound and empirically validated for tree-intermediate siblings** (one formal exemplar — JSON.Serializable — plus two shape-compatible siblings — Plist.Serializable, XML.Serializable). The convention is **structurally specified but empirically pending for byte-stream Codable** until the split byte-stream sibling pair completes: `Binary.Parseable` (NEW, parallel to `ASCII.Parseable`) needs to be authored, and the existing `Binary.Serializable` needs the `endianness: Binary.Endianness` operation parameter added. Both halves land after Φ.3 removes the remaining canonical pins. The convention is **structurally convergent with Apple's Codable-successor proposal on three of four axes** (per-format specialized protocols; per-format macros architecturally aligned but timing-deferred on institute side; parser-driven visitor pattern); **partially aligned on the fourth axis** (Apple expands beyond rather than rejects single-canonical-encoding); **structurally distinct on the format-agnostic-vs-canonical-attachment semantics** (Apple's `CommonCodable` for currency-type interop has no institute analog at this revision).

> **Next empirical validator** (promoted callout per v1.1.0 amendment):
> The split byte-stream sibling pair — `Binary.Parseable` (NEW) + existing `Binary.Serializable` (with `Binary.Endianness` parameter added). Endianness is a runtime parameter, NOT a sibling format namespace. Until both halves land, byte-stream support is **structurally specified but empirically pending**.

**v1.1.x structural rules codified** (Resolved tier):

| Rule | Statement | Replaces / refines | Version |
|---|---|---|---|
| [FAM-001] | Format-specific sibling protocols MUST NOT declare associated types. | NEW codification of v1.0.0 §2 structural argument | v1.1.0 |
| [FAM-002] | Canonical-attachment associatedtype is the structural enforcement of "one inherent codec per spec-value type" — intentional, not defect. **[RE-CUT v1.2.0 — the canonical operational tier is RETIRED by [FAM-012]; "single inherent codec" is the degenerate one-sibling case, carried by the sibling, not a separate slot.]** | REFRAMES v1.0.0 §4; re-cut v1.2.0 | v1.1.0 |
| [FAM-003] | Canonical attachment conformances on public/spec-value types require explicit justification comment. | NEW | v1.1.0 |
| [FAM-004] | Use format-specific instance accessors at call sites; bare static form is Swift overload-resolution territory, not convention scope. | NEW codification (V4 D framing correction) | v1.1.0 |
| [FAM-005] | Sibling namespaces correspond to format-level distinctions; sub-format dimensions (endianness, radix) are operation parameters or leaf-instance selections — NEVER per-dimension sibling namespaces. | NEW | v1.1.0 |
| [FAM-006] | Operational protocols MAY refine each other when the bidirectional/composite semantics demand it (Coder.Protocol: Parser.Protocol, Serializer.Protocol where Parsed == Serialized); attachment protocols MUST NOT refine each other (Codable, Parseable, Serializable stay flat at the attachment layer). Same-name unification of `Output` across the refinement is INTENDED; bridge-type collisions for non-codec dual-conformers are handled via `@_implements` per [BLOG-IDEA-031]. | NEW | v1.1.1 (refined v1.1.2) |
| [FAM-007] | Sub-sibling protocols (refinements of a top-level format-attachment sibling without associatedtypes, e.g., `UInt8.Base62.Serializable: Binary.Serializable`) MAY declare domain-specific associated types under three conditions: (1) unique naming that does not collide with operational-layer slots (`Failure`/`Input`/`Output`/`Buffer`/`Body`) or canonical attachment slots (`Coder`/`Parser`/`Serializer`); (2) bridge-type collisions between two sub-siblings handled at the conforming type via `@_implements` per [BLOG-IDEA-031]; (3) the sub-sibling MUST provide a default-implementation bridge to its parent sibling's required method. Carves out [FAM-001] for sub-siblings. | NEW | v1.1.3 |
| [FAM-012] | Self-contained format siblings each carry a static universal verb `serialize<Buffer: RangeReplaceableCollection>(_ value: borrowing Self, into:) where Buffer.Element == <FormatElement>` (+ dual `parse`); a type conforms to EXACTLY the siblings it has (one sibling = single inherent codec, two-or-more = multi-representation, both ordinary — no canonical tier, no decline, no derivation bridge); VARIANTS + parse-CONTEXT are `Serializer.\`Protocol\``/`Parser.\`Protocol\`` witness VALUES passed in (per-call-varying, so never anchored on the marker); the SOLE marker associatedtype is the fixed-per-type parse `Failure` (minimal-B: Binary fixed-concrete, ASCII/text rich; dual-parse conformers add `typealias Failure` or `@_implements`, both permitted); composites compose re-cut sub-parts' same-format VERBS directly (no byte-detour, no `rawValue` reach-in); accessors additive; canonical operational slot RETIRED (D2(a), spec-value types re-home onto their one sibling; `Tagged`/`Optional` fan out to per-format forwarders); ASCII→binary bridge DELETED; sink = `RangeReplaceableCollection` + `OutputSpan<E>`. Full derivation + probes: `swift-institute/Research/serialize-parse-codec-attachment-model.md` §12. | RETIRES the canonical operational tier; re-cuts [FAM-002/003/005]; absorbs [FAM-010] | v1.2.0 (parse-shape + composition refined v1.2.1) |

**Implementation state (v1.1.0)**:

| Element | Status | Evidence |
|---------|--------|----------|
| `JSON.Serializable` as non-refining sibling | CONFIRMED (in production) | `JSON.Serializable.swift:94`, commit `0307edc` (J1d) |
| `Plist.Serializable` as shape-compatible sibling | CONFIRMED (in production, pre-J1d) | `Plist.Serializable.swift:3` |
| `XML.Serializable` as shape-compatible sibling | CONFIRMED (in production, pre-J1d) | `XML.Serializable.swift:36` |
| `Binary.Serializable` as L1 byte-stream sibling (half of split pair) | CONFIRMED (in production) | `Binary.Serializable.swift:37` |
| `RFC_8259.Value: Coder_Primitives.Codable` with `JSON.Coder` leaf | CONFIRMED (in production) | `JSON.Coder.swift:110–116`, commit `3500d18` (Arc 1.5) |
| `Optional: JSON.Serializable` parallel to `Optional: Serializable` | CONFIRMED (in production) | `JSON.Serializable.swift:556`, `Optional+Serializable.swift:21`, commit `3f4f897` (W5b) |
| Dual-conformance experiment V1–V4 | CONFIRMED (2026-05-14) | `swift-foundations/swift-json/Experiments/double-json-binary-dual-conformance/` |
| `Binary.ASCII.Serializable` refinement-shape | DEPRECATED | `Binary.ASCII.Serializable.swift:7–8`, commit `b9abbff` (W4d) |
| `ASCII.Parseable: Parser_Primitives_Core.Parseable` (refinement) | RECOMMENDED-FOR-MIGRATION (Φ.1) | `ASCII.Parseable.swift:10–18`, commit `747c28a` |
| Stdlib integer `@retroactive Parseable` + `@retroactive Serializable` (canonical pinning) | RECOMMENDED-FOR-MIGRATION (Φ.3) | `FixedWidthInteger+Parseable.swift:11`, `FixedWidthInteger+Serializable.swift:8` |
| `Binary.Parseable` (NEW peer of `Binary.Serializable`) | LANDED 2026-05-14 — next empirical validator half | This amendment |
| `Binary.Serializable` endianness-parameter enhancement | RECOMMENDED (post-Φ.3) — next empirical validator half | This amendment |
| Apple Codable-successor proposal cite | CONFIRMED (verified by direct thread read 2026-05-14) | This amendment §9 |
| Per-format macros (`@JSONCodable`, etc.) | DEFERRED with explicit triggers | §10 |
| Cross-format synthesis macros | REJECTED on structural grounds | §11 |
| Cross-format round-trip equivalence | OUT OF SCOPE | §11 |
| Streaming/event-emitter shape | DEFERRED | §7, §11 |
| Cross-format-interop currency-type protocol (institute analog of `CommonCodable`) | DEFERRED — acknowledged gap | §9, §11 |
| Per-endianness sibling namespaces (`Binary.LittleEndian.Codable` etc.) | REJECTED on structural grounds (per [FAM-005]) | §5, §7 |
| Operational-layer refinement (`Coder.Protocol: Parser.Protocol, Serializer.Protocol where Parsed == Serialized`) | RECOMMENDED-FOR-MIGRATION (separate source-code arc; scope is small per [BLOG-IDEA-031] — no ecosystem Output-name rename needed; only swift-coder-primitives adds parser+serializer+either dependencies and the refinement; `Either<DecodeFailure, EncodeFailure>` from `swift-either-primitives` carries the unified `Failure` slot for codecs with distinct decode/encode failures) | §3a, [FAM-006] |
| Attachment-layer refinement (`Codable: Parseable, Serializable`) | REJECTED on structural grounds (per [FAM-006]); attachment slots stay independent | §3a, [FAM-006] |
| Decodable / Encodable aliases | REJECTED — institute vocabulary is more precise than Apple's; aliases dilute attachment-vs-operation split | §3a |

**Implementation notes**:

- v1.1.0 DOCUMENTS the convention's empirical state plus refinements emerging from the multi-format-codable-readiness audit + peer-review convergence (Claude ↔ ChatGPT, 2026-05-14). It does NOT prescribe renaming any existing protocol.
- The parser-side refinement-vs-siblings tension is REAL and queued for resolution via Φ.1 + Φ.3.
- The byte-stream sibling pair (`Binary.Parseable` + `Binary.Serializable` with endianness param) is the next empirical close-out. Endianness is a runtime parameter via `Binary.Endianness`, not a sibling namespace dimension.
- Promotion of this Research doc to `swift-institute/Research/` per [RES-002a] triggers when `Binary.Parseable` lands (second non-trivial format-Codable empirically exercising the byte-appender shape's parse direction).

## References

**Convention authoring lineage**:
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` (commit `0307edc`, 2026-05-14, J1d) — formal exemplar
- `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift` (commit `3500d18`, Arc 1.5) — canonical Coder for RFC_8259.Value
- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift` — canonical attachment
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift` — canonical attachment
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift` — canonical attachment

**Shape-compatible siblings (predate J1d formalization; v1.1.0 baseline)**:
- `swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift` — Plist sibling (tree-intermediate)
- `swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift` — XML sibling (tree-intermediate)
- `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift` — Binary L1 byte-stream sibling (half of split pair; needs Binary.Parseable peer)

**Endianness handling reference**:
- `swift-primitives/swift-binary-primitives/Sources/Binary Primitives Core/Binary.Endianness.swift` — runtime endianness enum; the operation parameter the convention uses (NOT a namespace dimension)

**Parser-side migration (Φ)**:
- `swift-foundations/swift-ascii/Research/ascii-codable-unification.md` v1.0.0 — Φ.1 through Φ.7 plan
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift` (commit `747c28a`) — refinement shape, RECOMMENDED-FOR-MIGRATION
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift` (commit `68e02d7`) — canonical pin, RECOMMENDED-FOR-MIGRATION
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift` (deprecation commit `b9abbff` / W4d) — DEPRECATED legacy
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift` — canonical pin, RECOMMENDED-FOR-MIGRATION

**Empirical validation**:
- `swift-foundations/swift-json/Experiments/double-json-binary-dual-conformance/` (2026-05-14) — V1–V4 dual-conformance experiment

**Adjacent docs (v1.1.0 audit)**:
- `swift-foundations/swift-json/Research/multi-format-codable-readiness.md` v1.0.0 (RECOMMENDATION, 2026-05-14) — readiness audit driving the v1.1.0 amendments
- `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` — language-mechanism premise for [FAM-001]
- User memory: `project_parser_serializer_coder_system_framing.md` — framing memo locking in sibling-not-refinement

**External anchors (v1.1.0 NEW)**:
- **Apple/Foundation Codable-successor proposal**: [The future of serialization & deserialization APIs](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585) (Kevin Perry, 2025-03-17 → ongoing). Verified by direct thread read on 2026-05-14: opening post + [reply #33](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585/33) (currency-types problem; format-agnostic protocol introduction). Three of four structural axes confirmed; fourth axis partially aligned; one structural distinction (format-agnostic vs canonical-attachment semantics) acknowledged.
- Rust serde: https://serde.rs/ — inspiration for Apple's visitor pattern; cross-format interop precedent.
- Foundation Codable: SE-0166 + SE-0167 — the architecturally-opposite call (single Codable + per-format encoder dispatch); the convention specifically rejects this lockout.
- Swift Forums threads on Codable extension gaps: [10207](https://forums.swift.org/t/writing-new-encoders-and-decoders/10207), [11836](https://forums.swift.org/t/codable-encoder-and-decoder-implementations-for-other-formats-yaml-xml/11836).

**Peer review (v1.1.0 ratification)**:
- Collaborative discussion transcript: `/tmp/multi-format-codable-review-transcript.md` — CONVERGED 2026-05-14 (Claude Round 3 ↔ ChatGPT Round 3 + Claude peer Round 1 independent assessment)
- Converged plan: `/tmp/multi-format-codable-review-converged.md` — 16-item drafting plan integrated by this amendment
- Naming/architecture refinement (2026-05-14, mid-drafting): both peer reviewers independently flagged `Binary.LittleEndian.Codable` as the wrong abstraction boundary (compound name violating [API-NAME-001]; endianness modeled as sibling format rather than parameter). Corrected to split byte-stream sibling pair `Binary.Parseable` + `Binary.Serializable` with `Binary.Endianness` as operation parameter; codified as [FAM-005].
