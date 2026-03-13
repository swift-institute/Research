# Layout Stack API in PDF Rendering

<!--
---
version: 2.0.0
last_updated: 2026-03-13
status: DECISION
---
-->

## Context

While fixing a table rendering bug in swift-pdf-rendering (all 6 columns collapsed into a single column, data across 10 pages), we discovered that `PDF.HStack { }` silently creates a **vertical** stack. The root cause: `PDF.VStack` and `PDF.HStack` are typealiases to the same `Layout.Stack` type, and the only convenience `init` hardcodes `.vertical(...)`.

The layout primitives package (`swift-layout-primitives`, L1) defines `Layout<Scalar, Space>.Stack<Content>` correctly — a struct with an `axis: Axis<2>` property and two static factories (`.vertical(...)` / `.horizontal(...)`). The pdf-rendering package (L3) wraps this with `@PDF.Builder` convenience methods but introduced misleading typealiases.

### Trigger

Design question arose during implementation: after fixing the table bug, how should `Layout.Stack` be properly adapted in the rendering layer?

### Constraints

- `Layout.Stack` is the canonical type (L1 primitives). pdf-rendering should adapt it, not wrap it.
- `@PDF.Builder` result builder syntax is rendering-layer specific.
- `Axis<2>` uses `.primary`/`.secondary` (dimension-generic).
- Existing test code already uses `PDF.HStack.horizontal { }` — the footgun only hit internal table type implementations.

## Question

1. How should `Layout.Stack` be constructed in the PDF rendering layer?
2. Should the `VStack`/`HStack` typealiases be preserved?
3. Where do spatial axis names (`.horizontal`/`.vertical`) belong in the type hierarchy?

## First-Principles Analysis

### What is a Stack?

A stack is a sequential arrangement of content along a single axis. It is parameterized by:
- **Axis**: which basis direction to arrange along
- **Spacing**: gap between adjacent items
- **Content**: the things being arranged

The axis is *data* — a parameter to the stack concept, not a type-level distinction. Both orientations produce the same structural result (a linear sequence of positioned items); only the direction differs. This is correctly modeled by `Layout.Stack<Content>` storing `axis: Axis<2>` as a property.

### Can a stack be diagonal?

No. `Axis<N>` identifies one of exactly N basis vector directions (indices 0 through N-1). A diagonal is a linear combination of basis vectors, not a basis vector itself. `Axis<2>` has exactly 2 values — `.primary` (index 0) and `.secondary` (index 1). Diagonal arrangement is correctly unrepresentable. Stack is fundamentally basis-aligned by construction.

If diagonal arrangement were needed, it would require a different primitive (e.g., a flow with a direction vector, or a rotated coordinate system), not an extended axis.

### Why VStack/HStack typealiases are wrong

`PDF.VStack<C>` and `PDF.HStack<C>` are both `PDF.Layout.Stack<C>`. Since they're the same type:
- The compiler cannot enforce that `HStack` is horizontal
- Any `init` on one is available on the other
- Return types `PDF.HStack<T>` are documentary fiction — the type doesn't encode axis

This is not a solvable problem with typealiases. The axis is data, and typealiases can't carry data. The only honest options are: (a) separate wrapper types (wrapping primitives — against "adapt, not wrap"), or (b) accept that there is one `Stack` type and the axis is always a parameter.

### Where do `.horizontal`/`.vertical` belong?

**`Axis<N>` in dimension-primitives** (L1, Tier 0):

`Axis<N>` is defined as "A coordinate axis in N-dimensional space." The doc comments say "typically X/horizontal" and "typically Y/vertical." The "typically" qualifier exists because dimension-primitives is not exclusively spatial — the dimension concept could model non-spatial dimensions (time, temperature, frequency).

`.primary`/`.secondary` are correct at this layer: they're index-based names that make no spatial assumptions.

**`Layout` in layout-primitives** (L1, Tier 10):

Layout IS spatial. The `Layout` namespace is defined as "Compositional layout primitives parameterized by scalar type and coordinate space." Layout types already commit to the spatial mapping: `Layout.Stack.horizontal(...)` → axis `.primary`, `Layout.Stack.vertical(...)` → axis `.secondary`. The mapping is also standard mathematics for 2D Cartesian coordinates.

Furthermore, layout-primitives already imports and extends spatial types: `Horizontal`, `Vertical`, `Cross.Alignment`. The spatial vocabulary exists at this layer.

**Conclusion**: `.horizontal`/`.vertical` belong on `Axis where N == 2` as extensions in layout-primitives. This is the layer that interprets abstract axes spatially. The mapping is:
- Standard 2D Cartesian convention (axis 0 = X = horizontal, axis 1 = Y = vertical)
- Consistent with existing `Layout.Stack` factory methods
- Scoped to `N == 2` (not available on `Axis<3>` where "horizontal"/"vertical" would be ambiguous)

Note: `.primary`/`.secondary` remain the canonical names on `Axis<2>`. `.horizontal`/`.vertical` are additional spatial aliases, not replacements. Both remain available.

### On typealiases

> "ONLY have typealiases where they add significant value"

- `PDF.Stack<C>` — **keep**. Genuine shortcut for `PDF.Layout.Stack<C>` = `LayoutRaw<Double, ISO_32000_Shared.UserSpace>.Stack<C>`. Adds significant value.
- `PDF.VStack<C>` — **remove**. Same type as `PDF.Stack<C>`. Cannot encode axis. No value.
- `PDF.HStack<C>` — **remove**. Same type as `PDF.Stack<C>`. Active footgun.

### On default axis

Vertical is the common case in document rendering — content flows top to bottom. The `init` should default to `.vertical` (equivalently `.secondary`):

```swift
init(_ axis: Axis<2> = .vertical, spacing: ..., @PDF.Builder _ build: ...)
```

This enables three call patterns:
```swift
PDF.Stack { }                    // vertical (default, common case)
PDF.Stack(.vertical) { }        // explicit vertical
PDF.Stack(.horizontal) { }      // horizontal
```

### On static factories vs. init

The existing `.horizontal(...)` / `.vertical(...)` static factories on `Layout.Stack` encode the spatial mapping in the method name. The `init(_ axis:)` approach encodes it in the parameter value. Both are correct.

With the Axis aliases, the init subsumes the factories:
- `Stack.horizontal { }` → `Stack(.horizontal) { }`
- `Stack.vertical { }` → `Stack(.vertical) { }`

The init is strictly more general (composable — axis can be passed as data, no switch needed). The factories become redundant but not harmful. In the primitives layer, keeping them is fine (they predate the rendering layer). In the rendering layer, the init replaces them — one construction path.

## Current State

### Layout primitives

```swift
public struct Stack<Content> {
    public var axis: Axis<2>
    public var spacing: Spacing
    public var alignment: Cross.Alignment
    public var content: Content
}

// Memberwise init
public init(axis: Axis<2>, spacing: Spacing, alignment: Cross.Alignment, content: Content)

// Static factories
static func vertical(spacing:alignment:content:) -> Self   // axis = .secondary
static func horizontal(spacing:alignment:content:) -> Self  // axis = .primary
```

### PDF rendering layer

```swift
// Three typealiases to the same type
public typealias Stack<C>  = PDF.Layout.Stack<C>
public typealias VStack<C> = PDF.Layout.Stack<C>
public typealias HStack<C> = PDF.Layout.Stack<C>

// Single convenience init — always vertical
public init(spacing: PDF.Layout.Spacing = 0, @PDF.Builder _ build: () -> Content) {
    self = .vertical(spacing: spacing, content: build())
}

// @Builder-wrapped static factories
public static func vertical(spacing:, @PDF.Builder _:) -> Self
public static func horizontal(spacing:, @PDF.Builder _:) -> Self
```

### Usage census (pdf-rendering sources + tests)

| Pattern | Count | Correct? |
|---------|-------|----------|
| `PDF.VStack(spacing: X) { }` | ~25 | Yes — init defaults to vertical |
| `PDF.VStack { }` | ~10 | Yes — same |
| `PDF.HStack.horizontal { }` | 8 | Yes — explicit factory |
| `PDF.HStack { }` | 2 (table types, now fixed) | **No** — created vertical |
| `PDF.Stack.horizontal { }` | 2 (table types, current fix) | Yes — explicit factory |
| `PDF.VStack<T>` as return type | 7 | Documentary only |
| `PDF.HStack<T>` as return type | 2 | Documentary only — same type |

## Outcome

**Status**: DECISION

### Decision: `init(_ axis:)` with Axis aliases in layout-primitives

Target call sites:

```swift
PDF.Stack { }                    // vertical (default)
PDF.Stack(.vertical) { }        // explicit vertical
PDF.Stack(.horizontal) { }      // horizontal
PDF.Stack(.primary) { }         // also valid (raw axis name)
```

### Implementation

#### Step 1: Add Axis aliases in layout-primitives

File: `swift-layout-primitives/Sources/Layout Primitives/Axis+Layout.swift` (new file)

```swift
extension Axis where N == 2 {
    /// The horizontal axis (index 0, X).
    ///
    /// Alias for `.primary` using spatial terminology standard in 2D Cartesian coordinates.
    @inlinable
    public static var horizontal: Self { .primary }

    /// The vertical axis (index 1, Y).
    ///
    /// Alias for `.secondary` using spatial terminology standard in 2D Cartesian coordinates.
    @inlinable
    public static var vertical: Self { .secondary }
}
```

#### Step 2: Add `init(_ axis:)` convenience on Layout.Stack in layout-primitives

File: `swift-layout-primitives/Sources/Layout Primitives/Layout.Stack.swift`

```swift
/// Creates a stack along the given axis with default alignment.
@inlinable
public init(
    _ axis: Axis<2> = .secondary,
    spacing: Layout.Spacing,
    content: Content
) {
    self.init(axis: axis, spacing: spacing, alignment: .center, content: content)
}
```

Existing `.vertical(...)` / `.horizontal(...)` factories remain (backwards compatibility). They are subsumed by the init but not harmful.

#### Step 3: Replace pdf-rendering convenience init

File: `swift-pdf-rendering/.../PDF.Stack+PDF.View.swift`

Replace:
```swift
public typealias Stack<C>  = PDF.Layout.Stack<C>
public typealias VStack<C> = PDF.Layout.Stack<C>
public typealias HStack<C> = PDF.Layout.Stack<C>

public init(spacing: ..., @PDF.Builder _ build: ...) {
    self = .vertical(spacing: spacing, content: build())
}

public static func vertical(spacing: ..., @PDF.Builder _ build: ...) -> Self { ... }
public static func horizontal(spacing: ..., @PDF.Builder _ build: ...) -> Self { ... }
```

With:
```swift
public typealias Stack<C> = PDF.Layout.Stack<C>

public init(
    _ axis: Axis<2> = .vertical,
    spacing: PDF.Layout.Spacing = 0,
    @PDF.Builder _ build: () -> Content
) {
    self.init(axis: axis, spacing: spacing, alignment: .center, content: build())
}
```

#### Step 4: Update all call sites

| Before | After |
|--------|-------|
| `PDF.VStack(spacing: 12) { }` | `PDF.Stack(.vertical, spacing: 12) { }` |
| `PDF.VStack { }` | `PDF.Stack { }` |
| `PDF.HStack.horizontal { }` | `PDF.Stack(.horizontal) { }` |
| `PDF.Stack.horizontal { }` | `PDF.Stack(.horizontal) { }` |
| `PDF.VStack<Content>` (return type) | `PDF.Stack<Content>` |
| `PDF.HStack<Content>` (return type) | `PDF.Stack<Content>` |
| `PDF.VStack._render(stack, context:)` | `PDF.Stack._render(stack, context:)` |

#### Step 5: Rename test suites

| Before | After |
|--------|-------|
| `PDF.Stack.Vertical Tests` | `PDF.Stack Tests` with vertical section |
| `PDF.Stack.Horizontal Tests` | `PDF.Stack Tests` with horizontal section |
| `PDF.Stack Nested Tests` | `PDF.Stack Tests` with nesting section |

### Rationale

1. **A stack is parameterized by axis** — axis is data, not type-level. The `init(_ axis:)` pattern makes this explicit.
2. **`.horizontal`/`.vertical` are standard spatial names** for 2D Cartesian basis vectors. They belong in layout-primitives where the spatial interpretation is established.
3. **`VStack`/`HStack` typealiases add no value** — same type, cannot encode axis, active footgun for `HStack`. Only `PDF.Stack` adds genuine value.
4. **Default to `.vertical`** — vertical is the common case in document rendering (content flows top to bottom). The bare `Stack { }` call handles the ~35 most common occurrences with no axis annotation needed.
5. **Composable** — axis as data enables `func makeStack(_ axis: Axis<2>) { PDF.Stack(axis) { } }` without switching on factories.

### Open Design Question

Should `Layout.Stack` in primitives deprecate the `.horizontal(...)` / `.vertical(...)` static factories now that `init(_ axis:)` subsumes them? Or keep them for backwards compatibility and as documented named constructors?

**Recommendation**: Keep for now. They're not harmful, and external consumers may use them. Deprecation can happen in a future major version if the init pattern proves sufficient.

## References

- `swift-layout-primitives/Sources/Layout Primitives/Layout.Stack.swift` — canonical Stack type
- `swift-dimension-primitives/Sources/Dimension Primitives/Axis.swift` — Axis<N> type
- `swift-pdf-rendering/Sources/PDF Rendering/Rendering/PDF.Stack+PDF.View.swift` — current adaptation
- `swift-pdf-rendering/Sources/PDF Rendering/ISO_32000+PDF.View/ISO 32000.Table+PDF.View.swift` — table types (bug site)
- Commit `a10cf531` — table layout fix that exposed this design question

## Changelog

- v2.0.0 (2026-03-13): First-principles analysis. Resolved open questions: Axis aliases in layout-primitives, `PDF.Stack Tests` with per-axis sections, `init(_ axis:)` on primitives Stack. Status → DECISION.
- v1.0.0 (2026-03-13): Initial analysis with 5 options and preliminary recommendation.
