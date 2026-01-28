# Affine Space Scaling Operations

<!--
---
version: 1.0.0
last_updated: 2026-01-27
status: IN_PROGRESS
tier: 3
applies_to: [swift-primitives, swift-affine-primitives, swift-ordinal-primitives, swift-cardinal-primitives, swift-index-primitives, swift-bit-primitives]
depends_on: [ordinal-cardinal-foundations.md]
---
-->

## Abstract

This document investigates the mathematical foundations for scalar multiplication and scaling operations in the Swift Primitives ecosystem. We analyze whether positions (ordinals) can be scaled, whether vectors can be scaled, and how unit conversions (e.g., byte index to bit index) should be modeled. This is Tier 3 research establishing foundational semantic commitments for arithmetic operations across the primitives layer.

---

## 1. Context

### 1.1 Trigger

During implementation of byte-to-bit index conversion in `swift-bit-primitives`, the question arose: **How should the `* 8` scaling operation be expressed?**

```swift
// Current implementation
public init(_ byteIndex: Index<UInt8>) {
    self.init(__unchecked: (), Ordinal.Position(byteIndex.position.rawValue * 8))
}
```

The multiplication `* 8` operates on raw `UInt` values, sidestepping the type system. This raised questions:

1. Should `Ordinal.Position * UInt` (position scaling) exist as an operator?
2. Should `Cardinal.Count * UInt` exist? (It currently does in Index_Primitives)
3. Is scaling a position mathematically valid, or is it a category error?
4. How should unit conversions between index spaces be modeled?

### 1.2 Related Research

This document builds on [Ordinal and Cardinal Foundations](ordinal-cardinal-foundations.md), which establishes:

- **Ordinals** represent positions (which one?)
- **Cardinals** represent cardinalities (how many?)
- **Affine operations** are geometric operations on ordinals

The current document addresses a gap: **What operations involve scalars, and where do they belong?**

### 1.3 Scope and Precedent

This decision is **precedent-setting** and **hard to undo**:

- Affects what arithmetic operators exist on foundational types
- Establishes whether "scaling a position" is a valid concept
- Determines how unit conversions are expressed across the ecosystem
- Incorrect choices will propagate through all dependent packages

### 1.4 Tier Justification

| Criterion | Assessment |
|-----------|------------|
| Scope | Ecosystem-wide |
| Precedent-setting | Yes, hard to undo |
| Semantic commitment | Normative/foundational |
| Cost of error | Very high |
| Expected lifetime | "Timeless infrastructure" |

**Conclusion**: Tier 3 research is required.

---

## 2. Research Questions

**RQ1**: What is the mathematical definition of an affine space, and what operations does it support?

**RQ2**: Can points (positions) be scaled in affine geometry? Under what conditions?

**RQ3**: Can vectors (displacements) be scaled? Is this an affine or vector space operation?

byte) be modeled?

**RQ5**: What is the correct organization of scaling operations in Swift Primitives?

**RQ6**: Should the existing `Count * UInt` operator be removed, relocated, or retained?

---

## 3. Systematic Literature Review

### 3.1 Search Strategy

**Databases**:
- Mathematics: Linear algebra texts (Axler, Strang), differential geometry (do Carmo, Lee)
- Computer graphics: Foundations of 3D Computer Graphics (Gortler), Real-Time Rendering
- Type theory: Relevant papers on affine types, linear types
- Programming languages: CGAL documentation, Haskell geometric-algebra, Rust nalgebra

**Keywords**: affine space, affine transformation, vector space, scalar multiplication, homogeneous coordinates, barycentric coordinates, affine combination, unit conversion, dimensional analysis

**Date range**: Foundational texts (any date), PL implementations (2010-2026)

### 3.2 Inclusion/Exclusion Criteria

**Include**:
- Foundational linear algebra defining vector spaces
- Affine geometry texts distinguishing points from vectors
- Computer graphics texts on affine transformations
- Type systems encoding dimensional/unit safety

**Exclude**:
- Purely continuous/differential geometry (focus on discrete)
- Projective geometry beyond motivation for affine
- Implementation-only papers without semantic foundations

### 3.3 Data Extraction

#### 3.3.1 Vector Space Definition

| Source | Definition |
|--------|------------|
 V satisfying eight axioms |
| Strang (2016) | A vector space is closed under addition and scalar multiplication |

**Key operations in a vector space**:
 v'
 v' (where α ∈ F, v ∈ V)
 v'
- Zero vector: 0 ∈ V

#### 3.3.2 Affine Space Definition

| Source | Definition |
|--------|------------|
 A satisfying specific axioms |
| Gortler (2012) | "Points and vectors are different beasts... you can subtract two points to get a vector, add a vector to a point to get a point, but you cannot add two points" |
| Wikipedia | An affine space is a set A together with a vector space V and a transitive free action of V on A |

**Key insight**: An affine space has **no origin**. Points are not vectors. Scalar multiplication is defined on vectors, not points.

#### 3.3.3 Affine Space Operations

| Operation | Type Signature | Meaning |
|-----------|---------------|---------|
 V | Displacement vector between points |
 A | Translate point by vector |
 A | Translate point by negated vector |
 V | Vector addition |
 V | Vector subtraction |
 V | Scale a vector |
| Scalar × Point | — | **NOT DEFINED** in pure affine geometry |

**Critical finding**: **Scalar multiplication of points is not an affine operation.** There is no `α · P` for point P and scalar α in a pure affine space.

#### 3.3.4 Scaling Points Relative to an Origin

While `α · P` is undefined in pure affine geometry, **scaling relative to a chosen origin** is well-defined:

**Definition**: Given origin O and point P, scaling P by factor α relative to O is:
```
scale_O(P, α) = O + α · (P - O)
```

This decomposes into valid affine operations:
 v (point difference yields vector)
 v' (scalar multiplication of vector)
 P' (point translation)

**When O = 0** (origin is the zero position):
```
scale_0(P, α) = 0 + α · (P - 0) = α · P
```

This makes `α · P` look like scalar multiplication of a point, but it's actually vector scaling in disguise (treating the point's position as a displacement from origin).

#### 3.3.5 Homogeneous Coordinates

Computer graphics uses **homogeneous coordinates** to unify points and vectors:

| Entity | Homogeneous Representation | w-component |
|--------|---------------------------|-------------|
| Point (x, y, z) | (x, y, z, 1) | w = 1 |
| Vector (x, y, z) | (x, y, z, 0) | w = 0 |

Scalar multiplication in homogeneous coordinates:
- α · (x, y, z, 1) = (αx, αy, αz, α) — **not a valid point** (w ≠ 1)
- α · (x, y, z, 0) = (αx, αy, αz, 0) — valid vector

This confirms: scaling a point does not yield a point in homogeneous coordinates. Scaling a vector yields a vector.

#### 3.3.6 Dimensional Analysis and Unit Conversions

| Source | Approach |
|--------|----------|
| Kennedy (1996) | Types encode physical dimensions; multiplication has dimensional semantics |
| F# Units of Measure | `[<Measure>]` types prevent mixing incompatible units |
| Rust uom crate | Compile-time dimensional analysis |

**Dimensional analysis perspective**:
- "8 bits per byte" is a **conversion factor**, not scalar multiplication
- The operation is: `bit_position = byte_position × (8 bits/byte)`
- Dimensionally: `[bit] = [byte] × [bit/byte]`

This suggests unit conversions are **morphisms between spaces**, not scaling within a space.

### 3.4 Synthesis of Findings

1. **Vector spaces have scalar multiplication**; affine spaces do not have scalar multiplication of points
2. **Scaling a point requires a chosen origin**, making it a composite operation
3. **Homogeneous coordinates** distinguish points (w=1) from vectors (w=0); scaling a point breaks w=1
4. **Unit conversions are morphisms** between index spaces, not scaling within a space
5. **The existing `Count * UInt` is mathematically questionable** unless interpreted as vector scaling (count as displacement from zero)

---

## 4. Theoretical Grounding

### 4.1 Affine Space Axioms

An affine space (A, V, +) satisfies:

**A1 (Identity)**: ∀P ∈ A. P + 0 = P

**A2 (Associativity)**: ∀P ∈ A, v, w ∈ V. (P + v) + w = P + (v + w)

**A3 (Free action)**: ∀P ∈ A, v ∈ V. P + v = P ⟹ v = 0

**A4 (Transitivity)**: ∀P, Q ∈ A. ∃! v ∈ V. P + v = Q

From A4, we derive point subtraction: Q - P = v where P + v = Q.

### 4.2 Why Points Cannot Be Scaled

**Theorem 4.1**: In an affine space (A, V, +), there is no well-defined operation α · P for scalar α and point P.

**Proof sketch**:
1. Affine spaces have no distinguished origin
2. Scalar multiplication requires linearity: α · (P₁ + P₂) = α · P₁ + α · P₂
3. But P₁ + P₂ is not defined for points (not a valid operation)
4. Therefore, scalar multiplication of points cannot satisfy linearity
5. Therefore, scalar multiplication of points is not well-defined

**Corollary 4.2**: Any operation resembling `α · P` for point P implicitly chooses an origin, reducing P to a displacement vector from that origin.

### 4.3 Ordinal Positions as Affine Points

In the Swift Primitives model:
- `Ordinal.Position` represents points in a 1D discrete affine space
- `Affine.Discrete.Vector` (displacement) represents vectors in the associated vector space
- The origin is implicit: position 0

**Observation**: Because we have an implicit origin at 0, every position can be viewed as a displacement from 0. This is why `position.rawValue * 8` "works"—we're treating the position as if it were a displacement.

**But this conflates points and vectors**, which is exactly what affine geometry distinguishes.

### 4.4 Cardinal Counts as Magnitudes

Cardinals represent "how many", which is a **magnitude** concept.

**Definition 4.3 (Magnitude)**: A magnitude is a non-negative real number representing size, amount, or extent.

Magnitudes can be scaled: "twice as many" is well-defined.
- 2 × 5 elements = 10 elements ✓

**Observation**: `Count * UInt` is mathematically valid if we interpret Count as a magnitude (cardinal), not as a position (ordinal).

### 4.5 Type-Theoretic Formalization

#### 4.5.1 Affine Operations (Valid)

```
Γ ⊢ P : Point    Γ ⊢ v : Vector
─────────────────────────────────── (T-Translate)
Γ ⊢ P + v : Point

Γ ⊢ P : Point    Γ ⊢ Q : Point
─────────────────────────────────── (T-Displacement)
Γ ⊢ Q - P : Vector

Γ ⊢ v : Vector    Γ ⊢ w : Vector
─────────────────────────────────── (T-VecAdd)
Γ ⊢ v + w : Vector

Γ ⊢ α : Scalar    Γ ⊢ v : Vector
─────────────────────────────────── (T-VecScale)
Γ ⊢ α · v : Vector
```

#### 4.5.2 Invalid Operations (Not Derivable)

```
Γ ⊢ α : Scalar    Γ ⊢ P : Point
─────────────────────────────────── (T-PointScale)  ✗ NOT VALID
Γ ⊢ α · P : ???

Γ ⊢ P : Point    Γ ⊢ Q : Point
─────────────────────────────────── (T-PointAdd)  ✗ NOT VALID
Γ ⊢ P + Q : ???
```

#### 4.5.3 Unit Conversion as Morphism

```
Γ ⊢ P : Index<Byte>
─────────────────────────────────── (T-ByteToBit)
Γ ⊢ bitIndex(P) : Index<Bit>
```

This is a **function** (morphism) between index types, not scalar multiplication.

### 4.6 Category-Theoretic Perspective

**Definition 4.4 (Category of Affine Spaces)**:
- Objects: Affine spaces
- Morphisms: Affine maps (preserve affine combinations)

 B satisfies:
```
f(α₁P₁ + α₂P₂ + ... + αₙPₙ) = α₁f(P₁) + α₂f(P₂) + ... + αₙf(Pₙ)
```
where Σαᵢ = 1 (affine combination).

**Unit conversions as affine maps**:
 Index<Bit>` maps byte position P to bit position 8P
- This is an affine map (specifically, a scaling map relative to origin 0)

**Key insight**: Unit conversions are **morphisms**, not operations within a single space.

---

## 5. Analysis of Options

### 5.1 Option A: Allow Position Scaling (α · P)

**Structure**:
```swift
// In swift-ordinal-primitives or swift-affine-primitives
public func * (lhs: UInt, rhs: Ordinal.Position) -> Ordinal.Position
public func * (lhs: Ordinal.Position, rhs: UInt) -> Ordinal.Position
```

**Advantages**:
- Convenient for unit conversions
- Matches common programming idioms

**Disadvantages**:
- **Mathematically incorrect**: Points cannot be scaled in affine geometry
- **Conflates points and vectors**: Treats positions as displacements
- **Precedent risk**: Opens door to other invalid operations
- **Loss of type safety**: Allows meaningless operations

**Assessment**: Mathematically unsound. Convenience over correctness.

### 5.2 Option B: Vector Scaling Only (α · v)

**Structure**:
```swift
// In swift-affine-primitives
public func * (lhs: Int, rhs: Affine.Discrete.Vector) -> Affine.Discrete.Vector
public func * (lhs: Affine.Discrete.Vector, rhs: Int) -> Affine.Discrete.Vector
```

Unit conversions via decomposition:
```swift
extension Index<Bit> {
    init(_ byteIndex: Index<UInt8>) {
 Vector
        let scaledDisplacement = displacement * 8      // Vector scaling
 Point
    }
}
```

**Advantages**:
- **Mathematically correct**: Only vectors are scaled
- **Explicit**: Decomposition shows the conceptual steps
- **Type-safe**: Cannot accidentally scale a point

**Disadvantages**:
- More verbose for simple unit conversions
- Requires understanding affine/vector distinction

**Assessment**: Mathematically sound. Correctness over convenience.

### 5.3 Option C: Unit Conversion as Typed Morphism

**Structure**:
```swift
// Explicit morphism functions
extension Index<Bit> {
 Index<Bit>
    init(_ byteIndex: Index<UInt8>) {
        // Internal implementation may use raw arithmetic
        self.init(__unchecked: (), Ordinal.Position(byteIndex.position.rawValue * 8))
    }
}
```

The `* 8` happens at the raw value level, inside the typed boundary. The type system enforces that only valid conversions are expressed.

**Advantages**:
- **Type-safe at API boundary**: Can only convert Index<Byte> to Index<Bit>, not arbitrary scaling
- **Efficient**: No decomposition overhead
- **Expresses intent**: init clearly shows this is a conversion morphism
- **No new operators**: No `Position * Scalar` or `Count * Scalar` operators needed

**Disadvantages**:
- Internal implementation "cheats" by using raw arithmetic
- Doesn't enforce mathematical purity internally

**Assessment**: Pragmatic correctness. Type boundary enforces safety while allowing efficient implementation.

### 5.4 Option D: Cardinal Scaling with Justification

**Structure**:
```swift
// In swift-cardinal-primitives
// Cardinal represents magnitude, magnitudes can be scaled
public func * (lhs: Cardinal.Count, rhs: UInt) -> Cardinal.Count
public func * (lhs: UInt, rhs: Cardinal.Count) -> Cardinal.Count
```

**Justification**: Cardinals represent magnitudes ("how many"). Scaling a magnitude is mathematically valid: "twice as many" is well-defined.

**Advantages**:
- Mathematically justifiable (magnitudes, not positions)
- Useful for capacity calculations

**Disadvantages**:
- **Risk of misuse**: Users might use Count where Position is appropriate
- **Semantic drift**: Count becomes "number that can be scaled"

**Assessment**: Conditionally acceptable if Count is strictly cardinal (magnitude) and never used as ordinal (position).

### 5.5 Comparison Matrix

| Criterion | Option A (Position Scale) | Option B (Vector Only) | Option C (Typed Morphism) | Option D (Cardinal Scale) |
|-----------|--------------------------|------------------------|--------------------------|--------------------------|
| Mathematical correctness | ✗ | ✓✓ | ✓ | ✓ |
| Type safety | ✗ | ✓✓ | ✓✓ | ✓ |
| Convenience | ✓✓ | ✗ | ✓ | ✓ |
| Implementation efficiency | ✓✓ | ✗ | ✓✓ | ✓✓ |
| Semantic clarity | ✗ | ✓✓ | ✓ | ✓ |
| Precedent safety | ✗ | ✓✓ | ✓✓ | ✓ |

---

## 6. Recommendation

### 6.1 Primary Recommendation: Option C (Typed Morphism) + Option B (Vector Scaling)

**Recommended approach**:

1. **NO scalar multiplication of positions** (`Position * Scalar` does not exist)
2. **Vector scaling is valid** (`Vector * Scalar` exists in Affine_Primitives)
3. **Unit conversions are typed morphisms** (init-based, type-enforced)
4. **Cardinal scaling is conditionally acceptable** (only if Count is strictly magnitude)

### 6.2 Implementation for Bit Primitives

```swift
extension Index<Bit> {
    /// Creates a bit index from a byte index.
    ///
    /// This is a morphism from the byte index space to the bit index space.
 Bit 8n.
    ///
    /// - Parameter byteIndex: The byte index to convert.
    /// - Precondition: Byte position must not overflow when converted to bits.
    @inlinable
    public init(_ byteIndex: Index<UInt8>) {
        let (bitPosition, overflow) = byteIndex.position.rawValue.multipliedReportingOverflow(by: 8)
        precondition(!overflow, "byte index overflows when converted to bit index")
        self.init(__unchecked: (), Ordinal.Position(bitPosition))
    }
}
```

**Key points**:
- The init is the typed morphism
- Raw arithmetic happens inside the typed boundary
- No `Position * UInt` operator is exposed
- The type system prevents arbitrary scaling

### 6.3 What to Do with Existing Count * UInt

The existing `Count * UInt` in Index_Primitives should be **evaluated against cardinal semantics**:

- If `Index<T>.Count` is strictly a **magnitude** (cardinal), scaling is acceptable
- If `Index<T>.Count` is ever used as a **position** (ordinal), scaling should be removed

**Recommendation**: Keep `Count * UInt` but document it as magnitude scaling, not position scaling. Ensure Count is never used where Index (position) is appropriate.

### 6.4 Add Vector Scaling to Affine_Primitives

```swift
// swift-affine-primitives/Sources/Affine Primitives/Affine.Discrete+Arithmetic.swift

/// Scales a vector by a scalar.
@inlinable
public func * (lhs: Int, rhs: Affine.Discrete.Vector) -> Affine.Discrete.Vector {
    Affine.Discrete.Vector(lhs * rhs.rawValue)
}

/// Scales a vector by a scalar (commutative).
@inlinable
public func * (lhs: Affine.Discrete.Vector, rhs: Int) -> Affine.Discrete.Vector {
    Affine.Discrete.Vector(lhs.rawValue * rhs)
}
```

This provides a mathematically valid scaling operation for users who need it.

---

## 7. Impact on Package Organization

### 7.1 Operator Inventory

| Package | Operation | Status |
|---------|-----------|--------|
| swift-ordinal-primitives | `Position * Scalar` | **NOT ADDED** (mathematically invalid) |
| swift-cardinal-primitives | `Cardinal * Scalar` | **ACCEPTABLE** (magnitude scaling) |
| swift-affine-primitives | `Vector * Scalar` | **ADD** (vector space operation) |
| swift-index-primitives | `Index<T> * Scalar` | **NOT ADDED** (Index is position) |
| swift-index-primitives | `Count * Scalar` | **KEEP** (Count is magnitude) |

### 7.2 Dependency on Ordinal/Cardinal Research

This research builds on [ordinal-cardinal-foundations.md]:

- If Option B (Full Separation) is adopted there, `Ordinal.Position` explicitly cannot be scaled
- `Cardinal.Count` can be scaled as a magnitude
- Affine operations (including vector scaling) belong in `swift-affine-primitives`

---

## 8. Open Questions

1. **Index.Offset scaling**: Should `Offset * Scalar` exist? (Offset is a displacement/vector)
2. **Negative scaling**: Should `Vector * Int` allow negative scalars (direction reversal)?
3. **Fractional scaling**: Do we ever need `Vector * Rational`? (Not for discrete spaces)

---

## 9. Outcome

### 9.1 Status

**Status**: RECOMMENDATION

### 9.2 Summary

1. **Position scaling is invalid** in affine geometry—do not add `Position * Scalar`
2. **Vector scaling is valid**—add `Vector * Scalar` to Affine_Primitives
3. **Unit conversions are morphisms**—express via typed init, not generic scaling
4. **Cardinal scaling is acceptable**—Count represents magnitude, not position
5. **Existing `Count * UInt` can remain** if Count is strictly cardinal

### 9.3 Rationale

Mathematical purity ensures:
- Type safety communicates valid operations
- Invalid operations are impossible, not just discouraged
- Future extensions won't introduce semantic drift

bit conversion is properly modeled as a typed morphism (init), not scalar multiplication.

---

## 10. References

### 10.1 Linear Algebra and Affine Geometry

- Axler, S. (2015). *Linear Algebra Done Right* (3rd ed.). Springer.
- Strang, G. (2016). *Introduction to Linear Algebra* (5th ed.). Wellesley-Cambridge.
- Gallier, J. (2011). *Geometric Methods and Applications*. Springer.

### 10.2 Computer Graphics

- Gortler, S. J. (2012). *Foundations of 3D Computer Graphics*. MIT Press.
- Akenine-Möller, T., Haines, E., & Hoffman, N. (2018). *Real-Time Rendering* (4th ed.). CRC Press.

### 10.3 Dimensional Analysis

- Kennedy, A. J. (1996). "Programming Languages and Dimensions." PhD thesis, University of Cambridge.
- F# Units of Measure. https://docs.microsoft.com/en-us/dotnet/fsharp/language-reference/units-of-measure

### 10.4 Type Theory

- Pierce, B. C. (2002). *Types and Programming Languages*. MIT Press.

---

## Appendix A: Affine Combination Clarification

An **affine combination** of points P₁, ..., Pₙ with weights α₁, ..., αₙ where Σαᵢ = 1 is:
```
α₁P₁ + α₂P₂ + ... + αₙPₙ
```

This is well-defined in affine geometry because the constraint Σαᵢ = 1 ensures the result is origin-independent.

**Special cases**:
- Midpoint: (P + Q) / 2 with weights (0.5, 0.5)
- Barycentric coordinates in triangles

**Note**: This is NOT scalar multiplication. The constraint Σαᵢ = 1 is essential.

---

## Appendix B: Homogeneous Coordinates Detail

In homogeneous coordinates (3D):

| Operation | Input | Output | Valid? |
|-----------|-------|--------|--------|
| Point + Vector | (p, 1) + (v, 0) | (p+v, 1) | ✓ Point |
| Point - Point | (p, 1) - (q, 1) | (p-q, 0) | ✓ Vector |
| Vector + Vector | (v, 0) + (w, 0) | (v+w, 0) | ✓ Vector |
| α × Vector | α(v, 0) | (αv, 0) | ✓ Vector |
| α × Point | α(p, 1) | (αp, α) | ✗ Not a point (w ≠ 1) |
| Point + Point | (p, 1) + (q, 1) | (p+q, 2) | ✗ Not a point (w ≠ 1) |

The w-component tracks validity: points have w=1, vectors have w=0.

---

*Document version 1.0.0 — 2026-01-27 — Status: IN_PROGRESS*

