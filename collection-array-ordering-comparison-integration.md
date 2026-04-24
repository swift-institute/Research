<!-- SUPERSEDED: No implementation exists. Analysis captured in Ordered Dictionary design. -->

# Collection/Array Primitives Integration with Comparison/Ordering Primitives

## Experiment Discovery Analysis

**Date**: 2026-01-22
**Question**: How should swift-collection-primitives and swift-array-primitives relate to ordering/comparison-primitives?

---

## Package Analysis

### swift-collection-primitives (Tier 3)

**Current dependencies**:
- comparison-primitives (Tier 1) ✓
- index-primitives (Tier 1)
- property-primitives (Tier 0)
- sequence-primitives (Tier 2)

**Current operations**:
| Tag | Operations |
|-----|------------|
| `Collection.ForEach` | `.forEach { }`, `.forEach.borrowing { }`, `.forEach.consuming { }` |
| `Collection.Map` | `.map { }` |
| `Collection.Filter` | `.filter { }` |
| `Collection.Reduce` | `.reduce { }` |
| `Collection.Contains` | `.contains { }` |
| `Collection.First` | `.first { }` |
| `Collection.Satisfies` | `.satisfies { }` |
| `Collection.Count` | `.count` |

**Protocols**:
- `Collection.Protocol` - basic iteration
- `Collection.Indexed` - index navigation
- `Collection.Bidirectional` - bidirectional index navigation
- `Collection.Access.Random` - O(1) index access
- `Collection.Clearable` - can be cleared for consuming iteration

**Ordering-related operations**: NONE

### swift-array-primitives (Tier 7)

**Current dependencies**:
- collection-primitives (Tier 3) → transitively gets comparison-primitives
- index-primitives (Tier 1)
- bit-primitives (Tier 6)
- standard-library-extensions (Tier 0)

**Array types**:
- `Array.Unbounded` - heap-allocated, growable
- `Array.Bounded` - stack-allocated, fixed max capacity
- `Array.Inline` - inline storage only, fixed capacity
- `Array.Small` - inline storage with heap overflow
- `Array.Bit.Packed.*` - bit arrays

**Ordering-related operations**: NONE

---

## Discovered Duplication: heap-primitives

**Critical finding**: heap-primitives (Tier 9) defines its own `Heap.Ordering` protocol that duplicates `Comparison.Protocol`:

```swift
// heap-primitives/Heap.swift
public protocol __HeapOrdering: ~Copyable {
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}
```

This is semantically equivalent to:

```swift
// comparison-primitives
public protocol `Protocol`: ~Copyable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}
```

**Recommendation**: heap-primitives should depend on comparison-primitives and use `Comparison.Protocol` instead of defining its own protocol.

---

## Integration Opportunities

### 1. Collection.Extrema (Min/Max) - RECOMMENDED

**Location**: collection-primitives (can use existing comparison-primitives dependency)

```swift
extension Collection {
    /// Tag type for `.extrema` property extensions (min/max).
    public enum Extrema {}
}

extension Property.View
where Base: Collection.`Protocol` & ~Copyable, Tag == Collection.Extrema {

    /// Find minimum element by comparator.
    public func min(by comparator: Ordering.Comparator<Base.Element>) -> Base.Element?

    /// Find maximum element by comparator.
    public func max(by comparator: Ordering.Comparator<Base.Element>) -> Base.Element?

    /// Find both min and max in single pass.
    public func minMax(by comparator: Ordering.Comparator<Base.Element>)
        -> (min: Base.Element, max: Base.Element)?
}

// Convenience for Comparison.Protocol elements
extension Property.View
where Base: Collection.`Protocol` & ~Copyable,
      Base.Element: Comparison.`Protocol` & ~Copyable,
      Tag == Collection.Extrema {

    public func min() -> Base.Element?
    public func max() -> Base.Element?
}
```

**Requires**: Add ordering-primitives dependency to collection-primitives

### 2. Array.Sort - DEFERRED

**Location**: array-primitives OR new swift-sort-primitives package

Sorting requires careful consideration:
- In-place sorting mutates the array
- ~Copyable elements require move-based swaps
- Multiple algorithm choices (quicksort, mergesort, heapsort, timsort)

**Options**:
- A. Add `Array.Sort` tag to array-primitives (add ordering-primitives dependency)
- B. Create dedicated swift-sort-primitives package at Tier 8+

**Recommendation**: Defer until use case demands. Array types can be sorted through stdlib conformance via `Swift.MutableCollection.sort()` for Copyable elements.

### 3. Collection.Binary (Binary Search) - OPTIONAL

**Location**: collection-primitives (requires Access.Random for efficiency)

```swift
extension Collection {
    public enum Binary {}
}

extension Property.View
where Base: Collection.Access.Random & ~Copyable, Tag == Collection.Binary {

    /// Binary search for partition point.
    public func partition(where predicate: (borrowing Base.Element) -> Bool) -> Base.Index

    /// Binary search for element.
    public func search(for element: borrowing Base.Element,
                       by comparator: Ordering.Comparator<Base.Element>) -> Base.Index?
}
```

**Requires**: Add ordering-primitives dependency to collection-primitives

### 4. Heap.Ordering Refactor - RECOMMENDED

**Location**: heap-primitives

Replace custom `__HeapOrdering` protocol with `Comparison.Protocol`:

```swift
// Before
public struct Heap<Element: ~Copyable & __HeapOrdering>: ~Copyable

// After
public struct Heap<Element: ~Copyable & Comparison.`Protocol`>: ~Copyable
```

**Requires**: Add comparison-primitives dependency to heap-primitives

---

## Dependency Changes Summary

| Package | Current | Proposed Addition | Rationale |
|---------|---------|-------------------|-----------|
| collection-primitives | comparison-primitives | ordering-primitives | Enable min/max, binary search |
| array-primitives | (via collection) | ordering-primitives (optional) | Enable sorting (if implemented) |
| heap-primitives | NONE | comparison-primitives | Replace Heap.Ordering with Comparison.Protocol |

---

## Tier Verification

All proposed dependencies flow downward (valid):

```
Tier 0: property-primitives
Tier 1: comparison-primitives, ordering-primitives, index-primitives
Tier 2: sequence-primitives
Tier 3: collection-primitives (can depend on Tier 0-2)
        ↓ add ordering-primitives (Tier 1) ✓
Tier 7: array-primitives (can depend on Tier 0-6)
        ↓ add ordering-primitives (Tier 1) ✓
Tier 9: heap-primitives (can depend on Tier 0-8)
        ↓ add comparison-primitives (Tier 1) ✓
```

---

## Recommendations

### Immediate Actions

1. **Add ordering-primitives dependency to collection-primitives** and implement `Collection.Extrema` (min/max)

2. **Add comparison-primitives dependency to heap-primitives** and refactor to use `Comparison.Protocol` instead of `Heap.Ordering`

### Deferred Actions

3. **Collection.Binary** - implement binary search when needed

4. **Array.Sort** - implement sorting when needed (consider if stdlib conformance is sufficient)

---

## Non-Recommendations

**DO NOT add sorting to collection-primitives**: Sorting is a mutable operation that doesn't fit the read-focused collection protocols. Arrays handle mutation.

**DO NOT add ordering-primitives dependency to array-primitives yet**: Wait for concrete sorting use case. Copyable elements can use stdlib sorting.
