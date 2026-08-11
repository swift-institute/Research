# Affine-Index Architectural Reorganization

<!--
---
title: Affine-Index Architectural Reorganization
version: 1.0.0
last_updated: 2026-01-20
applies_to: [swift-primitives]
normative: true
---
-->

A comprehensive analysis of the dependency architecture for affine, index, identity, and related primitives packages, with a proposal for reorganization following Swift Institute norms.

---

## Abstract

This document presents a complete architectural analysis of the affine-index-identity package constellation within swift-primitives. The current architecture suffers from a cyclic dependency between `Index`, `Affine`, `Linear`, and `Vector` packages. Through systematic application of Swift Institute naming conventions [API-NAME-001], the relocation principle [PRIM-ORG-001], and semantic organization guidelines [PRIM-ORG-005], we derive a reorganization that eliminates the cycle while preserving mathematical precision and maximizing code reuse.

The key insight is that the current `swift-affine-primitives` conflates two distinct semantic domains: **1D discrete affine space** (positions, displacements, bounds) and **N-dimensional continuous affine geometry** (points, vectors, transforms). By factoring these into separate namespaces within a restructured package hierarchy, we achieve clean dependency flow and enable `Index` to reuse affine arithmetic without inheriting geometric complexity.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Current Architecture Analysis](#current-architecture-analysis)
3. [Semantic Domain Analysis](#semantic-domain-analysis)
4. [Mathematical Foundations](#mathematical-foundations)
5. [Naming Analysis](#naming-analysis)
6. [Proposed Architecture](#proposed-architecture)
7. [Package Specifications](#package-specifications)
8. [Migration Path](#migration-path)
9. [Verification Criteria](#verification-criteria)

---

## 1. Problem Statement

### 1.1 The Cyclic Dependency

The current architecture exhibits the following dependency cycle:

```
swift-index-primitives
         ↓ (wants to use)
swift-affine-primitives
         ↓ (depends on)
swift-algebra-linear-primitives
         ↓ (depends on)
swift-vector-primitives
         ↓ (depends on)
swift-index-primitives
```

This cycle prevents `Index` from importing `Affine` to reuse affine arithmetic operators.

### 1.2 The Underlying Cause

The cycle exists because:

1. **`Affine.Point<N>`** uses **`Linear.Vector<N>`** as its displacement type
2. **`Vector<Element, N>`** uses **`Index`** for element access
3. **`Index`** wants affine arithmetic but cannot import `Affine`

### 1.3 Constraints

Per user directive, the following constraints apply:

1. **Protocols are forbidden** — No `AffinePosition`, `AffineDisplacement` protocols
2. **`swift-affine-primitives` must be reusable by `swift-index-primitives`**
3. **All Swift Institute norms apply**, particularly:
   - [API-NAME-001] Nest.Name pattern
   - [PRIM-ARCH-001] Nine-tier dependency structure
   - [PRIM-ORG-001] Relocation principle
   - [PRIM-NAME-003] Names describe mechanism, not origin
   - [PRIM-ORG-005] Factor the law, not the module

---

## 2. Current Architecture Analysis

### 2.1 Package Inventory

| Package | Tier | Dependencies | Main Types |
|---------|------|--------------|------------|
| `swift-tagged-primitives` | 0 | None | `Tagged<Tag, RawValue>` |
| `swift-ordinal-primitives` | 0 | None | `Ordinal`, `Ordinal.Offset` |
| `swift-finite-primitives` | 1 | ordinal | `Finite.Ordinal`, `Finite.Bounded` |
| `swift-dimension-primitives` | 4 | identity, numeric, formatting, algebra, finite | `Coordinate.*`, `Displacement.*`, `Extent.*` |
| `swift-algebra-linear-primitives` | 5 | algebra, dimension, formatting, numeric, vector | `Linear.Vector<N>`, `Linear.Matrix<R,C>` |
| `swift-affine-primitives` | 5 | linear, formatting, numeric | `Affine.Point<N>`, `Affine.Transform` |
| `swift-geometry-primitives` | 6 | algebra, linear, affine, dimension, region, symmetry | `Geometry.Point<N>`, shapes |
| `swift-vector-primitives` | 3* | index, bit | `Vector<Element, N>` |
| `swift-index-primitives` | 1 | ordinal, identity | `Index<Element>`, `Index.Offset`, `Index.Bounded<N>` |

*Note: `swift-vector-primitives` is listed at Tier 3 but creates the cycle by depending on `swift-index-primitives`.

### 2.2 Type Analysis

#### `swift-tagged-primitives`

```swift
public struct Tagged<Tag: ~Copyable, RawValue> {
    @usableFromInline internal var _storage: RawValue
}
```

A phantom-type wrapper providing zero-cost type safety. No arithmetic, no bounds, no affine semantics.

#### `swift-ordinal-primitives`

```swift
public struct Ordinal: Hashable, Comparable, Sendable {
    public let rawValue: Int  // non-negative
}

extension Ordinal {
    public struct Offset: Hashable, Comparable, Sendable {
        public let rawValue: Int  // signed
    }
}
```

A non-negative position with signed offset. Implements affine arithmetic (point + vector → point, point - point → vector).

#### `swift-finite-primitives`

```swift
extension Finite {
    public struct Bounded<let N: Int>: Hashable, Comparable, Sendable {
        public let rawValue: Int  // in [0, N)
    }
}
```

A compile-time bounded ordinal. Also implements affine arithmetic with bounds checking.

#### `swift-index-primitives`

```swift
public typealias Index<Element: ~Copyable> = Tagged<Element, Int>

extension Tagged where Tag: ~Copyable, RawValue == Int {
    public struct Offset: Hashable, Comparable, Sendable {
        public let rawValue: Int
    }

    public struct Bounded<let N: Int>: Hashable, Comparable, Sendable {
        public let rawValue: Int
    }
}
```

A phantom-typed index that **re-implements** the same arithmetic as `Ordinal` and `Finite.Bounded`.

#### `swift-affine-primitives`

```swift
public struct Affine<Scalar: Numeric, Space> {}

extension Affine {
    public struct Point<let N: Int>: Hashable, Sendable {
        public var storage: Linear<Scalar, Space>.Vector<N>
    }
}
```

An N-dimensional point using `Linear.Vector<N>` as storage and displacement type.

### 2.3 Duplication Analysis

The following arithmetic patterns are implemented redundantly:

| Pattern | Ordinal | Finite.Bounded | Index | Index.Bounded | Affine.Point |
|---------|---------|----------------|-------|---------------|--------------|
| Position + Displacement → Position | ✓ | ✓ (optional) | ✓ | ✓ (optional) | ✓ |
| Position - Displacement → Position | ✓ | ✓ (optional) | ✓ | ✓ (optional) | ✓ |
| Position - Position → Displacement | ✓ | ✓ | ✓ | ✓ | ✓ |
| Displacement + Displacement → Displacement | ✓ | N/A | ✓ | N/A | ✓ |
| -Displacement → Displacement | ✓ | N/A | ✓ | N/A | ✓ |

This is the **affine space pattern** repeated five times with minor variations.

---

## 3. Semantic Domain Analysis

### 3.1 Domain Identification

Applying [PRIM-ORG-001] (relocation principle), we ask: **what IS each concept?**

| Concept | What It IS | Current Home | Semantic Home |
|---------|------------|--------------|---------------|
| `Ordinal` | 1D discrete position | ordinal-primitives | affine-primitives |
| `Ordinal.Offset` | 1D discrete displacement | ordinal-primitives | affine-primitives |
| `Finite.Bounded` | Bounded 1D discrete position | finite-primitives | affine-primitives |
| `Index<E>` | Tagged 1D discrete position | index-primitives | index-primitives (uses affine) |
| `Index.Offset` | Duplicate of Ordinal.Offset | index-primitives | should reuse affine |
| `Index.Bounded<N>` | Tagged bounded 1D position | index-primitives | index-primitives (uses affine) |
| `Affine.Point<N>` | N-dimensional continuous position | affine-primitives | affine-primitives |
| `Linear.Vector<N>` | N-dimensional continuous displacement | linear-primitives | linear-primitives |

### 3.2 The Two Affine Domains

The affine space concept has two distinct instantiations in this codebase:

#### Domain A: 1D Discrete Affine Space

- **Position type**: Non-negative integer (0, 1, 2, ...)
- **Displacement type**: Signed integer (..., -2, -1, 0, 1, 2, ...)
- **Arithmetic**: Exact, no floating-point
- **Bounds**: Optional compile-time bounds `[0, N)`
- **Use cases**: Array indices, ordinal positions, cursor positions

#### Domain B: N-Dimensional Continuous Affine Space

- **Position type**: N-tuple of scalars (floats, doubles)
- **Displacement type**: N-dimensional vector
- **Arithmetic**: Floating-point with tolerance
- **Bounds**: None at the type level
- **Use cases**: Graphics, geometry, physics

### 3.3 The Conflation Problem

The current `swift-affine-primitives` only implements Domain B. Domain A is scattered across `ordinal-primitives`, `finite-primitives`, and `index-primitives` with redundant implementations.

Per [PRIM-NAME-003], names should describe mechanism, not origin. The names `Ordinal`, `Finite.Bounded`, and `Index.Offset` describe **where they were needed**, not **what they are**. What they ARE is:

- `Ordinal` = 1D discrete affine position
- `Ordinal.Offset` = 1D discrete affine displacement
- `Finite.Bounded<N>` = Bounded 1D discrete affine position

---

## 4. Mathematical Foundations

### 4.1 Affine Space Definition

An **affine space** over a vector space V is a set A together with a free and transitive group action of V on A. The key operations are:

1. **Point + Vector → Point** (translation)
2. **Point - Vector → Point** (translation)
3. **Point - Point → Vector** (displacement)

Note that **Point + Point is undefined** — this is the distinguishing feature of affine spaces versus vector spaces.

### 4.2 1D Discrete Affine Space

When V = ℤ (integers as a 1D vector space over itself), the affine space is:

- **Points**: Non-negative integers ℤ≥0 (positions)
- **Vectors**: All integers ℤ (displacements)
- **Operations**: Standard integer arithmetic with non-negativity constraint on results

### 4.3 Bounded Affine Space

A **bounded** affine space restricts positions to `[0, N)`:

- **Points**: Integers in `{0, 1, ..., N-1}`
- **Vectors**: All integers ℤ
- **Operations**: Same as unbounded, but translations may fail (return nil/throw)

### 4.4 N-Dimensional Continuous Affine Space

The current `Affine.Point<N>` implements:

- **Points**: N-tuples of scalars
- **Vectors**: `Linear.Vector<N>`
- **Operations**: Component-wise arithmetic

---

## 5. Naming Analysis

### 5.1 Applying [API-NAME-001] Nest.Name Pattern

The Nest.Name pattern requires:

> All types MUST use the `Nest.Name` pattern where **Nest** is the larger domain and **Name** is the specific concept.

For affine space:

```
Affine                          // Domain: affine space concepts
├── Affine.Discrete             // Subdomain: 1D discrete affine space
│   ├── Affine.Discrete.Position
│   ├── Affine.Discrete.Displacement
│   └── Affine.Discrete.Bounded<N>
└── Affine.Continuous           // Subdomain: N-dimensional continuous
    ├── Affine.Continuous.Point<N>
    ├── Affine.Continuous.Transform
    └── (uses Linear.Vector<N> for displacement)
```

### 5.2 Applying [API-NAME-009] Names as Constraints

> A well-chosen name MUST prevent future drift by making inappropriate additions feel obviously wrong.

| Name | Constraint | Test |
|------|------------|------|
| `Affine.Discrete` | 1D discrete affine operations only | "Add N-dimensional point?" → Obviously wrong |
| `Affine.Discrete.Position` | Non-negative integer position | "Add floating point?" → Obviously wrong |
| `Affine.Discrete.Bounded<N>` | Position in `[0, N)` | "Add unbounded?" → That's `Position` |
| `Affine.Continuous` | N-dimensional continuous geometry | "Add integer-only?" → That's `Discrete` |

### 5.3 Candidate Names Rejected

| Candidate | Problem |
|-----------|---------|
| `Ordinal` | Describes use case (ordering), not mechanism (affine position) |
| `Index.Offset` | Duplicates `Affine.Discrete.Displacement` under a context-specific name |
| `Finite.Bounded` | Describes constraint (finite), not domain (affine) |
| `Position1D` | Compound name violates [API-NAME-002] |
| `IntegerPosition` | Compound name violates [API-NAME-002] |

---

## 6. Proposed Architecture

### 6.1 Package Restructuring

```
TIER 0 (Atomic - No Dependencies)
├── swift-tagged-primitives
│   └── Tagged<Tag, RawValue>
│
└── swift-affine-primitives  ← RESTRUCTURED
    ├── Affine                       // Namespace
    ├── Affine.Discrete              // 1D discrete subdomain
    │   ├── Affine.Discrete.Position
    │   ├── Affine.Discrete.Displacement
    │   └── Affine.Discrete.Bounded<N>
    └── Affine.Discrete+Arithmetic   // All affine operators

TIER 1 (Foundation Layer)
├── swift-index-primitives  ← SIMPLIFIED
│   ├── Index<Element> = Tagged<Element, Affine.Discrete.Position>
│   ├── Index.Offset = Affine.Discrete.Displacement  // or Tagged wrapper
│   └── Index.Bounded<N>  // wraps Affine.Discrete.Bounded
│
├── swift-ordinal-primitives  ← DEPRECATED/ALIAS
│   └── Ordinal = Affine.Discrete.Position  // typealias for migration
│
└── swift-finite-primitives  ← DEPENDS ON AFFINE
    ├── Finite.Enumerable (protocol)
    ├── Finite.Enumeration
    └── Finite.Ordinal<N> = Affine.Discrete.Bounded<N>  // typealias

TIER 5 (Linear Algebra)
├── swift-algebra-linear-primitives
│   ├── Linear.Vector<N>
│   └── Linear.Matrix<R, C>
│
└── swift-affine-geometry-primitives  ← NEW PACKAGE
    ├── Affine.Continuous             // N-dimensional subdomain
    │   ├── Affine.Continuous.Point<N>
    │   └── Affine.Continuous.Transform
    └── depends on: linear-primitives

TIER 6 (Geometry)
└── swift-geometry-primitives
    └── depends on: affine-geometry-primitives (NOT affine-primitives)
```

### 6.2 Dependency Graph (No Cycles)

```
                    identity-primitives (Tier 0)
                              ↑
                    affine-primitives (Tier 0)
                         ↑         ↑
            index-primitives    finite-primitives (Tier 1)
                    ↑
           vector-primitives (Tier 3)
                    ↑
           linear-primitives (Tier 5)
                    ↑
        affine-geometry-primitives (Tier 5)
                    ↑
          geometry-primitives (Tier 6)
```

### 6.3 Key Design Decisions

#### Decision 1: Split `swift-affine-primitives`

The current package conflates discrete and continuous domains. Split into:

- `swift-affine-primitives` (Tier 0) — 1D discrete only, no dependencies
- `swift-affine-geometry-primitives` (Tier 5) — N-dimensional continuous, depends on linear

#### Decision 2: `Affine.Discrete.Position` replaces `Ordinal`

Per [PRIM-ORG-001], the type's semantic home is `Affine.Discrete`, not `Ordinal`. The name `Ordinal` describes the use case (ordering); `Affine.Discrete.Position` describes the mechanism.

#### Decision 3: `Index` composes, doesn't duplicate

`Index<Element>` becomes `Tagged<Element, Affine.Discrete.Position>`. All arithmetic is inherited from `Affine.Discrete`, not re-implemented.

#### Decision 4: No protocols

Per user constraint, we use concrete types and typealiases, not protocols. This means:

- `Index` wraps or aliases `Affine.Discrete.Position`
- Arithmetic operators are defined on concrete types
- Reuse comes from composition, not conformance

---

## 7. Package Specifications

### 7.1 `swift-affine-primitives` (Restructured)

**Tier**: 0 (Atomic)
**Dependencies**: None

**File Structure**:
```
Sources/Affine Primitives/
├── Affine.swift
├── Affine.Discrete.swift
├── Affine.Discrete.Position.swift
├── Affine.Discrete.Displacement.swift
├── Affine.Discrete.Bounded.swift
├── Affine.Discrete+Arithmetic.swift
└── exports.swift
```

**Type Definitions**:

```swift
// Affine.swift
public enum Affine {}

// Affine.Discrete.swift
extension Affine {
    public enum Discrete {}
}

// Affine.Discrete.Position.swift
extension Affine.Discrete {
    public struct Position: Hashable, Comparable, Sendable {
        public let rawValue: Int

        public init?(_ value: Int) {
            guard value >= 0 else { return nil }
            self.rawValue = value
        }

        public init(__unchecked value: Int) {
            self.rawValue = value
        }
    }
}

// Affine.Discrete.Displacement.swift
extension Affine.Discrete {
    public struct Displacement: Hashable, Comparable, Sendable,
                                 ExpressibleByIntegerLiteral {
        public let rawValue: Int

        public init(_ value: Int) {
            self.rawValue = value
        }

        public init(integerLiteral value: Int) {
            self.rawValue = value
        }
    }
}

// Affine.Discrete.Bounded.swift
extension Affine.Discrete {
    public struct Bounded<let N: Int>: Hashable, Comparable, Sendable {
        public let rawValue: Int

        public static var count: Cardinal { N }

        public init?(_ value: Int) {
            guard value >= 0, value < N else { return nil }
            self.rawValue = value
        }

        public init(__unchecked marker: Void = (), _ value: Int) {
            self.rawValue = value
        }
    }
}

// Affine.Discrete+Arithmetic.swift

// Position + Displacement → Position?
@inlinable
public func + (
    lhs: Affine.Discrete.Position,
    rhs: Affine.Discrete.Displacement
) -> Affine.Discrete.Position? {
    Affine.Discrete.Position(lhs.rawValue + rhs.rawValue)
}

// Position - Displacement → Position?
@inlinable
public func - (
    lhs: Affine.Discrete.Position,
    rhs: Affine.Discrete.Displacement
) -> Affine.Discrete.Position? {
    Affine.Discrete.Position(lhs.rawValue - rhs.rawValue)
}

// Position - Position → Displacement
@inlinable
public func - (
    lhs: Affine.Discrete.Position,
    rhs: Affine.Discrete.Position
) -> Affine.Discrete.Displacement {
    Affine.Discrete.Displacement(lhs.rawValue - rhs.rawValue)
}

// Displacement ± Displacement → Displacement
@inlinable
public func + (
    lhs: Affine.Discrete.Displacement,
    rhs: Affine.Discrete.Displacement
) -> Affine.Discrete.Displacement {
    Affine.Discrete.Displacement(lhs.rawValue + rhs.rawValue)
}

@inlinable
public func - (
    lhs: Affine.Discrete.Displacement,
    rhs: Affine.Discrete.Displacement
) -> Affine.Discrete.Displacement {
    Affine.Discrete.Displacement(lhs.rawValue - rhs.rawValue)
}

// -Displacement → Displacement
@inlinable
public prefix func - (
    displacement: Affine.Discrete.Displacement
) -> Affine.Discrete.Displacement {
    Affine.Discrete.Displacement(-displacement.rawValue)
}

// Bounded<N> + Displacement → Bounded<N>?
@inlinable
public func + <let N: Int>(
    lhs: Affine.Discrete.Bounded<N>,
    rhs: Affine.Discrete.Displacement
) -> Affine.Discrete.Bounded<N>? {
    Affine.Discrete.Bounded<N>(lhs.rawValue + rhs.rawValue)
}

// Bounded<N> - Displacement → Bounded<N>?
@inlinable
public func - <let N: Int>(
    lhs: Affine.Discrete.Bounded<N>,
    rhs: Affine.Discrete.Displacement
) -> Affine.Discrete.Bounded<N>? {
    Affine.Discrete.Bounded<N>(lhs.rawValue - rhs.rawValue)
}

// Bounded<N> - Bounded<N> → Displacement
@inlinable
public func - <let N: Int>(
    lhs: Affine.Discrete.Bounded<N>,
    rhs: Affine.Discrete.Bounded<N>
) -> Affine.Discrete.Displacement {
    Affine.Discrete.Displacement(lhs.rawValue - rhs.rawValue)
}
```

### 7.2 `swift-index-primitives` (Simplified)

**Tier**: 1
**Dependencies**: `swift-tagged-primitives`, `swift-affine-primitives`

**File Structure**:
```
Sources/Index Primitives/
├── Index.swift
├── Index.Bounded.swift
├── Index.Safe.swift
└── exports.swift
```

**Type Definitions**:

```swift
// Index.swift
import Tagged_Primitives
import Affine_Primitives

/// A phantom-typed index for type-safe collection access.
///
/// `Index<Element>` wraps `Affine.Discrete.Position` with a phantom type
/// parameter that prevents indices from different collections being confused.
public struct Index<Element: ~Copyable>: Hashable, Comparable, Sendable {
    public let position: Affine.Discrete.Position

    @inlinable
    public init(position: Int) throws(Index.Error) {
        guard let pos = Affine.Discrete.Position(position) else {
            throw .negativePosition(position)
        }
        self.position = pos
    }

    @inlinable
    public init(__unchecked position: Int) {
        self.position = Affine.Discrete.Position(__unchecked: position)
    }

    @inlinable
    public init(_ position: Affine.Discrete.Position) {
        self.position = position
    }

    public enum Error: Swift.Error, Hashable, Sendable {
        case negativePosition(Int)
    }
}

/// The displacement between two indices.
///
/// Typealiased to `Affine.Discrete.Displacement` — no duplication.
extension Index where Element: ~Copyable {
    public typealias Offset = Affine.Discrete.Displacement
}

// Arithmetic: Index inherits from Affine.Discrete

@inlinable
public func + <Element: ~Copyable>(
    lhs: Index<Element>,
    rhs: Index<Element>.Offset
) -> Index<Element>? {
    (lhs.position + rhs).map(Index.init)
}

@inlinable
public func - <Element: ~Copyable>(
    lhs: Index<Element>,
    rhs: Index<Element>.Offset
) -> Index<Element>? {
    (lhs.position - rhs).map(Index.init)
}

@inlinable
public func - <Element: ~Copyable>(
    lhs: Index<Element>,
    rhs: Index<Element>
) -> Index<Element>.Offset {
    lhs.position - rhs.position
}


// Index.Bounded.swift

extension Index where Element: ~Copyable {
    /// A bounded index constrained to `[0, N)`.
    public struct Bounded<let N: Int>: Hashable, Comparable, Sendable {
        public let position: Affine.Discrete.Bounded<N>

        @inlinable
        public init?(_ value: Int) {
            guard let pos = Affine.Discrete.Bounded<N>(value) else {
                return nil
            }
            self.position = pos
        }

        @inlinable
        public init(__unchecked marker: Void = (), _ value: Int) {
            self.position = Affine.Discrete.Bounded<N>(__unchecked: (), value)
        }

        @inlinable
        public init(_ bounded: Affine.Discrete.Bounded<N>) {
            self.position = bounded
        }

        public static var count: Cardinal { N }
    }
}

// Bounded arithmetic delegates to Affine.Discrete.Bounded

@inlinable
public func + <Element: ~Copyable, let N: Int>(
    lhs: Index<Element>.Bounded<N>,
    rhs: Index<Element>.Offset
) -> Index<Element>.Bounded<N>? {
    (lhs.position + rhs).map(Index.Bounded.init)
}

@inlinable
public func - <Element: ~Copyable, let N: Int>(
    lhs: Index<Element>.Bounded<N>,
    rhs: Index<Element>.Offset
) -> Index<Element>.Bounded<N>? {
    (lhs.position - rhs).map(Index.Bounded.init)
}

@inlinable
public func - <Element: ~Copyable, let N: Int>(
    lhs: Index<Element>.Bounded<N>,
    rhs: Index<Element>.Bounded<N>
) -> Index<Element>.Offset {
    lhs.position - rhs.position
}
```

### 7.3 `swift-affine-geometry-primitives` (New Package)

**Tier**: 5
**Dependencies**: `swift-algebra-linear-primitives`, `swift-formatting-primitives`, `swift-numeric-primitives`

**File Structure**:
```
Sources/Affine Geometry Primitives/
├── Affine.Continuous.swift
├── Affine.Continuous.Point.swift
├── Affine.Continuous.Transform.swift
├── Affine.Continuous+Arithmetic.swift
└── exports.swift
```

This package contains all the current `swift-affine-primitives` content that depends on `Linear.Vector<N>`:

```swift
// Affine.Continuous.swift
import Algebra_Linear_Primitives

extension Affine {
    public enum Continuous {}
}

// Affine.Continuous.Point.swift
extension Affine.Continuous {
    public struct Point<let N: Int>: Hashable, Sendable
    where Scalar: Numeric {
        public var storage: Linear<Scalar, Space>.Vector<N>
        // ... current Affine.Point implementation
    }
}
```

### 7.4 `swift-ordinal-primitives` (Migration Typealiases)

**Tier**: 1
**Dependencies**: `swift-affine-primitives`

```swift
// Ordinal.swift - DEPRECATED
import Affine_Primitives

@available(*, deprecated, renamed: "Affine.Discrete.Position")
public typealias Ordinal = Affine.Discrete.Position

extension Ordinal {
    @available(*, deprecated, renamed: "Affine.Discrete.Displacement")
    public typealias Offset = Affine.Discrete.Displacement
}
```

### 7.5 `swift-finite-primitives` (Updated)

**Tier**: 1
**Dependencies**: `swift-affine-primitives`

```swift
// Finite.Ordinal.swift
import Affine_Primitives

extension Finite {
    /// A finite ordinal with exactly N inhabitants.
    public typealias Ordinal<let N: Int> = Affine.Discrete.Bounded<N>
}

extension Finite {
    /// Deprecated alias for migration.
    @available(*, deprecated, renamed: "Affine.Discrete.Bounded")
    public typealias Bounded<let N: Int> = Affine.Discrete.Bounded<N>
}
```

### 7.6 `swift-vector-primitives` (Updated)

**Tier**: 3
**Dependencies**: `swift-affine-primitives`, `swift-bit-primitives`

```swift
// Vector.Index.swift - REMOVED
// Vector now uses Affine.Discrete.Bounded directly

public struct Vector<Element, let N: Int> {
    public typealias Index = Affine.Discrete.Bounded<N>

    public subscript(index: Index) -> Element {
        get { storage[index.rawValue] }
        set { storage[index.rawValue] = newValue }
    }
}
```

---

## 8. Migration Path

### Phase 1: Create `swift-affine-primitives` (Discrete)

1. Remove all dependencies from `swift-affine-primitives`
2. Remove `Affine.Point`, `Affine.Transform`, etc. (move to new package)
3. Add `Affine.Discrete.Position`, `Affine.Discrete.Displacement`, `Affine.Discrete.Bounded<N>`
4. Add arithmetic operators
5. Verify: `swift build` with zero dependencies

### Phase 2: Create `swift-affine-geometry-primitives`

1. Create new package at Tier 5
2. Move `Affine.Point<N>`, `Affine.Transform`, etc. from old affine-primitives
3. Rename to `Affine.Continuous.Point<N>`, etc.
4. Add dependency on `swift-algebra-linear-primitives`
5. Verify: `swift build` succeeds

### Phase 3: Update `swift-index-primitives`

1. Add dependency on `swift-affine-primitives`
2. Change `Index<Element>` to wrap `Affine.Discrete.Position`
3. Change `Index.Offset` to typealias `Affine.Discrete.Displacement`
4. Change `Index.Bounded<N>` to wrap `Affine.Discrete.Bounded<N>`
5. Simplify arithmetic operators to delegate
6. Verify: all tests pass

### Phase 4: Update `swift-vector-primitives`

1. Change dependency from `swift-index-primitives` to `swift-affine-primitives`
2. Use `Affine.Discrete.Bounded<N>` for `Vector.Index`
3. Verify: cycle eliminated, build succeeds

### Phase 5: Update `swift-finite-primitives`

1. Add dependency on `swift-affine-primitives`
2. Change `Finite.Bounded<N>` to typealias `Affine.Discrete.Bounded<N>`
3. Verify: tests pass

### Phase 6: Deprecate `swift-ordinal-primitives`

1. Add dependency on `swift-affine-primitives`
2. Add deprecation typealiases
3. Plan removal in future major version

### Phase 7: Update `swift-geometry-primitives`

1. Change dependency from `swift-affine-primitives` to `swift-affine-geometry-primitives`
2. Update imports
3. Verify: build succeeds

---

## 9. Verification Criteria

### 9.1 Structural Verification

| Criterion | Verification |
|-----------|--------------|
| No cyclic dependencies | `swift package dump-package` shows DAG |
| `swift-affine-primitives` at Tier 0 | Zero dependencies in Package.swift |
| `swift-index-primitives` at Tier 1 | Depends only on Tier 0 packages |
| All arithmetic in one place | Grep for `func +` shows only affine-primitives |

### 9.2 Semantic Verification

| Criterion | Verification |
|-----------|--------------|
| Nest.Name pattern | All types follow `Domain.Concept` naming |
| No compound names | No `OrdinalOffset`, `IndexBounded`, etc. |
| Names constrain scope | Ask "does X belong in Y?" — name answers clearly |

### 9.3 Functional Verification

| Test | Expected Result |
|------|-----------------|
| `Index<A>` + `Index<A>.Offset` | Returns `Index<A>?` |
| `Index<A>` - `Index<B>` | Compile error (different types) |
| `Affine.Discrete.Bounded<5>(5)` | Returns `nil` |
| `Affine.Discrete.Position(-1)` | Returns `nil` |
| All existing tests | Pass unchanged |

---

## 10. Conclusion

This reorganization achieves:

1. **Cycle elimination** — `Index` can now import `Affine` without creating a cycle
2. **Code reuse** — Affine arithmetic implemented once, used by all position types
3. **Semantic clarity** — Types named for what they ARE, not where needed
4. **Nest.Name compliance** — `Affine.Discrete.Position`, not `Ordinal`
5. **Constraint preservation** — No protocols used; concrete types throughout

The key insight is recognizing that "affine space" is a mathematical concept with multiple instantiations (discrete vs. continuous, 1D vs. N-D), and the current architecture conflated these. By separating `Affine.Discrete` (Tier 0) from `Affine.Continuous` (Tier 5), we preserve the mathematical precision while enabling proper dependency flow.

---

## Appendix A: Package Dependency Matrix (After Reorganization)

| Package | Tier | Dependencies |
|---------|------|--------------|
| `swift-tagged-primitives` | 0 | — |
| `swift-affine-primitives` | 0 | — |
| `swift-index-primitives` | 1 | identity, affine |
| `swift-finite-primitives` | 1 | affine |
| `swift-ordinal-primitives` | 1 | affine (deprecated) |
| `swift-vector-primitives` | 3 | affine, bit |
| `swift-algebra-linear-primitives` | 5 | algebra, dimension, formatting, numeric |
| `swift-affine-geometry-primitives` | 5 | linear, formatting, numeric |
| `swift-geometry-primitives` | 6 | affine-geometry, algebra, dimension, region, symmetry |

## Appendix B: Type Mapping

| Old Type | New Type |
|----------|----------|
| `Ordinal` | `Affine.Discrete.Position` |
| `Ordinal.Offset` | `Affine.Discrete.Displacement` |
| `Finite.Bounded<N>` | `Affine.Discrete.Bounded<N>` |
| `Index<E>.Offset` | `Affine.Discrete.Displacement` (typealias) |
| `Index<E>.Bounded<N>` | Wrapper around `Affine.Discrete.Bounded<N>` |
| `Affine.Point<N>` | `Affine.Continuous.Point<N>` |
| `Affine.Transform` | `Affine.Continuous.Transform` |

## Appendix C: References

- [API-NAME-001] Namespace Structure: Nest.Name Pattern
- [API-NAME-002] No Compound Identifiers
- [API-NAME-009] Names as Constraints
- [PRIM-ARCH-001] Nine-Tier Dependency Structure
- [PRIM-ARCH-002] Tier Dependency Constraint
- [PRIM-ORG-001] The Relocation Principle
- [PRIM-ORG-005] Factor the Law, Not the Module
- [PRIM-NAME-003] Names Describe Mechanism, Not Origin
