# Serialize/Parse Codec-Attachment Model

<!--
---
version: 1.0.0
last_updated: 2026-06-30
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
supersedes:
  - multi-representation-value-codec-attachment.md   # v1.0.0 — the per-corner "decline canonical" carve-out, generalised here
recuts:
  - 2026-05-15-family-codable-convention.md          # [FAM-002]/[FAM-003]/[FAM-005] re-cut proposed (class-(c) surface, not made)
  - sibling-refines-canonical-attachment.md          # [FAM-010] absorbed by the dissolution
resolves:
  - family-codable-contextual-parsing.md             # OQ2 — context-bearing parsing
governing_conventions:
  - 2026-05-15-family-codable-convention.md
  - swift-foundations/swift-json/Research/family-codable-convention.md
---

Changelog:
- v1.0.0 (2026-06-30): initial Tier-3 RECOMMENDATION. First-principles re-derivation
  (explicit principal directive: the principle leads, the code conforms; existing
  documents are NOT accepted as fact) of the ecosystem-wide serialize/parse
  codec-attachment model — call-site surface AND protocol structure. Supersedes the
  narrower "multi-representation values DECLINE the canonical attachment" carve-out of
  `multi-representation-value-codec-attachment.md` v1.0.0 with the universal
  static-verb / self-contained-sibling model in which the canonical operational tier
  DISSOLVES (|siblings| = 1 IS "single inherent codec"). Six embedded /experiment-process
  probes (Swift 6.3.3, throwaway /tmp per principal directive) settle every load-bearing
  empirical premise; prior art (serde, swift-parsing, Codable, Rendel-Ostermann,
  swift-iterator-primitives) primary-source-verified per [RES-020]/[RES-032]. Includes
  the addendum sink-model resolution (RangeReplaceableCollection default + OutputSpan
  perf path; no sink protocol). [FAM-012] surfaced as a skill-lifecycle ratification
  CANDIDATE; canonical-protocol modifications surfaced, not made (class-(c)).
-->

> **Headline.** A format codec is a **self-contained, flat sibling protocol carrying its OWN
> static universal verb** `serialize<Buffer: RangeReplaceableCollection>(_ value: borrowing
> Self, into: inout Buffer) where Buffer.Element == <FormatElement>` (and the dual `parse`).
> **The FORMAT is the sink's element type** (`Byte` ⇒ wire, `ASCII.Code` ⇒ text, the tree node
> ⇒ tree); the collection is free. A type conforms to **exactly the siblings it has** —
> `|siblings| = 1` IS the "single inherent codec" case, `|siblings| ≥ 2` is multi-representation,
> and **both are ordinary**: there is no canonical attachment to decline and no derivation
> bridge. **VARIANTS** (IPv6 RFC 5952 / full / IPv4-mixed; endianness; radix) and **parse
> CONTEXT** (URL base, multipart boundary) are carried by a **witness VALUE passed in** — the
> witness carries the operation's parameters, you pass the witness — never by an `associatedtype`
> on the flat marker. The canonical single-slot `static var serializer` operational attachment
> is **retired** for byte/text streams (you cannot serialize without choosing an element type =
> a format). The **ASCII→binary projection bridge is deleted**. This supersedes the
> per-corner "decline canonical" patch; the answer is ecosystem-wide.

---

## Context

### The carve-out being superseded

`multi-representation-value-codec-attachment.md` v1.0.0 (RECOMMENDATION, 2026-06-30) resolved
the IPv4/IPv6 forcing function by a **carve-out**: multi-representation value types are *special*
— they MUST **decline** the canonical `Serializable`/`static var serializer` attachment, which
"structurally disables" the ASCII→binary bridge that would otherwise mis-derive their wire form
from text bytes. That doc keeps the canonical operational tier, keeps `ASCII.Serializable` a bare
marker, keeps the bridge for "text-only" types, and treats IPv4/IPv6 as the exceptional case that
opts out. Its proposed `[FAM-012]` reads "multi-representation value types MUST decline the
canonical attachments."

The principal's directive for this arc: **the answer is ecosystem-wide, not a dual-D carve-out.**
The forcing functions remain `RFC_791.IPv4.Address` (4 wire bytes vs `"192.168.1.1"`) and
`RFC_4291.IPv6.Address` (16 wire bytes vs RFC 5952 text + variants), but the principally-correct
serialize/parse codec-attachment model — *the call-site surface AND the protocol structure* — must
be re-derived **from first principles**: the principle leads, the code conforms to it; existing
documents are NOT accepted as fact (including the v1.0.0 doc and the `[FAM-*]` convention docs,
which are read as prior art / leads per [RES-013a], not ground truth). This document is that
re-derivation. It does not patch a corner; it removes the structure that made the corner sharp.

### The root-cause asymmetry (live source, [Verified: 2026-06-30])

Live-source recon (authoritative over the dated docs per [RES-013a]) shows the codec surface is
**asymmetric**, and the asymmetry is the entire source of the carve-out:

- `Binary.Serializable` **already carries a static universal verb over a generic buffer** —
  `swift-binary-serializer-primitives/.../Binary.Serializable.swift:42-55`:
  ```swift
  public protocol Serializable: Sendable {
      static func serialize<Buffer: RangeReplaceableCollection>(
          _ serializable: Self, into buffer: inout Buffer
      ) where Buffer.Element == Byte
  }
  ```
- `ASCII.Serializable` is a **bare marker with no verb** —
  `swift-ascii-serializer-primitives/.../ASCII.Serializable.swift:10-36`:
  ```swift
  extension ASCII { public protocol Serializable {} }
  ```
- Because the text sibling carries no operation, ASCII serialization **piggybacks the canonical
  `static var serializer`**: the `.asciiCodes` / `.serialized` accessors reach
  `Self.serializer.serialize(self, into:)` with `Serializer.Buffer == [ASCII.Code]`
  (`Serializable+ASCII.swift`), and the **ASCII→binary bridge** derives a wire witness by
  projecting that text serializer's codes to bytes (`Binary.Serializable+ASCII.swift:19-36`,
  `buffer.append(contentsOf: serializable.serialized)`).

This single asymmetry — *Binary owns its verb; ASCII borrows the canonical's* — is what forces (a)
the canonical's operational double-duty, (b) the projection bridge, and (c) the "decline canonical"
dance for any type whose wire form ≠ its text-bytes. **Symmetrise the text sibling (give it its
own verb) and all three dissolve.** That is the whole derivation in one sentence; the rest of this
document proves it rigorously, pressure-tests it, builds it (six probes), and re-specifies the
cascade, the IPv4/IPv6 shape, the sink model, and the convention re-cut.

### The addendum — the serialize/parse sink

A folded-in sub-question (principal, 2026-06-30): *what IS the serialize sink?* Recon confirms the
institute has **already decided** the write/append hot-path must not be protocol-abstracted —
`Buffer.\`Protocol\`` is a capability surface (count/isEmpty) that deliberately **excludes**
append/remove/subscript, "those stay on concrete-Base accessors per the specialization evidence in
`storage-generic-buffer-core.md`" (verbatim, `Buffer.Protocol.swift:80-85`). No buffer discipline
conforms `RangeReplaceableCollection`; there is no shared Sink/Writer/Appendable protocol. **This
decision is not reopened.** §7 resolves the sink fork (default `RangeReplaceableCollection` +
`OutputSpan` region-write perf path; no sink protocol; format still by element type) and ties it to
buffer-primitives.

---

## Question

1. **MODEL + SURFACE.** What is the principally-correct serialize/parse codec-attachment model —
   the protocol structure AND the call-site verbs for serialize / parse / variant / context —
   ecosystem-wide, superseding the per-corner carve-out?
2. **CANONICAL FATE.** What becomes of the canonical single-slot `Serializable`/`static var
   serializer` (and its `Parseable`/`Codable` peers)? Retire, or demote to a pure semantic marker?
   (Downward only.)
3. **SINK.** What is the serialize sink — stdlib `RangeReplaceableCollection`, or a path that
   reaches buffer-primitives' `~Copyable` disciplines — without reopening the no-append-on-protocol
   decision?
4. **CONTEXT / OQ2.** How does the parse side carry out-of-band context (the 5 non-Void conformers:
   `WHATWG_URL.URL`/`.Host`/`.Path`, `RFC_2046.Multipart`, `RFC_2387.Related`) under the unified
   model?

---

## Methodology

This is a **Tier 3** arc (ecosystem-wide; precedent-setting; long-lived semantic contract;
timeless infrastructure). Per [RES-020]/[RES-023]/[RES-024]/[RES-026] it carries parallel
subagent prior-art verification, write-time empirical-claim verification, formal semantics, and a
References section.

- **[RES-019] internal grep first.** `swift-institute/Research/` + `swift-foundations/swift-json/Research/`
  swept; the load-bearing antecedents are `multi-representation-value-codec-attachment.md` (the
  superseded carve-out), `2026-05-15-family-codable-convention.md` ([FAM-001..009]),
  `swift-foundations/swift-json/Research/family-codable-convention.md` ([FAM-001..008],
  incl. [FAM-007]), `family-codable-contextual-parsing.md` (OQ2), `sibling-refines-canonical-attachment.md`
  ([FAM-010]), `canonical-attachment-semantic.md` (the conformer inventory + Common.Codable axis,
  SUPERSEDED), `serializer-leaf-witness-bodyless-fix-options.md` (the A16 SIL crash + Option 1
  fix), `unified-iteration-design.md` (the Iterable ∥ Sequenceable precedent),
  `storage-generic-buffer-core.md` (the sink specialization decision).
- **[RES-013a] / live source outranks the docs.** Every protocol shape, conformer body, and type
  identity below was re-verified at source by two independent recon subagents; where a doc claim
  and live source disagreed, source governs and the delta is recorded (§5, §9).
- **[RES-021] prior art with contextualization.** serde, pointfree swift-parsing, Swift Codable,
  Rendel & Ostermann (invertible syntax), and the institute's own swift-iterator-primitives,
  each verified against primary sources by an independent subagent and **contextualized** before
  classification (universal adoption ≠ universal necessity; §3).
- **[RES-020] / [RES-032] primary-source verification.** Every external claim carries a
  `[Verified: 2026-06-30]` tag traceable to fetched source; two honest gaps are marked
  `(UNVERIFIED)` rather than asserted.
- **[RES-024] / [RES-028] embedded experiments — build-truth before committing.** Six throwaway
  single-file `swiftc` probes (Swift 6.3.3; smallest-isolation-first) settle every load-bearing
  type-system premise *before* the model is committed to. This is the discipline whose absence
  cost an earlier fan-out; the verdicts are folded in per [RES-023] (§5). The probes are
  `/tmp`-throwaway per the principal's research-only constraint; if productionised they belong in
  `swift-serializer-primitives/Experiments/` per [EXP-002c] (a follow-up, not a gate).
- **Class-(c) discipline.** This arc **modifies no canonical attachment protocol**. The re-cut of
  `[FAM-002]/[FAM-003]/[FAM-005]/[FAM-010]` and the new `[FAM-012]` are **surfaced** as a
  skill-lifecycle ratification candidate, **not made** (§12).

---

## Analysis

### 1. First principles — what serialization *is*, and what a format *is*

Strip away the existing protocols. A **serialization** of a value `v : V` is a total function
producing a sequence of atoms of some element type `E`, written into a sink. Three questions
determine its shape:

1. **What is the atom type `E`?** For a *wire* form it is a raw octet (`Byte`); for a *text* form
   it is a character code (`ASCII.Code`); for a *tree* form it is a tree node (`JSON`). The atom
   type is not incidental — it *is* the choice of format. `192.168.1.1` (eleven `ASCII.Code`s) and
   `[0xC0,0xA8,0x01,0x01]` (four `Byte`s) are not two encodings of one structure; they are two
   different functions whose codomains have different atom types.
2. **Who drives — the value or the codec?** The value is the *data*; the codec is the *operation*.
   The operation is naturally **static and takes the value explicitly**: `serialize(_ value, into:
   &sink)`. This is the only shape that (a) works for `~Copyable`/`~Escapable` values (an instance
   method on a `~Copyable` value cannot be passed around as a function value; a static verb taking
   `borrowing Self` can), (b) composes as a first-class function value (`Type.serialize` is a
   curried function), and (c) keeps the value immutable during serialization (`borrowing`).
3. **What is the sink?** A growable container of `E`. Its concrete type (`Array`, `ContiguousArray`,
   a Span-backed region) is *free* — irrelevant to the format. So the verb is **generic over the
   sink**, constrained only on its element type: `serialize<Buffer: RangeReplaceableCollection>(_:
   into:) where Buffer.Element == E`. (§7 adds the `OutputSpan<E>` perf sink as a second path; the
   collection genericity is the point — fixing it to `Array` would be wrong.)

From (1)–(3): **a format codec is exactly a static universal verb over a generic
element-typed sink.** The element-type `where`-clause *is* the format selector. This is not a new
invention — it is precisely the shape `Binary.Serializable` already ships. The first-principles
derivation says: *that shape is correct, and every format sibling should have it.*

**The asymmetry is therefore the defect, not a corner.** `ASCII.Serializable` is a bare marker; it
has no verb; so text serialization had to be hung on the canonical `static var serializer`. Make
the text sibling symmetric — give it the same static verb with `where Buffer.Element == ASCII.Code`
— and the canonical's operational role evaporates.

### 2. The dissolution — the canonical operational tier is unnecessary

The existing system has **three** constructs: per-format *siblings* (flat markers), the *canonical*
attachment (`Serializable`/`static var serializer`, [FAM-002] "one inherent codec"), and the
*operational* witness layer (`Serializer.Protocol`/`Witness`). The carve-out doc keeps all three
and routes multi-representation types *around* the canonical.

First principles collapse the first two:

- "**Single inherent codec**" ([FAM-002]) means *the value has exactly one representation*. In the
  sibling model that is simply **`|siblings| = 1`**: the type conforms to exactly one format
  sibling. `RFC_8259.Value` conforms `JSON.Serializable` and nothing else; `Version.Semantic`
  conforms one text sibling and nothing else. There is nothing a separate canonical tier adds — it
  is the degenerate case of the sibling model, not a distinct construct.
- "**Multiple representations**" is **`|siblings| ≥ 2`**: `IPv4.Address` conforms
  `Binary.Serializable` *and* `ASCII.Serializable`. There is no canonical slot that must somehow
  name "the" codec, so there is **nothing to decline** and **no ambiguity to suppress**.

So the canonical operational attachment is not declined by some types — it is **unnecessary for
all types**. Every type conforms to exactly the format siblings its specification gives it. The
"decline canonical" dance, the bridge, and the canonical's operational double-duty are not patched;
they cease to have a referent.

What survives the dissolution:

- The **operational witness layer** (`Serializer.Protocol`/`Witness`, Body/Builder) survives —
  but only in its proper role: as the **value type of a VARIANT** (§6) and of a composed/leaf
  serializer. It is not an attachment tier; it is the type of the witness you pass in.
- The **semantic** notion "this type has one inherent codec" survives as `|siblings| = 1` — a fact
  about the conformance set, not a protocol. (Whether to keep any *marker* protocol for it is the
  downward-only sub-question of §8; the recommendation is **retire**, because the one sibling
  already carries it.)

This is the deep move the carve-out doc did not make. The carve-out keeps the canonical tier and
adds a rule ("multi-rep types decline it"). First principles *delete the tier* and the rule with
it.

### 3. Prior art (primary-source-verified) + contextualization

Per [RES-021]; full citations in References. Each system is concretised in the institute's
own type system before classification.

**Rust serde — `Serialize` + `Serializer`-arg + `is_human_readable` + `DeserializeSeed`.** serde's
`Serialize::serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error>` is a single
stateless verb; the **serializer is a *generic* type parameter taken by value** (monomorphised at
compile time, not `&dyn`), and the **data drives** (`&self`). The one hook a *type* gets is
`fn is_human_readable(&self) -> bool` (default `true`) — a **runtime bool** the *format* exposes;
`Ipv4Addr` branches on it (`if serializer.is_human_readable() { serialize_str(...) } else {
self.octets().serialize(...) }`), and serde's own doc warns the two forms are **not required to
round-trip** ("regarded as a breaking change"). Context-bearing *deserialization* is a **separate
trait** `DeserializeSeed::deserialize<D>(self, deserializer: D)` whose **seed (`self`, consumed by
value) carries the state** — "the stateful form of `Deserialize` … the way to pass data into a
`Deserialize` impl." Format is the concrete `Serializer` impl (`serde_json` vs `bincode`) chosen at
the call site, **never an element type.** [Verified: 2026-06-30 — `serde_core/src/{ser,de}/*.rs`
@ serde 1.0.228; the trait source has moved to a new `serde_core/` crate, old `serde/src/...`
paths 404.]

*Contextualization.* serde proves the **use case is real and load-bearing** (the std `net` types
genuinely present different shapes per format), and it gives the institute **two patterns to adopt
and one to reject.** Adopt: the **monomorphised generic-witness-argument** (`serialize<S>(...,
serializer: S)`) — the institute's variant-witness param is exactly this, compile-time, typed;
and the **seed-carries-context** shape (`DeserializeSeed`) — the institute's parser-witness-value
is exactly this. Reject: `is_human_readable` — an **under-typed runtime bool** that erases the
per-form typed `Failure`, cannot carry a variant axis (IPv6 has *three* text forms; one bool can't
select them), carries a documented round-trip hazard, and has **no typed buffers**. The institute
keys FORMAT by the **element type at compile time** (type-safe, total, no runtime tag) and carries
VARIANT/CONTEXT in a **typed witness value** — serde's strengths without serde's runtime branch.

**pointfree swift-parsing — `Input` is the type axis.** `Parser<Input, Output>` has
`associatedtype Input`; `ParserPrinter` refines it with `print(_ output: Output, into input: inout
Input)`. Because `Input` is an associated *type*, a parser over bytes (`Input = ArraySlice<UInt8>`)
and one over text (`Input = Substring`) are **statically distinct types** — the byte/text split is
type-enforced. [Verified: 2026-06-30 — `Parser.swift`, `ParserPrinter.swift` @ main.]
*Contextualization.* This is the **same insight the institute already encodes** — except the
institute puts the axis on the *sink element type* (`Buffer.Element == Byte` vs `== ASCII.Code`)
rather than on the whole `Input` type, which is finer-grained (the collection stays free) and gives
the overload-resolution format selection of §1. (Caveat: swift-parsing uses *untyped* `throws`; the
institute keeps `throws(Failure)`.)

**Rendel & Ostermann, "Invertible Syntax Descriptions" (Haskell Symposium 2010) — the theory of
the variant axis.** One `Syntax` description denotes both a parser and a printer (the
implementation chooses which); built on **partial isomorphisms** `Iso α β = Iso (α → Maybe β) (β →
Maybe α)`, with `<$>` lifted *over isos* (not plain functions), `<*>`, `<|>`. The paper's premise
is the IPv6 situation verbatim: "*a single abstract value usually corresponds to multiple concrete
representations … pretty printing has been characterized as choosing the 'nicest' representation*";
"accept many, emit one canonical" is native (the `optSpace` example: parse arbitrary space, print
one). [Verified: 2026-06-30 — full PDF, §§1, 3.1, 3.4, 4.2, 6.3; the claim "emit several variants
needs several printer descriptions" is **(UNVERIFIED)** — design-implied by the deterministic
`Printer (α → Maybe String)`, not stated in the paper.] *Contextualization.* This grounds the
institute's **variant axis**: one value, N concrete forms; the canonical/recommended form is the
default; alternative forms are **additional named printer descriptions** — realised in the
institute as **distinct `Serializer.Protocol` witness values** (IPv6 RFC 5952 / full / IPv4-mixed).

**Swift Codable — the counter-example.** `Encodable.encode(to encoder: any Encoder) throws` /
`Decodable.init(from decoder: any Decoder) throws`: the coder is an **existential** (type-erased),
`throws` is **untyped**, and there is **no `is_human_readable` equivalent** — a Codable type
*cannot* natively present a structurally different shape per format (the escape hatches `if encoder
is JSONEncoder` / `userInfo` recouple to concrete coder identities). [Verified: 2026-06-30 —
`stdlib/.../Codable.swift` @ main; SE-0166.] *Contextualization.* Codable's cost is the one the
institute's typed system exists to avoid: existential erasure + untyped throws. The unified model
keeps everything **monomorphised and typed** (no `any` coder, `throws(Failure)` throughout). Codable
is the design the family-Codable convention was founded to escape; it is informative only as the
shape to *not* take.

**swift-iterator-primitives — `Iterable ∥ Sequenceable` (in-ecosystem precedent, PARTIAL).** The
institute independently shipped *flat orthogonal format-like siblings* in the iterator domain.
[Verified: 2026-06-30 — `Iterable.swift:24-58`, `swift-sequence-primitives/.../Sequenceable.swift:17-122`,
`unified-iteration-design.md`.] Honestly classified:

| Converged-position claim | Iterator-domain verdict |
|---|---|
| Flat orthogonal siblings, neither refines the other | **CONFIRMED** — "orthogonal capabilities, not a refinement chain … no refinement edge"; live across two packages |
| A shared universal verb | **CONFIRMED** — `makeIterator()`, carried by both |
| `associatedtype`/`@_implements` trap awareness | **STRONGLY CONFIRMED** — but the **trap-PAID** case: both siblings genuinely need `associatedtype Iterator`, so they cannot flatten it; `@_implements(Iterable, Iterator)` is **live across ≥5 packages** (tree-keyed, queue-linked, buffer-ring, cyclic-iterator, set-algebra) |
| Verb is **static** | **DIVERGES** — `makeIterator()` is **instance**, by design: iteration is *value-level* (you iterate a specific value) |
| Variant/context as a **passed-in witness value** | **NOT PRESENT** — the variant (borrow vs consume) is carried *structurally* (which protocol + ownership modifier); `makeIterator()` takes no parameters |

*Contextualization — this is the most instructive precedent precisely because it diverges.* The
iterator domain is the **trap-PAID** counterpart: its siblings each carry an `associatedtype
Iterator` (the iterator type is genuinely per-conformer and cannot be expressed as a method
`where`-clause), so they pay `@_implements` at every dual conformer. **The codec model is the
trap-AVOIDED design**: format is expressible as `where Buffer.Element == Byte` on a *generic
method*, so the sibling markers carry **no `associatedtype` at all** — Experiment 1 shows a dual
conformer needs **no `@_implements`** (the disjoint element types partition the same-named verb).
The iterator domain is the empirical "why [FAM-001] exists"; the codec model is what it looks like
when you *can* obey it fully. The **static-vs-instance** divergence is also principled and resolved
by the institute's own rubric (`agent-witness-attachable-pattern.md`: value-producing capabilities
use instance accessors; type-level capabilities — parse-from-bytes, serialize-any-value-of-type —
use `static`). Serialization is type-level; iteration is value-level; the verbs differ *because the
operations differ*, not arbitrarily. And the "variant/context as passed witness" half of the
converged position comes from serde's verified `DeserializeSeed`, **not** from the iterator domain
— the precedent is not overclaimed.

### 4. Theoretical framing (Tier-3 formal semantics, [RES-024])

**Formats and the format map.** Let `𝔉` be the set of formats. Each format `F ∈ 𝔉` is identified
with a distinguished **element type** `E_F`: `E_wire = Byte`, `E_text = ASCII.Code`, `E_json =
JSON` (the tree node; the sink is the tree itself). The institute's element types are **pairwise
disjoint nominal types** — `Byte` and `ASCII.Code` are distinct `@frozen struct`s (each wrapping a
`let underlying: UInt8`), neither a `typealias` to `UInt8` nor to each other (§5, item 11). Write
`elt(Σ)` for the element type of a sink `Σ`.

**Sibling protocol.** A format sibling `𝒮_F` is the predicate "`V` serialises to format `F`",
witnessed by a static verb
```
serialize_F : (borrowing V) × (inout Σ) → ()      for every sink Σ with elt(Σ) = E_F
```
carrying **no associated type** (the format is in the `where`-clause, not an anchor).

**Typing rule (format selection).**
```
   Γ ⊢ v : V      V : 𝒮_F      Γ ⊢ σ : Σ      elt(Σ) = E_F
  ──────────────────────────────────────────────────────────  (Ser)
                Γ ⊢ V.serialize(v, into: &σ)            ⇝ 𝒮_F's verb
```
**Determinacy / soundness.** Because the `E_F` are pairwise disjoint nominal types, for a given `σ`
**at most one** `F` satisfies `elt(Σ) = E_F`; (Ser) therefore resolves to a unique verb, and
overload resolution is **total and unambiguous** (Experiment 1 — confirmed for `[Byte]`,
`[ASCII.Code]`, `ContiguousArray<Byte>`, and generic pass-throughs constrained to either element).
If `elt(Σ) ∉ {E_F}` the term is **ill-typed** (Experiment 1-neg1: `[Int]` sink rejected); if `Σ`'s
element is *unconstrained* (a generic without a `where`-clause) **no** `F` is selected and the term
is **ill-typed** (Experiment 1-neg2). The model **fails closed**: you cannot serialize without
choosing an element type, and choosing it *is* choosing the format — no runtime format tag is ever
consulted (the structural contrast with serde's `is_human_readable`).

**The two-axis factoring.** The set of representations of `V` factors into exactly two orthogonal
axes — **there is no third "canonical" axis**:
```
Reps(V)  =  Format  ×  Variant
Format   ∈ { F : V : 𝒮_F }                              ← the SIBLING axis (compile-time, by overload resolution)
Variant  ∈ { w : Serializer.`Protocol`, w.Output = V }   ← the LEAF-INSTANCE axis ([FAM-005]; a witness VALUE)
```
`|Format(V)| = 1` is the "single inherent codec" case (formerly "canonical"); `|Format(V)| ≥ 2` is
multi-representation. Both are ordinary instances of the same factoring.

**The witness-carries-parameters principle (serialize-variant ∥ parse-context).** Both the output
*variant* and the input *context* are parameters of the operation, and both are carried by a
**witness value passed in**:
```
serialize(v, into: &σ, serializer: w)   — w : Serializer.`Protocol` carries the VARIANT (output-shape parameter)
parse(from: &σ, parser: p)              — p : Parser.`Protocol`     carries the CONTEXT (input-disambiguation parameter)
```
The default no-witness verbs (`serialize(v, into:)`, `parse(from:)`) denote the canonical variant /
empty context. The flat marker carries **no `associatedtype`** for either (no Variant anchor, no
Context anchor — [FAM-001]); the witness is a monomorphised generic argument (`serialize<W:
Serializer.\`Protocol\`>(..., serializer: W) where W.Output == Self`). This is exactly serde's split
— stateless verb (`Serialize`) + stateful argument (`Serializer` / `DeserializeSeed` seed) — with
FORMAT moved to the type system.

**The inverse law (Rendel-Ostermann partial isomorphism).** For the canonical variant of format
`F`, `parse_F ∘ serialize_F = id_V` (author discipline/test, per
`transformation-domain-architecture.md`). serialize is **total**; parse is **partial** (typed
`Failure`). A future `Coder` promotes the pair to a typed inverse when round-trip is a hard
requirement; not needed for the model.

**Ownership soundness.** `serialize(_ value: borrowing Self, into:)` is sound for `~Copyable` `V`:
`borrowing` borrows-without-consuming, so `V` survives repeated serialization and an end-of-life
`consuming` use is still legal (Experiment 4). `value = data`, `codec = operation`: the value is
never mutated; the sink is exclusively borrowed (`inout`).

### 5. Embedded experiment verdicts (build-truth, [RES-023])

Six throwaway single-file `swiftc` probes, **Swift 6.3.3 (swiftlang-6.3.3.1.3), arm64-apple-macosx26.0**,
`-swift-version 6`. Full sources in the session scratchpad (`codec-probes/`); reproducible. Every
load-bearing type-system premise of the model is settled empirically before commitment.

| # | Premise | Verdict | Evidence |
|---|---------|---------|----------|
| **1** | The static universal verb, carried independently by two siblings with disjoint element-type `where`-clauses, resolves the FORMAT by sink element type — for concrete `[Byte]`/`[ASCII.Code]`, a different collection, AND generic pass-throughs. **No `@_implements` needed** on the dual conformer. | **PASS** | Compiled + ran; correct dispatch in all 5 variants (`wire=[192,168,1,1]`, `text="192.168.1.1"`). A single type conforming to BOTH siblings needed no anchor escape hatch — the disjoint `Byte`/`ASCII.Code` element types partition the same-named verb. |
| **1-neg1** | A sink whose element is neither `Byte` nor `ASCII.Code` (`[Int]`) must FAIL. | **PASS (fails closed)** | `error: no exact matches in call to static method 'serialize'`. |
| **1-neg2** | An unconstrained generic sink must FAIL (format undetermined). | **PASS (fails closed)** | `error: no exact matches …`. Choosing the format is mandatory. |
| **2** | The converged static shape (default verbs + `Body == Never` variant witnesses per [API-IMPL-020]) builds clean under `-sil-verify-all` — the SIL-verification condition under which catalog-**A16** (bodyless leaf-witness) fires. | **PASS** | `swiftc -O -Xfrontend -sil-verify-all` clean; variant-selecting `serialize(_:into:serializer:)` ran. The **default static verb has no `var body` leaf → structurally A16-immune**; variant witnesses use the existing `Serializer.Protocol` layer whose A16 **Option 1 fix is already applied in-tree** (`Serializer.Witness` relocated to `Serializer Witness Primitives`, commit `a652cec`, confirmed at source). Isolated single-module bodyless-leaf shape also SIL-clean (the full A16 trigger needs cross-module + Embedded/Windows+Asserts per the dossier). |
| **3** | Parse CONTEXT carried by the parser-witness VALUE typechecks across a Void (context-free) AND a non-Void (context-bearing) conformer with **NO `associatedtype` on the flat marker** (no [FAM-001] violation), one generic algorithm, typed throws. | **PASS** | Compiled + ran (`digit=5`, `url=http://x/2`). The flat `ASCIIParseable` marker carried no associated type; context lived in the `URLParser.base` witness field; one `parseWith<W: ParserWitness>(_:from:) throws(W.Failure)` served both. |
| **4** | `static func serialize(_ value: borrowing Self, into:)` over a `~Copyable` `Self` — ownership holds (borrowing does not consume; value survives repeated borrows; end-of-life consume legal). | **PASS** | Survived 2 borrows then `consuming` use. (The only earlier error was a harness artifact — consuming a *global* ~Copyable — not the verb.) |
| **5a** | The verb composes over BOTH a `RangeReplaceableCollection` sink AND an `OutputSpan<Element>` sink with no ambiguity, format still by element type. | **PASS** | 4 sinks (2 RRC + 2 `OutputSpan`) coexist; `(collection-kind) × (element-type=format)` resolves uniquely. |
| **5b** | `static func serialize(_ value: borrowing Self, into span: inout OutputSpan<Byte>)` over a `~Copyable` `Self` — ownership holds against the `~Copyable` Span sink. | **PASS (ran)** | `Array(capacity:initializingWith:)` with `inout OutputSpan<Byte>`; 2 borrows, 2 bytes written. |

**Net.** Every premise of the model is empirically confirmed on the live toolchain, including the
two that could have sunk it (format-by-element-type resolution; SIL-cleanliness of the static
shape). The model fails closed where it should and avoids the `@_implements` trap entirely.

### 6. Live-source state the model must respect (and what it corrects)

[Verified: 2026-06-30 — two independent recon subagents.]

| Surface | Live shape | Disposition under the model |
|---|---|---|
| Canonical `Serializable` (`swift-serializer-primitives/.../Serializable.swift:8-25`) | `associatedtype Serializer` + `static var serializer { get }`; doc-comment example is `IPv4.Address: Serializable` (the irony) | **Retire** the operational slot (§8). The doc-comment example is removed (it never matched — IPv4 has two codecs). |
| `Serializer.Protocol` (`Serializer.Protocol.swift:34-68`) | `~Copyable`; `Output`/`Buffer`/`Failure: Swift.Error = Never`/`Body: ~Copyable`; `@Serializer.Builder` body; `borrowing func serialize(_:into:) throws(Failure)` | **Kept** — this is the **variant-witness value type**, not an attachment tier. |
| `Serializer.Witness` (`Serializer Witness Primitives/...`) | leaf closure-witness; `typealias Body = Never`; A16 Option-1 relocation confirmed | **Kept** — the leaf variant witness. |
| `Binary.Serializable` (`Binary.Serializable.swift:42-55`) | `protocol Serializable: Sendable { static func serialize<Buffer: RRC>(_ serializable: Self, into:) where Buffer.Element == Byte }` | **Kept as the template**; add `borrowing` to the value param (Exp 4); the `: Sendable` refinement is orthogonal and reviewable (a `~Copyable` value need not be `Sendable`). |
| `ASCII.Serializable` (`ASCII.Serializable.swift:10-36`) | **bare marker** `protocol Serializable {}` | **Symmetrise** — gain the static verb `where Buffer.Element == ASCII.Code` (the root-cause fix). |
| `Binary.Parseable` (`Binary.Parseable.swift:61-76`) | `static func parse<Source: RRC>(from:) throws(Binary.Parse.Failure) -> Self where Source.Element == Byte`; **fixed** `Binary.Parse.Failure` (enum insufficient/malformed/outOfRange) | **Kept**; per-type/rich `Failure` moves to the **parser witness** (`throws(W.Failure)`, Exp 3); the marker's default keeps the format-level fixed `Failure`. |
| `ASCII.Parseable` (`ASCII.Parseable.swift:10-33`) | bare marker | **Symmetrise** — gain the static parse verb `where Source.Element == ASCII.Code`. |
| ASCII→binary bridge (`Binary.Serializable+ASCII.swift:19-36`) | `buffer.append(contentsOf: serializable.serialized)` | **Delete** (§9). |
| `.asciiCodes`/`.serialized` (`Serializable+ASCII.swift`) | derive via `Self.serializer.serialize(...)` keyed on `Serializer.Buffer == [ASCII.Code]` | **Re-derive** via the static ASCII verb (`Self.serialize(self, into: &codes)`); additive sugar, not load-bearing. |
| Deprecated `Binary.ASCII.Serializable` (`Binary.ASCII.Serializable.swift:14-35`) | `: Binary.Serializable` refinement + `associatedtype Error/Context` + `init(ascii:in:)`; **still load-bearing** (IPv4 + IPv6 text ride it) | **Delete** (W4) once IPv4/IPv6 migrate to the symmetric verbs (§9). |
| `Byte` / `ASCII.Code` (`Byte.swift:36-48` / `ASCII.Code.swift:34-44`) | distinct `@frozen struct`s; `ASCII.Code : Byte.\`Protocol\`` (peer); cross via `.underlying` / `.byte` | **Load-bearing disjointness** — the format axis (Exp 1). No change. |

**Two defects the model corrects at source (recon findings):**

1. **IPv4 text rides the deprecated protocol.** `RFC_791.IPv4.Address` serialises dotted-decimal on
   `Binary.ASCII.Serializable` into `Buffer.Element == Byte` (`RFC_791.IPv4.Address.swift:162-210`)
   — the deprecated refinement [FAM-010] forbids.
2. **IPv6 has a DEAD canonical serializer.** There are **two** IPv6 text serializers: the RFC 4291
   inline one on the deprecated protocol (`Buffer.Element == Byte`, `String(_, radix:16)`,
   `:129-197`) and the RFC 5952 canonical one (`Buffer.Element == ASCII.Code`, via
   `RFC_4648.Base16.encode`, `RFC_4291.IPv6.Address+RFC_5952.swift:39-102`). The user-facing
   `String`/`rawValue` path dispatches through the **RFC 4291 `Byte`-buffer** serializer — so the
   **canonical RFC 5952 `ASCII.Code` serializer is effectively dead code** (its doc-comment claims
   it "overrides" the RFC 4291 one; it does not — different overload). The model unifies them.

### 7. The sink model (addendum) — default + perf path, no sink protocol

**Recon-confirmed constraint (not reopened).** `Buffer.\`Protocol\`` is capability-only (count/isEmpty);
append/remove/subscript "stay on concrete-Base accessors per the specialization evidence" — the SIL
evidence (`storage-generic-buffer-core.md`) is that concrete-Base `Property.Inout` accessors
specialise cross-module to **0 `witness_method` unconditionally**, while protocol-Base accessors do
**not** (they need `@inlinable`, which lands on the documented `~Copyable` `Property.Inout`
borrow-init miscompile). No buffer discipline conforms `RangeReplaceableCollection`; there is **no
Sink/Writer/Appendable protocol**. **The write hot-path must not be protocol-abstracted.**

**The fork, resolved.** The static verb's sink is generic, but a single generic *cannot* span both
worlds: `RangeReplaceableCollection` is `Copyable` (Array/ContiguousArray, dynamic growth) and
cannot name buffer-primitives' `~Copyable`, pre-sized, Span-backed disciplines — exactly the
zero-realloc case those disciplines exist for. So the verb carries **two output paths, one format
axis**:

```swift
extension RFC_791.IPv4.Address: Binary.Serializable {
    // (A) DEFAULT sink — ergonomic, Copyable, dynamic-growth (Array/ContiguousArray world):
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ a: borrowing Self, into buffer: inout Buffer
    ) where Buffer.Element == Byte { /* append octets */ }

    // (B) PERF sink — the ~Copyable region-write path that reaches buffer-primitives:
    static func serialize(_ a: borrowing Self, into span: inout OutputSpan<Byte>) { /* span.append */ }
}
```

- **Format is still by element type in BOTH paths** (`OutputSpan<Byte>` ⇒ wire, `OutputSpan<ASCII.Code>`
  ⇒ text), and the two paths coexist with **no ambiguity** — `[Byte]` is `RangeReplaceableCollection`,
  `OutputSpan<Byte>` is not, so they are disjoint (**Experiment 5a** — 4 sinks coexisting). Ownership
  holds for `~Copyable` values into the `~Copyable` span (**Experiment 5b**, ran).
- **The perf path is `OutputSpan`, not `Span`.** The addendum's hypothesis named "Span"; recon and the
  toolchain probe refine it: `Span<E>` is **read-only** (cannot be a serialize sink), `MutableSpan<E>`
  is **in-place fixed-count** (overwrite, not append), and **`OutputSpan<E>` is the append-into-
  uninitialised-capacity primitive** — the serialize sink. buffer-primitives already exposes exactly
  this on the concrete disciplines: `Buffer.Linear.init(capacity:initializingWith: (inout
  OutputSpan<E>))`, `append(addingCapacity:initializingWith:)`, `edit { }`
  (`Buffer.Linear+OutputSpan.swift`). A serializer writes into a `Buffer.Linear<Byte>`'s
  uninitialised tail by being handed its `OutputSpan<Byte>` — **no sink protocol, no
  `RangeReplaceableCollection` conformance, the no-append-on-protocol decision untouched.**
- **Relationship to buffer-primitives.** The element model already aligns: `Buffer.\`Protocol\`` keys
  on `associatedtype Element: ~Copyable`, the format axis keys on `Buffer.Element == Byte`/`==
  ASCII.Code`; a `Buffer.Linear<Byte>` slots into format-by-element-type perfectly. The **only** gap
  was the write-sink expression, and `OutputSpan<Element>` (path B) closes it. The default path (A)
  serves the Array world; the perf path (B) serves the buffer-primitives world; both keyed by element
  type.

**Recommendation.** The flat serialize verb requires path (A) (`RangeReplaceableCollection`,
ergonomic default). Path (B) (`OutputSpan<E>`) is an **additive perf overload** provided where the
zero-realloc / `~Copyable` / buffer-primitives case matters; it is `[FAM-005]`-clean (same format
axis) and does not reopen the sink-protocol decision. A type may ship only (A); (B) is opt-in per
conformer. (Symmetrically, the parse side may add an `inout some Span<E>` / borrowing-region read
path; the read primitives `Span`/`RawSpan` already exist — `init?(_ bytes: borrowing Span<Byte>)`
is shipped.)

### 8. The canonical-slot fate (downward only)

The canonical `Serializable`/`static var serializer` had two jobs: **(i)** the semantic marker
"this type has one inherent codec" ([FAM-002]); **(ii)** the **operational ASCII path** (the bare
`ASCII.Serializable` marker piggybacks it). §1 strips job (ii) by giving the ASCII sibling its own
verb. That leaves job (i), which §2 shows is **`|siblings| = 1`** — a fact about the conformance
set, carried by the one sibling, not by a separate slot.

- **For byte/text-stream formats: RETIRE the operational `static var serializer`.** It is
  near-vacuous: you cannot produce a serialization without choosing an element type (= a format), so
  there is no format-agnostic single value for the slot to hold. Its only consumer was the
  `.asciiCodes` accessor, which §6 re-derives from the static verb. (Symmetrically for
  `static var parser`/`static var coder`.)
- **For the tree-format constitutive case** (`RFC_8259.Value`, whose sole codec IS "be the JSON
  tree"): the type conforms `JSON.Serializable` (its one sibling) directly. The single inherent
  codec is `|siblings| = 1` on the *tree* sibling — no separate canonical tier is needed even here.

**The exact fate (the one downward-only sub-decision).** Two dispositions, both downward:

- **(a) Retire entirely (RECOMMENDED).** Delete the canonical `Serializable`/`Parseable`/`Codable`
  operational protocols; every conformer (Class I spec-value types `RFC_8259.Value`,
  `Version.Semantic`/`.Tools`/`.Calendar`, `Glob.Pattern`; Class II `Tagged`/`Optional`
  delegations; Class III stdlib pins already on the Φ.3 removal path) re-homes onto its single
  format sibling. Cleanest; the sibling carries everything.
- **(b) Demote to a pure semantic marker.** Keep an *empty* `Serializable` marker (no `static var
  serializer`) inhabited only by tree-constitutive single-codec types, as a documentation anchor
  for "one inherent codec." Conservative; retains a vestigial tier.

The recommendation is **(a) retire** — the tree sibling subsumes the semantic, and a vestigial
empty marker is vocabulary overhead per [API-NAME-001a]'s spirit. **This is a canonical-protocol
modification — surfaced for ratification (§12), not made.** It is strictly out of scope of the
narrower "modify nothing canonical" framing of the superseded doc, and is the substantive
escalation this arc carries to the principal.

> **Honesty caveat — re-homing inventory is a ratification precondition.** This arc verified the
> **serializer** side at source (the `Binary.Serializable` template, the `ASCII.Serializable`
> bare-marker asymmetry, the bridge, the IPv4/IPv6 bodies). The **canonical `Parseable`/`Coder`-side**
> conformer set — and the precise re-homing of `RFC_8259.Value`'s `Coder_Primitives.Codable`
> conformance and `Version.Semantic`'s `Parseable` conformance — leans on the prior inventory in
> `canonical-attachment-semantic.md`, not on a fresh source sweep. A full conformer inventory across
> the canonical `Serializable`/`Parseable`/`Coder` triple is therefore a **precondition of ratifying
> disposition (a)**, not a claim this document discharges. The *model* is independent of the
> inventory; only the *retirement's blast radius* depends on it.

> **Note — the Common.Codable axis is untouched.** `canonical-attachment-semantic.md` reserved
> `[FAM-011]` for an *additive* `Common.Codable` floor peer (Apple's CommonCodable currency-type
> shape, for `Range`/`CGRect`). That is an orthogonal axis (a cross-format minimum-shape floor),
> not the byte/text operational attachment this document retires. The dissolution here does not
> bear on it; if `Common.Codable` is ever built it is a peer of the format siblings, not a revival
> of the operational canonical.

### 9. Per-conformer cascade shape (preserve the bespoke logic; change only the scaffolding)

The bespoke byte-producing **bodies** already written by the W3 cascade are **reusable and
preserved**; only the **conformance scaffolding and call sites** change. The mechanical shape, per
conformer:

| Conformer kind | Before (scaffolding) | After (scaffolding) | Body |
|---|---|---|---|
| Wire-only (e.g. an integer's big-endian form) | `Binary.Serializable` static verb | unchanged | unchanged |
| Text-only (e.g. `Version.Semantic`) | bare `ASCII.Serializable` marker + canonical `static var serializer` + bridge derives `.bytes` | `ASCII.Serializable` **with the static verb** (`where Buffer.Element == ASCII.Code`); **no** canonical conformance; **no** bridge | move the existing inline text logic verbatim into the verb body |
| Multi-representation (`IPv4`, `IPv6`) | `Binary.Serializable` + deprecated `Binary.ASCII.Serializable` (text) | `Binary.Serializable` (wire verb) + `ASCII.Serializable` (text verb); **no** canonical, **no** decline, **no** bridge | both bodies preserved verbatim, re-homed onto the two symmetric verbs |
| Variant-bearing (`IPv6` text forms) | (the dead RFC 5952 overload + the live RFC 4291 inline) | one `ASCII.Serializable` verb (default = RFC 5952 canonical) + named `Serializer.\`Protocol\`` witness **values** for full / IPv4-mixed, via `serialize(_:into:serializer:)` | preserve the zero-run-compression + `RFC_4648.Base16.encode` logic; delete the duplicate inline `String(_,radix:16)` body |
| Context-bearing parse (the 5: URL/.Host/.Path, Multipart, Related) | concrete `init(ascii:in:)` (status quo) OR deprecated `Binary.ASCII.Serializable.Context` | `parse(from:, parser: witnessBuiltWithContext)`; the parser witness **value** stores the context | preserve the concrete reader body inside the witness's `parse` |

No conformer loses its hand-written byte-producing logic; the migration is a **conformance-and-call-site
reshape**, not a rewrite. (Recon flagged the exact bodies to preserve: IPv4 wire 4-octet append; IPv4
`appendDecimal` dotted-decimal; IPv6 wire `bytes(endianness:.big)` ×8; IPv6 RFC 5952 zero-run +
`Base16.encode`. All carry over.)

### 10. The IPv4 / IPv6 shape (the forcing functions, ordinary)

```swift
// ── RFC_791.IPv4.Address — an ORDINARY two-sibling value. No canonical, no decline, no bridge. ──
extension RFC_791.IPv4.Address: Binary.Serializable {            // wire, [Byte]
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ a: borrowing Self, into buffer: inout Buffer) where Buffer.Element == Byte {
        let (o0,o1,o2,o3) = a.octets
        buffer.append(o0); buffer.append(o1); buffer.append(o2); buffer.append(o3)   // body preserved
    }
}
extension RFC_791.IPv4.Address: ASCII.Serializable {            // text, [ASCII.Code]
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ a: borrowing Self, into buffer: inout Buffer) where Buffer.Element == ASCII.Code {
        // the existing appendDecimal dotted-decimal logic, now emitting ASCII.Code (not Byte)
    }
}
extension RFC_791.IPv4.Address: Binary.Parseable { /* [Byte] → Self, fixed Failure */ }
extension RFC_791.IPv4.Address: ASCII.Parseable  { /* [ASCII.Code] → Self */ }
// NO `: Serializable` (canonical) — retired; NO `Binary.ASCII.Serializable` — deleted.

// ── RFC_4291.IPv6.Address — wire + text, with text VARIANTS as witness values. ──
extension RFC_4291.IPv6.Address: ASCII.Serializable {          // default text = RFC 5952 canonical
    static func serialize<Buffer: RangeReplaceableCollection>(
        _ a: borrowing Self, into buffer: inout Buffer) where Buffer.Element == ASCII.Code {
        // the RFC 5952 zero-run-compression + RFC_4648.Base16.encode body (the formerly-DEAD one,
        // now the live default — the duplicate RFC 4291 inline String(radix:16) body is deleted)
    }
}
let canonical: [ASCII.Code] = address.asciiCodes                              // RFC 5952 (default verb)
var full: [ASCII.Code] = []; RFC_4291.IPv6.Address.serialize(address, into: &full, serializer: .full)        // variant witness VALUE
var mixed: [ASCII.Code] = []; RFC_4291.IPv6.Address.serialize(address, into: &mixed, serializer: .ipv4Mixed)  // variant witness VALUE
let wire: [Byte] = address.bytes                                             // Binary verb
```

The three IPv6 text forms are the Rendel-Ostermann "N concrete syntaxes = N printer descriptions"
realised as N `Serializer.\`Protocol\`` **witness values** (compile-time, typed — not a runtime
enum). RFC 5952 canonical is the default (the verb body); `.full` / `.ipv4Mixed` are passed in.
**Call-site surface:** `.bytes` (wire), `.asciiCodes` (canonical text), `.description` (text →
`String`) — additive accessors deriving from the verbs ([FAM-004]); the variant forms via the
witness-passing verb.

**Placement note (direction, not a gate).** The RFC 5952 canonical text witness may live in
`swift-rfc-5952` (where the spec lives) with `swift-rfc-4291` owning the wire form — the existing
package split plus the [FAM-009] namespace-rooted rule support this. It does not change the model.

### 11. Context / OQ2 — resolved under the unification

`family-codable-contextual-parsing.md` recommended status-quo (concrete `init(ascii:in:)` only),
and *if ever built*, a `[FAM-007]` context **sub-sibling** carrying `associatedtype Context`. The
unified model **resolves OQ2 differently and more cleanly**: context is carried by the **parser
witness value** passed to `parse(from:, parser:)` — the serde `DeserializeSeed` shape, which that
doc itself identified as the institute-idiomatic realization ("context-as-witness-state:
`static func parser(in context: Context) -> Parser`"). This makes the 5 non-Void conformers
**ordinary**:

- The flat `ASCII.Parseable`/`Binary.Parseable` marker stays flat — **no `associatedtype Context`,
  no [FAM-007] sub-sibling** (Experiment 3 confirms typecheck across Void + non-Void with no
  associated type on the marker, one generic algorithm, typed throws).
- A context-free conformer offers a default witness (`Self.parser`); a context-bearing conformer
  builds its witness with the context (`URL.Parser(base: ...)`) and the caller passes it. The
  caller that can build the context is concrete by construction (the doc's own Q2 finding) — so the
  realistic site is `URL.parse(from: &bytes, parser: URL.Parser(base: base))`, which needs no
  sub-sibling.
- **serialize-variant ∥ parse-context are the same principle** (§4): the witness carries the
  operation's parameters; you pass the witness. OQ2's "context" and the IPv6 "variant" are one
  mechanism, applied on the two sides.

This **supersedes** that doc's "if ever built, use a [FAM-007] sub-sibling" with "the unified
witness-value mechanism already covers it — no sub-sibling, no `associatedtype` on the marker." The
deferral (don't build a bespoke context tier) stands and is reinforced; the *shape*, when context
is threaded, is the parser witness value, not a sub-sibling.

### 12. Convention re-cut + [FAM-012] CANDIDATE (surfaced, not made)

Per the CLAUDE.md memory-write guardrail and class-(c): the rules below modify the **canonical
attachment protocols** and the `[FAM-*]` convention. They are **surfaced for principal ratification
via `skill-lifecycle`**, not codified here.

**Re-cut of existing rules** (proposed):

- **[FAM-002] (re-cut).** *Was:* "the canonical-attachment associated type is the structural
  enforcement of one inherent codec per spec-value type." *Becomes:* "**there is no canonical
  operational attachment tier for byte/text-stream formats.** 'Single inherent codec' is the
  degenerate case `|format-siblings| = 1`; the type conforms to exactly its one sibling. The
  canonical `static var serializer`/`parser`/`coder` operational slot is **retired** (you cannot
  serialize/parse without choosing an element type = a format)." Downward only; the tree-constitutive
  disposition + the retire-vs-vestigial-marker call (§8) are the ratification's substance.
- **[FAM-003] (re-cut).** *Was:* "guarded-use of canonical attachments on public spec-value types."
  *Becomes:* "spec-value types conform to exactly the format sibling(s) their specification defines;
  there is no canonical-conformance gate because there is no canonical tier. A generic algorithm
  ranges over a **format-specific** bound (`<T: Binary.Serializable>`), never a canonical one."
  (This is exactly what [FAM-010]'s resolution already recommended — the re-cut removes the
  now-pointless canonical alternative.)
- **[FAM-005] (re-cut, reinforced).** *Was:* "sibling namespaces = format-level distinctions;
  sub-format dimensions are operation parameters / leaf-instance selections." *Becomes (extended):*
  "the FORMAT is the sink element type (the sibling axis, by overload resolution); all sub-format
  dimensions AND representation **variants** (endianness, radix, IPv6 RFC 5952 / full / IPv4-mixed)
  are **`Serializer.\`Protocol\`` witness VALUES** passed to `serialize(_:into:serializer:)` —
  compile-time, typed, never siblings, never an `associatedtype` on the marker." The variant-as-value
  operationalises [FAM-005]'s "leaf-instance selection."
- **[FAM-010] (absorbed).** *Was:* "format-specific siblings MUST NOT refine the canonical
  attachments." *Becomes:* vacuous and **absorbed** by the dissolution — with the canonical
  operational tier retired, there is nothing to refine; the siblings are the only attachment. The
  rule's intent (no anchor-merging trap) is preserved structurally: the flat verb-bearing siblings
  carry no `associatedtype`, so the trap cannot fire (Experiment 1 — no `@_implements` needed,
  unlike the iterator domain which *does* pay it).

**[FAM-012] (candidate — the new normative rule):**

> **[FAM-012] (candidate) Self-contained format siblings carry a static universal verb keyed by sink
> element type.**
> 1. Each format sibling (`Binary.Serializable`, `ASCII.Serializable`, `JSON.Serializable`, …)
>    declares its OWN static universal verb `serialize<Buffer: RangeReplaceableCollection>(_ value:
>    borrowing Self, into: inout Buffer) where Buffer.Element == <FormatElement>` (tree formats:
>    `into: inout <Tree>`), and the dual `parse`. **No bare-marker sibling may piggyback another
>    sibling's or the canonical's operational slot.** The FORMAT is the sink's element type; the
>    collection is free.
> 2. A type conforms to **exactly the siblings it genuinely has.** `|siblings| = 1` is the "single
>    inherent codec" case (formerly canonical); `|siblings| ≥ 2` is multi-representation. **Both are
>    ordinary — there is no canonical attachment to decline and no derivation bridge.**
> 3. **VARIANTS** within a format (IPv6 RFC 5952 / full / IPv4-mixed; endianness; radix) are
>    leaf-instance `Serializer.\`Protocol\`` **witness VALUES** passed to `serialize(_:into:serializer:)`
>    — never siblings, never an `associatedtype` on the marker ([FAM-001]/[FAM-005]). The canonical/
>    recommended variant is the default verb body.
> 4. **PARSE CONTEXT** (the non-Void conformers) is carried by the **parser witness VALUE** passed to
>    `parse(from:, parser:)` (serde `DeserializeSeed` shape); the flat marker carries no
>    `associatedtype Context` ([FAM-001]). Serialize-variant ∥ parse-context are the same principle:
>    the witness carries the operation's parameters; you pass the witness.
> 5. **ACCESSORS** (`.bytes`/`.asciiCodes`) are additive instance sugar deriving from the static verb;
>    not load-bearing; a type may omit them.
> 6. The canonical single-slot `Serializable`/`static var serializer` (and `Parseable`/`Codable`
>    peers) operational attachment is **retired** for byte/text-stream formats (§8; downward only).
> 7. The ASCII→binary projection bridge is **deleted**; a text-only value's byte view is the `.bytes`
>    text-projection accessor, not a wire codec, and it does **not** conform `Binary.Serializable`.
> 8. **Sink** ([FAM-005]-clean): the default sink is `RangeReplaceableCollection`; an `OutputSpan<E>`
>    region-write overload MAY be added for the `~Copyable`/buffer-primitives perf path. Format is the
>    element type in both. No sink protocol (the no-append-on-protocol decision stands).

**Companion lint candidate** (out of scope; for `lint-rule-promotion`): flag any type conforming to a
format sibling AND a (retired) canonical operational protocol; flag any bare-marker format sibling
(a sibling protocol with no static verb).

### 13. Cognitive-dimensions check ([RES-025])

| Dimension | Assessment |
|---|---|
| **Visibility** | Each representation is a named conformance + named verb + named accessor; the format is visible at the type level (the element-type `where`-clause), never a runtime bool or a hidden coder. |
| **Consistency** | Every format sibling has the identical shape (a static verb keyed by element type); Binary and ASCII become symmetric (the asymmetry was the lone inconsistency). |
| **Viscosity** | Adding a format = one additive sibling + verb. Adding a variant = one witness value. Removing the canonical tier removes a whole construct from the surface authors must triage. |
| **Role-expressiveness** | `Binary.Serializable`/`ASCII.Serializable` read as "wire form"/"text form"; a witness value reads as "which variant"; a parser witness reads as "parse with this context". |
| **Error-proneness** | The chief hazards are **structurally eliminated**, not left to vigilance: the bridge (silent wire-from-text mis-derivation) is deleted; the `@_implements` anchor trap cannot fire (no `associatedtype` on the verb-bearing siblings, Exp 1); format mismatches fail closed at compile time (Exp 1-neg). |
| **Abstraction gradient** | Consumers use accessors (low); authors write per-format verbs (medium); the only new concept is "format = element type, variant/context = witness value", which names structure that already half-existed (`Binary.Serializable`'s verb; `Serializer.Protocol`'s `Buffer`). |

### 14. Gating resolved

- **W3 (dual-/defunctionalize-witness migration of IPv4/IPv6).** Unblocked: the witness shapes are
  specified — two flat symmetric verbs (wire + text) per type, variants as `Serializer.Protocol`
  witness values; the bespoke bodies preserved (§9, §10).
- **W4 (delete `Binary.ASCII` namespace + the deprecated protocol).** Unblocked: IPv4/IPv6 (the last
  consumers) migrate to the symmetric verbs; the deprecated refinement and the bridge are deleted.
- **IPv4/IPv6 migration.** Specified (§10), including the dead-RFC-5952 unification (§6 defect 2).
- **Context / OQ2.** Resolved (§11): parser witness value, no sub-sibling.
- **Sink.** Resolved (§7): `RangeReplaceableCollection` default + `OutputSpan` perf path; no sink
  protocol.

---

## Outcome

**Status: RECOMMENDATION.**

**The ONE design.** A format codec is a **self-contained flat sibling carrying its own static
universal verb keyed by the sink's element type** (`Byte` ⇒ wire, `ASCII.Code` ⇒ text, tree node ⇒
tree; the collection is free). A type conforms to **exactly the siblings it has** — `|siblings| = 1`
IS "single inherent codec", `|siblings| ≥ 2` is multi-representation, **both ordinary**; the
**canonical operational tier dissolves** (there is nothing to decline, no bridge). **VARIANTS** and
**parse CONTEXT** are carried by a **witness VALUE passed in** (serde `DeserializeSeed` shape;
Rendel-Ostermann "N forms = N descriptions"), never an `associatedtype` on the flat marker. The
canonical `static var serializer` is **retired** for byte/text streams; the ASCII→binary bridge is
**deleted**; the root-cause fix is **symmetrising `ASCII.Serializable`** (give it the verb
`Binary.Serializable` already has). The sink is `RangeReplaceableCollection` (default) +
`OutputSpan<E>` (perf), one format axis, **no sink protocol** (the no-append-on-protocol decision is
respected, not reopened).

**This supersedes** `multi-representation-value-codec-attachment.md` v1.0.0: the carve-out kept the
canonical tier and made multi-representation types decline it; first principles **delete the tier**,
so multi-representation types are not special and there is no decline-dance. The forcing functions
IPv4/IPv6 are ordinary two-sibling values.

**Empirically settled (build-truth, Swift 6.3.3).** Six probes confirm every load-bearing premise:
format-by-element-type resolution + fail-closed (Exp 1); SIL-cleanliness under `-sil-verify-all`
(Exp 2); context-as-parser-witness with no `associatedtype` (Exp 3); `borrowing`/~Copyable ownership
(Exp 4); RRC ∥ OutputSpan sink coexistence (Exp 5a) and ownership (Exp 5b). Prior art
primary-source-verified (serde, swift-parsing, Codable, Rendel-Ostermann, swift-iterator-primitives;
the iterator precedent honestly classified as partial — trap-PAID, instance-verb).

**Class-(c) discipline.** The model as stated changes **no canonical protocol on its own
authority**. The **canonical retirement (§8)** and the **`[FAM-002]/[FAM-003]/[FAM-005]/[FAM-010]`
re-cut + `[FAM-012]` (§12)** are **surfaced for principal ratification via `skill-lifecycle`**, not
made. This is the substantive escalation: the carve-out doc stayed inside "modify nothing canonical";
the first-principles answer requires retiring the canonical operational tier, which is a
canonical-protocol modification and therefore surfaced.

**Gating.** W3, W4, the IPv4/IPv6 migration, and the Context/OQ2 decision are all unblocked; the
cascade preserves the bespoke serializer logic and changes only conformance scaffolding + call sites
(§9). Research + throwaway `/tmp` probes only; no production source or cascade package was touched.

---

## References

**Primary internal sources** ([Verified: 2026-06-30], live source):
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitive/Serializable.swift:8-25` — canonical `Serializable` (retire target); the IPv4 doc-comment irony
- `…/Serializer Primitive/Serializer.Protocol.swift:34-68` — `Serializer.Protocol<Output,Buffer,Failure>` (the variant-witness value type)
- `…/Serializer Witness Primitives/Serializer.Witness{,+Protocol}.swift` — leaf witness; A16 Option-1 relocation
- `swift-primitives/swift-binary-serializer-primitives/.../Binary.Serializable.swift:42-55` — the static-verb template
- `swift-primitives/swift-ascii-serializer-primitives/.../ASCII.Serializable.swift:10-36` — the bare marker (root-cause asymmetry)
- `…/Serializable ASCII Primitives/Binary.Serializable+ASCII.swift:19-36` — the ASCII→binary bridge (delete)
- `…/Serializable ASCII Primitives/Serializable+ASCII.swift` — `.asciiCodes`/`.serialized` (re-derive)
- `…/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift:14-35` — deprecated refinement (delete, W4)
- `swift-primitives/swift-binary-parser-primitives/.../Binary.Parseable.swift:61-76`, `Binary.Parse.Failure.swift:15-22` — parse verb, fixed Failure
- `swift-primitives/swift-ascii-parser-primitives/.../ASCII.Parseable.swift:10-33` — bare marker
- `swift-primitives/swift-byte-primitives/.../Byte.swift:36-48`, `swift-primitives/swift-ascii-primitives/.../ASCII.Code.swift:34-44` — disjoint `@frozen struct`s (the format axis)
- `swift-ietf/swift-rfc-791/Sources/RFC 791/RFC_791.IPv4.Address.swift:130-160,162-210` — IPv4 wire + (deprecated) text bodies (preserve)
- `swift-ietf/swift-rfc-4291/Sources/RFC 4291/RFC_4291.IPv6.Address.swift:129-197,361-401` — IPv6 (deprecated) text + wire bodies
- `swift-ietf/swift-rfc-5952/Sources/RFC 5952/RFC_4291.IPv6.Address+RFC_5952.swift:39-102` — the DEAD RFC 5952 canonical serializer (revive as default)
- `swift-primitives/swift-buffer-primitives/Sources/Buffer Protocol Primitives/Buffer.Protocol.swift:80-85` + `Research/storage-generic-buffer-core.md` — the no-append-on-protocol specialization decision
- `swift-primitives/swift-buffer-linear-primitives/.../Buffer.Linear+OutputSpan.swift` — `OutputSpan` write region (the perf sink target)

**Convention / antecedent docs:**
- `swift-institute/Research/multi-representation-value-codec-attachment.md` v1.0.0 — **SUPERSEDED** by this doc (the per-corner carve-out generalised)
- `swift-institute/Research/2026-05-15-family-codable-convention.md` — [FAM-001..009]
- `swift-foundations/swift-json/Research/family-codable-convention.md` — [FAM-001..008] incl. [FAM-007]
- `swift-institute/Research/family-codable-contextual-parsing.md` — OQ2 (resolved here, §11)
- `swift-institute/Research/sibling-refines-canonical-attachment.md` — [FAM-010] (absorbed, §12)
- `swift-institute/Research/canonical-attachment-semantic.md` — conformer inventory; the orthogonal Common.Codable axis ([FAM-011])
- `swift-institute/Research/serializer-leaf-witness-bodyless-fix-options.md` — A16 SIL crash + Option 1 (Exp 2)
- `swift-institute/Research/unified-iteration-design.md`, `swift-primitives/swift-iterator-primitives/.../Iterable.swift`, `swift-sequence-primitives/.../Sequenceable.swift` — the Iterable ∥ Sequenceable precedent (§3, partial)
- `swift-institute/Research/transformation-domain-architecture.md` — parse/serialize inverse (the partial-isomorphism law)

**External prior art** (primary-source-verified per [RES-021]/[RES-032]; [Verified: 2026-06-30]):
- Rust serde 1.0.228 — `serde_core/src/{ser,de}/*.rs`: `Serialize::serialize<S: Serializer>` (generic-not-dyn), `Serializer::is_human_readable` (the rejected runtime bool), `DeserializeSeed` (the adopted seed-carries-context shape); `https://docs.rs/serde/1.0.228`, `https://serde.rs/data-model.html`. Note: trait source moved to the new `serde_core/` crate (old `serde/src/...` paths 404).
- pointfree swift-parsing — `Parser<Input,Output>`/`ParserPrinter` (the `Input`-is-the-type-axis insight); `https://github.com/pointfreeco/swift-parsing`
- Swift Codable — `encode(to encoder: any Encoder) throws` (existential + untyped throws; no `is_human_readable`); `stdlib/.../Codable.swift`, SE-0166
- Rendel & Ostermann, "Invertible Syntax Descriptions: Unifying Parsing and Pretty Printing," Haskell Symposium 2010 — partial isomorphisms; "one abstract value ↔ multiple concrete representations" (the variant axis); `https://www.informatik.uni-marburg.de/~rendel/unparse/rendel10invertible.pdf` (the "several variants need several printer descriptions" reading is design-implied, marked UNVERIFIED)

**Embedded experiments** (Swift 6.3.3, throwaway `/tmp` per principal directive; reproducible; §5):
- `codec-probes/exp1-format-resolution.swift` (+ negatives) — format-by-element-type resolution, fail-closed
- `codec-probes/exp2a.swift`, `exp2b.swift` — SIL-cleanliness under `-sil-verify-all` (A16)
- `codec-probes/exp3.swift` — context-as-parser-witness, no `associatedtype` on flat marker
- `codec-probes/exp4b.swift` — `borrowing`/~Copyable ownership
- `codec-probes/exp5a-coexistence.swift`, `exp5b-span-ownership.swift` — RRC ∥ OutputSpan sink coexistence + ownership
