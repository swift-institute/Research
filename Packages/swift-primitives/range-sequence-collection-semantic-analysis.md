# Range, Sequence, Collection Primitives: Semantic Analysis

<!--
Research ID: RES-014
Date: 2026-01-24
Status: Complete
-->

## Summary

This document captures the semantic relationships between `swift-range-primitives`, `swift-sequence-primitives`, and `swift-collection-primitives`, and documents design decisions made during the Property.View pattern integration.

**Key Decision**: `Range.Lazy<Bound>` does NOT conform to `Sequence.Protocol` due to SE-0427 constraints on `~Copyable` associated types.

---

## 1. Why Range.Lazy Cannot Conform to Sequence.Protocol

### The Constraint Incompatibility

```swift
// Sequence.Protocol requirement (implicit per SE-0427)
associatedtype Element  // Requires Copyable

// Range.Lazy design
struct Lazy<Bound: ~Copyable>  // Explicitly supports ~Copyable
```

When `Bound: ~Copyable`, `Range.Lazy` cannot satisfy `Sequence.Protocol` because:

1. `Sequence.Protocol.Element` would need to be `Bound`
2. `Bound: ~Copyable` violates the implicit `Element: Copyable` requirement

### Why Not Conditional Conformance?

We considered:

```swift
extension Range.Lazy: Sequence.Protocol where Bound: Copyable {
    typealias Element = Bound
}
```

**Rejected because**:
- Creates API asymmetry (some bounds get more features)
- May mislead users about primary use case (`~Copyable`)
- For `Copyable` bounds, users can bridge trivially: `(0..<n).lazy.map { transform($0) }`

---

## 2. Semantic Relationship Model

```
                     ┌─────────────────────────────────────┐
                     │        Abstract Iteration           │
                     │   "Things that can be traversed"    │
                     └─────────────────────────────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ▼                        ▼                        ▼
     ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
     │     Range       │    │    Sequence     │    │   Collection    │
     │                 │    │                 │    │                 │
     │ Bounded integer │    │  Single-pass    │    │  Indexed,       │
     │ intervals with  │    │  iteration via  │    │  multi-pass     │
     │ transformation  │    │  iterator       │    │  with subscript │
     └─────────────────┘    └─────────────────┘    └─────────────────┘
              │                        │                        │
              │                        ▼                        │
              │              ┌─────────────────┐                │
              │              │ Sequence.Protocol│                │
              │              └────────┬────────┘                │
              │                       │                         │
              │              ┌────────▼────────┐                │
              │              │Collection.Protocol│◄─────────────┘
              │              └─────────────────┘
              │
              ▼
     ┌─────────────────────────────────────────┐
     │            Range.Lazy<Bound>            │
     │                                         │
     │  Does NOT conform to Sequence.Protocol  │
     │  (designed for Bound: ~Copyable)        │
     └─────────────────────────────────────────┘
```

### Key Semantic Distinctions

| Aspect | Range.Lazy | Sequence.Protocol | Collection.Protocol |
|--------|------------|-------------------|---------------------|
| **Traversal** | Borrowing or draining | Single-pass via iterator | Multi-pass |
| **Element Source** | Generated via transform | Produced by iterator | Stored and indexed |
| **Element Access** | Borrowing or consuming | Typically copying | Subscript |
| **~Copyable Elements** | Full support | No (SE-0427) | No (use Collection.Indexed) |
| **~Copyable Container** | Yes | Yes | Yes |
| **Index Concept** | Integer position only | None | Associated Index type |
| **Finite** | Always (integer bounds) | Possibly infinite | Finite |

---

## 3. Design Decisions

### 3.1 Inline Nested Types for ~Copyable

**Problem**: When `Bound: ~Copyable`, nested types declared in extensions don't properly inherit the constraint.

**Solution**: Declare `Iterator` and `Reversed` inline within `Range.Lazy` struct body.

```swift
public struct Lazy<Bound: ~Copyable>: ~Copyable {
    // Declared inline - inherits Bound: ~Copyable
    public struct Iterator: ~Copyable { ... }
    public struct Reversed: ~Copyable { ... }
}
```

### 3.2 No Range.Iterable Protocol

**Problem**: SE-0427 prohibits `associatedtype Bound: ~Copyable` in protocols.

**Solution**: Remove protocol abstraction; constrain Property.View extensions directly on concrete types.

```swift
// Instead of protocol-based:
// extension Property.View where Base: Range.Iterable & ~Copyable

// Use concrete type constraints:
extension Property.View where Base: ~Copyable, Tag == Range.ForEach {
    public mutating func callAsFunction<Bound: ~Copyable>(
        _ body: (borrowing Bound) -> Void
    ) where Base == Range.Lazy<Bound> { ... }
}
```

### 3.3 Property.View Pattern Adoption

**Motivation**: API consistency with Sequence and Collection primitives.

**Before** (direct methods):
```swift
range.forEach { }  // consuming func
range.drain { }    // consuming func
```

**After** (Property.View pattern):
```swift
range.forEach { }           // Borrowing, range survives
range.forEach.borrowing { } // Explicit borrowing
range.drain { }             // Consuming, range becomes empty
```

**Semantic change**: `forEach` is now borrowing (range survives), not consuming.

### 3.4 Drain Semantics

**Definition**: Draining iterates and marks the range as empty (`start = end`).

| Operation | Before | After |
|-----------|--------|-------|
| `.forEach { }` | Range with N elements | Range with N elements (unchanged) |
| `.drain { }` | Range with N elements | Range with 0 elements (empty) |

---

## 4. Implementation Notes

### Files Modified/Created

| File | Purpose |
|------|---------|
| `Package.swift` | Added Property Primitives dependency |
| `Range.ForEach.swift` | Tag type for `.forEach` Property.View |
| `Range.Drain.swift` | Tag type for `.drain` Property.View |
| `Range.ForEach+Property.View.swift` | Borrowing iteration extensions |
| `Range.Drain+Property.View.swift` | Consuming iteration extensions |
| `Range.Lazy.swift` | Core type with inline Iterator, Reversed, and Property.View accessors |

### Swift 6 Language Features Used

- `~Copyable` types (SE-0390)
- `~Escapable` types
- `@Sendable` closures
- `@_lifetime` annotations
- `unsafe` blocks (strict memory safety)
- `borrowing` and `consuming` parameters

---

## 5. Cross-Package Consistency

### Naming Convention Compliance

All follow [API-NAME-001] `Nest.Name` pattern:

| Package | Examples |
|---------|----------|
| Range | `Range.Lazy`, `Range.ForEach`, `Range.Drain` |
| Sequence | `Sequence.Protocol`, `Sequence.ForEach`, `Sequence.Drain` |
| Collection | `Collection.Protocol`, `Collection.Indexed` |

### Operation Pattern Alignment

| Operation | Range | Sequence | Collection |
|-----------|-------|----------|------------|
| Borrowing iteration | `.forEach { }` | `.forEach { }` | `.forEach { }` |
| Consuming iteration | `.drain { }` | `.forEach.consuming { }` | `.forEach.consuming { }` |

**Note**: Range uses `.drain { }` directly because the semantics differ from clearing a container.

---

## 6. Future Considerations

1. **Swift evolution**: If SE-0427 is relaxed to allow `~Copyable` associated types, `Range.Iterable` protocol could be reconsidered.

2. **Collection.Indexed integration**: `Range.Lazy<Index>` could potentially be used for index iteration in `Collection.Indexed`.

3. **Swift.Sequence bridge**: A conditional conformance `where Bound: Copyable` could be added for stdlib interop if demanded.

---

## References

- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
- Swift Institute Documentation: `/Users/coen/Developer/swift-institute/Documentation.docc/`
