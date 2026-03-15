# Research: Direct Context Rendering for Markdown

## Assignment

Design a theoretically perfect architecture for rendering markdown directly into a `Rendering.Context` — eliminating `HTML.AnyView` type erasure from the markdown→HTML and markdown→PDF pipelines entirely.

**Quality bar**: Academically perfect code. No compromises for implementation effort. Every design decision must be justified from first principles.

**Research process**: Follow [RES-004] Investigation Methodology. Enumerate options, identify criteria, analyze trade-offs, recommend.

**Output**: Research document at `swift-institute/Research/markdown-direct-context-rendering.md` per [RES-003].

---

## Context

### What exists today

The markdown rendering pipeline converts markdown to rendered output through three phases:

1. **Parse**: `SwiftMarkdown.Document(parsing: string)` → markdown AST
2. **Visit**: `Markdown.Converter` (a `MarkupVisitor`) walks the AST, producing `HTML.AnyView` at every node
3. **Render**: `HTML.AnyView._render(view, context: &context)` dispatches to concrete views which write to the context

Phase 2 is the problem. Every `visit*` method returns `HTML.AnyView` — a type-erased existential wrapper. This causes:

- **Stack overflow** in PDF rendering with deeply nested content (the `_render` call chain recurses through existentials)
- **Loss of semantic identity** — a markdown heading becomes a generic `AnyView` wrapping a `div` wrapping an `h1`, losing its "heading" nature
- **Existential dispatch overhead** at every render node
- **Repeated boilerplate** — 18 element types with identical `nonisolated(unsafe)` + AnyView wrapping

The type erasure is forced by `MarkupVisitor`'s `associatedtype Result` — the converter must return a single type from all visit methods. We chose `HTML.AnyView` as that type. The proposed change: choose `Void` instead, and write directly to the context.

### Why this matters

The `Rendering.Context` protocol already supports direct rendering. Every leaf view (`HTML.Element.Tag`, `HTML.Text`, `HTML.Raw`) ultimately calls context methods like `context.push.element(...)`, `context.text(...)`, `context.pop.element(...)`. The view tree is an intermediate representation that adds no semantic value — it's created only to be immediately consumed.

The rendering infrastructure is designed for exactly this use case. `_render<C: Context>` is generic over `C`. Both `HTML.Context` and `PDF.HTML.Context` conform to `Rendering.Context`. The same context methods work for both formats.

---

## The Current Architecture (Reference)

### Rendering.View protocol (Layer 1: Primitives)

```swift
extension Rendering {
    public protocol View: ~Copyable {
        associatedtype RenderBody: View & ~Copyable
        @Builder var body: RenderBody { get }

        static func _render<C: Context>(
            _ view: borrowing Self, context: inout C
        )
    }
}

extension Rendering.View where RenderBody: Rendering.View {
    @inlinable
    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        RenderBody._render(view.body, context: &context)
    }
}
```

Key: composite views define `body` which recursively renders. Leaf views (`RenderBody == Never`) override `_render` to write directly to the context.

### Rendering.Context protocol (Layer 1: Primitives)

The context is a **push/pop event sink**. It receives structured content events:

```swift
extension Rendering {
    public protocol Context: ~Copyable {
        // Direct instance methods
        mutating func text(_ content: borrowing String)
        mutating func lineBreak()
        mutating func thematicBreak()
        mutating func image(source: String, alt: String)
        mutating func pageBreak()
        mutating func set(attribute name: String, _ value: String?)
        mutating func add(`class` name: String)
        mutating func write(raw bytes: [UInt8])
        mutating func register(style declaration: String, atRule: String?, selector: String?, pseudo: String?) -> String?

        // Static push/pop requirements
        static func _pushBlock(_ context: inout Self, role: Semantic.Block?, style: Style)
        static func _popBlock(_ context: inout Self)
        static func _pushInline(_ context: inout Self, role: Semantic.Inline?, style: Style)
        static func _popInline(_ context: inout Self)
        static func _pushList(_ context: inout Self, kind: Semantic.List, start: Int?)
        static func _popList(_ context: inout Self)
        static func _pushItem(_ context: inout Self)
        static func _popItem(_ context: inout Self)
        static func _pushLink(_ context: inout Self, destination: borrowing String)
        static func _popLink(_ context: inout Self)
        static func _pushAttributes(_ context: inout Self)
        static func _popAttributes(_ context: inout Self)
        static func _pushElement(_ context: inout Self, tagName: String, isBlock: Bool, isVoid: Bool, isPreElement: Bool)
        static func _popElement(_ context: inout Self, isBlock: Bool)
        static func _pushStyle(_ context: inout Self)
        static func _popStyle(_ context: inout Self)

        mutating func apply(inlineStyle property: Any) -> Bool
    }
}
```

The context is accessed through Property.View accessors:
```swift
context.push.block(role: .heading(level: 1), style: .empty)
context.text("Hello")
context.pop.block()
```

### Semantic roles (Layer 1: Primitives)

```swift
extension Rendering.Semantic {
    public enum Block: Sendable {
        case heading(level: Int)
        case paragraph
        case blockquote
        case section
        case pre
        case table
        case row
        case cell(header: Bool)
    }

    public enum Inline: Sendable {
        case emphasis
        case strong
        case code
    }

    public enum List: Sendable {
        case ordered
        case unordered
    }
}
```

### How HTML.Element.Tag renders (Layer 3: Foundations)

```swift
extension HTML.Element.Tag: Rendering.View where Content: HTML.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        context.push.element(
            tagName: view.tagName,
            block: view.isBlock,
            void: view.isVoid,
            preformatted: view.isPreElement
        )

        if !view.isVoid, let content = view.content {
            Content._render(content, context: &context)
        }

        if !view.isVoid {
            context.pop.element(block: view.isBlock)
        }
    }
}
```

This is the pattern: push, render children, pop. The context handles format-specific output (HTML bytes vs PDF operations).

### How HTML.AnyView renders

```swift
extension HTML {
    public struct AnyView: HTML.View, @unchecked Sendable {
        public let base: any HTML.View

        public typealias RenderBody = Never
        public var body: Never { fatalError() }

        public static func _render<C: Rendering.Context>(
            _ view: borrowing HTML.AnyView, context: inout C
        ) {
            _openAndRender(view.base, context: &context)
        }

        private static func _openAndRender<V: HTML.View, C: Rendering.Context>(
            _ base: V, context: inout C
        ) {
            V._render(base, context: &context)
        }
    }
}
```

Every `AnyView._render` call opens an existential and dynamically dispatches. With 50+ elements in a markdown document, this creates 50+ stack frames of existential dispatch.

### How Rendering.Builder composes (flat _Tuple)

```swift
extension Rendering {
    @resultBuilder
    public enum Builder {
        public static func buildBlock<each Content>(
            _ content: repeat each Content
        ) -> Rendering._Tuple<repeat each Content> {
            Rendering._Tuple(repeat each content)
        }
        // ... buildOptional, buildEither, buildArray
    }
}

extension Rendering._Tuple: Rendering.View where repeat each Content: Rendering.View {
    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        func render<V: Rendering.View>(_ v: V, _ ctx: inout C) {
            V._render(v, context: &ctx)
        }
        repeat render(each view.content, &context)
    }
}
```

The builder produces flat tuples — O(1) nesting depth. But AnyView re-introduces nesting.

### The current Markdown.Converter (the problem)

```swift
extension Markdown {
    struct Converter: SwiftMarkdown.MarkupVisitor {
        typealias Result = HTML.AnyView  // ← forces type erasure

        let configuration: Markdown.Configuration
        let previewOnly: Bool

        var tableOfContents: [Markdown.Section] = []

        // Every visit method returns HTML.AnyView:
        mutating func visitHeading(_ heading: SwiftMarkdown.Heading) -> HTML.AnyView {
            let slug = generateSlug(for: heading.plainText)
            let childrenHTML = HTML.AnyView {
                for child in heading.children { visit(child) }
            }
            configuration.elements.heading.render(
                .init(level: heading.level, slug: slug, plainText: heading.plainText, children: childrenHTML)
            )
        }

        mutating func visitParagraph(_ paragraph: SwiftMarkdown.Paragraph) -> HTML.AnyView {
            let childrenHTML = HTML.AnyView {
                for child in paragraph.children { visit(child) }
            }
            configuration.elements.paragraph.render(.init(children: childrenHTML))
        }

        // ... 15 more visit methods, all returning HTML.AnyView
        // ... children are always wrapped in HTML.AnyView { for child in ... { visit(child) } }
    }
}
```

Pattern: visit children → wrap in `AnyView` → pass to element renderer → renderer wraps result in `AnyView` → return. Double erasure at every level.

### How Markdown.body uses the converter

```swift
public var body: some HTML_Renderable.HTML.View {
    var converter = Converter(configuration: configuration, previewOnly: previewOnly)
    let content = converter.visit(
        SwiftMarkdown.Document(parsing: markdownString, options: .parseBlockDirectives)
    )

    return ContentDivision {
        VStack(spacing: .rem(0.5)) {
            content  // ← HTML.AnyView, rendered into context later
        }
        .css
        .inlineStyle("mask-image", previewOnly ? "..." : nil)
    }
    .css
    .display(.block)
}
```

The `Markdown` struct conforms to `HTML.View`. Its `body` builds a view tree that gets rendered through the normal `_render<C>` path. The converter's `AnyView` output is embedded in this tree.

### Element renderer pattern (18 types, all identical structure)

```swift
extension Markdown.Configuration.Elements {
    public struct Heading: Sendable {
        public var render: @Sendable (Input) -> HTML.AnyView

        public init<View: HTML.View>(
            @HTML.Builder _ render: @escaping @Sendable (Input) -> View
        ) {
            nonisolated(unsafe) let unsafeRender = render
            self.render = { input in
                HTML.AnyView(unsafeRender(input))
            }
        }
    }
}

extension Markdown.Configuration.Elements.Heading {
    public struct Input: Sendable {
        public let level: Int
        public let slug: String
        public let plainText: String
        public let children: HTML.AnyView  // ← pre-rendered children as AnyView
    }
}

extension Markdown.Configuration.Elements.Heading {
    public static var `default`: Self {
        .init { input in
            // Returns an HTML view tree (which gets wrapped in AnyView by the init)
            Anchor {} .id(input.slug) ...
            ContentDivision { tag("h\(input.level)") { input.children } ... }
        }
    }
}
```

Each element renderer:
1. Takes an `Input` containing data + pre-rendered children (`HTML.AnyView`)
2. Returns `HTML.AnyView` (via the `init`'s `nonisolated(unsafe)` wrapping)
3. The default implementation builds an HTML view tree

### apple/swift-markdown MarkupVisitor protocol

```swift
public protocol MarkupVisitor<Result> {
    associatedtype Result

    mutating func defaultVisit(_ markup: Markup) -> Result
    mutating func visit(_ markup: Markup) -> Result

    // Block elements
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> Result
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Result
    mutating func visitHeading(_ heading: Heading) -> Result
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> Result
    mutating func visitHTMLBlock(_ html: HTMLBlock) -> Result
    mutating func visitListItem(_ listItem: ListItem) -> Result
    mutating func visitOrderedList(_ orderedList: OrderedList) -> Result
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> Result
    mutating func visitParagraph(_ paragraph: Paragraph) -> Result
    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> Result

    // Inline elements
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> Result
    mutating func visitEmphasis(_ emphasis: Emphasis) -> Result
    mutating func visitImage(_ image: Image) -> Result
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> Result
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> Result
    mutating func visitLink(_ link: Link) -> Result
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Result
    mutating func visitStrong(_ strong: Strong) -> Result
    mutating func visitText(_ text: Text) -> Result
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> Result

    // Table elements
    mutating func visitTable(_ table: Table) -> Result
    mutating func visitTableHead(_ tableHead: Table.Head) -> Result
    mutating func visitTableBody(_ tableBody: Table.Body) -> Result
    mutating func visitTableRow(_ tableRow: Table.Row) -> Result
    mutating func visitTableCell(_ tableCell: Table.Cell) -> Result

    // Documentation elements (not used by markdown-html-rendering)
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> Result
    mutating func visitInlineAttributes(_ attributes: InlineAttributes) -> Result
    mutating func visitDoxygenDiscussion/Note/Abstract/Parameter/Returns -> Result
}
```

Key: `Result` is an associated type. We can set it to anything, including `Void`.

### How PDF.HTML.Context handles rendering events

`PDF.HTML.Context` conforms to `Rendering.Context`. Examples of how it handles semantic events:

```swift
extension PDF.HTML.Context: Rendering.Context {
    public mutating func text(_ content: borrowing String) {
        // Capture heading text for bookmarks
        if section.activeHeading != nil {
            section.activeHeading!.text += copy content
        }
        // Convert to PDF text runs with font/color/link state
        let runs = PDF.Context.Text.Run.runsWithSymbolSupport(
            text: copy content, font: pdf.style.font, fontSize: pdf.style.fontSize,
            color: pdf.style.color, textDecoration: pdf.style.textMarkup, ...
        )
        for run in runs { pdf.append(inline: run) }
    }

    public mutating func lineBreak() {
        pdf.flush.inline()
        pdf.advance.line()
    }

    public static func _pushBlock(_ context: inout Self, role: Semantic.Block?, style: Style) {
        // Apply margin collapsing, push element scope, handle heading start, etc.
    }

    public static func _popBlock(_ context: inout Self) {
        // Pop element scope, finalize heading, apply pending bottom margin
    }

    public static func _pushList(_ context: inout Self, kind: Semantic.List, start: Int?) {
        // Push list indentation, store list kind for bullets vs numbers
    }
}
```

The PDF context handles the same semantic events as HTML.Context but produces PDF layout operations instead of HTML bytes. **Both contexts already handle the semantic level — they don't need HTML element types as intermediaries.**

---

## The Design Question

How should markdown rendering bypass the view tree entirely and write directly to a `Rendering.Context`, while preserving:

1. **Format independence** — same converter renders to both HTML and PDF
2. **Configurability** — users can still customize how each element renders
3. **Semantic preservation** — heading/paragraph/list semantics flow to the context
4. **Table of contents extraction** — headings accumulate during traversal
5. **Directive handling** — custom block directives remain extensible
6. **`Markdown` as `HTML.View`** — the `Markdown` struct must still conform to `HTML.View` so it composes with other HTML views and works in `HTML.Document { Markdown { ... } }`
7. **CSS styling** — the HTML output must still support CSS classes and inline styles
8. **Diagnostic rendering** — blockquote→diagnostic mapping must work
9. **SwiftUI previews** — `#Preview { HTML.Document { Markdown { ... } } }` must work (the recently-fixed RenderBody rename enables this)

---

## Constraints

### Non-negotiable

1. **`Markdown: HTML.View`** — Markdown must conform to `HTML.View` (and therefore `Rendering.View`). It must compose inside `HTML.Document { ... }`, `PDF.Document { ... }`, and arbitrary HTML view trees.

2. **Single `_render<C: Rendering.Context>` entry point** — the rendering pipeline uses static dispatch on the context type parameter. This must be preserved.

3. **Configuration customizability** — users must be able to override any element's rendering behavior (heading style, code block appearance, etc.)

4. **No Foundation in primitives** — `Rendering.View`, `Rendering.Context` are in Layer 1. No Foundation types.

5. **[API-IMPL-005] One type per file** — new types go in separate files.

6. **[API-NAME-001] Namespace nesting** — no compound names. Use `Markdown.Converter`, `Markdown.Configuration`, etc.

7. **Table of contents as side-effect** — `Markdown.tableOfContents(from:)` must still work by accumulating headings during traversal.

### Strongly preferred

8. **No `HTML.AnyView`** — the whole point of this research. If AnyView appears anywhere in the new design, justify why it's unavoidable.

9. **O(1) stack depth** — rendering should not recurse through existentials. Direct context calls are O(1) stack frames per element.

10. **Sendable** — configuration and element renderers must be `Sendable`.

11. **`@HTML.Builder` syntax preserved** — users writing custom element renderers should still use the `@HTML.Builder` result builder syntax if they want view-tree-based rendering. The default renderers may use direct context calls instead.

### Open questions (the research should resolve these)

12. **Can custom renderers mix view-tree and direct-context approaches?** If a user provides an `@HTML.Builder`-based renderer for headings but uses the default (direct-context) renderer for everything else, does the architecture handle this cleanly?

13. **Should `Rendering.Semantic` gain markdown-specific roles?** Currently the semantic roles are HTML-derived (heading, paragraph, blockquote, pre, table). Should markdown add its own (e.g., `case codeBlock(language: String?)`, `case image(source: String, alt: String)`)? Or are the existing roles sufficient?

14. **How does the `previewOnly` gradient mask work without a view tree?** The current implementation wraps the entire output in a `ContentDivision` with a CSS mask. With direct context rendering, how is this applied?

15. **How does the diagnostic blockquote mapping work?** Currently, blockquotes check for diagnostic aside kinds and render a `Markdown.Diagnostic(level:) { children }` view. Without AnyView, how are children passed to the diagnostic renderer?

16. **What is the Input type for configurable renderers?** Currently, Input holds `children: HTML.AnyView`. Without AnyView, what replaces it? A closure `(inout C) -> Void`? A rendering thunk?

---

## Approaches to Evaluate

### Approach A: Void-returning visitor with context parameter

Make the converter generic over `C: Rendering.Context`. Set `Result = Void`. Each visit method writes directly to the context:

```swift
extension Markdown {
    struct Converter<C: Rendering.Context>: SwiftMarkdown.MarkupVisitor {
        typealias Result = Void

        var context: UnsafeMutablePointer<C>  // or inout binding
        let configuration: Markdown.Configuration

        mutating func visitHeading(_ heading: SwiftMarkdown.Heading) {
            let slug = generateSlug(for: heading.plainText)
            context.pointee.push.block(role: .heading(level: heading.level), style: .empty)
            for child in heading.children { visit(child) }
            context.pointee.pop.block()
        }

        mutating func visitParagraph(_ paragraph: SwiftMarkdown.Paragraph) {
            context.pointee.push.block(role: .paragraph, style: .empty)
            for child in paragraph.children { visit(child) }
            context.pointee.pop.block()
        }

        mutating func visitText(_ text: SwiftMarkdown.Text) {
            context.pointee.text(text.string)
        }
    }
}
```

**Pros**: Zero type erasure. O(1) stack depth per element. Direct semantic mapping.
**Cons**: Loses configurability (hardcoded rendering). The generic `C` parameter may cause issues with `MarkupVisitor` conformance. Passing `inout C` through a mutating visitor is awkward (requires unsafe pointer or reference wrapper).

### Approach B: Rendering thunks (closures capturing context operations)

Instead of returning `HTML.AnyView`, each visit returns a rendering thunk `(inout C) -> Void`:

```swift
extension Markdown {
    struct Converter<C: Rendering.Context>: SwiftMarkdown.MarkupVisitor {
        typealias Result = (inout C) -> Void

        mutating func visitHeading(_ heading: SwiftMarkdown.Heading) -> (inout C) -> Void {
            let slug = generateSlug(for: heading.plainText)
            let childThunks = heading.children.map { visit($0) }
            return { context in
                context.push.block(role: .heading(level: heading.level), style: .empty)
                for thunk in childThunks { thunk(&context) }
                context.pop.block()
            }
        }
    }
}
```

**Pros**: Deferred rendering (can inspect/transform before executing). Composable.
**Cons**: Closures allocate. Still has nesting (closure calling closures). The `C` generic parameter leaks into the `Result` type, which `MarkupVisitor` may not support (it expects a concrete `Result`).

### Approach C: Markdown as a leaf view with RenderBody == Never

Make `Markdown` a leaf view that overrides `_render` directly, bypassing `body` entirely:

```swift
public struct Markdown: HTML.View {
    let markdownString: String
    let configuration: Configuration

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        var converter = Converter(context: &context, configuration: view.configuration)
        converter.visit(
            SwiftMarkdown.Document(parsing: view.markdownString, options: .parseBlockDirectives)
        )
    }
}
```

**Pros**: Cleanest integration with Rendering.View. No intermediate view tree. `_render` is the single entry point.
**Cons**: `body` returns `Never`, so `Markdown` can't be inspected structurally. Must combine with Approach A or B for the converter internals.

### Approach D: Configurable renderers as context writers

Instead of element renderers returning `HTML.AnyView`, they write directly to the context:

```swift
extension Markdown.Configuration {
    struct Renderer<Input: Sendable>: Sendable {
        let render: @Sendable (Input, inout some Rendering.Context) -> Void
    }
}
```

But `inout some Rendering.Context` is not expressible in a stored closure in Swift 6.2 (existential `some` can't appear in function parameter of stored property).

Variant: erase the context through a protocol witness table or callback struct:

```swift
struct ContextWriter: ~Copyable {
    private let _text: (borrowing String) -> Void
    private let _pushBlock: (Rendering.Semantic.Block?, Rendering.Style) -> Void
    private let _popBlock: () -> Void
    // ... all Rendering.Context methods as closures
}
```

**Pros**: Fully configurable. No generic parameter leakage.
**Cons**: Manual protocol witness table. Verbose. Loses static dispatch (closures are dynamic dispatch).

### Approach E: Two-phase rendering (semantic IR + presentation)

Introduce a semantic intermediate representation between markdown AST and rendering:

```swift
extension Markdown {
    indirect enum Node: Sendable {
        case heading(level: Int, slug: String, children: [Node])
        case paragraph(children: [Node])
        case text(String)
        case emphasis(children: [Node])
        case strong(children: [Node])
        case codeBlock(language: String?, code: String)
        case link(destination: String?, children: [Node])
        case image(source: String?, alt: String?)
        case list(ordered: Bool, items: [[Node]])
        case blockquote(kind: String, children: [Node])
        case thematicBreak
        case lineBreak
        case softBreak
        case raw([UInt8])
    }
}
```

Phase 1: Markdown AST → `Markdown.Node` (pure data, no rendering)
Phase 2: `Markdown.Node` + configuration → rendering context events

**Pros**: Clean separation. Phase 1 is testable independently. Phase 2 can be customized per-node. No type erasure.
**Cons**: Extra allocation (the Node tree). Duplicates the markdown AST in a different shape.

### Approach F: Hybrid — direct rendering with view-tree escape hatch

Default element renderers write directly to the context. Custom renderers can return `HTML.View` which gets rendered through the normal path. The converter detects which mode each element uses:

```swift
extension Markdown.Configuration {
    enum Renderer<Input: Sendable>: Sendable {
        case direct(@Sendable (Input, inout any Rendering.Context) -> Void)
        case view(@Sendable (Input) -> HTML.AnyView)
    }
}
```

**Pros**: Backward compatible. Default path is zero-erasure. Custom path still works.
**Cons**: `any Rendering.Context` existential in the direct case loses static dispatch. The enum adds branching at every element.

---

## Evaluation Criteria

1. **Zero type erasure** — does the approach eliminate `HTML.AnyView` entirely?
2. **O(1) stack depth** — does rendering depth depend on document size?
3. **Static dispatch** — does the rendering path use generic specialization or existential dispatch?
4. **Configurability** — can users override element rendering?
5. **Composability** — does `Markdown` compose inside `HTML.Document`, `PDF.Document`, other views?
6. **Semantic preservation** — do heading levels, list types, etc. reach the context?
7. **Table of contents** — can headings be accumulated during traversal?
8. **CSS support** — does the HTML context still produce styled output?
9. **Sendable** — is the configuration Sendable?
10. **Complexity** — how many new types? How deep is the abstraction?
11. **Migration path** — can the current `@HTML.Builder` configuration syntax survive?

---

## Package Locations (for exploration)

| Package | Path |
|---------|------|
| swift-rendering-primitives | `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/` |
| swift-html-rendering | `/Users/coen/Developer/swift-foundations/swift-html-rendering/` |
| swift-markdown-html-rendering | `/Users/coen/Developer/swift-foundations/swift-markdown-html-rendering/` |
| swift-pdf-html-rendering | `/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/` |
| swift-pdf | `/Users/coen/Developer/swift-foundations/swift-pdf/` |
| diagnostic-primitives | `/Users/coen/Developer/swift-primitives/swift-diagnostic-primitives/` |

### Key files to study

| File | Contains |
|------|----------|
| `swift-rendering-primitives/.../Rendering.View.swift` | `Rendering.View` protocol |
| `swift-rendering-primitives/.../Rendering.Context.swift` | `Rendering.Context` protocol with all push/pop methods |
| `swift-rendering-primitives/.../Rendering.Semantic.Block.swift` | Block-level semantic roles |
| `swift-rendering-primitives/.../Rendering.Semantic.Inline.swift` | Inline semantic roles |
| `swift-rendering-primitives/.../Rendering.Semantic.List.swift` | List semantic roles |
| `swift-rendering-primitives/.../Rendering.Style.swift` | Format-independent style hints |
| `swift-rendering-primitives/.../Rendering.Builder.swift` | Result builder (flat _Tuple) |
| `swift-rendering-primitives/.../Rendering._Tuple.swift` | Flat variadic composition |
| `swift-html-rendering/.../HTML.View.swift` | `HTML.View` refines `Rendering.View` |
| `swift-html-rendering/.../HTML.Context.swift` | HTML rendering context (634 lines) |
| `swift-html-rendering/.../HTML.AnyView.swift` | Type-erased view wrapper |
| `swift-html-rendering/.../HTML.Element.swift` | `HTML.Element.Tag._render` — push/pop element |
| `swift-html-rendering/.../HTML.Document.Protocol.swift` | Document rendering (two-phase style collection) |
| `swift-html-rendering/.../HTML.Document+ViewRepresentable.swift` | SwiftUI bridge (recently added) |
| `swift-markdown-html-rendering/.../Markdown.swift` | `Markdown` struct (HTML.View conformance) |
| `swift-markdown-html-rendering/.../Markdown.Converter.swift` | MarkupVisitor → HTML.AnyView (the problem file) |
| `swift-markdown-html-rendering/.../Markdown.Configuration.swift` | Configuration aggregate |
| `swift-markdown-html-rendering/.../Markdown.Configuration.Element.*.swift` | 17 element renderers |
| `swift-markdown-html-rendering/.../Markdown.Diagnostic.swift` | Diagnostic view component |
| `swift-pdf-html-rendering/.../PDF.HTML.Context.swift` | PDF rendering context |
| `swift-pdf-html-rendering/.../PDF.HTML.Context+Rendering.swift` | Rendering.Context conformance (1095 lines) |

### Research to reference

| Document | Path |
|----------|------|
| Rendering.View associated type naming | `swift-institute/Research/rendering-view-associated-type-naming.md` |
| Markdown rendering organization audit | `swift-institute/Research/markdown-rendering-organization-audit.md` |
| SwiftUI preview investigation prompt | `swift-institute/Research/prompts/markdown-swiftui-pdf-investigation.md` |
| Stack overflow research | `swift-pdf/Research/sigbus-stack-overflow-handoff.md` |

---

## Success Criteria

The research is complete when:

1. Each approach (A–F) is analyzed against all 11 evaluation criteria
2. A recommendation is made with full justification
3. The recommended approach includes a detailed type design showing:
   - The new `Markdown.Converter` signature
   - The new element renderer type (or why renderers change)
   - How `Markdown` conforms to `HTML.View` and renders via `_render<C>`
   - How children are passed to configurable renderers without AnyView
   - How table of contents extraction works
   - How CSS styling survives (classes, inline styles)
   - How diagnostic blockquotes work
4. A migration path from the current architecture is described
5. Any required changes to `Rendering.Context`, `Rendering.Semantic`, or other primitives are identified
6. The stack overflow issue is addressed (PDF rendering of deeply nested markdown)
