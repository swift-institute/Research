# Research: Unified Geometry Types Across SVG/CSS/HTML
<!--
---
version: 1.0.0
last_updated: 2026-03-15
status: COMPLETE
---
-->

## Question Being Researched

Can swift-standards types (Circle, Rectangle, Dx, Dy, EdgeInsets, etc.) **directly replace** the corresponding types in swift-w3c-css and swift-whatwg-html, so that a `Circle` is the same type everywhere?

---

## Answer: Yes, With Context Extensions

**Core Principle:** A `Circle` is a geometric primitive (center + radius). Whether it becomes an SVG element, CSS clip-path, or canvas drawing is just *how it's rendered* in that context.

```swift
// ONE Circle type from swift-standards
let circle: Geometry<Double, Space>.Ball<2> = .init(center: (100, 100), radius: 50)

// Context-specific rendering via INCITS pattern
circle.svg.element       // -> W3C_SVG2.Shapes.Circle element
circle.css.clip.path     // -> CSS clip-path: circle(50px at 100px 100px)
circle.canvas.draw(ctx)  // -> CGContext arc drawing
```

---

## Naming Convention

**Important:** This codebase follows a strict naming convention:
- **Never use compound names** for types or properties
- Use `Type.Wrapper` instead of `TypeWrapper`
- Use `curve.up` instead of `curveUp`
- For reserved name conflicts, use **backticks**: `Length.`Protocol`` and `Length.`Type``

This affects how context wrappers are named and accessed.

### Escaping Reserved Names with Backticks

Swift reserves `.Type` and `.Protocol` as metatype accessors. When you need nested types with these names, use backticks:

```swift
// ❌ BAD: These conflict with Swift's reserved metatype names
extension Length {
    struct Type { ... }      // Conflicts with Length.Type (metatype)
    struct Protocol { ... }  // Conflicts with Length.Protocol (protocol metatype)
}

// ✅ GOOD: Backticks escape the reserved names
extension Length {
    struct `Type` { ... }      // Length.`Type` - a nested struct
    struct `Protocol` { ... }  // Length.`Protocol` - a nested struct
}

// Usage
let lengthType: Length.`Type` = ...      // The nested struct
let metatype: Length.Type = Length.self  // The metatype (different thing)
```

This eliminates the need for compound names like `LengthType` or `LengthProtocol`.

---

## swift-standards Types Available for Unification

### Geometric Primitives

| swift-standards Type | Description | SVG Equivalent | CSS Equivalent | HTML Equivalent |
|---------------------|-------------|----------------|----------------|-----------------|
| `Geometry.Ball<2>` | Circle (center + radius) | `<circle>` element | `clip-path: circle()` | Canvas arc |
| `Geometry.Ellipse` | Ellipse with axes | `<ellipse>` element | `clip-path: ellipse()` | Canvas ellipse |
| `Geometry.Rectangle` | Axis-aligned rect | `<rect>` element | Various box properties | Canvas rect |
| `Geometry.Line.Segment` | Line between points | `<line>` element | - | Canvas line |
| `Geometry.Polygon` | N-vertex polygon | `<polygon>` element | `clip-path: polygon()` | Canvas path |
| `Geometry.Path` | General path | `<path>` element | `clip-path: path()` | Canvas path |
| `Geometry.Arc` | Circular arc | Path arc commands | - | Canvas arc |
| `Geometry.Ellipse.Arc` | Elliptical arc (SVG-compatible) | Path A command | - | - |
| `Geometry.EdgeInsets` | Top/Right/Bottom/Left | - | margin, padding | - |

### Dimension Types

| swift-standards Type | Description | SVG Use | CSS Use | HTML Use |
|---------------------|-------------|---------|---------|----------|
| `Coordinate.X<Space>` | X position | cx, x, x1, x2 | left, right | - |
| `Coordinate.Y<Space>` | Y position | cy, y, y1, y2 | top, bottom | - |
| `Displacement.X<Space>` | Dx offset | dx, translate-x | translateX | - |
| `Displacement.Y<Space>` | Dy offset | dy, translate-y | translateY | - |
| `Extent.X<Space>` | Width | width, rx | width | width attr |
| `Extent.Y<Space>` | Height | height, ry | height | height attr |
| `Magnitude<Space>` | Radius/length | r, stroke-width | border-radius | - |
| `Degree<Scalar>` | Angle in degrees | rotate | rotate() | - |
| `Radian<Scalar>` | Angle in radians | (internal math) | (internal math) | - |

### Transform Types

| swift-standards Type | SVG Use | CSS Use |
|---------------------|---------|---------|
| `Scale<2, Scalar>` | `scale(sx, sy)` | `scale(sx, sy)` |
| `AffineTransform` | `matrix(...)` | `matrix(...)` |

---

## How Unification Would Work

### Pattern 1: Geometry Primitive + Context Extensions (Nested Types)

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

    /// Nested context type (not SVGCircleContext!)
    public struct SVG {
        let circle: Geometry.Circle

        /// Convert to SVG circle element
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

    /// Nested context type (not CSSCircleContext!)
    public struct CSS {
        let circle: Geometry.Circle

        /// Access clip-path rendering
        public var clip: Clip { .init(circle) }

        /// Nested under CSS (not ClipPath!)
        public struct Clip {
            let circle: Geometry.Circle

            /// The path value for CSS clip-path
            public var path: String {
                "circle(\(circle.radius) at \(circle.center.x) \(circle.center.y))"
            }
        }
    }
}

// Usage follows dot notation:
circle.svg.element     // SVG element
circle.css.clip.path   // CSS clip-path value (not clipPath!)
```

### Pattern 2: Dimension Types with Context Serialization

```swift
// In swift-standards
public typealias Width<Space> = Tagged<Extent.X<Space>, Double>

// Usage in SVG
let rectWidth: Width<SVGSpace> = 100

// In swift-w3c-svg (extension)
extension Tagged where Tag == Extent.X<SVGSpace> {
    public var svg: SVG { .init(self) }

    /// Nested type (not SVGWidthContext!)
    public struct SVG {
        let width: Width<SVGSpace>
        public var attribute: String { "\(width.rawValue)" }  // unitless for SVG
    }
}

// In swift-w3c-css (extension)
extension Tagged where Tag == Extent.X<CSSSpace> {
    public var css: CSS { .init(self) }

    /// Nested type (not CSSWidthContext!)
    public struct CSS {
        let width: Width<CSSSpace>
        public var declaration: String { "\(width.rawValue)px" }  // with unit for CSS
    }
}
```

### Pattern 3: EdgeInsets → Margin/Padding (Dot Notation for Properties)

```swift
// In swift-standards
public struct EdgeInsets<Scalar, Space> {
    public var top: Height<Space>
    public var leading: Width<Space>
    public var bottom: Height<Space>
    public var trailing: Width<Space>
}

// In swift-w3c-css (extension)
extension Geometry.EdgeInsets where Space == CSSSpace {
    public var css: CSS { .init(self) }

    /// Nested type (not CSSEdgeInsetsContext!)
    public struct CSS {
        let insets: Geometry<Double, CSSSpace>.EdgeInsets

        /// Access margin formatting (not marginDeclaration!)
        public var margin: Margin { .init(insets) }

        /// Access padding formatting (not paddingDeclaration!)
        public var padding: Padding { .init(insets) }

        public struct Margin {
            let insets: Geometry<Double, CSSSpace>.EdgeInsets

            public var declaration: String {
                "margin: \(insets.top)px \(insets.trailing)px \(insets.bottom)px \(insets.leading)px"
            }
        }

        public struct Padding {
            let insets: Geometry<Double, CSSSpace>.EdgeInsets

            public var declaration: String {
                "padding: \(insets.top)px \(insets.trailing)px \(insets.bottom)px \(insets.leading)px"
            }
        }
    }
}

// Usage with dot notation:
let spacing: Geometry<Double, CSSSpace>.EdgeInsets = .init(all: 10)
spacing.css.margin.declaration   // "margin: 10px 10px 10px 10px"
spacing.css.padding.declaration  // "padding: 10px 10px 10px 10px"
```

---

## Summary Findings

### Current State of Each Library

| Library | Static Property | Namespace | swift-standards Integration |
|---------|----------------|-----------|----------------------------|
| **swift-w3c-svg** | `static var tag: Tag` | `W3C_SVG2` | Geometry + Formatting ✅ |
| **swift-w3c-css** | `static let property: String` | `W3C_CSS_*` | Formatting only |
| **swift-whatwg-html** | `static var tag: String` | `WHATWG_HTML` | Geometry (minimal) + Formatting (minimal) |

### Key Observation: No Direct Conflicts Currently

The libraries are **already well-separated** by module namespaces:
- SVG types: `W3C_SVG2.Shapes.Circle`
- CSS types: `W3C_CSS_Images.Fill`
- HTML types: `WHATWG_HTML.Image`

---

## Analysis: When Would `Type.svg.tag` Pattern Be Needed?

The INCITS pattern (`UInt8.ascii`) is useful when you have **a single type** that needs **context-specific behavior**:

```swift
// INCITS pattern
UInt8.ascii.A         // static: access ASCII constant
byte.ascii.isLetter   // instance: check byte property
```

### Scenario Where Conflicts Would Arise

If you create a **shared type** used across SVG/HTML/CSS contexts, you'd need disambiguation:

```swift
// Hypothetical shared Color type
struct Color {
    // CONFLICT: Which context's "tag" or "property"?
    static var tag: String { ??? }  // SVG? HTML?
    static var property: String { ??? }  // CSS?
}
```

**Solution with namespacing pattern (nested types, not compound names!):**
```swift
struct Color {
    // Namespaced access via computed properties
    static var svg: SVG.Type { SVG.self }
    static var html: HTML.Type { HTML.self }
    static var css: CSS.Type { CSS.self }

    /// Nested type (not SVGContext!)
    enum SVG {
        static var tag: Tag { .init(name: "color") }
    }

    /// Nested type (not HTMLContext!)
    enum HTML {
        static var tag: String { "color" }
    }

    /// Nested type (not CSSContext!)
    enum CSS {
        static var property: String { "color" }
    }
}

// Usage
Color.SVG.tag.name   // "color" for SVG (dot notation: tag.name, not tagName)
Color.CSS.property   // "color" for CSS
```

---

## Recommendation: Apply Pattern Selectively

### 1. Types That SHOULD Be Shared (Strong Candidates)

These types have overlapping semantics across SVG/CSS/HTML:

| Type | SVG Use | CSS Use | HTML Use |
|------|---------|---------|----------|
| **Length** | coordinates, dimensions | all dimensions | width/height attributes |
| **Angle** | rotations, arcs | transforms, gradients | - |
| **Color** | fill, stroke | all colors | - |
| **Percentage** | relative coords | relative sizes | - |
| **Transform** | transform attribute | transform property | - |

**For these types**, integrating with swift-standards Geometry/Formatting makes strong sense.

### 2. Types That SHOULD Stay Separate

Element types should remain in their own namespaces:
- `W3C_SVG2.Shapes.Circle` - SVG circle element
- `WHATWG_HTML.Image` - HTML img element
- These are fundamentally different things with different semantics

### 3. When `Type.context.property` Is Needed

Only needed when a **single shared type** needs **different behaviors** per context:

```swift
// If Length is shared between all three:
Length.svg.attribute    // how it serializes in SVG
Length.css.property     // how it serializes in CSS
Length.html.attribute   // how it serializes in HTML
```

---

## Current Integration Opportunities

### swift-w3c-css (Strong Candidate for Integration)

**Already has SVG-related CSS properties:**
- `Fill`, `Stroke`, `Stroke.Width` (not `StrokeWidth`!)
- `Cx`, `Cy`, `R`, `Rx`, `Ry`, `X`, `Y`
- These could **share types** with swift-w3c-svg

**Value types that could be shared:**
- `Length` (with units: px, em, rem, vw, vh, etc.)
- `Angle` (deg, rad, grad, turn)
- `Percentage`
- `Color`
- `Length.Percentage` (not `LengthPercentage` - union type)

**Current dependency:** Already imports `Formatting` from swift-standards

### swift-whatwg-html (Moderate Candidate)

**Already uses Geometry for:**
- `Width`, `Height` (MediaAttributes)
- `Col.Span`, `Row.Span`, `Span` (TableAttributes - not `ColSpan`/`RowSpan`!)

**Potential additions:**
- Could share `Length` type with CSS for width/height
- Could use `Formatting` more extensively

---

## Concrete Implementation Approach

### Option A: Keep Types Separate, Share via Protocols

```swift
// In swift-standards
protocol Length.Convertible {  // Not LengthConvertible!
    var length: Length.Value { get }
    var unit: Length.Unit { get }
}

// Each library implements its own Length conforming to protocol
// No namespace conflicts, but no direct reuse
```

### Option B: Shared Types with Context Namespacing (Recommended)

```swift
// In swift-standards (or a new swift-web-types package)
public struct Length: Sendable, Hashable {
    public let value: Double
    public let unit: Unit

    // Context-specific serialization via nested types
    public static var svg: SVG.Type { SVG.self }
    public static var css: CSS.Type { CSS.self }

    /// Nested type (not SVGContext!)
    public enum SVG {
        public static func format(_ length: Length) -> String { ... }
    }

    /// Nested type (not CSSContext!)
    public enum CSS {
        public static func format(_ length: Length) -> String { ... }
    }
}
```

### Option C: Shared Types, Same Serialization

If SVG and CSS use the same serialization for a type (e.g., both use `"10px"`), no namespacing needed:

```swift
// Simple shared type - no context needed
public struct Length: CustomStringConvertible {
    public var description: String { "\(value)\(unit.rawValue)" }
}
```

---

## Files to Reference

### INCITS Namespacing Pattern
`https://github.com/swift-standards/swift-incits-4-1986/blob/main/Sources/INCITS_4_1986/UInt8.ASCII.swift`

Key pattern:
```swift
extension UInt8 {
    public static var ascii: Binary.ASCII.Type { Binary.ASCII.self }  // static access
    public var ascii: Binary.ASCII { Binary.ASCII(byte: self) }       // instance access
}
```

### Existing Integration Examples
- **SVG Geometry**: `https://github.com/swift-standards/swift-w3c-svg/blob/main/Sources/W3C SVG/W3C_SVG2.GeometryTypes.swift`
- **HTML Geometry**: `https://github.com/swift-standards/swift-whatwg-html/blob/main/Sources/WHATWG HTML MediaAttributes/Width.swift`
- **CSS Formatting**: `https://github.com/swift-standards/swift-w3c-css/blob/main/Sources/W3C CSS Shared/exports.swift`

---

## Deep Dive: Unification Possibilities

### What's Possible: A Unified Type System

The goal: Create shared value types in swift-standards that work across SVG/CSS/HTML while remaining domain-specific where needed.

```
                     swift-standards
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         Geometry     Formatting    Dimension
              │            │            │
              └────────────┼────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   swift-w3c-svg    swift-w3c-css    swift-whatwg-html
```

---

## Benefits of Unification

### 1. Type Safety for Dimensions (Margins, Padding, etc.)

**Current State (CSS):**
```swift
// In swift-w3c-css, margin is just a string or enum
public enum Margin: Property {
    case length(Length)
    case auto
    // But Length is defined locally, not shared
}
```

**Unified Approach:**
```swift
// In swift-standards, define a type-safe margin system
public struct Margin<Space>: Sendable {
    public let top: Length<Space>
    public let right: Length<Space>
    public let bottom: Length<Space>
    public let left: Length<Space>
}

// CSS-specific space marker
public enum CSSSpace {}

// Usage becomes type-safe
let margin: Margin<CSSSpace> = .init(
    top: 10.px,
    right: 20.px,
    bottom: 10.px,
    left: 20.px
)

// Can't accidentally mix with SVG space
let svgMargin: Margin<SVGSpace> = ...  // Different type!
```

### 2. Shared Length with Domain-Specific Behavior

**The Key Insight:** Length VALUE is the same, but SERIALIZATION may differ.

```swift
// Shared Length in swift-standards
public struct Length<Space>: Sendable, Hashable {
    public let value: Double
    public let unit: Unit

    public enum Unit: String, Sendable {
        case px, em, rem, ex, ch
        case vw, vh, vmin, vmax
        case cm, mm, in, pt, pc, q
        case percent = "%"
    }
}

// Domain-specific extensions using nested types (not compound names!)
extension Length {
    /// CSS serialization context
    public var css: CSS { CSS(length: self) }

    /// SVG serialization context
    public var svg: SVG { SVG(length: self) }

    /// Nested type (not CSSContext!)
    public struct CSS {
        let length: Length
        public var declaration: String {
            "\(length.value)\(length.unit.rawValue)"
        }
    }

    /// Nested type (not SVGContext!)
    public struct SVG {
        let length: Length
        public var attribute: String {
            // SVG may format differently (e.g., no unit for userSpaceOnUse)
            length.unit == .px ? "\(length.value)" : "\(length.value)\(length.unit.rawValue)"
        }
    }
}

// Usage
let len: Length<CSSSpace> = 10.px
len.css.declaration  // "10px" - for CSS
len.svg.attribute    // "10" - for SVG (unitless when px)
```

### 3. Compile-Time Prevention of Domain Mixing

```swift
// Define space markers
public enum CSSSpace {}
public enum SVGSpace {}
public enum HTMLSpace {}

// Functions become type-safe
func setMargin(_ margin: Margin<CSSSpace>) { ... }
func setViewBox(_ rect: Rectangle<SVGSpace>) { ... }

// Compiler prevents mistakes
let cssMargin: Margin<CSSSpace> = ...
let svgRect: Rectangle<SVGSpace> = ...

setMargin(svgRect)  // ❌ Compile error: type mismatch
setViewBox(cssMargin)  // ❌ Compile error: type mismatch
```

### 4. Reusable Dimension Types

```swift
// Define once in swift-standards
public typealias X<Space> = Tagged<X.Tag, Length<Space>>
public typealias Y<Space> = Tagged<Y.Tag, Length<Space>>
public typealias Width<Space> = Tagged<Width.Tag, Length<Space>>
public typealias Height<Space> = Tagged<Height.Tag, Length<Space>>

// Use everywhere
// In SVG:
let circleX: X<SVGSpace> = 100.px
let circleY: Y<SVGSpace> = 50.px

// In CSS:
let boxWidth: Width<CSSSpace> = 200.px
let boxHeight: Height<CSSSpace> = 100.px

// In HTML:
let imgWidth: Width<HTMLSpace> = 640.px
let imgHeight: Height<HTMLSpace> = 480.px
```

---

## Trade-offs and Challenges

### 1. Complexity vs. Simplicity

**Trade-off:** More type safety = more complex type signatures

```swift
// Simple (current)
struct Circle {
    let cx: Double?
    let cy: Double?
    let r: Double?
}

// Type-safe (unified)
struct Circle<Space> {
    let cx: X<Space>?
    let cy: Y<Space>?
    let r: Radius<Space>?
}
```

**Mitigation:** Use typealiases to hide complexity at usage sites:
```swift
public typealias SVG.Circle = Circle<SVGSpace>
```

### 2. Generic Proliferation

**Challenge:** Generics can spread through the codebase

```swift
// One generic leads to more
struct Element<Space> {
    let transform: Transform<Space>?  // Now Transform needs Space
    let style: Style<Space>?          // Now Style needs Space
}
```

**Mitigation:** Use type erasure where appropriate:
```swift
// Type-erased wrapper for when you don't care about space
struct Any.Length: Sendable {  // Not AnyLength!
    private let _value: Double
    private let _unit: Length<Never>.Unit
}
```

### 3. Migration Effort

**Challenge:** Existing codebases need migration

**Current swift-w3c-css Length:**
```swift
public enum Length: Sendable, Hashable {
    case value(Double, Unit)
    // ... many cases
}
```

**Migration path:**
1. Create shared types in swift-standards
2. Add conformances/bridges in existing libraries
3. Deprecate old types gradually

### 4. Serialization Differences

**Challenge:** Same concept, different string formats

| Type | CSS Format | SVG Format | HTML Format |
|------|------------|------------|-------------|
| Length | `10px` | `10` (when px) | `10` (integer only) |
| Color | `rgb(255, 0, 0)` | `rgb(255, 0, 0)` or `#ff0000` | N/A |
| Angle | `45deg` | `45` (degrees implied) | N/A |

**Solution:** INCITS pattern for context-specific formatting:
```swift
length.css.format()   // "10px"
length.svg.format()   // "10"
length.html.format()  // "10"
```

---

## Concrete Examples

### Example 1: Unified Margin/Padding (Using Box.Spacing, not BoxSpacing!)

```swift
// In swift-standards/Dimension
extension Box {
    public struct Spacing<Space>: Sendable, Hashable {
        public let top: Length<Space>
        public let right: Length<Space>
        public let bottom: Length<Space>
        public let left: Length<Space>

        // Convenience initializers
        public init(all: Length<Space>) {
            self.init(top: all, right: all, bottom: all, left: all)
        }

        public init(vertical: Length<Space>, horizontal: Length<Space>) {
            self.init(top: vertical, right: horizontal, bottom: vertical, left: horizontal)
        }
    }
}

public typealias Margin<Space> = Box.Spacing<Space>
public typealias Padding<Space> = Box.Spacing<Space>

// CSS usage with nested types
extension Margin where Space == CSSSpace {
    public var css: CSS { CSS(self) }

    /// Nested type (not CSSMarginContext!)
    public struct CSS {
        let margin: Margin<CSSSpace>

        public var declaration: String {
            "margin: \(margin.top.css) \(margin.right.css) \(margin.bottom.css) \(margin.left.css)"
        }

        public static var property: String { "margin" }
    }
}
```

### Example 2: Unified Color Type (Using Color.Named, not NamedColor!)

```swift
// In swift-standards
public struct Color: Sendable, Hashable {
    public enum Value {
        case rgb(r: UInt8, g: UInt8, b: UInt8)
        case rgba(r: UInt8, g: UInt8, b: UInt8, a: Double)
        case hsl(h: Double, s: Double, l: Double)
        case named(Color.Named)  // Not NamedColor!
        case hex(String)
        case current
    }

    /// Named color enumeration (not NamedColor!)
    public enum Named: String {
        case red, green, blue, black, white
        // ... etc
    }

    public let value: Value

    // Context-specific serialization via nested types
    public var css: CSS { CSS(self) }
    public var svg: SVG { SVG(self) }

    /// Nested type (not CSSColorContext!)
    public struct CSS {
        let color: Color
        // CSS serializes as: rgb(255, 0, 0)
    }

    /// Nested type (not SVGColorContext!)
    public struct SVG {
        let color: Color
        // SVG may serialize as: #ff0000 or rgb(255, 0, 0)
    }
}
```

### Example 3: Unified Transform (Using Transform.Function, not TransformFunction!)

```swift
// Shared transform operations
extension Transform {
    /// Transform function enumeration (not TransformFunction!)
    public enum Function<Space>: Sendable {
        case translate(x: Length<Space>, y: Length<Space>)
        case rotate(angle: Angle)
        case scale(x: Double, y: Double)
        case skew(x: Angle)  // Not skewX!
        case skew(y: Angle)  // Not skewY!
        case matrix(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double)
    }
}

// CSS: transform: translate(10px, 20px) rotate(45deg)
// SVG: transform="translate(10 20) rotate(45)"
```

---

## Architecture Recommendation

### Layered Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    swift-standards                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Geometry   │  │  Dimension  │  │     Formatting      │ │
│  │ (Points,    │  │ (Length,    │  │  (Number formats,   │ │
│  │  Vectors,   │  │  Angle,     │  │   serialization)    │ │
│  │  Transforms)│  │  Color)     │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ swift-w3c-svg │    │ swift-w3c-css │    │swift-whatwg-  │
│               │    │               │    │    html       │
│ Uses:         │    │ Uses:         │    │ Uses:         │
│ - Geometry    │    │ - Dimension   │    │ - Dimension   │
│ - Dimension   │    │ - Formatting  │    │ - Formatting  │
│ - Formatting  │    │               │    │               │
│               │    │ Adds:         │    │ Adds:         │
│ Defines:      │    │ - CSS Props   │    │ - HTML Attrs  │
│ - SVGSpace    │    │ - CSSSpace    │    │ - HTMLSpace   │
│ - SVG Elements│    │ - Properties  │    │ - Elements    │
└───────────────┘    └───────────────┘    └───────────────┘
```

### Space Marker Pattern

```swift
// Each domain defines its space marker
// In swift-w3c-svg:
public enum SVGSpace {}

// In swift-w3c-css:
public enum CSSSpace {}

// In swift-whatwg-html:
public enum HTMLSpace {}

// Shared types become domain-specific via the space parameter
// Using typealiases inside namespaces (not compound names!)
extension SVG {
    public typealias Length = Standards.Length<SVGSpace>
}
extension CSS {
    public typealias Length = Standards.Length<CSSSpace>
}
extension HTML {
    public typealias Length = Standards.Length<HTMLSpace>
}
```

---

## Conclusion

### Is Unification Possible?
**Yes.** The architecture can support shared types with domain-specific behavior.

### Key Benefits
1. **Type safety**: Compile-time prevention of mixing domains
2. **Code reuse**: Define Length, Color, Angle once
3. **Consistency**: Same concepts use same underlying types
4. **Domain specificity**: INCITS pattern allows context-specific serialization

### Key Trade-offs
1. **Complexity**: More generics in type signatures
2. **Migration**: Existing code needs updates
3. **Learning curve**: Developers need to understand the pattern

### Recommended Next Steps (If Pursuing)
1. Start with `Length` as proof-of-concept
2. Add space markers to existing libraries
3. Use INCITS pattern for serialization contexts
4. Create typealiases to simplify common cases
5. Migrate gradually with deprecation warnings

---

## The Static Property Conflict Question

### When Does `Type.svg.tag` vs `Type.html.tag` Matter?

**Short answer:** Only when a SINGLE type has DIFFERENT static properties per context.

### Scenario Analysis

#### Scenario 1: Separate Element Types (Current State - No Conflict)

```swift
// SVG has its own Circle element
W3C_SVG2.Shapes.Circle  // has: static var tag: Tag (with tag.name)

// CSS has its own Circle (for clip-path)
W3C_CSS.Basic.Shape.Circle  // has: static var function: String { "circle" }

// These are DIFFERENT types, no conflict
```

#### Scenario 2: Shared Geometry Type (Proposed - Needs INCITS Pattern)

```swift
// ONE Circle type in swift-standards
Geometry<Double, Space>.Circle  // center + radius only, NO tag property

// Context-specific behavior via extensions with nested types
extension Geometry.Circle {
    public var svg: SVG { ... }   // provides .tag.name, .element
    public var css: CSS { ... }   // provides .function, .clip.path

    /// Nested type (not SVGContext!)
    public struct SVG { ... }

    /// Nested type (not CSSContext!)
    public struct CSS { ... }
}

// Usage
let circle = Geometry<Double, Space>.Circle(center: (100, 100), radius: 50)
circle.svg.tag.name  // "circle" (dot notation: tag.name, not tagName!)
circle.svg.element   // W3C_SVG2.Shapes.Circle

circle.css.function  // "circle"
circle.css.clip.path // "circle(50px at 100px 100px)" (dot notation: clip.path, not clipPath!)
```

### The Key Insight

**Geometry primitives (Circle, Rectangle, etc.) should NOT have a `tag` property.**

They are pure mathematical objects. The `tag`/`property` belongs to the *rendering context*, not the geometry.

```swift
// ✅ GOOD: Geometry is pure, context adds behavior
struct Circle<Space> {
    var center: Point
    var radius: Double
    // NO tag, NO property - just geometry
}

// SVG context adds element conversion
circle.svg.element  // W3C_SVG2.Shapes.Circle with tag.name

// CSS context adds clip-path conversion
circle.css.clip.path  // "circle(...)" (dot notation!)
```

```swift
// ❌ BAD: Geometry has context-specific properties
struct Circle<Space> {
    var center: Point
    var radius: Double
    static var tag: String { ??? }  // SVG? CSS? Which context?
}
```

### When INCITS Pattern IS Required

The pattern is needed when a type must have **different static constants** per context:

```swift
// Length needs different formatting per context
extension Length {
    public static var svg: SVG.Type { SVG.self }
    public static var css: CSS.Type { CSS.self }

    /// Nested type (not SVGLengthType!)
    public enum SVG {
        public static func format(_ length: Length) -> String {
            // SVG often uses unitless numbers for px
            "\(length.value)"
        }
    }

    /// Nested type (not CSSLengthType!)
    public enum CSS {
        public static func format(_ length: Length) -> String {
            // CSS requires explicit units
            "\(length.value)\(length.unit.rawValue)"
        }
    }
}

// Usage
Length.SVG.format(myLength)  // "100"
Length.CSS.format(myLength)  // "100px"
```

---

## Concrete Comparison: Before vs After Unification

### Before: Types Defined Separately in Each Library

```swift
// In swift-w3c-svg
extension W3C_SVG2.Shapes {
    public struct Circle {
        public let cx: W3C_SVG2.X?
        public let cy: W3C_SVG2.Y?
        public let r: W3C_SVG2.Radius?
    }
}

// In swift-w3c-css
extension W3C_CSS_Images {
    public struct Cx: Property {  // Different type!
        public static let property = "cx"
        public var value: Length.Percentage  // Not LengthPercentage!
    }
}

// In swift-whatwg-html
extension WHATWG_HTML {
    public struct Width: String.Attribute {  // Not StringAttribute!
        public static var attribute = "width"
        public var rawValue: String
    }
}
```

**Problems:**
- Three different `Width` types
- Can't share geometry between contexts
- Duplication of similar concepts

### After: Unified Types with Namespace Pattern (ISO 32000 Style)

**The ISO 32000 pattern** (from `https://github.com/swift-standards/swift-iso-32000`) provides convenient namespace access:

```swift
// ISO 32000 pattern example:
public typealias UserSpace = Geometry<Double, ISO_32000_Shared.UserSpace>

// Then you can write:
ISO_32000.UserSpace.Rectangle  // instead of Geometry<Double, UserSpace>.Rectangle
```

**Applied to CSS/SVG/HTML:**

```swift
// ═══════════════════════════════════════════════════════════════
// In swift-w3c-css
// ═══════════════════════════════════════════════════════════════

/// CSS coordinate space marker
public enum CSSSpace {}

/// CSS namespace providing convenient access to geometry types
public enum CSS {
    /// CSS-specialized geometry types
    public typealias Geometry = Swift.Geometry<Double, CSSSpace>
}

extension CSS {
    // Shapes
    public typealias Circle = Geometry.Circle
    public typealias Rectangle = Geometry.Rectangle
    public typealias Ellipse = Geometry.Ellipse
    public typealias Polygon = Geometry.Polygon
    public typealias Path = Geometry.Path

    // Dimensions
    public typealias X = Geometry.X
    public typealias Y = Geometry.Y
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
    public typealias Radius = Geometry.Radius

    // Layout
    public typealias EdgeInsets = Geometry.EdgeInsets
    public typealias Point = Geometry.Point
}

// ═══════════════════════════════════════════════════════════════
// In swift-w3c-svg
// ═══════════════════════════════════════════════════════════════

/// SVG coordinate space marker
public enum SVGSpace {}

/// SVG namespace providing convenient access to geometry types
public enum SVG {
    public typealias Geometry = Swift.Geometry<Double, SVGSpace>
}

extension SVG {
    public typealias Circle = Geometry.Circle
    public typealias Rectangle = Geometry.Rectangle
    public typealias Ellipse = Geometry.Ellipse
    public typealias Line = Geometry.Line.Segment
    public typealias Polygon = Geometry.Polygon
    public typealias Path = Geometry.Path

    public typealias X = Geometry.X
    public typealias Y = Geometry.Y
    public typealias Dx = Geometry.Dx
    public typealias Dy = Geometry.Dy
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
    public typealias Radius = Geometry.Radius
}

// ═══════════════════════════════════════════════════════════════
// In swift-whatwg-html
// ═══════════════════════════════════════════════════════════════

/// HTML coordinate space marker
public enum HTMLSpace {}

/// HTML namespace providing convenient access to dimension types
public enum HTML {
    public typealias Geometry = Swift.Geometry<Double, HTMLSpace>
}

extension HTML {
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
}
```

**Usage becomes beautifully clean:**

```swift
// CSS
let circle: CSS.Circle = .init(center: (100, 100), radius: 50)
let margin: CSS.EdgeInsets = .init(all: 10)
let width: CSS.Width = 200

// SVG
let svgCircle: SVG.Circle = .init(center: (50, 50), radius: 25)
let translateX: SVG.Dx = 10
let translateY: SVG.Dy = 20

// HTML
let imgWidth: HTML.Width = 640
let imgHeight: HTML.Height = 480

// Type safety preserved - these are different types!
let cssWidth: CSS.Width = 100
let svgWidth: SVG.Width = 100
// cssWidth == svgWidth  // ❌ Compile error: different types
```

**Benefits:**
- Clean namespace syntax: `CSS.Circle` instead of `Circle<CSSSpace>`
- ONE underlying type (swift-standards Geometry)
- Type safety: `CSS.Width` ≠ `SVG.Width` ≠ `HTML.Width`
- Context extensions still work: `circle.css.clip.path` (dot notation!)
- Follows established ISO 32000 pattern

---

## Final Conclusion

### Can We Unify Types Across SVG/CSS/HTML?

**Yes.** Using the ISO 32000 namespace pattern provides clean, convenient access.

### The Recommended Pattern

```swift
// Clean namespace syntax (ISO 32000 style)
CSS.Circle      // instead of Circle<CSSSpace>
SVG.Rectangle   // instead of Rectangle<SVGSpace>
HTML.Width      // instead of Width<HTMLSpace>

// All backed by ONE swift-standards Geometry type
```

**Architecture:**

1. **swift-standards** defines generic `Geometry<Scalar, Space>` types
2. **Each library** creates a namespace enum (CSS, SVG, HTML)
3. **Each namespace** has typealiases specializing Geometry for its space
4. **Context extensions** add `.svg`, `.css`, `.html` for serialization when needed

### Is `Type.svg.tag` Needed?

**No, for geometric primitives** - they're pure math, no tags.

**Yes, for serialization** - when the same value formats differently:
- `length.svg.attribute` → `"100"` (unitless)
- `length.css.declaration` → `"100px"` (with unit)

### Benefits

1. **Clean syntax**: `CSS.Circle` is natural and readable
2. **Single source of truth**: ONE Circle/Rectangle/Path definition
3. **Type safety**: `CSS.Width` ≠ `SVG.Width` (compile-time error)
4. **Math operations**: area(), perimeter(), contains() available everywhere
5. **Follows precedent**: Same pattern as ISO 32000 (PDF)

### Trade-offs

1. **Migration effort**: Existing types need updating
2. **Dependency**: CSS/HTML libraries depend on swift-standards Geometry
3. **Learning curve**: Developers need to understand the pattern

### Naming Convention Compliance

All types and properties follow the dot notation convention:
- `Circle.SVG` not `SVGCircleContext`
- `Length.CSS` not `CSSLengthType`
- `clip.path` not `clipPath`
- `tag.name` not `tagName`
- `Color.Named` not `NamedColor`
- `Transform.Function` not `TransformFunction`
- `Box.Spacing` not `BoxSpacing`

### Reference Files

- ISO 32000 pattern: `https://github.com/swift-standards/swift-iso-32000/blob/main/Sources/ISO 32000 Shared/ISO_32000.swift`
- Existing SVG integration: `https://github.com/swift-standards/swift-w3c-svg/blob/main/Sources/W3C SVG/W3C_SVG2.GeometryTypes.swift`
- INCITS namespacing pattern: `https://github.com/swift-standards/swift-incits-4-1986/blob/main/Sources/INCITS_4_1986/UInt8.ASCII.swift`
