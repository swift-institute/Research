# Stdlib Pointer Migration Analysis

<!--
---
version: 1.0.0
last_updated: 2026-01-26
status: DECISION
scope: primitives-wide
affects: [all packages using stdlib pointer types]
---
-->

## Context

**Trigger**: Systematic review of stdlib pointer usage across swift-primitives to determine migration candidates to swift-pointer-primitives types.

**Background**: swift-pointer-primitives provides typed pointer wrappers (`Pointer<T>`, `Pointer<T>.Mutable`, etc.) and swift-memory-primitives provides raw address wrappers (`Memory.Address`, `Memory.Address.Mutable`, etc.). These offer:
- Non-null guarantee (wrapped pointer is never nil)
- Typed semantics via phantom generics
- Consistent API across pointer variants

**Scope**: Inventory and analyze 826 stdlib pointer occurrences across 68 files in 17 packages to determine which should migrate to primitives types.

## Question

Which stdlib pointer usages should migrate to swift-pointer-primitives/swift-memory-primitives types, and which should remain as stdlib types?

## Analysis

### Inventory Summary

| Pointer Type | Count | Primary Usage |
|--------------|-------|---------------|
| `UnsafeMutablePointer<T>` | 470 | Internal storage, ManagedBuffer |
| `UnsafePointer<T>` | 119 | Internal storage, read access |
| `UnsafeMutableRawPointer` | 94 | Inline storage arithmetic |
| `UnsafeRawPointer` | 63 | Inline storage arithmetic |
| `UnsafeMutableBufferPointer<T>` | 37 | ManagedBuffer interop |
| `UnsafeBufferPointer<T>` | 36 | ManagedBuffer interop |
| `UnsafeRawBufferPointer` | 10 | Buffer operations |
| `UnsafeMutableRawBufferPointer` | 8 | Buffer operations |
| **Total** | **826** | |

### Package-by-Package Analysis

#### Tier 0 (Foundational)

| Package | Files | Occurrences | Migration Status |
|---------|-------|-------------|------------------|
| swift-index-primitives | 5 | 42 | No migration needed |
| swift-comparison-primitives | 0 | 0 | N/A |
| swift-ordering-primitives | 0 | 0 | N/A |
| swift-sequence-primitives | 1 | 1 | No migration needed |

**Analysis**: swift-index-primitives provides interop extensions adding `Index<T>` support to stdlib pointers. These are intentionally stdlib types for interoperability.

#### Tier 1 (Low-Level)

| Package | Files | Occurrences | Migration Status |
|---------|-------|-------------|------------------|
| swift-pointer-primitives | N/A | N/A | Source package |
| swift-memory-primitives | N/A | N/A | Source package |
| swift-range-primitives | 0 | 0 | N/A |
| swift-property-primitives | 0 | 0 | N/A |

#### Tier 2 (Structural)

| Package | Files | Occurrences | Migration Status |
|---------|-------|-------------|------------------|
| swift-hash-primitives | 2 | 8 | No migration needed |
| swift-reference-primitives | 3 | 31 | **Migrated** |
| swift-collection-primitives | 4 | 12 | No migration needed |

**Analysis**:
- swift-hash-primitives: Conformance extensions for stdlib pointer types
- swift-reference-primitives: User-facing APIs - **migrated to primitives types**
- swift-collection-primitives: View types use stdlib for `&self` syntax

#### Tier 3+ (Data Structures)

| Package | Files | Occurrences | Primary Pattern |
|---------|-------|-------------|-----------------|
| swift-hash-table-primitives | 6 | 89 | ManagedBuffer interop |
| swift-deque-primitives | 5 | 67 | Inline storage, ManagedBuffer |
| swift-list-primitives | 4 | 43 | Internal storage |
| swift-stack-primitives | 5 | 58 | Inline storage, ManagedBuffer |
| swift-queue-primitives | 4 | 45 | Internal storage |
| swift-slab-primitives | 3 | 34 | ManagedBuffer interop |
| swift-array-primitives | 4 | 52 | Inline storage, ManagedBuffer |
| swift-heap-primitives | 4 | 47 | Internal storage |
| swift-set-primitives | 5 | 61 | Hash table storage |
| swift-dictionary-primitives | 6 | 73 | Hash table storage |
| swift-buffer-primitives | 4 | 38 | ManagedBuffer interop |
| swift-tree-primitives | 5 | 56 | Internal storage |

**Analysis**: All Tier 3+ packages use stdlib pointers for internal storage implementation. These are appropriate uses—internal machinery, not user-facing APIs.

### Usage Categories

#### Category 1: ManagedBuffer Interop

```swift
// withUnsafeMutablePointerToElements returns stdlib pointer
storage.withUnsafeMutablePointerToElements { elements in
    // elements: UnsafeMutablePointer<Element>
}
```

**Decision**: Keep as stdlib. ManagedBuffer API returns stdlib types.

#### Category 2: Inline Storage Arithmetic

```swift
// Small buffer optimization with raw pointer arithmetic
let rawPtr = UnsafeMutableRawPointer(mutating: &inlineStorage)
let elementPtr = rawPtr.advanced(by: offset).assumingMemoryBound(to: Element.self)
```

**Decision**: Keep as stdlib. Raw pointer arithmetic for inline storage is internal implementation detail.

#### Category 3: Cached Pointers

```swift
// Performance optimization: cache element pointer
private var _cachedElementPointer: UnsafeMutablePointer<Element>?
```

**Decision**: Keep as stdlib. Internal performance optimization, not API surface.

#### Category 4: `withUnsafe*Pointer` APIs

```swift
public func withUnsafeMutableBufferPointer<R>(
    _ body: (UnsafeMutableBufferPointer<Element>) throws -> R
) rethrows -> R
```

**Decision**: Keep as stdlib. Follows stdlib naming convention; users expect stdlib types.

#### Category 5: Conformance Extensions

```swift
extension UnsafeMutablePointer: SomeProtocol { ... }
```

**Decision**: Keep as stdlib. Extending stdlib types requires stdlib type names.

#### Category 6: View Types Internal Storage

```swift
struct View<Base> {
    let _base: UnsafeMutablePointer<Base>  // NOT Pointer<Base>.Mutable

    init(_ base: UnsafeMutablePointer<Base>) { ... }
}

// Enables clean syntax:
View(&self)
```

**Decision**: Keep as stdlib. The `&self` syntax produces `UnsafeMutablePointer<Self>` (compiler magic, not overloadable).

#### Category 7: User-Facing Stored Properties

```swift
public struct Transfer<T>.Box.Pointer {
    public let pointer: Pointer<T>.Mutable  // Non-null guarantee matters
}
```

**Decision**: **Migrate to primitives types**. User-facing APIs benefit from non-null guarantee and typed semantics.

### Comparison Summary

| Category | Count | Migration | Rationale |
|----------|-------|-----------|-----------|
| ManagedBuffer interop | ~200 | No | API returns stdlib |
| Inline storage | ~150 | No | Internal arithmetic |
| Cached pointers | ~100 | No | Internal optimization |
| withUnsafe* APIs | ~80 | No | Follows stdlib convention |
| Conformance extensions | ~50 | No | Extending stdlib types |
| View types | ~50 | No | `&self` syntax requirement |
| User-facing properties | ~10 | **Yes** | Non-null guarantee matters |

## Outcome

**Status**: DECISION

**Conclusion**: The 826 pointer occurrences are primarily **internal storage implementation** where stdlib pointers are appropriate. Primitives types are valuable for **user-facing APIs**, not internal machinery.

### Migration Actions Taken

| Package | Changes |
|---------|---------|
| swift-memory-primitives | Added `Memory.Address.Mutable`, `Buffer`, `Buffer.Mutable`; Range.Lazy integration |
| swift-pointer-primitives | `nonmutating _modify` for `Pointer.Mutable.pointee` (matches stdlib semantics) |
| swift-reference-primitives | Migrated to `Pointer<T>.Mutable`, `Memory.Address.Mutable`, typed offsets |

### No Migration Needed

| Package | Reason |
|---------|--------|
| swift-index-primitives | Interop extensions for stdlib pointers |
| swift-sequence-primitives | Doc comment example only |
| swift-collection-primitives | View types need `&self` syntax |
| swift-hash-primitives | Conformance extensions for stdlib types |
| All Tier 3+ packages | Internal storage implementation |

### Guidelines Established

**When to use primitives types**:
- Public stored properties representing pointers
- API parameters/returns exposing pointers to callers
- Types where non-null guarantee is part of the contract

**When to use stdlib types**:
1. **ManagedBuffer interop** - `withUnsafeMutablePointerToElements` returns stdlib pointers
2. **Inline storage** - Raw pointer arithmetic for small buffer optimization
3. **Cached pointers** - Performance optimization internal to storage
4. **`withUnsafe*Pointer` APIs** - Follows stdlib naming convention
5. **Conformance extensions** - Adding protocol conformance to stdlib pointer types
6. **View types** - Need clean `&self` syntax (produces `UnsafeMutablePointer`)

**Date**: 2026-01-26

## Type Mapping Reference

| stdlib | Primitives |
|--------|------------|
| `UnsafePointer<T>` | `Pointer<T>` |
| `UnsafeMutablePointer<T>` | `Pointer<T>.Mutable` |
| `UnsafeBufferPointer<T>` | `Pointer<T>.Buffer` |
| `UnsafeMutableBufferPointer<T>` | `Pointer<T>.Buffer.Mutable` |
| `UnsafeRawPointer` | `Memory.Address` |
| `UnsafeMutableRawPointer` | `Memory.Address.Mutable` |
| `UnsafeRawBufferPointer` | `Memory.Address.Buffer` |
| `UnsafeMutableRawBufferPointer` | `Memory.Address.Buffer.Mutable` |

## References

- Package-specific research: `swift-pointer-primitives/Research/pointer-mutable-pointee-semantics.md`
- [RES-001] Investigation Triggers
- [RES-004] Investigation Methodology
- [RES-004b] Scope Escalation (from package-specific to primitives-wide)
