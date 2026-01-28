# Discrete Scaling Morphisms

<!--
---
version: 1.0.0
last_updated: 2026-01-27
status: IN_PROGRESS
tier: 3
applies_to: [swift-primitives, swift-affine-primitives, swift-index-primitives, swift-bit-primitives]
depends_on: [affine-scaling-operations.md, ordinal-cardinal-foundations.md]
---
-->

## Abstract

This document investigates the type-theoretic foundations for modeling cross-domain scaling factors in discrete index spaces. We distinguish between **geometric scaling** (endomorphism within a space) and **unit conversion** (morphism between spaces), and propose a design for the Swift Primitives ecosystem that maintains mathematical rigor while providing practical utility.

**Tier 3 Justification**: This decision establishes a long-lived semantic contract for how scaling and conversion are modeled across all index-based primitives. It is precedent-setting, foundational, and hard to undo.

---

## 1. Research Questions

**RQ1**: What is the mathematical distinction between geometric scaling and unit conversion, and how should this be reflected in the type system?

**RQ2**: How should cross-domain conversion factors (e.g., "8 bits per byte") be typed to ensure compile-time safety?

**RQ3**: What operations should a discrete scaling/conversion type support, and what is the algebraic structure?

**RQ4**: Where does this type belong in the Swift Primitives package hierarchy?

**RQ5**: What should the type be named to avoid confusion with existing concepts?

---

## 2. Systematic Literature Review

### 2.1 Search Strategy

**Databases**: arXiv, ACM Digital Library, Swift Evolution Forums, Hackage, crates.io, Microsoft Learn

**Keywords**: dimensional analysis, units of measure, type-safe scaling, affine types, category theory morphisms, unit conversion, phantom types

**Date range**: 2010-2026 (focus on modern type systems)

### 2.2 Inclusion/Exclusion Criteria

**Include**:
- Type systems for dimensional analysis
- Mathematical formalizations of dimensional analysis
- Category-theoretic treatments of scaling
- Practical implementations in strongly-typed languages

**Exclude**:
- Runtime-only unit checking
- Domain-specific implementations without generalizable theory
- Continuous-only frameworks (we need discrete support)

### 2.3 Data Extraction

#### 2.3.1 Mathematical Foundations

| Source | Key Contribution |
|--------|-----------------|
| Tao (2012) | Dimensional analysis via 1D vector spaces (relative) and affine spaces (absolute) |
| Zapata-Carratala (2021) | "Dimensioned algebra" extending algebraic structures for physical dimensions |
| Buckingham (1914) | π theorem: n variables with k dimensions reduce to n-k dimensionless parameters |

**Key Finding (Tao)**: A scaled quantity is a weight space for a representation of a scaling group. This formalizes the notion that "8 bits per byte" is a morphism between representation spaces.

#### 2.3.2 Type System Implementations

| System | Approach | Limitations |
|--------|----------|-------------|
| F# Units of Measure | Compile-time, type-level arithmetic, erased at runtime | Continuous only, no cross-domain |
| Haskell `dimensional` | Data kinds, closed type families, 7 SI base dimensions | SI-focused, continuous |
| Haskell `units` | Extensible embedded type system | Complex, heavyweight |
| Rust `uom` | Quantity-based (not unit-based), zero-cost | Continuous, no discrete support |
| C++ Boost.Units | Template metaprogramming | Compile-time intensive |

**Gap Identified**: All surveyed systems focus on continuous physical quantities. None provide first-class support for discrete scaling (bit-byte conversion) or cross-domain morphisms.

#### 2.3.3 Category-Theoretic Framework

| Concept | Definition | Application |
|---------|------------|-------------|
| Morphism | f: X → Y (source and target may differ) | Unit conversion between spaces |
| Endomorphism | f: X → X (source equals target) | Geometric scaling within a space |
| Automorphism | Invertible endomorphism | Bijective scaling |
| Natural transformation | Morphism of functors respecting structure | Scaling as functor transformation |

**Key Insight**: Geometric scaling is an endomorphism (same-space transformation). Unit conversion is a morphism between different spaces. These are categorically distinct.

### 2.4 Synthesis

1. **Dimensional analysis is algebraically rigorous**: It can be modeled as vector spaces of exponents over base quantities.

2. **The affine/linear distinction matters**: Absolute quantities (positions) live in affine spaces; relative quantities (displacements) live in vector spaces. Scaling semantics differ.

3. **Cross-domain conversion is a morphism, not a scaling**: "8 bits per byte" maps between Index<Byte> and Index<Bit>—different spaces. This is a morphism, not an endomorphism.

4. **Discrete dimensional analysis is underexplored**: No prior art specifically addresses type-safe discrete conversion factors.

5. **Naming matters**: Using "Scale" for both geometric scaling (Lie group) and unit conversion (morphism) creates confusion.

---

## 3. Theoretical Grounding

### 3.1 Affine Space Formalization

**Definition 3.1 (Discrete Affine Space)**: A discrete affine space (A, V, +) consists of:
- A set A of positions (points)
- An abelian group V of displacements (vectors)
- A free transitive action +: A × V → A

**Axioms**:
- A1 (Identity): ∀P ∈ A. P + 0 = P
- A2 (Associativity): ∀P ∈ A, v,w ∈ V. (P + v) + w = P + (v + w)
- A3 (Free): ∀P ∈ A, v ∈ V. P + v = P ⟹ v = 0
- A4 (Transitive): ∀P,Q ∈ A. ∃!v ∈ V. P + v = Q

**Definition 3.2 (Point Difference)**: Q - P := the unique v such that P + v = Q

### 3.2 Scaling Operations

**Definition 3.3 (Vector Scaling)**: For v ∈ V and scalar α ∈ ℤ:
```
α · v ∈ V
```
Vector scaling is a valid operation (V is a ℤ-module for discrete spaces).

**Theorem 3.4 (No Position Scaling)**: There is no well-defined operation α · P for position P ∈ A.

**Proof**: Affine spaces have no distinguished origin. Scalar multiplication requires linearity: α · (P₁ + P₂) = α · P₁ + α · P₂. But P₁ + P₂ is undefined for positions. ∎

**Corollary 3.5**: Any operation resembling α · P implicitly chooses an origin O, computing O + α · (P - O).

### 3.3 Cross-Domain Morphisms

**Definition 3.6 (Affine Morphism)**: An affine morphism f: (A₁, V₁) → (A₂, V₂) consists of:
- A map on positions: f_A: A₁ → A₂
- A linear map on vectors: f_V: V₁ → V₂
- Compatibility: f_A(P + v) = f_A(P) + f_V(v)

**Definition 3.7 (Scaling Morphism)**: A scaling morphism with factor k ∈ ℤ is an affine morphism where:
```
f_V(v) = k · v'  (where v' is the image of v under a unit identification)
```

**Example**: The byte-to-bit morphism has factor k = 8:
```
f: Index<Byte> → Index<Bit>
f_V: Offset<Byte> → Offset<Bit>
f_V(v) = 8 · v
```

### 3.4 Algebraic Structure

**Theorem 3.8 (Composition)**: Scaling morphisms compose by factor multiplication:
```
If f: A → B has factor k₁ and g: B → C has factor k₂,
then g ∘ f: A → C has factor k₁ · k₂.
```

**Proof**: (g ∘ f)_V(v) = g_V(f_V(v)) = g_V(k₁ · v') = k₂ · (k₁ · v'') = (k₁ · k₂) · v''. ∎

**Theorem 3.9 (Identity)**: The identity morphism id: A → A has factor 1.

**Theorem 3.10 (Partial Inverse)**: A scaling morphism with factor k has an inverse iff k divides evenly in the target domain.

---

## 4. Type-Theoretic Formalization

### 4.1 Typing Rules

**Judgment Forms**:
- Γ ⊢ e : τ (expression e has type τ in context Γ)
- τ ≤ σ (τ is a subtype of σ)

**Position and Vector Types**:
```
Γ ⊢ P : Index<T>           Position in domain T
Γ ⊢ v : Index<T>.Offset    Displacement in domain T
Γ ⊢ n : Index<T>.Count     Cardinality in domain T
```

**Scaling Morphism Type**:
```
Γ ⊢ s : Ratio<From, To>    Scaling morphism from From to To
```

### 4.2 Well-Typed Operations

**T-VecScale (Vector Scaling)**:
```
Γ ⊢ v : Index<From>.Offset    Γ ⊢ s : Ratio<From, To>
─────────────────────────────────────────────────────
Γ ⊢ v * s : Index<To>.Offset
```

**T-CountScale (Count Scaling)**:
```
Γ ⊢ n : Index<From>.Count    Γ ⊢ s : Ratio<From, To>
────────────────────────────────────────────────────
Γ ⊢ n * s : Index<To>.Count
```

**T-Compose (Morphism Composition)**:
```
Γ ⊢ s₁ : Ratio<A, B>    Γ ⊢ s₂ : Ratio<B, C>
─────────────────────────────────────────────
Γ ⊢ s₁ * s₂ : Ratio<A, C>
```

### 4.3 Ill-Typed Operations (Compile Errors)

**No Position Scaling**:
```
Γ ⊢ P : Index<From>    Γ ⊢ s : Ratio<From, To>
──────────────────────────────────────────────
Γ ⊢ P * s : ???  ✗ NOT DERIVABLE
```

**No Mismatched Scaling**:
```
Γ ⊢ v : Index<A>.Offset    Γ ⊢ s : Ratio<B, C>    A ≠ B
────────────────────────────────────────────────────────
Γ ⊢ v * s : ???  ✗ NOT DERIVABLE
```

### 4.4 Soundness

**Theorem 4.1 (Type Safety)**: If Γ ⊢ e : τ and e →* v, then Γ ⊢ v : τ.

**Theorem 4.2 (Dimensional Consistency)**: The type system prevents dimensionally inconsistent operations at compile time.

---

## 5. Design Options

### 5.1 Option A: Affine.Discrete.Ratio<From, To>

```swift
extension Affine.Discrete {
    public struct Ratio<From, To>: Hashable, Sendable {
        public let factor: Int

        @inlinable
        public init(_ factor: Int) {
            self.factor = factor
        }

        @inlinable
        public static var identity: Ratio<From, From> where From == To {
            Ratio<From, From>(1)
        }
    }
}
```

**Advantages**:
- Follows `Affine.Discrete.Vector` naming pattern
- "Ratio" clearly indicates relationship between domains
- Avoids confusion with dimension-primitives `Scale<N, Scalar>`

**Disadvantages**:
- "Ratio" may suggest division/quotient rather than morphism

### 5.2 Option B: Index.Morphism<From, To>

```swift
extension Index where Tag: ~Copyable {
    public struct Morphism<To>: Hashable, Sendable {
        public let factor: Int
        // ...
    }
}
```

**Advantages**:
- Category-theoretic precision
- Nested under Index, showing relationship

**Disadvantages**:
- Asymmetric (nested under source, not free-standing)
- "Morphism" may be unfamiliar to non-mathematicians

### 5.3 Option C: Conversion<From, To>

```swift
public struct Conversion<From, To>: Hashable, Sendable {
    public let factor: Int
    // ...
}
```

**Advantages**:
- Most explicit about purpose
- Familiar term
- Top-level, not nested

**Disadvantages**:
- Doesn't indicate discrete/affine context
- Very generic name

### 5.4 Option D: Affine.Discrete.Scale<From, To>

```swift
extension Affine.Discrete {
    public struct Scale<From, To>: Hashable, Sendable {
        public let factor: Int
        // ...
    }
}
```

**Advantages**:
- "Scale" is intuitive for multiplication factor
- Matches existing terminology in plan

**Disadvantages**:
- Conflicts conceptually with dimension-primitives `Scale<N, Scalar>`
- [MATH-005] defines Scale as Lie group element for geometric transformation

### 5.5 Comparison Matrix

| Criterion | Ratio | Morphism | Conversion | Scale |
|-----------|-------|----------|------------|-------|
| Mathematical precision | ✓ | ✓✓ | ✓ | ✗ |
| Avoids naming conflict | ✓✓ | ✓✓ | ✓✓ | ✗ |
| Follows existing patterns | ✓✓ | ✓ | ✗ | ✓ |
| Intuitive meaning | ✓ | ✗ | ✓✓ | ✓ |
| Discoverability | ✓ | ✓ | ✓ | ✓ |

---

## 6. Recommendation

### 6.1 Primary Choice: Affine.Discrete.Ratio<From, To>

**Rationale**:
1. **Mathematical alignment**: A ratio expresses the relationship between two quantities, exactly what we need
2. **Naming consistency**: Follows `Affine.Discrete.Vector` pattern
3. **Conflict avoidance**: Clearly distinct from dimension-primitives `Scale<N, Scalar>`
4. **Intuitive**: "8 bits per byte" is naturally expressed as a ratio

### 6.2 Type Definition

```swift
// In swift-affine-primitives/Sources/Affine Primitives/Affine.Discrete.Ratio.swift

extension Affine.Discrete {
    /// A conversion ratio between discrete index domains.
    ///
    /// `Ratio<From, To>` represents a multiplicative morphism that converts
    /// quantities (offsets, counts) from one domain to another. The factor
    /// is signed, allowing negative ratios (direction reversal).
    ///
    /// ## Mathematical Model
    ///
    /// A ratio is a morphism in the category of discrete affine spaces.
    /// It satisfies:
    /// - Identity: `Ratio<T, T>(1)` is the identity morphism
    /// - Composition: `Ratio<A,B> * Ratio<B,C> = Ratio<A,C>` with multiplied factors
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bitsPerByte = Ratio<UInt8, Bit>(8)
    /// let byteOffset: Index<UInt8>.Offset = ...
    /// let bitOffset = byteOffset * bitsPerByte  // Index<Bit>.Offset
    /// ```
    public struct Ratio<From, To>: Hashable, Sendable {
        /// The conversion factor (signed, allows direction reversal).
        public let factor: Int

        /// Creates a ratio with the given factor.
        @inlinable
        public init(_ factor: Int) {
            self.factor = factor
        }

        /// The identity ratio (factor = 1).
        @inlinable
        public static var identity: Ratio<From, From> where From == To {
            Ratio<From, From>(1)
        }
    }
}
```

### 6.3 Operations

```swift
// Composition
@inlinable
public func * <A, B, C>(
    lhs: Affine.Discrete.Ratio<A, B>,
    rhs: Affine.Discrete.Ratio<B, C>
) -> Affine.Discrete.Ratio<A, C> {
    Affine.Discrete.Ratio<A, C>(lhs.factor * rhs.factor)
}

// Offset scaling
@inlinable
public func * <From, To>(
    lhs: Index<From>.Offset,
    rhs: Affine.Discrete.Ratio<From, To>
) -> Index<To>.Offset {
    Index<To>.Offset(Affine.Discrete.Vector(lhs.rawValue.rawValue * rhs.factor))
}

// Count scaling
@inlinable
public func * <From, To>(
    lhs: Index<From>.Count,
    rhs: Affine.Discrete.Ratio<From, To>
) -> Index<To>.Count {
    let result = Int(bitPattern: lhs.rawValue.rawValue) * rhs.factor
    precondition(result >= 0, "Scaled count must be non-negative")
    return Index<To>.Count(Cardinal.Count(UInt(result)))
}
```

### 6.4 Domain-Specific Constants

```swift
// In swift-bit-primitives/Sources/Bit Primitives/Bit.Ratio.swift

extension Affine.Discrete.Ratio where From == UInt8, To == Bit {
    /// 8 bits per byte.
    @inlinable
    public static var bitsPerByte: Self { Self(8) }
}
```

---

## 7. Impact Analysis

### 7.1 Package Dependencies

```
Affine_Primitives (adds Ratio)
    ↓
Index_Primitives (uses Ratio in operators)
    ↓
Bit_Primitives (defines bitsPerByte constant)
```

No new cross-tier dependencies introduced.

### 7.2 Distinction from dimension-primitives Scale

| Aspect | dimension-primitives Scale | Affine.Discrete.Ratio |
|--------|---------------------------|----------------------|
| Purpose | Geometric transformation | Domain conversion |
| Type params | `<N: Int, Scalar>` | `<From, To>` |
| Scalar | FloatingPoint | Int |
| Operation | Endomorphism (A → A) | Morphism (A → B) |
| Category | Lie group (R+)^n | Affine morphisms |

These are complementary, not conflicting concepts.

---

## 8. Verification Plan

### 8.1 Type Safety Tests

```swift
// These should compile:
let bitsPerByte = Affine.Discrete.Ratio<UInt8, Bit>(8)
let byteOffset: Index<UInt8>.Offset = Index<UInt8>.Offset(Affine.Discrete.Vector(2))
let bitOffset = byteOffset * bitsPerByte  // Index<Bit>.Offset with value 16

// These should NOT compile:
// let invalid = byteIndex * bitsPerByte  // Position scaling - type error
// let mismatched = bitOffset * bitsPerByte  // Wrong source domain - type error
```

### 8.2 Mathematical Property Tests

```swift
// Identity
let id = Affine.Discrete.Ratio<Bit, Bit>.identity
XCTAssertEqual(offset * id, offset)

// Composition associativity
let r1 = Affine.Discrete.Ratio<A, B>(2)
let r2 = Affine.Discrete.Ratio<B, C>(3)
let r3 = Affine.Discrete.Ratio<C, D>(4)
XCTAssertEqual((r1 * r2) * r3, r1 * (r2 * r3))

// Factor multiplication
XCTAssertEqual((r1 * r2).factor, r1.factor * r2.factor)
```

---

## 9. Open Questions

1. **Division semantics**: Should `Offset<To> / Ratio<From, To>` return `Offset<From>?` (failing if not evenly divisible)?

2. **Rational factors**: Should we support non-integer ratios for edge cases? (Current design: No, integers only.)

3. **Compile-time constants**: Should common ratios like `bitsPerByte` be compile-time constants for optimization?

---

## 10. Outcome

**Status**: RECOMMENDATION

**Choice**: `Affine.Discrete.Ratio<From, To>`

**Rationale**:
1. Mathematically precise: correctly models cross-domain morphisms
2. Naming clarity: distinct from geometric `Scale<N, Scalar>`
3. Pattern consistency: follows `Affine.Discrete.Vector` pattern
4. Type safety: prevents invalid operations at compile time

**Next Steps**:
1. Review and approve naming choice
2. Implement in Affine_Primitives
3. Update Bit_Primitives to use Ratio
4. Add tests for type safety and mathematical properties

---

## References

### Academic

- Tao, T. (2012). "A mathematical formalisation of dimensional analysis." https://terrytao.wordpress.com/2012/12/29/a-mathematical-formalisation-of-dimensional-analysis/
- Zapata-Carratala, C. (2021). "Dimensioned Algebra: Mathematics with Physical Quantities." arXiv:2108.08703
- Buckingham, E. (1914). "On Physically Similar Systems." Physical Review, 4(4), 345-376.
- Kennedy, A. J. (1996). "Programming Languages and Dimensions." PhD thesis, University of Cambridge.

### Language Implementations

- F# Units of Measure. Microsoft Learn. https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/units-of-measure
- Haskell `dimensional` library. https://hackage.haskell.org/package/dimensional
- Rust `uom` crate. https://docs.rs/uom/latest/uom/

### Standards

- ISO 80000-1:2022. Quantities and units — Part 1: General.

### Internal

- Mathematical Foundations.md [MATH-005] — Lie groups for transformations
- affine-scaling-operations.md — Prior research on scaling semantics
- ordinal-cardinal-foundations.md — Ordinal/cardinal distinction

---

*Document version 1.0.0 — 2026-01-27 — Status: RECOMMENDATION*
