# Unified Geometry Types Implementation Plan

A phased implementation guide for integrating swift-standards Geometry types across SVG, CSS, and HTML libraries.

**IMPORTANT: This is a breaking change refactor. No backward compatibility will be maintained.**

---

## Migration Strategy

### Breaking Changes Policy

- **Delete** old type aliases, don't deprecate them
- **Remove** existing geometry types from SVG/CSS/HTML that will be replaced
- **Replace** with new unified types directly
- **Bump major version** on all affected packages

This keeps the codebase clean without legacy cruft.

---

## Current State Assessment

### swift-standards (Geometry Module)
**Status:** Complete and ready

- Full geometric primitives: `Ball<N>` (Circle, Sphere), `Orthotope<N>` (Rectangle, Cuboid), `Polygon`, `Ngon<N>`, `Path`, `Line`, `Ray`, `Arc`, `Ellipse`, `Bezier`
- Dimension types: `X`, `Y`, `Width`, `Height`, `Dx`, `Dy`, `Magnitude`, `Radius`, `Area`
- Space phantom type parameter for coordinate isolation
- Comprehensive arithmetic in `Tagged+Arithmatic.swift`

### swift-w3c-svg
**Status:** Partially integrated

- Already imports Geometry from swift-standards
- Has `W3C_SVG.Space` marker enum
- Type aliases exist but will be reorganized

### swift-w3c-css
**Status:** Independent implementation (will be refactored)

- Own `Length`, `Percentage`, `LengthPercentage` types (keep these - CSS-specific)
- Own `BasicShape` types (will be replaced with Geometry)
- No Space marker enum (will add)

### swift-whatwg-html
**Status:** Minimal geometry usage

- Has `Width`, `Height` for media attributes (will be replaced)

---

## Implementation Phases

```
Phase 1: Foundation (swift-standards)
    │
    ▼
Phase 2: SVG Integration (swift-w3c-svg)
    │
    ▼
Phase 3: CSS Integration (swift-w3c-css)
    │
    ▼
Phase 4: HTML Integration (swift-whatwg-html)
    │
    ▼
Phase 5: Cross-Domain (swift-html)
```

---

## Phase 1: Foundation (swift-standards)

**Goal:** Add space functor `map` overload to Geometry module (scalar functor already exists).

### 1.1 Two `map` Overloads (Both Called `map`)

Each geometry type gets two `map` methods distinguished by signature:

| Functor | Signature | Changes |
|---------|-----------|---------|
| **Scalar** (exists) | `(Scalar) -> R` | Numeric type |
| **Space** (new) | `(Point) -> Point'` | Coordinate space |

Swift disambiguates by closure parameter type. Tested and verified.

### 1.2 Add Space Functor `map` to Geometry Types

**Files to modify:**
- `/swift-standards/Sources/Geometry/Geometry.Ball.swift`
- `/swift-standards/Sources/Geometry/Geometry.Orthotope.swift`
- `/swift-standards/Sources/Geometry/Geometry.Polygon.swift`
- `/swift-standards/Sources/Geometry/Geometry.Ngon.swift`
- `/swift-standards/Sources/Geometry/Geometry.Path.swift`
- `/swift-standards/Sources/Geometry/Geometry.Line.swift`
- `/swift-standards/Sources/Geometry/Geometry.Arc.swift`
- `/swift-standards/Sources/Geometry/Geometry.Ellipse.swift`
- `/swift-standards/Sources/Geometry/Geometry.Bezier.swift`
- `/swift-standards/Sources/Geometry/Geometry.EdgeInsets.swift`

**Pattern:**
```swift
extension Geometry.Ball {
    // Scalar functor (EXISTING) - transforms numeric values
    public func map<R>(
        _ f: (Scalar) -> R
    ) -> Geometry<R, Space>.Ball<N> {
        .init(
            center: center.map(f),
            radius: radius.map(f)
        )
    }

    // Space functor (NEW) - transforms coordinate space
    public func map<T>(
        _ f: (Point<N>) -> Geometry<Scalar, T>.Point<N>
    ) -> Geometry<Scalar, T>.Ball<N> {
        .init(
            center: f(center),
            radius: radius.retagged()
        )
    }
}
```

**Implementation pattern for each type:**
- **Points:** Apply `f()` (the point transformation)
- **Scalars:** Apply `.retagged()` (change Space tag, keep value)

**Order:** Ball → Line.Segment → Arc → Ellipse → Orthotope → Polygon → Ngon → Path → Bezier → EdgeInsets

### 1.3 Optional: Add `CoordinateSpace` Protocol

**File to create:** `/swift-standards/Sources/Geometry/CoordinateSpace.swift`

```swift
public protocol CoordinateSpace {
    static var yAxis: Axis.Direction { get }
    static var origin: Origin.Convention { get }
}
```

---

## Phase 2: SVG Integration (swift-w3c-svg)

**Goal:** Create `SVG` namespace, add context wrappers, styled types, and convenience extensions.

### 2.1 Create SVG Namespace

**File to create:** `/swift-w3c-svg/Sources/W3C SVG/SVG.swift`

```swift
public enum SVG {
    public typealias Geometry = Swift.Geometry<Double, W3C_SVG.Space>
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
    public typealias Point = Geometry.Point<2>
    public typealias Vector = Geometry.Vector<2>
    public typealias Transform = Geometry.AffineTransform
}
```

### 2.2 Add Context Wrappers

**File to create:** `/swift-w3c-svg/Sources/W3C SVG/SVG.Context.swift`

```swift
extension Geometry.Circle where Space == W3C_SVG.Space {
    public var svg: SVG { SVG(self) }

    public struct SVG {
        let circle: Geometry<Double, W3C_SVG.Space>.Circle

        public var element: W3C_SVG2.Shapes.Circle? {
            guard circle.radius.value >= 0 else { return nil }
            return W3C_SVG2.Shapes.Circle(
                cx: circle.center.x,
                cy: circle.center.y,
                r: circle.radius
            )
        }
    }
}
```

### 2.3 Create Styled Domain Types

**File to create:** `/swift-w3c-svg/Sources/W3C SVG/SVG.Styled.swift`

```swift
extension SVG {
    public enum Styled {}
}

extension SVG.Styled {
    public struct Circle: Sendable, Hashable {
        public var geometry: SVG.Circle
        public var fill: W3C_SVG2.Types.Paint?
        public var stroke: Stroke?
    }
}
```

### 2.4 Add Convenience Extensions

**File to create:** `/swift-w3c-svg/Sources/W3C SVG/SVG.Convenience.swift`

```swift
extension SVG.Circle {
    public func filled(_ paint: W3C_SVG2.Types.Paint) -> SVG.Styled.Circle {
        SVG.Styled.Circle(geometry: self, fill: paint)
    }
}
```

### 2.5 Delete Old Type Aliases

**File to delete/clean:** `/swift-w3c-svg/Sources/W3C SVG/W3C_SVG2.GeometryTypes.swift`

Remove all old `W3C_SVG2.Rectangle`, `W3C_SVG2.Circle` typealiases. Users must use `SVG.*` namespace.

---

## Phase 3: CSS Integration (swift-w3c-css)

**Goal:** Add CSS namespace with geometry integration.

### 3.1 Create CSS Space Marker

**File to create:** `/swift-w3c-css/Sources/W3C CSS Shared/CSSSpace.swift`

```swift
public enum CSSSpace {}
```

### 3.2 Create CSS Namespace

**File to create:** `/swift-w3c-css/Sources/W3C CSS Shared/CSS.swift`

```swift
import Geometry

public enum CSS {
    public typealias Geometry = Swift.Geometry<Double, CSSSpace>
}

extension CSS {
    public typealias Circle = Geometry.Circle
    public typealias Ellipse = Geometry.Ellipse
    public typealias Rectangle = Geometry.Rectangle
    public typealias Polygon = Geometry.Polygon
    public typealias Path = Geometry.Path
    public typealias X = Geometry.X
    public typealias Y = Geometry.Y
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
    public typealias EdgeInsets = Geometry.EdgeInsets
    public typealias Point = Geometry.Point<2>
}
```

### 3.3 Add Context Wrappers

**File to create:** `/swift-w3c-css/Sources/W3C CSS Masking/CSS.Context.swift`

```swift
extension Geometry.Circle where Space == CSSSpace {
    public var css: CSS { CSS(self) }

    public struct CSS {
        let circle: Geometry<Double, CSSSpace>.Circle

        public var clip: Clip { Clip(circle) }

        public struct Clip {
            let circle: Geometry<Double, CSSSpace>.Circle

            public var path: String {
                "circle(\(circle.radius.value)px at \(circle.center.x.value)px \(circle.center.y.value)px)"
            }
        }
    }
}
```

### 3.4 Delete Old Shape Types

**Files to modify/delete:**
- `/swift-w3c-css/Sources/W3C CSS Values/BasicShape.swift` - Remove circle, ellipse, polygon (keep path for now)
- `/swift-w3c-css/Sources/W3C CSS Masking/ClipPath.swift` - Update to use `CSS.Circle`, etc.

**Keep:** `CSS.Length`, `CSS.Percentage`, `CSS.LengthPercentage` - these are CSS-specific value types.

### 3.5 Update Package.swift

Add Geometry dependency to W3C CSS Shared target.

---

## Phase 4: HTML Integration (swift-whatwg-html)

**Goal:** Add HTML namespace for dimensional types.

### 4.1 Create HTML Space Marker

**File to create:** `/swift-whatwg-html/Sources/WHATWG HTML/HTMLSpace.swift`

```swift
public enum HTMLSpace {}
```

### 4.2 Create HTML Namespace

**File to create:** `/swift-whatwg-html/Sources/WHATWG HTML/HTML.swift`

```swift
import Geometry

public enum HTML {
    public typealias Geometry = Swift.Geometry<Double, HTMLSpace>
}

extension HTML {
    public typealias Width = Geometry.Width
    public typealias Height = Geometry.Height
}
```

### 4.3 Add Context Wrapper

**File to create:** `/swift-whatwg-html/Sources/WHATWG HTML/HTML.Context.swift`

```swift
extension Geometry.Width where Space == HTMLSpace {
    public var html: HTML { HTML(self) }

    public struct HTML {
        let width: Geometry<Double, HTMLSpace>.Width
        public var attribute: String { "\(Int(width.value))" }
    }
}
```

### 4.4 Delete Old Types

Remove existing `Width`, `Height` types that will be replaced.

---

## Phase 5: Cross-Domain Integration (swift-html)

**Goal:** Enable conversion between spaces using the space functor `map`.

### 5.1 Add Conversions

**File to create:** `/swift-html/Sources/HTML/Geometry.Conversion.swift`

```swift
extension SVG.Circle {
    /// Convert to CSS coordinate space
    public var css: CSS.Circle {
        self.map { p in CSS.Point(x: p.x.value, y: p.y.value) }
    }
}

extension CSS.Circle {
    /// Convert to SVG coordinate space
    public var svg: SVG.Circle {
        self.map { p in SVG.Point(x: p.x.value, y: p.y.value) }
    }
}
```

---

## Files Summary

### Phase 1 (swift-standards)
- Modify: 10 geometry files to add space functor `map`
- Optional: Create `CoordinateSpace.swift`

### Phase 2 (swift-w3c-svg)
- Create: `SVG.swift`, `SVG.Context.swift`, `SVG.Styled.swift`, `SVG.Convenience.swift`
- Delete/Clean: `W3C_SVG2.GeometryTypes.swift`

### Phase 3 (swift-w3c-css)
- Create: `CSSSpace.swift`, `CSS.swift`, `CSS.Context.swift`
- Modify: `BasicShape.swift`, `ClipPath.swift`
- Modify: `Package.swift`

### Phase 4 (swift-whatwg-html)
- Create: `HTMLSpace.swift`, `HTML.swift`, `HTML.Context.swift`
- Delete: Old Width/Height types

### Phase 5 (swift-html)
- Create: `Geometry.Conversion.swift`

---

## Verification Checklist

### Phase 1 Complete When:
- [ ] All geometry types have space functor `map`
- [ ] Both `map` overloads disambiguate correctly
- [ ] Tests pass

### Phase 2 Complete When:
- [ ] `SVG.Circle` works
- [ ] `circle.svg.element` returns element
- [ ] `circle.filled(.red)` works
- [ ] Old aliases deleted

### Phase 3 Complete When:
- [ ] `CSS.Circle` works
- [ ] `circle.css.clip.path` returns CSS string
- [ ] Old BasicShape types deleted

### Phase 4 Complete When:
- [ ] `HTML.Width` works
- [ ] `width.html.attribute` works
- [ ] Old types deleted

### Phase 5 Complete When:
- [ ] `svgCircle.css` converts via `map`
- [ ] `cssCircle.svg` converts via `map`

---

## Getting Started

**First task:** Add space functor `map` to `Ball<N>` in `/swift-standards/Sources/Geometry/Geometry.Ball.swift`

```swift
// Add this alongside the existing scalar map
public func map<T>(
    _ f: (Point<N>) -> Geometry<Scalar, T>.Point<N>
) -> Geometry<Scalar, T>.Ball<N> {
    .init(
        center: f(center),
        radius: radius.retagged()
    )
}
```
