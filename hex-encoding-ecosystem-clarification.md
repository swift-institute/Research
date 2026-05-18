# Hex / Base-N Encoding Ecosystem Clarification

<!--
---
version: 1.0.0
last_updated: 2026-05-18
status: DECISION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The hex / base-N encoding surface sits across multiple packages (binary, byte,
ASCII, RFC 4648). HANDOFF.md Wave 4 Item 14 (F3) frames it as an
"institutional statement" missing — but two prior research docs already
adjudicate the architecture and a third (the byte-extraction arc) settles
the binary-vs-byte ownership question. This doc CONSOLIDATES the answer in
one place, EXTENDS the analysis to the `ASCII.Hexadecimal` / `Binary.Base.\`16\``
relationship (not addressed by either predecessor), and CLOSES the latent
ambiguity about whether a `Byte.Base*` namespace should exist.

The handoff's four sub-questions:

1. Which encoding belongs in which home.
2. Whether `Binary.Base*` and `Byte.Base*` should coexist or one subsumes
   the other.
3. How `RFC_4648` spec-mirroring fits with the per-domain instances.
4. Whether Base62 / other-base-N encodings follow the same rule.

Q1 / Q3 / Q4 are answered by the two prior docs; Q2 is answered by the
byte-extraction arc's binary-stack audit. The novel contribution of this
doc is the explicit decision frame plus the ASCII.Hexadecimal / Binary.Base
disambiguation that no predecessor records.

**Trigger**: HANDOFF.md Wave 4 Item 14 (F3) requested an ecosystem-wide
institutional statement. The latent risk is that future sessions read the
multi-package surface as ambiguous and propose `Byte.Base16` /
`ASCII.Hexadecimal.Encoder` re-implementations that would duplicate
existing surface or violate `[API-NAME-001b]` (Subject-First).

## Prior research

Two predecessor research docs are load-bearing; a third closes the cross-
domain ownership question:

### [`binary-base-n-encoding-family-architecture.md`](./binary-base-n-encoding-family-architecture.md) v1.0.0 (2026-05-07, RECOMMENDATION)

Banner-superseded for Phase 2 by the reconciliation doc below; Phase 1
stands. Established the L1 mechanism shape:

- Closed-radix nested types `Binary.Base.\`16\`` / `\`32\`` / `\`58\`` /
  `\`62\`` / `\`64\`` / `\`85\``, NOT value-generic `Binary.Base<let N: Int>`.
  Reason: `Binary.Base<23456789>` instantiates as a type with no method
  surface (radix axis is closed by encoding mathematics; ~6 useful values).
- Per-radix `.Encode` / `.Decode` phantom tags + `Property<Tag, Base>`
  callable mechanism per `[API-NAME-008]` (multi-form operations under one
  root MUST use Property.View nested accessors). Algorithm is parameterized
  over alphabet at the Property level; consumers supply alphabet either via
  direct argument or via spec-package extensions that bind it.
- Convention alphabets (`Binary.Base.\`62\`.encode.{standard, gmp,
  inverted}`) ship in the L1 mechanism package; spec-defined alphabets ship
  in per-spec L2 packages.
- Heritage-forks `swift-base62-primitives` into `swift-binary-base-primitives`
  (the legacy package is gone from disk — Phase 3 archive landed).

### [`binary-base-n-rfc-4648-reconciliation.md`](./binary-base-n-rfc-4648-reconciliation.md) v1.0.0 (2026-05-07, RECOMMENDATION)

Supersedes Phase 2 of the predecessor. Two corrections drive it:

- The empirical claim "no `swift-ietf/swift-rfc-4648` repo exists" was
  wrong. The repo is public, actively developed, and ships
  `RFC_4648.Base{16,32,32.Hex,64,64.URL}` per spec terminology.
- Principal-stated directional rule: "Standards are encoded as literally
  to the spec as they are, and they use primitives as their building
  blocks. Primitives don't add to standards; primitives are USED to encode
  the standard." The original direction (RFC alphabets as Property
  extensions on the L1 tag from inside L2) inverted this — the right
  direction is L2 delegates algorithms to L1, NOT L2 extends L1's Property
  surface from outside.

Reconciled three-layer shape (the canonical pattern, mirrored from
`swift-ascii-primitives` → `swift-incits-4-1986` → `swift-ascii`):

| Tier | Package | Role |
|------|---------|------|
| L1 | `swift-primitives/swift-binary-base-primitives` (SHIPPED v0.1.0) | Closed-radix mechanism + algorithms + convention alphabets |
| L2 | `swift-ietf/swift-rfc-4648` (public, pre-reconciliation state) | Spec-literal `RFC_4648.Base{16,32,...}` types; algorithms will delegate to L1 once L1 is publicly tagged |
| L2 (future) | `swift-bitcoin/swift-base58`, `swift-zmq/swift-z85`, etc. | Per-spec alphabets for non-RFC conventions, delegating to L1 |
| L3 (future, optional) | `swift-foundations/swift-binary-base` | Ergonomic Property extensions binding spec defaults — `Binary.Base.\`16\`.encode(bytes)` calls RFC 4648 §8 |

### [`byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md) v1.0.1 (2026-05-15, DECISION)

Promoted `[API-NAME-001b]` (LargerDomain.Subdomain — Subject-First When
Domain Exceeds Role). Includes a binary-stack audit explicitly evaluating
whether `Binary.*` packages should be re-routed to depend on
`swift-byte-primitives`. Verdict: GREEN across all five binary packages.
The architectural reading is dispositive:

> "`Binary` is the encoding/representation domain. `Byte` is the value-type
> domain. They are peer subjects, not consumer/producer. The binary stack
> neither needs nor wants `swift-byte-primitives` as a dependency, and
> introducing one would create a phantom layering."

This settles Q2 from the handoff: no `Byte.Base*` namespace.

## Survey — current ecosystem state

[Verified: 2026-05-18 against file system at `/Users/coen/Developer/`]

### swift-primitives/swift-binary-base-primitives (L1)

- Source files (35): `Binary.Base.swift`, `Binary.Base.Encode.swift`,
  `Binary.Base.Decode.swift`, six radix structs (`Binary.Base.\`16\``,
  `\`32\``, `\`58\``, `\`62\``, `\`64\``, `\`85\``), per-radix
  `+encode.swift` / `+decode.swift` algorithm files, twelve
  `Property+Binary.Base.\`N\`.{Encode,Decode}.swift` Property extensions
  carrying the parameterized algorithms, plus `Binary.Base.62.Alphabet.swift`
  for convention alphabets.
- Deps: `swift-property-primitives` (Property mechanism), `swift-binary-primitives`
  (Binary namespace).
- Heritage: initial commit `de0d070` reads
  *"Initial publication: swift-binary-base-primitives (heritage from
  swift-base62-primitives)"* — the legacy `swift-base62-primitives` package
  has been folded into this multi-radix package and is absent from disk.
- Status: Phase 1 of the original architecture doc complete; private,
  v0.1.0 awaiting public release for the reconciliation Phase 2 gate.

### swift-ietf/swift-rfc-4648 (L2, public)

- Source files (16 + 1 Foundation): `RFC_4648.swift`,
  `RFC_4648.Base16.swift`, `RFC_4648.Base32.swift`,
  `RFC_4648.Base32.Hex.swift`, `RFC_4648.Base64.swift`,
  `RFC_4648.Base64.URL.swift`, plus per-radix `.Encoder` + `.SpanWrapper`
  files, plus collection / integer / span / string extension surfaces, plus
  `RFC_4648.EncodingTable.swift` (table-driven encode/decode storage).
- Deps: `swift-binary-primitives`, `swift-ascii-primitives`,
  `swift-standard-library-extensions`. Does NOT depend on
  `swift-binary-base-primitives` yet — the reconciliation Phase 2 refactor
  is queued, gated on L1 going public + tagged.
- Algorithm shape: inline bit-packing (`Base16.encode(byte: UInt8, into:)`)
  and direct alphabet table lookup. Each radix has a `Wrapper<W>`
  convenience instance type for `bytes.hex.encoded()` / `"deadbeef".hex.decoded()`
  syntax.
- API includes BOTH byte-array encode/decode AND integer encode/decode
  (`RFC_4648.Base16.encode<T: FixedWidthInteger>(_, into:)`,
  `RFC_4648.Base16.decode<T>(_) -> T?`).

### swift-primitives/swift-ascii-primitives (L1) — `ASCII.Hexadecimal`

- File: `Sources/ASCII Primitives/ASCII.Hexadecimal.swift` declares
  `extension ASCII { public enum Hexadecimal {} }` — a SUBJECT DOMAIN,
  not an encoder.
- Doc comment names the consumers:
  > "Extended by capability packages with concrete parser and serializer
  > types — `ASCII.Hexadecimal.Parser` (from
  > `ASCII_Hexadecimal_Parser_Primitives`), `ASCII.Hexadecimal.Serializer`
  > (from `ASCII_Hexadecimal_Serializer_Primitives`),
  > `ASCII.Hexadecimal.Error`."

### swift-primitives/swift-ascii-parser-primitives — `ASCII.Hexadecimal.Parser`

- File: `Sources/ASCII Hexadecimal Parser Primitives/ASCII.Hexadecimal.Parser.swift`
- Signature:
  ```swift
  public struct Parser<Input: Collection.Slice.`Protocol`, T: FixedWidthInteger>
  ```
- Output: `T` (a fixed-width integer). Operation: consume ASCII bytes
  (`0-9A-Fa-f`) and accumulate into an integer.

### swift-primitives/swift-ascii-serializer-primitives — `ASCII.Hexadecimal.Serializer`

- Files include the `ASCII Hexadecimal Serializer Primitives Tests/`
  directory and matching production targets per the package's target
  layout.

### swift-primitives/swift-byte-primitives (L1)

- `Byte` is a `@frozen struct` carrying a `UInt8` `underlying` field.
- The doc-comment of `Sources/Byte Primitives/Byte.swift:32-35` is
  explicit:
  > "Hex (and other base) rendering is NOT part of `Byte`. Use the
  > encoder packages — `swift-binary-base-primitives` (`Binary.Base.16`)
  > or `swift-ietf/swift-rfc-4648` (`RFC_4648.Base16`). L1 String-conversion
  > friction is intentional per `[PRIM-FOUND-004]`."
- No `Byte.Base*` namespace exists on disk.

### Absent — `swift-binary-base62-primitives`

The handoff's enumeration listed `swift-binary-base62-primitives` as a
current-ecosystem package. [Verified: 2026-05-18 via `find … -type d`]
this package does NOT exist on disk under `swift-primitives/`. The legacy
`swift-base62-primitives` (note the different name) was the predecessor —
heritage-forked into `swift-binary-base-primitives` per Phase 3 of the
predecessor architecture doc. The handoff's claim was stale.

## Naming-convention application

Mapping the surveyed surface to `[API-NAME-001]` / `[API-NAME-001a]` /
`[API-NAME-001b]` / `[API-NAME-003]`:

### `Binary.Base.\`N\`` — closed-radix encoder family

| Rule | Compliance |
|------|------------|
| `[API-NAME-001]` Nest.Name | ✓ `Binary` ⊃ `Base` ⊃ `\`16\``; reads as "16 (radix) within Base (encoding-family) within Binary (representation domain)" |
| `[API-NAME-001a]` Single-Type-No-Namespace | ✓ `Base` contains six radix structs as siblings (multi-inhabitant namespace) |
| `[API-NAME-001b]` LargerDomain.Subdomain | ✓ Binary is the larger encoding-representation domain; Base-N is a specialization within it. Wrong shape `Encoding.Binary.Base16` would have Encoding as the role, which doesn't fit because Encoding is not the larger domain — it's the role being specialized |
| `[API-NAME-003]` Spec-Mirroring | N/A — no specification governs the L1 mechanism itself; specs (RFC 4648, Bitcoin base58, Z85) attach via L2 packages |

The backticked-digit shape (`Binary.Base.\`16\``) mirrors the existing
`Windows.\`32\`` precedent per `[PLAT-ARCH-008k]` — the institute's
pattern for closed numeric variant sets whose variant identifier IS the
spec-defined number.

### `RFC_4648.Base{16,32,...}` — spec-mirroring spec-implementation

| Rule | Compliance |
|------|------------|
| `[API-NAME-001]` Nest.Name | ✓ |
| `[API-NAME-003]` Spec-Mirroring | ✓ RFC 4648 §4 ("Base 64 Encoding"), §5 ("Base 64 Encoding with URL and Filename Safe Alphabet"), §6 ("Base 32 Encoding"), §7 ("Base 32 Encoding with Extended Hex Alphabet"), §8 ("Base 16 Encoding") map directly to `Base64`, `Base64.URL`, `Base32`, `Base32.Hex`, `Base16` |

The `RFC_4648` package both has its own algorithm code AND a spec-defined
alphabet. Reconciliation Phase 2 retains the spec-literal type surface and
moves the algorithm implementation behind a delegation to the L1
mechanism. Public API surface unchanged.

### `ASCII.Hexadecimal` and `ASCII.Hexadecimal.Parser` — different operation

This is the non-obvious case. ASCII.Hexadecimal and Binary.Base.16 SHARE
the alphabet (`0-9A-F` / `0-9a-f`) but DIFFER in operation:

| Type | Input | Output | Purpose |
|------|-------|--------|---------|
| `ASCII.Hexadecimal.Parser<Input, T>` | ASCII bytes from a parser input | `T: FixedWidthInteger` (single integer) | Consume hex-numeral text into one integer (e.g., parse `"DEAD"` → `UInt16(0xDEAD)`) |
| `ASCII.Hexadecimal.Serializer` | `FixedWidthInteger` | ASCII bytes | Render one integer to hex-numeral text |
| `Binary.Base.\`16\`.encode` | `[UInt8]` (arbitrary-length byte array) | `String` (arbitrary-length ASCII hex) | Encode bytes-as-data to hex-encoded byte-stream |
| `Binary.Base.\`16\`.decode` | hex-encoded byte-stream | `[UInt8]` | Decode hex-encoded byte-stream to bytes |
| `RFC_4648.Base16.encode<T: FixedWidthInteger>(_, into:)` | `T` | hex byte-stream | RFC 4648 §8 integer encoding (canonical alphabet) |
| `RFC_4648.Base16.encode(bytes:into:)` | `[UInt8]` | hex byte-stream | RFC 4648 §8 byte-array encoding (canonical alphabet) |

The shared alphabet is a coincidence of mathematics (4 bits per ASCII hex
digit). The OPERATIONS are different domain concerns:

- `ASCII.Hexadecimal.*` is the ASCII parsing/serialization domain
  consuming/producing **integer literals** as ASCII text. Subject: ASCII.
  Specialization: parsing/serializing a specific ASCII-numeral form.
  Per `[API-NAME-001b]` the larger domain (ASCII) owns the namespace.
- `Binary.Base.\`16\`.*` is the binary-encoding domain transforming
  **byte arrays** to/from hex text. Subject: Binary. Specialization: the
  Base-16 encoding scheme. Per `[API-NAME-001b]` the larger domain
  (Binary) owns the namespace.
- `RFC_4648.Base16.*` is the spec-literal surface implementing both
  operations against the canonical §8 alphabet. Per `[API-NAME-003]` the
  spec namespace governs.

No overlap requires resolution. The three surfaces operate on different
data shapes (integer / byte-array) and serve different consumers (text
parsers / byte-array encoders / RFC-faithful applications).

### Absence of `Byte.Base*` — load-bearing

`[API-NAME-001b]`'s Decision Procedure run on a hypothetical
`Byte.Base16`:

| Question | Answer |
|----------|--------|
| Is `Base16` a kind of `Byte` (Byte-variant)? | No — `Base16` is a binary-encoding scheme, not a byte variant |
| Is one of `{Byte, Base16}` a role and the other a subject — with `Base16` being "the Byte specialization of Base16"? | No — Base16 is not a role applied to bytes-as-subject; it is a binary→text encoding whose data-flow is byte-array → hex-text. The "subject" of base-16 encoding is `Binary` (the representation domain), not `Byte` (the value-type domain). |

The proposed shape fails both clauses. `Byte.Base16` would be a phantom
namespace. The byte-extraction arc's binary-stack audit (GREEN across all
five binary packages — see prior research above) reached the same
verdict from the structural side: Binary and Byte are peer subjects, not
consumer/producer.

## Decision points

### Q1 — Which encoding belongs in which home?

**Decision**:

| Operation | Home | Notes |
|-----------|------|-------|
| Closed-radix mechanism + algorithms | `swift-primitives/swift-binary-base-primitives` (L1) | `Binary.Base.\`16\`` / `\`32\`` / `\`58\`` / `\`62\`` / `\`64\`` / `\`85\``. SHIPPED v0.1.0. |
| Convention-defined alphabets (no spec authority) | Same L1 package | Base62 standard / GMP / inverted. Convention authorities can later move to per-convention L2 packages without breaking the L1 mechanism. |
| Spec-defined RFC 4648 alphabets | `swift-ietf/swift-rfc-4648` (L2, public) | `RFC_4648.Base16`, `Base32`, `Base32.Hex`, `Base64`, `Base64.URL` — spec-literal surface per `[API-NAME-003]`. Algorithms will delegate to L1 per reconciliation Phase 2. |
| Future Bitcoin base58 | `swift-bitcoin/swift-base58` (L2, future) | Per-convention L2 package, delegating to L1 mechanism. |
| Future ZeroMQ Z85 base85 | `swift-zmq/swift-z85` (L2, hypothetical) | Same pattern. |
| Future Ascii85 (Adobe PostScript / PDF) | Extension of `swift-iso/swift-iso-32000` or own L2 (hypothetical) | Same pattern. |
| Future Base85 RFC 1924 | `swift-ietf/swift-rfc-1924` (L2, hypothetical) | Same pattern. |
| Ergonomic call-site (RFC defaults baked) | `swift-foundations/swift-binary-base` (L3, deferred) | Optional L3 unifier per reconciliation Phase 4. Provides `Binary.Base.\`16\`.encode(bytes)` with §8 alphabet pre-bound. Lives at L3 because the spec-default choice is an opinionated composition decision, not an L1 mechanism fact. |
| ASCII hex-NUMERAL parse (text → integer) | `swift-primitives/swift-ascii-parser-primitives` | `ASCII.Hexadecimal.Parser<Input, T>`. Different operation than Binary.Base.16 — output is `T: FixedWidthInteger`, not `[UInt8]`. |
| ASCII hex-NUMERAL serialize (integer → text) | `swift-primitives/swift-ascii-serializer-primitives` | `ASCII.Hexadecimal.Serializer`. Mirror of the parser. |

### Q2 — Should `Binary.Base*` and `Byte.Base*` coexist?

**Decision**: NO. `Binary.Base*` is canonical. `Byte.Base*` MUST NOT be
created.

**Reason**: `Binary` and `Byte` are PEER SUBJECTS — the binary-encoding
domain and the byte value-type domain. Encoding bytes to text is a
Binary-domain operation regardless of the per-byte representation. A
`Byte.Base16` namespace would:

- Suggest base-16 encoding is a property of the byte value type rather
  than of binary representation. The byte value type is `Byte` (carries
  one `UInt8`); base-16 encoding transforms BYTE ARRAYS (plural) into hex
  text. The pluralization is structural, not stylistic.
- Force `swift-byte-primitives` to depend on an encoder mechanism, which
  the byte-extraction arc's binary-stack audit explicitly rejected.
  `swift-byte-primitives`'s doc comment is already explicit:
  > "Hex (and other base) rendering is NOT part of `Byte`. Use the
  > encoder packages — `swift-binary-base-primitives` (`Binary.Base.16`)
  > or `swift-ietf/swift-rfc-4648` (`RFC_4648.Base16`). L1 String-conversion
  > friction is intentional per `[PRIM-FOUND-004]`."

The handoff's framing of Q2 as a coexistence question was contingent on
the framing being live. Per the byte-extraction arc's binary-stack audit,
it is not live; this doc closes the latent ambiguity by stating the
verdict explicitly.

### Q3 — How does `RFC_4648` spec-mirroring fit with the per-domain instances?

**Decision**: Per `[API-NAME-003]` and the three-layer pattern, the
spec-literal types `RFC_4648.Base{16,32,...}` live at L2 in
`swift-ietf/swift-rfc-4648`. They are spec-mirroring entities (RFC 4648
§4 / §5 / §6 / §7 / §8) with their own public surface separate from the
L1 mechanism. The reconciliation Phase 2 refactor moves the algorithm
*implementation* to delegate to L1's `Binary.Base.\`N\``, but the public
RFC-namespaced type surface is preserved.

Consumers have two equally-valid surfaces:

```swift
// L2 — spec-literal
RFC_4648.Base16.encode(bytes, into: &buffer)
RFC_4648.Base32.Hex.encode(bytes)
RFC_4648.Base64.URL.encode(bytes)
"deadbeef".hex.decoded()                         // Wrapper convenience

// L3 — envisioned ergonomic, with spec defaults pre-bound (deferred)
Binary.Base.`16`.encode(bytes)                   // → RFC 4648 §8
Binary.Base.`32`.encode(bytes)                   // → RFC 4648 §6 standard
Binary.Base.`32`.encode.hex(bytes)               // → RFC 4648 §7 extended hex
Binary.Base.`64`.encode(bytes)                   // → RFC 4648 §4 standard
Binary.Base.`64`.encode.url(bytes)               // → RFC 4648 §5 URL-safe
```

The L1 mechanism shape (Property.callAsFunction taking explicit alphabet)
is the foundation; consumers who don't import the L3 unifier supply the
alphabet directly or use the L2 spec-literal API.

### Q4 — Does Base62 / other-base-N follow the same rule?

**Decision**: YES. Two-tier classification by spec authority:

- **Convention-defined alphabets** (no spec authority): ship as Property
  extensions in the L1 mechanism package. `Binary.Base.\`62\`.encode.standard`,
  `Binary.Base.\`62\`.encode.gmp`, `Binary.Base.\`62\`.encode.inverted` —
  all live in `swift-binary-base-primitives` today.
- **Spec-authority-defined alphabets**: ship in per-spec L2 packages
  extending `Property where Tag == Binary.Base.\`N\`.Encode`. Examples:
  RFC 4648 §4/§5/§6/§7/§8 alphabets in `swift-ietf/swift-rfc-4648`;
  future Bitcoin base58 in `swift-bitcoin/swift-base58`; future Z85
  base85 in `swift-zmq/swift-z85`; future RFC 1924 base85 in
  `swift-ietf/swift-rfc-1924`; future Ascii85 alongside `swift-iso/swift-iso-32000`.

A convention-defined alphabet MAY later migrate to a per-convention L2
package without breaking the L1 mechanism — the Property-extension shape
makes relocation a one-extension-block move per the predecessor
architecture doc's open-question OQ-1.

### Q5 — `ASCII.Hexadecimal` vs `Binary.Base.\`16\`` (clarification, no decision needed)

The two surfaces co-exist by design and do not compete:

| `ASCII.Hexadecimal.*` | `Binary.Base.\`16\`.*` |
|------------------------|--------------------------|
| Input = ASCII byte stream | Input = byte array (any bytes) |
| Output = single `FixedWidthInteger` | Output = `String` / byte array |
| Use case: parse `"0xDEAD"` literal | Use case: encode `[0xDE, 0xAD, 0xBE, 0xEF]` for transmission |
| Subject: ASCII numeric domain | Subject: Binary encoding domain |
| Owner: swift-ascii-{parser,serializer}-primitives | Owner: swift-binary-base-primitives + swift-rfc-4648 |

`RFC_4648.Base16` provides BOTH operations against the §8 canonical
alphabet — the spec defines both byte-array and integer encoding forms.
That overlap is intentional spec faithfulness, not a domain duplication;
consumers needing RFC-correct integer hex use `RFC_4648.Base16.encode<T>(_, into:)`,
consumers needing generic ASCII hex literal parsing (e.g., for source-code
literal parsing where prefixes / case-insensitivity / overflow semantics
differ from RFC 4648) use `ASCII.Hexadecimal.Parser<Input, T>`.

## Outcome

**Status**: DECISION

**Recommendation summary**:

1. **L1 mechanism** lives at `swift-primitives/swift-binary-base-primitives`
   under `Binary.Base.\`N\`` for the closed radix set `{16, 32, 58, 62, 64, 85}`
   with `.Encode` / `.Decode` phantom tags and `Property<Tag, Base>` callable
   mechanism. SHIPPED v0.1.0 (private).
2. **L2 spec packages** own spec-literal types per `[API-NAME-003]` and
   delegate algorithms to L1. `swift-ietf/swift-rfc-4648` exists and is
   public; reconciliation Phase 2 (algorithm delegation refactor) is queued
   on L1 going public + tagged. Future per-convention L2 packages (Bitcoin
   base58, Z85, Ascii85, etc.) follow the same pattern.
3. **No `Byte.Base*` namespace** is created. `Binary` and `Byte` are peer
   subjects per the byte-extraction arc's binary-stack audit; Binary
   encoding operates on byte arrays as a unit, not as a Byte-domain
   capability. `swift-byte-primitives` already delegates hex rendering
   explicitly in its `Byte.swift` doc comment.
4. **`ASCII.Hexadecimal.*`** is a distinct surface for parsing/serializing
   integer literals from/to ASCII hex digits. It coexists with `Binary.Base.\`16\``
   without overlap — different data shapes (integer vs byte array),
   different domain owners (ASCII parsing/serialization vs Binary
   encoding), different consumer use cases (literal parsing vs byte-stream
   encoding).
5. **L3 unifier** (`swift-foundations/swift-binary-base`) is the
   architecturally-correct home for the ergonomic call-site shape
   (`Binary.Base.\`16\`.encode(bytes)` with RFC defaults pre-bound).
   Deferred per reconciliation Phase 4 until at least swift-rfc-4648's
   post-Phase-2 delegation refactor lands as the L2 substrate to compose
   against.

**Skill-promotion candidate**: the per-radix nested-backticked-digit shape
(`Binary.Base.\`16\``, `Windows.\`32\``, future `IP.\`4\`` / `IP.\`6\``)
is a recurring pattern across the institute. The predecessor architecture
doc's Outcome section already flagged it as worth promoting to a
code-surface skill amendment. This doc reinforces the recommendation but
does NOT promote here — promotion is a `skill-lifecycle` workflow, out of
scope for this doc.

## Migration scope

No source-code changes are authorized by this doc. The reconciliation
Phase 2 refactor (swift-rfc-4648 algorithm delegation) and Phase 4 L3
unifier are tracked at the reconciliation doc; both require separate
per-action authorization. The migration scope spelled out below is the
status snapshot, not a dispatch.

| Action | Status |
|--------|--------|
| swift-binary-base-primitives v0.1.0 | SHIPPED (private). Public release pending per-action authorization. |
| swift-base62-primitives archival | RESOLVED — heritage-forked into swift-binary-base-primitives; legacy package absent from disk. |
| swift-rfc-4648 Phase 2 algorithm delegation | QUEUED. Gated on swift-binary-base-primitives public + tagged release. Public API unchanged through the refactor. |
| swift-foundations/swift-binary-base (L3 unifier, Phase 4) | DEFERRED. Optional package; consumers who want RFC-default ergonomics use L3, consumers who want spec-literal use L2 directly. |
| Future per-convention L2 packages (swift-bitcoin/swift-base58, etc.) | NOT IN PLAN. Per-spec authorship decision; this doc records the architectural shape, not the publication schedule. |

The reconciliation doc lists Phase 2 sub-steps (2a alphabet exposure, 2b
gate on L1 going public, 2c delegation refactor, 2d duplicated-code
cleanup); this doc does not duplicate them.

## References

### Internal artifacts (canonical predecessors)

- [`binary-base-n-encoding-family-architecture.md`](./binary-base-n-encoding-family-architecture.md) v1.0.0 (2026-05-07, RECOMMENDATION; Phase 2 superseded; Phase 1 stands).
- [`binary-base-n-rfc-4648-reconciliation.md`](./binary-base-n-rfc-4648-reconciliation.md) v1.0.0 (2026-05-07, RECOMMENDATION; supersedes Phase 2 of the predecessor; introduces L3 Phase 4).
- [`byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md) v1.0.1 (2026-05-15, DECISION; promotes `[API-NAME-001b]`; binary-stack audit GREEN).
- [`ascii-parsing-domain-ownership.md`](./ascii-parsing-domain-ownership.md) v4.2.0 (2026-03-04, RECOMMENDATION; prior single-domain instance of subject-first ordering for ASCII × Parser).

### Internal artifacts (verified source surface, 2026-05-18)

- `swift-primitives/swift-binary-base-primitives/Sources/Binary Base Primitives/` (35 source files; `Binary.Base.\`16\`–\`85\`` + Property extensions).
- `swift-primitives/swift-binary-base-primitives/Package.swift` (deps: swift-property-primitives, swift-binary-primitives via path).
- `swift-ietf/swift-rfc-4648/Sources/RFC 4648/` (16 + 1 Foundation source files; `RFC_4648.Base16` etc.).
- `swift-ietf/swift-rfc-4648/Package.swift` (deps: swift-binary-primitives, swift-ascii-primitives, swift-standard-library-extensions — does NOT YET depend on swift-binary-base-primitives).
- `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift:32-35` (the explicit delegation doc comment).
- `swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Hexadecimal.swift` (subject-domain namespace declaration).
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Hexadecimal Parser Primitives/ASCII.Hexadecimal.Parser.swift` (the integer-output parser).

### Skills + conventions

- `[API-NAME-001]` Nest.Name pattern.
- `[API-NAME-001a]` Single-Type-No-Namespace.
- `[API-NAME-001b]` LargerDomain.Subdomain — Subject-First When Domain
  Exceeds Role (promoted by the byte-extraction arc).
- `[API-NAME-003]` Specification-Mirroring Names.
- `[API-NAME-008]` Property.View vs Labeled Method Decision Rule (multi-form
  encode/decode under one root requires Property.View).
- `[ARCH-LAYER-001]` Dependency direction (L2 may import L1; L1 may not
  import L2).
- `[ARCH-LAYER-007]` No-Foundation discipline through all five layers
  (composition with the L1 mechanism's Foundation-freedom).
- `[ARCH-LAYER-011]` Improve institute foundation, don't reach for Apple
  Foundation or third-party libs (the L1 + L2 + L3 stack IS the institute
  resolution; no third-party hex lib is needed).
- `[PLAT-ARCH-008k]` (referenced by the predecessor architecture doc) —
  backticked-digit nested types for closed numeric variant sets.
- `[PRIM-FOUND-004]` (referenced by `swift-byte-primitives`'s Byte.swift
  doc comment) — L1 String-conversion friction is intentional.
- `feedback_correctness_and_evergreen.md` — pre-1.0 architectural decisions
  are correctness-driven, not consumer-count-driven.

### External primary sources

- [RFC 4648 — The Base16, Base32, and Base64 Data Encodings](https://datatracker.ietf.org/doc/html/rfc4648).
- [INCITS 4-1986 — ASCII](https://www.incits.org/) (precedent for the
  spec-literal L2 pattern, mirroring three-layer ASCII stack).
