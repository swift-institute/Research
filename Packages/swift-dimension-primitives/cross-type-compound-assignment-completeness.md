# Cross-Type Compound Assignment Completeness

<!--
---
version: 1.0.0
last_updated: 2026-02-28
status: RECOMMENDATION
tier: 2
---
-->

## Context

During the kernel-primitives modularization audit, investigation of `Kernel.File.Size.swift` revealed hand-rolled `+=` and `-=` operators for `Kernel.File.Offset ±= Kernel.File.Size`. These exist because Dimension Primitives provides the binary `Coordinate + Magnitude → Coordinate` operators but does NOT provide corresponding compound assignment operators for any cross-type pair.

Timeline that led to this gap:
1. **Dimension Primitives** (older): Original affine geometry system with phantom-typed coordinates, displacements, extents, and magnitudes
2. **Ordinal/Cardinal/Affine Primitives** (newer): Discrete affine system for in-memory indexing, designed with principled compound assignment from the start
3. **Dimension refactored**: Integrated with the newer type system (depends on `swift-finite-primitives`), but compound assignment operators were not revisited during the refactor

The newer packages establish a precedent that Dimension does not follow. This research investigates whether Dimension's omission of cross-type compound assignment is a principled design choice or an accidental gap from the refactoring timeline.

**Trigger**: [RES-001] — Design question arose during kernel-primitives implementation; cannot be resolved without systematic analysis.

**Scope**: [RES-002a] — Affects dimension-primitives and all consumers (kernel, geometry). Primitives-wide.

## Question

Should Dimension Primitives provide cross-type compound assignment operators (`+=`, `-=`) for `Coordinate ± Displacement`, `Coordinate ± Magnitude`, and `Coordinate ± Extent`? If so, which pairs, and with what attributes?

## Analysis

### Current State: Dimension Primitives Operator Inventory

Dimension Primitives (`Tagged+Arithmatic.swift`) contains 12 compound assignment operators, **all same-type**:

| Operator | LHS | RHS | Lines |
|----------|-----|-----|-------|
| `+=` | `Magnitude<Space>.Value<Scalar>` | Same | 218-224 |
| `-=` | `Magnitude<Space>.Value<Scalar>` | Same | 227-233 |
| `+=` | `Extent.X<Space>.Value<Scalar>` | Same | 292-298 |
| `-=` | `Extent.X<Space>.Value<Scalar>` | Same | 301-307 |
| `+=` | `Extent.Y<Space>.Value<Scalar>` | Same | 310-316 |
| `-=` | `Extent.Y<Space>.Value<Scalar>` | Same | 319-325 |
| `+=` | `Extent.Z<Space>.Value<Scalar>` | Same | 328-334 |
| `-=` | `Extent.Z<Space>.Value<Scalar>` | Same | 337-343 |

**Missing** — no compound assignment for any cross-type pair:
- `Coordinate.{X,Y,Z} ±= Displacement.{X,Y,Z}` (0 of 6)
- `Coordinate.{X,Y,Z} ±= Magnitude` (0 of 6)
- `Coordinate.{X,Y,Z} ±= Extent.{X,Y,Z}` (0 of 6)

Meanwhile, corresponding binary operators (`+`, `-`) exist for all 18 cross-type pairs (plus quantized `BinaryFloatingPoint` overloads and commutative variants), totaling ~72 cross-type binary operators.

**No Displacement same-type compound assignment** exists either — `Displacement += Displacement` is also missing, despite `Displacement + Displacement → Displacement` binary operators existing (lines 144-194).

### Current State: Ordinal/Cardinal/Affine Compound Assignment

The newer packages, designed after Dimension, provide cross-type compound assignment:

| Operator | LHS | RHS | Package | Attributes |
|----------|-----|-----|---------|------------|
| `+=` | `Ordinal.Protocol` | `Cardinal.Protocol` | ordinal-primitives | `@_disfavoredOverload` |
| `+=` | `Ordinal.Protocol` | `Vector.Protocol` | affine-primitives | typed throws |
| `-=` | `Ordinal.Protocol` | `Vector.Protocol` | affine-primitives | typed throws |
| `-=` | `Tagged<T, Ordinal>` | `Tagged<T, Vector>` | affine-primitives | typed throws |

Pattern: **every cross-type binary operator has a corresponding compound assignment**. The Ordinal/Cardinal/Affine system treats this as axiomatic.

### Current State: Downstream Hand-Rolled Operators

Only one downstream package hand-rolls cross-type compound assignment:

| Package | File | Operators | Types |
|---------|------|-----------|-------|
| kernel-primitives | `Kernel.File.Size.swift` | `+=`, `-=` | `Offset ±= Size` (`Coordinate.X ±= Magnitude`) |

No other consumer of Dimension Primitives has been forced to hand-roll operators. However, this may indicate that kernel-primitives is the only consumer that mutates coordinates in place (geometry code tends to produce new values).

### Theoretical Analysis

#### Affine Space Axioms

An affine space is a triple (A, V, +) where:
- A is a set of points
- V is a vector space (the "translation group")
- `+: A × V → A` is a free and transitive group action

The action `+: A × V → A` is one of the **defining operations** of an affine space. It is axiomatic, not derived. The equivalent torsor formulation (nLab, Weyl) defines:
- `vadd: A × V → A` (translate point by vector)
- `vsub: A × A → V` (displacement between points)

Lean's mathlib formalizes this as `add_torsor` with roundtrip axioms `vsub_vadd` and `vadd_vsub`.

#### Compound Assignment is Closure

The group action `A × V → A` has the **closure property**: the result lives in the same set (A) as the first operand. Any closed binary operation admits in-place mutation:

| Operation | Closure | Compound Assignment | Mathematical Status |
|-----------|---------|--------------------|--------------------|
| `Vector + Vector → Vector` | V × V → V | `Vector += Vector` | Vector space axiom |
| `Point + Vector → Point` | A × V → A | `Point += Vector` | Affine space axiom |
| `Point - Point → Vector` | A × A → V | N/A (changes type) | Torsor subtraction |
| `Point + Point → ???` | Undefined | Prohibited | Not an operation |
| `Point × Scalar → ???` | Undefined | Prohibited | Not an operation |

The mathematical conclusion: **if the binary operation is principled, its compound assignment form is equally principled**. The distinction is purely representational (in-place vs. new-value), not semantic.

#### Classification of Cross-Type Pairs in Dimension

| Pair | Binary Form | Mathematical Status | Compound Assignment Status |
|------|------------|--------------------|--------------------|
| `Coordinate ± Displacement` | Axiomatic affine action | **Axiomatic** | Should exist |
| `Coordinate ± Extent` | Axis-aligned displacement (Extent.X carries axis info) | **Canonical embedding** | Should exist |
| `Coordinate ± Magnitude` | Non-directional magnitude interpreted along coordinate axis | **Interpretation** (axis from Coordinate, distance from Magnitude) | Conditional |

All three are unambiguous in Dimension because of per-axis typing:
- `Coordinate.X += Displacement.X` — both carry X axis, unambiguous
- `Coordinate.X += Extent.X` — both carry X axis, unambiguous
- `Coordinate.X += Magnitude` — axis from `Coordinate.X`, distance from non-directional `Magnitude`

The `Magnitude` case is the least principled because `Magnitude` is non-directional by definition. However, Dimension already accepts this interpretation in the binary operators (lines 1001-1003):
> "Magnitude (non-directional distance) can be added/subtracted from coordinates. This enables `center.x - radius` patterns in geometry code. The magnitude is interpreted as distance along the axis of the coordinate."

If the interpretation is accepted for binary `+`, it is equally valid for compound `+=`.

### Prior Art Survey

Every major typed affine geometry library in imperative languages provides `Point += Vector`:

| Library | Language | `Point + Vector` | `Point += Vector` | `Point + Magnitude-like` | `Point += Magnitude-like` |
|---------|----------|:-:|:-:|:-:|:-:|
| euclid (Servo) | Rust | Yes | **Yes** | Yes (`+ Size2D`) | **Yes** (`+= Size2D`) |
| nalgebra | Rust | Yes | **Yes** | No | No |
| CGAL | C++ | Yes | **Yes** | No | No |
| linear | Haskell | Yes (`.+^`) | N/A (pure) | No | N/A |
| vector-space | Haskell | Yes (`.+^`) | N/A (pure) | No | N/A |

Haskell libraries omit compound assignment because the language has no mutable variables — not by design choice.

`Point += Magnitude-like` is less common — only euclid provides it (as `Point2D += Size2D`). However, euclid's `Size2D` is axis-aware (width/height), closer to Dimension's `Extent` than `Magnitude`.

### Option A: Add All Cross-Type Compound Assignments

Add `+=` and `-=` for all three cross-type pairs × 3 axes = 18 operators. Also add the missing `Displacement +=/-= Displacement` same-type operators (6 operators). Total: 24 new operators.

**Advantages**:
- Complete: every binary operator has a compound assignment counterpart
- Consistent with Ordinal/Cardinal/Affine precedent
- Eliminates need for downstream hand-rolling
- Follows the closure principle universally

**Disadvantages**:
- 24 additional operators in an already large file (1843 lines)
- `Coordinate ±= Magnitude` compounds make the "interpretation" (direction from axis) more convenient to use, potentially discouraging the more principled `Coordinate ±= Displacement`
- No quantized overloads needed (compound assignment delegates to binary which handles quantization), but adds API surface

**Attributes**: `Coordinate ±= Displacement` without `@_disfavoredOverload` (axiomatic). `Coordinate ±= Magnitude` and `Coordinate ±= Extent` with `@_disfavoredOverload` (mirrors binary operator pattern).

### Option B: Add Only Coordinate ±= Displacement

Add `+=` and `-=` for `Coordinate ± Displacement` only (6 operators). Also add `Displacement ±= Displacement` (6 operators). Total: 12 new operators.

**Advantages**:
- Strictly principled: only the axiomatic affine operation gets compound assignment
- Clear signal that `Displacement` is the canonical translation type
- `Coordinate ±= Magnitude` and `Coordinate ±= Extent` remain binary-only, encouraging users to be explicit about the interpretation

**Disadvantages**:
- Inconsistent: binary operators exist for Magnitude/Extent, but compound assignments don't
- Does not eliminate kernel's hand-rolled `Offset ±= Size` operators (these use Magnitude)
- Creates an asymmetry that needs documentation/justification

### Option C: Keep Current State (No Cross-Type Compound Assignment)

Leave Dimension as-is. Downstream packages hand-roll what they need.

**Advantages**:
- No changes to a stable package
- Each consumer decides what's appropriate for its domain

**Disadvantages**:
- Inconsistent with Ordinal/Cardinal/Affine precedent established during refactoring
- Forces downstream hand-rolling of trivial `lhs = lhs + rhs` wrappers
- The "design choice" rationale doesn't hold — the existing comments explain why `AdditiveArithmetic` conformance and blanket scaling are omitted, but never explain why compound assignment is omitted for cross-type operations

### Option D: Add Coordinate ±= Displacement and Coordinate ±= Extent (Not Magnitude)

Add `+=` and `-=` for `Coordinate ± Displacement` (6 operators) and `Coordinate ± Extent` (6 operators, with `@_disfavoredOverload`). Also add `Displacement ±= Displacement` (6 operators). Total: 18 new operators.

**Advantages**:
- Displacement: axiomatic, no `@_disfavoredOverload`
- Extent: axis-aware (canonical embedding), with `@_disfavoredOverload`
- Magnitude excluded: non-directional, requires interpretation — stays binary-only
- Clean principled distinction: compound assignment only for types that carry direction

**Disadvantages**:
- Still doesn't help kernel's `Offset ±= Size` case (Magnitude-based)
- Magnitude exclusion is debatable: Dimension already accepts the interpretation in binary operators

### Comparison

| Criterion | A: All | B: Displacement only | C: No change | D: Displacement + Extent |
|-----------|:---:|:---:|:---:|:---:|
| Mathematically principled | **Yes** (closure) | **Yes** (axiomatic only) | N/A | **Yes** (directional types) |
| Consistent with binary ops | **Yes** (1:1) | No (partial) | No (0:72) | Partial (2 of 3 pairs) |
| Consistent with Ord/Card/Affine | **Yes** | Partial | No | Partial |
| Eliminates downstream hand-rolling | **Yes** | No (kernel still needs Magnitude) | No | No (kernel still needs Magnitude) |
| Avoids encouraging less-principled path | No | **Yes** | **Yes** | Partial |
| Operator count increase | +24 | +12 | 0 | +18 |
| Displacement ±= Displacement gap fixed | **Yes** | **Yes** | No | **Yes** |

### The Displacement Same-Type Gap

Independently of the cross-type question, `Displacement ±= Displacement` is missing despite:
- `Displacement + Displacement → Displacement` existing (lines 144-194)
- `Magnitude ±= Magnitude` existing (lines 218-233)
- `Extent ±= Extent` existing (lines 292-343)

This is clearly an oversight, not a design choice. Vector addition is closed on V — compound assignment is trivially principled. All options except C should fix this.

## Outcome

**Status**: RECOMMENDATION

### Recommended: Option A — Add all cross-type compound assignments

The mathematical analysis is unambiguous: **if a binary operation `A × B → A` is principled, its compound assignment form `a ←= b` is equally principled**. The distinction is representational, not semantic.

The strongest arguments for Option A:

1. **Closure principle**: Compound assignment is syntactic sugar for `lhs = lhs op rhs`. If the binary form is accepted (which it is — Dimension provides 72+ cross-type binary operators), the compound form is identically sound.

2. **Consistency with Ordinal/Cardinal/Affine**: The newer, more principled packages provide cross-type compound assignment as standard. Dimension should follow the precedent it helped establish.

3. **Prior art unanimity**: Every imperative typed geometry library provides `Point += Vector`. The mathematical and engineering communities agree this is standard.

4. **Eliminates downstream hand-rolling**: Kernel-primitives (and any future consumer) shouldn't need to define trivial `lhs = lhs + rhs` wrappers.

5. **`@_disfavoredOverload` preserves hierarchy**: The existing binary operator pattern (Displacement is preferred, Magnitude/Extent are disfavored) carries over to compound assignment. Users are guided toward `Coordinate += Displacement` but not blocked from `Coordinate += Magnitude` when it's the natural expression.

### Implementation Specification

#### New operators to add (24 total):

**Displacement same-type compound assignment** (6 operators, no `@_disfavoredOverload`):
```swift
Displacement.X +=/-= Displacement.X
Displacement.Y +=/-= Displacement.Y
Displacement.Z +=/-= Displacement.Z
```

**Coordinate ±= Displacement** (6 operators, no `@_disfavoredOverload`):
```swift
Coordinate.X +=/-= Displacement.X
Coordinate.Y +=/-= Displacement.Y
Coordinate.Z +=/-= Displacement.Z
```

**Coordinate ±= Magnitude** (6 operators, with `@_disfavoredOverload`):
```swift
Coordinate.X +=/-= Magnitude
Coordinate.Y +=/-= Magnitude
Coordinate.Z +=/-= Magnitude
```

**Coordinate ±= Extent** (6 operators, with `@_disfavoredOverload`):
```swift
Coordinate.X +=/-= Extent.X
Coordinate.Y +=/-= Extent.Y
Coordinate.Z +=/-= Extent.Z
```

#### Operator pattern:

All compound assignments delegate to their binary operator (which handles quantization):
```swift
@inlinable
public func += <Space, Scalar: AdditiveArithmetic>(
    lhs: inout Coordinate.X<Space>.Value<Scalar>,
    rhs: Displacement.X<Space>.Value<Scalar>
) {
    lhs = lhs + rhs
}
```

No `BinaryFloatingPoint` overload needed — the binary `+` already selects the quantized version when applicable.

No `@_disfavoredOverload` on Displacement compound assignments — Displacement is the canonical translation type.

`@_disfavoredOverload` on Magnitude and Extent compound assignments — mirrors binary operator pattern.

#### After implementation:

Remove kernel-primitives' hand-rolled `Offset +=/-= Size` operators from `Kernel.File.Size.swift`, letting Dimension's generic versions handle them (same as was done for the binary `+` and `-` operators).

### Scope escalation

This research connects to the in-progress `affine-operator-unification-completeness.md` in swift-institute, which investigates whether remaining `Tagged+Affine.swift` operators should be unified via Domain + companion types. The compound assignment completeness question is orthogonal but related — both concern operator inventory gaps from the refactoring timeline.

## References

### Mathematical Foundations
- nLab: [Affine Space](https://ncatlab.org/nlab/show/affine+space)
- nLab: [Torsor](https://ncatlab.org/nlab/show/torsor)
- ProofWiki: [Affine Space](https://proofwiki.org/wiki/Definition:Affine_Space)
- Lean mathlib: [`add_torsor`](https://cs.brown.edu/courses/cs1951x/docs/algebra/add_torsor.html)

### Prior Art
- Rust euclid: [`Point2D` + `AddAssign<Vector2D>`](https://docs.rs/euclid/latest/euclid/struct.Point2D.html), [`AddAssign<Size2D>`](https://github.com/servo/euclid/blob/master/src/point.rs)
- Rust nalgebra: [`Point` + `AddAssign<Vector>`](https://docs.rs/nalgebra/0.13.0/nalgebra/geometry/struct.Point.html)
- C++ CGAL: [`Point_2::operator+=(Vector_2)`](https://doc.cgal.org/latest/Kernel_23/classCGAL_1_1Point__2.html)
- Haskell linear: [`Linear.Affine` (`.+^`, `.-.`)](https://hackage-content.haskell.org/package/linear-1.23.2/docs/Linear-Affine.html)
- Haskell vector-space: [`Data.AffineSpace`](https://hackage.haskell.org/package/vector-space-0.12/docs/Data-AffineSpace.html)
- Swift SE-0233: [AdditiveArithmetic](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0233-additive-arithmetic-protocol.md)

### Internal
- Dimension Primitives: `/Users/coen/Developer/swift-primitives/swift-dimension-primitives/`
- Kernel-primitives hand-rolled operators: `Sources/Kernel Primitives Core/Kernel.File.Size.swift`
- Affine operator unification research: `/Users/coen/Developer/swift-institute/Research/affine-operator-unification-completeness.md`
- Ordinal compound assignment: `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift:119`
- Affine compound assignment: `swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift:112-123`
