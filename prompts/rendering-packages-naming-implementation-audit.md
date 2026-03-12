# Rendering Packages — Naming & Implementation Audit

## Purpose

Perform a comprehensive audit of the three rendering packages against the
`/naming` and `/implementation` skills. This covers every source file in:

1. **swift-pdf-html-rendering** (Layer 3 — Foundations, 82 files, ~6,200 lines)
2. **swift-pdf-rendering** (Layer 3 — Foundations, 27 files, ~3,400 lines)
3. **swift-rendering-primitives** (Layer 1 — Primitives, 27 files, ~1,000 lines)

Total scope: **136 source files, ~10,700 lines** across 5 modules.

The audit produces a structured findings document with severity ratings,
file:line citations, requirement IDs, and concrete remediation proposals.
It does NOT make code changes — it produces the findings document only.

---

## Skills to Load

Before beginning the audit, load these skills (in order):

```
/naming
/implementation
```

The requirement IDs below are extracted from those skills and serve as the
audit checklist. Every source file must be evaluated against every applicable
requirement.

---

## Naming Requirements — [API-NAME-*]

### [API-NAME-001] Nest.Name Pattern

**Statement**: All types MUST use the `Nest.Name` pattern. Compound type
names are FORBIDDEN.

**Audit focus**:
- Any type whose name contains two or more concatenated nouns/concepts
  (e.g., `TextExtractable`, `PageBreakBefore`, `ListStyleType`)
- Any type that should be nested inside its parent namespace but is declared
  at module level
- Protocol names: protocols are types too — compound protocol names violate
  this rule

**Examples of violations to look for**:
```swift
PDFTextExtractable      // ❌ compound
PageBreakAfter          // ❌ compound — should be Break.After in a Page namespace
ListStyleType           // ❌ compound — should be List.Style.Type or similar
BackgroundColor         // ❌ compound — should be Background.Color
```

**Note**: CSS property names like `W3C_CSS_Backgrounds.BackgroundColor` may
get a pass IF they mirror the CSS specification naming (see [API-NAME-003]).
The audit should flag them but note the specification-mirroring justification.

### [API-NAME-002] No Compound Method/Property Identifiers

**Statement**: Methods and properties MUST NOT use compound names. Use nested
accessors.

**Audit focus**:
- Methods with two or more verbs/nouns concatenated
- Properties with compound names that could be nested

**Examples of violations to look for**:
```swift
func renderBlock(...)         // ❌ compound — should be render.block or similar
func renderInline(...)        // ❌ compound
func renderTableRow(...)      // ❌ compound
func applyTagStyle(...)       // ❌ compound
func extractCellText(...)     // ❌ compound
var pendingListMarker         // ❌ compound
var preserveWhitespace        // ❌ compound
var pendingBottomMargin       // ❌ compound
var deferredKeepWithNextRender  // ❌ compound
var avoidPageBreakAfter       // ❌ compound
```

### [API-NAME-003] Specification-Mirroring Names

**Statement**: Types implementing specifications MUST mirror the specification
terminology.

**Audit focus**:
- CSS property types should mirror W3C CSS specification names
- PDF types should mirror ISO 32000 terminology
- HTML element handling should mirror WHATWG HTML terminology

**Key question**: Do CSS `StyleModifier` conformances correctly mirror their
W3C CSS specification names? The current pattern is:
```
W3C_CSS_Backgrounds.BackgroundColor+PDF.HTML.StyleModifier.swift
```
This mirrors the spec module (`W3C_CSS_Backgrounds`) but uses a compound
type name (`BackgroundColor`). The audit should determine whether these
names faithfully mirror the spec or whether the spec itself uses nested
naming that we're flattening.

### [API-NAME-004] No Typealias Unification Bridges

**Statement**: When unifying duplicate types across packages, the canonical
type MUST be used directly. Typealiases MUST NOT be introduced as a bridge.

**Audit focus**:
- Any `typealias` that exists solely to bridge between packages
- Re-exports that create type aliases rather than using the canonical type

---

## Implementation Requirements — [IMPL-*]

### [IMPL-INTENT] Code Reads as Intent, Not Mechanism

**Statement**: Code must communicate what it does, not how it does it.
Reader should understand purpose from names and structure alone.

**Audit focus** (this is the most broadly applicable requirement):
- Functions whose names describe mechanism rather than intent
- Variables named after their implementation detail rather than their role
- Control flow that obscures intent (deeply nested if/else, raw index
  manipulation, manual state machines)
- Comments that explain "what" when the code should be self-documenting

**High-priority files for this check**:
```
PDF.HTML+Dispatch.swift                    (584 lines — worklist interpreter)
HTML.Element+PDF.HTML.View.swift           (402 lines — tag rendering)
PDF.HTML.Context.Table.swift               (487 lines — table layout)
HTML.Element.Tag+TableRow.swift            (265 lines — row rendering)
HTML.Element.Tag+TableCell.swift           (203 lines — cell rendering)
PDF.Context.swift                          (891 lines — core PDF context)
PDF.Context.TextRun+Rendering.swift        (552 lines — text run rendering)
PDF.HTML.Configuration.swift               (650 lines — configuration)
```

### [IMPL-000] Call-Site-First Design

**Statement**: Design APIs from the call site backwards.

**Audit focus**:
- Entry points in `PDF.HTML+EntryPoints.swift` — are the call sites clean?
- `PDF.Document+HTML.swift` — document construction API
- Builder patterns — does `@HTML.Builder` produce readable call sites?

### [IMPL-001] Principled Absences

**Statement**: Use typed `Optional` for principled absences, never sentinel
values or empty collections as "none".

**Audit focus**:
- Empty string used as "no value" instead of `nil`
- Empty array used as "no items" when the distinction matters
- Magic values (0, -1, etc.) used as sentinels

### [IMPL-006] Zero-Cost Typed Stored Properties

**Statement**: Stored properties should use typed wrappers, not raw primitives.

**Audit focus**:
- `Int` used where `Count`, `Index<T>`, or `Offset` would be appropriate
- `Double`/`CGFloat` used where typed dimensions would be appropriate
- Raw numeric literals without typed context

### [IMPL-010] Push Int to the Edge

**Statement**: Internal code should use typed indices/counts. `Int` only at
API boundaries.

**Audit focus**:
- `pageNumber: Int` — should this be `Page.Number` or `Index<Page>`?
- `level: Int` for heading levels — should this be `Heading.Level`?
- `totalPages: Int` — should this be `Count<Page>`?
- Array subscripts with raw `Int` where a typed index would be clearer

### [IMPL-020] Verb-as-Property with callAsFunction

**Statement**: When a type represents a single action, use `callAsFunction`.

**Audit focus**:
- `DeferredRender` has a `render` closure — should it use `callAsFunction`?
- Any type whose primary purpose is a single verb

### [IMPL-023] Core Logic in Static Methods

**Statement**: Core logic lives in static methods. Instance methods delegate.

**Audit focus**:
- `_render` is already static — good
- Are there instance methods that contain core logic that should be static?

### [IMPL-024] Compound Identifiers in the Static Layer

**Statement**: Compound identifiers are ACCEPTABLE in the static method layer
(private implementation detail). They are forbidden at the API surface.

**Audit focus**:
- Private helper methods with compound names (acceptable if truly private)
- Public API methods with compound names (violations)

### [IMPL-030] Inline Construction Over Intermediate Variables

**Statement**: Prefer inline construction. Avoid naming temporaries that add
no clarity.

**Audit focus**:
- Variables created solely to be passed to the next line
- `let x = Foo(...); bar(x)` where `bar(Foo(...))` would be clearer

### [IMPL-031] Enum Iteration Over Manual Switch

**Statement**: Prefer `allCases` iteration over manual switch statements.

**Audit focus**:
- Switch statements on enums that could use iteration
- `TagStyle.swift` tag name matching — is string-based switching the right
  approach, or should tags be an enum?

### [IMPL-033] Iteration: Intent Over Mechanism

**Statement**: Prefer higher-order functions over manual loops.

**Audit focus**:
- Manual `for` loops that could be `map`, `filter`, `reduce`, `forEach`
- Index-based iteration where collection iteration would be clearer

### [IMPL-034] unsafe Keyword Placement

**Statement**: `unsafe` keyword must be placed correctly per Swift 6 rules.

**Audit focus**:
- Any `@unchecked Sendable` conformances — are they justified?
- `DeferredRender` is `@unchecked Sendable` — audit justification

### [IMPL-040] Typed Throws vs Preconditions

**Statement**: Use typed throws for recoverable errors, preconditions for
programmer errors.

**Audit focus**:
- Are there any `fatalError` or `preconditionFailure` calls that should
  be typed throws?
- Are there `throws` that should be preconditions?

### [IMPL-041] Error Type Nesting

**Statement**: Error types must be nested inside their parent type.

**Audit focus**:
- Any standalone error types that should be nested

### [IMPL-050–053] Bounded Indices

**Statement**: Static-capacity types must use bounded index types.

**Audit focus**:
- Table column indices — are they bounded?
- Page numbers — are they bounded (1-indexed)?

---

## Pattern Requirements — [PATTERN-*]

### [PATTERN-009] No Foundation Types

**Statement**: Primitives MUST NOT import Foundation.

**Audit focus**:
- `swift-rendering-primitives` — verify zero Foundation imports
- `swift-pdf-rendering` and `swift-pdf-html-rendering` — Foundation is
  discouraged but not forbidden at Layer 3. Flag any imports.

### [PATTERN-010] Nested Type Names

**Statement**: Types that belong to a parent namespace must be nested, not
prefixed.

**Audit focus**:
- Same as [API-NAME-001] but from the implementation perspective
- `PDF.HTML.TextExtractable` — was recently renamed from `PDFTextExtractable`,
  verify it's properly nested now

### [PATTERN-012] Initializers as Canonical Implementation

**Statement**: Prefer initializers over factory methods when constructing
values.

**Audit focus**:
- `prepareContext(configuration:)` — should this be `Context.init`?
- `finalizeRendering(context:)` — should this return via a method on Context?

### [PATTERN-013] Concrete Types Before Abstraction

**Statement**: Start with concrete types. Add protocols only when needed.

**Audit focus**:
- `PDF.HTML.View` protocol — is it justified by multiple conformers? (Yes — 15+)
- `StyleModifier` protocol — is it justified? (Yes — 30+ conformers)
- `HTMLContextStyleModifier` protocol — is it justified? (Yes — 30+ conformers)
- `_HTMLElementContent` — is this protocol necessary? Could it be replaced?
- `_HTMLStyledContent` — same question
- `_AnyViewContent` — same question
- `PDF.HTML.TextExtractable` — same question

### [PATTERN-016] Conscious Technical Debt

**Statement**: Technical debt must be marked with `// DEBT:` comments.

**Audit focus**:
- Unmarked technical debt (workarounds, known limitations, temporary code)
- The Mirror-based dispatch in `PDF.HTML+Dispatch.swift` is a workaround for
  compiler crashes — is it marked as debt?

### [PATTERN-017] rawValue and Property Access Location

**Statement**: `.rawValue` access should be at the boundary, not deep in
business logic.

**Audit focus**:
- Any `.rawValue` access in rendering logic that should be at the edge

### [PATTERN-022] ~Copyable Nested Types in Separate Files

**Statement**: ~Copyable nested types must be in their own files.

**Audit focus**:
- Are there any `~Copyable` types in these packages? If so, verify file
  separation.

---

## File Inventory — swift-pdf-html-rendering

### Module: PDF HTML Rendering (82 files)

#### Namespace & Entry Points
| File | Lines | Audit Priority |
|------|-------|----------------|
| `PDF.HTML.swift` | 9 | LOW — namespace enum |
| `PDF.HTML+EntryPoints.swift` | 183 | HIGH — public API surface |
| `PDF.HTML.RenderResult.swift` | 60 | MEDIUM — result type + shared infra |
| `PDF.HTML.View.swift` | 48 | MEDIUM — core protocol |
| `PDF.HTML.Render.swift` | 85 | HIGH — block/inline dispatch |
| `PDF.Document+HTML.swift` | 106 | MEDIUM — document construction |
| `exports.swift` | 23 | LOW — re-exports |

#### Context & Configuration
| File | Lines | Audit Priority |
|------|-------|----------------|
| `PDF.HTML.Context.swift` | 317 | HIGH — context + sub-structs |
| `PDF.HTML.Context.Table.swift` | 487 | HIGH — table layout context |
| `PDF.HTML.Configuration.swift` | 650 | HIGH — all configuration |

#### Core Rendering Pipeline
| File | Lines | Audit Priority |
|------|-------|----------------|
| `PDF.HTML+Dispatch.swift` | 584 | CRITICAL — worklist interpreter |
| `HTML.Element+PDF.HTML.View.swift` | 402 | CRITICAL — tag rendering |
| `HTML.Styled+PDF.HTML.View.swift` | 160 | HIGH — CSS property application |
| `HTML.Element.Tag+TagStyle.swift` | 156 | HIGH — tag→style mapping |
| `HTML.Element.Tag+Table.swift` | 140 | HIGH — table container |
| `HTML.Element.Tag+TableRow.swift` | 265 | HIGH — row rendering |
| `HTML.Element.Tag+TableCell.swift` | 203 | HIGH — cell rendering |
| `HTML.Element.Tag+TableBorders.swift` | 101 | MEDIUM — border rendering |
| `HTML.Element.Tag+HeaderRepetition.swift` | 136 | MEDIUM — header repeat |

#### Dynamic Dispatch & Protocols
| File | Lines | Audit Priority |
|------|-------|----------------|
| `PDF.HTML+DynamicDispatchProtocols.swift` | 64 | HIGH — marker protocols |
| `PDF.HTML.StyleModifier.swift` | 34 | MEDIUM — style protocols |
| `PDF.HTML.TextExtractable.swift` | 76 | MEDIUM — text extraction |

#### Leaf View Conformances
| File | Lines | Audit Priority |
|------|-------|----------------|
| `String+PDF.HTML.View.swift` | 29 | LOW |
| `HTML.Text+PDF.HTML.View.swift` | 19 | LOW |
| `HTML.Empty+PDF.HTML.View.swift` | 14 | LOW |
| `HTML.Raw+PDF.HTML.View.swift` | 13 | LOW |
| `HTML.AnyView+PDF.HTML.View.swift` | 18 | LOW |
| `Never+PDF.HTML.View.swift` | 13 | LOW |
| `ForEach+PDF.HTML.View.swift` | 17 | LOW |
| `Optional+PDF.HTML.View.swift` | 23 | LOW |
| `_Conditional+PDF.HTML.View.swift` | 27 | LOW |
| `_Tuple+Transform.swift` | 25 | LOW |
| `_Array+PDF.HTML.View.swift` | 29 | LOW |
| `CSS+PDF.HTML.View.swift` | 22 | LOW |
| `HTML._Attributes+PDF.HTML.View.swift` | 76 | MEDIUM |

#### HTML Element Rendering
| File | Lines | Audit Priority |
|------|-------|----------------|
| `HTML/Image+PDF.HTML.View.swift` | 211 | MEDIUM — image rendering |
| `HTML/BR+PDF.HTML.View.swift` | 26 | LOW |
| `HTML/ThematicBreak+PDF.HTML.View.swift` | 37 | LOW |
| `HTML/InlineQuotation+PDF.HTML.View.swift` | 10 | LOW |

#### CSS StyleModifier Conformances (32 files, 12–37 lines each)
| File | Lines |
|------|-------|
| `CSS/W3C_CSS_Backgrounds.BackgroundColor+PDF.HTML.StyleModifier.swift` | 27 |
| `CSS/W3C_CSS_Backgrounds.Border+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Backgrounds.BorderCollapse+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Backgrounds.BorderColor+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Backgrounds.BorderRadius+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Backgrounds.BorderSpacing+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Backgrounds.BorderStyle+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Backgrounds.BorderWidth+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_BoxModel.Height+PDF.HTML.StyleModifier.swift` | 31 |
| `CSS/W3C_CSS_BoxModel.Margin+PDF.HTML.StyleModifier.swift` | 70 |
| `CSS/W3C_CSS_BoxModel.MarginBottom+PDF.HTML.StyleModifier.swift` | 28 |
| `CSS/W3C_CSS_BoxModel.MarginLeft+PDF.HTML.StyleModifier.swift` | 28 |
| `CSS/W3C_CSS_BoxModel.MarginRight+PDF.HTML.StyleModifier.swift` | 28 |
| `CSS/W3C_CSS_BoxModel.MarginTop+PDF.HTML.StyleModifier.swift` | 28 |
| `CSS/W3C_CSS_BoxModel.MaxHeight+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_BoxModel.MaxWidth+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_BoxModel.MinHeight+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_BoxModel.MinWidth+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_BoxModel.Padding+PDF.HTML.StyleModifier.swift` | 127 |
| `CSS/W3C_CSS_BoxModel.PaddingBottom+PDF.HTML.StyleModifier.swift` | 25 |
| `CSS/W3C_CSS_BoxModel.PaddingLeft+PDF.HTML.StyleModifier.swift` | 25 |
| `CSS/W3C_CSS_BoxModel.PaddingRight+PDF.HTML.StyleModifier.swift` | 25 |
| `CSS/W3C_CSS_BoxModel.PaddingTop+PDF.HTML.StyleModifier.swift` | 25 |
| `CSS/W3C_CSS_BoxModel.Width+PDF.HTML.StyleModifier.swift` | 31 |
| `CSS/W3C_CSS_Color.Color+PDF.HTML.StyleModifier.swift` | 21 |
| `CSS/W3C_CSS_Display.Display+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Fonts.FontSize+PDF.HTML.StyleModifier.swift` | 31 |
| `CSS/W3C_CSS_Fonts.FontStyle+PDF.HTML.StyleModifier.swift` | 20 |
| `CSS/W3C_CSS_Fonts.FontWeight+PDF.HTML.StyleModifier.swift` | 27 |
| `CSS/W3C_CSS_Lists.ListStylePosition+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Lists.ListStyleType+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Multicolumn.BreakAfter+PDF.HTML.StyleModifier.swift` | 32 |
| `CSS/W3C_CSS_Multicolumn.BreakBefore+PDF.HTML.StyleModifier.swift` | 37 |
| `CSS/W3C_CSS_Multicolumn.BreakInside+PDF.HTML.StyleModifier.swift` | 28 |
| `CSS/W3C_CSS_Paged.Orphans+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Paged.PageBreakAfter+PDF.HTML.StyleModifier.swift` | 21 |
| `CSS/W3C_CSS_Paged.PageBreakBefore+PDF.HTML.StyleModifier.swift` | 26 |
| `CSS/W3C_CSS_Paged.PageBreakInside+PDF.HTML.StyleModifier.swift` | 22 |
| `CSS/W3C_CSS_Paged.Widows+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Text.LetterSpacing+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Text.LineHeight+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Text.TextAlign+PDF.HTML.StyleModifier.swift` | 25 |
| `CSS/W3C_CSS_Text.TextIndent+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Text.TextTransform+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Text.WhiteSpace+PDF.HTML.StyleModifier.swift` | 12 |
| `CSS/W3C_CSS_Text.WordSpacing+PDF.HTML.StyleModifier.swift` | 12 |

#### CSS Support
| File | Lines | Audit Priority |
|------|-------|----------------|
| `CSS/CSS+PDF.UserSpace.Size.swift` | 157 | MEDIUM — unit conversion |
| `CSS/CSS.LineBox.swift` | 114 | MEDIUM — line box model |
| `CSS/PDF.Color.swift` | 18 | LOW — color conversion |

---

## File Inventory — swift-pdf-rendering

### Module: PDF Rendering (27 files)

#### Core Types
| File | Lines | Audit Priority |
|------|-------|----------------|
| `PDF.Context.swift` | 891 | CRITICAL — core layout engine |
| `PDF.Context.TextRun+Rendering.swift` | 552 | CRITICAL — text rendering |
| `PDF.Context.TextRun.swift` | 185 | HIGH — text run type |
| `PDF.Context.Style.swift` | 245 | HIGH — style resolution |
| `PDF.Context.Style.Resolved.swift` | 76 | MEDIUM — resolved style |
| `PDF.Context.ListType.swift` | 16 | LOW — list type enum |
| `PDF.Context.ListMarker.swift` | 32 | LOW — list marker enum |
| `PDF.Page.swift` | 34 | LOW — page type |
| `PDF.Document.swift` | 55 | LOW — document type |
| `PDF.Element.swift` | 155 | MEDIUM — element primitives |
| `PDF.View.swift` | 63 | MEDIUM — view protocol |
| `PDF.Builder.swift` | 25 | LOW — result builder |
| `exports.swift` | 4 | LOW |

#### View Conformances
| File | Lines | Audit Priority |
|------|-------|----------------|
| `Rendering/PDF.Stack+PDF.View.swift` | 126 | MEDIUM — stack layout |
| `Rendering/Pair+PDF.View.swift` | 174 | MEDIUM — pair rendering |
| `Rendering/_Tuple+PDF.View.swift` | 76 | LOW |
| `Rendering/_Array+PDF.View.swift` | 73 | LOW |
| `Rendering/PDF.Divider+PDF.View.swift` | 57 | LOW |
| `Rendering/PDF.Rectangle+PDF.View.swift` | 40 | LOW |
| `Rendering/PDF.Spacer+PDF.View.swift` | 27 | LOW |
| `Rendering/_Conditional+PDF.View.swift` | 20 | LOW |
| `Rendering/Optional+PDF.View.swift` | 16 | LOW |
| `Rendering/ForEach+PDF.View.swift` | 11 | LOW |
| `Rendering/Never+PDF.View.swift` | 18 | LOW |
| `Rendering/Empty+PDF.View.swift` | 15 | LOW |

#### ISO 32000 Integration
| File | Lines | Audit Priority |
|------|-------|----------------|
| `ISO_32000+PDF.View/ISO_32000.Text+PDF.View.swift` | 172 | MEDIUM |
| `ISO_32000+PDF.View/ISO 32000.Table+PDF.View.swift` | 262 | HIGH |

---

## File Inventory — swift-rendering-primitives

### Module: Rendering Primitives Core (15 files)

| File | Lines | Audit Priority |
|------|-------|----------------|
| `Rendering.Protocol.swift` | 62 | HIGH — core protocol |
| `Rendering.Builder.swift` | 88 | MEDIUM — result builder |
| `Rendering.Element.swift` | 134 | MEDIUM — element types |
| `Rendering._Conditional.swift` | 46 | LOW |
| `Rendering._Array.swift` | 43 | LOW |
| `Rendering.AnyView.swift` | 37 | LOW |
| `Rendering.Raw.swift` | 32 | LOW |
| `Rendering.Group.swift` | 31 | LOW |
| `Rendering._TupleMarker.swift` | 28 | LOW |
| `Rendering._Tuple.swift` | 20 | LOW |
| `Optional+Rendering.swift` | 20 | LOW |
| `Rendering.ForEach.swift` | 58 | LOW |
| `Rendering.Empty.swift` | 17 | LOW |
| `Rendering.swift` | 12 | LOW — namespace |
| `exports.swift` | 1 | LOW |

### Module: Rendering Async Primitives (10 files)

| File | Lines | Audit Priority |
|------|-------|----------------|
| `Rendering.Async.Protocol.swift` | 123 | MEDIUM |
| `Rendering.Async.Sink.Buffered.swift` | 100 | MEDIUM |
| `Rendering.Async.Sink.Chunked.swift` | 91 | MEDIUM |
| `Rendering.Async.Sink.Protocol.swift` | 14 | LOW |
| `Rendering.Async.Sink.swift` | 9 | LOW |
| `Rendering.Async.swift` | 11 | LOW |
| `Rendering._Conditional+Async.swift` | 20 | LOW |
| `Rendering._Array+Async.swift` | 17 | LOW |
| `Rendering.Group+Async.swift` | 5 | LOW |
| `Optional+Async.swift` | 13 | LOW |
| `exports.swift` | 2 | LOW |

### Module: Rendering Primitives (umbrella, 1 file)

| File | Lines | Audit Priority |
|------|-------|----------------|
| `exports.swift` | 2 | LOW |

---

## Audit Procedure

### Phase 1: CRITICAL files (4 files, ~2,300 lines)

Read and audit these files first. They contain the most logic and the
highest density of potential violations:

1. `PDF.Context.swift` (891 lines) — Core layout engine
2. `PDF.HTML+Dispatch.swift` (584 lines) — Worklist interpreter
3. `PDF.Context.TextRun+Rendering.swift` (552 lines) — Text rendering
4. `HTML.Element+PDF.HTML.View.swift` (402 lines) — Tag rendering

For each file, evaluate against ALL naming and implementation requirements.
Record findings in this format:

```
### Finding [N-001]: [Title]
- **Severity**: CRITICAL | HIGH | MEDIUM | LOW
- **Requirement**: [API-NAME-001] / [IMPL-INTENT] / etc.
- **Location**: file.swift:42
- **Current**: `currentCode`
- **Proposed**: `proposedFix`
- **Rationale**: Why this violates the requirement
```

### Phase 2: HIGH priority files (~2,600 lines)

Read and audit:
1. `PDF.HTML.Configuration.swift` (650 lines)
2. `PDF.HTML.Context.Table.swift` (487 lines)
3. `HTML.Element.Tag+TableRow.swift` (265 lines)
4. `PDF.Context.Style.swift` (245 lines)
5. `HTML.Element.Tag+TableCell.swift` (203 lines)
6. `PDF.HTML+EntryPoints.swift` (183 lines)
7. `PDF.Context.TextRun.swift` (185 lines)
8. `HTML.Styled+PDF.HTML.View.swift` (160 lines)
9. `HTML.Element.Tag+TagStyle.swift` (156 lines)
10. `HTML.Element.Tag+Table.swift` (140 lines)

### Phase 3: MEDIUM priority files (~1,400 lines)

Read and audit:
1. `Rendering.Protocol.swift` (62 lines)
2. `Rendering.Element.swift` (134 lines)
3. `Rendering.Builder.swift` (88 lines)
4. `ISO 32000.Table+PDF.View.swift` (262 lines)
5. `ISO_32000.Text+PDF.View.swift` (172 lines)
6. `PDF.Element.swift` (155 lines)
7. `PDF.HTML.Context.swift` (317 lines)
8. `CSS+PDF.UserSpace.Size.swift` (157 lines)
9. `CSS.LineBox.swift` (114 lines)

### Phase 4: LOW priority files (sweep)

Scan remaining files (mostly small leaf conformances and CSS modifiers).
These are typically 10–30 lines and unlikely to have significant violations,
but compound names in type/protocol declarations should still be caught.

---

## Known Context

### Recent Changes (2026-03-12)

The following changes were made in the previous audit session:

1. **Dead code removal**: 56 per-element HTML tag files deleted (contained
   dead `TagRenderer`/`BlockMargins`/`ListContainer`/`ListItemRenderer`
   protocol conformances). Five dead protocols removed from
   `PDF.HTML.StyleModifier.swift`.

2. **Protocol cleanup**: `_TupleContent`, `_ConditionalContent`,
   `_OptionalContent` protocols removed (redundant with Phase 1 Mirror
   detection in the worklist interpreter).

3. **Context decomposition**: `PDF.HTML.Context` gained `Link` and `Section`
   sub-structs grouping related fields. Block flow fields (`pendingBottomMargin`,
   `deferredKeepWithNextRender`, break flags) were left flat.

4. **Break flag capture**: `BreakFlags` struct + `captureBreakFlags()` method
   replaced manual set-check-reset pattern.

5. **Render namespace**: `PDF.HTML.Render` enum with `block`/`inline` static
   methods replaced top-level `renderBlock`/`renderInline` free functions.

6. **Renamed**: `PDFTextExtractable` → `PDF.HTML.TextExtractable`.

7. **Stale headers**: All Xcode template headers replaced with descriptive
   file-level comments.

### Architecture Notes

- **Worklist interpreter** (`PDF.HTML+Dispatch.swift`): Uses `Stack<Dispatch>`
  with LIFO ordering for defer-equivalent semantics. Avoids mutual recursion
  that caused stack overflow on deeply nested `_Tuple` types. Uses Mirror-based
  Phase 1 detection to avoid `as?` casts that SIGBUS on 70+ element types.

- **Two rendering paths**: Static dispatch (`PDF.HTML.View` conformances) and
  dynamic dispatch (`HTML.View` via `renderHTMLView` + marker protocols).
  Static path uses `_render(_:context:)`. Dynamic path uses the worklist
  interpreter.

- **CSS property application**: `HTML.Styled` wrapper type captures CSS
  properties. `applyStyle(to:)` maps CSS values to PDF context mutations.
  `StyleModifier` and `HTMLContextStyleModifier` protocols allow CSS property
  types to self-apply.

- **Table rendering**: Multi-pass approach — first pass measures column
  widths, second pass renders cells. Header repetition on page breaks is
  handled by `HeaderRepetition`.

---

## Output Format

Write the findings document to:
```
/Users/coen/Developer/swift-institute/Research/rendering-packages-naming-implementation-audit.md
```

Structure the document as:

```markdown
# Rendering Packages — Naming & Implementation Audit Findings

## Summary
- Total findings: N
- CRITICAL: N | HIGH: N | MEDIUM: N | LOW: N
- By requirement: [table of requirement ID → count]

## CRITICAL Findings
### Finding [N-001]: ...

## HIGH Findings
### Finding [N-002]: ...

## MEDIUM Findings
...

## LOW Findings
...

## Recommendations
- Priority-ordered list of changes to make
- Grouping by file where changes cluster
- Estimated churn impact
```

---

## Constraints

1. **Read-only audit**: Do NOT modify any source files. Produce findings only.
2. **Cite exact lines**: Every finding must include `file.swift:NN`.
3. **One finding per violation**: Do not bundle multiple violations.
4. **Classify severity**:
   - CRITICAL: Public API naming violation, active bug risk
   - HIGH: Internal naming violation in high-traffic code, mechanism-over-intent
   - MEDIUM: Style deviation, minor naming issue, could-be-better pattern
   - LOW: Cosmetic, comment quality, optional improvement
5. **Spec-mirroring exception**: CSS property names that mirror W3C spec
   terminology get a MEDIUM at most (not HIGH/CRITICAL) even if they are
   compound, per [API-NAME-003].
6. **Static layer exception**: Compound identifiers in `private` static
   helper methods are acceptable per [IMPL-024]. Still flag them as LOW
   if a better name exists.
7. **Load skills first**: The auditor MUST load `/naming` and `/implementation`
   before beginning, to have the full requirement text available.
