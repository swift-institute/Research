# Rendering Stack Audit: Synthesis & Fix Plan

Date: 2026-03-13
Scope: /implementation + /naming skills
Packages: swift-rendering-primitives, swift-html-rendering, swift-pdf-rendering, swift-pdf-html-rendering, swift-pdf

## Aggregate Summary

| Package | Files | Violations | Critical | Impl |
|---------|-------|------------|----------|------|
| swift-rendering-primitives | 28 | 11 | 2 | 9 |
| swift-html-rendering | 324 | 37 | 26 | 11 |
| swift-pdf-rendering | 49 | 26 | 8 | 18 |
| swift-pdf-html-rendering | 106 | 34 | 18 | 16 |
| swift-pdf | 8 | 13 | 5 | 8 |
| **Total** | **515** | **121** | **59** | **62** |

Note: swift-pdf violations are all in test/experiment code (production source is a 7-line re-export). Swift-html-rendering's 26 critical violations are all [API-NAME-002] compound identifiers.

---

## Cross-Cutting Themes

### Theme 1: [API-NAME-002] Compound Identifiers (59 violations)

The single largest category. Organized by propagation order (root → leaf):

#### 1a. Rendering Primitives Protocol (root — cascades to all consumers)

| Current | Proposed | File |
|---------|----------|------|
| `lineBreak()` | Needs design — `break` is a keyword. Options: `insert.lineBreak()` via Property tag, or rename to `break(line:)` with label. | `Rendering.Context.swift:33` |
| `thematicBreak()` | Same pattern as lineBreak. | `Rendering.Context.swift:34` |
| `pageBreak()` | Same pattern as lineBreak. | `Rendering.Context.swift:36` |

**Design decision needed**: These are protocol requirements. Renaming cascades to every conformer (HTML.Context, PDF.Context, and any downstream contexts). The `break` keyword collision means we can't simply do `context.line.break()`. Options:

- **Option A**: `context.insert.lineBreak()` / `context.insert.thematicBreak()` / `context.insert.pageBreak()` — uses existing Property.View `Insert` tag pattern. Reads as intent: "insert a line break."
- **Option B**: `context.`break`.line()` with backtick escaping — legal Swift but poor ergonomics.
- **Option C**: Accept as principled compound name — CSS/HTML spec terminology *is* "line break," "thematic break," "page break." [API-NAME-003] spec-mirroring may justify the compound form.

**Recommendation**: Option C (accept with [API-NAME-003] justification). The terms are spec-defined CSS/HTML concepts, not compound verbs. Document the [API-NAME-003] exception.

#### 1b. HTML Renderable (26 violations)

Organized by sub-domain:

**HTML.Tag static members** (6 instances):
| Current | Proposed |
|---------|----------|
| `HTML.Tag.headOpen` | `HTML.Tag.head.open` |
| `HTML.Tag.headClose` | `HTML.Tag.head.close` |
| `HTML.Tag.bodyOpen` | `HTML.Tag.body.open` |
| ... | ... |

Requires a nested namespace per tag element on `HTML.Tag` — e.g., `HTML.Tag.Head` with `.open`/`.close` properties.

**HTML.Pseudo pseudo-classes** (12+ instances):
| Current | Proposed |
|---------|----------|
| `.firstChild` | `.first.child` |
| `.lastChild` | `.last.child` |
| `.nthChild("even")` | `.nth.child("even")` |
| `.firstOfType` | `.first.ofType` |
| `.readOnly` | `.read.only` |
| ... | ... |

Requires nested namespace types on `HTML.Pseudo` (e.g., `HTML.Pseudo.First` with `.child`, `.ofType` properties).

**HTML.Selector input types** (21 instances):
| Current | Proposed |
|---------|----------|
| `.inputText` | `.input.text` |
| `.inputPassword` | `.input.password` |
| ... | ... |

Requires `HTML.Selector.Input` namespace with per-type properties.

**HTML.Selector combinators** (6 instances):
| Current | Proposed |
|---------|----------|
| `.withClass("nav")` | `.with.class_("nav")` or restructure |
| `.withId("main")` | `.with.id("main")` |
| `.hasAttribute("disabled")` | `.has.attribute("disabled")` |
| `.nextSibling(of:)` | `.next.sibling(of:)` |
| `.subsequentSibling(of:)` | `.subsequent.sibling(of:)` |

**HTML.Context methods** (5 instances):
| Current | Proposed |
|---------|----------|
| `writeOpeningTag` | `write.opening(tag:)` |
| `writeClosingTag` | `write.closing(tag:)` |
| `escapeAttributeValue` | `escape.attribute(value:)` |
| `pushStyle` | `push.style(style)` |
| `asyncDocumentBytes` | `async.bytes(...)` |

**Other** (3 instances): `doubleQuotationMark`, `propertyName`, `stylesheetBytes`, `combinePseudo`.

#### 1c. PDF Rendering (5 violations)

| Current | Proposed | File |
|---------|----------|------|
| `addLinkAnnotation(rect:uri:)` | `annotation.link(rect:uri:)` | `PDF.Context.swift:407` |
| `addPendingInternalLink(rect:targetId:)` | `link.internal.add(rect:targetId:)` | `PDF.Context.swift:430` |
| `resolveInternalLinks(pages:...)` | `PDF.Context.Link.Internal.resolve(...)` | `PDF.Context.swift:493` |
| `updateHorizontalRowMaxY()` | `horizontal.row.updateMaxY()` | `PDF.Context.swift:303` |
| 30+ compound property names on PDF.Context | Many are stored properties — restructuring into sub-structs required | `PDF.Context.swift:56-149` |

The 30+ stored property violations on `PDF.Context` (e.g., `inlineRuns`, `listStack`, `pendingListMarker`, `marginTop`, `paddingLeft`, `currentTextFont`) are the hardest to fix because they're stored properties on a `@CoW` struct. Restructuring into sub-structs (e.g., `context.margin.top`, `context.text.font`, `context.list.stack`) requires careful @CoW integration.

#### 1d. PDF HTML Rendering (18 violations)

**Configuration properties** (12 instances):
| Current | Proposed |
|---------|----------|
| `paperSize` | `paper` (type conveys rectangle) |
| `documentTitle` | Group into `Document` sub-struct: `document.title` |
| `documentDate` | `document.date` |
| `defaultFont` | `font` (default is implied by Configuration context) |
| `defaultFontSize` | `fontSize` |
| `defaultColor` | `color` |
| `paragraphSpacing` | Group into `Paragraph` sub-struct: `paragraph.spacing` |
| `headingSpacing` | Group into `Heading` sub-struct: `heading.spacing` |
| `horizontalGapEm` | TBD — needs design |
| `deferredHeaderThreshold` | Group into `Header` sub-struct: `header.threshold` |

**Tag style methods** (6 instances):
| Current | Proposed |
|---------|----------|
| `applyTagStyle(_:context:)` | `apply(tag:context:)` |
| `blockMargins(for:configuration:)` | `margins(block:configuration:)` |
| `headingLevel(for:)` | `heading(level:)` |
| `isListContainer(_:)` | Restructure |
| `listType(for:)` | `list(type:)` |
| `headingSize(level:)` | `heading(size:)` |

---

### Theme 2: [API-NAME-004] Typealiases for Type Unification (8 violations)

| Package | Current | Action |
|---------|---------|--------|
| swift-pdf-rendering | `BuilderRaw = Rendering.Builder` | Remove, use `Rendering.Builder` directly |
| swift-pdf-rendering | `LayoutRaw = Layout` | Remove, use `Layout` directly |
| swift-pdf-rendering | `PDF.Layout = LayoutRaw<Double, UserSpace>` | Replace with direct `Layout<Double, UserSpace>` |
| swift-pdf-rendering | `PDF.Stack/VStack/HStack` all → same type | Remove VStack/HStack or make distinct types |
| swift-html-rendering | `HTML.Builder = Rendering.Builder` | **Borderline** — DSL ergonomics. Discuss. |
| swift-html-rendering | `HTML.Empty = Rendering.Empty` | Same as above |
| swift-html-rendering | `HTML.Group = Rendering.Group` | Same as above |
| swift-html-rendering | `HTML.AtRule.Media = HTML.AtRule` | Remove self-alias or make Media a distinct type |

**Decision needed**: The `HTML.Builder`, `HTML.Empty`, `HTML.Group` aliases serve DSL ergonomics — users write `@HTML.Builder` rather than `@Rendering.Builder`. This is a [PATTERN-024] specialization typealias (localizing a decision), not a unification bridge. I'd argue these are **acceptable**.

The `BuilderRaw`/`LayoutRaw` aliases in swift-pdf-rendering are pure unification bridges and should go.

---

### Theme 3: [IMPL-010] Raw Int at Domain Boundaries (14 violations)

Cross-cutting across all packages:

| Domain Value | Current Type | Proposed Type | Packages Affected |
|-------------|-------------|---------------|-------------------|
| Heading level | `Int` | `Rendering.Semantic.Block.Level` (bounded 1-6) | rendering-primitives, pdf-rendering, pdf-html-rendering |
| Page number | `Int` | `Index<PDF.Page>` or `PDF.Page.Number` | pdf-rendering, pdf-html-rendering |
| List start | `Int` | Accept as-is (unbounded domain) | rendering-primitives |
| Table row index | `Int` | `Table.Row.Index` or `Index<Table.Row>` | pdf-html-rendering |
| Table column index | `Int` | `Table.Column.Index` or `Index<Table.Column>` | pdf-html-rendering |
| Chunk size / yield interval | `Int` | Accept as-is (async infrastructure) | rendering-primitives |

**Recommended typed wrappers**:
1. **Heading level** — Define `Rendering.Semantic.Block.Level` (bounded 1-6) in rendering-primitives. Propagates to all consumers.
2. **Page number** — Define typed page index in pdf-rendering. Used by pdf-html-rendering.
3. **Table row/column** — Define typed indices in pdf-html-rendering (local scope).

---

### Theme 4: [IMPL-031] Manual Switch for Heading Levels (4 violations)

All in pdf-html-rendering. The heading level → size/margin mapping is repeated in 4 switches:

1. `headingSize(level:)` → switch 1-6 to font multiplier
2. `headingMarginEm(for:)` → switch h1-h6 to margin em
3. `headingLevel(for:)` → switch h1-h6 to Int
4. `applyTagStyle` → switch h1-h6 with per-level styling

**Fix**: Define heading configuration as a static array:
```swift
static let headingConfig: [(scale: Double, marginEm: Double)] = [
    (2.0, 0.67), (1.5, 0.83), (1.17, 1.0), (1.0, 1.33), (0.83, 1.67), (0.67, 2.33)
]
```
Parse level from tag name once (`"h\(n)"` → `n`), then index into the array. Eliminates all 4 switches.

If Theme 3's `Rendering.Semantic.Block.Level` is adopted, the level type itself can carry the config lookup.

---

### Theme 5: [IMPL-EXPR-001] Repeated Font Size Resolution (12 violations)

In pdf-html-rendering, 12+ CSS modifier files repeat:
```swift
let currentSize = context.style.fontSize ?? configuration.defaultFontSize
```

**Fix**: Add a single computed property:
```swift
extension PDF.HTML.Context {
    var resolvedFontSize: PDF.UserSpace.Size<1> {
        style.fontSize ?? configuration.defaultFontSize
    }
}
```
Or on the style itself:
```swift
extension PDF.Context.Style {
    func fontSize(default: PDF.UserSpace.Size<1>) -> PDF.UserSpace.Size<1> {
        self.fontSize ?? `default`
    }
}
```

---

### Theme 6: [API-IMPL-005] One Type Per File (5 violations)

| Package | File | Types | Action |
|---------|------|-------|--------|
| rendering-primitives | `Rendering.Style.swift` | Style, Font, Weight, Color | Split Font into own file; accept leaf enums |
| pdf-rendering | `Text.Run+Rendering.swift` | RenderState, WordDescriptor | Accept — private impl types |
| pdf-html-rendering | `Section.swift` | Section, ActiveHeading | Split ActiveHeading into own file |
| pdf-html-rendering | `Render.Result.swift` | Render, Result, helpers | Split into 3 files |
| html-rendering | `HTML.Context.swift` | HTML.important extension | Move to HTML.swift |

---

### Theme 7: [IMPL-INTENT] Mechanism Patterns (5 violations)

| Package | Issue | Severity | Action |
|---------|-------|----------|--------|
| pdf-html-rendering | Mirror-based optional unwrapping | HIGH | Replace with generic overloads or protocol dispatch |
| pdf-rendering | unsafeBitCast chain for tag dispatch | MEDIUM | Consider protocol-based dispatch |
| pdf-rendering | `try!` force unwrap | MEDIUM | Replace with guard + preconditionFailure |
| pdf-html-rendering | `@unchecked Sendable` on Deferred | LOW | Document or restructure |
| pdf-html-rendering | `@unchecked Sendable` on Recording.Command | LOW | Use concrete existential instead of Any |

---

## Proposed Fix Order

Fixes are ordered by propagation (root → leaf) and priority:

### Phase 1: Root Infrastructure (rendering-primitives)

1. **[API-NAME-002]** Decide on `lineBreak`/`thematicBreak`/`pageBreak` — either accept with [API-NAME-003] justification or redesign protocol. **This decision gates all downstream work.**
2. **[IMPL-010]** Introduce `Rendering.Semantic.Block.Level` typed wrapper for heading levels.
3. **[API-IMPL-005]** Split `Rendering.Style.Font` into own file.

### Phase 2: HTML Rendering (html-rendering)

4. **[API-NAME-002]** Introduce nested namespaces for:
   - `HTML.Tag` → `HTML.Tag.Head`, `HTML.Tag.Body`, `HTML.Tag.Style` with `.open`/`.close`
   - `HTML.Pseudo` → `HTML.Pseudo.First`, `.Last`, `.Only`, `.Nth`, `.Read`
   - `HTML.Selector` → `HTML.Selector.Input`, `.With`, `.Has`
5. **[API-NAME-002]** Rename methods on `HTML.Context`: `writeOpeningTag` → restructure, `pushStyle` → align with push.style() existing pattern.
6. **[API-NAME-004]** Remove `HTML.AtRule.Media` self-alias. Decide on `HTML.Builder`/`Empty`/`Group` aliases (recommend: keep with [PATTERN-024] justification).
7. **[API-IMPL-005]** Move `HTML.important` to correct file.
8. **[IMPL-040]** Restructure string-message Error type.

### Phase 3: PDF Rendering (pdf-rendering)

9. **[API-NAME-004]** Remove `BuilderRaw`, `LayoutRaw` aliases. Decide on VStack/HStack (distinct types or single name).
10. **[API-NAME-001]** Rename `PendingInternalLink` → nested type.
11. **[API-NAME-002]** Rename `addLinkAnnotation`, `addPendingInternalLink`, `resolveInternalLinks`, `updateHorizontalRowMaxY`.
12. **[IMPL-010]** Introduce typed page index.
13. **[IMPL-INTENT]** Replace `try!` with guard + preconditionFailure. Consider protocol dispatch for tag type checks.
14. **[API-NAME-002]** PDF.Context stored properties — this is the **largest single effort**. Requires sub-struct decomposition within @CoW.

### Phase 4: PDF HTML Rendering (pdf-html-rendering)

15. **[API-NAME-002]** Restructure Configuration properties into sub-structs (Document, Paragraph, Heading, Header).
16. **[API-NAME-002]** Rename tag style methods.
17. **[IMPL-031]** Replace heading switch statements with data-driven lookup.
18. **[IMPL-EXPR-001]** Add `resolvedFontSize` computed property. Update 12+ CSS modifier files.
19. **[API-IMPL-005]** Split Section.ActiveHeading and Render/Result files.
20. **[IMPL-INTENT]** Replace Mirror-based optional unwrapping with generic dispatch.
21. **[IMPL-010]** Introduce typed table row/column indices (local scope).

### Phase 5: PDF Umbrella (swift-pdf)

22. No production code fixes needed. Optionally clean up unused `import Foundation` in test files.

---

## Design Decisions Required Before Implementation

| # | Decision | Options | Impact |
|---|----------|---------|--------|
| D1 | lineBreak/thematicBreak/pageBreak naming | Accept as spec-mirroring vs redesign protocol | All packages |
| D2 | HTML.Builder/Empty/Group aliases | Keep (PATTERN-024) vs remove (strict API-NAME-004) | html-rendering, pdf-rendering |
| D3 | PDF VStack/HStack | Distinct types vs single Stack with axis parameter | pdf-rendering |
| D4 | PDF.Context stored property decomposition | Sub-structs vs accept | pdf-rendering (largest effort) |
| D5 | Heading level typed wrapper | New type in primitives vs accept Int | All packages |
| D6 | Page number typed wrapper | Index<PDF.Page> vs PDF.Page.Number vs accept Int | pdf-rendering, pdf-html-rendering |

---

## Individual Audit Reports

- [swift-rendering-primitives.md](swift-rendering-primitives.md)
- [swift-html-rendering.md](swift-html-rendering.md)
- [swift-pdf-rendering.md](swift-pdf-rendering.md)
- [swift-pdf-html-rendering.md](swift-pdf-html-rendering.md)
- [swift-pdf.md](swift-pdf.md)
