# Multi-Representation Value Codec Attachment

<!--
---
version: 1.0.0
last_updated: 2026-06-30
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The institute's family-Codable convention (`family-codable-convention.md`
v1.1.4; `2026-05-15-family-codable-convention.md` [FAM-009];
`sibling-refines-canonical-attachment.md` [FAM-010]) and its readiness
review (`swift-foundations/swift-json/Research/multi-format-codable-readiness.md`
v1.0.0, RECOMMENDATION 2026-05-14) jointly validated the family-Codable
architecture for **tree-intermediate** formats — JSON, Plist, XML — and
explicitly named the open frontier:

> "the multi-format Codable story is structurally validated by three
> tree-intermediate siblings, with the structural contrast (**a non-tree
> byte-stream sibling**) remaining the live forcing-function target."
> — `multi-format-codable-readiness.md` §0

That readiness doc framed the byte-stream sibling as `Binary.Serializable`
(wire) and resolved the *two-sibling coexistence* question (a type may carry
JSON + Binary simultaneously). It did **not** resolve the harder case that
this document addresses: **a single value type with two or more genuinely
distinct byte representations — a binary/wire form AND an ASCII-text form
(and, for IPv6, several text variants) — where the forms are not different
encodings of one field-tree but structurally different serializations of the
same value.** `RFC_791.IPv4.Address` (4 wire bytes vs `"192.168.1.1"`) and
`RFC_4291.IPv6.Address` (16 wire bytes vs RFC 5952 canonical text + variants)
are the concrete forcing functions.

**The irony to resolve.** The canonical `Serializable` protocol's own doc
comment holds up exactly this case as its textbook example:

```swift
// swift-serializer-primitives/Sources/Serializer Primitive/Serializable.swift:14-18
/// ```swift
/// extension IPv4.Address: Serializable {
///     static var serializer: IPv4.Address.Serializer { .init() }
/// }
/// ```
```
[Verified: 2026-06-30 — read Serializable.swift:14-25.]

`Serializable` carries a single `associatedtype Serializer` + `static var
serializer` — the structural commitment to **one** inherent codec ([FAM-002]).
Yet `IPv4.Address` has at least two genuine codecs (wire bytes; dotted-decimal
text), so it is precisely the type that **cannot** satisfy the "one inherent
canonical codec" premise the protocol's example asks it to exemplify. The
poster-child for canonical single-codec attachment is the one type that must
decline it.

This document resolves the question the readiness doc deferred, and in doing so
**gates two held migrations**: the W3 dual-/defunctionalize-witness migration
of IPv4/IPv6 serialization, and the W4 deletion of the `Binary.ASCII` namespace.

## Question

**(a) MODEL.** Should a value with multiple genuine byte representations use
the canonical single-`static var serializer` attachment at all, or the
format-sibling model (`Binary.Serializable` + `ASCII.Serializable` as flat
peers, each carrying its own serializer)?

**(b) SURFACE.** Weigh three call-site/witness-attachment candidates from first
principles + prior art:

1. **Format/serializer passed as a parameter** — claimed to generalize
   [FAM-005] (the assertion being that `Binary.Serializable` already takes a
   `Binary.Endianness` operation parameter); scales to N forms.
2. **Buffer-element dispatch via `Byte.\`Protocol\``** — `ASCII.Code:
   Byte.\`Protocol\``, so one `serialize<Buffer>(_:into:) where Buffer.Element:
   Byte.\`Protocol\`` could target `[ASCII.Code]` ⇒ text vs `[Byte]` ⇒ wire.
3. **Status quo ("Option A")** — explicit `Binary.Serializable` witness (wire)
   + a bespoke `Serializer` reached only via `.serialized` (ASCII text).

## Methodology

Per **[RES-019] internal grep first** (executed 2026-06-30): the
`swift-institute/Research/` and `swift-foundations/swift-json/Research/`
corpora were swept for `canonical`, `serializer`, `multi-format`, `family`,
`codable`, `IPv4`, `IPv6`, `ASCII.Serializ`, `Binary.Serializ`, `sibling`,
`attachment`. Sixteen related docs surfaced; the load-bearing antecedents are
`multi-format-codable-readiness.md`, `family-codable-convention.md`,
`sibling-refines-canonical-attachment.md` ([FAM-010]),
`canonical-attachment-semantic.md` ([FAM-011], SUPERSEDED 2026-05-26),
`operation-domain-naming-and-organization.md` (current naming authority),
`binary-base-n-encoding-family-architecture.md` (asymmetric-substrate codec),
and `transformation-domain-architecture.md` (parse/serialize inverse framing).
**This document EXTENDS `multi-format-codable-readiness.md`'s named-open
forcing function; it does not duplicate it.**

Per **[RES-021] prior-art survey with contextualization**: four external
systems (Rendel & Ostermann invertible syntax; pointfree swift-parsing
ParserPrinter; Rust serde; Swift Codable) surveyed against primary sources
(§4), then *contextualized* — universal adoption is not taken as universal
necessity; each pattern's cost is concretized in the institute's typed-throws +
`~Copyable` + typed-byte-buffer (`[Byte]` vs `[ASCII.Code]`) world before
classification.

Per **[RES-020] parallel subagent verification** and **[RES-023] empirical-claim
verification**: every load-bearing source claim carries a `[Verified:
2026-06-30]` tag. Claims I read personally are tagged with the file:line read;
claims established by two independently-dispatched recon subagents reporting
identical file:line are tagged `[Verified via cross-corroborated recon]`. **Two
premises in the brief were falsified at source** (§2) — the discipline earned
its cost.

Per **[RES-029] framing-challenge for binding questions** and **[RES-022]
structural-correctness framing**: question (b) is decided on *semantic
identity* first (is wire-serialize the same operation as text-serialize?), with
cost/ergonomics as tiebreakers only. The "cheap-decided" status-quo option is
re-derived, not assumed.

---

## Analysis

### 1. The forcing function, precisely

`RFC_791.IPv4.Address` (real type at `swift-ietf/swift-rfc-791`; the
`swift-ipv4-standard` package is a one-line `@_exported import RFC_791` shim)
[Verified: 2026-06-30 — read IPv4Standard.swift:27-58] currently attaches its
codecs as:

| Conformance | File:line | Form | Buffer |
|---|---|---|---|
| `Binary.Serializable` | `RFC_791.IPv4.Address.swift:130` | 4 raw network-order bytes | `Buffer.Element == Byte` |
| `Binary.ASCII.Serializable` (DEPRECATED) | `RFC_791.IPv4.Address.swift:162` | dotted-decimal text, hand-rolled | `Buffer.Element == Byte` |
| `Codable` (stdlib) | (via `CustomStringConvertible`/`ExpressibleByStringLiteral`) | text | — |

[Verified: 2026-06-30 — read RFC_791.IPv4.Address.swift:42, 130-160, 162-210, 322, 346.]

`RFC_4291.IPv6.Address` (at `swift-ietf/swift-rfc-4291`):

| Conformance | File:line | Form |
|---|---|---|
| `Binary.ASCII.Serializable` (DEPRECATED) | `RFC_4291.IPv6.Address.swift:129` | RFC 5952 canonical text, `::`-compression inlined |
| `Binary.Serializable` | `RFC_4291.IPv6.Address.swift:361` | 16 raw big-endian bytes |
| `Binary.ASCII.RawRepresentable` | `:405` | `rawValue: String` via `String(ascii:)` |
| `Codable` (stdlib `Swift.Codable`) | `:463` | single-value container, encodes `.description` (text) |

[Verified: 2026-06-30 — read RFC_4291.IPv6.Address.swift:54-69, 129-197, 361-401, 405-406, 463-483.]

Three structural facts fall out:

1. **Neither type conforms to the canonical `Serializable`/`static var
   serializer`.** The doc-comment example is aspirational, not actual.
2. **Both ride the *deprecated* `Binary.ASCII.Serializable`** — which is
   `public protocol Serializable: Binary.Serializable` (a *refinement* of
   `Binary.Serializable`, carrying `associatedtype Error` + `associatedtype
   Context`). That is exactly the sibling-refines-sibling shape [FAM-010] now
   forbids. [Verified via cross-corroborated recon: 2026-06-30 —
   `swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable
   Primitives/Binary.ASCII.Serializable.swift:16-28`.] The `Binary.ASCII`
   namespace is the **W4 deletion target**.
3. **The wire form and the text form are structurally distinct**, not two
   encodings of one tree: `192.168.1.1` is 11 ASCII characters with dots and
   variable-width decimal digits; the wire form is 4 fixed raw bytes
   `[0xC0, 0xA8, 0x01, 0x01]`. IPv6 widens this: `2001:db8::1` (text, with
   `::`-compression and hex) vs 16 raw bytes, AND the text form has **multiple
   variants** (RFC 4291 §2.2 full / compressed / IPv4-mixed; RFC 5952 canonical
   recommended form). RFC 5952 — "A Recommendation for IPv6 Address Text
   Representation" — even lives in a *separate package* (`swift-ietf/swift-rfc-5952`)
   from the RFC 4291 address type. [Verified: 2026-06-30 — `swift-rfc-5952`
   directory exists; RFC_4291.IPv6.Address.swift:37-40 states "Text parsing and
   serialization are provided by RFC 5952."]

### 2. Two premise corrections (the brief vs. live source)

Per [RES-023], empirical premises in the brief were verified before being built
on. Two failed:

**Correction 1 — `Binary.Serializable` does NOT take a `Binary.Endianness`
operation parameter.** The protocol requirement is:

```swift
// swift-binary-serializer-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:42-55
extension Binary {
    public protocol Serializable: Sendable {
        static func serialize<Buffer: RangeReplaceableCollection>(
            _ serializable: Self, into buffer: inout Buffer
        ) where Buffer.Element == Byte
    }
}
```
[Verified via cross-corroborated recon: 2026-06-30 — two independent reads at :42-55.]
No `endianness:` parameter exists on the requirement. Endianness is applied
*inside* conformances via leaf `rawValue.bytes(endianness:)` calls; the
family-codable doc itself labels the parameter "(endianness param to be added)"
(json doc:474). **Candidate #1's claim that it "generalizes [FAM-005] — Binary
already takes an endianness parameter" rests on a false premise.**

**Correction 2 — [FAM-005] classifies *formats* as siblings and *sub-format
dimensions* as parameters/leaf-instances, never the reverse.** Verbatim:

> [FAM-005] Sibling namespaces correspond to format-level distinctions;
> sub-format dimensions (endianness, radix) are operation parameters or
> leaf-instance selections — NEVER per-dimension sibling namespaces.
> — `family-codable-convention.md:788` [Verified via cross-corroborated recon: 2026-06-30]

Endianness is a sub-format *dimension* of the wire format (same wire bytes,
reordered). Wire-vs-text is a *format-level* distinction (different intermediate
substrate, structurally different output). So generalizing "endianness is a
parameter" to "format is a parameter" runs **against** [FAM-005], not with it.

### 3. The architecture that already exists (verified)

The institute already ships the relevant machinery; the gap is its *application*
to genuinely-multi-representation types.

**Canonical attachment** — one slot, single-codec commitment:
```swift
// Serializable.swift:19-25
public protocol Serializable {
    associatedtype Serializer: Serializer.`Protocol`
    static var serializer: Serializer { get }
}
```
**Operational protocol** — parameterized over its output buffer:
```swift
// Serializer.Protocol.swift:34-68
public protocol `Protocol`<Output, Buffer, Failure>: ~Copyable {
    associatedtype Output
    associatedtype Buffer            // [Byte] for wire, [ASCII.Code] for text
    associatedtype Failure: Swift.Error = Never
    associatedtype Body: ~Copyable
    @Serializer.Builder<Buffer> var body: Body { borrowing get }
    borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
}
```
[Verified: 2026-06-30 — read Serializer.Protocol.swift:34-101; leaf path `Body == Never`, declarative path composes via `@Serializer.Builder`.]

**Two flat sibling protocols already exist, non-refining:**
- `Binary.Serializable` (wire, `Buffer.Element == Byte`) — its own
  `Binary.Serializer<Value>` witness, `Buffer = [Byte]`, `Body = Never`.
- `ASCII.Serializable` — `public protocol Serializable {}` (flat marker, no
  associatedtype, no refinement; "the write peer of `ASCII.Parseable` … both
  non-refining peers of the canonical `Serializable`/`Parseable`"). Its
  witnesses are `ASCII.Serializer`, `ASCII.Decimal.Serializer`,
  `ASCII.Hexadecimal.Serializer`, …, `Buffer = [ASCII.Code]`.

[Verified: 2026-06-30 — read ASCII.Serializable.swift (flat marker `public
protocol Serializable {}`); Binary.Serializable.swift:42-55.]

**Buffer-type dispatch is the shipped text/wire discriminator.** The ASCII
conveniences key on `Serializer.Buffer == [ASCII.Code]`:
```swift
// Serializable+ASCII.swift
extension Serializable where Serializer.Buffer == [ASCII.Code], Serializer.Output == Self {
    public var asciiCodes: [ASCII.Code] { ... }          // text
    public var serialized:  [Byte]      { asciiCodes.map(\.byte) }  // text projected to bytes
}
```
[Verified via cross-corroborated recon: 2026-06-30 — Serializable+ASCII.swift:13-58.]

**The ASCII→binary bridge** — the live tension — is a constrained default:
```swift
// Binary.Serializable+ASCII.swift:19-37  [Verified: 2026-06-30 — read in full]
extension Binary.Serializable
where Self: Serializable, Self: ASCII.Serializable,
      Self.Serializer.Buffer == [ASCII.Code], Self.Serializer.Output == Self {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ serializable: Self, into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: serializable.serialized)   // binary == text-bytes
    }
}
```
The file header is explicit: it "Derives the byte-stream serialize witness from
the canonical `[ASCII.Code]` serializer by projecting each code to its `Byte`"
and "Replaces the deprecated `Binary.ASCII.Serializable: Binary.Serializable`
refinement with a non-refining family-Codable bridge." **This bridge is correct
only when `binary == text-as-bytes`** — i.e. for *text-only* values whose only
serialization is textual. **For IPv4/IPv6 it is wrong**: their wire form (4/16
raw bytes) is not their text bytes. Note the bridge's firing precondition —
`Self: Serializable` (the *canonical* attachment) with `Serializer.Buffer ==
[ASCII.Code]`. This will matter decisively in §6.

### 4. Prior-art survey (primary-source-verified) + contextualization

Per [RES-021]; full primary-source citations in References.

**Rust serde — `Serializer::is_human_readable()`** *(the closest analog,
shipping in std)*. `Serialize`/`Deserialize` are implemented once, format-
agnostic; the format is a `Serializer` passed at the call site. The one hook a
*type* gets is `is_human_readable() -> bool`. The std `net` types use it to emit
**structurally different data-model shapes**:
```rust
// serde/src/ser/impls.rs  (Ipv4Addr)
if serializer.is_human_readable() { serialize_str("192.168.0.1") }   // a STRING
else { self.octets().serialize(serializer) }                          // a [u8; 4]
```
`IpAddr` presents as a `string` to JSON and a *tagged enum of bytes* to bincode.
[Verified — Agent C fetched serde/src/ser/impls.rs at commit 3c97e1b; docs.rs
`is_human_readable`; serde issue #790.] This **confirms the use case is real,
named, and load-bearing in production**. But the *mechanism* is an under-typed
runtime branch: the compiler cannot relate the two shapes; the doc warns the
two forms are explicitly **not required to round-trip** against each other ("a
breaking change"); a single bool **cannot select among IPv6 text variants**
(those still live inside `Display`/`FromStr`); and there is **no typed-buffer
distinction** (serde has one untyped byte sink).

**pointfree swift-parsing — `ParserPrinter<Input, Output>`** *(the structural
match)*. One value carries both directions (`parse` + `print(_:into:)`);
conversions are `Conversion<Input, Output>` with `apply`/`unapply`. N formats =
**N distinct first-class values** — there is no `is_human_readable`-style flag.
Critically, **because `Input` is a type parameter, a wire form and a text form
are literally different types** — `ParserPrinter<[Byte], V>` vs
`ParserPrinter<[ASCII.Code], V>`. Invertibility is author discipline, not
type-enforced. [Verified — Agent C fetched ParserPrinter.swift, Conversion.swift
from main.]

**Rendel & Ostermann, "Invertible Syntax Descriptions" (Haskell Symposium
2010)** *(the theory)*. A single syntax description denotes a *relation* between
abstract type α and concrete syntax, instantiated twice (as `Parser`, as
`Printer`). Built on **partial isomorphisms** `Iso (α→Maybe β) (β→Maybe α)`. The
paper's premise is exactly the IPv6 situation: "a single abstract value usually
corresponds to multiple concrete representations" (§1). "Accept many, emit one
canonical" is native (via `<|>`); "emit several variants" requires several
printer descriptions. [Verified — Agent C fetched the PDF; §§1, 3.1, 3.4, 4.1-4.3.]

**Swift Codable** *(the counter-example)*. One `encode(to:)` describing one
container structure; the format lives in the `Encoder` (JSONEncoder vs
PropertyListEncoder). **No `is_human_readable` equivalent** — a Codable type
*cannot* natively present a structurally different shape to binary vs text; the
escape hatches (`if encoder is JSONEncoder`, `userInfo` flags) are smells that
recouple the model to concrete coder identities. [Verified — Agent C fetched
SE-0166.]

**Contextualization ([RES-021] — adoption ≠ necessity).** serde proves the
*requirement* is real but its *mechanism* (runtime bool) is the wrong fit for a
typed world: it erases the per-representation typed `Failure`, can't carry the
variant axis, carries a documented breaking-change hazard, and has no typed
buffers. Codable's cost is worse (it forbids the requirement). The
ParserPrinter/invertible-syntax family is the **only** surveyed pattern that
treats wire and text as *first-class, separately-typed, bidirectional values* —
and that pattern's "`Input` is the type axis" insight is **already how the
institute's `Serializer.Protocol<Output, Buffer, Failure>` is shaped** (`Buffer`
is the type axis). The institute does not need to import a mechanism; it needs
to apply the one it has.

### 5. Theoretical framing — the two-axis factoring

Light formalism per [RES-022]. Let `V` be a value type. A **representation** of
`V` is a pair `(B, c)` of an output buffer type `B` and a codec `c : V ⇌ B`
(`serialize : V → B` total; `parse : B ⇀ V` partial — a partial isomorphism in
the Rendel-Ostermann sense, with `parse ∘ serialize = id_V` by author
discipline/test, per `transformation-domain-architecture.md:136-137,281`).

The set `Reps(V)` factors along **two orthogonal axes**:

```
Reps(V)  =  Format  ×  Variant

Format   ∈ { wire( [Byte] ),  text( [ASCII.Code] ),  tree( JSON ), ... }   ← the Buffer type
Variant  ∈ { canonical, alt₁, alt₂, ... }  within a fixed Format            ← leaf-instance selection
```

- The **Format axis** is the institute's *sibling-protocol* axis
  (`Binary.Serializable`, `ASCII.Serializable`, `JSON.Serializable`). Each is a
  flat peer ([FAM-001]/[FAM-010]) keyed by its `Buffer` type. This is the
  ParserPrinter "`Input`/`Buffer` is the type axis" insight.
- The **Variant axis** is the institute's *leaf-instance* axis ([FAM-005]).
  Within `text`, IPv6 has `{RFC 5952 canonical, full-form, IPv4-mixed}`; within
  `wire`, an integer has `{big-endian, little-endian}`; within ASCII, an integer
  has `{decimal, hex, base-62}`. These are distinct `Serializer` *values*, never
  distinct protocols.

The **canonical attachment** (`Serializable`/`static var serializer`,
[FAM-002]) is a *third* construct, well-defined **only when `Reps(V)` collapses
to a single inherent codec** — `|Format| = 1 ∧ |Variant| = 1`, the codec being
inherent to `V`'s specification (e.g. `RFC_8259.Value`'s sole codec is JSON;
`Version.Semantic`'s sole codec is the SemVer grammar). For `IPv4.Address`,
`|Format| ≥ 2`; the canonical serializer is therefore **undefined**, not merely
"unset." This is the structural reason IPv4/IPv6 must decline it.

### 6. Question (a) — MODEL

**Recommendation: the format-sibling model. Multi-representation values MUST
decline the canonical `Serializable`/`static var serializer` attachment.**

This is not a new call — it is what the convention already prescribes, made
explicit for the genuinely-distinct-representation case:

- [FAM-002]: the canonical associatedtype "commits the conforming type to a
  single `Coder`/`Parser`/`Serializer` … canonical attachments commit, sibling
  attachments don't." A type with two genuine codecs cannot honestly commit to
  one.
- [FAM-003]: "**Types expected to support multiple independent format
  representations MUST prefer format-specific siblings.**" IPv4/IPv6 are the
  canonical instance of "multiple independent format representations."
- [FAM-010]: siblings are flat peers, never refinements; its own motivating
  example is literally `extension Foo: Binary.Serializable, ASCII.Serializable`.
- `sibling-refines-canonical-attachment.md` already *rejected* the alternatives:
  Option Y (promote one sibling to bear the canonical), Option Z (conditional
  `@_implements` refinement), Option V (multi-slot canonical). Flat peers won.

**The decisive structural lever (the new finding).** Declining the canonical
attachment is not merely a semantic nicety — it is *load-bearing for
correctness*. The ASCII→binary bridge (§3) fires **iff** the type conforms to
the *canonical* `Serializable` with `Serializer.Buffer == [ASCII.Code]`. A
multi-representation value that declines canonical `Serializable` therefore:

1. satisfies [FAM-002]/[FAM-003] (no false single-codec commitment); **and**
2. **structurally disables the wrong-for-it bridge** (which would otherwise
   silently derive its wire form as `text-as-bytes` — a correctness bug);
   **and**
3. sheds the confusing `.serialized: [Byte]` (text-projected-to-bytes)
   convenience (defined on `Serializable where Serializer.Buffer ==
   [ASCII.Code]`), which for a wire-bearing type would collide semantically with
   its real `.bytes` wire accessor.

One decision, three correct consequences. The model question and the
bridge-correctness question are the *same lever*.

**Resolving the irony.** Because IPv4/IPv6 must decline canonical attachment,
the `Serializable.swift` doc-comment example (`extension IPv4.Address:
Serializable`) is not merely ironic — it is a [FAM-002]/[FAM-003] **miscitation**
and a concrete migration deliverable: replace it with a genuine single-inherent-
codec spec-value type (`RFC_8259.Value` or `Version.Semantic`).

### 7. Question (b) — SURFACE

Decided on semantic identity first ([RES-029]).

**Candidate #1 — format/serializer as a runtime parameter: REJECTED.**
- *Premise false* (§2): `Binary.Serializable` takes no endianness parameter, so
  there is nothing to "generalize."
- *Against [FAM-005]* (§2): formats are siblings; only sub-format dimensions are
  parameters. Wire-vs-text is a format.
- *Prior art rejects the mechanism*: this is serde's `is_human_readable` (§4) —
  an under-typed runtime branch (no typed `Failure`, can't carry the variant
  axis, breaking-change hazard, no typed buffers). `family-codable-convention.md`
  §6.1 rejects the serde model as "exactly the lockout the institute's sibling
  design rejects"; `canonical-witness-capability-attachment.md` Option D
  ("Parameterized Canonical", `static func serializer(for:)`) was rejected
  in-corpus ("No prior art for this pattern"). [Verified via cross-corroborated
  recon: 2026-06-30.]

**Candidate #2 — buffer-element dispatch via `Byte.\`Protocol\``: SPLIT VERDICT.**
- *The buffer-**type** discrimination is correct and already shipped* — each
  sibling fixes its own `Serializer.Buffer` (`[Byte]` vs `[ASCII.Code]`); the
  conveniences key on it (§3). Keep this. It IS the Format axis.
- *The proposed **unification** is rejected as a category error.* "One
  `serialize<Buffer>(_:into:) where Buffer.Element: Byte.\`Protocol\``" spanning
  both forms cannot produce structurally different output (4 raw bytes vs
  `"192.168.1.1"`) from a single body without either runtime element-type
  branching (serde's opaque branch, re-imported) or two `where`-clause-
  partitioned overloads — and two `where`-partitioned overloads *are* the
  sibling model with a shared method name, not a unification. Per [RES-029]
  (semantic identity first): **wire-serialize and text-serialize are not the
  same operation** — different output structure, different fallibility (wire
  append is infallible; text *parse* is fallible), and `ASCII.Code ≠ Byte` by
  deliberate byte-discipline ([API-BYTE-001]). Treating them as one operation
  parameterized by element type misrepresents their identity.
- *`Byte.\`Protocol\``'s real role*: it lets the text codec's `[ASCII.Code]`
  output be cheaply *projected* to `[Byte]` for transport (the `.serialized`
  accessor / the bridge) — an output-lowering, not a serialize-body dispatch.

**Candidate #3 — status quo: RIGHT SHAPE, deprecated instantiation → this IS the
recommendation once migrated.** The "Option A" the brief names is the
*deprecated* `Binary.Serializable` + refining `Binary.ASCII.Serializable` pair
that IPv4/IPv6 currently ride. The *non-deprecated* instantiation — two
independent **flat** siblings (`Binary.Serializable` wire + `ASCII.Serializable`
text), each its own leaf witness, surfaced via [FAM-004] accessors — is exactly
the recommended design. So candidate #3, corrected, **converges with** the
buffer-type half of candidate #2 and the model answer of §6.

### 8. The recommended design (ONE plan)

A multi-representation value type attaches its codecs as **flat format
siblings, each a leaf `Serializer.Protocol`/`Parser.Protocol` witness keyed by
its `Buffer` type, with representation variants as leaf instances, and with the
canonical single-codec attachment declined.**

```swift
// ── Format axis: flat sibling protocols, each its own typed witness ──────────

extension RFC_791.IPv4.Address: Binary.Serializable {            // wire, [Byte]
    // HAND-WRITTEN wire witness — 4 raw network-order bytes.
    // MUST NOT route through the ASCII→binary bridge (wire ≠ text-bytes).
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ a: Self, into buffer: inout Buffer) where Buffer.Element == Byte {
        let (o0, o1, o2, o3) = a.octets
        buffer.append(o0); buffer.append(o1); buffer.append(o2); buffer.append(o3)
    }
}
extension RFC_791.IPv4.Address: Binary.Parseable { /* [Byte] → Self, throws(Error) */ }

extension RFC_791.IPv4.Address: ASCII.Serializable {            // text, [ASCII.Code]
    // canonical text witness (dotted-decimal); Serializer.Buffer == [ASCII.Code]
    static var serializer: ASCII.Decimal.Address.Serializer { .init() }
}
extension RFC_791.IPv4.Address: ASCII.Parseable { /* [ASCII.Code] → Self, throws(Error) */ }

// NO `extension RFC_791.IPv4.Address: Serializable` — canonical attachment DECLINED
// (|Format| ≥ 2; [FAM-002]/[FAM-003]). Declining also disables the ASCII→binary bridge.
```

**Call-site surface ([FAM-004] — format-specific instance accessors):**
```swift
let wire: [Byte]       = address.bytes        // Binary.Serializable  — 4 raw bytes
let text: [ASCII.Code] = address.asciiCodes   // ASCII.Serializable   — "192.168.1.1"
let str:  String       = address.description  // text lowered to String
```

**Variant axis for IPv6 (leaf-instance selection, [FAM-005]):**
```swift
let canonical: [ASCII.Code] = address.asciiCodes              // RFC 5952 (default witness)
let full:      [ASCII.Code] = address.ascii(.full)            // 2001:0db8:0000:… (variant instance)
let wire16:    [Byte]       = address.bytes                   // 16 raw bytes
```
The canonical/recommended variant (RFC 5952) is the *default* `ASCII.Serializer`
witness reached by the plain accessor; full-form / IPv4-mixed are additional
named `ASCII.Serializer` **instances** — never additional protocols. This is the
Rendel-Ostermann "N concrete syntaxes = N printer descriptions" shape, realized
as N witness values.

**Why this is the structurally-correct answer (synthesis):**
- It is the *only* surveyed shape that keeps each representation a first-class,
  separately-**typed**, bidirectional value (ParserPrinter's insight), rather
  than a runtime branch (serde) or a hidden coder choice (Codable).
- It honors every existing FAM rule ([FAM-001]/[FAM-002]/[FAM-003]/[FAM-004]/
  [FAM-005]/[FAM-010]) without modifying any of them — **no class-(c)
  escalation** (the canonical attachment protocols are untouched).
- It makes the wire/text typed `Failure`s independent (wire serialize: `Never`;
  text parse: `RFC_791.IPv4.Address.Error`) — impossible under a single
  format-parameter method.

### 9. Migration sketch for IPv4 / IPv6

Research-only; this is a sketch for the W3/W4 executor, not an edit.

| # | Step | Gates |
|---|---|---|
| 1 | Delete the `Binary.ASCII.Serializable` conformances (IPv4:162, IPv6:129) and the `Binary.ASCII` namespace + the deprecated protocol file. | **W4 namespace deletion** |
| 2 | Add `ASCII.Serializable` + `ASCII.Parseable` conformances; relocate the existing inline text logic into a leaf `ASCII.Serializer`/`ASCII.Parser` witness over `[ASCII.Code]`. | W3 |
| 3 | Keep `Binary.Serializable` (hand-written wire witness) + add `Binary.Parseable`; ensure the witness is explicit (the bridge must not fire — guaranteed by step 5). | W3 |
| 4 | IPv6 text variants → named leaf `ASCII.Serializer` instances; RFC 5952 canonical is the default. Consider homing the canonical text witness in `swift-rfc-5952` (where the spec lives), leaving `swift-rfc-4291` to own the wire form — placement sub-question, §12. | W3 |
| 5 | Do **not** conform IPv4/IPv6 to canonical `Serializable` (decline per [FAM-002]/[FAM-003]). This is what disables the ASCII→binary bridge for them. | (a) |
| 6 | stdlib `Swift.Codable` on IPv6 (:463) → re-express as the tree-sibling path: a `JSON.Serializable` whose representation is the canonical text string (IPv6-in-JSON *is* its RFC 5952 text), serialized via the text witness; or retain as Foundation-interop. | — |
| 7 | Fix `Serializable.swift:14-18`: replace the `IPv4.Address` example with a single-inherent-codec spec-value type (`RFC_8259.Value` / `Version.Semantic`). Removes the irony at its source. | — |

**W3/W4 unblock statement.** W4 (delete `Binary.ASCII`) is cleared: the
namespace is fully replaced by the flat `ASCII.Serializable` sibling (Φ.1/Φ.7 of
`ascii-codable-unification.md`), with IPv4/IPv6 as the unmigrated Phase-2
consumers. W3 (dual-/defunctionalize-witness migration) is cleared: the witness
shapes are now specified — two independent flat-sibling leaf witnesses (wire +
text), not one unified codec and not a canonical attachment.

### 10. Cognitive-dimensions check ([RES-025])

| Dimension | Assessment |
|---|---|
| **Visibility** | Each representation is a named conformance + named accessor (`.bytes`, `.asciiCodes`); the wire/text distinction is visible at the type level, not hidden in a coder or a bool. |
| **Consistency** | Same shape as the shipped JSON/Plist/XML/Binary siblings; one extension per format; format-specific accessor per [FAM-004]. |
| **Viscosity** | Adding a new representation (e.g. a future `CBOR.Serializable`) is one additive extension; no edit to existing conformances. Adding a text *variant* is one leaf instance. |
| **Role-expressiveness** | `Binary.Serializable` vs `ASCII.Serializable` reads as "wire form" vs "text form"; variant instances read as "which text shape." |
| **Error-proneness** | The chief hazard — the ASCII→binary bridge silently mis-deriving wire from text — is *structurally* eliminated by declining canonical attachment (§6), not left to author vigilance. |
| **Abstraction gradient** | Consumers use accessors (low); type authors write per-format witnesses (medium); the two-axis factoring (§5) is the only new concept, and it names structure that already exists. |

### 11. Proposed convention codification — [FAM-012] CANDIDATE

Per [RES-006a] and the CLAUDE.md memory-write guardrail, the one *novel*
normative rule below is surfaced as a **candidate for principal ratification via
`skill-lifecycle`**, not unilaterally codified. It does not modify any canonical
attachment protocol (no class-(c) escalation); it applies and lightly extends
[FAM-002]/[FAM-003]/[FAM-005]/[FAM-010]:

> **[FAM-012] (candidate) Multi-representation value types.** A value type with
> two or more *genuinely distinct* byte representations — a wire form whose bytes
> differ structurally from its text form (canonical exemplars:
> `RFC_791.IPv4.Address`, `RFC_4291.IPv6.Address`) — MUST:
> 1. **decline** the canonical attachment protocols (`Serializable`/`Parseable`/
>    `Codable`) per [FAM-002]/[FAM-003]; the single-codec commitment is undefined
>    for it;
> 2. carry each representation as a **flat sibling** ([FAM-001]/[FAM-010]) with
>    its own leaf `Serializer.Protocol`/`Parser.Protocol` witness keyed by its
>    `Buffer` type (`[Byte]` wire, `[ASCII.Code]` text);
> 3. provide a **hand-written** `Binary.Serializable` wire witness — NOT the
>    ASCII→binary projection bridge, which is correct only for *text-only* values
>    (`binary == text-bytes`). Declining the canonical attachment (clause 1)
>    structurally prevents the bridge from firing;
> 4. express representation **variants** within a format (IPv6 RFC 5952 canonical
>    vs full vs IPv4-mixed) as leaf-instance selections per [FAM-005], the
>    canonical/recommended variant being the default witness.

A companion lint candidate (out of scope here): flag any type conforming to BOTH
`Binary.Serializable` and `ASCII.Serializable` (or `JSON.Serializable`) AND the
canonical `Serializable` — the multi-sibling-plus-canonical shape [FAM-003]
forbids.

### 12. Residual / open questions ([RES-027])

These are **directions**, not load-bearing premises (none gates the §8
recommendation):

- **Canonical-text witness placement.** Should IPv6's RFC 5952 canonical text
  witness live in `swift-rfc-5952` (where the spec lives) with `swift-rfc-4291`
  owning only the wire form? This mirrors the existing package split and the
  [FAM-009] namespace-rooted placement rule. A direction for the W3 executor;
  does not change the model.
- **`Binary.Serializer` leaf-witness SIL crash.** The `Body == Never` +
  `fatalError()` leaf-default pattern is under a known SIL crash
  (`serializer-leaf-witness-bodyless-fix-options.md`, catalog A16, Swift 6.5-dev);
  Option-1 fix (relocate the witness to a sibling target) is applied. The IPv4/IPv6
  wire/text witnesses inherit whatever resolution that arc reaches; an
  *experiment* should confirm the migrated witnesses build clean before W3 closes
  (per [RES-027], this is a premise to verify, and the extant
  `swift-binary-serializer-primitives` build is the verification vehicle).
- **A future `Coder` (typed inverse pair) for IPv4/IPv6.** Each format's
  serialize/parse pair could be promoted to a `Coder` (the typed inverse pair,
  `parse ∘ serialize = id` by type, per `transformation-domain-architecture.md`)
  once round-trip is a hard requirement. Not needed for the migration; a
  direction.

---

## Outcome

**Status: RECOMMENDATION.**

**(a) MODEL — the format-sibling model.** A multi-representation value MUST
decline the canonical `Serializable`/`static var serializer` attachment and
carry each representation as a flat, non-refining sibling ([FAM-001]/[FAM-002]/
[FAM-003]/[FAM-010]). For IPv4/IPv6 this is not just convention-compliance:
declining canonical attachment is the *structural lever* that disables the
ASCII→binary bridge that would otherwise mis-derive their wire form from text
bytes. The `Serializable.swift` doc-comment example is a [FAM-002] miscitation
and must be replaced.

**(b) SURFACE — per-representation typed witnesses (candidate #3, migrated),
NOT a format parameter (#1), NOT a unified buffer-element method (#2).**
Candidate #1 is rejected (false premise; against [FAM-005]; it is serde's
under-typed `is_human_readable` branch and the Codable lockout). Candidate #2
splits: the buffer-**type** discrimination is the correct, shipped Format axis;
the proposed buffer-element **unification** is a category error per [RES-029]
(wire-serialize ≠ text-serialize), with `Byte.\`Protocol\``'s real role being
output-lowering, not body dispatch. Candidate #3, migrated off the deprecated
refining `Binary.ASCII.Serializable` onto flat `Binary.Serializable` +
`ASCII.Serializable` peers, IS the recommendation.

**The ONE design (§8):** two orthogonal axes — Format (flat sibling protocols,
keyed by `Buffer` type) × Variant (leaf-instance selection per [FAM-005]) — with
the canonical single-codec attachment declined. Call-site surface via
format-specific accessors ([FAM-004]). IPv6's multiple text variants are leaf
instances, not protocols.

**Gating resolved.** W4 (`Binary.ASCII` namespace deletion) and W3 (dual-/
defunctionalize-witness migration) are both unblocked; the migration sketch
(§9) specifies the witness shapes and the bridge-suppression discipline. This
resolves the "non-tree byte-stream sibling" forcing function that
`multi-format-codable-readiness.md` §0 named as the live unresolved target.

**Class-(c) check.** No canonical attachment protocol is modified. The one novel
rule ([FAM-012] candidate, §11) applies and lightly extends existing FAM rules
and is surfaced for principal ratification via `skill-lifecycle`, not codified
here.

**Promotion note.** `multi-format-codable-readiness.md` (in
`swift-foundations/swift-json/Research/`) named this forcing function and stated
it would promote to `swift-institute/Research/` when a second non-trivial
format-Codable lands. This document is that ecosystem-wide resolution; a
forward-pointer should be added to the readiness doc's Outcome when it is
promoted.

## References

**Primary internal sources** (all `[Verified: 2026-06-30]`):
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitive/Serializable.swift:14-25` — canonical attachment + the IPv4 doc-comment irony
- `…/Serializer Primitive/Serializer.Protocol.swift:34-101` — `Serializer.Protocol<Output, Buffer, Failure>`, Body/Builder, leaf path
- `swift-primitives/swift-binary-serializer-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:42-55` — wire sibling (no endianness param)
- `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable ASCII Primitives/ASCII.Serializable.swift:35` — flat text sibling marker
- `…/Serializable ASCII Primitives/Serializable+ASCII.swift:13-58` — `.asciiCodes`/`.serialized` accessors (buffer-type dispatch)
- `…/Serializable ASCII Primitives/Binary.Serializable+ASCII.swift:19-37` — the ASCII→binary bridge (the live tension)
- `swift-ietf/swift-rfc-791/Sources/RFC 791/RFC_791.IPv4.Address.swift:42,130,162` — IPv4 current dual-protocol state
- `swift-ietf/swift-rfc-4291/Sources/RFC 4291/RFC_4291.IPv6.Address.swift:129,361,405,463` — IPv6 current state incl. stdlib Codable
- `swift-ietf/swift-rfc-5952/` — RFC 5952 canonical-text package (separate from the wire type)

**Convention sources:**
- `swift-foundations/swift-json/Research/family-codable-convention.md` — [FAM-001]:117, [FAM-002]:417, [FAM-003]:427, [FAM-004]:465, [FAM-005]:788, [FAM-006]:141, [FAM-007]:300, [FAM-008]:353; serde rejection §6.1:516-544
- `swift-institute/Research/2026-05-15-family-codable-convention.md` — [FAM-009]:684-691
- `swift-institute/Research/sibling-refines-canonical-attachment.md` — [FAM-010]:835 (rejected Options Y/Z/V)
- `swift-institute/Research/canonical-attachment-semantic.md` — [FAM-011] reserved (Common.Codable currency-type peer; SUPERSEDED 2026-05-26, distinct axis)
- `swift-institute/Research/operation-domain-naming-and-organization.md` — current naming authority; §4.3 attachment-flat-not-refining; `Namespace.Witness` + result-noun alias
- `swift-foundations/swift-json/Research/multi-format-codable-readiness.md` v1.0.0 — the Tier-2 antecedent this doc extends (§0 named-open forcing function)
- `swift-institute/Research/binary-base-n-encoding-family-architecture.md` — asymmetric encode/decode via single-type where-clause partition (Option D)
- `swift-institute/Research/transformation-domain-architecture.md:136-137,281` — parse/serialize inverse; Coder as typed inverse pair
- Skill: `code-surface` [API-IMPL-020] (leaf `Body = Never`), [API-NAME-001b] (subject-first `Binary.Serializer`); `byte-discipline` [API-BYTE-001] (`ASCII.Code`/`Byte` siblings)

**External prior art** (primary-source-verified per [RES-021]/[RES-032]; fetched 2026-06-30):
- Rendel & Ostermann, "Invertible Syntax Descriptions: Unifying Parsing and Pretty Printing," Haskell Symposium 2010 — `https://ps.informatik.uni-tuebingen.de/publications/rendel10invertible/` (§§1, 3.1, 3.4, 4.1-4.3; partial isomorphisms; "one abstract value ↔ multiple concrete representations")
- pointfree swift-parsing — `ParserPrinter.swift`, `Conversion.swift` (main) — `Input`/`Output` type parameters make wire vs text distinct types; N formats = N values
- Rust serde — `Serializer::is_human_readable` (`docs.rs/serde`); `serde/src/ser/impls.rs` (`Ipv4Addr`/`IpAddr` structurally-different shapes per branch); issue #790 — the closest analog; confirms the use case, but an under-typed runtime branch
- Swift Codable — SE-0166 — single container, format in the coder; no `is_human_readable`; the counter-example
