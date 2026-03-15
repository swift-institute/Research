# Implementation: Rendering.Context Witness Migration — Phase 4 (Markdown Direct Rendering)

## Assignment

Redesign swift-markdown-html-rendering to eliminate `HTML.AnyView` type erasure from the markdown rendering pipeline. This is the motivating problem — markdown→PDF rendering overflows the ~64KB async task stack because the `Markdown.Converter` produces deeply nested `HTML.AnyView` trees.

Phase 4 replaces the `HTML.AnyView`-producing `Markdown.Converter` with a `Markdown.DirectConverter` that writes `[Rendering.Action]` directly, then interprets them against the concrete `Rendering.Context`. This flattens the rendering stack from O(view tree depth) to O(1).

**This is Phase 4 of 4.** Phases 1–3 are complete: `Rendering.Context` is a witness struct, `Rendering.Action` enum exists, HTML/PDF/PDF-HTML factories exist.

**Quality bar**: Timeless infrastructure. Follow all Swift Institute conventions.

---

## The Problem

The current `Markdown.Converter` (a `SwiftMarkdown.MarkupVisitor`) sets `Result = HTML.AnyView`. Every `visit*` method wraps children in `HTML.AnyView { for child in ... { visit(child) } }`, then passes them to a configuration element renderer that also returns `HTML.AnyView`. This produces a deeply nested view tree that, when rendered via `_render`, creates 20+ recursive stack frames per element — overflowing the async task stack even for simple documents.

The `Rendering.Action` enum + `interpret` method from Phase 1 provides the solution: produce actions as flat data, interpret them in a loop. O(1) stack depth.

---

## Architecture

### The Markdown.Rendering witness

A `@Witness`-style struct (hand-written, no macro) where each element renderer is a closure that appends `[Rendering.Action]` to a buffer. This replaces `Markdown.Configuration.Elements` (which stores `@Sendable (Input) -> HTML.AnyView` closures).

```swift
extension Markdown {
    public struct Rendering: Sendable {
        public var heading: @Sendable (Heading.Input, inout [Rendering.Action]) -> Void
        public var paragraph: @Sendable (Paragraph.Input, inout [Rendering.Action]) -> Void
        public var codeBlock: @Sendable (CodeBlock.Input, inout [Rendering.Action]) -> Void
        public var blockQuote: @Sendable (BlockQuote.Input, inout [Rendering.Action]) -> Void
        public var emphasis: @Sendable (Emphasis.Input, inout [Rendering.Action]) -> Void
        public var strong: @Sendable (Strong.Input, inout [Rendering.Action]) -> Void
        public var strikethrough: @Sendable (Strikethrough.Input, inout [Rendering.Action]) -> Void
        public var inlineCode: @Sendable (InlineCode.Input, inout [Rendering.Action]) -> Void
        public var link: @Sendable (Link.Input, inout [Rendering.Action]) -> Void
        public var image: @Sendable (Image.Input, inout [Rendering.Action]) -> Void
        public var orderedList: @Sendable (List.Input, inout [Rendering.Action]) -> Void
        public var unorderedList: @Sendable (List.Input, inout [Rendering.Action]) -> Void
        public var listItem: @Sendable (ListItem.Input, inout [Rendering.Action]) -> Void
        public var table: @Sendable (Table.Input, inout [Rendering.Action]) -> Void
        public var text: @Sendable (Text.Input, inout [Rendering.Action]) -> Void
        public var thematicBreak: @Sendable (inout [Rendering.Action]) -> Void
        public var lineBreak: @Sendable (inout [Rendering.Action]) -> Void
        public var softBreak: @Sendable (inout [Rendering.Action]) -> Void
    }
}
```

Each closure produces actions for that element's **wrapping structure** (the push/pop, attributes, styles). Children are rendered separately by the converter — the closure does NOT render children. Instead, the converter interleaves the element's actions with the children's actions.

**The `.renderChildren` sentinel**: Add `case renderChildren` to `Rendering.Action` (or to a `Markdown.Action` wrapper). The element closure emits `.renderChildren` where children should appear. The converter interprets this by visiting child nodes.

Wait — `Rendering.Action` is in Layer 1 and shouldn't have markdown-specific cases. Two options:

**Option A**: The element closure returns TWO action arrays — `before` (pushed before children) and `after` (pushed after children). The converter renders: before → children → after.

**Option B**: Add a `Markdown.Action` enum that wraps `Rendering.Action` with a `.renderChildren` case. The converter interprets this locally.

**Option C**: The element closures DON'T produce actions. Instead, they receive a mutable reference to the context and write directly. But this reintroduces the generic parameter problem.

**Recommended: Option A** — simplest, no new types, no L1 changes:

```swift
public struct Heading: Sendable {
    // Returns (before, after) — actions to emit before and after children
    public var render: @Sendable (Input) -> (before: [Rendering.Action], after: [Rendering.Action])
}
```

Or even simpler — the closure appends to a buffer, with a convention that `.renderChildren` is a local marker:

Actually, the cleanest approach: **the Input types include children as `[Rendering.Action]`** instead of `HTML.AnyView`. The closure receives pre-rendered children as actions and produces the complete action sequence including the children.

```swift
extension Markdown.Rendering {
    public struct Heading: Sendable {
        public struct Input: Sendable {
            public let level: Int
            public let slug: String
            public let plainText: String
            public let children: [Rendering.Action]  // ← actions, not AnyView
        }
        public var render: @Sendable (Input) -> [Rendering.Action]
    }
}
```

The converter:
1. Visits children → produces `[Rendering.Action]` (by recursion)
2. Passes children actions to the element's `render` closure
3. The closure wraps children actions with push/pop: `[.push(.block(...))] + input.children + [.pop(.block)]`
4. The converter feeds the result to `context.interpret(actions)`

**This is the theoretically perfect approach**: children are already actions, the element closure composes them into a larger action sequence, the converter interprets the final sequence. Zero type erasure. O(1) interpretation stack depth.

---

## What to Build

### 1. `Markdown.Rendering` witness struct

New file: `Markdown.Rendering.swift`

The struct with 18 element closures. Each closure takes an Input (with children as `[Rendering.Action]`) and returns `[Rendering.Action]`.

For elements without children (text, lineBreak, softBreak, thematicBreak, image, inlineCode, codeBlock), the Input has no `children` field.

### 2. Input types

Each element needs an Input struct. Reuse the existing names but change `children: HTML.AnyView` to `children: [Rendering.Action]`.

| Element | Input fields |
|---------|-------------|
| Heading | level, slug, plainText, children: [Rendering.Action] |
| Paragraph | children: [Rendering.Action] |
| BlockQuote | kind, children: [Rendering.Action], isDiagnostic, diagnosticLevel |
| Emphasis | children: [Rendering.Action] |
| Strong | children: [Rendering.Action] |
| Strikethrough | children: [Rendering.Action] |
| Link | destination, title, children: [Rendering.Action] |
| List | isOrdered, children: [Rendering.Action] |
| ListItem | children: [Rendering.Action] |
| Table | head: [Rendering.Action], body: [Rendering.Action], hasHead, hasBody |
| CodeBlock | language, code, highlightLines |
| InlineCode | code |
| Image | source, alt, title |
| Text | text |
| ThematicBreak | (none) |
| LineBreak | (none) |
| SoftBreak | (none) |

### 3. Default renderers

Each element's `.default` produces the standard HTML structure as actions. Study the current default renderers (the `@HTML.Builder` closures) and translate their HTML structure into action sequences.

Example — default heading:

```swift
extension Markdown.Rendering.Heading {
    public static var `default`: Self {
        .init { input in
            var actions: [Rendering.Action] = []
            // Anchor target
            actions.append(.push(.element(tagName: "a", isBlock: false, isVoid: false, isPreElement: false)))
            actions.append(.attribute(set: "id", value: input.slug))
            actions.append(.style(register: "display: block; position: relative; top: -5em; visibility: hidden", atRule: nil, selector: nil, pseudo: nil))
            actions.append(.pop(.element(isBlock: false)))
            // Heading wrapper
            actions.append(.push(.block(role: .heading(level: input.level), style: .empty)))
            actions.append(.push(.element(tagName: "div", isBlock: true, isVoid: false, isPreElement: false)))
            actions.append(.style(register: "margin-left: -2.25rem; padding-left: 2.25rem; position: relative", atRule: nil, selector: nil, pseudo: nil))
            actions.append(.push(.element(tagName: "h\(input.level)", isBlock: true, isVoid: false, isPreElement: false)))
            // Children
            actions.append(contentsOf: input.children)
            // Link icon (simplified — the real one has SVG)
            actions.append(.push(.element(tagName: "a", isBlock: false, isVoid: false, isPreElement: false)))
            actions.append(.attribute(set: "href", value: "#\(input.slug)"))
            actions.append(.style(register: "display: none; position: absolute; left: 0; width: 2.5rem", atRule: nil, selector: nil, pseudo: nil))
            // SVG icon as raw bytes
            actions.append(.raw(Array(LinkIcon.svgBytes)))
            actions.append(.pop(.element(isBlock: false)))
            // Close
            actions.append(.pop(.element(isBlock: true)))
            actions.append(.pop(.element(isBlock: true)))
            actions.append(.pop(.block))
            return actions
        }
    }
}
```

**Note**: The current default heading has responsive CSS (`.desktop { }`, `.mobile { }`) that uses `atRule` parameter of `register(style:atRule:selector:pseudo:)`. Translate these accurately:
```swift
actions.append(.style(register: "top: -0.5em", atRule: "@media (min-width: 768px)", selector: nil, pseudo: nil))
```

### 4. `Markdown.DirectConverter`

New file: `Markdown.DirectConverter.swift`

A `MarkupVisitor` with `Result = [Rendering.Action]`. Each visit method:
1. Visits children (recursive) → produces `[Rendering.Action]`
2. Calls the rendering witness closure with Input (including children actions)
3. Returns the element's action sequence

```swift
extension Markdown {
    struct DirectConverter: SwiftMarkdown.MarkupVisitor {
        typealias Result = [Rendering.Action]

        let rendering: Markdown.Rendering
        let configuration: Markdown.Configuration  // for slugs, directives, diagnostics
        let previewOnly: Bool

        private var currentTimestamp: Timestamp?
        private var currentSection: (title: String, id: String, level: Int)?
        private var existingSlugs: Swift.Set<String> = []
        var tableOfContents: [Markdown.Section] = []

        mutating func defaultVisit(_ markup: any SwiftMarkdown.Markup) -> [Rendering.Action] {
            var actions: [Rendering.Action] = []
            for child in markup.children {
                if previewOnly && tableOfContents.count > 1 { break }
                actions.append(contentsOf: visit(child))
            }
            return actions
        }

        mutating func visitText(_ text: SwiftMarkdown.Text) -> [Rendering.Action] {
            rendering.text.render(.init(text: text.string))
        }

        mutating func visitHeading(_ heading: SwiftMarkdown.Heading) -> [Rendering.Action] {
            let slug = generateSlug(for: heading.plainText)
            currentSection = (title: heading.plainText, id: slug, level: heading.level)

            // Visit children first → actions
            var childActions: [Rendering.Action] = []
            for child in heading.children {
                childActions.append(contentsOf: visit(child))
            }

            return rendering.heading.render(.init(
                level: heading.level,
                slug: slug,
                plainText: heading.plainText,
                children: childActions
            ))
        }

        // ... same pattern for all 18 elements
    }
}
```

### 5. `Markdown` as leaf view

Change `Markdown.body` to `_render` with `RenderBody = Never`:

```swift
public struct Markdown: HTML.View {
    let markdownString: String
    let configuration: Configuration
    let rendering: Rendering
    let previewOnly: Bool

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        let document = SwiftMarkdown.Document(
            parsing: view.markdownString,
            options: .parseBlockDirectives
        )

        // Outer wrapper
        context.push.block(role: nil, style: .empty)
        context.add(class: "markdown")
        _ = context.register(style: "display: block", atRule: nil, selector: nil, pseudo: nil)

        // VStack wrapper
        context.push.block(role: nil, style: .empty)
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

        // Convert markdown → actions → interpret
        var converter = DirectConverter(
            rendering: view.rendering,
            configuration: view.configuration,
            previewOnly: view.previewOnly
        )
        let actions = converter.visit(document)
        context.interpret(actions)

        context.pop.block()  // VStack
        context.pop.block()  // outer
    }
}
```

### 6. Update `Markdown.init`

Add `rendering` parameter:

```swift
public init(
    configuration: Configuration = .default,
    rendering: Rendering = .default,
    previewOnly: Bool = false,
    @Markdown.Builder _ markdown: () -> String
) {
    self.configuration = configuration
    self.rendering = rendering
    self.previewOnly = previewOnly
    self.markdownString = markdown()
}
```

### 7. `tableOfContents` extraction

Keep using the DirectConverter:

```swift
public static func tableOfContents(
    from markdown: String,
    configuration: Configuration = .default,
    rendering: Rendering = .default
) -> [Section] {
    var converter = DirectConverter(
        rendering: rendering,
        configuration: configuration,
        previewOnly: false
    )
    _ = converter.visit(
        SwiftMarkdown.Document(parsing: markdown, options: .parseBlockDirectives)
    )
    return converter.tableOfContents
}
```

The actions are produced but discarded — only the side-effect (tableOfContents accumulation) matters.

### 8. Keep the old Converter for now

Don't delete `Markdown.Converter.swift` yet. It may be needed by:
- Block directives that return `HTML.AnyView` (the directive handler API)
- Downstream code that references `Markdown.Converter` directly

Mark it as deprecated if possible, or leave it as an internal fallback.

### 9. Block directives

The current `visitBlockDirective` delegates to `configuration.directives.handler(directive)` which returns `.rendered(HTML.AnyView)`, `.suppress`, or `.useDefault`. The `.rendered` case returns an `HTML.AnyView` — this needs special handling.

Options:
- Render the AnyView into a recording context → capture as actions → include in action sequence
- Keep `HTML.AnyView` support for directives only (hybrid)

**Recommended**: For directives that return `.rendered(view)`, render the view into a temporary recording context to capture its actions:

```swift
mutating func visitBlockDirective(_ blockDirective: SwiftMarkdown.BlockDirective) -> [Rendering.Action] {
    // ... parse directive ...
    let result = configuration.directives.handler(directive)
    switch result {
    case .rendered(let view):
        // Render the AnyView through a recording context to capture actions
        let recording = Ownership.Mutable(Rendering.Recording.State())
        var recordingContext = Rendering.Context.recording(into: recording)
        HTML.AnyView._render(view, context: &recordingContext)
        return recording.value.actions  // captured as Rendering.Actions
    case .suppress:
        return []
    case .useDefault:
        return childActions
    }
}
```

This preserves backward compatibility for existing directive handlers while producing actions.

### 10. Diagnostic blockquotes

The current default blockquote renderer checks `isDiagnostic` and renders a `Markdown.Diagnostic` view. In the action-based approach, the diagnostic HTML structure is expressed as actions in the default blockquote renderer closure.

---

## Files to Modify

| File | Change |
|------|--------|
| `Markdown.swift` | body-based → leaf view with _render |
| `Markdown.Converter.swift` | Keep for compatibility, mark deprecated |
| `Markdown.Configuration.Element.swift` | Keep as-is (existing API preserved) |
| `Markdown.Configuration.Element.*.swift` (18 files) | Keep as-is OR update Input types |
| `Markdown.Configuration.swift` | Add `rendering: Rendering` field |

**New files:**

| File | Contains |
|------|----------|
| `Markdown.Rendering.swift` | The witness struct |
| `Markdown.Rendering.*.swift` | Per-element Input + default (18 files, per [API-IMPL-005]) |
| `Markdown.DirectConverter.swift` | The action-producing MarkupVisitor |

---

## Critical Design Decision: Coexistence vs Replacement

The old `Markdown.Configuration.Elements` (AnyView-based) and new `Markdown.Rendering` (Action-based) can **coexist**. The `Markdown` init takes both:

```swift
public init(
    configuration: Configuration = .default,  // includes old element renderers (for directives)
    rendering: Rendering = .default,          // new action-based renderers
    previewOnly: Bool = false,
    @Markdown.Builder _ markdown: () -> String
)
```

The old `Configuration.Elements` is still used for:
- Block directives (their handler returns AnyView)
- Any downstream code using the old API

The new `Markdown.Rendering` is used for:
- All 18 standard markdown elements
- The direct rendering path (no AnyView)

This allows gradual migration — existing code keeps working, new code uses the action path.

---

## Validation

```bash
cd /Users/coen/Developer/swift-foundations/swift-markdown-html-rendering
swift build
swift test
```

Also verify the PDF markdown tests (these were the ones that crashed with stack overflow):

```bash
cd /Users/coen/Developer/swift-foundations/swift-pdf
swift test
```

If the PDF markdown tests pass, the stack overflow is fixed.

---

## Files to Read Before Starting

| File | Why |
|------|-----|
| `Rendering.Context.swift` (L1) | The witness struct + interpret method |
| `Rendering.Action.swift` (L1) | The Action enum with nested Push/Pop |
| `Rendering.Context +HTML.swift` (L3) | The HTML factory pattern to follow |
| `Markdown.swift` | Current body-based implementation |
| `Markdown.Converter.swift` | Current AnyView-producing visitor (447 lines) |
| `Markdown.Configuration.Element.Heading.swift` | Example default renderer to translate |
| `Markdown.Configuration.Element.BlockQuote.swift` | Diagnostic handling |
| `Markdown.Diagnostic.swift` | Diagnostic view to translate to actions |
| `LinkIcon.swift` | SVG bytes for heading anchor icons |
| All 18 `Markdown.Configuration.Element.*.swift` | Default renderers to translate |

---

## Reference: Prior Research

| Document | Key insight |
|----------|------------|
| `markdown-direct-context-rendering.md` | Original analysis of 6 approaches, C+A+F recommendation |
| `rendering-witness-architecture-value-analysis.md` | Action enum as free Σ-algebra, tee transform |
| `rendering-context-witness-migration-implications.md` | Migration scope, factory pattern |
| `sigbus-stack-overflow-handoff.md` | Stack overflow root cause (AnyView nesting depth) |
| `markdown-rendering-organization-audit.md` | F-6: AnyView everywhere finding |

---

## Constraints

- **Only modify swift-markdown-html-rendering**
- Follow [API-IMPL-005] — one type per file for Markdown.Rendering and its element types
- Follow [API-NAME-001] — `Markdown.Rendering`, `Markdown.DirectConverter`
- The old `Markdown.Configuration.Elements` API is preserved for backward compatibility
- The `Markdown.Rendering` witness closures are `@Sendable`
- Children are `[Rendering.Action]`, not `HTML.AnyView`
- The DirectConverter returns `[Rendering.Action]` (not `Void`) — actions flow up the AST
- Block directives keep their AnyView handler but render through a recording context to capture actions
- The `Markdown.Diagnostic` view's HTML structure is translated to actions in the default blockquote renderer

## What NOT to Do

- Do NOT modify packages from Phases 1–3
- Do NOT delete the old `Markdown.Converter` — keep it for compatibility
- Do NOT change the `Markdown.Configuration.Elements.*.Input` types — the new Input types live in `Markdown.Rendering.*`
- Do NOT change the directive handler API (`configuration.directives.handler`)
- Do NOT use the `@Witness` macro
- Do NOT try to make this a transformer on Rendering.Context — it's a separate visitor that produces actions
