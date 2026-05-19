# W2 Byte Cascade — Structural Issue & Recommended Path

<!--
---
version: 0.1.0
last_updated: 2026-05-19
status: REPORT_FOR_REVIEW
tier: 2
scope: ecosystem-wide
applies_to:
  - swift-binary-primitives
  - swift-ascii-serializer-primitives
  - swift-foundations/swift-file-system
  - swift-foundations/swift-paths
  - swift-foundations/swift-ascii
  - swift-iso/swift-iso-32000
  - swift-ietf/swift-rfc-* (all Binary.Serializable conformers)
depends_on:
  - swift-institute/Research/broader-l2-l3-byte-typing-gap-plan.md
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
companion_to: broader-l2-l3-byte-typing-gap-plan.md (§ Wave 2)
---
-->

## Purpose

Surface a structural issue discovered during W2 cascade execution and recommend a discrimination
criterion for "full UInt8 → Byte" vs. "UInt8 stays where truly appropriate."

## Current state (post-W2 protocol retype, pre-supervisor review)

**Landed (kept)**:

| Repo | Commit | What |
|---|---|---|
| `swift-binary-primitives` | `b121c0e` | `Binary.Serializable.Buffer.Element` and `Binary.Parseable.Source.Element`: `UInt8 → Byte`. In-package test fixtures (Greeting/Element/Container/LargeContent + DualWord) retyped. Stdlib-interop forwarders preserved (`serialize(into:) where Buffer.Element == UInt8`, `[UInt8].init<S: Binary.Serializable>(_:)`, etc.). 337/337 tests pass in 111 suites. |
| `swift-ascii-serializer-primitives` | `06613af` | `Binary.ASCII.Serializable → Binary.Serializable` bridge simplified to direct delegation (both protocols now `Buffer.Element == Byte`). Build clean. |

**Reverted (out of W2 scope)**:

| Repo | Reverted commit | Reason |
|---|---|---|
| `swift-foundations/swift-paths` | `db3de1c` reverts `6e440f9` | Consumer witness retype on `Path` / `Path.Component` — not W2 scope per principal direction. |
| `swift-foundations/swift-file-system` | `040e97b` reverts `c790c1d` | Consumer witness retypes on 5 file-system types (Kind enums + Permissions + Ownership + File.Name) — mass-patching at conformance boundary. |

**Workspace consequence**: every consumer of `Binary.Serializable` currently fails to compile against
the new Byte-typed protocol — `Buffer.Element == UInt8` witness signatures don't satisfy
`Buffer.Element == Byte` requirement. Ecosystem build is broken until consumer witnesses are
adapted.

## Issue — why the cascade is hard

`UInt8` (stdlib) and `Byte` (institute wrapper) are **nominally distinct types**. Swift's type system
won't auto-convert between them. Two consequences:

1. **Sequence-level appends bridge cleanly** via BSLI. The `Byte_Primitives_Standard_Library_Integration`
   extension on `RangeReplaceableCollection where Element: Byte.Protocol` provides
   `append(contentsOf:) where S.Element == UInt8`. This means
   `buffer.append(contentsOf: "str".utf8)` and `buffer.append(contentsOf: rawValue.bytes())` work
   against a `[Byte]` buffer with **no source-side changes**.

2. **Element-level appends do NOT bridge**. There is no BSLI helper
   `append(_ value: UInt8) where Element: Byte.Protocol`, and the `byte-protocol-capability-marker.md`
   discipline forbids adding one — because `UInt8` MUST NOT conform to `Byte.Protocol` (the recipe
   would dissolve the byte-domain identity that motivates the institute twin).

The cascade pain concentrates at conformer types whose **internal storage** is `UInt8` and whose
witness body appends element-by-element from that storage:

```swift
// Pattern A (storage: UInt8, witness body appends single elements)
extension File.Directory.Entry.Kind: Binary.Serializable {
    public static func serialize<Buffer>(
        _ value: Self, into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {  // ← W2 wants this to be Byte
        buffer.append(value.rawValue)   // ← rawValue is UInt8; doesn't satisfy Byte buffer
    }
}

// Pattern B (storage: UInt8 tuple, witness destructures and appends)
extension RFC_791.IPv4.Address: Binary.Serializable {
    public static func serialize<Buffer>(
        _ address: Self, into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {  // ← W2 wants this to be Byte
        let (a, b, c, d) = address.octets  // ← octets is (UInt8, UInt8, UInt8, UInt8)
        buffer.append(a)                   // ← doesn't satisfy Byte buffer
        ...
    }
}
```

**Two paths to fix each Pattern A/B site**:

- **Bridge at the conformance boundary**: wrap with `Byte(value.rawValue)` or `Byte(a)`. This is the
  `.underlying` / `Byte(...)` mass-patching pattern the broader plan's hard rule explicitly forbids.
- **Retype the consumer's storage**: change `rawValue: UInt8` to `rawValue: Byte`, change
  `octets: (UInt8,UInt8,UInt8,UInt8)` to `(Byte,Byte,Byte,Byte)`. The witness body then works
  natively without bridges. This is **W3's nominal job** per `broader-l2-l3-byte-typing-gap-plan.md`
  — but the W3 cohort there enumerates only 6 packages, not the ~50+ workspace consumers actually
  affected.

## The structural inconsistency in the plan

The broader plan asserts:

- **W2 termination**: "ecosystem-wide build gate covers Binary.Serializable consumers"
- **W2→W3 ordering**: strict (W2 lands before W3 begins)
- **W3 cohort**: 6 packages (`swift-iso-32000`, `swift-rfc-7519`, `swift-rfc-4648`,
  `swift-incits-4-1986`, `swift-foundations/swift-ascii`, `swift-ascii-serializer-primitives`)

These three are jointly inconsistent: W2 protocol retype breaks compile for every Pattern A/B
consumer; many of those consumers live OUTSIDE the W3 cohort (e.g., `RFC_791.IPv4.Address`,
`File.Directory.Entry.Kind`, `RFC_768.Port`, etc.). W2 can't satisfy "ecosystem build clean"
without W3 — and W3 as currently scoped doesn't cover the full cascade.

## Recommended path — full UInt8 → Byte, with discriminated exceptions

The principal's leaning: **full UInt8 → Byte, only UInt8 where truly appropriate**.

Below is a discrimination criterion that operationalises this: when to keep a site UInt8 vs. when
to retype to Byte.

### Sites that MUST stay UInt8 (truly appropriate)

| Category | Example | Reason |
|---|---|---|
| **Stdlib boundary types** | `String.UTF8View.Element == UInt8`, `Substring.utf8` | These are stdlib-owned types; not ours to retype. |
| **Stdlib protocol witnesses** | `String(decoding: bytes, as: UTF8.self)` (expects `Sequence<UInt8>`) | Stdlib API signatures consume UInt8 sequences. |
| **`BinaryInteger.bytes(endianness:)`** | `value.bytes(endianness: .big)` returns `[UInt8]` | Inherited from `Standard_Library_Extensions`; arithmetic-domain output. |
| **FFI / C interop** | `read(2)` / `write(2)` syscalls take `UnsafeMutablePointer<UInt8>` | C-language boundary; UInt8 IS the platform byte. |
| **File I/O raw read buffers** | `withUnsafeUTF8Bytes`, `withBytes(_:Span<UInt8>)` | Per the broader plan's stated `.underlying` carve-out. |
| **Test fixtures comparing literal byte arrays** | `#expect(bytes == [0x78, 0x56, 0x34, 0x12])` | Integer literals default to UInt8 here; bridging at the comparison site is acceptable. |
| **Internal helper utilities for stdlib idioms** | `swift-strings/Array.String.Char+PlatformNativeUTF8.appendUTF8(into:)` | Acts on stdlib-flavoured platform-native code units. Not a `Binary.Serializable` witness. |

### Sites that MUST retype to Byte (not truly appropriate as UInt8)

| Category | Example | Reason |
|---|---|---|
| **Binary.Serializable / Binary.Parseable witness signatures** | `where Buffer.Element == UInt8` | W2 protocol surface IS Byte; witnesses MUST match. |
| **Domain-typed enum `rawValue: UInt8`** | `File.Directory.Entry.Kind.rawValue` | The byte IS the domain value (a kind code); should carry byte-domain identity. |
| **Domain-typed struct field `xxx: UInt8`** | `RFC_791.Flags.rawValue: UInt8` | Same reasoning. |
| **Octet tuples representing addresses** | `RFC_791.IPv4.Address.octets: (UInt8,UInt8,UInt8,UInt8)` | Each octet is a byte-domain value. |
| **Opaque byte payloads** | `RFC_7519.JWT.payload: [UInt8]` | JWT bytes are byte-domain opaque content. |
| **`Buffer.Element == UInt8` in any institute Binary.Serializable / Binary.Parseable extension or default impl** | (~50 sites across IETF/ISO/foundations) | All transitively bound to the W2-retyped protocol surface. |
| **Wrappers around byte values** | `Binary.ASCII.Wrapper.bytes: [UInt8]` | Byte-domain wrapper; should expose `[Byte]`. |

### Ambiguous / soft cases (flag for principal call)

| Site | Question |
|---|---|
| `BinaryInteger.bytes(endianness:) -> [UInt8]` | Should this gain a Byte-typed companion `bytes(endianness:) -> [Byte]`, or do consumers always cross the BSLI? |
| `withBytes(_:Span<UInt8>) -> R?` on `File.Name` (zero-copy POSIX access) | Stays UInt8 for POSIX raw bytes, or Byte for byte-domain? |
| Test bodies that read serialized output as `[UInt8]` to assert against literal byte arrays | Convert to `[Byte]` comparisons (uses Byte literals) or keep UInt8? |
| `String(decoding:as:)` inputs in conformer bodies | Stays UInt8 (stdlib idiom) — but the source of those bytes is now a `[Byte]`. Bridge via `.underlying` at one site is OK; multiple sites suggests rethinking. |

## Recommended scope expansion

To honour "full UInt8 → Byte, only UInt8 where truly appropriate" while respecting the broader
plan's hard rule against mass-patching:

1. **Re-classify W2 + W3 as a single coupled cascade.** Drop the W2-must-precede-W3 strict
   ordering. The protocol retype and consumer container retypes are mechanically coupled and
   should land as one cascade per package.

2. **Re-scope W3 from 6 cohort packages to "every consumer of `Binary.Serializable` /
   `Binary.Parseable` with UInt8 storage that doesn't fall under the 'must stay UInt8' criteria
   above"**. Enumeration command:

   ```bash
   # All conformers of Binary.Serializable that fail compile under Byte protocol:
   grep -rln "where Buffer\\.Element == UInt8" \
     swift-primitives/ swift-standards/ swift-foundations/ \
     swift-incits/ swift-iso/ swift-ietf/ \
     2>/dev/null \
     | grep -v "/.build/" \
     | xargs grep -l "Binary\\.Serializable\\|Binary\\.Parseable" \
     2>/dev/null
   ```

   Workspace-wide grep at execution start: **~56 files** carry this pattern. After excluding
   swift-strings/swift-svg-render/swift-json/Sources/JSON/JSON.Encode (different protocol families
   per discrimination) and swift-binary-primitives (intentional `@_disfavoredOverload`
   forwarders), the actual W2+W3 unified cascade is **~35–40 packages**.

3. **Per-consumer treatment plan** (one of):

   a. **Container retype**: `rawValue: UInt8 → Byte`. Witness body works natively. Preferred for
      domain-typed byte values (most cases).

   b. **Two-axis retype**: storage stays UInt8 (e.g., kept for stdlib-interop reasons), but
      witness uses sequence-level BSLI bridges (`buffer.append(contentsOf: rawValue.bytes())`).
      Acceptable when there's a clear "stdlib boundary" justification.

   c. **Drop conformance**: if the consumer is genuinely UInt8-flavoured and doesn't belong in the
      Byte ecosystem, drop the `Binary.Serializable` conformance. Rare.

4. **Acceptance gate**: ecosystem-wide `swift build --build-tests` clean across all transitive
   consumers, AND workspace-wide grep showing zero residual `Buffer.Element == UInt8` outside the
   discriminated "must stay UInt8" exceptions.

## Open questions for supervisor

1. **Is the "must stay UInt8" criteria above complete?** Specifically, the ambiguous cases (test
   literal byte arrays, `bytes(endianness:)`, zero-copy `withBytes(_:Span<UInt8>)`).

2. **Plan reshape**: bundle W2 + W3 into a single unified cascade (recommended), or keep them
   separate with W2 stamped as "protocol-only, build-broken intentionally"?

3. **W3 cohort scope**: extend from 6 named packages to ~35–40 actual cascade affected packages?

4. **BSLI helper question**: should `BinaryInteger.bytes(endianness:)` gain a Byte-typed
   companion `bytes(endianness:) -> [Byte]`? This would eliminate the BSLI bridge at every
   integer-RawValue Binary.Serializable conformer.

5. **`@_disfavoredOverload` UInt8 forwarder scope**: which of these should remain on the
   `Binary.Serializable` extension surface, and which should be dropped?
   - `serialize(into:) where Buffer.Element == UInt8` (KEEP — stdlib interop is broad)
   - `Array.init<S: Binary.Serializable>(_:) where Element == UInt8` (KEEP — same)
   - `ContiguousArray.init<S: Binary.Serializable>(_:) where Element == UInt8` (KEEP — same)
   - `RangeReplaceableCollection<UInt8>.append(_ S: Binary.Serializable)` (KEEP — same)

## References

- `swift-institute/Research/broader-l2-l3-byte-typing-gap-plan.md` (the W1–W6 program)
- `swift-institute/Research/byte-protocol-capability-marker.md` (capability-marker recipe; explains
  why `UInt8` cannot conform to `Byte.Protocol`)
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` (Byte type identity)
- Parent arc: `swift-ascii-serializer-primitives@6755cd6` (the ASCII-domain retyping precedent)

## Changelog

- **v0.1.0 (2026-05-19)** — Initial report. Surfaces W2 cascade structural issue, proposes
  discrimination criterion, recommends W2+W3 unification.
