# Research: Markdown Action Rendering Performance Optimization

## Assignment

The action-based markdown rendering pipeline (Phase 4) works correctly and eliminates the stack overflow. But it's slow — 22x the raw SwiftMarkdown parsing time for a 100-section document in debug builds. The old AnyView pipeline is equally slow (same 22x), so the action layer itself isn't the bottleneck. The bottleneck is the `capture { }` pattern used by default element renderers.

Conduct a Tier 1 investigation ([RES-004]) to identify optimization opportunities and recommend a path to book-scale performance (1000+ sections in < 5 seconds, release build).

**Output**: Research document at `swift-foundations/swift-markdown-html-rendering/Research/markdown-action-rendering-performance-optimization.md` per [RES-003].

---

## Context

### Current architecture

Each of the 18 default element renderers uses `Markdown.Rendering.capture { HTMLView }` — it constructs the existing HTML view (with CSS styling), renders it through a capturing `Rendering.Context`, and extracts the resulting `[Rendering.Action]`. This guarantees identical HTML output to the old pipeline.

```swift
// Current: capture-based default (heading example)
public static var `default`: Self {
    .init { input in
        Markdown.Rendering.capture {
            Anchor {} .id(input.slug) .css.display(.block) ...
            ContentDivision {
                tag("h\(input.level)") { ... }
            } .css.marginLeft(...) ...
        }
    }
}
```

The `capture` function:
1. Creates a recording `Rendering.Context`
2. Builds the HTML view tree (allocates Anchor, ContentDivision, Tag, Styled wrappers)
3. Renders the tree via `_render(view, context: &recordingContext)` (recursive)
4. Extracts `[Rendering.Action]` from the recording

Steps 2–3 are expensive: view struct allocation, CSS property application, recursive `_render` dispatch. This is the SAME work the old AnyView pipeline did — we just capture the result as data instead of dispatching through existentials.

### Performance baseline (debug build, 100 sections, ~1200 markdown elements)

| Layer | Time | % of total |
|-------|------|-----------|
| SwiftMarkdown parsing | 113ms | 4.4% |
| Full action pipeline (parse + capture + interpret) | 2,552ms | 100% |
| Old string pipeline (parse + AnyView + render) | 2,548ms | ~100% |
| **Rendering overhead (total - parsing)** | **~2,439ms** | **95.6%** |

The rendering overhead is 22x the parsing cost. Both old and new pipelines pay it equally.

### The optimization opportunity

Replace `capture { HTMLView }` with **pure action-producing closures** that emit actions directly without constructing HTML views:

```swift
// Proposed: pure action default (heading example)
public static var `default`: Self {
    .init { input in
        var actions: [Rendering.Action] = []
        actions.append(.push(.element(tagName: "a", isBlock: false, isVoid: false, isPreElement: false)))
        actions.append(.attribute(set: "id", value: input.slug))
        actions.append(.style(register: "display: block; position: relative; top: -5em; visibility: hidden"))
        actions.append(.pop(.element(isBlock: false)))
        actions.append(.push(.block(role: .heading(level: input.level), style: .empty)))
        // ... children + link icon ...
        actions.append(.pop(.block))
        return actions
    }
}
```

No view allocation, no CSS property wrappers, no recursive `_render`. Just array appends.

---

## Questions to Answer

### 1. Where exactly does the time go?

Profile the 100-section benchmark. Break down:
- SwiftMarkdown `Document(parsing:)` time
- `Markdown.Rendering.Converter.visit()` total time (action production)
- Per-element `capture {}` time (which elements are slowest?)
- `context.interpret(actions)` time (action interpretation)
- HTML.Context byte writing time

### 2. What's the theoretical minimum?

If we replaced ALL `capture {}` defaults with pure action closures:
- The action production becomes: walk AST + append to `[Rendering.Action]` array
- No view allocation, no `_render` recursion, no CSS property structs
- Estimate: close to parsing time (array appends are cheap)

### 3. Which elements have the most expensive defaults?

The heading default has: Anchor + ContentDivision + tag + Anchor + LinkIcon SVG + 12 CSS properties with responsive breakpoints. The code block has: PreformattedText + Code + 6 CSS properties. The blockquote with diagnostics has: nested HStack + VStack + multiple ContentDivisions + SVG icons + 10+ CSS properties.

Rank the 18 elements by rendering cost. The most expensive ones should be converted to pure actions first.

### 4. What about responsive CSS?

The current defaults use `.desktop { }` and `.mobile { }` which generate `@media` query CSS. In action form, these become:
```swift
.style(register: "top: -0.5em", atRule: "@media (min-width: 768px)", selector: nil, pseudo: nil)
```

Is there a fidelity loss? The `register(style:atRule:selector:pseudo:)` API supports media queries. Verify.

### 5. What about selector-based CSS?

The heading default uses `.selector("article div:hover > * >") { $0.display(.initial) }`. In action form:
```swift
.style(register: "display: initial", atRule: nil, selector: "article div:hover > * >", pseudo: nil)
```

Verify the HTML.Context handles selector-based styles correctly when received via `interpret`.

### 6. Release build performance

The 22x overhead is in debug. What's the ratio in release? The view construction may inline aggressively in release. Measure both pipelines in release to establish the actual production performance gap.

### 7. Action array allocation

Each element produces 5-20 actions. For a 100-section document with ~1200 elements, that's ~6000-24000 action values. Each action is an enum with associated values (~48-80 bytes). Total: ~300KB-1.9MB of action data.

Is this significant? Should we use a pre-allocated buffer? The `removeAll(keepingCapacity: true)` pattern from the earlier design?

### 8. Can we make the `capture {}` path faster without replacing it?

If replacing all 18 defaults with pure actions is too much work, can we optimize the `capture {}` path itself?
- Reduce the number of CSS properties on default elements
- Use simpler HTML structures for the defaults
- Cache the action sequences for static content (headings with the same level produce the same wrapping actions)

---

## Experiment Design

Create an experiment in `swift-institute/Experiments/markdown-rendering-performance-profiling/` that:

1. **Profiles per-element cost**: Render each of the 18 element types 1000 times in isolation, measure time per element
2. **Profiles per-layer cost**: Instrument the pipeline to measure parsing, action production, and interpretation separately
3. **Compares capture vs pure actions**: Implement pure action defaults for 3 key elements (heading, paragraph, code block) and compare against the capture defaults
4. **Measures release performance**: Run the 100-section benchmark in both debug and release

The experiment should produce a concrete recommendation: which elements to convert first, expected speedup, and whether the remaining capture-based elements are acceptable.

---

## Files to Read

| File | Contains |
|------|----------|
| `swift-markdown-html-rendering/.../Markdown.Rendering.swift` | The capture helper |
| `swift-markdown-html-rendering/.../Markdown.Rendering.Heading.swift` | Most complex default |
| `swift-markdown-html-rendering/.../Markdown.Rendering.CodeBlock.swift` | Medium complexity |
| `swift-markdown-html-rendering/.../Markdown.Rendering.Paragraph.swift` | Simple default |
| `swift-markdown-html-rendering/.../Markdown.Rendering.Converter.swift` | Action-producing visitor |
| `swift-markdown-html-rendering/.../Rendering.Context+Capturing.swift` | The capture context factory |
| `swift-markdown-html-rendering/.../Rendering.Context+InterpretMarkdown.swift` | interpret(markdown:) |
| `swift-markdown-html-rendering/Tests/.../Pipeline Comparison Tests.swift` | Current benchmarks |
| `swift-markdown-html-rendering/Tests/.../Action Rendering Performance Tests.swift` | Stress tests |
| `swift-rendering-primitives/.../Rendering.Action.swift` | Action enum definition |

---

## Success Criteria

1. Per-element cost ranking for all 18 elements
2. Per-layer cost breakdown (parse / action production / interpretation)
3. Comparison of capture vs pure action defaults for at least 3 elements
4. Release build measurements
5. Concrete recommendation: which elements to convert, expected overall speedup
6. Path to book-scale performance (1000+ sections in < 5s release)
