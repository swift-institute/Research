# Academic Critique: Unified Geometry Types Research

This document provides critical analysis of the unified geometry types proposal, examining assumptions, edge cases, and unexplored implications. Each section includes responses and proposed solutions.

---

## 1. Coordinate System Semantics: The map/flatMap Question

### The Problem

Different rendering contexts use different coordinate systems:

| Context | Y-Axis | Origin |
|---------|--------|--------|
| SVG | Down = positive | Top-left |
| CSS (transforms) | Down = positive | Varies by `transform-origin` |
| Mathematical | Up = positive | Bottom-left (typically) |
| PDF (ISO 32000) | Up = positive | Bottom-left |

If `SVG.Circle` and `CSS.Circle` are different types (good), but `Geometry.Circle` is the "universal" backing type, what coordinate convention does it use?

### Proposed Solution: Space Transformation via map/flatMap

The `Geometry` type should support space transformation through functional combinators:

```swift
extension Geometry.Circle {
    /// Transform this circle to a different coordinate space
    public func map<TargetSpace>(
        _ transform: (Space) -> TargetSpace
    ) -> Geometry<Scalar, TargetSpace>.Circle {
        // Apply coordinate transformation
    }
}

// Or perhaps on the space marker itself
extension Geometry where Space: CoordinateSpace {
    /// Convert geometry to a different space with the provided transformation
    public func transformed<Target: CoordinateSpace>(
        to target: Target.Type,
        using transform: Space.Transform<Target>
    ) -> Geometry<Scalar, Target>
}
```

### Space Marker with Transformation Protocol

```swift
/// Protocol for coordinate spaces that can be transformed
public protocol CoordinateSpace {
    /// The transformation needed to convert to another space
    associatedtype Transform<Target: CoordinateSpace>

    /// Y-axis direction
    static var yAxis: Axis.Direction { get }

    /// Origin convention
    static var origin: Origin.Convention { get }
}

public enum Axis {
    public enum Direction {
        case up    // Mathematical, PDF
        case down  // SVG, CSS, Screen
    }
}

/// SVG space marker with transformation capability
public enum SVGSpace: CoordinateSpace {
    public static var yAxis: Axis.Direction { .down }
    public static var origin: Origin.Convention { .topLeft }
}

/// PDF space marker
public enum PDFSpace: CoordinateSpace {
    public static var yAxis: Axis.Direction { .up }
    public static var origin: Origin.Convention { .bottomLeft }
}
```

### Converting Between Spaces

```swift
// SVG → PDF requires Y-axis flip
let svgCircle: SVG.Circle = .init(center: (100, 100), radius: 50)

// Option 1: Explicit transform function
let pdfCircle = svgCircle.map { point in
    Point(x: point.x, y: viewportHeight - point.y)
}

// Option 2: Space-aware transformation
let pdfCircle = svgCircle.transformed(to: PDFSpace.self, in: viewport)

// Option 3: Higher-level package provides this
// In swift-html (which depends on both SVG and PDF):
extension SVG.Circle {
    public func toPDF(viewport: Viewport) -> PDF.UserSpace.Circle {
        // Y-flip transformation
    }
}
```

### Key Insight

The **swift-standards Geometry module remains pure** (no coordinate convention). The **Space marker** carries the convention, and **higher-level packages** (swift-html, swift-svg-to-pdf) provide transformations between spaces.

---

## 2. Ontological Question: Is a "Circle" Really the Same Thing?

### The Concern

SVG `<circle>`, CSS `circle()`, and Canvas arc have fundamentally different:
- Parameter syntax
- Default values
- Additional attributes (fill, stroke vs clip-path keywords)

### Resolution: Unified API, Context-Specific Serialization

**The approach is correct:** A geometric circle IS a universal concept (center + radius). The differences are in:

1. **Serialization** → handled by `.svg`, `.css` context wrappers
2. **Additional attributes** → handled by domain-specific styled types (see PDF.Rectangle pattern)

```swift
// Pure geometry - universal
let circle = Geometry<Double, SVGSpace>.Circle(center: (100, 100), radius: 50)

// Context-specific serialization
circle.svg.element    // <circle cx="100" cy="100" r="50"/>
circle.css.clip.path  // circle(50px at 100px 100px)

// Domain-specific styled version (like PDF.Rectangle)
SVG.StyledCircle(circle, fill: .red, stroke: .black)
```

### The PDF.Rectangle Pattern

From `PDF.Rectangle.swift` - this is the correct pattern:

```swift
// Pure geometry type
PDF.UserSpace.Rectangle  // Just llx, lly, urx, ury

// Styled view type (domain-specific)
PDF.Rectangle {
    var rect: PDF.UserSpace.Rectangle  // Contains geometry
    var fill: PDF.Color?               // Domain-specific
    var stroke: PDF.Stroke?            // Domain-specific
}

// Extension bridges the two
extension PDF.UserSpace.Rectangle {
    func filled(_ color: PDF.Color) -> PDF.Rectangle {
        PDF.Rectangle(self, fill: color)
    }
}
```

**Apply to SVG/CSS:**

```swift
// Pure geometry
SVG.Circle = Geometry<Double, SVGSpace>.Circle

// Styled element (domain-specific)
extension SVG {
    struct StyledCircle {
        var circle: SVG.Circle           // Geometry
        var fill: SVG.Paint?             // SVG-specific
        var stroke: SVG.Stroke?          // SVG-specific
        var presentation: SVG.Presentation?
    }
}

// Bridge
extension SVG.Circle {
    func filled(_ paint: SVG.Paint) -> SVG.StyledCircle {
        SVG.StyledCircle(self, fill: paint)
    }
}
```

---

## 3. The "Intentional Conversion" Problem

### The Problem

The type system prevents accidental mixing. What about intentional conversion?

```swift
let svgCircle: SVG.Circle = ...
let cssClipPath = svgCircle.toCSS()  // How?
```

### Solution: map/flatMap + Higher-Level Packages

**Option A: map for Same-Scalar Transformations**

```swift
extension Geometry.Circle {
    /// Transform to a different coordinate space
    public func map<TargetSpace>(
        _ transform: (Point<2, Scalar, Space>) -> Point<2, Scalar, TargetSpace>
    ) -> Geometry<Scalar, TargetSpace>.Circle {
        .init(
            center: transform(self.center),
            radius: self.radius  // Radius is space-independent magnitude
        )
    }
}

// Usage
let cssCircle = svgCircle.map { point in
    // Transform SVG coordinates to CSS coordinates
    // (often identity, but could involve viewport mapping)
    Point<2, Double, CSSSpace>(x: point.x, y: point.y)
}
```

**Option B: Higher-Level Package Provides Transformation**

In **swift-html** (which depends on both swift-w3c-svg and swift-w3c-css):

```swift
// swift-html provides SVG ↔ CSS transformations
extension SVG.Circle {
    /// Convert to CSS basic shape for clip-path
    public var css: CSS.Circle {
        CSS.Circle(
            center: (self.center.x, self.center.y),
            radius: self.radius
        )
    }
}

extension CSS.Circle {
    /// Convert to SVG circle geometry
    public var svg: SVG.Circle {
        SVG.Circle(
            center: (self.center.x, self.center.y),
            radius: self.radius
        )
    }
}
```

**Option C: flatMap for Complex Transformations**

```swift
extension Geometry.Circle {
    /// Transform with possible failure or context
    public func flatMap<TargetSpace>(
        _ transform: (Self) -> Geometry<Scalar, TargetSpace>.Circle?
    ) -> Geometry<Scalar, TargetSpace>.Circle? {
        transform(self)
    }
}
```

### Recommended Approach

1. **swift-standards** provides `map` on Geometry types
2. **Domain packages** (swift-w3c-svg, swift-w3c-css) define their spaces
3. **Integration packages** (swift-html, swift-svg-to-pdf) provide cross-domain transformations

---

## 4. Algebraic Properties: Already Solved

### Existing Solution

The `Tagged+Arithmatic.swift` file shows a **comprehensive dimensional analysis system**:

```swift
// ✅ Width + Width = Width (same type)
public func + <Space, Scalar>(
    lhs: Extent.X<Space>.Value<Scalar>,
    rhs: Extent.X<Space>.Value<Scalar>
) -> Extent.X<Space>.Value<Scalar>

// ✅ Width × Height = Area (dimensional product)
public func * <Space, Scalar>(
    lhs: Extent.X<Space>.Value<Scalar>,
    rhs: Extent.Y<Space>.Value<Scalar>
) -> Area<Space>.Value<Scalar>

// ✅ Coordinate - Coordinate = Displacement (affine geometry)
public func - <Space, Scalar>(
    lhs: Coordinate.X<Space>.Value<Scalar>,
    rhs: Coordinate.X<Space>.Value<Scalar>
) -> Displacement.X<Space>.Value<Scalar>

// ✅ Area / Magnitude = Magnitude
public func / <Space, Scalar>(
    lhs: Area<Space>.Value<Scalar>,
    rhs: Magnitude<Space>.Value<Scalar>
) -> Magnitude<Space>.Value<Scalar>

// ❌ Width + Height - NOT defined (prevents dimensional errors)
// ❌ SVG.Width + CSS.Width - NOT defined (prevents space mixing)
```

### Key Design Decisions

From the code comments:

> "We intentionally do NOT conform Tagged to AdditiveArithmetic.
> In affine geometry, Coordinate - Coordinate = Displacement (not Coordinate).
> Blanket +/- operators would give wrong types."

This is exactly correct and follows dimensional analysis principles.

### Missing Operations (Potential Additions)

```swift
// Width * 2 → Width (scalar multiplication)
// Currently using Scale<1, Scalar> for explicit scaling:
width * Scale(2.0)  // Explicit scale factor

// Consider: allow direct scalar multiplication?
width * 2.0  // More ergonomic, but less type-safe
```

---

## 5. Validation Semantics: Context Wrapper Pattern

### The Problem

Different contexts have different valid ranges:

| Type | SVG Valid | CSS Valid | HTML Valid |
|------|-----------|-----------|------------|
| Radius | ≥ 0 | ≥ 0 | N/A |
| Width | ≥ 0 | Any | ≥ 0, integer |
| Margin | N/A | Any (negative ok) | N/A |

### Proposed Solution: Validate in Context Wrapper

The `.svg`, `.css`, `.html` context wrappers can perform validation:

```swift
extension Geometry.Circle {
    public var svg: SVG { SVG(self) }

    public struct SVG {
        let circle: Geometry.Circle

        /// Validates and returns SVG element, or nil if invalid
        public var element: W3C_SVG2.Shapes.Circle? {
            // SVG requires non-negative radius
            guard circle.radius >= 0 else { return nil }
            return .init(
                cx: circle.center.x,
                cy: circle.center.y,
                r: circle.radius
            )
        }

        /// Validated element (crashes on invalid)
        public var validatedElement: W3C_SVG2.Shapes.Circle {
            guard let element else {
                preconditionFailure("Invalid SVG circle: radius must be >= 0")
            }
            return element
        }
    }
}
```

### Alternative: Validating Initializer in Context

```swift
extension SVG {
    /// SVG-validated circle (enforces SVG constraints)
    public struct Circle {
        private let geometry: Geometry<Double, SVGSpace>.Circle

        public init?(_ geometry: Geometry<Double, SVGSpace>.Circle) {
            guard geometry.radius >= 0 else { return nil }
            self.geometry = geometry
        }

        public init(center: (Double, Double), radius: Double) {
            precondition(radius >= 0, "SVG circle radius must be >= 0")
            self.geometry = .init(center: center, radius: radius)
        }
    }
}
```

### Recommendation

**Keep Geometry pure (no validation)**, perform validation in:
1. Context wrappers (`.svg.element`)
2. Domain-specific initializers (`SVG.Circle.init`)
3. Serialization methods (`svg.serialize()`)

---

## 6. Unit System Complexity

### The Problem

CSS units are complex:
- Relative units (`em`, `rem`, `%`) depend on context
- `calc()` expressions
- Keywords (`auto`, `min-content`)

### Observation

This is less about **geometry** and more about **CSS values**. The research document conflates two concerns:

1. **Geometric primitives** (Circle, Rectangle, Point) → Unified ✅
2. **CSS Length values** (with calc, %, keywords) → Separate concern

### Proposed Architecture

```swift
// Geometry uses simple numeric scalars
Geometry<Double, Space>.Circle  // center: Point, radius: Double

// CSS Length is a separate, complex type
CSS.Length {
    enum Value {
        case absolute(Double, Unit)     // 10px, 2em
        case percentage(Double)          // 50%
        case calc(Expression)            // calc(100% - 20px)
        case keyword(Keyword)            // auto, min-content
    }
}

// When geometry needs a CSS length:
CSS.Box {
    var width: CSS.Length   // Complex CSS value
    var height: CSS.Length
}

// NOT:
CSS.Box {
    var width: CSS.Width    // Don't try to unify this with Geometry.Width
}
```

### Key Insight

**Geometry types** (swift-standards) use **numeric scalars** (Double, Float).
**CSS value types** (swift-w3c-css) handle **CSS-specific complexity**.

The unification applies to **geometric operations**, not **CSS value syntax**.

---

## 7. Versioning and Extensibility

### The Concern

When CSS adds new units (e.g., `lh` for line-height):
- Does `Length.Unit` enum need updating?
- Breaking change propagates?

### Response: This is a Feature, Not a Bug

**Benefits of centralized types:**
1. All packages get new capabilities simultaneously
2. Compiler assists migration (exhaustive switch)
3. Single source of truth

### Alternative: Domain-Specific Length Types

If CSS-specific complexity is too much for a shared type:

```swift
// In swift-standards: Geometry with numeric scalars
Geometry<Double, Space>.Circle  // radius: Double

// In swift-w3c-css: CSS-specific length type
CSS.Length  // with all CSS unit complexity

// In swift-w3c-svg: SVG-specific length type
SVG.Length  // with SVG unit semantics

// The GEOMETRY is shared, the LENGTH VALUES are domain-specific
```

### Recommendation

**Two-tier approach:**

1. **Geometric dimensions** (Width, Height, Radius as scalars) → Unified in Geometry
2. **Value syntax** (CSS Length with calc, SVG Length with units) → Domain-specific

```swift
// Shared geometry
let circle: Geometry<Double, CSSSpace>.Circle = .init(
    center: (100, 100),  // Numeric coordinates
    radius: 50           // Numeric radius
)

// CSS value wrapper when needed
let cssWidth: CSS.Length = .calc("100% - 20px")
```

---

## 8. The Leaky Abstraction Problem: Solved by PDF Pattern

### The Concern

At the boundary, you need actual SVG/CSS/HTML with attributes beyond geometry.

### Solution: The PDF.Rectangle Pattern

From your codebase:

```swift
// LAYER 1: Pure Geometry (swift-standards)
PDF.UserSpace.Rectangle  // llx, lly, urx, ury - just coordinates

// LAYER 2: Styled Domain Type (swift-pdf-standard)
PDF.Rectangle {
    var rect: PDF.UserSpace.Rectangle  // Wraps geometry
    var fill: PDF.Color?               // PDF-specific
    var stroke: PDF.Stroke?            // PDF-specific
}

// LAYER 3: Convenience Extensions
extension PDF.UserSpace.Rectangle {
    func filled(_ color: PDF.Color) -> PDF.Rectangle
    func stroked(_ color: PDF.Color, width: PDF.UserSpace.Width) -> PDF.Rectangle
    func styled(fill: PDF.Color?, stroke: PDF.Stroke?) -> PDF.Rectangle
}
```

**Apply to SVG:**

```swift
// LAYER 1: Pure Geometry (from swift-standards)
SVG.Circle = Geometry<Double, SVGSpace>.Circle  // center + radius

// LAYER 2: SVG Element Type (swift-w3c-svg)
extension W3C_SVG2.Shapes {
    struct Circle {
        var geometry: SVG.Circle           // From swift-standards
        var fill: SVG.Paint?
        var stroke: SVG.Stroke?
        var presentation: SVG.Presentation?
        var id: String?
        var className: String?
    }
}

// LAYER 3: Convenience Extensions
extension SVG.Circle {
    func filled(_ paint: SVG.Paint) -> W3C_SVG2.Shapes.Circle
    func stroked(_ paint: SVG.Paint, width: Double) -> W3C_SVG2.Shapes.Circle
}
```

**Apply to CSS:**

```swift
// LAYER 1: Pure Geometry
CSS.Circle = Geometry<Double, CSSSpace>.Circle

// LAYER 2: CSS Clip Path Value
extension CSS.Clip {
    struct Path {
        enum Shape {
            case circle(CSS.Circle)
            case ellipse(CSS.Ellipse)
            case polygon(CSS.Polygon)
            case path(CSS.Path)
        }
        var shape: Shape
        var box: CSS.Box?  // Optional geometry box reference
    }
}

// LAYER 3: Convenience
extension CSS.Circle {
    var asClipPath: CSS.Clip.Path {
        .init(shape: .circle(self))
    }
}
```

### Summary

The abstraction doesn't "leak" - it's **deliberately layered**:
1. **Geometry** (pure math, shared)
2. **Domain elements** (wrap geometry + domain attributes)
3. **Convenience bridges** (geometry → styled element)

---

## 9. Summary: Areas Requiring Attention

| Area | Status | Recommendation |
|------|--------|----------------|
| **Coordinate Systems** | Needs work | Add `map`/`flatMap`, define Space protocol with axis info |
| **Ontological Question** | Resolved | Unified geometry + context serialization is correct |
| **Intentional Conversion** | Needs work | Higher-level packages provide transformations |
| **Algebraic Operations** | ✅ Solved | Existing Tagged+Arithmatic.swift is comprehensive |
| **Validation** | Needs work | Validate in context wrappers, not geometry |
| **Unit Complexity** | Clarify | Geometry uses scalars; CSS.Length is separate |
| **Versioning** | Clarify | Feature for geometry; domain-specific for value syntax |
| **Leaky Abstraction** | ✅ Solved | PDF.Rectangle pattern is the answer |

---

## 10. Proposed Additions to Research Document

### Add: Space Transformation Protocol

```swift
/// Protocol for transformable coordinate spaces
public protocol TransformableSpace {
    /// Transform a point from this space to another
    static func transform<Target: TransformableSpace>(
        _ point: Point<2, Double, Self>,
        to target: Target.Type,
        viewport: Viewport
    ) -> Point<2, Double, Target>
}
```

### Add: map/flatMap on Geometry Types

```swift
extension Geometry.Circle {
    /// Transform to different coordinate space
    public func map<TargetSpace>(
        _ transform: (Point<2, Scalar, Space>) -> Point<2, Scalar, TargetSpace>
    ) -> Geometry<Scalar, TargetSpace>.Circle
}
```

### Add: Validation Strategy

```swift
// Geometry: No validation (pure math)
// Context wrappers: Validate on access
// Domain types: Validate on init
```

### Add: The Layered Pattern

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: Convenience Extensions                            │
│  rectangle.filled(.red)  →  PDF.Rectangle                   │
├─────────────────────────────────────────────────────────────┤
│  LAYER 2: Domain-Specific Styled Types                      │
│  PDF.Rectangle { geometry + fill + stroke }                 │
│  SVG.StyledCircle { geometry + paint + stroke }             │
├─────────────────────────────────────────────────────────────┤
│  LAYER 1: Pure Geometry (swift-standards)                   │
│  Geometry<Scalar, Space>.Rectangle                          │
│  Geometry<Scalar, Space>.Circle                             │
└─────────────────────────────────────────────────────────────┘
```

---

## References

- Dimensional analysis: `swift-standards/Sources/Dimension/Tagged+Arithmatic.swift`
- PDF styled pattern: `swift-pdf-standard/Sources/PDF Standard/PDF.Rectangle.swift`
- ISO 32000 namespace: `swift-iso-32000/Sources/ISO 32000 Shared/ISO_32000.swift`
- INCITS namespacing: `swift-incits-4-1986/Sources/INCITS_4_1986/UInt8.ASCII.swift`
