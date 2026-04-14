# Rendering Stack Overflow Investigation

## Problem Statement

Deeply nested `HTML.View` types cause a runtime stack overflow (SIGBUS signal 10) during rendering. The crash occurs when the concrete type behind `some HTML.View` has extreme generic nesting — specifically, views composed of multiple `Section` elements containing multiple `Table > TableBody > TableRow > TableDataCell` hierarchies with CSS modifier chains and `if/let` conditionals.

This is **not** a compile-time issue — the code compiles fine on Swift 6.2.4. It is a **runtime** issue: the recursive `_render` traversal of deeply nested generic types overflows the default thread stack.

## Confirmed Crash Reproduction

The crash is reproducible with any `HTML.View` that nests multiple `Section` elements containing multiple `Table > TableBody > TableRow > TableDataCell` hierarchies with CSS modifier chains and `if/let` conditionals, producing a concrete type with extreme generic depth.

The crash happens regardless of whether the view is iterated via `for` loop or `HTMLForEach` — it's the **view itself** that overflows during rendering, not the iteration mechanism.

## Representative Crashing View Shape

A typical crashing view contains two `Section` elements (each with `.css.breakBefore(.page)` modifier), each containing several Tables with CSS modifier chains and conditional content. The concrete type behind `body: some HTML.View` looks approximately:
```
_Tuple<
  CSS.Modified<Section<_Tuple<
    H<1, String>,
    H<3, String>,
    Optional<_Tuple<...~6 nested rows...>>,
    Optional<_Tuple<
      CSS.Modified<H<3, String>>,
      CSS.Modified<Table<TableBody<_Tuple<...6 rows...>>>>,
      CSS.Modified<Table<TableBody<_Tuple<...3 rows...>>>>,
      CSS.Modified<Table<TableBody<_Tuple<...4 rows...>>>>,
      Optional<Paragraph<String>>
    >>,
    Optional<_Tuple<...more tables...>>,
    Optional<_Tuple<...more tables...>>
  >>>,
  CSS.Modified<Section<_Tuple<
    H<1, String>,
    Paragraph<String>,
    Optional<_Tuple<...>>,
    Optional<_Tuple<...>>
  >>>
>
```

Each `@HTML.Builder` sub-property returns `some HTML.View`, which the compiler resolves to an `Optional<_Tuple<...>>` when used in the parent builder (because the property is called from a non-builder context, or due to how the builder transform handles computed property references).

## Root Cause Analysis

The rendering infrastructure uses recursive static dispatch:

1. `Rendering.View` default `_render` calls `RenderBody._render(view.body, context:)`
2. `_Tuple._render` iterates the pack: `repeat render(each view.content, &context)`
3. Each element's `_render` recurses into its children
4. Container types (`Section`, `Table`, `TableBody`, etc.) call `Content._render` on their generic content
5. CSS modifier wrappers add another frame per `.css.xxx()` call

For a sufficiently deep view, this creates a call stack roughly 200-400+ frames deep. The default thread stack (typically 512KB on macOS for non-main threads, 8MB for main) overflows.

## Architecture: How Rendering Works

### Layer 1: Rendering Primitives
**Package**: `https://github.com/swift-primitives/swift-rendering-primitives`

Key files:
- `Sources/Rendering Primitives Core/Rendering.View.swift` — Protocol with default `_render` that calls `body._render()`
- `Sources/Rendering Primitives Core/Rendering._Tuple.swift` — Variadic `_Tuple<each Content>` with `repeat render(each view.content, &context)` in `_render`
- `Sources/Rendering Primitives Core/Rendering.Builder.swift` — Unconstrained result builder
- `Sources/Rendering Primitives Core/Rendering.Context.swift` — Mutable context passed through rendering
- `Sources/Rendering Primitives Core/Rendering.Conditional.swift` — `if/else` wrapper
- `Sources/Rendering Primitives Core/Rendering.ForEach.swift` — ForEach wrapper
- `Sources/Rendering Primitives Core/Array+Rendering.swift` — Array: Rendering.View conformance

### Layer 3: HTML Rendering
**Package**: `https://github.com/swift-foundations/swift-html-rendering`

Key files:
- `Sources/HTML Renderable/HTML.View.swift` — `HTML.View: Rendering.View` protocol refinement
- `Sources/HTML Renderable/_Tuple+HTML.swift` — Conditional `HTML.View` conformance for `_Tuple`
- `Sources/HTML Renderable/_Array+HTML.swift` — Conditional `HTML.View` conformance for `Array`
- `Sources/HTML Renderable/ForEach+HTML.swift` — Conditional `HTML.View` conformance for `ForEach`

### Layer 3: CSS HTML Rendering
**Package**: `https://github.com/swift-foundations/swift-css-html-rendering`

This is where CSS modifiers wrap views in additional generic layers. Each `.css.xxx()` call wraps the view in a modifier type, adding generic depth.

### WHATWG HTML Elements
**Package**: `https://github.com/swift-whatwg/swift-whatwg-html`

Defines `Table`, `TableBody`, `TableRow`, `TableDataCell`, `Section`, `H`, `Paragraph`, etc. — each a generic struct `Type<Content: HTML.View>: HTML.View` that calls `Content._render` in its implementation.

## What Was Already Tried

### Experiment: for-loop-result-builder
**Location**: `Experiments/for-loop-result-builder/`

This experiment has a multi-module setup (LocalPackages/RenderingPrimitives + LocalPackages/HTMLRenderable) simulating the L1→L3 module chain. **Could not reproduce the crash** because the simulated types lack the real generic depth of WHATWG elements + CSS modifier chains. The experiment is still useful as a test harness.

### Related Memory Entry
The `iterative-tuple-rendering.md` memory entry tracks a related issue: stack overflow from deeply nested `_Tuple` types in PDF rendering. The previous investigation found that `as?` casts on 70+ element types overflow. The user directed investigating a trampoline approach.

## Fix Approaches to Investigate

### Approach A: Trampoline in Rendering.Context

Instead of recursive `_render` calls, push render work onto a stack/queue in the `Rendering.Context` and process iteratively:

```swift
// Conceptual sketch
extension Rendering {
    struct Context {
        var output: String = ""
        // Add a work stack
        var workStack: [(any Rendering.View, ???)] = []

        mutating func processIteratively() {
            while let work = workStack.popLast() {
                // render without recursion
            }
        }
    }
}
```

**Challenge**: `_render` is a static protocol method with generic `Self`. Converting to existential dispatch (`any Rendering.View`) would lose the static dispatch performance that the entire rendering system is built on. Need to find a way to push closures or type-erased work items.

### Approach B: Increase Stack Size

Run rendering on a thread with a larger stack:
```swift
let thread = Thread { /* render here */ }
thread.stackSize = 16 * 1024 * 1024 // 16MB
```

**Pro**: Simple, no architectural changes.
**Con**: Band-aid, doesn't fix the fundamental issue. Stack can still overflow with sufficiently deep types.

### Approach C: Flatten _Tuple Rendering

Change `_Tuple._render` to be iterative rather than recursive. Currently uses parameter pack iteration (`repeat render(each view.content, &context)`), which may compile to recursive calls. If it could be converted to array-based iteration, the stack depth would be bounded.

**Challenge**: Parameter pack iteration (`repeat each`) is the only way to iterate heterogeneous packs in Swift. Converting to homogeneous iteration requires type erasure.

### Approach D: Break the Recursion at Container Boundaries

Make container types (Table, Section, etc.) use an iterative rendering approach for their content. Instead of `Content._render(view.content, context:)`, they could push the content rendering to the context's work queue.

### Approach E: Limit Nesting Depth Per View

Restructure views so that each computed property doesn't return `some HTML.View` (which gets wrapped in Optional by the builder) but instead uses `Never` as RenderBody with a custom `_render`. This avoids the default `_render → body → _render` recursion.

## Key Constraints

1. The rendering system MUST remain statically dispatched — existential overhead (`any Rendering.View`) is not acceptable for production rendering
2. The fix should be in L1 (Rendering Primitives) so all domain layers (HTML, SVG, PDF) benefit
3. `~Copyable` is used in the real `Rendering.View` protocol — solutions must be compatible
4. The fix must handle arbitrarily deep generic types, not just a specific threshold
5. The `Rendering.Context` is `~Copyable` and passed as `inout` — this constrains what patterns are possible

## Files to Read First

1. `https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Sources/Rendering Primitives Core/Rendering.View.swift` — Default `_render` implementation
2. `https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Sources/Rendering Primitives Core/Rendering._Tuple.swift` — Pack iteration in `_render`
3. `https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Sources/Rendering Primitives Core/Rendering.Context.swift` — Context structure
4. `Experiments/for-loop-result-builder/` — Existing experiment (doesn't reproduce but has multi-module harness)
5. `https://github.com/swift-foundations/swift-css-html-rendering/blob/main/Tests/CSS HTML Rendering Tests/ForLoopBuilderTests.swift` — Tests that PASS (simple types)

## Build & Test Commands

```bash
# Build the rendering primitives:
cd swift-rendering-primitives
swift build

# Build/test the experiment:
cd Experiments/for-loop-result-builder
swift build && swift run

# Build CSS HTML rendering tests (for-loop tests that pass):
cd swift-css-html-rendering
swift test --filter ForLoopBuilderTests
```

## Success Criteria

1. A representative deeply-nested HTML view can render without signal 10 stack overflow
2. No performance regression in rendering simple views
3. Fix is in L1 (Rendering Primitives), not a consumer-side workaround
4. `HTMLForEach` becomes truly unnecessary (can use native `for` loops everywhere)
5. No existential boxing (`any Rendering.View`) in the hot rendering path
