# swift-binary-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming [API-NAME-*], implementation [IMPL-*]
**Package**: swift-binary-primitives (Binary Primitives Core, Binary Format Primitives, Binary Serializable Primitives)
**Files audited**: 54

## Summary Table

| ID | Severity | Requirement | File | Title |
|----|----------|-------------|------|-------|
| BIN-001 | HIGH | IMPL-010 | Binary.Cursor.swift | 30 Int(bitPattern:) calls at non-boundary call sites |
| BIN-002 | HIGH | PATTERN-017 | Binary.Cursor.swift | 4 .rawValue.rawValue chains for offset extraction |
| BIN-003 | HIGH | IMPL-010 | Binary.Reader.swift | 14 Int(bitPattern:) calls at non-boundary call sites |
| BIN-004 | HIGH | PATTERN-017 | Binary.Reader.swift | 2 .rawValue.rawValue chains for offset extraction |
| BIN-005 | MEDIUM | PATTERN-021 | Tagged+Bitwise.swift | 26 Tagged(__unchecked:) constructions instead of .map/.retag |
| BIN-006 | MEDIUM | API-NAME-002 | Binary.Cursor.swift | Compound method names: moveReaderIndex, moveWriterIndex, setReaderIndex, setWriterIndex |
| BIN-007 | MEDIUM | API-NAME-002 | Binary.Reader.swift | Compound method names: moveReaderIndex, setReaderIndex |
| BIN-008 | MEDIUM | API-NAME-002 | Binary.Cursor.swift | Compound property names: readableCount, writableCount, readableBytes, withReadableBytes |
| BIN-009 | MEDIUM | API-NAME-002 | Binary.Reader.swift | Compound property names: remainingCount, remainingBytes, withRemainingBytes |
| BIN-010 | MEDIUM | API-NAME-002 | FixedWidthInteger+Binary.swift | Compound method names: rotateLeft, rotateRight, reverseBits |
| BIN-011 | MEDIUM | API-NAME-002 | Memory.Alignment+Binary.Position.swift | Compound method names: isAlignedThrowing, alignUpThrowing, alignDownThrowing |
| BIN-012 | MEDIUM | API-NAME-002 | Binary.Format.Bytes.swift | Compound method names: selectUnit, formatNumber, formatWithPrecision, stripTrailingZeros, withoutUnit |
| BIN-013 | MEDIUM | API-NAME-002 | Binary.Format.Radix.swift | Compound method name: zeroPadded |
| BIN-014 | LOW | PATTERN-017 | Memory.Alignment+Binary.Position.swift | .rawValue extraction in alignment arithmetic |
| BIN-015 | LOW | PATTERN-017 | Binary.Pattern.swift | .rawValue extraction in mask bitwise operators |
| BIN-016 | LOW | PATTERN-017 | Binary.Mask.swift | .rawValue extraction in Comparable conformance |
| BIN-017 | LOW | IMPL-INTENT | Binary.Cursor.swift | Ordinal/Cardinal conversion boilerplate obscures intent |
| BIN-018 | LOW | API-NAME-002 | Binary.Serializable.swift | Compound method name: withSerializedBytes |
| BIN-019 | LOW | API-NAME-002 | Binary.Format.Bytes.Notation.swift | Compound case name: compactName |
| BIN-020 | LOW | API-NAME-002 | Collection+UInt8.swift | Compound variable name: lastNonTrimIndex |
| BIN-021 | LOW | API-IMPL-005 | Binary.Serializable.swift | Multiple extension blocks + conformances in one file |

---

## Findings

### Finding [BIN-001]: Int(bitPattern:) at non-boundary call sites in Binary.Cursor
- **Severity**: HIGH
- **Requirement**: [IMPL-010]
- **Location**: Binary.Cursor.swift:118-119, 128-130, 181-182, 190-191, 219-220, 265-266, 286-288, 333-335, 355-356, 382-383, 400-402, 439-441, 469-470
- **Current**: `let currentReader = Int(bitPattern: _readerIndex)` (30 occurrences across the file)
- **Proposed**: Add typed arithmetic overloads to `Index<T>` / `Index<T>.Count` / `Index<T>.Offset` that internalize the conversion, or add a computed `intValue` property. All `Int(bitPattern:)` calls should be confined to those boundary overloads.
- **Rationale**: [IMPL-010] requires `Int(bitPattern:)` only in boundary overloads, never at call sites. These are internal implementation sites but every method in Cursor performs the same pattern of extracting an Int from a typed index to do arithmetic, then wrapping the result back. This is mechanism, not intent.

### Finding [BIN-002]: .rawValue.rawValue chains for offset extraction in Binary.Cursor
- **Severity**: HIGH
- **Requirement**: [PATTERN-017]
- **Location**: Binary.Cursor.swift:221, 267, 289, 336
- **Current**: `let offsetValue = offset.rawValue.rawValue`
- **Proposed**: Add a boundary accessor like `var intValue: Int` on `Index<T>.Offset` that performs the double-unwrap once, or add typed arithmetic (`Index + Offset -> Index`) that eliminates the need to unwrap at all.
- **Rationale**: [PATTERN-017] confines `.rawValue` to boundary code. A double `.rawValue.rawValue` chain indicates the type system's domain-crossing layers are being manually unwrapped at every call site rather than through functor operations or typed arithmetic.

### Finding [BIN-003]: Int(bitPattern:) at non-boundary call sites in Binary.Reader
- **Severity**: HIGH
- **Requirement**: [IMPL-010]
- **Location**: Binary.Reader.swift:104, 106, 153-154, 182-183, 229-230, 250-251, 278-279, 306-307
- **Current**: `let currentReader = Int(bitPattern: _readerIndex)` (14 occurrences)
- **Proposed**: Same as BIN-001 -- add typed arithmetic overloads or boundary accessors to `Index<T>`.
- **Rationale**: Same as BIN-001. Reader duplicates the same pattern as Cursor.

### Finding [BIN-004]: .rawValue.rawValue chains for offset extraction in Binary.Reader
- **Severity**: HIGH
- **Requirement**: [PATTERN-017]
- **Location**: Binary.Reader.swift:184, 231
- **Current**: `let offsetValue = offset.rawValue.rawValue`
- **Proposed**: Same as BIN-002.
- **Rationale**: Same as BIN-002.

### Finding [BIN-005]: Tagged(__unchecked:) constructions in Tagged+Bitwise.swift
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-021], [IMPL-003]
- **Location**: Tagged+Bitwise.swift:26, 35, 44, 55, 64, 73, 84, 93, 102, 123, 132, 143, 152, 167, 176 (26 occurrences total including compound assignment delegations)
- **Current**: `Tagged(__unchecked: (), lhs.rawValue & rhs.rawValue)`
- **Proposed**: Use `.map { $0 & rhs.rawValue }` or define typed bitwise operators on Tagged that delegate through `.map` (note: `~` already uses `.map` at line 112).
- **Rationale**: [IMPL-003] prefers functor ops (`.map`/`.retag`) for domain crossing over `__unchecked`. The `~` operator already uses `.map { ~$0 }` correctly. The binary operators should follow the same pattern: `lhs.map { $0 & rhs.rawValue }`. However, this is marked MEDIUM rather than HIGH because bitwise boundary overloads are a legitimate use of `__unchecked` -- the concern is consistency, not correctness.

### Finding [BIN-006]: Compound method names in Binary.Cursor
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Cursor.swift:216, 261, 283, 329, 352, 378, 397, 435
- **Current**:
  - `moveReaderIndex(by:)` / `moveWriterIndex(by:)`
  - `setReaderIndex(to:)` / `setWriterIndex(to:)`
- **Proposed**: Use nested accessor pattern:
  - `cursor.reader.move(by:)` / `cursor.writer.move(by:)`
  - `cursor.reader.set(to:)` / `cursor.writer.set(to:)`
  Or use the `_modify`-based verb-as-property pattern for `reader` and `writer` views.
- **Rationale**: [API-NAME-002] forbids compound method names. `moveReaderIndex` is a compound of move + reader + index. The nested accessor pattern (`cursor.reader.move(by:)`) decomposes this into single-concept names.

### Finding [BIN-007]: Compound method names in Binary.Reader
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Reader.swift:179, 225, 247, 274
- **Current**: `moveReaderIndex(by:)`, `setReaderIndex(to:)`
- **Proposed**: `reader.move(by:)`, `reader.set(to:)` or since Reader only has one index, simply `move(by:)` and `set(to:)`.
- **Rationale**: Same as BIN-006.

### Finding [BIN-008]: Compound property names in Binary.Cursor
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Cursor.swift:179, 188, 466, 480
- **Current**: `readableCount`, `writableCount`, `readableBytes`, `withReadableBytes`
- **Proposed**: `readable.count`, `writable.count`, `readable.bytes` (using nested view types or Property.View pattern).
- **Rationale**: [API-NAME-002] forbids compound property names. Each of these joins an adjective (readable/writable) with a noun (count/bytes).

### Finding [BIN-009]: Compound property names in Binary.Reader
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Reader.swift:151, 303, 317
- **Current**: `remainingCount`, `remainingBytes`, `withRemainingBytes`
- **Proposed**: `remaining.count`, `remaining.bytes` (using a nested view type or Property.View pattern).
- **Rationale**: Same as BIN-008.

### Finding [BIN-010]: Compound method names in FixedWidthInteger+Binary.swift
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: FixedWidthInteger+Binary.swift:26, 50, 73, 97, 117, 145
- **Current**: `rotateLeft(by:)`, `rotateRight(by:)`, `reverseBits()`
- **Proposed**:
  - `rotate.left(by:)` / `rotate.right(by:)` using a nested accessor
  - `bits.reversed()` or `reverse.bits()` using a nested accessor
- **Rationale**: [API-NAME-002] forbids compound method names. `rotateLeft` compounds a verb (rotate) with a direction (left).

### Finding [BIN-011]: Compound method names in Memory.Alignment+Binary.Position.swift
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Memory.Alignment+Binary.Position.swift:50, 63, 76
- **Current**: `isAlignedThrowing(_:)`, `alignUpThrowing(_:)`, `alignDownThrowing(_:)`
- **Proposed**: The non-throwing versions (`isAligned`, `alignUp`, `alignDown`) are already compound. The `Throwing` suffix makes them triple-compound. Consider: `align.up(_:)` / `align.down(_:)` with throwing vs non-throwing overloads distinguished by the `throws(E)` signature rather than name suffix.
- **Rationale**: [API-NAME-002] forbids compound method names. Adding `Throwing` as a suffix to distinguish error handling from preconditions is mechanism leaking into the name. Swift's type system (typed throws) should distinguish these overloads, not the method name.

### Finding [BIN-012]: Compound internal method names in Binary.Format.Bytes.swift
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Format.Bytes.swift:121, 159, 196, 213, 247
- **Current**: `withoutUnit()`, `selectUnit(for:)`, `formatNumber(_:)`, `formatWithPrecision(_:precision:)`, `stripTrailingZeros(_:)`
- **Proposed**:
  - `withoutUnit()` -> `unit.hidden()` or `excluding(.unit)`
  - `selectUnit(for:)` -> `unit(for:)` (internal)
  - `formatNumber(_:)` -> `format(number:)` (internal)
  - `formatWithPrecision(_:precision:)` -> `format(_:precision:)` (internal)
  - `stripTrailingZeros(_:)` -> `strip(trailingZeros:)` (internal)
- **Rationale**: [API-NAME-002] applies to internal methods too. `formatWithPrecision` is a four-word compound.

### Finding [BIN-013]: Compound method name zeroPadded in Binary.Format.Radix.swift
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Format.Radix.swift:247
- **Current**: `zeroPadded(width:)`
- **Proposed**: `padded(zeros:)` or `padding(.zeros, width:)`
- **Rationale**: [API-NAME-002] forbids compound method names. `zeroPadded` compounds "zero" with "padded".

### Finding [BIN-014]: .rawValue extraction in alignment arithmetic
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Memory.Alignment+Binary.Position.swift:16, 28, 40, 57, 70, 83
- **Current**: `value.rawValue & mask == 0`, `Binary.Position((value.rawValue &+ mask) & ~mask)`
- **Proposed**: Add typed bitwise operators to `Binary.Position` that internalize the rawValue access (e.g., `value & mask` and `value.aligned(up: mask)`).
- **Rationale**: [PATTERN-017] confines `.rawValue` to boundary code. These are boundary-adjacent (implementing alignment as typed operations on positions), but the `.rawValue` extraction could be internalized into typed operators.

### Finding [BIN-015]: .rawValue extraction in mask bitwise operators
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Binary.Pattern.swift:121, 127, 133, 139, 149, 155
- **Current**: `Self(lhs.rawValue & rhs.rawValue)`, `(rawValue & other.rawValue) == other.rawValue`
- **Proposed**: These are boundary overloads implementing bitwise semantics -- this is legitimate boundary code. No change needed, but consider documenting them as boundary overloads.
- **Rationale**: [PATTERN-017] allows `.rawValue` in boundary code. These operator implementations ARE boundary code. Flagged as LOW for completeness only.

### Finding [BIN-016]: .rawValue extraction in Binary.Mask Comparable conformance
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Binary.Mask.swift:129
- **Current**: `lhs.rawValue < rhs.rawValue`
- **Proposed**: This is a legitimate Comparable boundary overload. No change needed.
- **Rationale**: Same as BIN-015. Protocol conformance implementations are boundary code.

### Finding [BIN-017]: Ordinal/Cardinal conversion boilerplate obscures intent
- **Severity**: LOW
- **Requirement**: [IMPL-INTENT]
- **Location**: Binary.Cursor.swift:89, 112, 164, 183, 250, 271, 318, 340; Binary.Reader.swift:78, 98, 137, 155, 214, 235
- **Current**: `Index<Storage>.Count(Cardinal(UInt(byteCount)))` and `Index<Storage>(Ordinal(UInt(newIndex)))`
- **Proposed**: Add convenience initializers to `Index<T>` and `Index<T>.Count` that accept `Int` directly, internalizing the Ordinal/Cardinal wrapping: `Index<Storage>(intValue: newIndex)`.
- **Rationale**: [IMPL-INTENT] requires code to read as intent, not mechanism. The triple-nested constructor `Index<Storage>.Count(Cardinal(UInt(byteCount)))` is mechanism -- the intent is "count from byte count". A convenience initializer would express this as `Index<Storage>.Count(byteCount)`.

### Finding [BIN-018]: Compound method name withSerializedBytes
- **Severity**: LOW
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Serializable.swift:108, 119, 238, 250, 294, 316, 336
- **Current**: `withSerializedBytes(_:_:)` / `withSerializedBytes(_:)`
- **Proposed**: `serialized.bytes { span in ... }` or `withBytes(_:)` (since the serialization context is already established by the type).
- **Rationale**: [API-NAME-002] forbids compound method names. `withSerializedBytes` is a three-word compound. However, `with...` closures are a common Swift pattern (e.g., `withUnsafeBytes`), so this is LOW severity.

### Finding [BIN-019]: Compound case name compactName
- **Severity**: LOW
- **Requirement**: [API-NAME-002]
- **Location**: Binary.Format.Bytes.Notation.swift:24
- **Current**: `case compactName`
- **Proposed**: `case compact`
- **Rationale**: [API-NAME-002] forbids compound identifiers. `compactName` compounds two concepts. The context (`Notation` enum) already establishes that this is about name formatting, so `compact` suffices.

### Finding [BIN-020]: Compound variable name lastNonTrimIndex
- **Severity**: LOW
- **Requirement**: [API-NAME-002]
- **Location**: Collection+UInt8.swift:43
- **Current**: `var lastNonTrimIndex = start`
- **Proposed**: `var lastKeptIndex = start` or `var boundary = start`
- **Rationale**: [API-NAME-002] forbids compound identifiers. This is an internal local variable, so impact is minimal.

### Finding [BIN-021]: Multiple extension blocks + conformances in Binary.Serializable.swift
- **Severity**: LOW
- **Requirement**: [API-IMPL-005]
- **Location**: Binary.Serializable.swift (all 354 lines)
- **Current**: Contains `Binary.Serializable` protocol definition + 14 extension blocks covering: convenience extensions, zero-copy access, RangeReplaceableCollection append, Array/ContiguousArray/ArraySlice conformances, String conversion, RawRepresentable default implementations, Tagged conformance.
- **Proposed**: Split into separate files:
  - `Binary.Serializable.swift` -- protocol definition only
  - `Binary.Serializable+Convenience.swift` -- bytes property, serialize(into:), returning convenience
  - `Binary.Serializable+Span.swift` -- withSerializedBytes
  - `Binary.Serializable+Array.swift` -- Array/ContiguousArray/ArraySlice conformances
  - `Binary.Serializable+RawRepresentable.swift` -- default implementations
  - `Binary.Serializable+Tagged.swift` -- Tagged conformance
  - `String+Bytes.swift` -- String init from bytes
- **Rationale**: [API-IMPL-005] requires one type per file. While this is one protocol, it has 7+ distinct conformance categories spanning 354 lines. The Tagged conformance, collection conformances, and String conversions are distinct types that should each have their own file.

---

## Aggregate Statistics

| Category | Count |
|----------|-------|
| `Int(bitPattern:)` usages | 44 (30 in Cursor, 14 in Reader) |
| `.rawValue.rawValue` chains | 6 (4 in Cursor, 2 in Reader) |
| `__unchecked` constructions | 32 (26 in Tagged+Bitwise, 6 in Cursor/Reader inits) |
| Compound method names | 25+ distinct methods |
| Files with only comments | 9 (Int8.swift through UInt.swift -- dead code) |

## Notes

1. **Tagged+Bitwise.swift** is the largest single source of `__unchecked` usage (26 calls). One operator (`~`) already uses `.map`, proving the pattern works. The remaining 25 should follow suit.

2. **Binary.Cursor and Binary.Reader** share identical patterns of `Int(bitPattern:)` extraction + arithmetic + re-wrapping. This suggests a missing typed arithmetic layer in `Index<T>` that would eliminate all 44 `Int(bitPattern:)` calls and all 6 `.rawValue.rawValue` chains.

3. **9 commented-out files** (Int8.swift, Int16.swift, Int32.swift, Int64.swift, Int.swift, UInt16.swift, UInt32.swift, UInt64.swift, UInt.swift) contain only TODO comments and dead code. These should be deleted -- the generic `FixedWidthInteger` extension in `FixedWidthInteger+Binary.swift` supersedes them.

4. **Memory.Alignment+Binary.Position.swift** has both throwing and non-throwing variants distinguished by method name suffix (`alignUpThrowing` vs `alignUp`). This is an anti-pattern per [API-NAME-002]. The typed throws signature should distinguish them, not the method name.

5. **Binary.Format.Bytes.swift** internal helpers (`formatNumber`, `formatWithPrecision`, `stripTrailingZeros`, `selectUnit`) are all compound names. Since they are `@usableFromInline` internal, the impact is limited to this file, but the naming convention should still be followed.
