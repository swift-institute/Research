# LineBox Unification Research — Agent Handoff Prompt

## Objective

Execute the `/research-process` skill to produce a Tier 2 research document analyzing where and how to unify the duplicated line box (half-leading) computation that currently exists in two Layer 3 packages. The research must evaluate placement in `text-primitives`, `layout-primitives`, a new package, or leaving the duplication in place. The output is a single research document written to `/Users/coen/Developer/swift-institute/Research/line-box-unification.md`.

**You are doing RESEARCH ONLY. Do NOT write implementation code. Do NOT modify any source files. Your sole deliverable is the research document.**

---

## Skills to Load

Before starting, you MUST read these skill files (they are the canonical source for all requirement IDs):

1. **research-process**: `/Users/coen/Developer/.claude/skills/research-process` — governs research document format, tiers, methodology
2. **naming**: `/Users/coen/Developer/.claude/skills/naming` — [API-NAME-001] through [API-NAME-004]
3. **implementation**: `/Users/coen/Developer/.claude/skills/implementation` — [IMPL-INTENT], [IMPL-000] through [IMPL-053], [PATTERN-009] through [PATTERN-022]
4. **code-organization**: `/Users/coen/Developer/.claude/skills/code-organization` — [API-IMPL-005] one type per file
5. **primitives**: `/Users/coen/Developer/.claude/skills/primitives` — [PRIM-*] primitives conventions, including [PRIM-FOUND-001] no Foundation
6. **swift-institute**: `/Users/coen/Developer/.claude/skills/swift-institute` — [ARCH-LAYER-*] five-layer architecture
7. **modularization**: `/Users/coen/Developer/.claude/skills/modularization` — [MOD-*] intra-package target structure

Read ALL of these before writing anything. They contain the rules that govern every design decision.

---

## Research Tier

**Tier 2: Standard**. This is a cross-package type placement decision that affects the primitives layer. It is reversible but has medium cost of error — wrong placement creates dependency problems or naming conflicts across multiple packages.

Per [RES-020], Tier 2 requires:
- All mandatory sections (Context, Question, Analysis, Outcome, References)
- Prior Art Survey [RES-021]
- Comparison table
- Clear recommendation with rationale

---

## Background: What You Need to Know

### The Five-Layer Architecture

```
Layer 5: Applications    (Commercial)   - End-user products
              |
Layer 4: Components      (Flexible)     - Opinionated assemblies
              |
Layer 3: Foundations     (Apache 2.0)   - Composed building blocks
              |
Layer 2: Standards       (Apache 2.0)   - Specification implementations
              |
Layer 1: Primitives      (Apache 2.0)   - Atomic building blocks
```

Packages MUST depend only on layers below them. Upward and lateral dependencies are forbidden within the same layer (foundations cannot depend on other foundations that are at the same level — they can share primitives dependencies).

### Package Locations

| Package | Path | Layer |
|---------|------|-------|
| swift-primitives (monorepo) | `/Users/coen/Developer/swift-primitives/` | 1 |
| swift-standards (monorepo) | `/Users/coen/Developer/swift-standards/` | 2 |
| swift-foundations (monorepo) | `/Users/coen/Developer/swift-foundations/` | 3 |
| swift-institute | `/Users/coen/Developer/swift-institute/` | Docs |

### The Duplication

Two independent implementations of the CSS half-leading model exist in Layer 3:

**Implementation A: `PDF.HTML.LineBox`** in swift-pdf-html-rendering (Layer 3)

```
File: /Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/CSS/CSS.LineBox.swift
```

- Stored struct with 4 properties: `height`, `baselineOffset`, `belowBaseline`, `halfLeading`
- Two initializers: one with `lineHeightMultiplier: Scale<1, Double>`, one with explicit `lineHeight: PDF.UserSpace.Height`
- Takes `PDF.Font.Metrics`, `PDF.UserSpace.Size<1>` (fontSize), and the multiplier/height
- Comment says: "This is a CSS concept (CSS 2.1 Section 10.8), not a PDF concept"
- Nested under `PDF.HTML` namespace

**Implementation B: `PDF.Context.Style.Resolved.Line`** in swift-pdf-rendering (Layer 3)

```
File: /Users/coen/Developer/swift-foundations/swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.Style.Resolved.swift
```

- Computed property on `Style.Resolved` — recomputes each access
- Has 3 properties: `height`, `halfLeading`, `baselineOffset` (missing `belowBaseline`)
- Derives all values from `Style.Resolved`'s font, fontSize, and lineHeight
- Calls `style.font.metrics.ascender(atSize:)` / `descender(atSize:)` internally

**The formulas are identical:**

```
contentHeight = ascender - descender     (descender is negative, so this adds magnitudes)
halfLeading   = max(0, (lineHeight - contentHeight) / 2)
height        = lineHeight               (or fontSize * multiplier)
baselineOffset = halfLeading + ascender
belowBaseline  = halfLeading + |descender|
```

### Dependency Direction

```
swift-pdf-html-rendering (Layer 3)
        |
        v
swift-pdf-rendering (Layer 3)
        |
        v
swift-pdf-standard (Layer 3)
        |
        v
swift-iso-32000 (Layer 2)
        |
        v
swift-geometry-primitives, swift-dimension-primitives, etc. (Layer 1)
```

- pdf-html-rendering depends on pdf-rendering (can use its types)
- pdf-rendering CANNOT depend on pdf-html-rendering
- Both depend on Layer 1 primitives

---

## Candidate Packages for Placement

### Candidate 1: `swift-text-primitives` (Layer 1)

**Location**: `/Users/coen/Developer/swift-primitives/swift-text-primitives/`
**Module**: `Text_Primitives`

**Current contents:**
- `Text` — enum namespace
- `Text.Line` — enum namespace for line-oriented types
- `Text.Line.Number` — 1-based line number (struct, backed by UInt)
- `Text.Line.Column` — typealias for `Text.Count` (UTF-8 byte offset within a line)
- `Text.Line.Map` — sorted array of line-start byte offsets, O(log L) line resolution
- `Text.Position` — typealias for `Tagged<Text, Ordinal>` (UTF-8 byte offset)
- `Text.Offset` — typealias for `Tagged<Text, Affine.Discrete.Vector>` (signed displacement)
- `Text.Count` — typealias for `Tagged<Text, Cardinal>` (non-negative quantity)
- `Text.Range` — struct with `start: Text.Position`, `end: Text.Position`
- `Text.Location` — struct with `line: Text.Line.Number`, `column: Text.Line.Column`

**Current dependencies**: Only `swift-affine-primitives`

**Key characteristics:**
- All types are about text structure (positions, ranges, lines) in terms of UTF-8 byte offsets
- No font, glyph, metrics, or visual/geometric types
- No dependency on geometry-primitives, dimension-primitives, or any geometric type system
- `Text.Line` is purely structural (source code line numbers), NOT visual (rendered line boxes)
- Adding a visual line box type would require adding geometry-primitives as a dependency

**Naming consideration:**
- `Text.Line` already exists as a namespace for structural line concepts
- Adding `Text.Line.Box` would mix structural and visual concerns under the same namespace
- The term "line" in `Text.Line.Number` means "source line" (structural); in "line box" it means "rendered line" (visual/geometric)

### Candidate 2: `swift-layout-primitives` (Layer 1)

**Location**: `/Users/coen/Developer/swift-primitives/swift-layout-primitives/`
**Module**: `Layout_Primitives`

**Current contents:**
- `Layout<Scalar: ~Copyable, Space>` — parameterized namespace enum
- Type aliases: `Layout.Width` = `Geometry<Scalar, Space>.Width`, `Layout.Height` = `Geometry<Scalar, Space>.Height`, `Layout.Spacing` = `Geometry<Scalar, Space>.Magnitude`
- `Layout.Stack<Content>` — linear arrangement (horizontal/vertical)
- `Layout.Grid<Content>` — 2D grid
- `Layout.Grid.Lazy` — responsive grid with fractional columns
- `Layout.Flow<Content>` — wrapping layout
- `Alignment` — 2D horizontal + vertical alignment (struct)
- `Horizontal.Alignment` — leading/center/trailing (enum)
- `Vertical.Alignment` — top/center/bottom/baseline (enum)
- `Vertical.Baseline` — first/last baseline selection (enum)
- `Cross.Alignment` — cross-axis: leading/center/trailing/fill (enum)
- `Direction` — LTR/RTL text flow (enum)
- `Corner` — layout-relative rectangle corner (struct)

**Current dependencies**: dimension-primitives, positioning-primitives, geometry-primitives, region-primitives

**Key characteristics:**
- Already has geometric types (`Layout.Height`, `Layout.Width`, `Layout.Spacing`)
- Already parameterized by `Scalar` and `Space` (same parameterization needed for LineBox)
- Has `Vertical.Baseline` enum — baseline awareness already present
- Has `Layout.Flow.Line` — line-level configuration in flow layout
- No text-specific types, but layout IS the domain of "how things get positioned on a page"
- LineBox is fundamentally about layout geometry (how a line of text occupies vertical space)

**Naming consideration:**
- `Layout.Line` doesn't exist yet as a namespace (only `Layout.Flow.Line` which is a nested struct)
- `Layout.Line.Box` would read as "a box for a line, in the layout domain" — accurate
- Alternatively `Layout.LineBox` but that's compound [API-NAME-001]
- Or `Layout.Text.Line.Box` but that introduces a `Text` namespace inside `Layout`

### Candidate 3: New package `swift-typography-primitives` (Layer 1)

A new primitives package dedicated to typographic concepts.

**Would contain:**
- Line box geometry (the half-leading model)
- Potentially: baseline types, em-square concepts, typographic scales
- Could grow to include other typographic primitives as needed

**Dependencies needed**: geometry-primitives, dimension-primitives (for Height, Scale types)

**Key characteristics:**
- Clean domain boundary: typography is distinct from both text structure and general layout
- Follows the primitives pattern of small, focused packages
- Risk: may remain a single-type package indefinitely (YAGNI violation)
- The `swift-primitives` monorepo already has 61 packages in 9 tiers — adding another is low-cost

### Candidate 4: Leave duplication in place (Layer 3)

Keep both implementations where they are:
- `PDF.HTML.LineBox` in pdf-html-rendering
- `Style.Resolved.Line` in pdf-rendering

**Key characteristics:**
- Zero migration cost
- ~15 lines of duplicated formulas
- Risk: silent divergence if one implementation gets a bugfix
- Both implementations are correct today
- Only 2 consumers (both in swift-foundations)

---

## Type System Context

### The Height Type Chain

LineBox needs a "height" type. Here is the complete chain from Layer 1 to the concrete PDF usage:

```
Layer 1 (identity-primitives):
  Tagged<Tag, RawValue>                    — zero-cost phantom-typed wrapper

Layer 1 (dimension-primitives):
  Extent.Y<Space>                          — phantom tag for vertical extent
  Extent.Y<Space>.Value<Scalar>            — Tagged<Extent.Y<Space>, Scalar>

Layer 1 (algebra-linear-primitives):
  Linear<Scalar, Space>.Height             — Extent.Y<Space>.Value<Scalar>

Layer 1 (geometry-primitives):
  Geometry<Scalar, Space>.Height           — Linear<Scalar, Space>.Height

Layer 1 (layout-primitives):
  Layout<Scalar, Space>.Height             — Geometry<Scalar, Space>.Height  (typealias)

Layer 2 (iso-32000):
  ISO_32000.UserSpace.Height               — Geometry<Double, UserSpace>.Height

Layer 3 (pdf-standard):
  PDF.UserSpace.Height                     — ISO_32000.UserSpace.Height  (typealias)
```

All of these are the SAME underlying type: `Tagged<Extent.Y<Space>, Scalar>`. The typealiases provide domain-specific names at each layer.

### The Scale Type

```
Layer 1 (dimension-primitives):
  Scale<let N: Int, Scalar>                — dimensionless scaling factor
  Scale<1, Double>                         — 1D scale (e.g., line-height multiplier 1.2)
```

### The Size Type

```
Layer 1 (geometry-primitives):
  Geometry<Scalar, Space>.Size<let N: Int> — N-dimensional size
  Geometry<Double, UserSpace>.Size<1>      — 1D size (e.g., font size 12pt)
```

The `.height` property on `Size<1>` extracts the single dimension as a `Height`:

```swift
extension Geometry.Size where N == 1 {
    public var height: Geometry.Height {
        get { Geometry.Height(dimensions[0]) }
        set { dimensions[0] = newValue.rawValue }
    }
}
```

### Font Metrics (Layer 2)

```
Layer 2 (iso-32000, Section 9.8):
  ISO_32000.9.8.Metrics                    — font descriptor metrics
    .ascender: ISO_32000.FontDesign.Height
    .descender: ISO_32000.FontDesign.Height  (negative value)
    .unitsPerEm: Int

    func ascender(atSize: ISO_32000.UserSpace.Size<1>) -> ISO_32000.UserSpace.Height
    func descender(atSize: ISO_32000.UserSpace.Size<1>) -> ISO_32000.UserSpace.Height
```

The `ascender(atSize:)` and `descender(atSize:)` methods scale font design units to user space. This is the bridge from font metrics (Layer 2) to geometric heights (Layer 1).

### Key Insight for Placement

If LineBox takes raw `Height` values (ascender, descender, lineHeight) as inputs — NOT font metrics — then it has NO Layer 2 dependency. The font-to-height conversion happens at the call site. This is what enables Layer 1 placement.

```swift
// Layer 1: Pure geometry — no font knowledge
Layout<Scalar, Space>.Line.Box(
    ascender: someHeight,      // Layout.Height
    descender: someHeight,     // Layout.Height (negative)
    lineHeight: someHeight     // Layout.Height
)

// Layer 3 call site: Font metrics → heights → LineBox
let ascender = font.metrics.ascender(atSize: fontSize)   // Layer 2 call
let descender = font.metrics.descender(atSize: fontSize)  // Layer 2 call
let lineHeight = fontSize.height * lineHeightMultiplier    // Layer 1 arithmetic
let lineBox = Layout<Double, UserSpace>.Line.Box(          // Layer 1 construction
    ascender: ascender,
    descender: descender,
    lineHeight: lineHeight
)
```

---

## Consumer Analysis

### All Usage Sites of Line Box Geometry

You MUST read these files to understand every consumer. This is the complete list.

**pdf-rendering consumers (Layer 3) — use `Style.Resolved.Line`:**

| File | Usage | What it accesses |
|------|-------|------------------|
| `swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.swift` line 294 | `advanceLine()` — advance Y by one line | `.line.height` |
| `swift-pdf-rendering/Sources/PDF Rendering/ISO_32000+PDF.View/ISO_32000.Text+PDF.View.swift` lines 44, 75 | Page break check before text | `.line.height` |
| `swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift` line 225 | Cache line height for word wrapping | `.line.height` |
| `swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift` line 234 | Calculate baseline Y for text | `.line.baselineOffset` |
| `swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift` line 444 | List marker baseline positioning | `.line.baselineOffset` |
| `swift-pdf-rendering/Tests/PDF Rendering Tests/PDF.Context Tests.swift` lines 90, 112 | Test line height scaling | `.line.height` |
| `swift-pdf-rendering/Tests/PDF Rendering Tests/PDF.Text Tests.swift` lines 114-115 | Test wrapped text advances | `.line.height` |

**pdf-html-rendering consumers (Layer 3) — use `Style.Resolved.Line` via `context.pdf.style.line`:**

| File | Usage | What it accesses |
|------|-------|------------------|
| `swift-pdf-html-rendering/Sources/.../HTML.Element.Tag+TableRow.swift` line 42 | Minimum row height | `.line.height` |
| `swift-pdf-html-rendering/Sources/.../HTML.Element.Tag+TableCell.swift` lines 69, 115 | Cell height estimation | `.line.height` |
| `swift-pdf-html-rendering/Sources/.../HTML.Element.Tag+HeaderRepetition.swift` lines 34, 68 | Header row height | `.line.height` |
| `swift-pdf-html-rendering/Sources/.../HTML.Element.Tag+Table.swift` lines 26, 90 | Default row height, deferred cell centering | `.line.height` |
| `swift-pdf-html-rendering/Sources/.../HTML.Element+PDF.HTML.View.swift` line 183 | Minimum content height check | `.line.height` |

**pdf-html-rendering consumers — use `PDF.HTML.LineBox` directly:**

| File | Usage | What it accesses |
|------|-------|------------------|
| `swift-pdf-html-rendering/Sources/.../HTML.Element.Tag+TableRow.swift` lines 33-36 | Multi-font baseline alignment | Constructs LineBox from font metrics |

**Font metrics consumers (ascender/descender calls that bypass line box):**

| File | Usage |
|------|-------|
| `swift-pdf-rendering/.../Pair+PDF.View.swift` lines 73, 144 | Checkmark vertical alignment |
| `swift-pdf-rendering/.../ISO_32000.Text+PDF.View.swift` lines 50, 81 | Direct baseline positioning |
| `swift-pdf-html-rendering/.../HTML.Element.Tag+TableRow.swift` lines 33-36 | Multi-font baseline |
| `swift-pdf-html-rendering/.../PDF.HTML.Configuration.swift` line 195 | Font metrics line normal/height |

---

## Naming Analysis Requirements

The research MUST evaluate naming options per [API-NAME-001] (Nest.Name pattern, no compound names):

### If placed in layout-primitives:

Option A: `Layout.Line.Box`
- `Layout.Line` = new namespace enum
- `Layout.Line.Box` = the line box struct
- Pro: Clean nesting, "Line" is a layout concept
- Con: `Layout.Flow.Line` already exists (different concept — flow line configuration)
- Question: Does `Layout.Line` conflict semantically with `Layout.Flow.Line`?

Option B: `Layout.Text.Line.Box`
- `Layout.Text` = new namespace enum
- Pro: Distinguishes text-layout from flow-layout line concepts
- Con: `Layout.Text` introduces a `Text` namespace inside `Layout` — potential confusion with `Text` from text-primitives
- Question: Does `Layout.Text` violate any naming convention?

Option C: `Layout.Inline.Box`
- CSS calls this the "inline formatting context"
- Pro: Mirrors CSS terminology
- Con: "Inline" is CSS-specific jargon, not a universal layout concept

### If placed in text-primitives:

Option D: `Text.Line.Box`
- Pro: Simple, `Text.Line` already exists
- Con: `Text.Line` is currently about structural lines (source code lines, byte offsets). A visual line box is a fundamentally different concept. Mixing structural and visual semantics under one namespace is a design smell.
- Con: Would require adding geometry-primitives as a dependency (currently only depends on affine-primitives)
- Question: Is the dependency cost justified for a single type?

Option E: `Text.Layout.Line.Box`
- Pro: Separates visual layout from structural text
- Con: Creates `Text.Layout` which overlaps with `Layout` from layout-primitives

### If placed in a new package:

Option F: `Typography.Line.Box`
- New `swift-typography-primitives` package
- Pro: Clean domain, no namespace conflicts
- Con: Single-type package (YAGNI until more typographic primitives are needed)

### File naming (per [API-IMPL-005]):

Whichever option is chosen, each type gets its own file:
- `Layout.Line.swift` — namespace enum (if needed)
- `Layout.Line.Box.swift` — the struct

---

## API Design Requirements

The research MUST evaluate API shape options:

### Init signature options:

**Option 1: Raw heights (decoupled from fonts)**
```swift
public init(
    ascender: Layout.Height,
    descender: Layout.Height,
    lineHeight: Layout.Height
)
```
- Pro: No font dependency, pure Layer 1
- Pro: Caller controls how heights are derived (could come from any font system, not just PDF)
- Con: Caller must extract ascender/descender before construction

**Option 2: Raw heights + multiplier convenience**
```swift
// Primary
public init(
    ascender: Layout.Height,
    descender: Layout.Height,
    lineHeight: Layout.Height
)

// Convenience — computes lineHeight from fontSize * multiplier
public init(
    ascender: Layout.Height,
    descender: Layout.Height,
    fontSize: Geometry<Scalar, Space>.Size<1>,
    lineHeightMultiplier: Scale<1, Scalar>
)
```
- Pro: Covers both current usage patterns (explicit height and multiplier)
- Con: The convenience init pulls in `Size<1>` and `Scale<1, Scalar>` — still Layer 1 types but more dependencies
- Question: Does `fontSize.height * multiplier` belong in the type or at the call site?

**Option 3: Static factory methods**
```swift
public init(ascender:descender:lineHeight:)

public static func scaled(
    ascender: Layout.Height,
    descender: Layout.Height,
    fontSize: Geometry<Scalar, Space>.Size<1>,
    by multiplier: Scale<1, Scalar>
) -> Self
```
- Pro: Primary init is minimal; factory adds convenience without polluting init namespace
- Con: Factory method name is compound (but acceptable per [IMPL-024] for static methods)

### Stored properties:

```swift
public let height: Layout.Height           // Total line box height
public let baselineOffset: Layout.Height   // Top of box to baseline
public let belowBaseline: Layout.Height    // Baseline to bottom of box
public let halfLeading: Layout.Height      // Half-leading value
```

Questions to evaluate:
- Should all 4 be stored, or should some be computed from others?
- Current `Style.Resolved.Line` has only 3 (missing `belowBaseline`). Is `belowBaseline` needed?
- If `height = baselineOffset + belowBaseline` always holds, should one be derived?

### Generic parameterization:

The type should be generic over `Scalar` and `Space` to match `Layout<Scalar, Space>`:

```swift
extension Layout where Scalar: BinaryFloatingPoint {
    public struct LineBox: Sendable, Equatable { ... }
}
```

Questions:
- Constraint: `BinaryFloatingPoint` vs `FloatingPoint` vs `SignedNumeric`?
- The computation uses: subtraction, addition, division by 2, max, negation
- `BinaryFloatingPoint` implies `FloatingPoint` implies `SignedNumeric` + `Comparable`
- What's the minimal constraint that supports all operations?

### Conformances:

Current `PDF.HTML.LineBox` conforms to `Sendable, Equatable`. Evaluate:
- `Sendable` — yes, all stored properties are `let`
- `Equatable` — yes, useful for tests and caching
- `Hashable` — consider (enables use as dictionary key / set member)
- `Codable` — consider (enables serialization of layout state)
- `Comparable` — NO (comparing line boxes is not semantically meaningful)

---

## Migration Analysis Requirements

The research MUST evaluate the migration path:

### What changes in pdf-rendering:

`Style.Resolved.Line` currently:
```swift
public var line: Line { Line(style: self) }

public struct Line: Sendable {
    private let style: PDF.Context.Style.Resolved
    init(style: ...) { ... }
    public var height: PDF.UserSpace.Height { ... }
    public var halfLeading: PDF.UserSpace.Height { ... }
    public var baselineOffset: PDF.UserSpace.Height { ... }
}
```

After migration, `Line` either:
- Becomes a typealias for `Layout<Double, UserSpace>.Line.Box` (if all properties match)
- Becomes a wrapper that returns a `Line.Box` (if additional properties are needed)
- Gets replaced entirely (call sites use `Line.Box` directly)

Questions:
- Does `Style.Resolved.line` remain as a computed property that constructs a `Line.Box`?
- Or does `Style.Resolved` store a `Line.Box` and update it when font/fontSize/lineHeight change?
- The current `Line` struct holds a reference to the entire `Style.Resolved` and recomputes on each access. A stored `Line.Box` would be more efficient but requires invalidation on style changes.

### What changes in pdf-html-rendering:

`CSS.LineBox.swift` gets deleted. All construction sites change from:
```swift
PDF.HTML.LineBox(metrics: font.metrics, fontSize: fontSize, lineHeightMultiplier: multiplier)
```
To:
```swift
let ascender = font.metrics.ascender(atSize: fontSize)
let descender = font.metrics.descender(atSize: fontSize)
Layout<Double, UserSpace>.Line.Box(ascender: ascender, descender: descender, lineHeight: ...)
```

Or, if a convenience init exists:
```swift
Layout<Double, UserSpace>.Line.Box(ascender: ..., descender: ..., fontSize: fontSize, lineHeightMultiplier: multiplier)
```

### Downstream call site impact:

Consumers that access `.line.height` or `.line.baselineOffset` on `Style.Resolved`:
- If `Style.Resolved.line` returns the unified type, call sites don't change
- If the return type changes (e.g., from `Line` to `Layout<...>.Line.Box`), property names must match

---

## Prior Art Survey Requirements

Per [RES-021], the research MUST survey prior art. Check:

### CSS Specification
- CSS 2.1 Section 10.8 — Line height calculations: the 'line-height' and 'vertical-align' properties
- CSS Inline Layout Module Level 3 — modern line box model
- How does the spec define "line box"? What properties does it have?
- Is the half-leading model the only model, or are there alternatives?

### Other rendering engines
- How do WebKit, Blink, and Gecko represent line box geometry internally?
- Do they separate the line box computation from font metrics?
- Are there standard abstractions used across rendering engines?

### Swift ecosystem
- Does SwiftUI have an equivalent concept? (It doesn't expose line box geometry publicly, but investigate)
- Does any Swift package on GitHub implement line box geometry?

### Other type-safe rendering systems
- Typst (Rust) — how does it handle line geometry?
- Prince XML — does it expose line box types?

### Typographic standards
- ISO 32000-2:2020 Section 9.8 (Font Descriptors) — already referenced
- OpenType spec — how does it define line spacing metrics (hhea table, OS/2 table)?
- The concept of "leading" in traditional typography vs. CSS half-leading

---

## Evaluation Criteria

The research MUST evaluate each option against these criteria:

1. **Layer correctness** — Does the type live at the correct architectural layer? Does it violate any upward/lateral dependency rules?

2. **Dependency cost** — What new dependencies does the placement introduce? Is the dependency justified by the type's domain?

3. **Naming clarity** — Does the type name and namespace accurately describe what it is? Does it conflict with existing names? Does it follow [API-NAME-001]?

4. **Semantic coherence** — Does the type fit with its neighbors? Does it share the same domain as other types in the package?

5. **Consumer ergonomics** — How does the placement affect call sites? How many imports change? How readable is the construction?

6. **Future extensibility** — If more typographic/layout primitives are needed later, does this placement leave room for growth?

7. **Migration cost** — How many files change? How complex is the migration? Can it be done incrementally?

8. **Reusability** — Could non-PDF rendering systems use this type? (e.g., a future SVG renderer, a terminal text renderer)

---

## Specific Questions to Answer

The research document MUST provide clear answers to ALL of these:

1. Should LineBox live in `text-primitives`, `layout-primitives`, a new `typography-primitives`, or stay duplicated in Layer 3?

2. If `text-primitives`: How do you resolve the semantic conflict between structural lines (byte offsets) and visual lines (rendered geometry)? Is adding geometry-primitives as a dependency justified?

3. If `layout-primitives`: What namespace? `Layout.Line.Box`? `Layout.Text.Line.Box`? Something else? How do you avoid confusion with `Layout.Flow.Line`?

4. If new package: Is a single-type package justified? What other types would plausibly join it? Is this premature abstraction?

5. Should the init take raw heights (ascender, descender, lineHeight) or font metrics? What's the correct abstraction boundary?

6. Should `belowBaseline` be a stored property or computed from `height - baselineOffset`?

7. What constraint should the generic require? `BinaryFloatingPoint`? `FloatingPoint`? Something else?

8. How should `Style.Resolved.Line` migrate? Typealias? Wrapper? Direct replacement?

9. Is the "CSS concept, not PDF concept" comment correct? Or is half-leading a universal typographic concept that predates CSS?

10. Are there any other duplicated typographic computations across these packages that should be unified at the same time? (Avoid solving only half the problem.)

---

## Files to Read

You MUST read these files as part of your analysis. Do not skip any.

### The two implementations being unified:

```
/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/CSS/CSS.LineBox.swift
/Users/coen/Developer/swift-foundations/swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.Style.Resolved.swift
```

### The candidate packages:

```
/Users/coen/Developer/swift-primitives/swift-text-primitives/Package.swift
/Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.swift
/Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Line.swift
/Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Line.Number.swift
/Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Line.Map.swift

/Users/coen/Developer/swift-primitives/swift-layout-primitives/Package.swift
/Users/coen/Developer/swift-primitives/swift-layout-primitives/Sources/Layout Primitives/Layout.swift
/Users/coen/Developer/swift-primitives/swift-layout-primitives/Sources/Layout Primitives/Layout.Flow.swift
/Users/coen/Developer/swift-primitives/swift-layout-primitives/Sources/Layout Primitives/Layout.Flow.Line.swift
/Users/coen/Developer/swift-primitives/swift-layout-primitives/Sources/Layout Primitives/Vertical.Alignment.swift
/Users/coen/Developer/swift-primitives/swift-layout-primitives/Sources/Layout Primitives/Vertical.Baseline.swift
```

### Font metrics (to understand what feeds into LineBox):

```
/Users/coen/Developer/swift-standards/swift-iso-32000/Sources/ISO 32000 9 Text/9.8 Font descriptors.swift
```

### All consumer files:

```
/Users/coen/Developer/swift-foundations/swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.swift
/Users/coen/Developer/swift-foundations/swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift
/Users/coen/Developer/swift-foundations/swift-pdf-rendering/Sources/PDF Rendering/ISO_32000+PDF.View/ISO_32000.Text+PDF.View.swift
/Users/coen/Developer/swift-foundations/swift-pdf-rendering/Sources/PDF Rendering/Rendering/Pair+PDF.View.swift

/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/HTML.Element.Tag+TableRow.swift
/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/HTML.Element.Tag+TableCell.swift
/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/HTML.Element.Tag+Table.swift
/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/HTML.Element.Tag+HeaderRepetition.swift
/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/HTML.Element+PDF.HTML.View.swift
/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift
```

### Dimension/geometry type definitions (to understand the type chain):

```
/Users/coen/Developer/swift-primitives/swift-dimension-primitives/Sources/Dimension Primitives/Scale.swift
/Users/coen/Developer/swift-primitives/swift-geometry-primitives/Sources/Geometry Primitives/Geometry.Size.swift
/Users/coen/Developer/swift-primitives/swift-geometry-primitives/Sources/Geometry Primitives/Geometry.swift
```

### Existing research (check for related research):

```
/Users/coen/Developer/swift-institute/Research/_index.md
```

---

## Output Format

Write the research document to:

```
/Users/coen/Developer/swift-institute/Research/line-box-unification.md
```

The document MUST follow [RES-003] format:

```markdown
# Line Box Unification

<!-- version: 1.0.0 -->
<!-- last_updated: 2026-03-12 -->
<!-- status: RECOMMENDATION -->

## Context

[Why this research is needed — the duplication, the audit finding, the architectural question]

## Question

[The specific design question — where should the canonical line box type live?]

## Prior Art

[CSS spec, rendering engines, Swift ecosystem, typographic standards]

## Analysis

### Option A: layout-primitives
[Description, pros, cons]

### Option B: text-primitives
[Description, pros, cons]

### Option C: New typography-primitives
[Description, pros, cons]

### Option D: Leave duplicated
[Description, pros, cons]

### Comparison

| Criterion | layout-primitives | text-primitives | typography-primitives | Leave duplicated |
|-----------|---|---|---|---|
| Layer correctness | ... | ... | ... | ... |
| Dependency cost | ... | ... | ... | ... |
| Naming clarity | ... | ... | ... | ... |
| Semantic coherence | ... | ... | ... | ... |
| Consumer ergonomics | ... | ... | ... | ... |
| Future extensibility | ... | ... | ... | ... |
| Migration cost | ... | ... | ... | ... |
| Reusability | ... | ... | ... | ... |

## Outcome

**Status**: RECOMMENDATION
**Conclusion**: [Which option and why]
**Rationale**: [Detailed reasoning]

### Recommended Type Design

[Show the complete type signature, init, properties, conformances, file layout]

### Recommended Migration Path

[Step-by-step migration for both pdf-rendering and pdf-html-rendering]

### Naming Decision

[Final type name with reasoning against alternatives]

## References

- CSS 2.1 Section 10.8
- ISO 32000-2:2020 Section 9.8
- [Any other references discovered during prior art survey]
```

After writing the research document, update the index at `/Users/coen/Developer/swift-institute/Research/_index.md` if it exists (add a row for the new document).

---

## Reminders

- You are producing a RESEARCH DOCUMENT, not implementation code.
- Read ALL skills before writing.
- Read ALL listed files before writing.
- Follow [RES-003] format exactly.
- This is Tier 2 — include Prior Art Survey.
- The document should be thorough enough that an implementer can execute without further research.
- Do not abbreviate the analysis. Show full reasoning for every option.
- The comparison table must cover all 8 evaluation criteria for all 4 options.
- Write output to `/Users/coen/Developer/swift-institute/Research/line-box-unification.md`. Return ONLY a one-line confirmation: "Wrote line-box-unification.md to /Users/coen/Developer/swift-institute/Research/".
