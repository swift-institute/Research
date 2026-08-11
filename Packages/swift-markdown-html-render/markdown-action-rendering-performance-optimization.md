# Markdown Action Rendering Performance Optimization

<!--
---
version: 2.0.0
last_updated: 2026-03-15
status: RECOMMENDATION
---
-->

## Context

The action-based markdown rendering pipeline (Phase 4) works correctly and eliminates the stack overflow that plagued the old AnyView pipeline. However, it is slow: **~1.88s** for a 100-section document in debug builds. The old AnyView pipeline shows identical performance, confirming the action layer itself is not the bottleneck — the bottleneck is the `capture { }` bridge pattern used by default element renderers.

**Trigger**: Performance profiling of 100-section book-chapter rendering.

**Constraints**: Any optimization must produce byte-identical HTML output. Custom user-supplied renderers (which use `capture {}`) must continue to work. The pure action path should coexist with capture-based renderers.

## Question

Where exactly does the rendering time go, and what is the fastest path to book-scale performance (1000+ sections in <5 seconds, release build)?

## Analysis

### Current Pipeline Architecture

```
Markdown string
    ↓  SwiftMarkdown.Document(parsing:)
SwiftMarkdown AST (~1200 nodes for 100 sections)
    ↓  Converter.visit() — walks AST
    ↓  Per-element: renderer.render(input)
    ↓    → capture { HTML views } → [Action]
[Rendering.Action] array
    ↓  Outer capture: ContentDivision { VStack { Replay(actions) } }
    ↓    → re-interprets ALL actions through capturing context
    ↓  context.interpret(markdown: actions)
HTML bytes
```

The `capture {}` path for each element:
1. **Constructs** HTML view structs (Element.Tag, HTML.Styled wrappers, layout containers)
2. **Renders** recursively via `V._render(view, context: &capturingCtx)` — each view calls children
3. **Replays** children actions through the capturing context via `Markdown.Rendering.Replay`
4. **Captures** the resulting operations as `[Rendering.Action]`

Steps 1–3 are the bottleneck. Each CSS property application (`.css.color(.red)`) creates a nested `HTML.Styled<Base, Property>` wrapper. Each wrapper's `_render` does: push style → register style → render child → pop style. For a heading with 18 CSS properties across 5 HTML elements, that's ~24 recursive `_render` calls with closure dispatch through the `Rendering.Context` function pointers.

### Critical Discovery: Children Replay Amplification

Step 3 is the dominant hidden cost. When a capture-based renderer receives `children: [Action]`, it wraps them in a `Replay` view that re-interprets every child action through the capturing context. This means:

- A paragraph's 5 children actions get interpreted through the capturing context (5 closure dispatches)
- A heading's children (paragraph text + emphasis + inline code) get interpreted through the heading's capturing context
- The outer wrapper in `Markdown._render` re-interprets ALL ~20,000 content actions through its capturing context

Every ancestor that uses capture adds a full pass through its descendants' actions. This compounds: a text node inside an emphasis inside a paragraph inside a list item inside a list inside the outer wrapper goes through **6 capture → replay cycles**.

With pure action defaults, children are spliced via `actions.append(contentsOf: input.children)` — an O(n) memcpy with zero closure dispatch.

### Measured Per-Element Performance (debug, `.timed()`)

Benchmark environment: arm64, 8 cores, 24GB, Swift 6.2, debug optimization.

| Element | Capture (median) | Pure action (median) | Speedup |
|---------|:-----------------:|:--------------------:|:-------:|
| **Paragraph** | 8.791µs | 500ns | **17.6x** |
| **InlineCode** | 1.458µs | 208ns | **7.0x** |
| **ListItem** | 21.208µs | 583ns | **36.4x** |
| Emphasis (capture baseline) | 2.250µs | — | — |
| Text (already pure baseline) | 208ns | — | — |

All measurements: CV < 5% (STABLE), no thermal throttle trend.

ListItem is the most expensive per-call because it has a VStack wrapper (4 CSS push/pop/register cycles) AND replays children through the capturing context. Paragraph's 3 CSS properties add 8.3µs of overhead. InlineCode has no CSS but still pays view construction + _render dispatch cost.

### Measured Full Pipeline Performance (debug, `.timed()`)

| Scale | All capture | 3 pure + 15 capture | Improvement |
|-------|:-----------:|:-------------------:|:-----------:|
| **100 sections** | 1.877s | 1.709s | **8.9%** |
| **500 sections** | 38.045s | 34.516s | **9.3%** |

The 3 converted elements (paragraph, inlineCode, listItem) account for ~32% of per-section _render calls but only ~9% full-pipeline improvement. This is because:

1. The per-element savings (paragraph: 8.3µs, inlineCode: 1.25µs, listItem: 20.6µs) sum to ~15ms for 100 sections — trivial relative to the 1.877s total
2. The dominant cost is **children replay amplification** through the outer wrapper and remaining capture-based ancestors
3. The outer `Rendering.capture { ContentDivision { VStack { Replay(contentActions) } } }` in `Markdown._render` still re-interprets ALL actions through a capturing context regardless of which element renderers are pure

**Implication**: Converting individual elements yields diminishing returns until the outer wrapper and all ancestors in the capture chain are also converted. The greatest gains come from converting the entire chain, especially the heading (which has the deepest children) and the outer wrapper.

### Per-Element Cost Analysis (static, from code)

| Rank | Element | _render calls | CSS props | Uses/section |
|------|---------|:------------:|:---------:|:------------:|
| 1 | **Heading** | ~24 | 18 | 3 |
| 2 | **BlockQuote** (diagnostic) | ~25 | 15 | 1 |
| 3 | **BlockQuote** (non-diag) | ~16 | 11 | — |
| 4 | **Image** | ~13 | 9 | rare |
| 5 | **ThematicBreak** | ~11 | 7 | 1 |
| 6 | **CodeBlock** | ~10 | 6 | 1 |
| 7 | **ListItem** | ~7 | 4 | 6 |
| 8 | **UnorderedList** | ~7 | 5 | 1 |
| 9 | **Table** | ~6 | 0 | 1 |
| 10 | **OrderedList** | ~5 | 3 | 1 |
| 11 | **Paragraph** | ~5 | 3 | 3 |
| 12 | **InlineCode** | ~3 | 0 | 2 |
| 13 | **Link** | ~2 | 0 | 1 |
| 14 | **Emphasis** | ~2 | 0 | 1 |
| 15 | **Strong** | ~2 | 0 | 2 |
| 16–18 | Strikethrough, LineBreak, SoftBreak | 0–2 | 0 | rare |

Text and SoftBreak are **already pure actions**.

### Responsive CSS and Selector Fidelity

**No fidelity loss.** The `.desktop {}`, `.mobile {}` modifiers produce `registerStyle` calls with `atRule` set to the media query string. The capturing context records these as:
```swift
.style(register: "top: -0.5em", atRule: "@media (min-width: 832px)", selector: nil, pseudo: nil)
```

The pure action version produces the identical action directly. Similarly for `.selector("article div:hover > * >") { ... }`. The `Rendering.Action.style` case carries all four CSS context dimensions (declaration, atRule, selector, pseudo).

### Conversion Priority

Given the children replay amplification finding, the conversion must be **all-or-nothing** to realize the full benefit. However, conversion difficulty varies:

| Priority | Element | Difficulty | Notes |
|:--------:|---------|:----------:|-------|
| 1 | ListItem | Low | Simple wrapper + VStack |
| 2 | Paragraph | Low | 3 CSS props |
| 3 | InlineCode | Low | No CSS |
| 4 | Strong | Low | No CSS |
| 5 | Emphasis | Low | No CSS |
| 6 | Strikethrough | Low | No CSS |
| 7 | Link | Low | 1 attribute |
| 8 | LineBreak | Low | Single void element |
| 9 | OrderedList | Low | 3 CSS props |
| 10 | UnorderedList | Low | 5 CSS props |
| 11 | Table | Low | No CSS, already mostly pure in Converter |
| 12 | ThematicBreak | Medium | 7 CSS, static output |
| 13 | CodeBlock | Medium | 6 CSS, 2 attributes |
| 14 | Image | Medium | 5 CSS, VStack layout |
| 15 | Heading | High | 18 CSS, SVG, responsive, selector |
| 16 | BlockQuote | High | 2 paths (diagnostic + styled), SVG icons |
| 17 | Outer wrapper | Medium | ContentDivision + VStack in `Markdown._render` |

**Phase 1** (items 1–11 + 17): 12 elements + outer wrapper. Mechanical. Low risk.
**Phase 2** (items 12–16): 5 complex elements. Requires extracting CSS declaration strings from the view tree.

### Path to Book-Scale Performance

500-section capture: 38.0s debug. Linear extrapolation → 1000 sections ≈ 76s debug.

With all elements + outer wrapper converted to pure actions, the remaining cost would be:
- SwiftMarkdown parsing (scales linearly, ~500ms for 500 sections estimated)
- AST traversal + array appends (cheap, proportional to parsing)
- Single-pass interpretation into HTML context

Conservative estimate: full pipeline ≈ 2–3x parsing time. For 1000 sections → ~2–3s debug, ~1s release. **Target met.**

## Outcome

**Status**: RECOMMENDATION

### Decision

Convert all 16 capture-based default element renderers **plus the outer wrapper** to pure action-producing closures. The critical finding is that children replay amplification makes incremental conversion yield only ~9% per batch — the full benefit requires converting the entire capture chain.

### Rationale

1. **Measured**: 3 pure elements → 9% improvement at full pipeline scale (100 sections: 1.877s → 1.709s)
2. **Measured**: Per-element speedups are 7–36x (paragraph 17.6x, listItem 36.4x, inlineCode 7.0x)
3. **Discovery**: Children replay amplification through the outer wrapper dominates — individual element conversion has diminishing returns until the entire chain is pure
4. No fidelity loss — responsive CSS, selectors, and pseudo-classes fully captured by `Rendering.Action`
5. No architectural changes — the renderer closure signature stays the same
6. Custom user renderers can continue using `capture {}` — only defaults are converted
7. Book-scale target (1000+ sections <5s release) achievable with full conversion

### Implementation Notes

- Each pure action default must produce **byte-identical HTML** to the capture-based version. Verify with snapshot tests.
- The **outer wrapper** in `Markdown._render` should be the FIRST conversion — it eliminates the final capture+replay pass over all content actions.
- The `Markdown.Rendering.Replay` type remains needed for `capture {}` in custom renderers and block directive handlers.
- `DarkModeColor` values used in heading/blockquote CSS need their resolved color strings extracted for pure action defaults.
- Add `reserveCapacity` hints per element type.

### Experiment

See `swift-institute/Experiments/markdown-rendering-performance-profiling/` — test suite using `.timed()` from swift-testing with per-element isolation and full-pipeline comparison.

## References

- `swift-foundations/swift-markdown-html-rendering/` — implementation
- `swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Action.swift` — action enum
- `swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Context.swift` — context + interpret
- `swift-institute/Research/prompts/markdown-action-rendering-performance-optimization.md` — prompt
