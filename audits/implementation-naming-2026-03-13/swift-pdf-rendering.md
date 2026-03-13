# swift-pdf-rendering Audit: Implementation + Naming

Date: 2026-03-13

## Summary
- Total files audited: 49 (35 Sources, 14 Tests)
- Total violations found: 26
- Critical (naming/compound types): 8
- Implementation style: 18

## Violations

### [API-NAME-004] Typealias for type unification — `BuilderRaw`
- **File**: `Sources/PDF Rendering/PDF.Builder.swift:8`
- **Issue**: Module-level typealias `BuilderRaw` introduced purely for type unification. The canonical type `Rendering.Builder` should be used directly.
- **Current**: `public typealias BuilderRaw = Rendering.Builder`
- **Expected**: Remove `BuilderRaw` and use `Rendering.Builder` directly at all call sites (lines 15, 20, 22).

### [API-NAME-004] Typealias for type unification — `LayoutRaw`
- **File**: `Sources/PDF Rendering/Rendering/PDF.Stack+PDF.View.swift:12`
- **Issue**: Module-level typealias `LayoutRaw` introduced for type unification. The canonical type `Layout` should be used directly.
- **Current**: `public typealias LayoutRaw = Layout`
- **Expected**: Remove `LayoutRaw` and use `Layout<Double, ISO_32000_Shared.UserSpace>` directly in the extensions (lines 34, 102).

### [API-NAME-004] Typealias for type unification — `PDF.Layout`
- **File**: `Sources/PDF Rendering/Rendering/PDF.Stack+PDF.View.swift:16`
- **Issue**: `PDF.Layout` is a typealias to `LayoutRaw<Double, ISO_32000_Shared.UserSpace>`, layering a typealias on top of another typealias.
- **Current**: `public typealias Layout = LayoutRaw<Double, ISO_32000_Shared.UserSpace>`
- **Expected**: Use `Layout<Double, ISO_32000_Shared.UserSpace>` directly or define a concrete nested type.

### [API-NAME-004] Typealias for type unification — `PDF.Stack`, `PDF.VStack`, `PDF.HStack`
- **File**: `Sources/PDF Rendering/Rendering/PDF.Stack+PDF.View.swift:22-29`
- **Issue**: Three typealiases (`Stack`, `VStack`, `HStack`) that all resolve to the same underlying type `PDF.Layout.Stack<C>`. `VStack` and `HStack` are semantically distinct (vertical vs horizontal) but map to the same type, meaning the type system does not distinguish them. This is misleading.
- **Current**:
  ```swift
  public typealias Stack<C> = PDF.Layout.Stack<C>
  public typealias VStack<C> = PDF.Layout.Stack<C>
  public typealias HStack<C> = PDF.Layout.Stack<C>
  ```
- **Expected**: Either use distinct types for `VStack`/`HStack` so the type system enforces axis semantics, or use a single canonical name. Three aliases to the same type is type-unification-via-typealias.

### [API-NAME-001] Compound type name — `PendingInternalLink`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:182`
- **Issue**: `PendingInternalLink` is a compound name. Should follow Nest.Name pattern.
- **Current**: `public struct PendingInternalLink: Sendable`
- **Expected**: Nest under a namespace, e.g. `PDF.Context.Link.Pending` or `PDF.Context.Internal.Link.Pending`.

### [API-NAME-002] Compound method name — `addLinkAnnotation`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:407,417`
- **Issue**: `addLinkAnnotation` is a compound method name combining verb + noun + noun.
- **Current**: `public mutating func addLinkAnnotation(rect:uri:)` and `addLinkAnnotation(rect:destination:)`
- **Expected**: Use nested accessor pattern, e.g. `context.annotation.link(rect:uri:)` or similar decomposition.

### [API-NAME-002] Compound method name — `addPendingInternalLink`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:430`
- **Issue**: `addPendingInternalLink` is a compound method name with four words.
- **Current**: `public mutating func addPendingInternalLink(rect:targetId:)`
- **Expected**: Decompose via nested accessor, e.g. `context.link.internal.add(rect:targetId:)`.

### [API-NAME-002] Compound method name — `resolveInternalLinks`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:493`
- **Issue**: `resolveInternalLinks` is a compound name.
- **Current**: `public static func resolveInternalLinks(pages:pendingLinks:namedDestinations:)`
- **Expected**: Decompose, e.g. `PDF.Context.Link.Internal.resolve(pages:pending:destinations:)`.

### [API-NAME-002] Compound method name — `updateHorizontalRowMaxY`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:303`
- **Issue**: `updateHorizontalRowMaxY` is a heavily compound method name (five words).
- **Current**: `public mutating func updateHorizontalRowMaxY()`
- **Expected**: Restructure, e.g. `context.horizontal.row.updateMaxY()` or encapsulate in a verb-as-property accessor.

### [API-NAME-002] Compound property names on `PDF.Context`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:56,64,72,75,83,88-115,118,121,124,129,132,137,140,143,146,149`
- **Issue**: Multiple compound property names: `inlineRuns`, `listStack`, `pendingListMarker`, `preserveWhitespace`, `stackSpacing`, `lastElementY`, `measurementMode`, `horizontalSpacing`, `marginTop`, `marginRight`, `marginBottom`, `marginLeft`, `paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft`, `explicitWidth`, `explicitHeight`, `lastElementX`, `horizontalRowStartY`, `horizontalRowMaxY`, `scopeStack`, `currentLinkURL`, `textBlockOpen`, `currentTextFont`, `currentTextFontSize`, `currentTextColor`, `currentTextPosition`, `initialLayoutBox`, `completedPages`, `currentPageBuilder`, `currentPageAnnotations`, `pendingInternalLinks`, `fontRegistry`.
- **Current**: e.g. `public var inlineRuns`, `public var listStack`, `public var pendingListMarker`
- **Expected**: Use nested accessors, e.g. `context.inline.runs`, `context.list.stack`, `context.list.pendingMarker`. However, for `internal`/stored properties on a `@CoW` struct, nesting may not be practical. This is a stylistic concern for the public surface; internal properties have weaker naming requirements.

### [IMPL-EXPR-001] Unnecessary intermediate variable — `contentWidth`/`contentHeight`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:261-262,277-278`
- **Issue**: `contentWidth` and `contentHeight` are declared as separate variables and used exactly once in the initializer call. These could be inlined.
- **Current**:
  ```swift
  let contentWidth = mediaBox.width - margins.horizontal
  let contentHeight = mediaBox.height - margins.vertical
  self.init(x: .zero + margins.leading, y: .zero + margins.top,
            availableWidth: contentWidth, availableHeight: contentHeight, ...)
  ```
- **Expected**: Inline the expressions directly into the `self.init(...)` call.

### [IMPL-EXPR-001] Unnecessary intermediate variables in `resolveInternalLinks`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:514,525-526`
- **Issue**: `newAnnotations` is declared as a `var`, mutated, then used once. The `destination` and `link` variables are each used exactly once.
- **Current**:
  ```swift
  var newAnnotations = page.annotations
  for pendingLink in pageLinks {
      if let dest = namedDestinations[pendingLink.targetId] {
          let destination = ISO_32000.Destination.xyz(...)
          let link = PDF.Annotation.Link(destination: destination)
          let annotation = PDF.Annotation(rect: pendingLink.bounds, content: .link(link))
          newAnnotations.append(annotation)
      }
  }
  ```
- **Expected**: Inline `destination` and `link` into the `PDF.Annotation(...)` construction.

### [IMPL-EXPR-001] Unnecessary intermediate variables in `setFillColor`/`setStrokeColor`
- **File**: `Sources/PDF Rendering/PDF.Context.swift:562-583`
- **Issue**: The switch cases destructure color components into named bindings used exactly once. This is mechanism over intent, though the readability trade-off is minor.
- **Current**: `case .gray(let g): currentPageBuilder.setFillColorGray(g)`
- **Expected**: Acceptable as-is for readability, but noted for completeness.

### [IMPL-030] Intermediate variables in `Pair._renderRectangleContent`
- **File**: `Sources/PDF Rendering/Rendering/Pair+PDF.View.swift:56-99`
- **Issue**: `rectWidth`, `rectHeight`, `ascender`, `capHeight`, `baselineFromTop`, `contentY` are intermediate locals. Some (like `rectWidth`/`rectHeight`) are used twice, which is acceptable. But `baselineFromTop` is used once and could be inlined.
- **Current**: `let baselineFromTop = (rectHeight + capHeight) / 2`
- **Expected**: Inline into `startY + (rectHeight + capHeight) / 2 - ascender`.

### [IMPL-INTENT] Mechanism-heavy text rendering
- **File**: `Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:17-163`
- **Issue**: The `renderRuns` method is 146 lines of imperative byte-manipulation. While this is justified for performance (the method comments explain the optimization rationale), the nested switch/case/if structure reads as mechanism, not intent. The `RenderState` and `WordDescriptor` types help, but the overall flow is deeply procedural.
- **Current**: Imperative byte processing with manual state tracking.
- **Expected**: Not easily refactored without performance cost. Consider documenting the intent more prominently at the top of the method (e.g., "Tokenize runs into words, wrap to lines, emit with style batching").

### [IMPL-INTENT] Mechanism-heavy `markedContentInfo` method
- **File**: `Sources/PDF Rendering/PDF.Element.swift:78-157`
- **Issue**: Chain of `if Tag.self == ...` type checks with `unsafeBitCast` is mechanism-oriented pattern matching. This is a workaround for Swift's lack of static type dispatch on generic parameters, but it reads as mechanism rather than intent.
- **Current**:
  ```swift
  if Tag.self == ISO_32000.Table.self {
      let table = unsafeBitCast(tag, to: ISO_32000.Table.self)
      ...
  }
  ```
- **Expected**: Consider a protocol (e.g., `MarkedContentTaggable`) with a method returning `(COS.Name, COS.Dictionary?)`. This would replace the type-check chain with a single protocol dispatch. If that is not feasible due to cross-module constraints, the current approach is tolerable but should be documented as a workaround.

### [IMPL-034] `unsafe` keyword placement
- **File**: `Sources/PDF Rendering/Rendering/Pair+PDF.View.swift:21`
- **Issue**: `unsafeBitCast` is used without `unsafe` block annotation (Swift 6.2 style).
- **Current**: `unsafeBitCast(view.first, to: PDF.Rectangle.self)`
- **Expected**: Wrap in `unsafe { ... }` if strict memory safety is enabled, or ensure the module opts out. The main Package.swift does not enable `.strictMemorySafety()` for non-test targets, so this is not currently a build error, but it is not future-proof.

### [IMPL-034] `unsafe` keyword placement in `PDF.Element`
- **File**: `Sources/PDF Rendering/PDF.Element.swift:83,98,120`
- **Issue**: Three uses of `unsafeBitCast` without `unsafe` block wrapping.
- **Current**: `let table = unsafeBitCast(tag, to: ISO_32000.Table.self)`
- **Expected**: Same as above -- wrap in `unsafe { ... }` for forward compatibility.

### [IMPL-034] `force_try` usage
- **File**: `Sources/PDF Rendering/PDF.Element.swift:155`
- **Issue**: `try!` used in fallback path. While documented with a WORKAROUND comment, this is a runtime crash risk for unexpected type names.
- **Current**: `return (try! ISO_32000.COS.Name(typeName), nil)`
- **Expected**: Use `guard let name = try? ISO_32000.COS.Name(typeName) else { ... }` with a sensible fallback, or propagate the error.

### [IMPL-010] Raw `Int` at API surface
- **File**: `Sources/PDF Rendering/PDF.Context.swift:186`
- **Issue**: `pageNumber: Int` in `PendingInternalLink` uses raw `Int` instead of a typed page index.
- **Current**: `public let pageNumber: Int`
- **Expected**: Use a typed index (e.g., `PDF.Page.Index` or `Index<PDF.Page>`) to avoid off-by-one errors and clarify 1-indexed semantics.

### [IMPL-010] Raw `Int` at API surface
- **File**: `Sources/PDF Rendering/PDF.Context.swift:496`
- **Issue**: `namedDestinations` dictionary uses `(pageNumber: Int, yPosition: ...)` with raw `Int` for page number.
- **Current**: `namedDestinations: [String: (pageNumber: Int, yPosition: PDF.UserSpace.Y)]`
- **Expected**: Same typed page index as above.

### [IMPL-010] Raw `Int` at API surface
- **File**: `Sources/PDF Rendering/PDF.Context.List.Kind.swift:14`
- **Issue**: `case ordered(startNumber: Int)` uses raw `Int` for list numbering.
- **Current**: `case ordered(startNumber: Int)`
- **Expected**: Acceptable for a rendering hint (small boundary), but ideally would use a typed count.

### [IMPL-010] Raw `Int` values in heading level
- **File**: `Sources/PDF Rendering/PDF.Context+Rendering.swift:41-48`
- **Issue**: Heading level mapped to font size using a raw `Double` switch. The heading levels (`1...6`) are raw `Int` from the `Rendering.Semantic.Block.heading` case.
- **Current**:
  ```swift
  let headingSize: Double = switch level {
  case 1: 24
  case 2: 20
  ...
  }
  ```
- **Expected**: This is a boundary mapping (Rendering.Semantic -> PDF style), so raw values here are tolerable. Noted for awareness.

### [IMPL-040] Untyped throw with `force_try`
- **File**: `Sources/PDF Rendering/PDF.Element.swift:155`
- **Issue**: `try!` on `ISO_32000.COS.Name(typeName)` is an untyped crash path. Should either use typed throws or `preconditionFailure` with a clear message.
- **Current**: `try! ISO_32000.COS.Name(typeName)`
- **Expected**: `guard let name = try? ISO_32000.COS.Name(typeName) else { preconditionFailure("Invalid COS name from type: \(typeName)") }` or propagate as typed error.

### [PATTERN-009] Foundation import in test support
- **File**: `Tests/PDF Rendering Tests/Support/PDFOutput.swift:3`
- **Issue**: Foundation is imported in test support code. This is acceptable in test targets (not primitives/standards), so this is informational only.
- **Current**: `import Foundation`
- **Expected**: Acceptable in test support code at Layer 3 (Foundations).

### [PATTERN-010] File name mismatch
- **File**: `Sources/PDF Rendering/Rendering/Never+PDF.View.swift`
- **Issue**: File header comment says `// File.swift` but the file is named `Never+PDF.View.swift`.
- **Current**: `//  File.swift` (line 2)
- **Expected**: `// Never+PDF.View.swift`

### [API-IMPL-005] Multiple types in one file
- **File**: `Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:168-213`
- **Issue**: `RenderState` and `WordDescriptor` are declared alongside the `Text.Run` extension. These are private nested types used only by the renderer, so the violation is minor -- they are implementation details, not public API types.
- **Current**: Two private structs (`RenderState`, `WordDescriptor`) in a rendering extension file.
- **Expected**: Acceptable for private implementation types co-located with their only consumer. Strict compliance would put them in separate files, but the privacy boundary makes this low priority.

## Notes

### Positive patterns observed

1. **Verb-as-property pattern** (`advance`, `emit`, `flush`, `page`) is correctly applied per [IMPL-020]. These use `Property<Tag, Base>` with `callAsFunction` and follow the canonical pattern.

2. **Typed arithmetic** is consistently used throughout. Coordinates, widths, heights, and sizes all use typed geometric values (`PDF.UserSpace.Width`, `PDF.UserSpace.Height`, etc.). No raw `Double` arithmetic for geometric operations.

3. **Nest.Name pattern** is well-followed for core types: `PDF.Context`, `PDF.Context.Style`, `PDF.Context.Style.Resolved`, `PDF.Context.Text`, `PDF.Context.Text.Run`, `PDF.Context.List`, `PDF.Context.List.Kind`, `PDF.Context.List.Marker`, `PDF.Context.Scope`, `PDF.Context.Advance`, `PDF.Context.Emit`, `PDF.Context.Flush`, `PDF.Context.Page`.

4. **One type per file** is correctly followed for all public types.

5. **Specification-mirroring names** are correctly used: `ISO_32000.Table`, `ISO_32000.TH`, `ISO_32000.TD`, `ISO_32000.TR`, etc.

6. **@CoW** on `PDF.Context` provides zero-cost copy semantics per [IMPL-006].

7. **No Foundation imports** in any source file (only in test support, which is acceptable at Layer 3).
