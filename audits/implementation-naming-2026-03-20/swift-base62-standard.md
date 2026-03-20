# swift-base62-standard — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming [API-NAME-*], implementation [IMPL-*]
**Package**: swift-base62-standard (Base62 Standard)
**Files audited**: 14

## Summary Table

| ID | Severity | Requirement | File | Title |
|----|----------|-------------|------|-------|
| B62-001 | HIGH | API-NAME-001 | Base62_Standard.IntegerWrapper.swift | Compound type name `IntegerWrapper` |
| B62-002 | HIGH | API-NAME-001 | Base62_Standard.StringWrapper.swift | Compound type name `StringWrapper` |
| B62-003 | HIGH | API-NAME-001 | Base62_Standard.CollectionWrapper.swift | Compound type name `CollectionWrapper` |
| B62-004 | MEDIUM | API-NAME-002 | Base62_Standard.IntegerWrapper.swift | Compound method `encodedBytes()` |
| B62-005 | MEDIUM | API-NAME-002 | Base62_Standard.CollectionWrapper.swift | Compound method `encodedBytes()` |
| B62-006 | MEDIUM | API-NAME-002 | Base62_Standard.StringWrapper.swift | Compound method `decodeBytes()` |
| B62-007 | MEDIUM | API-NAME-002 | UInt8.ASCII+Base62.swift | Compound method name `isBase62Digit(_:using:)` |
| B62-008 | MEDIUM | API-NAME-002 | BinaryInteger+Base62.swift | Compound initializer label `base62Encoded` |
| B62-009 | LOW | API-NAME-002 | Base62_Standard.Alphabet.swift | Compound property names `encodeTable`, `decodeTable` |
| B62-010 | LOW | API-NAME-002 | Base62_Standard.Encoding.swift | Compound local variable names in algorithm |
| B62-011 | LOW | API-IMPL-005 | UInt8.Base62.Serializing.swift | Multiple types, protocols, and extension blocks in one file |
| B62-012 | LOW | IMPL-INTENT | Base62_Standard.Encoding.swift | BigInt division loop reads as mechanism, not intent |
| B62-013 | LOW | IMPL-INTENT | Base62_Standard.Decoding.swift | BigInt multiplication loop reads as mechanism, not intent |
| B62-014 | INFO | API-NAME-001 | UInt8.Base62.Serializing.swift | `Serializable` protocol nested under `UInt8.Base62` — correct Nest.Name |
| B62-015 | INFO | API-NAME-001 | Base62_Standard.Alphabet.swift | `Alphabet` nested under `Base62_Standard` — correct Nest.Name |
| B62-016 | INFO | API-NAME-001 | Base62_Standard.Error.swift | `Error` nested under `Base62_Standard` — correct Nest.Name |

---

## Findings

### Finding [B62-001]: Compound type name `IntegerWrapper`
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: Base62_Standard.IntegerWrapper.swift:24
- **Current**: `public struct IntegerWrapper<T: BinaryInteger>`
- **Proposed**: Rename to `Base62_Standard.Integer<T>` — the nesting already provides the "wrapper" context. The type wraps an integer for Base62 operations; `Integer` nested under `Base62_Standard` makes this clear. Alternative: `Base62_Standard.Encoded<T>` with a constraint, though `Integer` mirrors the domain better.
- **Rationale**: [API-NAME-001] forbids compound type names. `IntegerWrapper` is two words fused. The Nest.Name pattern `Base62_Standard.Integer` communicates "the integer facet of Base62" without compounding.

### Finding [B62-002]: Compound type name `StringWrapper`
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: Base62_Standard.StringWrapper.swift:35
- **Current**: `public struct StringWrapper<S: StringProtocol>`
- **Proposed**: Rename to `Base62_Standard.Source<S>` or `Base62_Standard.Validator<S>`. The wrapper's primary purpose is validation and decoding of an already-encoded string, so `Source` or `Validator` captures intent. `String` would shadow `Swift.String`.
- **Rationale**: [API-NAME-001] forbids compound type names. `StringWrapper` is two words fused.

### Finding [B62-003]: Compound type name `CollectionWrapper`
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: Base62_Standard.CollectionWrapper.swift:29
- **Current**: `public struct CollectionWrapper<Source: Collection> where Source.Element == UInt8`
- **Proposed**: Rename to `Base62_Standard.Bytes<Source>`. The wrapper operates on byte collections; `Bytes` nested under `Base62_Standard` communicates "the byte-collection facet of Base62" without compounding. Alternative: `Base62_Standard.Buffer<Source>`.
- **Rationale**: [API-NAME-001] forbids compound type names. `CollectionWrapper` is two words fused.

### Finding [B62-004]: Compound method `encodedBytes()`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Base62_Standard.IntegerWrapper.swift:58
- **Current**: `public func encodedBytes() -> [UInt8]`
- **Proposed**: Use nested accessor pattern: `encoded.bytes` or simply `bytes`. Since `encoded()` already returns a `String`, a sibling `.bytes` property or an `encoded.bytes` accessor would avoid the compound method name.
- **Rationale**: [API-NAME-002] forbids compound method names. `encodedBytes` fuses two concepts.

### Finding [B62-005]: Compound method `encodedBytes()` on CollectionWrapper
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Base62_Standard.CollectionWrapper.swift:62
- **Current**: `public func encodedBytes() -> [UInt8]`
- **Proposed**: Same as B62-004. Use `encoded.bytes` or a `bytes` property.
- **Rationale**: Same as B62-004.

### Finding [B62-006]: Compound method `decodeBytes()`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Base62_Standard.StringWrapper.swift:92
- **Current**: `public func decodeBytes() -> [UInt8]?`
- **Proposed**: Rename to `decoded()` returning `[UInt8]?` (matching `CollectionWrapper.decoded()`), or use nested accessor `decode.bytes`.
- **Rationale**: [API-NAME-002] forbids compound method names. `decodeBytes` fuses two concepts.

### Finding [B62-007]: Compound method `isBase62Digit(_:using:)`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: UInt8.ASCII+Base62.swift:85
- **Current**: `public static func isBase62Digit(_ byte: UInt8, using alphabet: ...) -> Bool`
- **Proposed**: This follows established `Binary.ASCII` patterns (`isHexDigit`, etc.). If those patterns are being updated to nested accessors, this should follow. However, if `isHexDigit` etc. are grandfathered, this is consistent. Flagging for awareness.
- **Rationale**: [API-NAME-002] compound method name. `isBase62Digit` fuses three words. However, this mirrors stdlib-adjacent patterns (`isASCII`, `isHexDigit`), so severity is contextual.

### Finding [B62-008]: Compound initializer label `base62Encoded`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: BinaryInteger+Base62.swift:59, 72
- **Current**: `init?(base62Encoded string: ...)` and `init?(base62Encoded bytes: ...)`
- **Proposed**: Simplify to `init?(base62: ...)`. The `Encoded` suffix is redundant — the initializer argument is the encoded form, which is the natural reading. `UInt64(base62: "g")` reads cleanly.
- **Rationale**: [API-NAME-002] compound argument labels. The label `base62Encoded` fuses two concepts. Compare with existing `init?(base62:)` pattern on `[UInt8]` in Collection+Base62.swift which is already compliant.

### Finding [B62-009]: Compound property names `encodeTable`, `decodeTable`
- **Severity**: LOW
- **Requirement**: [API-NAME-002]
- **Location**: Base62_Standard.Alphabet.swift:37-40
- **Current**: `public let encodeTable: [UInt8]` and `public let decodeTable: [UInt8]`
- **Proposed**: Use nested accessor pattern: `table.encode` / `table.decode`, or simply `encoder` / `decoder` as nouns describing the table's role.
- **Rationale**: [API-NAME-002] compound property names. These are internal-facing (users access `encode(_:)` / `decode(_:)` methods), so the impact is low.

### Finding [B62-010]: Compound local variable names in encoding/decoding algorithms
- **Severity**: LOW
- **Requirement**: [API-NAME-002]
- **Location**: Base62_Standard.Encoding.swift:91 (`leadingZeros`), :101 (`startIndex`), :106 (`newStartIndex`); Base62_Standard.Decoding.swift:133 (`leadingZeros`)
- **Current**: `let leadingZeros = ...`, `var startIndex = 0`, `var newStartIndex = ...`
- **Proposed**: Local variables in algorithmic code are conventionally allowed more latitude. `startIndex` mirrors `Collection.startIndex`. These are informational only.
- **Rationale**: [API-NAME-002] technically applies to all identifiers, but compound local variable names in algorithmic contexts are low-impact. Flagging for completeness.

### Finding [B62-011]: Multiple types and extension blocks in UInt8.Base62.Serializing.swift
- **Severity**: LOW
- **Requirement**: [API-IMPL-005]
- **Location**: UInt8.Base62.Serializing.swift (entire file, 323 lines)
- **Current**: The file contains:
  - `UInt8.Base62` enum (namespace, line 14)
  - `UInt8.Base62.Serializable` protocol (line 65)
  - `UInt8.Base62.RawRepresentable` protocol (line 119)
  - `UInt8.Base62.Wrapper` struct (line 346)
  - 15+ extension blocks providing default implementations, conformances, and convenience methods
- **Proposed**: Split into separate files:
  - `UInt8.Base62.swift` — namespace enum
  - `UInt8.Base62.Serializable.swift` — protocol + core defaults
  - `UInt8.Base62.RawRepresentable.swift` — marker protocol + defaults
  - `UInt8.Base62.Wrapper.swift` — wrapper struct + methods
  - `Array+UInt8.Base62.swift` — Array convenience initializer
  - `StringProtocol+UInt8.Base62.swift` — string conversion
  - `RangeReplaceableCollection+UInt8.Base62.swift` — append method
- **Rationale**: [API-IMPL-005] requires one type per file. This file defines 4 types/protocols and mixes concerns. The current file is the densest in the package.

### Finding [B62-012]: BigInt division loop reads as mechanism
- **Severity**: LOW
- **Requirement**: [IMPL-INTENT]
- **Location**: Base62_Standard.Encoding.swift:104-121
- **Current**: The inner loop performs big-integer division with manual index bookkeeping. Variables like `startIndex`, `newStartIndex`, `remainder` expose the mechanism of schoolbook division rather than expressing encoding intent.
- **Proposed**: Extract the division loop into a named helper: `divideByBase(_ source: inout [UInt8], startingAt: Int) -> (remainder: UInt8, newStart: Int)`. The encoding function would then read as: "while digits remain, extract the next base-62 digit."
- **Rationale**: [IMPL-INTENT] requires code to read as intent. The current implementation is correct and well-commented, but the loop body mixes index tracking with arithmetic in a way that requires careful reading.

### Finding [B62-013]: BigInt multiplication loop reads as mechanism
- **Severity**: LOW
- **Requirement**: [IMPL-INTENT]
- **Location**: Base62_Standard.Decoding.swift:142-158
- **Current**: The inner loop performs big-integer multiplication with manual carry propagation. Same class of concern as B62-012.
- **Proposed**: Extract into a named helper: `multiplyAndAdd(_ result: inout [UInt8], by: UInt, adding: UInt)`. The decoding function would then read: "for each digit, multiply accumulated result by base and add the digit value."
- **Rationale**: [IMPL-INTENT] requires code to read as intent. Same rationale as B62-012.

### Finding [B62-014]: Correct nesting — `UInt8.Base62.Serializable`
- **Severity**: INFO (positive)
- **Requirement**: [API-NAME-001]
- **Location**: UInt8.Base62.Serializing.swift:65
- **Current**: `public protocol Serializable: Binary.Serializable` nested under `UInt8.Base62`
- **Assessment**: Correct use of Nest.Name pattern. `UInt8.Base62.Serializable` reads as "the serializable protocol within the Base62 namespace within UInt8." No compound names.

### Finding [B62-015]: Correct nesting — `Base62_Standard.Alphabet`
- **Severity**: INFO (positive)
- **Requirement**: [API-NAME-001]
- **Location**: Base62_Standard.Alphabet.swift:35
- **Current**: `public struct Alphabet: Sendable, Hashable` nested under `Base62_Standard`
- **Assessment**: Correct Nest.Name pattern.

### Finding [B62-016]: Correct nesting — `Base62_Standard.Error`
- **Severity**: INFO (positive)
- **Requirement**: [API-NAME-001]
- **Location**: Base62_Standard.Error.swift:10
- **Current**: `public enum Error: Swift.Error, Sendable, Equatable` nested under `Base62_Standard`
- **Assessment**: Correct Nest.Name pattern.

---

## Statistical Summary

| Severity | Count |
|----------|-------|
| HIGH | 3 |
| MEDIUM | 5 |
| LOW | 5 |
| INFO | 3 |
| **Total** | **16** |

## Priority Remediation

1. **B62-001, B62-002, B62-003** (HIGH): Rename the three wrapper types. These are the most visible API-NAME-001 violations and affect the public type namespace. Suggested names: `Base62_Standard.Integer`, `Base62_Standard.Source` (or `Validator`), `Base62_Standard.Bytes`.
2. **B62-008** (MEDIUM): Simplify `init?(base62Encoded:)` to `init?(base62:)` — aligns with existing `[UInt8](base62:)` pattern in the same package.
3. **B62-004, B62-005, B62-006** (MEDIUM): Address compound method names `encodedBytes()` and `decodeBytes()`.
4. **B62-011** (LOW): Split UInt8.Base62.Serializing.swift into per-type files.
