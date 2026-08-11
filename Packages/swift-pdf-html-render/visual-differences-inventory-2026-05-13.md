# Visual Differences Inventory — factuur 29IOVCDMKT-21 (institute swift-pdf vs Quartz reference)

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: INVENTORY
---
-->

## Context

Phase E continuation of the `HANDOFF-swift-pdf-render-parity.md` arc. Two prior chats (Round 4.2.x and Round 4.3) accumulated heavy context investigating the institute swift-pdf rendering of `Invoice` templates. User adjudication 2026-05-13: separate the diagnostic *inventory* (this document) from the *fix* work (subsequent chat). This doc is the inventory.

## Question

What are the empirical, observable visual differences between:

| Slot | Path | Producer | Page size | Pages |
|---|---|---|---|---|
| REF (target) | `Invoices/100+/20260211/20260211 Ten Thije Boonkkamp factuur 29IOVCDMKT-21.pdf` | macOS Quartz PDFContext (via `coenttb/swift-html-to-pdf` WebKit bridge) | 595 × 961 pt (custom, +119pt vs A4) | 1 |
| WIP | `Invoices/100+/20260512/20260507 Ten Thije Boonkkamp factuur 29IOVCDMKT-21.pdf` | institute `swift-pdf` chain at swift-pdf-html-render HEAD `0039040` | 595.276 × 841.89 pt (A4) | 2 |

Both render the same `Invoice.swift` HTML body via the same upstream `coenttb/swift-document-templates` templates. The page-count delta (1 vs 2) is accepted per user adjudication 2026-05-13 as a structural reality of the +119pt-taller REF page; this inventory does **not** treat page count as a defect.

## Methodology

Pure observation. For each distinguishable text element across both PDFs:

1. **Visual rendering** — `sips -s format png … --out …` then read PNG.
2. **Logical/positional extraction** — `pdftotext -bbox-layout` for bbox per block / line / word.
3. **Raw operator extraction** — Python+zlib inflate of content streams, then locate `cm`/`Tm`/`Td`/`Tj`/`TJ` operators for baseline-precise positions and per-glyph kerning shape.
4. **Font inventory** — `pdffonts`.

Reference Tj-baseline positions are top-down Y (i.e. `pageHeight - PDF_native_Y`). WIP positions are reported directly in top-down Y where bbox-layout already converts.

**Confounder noted up front**: `pdftotext` consolidates Tj operators wrapped in `/ActualText` `BDC`/`EMC` spans into a single logical word, even when the renderer emitted two separate Tj operators with an intervening `0 -lineHeight Td` (a wrap-line-break). Reading bbox values alone hides several WIP visible wraps. Where this matters the raw operator stream is cited; bbox is supplementary.

## Empirical inventory

### Quick reference — corpus-wide facts

| Axis | REF | WIP | Source |
|---|---|---|---|
| Page width (pt) | 595.000 | 595.276 | `pdfinfo` |
| Page height (pt) | 961.000 | 841.890 (A4) | `pdfinfo` |
| Total pages | 1 | 2 | `pdfinfo` — **accepted, not a defect** |
| Pages-1 content density | All content fits 961pt | Bedrag+BTW fit p1; Totaalbedrag + payment paragraph spill to p2 | visual / `pdftotext -layout` |
| Producer | `macOS Version 26.2 (Build 25C56) Quartz PDFContext` | (none) | `pdfinfo` |
| PDF version | 1.4 | 1.7 | `pdfinfo` |
| Body text font | `AAAAAC+.SFNS-Regular_wdth_opsz110000_GRAD_wght` (and bold sibling), TrueType subsets, **embedded** | `Helvetica` + `Helvetica-Bold`, Type-1 base-14, **not embedded** | `pdffonts` |
| Body text size | 14pt | 12pt | raw `Tm` operator (REF), `Tf` operand (WIP) |
| Small / sender body | 11.2pt | 9.96pt | raw operators |
| Sender H3 (name) | 16.38pt bold | 14.04pt bold | raw operators |
| H1 "Factuur" | 28pt bold (TT3 subset) | 24pt bold (Helvetica-Bold) | raw operators |
| Line-height (recipient block) | 21pt baseline-to-baseline = 1.5× | 13.8pt baseline-to-baseline = 1.15× | Td-y deltas / cm-Y deltas |
| Page left margin (body content) | 49pt (left text), 48pt (payment paragraph) | 40pt | bbox X-min of left-column blocks |
| Encoding for `€` / `ë` | Tj bytes via TT4 subset CMap (REF); ActualText UTF-16BE BOM | Tj `0x80` (WinAnsi €), `0xEB` (ë); ActualText UTF-16BE BOM correct | raw Tj bytes (hex) |

No encoding mojibake observed in either PDF.

---

### Category: FONT — typeface, weight, embedding

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| F1 | Body font typeface differs | Apple SFNS / SF Pro variable axis | Helvetica base-14 (Type 1) | family change | **HIGH** — letterforms visibly different (SF Pro is geometric / closed apertures; Helvetica is grotesque / open). At-a-glance distinguishable. | `HTML.Document.document.swift:68` declares `font-family: ui-sans-serif, -apple-system, Helvetica Neue, Helvetica, Arial, sans-serif`. WebKit/Quartz resolves `ui-sans-serif` → SF UI/Pro; institute Helvetica fallback is configured at consumer site `timekeeping/Sources/Invoices/main.swift` `e724a08 / 104f3d0`. | Institute renderer treats `font-family: ui-sans-serif` as un-resolvable and falls back to Helvetica per `PDF.HTML.Configuration.defaultFont`. SFNS not available in PDF base-14 set; institute has no embed pipeline for `ui-sans-serif` resolution → font-family CSS string is effectively ignored. investigate `swift-pdf-html-render` Tag/Style modifier for `font-family`. |
| F2 | Body font weight: subtle weight axis differences | TT1 / TT2 / TT3 distinct subsets, including TT3 specifically for "Factuur" H1 with different `wght` axis; TT4 / TT5 subsets carry only `€` glyph at body-vs-bold weights | Helvetica + Helvetica-Bold only; the `€` glyph is drawn from the same Helvetica / Helvetica-Bold font as surrounding text | weight axis collapsed | Medium | normalize.css `b, strong { font-weight: bolder }`; Letter.Sender L53 `h3 { name }.css.margin(top: 0).margin(bottom: 0).textAlign(.right)` is bold-by-tag-default | Institute has no variable-font axis support; one regular + one bold for any given family. No defect for invoice content but loses the H1-distinct weight REF carries. |
| F3 | Per-glyph kerning shape | REF uses `TJ` arrays with per-glyph adjustments e.g. `[ (Te) -92 (n) -93 ( ) -92 (T) -93 (h) ... ]` for "Ten Thije Boonkkamp"; visible micro-tight tracking. Also character-spacing `Tc -0.0105`..`-0.1141` set per BT block. | WIP uses flat `Td` between word-blocks, no kerning array; default character spacing `Tc 0` throughout. | full kerning loss | Medium — visible at H1 / H3 sizes (looser tracking in WIP) | None — typography intent baked into Quartz's font rendering. | Institute renderer does not emit `TJ` arrays for kerning, only `Tj` per word with `Td` x-advances. Cumulative tracking on H1/H3 visibly looser. |

---

### Category: SIZING — font sizes and line heights

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| S1 | Body text size smaller in WIP | 14pt | 12pt | −2pt (−14.3%) | **HIGH** — affects every line of every block | normalize.css default for html font-size; `HTML.Document.document.swift:97-107` declares two `@media only screen` queries: `min-width: 832px → 16px` else `max-width: 831px → 14px`. WebKit/Quartz at A4 width (~793px @96dpi) matches `max-width: 831px` ⇒ 14px ≈ 14pt. | Institute does not evaluate `@media` queries → falls back to `PDF.HTML.Configuration.defaultFontSize`. Round 4.3 commit `0039040` reverted this to 12pt institute default; consumer-side `e724a08` (timekeeping `Sources/Invoices/main.swift`) sets `defaultFontSize: 14` but the WIP PDF on disk was generated at snapshot `2aa49d7` BEFORE `e724a08` landed. Effective WIP fontSize = 12pt. |
| S2 | Sender block (small) size smaller | 11.2pt | 9.96pt | −1.24pt | **HIGH** — recipient column visibly tighter | `small { font-size: 80% }` per normalize.css L65; Letter.Sender L61 `small { line }` and L69 `small { key }`. 80% × 14 = 11.2; 80% × 12 ≈ 9.6 (WIP renders 9.96, rounded). | Downstream effect of S1 — `small` correctly scales but propagates the smaller base. |
| S3 | Sender H3 (name) smaller | 16.38pt bold | 14.04pt bold | −2.34pt | Medium | normalize.css L65: `h3` follows browser default (~1.17em). 1.17 × 14 = 16.38; 1.17 × 12 = 14.04. | Downstream of S1. |
| S4 | H1 "Factuur" title smaller | 28pt bold (TT3) | 24pt bold (Helv-Bold) | −4pt | Medium | normalize.css L65: `h1 { font-size: 2em }`. 2 × 14 = 28; 2 × 12 = 24. Invoice.swift:130 `h1 { "\(TranslatedString.invoice.capitalized)" }.css.margin(top: 0).margin(bottom: 0)`. | Downstream of S1. |
| S5 | Body line-height ratio | 21pt for 14pt = 1.5× | 13.8pt for 12pt = 1.15× | −0.35× ratio (−7.2pt baseline-to-baseline) | **HIGH** — tighter WIP makes every text block visibly more compressed; also a load-bearing contributor to the 2-vs-1-page outcome | `HTML.Document.document.swift:69` declares `html { ... line-height: 1.5; ... }`. The normalize.css preamble L65 declares `html { line-height: 1.15 }`. Cascade: normalize first, then document override = 1.5 wins for WebKit. | Institute renderer does not evaluate the second style block override; appears to take the normalize.css `1.15` directly. Round 4.3 commit `e7da3dc feat(line-height): default normal line-height 1.15 → 1.2` shifted base default toward 1.2 but does not pick up the document-level 1.5 override. investigate `swift-pdf-html-render` `LineHeight+PDF.HTML.Style.Modifier.swift` reading. |
| S6 | Sender contact-row baseline-to-baseline | 23pt between rows | 21.8pt between rows | −1.2pt | Low | sender CSS in Letter.Sender L66-74: rows in inner table; each `tr` consumes a row of metadata. Line-height inheritance from html. | Slightly tighter WIP. |
| S7 | Sender address sub-block baseline-to-baseline | 21pt | 13.8pt | −7.2pt | Medium | `small { line }; br()` repeated 3× for the 3 address strings. line-height 1.5 (REF) vs 1.15 (WIP) applied to the *parent's* leading. | Downstream of S5. |
| S8 | "Factuur" H1 to "Cliëntnummer" row | Factuur baseline Y=330, Cliëntnummer baseline Y=318 (H1 baseline is BELOW the meta row's baseline → bottom-aligned 2-col layout) | Factuur baseline Y=373.5, Cliëntnummer baseline Y=372.7 — also bottom-aligned, but the WHOLE block sits ~43pt lower than REF | (positioning effect, see P9) | Medium | Invoice.swift:127-169: outer `table` with `tr { td { h1 "Factuur" }.css.verticalAlign(.top).width(.percent(100)); td { meta-table } }.css.verticalAlign(.bottom)`. Both `verticalAlign(.top)` on H1 cell and `verticalAlign(.bottom)` on row → REF takes the H1 to top of cell and meta-rows to bottom; WIP appears similar layout but downstream position is lower due to taller header block. | See L1 / S7 / S5 cumulative. |

---

### Category: POSITIONING — X positions and column allocation

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| P1 | Page left margin | 49pt (body) / 48pt (payment) | 40pt | −9pt left-shift across the entire WIP layout | Medium — content visibly hugs the left edge tighter | None obvious in coenttb/normalize.css; defaults likely from `body { margin: 0 }` (normalize) + UA/configuration page margin. | Institute renderer's default page margin (PDF.HTML.Configuration page margins) differs from Quartz's print margin. investigate `PDF.HTML.Configuration` `margins:` defaults. |
| P2 | Recipient column width (in flow, top-left) | ~219pt (49 → 268) | ~179pt (40 → 219) | −40pt | Low — only affects very long lines (would wrap if narrower) | Letter.Header L40: `td { recipient }.css.verticalAlign(.top).width(.percent(100))`. The 100% on left cell pushes right column to natural width, leaving most of the page for left. | Column-width allocation: post-Phase-B-Width-fix the outer Letter.Header LEFT cell gets ~84% (REF) vs ~76% (WIP) of available content width. May trace to consumer `Sources/Invoices/main.swift` page-margin diff propagating to content width. |
| P3 | Sender H3 ("Ten Thije Boonkkamp") right-edge | xMax ≈ 546 (49pt from right edge of 595pt page) | xMax ≈ 555 (40pt from right edge of 595pt page) | +9pt right-shift | Low — symmetric to P1 page margin | Letter.Sender L53 `.css.textAlign(.right)` on h3. | Page margin difference (P1) shifts everything right-aligned. |
| P4 | Sender body value column origin | xMin = 400.25 (consistent across all metadata rows) | xMin = 484.18 (consistent across all metadata rows) | +84pt rightward | **HIGH** — directly causes wraps F1/L1/L2/L3 below | Letter.Sender L56-65: inner table with `td {}` empty first cell, `td { for line in address { small{line}; br() } }` second cell. Column-width allocator decides where col-2 starts. | Institute content-measured column allocator (Round 2b.2 `4ac885c` + `bfa6afe` + `532f533`) measures column widths from cell content. Empty first cell + label cells of variable width → col-2 origin pinned far right. Trace `applyBoxModel` / `popTableCell` / `popTableRow` column-width logic in `PDF.HTML.Context+Rendering.swift`. |
| P5 | Sender label column right-edge | x ≈ 389.2 (consistent across all label rows; right-aligned) | x ≈ 476.18 (consistent; right-aligned) | +87pt rightward | Medium | Letter.Sender L69 `.css.textAlign(.right).verticalAlign(.top).padding(right: .px(10))` | Downstream of P4 column allocator decision. Padding-right 10px appears honored (484.18−476.18 ≈ 8pt ≈ 10px×72/96). |
| P6 | Available sender body value width | 595−400.25 = 194.75pt | 595.276−484.18 = 111.10pt | −83.65pt narrower | **HIGH** — direct cause of multiple wraps (L1, L2, L3) | Letter.Sender outer table is wrapped in `Letter.Header`'s right-side cell which has natural width. | Combined effect of P4 column-allocator pinning and P1 page margin. |
| P7 | Factuur meta block X origin | x = 310.25 (label start), x = 438.53 (value start) | x = 259.22 (label start), x = 348.90 (value start) | −51pt leftward shift for the entire meta block | **HIGH** — block visibly mis-positioned ~138pt from right page edge instead of ~95pt as REF | Invoice.swift:135-166: meta table inside h1's row's right cell. `td { h1 "Factuur" }.css.verticalAlign(.top).width(.percent(100))`. | Outer table column allocator gives wider H1 cell in REF (forcing meta to right) but narrower in WIP. Likely interacts with the `.css.width(.percent(100))` on the H1 cell — the post-Width-fix flows the percent through column allocator but result is different from Quartz. Round 4.3 P7 identifies this. |
| P8 | Factuur meta label-to-value gap | "Cliëntnummer" label X=310.25 ends ~408 (~98pt wide) → value at X=438.53 ⇒ ~30pt label-to-value gap. For "Factuurnummer" (slightly wider label): similar generous gap. | Label X=259.22 to value X=348.90 = 89.68pt span. "Cliëntnummer" at 12pt Helv-Bold ≈ 80pt wide → 9.7pt gap. "Factuurnummer" at 12pt Helv-Bold ≈ 84pt wide → 5.7pt gap. | label-to-value gap insufficient | **HIGH** — produces "Factuurnummer21" visually GLUED in WIP (pdftotext also reports them as single word) | Invoice.swift:139 `td { b { "Cliëntnummer" } }.css.padding(right: .px(15))`. The 15px right-padding on each label cell is intended to space label from value. | Column-width allocator does not factor max-content of all label cells when computing the value-column origin. Investigate single-row-table allocator behavior — Round 4.3 P8 and `4ac885c`/`bfa6afe`/`532f533` shrink-to-fit work overlap. |
| P9 | Vervaldatum block label-to-value gap | label X=49 ends ~130 → value X=196.2 → ~66pt gap | label X=40 ends ~107 → value X=122.36 → ~15pt gap (but visible PNG shows the gap is preserved differently — value column ~83pt wide gap to next col? See raw) | (raw Td: `82.36 0 Td (8) Tj` — i.e. value at label-X + 82.36 = 122.36) | **HIGH** — Round 4.3 P8 documents this as "single-row-table label-value gap over-wide"; visible PNG shows huge gap because allocator over-allocates after `padding(right: .px(15))` measurement | Invoice.swift:175-181 `td { "Vervaldatum" }.css.padding(right: .px(15)); td { "11 maart 2026" }`. | Single-row table allocator (1-row 2-col with one row) over-allocates label column when value is short. Round 4.3 priority 2 / Root Cause #7. |
| P10 | Items table X origin | First column "Omschrijving" at X=51 | First column "Omschrijving" at X=40 | −11pt | Low — page margin (P1) propagates | Items table at Invoice.swift:198+ has no per-table left positioning; inherits page/body left margin. | Downstream of P1. |
| P11 | Items table column X positions | Aantal X=275.64, Eenheid X=338.09, Tarief X=411.34, BTW% X=483.02 | Aantal X=245.07, Eenheid X=321.85, Tarief X=409.77, BTW% X=482.82 | varies per col; cumulative −10..−30pt | Low — within typical printable variance | Invoice.swift:200-213: thead row of 5 `td`s with `.css.padding(right: .px(15))`. | Column allocator computes widths from header + body row content; difference traces to font width (Helvetica vs SFNS) and to padding consumption. |
| P12 | "Factuur" H1 baseline | Y_top ≈ 330pt | Y_top ≈ 373.5pt | +43.5pt downward shift | Medium | Invoice.swift:130. | Cumulative: tighter top section (L1+L2+L3 wraps in sender block + S5 line-height) is forcing more vertical real estate, pushing Factuur down. Or, top-of-Factuur-block has additional margin in WIP. |
| P13 | Bedrag/BTW/Totaalbedrag X-axis | Label X=336.11, value X=468.84 (~132pt label-value span) | Label X=334.28, value X=441.98 / X=445.98 (~108-112pt label-value span) | label X within 2pt; value X −23pt leftward | Medium | Invoice.swift:255-281 totals table inside an outer `tr { td {}.css.width(.percent(100)); td { inner table } }.css.borderCollapse(.collapse)`. | Different column allocation in inner totals table; value column origin different. |

---

### Category: SPACING — inter-section vertical gaps

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| G1 | iban-row → "Factuur" H1 gap | iban baseline Y_top=224, Factuur baseline Y_top=330 ⇒ ~106pt gap | iban baseline Y_top ≈ 274, Factuur baseline Y_top ≈ 373.5 ⇒ ~99pt gap | −7pt; broadly similar | Low | Letter.swift L42-50 emits `Letter.Header` then `br()` then `_body` (the invoice content). Letter.Header trailing content + br + Invoice's outer table. | Similar block-level spacing handling. |
| G2 | Factuur-meta → Vervaldatum block gap | Factuurdatum row Y_top=368 → Vervaldatum Y_top=415 ⇒ 47pt | Factuurdatum row Y_top ≈ 415 → Vervaldatum Y_top ≈ 463 ⇒ ~48pt | +1pt; similar | Low | Invoice.swift:171 `br()` between the meta table and the metadata table. | Similar. |
| G3 | Vervaldatum block → Items table header gap | Vervaldatum block bottom (Inkoopordernummer) Y_top=479 → Omschrijving Y_top=549 ⇒ 70pt | Vervaldatum block bottom (Inkoopordernummer) Y_top ≈ 535 → Omschrijving Y_top ≈ 596 ⇒ ~61pt | −9pt | Low | Invoice.swift:195-197 `br(); br()` between metadata table and items table. | Subtle inter-block compression in WIP — different `br()` advance increment. |
| G4 | Items table → totals block gap | Last items row (week 5) Y_top ≈ 674 → Bedrag excl. BTW Y_top=718 ⇒ ~44pt | Last items row (week 5) Y_top ≈ 730 → Bedrag excl. BTW Y_top ≈ 775 ⇒ ~45pt | +1pt; similar | Low | Invoice.swift:253 `hr().body` between items table and totals table. | hr() height + table-bottom-margin behavior similar. |
| G5 | Totals block internal row spacing | Bedrag excl. Y_top=718, BTW Y_top=744.5, Totaalbedrag Y_top=771 ⇒ 26.5pt + 26.5pt | Bedrag excl. Y_top=775 (page1), BTW Y_top=797 (page1), Totaalbedrag Y_top=51.6 (page 2) ⇒ 21.8pt + (page break) | −4.7pt for first internal gap; page-break inserted between BTW and Totaalbedrag (because page1 vertical budget is exhausted) | **HIGH** — Totaalbedrag separated by page break from its peers; payment paragraph also on page 2 | Invoice.swift:255-280 inner totals table with 3 rows. | Cumulative-vertical-spacing budget exhausted in WIP page1 before Totaalbedrag fits; page-break splits the block. Trace to S5 (line-height 1.15 vs 1.5) + other accumulated trim. |
| G6 | Payment paragraph start gap from totals | Totaalbedrag Y_top=771 → Payment line 1 Y_top=852 ⇒ 81pt | (totals on page 2 Y_top=51.6; payment line 1 on page 2 Y_top=109.05) ⇒ ~57.5pt | −23.5pt | Medium — visible in vertical rhythm | Invoice.swift:283-310 `br(); br()` then `p { ... }`. | Different br()-advance accumulation post-page-break vs in-flow. |
| G7 | Recipient block first-line Y_top (top page margin) | 65pt from page top (baseline 51 from top of bbox + 14pt ascent) | 61.97pt from page top (baseline 53.35 from top of bbox + ~8pt ascent for 12pt font) | −3pt; close | Low | UA / page-margin baseline | Similar page top-margin. |

---

### Category: LAYOUT — table structures and wrapping behaviors

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| L1 | Sender address lines wrap mid-row | "Melissekade 114" on 1 line. "3544 CV Utrecht" on 1 line. "Nederland" on 1 line. | "Melissekade" then `0 -13.8 Td` then "114" — i.e. "114" wraps to new line. "3544 CV" together, then "Utrecht" wraps. "Nederland" alone. | 3 visible lines become 5 visible lines | **HIGH** — first-glance wrap defect | Letter.Sender L60-63 `for line in self.address { small { "\(line)" }; br() }` — each address line is one `<small>`. The string itself contains spaces (e.g. "Melissekade 114"). | Column width (P6 = 111pt) insufficient for some `small{}` content widths at Helv-9.96pt. Renderer splits on whitespace when content exceeds `context.layout.box.width`. Trace `PDF.Context.Text.Run.render(into:)` wrap branches (case `.ascii.space`) in swift-pdf-render. |
| L2 | tel value wraps | "+31 6 43 90 14 29" on 1 line | "+31 6 43 90 14" / "29" — last word wraps to new line | wrap break | **HIGH** — phone visibly broken | Letter.Sender L67-72: metadata row `td { small { value } }`. `iban` value already has `.css.whiteSpace(.nowrap)` (Invoice.swift:298) but `tel` value does NOT. | Same root as L1 (column too narrow + value contains internal whitespace). Round 4.3 W1 / P6 references. |
| L3 | iban value wraps | "NL47 BUNQ 2038 5375 42" on 1 line | "NL47 BUNQ" / "2038 5375 42" wrap | wrap break | **HIGH** — iban visibly broken across 2 lines IN THE SENDER block (the payment-paragraph iban via `.css.whiteSpace(.nowrap)` Invoice.swift:298 stays on one line, post-A.4) | Letter.Sender metadata loop. `iban` row has no special whitespace-nowrap CSS in Letter.Sender (only the payment-paragraph instance in Invoice.swift does). | Column too narrow. |
| L4 | "Verzonden per email" label wraps | "Verzonden per" line 1 / "email" line 2 (wraps WITHIN label cell — REF column allocator's label-column width forces this) | "Verzonden per email" on 1 line (WIP label column wider) | REF wraps, WIP doesn't (inverted from L1/L2/L3) | Medium | Invoice.swift:184-191: metadata loop with `td { "\(key)" }.css.padding(right: .px(15))`. | Inverse direction of L1-L3: REF *constrains* label col more, WIP gives it ample width. Possibly tied to S1 (REF body 14pt vs WIP 12pt). |
| L5 | Vervaldatum value "8 juni 2026" wraps | "11 maart 2026" on 1 line (value col wide) | "8 juni" / "2026" wraps | wrap break | **HIGH** — date visibly broken | Invoice.swift:177-181. Single-row table. | Single-row table value column too narrow (P9). Round 4.3 P8 covers this. |
| L6 | "Factuurnummer21" glued in meta header | "Factuurnummer" + ` ` + "21" with visible padding | "Factuurnummer21" (label + value visually concatenated; no internal space; pdftotext reports as one word) | one whitespace lost visually | **HIGH** — clearly broken at-a-glance | Invoice.swift:139, 146, 153: each label `td { b { name } }.css.padding(right: .px(15))`. | Column allocator gap between label-column right-edge and value-column left-edge is < 1 space-width for the widest label. The `padding(right: .px(15))` per-cell doesn't ensure inter-cell whitespace; result depends on allocator. Round 4.3 P7. |
| L7 | Totals block "Bedrag excl. BTW €6.004,62" — different column-width allocation; Tj advance from "BTW" end to "€" start is tight ~5pt | "BTW" ends ~451 → "€" starts at 469 ⇒ 18pt gap (clear separation) | "BTW" ends ~377 → "€6.004,62" starts at 442 ⇒ 65pt gap; but the value is much further right; the inner total table column-2 is at X≈441.98 | gap shape totally different — not just a magnitude diff | Medium | Invoice.swift:263 `td { "Bedrag excl. BTW" }.css.whiteSpace(.nowrap).padding(right: .px(15))`. | Differential column allocation in nested table. |
| L8 | "BTW" "Totaalbedrag" row column-2 X | Same as L7 row column (X=468.84) | Same as L7 row column (X=441.98 page1; X=445.98 page2 totaalbedrag) | column-X differs by ~3pt between BTW row and Totaalbedrag row in WIP (REF identical) | Low | Inner totals table 3 rows; Invoice.swift:260-278. | Per-row independent column allocation in WIP — column origin not consistent across the 3 rows. May trace to the Round 4.3 P8 `4ac885c`/`bfa6afe`/`532f533` single-row-allocator changes interacting with multi-row context. |

---

### Category: DETAILS — borders, rules, weights, underlines

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| D1 | Items thead bottom rule color | Light gray (rgb 0.83,0.83,0.83 stripe 1pt + rgb 0.17,0.17,0.17 anchor 1pt; layered effect — top edge slightly darker) | Pure black (RGB 0,0,0) 0.75pt | color diff; thickness diff | Medium | Invoice.swift:214 `tr { ... }.css.border(.bottom, width: .px(1), style: .solid, color: .init(light: .hex("000")))`. The HEX("000") is pure black. | REF Quartz applies anti-aliased layered render of 1pt border; WIP renders crisp 0.75pt black. Per-side border modifiers landed in `b7a84d6` use the explicit color and width but the result thickness in WIP is 0.75pt — investigate where the 0.75pt default originates (institute Configuration.Table.Border.width default was 0.5→0 per A.3; per-side may have its own default). |
| D2 | Items table bottom rule (above totals) | Thin black 1pt rule with subtle anti-aliased top edge; from `hr()` Invoice.swift:253 | Gray (RGB 0.5,0.5,0.5) 1pt at Y=115.94 | color diff (gray vs near-black); same thickness | Medium | Invoice.swift:253 `hr().body` between items table and totals table. normalize.css L65 `hr { box-sizing: content-box; height: 0; overflow: visible }`. | WIP `<hr>` color default differs from REF Quartz. investigate institute Tag/Style default for `hr`. |
| D3 | "BTW" value underline (double line) | UNDERLINE: two horizontal lines below "€ 1.260,97" — REF rendered as two thin black strokes at y=211 and y=209 (`468 211 m 544 211 l 544 210 ... 468 210 m 544 210 l 544 209 ...`); thickness ≈ 0.5pt each | UNDERLINE: two horizontal lines below "€ 1.260,97" — WIP rendered as two black strokes at y=39.09 and y=37.59 (separation ≈ 1.5pt); both width 0.75 | similar two-stroke double underline but separation 1pt vs 1.5pt | Low | Invoice.swift:271 `td { "\(self.rows.totalVAT.formatted(.euro))" }.css.border(.bottom, width: .px(3), style: .double, color: .init(light: .hex("000")))`. `border-style: double` per CSS Backgrounds §3.5: two parallel strokes width/3 thick with gap width/3. 3px ⇒ 1pt strokes, 1pt gap. | REF rendered 2 thin parallel strokes for `style: .double`; WIP `6dd2bbb feat(borders): implement border-style: double per CSS Backgrounds §3.5` — but WIP strokes width 0.75 vs spec 1pt; gap 1.5pt vs spec 1pt. May be a parameter mis-application — empirical separation 1.5pt corresponds to total stroke-bundle width ~1.5+0.75+0.75 = 3pt = nominal 3px width, so the total span is right but the W3C-spec partition (each part = width/3) is off. |
| D4 | Recipient block top thin gray rule (Quartz 271pt line) | A horizontal rule at y=271-272 (page coords from bottom; 690pt top-down) is rendered by REF (`48 272 m 547 272 l 547 271 l 48 271 l h f`) — appears to be a separator between recipient and "Factuur" sections; light gray | Not present in WIP | rule present in REF, absent in WIP | Low — visually subtle | Quartz-generated; from coenttb-html-to-pdf rendering pipeline. Not directly Invoice.swift; possibly a WebKit/Quartz print decoration or template artifact. | Confirm if intended visual element or Quartz print artifact; not load-bearing for parity since user did not flag. |
| D5 | "Totaalbedrag" weight | Bold (TT1 + TT5 €-glyph subset); larger visual weight | Bold (Helv-Bold) | similar but font axis differs | Low | Invoice.swift:275 `td { b { "\(TranslatedString.totalAmount.capitalized)" } }`. | Both bold; render diff is downstream of F1/F2. |
| D6 | "€ 150,12" Euro-glyph weight | Drawn from separate TT4 subset (italic? oblique?); appears slightly different from main body weight | Drawn from same Helvetica as surrounding digits; uniform appearance | weight/style diff for € only | Low | normalize.css does not single out €; the variant comes from Quartz font selection logic. | Quartz uses a € fallback font (TT4 sub) when SFNS subset doesn't carry the glyph; WIP Helvetica base-14 has € at byte 0x80 directly. |

---

### Category: COLOR

| ID | Defect | REF value | WIP value | Δ | Perceptibility | CSS source clue | Suspected institute root cause |
|---|---|---|---|---|---|---|---|
| C1 | Body text color | RGB 0.17 0.17 0.17 (very dark gray, `0 0 0 sc` for text but `/Cs1` color space applied — `q /Cs1 cs 0 0 0 sc /Gs1 gs` — black with transparency state) | RGB 0 0 0 (pure black `0 g`) | dark gray vs pure black; difference visible only side-by-side | Low | `html`/`body` CSS does not set color; default black. | Quartz print uses slight gray text by default; WIP uses pure black. |
| C2 | Items header bottom-rule + recipient-block top-rule color (already in D1/D4) | Gray (0.83) and dark gray (0.17) layered | Pure black | already covered | (already covered) | (see D1) | (see D1) |

No background-color or fill-color differences observed.

---

## Cross-cutting observations and root-cause clusters

### Cluster CC1 — Page-margin propagation (1 defect group)
P1 (page left margin) propagates to P3 (sender H3 right-edge), P10 (items table X), P13 (totals X). Single-source: institute renderer's default page margin (probably `PDF.HTML.Configuration` defaults). Fixing P1 collapses ~4 visible deltas.

### Cluster CC2 — Font-size cascade (4 defect group)
S1 (body font 14pt → 12pt) propagates to S2 (sender body 11.2 → 9.96, via `small{}` 80%), S3 (H3 16.38 → 14.04, via 1.17em), S4 (H1 28 → 24, via 2em). Single-source: institute does not evaluate `@media only screen and (max-width: 831px)` queries which set body to 14px in REF. Snapshot was generated before consumer-side `e724a08 defaultFontSize: 14` landed; current institute default of 12pt remains in the WIP under inspection.

### Cluster CC3 — Line-height cascade (3+ defect group)
S5 (body line-height 1.5 → 1.15) propagates to S7 (sender address 21 → 13.8), S6 (sender contact 23 → 21.8). Combined with CC2, drives most of the vertical-real-estate gap that causes G5 (Totaalbedrag page-break). Single source: `HTML.Document.document.swift:69` `line-height: 1.5` document-level override of normalize.css `line-height: 1.15` not honored by institute renderer.

### Cluster CC4 — Column allocator allocates RIGHT-COLUMN-NARROW (4+ defect group)
P4 (sender body value col origin x=484 vs x=400) → P5 (label col x=476 vs x=389) → P6 (available value width 111pt vs 195pt) → L1 (address wraps), L2 (tel wraps), L3 (iban wraps), L5 (vervaldatum value wraps), L6 (Factuurnummer21 glued), L7 (totals column-2 X positions), L8 (per-row column-2 inconsistent). Single (likely) root: the institute content-measured column allocator (Round 2b.2 `4ac885c` + `bfa6afe` + `532f533` shrink-to-fit + max-content-of-cells uses MAX-of-logical-lines work) makes the right column too narrow for nested-table contexts where labels are right-aligned with small widths. Fixing the allocator's single-row + label-aware logic could collapse ~7 visible defects.

### Cluster CC5 — Factuur meta block position (2 defect group)
P7 (meta block X=259 vs X=310) and L6 (Factuurnummer21 glued) likely share root in the outer-table column allocator for the H1+meta row. The h1 cell has `.css.verticalAlign(.top).width(.percent(100))` but the meta cell has no explicit width; the percent on h1 should claim all leftover space to push meta as far right as possible — institute appears to give meta MORE space than it needs (pushing it left and squeezing the inner-meta-table label-value gap). Round 4.3 P7 candidates apply here.

### Cluster CC6 — Cumulative vertical-budget exhaustion (1 outcome, many contributors)
G5 (Totaalbedrag page-break) is the *consequence* of S5 + S7 + S6 (line-height) + S1-S4 (font-size cascade) + G3+G4+G6 (block-level br()/hr() advance differences). No single fix; this is the cluster of "everything is a bit tighter" totalled. The accepted-as-structural +119pt page-height delta absorbs much of this on the REF side; on A4 WIP it compounds into a page overflow.

### Cluster CC7 — Border / rule rendering (3 defect group)
D1 (items thead rule color), D2 (hr color), D3 (BTW underline thickness/separation) all involve stroke rendering. D1 + D2 are color defaults (institute uses black where Quartz produces gray); D3 is a `border-style: double` partition formula that differs from CSS Backgrounds §3.5 (1pt-1pt-1pt vs WIP's 0.75-1.5-0.75 partition). Per-side border modifiers `b7a84d6` + `6dd2bbb` are recent landings; their interaction with default-stroke-color and width/3 formula merits a focused look.

### Cluster CC8 — Wrap-on-overflow vs Quartz column-fit (2 defect direction)
L1/L2/L3/L5 wrap because WIP column is too narrow for the value at the rendered font. L4 *inverse*: REF wraps "Verzonden per email" within label cell where WIP fits it on one line — same column allocator producing opposite-sided allocations between REF and WIP. The allocator's behavior shape is qualitatively different from Quartz's, not just quantitatively scaled. This suggests the institute allocator is not yet emulating WebKit table layout (CSS 2.1 §17.5 automatic table layout / §17.5.2.2 column widths). Phase D referenced this gap; not fixed.

### Cluster CC9 — Font-typeface choice (1 fundamental)
F1 (SFNS vs Helvetica) is independent of all the above and is a font-selection / availability gap. It cannot be fully closed without embedding the SF-family fonts; partial close (e.g. Helvetica Neue + Helvetica Bold with `font-feature-settings` for tighter kerning) might narrow the gap. Out of scope for purely layout fixes.

---

## What was deliberately **not** inventoried

- Page count (1 vs 2) — accepted as structural reality per user adjudication 2026-05-13.
- Items table per-row body content (week 1-5 rows are mechanically equivalent in both PDFs).
- Encoding (`€`, `ë`) — verified non-defective in both per `pdf-text-encoding-trace.md` and confirmed empirically here (Tj byte hex inspection of currency rows).
- Tagging / accessibility tree — both PDFs are untagged at the structure-tree level (`Tagged: no`); ActualText spans match logical content in both.
- Inter-language / locale differences — same content in both (Dutch).

---

## Methodology limitations

- `pdftotext`'s consolidation of Tj-with-ActualText-BDC into single logical word masks visible wraps. Raw-operator inspection corrects this where the result was material.
- Quartz's REF stream is a single content stream encoding *all* page elements; institute WIP separates into two streams (one per page). Block-by-block extraction therefore differs.
- Font metric measurements assumed standard Helvetica widths at 12pt for the WIP rendering; SF Pro widths are approximated (Quartz does not embed the full font metrics in a way that's easily extractable without the source font).

---

## References

- `HANDOFF-swift-pdf-render-parity.md` (timekeeping root) — full dispatch context Rev 7.11 Round 4.3.
- `coenttb/swift-document-templates/Sources/Document Utilities/HTML.Document.document.swift:62-110` — embedded normalize.css + html font-family + line-height override.
- `coenttb/swift-document-templates/Sources/Invoice/Invoice.swift` — invoice tree (h1, outer table, meta table, vervaldatum table, items table, totals table, payment paragraph).
- `coenttb/swift-document-templates/Sources/Letter/Letter.Header.swift:38-45` — Letter.Header outer 2-col table (recipient + sender).
- `coenttb/swift-document-templates/Sources/Letter/Letter.Sender.swift:50-77` — Letter.Sender inner 2-col table (label / value rows).
- `swift-pdf-html-render/Research/coenttb-rendering-reference.md` — Phase D 5-axis reference inventory.
- `swift-pdf-html-render/Research/css-fidelity-gap-inventory.md` — Round 1 CSS gap catalog (uncommitted draft).
- `swift-pdf-html-render/Research/css-width-percentage-misinterpretation.md` — Phase B Width-fix root cause.
- `swift-pdf-html-render/Research/modifier-dispatch-ordering.md` — A1/A2 dispatch + emission audit.
- swift-pdf-html-render HEAD `0039040` (Round 4.3 `defaultFontSize 16 → 12 revert`); branches at `e7da3dc` (line-height 1.15 → 1.2), `c84cb50` (deferred 16pt). Per-side borders `b7a84d6` + `6dd2bbb`.

---

## Outcome

**Status**: INVENTORY (no decision; no recommendation; no fix proposed).

Pure observation of empirical visual deltas. Subsequent chat will prioritize and propose fixes against this inventory. Defect IDs F1, S1–S5, P1, P4, P6, P7, P8, L1, L2, L3, L5, L6, G5 are the **HIGH-perceptibility** items by the criterion "visible at a glance to a user comparing the two PDFs side by side."
