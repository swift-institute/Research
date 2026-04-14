# Implementation: Markdown Rendering Performance Parity

## Assignment

Eliminate the 20x performance gap between our styled markdown rendering pipeline and a bare swift-markdown HTML visitor. The goal: rendering 100 sections of styled markdown should approach the 121ms baseline of a bare `MarkupVisitor` that produces unstyled HTML strings.

**Current measurements (debug build, 100 sections):**

| Pipeline | Median | vs Bare |
|----------|--------|---------|
| SwiftMarkdown parse only | 110ms | 0.9x |
| Bare HTML visitor (parse + walk → string) | 121ms | **1.0x** |
| Our action pipeline (parse + capture → actions → interpret) | 2,431ms | **20.1x** |

The 20x overhead comes from `Markdown.Rendering.capture { HTMLView }` calls in element renderers. Each call constructs an HTML view tree (struct allocations, CSS property wrappers), renders it recursively through `_render`, and extracts actions. This happens for EVERY element on EVERY document render.

**Target**: < 3x of the bare visitor in debug, < 1.5x in release. That means < 363ms debug, < 182ms release for 100 sections.

---

## Architecture Context

### The rendering pipeline

```
Markdown string
    → SwiftMarkdown.Document(parsing:)        [110ms — parsing]
    → Markdown.Rendering.Converter.visit()     [action production]
        → per element: renderer.render(input)  [view construction + capture]
    → context.interpret(markdown: actions)      [action interpretation]
    → HTML bytes in context
```

### What's slow

Each of the 18 element renderers has a `.render` closure. The default closures call `Markdown.Rendering.capture { HTMLView }` which:
1. Allocates HTML view structs (Anchor, ContentDivision, tag, Styled wrappers)
2. Applies CSS properties (each `.css.lineHeight(1.5)` creates a `Styled<Content>` wrapper)
3. Recursively calls `_render` on the view tree
4. The capturing context records each operation as a `Rendering.Action`

For a 100-section document with ~1200 elements, this means ~1200 view tree constructions + ~1200 recursive `_render` calls. Each call is ~1-2ms in debug (due to closure dispatch + no inlining).

### What's already optimized

- **Frame caching** for 10 static elements (Paragraph, Emphasis, Strong, Strikethrough, InlineCode, ListItem, List×2, LineBreak, ThematicBreak). These compile the view tree ONCE (`static let frame`) and splice children on subsequent calls. But they still construct the view tree on first access.
- **Splice optimization** — `Replay._render` uses `context.splice()` for O(1) children embedding.
- **Text and SoftBreak** — already pure action production (no capture).

### What's still slow

6 elements still use `capture {}` PER CALL because they have dynamic attributes:
- **Heading** — slug, level, link icon href (12 CSS properties, responsive breakpoints, SVG icon)
- **CodeBlock** — language class, code text, highlight lines (6 CSS properties)
- **BlockQuote** — diagnostic detection, blockquote kind styling (10+ CSS properties, conditional)
- **Link** — destination href, title attribute
- **Image** — source, alt, title (5 CSS properties, nested anchor)
- **Table** — head/body conditional, already uses pure actions for cells

Plus the **outer wrapper** in `Markdown._render` — `capture { ContentDivision { VStack { Replay(actions) } } }` with 7 CSS properties. This captures the ENTIRE document's actions through a view tree.

---

## The Fix: Pure Action Defaults with Frame Templates

### Strategy

Replace ALL remaining `capture {}` calls with **pure action construction** that directly builds `[Rendering.Action]` arrays. No view tree allocation, no `_render` recursion, no CSS property wrappers.

But — and this is critical — **maintain readability** per [IMPL-INTENT]. Do NOT replace beautiful view builder syntax with raw `actions.append(.push(.element(...)))` chains. Instead, use **Frame templates** and **helper methods** that read as intent.

### Frame template pattern (for elements with static CSS + dynamic children/attributes)

```swift
extension Markdown.Rendering.Heading {
    // Static structure compiled once from view DSL
    private static let anchorFrame = Markdown.Rendering.Frame {
        Anchor {}
            .css
            .display(.block)
            .position(.relative)
            .top(Top.em(-5))
            .desktop { $0.top(Top.em(-0.5)) }
            .visibility(.hidden)
    }

    // Dynamic attributes applied at runtime
    public static var `default`: Self {
        .init { input in
            var actions: [Rendering.Action] = []

            // Anchor target — static frame + dynamic id
            actions.append(contentsOf: anchorFrame.prefix)
            actions.append(.attribute(set: "id", value: input.slug))
            actions.append(contentsOf: anchorFrame.suffix)

            // Heading content — cached frame with dynamic tag
            // (tag name varies by level, so can't use static Frame)
            actions.append(.push(.element(tagName: "h\(input.level)", isBlock: true, isVoid: false, isPreElement: false)))
            actions.append(contentsOf: input.children)
            actions.append(.pop(.element(isBlock: true)))

            return actions
        }
    }
}
```

Wait — this still has raw action appends. Per [IMPL-INTENT], we need intent-level helpers.

### Intent-level helpers

Add small helpers that express rendering intent without exposing action construction:

```swift
extension [Rendering.Action] {
    /// Wraps actions in an element.
    mutating func element(_ tagName: String, block: Bool = true, @ActionBuilder content: () -> [Rendering.Action]) {
        append(.push(.element(tagName: tagName, isBlock: block, isVoid: false, isPreElement: false)))
        append(contentsOf: content())
        append(.pop(.element(isBlock: block)))
    }
}
```

Or use a result builder for actions? Or use the Frame's `applying` with attribute injection?

**The key insight: the Frame pattern already works for the static parts. For dynamic parts (attributes, variable tag names), we need a small set of helpers that bridge the gap without regressing to raw appends.**

### Recommended approach: Parametric Frames

Extend `Markdown.Rendering.Frame` to support attribute injection:

```swift
extension Markdown.Rendering.Frame {
    /// Applies the frame with children and attribute patches.
    func applying(
        children: [Rendering.Action],
        attributes: [Rendering.Action] = []
    ) -> [Rendering.Action] {
        var result: [Rendering.Action] = []
        result.reserveCapacity(prefix.count + attributes.count + children.count + suffix.count)
        result.append(contentsOf: prefix)
        result.append(contentsOf: attributes)
        result.append(contentsOf: children)
        result.append(contentsOf: suffix)
        return result
    }
}
```

Then the heading anchor becomes:

```swift
private static let anchorFrame = Markdown.Rendering.Frame {
    Anchor { Markdown.Rendering.Frame.Placeholder() }
        .css.display(.block).position(.relative).top(Top.em(-5))
        .desktop { $0.top(Top.em(-0.5)) }
        .visibility(.hidden)
}

// In the render closure:
actions.append(contentsOf: anchorFrame.applying(
    children: [],
    attributes: [.attribute(set: "id", value: input.slug)]
))
```

This preserves the view DSL for the static parts (CSS, structure) and uses a small, readable API for the dynamic parts (attribute injection).

---

## What to Implement

### Phase 1: Outer wrapper (biggest single impact)

**File**: `Markdown.swift` — the `_render` method

The outer wrapper currently uses `capture { ContentDivision { VStack { Replay(actions) } .css... } .css... }`. Convert to a static Frame:

```swift
private static let outerFrame = Markdown.Rendering.Frame {
    ContentDivision {
        VStack(spacing: .rem(0.5)) {
            Markdown.Rendering.Frame.Placeholder()
        }
    }
    .css
    .display(.block)
}
```

Then in `_render`:
```swift
var actions = outerFrame.applying(children: contentActions)
if view.previewOnly {
    // Insert mask-image style at the VStack level
    // This needs the Frame to support style injection, or handle separately
}
context.interpret(markdown: actions)
```

The `previewOnly` mask-image is tricky — it's applied to the VStack, which is inside the Frame. Options:
1. Two frames: one with mask, one without. Select at runtime.
2. Inject the style action after the VStack's push.

Option 1 is cleaner:
```swift
private static let outerFrame = Markdown.Rendering.Frame { /* without mask */ }
private static let outerFramePreview = Markdown.Rendering.Frame { /* with mask */ }

let frame = view.previewOnly ? Self.outerFramePreview : Self.outerFrame
context.interpret(markdown: frame.applying(children: contentActions))
```

### Phase 2: Heading (most complex, most frequent in sections)

**File**: `Markdown.Rendering.Heading.swift`

The heading has:
- Invisible anchor target (static CSS, dynamic `id` attribute)
- Wrapper div (static CSS with responsive breakpoints)
- Heading element (`h1`–`h6` — dynamic tag name)
- Link icon anchor (static CSS, dynamic `href`)
- LinkIcon SVG (static raw bytes)

Split into:
1. Anchor frame (static CSS) + attribute injection (`id`)
2. Wrapper div frame (static CSS) — use Frame
3. Heading tag — dynamic (`h\(level)`) — must be direct action, but it's just one push/pop
4. Link icon — static Frame + attribute injection (`href`)
5. SVG bytes — static, cached

Read `LinkIcon.swift` to get the SVG bytes. They should be a `static let` already.

### Phase 3: CodeBlock

**File**: `Markdown.Rendering.CodeBlock.swift`

Static CSS: `color`, `margin`, `marginBottom`, `overflowX`, `padding`, `borderRadius`.
Dynamic: `class` attribute (language), `data-line` attribute (highlight), code text content.

Use Frame for the `<pre>` wrapper with CSS. Inject attributes and text at runtime.

### Phase 4: Link

**File**: `Markdown.Rendering.Link.swift`

Simple — `<a>` with dynamic `href` and `title`. No CSS on the link itself. This could be pure actions without any Frame (the structure is just push + attributes + children + pop).

### Phase 5: Image

**File**: `Markdown.Rendering.Image.swift`

Has CSS (margins, border-radius) on the `<img>` inside a VStack. Use Frame for the static wrapper, inject `src` and `alt` attributes.

### Phase 6: BlockQuote

**File**: `Markdown.Rendering.BlockQuote.swift`

Two paths:
1. **Non-diagnostic**: `<blockquote>` with CSS (border, background, padding). The blockquote `kind` determines colors — these are dynamic. But the CSS property NAMES are static, only VALUES vary.
2. **Diagnostic**: Complex `Markdown.Diagnostic` view with nested HStack, icon panel, message panel. This is the most complex renderer.

For non-diagnostic: parametric Frame with style value injection.
For diagnostic: keep `capture {}` for now (diagnostics are rare in most documents) or convert to pure actions.

### Phase 7: Table

**File**: `Markdown.Rendering.Table.swift`

Currently uses `capture { HTML_Rendering.Table { ... } }`. The table structure (`<table><thead><tbody>`) is simple. Use a static Frame for the outer table, splice head/body.

### Phase 8: Outer wrapper mask-image for previewOnly

Handle the `previewOnly` variant of the outer Frame. Either two cached frames or post-injection.

---

## Files to Modify

| File | Change |
|------|--------|
| `Markdown.swift` | `_render` outer wrapper → static Frame |
| `Markdown.Rendering.Heading.swift` | capture → split Frames + attribute injection |
| `Markdown.Rendering.CodeBlock.swift` | capture → Frame + attribute injection |
| `Markdown.Rendering.Link.swift` | capture → pure actions (trivial structure) |
| `Markdown.Rendering.Image.swift` | capture → Frame + attribute injection |
| `Markdown.Rendering.BlockQuote.swift` | Non-diagnostic → Frame; diagnostic → keep capture or convert |
| `Markdown.Rendering.Table.swift` | capture → Frame |
| `Markdown.Rendering.Frame.swift` | Add `applying(children:attributes:)` variant |

**DO NOT modify**: Paragraph, Emphasis, Strong, Strikethrough, InlineCode, ListItem, List, LineBreak, SoftBreak, ThematicBreak — these already use Frame caching or are already pure.

---

## Files to Read Before Starting

| File | Why |
|------|-----|
| `Markdown.Rendering.Frame.swift` | The Frame type + Placeholder + captureFrame |
| `Markdown.Rendering.Paragraph.swift` | Example of static Frame usage (the pattern to follow) |
| `Markdown.Rendering.Heading.swift` | Most complex renderer to convert |
| `Markdown.Rendering.CodeBlock.swift` | Medium complexity with dynamic attributes |
| `Markdown.Rendering.BlockQuote.swift` | Conditional rendering (diagnostic vs normal) |
| `Markdown.Rendering.Link.swift` | Simple dynamic attributes |
| `Markdown.Rendering.Image.swift` | CSS + dynamic attributes |
| `Markdown.Rendering.Table.swift` | Conditional content (head/body) |
| `Markdown.swift` | The outer wrapper in `_render` |
| `LinkIcon.swift` | SVG bytes for heading link icon |
| `Markdown.Rendering.Converter.swift` | How renderers are called from the visitor |
| `Rendering.Context+Capturing.swift` | How capture works |
| `Rendering.Context+InterpretMarkdown.swift` | How interpret(markdown:) handles CSS class flow |
| `Tests/.../Pipeline Comparison Tests.swift` | The benchmark + bare HTML visitor |

---

## Design Constraints

### [IMPL-INTENT] — Code reads as intent, not mechanism

**DO NOT** write:
```swift
actions.append(.push(.style))
actions.append(.style(register: "margin:0", atRule: nil, selector: nil, pseudo: nil))
actions.append(.push(.style))
actions.append(.style(register: "padding:0", atRule: nil, selector: nil, pseudo: nil))
```

**DO** write:
```swift
// Static CSS compiled once from view DSL
private static let wrapperFrame = Markdown.Rendering.Frame {
    ContentDivision { Markdown.Rendering.Frame.Placeholder() }
        .css.margin(.zero).padding(.zero)
}

// Runtime: splice children into cached frame
wrapperFrame.applying(children: input.children)
```

The view DSL is the "intent language" for CSS. Raw action appends are mechanism. Use Frame for all static CSS. Only use raw actions for truly dynamic content (tag names, attribute values, text).

### [API-NAME-001] / [API-NAME-002] — Naming conventions

If you add helper methods, follow naming conventions. No compound names.

### Preserve existing API

- The `Markdown.Rendering.*` witness struct API stays unchanged
- The `Input` types stay unchanged
- The `render` closure signatures stay unchanged
- Custom renderers (user-provided) still work — they can use capture or pure actions

### Identical HTML output

Every converted renderer MUST produce byte-identical HTML to the `capture {}` version. Run the snapshot tests to verify. The test suite has 96 tests that validate HTML output.

---

## Validation

### Correctness
```bash
cd swift-markdown-html-rendering
swift build && swift test   # 96 tests must pass
```

### Snapshot tests
```bash
cd Tests
swift test --filter "Snapshot"   # all snapshots must match
```

### Performance
```bash
cd Tests
swift test --filter "Pipeline Comparison" 2>&1 | grep -E "Test:.*Pipeline" -A2 | grep -E "Test:|Value:"
```

Target results:
```
parse only - 100 sections:              ~110ms
swift-markdown raw HTML - 100 sections: ~121ms
full action pipeline - 100 sections:    < 363ms  (< 3x bare visitor)
old string pipeline - 100 sections:     ~2,400ms (unchanged, for reference)
```

### PDF smoke test
```bash
cd swift-pdf
rm -rf .build && swift test   # markdown-to-PDF tests must pass (no stack overflow)
```

---

## Key Insight: What the Bare Visitor Does Differently

The bare visitor takes 121ms for 100 sections because it does ONLY:
1. Walk AST nodes (swift-markdown's visitor dispatch)
2. String concatenation (`"<p>" + children + "</p>"`)

It does NOT:
- Allocate view structs
- Apply CSS properties (no Styled wrappers, no class generation)
- Recursively call `_render` on a view tree
- Register styles in a style dictionary
- Generate CSS class names

Our pipeline MUST do CSS class generation (that's the value we add over bare HTML). But it should NOT construct view trees to do it. The Frame pattern pre-computes the CSS once; runtime just splices the cached action sequence.

The remaining gap after Frame conversion will be:
1. Array allocation for `[Rendering.Action]` per element (~small)
2. `append(contentsOf:)` for children splicing (~small)
3. Slug generation for headings (~small)
4. Any remaining `capture {}` calls (diagnostics, directives)

This should bring us to < 3x the bare visitor.

---

## What NOT to Do

- Do NOT replace the view builder syntax in Frame static lets — the whole point is keeping the DSL
- Do NOT modify `Rendering.Context`, `Rendering.Action`, or any L1 code
- Do NOT modify the `Markdown.Rendering.Converter` — it calls `renderer.render(input)` and doesn't care what the render closure does internally
- Do NOT modify `Rendering.Context+InterpretMarkdown.swift` — the CSS class flow is correct
- Do NOT change element `Input` types
- Do NOT break backward compatibility for custom renderers
- Do NOT create new types unless necessary — Frame + helpers should suffice
- Do NOT add Foundation imports
- Follow [API-IMPL-005] — one type per file
- Follow [API-NAME-001] / [API-NAME-002] — no compound names
