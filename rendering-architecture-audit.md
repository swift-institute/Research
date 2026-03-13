# Rendering Architecture Audit — Findings

**Date**: 2026-03-13
**Scope**: `swift-rendering-primitives` (L1), `swift-html-rendering` (L3), `swift-svg-rendering` (L3), `swift-pdf-rendering` (L3)
**Skills**: `/implementation`, `/naming`
**Reference**: `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Experiments/vertical-slice-rendering/`

---

## Summary

| Severity | L1 | HTML | SVG | PDF | Cross | Total |
|----------|---:|-----:|----:|----:|------:|------:|
| Critical | 0  | 3    | 0   | 5   | 1     | **9** |
| High     | 6  | 5    | 2   | 8   | 0     | **21** |
| Medium   | 8  | 8    | 7   | 9   | 3     | **35** |
| Low      | 5  | 6    | 5   | 5   | 0     | **21** |
| **Total**| 19 | 22   | 14  | 27  | 4     | **86** |

### Top-Level Observations

1. **L1 protocol naming cascades everywhere.** The `Rendering.Context` protocol defines 13+ compound method names (`pushBlock`, `addClassName`, `writeRawBytes`, etc.). Every L3 conformer inherits these. Fixing at L1 fixes all packages.

2. **CSS/SVG/PDF spec-mirroring creates a persistent tension** with [API-NAME-002]. Properties like `fontSize`, `fontWeight`, `lineHeight`, `strokeWidth` mirror specification terminology directly. The audit flags each but acknowledges [API-NAME-003] as a valid defense.

3. **PDF.Context has 28+ compound stored properties** — the single largest naming concentration. A nested-namespace decomposition (layout, text, pagination, list, inline) would dramatically improve readability.

4. **Scope completeness** is the only correctness concern. PDF's `Scope` captures 4 fields but `pushBlock` can modify fields not captured. Currently safe but brittle.

5. **SVG is architecturally clean** post-Phase 3. No vestigial `Rendering.Protocol` references. Main concern is 50+ compound attribute methods (all spec-mirroring).

---

## Decision Points for the Architect

These require explicit decisions before implementation:

### D1. Push/Pop Compound Names in Rendering.Context
Should `pushBlock`/`popBlock` become `push(block:style:)` / `pop(block:)`?

- **For**: Eliminates compound names; all push/pop become overloads of `push` and `pop` with different argument labels, creating a unified pattern.
- **Against**: `pushBlock`/`popBlock` is standard stack terminology. The vertical-slice experiment uses the same naming intentionally.
- **Blast radius**: All `Rendering.Context` conformers (HTML.Context, PDF.Context, any future context).
- **Recommendation**: Do it. The overloaded `push(block:)` / `push(inline:)` / `push(list:)` / `push(link:)` / `push(item:)` / `push(element:)` pattern reads better and is still stack terminology.

### D2. Break Method Compound Names
Should `lineBreak`/`thematicBreak`/`pageBreak` become `break.line()` / `break.thematic()` / `break.page()`?

- **For**: Eliminates compound names; groups all break operations.
- **Against**: `break` is a Swift keyword (requires backticks). `lineBreak` mirrors CSS `line-break`. These are specification-standard terms per [API-NAME-003].
- **Recommendation**: Defer. The backtick requirement makes this ugly. Accept as spec-mirroring compounds.

### D3. Element Method Compound Names
Should `setAttribute`, `addClassName`, `writeRawBytes` become nested accessors?

- **For**: `set(attribute:)`, `add(className:)`, `write(raw:)` read as verb + noun label.
- **Against**: These are default-implemented protocol methods; high blast radius but low external usage (only HTML.Context overrides them).
- **Recommendation**: Do it. The verb + noun-label pattern is clean and low-risk since only HTML overrides these defaults.

### D4. CSS Property Name Mirroring
When compound names like `fontSize`, `fontWeight`, `lineHeight` mirror CSS terminology, should we refactor to `font.size`, `font.weight`, `line.height`?

- **For**: Full [API-NAME-002] compliance. Nested accessors enable `style.font.size` which is natural.
- **Against**: CSS developers expect `fontSize`. Every web framework uses camelCase CSS properties.
- **Recommendation**: For `Rendering.Style` (4 properties, L1), introduce `Font` sub-struct: `style.font.size`, `style.font.weight`. For L3 types (`PDF.Context.Style.Resolved`, SVG attributes), defer — these are larger surfaces with spec-mirroring defense.

### D5. SVG.AnyView / SVG.GeometryContext
Are these compound names acceptable?

- **For keeping**: SwiftUI uses `AnyView`. Convention.
- **For renaming**: SwiftUI convention is not authoritative in this ecosystem. `SVG.View.Erased` follows Nest.Name. `GeometryContext` file defines no type — just needs a file rename.
- **Recommendation**: Rename `AnyView` to `SVG.View.Erased`. Rename the `GeometryContext` file to `Geometry+SVG.View.swift`.

### D6. Underscore Prefix Convention
`Rendering._Tuple`, `HTML._Attributes`, `SVG._Attributes` — intentional or vestigial?

- **Assessment**: Intentional. The underscore signals "builder-internal, not user-facing API." This mirrors SwiftUI's `_ConditionalContent`, `_ViewModifier_Content`. Users never write these types directly.
- **Recommendation**: Keep. Document the convention.

### D7. Scope Completeness
PDF `Scope` captures `style`, `llx`, `preserveWhitespace`, `currentLinkURL`. Should it capture more?

- **Assessment**: Currently safe because VStack/HStack manage their own save/restore for `stackSpacing`/`horizontalSpacing`. But fragile — a new push role that modifies these fields without its own save/restore would silently leak state.
- **Recommendation**: Add `lastElementY` and `stackSpacing` to Scope. Low effort, high safety value.

---

## L1: swift-rendering-primitives

**Location**: `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/`

### Critical

None.

### High

#### L1-H-001 — `pushBlock`/`popBlock` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:24`
- **Current**: `pushBlock(role:style:)` / `popBlock()`
- **Recommended**: `push(block role:style:)` / `pop(block:)`
- **Impact**: All `Rendering.Context` conformers (HTML, PDF, any future context)
- **Priority**: High — see Decision D1

#### L1-H-002 — `pushInline`/`popInline` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:27`
- **Current**: `pushInline(role:style:)` / `popInline()`
- **Recommended**: `push(inline role:style:)` / `pop(inline:)`
- **Impact**: Same as L1-H-001
- **Priority**: High

#### L1-H-003 — `pushList`/`popList`/`pushItem`/`popItem` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:30-31`
- **Current**: `pushList(kind:start:)` / `popList()` / `pushItem()` / `popItem()`
- **Recommended**: `push(list kind:start:)` / `pop(list:)` / `push(item:)` / `pop(item:)`
- **Impact**: Same as L1-H-001
- **Priority**: High

#### L1-H-004 — `pushLink`/`popLink` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:40-41`
- **Current**: `pushLink(destination:)` / `popLink()`
- **Recommended**: `push(link destination:)` / `pop(link:)`
- **Impact**: Same as L1-H-001
- **Priority**: High

#### L1-H-005 — `setAttribute` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:48`
- **Current**: `setAttribute(_ name:_ value:)`
- **Recommended**: `set(attribute name:_ value:)`
- **Impact**: All context conformers overriding the default
- **Priority**: High — see Decision D3

#### L1-H-006 — `addClassName` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:51`
- **Current**: `addClassName(_ name:)`
- **Recommended**: `add(className name:)`
- **Impact**: All context conformers overriding the default
- **Priority**: High

### Medium

#### L1-M-001 — `lineBreak` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:35`
- **Current**: `lineBreak()`
- **Recommended**: Defer — see Decision D2. `break` is a keyword; compound form mirrors CSS `line-break`.
- **Priority**: Medium — needs design discussion

#### L1-M-002 — `thematicBreak` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:36`
- **Current**: `thematicBreak()`
- **Recommended**: Same as L1-M-001
- **Priority**: Medium

#### L1-M-003 — `pageBreak` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:43`
- **Current**: `pageBreak()`
- **Recommended**: Same as L1-M-001
- **Priority**: Medium

#### L1-M-004 — `saveAttributes`/`restoreAttributes` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:54-57`
- **Current**: `saveAttributes()` / `restoreAttributes()`
- **Recommended**: `save(attributes:)` / `restore(attributes:)`
- **Impact**: Format-specific context conformers only
- **Priority**: Medium

#### L1-M-005 — `writeRawBytes` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:60`
- **Current**: `writeRawBytes(_ bytes:)`
- **Recommended**: `write(raw bytes:)` or `write(rawBytes bytes:)`
- **Impact**: Format-specific context conformers only
- **Priority**: Medium

#### L1-M-006 — `pushElement`/`popElement` compound methods with compound parameters
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:63-71`
- **Current**: `pushElement(tagName:isBlock:isVoid:isPreElement:)` / `popElement(isBlock:)`
- **Recommended**: `push(element tag:block:void:preformatted:)` / `pop(element block:)`
- **Impact**: Format-specific context conformers only
- **Priority**: Medium

#### L1-M-007 — `registerStyle` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:74-79`
- **Current**: `registerStyle(declaration:atRule:selector:pseudo:)`
- **Recommended**: `register(style declaration:atRule:selector:pseudo:)`
- **Impact**: Format-specific context conformers only
- **Priority**: Medium

#### L1-M-008 — `fontSize`/`fontWeight` compound properties on Rendering.Style
- **Rule**: [API-NAME-002]
- **File**: `Sources/Rendering Primitives Core/Rendering.Style.swift:4-5`
- **Current**: `fontSize: Float?` / `fontWeight: Weight?`
- **Recommended**: Introduce `Style.Font` sub-struct: `style.font.size` / `style.font.weight`. See Decision D4.
- **Impact**: All call sites constructing `Style` values
- **Priority**: Medium — design improvement

### Low

#### L1-L-001 — `Rendering._Tuple` underscore prefix
- **File**: `Sources/Rendering Primitives Core/Rendering._Tuple.swift:10`
- **Assessment**: Justified — signals builder-internal type. See Decision D6.
- **Priority**: No action

#### L1-L-002 — `Rendering.ForEach` compound name
- **File**: `Sources/Rendering Primitives Core/Rendering.ForEach.swift:7`
- **Assessment**: Justified — established SwiftUI convention.
- **Priority**: No action

#### L1-L-003 — `copy view` mechanism in Array/Optional _render
- **File**: `Sources/Rendering Primitives Core/Array+Rendering.swift:8-9`
- **Assessment**: Required by `borrowing` parameter + `for-in` ownership. Language limitation.
- **Priority**: No action

#### L1-L-004 — Builder design (variadic vs fixed-arity)
- **File**: `Sources/Rendering Primitives Core/Rendering.Builder.swift:14-41`
- **Assessment**: Correct — variadic `_Tuple` avoids 70+ element stack overflow. Matches documented design decision.
- **Priority**: No action

#### L1-L-005 — One type per file compliance
- **Assessment**: Fully compliant across all 18 files.
- **Priority**: No action

---

## L3: swift-html-rendering

**Location**: `/Users/coen/Developer/swift-foundations/swift-html-rendering/`

### Critical

#### HTML-C-001 — `asyncDocumentBytes`/`asyncDocumentString` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/HTML Renderable/HTML.Document.Protocol.swift:124-136`
- **Current**: `asyncDocumentBytes(...)` / `asyncDocumentString(...)`
- **Recommended**: Remove — the `init` overloads on `RangeReplaceableCollection` and `StringProtocol` already provide async variants (`await [UInt8](document)`, `await String(document)`). These are redundant compound-named convenience methods.
- **Impact**: Callers switch from `doc.asyncDocumentBytes()` to `await [UInt8](doc)` (already supported)
- **Priority**: Fix now

#### HTML-C-002 — `writeOpeningTag`/`writeClosingTag`/`escapeAttributeValue` compound internal methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/HTML Renderable/HTML.Context.swift:338,357,365`
- **Current**: `writeOpeningTag(_:)` / `writeClosingTag(_:)` / `escapeAttributeValue(_:)`
- **Recommended**: `write(openTag:)` / `write(closeTag:)` / `escape(attributeValue:)`
- **Impact**: Internal only — no downstream breakage
- **Priority**: Fix now

#### HTML-C-003 — `DocumentProtocol` compound type name
- **Rule**: [API-NAME-001]
- **File**: `Sources/HTML Renderable/HTML.Document.Protocol.swift:13`
- **Current**: `public protocol DocumentProtocol: HTML.View`
- **Recommended**: `HTML.Document.Protocol` — but `Document` is generic, so nested protocol may not be possible. Investigate Swift limitation.
- **Impact**: 7 file references
- **Priority**: Defer — investigate language limitation. If nesting is impossible, document the reason.

### High

#### HTML-H-001 — `isBlock`/`isVoid`/`isPreElement` compound boolean properties on Element
- **Rule**: [API-NAME-002]
- **File**: `Sources/HTML Renderable/HTML.Element.swift:23-34`
- **Current**: `tagName: String`, `isBlock: Bool`, `isVoid: Bool`, `isPreElement: Bool`
- **Recommended**: `tag: String` (or keep `tagName` per [API-NAME-003] — mirrors WHATWG DOM), `block: Bool`, `void: Bool`, `preformatted: Bool`
- **Impact**: Internal type, contained rename
- **Priority**: Fix now

#### HTML-H-002 — `tagName(forBlock:)`/`isVoidTag` compound static methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/HTML Renderable/HTML.Context.swift:389,405,415`
- **Current**: `tagName(forBlock:)` / `tagName(forInline:)` / `isVoidTag(_:)`
- **Recommended**: `tag(for:)` (overloaded on Block/Inline) / `isVoid(tag:)`
- **Impact**: Internal static methods
- **Priority**: Fix now

#### HTML-H-003 — `inputText`/`inputPassword`/... compound static properties on Selector
- **Rule**: [API-NAME-002]
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:488-515`
- **Current**: 21 compound `inputText`, `inputPassword`, `inputEmail`, etc.
- **Recommended**: Nest under `input` namespace: `HTML.Selector.input.text` instead of `HTML.Selector.inputText`
- **Impact**: Source-breaking for callers using the compound names
- **Priority**: Fix now

#### HTML-H-004 — `inlineStyle` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/HTML Renderable/HTML.Styled.swift:88`
- **Current**: `inlineStyle(_:)`
- **Recommended**: Defensible under [API-NAME-003] — mirrors CSS "inline style" spec terminology.
- **Priority**: Defer

#### HTML-H-005 — `pushBlock` reads as mechanism (whitespace management inlined)
- **Rule**: [IMPL-INTENT]
- **File**: `Sources/HTML Renderable/HTML.Context.swift:102-143`
- **Current**: `pushBlock` mixes whitespace emission, void element handling, and state saving in one method body
- **Recommended**: Extract whitespace emission helper (duplicated across 7 methods). See HTML-M-002.
- **Impact**: Internal refactoring, reduces 7-fold duplication
- **Priority**: Fix now

### Medium

#### HTML-M-001 — `isPrettyPrinting` local computed 10 times
- **Rule**: [IMPL-EXPR-001]
- **File**: `Sources/HTML Renderable/HTML.Context.swift:106` (and 9 other methods)
- **Current**: `let isPrettyPrinting = !configuration.newline.isEmpty` repeated in 10 methods
- **Recommended**: Add computed property: `var isPrettyPrinting: Bool { !configuration.newline.isEmpty }`
- **Priority**: Fix now — trivial

#### HTML-M-002 — Whitespace emission pattern duplicated 7 times
- **Rule**: [IMPL-INTENT]
- **File**: `Sources/HTML Renderable/HTML.Context.swift:109-114,193-198,225-232,...`
- **Current**: Identical 5-line whitespace block repeated in pushBlock, popBlock, pushList, pushItem, lineBreak, thematicBreak, image
- **Recommended**: Extract `emitLeadingWhitespace()` helper
- **Priority**: Fix now — DRY violation

#### HTML-M-003 through HTML-M-006 — L1 protocol compound names inherited at L3
- **Rule**: [API-NAME-002]
- **Files**: `Sources/HTML Renderable/HTML.Context.swift:435,443,454,459,463-467`
- **Current**: `addClassName`, `saveAttributes`, `restoreAttributes`, `writeRawBytes`, `pushElement`/`popElement`
- **Assessment**: These originate from `Rendering.Context` at L1. Cannot fix at L3.
- **Priority**: Defer to L1 — tracked as L1-H-005, L1-H-006, L1-M-004 through L1-M-007

#### HTML-M-007 — `Configuration.Error` misscoped
- **Rule**: [API-NAME-001]
- **File**: `Sources/HTML Renderable/HTML.Context.Configuration.swift:147`
- **Current**: `HTML.Context.Configuration.Error` — but the error represents a rendering failure, not a configuration failure
- **Recommended**: Move to `HTML.Context.Error`
- **Impact**: 2 call sites
- **Priority**: Fix now

#### HTML-M-008 — `important` spelled byte-by-byte
- **Rule**: [IMPL-INTENT]
- **File**: `Sources/HTML Renderable/HTML.Context.swift:629-641`
- **Current**: `.ascii.exclamationPoint, .ascii.i, .ascii.m, .ascii.p, ...` for "!important"
- **Recommended**: `Array("!important".utf8)`
- **Priority**: Fix now — trivial readability improvement

### Low

#### HTML-L-001 through HTML-L-003 — CSS spec-mirroring pseudo/selector names
- **Files**: `HTML.Pseudo.swift:313-395`, `HTML.Selector.swift:168,199`
- **Assessment**: `firstChild`, `lastChild`, `nthChild`, `nextSibling`, etc. mirror CSS pseudo-class names exactly. Defensible under [API-NAME-003].
- **Priority**: No action

#### HTML-L-004 — `withClass`/`withId`/`withAttribute` fluent methods
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:330-376`
- **Assessment**: `with*` is standard Swift fluent builder convention. Borderline.
- **Priority**: Defer

#### HTML-L-005 — `startsWithOrHyphen` parameter label
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:469`
- **Assessment**: Mirrors CSS `[attr|="value"]`. Low usage.
- **Priority**: Defer

#### HTML-L-006 — `currentIndentation` redundant prefix
- **File**: `Sources/HTML Renderable/HTML.Context.swift:43`
- **Current**: `currentIndentation`
- **Recommended**: `indentation` (mutable state is inherently "current")
- **Priority**: Defer — cosmetic

### Architectural Notes

- **HTML.View protocol**: Correctly refines `Rendering.View` with `Body: HTML.View` constraint.
- **Rendering.Context conformance**: All 15 semantic + 7 element methods implemented. WHATWG tag name mapping correct. Push/pop symmetry verified. No scope leakage bug (void elements skip state push).
- **Composition types**: Zero rendering logic duplication — all inherited from L1.
- **Two-phase document rendering**: Clear, well-documented.
- **_Attributes underscore prefix**: Justified (builder-internal).

---

## L3: swift-svg-rendering

**Location**: `/Users/coen/Developer/swift-foundations/swift-svg-rendering/`

### High

#### SVG-H-001 — `AnyView` compound type name
- **Rule**: [API-NAME-001]
- **File**: `Sources/SVG Rendering/SVG.AnyView.swift:10`
- **Current**: `public struct AnyView: SVG.View`
- **Recommended**: `SVG.View.Erased` — see Decision D5
- **Impact**: All call sites using `SVG.AnyView`
- **Priority**: Fix now

#### SVG-H-002 — `GeometryContext` file name implies compound type
- **Rule**: [API-NAME-001]
- **File**: `Sources/SVG Rendering/SVG.GeometryContext.swift`
- **Current**: File named `SVG.GeometryContext.swift` but defines no type — only adds `SVG.View` conformances to geometry `SVGContext` types
- **Recommended**: Rename file to `Geometry+SVG.View.swift`. The underlying `SVGContext` compound name is an L2 issue.
- **Impact**: File rename only
- **Priority**: Fix now

### Medium

#### SVG-M-001 through SVG-M-004 — 50+ compound attribute methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/SVG Rendering/SVG.Attributes.swift:31-586`
- **Current**: `strokeWidth`, `fillOpacity`, `strokeOpacity`, `strokeLinecap`, `strokeLinejoin`, `strokeDasharray`, `strokeDashoffset`, `fillRule`, `fontFamily`, `fontSize`, `fontWeight`, `fontStyle`, `textAnchor`, `dominantBaseline`, `textLength`, `lengthAdjust`, `gradientUnits`, `gradientTransform`, `spreadMethod`, `stopColor`, `stopOpacity`, `patternUnits`, `patternContentUnits`, `patternTransform`, `clipPathUnits`, `maskUnits`, `maskContentUnits`, `markerStart`, `markerMid`, `markerEnd`, `markerWidth`, `markerHeight`, `markerUnits`, `preserveAspectRatio`, `xlinkHref`, `pathLength`
- **Recommended**: Nested accessors: `.stroke.width(_:)`, `.fill.opacity(_:)`, `.font.family(_:)`, `.gradient.units(_:)`, `.marker.start(_:)`, etc.
- **Assessment**: All mirror CSS/SVG property names (kebab-case → camelCase). Defensible under [API-NAME-003]. But the volume (50+) makes this the largest single naming concern.
- **Priority**: Defer — design decision needed. If adopted, should be done holistically across all attribute methods.

#### SVG-M-005 — `currentIndentation` / `appendNewline` / `appendIndentation` compound names on Context
- **Rule**: [API-NAME-002]
- **File**: `Sources/SVG Rendering/SVG.Context.swift:20,49,74`
- **Current**: `currentIndentation`, `appendNewline(into:)`, `appendIndentation(into:)`
- **Recommended**: `indentation`; the append methods appear unused (dead code — see SVG-L-003)
- **Priority**: Defer

#### SVG-M-006 — `_render` parameter named `markup` instead of `svg`
- **Rule**: [IMPL-INTENT]
- **File**: `Sources/SVG Rendering/Never+SVG.swift:9`
- **Current**: `_ markup: Self` — all others use `_ svg: Self`
- **Recommended**: `_ svg: Self`
- **Priority**: Fix now — trivial

#### SVG-M-007 — Duplicate rendering logic in `callAsFunction` + `SVG.View.body`
- **Rule**: [IMPL-INTENT]
- **File**: `Sources/SVG Rendering/SVG.Elements.swift`
- **Current**: Every W3C SVG type has both `callAsFunction` and `SVG.View.body` with identical rendering logic (~250 lines duplicated across 25 conformances)
- **Recommended**: Have `body` delegate to `callAsFunction`: `var body: some SVG.View { self() }`
- **Impact**: ~250 lines removed, no behavior change
- **Priority**: Fix now — DRY violation

### Low

#### SVG-L-001 — `SVG.Element._render` mixes concerns (escape sequences, indentation, tag writing)
- **File**: `Sources/SVG Rendering/SVG.Element.swift:24-90`
- **Assessment**: 66 lines mixing concerns. Escape logic duplicated with `SVG.Text._render`.
- **Priority**: Defer

#### SVG-L-002 — `_Tuple` saves/restores attributes but `_Array` does not
- **File**: `Sources/SVG Rendering/SVG._Array.swift:9-17` vs `SVG._Tuple.swift:11-22`
- **Assessment**: Asymmetry — attributes set by one array element could leak to the next. Could be intentional (arrays are homogeneous) or a bug.
- **Priority**: Defer but investigate

#### SVG-L-003 — Dead code: `appendNewline`, `appendIndentation`, `indented()`, `outdented()` on Context
- **File**: `Sources/SVG Rendering/SVG.Context.swift:49-80`
- **Assessment**: Four public methods never called. `SVG.Element._render` manages indentation inline instead.
- **Priority**: Defer — remove or refactor

#### SVG-L-004 — Stale file headers reference `swift-svg-renderable`
- **Files**: 8 files with old module name in header comment
- **Priority**: Defer — cosmetic

#### SVG-L-005 — Inconsistent escape approach (string literals vs typed constants)
- **Files**: `SVG.Text.swift:44` vs `SVG.Element.swift:51`
- **Assessment**: Two different approaches to XML escaping. Should unify.
- **Priority**: Defer

### Architectural Notes

- **SVG.View standalone protocol**: Clean. No vestigial `Rendering.Protocol` or `@retroactive` references.
- **Buffer-based output**: Correct architectural choice for geometry-based rendering.
- **_Attributes underscore prefix**: Justified (same pattern as L1 and HTML).
- **Composition types**: All correct with `body: Never { fatalError() }` pattern.
- **Phase 3 cleanup**: Complete — no vestigial references found.

---

## L3: swift-pdf-rendering

**Location**: `/Users/coen/Developer/swift-foundations/swift-pdf-rendering/`

### Critical

#### PDF-C-001 — 28+ compound stored property names on PDF.Context
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:42-172`
- **Current**: `layoutBox`, `graphicsStack`, `fontRegistry`, `inlineRuns`, `listStack`, `pendingListMarker`, `preserveWhitespace`, `stackSpacing`, `measurementMode`, `horizontalSpacing`, `marginTop/Right/Bottom/Left`, `paddingTop/Right/Bottom/Left`, `explicitWidth/Height`, `lastElementX/Y`, `horizontalRowStartY`, `horizontalRowMaxY`, `scopeStack`, `currentLinkURL`, `textBlockOpen`, `currentTextFont/FontSize/Color/Position`, `initialLayoutBox`, `completedPages`, `currentPageBuilder/Annotations`, `pendingInternalLinks`
- **Recommended**: Decompose into nested namespaces:
  - `context.layout.box` / `context.layout.initial`
  - `context.box.margin.top` / `context.box.padding.left`
  - `context.inline.runs` / `context.list.stack`
  - `context.horizontal.spacing` / `context.horizontal.row.maxY`
  - `context.text.block.open` / `context.text.current.font`
  - `context.pagination.completed` / `context.pagination.current.builder`
- **Impact**: Massive — every call site across all Rendering files changes. Track as a design project.
- **Priority**: Defer — requires coordinated multi-file refactor

#### PDF-C-002 — `updateHorizontalRowMaxY` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:303`
- **Recommended**: Absorb into `horizontal` Property accessor or inline at 2 call sites
- **Priority**: Fix with PDF-C-001

#### PDF-C-003 — `nextListMarker` compound method
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:353`
- **Recommended**: `context.list.next.marker()`
- **Priority**: Fix with PDF-C-001

#### PDF-C-004 — `addLinkAnnotation`/`addPendingInternalLink` compound methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:407-444`
- **Recommended**: `context.annotation.add.link(rect:uri:)` / `context.annotation.add.pending(rect:targetId:)`
- **Priority**: Fix with PDF-C-001

#### PDF-C-005 — Scope captures only 4 fields; push operations can modify uncaptured state
- **Rule**: Architectural correctness
- **File**: `Sources/PDF Rendering/PDF.Context.Scope.swift:14-19`
- **Current**: Scope captures `style`, `llx`, `preserveWhitespace`, `currentLinkURL`
- **Missing**: `lastElementY` (spacing logic after `popBlock` may miscalculate), `stackSpacing` (VStack handles its own save/restore, but Scope doesn't — fragile under future changes)
- **Recommended**: Add `lastElementY` and `stackSpacing` to Scope
- **Impact**: Low effort, high safety value
- **Priority**: Fix now — see Decision D7

### High

#### PDF-H-001 — `setFillColor`/`setStrokeColor` compound internal methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:562-583`
- **Recommended**: Move to emit Property accessor methods: `emit.fill(_:)` / `emit.stroke(_:)`
- **Priority**: Fix with PDF-C-001

#### PDF-H-002 — `applyRenderingStyle` compound private method
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context+Rendering.swift:218`
- **Current**: `applyRenderingStyle(_:)`
- **Recommended**: `apply(_:)` — parameter type `Rendering.Style` is already descriptive
- **Priority**: Fix now — trivial

#### PDF-H-003 — `pdfColor` compound cross-domain property
- **Rule**: [API-NAME-002], [PATTERN-012]
- **File**: `Sources/PDF Rendering/PDF.Context+Rendering.swift:238-246`
- **Current**: `extension Rendering.Style.Color { var pdfColor: PDF.Color }`
- **Recommended**: Per [PATTERN-012], make it an initializer on the target type: `PDF.Color(color)`
- **Priority**: Fix now — trivial

#### PDF-H-004 — `isHorizontalLayout` compound boolean
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:298`
- **Recommended**: `isHorizontal` or `context.layout.isHorizontal`
- **Priority**: Fix with PDF-C-001

#### PDF-H-005 — `hasInlineRuns` compound boolean (possibly dead code)
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:322`
- **Assessment**: No call sites found. May be dead code.
- **Priority**: Investigate — remove if dead

#### PDF-H-006 — `runsWithSymbolSupport` compound static factory
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.Text.Run.swift:100`
- **Current**: `static func runsWithSymbolSupport(text:font:fontSize:...)`
- **Priority**: Defer — public API, needs downstream audit

#### PDF-H-007 — Property accessors use `get` instead of `_read`
- **Rule**: [IMPL-022]
- **Files**: `PDF.Context.Advance.swift:14-21`, `PDF.Context.Emit.swift:13-20`, `PDF.Context.Flush.swift:11-18`, `PDF.Context.Page.swift:13-20`
- **Current**: All four use `get` + `_modify` — no `_read`
- **Assessment**: For `@CoW` types with `Property<Tag, Base>` (not `.View`), `get` may be acceptable. Measure before changing.
- **Priority**: Defer — measure first

#### PDF-H-008 — `renderRuns`/`buildActualText` compound static methods
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:17,511`
- **Current**: `renderRuns(_:context:)` / `buildActualText(from:)`
- **Recommended**: `render(_:context:)` / `actualText(from:)`
- **Priority**: Fix now — trivial

### Medium

#### PDF-M-001 through PDF-M-004 — CSS-mirroring compound names on Style.Resolved
- **Files**: `PDF.Context.Style.swift:41-50`
- **Current**: `textMarkup`, `verticalOffset`, `textAlign`, `lineHeight`
- **Assessment**: All mirror CSS property names. Defensible under [API-NAME-003].
- **Priority**: Defer — spec-aligned

#### PDF-M-005 — Compound stored properties on Text.Run
- **File**: `Sources/PDF Rendering/PDF.Context.Text.Run.swift:26-36`
- **Current**: `textDecoration`, `verticalOffset`, `linkURL`, `internalLinkId`
- **Recommended**: `decoration`, `offset`, `link`, `anchor`
- **Priority**: Fix — moderate effort

#### PDF-M-006 — `PendingInternalLink` defined inside `PDF.Context.swift` (one type per file violation)
- **Rule**: [API-IMPL-005]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:182-195`
- **Recommended**: Extract to `PDF.Context.PendingInternalLink.swift`
- **Priority**: Fix now — trivial

#### PDF-M-007 — `BuilderRaw` leaked public typealias
- **Rule**: [API-NAME-001]
- **File**: `Sources/PDF Rendering/PDF.Builder.swift:8`
- **Current**: `public typealias BuilderRaw = Rendering.Builder`
- **Recommended**: Make `internal` or remove
- **Priority**: Fix now

#### PDF-M-008 — `LayoutRaw` leaked public typealias
- **Rule**: [API-NAME-001]
- **File**: `Sources/PDF Rendering/Rendering/PDF.Stack+PDF.View.swift:12`
- **Current**: `public typealias LayoutRaw = Layout`
- **Recommended**: Make `internal` or remove
- **Priority**: Fix now

#### PDF-M-009 — `resolveInternalLinks` compound static method
- **Rule**: [API-NAME-002]
- **File**: `Sources/PDF Rendering/PDF.Context.swift:493`
- **Current**: `resolveInternalLinks(pages:pendingLinks:namedDestinations:)`
- **Recommended**: `resolve(links:in:destinations:)`
- **Priority**: Defer — public API

### Low

#### PDF-L-001 — Performance-motivated intermediate variables in Run rendering loop
- **File**: `Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:44-53`
- **Assessment**: Justified by hot loop performance.
- **Priority**: No action

#### PDF-L-002 — File header says `File.swift` (auto-generated)
- **File**: `Sources/PDF Rendering/Rendering/Never+PDF.View.swift:1`
- **Priority**: Fix now — trivial

#### PDF-L-003 — `markedContentInfo(for:)` uses `unsafeBitCast` chain
- **File**: `Sources/PDF Rendering/PDF.Element.swift:82-155`
- **Assessment**: Reads as mechanism. But correct for value types with identical layout.
- **Priority**: Defer — design work needed for protocol-based alternative

#### PDF-L-004 — VStack/HStack are same generic type distinguished by axis
- **File**: `Sources/PDF Rendering/Rendering/PDF.Stack+PDF.View.swift:22-29`
- **Assessment**: Known pattern. Document.
- **Priority**: Defer

#### PDF-L-005 — File header comment mismatches filename
- **File**: `Sources/PDF Rendering/Rendering/PDF.Rectangle+PDF.View.swift:1`
- **Priority**: Fix now — trivial

### Architectural Notes

- **Rendering.Context conformance**: All 15 methods implemented. Heading sizes and spacing factors are reasonable CSS-like defaults.
- **Property.View accessors**: All four (`advance`, `emit`, `flush`, `page`) follow [IMPL-020] correctly with empty enum tag types, `get` + `_modify`.
- **Scope save/restore**: Correctly captures `style`, `llx`, `preserveWhitespace`, `currentLinkURL`. See PDF-C-005 for completeness concern.
- **Composition type duplication**: `Array+PDF.View.swift` partially duplicates vertical/horizontal layout logic from `_Tuple+PDF.View.swift`. Low priority — different iteration mechanisms (pack vs for-in).
- **Hardcoded values**: All reasonable CSS/PDF defaults. Could be extracted to a `PDF.Theme` type for configurability (feature request, not a bug).

---

## Cross-Package

### XP-C-001 — L1 protocol naming cascades to all conformers
- **Rule**: [API-NAME-002]
- **Assessment**: 13+ compound method names on `Rendering.Context` are inherited by HTML.Context and PDF.Context. This is the single highest-leverage fix: renaming at L1 fixes 2 packages simultaneously.
- **Recommendation**: Fix L1 first (L1-H-001 through L1-H-006, L1-M-004 through L1-M-007), then update conformers.

### Consistency Issues

#### XP-M-001 — Protocol Hierarchy Alignment

| Package | View Protocol | Refines Rendering.View? | Context Type | Implements Rendering.Context? |
|---------|--------------|------------------------|--------------|-------------------------------|
| L1 | `Rendering.View` | — (is the base) | `Rendering.Context` | — (is the base) |
| HTML | `HTML.View` | **Yes** | `HTML.Context` | **Yes** |
| SVG | `SVG.View` | **No** (standalone) | `SVG.Context` | **No** (buffer-based) |
| PDF | `PDF.View` | **No** (standalone) | `PDF.Context` | **Yes** |

**Assessment**: This is architecturally sound. `Rendering.View` trees render into `HTML.Context` and `PDF.Context` via the generic `_render<C: Rendering.Context>`. `PDF.View` exists for PDF-specific views (layout primitives) that don't make sense as `Rendering.View`. SVG is intentionally standalone (geometry-based, not document-based). The separation is clean.

**One clarification needed**: Can a `PDF.View` tree render through a `PDF.Context` that implements `Rendering.Context`? Or must PDF-specific views use a different rendering path? This should be documented.

#### XP-M-002 — Composition Type Conformance Matrix

| L1 Type | HTML.View? | SVG.View? | PDF.View? |
|---------|-----------|----------|----------|
| `Rendering._Tuple` | Yes | Yes | Yes |
| `Rendering.Conditional` | Yes | Yes | Yes |
| `Rendering.Pair` | No file found | No file found | Yes |
| `Rendering.Group` | Yes (typealias) | Yes (own type) | No file found |
| `Rendering.Empty` | Yes (typealias) | Yes (own type) | Yes |
| `Rendering.ForEach` | No file found | No file found | Yes |
| `Array` | Yes | Yes | Yes |
| `Optional` | Yes | Yes | Yes |
| `Never` | Yes | Yes | Yes |

**Assessment**: Gaps exist but may be intentional:
- `Pair` and `ForEach` only have PDF conformances — HTML and SVG may not need them if their builders don't produce these types.
- `Group` has no PDF conformance — PDF may handle grouping differently (via layout stacks).
- The gaps should be documented to distinguish intentional omissions from oversights.

#### XP-M-003 — State Management Symmetry

| Context | State Saved | Mechanism | Concern |
|---------|-------------|-----------|---------|
| HTML.Context | Tag name, block flag, pre flag, indentation | `stateStack: [SavedState]` | `saveAttributes`/`restoreAttributes` shares `stateStack` with empty-tag sentinel — cross-call confusion possible in theory |
| PDF.Context | style, llx, preserveWhitespace, currentLinkURL | `scopeStack: [Scope]` | Missing `lastElementY`, `stackSpacing` — see PDF-C-005 |
| SVG.Context | `attributes` | Per-element save/restore in `_Tuple` only | `_Array` doesn't save/restore — see SVG-L-002 |

**Assessment**: Each context uses a different state management approach. PDF's `Scope` is the most explicit but incomplete. HTML's shared stack is risky in theory. SVG's per-composition-type approach is inconsistent. Consider a unified pattern documentation.

### Builder Consistency

All three packages use `Rendering.Builder` via typealias:
- `HTML.Builder = Rendering.Builder` — confirmed
- `SVG.Builder = Rendering.Builder` — confirmed
- `PDF.Builder` — uses `BuilderRaw` typealias workaround (see PDF-M-007)

The builder handles empty, single, multiple, optional, conditional, and array cases uniformly across all packages.

### Entry Point Consistency

| Package | Sync Entry | Async Entry | Pattern |
|---------|-----------|-------------|---------|
| HTML | `String(html:)`, `[UInt8](html:)` | `await String(html:)`, `await [UInt8](html:)` | init on target type |
| SVG | `String(svg:)`, `[UInt8](svg:)` | `await String(svg:)`, `await [UInt8](svg:)` | init on target type |
| PDF | `PDF.Document.render()` → `[PDF.Page]` | — | method on source type |

**Assessment**: HTML and SVG use consistent init-on-target-type pattern. PDF necessarily differs because PDF rendering produces multi-page structured output, not a byte stream. The asymmetry is architecturally justified.

---

## Implementation Phases

### Phase 1: Quick Wins (0 risk, high readability)
Fix now, no design decisions needed:
- HTML-C-002: internal method renames (`writeOpeningTag` → `write(openTag:)`)
- HTML-H-001: Element boolean property renames (`isBlock` → `block`)
- HTML-H-002: static method renames (`tagName(forBlock:)` → `tag(for:)`)
- HTML-M-001: extract `isPrettyPrinting` computed property
- HTML-M-002: extract `emitLeadingWhitespace()` helper
- HTML-M-007: move `Configuration.Error` to `Context.Error`
- HTML-M-008: `"!important".utf8` instead of byte-by-byte
- PDF-H-002: `applyRenderingStyle` → `apply`
- PDF-H-003: `pdfColor` → `PDF.Color(color)` initializer
- PDF-H-008: `renderRuns` → `render`; `buildActualText` → `actualText`
- PDF-M-006: extract `PendingInternalLink` to own file
- PDF-M-007: make `BuilderRaw` internal
- PDF-M-008: make `LayoutRaw` internal
- PDF-L-002, PDF-L-005: fix file header comments
- SVG-H-002: rename `SVG.GeometryContext.swift` file
- SVG-M-006: `markup` → `svg` parameter name
- SVG-M-007: deduplicate `callAsFunction`/`body` (~250 lines)
- SVG-L-004: update stale file headers

### Phase 2: L1 Protocol Renames (Decision D1, D3 needed)
After architect approves push/pop and element method renames:
- L1-H-001 through L1-H-006: rename protocol methods
- L1-M-004 through L1-M-007: rename element/utility methods
- Update all conformers (HTML.Context, PDF.Context)

### Phase 3: Naming Cleanup (Decision D5 needed)
- SVG-H-001: `AnyView` → `SVG.View.Erased`
- HTML-C-001: remove redundant `asyncDocumentBytes`/`asyncDocumentString`
- HTML-H-003: restructure `Selector.inputText` family under `input` namespace
- PDF-M-005: simplify Text.Run property names
- PDF-C-005: expand Scope with `lastElementY`, `stackSpacing`

### Phase 4: Design Projects (Decisions D2, D4 needed)
Requires significant design work:
- PDF-C-001: decompose 28+ compound stored properties into nested namespaces
- L1-M-001 through L1-M-003: break method family (`lineBreak`/`thematicBreak`/`pageBreak`)
- L1-M-008: introduce `Style.Font` sub-struct
- SVG-M-001 through SVG-M-004: 50+ compound attribute methods → nested accessors

---

## Known Issues (Not Re-Audited)

Per the handoff prompt, these are already tracked and were not re-reported:
1. Stack overflow with 70+ element `_Tuple` types
2. PDF image rendering (alt text fallback only)
3. `Rendering.Style.Color` limited to 4 colors (intentional for L1)
4. SVG standalone architecture (intentional — geometry-based, not document-based)
