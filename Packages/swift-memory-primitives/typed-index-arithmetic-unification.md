# Research: Typed Index Arithmetic Unification

<!--
---
version: 2.0.0
last_updated: 2026-01-29
status: DECISION
scope: primitives-wide
tier: 2
affects: [swift-index-primitives, swift-input-primitives]
tags: [architecture, arithmetic, typed-indices]
---
-->

## Context

During implementation of `Input.Protocol.advance(by:)`, we discovered a design tension:

1. The typed index system (`Index<T>`, `Index<T>.Count`, `Index<T>.Offset`) provides rich arithmetic
2. But conformance implementations use `Storage.Index` (stdlib indices like `Int`)
3. This forces wrapper methods like `Int(bitPattern: count)` at the boundary

**Trigger**: The observation that `Int(bitPattern: count)` is ceremony that shouldn't be needed.

## Question

How should typed index arithmetic integrate with stdlib collection indices to enable inline expressions without wrapper ceremony?

## Current State Inventory

### Typed Index Arithmetic (Complete)

The primitives packages provide comprehensive arithmetic:

| Expression | Result | Package | Total? |
|------------|--------|---------|--------|
| `Index<T> + Index<T>.Count` | `Index<T>` | ordinal-primitives | ✅ Total |
| `Index<T> + Index<T>.Offset` | `Index<T>` | affine-primitives | Throws |
| `Index<T> - Index<T>.Offset` | `Index<T>` | affine-primitives | Throws |
| `Index<T> - Index<T>` | `Index<T>.Offset` | affine-primitives | Throws |
| `Index<T> % Index<T>.Count` | `Index<T>` | ordinal-primitives | ✅ Total |
| `Index<T> < Index<T>.Count` | `Bool` | ordinal-primitives | ✅ Total |
| `Index<T>.Count + Index<T>.Count` | `Index<T>.Count` | cardinal-primitives | ✅ Total |
| `Index<T>.Offset + Index<T>.Offset` | `Index<T>.Offset` | affine-primitives | ✅ Total |

### Stdlib Integration (Gaps)

| Need | Current | Gap |
|------|---------|-----|
| `collection.index(i, offsetBy: Index<T>.Offset)` | Overload exists | ✅ Works |
| `collection.index(i, offsetBy: Index<T>.Count)` | Not defined | ❌ Must use `Int(bitPattern:)` |
| `Int + Index<T>.Count` | Not defined | ❌ Must convert |
| `Storage.Index + Index<T>.Count` | Not defined | ❌ Generic gap |

### The Boundary Problem

In `Input.Buffer`:
```swift
public struct Buffer<Storage: RandomAccessCollection>
where Storage.Index: Sendable & Hashable {
    var position: Storage.Index  // This is Int, String.Index, etc.
}
```

When implementing `advance(by count: Index<Element>.Count)`:
```swift
// Current: explicit conversion ceremony
position = storage.index(position, offsetBy: Int(bitPattern: count))

// Desired: inline arithmetic
position = position + count  // ❌ No operator defined
```

The issue: `Storage.Index` is opaque — it could be `Int`, `String.Index`, or any `Comparable` type. We can't define `Storage.Index + Index<T>.Count` generically.

## Options

### Option A: Accept Conversion at Boundary

**Status Quo**: Typed index arithmetic works within the typed world; explicit conversion at stdlib boundaries.

```swift
// Conformance implementation
position = storage.index(position, offsetBy: Int(bitPattern: count))
```

**Advantages**:
- Clear separation between typed and untyped worlds
- No implicit conversions hiding intent
- Works with any `Storage.Index` type

**Disadvantages**:
- Verbose at boundaries
- `Int(bitPattern:)` feels like ceremony

### Option B: Add Collection Overloads

Add `index(_:offsetBy: Index<T>.Count)` to Collection protocols.

```swift
extension RandomAccessCollection {
    func index<T>(_ i: Index, offsetBy count: Index<T>.Count) -> Index
}
```

**Advantages**:
- Cleaner call sites: `storage.index(position, offsetBy: count)`

**Disadvantages**:
- Adds API surface to Collection
- Conversion still happens, just hidden in the overload
- Doesn't help with direct arithmetic (`position + count`)

### Option C: Position as Typed Index

Redesign `Input.Buffer` to use typed positions:

```swift
public struct Buffer<Storage: RandomAccessCollection> {
    var position: Index<Storage.Element>  // Typed!
    // Need: conversion to/from Storage.Index for subscripting
}
```

**Advantages**:
- Full typed arithmetic: `position + count` works directly
- Type safety throughout

**Disadvantages**:
- Adds conversion overhead at every subscript
- Loses direct `Storage.Index` interop
- Significant redesign of Input.Buffer/Slice

### Option D: Typed Wrapper Protocol

Define a protocol that wraps stdlib indices with typed arithmetic:

```swift
protocol TypedIndexable {
    associatedtype Element
    associatedtype RawIndex: Comparable

    func index(_ i: RawIndex, offsetBy count: Index<Element>.Count) -> RawIndex
}

extension RandomAccessCollection: TypedIndexable {
    func index(_ i: Index, offsetBy count: Index<Element>.Count) -> Index {
        index(i, offsetBy: Int(bitPattern: count))
    }
}
```

**Advantages**:
- Clean call sites
- Works with existing types
- Conversion encapsulated

**Disadvantages**:
- Another protocol layer
- Still doesn't enable `position + count` syntax

### Option E: Int Arithmetic with Count/Offset

Define arithmetic operators on `Int`:

```swift
extension Int {
    static func + <T>(lhs: Int, rhs: Index<T>.Count) -> Int {
        lhs + Int(bitPattern: rhs)
    }
}
```

**Advantages**:
- Enables `position + count` when position is Int
- Most common case (Array, ContiguousArray)

**Disadvantages**:
- Only works when `Storage.Index == Int`
- Pollutes Int with typed index concerns
- Cross-package dependency concerns

### Option F: Generic Strideable Arithmetic

Since `RandomAccessCollection.Index: Strideable`, leverage that:

```swift
extension Strideable where Stride == Int {
    static func + <T>(lhs: Self, rhs: Index<T>.Count) -> Self {
        lhs.advanced(by: Int(bitPattern: rhs))
    }
}
```

**Advantages**:
- Works with any Strideable index
- Enables `position + count` generically

**Disadvantages**:
- Not all `RandomAccessCollection.Index` is `Strideable where Stride == Int`
- Adds operators to stdlib types
- May cause ambiguity

## Analysis

### Semantic Model

The typed index system models a **1-dimensional affine space**:
- **Points** (`Index<T>` = `Tagged<T, Ordinal>`): positions
- **Vectors** (`Index<T>.Offset` = `Tagged<T, Vector>`): displacements
- **Scalars** (`Index<T>.Count` = `Tagged<T, Cardinal>`): magnitudes

Arithmetic follows affine geometry laws:
- Point + Vector → Point
- Point - Point → Vector
- Point + Count → Point (Count is a non-negative Vector)

The **stdlib indices** (`Int`, `String.Index`) are **not** part of this type system. They exist in a parallel world.

### Key Insight

The real question is: **Where does the type boundary live?**

| Approach | Boundary Location |
|----------|-------------------|
| Option A | At every conformance implementation |
| Option B | Hidden in Collection overload |
| Option C | At subscript operations |
| Option D | In a protocol adapter |
| Option E/F | At Int/Strideable extension |

### Recommendation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Expression clarity | High | Can we write `position + count`? |
| Type safety | High | Are phantom types preserved? |
| Minimal API surface | Medium | How many overloads/extensions added? |
| Generality | Medium | Works with all collection types? |
| Minimal conversion | Medium | How much ceremony at boundaries? |

## Preliminary Assessment

**Option A (Accept Conversion)** is the most principled but verbose.

**Option F (Strideable Arithmetic)** enables the cleanest expressions when `Storage.Index: Strideable where Stride == Int`, which covers `Array`, `ContiguousArray`, and most common cases.

**Hybrid Approach**: Accept Option A as the general case, but provide Option F for the common case of Int-strided indices.

## Open Questions

1. Is `Strideable where Stride == Int` broad enough to cover practical use cases?
2. Should these operators live in index-primitives or a separate integration package?
3. Does adding `Int + Index<T>.Count` create ambiguity with existing overloads?
4. Should we prioritize `position + count` over `collection.index(position, offsetBy: count)`?

## Decision: Typed Position as Primary

**CONFIRMED** via experiment `/swift-primitives/Experiments/typed-index-boundary/`

### The Pattern

Store `Index<Element>` as the primary representation. Derive `Storage.Index` only at subscript boundaries.

```swift
struct IdealCursor<Base: RandomAccessCollection> {
    let base: Base
    private(set) var position: Index<Base.Element>  // PRIMARY

    // Pure typed arithmetic - no conversions!
    mutating func advance(by count: Index<Base.Element>.Count) {
        position = position + count  // Uses existing Index + Count operator
    }

    // Conversion encapsulated here ONLY
    private var rawIndex: Base.Index {
        base.index(base.startIndex, offsetBy: Int(bitPattern: position))
    }

    var first: Base.Element? {
        guard !isEmpty else { return nil }
        return base[rawIndex]  // Single conversion point
    }
}
```

### Why This Works

1. **No dual tracking**: Single source of truth (`position: Index<Element>`)
2. **Pure typed arithmetic**: `position + count` uses existing operators from ordinal-primitives
3. **Encapsulated conversion**: `Int(bitPattern:)` appears once in `rawIndex` getter
4. **O(1) for RandomAccessCollection**: `index(_:offsetBy:)` is constant time
5. **No new operators needed**: Leverages existing `Index<T> + Index<T>.Count` from `Tagged+Ordinal.swift:93-95`

### Application to Input.Buffer

Current:
```swift
var position: Storage.Index  // stdlib type
mutating func advance(by count: Index<Element>.Count) {
    position = storage.index(position, offsetBy: Int(bitPattern: count))
}
```

Recommended:
```swift
var position: Index<Element>  // typed!
mutating func advance(by count: Index<Element>.Count) {
    position = position + count  // pure typed arithmetic
}
private var rawIndex: Storage.Index {
    storage.index(storage.startIndex, offsetBy: Int(bitPattern: position))
}
```

### Trade-offs

| Aspect | Current (Storage.Index) | Recommended (Index<Element>) |
|--------|------------------------|------------------------------|
| Arithmetic | Requires `Int(bitPattern:)` | Pure typed: `position + count` |
| Subscript | Direct | Via `rawIndex` getter |
| Subscript cost | O(1) | O(1) for RandomAccessCollection |
| Source of truth | Raw index | Typed index |
| Conversion location | In arithmetic | In subscript |

## Implementation

**Implemented**: 2026-01-29

Files changed:
- `swift-input-primitives/Sources/Input Primitives/Input.Buffer.swift` — position now `Index<Element>`
- `swift-input-primitives/Sources/Input Primitives/Input.Buffer+Input.Protocol.swift` — typed arithmetic
- `swift-input-primitives/Sources/Input Primitives/Input.Slice.swift` — position now `Index<Element>`
- `swift-input-primitives/Sources/Input Primitives/Input.Slice+Input.Protocol.swift` — typed arithmetic
- `swift-index-primitives/Skills/index/SKILL.md` — added [IDX-006a], [IDX-006b]

## References

- `Tagged+Ordinal.swift:87-101` — `Index<T> + Index<T>.Count` definition
- `Tagged+Affine.swift:132-159` — `Index<T> ± Index<T>.Offset` definitions
- `Input.Buffer+Input.Protocol.swift:64-67` — current boundary conversion
- `Index+RandomAccessCollection.swift` — existing Offset overload
