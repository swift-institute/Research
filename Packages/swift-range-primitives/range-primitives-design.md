# Range Primitives Design: First-Class ~Copyable and Copyable Support

<!--
---
version: 1.1.0
last_updated: 2026-01-25
status: DECISION
tier: 3
---
-->

## Context

The Swift Institute's swift-range-primitives package provides iteration primitives for `~Copyable` bound types, addressing limitations in Swift's standard library where `Range<Bound>` requires `Bound: Strideable` (implying `Copyable`) for iteration.

**Current State**: `Range.Lazy<Bound: ~Copyable>` exists with:
- `forEach` (borrowing iteration)
- `drain` (consuming iteration)
- `makeIterator()` (manual iteration)
- `reversed()` (reverse iteration)
- Custom operator `0..<count` for `Index<Tag>.Count`

**Trigger**: Design audit to determine if the current design represents the "perfect" range primitives for the Swift Institute ecosystem, with comprehensive ~Copyable and Copyable support.

**Scope**: Ecosystem-wide (Tier 3) — establishes foundational range semantics for all Swift Institute packages.

**Semantic Commitment**: Range primitives are a foundational abstraction. Design decisions here propagate to swift-sequence-primitives, swift-collection-primitives, swift-array-primitives, and all downstream packages.

---

## Question

What does a perfect range-primitives package look like for the Swift Institute ecosystem, with first-class support for both `~Copyable` and `Copyable` bound types?

---

## Prior Art Survey [RES-021]

### Swift Standard Library

Swift provides five range types unified under `RangeExpression`:

| Type | Syntax | Semantics |
|------|--------|-----------|
| `Range<Bound>` | `a..<b` | Half-open: `[a, b)` |
| `ClosedRange<Bound>` | `a...b` | Closed: `[a, b]` |
| `PartialRangeUpTo<Bound>` | `..<b` | One-sided: `(-∞, b)` |
| `PartialRangeThrough<Bound>` | `...b` | One-sided: `(-∞, b]` |
| `PartialRangeFrom<Bound>` | `a...` | One-sided: `[a, ∞)` |

**Iteration Constraints**:
- Requires `Bound: Strideable where Stride: SignedInteger`
- `Strideable` implies `Copyable`
- `Sequence` and `Collection` protocols require `Copyable` elements (SE-0427)

**Key Evolution**:
- SE-0172: One-Sided Ranges (Swift 4)
- SE-0270: RangeSet and Collection Operations (Swift 6.0)

### Rust RFC 3550: New Range Types

**Problem Rust Addressed**: Legacy ranges (`Range`, `RangeFrom`, `RangeInclusive`) implement `Iterator` directly, preventing `Copy`.

**Rust's Solution**:
- Separate ranges from iterators
- New range types implement `Copy` + `IntoIterator`
- Dedicated iterator types (`IterRange`, `IterRangeInclusive`)
- `RangeInclusive` redesigned to eliminate `exhausted: bool` field

**Most-Used Range Methods** (GitHub analysis):
| Method | Usage Count |
|--------|-------------|
| `map` | 65.8k |
| `rev` | 23.2k |
| `collect` | 9.9k |
| `for_each` | 8.5k |
| `step_by` | 8.3k |
| `filter` | 8.2k |

**Key Insight**: Small ergonomic cost for iterator adaptor chaining is acceptable if it enables `Copy` semantics.

### Haskell Linear Types (GHC 9.0+)

```haskell
-- Ranges consumed via folds, not mutable iteration
foldRange :: (a -> b -> b) -> b -> Range a -> b
```

Haskell avoids mutable iteration entirely; ranges are consumed via higher-order functions.

### C++ std::ranges (C++20)

- Separates ranges (containers with begin/end) from views (lazy adaptations)
- `std::views::iota(0, n)` creates lazy integer range
- Composability via `|` operator
- Move-only types use generators (`std::generator<T>`)

---

## Theoretical Grounding [RES-022]

### Affine Type Theory

Swift's `~Copyable` corresponds to **affine types** in substructural type systems:

| Type System | Contraction | Weakening | Property |
|-------------|-------------|-----------|----------|
| Linear | ✗ | ✗ | Must use exactly once |
| **Affine** | ✗ | ✓ | May use at most once |
| Relevant | ✓ | ✗ | Must use at least once |
| Unrestricted | ✓ | ✓ | Standard copying |

**Iteration Challenge**: Traditional `for-in` loops implicitly copy iterator state and elements. For affine types:
- Iterator must be consumed (moved) at each step
- Elements cannot be copied out; must be borrowed or consumed

### Range as Interval Abstraction

Mathematical interval notation provides semantic foundation:

| Notation | Range Type | Swift Equivalent |
|----------|------------|------------------|
| `[a, b)` | Half-open | `Range<Bound>` |
| `[a, b]` | Closed | `ClosedRange<Bound>` |
| `(-∞, b)` | Unbounded left, open right | `PartialRangeUpTo<Bound>` |
| `(-∞, b]` | Unbounded left, closed right | `PartialRangeThrough<Bound>` |
| `[a, ∞)` | Bounded left, unbounded right | `PartialRangeFrom<Bound>` |

### The Index Domain Concept

A critical conceptual foundation for Range.Lazy is the separation between:

1. **Index Domain**: A `Copyable` integer interval `[start, end)` over which iteration proceeds
2. **Bound Projection**: A transform function `(Int) -> Bound` that generates `~Copyable` values on demand

This separation is not incidental — it is the architectural core that enables ~Copyable range iteration:

| Aspect | Index Domain | Bound Projection |
|--------|--------------|------------------|
| Type | `Int` (always Copyable) | `Bound: ~Copyable` |
| Storage | Stored directly | Never stored |
| Iteration state | Trivial integer increment | Regenerated each access |
| Count computation | O(1): `end - start` | Not applicable |
| Reversal | Trivial: iterate `[end-1, start]` | Same transform, reversed order |

**Key Insight**: The index domain provides all the mechanics (counting, stepping, reversing, subscripting), while the projection provides the semantics (typed bounds). This "store mechanics, generate values" pattern is the correct abstraction for ~Copyable ranges.

### Formal Definition for ~Copyable Ranges

Let `Range.Lazy<B>` be a lazy range type with bound type `B: ~Copyable`.

**Internal Representation**:
```
Range.Lazy<B> ::= { start: Int, end: Int, transform: Int → B }
```

**Key Insight**: Store `Int` bounds internally (the index domain) with a transformation function to produce `B` values on-demand. This avoids storing `~Copyable` values directly.

**Typing Rules**:

```
Γ ⊢ r : Range.Lazy<B>    Γ, x : B ⊢ e : T    borrows(x, e)
────────────────────────────────────────────────────────── [Range-ForEach]
Γ ⊢ r.forEach(x => e) : ()

Γ ⊢ r : Range.Lazy<B>    Γ, x : B ⊢ e : T    consumes(x, e)
────────────────────────────────────────────────────────── [Range-Drain]
Γ ⊢ r.drain(x => e) : ()
```

---

## Analysis

### Design Dimension 1: Range Type Taxonomy

**Question**: What range types should swift-range-primitives provide?

#### Option 1A: Single Lazy Type (Current)

```swift
extension Range {
    public struct Lazy<Bound: ~Copyable>: ~Copyable { ... }
}
```

**Advantages**:
- Simple, minimal API surface
- `Lazy` emphasizes on-demand generation
- Works for all use cases via transform function

**Disadvantages**:
- Doesn't mirror stdlib range taxonomy
- No direct support for closed ranges, partial ranges
- Naming may confuse users expecting stdlib analogs

#### Option 1B: Full Range Type Family

```swift
extension Range {
    /// Half-open range: [start, end)
    public struct Lazy<Bound: ~Copyable>: ~Copyable { ... }

    /// Closed range: [start, end]
    public struct Closed<Bound: ~Copyable>: ~Copyable { ... }

    /// One-sided from lower bound: [start, ∞)
    public struct From<Bound: ~Copyable>: ~Copyable { ... }

    /// One-sided to upper bound (exclusive): (-∞, end)
    public struct UpTo<Bound: ~Copyable>: ~Copyable { ... }

    /// One-sided through upper bound (inclusive): (-∞, end]
    public struct Through<Bound: ~Copyable>: ~Copyable { ... }
}
```

**Advantages**:
- Complete taxonomy matching mathematical intervals
- Mirrors Swift stdlib range types
- Clear semantic distinction between range kinds

**Disadvantages**:
- Larger API surface
- `From`, `UpTo`, `Through` are unbounded — infinite iteration risk
- More complexity for rare use cases

#### Option 1C: Bounded Types Only

```swift
extension Range {
    /// Half-open bounded range: [start, end)
    public struct Bounded<Bound: ~Copyable>: ~Copyable { ... }

    /// Closed bounded range: [start, end]
    public struct Closed<Bound: ~Copyable>: ~Copyable { ... }
}
```

**Advantages**:
- Covers 95%+ of practical use cases
- Avoids infinite iteration danger
- Reasonable API surface

**Disadvantages**:
- Missing partial range support

### Comparison: Range Type Taxonomy

| Criterion | 1A: Single Lazy | 1B: Full Family | 1C: Bounded Only |
|-----------|-----------------|-----------------|------------------|
| API simplicity | ✓✓ | ✗ | ✓ |
| Mathematical completeness | ✗ | ✓✓ | ✓ |
| Safety (no infinite) | ✓ | ✗ | ✓ |
| Stdlib familiarity | ✗ | ✓✓ | ✓ |
| Implementation cost | ✓✓ | ✗ | ✓ |

**Recommendation**: Option 1A with evolved naming. The current `Range.Lazy<Bound>` design is correct — it's a lazy-generating range that transforms integers to bounds on-demand. The name "Lazy" accurately describes the deferred computation. Full range taxonomy is unnecessary because:
1. Partial/unbounded ranges are rarely needed in collection iteration
2. The transform function provides flexibility beyond fixed interval types
3. Closed vs half-open distinction can be handled by the integer range passed to initializer

---

### Design Dimension 2: Naming

**Question**: Is `Range.Lazy<Bound>` the right name?

#### Option 2A: Range.Lazy (Current)

```swift
Range.Lazy<Bound: ~Copyable>
```

**Rationale**: "Lazy" emphasizes deferred/on-demand computation. Each bound is produced by the transform function only when needed.

#### Option 2B: Range.Generating

```swift
Range.Generating<Bound: ~Copyable>
```

**Rationale**: Emphasizes the generative nature — bounds are generated, not stored.

#### Option 2C: Range.Mapped

```swift
Range.Mapped<Bound: ~Copyable>
```

**Rationale**: Emphasizes the transformation from integers to bounds.

#### Option 2D: Range.Indexed

```swift
Range.Indexed<Bound: ~Copyable>
```

**Rationale**: Emphasizes position-indexed access to generated bounds.

### Comparison: Naming

| Criterion | 2A: Lazy | 2B: Generating | 2C: Mapped | 2D: Indexed |
|-----------|----------|----------------|------------|-------------|
| Clarity of purpose | ✓ | ✓✓ | ✓ | ✗ |
| Precedent (stdlib) | ✓ (`lazy`) | ✗ | ✓ (`map`) | ✓ (`Index`) |
| Brevity | ✓✓ | ✓ | ✓✓ | ✓ |
| Avoids confusion | ✓ | ✓ | ✗ (with Sequence.Map) | ✗ (with Index<T>) |

**Recommendation**: Keep **Option 2A: Range.Lazy**. The name correctly captures:
- Deferred computation (bounds generated on-demand)
- Familiarity with `LazySequence`, `lazy` keyword
- No conflict with existing ecosystem types

**Documentation Requirement**: The term "Lazy" is subtly overloaded and requires explicit clarification in DocC:

> Unlike `LazySequence`, which defers traversal of stored elements, `Range.Lazy` generates values on demand from an integer index domain. No `Bound` values are ever stored — they are created fresh by the transform function at each access.

This distinction prevents incorrect mental models where users assume Range.Lazy wraps an existing collection.

---

### Design Dimension 3: Iteration API

**Question**: What iteration patterns should Range.Lazy support?

#### Current API

```swift
extension Range.Lazy {
    // Manual iteration
    consuming func makeIterator() -> Iterator

    // Borrowing iteration via Property pattern
    var forEach: Property<Range.ForEach, Self> { ... }

    // Consuming iteration via Property.View pattern
    var drain: Property<Range.Drain, Self>.View { mutating _read { ... } }

    // Reverse iteration
    consuming func reversed() -> Reversed
}
```

#### Option 3A: Current (Property.View Pattern)

Maintain current design with Property.View for `drain`.

**Advantages**:
- Consistent with Sequence/Collection primitives
- Lifetime-safe via `_lifetime` annotations
- Clear borrowing vs consuming semantics

#### Option 3B: Direct Methods

```swift
extension Range.Lazy {
    mutating func forEach(_ body: (borrowing Bound) -> Void)
    mutating func drain(_ body: (consuming Bound) -> Void)
}
```

**Advantages**:
- Simpler implementation
- No Property.View complexity

**Disadvantages**:
- Inconsistent with other primitives packages
- Less composable

#### Option 3C: Expanded API

```swift
extension Range.Lazy {
    // Current patterns
    var forEach: Property<Range.ForEach, Self>
    var drain: Property<Range.Drain, Self>.View

    // Additional patterns
    consuming func map<T>(_ transform: (Bound) -> T) -> Range.Lazy<T>
    consuming func filter(_ predicate: (borrowing Bound) -> Bool) -> Range.Lazy<Bound>
    consuming func reduce<T>(_ initial: T, _ combine: (T, borrowing Bound) -> T) -> T
    consuming func first(where predicate: (borrowing Bound) -> Bool) -> Bound?
    consuming func contains(where predicate: (borrowing Bound) -> Bool) -> Bool
}
```

**Advantages**:
- Rich functional API
- Mirrors Rust's most-used methods

**Disadvantages**:
- Larger API surface
- Some methods (filter) problematic with ~Copyable
- May duplicate Sequence functionality

### Comparison: Iteration API

| Criterion | 3A: Current | 3B: Direct | 3C: Expanded |
|-----------|-------------|------------|--------------|
| Ecosystem consistency | ✓✓ | ✗ | ✓ |
| API simplicity | ✓ | ✓✓ | ✗ |
| Composability | ✓ | ✗ | ✓✓ |
| Implementation cost | ✓ | ✓✓ | ✗ |

**Recommendation**: **Option 3A (Current)** with minor additions:

```swift
extension Range.Lazy {
    // Keep current Property.View patterns

    // Add commonly-needed operations
    consuming func count(where predicate: (borrowing Bound) -> Bool) -> Int
    consuming func allSatisfy(_ predicate: (borrowing Bound) -> Bool) -> Bool
    consuming func first(where predicate: (borrowing Bound) -> Bool) -> Bound?
}
```

The Property.View pattern provides ecosystem consistency. Add only the most commonly-needed terminal operations.

**Normative Requirement**: Property.View is not a stylistic choice — it is mandatory for expressing consuming iteration over `~Copyable` ranges while preserving borrow checking and lifetime guarantees.

Direct mutating iteration methods are intentionally avoided because:
1. `mutating func drain(_:)` would require the range to be `var`-bound at the call site
2. Property.View with `_lifetime` annotations enables safe interior pointer access
3. The pattern maintains consistency with Sequence and Collection primitives

Future contributors MUST NOT "simplify" this to direct methods without understanding these constraints.

---

### Design Dimension 4: Copyable Conditional Conformance

**Question**: Should Range.Lazy conditionally conform to Sequence/Collection when Bound is Copyable?

#### Option 4A: No Conformance (Current)

```swift
// Range.Lazy never conforms to Sequence or Collection
extension Range.Lazy: Sendable where Bound: Sendable {}
// That's it
```

**Advantages**:
- Simple, predictable behavior
- No API asymmetry based on bound type
- Users who need stdlib Sequence can bridge trivially

**Disadvantages**:
- Loss of stdlib algorithm access for Copyable bounds

#### Option 4B: Conditional Sequence Conformance

```swift
extension Range.Lazy: Sequence where Bound: Copyable {
    typealias Element = Bound
    func makeIterator() -> Iterator { ... }
}
```

**Advantages**:
- stdlib algorithm access when possible
- Familiar `for-in` syntax for Copyable bounds

**Disadvantages**:
- API asymmetry (some bounds get more features)
- May mislead users about primary use case (~Copyable)
- Constraint poisoning risk (see MEM-COPY-006 Category 3)

#### Option 4C: Conditional Conformance via Module Boundary

Following the pattern from swift-array-primitives:

```
Range Primitives/          # Core types, ~Copyable support
Range Primitives Sequence/ # Sequence conformance (imports Core)
```

**Advantages**:
- No constraint poisoning
- Clean separation
- Best of both worlds

**Disadvantages**:
- Package structure complexity
- More modules to manage

### Comparison: Copyable Conformance

| Criterion | 4A: None | 4B: Direct | 4C: Module Split |
|-----------|----------|------------|------------------|
| Simplicity | ✓✓ | ✓ | ✗ |
| Stdlib access | ✗ | ✓ | ✓ |
| ~Copyable focus | ✓✓ | ✗ | ✓ |
| No constraint poison | ✓ | ✗ | ✓ |

**Recommendation**: **Option 4A (No Conformance)** for now, with documentation on bridging:

```swift
// For Copyable bounds needing stdlib algorithms:
let lazyRange = Range.Lazy(0..<10) { Element(position: $0) }
let stdlibSequence = (0..<10).lazy.map { Element(position: $0) }
```

The primary value of Range.Lazy is ~Copyable support. For Copyable bounds, stdlib's `lazy.map` is already available. Adding conditional conformance adds complexity without significant benefit.

**Design Note — Reserved Option**: Conditional `Sequence` conformance MAY be introduced in a separate module (following the swift-array-primitives pattern) if a clear ecosystem need emerges. This reservation keeps the door open without commitment and signals intent to future maintainers. The module structure would be:

```
Range Primitives/          # Core types, ~Copyable support
Range Primitives Sequence/ # Sequence conformance (imports Core)
```

This is NOT a recommendation to implement now — only a reservation of the design space.

---

### Design Dimension 5: Bound Type Constraints

**Question**: What constraints should Range.Lazy place on its Bound type parameter?

#### Option 5A: Minimal (~Copyable only)

```swift
public struct Lazy<Bound: ~Copyable>: ~Copyable { ... }
```

Current design: only suppresses Copyable requirement.

#### Option 5B: ~Copyable & ~Escapable

```swift
public struct Lazy<Bound: ~Copyable & ~Escapable>: ~Copyable { ... }
```

Also supports non-escapable bounds (spans, views).

#### Option 5C: Separate Types for Escapable/~Escapable

```swift
public struct Lazy<Bound: ~Copyable>: ~Copyable { ... }
public struct LazyEscapable<Bound: ~Copyable & ~Escapable>: ~Copyable & ~Escapable { ... }
```

### Comparison: Bound Constraints

| Criterion | 5A: ~Copyable | 5B: ~Copyable & ~Escapable | 5C: Separate Types |
|-----------|---------------|----------------------------|-------------------|
| Flexibility | ✓ | ✓✓ | ✓✓ |
| API simplicity | ✓✓ | ✓ | ✗ |
| Span support | ✗ | ✓ | ✓ |

**Recommendation**: **Option 5A (Current)** for now. `~Escapable` bounds are rare for range iteration. The transform function `(Int) -> Bound` would need to return `~Escapable` values, which has complex lifetime implications. If needed, a separate `Range.Lazy.NonEscapable` can be added later.

---

### Design Dimension 6: Sendable Support

**Question**: How should Range.Lazy handle Sendable?

#### Current Design

```swift
extension Range.Lazy: Sendable where Bound: Sendable {}
extension Range.Lazy.Iterator: Sendable where Bound: Sendable {}
extension Range.Lazy.Reversed: Sendable where Bound: Sendable {}
extension Range.Lazy.Reversed.Iterator: Sendable where Bound: Sendable {}
```

**Observation**: This requires `@Sendable` on the transform function:

```swift
let transform: @Sendable (Int) -> Bound
```

**Current design is correct**. The transform is marked `@Sendable`, enabling conditional Sendable conformance.

---

### Design Dimension 7: Step/Stride Support

**Question**: Should Range.Lazy support strided iteration?

#### Option 7A: No Stride (Current)

Iteration always proceeds by 1.

#### Option 7B: Strided Variant

```swift
extension Range {
    public struct Strided<Bound: ~Copyable>: ~Copyable {
        let start: Int
        let end: Int
        let stride: Int
        let transform: @Sendable (Int) -> Bound
    }
}
```

#### Option 7C: Stride Parameter on Lazy

```swift
public struct Lazy<Bound: ~Copyable>: ~Copyable {
    let start: Int
    let end: Int
    let stride: Int  // Default: 1
    let transform: @Sendable (Int) -> Bound
}
```

### Comparison: Stride Support

| Criterion | 7A: No Stride | 7B: Strided Variant | 7C: Stride Parameter |
|-----------|---------------|---------------------|----------------------|
| API simplicity | ✓✓ | ✓ | ✓ |
| Use case coverage | ✗ | ✓ | ✓ |
| Zero-overhead default | ✓ | ✓ | ✗ (stores stride) |

**Recommendation**: **Option 7A (No Stride)** for now. Strided iteration is uncommon for typed index ranges. Users can achieve striding via transform:

```swift
Range.Lazy(0..<count/2) { Index(__unchecked: (), position: $0 * 2) }
```

If demand warrants, add `Range.Strided<Bound>` as a separate type (Option 7B) to avoid adding overhead to the common case.

---

### Design Dimension 8: Reversed Iteration

**Question**: Is the current Reversed design optimal?

#### Current Design

```swift
extension Range.Lazy {
    public struct Reversed { ... }

    consuming func reversed() -> Reversed
}
```

`Reversed` is a nested type with its own `forEach`, `drain`, `makeIterator()`.

**Analysis**: This is correct. The nested type approach:
- Maintains proper ~Copyable constraint propagation (nested in struct body)
- Provides complete API on reversed ranges
- Matches stdlib pattern (`ReversedCollection`)

**Recommendation**: **Keep current design**. The `Reversed` nested type is the right pattern.

---

### Design Dimension 9: Operator Support

**Question**: What operators should Range.Lazy support?

#### Current Design

```swift
// Creates Range.Lazy from Int and Index.Count
public func ..< <Tag: ~Copyable>(
    lhs: Int,
    rhs: Index<Tag>.Count
) -> Range.Lazy<Index<Tag>>
```

#### Option 9A: Current (Index.Count only)

Keep existing operator for typed counts.

#### Option 9B: Additional Operators

```swift
// Range.Lazy from transform
public func ..< <Bound: ~Copyable>(
    lhs: Int,
    rhs: Int
) -> (_ transform: @escaping @Sendable (Int) -> Bound) -> Range.Lazy<Bound>

// Closed range variant
public func ... <Tag: ~Copyable>(
    lhs: Int,
    rhs: Index<Tag>.Count
) -> Range.Lazy<Index<Tag>>
```

### Comparison: Operators

| Criterion | 9A: Current | 9B: Additional |
|-----------|-------------|----------------|
| API simplicity | ✓✓ | ✗ |
| Discoverability | ✓ | ✓✓ |
| Type inference | ✓ | Complex |

**Recommendation**: **Option 9A (Current)**. The `0..<count` operator is the primary use case. Additional operators add complexity without proportional benefit.

---

## Empirical Validation [RES-025]

### Cognitive Dimensions Analysis

| Dimension | Current Design | Assessment |
|-----------|----------------|------------|
| **Visibility** | Good — `Range.Lazy` is discoverable | ✓ |
| **Consistency** | Matches Sequence/Collection patterns | ✓ |
| **Viscosity** | Low — one type, clear operations | ✓ |
| **Role-expressiveness** | Clear — "Lazy" conveys deferred computation | ✓ |
| **Error-proneness** | Low — type system prevents misuse | ✓ |
| **Abstraction** | Right level — not too high, not too low | ✓ |

### Usage Patterns Validation

**Primary Use Case** (collections with ~Copyable elements):

```swift
// Before Range.Lazy
for i in 0..<count.rawValue {
    let idx = Index(__unchecked: (), position: i)
    body(storage.read(at: idx).pointee)
}

// With Range.Lazy
(0..<count).forEach { idx in
    body(storage.read(at: idx).pointee)
}
```

**Reverse Iteration**:

```swift
// Before
for i in stride(from: count.rawValue - 1, through: 0, by: -1) {
    let idx = Index(__unchecked: (), position: i)
    body(storage.read(at: idx).pointee)
}

// With Range.Lazy
(0..<count).reversed().forEach { idx in
    body(storage.read(at: idx).pointee)
}
```

**Manual Iteration**:

```swift
var iterator = (0..<count).makeIterator()
while let idx = iterator.next() {
    if shouldStop(idx) { break }
    process(idx)
}
```

All patterns are clean, readable, and type-safe.

---

## Identified Gaps and Recommendations

### Gap 1: Missing Common Terminal Operations

**Current State**: Only `forEach`, `drain`, `makeIterator`, `reversed`, `count`, `isEmpty`.

**Recommendation**: Add commonly-needed terminal operations:

```swift
extension Range.Lazy where Bound: ~Copyable {
    /// Returns the first element satisfying the predicate, if any.
    @inlinable
    public consuming func first(
        where predicate: (borrowing Bound) -> Bool
    ) -> Bound?

    /// Returns true if all elements satisfy the predicate.
    @inlinable
    public consuming func allSatisfy(
        _ predicate: (borrowing Bound) -> Bool
    ) -> Bool

    /// Returns the count of elements satisfying the predicate.
    @inlinable
    public consuming func count(
        where predicate: (borrowing Bound) -> Bool
    ) -> Int
}
```

### Gap 2: No Indexed Access

**Current State**: No way to get the nth element without iteration.

**Recommendation**: Add subscript for random access:

```swift
extension Range.Lazy where Bound: ~Copyable {
    /// Returns the element at the given offset from start.
    ///
    /// This is a **generative** subscript: each access calls the transform
    /// function and produces a fresh `Bound` value. No caching occurs.
    ///
    /// - Important: This does not advance any iteration state. Repeated
    ///   subscripting at the same offset regenerates the value each time.
    ///
    /// - Precondition: `offset >= 0 && offset < count`
    @inlinable
    public subscript(offset: Int) -> Bound {
        precondition(offset >= 0 && offset < count, "Index out of bounds")
        return transform(start + offset)
    }
}
```

**Documentation Requirement**: The subscript semantics differ from collection subscripts in a critical way:
- Collection subscripts return stored values (or views into storage)
- Range.Lazy subscripts **regenerate** values via the transform function

This distinction must be documented clearly to prevent users from assuming caching or iterator-like state advancement. The subscript is "random access generation" operating on the index domain, not "element retrieval" from storage.

### Gap 3: Documentation Gaps

**Current State**: Good inline documentation but no package-level overview.

**Recommendation**: Add `Range.swift` documentation or DocC article explaining:
- Why Range.Lazy exists (stdlib limitations)
- How it differs from Swift.Range
- Migration patterns from stdlib
- Relationship with Sequence/Collection primitives
- **The Index Domain concept** (critical for mental model)
- **Clarification that "Lazy" means generative, not deferred-over-storage**

**Required Documentation Elements**:

1. **Index Domain explanation** at package level:
   > Range.Lazy operates over a Copyable index domain (currently `Int`), from which `~Copyable` bounds are generated on demand.

2. **Lazy vs LazySequence distinction** in type documentation:
   > Unlike `LazySequence`, which defers traversal of stored elements, `Range.Lazy` generates values on demand from an integer index domain. No `Bound` values are ever stored.

3. **Regeneration semantics** for any random-access operations:
   > Each subscript access or iteration step calls the transform function. Values are not cached.

### Gap 4: No Combining Operations

**Current State**: Cannot combine or split ranges.

**Recommendation**: Consider adding:

```swift
extension Range.Lazy where Bound: ~Copyable {
    /// Drops the first n elements.
    @inlinable
    public consuming func dropFirst(_ n: Int) -> Range.Lazy<Bound>

    /// Takes only the first n elements.
    @inlinable
    public consuming func prefix(_ n: Int) -> Range.Lazy<Bound>

    /// Drops the last n elements.
    @inlinable
    public consuming func dropLast(_ n: Int) -> Range.Lazy<Bound>

    /// Takes only the last n elements.
    @inlinable
    public consuming func suffix(_ n: Int) -> Range.Lazy<Bound>
}
```

### Gap 5: Enumeration Support

**Current State**: No way to get (index, element) pairs.

**Recommendation**: Add enumerated iteration:

```swift
extension Range.Lazy where Bound: ~Copyable {
    /// Iterates with both offset and element.
    @inlinable
    public consuming func enumerated(
        _ body: (Int, borrowing Bound) -> Void
    )
}

// Alternative: via Property.View
extension Range {
    public enum Enumerated {}
}

extension Property where Tag == Range.Enumerated {
    @inlinable
    public func callAsFunction<Bound: ~Copyable>(
        _ body: (Int, borrowing Bound) -> Void
    ) where Base == Range.Lazy<Bound>
}
```

---

## Implementation Plan

### Phase 1: Polish Current API (Minimal Changes)

1. Keep `Range.Lazy<Bound: ~Copyable>` as-is
2. Keep `Range.Lazy.Iterator` nested inline (correct)
3. Keep `Range.Lazy.Reversed` nested inline (correct)
4. Keep Property.View patterns for `forEach`, `drain`
5. Keep `0..<count` operator

### Phase 2: Add Terminal Operations

Add to `Range.Lazy`:
- `first(where:) -> Bound?`
- `allSatisfy(_:) -> Bool`
- `count(where:) -> Int`
- `subscript(offset:) -> Bound`

### Phase 3: Add Combining Operations (If Demand)

Add to `Range.Lazy`:
- `dropFirst(_:) -> Range.Lazy<Bound>`
- `prefix(_:) -> Range.Lazy<Bound>`
- `dropLast(_:) -> Range.Lazy<Bound>`
- `suffix(_:) -> Range.Lazy<Bound>`

### Phase 4: Add Enumeration (If Demand)

Add:
- `enumerated(_:)` method or `Range.Enumerated` Property.View tag

### Phase 5: Consider Striding (If Demand)

Add `Range.Strided<Bound>` as separate type if striding demand emerges.

---

## Changelog

- **v1.1.0 (2026-01-25)**: Incorporated design review feedback:
  - Added "Index Domain" concept as named abstraction
  - Clarified "Lazy" terminology vs LazySequence
  - Explicitly justified Property.View as mandatory (not stylistic)
  - Documented subscript regeneration semantics
  - Reserved module-split option for future Sequence conformance

- **v1.0.0 (2026-01-25)**: Initial comprehensive design analysis

---

## Outcome

**Status**: DECISION

**Assessment**: The current design is **largely correct** and represents a well-designed range primitive for ~Copyable support. The design:

1. **Correctly stores integers internally** with transform function — avoids storing ~Copyable values
2. **Correctly nests Iterator/Reversed** inside struct body — proper constraint propagation
3. **Uses Property.View pattern** — consistent with ecosystem
4. **Supports Sendable conditionally** — correct for concurrent use
5. **Provides custom operator** — clean syntax for typed counts

**Recommended Additions** (Priority Order):

| Priority | Category | Addition | Rationale |
|----------|----------|----------|-----------|
| 1 | Documentation | Index Domain concept | Names the core abstraction |
| 2 | Documentation | Lazy vs LazySequence clarification | Prevents incorrect mental models |
| 3 | Documentation | Property.View normative justification | Prevents future "simplification" |
| 4 | API | `subscript(offset:)` with regeneration docs | Random access generation |
| 5 | API | `first(where:)` | Common search pattern |
| 6 | API | `allSatisfy(_:)` | Common validation pattern |
| 7 | API | `count(where:)` | Common counting pattern |
| 8 | API | `dropFirst(_:)`, `prefix(_:)` | Range manipulation |
| 9 | API | `enumerated(_:)` | Offset+element iteration |

**Documentation Requirements** (must be completed before DECISION status):

| Location | Requirement |
|----------|-------------|
| Package DocC overview | Explain Index Domain concept |
| Package DocC overview | Why Range.Lazy exists (stdlib ~Copyable limitations) |
| `Range.Lazy` type docs | Clarify "Lazy" means generative, not deferred-over-storage |
| `Range.Lazy` type docs | Explain regeneration semantics |
| Property.View usage | Normative statement: Property.View is mandatory, not stylistic |
| `subscript(offset:)` | Document that access regenerates values (no caching) |
| `forEach`/`drain` | Document borrowing vs consuming ownership |

**Not Recommended**:

| Feature | Reason |
|---------|--------|
| Full range type taxonomy | Unnecessary complexity; transform function provides flexibility |
| Conditional Sequence conformance | Constraint poisoning risk; stdlib alternatives exist for Copyable |
| Stride parameter on Lazy | Overhead on common case; transform can achieve striding |
| ~Escapable bound support | Complex lifetime implications; rare use case |

---

## Design Decisions Summary

| Dimension | Decision | Rationale |
|-----------|----------|-----------|
| Type taxonomy | Single `Range.Lazy` | Simplicity; transform provides flexibility |
| Naming | Keep `Range.Lazy` | Clear, familiar, no conflicts |
| Naming clarification | Document "Lazy" vs "LazySequence" | Prevents incorrect mental models |
| Core concept | Name "Index Domain" explicitly | Unifies mental model; explains O(1) count, reversal |
| Iteration API | Property.View pattern (mandatory) | Not stylistic; required for ~Copyable ownership |
| Copyable conformance | None (module-split reserved) | Focus on ~Copyable; option preserved for future |
| Bound constraints | `~Copyable` only | `~Escapable` adds complexity |
| Sendable | Conditional | Transform is `@Sendable` |
| Stride | None (can add later) | Zero-overhead default |
| Reversed | Nested `Reversed` type | Constraint propagation |
| Operators | `0..<count` only | Primary use case |
| Subscript semantics | Regenerative (no caching) | Follows from Index Domain design |

---

## References

### Swift Evolution
- SE-0172: One-Sided Ranges
- SE-0270: RangeSet and Collection Operations
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
- SE-0437: Noncopyable standard library primitives

### Rust
- RFC 3550: New Range Types
- Iterator vs IntoIterator patterns

### Academic
- Wadler, P. (1990). Linear types can change the world!
- Walker, D. (2005). Substructural Type Systems

### Swift Institute
- Memory Copyable.md — ~Copyable patterns
- range-noncopyable-iteration.md — Prior research
- range-sequence-collection-analysis.md — Semantic relationships

---

## Related Documents

- `/Users/coen/Developer/swift-primitives/swift-range-primitives/Research/range-noncopyable-iteration.md`
- `/Users/coen/Developer/swift-primitives/swift-range-primitives/Research/range-sequence-collection-analysis.md`
- `/Users/coen/Developer/swift-institute/Documentation.docc/Memory Copyable.md`
