# Binary Split-Pair Plan (Binary.Parseable + endianness as operation parameter)

> Arc 3.1 — read-only design + planning. Source code edits are scheduled for Arc 3.2.
>
> v0.1 (2026-05-14): initial plan. Convention v1.1.2 [FAM-005] designates the byte-stream sibling pair `Binary.Serializable` + `Binary.Parseable` (NEW) as the next empirical validator. Endianness is a runtime operation parameter via the existing `Binary.Endianness` enum, NOT a sibling-namespace dimension.
>
> **Revision history**:
> - **v2 (2026-05-14, same-session)**: orchestrator caught [FAM-001] violation in Q2's refinement design. v1 designed `Binary.Parseable: Parser_Primitives_Core.Parseable` (refinement). Refining the canonical attachment protocol inherits its `associatedtype Parser`, which [FAM-001] explicitly forbids siblings from carrying — inherited counts. Additionally, replicating `ASCII.Parseable`'s refinement shape replicates the very Arc-4-Φ.1+Φ.3 cleanup target the convention is removing, not duplicating. v2 redesigns `Binary.Parseable` as a **standalone protocol** with a direct `static func parse(...)` requirement, mirroring `Binary.Serializable`'s standalone shape. Q1 (endianness as convenience, no protocol-requirement change) is preserved verbatim. The conformer survey in §2 is unchanged.

## 1. Context

The family-Codable convention v1.1.0/v1.1.2 (`/Users/coen/Developer/swift-foundations/swift-json/Research/family-codable-convention.md`) reached "structurally specified but empirically pending" for byte-stream Codable. §5 (Naming-symmetry rule) and §7 (Future sibling protocols and shape variants) jointly designate:

- **Binary.Serializable** (existing) — half of the split byte-stream sibling pair (`Binary.Serializable.swift:37`).
- **Binary.Parseable** (NEW — to be authored) — symmetric peer, parallel to the existing `ASCII.Parseable`.
- **Binary.Endianness** — runtime parameter (existing enum at `Binary.Endianness.swift:24`), NOT a sibling namespace dimension. The compound name `Binary.LittleEndian.X` is rejected on two grounds: it violates [API-NAME-001] (compound identifier), and it over-models a runtime parameter as a compile-time sibling format. The convention chooses **one mechanism**: runtime via the `Binary.Endianness` enum.

Two architecturally peer-reviewed reframings (Claude peer + ChatGPT) during the v1.1.0 draft converged on this design before [FAM-005] was codified. This plan implements [FAM-005] for the Binary family.

**Reference structural anchors**:
- Convention §5 table at `family-codable-convention.md:321-323` (naming-symmetry across canonical / sibling / nested ranks).
- Convention §7 worked example at `family-codable-convention.md:373-393` (dual-conformance code sketch for `UInt32`).
- Convention §7 endianness-as-parameter rationale at `family-codable-convention.md:395-399`.
- **v2 NOTE**: ASCII peer at `swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:10-18` (`extension ASCII { public protocol Parseable: Parser_Primitives_Core.Parseable {} }`) is **not** the template for Binary.Parseable's shape — it is the Arc-4-Φ.1+Φ.3 cleanup target. v2 mirrors `Binary.Serializable`'s standalone shape instead.
- Canonical parser protocol at `swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:19-25` — carries `associatedtype Parser`; refining it would violate [FAM-001] (inherited associatedtypes count). Binary.Parseable does not refine this protocol.
- Existing endianness-aware FixedWidthInteger primitive at `swift-binary-primitives/Sources/Binary Primitives Core/FixedWidthInteger+Binary.swift:175-243` — `bytes(endianness:)` and `init?(bytes:endianness:)` already provide the leaf-level work; Binary.Parseable's `parse(from:)` default-implementation composes these directly without lifting through an associatedtype.

## 2. Conformer survey (Binary.Serializable, ecosystem-wide)

A grep across `swift-primitives/`, `swift-standards/`, `swift-foundations/` for `: Binary.Serializable` (conformance-site form, excluding `.md`, `Outputs/`, `Research/`, `Audits/`, `HANDOFF`) yields **29 source/test files**. Each conformance is classified by whether endianness is *semantically relevant* (the type encodes a multi-byte word whose byte order can differ) or *semantically irrelevant* (single-byte, byte-array, or string/UTF-8 backed — no multi-byte word to reorder).

### 2.1. Conformances classified

| # | Site (file:line) | Conformer | Endianness relevance | Reason |
|---|---|---|---|---|
| 1 | `swift-primitives/swift-cpu-primitives/Sources/CPU Primitives/CPU.Integrity.Cyclic.Checksum.swift:45` | `CPU.Integrity.Cyclic.Checksum` | **Relevant** | Multi-byte integer-backed (FixedWidthInteger RawValue path; `Binary.Serializable.swift:263` default uses `#if _endian(little)`). |
| 2 | `swift-primitives/swift-cpu-primitives/Sources/CPU Primitives/CPU.Timestamp.swift:64` | `CPU.Timestamp` | **Relevant** | `UInt64` RawValue (FixedWidthInteger default applies). |
| 3 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:263-280` | `where Self: RawRepresentable, RawValue: FixedWidthInteger` (default ext.) | **Relevant** | Where the endianness question lives today; resolved via `#if _endian(little)`. |
| 4 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:283` | `Tagged: Binary.Serializable where Underlying: Binary.Serializable` | **Conditional** | Delegates to underlying — relevance follows the underlying type. |
| 5 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:307` | `Array where Element == UInt8` | Irrelevant | Single-byte elements, raw byte stream. |
| 6 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:327` | `ContiguousArray where Element == UInt8` | Irrelevant | Single-byte. |
| 7 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:347` | `ArraySlice where Element == UInt8` | Irrelevant | Single-byte. |
| 8 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:207` | default ext. `where Self: RawRepresentable, RawValue: StringProtocol` | Irrelevant | UTF-8 bytes (single-byte units; UTF-8 byte order is fixed). |
| 9 | `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:221` | default ext. `where Self: RawRepresentable, RawValue == [UInt8]` | Irrelevant | Byte-array raw value. |
| 10 | `swift-primitives/swift-ascii-serializer-primitives/.../Binary.ASCII.Serializable.swift:8` | `protocol Binary.ASCII.Serializable: Binary.Serializable` | Irrelevant | ASCII refinement is by definition single-byte-per-code-point. |
| 11 | `swift-primitives/swift-base62-primitives/Sources/Base62 Primitives/UInt8.Base62.Serializing.swift:60` | `protocol UInt8.Base62.Serializable: Binary.Serializable` | Irrelevant | Base-62-encoded ASCII output. |
| 12 | `swift-primitives/swift-binary-primitives/Tests/.../Binary.Serializable Tests.swift:16` | `Greeting` (test fixture) | Irrelevant | Test struct; UTF-8/byte-stream fields. |
| 13 | same file, line 29 | `Element` (test fixture) | Irrelevant | Test struct. |
| 14 | same file, line 52 | `Container` (test fixture) | Irrelevant | Test struct. |
| 15 | same file, line 66 | `LargeContent` (test fixture) | Irrelevant | Test struct. |
| 16 | `swift-foundations/swift-ascii/Sources/ASCII/Int+ASCII.Serializable.swift:103` | `Int: @retroactive Binary.Serializable, Binary.ASCII.Serializable` | Irrelevant | ASCII-decimal serialization (`INCITS_4_1986.Numeric.Serialization.serializeDecimal`) — ASCII byte stream, not native bytes. (Documented at `family-codable-convention.md:352` as Φ.3 migration target — canonical pin.) |
| 17 | same file, line 123 | `Int64: @retroactive Binary.Serializable, Binary.ASCII.Serializable` | Irrelevant | Same as above. |
| 18 | same file, line 145 | `UInt: @retroactive Binary.Serializable, Binary.ASCII.Serializable` | Irrelevant | Same as above. |
| 19 | same file, line 165 | `UInt64: @retroactive Binary.Serializable, Binary.ASCII.Serializable` | Irrelevant | Same as above. |
| 20 | `swift-foundations/swift-ascii/Tests/.../UInt8.ASCII.Serializable Tests.swift:365` | `HTMLAnchor` (test fixture) | Irrelevant | ASCII fields. |
| 21 | same file, line 578 | `Document` (test fixture, nested) | Irrelevant | ASCII fields. |
| 22 | `swift-foundations/swift-paths/Sources/Paths/Path.Binary.swift:16` | `Path: Binary.Serializable` | Irrelevant | UTF-8 string body (`path.string.utf8`). |
| 23 | same file, line 40 | `Path.Component: Binary.Serializable` | Irrelevant | UTF-8 string body. |
| 24 | `swift-foundations/swift-file-system/Sources/File System Core/File.Name.swift:310` | `File.Name: Binary.Serializable` | Irrelevant | UTF-8 file-name bytes. |
| 25 | `swift-foundations/swift-file-system/Sources/File System Core/File.System.Metadata.Type.swift:54` | `File.System.Metadata.Kind: Binary.Serializable` | Irrelevant | Single-byte or string-like discriminator. |
| 26 | `swift-foundations/swift-file-system/Sources/File System Core/File.System.Metadata.Permissions.swift:184` | `File.System.Metadata.Permissions` | Conditional | Backed by a small-width integer; if RawValue is UInt8 it's irrelevant; if UInt16/32 it's relevant. (Verify in Arc 3.2; provisional: irrelevant — POSIX modes fit in 16 bits but are commonly serialized as ASCII octal in domain practice.) |
| 27 | `swift-foundations/swift-file-system/Sources/File System Core/File.System.Metadata.Ownership.swift:152` | `File.System.Metadata.Ownership` | Conditional | UID/GID typically UInt32 — provisionally relevant. (Verify in Arc 3.2.) |
| 28 | `swift-foundations/swift-file-system/Sources/File System Core/File.Directory.Entry.Type.swift:49` | `File.Directory.Entry.Kind: Binary.Serializable` | Irrelevant | Discriminator. |
| 29 | `swift-foundations/swift-json/Experiments/double-json-binary-dual-conformance/Sources/Probe/Probe.swift:23` | `Double: @retroactive Binary.Serializable` | **Relevant** | 8-byte IEEE-754 word — endianness applies to bit-pattern serialization (EXP-017's V3 explicitly tested bit-pattern preservation). |

Plus the two `File.System.Write.*` consumers (`File.System.Write.Append.swift:170`, `File.System.Write.Atomic.swift:88`) — these take `<S: Binary.Serializable>` as a generic constraint; they consume the protocol but do not add new conformances. They will inherit whatever signature Q1's choice produces; no per-site rework if Q1 = (C).

### 2.2. Breakdown summary

- **Endianness-relevant** (multi-byte word, byte order semantically meaningful): **4 conformer sites** — CPU.Integrity.Cyclic.Checksum, CPU.Timestamp, Double (experiment), and the FixedWidthInteger RawRepresentable default extension itself. Conditionally add File.System.Metadata.Permissions and File.System.Metadata.Ownership (provisionally 1–2 more).
- **Endianness-irrelevant** (single-byte, byte-array, UTF-8/ASCII string, or test fixture with no multi-byte fields): **~22 conformer sites** out of the 29.
- **Tagged delegation** (conditional, follows underlying): 1 site, conformance applies transitively.
- **Generic consumers** (constrain on the protocol, do not add conformance): 2 sites in File.System.Write.

Ratio: **~14% of sites are endianness-relevant**; the rest are dominated by ASCII/UTF-8 byte streams (which are byte-oriented and have no meaningful byte-order choice) or test fixtures.

## 3. Q1 answer: **(C) Stay at convenience level — protocol requirement unchanged**

**Recommendation: (C).** The protocol requirement on `Binary.Serializable` remains:

```swift
static func serialize<Buffer: RangeReplaceableCollection>(
    _ serializable: Self,
    into buffer: inout Buffer
) where Buffer.Element == UInt8
```

Endianness handling stays at the **leaf level** (the existing `FixedWidthInteger.bytes(endianness:)` API at `FixedWidthInteger+Binary.swift:175-243` is the existing canonical mechanism) and at the **convenience-API level** (a new endianness-aware extension on `Binary.Serializable` that wraps the parameterless requirement, plus the integer-RawValue default extension at `Binary.Serializable.swift:263-280` keeps using `#if _endian(little)` for the parameterless path). New endianness-aware *static convenience overloads* on the protocol provide the explicit-endianness call shape:

```swift
extension Binary.Serializable where Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        endianness: Binary.Endianness,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.rawValue.bytes(endianness: endianness))
    }
}
```

This overload coexists with the requirement; sites that don't pass `endianness:` get the existing `.native` semantics (or `.little`, per `FixedWidthInteger+Binary.swift:175` default).

**One-sentence reasoning**: ~86% of in-ecosystem conformer sites have no semantic notion of byte order (UTF-8 strings, byte arrays, single-byte discriminators), so making `endianness:` a mandatory protocol parameter would force 22+ conformers to accept-and-ignore a meaningless argument — a structural mismatch between the protocol surface and the conformer body. Endianness is a property of *multi-byte primitive encoding*, not of *byte-stream-shaped-conformance-in-general*.

**Why not (A)** (method-level mandatory): forces 25+ sites to add a parameter their bodies cannot meaningfully respect. Violates the §5 sub-format-as-parameter rule's spirit — the rule says endianness *can be* a parameter, not that *every* byte-stream operation *must* expose it. For string-backed and byte-array conformers, the parameter would be pure noise.

**Why not (B)** (method-level optional via default): Swift's protocol-requirement default parameter behavior is fragile. A default-parameter on a protocol-method requirement does not automatically inherit to conformers' implementations; conformers must either match the signature with the default re-stated, or expose the parameter and ignore it. The 22 irrelevant-endianness conformers would either silently break (signature mismatch fails to satisfy the requirement) or be forced to copy a meaningless parameter into every body. Plus, default-arg-in-requirement-position has historically interacted poorly with `@retroactive` conformances (4 sites in `Int+ASCII.Serializable.swift`).

**The structural insight**: endianness already IS an operation parameter at the leaf level (`FixedWidthInteger.bytes(endianness:)`) and at the integer-backed RawRepresentable default extension. The convention §7 text *"endianness is already an operation parameter on integer primitives"* explicitly endorses this layering. The protocol surface does not need to repeat what the leaf already does; it needs to **NOT FOREBID** the leaf from being threaded. Choice (C) preserves the leaf's role and adds explicit-endianness convenience at the protocol-extension layer where it composes.

**Symmetric implication for Q2**: `Binary.Parseable`'s requirement also does NOT take `endianness:`. The protocol requirement `parse(from:)` parses in a canonical endianness chosen by each conformer (typically `.little`); explicit-endianness inits are provided by the FixedWidthInteger-RawValue default extension as convenience APIs, mirroring Q1's structural choice. (v2: in v1 this paragraph cited a `Parser` associatedtype — that is removed; the requirement is a direct static func.)

## 4. Q2 answer: Binary.Parseable design

### 4.1. Protocol declaration — standalone, no refinement

Per [FAM-001/006], `Binary.Parseable` is a **standalone top-level sibling protocol**: it carries **no `associatedtype`** and **no refinement** of any canonical-attachment protocol. It is the structural mirror of `Binary.Serializable` (`Binary.Serializable.swift:36-51`) on the parse side. The substantive content lives in the protocol body directly (one static-func requirement) plus extensions for default implementations.

This deliberately **does not** mirror `ASCII.Parseable`'s current refinement shape (`ASCII.Parseable.swift:17`: `protocol Parseable: Parser_Primitives_Core.Parseable {}`). That refinement is precisely the parser-side defect convention v1.1.2 queues for cleanup via Arc 4 (Φ.1+Φ.3 — `Parser.Protocol` rank-3 split-out + canonical-attachment renames). Introducing a new sibling with the same defect creates a *second* future migration. The corrected sibling pair (`Binary.Serializable` standalone, `Binary.Parseable` standalone) is the convention-aligned shape; `ASCII.Parseable`'s refinement is the migration target, not the template.

```swift
// Binary.Parseable.swift
// Streaming byte deserialization protocol — symmetric peer of Binary.Serializable.

@_spi(Internal) import Tagged_Primitives

extension Binary {
    /// A type that can parse itself from a byte stream.
    ///
    /// Symmetric peer of ``Binary/Serializable``. Siblings are flat top-level
    /// protocols per family-Codable convention [FAM-001/006]: no associated
    /// types, no refinement of canonical-attachment protocols. Where
    /// ``Binary/Serializable`` writes bytes via `serialize(_:into:)`,
    /// `Binary.Parseable` reads bytes via `parse(from:)`.
    ///
    /// ## Symmetry with Binary.Serializable
    ///
    /// A type may conform to both protocols. The serialize side is naturally
    /// infallible (just append bytes); the parse side is naturally fallible
    /// (validate, bounds-check, throw on malformed/insufficient input).
    /// `parse(from:)` advances `source` past consumed bytes on success,
    /// providing cursor semantics atop the same `RangeReplaceableCollection`
    /// substrate `serialize(_:into:)` uses.
    ///
    /// ## Endianness
    ///
    /// Endianness is NOT a parameter on the protocol surface (see [FAM-005]).
    /// Multi-byte-word conformers may either pick a canonical endianness for
    /// the protocol requirement and expose alternates via convenience overloads,
    /// or use endianness-aware convenience inits provided by the integer
    /// RawRepresentable default extension (mirroring the FixedWidthInteger
    /// default extension on `Binary.Serializable`).
    ///
    /// ## Example
    ///
    /// ```swift
    /// extension UInt32: Binary.Parseable {
    ///     public static func parse<Source: RangeReplaceableCollection>(
    ///         from source: inout Source
    ///     ) throws(Binary.Parseable.Failure) -> UInt32
    ///     where Source.Element == UInt8 {
    ///         // canonical little-endian; convenience overloads cover .big
    ///         guard source.count >= 4 else { throw .insufficient(needed: 4) }
    ///         let bytes = Array(source.prefix(4))
    ///         source.removeFirst(4)
    ///         return UInt32(bytes: bytes, endianness: .little)!
    ///     }
    /// }
    ///
    /// var bytes: [UInt8] = [0x78, 0x56, 0x34, 0x12]
    /// let value = try UInt32.parse(from: &bytes) // 0x12345678
    /// // bytes is now empty
    /// ```
    public protocol Parseable: Sendable {
        /// Parses a value from a byte source, consuming the prefix on success.
        ///
        /// On success, `source` is advanced past the bytes consumed by parsing
        /// (cursor semantics via `removeFirst`). On failure, `source` is
        /// unmodified.
        ///
        /// - Parameter source: A byte source. Acts as a cursor: parsing
        ///   consumes bytes from the front.
        /// - Returns: The parsed value.
        /// - Throws: ``Binary/Parseable/Failure`` describing the parse defect.
        static func parse<Source: RangeReplaceableCollection>(
            from source: inout Source
        ) throws(Binary.Parseable.Failure) -> Self
        where Source.Element == UInt8
    }
}
```

### 4.2. Source-type choice: `inout some RangeReplaceableCollection where Element == UInt8`

Two candidate Source types were considered:

| Choice | Pros | Cons |
|---|---|---|
| `inout Span<UInt8>` | Zero-copy borrowed cursor; matches JSON.Coder's `Coder.Protocol` surface. | Non-Copyable cursor type harder to compose; asymmetric with `Binary.Serializable`'s `<Buffer: RangeReplaceableCollection>` parametric shape; cannot drop in to existing `[UInt8]` call sites without conversion. |
| **`inout some RangeReplaceableCollection where Element == UInt8`** (CHOSEN) | **Perfect parametric symmetry with `Binary.Serializable.serialize(_:into:)` — both protocols quantify over the same substrate. Cursor semantics expressed via `removeFirst(_:)`. Drop-in for `[UInt8]`, `ContiguousArray<UInt8>`, `ArraySlice<UInt8>`.** | `removeFirst(_:)` on `Array` is O(n); for hot-path parsing of large buffers a Span-based cursor would be faster. Mitigation: hot-path parsers can still use Binary.Cursor internally and expose a Binary.Parseable wrapper. |

**Choice (reasoning, one sentence)**: `inout some RangeReplaceableCollection where Element == UInt8` is chosen for perfect parametric symmetry with `Binary.Serializable`'s requirement (`Binary.Serializable.swift:46-49`) — Serializable appends to the back, Parseable removes from the front, both quantifying over the same substrate; this keeps the sibling pair structurally aligned at the protocol surface, and hot-path consumers retain `Binary.Cursor`/`Binary.Reader` as zero-copy back-doors.

### 4.3. Failure-type choice: NEW `Binary.Parseable.Failure`

Inspection of `Binary.Parse.Error` (`Binary.Parse.Error.swift:8-16`) reveals it has a **single case** `.end(remaining: Index<UInt8>.Count)` — a *post-condition* check (parsing succeeded but bytes remain). It is NOT designed as a general parse-failure type covering malformed input, insufficient bytes, or out-of-range values. Re-purposing it as the `Binary.Parseable` failure would conflate two roles (post-condition vs. during-parse failure) and force every parse defect into a single `.end(remaining:)` case that doesn't describe them.

Two candidate Failure types:

| Choice | Pros | Cons |
|---|---|---|
| Extend `Binary.Parse.Error` with `.malformed`, `.insufficient(needed:)` | Reuses an existing namespace; one error type for all binary parsing. | Mixes post-condition (`.end`) and during-parse (`.malformed`, `.insufficient`) cases in one type; widens an existing public API for a new purpose. |
| **NEW `Binary.Parseable.Failure`** (CHOSEN) | **Sibling-aligned: `Binary.Parseable.Failure` is the protocol's own typed failure. Keeps `Binary.Parse.Error` focused on whole-buffer post-conditions. Mirrors the convention's "nested operational" rank — failure is operational to the parse op.** | One additional public error type. |

**Choice (reasoning, one sentence)**: introduce `Binary.Parseable.Failure` as a sibling-namespaced typed error covering during-parse defects (`.insufficient`, `.malformed`, `.outOfRange`), leaving `Binary.Parse.Error` to retain its existing role as the whole-buffer post-condition check.

```swift
// Binary.Parseable.Failure.swift
extension Binary.Parseable {
    /// Typed failure for `Binary.Parseable.parse(from:)` implementations.
    public enum Failure: Swift.Error, Sendable, Equatable {
        /// Source had fewer bytes than required.
        case insufficient(needed: Int)
        /// Source bytes were structurally malformed for this type.
        case malformed
        /// Parsed raw value did not initialize a valid instance of `Self`.
        case outOfRange
    }
}
```

### 4.4. Default implementation for FixedWidthInteger RawRepresentable

Mirrors `Binary.Serializable.swift:263-280` on the parse side, but **implements `parse(from:)` directly** — without the v1 plan's refinement of `Parser_Primitives_Core.Parseable`, the default extension cannot lift through any `associatedtype Parser` chain. It composes only with the leaf `FixedWidthInteger.init?(bytes:endianness:)` primitive at `FixedWidthInteger+Binary.swift:232`.

```swift
extension Binary.Parseable where Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    /// Default parse: canonical little-endian read of `MemoryLayout<RawValue>.size` bytes.
    ///
    /// Convenience init `init?(bytes:endianness:)` below covers explicit endianness.
    /// Conformers wanting big-endian as canonical override this static method.
    @inlinable
    public static func parse<Source: RangeReplaceableCollection>(
        from source: inout Source
    ) throws(Binary.Parseable.Failure) -> Self
    where Source.Element == UInt8 {
        let size = MemoryLayout<RawValue>.size
        guard source.count >= size else { throw .insufficient(needed: size) }
        let bytes = Array(source.prefix(size))
        source.removeFirst(size)
        guard let raw = RawValue(bytes: bytes, endianness: .little) else {
            throw .malformed
        }
        guard let value = Self(rawValue: raw) else { throw .outOfRange }
        return value
    }

    /// Endianness-aware convenience init for integer-RawValue parseables.
    ///
    /// Parses exactly `MemoryLayout<RawValue>.size` bytes in the given order.
    /// Returns `nil` if byte count mismatches or the resulting raw value
    /// does not initialize a valid Self.
    @inlinable
    public init?(bytes: [UInt8], endianness: Binary.Endianness = .little) {
        guard let raw = Self.RawValue(bytes: bytes, endianness: endianness) else {
            return nil
        }
        guard let value = Self(rawValue: raw) else {
            return nil
        }
        self = value
    }
}
```

This is the parse-side mirror of `value.bytes(endianness:)` (`FixedWidthInteger+Binary.swift:207`) and `UInt32(bytes:, endianness:)` (`FixedWidthInteger+Binary.swift:232`). The leaf primitive already exists — Binary.Parseable's job is to lift it to the protocol surface and add the cursor-semantic `parse(from:)` requirement-satisfying default.

### 4.5. Sample symmetric conformance (UInt32)

Without an `associatedtype Parser` to satisfy, UInt32's conformance is satisfied entirely by the FixedWidthInteger-RawRepresentable default in §4.4 — except UInt32 is NOT `RawRepresentable` in the stdlib. Conformance requires an explicit `parse(from:)` body:

```swift
// in a new file UInt32+Binary.Parseable.swift

extension UInt32: @retroactive Binary.Parseable {
    /// Canonical little-endian parse for UInt32.
    ///
    /// For big-endian or runtime-selected endianness, callers compose
    /// `UInt32(bytes:endianness:)` with manual cursor advancement.
    public static func parse<Source: RangeReplaceableCollection>(
        from source: inout Source
    ) throws(Binary.Parseable.Failure) -> UInt32
    where Source.Element == UInt8 {
        guard source.count >= 4 else { throw .insufficient(needed: 4) }
        let bytes = Array(source.prefix(4))
        source.removeFirst(4)
        guard let value = UInt32(bytes: bytes, endianness: .little) else {
            throw .malformed
        }
        return value
    }
}
```

Combined with Binary.Serializable (existing `RawRepresentable<FixedWidthInteger>` default at `Binary.Serializable.swift:263`, plus the new endianness overload from Q1), UInt32 has a symmetric two-protocol surface:

```swift
// Round-trip
let original: UInt32 = 0x1234_5678
var buffer: [UInt8] = []
UInt32.serialize(original, into: &buffer)  // existing Binary.Serializable
let decoded = try UInt32.parse(from: &buffer)  // new Binary.Parseable
#expect(decoded == original)
#expect(buffer.isEmpty)  // cursor advanced past all consumed bytes
```

### 4.6. Tagged conformance

Symmetric mirror of `Binary.Serializable.swift:283`. Without the v1 plan's `Parser.Output == Underlying` constraint (no associatedtype now), the Tagged conformance simplifies:

```swift
extension Tagged: Binary.Parseable where Underlying: Binary.Parseable {
    public static func parse<Source: RangeReplaceableCollection>(
        from source: inout Source
    ) throws(Binary.Parseable.Failure) -> Tagged<Tag, Underlying>
    where Source.Element == UInt8 {
        let underlying = try Underlying.parse(from: &source)
        return Tagged(rawValue: underlying)
    }
}
```

This is mechanically simpler than v1's parser-combinator approach — the standalone-protocol shape pays off here.

### 4.7. Byte-collection conformances

Symmetric mirror of `Binary.Serializable.swift:307/327/347`:

```swift
extension Array: Binary.Parseable where Element == UInt8 {
    public static func parse<Source: RangeReplaceableCollection>(
        from source: inout Source
    ) throws(Binary.Parseable.Failure) -> [UInt8]
    where Source.Element == UInt8 {
        let bytes = Array(source)
        source.removeAll(keepingCapacity: false)
        return bytes
    }
}

extension ContiguousArray: Binary.Parseable where Element == UInt8 { ... }
extension ArraySlice: Binary.Parseable where Element == UInt8 { ... }
```

For these, the parser consumes all remaining bytes — there is no internal length-prefix in the wire format, so the conformance is "the rest is mine." Conformers wanting length-prefixed semantics build that at a higher layer.

## 5. Source-change plan (file-by-file blueprint for Arc 3.2)

### 5.1. NEW package target: `Binary Parseable Primitives`

Add a new target to `swift-binary-primitives/Package.swift` (mirrors `Binary Serializable Primitives`). Note: with v2's standalone-protocol design, there is **no longer a dependency on `swift-parser-primitives`** — Binary.Parseable does not refine `Parser_Primitives_Core.Parseable`, so the parser-primitives package is not imported.

```swift
// in Package.swift products:
.library(name: "Binary Parseable Primitives", targets: ["Binary Parseable Primitives"]),

// in Package.swift targets:
.target(
    name: "Binary Parseable Primitives",
    dependencies: [
        "Binary Primitives Core",
        // NO parser-primitives dependency — Binary.Parseable is standalone.
    ]
),

// add to umbrella "Binary Primitives" dependencies:
"Binary Parseable Primitives",
```

No new package-level `.package(path:)` declaration is needed (this is a v1→v2 simplification — v1's plan added `swift-parser-primitives` to support the refinement).

### 5.2. NEW source files

| Path | Purpose |
|---|---|
| `swift-binary-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift` | Protocol declaration — standalone, no refinement, no associatedtype (§4.1). |
| `swift-binary-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.Failure.swift` | NEW typed error: `.insufficient`, `.malformed`, `.outOfRange` (§4.3). |
| `swift-binary-primitives/Sources/Binary Parseable Primitives/Binary.Parseable+FixedWidthIntegerRaw.swift` | Default `parse(from:)` impl for FixedWidthInteger-RawValue conformers + endianness-aware convenience init (§4.4). Implements the protocol requirement directly — no longer lifts through `associatedtype Parser`. |
| `swift-binary-primitives/Sources/Binary Parseable Primitives/Tagged+Binary.Parseable.swift` | Tagged conformance — simplified from v1 (no `Parser.Output == Underlying` constraint needed) (§4.6). |
| `swift-binary-primitives/Sources/Binary Parseable Primitives/Array+Binary.Parseable.swift` | `Array` byte-collection conformance (§4.7). |
| `swift-binary-primitives/Sources/Binary Parseable Primitives/ContiguousArray+Binary.Parseable.swift` | `ContiguousArray` byte-collection conformance (§4.7). |
| `swift-binary-primitives/Sources/Binary Parseable Primitives/ArraySlice+Binary.Parseable.swift` | `ArraySlice` byte-collection conformance (§4.7). |
| `swift-binary-primitives/Tests/Binary Parseable Primitives Tests/Binary.Parseable Tests.swift` | Round-trip tests (§7). |

One-type-per-file per [API-IMPL-005] — protocol declaration in one file; extensions in dedicated files per nest. v2 splits the v1 single `Array+Binary.Parseable.swift` (which contained three extensions) into three per-type files for [API-IMPL-005] compliance.

### 5.3. MODIFIED source files (Q1 = (C); minimal disturbance)

| Path | Change |
|---|---|
| `swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift` | ADD an endianness-aware convenience overload on the `where Self: RawRepresentable, Self.RawValue: FixedWidthInteger` extension (§3 code sample). Existing parameterless `serialize(_:into:)` requirement UNCHANGED. Existing 4 conformer-extension defaults UNCHANGED. |
| `swift-binary-primitives/Package.swift` | Add Binary Parseable Primitives target + product (§5.1). No new external package dep. |

**No other Binary.Serializable conformer site needs modification.** This is the key payoff of Q1 = (C): the 27 other source/test sites continue to compile unchanged. Sites with multi-byte-word semantics (CPU.Integrity.Cyclic.Checksum, CPU.Timestamp, Double) can OPTIONALLY adopt the new endianness-aware overload at their convenience; they are not forced to.

### 5.4. Demonstrator: UInt32 dual conformance

| Path | Purpose |
|---|---|
| `swift-binary-primitives/Sources/Binary Parseable Primitives Standard Library Integration/UInt32+Binary.Parseable.swift` (NEW) | `extension UInt32: @retroactive Binary.Parseable` — implements `parse(from:)` directly (UInt32 is not RawRepresentable in stdlib, so the FixedWidthInteger-RawValue default does not apply) (§4.5). |
| `swift-binary-primitives/Sources/Binary Parseable Primitives Standard Library Integration/UInt16+Binary.Parseable.swift` (NEW, optional second demonstrator) | Same shape, UInt16. |

(These live in a "Standard Library Integration" sub-target — separate from the core protocol target because retroactive conformances on stdlib types are isolated per ecosystem convention.)

### 5.5. Total source files Arc 3.2 will modify or create

- **Create**: 7 new source files in core target (protocol, Failure, FixedWidthInteger-Raw default, Tagged, Array, ContiguousArray, ArraySlice) + 1 new test file + 1 or 2 demonstrator files in stdlib-integration sub-target = **9–10 new files**.
- **Modify**: 2 existing files (`Binary.Serializable.swift` for the convenience overload, `Package.swift` for target wiring) = **2 modified files**.
- **Untouched**: the other 27 conformer/consumer sites.

**Arc 3.2 modifies 2 source files; creates 9–10 new files.** This is the headline number for the verification gate. (v1 said 7–8; the increase reflects (a) the new `Binary.Parseable.Failure.swift` file required by the standalone-protocol shape, and (b) splitting the byte-collection conformances into one-file-per-type per [API-IMPL-005].)

## 6. Risk + rollback

### 6.1. Risks

- **R1 — Standalone-protocol structural shape.** Binary.Parseable is a top-level sibling protocol with no `associatedtype` and no refinement, per [FAM-001/006]. Parallel to Binary.Serializable's existing shape (`Binary.Serializable.swift:36-51`). v1's risk register invoked a rank-1/rank-3 distinction inherited from `Parser_Primitives_Core.Parseable`; v2 retires that distinction because Binary.Parseable no longer refines a canonical-attachment protocol. The Serializable–Parseable pair now sits symmetrically at the sibling level with no inherited associatedtype to manage.
- **R2 — `RangeReplaceableCollection.removeFirst(_:)` cost.** O(n) on `Array` (worst case: shifts the remaining elements). For hot-path parsing of large buffers, this is a known cost of the symmetric `RangeReplaceableCollection` Source choice (§4.2). Mitigation: hot-path consumers retain `Binary.Cursor`/`Binary.Reader` as zero-copy back-doors and can expose a Binary.Parseable wrapper only for the public API. NOT a blocker; documented as a known trade-off.
- **R3 — Default integer-RawValue extension diamond.** The Binary.Serializable side has `where Self: RawRepresentable, Self.RawValue: FixedWidthInteger` (line 263). Adding the parallel default on Binary.Parseable does NOT trigger a diamond because the protocols are independent (no shared requirement). Safe.
- **R4 — Endianness default value drift.** `FixedWidthInteger.bytes(endianness:)` defaults to `.little`; the Binary.Serializable RawValue default uses `#if _endian(little)`; the convention §7 code sketches use `.native`. These three defaults differ. **Arc 3.2 decision required**: pick one default and document. Recommendation: `.little` (matches the existing leaf primitive's choice at `FixedWidthInteger+Binary.swift:175`), with a note that callers needing native-or-network order should be explicit.
- **R5 — `@retroactive` conformances on stdlib types.** `Int`, `Int64`, `UInt`, `UInt64` already have `@retroactive Binary.Serializable` from swift-ascii (`Int+ASCII.Serializable.swift:103/123/145/165`). Adding `@retroactive Binary.Parseable` for `UInt32` (a different integer width, no existing retroactive in this surface) does not collide. If Arc 3.2 chooses to also retroactively conform `Int`/`UInt`/`Int64`/`UInt64`, it must coordinate with swift-ascii's existing extension to avoid retroactive-conformance-conflict diagnostics.
- **R6 — `Binary.Parse.Error` vs `Binary.Parseable.Failure` distinction.** `Binary.Parse.Error` (`Binary.Parse.Error.swift:8-16`) exposes a single `.end(remaining:)` post-condition case — it is NOT a general parse-failure type and was NOT designed as one. v2 introduces a sibling `Binary.Parseable.Failure` for during-parse defects (`.insufficient`, `.malformed`, `.outOfRange`); `Binary.Parse.Error` retains its existing role as the whole-buffer post-condition check. Arc 3.2 must NOT delete or repurpose `Binary.Parse.Error` — it has a distinct, complementary role (callers can compose: `try X.parse(from: &buf)` for during-parse failures, then check `buf.isEmpty` or throw `Binary.Parse.Error.end(remaining:)` for unconsumed-tail).

### 6.2. Rollback

- The new target and protocol are additive. Deleting the `Binary Parseable Primitives` target and the 7–8 new files plus the single convenience overload reverts the workspace to its pre-Arc-3.2 state. No conformer is forced to change; rollback is mechanically clean.

## 7. Test plan

A new test file `Binary.Parseable Tests.swift` covers:

### 7.1. Round-trip identity (per integer width × per endianness)

```swift
@Test("UInt32 round-trip preserves value (little-endian)")
func uint32RoundTripLittleEndian() throws {
    let original: UInt32 = 0x1234_5678
    let bytes = original.bytes(endianness: .little)
    #expect(bytes == [0x78, 0x56, 0x34, 0x12])
    let decoded = try #require(UInt32(bytes: bytes, endianness: .little))
    #expect(decoded == original)
}

@Test("UInt32 round-trip preserves value (big-endian)")
func uint32RoundTripBigEndian() throws {
    let original: UInt32 = 0x1234_5678
    let bytes = original.bytes(endianness: .big)
    #expect(bytes == [0x12, 0x34, 0x56, 0x78])
    let decoded = try #require(UInt32(bytes: bytes, endianness: .big))
    #expect(decoded == original)
}
```

Parameterized across `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Int16`, `Int32`, `Int64`.

### 7.2. Endianness asymmetry assertion

```swift
@Test("UInt32 little- and big-endian byte arrays differ")
func uint32EndiannessDiffers() {
    let v: UInt32 = 0x1234_5678
    let le = v.bytes(endianness: .little)
    let be = v.bytes(endianness: .big)
    #expect(le != be)
    #expect(le.reversed() == be)
}
```

### 7.3. Mismatched-endianness decode is detected

```swift
@Test("Decoding with wrong endianness yields wrong value")
func uint32WrongEndianness() throws {
    let original: UInt32 = 0x1234_5678
    let leBytes = original.bytes(endianness: .little)
    let asBE = try #require(UInt32(bytes: leBytes, endianness: .big))
    #expect(asBE == 0x7856_3412) // byte-reversed interpretation
    #expect(asBE != original)
}
```

### 7.4. Length-mismatch returns nil

```swift
@Test("UInt32 init returns nil on wrong byte count")
func uint32WrongLength() {
    let tooFew: [UInt8] = [0x12, 0x34]
    #expect(UInt32(bytes: tooFew, endianness: .big) == nil)
}
```

### 7.5. Dual-conformance compile gate

A compile-only test that mirrors the swift-json double-json-binary-dual-conformance experiment:

```swift
@Test("UInt32 satisfies both Binary.Serializable and Binary.Parseable")
func uint32DualConformance() {
    func witnessSerializable<T: Binary.Serializable>(_: T.Type) {}
    func witnessParseable<T: Binary.Parseable>(_: T.Type) {}
    witnessSerializable(UInt32.self)
    witnessParseable(UInt32.self)
    // If both witnesses accept UInt32, the dual conformance is structurally sound.
}
```

This is the empirical close-out the convention §"Status of the workspace" references — once it green-lights, Binary.Parseable joins Binary.Serializable as a shipping empirical validator pair.

### 7.6. Validation gates for Arc 3.2

After Arc 3.2 lands, the following must hold:
- `swift build` green in `swift-binary-primitives`.
- `swift test` green in `swift-binary-primitives` (new tests pass; existing tests still pass).
- `swift build` green in the 6 downstream packages that import Binary.Serializable today (swift-cpu-primitives, swift-base62-primitives, swift-ascii-serializer-primitives, swift-ascii, swift-paths, swift-file-system) — Q1 = (C) means no signature change, so this should be a no-op gate.
- The dual-conformance probe in `swift-foundations/swift-json/Experiments/double-json-binary-dual-conformance/` continues to compile.

## 8. Open questions deferred to Arc 3.2

1. **Tagged conformance** — with the standalone-protocol shape (no `Parser.Output` constraint), the Tagged conformance (§4.6) is mechanically simple: `parse` delegates to the underlying type. NOT a deferred question in v2 — this resolves cleanly. (v1 deferred it pending parser-primitives surface investigation; v2's standalone design removes that dependency.)
2. **File.System.Metadata.Permissions / Ownership** — verify RawValue width to settle whether these are endianness-relevant. Cosmetic; does not affect protocol design.
3. **Default-endianness value** — pick one of `.little` / `.native` / explicit-required and document. Recommendation: `.little` (matches leaf primitive's default).
4. **Float / Double** — should Float and Double get first-class Binary.Parseable conformances in this arc, or stay in the Experiments package? Recommendation: stay in Experiments for now (the dual-conformance experiment EXP-017 already covers them); promote when a second consumer needs them.
5. **`Binary.Cursor` integration path** — should a future revision add a `parse(from cursor: inout Binary.Cursor<...>)` overload alongside the `RangeReplaceableCollection` requirement? Defer; not in scope for Arc 3.2. The current shape doesn't preclude it.

## 9. Class-(c) blocker check

No class-(c) ecosystem blocker surfaces in this design.

- Binary.Parseable is a **standalone top-level sibling protocol** with no refinement and no inherited associatedtype, per [FAM-001/006]. It does not interact with `Parser_Primitives_Core`'s rank-1 canonical attachment or rank-3 operational types at all. No collision with parser-primitives surface; no parser-primitives dependency added to the package.
- Binary.Parseable does NOT need `~Copyable` propagation on its requirement signature, because `parse(from:)` is a static method returning `Self` from a borrowed-via-inout source — there is no element-ownership concern at the protocol level (conformers may use ownership-aware leaf primitives internally without surfacing them).
- The existing `Binary.Cursor` and `Binary.Reader` infrastructure (lifetime-dependent borrowing) is available but does NOT need to be threaded through the protocol surface in this arc — hot-path consumers may use those as zero-copy back-doors internally while exposing the Binary.Parseable surface publicly.

Proceed to Arc 3.2 implementation.

---

## Appendix A — File evidence summary (file:line)

- Convention §5 table: `family-codable-convention.md:321-323`
- Convention §7 worked example: `family-codable-convention.md:373-393`
- Convention §7 endianness-as-parameter rationale: `family-codable-convention.md:395-399`
- [FAM-005] codification: `family-codable-convention.md:661`
- Binary.Serializable protocol (template for v2 standalone shape): `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:36-51`
- FixedWidthInteger RawValue default (current `#if _endian` path): `Binary.Serializable.swift:263-280`
- Endianness enum: `swift-primitives/swift-binary-primitives/Sources/Binary Primitives Core/Binary.Endianness.swift:24`
- FixedWidthInteger.bytes(endianness:): `swift-binary-primitives/Sources/Binary Primitives Core/FixedWidthInteger+Binary.swift:175-209`
- FixedWidthInteger.init?(bytes:endianness:): `FixedWidthInteger+Binary.swift:232-243`
- ASCII.Parseable (the Arc-4-Φ.1+Φ.3 cleanup target — NOT a template for v2): `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:10-18`. Its `: Parser_Primitives_Core.Parseable` refinement is the very shape v2 avoids per [FAM-001/006].
- Canonical Parser_Primitives_Core.Parseable (carries `associatedtype Parser` — the [FAM-001]-disallowed inheritance v2 avoids): `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:19-25`
- Binary.Reader / Cursor infrastructure (zero-copy back-door for hot-path consumers): `swift-binary-primitives/Sources/Binary Cursor Primitives/Binary.Reader.swift:42`, `Binary.Cursor.swift:42`
- Binary.Parse.Error (existing whole-buffer post-condition; complementary to v2's new `Binary.Parseable.Failure`): `swift-binary-primitives/Sources/Binary Primitives Core/Binary.Parse.Error.swift:8-16`
