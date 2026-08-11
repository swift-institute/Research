# Maximal Algebra Refactor

<!--
---
version: 1.0.0
last_updated: 2026-02-04
status: RECOMMENDATION
tier: 2
packages: [swift-symmetry-primitives, swift-algebra-primitives]
---
-->

## Context

swift-symmetry-primitives contains three types with algebraic group structure: `Rotation<2, Scalar>` (SO(2)), `Phase` (Z4), and `Shear<2, Scalar>` (additive abelian group on off-diagonal parameters). Each type currently implements its own ad-hoc algebraic operations (`identity`, `concatenate`, `inverted`, `composed`, `inverse`, etc.) using bespoke static and instance methods.

swift-algebra-primitives provides a witness-based algebra system with `Algebra.Group<Element>` and `Algebra.Group<Element>.Abelian`, plus law verification harnesses (`Algebra.Law.Inverse`, `Algebra.Law.Commutativity`, `Algebra.Law.Associativity`). These witnesses are `@frozen` structs carrying `identity`, `combining`, and `inverting` closures.

The symmetry types predate the algebra package. They duplicate algebraic structure that should be expressed through the canonical witness types. This research documents the refactoring plan to align symmetry-primitives with algebra-primitives.

## Question

How should each symmetry type's algebraic operations be refactored to use `Algebra.Group<Element>.Abelian` witnesses, what is the correct algebraic structure for each type, and what are the breaking changes?

## Analysis

### Type Inventory

Six source files exist in `Symmetry Primitives`:

| File | Type | Algebraic Structure | In Scope |
|------|------|---------------------|----------|
| `Rotation.swift` | `Rotation<N, Scalar>` | SO(2) abelian group (N=2) | Yes |
| `Rotation.Phase.swift` | `Phase` | Z4 cyclic abelian group | Yes |
| `Shear.swift` | `Shear<N, Scalar>` | Abelian group (additive on off-diagonal params) | Yes |
| `Scale+Linear.swift` | `Scale` extension | No algebraic ops (conversion only) | No |
| `Affine.Transform.swift` | `Affine.Transform` extension | No algebraic ops (bridge inits only) | No |
| `Symmetry.swift` | `Symmetry` namespace | No algebraic ops | No |

### Option A: Witness-First (Recommended)

Each type vends a static `group` property returning `Algebra.Group<Self>.Abelian`. Existing convenience API is preserved as thin wrappers delegating to the witness. Duplicate static methods are removed.

**Advantages**:
- Single canonical source of algebraic truth per type
- Law harnesses become available for exhaustive verification
- Consistent API surface across all algebraic types in the ecosystem
- Convenience wrappers preserve discoverability for geometric contexts

**Disadvantages**:
- Breaking change: removes static two-argument forms
- New dependency on swift-algebra-primitives

### Option B: Protocol Conformance

Define a protocol (e.g., `GroupElement`) requiring `static var group` and conform each type.

**Advantages**:
- Generic algorithms over all group elements

**Disadvantages**:
- Protocol introduces existential or generic constraint propagation issues with `~Copyable` and value generics
- Premature abstraction; no current consumer needs generic group dispatch
- Algebra-primitives deliberately chose witnesses over protocols

### Option C: No Change

Keep ad-hoc methods.

**Advantages**:
- No breaking changes
- No new dependency

**Disadvantages**:
- Algebraic laws unverifiable through standard harnesses
- Duplicates structure that algebra-primitives exists to provide
- Inconsistent with direction of all other algebraic types in the ecosystem

### Comparison

| Criterion | Option A: Witness-First | Option B: Protocol | Option C: No Change |
|-----------|------------------------|-------------------|---------------------|
| Canonical algebraic structure | Yes | Yes | No |
| Law verification via harnesses | Yes | Yes | No |
| Breaking changes | Moderate (static methods) | Moderate + protocol tax | None |
| New dependency | algebra-primitives | algebra-primitives | None |
| Ecosystem consistency | Full | Full | Divergent |
| Complexity | Low | Medium (protocol design) | Lowest |
| Premature abstraction risk | None | Yes | N/A |

---

## Detailed Design Per Type

### 1. Rotation<2, Scalar> -- SO(2) Abelian Group

**Mathematical structure**: The 2D rotation group SO(2) is abelian because rotation composition in 2D is commutative (angle addition). The group operation is 2x2 orthogonal matrix multiplication, identity is the 2x2 identity matrix, and inversion is matrix transpose.

**Current API** (from `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Sources/Symmetry Primitives/Rotation.swift`):

```swift
// Lines 96-108: Identity
extension Rotation where Scalar: ExpressibleByIntegerLiteral {
    public static var identity: Self {
        var m = InlineArray<N, InlineArray<N, Scalar>>(
            repeating: InlineArray<N, Scalar>(repeating: 0)
        )
        for i in 0..<N {
            m[i][i] = 1
        }
        return Self(matrix: m)
    }
}

// Lines 200-225: Static composition
extension Rotation where N == 2, Scalar: BinaryFloatingPoint {
    public static func concatenate(_ lhs: Self, with rhs: Self) -> Self {
        let a = lhs.matrix[0][0] * rhs.matrix[0][0] + lhs.matrix[0][1] * rhs.matrix[1][0]
        let b = lhs.matrix[0][0] * rhs.matrix[0][1] + lhs.matrix[0][1] * rhs.matrix[1][1]
        let c = lhs.matrix[1][0] * rhs.matrix[0][0] + lhs.matrix[1][1] * rhs.matrix[1][0]
        let d = lhs.matrix[1][0] * rhs.matrix[0][1] + lhs.matrix[1][1] * rhs.matrix[1][1]
        var m = InlineArray<2, InlineArray<2, Scalar>>(
            repeating: InlineArray<2, Scalar>(repeating: .zero)
        )
        m[0][0] = a; m[0][1] = b; m[1][0] = c; m[1][1] = d
        return Self(matrix: m)
    }
}

// Lines 228-236: Instance composition
extension Rotation where N == 2, Scalar: BinaryFloatingPoint {
    public func concatenating(_ other: Self) -> Self {
        Self.concatenate(self, with: other)
    }
}

// Lines 238-255: Static inversion
extension Rotation where N == 2, Scalar: BinaryFloatingPoint {
    public static func inverted(_ rotation: Self) -> Self {
        var m = InlineArray<2, InlineArray<2, Scalar>>(
            repeating: InlineArray<2, Scalar>(repeating: .zero)
        )
        m[0][0] = rotation.matrix[0][0]; m[0][1] = rotation.matrix[1][0]
        m[1][0] = rotation.matrix[0][1]; m[1][1] = rotation.matrix[1][1]
        return Self(matrix: m)
    }
}

// Lines 257-263: Instance inversion
extension Rotation where N == 2, Scalar: BinaryFloatingPoint {
    public var inverted: Self {
        Self.inverted(self)
    }
}
```

**Operations to replace with witness**: `concatenate(_:with:)`, `concatenating(_:)`, `inverted(_:)` (static), `var inverted`.

**Operations to keep unchanged**: `identity` (N-dimensional, geometric significance beyond the 2D group witness), `init(angle:)`, `init(degrees:)`, `init(cos:sin:)`, `var angle`, `linear()`, `quarterTurn`, `halfTurn`, `quarterTurnClockwise`, `rotated(by:)`, Equatable, Hashable, Codable.

**Design decision -- identity**: The existing `identity` is defined for all N where `Scalar: ExpressibleByIntegerLiteral`. The abelian group witness is constrained to `N == 2, Scalar: BinaryFloatingPoint & Sendable`. The N-dimensional `identity` must remain as a separate geometric property. The witness's `identity` closure will return `Self.identity` when `N == 2`.

#### After: Rotation+Algebra.swift

```swift
// Rotation+Algebra.swift

import Algebra_Group_Primitives

extension Rotation where N == 2, Scalar: BinaryFloatingPoint & Sendable {
    /// SO(2) abelian group witness.
    ///
    /// The group operation is 2x2 orthogonal matrix multiplication.
    /// Commutativity holds because 2D rotations commute (angle addition).
    public static var group: Algebra.Group<Self>.Abelian {
        .init(group: .init(
            identity: .identity,
            combining: { lhs, rhs in
                let a = lhs.matrix[0][0] * rhs.matrix[0][0]
                    + lhs.matrix[0][1] * rhs.matrix[1][0]
                let b = lhs.matrix[0][0] * rhs.matrix[0][1]
                    + lhs.matrix[0][1] * rhs.matrix[1][1]
                let c = lhs.matrix[1][0] * rhs.matrix[0][0]
                    + lhs.matrix[1][1] * rhs.matrix[1][0]
                let d = lhs.matrix[1][0] * rhs.matrix[0][1]
                    + lhs.matrix[1][1] * rhs.matrix[1][1]
                var m = InlineArray<2, InlineArray<2, Scalar>>(
                    repeating: InlineArray<2, Scalar>(repeating: .zero)
                )
                m[0][0] = a; m[0][1] = b; m[1][0] = c; m[1][1] = d
                return Self(matrix: m)
            },
            inverting: { rotation in
                var m = InlineArray<2, InlineArray<2, Scalar>>(
                    repeating: InlineArray<2, Scalar>(repeating: .zero)
                )
                m[0][0] = rotation.matrix[0][0]
                m[0][1] = rotation.matrix[1][0]
                m[1][0] = rotation.matrix[0][1]
                m[1][1] = rotation.matrix[1][1]
                return Self(matrix: m)
            }
        ))
    }

    /// Composes two rotations by matrix multiplication.
    ///
    /// - Returns: Rotation applying `other` first, then `self`.
    @inlinable
    public func concatenating(_ other: Self) -> Self {
        Self.group.combining(self, other)
    }

    /// Inverse rotation (matrix transpose for orthogonal matrices).
    @inlinable
    public var inverted: Self {
        Self.group.inverting(self)
    }
}
```

**Removed API**:
- `static func concatenate(_:with:)` -- callers use `group.combining(a, b)` or `a.concatenating(b)`
- `static func inverted(_:)` -- callers use `group.inverting(a)` or `a.inverted`

**Preserved API** (delegating to witness):
- `func concatenating(_:)` -- thin wrapper over `group.combining`
- `var inverted` -- thin wrapper over `group.inverting`

**Unchanged API**:
- `static var identity` (N-dimensional, line 96)
- `func rotated(by:)` (line 152, calls `concatenating` which now delegates to witness)
- All initializers, angle property, linear(), named turns, Equatable, Hashable, Codable

---

### 2. Phase -- Z4 Cyclic Abelian Group

**Mathematical structure**: The cyclic group of order 4 under addition modulo 4. Identity is `.zero`, composition is `(a.rawValue + b.rawValue) % 4`, inverse is `(4 - a.rawValue) % 4`.

**Current API** (from `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Sources/Symmetry Primitives/Rotation.Phase.swift`):

```swift
// Lines 37-39: Static next
public static func next(of phase: Phase) -> Phase {
    Phase(rawValue: (phase.rawValue + Cardinal.one) % 4)!
}

// Lines 43-45: Instance next
public var next: Phase { Phase.next(of: self) }

// Lines 49-51: Static previous
public static func previous(of phase: Phase) -> Phase {
    Phase(rawValue: (phase.rawValue + Cardinal(3)) % 4)!
}

// Lines 55-57: Instance previous
public var previous: Phase { Phase.previous(of: self) }

// Lines 61-63: Static opposite
public static func opposite(of phase: Phase) -> Phase {
    Phase(rawValue: (phase.rawValue + Cardinal(2)) % 4)!
}

// Lines 67-69: Instance opposite
public var opposite: Phase { Phase.opposite(of: self) }

// Lines 73-75: Prefix operator
public static prefix func ! (value: Phase) -> Phase {
    value.opposite
}

// Lines 83-85: Static composition
public static func composed(_ lhs: Phase, with rhs: Phase) -> Phase {
    Phase(rawValue: (lhs.rawValue + rhs.rawValue) % 4)!
}

// Lines 89-91: Instance composition
public func composed(with other: Phase) -> Phase {
    Phase.composed(self, with: other)
}

// Lines 95-97: Static inverse
public static func inverse(of phase: Phase) -> Phase {
    Phase(rawValue: (4 - phase.rawValue) % 4)!
}

// Lines 101-103: Instance inverse
public var inverse: Phase { Phase.inverse(of: self) }
```

**Design decision -- no Z4 transport**: Phase should NOT use a generic Z4 carrier type. There is no canonical Z4 carrier shared across types in the ecosystem. Phase's rawValue arithmetic is the natural encoding.

**Design decision -- next/previous/opposite**: These are geometric convenience names for specific group elements (.quarter, .threeQuarter, .half) composed with self. They should be retained as convenience API, reimplemented as witness delegation:
- `next` = `composed(with: .quarter)` = `group.combining(self, .quarter)`
- `previous` = `composed(with: .threeQuarter)` = `group.combining(self, .threeQuarter)`
- `opposite` = `composed(with: .half)` = `group.combining(self, .half)`

#### After: Phase+Algebra.swift

```swift
// Phase+Algebra.swift

import Algebra_Group_Primitives

extension Phase {
    /// Z4 cyclic abelian group witness.
    ///
    /// The group operation is addition modulo 4 on rawValues.
    /// Commutativity holds because integer addition is commutative.
    public static var group: Algebra.Group<Phase>.Abelian {
        .init(group: .init(
            identity: .zero,
            combining: { lhs, rhs in
                Phase(rawValue: (lhs.rawValue + rhs.rawValue) % 4)!
            },
            inverting: { phase in
                Phase(rawValue: (4 - phase.rawValue) % 4)!
            }
        ))
    }

    /// Composes two phases by adding rotations (modulo 4).
    @inlinable
    public func composed(with other: Phase) -> Phase {
        Self.group.combining(self, other)
    }

    /// Inverse phase (rotation that reverses this rotation).
    @inlinable
    public var inverse: Phase {
        Self.group.inverting(self)
    }

    /// Next phase (90 degrees counterclockwise rotation).
    @inlinable
    public var next: Phase {
        Self.group.combining(self, .quarter)
    }

    /// Previous phase (90 degrees clockwise rotation).
    @inlinable
    public var previous: Phase {
        Self.group.combining(self, .threeQuarter)
    }

    /// Opposite phase (180 degrees rotation).
    @inlinable
    public var opposite: Phase {
        Self.group.combining(self, .half)
    }

    /// Returns the opposite phase.
    @inlinable
    public static prefix func ! (value: Phase) -> Phase {
        value.opposite
    }
}
```

**Removed API**:
- `static func composed(_:with:)` -- callers use `group.combining(a, b)` or `a.composed(with: b)`
- `static func inverse(of:)` -- callers use `group.inverting(a)` or `a.inverse`
- `static func next(of:)` -- callers use `a.next`
- `static func previous(of:)` -- callers use `a.previous`
- `static func opposite(of:)` -- callers use `a.opposite`

**Preserved API** (delegating to witness):
- `func composed(with:)` -- thin wrapper
- `var inverse` -- thin wrapper
- `var next` -- reimplemented as composition with `.quarter`
- `var previous` -- reimplemented as composition with `.threeQuarter`
- `var opposite` -- reimplemented as composition with `.half`
- `prefix !` -- unchanged (delegates to `opposite`)

**Unchanged API**:
- `var degrees`, `init?(degrees:)`, `Value<Payload>`, `Finite.Enumerable`, cases, Codable

---

### 3. Shear<2, Scalar> -- Additive Abelian Group

**Mathematical structure**: Shear matrices are NOT closed under matrix multiplication. The product of two 2D shear matrices is not generally a shear matrix (the diagonal entries deviate from 1). The correct algebraic structure is component-wise addition of the off-diagonal parameters (x, y). Under this operation:
- Identity: `Shear(x: 0, y: 0)` (the identity shear)
- Composition: `Shear(x: a.x + b.x, y: a.y + b.y)`
- Inverse: `Shear(x: -a.x, y: -a.y)`

This is isomorphic to (R2, +), the additive group of the plane.

**Current API** (from `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Sources/Symmetry Primitives/Shear.swift`):

```swift
// Lines 80-86: Identity
extension Shear where Scalar: ExpressibleByIntegerLiteral {
    public static var identity: Self {
        Self(InlineArray(repeating: InlineArray(repeating: 0)))
    }
}
```

No composition or inverse operations currently exist. The refactoring adds them via the witness.

#### After: Shear+Algebra.swift

```swift
// Shear+Algebra.swift

import Algebra_Group_Primitives

extension Shear where N == 2, Scalar: Sendable {
    /// Additive abelian group witness for 2D shear parameters.
    ///
    /// The group operation is component-wise addition of off-diagonal
    /// shear factors. This is NOT matrix multiplication (shear matrices
    /// are not closed under matrix multiplication). The structure is
    /// isomorphic to (R^2, +).
    public static var group: Algebra.Group<Self>.Abelian {
        .init(group: .init(
            identity: .identity,
            combining: { lhs, rhs in
                var result = lhs
                result.x = lhs.x + rhs.x
                result.y = lhs.y + rhs.y
                return result
            },
            inverting: { shear in
                var result = shear
                result.x = .zero - shear.x
                result.y = .zero - shear.y
                return result
            }
        ))
    }

    /// Composes two shears by adding their off-diagonal parameters.
    @inlinable
    public func composed(with other: Self) -> Self {
        Self.group.combining(self, other)
    }

    /// Inverse shear (negation of off-diagonal parameters).
    @inlinable
    public var inverted: Self {
        Self.group.inverting(self)
    }
}
```

**New API**: `composed(with:)`, `var inverted` -- Shear gains composition and inverse for the first time.

**Constraint narrowing**: The witness requires `Scalar: Sendable` (in addition to `FloatingPoint` from the type definition). The existing `identity` remains on its own extension with `Scalar: ExpressibleByIntegerLiteral`. The witness references `.identity` which requires `ExpressibleByIntegerLiteral`; since `FloatingPoint` refines `ExpressibleByIntegerLiteral`, the constraint is already satisfied. The `Sendable` constraint narrows the set of eligible scalars.

**Design decision -- why not matrix multiplication**: Consider two shear matrices:

```
S1 = [[1, a], [b, 1]]    S2 = [[1, c], [d, 1]]

S1 * S2 = [[1 + a*d, c + a], [b + d, b*c + 1]]
```

The diagonal entries `1 + a*d` and `b*c + 1` are not 1 unless `a*d = 0` and `b*c = 0`. The product is not a shear matrix in general. Component-wise addition preserves the shear structure and forms a valid group.

---

## Package.swift Change

**Before** (`/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Package.swift`):

```swift
dependencies: [
    .package(path: "../swift-algebra-linear-primitives"),
    .package(path: "../swift-affine-primitives"),
    .package(path: "../swift-dimension-primitives"),
    .package(path: "../swift-numeric-primitives")
],
targets: [
    .target(
        name: "Symmetry Primitives",
        dependencies: [
            .product(name: "Algebra Linear Primitives", package: "swift-algebra-linear-primitives"),
            .product(name: "Affine Primitives", package: "swift-affine-primitives"),
            .product(name: "Dimension Primitives", package: "swift-dimension-primitives"),
            .product(name: "Real Primitives", package: "swift-numeric-primitives")
        ]
    )
],
```

**After**:

```swift
dependencies: [
    .package(path: "../swift-algebra-linear-primitives"),
    .package(path: "../swift-algebra-primitives"),
    .package(path: "../swift-affine-primitives"),
    .package(path: "../swift-dimension-primitives"),
    .package(path: "../swift-numeric-primitives")
],
targets: [
    .target(
        name: "Symmetry Primitives",
        dependencies: [
            .product(name: "Algebra Linear Primitives", package: "swift-algebra-linear-primitives"),
            .product(name: "Algebra Group Primitives", package: "swift-algebra-primitives"),
            .product(name: "Affine Primitives", package: "swift-affine-primitives"),
            .product(name: "Dimension Primitives", package: "swift-dimension-primitives"),
            .product(name: "Real Primitives", package: "swift-numeric-primitives")
        ]
    )
],
```

**Dependency direction**: swift-algebra-primitives is Tier 0. swift-symmetry-primitives depends on Tier 1 packages (dimension-primitives, algebra-linear-primitives). Adding a Tier 0 dependency is a downward dependency, which is permitted by the five-layer architecture.

---

## New Files Summary

| File | Type | Content |
|------|------|---------|
| `Rotation+Algebra.swift` | Extension | `Rotation<2, Scalar>` group witness + convenience wrappers |
| `Phase+Algebra.swift` | Extension | `Phase` group witness + convenience wrappers |
| `Shear+Algebra.swift` | Extension | `Shear<2, Scalar>` group witness + convenience wrappers |

Each file follows [API-IMPL-005] (one type per file). The `+Algebra` suffix follows the existing `Scale+Linear.swift` convention for extension files.

---

## Breaking Changes

### Rotation<2, Scalar>

| Removed | Replacement | Migration |
|---------|-------------|-----------|
| `static func concatenate(_:with:)` | `Rotation.group.combining(a, b)` | Mechanical: `concatenate(a, with: b)` becomes `group.combining(a, b)` |
| `static func inverted(_:)` | `Rotation.group.inverting(a)` | Mechanical: `inverted(r)` becomes `group.inverting(r)` |

Constraint narrowing: `var inverted` and `func concatenating(_:)` gain `Sendable` requirement on `Scalar` via the witness. All standard floating-point types (`Float`, `Double`, `Float16`, `Float80`) are `Sendable`, so this is non-breaking in practice.

### Phase

| Removed | Replacement | Migration |
|---------|-------------|-----------|
| `static func composed(_:with:)` | `Phase.group.combining(a, b)` | Mechanical |
| `static func inverse(of:)` | `Phase.group.inverting(a)` | Mechanical |
| `static func next(of:)` | `a.next` | Mechanical |
| `static func previous(of:)` | `a.previous` | Mechanical |
| `static func opposite(of:)` | `a.opposite` | Mechanical |

No constraint changes. Phase is already `Sendable`.

### Shear<2, Scalar>

| Added | Notes |
|-------|-------|
| `static var group` | New API |
| `func composed(with:)` | New API |
| `var inverted` | New API |

No removals. `identity` is unchanged. The `Sendable` constraint on the witness extension is additive (new API only).

---

## Test Benefits

### Exhaustive Law Verification for Phase

Phase has exactly 4 elements, enabling complete (not sampled) verification of all group laws:

```swift
import Testing
import Algebra_Law_Primitives

@Test func phaseGroupLaws() {
    let g = Phase.group.group
    let all = Phase.allCases

    // Associativity: (a * b) * c = a * (b * c) for all 64 triples
    #expect(Algebra.Law.Associativity.check(of: g.combining, over: all) == nil)

    // Left inverse: a^-1 * a = e for all 4 elements
    #expect(Algebra.Law.Inverse.left(of: g, over: all) == nil)

    // Right inverse: a * a^-1 = e for all 4 elements
    #expect(Algebra.Law.Inverse.right(of: g, over: all) == nil)

    // Commutativity: a * b = b * a for all 16 pairs
    #expect(Algebra.Law.Commutativity.check(of: g.combining, over: all) == nil)

    // Identity: e * a = a and a * e = a for all 4 elements
    #expect(Algebra.Law.Identity.left(of: g.monoid, over: all) == nil)
    #expect(Algebra.Law.Identity.right(of: g.monoid, over: all) == nil)
}
```

This is 4 + 16 + 4 + 4 + 4 = 32 law checks for Phase's full Cayley table, with zero sampling error.

### Sampled Verification for Rotation and Shear

Rotation and Shear operate over continuous scalar types. Tests should use a representative sample:

```swift
@Test func rotationGroupLaws() {
    let g = Rotation<2, Double>.group.group
    let samples: [Rotation<2, Double>] = [
        .identity,
        .quarterTurn,
        .halfTurn,
        .quarterTurnClockwise,
        Rotation(angle: Radian(0.7)),
        Rotation(angle: Radian(2.3)),
        Rotation(angle: Radian(-1.1)),
    ]

    #expect(Algebra.Law.Associativity.check(of: g.combining, over: samples) == nil)
    #expect(Algebra.Law.Inverse.left(of: g, over: samples) == nil)
    #expect(Algebra.Law.Inverse.right(of: g, over: samples) == nil)
    #expect(Algebra.Law.Commutativity.check(of: g.combining, over: samples) == nil)
}
```

Note: Floating-point equality checks may require approximate comparison for rotation tests. The law harnesses use `Equatable`, so the existing `Equatable` conformance on `Rotation<2, Scalar>` (exact comparison) will be used. For well-conditioned angles this should pass; for adversarial cases, a tolerance-aware wrapper may be needed.

---

## Scope Exclusions

### Scale

`Scale` is defined in swift-dimension-primitives, not swift-symmetry-primitives. Only `Scale+Linear.swift` exists here (a geometric conversion, no algebraic operations). Scale's algebraic refactoring belongs in a separate research document scoped to swift-dimension-primitives.

### Affine.Transform

`Affine.Transform.swift` contains only bridge initializers from symmetry types (`init(_ rotation:)`, `init(_ scale:)`, `init(_ shear:)`). No algebraic operations to refactor.

### N-Dimensional Generalization

The abelian group witnesses are constrained to `N == 2`. Higher-dimensional rotation groups (SO(3), SO(n)) are non-abelian and require `Algebra.Group<Self>` (not `.Abelian`). This is future work.

---

## Implementation Order

1. Add `swift-algebra-primitives` dependency to `Package.swift`
2. Create `Rotation+Algebra.swift` with witness and wrappers
3. Remove `static func concatenate` and `static func inverted` from `Rotation.swift`; redirect `concatenating` and `var inverted` to new file
4. Create `Phase+Algebra.swift` with witness and wrappers
5. Remove all static algebraic methods from `Rotation.Phase.swift`; redirect instance methods to new file
6. Create `Shear+Algebra.swift` with witness and wrappers
7. Run `swift package resolve` and `swift build`
8. Add law verification tests
9. Run `swift test`

---

## Outcome

**Status**: RECOMMENDATION

The witness-first approach (Option A) is recommended. It provides canonical algebraic structure, enables law verification through existing harnesses, and aligns symmetry-primitives with the ecosystem pattern established by algebra-primitives. Breaking changes are moderate and mechanically migratable. The new dependency on swift-algebra-primitives is a valid downward dependency within the tier architecture.

Implementation should proceed in the order specified above, with Phase implemented first (exhaustive verification provides highest confidence) followed by Rotation and Shear.

## References

- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Group Primitives/Algebra.Group.swift` -- Group witness definition
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Group Primitives/Algebra.Group.Abelian.swift` -- Abelian group witness definition
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Group Primitives/Algebra.Group.Abelian+Group.swift` -- Abelian group projections
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Law Primitives/Algebra.Law.Inverse.swift` -- Inverse law harness
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Law Primitives/Algebra.Law.Commutativity.swift` -- Commutativity law harness
- `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Sources/Symmetry Primitives/Rotation.swift` -- Current Rotation implementation
- `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Sources/Symmetry Primitives/Rotation.Phase.swift` -- Current Phase implementation
- `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Sources/Symmetry Primitives/Shear.swift` -- Current Shear implementation
- `/Users/coen/Developer/swift-primitives/swift-symmetry-primitives/Package.swift` -- Current package manifest
