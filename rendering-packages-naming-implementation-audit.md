# Rendering Packages — Naming & Implementation Audit Findings

**Date**: 2026-03-12
**Auditor**: Claude (Opus 4.6)
**Skills**: `/naming` [API-NAME-001–004], `/implementation` [IMPL-INTENT, IMPL-000–053, PATTERN-009–022]
**Scope**: 136 source files, ~10,700 lines across 3 packages (5 modules)

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 12 |
| MEDIUM | 41 |
| LOW | 55 |
| **Total** | **108** |

### By Requirement

| Requirement | Count | Severities |
|-------------|-------|------------|
| [API-IMPL-005] One type per file | 4 | 4 HIGH |
| [API-NAME-001] Nest.Name pattern | 17 | 7 HIGH, 8 MEDIUM, 2 LOW |
| [API-NAME-002] No compound identifiers | 54 | 1 HIGH, 22 MEDIUM, 31 LOW |
| [IMPL-INTENT] Intent over mechanism | 12 | 5 MEDIUM, 7 LOW |
| [IMPL-006]/[IMPL-010] Typed stored properties | 5 | 5 LOW |
| [PATTERN-016] Conscious technical debt | 5 | 3 MEDIUM, 2 LOW |
| [PATTERN-017] rawValue location | 2 | 2 MEDIUM |
| [IMPL-034] unsafe/@unchecked Sendable | 4 | 2 MEDIUM, 2 LOW |
| [IMPL-031] Enum iteration | 1 | 1 LOW |
| [IMPL-033] Iteration intent | 2 | 2 LOW |
| [PATTERN-013] Concrete before abstraction | 1 | 1 LOW |
| [API-NAME-003] Spec-mirroring | 0 violations | Correctly applied throughout |

### Dominant Theme

**Compound identifiers** ([API-NAME-001] + [API-NAME-002]) account for **71 of 108** findings. The rendering layer has extensive compound naming debt, concentrated in:
1. `PDF.HTML.Configuration` — 16 types in one file, 10+ compound properties
2. `PDF.HTML.Context.Table` — 15 types in one file, 15+ compound properties
3. `PDF.Context` — 20+ compound public methods (`emit*`, `flush*`, `advance*`, `start*`, `check*`)
4. `PDF.HTML.Context` — 5 compound properties on block flow state

---

## HIGH Findings

### Finding H-001: Configuration.swift contains 16 type declarations
- **Severity**: HIGH
- **Requirement**: [API-IMPL-005]
- **Location**: `PDF.HTML.Configuration.swift:16–650`
- **Current**: `Configuration`, `Header`, `Footer`, `Typography`, `Indent`, `Table`, `Cell`, `Border`, `Outline`, `Link`, `Annotation`, `Annotation.Border`, `Viewer`, `View`, `Print`, `PageInfo` — all in one file
- **Proposed**: One file per type: `PDF.HTML.Configuration.swift`, `PDF.HTML.Configuration.Header.swift`, `PDF.HTML.Configuration.Footer.swift`, etc.
- **Rationale**: [API-IMPL-005] states each `.swift` file MUST contain exactly one type declaration. 16 types in 650 lines.

### Finding H-002: Context.Table.swift contains 15 type declarations
- **Severity**: HIGH
- **Requirement**: [API-IMPL-005]
- **Location**: `PDF.HTML.Context.Table.swift:19–487`
- **Current**: `Table`, `SpanGrid`, `CellSpan`, `PendingCellBorder`, `DeferredSpanningCell`, `Origin`, `Span`, `Col`, `Row`, `Cell` (×2), `Content`, `HeaderState`, `Cell` (HeaderState), cell accessor
- **Proposed**: Extract into separate files per [API-IMPL-005]
- **Rationale**: 15 type declarations in 487 lines.

### Finding H-003: DynamicDispatchProtocols.swift contains 5 protocol declarations
- **Severity**: HIGH
- **Requirement**: [API-IMPL-005]
- **Location**: `PDF.HTML+DynamicDispatchProtocols.swift:21–64`
- **Current**: `_AnyViewContent`, `_HTMLElementContent`, `_HTMLRawContent`, `_HTMLStyledContent`, `_ArrayContent`
- **Proposed**: One file per protocol
- **Rationale**: 5 protocol declarations in one file.

### Finding H-004: Context.swift contains 9 type declarations
- **Severity**: HIGH
- **Requirement**: [API-IMPL-005]
- **Location**: `PDF.HTML.Context.swift:1–317`
- **Current**: `Context`, `Link`, `Destination`, `Pending`, `Section`, `HeadingEntry`, `Snapshot`, `DeferredRender`, `BreakFlags`
- **Proposed**: Extract each into its own file
- **Rationale**: 9 public struct declarations in 317 lines.

### Finding H-005: `HTMLContextStyleModifier` — quad-compound protocol name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.StyleModifier.swift:30`
- **Current**: `public protocol HTMLContextStyleModifier`
- **Proposed**: `PDF.HTML.Context.Style.Modifier` — nest under Context instead of prefixing
- **Rationale**: Four-word compound (`HTML` + `Context` + `Style` + `Modifier`) with redundant `HTML` prefix. Public protocol used by all ~45 CSS conformances.

### Finding H-006: `SpanGrid` — compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.Table.swift:81`
- **Current**: `public struct SpanGrid`
- **Proposed**: `Table.Span.Grid` or `Table.Grid`
- **Rationale**: Compound type name violates Nest.Name pattern.

### Finding H-007: `CellSpan` — compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.Table.swift:93`
- **Current**: `public struct CellSpan`
- **Proposed**: `Table.Span.Cell` or `SpanGrid.Cell`
- **Rationale**: Compound type name.

### Finding H-008: `PendingCellBorder` — triple-compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.Table.swift:199`
- **Current**: `public struct PendingCellBorder`
- **Proposed**: `Table.Border.Pending` or `Table.Pending.Border`
- **Rationale**: Triple-compound type name.

### Finding H-009: `DeferredSpanningCell` — triple-compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.Table.swift:209`
- **Current**: `public struct DeferredSpanningCell`
- **Proposed**: `Table.Deferred.Cell` or `Table.Cell.Deferred`
- **Rationale**: Triple-compound type name.

### Finding H-010: `HeaderState` — compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.Table.swift:260`
- **Current**: `public struct HeaderState`
- **Proposed**: `Table.Header.State` or `Table.Header`
- **Rationale**: Compound type name.

### Finding H-011: `PageInfo` — compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Configuration.swift:620`
- **Current**: `public struct PageInfo: Sendable`
- **Proposed**: `PDF.HTML.Page.Info` or `Configuration.Page`
- **Rationale**: Compound type name in public API.

### Finding H-012: `TextRun` — compound type name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.Context.TextRun.swift:12`
- **Current**: `public struct TextRun: Sendable`
- **Proposed**: `PDF.Context.Text.Run`
- **Rationale**: Compound type name used extensively throughout rendering pipeline.

---

## MEDIUM Findings

### Compound Type Names [API-NAME-001]

### Finding M-001: `StyleModifier` — compound protocol name
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.StyleModifier.swift:21`
- **Current**: `public protocol StyleModifier`
- **Proposed**: `PDF.HTML.Style.Modifier`
- **Rationale**: Two-word compound. Less severe than H-005 since it has the `PDF.HTML` namespace.

### Finding M-002: `RenderResult` — compound type name
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.RenderResult.swift:10`
- **Current**: `PDF.HTML.RenderResult`
- **Proposed**: `PDF.HTML.Render.Result`
- **Rationale**: Compound type name in public API (return type of entry points).

### Finding M-003: `TextExtractable` — compound protocol name
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.TextExtractable.swift:9`
- **Current**: `public protocol TextExtractable`
- **Proposed**: `PDF.HTML.Text.Extractable` or `PDF.HTML.Text.Source`
- **Rationale**: Compound protocol name.

### Finding M-004: `BreakFlags` — compound type name
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.swift` (BreakFlags struct)
- **Current**: `PDF.HTML.Context.BreakFlags`
- **Proposed**: `PDF.HTML.Context.Break.Flags` or `PDF.HTML.Context.Break`
- **Rationale**: Compound type name.

### Finding M-005: `DeferredRender` — compound type name
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML.Context.swift` (DeferredRender struct)
- **Current**: `PDF.HTML.Context.DeferredRender`
- **Proposed**: `PDF.HTML.Context.Deferred` or `PDF.HTML.Context.Deferred.Render`
- **Rationale**: Compound type name.

### Finding M-006: `ListType` and `ListMarker` — compound type names
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.Context.ListType.swift:14`, `PDF.Context.ListMarker.swift:12`
- **Current**: `PDF.Context.ListType`, `PDF.Context.ListMarker`
- **Proposed**: `PDF.Context.List.Kind`, `PDF.Context.List.Marker`
- **Rationale**: Two compound type names that share a `List` prefix — natural nesting candidates.

### Finding M-007: `_renderAsyncDynamic` — public free function outside namespace
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001], [IMPL-INTENT]
- **Location**: `Rendering.Async.Protocol.swift:67`
- **Current**: `public func _renderAsyncDynamic<T: Rendering.Protocol, Sink: Rendering.Async.Sink.Protocol>(...)`
- **Proposed**: `Rendering.Async.renderDynamic(...)` as a static method
- **Rationale**: Public function at module scope violates [API-NAME-001]. Despite underscore prefix, it is `public @inlinable` (ABI surface).

### Compound Property/Method Names [API-NAME-002]

### Finding M-008: Configuration defaults cluster — 5 compound properties
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Configuration.swift:36–50`
- **Current**: `documentTitle`, `documentDate`, `defaultFont`, `defaultFontSize`, `defaultColor`
- **Proposed**: Group under sub-structs: `document.title`, `document.date`, `defaults.font`, `defaults.fontSize`, `defaults.color`
- **Rationale**: Five compound identifiers on public configuration type. Grouping eliminates them all.

### Finding M-009: Configuration spacing cluster — 3 compound properties
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Configuration.swift:62–80`
- **Current**: `paragraphSpacing`, `headingSpacing`, `horizontalGapEm`
- **Proposed**: `spacing.paragraph`, `spacing.heading`, `gap.horizontal`
- **Rationale**: Compound identifiers. The `Em` suffix encodes unit in the name rather than the type.

### Finding M-010: Configuration compound methods — `resolveLineHeight`, `headingMarginEm`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Configuration.swift:185, 242`
- **Current**: `resolveLineHeight(for:fontSize:)`, `headingMarginEm(for:)`
- **Proposed**: `lineHeight.resolved(for:fontSize:)`, `heading.margin(for:)`
- **Rationale**: Public compound method names.

### Finding M-011: Configuration `deferredHeaderThreshold` — triple-compound
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Configuration.swift:83`
- **Current**: `public var deferredHeaderThreshold: Scale<1, Double>`
- **Proposed**: Nest under `header` or `threshold` namespace
- **Rationale**: Triple-compound identifier.

### Finding M-012: PDF.Context box model properties — 8 compound names
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.swift:87–108`
- **Current**: `marginTop`, `marginRight`, `marginBottom`, `marginLeft`, `paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft`
- **Proposed**: `margin.top`, `margin.right`, `margin.bottom`, `margin.left`, `padding.top`, etc. via CSS box model nested accessor
- **Rationale**: Eight compound identifiers. [API-NAME-003] reduces severity (CSS spec mirrors), but the institute convention requires nested accessors.

### Finding M-013: PDF.Context `preserveWhitespace` and `measurementMode`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.swift:68, 77`
- **Current**: `preserveWhitespace`, `measurementMode`
- **Proposed**: `whitespace.isPreserved`, `measurement.isActive`
- **Rationale**: Compound public property names.

### Finding M-014: PDF.Context `emit*` family — 5 compound public methods
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.swift:629, 689, 720, 750, 803, 835`
- **Current**: `emitText`, `emitLine`, `emitRectangle`, `emitImage`, `emitCircle`
- **Proposed**: `emit.text(...)`, `emit.line(...)`, `emit.rectangle(...)`, `emit.image(...)`, `emit.circle(...)` — unified verb-as-property [IMPL-020]
- **Rationale**: Five compound public methods sharing `emit` prefix. Clear verb-as-property candidate.

### Finding M-015: PDF.Context pagination methods — 4 compound names
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.swift:429, 456, 466, 497`
- **Current**: `startNewPage()`, `addLinkAnnotation(rect:uri:)`, `addLinkAnnotation(rect:destination:)`, `checkPageBreak(needing:)`
- **Proposed**: `page.start()`, `annotation.addLink(...)`, `page.breakIfNeeded(for:)`
- **Rationale**: Public compound method names on frequently-used type.

### Finding M-016: PDF.Context `advanceLine`, `advanceX`, `flushInlineRuns`, `flushText`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.swift:289, 301, 331, 709`
- **Current**: `advanceLine()`, `advanceX(_:)`, `flushInlineRuns()`, `flushText()`
- **Proposed**: `advance.line()`, `advance.horizontal(_:)`, `inline.flush()`, `text.flush()`
- **Rationale**: Public compound method names. `advance` and `flush` are verb-as-property candidates.

### Finding M-017: PDF.Context `nextListMarker` — compound method with complex logic
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.swift:375`
- **Current**: `public mutating func nextListMarker() -> ListMarker`
- **Proposed**: `list.nextMarker()` via nested accessor
- **Rationale**: Public compound method name containing ~90 lines of logic.

### Finding M-018: PDF.HTML.Context block flow properties — 5 compound names
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Context.swift:45–55`
- **Current**: `pendingBottomMargin`, `deferredKeepWithNextRender`, `avoidPageBreakAfter`, `forcePageBreakAfter`, `avoidPageBreakInside`
- **Proposed**: `margin.pending.bottom`, `deferred.keepWithNext`, `pageBreak.avoidAfter`, `pageBreak.forceAfter`, `pageBreak.avoidInside`
- **Rationale**: Five compound property names, including one quadruple-compound (`deferredKeepWithNextRender`).

### Finding M-019: PDF.HTML.Context compound methods
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Context.swift:156, 181, 241, 262`
- **Current**: `applyCollapsedMargin(top:bottom:)`, `resetMarginCollapsing()`, `captureBreakFlags()`, `withSavedStyleState(_:)`
- **Proposed**: `margin.collapse.apply(top:bottom:)`, `margin.collapse.reset()`, `breakFlags.capture()`, `style.withSaved(_:)`
- **Rationale**: Four public compound method names on a frequently-used type.

### Finding M-020: Table layout compound methods
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Context.Table.swift:376–481`
- **Current**: `xForColumn(_:)`, `yForRow(_:)`, `widthForColumns(...)`, `heightForRows(...)`, `advanceToNextAvailableColumn()`
- **Proposed**: `column.x(at:)`, `row.y(at:)`, `column.width(from:count:)`, `row.height(from:count:)`, `column.advance.next()`
- **Rationale**: Five compound method names with "For" joining concepts.

### Finding M-021: Table state compound properties (systemic)
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Context.Table.swift:164–339`
- **Current**: `currentRow`, `currentColumn`, `totalRowsRendered`, `columnsInitialized`, `measureOnly`, `maxCellHeightInCurrentRow`, `tableStartY`, `tableEndY`, `horizontalLineSkips`, `verticalLineSkips`, `currentRowMaxAscent`, `currentRowMaxDescent`, `currentFragmentStartY`, `currentFragmentEndY`
- **Proposed**: Group under nested accessors: `current.row`, `current.column`, `rows.total`, `columns.initialized`, etc.
- **Rationale**: 14+ compound property names. Systemic naming debt.

### Finding M-022: `CellSpan` compound properties `originRow`, `originColumn`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Context.Table.swift:95–97`
- **Current**: `originRow: Int`, `originColumn: Int`
- **Proposed**: `origin.row`, `origin.column` (pattern already used in `DeferredSpanningCell.Origin`)
- **Rationale**: Compound identifiers. Inconsistent with `DeferredSpanningCell.Origin` which properly uses nesting.

### Finding M-023: TextRun `linkURL`, `internalLinkId` — compound properties
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.Context.TextRun.swift:32, 36`
- **Current**: `linkURL: String?`, `internalLinkId: String?`
- **Proposed**: `link.url`, `link.internalId` or group into a `TextRun.Link` struct
- **Rationale**: Compound identifiers. Triple-compound for `internalLinkId`.

### Finding M-024: TextExtractable `pdfExtractedText` — triple-compound with redundant prefix
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.TextExtractable.swift:11`
- **Current**: `var pdfExtractedText: String { get }`
- **Proposed**: `var extractedText: String` — the `pdf` prefix is redundant in `PDF.HTML` namespace
- **Rationale**: Triple-compound property name with redundant namespace prefix.

### Finding M-025: PageInfo compound properties
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `PDF.HTML.Configuration.swift:622–633`
- **Current**: `pageNumber`, `totalPages`, `sectionTitle`, `documentTitle`
- **Proposed**: If restructured as `Page.Info`: `number`, `total`, `section.title`, `document.title`
- **Rationale**: Multiple compound identifiers that become clean when parent type uses Nest.Name.

### Finding M-026: Rendering.Element compound properties
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: `Rendering.Element.swift:36–55`
- **Current**: `tagName`, `isBlock`, `isVoid`, `preservesWhitespace`
- **Proposed**: `tag.name`, restructure booleans into flags struct
- **Rationale**: `tagName` is a compound identifier on a primitives-layer type. `isBlock`/`isVoid` follow stdlib convention (`isEmpty`), which moderates severity.

### Finding M-027: StyleModifier.swift contains 2 protocol declarations
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005]
- **Location**: `PDF.HTML.StyleModifier.swift:21, 30`
- **Current**: `StyleModifier` and `HTMLContextStyleModifier` in one 34-line file
- **Proposed**: Separate into two files
- **Rationale**: Two types in one file.

### Intent Over Mechanism [IMPL-INTENT]

### Finding M-028: Repeated color-switch mechanism — 6 identical blocks
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT], [IMPL-000]
- **Location**: `PDF.Context.swift:650–657, 734–741, 765–772, 776–783, 859–865, 869–878`
- **Current**: Six near-identical `switch color { case .gray: ... case .rgb: ... case .cmyk: ... }` blocks
- **Proposed**: Extract `setFillColor(_:)` and `setStrokeColor(_:)` on ContentStream.Builder
- **Rationale**: Intent is "set fill color" — mechanism is the 3-way switch. Six repetitions of identical mechanism. Missing infrastructure per [IMPL-000].

### Finding M-029: Repeated measurement pattern in Dispatch
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT], [IMPL-000]
- **Location**: `PDF.HTML+Dispatch.swift:369–381, 396–403`
- **Current**: Two nearly identical blocks measuring element height via temp context
- **Proposed**: Extract `measureInnermostContent(styled:snapshot:context:)` helper
- **Rationale**: Intent is "measure content height." Mechanism (create temp context, render, capture Y delta) repeated verbatim.

### Finding M-030: 22-line manual save/restore in `withSavedStyleState`
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: `PDF.HTML.Context.swift:262–294`
- **Current**: 11 individual `let saved* = pdf.*` + 11 restoration assignments
- **Proposed**: Extract `PDF.Context.LayoutSnapshot` struct with `save(from:)` / `restore(to:)`
- **Rationale**: 22-line block is pure mechanism — describes *how* to save/restore, not *what* is preserved. A snapshot type would express intent directly.

### Finding M-031: If-chain type dispatch in PDF.Element.markedContentInfo
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: `PDF.Element.swift:78–154`
- **Current**: 7 sequential `if Tag.self == ...` checks with `unsafeBitCast`
- **Proposed**: Protocol-based dispatch: `(tag as? StructureTagInfo)?.info ?? fallback`
- **Rationale**: Mechanism-heavy dispatch. The `unsafeBitCast` usage within each branch compounds the concern.

### Finding M-032: `Any`-based type erasure in async dynamic render
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: `Rendering.Async.Protocol.swift:72–122`
- **Current**: `var anyContext: Any = context` + casts through `Any` with `assertionFailure` fallbacks
- **Proposed**: Consider protocol witness tables or existential containers
- **Rationale**: The `Any`-based type erasure chain is mechanism-heavy. Three `assertionFailure` calls guard "impossible" states.

### rawValue / unsafe [PATTERN-017, IMPL-034]

### Finding M-033: `.rawValue > 0` comparisons in Dispatch
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017], [IMPL-002]
- **Location**: `PDF.HTML+Dispatch.swift:341, 352, 438, 441`
- **Current**: `if let marginTop = context.pdf.marginTop, marginTop.rawValue > 0`
- **Proposed**: `marginTop > .zero` — typed comparison on `PDF.UserSpace.Height`
- **Rationale**: `.rawValue` extraction for comparison is mechanism. If `> .zero` is not available, it's an infrastructure gap per [IMPL-000].

### Finding M-034: `.rawValue` in content height calculation
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017]
- **Location**: `HTML.Element.Tag+TableCell.swift:167`
- **Current**: `PDF.UserSpace.Height(abs(contentEndY.rawValue - contentStartY.rawValue))`
- **Proposed**: `contentEndY.distance(to: contentStartY)` or typed abs operation
- **Rationale**: Computing distance between typed coordinates should not require raw value extraction.

### Finding M-035: `unsafeBitCast` without justification comment
- **Severity**: MEDIUM
- **Requirement**: [IMPL-034], [PATTERN-016]
- **Location**: `PDF.Element.swift:83, 98, 120`
- **Current**: `unsafeBitCast(tag, to: ISO_32000.Table.self)` (after metatype check)
- **Proposed**: Add WORKAROUND comment per [PATTERN-016], or use `as?` cast
- **Rationale**: `unsafe` usage without justification. The metatype check makes it safe at runtime, but `as?` would be safer after specialization.

### Finding M-036: `@unchecked Sendable` on DeferredRender without structured justification
- **Severity**: MEDIUM
- **Requirement**: [IMPL-034], [PATTERN-016]
- **Location**: `PDF.HTML.Context.swift:210`
- **Current**: `public struct DeferredRender: @unchecked Sendable` — has code comment but no [PATTERN-016] format
- **Proposed**: Add `// WORKAROUND:` / `// WHY:` / `// WHEN TO REMOVE:` block
- **Rationale**: `@unchecked Sendable` requires structured justification.

### Finding M-037: `try!` in fallback path of `markedContentInfo`
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-016]
- **Location**: `PDF.Element.swift:152–153`
- **Current**: `return (try! ISO_32000.COS.Name(typeName), nil)` with `swiftlint:disable:next force_try`
- **Proposed**: Use `guard let name = try? ...` or add WORKAROUND comment
- **Rationale**: `try!` crashes if type name contains non-PDF characters (`<`, `>`, `,`). Generic type names can contain these. The swiftlint suppression hides the issue.

### Finding M-038: Unused `backgroundColor` parameter in TextRun init
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: `PDF.Context.TextRun.swift:45`
- **Current**: `backgroundColor: PDF.Color? = nil` in init — never stored or used
- **Proposed**: Remove unused parameter
- **Rationale**: Dead parameter. Likely vestige of earlier design.

### Finding M-039: Unused `collectedHeadings` variable
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: `PDF.HTML+EntryPoints.swift:98`
- **Current**: `let collectedHeadings = pass1Context.section.headings` — never referenced
- **Proposed**: Remove if unused
- **Rationale**: Dead code.

### Finding M-040: Duplicate LineBox computation across layers
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: `CSS.LineBox.swift:49–112` vs `PDF.Context.Style.Resolved.swift:41–75`
- **Current**: `PDF.HTML.LineBox` and `PDF.Context.Style.Resolved.Line` compute identical CSS half-leading geometry
- **Proposed**: Consolidate into one canonical computation in `PDF.Context.Style.Resolved.Line`
- **Rationale**: Identical formulas in two locations create maintenance risk.

### Finding M-041: DynamicDispatch protocols — compound names
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: `PDF.HTML+DynamicDispatchProtocols.swift:21–64`
- **Current**: `_AnyViewContent`, `_HTMLElementContent`, `_HTMLRawContent`, `_HTMLStyledContent`, `_ArrayContent`
- **Proposed**: These are underscore-prefixed package-internal protocols. Compound names have more latitude per [IMPL-024] spirit, but protocols are type declarations per [API-NAME-001].
- **Rationale**: Five compound protocol names. Underscore prefix moderates severity.

---

## LOW Findings

### Compound Type Names [API-NAME-001] — LOW

| # | Type | Location | Proposed |
|---|------|----------|----------|
| L-001 | `DataURL` | `Image+PDF.HTML.View.swift` (private) | `Data.URL` |
| L-002 | `LineBox` | `CSS.LineBox.swift` | `CSS.Line.Box` (W3C spec) |
| L-003 | `HeadingEntry` | `PDF.HTML.Context.swift` | `Section.Heading` |
| L-004 | `PendingInternalLink` | `PDF.Context.swift:173` | `Internal.Link.Pending` |
| L-005 | `AnyView` | `Rendering.AnyView.swift` | SwiftUI convention — justified |
| L-006 | `ForEach` | `Rendering.ForEach.swift` | SwiftUI convention — justified |

### Compound Method/Property Names [API-NAME-002] — LOW

All findings below are either internal/private (acceptable per [IMPL-024]) or CSS spec-mirroring (acceptable per [API-NAME-003]):

| # | Identifier | Location | Note |
|---|-----------|----------|------|
| L-007 | `stackSpacing`, `horizontalSpacing` | `PDF.Context.swift:71, 82` | Internal layout state |
| L-008 | `explicitWidth`, `explicitHeight` | `PDF.Context.swift:111–114` | Internal state |
| L-009 | `textBlockOpen`, `currentTextFont`, `currentTextFontSize`, `currentTextColor`, `currentTextPosition` | `PDF.Context.swift:128–140` | Internal text state |
| L-010 | `lastElementX`, `horizontalRowStartY`, `horizontalRowMaxY` | `PDF.Context.swift:117–123` | Internal horizontal layout |
| L-011 | `isHorizontalLayout` | `PDF.Context.swift:307` | Computed Bool accessor |
| L-012 | `updateHorizontalRowMaxY` | `PDF.Context.swift:312` | Public but narrow scope |
| L-013 | `hasInlineRuns` | `PDF.Context.swift:339` | Public computed Bool |
| L-014 | `popList` | `PDF.Context.swift:360` | Narrow scope |
| L-015 | `wouldExceedPage`, `remainingHeight` | `PDF.Context.swift:506, 511` | Public but self-documenting |
| L-016 | `addPendingInternalLink` | `PDF.Context.swift:479` | Public triple-compound |
| L-017 | `resolveInternalLinks` | `PDF.Context.swift:557` | Static — [IMPL-024] |
| L-018 | `lineHeight` | `Configuration.swift:57` | CSS spec mirror |
| L-019 | `hideToolbar`, `hideMenubar`, etc. | `Configuration.swift:517–531` | ISO 32000 spec mirror |
| L-020 | `textMarkup`, `textAlign` | `PDF.Context.Style.swift:44, 50` | CSS/PDF spec mirror |
| L-021 | `verticalOffset` | `PDF.Context.Style.swift:47` | Conventional |
| L-022 | `textDecoration` | `PDF.Context.TextRun.swift:26` | CSS spec mirror |
| L-023 | `columnWidths`, `rowHeights`, etc. | `Context.Table.swift:26–373` | Common table conventions |
| L-024 | `rowSpan`, `colSpan` | `Context.Table.swift:99–101` | HTML spec mirror |
| L-025 | `currentURL`, `currentInternalId` | `PDF.HTML.Context.swift:70, 73` | Sub-context already namespaced |
| L-026 | `currentTitle`, `pageTitles` | `PDF.HTML.Context.swift:117, 120` | Already in Section sub-context |
| L-027 | All static helpers in tag rendering | Multiple files | [IMPL-024] applies |

### Mechanism Over Intent [IMPL-INTENT] — LOW

| # | Finding | Location |
|---|---------|----------|
| L-028 | `.init(0)` repeated instead of `.zero` | `TextRun+Rendering.swift:44, 50, 78, 98, 142, 151, 186, 237, 263, 291, 318` |
| L-029 | Manual `for i in 0..<state.words.count` loop | `TextRun+Rendering.swift:238–242` |
| L-030 | Magic hex bytes `0x93`, `0x94` for quotation marks | `HTML.Element+PDF.HTML.View.swift:358, 371` |
| L-031 | Magic `0x3F` for fallback character | `PDF.Context.TextRun.swift:174` |
| L-032 | Magic string checks in TextExtractable fallback | `PDF.HTML.TextExtractable.swift:48` |
| L-033 | Long parameter list in `renderWithFlow` (8 params) | `HTML.Element+PDF.HTML.View.swift:206–214` |
| L-034 | Manual `for col in 0..<tc.columnCount` loops | `HTML.Element.Tag+TableRow.swift:142, 167` |
| L-035 | Heading tag switch repeated 3× instead of single source | `HTML.Element.Tag+TagStyle.swift:13–30, 103–108, 131–139` |
| L-036 | Save/restore 6 values in renderTag (could use `withSavedState`) | `HTML.Element+PDF.HTML.View.swift:92–106` |
| L-037 | `StyleKey.init(run:index:)` default `= 0` — past bug source | `TextRun+Rendering.swift:349` |

### Typed Properties / Int at Edge [IMPL-006, IMPL-010] — LOW

| # | Finding | Location |
|---|---------|----------|
| L-038 | `pageNumber: Int` | `PDF.Context.swift:177`, `PDF.HTML.Context.swift:88` |
| L-039 | `level: Int` for headings | `PDF.HTML.Configuration.swift:228`, `Context.swift:100` |
| L-040 | Row/column indices as raw `Int` | `Context.Table.swift:95–101, 164–167` |
| L-041 | `chunkSize: Int`, `bytesSinceYield: Int` | `Rendering.Async.Sink.Buffered.swift:35`, `Chunked.swift:22` |
| L-042 | `listStack` uses untyped tuple | `PDF.Context.swift:60` |

### Technical Debt / Other — LOW

| # | Finding | Location |
|---|---------|----------|
| L-043 | FRAGILITY WARNING without [PATTERN-016] format | `PDF.HTML+Dispatch.swift:457–458` |
| L-044 | `swiftlint:disable:next shorthand_operator` without docs | `PDF.Context.swift:290, 297` |
| L-045 | `Rendering.Builder` buildPartialBlock removal without [PATTERN-016] format | `Rendering.Builder.swift:81–86` |
| L-046 | `@unchecked Sendable` on `Rendering.AnyView` without structured justification | `Rendering.AnyView.swift` |
| L-047 | `PendingInternalLink` nested in PDF.Context file (should be separate) | `PDF.Context.swift:173–186` |
| L-048 | `RenderState`, `WordDescriptor` private types inline in extension | `TextRun+Rendering.swift:168, 207` |
| L-049 | `BuilderRaw` module-level typealias | `PDF.Builder.swift` |
| L-050 | `LayoutRaw` module-level typealias (duplicates L-049) | `PDF.Stack+PDF.View.swift` |
| L-051 | `Image+PDF.HTML.View.swift` contains private `DataURL` struct | `Image+PDF.HTML.View.swift` |
| L-052 | Dynamic dispatch protocols — conformer count unclear | `DynamicDispatchProtocols.swift` |
| L-053 | `Rendering.Protocol` uses backtick-escaped keyword name | `Rendering.Protocol.swift:20` |
| L-054 | Inconsistent border width types: `Double` vs `PDF.UserSpace.Size<1>` | `Configuration.swift:493 vs :402` |
| L-055 | `Rendering.Element.tagName` uses raw `String` | `Rendering.Element.swift:36` |

---

## Clean Attestations

### Zero Foundation imports
All three packages confirmed: zero Foundation imports across all 136 files. [PATTERN-009] fully compliant.

### CSS StyleModifier conformances
All 45 CSS StyleModifier files: **CLEAN**. Names mirror W3C CSS specifications per [API-NAME-003].

### Leaf View conformances
All leaf conformances (String, HTML.Text, HTML.Empty, HTML.Raw, HTML.AnyView, Never, ForEach, Optional, _Conditional, _Tuple, _Array, CSS, HTML._Attributes, Empty, Pair, Divider, Rectangle, Spacer, Stack): **CLEAN**.

### Export files
All `exports.swift` files across all packages: **CLEAN**. Proper `@_exported` and `public import` patterns.

### Static layer naming
All private/internal static methods correctly use compound names per [IMPL-024]. No violations in the static implementation layer.

---

## Recommendations

### Priority 1: File Splitting (4 findings, HIGH)

Split the four multi-type files. This is purely mechanical and has no API impact:

| File | Types | Effort |
|------|-------|--------|
| `PDF.HTML.Configuration.swift` | 16 → 16 files | Low (each type is self-contained) |
| `PDF.HTML.Context.Table.swift` | 15 → 15 files | Low |
| `PDF.HTML.Context.swift` | 9 → 9 files | Low |
| `PDF.HTML+DynamicDispatchProtocols.swift` | 5 → 5 files | Low |

**Estimated churn**: ~0 logic changes, ~45 new files, ~45 deleted lines (file headers).

### Priority 2: Compound Type Names (12 findings, HIGH + MEDIUM)

Rename compound types to Nest.Name pattern. Highest-impact first:

| Current | Proposed | Impact |
|---------|----------|--------|
| `HTMLContextStyleModifier` | `PDF.HTML.Context.Style.Modifier` | 45 conformances + call sites |
| `TextRun` | `PDF.Context.Text.Run` | Pervasive in rendering pipeline |
| `PageInfo` | `PDF.HTML.Page.Info` | Configuration + headers/footers |
| `SpanGrid` | `Table.Span.Grid` | Table internals |
| `CellSpan` | `Table.Span.Cell` | Table internals |
| `PendingCellBorder` | `Table.Border.Pending` | Table internals |
| `DeferredSpanningCell` | `Table.Deferred.Cell` | Table internals |
| `HeaderState` | `Table.Header.State` | Table internals |
| `RenderResult` | `PDF.HTML.Render.Result` | Entry point return type |
| `StyleModifier` | `PDF.HTML.Style.Modifier` | 45 conformances |
| `ListType` / `ListMarker` | `List.Kind` / `List.Marker` | Context internals |

**Estimated churn**: ~200 file renames, ~500 call site updates. Consider scripted rename.

### Priority 3: Verb-as-Property Refactoring (MEDIUM)

Group compound methods under nested accessors. Highest-value clusters:

1. **`emit.*`** family on `PDF.Context` (5 methods → 1 property): `emit.text()`, `emit.line()`, `emit.rectangle()`, `emit.image()`, `emit.circle()`
2. **`advance.*`** on `PDF.Context` (2 methods → 1 property): `advance.line()`, `advance.horizontal(_:)`
3. **`page.*`** on `PDF.Context` (3 methods → 1 property): `page.start()`, `page.breakIfNeeded(for:)`, `page.wouldExceed(adding:)`
4. **`margin.*`** on `PDF.HTML.Context` (2 methods → 1 property): `margin.collapse.apply()`, `margin.collapse.reset()`
5. **Configuration defaults** (5 properties → 1 sub-struct): `defaults.font`, `defaults.fontSize`, `defaults.color`, `document.title`, `document.date`

**Estimated churn**: ~15 new accessor properties, ~50 call site updates per cluster.

### Priority 4: Infrastructure Gaps (MEDIUM)

1. **Color-switch deduplication**: Extract `setFillColor(_:)` / `setStrokeColor(_:)` on `ContentStream.Builder`. Eliminates 6 identical switch blocks.
2. **Measurement helper**: Extract `measureInnermostContent(...)` in Dispatch. Eliminates 1 duplication.
3. **Style state snapshot**: Extract `LayoutSnapshot` struct. Eliminates 22-line save/restore block.
4. **Typed comparison `> .zero`**: If not available on `PDF.UserSpace.Height`, add it. Eliminates 4 `.rawValue` comparisons.
5. **Typed distance**: If not available between coordinate types, add it. Eliminates 1 `.rawValue` computation.

### Priority 5: Cleanup (MEDIUM)

1. Remove unused `backgroundColor` parameter from `TextRun.init`
2. Remove unused `collectedHeadings` variable from `EntryPoints`
3. Add [PATTERN-016] structured comments to existing WORKAROUND/FRAGILITY markers
4. Consolidate duplicate LineBox computation across layers

### Deferred (LOW)

The 55 LOW findings are predominantly:
- Internal/private compound names (acceptable per [IMPL-024])
- CSS/PDF spec-mirroring names (acceptable per [API-NAME-003])
- Minor `.init(0)` → `.zero` improvements
- Raw `Int` in foundations-layer code (typed wrappers not justified at this layer)

These can be addressed opportunistically during related refactoring work.
