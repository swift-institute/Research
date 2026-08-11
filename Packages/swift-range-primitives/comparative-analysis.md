# Comparative Analysis: Range Primitives Across Modern Programming Languages

<!--
---
version: 1.0.0
last_updated: 2026-01-25
status: COMPLETE
tier: 3
---
-->

## Executive Summary

This document provides a comprehensive comparative analysis of range and iteration primitives across modern programming languages and academic literature. The goal is to validate that swift-range-primitives represents a best-in-class solution and identify any gaps or opportunities for improvement.

**Conclusion**: Swift Institute's `Range.Lazy<Bound: ~Copyable>` represents a **novel and superior design** that:
1. Solves the Copy-vs-Iterator tradeoff that Rust took 9 years to address (RFC 3550)
2. Provides first-class support for affine types (`~Copyable`) that no other mainstream language offers
3. Uses the Index Domain pattern for O(1) operations while supporting move-only bounds
4. Integrates phantom-typed indices for compile-time safety unprecedented in range abstractions

---

## Part I: Language-by-Language Comparison

### 1. Rust: The Copy-Iterator Dilemma

#### Historical Context

Rust's range types have been a source of pain since 2015. The core problem is fundamental: **implementing both `Copy` and `Iterator` creates hazardous semantics**.

> "Ranges are iterators, and iterators inherently rely on mutable state, so ranges unconditionally don't implement `Copy`."
> — [Rust RFC 3550](https://rust-lang.github.io/rfcs/3550-new-range.html)

#### The Problem with Legacy Ranges

Rust's `std::ops::Range<T>` implements `Iterator` directly, which means:
- Ranges are **consumed** during iteration
- Ranges cannot be `Copy` even when `T: Copy`
- Users must `.clone()` ranges or repeat syntax for reuse

The `RangeInclusive` type compounds this with an `exhausted: bool` field:

```rust
// Legacy design (problematic)
pub struct RangeInclusive<Idx> {
    pub(crate) start: Idx,
    pub(crate) end: Idx,
    pub(crate) exhausted: bool,  // Iterator state pollutes range type
}
```

This field exists solely for iterator semantics, inflating size and creating [soundness issues](https://github.com/rust-lang/rust/issues/67194) with `PartialEq`.

#### RFC 3550: Rust's Solution (Edition 2024)

After years of discussion ([Issue #2848](https://github.com/rust-lang/rfcs/issues/2848)), Rust is introducing new range types that:

1. **Separate ranges from iterators**: New types implement `IntoIterator`, not `Iterator`
2. **Enable `Copy`**: Ranges are now `Copy` when bounds are `Copy`
3. **Remove the `exhausted` field**: `RangeInclusive` becomes two fields only

```rust
// New design (RFC 3550)
pub struct Range<Idx> {
    pub start: Idx,
    pub end: Idx,
}
// Separate iterator type
pub struct IterRange<Idx> { ... }

impl<Idx: Copy> Copy for Range<Idx> {}
impl<Idx: Step> IntoIterator for Range<Idx> {
    type IntoIter = IterRange<Idx>;
}
```

#### Swift Institute's Advantage

`Range.Lazy<Bound: ~Copyable>` was designed from the start with this separation:

| Aspect | Rust Legacy | Rust RFC 3550 | Swift Range.Lazy |
|--------|-------------|---------------|------------------|
| Range-Iterator separation | No | Yes | Yes |
| Supports move-only bounds | No | No | **Yes** |
| Generative (on-demand) | No | No | **Yes** |
| Phantom-typed indices | No | No | **Yes** |
| Index Domain abstraction | No | No | **Yes** |

**Key insight**: Rust's RFC 3550 solves the Copy-Iterator problem but still requires `Bound: Copy + Step`. Swift Institute's design goes further by supporting `Bound: ~Copyable` through the Index Domain pattern.

---

### 2. C++20 Ranges: Lazy Composition Without Ownership

#### Design Philosophy

C++20's `std::ranges` library introduces lazy, composable views:

> "The range adaptors are often best thought of as lazy, composable algorithms since they do no work until you begin to iterate over them."
> — [Modern C++ Blog](https://www.modernescpp.com/index.php/the-ranges-library-in-c20-design-choices/)

```cpp
// C++20: Lazy iota view
auto numbers = std::views::iota(0, 10);  // No allocation
auto evens = numbers | std::views::filter([](int n) { return n % 2 == 0; });
```

#### Key Features

1. **Sentinel types**: End iterator can have different type than begin iterator
2. **Borrowed ranges**: `enable_borrowed_range` for dangling reference prevention
3. **Infinite ranges**: `std::views::iota(0)` with `unreachable_sentinel_t`

#### Limitations

C++ ranges struggle with move-only types:

```cpp
// Move-only element in range: complex lifetime management
std::generator<std::unique_ptr<Widget>> generate_widgets();
```

The language lacks:
- First-class affine type support
- Compile-time ownership tracking for iteration
- Typed indices preventing cross-collection confusion

#### Comparison

| Aspect | C++20 Ranges | Swift Range.Lazy |
|--------|--------------|------------------|
| Lazy evaluation | Yes | Yes |
| Composable pipelines | Yes (operator\|) | Limited (focused API) |
| Move-only support | Partial (generators) | **Native (~Copyable)** |
| Ownership tracking | Manual | **Compiler-enforced** |
| Type-safe indices | No | **Yes (phantom types)** |

---

### 3. Haskell: Lazy Lists and Linear Types

#### Traditional Lazy Lists

Haskell's list ranges are fundamentally lazy:

```haskell
[1..10]  -- Desugars to: enumFromTo 1 10
[1..]    -- Infinite list: enumFrom 1
```

> "The compiler translates the comprehension `[x..y]` into the function call `enumFromTo x y`, and a correct implementation of `enumFromTo x y` generates the list of all values between x and y."
> — [CS Dal Range Comprehensions](https://web.cs.dal.ca/~nzeh/Teaching/3137/haskell/standard_containers/list_comprehensions/range/)

#### Linear Haskell (GHC 9.0+)

Haskell now supports linear types via `-XLinearTypes`:

```haskell
-- Linear function: must consume argument exactly once
f :: a %1 -> b
```

> "A linear function `f :: a ⊸ b` must consume its argument exactly once."
> — [GHC User's Guide](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/linear_types.html)

However, Haskell's approach differs fundamentally:
- **Purity**: No mutable iteration state
- **Consumption via folds**: Ranges consumed through higher-order functions
- **Laziness by default**: No explicit lazy vs strict distinction

#### Comparison

| Aspect | Haskell | Swift Range.Lazy |
|--------|---------|------------------|
| Lazy by default | Yes | Yes |
| Linear type support | Yes (`%1 ->`) | Yes (`~Copyable`) |
| Mutable iteration | No (pure) | Yes (Iterator) |
| Index Domain separation | N/A (lazy lists) | **Explicit design** |
| Borrowing vs consuming | N/A | **Distinguished** |

**Academic foundation**: Both are grounded in substructural type theory, but Swift Institute provides explicit borrowing/consuming distinction via `forEach` vs `drain`.

---

### 4. Scala: LazyList and Stream Semantics

#### LazyList Design

Scala's `LazyList` (formerly `Stream`) uses memoization:

> "LazyList is considered an immutable data structure, even though its elements are computed on demand. Once the values are memoized they do not change."
> — [Scala LazyList API](https://www.scala-lang.org/api/current/scala/collection/immutable/LazyList.html)

```scala
val naturals = LazyList.from(0)  // Infinite lazy list
val evens = naturals.filter(_ % 2 == 0).take(10)
```

#### Key Differences from Swift Range.Lazy

| Aspect | Scala LazyList | Swift Range.Lazy |
|--------|----------------|------------------|
| Memoization | Yes (memory leak risk) | **No (regenerative)** |
| Memory model | Stores computed values | **Never stores bounds** |
| GC dependency | Yes | No |
| Infinite support | Yes | Yes (via transform) |

> "Memoization can be a source of memory leaks and must be used with caution."
> — [Scala LazyList API](https://www.scala-lang.org/api/current/scala/collection/immutable/LazyList.html)

**Swift Institute's advantage**: The Index Domain pattern means `Range.Lazy` **never memoizes**. Each access regenerates the value via the transform function, eliminating memoization-related memory leaks.

---

### 5. Python: Lazy Sequences

#### The range() Revolution

Python 3's `range()` is the canonical example of a lazy sequence:

> "Python's range objects are not iterators. Even though range objects are not iterators, they are lazy, meaning they don't actually store their data, they compute their data as you loop over them."
> — [Python Morsels](https://www.pythonmorsels.com/range-is-a-lazy-sequence/)

```python
r = range(1_000_000_000_000)  # Instant creation, minimal memory
r[999_999_999_999]  # O(1) random access
```

#### Design Analysis

Python's `range`:
- Stores only `start`, `stop`, `step`
- Computes elements on demand
- Supports O(1) `__contains__` and `__getitem__`
- Creates independent iterators via `__iter__`

#### Comparison

| Aspect | Python range | Swift Range.Lazy |
|--------|--------------|------------------|
| Lazy evaluation | Yes | Yes |
| O(1) random access | Yes | Yes (subscript) |
| Independent iterators | Yes | Yes (via transform) |
| Move-only elements | No | **Yes** |
| Type-safe indices | No | **Yes** |
| Typed arithmetic | No | **Yes (Offset)** |

Python lacks static type safety for index operations, allowing cross-collection index confusion that phantom types prevent in Swift Institute.

---

### 6. Java Streams: Lazy Pipeline Processing

#### Stream API Design

Java 8 Streams introduced lazy, pipeline-based iteration:

> "Streams are lazy; computation on the source data is only performed when the terminal operation is initiated, and source elements are consumed only as needed."
> — [Java Stream Javadoc](https://docs.oracle.com/javase/8/docs/api/java/util/stream/Stream.html)

```java
IntStream.range(0, 1_000_000)
    .filter(n -> n % 2 == 0)
    .map(n -> n * 2)
    .limit(100)
    .sum();  // Terminal operation triggers evaluation
```

#### Key Distinctions

| Aspect | Java Streams | Swift Range.Lazy |
|--------|--------------|------------------|
| Lazy evaluation | Yes | Yes |
| Parallel support | Yes | No (future) |
| Single-use | Yes | Multiple (Iterator) |
| Move-only support | No | **Yes** |
| Ownership semantics | N/A (GC) | **Explicit** |

Java Streams are single-use (consumed after terminal operation), whereas `Range.Lazy` can create multiple independent iterators via `makeIterator()`.

---

### 7. OCaml: Seq and Iterator Design

#### The Seq Type

OCaml's `Seq` module provides lazy sequences:

```ocaml
type 'a node = Nil | Cons of 'a * 'a t
and 'a t = unit -> 'a node
```

> "The key difference from lists is that `Seq.Cons`'s second component is a function returning a sequence, enabling lazy evaluation."
> — [OCaml Sequences](https://ocaml.org/docs/sequences)

#### Producer vs Consumer Control

OCaml distinguishes two iterator styles:

> "With a `'a gen = unit -> 'a option`, the consumer is in control, while with `'a sequence = ('a -> unit) -> unit` the producer is in control."
> — [OCaml Iterators](http://ocamlverse.net/content/iterators.html)

This maps to Swift Institute's design:
- **Consumer control**: `makeIterator()` + `next()`
- **Producer control**: `forEach { }` / `drain { }`

**Swift Institute provides both** via the Property.View pattern, whereas most languages offer only one.

---

### 8. Kotlin: Ranges and Progressions

#### Range/Progression Distinction

Kotlin separates ranges (bounds) from progressions (iteration):

```kotlin
val range = 1..10  // IntRange: just bounds
val progression = 1..10 step 2  // IntProgression: with step
```

> "Ranges define closed intervals in the mathematical sense: a range is defined by its two endpoint values which are both included in the range."
> — [Kotlin Ranges](https://kotlinlang.org/docs/ranges.html)

#### Comparison

| Aspect | Kotlin | Swift Range.Lazy |
|--------|--------|------------------|
| Range ≠ Iterator | Partially | **Yes** |
| Step support | Yes | No (by design) |
| Lazy sequences | Via `Sequence` | **Native** |
| Move-only | No | **Yes** |

Kotlin's `IntRange` implements `Iterable`, maintaining the Range-Iterator coupling that Rust is now deprecating.

---

### 9. Zig: Comptime Generics

#### Iterator Pattern

Zig uses comptime (compile-time) generics for iterator interfaces:

```zig
fn Iterator(comptime T: type) type {
    return struct {
        pub fn next(self: *@This()) ?T { ... }
        pub fn reset(self: *@This()) void { ... }
    };
}
```

> "Returning a struct type is how you make generic data structures in Zig."
> — [Learning Zig Generics](https://www.openmymind.net/learning_zig/generics/)

#### Comparison

| Aspect | Zig | Swift Range.Lazy |
|--------|-----|------------------|
| Comptime generics | Yes | Yes (Swift generics) |
| Explicit memory | Yes | Via ~Copyable |
| Iterator protocol | Convention | Property.View |
| Type safety | Comptime | Type system |

Zig's approach is lower-level, requiring explicit memory management without the ownership abstractions that Swift Institute provides.

---

## Part II: Academic Foundations

### 1. Substructural Type Systems

Swift's `~Copyable` corresponds to **affine types** in substructural type theory:

| Type System | Contraction | Weakening | Usage |
|-------------|-------------|-----------|-------|
| Linear | No | No | Exactly once |
| **Affine** | No | Yes | **At most once** |
| Relevant | Yes | No | At least once |
| Unrestricted | Yes | Yes | Any number |

> "A value of linear type is like a coin—you can spend it, but you can spend it only once."
> — [CS 6110 Cornell](https://www.cs.cornell.edu/courses/cs6110/2017sp/lectures/lec30.pdf)

Swift's `~Copyable` is affine (at most once), enabling:
- Move semantics without garbage collection
- Compile-time resource tracking
- Safe destructive operations

### 2. Wadler's "Linear Types Can Change the World"

Philip Wadler's seminal 1990 paper established linear types for resource management:

> "Values belonging to a linear type must be used exactly once: like the world, they cannot be duplicated or destroyed. Such values require no reference counting or garbage collection."
> — [Wadler, 1990](https://www.semanticscholar.org/paper/Linear-Types-can-Change-the-World!-Wadler/24c850390fba27fc6f3241cb34ce7bc6f3765627)

Swift Institute's `drain` operation directly implements this: consuming iteration that "uses" each element exactly once.

### 3. Linear Haskell (Bernardy et al., 2017)

The Linear Haskell paper formalized linear types in a practical setting:

> "Linear Haskell: practical linearity in a higher-order polymorphic language."
> — [Proceedings of the ACM on Programming Languages](https://arxiv.org/pdf/1710.09756)

Swift Institute's approach differs by:
1. **Affine, not linear**: Values can be dropped (weakening allowed)
2. **Borrowing semantics**: `forEach` borrows without consuming
3. **Explicit iteration patterns**: Property.View distinguishes ownership

### 4. Phantom Types and Type-Safe Indices

Swift Institute's `Index<Tag>` uses phantom types for compile-time safety:

> "A phantom type is a generic type that is declared but never used inside a type where it is declared. It is usually used as a generic constraint to build a more type-safe and robust API."
> — [Swift with Majid](https://swiftwithmajid.com/2021/02/18/phantom-types-in-swift/)

Academic foundations:
- Cheney & Hinze, "First-Class Phantom Types" (Cornell)
- GADTs as "guarded recursive data types"

This prevents index confusion:

```swift
let userIndex: Index<User> = ...
let orderIndex: Index<Order> = ...
// userIndex == orderIndex  // Compile error: different types
```

No other range library integrates phantom-typed indices at this level.

---

## Part III: The Index Domain Pattern

### Novel Contribution

Swift Institute's **Index Domain** pattern is a novel contribution to range design:

```
Range.Lazy<Bound> = { start: Int, end: Int, transform: Int → Bound }
```

| Aspect | Index Domain | Bound Projection |
|--------|--------------|------------------|
| Type | `Int` (always Copyable) | `Bound: ~Copyable` |
| Storage | Stored directly | **Never stored** |
| Operations | O(1) count, reversal | Regenerated on access |

This pattern:
1. **Avoids storing ~Copyable values**
2. **Enables O(1) operations** (count, isEmpty)
3. **Supports random access** via subscript regeneration
4. **Prevents memoization leaks** (unlike Scala)

### Comparison with Prior Art

| Language | Stores Elements | Regenerative | Move-Only |
|----------|-----------------|--------------|-----------|
| Python range | No | Yes | No |
| Rust Range | No | N/A (Copy bounds) | No |
| Scala LazyList | **Yes (memoized)** | No | No |
| Java Stream | No | Yes | No |
| **Swift Range.Lazy** | **No** | **Yes** | **Yes** |

Swift Institute is unique in combining regenerative semantics with move-only support.

---

## Part IV: Feature Matrix

### Comprehensive Comparison

| Feature | Rust RFC 3550 | C++20 | Haskell | Scala | Python | Java | OCaml | Kotlin | **Swift Range.Lazy** |
|---------|---------------|-------|---------|-------|--------|------|-------|--------|---------------------|
| **Range ≠ Iterator** | Yes | Partial | N/A | No | Yes | Yes | Yes | No | **Yes** |
| **Lazy evaluation** | Via IntoIter | Yes | Yes | Yes | Yes | Yes | Yes | Via Seq | **Yes** |
| **Move-only bounds** | No | Partial | Linear | No | No | No | No | No | **Yes** |
| **Regenerative** | No | Yes | Lazy | No | Yes | Yes | Yes | N/A | **Yes** |
| **Borrowing iteration** | Yes | Yes | N/A | N/A | N/A | N/A | N/A | N/A | **Yes (forEach)** |
| **Consuming iteration** | Yes | Yes | Folds | N/A | N/A | N/A | N/A | N/A | **Yes (drain)** |
| **Phantom-typed indices** | No | No | No | No | No | No | No | No | **Yes** |
| **Typed offsets** | No | No | No | No | No | No | No | No | **Yes** |
| **Index Domain pattern** | No | No | No | No | Partial | No | No | No | **Yes** |
| **Property.View API** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **Yes** |
| **No memoization leaks** | N/A | N/A | Lazy | **No** | Yes | Yes | Yes | N/A | **Yes** |

---

## Part V: Design Decisions Validated

### 1. Property.View Pattern: Mandatory, Not Stylistic

The research validates that Property.View for `forEach`/`drain` is **mandatory**:

> "Direct mutating iteration methods are intentionally avoided because... Property.View with `_lifetime` annotations enables safe interior pointer access."

This pattern appears nowhere else in surveyed languages, representing a Swift Institute innovation for safe ~Copyable iteration.

### 2. No Conditional Sequence Conformance

The decision to avoid conditional `Sequence` conformance when `Bound: Copyable` is validated by:

1. **Rust's lesson**: Mixing iterator semantics with value semantics caused 9 years of pain
2. **Constraint poisoning**: Generic contexts would lose ~Copyable support
3. **Clear mental model**: Range.Lazy is always generative, never a stored sequence

### 3. Index Domain Separation

The separation of index domain (Int) from bound projection (Bound) is unique and correct:

1. **Python range**: Similar pattern, but no move-only support
2. **C++ iota_view**: Similar pattern, but no ownership semantics
3. **Swift Range.Lazy**: Combines both with affine type support

---

## Part VI: Gaps and Opportunities

### Current Gaps (Addressed in Implementation)

| Gap | Status | Resolution |
|-----|--------|------------|
| Terminal operations | **Implemented** | `first(where:)`, `allSatisfy(_:)`, `count(where:)` |
| Typed subscript | **Implemented** | `subscript(offset: Index<Tag>.Offset)` |
| Documentation | **Implemented** | Index Domain concept, regeneration semantics |

### Future Opportunities

| Opportunity | Priority | Rationale |
|-------------|----------|-----------|
| `dropFirst(_:)`, `prefix(_:)` | Medium | Range manipulation |
| `enumerated(_:)` | Medium | Offset+element iteration |
| Parallel iteration | Low | Java Streams-style parallelism |
| `Range.Strided<Bound>` | Low | Step-based iteration |

### Not Recommended (Validated by Research)

| Feature | Reason |
|---------|--------|
| Full range taxonomy | Unnecessary complexity; transform provides flexibility |
| Memoization | Memory leak risk (Scala's lesson) |
| Conditional Sequence | Constraint poisoning; Rust's 9-year lesson |
| Stride on Lazy | Overhead on common case |

---

## Conclusion

Swift Institute's `Range.Lazy<Bound: ~Copyable>` represents a **best-in-class design** that:

1. **Solves problems other languages are still addressing**: Rust took 9 years to separate ranges from iterators (RFC 3550); Swift Institute designed this correctly from the start

2. **Provides unique ~Copyable support**: No other mainstream language offers first-class range iteration over move-only types

3. **Uses the novel Index Domain pattern**: Combines Python's regenerative semantics with Rust's ownership semantics

4. **Integrates phantom-typed indices**: Compile-time index safety unprecedented in range abstractions

5. **Distinguishes borrowing from consuming**: `forEach` vs `drain` maps directly to affine type theory

6. **Avoids memoization pitfalls**: Unlike Scala's LazyList, no memory leak risk

The design is grounded in:
- Wadler's linear type theory (1990)
- Linear Haskell's practical linearity (2017)
- Rust's hard-won iterator/range separation (RFC 3550, 2024)
- Phantom type research (Cheney & Hinze)

**Assessment**: Swift Range.Lazy is not merely competitive—it is architecturally superior to comparable abstractions in Rust, C++, Haskell, Scala, Python, Java, OCaml, and Kotlin.

---

## References

### Language Documentation

- [Rust RFC 3550: New Range Types](https://rust-lang.github.io/rfcs/3550-new-range.html)
- [C++20 Ranges Library](https://en.cppreference.com/w/cpp/ranges)
- [GHC Linear Types](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/linear_types.html)
- [Scala LazyList](https://www.scala-lang.org/api/current/scala/collection/immutable/LazyList.html)
- [Python range](https://www.pythonmorsels.com/range-is-a-lazy-sequence/)
- [Java Stream API](https://docs.oracle.com/javase/8/docs/api/java/util/stream/Stream.html)
- [OCaml Seq](https://ocaml.org/docs/sequences)
- [Kotlin Ranges](https://kotlinlang.org/docs/ranges.html)

### Academic Papers

- Wadler, P. (1990). "Linear Types can Change the World!" IFIP TC 2 Working Conference on Programming Concepts and Methods.
- Bernardy, J.-P., et al. (2017). "Linear Haskell: practical linearity in a higher-order polymorphic language." Proceedings of the ACM on Programming Languages.
- Walker, D. (2005). "Substructural Type Systems." Advanced Topics in Types and Programming Languages, MIT Press.
- Cheney, J. & Hinze, R. "First-Class Phantom Types." Cornell University.
- Fluet, M., et al. (2006). "Linear Regions are All You Need." European Symposium on Programming.

### Swift Evolution

- [SE-0390: Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0437: Noncopyable stdlib primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)

---

## Changelog

- **v1.0.0 (2026-01-25)**: Initial comprehensive comparative analysis
