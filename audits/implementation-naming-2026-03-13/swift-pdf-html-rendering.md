# swift-pdf-html-rendering Audit: Implementation + Naming

Date: 2026-03-13

## Summary
- Total files audited: 106 (Sources only)
- Total violations found: 34
- Critical (naming/compound types): 18
- Implementation style: 16

## Violations

### [API-NAME-002] Compound method: `resolveLineHeight`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:185`
- **Issue**: Compound method name with verb+noun
- **Current**: `func resolveLineHeight(for font:fontSize:) -> Double`
- **Expected**: `func lineHeight(resolved for:fontSize:) -> Double` or a nested accessor pattern

### [API-NAME-002] Compound method: `headingSize`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:228`
- **Issue**: Compound method name
- **Current**: `func headingSize(level:) -> PDF.UserSpace.Size<1>`
- **Expected**: `func heading(size level:) -> PDF.UserSpace.Size<1>` or nested accessor `heading.size(level:)`

### [API-NAME-002] Compound method: `headingMarginEm`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:242`
- **Issue**: Compound method name
- **Current**: `func headingMarginEm(for tag:) -> Scale<1, Double>`
- **Expected**: `func heading(marginEm for:) -> Scale<1, Double>` or nested accessor

### [API-NAME-002] Compound property: `paperSize`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:20`
- **Issue**: Compound property name
- **Current**: `var paperSize: PDF.UserSpace.Rectangle`
- **Expected**: `var paper: PDF.UserSpace.Rectangle` (the type already conveys it is a size/rectangle)

### [API-NAME-002] Compound property: `documentTitle`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:36`
- **Issue**: Compound property name
- **Current**: `var documentTitle: String?`
- **Expected**: Nested accessor `document.title` or scoped via a `Document` sub-struct

### [API-NAME-002] Compound property: `documentDate`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:39`
- **Issue**: Compound property name
- **Current**: `var documentDate: String?`
- **Expected**: Nested accessor `document.date` or scoped via a `Document` sub-struct

### [API-NAME-002] Compound property: `defaultFont`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:44`
- **Issue**: Compound property name -- "default" prefix adds mechanism
- **Current**: `var defaultFont: PDF.Font`
- **Expected**: `var font: PDF.Font` (it is the configuration default by context)

### [API-NAME-002] Compound property: `defaultFontSize`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:47`
- **Issue**: Compound property name
- **Current**: `var defaultFontSize: PDF.UserSpace.Size<1>`
- **Expected**: `var fontSize: PDF.UserSpace.Size<1>` (default is implied by being on Configuration)

### [API-NAME-002] Compound property: `defaultColor`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:50`
- **Issue**: Compound property name
- **Current**: `var defaultColor: PDF.Color`
- **Expected**: `var color: PDF.Color`

### [API-NAME-002] Compound property: `paragraphSpacing`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:62`
- **Issue**: Compound property name
- **Current**: `var paragraphSpacing: Scale<1, Double>`
- **Expected**: Nested accessor `paragraph.spacing` or a `Paragraph` sub-struct

### [API-NAME-002] Compound property: `headingSpacing`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:65`
- **Issue**: Compound property name
- **Current**: `var headingSpacing: Scale<1, Double>`
- **Expected**: Nested accessor `heading.spacing` or a `Heading` sub-struct

### [API-NAME-002] Compound property: `horizontalGapEm`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:80`
- **Issue**: Compound property name
- **Current**: `var horizontalGapEm: Scale<1, Double>`
- **Expected**: Nested accessor or typed dimension

### [API-NAME-002] Compound property: `deferredHeaderThreshold`
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:83`
- **Issue**: Compound property name
- **Current**: `var deferredHeaderThreshold: Scale<1, Double>`
- **Expected**: Nested accessor on header configuration: `header.deferredThreshold` or `header.threshold`

### [API-NAME-002] Compound method: `applyTagStyle`
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:10`
- **Issue**: Compound method name
- **Current**: `static func applyTagStyle(_ tagName:context:)`
- **Expected**: `static func apply(tag tagName:context:)` or `static func apply(style tagName:context:)`

### [API-NAME-002] Compound method: `blockMargins`
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:99`
- **Issue**: Compound method name
- **Current**: `static func blockMargins(for tagName:configuration:)`
- **Expected**: `static func margins(block tagName:configuration:)` or nested accessor

### [API-NAME-002] Compound method: `headingLevel`
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:131`
- **Issue**: Compound method name
- **Current**: `static func headingLevel(for tagName:) -> Int?`
- **Expected**: `static func heading(level tagName:) -> Int?`

### [API-NAME-002] Compound method: `isListContainer`
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:144`
- **Issue**: Compound method name
- **Current**: `static func isListContainer(_ tagName:) -> Bool`
- **Expected**: Consider a nested accessor or restructuring

### [API-NAME-002] Compound method: `listType`
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:149`
- **Issue**: Compound method name
- **Current**: `static func listType(for tagName:) -> PDF.Context.List.Kind?`
- **Expected**: `static func list(type tagName:) -> PDF.Context.List.Kind?`

### [API-IMPL-005] Multiple types in one file: Section + ActiveHeading
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context.Section.swift`
- **Issue**: File contains both `Section` and nested `ActiveHeading` struct
- **Current**: `Section` (line 6) and `ActiveHeading` (line 20) in same file
- **Expected**: `ActiveHeading` should be in `PDF.HTML.Context.Section.ActiveHeading.swift`

### [API-IMPL-005] Multiple types in one file: Render + Result + helpers
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Render.Result.swift`
- **Issue**: File contains both the `Render` namespace enum (line 10) and the `Result` struct (line 63), plus two static helper methods on `PDF.HTML`
- **Current**: `Render` namespace + `Result` struct + `prepareContext()` + `finalizeRendering()` in one file
- **Expected**: `Render` namespace in `PDF.HTML.Render.swift`, `Result` in `PDF.HTML.Render.Result.swift`, helper methods in a separate extension file

### [IMPL-INTENT] Mirror-based type erasure for inline style dispatch
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:165`
- **Issue**: Uses `Mirror(reflecting:)` to unwrap optionals -- this is mechanism, not intent. Mirror is a debug/reflection API, not a production dispatch tool.
- **Current**: `let mirror = Mirror(reflecting: property); if mirror.displayStyle == .optional { ... }`
- **Expected**: Use generic overloads or a protocol-based dispatch pattern to avoid runtime reflection

### [IMPL-EXPR-001] Unnecessary intermediate variables in viewer construction
- **File**: `Sources/PDF HTML Rendering/PDF.Document+HTML.swift:33-56`
- **Issue**: `viewer` is constructed, then `viewerOrNil` is computed from it -- two intermediates where one expression suffices
- **Current**: `let viewer = ISO_32000.Viewer(...)` then `let viewerOrNil: ISO_32000.Viewer? = configuration.viewer == .init() ? nil : viewer`
- **Expected**: Single expression: build viewer inline only when needed, or use a computed function

### [IMPL-EXPR-001] Repeated `let currentSize = context.style.fontSize ?? configuration.defaultFontSize`
- **File**: Multiple CSS modifier files (MarginTop, MarginBottom, MarginLeft, MarginRight, PaddingTop, PaddingBottom, PaddingLeft, PaddingRight, Width, Height, Margin, Padding -- 12 files)
- **Issue**: Every CSS box model modifier repeats the same `fontSize ?? defaultFontSize` fallback inline instead of having a single resolved accessor
- **Current**: `let currentSize = context.style.fontSize ?? configuration.defaultFontSize` (12+ occurrences)
- **Expected**: A computed property like `context.style.resolvedFontSize(default: configuration.defaultFontSize)` or `context.currentFontSize(configuration:)`

### [IMPL-030] Intermediate variable `scope` in pushElement
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:347-358`
- **Issue**: Constructs `scope` as a let and immediately appends it -- could be inlined
- **Current**: `let scope = Element.Scope(...); context.elementStack.append(scope)`
- **Expected**: `context.elementStack.append(.init(...))`

### [IMPL-031] Manual switch for heading levels instead of data-driven iteration
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:13-30`
- **Issue**: Six nearly identical heading cases that only differ by level number
- **Current**: Separate `case "h1": ... case "h2": ... case "h3": ...` etc.
- **Expected**: Extract heading level from tag name, then apply uniformly: `if let level = headingLevel(for: tagName) { context.pdf.style.font = .bold; context.pdf.style.fontSize = context.configuration.headingSize(level: level) }`

### [IMPL-031] Manual switch for headingSize
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:229-237`
- **Issue**: Six case statements mapping level 1-6 to multipliers
- **Current**: `switch level { case 1: return defaultFontSize * 2.0; case 2: return defaultFontSize * 1.5; ... }`
- **Expected**: Use a static array of scale factors: `let scales: [Double] = [2.0, 1.5, 1.17, 1.0, 0.83, 0.67]; return defaultFontSize * scales[level - 1]`

### [IMPL-031] Manual switch for headingMarginEm
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift:243-251`
- **Issue**: Six case statements for heading margin em values
- **Current**: `switch tag { case "h1": return 0.67; case "h2": return 0.83; ... }`
- **Expected**: Data-driven lookup or level-based array

### [IMPL-031] Manual switch for headingLevel
- **File**: `Sources/PDF HTML Rendering/HTML.Element.Tag+TagStyle.swift:132-140`
- **Issue**: Six case statements to parse heading level from tag name
- **Current**: `switch tagName { case "h1": return 1; case "h2": return 2; ... }`
- **Expected**: Parse the digit from the tag name: `if tagName.hasPrefix("h"), let d = Int(String(tagName.dropFirst())), (1...6).contains(d) { return d }`

### [IMPL-033] Per-element loop in cumulative width/height recomputation
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context.Table.swift:52-59, 64-73`
- **Issue**: Manual sum loop where a scan/prefix-sum expression communicates intent better
- **Current**: `var sum = .zero; for width in columnWidths { sum = sum + width; cumulative.append(sum) }`
- **Expected**: Bulk operation or `reduce(into:)` -- though performance is equivalent, a scan captures intent more directly

### [IMPL-010] Raw Int used for row/column/level throughout Table and Grid
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context.Table.swift:83, 86, 106, 188, 191, 194, 200, 207, 217`
- **Issue**: Row indices, column indices, and heading levels are all bare `Int` -- no typed wrapper prevents mixing them
- **Current**: `var currentRow: Int`, `var currentColumn: Int`, `func xForColumn(_ column: Int)`, `var columnCount: Int`, etc.
- **Expected**: Consider typed wrappers (e.g., `Table.Row.Index`, `Table.Column.Index`) to prevent accidental mixing of row and column values

### [IMPL-010] Raw Int for pageNumber and heading level
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context.Section.HeadingEntry.swift:7-9`, `Sources/PDF HTML Rendering/PDF.HTML.Context.Link.Destination.swift:7`, `Sources/PDF HTML Rendering/PDF.HTML.Page.Info.swift:11-14`
- **Issue**: `pageNumber: Int`, `level: Int`, `totalPages: Int` are all bare Int
- **Current**: `public let level: Int; public let pageNumber: Int`
- **Expected**: Typed wrappers or at minimum Index<Page> / Count<Page>

### [IMPL-006] Untyped `Double` for annotation border width
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Configuration.Annotation.Border.swift:10`
- **Issue**: `width` stored as raw `Double` instead of a typed dimension
- **Current**: `public var width: Double`
- **Expected**: `public var width: PDF.UserSpace.Size<1>` (consistent with `Table.Border.width` which uses `PDF.UserSpace.Size<1>`)

### [IMPL-INTENT] `@unchecked Sendable` on Deferred without justification enforcement
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context.Deferred.swift:6`
- **Issue**: `@unchecked Sendable` is used because the closure captures non-Sendable generic types. While the comment explains why, this is a mechanism workaround -- the type should either be genuinely Sendable or not claim to be
- **Current**: `public struct Deferred: @unchecked Sendable`
- **Expected**: Drop Sendable if the type is not actually safe to transfer across concurrency domains, or restructure to make it genuinely Sendable

### [IMPL-INTENT] `@unchecked Sendable` on Recording.Command
- **File**: `Sources/PDF HTML Rendering/PDF.HTML.Context.Table.Recording.Command.swift:12`
- **Issue**: `@unchecked Sendable` for the `inlineStyle(Any)` case -- type-erased `Any` hides what is stored
- **Current**: `enum Command: @unchecked Sendable { case inlineStyle(Any) ... }`
- **Expected**: Use a concrete protocol-existential (e.g., `any PDF.HTML.Style.Modifier`) instead of `Any` to preserve type safety

## Notable Positives

- **[API-NAME-001]**: All types correctly use the `Nest.Name` extension pattern (`PDF.HTML.Context.Table.Grid.Span`, etc.). No compound type names found.
- **[API-NAME-003]**: Specification types (`ISO_32000`, `W3C_CSS_*`) are correctly mirrored.
- **[API-NAME-004]**: No typealiases for type unification found.
- **[API-ERR-001]**: No throwing functions exist in this package, so typed throws is not applicable.
- **[PATTERN-009]**: No Foundation imports anywhere in the package.
- **[PATTERN-017]**: No `.rawValue` extraction found at any call site.
- **[PATTERN-010]**: Nested type naming is consistent throughout.
- **[PATTERN-022]**: No ~Copyable types in this package.
- **[IMPL-020]**: Good use of `callAsFunction` on `Table.Cell` for positioned cell access.
- **[IMPL-034]**: The single `unsafe` usage (not found in sources) is not applicable here.
- **File organization**: The 106 source files follow one-type-per-file discipline well, with only 2 exceptions noted above.
