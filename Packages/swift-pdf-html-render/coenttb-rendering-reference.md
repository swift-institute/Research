# coenttb-html-to-pdf Rendering Reference — Phase D Inventory

**Status**: RECOMMENDATION (v1.0.0, 2026-05-12)
**Scope**: Phase D cumulative-vertical-spacing investigation per [HANDOFF-013] / [HANDOFF-013a]
**Triggered by**: `HANDOFF-swift-pdf-render-parity.md` §"Phase D Resumption Block" ζ-7
**Authority**: Reference-read only — no edits to `coenttb/*`

---

## Reference Implementation Status

`coenttb/swift-html-to-pdf` is a thin bridge: HTML strings → `WKWebView` → `NSPrintOperation` → Quartz `PDFContext`. It does NOT implement a custom CSS layout engine; layout is entirely delegated to WebKit (macOS Quartz on the render path used for the invoice corpus).

**Reference renderings**:
- `Invoices/100+/20251112/20251003 Ten Thije Boonkkamp factuur 29IOVCDMKT-15.pdf`
  Pages: 1; Producer: `macOS Version 26.0.1 (Build 25A362) Quartz PDFContext`.

**Institute renderings** (post-Phase-B chain, HEAD `2e1032c`):
- `Invoices/100+/20260512/20260507 Ten Thije Boonkkamp factuur 29IOVCDMKT-21.pdf`
  Pages: 2 (target 1; gap ~92pt of cumulative vertical space across page 1).

Because coenttb-html-to-pdf has no custom layout code, the "comparison vs coenttb" reduces to "comparison vs a W3C-conformant browser engine (WebKit)." The reference inventory below cites WebKit user-agent stylesheet defaults and W3C specs as ground truth, with file:line evidence inside the institute graph for every divergence.

**coenttb entry points** (read-only, for orientation):
- `coenttb/swift-html-to-pdf/Sources/HtmlToPdfLive/PDF.Render.Client+macOS.swift:21` — `NSPrintOperation` configuration; paperSize, margins forwarded.
- `coenttb/swift-html-to-pdf/Sources/HtmlToPdfLive/WKWebViewResource.swift` — WKWebView pool; HTML loaded via `loadHTMLString`; PDF emitted via `printOperation`.

---

## Inventory by Axis

### (a) Inter-element vertical spacing

**Browser (WebKit)**:
- Block elements participate in CSS margin collapsing per W3C §8.3.1: vertical margins between adjacent block boxes collapse to `max(top, bottom)`.
- `<br>` is an inline-level element. Between two block elements (e.g., `<table><br><table>`), `<br>` lives in an anonymous inline-formatting-context which has no preceding inline content; the line box is empty. Browsers do NOT advance Y for empty `<br>` in this position.

**Institute swift-pdf-html-render**:
- `PDF.HTML.Context.swift:109-128` — `applyCollapsedMargin` correctly implements W3C max-collapsing.
- `PDF.HTML.Context+Rendering.swift:629-640` — `<br>` ALWAYS advances Y by one line-height when there is no buffered inline content (`runs.isEmpty`). It does not check whether the `<br>` is between two block elements.

**Delta**: A bare `<br>` between two `<table>` elements (or between table and `<p>`) advances Y by ~14pt in institute but 0pt in WebKit. The Invoice template contains 7 such `<br>` instances between block siblings:
- Letter.swift:49 (1 br between Letter.Header and invoice body)
- Invoice.swift:171 (1 br between top header table and metadata table)
- Invoice.swift:195-196 (2 br between metadata table and items table)
- Invoice.swift:283-284 (2 br between totals table and payment paragraph)
- Plus the address-block br inside Letter.Sender's nested table

At ~14pt per advance, this contributes ~84pt of vertical-space overhead that WebKit does not produce.

### (b) Tag-default block margins

**Browser (WebKit user-agent stylesheet)**:
- `table { margin: 0 }` — tables have **zero** default margin. (CSS 2.1 §17.6: tables are display-table block-level elements; the UA stylesheet does not assign vertical margins.)
- `p { margin: 1em 0 }`
- `h1 { margin: 0.67em 0 }`, `h2 { 0.83em 0 }`, `h3 { 1em 0 }`, `h4 { 1.33em 0 }`, `h5 { 1.67em 0 }`, `h6 { 2.33em 0 }`
- `ul, ol { margin: 1em 0 }`; `blockquote { margin: 1em 40px }`; `pre { margin: 1em 0 }`

**Institute swift-pdf-html-render** (`HTML.Element.Tag+TagStyle.swift:97-125`):
| Tag | Institute default | WebKit UA | Delta |
|-----|-------------------|-----------|-------|
| p | 1em / 1em | 1em / 1em | — |
| h1-h6 | per `headingMarginEm` table | matches | — |
| blockquote | 1em / 1em | 1em / 1em (+ 40px horiz) | — |
| pre | 1em / 1em | 1em / 1em | — |
| ul, ol | 1em / 1em | 1em / 1em | — |
| **table** | **1em / 1em** | **0 / 0** | **+12pt top + 12pt bottom per table** |

The `<table>` row at `HTML.Element.Tag+TagStyle.swift:120-121` returns `(1.0em, 1.0em)`. This is the load-bearing divergence: the Invoice template contains 5 top-level `<table>` blocks (Letter.Header outer table; top header; metadata; items; totals); at 12pt+12pt per table, this is 120pt of margin not present in WebKit. Margin collapsing reclaims some of it (adjacent table margins collapse to 12pt) but the first/last edges and br-interrupted boundaries do not collapse.

### (c) Font setup / defaults

**Browser**:
- Default font: per-platform (Times-equivalent on macOS Quartz path).
- Default font size: 16px = 12pt at 72/96 conversion.
- Default `line-height: normal` resolves to ~1.2× for Times (font-metric-derived).

**Institute** (`PDF.HTML.Configuration.swift:133-138`, `:189-196`):
- `defaultFont: .times` — matches.
- `defaultFontSize: 12` — matches (after px→pt conversion).
- `lineHeight: .normal` — resolves to **1.15×** for Standard 14 fonts (when font's leading == .zero, falls back to `1.15` constant — see `:191-194`).

**Delta**: institute renders line-height as 1.15 × 12pt = 13.8pt; WebKit renders Times Roman at ~1.2 × 12pt = 14.4pt. Across ~50 visible lines in factuur-21 page 1, institute's tighter line-spacing should SAVE ~30pt vs WebKit — yet institute still overflows. This means the line-height delta is masking a larger spacing defect elsewhere. **C-10 diagnosis-first**: enumerate hex bytes of first text run in factuur-15 reference vs factuur-21 current to identify font-encoding / font-size / line-height divergence at byte level.

### (d) Cell layout in tables

**Browser**:
- `table-layout: auto` — content-measured allocator; column widths derived from max-content of cells in each column, with shrink-to-fit when total exceeds available width.
- Cells without explicit width participate in auto sizing.

**Institute** (`PDF.HTML.Context+Rendering.swift:680-700` + `Recording.swift` + post-A.1' commit `c443ddf`):
- Column allocation: default = `equalWidth` (bounds.width / columnCount).
- Per-cell `width: N%` hints honored via Recording.pendingCellWidthPercent and proportional allocation (A.1' fix).
- Per-cell length-form width (px/em/cm) NOT consumed — documented gap.
- **No content-measured allocation** — tables without explicit percent hints fall back to equalWidth.

**Delta**: Letter.Sender's nested table (`coenttb/swift-document-templates/Sources/Letter/Letter.Sender.swift:56-76`) has structure:
```
table {
  tr { td {} | td { for line in address { small{line}; br() } } }    // row 1: empty | address
  tr { td(small{key, padding-right:10}) | td(small{value}) }         // metadata rows
  // ... more metadata rows
}.css.borderCollapse(.collapse)
```
No `width(.percent(...))` hint on any cell. Institute allocates 50/50; WebKit allocates by content measurement (column 1 fits longest key ~30pt; column 2 gets the rest ~150pt). Under institute's 50/50, the value column has ~80-90pt; "+31 6 43901430" (phone string, ~75pt rendered width at small/10pt) BARELY fits — and may wrap if the column is even narrower due to outer Letter.Header column allocation.

### (e) Paragraph wrapping (text)

**Browser**: Knuth-Plass-style line-breaker; `white-space: nowrap` suppresses wrap; soft-break on word boundaries; hyphenation per locale.

**Institute** (`PDF.Context.Text.Run+Rendering.swift`):
- Custom greedy line wrapper; honors `white-space: nowrap` via `Mode.noWrap` (A.4 fix, commit `c0c45f6`).
- Wraps on word boundaries within `layout.box.width`.

**Delta**: when column-width allocator (axis d) gives a cell width too narrow for its content, text wraps unnecessarily — observed at C-7 (phone wraps to 2 lines).

---

## Per-Finding Mapping (C-1 through C-10)

| Item | Institute file:line root cause | Proposed institute-shaped fix-shape | Expected impact |
|------|-------------------------------|-------------------------------------|-----------------|
| **C-2** | `HTML.Element.Tag+TagStyle.swift:120-121` — `case "table": return (.length(.em(1.0)), .length(.em(1.0)))` diverges from WebKit UA stylesheet (which has zero margins on `table`). | Change `case "table"` to `return nil` (or `(.zero, .zero)`) — matches WebKit UA. | ~24pt × 5 tables, partially absorbed by margin-collapsing; net ~60-80pt savings expected. Highest single-fix impact. |
| **C-1 / C-8** | `PDF.HTML.Context+Rendering.swift:680-700` — default `equalWidth` column allocator; `Recording.swift` doesn't measure cell content widths. Letter.Sender nested table has no `.width(.percent(...))` hints, so columns split 50/50, wasting column 1. C-8 metadata rows in Invoice.swift top-header (Vervaldatum / Verzonden per email / Inkoopordernummer) share this defect via the same recording-replay path. | Implement content-measured allocator: in Recording, measure each cell's intrinsic content width (longest unbreakable token); when no percent hints, allocate proportionally to content widths with min-width = padding + measured. | High — fixes the sender column visual defect AND likely reclaims vertical space by avoiding multi-line wrapping. |
| **C-6** | `PDF.HTML.Context+Rendering.swift:450-453` — `userOverrodeMargin = pdf.margin.top != nil \|\| pdf.margin.bottom != nil` — when EITHER user-margin is non-nil, BOTH tag-defaults are skipped. Combined with C-2: heading defaults match WebKit (0.67em–2.33em); no actual divergence for headings, but tightening cumulative h1/h2/h3 stack in Invoice (h1 "FACTUUR" at top, possible h3 in sender) requires adjusting `headingMarginEm`. | Two options: (a) Tighten headingMarginEm for h1 only (Invoice template's only heading-of-significance); (b) Audit margin-override partial-set behavior (allow `.margin(top: 0)` to suppress only the top default). | Medium — ~10-16pt per heading instance, depends on headings present. |
| **C-7** | Same root cause as C-1 (cell width allocator). Phone string "+31 6 43901430" needs ~75pt rendered width at `small` (10pt); current column allocator may give it less. | Resolved by C-1 fix. Workaround if C-1 cost-prohibitive: institute-side heuristic for `.whiteSpace(.nowrap)` on short cells — but heuristic introduces drift risk; prefer C-1. | Small (~13.8pt) but visible defect; bundled with C-1. |
| **C-9** | Payment paragraph clip on page 2 — secondary to page-count gap. If factuur-21 reaches 1 page (after C-2 + C-1), the paragraph fits on page 1 and the clip resolves trivially. If not, diagnose remaining overflow at `PDF.HTML.Context+Rendering.swift` page-break path. | Defer; re-assess after C-2 + C-1 land. | Cosmetic on page 2; resolves automatically if primary criterion is met. |
| **C-3** | `tel+31` inter-span whitespace — cosmetic; spans separated by space-eating element transitions. Not page-count-impacting. | Defer (Rev 7.3 addendum acknowledges this). | Cosmetic only. |
| **C-4** | Broader percentage-modifier audit (Height, MinWidth, MaxWidth, MinHeight, MaxHeight, Padding*, Margin*) — same defect class as Width (now fixed at `e10ca52`): percent-of-font-size vs percent-of-containing-block. | Audit each modifier file in `CSS/W3C_CSS_BoxModel.*+PDF.HTML.Style.Modifier.swift`; identify which resolve `.percentage(N)` against containing-block vs font-size; align with W3C semantics. | Pre-emptive; defect-shape audit; defer unless invoice corpus consumers surface. |
| **C-5** | Snapshot rebaselining — mechanical post-fix flush. | Run regen after each C-* commit; commit baseline updates at Phase D close. | Mechanical. |
| **C-10** | Font setup off — specifics TBD. Diagnose-first per brief. | (a) Hex-byte diff: extract first text run bytes from factuur-15 reference (decode `/Contents` stream) vs factuur-21 current; compare encoding (WinAnsi vs PDFDoc vs other), font selection (`Tf` operator), and rendering matrix (`Tm`). (b) Compare line-height: institute 1.15 vs WebKit ~1.2; resolve which is correct per W3C — `line-height: normal` is implementation-defined, but matching WebKit is the parity target. | Variable; could be cumulative across all text. |

---

## Recommended Phase D Wave Ordering

By page-count impact, lowest cost first:

1. **C-2** — Single-line edit to `HTML.Element.Tag+TagStyle.swift:120-121`. Highest expected impact (60-80pt). Lowest risk (one commit; reverts cleanly; margin-collapsing already correct, just need to stop emitting nonzero defaults for `<table>`).
2. **C-10** — Diagnostic phase: hex-byte trace + line-height parity check. May surface a class of fixes or none; either way, defines the cumulative-trim ceiling.
3. **C-1 / C-8** — Content-measured column allocator. Architecturally larger (Recording + finalizeFirstRow modifications) but unblocks C-7 and resolves visible drift.
4. **C-6** — Heading margin tightening or partial-override semantics; small impact; can be deferred if C-2 alone meets criterion #1.
5. **C-7** — Resolved by C-1 in most cases.
6. **C-9** — Re-assess after primary criterion met.
7. **C-3, C-4, C-5** — Defer or mechanical close.

---

## Out of Scope (Confirmed)

- `coenttb/*` edits — read-only per resumption block.
- `tenthijeboonkkamp/timekeeping/Sources/Invoices/[InvoiceData].hundredPlus.swift` — pre-session user WIP.
- Pre-session WIP PDFs at `Invoices/100+/20260211/`, `/20260511/`, `Invoices/DemenTree/20260211/`.
- FROZEN institute packages outside the `swift-pdf-render` + `swift-pdf-html-render` + `swift-iso-32000` + `swift-html-render` set.
- Re-architecting Render protocol; modifying `swift-render-primitives` or `swift-html-render`.

---

## Cross-References

- `HANDOFF-swift-pdf-render-parity.md` §"Adjudication Addendum — Revision 7.8" (C-1–C-10 backlog source).
- `css-fidelity-gap-inventory.md` (broader CSS-fidelity inventory; this doc focuses on Phase D's specific cumulative-trim slice).
- `css-width-percentage-misinterpretation.md` (Phase B Width fix; pattern reference for C-4 percentage-modifier audit).
- `modifier-dispatch-ordering.md` (A1/A2 axes; reference for C-10 font-setup diagnosis if dispatch ordering implicated).
- `pdf-text-encoding-trace.md` (ISO 32000-2 §7.9.2.2 encoding; reference for C-10 hex-byte diagnostic).
