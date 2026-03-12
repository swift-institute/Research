# Line Box Unification

<!--
---
version: 1.0.0
last_updated: 2026-03-12
status: RECOMMENDATION
tier: 2
---
-->

## Context

Two independent implementations of line box geometry exist in the Swift Institute foundations layer:

1. **`PDF.HTML.LineBox`** in `swift-pdf-html-rendering` (`CSS.LineBox.swift`, line 49) — a stored-property struct with `height`, `baselineOffset`, `belowBaseline`, and `halfLeading`, constructed from font metrics + line height multiplier or explicit line height. All four fields are `let` stored properties computed once at `init`.

2. **`PDF.Context.Style.Resolved.Line`** in `swift-pdf-rendering` (`PDF.Context.Style.Resolved.swift`, line 46) — a computed-property wrapper over `Style.Resolved` that computes `height`, `halfLeading`, and `baselineOffset` on every access. Lacks `belowBaseline`.

Both perform the same half-leading calculation:

```
contentHeight = ascender - descender
halfLeading = max(0, (lineHeight - contentHeight) / 2)
baselineOffset = halfLeading + ascender
```

The duplication raises an architectural question: should this computation be unified into a canonical type, and if so, where in the five-layer architecture should it live?

### Trigger

This research was triggered by observing identical half-leading arithmetic duplicated across two rendering packages in the foundations layer, per [RES-017] Pattern Extraction.

### Scope

Ecosystem-wide: the question spans primitives (candidate packages), standards (font metrics source), and foundations (current consumers). This is a Tier 2 investigation because it affects cross-package type design but is reversible if the recommendation proves wrong.

## Question

Where should the canonical line box type live, and what should its API surface be?

### Specific Sub-Questions

1. Where should LineBox live?
2. If text-primitives: how is the semantic conflict with `Text.Line` (source text lines) resolved? What justifies the dependency?
3. If layout-primitives: what namespace? How is confusion with `Layout.Flow.Line` avoided?
4. If a new package: is a single type sufficient justification? What other types would belong?
5. Should `init` take raw heights (ascender/descender) or font metrics objects?
6. Should `descent` (née `belowBaseline`) be stored or computed?
7. What generic constraint? `BinaryFloatingPoint`? `FloatingPoint`?
8. How should `Style.Resolved.Line` migrate?
9. Is half-leading CSS-specific or universal typographic?
10. Are there other duplicated typographic computations to unify?

## Prior Art

### CSS 2.1 Section 10.8 — Line Height Calculations

The CSS 2.1 specification (W3C, Section 10.8) defines the half-leading model:

- The **content area** of an inline box is `ascender + |descender|` (the font's natural height).
- The **line-height** property specifies the desired total line box height.
- **Leading** is `lineHeight - contentHeight`.
- **Half-leading** is `leading / 2`, added symmetrically above and below the content area.
- The **inline box** height equals the line-height value.

This model was a deliberate invention for CSS, not inherited from traditional typography. Bert Bos (CSS1 co-author, 1995-1996) acknowledged that half-leading was not a traditional typographic concept — it was created to solve the problem that adding leading only below lines created uneven spacing when text boxes had backgrounds or borders.

### CSS Inline Layout Module Level 3

The modern CSS Inline Layout Module (W3C Working Draft, css-inline-3) extends the CSS 2.1 model with:

- Baseline alignment within line boxes
- `leading-trim` (now `text-box-trim`) to remove half-leading from the first/last line
- `text-box-edge` to control which font metrics define the content area
- Initial letter (drop-cap) geometry

The core half-leading arithmetic remains unchanged from CSS 2.1.

### Traditional Typography: Leading

In metal typesetting, **leading** (pronounced "ledding") refers to thin strips of lead inserted between lines of type. The extra space was added entirely below each line, not distributed symmetrically. The term comes from the physical lead strips, and the distance measured was baseline-to-baseline.

CSS's half-leading is therefore a **web-native concept**: it distributes the leading symmetrically above and below the content area. This is distinct from traditional leading (bottom-only) and also from baseline-to-baseline distance (which is what most design tools like InDesign and Figma call "leading").

### OpenType Specification: hhea / OS/2 Tables

OpenType fonts provide line spacing metrics in two tables:

| Table | Fields | Usage |
|-------|--------|-------|
| `hhea` | `ascender`, `descender`, `lineGap` | Apple platforms (CoreText) |
| `OS/2` | `sTypoAscender`, `sTypoDescender`, `sTypoLineGap` | Windows, web (with `USE_TYPO_METRICS` flag) |
| `OS/2` | `usWinAscent`, `usWinDescent` | Legacy Windows clipping |

The baseline-to-baseline distance is: `sTypoAscender - sTypoDescender + sTypoLineGap`.

The ISO 32000-2 (PDF) specification mirrors this structure in its font descriptor (Section 9.8, Table 121), using `Ascent`, `Descent`, `Leading`, and `CapHeight` fields — all in font design units (1/1000 em for Type 1 fonts).

### Rendering Engine Internals

**WebKit/Blink**: Both engines derive from a common ancestor. Blink's LayoutNG replaced the legacy layout engine but preserves the CSS 2.1 line box model. Internally, line boxes are represented as inline box fragments with ascent, descent, and leading values computed per the CSS specification.

**Gecko (Firefox)**: Uses `nsLineBox` internally, tracking ascent, descent, and leading as separate values. The half-leading computation follows CSS 2.1 precisely.

All three engines implement the same arithmetic — the CSS specification is authoritative and there is no meaningful divergence in how half-leading is calculated.

### SwiftUI

SwiftUI provides two distinct modifiers:

- **`lineSpacing(_:)`**: Extra space between the bottom of one line and the top of the next (inter-line gap). Default is 0.
- **`lineHeight(_:)`** (iOS 26+): Baseline-to-baseline distance. Accepts `AttributedString.LineHeight` with `.multiple(factor:)` and `.leading(increase:)` options.

SwiftUI does **not** expose a half-leading concept. It uses CoreText internally, which works with the `hhea` table metrics directly. SwiftUI's `lineSpacing` is closer to traditional leading (gap-only), while `lineHeight` is baseline-to-baseline.

### Typst (Rust)

Typst uses the `leading` parameter on `par()` to specify inter-line spacing (gap between bottom of one line and top of the next), defaulting to `0.65em`. This is traditional leading, not half-leading.

There is an active proposal (issue #4224) to deprecate `leading` in favor of `line-height` (baseline-to-baseline distance), aligning with InDesign and Figma conventions.

Typst does not implement CSS half-leading.

### Summary

| System | Model | Distribution |
|--------|-------|-------------|
| CSS 2.1 / CSS Inline 3 | Half-leading | Symmetric (above + below) |
| Traditional typography | Leading | Below only |
| OpenType fonts | Metrics-based | Platform-dependent |
| SwiftUI | Gap or baseline-to-baseline | Below only (lineSpacing) or baseline (lineHeight) |
| Typst | Gap (leading) or baseline | Below only |
| InDesign / Figma | Baseline-to-baseline | N/A (measured, not distributed) |

**Conclusion**: Half-leading is a CSS/web-specific concept, not a universal typographic primitive. However, the underlying **computation** (distributing extra space symmetrically around the content area) is a general geometric operation applicable whenever CSS-style text layout is being performed.

## Analysis

### Option A: Layout Primitives (`swift-layout-primitives`)

Place the type at `Layout.Line.Box` within the existing layout-primitives package.

**Namespace**: `Layout.Line.Box` (not `Layout.Flow.Line`, which already exists for flow layout line alignment configuration).

**Description**: The line box is fundamentally a layout concept — it determines how much vertical space a line of text occupies and where within that space the baseline sits. This aligns with layout-primitives' role as "compositional arrangement of content within space."

**Advantages**:
- Layout-primitives already depends on dimension-primitives and geometry-primitives (Tier 10), providing `Height`, `Width`, `Scale` types
- No new package needed
- `Layout.Line.Box` reads naturally: "a box for a line, within the layout domain"
- Layout-primitives already has `Layout.Flow.Line` (line configuration for flow layout), establishing precedent for line-related types
- Consumer packages already depend on layout-primitives

**Disadvantages**:
- `Layout.Line.Box` vs `Layout.Flow.Line` could cause confusion, though they serve very different purposes (geometry vs. alignment configuration)
- The type is parameterized by coordinate space via `Geometry<Scalar, Space>`, which layout-primitives supports via its `Layout<Scalar, Space>` parameterization — but the line box operates on concrete font metrics, not generic layout
- Requires the type to be generic over `Scalar`/`Space`, adding complexity for what is currently a concrete computation

### Option B: Text Primitives (`swift-text-primitives`)

Place the type at `Text.Line.Box` within the existing text-primitives package.

**Description**: The line box computes text-related geometry (baseline offset, ascender/descender relationships). `Text.Line` already exists as a namespace for line-oriented text types.

**Advantages**:
- `Text.Line.Box` reads naturally: "a box for a text line"
- `Text.Line` namespace already exists with `Text.Line.Number`, `Text.Line.Map`
- Semantic coherence: line boxes are about text layout

**Disadvantages**:
- **Semantic conflict**: `Text.Line` currently means "a line of source text" (byte offsets, line numbers, columns). A line box is about visual geometry, not source text structure. Placing both under `Text.Line` conflates two distinct domains
- **Dependency cost**: text-primitives (Tier 2) currently depends only on affine-primitives (Tier 0). Adding line box geometry would require adding dependencies on dimension-primitives (for `Scale`) and geometry-primitives (for `Height`), pulling text-primitives up to Tier 10 — a massive tier jump
- text-primitives is encoding-agnostic; line boxes are rendering-specific
- Current text-primitives consumers (parsers, compilers, LSP) have no use for visual line geometry

### Option C: New Package (`swift-typography-primitives`)

Create a new package dedicated to typographic computation types.

**Description**: A Tier 10+ package containing `Typography.Line.Box`, `Typography.Line.Height`, and potentially other typographic computation types.

**Advantages**:
- Clean semantic domain: typography is distinct from both text processing and generic layout
- No namespace pollution of existing packages
- Room for growth: could house `Typography.Baseline`, `Typography.ContentArea`, `Typography.Kerning`, etc.
- Follows [PRIM-NAME-003]: names describe mechanism, not origin

**Disadvantages**:
- **Single-type justification**: currently only one type (`Typography.Line.Box`) would live here. [MOD-008] says a concern SHOULD NOT be a separate target when "the file count is 1 and no other target depends on it specifically"
- Additional package in the primitives tier creates dependency management overhead
- The line box is currently used by exactly two foundation-layer packages — creating a primitives package for two consumers is premature
- Future typographic types (kerning, tracking, optical sizing) are speculative

### Option D: Leave Duplicated (Status Quo)

Keep both implementations as they are.

**Description**: Accept the duplication as justified by the different contexts: `CSS.LineBox` is CSS-specific with stored properties; `Style.Resolved.Line` is a computed-property accessor tied to style resolution.

**Advantages**:
- Zero migration cost
- Each implementation is optimized for its context (stored vs. computed)
- The CSS line box comment explicitly states "This is a CSS concept, not a PDF concept, so it belongs in the HTML-to-PDF rendering layer" — the original author considered placement
- Only ~25 lines of shared arithmetic

**Disadvantages**:
- Violates DRY across packages
- Bug fixes must be applied to both implementations
- `Style.Resolved.Line` lacks `belowBaseline` — a silent divergence that could cause bugs
- As more rendering backends are added (e.g., EPUB, terminal), the duplication would multiply

## Comparison

| Criterion | A: layout-primitives | B: text-primitives | C: typography-primitives | D: Status quo |
|-----------|---------------------|-------------------|------------------------|---------------|
| **Layer correctness** | Good — layout is the right semantic layer | Poor — text-primitives is about source text, not visual rendering | Good — typography is a coherent domain | N/A — stays in foundations |
| **Dependency cost** | None — consumers already depend on layout-primitives | Very high — Tier 2 jumps to Tier 10+ | Medium — new package dependency | None |
| **Naming clarity** | Good — `Layout.Line.Box` is clear; mild collision with `Layout.Flow.Line` | Poor — `Text.Line.Box` conflicts with source-text `Text.Line` | Best — `Typography.Line.Box` is unambiguous | N/A |
| **Semantic coherence** | Good — line boxes arrange content in space | Poor — conflates source text with visual geometry | Best — typography is the precise domain | Acceptable — each is contextualized |
| **Consumer ergonomics** | Best — both consumers already import layout-primitives | Poor — requires new dependency for pdf-rendering | Good — clear but adds import | Best — no change |
| **Future extensibility** | Moderate — layout-primitives could host `Layout.Line.Metrics` | Poor — wrong domain for growth | Best — natural home for typographic types | Poor — duplication multiplies |
| **Migration cost** | Low — rename + move, consumers already import the package | High — cascading dependency changes | Medium — new package, new dependency | None |
| **Reusability** | High — any layout system can use it | Low — text-primitives consumers don't need it | High — any typographic system can use it | Low — locked in foundations |

## Outcome

**Status**: RECOMMENDATION

### Recommended Location: Option A — `Layout.Line.Box` in layout-primitives

Layout-primitives is the recommended home for the canonical line box type for the following reasons:

1. **Semantic fit**: A line box determines the vertical space allocation for a line of content and the baseline position within that space. This is a spatial arrangement concern — exactly what layout-primitives provides.

2. **Zero dependency cost**: Both consumer packages (`swift-pdf-rendering` and `swift-pdf-html-rendering`) already depend on `Layout_Primitives`. No new package dependencies are introduced.

3. **Naming resolution**: `Layout.Line.Box` is distinct from `Layout.Flow.Line` (which controls line alignment within a flow layout). The `Box` suffix communicates that this is a geometric container, not a configuration object.

4. **Pragmatic**: Option C (typography-primitives) has better semantic purity but fails the [MOD-008] single-type justification test. If additional typographic computation types emerge in the future, a promotion from layout-primitives to a dedicated typography-primitives package would be straightforward.

### Recommended Type Design

```swift
extension Layout {
    /// Namespace for line-level layout types.
    ///
    /// Distinct from `Layout.Flow.Line` (flow layout line alignment).
    /// `Layout.Line` concerns the geometry of individual content lines.
    public enum Line {}
}

extension Layout.Line {
    /// Line box geometry following the half-leading model.
    ///
    /// Computes the vertical space allocation for a line of content
    /// given font metrics and a target line height. The half-leading
    /// model distributes extra space symmetrically above and below
    /// the content area (ascender + |descender|).
    ///
    /// ## Geometric Relationships
    ///
    /// ```
    /// ┌─────────────────────────┐ ← Line box top
    /// │     leading             │
    /// ├─────────────────────────┤ ← Ascender line
    /// │     ascender            │
    /// ├─────────────────────────┤ ← BASELINE
    /// │     |descender|         │
    /// ├─────────────────────────┤ ← Descender line
    /// │     leading             │
    /// └─────────────────────────┘ ← Line box bottom
    /// ```
    ///
    /// ## Formulas
    ///
    /// - `leading = max(0, (height - ascender - |descender|) / 2)`
    /// - `ascent = leading + ascender`
    /// - `descent = leading + |descender|`
    public struct Box: Sendable, Equatable {
        /// Total height of the line box.
        public let height: Height

        /// Distance from the top of the line box to the baseline.
        ///
        /// Equals: `leading + ascender`
        public let ascent: Height

        /// Distance from the baseline to the bottom of the line box.
        ///
        /// Equals: `leading + |descender|`
        public let descent: Height

        /// Half of the total leading, distributed symmetrically
        /// above and below the content area.
        ///
        /// `leading = max(0, (height - ascender - |descender|) / 2)`
        public let leading: Height
    }
}
```

### Design Decisions

**Q5: Should init take raw heights or font metrics?**

Raw heights (ascender as `Height`, descender as `Height`). The type should not depend on `ISO_32000.Font.Metrics` or any specific font metric structure — that would create an upward dependency from primitives to standards. The caller (in foundations) extracts ascender/descender from font metrics and passes them as typed `Height` values.

```swift
extension Layout.Line.Box {
    /// Create a line box from ascender, descender, and target height.
    ///
    /// - Parameters:
    ///   - ascender: Distance from baseline to top of tallest glyph (positive).
    ///   - descender: Distance from baseline to bottom of lowest glyph (positive magnitude).
    ///   - height: Target total line height.
    public init(
        ascender: Height,
        descender: Height,
        height: Height
    ) {
        let leading = Height.max(.zero, (height - ascender - descender) / 2)
        self.height = height
        self.leading = leading
        self.ascent = leading + ascender
        self.descent = leading + descender
    }
}
```

Note: The `descender` parameter is taken as a positive magnitude (absolute value). The current implementations handle the sign convention differently — `CSS.LineBox` negates the descender (`-descender`), while the formula uses `ascender - descender` where descender is already negative. The canonical type should accept positive magnitude to avoid sign confusion, matching [IMPL-INTENT]: the caller says "the descender extends 200 units below the baseline" rather than "the descender is -200."

Note: Per [IMPL-EXPR-001], the intermediate `contentHeight` is inlined — it was used once and its name merely restated `ascender + descender`. The `leading` intermediate is justified (multi-use: consumed three times).

**Q6: Should `descent` be stored or computed?**

Stored. All four properties (`height`, `ascent`, `descent`, `leading`) should be stored `let` properties computed once at `init`. This matches `CSS.LineBox`'s design and avoids the repeated computation of `Style.Resolved.Line` (which recomputes `halfLeading` and `ascender` on every access to `baselineOffset`). The struct is 4 `Height` values (32 bytes for `Double`-backed heights) — small enough that storage is cheaper than recomputation.

**Q7: What generic constraint?**

The type should use `Layout<Scalar, Space>.Line.Box` where `Height` is `Layout.Height` (which is `Geometry<Scalar, Space>.Height`). This inherits the generic parameterization from `Layout`, making it work with any scalar type and coordinate space. No explicit `BinaryFloatingPoint` or `FloatingPoint` constraint is needed beyond what `Height` already requires for the `max` and `/` operations used in the leading computation.

**Q8: How should `Style.Resolved.Line` migrate?**

In phases:

1. **Add `Layout.Line.Box`** to layout-primitives with the raw-height initializer.
2. **Add convenience initializer** in `swift-pdf-rendering` (or as an extension in foundations) that takes `PDF.Font.Metrics` and constructs a `Layout.Line.Box`. Per [IMPL-EXPR-001], the intermediates are inlined — each was single-use with no explanatory value beyond what the parameter labels provide:
   ```swift
   extension Layout.Line.Box where ... {
       init(metrics: PDF.Font.Metrics, fontSize: Size<1>, multiplier: Scale<1, Double>) {
           self.init(
               ascender: metrics.ascender(atSize: fontSize),
               descender: metrics.descender(atSize: fontSize).magnitude,
               height: fontSize.height * multiplier
           )
       }
   }
   ```
3. **Replace `Style.Resolved.Line`** with a computed property that returns `Layout.Line.Box`.
4. **Replace `CSS.LineBox`** with `Layout.Line.Box`, forwarding the font-metrics initializer.
5. **Update call sites** — property names change: `baselineOffset` → `ascent`, `belowBaseline` → `descent`, `halfLeading` → `leading`. The semantics are identical.

**Q9: Is half-leading CSS-specific or universal typographic?**

Half-leading is a CSS-specific concept (invented for CSS1 in 1996 by Hakon Lie and Bert Bos). However, the underlying geometric operation — distributing extra space symmetrically around a content area — is a general layout computation. The canonical type should document its CSS origins but not restrict itself to CSS terminology. Using standard typographic single-word terms (`ascent`, `descent`, `leading`) rather than CSS-specific compound names makes the type both broadly applicable and compliant with [API-NAME-002].

**Q10: Other duplicated typographic computations to unify?**

Examining the consumer files reveals additional candidates:

| Computation | Location(s) | Candidate for Unification |
|------------|-------------|--------------------------|
| Cap-height vertical centering | `Pair+PDF.View.swift` (lines 82-83), `HTML.Element.Tag+TableCell.swift` (line 79) | Yes — `(containerHeight + capHeight) / 2 - ascender` appears in both |
| x-height vertical centering | `PDF.Context.Text.Run+Rendering.swift` (line 460) | No — single occurrence |
| Text width measurement | Multiple files | No — already unified via `PDF.Font.Metrics.winAnsi.width(of:atSize:)` |

The cap-height centering formula is a secondary unification candidate but should be addressed in a separate research document after the line box unification is implemented.

### Naming Decision

Per [API-NAME-002], properties MUST NOT use compound names. The existing implementations use compound property names (`halfLeading`, `baselineOffset`, `belowBaseline`) that violate this rule.

**Type path**: `Layout.Line.Box` (within `Layout<Scalar, Space>`) — follows [API-NAME-001] Nest.Name pattern.

**Property names** — all single words, standard typographic terms:

| Property | Replaces | Rationale |
|----------|----------|-----------|
| `height` | `height` | Unchanged. In the `Line.Box` context, unambiguously the line height. |
| `ascent` | `baselineOffset` / `aboveBaseline` | Standard typographic term. The line box's ascent is the distance from top to baseline (= leading + ascender). Single word. Eliminates the ambiguity of `baselineOffset` (offset from what, in which direction?). |
| `descent` | `belowBaseline` | Standard typographic term. The line box's descent is the distance from baseline to bottom (= leading + \|descender\|). Single word. |
| `leading` | `halfLeading` | In the `Line.Box` context, "leading" unambiguously refers to the per-side half-leading — the box has no "full leading" property. The doc comment clarifies: "Half of the total leading, distributed symmetrically." Single word. |

**Init parameter names** — per [API-NAME-002]:

| Parameter | Replaces | Rationale |
|-----------|----------|-----------|
| `height:` | `lineHeight:` | The type IS `Line.Box`, so `height` unambiguously means the target line height. The `Line` context is already in the type name. |
| `multiplier:` | `lineHeightMultiplier:` | In a `Line.Box` convenience init, the multiplier can only be the line height multiplier. The compound prefix adds no information. |

**Expression style** — per [IMPL-EXPR-001]:

The init body inlines `contentHeight` (single-use intermediate whose name merely restated `ascender + descender`). The `leading` intermediate is retained (multi-use: consumed three times). The convenience init inlines all three intermediates into a single delegating `self.init(...)` expression — parameter labels provide the necessary context.

## References

- W3C, "CSS 2.1 Specification, Section 10.8 — Line height calculations," https://www.w3.org/TR/CSS2/visudet.html
- W3C, "CSS Inline Layout Module Level 3," https://www.w3.org/TR/css-inline-3/
- Microsoft, "OS/2 — OS/2 and Windows metrics table (OpenType 1.9.1)," https://learn.microsoft.com/en-us/typography/opentype/spec/os2
- SIL International, "Font Development Best Practices: Line Metrics," https://silnrsi.github.io/FDBP/en-US/Line_Metrics.html
- ISO 32000-2:2020, "Section 9.8 — Font descriptors"
- Typst, "Paragraph Function Documentation," https://typst.app/docs/reference/model/par/
- Typst, "Proposal: change `leading` option to `line-height`," https://github.com/typst/typst/issues/4224
- Apple, "lineSpacing(_:) | SwiftUI," https://developer.apple.com/documentation/swiftui/view/linespacing(_:)
- Ott, Matthias, "The Thing With Leading in CSS," https://matthiasott.com/notes/the-thing-with-leading-in-css
- Wikipedia, "Leading," https://en.wikipedia.org/wiki/Leading
- MDN, "Leading (Glossary)," https://developer.mozilla.org/en-US/docs/Glossary/Leading
- Wang, Ethan, "Leading-Trim: The Future of Digital Typesetting," https://medium.com/microsoft-design/leading-trim-the-future-of-digital-typesetting-d082d84b202
