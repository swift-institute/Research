# Three-Way Comparison Primitives: A Survey and Design for Swift
<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
---
-->

**swift-comparison-primitives**

---

## Abstract

Three-way comparison—determining whether one value is less than, equal to, or greater than another—is a fundamental operation in computing. While most programming languages provide comparison operators, the *result* of a comparison is often represented inconsistently: as integers in C and Java, as dedicated types in Rust and Haskell, or as a hierarchy of ordering categories in C++20. This paper surveys the theoretical foundations of comparison semantics, analyzes implementations across five major languages (Rust, Haskell, C++, Java, Scala), and proposes a design for `swift-comparison-primitives`—a Tier 0 atomic package in the Swift Institute's five-layer architecture. We argue that a dedicated `Comparison` enum with three cases (`.less`, `.equal`, `.greater`) provides superior type safety, semantic clarity, and composability compared to integer-based approaches, while remaining simpler than C++'s multi-category hierarchy for most use cases.

---

## 1. Introduction

### 1.1 Problem Statement

Comparison is ubiquitous in software: sorting algorithms, binary search, ordered collections, and decision logic all depend on determining the relative order of values. Yet the representation of comparison *results* varies significantly across programming languages:

- **Integer conventions**: C's `strcmp` returns negative, zero, or positive integers; Java's `Comparator.compare` follows the same pattern [1, 2].
- **Dedicated enum types**: Rust's `std::cmp::Ordering` and Haskell's `Ordering` provide explicit `Less`/`Equal`/`Greater` variants [3, 4].
- **Category hierarchies**: C++20 introduces `std::strong_ordering`, `std::weak_ordering`, and `std::partial_ordering` to distinguish semantic guarantees [5].

The integer convention suffers from several deficiencies: values like `-42` or `17` carry no semantic meaning beyond their sign, edge cases around `INT_MIN` can cause bugs when using subtraction, and the type system cannot prevent misuse. Meanwhile, C++'s hierarchy, while theoretically rigorous, introduces complexity that many applications do not require.

### 1.2 Scope and Constraints

This paper addresses the design of `swift-comparison-primitives`, a Tier 0 package in the Swift Institute's architecture [6]. Tier 0 packages are *atomic*: they have zero dependencies on other primitive packages and must compile without Foundation or any external frameworks. Key constraints include:

- **[PRIM-FOUND-001]**: No Foundation imports permitted [7]
- **[API-IMPL-003]**: All operations must be *total*—every valid input produces a valid output [8]
- **[API-NAME-001]**: Types must follow the `Nest.Name` namespace pattern [9]
- **[API-IMPL-005]**: One type per source file [8]

### 1.3 Contributions

This paper makes the following contributions:

1. A formal treatment of three-way comparison as an algebraic structure (Section 2)
2. A comprehensive survey of comparison primitives in five major languages (Section 3)
3. A comparative analysis identifying best practices and anti-patterns (Section 3.5)
4. A detailed design proposal for `swift-comparison-primitives` (Section 5)
5. Validation against Swift Institute requirements (Section 6)

---

## 2. Theoretical Foundations

### 2.1 Order Relations

**Definition 2.1** (Binary Relation). A *binary relation* R on a set S is a subset of S × S. We write a R b to denote (a, b) ∈ R.

**Definition 2.2** (Order Relation Properties). A binary relation ≤ on S is:
- *Reflexive* if ∀a ∈ S: a ≤ a
- *Antisymmetric* if ∀a,b ∈ S: (a ≤ b ∧ b ≤ a) → a = b
- *Transitive* if ∀a,b,c ∈ S: (a ≤ b ∧ b ≤ c) → a ≤ c

**Definition 2.3** (Partial Order). A *partial order* is a reflexive, antisymmetric, transitive relation. A set with a partial order is called a *poset*.

**Definition 2.4** (Total Order). A partial order ≤ is *total* if ∀a,b ∈ S: a ≤ b ∨ b ≤ a. Equivalently, every pair of elements is comparable.

### 2.2 Three-Way Comparison

Three-way comparison is the function that, given a total order ≤ on S and elements a, b ∈ S, determines the exact relationship:

**Definition 2.5** (Three-Way Comparison Function). For a totally ordered set (S, ≤), the three-way comparison function cmp: S × S → {−1, 0, +1} is defined as:

```
cmp(a, b) = −1  if a < b
          =  0  if a = b
          = +1  if a > b
```

More abstractly, we can represent the codomain as a three-element set **Cmp** = {less, equal, greater} rather than integers.

### 2.3 The Trichotomy Property

**Theorem 2.1** (Trichotomy). For any total order ≤ on S and elements a, b ∈ S, exactly one of the following holds:
1. a < b (strict less than)
2. a = b (equality)
3. a > b (strict greater than)

*Proof*. By totality, a ≤ b or b ≤ a. If both hold, antisymmetry gives a = b. If only a ≤ b holds with a ≠ b, then a < b. Symmetrically for a > b. Mutual exclusion follows from the definitions of strict inequalities. ∎

The trichotomy property is why three-way comparison returns exactly three values—no more, no less. This is a mathematical necessity for total orders.

### 2.4 Comparison as Algebraic Structure

The set **Cmp** = {less, equal, greater} exhibits algebraic structure under the reversal operation:

**Definition 2.6** (Reversal). The function rev: **Cmp** → **Cmp** is defined as:
- rev(less) = greater
- rev(equal) = equal
- rev(greater) = less

**Proposition 2.2**. Reversal is an *involution*: rev(rev(x)) = x for all x ∈ **Cmp**.

*Proof*. By case analysis:
- rev(rev(less)) = rev(greater) = less ✓
- rev(rev(equal)) = rev(equal) = equal ✓
- rev(rev(greater)) = rev(less) = greater ✓ ∎

**Proposition 2.3**. The structure (**Cmp**, equal, ·) forms a *monoid* under lexicographic chaining, where:

```
x · y = x    if x ≠ equal
      = y    if x = equal
```

*Proof*.
- *Identity*: equal · x = x and x · equal = x (when x ≠ equal, x · equal = x)
- *Associativity*: (x · y) · z = x · (y · z) by case analysis ∎

This monoid structure underlies the `then` combinator found in Rust and Haskell, enabling lexicographic comparison composition.

---

## 3. Survey of Existing Approaches

### 3.1 Rust: std::cmp::Ordering

Rust provides a dedicated enum type for comparison results [3]:

```rust
#[repr(i8)]
pub enum Ordering {
    Less = -1,
    Equal = 0,
    Greater = 1,
}
```

**Key Features**:

1. **Explicit Representation**: The `#[repr(i8)]` attribute ensures memory-efficient representation while maintaining semantic clarity.

2. **Query Methods** (stable since 1.53.0):
   - `is_eq()`, `is_ne()`: equality/inequality checks
   - `is_lt()`, `is_gt()`: strict ordering checks
   - `is_le()`, `is_ge()`: non-strict ordering checks

3. **Transformation Methods**:
   - `reverse()`: Swaps `Less` ↔ `Greater`, preserves `Equal`
   - `then(other: Ordering)`: Returns `self` if not `Equal`, else `other`
   - `then_with(f: FnOnce() -> Ordering)`: Lazy variant of `then`

4. **Trait Separation**: Rust distinguishes `PartialOrd` (returning `Option<Ordering>`) from `Ord` (returning `Ordering`) [10]. This separation explicitly models partial orders at the type level—`None` indicates incomparability.

**Example Usage**:
```rust
// Multi-field comparison with chaining
let result = x.name.cmp(&y.name)
    .then(x.age.cmp(&y.age))
    .then(x.id.cmp(&y.id));

// Reverse sorting
data.sort_by(|a, b| a.cmp(b).reverse());
```

**Analysis**: Rust's design achieves an excellent balance between type safety, ergonomics, and expressiveness. The `then` combinator directly implements the monoid structure from Section 2.4.

### 3.2 Haskell: Data.Ord.Ordering

Haskell's `Ordering` type is a simple algebraic data type [4]:

```haskell
data Ordering = LT | EQ | GT
```

**Key Features**:

1. **Monoid Instance**: Haskell explicitly provides a `Monoid` instance for `Ordering`:
   ```haskell
   instance Monoid Ordering where
       mempty = EQ
       LT <> _ = LT
       EQ <> y = y
       GT <> _ = GT
   ```
   This enables `comparison1 <> comparison2 <> comparison3` for lexicographic chaining.

2. **The comparing Combinator**:
   ```haskell
   comparing :: Ord a => (b -> a) -> b -> b -> Ordering
   ```
   This enables comparison by a projected key: `sortBy (comparing length) strings`.

3. **The Down Newtype**:
   ```haskell
   newtype Down a = Down { getDown :: a }
   ```
   Wrapping a value in `Down` reverses its ordering, enabling `sortBy (comparing Down)` for descending sorts.

**Analysis**: Haskell's strength lies in its combinator library and explicit algebraic structure. However, it lacks built-in support for partial orders—incomparability must be modeled manually with `Maybe Ordering`.

### 3.3 C++20: Ordering Categories

C++20 introduces three distinct ordering types as part of the "spaceship operator" (`<=>`) proposal [5, 11]:

```cpp
std::strong_ordering   // substitutability: a == b implies f(a) == f(b)
std::weak_ordering     // equivalence: a == b but may be distinguishable
std::partial_ordering  // allows incomparable pairs (returns unordered)
```

**Key Features**:

1. **Semantic Categories**: Each ordering type carries different guarantees:
   - `strong_ordering`: Values comparing equal are *substitutable* (indistinguishable)
   - `weak_ordering`: Values may compare equal but remain distinguishable
   - `partial_ordering`: Some pairs may be incomparable (e.g., NaN in floats)

2. **Implicit Conversions**: `strong_ordering` implicitly converts to `weak_ordering`, which implicitly converts to `partial_ordering`.

3. **Synthesized Comparisons**: The compiler can generate comparison operators from a single `operator<=>` definition.

**Analysis**: C++'s multi-category approach is theoretically rigorous and handles edge cases like floating-point NaN. However, the complexity is often unnecessary—most types require only total ordering. The implicit conversion chain can also mask precision loss in semantic guarantees.

### 3.4 Java/Scala: Integer Return Convention

Java's `Comparator<T>` interface uses integers [2]:

```java
int compare(T o1, T o2)
// Returns: negative if o1 < o2, zero if equal, positive if o1 > o2
```

**Key Features** (Java 8+):

1. **Static Factory Methods**: `comparing()`, `comparingInt()`, etc.
2. **Chaining**: `thenComparing()` for lexicographic composition
3. **Reversal**: `reversed()` returns a new comparator
4. **Null Handling**: `nullsFirst()`, `nullsLast()` wrappers

Scala's `Ordering[T]` trait follows a similar pattern with `compare(x: T, y: T): Int` [12].

**Analysis**: The integer convention is well-established but semantically impoverished. Values like `-42` or `17` carry no meaning beyond their sign, and the lack of a dedicated type prevents compile-time enforcement of valid comparison results.

### 3.5 Comparative Analysis

| Feature | Rust | Haskell | C++20 | Java | Scala |
|---------|------|---------|-------|------|-------|
| **Result Type** | Enum | ADT | Category hierarchy | Int | Int |
| **Type Safety** | High | High | High | Low | Low |
| **Partial Order Support** | `Option<Ordering>` | Manual | `partial_ordering` | Manual | Manual |
| **Chaining Combinator** | `then()` | Monoid `<>` | N/A | `thenComparing()` | `orElse` |
| **Reversal** | `reverse()` | `Down` newtype | N/A | `reversed()` | `reverse` |
| **Projection** | N/A | `comparing` | N/A | `comparing()` | `Ordering.by` |
| **Query Methods** | `is_*()` family | Pattern match | N/A | N/A | N/A |

**Best Practices Identified**:

1. **Use a dedicated enum type** rather than integers for semantic clarity and type safety
2. **Provide reversal as an operation**, not requiring manual negation
3. **Support chaining** for multi-field lexicographic comparison
4. **Separate total from partial ordering** at the type level when needed
5. **Include query methods** for convenient boolean extraction

**Anti-Patterns to Avoid**:

1. **Integer subtraction for comparison**: `a - b` risks overflow for extreme values
2. **Magic integer values**: Using arbitrary integers beyond -1/0/+1
3. **Conflating equality with equivalence**: `a == b` should not imply substitutability unless explicitly guaranteed

---

## 4. Current Swift Landscape

### 4.1 Swift.Comparable Protocol

Swift's standard library provides the `Comparable` protocol [13]:

```swift
public protocol Comparable: Equatable {
    static func < (lhs: Self, rhs: Self) -> Bool
}
```

Default implementations derive `>`, `<=`, `>=` from `<` and `==`. This design follows the two-operator paradigm (separate `==` and `<`) rather than three-way comparison.

**Limitation**: No standard type represents the *result* of a comparison. Code must either:
- Chain boolean conditions: `if a < b { ... } else if a > b { ... } else { ... }`
- Use the third-party result type (which this paper addresses)

### 4.2 Existing Comparison Type

The Swift Institute's `swift-algebra-primitives` package currently contains a `Comparison` enum [14]:

```swift
public enum Comparison: Sendable, Hashable, CaseIterable {
    case less
    case equal
    case greater
}
```

This implementation provides:
- Reversal: `reversed` property and `!` prefix operator
- Construction from `Comparable`: `init<T: Comparable>(_ lhs: T, _ rhs: T)`
- Boolean queries: `isLess`, `isEqual`, `isGreater`, `isLessOrEqual`, `isGreaterOrEqual`
- `Finite.Enumerable` conformance with ordinals
- `Codable` support (when not in embedded mode)

**Architectural Issue**: The type resides in Tier 4 (`swift-algebra-primitives`) but has zero dependencies—it should be Tier 0. This prevents lower-tier packages from using comparison results.

### 4.3 Gap Analysis

| Requirement | Current State | Gap |
|-------------|---------------|-----|
| Tier 0 placement | Tier 4 (algebra) | Migration needed |
| Foundation independence | Satisfied | None |
| Chaining combinator | Missing | Add `then(_:)` method |
| Lazy chaining | Missing | Add `then(with:)` method |
| Namespace compliance | Uses bare `Comparison` | Evaluate `Comparison.Result` |

---

## 5. Design Recommendations

### 5.1 Namespace Structure

Following [API-NAME-001], we recommend the namespace `Comparison` with nested types:

```
Comparison           (namespace enum, no cases)
Comparison.Result    (the three-way result type)
```

**Rationale**: Using `Comparison.Result` clearly distinguishes the *result* of a comparison from the *operation* of comparing. The outer `Comparison` namespace can later accommodate related types (e.g., `Comparison.Partial.Result` for partial orders).

**Alternative Considered**: Keeping bare `Comparison` as the result type (current design). This is acceptable given the type's simplicity, but the nested pattern provides better extensibility.

### 5.2 Core Type Design

```swift
/// Namespace for comparison-related types.
public enum Comparison {}

extension Comparison {
    /// Result of a three-way comparison: less, equal, or greater.
    ///
    /// Represents the outcome of comparing two totally ordered values.
    /// Corresponds to the signum of (a - b) in mathematical terms.
    public enum Result: Sendable, Hashable, CaseIterable {
        /// First value is less than second.
        case less

        /// Values are equal.
        case equal

        /// First value is greater than second.
        case greater
    }
}
```

**Design Decisions**:

1. **Three cases only**: Matches the trichotomy theorem (Section 2.3)
2. **Protocol conformances**:
   - `Sendable`: Safe for concurrent use
   - `Hashable`: Usable as dictionary key
   - `CaseIterable`: Enumeration support
3. **No raw value**: Unlike Rust's `#[repr(i8)]`, we avoid raw integer values to prevent magnitude comparisons

### 5.3 Operations

#### 5.3.1 Reversal

```swift
extension Comparison.Result {
    /// Returns the reversed comparison (less ↔ greater, equal unchanged).
    @inlinable
    public var reversed: Comparison.Result {
        switch self {
        case .less: return .greater
        case .equal: return .equal
        case .greater: return .less
        }
    }

    /// Returns the reversed comparison.
    @inlinable
    public static prefix func ! (value: Comparison.Result) -> Comparison.Result {
        value.reversed
    }
}
```

#### 5.3.2 Chaining (Monoid Operation)

```swift
extension Comparison.Result {
    /// Returns self if not equal, otherwise returns other.
    ///
    /// Enables lexicographic comparison composition:
    /// ```swift
    /// x.name.compare(y.name)
    ///     .then(x.age.compare(y.age))
    ///     .then(x.id.compare(y.id))
    /// ```
    @inlinable
    public func then(_ other: Comparison.Result) -> Comparison.Result {
        switch self {
        case .equal: return other
        case .less, .greater: return self
        }
    }

    /// Returns self if not equal, otherwise evaluates and returns the closure.
    ///
    /// Lazy variant that avoids computing subsequent comparisons when
    /// the result is already determined.
    @inlinable
    public func then(with other: () -> Comparison.Result) -> Comparison.Result {
        switch self {
        case .equal: return other()
        case .less, .greater: return self
        }
    }
}
```

#### 5.3.3 Boolean Properties

```swift
extension Comparison.Result {
    /// Whether the comparison is `.less`.
    @inlinable public var isLess: Bool { self == .less }

    /// Whether the comparison is `.equal`.
    @inlinable public var isEqual: Bool { self == .equal }

    /// Whether the comparison is `.greater`.
    @inlinable public var isGreater: Bool { self == .greater }

    /// Whether the comparison is `.less` or `.equal`.
    @inlinable public var isLessOrEqual: Bool { self != .greater }

    /// Whether the comparison is `.greater` or `.equal`.
    @inlinable public var isGreaterOrEqual: Bool { self != .less }
}
```

#### 5.3.4 Construction from Comparable

```swift
extension Comparison.Result {
    /// Creates a comparison result from two comparable values.
    @inlinable
    public init<T: Comparable>(_ lhs: T, _ rhs: T) {
        if lhs < rhs {
            self = .less
        } else if lhs > rhs {
            self = .greater
        } else {
            self = .equal
        }
    }
}
```

### 5.4 Protocol Conformances

#### 5.4.1 Finite.Enumerable

```swift
extension Comparison.Result: Finite.Enumerable {
    @inlinable
    public static var count: Cardinal { 3 }

    @inlinable
    public var ordinal: Ordinal {
        switch self {
        case .less: 0
        case .equal: 1
        case .greater: 2
        }
    }

    @inlinable
    public init(__unchecked: Void, ordinal: Ordinal) {
        self = [.less, .equal, .greater][ordinal]
    }
}
```

#### 5.4.2 Codable

```swift
#if !hasFeature(Embedded)
extension Comparison.Result: Codable {}
#endif
```

### 5.5 File Organization

Following [API-IMPL-005] (one type per file):

```
Sources/Comparison Primitives/
├── Comparison.swift                      // Namespace enum
├── Comparison.Result.swift               // Core enum definition
├── Comparison.Result+Reversal.swift      // reversed, prefix !
├── Comparison.Result+Chaining.swift      // then(_:), then(with:)
├── Comparison.Result+BooleanProperties.swift
├── Comparison.Result+Comparable.swift    // init from Comparable
├── Comparison.Result+Finite.swift        // Finite.Enumerable
├── Comparison.Result+Codable.swift       // Codable (non-embedded)
└── exports.swift                         // Re-exports if needed
```

---

## 6. Validation Against Requirements

### 6.1 [API-NAME-001] Compliance

✓ **Namespace Structure**: `Comparison.Result` follows `Nest.Name` pattern
✓ **No Compound Identifiers**: Method names like `isLess` are simple, not compound

### 6.2 [API-IMPL-003] Totality

✓ **All operations are total**:
- `reversed`: Always produces valid output
- `then(_:)`: Always produces valid output
- `init<T: Comparable>`: Always produces valid output for valid inputs
- Boolean properties: Always produce `Bool`

No precondition failures, no optional returns, no throwing.

### 6.3 [PRIM-FOUND-001] Foundation Independence

✓ **Zero Foundation imports**: The design uses only Swift standard library types
✓ **Embedded support**: `Codable` conformance gated behind `#if !hasFeature(Embedded)`

### 6.4 [API-IMPL-005] One Type Per File

✓ **File structure** in Section 5.5 places each logical unit in a separate file

---

## 7. Conclusion

Three-way comparison is a fundamental operation deserving a dedicated type rather than ad-hoc integer conventions. Our survey reveals that languages with explicit comparison types (Rust, Haskell, C++) provide superior type safety and expressiveness compared to integer-based approaches (Java, Scala).

For Swift, we recommend:

1. **A dedicated `Comparison.Result` enum** with `.less`, `.equal`, `.greater` cases
2. **Reversal and chaining operations** following the algebraic structure identified in Section 2.4
3. **Boolean query properties** for convenient condition extraction
4. **Placement at Tier 0** to enable use throughout the primitive hierarchy

This design achieves the Swift Institute's goals of totality, Foundation independence, and namespace compliance while providing a type-safe, ergonomic API for three-way comparison results.

---

## References

[1] ISO/IEC 9899:2018. *Programming Languages — C*. International Organization for Standardization, 2018.

[2] Oracle Corporation. "Interface Comparator<T>." *Java SE 21 Documentation*, 2023. https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Comparator.html

[3] The Rust Project Developers. "Enum std::cmp::Ordering." *Rust Standard Library Documentation*, 2024. https://doc.rust-lang.org/std/cmp/enum.Ordering.html

[4] Haskell Committee. "Data.Ord." *Haskell Base Library Documentation*, 2024. https://hackage.haskell.org/package/base/docs/Data-Ord.html

[5] Sutter, H. "P0515R3: Consistent comparison." *ISO/IEC JTC1/SC22/WG21*, 2017. https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0515r3.pdf

[6] Swift Institute. "Five Layer Architecture." *Swift Institute Documentation*, 2025. `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/Five Layer Architecture.md`

[7] Swift Institute. "Primitives Requirements." *Swift Primitives Documentation*, 2025. `/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Primitives Requirements.md`

[8] Swift Institute. "API Implementation." *Swift Institute Documentation*, 2025. `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/API Implementation.md`

[9] Swift Institute. "API Naming." *Swift Institute Documentation*, 2025. `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/API Naming.md`

[10] The Rust Project Developers. "RFC 0100: Add a `partial_cmp` method to `PartialOrd`." *Rust RFCs*, 2014. https://rust-lang.github.io/rfcs/0100-partial-cmp.html

[11] Revzin, B. "P1186R3: When do you actually use <=>?" *ISO/IEC JTC1/SC22/WG21*, 2019. https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1186r3.html

[12] EPFL. "scala.math.Ordering." *Scala Standard Library Documentation*, 2024. https://www.scala-lang.org/api/current/scala/math/Ordering.html

[13] Apple Inc. "Comparable." *Swift Standard Library Documentation*, 2024. https://developer.apple.com/documentation/swift/comparable

[14] Swift Institute. "Comparison.swift." *swift-algebra-primitives*, 2025. `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Primitives/Comparison.swift`
