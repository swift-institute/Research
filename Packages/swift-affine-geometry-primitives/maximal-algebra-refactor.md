# Maximal Algebra Refactor

<!--
---
version: 1.0.0
last_updated: 2026-02-04
status: RECOMMENDATION
tier: 2
packages: [swift-affine-geometry-primitives, swift-algebra-primitives]
---
-->

## Context

swift-affine-geometry-primitives (Tier 16) defines 2D/3D affine geometry: points, translations, and transforms. Several of its types carry re-implemented algebraic structure that duplicates what algebra-primitives provides. The package already transitively depends on algebra via algebra-linear-primitives.

Abstract algebra is conceptually more foundational than affine geometry — you define what a group is before you define the translation group or the affine transform group. The tier document is non-final; from first principles, affine-geometry should depend on algebra-primitives and express its algebraic structure through witnesses.

## Question

How should swift-affine-geometry-primitives be maximally refactored to use algebra-primitives, eliminating all re-implementation of algebraic concepts? All breaking changes are allowed.

## Inventory

### Source Files

| File | Primary Content |
|------|----------------|
| `Affine.Continuous.swift` | Namespace, type aliases (X, Y, Z, W, Dx, Dy, Dz, Distance, Area) |
| `Affine.Continuous.Point.swift` | `Point<N>` — coordinates, zero, translation methods, distance, lerp, midpoint |
| `Affine.Continuous.Translation.swift` | `Translation` — dx/dy, zero, +, -, prefix -, vector conversion |
| `Affine.Continuous.Transform.swift` | `Transform` — linear+translation, identity, concatenating, inverted, apply, factories, composed |
| `Affine.Continuous+Arithmetic.swift` | Point-Point subtraction, Point+Vector, Point-Vector (N-dimensional) |
| `Affine.Continuous+Formatting.swift` | Re-export |
| `Affine.Continuous.Point+Real.swift` | Polar coordinates, angle, radius, rotation |
| `exports.swift` | `@_exported import Algebra_Linear_Primitives`, `@_exported import Dimension_Primitives` |

### Operation Classification

#### Translation — Abelian Group (R², +)

| Operation | Algebraic Role | Replace? |
|-----------|---------------|----------|
| `.zero` | **Identity** | Yes — delegate to witness |
| `+ (Translation, Translation)` | **Combining** | Yes — delegate to witness |
| `- (Translation, Translation)` | **Combining with inverse** | Yes — delegate to witness |
| `prefix -` | **Inverse** | Yes — delegate to witness |
| `init(_ vector:)` | Geometric conversion | Keep |
| `.vector` property | Geometric conversion | Keep |

#### Transform — Group (Aff(2), composition)

| Operation | Algebraic Role | Replace? |
|-----------|---------------|----------|
| `.identity` | **Identity** | Yes — delegate to witness |
| `concatenating(_:_:)` static | **Combining** | **Remove** (use witness directly) |
| `concatenating(_:)` instance | **Combining** | Yes — delegate to witness |
| `.inverted` static | **Inverse** | **Remove** (use witness directly) |
| `.inverted` instance | **Inverse** | Yes — delegate to witness |
| `composed([transforms])` | **Monoidal fold** | Yes — delegate to witness |
| `composed(transforms...)` | **Monoidal fold** | Yes — delegate to witness |
| `.translated()`, `.scaled()`, `.rotated()` | Fluent modifiers (combining with factory) | Keep — delegate combining to witness |
| `.apply(to: point)` | Group action on Point | Keep (future: formal action witness) |
| `.apply(to: vector)` | Linear action on Vector | Keep |
| `.determinant` | Linear algebra property | Keep |
| `.isInvertible` | Derived property | Keep |
| All factory methods | Geometric constructors | Keep |

#### Point + Vector Arithmetic — Torsor / Group Action

| Operation | Algebraic Role | Replace? |
|-----------|---------------|----------|
| `Point - Point → Vector` | **Torsor difference** | Keep (no `Algebra.Torsor` exists yet) |
| `Point + Vector → Point` | **Group action** | Keep |
| `Point - Vector → Point` | **Inverse action** | Keep |
| `translated(dx:dy:)` | Component-wise action | Keep |
| `translated(by: vector)` | Action wrapper | Keep |
| `vector(from:to:)` | Torsor difference | Keep |

#### Pure Geometry (No Algebraic Structure)

| Operation | Category |
|-----------|----------|
| `Point.zero` | Origin (not algebraic — points don't form a group) |
| `lerp(from:to:t:)` | Affine combination |
| `midpoint(from:to:)` | Affine combination |
| `distance.squared`, `distance.from` | Metric structure |
| `polar(radius:angle:)`, `.angle`, `.radius` | Polar coordinates |
| `rotated(by:)` on Point | Point rotation |
| All `Equatable`, `Hashable`, `Codable` | Structural conformances |
| All coordinate accessors | Data access |

## Analysis

### Option A: Witnesses + Delegation (Recommended)

Add `Algebra.Group.Abelian` witness for Translation, `Algebra.Monoid` + `Algebra.Group` witnesses for Transform. Replace algebraic method bodies with witness delegation. Remove duplicate static methods.

**New files**:
- `Affine.Continuous.Translation+Algebra.swift`
- `Affine.Continuous.Transform+Algebra.swift`

**Translation refactoring**:

```swift
extension Affine.Continuous.Translation
where Scalar: AdditiveArithmetic & SignedNumeric & Sendable {

    /// Abelian group of 2D translations under component-wise addition.
    @inlinable
    public static var group: Algebra.Group<Self>.Abelian {
        .init(group: .init(
            identity: .init(dx: .zero, dy: .zero),
            combining: { .init(dx: $0.dx + $1.dx, dy: $0.dy + $1.dy) },
            inverting: { .init(dx: -$0.dx, dy: -$0.dy) }
        ))
    }
}

// Existing operators delegate:
extension Affine.Continuous.Translation
where Scalar: AdditiveArithmetic & SignedNumeric & Sendable {

    public static var zero: Self { group.identity }

    public static func + (lhs: Self, rhs: Self) -> Self {
        group.combining(lhs, rhs)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        group.combining(lhs, group.inverting(rhs))
    }

    public static prefix func - (value: Self) -> Self {
        group.inverting(value)
    }
}
```

**Transform refactoring**:

```swift
extension Affine.Continuous.Transform
where Scalar: FloatingPoint & ExpressibleByIntegerLiteral & Sendable {

    /// Monoid of affine transforms under composition (always valid).
    @inlinable
    public static var monoid: Algebra.Monoid<Self> {
        .init(
            identity: .identity,
            combining: { lhs, rhs in
                // matrix multiplication + translation composition
                lhs.concatenating(rhs)
            }
        )
    }

    /// Group of invertible affine transforms (precondition: det ≠ 0).
    @inlinable
    public static var group: Algebra.Group<Self> {
        .init(
            identity: .identity,
            combining: { lhs, rhs in lhs.concatenating(rhs) },
            inverting: { transform in
                guard let inv = transform.inverted else {
                    preconditionFailure("Group inverse on singular transform")
                }
                return inv
            }
        )
    }

    /// Monoidal fold of transforms.
    @inlinable
    public static func composed(_ transforms: [Self]) -> Self {
        transforms.reduce(monoid.identity, monoid.combining)
    }
}
```

**Removed API**:

| Removed | Replacement |
|---------|-------------|
| `static func concatenating(_:_:)` | `Transform.monoid.combining(a, b)` or `a.concatenating(b)` |
| `static func inverted(_:)` | `Transform.group.inverting(a)` or `a.inverted` |

**Preserved API** (delegates to witness):

| Method | Delegates to |
|--------|-------------|
| `func concatenating(_:)` | `Self.monoid.combining(self, other)` |
| `var inverted: Self?` | Keeps optional semantics (witness preconditions internally) |
| `.translated()`, `.scaled()`, `.rotated()` | `Self.monoid.combining(self, factory)` |
| `composed([])` / `composed(...)` | `reduce(monoid.identity, monoid.combining)` |

### Option B: Full Algebraic Redesign

Replace the entire Transform API surface with witness-centric design. Remove `concatenating`, `inverted` as methods — callers use `Transform.group.combining(a, b)` directly.

**Too aggressive** — the fluent modifier pattern (`.translated().scaled().rotated()`) is valuable geometric API that shouldn't require witness access at every call site.

### Comparison

| Criterion | A: Witnesses + Delegation | B: Full Redesign |
|-----------|--------------------------|-----------------|
| Duplication eliminated | ~90% | 100% |
| Ergonomic API preserved | Yes | No |
| Breaking changes | Moderate (static methods) | High (entire API) |
| Law verification | Full | Full |
| Geometric convenience | Preserved | Lost |

## Package.swift Change

No package-level dependency changes needed. The transitive dependency on algebra-primitives via algebra-linear-primitives already provides access. The target may need an explicit product dependency on `Algebra Group Primitives` or `Algebra Monoid Primitives` if not already re-exported through the chain.

Verify with:
```swift
// In any source file:
import Algebra_Group_Primitives  // Must resolve without error
```

If not available, add to target dependencies:
```swift
.product(name: "Algebra Group Primitives", package: "swift-algebra-primitives"),
.product(name: "Algebra Monoid Primitives", package: "swift-algebra-primitives"),
```

## Breaking Changes

| Change | Type | Migration |
|--------|------|-----------|
| `static func concatenating(_:_:)` removed | Removal | Use `a.concatenating(b)` or `Transform.monoid.combining(a, b)` |
| `static func inverted(_:)` removed | Removal | Use `a.inverted` or `Transform.group.inverting(a)` |
| `Translation.zero` may narrow constraints | Narrowing | Add `Sendable` where missing (all stdlib scalars already conform) |
| `composed()` implementation changes | Internal | Same behavior, delegated to monoid fold |

## Test Benefits

### Translation — Sampled Law Verification

```swift
let g = Translation.group
let samples: [Translation] = [.zero, .init(dx: 1, dy: 0), .init(dx: -3, dy: 7)]

#expect(Algebra.Law.Identity.left(of: g.monoid, over: samples) == nil)
#expect(Algebra.Law.Identity.right(of: g.monoid, over: samples) == nil)
#expect(Algebra.Law.Inverse.left(of: g.group, over: samples) == nil)
#expect(Algebra.Law.Inverse.right(of: g.group, over: samples) == nil)
#expect(Algebra.Law.Associativity.check(of: g.semigroup, over: samples) == nil)
#expect(Algebra.Law.Commutativity.check(of: g.combining, over: samples) == nil)
```

### Transform — Sampled with Exact Values

```swift
let m = Transform.monoid
let exact: [Transform] = [
    .identity,
    .translation(dx: 3, dy: -4),
    .scale(2),
    .rotation(Degree(90)),  // exact rotation avoids FP imprecision
]

#expect(Algebra.Law.Identity.left(of: m, over: exact) == nil)
#expect(Algebra.Law.Identity.right(of: m, over: exact) == nil)
#expect(Algebra.Law.Associativity.check(of: m.semigroup, over: exact) == nil)
```

## Follow-Up Work

| Item | Package | Description |
|------|---------|-------------|
| `Algebra.Torsor` witness type | algebra-primitives | Formalize Point-Vector torsor relationship |
| `Algebra.Group.Abelian<Linear.Vector<N>>` | algebra-linear-primitives | Vector group witness |
| `Algebra.VectorSpace` for scalar-vector | algebra-linear-primitives | Scalar multiplication witness |
| 3D Transform group | affine-geometry-primitives | Extend to `Transform<3>` when N-dimensional support lands |

## Outcome

**Status**: RECOMMENDATION

Option A (Witnesses + Delegation) is recommended. It eliminates ~90% of algebraic duplication, enables law verification through standard harnesses, preserves the ergonomic geometric API, and requires only moderate breaking changes (removal of static method duplicates). The dependency is already available transitively.

## References

- `/Users/coen/Developer/swift-primitives/swift-affine-geometry-primitives/Sources/Affine Geometry Primitives/` — All source files
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Group Primitives/Algebra.Group.swift`
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Group Primitives/Algebra.Group.Abelian.swift`
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Monoid Primitives/Algebra.Monoid.swift`
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Module Primitives/Algebra.Module.swift`
