# CSS Fidelity Gap Inventory — Institute `swift-pdf-html-render` vs `coenttb/swift-html-to-pdf`

<!--
---
version: 1.0.0
last_updated: 2026-05-11
status: RECOMMENDATION
---
-->

## Context

Per the parent dispatch's supervisor block (acceptance criterion #2), this
research doc inventories the CSS subset that `coenttb/swift-html-to-pdf`
honored but `swift-foundations/swift-pdf-html-render` does not honor (yet).

Reference rendering: `Invoices/100+/20260211/...factuur-17.pdf` (1-page,
designed layout via Apple's PDFKit/CGContext-backed coenttb chain).
Reproducer: `Invoices/100+/20260511/...factuur-21.pdf` (3-page, broken
layout via the institute swift-pdf chain).

## Question

Which CSS properties does the institute pipeline parse but not apply, and
how do those gaps explain the observed layout defects (heavy borders, word
stacking, glued labels, broken pagination)?

## Analysis

### The structural cause

Inspection of `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/`
reveals that **22 of 46 CSS style modifiers have empty `apply(...)` bodies
with a single `// TODO: Apply ... to PDF context` comment**. The CSS is
parsed correctly (the W3C CSS parser at L2 produces typed values), but the
application step that translates each value into `PDF.Context` state is
a no-op for these properties.

### Implemented properties (24, working)

| File suffix | CSS property |
|-------------|--------------|
| `W3C_CSS_Backgrounds.BackgroundColor` | `background-color` |
| `W3C_CSS_BoxModel.Height` | `height` |
| `W3C_CSS_BoxModel.Margin` / `MarginTop` / `MarginBottom` / `MarginLeft` / `MarginRight` | `margin*` |
| `W3C_CSS_BoxModel.Padding` / `PaddingTop` / `PaddingBottom` / `PaddingLeft` / `PaddingRight` | `padding*` |
| `W3C_CSS_BoxModel.Width` | `width` |
| `W3C_CSS_Color.Color` | `color` |
| `W3C_CSS_Fonts.FontSize` / `FontStyle` / `FontWeight` | font scalars |
| `W3C_CSS_Multicolumn.BreakAfter` / `BreakBefore` / `BreakInside` | column break hints |
| `W3C_CSS_Paged.PageBreakAfter` / `PageBreakBefore` / `PageBreakInside` | paged break hints |
| `W3C_CSS_Text.TextAlign` | `text-align` |

### Stubbed (no-op) properties (22, broken)

All files below have body `// TODO: Apply ... to PDF context` and emit
empty function bodies. Source: `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/`.

| File | CSS property | Symptom contribution |
|------|--------------|----------------------|
| `W3C_CSS_Backgrounds.Border.swift` | `border` shorthand | **CSS `border: none` ignored → tables show default borders** |
| `W3C_CSS_Backgrounds.BorderCollapse.swift` | `border-collapse` | Double borders, no collapse |
| `W3C_CSS_Backgrounds.BorderColor.swift` | `border-color` | Default gray stays |
| `W3C_CSS_Backgrounds.BorderRadius.swift` | `border-radius` | Square corners only |
| `W3C_CSS_Backgrounds.BorderSpacing.swift` | `border-spacing` | Cells touch |
| `W3C_CSS_Backgrounds.BorderStyle.swift` | `border-style` (`none` / `solid` / `dashed`) | Cannot turn off |
| `W3C_CSS_Backgrounds.BorderWidth.swift` | `border-width` | Width never overridden |
| `W3C_CSS_BoxModel.MaxHeight.swift` | `max-height` | No clamp |
| `W3C_CSS_BoxModel.MaxWidth.swift` | `max-width` | No clamp |
| `W3C_CSS_BoxModel.MinHeight.swift` | `min-height` | No clamp |
| `W3C_CSS_BoxModel.MinWidth.swift` | `min-width` | **Address columns collapse below content width** |
| `W3C_CSS_Display.Display.swift` | `display: flex` / `grid` / `inline-block` | **Two-column flex header collapses to block** |
| `W3C_CSS_Lists.ListStylePosition.swift` | `list-style-position` | List markers fixed |
| `W3C_CSS_Lists.ListStyleType.swift` | `list-style-type` | Disc/circle/square hardcoded by tier |
| `W3C_CSS_Paged.Orphans.swift` | `orphans` | Widow/orphan control absent |
| `W3C_CSS_Paged.Widows.swift` | `widows` | Widow/orphan control absent |
| `W3C_CSS_Text.LetterSpacing.swift` | `letter-spacing` | Tracking ignored |
| `W3C_CSS_Text.LineHeight.swift` | `line-height` | Default leading only |
| `W3C_CSS_Text.TextIndent.swift` | `text-indent` | No first-line indent |
| `W3C_CSS_Text.TextTransform.swift` | `text-transform` | uppercase / lowercase / capitalize ignored |
| `W3C_CSS_Text.WhiteSpace.swift` | `white-space: nowrap / pre / pre-wrap` | **`tel`/`+31` collapse — see below** |
| `W3C_CSS_Text.WordSpacing.swift` | `word-spacing` | Tracking ignored |

### Confirmed failure mappings from the reproducer

#### 1. Heavy box-borders on every table grouping

**Cause**: `W3C_CSS_Backgrounds.Border`, `BorderCollapse`, `BorderColor`,
`BorderStyle`, `BorderWidth` all stubbed → CSS `border: none` is parsed
but never applied to `PDF.Context.style.border` / `PDF.Context.Table`. The
table renderer falls back to its hard-coded defaults at
`swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Configuration.Table.Border.swift:16-22`:

```swift
public init(
    color: PDF.Color = .gray(0.3),
    width: PDF.UserSpace.Size<1> = 0.5
) { /* … */ }
```

Border drawing then unconditionally fires at
`HTML.Element.Tag+TableBorders.swift:12-36` (`drawCellBorder` runs unless
`tableCtx.borderWidth == .init(0)`). Since the CSS never gets a chance to
zero out the width, every cell draws left+top edges.

#### 2. 3-page output where coenttb produced 1

**Cause**: cascade from #3 (column-width misallocation) → vertical content
overflow → spillover into pages 2 and 3.
Pagination control fragments: `Orphans` / `Widows` stubbed; only
`PageBreakBefore` / `PageBreakAfter` / `PageBreakInside` are honored. Mid-
section cuts in the timekeeping output indicate that `page-break-inside:
avoid` was not present on the affected containers, OR that the cascade made
the content too tall to fit a single page regardless.

#### 3. Address words stacked one per line (`p/a` / `Profource` / …)

On-disk content stream:
```
/Span << /ActualText (p/a Profource Service Center)>> BDC
/F5 12 Tf
-4 -27.6 Td
(p/a) Tj
0 -13.8 Td        ← line break (one line-leading down)
(Profource) Tj
0 -13.8 Td
(Service) Tj
0 -13.8 Td
(Center) Tj
EMC
```

**Cause**: at the line-wrapper in
`swift-pdf-render/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:81-101`,
the wrap predicate is:

```swift
} else if currentLineWidth + width <= maxWidth {
    state.appendWord(width: width, runIndex: currentRunIndex)
    currentLineWidth = currentLineWidth + width
} else {
    // Line full — flush + start new line
    emitLine(&state, runs: runs, context: &context, isFirstLine: isFirstLine)
    /* … */
}
```

`maxWidth` is `context.layout.box.width` (the available content box). When
`display: flex` is stubbed and a child container's `min-width` /
`max-width` are stubbed, the address column inherits an unconstrained-but-
still-narrow block-layout box. The first word's width exceeds the box and
the wrapper goes into one-word-per-line failure mode.

**Two stubbed gaps cause this jointly**: `Display` (the flex container is
treated as block, so the address column doesn't get its parallel-positioned
parent box) and `MinWidth` (the inner column can't pin its own width).

#### 4. Labels glued to values (`tel+31`, `kvk75006723`, `btw NL002225740B77`, `iban NL47`)

On-disk content stream:
```
/Span << /ActualText (tel)>> BDC
(tel) Tj
EMC
/Span << /ActualText (+31 6 43 90 14 29)>> BDC
6 0 Td                          ← 6pt horizontal offset, no inline space
(+31) Tj
...
```

Each `<span>` ends with `EMC` (end-marked-content) and the next span starts
with NO whitespace text node between them. The HTML probably reads
`<span>tel</span> <span>+31 ...</span>` with whitespace TEXT NODES between
the spans (CSS-collapsible whitespace).

**Cause**: `W3C_CSS_Text.WhiteSpace` and `WordSpacing` stubbed → the CSS
whitespace-collapsing algorithm (CSS 2.1 §16.6) is not implemented. The
parser likely drops the inter-element whitespace text nodes (treating them
as not-significant), and there's no compensating mechanism to insert a
space glyph between adjacent inline elements.

Confirmation: when a single `<span>` contains "+31 6 43 90 14 29" with
spaces in the SAME text node (verified by the `/ActualText (+31 6 43 …)`),
the spaces ARE preserved per the WinAnsi byte 0x20 in the content stream.
The collapse fires specifically at the inter-element boundary.

#### 5. Table cell wrap ("week 1 vaste / uren")

**Cause**: same as #3 — table column widths fall back to equal-distribution
when CSS `width: X%` / `min-width: Y` / `max-width: Z` aren't honored.
`width` IS implemented per the IMPL list, but the `<colgroup><col width="...">`
HTML form is a separate pathway from CSS `td { width: ... }` — let me
verify.

Inspection of
`swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Context.Table.*`
shows column-width assignment via `tableCtx.columnWidths`. The assignment
strategy is "equal distribution if no `colgroup`/`col` widths declared and
no `td` width on first row." `<table style="table-layout: fixed">` is not
a parsed CSS property and CSS-based per-column widths require all three of
`{ table-layout: fixed; width: …; td { width: …; min-width: …; max-width: …; }}`
— at least 2 of which depend on stubbed properties.

#### 6. Pagination cuts mid-section

**Cause**: vertical box-overflow from accumulated #1–#5 defects (heavy
borders inflate cell height; word-per-line stacking inflates row height;
glued labels force wider layout, etc.) plus stubbed `Orphans`/`Widows`.
The `PageBreakInside.avoid` IS honored but the originating HTML
declarations likely don't carry `page-break-inside: avoid` on the affected
elements; the layout's pre-overflow shape would have fit on one page if
the CSS gaps were closed.

## Outcome

**Status**: RECOMMENDATION

**Top three concrete file:line examples** (per acceptance criterion #2,
"at least 3"):

1. `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_Backgrounds.Border+PDF.HTML.Style.Modifier.swift:8-10` — `border` is a no-op
2. `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_Display.Display+PDF.HTML.Style.Modifier.swift:8-10` — `display: flex / grid` is a no-op
3. `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_Text.WhiteSpace+PDF.HTML.Style.Modifier.swift:8-10` — `white-space: normal` whitespace collapse is a no-op

Three more shipped under the same defect class:

4. `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_Text.LineHeight+PDF.HTML.Style.Modifier.swift:8-10` — `line-height` is a no-op
5. `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_BoxModel.MinWidth+PDF.HTML.Style.Modifier.swift:8-10` — `min-width` is a no-op
6. `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_BoxModel.MaxWidth+PDF.HTML.Style.Modifier.swift:8-10` — `max-width` is a no-op

### Fix options

#### (a) Targeted patches per stubbed modifier (RECOMMENDED)

For each of the 22 stubbed files, implement the `apply(to:configuration:)`
body that translates the CSS value into `PDF.Context.style` / `Configuration`
mutations. The shape of each patch is small:

- `Border / BorderStyle / BorderWidth / BorderColor` → mutate
  `context.style.border` (a typed value the table renderer already reads
  conditionally; see `HTML.Element.Tag+TableBorders.swift:19`'s
  `tableCtx.borderWidth != .init(0)` guard).
- `Display.Display` → minimal flex/grid support is large (introduces a
  whole layout pass); a tactical step is to honor `display: none` and
  `display: inline` immediately (cheap, fixes a class of bugs); `flex`
  / `grid` are deferred per option (c) below.
- `Text.WhiteSpace` → toggle `context.mode.preserveWhitespace` (already
  read at `PDF.Context.Text.Run+Rendering.swift:36`); the inter-element-
  whitespace collapse algorithm needs companion work in the HTML tokenizer
  layer.
- `Text.LineHeight` → mutate `context.style.lineHeight` (the leading used
  in `0 -13.8 Td` displacements at flush time).
- `BoxModel.MinWidth` / `MaxWidth` / `MinHeight` / `MaxHeight` → clamp
  `context.layout.box.width` / `.height` against the typed value.

**Authorization gate**: edits land in `swift-pdf-html-render` (relaxed
package). Each is a standard per-finding YES.

The complete inventory + per-modifier sketch is ~22 patches; not all are
equally urgent for the timekeeping reproducer. Priority order matches the
symptom catalog above: Border + BorderStyle + BorderWidth first (#1, #2),
Display (partial: `none` + `inline-block`) + MinWidth (#3, #5), WhiteSpace
+ LineHeight (#4, #6).

#### (b) New institute infrastructure — flex/grid layout pass

`display: flex` and `display: grid` are NOT mechanical translations of a
single CSS value into one PDF.Context field. They require a layout-pass
module that runs before content emission and computes child-box positions
(main-axis / cross-axis alignment, gap, basis, grow, shrink, etc.). This
is substantial new infrastructure.

Placement candidates (subordinate cannot decide; class-(c) escalation
per supervisor-block ask #6):

- **L2 / a new `swift-css-layout-primitives` package** alongside
  `swift-w3c-css` — would contain the flex / grid algorithms abstracted
  away from PDF specifics, consumable also by HTML-render and SVG-render.
- **L3 / a new pass inside `swift-pdf-html-render`** — concrete to PDF
  rendering, sits between `PDF.HTML.Context.Element` resolution and
  content emission.

The first preserves architectural layering and aligns with the layered
ecosystem model; the second is faster to implement. Either is a
class-(c) escalation.

#### (c) Documented deferral with consumer workaround

For consumers like `tenthijeboonkkamp/timekeeping`: until flex/grid are
implemented, rewrite invoice HTML headers as `<table>` two-column layout
instead of CSS flex. Tables are honored by the institute pipeline
(column-width computation works when `<colgroup><col width="…">`
declarations are present per the `PDF.HTML.Context.Table.swift` machinery).
The invoice CSS-fidelity gap that is workaroundable is the flex/grid one;
the table-cell border problem still needs option (a) patches before any
parity claim is made.

### Recommendation

Combination: **(a)** for the 6 high-priority stubbed modifiers (Border,
BorderStyle, BorderWidth, BorderColor, MinWidth, MaxWidth, WhiteSpace,
LineHeight — sufficient to fix #1, #4, #6 and improve #3, #5), plus
class-(c) escalation per **(b)** to decide flex/grid placement and
priority. Option (c) is the bridge for downstream consumers while (a)
and (b) land.

Path (a) edits all live in the relaxed set
(`swift-pdf-html-render`); each patch is its own per-finding YES gate
per supervisor-block fact #2.

### Verification gates (per acceptance criterion #2)

- ✓ Gap inventory: 22 stubbed CSS modifier files enumerated
- ✓ At-least-3 concrete examples: 6 examples with file:line citations
- ✓ Semantic description per defect: tabled above
- ✓ Symptom → cause mapping for all 6 reported failure classes

## Addendum (2026-05-11) — Rev-6 γ-3 partial completion: MinWidth / MaxWidth schema gap

Under Rev-6 (`HANDOFF-swift-pdf-render-parity.md` Adjudication γ-3),
WhiteSpace and LineHeight landed under γ-3.1 (`e88fb38`) + γ-3.2
(`63712c6`). MinWidth and MaxWidth were **DEFERRED** from this
dispatch per the principal's adjudication (2026-05-11) on the
following grounds:

1. **No existing institute slot**.
   `swift-pdf-render/Sources/PDF Rendering/PDF.Context.Constraint.swift`
   line 8–13 declares `public struct Constraint { public var width:
   PDF.UserSpace.Width?; public var height: PDF.UserSpace.Height? }`.
   There are no `minWidth` / `maxWidth` fields and no consumer reads.
   Implementing the two modifiers requires extending the schema in
   `swift-pdf-render` (additive: two new optional fields) AND adding
   reads in `applyBoxModel` at
   `swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:526-528`
   to clamp `pdf.layout.box.urx`. Cross-package work touching two
   institute packages.

2. **No load-bearing consumer in the timekeeping reproducer**.
   `grep -r -i -E "(min-?width|max-?width|minWidth|maxWidth)"` across
   `tenthijeboonkkamp/timekeeping/Sources/` → 0 matches. Across
   `swift-document-templates/Sources/Invoice/` → 0 matches. The only
   `.maxWidth(.px(300))` lives in
   `swift-document-templates/Sources/Signature Page/Signatory.swift`
   (Signature Page template, not used by the Invoice template). The
   `normalize.css legend{max-width:100%}` is in a `<style>` string
   inside a media query — neither path the institute CSS modifier
   system intercepts.

3. **Reproducer column-collapse is caused by `display: flex` stubbing,
   not by missing min/max-width**. Per Rev-2 Adjudication #3, flex /
   grid placement is **DEFERRED to a separate dispatch** (recommended:
   new L2 `swift-css-layout-primitives` package alongside
   `swift-w3c-css`, reusable by HTML render + SVG render). Adding
   MinWidth/MaxWidth alone would not close the column-collapse
   symptom.

**Trigger for the follow-up dispatch**: if a future
`swift run Invoices` regeneration surfaces a visual defect that
traces specifically to missing `min-width` / `max-width` honoring
(e.g., user adds an explicit `min-width: NNN` to invoice CSS and the
column still collapses below NNN), THAT becomes the trigger for a
small follow-up — constraint field + `applyBoxModel` clamp + 2
modifiers + tests. Per Rev-6 γ-5 the deferred architectural dispatch
may also subsume this if it broadens to a CSS-layout-primitives
package.

**Files that would change in the follow-up**:
- `swift-pdf-render/Sources/PDF Rendering/PDF.Context.Constraint.swift`
  → add `minWidth: PDF.UserSpace.Width?`, `maxWidth: PDF.UserSpace.Width?`
- `swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift`
  applyBoxModel → clamp `pdf.layout.box.urx` accordingly
- `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/W3C_CSS_BoxModel.{Min,Max}Width+PDF.HTML.Style.Modifier.swift`
  → fill in the existing TODO stubs

The stub files at lines 8-10 of `W3C_CSS_BoxModel.MinWidth+…swift` and
`W3C_CSS_BoxModel.MaxWidth+…swift` REMAIN as TODO no-ops post-γ-3 —
not regressed. Discovery of this gap and the no-load-bearing-consumer
grep evidence is the addendum's load-bearing contribution.

## Addendum (2026-05-11) — Option 3 empirical results + state-stack diagnostic

After Rev-6 γ-1 → γ-3 landed (swift-pdf-html-render HEAD = 63712c6) and the
γ-2.1 Border-shorthand path was verified end-to-end on the
Experiments/render-parity reproducer (14/14 → 0/0 cell-border `m/l` strokes
on a single-table fixture), the orchestrator authorized **Option 3 — a
consumer-side edit to `swift-document-templates/Sources/Invoice/Invoice.swift`**
appending `.css.border(width: .px(0), style: LineStyle.none, color: .gray300)`
to each of the 6 `<table>` elements in the Invoice template. Expectation:
route through γ-2.1, suppress the institute's `Configuration.Table.Border`
default (gray 0.3 / 0.5pt) defaults that `drawCellBorder` emits per-cell.

### Empirical outcome — Option 3 fails at scale

After Invoice.swift edit + `swift run Invoices` regen:

| | Reference factuur-17 (coenttb chain) | Pre-Option-3 factuur-21 (post-γ-3.2) | Post-Option-3 factuur-21 |
|---|---|---|---|
| Pages | 1 | 3 | 3 (unchanged) |
| `m/l` cell-border strokes | 0 / 0 | 143 / 143 | **131 / 131** |
| Size | 23721 B | 14840 B | 14319 B |

**Stroke reduction: 12 of 143 (~8%). Far from full suppression.**

### Diagnostic findings (from `print` instrumentation, since reverted)

The Option-3 edit was reverted post-diagnostic per orchestrator adjudication
(2026-05-11). Diagnostic findings preserved here as durable signal:

1. **The Border modifier IS dispatched** for the Invoice's
   `.css.border(width:, style:, color:)` calls. Disambiguates to
   `swift-css/CSS+DarkModeColor.swift:98-115`'s typed-Border path (NOT the
   `RawProperty<Border>` convenience path initially feared). Diagnostic
   showed `property type: Border` at dispatch, not `RawProperty<Border>`.

2. **`context.table != nil` at ALL 264 modifier dispatches** for the 24
   invoices. The γ-slot path (intended for `context.table == nil` at
   modifier dispatch) does NOT fire for the invoice — writes go directly
   to `context.table?.borderWidth`.

3. **Writes correctly land**:
   `before write context.table.borderWidth=0.5; after write
   context.table.borderWidth=0`. The mutation itself succeeds at the
   write site.

4. **`_pushElement table` shows broken pop-ordering between siblings**:
   ```
   _pushElement table; context.table was nil: true   <- table 1 (top-level) ✓
   _pushElement table; context.table was nil: false  <- table 2 (nested in 1) ✓
   _pushElement table; context.table was nil: true   <- table 3 (after 1+2 popped) ✓
   [Border modifier fires; table == nil: false]      <- inside some table render
   _pushElement table; context.table was nil: false  <- table 4 — UNEXPECTED non-nil ✗
   _pushElement table; context.table was nil: false  <- table 5 — UNEXPECTED non-nil ✗
   ```
   Tables 4 and 5 are source-level siblings (not nested) — by the rendering
   model, table 3's pop should have cleared `context.table` to nil before
   table 4's push. The non-nil state at sibling pushes indicates pops are
   not firing in the expected order between siblings.

### Hypothesis — pipeline state-stack pop-ordering bug

The Render.Context uses an iterative stack-based renderer
(`Render.Context.render(_:)` at `swift-render-primitives/.../Render.Context.swift:165-186`)
with `_stack` LIFO processing of queued `.closeScope(.pop(...))` frames. Sibling
content is queued via `Render._Tuple._render` (push-each-to-stack then
`_reverseAbove(marker)` for FIFO replay). `HTML.CSS<Base>` (used by
`.css.borderCollapse(...)` and `.css.border(...)` chains) has no custom
`_render`, falling back to the default `Render.View._render` (line 19-37 of
`Render.View.swift`) which ALSO push-to-stack.

The interaction of:
- `HTML.Styled._render` (synchronous; apply-inline-style → Content._render)
- `HTML.CSS<X>._render` default (stack-push deferred)
- `Render._Tuple._render` (stack-push siblings)
- `HTML.Element._render` (synchronous; `context.open` queues element pop)

is plausibly the source of the missed pop. Sibling table pops queued during
table N's render may interleave incorrectly with table N+1's render entry,
leaving `context.table` set when the sibling's modifier dispatches and the
sibling's element push fires. Concrete trace + minimal reproducer is queued
for the deferred architectural dispatch.

### Consequence — Option-3-class fixes can't reach parity until state-stack is fixed

The 8% stroke-reduction from Option 3 corresponds to the small fraction of
tables whose state-stack happens to be well-formed at dispatch time. For
the rest, `drawCellBorder` reads a stale `tableCtx.borderWidth` snapshot
that the modifier write never reached. The bug is orthogonal to Rev-6 γ-5
triggers (i)–(iv) (dispatch ordering, emission ordering, slot scaling) — it
is a NEW architectural concern, surfaced empirically 2026-05-11 post-γ
landing.

### Recommended next-step paths (for the deferred dispatch)

- **(P1)** Instrument `drawCellBorder` + `popTableRow` to confirm whether
  `tableCtx.borderWidth` is 0 or 0.5 at draw time for each cell. Pin
  whether the issue is local-copy capture (`var tableCtx = context.table`
  at popTableRow line 993) or sibling pop-ordering. Estimated: ½ day +
  reproducer regen verification.
- **(P2)** Build a minimal swift-pdf-html-render-only reproducer for the
  sibling-table state-stack issue (no coenttb deps). Two top-level tables
  inline + γ-2.1 Border on each + diagnostic prints. Establishes blast
  radius of the bug for fix design.
- **(P3)** Architectural fix candidates:
  - (a) Switch HTML.CSS<X> to synchronous _render (drop the stack-push
    default, match HTML.Styled). Likely simplest if it doesn't blow the
    recursion budget — but the iterative renderer was introduced
    specifically to avoid stack overflow per `swift-render-primitives`
    docs.
  - (b) Synchronous pop fires for `.element` actions (close-scope frames
    fire eagerly rather than queued on `_stack`). Larger redesign.
  - (c) Decouple `context.table` state from element-push timing: state
    becomes scope-keyed (HashMap from element-scope-id → Table) so a
    stale `context.table` value can't leak between siblings.

### Tactical workaround if invoice parity is needed before the deferred dispatch lands

**(δ) Configuration.Table.Border default change**: Set
`PDF.HTML.Configuration.Table.Border.init` defaults (line 16-22 of
`PDF.HTML.Configuration.Table.Border.swift`) to `color: .gray(0.3),
width: 0` (was `0.5`). W3C-compatible — "no CSS = no border". Sidesteps
the state-stack bug without fixing it: defaults can't fire at width 0, so
broken state-propagation becomes moot for the cell-border path. One-line
institute edit; impact-assessment is the consumer-side opt-in expectation
shift (consumers wanting borders MUST declare them explicitly via CSS).
This is queued as Rev-6 γ-5 trigger (v) candidate — see HANDOFF for the
formal escalation.

## References

- `swift-pdf-html-render/Sources/PDF HTML Rendering/CSS/` — 46 CSS modifier files
- `swift-pdf-html-render/Sources/PDF HTML Rendering/HTML.Element.Tag+TableBorders.swift:12-86` — table-border drawing
- `swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Configuration.Table.Border.swift:16-22` — default border fallback
- `swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:992-1021` — `popTableRow` with `drawCellBorder` loop
- `swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:895-921` — `finalizeFirstRow` recording-replay
- `swift-render-primitives/Sources/Render Primitives Core/Render.Context.swift:165-186` — iterative stack-based renderer
- `swift-render-primitives/Sources/Render Primitives Core/Render._Tuple.swift:21-43` — sibling stack-push pattern
- `swift-render-primitives/Sources/Render Primitives Core/Render.View.swift:19-37` — default _render stack-push
- `swift-pdf-render/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:55-145` — line-wrapping wrap predicate
- W3C CSS 2.1 §16.6 — whitespace processing
- W3C CSS Flexbox Level 1 — flex layout algorithm
- W3C CSS Grid Layout Level 1 — grid layout algorithm
- W3C CSS Tables Level 3 — automatic / fixed table layout
