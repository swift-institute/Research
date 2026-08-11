# Modifier Dispatch Ordering

<!--
---
version: 1.1.0
last_updated: 2026-05-11
status: RECOMMENDATION
scope: cross-package
tier: 2
---
-->

<!--
Changelog:
  v1.0.0 — 2026-05-11 — Initial A1 dispatch-ordering audit + α₂-flat recommendation.
  v1.1.0 — 2026-05-11 — Additive amendment per Rev-4 path-α extension
                        (`tenthijeboonkkamp/timekeeping` commit `b3e4690`):
                        added § Inventory — PDF Emission Order per Render-Primitive
                        per Tag (A2 axis); added § A1+A2 Cross-Reference +
                        Compliance Analysis; refined Recommendation to address
                        both axes; added R8–R10 RELATED items for A2-induced
                        findings.
-->

## Context

While implementing the W3C_CSS_Backgrounds.Border CSS modifier as part of
Wave-2 sub-wave (a) of the render-parity dispatch
(`HANDOFF-swift-pdf-render-parity.md`), an instrumented commit (`fa112c0`,
subsequently reverted) demonstrated that the modifier never observes the
`PDF.HTML.Context.Table` state it intends to mutate:

```
[DIAG-Border] apply called; context.table = false
[DIAG-Border] apply called; context.table = false
```

Pre-commit cell-border `m/l/S` triple count in the reproducer
(`Experiments/render-parity/Outputs/render-parity.pdf`): **14**.
Post-commit triple count: **14** (zero modifier effect).

The diagnostic pinned the failure to dispatch order in the HTML rendering
pipeline: CSS modifiers attached to an element are dispatched via
`Render.Context.applyInlineStyle` → `PDF.HTML.Context.apply(inlineStyle:)`
*before* `_pushElement(tag, …)` creates the element's contextual state. For
modifiers whose target state is created at push time (notably
`context.table.borderColor` / `borderWidth`), the modifier dispatches against
state that does not yet exist and its guard early-returns without effect.

This audit precedes any architectural pivot. It enumerates every CSS modifier
conformance, every push-time state-read, and every pop-time state-consume,
then classifies each modifier by the *phases* at which its target state is
read. The classification determines whether a uniform "all modifiers fire
post-push" reorder (α₁) suffices, or whether a per-modifier phase declaration
(α₂) is required.

This Research doc was authorized under Rev-3 path-α of the parity dispatch
(user adjudication 2026-05-11: *"we want the architecturally 'best' answer —
always. dont care how long it takes or how much effort it takes."*). It is
read-only — no source edits accompany this commit. The Phase 2 form (α₁ vs
α₂) decision is gated on this doc's recommendation plus user adjudication.

### Prior research

Prior-research grep across `swift-foundations/swift-pdf-html-render/Research/`,
`swift-foundations/swift-html-render/Research/`, and
`~/.claude/projects/-Users-coen-Developer/memory/feedback_*.md` (queries:
"modifier.*dispatch", "pre-push", "post-push", "pushElement",
"inline-style.*order", "render.*pipeline", "css.*order") returned **0 hits in
all targets**. Greenfield analysis; no cite-and-extend per `[HANDOFF-013a]`.

## Question

> Given the empirical finding that CSS modifiers dispatched at
> `apply(inlineStyle:)` cannot observe element-context state created at
> `_pushElement(tag, …)`, what dispatch shape allows every modifier to
> mutate state at the phase its target state is actually consumed?

The Rev-4 path-α extension widens this question to a second axis (added
in doc v1.1.0):

> Independently of *when* CSS modifiers run, *when* are PDF
> render-primitives (`Tj` text, stroke/fill ops, line operators) emitted
> to the content stream, and does that emission order satisfy CSS painting
> order (§E.2, §17.6)?

The two axes are referred to as **A1 (dispatch ordering)** and **A2
(emission ordering)** below. The original Question and Inventory sections
address A1; the new § Inventory — PDF Emission Order and § A1+A2
Cross-Reference + Compliance Analysis address A2 and confirm orthogonality.

Concretely (A1):

- **α₁** — *All modifiers fire post-push uniformly*. The pipeline applies the
  CSS modifier dispatch site after `_pushElement` instead of before.
  Sufficient if and only if no modifier requires its effect to be observed by
  `_pushElement` itself (the push code's READ-set).
- **α₂** — *Per-modifier phase declaration*. The `Modifier` protocol carries
  a `var phase: Phase { get }` (or equivalent) and the pipeline dispatches
  each modifier at its declared phase. Required if any modifier's
  target-state is read at multiple phases or if some modifiers must fire
  pre-push while others must fire post-push.

The α₁-vs-α₂ test reduces to: *does any modifier have a phase-set whose
elements would not all be satisfied by a single uniform dispatch site?*

## Inventory — Modifiers

Forty-six CSS modifier files exist under
`swift-foundations/swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/`.
Conformance split (verified by `grep -l`): 42 conform to
`PDF.HTML.Style.Modifier` (operates on `PDF.Context` via
`apply(to: inout PDF.Context, configuration:)`), 4 conform to
`PDF.HTML.Style.Context.Modifier` (operates on
`PDF.HTML.Context` via `apply(to: inout PDF.HTML.Context)`).
Twenty-two carry stub bodies (`// TODO: Apply …`); twenty-four have
implemented bodies.

Each row records: file (basename), conformance, implementation status,
state-mutated (or stubbed-target-intent), and phase set. Phase sets are
{`pre-push`, `post-push_layout`, `post-push_render`, `pop-consumed`,
`apply-time-immediate`}; see § Phase Classification for the full taxonomy.

| # | File | Conformance | Status | Mutates state | Phase(s) | Notes |
|---|------|-------------|--------|---------------|----------|-------|
| 1 | `BackgroundColor` | Style.Modifier | IMPL | `pdf.style.textMarkup` | post-push_render | Highlight markup consumed at text emission |
| 2 | `Border` | Style.Modifier | STUB | intended: `context.table.borderColor` / `.borderWidth` (table) or `pdf.style.border` (block, deferred-G) | post-push_layout | Reproducer-confirmed: dispatched pre-push when target table context does not yet exist |
| 3 | `BorderCollapse` | Style.Modifier | STUB | intended: table cell border merge semantic — `context.table.X` | post-push_layout | Same shape as Border family |
| 4 | `BorderColor` | Style.Modifier | STUB | intended: `context.table.borderColor` | post-push_layout | Sub-wave (a) commit 4 |
| 5 | `BorderRadius` | Style.Modifier | STUB | intended: per-block rounding — `pdf.style.borderRadius` field (TBD) | post-push_render | No table-context dependency |
| 6 | `BorderSpacing` | Style.Modifier | STUB | intended: table cell spacing — read at `_pushElement("table",…)` for cell-padding calc | pre-push | Affects column-width geometry |
| 7 | `BorderStyle` | Style.Modifier | STUB | intended: solid/dashed/none → effective borderWidth | post-push_layout | Sub-wave (a) commit 2 |
| 8 | `BorderWidth` | Style.Modifier | STUB | intended: `context.table.borderWidth` | post-push_layout | Sub-wave (a) commit 3 |
| 9 | `Height` | Style.Modifier | IMPL | `pdf.constraint.height` | pre-push | Read by `applyBoxModel` → `pdf.layout.box.urx` (transitively) |
| 10 | `Margin` | Style.Modifier | IMPL | `pdf.margin.{top,right,bottom,left}` | pre-push (top/left/right) + pop-consumed (bottom) | `applyBoxModel` consumes top/left/right; `_popStyle` consumes bottom |
| 11 | `MarginBottom` | Style.Modifier | IMPL | `pdf.margin.bottom` | pop-consumed | Read in `_popStyle` at line 480 |
| 12 | `MarginLeft` | Style.Modifier | IMPL | `pdf.margin.left` | pre-push | `applyBoxModel` shifts `pdf.layout.box.llx` |
| 13 | `MarginRight` | Style.Modifier | IMPL | `pdf.margin.right` | pre-push | `applyBoxModel` shifts `pdf.layout.box.urx` |
| 14 | `MarginTop` | Style.Modifier | IMPL | `pdf.margin.top` | pre-push | `applyBoxModel` issues `pdf.advance` |
| 15 | `MaxHeight` | Style.Modifier | STUB | intended: max-height constraint | pre-push | Layout-engine consumer |
| 16 | `MaxWidth` | Style.Modifier | STUB | intended: max-width constraint — read at `_pushElement("table",…)` for `availableWidth` | pre-push | Wave-2 sub-wave (b) target |
| 17 | `MinHeight` | Style.Modifier | STUB | intended: min-height constraint | pre-push | Layout-engine consumer |
| 18 | `MinWidth` | Style.Modifier | STUB | intended: min-width constraint | pre-push | Wave-2 sub-wave (b) target |
| 19 | `Padding` | Style.Modifier | IMPL | `pdf.padding.{top,right,bottom,left}` | pre-push (top/left/right) + pop-consumed (bottom) | Same split as Margin |
| 20 | `PaddingBottom` | Style.Modifier | IMPL | `pdf.padding.bottom` | pop-consumed | Read in `_popStyle` at line 477 |
| 21 | `PaddingLeft` | Style.Modifier | IMPL | `pdf.padding.left` | pre-push | `applyBoxModel` shifts `pdf.layout.box.llx` |
| 22 | `PaddingRight` | Style.Modifier | IMPL | `pdf.padding.right` | pre-push | `applyBoxModel` shifts `pdf.layout.box.urx` |
| 23 | `PaddingTop` | Style.Modifier | IMPL | `pdf.padding.top` | pre-push | `applyBoxModel` issues `pdf.advance` |
| 24 | `Width` | Style.Modifier | IMPL | `pdf.constraint.width` | pre-push | `applyBoxModel` clamps `pdf.layout.box.urx` |
| 25 | `Color` | Style.Modifier | IMPL | `pdf.style.color` | post-push_render | Read at text-run construction (e.g. line 830, 848) |
| 26 | `Display` | Style.Modifier | STUB | intended: block/inline/flex/grid layout mode | pre-push | Affects `_pushElement`'s flow decisions |
| 27 | `FontSize` | Style.Modifier | IMPL | `pdf.style.fontSize` | pre-push + post-push_render | Read at `_pushElement("table",…)` line 577 (line.height calc), line 611 (tr row height), line 720 (`li` marker width); also read during text rendering |
| 28 | `FontStyle` | Style.Modifier | IMPL | `pdf.style.font` (`.italic`) | pre-push + post-push_render | Read at `_pushElement("li",…)` line 724 for marker font; also read at text rendering |
| 29 | `FontWeight` | Style.Modifier | IMPL | `pdf.style.font` (`.bold`) | pre-push + post-push_render | Read at `_pushElement("li",…)` for marker font; also read at text rendering |
| 30 | `ListStylePosition` | Style.Modifier | STUB | intended: marker positioning | pre-push | Read at `_pushElement("li",…)` marker placement |
| 31 | `ListStyleType` | Style.Modifier | STUB | intended: marker disc/circle/square/decimal | pre-push | Read at `_pushElement("li",…)` `nextListMarker()` |
| 32 | `Multicolumn.BreakAfter` | **Style.Context.Modifier** | IMPL | `context.avoidPageBreakAfter` / `forcePageBreakAfter` | pop-consumed | Flag consumed at `_popStyle` line 485 |
| 33 | `Multicolumn.BreakBefore` | Style.Modifier | IMPL | `pdf.page.new()` (immediate) | apply-time-immediate | Side-effect fires during `apply(inlineStyle:)` itself |
| 34 | `Multicolumn.BreakInside` | **Style.Context.Modifier** | IMPL | `context.avoidPageBreakInside` | pop-consumed | Flag consumed at `_popStyle` |
| 35 | `Paged.Orphans` | Style.Modifier | STUB | intended: minimum-lines-at-bottom for pagination | post-push_layout | Pagination heuristic |
| 36 | `Paged.PageBreakAfter` | **Style.Context.Modifier** | IMPL | `context.avoidPageBreakAfter` / `forcePageBreakAfter` | pop-consumed | Flag consumed at `_popStyle` line 485 |
| 37 | `Paged.PageBreakBefore` | Style.Modifier | IMPL | `pdf.page.new()` (immediate) | apply-time-immediate | Mirror of `Multicolumn.BreakBefore` |
| 38 | `Paged.PageBreakInside` | **Style.Context.Modifier** | IMPL | `context.avoidPageBreakInside` | pop-consumed | Mirror of `Multicolumn.BreakInside` |
| 39 | `Paged.Widows` | Style.Modifier | STUB | intended: minimum-lines-at-top for pagination | post-push_layout | Pagination heuristic |
| 40 | `Text.LetterSpacing` | Style.Modifier | STUB | intended: inter-glyph spacing | post-push_render | Text-rendering consumer |
| 41 | `Text.LineHeight` | Style.Modifier | STUB | intended: `pdf.style.line.height` | pre-push + post-push_render | Read at `_pushElement("table",…)` line 577, `_pushElement("tr",…)` line 611; also read during text vertical advance |
| 42 | `Text.TextAlign` | Style.Modifier | IMPL | `pdf.style.textAlign` | post-push_render + pop-consumed (cell alignment) | `popTableCell` reads alignment at line 1049 |
| 43 | `Text.TextIndent` | Style.Modifier | STUB | intended: first-line indent | post-push_render | Text-rendering consumer |
| 44 | `Text.TextTransform` | Style.Modifier | STUB | intended: uppercase/lowercase/capitalize | post-push_render | Text-rendering consumer |
| 45 | `Text.WhiteSpace` | Style.Modifier | STUB | intended: `pdf.mode.preserveWhitespace` | pre-push | Saved at line 351 in `Element.Scope`, used by tokenizer; affects `_pushElement` saved-state capture |
| 46 | `Text.WordSpacing` | Style.Modifier | STUB | intended: inter-word spacing | post-push_render | Text-rendering consumer |

**Counts**: 46 total · 22 STUB / 24 IMPL · 42 Style.Modifier / 4
Style.Context.Modifier. (Matches Wave-1 verification.)

Phase-distribution headline: 18 pre-push-only · 7 post-push_render-only · 6
post-push_layout-only (Border family + Orphans/Widows) · 6 pop-consumed-only ·
2 apply-time-immediate (Break/PageBreak Before) · **7 multi-phase**: Margin,
Padding (top/left/right + bottom pop-consumed), FontSize, FontStyle,
FontWeight, LineHeight (pre-push + post-push_render), TextAlign
(post-push_render + cell-pop-consumed).

## Inventory — `_pushElement` READs (per tag)

Source: `PDF.HTML.Context+Rendering.swift` lines 314–423 (generic `_pushElement`),
500–530 (`applyBoxModel`), 532–561 (`handleVoidElement`), 565–739
(`pushBlockElement`), 820–836 (`pushInlineElement`),
859–879 (`pushHeading`), and `HTML.Element.Tag+TagStyle.swift` lines 9–95
(`applyTagStyle`).

`applyBoxModel` is invoked from `apply(inlineStyle:)` at line 185 *before*
`_pushElement` runs — so its READ-set defines pre-push state that any margin/
padding/width modifier must have populated by then.

| Tag | Reads at push time |
|-----|-------------------|
| (all) — `_pushElement` generic head | `pdf.style` (scope save), `pdf.layout.box.{llx,urx}`, `pdf.mode.preserveWhitespace`, `link.currentURL`, `link.currentInternalId`, `pendingBottomMargin`, `attributes["href"]`, `attributes["id"]`, `pdf.completedPages.count`, `pdf.layout.box.lly` |
| (block) — block-margin pass (line 388–410) | `pdf.list.depth` (nested-list test), `configuration.headingMarginEm` (for h1-h6), `pdf.style.fontSize` (em→pt) |
| (all) — `applyBoxModel` (called pre-push) | `pdf.margin.{top,left,right}`, `pdf.padding.{top,left,right}`, `pdf.constraint.width` |
| `br` (void) | `pdf` inline runs flush; `pdf.advance.line()` |
| `hr` (void) | `configuration.defaultFontSize`, `configuration.horizontalGapEm`, `pdf.layout.box.{llx,urx,lly}` |
| `table` | `pdf.layout.box.{lly,width,llx}`, `pdf.style.line.height`, `configuration.table.cell.padding`, `configuration.table.border.color`, `configuration.table.border.width`, `configuration.table.headerBackground`, `configuration.table.alternatingRowColor` |
| `thead` | `context.table` (existence) |
| `tbody`, `tfoot` | (pass-through) |
| `tr` | `context.table`, `pdf.style.line.height`, `tableCtx.cell.padding`, `pdf.page.exceeds(adding:)`, `pdf.layout.box.lly`, `tableCtx.bounds.{llx,width}`, `tableCtx.totalRowsRendered`, `tableCtx.currentFragmentStartY/EndY`, `tableCtx.columnsInitialized` |
| `td`, `th` | `context.table.{columnsInitialized,currentColumn,columnCount,spans}`, `attributes["colspan"]`, `attributes["rowspan"]`, `tableCtx.xForColumn`, `tableCtx.widthForColumns`, `tableCtx.cell.padding`, `tableCtx.bounds.{lly,height}`; if `th`: writes `pdf.style.font = .bold` |
| `ol`, `ul` | `configuration.indent.list`, `pdf.layout.box.llx`, `pendingBottomMargin`, `elementStack.last` |
| `li` | `pdf.nextListMarker()` (reads marker state), `pdf.style.fontSize`, `pdf.style.font.winAnsi`, `configuration.horizontalGapEm`, `pdf.layout.box.llx`; writes `pdf.list.marker` |
| `applyTagStyle` (called pre-`pushBlockElement` at line 360) | per-tag: writes `pdf.style.font`, `pdf.style.fontSize`, `pdf.style.textMarkup`, `pdf.style.color`, `pdf.style.verticalOffset`, `pdf.mode.preserveWhitespace`, `pdf.layout.box.{llx,urx}`. Reads `configuration.headingSize`, `configuration.typography.{subscriptScale,subscriptOffset,superscriptScale,superscriptOffset,smallScale}`, `configuration.indent.{blockquote,figure}` |
| `pushHeading` (h1–h6) | `configuration.headingSize`, `pdf.style.lineHeight`, `pdf.page.ensure(height:)`, `pdf.completedPages.count`, `pdf.layout.box.lly` |
| inline `q` (in `pushInlineElement` line 820) | `pdf.style.{font,fontSize,color,textMarkup,verticalOffset}` |

Generalization: pre-push READs concentrate on `pdf.layout.box.*`,
`pdf.style.*` (line height, font, fontSize, color via `applyTagStyle`'s own
writes), `pdf.margin/padding` (via `applyBoxModel`), `pdf.constraint.width`,
and table configuration defaults (`configuration.table.*`). Any modifier
mutating one of these has a pre-push phase entry.

## Inventory — `_popElement` CONSUMES (per tag)

Source: `PDF.HTML.Context+Rendering.swift` lines 425–460 (generic `_popElement`),
473–498 (`_popStyle`), 740–798 (`popBlockElement`), 838–854 (`popInlineElement`),
975–1037 (`popTableRow`), 1039–1075 (`popTableCell`).

| Tag / pop site | Consumes at pop time |
|----------------|----------------------|
| (all) — `_popElement` generic | `elementStack.last` (`Element.Scope`); restores `pdf.style`, `pdf.layout.box.{llx,urx}`, `pdf.mode.preserveWhitespace`, `link.{currentURL,currentInternalId}` from scope |
| (all) — `_popStyle` | `pdf.padding.bottom`, `pdf.margin.bottom`, `context.forcePageBreakAfter`, `context.avoidPageBreakAfter`, `context.avoidPageBreakInside`, `styleScopeStack.last` (Style.Snapshot) |
| `table` | `context.table`, `configuration.{defaultFontSize,horizontalGapEm}`, `scope.savedTable`. Calls `drawTableRightAndBottomBorders` which reads `tableCtx.{borderColor,borderWidth,bounds,currentFragmentStartY/EndY,columnWidths}` |
| `thead` | `context.table`, writes `tc.header.rowHeight = tc.rowHeights[0]` |
| `tbody`, `tfoot` | (pass-through) |
| `tr` → `popTableRow` | `context.table.{maxCellHeightInCurrentRow,bounds.lly,cell.padding,pdf.style.line.height,pendingCellBorders,xForColumn,widthForColumns,spans,totalRowsRendered,borderColor,borderWidth,header.{rows,rowHeight,…},rowHeights,bounds,currentFragmentEndY}`; calls `drawCellBorder` per pending cell — reads `tableCtx.{borderColor,borderWidth}` |
| `td`, `th` → `popTableCell` | `pdf.inline.hasRuns`, `attributes["colspan"]`, `attributes["rowspan"]`, **`pdf.style.textAlign`** (line 1049), `context.table.{bounds.lly,cell.padding}`, writes `tc.{maxCellHeightInCurrentRow,pendingCellBorders,currentColumn}` |
| `ol`, `ul` | `pdf.inline.hasRuns`, `pdf.list.stack`, `scope.savedPendingMargin` |
| `li` | `pdf.inline.hasRuns`, writes `pdf.list.marker = nil` |
| inline `q` | `pdf.style.{font,fontSize,color,textMarkup,verticalOffset}` |
| `pushHeading` finalize (in `popBlockElement` block) | `section.activeHeading`, generates outline bookmark |

Key pop-time consumers: `pdf.padding.bottom`, `pdf.margin.bottom` (from
`_popStyle`); `pdf.style.textAlign` (from `popTableCell`); the three page-break
flags (from `_popStyle`); `tableCtx.{borderColor,borderWidth}` (from cell-
border draw routine and `drawTableRightAndBottomBorders`).

## Inventory — PDF Emission Order per Render-Primitive per Tag

### A2 axis preamble

The user's "are we respecting BOTH PDF and CSS drawing order?" question
identifies a second axis orthogonal to A1 (modifier-dispatch timing): A2 is
the *emission order* of PDF content-stream operators. A1 governs when
modifier `apply` bodies *mutate state*; A2 governs when render-primitives
(`Tj` text, `m`/`l`/`S` stroke triples, `re`/`f` fill rectangles, line
operators for separators, etc.) are *emitted into the PDF content stream*.

PDF content-stream semantics are painter-style: later operators paint over
earlier operators. CSS painting order (§E.2, §17.6) specifies the inverse
constraint on rendering — backgrounds first, borders next, content on top.
Producing CSS-compliant output therefore requires the PDF emission order to
match the CSS painting order per element.

This inventory enumerates every render-primitive currently emitted to the
content stream by this package, records the pipeline phase at which it is
emitted, and cross-references against the CSS painting-order rules in
§ A1+A2 Cross-Reference + Compliance Analysis below.

### Per render-primitive emission sites

Source: `PDF.HTML.Context+Rendering.swift`, `HTML.Element.Tag+TableBorders.swift`,
`PDF.HTML.Context+Interpret.swift` (text + inline media), plus header/footer
two-pass rendering (out of scope for the present table-and-block analysis).

| # | Render-primitive | Definition site | Call site | Emission phase | Notes |
|---|------------------|-----------------|-----------|----------------|-------|
| E1 | Cell border (left+top edges) | `HTML.Element.Tag+TableBorders.swift:12-36` (`drawCellBorder`) | `PDF.HTML.Context+Rendering.swift:1000` (`popTableRow`) | **row-end deferred** | All cell-border `m/l/S` triples emitted AFTER all cells in the row have rendered their content. Border-collapse model: each cell draws left+top. |
| E2 | Cell rowspan border extension | `pdf.emit.line` inline | `PDF.HTML.Context+Rendering.swift:1016-1021` (`popTableRow`) | **row-end deferred** | Left-border extension for cells with active rowspan from previous rows. Same row-end timing as E1. |
| E3 | Table outer right+bottom border | `HTML.Element.Tag+TableBorders.swift:75-85` (`drawTableRightAndBottomBorders`) | `PDF.HTML.Context+Rendering.swift:750` (`popBlockElement` "table") | **table-end deferred** | After all row-end emissions for the table. Right edge spans `currentFragmentStartY → currentFragmentEndY`; bottom edge spans `tableBounds.llx → tableBounds.urx`. |
| E4 | Fragment right+bottom border (multi-page) | `HTML.Element.Tag+TableBorders.swift:43-71` (`drawFragmentRightAndBottomBorders`) | `PDF.HTML.Context+Rendering.swift:617-622` (in `pushBlockElement` "tr" before page break) | **pre-page-break deferred** | Mirrors E3 but per-page-fragment. Fires when a new `<tr>` push detects page overflow; closes the fragment on the current page. |
| E5 | Cell background fill | `HTML.Element.Tag+TableBorders.swift:88-102` (`drawCellBackground`) | **NONE** — defined but never called | **N/A (dead code)** | The function exists with `pdf.emit.rectangle(bounds, fill: color, stroke: nil)`; **zero call sites** in the entire codebase (grep verified). Per CSS 2.1 §17.6.1 the cell-background paint is required between cell-background and cell-border, ordering background under border. Currently the table model emits no backgrounds whatsoever. |
| E6 | Cell text content (`Tj`/`TJ`) | `pdf.append(inline:)` via `text(...)` etc. | During `<td>`/`<th>` body rendering, between `_pushElement("td"/"th",…)` and `_popElement` | **content-time (in-cell, pre-pop)** | The first row is recorded via `Table.Recording` and replayed after column-width finalization at line 907 — its emission is *replayed* at content-time but is *captured at apply-time during the first row*. Subsequent rows emit synchronously. |
| E7 | Block-element text content (`Tj`/`TJ`) | `pdf.append(inline:)` | During the owning element's body between push and pop | **content-time** | No special phase: text emission is inline with the rendering flow. |
| E8 | Inline element open/close glyphs (`<q>` curly quotes) | `pdf.append(inline:)` at `pushInlineElement`/`popInlineElement` | `PDF.HTML.Context+Rendering.swift:820-854` | **push-time (open) / pop-time (close)** | E.g., U+201C and U+201D quote-mark glyphs appended at element push and pop respectively. |
| E9 | List marker glyph | Set in `pdf.list.marker` at `_pushElement("li",…)` line 720-734; *emitted* in `pdf.flush.inline()` at next inline flush | `PDF.HTML.Context+Rendering.swift:719-734` (assignment) + `pdf.flush.inline()` (emission) | **push-time (assignment) → first-inline-flush (emission)** | Marker is staged at push; actual `Tj` for the glyph fires when the first inline run is flushed. Marker cleared at `_popElement("li",…)` line 792. |
| E10 | Thematic break (`<hr>`) line | `pdf.emit.line` | `PDF.HTML.Context+Rendering.swift:550-555` (`handleVoidElement` "hr") | **apply-time of `<hr>` void element** | Single stroke line at current `pdf.layout.box.lly`; `<hr>` is a void element so no push/pop pair. |
| E11 | Thematic break (markdown rule via `thematicBreak()`) | `pdf.emit.line` | `PDF.HTML.Context+Rendering.swift:71-76` | **call-time** | Distinct entry point from E10; same primitive shape. |
| E12 | Hyperlink underline / strike-through / highlight | `pdf.style.textMarkup` → emitted at text-run construction via `textDecoration:` parameter | `PDF.HTML.Context+Rendering.swift:829-832, 847-850` and similar | **content-time inline-with-text** | The markup is *part of the text-run record*; it's a property of the `Tj` operator emission, not a separate stroke. Underlines are emitted as a line below the baseline as part of the run; the renderer composes them with the text. |
| E13 | Image (`<img>`) | `pdf.append(inline:)` with image-style run | `PDF.HTML.Context+Interpret.swift:image(source:alt:)` | **content-time inline** | Currently the `image(...)` body emits a placeholder text run (`[image]` or `[\(alt)]`), not actual image data. Real image XObject support is a separate concern. |
| E14 | Page-break trigger | `pdf.page.new()` | Multiple sites: `apply(inlineStyle:)` for `BreakBefore`/`PageBreakBefore` (apply-time-immediate); `pushBlockElement` "tr" line 626 (when row overflows); `_popStyle` line 487 (when `forcePageBreakAfter` set) | **mixed: apply-time / push-time / pop-time** | Page transitions are control-flow, not a paint primitive per se, but the page-new emission flushes accumulated content and starts a new content stream. |

### Per-cell painting-order snapshot (current behaviour)

For a non-first row of a typical `<tr>` containing two `<td>` cells:

```
Sequence emitted to content stream:
  ┌─────────────────────────────────────────────────────────────┐
  │ <tr> push                                                   │
  │   ├─ <td 1> push (saves layout box for cell 1's content)    │
  │   │   ├─ E6: cell 1 text content (Tj operators)             │
  │   │   └─ <td 1> pop (popTableCell — records pending border) │
  │   ├─ <td 2> push (saves layout box for cell 2's content)    │
  │   │   ├─ E6: cell 2 text content (Tj operators)             │
  │   │   └─ <td 2> pop (popTableCell — records pending border) │
  │   └─ <tr> pop (popTableRow)                                 │
  │       ├─ E1: drawCellBorder × 2 (cell 1 + cell 2 borders)   │
  │       │   ↳ EMITTED AFTER both cells' text content          │
  │       └─ E2: rowspan border extensions (none here)          │
  └─────────────────────────────────────────────────────────────┘

Cell background (E5): NEVER emitted (dead function).
Table outer borders (E3): emitted at <table> pop, after the last row's E1/E2.
```

In PDF content-stream order: **text-content first, borders last**. Painter
semantics: each later operator paints over earlier ones. Borders therefore
paint ON TOP of cell content. This is the inverse of CSS painting order.

The defect is **latent today** because cell content is inset by
`tableCtx.cell.padding` (line 678-685 of `_pushElement("td"/"th",…)`), so the
border rectangle does not visually overlap with the text. But the defect is
real: if `padding == 0` or if the cell border has alpha < 1, content
clipping would be visible.

For cell backgrounds: not emitted at all today, so no painting-order issue
yet. As soon as cell backgrounds land (sub-wave (b) candidate), the
emission-order question becomes load-bearing.

## Phase Classification

### Definitions

| Phase | Definition |
|-------|-----------|
| **pre-push** | The modifier's target state is read by `_pushElement(tag,…)` or by `applyBoxModel` (invoked pre-push). For correctness the modifier must fire before push. |
| **post-push_layout** | The modifier's target state is created by `_pushElement` (e.g., `context.table` initialized at push). The modifier must fire after push for its write to land somewhere other than `nil`. |
| **post-push_render** | The modifier's target state is read during child-content rendering inside the element. Either pre-push or post-push fires correctly — render-time reads see whichever value persisted. |
| **pop-consumed** | The modifier's target state is read at `_popElement` or `_popStyle`. Either pre-push or post-push fires correctly — pop reads whichever value was last written before pop. |
| **apply-time-immediate** | The modifier's `apply` body issues an immediate side-effect (`pdf.page.new()`). Phase is "wherever `apply` runs" — the side-effect is bound to call timing, not to a state-read site. |

A modifier's **phase-set** is the union of phases at which any of the state
it writes is consumed.

### Per-modifier phase sets

Single-phase modifiers (38 of 46):

- **pre-push only** (16): Height, MaxHeight, MaxWidth, MinHeight, MinWidth,
  MarginLeft, MarginRight, MarginTop, PaddingLeft, PaddingRight, PaddingTop,
  Width, Display, BorderSpacing, ListStylePosition, ListStyleType, WhiteSpace
  — *17 if we count single-side margin/padding pre-push effects but the
  shorthand (Margin, Padding) is multi-phase due to bottom-side pop-consumed
  semantics.*
- **post-push_layout only** (6): Border, BorderCollapse, BorderColor,
  BorderStyle, BorderWidth, Orphans/Widows (pagination heuristics targeting
  layout)
- **post-push_render only** (8): BackgroundColor, BorderRadius, Color,
  LetterSpacing, TextIndent, TextTransform, WordSpacing, (TextAlign is
  multi-phase due to popTableCell)
- **pop-consumed only** (5): MarginBottom, PaddingBottom,
  Multicolumn.BreakAfter, Multicolumn.BreakInside, Paged.PageBreakAfter,
  Paged.PageBreakInside (six if we split the two protocol families; the flag
  state is the same)
- **apply-time-immediate only** (2): Multicolumn.BreakBefore,
  Paged.PageBreakBefore

Multi-phase modifiers (7 of 46):

| Modifier | Phase set | Why multi-phase |
|----------|-----------|-----------------|
| `Margin` (shorthand) | {pre-push, pop-consumed} | top/left/right consumed by `applyBoxModel` pre-push; bottom consumed by `_popStyle` |
| `Padding` (shorthand) | {pre-push, pop-consumed} | Same split as Margin |
| `FontSize` | {pre-push, post-push_render} | `pdf.style.fontSize` read by `_pushElement` for `table`/`tr`/`li` height/marker calcs AND read during text rendering |
| `FontStyle` | {pre-push, post-push_render} | `pdf.style.font` read at `_pushElement("li",…)` for marker font width AND read at text-run construction |
| `FontWeight` | {pre-push, post-push_render} | Same as FontStyle |
| `LineHeight` (stubbed-intent) | {pre-push, post-push_render} | `pdf.style.line.height` read at `_pushElement("table",…)` line 577 and `("tr",…)` line 611 AND read during text vertical advance |
| `TextAlign` | {post-push_render, pop-consumed} | Render-time text positioning AND `popTableCell` reads alignment for pendingCellBorder record (line 1049) |

For the Margin/Padding shorthand modifiers, the multi-phase nature is
*self-induced*: the shorthand sets all four sides, and the bottom-side
pop-consumer reads the bottom field that the shorthand wrote pre-push. The
write itself happens at apply-time; the *reads* span phases. Pre-push
dispatch satisfies this case (the bottom value persists from write-time
through pop-time).

## α₁ vs α₂ Analysis

### Restating the test

α₁ (uniform post-push reorder) succeeds if and only if, for every modifier in
the inventory, post-push dispatch satisfies every phase in the modifier's
phase-set.

- **post-push_layout** modifiers: satisfied (post-push dispatch makes
  `context.table` exist when the modifier runs).
- **post-push_render** modifiers: satisfied (write happens before child
  rendering reads).
- **pop-consumed** modifiers: satisfied (post-push write persists until pop).
- **apply-time-immediate** modifiers: satisfied if `apply` runs at all
  (BreakBefore's `pdf.page.new()` is order-sensitive only if it must happen
  *before* the element's content begins rendering; post-push dispatch is
  still before content rendering, so satisfied).
- **pre-push** modifiers: **NOT satisfied** — by definition, their target
  state is read *during* `_pushElement` itself. Post-push dispatch means the
  modifier writes after the push has already computed using the *old* value.

Concrete pre-push modifiers that break under α₁:

- `Margin` / `MarginTop` / `MarginLeft` / `MarginRight` / `Padding` /
  `PaddingTop` / `PaddingLeft` / `PaddingRight` — `applyBoxModel`'s shifts to
  `pdf.layout.box.{llx,urx}` and its `pdf.advance(marginTop|paddingTop)` must
  happen pre-push so the push reads the shifted box. Under α₁ the box is
  unshifted when `_pushElement("table",…)` captures
  `availableWidth = pdf.layout.box.width` at line 575 — table width is wrong.
- `Width` / `Height` / `MaxWidth` / `MinWidth` (when implemented) —
  `applyBoxModel` clamps `pdf.layout.box.urx` from `pdf.constraint.width`;
  same break shape.
- `FontSize` (pre-push phase) — `_pushElement("table",…)` line 577 computes
  `defaultRowHeight = pdf.style.line.height + cellPadding.height * 2` and
  `_pushElement("tr",…)` line 611 reads `pdf.style.line.height` for
  `rowHeight`. Under α₁ both reads see the parent's fontSize, not the element's.
- `FontStyle` / `FontWeight` (pre-push phase) — `_pushElement("li",…)` line
  724 reads `pdf.style.font.winAnsi.width(...)` for marker width. Under α₁
  the marker is sized against the parent's font, not the `<li>` element's.
- `LineHeight` (when implemented) — same as FontSize.
- `Display` (when implemented) — affects whether the element is treated as
  block/inline at push time. Under α₁ the wrong push-path is selected.
- `WhiteSpace` (when implemented) — saved at line 351 in `Element.Scope`.
  Under α₁ the scope captures the parent's value.
- `BorderSpacing` (when implemented) — read at table push for cell-padding
  calculation. Under α₁ wrong padding is computed.
- `ListStyleType` / `ListStylePosition` (when implemented) — read at
  `_pushElement("li",…)` for marker selection. Under α₁ wrong marker.

**Verdict**: α₁ breaks at least 14 modifier types (counting shorthands and
stubbed intents). It is *not* a viable dispatch model.

## A1+A2 Cross-Reference + Compliance Analysis

### Painting-order specification

CSS 2.1 §E.2 (visual formatting model painting order) specifies the order
in which an element's render-primitives must be painted, for stacking
context purposes:

1. Background of the root element / element forming the stacking context
2. Descendant blocks in the normal flow, in tree order:
   - Background color
   - Background image(s)
   - Border
3. Descendant non-positioned floats
4. Descendant inline-level non-positioned content
5. Outlines
6. Descendant positioned content with stacking context

The relevant invariant for this audit: **background, then border, then
descendant content** (within a non-positioned non-floating block).

For tables specifically, CSS 2.1 §17.6 ("Borders") and §17.6.1 ("Separated
borders model") /§17.6.2 ("Collapsing border model") specify per-cell
painting order:

- Separated model (`border-collapse: separate`): each cell paints its own
  background, then its own border, in tree order. Cell content paints on
  top.
- Collapsing model (`border-collapse: collapse`, the institute renderer's
  effective mode): borders are shared and painted in tree order at table-,
  row-group-, row-, column-group-, column-, and cell-level. Backgrounds
  paint behind borders. Cell content paints on top.

### Per-primitive compliance scan

For each render-primitive in § Inventory — PDF Emission Order, the
compliance status is determined by whether its emission phase produces a
content-stream sequence that satisfies the CSS painting order.

| Primitive | Current emission phase | Required by CSS painting order | Compliance | Severity |
|-----------|------------------------|-------------------------------|------------|----------|
| E1 (cell border) | row-end deferred — AFTER cell content | Cell content must paint OVER cell border (§E.2 step 2 + §17.6) — border under content | **NON-COMPLIANT** | Latent (current cell padding insets content; visible if `padding == 0` or border `alpha < 1`) |
| E2 (rowspan border extension) | row-end deferred — AFTER spanned-cells' content | Same as E1 | **NON-COMPLIANT** | Latent (mirror of E1) |
| E3 (table outer right/bottom border) | table-end deferred — AFTER all rows' content | Painted at table-level in tree order per §17.6; OK if before next descendant. Since table is last-flushed before `<table>` pop, no later descendants exist in the current implementation. | **COMPLIANT** | None |
| E4 (fragment right/bottom border, multi-page) | pre-page-break deferred | Painted at fragment boundary; no later content on this page | **COMPLIANT** | None |
| E5 (cell background fill) | NOT emitted (dead function) | Required to paint behind cell content under §17.6 | **MISSING** | High (architectural gap; once cell backgrounds are wired up, MUST be emitted *before* content) |
| E6 (cell text content `Tj`/`TJ`) | content-time, after cell push, before cell pop | Painted on top of cell background + cell border | **COMPLIANT relative to E1/E2** but only because E1/E2 fire LATER. Actually: content fires FIRST, borders fire SECOND. PDF painter semantics paint borders ON TOP. So the *real* order is: cell content → cell border. Inverse of CSS. | **NON-COMPLIANT** (the same finding as E1/E2 from the other direction) |
| E7 (block-element text) | content-time, inline | No block-level background/border emission today; trivially compliant | **N/A (no block paints yet)** | None |
| E8 (`<q>` curly quotes) | push-time / pop-time | Text glyphs; no painting-order interaction | **COMPLIANT** | None |
| E9 (list marker) | push-time (assignment) → flush-time (emission) | Marker is text glyph painted with cell content; no painting-order interaction with backgrounds/borders today | **COMPLIANT** | None |
| E10 (`<hr>` line) | apply-time of void element | Stroke line, no background interaction | **COMPLIANT** | None |
| E11 (`thematicBreak()` line) | call-time | Same as E10 | **COMPLIANT** | None |
| E12 (textMarkup underline/strike/highlight) | content-time inline-with-text | Decoration is part of the text run; PDF emission composes it with the `Tj` op | **COMPLIANT** | None |
| E13 (image placeholder) | content-time inline | Placeholder text run, no painting-order interaction today | **COMPLIANT** | None |
| E14 (page break) | mixed | Control-flow, not a paint primitive | **N/A** | None |

**Compliance headline**: of the 14 render-primitives, **2 non-compliant**
(E1 + E2, both cell borders, latent due to padding inset) and **1 missing**
(E5 cell background, dead function never wired up). The non-compliance is
**latent today** — the reproducer's defect class is dispatch-side (A1), not
emission-side (A2). But the A2 architectural gap exists and will surface as
soon as either (a) cell backgrounds are implemented, or (b) any block-level
border/background landing forces the same ordering question for non-table
elements.

### A1+A2 orthogonality

The A1 fix (when modifier `apply` bodies *run*) and the A2 fix (when
render-primitives are *emitted*) are orthogonal:

- A1 is a dispatch-time question: phase-aware modifier protocol.
- A2 is an emission-time question: deferred-emission per cell, ordering
  background → border → content within the content stream.

Fixing A1 does not fix A2. Fixing A2 does not fix A1. The α₂-flat
recommendation for A1 remains correct — it does not depend on A2 and does
not preclude any A2 fix shape.

### A2 fix shape (sketch only — not authorized in this commit)

For separated-border / non-table-element painting, the natural shape is:

- `_pushElement(block, …)` captures the cell/block rectangle at push time.
- Background fill (`re`/`f`) is emitted *immediately on push* with the
  width-known rectangle (height TBD for table cells).
- Border stroke is emitted at the appropriate boundary.
- Content is emitted normally between push and pop.

For collapsing borders (the institute model) on table cells with row-end
height determination:

- The current pattern emits content first then border at row-end.
- To swap order, content must be deferred: buffer cell content stream ops
  during the cell's body, then at row-end emit *background → border → buffered
  content* in that order.
- The `Table.Recording` mechanism (currently used for first-row
  column-width measurement) is structurally adjacent — extending it to all
  rows for emission-order reasons is the natural lift.

Alternative: use PDF form XObjects per cell — each cell renders into its
own XObject, then the row-end emission composites in `background → border
→ content` order. Heavier-weight but cleaner.

The A2 fix is **out of scope for the present audit** — flagged here as a
follow-on architectural question gated on A1 (which lands first).

### Updated α₁/α₂ recommendation under A1+A2

The A2 axis does not change the A1 recommendation. **α₂-flat for A1 still
stands.** A2 is a separate axis whose fix path is independent of the A1
choice; it should be authored as its own Research doc once A1 has landed
and Wave-2 sub-wave (a) Border-family modifiers reveal the cell-background
follow-on.

### α₂ feasibility

α₂ requires each modifier to declare its phase(s). For multi-phase modifiers
the protocol surface is either:

- **(a)** A `var phase: Phase` returning a single phase, with the pipeline
  dispatching the modifier multiple times if needed (once per phase). The
  modifier's `apply` body is responsible for being idempotent.
- **(b)** A `var phases: Set<Phase>` returning the full set, with the
  pipeline dispatching the modifier once per phase, and the modifier may
  inspect a `currentPhase: Phase` parameter to specialise behaviour.
- **(c)** Per-target dispatch: the modifier declares which `apply(to:)`
  variants it implements (`applyPrePush(to:)`, `applyPostPushLayout(to:)`,
  `applyPostPushRender(to:)`, `applyPopConsumed(to:)`), and the pipeline
  calls only the implemented ones. Default no-op implementations cover
  modifiers that need only one phase.

For multi-phase modifiers in our inventory, the second write at a different
phase is generally *redundant* — `FontSize`/`FontStyle`/`FontWeight`/
`LineHeight` write the same value at apply-time, and both pre-push (push
reads it) and post-push_render (rendering reads it) observe the same write.
A single dispatch suffices *if dispatched pre-push*, because the write
persists through both reads.

This collapses α₂ to a simpler shape: **per-modifier phase declaration with
single dispatch at the modifier's effective earliest-binding phase**. Most
modifiers fire pre-push (their natural state-write site); the
post-push_layout class (Border family + Orphans/Widows) fires post-push.

Variants under α₂:

- **α₂-flat**: enum `Phase { case prePush, postPushLayout, postPushRender,
  popConsumed, applyTimeImmediate }`. Each modifier returns a single value;
  multi-phase modifiers pick the *earliest* phase whose dispatch satisfies
  all their reads (pre-push for FontSize, etc.). The pipeline dispatches
  once per modifier at its declared phase.
- **α₂-typed**: split the `Modifier` protocol into phase-specific protocols:
  `Modifier.PrePush`, `Modifier.PostPushLayout`, etc. Each modifier conforms
  to exactly one (or multiple, where genuine multi-write semantics matter).
  Pipeline dispatches via type-witness check at each phase.

α₂-flat is simpler. α₂-typed is more type-safe but adds protocol surface.

## Recommendation

### For the A1 (dispatch-ordering) axis

**α₂-flat**: introduce a single enum `PDF.HTML.Style.Dispatch.Phase` and a
`var phase: Phase { get }` requirement on the existing
`PDF.HTML.Style.Modifier` and `PDF.HTML.Style.Context.Modifier` protocols
(with a default implementation returning `.prePush` to preserve current
behaviour for unspecified modifiers). The HTML rendering pipeline routes
each modifier's dispatch to one of four call sites: before
`applyBoxModel`/`_pushElement` (prePush), after `_pushElement` (postPushLayout),
before child-content rendering (postPushRender — practically the same as
postPushLayout for current consumers), or before `_popStyle` (popConsumed).
The `applyTimeImmediate` phase keeps the current behaviour (apply at
dispatch-call time).

Rationale:

1. **α₁ is provably wrong** — at least 14 modifier types break under uniform
   post-push reorder; no single dispatch site satisfies the full inventory.
2. **α₂-flat preserves current behaviour by default** — modifiers without an
   explicit phase declaration default to `.prePush`, matching the current
   pipeline. The migration is additive: only modifiers that need a different
   phase (Border family, the 6 post-push_layout class) carry an explicit
   override.
3. **α₂-typed is over-engineered for the inventory** — only 6 modifiers
   need a non-default phase (the post-push_layout class). Splitting the
   protocol into phase-specific variants introduces 4 protocols for 6
   target modifiers; the cost/benefit favours flat.
4. **Multi-phase modifiers collapse to single-dispatch under α₂-flat** —
   FontSize/FontStyle/FontWeight/LineHeight all dispatch once at pre-push;
   their writes persist through render-time reads. Margin/Padding shorthand
   similarly dispatches once at pre-push; bottom-side pop-consumed semantics
   are satisfied by write-persistence.
5. **The Border family fix is small** — change `phase` from default
   `.prePush` to `.postPushLayout` on Border, BorderStyle, BorderWidth,
   BorderColor, BorderCollapse, BorderSpacing-on-table (6 conformances).
6. **Phase-routing in the pipeline is one switch site** — the
   `apply(inlineStyle:)` call from `Render.Context.applyInlineStyle` becomes
   a no-op queue-append; the actual `apply` calls happen at the four routed
   sites in `_pushElement` / `_popStyle`. The queue is per-element; cleared
   on element pop.

### Sketch (illustrative; not the Phase 2 patch)

```swift
extension PDF.HTML.Style {
    public enum Dispatch {
        public enum Phase: Sendable {
            case prePush               // Before applyBoxModel + _pushElement
            case postPushLayout        // After _pushElement creates element context
            case postPushRender        // Before child-content rendering begins
            case popConsumed           // At _popStyle, before snapshot restore
            case applyTimeImmediate    // At apply(inlineStyle:) dispatch call
        }
    }
}

extension PDF.HTML.Style.Modifier {
    public var phase: PDF.HTML.Style.Dispatch.Phase { .prePush }   // default
}

extension W3C_CSS_Backgrounds.Border: PDF.HTML.Style.Context.Modifier {
    public var phase: PDF.HTML.Style.Dispatch.Phase { .postPushLayout }
    public func apply(to context: inout PDF.HTML.Context) { … }
}
```

The pipeline change (in `Render.Context +PDF.HTML.swift` and
`PDF.HTML.Context.apply(inlineStyle:)`) queues each modifier by phase
during element collection; `_pushElement` flushes prePush before its work,
flushes postPushLayout after creating element context, flushes
postPushRender before rendering content; `_popStyle` flushes popConsumed
before snapshot restore. The applyTimeImmediate phase fires synchronously
during the queue-append, preserving current `BreakBefore.apply` semantics.

This sketch is illustrative — the Phase 2 patch will commit the exact protocol
shape, the exact queue site, and the per-modifier `phase` overrides as
separate commits per `[SUPER-046]` per-modifier coherence.

### For the A2 (emission-ordering) axis

Out of scope for this audit. The compliance scan (see § A1+A2
Cross-Reference + Compliance Analysis) identifies E1+E2 cell borders as
latently non-compliant (emitted after cell content; PDF painter semantics
paint borders on top of text, opposite to CSS §17.6) and E5 cell
backgrounds as architecturally missing (`drawCellBackground` defined but
never called). The A2 fix path requires deferred cell content emission
(extending the `Table.Recording` pattern from first-row-only to all rows)
or per-cell PDF form XObjects. **Recommend authoring a follow-on Research
doc `table-emission-ordering.md` once A1 Phase 2 has landed** — A1 is the
gating dependency because the Border modifier (which would set
`context.table.borderColor`/`borderWidth`) must work correctly before any
A2 emission-ordering fix is meaningfully testable.

## Open Questions / RELATED

Surfaced during the read; not in scope for this Research doc nor for the
α₂ Phase 2 patch. Each is a candidate for a separate dispatch.

- **R1 — Cascade-resolution gap (Open Question F)**: the institute renderer
  has no cascading-styles model. CSS-wide keywords (`inherit`, `initial`,
  `unset`, `revert`) are stubbed as `.global` branches in every modifier and
  the `apply` body just `break`s. Phase-aware dispatch is orthogonal to
  cascade resolution but interacts: once cascade lands, phase dispatch still
  applies per-modifier.
- **R2 — Block-element border surface (Open Question G)**: `PDF.Context.Style`
  carries no `border` field for non-table block elements. The Border family's
  current target is `context.table.borderX`; a `<div>`-bound border has no
  destination. When `PDF.Context.Style.border` lands, the Border family's
  `apply` body needs a branch on element kind (table vs non-table); phase
  remains `.postPushLayout` for the table case and could be `.prePush` for
  the block case if border is drawn during push, or `.postPushRender` if
  drawn after content (more likely the latter for box-model-style borders).
- **R3 — `<th>` font-bold timing**: `_pushElement("th",…)` line 688
  unconditionally sets `pdf.style.font = .bold`. This *also* fires before
  modifier dispatch under current dispatch order, so the modifier wins.
  Under α₂ if the `<th>` font-bold is in `pushBlockElement` (which is called
  at the end of `_pushElement`), it fires after prePush dispatch and before
  postPushLayout dispatch — i.e., the modifier can still override it via
  postPushRender. The audit does not change this; flag for confirmation.
- **R4 — `applyTagStyle` interaction**: `applyTagStyle` (line 360) fires
  *inside* `_pushElement` before `pushBlockElement`. It writes
  `pdf.style.{font,fontSize,textMarkup,color}`. Under prePush dispatch the
  modifier writes happen first, then `applyTagStyle` may overwrite (e.g.,
  `<a>` sets `color = .blue` which would stomp a user's `.css.color(.red)`).
  This is a defect in current dispatch ordering, not a side-effect of α₂.
  Phase-aware dispatch makes the fix tractable: a per-tag `applyTagStyle`
  could be reframed as a pre-tag set of "stylesheet defaults" that fire at
  a `phase` *before* user modifiers. Flag for separate research.
- **R5 — Speculative-rendering interaction**: `Render.Context +PDF.HTML.swift`
  line 197 captures a `speculativeSnapshot` when `avoidPageBreakAfter` is
  set by a modifier. Under α₂, `avoidPageBreakAfter` is set in the
  popConsumed dispatch — but the speculative-snapshot capture currently
  happens inside `applyInlineStyle`. The capture site will need to move to
  whichever dispatch phase sets `avoidPageBreakAfter`. The current single
  Context.Modifier (`PageBreakAfter`/`Multicolumn.BreakAfter`) sets the
  flag immediately on apply; under α₂ this could become prePush
  (consistent with default) or popConsumed (consistent with when the flag
  is read). Phase 2 must reconcile.
- **R6 — Multicolumn / Paged duplicate semantics**: `PageBreakAfter` (legacy)
  and `Multicolumn.BreakAfter` (modern) set the same flag with slightly
  different value branches. Phase declarations should be identical for both
  to avoid divergence. Flag for confirmation during Phase 2 implementation.
- **R7 — Recording-replay path interaction**: `apply(inlineStyle:)` line 156
  routes to the table-recording queue when `table.recording != nil`. Phase
  dispatch must preserve this: the recording captures the *inline-style
  value* with its phase, and replay applies it at the same phase. The
  table-recording inventory's `Command.inlineStyle(_)` case needs a phase
  field or the modifier's `phase` is queried at replay. Phase 2 detail.

A2-induced RELATED items (added in v1.1.0 per Rev-4 amendment):

- **R8 — `drawCellBackground` dead code**: `HTML.Element.Tag+TableBorders.swift:88-102`
  defines `drawCellBackground` with full body (`pdf.emit.rectangle(bounds,
  fill: color, stroke: nil)`) but zero call sites in the codebase (grep
  verified). Wiring this up is gated on (a) A1 Border family landing (so
  `context.table.background*` defaults can be modifier-overridden the same
  way `borderColor`/`Width` will be), and (b) A2 emission-ordering fix
  (background must paint before content; current emission order paints
  borders after content; backgrounds would need to paint before both).
  Out of scope for both A1 Phase 2 and the A2 follow-on doc.
- **R9 — Latent non-compliance severity assessment**: cell borders paint
  AFTER text content (E1+E2), inverse of CSS §17.6 painting order. Latent
  today because cell-padding insets text. As soon as: (a) cell-padding is
  configurable per cell (no fixed inset guarantee), (b) cell borders carry
  alpha < 1 (translucent borders would visibly clip text), or (c) cell
  backgrounds are wired up (E5 → R8), the latent defect surfaces visibly.
  Estimated 6-12 month horizon before this becomes user-visible. The Phase
  2 A1 fix is non-dependent.
- **R10 — Block-level border/background emission order**: when
  `PDF.Context.Style.border` and `PDF.Context.Style.background` fields
  land for non-table block elements (Open Question G), the same
  before-content emission constraint applies. The fix shape will be
  symmetric to the table cell case but easier — block bounds are known at
  push time (no row-end height determination) so background and border
  can be emitted directly at push. Authoring suggestion: when block-level
  border lands, the modifier writes to `pdf.style.border`; `_pushElement`
  reads and emits background + border *before* dispatching prePush
  modifiers' descendant content. This naturally satisfies §E.2 step 2.

None of R1–R10 invalidate the α₂-flat recommendation for A1; they bound
the Phase 2 A1 patch scope and seed the A2 follow-on doc.

## References

- Entry condition: `swift-foundations/swift-pdf-html-render` commit `fa112c0`
  (subsequently reverted to `3f84976`). Empirical finding: 14-pre/14-post
  cell-border `m/l/S` triple count in
  `Experiments/render-parity/Outputs/render-parity.pdf`; instrumented `print`
  confirmed `context.table == nil` at modifier dispatch.
- Authorizing dispatch: `tenthijeboonkkamp/timekeeping/HANDOFF-swift-pdf-render-parity.md`
  `## Constraints / Adjudications (Revision 3, 2026-05-11)` — user
  adjudication for path α (architecturally-best, unbounded effort).
- Authorizing extension (v1.1.0): `tenthijeboonkkamp/timekeeping/HANDOFF-swift-pdf-render-parity.md`
  commit `b3e4690` — Revision 4 path-α extension to A2 emission-ordering
  axis ("are we respecting BOTH PDF and CSS drawing order here?").
- CSS painting order normative references: CSS 2.1 §E.2 (Painting order
  for stacking contexts); §17.6 (Borders); §17.6.1 (Separated borders
  model); §17.6.2 (Collapsing border model).
- A2 emission inventory sources: `HTML.Element.Tag+TableBorders.swift`
  (drawCellBorder / drawTableRightAndBottomBorders /
  drawFragmentRightAndBottomBorders / drawCellBackground); `PDF.HTML.Context+Rendering.swift`
  (E1 call site at line 1000, E2 at 1016, E3 at 750, E4 at 617, E9
  list-marker assignment at 720-734, E10 `<hr>` at 550-555, E14 page-break
  at 487/626).
- Related Research: `swift-foundations/swift-pdf-html-render/Research/css-fidelity-gap-inventory.md`
  (the 22-stub modifier inventory and per-symptom mapping); this audit
  generalizes that inventory's phase implications.
- Source: `PDF HTML Rendering/PDF.HTML.Context+Rendering.swift` (dispatch site
  at lines 155–189; push-time READ-set at 314–423, 565–739; pop-time
  consume-set at 425–460, 473–498, 740–798, 975–1075).
- Skill anchors: `[RES-001]` investigation triggers; `[RES-004]`/`[RES-009]`
  multi-option analysis; `[RES-020]`/`[RES-021]` Tier-2 prior-art rigour.
