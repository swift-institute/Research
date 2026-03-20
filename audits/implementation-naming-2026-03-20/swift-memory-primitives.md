# swift-memory-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (read-only)
**Scope**: 45 source files across 5 modules
**Skills**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [PATTERN-017], [PATTERN-021], [API-IMPL-005]

## Summary Table

| ID | Severity | Rule | File | Line | Description |
|----|----------|------|------|------|-------------|
| MEM-001 | HIGH | [IMPL-002] | Memory.Address.swift | 138,146 | `.rawValue.rawValue` to extract `UInt` from `Tagged<Memory, Ordinal>` |
| MEM-002 | MEDIUM | [IMPL-002] | Memory.Shift.swift | 163 | `.rawValue` comparison in `Comparable` |
| MEM-003 | MEDIUM | [IMPL-002] | Memory.Shift.swift | 171 | `.rawValue` in `description` |
| MEM-004 | MEDIUM | [IMPL-002] | Memory.Address.swift | 65 | `Ordinal(UInt(bitPattern: pointer))` — `.rawValue`-adjacent conversion |
| MEM-005 | LOW | [IMPL-010] | Memory.Address.swift | 138,146 | `UnsafeRawPointer(bitPattern:)` at pointer boundary — acceptable |
| MEM-006 | MEDIUM | [IMPL-002] | Memory.Shift+Cardinal.Protocol.swift | 10-11 | `.rawValue` in Cardinal conformance |
| MEM-007 | MEDIUM | [IMPL-002] | Memory.Alignment.swift | 132 | `Int(shift.rawValue)` in `validated(for:)` |
| MEM-008 | MEDIUM | [IMPL-002] | Memory.Alignment.swift | 148,155 | `UInt(bitPattern:)` on pointer for alignment check |
| MEM-009 | LOW | [IMPL-010] | Memory+UnsafeMutableRawPointer.swift | 20 | `Int(bitPattern: count.count)` at stdlib boundary — acceptable |
| MEM-010 | LOW | [IMPL-010] | Memory.Buffer.swift | 108 | `Memory.Address.Count(UInt(buffer.count))` at stdlib boundary — acceptable |
| MEM-011 | MEDIUM | [IMPL-002] | Memory.Shift.swift | 57 | `self.rawValue = UInt8(value)` in init — internal, acceptable |
| MEM-012 | LOW | [API-IMPL-005] | Memory.Buffer.swift | 29-37 | Two module-level sentinels + `Memory.Buffer` in one file |
| MEM-013 | LOW | [API-IMPL-005] | Memory.Buffer.Mutable.swift | 19-20 | Sentinel re-export + `Memory.Buffer.Mutable` in one file |
| MEM-014 | MEDIUM | [IMPL-002] | Memory Primitives Standard Library Integration (various) | various | `.vector.rawValue` on offset types at stdlib boundary |

## Findings

### MEM-001 — `.rawValue.rawValue` Chain in Pointer Interop [HIGH]

**File**: `Sources/Memory Primitives Core/Memory.Address.swift`, lines 138, 146
**Rule**: [IMPL-002], [PATTERN-017]

```swift
extension UnsafeRawPointer {
    public init(_ address: Memory.Address) {
        unsafe self = UnsafeRawPointer(bitPattern: address.rawValue.rawValue)!
    }
}
extension UnsafeMutableRawPointer {
    public init(_ address: Memory.Address) {
        unsafe self = UnsafeMutableRawPointer(bitPattern: address.rawValue.rawValue)!
    }
}
```

Double `.rawValue` extraction: `Memory.Address` (= `Tagged<Memory, Ordinal>`) unwraps to `Ordinal`, then `.rawValue` on `Ordinal` yields `UInt`. This is boundary code (converting typed address back to stdlib pointer), so the `.rawValue` is confined to the interop boundary. However, the double chain `.rawValue.rawValue` is a code smell. A dedicated `address.bitPattern` computed property would be cleaner.

### MEM-002 — `.rawValue` in Comparable

**File**: `Sources/Memory Primitives Core/Memory.Shift.swift`, line 163
**Rule**: [IMPL-002]

```swift
public static func < (lhs: Memory.Shift, rhs: Memory.Shift) -> Bool {
    lhs.rawValue < rhs.rawValue
}
```

`Memory.Shift` has a stored `rawValue: UInt8`. Since `Shift` is not a wrapper type (it's a primary type with a stored property named `rawValue`), this is the conventional RawRepresentable pattern, not a wrapper leakage. **Borderline acceptable** — the property name `rawValue` invites this usage, but a rename to `exponent` or `count` would be more intent-expressive.

### MEM-003 — `.rawValue` in Description

**File**: `Sources/Memory Primitives Core/Memory.Shift.swift`, line 171
**Rule**: [IMPL-002]

```swift
public var description: String { "\(rawValue)" }
```

Same stored-property pattern as MEM-002. Accessing the stored `UInt8` for string output.

### MEM-004 — Ordinal Construction from Pointer Bit Pattern

**File**: `Sources/Memory Primitives Core/Memory.Address.swift`, line 65
**Rule**: [IMPL-002]

```swift
self.init(__unchecked: (), Ordinal(UInt(bitPattern: pointer)))
```

This is the fundamental address-from-pointer constructor. `UInt(bitPattern:)` is the only correct way to extract a pointer's numeric value in Swift. The `__unchecked` initializer bypasses Tagged validation. This is boundary code by definition — it's the bridge between pointer and typed-address domains. **Acceptable**.

### MEM-005 — `bitPattern:` at Pointer Boundary [ACCEPTABLE]

**File**: `Sources/Memory Primitives Core/Memory.Address.swift`, lines 138, 146
**Rule**: [IMPL-010]

`UnsafeRawPointer(bitPattern:)` and `UnsafeMutableRawPointer(bitPattern:)` are used in the pointer-from-address constructors. These are the canonical boundary overloads. **Acceptable per [IMPL-010]**.

### MEM-006 — `.rawValue` in Cardinal Conformance

**File**: `Sources/Memory Primitives Core/Memory.Shift+Cardinal.Protocol.swift`, lines 10-11
**Rule**: [IMPL-002]

```swift
public var cardinal: Cardinal {
    Cardinal(UInt(rawValue))
}
public init(_ cardinal: Cardinal) {
    self.init(unchecked: UInt8(cardinal.rawValue))
}
```

Bidirectional conversion between `Memory.Shift.rawValue` (UInt8) and `Cardinal.rawValue` (UInt). The `cardinal.rawValue` extraction is a `.rawValue` at a conformance boundary — converting from the typed Cardinal system to raw UInt8 for the Shift's stored property. This is a protocol conformance bridge. **Borderline acceptable**.

### MEM-007 — `.rawValue` in Validated Method

**File**: `Sources/Memory Primitives Core/Memory.Alignment.swift`, line 132
**Rule**: [IMPL-002]

```swift
guard Int(shift.rawValue) < Carrier.bitWidth else {
```

Accesses `Memory.Shift.rawValue` (the stored `UInt8`) to compare against `Carrier.bitWidth` (an `Int`). The comparison requires widening the UInt8 to Int. A `.cardinal` or widening accessor on `Shift` would avoid the `.rawValue` extraction.

### MEM-008 — `UInt(bitPattern:)` on Pointer for Alignment Check

**File**: `Sources/Memory Primitives Core/Memory.Alignment.swift`, lines 148, 155
**Rule**: [IMPL-002]

```swift
public func isAligned(_ pointer: UnsafeRawPointer) -> Bool {
    UInt(bitPattern: pointer) & shift.mask() == 0
}
```

Extracts pointer's numeric value via `UInt(bitPattern:)` for bitwise alignment check. This is the only correct way to perform alignment checking in Swift — there is no stdlib API for this. **Acceptable as boundary code**.

### MEM-009 — `Int(bitPattern:)` at stdlib Boundary [ACCEPTABLE]

**File**: `Sources/Memory Primitives Standard Library Integration/Memory+UnsafeMutableRawPointer.swift`, line 20
**Rule**: [IMPL-010]

```swift
Self.allocate(byteCount: Int(bitPattern: count.count), alignment: alignment.magnitude())
```

Crossing from typed `Memory.Address.Count` to stdlib's `Int` parameter. **Acceptable per [IMPL-010]**.

### MEM-010 — `UInt(buffer.count)` at stdlib Boundary [ACCEPTABLE]

**File**: `Sources/Memory Primitives/Memory.Buffer.swift`, line 108
**Rule**: [IMPL-010]

```swift
self._count = Memory.Address.Count(UInt(buffer.count))
```

Crossing from stdlib's `Int` buffer count to typed `Memory.Address.Count`. **Acceptable per [IMPL-010]**.

### MEM-011 — `.rawValue` Assignment in Init [ACCEPTABLE]

**File**: `Sources/Memory Primitives Core/Memory.Shift.swift`, line 57
**Rule**: [IMPL-002]

```swift
self.rawValue = UInt8(value)
```

Direct assignment to the stored property in an initializer. This is type-internal code, not a call-site extraction. **Acceptable**.

### MEM-012 — Module-Level Sentinels in Buffer File

**File**: `Sources/Memory Primitives/Memory.Buffer.swift`, lines 29-37
**Rule**: [API-IMPL-005]

Two `nonisolated(unsafe) let` sentinels (`_emptyBufferSentinelMutable`, `_emptyBufferSentinel`) are declared at module scope alongside the `Memory.Buffer` struct. These are implementation details of `Memory.Buffer`, not independent types. **Minor**.

### MEM-013 — Sentinel Re-export in Mutable Buffer File

**File**: `Sources/Memory Primitives/Memory.Buffer.Mutable.swift`, lines 19-20
**Rule**: [API-IMPL-005]

A module-level sentinel (`_emptyMutableBufferSentinel`) is defined alongside `Memory.Buffer.Mutable`. Same pattern as MEM-012. **Minor**.

### MEM-014 — `.vector.rawValue` in Standard Library Integration

**Files**: Various files in `Sources/Memory Primitives Standard Library Integration/`
**Rule**: [IMPL-002], [PATTERN-017]

Multiple files extract `.vector.rawValue` from typed offset values to pass to stdlib pointer methods:

```swift
// Memory+UnsafeRawPointer.swift:23
unsafe self.advanced(by: offset.vector.rawValue)

// Memory+UnsafeMutableRawPointer.Store.swift:51
unsafe base.storeBytes(of: value, toByteOffset: offset.vector.rawValue, as: type)
```

The `.vector.rawValue` pattern appears in 7 locations across 6 files. These are all boundary code — converting typed offsets to `Int` for stdlib pointer operations. The `.vector` extracts the `Vector` (signed displacement) and `.rawValue` yields the `Int`. This is the Standard Library Integration module, so boundary extraction is expected. **Acceptable as boundary code**, but a dedicated `.intValue` or similar accessor on the offset type would centralize the extraction.

## Clean Areas

### Naming ([API-NAME-001], [API-NAME-002])

All types follow the `Nest.Name` pattern:
- `Memory.Address`, `Memory.Alignment`, `Memory.Shift`, `Memory.Allocation`, `Memory.Aligned`
- `Memory.Contiguous`, `Memory.ContiguousProtocol` (= `Memory.Contiguous.Protocol`)
- `Memory.Inline`, `Memory.Buffer`, `Memory.Buffer.Mutable`, `Memory.Buffer.Base`, `Memory.Buffer.Mutable.Base`
- `Memory.Pool`, `Memory.Pool.Slot`, `Memory.Pool.Error`
- `Memory.Arena`, `Memory.Arena.Error`
- `Memory.Allocator`, `Memory.Allocator.Protocol`
- `Memory.Alignment.Align`, `Memory.Alignment.Error`
- `Memory.Shift.Error`, `Memory.Address.Error`
- `Memory.Move` (tag type)
- No compound type names.

Method/property names:
- `alignment.align.up()`, `alignment.align.down()`
- `pool.slot.stride`, `pool.slot.alignment`
- `pool.allocation.indices`
- `buffer.base.nullable`, `buffer.base.nonNull`
- `pointer.store.bytes(of:at:as:)`, `pointer.memory.initialize(as:repeating:count:)`, `pointer.memory.move.initialize(as:from:count:)`
- No compound names.

### Typed Arithmetic ([PATTERN-021])

No `__unchecked` usage (except the pre-validated `Tagged.__unchecked` initializer in address construction). All arithmetic uses typed operations through the Affine system.

### One Type Per File ([API-IMPL-005])

Well-organized. Each type lives in its own file. Extensions correctly separated.

## Verdict

**Good**. The primary concern is `.rawValue` access patterns: MEM-001 (`.rawValue.rawValue` chain) is the most significant finding. Most `.rawValue` usages are in boundary code (pointer interop, Cardinal conformance, stdlib integration) where extraction is structurally necessary. The package would benefit from:
1. A `bitPattern: UInt` computed property on `Memory.Address` to replace the `.rawValue.rawValue` chain.
2. A widening accessor on `Memory.Shift` (e.g., `.intValue`) to avoid `Int(shift.rawValue)`.
3. A `.rawIntValue` or similar on typed offsets to centralize the `.vector.rawValue` pattern used in 7 stdlib integration sites.

Naming is exemplary throughout — deep nesting, no compound identifiers, consistent accessor pattern.
