# Maximal Algebra Refactor: Algebraic Witnesses for Swift Numeric Types

<!--
---
version: 1.0.0
last_updated: 2026-02-04
status: RECOMMENDATION
tier: 2
---
-->

## Context

swift-numeric-primitives provides utilities for Swift's standard numeric types: transcendental functions, rounding, approximate equality, GCD/LCM, saturating arithmetic, augmented arithmetic, bit rotation, and division with rounding. Meanwhile, swift-algebra-primitives provides the canonical algebraic vocabulary: `Algebra.Monoid`, `Algebra.Group`, `Algebra.Group.Abelian`, `Algebra.Semiring`, `Algebra.Ring`, `Algebra.Ring.Commutative`, and `Algebra.Field`, all as witness structs (value-level evidence of algebraic structure).

Currently, **no package in the ecosystem provides algebraic witnesses for Swift's standard numeric types** (`Int`, `Double`, `Float`, `UInt`, etc.). This is a critical gap: the algebra-primitives infrastructure exists, but there is no bridge connecting it to the types that every Swift developer uses.

The abstract algebraic vocabulary (what a ring IS, what a field IS) is conceptually more foundational than concrete numeric operations. Numbers are instances of algebraic structures, not the other way around. The tier document is non-final; from first principles, algebra-primitives' core hierarchy (Magma → Field, Module, Law) depends only on witness-primitives and belongs at a low tier. numeric-primitives should depend on algebra and provide witnesses for its domain types.

This document investigates how to maximally refactor swift-numeric-primitives to provide these witnesses by depending on algebra-primitives.

## Question

How should swift-numeric-primitives be refactored to provide algebraic witnesses (Ring, Field, Semiring, Monoid, Group) for Swift's standard numeric types, leveraging algebra-primitives?

## Prior Art Survey

### Mathematical Classification of Standard Types

The mathematical classification of machine numeric types is well-established:

- **Signed fixed-width integers** (Int, Int8, ..., Int64): Commutative rings with wrapping arithmetic. With standard `+`/`*`, they overflow and do not form exact rings. With `&+`/`&*` (wrapping), they form commutative rings isomorphic to Z/2^n Z.
- **Unsigned fixed-width integers** (UInt, UInt8, ..., UInt64): Commutative semirings with wrapping arithmetic. No additive inverses. With `&+`/`&*`, they form commutative semirings isomorphic to the non-negative elements of Z/2^n Z under addition and multiplication.
- **Floating-point types** (Double, Float, Float16): Approximate fields. IEEE 754 arithmetic is not associative, not distributive, and has special values (NaN, Inf, -0). However, for "ordinary" values, they approximate the field of real numbers.

### Haskell Precedent

Haskell's `Num` typeclass bundles ring operations (`+`, `-`, `*`, `negate`, `abs`, `signum`, `fromInteger`). `Fractional` extends this with division (`/`, `recip`). The numeric hierarchy has been widely criticized (e.g., the "Num Sucks" meme) for conflating algebraic structure with numeric representation. The witness-based approach in algebra-primitives avoids this by separating structure from type.

### Rust Precedent

The `num-traits` crate provides `Zero`, `One`, `Num`, `NumOps` traits. The `alga` crate (now superseded by `simba`) provided algebraic structure traits. Both use protocol/trait conformance rather than value-level witnesses, which means a type can only have ONE algebraic structure per trait.

### Advantage of Witness-Based Approach

algebra-primitives uses **value-level witnesses**: `Algebra.Ring<Int>` is a *value* that carries the operations, not a protocol conformance. This means:
- A single type can have multiple algebraic structures (e.g., `Int` under wrapping arithmetic vs. saturating arithmetic)
- The choice of structure is explicit at the call site
- Caveats (overflow, rounding) are documented per-witness, not per-type

## Tier Positioning

The current tier document places numeric-primitives at Tier 1 and algebra-primitives at Tier 12. This document treats the tier assignments as non-final. From first principles, the abstract algebraic vocabulary (what a ring IS) is more foundational than concrete numeric utilities (transcendental functions, rounding modes). The core algebraic hierarchy (Magma → Field, Module, Law) depends only on witness-primitives. With algebra's core at a low tier, numeric-primitives can depend on it directly.

## Analysis

### Option A: Witnesses in numeric-primitives (Recommended)

numeric-primitives adds algebra-primitives as a dependency and provides Ring/Field/Semiring witnesses alongside its existing numeric utilities. This is the natural home: numeric-primitives is the domain expert for numeric types.

**Structure:**
```
swift-numeric-primitives/Sources/Numeric Primitives/
    Algebra.Ring.Commutative+Int.swift
    Algebra.Semiring+UInt.swift
    Algebra.Field+Double.swift
    Algebra.Group.Abelian+Additive.swift
    Algebra.Monoid.Commutative+GCD.swift
    Algebra.Monoid.Commutative+LCM.swift
    ...
```

Or organized as a separate target within the package:
```
swift-numeric-primitives/Sources/Numeric Algebra Primitives/
    ...
```

**Pros:**
- Witnesses live with the domain they describe
- Can reuse existing GCD/LCM implementations from Integer Primitives
- Can provide saturating arithmetic monoids using existing infrastructure
- numeric-primitives becomes the canonical "numbers + their algebraic structure" package

**Cons:**
- Requires tier document update (algebra must be lower-tier than numeric)
- Adds a dependency to numeric-primitives

### Option B: Witnesses in algebra-primitives

Place witnesses in algebra's aggregate target. Witnesses only use stdlib operators, so no dependency on numeric-primitives is needed.

**Pros:**
- No tier changes needed (algebra already exists, witnesses use only stdlib)
- Follows existing precedent (`Algebra.Field+Parity.swift`)
- Users get witnesses by importing `Algebra_Primitives`

**Cons:**
- GCD/LCM must be reimplemented (cannot import from numeric-primitives)
- Saturating arithmetic witnesses impossible (no dep on numeric-primitives)
- algebra-primitives gains knowledge of concrete numeric types
- Witnesses are separated from the domain they describe

### Comparison

| Criterion | A: In numeric-primitives | B: In algebra-primitives |
|-----------|-------------------------|-------------------------|
| Domain cohesion | **High** (witnesses next to the types) | Low (separated) |
| GCD/LCM reuse | **Yes** (same package) | No (must reimplement) |
| Saturating witnesses | **Yes** | No |
| Tier change required | Yes | No |
| Existing precedent | No | Yes (Parity, Z2) |
| Discoverability | import Numeric_Primitives | import Algebra_Primitives |

## Recommendation

**Option A: Add witnesses to numeric-primitives**, contingent on tier restructuring that places algebra's core hierarchy at a low tier. This is the architecturally correct placement — the domain expert for numeric types should also express their algebraic structure.

**For operations that DO need numeric-primitives** (saturating arithmetic monoids, GCD/LCM monoids), two sub-options exist:
- **(A1)** Implement GCD/LCM directly in algebra-primitives (the algorithm is trivial: Euclidean GCD is ~5 lines, and only needs `%` and `*` from stdlib).
- **(A2)** Defer saturating arithmetic monoids to a future bridge package if demand arises.

We recommend A1 for GCD/LCM (they are fundamental number-theoretic operations that belong alongside ring/field structure) and A2 for saturating arithmetic (niche, can wait).

---

## Full Inventory of Witnesses

### Mapping Table: Swift Type to Algebraic Structure

| Swift Type | Algebraic Structure | Witness Type | Identity (+) | Identity (*) | Caveats |
|------------|---------------------|-------------|--------------|--------------|---------|
| `Int` | Commutative ring (wrapping) | `Algebra.Ring.Commutative<Int>` | `0` | `1` | Wrapping overflow (`&+`, `&*`, `&-`). Not a mathematical ring under `+`/`*` due to trapping overflow. |
| `Int8` | Commutative ring (wrapping) | `Algebra.Ring.Commutative<Int8>` | `0` | `1` | Same as Int. Isomorphic to Z/256Z (two's complement). |
| `Int16` | Commutative ring (wrapping) | `Algebra.Ring.Commutative<Int16>` | `0` | `1` | Same. Z/65536Z. |
| `Int32` | Commutative ring (wrapping) | `Algebra.Ring.Commutative<Int32>` | `0` | `1` | Same. Z/2^32 Z. |
| `Int64` | Commutative ring (wrapping) | `Algebra.Ring.Commutative<Int64>` | `0` | `1` | Same. Z/2^64 Z. |
| `UInt` | Commutative semiring (wrapping) | `Algebra.Semiring<UInt>` | `0` | `1` | No additive inverses. Wrapping overflow (`&+`, `&*`). |
| `UInt8` | Commutative semiring (wrapping) | `Algebra.Semiring<UInt8>` | `0` | `1` | Same. |
| `UInt16` | Commutative semiring (wrapping) | `Algebra.Semiring<UInt16>` | `0` | `1` | Same. |
| `UInt32` | Commutative semiring (wrapping) | `Algebra.Semiring<UInt32>` | `0` | `1` | Same. |
| `UInt64` | Commutative semiring (wrapping) | `Algebra.Semiring<UInt64>` | `0` | `1` | Same. |
| `Double` | Approximate field | `Algebra.Field<Double>` | `0.0` | `1.0` | Not exact: rounding, NaN, Inf, -0. Laws hold approximately. Reciprocal of 0 throws. |
| `Float` | Approximate field | `Algebra.Field<Float>` | `0.0` | `1.0` | Same caveats, lower precision. |
| `Float16` | Approximate field (platform-conditional) | `Algebra.Field<Float16>` | `0.0` | `1.0` | Same caveats, very low precision. Platform-conditional availability. |

### Decomposed Sub-Witnesses

Each top-level witness is composed of sub-witnesses. These SHOULD also be available independently:

| Sub-Witness | Types | Witness Type | Description |
|-------------|-------|-------------|-------------|
| Additive abelian group | `Int`, `Int8`..`Int64` | `Algebra.Group.Abelian<IntN>` | `(Z/2^n Z, &+, 0, &-)` |
| Additive commutative monoid | `UInt`, `UInt8`..`UInt64` | `Algebra.Monoid.Commutative<UIntN>` | `(Z/2^n Z, &+, 0)` |
| Additive abelian group | `Double`, `Float`, `Float16` | `Algebra.Group.Abelian<T>` | `(T, +, 0, -)` with IEEE 754 semantics |
| Multiplicative commutative monoid | All numeric types | `Algebra.Monoid.Commutative<T>` | `(T, &*, 1)` or `(T, *, 1)` |
| Multiplicative monoid | All numeric types | `Algebra.Monoid<T>` | Same (commutativity just adds the documented invariant) |
| GCD commutative monoid | `BinaryInteger` types | `Algebra.Monoid.Commutative<T>` | `(N, gcd, 0)` where gcd(a, 0) = a |
| LCM commutative monoid | `BinaryInteger` types | `Algebra.Monoid.Commutative<T>` | `(N, lcm, 1)` where lcm(a, 1) = a |
| Min commutative monoid | Signed integers | `Algebra.Monoid.Commutative<T>` | `(T, min, .max)` |
| Max commutative monoid | Signed integers | `Algebra.Monoid.Commutative<T>` | `(T, max, .min)` |
| Bitwise AND monoid | Fixed-width integers | `Algebra.Monoid.Commutative<T>` | `(T, &, ~0)` |
| Bitwise OR monoid | Fixed-width integers | `Algebra.Monoid.Commutative<T>` | `(T, |, 0)` |
| Bitwise XOR abelian group | Fixed-width integers | `Algebra.Group.Abelian<T>` | `(T, ^, 0, id)` where each element is self-inverse |

---

## Code Sketches

### Witness: `Algebra.Ring.Commutative<Int>` (and other signed integers)

```swift
// File: Algebra.Ring.Commutative+Int.swift
// In: swift-algebra-primitives/Sources/Algebra Primitives/

import Algebra_Ring_Primitives

extension Algebra.Ring.Commutative where Element == Int {
    /// The commutative ring (Z/2^64 Z, &+, &*, 0, 1) with wrapping arithmetic.
    ///
    /// Uses wrapping operators (`&+`, `&*`, `&-`) to ensure closure.
    /// Standard `+`, `*`, `-` would trap on overflow, violating totality.
    ///
    /// ## Caveats
    ///
    /// This is the ring of integers modulo 2^64 (on 64-bit platforms),
    /// NOT the ring of mathematical integers Z. Overflow wraps silently.
    @inlinable
    public static var wrapping: Self {
        .init(ring: .init(
            additive: .init(group: .init(
                identity: 0,
                combining: { $0 &+ $1 },
                inverting: { 0 &- $0 }
            )),
            multiplicative: .init(
                identity: 1,
                combining: { $0 &* $1 }
            )
        ))
    }
}
```

The same pattern applies to `Int8`, `Int16`, `Int32`, `Int64`, each with their respective type.

**Generic variant** (for all `SignedInteger & FixedWidthInteger`):

```swift
// File: Algebra.Ring.Commutative+SignedInteger.swift

extension Algebra.Ring {
    /// Constructs a commutative ring with wrapping arithmetic for any
    /// signed fixed-width integer type.
    @inlinable
    public static func wrapping<T: SignedInteger & FixedWidthInteger>(
        _: T.Type
    ) -> Algebra.Ring.Commutative<T> {
        .init(ring: .init(
            additive: .init(group: .init(
                identity: 0,
                combining: { $0 &+ $1 },
                inverting: { 0 &- $0 }
            )),
            multiplicative: .init(
                identity: 1,
                combining: { $0 &* $1 }
            )
        ))
    }
}
```

### Witness: `Algebra.Semiring<UInt>` (and other unsigned integers)

```swift
// File: Algebra.Semiring+UInt.swift

import Algebra_Semiring_Primitives

extension Algebra.Semiring where Element == UInt {
    /// The commutative semiring (Z/2^64 Z, &+, &*, 0, 1) with wrapping arithmetic.
    ///
    /// Unsigned integers have no additive inverse, so this is a semiring
    /// (not a ring). Uses wrapping operators for totality.
    @inlinable
    public static var wrapping: Self {
        .init(
            additive: .init(monoid: .init(
                identity: 0,
                combining: { $0 &+ $1 }
            )),
            multiplicative: .init(
                identity: 1,
                combining: { $0 &* $1 }
            )
        )
    }
}
```

**Generic variant:**

```swift
extension Algebra.Semiring {
    @inlinable
    public static func wrapping<T: UnsignedInteger & FixedWidthInteger>(
        _: T.Type
    ) -> Algebra.Semiring<T> {
        .init(
            additive: .init(monoid: .init(
                identity: 0,
                combining: { $0 &+ $1 }
            )),
            multiplicative: .init(
                identity: 1,
                combining: { $0 &* $1 }
            )
        )
    }
}
```

### Witness: `Algebra.Field<Double>` (and Float, Float16)

```swift
// File: Algebra.Field+Double.swift

import Algebra_Field_Primitives

extension Algebra.Field where Element == Double {
    /// The approximate field (Double, +, *, 0, 1) with IEEE 754 arithmetic.
    ///
    /// ## Caveats
    ///
    /// IEEE 754 floating-point arithmetic does NOT satisfy the field axioms exactly:
    /// - **Addition is not associative**: `(a + b) + c != a + (b + c)` in general
    /// - **Multiplication is not associative**: `(a * b) * c != a * (b * c)` in general
    /// - **Distributivity fails**: `a * (b + c) != a*b + a*c` in general
    /// - **NaN poisons**: `NaN + x = NaN` for all x (identity law fails for NaN)
    /// - **Negative zero**: `-0.0 + 0.0 = 0.0` but `-0.0 != 0.0` under some comparisons
    ///
    /// For "ordinary" values far from overflow/underflow boundaries, the laws
    /// hold approximately. This witness uses `==` comparison, which treats
    /// `-0.0 == 0.0` (true) and `NaN != NaN` (true).
    ///
    /// The reciprocal operation throws `.nonInvertible` for zero.
    @inlinable
    public static var ieee754: Self {
        .init(
            additive: .init(group: .init(
                identity: 0.0,
                combining: { $0 + $1 },
                inverting: { -$0 }
            )),
            multiplicative: .init(monoid: .init(
                identity: 1.0,
                combining: { $0 * $1 }
            )),
            reciprocal: { element throws(Error) in
                guard element != 0.0 else { throw .nonInvertible }
                return 1.0 / element
            }
        )
    }
}
```

The same pattern for `Float` and `Float16` (platform-conditional).

**Generic variant:**

```swift
extension Algebra.Field {
    /// Constructs an approximate field for any `FloatingPoint` type.
    @inlinable
    public static func ieee754<T: FloatingPoint & Sendable>(
        _: T.Type
    ) -> Algebra.Field<T> {
        .init(
            additive: .init(group: .init(
                identity: .zero,
                combining: { $0 + $1 },
                inverting: { -$0 }
            )),
            multiplicative: .init(monoid: .init(
                identity: T(1),
                combining: { $0 * $1 }
            )),
            reciprocal: { element throws(Error) in
                guard element != .zero else { throw .nonInvertible }
                return T(1) / element
            }
        )
    }
}
```

### Witness: `Algebra.Group.Abelian` for Additive Groups

```swift
// File: Algebra.Group.Abelian+Int.swift

import Algebra_Group_Primitives

extension Algebra.Group.Abelian where Element == Int {
    /// The additive abelian group (Int, &+, 0, &-) with wrapping arithmetic.
    @inlinable
    public static var additive: Self {
        .init(group: .init(
            identity: 0,
            combining: { $0 &+ $1 },
            inverting: { 0 &- $0 }
        ))
    }
}

extension Algebra.Group.Abelian where Element == Double {
    /// The additive abelian group (Double, +, 0.0, -) with IEEE 754 arithmetic.
    @inlinable
    public static var additive: Self {
        .init(group: .init(
            identity: 0.0,
            combining: { $0 + $1 },
            inverting: { -$0 }
        ))
    }
}
```

### Witness: `Algebra.Monoid` for Multiplicative Monoids

```swift
// File: Algebra.Monoid.Commutative+Multiplicative.swift

import Algebra_Monoid_Primitives

extension Algebra.Monoid.Commutative where Element == Int {
    /// The multiplicative commutative monoid (Int, &*, 1) with wrapping arithmetic.
    @inlinable
    public static var multiplicative: Self {
        .init(monoid: .init(
            identity: 1,
            combining: { $0 &* $1 }
        ))
    }
}

extension Algebra.Monoid.Commutative where Element == Double {
    /// The multiplicative commutative monoid (Double, *, 1.0) with IEEE 754 arithmetic.
    @inlinable
    public static var multiplicative: Self {
        .init(monoid: .init(
            identity: 1.0,
            combining: { $0 * $1 }
        ))
    }
}
```

### Witness: GCD Commutative Monoid

**Assessment**: GCD forms a commutative monoid with identity 0.

**Proof:**
- **Closure**: gcd(a, b) is always a non-negative integer when a, b are non-negative integers.
- **Associativity**: gcd(gcd(a, b), c) = gcd(a, gcd(b, c)) = gcd(a, b, c). This is a standard result.
- **Commutativity**: gcd(a, b) = gcd(b, a). Immediate from definition.
- **Identity**: gcd(a, 0) = gcd(0, a) = a. Since every integer divides 0, the greatest common divisor of a and 0 is a.

```swift
// File: Algebra.Monoid.Commutative+GCD.swift

import Algebra_Monoid_Primitives

extension Algebra.Monoid.Commutative where Element == Int {
    /// The GCD commutative monoid (non-negative Int, gcd, 0).
    ///
    /// gcd(a, 0) = a for all a (identity).
    /// gcd(a, b) = gcd(b, a) (commutativity).
    /// gcd(gcd(a, b), c) = gcd(a, gcd(b, c)) (associativity).
    ///
    /// Operates on magnitudes: gcd(-6, 4) = 2.
    @inlinable
    public static var gcd: Self {
        .init(monoid: .init(
            identity: 0,
            combining: { a, b in
                var x = a < 0 ? -a : a
                var y = b < 0 ? -b : b
                while y != 0 {
                    let t = y
                    y = x % y
                    x = t
                }
                return x
            }
        ))
    }
}
```

### Witness: LCM Commutative Monoid

**Assessment**: LCM forms a commutative monoid with identity 1.

**Proof:**
- **Closure**: lcm(a, b) is always a non-negative integer when a, b are positive integers.
- **Associativity**: lcm(lcm(a, b), c) = lcm(a, lcm(b, c)). Standard result from the lattice structure of divisibility.
- **Commutativity**: lcm(a, b) = lcm(b, a). Immediate from definition.
- **Identity**: lcm(a, 1) = lcm(1, a) = a. Since 1 divides every integer, the least common multiple of a and 1 is a.

**Note**: lcm(a, 0) = 0 for all a, making 0 an **absorbing element** (annihilator), not the identity. The identity is 1.

```swift
// File: Algebra.Monoid.Commutative+LCM.swift

import Algebra_Monoid_Primitives

extension Algebra.Monoid.Commutative where Element == Int {
    /// The LCM commutative monoid (non-negative Int, lcm, 1).
    ///
    /// lcm(a, 1) = a for all a (identity).
    /// lcm(a, b) = lcm(b, a) (commutativity).
    /// lcm(lcm(a, b), c) = lcm(a, lcm(b, c)) (associativity).
    ///
    /// Note: lcm(a, 0) = 0 (absorbing element), so this monoid is
    /// well-defined only on positive integers if absorption is undesired.
    @inlinable
    public static var lcm: Self {
        func gcd(_ a: Int, _ b: Int) -> Int {
            var x = a < 0 ? -a : a
            var y = b < 0 ? -b : b
            while y != 0 { let t = y; y = x % y; x = t }
            return x
        }
        return .init(monoid: .init(
            identity: 1,
            combining: { a, b in
                let absA = a < 0 ? -a : a
                let absB = b < 0 ? -b : b
                if absA == 0 || absB == 0 { return 0 }
                return absA / gcd(absA, absB) * absB
            }
        ))
    }
}
```

### Witness: Bitwise XOR Abelian Group

```swift
// File: Algebra.Group.Abelian+XOR.swift

import Algebra_Group_Primitives

extension Algebra.Group.Abelian where Element == UInt {
    /// The bitwise XOR abelian group (UInt, ^, 0).
    ///
    /// Every element is its own inverse: a ^ a = 0.
    @inlinable
    public static var xor: Self {
        .init(group: .init(
            identity: 0,
            combining: { $0 ^ $1 },
            inverting: { $0 }  // self-inverse
        ))
    }
}
```

### Witness: Min/Max Monoids

```swift
// File: Algebra.Monoid.Commutative+MinMax.swift

import Algebra_Monoid_Primitives

extension Algebra.Monoid.Commutative where Element == Int {
    /// The min commutative monoid (Int, min, .max).
    @inlinable
    public static var min: Self {
        .init(monoid: .init(
            identity: .max,
            combining: { Swift.min($0, $1) }
        ))
    }

    /// The max commutative monoid (Int, max, .min).
    @inlinable
    public static var max: Self {
        .init(monoid: .init(
            identity: .min,
            combining: { Swift.max($0, $1) }
        ))
    }
}
```

### Witness: Bitwise AND/OR Monoids

```swift
// File: Algebra.Monoid.Commutative+Bitwise.swift

import Algebra_Monoid_Primitives

extension Algebra.Monoid.Commutative where Element == UInt {
    /// The bitwise AND commutative monoid (UInt, &, ~0).
    @inlinable
    public static var and: Self {
        .init(monoid: .init(
            identity: ~0,
            combining: { $0 & $1 }
        ))
    }

    /// The bitwise OR commutative monoid (UInt, |, 0).
    @inlinable
    public static var or: Self {
        .init(monoid: .init(
            identity: 0,
            combining: { $0 | $1 }
        ))
    }
}
```

---

## GCD and LCM: Deeper Algebraic Analysis

### GCD/LCM Form a Bounded Distributive Lattice

On the non-negative integers, GCD and LCM together form a distributive lattice:

- **Meet**: gcd (greatest lower bound in divisibility order)
- **Join**: lcm (least upper bound in divisibility order)
- **Distributivity**: gcd(a, lcm(b, c)) = lcm(gcd(a, b), gcd(a, c)) and lcm(a, gcd(b, c)) = gcd(lcm(a, b), lcm(a, c))
- **Absorption**: gcd(a, lcm(a, b)) = a and lcm(a, gcd(a, b)) = a

This is a well-known result from number theory. The divisibility poset of positive integers is a distributive lattice.

### Relationship to Existing Numeric Operations

The GCD and LCM implementations in `Integer Primitives` (`BinaryInteger+GCD.swift`) are correct and complete. However, they live in a Tier 1 package. The algebraic witnesses would reimplement the same algorithms (trivially) in Tier 12, which is acceptable because:
1. The Euclidean algorithm is ~5 lines of code
2. No attribution/duplication concern -- it is a fundamental algorithm
3. The witness wraps the algorithm; the algorithm is not the point

---

## Handling the Imprecision Caveat

### Integer Overflow

**Problem**: Swift's `+`, `*`, `-` trap on overflow. Algebraic operations must be total (closed under the operation).

**Solution**: Use wrapping operators `&+`, `&*`, `&-`. These are total and form exact rings/semirings modulo 2^n. The witnesses MUST document that they model Z/2^n Z, not Z.

**Named accordingly**: The static property is named `.wrapping` to make the choice explicit.

### Floating-Point Rounding

**Problem**: IEEE 754 arithmetic violates associativity, distributivity, and (for NaN/Inf) identity laws.

**Solution**: Document caveats exhaustively. The witnesses are named `.ieee754` to signal approximate semantics. Law verification harnesses (`Algebra.Law.*`) will detect violations when tested with pathological values (NaN, Inf, very large/small values).

**Practical guidance**: For law verification, test with "ordinary" values (e.g., small integers cast to Double) where the laws hold exactly, and document that pathological values are excluded from the algebraic contract.

### Negative Zero

**Problem**: IEEE 754 has -0.0 and +0.0 which are equal under `==` but distinct under `===` and `isNegative`.

**Solution**: The witness uses `==` (which treats -0.0 == 0.0), so the identity law `0 + a == a` holds for both -0.0 and +0.0. The `inverting` closure `{ -$0 }` maps +0.0 to -0.0, but since -0.0 == 0.0 under `==`, the inverse law `a + (-a) == 0` holds.

### NaN

**Problem**: NaN != NaN under IEEE 754, so `a + 0 == a` fails when a is NaN (because NaN != NaN).

**Solution**: Document that NaN is outside the algebraic contract. Witnesses operate on the subset of floating-point values excluding NaN. This mirrors mathematical convention where algebraic structures are defined on sets, and NaN is not a real number.

---

## Package.swift Changes

### No Changes to swift-numeric-primitives

swift-numeric-primitives remains at Tier 1 with its current dependencies. **No algebra dependency is added.**

### Changes to swift-algebra-primitives

The `Algebra Primitives` target gains new source files. No new targets or dependencies are needed because the witnesses only use stdlib operations.

```swift
// No changes to Package.swift structure needed.
// New .swift files are added to Sources/Algebra Primitives/:
//
//   Algebra.Ring.Commutative+Int.swift
//   Algebra.Ring.Commutative+Int8.swift
//   Algebra.Ring.Commutative+Int16.swift
//   Algebra.Ring.Commutative+Int32.swift
//   Algebra.Ring.Commutative+Int64.swift
//   Algebra.Semiring+UInt.swift
//   Algebra.Semiring+UInt8.swift
//   Algebra.Semiring+UInt16.swift
//   Algebra.Semiring+UInt32.swift
//   Algebra.Semiring+UInt64.swift
//   Algebra.Field+Double.swift
//   Algebra.Field+Float.swift
//   Algebra.Field+Float16.swift
//   Algebra.Group.Abelian+Int.swift      (additive)
//   Algebra.Group.Abelian+Double.swift   (additive)
//   Algebra.Monoid.Commutative+GCD.swift
//   Algebra.Monoid.Commutative+LCM.swift
//   Algebra.Monoid.Commutative+MinMax.swift
//   Algebra.Monoid.Commutative+Bitwise.swift
//   Algebra.Group.Abelian+XOR.swift
```

**Alternatively**, generic factory methods can reduce file count:

```
Algebra.Ring.Commutative+SignedInteger.swift    (generic + concrete type aliases)
Algebra.Semiring+UnsignedInteger.swift          (generic + concrete type aliases)
Algebra.Field+FloatingPoint.swift               (generic + concrete type aliases)
Algebra.Monoid.Commutative+GCD.swift
Algebra.Monoid.Commutative+LCM.swift
Algebra.Monoid.Commutative+MinMax.swift
Algebra.Monoid.Commutative+Bitwise.swift
Algebra.Group.Abelian+XOR.swift
```

The [API-IMPL-005] one-type-per-file rule applies to type *declarations*, not extensions. Extension files for witnesses on existing types are standard practice in the codebase (see `Algebra.Field+Parity.swift`).

---

## Target(s) to Host the Witnesses

**Primary target**: `Algebra Primitives` (the aggregation target in swift-algebra-primitives).

**Rationale**: This target already:
- Depends on all algebra sub-targets (Ring, Field, Group, Monoid, Semiring)
- Contains concrete witnesses (`Algebra.Field+Parity.swift`, `Algebra.Field+Z2.swift`)
- Is the recommended import for users who want "everything"

**Alternative considered**: A new `Algebra Numeric Witnesses` target within swift-algebra-primitives. Rejected because it adds unnecessary target proliferation for witnesses that are simple extensions.

---

## What Should NOT Be Refactored in numeric-primitives

The following operations in numeric-primitives are **orthogonal to algebraic structure** and should remain unchanged:

| Operation | Package/Target | Reason to Keep |
|-----------|---------------|----------------|
| Transcendental functions | Real Primitives | Not algebraic (transcendental by definition) |
| Rounding modes | Numeric Primitives | Operational concern, not algebraic |
| Approximate equality | Numeric Primitives | Comparison utility, not algebraic |
| Augmented arithmetic | Real Primitives | Error-free transforms, numerical analysis |
| Relaxed arithmetic | Real Primitives | Optimization concern, not algebraic |
| Bit rotation | Integer Primitives | Computational operation, not algebraic |
| Division with rounding | Integer Primitives | Enriched division, not basic ring structure |
| Saturating arithmetic | Integer Primitives | Alternative arithmetic, not standard ring |
| Right shift with rounding | Integer Primitives | Enriched shift, not algebraic |
| Fraction | Real Primitives | Compile-time fraction, not algebraic |
| Quantized | Numeric Primitives | Discretization, not algebraic |

**GCD and LCM** (`BinaryInteger+GCD.swift`) remain in Integer Primitives as computational utilities. The algebraic witnesses in algebra-primitives provide *algebraic framing* of the same operations.

---

## Test Strategy

### Law Verification Tests

Each witness should be tested using `Algebra.Law.*` harnesses:

```swift
// In: swift-algebra-primitives/Tests/Algebra Primitives Tests/

import Testing
import Algebra_Primitives

@Test func intCommutativeRingLaws() {
    let ring = Algebra.Ring.Commutative<Int>.wrapping
    let elements: [Int] = [-2, -1, 0, 1, 2, 3, 100, .min, .max]

    // Additive group laws
    #expect(Algebra.Law.Identity.left(of: ring.ring.additive.group, over: elements) == nil)
    #expect(Algebra.Law.Identity.right(of: ring.ring.additive.group, over: elements) == nil)
    #expect(Algebra.Law.Associativity.verify(of: ring.ring.additive.group, over: elements) == nil)
    #expect(Algebra.Law.Commutativity.verify(of: ring.ring.additive.group, over: elements) == nil)
    #expect(Algebra.Law.Inverse.left(of: ring.ring.additive.group, over: elements) == nil)
    #expect(Algebra.Law.Inverse.right(of: ring.ring.additive.group, over: elements) == nil)

    // Multiplicative monoid laws
    #expect(Algebra.Law.Identity.left(of: ring.ring.multiplicative, over: elements) == nil)
    #expect(Algebra.Law.Identity.right(of: ring.ring.multiplicative, over: elements) == nil)
    #expect(Algebra.Law.Associativity.verify(of: ring.ring.multiplicative, over: elements) == nil)
    #expect(Algebra.Law.Commutativity.verify(of: ring.ring.multiplicative, over: elements) == nil)

    // Distributivity (wrapping arithmetic makes this exact)
    #expect(Algebra.Law.Distributivity.left(of: ring.ring, over: elements) == nil)
    #expect(Algebra.Law.Distributivity.right(of: ring.ring, over: elements) == nil)
}

@Test func doubleFieldLaws() {
    let field = Algebra.Field<Double>.ieee754
    // Use small integers to avoid rounding issues
    let elements: [Double] = [-3, -2, -1, 0, 0.5, 1, 2, 3]

    #expect(Algebra.Law.Identity.left(of: field.additive.group, over: elements) == nil)
    #expect(Algebra.Law.Associativity.verify(of: field.additive.group, over: elements) == nil)
}

@Test func gcdMonoidLaws() {
    let m = Algebra.Monoid.Commutative<Int>.gcd
    let elements: [Int] = [0, 1, 2, 3, 4, 6, 12, 15, 24, 36]

    #expect(Algebra.Law.Identity.left(of: m.monoid, over: elements) == nil)
    #expect(Algebra.Law.Identity.right(of: m.monoid, over: elements) == nil)
    #expect(Algebra.Law.Associativity.verify(of: m.monoid, over: elements) == nil)
    #expect(Algebra.Law.Commutativity.verify(of: m.monoid, over: elements) == nil)
}
```

### Overflow Boundary Tests

Specifically test that wrapping witnesses handle boundary values correctly:

```swift
@Test func wrappingRingOverflowBehavior() {
    let ring = Algebra.Ring.Commutative<Int8>.wrapping

    // Wrapping addition at boundary
    #expect(ring.adding(127, 1) == -128)  // wraps
    #expect(ring.adding(-128, -1) == 127)  // wraps

    // Wrapping multiplication at boundary
    #expect(ring.multiplying(127, 2) == -2)  // wraps

    // Negation at boundary
    #expect(ring.negating(-128) == -128)  // wraps (two's complement)
}
```

---

## Summary of Recommendations

1. **Do NOT add algebra-primitives as a dependency of numeric-primitives.** The tier architecture (Tier 1 vs Tier 12) forbids it.

2. **Add algebraic witnesses for standard numeric types to the `Algebra Primitives` target in swift-algebra-primitives.** This follows existing precedent and requires no new packages or targets.

3. **Provide both concrete type-specific witnesses and generic factory methods** for maximum usability.

4. **Name witnesses explicitly**: `.wrapping` for integer witnesses (signals modular arithmetic), `.ieee754` for floating-point witnesses (signals approximate semantics).

5. **Document all caveats exhaustively**: overflow behavior for integers, rounding/NaN/Inf for floats.

6. **Implement GCD/LCM monoid witnesses directly** in algebra-primitives (the algorithms are trivial and need only stdlib operations).

7. **Provide sub-witnesses independently**: additive groups, multiplicative monoids, GCD monoids, LCM monoids, bitwise monoids, XOR groups, min/max monoids.

8. **Verify all witnesses with law verification harnesses** from `Algebra Law Primitives`.

9. **Leave numeric-primitives unchanged.** Its operations (transcendentals, rounding, saturating arithmetic, augmented arithmetic) are orthogonal to algebraic structure.

## References

- Haskell Numeric Hierarchy: https://wiki.haskell.org/Numeric_Haskell
- Rust num-traits: https://docs.rs/num-traits/
- IEEE 754-2019: https://ieeexplore.ieee.org/document/8766229
- Ring (mathematics): https://en.wikipedia.org/wiki/Ring_(mathematics)
- Semiring: https://en.wikipedia.org/wiki/Semiring
- Field (mathematics): https://en.wikipedia.org/wiki/Field_(mathematics)
- Distributive lattice (GCD/LCM): https://en.wikipedia.org/wiki/Distributive_lattice
- Two's complement ring: https://en.wikipedia.org/wiki/Two%27s_complement
