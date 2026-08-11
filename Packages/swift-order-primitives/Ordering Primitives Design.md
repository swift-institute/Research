# Ordering Primitives: Comparators, Combinators, and Projections
<!--
---
version: 1.0.0
last_updated: 2026-01-22
status: RECOMMENDATION
---
-->

**swift-ordering-primitives**

---

## Abstract

While three-way comparison *results* answer "how do two values relate?", *ordering abstractions* answer "how should values be compared?" This distinction—between comparison as value versus comparison as function—is fundamental to flexible, composable sorting and ordering operations. This paper surveys ordering abstractions across major programming languages, analyzes their combinator patterns, and proposes a design for `swift-ordering-primitives`—a Tier 0 package providing reified comparators, direction enums, and projection-based ordering for Swift. We demonstrate that first-class comparators with proper combinator support enable powerful composition patterns while maintaining type safety and concurrency guarantees through `@Sendable` constraints.

---

## 1. Introduction

### 1.1 Problem Statement: Abstract Ordering Behavior

Consider sorting a collection of `Person` records. The *natural* ordering might be alphabetical by name, but applications frequently need alternative orderings: by age, by registration date, descending by score, or compound orderings like "by department ascending, then by salary descending."

Most languages provide two mechanisms:

1. **Natural ordering**: A type declares its preferred comparison (Swift's `Comparable`, Java's `Comparable<T>`)
2. **External comparators**: A separate object or closure defines comparison (Java's `Comparator<T>`, Scala's `Ordering[T]`)

The second mechanism—*reified comparators*—enables:
- Multiple orderings for the same type
- Runtime-determined orderings
- Composition of orderings
- Reversal without modifying the type

However, Swift's standard library lacks a standardized comparator type. Sorting APIs accept closures directly:

```swift
array.sorted { $0.age < $1.age }
```

This works but provides no abstraction for storing, composing, or manipulating orderings as first-class values.

### 1.2 Distinction from Comparison

The companion paper on `swift-comparison-primitives` [1] addresses the *result* of comparison—the three-valued type indicating less/equal/greater. This paper addresses the *operation* of comparison—the function that produces those results.

| Concept | Package | Type | Role |
|---------|---------|------|------|
| Comparison Result | comparison-primitives | `Comparison.Result` | Value: outcome of comparing |
| Comparator | ordering-primitives | `Ordering.Comparator<T>` | Function: how to compare |
| Direction | ordering-primitives | `Ordering.Direction` | Modifier: ascending/descending |

### 1.3 Scope and Constraints

This paper designs `swift-ordering-primitives`, a Tier 0 package with constraints identical to `swift-comparison-primitives`:

- **[PRIM-FOUND-001]**: No Foundation imports [2]
- **[API-IMPL-003]**: All operations must be total [3]
- **[API-NAME-001]**: Types must follow `Nest.Name` pattern [4]

Additionally, comparators must support concurrency:
- **[API-CONC-001]**: Closure-based types must be `@Sendable` [5]

### 1.4 Contributions

1. Formal definition of comparators as contravariant functors (Section 2)
2. Analysis of combinator algebras for ordering composition (Section 2.2)
3. Comprehensive survey of ordering abstractions in five languages (Section 3)
4. Design proposal for `swift-ordering-primitives` (Section 5)
5. Validation against Swift Institute requirements (Section 6)

---

## 2. Theoretical Foundations

### 2.1 Comparators as First-Class Values

**Definition 2.1** (Comparator). A *comparator* on type T is a function c: T × T → **Cmp** where **Cmp** = {less, equal, greater}.

Comparators generalize the comparison function of totally ordered sets to arbitrary types, potentially with multiple valid orderings.

**Definition 2.2** (Comparator Equivalence). Two comparators c₁, c₂ on T are *equivalent* if ∀a,b ∈ T: c₁(a,b) = c₂(a,b).

**Definition 2.3** (Consistent Comparator). A comparator c is *consistent* if it defines a total order:
- *Antisymmetry*: c(a,b) = equal ∧ c(b,a) = equal → a and b are order-equivalent
- *Transitivity*: c(a,b) = less ∧ c(b,c) = less → c(a,c) = less
- *Totality*: c returns less, equal, or greater (never fails)

### 2.2 Combinator Algebra

Comparators support several composition operations that form an algebraic structure.

#### 2.2.1 Reversal

**Definition 2.4** (Reversal). For comparator c, its *reversal* rev(c) is defined as:
```
rev(c)(a, b) = c(b, a)
```

Equivalently, rev(c)(a, b) = reverse(c(a, b)) where reverse swaps less ↔ greater.

**Proposition 2.1** (Involution). rev(rev(c)) = c.

*Proof*. rev(rev(c))(a, b) = rev(c)(b, a) = c(a, b). ∎

#### 2.2.2 Lexicographic Chaining

**Definition 2.5** (Lexicographic Chain). For comparators c₁ and c₂ on T, the *chain* c₁ ⊕ c₂ is:
```
(c₁ ⊕ c₂)(a, b) = c₁(a, b)     if c₁(a, b) ≠ equal
                = c₂(a, b)     if c₁(a, b) = equal
```

**Proposition 2.2** (Monoid Structure). The set of comparators on T forms a monoid under ⊕:
- *Identity*: The trivial comparator ε where ε(a,b) = equal for all a,b
- *Associativity*: (c₁ ⊕ c₂) ⊕ c₃ = c₁ ⊕ (c₂ ⊕ c₃)

*Proof*. Associativity follows from the left-biased nature of the operation—the first non-equal result determines the outcome regardless of grouping. ∎

This monoid structure is the foundation of `thenComparing` in Java and `then` in Rust.

#### 2.2.3 Identity and Annihilator

**Definition 2.6** (Identity Comparator). The identity comparator ε(a,b) = equal for all a,b.

**Definition 2.7** (Natural Comparator). For `Comparable` type T, the natural comparator is:
```
nat(a, b) = Comparison.Result(a, b)
```

**Observation**. There is no annihilator element—no comparator c such that c ⊕ d = c for all d when c can return equal.

### 2.3 Projection-Based Ordering (Contravariant Functors)

**Definition 2.8** (Projection). For function f: A → B and comparator c on B, the *projected comparator* on A is:
```
proj(f, c)(a₁, a₂) = c(f(a₁), f(a₂))
```

**Proposition 2.3** (Contravariance). Projection is *contravariant* in the first argument:
- If we have f: A → B and g: B → C, with comparator c on C
- Then proj(g, c) is a comparator on B
- And proj(f, proj(g, c)) = proj(g ∘ f, c)

This contravariance justifies calling comparators *contravariant functors* from the category of types to the category of comparators.

**Example**: To compare `Person` records by age:
```
ageComparator = proj(person.age, naturalComparator<Int>)
```

### 2.4 Relationship to Category Theory

The structure of comparators can be formalized categorically:

- **Objects**: Types
- **Morphisms**: Functions
- **Functor**: `Comparator<_>` is a contravariant functor from **Type** to **Comparator**

The contravariant functor laws ensure that projection composes correctly:
```
proj(id, c) = c                              // Identity
proj(f, proj(g, c)) = proj(g ∘ f, c)         // Composition
```

---

## 3. Survey of Existing Approaches

### 3.1 Rust: Closure-Based Comparison

Rust does not provide a dedicated `Comparator` type. Instead, sorting functions accept closures directly [6]:

```rust
// Sort by closure
vec.sort_by(|a, b| a.name.cmp(&b.name));

// Chain comparisons manually
vec.sort_by(|a, b| {
    a.name.cmp(&b.name)
        .then(a.age.cmp(&b.age))
});
```

**Key Features**:

1. **Direct closure passing**: No wrapper type needed
2. **Ordering chaining**: `then()` and `then_with()` on `Ordering` enable composition
3. **Key extraction**: `sort_by_key(|x| x.field)` for simple projections

**Limitations**:
- No reified comparator type for storage or manipulation
- Reversal requires manual `reverse()` call on result
- No combinator for chaining comparators (only chaining results)

### 3.2 Haskell: Comparing and On Combinators

Haskell provides powerful combinators in `Data.Ord` [7]:

```haskell
-- Type signature
comparing :: Ord a => (b -> a) -> b -> b -> Ordering

-- Usage: sort by length
sortBy (comparing length) strings

-- Chaining via Monoid
sortBy (comparing name <> comparing age) people

-- Descending order via Down newtype
sortBy (comparing (Down . age)) people
```

**Key Features**:

1. **`comparing` combinator**: Projects before comparing
2. **Monoid instance**: `Ordering` is a monoid, enabling `<>` for chaining
3. **`Down` newtype**: Reverses ordering via newtype wrapper
4. **`on` combinator**: `compare `on` f` compares by applying f

**Analysis**: Haskell's approach is elegant and algebraically principled. The Monoid instance on `Ordering` (not on comparators themselves) means chaining happens at the result level, but the effect is the same.

### 3.3 Scala: Ordering[T] Typeclass

Scala provides a dedicated typeclass for external orderings [8]:

```scala
trait Ordering[T] {
  def compare(x: T, y: T): Int

  // Combinators
  def reverse: Ordering[T]
  def on[U](f: U => T): Ordering[U]
  def orElse(other: Ordering[T]): Ordering[T]
}

object Ordering {
  def by[T, S: Ordering](f: T => S): Ordering[T]
}
```

**Key Features**:

1. **Explicit typeclass**: `Ordering[T]` is distinct from `Ordered[T]` (natural ordering)
2. **`reverse` method**: Returns reversed ordering
3. **`on` method**: Contravariant mapping (projection)
4. **`orElse` method**: Lexicographic chaining
5. **`by` factory**: Creates ordering from key extractor
6. **Context parameters**: `given`/`using` for implicit resolution

**Example**:
```scala
given personOrdering: Ordering[Person] =
  Ordering.by(_.name).orElse(Ordering.by(_.age))
```

**Analysis**: Scala's design is comprehensive and well-suited to the typeclass pattern. The separation of `Ordering` (external) from `Ordered` (internal) mirrors the comparator/comparable distinction.

### 3.4 Java 8+: Comparator Default Methods

Java 8 dramatically enhanced `Comparator<T>` with default methods [9]:

```java
public interface Comparator<T> {
    int compare(T o1, T o2);

    // Static factories
    static <T, U extends Comparable<? super U>> Comparator<T>
        comparing(Function<? super T, ? extends U> keyExtractor);

    static <T> Comparator<T> comparingInt(ToIntFunction<? super T> keyExtractor);
    // ... comparingLong, comparingDouble

    // Instance methods
    default Comparator<T> reversed();
    default Comparator<T> thenComparing(Comparator<? super T> other);
    default <U extends Comparable<? super U>> Comparator<T>
        thenComparing(Function<? super T, ? extends U> keyExtractor);

    // Null handling
    static <T> Comparator<T> nullsFirst(Comparator<? super T> comparator);
    static <T> Comparator<T> nullsLast(Comparator<? super T> comparator);
}
```

**Key Features**:

1. **`comparing()` factory**: Creates comparator from key extractor
2. **Specialized extractors**: `comparingInt`, `comparingLong`, `comparingDouble` avoid boxing
3. **`reversed()`**: Returns reversed comparator
4. **`thenComparing()`**: Lexicographic chaining
5. **`nullsFirst()`/`nullsLast()`**: Null-safe wrappers

**Example**:
```java
Comparator<Person> comparator = Comparator
    .comparing(Person::getName)
    .thenComparing(Person::getAge)
    .reversed();
```

**Analysis**: Java's modern Comparator API is arguably the most feature-complete among mainstream languages. The combination of static factories, default methods, and method chaining creates an expressive DSL. However, the `int` return type loses semantic clarity.

### 3.5 Comparative Analysis

| Feature | Rust | Haskell | Scala | Java |
|---------|------|---------|-------|------|
| **Comparator Type** | None (closures) | Functions | `Ordering[T]` trait | `Comparator<T>` |
| **Result Type** | `Ordering` enum | `Ordering` ADT | `Int` | `int` |
| **Reversal** | `.reverse()` on result | `Down` newtype | `.reverse` method | `.reversed()` |
| **Chaining** | `.then()` on result | `<>` (Monoid) | `.orElse` | `.thenComparing()` |
| **Projection** | `sort_by_key` | `comparing` | `Ordering.by` | `Comparator.comparing()` |
| **Null Handling** | `Option` | `Maybe` | `Option` | `nullsFirst/Last` |
| **Concurrency Safety** | `Send + Sync` | Pure functions | N/A | Not enforced |

**Best Practices Identified**:

1. **Provide a reified comparator type** for storage and manipulation
2. **Support reversal as a method** returning a new comparator
3. **Support lexicographic chaining** via `then`/`orElse`
4. **Support projection** via key extraction
5. **Return semantic result type** (enum) not integers
6. **Ensure thread safety** for concurrent usage

---

## 4. Current Swift Landscape

### 4.1 Swift.Comparable vs External Comparators

Swift's `Comparable` protocol defines natural ordering:

```swift
protocol Comparable: Equatable {
    static func < (lhs: Self, rhs: Self) -> Bool
}
```

For external ordering, Swift relies on closure parameters:

```swift
array.sorted(by: { $0.age < $1.age })
array.sorted(by: <)  // Natural ordering
```

**Limitation**: No standard type represents a comparator. Closures cannot be:
- Stored in homogeneous collections
- Easily reversed
- Composed with combinators
- Guaranteed `Sendable`

### 4.2 Closure-Based Sorting APIs

Swift's sorting APIs accept two closure signatures:

```swift
// Boolean predicate (less-than)
func sorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element]

// Via Comparable
func sorted() -> [Element] where Element: Comparable
```

The boolean predicate approach loses information—the caller cannot distinguish "equal" from "not in increasing order."

### 4.3 Gap Analysis

| Requirement | Current State | Gap |
|-------------|---------------|-----|
| Reified comparator type | None | Need `Ordering.Comparator<T>` |
| Direction abstraction | None | Need `Ordering.Direction` |
| Reversal operation | Manual closure construction | Need `.reversed` property |
| Chaining operation | Manual closure composition | Need `.then(_:)` method |
| Projection | `sorted(by:)` with closure | Need `.by(_:)` factory |
| Sendable guarantee | Not enforced | Need `@Sendable` constraint |

---

## 5. Design Recommendations

### 5.1 Namespace Structure

```
Ordering                           (namespace enum)
Ordering.Direction                 (ascending/descending)
Ordering.Comparator<T>             (reified comparator)
Ordering.Projection<Root, Value>   (key-based ordering)
```

### 5.2 Ordering.Direction

```swift
extension Ordering {
    /// Direction of ordering: ascending or descending.
    public enum Direction: Sendable, Hashable, CaseIterable {
        /// Smaller values come first.
        case ascending

        /// Larger values come first.
        case descending

        /// Returns the opposite direction.
        @inlinable
        public var reversed: Direction {
            switch self {
            case .ascending: return .descending
            case .descending: return .ascending
            }
        }
    }
}
```

**Use Case**: Parameterizing sort direction in APIs:
```swift
func sort(by keyPath: KeyPath<Element, some Comparable>,
          direction: Ordering.Direction = .ascending)
```

### 5.3 Ordering.Comparator<T>

```swift
extension Ordering {
    /// A reified comparator that determines the relative order of two values.
    ///
    /// Comparators are first-class values that can be stored, composed, and
    /// passed to sorting functions. They encapsulate comparison logic while
    /// ensuring thread safety through `@Sendable` constraints.
    public struct Comparator<T>: Sendable {
        /// The underlying comparison function.
        @usableFromInline
        internal let compare: @Sendable (T, T) -> Comparison.Result

        /// Creates a comparator from a comparison function.
        @inlinable
        public init(_ compare: @escaping @Sendable (T, T) -> Comparison.Result) {
            self.compare = compare
        }

        /// Compares two values using this comparator.
        @inlinable
        public func callAsFunction(_ lhs: T, _ rhs: T) -> Comparison.Result {
            compare(lhs, rhs)
        }
    }
}
```

#### 5.3.1 Construction from Comparable

```swift
extension Ordering.Comparator where T: Comparable {
    /// Creates a comparator using the natural ordering of a Comparable type.
    @inlinable
    public init() {
        self.init { Comparison.Result($0, $1) }
    }

    /// The natural ascending comparator for Comparable types.
    @inlinable
    public static var ascending: Ordering.Comparator<T> {
        Ordering.Comparator()
    }

    /// The natural descending comparator for Comparable types.
    @inlinable
    public static var descending: Ordering.Comparator<T> {
        Ordering.Comparator().reversed
    }
}
```

#### 5.3.2 Reversal

```swift
extension Ordering.Comparator {
    /// Returns a comparator with reversed ordering.
    ///
    /// Elements that were ordered as less become greater, and vice versa.
    /// Equal elements remain equal.
    @inlinable
    public var reversed: Ordering.Comparator<T> {
        Ordering.Comparator { [compare] lhs, rhs in
            compare(lhs, rhs).reversed
        }
    }
}
```

#### 5.3.3 Lexicographic Chaining

```swift
extension Ordering.Comparator {
    /// Returns a comparator that uses this comparator first, then the other
    /// comparator to break ties.
    ///
    /// ```swift
    /// let byNameThenAge = Ordering.Comparator.by(\.name)
    ///     .then(.by(\.age))
    /// ```
    @inlinable
    public func then(_ other: Ordering.Comparator<T>) -> Ordering.Comparator<T> {
        Ordering.Comparator { [compare] lhs, rhs in
            compare(lhs, rhs).then(other.compare(lhs, rhs))
        }
    }

    /// Returns a comparator that uses this comparator first, then evaluates
    /// the closure to break ties.
    ///
    /// Lazy variant that avoids computing the secondary comparison when
    /// the primary comparison is decisive.
    @inlinable
    public func then(
        with other: @escaping @Sendable () -> Ordering.Comparator<T>
    ) -> Ordering.Comparator<T> {
        Ordering.Comparator { [compare] lhs, rhs in
            let primary = compare(lhs, rhs)
            if primary.isEqual {
                return other().compare(lhs, rhs)
            }
            return primary
        }
    }
}
```

#### 5.3.4 Projection (Contravariant Map)

> **Empirical Discovery [2026-01-22]**: Swift's `KeyPath<Root, Value>` type is **NOT** `Sendable`.
> Experiment verification revealed that KeyPath-based overloads cannot be included in a `@Sendable`
> comparator API. The design below uses closure-based selectors exclusively.

```swift
extension Ordering.Comparator {
    /// Creates a comparator using a key-extracting function.
    ///
    /// ```swift
    /// let byAge = Ordering.Comparator<Person>.by { $0.age }
    /// ```
    ///
    /// - Note: KeyPath-based overloads (`.by(\.age)`) are not provided because
    ///   `KeyPath` is not `Sendable` in Swift 6. Use closure syntax instead.
    @inlinable
    public static func by<Value: Comparable>(
        _ selector: @escaping @Sendable (T) -> Value
    ) -> Ordering.Comparator<T> {
        Ordering.Comparator { lhs, rhs in
            Comparison.Result(selector(lhs), selector(rhs))
        }
    }

    /// Creates a comparator using a key-extracting function and custom comparator.
    @inlinable
    public static func by<Value>(
        _ selector: @escaping @Sendable (T) -> Value,
        using comparator: Ordering.Comparator<Value>
    ) -> Ordering.Comparator<T> {
        Ordering.Comparator { lhs, rhs in
            comparator(selector(lhs), selector(rhs))
        }
    }
}
```

**Why No KeyPath Overloads?**

Swift 6 strict concurrency requires all captured values in `@Sendable` closures to be `Sendable`.
However, `KeyPath<Root, Value>` does not conform to `Sendable`:

```swift
// This does NOT compile in Swift 6:
public static func by<Value: Comparable>(
    _ keyPath: KeyPath<T, Value>  // KeyPath is not Sendable
) -> Ordering.Comparator<T> {
    Ordering.Comparator { lhs, rhs in  // @Sendable closure
        // error: capture of 'keyPath' with non-Sendable type 'KeyPath<T, Value>'
        Comparison.Result(lhs[keyPath: keyPath], rhs[keyPath: keyPath])
    }
}
```

The closure-based API provides equivalent functionality with full concurrency safety:

```swift
// Use this instead:
let byAge = Ordering.Comparator<Person>.by { $0.age }
let byName = Ordering.Comparator<Person>.by { $0.name }
```

### 5.4 Ordering.Projection<Root, Value>

For advanced use cases, a dedicated projection type enables additional composition:

> **Note**: KeyPath-based initializer removed due to Sendable constraints (see Section 5.3.4).

```swift
extension Ordering {
    /// A projection that extracts an orderable value from a root type.
    ///
    /// Projections can be composed and transformed before being converted
    /// to comparators, enabling flexible ordering specifications.
    public struct Projection<Root, Value: Comparable>: Sendable {
        /// The key extraction function.
        @usableFromInline
        internal let extract: @Sendable (Root) -> Value

        /// The direction of ordering.
        public let direction: Direction

        /// Creates a projection with the given extractor and direction.
        ///
        /// ```swift
        /// let byAge = Ordering.Projection<Person, Int>({ $0.age }, direction: .descending)
        /// ```
        @inlinable
        public init(
            _ extract: @escaping @Sendable (Root) -> Value,
            direction: Direction = .ascending
        ) {
            self.extract = extract
            self.direction = direction
        }

        /// Returns a projection with reversed direction.
        @inlinable
        public var reversed: Projection<Root, Value> {
            Projection(extract, direction: direction.reversed)
        }

        /// Converts this projection to a comparator.
        @inlinable
        public var comparator: Ordering.Comparator<Root> {
            let base = Ordering.Comparator<Root>.by(extract)
            return direction == .ascending ? base : base.reversed
        }
    }
}
```

### 5.5 Partial Ordering Consideration

For types with partial orders (where some pairs are incomparable), we can provide:

```swift
extension Ordering {
    /// A comparator for partially ordered types.
    ///
    /// Returns `nil` when two values are incomparable.
    public struct PartialComparator<T>: Sendable {
        @usableFromInline
        internal let compare: @Sendable (T, T) -> Comparison.Result?

        @inlinable
        public init(_ compare: @escaping @Sendable (T, T) -> Comparison.Result?) {
            self.compare = compare
        }

        @inlinable
        public func callAsFunction(_ lhs: T, _ rhs: T) -> Comparison.Result? {
            compare(lhs, rhs)
        }
    }
}
```

**Decision**: Include `PartialComparator` at Tier 0 for completeness, as floating-point NaN handling requires partial ordering semantics.

### 5.6 File Organization

```
Sources/Ordering Primitives/
├── Ordering.swift                           // Namespace enum
├── Ordering.Direction.swift                 // Direction enum
├── Ordering.Comparator.swift                // Core comparator struct
├── Ordering.Comparator+Reversal.swift       // reversed property
├── Ordering.Comparator+Chaining.swift       // then(_:), then(with:)
├── Ordering.Comparator+Projection.swift     // by(_:) factory methods
├── Ordering.Comparator+Comparable.swift     // init(), .ascending, .descending
├── Ordering.Projection.swift                // Projection struct
├── Ordering.PartialComparator.swift         // Partial ordering support
└── exports.swift                            // Re-export Comparison Primitives
```

### 5.7 Dependency on comparison-primitives

`swift-ordering-primitives` depends on `swift-comparison-primitives` for the `Comparison.Result` type. This creates a dependency graph:

```
swift-ordering-primitives (Tier 0)
    └── swift-comparison-primitives (Tier 0)
```

**Note**: Both packages remain Tier 0 because neither depends on packages outside the atomic tier. Intra-tier dependencies at Tier 0 are permitted when semantically justified.

---

## 6. Validation Against Requirements

### 6.1 [API-NAME-001] Compliance

✓ **Namespace Structure**:
- `Ordering.Direction` follows `Nest.Name`
- `Ordering.Comparator<T>` follows `Nest.Name`
- `Ordering.Projection<Root, Value>` follows `Nest.Name`

✓ **No Compound Identifiers**: Method names are simple (`reversed`, `then`, `by`)

### 6.2 [API-IMPL-003] Totality

✓ **All operations are total**:
- `Comparator.callAsFunction`: Always returns `Comparison.Result`
- `reversed`: Always returns valid comparator
- `then(_:)`: Always returns valid comparator
- `by(_:)`: Always returns valid comparator

**Exception**: `PartialComparator` returns `Optional` by design—this is intentional to model partial orders, not a violation of totality (the function itself is total; only the ordering is partial).

### 6.3 [PRIM-FOUND-001] Foundation Independence

✓ **Zero Foundation imports**: All types use only Swift standard library

### 6.4 [API-CONC-001] Sendable Compliance

✓ **All closures are @Sendable**: Enforced in type signatures
✓ **All types are Sendable**: `Direction`, `Comparator<T>`, `Projection<Root, Value>`

⚠️ **KeyPath Limitation Discovered**: Swift's `KeyPath<Root, Value>` does NOT conform to `Sendable`.
This means KeyPath-based projection APIs cannot be included in a fully `@Sendable`-compliant design.
Closure-based selectors (`.by { $0.field }`) are used instead of KeyPath syntax (`.by(\.field)`).

**Experiment Evidence**: `/Users/coen/Developer/swift-primitives/swift-ordering-primitives/experiments/`

---

## 7. Conclusion

Ordering primitives—reified comparators with combinator support—fill a significant gap in Swift's standard library. Our survey reveals that modern languages (Java 8+, Scala) provide comprehensive comparator APIs with projection, reversal, and chaining capabilities.

For Swift, we recommend:

1. **`Ordering.Direction`**: Simple ascending/descending enum
2. **`Ordering.Comparator<T>`**: Sendable comparator with combinators
3. **`Ordering.Projection<Root, Value>`**: Closure-based ordering specification
4. **`Ordering.PartialComparator<T>`**: Optional for partial orders

This design enables expressive, type-safe ordering composition:

```swift
let comparator = Ordering.Comparator<Person>
    .by { $0.department }
    .then(.by { $0.salary }.reversed)
    .then(.by { $0.name })
```

The algebraic structure (monoid under chaining, involution under reversal) ensures predictable composition behavior, while `@Sendable` constraints guarantee safe concurrent usage.

### Empirical Validation

All claims in this paper were verified through the Experiment Discovery workflow [EXP-012 through EXP-017]:

| Claim | Status | Evidence |
|-------|--------|----------|
| Comparators store @Sendable closures | **VERIFIED** | Compilation + actor boundary tests |
| Reversal is an involution | **VERIFIED** | Exhaustive testing over all cases |
| Chaining forms a monoid | **VERIFIED** | Identity and associativity laws tested |
| callAsFunction works | **VERIFIED** | Syntax `comparator(a, b)` compiles |
| KeyPath projection | **REFUTED** | KeyPath not Sendable; use closures |

The KeyPath limitation is a significant finding that shapes the final API. While `.by(\.age)` syntax would be more ergonomic, `.by { $0.age }` provides equivalent functionality with full concurrency safety.

---

## References

[1] Swift Institute. "Three-Way Comparison Primitives: A Survey and Design for Swift." *swift-comparison-primitives*, 2025.

[2] Swift Institute. "Primitives Requirements." *Swift Primitives Documentation*, 2025. `/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Primitives Requirements.md`

[3] Swift Institute. "API Implementation." *Swift Institute Documentation*, 2025. `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/API Implementation.md`

[4] Swift Institute. "API Naming." *Swift Institute Documentation*, 2025. `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/API Naming.md`

[5] Swift Institute. "API Concurrency." *Swift Institute Documentation*, 2025. `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/API Concurrency.md`

[6] The Rust Project Developers. "Module std::cmp." *Rust Standard Library Documentation*, 2024. https://doc.rust-lang.org/std/cmp/index.html

[7] Haskell Committee. "Data.Ord." *Haskell Base Library Documentation*, 2024. https://hackage.haskell.org/package/base/docs/Data-Ord.html

[8] EPFL. "scala.math.Ordering." *Scala Standard Library Documentation*, 2024. https://www.scala-lang.org/api/current/scala/math/Ordering.html

[9] Oracle Corporation. "Interface Comparator<T>." *Java SE 21 Documentation*, 2023. https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Comparator.html

[10] The Rust Project Developers. "RFC 0100: Add a `partial_cmp` method to `PartialOrd`." *Rust RFCs*, 2014. https://rust-lang.github.io/rfcs/0100-partial-cmp.html

[11] Sutter, H. "P0515R3: Consistent comparison." *ISO/IEC JTC1/SC22/WG21*, 2017. https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0515r3.pdf

[12] Revzin, B. "P1186R3: When do you actually use <=>?" *ISO/IEC JTC1/SC22/WG21*, 2019. https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1186r3.html

[13] Apple Inc. "Comparable." *Swift Standard Library Documentation*, 2024. https://developer.apple.com/documentation/swift/comparable
