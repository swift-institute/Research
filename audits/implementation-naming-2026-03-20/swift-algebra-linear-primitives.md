# swift-algebra-linear-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation [IMPL-*], naming [API-NAME-*]
**Scope**: All `.swift` files in `Sources/`

---

## Summary Table

| ID | Severity | Requirement | File | Title |
|----|----------|-------------|------|-------|
| LIN-001 | LOW | [API-NAME-002] | Linear.Vector.swift:168 | `lengthSquared` compound property |
| LIN-002 | LOW | [API-NAME-002] | Linear.Vector.swift:156 | `lengthSquared` compound static method |
| LIN-003 | LOW | [API-NAME-002] | Linear.Vector+Real.swift:56 | `signedAngle` compound method |
| LIN-004 | LOW | [API-NAME-002] | Linear.Matrix.swift:352 | `rotationAngle` compound property |
| LIN-005 | LOW | [API-NAME-002] | Linear.Matrix.swift:370 | `scaleFactors` compound property |
| LIN-006 | LOW | [API-NAME-002] | Linear.Matrix.swift:221 | `isInvertible` compound property |
| LIN-007 | LOW | [API-NAME-002] | Linear.Vector.swift:68-74 | `Vector2`/`Vector3`/`Vector4` compound typealiases |
| LIN-008 | LOW | [API-NAME-002] | Linear.Matrix.swift:84-90 | `Matrix2x2`/`Matrix3x3`/`Matrix4x4` compound typealiases |
| LIN-009 | MEDIUM | [PATTERN-017] | Linear.Vector.swift:189 | `.rawValue` at call site in `normalized` |
| LIN-010 | MEDIUM | [PATTERN-017] | Linear.Vector.swift:260 | `.rawValue` at call site in `distance` |
| LIN-011 | INFO | [PATTERN-017] | Linear.Vector.swift:277,284,290,323,330,337,343,349,390,397,404,411,417,423 | `.rawValue` in property getters/setters and typed inits (boundary-correct) |
| LIN-012 | INFO | [PATTERN-017] | Linear.Vector.swift:363-368 | `.rawValue` in 3D cross product intermediate extraction (boundary-correct) |
| LIN-013 | INFO | [IMPL-002] | Linear.Vector.swift:370-372 | `__unchecked` in 3D cross product result construction (boundary-correct) |
| LIN-014 | INFO | [PATTERN-017] | Linear+Arithmatic.swift:129-131 | `.rawValue` in 2x2 matrix-vector multiply (boundary-correct) |
| LIN-015 | INFO | [PATTERN-017] | Linear+Arithmatic.swift:270,287 | `.rawValue` in free-function dot/cross products (boundary-correct) |
| LIN-016 | INFO | [IMPL-002] | Linear.Vector.swift:175,276,283,322,329,336,389,396,403,410 | `__unchecked` in property getters and length construction (boundary-correct) |
| LIN-017 | INFO | [IMPL-002] | Linear.Vector+Real.swift:25,32,73 | `__unchecked` in unit/polar/rotated constructions (boundary-correct) |
| LIN-018 | INFO | [IMPL-002] | Linear.Matrix.swift:353 | `__unchecked` in rotationAngle construction (boundary-correct) |
| LIN-019 | INFO | [IMPL-002] | Linear.Vector+Real.swift:57 | `__unchecked` + `.rawValue` in signedAngle (boundary-correct) |
| LIN-020 | MEDIUM | [API-NAME-002] | Linear+Arithmatic.swift:1 | Filename misspelling: "Arithmatic" should be "Arithmetic" |
| LIN-021 | INFO | [API-IMPL-005] | Linear+Formatting.swift | Extension on `Tagged` (not a Linear type) — acceptable as domain integration file |

**Totals**: 0 CRITICAL, 0 HIGH, 3 MEDIUM, 8 LOW, 10 INFO (boundary-correct)

---

## Classification Methodology

This package bridges between raw `InlineArray<N, Scalar>` storage (the internal vector representation) and typed `Tagged<Displacement.X<Space>, Scalar>` component accessors. Every `.rawValue` and `__unchecked` usage falls into one of two categories:

1. **Boundary code** (operator definitions, typed property accessors, factory methods): These are the typed-to-raw bridge points. `.rawValue` extraction and `__unchecked` construction are the *correct* pattern here — they define the boundary.

2. **Call-site code** (methods that compose higher-level operations from typed components): These should use typed arithmetic where available, not `.rawValue`.

---

## Findings

### LIN-001 / LIN-002: `lengthSquared` compound name [LOW]

**File**: `Linear.Vector.swift:156,168`
**Requirement**: [API-NAME-002]

```swift
public static func lengthSquared(_ vector: Self) -> Scalar { ... }
public var lengthSquared: Scalar { ... }
```

The name `lengthSquared` is a compound identifier. Under [API-NAME-002], this should use a nested accessor pattern like `length.squared` or a static form like `Length.squared(_:)`. However, `lengthSquared` is a universally recognized mathematical term (SIMD, Metal, GLM all use it), and the result type is `Scalar` not `Length`, so the nesting would be misleading. **Pragmatic pass** — flag for awareness.

### LIN-003: `signedAngle` compound method [LOW]

**File**: `Linear.Vector+Real.swift:56`
**Requirement**: [API-NAME-002]

```swift
public static func signedAngle(_ lhs: Self, to rhs: Self) -> Radian<Scalar>
```

Could be `angle.signed(_:to:)` under strict naming, but `signedAngle` mirrors standard graphics API convention and the `angle(_:to:)` / `signedAngle(_:to:)` pair reads naturally. **Pragmatic pass**.

### LIN-004: `rotationAngle` compound property [LOW]

**File**: `Linear.Matrix.swift:352`
**Requirement**: [API-NAME-002]

```swift
public static func rotationAngle(_ matrix: Self) -> Radian<Scalar>
```

Could be `rotation.angle` as a nested accessor. The matrix type already has factory methods like `.rotation(_:)`, so a decomposition namespace `rotation.angle` would be consistent. **Candidate for improvement**.

### LIN-005: `scaleFactors` compound property [LOW]

**File**: `Linear.Matrix.swift:370`
**Requirement**: [API-NAME-002]

```swift
public static func scaleFactors(_ matrix: Self) -> (x: Scalar, y: Scalar)
```

Could be `scale.factors` as a nested accessor. Similar to LIN-004 — the matrix has `scale(_:)` factory, so `scale.factors` would mirror it. **Candidate for improvement**.

### LIN-006: `isInvertible` compound property [LOW]

**File**: `Linear.Matrix.swift:221`
**Requirement**: [API-NAME-002]

`isInvertible` follows the Swift API Design Guidelines `is`-prefix convention for Boolean properties. This is a tension between [API-NAME-002] and Swift standard convention. The stdlib uses `isEmpty`, `isZero`, `isFinite` — all compound. **Pragmatic pass**.

### LIN-007 / LIN-008: Compound typealiases [LOW]

**Files**: `Linear.Vector.swift:68-74`, `Linear.Matrix.swift:84-90`
**Requirement**: [API-NAME-002]

```swift
public typealias Vector2 = Vector<2>
public typealias Matrix2x2 = Matrix<2, 2>
```

These are convenience typealiases, not types. The actual types (`Vector<2>`, `Matrix<2, 2>`) conform to [API-NAME-001]. The typealiases provide ergonomic shortcuts (`Linear<Double, Void>.Vector2` vs `Linear<Double, Void>.Vector<2>`). Since value generics are new and `<2>` may not always be inferrable, these are defensible. **Pragmatic pass**.

### LIN-009: `.rawValue` in `normalized` [MEDIUM]

**File**: `Linear.Vector.swift:189`
**Requirement**: [PATTERN-017]

```swift
public static func normalized(_ vector: Self) -> Self {
    let len = length(vector).rawValue   // <- .rawValue leak
    guard len > 0 else { return .zero }
    return vector / len
}
```

The `length(_:)` returns `Linear.Length` (a `Tagged<Magnitude<Space>, Scalar>`). The `.rawValue` extraction happens because the internal `vector / len` divides by raw `Scalar`. This is a call-site leak — the division should use the typed `Vector / Scale` or `Vector / Length` operator. Two possible fixes:

1. Add a `Vector / Length -> Vector` operator that strips the magnitude tag, or
2. Use `vector * Scale(1 / len.rawValue)` which keeps `.rawValue` in Scale boundary code.

Fix (2) keeps rawValue but moves it into a Scale construction — a typed boundary. Fix (1) would be a new typed arithmetic overload.

### LIN-010: `.rawValue` in `distance` [MEDIUM]

**File**: `Linear.Vector.swift:260`
**Requirement**: [PATTERN-017]

```swift
public static func distance(_ lhs: Self, to rhs: Self) -> Linear.Distance {
    Linear.Distance(__unchecked: (), length(lhs - rhs).rawValue)
}
```

`length(lhs - rhs)` returns `Linear.Length`, which is `Tagged<Magnitude<Space>, Scalar>`. `Linear.Distance` is also `Tagged<Magnitude<Space>, Scalar>` — they are the *same type*. This `.rawValue` + `__unchecked` round-trip is a no-op identity retagging. The entire body can simply be:

```swift
length(lhs - rhs)
```

Since `Length`, `Distance`, `Radius`, `Diameter` are all typealiases for `Magnitude<Space>.Value<Scalar>`, this `.rawValue` extraction and reconstruction is redundant. **Clear improvement opportunity**.

### LIN-011: `.rawValue` in property getters/setters [INFO — BOUNDARY-CORRECT]

**File**: `Linear.Vector.swift` (14 occurrences)

All `.rawValue` usages in the `dx`/`dy`/`dz`/`dw` property setters and typed initializers are boundary code. These are the bridge between untyped `InlineArray<N, Scalar>` storage and typed `Tagged<Displacement.X<Space>, Scalar>` accessors. The pattern is:

```swift
// Getter: raw component -> typed displacement
get { Linear.Dx(__unchecked: (), components[0]) }

// Setter: typed displacement -> raw component
set { components[0] = newValue.rawValue }

// Init: typed displacements -> raw array
self.init([dx.rawValue, dy.rawValue, dz.rawValue])
```

This is exactly [PATTERN-017]'s intent: `.rawValue` confined to boundary code. **No action needed.**

### LIN-012: `.rawValue` in 3D cross product [INFO — BOUNDARY-CORRECT]

**File**: `Linear.Vector.swift:363-368`

```swift
let lx = lhs.dx.rawValue
let ly = lhs.dy.rawValue
...
```

The 3D cross product extracts raw values to perform mixed-axis arithmetic (`ly * rz - lz * ry`), then re-wraps as `__unchecked`. This is boundary code — the computation crosses dimension tags (X, Y, Z mix freely), and no typed arithmetic exists for `Dy * Dz -> Dx`. The result is `Self` (a vector), not an `Area`, so the dimension semantics are already approximate (as noted in the doc comment: "dimensionally it's Length squared (a bivector)"). **Correctly classified as boundary.**

### LIN-013 through LIN-019: `__unchecked` constructions [INFO — BOUNDARY-CORRECT]

All 20 `__unchecked` constructions are in operator definitions, typed property getters, or factory methods. These are the boundary points where raw scalar results are tagged with their dimensional meaning. Every usage correctly produces a `Tagged` wrapper for a computed scalar value. **No action needed.**

### LIN-020: Filename misspelling [MEDIUM]

**File**: `Linear+Arithmatic.swift`

The filename uses "Arithmatic" — the correct spelling is "Arithmetic". This is a consistent misspelling also found in `Tagged+Arithmatic.swift` in dimension-primitives, suggesting it was propagated from an upstream template. The spelling does not affect compilation but reduces searchability and professionalism.

### LIN-021: `Tagged` extension in Linear package [INFO]

**File**: `Linear+Formatting.swift`

This file extends `Tagged` (from identity-primitives), not a Linear type. It adds `.formatted(_:)` to any `Tagged` value with `BinaryFloatingPoint` raw values. This is a domain integration extension — acceptable as the package provides the formatting bridge for its own type ecosystem. No [API-IMPL-005] violation since it's an extension, not a type declaration.

---

## 2D Cross Product: Typed Arithmetic Success

The 2D cross product at `Linear.Vector.swift:302-303` uses fully typed arithmetic:

```swift
lhs.dx * rhs.dy - lhs.dy * rhs.dx
```

This leverages dimension-primitives' typed operators:
- `Dx * Dy -> Area` (cross-axis displacement product)
- `Dy * Dx -> Area` (commutative)
- `Area - Area -> Area` (same-type subtraction)

The return type is `Linear.Area` = `Area<Space>.Value<Scalar>`. This is a model example of [IMPL-002] typed arithmetic. **No `.rawValue` needed.**

---

## Architecture Assessment

The package's boundary design is clean. The core tension is:

1. **Vector stores raw scalars** (`InlineArray<N, Scalar>`), but exposes **typed component accessors** (`dx: Linear.Dx`). This means every property getter/setter is a boundary crossing, and `.rawValue`/`__unchecked` are structurally required.

2. **N-dimensional operations** (`+`, `-`, dot, `lengthSquared`) work on raw `components[i]` because there is no typed representation for an arbitrary component in an N-dimensional vector. This is correct — the type safety lives at the named-component level (2D/3D/4D), not the generic loop level.

3. **The free-function dot/cross products** (lines 253-288 in Linear+Arithmatic.swift) duplicate the instance methods. The 2D-specialized versions use `.rawValue` because they access `dx`/`dy` typed components and multiply across tags. The N-dimensional versions use raw `components[i]` directly. Both are boundary-correct.

Out of 31 `.rawValue` usages: **29 are boundary-correct**, **2 are call-site leaks** (LIN-009, LIN-010).
Out of 20 `__unchecked` usages: **all 20 are boundary-correct**.
