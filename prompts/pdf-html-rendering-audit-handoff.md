# Handoff: swift-pdf-html-rendering Quality Audit — Deferred Work

**Date**: 2026-03-12
**Package**: `/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/`
**Audit document**: `/Users/coen/Developer/swift-institute/Research/pdf-html-rendering-audit.md`
**State**: 84 tests passing, all FOUNDATIONAL findings resolved, STRUCTURAL and COSMETIC findings partially addressed

---

## What Was Completed

All 5 FOUNDATIONAL findings (F-1 through F-5) from the audit have been implemented and committed. The cleanup pass removed dead code identified in the audit. Here is what was done, in order:

### F-5: Extract entry point setup into shared infrastructure
`prepareContext` and `finalizeRendering` were extracted into `PDF.HTML.RenderResult.swift`. The 4 entry points in `PDF.HTML+EntryPoints.swift` now each call these shared methods, eliminating ~80 lines of duplicated context setup and teardown.

### F-2: Extract withSavedStyleState infrastructure
A `withSavedStyleState` method was added to `PDF.HTML.Context` (in `PDF.HTML.Context.swift`). It saves and restores 11 properties (style, margins×4, paddings×4, explicitWidth, explicitHeight, layoutBox). Applied in `HTML.Styled+PDF.HTML.View.swift` and `PDF.HTML+Dispatch.swift` (`renderFlattenedStyledContent`), eliminating ~44 lines of manual save/defer-restore.

### F-1: Unify static and dynamic rendering paths
The 5 duplicated method pairs in `HTML.Element+PDF.HTML.View.swift` were unified by parameterizing on `renderBlock` and `renderInline` closures. The static entry point passes `PDF.HTML.renderBlock`/`PDF.HTML.renderInline`, the dynamic entry point passes `PDF.HTML.renderBlockDynamic`/`PDF.HTML.renderInlineDynamic`. This eliminated ~605 lines (file went from 2038 to 1433 lines). The closure parameter types use `Content?` (not `Content`) because `view.content` is optional for void HTML elements.

### F-3: Decompose PDF.HTML.swift (995 lines → 6 files)
The 995-line god-file was decomposed into:
- `PDF.HTML.swift` — 9 lines, namespace declaration only (`extension PDF { public enum HTML {} }`)
- `PDF.HTML.RenderResult.swift` — 60 lines, `prepareContext`, `RenderResult` struct, `finalizeRendering`
- `PDF.HTML+EntryPoints.swift` — 183 lines, 4 simple entry points + two-pass header/footer rendering
- `PDF.HTML+Dispatch.swift` — 595 lines, `renderHTMLView`, `Dispatch` enum, `iterativeDispatch` worklist, `renderFlattenedStyledContent`, 5 mirror predicates, `applyStylePropertyViaMirror`, `renderInnerContent`
- `PDF.HTML+DynamicDispatchProtocols.swift` — 82 lines, 7 package protocols (`_TupleContent`, `_HTMLElementContent`, `_HTMLRawContent`, `_HTMLStyledContent`, `_ConditionalContent`, `_ArrayContent`, `_OptionalContent`)
- `PDF.HTML+BlockInlineHelpers.swift` — 91 lines, `renderBlock`, `renderInline`, `renderBlockDynamic`, `renderInlineDynamic`

### F-4: Decompose HTML.Element+PDF.HTML.View.swift (1433 lines → 8 files)
The remaining 1433-line file was decomposed into:
- `HTML.Element+PDF.HTML.View.swift` — 402 lines, `PDF.HTML.View` conformance, `renderTag`, `renderWithFlow`, void element rendering, `_HTMLElementContent` dynamic dispatch conformance
- `PDF.HTML.TextExtractable.swift` — 74 lines, `PDFTextExtractable` protocol + `extractCellText` helpers
- `HTML.Element.Tag+TagStyle.swift` — 156 lines, `applyTagStyle`, `blockMargins`, `headingLevel`, `isListContainer`, `listType`
- `HTML.Element.Tag+TableBorders.swift` — 101 lines, `drawCellBorder`, `drawFragmentRightAndBottomBorders`, `drawTableRightAndBottomBorders`, `drawCellBackground`
- `HTML.Element.Tag+HeaderRepetition.swift` — 136 lines, `renderRepeatedHeader`
- `HTML.Element.Tag+Table.swift` — 140 lines, `renderTable`
- `HTML.Element.Tag+TableRow.swift` — 265 lines, `renderTableRow`
- `HTML.Element.Tag+TableCell.swift` — 203 lines, `renderTableCell`

### Cleanup
- Removed 4 dead table protocols (`TableContainer`, `TableRowContainer`, `TableCellContainer`, `TableSectionContainer`) from `PDF.HTML.StyleModifier.swift` and their 7 conformances across HTML element files
- Removed commented-out code in `HTML._Attributes+PDF.HTML.View.swift` (old implementation, C-1)
- Deleted unused `with.swift` (free functions superseded by `context.with(\.table)` instance method, S-4)

All changes are in commit `f37ced1` on the `main` branch of the `swift-pdf-html-rendering` submodule.

---

## What Is Deferred — STRUCTURAL Findings

These are findings from the audit that were identified but intentionally not addressed. They are lower priority than the FOUNDATIONAL work and carry more design risk. Each has a clear description in the audit document.

### S-1: Context Is a God Object (15+ fields spanning 6 concerns)
`PDF.HTML.Context.swift` holds table state, HTML attributes, link tracking, margin collapsing, break flags, and section/heading tracking all in one `@CoW` struct. The audit notes this is "messy but not causing bugs." Decomposing it would require threading multiple smaller context types through all rendering methods — high churn for uncertain benefit. **Deferred indefinitely** unless it becomes a bug source.

### S-2: Partially Redundant Dynamic Dispatch Protocols
The 7 package protocols in `PDF.HTML+DynamicDispatchProtocols.swift` (`_TupleContent`, `_HTMLElementContent`, `_HTMLStyledContent`, etc.) exist to work around Swift's limitation where `as?` casts fail for conditional conformances on deeply nested generic types. The worklist interpreter's Mirror-based Phase 1 now handles Styled, CSS, Attributes, Conditional, and Optional detection — making `_HTMLStyledContent`, `_ConditionalContent`, `_ArrayContent`, and `_OptionalContent` potentially eliminable. However, they are still referenced in Phase 2's `as?` casts as fallback paths, and `_HTMLElementContent` is essential for terminal dispatch. **Deferred** — removing them requires careful verification that all rendering paths still work, especially for types that bypass Mirror detection.

### S-3: Compound Identifiers in Public API
Public methods `renderBlock`, `renderInline`, `renderBlockDynamic`, `renderInlineDynamic` violate [API-NAME-002]. Per [IMPL-024], compound names are acceptable in the implementation layer, and these methods are used as closure arguments throughout the unified rendering path. Renaming them to nested accessor style (`render.block()`) would require changing all call sites including closure construction. **Deferred** — low impact, high churn.

### S-5: `PDFTextExtractable` at Module Scope
The protocol is now in `PDF.HTML.TextExtractable.swift` but still uses the compound name `PDFTextExtractable` rather than being nested as `PDF.HTML.TextExtractable`. It has only one conformer (`String`). **Deferred** — renaming a public protocol is a breaking change for any downstream consumers.

### S-6: Break Flags as Mutable State Instead of Return Values
The `forcePageBreakAfter`, `avoidPageBreakAfter`, `avoidPageBreakInside` flags on `PDF.HTML.Context` use a set-check-reset communication pattern between `applyStyle` and its callers. The audit recommends making these return values from `applyStyle` instead of context mutations. Note: the static dispatch path (`renderFlattenedStyledContent`) already uses a return-value pattern via `_HTMLStyledContent.applyStyle(to:) -> (avoidBreakAfter:, forceBreakAfter:, avoidBreakInside:)`. The dynamic dispatch path's worklist interpreter still uses the mutable context flag pattern. **Deferred** — requires refactoring the worklist's styled-type handling to use the same return-value approach.

### Remaining COSMETIC Findings
- **C-2**: Many files have stale Xcode template headers (`// File.swift // swift-pdf-html-rendering // Created by...`). Low noise, no functional impact.
- **C-3**: `_AnyViewContent` protocol is declared in `HTML.AnyView+PDF.HTML.View.swift` rather than its own file. Single conformer — may not need a protocol at all.

### Tag Dispatch Protocols (Not in Audit, Observed During Work)
The 5 internal protocols (`TagRenderer`, `ListContainer`, `ListItemRenderer`, `BlockMargins`, `VoidElementRenderer`) in `PDF.HTML.StyleModifier.swift` are conformed-to by ~50 HTML element files in the HTML/ directory, but the actual rendering now dispatches by tag name string in `applyTagStyle`, `blockMargins`, etc. These conformances are technically dead code — the protocols are declared, conformed-to, but never used for dispatch. Removing them would touch 50+ files. **Deferred** — high churn, zero functional impact.

---

## Out of Scope (Per Audit)

These were explicitly marked as not needing change:
- **Mirror-based type detection** — principled technical debt, fragile but necessary due to Swift runtime SIGBUS crashes on deeply nested `as?` casts
- **Worklist interpreter complexity** — 200 lines of correct, well-documented dispatch logic
- **Configuration size** (650 lines) — pure data, correctly structured
- **Table context size** (491 lines) — cohesive, well-decomposed nested types
- **CSS style modifier files** (46 files) — correct [API-IMPL-005] structure
- **HTML element view files** (96 files) — correct [API-IMPL-005] structure

---

## Key Technical Details for Future Work

1. **Closure parameter types use `Content?`**: The unified `renderTag` method takes `renderBlock: (Content?, inout PDF.HTML.Context) -> Void` because `view.content` is optional for void HTML elements. This is correct — `PDF.HTML.renderBlock` already accepted `C?`.

2. **`fileprivate` → `static` visibility change**: When decomposing the god-files, methods that were `fileprivate` (accessible only within the original file) became `static` (internal to the module) since they're now called across files. This is an intentional widening required by the decomposition.

3. **84 tests all pass**: The test suite includes box model tests, break property tests, table tests (including rowspan, conditional rows, page break header repetition), outline generation tests, iterative tuple rendering tests (10×10, 10×30 tables), and a comprehensive document test. All 84 pass after every change.

4. **3 pre-existing `breakAfter` test failures**: The audit document mentions "81 pass, 3 pre-existing breakAfter failures" but all 84 tests passed during our work. This discrepancy may be due to fixes applied in a prior session (the worklist `forcePageBreak` case was added to fix dynamic dispatch path handling).
