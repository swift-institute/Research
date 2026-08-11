# CSS `width: N%` misinterpreted as percentage of font size

> Phase B sub-investigation pivot (2026-05-12). After
> `state-stack-pop-ordering.md` ruled out the original state-stack
> hypothesis with assertion-grade reproducers, the user's primary goal
> (factuur-21: 3 pages → 1 page) drove a deeper P3 read into the
> consumer source (coenttb/swift-document-templates Letter pattern).
> That surfaced this architectural defect.

## TL;DR

`W3C_CSS_BoxModel.Width.apply(...)` at
`CSS/W3C_CSS_BoxModel.Width+PDF.HTML.Style.Modifier.swift:7-29` writes
`context.constraint.width = size.width` where `size` is computed via
`PDF.UserSpace.Size<1>(lengthPercentage, currentSize:, baseFontSize:)`.

For `.percentage(N)`, that init at
`CSS/CSS+PDF.UserSpace.Size.swift:73-75` does:

```swift
case .percentage(let percentage):
    // Percentage of current font size
    self = currentSize * Dimension_Primitives.Scale(percentage.value / 100.0)
```

`currentSize` is the FONT size. So `width: 100%` becomes
`11pt × 1.0 = 11pt` (when font is 11pt). Then `applyBoxModel` reads
`context.constraint.width` and writes
`pdf.layout.box.urx = pdf.layout.box.llx + 11pt` — **collapsing the
layout box to 11pt wide**.

Per **CSS 2.1 §10.3.4** ("Block-level, non-replaced elements in normal
flow") and **CSS Box Sizing 3 §6.3** ("Sizing Values"):

> The percentage is calculated with respect to the **width of the
> generated box's containing block**.

i.e., `width: 100%` means 100% of the containing block's width, NOT
100% of the font size.

## Empirical reproducer

`Tests/PDF HTML Rendering Tests/BaselineEmpiricalTests.swift` test 8
(currently `.disabled` until fix lands):

```swift
@Test
func `outer table css width(.percent(100)) does not collapse layout box`() throws {
    struct TestView: HTML.View {
        var body: some HTML.View {
            Table {
                TableRow {
                    TableDataCell { "LEFT" }.css.width(.percent(100))
                    TableDataCell { "RIGHT" }
                }
            }
            .css.width(.percent(100))   // ← the trigger
        }
    }
    let right = bytes.tjPositions().first { $0.text.contains("RIGHT") }
    #expect(right!.x > 270)             // currently fails: right.x ≈ 8pt
}
```

**Current behavior**: RIGHT cell renders at relative-Td x ≈ 8pt from
LEFT (vs expected 300+pt for full-width 67/33 split). The table's
layout box collapses to 11pt; A.1' weighted allocation splits 11pt
between two cells (~7pt + 3pt + padding); RIGHT cell starts at
LEFT.x + 7pt + padding ≈ 76 + 8 = 84pt. Empirical `right.x = 8` is the
relative-Td offset from LEFT (absolute = 76 + 8 = 84). All consistent
with a 11pt-wide table.

**Expected behavior (post-fix)**: `width: 100%` interpreted as 100% of
containing block width (= a4 content area, ≈ 451pt). Table renders at
451pt wide; A.1' allocator splits 67/33; RIGHT cell at ~300pt
relative-Td from LEFT.

## Trigger isolation

Five reproducer variants ran with this 2-col table shape, varying
which modifiers/content are applied. Results (RIGHT cell relative-Td
x from LEFT, on a4 content width ≈ 451pt):

| # | Outer width | Outer borderCollapse | Cell verticalAlign | Cell content | RIGHT.x | Status |
|---|-------------|---------------------|--------------------|-----|---------|--------|
| A | 100%        | collapse            | .top               | text         | 8.0     | **broken** |
| B | (none)      | (none)              | (none)             | b+br+text    | (overlap) | **broken** |
| C | (none)      | (none)              | .top               | text         | 300.85  | ✓ |
| D | (none)      | collapse            | (none)             | text         | 300.85  | ✓ |
| E | 100%        | (none)              | (none)             | text         | 8.0     | **broken** |

**Conclusion**: The outer table's `.css.width(.percent(100))` is the
trigger (E broken; D + C show that borderCollapse and verticalAlign
alone do NOT trigger). The cell-level `.css.width(.percent(100))`
hint (Test 2 / A.1' regression test) goes through a SEPARATE recording
path (`captureCellWidthHint` → `columnWidthWeights[idx]`) that
correctly interprets the percentage as a per-column weight; that path
does NOT touch `constraint.width` and is unaffected.

## Impact on factuur-21

`Letter.Header` (coenttb/swift-document-templates) is:

```swift
table {
    tr {
        td { recipient }.css.verticalAlign(.top).width(.percent(100))
        td { sender }.css.verticalAlign(.top)
    }
}.css.width(.percent(100)).borderCollapse(.collapse)
```

The outer `.css.width(.percent(100))` collapses the Letter.Header
table to 11pt wide. Both cells (recipient + sender) render within
this 11pt window, effectively overlapping at the left of the page.
pdftotext's bbox extraction shows recipient lines at `xMin=72-145`
AND sender content (h3 "Ten Thije Boonkkamp", address rows, metadata
rows like `tel`, `kvk`, `iban`) ALSO at `xMin=72-145` — both cells
in the same narrow column.

The vertical "stacking" the user reports is the visual consequence:
the recipient's 5 address lines render top-down at the left edge of
the collapsed table; the sender's h3 + nested table render BELOW the
recipient (still in the same narrow x range), reading top-to-bottom
as one column.

This ALSO contributes to the 3-page factuur-21 output: with the
header table consumed by recipient-then-sender stacked vertically,
page 1 runs out of vertical space partway through the sender; the
remaining sender content (metadata: tel, email, kvk, btw, iban)
either flows to page 2 or pages 2-3 are consumed by the line-items
table that should fit on page 1 if Letter.Header didn't waste so
much vertical real estate.

## Why this didn't appear in earlier reproducers

All earlier reproducers (Test 2 A.1' regression, Test 6 discriminating,
the Phase B sibling-table tests) applied `.css.width(.percent(N))` to
**cells**, not to the **outer table**. Cell-level width hints flow
through `apply(inlineStyle:)`'s recording branch (line 156-160), which
calls `captureCellWidthHint` (line 212-228) and records the percentage
as a column-allocation weight (line 357 of `_pushElement`'s recording
branch). That path does NOT touch `constraint.width` and is correct.

Only the OUTER table's width modifier (which fires BEFORE recording
starts, i.e., before the first `<tr>` push) goes through
`apply(inlineStyle:)`'s NORMAL path (line 162+), which calls
`Width.apply` which writes `constraint.width = size.width` via the
buggy percentage-of-font-size computation.

## Scope of the bug — other percentage modifiers

Per CSS spec, the following CSS properties take a percentage relative
to the containing block's WIDTH (not font size):

- `width`, `min-width`, `max-width`
- `height`, `min-height`, `max-height` — **but relative to containing-block HEIGHT, not width**
- `padding-top`, `padding-bottom`, `padding-left`, `padding-right`,
  `padding` — relative to containing-block WIDTH (per CSS 2.1 §8.4)
- `margin-top`, `margin-bottom`, `margin-left`, `margin-right`,
  `margin` — relative to containing-block WIDTH (per CSS 2.1 §8.3)
- `text-indent`, `left`, `right`, `top`, `bottom` — vary

Properties that DO use font-size as the percentage reference:

- `font-size`: % of PARENT font size — uses currentSize ✓
- `line-height`: % of OWN font size — uses currentSize ✓
- `vertical-align`: % of `line-height` (close to font size)

The `PDF.UserSpace.Size(lengthPercentage:currentSize:baseFontSize:)`
init at `CSS+PDF.UserSpace.Size.swift:65-80` is correct for
font-related contexts but WRONG for width/padding/margin contexts.

Modifiers currently relying on this init for percentage-form lengths:
needs an audit. At minimum `Width`, `Height`, `MinWidth`, `MaxWidth`,
`MinHeight`, `MaxHeight`, `Padding*`, `Margin*` should be reviewed.

## Recommended fix shape

### Narrow fix (preferred for invoice-readiness scope)

Change `W3C_CSS_BoxModel.Width.apply` to handle `.percentage(N)`
explicitly using `context.layout.box.width` as the percentage
reference:

```swift
extension W3C_CSS_BoxModel.Width: PDF.HTML.Style.Modifier {
    public func apply(to context: inout PDF.Context, configuration: PDF.HTML.Configuration) {
        switch self {
        case .lengthPercentage(.percentage(let percentage)):
            // Per CSS 2.1 §10.3.4: width N% is relative to containing-block width.
            context.constraint.width = context.layout.box.width
                * Dimension_Primitives.Scale(percentage.value / 100.0)
        case .lengthPercentage(let lp):
            let currentSize = context.style.fontSize ?? configuration.defaultFontSize
            let size = PDF.UserSpace.Size<1>(
                lp,
                currentSize: currentSize,
                baseFontSize: configuration.defaultFontSize
            )
            context.constraint.width = size.width
        case .auto, .maxContent, .minContent, .fitContent, .fitContentLength, .stretch:
            context.constraint.width = nil
        case .global:
            break
        }
    }
}
```

**Diff shape**: ~7 lines (one new `case` for `.percentage` + delegate
the rest to the existing path). One file: `W3C_CSS_BoxModel.Width+PDF.HTML.Style.Modifier.swift`.

**Impact assessment**:
- Re-enables the disabled Test 8 (`outer table css width(.percent(100)) does not collapse layout box`).
- Should fix factuur-21's Letter.Header rendering, restoring cell side-by-side layout.
- Likely reduces page count (page 1 reclaim of vertical space lost to vertical stacking) — confirmation via `swift run Invoices`.
- Low blast radius: only affects views that use `.css.width(.percent(N))` and previously got the wrong (font-size-relative) width. The cell-level recording path is untouched (separate code path).

**Build-verify plan**:
1. `swift build` + `swift test` in swift-pdf-html-render — verify Test 8 passes; existing tests unchanged.
2. `cd timekeeping && rm -rf .build && swift run Invoices` — verify factuur-21 page count drops (target: 1 page) and Letter.Header recipient + sender render side-by-side.
3. Inspect `pdftotext -bbox-layout` for factuur-21 page 1: sender (h3 + metadata) should appear at xMin ≈ 300+pt (right column), not xMin ≈ 72pt.

### Broader audit (separate dispatch)

The `PDF.UserSpace.Size(lengthPercentage:currentSize:baseFontSize:)`
init returns wrong values for any caller that wants
"percentage-of-containing-block-width" semantics. Audit:

- `Height`, `MinWidth`, `MaxWidth`, `MinHeight`, `MaxHeight` modifiers
  — each one likely has the same bug if it uses the same init.
- `Padding*`, `Margin*` modifiers — same.

This audit + fix is broader and out of scope for the immediate
factuur-21 page-count fix. Surface as a separate finding for future
dispatch.

## References

- `Sources/PDF HTML Rendering/CSS/W3C_CSS_BoxModel.Width+PDF.HTML.Style.Modifier.swift:7-29`
  — the bug site.
- `Sources/PDF HTML Rendering/CSS/CSS+PDF.UserSpace.Size.swift:73-75`
  — the percentage→size conversion (correct for font-size-relative
  contexts; wrong for layout-related).
- `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:540-562`
  — `applyBoxModel`'s `constraint.width` read at line 559-561.
- `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:155-190`
  — `apply(inlineStyle:)` dispatch; recording branch at 156-160 vs
  normal branch at 174+.
- `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:347-367`
  — recording-mode `_pushElement` cell-width capture (correct path,
  unaffected by this bug).
- `coenttb/swift-document-templates/Sources/Letter/Letter.Header.swift:36-46`
  — the consumer pattern that triggers the bug
  (`table { ... }.css.width(.percent(100)).borderCollapse(.collapse)`).
- W3C CSS 2.1 §10.3.4 — width percentage spec.
- W3C CSS Box Sizing 3 §6.3 — sizing values spec.
