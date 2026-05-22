# Sibling-Refines-Canonical Attachment

<!--
---
version: 1.2.0
last_updated: 2026-05-22
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---

Changelog:
- v1.0.0 (2026-05-21): initial RECOMMENDATION. Codifies [FAM-010]
  forbidding format-specific sibling attachment protocols from
  refining the canonical attachment protocols (Serializable /
  Parseable / Codable). Closes the gap left open by [FAM-001] (no
  associated types on top-level siblings) and [FAM-006] (no
  attachment-vs-attachment refinement among canonicals): sibling-
  refines-canonical fell between the two rules — this doc closes it
  by extending [FAM-006] explicitly to siblings as attachments.
- v1.1.0 (2026-05-22): axis-B-open section added (§10a); [FAM-010]
  reinforced by outside-view review (HANDOFF-multi-format-serialization-fresh-review.md
  — firewalled 36-system survey + corpus-grounded forums-review
  simulation per /swift-forums-review + independent synthesis per
  [RES-020]); semantic axis (canonical attachment meaning, [FAM-002])
  deferred to successor arc HANDOFF-canonical-semantic-axis-b.md.
  §10 [FAM-010] body unchanged.
- v1.2.0 (2026-05-22): axis B RESOLVED via successor arc
  `swift-institute/Research/canonical-attachment-semantic.md` v1.0.0.
  Recommendation: path (c) sanctioned-but-deferred — additive
  `Common.Codable` peer reserved as [FAM-011] alongside the existing
  canonical attachment trio; [FAM-002]'s type-commitment semantic
  retained unchanged; new peer's authoring deferred until empirical
  pull (consumer-driven currency-type need OR Apple New Codable
  proposal reaches formal Swift Evolution pitch). The successor doc's
  tipping-question enumeration (§4) settled "can a sufficiently-rich
  canonical absorb every format's native concerns without translation
  loss" as NO (categorical mismatches for protobuf field numbers + XML
  attribute-vs-element + plist Data/Date; format-shape-leak costs for
  CBOR tags + MessagePack ext types + JSON null-vs-missing-key),
  ruling out path (b)'s effective rich-canonical reframing. §10a
  Disposition updated to `RESOLVED-VIA-PATH-(c)-DEFERRED`. §10
  [FAM-010] body unchanged; v1.2.0 carries forward [FAM-010] for
  axis A and resolves axis B via path (c).
-->

## Context

The institute's family-Codable convention codifies [FAM-001]–[FAM-008] (in
`swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4)
plus [FAM-009] (in `swift-institute/Research/2026-05-15-family-codable-convention.md` v1.0.0).
Together they pin two structural axes:

- **[FAM-001]** Top-level format-specific sibling attachment protocols (`JSON.Serializable`,
  `Binary.Serializable`, `Binary.Parseable`, `ASCII.Parseable`, `Plist.Serializable`,
  `XML.Serializable`) MUST NOT declare associated types. Method-based contract only.
- **[FAM-006]** Attachment protocols MUST NOT refine each other. The canonical trio
  (`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`,
  `Serializer_Primitives_Core.Serializable`) stay flat; only the operational protocols
  (`Coder.Protocol`, `Parser.Protocol`, `Serializer.Protocol`) refine.

What [FAM-001] and [FAM-006] together leave **unaddressed**: the diagonal relationship
between a *sibling attachment protocol* (top-level under its format namespace, flat per
[FAM-001]) and the *canonical attachment protocol* (top-level in its primitives package,
with `associatedtype Serializer`/`Parser`/`Coder`). The current shape — confirmed by
[RES-023] empirical verification (§2 below) — has `Binary.Serializable` flat with no
canonical refinement; symmetrically for `Binary.Parseable`, `ASCII.Parseable`,
`JSON.Serializable`, `Plist.Serializable`, `XML.Serializable`.

The closing arc of the binary-primitives modularization (Core deletion, dimension-
primitives dep removal, finalization of `Binary.Serializable` + `Binary.Parseable`
split-pair) surfaced a consumer-side ergonomic question: a generic algorithm over
canonical `Serializable`,

```swift
func encode<T: Serializer_Primitives_Core.Serializable>(_ value: T) -> T.Serializer.Buffer {
    T.serializer.serialize(value)
}

extension Foo: Binary.Serializable, ASCII.Serializable { ... }
encode(foo)   // ❌ Foo doesn't conform to canonical Serializable
```

fails to accept `Binary.Serializable` types because Binary.Serializable is a sibling,
not a canonical-refinement. The proposal raised by parent context: should
`Binary.Serializable: Serializer_Primitives_Core.Serializable` (and symmetric variants)
be added so the generic surface accepts sibling-conformers automatically?

This Research arc resolves the question.

**Trigger**: parent session's `HANDOFF-sibling-refines-canonical-attachment.md`
dispatch (2026-05-21) following closure of the binary-primitives modularization
arc. The parent session continues separate work; files listed under "Do Not Touch"
in the handoff (binary-primitives / binary-parser-primitives / binary-serializer-
primitives / carrier-primitives / bit-primitives) are not modified by this arc.

## Question

**Should format-specific sibling attachment protocols refine the canonical
attachment protocol of the same family?** Concretely:

- Should `Binary.Serializable: Serializer_Primitives_Core.Serializable`?
- Should `Binary.Parseable: Parser_Primitives_Core.Parseable`?
- Symmetric for `ASCII.Serializable`, `ASCII.Parseable`, `JSON.Serializable`,
  `Plist.Serializable`, `XML.Serializable`, future `MessagePack.Serializable`/
  `Parseable`, future `CBOR.Serializable`/`Parseable`, etc.

## Methodology

Per [RES-019] **internal grep first** (executed at write time): the existing
`swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4 codifies
[FAM-001]–[FAM-008]; `swift-institute/Research/2026-05-15-family-codable-convention.md`
v1.0.0 codifies [FAM-009]. Neither addresses sibling-refines-canonical directly.
`swift-foundations/swift-json/Research/multi-format-codable-readiness.md` v1.0.0
(CROSS-1 §6) audits canonical-attachment associated-type latent risk on
`Coder_Primitives.Codable`/`Parseable`/`Serializable`, but does not consider sibling
refinement of those canonicals. The gap is real; no internal prior research answers it.

Per [RES-021] **prior art survey with contextualization**: Apple Foundation Codable,
Rust serde, Haskell aeson/cassava, Apple Codable-successor proposal — surveyed in §6
with the contextualization step warning that universal adoption ≠ universal necessity.

Per [RES-022] **structural-correctness framing**: the recommendation drives on
structural identity (does refinement violate the foundational rules the convention
stands on?). Cost / migration / pragmatism axes serve as tiebreakers only.

Per [RES-023] **empirical-claim verification**: §2 confirms current protocol shapes
inline with file:line citations.

Per [RES-025] **Cognitive Dimensions analysis**: visibility, viscosity,
role-expressiveness, error-proneness applied in §7.

Per [RES-029] **framing-challenge for placement / membership questions**: the
question is semantic identity ("IS-A `Binary.Serializable` IS-A `Serializable`?") —
ranked first on tier-1 semantic identity, then tier-2 operational behavior of
adjacent siblings, then cost/pragmatism as tiebreakers.

---

## Analysis

### 1. Framing the unaddressed question precisely

The convention's two existing rules:

| Rule | Statement | Where it applies |
|---|---|---|
| [FAM-001] | Top-level format-specific sibling protocols MUST NOT declare associated types. | Sibling layer (top-level under format namespace) |
| [FAM-006] | Attachment protocols MUST NOT refine each other. Canonicals stay flat. | Canonical-vs-canonical refinement at the attachment layer |

The proposed `Binary.Serializable: Serializer_Primitives_Core.Serializable` falls
in the diagonal:

- It's NOT [FAM-001] verbatim — `Binary.Serializable` itself does not *declare* an
  associated type. It would *inherit* one via the refinement, but the declared shape
  of the sibling is method-only.
- It's NOT [FAM-006] verbatim — that rule's example is canonical `Codable` refining
  canonical `Parseable + Serializable`. The proposed refinement is sibling refining
  canonical, which is a different shape.

Neither rule directly answers the question. This arc closes the gap.

The structural test: per [FAM-006]'s general principle — "Attachment protocols MUST
NOT refine each other" — the question is whether siblings are *also* attachment
protocols. The convention's framing is unambiguous on this point. The
`family-codable-convention.md` v1.1.4 §1 names siblings as "format-specific sibling
**attachment** protocols" (emphasis added). [FAM-001] applies to them precisely
because they ARE attachment protocols (just without the canonical's associated-type
slot). Therefore, sibling-refines-canonical IS attachment-vs-attachment refinement
— and [FAM-006] applies.

But the question deserves its own analysis rather than being closed by inference,
because the *direction* matters: canonical→canonical refinement (forbidden by
[FAM-006]) is symmetric peer-refining-peer; sibling→canonical refinement is
asymmetric (no-associatedtype → has-associatedtype). The asymmetry is worth
unpacking before concluding.

### 2. Current protocol shapes — verified at write time

Per [RES-023], every claim below was verified by direct inspection during this
research arc (2026-05-21):

#### Canonical attachment protocols

```swift
// swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19–25
public protocol Serializable {
    associatedtype Serializer: Serializer_Primitives_Core.Serializer.`Protocol`
    static var serializer: Serializer { get }
}

// swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:26–32
public protocol Parseable {
    associatedtype Parser: Parser_Primitives_Core.Parser.`Protocol`
    static var parser: Parser { get }
}
```

(`Coder_Primitives.Codable` has the analogous shape with `associatedtype Coder`,
verified per multi-format-codable-readiness.md §6 audit table.)

#### Format-specific sibling attachment protocols

```swift
// swift-primitives/swift-binary-serializer-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:41–55
extension Binary {
    public protocol Serializable: Sendable {
        static func serialize<Buffer: RangeReplaceableCollection>(
            _ serializable: Self,
            into buffer: inout Buffer
        ) where Buffer.Element == Byte
    }
}

// swift-primitives/swift-binary-parser-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift:61–77
extension Binary {
    public protocol Parseable: Sendable {
        static func parse<Source: RangeReplaceableCollection>(
            from source: inout Source
        ) throws(Binary.Parse.Failure) -> Self
        where Source.Element == Byte
    }
}

// swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift (around line 96)
extension JSON {
    public protocol Serializable {
        static func serialize(_ value: Self) -> JSON
        static func deserialize(_ json: JSON) throws(JSON.Error) -> Self
    }
}
```

Confirmed: every shipped sibling carries NO associated type. Per [FAM-001], each
encodes its contract through method requirements alone. The canonicals carry the
associated-type slot that the proposed refinement would inherit into the siblings.

### 3. Options enumeration

Per [RES-009], all viable alternatives are documented with consistent structure.
Five options are considered (matching the handoff's enumeration), with mechanical
analysis below the table:

#### Option X — Status quo (no sibling refines canonical)

Siblings remain flat per [FAM-001]; canonicals remain unconformed by stdlib /
user-defined types whose codec is format-dependent. Generic algorithms over
canonical `Serializable` accept only spec-value types with an inherent canonical
codec (`RFC_8259.Value`, etc.). Multi-format types compose by holding multiple
sibling conformances and using format-specific instance accessors (`.json`,
`.bytes`) per [FAM-004].

#### Option Y — Promote ONE sibling per family

Designate one sibling per family as the canonical-bearer: e.g.,
`Binary.Serializable: Serializer_Primitives_Core.Serializable` with a default Binary
witness as the associated `Serializer`; the other format siblings
(`JSON.Serializable`, `Plist.Serializable`, …) stay independent. The chosen sibling
becomes the "default canonical" for multi-format types.

#### Option Z — Conditional refinement, gated on conformer choice

Siblings declare no refinement; conformers opt in to canonical via `@_implements`
stamps, picking which sibling's serializer/parser becomes the canonical witness for
each conforming type. E.g.,

```swift
extension Int: Binary.Serializable, JSON.Serializable, Serializer_Primitives_Core.Serializable {
    @_implements(Serializer_Primitives_Core.Serializable, Serializer)
    typealias Serializer = ... // conformer picks one
}
```

#### Option W — Promote-to-canonical helper / explicit wrapper

Provide a generic wrapper or instance accessor that adapts a sibling-conformer
into a canonical-conforming view. E.g., `T.asBinaryCanonical` returns a value of
some wrapper type conforming to canonical `Serializable` with
`Serializer = Binary.SomeCoder`. Original sibling protocols remain flat; the
canonical surface is reachable through explicit promotion.

#### Option V — Multi-slot canonical Serializable

Redesign the canonical to carry multiple associated-type slots:
`associatedtype JSONSerializer`, `associatedtype BinarySerializer`, etc. Rejected
upfront in the handoff because it re-derives the lockout shape [FAM-001] was
designed to escape — but documented for completeness.

### 4. Per-option mechanical analysis

#### Option X — Status quo

**Mechanics**: unchanged. `Binary.Serializable` is `protocol Serializable: Sendable
{ static func serialize<Buffer: ...>(...) }`. No inherited associated-type slot.
Multi-format types conform to multiple siblings freely. Per [FAM-004] consumers
use `.json` / `.bytes` / `.plist` accessors at call sites.

**The "gap" the handoff surfaces is intentional**: `encode<T: Serializable>(_:)`
explicitly rejects sibling-only conformers because the canonical-attachment slot
expresses *"this type has ONE inherent canonical codec"* per [FAM-002]. Stdlib
`Int`, user-defined `Foo`, etc., simply do not have one inherent canonical codec —
their codec is format-dependent. A generic algorithm requiring canonical
`Serializable` is implicitly requiring exactly this single-codec commitment, which
sibling-conforming types deliberately decline. The right consumer pattern is
either:

- **Per-format generic algorithms** with format-specific bounds:
  ```swift
  func jsonEncode<T: JSON.Serializable>(_ value: T) -> JSON { T.serialize(value) }
  func binaryEncode<T: Binary.Serializable, Buffer: RangeReplaceableCollection>(
      _ value: T, into buffer: inout Buffer
  ) where Buffer.Element == Byte { T.serialize(value, into: &buffer) }
  ```
- **Spec-value-typed generic algorithms** with canonical bounds, used only on types
  with one inherent canonical codec (`RFC_8259.Value`).

**Type-safety preservation**: full. No associated-type unification trap; no
@_implements requirement; no inherited slots.

**Extensibility for new formats**: open. Adding `MessagePack.Serializable` requires
no edit to existing siblings or to the canonical.

#### Option Y — One sibling refines canonical

**Mechanics**: `extension Binary { public protocol Serializable: Sendable,
Serializer_Primitives_Core.Serializable { ... } }`. Now every `Binary.Serializable`
conformer must satisfy the canonical's two requirements:

1. `associatedtype Serializer: Serializer_Primitives_Core.Serializer.\`Protocol\``
2. `static var serializer: Serializer { get }`

These do not exist in the current Binary.Serializable surface. Adding them
ecosystem-wide:

- Every primitive conformance (`UInt32`, `Int`, `Array<Byte>`, etc.) needs an
  associated `Serializer` type and a static instance. The existing
  `Binary.Coder<Output>` (in swift-binary-coder-primitives) is the closest candidate,
  but it is generic over `Output` — there is no "default Binary serializer for
  arbitrary T."
- A default extension `extension Binary.Serializable { static var serializer:
  SomeWitness { ... } }` would need to either bind to a specific Coder shape (which
  pins the buffer / output / failure choice into the convention) or invent a new
  general-purpose witness for the byte-stream sibling-conformance path.

**The associated-type trap activates if a second sibling also refines canonical.**
If `JSON.Serializable: Serializer_Primitives_Core.Serializable` ships next, then a
type `Int` conforming to both `Binary.Serializable` AND `JSON.Serializable`
inherits the `associatedtype Serializer` slot through two independent refinement
paths. Per the anchor-merging mechanism documented in `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md`
([BLOG-IDEA-031]) — `AssociatedTypeDecl::getAssociatedTypeAnchor` in
`lib/AST/Decl.cpp` — same-named associated types unify unconditionally across
protocols a single type conforms to. `Int.Serializer` must resolve to a single
concrete type satisfying both the Binary and JSON contract. There is no such type
(JSON's Coder maps to `JSON` tree value; Binary's Coder maps to `[Byte]`).

Option Y is only mechanically consistent if **exactly one** sibling per family
refines canonical, and all others stay flat. This privileges the chosen sibling
asymmetrically with no principled basis: by what criterion would `Binary` be
elevated over `JSON`? Both are format-level distinctions per [FAM-005]; both are
peer siblings under the convention's framing.

**Multi-format symmetry**: BROKEN. The chosen sibling becomes a privileged
"default canonical" while peers do not. The asymmetry has no semantic origin —
it is a packaging convenience masquerading as structure.

**Generic-API uniformity**: only partially restored. `encode<T: Serializable>(_:)`
accepts the chosen sibling's conformers, but not the others. Consumers must still
know which sibling was promoted.

**Type-safety preservation**: brittle. Adding a second canonical-refining sibling
later (the inevitable temptation) re-introduces the lockout — the conformer trap.

**Extensibility for new formats**: cost shifts onto every new sibling — does it
refine canonical (Option Y exception fires) or not (status quo)? The convention
must decide per-sibling, with no structural rule.

#### Option Z — Conditional refinement via @_implements

**Mechanics**: siblings stay flat; conformers add canonical conformance with
`@_implements` stamps to choose which sibling's witness fills the associated
`Serializer` slot:

```swift
extension Int: Binary.Serializable, JSON.Serializable, Serializer_Primitives_Core.Serializable {
    // Pick one sibling's witness as the canonical Serializer:
    typealias Serializer = JSON.IntSerializerWitness   // or Binary.IntSerializerWitness
    static var serializer: Serializer { Serializer() }
}
```

But this only requires `@_implements` if there's anchor ambiguity. With no sibling
refining canonical, no ambiguity exists. The pattern collapses to: "the conformer
explicitly conforms to canonical and picks a default codec," which is exactly
[FAM-002] + [FAM-003] (canonical conformance with explicit justification on
public/spec-value types).

**Per-conformer cost**: every type that wants generic-API uniformity must add an
explicit canonical conformance. This is correct per [FAM-002]: the conformer
declares "this type's *canonical* codec is X." For stdlib types like `Int`, the
canonical conformance is a category error — `Int` has no inherent canonical codec.
Per [FAM-003], adding the conformance would require an explicit justification
comment in the extension; for stdlib types, no such justification exists.

Option Z restates status quo with an explicit per-conformer escape hatch. The
escape hatch already exists in the convention (the conformer can add canonical
conformance with [FAM-003] justification). Option Z adds nothing structurally.

**Multi-format symmetry**: preserved (siblings stay flat).
**Generic-API uniformity**: only for opted-in conformers.
**Type-safety preservation**: full.
**Extensibility**: open.

#### Option W — Promote-to-canonical helper

**Mechanics**: provide a generic adapter that wraps a sibling-conformer into a
canonical-conforming view. E.g., a `Binary.Canonical<T>` wrapper:

```swift
public struct Binary.Canonical<T: Binary.Serializable>: Serializer_Primitives_Core.Serializable {
    public let value: T
    public typealias Serializer = Binary.GenericSerializer<T>
    public static var serializer: Binary.GenericSerializer<T> { .init() }
}

extension Binary.Serializable {
    public var asCanonical: Binary.Canonical<Self> { .init(value: self) }
}

// Consumer:
encode(foo.asCanonical)
```

This requires the existence of `Binary.GenericSerializer<T>` — a Coder-like witness
that knows how to serialize arbitrary `T: Binary.Serializable` through the protocol's
method requirement. This is implementable: the witness's `serialize` method calls
`T.serialize(value, into: &buffer)`.

**Where Option W differs from Option Y**: the canonical conformance lives on the
*wrapper*, not on `Self`. `Int` itself does not conform to canonical `Serializable`;
`Binary.Canonical<Int>` does. No inherited associated-type slot on `Int`. The trap
does not fire even if a symmetric `JSON.Canonical<T>` ships — they are distinct
wrapper types with distinct `Serializer` slots.

**Cost**: a wrapper layer at every promotion site. Generic algorithms over
canonical `Serializable` see `Binary.Canonical<Int>` rather than `Int`; the
underlying `Int` is reachable via `.value`. The buffer type is the wrapper's, not
`Int`'s.

**The convention already has a closer-fit pattern**: per [FAM-004], format-specific
instance accessors (`.json`, `.bytes`) are the consumer ergonomic surface. Option W
generalizes this by adding `.asBinaryCanonical` / `.asJSONCanonical` accessors that
produce wrapper values. For generic algorithms that genuinely require canonical
`Serializable` bounds, this is the structurally clean adapter.

**Multi-format symmetry**: preserved — each sibling can have its own wrapper, no
privilege.
**Generic-API uniformity**: opt-in per call site (consumer wraps the value
explicitly).
**Type-safety preservation**: full.
**Extensibility**: per-sibling wrapper authoring required, but no edit to
canonicals.

#### Option V — Multi-slot canonical Serializable

**Mechanics**: redesign canonical `Serializable` with multiple slots:

```swift
public protocol Serializable {
    associatedtype JSONSerializer: Serializer.Protocol
    associatedtype BinarySerializer: Serializer.Protocol
    associatedtype PlistSerializer: Serializer.Protocol
    // ... one per format
}
```

This re-introduces Codable's lockout shape at the canonical layer with worse
ergonomics: every Serializable conformer must commit to one concrete Serializer
PER FORMAT, with the convention pre-enumerating the supported formats. New formats
require editing the canonical. Stdlib `Int` would need three+ witness types
declared upfront. The associated-type-trap inverts: instead of one slot for many
formats, many slots for one format each — but the failure mode is symmetric, with
the wrong types now committed unilaterally rather than collisions.

Rejected upfront per the handoff. Documented for completeness.

**Multi-format symmetry**: enforced but at a structural cost (open-world for new
formats is BROKEN — adding a new format requires editing canonical, which is the
lockout shape).
**Generic-API uniformity**: full but at the cost of single-codec freedom.
**Type-safety preservation**: shifts trap from anchor-merging to upfront
commitment.
**Extensibility**: ROADBLOCKED.

### 5. Per-option trade-off matrix

Trade-off axes from the handoff plus [RES-025] cognitive-dimensions extensions:

| Criterion | X (status quo) | Y (one sibling) | Z (conditional) | W (wrapper) | V (multi-slot) |
|---|---|---|---|---|---|
| Multi-format symmetry across siblings | YES | NO (privileges one) | YES | YES | YES |
| Generic-API uniformity over canonical `Serializable` | NO — bound is reserved for spec-value types | PARTIAL — only chosen sibling | OPT-IN per conformer | OPT-IN per call site (wrap) | YES |
| Type-safety preservation (anchor-merging avoided) | YES | BRITTLE (breaks if a second sibling adopts the refinement) | YES | YES | YES |
| Conformer ergonomics (effort to write a multi-format conformance) | LOW (one extension per format) | LOW (chosen sibling gets canonical free) | LOW unless conformer wants canonical (then +explicit conformance) | LOW (no per-conformer change) | HIGH (one witness per supported format upfront) |
| Open-world extensibility for new formats | OPEN | OPEN with privileged-sibling drift | OPEN | OPEN (per-sibling wrapper authoring) | CLOSED (canonical edit per format) |
| Consistency with [FAM-001] (no associatedtype on siblings) | YES | NO (siblings inherit Serializer slot) | YES | YES | YES |
| Consistency with [FAM-006] (no attachment-vs-attachment refinement) | YES | NO (sibling refines canonical attachment) | YES | YES (no refinement) | YES (no refinement) |
| Consistency with [FAM-002] (canonical = "ONE inherent canonical codec") | YES (canonical reserved for spec-value types) | NO (canonical leaks to every sibling-conformer) | YES (per-conformer opt-in respects [FAM-003] justification) | YES (canonical conformance lives on wrapper, expressing "this VIEW has one codec") | YES, kind of (multiple inherent codecs reframed as multiple slots — but a different category) |
| Reversibility if wrong | TRIVIAL | HARD — every sibling-conformer ecosystem-wide gained an associated-type slot | TRIVIAL | TRIVIAL | VERY HARD — canonical surface change |

Options Y and V fail multiple structural axes. Z restates status quo with an
escape-hatch already supplied by [FAM-002]/[FAM-003]. W is a clean adapter pattern
that complements status quo without adding any structural commitment.

The axes that decide between X and W:
- **Visibility of the "gap"** at the consumer call site: under X, `encode(foo)`
  fails to compile; the consumer sees the gap. Under W, `encode(foo.asBinaryCanonical)`
  compiles; the wrapping discipline is explicit.
- **Open-world for new formats**: both X and W stay open. W requires per-sibling
  wrapper authoring; X requires per-call-site format-specific bounds.

### 6. Prior art survey (per [RES-021])

#### 6.1 Apple Foundation Codable (SE-0166, SE-0167)

Single canonical `Codable` (refines `Encodable + Decodable`) per type. Format
support lives in encoder/decoder driver types (`JSONEncoder`, `PropertyListEncoder`).
The protocol surface is format-agnostic; format selection is dispatched at the
encoder/decoder construction site.

**Contextualization step** (per [RES-021]): in Swift Foundation, Apple's Codable is
the lockout the institute's convention explicitly rejects per [FAM-002] / the
convention's introductory framing. Apple's design does not face the
sibling-refines-canonical question because there are no siblings: there is only
one canonical, refined into one decode + one encode protocol. The institute's
choice of *siblings instead of refinement* IS the rejection of this design. Apple's
shape is therefore not informative on the sibling-refines-canonical question — it
is the structural opposite.

#### 6.2 Rust serde

Two top-level traits (`Serialize`, `Deserialize`) defined once in the central
`serde` crate. Format crates (`serde_json`, `serde_yaml`, `bincode`, `ciborium`)
implement the dispatched driver side (`Serializer`, `Deserializer` traits). User
types derive `#[derive(Serialize, Deserialize)]` once and work across all formats.

**Contextualization step**: serde's `Serialize` is a single trait corresponding to
the institute's canonical `Codable` — one inherent encoding interface per type,
format-dispatched at runtime by the driver. Rust has no sibling-attachment layer;
the question of sibling-refines-canonical does not arise because there are no
siblings.

The institute's convention deliberately diverges: stdlib `Int`'s representation in
serde's data model is a single fixed integer that format crates render. The
institute's framing is that `Int`'s representation is format-dependent — JSON
encodes it as a number node, ASCII as decimal text, Binary as fixed-width little-
endian bytes — and the type author may pick which formats to support and how. The
convention's siblings let each format choose its own representation independently;
serde's single trait + driver dispatch forces one representation per type per
direction.

Universal adoption of the single-trait + driver-dispatch shape across Rust and
Apple Foundation does NOT imply universal necessity. The institute's design
deliberately escapes the single-codec lockout for stdlib + user-defined types.
Importing serde's shape into the institute would re-derive the lockout.

#### 6.3 Haskell aeson + cassava + serialise

Per-format typeclasses: `FromJSON` / `ToJSON` (aeson), `FromField` / `ToField`
(cassava for CSV), `Serialise` (serialise for CBOR). No central refining class.
Each format library declares its own typeclasses; consumers conform their types to
each format's classes independently.

**Contextualization step**: Haskell's per-format typeclass shape is the closest to
the institute's siblings. Critically, *no* central typeclass refines anything —
each format's classes are top-level and disjoint. The Haskell ecosystem has no
analog of the institute's canonical attachment protocols (no `Serializable`-with-
associatedtype reserved for "this type has one inherent canonical codec"). The
question of sibling-refines-canonical does not arise because there is no canonical
to refine.

This is informative: the structurally closest external ecosystem to the institute's
sibling convention DOES NOT introduce a refining canonical. The siblings stand
alone; consumers compose by conforming to multiple format classes independently.
This is consistent with status quo (Option X).

#### 6.4 Apple Codable-successor proposal (Kevin Perry, 2025)

The proposal introduces per-format "specialized" protocols (`JSONCodable`,
`PropertyListCodable`) ALONGSIDE a format-agnostic `CommonCodable`. The format-
specialized protocols are siblings of each other; `CommonCodable` is closer to the
institute's canonical attachment (for "currency" types with a single shared cross-
format representation).

**Contextualization step**: Apple's proposal explicitly does NOT specify that the
specialized protocols refine `CommonCodable`. From the proposal's framing:
"format-specialized protocols ... should have full freedom to craft their interface
around each format's individual needs and specialties." Refinement of
`CommonCodable` would couple the specialized protocols to its associated-type or
method surface, which the proposal avoids. The siblings stand at peer rank with
the format-agnostic protocol — they do not refine it.

This is the third independent external precedent (Haskell, Apple's proposal,
Rust's lack of canonical) all converging on "siblings do not refine the canonical."
The institute's status quo matches the cross-ecosystem pattern.

#### 6.5 Prior-art synthesis

| Ecosystem | Canonical exists? | Siblings exist? | Siblings refine canonical? |
|---|---|---|---|
| Apple Foundation Codable | YES (Codable) | NO | N/A |
| Rust serde | YES (Serialize, Deserialize) | NO | N/A |
| Haskell aeson/cassava/serialise | NO | YES (FromJSON, ToJSON, FromField, etc.) | N/A |
| Apple Codable-successor (Mar 2025) | YES (CommonCodable, format-agnostic) | YES (JSONCodable, PropertyListCodable) | **NO** — peers, no refinement |
| Institute v1.1.x | YES (Serializable, Parseable, Codable) | YES (JSON.Serializable, Binary.Serializable, ASCII.Parseable, ...) | **NO** (status quo) |

Where canonical + siblings both exist (Apple Codable-successor; institute), the
design chooses NOT to refine. The pattern is convergent: refinement is rejected
in every ecosystem that has both layers.

The prior-art survey supports status quo (Option X). No external precedent
introduces sibling-refines-canonical refinement.

### 7. Cognitive Dimensions analysis (per [RES-025])

Applied to Options X (status quo) and W (wrapper) — the two non-defective
candidates from §4. Reference: Green & Petre's *Cognitive Dimensions of Notations*.

#### Visibility

**X**: the gap at `encode(foo)` is loud — Swift compile error: *"type 'Foo' does
not conform to protocol 'Serializable'."* The consumer immediately sees the missing
conformance. The error message names the canonical protocol; the consumer can look
it up and discover the [FAM-002] / [FAM-003] guidance.

**W**: the gap is medium — `encode(foo)` fails for the same reason, but the fix
is in the call site: `encode(foo.asBinaryCanonical)`. The wrapper accessor must be
discoverable. Discoverability cost is bounded by [FAM-004] (instance-accessor
naming convention) extended with `asBinaryCanonical` / `asJSONCanonical`.

**Y**: the gap is invisible (the chosen sibling auto-conforms). But the *cost* is
hidden — every conformer carries an inherited associatedtype slot without writing
it. When the trap fires later (a second sibling refines canonical), the diagnostic
points at anchor-merging, which is opaque to most consumers.

X scores best on visibility under the standard error path. W is close, with the
wrapper acting as an explicit signal to the consumer that "this is a format-
specific view, not a universal canonical conformance."

#### Viscosity (resistance to local change)

**X**: low. Adding a new format is one new sibling protocol; no edit to the
canonical, no edit to existing siblings. Each conformer adds an extension per
format independently.

**Y**: moderate. The chosen sibling's elevation requires every conformer ecosystem-
wide to have a witness for the inherited `Serializer` slot. Default extensions
papers over the cost for primitive types; user-defined types pay per-type.

**W**: low. Adding a wrapper for a new sibling is one new type. Consumers opt in
per call site.

#### Role-expressiveness

**X**: HIGH. The split between sibling (`extension Foo: Binary.Serializable`) and
canonical (`extension RFC_8259.Value: Coder_Primitives.Codable`) directly expresses
the [FAM-002] semantic: *"siblings declare format-specific representations; canonical
declares an inherent codec."* The consumer reads the conformance and knows the
relationship without ambiguity.

**Y**: LOW. The chosen sibling's refinement obscures the [FAM-002] semantic — a
type that conforms to `Binary.Serializable` "accidentally" claims an inherent
canonical codec via the inherited slot. The conformer did not intend this; it just
wanted byte serialization. The signature lies about the contract.

**W**: HIGH. `foo.asBinaryCanonical` reads as "view this value through the Binary
canonical lens" — explicit promotion, no implicit slot inheritance.

#### Error-proneness

**X**: LOW. The associated-type-trap (anchor-merging) cannot fire because no
sibling carries the canonical slot. The diagnostics at the call site
(`encode(foo)` failing) are immediate and well-known.

**Y**: HIGH (deferred). The trap is dormant until a second sibling adopts the
refinement. The convention would carry a structural bomb that detonates whenever
two siblings happen to share the canonical-refinement choice on the same type —
exactly the failure mode [FAM-001] was designed to prevent. The fix (per
[BLOG-IDEA-031]) requires `@_implements` per conformer, which is a per-bridge-type
remediation, not a structural fix.

**W**: LOW. Wrappers are independent types; their canonical slots cannot
unify on the underlying value.

#### Abstraction (right level for the task)

**X**: the abstraction is at the right level. Format-specific representation is
expressed at the sibling-layer; inherent-canonical-codec commitment is expressed at
the canonical-layer. Each layer has its own protocol shape (method-based vs
associated-type-based) reflecting its semantic role.

**Y**: the abstraction collapses two distinct semantics into one slot — the
chosen sibling's witness becomes "the canonical codec" for the conformer, even
when the conformer has no inherent canonical codec. Wrong abstraction level.

**W**: the wrapper is a clean adapter — promoting a sibling view into a canonical
view at a specific call site. The abstraction is local and explicit.

#### Cognitive-dimensions verdict

| Dimension | X | Y | W | Decision |
|---|---|---|---|---|
| Visibility | strong | weak (hidden trap) | strong | X / W |
| Viscosity | low | moderate | low | X / W |
| Role-expressiveness | strong | weak (lies about contract) | strong | X / W |
| Error-proneness | low | high (deferred trap) | low | X / W |
| Abstraction | right level | collapses semantics | right level | X / W |

Both X and W are structurally sound. Y fails on every cognitive dimension where
the trap activates.

### 8. The structural argument

Per [RES-022], structural correctness drives the recommendation; cost / migration
serves as tiebreaker only.

**The structural argument against sibling-refines-canonical**:

1. **Semantic identity per [RES-029]**: ask "IS a `Binary.Serializable`-conformer
   IS-A `Serializer_Primitives_Core.Serializable`?" The answer is NO. `Serializable`'s
   contract is "this type has ONE inherent canonical serializer" per [FAM-002].
   A `Binary.Serializable`-conformer asserts only that the type has a byte-stream
   serialization — which is one format's representation, not THE canonical
   representation. Conflating them is a category error.

2. **The convention's foundation rests on the no-associatedtype rule**: [FAM-001]
   forbids associated types on top-level siblings because the anchor-merging
   mechanism (`AssociatedTypeDecl::getAssociatedTypeAnchor`) unifies same-named
   associated types unconditionally across a single conformer's protocols.
   Sibling-refines-canonical violates this transitively: every sibling-conformer
   inherits the canonical's `associatedtype Serializer` slot, opening the trap
   the convention was designed to escape.

3. **[FAM-006] explicitly forbids attachment-vs-attachment refinement**: siblings
   ARE attachment protocols per the convention's framing. The rule applies
   verbatim. Sibling-refines-canonical is one direction of attachment-vs-attachment
   refinement that the convention's foundation already disallows.

4. **Prior art is convergent**: every external ecosystem that has both a canonical
   layer and a sibling layer (Apple Codable-successor proposal) explicitly chooses
   NOT to refine. The institute's status quo matches this convergent pattern.

5. **The "gap" at the consumer call site is intentional**, not a defect. Per
   [FAM-002], canonical `Serializable` is reserved for spec-value types with one
   inherent canonical codec. Generic algorithms over canonical `Serializable` are
   implicitly generic over types-with-one-canonical-codec. Stdlib `Int` and user-
   defined `Foo` deliberately decline that commitment. The "fix" the proposal
   offers (refine sibling into canonical) re-introduces the very lockout [FAM-002]
   rejects.

**The structural argument for status quo (Option X)** is the simultaneous
preservation of [FAM-001], [FAM-002], [FAM-006], and the convention's escape from
Codable's lockout. No other option preserves all four.

**Option W** (wrapper) is the structurally-clean adapter for genuine generic-
canonical use cases. It does not modify any protocol; it adds a per-sibling
wrapper type for consumers who explicitly want to lift a sibling view into a
canonical view.

### 9. Consequences for consumer code

The handoff's motivating example:

```swift
func encode<T: Serializable>(_ value: T) -> T.Serializer.Buffer {
    T.serializer.serialize(value)
}

extension Foo: Binary.Serializable, ASCII.Serializable { ... }
encode(foo)   // ❌
```

Under the recommendation (status quo + Option W):

**Path A — format-specific generic algorithm** (preferred for stdlib + user-defined
types):
```swift
func binaryEncode<T: Binary.Serializable, Buffer: RangeReplaceableCollection>(
    _ value: T, into buffer: inout Buffer
) where Buffer.Element == Byte {
    T.serialize(value, into: &buffer)
}

var buffer: [Byte] = []
binaryEncode(foo, into: &buffer)
```

**Path B — explicit canonical conformance** (for spec-value types with one
inherent canonical codec, per [FAM-002] / [FAM-003]):
```swift
extension RFC_8259.Value: Coder_Primitives.Codable {
    /// CANONICAL-ATTACHMENT JUSTIFICATION [FAM-003]:
    /// RFC_8259.Value has exactly one inherent canonical codec — JSON.
    typealias Coder = JSON.Coder
    static var coder: JSON.Coder { JSON.Coder() }
}
```

**Path C — wrapper promotion** (Option W; for the rare case where the consumer
genuinely wants a canonical surface on a sibling-only conformer):
```swift
public struct Binary.Canonical<T: Binary.Serializable>: Serializer_Primitives_Core.Serializable {
    public let value: T
    public typealias Serializer = Binary.GenericSerializer<T>
    public static var serializer: Binary.GenericSerializer<T> { .init() }
}

extension Binary.Serializable {
    public var asBinaryCanonical: Binary.Canonical<Self> { .init(value: self) }
}

encode(foo.asBinaryCanonical)  // ✓ Binary.Canonical<Foo>: Serializable
```

Path A is the consumer-facing default and matches existing institute style.
Path B is the documented canonical exception. Path C is an authored-on-demand
adapter the convention sanctions but does not mandate.

### 10. Recommendation — [FAM-010]

Per [RES-006a], the resolved rule is a candidate for codification as a new
convention rule:

> **[FAM-010] Format-specific sibling attachment protocols MUST NOT refine the
> canonical attachment protocols.** Siblings (`JSON.Serializable`,
> `Binary.Serializable`, `Binary.Parseable`, `ASCII.Parseable`, `Plist.Serializable`,
> `XML.Serializable`, future `MessagePack.Serializable` / `Parseable`, future
> `CBOR.Serializable` / `Parseable`, etc.) remain flat at the attachment layer.
> Consumers needing the canonical surface on a sibling-conforming type either
> (a) declare an explicit canonical conformance with [FAM-003] justification when
> the type has one inherent canonical codec, OR (b) use format-specific generic
> bounds (`<T: Binary.Serializable>` instead of `<T: Serializable>`), OR (c) author
> an explicit promotion wrapper (`Binary.Canonical<T>`) to lift a sibling view into
> a canonical view at the call site.
>
> This rule generalizes [FAM-006] (attachment protocols do not refine each other)
> to siblings, closing the diagonal between [FAM-001] (no associatedtype on
> siblings) and [FAM-006] (no attachment-vs-attachment refinement among canonicals).

This is suitable for promotion to the
`swift-foundations/swift-json/Research/family-codable-convention.md` doc when it
next moves to v1.2.x — OR cross-referenced from a new ecosystem-wide skill
addition. The promotion choice is deferred to a separate skill-lifecycle arc; the
rule is published here as a RECOMMENDATION and is immediately applicable.

#### Application to currently-shipped placements

| Sibling | Currently refines canonical? | Per [FAM-010] should refine? | Action |
|---|---|---|---|
| `JSON.Serializable` | NO | NO | NO CHANGE |
| `Plist.Serializable` | NO | NO | NO CHANGE |
| `XML.Serializable` | NO | NO | NO CHANGE |
| `Binary.Serializable` | NO | NO | NO CHANGE |
| `Binary.Parseable` | NO | NO | NO CHANGE |
| `ASCII.Parseable` | refinement-shape (RECOMMENDED-FOR-MIGRATION per Φ.1) | NO | Already on migration path; Φ.1 closure compatible with [FAM-010] |

**All currently-shipped placements MATCH the recommended rule.** The convention
canonicalizes the existing pattern; nothing breaks. The single not-fully-aligned
sibling (`ASCII.Parseable`'s remaining refinement of canonical `Parseable`) is
already RECOMMENDED-FOR-MIGRATION to flat per `swift-foundations/swift-ascii/Research/ascii-codable-unification.md`
Φ.1; [FAM-010] adds structural weight to the migration but does not introduce a new
action.

#### Risks and reversibility

The rule is reversible — undoing [FAM-010] would require a `RECOMMENDATION → SUPERSEDED`
status transition plus an ecosystem-wide audit. No source code change is implied
by the rule's adoption today; it codifies the existing pattern. The risk is
asymmetric: failing to codify keeps the question recurrent (every future sibling
arc re-litigates it); codifying closes the question with structural backing.

The convention's pre-existing pattern is structurally correct; this Research arc
names and codifies what was implicit.

### 10a. Axis B open question — canonical semantic (v1.1.0)

v1.1.0 incorporates findings from an independent outside-view review
(`HANDOFF-multi-format-serialization-fresh-review.md` — a firewalled investigation
that the parent session dispatched without source-of-truth access to this doc, to
`swift-foundations/swift-json/Research/family-codable-convention.md`, or to any
file under `/Users/coen/Developer/`). The review delivered:

- a 36-system external survey (Rust serde; Haskell aeson/cassava/binary/cereal/serialise;
  OCaml ppx_deriving + atdgen; Scala circe/play-json/upickle/scodec/avro4s/scala-pickling;
  Java Jackson/Gson/Moshi/Kryo; Kotlin kotlinx.serialization; Python
  pydantic/marshmallow/msgspec/cattrs/dataclasses-json; Go encoding/json+xml+gob+binary +
  encoding.* + yaml + protobuf-go + easyjson; .NET System.Text.Json/Newtonsoft/Utf8Json/
  MessagePack-CSharp/protobuf-net; JS/TS zod/io-ts/class-transformer/superjson/cbor-x;
  Protocol Buffers cross-language; Apple Foundation Codable + New Codable prototype),
- a corpus-grounded forums-review thread simulation per /swift-forums-review (archetypes
  c0–c11 from the bundled corpus, venue-stratified angle base rates with Swift-6-era
  multipliers, opener/closer distributions matching observed frequencies, [FREVIEW-012]
  triage classification per post),
- an independent synthesis per [RES-020] forming axis-by-axis recommendations without
  reference to the parent's converged position.

The findings address two axes the parent investigation deliberately separated:

- **Axis A — structural relationship** between per-format protocols and any canonical
  protocol (refinement / siblings / unified-single / hybrid)
- **Axis B — semantic meaning** of canonical conformance (type-commitment / author-choice /
  unify-everything / other)

#### Axis A — [FAM-010] reinforced

The outside-view review's axis-A finding directly reinforces [FAM-010]:

1. **36-system convergence**. Of every production-grade library surveyed, refinement
   (per-format protocols extending a canonical) is "essentially absent." Newtonsoft.Json's
   honoring of legacy `[Serializable]` / `[DataContract]` is the closest production
   instance, and the survey characterizes it as interop, not refinement.

2. **Coherence-theoretic citation**. The review cites Bottu et al. 2019 "Coherence of
   Type Class Resolution" (arXiv:1907.00844) and Racordon 2025 (arXiv:2502.20546) plus the
   ezyang coherence write-up (http://blog.ezyang.com/2014/07/type-classes-confluence-coherence-global-uniqueness/)
   as the theoretical reason refinement is absent: any system that allows a canonical
   protocol with two refining-format protocols introduces dispatch ambiguity when a single
   type conforms to both. This matches §8's anchor-merging argument exactly.

3. **Apple's New Codable prototype** (forums.swift.org/t/78585 and /t/85186, Kevin Perry
   2025) ships its format-specialized protocols as **siblings of, not refinements of,**
   `CommonEncodable`/`CommonDecodable`. Quoting Perry: *"format-specialized protocols are
   expected to be entirely distinct from the format-agnostic one, but they should share
   the same basic structure and patterns."* Independent corroboration from a parallel
   production design context.

[FAM-010]'s structural body (sibling-refines-canonical MUST NOT happen) is reinforced.
§10's rule body and the in-production placement table are unchanged.

#### Axis B — [FAM-002] challenged

The outside-view review's axis-B finding challenges [FAM-002]'s current statement: *"The
associatedtype on canonical attachment protocols is the structural enforcement of 'exactly
one inherent codec per spec-value type.'"* Three findings interact with this:

1. **Cross-ecosystem convergence on hybrid axis-A paired with author-choice-with-fallback
   axis-B** (Phase 0 cross-ecosystem patterns, summary section). Two ecosystems with 12+
   years between them — Go's `encoding.BinaryMarshaler` / `TextMarshaler` (2013, per Russ
   Cox's golang-dev thread justifying that `time.Time`-style cross-format types don't
   scale via per-format methods) and Apple's New Codable prototype (2025) — converged
   independently on the same structural shape: the canonical is a *narrow fallback
   contract*, not a primary authoring surface; per-format protocols carry rich format-
   native semantics; encoders are required to accept both. Both pair this structural
   choice with an author-choice-with-fallback semantic: currency types conform to the
   canonical only and gain every format for free; opinionated types layer per-format
   protocols on top.

2. **Axes A and B are not independent** (Phase 1 post 10's load-bearing observation,
   archetype c9 essay reviewer). The fresh-view forums-review simulation surfaced four
   joint positions in the design space:

   | Axis A | Axis B | Production instances |
   |---|---|---|
   | refinement | type-commitment | none (coherence-fragile) |
   | unified-single | unify-everything | Codable 2017, serde, kotlinx.serialization |
   | sibling | author-choice-per-format | Haskell aeson/cassava/binary; OCaml PPX |
   | hybrid | author-choice-with-fallback | Go `encoding.*`, Apple New Codable |

   The institute's current shape ([FAM-010] axis A + [FAM-002] axis B) is structurally
   close to position 4 — siblings + canonical without refinement — but [FAM-002]'s "ONE
   inherent canonical codec" semantic reads as type-commitment (position 2's axis B). The
   combination is internally consistent only when "canonical" is read as "the inherent
   codec when one exists; nothing when it doesn't" — a *partial* type-commitment scoped to
   spec-value types. [FAM-003]'s guarded-use rule effectively encodes this scoping today.
   But the position-4-vs-position-2 axis-B question is not resolved by the convention's
   current rules; it sits unaddressed.

3. **The tipping question** (Phase 2 independent synthesis). The review names the open
   empirical question that bears on axis B: *"can a sufficiently-rich canonical container
   API absorb every format's native concerns (CBOR tags, protobuf field numbers, plist
   data types, JSON null-vs-missing-key, MessagePack ext types, XML attribute-vs-element)
   without translation loss?"* If yes, unified-single + per-format encoder strategies wins
   (the kotlinx.serialization model). If no, hybrid + per-format siblings carries the
   format-native semantics the canonical can't. The survey's evidence leans no: Codable's
   snake_case ambiguity (forums.swift.org/t/69542), serde issue
   [#1556](https://github.com/serde-rs/serde/issues/1556) on PDF datatype loss, Jackson's
   per-format annotation packages, kotlinx's per-format annotation namespaces all suggest
   the canonical *de facto* fragments along format even when *de jure* it doesn't. But
   the question is genuinely open and bears directly on what [FAM-002]'s canonical
   semantic should commit to.

#### Three resolution paths

Three structurally-distinct paths forward, all consistent with [FAM-010]:

**(a) Preserve [FAM-002] type-commitment.** The canonical attachment protocols remain
"ONE inherent canonical codec per spec-value type," with [FAM-003]'s guarded-use rule
scoping conformance to types that genuinely have one inherent codec (`RFC_8259.Value`,
`RFC_3986.URI`, etc.). The fresh-view's "author-choice-with-fallback" framing is rejected;
the institute's design IS type-commitment-scoped-to-spec-value-types. Non-spec-value
types like `Int` continue to have no canonical-conformance path — the "consumer triage"
cost the fresh-view counterargument names is accepted as a deliberate design property.

Trade-off: preserves the canonical's narrow semantic and avoids any [FAM-002] rewrite;
keeps the institute distinct from Apple's New Codable shape; pays the cost that the
canonical surface stays narrow and generic algorithms over it accept only spec-value-type
conformers.

**(b) Reframe canonical to author-choice-with-fallback per the fresh view.** [FAM-002] is
rewritten to express that canonical conformance means "this type can be serialized to a
minimum-common shape that any encoder driver supports — a fallback for the canonical
surface only." Per-format siblings (per [FAM-010]) remain the primary authoring surface;
the canonical's role becomes a thin lowest-common-denominator floor. [FAM-003]'s guarded-
use rule may relax — the canonical is no longer a singular commitment but a fallback
declaration that more types could reasonably make.

Trade-off: substantial semantic-rewrite cost across the convention (every [FAM-*] rule
reasoning about [FAM-002]'s commitment semantic needs revisiting); resets the canonical's
role to one closer to Apple's New Codable `CommonCodable`; potentially expands the set of
types that can/should carry canonical conformance, which interacts with [FAM-009]'s
substrate-friction placement rule in ways the present convention does not address.

**(c) Introduce a thin CommonCodable analogue alongside the existing canonical, leaving
[FAM-002] intact.** The institute keeps the existing canonical attachments
(`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`,
`Serializer_Primitives_Core.Serializable`) with their [FAM-002] type-commitment semantic
for spec-value types, AND introduces a peer protocol (analogous to Apple's New Codable
`CommonCodable`) carrying the author-choice-with-fallback semantic for non-spec-value
types. Two canonical-tier protocols with distinct semantics: the existing for "ONE
inherent codec" types; the new for "this type can fall back to a common shape across
formats." Per-format siblings continue per [FAM-010] without refining either.

Trade-off: introduces a second canonical-tier protocol with attendant naming question
(placement under [FAM-009], slot semantics, refinement relationships with the existing
canonical, layer home); avoids the broad [FAM-002] semantic rewrite of (b) by additively
introducing the new shape instead of revising the existing; produces a structure most
similar to Apple's New Codable prototype while preserving the institute's pre-existing
[FAM-002] commitment for spec-value types.

#### Disposition

**Axis A**: REINFORCED. [FAM-010]'s structural rule and §10's recommendation stand
unchanged. v1.1.0 carries the rule forward without modification; v1.2.0 leaves it
unchanged.

**Axis B (v1.2.0)**: **RESOLVED-VIA-PATH-(c)-DEFERRED.** The successor arc
`swift-institute/Research/canonical-attachment-semantic.md` v1.0.0 (2026-05-22)
recommends **path (c)** — an additive `Common.Codable` peer alongside the existing
canonical attachment trio, sanctioned-but-deferred until empirical pull surfaces
(consumer-driven currency-type need OR Apple New Codable proposal reaches a formal
Swift Evolution pitch). The recommendation is codified as [FAM-011] (sanctioned-but-
deferred). [FAM-002]'s type-commitment semantic is retained UNCHANGED for the
existing canonical attachment trio; the new peer carries author-choice-with-fallback
semantic for currency types (Range, CGRect, UUID, etc.).

**Key findings from the successor arc**:

1. **Workspace-wide canonical-attachment conformer inventory** (per [HANDOFF-021]
   live output): Class I spec-value-type commitments (`RFC_8259.Value`,
   `Version.Semantic`, `Version.Tools`, `Version.Calendar`, `Glob.Pattern`) — exactly
   match [FAM-002] type-commitment semantic; Class II generic-instantiated
   delegations (`Tagged`, `Optional`) — semantically neutral lifting pattern;
   Class III legacy stdlib pins (10 `FixedWidthInteger` integers) — RECOMMENDED-FOR-
   MIGRATION per Φ.3, treated as defects to remove under both paths (a) and (c).
   The operational state already aligns with type-commitment-scoped-to-spec-value-
   types; path (a) is not aspirational, it is operationally correct today.

2. **Apple New Codable live state** (verified 2026-05-22 against forums.swift.org
   per [RES-031]): t/78585 has 178 posts, last reply 2026-03-06; t/85186 has 71
   posts, last reply 2026-05-22 (active). Prototype IS structurally path (c) —
   additive `CommonEncodable`/`CommonDecodable` peer alongside
   `JSONEncodable`/`JSONDecodable` siblings. Perry's verbatim opening-post quote:
   *"these format-specialized protocols are expected to be entirely distinct from
   the format-agnostic one, but they should share the same basic structure and
   patterns."* — confirms peer relationship, not refinement. Data/Date strategy
   handling remains open in the prototype design conversation.

3. **Tipping question settled NO** (per §4 enumeration of CBOR tags / protobuf
   field numbers / plist Data/Date / JSON null-vs-missing-key / MessagePack ext
   types / XML attribute-vs-element against any sufficiently-rich canonical):
   protobuf field numbers and XML attribute-vs-element are categorically distinct
   from key-value formats and have no canonical analog without distorting other
   formats; CBOR tags / MessagePack ext / plist Data/Date can be absorbed only at
   the cost of format-shape leak; JSON null-vs-missing-key is asymmetrically
   absorbable. Implication: the canonical CANNOT be a rich primary surface
   (path (b)'s effective shape). Must be either narrow type-commitment (a) or
   thin floor (c's new peer).

4. **[FAM-011] sanctioned-but-deferred** is the recommended resolution: pre-codify
   the design-space reservation without authoring the protocol family today. Per
   [RES-027] no premise carried forward without empirical pull; the deferral
   discipline itself is the mechanism by which future empirical needs (currency-
   type consumer friction OR Apple formal pitch) surface explicitly.

**Migration cost under v1.2.0**: zero source-code changes; zero existing-rule
rewrites; one new rule reservation ([FAM-011]) added at the convention level. The
existing canonical attachment trio continues unchanged; Class I conformers retain
their [FAM-003] justifications; Φ.3 stdlib-pin removal continues. The new
`Common.Codable` peer is not authored at this revision.

**Cross-monitoring trigger**: when Apple's New Codable proposal reaches a formal
swift-evolution pitch, the institute SHOULD re-audit BOTH [FAM-010] (axis A) AND
[FAM-011] (axis B) against the formal-pitch shape. Current expectation per
Perry's prototype framing through 2026-05-22: siblings remain peers of the
common protocol (corroborates [FAM-010]); the common protocol carries author-
choice-with-fallback semantic (corroborates [FAM-011] path c). The pitch's
formal text governs the institute's adoption decision.

Findings destination for the successor arc:
`swift-institute/Research/canonical-attachment-semantic.md` v1.0.0 (RECOMMENDATION,
Tier 2 ecosystem-wide). v1.2.0 of this doc cites the successor's outcome and
forwards [FAM-011] alongside [FAM-010] as the convention's axis A + axis B
resolutions.

### 11. Loose ends (per [RES-027])

#### Premise items (require empirical backing)

None. The recommendation is structurally derived; no premise about external
state is asserted that would benefit from a verification spike.

#### Direction items (deferred, not load-bearing)

1. **Skill-promotion of [FAM-010]** alongside the eventual move of the per-package
   family-codable-convention doc to ecosystem-wide scope. Deferred per the
   skill-lifecycle process. Per [RES-006a], a candidate skill addition is the
   `code-surface` or a new `codable-conventions` skill. Note: [FAM-010] is the
   third FAM-rule to live exclusively in research notes (after [FAM-009] in
   `2026-05-15-family-codable-convention.md`); the cumulative load argues for
   eventual consolidation into a single ecosystem-wide doc + skill.

2. **Option W wrapper authoring** (`Binary.Canonical<T>`, `JSON.Canonical<T>`,
   etc.) is sanctioned by [FAM-010] but not mandated. Authoring is deferred
   until at least one consumer surfaces a genuine generic-canonical need on a
   sibling-only conformer. The convention does not pre-emptively author adapters.

3. **Apple Codable-successor proposal cross-monitoring**: when Apple's proposal
   reaches a formal Swift Evolution pitch, the institute SHOULD re-audit the
   sibling-refines-canonical question against the formal-pitch shape. If Apple's
   `CommonCodable` is positioned such that the specialized protocols
   *do* refine it, the institute's [FAM-010] may need a contrasting-design
   amendment. Current expectation: Apple's siblings will remain peers (per the
   proposal's framing through 2025), but the pitch's formal text governs.

---

## Outcome

**Status**: RECOMMENDATION (initial publication; ready for promotion to skill on
principal authorization).

### Conclusion

Format-specific sibling attachment protocols MUST NOT refine the canonical
attachment protocols of the same family. The status quo is structurally correct
and consistent with [FAM-001] + [FAM-002] + [FAM-006] + the convention's
foundational rejection of Codable's single-codec lockout. The "gap" at consumer
call sites (a generic algorithm over canonical `Serializable` not accepting
sibling-only conformers) is intentional and reflects the canonical-attachment
semantic of "ONE inherent canonical codec per spec-value type." Consumers needing
the canonical surface follow one of three documented paths (format-specific
generic bounds, explicit canonical conformance with [FAM-003] justification, or
Option W wrapper promotion).

### Concrete decisions

1. **No changes to currently-shipped siblings**. All six in-production siblings
   (`JSON.Serializable`, `Plist.Serializable`, `XML.Serializable`,
   `Binary.Serializable`, `Binary.Parseable`, `ASCII.Parseable`) MATCH the
   recommended rule.

2. **[FAM-010] is a candidate for skill promotion** alongside the eventual
   move of the per-package family-codable-convention doc to ecosystem-wide
   scope.

3. **`ASCII.Parseable`'s remaining canonical-refinement** is already
   RECOMMENDED-FOR-MIGRATION per Φ.1 in `ascii-codable-unification.md`; the
   migration is structurally compatible with [FAM-010]. No additional
   dispatch arises from this arc.

4. **Option W wrappers** are sanctioned but not mandated. Authoring is deferred
   until consumer demand surfaces.

### Next steps

1. Principal review of this RECOMMENDATION. On acceptance, promote [FAM-010]
   into the family-codable-convention.md doc at next version bump (v1.2.x) OR
   into a new ecosystem-wide skill (alongside [FAM-001]–[FAM-009]).

2. No source code changes are implied by the rule's adoption today.

3. When Apple's Codable-successor proposal reaches a formal Swift Evolution
   pitch, re-audit this rule against the pitch shape per loose-end #3 above.

### Cross-references

- Per-package convention doc: `swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4 — [FAM-001]–[FAM-008]
- Placement-rule companion: `swift-institute/Research/2026-05-15-family-codable-convention.md` v1.0.0 — [FAM-009]
- Multi-format readiness audit: `swift-foundations/swift-json/Research/multi-format-codable-readiness.md` v1.0.0 — CROSS-1 canonical-attachment associated-type latent risk
- Operational-layer refinement plan: `swift-foundations/swift-json/Research/coder-refinement-migration-plan.md` — [FAM-006] in production
- Associated-type-trap blog post: `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` ([BLOG-IDEA-031]) — language-mechanism premise
- Primitives skill: `swift-institute/Skills/primitives/SKILL.md` [PRIM-FOUND-004] — substrate-friction rule (used by [FAM-009])
- Framing memo: `project_parser_serializer_coder_system_framing.md`

## References

### Internal (primary)

- `swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4 — [FAM-001] through [FAM-008]
- `swift-institute/Research/2026-05-15-family-codable-convention.md` v1.0.0 — [FAM-009]
- `swift-foundations/swift-json/Research/multi-format-codable-readiness.md` v1.0.0 — empirical-baseline N=3 finding + CROSS-1 audit
- `swift-foundations/swift-json/Research/coder-refinement-migration-plan.md` — [FAM-006] operational-layer refinement in production
- `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` ([BLOG-IDEA-031]) — anchor-merging language mechanism + `@_implements` escape hatch

### Empirical anchors (verified file:line at write time per [RES-023])

- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19–25` — canonical attachment with `associatedtype Serializer`
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:26–32` — canonical attachment with `associatedtype Parser`
- `swift-primitives/swift-binary-serializer-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:41–55` — sibling, flat, no associatedtype
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift:61–77` — sibling, flat, no associatedtype, typed throws Binary.Parse.Failure
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` (around line 96) — JSON sibling, flat, no associatedtype

### External (per [RES-021] contextualization)

- [Apple/Foundation Codable-successor proposal](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585) (Kevin Perry, 2025-03-17 → ongoing) — sibling specialized protocols + format-agnostic `CommonCodable`; siblings remain peers, not refinements
- [Foundation Codable SE-0166](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0166-swift-archival-serialization.md) + [SE-0167](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0167-swift-encoders.md) — single canonical Codable, format-driver dispatch
- [Rust serde](https://serde.rs/) — `Serialize` / `Deserialize` as canonical traits with format-driver dispatch
- [Haskell aeson](https://hackage.haskell.org/package/aeson) — per-format `FromJSON` / `ToJSON` typeclasses, no central refining class
- [Haskell cassava](https://hackage.haskell.org/package/cassava) — per-format `FromField` / `ToField` typeclasses for CSV
- [Haskell serialise](https://hackage.haskell.org/package/serialise) — per-format `Serialise` typeclass for CBOR

### Process anchors

- [RES-002a] Research triage — ecosystem-wide scope per [META-005]
- [RES-003] Document structure
- [RES-003c] Research index entry per `_index.json`
- [RES-006a] Documentation promotion — research findings to skill
- [RES-009] Multi-option analysis
- [RES-013a] Synthesis verification — carry-forward findings must be verified
- [RES-019] Internal grep — applied in §1 (no prior research covers the gap)
- [RES-020] Tier classification — Tier 2 (cross-package, reversible, codification of an existing pattern)
- [RES-021] Prior art contextualization — applied in §6
- [RES-022] Structural correctness framing — applied in §8 + §10
- [RES-023] Empirical claim verification — applied to every file:line citation in §2
- [RES-025] Cognitive Dimensions analysis — applied in §7
- [RES-027] Loose-end follow-up — §11 distinguishes premise items (none) from direction items
- [RES-029] Framing-challenge for placement / membership questions — applied in §8 (IS-A test)
