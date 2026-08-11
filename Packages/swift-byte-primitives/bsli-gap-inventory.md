# BSLI Gap Inventory

**Status**: LANDED 2026-05-19
**Scope**: `swift-byte-primitives/Sources/Byte Primitives Standard Library Integration`

This document captures the friction inventory that motivated the BSLI
additions landed in this arc, plus the explicit exclusions and the
Swift-language-blocked candidates. Future additions should consult this
inventory before re-deriving rejected items.

## Motivating arc

The Byte-adoption arc (α + β + Issue 1 substrate migration) drove
byte-domain APIs to full Byte adoption end-to-end. Stdlib integer types,
collections, and strings remain UInt8-typed by design (UInt8 is the
arithmetic carrier; Byte is its byte-domain twin per
[byte-protocol-capability-marker.md](../../../swift-institute/Research/byte-protocol-capability-marker.md)).
The friction at the boundary between byte-domain and stdlib drove this
BSLI work. Without BSLI bridges, every consumer wraps `Byte(uint8)` /
`byte.underlying` at construction and extraction sites, producing
ceremony that obscures intent.

## Landed additions

### 1. Integer widening (unlabelled)

| Type | Init | Replaces |
|------|------|----------|
| `UInt16` | `init(_ byte: Byte)` | `UInt16(byte.underlying)` chains |
| `UInt32` | `init(_ byte: Byte)` | `UInt32(byte.underlying)` chains |
| `UInt64` | `init(_ byte: Byte)` | `UInt64(byte.underlying)` chains |
| `Int8` | `init(_ byte: Byte)` | `Int8(byte.underlying)` — traps on >127 |
| `Int16` | `init(_ byte: Byte)` | `Int16(byte.underlying)` chains |
| `Int32` | `init(_ byte: Byte)` | `Int32(byte.underlying)` chains |
| `Int64` | `init(_ byte: Byte)` | `Int64(byte.underlying)` chains |

**Naming**: unlabelled per "no labels for bridging where possible".

**Motivating sites**: `Binary.Bytes.Machine.Run.swift` endianness decoders
(`u16le`, `u16be`, `u32le`, `u32be`, `u64le`, `u64be`) — each calls
`UInt16(try! input.advance())` / `UInt32(...)` / `UInt64(...)` per byte.
After the substrate migration these become `UInt16(byte)` / `UInt32(byte)`
/ `UInt64(byte)` directly without `.underlying` ceremony.

### 2. Integer bitPattern (stdlib-pattern label)

| Type | Init | Semantic |
|------|------|----------|
| `Int8` | `init(bitPattern byte: Byte)` | Same-width reinterpret: `0xFF` → `-1` |
| `Int16` | `init(bitPattern byte: Byte)` | Zero-extend then `Int16(bitPattern: UInt16)` |
| `Int32` | `init(bitPattern byte: Byte)` | Zero-extend then `Int32(bitPattern: UInt32)` |
| `Int64` | `init(bitPattern byte: Byte)` | Zero-extend then `Int64(bitPattern: UInt64)` |

**Naming**: `bitPattern:` is semantic per stdlib convention (allowed
under the no-labels-for-bridging rule).

**Motivating sites**: `Binary.Bytes.Machine.Run.swift` `.i8` decoder
(`Int8(bitPattern: try! input.advance())`). `Int16+` variants provided
for stdlib-pattern symmetry; for unsigned source `Byte`, the result
equals the unlabelled widening.

### 3. Array bridges (unlabelled, both directions)

| Type | Init | Replaces |
|------|------|----------|
| `Array<Byte>` | `init<S: Sequence>(_:) where S.Element == UInt8` | `Array(uint8s.map(Byte.init))` |
| `Array<UInt8>` | `init<S: Sequence>(_:) where S.Element == Byte` | `Array(bytes.map(\.underlying))` |

**Naming**: unlabelled per "no labels for bridging where possible".

**Motivating sites**: `Byte.Input(_:)` initializer's UInt8 → Byte staging,
`starts(with:)` body's prefix conversion (after the substrate migration
forced `Prefix.Element == Byte` constraint), arc-introduced
`Swift.Array(bytes.map(Byte.init))` patterns ecosystem-wide.

### 4. Sequence-level eager underlying

| Type | Property | Replaces |
|------|----------|----------|
| `Sequence where Element == Byte` | `var underlying: [UInt8]` | `bytes.map(\.underlying)` |

**Motivating sites**: any byte-sequence consumer that needs a UInt8
buffer (diagnostic output, stdlib API calls, hashing).

### 5. Fallible Byte init

| Type | Init | Semantic |
|------|------|----------|
| `Byte` | `init?(exactly source: some BinaryInteger)` | Returns nil if out-of-range |

**Naming**: `exactly:` is semantic per stdlib convention.

**Motivating sites**: test patterns like `(0..<32).map { Byte(UInt8($0)) }`
(arc α `swift-bit-index-primitives` tests). Cleaner form:
`(0..<32).compactMap(Byte.init(exactly:))`.

### 6. String UTF-8 decoding

| Type | Init | Semantic |
|------|------|----------|
| `String` | `init<S: Sequence>(decoding: S, as: UTF8.Type) where S.Element == Byte` | Mirrors stdlib's `String.init(decoding:as:)` for UInt8 sequences |

**Naming**: `decoding:as:` is semantic per stdlib convention.

**Motivating sites**: diagnostic output, tests interpreting byte streams
as UTF-8. Invalid sequences produce U+FFFD per stdlib semantics.

### 7. Byte-domain Collection trimming + subsequence search (W1, 2026-05-19)

| Receiver | Method | Replaces |
|----------|--------|----------|
| `Swift.Collection where Element: Byte.Protocol & Hashable` | `func trimming(_ byteSet: Set<Element>) -> SubSequence` | UInt8-only path in `swift-binary-primitives/Collection+UInt8.swift`; INCITS_4_1986.ASCII<Source>'s UInt8-element trimming |
| `Swift.Collection where Element: Byte.Protocol & Hashable` | `func trimming(where: (Element) -> Bool) -> SubSequence` | Predicate-form companion |
| `Swift.Collection where Element: Byte.Protocol & Equatable` | `func firstIndex<C>(of needle: C) -> Index? where C.Element == Element` | UInt8-only path in `swift-binary-primitives/Collection+UInt8.swift` |
| `Swift.Collection where Element: Byte.Protocol & Equatable` | `func contains<C>(_ needle: C) -> Bool where C.Element == Element` | Convenience over `firstIndex(of:)` |

**File**: `Collection+Byte.swift`.

**Motivating sites**: rfc-2183 Set-keyed trimming previously had only a
UInt8-element pathway via `INCITS_4_1986.ASCII<Source>`; rfc-2046
`firstIndex(of: subsequence)` was UInt8-keyed in
`swift-binary-primitives`. Lifting both completes the W2/W3 container
retype cascade so consumer packages can retype to Byte/ASCII.Code
without retaining `.underlying` patching at trimming/search call sites.

**Coexistence with stdlib UInt8 path**: per the
byte-protocol-capability-marker discipline, `UInt8` does NOT conform to
`Byte.Protocol`. The two paths fire on disjoint type sets — the BSLI
Byte.Protocol-generic version is for the byte-domain layer; the
swift-binary-primitives UInt8 version remains for stdlib-interop sites.

### 8. BinaryInteger → ASCII decimal digits (W1, 2026-05-19)

| Receiver | Method | Replaces |
|----------|--------|----------|
| `RangeReplaceableCollection where Element: Byte.Protocol` | `mutating func append<I: BinaryInteger>(contentsOf value: I)` | `buffer.append(contentsOf: String(value).utf8)` patterns |

**File**: `Numeric+Byte.swift`.

**Naming**: `@_disfavoredOverload` so the existing byte-domain
`append(contentsOf: Sequence)` overloads continue to win for sequence
sources; this overload fires when `value: some BinaryInteger`.

**Semantics**: writes ASCII decimal digits directly without a `String`
intermediate. Sign and digits accumulate in a single `[UInt8]` buffer;
one boundary call to BSLI's `append(contentsOf:) where S.Element == UInt8`
flushes through to the destination's typed element. `Int.min` / `UInt.max`
handled via `value.magnitude`.

**Motivating sites**: rfc-2183 `RFC_2183.Size.swift` lines 62 + 131
(`buffer.append(contentsOf: String(size.bytes).utf8)`),
serializer-primitives + byte-serializer-primitives literal-serializer
patterns. After this addition, the standard form at consumer sites is
`buffer.append(contentsOf: value)` for `value: some BinaryInteger`.

**Test coverage**: `Tests/Byte Primitives Standard Library Integration
Tests/Numeric+Byte Tests.swift` — zero, positive small, positive large,
negative single-digit, negative multi-digit, UInt32 unsigned, prefix
preservation, UInt64.max (20 digits), Int64.min.

### Array+Byte.swift refactor (W1, 2026-05-19)

**Change**: BSLI inits #1, #2, #3 moved from `extension Array` to
`extension RangeReplaceableCollection`. The bridges now fire uniformly on
`Array`, `ContiguousArray`, `Deque`, and any other
`RangeReplaceableCollection` conformer — least restrictive receiver type
that still composes with `init<S: Sequence>(_:)` via the protocol's
`init()` + `append(contentsOf:)` machinery.

**Additional fix**: BSLI #3 (`init<S>(_:) where Element == UInt8,
S.Element: Byte.Protocol`) gained `@_disfavoredOverload`. Without it,
`Array(arraySliceOfByte)` (no explicit `<Element>`) was ambiguous because
the BSLI candidate proposed `Array<UInt8>` while stdlib proposed
`Array<Byte>` — Element-type inference had two valid answers. With the
disfavored marker, stdlib's same-type path wins for unannotated callers;
explicit-type callers (`Array<UInt8>(bytes)`) continue to resolve via
the BSLI.

**Verification**: 88 tests in swift-byte-primitives pass; 337 tests in
swift-binary-primitives pass; swift-foundations/swift-ascii and
swift-ietf/swift-rfc-3986 (both use `Array<ASCII.Code>(bytes)` consumer
pattern) build clean.

## Explicitly rejected (do not propose)

### Byte arithmetic operators (`+`, `-`, `*`, `/`)

**Why**: Byte is the byte-domain twin of UInt8, NOT the arithmetic type.
Per [byte-protocol-capability-marker.md](../../../swift-institute/Research/byte-protocol-capability-marker.md)
Q1=Option B. Adding arithmetic dissolves the byte-vs-arithmetic identity
separation. Consumers needing arithmetic extract `.underlying`.

### Byte.hex / Byte.binary rendering accessors

**Why**: Explicitly ruled out by `byte-protocol-capability-marker.md`
and `Byte.swift:30–35`:

> "Hex (and other base) rendering is NOT part of Byte. Use the encoder
> packages — `swift-binary-base-primitives` (`Binary.Base.16`) or
> `swift-ietf/swift-rfc-4648` (`RFC_4648.Base16`). L1 String-conversion
> friction is intentional per `[PRIM-FOUND-004]`."

### Foundation-typed bridges (`Data`, `String.Encoding`)

**Why**: byte-primitives is L1 / Foundation-free per `[PRIM-FOUND-001]`.
Foundation bridges live in a Foundation-tier package, NOT BSLI.

## Blocked by Swift-language constraints

Re-attempting these requires a Swift-language change. Do NOT re-derive
without acknowledging the prior result (see the
*Substrate-bridge compromise* section of the original arc handoff).

| Candidate | Block |
|-----------|-------|
| `extension Swift.Span where Element == UInt8 { func reinterpreted() -> Span<Byte> }` | `~Escapable` Span can't escape closures; can't return Span from a function. |
| `extension Swift.Span where Element == Byte { init(_ uint8Span: borrowing Span<UInt8>) }` | Same block — typed rebind cannot fit Span's lifetime model. `unsafeBitCast` requires `Escapable`. `withMemoryRebound` forces nested-closure structure that doesn't compose with `~Escapable` Span returns. |
| Implicit subtyping between `Span<UInt8>` and `Span<Byte>` | Swift has no implicit subtyping; would need a language change. |

The β-1 attempt at full substrate adoption (Byte.Borrowed.span: Span<Byte>)
was reverted because of these blocks. The decision is: substrate at
`Byte.Borrowed.span` stays `Span<UInt8>`; the byte-domain API surface
(`Cursor<Byte>.peek/consume`) wraps `Byte(storage.span[p])` at the
return boundary. The byte-extraction arc continues to live with this
compromise as a load-bearing constraint.

## Sequencing note (2026-05-19)

This BSLI work was landed BEFORE Run.swift's body migration to Byte —
flipped from the handoff's original Issue-1-then-Issue-2 order. The
flip eliminates a two-touch refactor: Run.swift's body can be written
in its final BSLI-using form (e.g., `UInt16(byte)` instead of
`UInt16(byte.underlying)`) from the start, rather than landing with
`.underlying` ceremony and being refactored later.

## `.underlying` triage from the Byte substrate migration arc

Each `.underlying` extraction site that landed during the 2026-05-19
arc, with classification:

| Site | Purpose | Disposition |
|------|---------|-------------|
| Run.swift `.u8: Value.make(advance().underlying)` | `.u8` instruction produces `UInt8` (integer-domain output) | LEAVE — `.u8` is by definition integer; both `.underlying` and `UInt8(byte)` (via Carrier+Byte BSLI) are equivalent |
| Lexer.Classify: `ASCII.Classification.isLetter(byte.underlying)` × 4 | Predicates are `UInt8`-typed in `swift-ascii-primitives` | FOLLOW-UP — ASCII.Classification predicate signatures could migrate to `Byte` (or to `Carrier.Protocol<UInt8>` via the Self-resolving pattern that ASCII constants now use); separate arc |
| Manifest.Parent: `urlBytes.append(first.underlying)` | `urlBytes: [UInt8]` return type | REVISIT — migrate storage to `[Byte]` + return `.underlying` at boundary via BSLI #3 (Q2 follow-up) |
| Byte.Input Tests: `Int(byte.underlying - 0x30)` | ASCII digit decoding — Byte deliberately lacks arithmetic | FOLLOW-UP — see "ASCII-arithmetic ergonomics" section below |
| Error.swift: `String(byte.underlying, radix: 16)` × 3 | Hex rendering for diagnostic output | PERMANENT — stdlib's `String(_:radix:)` requires `BinaryInteger`; Byte hex rendering explicitly excluded per byte-protocol-capability-marker.md |
| Run.swift LEB128: `byte.underlying & 0x7F` (and `& 0x80`, `& 0x40`) | LEB128 bit manipulation | LEAVE — could be `byte & 0x7F` (Byte has bitwise) but surrounding `UInt64(byte)` widening goes through `.underlying` anyway; marginal aesthetic gain |
| Run.swift `.i8: Value.make(Int8(bitPattern: byte))` | `Int8.init(bitPattern: Byte)` is BSLI #1b — no `.underlying` needed | RESOLVED via BSLI |
| Run.swift `.u16le/u32le/...: UInt16(byte) | UInt32(byte) | ...` | `UInt{16,32,64}.init(_ byte: Byte)` is BSLI #1 — no `.underlying` needed | RESOLVED via BSLI |

**ASCII.Classification predicate signatures** — out-of-scope candidate
for follow-up arc. The 4 `byte.underlying` extractions in
`Lexer.Classify.swift` (lines 33, 41, 107, 113) all bridge to
UInt8-typed predicates. A `Carrier.Protocol<UInt8>`-extension pattern
mirroring the ASCII-constants design (Option IV-a) could land Byte-typed
predicates that resolve to the underlying value internally. Estimated
scope: ~10-15 predicate signatures in swift-ascii-primitives' ASCII.Classification.

## Future candidates

Items considered but NOT yet in scope. Surface to principal before
authoring.

| Candidate | Rationale |
|-----------|-----------|
| `Sequence where Element == UInt8 { var asBytes: LazyMapCollection<Self, Byte> }` | Lazy Sequence-level bridge from UInt8 to Byte. Symmetric to Sequence<Byte>.underlying but lazy. Useful for `prefix.asBytes` at boundary sites. |
| `Byte.init(clamping:)` / `Byte.init(truncatingIfNeeded:)` | Stdlib-pattern fallible inits beyond `exactly:`. Useful when callers want lossy conversion. |

## Open friction note: `self.bytes = ...` loop-form dance

Sites doing `[UInt8] → [Byte]` conversion currently take a verbose
loop form:

```swift
var typed: [Byte] = []
typed.reserveCapacity(bytes.count)
for byte in bytes { typed.append(Byte(byte)) }
self.bytes = typed
```

Six instances landed during the Byte substrate migration arc in
`swift-byte-parser-primitives/Sources/Byte Parser Primitives/Byte.Literal.Parser.swift`
(plus `Byte.Input.swift`'s canonical init).

Cleaner forms were tried and bounced off two constraints:

1. **`Swift.Array<Byte>(bytes)` via BSLI #2** — bridges via
   `extension Array { init<S: Sequence>(_:) where Element == Byte, S.Element == UInt8 }`.
   Required `Byte_Primitives_Standard_Library_Integration` import. Tried
   `internal import` — fails because the consumer init is `@inlinable`
   and Swift forbids referencing internal-imported APIs from inlinable
   code. Public import works but adds module visibility cascade for
   downstream consumers.

2. **`bytes.map(Byte.init)`** — function reference ambiguity. BSLI #4
   (`Byte.init?(exactly: some BinaryInteger)`) introduced a second init
   that matches `UInt8 → Byte` (via BinaryInteger). The unqualified
   `Byte.init` reference can't disambiguate between
   `Byte.init(_:UInt8)` (Carrier-required) and `Byte.init?(exactly:)`
   (BSLI #4 fallible).

Resolution paths:

| Option | Mechanism | Tradeoff |
|---|---|---|
| Make BSLI #4 less ambiguous | Rename to `Byte.init?(exactlyChecked:)` or similar | Awkward; departs from stdlib's `exactly:` convention |
| Drop `@inlinable` from the affected init bodies | Removes the import-public requirement | Loses the inlining benefit; may regress perf |
| Public-import BSLI from byte-parser-primitives | Symbol visibility flows through | Adds module visibility cascade and re-export discipline |
| Add a non-BSLI fast-path helper in byte-primitives | e.g., `Byte.init(unchecked:UInt8)` or a free-function bridge | New API for a workaround |
| Use closure-form `.map { Byte($0) }` | Disambiguates because $0's type narrows | Less elegant than `.map(Byte.init)` but works |

**Provenance**: 2026-05-19 substrate migration arc — surfaced as
follow-up to investigate after the substrate migration ships. The
loop-form is acceptable as a stopgap; the dance is the friction worth
removing.

## Open friction note: ASCII-arithmetic ergonomics — RESOLVED 2026-05-19

**Disposition**: settled by `swift-institute/Research/byte-arithmetic-conformance.md`
v1.0.0 RECOMMENDATION ζ (2026-05-19). Byte does NOT gain arithmetic;
the ~38 audit-marked sites across the cohort migrate to `ASCII.Code`'s
existing typed API (`.digitValue: UInt8?` + `.hexValue: UInt8?` +
classification predicates). Migration is W6 of the broader L2/L3
byte-typing gap program.

Original framing retained below for historical record.

---

Sites doing ASCII digit decoding (`value = value * 10 + Int(byte.underlying - 0x30)`)
hit friction because Byte deliberately has no arithmetic (MUST NOT ground
rule per byte-protocol-capability-marker.md Q1=Option B). The ideal form
`value = value * 10 + (byte - 0x30)` requires:

- `byte - 0x30` on Byte → introduces arithmetic on byte-domain types
  (violates the MUST NOT)
- Or a separate ASCII-domain numeric type that conforms to BinaryInteger
  for digit-shape values, with Byte → ASCII-digit conversion at the
  parse boundary

This is a follow-up surfaced 2026-05-19 during Run.swift body migration
in the same arc. Resolution requires re-examining the no-arithmetic-on-Byte
decision OR introducing a separate ASCII-digit numeric type. Not in
current scope; recorded for principal review.
