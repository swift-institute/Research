# Geometry.Insets → Product<Height, Width, Height, Width> — Experiment Prompt

## Objective

Determine whether `Geometry.Insets` (currently a struct with four `Scalar` properties) can be replaced by `Product<Geometry.Height, Geometry.Width, Geometry.Height, Geometry.Width>` with labeled accessors via extensions.

## Current State

`Geometry.Insets` was recently renamed from `EdgeInsets` (Pass 4). It lives at:

```
https://github.com/swift-primitives/swift-geometry-primitives/blob/main/Sources/Geometry Primitives/Geometry.EdgeInsets.swift
```

Current declaration (read this file for full code):

```swift
extension Geometry {
    public struct Insets {
        public let top: Scalar
        public let leading: Scalar
        public let bottom: Scalar
        public let trailing: Scalar
    }
}
```

It has extensions for `Sendable`, `Equatable`, `Hashable`, `Codable`, `AdditiveArithmetic` (`.zero`, `+`, `-`, negation), convenience inits (`init(all:)`, `init(horizontal:vertical:)`), and a functorial `map` method.

## Hypothesis

`Geometry.Insets` can be expressed as a typealias to `Product<Geometry.Height, Geometry.Width, Geometry.Height, Geometry.Width>` where:
- `.top` → first `Height` (top inset is a vertical measurement)
- `.leading` → first `Width` (leading inset is a horizontal measurement)
- `.bottom` → second `Height`
- `.trailing` → second `Width`

Labels (`top`, `leading`, `bottom`, `trailing`) would be added via extensions on the specific `Product` instantiation.

## Research Steps

### 1. Understand the Product type

Read the `Product` type in algebra-primitives:
```
https://github.com/swift-primitives/swift-algebra-primitives
```

Grep for `struct Product` or `enum Product` to find it. Understand:
- How many elements can a Product hold? (2? N? Variadic?)
- What are its generic parameters?
- Does it support labeled access via extensions?
- Is it `Sendable`, `Equatable`, `Hashable`?

### 2. Understand Geometry.Height and Geometry.Width

These are typed scalars from the affine/linear algebra layer. Find their declarations:
```bash
grep -rn "typealias Height\|typealias Width\|struct Height\|struct Width" \
  https://github.com/swift-primitives/swift-geometry-primitives/tree/main/Sources/
```

Understand:
- Are they `Scalar` wrappers (newtypes)?
- Can you construct them from a bare `Scalar`?
- Do they support `AdditiveArithmetic`?

### 3. Create experiment

Location: `https://github.com/swift-primitives/swift-geometry-primitives/tree/main/Experiments/insets-as-product/`

Follow `/experiment-process` skill conventions ([EXP-002] through [EXP-006]).

Test these variants:

**Variant A**: Can you typealias `Product<Height, Width, Height, Width>` and add labeled accessors?
```swift
extension Product where A == Height, B == Width, C == Height, D == Width {
    var top: Height { a }
    var leading: Width { b }
    var bottom: Height { c }
    var trailing: Width { d }
}
```

**Variant B**: Does `init(top:leading:bottom:trailing:)` work as an extension?

**Variant C**: Do the existing `Insets` operations map naturally?
- `.zero` — does `Product` have `.zero` when all components are `AdditiveArithmetic`?
- `+` / `-` — component-wise?
- `init(all:)` — can this work with mixed types (`Height` from vertical scalar, `Width` from horizontal)?
- `init(horizontal:vertical:)` — same question
- `map` (functorial) — does `Product` support mapping over components?

**Variant D**: Does `Codable` conformance on the product match the current JSON shape? The current `Insets` encodes as `{"top":..., "leading":..., "bottom":..., "trailing":...}`. A `Product` would encode differently unless custom `Codable` is provided.

**Variant E**: Cross-check the current usage in `Geometry.Orthotope.inset(by:)` — does the API still work if `Insets` becomes a product typealias?

### 4. Check `init(all:)` feasibility

The current `init(all: Scalar)` sets all four edges to the same value. But `Height` and `Width` are different types — you can't use the same `Scalar` for both without conversion. How does the geometry layer handle `Scalar → Height` and `Scalar → Width` conversion? Is it just wrapping?

### 5. Evaluate trade-offs

Even if it compiles, consider:
- **API ergonomics**: Is `Product<Height, Width, Height, Width>` harder to read than a named struct?
- **Discoverability**: Will autocomplete show `.top`, `.leading` etc. on the product type?
- **Codable compatibility**: Breaking JSON shape is a concern for consumers.
- **Type safety gain**: The real win is that `top`/`bottom` are `Height` and `leading`/`trailing` are `Width` — you can't accidentally swap them. Is this actually useful in practice?

## Deliverable

Update the experiment's `main.swift` header with CONFIRMED/REFUTED per variant. If the approach is viable, draft the concrete replacement code (typealias + extensions). If not, document exactly which variant failed and why.

## Context

- `Geometry<Scalar, Space>` is generic over `Scalar` and a phantom `Space` parameter.
- `Geometry.Height`, `Width`, etc. are likely typealiases to `Linear<Scalar, Space>.Magnitude` or similar typed wrappers.
- The `Product` type is in algebra-primitives (tier 0), geometry-primitives is tier 12 — dependency direction is valid.
- Cross-repo consumers (`PDF.UserSpace.EdgeInsets` in swift-standards/swift-foundations) would need updating if the type changes shape.
