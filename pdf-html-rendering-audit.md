# Quality Audit: swift-pdf-html-rendering

**Date**: 2026-03-12
**Scope**: Full package audit against `/implementation`, `/naming`, `/code-organization`, `/design` skills
**Package**: `/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/`
**State**: 165 source files, 8,041 LOC; 84 tests (81 pass, 3 pre-existing `breakAfter` failures)

---

## Findings

### FOUNDATIONAL

#### F-1: Two Parallel Rendering Paths Duplicate All Logic

**Files**: `HTML.Element+PDF.HTML.View.swift`, `PDF.HTML.swift`
**Rules violated**: [IMPL-INTENT], [API-IMPL-005]
**Severity**: FOUNDATIONAL

The package maintains two complete rendering pipelines that are near-identical copies:

| Static dispatch | Dynamic dispatch | Lines |
|---|---|---|
| `Tag._render` (line 27) | `_renderElementDynamically` (line 1397) | ~150 each |
| `renderWithFlow` (line 156) | `renderWithFlowDynamic` (line 1501) | ~170 each |
| `renderTable` (line 336) | `renderTableDynamic` (line 1625) | ~130 each |
| `renderTableRow` (line 468) | `renderTableRowDynamic` (line 1712) | ~200 each |
| `renderTableCell` (line ~700) | `renderTableCellDynamic` (line 1911) | ~130 each |

The only difference between each pair is the call to render child content:
- Static: `PDF.HTML.renderBlock(view.content, context:)` / `Content._render(content, context:)`
- Dynamic: `PDF.HTML.renderBlockDynamic(view.content, context:)` / `renderHTMLView(content, context:)`

**Total duplicated**: ~780 lines of near-identical rendering logic. Bugs fixed in one path are trivially missed in the other — the handoff document already identifies `forcePageBreakAfter` as one such case.

**Root cause**: The static and dynamic paths were written separately rather than parameterizing on the single axis of variation (how to render child content).

---

#### F-2: Style Save/Restore Duplicated 3 Times

**Files**: `HTML.Styled+PDF.HTML.View.swift:24-58`, `PDF.HTML.swift:737-797`, `HTML.Element+PDF.HTML.View.swift:42-56`
**Rules violated**: [IMPL-INTENT]
**Severity**: FOUNDATIONAL

The pattern of saving and restoring style + box model state appears verbatim in three locations:

**Location 1** — `HTML.Styled._render` (lines 25-58):
```swift
let savedStyle = context.pdf.style
let savedMarginTop = context.pdf.marginTop
let savedMarginRight = context.pdf.marginRight
// ... 9 more properties
defer {
    context.pdf.style = savedStyle
    context.pdf.marginTop = savedMarginTop
    // ... 9 more restores
}
```

**Location 2** — `renderFlattenedStyledContent` (lines 738-797): identical 11-property save/restore.

**Location 3** — `Tag._render` (lines 42-56): 6-property save/restore (style, layoutBox corners, preserveWhitespace, link state).

This is mechanism drowning intent. The intent is "render this content with scoped style changes." The mechanism is 22 lines of property shuffling, copy-pasted.

---

#### F-3: `PDF.HTML.swift` Is a 1206-Line God-File with 15+ Declarations

**File**: `PDF.HTML.swift`
**Rules violated**: [API-IMPL-005] (one type per file)
**Severity**: FOUNDATIONAL

Contents of this single file:

| Declaration | Lines | Kind |
|---|---|---|
| `PDF.HTML` namespace enum | 13-16 | Type |
| `PDF.HTML.RenderResult` | 79-86 | Type |
| `pages<H: PDF.HTML.View>` | 33-76 | Entry point |
| `render<H: PDF.HTML.View>` | 97-145 | Entry point |
| `render<H: HTML.View>` (`@_disfavoredOverload`) | 158-206 | Entry point |
| `pages<H: HTML.View>` (`@_disfavoredOverload`) | 222-265 | Entry point |
| `pages(header:footer:content:)` | 283-426 | Two-pass entry point |
| `renderHTMLView` | 437-442 | Dispatcher |
| `Dispatch` enum | 457-485 | Type |
| `iterativeDispatch` | 512-713 | Worklist interpreter |
| `renderFlattenedStyledContent` | 733-905 | Flattened style renderer |
| `isStyledType`, `isCSSWrapperType`, `isAttributesType`, `isConditionalType`, `isOptionalType` | 919-1001 | Mirror predicates |
| `applyStylePropertyViaMirror` | 1009-1032 | Style application |
| `renderInnerContent` | 1037-1042 | Delegation |
| `_TupleContent`, `_HTMLElementContent`, `_HTMLRawContent`, `_HTMLStyledContent`, `_ConditionalContent`, `_ArrayContent`, `_OptionalContent` | 1047-1120 | 7 protocols |
| `renderBlock`, `renderInline` | 1127-1168 | Static helpers |
| `renderBlockDynamic`, `renderInlineDynamic` | 1177-1205 | Dynamic helpers |

This file contains 4 type declarations, 7 protocol declarations, a 200-line worklist interpreter, a 170-line flattened renderer, and 4 entry points. It violates [API-IMPL-005] at least 10 times.

---

#### F-4: `HTML.Element+PDF.HTML.View.swift` Is a 2038-Line God-File

**File**: `HTML.Element+PDF.HTML.View.swift`
**Rules violated**: [API-IMPL-005]
**Severity**: FOUNDATIONAL

Contains both the static and dynamic dispatch rendering for ALL tag-based elements:

| Concern | Static lines | Dynamic lines |
|---|---|---|
| Tag rendering entry | ~130 | ~130 |
| Flow rendering (block/inline) | ~170 | ~120 |
| Table rendering | ~130 | ~85 |
| Table row rendering | ~260 | ~200 |
| Table cell rendering | ~200 | ~130 |
| Tag style application | ~65 | (shared) |
| Block margins | ~25 | (shared) |
| Border drawing | ~90 | (shared) |
| Header repetition | ~130 | (shared) |
| Heading detection | ~10 | (shared) |
| Text extraction | ~55 | (shared) |
| `PDFTextExtractable` protocol | ~10 | — |

After unifying the rendering paths (F-1), the file should be decomposed by concern.

---

#### F-5: Entry Point Duplication — 4 Nearly Identical Functions

**File**: `PDF.HTML.swift:33-265`
**Rules violated**: [IMPL-INTENT]
**Severity**: FOUNDATIONAL

All four entry points repeat the same ~20 lines:

```swift
var pdfContext = PDF.Context(mediaBox: ..., margins: ...)
pdfContext.style.font = configuration.defaultFont
pdfContext.style.fontSize = configuration.defaultFontSize
pdfContext.style.color = configuration.defaultColor
pdfContext.style.lineHeight = Scale(configuration.resolveLineHeight(...))
var context = PDF.HTML.Context(pdf: pdfContext, configuration: configuration)
// ... render (one line differs) ...
if let deferred = context.deferredKeepWithNextRender { ... }
context.pdf.flushInlineRuns()
let rawPages = context.pdf.pages
return PDF.Context.resolveInternalLinks(pages: rawPages, ...)
```

The only difference is one line: `H._render(html(), context:)` vs `renderHTMLView(html(), context:)`. And `pages` vs `render` differs only in whether it returns `RenderResult` (pages + headings) or just `[PDF.Page]`.

---

### STRUCTURAL

#### S-1: Context Is a God Object with 15+ Fields

**File**: `PDF.HTML.Context.swift`
**Rules violated**: [API-LAYER-002] (responsibility separation)
**Severity**: STRUCTURAL

`PDF.HTML.Context` holds fields spanning 6 different concerns:

| Concern | Fields |
|---|---|
| PDF layout | `pdf`, `configuration` |
| Table state | `table` |
| HTML attributes | `attributes` |
| Link tracking | `currentLinkURL`, `currentInternalLinkId`, `namedDestinations`, `pendingInternalLinks` |
| Margin collapsing | `pendingBottomMargin` |
| Break flags | `forcePageBreakAfter`, `avoidPageBreakAfter`, `avoidPageBreakInside`, `deferredKeepWithNextRender` |
| Section/heading tracking | `currentSectionTitle`, `pageSectionTitles`, `collectedHeadings` |

The ephemeral flags (`forcePageBreakAfter`, `avoidPageBreakAfter`, `avoidPageBreakInside`) are set-then-checked-then-reset within a single render call. They use a mutable context field as a communication channel between `applyStyle` and the caller — a pattern that should be a return value.

**Note**: Decomposing the context is lower priority than the rendering path unification. The context works correctly as-is; it's messy but not causing bugs. Consider this after F-1 through F-5 are addressed.

---

#### S-2: 19 Protocols — Some Redundant

**Files**: `PDF.HTML.StyleModifier.swift`, `PDF.HTML.swift`
**Rules violated**: [PATTERN-013] (concrete types before abstraction)
**Severity**: STRUCTURAL

| Category | Protocols | Assessment |
|---|---|---|
| **Public (essential)** | `View`, `StyleModifier`, `HTMLContextStyleModifier` | Keep — core API |
| **Internal (tag dispatch)** | `TagRenderer`, `ListContainer`, `ListItemRenderer`, `BlockMargins`, `VoidElementRenderer` | Keep — each has 2+ conformers, clear purpose |
| **Internal (table dispatch)** | `TableContainer`, `TableRowContainer`, `TableCellContainer`, `TableSectionContainer` | **Redundant** — empty marker protocols, dispatch is by tag name string |
| **Package (dynamic dispatch)** | `_TupleContent`, `_HTMLElementContent`, `_HTMLStyledContent`, `_HTMLRawContent`, `_ConditionalContent`, `_ArrayContent`, `_OptionalContent`, `_AnyViewContent` | **Partially redundant** — the worklist interpreter handles Styled/CSS/Attributes/Conditional/Optional via Mirror. `_HTMLElementContent` is still needed for terminal dispatch. Others may be eliminable. |

The four table protocols (`TableContainer`, `TableRowContainer`, `TableCellContainer`, `TableSectionContainer`) are declared but dispatch is actually by `view.tagName == "table"`, not by protocol conformance. They are dead code.

---

#### S-3: Compound Identifiers Throughout

**Files**: Throughout
**Rules violated**: [API-NAME-002]
**Severity**: STRUCTURAL

Methods using compound names:

| Current | Compliant shape |
|---|---|
| `renderHTMLView` | `render.html(view:)` or keep as internal dispatch (not public API) |
| `renderFlattenedStyledContent` | internal — compound name acceptable per [IMPL-024] |
| `renderBlock` / `renderInline` | `render.block()` / `render.inline()` |
| `renderBlockDynamic` / `renderInlineDynamic` | eliminated by F-1 |
| `applyCollapsedMargin` | `margin.collapse(top:bottom:)` |
| `applyStylePropertyViaMirror` | internal — compound name acceptable per [IMPL-024] |
| `isStyledType` / `isCSSWrapperType` / `isAttributesType` | internal predicates — compound name acceptable per [IMPL-024] |
| `_renderElementDynamically` etc. | eliminated by F-1 |
| `PDFTextExtractable` | `PDF.HTML.TextExtractable` per [API-NAME-001] |

**Assessment**: Most compound names are in the internal/package implementation layer where [IMPL-024] allows them. The public-facing ones (`renderBlock`, `renderInline`, `applyCollapsedMargin`, `PDFTextExtractable`) should be addressed. The dynamic dispatch methods are eliminated by F-1.

---

#### S-4: Duplicated `with` Utility

**Files**: `with.swift`, `PDF.HTML.Context.swift:236-255`
**Severity**: STRUCTURAL

Two identical `with` implementations exist:
1. Free functions at module scope (`with.swift:8-28`)
2. Instance methods on `PDF.HTML.Context` (`PDF.HTML.Context.swift:236-254`)

The instance method `context.with(\.table) { tc in ... }` is used ~30 times across the codebase. The free functions appear unused. Remove the dead code.

---

#### S-5: `PDFTextExtractable` at Module Scope

**File**: `HTML.Element+PDF.HTML.View.swift:16-19`
**Rules violated**: [API-NAME-001]
**Severity**: STRUCTURAL

`PDFTextExtractable` is a public protocol declared at file scope with a compound name. Should be `PDF.HTML.TextExtractable` per namespace rules. Also consider whether this protocol is necessary — it has only one conformer (`String`) and the Mirror fallback handles everything else.

---

#### S-6: Break Flags as Mutable State Instead of Return Values

**File**: `PDF.HTML.Context.swift:71-79`, `HTML.Styled+PDF.HTML.View.swift:61-87`
**Rules violated**: [IMPL-INTENT]
**Severity**: STRUCTURAL

The break flags (`forcePageBreakAfter`, `avoidPageBreakAfter`, `avoidPageBreakInside`) use a set-check-reset pattern:

```swift
// In applyStyle:
modifier.apply(to: &context)  // sets context.forcePageBreakAfter = true

// In caller:
if context.forcePageBreakAfter {
    shouldForce = true
    context.forcePageBreakAfter = false  // reset
}
```

This is mutation-as-communication. The style modifier's `apply` method mutates a flag on the context, then the caller reads and immediately clears it. The flag's lifetime is a single function call. This should be a return value from `apply`, not a context mutation.

---

### COSMETIC

#### C-1: Commented-Out Code

**File**: `HTML._Attributes+PDF.HTML.View.swift:12-28`
**Severity**: COSMETIC

Old implementation is commented out but left in place. Remove it — git history preserves it.

---

#### C-2: Template File Headers

**Files**: `PDF.HTML.Context.swift:1-6`, `PDF.HTML.Context.Table.swift:1-6`, `with.swift:1-6`, many others
**Severity**: COSMETIC

Multiple files have boilerplate headers:
```swift
//  File.swift
//  swift-pdf-html-rendering
//  Created by Coen ten Thije Boonkkamp on 10/12/2025.
```

The actual file name doesn't match. These add noise without information.

---

#### C-3: `_AnyViewContent` Protocol in Wrong File

**File**: `HTML.AnyView+PDF.HTML.View.swift:11-13`
**Severity**: COSMETIC

The `_AnyViewContent` protocol is declared in the `HTML.AnyView` conformance file. Per [API-IMPL-005], it should be in its own file. However, since it has exactly one conformer, consider whether the protocol indirection is necessary at all — the worklist interpreter could handle `HTML.AnyView` directly.

---

## Foundational Changes

The 5 changes with the deepest structural impact, ordered by dependency:

### 1. Unify Static and Dynamic Rendering Paths

**Eliminates**: F-1 (~780 lines of duplication), makes F-4 decomposition possible
**Approach**: Parameterize the rendering logic on a content rendering strategy.

The key insight: every duplicated method pair differs by exactly one thing — how child content is rendered. This is a classic strategy extraction:

```swift
// Instead of two copies of renderWithFlow / renderWithFlowDynamic:
private static func renderWithFlow(
    _ view: Self,
    isBlock: Bool,
    marginTop: PDF.UserSpace.Height,
    marginBottom: PDF.UserSpace.Height,
    pendingHeading: (level: Int, text: String)?,
    renderContent: (Content, inout PDF.HTML.Context) -> Void,
    renderBlockContent: (Content, inout PDF.HTML.Context) -> Void,
    renderInlineContent: (Content, inout PDF.HTML.Context) -> Void,
    context: inout PDF.HTML.Context
)
```

Static callers pass `{ Content._render($0, context: &$1) }`, dynamic callers pass `{ PDF.HTML.renderHTMLView($0, context: &$1) }`.

A cleaner alternative: since the dynamic path exists solely for `HTML.View` types that don't conform to `PDF.HTML.View`, consider whether all the work in the worklist interpreter (`iterativeDispatch`) can be a pre-processing step that ultimately delegates to the same `Tag._render`. The worklist already handles wrappers (Styled, CSS, Attributes, Conditional, Optional) and terminates at either `PDF.HTML.View._render` or `_renderElementDynamically`. If `_renderElementDynamically` delegates to `_render` with a content rendering closure, the duplication collapses.

**Risk**: Medium. The two paths have diverged subtly over time. Unification requires careful verification that all test cases pass on both paths. Run the full test suite after each incremental merge.

---

### 2. Extract `withSavedState` Infrastructure

**Eliminates**: F-2 (3 copies of save/restore pattern, ~66 lines total)
**Approach**: Add scoped state methods to `PDF.Context` and `PDF.HTML.Context`.

```swift
extension PDF.HTML.Context {
    /// Render with scoped style and box model state.
    /// Style, margins, padding, explicit width/height, and layout box X bounds
    /// are saved before the closure and restored after.
    mutating func withSavedStyleState(_ body: (inout Self) -> Void) {
        let saved = StyleStateSnapshot(from: self)
        body(&self)
        saved.restore(to: &self)
    }
}
```

The `StyleStateSnapshot` captures the 11 properties currently saved manually. This is infrastructure — it reads as intent ("render with scoped style") instead of mechanism ("save 11 properties, defer restore 11 properties").

**Prerequisite**: None. Can be done independently of change 1.

---

### 3. Extract Entry Point Setup into Shared Infrastructure

**Eliminates**: F-5 (4 copies of ~20 lines each, ~80 lines total)
**Approach**: Two shared methods — `prepareContext` and `finalizeRendering`.

```swift
extension PDF.HTML {
    /// Create a rendering context from configuration with all defaults applied.
    private static func prepareContext(
        configuration: PDF.HTML.Configuration
    ) -> PDF.HTML.Context { ... }

    /// Finalize rendering: flush deferred content, resolve links, return pages.
    private static func finalizeRendering(
        context: inout PDF.HTML.Context
    ) -> (pages: [PDF.Page], headings: [Context.HeadingEntry], destinations: [String: Context.DestinationInfo]) { ... }
}
```

The 4 entry points become:
```swift
public static func pages<H: PDF.HTML.View>(...) -> [PDF.Page] {
    var context = prepareContext(configuration: configuration)
    H._render(html(), context: &context)
    return finalizeRendering(context: &context).pages
}
```

**Prerequisite**: None. Can be done independently.

---

### 4. Decompose `PDF.HTML.swift` into One-Type-Per-File

**Eliminates**: F-3
**Approach**: Extract each declaration to its own file.

| Declaration | Target file |
|---|---|
| `PDF.HTML` namespace | `PDF.HTML.swift` (keep, ~5 lines) |
| `PDF.HTML.RenderResult` | `PDF.HTML.RenderResult.swift` |
| `PDF.HTML.PageInfo` | `PDF.HTML.PageInfo.swift` |
| Entry points (`pages`, `render`) | `PDF.HTML+Rendering.swift` |
| Two-pass rendering | `PDF.HTML+TwoPass.swift` |
| `Dispatch` enum + `iterativeDispatch` | `PDF.HTML.Dispatch.swift` |
| `renderFlattenedStyledContent` | `HTML.Styled+PDF.HTML.FlattenedRendering.swift` |
| Mirror predicates | `PDF.HTML+MirrorDetection.swift` |
| Dynamic dispatch protocols | `PDF.HTML+DynamicDispatch.swift` (or per-protocol) |
| `renderBlock` / `renderInline` helpers | `PDF.HTML+BlockInline.swift` |

**Prerequisite**: Changes 1 and 3 should come first — they reduce the amount of code to be moved.

---

### 5. Decompose `HTML.Element+PDF.HTML.View.swift` by Concern

**Eliminates**: F-4
**Approach**: After unifying rendering paths (change 1), split by concern.

| Concern | Target file |
|---|---|
| `Tag._render` + `renderWithFlow` | `HTML.Element.Tag+PDF.HTML.View.swift` |
| `renderTable` | `HTML.Element.Tag+Table.swift` |
| `renderTableRow` | `HTML.Element.Tag+TableRow.swift` |
| `renderTableCell` | `HTML.Element.Tag+TableCell.swift` |
| `applyTagStyle` + `blockMargins` | `HTML.Element.Tag+TagStyle.swift` |
| Border drawing helpers | `HTML.Element.Tag+TableBorders.swift` |
| Header repetition | `HTML.Element.Tag+HeaderRepetition.swift` |
| Text extraction + `PDFTextExtractable` | `PDF.HTML.TextExtractable.swift` |
| Heading level detection | Inline into `TagStyle` (10 lines) |

**Prerequisite**: Change 1 (unification) must come first — it eliminates the dynamic copies.

---

## Recommended Sequence

```
1. Extract entry point setup (F-5)             — independent, low risk
2. Extract withSavedState infrastructure (F-2)  — independent, low risk
3. Unify rendering paths (F-1)                  — highest impact, medium risk
4. Decompose PDF.HTML.swift (F-3)               — file moves, low risk after 1+3
5. Decompose HTML.Element+PDF.HTML.View.swift (F-4) — file moves, low risk after 3
```

Steps 1 and 2 can be done in parallel. Step 3 is the critical path — it has the highest impact and enables steps 4 and 5. Steps 4 and 5 can be done in parallel after 3.

Each step should be committed and tested independently. The test suite (81 passing tests) provides the safety net.

---

## Out of Scope

### Mirror-Based Type Detection (Intentional Fragility)

The 5 Mirror predicates (`isStyledType`, `isCSSWrapperType`, etc.) depend on internal field names of types in `swift-html-rendering`. This is inherently fragile. However:
- It exists because `as?` casts on deeply nested generic types crash with SIGBUS
- No better alternative exists given Swift's runtime limitations
- The predicates are clearly documented with fragility warnings
- They are localized in one place

**Verdict**: Accept as principled technical debt per [PATTERN-016]. The fragility is bounded, documented, and has clear removal criteria (when Swift fixes generic metadata instantiation).

### Worklist Interpreter Complexity

`iterativeDispatch` is ~200 lines of careful dispatch logic. It's complex but well-structured — the defunctionalized `Dispatch` enum with LIFO ordering correctly replicates recursive semantics. It replaced mutual recursion that caused stack overflow. The complexity is inherent to the problem.

**Verdict**: Leave as-is. The worklist is correct and well-documented.

### Configuration Size (650 Lines)

`PDF.HTML.Configuration.swift` is large but follows [API-IMPL-005] correctly — each nested type is in its own extension. The file is purely data (stored properties + initializers). It could be split, but there's no structural benefit.

**Verdict**: Low priority. Split only if it becomes a merge conflict hotspot.

### Table Context Size (491 Lines)

`PDF.HTML.Context.Table.swift` is large but cohesive — all table layout state in one place, with well-separated concerns via nested types (`SpanGrid`, `HeaderState`, `DeferredSpanningCell`, `PendingCellBorder`, `Cell`). Each nested type follows [API-IMPL-005] within extensions.

**Verdict**: Leave as-is. The size is proportional to the complexity of table layout.

### CSS Style Modifier Files (46 Files, ~12 Lines Each)

The CSS/ directory has 46+ files, most 12 lines (conformance to `PDF.HTML.StyleModifier`). This is exactly [API-IMPL-005] applied correctly.

**Verdict**: Correct structure. No change needed.

### HTML Element View Files (96 Files, ~12 Lines Each)

The HTML/ directory has 60+ element conformance files, most 12-20 lines. These are clean protocol conformances following [API-IMPL-005].

**Verdict**: Correct structure. No change needed.
