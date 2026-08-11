# Strideable Conformance for Phantom-Typed Index and Count
<!--
---
version: 1.0.0
last_updated: 2026-01-28
status: DECISION
---
-->

**Abstract.** This paper examines the design considerations for adding `Strideable` conformance to phantom-typed index types in Swift. We analyze the semantic model distinguishing positions (Index) from magnitudes (Count), explore why `Strideable` is appropriate for positions but not magnitudes, and document the fundamental tension between Swift's iteration infrastructure and move-only (`~Copyable`) types. We conclude that while the semantic model is sound, practical implementation requires either constraining iteration to `Copyable` phantom tags or adopting raw-value iteration patterns for move-only contexts.

---

## 1. Introduction

The `Index<Tag>` type represents a phantom-typed position in discrete space, providing compile-time safety against cross-collection index confusion. Its companion type `Index<Tag>.Count` represents a magnitude—the cardinality of a collection. These types follow affine space semantics from category theory, where positions and displacements are distinct mathematical objects with constrained operations.

When iterating over collection indices, a natural question arises: should these types conform to `Strideable`? And if so, which types should conform? This paper examines the semantic and practical considerations that inform this design decision.

## 2. Affine Space Model

### 2.1 Semantic Roles

The index system models discrete affine space with three distinct types:

| Type | Semantic Role | Affine Analog | Example |
|------|---------------|---------------|---------|
| `Index<Tag>` | Position (where) | Point | "element at position 5" |
| `Index<Tag>.Offset` | Displacement (how far) | Vector | "3 positions forward" |
| `Index<Tag>.Count` | Magnitude (how many) | Scalar/Distance | "collection has 10 elements" |

### 2.2 Permitted Operations

Affine geometry constrains which operations are meaningful:

```
Position + Displacement → Position    (translation)
Position - Displacement → Position    (translation)
Position - Position     → Displacement (difference)
Displacement ± Displacement → Displacement (vector arithmetic)
Position + Position     → undefined   (intentionally unsupported)
```

This model is implemented in the existing arithmetic operators:

```swift
// Index + Offset → Index? (Point + Vector → Point)
public func + <Tag: ~Copyable>(
    lhs: Index<Tag>,
    rhs: Index<Tag>.Offset
) -> Index<Tag>?

// Index - Index → Offset (Point - Point → Vector)
public func - <Tag: ~Copyable>(
    lhs: Index<Tag>,
    rhs: Index<Tag>
) -> Index<Tag>.Offset
```

## 3. Strideable: Semantic Analysis

### 3.1 What Strideable Means

Swift's `Strideable` protocol models values that can be offset by a stride and measured for distance:

```swift
protocol Strideable: Comparable {
    associatedtype Stride: SignedNumeric, Comparable
    func advanced(by n: Stride) -> Self
    func distance(to other: Self) -> Stride
}
```

The key semantic: `Strideable` types represent **positions that can be traversed**. You "walk through" a strideable space by steps.

### 3.2 Index Should Be Strideable

`Index<Tag>` represents a position. Striding through positions is semantically valid:

```swift
extension Index: Strideable where Tag: ~Copyable {
    public typealias Stride = Int

    public func advanced(by n: Stride) -> Self {
        let newPosition = position.rawValue + n
        precondition(newPosition >= 0, "Index cannot be negative")
        return Self(__unchecked: (), position: newPosition)
    }

    public func distance(to other: Self) -> Stride {
        other.position - position.rawValue
    }
}
```

**Note on the precondition:** While `Index` is non-negative by construction (the validated initializer throws on negative values), `advanced(by:)` performs arithmetic that could violate this invariant. The precondition maintains the type's safety guarantee at runtime, consistent with how `Int.advanced(by:)` can overflow and trap.

### 3.3 Count Should NOT Be Strideable

`Count` represents a magnitude—"how many," not "where." You don't "walk through" counts; you measure them.

Consider the semantic confusion if `Count` were strideable:

```swift
// What does this mean?
let count: Index<Node>.Count = 5
for c in stride(from: .zero, to: count, by: 1) {
    // c is a Count... but we want Index values for subscripting
}
```

Striding over counts produces more counts, but iteration typically wants indices (positions). The semantic mismatch indicates `Count` should not be `Strideable`.

### 3.4 The Principled Design

The correct abstraction:

1. **`Index` is `Strideable`** — positions can be traversed
2. **`Count` is NOT `Strideable`** — magnitudes are not positions
3. **`Count` provides `indices`** — converts magnitude to range of positions

```swift
extension Index<Tag>.Count where Tag: Copyable {
    /// The range of valid indices for this count.
    public var indices: Range<Index<Tag>> {
        Index<Tag>.zero ..< Index<Tag>(self)
    }
}
```

This respects the affine model: `Count` (magnitude) → `Range<Index>` (positions).

## 4. The Copyable Constraint Problem

### 4.1 Swift's Iteration Infrastructure

Swift's `Range<Bound>` and iteration infrastructure have implicit requirements:

```swift
public struct Range<Bound: Comparable> {
    public let lowerBound: Bound  // stored property
    public let upperBound: Bound  // stored property
}
```

For `Range` to be usable:
- `Bound` must be `Comparable` (explicit)
- `Bound` must be `Copyable` (implicit, for storage and iteration)

Similarly, `Sequence` and `IteratorProtocol` assume copyable elements.

### 4.2 Phantom Types and Copyability

`Index<Tag>` is defined as:

```swift
public typealias Index<Tag: ~Copyable> = Tagged<Tag, Affine.Discrete.Position>
```

The `Tagged` type's copyability depends on both parameters:

```swift
extension Tagged: Copyable where Tag: Copyable, RawValue: Copyable {}
```

Since `Affine.Discrete.Position` is always `Copyable`, `Index<Tag>` is copyable if and only if `Tag` is copyable.

### 4.3 The Fundamental Tension

For `~Copyable` element types (e.g., `Array<FileHandle>` where `FileHandle: ~Copyable`):

- `Index<FileHandle>` is `~Copyable` (because `FileHandle` is)
- `Range<Index<FileHandle>>` is invalid (Range requires Copyable bounds)
- Standard iteration patterns fail

This creates an impedance mismatch: the semantic model (striding over positions) is sound, but Swift's runtime machinery cannot express it for move-only types.

## 5. Attempted Solutions and Their Failures

### 5.1 LazyMapSequence

One approach: return a lazy sequence over raw integers:

```swift
extension Index<Tag>.Count where Tag: ~Copyable {
    public var indices: LazyMapSequence<Range<Int>, Index<Tag>> {
        (0..<rawValue).lazy.map {
            Index<Tag>(__unchecked: (), position: $0)
        }
    }
}
```

**Failure:** `LazyMapSequence<Base, Element>` requires `Element: Copyable`. The mapped-to type `Index<Tag>` is not copyable when `Tag: ~Copyable`.

### 5.2 Opaque Return Type

```swift
public var indices: some Sequence<Index<Tag>> { ... }
```

**Failure:** `Sequence.Element` implicitly requires `Copyable`. The `some` wrapper doesn't escape this constraint.

### 5.3 Custom Iterator

A non-copyable iterator could theoretically work:

```swift
public struct IndexIterator<Tag: ~Copyable>: ~Copyable {
    var current: Int
    let end: Int

    mutating func next() -> Index<Tag>? {
        guard current < end else { return nil }
        defer { current += 1 }
        return Index<Tag>(__unchecked: (), position: current)
    }
}
```

**Partial Success:** This compiles, but cannot conform to `IteratorProtocol` (which requires `Copyable`), so it cannot be used with `for-in` loops.

## 6. Practical Recommendations

### 6.1 For Copyable Tags: Use `indices`

When `Tag: Copyable`, the full abstraction works:

```swift
extension Index<Tag>.Count where Tag: Copyable {
    public var indices: Range<Index<Tag>> {
        Index<Tag>.zero ..< Index<Tag>(self)
    }
}

// Usage
let count: Index<Node>.Count = 5
for i in count.indices {
    print(array[i])  // i is Index<Node>
}
```

### 6.2 For ~Copyable Tags: Use Raw Iteration

When `Tag: ~Copyable`, users must iterate with raw values:

```swift
let count: Index<FileHandle>.Count = 5
for i in 0..<count.rawValue {
    let idx = Index<FileHandle>(__unchecked: (), position: i)
    array.withElement(at: idx) { handle in
        // use handle
    }
}
```

This is verbose but unavoidable given Swift's current type system.

### 6.3 Documentation Pattern

The API should document this constraint clearly:

```swift
/// The range of valid indices for this count.
///
/// - Note: Only available when `Tag` is `Copyable` because Swift's `Range`
///   requires copyable bounds. For `~Copyable` tags, iterate raw values:
///   ```swift
///   for i in 0..<count.rawValue {
///       let idx = Index(__unchecked: (), position: i)
///       // use idx
///   }
///   ```
@inlinable
public var indices: Range<Index<Tag>> where Tag: Copyable { ... }
```

## 7. Future Directions

### 7.1 Swift Evolution

Swift's ownership model is evolving. Future proposals may introduce:

- Non-copyable sequence/iterator protocols
- `for-in` support for `~Copyable` iterators
- `borrowing` iteration patterns built into the language

These would enable the semantic model to be fully realized.

### 7.2 Span-Based Iteration

The `Span<T>` type (available in recent Swift versions) provides borrowing access to contiguous memory and may offer iteration patterns that work with `~Copyable` elements:

```swift
extension Array where Element: ~Copyable {
    public var span: Span<Element> { ... }
}

// Span may eventually support for-in with borrowing semantics
```

### 7.3 Closure-Based Iteration

An alternative pattern that works today:

```swift
extension Index<Tag>.Count where Tag: ~Copyable {
    @inlinable
    public func forEach(_ body: (Index<Tag>) -> Void) {
        for i in 0..<rawValue {
            body(Index<Tag>(__unchecked: (), position: i))
        }
    }
}
```

This provides type-safe iteration without requiring `Range<Index<Tag>>`.

## 8. Conclusion

The semantic model is clear: `Index` (position) should be `Strideable`; `Count` (magnitude) should not. The `indices` property on `Count` correctly bridges from magnitude to position range.

However, Swift's iteration infrastructure fundamentally assumes copyable values. For phantom-typed indices where the tag is `~Copyable`, this creates an unbridgeable gap between the semantic model and practical implementation.

The recommended approach:

1. Provide `Strideable` conformance for `Index<Tag>` (all tags)
2. Provide `indices` property on `Count` only for `Tag: Copyable`
3. Document raw-value iteration as the pattern for `~Copyable` tags
4. Monitor Swift Evolution for non-copyable iteration support

This balances semantic correctness with practical usability, accepting that full expressiveness awaits future language evolution.

---

## References

1. Swift Evolution SE-0390: Noncopyable structs and enums
2. Swift Evolution SE-0437: Non-copyable Standard Library Primitives
3. Swift Standard Library: `Strideable` protocol documentation
4. Affine Space (mathematics): Wikipedia
5. Swift Forums: Discussion on non-copyable iteration patterns

---

*Swift Primitives Project — January 2026*
