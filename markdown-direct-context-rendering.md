# Direct Context Rendering for Markdown

<!--
---
version: 1.0.0
last_updated: 2026-03-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The markdown rendering pipeline converts markdown strings to rendered output through three phases:

1. **Parse**: `SwiftMarkdown.Document(parsing:)` → markdown AST
2. **Visit**: `Markdown.Converter` (`MarkupVisitor`) walks the AST, producing `HTML.AnyView` at every node
3. **Render**: `HTML.AnyView._render(view, context: &context)` dispatches to concrete views which write to the context

Phase 2 forces type erasure at every AST node because `MarkupVisitor` requires a single `Result` type across all visit methods. The current choice is `Result = HTML.AnyView`. This causes:

- **Stack overflow** in PDF rendering — the `_render` call chain recurses through existentials, exhausting the ~64KB async task stack even for simple documents (documented in `swift-pdf/Research/sigbus-stack-overflow-handoff.md`)
- **Loss of semantic identity** — a markdown heading becomes a generic `AnyView` wrapping a `div` wrapping an `h1`, losing its "heading" nature at the rendering context level
- **Existential dispatch overhead** at every render node — `AnyView._openAndRender` opens the existential and dynamically dispatches for every element
- **View tree depth multiplication** — each markdown AST level produces 3–5 view tree levels (Tag + Styled + AnyView + Array + AnyView), amplifying a bounded AST depth (~8–10) into an unbounded view tree depth (~24+)

The `Rendering.Context` protocol already has semantic push/pop methods (`_pushBlock(role: .heading(level:))`, `_pushList(kind: .ordered)`, `text()`, `lineBreak()`, etc.) that can express all markdown structure directly. The view tree is an intermediate representation that adds no semantic value — it's created only to be immediately consumed.

### Related research

- `swift-pdf/Research/sigbus-stack-overflow-handoff.md` — stack overflow analysis, 5 hypotheses
- `swift-institute/Research/markdown-rendering-organization-audit.md` — F-6 identifies AnyView as architectural
- `swift-institute/Research/rendering-view-associated-type-naming.md` — RenderBody rename enabling SwiftUI previews
- Project memory: "Iterative Tuple Rendering — Stack Overflow Fix (IN PROGRESS)"

---

## Question

How should markdown rendering bypass the `HTML.AnyView` view tree and write directly to a `Rendering.Context`, while preserving format independence, configurability, semantic preservation, table of contents extraction, CSS styling, diagnostic rendering, and composability with `HTML.Document`?

---

## Analysis

### Approach A: Void-Returning Visitor with Context Parameter

Make the converter generic over `C: Rendering.Context`, set `Result = Void`, and write directly to the context in each visit method.

```swift
extension Markdown {
    struct DirectConverter<C: Rendering.Context>: SwiftMarkdown.MarkupVisitor {
        typealias Result = Void
        var context: UnsafeMutablePointer<C>
        let configuration: Markdown.Configuration

        mutating func visitHeading(_ heading: SwiftMarkdown.Heading) {
            context.pointee.push.block(role: .heading(level: heading.level), style: .empty)
            for child in heading.children { visit(child) }
            context.pointee.pop.block()
        }

        mutating func visitText(_ text: SwiftMarkdown.Text) {
            context.pointee.text(text.string)
        }
    }
}
```

**Strengths**:
- Zero type erasure. No `HTML.AnyView` anywhere.
- O(AST depth) stack — markdown AST is bounded (~8–10 levels), so stack depth is bounded regardless of document size.
- Static dispatch — `C` is a concrete generic parameter, enabling full specialization.
- `UnsafeMutablePointer<C>` is safe within `withUnsafeMutablePointer` scope in `_render`.

**Weaknesses**:
- Loses configurability — the rendering logic is hardcoded in the converter, not in the `Configuration.Elements` renderers.
- Default CSS styling must be expressed as raw context calls (`context.register(style:...)`, `context.add(class:)`) instead of the composable `.css` accessor pattern.
- Cannot standalone — must combine with Approach C to integrate with `HTML.View`.

---

### Approach B: Rendering Thunks (Closures Capturing Context Operations)

Return deferred rendering closures instead of views:

```swift
extension Markdown {
    struct ThunkConverter<C: Rendering.Context>: SwiftMarkdown.MarkupVisitor {
        typealias Result = (inout C) -> Void

        mutating func visitHeading(_ heading: Heading) -> (inout C) -> Void {
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

**Strengths**:
- Zero AnyView. Deferred execution allows inspection/transformation before rendering.
- Composable — thunks can be passed as children to other thunks.

**Weaknesses**:
- Closures heap-allocate. Each node produces a closure capturing its child thunks.
- Stack depth during execution tracks AST depth (thunks calling thunks), same as Approach A.
- `MarkupVisitor.Result` would be `(inout C) -> Void` which is concrete for a given `C` but requires the conforming type to be generic over `C`. This works but means the Result type varies per specialization.
- The closure type `(inout C) -> Void` cannot be `@Sendable` (captures mutable state), complicating Sendable configuration.
- Strictly worse than Approach A: same stack behavior, plus closure overhead, plus lost Sendable safety.

---

### Approach C: Markdown as Leaf View with RenderBody == Never

Make `Markdown` a leaf view that overrides `_render` directly, bypassing `body`:

```swift
public struct Markdown: HTML.View {
    let markdownString: String
    let configuration: Configuration
    let previewOnly: Bool

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        // Direct rendering — no intermediate view tree
        let document = SwiftMarkdown.Document(
            parsing: view.markdownString,
            options: .parseBlockDirectives
        )
        withUnsafeMutablePointer(to: &context) { ptr in
            var converter = DirectConverter(context: ptr, configuration: view.configuration)
            converter.visit(document)
        }
    }
}
```

**Strengths**:
- Cleanest integration with `Rendering.View`. `Markdown` conforms to `HTML.View` and composes inside `HTML.Document`, `PDF.Document`, etc.
- `_render<C>` is the single entry point — the generic `C` parameter is available for the converter.
- No intermediate view tree between `Markdown` and the context.

**Weaknesses**:
- `body` returns `Never`, so `Markdown` can't be structurally inspected (no view tree to walk).
- Must combine with Approach A or B for the converter implementation.
- The `previewOnly` gradient mask and outer `ContentDivision` wrapper need to be expressed as direct context calls within `_render`.

---

### Approach D: Configurable Renderers as Context Writers

Element renderers write directly to the context instead of returning views:

```swift
extension Markdown.Configuration {
    struct Renderer<Input: Sendable>: Sendable {
        let render: @Sendable (Input, inout some Rendering.Context) -> Void  // ← impossible
    }
}
```

`inout some Rendering.Context` is not expressible in a stored closure in Swift 6.2. The `some` keyword in parameter position of a stored closure is not supported.

**Variant D1: Manual protocol witness table**

```swift
struct ContextWriter: ~Copyable {
    private let _text: (borrowing String) -> Void
    private let _pushBlock: (Rendering.Semantic.Block?, Rendering.Style) -> Void
    private let _popBlock: () -> Void
    // ... all Rendering.Context methods as closures
}
```

**Strengths**:
- Fully configurable. No generic parameter leakage.

**Weaknesses**:
- Manual witness table — 26+ stored closures replicating the `Rendering.Context` protocol surface.
- Loses static dispatch — every context call goes through a closure indirection.
- Massive maintenance burden — any change to `Rendering.Context` requires updating `ContextWriter`.
- ~Copyable complicates storage in the Sendable `Configuration`.

**Variant D2: Type-erased `any Rendering.Context` existential**

```swift
struct Renderer<Input: Sendable>: Sendable {
    let render: @Sendable (Input, inout any Rendering.Context) -> Void
}
```

**Weaknesses**:
- `any Rendering.Context` loses static dispatch entirely.
- `inout any Rendering.Context` requires opening the existential at every call site.
- `Rendering.Context` is `~Copyable`, making existential usage fragile.

**Assessment**: Both variants sacrifice the static dispatch that makes the `Rendering.Context` architecture valuable. Rejected.

---

### Approach E: Two-Phase Rendering (Semantic IR)

Introduce a semantic intermediate representation between the markdown AST and rendering:

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
        case blockquote(kind: String, children: [Node], diagnosticLevel: Diagnostic.Level?)
        case thematicBreak
        case lineBreak
        case softBreak
        case raw([UInt8])
        case table(head: [Node], body: [[Node]], alignments: [String?])
    }
}
```

Phase 1: `MarkupVisitor` → `Markdown.Node` (pure data, no rendering)
Phase 2: `Markdown.Node` → `Rendering.Context` events (configurable, format-independent)

**Strengths**:
- Clean separation of concerns. Phase 1 is pure data transformation (testable independently).
- Phase 2 can be customized per-node type without requiring view trees.
- The Node tree is `Sendable` — can be cached, shared, or pre-computed.
- Table of contents extraction happens naturally during Phase 1.

**Weaknesses**:
- **Duplicates the markdown AST** in a different shape. SwiftMarkdown already provides a rich AST — the Node enum is a less capable copy.
- Extra allocation — every document produces a complete Node tree before rendering.
- The Node enum must mirror all markdown elements, creating a parallel type hierarchy that must be maintained alongside SwiftMarkdown's types.
- Customization in Phase 2 still faces the same generic `C` parameter problem as Approach D.
- The intermediate representation has no independent value — it's consumed immediately by Phase 2.

---

### Approach F: Hybrid — Direct Rendering with View-Tree Escape Hatch

Default element renderers write directly to the context. Custom renderers return `HTML.AnyView` which gets rendered through the normal path. The converter checks per-element:

```swift
mutating func visitHeading(_ heading: SwiftMarkdown.Heading) {
    if let customRender = configuration.elements.heading.customRender {
        // Custom path: materialize children as AnyView, delegate to custom renderer
        var materializer = Materializer(configuration: configuration, ...)
        let childrenHTML = HTML.AnyView {
            for child in heading.children { materializer.visit(child) }
        }
        let view = customRender(.init(level: heading.level, slug: slug, children: childrenHTML))
        HTML.AnyView._render(view, context: &context.pointee)
    } else {
        // Default path: direct context calls (zero AnyView)
        context.pointee.push.block(role: .heading(level: heading.level), style: .empty)
        renderDefaultHeadingHTML(heading, slug: slug)
        for child in heading.children { visit(child) }
        context.pointee.pop.block()
    }
}
```

**Strengths**:
- Default path is zero-erasure, O(AST depth) stack, static dispatch — solves the stack overflow.
- Custom renderers keep working with full `@HTML.Builder` syntax and `HTML.AnyView`.
- Per-element granularity — only customized elements pay the AnyView cost.
- Backward compatible — existing custom renderers continue to work unchanged.
- CSS styling on the default path uses context methods (`register(style:...)`, `add(class:)`, `set(attribute:)`) which both HTML and PDF contexts handle.

**Weaknesses**:
- The default rendering logic moves from `Configuration.Elements.*.default` into the converter, meaning it's no longer a composable value.
- Two converters needed: `DirectConverter<C>` for the default path and `Materializer` (current `Converter`) for materializing children of custom elements.
- The `Materializer` is essentially the current code, kept for backward compatibility.
- Each visit method has a conditional branch (custom vs default), though this is a single `if let` check.

---

## Comparison

| Criterion | A: Void | B: Thunks | C: Leaf | D: Writers | E: IR | F: Hybrid |
|-----------|---------|-----------|---------|------------|-------|-----------|
| 1. Zero type erasure | **Yes** | Yes | N/A¹ | Yes | Yes | **Default: Yes, Custom: No** |
| 2. O(1) stack depth | **O(AST)²** | O(AST) | N/A¹ | O(AST) | O(AST) | **O(AST) default, O(AST+view) custom** |
| 3. Static dispatch | **Yes** | Yes | N/A¹ | **No** | Partial³ | **Yes default, No custom** |
| 4. Configurability | **No** | No | N/A¹ | Yes | Yes | **Yes** |
| 5. Composability | No⁴ | No⁴ | **Yes** | N/A | N/A | **Yes** (via C) |
| 6. Semantic preservation | **Yes** | Yes | N/A¹ | Yes | Yes | **Yes** |
| 7. Table of contents | **Yes** | Yes | N/A¹ | Yes | Yes | **Yes** |
| 8. CSS support | **Verbose⁵** | Verbose | N/A¹ | Verbose | Verbose | **Verbose default, Full custom** |
| 9. Sendable | **Yes** | No⁶ | Yes | Yes | Yes | **Yes** |
| 10. Complexity | Low | Medium | Low | Very High | Medium | **Medium** |
| 11. Migration path | Breaking | Breaking | Compatible | Breaking | Breaking | **Compatible** |

¹ Approach C is a structural pattern for `Markdown`, not a converter design. It combines with A, B, or F.
² O(AST depth) ≈ O(1) for practical purposes: markdown AST depth is bounded by structure (~8–10 levels), not document size.
³ Phase 2 customization requires type erasure for the generic context parameter.
⁴ Approaches A and B provide converter implementations but not `HTML.View` conformance. Must combine with C.
⁵ CSS properties expressed as raw `context.register(style:...)` calls instead of `.css` accessors.
⁶ Thunk closures capture mutable converter state.

---

## Recommendation

**Approach C + A + F: Hybrid Leaf View with Direct Default Rendering**

The recommended architecture combines three approaches:
- **C** (Leaf View): `Markdown` becomes a leaf view (`RenderBody = Never`) with a custom `_render<C>`.
- **A** (Void Visitor): The converter sets `Result = Void` and writes directly to the context.
- **F** (Hybrid): Per-element check — default renderers use direct context calls; custom renderers materialize children as `HTML.AnyView` and delegate.

### Rationale

1. **The stack overflow is the motivating problem.** The current architecture overflows the 64KB async task stack even for simple markdown documents. The root cause is view tree depth multiplication: each AST level produces 3–5 view tree levels through AnyView + Tag + Styled wrappers. The fix must bound stack depth to AST depth, not view tree depth.

2. **The default path is the common case.** Most users never customize markdown element renderers. The default `Configuration.Elements` is used in the vast majority of deployments. Optimizing the default path to zero-erasure addresses 99% of real-world usage.

3. **Custom renderers are rare and per-element.** When a user customizes a heading renderer, only headings pay the AnyView cost. The rest of the document (paragraphs, lists, code blocks, etc.) uses direct context calls. Stack depth impact is bounded by a single element and its children, not the full document.

4. **Backward compatibility.** The `@HTML.Builder` syntax for custom renderers is preserved. Existing custom renderers continue to work without modification. The only API change is that `Configuration.Elements.*.render` becomes Optional (nil = use built-in default).

5. **`Rendering.Context` already has the semantic vocabulary.** The push/pop methods for blocks (heading, paragraph, blockquote, pre, table, row, cell), inlines (emphasis, strong, code), lists (ordered, unordered), items, and links — plus leaf methods for text, line breaks, thematic breaks, and images — can express all standard markdown structure without view trees.

---

## Detailed Design

### 1. `Markdown` struct: Leaf view

```swift
public struct Markdown: HTML.View {
    let markdownString: String
    let configuration: Configuration
    let previewOnly: Bool

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        let document = SwiftMarkdown.Document(
            parsing: view.markdownString,
            options: .parseBlockDirectives
        )

        // Outer wrapper: ContentDivision with display:block
        C._pushBlock(&context, role: nil, style: .empty)
        context.add(class: "markdown")
        _ = context.register(
            style: "display: block",
            atRule: nil, selector: nil, pseudo: nil
        )

        // Inner wrapper: VStack with spacing
        C._pushBlock(&context, role: nil, style: .empty)
        _ = context.register(
            style: "display: flex; flex-direction: column; row-gap: 0.5rem",
            atRule: nil, selector: nil, pseudo: nil
        )

        if view.previewOnly {
            _ = context.register(
                style: "mask-image: linear-gradient(to bottom, black 50%, transparent 100%)",
                atRule: nil, selector: nil, pseudo: nil
            )
        }

        // Render markdown content
        withUnsafeMutablePointer(to: &context) { ptr in
            var converter = DirectConverter(
                context: ptr,
                configuration: view.configuration,
                previewOnly: view.previewOnly
            )
            converter.visit(document)
        }

        C._popBlock(&context)  // VStack
        C._popBlock(&context)  // ContentDivision
    }
}
```

**Key invariant**: `Markdown` still conforms to `HTML.View` (and therefore `Rendering.View`). It composes inside `HTML.Document`, `PDF.Document`, and arbitrary view trees via `_render<C>`. The generic `C` parameter enables format-independent rendering.

### 2. `Markdown.DirectConverter<C>`: The primary converter

```swift
extension Markdown {
    struct DirectConverter<C: Rendering.Context>: SwiftMarkdown.MarkupVisitor {
        typealias Result = Void

        let context: UnsafeMutablePointer<C>
        let configuration: Markdown.Configuration
        let previewOnly: Bool

        private var currentTimestamp: Timestamp?
        private var currentSection: (title: String, id: String, level: Int)?
        private var existingSlugs: Swift.Set<String> = []
        var tableOfContents: [Markdown.Section] = []

        // --- Slug generation (unchanged) ---

        private mutating func generateSlug(for text: String) -> String {
            let slug = configuration.slugGenerator.generate(
                .init(text: text, existingSlugs: existingSlugs)
            )
            existingSlugs.insert(slug)
            return slug
        }

        // --- Visit methods ---

        mutating func defaultVisit(_ markup: any SwiftMarkdown.Markup) {
            for child in markup.children {
                if previewOnly && tableOfContents.count > 1 { break }
                visit(child)
            }
        }

        mutating func visitText(_ text: SwiftMarkdown.Text) {
            context.pointee.text(text.string)
        }

        mutating func visitLineBreak(_ lineBreak: SwiftMarkdown.LineBreak) {
            if let customRender = configuration.elements.lineBreak.customRender {
                let view = customRender()
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                context.pointee.lineBreak()
            }
        }

        mutating func visitSoftBreak(_ softBreak: SwiftMarkdown.SoftBreak) {
            if let customRender = configuration.elements.softBreak.customRender {
                let view = customRender()
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                context.pointee.text(" ")
            }
        }

        mutating func visitThematicBreak(_ thematicBreak: SwiftMarkdown.ThematicBreak) {
            if let customRender = configuration.elements.thematicBreak.customRender {
                let view = customRender()
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                context.pointee.thematicBreak()
            }
        }

        mutating func visitHeading(_ heading: SwiftMarkdown.Heading) {
            let slug = generateSlug(for: heading.plainText)
            currentSection = (title: heading.plainText, id: slug, level: heading.level)

            if let customRender = configuration.elements.heading.customRender {
                let childrenHTML = materializeChildren(heading.children)
                let view = customRender(.init(
                    level: heading.level,
                    slug: slug,
                    plainText: heading.plainText,
                    children: childrenHTML
                ))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                renderDefaultHeading(heading, slug: slug)
            }
        }

        mutating func visitParagraph(_ paragraph: SwiftMarkdown.Paragraph) {
            if let customRender = configuration.elements.paragraph.customRender {
                let childrenHTML = materializeChildren(paragraph.children)
                let view = customRender(.init(children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushBlock(&context.pointee, role: .paragraph, style: .empty)
                C._pushElement(
                    &context.pointee,
                    tagName: "p", isBlock: true, isVoid: false, isPreElement: false
                )
                _ = context.pointee.register(
                    style: "line-height: 1.5; padding: 0; margin: 0",
                    atRule: nil, selector: nil, pseudo: nil
                )
                for child in paragraph.children { visit(child) }
                C._popElement(&context.pointee, isBlock: true)
                C._popBlock(&context.pointee)
            }
        }

        mutating func visitEmphasis(_ emphasis: SwiftMarkdown.Emphasis) {
            if let customRender = configuration.elements.emphasis.customRender {
                let childrenHTML = materializeChildren(emphasis.children)
                let view = customRender(.init(children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushInline(&context.pointee, role: .emphasis, style: .empty)
                C._pushElement(
                    &context.pointee,
                    tagName: "em", isBlock: false, isVoid: false, isPreElement: false
                )
                for child in emphasis.children { visit(child) }
                C._popElement(&context.pointee, isBlock: false)
                C._popInline(&context.pointee)
            }
        }

        mutating func visitStrong(_ strong: SwiftMarkdown.Strong) {
            if let customRender = configuration.elements.strong.customRender {
                let childrenHTML = materializeChildren(strong.children)
                let view = customRender(.init(children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushInline(&context.pointee, role: .strong, style: .empty)
                C._pushElement(
                    &context.pointee,
                    tagName: "strong", isBlock: false, isVoid: false, isPreElement: false
                )
                for child in strong.children { visit(child) }
                C._popElement(&context.pointee, isBlock: false)
                C._popInline(&context.pointee)
            }
        }

        mutating func visitInlineCode(_ inlineCode: SwiftMarkdown.InlineCode) {
            if let customRender = configuration.elements.inlineCode.customRender {
                let view = customRender(.init(code: inlineCode.code))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushInline(&context.pointee, role: .code, style: .empty)
                C._pushElement(
                    &context.pointee,
                    tagName: "code", isBlock: false, isVoid: false, isPreElement: false
                )
                context.pointee.text(inlineCode.code)
                C._popElement(&context.pointee, isBlock: false)
                C._popInline(&context.pointee)
            }
        }

        mutating func visitCodeBlock(_ codeBlock: SwiftMarkdown.CodeBlock) {
            let languageInfo: (language: String?, highlightLines: String?)
            if let lang = codeBlock.language {
                let parts = lang.split(separator: ":", maxSplits: 2)
                languageInfo = (
                    language: parts.first.map(String.init),
                    highlightLines: parts.dropFirst().first.map(String.init)
                )
            } else {
                languageInfo = (nil, nil)
            }

            if let customRender = configuration.elements.codeBlock.customRender {
                let view = customRender(.init(
                    language: languageInfo.language,
                    code: codeBlock.code,
                    highlightLines: languageInfo.highlightLines
                ))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushBlock(&context.pointee, role: .pre, style: .empty)
                C._pushElement(
                    &context.pointee,
                    tagName: "pre", isBlock: true, isVoid: false, isPreElement: true
                )
                context.pointee.set(attribute: "data-line", languageInfo.highlightLines)
                // CSS: color, margin, padding, overflow, border-radius
                _ = context.pointee.register(
                    style: "margin: 0; margin-bottom: 0.5rem; overflow-x: auto; padding: 1rem 1.5rem; border-radius: 6px",
                    atRule: nil, selector: nil, pseudo: nil
                )
                C._pushElement(
                    &context.pointee,
                    tagName: "code", isBlock: false, isVoid: false, isPreElement: false
                )
                if let lang = languageInfo.language {
                    context.pointee.set(attribute: "class", "language-\(lang)")
                }
                context.pointee.text(codeBlock.code)
                C._popElement(&context.pointee, isBlock: false)
                C._popElement(&context.pointee, isBlock: true)
                C._popBlock(&context.pointee)
            }
        }

        mutating func visitLink(_ link: SwiftMarkdown.Link) {
            if let customRender = configuration.elements.link.customRender {
                let childrenHTML = materializeChildren(link.children)
                let view = customRender(.init(
                    destination: link.destination,
                    title: link.title,
                    children: childrenHTML
                ))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushLink(&context.pointee, destination: link.destination ?? "#")
                C._pushElement(
                    &context.pointee,
                    tagName: "a", isBlock: false, isVoid: false, isPreElement: false
                )
                context.pointee.set(attribute: "href", link.destination)
                if let title = link.title {
                    context.pointee.set(attribute: "title", title)
                }
                for child in link.children { visit(child) }
                C._popElement(&context.pointee, isBlock: false)
                C._popLink(&context.pointee)
            }
        }

        mutating func visitImage(_ image: SwiftMarkdown.Image) {
            if let customRender = configuration.elements.image.customRender {
                let view = customRender(.init(
                    source: image.source,
                    alt: image.plainText,
                    title: image.title
                ))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                context.pointee.image(source: image.source ?? "", alt: image.plainText)
            }
        }

        mutating func visitOrderedList(_ orderedList: SwiftMarkdown.OrderedList) {
            if let customRender = configuration.elements.orderedList.customRender {
                let childrenHTML = materializeChildren(orderedList.children)
                let view = customRender(.init(isOrdered: true, children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushList(&context.pointee, kind: .ordered, start: nil)
                C._pushElement(
                    &context.pointee,
                    tagName: "ol", isBlock: true, isVoid: false, isPreElement: false
                )
                _ = context.pointee.register(
                    style: "display: flex; flex-direction: column; row-gap: 0.5rem",
                    atRule: nil, selector: nil, pseudo: nil
                )
                for child in orderedList.children { visit(child) }
                C._popElement(&context.pointee, isBlock: true)
                C._popList(&context.pointee)
            }
        }

        mutating func visitUnorderedList(_ unorderedList: SwiftMarkdown.UnorderedList) {
            if let customRender = configuration.elements.unorderedList.customRender {
                let childrenHTML = materializeChildren(unorderedList.children)
                let view = customRender(.init(isOrdered: false, children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushList(&context.pointee, kind: .unordered, start: nil)
                C._pushElement(
                    &context.pointee,
                    tagName: "ul", isBlock: true, isVoid: false, isPreElement: false
                )
                _ = context.pointee.register(
                    style: "display: flex; flex-direction: column; row-gap: 0.5rem; margin-top: 0; margin-bottom: 0",
                    atRule: nil, selector: nil, pseudo: nil
                )
                for child in unorderedList.children { visit(child) }
                C._popElement(&context.pointee, isBlock: true)
                C._popList(&context.pointee)
            }
        }

        mutating func visitListItem(_ listItem: SwiftMarkdown.ListItem) {
            if let customRender = configuration.elements.listItem.customRender {
                let childrenHTML = materializeChildren(listItem.children)
                let view = customRender(.init(children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushItem(&context.pointee)
                C._pushElement(
                    &context.pointee,
                    tagName: "li", isBlock: true, isVoid: false, isPreElement: false
                )
                for child in listItem.children { visit(child) }
                C._popElement(&context.pointee, isBlock: true)
                C._popItem(&context.pointee)
            }
        }

        mutating func visitBlockQuote(_ blockQuote: SwiftMarkdown.BlockQuote) {
            let aside = SwiftMarkdown.Aside(blockQuote)
            let kind = aside.kind.displayName
            let diagnosticLevel = configuration.style.diagnostic.level(aside.kind.rawValue)

            if let customRender = configuration.elements.blockQuote.customRender {
                let childrenHTML = materializeChildren(aside.content)
                let view = customRender(.init(
                    kind: kind,
                    children: childrenHTML,
                    isDiagnostic: diagnosticLevel != nil,
                    diagnosticLevel: diagnosticLevel
                ))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                renderDefaultBlockQuote(aside: aside, kind: kind, diagnosticLevel: diagnosticLevel)
            }
        }

        mutating func visitTable(_ table: SwiftMarkdown.Table) {
            if let customRender = configuration.elements.table.customRender {
                let headHTML = materializeTableHead(table)
                let bodyHTML = materializeTableBody(table)
                let view = customRender(.init(
                    head: headHTML,
                    body: bodyHTML,
                    hasHead: !table.head.isEmpty,
                    hasBody: !table.body.isEmpty
                ))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                renderDefaultTable(table)
            }
        }

        mutating func visitHTMLBlock(_ html: SwiftMarkdown.HTMLBlock) {
            context.pointee.write(raw: Array(html.rawHTML.utf8))
        }

        mutating func visitInlineHTML(_ inlineHTML: SwiftMarkdown.InlineHTML) {
            context.pointee.write(raw: Array(inlineHTML.rawHTML.utf8))
        }

        mutating func visitStrikethrough(_ strikethrough: SwiftMarkdown.Strikethrough) {
            if let customRender = configuration.elements.strikethrough.customRender {
                let childrenHTML = materializeChildren(strikethrough.children)
                let view = customRender(.init(children: childrenHTML))
                HTML.AnyView._render(view, context: &context.pointee)
            } else {
                C._pushElement(
                    &context.pointee,
                    tagName: "del", isBlock: false, isVoid: false, isPreElement: false
                )
                for child in strikethrough.children { visit(child) }
                C._popElement(&context.pointee, isBlock: false)
            }
        }

        // --- Block directives ---

        mutating func visitBlockDirective(_ blockDirective: SwiftMarkdown.BlockDirective) {
            // Timestamp directives
            if blockDirective.name == "T" {
                // ... timestamp handling (same as current) ...
                return
            }

            // General directives: materialize children and delegate to handler
            let childrenHTML = materializeChildren(blockDirective.children)
            let directive = Markdown.Configuration.Directives.Directive(
                name: blockDirective.name,
                rawArguments: blockDirective.argumentText.segments
                    .map(\.trimmedText).joined(separator: " "),
                arguments: parseArguments(from: blockDirective),
                children: childrenHTML
            )
            let result = configuration.directives.handler(directive)
            switch result {
            case .rendered(let view):
                HTML.AnyView._render(view, context: &context.pointee)
            case .suppress:
                break  // no output
            case .useDefault:
                HTML.AnyView._render(childrenHTML, context: &context.pointee)
            }
        }

        // --- Materialization (for custom renderers) ---

        private mutating func materializeChildren(
            _ children: some Sequence<any SwiftMarkdown.Markup>
        ) -> HTML.AnyView {
            var materializer = Markdown.Converter(
                configuration: configuration,
                previewOnly: false
            )
            let view = HTML.AnyView {
                for child in children {
                    materializer.visit(child)
                }
            }
            // Propagate table-of-contents from materializer
            self.tableOfContents.append(contentsOf: materializer.tableOfContents)
            return view
        }

        // ... default rendering helpers (renderDefaultHeading, etc.)
    }
}
```

### 3. Element renderer API change

The `Configuration.Elements.*.render` closure becomes Optional. When nil, the `DirectConverter` uses built-in default rendering logic. When set, the `DirectConverter` falls back to the materializer path.

```swift
extension Markdown.Configuration.Elements {
    public struct Heading: Sendable {
        /// Custom renderer. When nil, uses built-in default rendering.
        public var customRender: (@Sendable (Input) -> HTML.AnyView)?

        /// Creates a heading renderer using the built-in default.
        public init() {
            self.customRender = nil
        }

        /// Creates a heading renderer with custom view-based rendering.
        public init<View: HTML.View>(
            @HTML.Builder _ render: @escaping @Sendable (Input) -> View
        ) {
            nonisolated(unsafe) let unsafeRender = render
            self.customRender = { input in
                HTML.AnyView(unsafeRender(input))
            }
        }
    }
}

extension Markdown.Configuration.Elements.Heading {
    public static var `default`: Self { .init() }
}
```

The `Input` types remain unchanged. The `children: HTML.AnyView` property on Input types is only populated when a custom renderer is used (via materialization). For the default path, children are rendered directly through the context.

### 4. `Markdown.Converter` (current code, retained as Materializer)

The existing `Markdown.Converter` is retained without modification. It serves as the materializer for children of custom-rendered elements and for block directives. Its `Result = HTML.AnyView` type is still needed for materializing children into the `Input.children` field.

The converter is renamed from `HTMLConverter` to `Markdown.Converter` per the organization audit (F-3), and remains `internal`.

### 5. `tableOfContents` extraction

```swift
extension Markdown {
    public static func tableOfContents(
        from markdown: String,
        configuration: Configuration = .default
    ) -> [Section] {
        // Use a dummy context that discards all output
        var context = Rendering.NullContext()
        withUnsafeMutablePointer(to: &context) { ptr in
            var converter = DirectConverter(
                context: ptr,
                configuration: configuration,
                previewOnly: false
            )
            converter.visit(
                SwiftMarkdown.Document(parsing: markdown, options: .parseBlockDirectives)
            )
            return converter.tableOfContents
        }
    }
}
```

**Alternative**: Since the `DirectConverter` accumulates headings as a side effect during traversal, and `_render` uses the `DirectConverter`, we can also extract table of contents by running the converter with a null context. This requires a `Rendering.NullContext` type — a minimal `Rendering.Context` conformance that discards all output.

**Simpler alternative**: Keep using the existing `Markdown.Converter` for `tableOfContents(from:)` since it doesn't need to render anything — it just visits and accumulates headings. This avoids needing a null context.

```swift
extension Markdown {
    public static func tableOfContents(
        from markdown: String,
        configuration: Configuration = .default
    ) -> [Section] {
        // Use the materializer (existing converter) — its AnyView output is discarded
        var converter = Converter(configuration: configuration, previewOnly: false)
        _ = converter.visit(
            SwiftMarkdown.Document(parsing: markdown, options: .parseBlockDirectives)
        )
        return converter.tableOfContents
    }
}
```

### 6. Diagnostic blockquote rendering

The default blockquote renderer checks for diagnostic asides and renders them with the `Markdown.Diagnostic` view. In the direct rendering path:

```swift
private mutating func renderDefaultBlockQuote(
    aside: SwiftMarkdown.Aside,
    kind: String,
    diagnosticLevel: Markdown.Diagnostic.Level?
) {
    if let level = diagnosticLevel {
        // Diagnostic: render as custom diagnostic block
        // The diagnostic rendering has rich CSS that justifies using
        // the view-based path even in the default converter
        let childrenHTML = materializeChildren(aside.content)
        let diagnosticView = Markdown.Diagnostic(level: level) {
            childrenHTML
        }
        // Push block for the diagnostic wrapper
        C._pushBlock(&context.pointee, role: .blockquote, style: .empty)
        type(of: diagnosticView).callAsFunction._render(/* ... */)
        C._popBlock(&context.pointee)
    } else {
        // Standard blockquote: direct context rendering
        C._pushBlock(&context.pointee, role: .blockquote, style: .empty)
        C._pushElement(
            &context.pointee,
            tagName: "blockquote", isBlock: true, isVoid: false, isPreElement: false
        )
        // Apply blockquote styling
        let style = SwiftMarkdown.BlockQuote.Style(blockName: kind)
        // ... register CSS for border, background, padding ...
        for child in aside.content { visit(child) }
        C._popElement(&context.pointee, isBlock: true)
        C._popBlock(&context.pointee)
    }
}
```

**Design choice**: Diagnostic blockquotes have complex CSS (flexbox layout with icon panel and message panel, drop shadows, border radius). There are two options:

1. **Inline the diagnostic CSS as direct context calls** — verbose (~20 register/set calls) but zero erasure.
2. **Use view-based rendering for diagnostics** — keep `Markdown.Diagnostic` as a view, materialize the children, and render through AnyView. Simpler, but adds one AnyView level for diagnostics only.

**Recommendation**: Option 2. Diagnostics are structurally complex (HStack with two divs, icon with filters, nested VStack) and have extensive responsive CSS. Expressing this as raw context calls would be fragile and hard to maintain. The view-based path adds minimal stack depth (one AnyView + a few Tag/Styled levels), and diagnostics are rare in most documents. The stack overflow risk is negligible for a single diagnostic element.

### 7. CSS styling in the default path

The default element renderers currently use the `.css` accessor pattern:

```swift
// Current (view-based)
HTML_Rendering.Paragraph { input.children }
    .css.lineHeight(1.5).padding(.zero).margin(.zero)
```

In the direct path, CSS is applied via context methods:

```swift
// New (direct context)
C._pushElement(&context.pointee, tagName: "p", isBlock: true, isVoid: false, isPreElement: false)
_ = context.pointee.register(
    style: "line-height: 1.5; padding: 0; margin: 0",
    atRule: nil, selector: nil, pseudo: nil
)
```

**For HTML contexts**: `register(style:...)` generates a CSS class and applies it. The output is equivalent.

**For PDF contexts**: `register(style:...)` returns nil (the PDF context does not process raw CSS strings). Instead, the PDF context handles styling through semantic roles. A `_pushBlock(role: .paragraph)` is sufficient for the PDF layout engine to apply paragraph-appropriate styling. The CSS properties (line-height, padding, margin) are HTML-specific and correctly ignored by PDF.

This is actually **more correct** than the current approach: the view-based path applies CSS properties that the PDF context then has to parse and translate (or ignore). The direct path applies semantic roles that both contexts understand natively.

### 8. `previewOnly` gradient mask

Currently applied as:
```swift
.css.inlineStyle("mask-image", previewOnly ? "linear-gradient(...)" : nil)
```

In the direct path, applied in `Markdown._render` before the converter runs:
```swift
if view.previewOnly {
    _ = context.register(
        style: "mask-image: linear-gradient(to bottom, black 50%, transparent 100%)",
        atRule: nil, selector: nil, pseudo: nil
    )
}
```

The `register(style:...)` call applies the mask to the current element scope (the outer wrapper div). For PDF contexts, this is ignored — the `previewOnly` behavior for PDF would need to be handled differently (e.g., limiting the number of sections rendered, which `DirectConverter.defaultVisit` already does by checking `tableOfContents.count`).

### 9. Default heading rendering (example of complex default)

The current heading default produces:

```swift
Anchor {} .id(input.slug) .css.display(.block).position(.relative).top(Top.em(-5))...
ContentDivision {
    tag("h\(input.level)") { input.children; Anchor(href: "#\(slug)") { LinkIcon() } ... }
        .css.color(...)
}
.css.marginLeft(...).paddingLeft(...).position(.relative)
```

In the direct path:

```swift
private mutating func renderDefaultHeading(
    _ heading: SwiftMarkdown.Heading, slug: String
) {
    C._pushBlock(&context.pointee, role: .heading(level: heading.level), style: .empty)

    // Invisible anchor target
    C._pushElement(&context.pointee, tagName: "a", isBlock: false, isVoid: false, isPreElement: false)
    context.pointee.set(attribute: "id", slug)
    _ = context.pointee.register(
        style: "display: block; position: relative; top: -5em; visibility: hidden",
        atRule: nil, selector: nil, pseudo: nil
    )
    C._popElement(&context.pointee, isBlock: false)

    // Heading wrapper div
    C._pushElement(&context.pointee, tagName: "div", isBlock: true, isVoid: false, isPreElement: false)
    _ = context.pointee.register(
        style: "margin-left: -2.25rem; padding-left: 2.25rem; position: relative",
        atRule: nil, selector: nil, pseudo: nil
    )

    // Heading element
    C._pushElement(
        &context.pointee,
        tagName: "h\(heading.level)", isBlock: true, isVoid: false, isPreElement: false
    )

    // Children (inline content)
    for child in heading.children { visit(child) }

    // Link icon anchor (hover-reveal)
    C._pushElement(&context.pointee, tagName: "a", isBlock: false, isVoid: false, isPreElement: false)
    context.pointee.set(attribute: "href", "#\(slug)")
    _ = context.pointee.register(
        style: "display: none; position: absolute; left: 0; width: 2.5rem",
        atRule: nil, selector: nil, pseudo: nil
    )
    // LinkIcon SVG
    context.pointee.write(raw: Array(LinkIcon.svgBytes))
    C._popElement(&context.pointee, isBlock: false)

    C._popElement(&context.pointee, isBlock: true)   // h1/h2/etc
    C._popElement(&context.pointee, isBlock: true)   // div
    C._popBlock(&context.pointee)
}
```

**Observation**: The direct path is more verbose but structurally simpler. Each push/pop pair is one stack frame on the context implementation side, not on the rendering side. The total stack depth for a heading in the direct path: 1 frame (the `renderDefaultHeading` function call). Compare with the current path: 10+ frames (AnyView → ContentDivision → body → Styled → Tag → AnyView → Array → ...).

---

## Open Questions Resolved

### Q12: Can custom renderers mix view-tree and direct-context approaches?

**Yes.** The hybrid architecture allows per-element choice. Elements with default rendering use direct context calls. Elements with custom renderers use view-tree-based rendering. They coexist within the same document because both paths ultimately write to the same `Rendering.Context`.

### Q13: Should `Rendering.Semantic` gain markdown-specific roles?

**No, not yet.** The existing semantic roles (`heading(level:)`, `paragraph`, `blockquote`, `pre`, `table`, `row`, `cell(header:)`, `emphasis`, `strong`, `code`, `ordered`, `unordered`) cover all standard markdown structures. Strikethrough maps to an HTML `del` element (no semantic role needed — it's presentational). Images and line breaks are handled by dedicated context methods.

If a future PDF context needs language-specific code block handling, `Rendering.Semantic.Block` could gain `case codeBlock(language: String?)`. But this is speculative and should wait for a concrete need.

### Q14: How does `previewOnly` work without a view tree?

The gradient mask is applied as a CSS property on the outer wrapper div via `context.register(style:...)`. Content limiting is handled by the converter's `defaultVisit` method, which breaks the loop when `tableOfContents.count > 1` in preview mode. Both mechanisms work identically to the current approach.

### Q15: How do diagnostic blockquotes work?

Diagnostic blockquotes use the view-based path — the `Markdown.Diagnostic` view is instantiated and rendered through `_render`. This adds minimal stack depth (one element) and preserves the diagnostic's complex CSS layout. See Section 6 above.

### Q16: What is the Input type for configurable renderers?

**Unchanged.** `Input` types keep their `children: HTML.AnyView` properties. When a custom renderer is invoked, children are materialized into `HTML.AnyView` using the existing `Markdown.Converter` (retained as a materializer). The `Input` types are only populated on the custom path.

---

## Required Changes to Other Packages

### swift-rendering-primitives (Layer 1)

**No changes required.** The `Rendering.Context` protocol already has all necessary push/pop methods and leaf content methods. The semantic roles cover all markdown structures.

**Optional enhancement**: A `Rendering.NullContext` type (discards all output) would be useful for table-of-contents extraction without rendering. However, this is not required — the existing `Markdown.Converter` can still be used for table-of-contents-only extraction.

### swift-html-rendering (Layer 3)

**No changes required.** `HTML.AnyView`, `HTML.View`, `HTML.Context`, and the view rendering pipeline are preserved. Custom renderers continue to produce and render `HTML.AnyView`.

### swift-markdown-html-rendering (Layer 3)

**All changes concentrated here:**

1. `Markdown.swift` — change from `body`-based rendering to `RenderBody = Never` + `_render<C>`
2. New file: `Markdown.DirectConverter.swift` — the generic `DirectConverter<C>` type
3. Each `Markdown.Configuration.Element.*.swift` — `render` property becomes Optional (`customRender`), `.default` returns `nil`
4. `Markdown.Converter.swift` — retained as-is for materialization and `tableOfContents(from:)`
5. `LinkIcon.swift` — may need a static `svgBytes` property for inline SVG rendering

### swift-pdf-html-rendering (Layer 3)

**No changes required.** `PDF.HTML.Context` already handles all semantic push/pop events. The direct rendering path sends the same events that the view-based path produces after traversing the view tree.

---

## Migration Path

### Phase 1: Non-breaking preparation

1. Add `customRender` optional property to each element renderer alongside the existing `render` property.
2. Update `.default` statics to set `customRender = nil` and `render` to the existing default.
3. All existing code continues to work — `render` is still used by the current converter.

### Phase 2: Add DirectConverter

1. Add `Markdown.DirectConverter<C>` with all visit methods.
2. Add `_render<C>` override to `Markdown` (as leaf view).
3. In `_render`, check each element: if `customRender != nil`, use custom path; otherwise, use direct rendering.
4. The existing `Markdown.Converter` is retained for materialization and `tableOfContents(from:)`.

### Phase 3: API cleanup (next major version)

1. Remove the `render` stored property (replaced by `customRender`).
2. Remove the `body` property from `Markdown` (already returns `Never`).
3. Consider removing `Markdown.Converter` if all table-of-contents callers migrate to the direct path.

### Backward compatibility

- **Custom renderers**: Continue to work via `customRender` property. The `init<View: HTML.View>(@HTML.Builder ...)` initializer is preserved.
- **Default rendering**: Behavior is identical — the direct context calls produce the same semantic events as the view tree path.
- **`tableOfContents(from:)`**: Works via the retained materializer converter.
- **`Markdown.Diagnostic`**: Preserved as a view, rendered through AnyView on the diagnostic path only.

---

## Stack Depth Analysis

### Current architecture (view-based)

For a simple heading with text content:

```
Markdown.body → ContentDivision.body → Styled._render → Tag._render (div)
→ VStack.body → Styled._render → Tag._render (div)
→ AnyView._render → AnyView._openAndRender
→ Array._render → AnyView._render → AnyView._openAndRender
→ heading view body → ContentDivision.body → Styled._render → Tag._render (div)
→ heading element → Tag._render (h1)
→ AnyView._render (children) → Array._render → AnyView._render → Text._render
```

**Total: ~20 frames** per heading. Each frame is 200–500 bytes in debug builds. With multiple elements, the stack accumulates across the document. Even a 10-element document can approach the 64KB limit.

### Recommended architecture (direct context)

For the same heading:

```
Markdown._render → DirectConverter.visitHeading → renderDefaultHeading
    → C._pushBlock (semantic heading)
    → C._pushElement (anchor)
    → C._popElement
    → C._pushElement (div)
    → C._pushElement (h1)
    → DirectConverter.visitText → C.text(...)
    → C._popElement (h1)
    → C._popElement (div)
    → C._popBlock
```

**Total: 3 frames** (Markdown._render → visitHeading → renderDefaultHeading). The context push/pop calls are direct function calls that don't accumulate stack — they modify context state and return. The total stack depth for any document is bounded by: `_render` (1) + visitor dispatch (1) + default renderer (1) + child visitor recursion (bounded by AST depth, ~8–10 max) = **~12 frames worst case**.

**Improvement**: From ~20 frames per element (unbounded total) to ~12 frames total (bounded). This is well within the 64KB async task stack limit.

---

## References

- `swift-pdf/Research/sigbus-stack-overflow-handoff.md` — stack overflow root cause analysis
- `swift-institute/Research/markdown-rendering-organization-audit.md` — organizational findings F-1 through F-10
- `swift-institute/Research/rendering-view-associated-type-naming.md` — RenderBody rename (prerequisite)
- `swift-institute/Research/worklist-rendering-dispatch.md` — prior worklist fix (superseded)
- `swift-markdown-html-rendering/Sources/Markdown HTML Rendering/Markdown.Converter.swift` — current converter
- `swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Context.swift` — context protocol
- `swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Semantic.Block.swift` — semantic roles
- Apple `swift-markdown` `MarkupVisitor` protocol — `associatedtype Result` constraint
