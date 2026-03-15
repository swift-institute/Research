# Unified Geometry Types Specification

A comprehensive specification for sharing geometry types from `swift-standards` across SVG, CSS, and HTML libraries.

---

## Executive Summary

**Can swift-standards types (Circle, Rectangle, Dx, Dy, EdgeInsets, etc.) directly replace corresponding types in swift-w3c-css and swift-whatwg-html?**

**Yes.** A `Circle` is a geometric primitive (center + radius). Whether it becomes an SVG element, CSS clip-path, or canvas drawing is just *how it's rendered* in that context.

```swift
// ONE Circle type from swift-standards
let circle: SVG.Circle = .init(center: (100, 100), radius: 50)

// Context-specific rendering
circle.svg.element       // -> <circle cx="100" cy="100" r="50"/>
circle.css.clip.path     // -> circle(50px at 100px 100px)
circle.filled(.red)      // -> SVG.Styled.Circle with fill
```

---

## Architecture Overview

### The Three-Layer Pattern

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: Convenience Extensions                            │
│  circle.filled(.red)  →  SVG.Styled.Circle                  │
│  rectangle.stroked(.black, width: 2)  →  PDF.Rectangle      │
├─────────────────────────────────────────────────────────────┤
│  LAYER 2: Domain-Specific Styled Types                      │
│  SVG.Styled.Circle { geometry + paint + stroke }            │
│  PDF.Rectangle { geometry + fill + stroke }                 │
│  CSS.Clip.Path { shape + box }                              │
├─────────────────────────────────────────────────────────────┤
│  LAYER 1: Pure Geometry (swift-standards)                   │
│  Geometry<Scalar, Space>.Circle                             │
│  Geometry<Scalar, Space>.Rectangle                          │
│  Geometry<Scalar, Space>.Path                               │
└─────────────────────────────────────────────────────────────┘
```

### Dependency Graph

```
                     swift-standards
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         Geometry     Dimension     Formatting
              │            │            │
              └────────────┼────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   swift-w3c-svg    swift-w3c-css    swift-whatwg-html
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                      swift-html
              (provides cross-domain transforms)
```

---

## Naming Conventions

### Core Rules

1. **Never use compound names** for types or properties
2. Use `Type.Wrapper` instead of `TypeWrapper`
3. Use `curve.up` instead of `curveUp`
4. For reserved names, use **backticks**: `Length.`Type``

### Examples

| ❌ Bad | ✅ Good |
|--------|---------|
| `SVGCircleContext` | `Circle.SVG` |
| `CSSLengthType` | `Length.CSS` |
| `clipPath` | `clip.path` |
| `tagName` | `tag.name` |
| `NamedColor` | `Color.Named` |
| `TransformFunction` | `Transform.Function` |
| `BoxSpacing` | `Box.Spacing` |

### Escaping Reserved Names

```swift
// Swift reserves .Type and .Protocol as metatype accessors
extension Length {
    struct `Type` { ... }      // Length.`Type` - nested struct
    struct `Protocol` { ... }  // Length.`Protocol` - nested struct
}

// Usage
let lengthType: Length.`Type` = ...      // The nested struct
let metatype: Length.Type = Length.self  // The metatype
```

---

## Available Types

### Geometric Primitives

| swift-standards Type | Description | SVG | CSS | HTML |
|---------------------|-------------|-----|-----|------|
| `Geometry.Ball<2>` | Circle | `<circle>` | `clip-path: circle()` | Canvas arc |
| `Geometry.Ellipse` | Ellipse | `<ellipse>` | `clip-path: ellipse()` | Canvas ellipse |
| `Geometry.Rectangle` | Axis-aligned rect | `<rect>` | Box properties | Canvas rect |
| `Geometry.Line.Segment` | Line segment | `<line>` | - | Canvas line |
| `Geometry.Polygon` | N-vertex polygon | `<polygon>` | `clip-path: polygon()` | Canvas path |
| `Geometry.Path` | General path | `<path>` | `clip-path: path()` | Canvas path |
| `Geometry.Arc` | Circular arc | Path commands | - | Canvas arc |
| `Geometry.Ellipse.Arc` | Elliptical arc | Path A command | - | - |
| `Geometry.EdgeInsets` | Top/Right/Bottom/Left | - | margin, padding | - |

### Dimension Types

| swift-standards Type | Description | SVG | CSS | HTML |
|---------------------|-------------|-----|-----|------|
| `Coordinate.X<Space>` | X position | cx, x | left, right | - |
| `Coordinate.Y<Space>` | Y position | cy, y | top, bottom | - |
| `Displacement.X<Space>` | Dx offset | dx | translateX | - |
| `Displacement.Y<Space>` | Dy offset | dy | translateY | - |
| `Extent.X<Space>` | Width | width, rx | width | width attr |
| `Extent.Y<Space>` | Height | height, ry | height | height attr |
| `Magnitude<Space>` | Radius/length | r, stroke-width | border-radius | - |
| `Degree<Scalar>` | Angle in degrees | rotate | rotate() | - |
| `Radian<Scalar>` | Angle in radians | (internal) | (internal) | - |

### Transform Types

| swift-standards Type | SVG | CSS |
|---------------------|-----|-----|
| `Scale<2, Scalar>` | `scale(sx, sy)` | `scale(sx, sy)` |
| `AffineTransform` | `matrix(...)` | `matrix(...)` |

---

## Space Marker Pattern (ISO 32000 Style)

Each domain defines a space marker enum and namespace:

```swift
// ═══════════════════════════════════════════════════════════════
// In swift-w3c-svg
// ═══════════════════════════════════════════════════════════════

/// SVG coordinate space marker
public enum SVGSpace {}

/// SVG namespace with convenient typealiases
public enum SVG {
    public typealias Geometry = Swift.Geometry<Double, SVGSpace>
}

extension SVG {
    // Shapes
    public typealias Circle = Geometry.Circle
    public typealias Rectangle = Geometry.Rectangle
    public typealias Ellipse = Geometry.Ellipse
    public typealias Line = Geometry.Line.Segment
    public typealias Polygon = Geometry.Polygon
    public typealias Path = Geometry.Path

    // Dimensions
    public typealias X = Geometry.X
    public typealias Y = Geometry.Y
    public typealias Dx = Geometry.Dx
    public typealias Dy = Geometry.Dy
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
    public typealias Radius = Geometry.Radius
}

// ═══════════════════════════════════════════════════════════════
// In swift-w3c-css
// ═══════════════════════════════════════════════════════════════

/// CSS coordinate space marker
public enum CSSSpace {}

/// CSS namespace with convenient typealiases
public enum CSS {
    public typealias Geometry = Swift.Geometry<Double, CSSSpace>
}

extension CSS {
    public typealias Circle = Geometry.Circle
    public typealias Rectangle = Geometry.Rectangle
    public typealias Ellipse = Geometry.Ellipse
    public typealias Polygon = Geometry.Polygon
    public typealias Path = Geometry.Path

    public typealias X = Geometry.X
    public typealias Y = Geometry.Y
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
    public typealias Radius = Geometry.Radius
    public typealias EdgeInsets = Geometry.EdgeInsets
}

// ═══════════════════════════════════════════════════════════════
// In swift-whatwg-html
// ═══════════════════════════════════════════════════════════════

/// HTML coordinate space marker
public enum HTMLSpace {}

/// HTML namespace
public enum HTML {
    public typealias Geometry = Swift.Geometry<Double, HTMLSpace>
}

extension HTML {
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
}
```

### Usage

```swift
// Clean namespace syntax
let circle: SVG.Circle = .init(center: (100, 100), radius: 50)
let margin: CSS.EdgeInsets = .init(all: 10)
let imgWidth: HTML.Width = 640

// Type safety - these are different types!
let cssWidth: CSS.Width = 100
let svgWidth: SVG.Width = 100
// cssWidth == svgWidth  // ❌ Compile error
```

---

## Context Extensions Pattern (INCITS Style)

Pure geometry types get context-specific behavior via nested types:

```swift
// In swift-standards/Geometry
public struct Ball<let N: Int, Scalar, Space> {
    public var center: Point<N, Scalar, Space>
    public var radius: Magnitude<Space, Scalar>
}

public typealias Circle<Scalar, Space> = Ball<2, Scalar, Space>

// In swift-w3c-svg (extension)
extension Geometry.Circle {
    /// SVG rendering context
    public var svg: SVG { .init(self) }

    public struct SVG {
        let circle: Geometry.Circle

        /// Convert to SVG element
        public var element: W3C_SVG2.Shapes.Circle {
            .init(
                cx: circle.center.x,
                cy: circle.center.y,
                r: circle.radius
            )
        }
    }
}

// In swift-w3c-css (extension)
extension Geometry.Circle {
    /// CSS rendering context
    public var css: CSS { .init(self) }

    public struct CSS {
        let circle: Geometry.Circle

        /// Access clip-path rendering
        public var clip: Clip { .init(circle) }

        public struct Clip {
            let circle: Geometry.Circle

            public var path: String {
                "circle(\(circle.radius) at \(circle.center.x) \(circle.center.y))"
            }
        }
    }
}

// Usage (dot notation!)
circle.svg.element     // SVG element
circle.css.clip.path   // CSS clip-path value
```

---

## Styled Domain Types Pattern (PDF.Rectangle Style)

Domain packages wrap pure geometry with domain-specific attributes:

### Layer 1: Pure Geometry (swift-standards)

```swift
PDF.UserSpace.Rectangle  // Just coordinates: llx, lly, urx, ury
SVG.Circle               // Just center + radius
CSS.Circle               // Just center + radius
```

### Layer 2: Styled Domain Type

```swift
// In swift-pdf-standard
extension PDF {
    public struct Rectangle: Sendable, Hashable {
        public var rect: PDF.UserSpace.Rectangle  // Geometry
        public var fill: PDF.Color?               // PDF-specific
        public var stroke: PDF.Stroke?            // PDF-specific
    }
}

// In swift-w3c-svg
extension SVG.Styled {
    public struct Circle {
        public var circle: SVG.Circle             // Geometry
        public var fill: SVG.Paint?               // SVG-specific
        public var stroke: SVG.Stroke?            // SVG-specific
        public var presentation: SVG.Presentation?
    }
}

// In swift-w3c-css
extension CSS.Clip {
    public struct Path {
        public enum Shape {
            case circle(CSS.Circle)
            case ellipse(CSS.Ellipse)
            case polygon(CSS.Polygon)
            case path(CSS.Path)
        }
        public var shape: Shape
        public var box: CSS.Box?
    }
}
```

### Layer 3: Convenience Extensions

```swift
// In swift-pdf-standard
extension PDF.UserSpace.Rectangle {
    public func filled(_ color: PDF.Color) -> PDF.Rectangle {
        PDF.Rectangle(self, fill: color)
    }

    public func stroked(_ color: PDF.Color, width: PDF.UserSpace.Width = 1) -> PDF.Rectangle {
        PDF.Rectangle(self, stroke: .init(color, width: width))
    }
}

// In swift-w3c-svg
extension SVG.Circle {
    public func filled(_ paint: SVG.Paint) -> SVG.Styled.Circle {
        SVG.Styled.Circle(self, fill: paint)
    }

    public func stroked(_ paint: SVG.Paint, width: Double) -> SVG.Styled.Circle {
        SVG.Styled.Circle(self, stroke: .init(paint, width: width))
    }
}

// In swift-w3c-css
extension CSS.Circle {
    public var asClipPath: CSS.Clip.Path {
        .init(shape: .circle(self))
    }
}
```

---

## Coordinate Space Transformation

### The Problem

Different contexts use different coordinate systems:

| Context | Y-Axis | Origin |
|---------|--------|--------|
| SVG | Down = positive | Top-left |
| CSS | Down = positive | Varies |
| PDF | Up = positive | Bottom-left |
| Math | Up = positive | Bottom-left |

### Solution: map/flatMap on Geometry

```swift
extension Geometry.Circle {
    /// Transform to a different coordinate space
    public func map<TargetSpace>(
        _ transform: (Point<2, Scalar, Space>) -> Point<2, Scalar, TargetSpace>
    ) -> Geometry<Scalar, TargetSpace>.Circle {
        .init(
            center: transform(self.center),
            radius: self.radius  // Radius is space-independent
        )
    }

    /// Transform with possible failure
    public func flatMap<TargetSpace>(
        _ transform: (Self) -> Geometry<Scalar, TargetSpace>.Circle?
    ) -> Geometry<Scalar, TargetSpace>.Circle? {
        transform(self)
    }
}
```

### Space Protocol (Optional)

```swift
/// Protocol for coordinate spaces with known conventions
public protocol CoordinateSpace {
    static var yAxis: Axis.Direction { get }
    static var origin: Origin.Convention { get }
}

public enum Axis {
    public enum Direction {
        case up    // Mathematical, PDF
        case down  // SVG, CSS, Screen
    }
}

public enum SVGSpace: CoordinateSpace {
    public static var yAxis: Axis.Direction { .down }
    public static var origin: Origin.Convention { .topLeft }
}

public enum PDFSpace: CoordinateSpace {
    public static var yAxis: Axis.Direction { .up }
    public static var origin: Origin.Convention { .bottomLeft }
}
```

### Cross-Domain Transformation (Higher-Level Packages)

In **swift-html** (depends on both SVG and CSS):

```swift
extension SVG.Circle {
    /// Convert to CSS circle for clip-path
    public var css: CSS.Circle {
        CSS.Circle(
            center: (self.center.x, self.center.y),
            radius: self.radius
        )
    }
}

extension CSS.Circle {
    /// Convert to SVG circle
    public var svg: SVG.Circle {
        SVG.Circle(
            center: (self.center.x, self.center.y),
            radius: self.radius
        )
    }
}
```

---

## Validation Strategy

### Principle

**Geometry is pure math - no validation.** Validation occurs at context boundaries.

### Validate in Context Wrapper

```swift
extension Geometry.Circle {
    public var svg: SVG { SVG(self) }

    public struct SVG {
        let circle: Geometry.Circle

        /// Returns nil if invalid for SVG
        public var element: W3C_SVG2.Shapes.Circle? {
            guard circle.radius >= 0 else { return nil }
            return .init(
                cx: circle.center.x,
                cy: circle.center.y,
                r: circle.radius
            )
        }

        /// Crashes if invalid
        public var validatedElement: W3C_SVG2.Shapes.Circle {
            guard let element else {
                preconditionFailure("SVG circle radius must be >= 0")
            }
            return element
        }
    }
}
```

### Validation Rules by Context

| Type | SVG | CSS | HTML |
|------|-----|-----|------|
| Radius | ≥ 0 | ≥ 0 | N/A |
| Width | ≥ 0 | Any | ≥ 0, integer |
| Margin | N/A | Any (negative ok) | N/A |

---

## Algebraic Operations (Already Implemented)

The `Tagged+Arithmatic.swift` provides comprehensive dimensional analysis:

### Valid Operations

```swift
// Width + Width = Width
let total = width1 + width2

// Width × Height = Area
let area = width * height

// Coordinate - Coordinate = Displacement
let offset = point2.x - point1.x  // Returns Displacement.X

// Coordinate + Displacement = Coordinate
let newPoint = point.x + offset

// Area / Magnitude = Magnitude
let radius = area / circumference

// Displacement × Scale = Displacement
let scaled = displacement * Scale(2.0)
```

### Prevented Operations

```swift
// ❌ Width + Height - different dimensions
// ❌ SVG.Width + CSS.Width - different spaces
// ❌ Coordinate + Coordinate - not meaningful in affine geometry
```

---

## Unit System Clarification

### Two Separate Concerns

1. **Geometric dimensions** (numeric scalars) → **Unified in Geometry**
2. **CSS value syntax** (calc, %, keywords) → **Domain-specific**

### Geometry Uses Scalars

```swift
// Pure geometry with numeric coordinates
Geometry<Double, Space>.Circle  // center: Point, radius: Double
```

### CSS.Length is Separate

```swift
// CSS-specific value type with full complexity
extension CSS {
    public struct Length {
        public enum Value {
            case absolute(Double, Unit)      // 10px, 2em
            case percentage(Double)           // 50%
            case calc(Expression)             // calc(100% - 20px)
            case keyword(Keyword)             // auto, min-content
        }
    }
}

// CSS box uses CSS.Length, not Geometry.Width
extension CSS {
    public struct Box {
        var width: CSS.Length   // Complex CSS value
        var height: CSS.Length
    }
}
```

### When They Meet

```swift
// Geometry circle with numeric radius
let circle: CSS.Circle = .init(center: (100, 100), radius: 50)

// CSS clip-path with CSS-specific formatting
circle.css.clip.path  // "circle(50px at 100px 100px)"
```

---

## Implementation Checklist

### swift-standards (Geometry Module)

- [ ] Add `map<TargetSpace>` to all geometry types
- [ ] Add `flatMap<TargetSpace>` for failable transformations
- [ ] Optional: Add `CoordinateSpace` protocol with axis info

### swift-w3c-svg

- [ ] Define `SVGSpace` marker enum
- [ ] Define `SVG` namespace with typealiases
- [ ] Add `.svg` context wrapper to geometry types
- [ ] Define `SVG.Styled.*` types (geometry + presentation)
- [ ] Add convenience extensions (`.filled()`, `.stroked()`)

### swift-w3c-css

- [ ] Define `CSSSpace` marker enum
- [ ] Define `CSS` namespace with typealiases
- [ ] Add `.css` context wrapper to geometry types
- [ ] Keep `CSS.Length` as separate domain-specific type
- [ ] Define `CSS.Clip.Path` with shape enum

### swift-whatwg-html

- [ ] Define `HTMLSpace` marker enum
- [ ] Define `HTML` namespace with typealiases
- [ ] Add `.html` context wrapper where needed

### swift-html (Integration Package)

- [ ] Add `SVG.Circle.css` → `CSS.Circle` conversion
- [ ] Add `CSS.Circle.svg` → `SVG.Circle` conversion
- [ ] Add viewport-aware transformations where needed

---

## Benefits Summary

1. **Single source of truth** - ONE Circle/Rectangle/Path definition
2. **Type safety** - `CSS.Width` ≠ `SVG.Width` (compile-time error)
3. **Clean syntax** - `CSS.Circle` instead of `Circle<CSSSpace>`
4. **Math operations** - area(), perimeter(), contains() available everywhere
5. **Context-specific serialization** - `.svg.element`, `.css.clip.path`
6. **Layered architecture** - Pure geometry → Styled types → Convenience
7. **Follows precedent** - Same pattern as ISO 32000 (PDF)

---

## Trade-offs

1. **Migration effort** - Existing types need updating
2. **Dependency** - Domain libraries depend on swift-standards Geometry
3. **Learning curve** - Developers need to understand the pattern
4. **Generic signatures** - Type signatures become more complex (mitigated by typealiases)

---

## References

| File | Description |
|------|-------------|
| `swift-standards/Sources/Dimension/Tagged+Arithmatic.swift` | Dimensional analysis |
| `swift-pdf-standard/Sources/PDF Standard/PDF.Rectangle.swift` | Styled type pattern |
| `swift-iso-32000/Sources/ISO 32000 Shared/ISO_32000.swift` | Namespace pattern |
| `swift-incits-4-1986/Sources/INCITS_4_1986/UInt8.ASCII.swift` | Context wrapper pattern |
| `swift-w3c-svg/Sources/W3C SVG/W3C_SVG2.GeometryTypes.swift` | Existing SVG integration |
