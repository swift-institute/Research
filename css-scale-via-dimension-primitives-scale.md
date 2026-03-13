# CSS Scale via Dimension Primitives Scale

<!--
---
version: 1.0.0
last_updated: 2026-03-13
status: DECISION
---
-->

## Context

The W3C CSS Transforms module (`swift-w3c-css`) defines `Scale` as a CSS property enum. The Dimension Primitives package (`swift-dimension-primitives`) defines `Scale<let N: Int, Scalar>` as an N-dimensional mathematical transformation. Both represent scaling — the question is whether the CSS type can or should be expressed in terms of the primitive.

### Source Files

| Type | Path | Layer |
|------|------|-------|
| CSS Scale | `swift-w3c/swift-w3c-css/Sources/W3C CSS Transforms/Scale.swift` | Standards (L2) |
| Dimension Scale | `swift-primitives/swift-dimension-primitives/Sources/Dimension Primitives/Scale.swift` | Primitives (L1) |

## Question

Can `W3C_CSS_Transforms.Scale` be expressed via `Dimension_Primitives.Scale`?

## Analysis

### Current CSS Scale

```swift
public enum Scale: Property, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    case none
    case single(Double)
    case xy(Double, Double)
    case xyz(Double, Double, Double)
    case global(Global)
}
```

**Concerns**: CSS property name, CSS serialization (`description`), CSS global values (`inherit`, `initial`, etc.), variable-arity serialization (1/2/3 values produce different CSS text), literal conformances for ergonomic initialization.

### Current Dimension Primitives Scale

```swift
public struct Scale<let N: Int, Scalar> {
    public var factors: InlineArray<N, Scalar>
}
```

**Concerns**: N-dimensional generality, generic scalar type, algebraic composition (`concatenate`, `inverted`), type-safe dimensional analysis (Scale × Displacement → Displacement), trigonometric returns (`sin(angle) → Scale<1, _>`).

### Option A: Replace CSS Scale enum cases with Dimension Primitives Scale

```swift
public enum Scale: Property {
    case none
    case uniform(Dimension_Primitives.Scale<1, Double>)
    case xy(Dimension_Primitives.Scale<2, Double>)
    case xyz(Dimension_Primitives.Scale<3, Double>)
    case global(Global)
}
```

**Advantages**:
- Shared vocabulary type across layers
- If CSS Scale values need to be applied to geometry, the primitive is already there

**Disadvantages**:
- Adds `swift-dimension-primitives` as a dependency of `swift-w3c-css` — this is a significant dependency for wrapping 1–3 `Double`s
- No structural simplification — the enum still needs the same cases for CSS serialization semantics
- The `InlineArray`-backed struct adds indirection over bare `Double` payloads with no benefit at this level
- Composition operations (`concatenate`, `inverted`) are irrelevant to CSS property values — CSS properties are declarative values, not mathematical operators
- Generic scalar type is unused — CSS numbers are always `Double`
- CSS-specific concerns (`.none`, `.global`, variable-arity `description`) cannot be derived from the primitive

### Option B: Keep CSS Scale independent, add conversion

```swift
// In a higher layer or extension:
extension W3C_CSS_Transforms.Scale {
    public var dimensionScale: Dimension_Primitives.Scale<3, Double> {
        switch self {
        case .none:           .identity
        case .single(let s):  .init(x: s, y: s, z: 1)
        case .xy(let x, let y): .init(x: x, y: y, z: 1)
        case .xyz(let x, let y, let z): .init(x: x, y: y, z: z)
        case .global:         .identity // or fatalError — globals have no numeric meaning
        }
    }
}
```

**Advantages**:
- No coupling between Layer 1 and the CSS domain
- CSS type remains a pure property-value type — clean, self-contained, no unnecessary abstractions
- Conversion available at the point of use (e.g., when applying CSS transforms to geometry)
- Each type stays focused on its own domain concerns
- No new dependency for `swift-w3c-css`

**Disadvantages**:
- Two types exist for "scale" — but they serve fundamentally different purposes

### Option C: CSS Scale wraps Dimension Primitives Scale<3, Double> as backing storage

```swift
public enum Scale: Property {
    case none
    case value(Dimension_Primitives.Scale<3, Double>, arity: Int)
    case global(Global)
}
```

**Advantages**:
- Single backing representation

**Disadvantages**:
- Runtime `arity` tracking to reconstruct CSS serialization — fragile, error-prone
- Semantic mismatch: CSS `.single(2.0)` means "scale X and Y by 2, Z by 1" but storing `Scale<3>(2, 2, 1)` loses the information that only one value was specified
- Adds dependency for no structural gain

### Comparison

| Criterion | A: Replace | B: Independent + Convert | C: Wrap |
|-----------|-----------|--------------------------|---------|
| Dependency cost | High | None | High |
| Structural simplification | None | N/A | Negative |
| Domain clarity | Muddied | Clean | Muddied |
| CSS serialization fidelity | Same | Same | Worse (arity tracking) |
| Geometry interop | Built-in | Conversion needed | Built-in |
| Layer architecture fit | Questionable | Clean | Questionable |

### Key Insight: Domain Mismatch

These types occupy fundamentally different roles:

| Aspect | CSS Scale | Dimension Primitives Scale |
|--------|-----------|---------------------------|
| Purpose | Declarative CSS property value | Mathematical transformation operator |
| Used for | Serialization to CSS text | Computation on geometric types |
| Dimensionality | Variable (1/2/3 = different CSS text) | Fixed at compile time (value generic `N`) |
| Scalar | Always `Double` | Generic `Scalar` |
| Operations | `description` → CSS string | `concatenate`, `inverted`, `*` with vectors |
| Special values | `none`, `global(inherit/initial/...)` | `identity`, `half`, `double` |
| Identity | `.none` (no transform) | `.identity` (scale by 1) |

CSS `Scale.none` and Dimension `Scale.identity` are semantically equivalent in effect but serve different protocols — one is a CSS keyword, the other a mathematical identity element.

The CSS Translate property (`Translate.swift`) confirms this pattern: it uses `LengthPercentage` and `Length` (CSS value types), not Dimension Primitives vectors. CSS properties are *value declarations*, not *operations*.

## Outcome

**Status**: DECISION

**Decision**: Keep CSS Scale independent (Option B). The types serve fundamentally different domains — CSS serialization vs. mathematical transformation — and forcing one to wrap the other adds dependency cost with no structural benefit.

**Rationale**:
1. **No structural simplification** — the CSS enum still needs all the same cases regardless of payload type
2. **Domain mismatch** — CSS properties are declarative values; primitives are computational operators
3. **Variable arity is semantic** — CSS `scale: 1.5` (1 value) and `scale: 1.5 1.5` (2 values) are syntactically different and must serialize differently; a 3D backing store erases this distinction
4. **Dependency weight** — `swift-dimension-primitives` brings `InlineArray`, value generics, the full dimension type system, and transitive dependencies — all for wrapping 1–3 `Double`s
5. **Layer architecture** — W3C CSS standards should not depend on geometric primitives; CSS is a *text formatting specification*, not a geometry library

**When conversion matters**: If a rendering engine needs to apply CSS scale values to actual geometry, a conversion extension (Option B) at the component/application layer is the right approach. That conversion lives where the two domains meet, not inside either domain type.

## References

- CSS Transforms Module Level 2: [`scale` property](https://drafts.csswg.org/css-transforms-2/#individual-transforms)
- Swift Institute Five-Layer Architecture: Layer dependencies flow downward only
