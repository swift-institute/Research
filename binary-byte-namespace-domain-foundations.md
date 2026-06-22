# Binary, Byte, Bit — Namespace Domain Foundations

<!--
---
version: 3.2.0
last_updated: 2026-06-22
status: IMPLEMENTED
tier: 3
scope: ecosystem-wide
applies_to:
  - swift-bit-primitives
  - swift-byte-primitives
  - swift-byte-parser-primitives
  - swift-byte-serializer-primitives
  - swift-binary-primitives
  - swift-binary-parser-primitives
  - swift-binary-coder-primitives
  - swift-binary-base-primitives
  - swift-binary-leb128-primitives
depends_on:
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-institute/Research/byte-arithmetic-conformance.md
  - swift-institute/Research/binary-primitives-package-decomposition.md
  - swift-institute/Research/byte-cursor-primitive-unification.md
  - swift-institute/Research/transformation-domain-architecture.md
  - swift-institute/Research/broader-l2-l3-byte-typing-gap-plan.md
  - swift-institute/Research/2026-05-19-w2-byte-cascade-structural-issue.md
normative: true
---
-->

## Context

The ecosystem now contains, in parallel, two families of byte-level packages whose relationship has never been written down from first principles:

| Older (pre-byte arc) | Newer (post-byte arc, 2026-05-15…2026-05-19) |
|---|---|
| `swift-binary-primitives` (Namespace + Core + Serializable + Parseable + Format + Cursor + LEB128 + Base) | `swift-byte-primitives` (Byte value type + Byte.Protocol capability marker) |
| `swift-binary-parser-primitives` (Binary.Bytes.Parser + Binary.Bytes.Input + Binary.Bytes.Machine + LEB128/Integer parsers) | `swift-byte-parser-primitives` (Byte.Parser + Byte.Input + Byte.Literal.Parser) |
| `swift-binary-coder-primitives` (Binary.Coder) | `swift-byte-serializer-primitives` (Byte.Serializer + Byte.Literal.Serializer) |
| `swift-binary-leb128-primitives` (LEB128 encoding mechanism) | — |
| `swift-binary-base-primitives` (Binary.Base.N — base-16/32/64) | — |

The byte-arc (2026-05-15) extracted `Byte` from inside `swift-parser-primitives` to its own L1 package with no parser dependency, and split `Byte.Parser` to its own sibling L1 package. The byte-protocol-capability-marker decision (v1.1.0, 2026-05-15) locked `UInt8 ≢ Byte.Protocol`. The byte-arithmetic-conformance decision (v1.0.0, 2026-05-19) locked `Byte ≢ stdlib-arithmetic`. The W2 cascade (2026-05-19) retyped `Binary.Serializable.Buffer.Element` from `UInt8` to `Byte`, propagating byte-domain identity into `swift-binary-primitives`' protocol surface.

The result is a moment of architectural coherence — but also of architectural overlap. The principal raised the following at 2026-05-20:

> *"For our byte ecosystem, we now have bit-primitives, byte-primitives, which are newer and more in line with our ecosystem, as well as their relevant parser/serializer/coder packages. However, previously we had binary-primitives (and binary-parser-primitives), these are older. I have a few questions as I'm unsure whether binary-primitives is well organized. In particular, why do we have binary-parser-primitives and binary-serializer-primitives. Should this perhaps be byte-parser-primitives and byte-serializer-primitives? Or is using Binary justified here? In particular Binary is just a namespace here, isn't it? But what IS Binary, from first principles? Just a Collection of Bytes? If so, would it make MORE sense to do binary as literal typealias to Collection<Byte>? And what about parser/serializer relation to it? For example, could we build binary-parser on a theoretical byte-parser?"*

This research answers those questions from first principles, classifies the relationship between `Bit`, `Byte`, and `Binary` as semantically distinct domain layers, and prescribes the canonical organization across the existing nine packages.

### Trigger

[RES-001] Architecture choice — the relationship between `Bit`, `Byte`, and `Binary` as ecosystem-wide namespace domains, plus the relationship between their parser/serializer/coder companions, has never been written down from first principles. Adjudicating this is precedent-setting for every future package that touches binary-encoded data (DWARF, WASM, Protobuf, every binary network protocol, every binary file format).

### Constraints

- **[BET-*]** Swift Institute core conventions — namespaces are nouns; `enum Namespace { ... }` empty-shell pattern.
- **[API-NAME-001]** Nest.Name pattern; no compound type names.
- **[API-NAME-001b]** LargerDomain.Subdomain (subject-first when domain exceeds role).
- **[API-NAME-001c]** Per-domain capability-marker protocol pattern; the recipe is manual application per domain.
- **[ARCH-LAYER-001]** Five-layer downward-only dependencies; L1 packages depend only on lower-tier L1 packages.
- **[MOD-DOMAIN]** One semantic domain per package.
- **[MOD-RENT]** Three-criteria primitive-package rent test (capability + consumer + theoretical content).
- **[PRIM-FOUND-001]** No Foundation in any L1 package.
- **[RES-018]** Premature cross-cutting primitive anti-pattern; cases (a)–(d) classification.
- **[RES-019]** Step-0 internal research grep before external survey.
- **[RES-020]** Research tiers — Tier 3 = ecosystem-wide, precedent-setting, hard-to-undo, mandatory formalization.
- **[RES-021]** Prior art survey with contextualization step.
- **[RES-023]** Systematic literature review per Kitchenham methodology.
- **[RES-024]** Formal semantics required for Tier 3.
- **[RES-029]** Framing-challenge for binding/membership/placement questions — semantic identity first, cost as tiebreaker only.
- **[API-BYTE-001..006]** byte-discipline skill — UInt8/Byte sibling-form, byte-vs-arithmetic-domain axis.
- **byte-cursor-primitive-unification.md** v1.3.0 IN_PROGRESS — successor Tier 3 arc on "Cursor Abstractions Across the Institute L1 Ecosystem" is in flight; this doc's outcome must NOT pre-determine that arc's outcome.

### Stakeholders

Every package in the ecosystem that touches binary-encoded data:

- **Direct**: nine packages enumerated in the Context table.
- **Downstream L2 consumers**: `swift-rfc-4122` (UUID), `swift-rfc-4648` (Base16/32/64), `swift-rfc-791` (IPv4), `swift-rfc-3596` (IPv6), `swift-rfc-7519` (JWT), `swift-rfc-8446` (TLS), `swift-rfc-9293` (TCP), `swift-iso-32000` (PDF), `swift-incits-4-1986` (US-ASCII), `swift-x86-standard`, `swift-cpu-primitives`, `swift-sockets`, etc.
- **Downstream L3 composition consumers**: `swift-file-system`, `swift-paths`, `swift-json`, `swift-html`, `rule-legal-nl`, etc.
- **Future Tier 3 cursor-abstractions arc**: this doc surfaces a structural finding that the successor arc will compose against.

## Questions

### Q1 — Is using "Binary" justified as a namespace?

Or should the binary-* packages be absorbed into the byte-* packages?

### Q2 — From first principles, what IS Binary?

Is it: (a) a collection of bytes, (b) a representation domain distinct from byte collections, (c) something else?

### Q3 — Should Binary be a typealias for Collection<Byte>?

The principal's specific hypothesis. Would this make more sense than a separate namespace?

### Q4 — Why do we have binary-parser-primitives and (proposed) binary-serializer-primitives?

What semantic content justifies their existence as siblings to byte-parser-primitives and byte-serializer-primitives?

### Q5 — Could binary-parser be built on a theoretical byte-parser?

Empirically — what does the current dependency graph say, and what is the principled answer?

### Q6 — What is the relationship between Bit, Byte, and Binary as domain layers?

Specifically the type-theoretic and category-theoretic relationship.

### Q7 — What is the canonical organization across all nine packages?

The architecture writ in one place.

## Internal Research Survey [per [RES-019]]

```bash
grep -rl "binary-primitives\|byte-primitives\|bit-primitives\|binary-parser\|binary-serializer" \
  /Users/coen/Developer/swift-institute/Research/ 2>/dev/null
```

[Verified: 2026-05-20] 26 ecosystem-wide research docs match. The load-bearing ones, in chronological order:

| Document | Status | Bearing |
|---|---|---|
| `transformation-domain-architecture.md` v3.4.0 | DECISION (2026-05-13) | The umbrella DECISION that established Parser/Serializer/Coder/Formatter as four independent top-level capability domains, each with their own package. Locks the cross-domain capability-package convention this doc inherits. |
| `binary-buffer-primitives-architectural-review.md` v1.0.0 | DECISION (2026-02-24) | Deleted `swift-binary-buffer-primitives`; `Buffer.Aligned` moved to `swift-buffer-primitives` with `where Element == UInt8`. Precedent: when a "binary X" package is 86% non-binary content, it absorbs into the non-binary host. |
| `binary-primitives-package-decomposition.md` v1.0.0 | RECOMMENDATION (2026-05-07) | Per-sub-product analysis of LEB128 / Format / Serializable / Coder splits. SPLIT recommendations for LEB128 + Serializer; HOLD for Format; DO-NOT-EXTRACT for Coder. The execution record for the older binary-* family. |
| `byte-primitive-extraction-and-domain-naming.md` v1.0.1 | DECISION (2026-05-15) | The byte-arc that extracted `Byte` to its own L1 package + split `Byte.Parser` to a sibling L1 package. Promoted `[API-NAME-001b]` (Subject-First when domain exceeds role). Binary-stack audit GREEN: no Binary→Byte dep introduced. |
| `byte-protocol-capability-marker.md` v1.1.0 | RECOMMENDATION (2026-05-15) | Tier 3. UInt8 MUST NOT conform to Byte.Protocol. Per-domain manual recipe is canonical. Establishes UInt8 (arithmetic carrier) vs Byte (byte-domain twin) as semantic siblings, not refinement-related. |
| `byte-cursor-primitive-unification.md` v1.3.0 | IN_PROGRESS (2026-05-17 downgrade) | Investigation of whether `Binary.Bytes.Input.View`, `Lexer.Scanner`, and `Binary.Cursor` should unify under one Cursor<DomainTag> primitive. Discovered the decomposition probe: `Text.Position ≡ Tagged<Text, Ordinal>` and `Index<Byte> ≡ Tagged<Byte, Ordinal>` already exist as shared substrate. Downgraded to IN_PROGRESS pending the Tier 3 successor arc "Cursor Abstractions Across the Institute L1 Ecosystem." |
| `broader-l2-l3-byte-typing-gap-plan.md` v1.0.0 | IN_PROGRESS (2026-05-19) | The W1–W6 byte-typing program. W2 retyped `Binary.Serializable.Buffer.Element == UInt8 → Byte`. Established the byte-vs-arithmetic-domain axis as the load-bearing classification. |
| `2026-05-19-w2-byte-cascade-structural-issue.md` v0.1.0 | REPORT_FOR_REVIEW | Surfaces the discrimination rubric (`Stays UInt8` arithmetic-domain vs `Retype to Byte` byte-domain). |

**Internal research governs** per [RES-019]. The external survey extends the picture but does not override.

## Empirical State Verification [per [RES-023]]

| Claim | Verification | Result |
|---|---|---|
| `swift-binary-primitives/Sources/Binary Namespace/Binary.swift` declares `public enum Binary {}` with doc "Bit and byte level operations and types" | Read file:1-15 | [Verified: 2026-05-20] confirmed. |
| `swift-binary-primitives/Sources/Binary Primitives Core/Binary.Bytes.swift` declares `extension Binary { public enum Bytes {} }` (sub-namespace) | Read file:1-7 | [Verified: 2026-05-20] confirmed. |
| `swift-binary-primitives/Sources/Binary Primitives Core/` contains representation-domain types: Position, Endianness, Pattern, Mask, Space, Optionator, Aligned, plus per-width FixedWidthInteger+Binary extensions | `ls Binary Primitives Core/` | [Verified: 2026-05-20] 35 files including `Binary.Position.swift`, `Binary.Endianness.swift`, `Binary.Pattern.swift`, `Binary.Mask.swift`, `Binary.Space.swift`, `Binary.Optionator.swift`, `Binary.Aligned.swift`, `FixedWidthInteger+Binary.swift`, `Int8/16/32/64.swift`, `UInt/UInt8/16/32/64.swift`. Confirmed — Binary owns representational concerns, not just storage. |
| `swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift` declares `Buffer.Element == Byte` (post-W2) | Read file:42-56 | [Verified: 2026-05-20] confirmed. Substrate is `Buffer.Element == Byte` and `Bytes.Element == Byte`. |
| `swift-byte-primitives/Sources/Byte Primitives/Byte.swift` declares `@frozen public struct Byte` with `public let underlying: UInt8` | Read file:36-46 | [Verified: 2026-05-20] confirmed. `Byte` is a value-type wrapper; `Sendable` only. |
| `swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift` declares `Byte.Protocol` as a SIBLING to Carrier.Protocol (not a refinement), with `var byte: Byte { get }` accessor and `init(_ byte: Byte)` injection | Read file:43-103 | [Verified: 2026-05-20] confirmed. UInt8 explicitly NOT a conformer. |
| `swift-byte-parser-primitives/Sources/Byte Parser Primitives/Byte.Parser.swift` declares `struct Byte.Parser<Input>` where `Input.Element == Byte`, conforming to `Parser_Primitives_Core.Parser.Protocol` | Read file:18-54 | [Verified: 2026-05-20] confirmed. Single-byte literal-matching parser; lives in Byte domain per [API-NAME-001b]. |
| `swift-byte-serializer-primitives/Sources/Byte Serializer Primitives/Byte.Serializer.swift` declares `struct Byte.Serializer<Buffer>` where `Buffer.Element == Byte`, conforming to `Serializer.Protocol` | Read file:11-37 | [Verified: 2026-05-20] confirmed. Single-byte serializer; symmetric to Byte.Parser. |
| `swift-binary-parser-primitives/Package.swift` depends on `swift-byte-primitives` AND `swift-byte-parser-primitives` | Read Package.swift dependencies | [Verified: 2026-05-20] confirmed at lines 62-63. **Binary-parser IS already built on byte-parser at the dependency level.** |
| `swift-binary-parser-primitives/Sources/Binary Parser Primitives/` contains: Core, Input, Input.View, Machine, Borrowed, Parse, LEB128 Parser, Integer Parsers | `ls Sources/` | [Verified: 2026-05-20] confirmed — 9 sub-modules. The Binary parser carries far more than byte parsing: cursor machinery, state machine, binary-encoding-specific integer parsers, LEB128 (variable-length) parsing. |
| `swift-binary-coder-primitives` exists as its own package per `transformation-domain-architecture.md` v3.4.0 | `ls swift-primitives/swift-binary-coder-primitives/` | [Verified: 2026-05-20] confirmed (13 entries listed). |
| `swift-byte-serializer-primitives` Package.swift depends ONLY on swift-serializer-primitives + swift-byte-primitives | Read file:24-27 | [Verified: 2026-05-20] confirmed — lean dependency surface. |
| `Binary.Bytes` is a sub-namespace inside the Binary domain, extended by Binary parsing/serializing for `Input` and `Machine` types | Doc comment at Binary.Bytes.swift:1-6 | [Verified: 2026-05-20] confirmed. |
| No package called `swift-binary-serializer-primitives` currently exists | `ls swift-primitives/ \| grep binary-serializer` | [Verified: 2026-05-20] not found. The package is RECOMMENDED to be created per `binary-primitives-package-decomposition.md` but not yet authored. |

## Prior Art Survey [per [RES-021]]

Three parallel subagent surveys (Rust / Haskell / Go+OCaml) verified primary sources at write-time. Full per-survey content lives at:

- `swift-institute/Research/_subagent-outputs/binary-byte-namespace-domain-foundations/2026-05-20-rust-survey.md` (transcribed)
- `swift-institute/Research/_subagent-outputs/binary-byte-namespace-domain-foundations/2026-05-20-haskell-survey.md` (transcribed)
- `swift-institute/Research/_subagent-outputs/binary-byte-namespace-domain-foundations/2026-05-20-go-ocaml-survey.md` (transcribed)

(*The `_subagent-outputs/` directory is local-only and not committed; the synthesis below carries all load-bearing claims with their verified URLs.*)

### Rust ecosystem [Verified: 2026-05-20]

| Crate | Owns | Does NOT own | Insight |
|---|---|---|---|
| `bytes` ([docs.rs/bytes](https://docs.rs/bytes/latest/bytes/)) | `Bytes`/`BytesMut` storage; `Buf`/`BufMut` traits with **endianness baked into method names** (`get_u16`, `get_u16_le`, `get_u16_ne`) [[docs.rs/bytes/Buf](https://docs.rs/bytes/1.10.1/bytes/buf/trait.Buf.html)] | Parsers, serializers, Serialize/Deserialize traits | Folds storage + cursor + endian-aware numeric decoding into one trait. Equivalent of institute's `Binary.Cursor` + `Binary.Endianness` + `Binary.Position` collapsed onto a buffer-typed trait. |
| `byteorder` ([docs.rs/byteorder](https://docs.rs/byteorder/latest/byteorder/)) | `ByteOrder` phantom/sealed trait with `BigEndian`/`LittleEndian` marker types; extension traits `ReadBytesExt`/`WriteBytesExt` | Buffer storage; no concrete buffer type | Endianness is a typeclass dispatched at `T::read_u16(&[0,1])`. Lives in a separate crate from `bytes`. Equivalent of institute's `Binary.Endianness` enum + dispatch. |
| `bitvec` ([docs.rs/bitvec](https://docs.rs/bitvec/latest/bitvec/)) | `BitArray`, `BitSlice`, `BitVec` — bit-addressed storage | Byte-level types; parsing; serialization is opt-in via serde feature | **Bits and bytes are fully separate crates.** No dependency between `bytes` and `bitvec`. Mirrors institute's `swift-bit-primitives` ≠ `swift-byte-primitives` split. |
| `nom` ([docs.rs/nom](https://docs.rs/nom/latest/nom/)) | Parser combinators with sibling sub-modules `nom::bytes`, `nom::bits`, `nom::number`. Each cuts orthogonally by `complete` vs `streaming` | Storage; serializer | **"Binary" does not appear as a namespace.** Numeric decoding (with endianness suffix `be_u32`/`le_u32`) lives in `nom::number`, not `nom::binary`. Bytes and bits are siblings, not parent/child. |
| `serde` + `bincode`/`postcard` ([docs.rs/serde](https://docs.rs/serde/latest/serde/), [docs.rs/bincode](https://docs.rs/bincode/2.0.1/bincode/), [docs.rs/postcard](https://docs.rs/postcard/latest/postcard/)) | Format-agnostic `Serialize`/`Deserialize` traits split into `serde::ser` and `serde::de`. Concrete binary formats: `bincode`, `postcard`, `rkyv` — peer crates | A unified `binary` namespace inside serde | **serde explicitly refuses to namespace "binary"** — uses `ser`/`de` and lets format-specific crates own their own names. `postcard` calls itself "wire format" rather than "binary serialization." |
| `leb128` ([docs.rs/leb128](https://docs.rs/leb128/latest/leb128/)) | Variable-length integer encoding (DWARF spec); standalone crate; no deps | Other encodings | Each named encoding family is its own tiny crate. Direct precedent for `swift-binary-leb128-primitives`. |
| `deku` ([docs.rs/deku](https://docs.rs/deku/latest/deku/)) | Declarative bit-and-byte-level binary parser derive. Bridges `bitvec` (bits) + `std::io` (bytes) symmetrically with `DekuRead`/`DekuWrite` | Storage abstraction | **The only Rust crate where "binary" is the load-bearing word in positioning.** Earns it because it spans bit + byte granularity symmetrically read/write — exactly the surface `Binary.Serializable` + `Binary.Parseable` covers. |

**Rust synthesis**: The ecosystem distributes the institute's `Binary.*` concerns across `bytes` (storage + cursor + endian-suffixed reads), `byteorder` (endianness typeclass), `nom` (parsing combinators), and format-specific peer crates (bincode/postcard/serde). The crate that *does* earn the "binary" label (deku) does so by **spanning bit + byte symmetrically read/write** — i.e., when binary is a unifying domain over both bit-level and byte-level encoding semantics. No Rust crate collapses "binary" to "byte collection."

### Haskell ecosystem [Verified: 2026-05-20]

| Module/Package | Owns | Does NOT own | Insight |
|---|---|---|---|
| `Data.Word.Word8` ([hackage/base/Data-Word](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Word.html)) | The 8-bit unsigned integer + stdlib numeric instances | Any notion of "byte" as a domain | **Haskell deliberately models Word8 as a number, not a byte.** No sibling distinction between Byte and Word8. The "byteness" begins at the container, not the scalar. |
| `Data.Bits` ([hackage/base/Data-Bits](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bits.html)) | The `Bits` typeclass polymorphic over any integral type | Byte-shaped ops; endianness | Bit manipulation is one polymorphic typeclass over Int / Integer / Word8 / Word16. No per-width split. |
| `Data.ByteString` ([hackage/bytestring](https://hackage.haskell.org/package/bytestring)) | "Byte vectors using packed Word8 arrays"; strict/lazy/short variants; `Builder` for efficient construction | Unicode text; character encoding | **`Data.ByteString.Builder.Prim` (inside the storage package) owns `word16LE/BE`, `word32LE/BE`, `floatLE/BE`, `FixedPrim`/`BoundedPrim` typed-encoder catalog** [[hackage/bytestring/Builder.Prim](https://hackage-content.haskell.org/package/bytestring-0.12.2.0/docs/Data-ByteString-Builder-Prim.html)]. **The storage package itself owns representation-domain endianness primitives.** ByteString is NOT a typealias for `[Word8]`. |
| `Data.Binary` ([hackage/binary](https://hackage.haskell.org/package/binary)) | `Binary` typeclass + `Put`/`Get` monads, both with full endianness catalogs | Storage (delegates to lazy ByteString) | **"Binary" in Haskell is a capability typeclass + a pair of monads, NOT a namespace and NOT a typealias.** The package name "binary" denotes binary serialization (vs textual serialization à la `show`/`read`), not "the byte representation domain." |
| `attoparsec` ([hackage/attoparsec](https://hackage.haskell.org/package/attoparsec/docs/Data-Attoparsec-ByteString.html)) | Incremental byte-stream parser combinators: `word8`, `anyWord8`, `satisfy`, `string`, `takeWhile` | Endianness primitives (those live in `binary.Get`) | **attoparsec separates "byte parsing" from "binary decoding"** explicitly. Byte parsing is structural (find delimiters, take ranges, satisfy predicates); binary decoding (LE/BE/host) lives in `Data.Binary.Get` and `Data.Serialize.Get`. **Two libraries, two abstractions, same substrate.** This is the cleanest external precedent for the institute's `byte-parser-primitives` ≠ `binary-parser-primitives` boundary. |
| `cereal` ([hackage/cereal](https://hackage.haskell.org/package/cereal)) | `Serialize` typeclass over strict ByteString; `isolate` parser-isolation primitive; dedicated IEEE754 module | — | Coexists with `binary` because the substrate choice (strict vs lazy) is itself a representation-domain decision worth its own library. **The community refused to collapse them.** |

**Haskell synthesis**: Binary is a representation domain, but Haskell **distributes** ownership across three packages (bytestring + binary + cereal) rather than concentrating it in one namespace. Crucially: (a) `Word8` carries no byte-domain semantics — byteness begins at the container; (b) the storage package itself owns endianness primitives — `ByteString` is NOT just `[Word8]`; (c) byte parsing (attoparsec) and binary decoding (binary.Get) are deliberately separate libraries running along the **endianness-in-scope axis**.

### Go + OCaml ecosystems [Verified: 2026-05-20]

**Go**:

| Aspect | Finding |
|---|---|
| `builtin.byte` ([pkg.go.dev/builtin](https://pkg.go.dev/builtin)) | Type alias `type byte = uint8`. No nominal distinction. Used "by convention, to distinguish byte values from 8-bit unsigned integer values." Weakest form of byte-domain isolation. |
| `bytes` ([pkg.go.dev/bytes](https://pkg.go.dev/bytes)) | "Functions for the manipulation of byte slices. Analogous to the strings package." Owns `Buffer`/`Reader` + string-style ops (search, split, trim). Does NOT own endianness or encoding. |
| `encoding/binary` ([pkg.go.dev/encoding/binary](https://pkg.go.dev/encoding/binary)) | "Simple translation between numbers and byte sequences and encoding and decoding of varints." Owns `ByteOrder` interface, `BigEndian`/`LittleEndian` values, varint family. **Lives at `encoding/binary`, peer to `encoding/json`, `encoding/xml`, `encoding/gob`.** |
| `encoding` ([pkg.go.dev/encoding](https://pkg.go.dev/encoding)) | `BinaryMarshaler`/`BinaryUnmarshaler` vs `TextMarshaler`/`TextUnmarshaler` — **Go promotes the binary/text distinction to a top-level interface concern.** |
| `io.Reader`/`io.Writer` | Strictly byte-typed transport. `encoding/binary.Read(r, order, data)` composes binary-domain (`ByteOrder`) over byte-stream (`io.Reader`). |

**OCaml**:

| Aspect | Finding |
|---|---|
| `Bytes` ([ocaml.org/manual/Bytes](https://ocaml.org/manual/5.2/api/Bytes.html)) | Mutable byte container. Endianness exposed as method-name suffixes (`get_int32_be`/`get_int32_le`). No `Binary.Endianness` peer module. |
| `Buffer` ([ocaml.org/manual/Buffer](https://ocaml.org/manual/5.2/api/Buffer.html)) | Auto-expanding buffers. Has a "Binary encoding of integers" SECTION (not a separate module). `add_int32_le`/`add_int32_be`. |
| `Cstruct` ([github.com/mirage/ocaml-cstruct](https://github.com/mirage/ocaml-cstruct)) | Typed views over byte buffers; PPX-generated field accessors. **Endianness as named sub-modules: `Cstruct.BE`, `Cstruct.LE` as peer namespaces inside Cstruct.** |
| `Angstrom` ([github.com/inhabitedtype/angstrom](https://github.com/inhabitedtype/angstrom)) | Parser combinators "written with network protocols and serialization formats in mind." **Does NOT split byte-parser from text-parser** — unified API. |
| `Iobuf` (Jane Street, [ocaml.org/p/core_kernel/Iobuf](https://ocaml.org/p/core_kernel/latest/doc/Iobuf/index.html)) | Industrial-grade buffer with `Peek`/`Poke`/`Consume`/`Fill` + `Window`/`Limits` bounds tracking + endianness via integer-representation sub-modules. **The closest OCaml analog to "binary representation domain," but the type is named `Iobuf`, not `Binary`.** |

**Go + OCaml synthesis**: Go has `encoding/binary` as a peer-of-text encoding namespace — narrowly scoped to byte-order + fixed-width + varint. It does NOT own position/cursor/pattern/parseable — those are in `io` (transport), `encoding` (marshaler interfaces), per-protocol code. OCaml has no top-level `Binary` namespace at all; binary encoding is a section of `Buffer`, sub-modules `BE`/`LE` of `Cstruct`, or industrial `Iobuf`.

### Contextualization step [per [RES-021]]

**Pattern identified across surveyed systems**: byte storage (`bytes`/`bytestring`/`Bytes`) and binary-encoding rules (endianness + varint + fixed-width) are **always distinguished** at the type-system level — even when collapsed into a single trait/module (`bytes::Buf`, `Buffer.add_int32_le`), the distinction is mechanically visible. **No surveyed ecosystem collapses "binary" to "collection of bytes."**

The variance is in *concentration vs distribution*:
- **Concentrated** (Go `encoding/binary`): one namespace owns byte-order + Read/Write composition + varint, narrowly scoped, peer to other encoding namespaces.
- **Distributed** (Haskell): byte-storage primitives at `bytestring`, binary-class at `binary`, byte-parser at `attoparsec`, alternative-substrate at `cereal`. Endianness primitives appear in *all four* — duplicated, not centralized.
- **Folded onto buffer** (Rust `bytes::Buf`, OCaml `Buffer`): endianness becomes method-name suffixes on the byte-buffer trait itself. No separate "binary" namespace.
- **Folded onto typed-view library** (Rust `deku`, OCaml `Cstruct`): the "binary" framing is earned when a library spans bit + byte symmetrically with structured-access.

The institute's current shape (`Binary.*` namespace owning Endianness + Position + Pattern + Mask + Space + Cursor + Serializable + Parseable + Coder + Format) is **stricter than any surveyed prior art**. It concentrates in one namespace what Rust distributes across `bytes` + `byteorder` + `nom` + `bincode`, what Haskell distributes across `bytestring` + `binary` + `attoparsec` + `cereal`, what Go distributes across `bytes` + `encoding/binary` + `encoding` + `io`, and what OCaml distributes across `Bytes` + `Buffer` + `Cstruct` + `Iobuf` + `Angstrom`.

**Does this concentration imply the institute got it wrong?** Per [RES-021]'s contextualization step: no — it implies the institute's design space is denser. The institute is **structurally committed** to:

1. **One namespace per semantic domain** ([MOD-DOMAIN]).
2. **Cross-domain capability protocols** (Parser/Serializer/Coder/Formatter) each in their own packages per `transformation-domain-architecture.md` v3.4.0.
3. **Phantom-typed positions** via `Tagged<DomainTag, Ordinal>` (Text.Position, Index<Byte>, Binary.Position).
4. **Sibling-form value-type primitives** with [API-NAME-001c] capability-marker protocols (UInt8 vs Byte; Cardinal vs UInt; Ordinal vs UInt).

Given these commitments, the question is not "does Binary deserve a namespace?" (the answer is structurally yes by [MOD-DOMAIN]), but "what is the semantic content of the Binary domain that distinguishes it from Byte and Bit?"

## Theoretical Grounding / Formal Semantics [per [RES-024]]

This section gives a precise, type-theoretic answer to Q2 ("what IS Binary?") and Q6 ("Bit / Byte / Binary as domain layers"). The formal vocabulary below makes the answer mechanical rather than aesthetic.

### Three categorical layers

The institute's byte-ecosystem is a three-layer stratification:

```
Layer 3: Binary    — REPRESENTATION DOMAIN
                     (encoding rules over byte sequences)
                ↑
                ↑ uses ↑
                ↑
Layer 2: Byte      — VALUE-TYPE DOMAIN
                     (the atomic byte as a value)
                ↑
                ↑ contains 8 of ↑
                ↑
Layer 1: Bit       — ATOMIC INFORMATION DOMAIN
                     (the 0/1 atom)
```

#### Layer 1 — Bit: atomic information

Formally, `Bit` is the two-element set `{0, 1}` with structure:

- *Boolean algebra* (`Bit Boolean Primitives` target): AND, OR, NOT, XOR. Cardinality |Bit| = 2.
- *Field* (`Bit Field Primitives` target): the finite field GF(2) — bitwise XOR as addition, bitwise AND as multiplication.
- Conformers: a single value with two inhabitants; representable as 1 bit in any storage.

`Bit` answers: *"what is a single information atom?"*

#### Layer 2 — Byte: atomic value-type

Formally, `Byte ≅ Bit^8` — the 8-fold product of bits, considered as a structured value type. Cardinality |Byte| = 2^8 = 256.

But `Byte` is NOT merely `Bit^8` in the categorical sense — it carries additional structure absent at Bit-level:

- *Equality, ordering, hashing* (lifted from underlying UInt8 storage).
- *Bitwise operations* (`& | ^ ~ << >>`) — lifted but operating on the byte as a unit.
- *No arithmetic* per `byte-arithmetic-conformance.md` v1.0.0 — `+`, `-`, `*`, `/` are absent by design.
- *No collection structure* — `Byte` is one value, not a sequence of 8 bits.

The Byte domain provides the *capability marker* `Byte.Protocol` per `byte-protocol-capability-marker.md` v1.1.0, with `var byte: Byte { get }` projection and `init(_ byte: Byte)` injection. Conformers express "I am a byte-domain value" via the marker.

`Byte` answers: *"what is one byte as a value-type?"*

**Critical**: `Byte ≢ UInt8`. UInt8 is the arithmetic carrier (`+`, `-`, `*`, `/`, `Numeric`, `BinaryInteger`, `FixedWidthInteger`); Byte is the byte-domain twin (no arithmetic). They are siblings, not refinement-related. Per [API-BYTE-001..002].

#### Layer 3 — Binary: representation domain

Formally, `Binary` is the *category* of byte-sequence-based representation rules. It is NOT a set; it is NOT a collection. It is the *structure of how values become byte sequences*.

Its objects are encoded representations: a `UInt32` in big-endian form (4 bytes), an LEB128-encoded signed integer (variable bytes), an IPv4 address (4 octets), an RFC 4648 Base64-encoded payload, etc. Its morphisms are the encoding/decoding maps:

- `serialize: Value → Sequence<Byte>` — the encoding morphism.
- `parse: Sequence<Byte> → Value ∪ Failure` — the (partial) decoding morphism, dual to serialize.
- `code: Value ↔ Sequence<Byte>` — the bidirectional pair (Coder.Protocol per `transformation-domain-architecture.md` v3.4.0).
- `format: Value → String` — the lossy human-readable morphism (Formatter.Protocol).

The Binary domain contains the **representational structure** that makes these morphisms expressible:

| Concept | Type-theoretic content |
|---|---|
| `Binary.Endianness` | Two-element choice (big/little) that parameterizes integer ↔ byte-sequence maps. |
| `Binary.Position` | A `Tagged<Byte, Ordinal>`-shaped typed-offset into a byte sequence (parallels `Text.Position ≡ Tagged<Text, Ordinal>` per `byte-cursor-primitive-unification.md` v1.3.0 §1.3). |
| `Binary.Pattern` | A bit-mask pattern over byte sequences (predicate over byte windows). |
| `Binary.Mask` | A bit-mask over an integer width — selects specific bit positions for read/write. |
| `Binary.Cursor` | A read/write head over a byte buffer — owns position, supports advance/peek/seek. |
| `Binary.Bytes` | A sub-namespace inside Binary that scopes byte-sequence consumption (Binary.Bytes.Input, Binary.Bytes.Machine in the parser package). |
| `Binary.Serializable` | The capability "this value can be serialized to a byte sequence" — a protocol that maps types to encoding morphisms. |
| `Binary.Parseable` | The capability "this value can be parsed from a byte sequence" — the dual protocol. |
| `Binary.Coder` | The capability "this value has a bidirectional encoding" — the parser+serializer pair (per `transformation-domain-architecture.md`). |
| `Binary.Format` | Format-style values for human-readable byte rendering (byte count, hex, etc.). |
| `Binary.Base.N` | A closed family of base-N encodings (Base16, Base32, Base64 — RFC 4648) — variants of the encoding morphism for ASCII-text output. |
| `Binary.LEB128` | A specific variable-length integer encoding scheme. |

`Binary` answers: *"how does data become byte sequences (and back), according to which rules?"*

### Distinctions in formal terms

The three layers carry **categorically distinct content**:

| Layer | Mathematical type | What it is | Closure operations |
|---|---|---|---|
| Bit | Set {0, 1} ≡ GF(2) | A two-element atom | Boolean / field operations |
| Byte | (Bit)^8 with extra structure | A typed value (one inhabitant) | Equality, hashing, ordering, bitwise; NO arithmetic |
| Binary | Category of encoding morphisms | A representation domain | Parser/Serializer/Coder/Formatter capabilities + encoding-specific structure (Endianness, Position, Pattern, Mask, Cursor) |

The **type-theoretic answer to Q2 is**: Binary is NOT a set, NOT a collection, NOT a typealias. It is a *category* — the category of byte-sequence-based encoding rules. Its objects are representations; its morphisms are encode/decode maps; its additional structure (Endianness, Position, Pattern, Mask, Cursor) parameterizes the morphisms.

### Why Binary ≠ Collection<Byte>

A typealias `Binary = Collection<Byte>` would force the following identifications:

| Concept | Under typealias | Under namespace (current) | Cost of typealias |
|---|---|---|---|
| `Binary.Endianness` | Must be a property of `Collection<Byte>` | Property of the encoding morphism | Endianness is meaningless for a raw byte collection (what would `[0x01, 0x02].endianness` mean?). It's a parameter of integer ↔ bytes encoding, not a property of the bytes themselves. |
| `Binary.Position` | Must be `Collection<Byte>.Index` | Typed `Tagged<Byte, Ordinal>` | Loses the typed-offset discipline. `Collection<Byte>.Index` is `Int` for `[Byte]` but opaque `String.Index`-shaped for sliced types; the typealias forces consumers to track which substrate is in use. |
| `Binary.Pattern` | Predicate over `Collection<Byte>` | A bit-mask pattern with optional bit-level structure | Loses the bit-aware framing. `Binary.Pattern` is about bit-windows over byte sequences, not arbitrary predicates. |
| `Binary.Cursor` | Position into `Collection<Byte>` | Read/write head with advance/peek/seek + lifetime-bound borrowing | Loses the `~Escapable` lifetime contract and the cursor's owned-vs-borrowed reader/writer discrimination per `swift-binary-primitives/Research/Lifetime Dependent Borrowed Cursors.md`. |
| `Binary.Serializable` | Conformance on `Collection<Byte>` | Capability on arbitrary types that *produce* byte sequences | The protocol's whole point is `T → [Byte]`, NOT `[Byte] → [Byte]`. A `UInt32`, an `RFC_791.IPv4.Address`, a JWT — these are NOT collections of bytes; they ARE values that the protocol maps to byte sequences. Under the typealias, the protocol would only conform to byte-collection types, which is empty content. |
| `Binary.Coder` | A function over `Collection<Byte>` | A bidirectional encoding morphism | Loses the symmetric encode+decode pair structure. |
| `Binary.Base.16/32/64` | An algorithm over `Collection<Byte>` | A family of encodings to ASCII text | The base-N family produces ASCII text from bytes — it's NOT byte-collection-shaped output, it's String-shaped output. |
| `Binary.LEB128` | An algorithm over `Collection<Byte>` | A variable-length encoding for FixedWidthInteger | LEB128 is parametric over integer width, not over byte collection. |

The typealias is **categorically wrong**: it conflates the *substrate* (Collection<Byte> — the input/output type) with the *domain* (Binary — the rules for mapping values to/from the substrate). This is the standard category-theory distinction between an object's underlying set and the structure imposed on it. Binary is the structure; `[Byte]` is the underlying set.

The Haskell prior art makes this explicit [Verified: 2026-05-20, [hackage/binary](https://hackage.haskell.org/package/binary)]:

> "Values encoded using the Binary class are always encoded in network order (big endian) form, and encoded data should be portable across machine endianness, word size, or compiler version."

`Binary` here is the capability class, not the byte sequence. ByteString is the byte sequence. The Haskell community deliberately keeps these separate, and even ByteString does NOT collapse to `[Word8]` (the `Builder.Prim` typed-encoder catalog lives in `Data.ByteString.Builder.Prim` precisely because raw byte lists are insufficient).

### Three-layer composition

Per the layered model:

- `Binary` *uses* `Byte` (its operations consume and produce byte sequences).
- `Byte` *contains* 8 `Bit`s (its underlying structure).
- But: `Binary` does NOT subsume `Byte`, and `Byte` does NOT subsume `Bit`. Each layer is a distinct semantic domain.

This composition relation is the same as:
- `Text` (representation domain) *uses* `Char` (value-type) *contains* code-units. Text is NOT a collection of Chars.
- `Geometry` (representation domain) *uses* `Point` (value-type) *contains* coordinates. Geometry is NOT a collection of Points.
- `Time` (representation domain) *uses* `Instant` (value-type) *contains* picosecond ticks. Time is NOT a collection of Instants.

The pattern is consistent across the institute's L1 ecosystem.

## Analysis — First-Principles Decomposition

### What about `binary-parser-primitives` ≠ `byte-parser-primitives`?

The two packages live at different categorical layers:

| Package | Owns | What it parses | Substrate |
|---|---|---|---|
| `swift-byte-parser-primitives` | `Byte.Parser<Input>` where `Input.Element == Byte`; `Byte.Literal.Parser`; `Byte.Input` typealias; `Parser.Builder+Literal`; `Parseable+Byte.Input` | Single-byte literals; byte-sequence patterns; cross-domain (ASCII parsing, UTF-8 parsing, network framing, lexer scaffolding) | `Input.Element == Byte` — substrate-shape neutral on the encoding semantics |
| `swift-binary-parser-primitives` | `Binary.Bytes.Parser` (full state machine — Input + InputView + Machine + Borrowed + Parse); `Binary.LEB128.Parser`; `Binary.Integer.Parser` (UInt8/16/32/64 + Int8/16/32/64 with endianness) | Binary-encoding-specific: typed integer reads with explicit endianness, variable-length LEB128, structured byte-stream protocols | `Binary.Bytes.Input` cursor with `position: Int`, lifetime-dependent borrowing, machine-IR-backed parser; richer substrate carrying binary-encoding semantics |

The dependency at Package.swift level [Verified: 2026-05-20]: `swift-binary-parser-primitives` depends on `swift-byte-primitives` AND `swift-byte-parser-primitives`. So the answer to Q5 ("could binary-parser be built on byte-parser?") is **yes, and it already is**. The relationship is layered, not redundant.

What's in `binary-parser-primitives` that ISN'T in `byte-parser-primitives`:

1. **Endianness-aware integer parsers** — `Binary.Integer.UInt32.Parser(endianness: .big)`. Cannot live in `byte-parser-primitives` because endianness is a Binary-domain concept (per the formal semantics above), not a byte-domain concept.

2. **LEB128 variable-length integer parsers** — variable-byte encoding requires knowledge of the LEB128 spec (`swift-binary-leb128-primitives`). Cross-domain (DWARF, WASM, Protobuf).

3. **Binary.Bytes.Machine** — the parser state machine over byte sequences with binary-encoding error semantics (`Binary.Bytes.Machine.Fault`).

4. **Binary.Bytes.Input.View** with `~Escapable` lifetime-bound Span<UInt8>-cursor — the borrowed-cursor pattern documented in `Lifetime Dependent Borrowed Cursors.md`.

5. **Binary.Coder integration** — Binary.Coder's decode field has signature `(inout Binary.Bytes.Input) throws(Binary.Bytes.Machine.Fault) -> Output`, parameterized over Binary domain types. Per `binary-primitives-package-decomposition.md`, Coder cannot extract independently of the parser substrate.

The Haskell prior art is explicit on this boundary: **attoparsec parses bytes structurally (`word8`, `satisfy`, `takeWhile`); `Data.Binary.Get` parses bytes with binary-encoding semantics (`getWord32le`, `getInt64be`).** Two libraries, two abstractions, same byte substrate — split along the **endianness-in-scope axis**.

This is the institute's correct boundary as well:

- `byte-parser-primitives` = byte-shape-aware parser layer (consume bytes, match literals, structural framing).
- `binary-parser-primitives` = binary-encoding-aware parser layer (typed integers, endianness, LEB128, machine IR, lifetime-bound cursors).

The dependency arrow `binary-parser-primitives → byte-parser-primitives` is the categorically correct layering.

### What about `binary-serializer-primitives` (proposed) ≠ `byte-serializer-primitives` (existing)?

`swift-byte-serializer-primitives` exists today [Verified: 2026-05-20]; it owns `Byte.Serializer<Buffer>` (single-byte emission) + `Byte.Literal.Serializer`.

`swift-binary-serializer-primitives` does NOT exist as a separate package today; the `Binary.Serializable` protocol lives inside `swift-binary-primitives` as the sub-product `Binary Serializable Primitives`. Per `binary-primitives-package-decomposition.md` v1.0.0 RECOMMENDATION, it should split out — but as a *witness-shape refactor* (Pattern 2 from `canonical-witness-capability-attachment.md`), not as a mere relocation.

If `swift-binary-serializer-primitives` is created per that RECOMMENDATION, it would own:

- `Binary.Serializer<T>` plain witness struct (closures conforming to `Serializer.Protocol`).
- Endianness-aware default impls for `FixedWidthInteger`-RawValue types.
- The `Binary.Serializable` associated-type protocol with `static var serializer: Binary.Serializer<Self>`.

This is symmetric to `Binary.Parser` machinery in `swift-binary-parser-primitives` — both carry binary-encoding-specific semantics that the bare byte-serializer/parser don't.

The Q4 answer: `binary-serializer-primitives` is justified because **binary-encoding serialization is a different domain from byte-stream emission** — endianness, LEB128, fixed-width encoding rules live there. `byte-serializer-primitives` is the substrate (emit bytes); `binary-serializer-primitives` is the encoding layer (emit bytes per binary-encoding rules).

### What does `Binary.Bytes.Parser` ≠ `Byte.Parser` actually express?

Per the byte-cursor-primitive-unification.md v1.3.0 IN_PROGRESS RECOMMENDATION (now downgraded pending the Tier 3 cursor-abstractions arc), both implementations share substantial mechanically-symmetric scaffolding (~100 LOC), but live at different layers:

- `Byte.Parser` (in byte-parser-primitives): single-byte literal matcher; `Input.Element == Byte`; minimal, byte-domain only; conforms to `Parser.Protocol` AND `Parser.Printer`.
- `Binary.Bytes.Parser` (in binary-parser-primitives): the binary-domain byte-input parser machinery; carries `Binary.Bytes.Input.View` (lifetime-bound Span-cursor), `Binary.Bytes.Machine` (state machine with `Binary.Bytes.Machine.Fault` errors), and the byte-level entry surface for the binary-encoding parser hierarchy.

These should NOT collapse into one package today. The byte-cursor-unification arc may eventually unify the *cursor primitive itself* (`Cursor<DomainTag>` parameterized over Byte vs Text vs Binary domain tags), but that is a substrate-level unification, not a domain-level merge. The domain-level distinction remains: byte-parsing ≠ binary-parsing.

## Options

Five viable architectural options, classified by their structural commitment:

### Option A — Status quo (Binary, Byte, Bit as three peer L1 domains)

Keep all nine packages. Binary is the encoding-rule namespace; Byte is the value-type domain; Bit is the atomic-information domain. Parser/Serializer/Coder/Formatter exist as separate capability packages per `transformation-domain-architecture.md` v3.4.0, with both byte-* and binary-* variants where the substrate distinction matters.

**Pros**:
- Matches the formal three-layer semantics (Bit → Byte → Binary).
- Matches Haskell's distributed pattern (bytestring + binary + attoparsec + cereal) within institute namespace discipline.
- Matches the dependency layering already in place (`binary-parser-primitives → byte-parser-primitives`).
- W2 cascade already established `Binary.Serializable.Buffer.Element == Byte` — the byte-domain identity has propagated into Binary's protocol surface without collapsing the namespaces.
- Honors [MOD-DOMAIN] — each package's domain is coherent.

**Cons**:
- More packages than alternatives (nine vs five for option B).
- Requires consumers to understand the Bit / Byte / Binary distinction (mitigated by clear docs).

### Option B — Collapse Binary to typealias for `Collection<Byte>`

Reject the Binary namespace; replace with `public typealias Binary = Collection<Byte>` (or similar). Move endianness, position, pattern, mask, cursor, serializable, parseable, coder to byte-* packages.

**Pros**:
- Fewer packages.
- Surface simplification at first glance.

**Cons (structural — Tier 1 axis per [RES-029])**:
- **Categorically wrong** — see § "Why Binary ≠ Collection<Byte>" above. Conflates substrate (byte collection) with domain (encoding rules).
- **No surveyed prior art supports this** — see § "Contextualization step." Rust, Haskell, Go, OCaml all distinguish byte-collection manipulation from binary-encoding rules; none collapses them.
- **Loses categorical content** — Binary.Endianness, Binary.Position (`Tagged<Byte, Ordinal>`), Binary.Pattern, Binary.Mask, Binary.Cursor are NOT properties of a byte collection; they are structure parameterizing the encoding morphisms.
- **Breaks the Binary.Serializable protocol** — the protocol maps `T → [Byte]` where T is an arbitrary type (UInt32, JWT, IPv4.Address). Conformance is on T, not on `[Byte]`. Under typealias, `Binary.Serializable` would only conform to byte-collection types — empty content.
- **Breaks Binary.Coder** — Coder is a symmetric `T ↔ [Byte]` pair morphism, not a function over byte collections.
- **Breaks Binary.Base.16/32/64 family** — base-N output is ASCII text, not a byte collection; the family already exists at `swift-binary-base-primitives` per the precedent.
- **Reverses the W2 cascade direction** — W2 propagated byte-domain identity INTO Binary's protocol surface (`Buffer.Element == Byte`). Option B would propagate Binary INTO byte's surface, dissolving the encoding-rule layer.
- **Forces all of `swift-binary-primitives/Sources/Binary Primitives Core/` to relocate**: the 35 files including FixedWidthInteger+Binary, Int*.swift, UInt*.swift, Binary.Endianness, Binary.Position, Binary.Pattern, Binary.Mask, Binary.Space — these contain binary-encoding mechanics that don't fit in `swift-byte-primitives` (which is intentionally arithmetic-and-parser-free per the byte-arc).

**Verdict**: REJECTED. Categorically wrong; no prior art; loses load-bearing structure; reverses an in-flight cascade.

### Option C — Keep Binary as namespace; collapse `binary-parser-primitives` + `binary-serializer-primitives` into byte-* packages

Keep Binary.Endianness, Binary.Position, etc. in `swift-binary-primitives`, but move all parsing/serializing into byte-parser-primitives and byte-serializer-primitives. The Binary domain becomes "namespace + non-parser/serializer mechanics."

**Pros**:
- One fewer parser package, one fewer serializer package.

**Cons**:
- **Structurally wrong** — endianness-aware integer parsers, LEB128 parsers, the Binary.Bytes.Machine state machine are NOT byte-shape parsers; they are binary-encoding parsers. Putting them in `byte-parser-primitives` would force the byte-parser package to carry binary-encoding semantics it explicitly doesn't have today.
- **Violates [MOD-DOMAIN]** — `swift-byte-parser-primitives` would suddenly contain two domains (byte parsing + binary parsing). The package's domain identity dissolves.
- **Contradicts the Haskell precedent** — attoparsec (byte parsing) and binary.Get (binary parsing) are deliberately separate libraries.
- **Breaks the layering** — currently `binary-parser → byte-parser`. Collapsing would require `byte-parser` to absorb binary-encoding machinery, inverting the layering.
- **Forces `Binary.Coder` relocation** — its decode signature consumes `Binary.Bytes.Input`. Either move the cursor type or break Coder.

**Verdict**: REJECTED. Same domain-conflation cost as B, just localized to the parser/serializer packages.

### Option D — Split `Binary.Serializable` out per `binary-primitives-package-decomposition.md`

Status quo PLUS: create `swift-binary-serializer-primitives` with `Binary.Serializer<T>` witness struct, deprecate the in-package `Binary.Serializable` protocol, migrate 9+ consumer packages over multiple cycles per the W2 cascade discipline.

**Pros**:
- Matches the existing RECOMMENDATION (binary-primitives-package-decomposition.md).
- Symmetric to the byte-* family (byte-primitives + byte-parser-primitives + byte-serializer-primitives ⇔ binary-primitives + binary-parser-primitives + binary-serializer-primitives).
- Aligns with `transformation-domain-architecture.md` v3.4.0's principle that each capability domain (Parser/Serializer/Coder/Formatter) gets its own package per layer.
- Cleanly separates the protocol contract (in serializer package) from the namespace + representation primitives (in core binary-primitives).

**Cons**:
- Non-trivial migration — 9+ external consumer packages need updating (per `binary-primitives-package-decomposition.md` § "Per-Candidate Summary").
- Requires staged execution (multi-phase, multi-authorization-cycle).
- The W2 cascade is mid-flight (PAUSED per `2026-05-19-w2-byte-cascade-structural-issue.md`); landing D would compose with that cascade.

**Verdict**: ACCEPTED CONDITIONALLY — this is the existing per-package RECOMMENDATION. This Tier 3 doc REAFFIRMS it (no override).

### Option E — Status quo + Tier 3 cursor-abstractions successor arc

Status quo PLUS: complete the Tier 3 successor arc that `byte-cursor-primitive-unification.md` v1.3.0 surfaces — unify `Binary.Bytes.Input.View`, `Lexer.Scanner`, `Binary.Cursor` into a `Cursor<DomainTag>` primitive parameterized over Byte/Text/Binary domain tags.

**Pros**:
- Resolves the cursor-substrate duplication WITHOUT collapsing the domain namespaces.
- The unification happens at the *substrate level* (Span-cursor mechanics), not the *domain level* (parser/serializer/coder boundaries remain).
- Composes cleanly with the Tagged-of-Ordinal/Cardinal/Vector pattern the ecosystem already invests in.

**Cons**:
- Tier 3 work is non-trivial; the successor arc has not yet executed.
- Requires the byte-cursor unification arc to disposition its IN_PROGRESS status.

**Verdict**: ACCEPTED — this is the existing in-flight successor arc; this doc REAFFIRMS it and INPUTS the formal three-layer model into its analysis.

## Recommendation

Per [RES-022] (Recommendation-Section Framing Heuristic — structural correctness first, cost as tiebreaker only): the structural answer dominates. Per [RES-029] (Framing-Challenge for Binding/Membership/Placement Questions — semantic identity first): Binary, Byte, Bit are semantically distinct domain layers.

### Q1 — Is using "Binary" justified as a namespace?

**YES.** Binary is the canonical name for the representation-domain category that owns encoding rules (endianness + position + pattern + mask + cursor + serializable + parseable + coder + format + base-N + LEB128). It is NOT collapsible into Byte (the value-type domain) without losing categorical content. The W2 cascade has *strengthened* the Binary namespace's coherence by propagating byte-domain identity into its protocol substrate while keeping the representation-domain types intact.

### Q2 — From first principles, what IS Binary?

Binary is a **representation domain** — formally, the *category of byte-sequence-based encoding rules*. Its objects are encoded representations (typed values mapped to byte sequences according to specific rules: endianness, fixed-width, variable-length, framing, base-N text encoding). Its morphisms are the encode/decode maps (Serializer/Parser/Coder). Its additional structure parameterizes the morphisms.

Binary is NOT: a set, a collection, a typealias.
Binary IS: a category with objects, morphisms, and parameterizing structure.

### Q3 — Should Binary be a typealias for Collection<Byte>?

**NO.** This collapse is categorically wrong:

- Conflates substrate with structure (the standard category-theory mistake of identifying an object with its underlying set).
- Loses the parameterizing structure (endianness, position-as-Tagged, pattern, mask).
- Breaks the Serializable/Parseable/Coder protocols (which map T ↔ [Byte] where T is arbitrary, not where T IS [Byte]).
- No surveyed prior art supports this collapse (Rust, Haskell, Go, OCaml all distinguish byte-collection manipulation from binary-encoding rules).
- Reverses the W2 cascade direction.

### Q4 — Why do we have binary-parser-primitives and (proposed) binary-serializer-primitives?

Because the **binary domain has encoding-specific parser/serializer content** distinct from byte-stream parsing/serializing:

- Endianness-aware integer parsers (`Binary.Integer.UInt32.Parser(endianness: .big)`).
- Variable-length integer parsers (LEB128, used by DWARF, WASM, Protobuf).
- Lifetime-bound borrowed cursors (`Binary.Bytes.Input.View`).
- Binary parser state machine (`Binary.Bytes.Machine`, with `Binary.Bytes.Machine.Fault` errors).
- Bidirectional Coder pairs (`Binary.Coder<Output>` consuming Binary.Bytes.Input).

These are NOT byte-stream concerns; they are binary-encoding concerns. The Haskell precedent (attoparsec ≠ binary.Get) is explicit on this boundary.

### Q5 — Could binary-parser be built on a theoretical byte-parser?

**Yes, and it already is.** `swift-binary-parser-primitives` Package.swift declares `.package(path: "../swift-byte-primitives")` and `.package(path: "../swift-byte-parser-primitives")` at lines 62-63 [Verified: 2026-05-20]. The dependency arrow `binary-parser → byte-parser` is in place and categorically correct.

### Q6 — Relationship between Bit, Byte, and Binary as domain layers

**Three semantic layers, each with distinct categorical content**:

| Layer | Layer is | Layer answers |
|---|---|---|
| Bit | Atomic information domain — GF(2) two-element field | "What is a single information atom?" |
| Byte | Value-type domain — Bit^8 with byte-domain identity (sibling to UInt8) | "What is one byte as a value?" |
| Binary | Representation domain — category of byte-sequence encoding morphisms | "How does data become byte sequences, per which rules?" |

Bit *composes into* Byte (8 bits per byte). Byte *is used by* Binary (binary encodings consume/produce byte sequences). The layers do NOT subsume one another; each is a distinct semantic domain with its own primitives, capability markers, and parser/serializer companions.

This pattern is consistent across the institute's L1 ecosystem (Text uses Char uses code-units; Geometry uses Point uses coordinates; Time uses Instant uses ticks).

### Q7 — Canonical organization across all nine packages

| Package | Layer | Owns | Depends on (within byte ecosystem) |
|---|---|---|---|
| `swift-bit-primitives` | Bit (Layer 1) | `Bit`, `Bit.Boolean`, `Bit.Field` | — |
| `swift-byte-primitives` | Byte (Layer 2) | `Byte` value-type + `Byte.Protocol` capability marker | — (deliberately byte-only) |
| `swift-byte-parser-primitives` | Byte (Layer 2) | `Byte.Parser`, `Byte.Literal.Parser`, `Byte.Input` | `swift-byte-primitives`, `swift-parser-primitives` |
| `swift-byte-serializer-primitives` | Byte (Layer 2) | `Byte.Serializer`, `Byte.Literal.Serializer` | `swift-byte-primitives`, `swift-serializer-primitives` |
| `swift-binary-primitives` | Binary (Layer 3) | Binary namespace + Endianness + Position + Pattern + Mask + Space + Cursor + Bytes (sub-namespace) + Format + Serializable + Parseable | `swift-byte-primitives`, `swift-bit-primitives`, format/cardinal/etc. |
| `swift-binary-parser-primitives` | Binary (Layer 3) | `Binary.Bytes.Parser`, `Binary.Bytes.Input(.View)`, `Binary.Bytes.Machine`, `Binary.Integer.Parser`, `Binary.LEB128.Parser` | `swift-binary-primitives`, `swift-byte-parser-primitives`, `swift-parser-primitives`, `swift-binary-leb128-primitives` |
| `swift-binary-coder-primitives` | Binary (Layer 3) | `Binary.Coder<Output>` (symmetric encode+decode) | `swift-binary-parser-primitives`, `swift-coder-primitives` |
| `swift-binary-base-primitives` | Binary (Layer 3) | `Binary.Base.16/32/64` (closed-radix family per RFC 4648) | `swift-binary-primitives` (Namespace only), `swift-property-primitives` |
| `swift-binary-leb128-primitives` | Binary (Layer 3) | `Binary.LEB128` (variable-length encoding mechanism) | `swift-binary-primitives` (Namespace only) |
| `swift-binary-serializer-primitives` (PROPOSED per D) | Binary (Layer 3) | `Binary.Serializer<T>` witness + `Binary.Serializable` associated-type protocol | `swift-binary-primitives` (Namespace + Core), `swift-byte-primitives`, `swift-serializer-primitives` |

### Synthesis verdict

| Option | Verdict | Reason |
|---|---|---|
| A — Status quo (Binary/Byte/Bit as three peer domains) | **ACCEPT** | Matches formal three-layer semantics; matches institute's [MOD-DOMAIN] discipline; honors existing dependency layering. |
| B — Collapse Binary to typealias `Collection<Byte>` | **REJECT** | Categorically wrong; no prior art; loses load-bearing structure; reverses W2 cascade. |
| C — Collapse binary-*-primitives parser/serializer into byte-* | **REJECT** | Violates [MOD-DOMAIN]; contradicts Haskell precedent; breaks the binary-parser → byte-parser layering. |
| D — Split Binary.Serializable to swift-binary-serializer-primitives | **REAFFIRM** existing RECOMMENDATION | This is the per-package decomposition decision already on the books; this Tier 3 doc does not override; the migration is staged and gated on authorization per the W2 program. |
| E — Tier 3 cursor-abstractions successor arc | **REAFFIRM** | The byte-cursor-unification arc is in-flight; this doc inputs the formal three-layer model and does NOT pre-determine that arc's outcome. |

**Composite recommendation**: keep all nine packages as the canonical organization (Option A); proceed with Option D's `swift-binary-serializer-primitives` split per its existing RECOMMENDATION; do not pre-empt the cursor-abstractions Tier 3 successor arc (Option E).

## What this closes

- **Q1/Q2/Q3 (Binary as namespace; Binary as category; Binary ≠ Collection<Byte>)**: closed by formal semantics + prior art.
- **Q4/Q5 (binary-parser-primitives' justification; binary-parser built on byte-parser)**: closed by the categorical layer model + the empirically-verified dependency layering.
- **Q6/Q7 (Bit/Byte/Binary as domain layers; canonical organization)**: closed by the three-layer formal model + the per-package table.

## What this does NOT recommend

- **No change to the existing nine packages' identities.** Binary, Byte, Bit remain three peer domains.
- **No collapse of any package into any other.** [MOD-DOMAIN] integrity preserved.
- **No pre-emption of the cursor-abstractions successor arc.** That arc remains the canonical answer on cursor unification.
- **No override of `binary-primitives-package-decomposition.md`'s RECOMMENDATIONS.** Split Binary.Serializable per that doc; HOLD Binary.Format; DO-NOT-EXTRACT Binary.Coder.

## What this opens (follow-on questions)

- **Skill promotion**: the three-layer Bit/Byte/Binary formal model is a candidate for promotion to a skill rule under `byte-discipline` or a new `binary-discipline` skill. The byte-discipline skill currently covers UInt8/Byte sibling-form; a sibling rule articulating the three-layer model would aid future authors. Deferred to skill-lifecycle workflow.
- **Documentation**: the formal three-layer model belongs in `swift-institute.org` DocC catalog as an architecture article. Deferred to documentation workflow.
- **Validation of Binary.Pattern, Binary.Mask, Binary.Space placements**: these were verified to exist at `swift-binary-primitives/Sources/Binary Primitives Core/` but their detailed semantics were not audited within this arc. If subsequent work surfaces concerns (e.g., that Binary.Mask is more naturally bit-level than binary-level), follow-on audit is in scope.

## References

### Internal — Load-bearing

- [`transformation-domain-architecture.md`](./transformation-domain-architecture.md) v3.4.0 (DECISION, 2026-05-13) — Parser/Serializer/Coder/Formatter as four independent top-level capability domains.
- [`byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md) v1.0.1 (DECISION, 2026-05-15) — byte-arc cementing [API-NAME-001b] subject-first ordering + Binary-stack audit GREEN.
- [`byte-protocol-capability-marker.md`](./byte-protocol-capability-marker.md) v1.1.0 (RECOMMENDATION, Tier 3, 2026-05-15) — UInt8/Byte sibling-form identity, [API-NAME-001c] capability-marker recipe.
- [`byte-arithmetic-conformance.md`](./byte-arithmetic-conformance.md) v1.0.0 (RECOMMENDATION, 2026-05-19) — Byte has no arithmetic.
- [`binary-primitives-package-decomposition.md`](./binary-primitives-package-decomposition.md) v1.0.0 (RECOMMENDATION, 2026-05-07) — per-sub-product split analysis (LEB128 SPLIT; Format HOLD; Serializable SPLIT; Coder DO-NOT-EXTRACT).
- [`byte-cursor-primitive-unification.md`](./byte-cursor-primitive-unification.md) v1.3.0 (IN_PROGRESS, 2026-05-17) — cursor-substrate analysis; downgraded pending Tier 3 successor arc.
- [`broader-l2-l3-byte-typing-gap-plan.md`](./broader-l2-l3-byte-typing-gap-plan.md) v1.0.0 (IN_PROGRESS, 2026-05-19) — W1–W6 byte-typing program; W2 retype to Byte protocol surface.
- [`binary-buffer-primitives-architectural-review.md`](./binary-buffer-primitives-architectural-review.md) v1.0.0 (DECISION, 2026-02-24) — precedent for removing `swift-binary-buffer-primitives` (86% non-binary content); informs the "Binary-named packages must contain binary content" discipline.
- [`canonical-witness-capability-attachment.md`](./canonical-witness-capability-attachment.md) (DECISION, 10/10 experiment variants CONFIRMED) — Pattern 2 domain-owned witnesses pattern that Option D's witness-shape refactor invokes.

### Skills + conventions

- byte-discipline `[API-BYTE-001..007]` — UInt8/Byte sibling-form; byte-vs-arithmetic-domain axis; SLI module-location.
- code-surface `[API-NAME-001]` Nest.Name; `[API-NAME-001b]` Subject-First; `[API-NAME-001c]` Per-Domain Capability-Marker.
- swift-institute `[ARCH-LAYER-001]` Five-layer downward-only.
- swift-institute-core `[BET-*]` namespaces-as-nouns; empty-enum shells.
- modularization `[MOD-DOMAIN]` one domain per package; `[MOD-RENT]` three-criteria rent test.
- primitives `[PRIM-FOUND-001]` no Foundation in L1.
- research-process `[RES-018]` premature-primitive anti-pattern; `[RES-019]` internal grep; `[RES-020]` tier classification; `[RES-021]` prior art + contextualization; `[RES-022]` recommendation framing heuristic; `[RES-023]` empirical-claim verification; `[RES-024]` formal semantics for Tier 3; `[RES-029]` framing-challenge for binding/membership questions.

### External — Verified Primary Sources

#### Rust

- [`bytes` crate (docs.rs)](https://docs.rs/bytes/latest/bytes/) — buffer storage + `Buf`/`BufMut` traits.
- [`bytes::Buf` trait (docs.rs)](https://docs.rs/bytes/1.10.1/bytes/buf/trait.Buf.html) — endian-suffixed numeric accessors (`get_u16`, `get_u16_le`, `get_u16_ne`).
- [`byteorder` crate (docs.rs)](https://docs.rs/byteorder/latest/byteorder/) — sealed `ByteOrder` trait.
- [`byteorder::ByteOrder` (docs.rs)](https://docs.rs/byteorder/latest/byteorder/trait.ByteOrder.html) — phantom typeclass.
- [`bitvec` crate (docs.rs)](https://docs.rs/bitvec/latest/bitvec/) — bit-addressed storage; separate from `bytes`.
- [`nom` crate (docs.rs)](https://docs.rs/nom/latest/nom/) — parser combinators with sibling `bytes`/`bits`/`number` modules.
- [`nom::number` (docs.rs)](https://docs.rs/nom/latest/nom/number/index.html) — endianness as function-name prefix (`be_u32`/`le_u32`).
- [`serde` crate (docs.rs)](https://docs.rs/serde/latest/serde/) — `ser`/`de` modules; no binary namespace.
- [`bincode` crate (docs.rs)](https://docs.rs/bincode/2.0.1/bincode/) — concrete binary format, peer crate.
- [`postcard` crate (docs.rs)](https://docs.rs/postcard/latest/postcard/) — "wire format" framing.
- [`leb128` crate (docs.rs)](https://docs.rs/leb128/latest/leb128/) — standalone variable-length encoding.
- [`deku` crate (docs.rs)](https://docs.rs/deku/latest/deku/) — bit+byte symmetric binary parser derive.

#### Haskell

- [`base/Data.Word.Word8` (hackage)](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Word.html) — 8-bit unsigned integer, NOT a byte-domain type.
- [`base/Data.Bits` (hackage)](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bits.html) — polymorphic bit typeclass.
- [`bytestring` package (hackage)](https://hackage.haskell.org/package/bytestring) — byte vector storage + builder.
- [`bytestring/Data.ByteString.Builder.Prim` (hackage)](https://hackage-content.haskell.org/package/bytestring-0.12.2.0/docs/Data-ByteString-Builder-Prim.html) — typed-encoder catalog with LE/BE primitives inside storage package.
- [`binary` package (hackage)](https://hackage.haskell.org/package/binary) — Binary typeclass + Put/Get monads.
- [`binary/Data.Binary.Get` (hackage)](https://hackage.haskell.org/package/binary/docs/Data-Binary-Get.html) — endianness-aware Get monad.
- [`cereal` package (hackage)](https://hackage.haskell.org/package/cereal) — alternative binary serialization over strict ByteString.
- [`attoparsec/Data.Attoparsec.ByteString` (hackage)](https://hackage.haskell.org/package/attoparsec/docs/Data-Attoparsec-ByteString.html) — byte-structural parser combinators (separate from binary.Get).

#### Go

- [`builtin` (pkg.go.dev)](https://pkg.go.dev/builtin) — `byte` as alias for `uint8`.
- [`bytes` (pkg.go.dev)](https://pkg.go.dev/bytes) — byte slice manipulation, analogous to strings.
- [`encoding/binary` (pkg.go.dev)](https://pkg.go.dev/encoding/binary) — `ByteOrder` interface, varint family.
- [`encoding` (pkg.go.dev)](https://pkg.go.dev/encoding) — `BinaryMarshaler` vs `TextMarshaler` at top-level.
- [`io` (pkg.go.dev)](https://pkg.go.dev/io) — byte-typed transport.

#### OCaml

- [`Bytes` module (ocaml.org)](https://ocaml.org/manual/5.2/api/Bytes.html) — mutable byte container.
- [`Buffer` module (ocaml.org)](https://ocaml.org/manual/5.2/api/Buffer.html) — auto-expanding buffers with "Binary encoding of integers" section.
- [`Cstruct` (mirage)](https://github.com/mirage/ocaml-cstruct) — typed views with `BE`/`LE` sub-modules.
- [`Angstrom` (inhabitedtype)](https://github.com/inhabitedtype/angstrom) — unified parser combinators.
- [`Iobuf` (Jane Street)](https://ocaml.org/p/core_kernel/latest/doc/Iobuf/index.html) — industrial buffer with Peek/Poke/Consume/Fill + endianness sub-modules.

### Foundational Citations (via Internal SLR)

Inherited from `phantom-typed-value-wrappers-literature-study.md` v1.0.0 (Tier 3 SLR, 36 papers, RECOMMENDATION, 2026-02-26) and `byte-protocol-capability-marker.md` v1.1.0 — verified per [RES-021]/[RES-026]:

- Reynolds, J. C. "Types, Abstraction and Parametric Polymorphism." *IFIP 1983*.
- Wadler, P. "Theorems for Free!" *FPCA 1989*.
- Hinze, R. "Fun with Phantom Types." *The Fun of Programming*, 2003.
- Cheney, J. & Hinze, R. "First-Class Phantom Types." Cornell CS TR 2003-1901.

## v2.0.0 Amendment — Option #8 (T + T.Borrowed via Ownership.Borrow.Protocol)

### Trigger

Principal observation 2026-05-20 post-v1.0.0: the institute's canonical
pattern for owned-storage types pairs an owned type `T` with a nested
`T.Borrowed` view, both governed by `Ownership.Borrow.Protocol`. The
v1.0.0 doc enumerated seven options for "if Binary were a type" but
missed this eighth — the canonical institute precedent already in
production at `String + String.Borrowed`, `Path + Path.Borrowed`, and
`Byte + Byte.Borrowed`. The omission is corrected here.

### Option #8 — T + T.Borrowed via `Ownership.Borrow.Protocol`

```swift
public struct Binary: ~Copyable {
    internal let _storage: Memory.Contiguous<UInt8>
    public var count: Index<Byte>.Count { /* … */ }
}

extension Binary {
    public struct Borrowed: ~Copyable, ~Escapable {
        public let span: Span<UInt8>
    }
}

extension Binary: Ownership.Borrow.`Protocol` {}
// Cursor<Binary> auto-derives storage as Binary.Borrowed.
```

Precedent for the shape:

| Type | Owned | Borrowed | Conforms to |
|---|---|---|---|
| `String` | `struct String: ~Copyable` over `Memory.Contiguous<Char>` | `struct Borrowed: ~Copyable, ~Escapable` over `UnsafePointer<Char> + count` | `Ownership.Borrow.Protocol` |
| `Path` | `struct Path: ~Copyable` over `Memory.Contiguous<Char>` | `struct Borrowed: ~Copyable, ~Escapable` over `UnsafePointer<Char> + count` | `Ownership.Borrow.Protocol` |
| `Byte` | `struct Byte` (value type) | `struct Borrowed: ~Copyable, ~Escapable` over `Span<UInt8>` | `Ownership.Borrow.Protocol` |

The pattern is governed by `Ownership.Borrow.Protocol` (in `swift-ownership-primitives`) with `associatedtype Borrowed: ~Copyable, ~Escapable`. `Cursor<DomainTag>` in `swift-cursor-primitives` derives storage via the protocol's associated type — `Cursor<Byte>` uses `Byte.Borrowed`, and `Cursor<Binary>` would use `Binary.Borrowed`. This is the canonical institute pattern for owned-buffer types.

### Empirical Finding — Why Option #8's Owned Struct Did NOT Land

The principal authorized 2026-05-20: *"ship Binary with typed counts, we'll sweep after."* Implementation proceeded with `struct Binary: ~Copyable` owning `Memory.Contiguous<UInt8>` and a nested `Binary.Borrowed: ~Copyable, ~Escapable`. Implementation [Verified: 2026-05-20]:

- `swift-binary-primitives/Sources/Binary Namespace/Binary.swift` rewritten to `struct Binary: ~Copyable` with `count: Index<Byte>.Count` storage.
- `Binary.Borrowed.swift` authored.
- `Binary+Ownership.Borrow.Protocol.swift` authored.
- `Package.swift` Binary Namespace target gained five deps (Memory_Primitives_Core, Byte_Primitives, Cardinal_Primitives, Index_Primitives, Ownership_Primitives).
- Package itself: **build clean, 364/364 tests pass**.

The build then failed in downstream `swift-binary-parser-primitives`:

```
error: 'Access' is not a member type of enum 'Binary_Namespace.Binary.Parse'
  swift-binary-parser-primitives/Sources/Binary Integer Primitives/Parser.Parser+parse.swift:22:36
    public var parse: Binary.Parse.Access<Self> { .init(self) }
                                   ^
```

Bisection [Verified: 2026-05-20] isolated the trigger:

| Binary type form | Downstream build |
|---|---|
| `enum Binary {}` (original) | clean |
| `@frozen public struct Binary: Sendable {}` (empty struct) | **fails** |
| `public struct Binary {}` (empty struct, no `Sendable`) | **fails** |
| `public struct Binary: ~Copyable { ... }` (full Option #8) | **fails** |
| `enum Binary {}` + nested `extension Binary { struct Borrowed: ~Copyable, ~Escapable { ... } }` + `extension Binary: Ownership.Borrow.Protocol {}` (Text-style with nominal Borrowed) | clean |

The failure reproduces under EVERY struct form, including the simplest empty-struct case. This isolates the trigger to: **Swift's `MemberImportVisibility` (SE-0444) treats extensions on struct types more strictly than extensions on empty-enum namespaces.** When `Binary` is an `enum`, extensions in transitive modules (`extension Binary { enum Parse {} }` in `Binary_Primitives_Core`, then `extension Binary.Parse { struct Access<...> {} }` in `Binary_Parse_Primitives`) resolve via implicit transitive imports. When `Binary` becomes a `struct`, the resolver requires explicit imports for the modules contributing each extension — which the existing call sites do not provide.

Adding the explicit import (`public import Binary_Parse_Primitives` in the failing file) was attempted and **did not resolve the error**. The compiler diagnostic continues to identify `Binary_Namespace.Binary.Parse` as the parent type but cannot find `Access` as a member. This points to a deeper resolution issue than a missing-import oversight — likely an interaction between `MemberImportVisibility` and cross-module extension chains anchored on a struct.

**Scope of the breakage if pushed through**: 25+ extension files in `swift-binary-primitives`, 10+ in `swift-binary-parser-primitives`, plus downstream extensions across the binary ecosystem (`swift-binary-coder-primitives`, `swift-binary-base-primitives`, `swift-binary-leb128-primitives`, every L2 spec consumer extending `Binary.*`). Rewriting all the import statements to satisfy `MemberImportVisibility` under the struct shape would touch hundreds of files. Some of those rewrites also fail (per the explicit-import test above) — the underlying compiler behavior would need a Swift PR to fully unblock.

### What Landed Instead — The Text Pattern with Nominal Borrowed

The implementation reverted to the Text-style shape, keeping `enum Binary {}` and adding the nested `Binary.Borrowed` struct with the conformance:

```swift
// Binary Namespace target / Binary.swift  (unchanged at the namespace level)
public enum Binary {}

// Binary Namespace target / Binary.Borrowed.swift  (NEW)
extension Binary {
    @safe
    public struct Borrowed: ~Copyable, ~Escapable {
        public let span: Swift.Span<UInt8>
        public var count: Index<Byte>.Count { /* … */ }

        @_lifetime(borrow span)
        public init(_ span: borrowing Swift.Span<UInt8>) {
            self.span = copy span
        }
    }
}

// Binary Namespace target / Binary+Ownership.Borrow.Protocol.swift  (NEW)
extension Binary: Ownership.Borrow.`Protocol` {}
// Swift infers Borrowed = Binary.Borrowed from the nested type.
```

[Verified: 2026-05-20]:

- `swift-binary-primitives` builds clean, **364 tests in 115 suites pass**.
- `swift-binary-parser-primitives` builds clean, **69 tests in 25 suites pass**.
- `Binary Namespace` target deps gained: Byte_Primitives, Cardinal_Primitives, Index_Primitives, Ownership_Primitives (four; Memory_Primitives_Core dropped since no owned storage in `Binary` itself).

### What This Shape Provides vs. Option #8

| Capability | Option #8 (owned struct) | Landed (Text pattern + nominal Borrowed) |
|---|---|---|
| Construct `Binary` from bytes | yes (`init(_ span:)`, `init(adopting:count:)`, etc.) | **no** — Binary remains uninhabited |
| `Binary.count: Index<Byte>.Count` on the owned type | yes | **no** — count lives on `Binary.Borrowed` instead |
| `Binary.Borrowed: ~Copyable, ~Escapable` nominal type | yes | **yes** |
| `Binary.Borrowed.count: Index<Byte>.Count` | yes | **yes** |
| Conformance to `Ownership.Borrow.Protocol` | yes | **yes** |
| `Cursor<Binary>` works | yes | **yes** (via the conformance) |
| Sibling-package compat ([MOD-017]) | broken | **preserved** (compile-clean ecosystem-wide) |
| Matches existing institute precedent | matches String/Path/Byte | matches Text |
| Implementation cost | very high (hundreds of imports) | very low (~80 LOC added) |
| Reversibility | high (pre-release) | high (additive) |

The Text pattern is **not** quite what the principal asked for ("Binary as a type with owned storage"). It's the **closest evergreen approximation** available under Swift's current `MemberImportVisibility` behavior, and it composes cleanly with the cursor-abstractions Tier 3 arc that's already implemented.

### Updated Recommendation Verdicts

| Option | v1.0.0 Verdict | v2.0.0 Verdict |
|---|---|---|
| A — Status quo (Binary/Byte/Bit as three peer domains) | ACCEPT | **ACCEPT (still)** |
| B — Collapse Binary to typealias `Collection<Byte>` | REJECT | **REJECT (unchanged)** |
| C — Collapse binary-*-primitives parser/serializer into byte-* | REJECT | **REJECT (unchanged)** |
| D — Split Binary.Serializable to swift-binary-serializer-primitives | REAFFIRM | **REAFFIRM (unchanged)** |
| E — Tier 3 cursor-abstractions successor arc | REAFFIRM | **CLOSED** — implemented v1.3.0 2026-05-18 at `cursor-shape-a-vs-three-worlds.md` |
| F — `~Copyable & ~Escapable` borrowed cursor type (most evergreen per first analysis) | RECOMMEND | **RECOMMEND (refined)** — superseded by the more specific Option #8 below |
| **#8 — T + T.Borrowed via Ownership.Borrow.Protocol (full owned-struct)** | not enumerated | **BLOCKED by Swift compiler behavior** (MemberImportVisibility on structs) |
| **#8b — Text-style enum + nested Binary.Borrowed + conformance** | not enumerated | **LANDED** as the closest evergreen approximation of #8 |

### Implications for Future Decisions

1. **The owned-`struct Binary` shape remains the structurally-ideal endpoint** — if Swift's compiler eventually resolves the `MemberImportVisibility`-on-struct-extensions interaction (whether via SE proposal, compiler bug fix, or migration tooling), revisit and promote.

2. **`Cursor<Binary>` now works as the canonical position-tracked borrowed binary-domain cursor** — symmetric to `Cursor<Byte>` and `Cursor<Text>`, all three Case-B conformers of `Ownership.Borrow.Protocol`.

3. **`Binary.Borrowed` is nominal (not a typealias to `Byte.Borrowed`)** — to allow binary-domain-specific accessors (typed integer reads, endianness affordances, encoding-aware peek/advance) to attach on the borrowed view in subsequent arcs. The trade-off is one-time duplication of the byte-span-wrapper shape; the gain is independent extensibility of the binary-domain borrowed surface. Cursor<Binary>'s operation extensions will need `where DomainTag.Borrowed == Binary.Borrowed` clauses (parallel to the existing `where DomainTag.Borrowed == Byte.Borrowed` extensions for Cursor<Byte> and Cursor<Text>).

4. **The typed-count discipline (Index<Byte>.Count) is established by Binary.Borrowed** — the user-authorized "sweep after" remains scheduled for `String.count`, `Path.count`, `Byte.Borrowed.count` to migrate from `Int` to `Index<…>.Count`.

5. **The Binary Namespace target's dep-free anchor status is partially relaxed** — four foundational L1 deps added (Byte, Cardinal, Index, Ownership). Sibling packages (binary-base-primitives, binary-leb128-primitives) transitively inherit them, which is acceptable per [MOD-017] amendment.

## v3.0.0 Amendment — v2.0.0 Misdiagnosis Retracted; Option #8 Ships

### Trigger

Principal observation 2026-05-20 post-v2.0.0: *"Could it be that the
downstream issues were just build issues (that remove .build / clean build)
would solve?"* The v2.0.0 doc claimed the owned-struct shape (Option #8)
was blocked by Swift's `MemberImportVisibility` (SE-0444) treatment of
struct extensions. Empirical verification with hard `.build` clean
([Verified: 2026-05-20]):

```bash
rm -rf swift-binary-primitives/.build
rm -rf swift-binary-parser-primitives/.build
cd swift-binary-primitives && swift build && swift test  # 364/115 pass
cd swift-binary-parser-primitives && swift build && swift test  # 69/25 pass
```

**Both packages build clean with `struct Binary: ~Copyable` after a fresh
build from scratch.** The "Swift compiler limitation" was entirely stale
SwiftPM incremental-build cache from before the enum→struct interface
change. The bisection in v2.0.0 was running against the same stale cache
across every variant, so the failure reproduced uniformly — which I
misread as confirming the compiler-limitation hypothesis. A hard
`.build` clean would have invalidated the hypothesis in 30 seconds.

### What landed (v3.0.0)

The actual Option #8 — the canonical institute T+T.Borrowed pattern:

**`Binary` is a `~Copyable` owned-storage struct** in
`swift-binary-primitives/Sources/Binary Namespace/`, owning
`Memory.Contiguous<Byte>` (byte-domain typed, NOT `Memory.Contiguous<UInt8>`).
The `count: Index<Byte>.Count` accessor establishes the new precedent for
typed counts on T+T.Borrowed types; String / Path / Byte.Borrowed
remain at `Int` count until a separate sweep.

**`Binary.Borrowed` is a `~Copyable & ~Escapable` nominal nested struct** —
not a typealias to `Byte.Borrowed`. The `span: Swift.Span<Byte>` field
uses byte-domain typing per the W2 cascade discipline (NOT `Span<UInt8>`).
The nominal-struct (vs typealias) choice is for independent extensibility
of the binary-domain borrowed surface — future binary-encoding-specific
accessors attach to `Binary.Borrowed` without polluting `Byte.Borrowed`.

**Stdlib-interop initializers** are provided as `@_disfavoredOverload`
convenience init from `Span<UInt8>` — bridging at the boundary, byte-domain
typing internally.

**Ownership.Borrow.Protocol conformance** in
`Binary+Ownership.Borrow.Protocol.swift` enables `Cursor<Binary>`
automatically.

### Updated Recommendation Verdicts

| Option | v1.0.0 Verdict | v2.0.0 Verdict | v3.0.0 Verdict |
|---|---|---|---|
| A — Status quo (Binary/Byte/Bit as three peer domains) | ACCEPT | ACCEPT (still) | **PARTIALLY SUPERSEDED** — Binary promoted from namespace to owned-struct per Option #8 |
| B — Collapse Binary to typealias `Collection<Byte>` | REJECT | REJECT (unchanged) | REJECT (unchanged) |
| C — Collapse binary-*-primitives parser/serializer into byte-* | REJECT | REJECT (unchanged) | REJECT (unchanged) |
| D — Split Binary.Serializable to swift-binary-serializer-primitives | REAFFIRM | REAFFIRM | REAFFIRM (unchanged) |
| E — Tier 3 cursor-abstractions successor arc | REAFFIRM | CLOSED | CLOSED (cursor-shape-a-vs-three-worlds.md v1.5.0 amendment adds Binary as third Case-B conformer) |
| F — `~Copyable & ~Escapable` borrowed cursor type | RECOMMEND | RECOMMEND (refined) | SUPERSEDED by Option #8 |
| **#8 — T + T.Borrowed via Ownership.Borrow.Protocol (full owned-struct)** | not enumerated | **claimed BLOCKED (misdiagnosis)** | **LANDED — the canonical evergreen choice** |
| #8b — Text-style enum + nested Binary.Borrowed | not enumerated | claimed LANDED (workaround) | RETIRED — was a misdiagnosis-driven workaround; the real Option #8 ships |

### v2.0.0 Retraction

The v2.0.0 doc's §"Empirical Finding — Why Option #8's Owned Struct Did NOT Land" section is RETRACTED. The bisection table claiming every struct form fails downstream was running against stale build cache; under a clean build from scratch, every variant of `struct Binary` works. The cited claim that "Swift's `MemberImportVisibility` treats extensions on struct types more strictly than extensions on empty-enum namespaces" is FALSE — no such asymmetry exists; the resolution issue was 100% cache.

Discipline lesson saved to memory as `feedback_clean_build_before_compiler_limitation_claim` — when downstream errors persist after struct/enum interface change, ALWAYS `rm -rf .build` clean before concluding it's a Swift compiler limitation. Skill-promotion candidate for `swift-package-build`.

### What v3.0.0 ships

| File | Status | Purpose |
|---|---|---|
| `swift-binary-primitives/Sources/Binary Namespace/Binary.swift` | MODIFIED | `enum Binary {}` → `@safe public struct Binary: ~Copyable, @unsafe @unchecked Sendable` over `Memory.Contiguous<Byte>` with `count: Index<Byte>.Count`, byte-typed + UInt8-bridging initializers |
| `swift-binary-primitives/Sources/Binary Namespace/Binary.Borrowed.swift` | NEW | Nominal `extension Binary { public struct Borrowed: ~Copyable, ~Escapable }` over `Swift.Span<Byte>` (not `<UInt8>`) with `count: Index<Byte>.Count` |
| `swift-binary-primitives/Sources/Binary Namespace/Binary+Ownership.Borrow.Protocol.swift` | NEW | `extension Binary: Ownership.Borrow.Protocol {}` — Swift auto-infers `Borrowed = Binary.Borrowed` |
| `swift-binary-primitives/Package.swift` | MODIFIED | `Binary Namespace` target gains five deps: Byte_Primitives, Cardinal_Primitives, Index_Primitives, Memory_Primitives_Core, Ownership_Primitives |

[Verified: 2026-05-20] swift-binary-primitives 364 tests / 115 suites pass; swift-binary-parser-primitives 69 tests / 25 suites pass.

### Companion follow-up

`cursor-shape-a-vs-three-worlds.md` v1.5.0 — adds Binary as the third Case-B conformer of `Ownership.Borrow.Protocol`, makes `Cursor<Binary>` a valid generic instantiation. `Cursor<Binary>` operation extensions (peek/advance/consume etc., constrained on `where DomainTag.Borrowed == Binary.Borrowed`) authored in this same arc.

`Binary.Bytes.Input.View` (currently in `swift-binary-parser-primitives`) is now a candidate for deprecation — `Cursor<Binary>` is the structurally-equivalent replacement under the unified cursor architecture. Migration plan deferred to a follow-up arc.

## v3.2.0 Amendment — Owned-Storage Dissolved; Binary Reverts to a Dependency-Free Namespace (Truly-Primitive Review)

Supervisor direction 2026-06-22, as part of the bit/byte/binary "truly
primitive" cleanup: **the owned-storage promotion (Option #8, shipped v3.0.0
and refined v3.1.0) is SUPERSEDED. `Binary` reverts to a dependency-free
namespace** — the v1.0.0 Option A shape — carrying only endianness policy and
the fixed-width-integer ↔ byte codec.

### Why Option #8 is retired

Option #8 promoted `Binary` from a namespace to an owned `~Copyable` struct
over `Memory.Contiguous<Byte>`, on the premise that the binary-domain wanted a
String/Path/Byte-style owned-buffer type. The truly-primitive review rejects
that premise: it conflates two orthogonal concerns this very document already
separated —

- **`Binary` is a representation *domain*** (Q2/Q6: endianness, encoding rules,
  the `Binary.*` namespace), not a storage container. Its identity is the
  *interpretation* of bytes, not their ownership.
- **Owned byte storage is a *Storage*-layer concern.** The canonical owned byte
  buffer is `Storage.Contiguous<Byte>` (i.e.
  `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Byte>`,
  swift-storage-primitives) per the `[MOD-PLACE]` layer-placement calculus
  (Memory ⊏ Storage ⊏ Buffer ⊏ ADT). Binding owned storage onto the `Binary`
  *namespace* placed a Storage secret at the wrong layer and forced five
  foundational deps (Byte, Cardinal, Index, Memory, Ownership) onto a namespace
  that should be a dependency-free anchor.

Empirically, no consumer needed `Binary`'s *ownership*: every owned-`Binary`
site (the 3 `swift-ascii` `Binary(bytes).parse*` sites, the `binary-parser`
`extension Binary { parse* }` convenience, and the test suites) parses-then-
discards — a *borrowed* byte span suffices. The binary-domain parse/serialize
operations already live on `Span.\`Protocol\` where Element == Byte` (the W3
prune); the owned struct was a thin, unnecessary wrapper over that seam.

### What landed (v3.2.0)

| Package | Change |
|---|---|
| `swift-binary-primitives` | `Binary.swift`: `struct Binary: ~Copyable …` → `public enum Binary {}`. `Binary+Ownership.Borrow.Protocol.swift` deleted. Owned-struct test suite deleted. Stranded duplicate `Bit.Order Tests.swift` deleted + `bit` dep dropped (bit-primitives owns `Bit.Order` + its test). Dead `Tagged_Primitives` re-export dropped from Binary Endianness. `Binary Primitive` target deps → `[]`; **package floor = byte-only** (Cardinal/Index/Memory/Ownership/Bit dropped). Namespace manifest comment amended. |
| `swift-binary-parser-primitives` | `extension Binary { parse / parsePrefix / parsePrefixUnchecked / parseWhole }` (delegated to `self.view`) removed — the canonical engine on `Span.\`Protocol\`` is unchanged. `Binary.withInput` (static) + the `Binary.*` namespace extensions are unaffected. Parse + LEB128 test suites migrated to the `[Byte].span.parse*` seam. |
| `swift-foundations/swift-ascii` | The 3 `Binary(bytes).parse*` sites migrated to `bytes.span.parse*`. |

`Binary.Borrowed` was already deleted in the W3 prune; borrowed byte views are
`Swift.Span<Byte>`. `Cursor<Binary>` (which depended on the now-removed
`Ownership.Borrow.Protocol` conformance) had no real instantiations — only
doc-comment mentions — so its removal is inert.

### Verdict table — v3.2.0

| Option | v3.0.0 Verdict | v3.2.0 Verdict |
|---|---|---|
| A — Binary/Byte/Bit as three peer namespace domains | PARTIALLY SUPERSEDED (Binary → owned struct) | **RE-ACCEPTED (full)** — Binary is a dependency-free namespace; the canonical shape |
| #8 — T + T.Borrowed via Ownership.Borrow.Protocol (owned struct) | LANDED | **RETIRED** — owned storage is a Storage-layer concern (`Storage.Contiguous<Byte>`), not a Binary-namespace concern |

[Verified: 2026-06-22] swift-binary-primitives 167 tests / 80 suites; swift-binary-parser-primitives 77 tests / 28 suites; swift-foundations/swift-ascii 501 tests / 151 suites — all pass. Commits: swift-binary-primitives `24e7465`, swift-binary-parser-primitives `076a0a38`, swift-foundations/swift-ascii (this arc).

## Changelog

- **v3.2.0** (2026-06-22): IMPLEMENTED — Owned-storage SUPERSEDED; `Binary` reverts to a dependency-free namespace (Option A re-accepted, Option #8 retired) per the bit/byte/binary truly-primitive review (supervisor 2026-06-22). `struct Binary` → `enum Binary {}`; `Binary+Ownership.Borrow.Protocol.swift` deleted; binary-primitives floor = byte-only (Cardinal/Index/Memory/Ownership/Bit dropped). Owned byte storage is `Storage.Contiguous<Byte>` (swift-storage-primitives) per `[MOD-PLACE]`; borrowed byte views are `Swift.Span<Byte>`; binary-domain parse/serialize remain on `Span.Protocol where Element == Byte`. binary-parser's `extension Binary { parse* }` convenience removed (canonical Span.Protocol engine unchanged); swift-ascii's 3 `Binary(bytes).parse*` sites + binary-parser parse/LEB128 tests migrated to `[Byte].span.parse*`. Verified: swift-binary-primitives 167/80, swift-binary-parser-primitives 77/28, swift-foundations/swift-ascii 501/151 tests pass. Commits: swift-binary-primitives `24e7465`, swift-binary-parser-primitives `076a0a38`, swift-foundations/swift-ascii (this arc). See §"v3.2.0 Amendment".
- **v3.1.0** (2026-05-20): IMPLEMENTED — Phase 3 of the byte cascade landed. The `Binary.Bytes` sub-namespace is eliminated: `Binary.Bytes.Machine.*` collapses to `Binary.Machine.*` (12 file renames in `swift-binary-parser-primitives/Sources/Binary Machine Primitives/`); `Binary.Bytes.withBorrowed` static-accessor reframes to instance methods on `Binary` (borrowing) and `Binary.Borrowed`: `parse / parsePrefix / parseWhole / parsePrefixUnchecked`; `Binary.Bytes.withInput` static helpers move to `extension Binary`; the `Binary.Bytes` namespace declaration is deleted. The two original interpreters (array-path + contiguous-path) unify into one engine on `Binary.Borrowed._parsePrefix` — semantically identical to both originals (verified via git-show diff). Supporting infrastructure added: `Binary.init(_ bytes: [Byte])` (canonical byte-domain owned init using `UnsafeMutableBufferPointer.initialize(fromContentsOf:)`), `Binary.Borrowed.init<C: Memory.Contiguous.Protocol>(_ source)` (lifetime-bound via `_overrideLifetime`). No backward-compat shim. Workspace-wide grep zero matches (excluding markdown). Ecosystem build gate green across swift-binary-primitives (377 tests / 120 suites pass — 13 new for owned `struct Binary` API), swift-binary-parser-primitives (93 tests / 30 suites pass — 24 new for the parse instance-method API), swift-binary-coder-primitives (45 tests), swift-lexer-primitives (48 tests). Predecessor `HANDOFF-byte-span-cascade.md` Phase 3 framing of "optional successor arc" retired. The earlier `Binary.Bytes.Input.View` deprecation candidate noted in v3.0.0 §What landed has now landed via this arc's cascade. Source: HANDOFF-binary-bytes-reframe.md Findings § (workspace root). Sister-arc commits (11 across 7 repos): swift-binary-primitives `814f688`, `a75408f`, `1a0e127`, `3f5c846`; swift-binary-parser-primitives `de9a1f52`, `8a041cdd`, `acc7fc2e`; swift-byte-parser-primitives `68f18b5`; swift-coder-primitives `c32aec5`; swift-binary-coder-primitives `3d6c527`; swift-lexer-primitives `f5d94e0`; plus swift-foundations/swift-ascii Wave 2 cascade `01a329d`, `9a05eb3`, `caa70a9` (independent ASCII migration ongoing in parallel session, not blocking).
- **v3.0.0** (2026-05-20): IMPLEMENTED — Option #8 (T+T.Borrowed via Ownership.Borrow.Protocol) ships as the canonical institute pattern for `Binary`. `struct Binary: ~Copyable` over `Memory.Contiguous<Byte>` with `count: Index<Byte>.Count`; nested `Binary.Borrowed: ~Copyable, ~Escapable` over `Span<Byte>` with matching typed count; `Ownership.Borrow.Protocol` conformance enabling `Cursor<Binary>`. Byte-domain typing throughout (Memory.Contiguous<Byte> storage + Span<Byte> borrowed view); UInt8 reserved for stdlib-interop boundary as `@_disfavoredOverload`. v2.0.0's §"Empirical Finding" RETRACTED — the claimed `MemberImportVisibility` limitation was 100% stale SwiftPM build cache; hard `.build` clean resolves cleanly. Discipline saved to memory `feedback_clean_build_before_compiler_limitation_claim`. Verified: swift-binary-primitives 364/115 + swift-binary-parser-primitives 69/25 tests pass. Companion: cursor-shape-a-vs-three-worlds.md v1.5.0 adds Binary as third Case-B conformer.
- **v2.0.0** (2026-05-20): Tier 3 ecosystem-wide RECOMMENDATION → IMPLEMENTED. Adds Option #8 (T+T.Borrowed via Ownership.Borrow.Protocol — String/Path/Byte precedent) which v1.0.0 missed. Empirical finding [Verified: 2026-05-20]: Swift's `MemberImportVisibility` treats extensions on struct types more strictly than on empty-enum namespaces, blocking the owned-struct shape across the 25+ binary-extension chains in the ecosystem. The Text-style fallback (`enum Binary {}` + nested `Binary.Borrowed` + `Ownership.Borrow.Protocol` conformance) landed instead — preserves all the conformance benefits (`Cursor<Binary>` works), retains the nominal `Binary.Borrowed` type, gains the typed-count discipline (`Index<Byte>.Count` on Borrowed), and keeps the binary ecosystem compile-clean. Source: `swift-binary-primitives/Sources/Binary Namespace/Binary.Borrowed.swift` + `Binary+Ownership.Borrow.Protocol.swift`. Build + test verification: swift-binary-primitives 364 tests / 115 suites pass; swift-binary-parser-primitives 69 tests / 25 suites pass. Companion amendment: `cursor-shape-a-vs-three-worlds.md` v1.4.0 records `Binary` as a third Case-B conformer alongside Byte and Text.
- **v1.0.0** (2026-05-20): Initial RECOMMENDATION. Tier 3, ecosystem-wide.
  - Q1 closed: Binary as namespace is justified.
  - Q2/Q3 closed: Binary is a representation-domain category, NOT a collection or typealias.
  - Q4/Q5 closed: binary-parser-primitives justified at distinct domain layer; binary-parser already builds on byte-parser per the verified Package.swift dep.
  - Q6 closed: Bit (atomic information) → Byte (value-type) → Binary (representation domain) as three-layer formal stratification.
  - Q7 closed: canonical organization table for all nine packages.
  - Reaffirms `binary-primitives-package-decomposition.md`'s split of `Binary.Serializable → swift-binary-serializer-primitives`.
  - Does NOT pre-determine the cursor-abstractions Tier 3 successor arc.
