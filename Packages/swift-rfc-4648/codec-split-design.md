# RFC 4648 Codec Per-Direction Type-Asymmetry Split

<!--
---
version: 1.0.0
last_updated: 2026-05-20
status: DECISION
---
-->

## Context

RFC 4648 defines five binary↔text codecs (Base16, Base32, Base32Hex, Base64,
Base64URL). Each has two operations with asymmetric type substrates per the
W2 discrimination rubric ([API-BYTE-004], `byte-discipline` skill at commit
`891e097/4d0b49f/7e3045a`):

- **Encode**: `[Byte]` IN → `[ASCII.Code]` OUT (encoded form = ASCII alphabet per spec)
- **Decode**: `[ASCII.Code]` IN → `[Byte]` OUT (decoded form = opaque binary)

Before this arc, every codec was `[UInt8]` on both directions. Pinned to plan
doc `swift-institute/Research/broader-l2-l3-byte-typing-gap-plan.md` (`0fbc860`,
Post-W2 Arc B closeout 2026-05-20 deferred this as substantive design work).

## Question

For each codec, decide the per-direction substrate AND the shared-vs-separate
strategy for internal alphabet/lookup arrays. The arc has 5 codecs; the
question fires once per codec.

## Analysis

### Substrate decision (uniform across all 5 codecs)

Both directions of the rubric apply identically — every codec maps
binary↔ASCII-alphabet text:

| Surface | Before | After | Rubric anchor |
|---|---|---|---|
| Encode input | `Bytes.Element == UInt8` | `Bytes.Element == Byte` | Byte = opaque binary (decoded form) |
| Encode output | `Buffer.Element == UInt8` / `[UInt8]` | `Buffer.Element == ASCII.Code` / `[ASCII.Code]` | Encoded form is ASCII alphabet → ASCII.Code |
| Decode input | `Bytes.Element == UInt8` | `Bytes.Element == ASCII.Code` | Encoded form |
| Decode output | `Buffer.Element == UInt8` / `[UInt8]?` | `Buffer.Element == Byte` / `[Byte]?` | Opaque binary |
| Per-digit primitive `decode(sextet/quintet/nibble: UInt8)` | `UInt8` parameter, `UInt8?` return | `ASCII.Code` parameter, `UInt8?` return | Parameter is encoded char (ASCII.Code); return value 0-63/0-31/0-15 is arithmetic-domain UInt8 per [API-BYTE-004] / Q3 |
| Encoding table | `[UInt8]` (16/32/64 entries) | `[ASCII.Code]` (same size) | Encoded alphabet entries |
| Decoding lookup | `[UInt8]` (256 entries, sentinel `255`) | **`[UInt8?]`** (256 entries, `nil` = invalid) | Values 0-63/0-31/0-15 are arithmetic-domain UInt8 per Q3; Optional wrapping types the validity signal at the type-system level (no magic sentinel) per HANDOFF Recommended Default |
| `RFC_4648.padding` | `UInt8 = .init(ascii: "=")` | `ASCII.Code = .equalsSign` | Padding is an encoded-form ASCII char |
| `Base16.hexDecodeTable` (private) | `[UInt8]` (256, sentinel `255`) | `[UInt8?]` (256) | Same domain rule as `EncodingTable.decode` |

### Shared-vs-separate table strategy (per HANDOFF Phase 1)

**Decision: separate tables, structural reuse via `RFC_4648.EncodingTable`.**

The struct `RFC_4648.EncodingTable` is retained as the shared shape:

```swift
public struct EncodingTable: Sendable {
    public let encode: [ASCII.Code]   // was [UInt8]; size 16/32/64 per codec
    public let decode: [UInt8]        // sextet/quintet/nibble values 0-63/0-31/0-15 (arithmetic-domain per Q3)
    ...
}
```

The encode and decode arrays carry **different element types** within a single
table — `[ASCII.Code]` vs `[UInt8]` — because they answer different domain
questions (encoded-form character vs arithmetic-domain digit value). "Separate
tables" per the HANDOFF's recommended default = the encode and decode arrays
have different element types within the struct, which is the natural
representation. Each of the 5 codecs continues to declare its own
`static let encodingTable: RFC_4648.EncodingTable` instance with codec-specific
encode/decode bytes — that per-instance separation is unchanged from current
state and is not what "separate tables" addressed.

#### Per-codec consequences

All 5 codecs make the same call — encode = `[ASCII.Code]`, decode = `[UInt8]`.
Per-codec disposition is uniform; the rubric does not produce per-codec
variation:

| Codec | Encode table | Decode lookup | Notes |
|---|---|---|---|
| Base16 (Section 8) | `[ASCII.Code]` (16) — `0-9`, `a-f` (or `A-F` for uppercase variant) | `[UInt8]` (256) — shared `hexDecodeTable` covers case-insensitive | Two `EncodingTable` instances (lowercase + uppercase) share the private `hexDecodeTable: [UInt8]` |
| Base32 (Section 6) | `[ASCII.Code]` (32) — `A-Z`, `2-7` | `[UInt8]` (256) — case-insensitive | `caseInsensitive: true` builder still produces `[UInt8]` decode table |
| Base32.Hex (Section 7) | `[ASCII.Code]` (32) — `0-9`, `A-V` | `[UInt8]` (256) — case-insensitive | Same shape as Base32 |
| Base64 (Section 4) | `[ASCII.Code]` (64) — `A-Z`, `a-z`, `0-9`, `+`, `/` | `[UInt8]` (256) | Standard alphabet |
| Base64.URL (Section 5) | `[ASCII.Code]` (64) — `A-Z`, `a-z`, `0-9`, `-`, `_` | `[UInt8]` (256) | URL-safe alphabet |

### Wrapper extension split (per-direction asymmetry)

Convenience wrappers (`bytes.base64.encoded()` /
`"...".base64.decoded()`) currently extend
`Wrapper where Wrapped: Collection, Wrapped.Element == UInt8` for **both**
encode (treats wrapped as raw bytes) and decode (treats wrapped as encoded
ASCII chars). Per-direction asymmetry forces the split:

| Wrapper extension constraint | Methods | Direction |
|---|---|---|
| `Wrapped.Element == Byte` | `encode(into:padding:)`, `encoded(padding:) -> String`, `callAsFunction(padding:)` | Encode (raw bytes IN) |
| `Wrapped.Element == ASCII.Code` | `decode(into:) -> Bool`, `decoded() -> [Byte]?`, `decoded<T: FixedWidthInteger>(as:) -> T?` | Decode (encoded chars IN) |
| `Wrapped: StringProtocol` | `decode(into:)`, `decoded()`, `decoded<T:FixedWidthInteger>(as:)` | Decode via `wrapped.utf8` → lifted to `ASCII.Code` substrate at the boundary |

Span extensions on `Span where Element == UInt8` retype to
`Span where Element == Byte` (encode-input substrate). `SpanWrapper.span:
Span<UInt8>` retypes to `Span<Byte>`.

### Sentinel vs Optional decoding lookup — `[UInt8?]` adopted

The HANDOFF's recommended default specifies `[UInt8?]` (256-element lookup,
value 0-63 or nil). The previous implementation used `[UInt8]` with `255`
sentinel. This arc adopts `[UInt8?]` because:

1. **Type-system signaling of validity**: Optional encodes "valid vs invalid"
   in the type, not in a magic value. Sentinel `255` overlaps the value range
   of `UInt8` and requires per-call discipline (`guard value != 255`) to
   maintain the validity invariant.
2. **Per HANDOFF Recommended Default**: the rubric explicitly shows `[UInt8?]`
   on both sides of the migration; the substrate question (UInt8 vs Byte) is
   orthogonal to the representation question (Optional vs sentinel) but
   adopting Optional is the typed-API answer.
3. **Call-site ergonomics**: `let value = table[Int(idx)]` followed by
   `guard let value` propagates cleanly through `decode(sextet:) -> UInt8?`
   without a sentinel-to-Optional conversion step.

Cost: ~5 call sites per codec body need `guard let value = ...` instead of
`guard value != 255`. Init helpers initialize with `[UInt8?](repeating: nil,
count: 256)` and store `UInt8(index)` (which Swift wraps in `Optional` at
the assignment).

### Stdlib-interop UInt8 forwarders — DEFERRED to follow-up arc

Per [API-BYTE-006] / [API-BYTE-007], any UInt8 forwarder in byte-domain
extensions MUST carry `@_disfavoredOverload` AND live in a `* Standard Library
Integration` module. rfc-4648 currently has no SLI target. Adding one is
out-of-scope for this codec-split arc (HANDOFF Phase 4 requires zero residual
UInt8 in primary surface; adding UInt8 forwarders in primary modules violates
that). Callers holding `[UInt8]` (e.g., from network frames) bridge via
`[Byte](bytes)` / `[ASCII.Code](bytes)` at the call site until a follow-up
arc adds the SLI module.

Reference precedent: rfc-7519 added `RFC 7519 Standard Library Integration`
target under Arc D (`5a4995b`) / Arc F (`29d0703`) for its `[UInt8]` JWT
constructor forwarder. Same pattern applies for rfc-4648 when SLI work is
authorized.

## Outcome

**Status**: DECISION

**Per-codec design** (uniform across Base16, Base32, Base32Hex, Base64, Base64URL):

- `RFC_4648.EncodingTable.encode: [ASCII.Code]`
- `RFC_4648.EncodingTable.decode: [UInt8?]` (Optional; nil = invalid)
- `RFC_4648.padding: ASCII.Code` (was `UInt8 = .init(ascii: "=")`)
- Encode input substrate: `Byte`
- Encode output substrate: `ASCII.Code`
- Decode input substrate: `ASCII.Code`
- Decode output substrate: `Byte`
- Per-digit primitive: parameter retypes to `ASCII.Code`, return stays `UInt8?` (arithmetic-domain per Q3)
- Wrapper extensions split by direction (Byte for encode, ASCII.Code for decode)
- Internal shared `encodeBase64` / `decodeBase64` / `encodeBase32` / `decodeBase32` (+ToInteger): same retype propagation
- No SLI UInt8 forwarders this arc; deferred to follow-up

**Implementation path**: Phase 2 sweep is mechanical against this rubric; no
per-codec variation surfaces a class-(c) ecosystem question (the 5 codecs are
structurally uniform in substrate decisions).

## References

- `swift-institute/Research/broader-l2-l3-byte-typing-gap-plan.md` § Post-W2
  Arc B closeout (DEFERRED row); § Post-W2 Arc D (rfc-7519 reference precedent)
- `byte-discipline` skill, [API-BYTE-004] W2 discrimination rubric (arithmetic-domain
  row, opaque byte-domain payload row), commit `891e097/4d0b49f/7e3045a`
- `swift-rfc-791@cde98cb` — arithmetic-domain reference (TTL stays UInt8)
- `swift-rfc-7519@5a4995b` — opaque byte-domain payload reference
