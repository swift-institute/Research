# CSS HTML Rendering + Markdown HTML Rendering Decomposition Feasibility

**Date**: 2026-03-22
**Triggered by**: Ecosystem-wide modularization audit (MOD-008)
**Status**: Complete — AnyView path removed, Diagnostic extraction blocked

---

## Executive Summary

**CSS HTML Rendering (512 files)**: Decomposition is structurally feasible but **not recommended**. The 510 property files are independent leaf extensions with zero inter-file dependencies — splitting them into sub-targets gains no semantic modularity, no consumer import granularity (consumers always want all properties), and no meaningful compile-time improvement. The upstream W3C CSS standards package *is* decomposed per spec (42 targets), which creates a structural argument for mirroring — but the rendering files are so trivially uniform (one-liner wrappers around `styled()`) that the target-boundary overhead exceeds the benefit. **Recommendation**: Document as exception. Extract Layout/ (4 files, structurally distinct) to its own target. Leave the 510 property files as-is.

**Markdown HTML Rendering (40 files, down from 59)**: The old AnyView rendering path (19 files) was removed — zero external consumers existed. Diagnostic extraction (4 files) was investigated but **blocked by circular dependency**: `Markdown` (the struct) is defined in the main target; Diagnostic extends it; the main target's `Configuration.Style` references `Diagnostic.Level`. Extraction would require a Core target solely to hold the `Markdown` namespace — overhead exceeds benefit at 40 files. **Result**: 40 files in one target, within acceptable range.

---

## 1. CSS HTML Rendering Analysis

### 1.1 Pattern Uniformity: Perfect

Every one of the 510 property files follows this exact pattern:

```swift
// BackgroundColor.swift (representative — all 510 identical in structure)
public import CSS_Standard
public import HTML_Rendering_Core

extension HTML.CSS {
    @discardableResult
    @_disfavoredOverload
    public func backgroundColor(
        _ backgroundColor: W3C_CSS_Backgrounds.BackgroundColor?
    ) -> HTML.CSS<HTML.Styled<Base, W3C_CSS_Backgrounds.BackgroundColor>> {
        styled(backgroundColor)
    }
}
```

Verified across 20+ files spanning W3C_CSS_Backgrounds, W3C_CSS_Text, W3C_CSS_UI, W3C_CSS_BoxModel, W3C_CSS_Flexbox, W3C_CSS_Grid, W3C_CSS_Animations, W3C_CSS_Alignment, W3C_CSS_Transforms, W3C_CSS_Color. **Zero exceptions found.** Every file:

1. Is a public extension on `HTML.CSS`
2. Defines exactly one method
3. Decorated with `@discardableResult` + `@_disfavoredOverload`
4. Takes a single nullable parameter of type `W3C_CSS_*.<PropertyName>?`
5. Returns `HTML.CSS<HTML.Styled<Base, W3C_CSS_*.<PropertyName>>>`
6. Body is a single call to `styled(propertyValue)`

No file defines a type (`struct`, `class`, `enum`). No file calls any other property method. No file has any cross-file dependency beyond the shared `HTML.CSS` type (defined externally in HTML Rendering Core).

### 1.2 Non-Property Files (8 files)

The target also contains 8 infrastructure files distinct from the 510 property extensions:

| File | Role | Lines | @inlinable |
|------|------|-------|-----------|
| `CSS.swift` | Main `CSS<Base>` struct, `styled()` method, `CSS.Builder` | 244 | Yes (14 annotations) |
| `CSS+ContextModifiers.swift` | `.media()`, `.dark()`, `.hover()`, etc. | ~200 | Yes (25 annotations) |
| `CSS.StringProperty.swift` | Helper for string-based inline styles | 50 | Yes (4 annotations) |
| `CSS.GlobalProperty.swift` | Generic wrapper for CSS global values | 40 | Yes (2 annotations) |
| `_HTML.swift` | `inlineStyle(_:_:)` overload for global properties | 43 | No |
| `exports.swift` | Re-exports `CSS_Standard`, `HTML_Rendering_Core`, `HTML_Rendering` | 9 | N/A |
| `CSS+color.swift` | Commented out (dead code) | 37 | N/A |
| `CSS+backgroundColor.swift` | Commented out (dead code) | 37 | N/A |

### 1.3 Layout/ Subdirectory (4 files)

The Layout/ files are structurally different from property extensions:

| File | Type Defined | CSS Properties Used | Lines |
|------|-------------|-------------------|-------|
| `HStack.swift` | `struct HStack<Content>` | alignItems, verticalAlign, display, flexDirection, maxHeight, columnGap | 37 |
| `VStack.swift` | `struct VStack<Content>` | alignItems, display, flexDirection, maxWidth, rowGap | 37 |
| `Spacer.swift` | `struct Spacer` | flexGrow | 20 |
| `LazyVGrid.swift` | `struct LazyVGrid<Content>`, `enum CSSSpace` | width, display, columnGap, rowGap + raw `grid-template-columns` | 88 |

These define **types** (not just extension methods), use **multiple** CSS properties from different W3C specs, and compose complex layouts. They are SwiftUI-style layout containers, semantically distinct from the property-rendering concern.

### 1.4 CSS Standard Structure: Monolithic Composition Layer

`swift-css-standard` is a thin composition layer with 2 files:
- `exports.swift` — re-exports `W3C_CSS` and `IEC_61966`
- `Color+sRGB.swift` — bridges W3C CSS colors with IEC 61966 sRGB

**However**, the upstream `swift-w3c-css` (in swift-standards) **is fully decomposed per specification**:
- **42 implementation targets** (W3C CSS Backgrounds, W3C CSS Text, W3C CSS Flexbox, W3C CSS Grid, etc.)
- **4 umbrella grouping targets** (Layout, Typography, Visual, Animation)
- **1 umbrella re-export target** (W3C CSS)
- Total: ~686 files across all targets

This means the L2 standards layer already has per-spec targets that the rendering layer *could* mirror. The structural symmetry argument exists.

### 1.5 Decomposition Options

#### Option A: Mirror W3C CSS structure (30 targets)

Split into one rendering target per W3C CSS specification:

```
CSS Backgrounds Rendering       (75 files)
CSS Text Rendering              (57 files)
CSS UI Rendering                (43 files)
CSS BoxModel Rendering          (38 files)
CSS Scroll Rendering            (37 files)
CSS Images Rendering            (31 files)
CSS Fonts Rendering             (27 files)
CSS Animations Rendering        (26 files)
CSS Masking Rendering           (23 files)
CSS Positioning Rendering       (23 files)
CSS Grid Rendering              (15 files)
CSS Multicolumn Rendering       (13 files)
CSS Alignment Rendering         (11 files)
CSS Color Rendering             (10 files)
CSS Containment Rendering       (10 files)
CSS Flexbox Rendering           (10 files)
CSS Shared Rendering            (10 files)
CSS Transforms Rendering        ( 9 files)
CSS Lists Rendering             ( 7 files)
CSS TextDecoration Rendering    ( 7 files)
CSS Logical Rendering           ( 6 files)
CSS Paged Rendering             ( 6 files)
CSS Transitions Rendering       ( 6 files)
CSS Visual Rendering            ( 6 files)
CSS MediaQueries Rendering      ( 5 files)
CSS Compositing Rendering       ( 2 files)
CSS Filters Rendering           ( 2 files)
CSS WritingModes Rendering      ( 2 files)
CSS Display Rendering           ( 1 file)
CSS Values Rendering            ( 1 file)
+ CSS HTML Rendering Core       ( 8 files: CSS.swift, helpers, exports)
+ CSS Layout                    ( 4 files: HStack, VStack, Spacer, LazyVGrid)
```

**Pros**:
- Mirrors upstream W3C CSS structure perfectly
- Each sub-target depends on exactly one W3C CSS spec target (different dependency set — MOD-008 criterion #1)
- Maximum build parallelism (32 independent compilations)

**Cons**:
- 32 targets for what is semantically a flat lookup table of one-liner wrappers
- 10 targets have ≤6 files; 2 targets have 1 file each
- Every consumer still wants all properties — no independent consumer value (violates MOD-008 criterion #2)
- Package.swift complexity: 32 target declarations, 32 product entries or umbrella re-exports
- 3 files reference two W3C modules (MediaQueries + another) — need to pick a home or duplicate

#### Option B: Grouped by category (6-8 targets)

Merge related specs into thematic groups matching W3C CSS umbrella targets:

```
CSS Layout Rendering            (~95 files: BoxModel, Flexbox, Grid, Positioning, Multicolumn, Alignment, Display)
CSS Typography Rendering        (~71 files: Text, Fonts, TextDecoration, WritingModes)
CSS Visual Rendering            (~141 files: Backgrounds, Images, Transforms, Filters, Masking, Compositing, Color)
CSS Animation Rendering         (~38 files: Animations, Transitions)
CSS Interaction Rendering       (~80 files: UI, Scroll, Containment)
CSS Misc Rendering              (~28 files: Shared, Logical, Paged, Lists, MediaQueries, Values, Visual)
CSS HTML Rendering Core         ( 8 files)
CSS Layout                      ( 4 files)
```

**Pros**:
- Fewer targets (8 vs. 32) — manageable Package.swift
- Groups have meaningful thematic coherence
- Mirrors W3C CSS umbrella groupings

**Cons**:
- Still no independent consumer value — who imports "CSS Typography Rendering" without "CSS Layout Rendering"?
- Grouping is subjective — different consumers might group differently
- 141 files in Visual group still violates the guideline

#### Option C: Accept as exception + extract Layout (recommended)

- Extract Layout/ (4 files) to "CSS Layout" target — justified by structural difference (defines types, composes multiple properties)
- Keep the 510 property files + 8 core files as a single target
- Document as a MOD-008 exception

**Pros**:
- Zero churn on 510 files that work correctly today
- Layout extraction is clean and justified (MOD-008 criterion #4: semantic independence)
- Honest about the nature of the target: it's a flat collection of leaf extensions, not a tangled monolith
- No @inlinable annotation burden
- Preserves WMO optimization scope (though marginal, since files are independent)

**Cons**:
- 514 files in one target remains an outlier in the ecosystem
- Doesn't mirror W3C CSS upstream structure

### 1.6 @inlinable Cost Assessment

**Current state**: The 510 property methods have **no** `@inlinable` annotations. Only the Core infrastructure (CSS.swift: 14, CSS+ContextModifiers.swift: 25, CSS.StringProperty.swift: 4, CSS.GlobalProperty.swift: 2) has them — 45 total across 5 files.

**If split into sub-targets**: Each of the 510 property methods would need `@inlinable` to preserve cross-target specialization. The annotation is mechanically trivial — every method body is a single `styled(value)` call with no closure captures, no complex generics beyond the existing `Base` parameter, and no local state. A script could add all 510 annotations.

**However**: The property methods are **not** `@inlinable` today, meaning consumers already cannot inline them across the package boundary. The `styled()` call IS `@inlinable`, but the property wrapper is not. Since these are one-liner wrappers around an already-inlinable method, the performance cost of the extra call frame is negligible. Adding `@inlinable` during a split would be an **improvement** over today, not a regression.

**Verdict**: @inlinable is not a blocking concern for any option. The annotation cost is mechanical and the performance impact is negligible either way.

### 1.7 Compile-Time Impact

Under WMO, the entire 512-file target compiles as one unit. However:

- Each property file is ~15 lines with no type definitions and a single generic method call
- The compiler's work per file is minimal: resolve one W3C CSS type, type-check one generic call to `styled()`
- There are no cross-file optimization opportunities (no file calls another)
- Splitting into N sub-targets enables N-way parallel compilation, but each sub-compilation is already tiny

Expected compile-time improvement from splitting: **minimal**. The bottleneck in CSS HTML Rendering compilation (if any) is the Core infrastructure, not the 510 leaf files.

### 1.8 Recommendation: Option C (Accept + Extract Layout)

**Rationale**: The 510 property files are a degenerate case for modularization analysis. MOD-008 asks whether concerns have different dependency sets, independent consumer value, or semantic independence. These 510 files have none of those properties relative to each other — they are a flat, uniform, dependency-free collection of leaf extensions. Splitting them into sub-targets creates target boundaries where none are needed: no consumer wants a subset, no file depends on another, and the compile-time cost is negligible.

The Layout/ files are the exception: they define types, compose multiple CSS properties, and represent a semantically distinct concern (SwiftUI-style layout containers vs. CSS property rendering). Extracting them satisfies MOD-008 criterion #4.

**Document the exception**: The CSS HTML Rendering target's 510-file count is a documented exception to the 20-25 file guideline. The justification: all 510 files are structurally identical leaf extensions with zero inter-file dependencies, zero shared state, and no type definitions. The target is effectively a registry, not a module with internal architecture. Standard modularization benefits (reduced coupling, independent testing, selective imports) do not apply to a flat collection of independent one-liner wrappers.

---

## 2. Markdown HTML Rendering Analysis

### 2.1 File Inventory

59 files in the main target, organized in four clusters:

**Configuration cluster (22 files)**:
- `Markdown.Configuration.swift` — root struct with `elements`, `directives`, `style`, `slugGenerator` fields
- `Markdown.Configuration.Element.swift` — `Elements` struct with 18 element renderer closures
- `Markdown.Configuration.Element.{Heading,Paragraph,CodeBlock,BlockQuote,Image,Link,Emphasis,Strong,Strikethrough,InlineCode,Text,LineBreak,SoftBreak,Table,List,ListItem,ThematicBreak}.swift` — 17 individual element configuration files
- `Markdown.Configuration.Style.swift` — diagnostic styling, blockquote styling, icons
- `Markdown.Configuration.Directive.swift` — custom directive handler (handles @Button, @Comment, @Video)
- `Markdown.Configuration.Slug.swift` — URL slug generation

**Rendering cluster (21 files)**:
- `Markdown.Rendering.swift` — root struct with 16 action-based element renderers
- `Markdown.Rendering.Converter.swift` — stack-safe MarkupVisitor producing `[Rendering.Action]`
- `Markdown.Rendering.{Heading,Paragraph,CodeBlock,BlockQuote,Image,Link,Emphasis,Strong,Strikethrough,InlineCode,Text,LineBreak,SoftBreak,Table,List,ListItem,ThematicBreak}.swift` — 17 element rendering files
- `Markdown.Rendering.Frame.swift` — prefix/suffix caching for HTML view trees
- `Markdown.Rendering.Replay.swift` — injects pre-built actions into view trees

**Diagnostic cluster (4 files)**:
- `Markdown.Diagnostic.swift` — root diagnostic struct
- `Markdown.Diagnostic.Level.swift` — severity levels (.error, .issue, .warning, etc.) with colors/icons
- `Markdown.Diagnostic.Icon.swift` — SVG icon constants
- `Markdown.Diagnostic.Inline.swift` — inline HTML view for diagnostics

**Utility/integration files (12 files)**:
- `Markdown.swift` — main entry point struct
- `Markdown.Converter.swift` — OLD AnyView-based converter (parallel to Rendering.Converter)
- `Markdown.Builder.swift` — result builder for markdown string construction
- `Rendering.Context+InterpretMarkdown.swift` — CSS registration during action interpretation
- `Rendering.Context+Capturing.swift` — factory for action capture
- `Rendering.Renderers.swift` — renderer registration
- `BlockQuote.Style.swift` — blockquote styling helper
- `LinkIcon.swift` — heading link SVG icon
- `PlainTextWalker.swift` — text extraction from markup
- `Slug.swift` — slug data structure
- `Timestamp.swift` — video timestamp view
- `exports.swift` — re-exports CSS, HTML, SwiftMarkdown

### 2.2 Cross-Cluster Dependency Map

```
Markdown (entry point)
  ├─ holds → Configuration (for slug, style, directives)
  ├─ holds → Rendering (for element rendering)
  └─ creates → Rendering.Converter(rendering:, configuration:)

Rendering.Converter (stack-safe)
  ├─ reads → Configuration.slugGenerator.generate(...)
  ├─ reads → Configuration.style.diagnostic.level(...)
  ├─ reads → Configuration.directives.handler(...)
  ├─ calls → Rendering.*.render(input) for each element
  └─ creates → Rendering.Frame, Rendering.Replay

Configuration.Style
  ├─ references → Markdown.Diagnostic.Level (in DiagnosticStyle)
  └─ references → Markdown.Diagnostic.Icon (in Icons)

Rendering.BlockQuote
  ├─ references → Markdown.Diagnostic.Level (in Input struct)
  └─ creates → Markdown.Diagnostic(level:) (in default renderer)

Diagnostic (LEAF — no outward references)
  ├─ Level — severity constants, colors, icon assignments
  ├─ Icon — SVG constants
  └─ Inline — HTML view composing icon + message
```

**Key findings**:
1. **Diagnostic is a clean leaf dependency.** Referenced by both Configuration.Style and Rendering.BlockQuote. Never references back. This is textbook MOD-008 criterion #3 (depended-on by siblings).
2. **Configuration → Rendering has NO direct references.** Configuration.Elements defines closures returning `HTML.AnyView` (old path). Rendering defines closures returning `[Rendering.Action]` (new path). These are parallel, non-intersecting architectures.
3. **Rendering.Converter reads Configuration** (slug, style, directives). This is a one-directional dependency: Converter needs Configuration, but Configuration doesn't know about Converter.
4. **No circular dependencies exist.** All references flow downward: Entry → Converter → {Configuration, Rendering} → Diagnostic.

### 2.3 Two Parallel Rendering Architectures

The package contains two complete rendering pipelines:

| | Old Path (AnyView) | New Path (Action) |
|--|---|---|
| **Converter** | `Markdown.Converter` | `Markdown.Rendering.Converter` |
| **Element renderers** | `Configuration.Elements.*` (→ `HTML.AnyView`) | `Rendering.*` (→ `[Rendering.Action]`) |
| **Stack safety** | Recursive (can overflow on deep nesting) | Flat action array (O(1) stack) |
| **Entry point** | Unclear — `Markdown.swift` delegates to `Rendering.Converter` | `Markdown.swift` line 61-65 |

The old `Markdown.Converter` (AnyView-based) appears to be the legacy path. `Markdown.swift` uses `Rendering.Converter` as its implementation. If the old converter is deprecated, its removal would reduce file count by 1 and simplify the architecture (the 18 Configuration.Element files serve the old path).

### 2.4 Core Extraction Feasibility

**Candidate "Markdown HTML Rendering Core" target**:
- `Markdown.swift` (entry point)
- `Markdown.Builder.swift` (result builder)
- `exports.swift` (re-exports)
- `Rendering.Context+InterpretMarkdown.swift` (context integration)
- `Rendering.Context+Capturing.swift` (factory)

**Problem**: This core would be 5 files. The remaining 54 files don't get meaningfully smaller sub-targets without splitting Configuration from Rendering — which fails MOD-008 criterion #2 (no independent consumer value; they always co-occur).

**Verdict**: Core extraction adds a target boundary without clear benefit. The core files are small, and no sibling target within the package would import Core independently.

### 2.5 Diagnostic Extraction Feasibility

**Candidate "Markdown HTML Rendering Diagnostic" target** (4 files):
- `Markdown.Diagnostic.swift`
- `Markdown.Diagnostic.Level.swift`
- `Markdown.Diagnostic.Icon.swift`
- `Markdown.Diagnostic.Inline.swift`

**MOD-008 assessment**:

| Criterion | Met? | Rationale |
|-----------|------|-----------|
| Different dependency set | Partial | Diagnostic only needs HTML Rendering Core (for the Inline view). Main target needs CSS, swift-markdown, OrderedCollections. |
| Independent consumer value | Weak | Diagnostic could theoretically be used standalone for status indicators, but this is speculative. |
| Depended-on by siblings | **Yes** | Both Configuration.Style and Rendering.BlockQuote reference Diagnostic.Level and Diagnostic.Icon. |
| Semantic independence | **Yes** | Diagnostic answers "how to render severity indicators" — clearly distinct from "how to render markdown elements." |

**@inlinable impact**: `Markdown.Diagnostic.Level` has static constants (`.error`, `.warning`, etc.) and color properties. These are value lookups, not hot-path generic code. @inlinable annotation is minimal (~5 properties) and straightforward.

**Verdict**: Diagnostic extraction is clean, justified by MOD-008 criteria #3 and #4, and has negligible @inlinable cost.

### 2.6 Full Configuration/Rendering Split Feasibility

A three-way split (Diagnostic + Configuration + Rendering):

```
Markdown HTML Rendering Diagnostic  ( 4 files)  — leaf
Markdown HTML Rendering Config      (22 files)  — depends on Diagnostic
Markdown HTML Rendering             (33 files)  — depends on Config, Diagnostic
```

**MOD-008 assessment for Config separation**:

| Criterion | Met? | Rationale |
|-----------|------|-----------|
| Different dependency set | No | Configuration needs the same dependencies as Rendering (HTML views, CSS types). |
| Independent consumer value | **No** | No consumer imports Configuration without also importing the rendering engine. |
| Depended-on by siblings | Yes | Rendering.Converter reads Configuration. |
| Semantic independence | Partial | Configuration defines "what" to render; Rendering defines "how." But they co-evolve: adding a new markdown element requires changes to both. |

The Configuration/Rendering split fails MOD-008 criterion #2 decisively. These clusters always co-occur. The split would create a target boundary solely for structural aesthetics, with the @inlinable cost of annotating Configuration's closure-heavy API surface (18 element renderers with generic initializers).

### 2.7 Recommendation: Extract Diagnostic Only

**Target structure after change**:

```
Markdown HTML Rendering Diagnostic  ( 4 files)  — new target
Markdown HTML Rendering             (55 files)  — depends on Diagnostic (+ existing deps)
Markdown Previews                   ( 2 files)  — unchanged
Markdown HTML Rendering Test Support( 1 file)   — unchanged
SwiftMarkdown                       ( 1 file)   — unchanged
```

55 files in the main target is above the 20-25 guideline but below the 40-file concern threshold. The files have clear internal clustering (Configuration: 22, Rendering: 21, Utilities: 12) but the clusters always co-occur and lack independent consumer value. Document as borderline-acceptable.

**Future consideration**: If the old AnyView-based rendering path (Markdown.Converter + Configuration.Elements.*) is deprecated and removed, the main target drops to ~36 files (Rendering: 21 + Utilities: 12 + Configuration root types: 3). This would bring it within comfortable range without needing further splits.

---

## 3. Implementation Effort Estimate

### CSS HTML Rendering: Layout Extraction

| Task | Effort |
|------|--------|
| Create "CSS Layout" target in Package.swift | Small |
| Move 4 Layout/ files to new Sources directory | Small |
| Add dependency from Layout → CSS HTML Rendering (for property methods) | Small |
| Update umbrella product to include both targets | Small |
| Verify tests pass | Small |
| **Total** | **~30 minutes** |

### Markdown HTML Rendering: Diagnostic Extraction

| Task | Effort |
|------|--------|
| Create "Markdown HTML Rendering Diagnostic" target in Package.swift | Small |
| Move 4 Diagnostic files to new Sources directory | Small |
| Add @inlinable to ~5 Diagnostic.Level properties | Small |
| Add dependency from main target → Diagnostic | Small |
| Update exports.swift to re-export Diagnostic module | Small |
| Verify tests pass | Small |
| **Total** | **~30 minutes** |

### NOT recommended: Full CSS HTML Rendering decomposition

| Task | Effort |
|------|--------|
| Create 30+ targets in Package.swift | Large |
| Create 30+ Sources directories | Large |
| Move 510 files to correct directories | Medium (scriptable) |
| Add @inlinable to 510 property methods | Medium (scriptable) |
| Create umbrella re-export target | Medium |
| Resolve 3 files referencing two W3C modules | Small |
| Update all consumers (if import paths change) | Unknown |
| **Total** | **Half a day to a day, mostly scriptable but high churn** |

---

## 4. MOD-008 Exception Documentation

### Exception: CSS HTML Rendering (510 property files)

**Rule**: MOD-008 recommends targets stay under 20-25 files.

**Exception**: The "CSS HTML Rendering" target contains 510 property extension files in a single target (514 total with core infrastructure).

**Justification**: The 510 property files are a degenerate case for modularization. Every file is structurally identical: a single extension method on `HTML.CSS` that delegates to `styled()`. There are:
- Zero inter-file dependencies
- Zero type definitions
- Zero shared state
- Zero cross-file optimization opportunities
- No independent consumer value for any subset (all properties are always wanted together)

The target is semantically a **registry** (flat lookup table of CSS property → rendering method), not a **module** (interconnected types with internal architecture). Standard modularization benefits — reduced coupling, independent testing, selective imports, incremental compilation — do not apply to a flat collection of independent one-liner wrappers.

The upstream W3C CSS standards package is decomposed per specification, and the rendering files map cleanly to those specifications. If the ecosystem ever needs per-spec rendering imports (e.g., a consumer that only renders CSS Grid properties), the decomposition axis is well-defined and scriptable. Until that need arises, the current structure is correct.

---

## 5. References

### CSS HTML Rendering
- Package.swift: `/Users/coen/Developer/swift-foundations/swift-css-html-rendering/Package.swift`
- Core infrastructure: `Sources/CSS HTML Rendering/CSS.swift` (lines 183-185: `styled()` method)
- Context modifiers: `Sources/CSS HTML Rendering/CSS+ContextModifiers.swift`
- Layout files: `Sources/CSS HTML Rendering/Layout/{HStack,VStack,Spacer,LazyVGrid}.swift`
- Shared helper: `Sources/CSS HTML Rendering/_HTML.swift`
- Exports: `Sources/CSS HTML Rendering/exports.swift`
- Representative property files: `BackgroundColor.swift`, `Width.swift`, `TextWrap.swift`, `FlexBasis.swift`, `GridAutoFlow.swift`, `AnimationDelay.swift`, `AlignItems.swift`, `ColorScheme.swift`, `TransformOrigin.swift`

### CSS Standard / W3C CSS
- CSS Standard: `/Users/coen/Developer/swift-standards/swift-css-standard/Package.swift` (2 files, composition layer)
- W3C CSS: `/Users/coen/Developer/swift-w3c/swift-w3c-css/Package.swift` (42 targets, decomposed per spec)

### Markdown HTML Rendering
- Package.swift: `/Users/coen/Developer/swift-foundations/swift-markdown-html-rendering/Package.swift`
- Entry point: `Sources/Markdown HTML Rendering/Markdown.swift`
- Old converter: `Sources/Markdown HTML Rendering/Markdown.Converter.swift`
- New converter: `Sources/Markdown HTML Rendering/Markdown.Rendering.Converter.swift`
- Configuration root: `Sources/Markdown HTML Rendering/Markdown.Configuration.swift`
- Rendering root: `Sources/Markdown HTML Rendering/Markdown.Rendering.swift`
- Diagnostic root: `Sources/Markdown HTML Rendering/Markdown.Diagnostic.swift`
- Exports: `Sources/Markdown HTML Rendering/exports.swift`

### Governing Rules
- Modularization skill: `/Users/coen/Developer/swift-institute/Skills/modularization/SKILL.md`
- MOD-008: Split Decision Criteria (lines 296-323)
- MOD-EXCEPT-001: Platform Packages exception (lines 560-570)
