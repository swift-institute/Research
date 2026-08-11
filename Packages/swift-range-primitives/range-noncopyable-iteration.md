# Range Iteration for ~Copyable Bounds

<!--
---
version: 1.0.0
last_updated: 2026-01-24
status: RECOMMENDATION
tier: 3
---
-->

## Context

While implementing `Array.Static+ForEach.swift`, we want to replace:

```swift
for i in 0..<count.rawValue {
    body(storage.read(at: .init(__unchecked: (), position: i)).pointee)
}
```

With the cleaner:

```swift
for i in 0..<count {
    body(storage.read(at: i).pointee)
}
```

However, `Index<Element>.Count` with `Element: ~Copyable` cannot be used with Swift's `Range` because:

```
Protocol 'Sequence' requires that 'Tagged<Element, Affine.Discrete.Position>.Count'
conform to 'Strideable'
```

Swift's `Range<Bound>` requires `Bound: Comparable`, and iterating requires `Bound: Strideable` (which implies `Copyable`).

**Trigger**: This pattern affects every collection primitive with `~Copyable` elements.

**Scope**: Ecosystem-wide (Tier 3) — affects swift-range-primitives, swift-sequence-primitives, swift-index-primitives, swift-array-primitives, and all downstream collection types.

**Semantic commitment**: Establishes foundational iteration semantics for `~Copyable` bounds.

---

## Question

How should swift-range-primitives provide range-based iteration that works with `~Copyable` bound types like `Index<Tag>.Count`?

---

## Prior Art Survey [RES-021]

### Swift Evolution

| Proposal | Relevance | Key Insight |
|----------|-----------|-------------|
| [SE-0427](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) | Noncopyable Generics | `~Copyable` suppression on type parameters; associated types still require Copyable |
| [SE-0437](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) | Stdlib ~Copyable | `Optional`, `Result` support ~Copyable; `Range`, `Sequence` do not |
| [SE-0390](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) | Move-only types | Original ~Copyable proposal |

**Key finding**: Swift's `Range<Bound>` and `Sequence` protocol are not designed for `~Copyable`. The stdlib team has not prioritized this.

### Rust

Rust's approach to iteration:

```rust
// Range requires Copy (implicit in Rust)
for i in 0..count {
    // i is copied each iteration
}

// For non-Copy types, use explicit patterns
let mut iter = (0..count).map(|i| NonCopy::new(i));
while let Some(item) = iter.next() {
    // item is moved
}
```

Rust's `Range<Idx>` requires `Idx: Copy` for iteration via `Iterator`. For non-Copy iteration, Rust uses:
- `IntoIterator` consuming the range
- `iter_mut()` for borrowing
- Closure-based patterns

### Haskell

Haskell's linearity (GHC 9.0+):

```haskell
-- Linear types track usage
data Range a where
  MkRange :: a %1 -> a %1 -> Range a

-- Iteration via fold pattern (no explicit loops)
foldRange :: (a -> b -> b) -> b -> Range a -> b
```

Haskell avoids mutable iteration entirely; ranges are consumed via folds.

### C++

C++ ranges (C++20):

```cpp
// views::iota creates lazy range
for (auto i : std::views::iota(0, count)) {
    // i is copied
}

// For move-only, explicit generator patterns
std::generator<MoveOnly> gen() {
    for (int i = 0; i < count; ++i)
        co_yield MoveOnly(i);
}
```

C++ separates value semantics from iteration; move-only types use generators.

---

## Theoretical Grounding [RES-022]

### Affine Type Theory

In substructural type systems:

| Type System | Contraction | Weakening | Exchange |
|-------------|-------------|-----------|----------|
| Linear | ✗ | ✗ | ✓ |
| Affine | ✗ | ✓ | ✓ |
| Relevant | ✓ | ✗ | ✓ |
| Ordered | ✗ | ✗ | ✗ |

Swift's `~Copyable` corresponds to **affine types**: values can be used at most once (weakening allowed, contraction forbidden).

**Iteration challenge**: Traditional `for-in` loops implicitly copy the iterator state and elements. For affine types:
- Iterator must be consumed (moved) at each step
- Elements cannot be copied out; must be borrowed or consumed

### Range as Affine Resource

A range `[start, end)` over affine bounds represents a **linear resource** that must be consumed exactly once. The iteration pattern must:

1. **Consume the range** (it cannot be reused)
2. **Produce elements linearly** (each element accessed once)
3. **Support both borrowing and consuming** element access

### Formal Definition

Let `Range<B>` be a range type with bound type `B: ~Copyable`.

**Typing rules**:

```
Γ ⊢ r : Range<B>    Γ, x : B ⊢ e : T
────────────────────────────────────── [Range-ForEach]
Γ ⊢ r.forEach(x => e) : ()
```

Where `r` is consumed and `x` is borrowed in the body `e`.

For consuming iteration:

```
Γ ⊢ r : Range<B>    Γ, x : B ⊢ e : T    consumes(x, e)
───────────────────────────────────────────────────────── [Range-Drain]
Γ ⊢ r.drain(x => e) : ()
```

Where both `r` and each `x` are consumed.

---

## Systematic Literature Review [RES-023]

### Research Questions

- **RQ1**: How do existing languages handle iteration over non-copyable/linear types?
- **RQ2**: What patterns exist for range abstraction with affine bounds?
- **RQ3**: What are the API design trade-offs for ~Copyable iteration?

### Search Strategy

| Database | Keywords | Date Range |
|----------|----------|------------|
| ACM DL | "linear types" AND "iteration" | 2015-2026 |
| arXiv | "affine types" AND "rust" | 2018-2026 |
| Swift Forums | "noncopyable" AND "sequence" | 2023-2026 |

### Key Findings

1. **Wadler (1990)**: Linear types require explicit consume/borrow distinction
2. **Rust RFC 2229** (2018): Capture analysis for closures with non-Copy
3. **Swift Forum discussions**: Community consensus that closure-based iteration is the pragmatic solution for ~Copyable

### Synthesis

The literature consistently shows:
- **Closure-based patterns** are the standard solution for affine iteration
- **Protocol-based iteration** (like Swift's `Sequence`) fundamentally conflicts with affine types
- **Lazy transformation** (like `map`) can work if the transformation function handles ownership

---

## Formal Semantics [RES-024]

### Type Definitions

```
Range<Bound: ~Copyable> ::= { start: Int, end: Int, transform: Int → Bound }
```

Note: We store `Int` bounds internally (copyable) and a transformation function to produce `Bound` values on demand. This avoids storing `~Copyable` values directly.

### Operational Semantics

**forEach (borrowing)**:

```
                    0 ≤ i < (r.end - r.start)
                    b = r.transform(r.start + i)
                    body borrows b
────────────────────────────────────────────────────────
r.forEach(body) ⟶ for i in 0..<(r.end - r.start): body(r.transform(r.start + i))
```

**makeIterator (consuming)**:

```
────────────────────────────────────────────
r.makeIterator() ⟶ Iterator { current: r.start, end: r.end, transform: r.transform }
```

**Iterator.next()**:

```
it.current < it.end
────────────────────────────────────────────
it.next() ⟶ Some(it.transform(it.current)); it.current += 1

it.current ≥ it.end
────────────────────────────────────────────
it.next() ⟶ None
```

### Soundness Argument

The design is sound because:

1. **Range stores no ~Copyable values**: Only `Int` bounds and a function
2. **Elements are produced on-demand**: Each call to `transform` creates a fresh value
3. **Ownership is clear**: `forEach` borrows, `drain`/consuming iteration moves
4. **No aliasing**: Each element is accessed through a unique call

---

## Analysis

### Option 1: Range.Lazy (Concrete Type)

**Approach**: Define `Range.Lazy<Bound: ~Copyable>` as a concrete struct that transforms `Range<Int>` to produce `Bound` values.

```swift
extension Range {
    public struct Lazy<Bound: ~Copyable>: ~Copyable {
        let start: Int
        let end: Int
        let transform: (Int) -> Bound

        public consuming func forEach(_ body: (borrowing Bound) -> Void)
        public consuming func makeIterator() -> Iterator
    }
}
```

**Advantages**:
- Matches `Sequence.Map.Lazy` pattern from swift-sequence-primitives
- Familiar API (`forEach`, `makeIterator`)
- No protocol constraints

**Disadvantages**:
- No `for-in` syntax
- Requires wrapping existing ranges

### Option 2: Counted Iteration Extension

**Approach**: Extend `Index.Count` with iteration methods directly.

```swift
extension Index<Tag>.Count where Tag: ~Copyable {
    public func forEach(_ body: (borrowing Index<Tag>) -> Void)
    public func forEachIndex(_ body: (Int) -> Void)
}
```

**Advantages**:
- Simple, direct API
- No new types needed
- Works immediately

**Disadvantages**:
- Couples iteration to Index.Count
- Doesn't generalize to other range-like types

### Option 3: Hybrid (Recommended)

**Approach**:
1. Define `Range.Lazy<Bound>` in swift-range-primitives
2. Provide extension on `Index.Count` that returns `Range.Lazy`
3. Coordinate with `Sequence.Map.Lazy` for consistent API

```swift
// In swift-range-primitives
extension Range {
    public struct Lazy<Bound: ~Copyable>: ~Copyable {
        // Core implementation
    }
}

// In swift-index-primitives (or extension in swift-range-primitives)
extension Index<Tag>.Count where Tag: ~Copyable {
    public var asRange: Range.Lazy<Index<Tag>> { ... }
}
```

**Advantages**:
- Reusable `Range.Lazy` type
- Clean extension pattern
- Consistent with `Sequence.Map.Lazy`

**Disadvantages**:
- Introduces dependency between packages

### Comparison

| Criterion | Option 1 | Option 2 | Option 3 |
|-----------|----------|----------|----------|
| Reusability | High | Low | High |
| Simplicity | Medium | High | Medium |
| Consistency with Sequence.Map.Lazy | High | Low | High |
| No new dependencies | Yes | Yes | No |
| Generalization | Good | Poor | Good |

---

## Empirical Validation [RES-025]

### Cognitive Dimensions Analysis

| Dimension | Option 1 | Option 2 | Option 3 |
|-----------|----------|----------|----------|
| **Visibility** | Medium (new type) | High (on Count) | High (property) |
| **Consistency** | Matches Sequence.Map.Lazy | Unique pattern | Matches both |
| **Viscosity** | Low (one wrapper) | Very low | Low |
| **Role-expressiveness** | Clear (Range.Lazy) | Clear (forEach) | Clear |
| **Error-proneness** | Low | Low | Low |
| **Abstraction** | Right level | Too specific | Right level |

### Usage Patterns

**Current (verbose)**:
```swift
for i in 0..<count.rawValue {
    let idx = Index(__unchecked: (), position: i)
    body(storage.read(at: idx).pointee)
}
```

**With Range.Lazy (Option 1/3)**:
```swift
count.asRange.forEach { idx in
    body(storage.read(at: idx).pointee)
}
```

**With direct forEach (Option 2)**:
```swift
count.forEach { idx in
    body(storage.read(at: idx).pointee)
}
```

---

## Coordination with swift-sequence-primitives

`Sequence.Map.Lazy` and `Range.Lazy` serve related purposes:

| Type | Source | Produces | Use Case |
|------|--------|----------|----------|
| `Sequence.Map.Lazy<E>` | `Range<Int>` + transform | `E: ~Copyable` | General lazy mapping |
| `Range.Lazy<B>` | `(start, end)` | `B: ~Copyable` | Range iteration |

**Decision**: `Range.Lazy` should be the foundational type. `Sequence.Map.Lazy` could be an alias or built on top of `Range.Lazy`.

Alternatively, merge concepts:
- `Range.Lazy<Bound>` IS-A lazy mapped range
- Remove `Sequence.Map.Lazy` duplication
- swift-range-primitives becomes the source of truth

---

## Experimental Validation

**Experiment**: `Experiments/range-lazy-noncopyable/`

**Result**: CONFIRMED

All patterns work:
- `Range.Lazy<Bound: ~Copyable>` compiles and runs
- `forEach` (borrowing) works
- `drain` (consuming) works
- `makeIterator()` + `while let` works
- Custom operator `0..<count` returning `Range.Lazy` works

**Critical Finding**: Iterator must be declared **inline in the struct body**, not in an extension. Nested types declared inside the struct body properly inherit `~Copyable` constraints from outer type parameters. This matches the pattern used by `Array.Static` and `Array.Storage` in swift-array-primitives.

**Naming**: `Range.Lazy.Iterator` works correctly when declared inline (not in extension).

---

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option 3 (Hybrid) with modifications

### Implementation Plan

1. **Define in swift-range-primitives**:
   - `Range.Lazy<Bound: ~Copyable>: ~Copyable`
   - `Range.Lazy<Bound>.Iterator: ~Copyable` (nested inline, NOT in extension)

2. **API Surface**:
   ```swift
   extension Range {
       public struct Lazy<Bound: ~Copyable>: ~Copyable {
           // Nested Iterator (MUST be inline, not in extension)
           public struct Iterator: ~Copyable {
               public mutating func next() -> Bound?
           }

           public init(_ range: Swift.Range<Int>, transform: @escaping @Sendable (Int) -> Bound)
           public var count: Int
           public var isEmpty: Bool
           public consuming func makeIterator() -> Iterator
           public consuming func forEach(_ body: (borrowing Bound) -> Void)
           public consuming func drain(_ body: (consuming Bound) -> Void)
       }
   }
   ```

3. **Custom Operator** (in swift-index-primitives or swift-range-primitives):
   ```swift
   public func ..< <Tag: ~Copyable>(lhs: Int, rhs: Index<Tag>.Count) -> Range.Lazy<Index<Tag>>
   ```

4. **Relationship with Sequence.Map.Lazy**:
   - `Range.Lazy` is more foundational (range-specific)
   - `Sequence.Map.Lazy` can be removed or kept as alias
   - Decision: Keep both, document relationship

5. **Update Array.Static+ForEach.swift**:
   ```swift
   // Before:
   for i in 0..<count.rawValue {
       let idx = Index(__unchecked: (), position: i)
       body(storage.read(at: idx).pointee)
   }

   // After:
   (0..<count).forEach { i in
       body(storage.read(at: i).pointee)
   }
   ```

### Dependency Direction

```
swift-range-primitives (defines Range.Lazy)
    ↓
swift-index-primitives (uses Range.Lazy for Index.Count)
    ↓
swift-sequence-primitives (may use Range.Lazy)
    ↓
swift-array-primitives (uses all of above)
```

**Issue**: Current dependency is `swift-sequence-primitives → swift-index-primitives`. If we want `Index.Count.asRange` to return `Range.Lazy`, we need:
- Option A: Move `Range.Lazy` to swift-index-primitives (breaks conceptual layering)
- Option B: Make swift-index-primitives depend on swift-range-primitives (adds dependency)
- Option C: Keep operator in swift-range-primitives, extending Index.Count from there

**Decision**: Option C - swift-range-primitives extends Index.Count from swift-index-primitives

### Files to Create

| Package | File | Content |
|---------|------|---------|
| swift-range-primitives | `Range.swift` | Namespace enum |
| swift-range-primitives | `Range.Lazy.swift` | Main type with nested Iterator (inline) |
| swift-range-primitives | `Index.Count+Range.Lazy.swift` | Extension for operator |

**Note**: `Iterator` is nested inside `Range.Lazy` struct body (not in separate file or extension) per API-IMPL-005 exception for nested types that must inherit `~Copyable` constraints.

### Limitations to Document

1. **No `for-in` syntax** - requires `Sequence` conformance which requires `Copyable`
2. **Iterator must be inline** - nested types in extensions don't inherit ~Copyable constraints
3. **Range is consumed** - forEach/drain consume the range (cannot reuse)

### Pattern for ~Copyable Nested Types

When a nested type needs to use the outer type's ~Copyable generic parameter, it MUST be declared inline in the struct body, not in an extension:

```swift
// CORRECT: Iterator declared inline
public struct Lazy<Bound: ~Copyable>: ~Copyable {
    public struct Iterator: ~Copyable {
        // Can use Bound here
    }
}

// INCORRECT: Iterator in extension (fails to compile)
extension Range.Lazy {
    public struct Iterator: ~Copyable {
        // ERROR: Bound doesn't inherit ~Copyable
    }
}
```

This pattern is documented in swift-array-primitives (see `Array.Static`, `Array.Storage`).

---

## References

### Swift Evolution
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
- SE-0437: Noncopyable standard library primitives

### Academic
- Wadler, P. (1990). Linear types can change the world!
- Walker, D. (2005). Substructural Type Systems. In Advanced Topics in Types and Programming Languages.

### Swift Forums
- [Noncopyable Sequence discussion](https://forums.swift.org/t/noncopyable-sequence)

### Related Experiments
- `/Users/coen/Developer/swift-primitives/swift-sequence-primitives/Experiments/sequence-lazy-map-noncopyable/`
