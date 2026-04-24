# Associative / Hashing -- Post-Refactor Assessment (v2)

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
supersedes: v1.0.0 (2026-02-08)
---
-->

## Context

Post-refactor assessment of the four associative/hashing packages following the
Buffer/Storage/Memory stack migration. This v2 audit reads every source file and
catalogs all types, storage mechanisms, dependencies, and convention compliance.

## Scope

| Package | Path |
|---------|------|
| swift-hash-primitives | `/Users/coen/Developer/swift-primitives/swift-hash-primitives/` |
| swift-hash-table-primitives | `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/` |
| swift-set-primitives | `/Users/coen/Developer/swift-primitives/swift-set-primitives/` |
| swift-dictionary-primitives | `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/` |

---

## Findings

### [F-001] UnsafePointer escape in Hash.Occupied.View -- HIGH

**File**: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table+occupied.swift`, lines 26-27

```swift
let hashes: UnsafePointer<Int> = unsafe _buffer.withMetadataPointer { unsafe UnsafePointer($0) }
let positions: UnsafePointer<Int> = unsafe UnsafePointer(_buffer.pointer(at: .zero))
```

Raw pointers are extracted from `Buffer<Int>.Slots<Int>` and stored in the `Hash.Occupied<Element>.View` struct. These pointers escape their scoped closure. If the buffer is mutated, deallocated, or copied during iteration, the pointers become dangling. The downstream `Hash.Occupied.View.Iterator` (`Hash.Occupied.View.Iterator.swift`, lines 44-48) reads through these escaped pointers.

**Severity**: HIGH. Memory unsafety in a non-`@_spi(Unsafe)` public API.

**Recommendation**: Either (a) have `View` hold a retained reference to the `Buffer.Slots` object (which is reference-counted), or (b) replace the pointer-based view with closure-based iteration exclusively. The `Hash.Occupied<Element>.Static` variant already avoids this by copying `InlineArray` values -- the heap variant should be equally safe.

**Convention**: Violates the spirit of `@safe` annotation on `Hash.Table`.

---

### [F-002] Raw Int in Dictionary subscripts and withValue methods -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered Copyable.swift`

Lines 151-155 (`Dictionary.Ordered`):
```swift
public subscript(index index: Int) -> (key: Key, value: Value) {
    precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
```

Lines 225-229 (`Dictionary.Ordered.Bounded`):
```swift
public subscript(index index: Int) -> (key: Key, value: Value) {
    precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
```

Lines 279-283 (`Dictionary.Ordered.Static`):
```swift
public subscript(index index: Int) -> (key: Key, value: Value) {
    precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
```

Lines 304-313 (`Dictionary.Ordered.Small`):
```swift
public subscript(index index: Int) -> (key: Key, value: Value) {
    precondition(index >= 0 && index < Int(bitPattern: count), "Index out of bounds")
```

**File**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered ~Copyable.swift`

Lines 408-412 (`Dictionary.Ordered.Static.withValue(atIndex:_:)`):
```swift
public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
    precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
    let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
```

Lines 557-561 (`Dictionary.Ordered.Small.withValue(atIndex:_:)`):
```swift
public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
    precondition(index >= 0 && index < Int(bitPattern: count), "Index out of bounds")
    let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
```

**Severity**: MEDIUM. These raw `Int` subscripts exist as stdlib compatibility bridges (for `Swift.Collection` conformance). The typed `Index<Key>` overloads exist alongside them. The `withValue(atIndex:)` methods on Static and Small variants take raw `Int` rather than `Index<Key>`.

**Recommendation**: Consider deprecating the raw-`Int` `withValue(atIndex:)` methods or renaming them with an `_unsafe` prefix since the typed `withValue(at: Index<Key>)` overloads already exist. The `subscript(index index: Int)` methods are needed for Collection conformance but could be narrowed to the variant module only.

**Convention**: [IMPL-INTENT] -- prefer typed indices over raw Int.

---

### [F-003] Raw Int as Collection.Index typealias -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Ordered Primitives/Dictionary.Ordered Copyable.swift`, line 99

```swift
public typealias Index = Int
```

The `Swift.Collection` conformance uses `typealias Index = Int` rather than a typed index. This is inherent to bridging with `Swift.Collection` (which requires `Comparable` on indices), but it means the Collection subscript at line 108 accepts raw `Int` positions.

**Severity**: MEDIUM. Required by Swift.Collection protocol, but breaks the typed-index discipline within the variant module.

**Recommendation**: Accepted trade-off. Document that `Swift.Collection`-based access uses raw `Int` and prefer `Index<Key>`-based access in primitives-layer code.

**Convention**: Inherent tension between [IMPL-INTENT] and Swift.Collection requirements.

---

### [F-004] Multiple error types per file (hoisted errors) -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Error.swift`
- `__DictionaryOrderedError<Key>` (line 28)
- `__DictionaryOrderedBoundedError<Key>` (line 79)
- `__DictionaryOrderedInlineError<Key>` (line 99)
- Plus nested payload structs, Sendable/Equatable conformances, and typealiases

**File**: `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Primitives Core/Set.Ordered.Error.swift`
- `__SetOrderedError<Element>` (line 22)
- `__SetOrderedFixedError<Element>` (line 58)
- `__SetOrderedInlineError<Element>` (line 118)
- Plus nested payload structs, conformances, and typealiases

**Severity**: MEDIUM. Both files contain 3 error enums each, violating [API-IMPL-005] (one type per file). These are hoisted to module level as a compiler workaround (Swift does not allow nested types inside generic types to be easily accessed). The workaround is documented with `WHEN TO REMOVE` comments and tracking reference `[API-EXC-001]`.

**Recommendation**: Accept as tracked debt. When Swift supports direct generic nested type access, split into separate files per error type.

**Convention**: [API-IMPL-005] violation, justified by compiler limitation, tracked at [API-EXC-001].

---

### [F-005] Hash.Table unconditional @unchecked Sendable -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift`, line 315

```swift
extension Hash.Table: @unchecked Sendable where Element: ~Copyable {}
```

`Hash.Table` is `@unchecked Sendable` unconditionally on `Element` -- i.e., even when `Element` is not `Sendable`. The `Static` variant correctly requires `where Element: Sendable` (line 318). The heap variant's unconditional conformance is aggressive: it assumes single-owner access, which is valid for value-type embedding but could be unsound if a reference to the internal `Buffer.Slots` escapes.

**Severity**: MEDIUM. The conformance should arguably be `where Element: Sendable` for consistency with Static and with the Set/Dictionary Sendable conformances (which all require `Key: Sendable, Value: Sendable`).

**Recommendation**: Change to `extension Hash.Table: @unchecked Sendable where Element: Sendable {}`.

**Convention**: [MEM-SEND-*] -- Sendable conformance should require Sendable element types.

---

### [F-006] Symmetric difference uses O(n^2) linear scan -- LOW

**File**: `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Algebra.Symmetric.swift`, lines 61-78

```swift
// Elements in other but not in self
var otherIndex: Index<Element> = .zero
let otherEnd = other.count.map(Ordinal.init)
while otherIndex < otherEnd {
    let element = other.buffer[otherIndex]
    // Check if element is in self by iterating
    var found = false
    var selfIndex: Index<Element> = .zero
    while selfIndex < end {
        if buffer[selfIndex] == element {
            found = true
            break
        }
        selfIndex += .one
    }
```

The first pass (lines 50-58) correctly uses `other.contains(element)` which is O(1) via hash lookup. The second pass (lines 61-78) uses O(n) linear scan through `buffer` instead of using a hash table lookup. Since `self` is an `Algebra.Symmetric` struct that stores only a `Buffer<Element>.Linear` (not a full `Set.Ordered`), it lacks hash-table-backed `contains()`.

**Severity**: LOW. Asymmetric complexity: first pass is O(n), second pass is O(n*m). For small sets this is fine; for large sets, the second pass dominates.

**Recommendation**: Either (a) also store the hash table in `Algebra.Symmetric`, or (b) build a temporary `Set.Ordered` from self's buffer for the reverse lookup, or (c) document the O(n*m) complexity in the doc comment (currently claims O(n+m) at line 44).

**Convention**: Documentation accuracy -- the doc comment claims O(n + m) but the implementation is O(n * m) for the second pass.

---

### [F-007] Multiple conformances per file in Hash Primitives Standard Library Integration -- LOW

**File**: `/Users/coen/Developer/swift-primitives/swift-hash-primitives/Sources/Hash Primitives Standard Library Integration/Hash.Protocol+Swift.Range.swift`
- `Range: Hash.Protocol` (line 4)
- `ClosedRange: Hash.Protocol` (line 19)

**File**: `/Users/coen/Developer/swift-primitives/swift-hash-primitives/Sources/Hash Primitives Standard Library Integration/Hash.Protocol+Swift.PartialRange.swift`
- `PartialRangeFrom: Hash.Protocol` (line 4)
- `PartialRangeThrough: Hash.Protocol` (line 15)
- `PartialRangeUpTo: Hash.Protocol` (line 26)

**Severity**: LOW. These are extension conformances (not type declarations), so [API-IMPL-005] strictly applies to types, not extensions. However, each conformance could be its own file for consistency: `Hash.Protocol+Swift.Range.swift`, `Hash.Protocol+Swift.ClosedRange.swift`, etc.

**Recommendation**: Consider splitting for consistency, but this is not blocking.

**Convention**: [API-IMPL-005] -- debatable applicability to extension-only files.

---

### [F-008] Template artifact in exports.swift header -- LOW

**File**: `/Users/coen/Developer/swift-primitives/swift-hash-primitives/Sources/Hash Primitives Core/exports.swift`, lines 1-6

```swift
//
//  File.swift
//  swift-hash-primitives
//
//  Created by Coen ten Thije Boonkkamp on 03/02/2026.
//
```

Uses the Xcode auto-generated "File.swift" header instead of the standard project header (the `===---===//` banner used in all other files).

**Severity**: LOW. Cosmetic inconsistency.

**Recommendation**: Replace with the standard project header.

---

### [F-009] Duplicate re-export in Dictionary Ordered Primitives exports -- LOW

**File**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Ordered Primitives/exports.swift`, lines 12-13

```swift
@_exported public import Dictionary_Primitives_Core
@_exported import Dictionary_Primitives_Core
```

`Dictionary_Primitives_Core` is exported twice -- once with `public` and once without. The second line is redundant.

**Severity**: LOW. No functional impact; the compiler deduplicates imports.

**Recommendation**: Remove the duplicate line.

---

## Compiler Workarounds (Tracked Debt)

### [CW-001] _deinitWorkaround: AnyObject?

**Files**:
- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Primitives Core/Set.swift`, line 115 (`Set.Ordered.Static`)
- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Primitives Core/Set.swift`, line 154 (`Set.Ordered.Small`)

**Bug**: swiftlang/swift#86652 -- deinit element cleanup fails for `~Copyable` structs containing only value-type stored properties. The `AnyObject?` field forces reference-type-like deinit semantics.

**When to remove**: When the upstream bug is fixed and the compiler correctly deinitializes `~Copyable` value-only structs.

---

### [CW-002] Exclusivity analysis crash workaround

**Files**:
- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Small.swift`, lines ~122, ~143, ~270

Pattern: extract `_heapHashTable` to a local `var ht` before calling chained Property.View.Typed accessors (`.positions.decrement(after:)`, `.remove.all()`). Direct access crashes the `DiagnoseStaticExclusivity` SIL pass on generic `~Copyable` structs.

**When to remove**: When the SIL pass handles mutating coroutine accessor chains on stored properties of `~Copyable` generics.

---

### [CW-003] Nested type with value generics not inheriting ~Copyable

**Files**:
- `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift`, lines 184-308 (`Hash.Table.Static<let bucketCapacity: Int>` declared inside `Hash.Table` body)
- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Primitives Core/Set.swift` (`Set.Ordered.Static<let capacity: Int>` and `Set.Ordered.Small<let inlineCapacity: Int>` declared inside `Set.Ordered` body)
- `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.swift` (`Dictionary.Ordered.Static<let capacity: Int>` and `Dictionary.Ordered.Small<let inlineCapacity: Int>` declared inside `Dictionary.Ordered` body)

**Bug**: Swift compiler does not properly propagate `~Copyable` constraints from outer generic type to extension-declared nested types that have value generic parameters. Declaring these types inside the parent struct body works around this.

**When to remove**: When the compiler correctly inherits `~Copyable` constraints in nested types declared in extensions with value generics.

---

## Cross-Cutting Observations

### Stack Migration is Complete

All four packages have fully migrated to the Buffer/Storage/Memory stack. Zero occurrences of raw `UnsafeMutableBufferPointer` allocation, `ManagedBuffer` subclasses, or manual `allocate`/`deallocate` calls anywhere in the tier. The composition hierarchy is clean:

```
Dictionary.Ordered
  +-- Set<Key>.Ordered
  |     +-- Buffer<Key>.Linear --> Storage<Key>.Heap --> Memory management
  |     +-- Hash.Table<Key>
  |           +-- Buffer<Int>.Slots<Int>
  +-- Buffer<Value>.Linear --> Storage<Value>.Heap --> Memory management

Hash Primitives
  +-- Pure value types (Hash.Value, Hash.Protocol)
  +-- No storage at all
```

### ~Copyable Support is Thorough

The tier supports `~Copyable` elements end-to-end:
- `Hash.Protocol` -- borrowing-based hashable for ~Copyable types
- `Hash.Table<Element: ~Copyable>` -- conditionally Copyable
- `Set<Element: Hash.Protocol & ~Copyable>` -- all four variants (Ordered, Fixed, Static, Small)
- `Dictionary<Key: Hash.Protocol, Value: ~Copyable>` -- all four variants
- `Entry`, `Drain`, `forEach`, `withValue` -- all handle ~Copyable values

The API surface is cleanly split between base methods (available for all types) and CoW/copy methods (gated on `Copyable` in separate file/extension).

### No Foundation Dependencies

Zero Foundation imports across all four packages. All hashing via `Hash.Protocol` / `Hash.Value`. All storage via Buffer/Storage/Memory. All indexing via `Index<T>` with Ordinal/Cardinal arithmetic.

### All Typed Throws

Every throwing function uses typed throws:
- `Dictionary.Ordered.Error` (`__DictionaryOrderedError<Key>`)
- `Dictionary.Ordered.Bounded.Error` (`__DictionaryOrderedBoundedError<Key>`)
- `Dictionary.Ordered.Static.Error` (`__DictionaryOrderedInlineError<Key>`)
- `Set.Ordered.Error` (`__SetOrderedError<Element>`)
- `Set.Ordered.Fixed.Error` (`__SetOrderedFixedError<Element>`)
- `Set.Ordered.Static.Error` (`__SetOrderedInlineError<Element>`)

No untyped `throws` anywhere.

### v1 Finding Resolution

The v1 assessment noted `Dictionary.Ordered.Small._count` used raw `Int`. This has been resolved:

**File**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.swift`, line 309

```swift
@usableFromInline
var _count: Index_Primitives.Index<Key>.Count
```

The field now uses typed `Index<Key>.Count` consistent with all other variants.

---

## Summary Table

| ID | Description | Severity | Package | Convention |
|----|-------------|----------|---------|------------|
| F-001 | UnsafePointer escape in Hash.Occupied.View | HIGH | hash-table | @safe / memory safety |
| F-002 | Raw Int in Dictionary subscripts/withValue | MEDIUM | dictionary | [IMPL-INTENT] |
| F-003 | Raw Int as Collection.Index typealias | MEDIUM | dictionary | [IMPL-INTENT] vs Collection |
| F-004 | Multiple error types per file (hoisted) | MEDIUM | set, dictionary | [API-IMPL-005] |
| F-005 | Hash.Table unconditional @unchecked Sendable | MEDIUM | hash-table | [MEM-SEND-*] |
| F-006 | Symmetric difference O(n^2) second pass | LOW | set | Documentation accuracy |
| F-007 | Multiple conformances per file in stdlib integration | LOW | hash | [API-IMPL-005] |
| F-008 | Template artifact in exports.swift header | LOW | hash | Cosmetic |
| F-009 | Duplicate re-export line | LOW | dictionary | Cosmetic |
| CW-001 | _deinitWorkaround: AnyObject? | Tracked | set | swiftlang/swift#86652 |
| CW-002 | Exclusivity analysis crash workaround | Tracked | set | SIL pass bug |
| CW-003 | Nested type value generic ~Copyable inheritance | Tracked | all | Compiler bug |

---

## Prioritized Recommendations

1. **F-001**: Redesign `Hash.Occupied.View` to avoid pointer escape. Either retain the Buffer.Slots reference or use closure-based iteration. This is the only memory safety issue.

2. **F-005**: Tighten `Hash.Table` Sendable conformance to require `Element: Sendable`, matching the `Static` variant and downstream Set/Dictionary conformances.

3. **F-006**: Fix the symmetric difference complexity by either storing the hash table in `Algebra.Symmetric` or building a temporary set for the reverse lookup. At minimum, correct the O(n+m) doc comment.

4. **F-002/F-003**: Accept as necessary stdlib bridges. Consider restricting raw-Int `withValue(atIndex:)` to `@_spi` or deprecating in favor of typed overloads.

5. **F-004/F-007/F-008/F-009**: Low-priority cleanup. Address during next maintenance pass.

---

## Outcome

**Status**: DECISION

The associative/hashing tier is production-ready on the new stack. One HIGH finding (pointer escape in Hash.Occupied.View) warrants near-term remediation. All other findings are MEDIUM or LOW severity, most being inherent trade-offs or tracked compiler workarounds. The v1 raw-Int count finding in Dictionary.Ordered.Small has been resolved.

## Changelog

- **v2.0.0** (2026-02-12): Complete re-audit reading all source files. Added Hash Primitives package to scope. Identified 9 findings + 3 compiler workarounds. Confirmed v1 _count finding resolved.
- **v1.0.0** (2026-02-08): Initial stack migration assessment.
