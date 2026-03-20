# swift-array-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Scope**: 40 files across 7 modules
**Rules**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-020], [IMPL-050], [PATTERN-017], [PATTERN-021], [API-IMPL-005]

---

## Summary Table

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| ARR-001 | MEDIUM | [IMPL-010] | Array.Fixed.swift (Core) | 45-46, 84-85 | `Int(bitPattern: count)` and raw `Ordinal(UInt(i))` construction at init call sites |
| ARR-002 | MEDIUM | [IMPL-002] | Array+ExpressibleByArrayLiteral.swift | 6 | Chain `.init(Cardinal(UInt(elements.count)))` — mechanism at call site |
| ARR-003 | LOW | [IMPL-010] | Array.Dynamic.swift | 38 | `Int(bitPattern: count)` for `underestimatedCount` — acceptable stdlib boundary |
| ARR-004 | LOW | [API-NAME-002] | Array.Dynamic ~Copyable.swift | 137, 146, 150 | `removeAll` compound method name (stdlib convention) |
| ARR-005 | INFO | [API-IMPL-005] | Array.Dynamic ~Copyable.swift | 234-236 | `Drain` enum + typealias in same extension as `Array` |
| ARR-006 | INFO | [API-IMPL-005] | Array.Static ~Copyable.swift | 167-169 | `Drain` enum + typealias in same extension as `Array.Static` |
| ARR-007 | INFO | [API-IMPL-005] | Array.Small ~Copyable.swift | 211-213 | `Drain` enum + typealias in same extension as `Array.Small` |
| ARR-008 | INFO | [API-IMPL-005] | Array.swift (Core) | 101-124 | `Fixed` struct declared inside `Array` struct body (compiler constraint) |
| ARR-009 | LOW | [API-IMPL-005] | Array.Fixed ~Copyable.swift | 62-83 | `Iterator` struct declared in same file as main Fixed extensions |
| ARR-010 | LOW | [IMPL-010] | Array.Small ~Copyable.swift | 182, 195 | `Int(bitPattern: _buffer.count)` in `withUnsafeBufferPointer` |
| ARR-011 | LOW | [API-IMPL-005] | Array.Dynamic.swift | 59-80 | `Iterator` struct in same file as conformances |
| ARR-012 | LOW | [API-IMPL-005] | Array.Small.swift | 48-69 | `Iterator` struct in same file as conformances |
| ARR-013 | INFO | [API-IMPL-005] | Array Primitives Core | — | `Array.Fixed Copyable.swift` and `Array.Fixed ~Copyable.swift` contain no type declarations |
| ARR-014 | MEDIUM | [IMPL-050] | Array.Static ~Copyable.swift | 80-91 | Static-capacity type uses unbounded `Index` in subscript, not `Index<Element>.Bounded<capacity>` |
| ARR-015 | LOW | [IMPL-050] | Array.Small ~Copyable.swift | 86-95 | Value-generic type uses unbounded `Index` in subscript |

---

## Findings

### ARR-001 — `Int(bitPattern:)` and raw index construction in Fixed init [IMPL-010]

**File**: `Array Primitives Core/Array.Fixed.swift`, lines 45-47 and 84-86
**Code**:
```swift
for i in 0..<Int(bitPattern: count) {
    let index = Array.Index(Ordinal(UInt(i)))
    unsafe (ptr + i).initialize(to: initializer(index))
}
```

The `Int(bitPattern: count)` conversion and the chain `Array.Index(Ordinal(UInt(i)))` are mechanism at the implementation site. Per [IMPL-010], the `Int(bitPattern:)` should be in a boundary overload. The `Ordinal(UInt(i))` chain is a construction gap — an `Index` should be constructible from the loop variable without chaining through `UInt` and `Ordinal`. This pattern is duplicated in both the checked and unchecked init.

### ARR-002 — Mechanism chain in ExpressibleByArrayLiteral [IMPL-002]

**File**: `Array Dynamic Primitives/Array+ExpressibleByArrayLiteral.swift`, line 6
**Code**: `Self(initialCapacity: .init(Cardinal(UInt(elements.count))))`

The chain `Cardinal(UInt(elements.count))` is mechanism. A boundary overload accepting `Int` count would eliminate this.

### ARR-003 — `Int(bitPattern:)` in underestimatedCount [IMPL-010]

**File**: `Array Dynamic Primitives/Array.Dynamic.swift`, line 38
**Code**: `public var underestimatedCount: Int { Int(bitPattern: count) }`

This is a stdlib-boundary conversion. The `Int(bitPattern:)` is the correct boundary point for interfacing with `Swift.Sequence`'s `underestimatedCount: Int` requirement. Acceptable boundary code per [IMPL-010].

### ARR-004 — `removeAll` compound method name [API-NAME-002]

**File**: `Array.Dynamic ~Copyable.swift`, lines 137-155
**Code**: `public mutating func removeAll(keepingCapacity: Bool = false)`

The method name `removeAll` is a compound identifier. However, this mirrors stdlib's `removeAll(keepingCapacity:)` for interop purposes. The ecosystem already provides `remove.all()` via Property.View, and the comment on line 141 ("Use `.remove.all()` at call sites") correctly directs consumers to the nested accessor form.

### ARR-005 through ARR-007 — `Drain` enum in extension files [API-IMPL-005]

**Files**: Array.Dynamic, Array.Static, Array.Small `~Copyable.swift` files

Each file declares a `Drain` enum (namespace + typealias) alongside the main type's extensions. These are small (3-line) namespace enums for Property.View typealiases. Extracting each to a separate file would be excessive.

### ARR-008 — `Fixed` struct inside `Array` body [API-IMPL-005]

**File**: `Array Primitives Core/Array.swift`, lines 101-107

`Array.Fixed` is declared inside the `Array` struct body rather than in a separate extension file. The comment explains this is required by Swift's ~Copyable constraint propagation rules. This is a compiler constraint, not a design choice.

### ARR-009, ARR-011, ARR-012 — `Iterator` types in shared files [API-IMPL-005]

**Files**: Array.Fixed, Array.Dynamic, Array.Small

Each variant declares its `Iterator` struct in the same file as protocol conformances. Per strict [API-IMPL-005], each Iterator should be in `Array.Fixed.Iterator.swift`, `Array.Iterator.swift`, `Array.Small.Iterator.swift`. These are small types (20 lines) that are tightly coupled to their Sequence conformance.

### ARR-014 — Static-capacity subscript uses unbounded index [IMPL-050]

**File**: `Array Static Primitives/Array.Static ~Copyable.swift`, lines 80-91
**Code**:
```swift
public subscript(_ index: Index) -> Element {
    _read {
        precondition(index < count, "Index out of bounds")
        yield _buffer[index]
    }
}
```

`Array.Static<capacity>` is a static-capacity type with `let capacity: Int`. Per [IMPL-050], it should accept `Index<Element>.Bounded<capacity>` in its subscript. The current implementation uses unbounded `Index<Element>` with a runtime precondition, discarding the compile-time capacity knowledge.

### ARR-015 — Small array subscript uses unbounded index [IMPL-050]

**File**: `Array Small Primitives/Array.Small ~Copyable.swift`, lines 86-95

Same issue as ARR-014 but for `Array.Small<inlineCapacity>`. The inline capacity is a value-generic parameter that could provide bounded index guarantees.

---

## Clean Areas

- **Namespace structure**: All types follow `Array.X.Y` nesting (`Array.Fixed`, `Array.Static`, `Array.Small`, `Array.Bounded`, `Array.Indexed`). No compound public type names.
- **Typed throws**: `Array.Fixed` init uses `throws(Error)`. `Array.Static.append` uses `throws(Array.Static.Error)`.
- **Property.View**: `forEach` and `drain` correctly use `Property<Tag, Self>.View.Typed<Element>` pattern with both `_read` and `_modify` coroutines.
- **No Foundation**: No Foundation imports anywhere.
- **Typed arithmetic**: `count.map(Ordinal.init)`, `i.successor.saturating()`, `i.predecessor.exact()`, `count.retag(Tag.self)` — all correct typed operations at call sites.
- **Static method pattern**: `removeLast` and `removeAll` correctly use static primitives for Collection protocol conformance.
