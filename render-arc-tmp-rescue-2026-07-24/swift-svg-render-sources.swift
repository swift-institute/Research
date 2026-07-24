# swift-svg-render

## Package Manifest

// swift-tools-version: 6.3.3

import PackageDescription

extension String {
    static let svgRendering: Self = "SVG Rendering"
    var tests: Self { self + " Tests" }
}

extension Target.Dependency {
    static var svgRendering: Self { .target(name: .svgRendering) }
}

extension Target.Dependency {
    static var renderingPrimitives: Self {
        .product(name: "Render Primitives", package: "swift-render-primitives")
    }
    static var svgStandard: Self {
        .product(name: "SVG Standard", package: "swift-svg-standard")
    }
    static var asciiPrimitives: Self {
        .product(name: "ASCII Primitives", package: "swift-ascii-primitives")
    }
    static var formatting: Self {
        .product(name: "Format Primitives", package: "swift-format-primitives")
    }
    static var dimension: Self {
        .product(name: "Dimension Primitives", package: "swift-dimension-primitives")
    }
    static var dictionaryPrimitives: Self {
        .product(name: "Dictionary Primitives", package: "swift-dictionary-primitives")
    }
    static var sharedPrimitive: Self {
        .product(name: "Ownership Shared Primitive", package: "swift-ownership-shared-primitives")
    }
    static var hashIndexedPrimitive: Self {
        .product(name: "Hash Indexed Primitive", package: "swift-hash-table-primitives")
    }
    static var columnPrimitives: Self {
        .product(name: "Column Primitives", package: "swift-column-primitives")
    }
    static var hashPrimitives: Self {
        .product(name: "Hash Primitives", package: "swift-hash-primitives")
    }
    static var bufferLinearPrimitive: Self {
        .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives")
    }
}

let package = Package(
    name: "swift-svg-render",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: .svgRendering, targets: [.svgRendering]),
        .library(name: "SVG Rendering Test Support", targets: ["SVG Rendering Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-render-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-svg-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-format-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-dimension-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ascii-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-dictionary-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-dictionary-ordered-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ownership-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-table-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-column-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: .svgRendering,
            dependencies: [
                .renderingPrimitives,
                .svgStandard,
                .asciiPrimitives,
                .formatting,
                .dimension,
                .dictionaryPrimitives,
                .product(name: "Dictionary Ordered Primitives", package: "swift-dictionary-ordered-primitives"),
                .sharedPrimitive,
                .hashIndexedPrimitive,
                .columnPrimitives,
                .hashPrimitives,
                .bufferLinearPrimitive,
            ]
        ),
        .target(
            name: "SVG Rendering Test Support",
            dependencies: [
                .svgRendering,
                .product(name: "Dimension Primitives Test Support", package: "swift-dimension-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: .svgRendering.tests,
            dependencies: [
                .svgRendering,
                "SVG Rendering Test Support",
            ],
            path: "Tests/SVG Rendering Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}

## File Structure

~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/Never+SVG.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/Optional+SVG.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/RangeReplaceableCollection UInt8 +SVG.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.AnyView.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Attributes.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Builder.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Context.Attributes.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Context.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Element.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Elements.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Empty.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.GeometryContext.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Group.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Raw.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.Text.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG.View.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG._Array.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG._Attributes.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG._Conditional.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/SVG._Tuple.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/String+SVG.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/StringProtocol+SVG.swift
~/Developer/swift-foundations/swift-svg-render/Sources/SVG Rendering/exports.swift

## Source Files

### File: Sources/SVG Rendering/Never+SVG.swift

//
//  Never+SVG.swift
//  swift-svg-rendering
//

extension Never: SVG.View {
    @inlinable
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ markup: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {}
}

### File: Sources/SVG Rendering/Optional+SVG.swift

//
//  Optional+SVG.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

/// Allows optional values to be used as SVG elements.
///
/// This conformance allows for convenient handling of optional SVG content,
/// where `nil` values simply render nothing.
extension Optional: SVG.View where Wrapped: SVG.View {
    /// Renders the optional SVG element if it exists.
    ///
    /// - Parameters:
    ///   - svg: The optional SVG to render.
    ///   - buffer: The buffer to render the SVG into.
    ///   - context: The rendering context.
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        guard let svg else { return }
        Wrapped._render(svg, into: &buffer, context: &context)
    }

    /// This type uses direct rendering and doesn't have a body.
    public var body: Never { fatalError("body should not be called") }
}

### File: Sources/SVG Rendering/RangeReplaceableCollection UInt8 +SVG.swift

//
//  RangeReplaceableCollection<UInt8>+SVG.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

public import Render_Primitives

extension RangeReplaceableCollection<UInt8> {
    /// Creates a byte collection from rendered SVG.
    ///
    /// This is the canonical way to render SVG to bytes when you need the
    /// complete document. Works with any `RangeReplaceableCollection<UInt8>`.
    ///
    /// ## When to Use
    ///
    /// Use `[UInt8](svg)` when:
    /// - You need the complete document
    /// - The document is small to medium sized
    /// - Simplicity is preferred over streaming
    ///
    /// ## Canonical Usage
    ///
    /// ```swift
    /// let bytes = [UInt8](myIcon)
    /// ```
    ///
    /// - Parameters:
    ///   - view: The SVG content to render to bytes
    ///   - configuration: Rendering configuration. Uses default if nil.
    @inlinable
    public init<View: SVG.View>(
        _ view: View,
        configuration: SVG.Context.Configuration? = nil
    ) {
        var buffer = Self()
        var context = SVG.Context(configuration ?? .default)
        View._render(view, into: &buffer, context: &context)
        self = buffer
    }
}

extension RangeReplaceableCollection<UInt8> {
    /// Asynchronously render SVG to a byte collection.
    ///
    /// This yields to the scheduler during rendering to avoid blocking,
    /// making it suitable for use in async contexts where responsiveness matters.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let icon = circle(cx: 50, cy: 50, r: 40)
    /// let bytes: [UInt8] = await .init(icon)
    /// ```
    ///
    /// - Parameters:
    ///   - view: The SVG content to render.
    ///   - configuration: Rendering configuration. Uses default if nil.
    @inlinable
    public init<View: SVG.View>(
        _ view: View,
        configuration: SVG.Context.Configuration? = nil
    ) async {
        await Task.yield()
        var buffer = Self()
        var context = SVG.Context(configuration ?? .default)
        View._render(view, into: &buffer, context: &context)
        self = buffer
    }
}

### File: Sources/SVG Rendering/SVG.AnyView.swift

//
//  SVG.AnyView.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

// swiftlint:disable no_any_protocol_existential
// reason: AnyView is SVG's type-erasure wrapper — its stored `base` and
// both initializers must accept any conforming SVG.View at the call site;
// `some SVG.View` would fix a single concrete type and defeat the eraser.
/// Type-erased SVG element that can hold any SVG content.
extension SVG {
    public struct AnyView: SVG.View {
        let base: any SVG.View

        public init(_ base: any SVG.View) {
            self.base = base
        }
    }
}

extension SVG.AnyView {
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: SVG.AnyView,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        func render<T: SVG.View>(_ element: T) {
            T._render(element, into: &buffer, context: &context)
        }
        render(svg.base)
    }

    public var body: Never { fatalError("body should not be called") }
}

extension SVG.AnyView {
    public init(_ closure: () -> any SVG.View) {
        self = .init(closure())
    }
}
// swiftlint:enable no_any_protocol_existential

### File: Sources/SVG Rendering/SVG.Attributes.swift

//
//  SVG.Attributes.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp
//

import Format_Primitives
public import SVG_Standard

// MARK: - Presentation Attributes

extension SVG.View {
    /// Sets the fill color of the SVG element.
    public func fill(_ color: String) -> SVG._Attributes<Self> {
        attribute("fill", color)
    }

    /// Sets the stroke color of the SVG element.
    public func stroke(_ color: String) -> SVG._Attributes<Self> {
        attribute("stroke", color)
    }

    /// Sets the stroke color and width of the SVG element.
    public func stroke(_ color: String?, width: Double?) -> SVG._Attributes<Self> {
        attribute("stroke", color)
            .attribute("stroke-width", width?.formatted(.number))
    }

    /// Sets the stroke width of the SVG element.
    public func strokeWidth(_ width: Double?) -> SVG._Attributes<Self> {
        attribute("stroke-width", width?.formatted(.number))
    }

    /// Sets the opacity of the SVG element.
    public func opacity(_ value: Double?) -> SVG._Attributes<Self> {
        attribute("opacity", value)
    }

    /// Sets the fill opacity of the SVG element.
    public func fillOpacity(_ value: Double?) -> SVG._Attributes<Self> {
        attribute("fill-opacity", value)
    }

    /// Sets the stroke opacity of the SVG element.
    public func strokeOpacity(_ value: Double?) -> SVG._Attributes<Self> {
        attribute("stroke-opacity", value)
    }

    /// Sets the stroke line cap of the SVG element.
    public func strokeLinecap(_ value: String) -> SVG._Attributes<Self> {
        attribute("stroke-linecap", value)
    }

    /// Sets the stroke line join of the SVG element.
    public func strokeLinejoin(_ value: String) -> SVG._Attributes<Self> {
        attribute("stroke-linejoin", value)
    }

    /// Sets the stroke dash array of the SVG element.
    public func strokeDasharray(_ value: String) -> SVG._Attributes<Self> {
        attribute("stroke-dasharray", value)
    }

    /// Sets the stroke dash offset of the SVG element.
    public func strokeDashoffset(_ value: Double?) -> SVG._Attributes<Self> {
        attribute("stroke-dashoffset", value)
    }

    /// Sets the fill rule of the SVG element.
    public func fillRule(_ value: String) -> SVG._Attributes<Self> {
        attribute("fill-rule", value)
    }
}

// MARK: - Transform Attributes

extension SVG.View {
    /// Sets the transform attribute of the SVG element.
    public func transform(_ value: String) -> SVG._Attributes<Self> {
        attribute("transform", value)
    }

    /// Applies a translation transform to the SVG element.
    public func translate(x: Double = 0, y: Double = 0) -> SVG._Attributes<Self> {
        attribute("transform", "translate(\(x.formatted(.number)), \(y.formatted(.number)))")
    }

    /// Applies a rotation transform to the SVG element.
    public func rotate(
        _ angle: Double,
        cx: Double? = nil,
        cy: Double? = nil
    ) -> SVG._Attributes<Self> {
        if let cx, let cy {
            return attribute(
                "transform",
                "rotate(\(angle.formatted(.number)), \(cx.formatted(.number)), \(cy.formatted(.number)))"
            )
        }
        return attribute("transform", "rotate(\(angle.formatted(.number)))")
    }

    /// Applies a scale transform to the SVG element.
    public func scale(x: Double, y: Double? = nil) -> SVG._Attributes<Self> {
        if let y {
            return attribute("transform", "scale(\(x.formatted(.number)), \(y.formatted(.number)))")
        }
        return attribute("transform", "scale(\(x.formatted(.number)))")
    }

    /// Applies a skewX transform to the SVG element.
    public func skewX(
        _ angle: Double
    ) -> SVG._Attributes<Self> {
        attribute("transform", "skewX(\(angle.formatted(.number)))")
    }

    /// Applies a skewY transform to the SVG element.
    public func skewY(
        _ angle: Double
    ) -> SVG._Attributes<Self> {
        attribute("transform", "skewY(\(angle.formatted(.number)))")
    }
}

// MARK: - Common Attributes

extension SVG.View {
    /// Sets the id attribute of the SVG element.
    public func id(_ value: String) -> SVG._Attributes<Self> {
        attribute("id", value)
    }

    /// Sets the class attribute of the SVG element.
    public func `class`(_ value: String) -> SVG._Attributes<Self> {
        attribute("class", value)
    }

    /// Sets the style attribute of the SVG element.
    public func style(_ value: String) -> SVG._Attributes<Self> {
        attribute("style", value)
    }

    /// Sets the clip-path attribute of the SVG element.
    public func clipPath(_ value: String) -> SVG._Attributes<Self> {
        attribute("clip-path", value)
    }

    /// Sets the mask attribute of the SVG element.
    public func mask(_ value: String) -> SVG._Attributes<Self> {
        attribute("mask", value)
    }

    /// Sets the filter attribute of the SVG element.
    public func filter(_ value: String) -> SVG._Attributes<Self> {
        attribute("filter", value)
    }
}

// MARK: - Text Attributes

extension SVG.View {
    /// Sets the font-family attribute of the SVG element.
    public func fontFamily(_ value: String) -> SVG._Attributes<Self> {
        attribute("font-family", value)
    }

    /// Sets the font-size attribute of the SVG element.
    public func fontSize(_ value: Double?) -> SVG._Attributes<Self> {
        attribute("font-size", value)
    }

    /// Sets the font-size attribute of the SVG element with a string value.
    public func fontSize(_ value: String) -> SVG._Attributes<Self> {
        attribute("font-size", value)
    }

    /// Sets the font-weight attribute of the SVG element.
    public func fontWeight(_ value: String) -> SVG._Attributes<Self> {
        attribute("font-weight", value)
    }

    /// Sets the font-style attribute of the SVG element.
    public func fontStyle(_ value: String) -> SVG._Attributes<Self> {
        attribute("font-style", value)
    }

    /// Sets the text-anchor attribute of the SVG element.
    public func textAnchor(_ value: String) -> SVG._Attributes<Self> {
        attribute("text-anchor", value)
    }

    /// Sets the dominant-baseline attribute of the SVG element.
    public func dominantBaseline(_ value: String) -> SVG._Attributes<Self> {
        attribute("dominant-baseline", value)
    }
}

// MARK: - Marker Attributes

extension SVG.View {
    /// Sets the marker-start attribute of the SVG element.
    public func markerStart(_ value: String) -> SVG._Attributes<Self> {
        attribute("marker-start", value)
    }

    /// Sets the marker-mid attribute of the SVG element.
    public func markerMid(_ value: String) -> SVG._Attributes<Self> {
        attribute("marker-mid", value)
    }

    /// Sets the marker-end attribute of the SVG element.
    public func markerEnd(_ value: String) -> SVG._Attributes<Self> {
        attribute("marker-end", value)
    }
}

// MARK: - Geometry Attributes (Shapes)

extension SVG.View {
    /// Sets the cx attribute (center x-coordinate).
    public func cx(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("cx", value)
    }

    /// Sets the cy attribute (center y-coordinate).
    public func cy(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("cy", value)
    }

    /// Sets the r attribute (radius).
    public func r(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("r", value)
    }

    /// Sets the r attribute (radius) as a string.
    public func r(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("r", value)
    }

    /// Sets the rx attribute (x-axis radius).
    public func rx(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("rx", value)
    }

    /// Sets the ry attribute (y-axis radius).
    public func ry(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("ry", value)
    }

    /// Sets the x attribute.
    public func x(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("x", value)
    }

    /// Sets the x attribute as a string (for lengths with units).
    public func x(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("x", value)
    }

    /// Sets the y attribute.
    public func y(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("y", value)
    }

    /// Sets the y attribute as a string (for lengths with units).
    public func y(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("y", value)
    }

    /// Sets the width attribute.
    public func width(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("width", value)
    }

    /// Sets the width attribute as a string (for lengths with units).
    public func width(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("width", value)
    }

    /// Sets the height attribute.
    public func height(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("height", value)
    }

    /// Sets the height attribute as a string (for lengths with units).
    public func height(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("height", value)
    }

    /// Sets the x1 attribute (line start x-coordinate).
    public func x1(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("x1", value)
    }

    /// Sets the x1 attribute as a string.
    public func x1(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("x1", value)
    }

    /// Sets the y1 attribute (line start y-coordinate).
    public func y1(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("y1", value)
    }

    /// Sets the y1 attribute as a string.
    public func y1(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("y1", value)
    }

    /// Sets the x2 attribute (line end x-coordinate).
    public func x2(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("x2", value)
    }

    /// Sets the x2 attribute as a string.
    public func x2(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("x2", value)
    }

    /// Sets the y2 attribute (line end y-coordinate).
    public func y2(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("y2", value)
    }

    /// Sets the y2 attribute as a string.
    public func y2(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("y2", value)
    }

    /// Sets the points attribute (for polygon/polyline).
    public func points(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("points", value)
    }

    /// Sets the d attribute (path data).
    public func d(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("d", value)
    }

    /// Sets the pathLength attribute.
    public func pathLength(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("pathLength", value)
    }
}

// MARK: - Viewport Attributes

extension SVG.View {
    /// Sets the viewBox attribute.
    public func viewBox(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("viewBox", value)
    }

    /// Sets the viewBox attribute from individual values.
    public func viewBox(
        minX: Double,
        minY: Double,
        width: Double,
        height: Double
    ) -> SVG._Attributes<Self> {
        attribute(
            "viewBox",
            "\(minX.formatted(.number)) \(minY.formatted(.number)) \(width.formatted(.number)) \(height.formatted(.number))"
        )
    }

    /// Sets the preserveAspectRatio attribute.
    public func preserveAspectRatio(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("preserveAspectRatio", value)
    }

    /// Sets the xmlns attribute.
    public func xmlns(_ value: String) -> SVG._Attributes<Self> {
        attribute("xmlns", value)
    }
}

// MARK: - Reference Attributes

extension SVG.View {
    /// Sets the href attribute.
    public func href(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("href", value)
    }

    /// Sets the xlink:href attribute (legacy).
    public func xlinkHref(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("xlink:href", value)
    }

    /// Sets the target attribute.
    public func target(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("target", value)
    }

    /// Sets the download attribute.
    public func download(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("download", value)
    }

    /// Sets the rel attribute.
    public func rel(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("rel", value)
    }

    /// Sets the hreflang attribute.
    public func hreflang(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("hreflang", value)
    }

    /// Sets the type attribute.
    public func type(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("type", value)
    }
}

// MARK: - Gradient Attributes

extension SVG.View {
    /// Sets the gradientUnits attribute.
    public func gradientUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("gradientUnits", value)
    }

    /// Sets the gradientTransform attribute.
    public func gradientTransform(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("gradientTransform", value)
    }

    /// Sets the spreadMethod attribute.
    public func spreadMethod(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("spreadMethod", value)
    }

    /// Sets the offset attribute (for gradient stops).
    public func offset(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("offset", value)
    }

    /// Sets the stop-color attribute.
    public func stopColor(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("stop-color", value)
    }

    /// Sets the stop-opacity attribute.
    public func stopOpacity(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("stop-opacity", value)
    }

    /// Sets the fx attribute (radial gradient focal point x).
    public func fx(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("fx", value)
    }

    /// Sets the fy attribute (radial gradient focal point y).
    public func fy(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("fy", value)
    }

    /// Sets the fr attribute (radial gradient focal radius).
    public func fr(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("fr", value)
    }
}

// MARK: - Pattern Attributes

extension SVG.View {
    /// Sets the patternUnits attribute.
    public func patternUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("patternUnits", value)
    }

    /// Sets the patternContentUnits attribute.
    public func patternContentUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("patternContentUnits", value)
    }

    /// Sets the patternTransform attribute.
    public func patternTransform(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("patternTransform", value)
    }
}

// MARK: - Clipping and Masking Attributes

extension SVG.View {
    /// Sets the clipPathUnits attribute.
    public func clipPathUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("clipPathUnits", value)
    }

    /// Sets the maskUnits attribute.
    public func maskUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("maskUnits", value)
    }

    /// Sets the maskContentUnits attribute.
    public func maskContentUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("maskContentUnits", value)
    }
}

// MARK: - Marker Element Attributes

extension SVG.View {
    /// Sets the refX attribute.
    public func refX(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("refX", value)
    }

    /// Sets the refX attribute as a string.
    public func refX(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("refX", value)
    }

    /// Sets the refY attribute.
    public func refY(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("refY", value)
    }

    /// Sets the refY attribute as a string.
    public func refY(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("refY", value)
    }

    /// Sets the markerWidth attribute.
    public func markerWidth(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("markerWidth", value)
    }

    /// Sets the markerHeight attribute.
    public func markerHeight(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("markerHeight", value)
    }

    /// Sets the markerUnits attribute.
    public func markerUnits(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("markerUnits", value)
    }

    /// Sets the orient attribute.
    public func orient(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("orient", value)
    }
}

// MARK: - Text Element Attributes

extension SVG.View {
    /// Sets the dx attribute (text offset x).
    public func dx(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("dx", value)
    }

    /// Sets the dx attribute as a string.
    public func dx(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("dx", value)
    }

    /// Sets the dy attribute (text offset y).
    public func dy(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("dy", value)
    }

    /// Sets the dy attribute as a string.
    public func dy(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("dy", value)
    }

    /// Sets the textLength attribute.
    public func textLength(_ value: Double?) -> SVG._Attributes<Self> {
        return attribute("textLength", value)
    }

    /// Sets the textLength attribute as a string.
    public func textLength(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("textLength", value)
    }

    /// Sets the lengthAdjust attribute.
    public func lengthAdjust(_ value: String?) -> SVG._Attributes<Self> {
        return attribute("lengthAdjust", value)
    }
}

// MARK: - Typed Geometry Attributes (from swift-standards)

extension SVG.View {
    /// Sets the x attribute from a typed X coordinate.
    public func x(_ value: W3C_SVG2.X?) -> SVG._Attributes<Self> {
        return attribute("x", value)
    }

    /// Sets the y attribute from a typed Y coordinate.
    public func y(_ value: W3C_SVG2.Y?) -> SVG._Attributes<Self> {
        return attribute("y", value)
    }

    /// Sets the width attribute from a typed Width.
    public func width(_ value: W3C_SVG2.Width?) -> SVG._Attributes<Self> {
        return attribute("width", value)
    }

    /// Sets the height attribute from a typed Height.
    public func height(_ value: W3C_SVG2.Height?) -> SVG._Attributes<Self> {
        return attribute("height", value)
    }

    /// Sets the cx attribute from a typed X coordinate.
    public func cx(_ value: W3C_SVG2.X?) -> SVG._Attributes<Self> {
        return attribute("cx", value)
    }

    /// Sets the cy attribute from a typed Y coordinate.
    public func cy(_ value: W3C_SVG2.Y?) -> SVG._Attributes<Self> {
        return attribute("cy", value)
    }

    /// Sets the r attribute from a typed Radius.
    public func r(_ value: W3C_SVG2.Radius?) -> SVG._Attributes<Self> {
        return attribute("r", value)
    }

    /// Sets the rx attribute from a typed Width.
    public func rx(_ value: W3C_SVG2.Width?) -> SVG._Attributes<Self> {
        return attribute("rx", value)
    }

    /// Sets the ry attribute from a typed Height.
    public func ry(_ value: W3C_SVG2.Height?) -> SVG._Attributes<Self> {
        return attribute("ry", value)
    }

    /// Sets the x1 attribute from a typed X coordinate.
    public func x1(_ value: W3C_SVG2.X?) -> SVG._Attributes<Self> {
        return attribute("x1", value)
    }

    /// Sets the y1 attribute from a typed Y coordinate.
    public func y1(_ value: W3C_SVG2.Y?) -> SVG._Attributes<Self> {
        return attribute("y1", value)
    }

    /// Sets the x2 attribute from a typed X coordinate.
    public func x2(_ value: W3C_SVG2.X?) -> SVG._Attributes<Self> {
        return attribute("x2", value)
    }

    /// Sets the y2 attribute from a typed Y coordinate.
    public func y2(_ value: W3C_SVG2.Y?) -> SVG._Attributes<Self> {
        return attribute("y2", value)
    }

    /// Sets the dx attribute from a typed Dx displacement.
    public func dx(_ value: W3C_SVG2.Dx?) -> SVG._Attributes<Self> {
        return attribute("dx", value)
    }

    /// Sets the dy attribute from a typed Dy displacement.
    public func dy(_ value: W3C_SVG2.Dy?) -> SVG._Attributes<Self> {
        return attribute("dy", value)
    }

    /// Sets the refX attribute from a typed X coordinate.
    public func refX(_ value: W3C_SVG2.X?) -> SVG._Attributes<Self> {
        return attribute("refX", value)
    }

    /// Sets the refY attribute from a typed Y coordinate.
    public func refY(_ value: W3C_SVG2.Y?) -> SVG._Attributes<Self> {
        return attribute("refY", value)
    }

    /// Sets the markerWidth attribute from a typed Width.
    public func markerWidth(_ value: W3C_SVG2.Width?) -> SVG._Attributes<Self> {
        return attribute("markerWidth", value)
    }

    /// Sets the markerHeight attribute from a typed Height.
    public func markerHeight(_ value: W3C_SVG2.Height?) -> SVG._Attributes<Self> {
        return attribute("markerHeight", value)
    }
}

### File: Sources/SVG Rendering/SVG.Builder.swift

//
//  SVG.Builder.swift
//  swift-svg-rendering
//

public import Render_Primitives

extension SVG {
    public typealias Builder = Render.Builder
}

### File: Sources/SVG Rendering/SVG.Context.Attributes.swift

//
//  SVG.Context.Attributes.swift
//  swift-svg-render
//

public import Buffer_Linear_Primitive
public import Column_Primitives
public import Dictionary_Ordered_Primitives
public import Dictionary_Primitives
public import Hash_Indexed_Primitive
public import Hash_Primitives
public import Ownership_Shared_Primitive

extension SVG.Context {
    /// The ordered set of attributes applied to the next element: a value-semantic
    /// (copy-on-write) insertion-ordered `String` → `String` map.
    ///
    /// Carried on the dictionary-primitives `Shared` column, so it stays `Copyable`
    /// and `Sendable` — the rendering value tree holds it by value, and the box
    /// detaches on the first mutation of a shared copy.
    public typealias Attributes = __DictionaryOrdered<
        Ownership.Shared<
            Hash.Entry<String, String>,
            Hash.Indexed<Column.Heap<Hash.Entry<String, String>>>
        >
    >
}

### File: Sources/SVG Rendering/SVG.Context.swift

//
//  SVG.Context.swift
//  swift-svg-rendering
//
//  Rendering context for SVG streaming.
//  Holds state (attributes, indentation) separate from the output buffer.
//

public import Dictionary_Ordered_Primitives
public import Render_Primitives

extension SVG {
    public struct Context: Sendable {
        /// The current set of attributes to apply to the next SVG element.
        public var attributes: Attributes

        /// Configuration for rendering, including formatting options.
        public let configuration: SVG.Context.Configuration

        /// The current indentation level for pretty-printing.
        public var currentIndentation: [UInt8]
    }
}

extension SVG.Context {
    public init(_ configuration: Configuration = .default) {
        self.attributes = .init()
        self.configuration = configuration
        self.currentIndentation = []
    }
}

extension SVG.Context {
    public struct Configuration: Sendable {
        public var indentation: [UInt8]
        public var newline: [UInt8]

        public init(indentation: String = "", newline: String = "") {
            self.indentation = Array(indentation.utf8)
            self.newline = Array(newline.utf8)
        }
    }
}

extension SVG.Context.Configuration {
    public static let `default` = Self()
    public static let pretty = Self(indentation: "  ", newline: "\n")
}

extension SVG.Context {
    @inlinable
    public func appendNewline<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        if !configuration.newline.isEmpty {
            buffer.append(contentsOf: configuration.newline)
        }
    }

    @inlinable
    public func indented() -> SVG.Context {
        var copy = self
        copy.currentIndentation.append(contentsOf: configuration.indentation)
        return copy
    }

    @inlinable
    public func outdented() -> SVG.Context {
        var copy = self
        if copy.currentIndentation.count >= configuration.indentation.count {
            copy.currentIndentation.removeLast(configuration.indentation.count)
        }
        return copy
    }

    @inlinable
    public func appendIndentation<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        if !configuration.indentation.isEmpty && !currentIndentation.isEmpty {
            buffer.append(contentsOf: currentIndentation)
        }
    }
}

### File: Sources/SVG Rendering/SVG.Element.swift

//
//  SVG.Element.swift
//  swift-svg-rendering
//

import ASCII_Primitives
import Dictionary_Ordered_Primitives

extension SVG {
    /// Represents an SVG element with a tag, attributes, and optional content.
    public struct Element<Content: SVG.View>: SVG.View {
        /// The SVG tag name (e.g., "circle", "rect", "path").
        let tag: String

        /// The optional content contained within this element.
        @SVG.Builder public let content: Content?

        /// Creates a new SVG element with the specified tag and content.
        public init(tag: String, @SVG.Builder content: () -> Content? = { Never?.none }) {
            self.tag = tag
            self.content = content()
        }

        /// Renders this SVG element into the provided buffer.
        public static func _render<Buffer: RangeReplaceableCollection>(
            _ svg: Self,
            into buffer: inout Buffer,
            context: inout SVG.Context
        ) where Buffer.Element == UInt8 {
            // Add newline and indentation (skip leading newline at root level)
            if !context.currentIndentation.isEmpty {
                buffer.append(contentsOf: context.configuration.newline)
            }
            buffer.append(contentsOf: context.currentIndentation)

            // Write opening tag
            buffer.append(ASCII.Character.Graphic.lessThanSign)
            buffer.append(contentsOf: svg.tag.utf8)

            // Add attributes from context (set via method chaining like .fill(), .cx(), etc.)
            context.attributes.forEach { name, value in
                buffer.append(ASCII.SPACE.sp)
                buffer.append(contentsOf: name.utf8)
                if !value.isEmpty {
                    buffer.append(ASCII.Character.Graphic.equalsSign)
                    buffer.append(ASCII.Character.Graphic.quotationMark)

                    // Single-pass: iterate directly over UTF-8 view, escape as needed
                    for byte in value.utf8 {
                        switch byte {
                        case ASCII.Character.Graphic.quotationMark:
                            buffer.append(contentsOf: [UInt8].svg.doubleQuotationMark)

                        case ASCII.Character.Graphic.apostrophe:
                            buffer.append(contentsOf: [UInt8].svg.apostrophe)

                        case ASCII.Character.Graphic.ampersand:
                            buffer.append(contentsOf: [UInt8].svg.ampersand)

                        case ASCII.Character.Graphic.lessThanSign:
                            buffer.append(contentsOf: [UInt8].svg.lessThan)

                        case ASCII.Character.Graphic.greaterThanSign:
                            buffer.append(contentsOf: [UInt8].svg.greaterThan)

                        default:
                            buffer.append(byte)
                        }
                    }

                    buffer.append(ASCII.Character.Graphic.quotationMark)
                }
            }
            buffer.append(ASCII.Character.Graphic.greaterThanSign)

            // Render content if present
            if let content = svg.content {
                let oldAttributes = context.attributes
                let oldIndentation = context.currentIndentation
                defer {
                    context.attributes = oldAttributes
                    context.currentIndentation = oldIndentation
                }
                context.attributes.removeAll()
                context.currentIndentation += context.configuration.indentation
                Content._render(content, into: &buffer, context: &context)
            }

            // Add closing tag (SVG elements are not void/self-closing in the HTML sense)
            buffer.append(contentsOf: context.configuration.newline)
            buffer.append(contentsOf: context.currentIndentation)
            buffer.append(ASCII.Character.Graphic.lessThanSign)
            buffer.append(ASCII.Character.Graphic.slant)
            buffer.append(contentsOf: svg.tag.utf8)
            buffer.append(ASCII.Character.Graphic.greaterThanSign)
        }

        /// This type uses direct rendering and doesn't have a body.
        public var body: Never {
            fatalError("body should not be called")
        }
    }
}

extension SVG.Element: Sendable where Content: Sendable {}

// MARK: - SVG Escape Sequences

extension [UInt8] {
    /// SVG-specific escape sequences for attribute values.
    public enum svg {}
}

extension [UInt8].svg {
    /// The escaped representation of a double quotation mark (`"`).
    public static let doubleQuotationMark: [UInt8] = [
        ASCII.Character.Graphic.ampersand, ASCII.Character.Graphic.q, ASCII.Character.Graphic.u,
        ASCII.Character.Graphic.o, ASCII.Character.Graphic.t, ASCII.Character.Graphic.semicolon,
    ]

    /// The escaped representation of an apostrophe (`'`).
    public static let apostrophe: [UInt8] = [
        ASCII.Character.Graphic.ampersand, ASCII.Character.Graphic.a, ASCII.Character.Graphic.p,
        ASCII.Character.Graphic.o, ASCII.Character.Graphic.s, ASCII.Character.Graphic.semicolon,
    ]

    /// The escaped representation of an ampersand (`&`).
    public static let ampersand: [UInt8] = [
        ASCII.Character.Graphic.ampersand, ASCII.Character.Graphic.a, ASCII.Character.Graphic.m,
        ASCII.Character.Graphic.p, ASCII.Character.Graphic.semicolon,
    ]

    /// The escaped representation of a less-than sign (`<`).
    public static let lessThan: [UInt8] = [
        ASCII.Character.Graphic.ampersand, ASCII.Character.Graphic.l, ASCII.Character.Graphic.t,
        ASCII.Character.Graphic.semicolon,
    ]

    /// The escaped representation of a greater-than sign (`>`).
    public static let greaterThan: [UInt8] = [
        ASCII.Character.Graphic.ampersand, ASCII.Character.Graphic.g, ASCII.Character.Graphic.t,
        ASCII.Character.Graphic.semicolon,
    ]
}

### File: Sources/SVG Rendering/SVG.Elements.swift

//
//  SVG.Elements.swift
//  swift-svg-rendering
//
//  callAsFunction extensions for W3C SVG types
//

import Dictionary_Ordered_Primitives
import Format_Primitives
public import SVG_Standard

// MARK: - Basic Shapes

extension SVG_Standard.Shapes.Circle {
    /// Renders the circle element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .cx(self.cx)
            .cy(self.cy)
            .r(self.r)
    }
}

extension SVG_Standard.Shapes.Rectangle {
    /// Renders the rect element with optional child content.
    ///
    /// Corner radii (rx, ry) can be applied using modifiers:
    /// ```swift
    /// rect().rx(5).ry(5)
    /// ```
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
    }
}

extension SVG_Standard.Shapes.Ellipse {
    /// Renders the ellipse element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .cx(self.cx)
            .cy(self.cy)
            .rx(self.rx)
            .ry(self.ry)
    }
}

extension SVG_Standard.Shapes.Line {
    /// Renders the line element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .x1(self.x1)
            .y1(self.y1)
            .x2(self.x2)
            .y2(self.y2)
    }
}

extension SVG_Standard.Shapes.Polygon {
    /// Renders the polygon element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .points(self.points)
    }
}

extension SVG_Standard.Shapes.Polyline {
    /// Renders the polyline element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .points(self.points)
    }
}

// MARK: - Paths

extension SVG_Standard.Paths.Path {
    /// Renders the path element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .d(self.d)
            .fillRule(self.fillRule?.rawValue)
    }
}

// MARK: - Document Structure

extension SVG_Standard.Document.SVG {
    /// Renders the svg element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .x(self.x?.description)
            .y(self.y?.description)
            .width(self.width?.description)
            .height(self.height?.description)
            .viewBox(self.viewBox?.description)
    }
}

extension SVG_Standard.Document.Group {
    /// Renders the g element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
    }
}

extension SVG_Standard.Document.Defs {
    /// Renders the defs element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
    }
}

extension SVG_Standard.Document.Symbol {
    /// Renders the symbol element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .viewBox(self.viewBox?.description)
            .refX(self.refX)
            .refY(self.refY)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

extension SVG_Standard.Document.Use {
    /// Renders the use element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .href(self.href)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
    }
}

// MARK: - Text

extension SVG_Standard.Text.Text {
    /// Renders the text element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) {
            if let textContent = self.content {
                SVG.Text(textContent)
            }
            content()
        }
        .x(self.x)
        .y(self.y)
        .dx(self.dx)
        .dy(self.dy)
    }
}

extension SVG_Standard.Text.TSpan {
    /// Renders the tspan element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) {
            if let textContent = self.content {
                SVG.Text(textContent)
            }
            content()
        }
        .x(self.x)
        .y(self.y)
        .dx(self.dx)
        .dy(self.dy)
    }
}

// MARK: - Paint Servers (Gradients & Patterns)

extension SVG_Standard.PaintServers.LinearGradient {
    /// Renders the linearGradient element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .x1(self.x1)
            .y1(self.y1)
            .x2(self.x2)
            .y2(self.y2)
            .href(self.href)
            .gradientUnits(self.gradientUnits?.rawValue)
            .gradientTransform(self.gradientTransform)
            .spreadMethod(self.spreadMethod?.rawValue)
    }
}

extension SVG_Standard.PaintServers.RadialGradient {
    /// Renders the radialGradient element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .cx(self.cx)
            .cy(self.cy)
            .r(self.r)
            .fx(self.fx)
            .fy(self.fy)
            .fr(self.fr)
            .href(self.href)
            .gradientUnits(self.gradientUnits?.rawValue)
            .gradientTransform(self.gradientTransform)
            .spreadMethod(self.spreadMethod?.rawValue)
    }
}

extension SVG_Standard.PaintServers.Stop {
    /// Renders the stop element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .offset(self.offset)
            .stopColor(self.stopColor)
            .stopOpacity(self.stopOpacity)
    }
}

extension SVG_Standard.PaintServers.Pattern {
    /// Renders the pattern element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .viewBox(self.viewBox?.description)
            .href(self.href)
            .patternUnits(self.patternUnits?.rawValue)
            .patternContentUnits(self.patternContentUnits?.rawValue)
            .patternTransform(self.patternTransform)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

// MARK: - Painting (Clipping, Masking, Markers)

extension SVG_Standard.Painting.ClipPath {
    /// Renders the clipPath element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .clipPathUnits(self.clipPathUnits?.rawValue)
    }
}

extension SVG_Standard.Painting.Mask {
    /// Renders the mask element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .maskUnits(self.maskUnits?.rawValue)
            .maskContentUnits(self.maskContentUnits?.rawValue)
    }
}

extension SVG_Standard.Painting.Marker {
    /// Renders the marker element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .id(self.id)
            .viewBox(self.viewBox?.description)
            .refX(self.refX)
            .refY(self.refY)
            .markerWidth(self.markerWidth)
            .markerHeight(self.markerHeight)
            .orient(self.orient)
            .markerUnits(self.markerUnits?.rawValue)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

// MARK: - Embedded Content

extension SVG_Standard.Embedded.Image {
    /// Renders the image element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .href(self.href)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

extension SVG_Standard.Embedded.ForeignObject {
    /// Renders the foreignObject element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
    }
}

// MARK: - Scripting

extension SVG_Standard.Scripting.Switch {
    /// Renders the switch element with optional child content.
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
    }
}

// MARK: - Optional Attribute Helper

extension SVG.View {
    /// Sets the id attribute if value is not nil.
    func id(_ value: String?) -> SVG._Attributes<Self> {
        guard let value else { return SVG._Attributes(content: self, attributes: .init()) }
        return attribute("id", value)
    }

    /// Sets the fill-rule attribute from a string value.
    func fillRule(_ value: String?) -> SVG._Attributes<Self> {
        guard let value else { return SVG._Attributes(content: self, attributes: .init()) }
        return attribute("fill-rule", value)
    }

    /// Sets the cx attribute for gradients (String version).
    func cx(_ value: String?) -> SVG._Attributes<Self> {
        guard let value else { return SVG._Attributes(content: self, attributes: .init()) }
        return attribute("cx", value)
    }

    /// Sets the cy attribute for gradients (String version).
    func cy(_ value: String?) -> SVG._Attributes<Self> {
        guard let value else { return SVG._Attributes(content: self, attributes: .init()) }
        return attribute("cy", value)
    }
}

// MARK: - SVG.View Conformances
// Direct conformances for W3C SVG types.
// Geometry types conform to SVG.View for direct DSL usage, and also provide .svg
// for explicit SVG-specific operations (transforms, etc.) separate from math operations.

extension Geometry.Ball: SVG.View where Scalar == Double, Space == W3C_SVG.Space, N == 2 {
    public var body: some SVG.View {
        svg
    }
}

extension Geometry.Orthotope: SVG.View where Scalar == Double, Space == W3C_SVG.Space, N == 2 {
    public var body: some SVG.View {
        svg
    }
}

extension Geometry.Ellipse: SVG.View where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        svg
    }
}

extension Geometry.Line.Segment: SVG.View where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        svg
    }
}

extension Geometry.Polygon: SVG.View where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        svg
    }
}

// Note: Ellipse, Line, Polygon conformances are now handled via Geometry type extensions above

extension SVG_Standard.Shapes.Polyline: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .points(self.points)
    }
}

extension SVG_Standard.Paths.Path: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .d(self.d)
            .fillRule(self.fillRule?.rawValue)
    }
}

extension SVG_Standard.Document.SVG: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .x(self.x?.description)
            .y(self.y?.description)
            .width(self.width?.description)
            .height(self.height?.description)
            .viewBox(self.viewBox?.description)
    }
}

extension SVG_Standard.Document.Group: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
    }
}

extension SVG_Standard.Document.Defs: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
    }
}

extension SVG_Standard.Document.Symbol: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .viewBox(self.viewBox?.description)
            .refX(self.refX)
            .refY(self.refY)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

extension SVG_Standard.Document.Use: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .href(self.href)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
    }
}

extension SVG_Standard.Text.Text: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) {
            if let textContent = self.content {
                SVG.Text(textContent)
            }
        }
        .x(self.x)
        .y(self.y)
        .dx(self.dx)
        .dy(self.dy)
    }
}

extension SVG_Standard.Text.TSpan: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) {
            if let textContent = self.content {
                SVG.Text(textContent)
            }
        }
        .x(self.x)
        .y(self.y)
        .dx(self.dx)
        .dy(self.dy)
    }
}

extension SVG_Standard.PaintServers.LinearGradient: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .x1(self.x1)
            .y1(self.y1)
            .x2(self.x2)
            .y2(self.y2)
            .href(self.href)
            .gradientUnits(self.gradientUnits?.rawValue)
            .gradientTransform(self.gradientTransform)
            .spreadMethod(self.spreadMethod?.rawValue)
    }
}

extension SVG_Standard.PaintServers.RadialGradient: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .cx(self.cx)
            .cy(self.cy)
            .r(self.r)
            .fx(self.fx)
            .fy(self.fy)
            .fr(self.fr)
            .href(self.href)
            .gradientUnits(self.gradientUnits?.rawValue)
            .gradientTransform(self.gradientTransform)
            .spreadMethod(self.spreadMethod?.rawValue)
    }
}

extension SVG_Standard.PaintServers.Stop: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .offset(self.offset)
            .stopColor(self.stopColor)
            .stopOpacity(self.stopOpacity)
    }
}

extension SVG_Standard.PaintServers.Pattern: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .viewBox(self.viewBox?.description)
            .href(self.href)
            .patternUnits(self.patternUnits?.rawValue)
            .patternContentUnits(self.patternContentUnits?.rawValue)
            .patternTransform(self.patternTransform)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

extension SVG_Standard.Painting.ClipPath: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .clipPathUnits(self.clipPathUnits?.rawValue)
    }
}

extension SVG_Standard.Painting.Mask: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .maskUnits(self.maskUnits?.rawValue)
            .maskContentUnits(self.maskContentUnits?.rawValue)
    }
}

extension SVG_Standard.Painting.Marker: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .id(self.id)
            .viewBox(self.viewBox?.description)
            .refX(self.refX)
            .refY(self.refY)
            .markerWidth(self.markerWidth)
            .markerHeight(self.markerHeight)
            .orient(self.orient)
            .markerUnits(self.markerUnits?.rawValue)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

extension SVG_Standard.Embedded.Image: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
            .href(self.href)
            .preserveAspectRatio(self.preserveAspectRatio)
    }
}

extension SVG_Standard.Embedded.ForeignObject: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
            .x(self.x)
            .y(self.y)
            .width(self.width)
            .height(self.height)
    }
}

extension SVG_Standard.Scripting.Switch: SVG.View {
    public var body: some SVG.View {
        SVG.Element(tag: Self.tagName) { SVG.Empty() }
    }
}

### File: Sources/SVG Rendering/SVG.Empty.swift

//
//  SVG.Empty.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

/// An empty SVG element that renders nothing.
///
/// This type is useful as a placeholder or when conditionally
/// rendering content that might be empty.
extension SVG {
    public struct Empty: SVG.View {
        /// Creates an empty SVG element.
        public init() {}
    }
}

extension SVG.Empty {
    /// Renders nothing into the buffer.
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        // Intentionally empty
    }

    public var body: Never { fatalError("body should not be called") }
}

### File: Sources/SVG Rendering/SVG.GeometryContext.swift

//
//  SVG.GeometryContext.swift
//  swift-svg-rendering
//
//  SVG.View conformances for geometry SVGContext wrappers.
//  All SVG rendering goes through .svg accessor, keeping geometry types pure math.
//

import Dictionary_Ordered_Primitives
import Format_Primitives
public import SVG_Standard

// MARK: - Circle SVGContext

extension Geometry.Ball.SVGContext: SVG.View
where Scalar == Double, Space == W3C_SVG.Space, N == 2 {
    public var body: some SVG.View {
        SVG.Element(tag: "circle") { SVG.Empty() }
            .cx(circle.cx)
            .cy(circle.cy)
            .r(circle.r)
    }

    /// Applies an SVG translate transform.
    ///
    /// Unlike `circle.translated(by:)` which returns a new circle with different coordinates,
    /// this method returns an SVG view with a `transform="translate(...)"` attribute.
    public func translated(by vector: W3C_SVG2.Vector) -> some SVG.View {
        self.translate(x: vector.dx.underlying, y: vector.dy.underlying)
    }

    /// Applies an SVG scale transform.
    ///
    /// Unlike `circle.scaled(by:)` which returns a new circle with different radius,
    /// this method returns an SVG view with a `transform="scale(...)"` attribute.
    public func scaled(by factor: Double) -> some SVG.View {
        self.scale(x: factor)
    }

    /// Applies an SVG scale transform with different x and y factors.
    public func scaled(x: Double, y: Double) -> some SVG.View {
        self.scale(x: x, y: y)
    }

    /// Applies an SVG rotate transform.
    public func rotated(by angle: W3C_SVG2.Degrees) -> some SVG.View {
        self.rotate(angle.underlying)
    }

    /// Applies an SVG rotate transform around a center point.
    public func rotated(by angle: W3C_SVG2.Degrees, around center: W3C_SVG2.Point) -> some SVG.View
    {
        self.rotate(angle.underlying, cx: center.x.underlying, cy: center.y.underlying)
    }
}

// MARK: - Rectangle SVGContext

extension Geometry.Orthotope.SVGContext: SVG.View
where Scalar == Double, Space == W3C_SVG.Space, N == 2 {
    public var body: some SVG.View {
        SVG.Element(tag: "rect") { SVG.Empty() }
            .x(rectangle.x)
            .y(rectangle.y)
            .width(rectangle.width)
            .height(rectangle.height)
    }

    /// Applies an SVG translate transform.
    public func translated(by vector: W3C_SVG2.Vector) -> some SVG.View {
        self.translate(x: vector.dx.underlying, y: vector.dy.underlying)
    }

    /// Applies an SVG scale transform.
    public func scaled(by factor: Double) -> some SVG.View {
        self.scale(x: factor)
    }

    /// Applies an SVG scale transform with different x and y factors.
    public func scaled(x: Double, y: Double) -> some SVG.View {
        self.scale(x: x, y: y)
    }

    /// Applies an SVG rotate transform.
    public func rotated(by angle: W3C_SVG2.Degrees) -> some SVG.View {
        self.rotate(angle.underlying)
    }

    /// Applies an SVG rotate transform around a center point.
    public func rotated(by angle: W3C_SVG2.Degrees, around center: W3C_SVG2.Point) -> some SVG.View
    {
        self.rotate(angle.underlying, cx: center.x.underlying, cy: center.y.underlying)
    }

    /// Sets the rx attribute for rounded corners.
    public func rx(_ value: W3C_SVG2.Width) -> some SVG.View {
        SVG._Attributes(content: self, attributes: .init()).rx(value)
    }

    /// Sets the ry attribute for rounded corners.
    public func ry(_ value: W3C_SVG2.Height) -> some SVG.View {
        SVG._Attributes(content: self, attributes: .init()).ry(value)
    }
}

// MARK: - Ellipse SVGContext

extension Geometry.Ellipse.SVGContext: SVG.View
where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        SVG.Element(tag: "ellipse") { SVG.Empty() }
            .cx(ellipse.center.x)
            .cy(ellipse.center.y)
            .rx(W3C_SVG2.Width(ellipse.semiMajor.underlying))
            .ry(W3C_SVG2.Height(ellipse.semiMinor.underlying))
    }

    /// Applies an SVG translate transform.
    public func translated(by vector: W3C_SVG2.Vector) -> some SVG.View {
        self.translate(x: vector.dx.underlying, y: vector.dy.underlying)
    }

    /// Applies an SVG scale transform.
    public func scaled(by factor: Double) -> some SVG.View {
        self.scale(x: factor)
    }

    /// Applies an SVG rotate transform.
    public func rotated(by angle: W3C_SVG2.Degrees) -> some SVG.View {
        self.rotate(angle.underlying)
    }
}

// MARK: - Line SVGContext

extension Geometry.Line.Segment.SVGContext: SVG.View
where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        let el = element
        return SVG.Element(tag: "line") { SVG.Empty() }
            .x1(el.x1)
            .y1(el.y1)
            .x2(el.x2)
            .y2(el.y2)
    }

    /// Applies an SVG translate transform.
    public func translated(by vector: W3C_SVG2.Vector) -> some SVG.View {
        self.translate(x: vector.dx.underlying, y: vector.dy.underlying)
    }

    /// Applies an SVG scale transform.
    public func scaled(by factor: Double) -> some SVG.View {
        self.scale(x: factor)
    }

    /// Applies an SVG rotate transform.
    public func rotated(by angle: W3C_SVG2.Degrees) -> some SVG.View {
        self.rotate(angle.underlying)
    }
}

// MARK: - Polygon SVGContext

extension Geometry.Polygon.SVGContext: SVG.View
where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        let el = element
        return SVG.Element(tag: "polygon") { SVG.Empty() }
            .points(el.points)
    }

    /// Applies an SVG translate transform.
    public func translated(by vector: W3C_SVG2.Vector) -> some SVG.View {
        self.translate(x: vector.dx.underlying, y: vector.dy.underlying)
    }

    /// Applies an SVG scale transform.
    public func scaled(by factor: Double) -> some SVG.View {
        self.scale(x: factor)
    }

    /// Applies an SVG rotate transform.
    public func rotated(by angle: W3C_SVG2.Degrees) -> some SVG.View {
        self.rotate(angle.underlying)
    }
}

// MARK: - Path SVGContext

extension Geometry.Path.SVGContext: SVG.View
where Scalar == Double, Space == W3C_SVG.Space {
    public var body: some SVG.View {
        let el = element
        return SVG.Element(tag: "path") { SVG.Empty() }
            .d(el.d)
    }

    /// Applies an SVG translate transform.
    public func translated(by vector: W3C_SVG2.Vector) -> some SVG.View {
        self.translate(x: vector.dx.underlying, y: vector.dy.underlying)
    }

    /// Applies an SVG scale transform.
    public func scaled(by factor: Double) -> some SVG.View {
        self.scale(x: factor)
    }

    /// Applies an SVG rotate transform.
    public func rotated(by angle: W3C_SVG2.Degrees) -> some SVG.View {
        self.rotate(angle.underlying)
    }
}

### File: Sources/SVG Rendering/SVG.Group.swift

//
//  SVG.Group.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

/// A container that groups multiple SVG elements together.
///
/// `SVG.Group` allows you to compose multiple SVG elements without
/// adding any additional rendering structure. It's useful for
/// returning multiple elements from computed properties or functions.
///
/// Example:
/// ```swift
/// var icons: some SVG.View {
///     SVG.Group {
///         circle(cx: 10, cy: 10, r: 5)
///         rect(x: 20, y: 20, width: 10, height: 10)
///     }
/// }
/// ```
extension SVG {
    public struct Group<Content: SVG.View>: SVG.View {
        /// The content of the group.
        let content: Content

        /// Creates a group with the given content.
        ///
        /// - Parameter content: A closure that returns the SVG content.
        public init(@SVG.Builder _ content: () -> Content) {
            self.content = content()
        }

        /// The body of the group is its content.
        public var body: some SVG.View {
            content
        }
    }
}

### File: Sources/SVG Rendering/SVG.Raw.swift

//
//  SVG.Raw.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

/// An SVG element that renders raw SVG content without escaping.
///
/// Use this type when you need to include pre-formatted SVG content
/// or when working with SVG strings from external sources.
///
/// - Warning: Content is not escaped. Ensure the SVG content is safe
///   and properly formatted to avoid injection vulnerabilities.
extension SVG {
    public struct Raw: SVG.View {
        /// The raw SVG content to render.
        let content: String

        /// Creates a raw SVG element with the given content.
        ///
        /// - Parameter content: The raw SVG content to render.
        public init(_ content: String) {
            self.content = content
        }
    }
}

extension SVG.Raw {
    /// Renders the raw content directly into the buffer.
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: svg.content.utf8)
    }

    public var body: Never { fatalError("body should not be called") }
}

### File: Sources/SVG Rendering/SVG.Text.swift

//
//  SVG.Text.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

import ASCII_Primitives

/// Represents plain text content in SVG, with proper XML escaping.
///
/// `SVG.Text` handles escaping special characters in text content to ensure
/// proper SVG/XML rendering without security vulnerabilities.
extension SVG {
    public struct Text: SVG.View {
        /// The raw text content.
        let text: String

        /// Creates a new SVG text component with the given text.
        ///
        /// - Parameter text: The text content to represent.
        public init(_ text: String) {
            self.text = text
        }
    }
}

extension SVG.Text {
    /// Renders the text content with proper XML escaping.
    ///
    /// This method escapes special characters (`&`, `<`, `>`, `"`, `'`) to prevent XML injection
    /// and ensure the text renders correctly in an SVG document.
    ///
    /// - Parameters:
    ///   - svg: The SVG text to render.
    ///   - buffer: The buffer to render the SVG into.
    ///   - context: The rendering context.
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        buffer.reserveCapacity(buffer.count + svg.text.utf8.count)
        for byte in svg.text.utf8 {
            switch byte {
            case ASCII.Character.Graphic.ampersand:
                buffer.append(contentsOf: "&amp;".utf8)

            case ASCII.Character.Graphic.lessThanSign:
                buffer.append(contentsOf: "&lt;".utf8)

            case ASCII.Character.Graphic.greaterThanSign:
                buffer.append(contentsOf: "&gt;".utf8)

            case ASCII.Character.Graphic.quotationMark:
                buffer.append(contentsOf: "&quot;".utf8)

            case ASCII.Character.Graphic.apostrophe:
                buffer.append(contentsOf: "&apos;".utf8)

            default:
                buffer.append(byte)
            }
        }
    }

    /// This type uses direct rendering and doesn't have a body.
    public var body: Never { fatalError("body should not be called") }

    /// Concatenates two SVG text components.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side text.
    ///   - rhs: The right-hand side text.
    /// - Returns: A new SVG text component containing the concatenated text.
    public static func + (lhs: Self, rhs: Self) -> Self {
        SVG.Text(lhs.text + rhs.text)
    }
}

/// Allows SVG text to be created from string literals.
extension SVG.Text: ExpressibleByStringLiteral {
    /// Creates a new SVG text component from a string literal.
    ///
    /// - Parameter value: The string literal to use as content.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

/// Allows SVG text to be created with string interpolation.
extension SVG.Text: ExpressibleByStringInterpolation {}

### File: Sources/SVG Rendering/SVG.View.swift

//
//  SVG.View.swift
//  swift-svg-rendering
//

public import Dictionary_Ordered_Primitives
import Dimension_Primitives
import Format_Primitives
public import Render_Primitives

/// A namespace for SVG-related types.
public enum SVG {}

extension SVG {
    public protocol View {
        associatedtype Content: SVG.View
        @SVG.Builder var body: Content { get }

        static func _render<Buffer: RangeReplaceableCollection>(
            _ svg: Self,
            into buffer: inout Buffer,
            context: inout SVG.Context
        ) where Buffer.Element == UInt8
    }
}

// reason: `Content: Self` here is not valid Swift in this where-clause
// conformance position ("type 'Self.Content' constrained to non-protocol,
// non-class type 'Self'") — confirmed by CI breakage across this package
// and downstream swift-pdf when swiftlint --fix applied it (commit 60e00fd).
// swiftlint:disable:next prefer_self_in_static_references
extension SVG.View where Content: SVG.View {
    @inlinable
    @_disfavoredOverload
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        Content._render(svg.body, into: &buffer, context: &context)
    }
}

extension SVG.View {
    public func attribute(_ name: String, _ value: String? = "") -> SVG._Attributes<Self> {
        var attrs = SVG.Context.Attributes()
        if let value {
            attrs.set(name, value)
        }
        return SVG._Attributes(content: self, attributes: attrs)
    }

    public func attribute(_ name: String, _ value: Double?) -> SVG._Attributes<Self> {
        attribute(name, value?.formatted(.number))
    }

    public func attribute<Tag>(
        _ name: String,
        _ value: Tagged<Tag, Double>?
    ) -> SVG._Attributes<Self> {
        attribute(name, value?.formatted(.number))
    }
}

extension CustomStringConvertible where Self: SVG.View {
    public var description: String {
        String(self)
    }
}

### File: Sources/SVG Rendering/SVG._Array.swift

//
//  SVG._Array.swift
//  swift-svg-rendering
//

extension Array: SVG.View where Element: SVG.View {
    public var body: Never { fatalError("body should not be called") }

    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        for element in svg {
            Element._render(element, into: &buffer, context: &context)
        }
    }
}

### File: Sources/SVG Rendering/SVG._Attributes.swift

//
//  SVG._Attributes.swift
//  swift-svg-rendering
//

public import Dictionary_Ordered_Primitives
public import Render_Primitives

/// A wrapper that adds attributes to an SVG element.
extension SVG {
    public struct _Attributes<Content: SVG.View>: SVG.View {
        let content: Content
        let attributes: SVG.Context.Attributes

        public init(content: Content, attributes: SVG.Context.Attributes) {
            self.content = content
            self.attributes = attributes
        }

        public static func _render<Buffer: RangeReplaceableCollection>(
            _ svg: Self,
            into buffer: inout Buffer,
            context: inout SVG.Context
        ) where Buffer.Element == UInt8 {
            let previousValue = context.attributes
            defer { context.attributes = previousValue }
            svg.attributes.forEach { key, value in
                context.attributes.set(key, value)
            }
            Content._render(svg.content, into: &buffer, context: &context)
        }

        public var body: Never { fatalError("body should not be called") }
    }
}

extension SVG._Attributes {
    /// Adds another attribute to the element.
    public func attribute(_ name: String, _ value: String? = "") -> SVG._Attributes<Content> {
        var newAttributes = self.attributes
        if let value {
            newAttributes.set(name, value)
        }
        return SVG._Attributes(content: content, attributes: newAttributes)
    }
}

### File: Sources/SVG Rendering/SVG._Conditional.swift

//
//  SVG._Conditional.swift
//  swift-svg-rendering
//

public import Render_Primitives

extension Render.Conditional: SVG.View where First: SVG.View, Second: SVG.View {
    public var body: Never { fatalError("body should not be called") }

    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        switch svg {
        case .first(let first): First._render(first, into: &buffer, context: &context)
        case .second(let second): Second._render(second, into: &buffer, context: &context)
        }
    }
}

### File: Sources/SVG Rendering/SVG._Tuple.swift

//
//  SVG._Tuple.swift
//  swift-svg-rendering
//

public import Render_Primitives

extension Render._Tuple: SVG.View where repeat each Content: SVG.View {
    public var body: Never { fatalError("body should not be called") }

    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        func render<T: SVG.View>(_ element: T) {
            let oldAttributes = context.attributes
            defer { context.attributes = oldAttributes }
            T._render(element, into: &buffer, context: &context)
        }
        repeat render(each svg.content)
    }
}

### File: Sources/SVG Rendering/String+SVG.swift

//
//  String+SVG.swift
//  swift-svg-rendering
//
//  String conformance to SVG.View for text content in SVG builders.
//

/// Allows String to be used directly in SVG builders.
///
/// Example:
/// ```swift
/// text(x: 10, y: 30) { "Hello, SVG!" }
/// tspan { "Some text" }
/// ```
extension String: SVG.View {
    public var body: some SVG.View {
        SVG.Text(self)
    }
}

### File: Sources/SVG Rendering/StringProtocol+SVG.swift

//
//  StringProtocol+SVG.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

extension StringProtocol {
    /// Creates a String from rendered SVG content.
    ///
    /// This is a **derived transformation** where String is constructed from
    /// the canonical byte representation (`ContiguousArray<UInt8>`).
    ///
    /// ## Transformation Chain
    ///
    /// ```
    /// SVG → ContiguousArray<UInt8> → String
    ///  ↑           ↑ (canonical)        ↑ (derived)
    ///  |           |                     |
    /// Protocol  Byte Representation  User-facing
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let icon = circle(cx: 50, cy: 50, r: 40)
    /// let svgString = try String(icon)
    /// print(svgString)
    /// ```
    ///
    /// - Parameters:
    ///   - svg: The SVG content to render as a string
    ///   - configuration: Rendering configuration. Uses default if nil.
    public init(
        _ svg: some SVG.View,
        configuration: SVG.Context.Configuration? = nil
    ) {
        let bytes = ContiguousArray(svg, configuration: configuration)
        self = Self(decoding: bytes, as: UTF8.self)
    }
}

extension StringProtocol {
    /// Asynchronously render SVG to a String.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let icon = circle(cx: 50, cy: 50, r: 40)
    /// let string = await String(icon)
    /// ```
    ///
    /// - Parameters:
    ///   - svg: The SVG content to render.
    ///   - configuration: Rendering configuration. Uses default if nil.
    @inlinable
    public init<T: SVG.View>(
        _ view: T,
        configuration: SVG.Context.Configuration? = nil
    ) async {
        let bytes = await [UInt8](view, configuration: configuration)
        self = Self(decoding: bytes, as: UTF8.self)
    }
}

### File: Sources/SVG Rendering/exports.swift

//
//  exports.swift
//  swift-svg-rendering
//

@_exported import ASCII_Primitives
@_exported import Dictionary_Primitives
@_exported import Format_Primitives
@_exported import Render_Primitives
@_exported import SVG_Standard
