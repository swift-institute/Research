# Equation Primitives Design

<!--
---
title: Equation Primitives Design
type: discovery
version: 2.1.0
date: 2026-01-22
last_updated: 2026-03-18
status: DECISION
package: swift-equation-primitives
applies_to: [swift-equation-primitives, swift-hash-primitives, swift-comparison-primitives]
---
-->

## Abstract

This document presents a systematic design analysis for `swift-equation-primitives`, a foundational package providing equality semantics with full `~Copyable` support. Through examination of existing primitives (`Comparison`, `Hash`), Swift's type system constraints, and a comprehensive cross-language literature study spanning Rust, Haskell, Scala, C++, Kotlin, Java, OCaml, and Zig, we establish that `Equation` is the semantic root of both ordering and hashing. We propose a protocol hierarchy that eliminates redundant `==` definitions while incorporating best-in-class design patterns from the broader programming language ecosystem.

---

## Part I: Literature Review

### 1. Theoretical Foundations

#### 1.1 Equivalence Relations in Mathematics

An equivalence relation `~` on a set `S` must satisfy three properties:

| Property | Definition | Implication |
|----------|------------|-------------|
| **Reflexivity** | `∀a ∈ S: a ~ a` | Every element equals itself |
| **Symmetry** | `∀a,b ∈ S: a ~ b → b ~ a` | Equality is bidirectional |
| **Transitivity** | `∀a,b,c ∈ S: a ~ b ∧ b ~ c → a ~ c` | Equality chains |

These properties form the mathematical contract that any equality implementation should satisfy.

#### 1.2 Partial Equivalence Relations (PERs)

A **partial equivalence relation** satisfies symmetry and transitivity but *not* reflexivity. This is precisely what IEEE 754 floating-point equality provides: `NaN ≠ NaN` violates reflexivity, but the relation remains symmetric and transitive for non-NaN values.

**Key insight**: The existence of PERs in real-world computing (floating-point) motivates the Rust distinction between `PartialEq` and `Eq`.

*Reference*: [Partial equivalence relation - Wikipedia](https://en.wikipedia.org/wiki/Partial_equivalence_relation)

#### 1.3 Equality and Substitutability

The **Leibniz property** (indiscernibility of identicals) states: if `a == b`, then for any predicate `P`, `P(a) == P(b)`. This is the foundation of the **substitution property**—equal values can be used interchangeably.

**Design tension**: Should equality imply substitutability? For value types, generally yes. For types with identity (entities), potentially not.

#### 1.4 Linear and Affine Types

From [type theory](https://en.wikipedia.org/wiki/Type_theory):

| Type System | Rule | Usage |
|-------------|------|-------|
| **Linear** | Use exactly once | Resources must be consumed |
| **Affine** | Use at most once | Resources may be dropped |

Swift's `~Copyable` implements **affine** semantics. The challenge: how do we compare two values when we cannot duplicate them?

**Solution**: `borrowing` parameters allow inspection without consumption, enabling equality comparison of move-only types.

*References*:
- [Linear types for programmers](https://twey.io/for-programmers/linear-types/)
- [Substructural type system - Wikipedia](https://en.wikipedia.org/wiki/Substructural_type_system)
- [CMU Lecture Notes on Linear Types](https://www.cs.cmu.edu/~fp/courses/15814-f20/lectures/23-linearity.pdf)

---

### 2. Rust: PartialEq and Eq

Rust's approach to equality is the most rigorous among mainstream systems languages, directly encoding the mathematical distinction between partial and full equivalence relations.

#### 2.1 The PartialEq/Eq Split

```rust
pub trait PartialEq<Rhs = Self> {
    fn eq(&self, other: &Rhs) -> bool;
    fn ne(&self, other: &Rhs) -> bool { !self.eq(other) }
}

pub trait Eq: PartialEq<Self> {
    // Marker trait - no additional methods
}
```

| Trait | Guarantees | Use Case |
|-------|------------|----------|
| `PartialEq` | Symmetric, transitive | Floating-point, partial orders |
| `Eq` | Reflexive, symmetric, transitive | HashMap keys, full equality |

**Design rationale**: The `Eq` marker exists solely because `NaN != NaN` in IEEE 754. Types implementing `Eq` promise reflexivity, enabling use as `HashMap` keys.

*References*:
- [PartialEq in std::cmp - Rust](https://doc.rust-lang.org/std/cmp/trait.PartialEq.html)
- [Eq in std::cmp - Rust](https://doc.rust-lang.org/std/cmp/trait.Eq.html)
- [Rust equality and ordering | Dongpo (2025)](https://0xpoe.dev/posts/2025-01-11-rust-std-cmp/)

#### 2.2 Protocol Hierarchy

```
         PartialEq
             │
      ┌──────┴──────┐
      │             │
     Eq         PartialOrd
      │             │
      └──────┬──────┘
             │
            Ord
```

**Key insight**: Rust separates *partial* equality from *full* equality, and *partial* ordering from *full* ordering. This four-way split is more precise than Swift's two-way split (`Equatable`/`Comparable`).

#### 2.3 Relevance to Swift Primitives

**Question**: Should `Equation.Protocol` be split into `Equation.Partial` and `Equation.Full`?

**Analysis**: Swift's `Double` and `Float` conform to `Equatable` despite `NaN != NaN`. The stdlib does not distinguish partial from full equality. For consistency with Swift conventions, we should follow the stdlib pattern (single equality protocol) rather than Rust's more rigorous split.

**Decision**: Single `Equation.Protocol` matching Swift's `Equatable` semantics.

---

### 3. Haskell: The Eq Typeclass

Haskell's `Eq` is the canonical functional programming approach to equality.

#### 3.1 Definition

```haskell
class Eq a where
    (==) :: a -> a -> Bool
    (/=) :: a -> a -> Bool

    -- Default implementations
    x == y = not (x /= y)
    x /= y = not (x == y)
```

**Minimal complete definition**: Either `(==)` or `(/=)`.

*Reference*: [Data.Eq - Hackage](https://hackage.haskell.org/package/base/docs/Data-Eq.html)

#### 3.2 The Single-Instance Property

Haskell guarantees **at most one instance** of a typeclass per type. This means the meaning of `==` for `Int` is globally unique—there cannot be multiple competing equality definitions.

**Contrast with Swift**: Swift allows multiple protocol conformances through conditional conformance. This is generally a feature, but means equality semantics can vary by context.

#### 3.3 No Laws in Eq

Notably, the Haskell Report defines **no laws** for `Eq`. The expectation of reflexivity, symmetry, and transitivity is conventional, not enforced.

**Criticism**: "The fault of Haskell's Eq is that it lives in a world in which there is only a single definition of equality per type, which is incorrect in general."

*Reference*: [Language Design: Equality & Identity – Fixing Haskell](https://soc.me/languages/equality-and-identity-fixing-haskell.html)

#### 3.4 Relevance to Swift Primitives

**Insight**: Like Haskell, we should provide default `!=` in terms of `==`. Unlike Haskell, Swift's type system allows more flexibility in protocol conformance.

---

### 4. Scala Cats: Type-Safe Equality

The Scala Cats library provides a disciplined functional approach to equality that prevents cross-type comparisons at compile time.

#### 4.1 The Eq Typeclass

```scala
trait Eq[A] {
  def eqv(x: A, y: A): Boolean
}

// Syntax extension enables === and =!=
1 === 1        // true
"a" === "b"    // false
1 === "hello"  // COMPILE ERROR - type mismatch
```

*Reference*: [Eq - Typelevel Cats](https://typelevel.org/cats/typeclasses/eq.html)

#### 4.2 Type Safety Advantage

Standard Scala/Java `==` allows comparing any two types, potentially returning `false` for incomparable types without warning. Cats `Eq` requires matching types at compile time.

**Example**:
```scala
1 == "1"        // false at runtime (standard Scala)
1 === "1"       // compile error (Cats Eq)
```

#### 4.3 Equality vs Equivalence Debate

The Cats community distinguishes:

| Concept | Definition | Example |
|---------|------------|---------|
| **Equality** | Full substitutability | `a == b` implies `f(a) == f(b)` for all `f` |
| **Equivalence** | Same-class membership | "Same birthday" is equivalence, not equality |

*Reference*: [Equivalence versus Equality - Typelevel](https://typelevel.org/blog/2017/04/02/equivalence-vs-equality.html)

#### 4.4 Relevance to Swift Primitives

**Insight**: Swift's generic system already prevents `Int == String` comparisons. The Cats pattern of requiring explicit `Eq` instances could inform a stricter API, but Swift's existing type safety is sufficient for our needs.

---

### 5. C++20: The Spaceship Operator

C++20 introduced a revolutionary approach to comparison with the three-way comparison operator (`<=>`).

#### 5.1 Comparison Categories

```cpp
#include <compare>

// Three ordering categories
std::strong_ordering   // Total order, substitutable equality
std::weak_ordering     // Total order, equivalence (not equality)
std::partial_ordering  // Partial order (NaN-compatible)
```

| Category | Reflexive | Symmetric | Transitive | Substitutable |
|----------|-----------|-----------|------------|---------------|
| `strong_ordering` | ✓ | ✓ | ✓ | ✓ |
| `weak_ordering` | ✓ | ✓ | ✓ | ✗ |
| `partial_ordering` | ✗ | ✓ | ✓ | ✗ |

*Reference*: [C++20: The Three-Way Comparison Operator](https://www.modernescpp.com/index.php/c-20-the-three-way-comparison-operator/)

#### 5.2 Separation of `==` and `<=>`

A critical C++20 design decision: `==` is **not** synthesized from `<=>` by default.

**Rationale**: Lexicographic comparison via `<=>` can be expensive (must compare all fields until difference found). Equality comparison can short-circuit on length/size differences first.

```cpp
struct String {
    auto operator<=>(const String&) const = default;  // Compares lexicographically
    bool operator==(const String&) const;             // Can optimize for length first
};
```

*Reference*: [Comparisons in C++20 | Barry's C++ Blog](https://brevzin.github.io/c++/2019/07/28/comparisons-cpp20/)

#### 5.3 Relevance to Swift Primitives

**Key insight**: Equality and comparison should be **independently optimizable**. Our design of separate `Equation.Protocol` and `Comparison.Protocol` (rather than deriving equality from comparison) aligns with C++20's approach.

**Design validation**: The C++20 committee's decision to keep `==` separate from `<=>` validates our architecture of `Equation` as a distinct primitive from `Comparison`.

---

### 6. Kotlin: Structural vs Referential Equality

Kotlin explicitly distinguishes two forms of equality in its syntax.

#### 6.1 Two Operators

| Operator | Name | Semantics |
|----------|------|-----------|
| `==` | Structural equality | Calls `equals()`, null-safe |
| `===` | Referential equality | Same object identity |

```kotlin
val a = listOf(1, 2, 3)
val b = listOf(1, 2, 3)

a == b   // true (same contents)
a === b  // false (different objects)
```

*Reference*: [Equality | Kotlin Documentation](https://kotlinlang.org/docs/equality.html)

#### 6.2 Data Classes

Kotlin `data class` automatically generates `equals()` and `hashCode()` based on constructor properties:

```kotlin
data class Point(val x: Int, val y: Int)

Point(1, 2) == Point(1, 2)  // true (auto-generated equals)
```

#### 6.3 Relevance to Swift Primitives

**Contrast with Swift**: Swift uses `==` for structural equality and `===` for reference identity, matching Kotlin. Our `Equation.Protocol` focuses on structural equality (`==`), which is the semantically meaningful comparison for value types.

---

### 7. Java: The equals/hashCode Contract

Java's approach, while older, established the canonical contract between equality and hashing.

#### 7.1 The Contract

| Rule | Requirement |
|------|-------------|
| **Reflexive** | `x.equals(x)` returns `true` |
| **Symmetric** | `x.equals(y) == y.equals(x)` |
| **Transitive** | If `x.equals(y)` and `y.equals(z)`, then `x.equals(z)` |
| **Consistent** | Multiple calls return same result |
| **Non-null** | `x.equals(null)` returns `false` |

**Critical invariant**: If `x.equals(y)`, then `x.hashCode() == y.hashCode()`.

*Reference*: [Java equals() and hashCode() Contracts | Baeldung](https://www.baeldung.com/java-equals-hashcode-contracts)

#### 7.2 Consequences of Violation

Violating the equals/hashCode contract causes:
- `HashMap` lookup failures
- Duplicate entries in `HashSet`
- Silent data corruption

#### 7.3 Relevance to Swift Primitives

**Design principle**: The Java contract between equals and hashCode is precisely why `Hash.Protocol` should refine `Equation.Protocol`. The dependency is semantic, not arbitrary.

**Implementation**: When `Hash.Protocol` refines `Equation.Protocol`, the semantic contract (equal objects have equal hashes) is enforced by the type system.

---

### 8. OCaml: The Perils of Polymorphic Compare

OCaml provides a cautionary tale about generic equality.

#### 8.1 Structural vs Physical Equality

| Operator | Name | Semantics |
|----------|------|-----------|
| `=` | Structural | Deep value comparison |
| `==` | Physical | Same memory location |

```ocaml
let a = [1; 2; 3]
let b = [1; 2; 3]

a = b   (* true - same structure *)
a == b  (* false - different allocations *)
```

*Reference*: [Structural Versus Physical Comparisons in OCaml](https://thealmarty.com/2018/10/09/structural-versus-physical-comparsions-in-ocaml/)

#### 8.2 Polymorphic Compare Problems

OCaml's polymorphic `compare` function works on any type but has serious issues:

| Problem | Description |
|---------|-------------|
| **Abstraction violation** | Ignores type system, crosses module boundaries |
| **Runtime exceptions** | Fails on functions, C objects |
| **Non-termination** | May loop on cyclic structures |
| **Performance** | Cannot be optimized for specific types |

*Reference*: [The perils of polymorphic compare - Jane Street](https://blog.janestreet.com/the-perils-of-polymorphic-compare/)

#### 8.3 Relevance to Swift Primitives

**Lesson**: Generic/polymorphic equality that ignores the type system is dangerous. Swift's protocol-based approach (requiring explicit conformance) is superior to OCaml's implicit polymorphic compare.

**Design validation**: Our approach of explicit `Equation.Protocol` conformance avoids OCaml's pitfalls.

---

### 9. Zig: Explicit Equality Functions

Zig takes an minimalist approach, avoiding operator overloading entirely.

#### 9.1 No Operator Overloading

```zig
const std = @import("std");

// Cannot use == for slices
const a = "hello";
const b = "hello";

// a == b  // COMPILE ERROR
std.mem.eql(u8, a, b)  // true - explicit function call
```

*Reference*: [Learning Zig - Language Overview](https://www.openmymind.net/learning_zig/language_overview_2/)

#### 9.2 Design Philosophy

Zig prioritizes:
- **Explicitness**: No hidden behavior behind operators
- **Predictability**: Operators do exactly what the language spec says
- **Control**: Programmer chooses comparison semantics explicitly

#### 9.3 Relevance to Swift Primitives

**Contrast**: Swift's operator overloading via protocols (`Equatable`, our `Equation.Protocol`) provides better ergonomics while maintaining type safety. Zig's approach is more explicit but less convenient.

**Hybrid insight**: Our `borrowing` parameter requirement makes the ownership semantics explicit (like Zig), while still providing operator syntax (like Swift stdlib).

---

### 10. IEEE 754 and Floating-Point Equality

The IEEE 754 standard for floating-point arithmetic creates the fundamental tension in equality design.

#### 10.1 NaN Behavior

```
NaN == NaN  → false  (not reflexive!)
NaN != NaN  → true
NaN < x     → false  (for any x)
NaN > x     → false  (for any x)
```

This violates reflexivity, making floating-point equality a **partial equivalence relation**.

*Reference*: [IEEE 754 - Wikipedia](https://en.wikipedia.org/wiki/IEEE_754)

#### 10.2 Total Ordering Alternative

IEEE 754-2008 provides `totalOrder`, a total ordering that handles NaN:

```
-NaN < -∞ < negative numbers < -0 < +0 < positive numbers < +∞ < +NaN
```

#### 10.3 Relevance to Swift Primitives

**Decision**: Following Swift stdlib, we treat `Double` and `Float` as implementing full equality (`Equation.Protocol`), accepting the NaN anomaly. This matches user expectations and stdlib precedent.

**Alternative considered**: A `Equation.Partial` protocol for types with non-reflexive equality. Rejected for simplicity and stdlib consistency.

---

### 11. Swift Evolution: Noncopyable Types and Equatable

Swift's noncopyable types (`~Copyable`) create new challenges for equality.

#### 11.1 The Fundamental Challenge

Traditional equality requires copying values:
```swift
func == (lhs: T, rhs: T) -> Bool  // Copies both arguments
```

For noncopyable types, this is impossible. Solution: `borrowing` parameters.

```swift
static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
```

*Reference*: [SE-0390: Noncopyable Structs and Enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)

#### 11.2 Philosophical Debate

From [SE-0499](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md):

> "It can be argued that non-Copyable types have identity, and therefore should not be Equatable in the current sense of the protocol."

**Counter-argument**: Noncopyable types like fixed-size strings or wrapped numbers naturally support equality comparison.

#### 11.3 Current Swift 6 Status

Swift 6 supports:
- `~Copyable` generic constraints
- `borrowing` parameters for comparison
- Conditional `Copyable` conformance

*Reference*: [Consume noncopyable types in Swift - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10170/)

---

### 12. Literature Summary: Best-in-Class Patterns

| Pattern | Source | Application |
|---------|--------|-------------|
| Partial vs Full equality | Rust | Consider for future expansion |
| Default `!=` from `==` | Haskell, Rust | Implement in `Equation.Protocol` |
| Type-safe comparison | Scala Cats | Already provided by Swift generics |
| Separate `==` from `<=>` | C++20 | Validates `Equation` separate from `Comparison` |
| `borrowing` for noncopyable | Swift 6 | Core design requirement |
| equals/hashCode contract | Java | Motivates `Hash` refining `Equation` |
| Explicit conformance | All | Avoids OCaml's polymorphic compare pitfalls |

---

## Part II: Design Analysis

### 13. Trigger Identification [RES-012]

**Category**: Cross-package consistency + Pattern extraction

**Trigger**: Creating `swift-equation-primitives` to serve as dependency for `swift-hash-primitives`, requiring analysis of the semantic relationship between equality, comparison, and hashing.

**Questions resolved by literature review**:
1. What is the minimal API for `Equation.Protocol`? → `==` with `borrowing` parameters; default `!=`
2. Should we split partial/full equality like Rust? → No, follow Swift stdlib precedent
3. Should `Hash.Protocol` refine `Equation.Protocol`? → Yes, per Java's equals/hashCode contract
4. What naming constraints apply? → Avoid `Equatable` shadow; use `Equation`

---

### 14. Scope Definition [RES-013]

**Packages in scope**:
- `swift-equation-primitives` (to be created)
- `swift-hash-primitives` (existing, to depend on equation)
- `swift-comparison-primitives` (existing, for consistency analysis)

**Decision types**:
- Protocol hierarchy (refinement relationships)
- Namespace naming (per [API-NAME-001], [API-NAME-007b])
- Dependency direction (per Five-Layer Architecture)

---

### 15. Design Decisions Inventory [RES-013]

#### 15.1 Current State Analysis

| Package | Protocol | Requires `==` | Requires `<` | Requires `hash(into:)` |
|---------|----------|---------------|--------------|------------------------|
| swift-comparison-primitives | `Comparison.Protocol` | Yes | Yes | No |
| swift-hash-primitives | `Hash.Protocol` | Yes | No | Yes |

**Observation**: Both protocols independently require `==`. This duplicates the Java/Haskell anti-pattern of embedding equality rather than refining it.

#### 15.2 Cross-Language Protocol Hierarchies

| Language | Equality | Ordering | Hashing |
|----------|----------|----------|---------|
| Swift stdlib | `Equatable` | `Comparable: Equatable` | `Hashable: Equatable` |
| Rust | `PartialEq`, `Eq: PartialEq` | `PartialOrd: PartialEq`, `Ord: Eq + PartialOrd` | `Hash` (no Eq requirement) |
| Haskell | `Eq` | `Ord: Eq` | (no stdlib Hash) |
| Java | `equals()` | `Comparable` | `hashCode()` (contract with equals) |

**Best practice**: Equality as root of hierarchy (Swift stdlib, Haskell, Java).

**Rust exception**: `Hash` does not require `Eq`, but documentation strongly recommends: "when implementing both Hash and Eq, it is important that [k1 == k2 implies hash(k1) == hash(k2)]."

---

### 16. Alternatives Considered [RES-016]

#### Alternative 1: Status Quo (No Equation Primitive)

**Rejected**: Violates DRY; no protocol for "equality only" use cases.

#### Alternative 2: Rust-Style Partial/Full Split

**Description**: `Equation.Partial` and `Equation.Full` protocols.

**Rejected because**:
- Swift stdlib doesn't distinguish (Float conforms to Equatable despite NaN)
- Adds complexity without clear benefit
- Would require all downstream code to choose between protocols

#### Alternative 3: Hash Without Equation Refinement (Rust-Style)

**Description**: `Hash.Protocol` independent of `Equation.Protocol`.

**Rejected because**:
- Violates Java's well-established equals/hashCode contract
- Swift stdlib's `Hashable: Equatable` sets precedent
- Allows semantically incorrect implementations

#### Alternative 4: Introduce Equation as Root (Chosen)

**Description**: `Equation.Protocol` with `==` only. `Hash.Protocol` and optionally `Comparison.Protocol` refine it.

**Accepted because**:
- Matches Swift stdlib pattern
- Matches Haskell, Java best practices
- Eliminates duplication
- Enforces equals/hashCode contract via type system

---

### 17. Protocol Design

#### 17.1 Namespace Selection

Per [API-NAME-007b], contested names must be avoided:

| Candidate | Issue | Resolution |
|-----------|-------|------------|
| `Equatable` | Shadows `Swift.Equatable` | Rejected |
| `Equality` | Abstract noun; inconsistent with `Comparison`, `Hash` | Considered |
| `Equation` | Concrete noun; parallels `Comparison` | **Selected** |

**Rationale**: `Comparison` describes *a comparison* (the thing). `Equation` describes *an equation* (the thing). Both are concrete nouns, not abstract capabilities.

#### 17.2 Protocol Requirements

```swift
extension Equation {
    /// A protocol for types that can be compared for equality, supporting both
    /// `Copyable` and `~Copyable` types.
    ///
    /// This protocol mirrors `Swift.Equatable` but uses `borrowing` parameters
    /// to enable equality comparison of move-only types without consuming them.
    ///
    /// ## Semantic Requirements
    ///
    /// Conforming types must satisfy the equivalence relation properties:
    /// - **Reflexive**: `a == a` is always `true`
    /// - **Symmetric**: `a == b` implies `b == a`
    /// - **Transitive**: `a == b` and `b == c` implies `a == c`
    ///
    /// ## Relationship to Swift.Equatable
    ///
    /// Types conforming to `Swift.Equatable` can conform to `Equation.Protocol`
    /// with empty conformance bodies, as the `==` operator already exists.
    public protocol `Protocol`: ~Copyable {
        /// Returns whether two values are equal.
        ///
        /// Two values that compare equal should be substitutable in most contexts.
        ///
        /// - Parameters:
        ///   - lhs: The left-hand side value.
        ///   - rhs: The right-hand side value.
        /// - Returns: `true` if `lhs` is equal to `rhs`.
        static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    }
}
```

#### 17.3 Default Implementations

Following Haskell and Rust patterns:

```swift
extension Equation.`Protocol` where Self: ~Copyable {
    /// Returns whether two values are not equal.
    ///
    /// Default implementation returns `!(lhs == rhs)`.
    @inlinable
    public static func != (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs == rhs)
    }
}
```

#### 17.4 Swift.Equatable Bridge

```swift
// Equation.Protocol+Swift.Equatable.swift

// MARK: - Integer Conformances
extension Int: Equation.`Protocol` {}
extension Int8: Equation.`Protocol` {}
extension Int16: Equation.`Protocol` {}
extension Int32: Equation.`Protocol` {}
extension Int64: Equation.`Protocol` {}
extension UInt: Equation.`Protocol` {}
extension UInt8: Equation.`Protocol` {}
extension UInt16: Equation.`Protocol` {}
extension UInt32: Equation.`Protocol` {}
extension UInt64: Equation.`Protocol` {}

// MARK: - Floating Point (accepting NaN anomaly per stdlib precedent)
extension Double: Equation.`Protocol` {}
extension Float: Equation.`Protocol` {}
#if canImport(CoreGraphics)
extension CGFloat: Equation.`Protocol` {}
#endif

// MARK: - Other Standard Library Types
extension Bool: Equation.`Protocol` {}
extension String: Equation.`Protocol` {}
extension Character: Equation.`Protocol` {}
extension Unicode.Scalar: Equation.`Protocol` {}
extension StaticString: Equation.`Protocol` {}
```

---

### 18. Dependency Analysis

#### 18.1 Current Dependencies

```
Hash Primitives
├── Comparison Primitives
│   └── Property Primitives
└── Property Primitives

Comparison Primitives
└── Property Primitives
```

#### 18.2 Proposed Dependencies

```
Hash Primitives
├── Equation Primitives (NEW)
│   └── Property Primitives
└── Property Primitives

Comparison Primitives
├── Equation Primitives (OPTIONAL - future consideration)
│   └── Property Primitives
└── Property Primitives
```

#### 18.3 Protocol Refinement

**Hash.Protocol (updated)**:
```swift
extension Hash {
    public protocol `Protocol`: Equation.`Protocol`, ~Copyable {
        borrowing func hash(into hasher: inout Hasher)
    }
}
```

This enforces the Java equals/hashCode contract at the type level: any type that can be hashed must also support equality comparison.

---

### 19. File Organization [API-IMPL-005]

```
swift-equation-primitives/
├── Sources/
│   └── Equation Primitives/
│       ├── Equation.swift                           # Namespace enum
│       ├── Equation.Protocol.swift                  # Protocol + default !=
│       ├── Equation.Protocol+Swift.Equatable.swift  # Stdlib bridges
│       └── exports.swift                            # Re-exports
├── Research/
│   └── Equation Primitives Design.md                # This document
└── Package.swift
```

---

### 20. Implementation Plan

#### Phase 1: Create Equation Primitives

1. Create directory structure
2. Implement `Package.swift` with dependency on `swift-property-primitives`
3. Implement `Equation.swift` (namespace)
4. Implement `Equation.Protocol.swift` (protocol + default `!=`)
5. Implement `Equation.Protocol+Swift.Equatable.swift` (bridges)
6. Implement `exports.swift`
7. Test build

#### Phase 2: Update Hash Primitives

1. Add dependency on `swift-equation-primitives`
2. Update `Hash.Protocol` to refine `Equation.Protocol`
3. Remove redundant `==` requirement from `Hash.Protocol`
4. Update `exports.swift` to re-export `Equation_Primitives`
5. Test build

#### Phase 3: Consider Comparison Primitives (Future)

Defer decision on whether `Comparison.Protocol` should refine `Equation.Protocol`.

---

### 21. Consistency Analysis [RES-014]

#### 21.1 Cross-Package Naming Consistency

| Package | Namespace | Protocol | Matches Pattern |
|---------|-----------|----------|-----------------|
| swift-comparison-primitives | `Comparison` | `Comparison.Protocol` | ✓ |
| swift-hash-primitives | `Hash` | `Hash.Protocol` | ✓ |
| swift-equation-primitives | `Equation` | `Equation.Protocol` | ✓ |

#### 21.2 Cross-Language Design Consistency

| Aspect | Our Design | Swift stdlib | Rust | Haskell | Java |
|--------|------------|--------------|------|---------|------|
| Equality protocol | `Equation.Protocol` | `Equatable` | `PartialEq`/`Eq` | `Eq` | `equals()` |
| Hash refines equality | ✓ | ✓ | ✗ | N/A | ✓ (contract) |
| Comparison refines equality | Deferred | ✓ | ✓ | ✓ | ✗ |
| Default `!=` | ✓ | ✓ | ✓ | ✓ | N/A |
| `~Copyable` support | ✓ | ✗ | N/A | N/A | N/A |

---

### 22. Convention Compliance [RES-015]

| Convention | Requirement | Compliance |
|------------|-------------|------------|
| [API-NAME-001] | Nest.Name pattern | ✓ `Equation.Protocol` |
| [API-NAME-007b] | No stdlib shadows | ✓ `Equation` not `Equatable` |
| [API-IMPL-005] | One type per file | ✓ |
| [PRIM-FOUND-001] | No Foundation | ✓ |

---

### 23. Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Namespace name | `Equation` | Parallels `Comparison`, `Hash`; avoids shadow |
| Single vs split equality | Single | Follow Swift stdlib, not Rust |
| Protocol refinement | Hash refines Equation | Java contract, Swift stdlib pattern |
| `borrowing` parameters | Required | Enable `~Copyable` support |
| Default `!=` | Provided | Haskell/Rust pattern |

---

### 24. Open Questions

1. **Should `Comparison.Protocol` refine `Equation.Protocol`?**
   - Pro: Consistency with Swift stdlib `Comparable: Equatable`
   - Con: May require changes to existing Comparison conformers
   - Recommendation: Defer to separate analysis

2. **Should we add partial equality support in future?**
   - Pro: More precise modeling (Rust's PartialEq/Eq)
   - Con: Complexity; Swift stdlib doesn't distinguish
   - Recommendation: Monitor Swift Evolution; consider if stdlib adopts

---

## References

### Swift Institute Documentation
- [API-NAME-001] Namespace Structure
- [API-NAME-007b] Module-Scoped Name Resolution
- [API-IMPL-005] One Type Per File
- [PRIM-FOUND-001] No Foundation

### Swift Evolution
- [SE-0390: Noncopyable Structs and Enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0499: Support Non-Copyable Types in Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)

### Rust
- [PartialEq in std::cmp](https://doc.rust-lang.org/std/cmp/trait.PartialEq.html)
- [Eq in std::cmp](https://doc.rust-lang.org/std/cmp/trait.Eq.html)
- [Rust equality and ordering (2025)](https://0xpoe.dev/posts/2025-01-11-rust-std-cmp/)
- [Eq Traits in Rust (2025)](https://www.rustcodeweb.com/2025/02/eq-traits-in-rust.html)

### Haskell
- [Data.Eq - Hackage](https://hackage.haskell.org/package/base/docs/Data-Eq.html)
- [The Eq type class - UPenn](https://www.cis.upenn.edu/~cis1940/fall16/lectures/04-typeclasses.html)
- [Equality & Identity – Fixing Haskell](https://soc.me/languages/equality-and-identity-fixing-haskell.html)

### Scala
- [Eq - Typelevel Cats](https://typelevel.org/cats/typeclasses/eq.html)
- [Equivalence versus Equality - Typelevel](https://typelevel.org/blog/2017/04/02/equivalence-vs-equality.html)

### C++
- [C++20: The Three-Way Comparison Operator](https://www.modernescpp.com/index.php/c-20-the-three-way-comparison-operator/)
- [Comparisons in C++20 - Barry's Blog](https://brevzin.github.io/c++/2019/07/28/comparisons-cpp20/)
- [Simplify Your Code With Rocket Science - Microsoft](https://devblogs.microsoft.com/cppblog/simplify-your-code-with-rocket-science-c20s-spaceship-operator/)

### Kotlin
- [Equality | Kotlin Documentation](https://kotlinlang.org/docs/equality.html)
- [Effective Kotlin: Respect the contract of equals](https://kt.academy/article/ek-equals)

### Java
- [Java equals() and hashCode() Contracts | Baeldung](https://www.baeldung.com/java-equals-hashcode-contracts)

### OCaml
- [The perils of polymorphic compare - Jane Street](https://blog.janestreet.com/the-perils-of-polymorphic-compare/)
- [Structural Versus Physical Comparisons in OCaml](https://thealmarty.com/2018/10/09/structural-versus-physical-comparsions-in-ocaml/)

### Zig
- [Learning Zig - Language Overview](https://www.openmymind.net/learning_zig/language_overview_2/)

### Type Theory
- [Type theory - Wikipedia](https://en.wikipedia.org/wiki/Type_theory)
- [Substructural type system - Wikipedia](https://en.wikipedia.org/wiki/Substructural_type_system)
- [Linear types for programmers](https://twey.io/for-programmers/linear-types/)
- [Partial equivalence relation - Wikipedia](https://en.wikipedia.org/wiki/Partial_equivalence_relation)
- [CMU Lecture Notes on Linear Types](https://www.cs.cmu.edu/~fp/courses/15814-f20/lectures/23-linearity.pdf)

### IEEE 754
- [IEEE 754 - Wikipedia](https://en.wikipedia.org/wiki/IEEE_754)
- [NaN - Wikipedia](https://en.wikipedia.org/wiki/NaN)
