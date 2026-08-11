# Iterative Tuple Rendering

<!--
---
version: 1.0.0
last_updated: 2026-03-12
status: RECOMMENDATION
tier: 2
---
-->

## Context

The PDF HTML rendering pipeline (`swift-pdf-html-rendering`) uses recursive dispatch to render view trees. The central function `renderHTMLView(_ view: some HTML.View, context:)` in `PDF.HTML.swift:439–558` acts as a runtime type dispatcher: it inspects each view, determines its type via Mirror (Phase 1) or `as?` casts (Phase 2), and delegates to the appropriate renderer. When the view is a `_Tuple`, the dynamic dispatch path calls `_renderEachElementDynamically()`, which calls `renderHTMLView` for each element — forming a recursive loop.

`Rendering.Builder` uses `buildPartialBlock(accumulated:next:)` (defined in `Rendering.Builder.swift:90–95`) to combine elements in a result builder body. For N elements, this produces a left-heavy binary tree of `_Tuple` nodes:

```
5 elements → _Tuple<_Tuple<_Tuple<_Tuple<A, B>, C>, D>, E>    (depth 4)
10 elements → depth 9
N elements → depth N-1
```

Each nesting level adds ~3 function frames during dynamic rendering:

```
_renderEachElementDynamically()    frame 1
  renderElement()  (local function)  frame 2
    renderHTMLView()                 frame 3  ← re-enters top
```

Each frame is approximately 200–400 bytes (Mirror creation, `as?` casts, local function closures, `inout` context reference). The cost per recursion cycle is ~700–1200 bytes.

### Stack Budget Analysis

| Environment | Available Stack | Baseline Usage | Budget for Rendering |
|---|---|---|---|
| Standalone executable (`Task { }`) | ~512 KB | ~5 KB | ~507 KB |
| Swift Testing (async test) | ~64 KB | ~40 KB | ~24 KB |

For a 5×5 table under Swift Testing:
- Table structure: `Table<TableHead<_Tuple<...>>, TableBody<_Tuple<...>>, TableFoot<...>>`
- TableBody: 5 rows → _Tuple depth 4 → 4 × 3 = 12 frames → ~6 KB
- Each Row: 5 cells → _Tuple depth 4 → 4 × 3 = 12 frames → ~6 KB per row
- Maximum depth: Table → TableBody → _Tuple row recursion → Row → _Tuple cell recursion
- Total _Tuple frames: ~12 + 12 = 24 frames at maximum depth → ~14 KB
- Plus view nesting (ComplexView → GroupView → SectionView → Table): ~4 KB
- Total: ~40 KB (baseline) + 14 KB (_Tuple) + 4 KB (views) = ~58 KB → within 64 KB but marginal

With 8+ columns or deeper view nesting, the budget is exceeded, triggering `___chkstk_darwin` (stack probe failure).

### Empirical Confirmation

Three experiments isolate the root cause:

| Experiment | Location | Result |
|---|---|---|
| HTML types only, async Task | `swift-rendering-primitives/Experiments/result-builder-stack-overflow-html/` | ALL PASS (100 elements) |
| Full PDF pipeline, async Task | `swift-pdf/Experiments/result-builder-stack-overflow/` | ALL PASS (70 elements) |
| Full PDF pipeline, Swift Testing | PDF test suite | CRASHES at 5+ columns/rows |

The crash occurs only when Swift Testing's ~40 KB baseline stack consumption combines with _Tuple recursion depth. Standalone executables have sufficient stack (~512 KB) for any realistic view tree.

## Question

How can the `_Tuple` dynamic dispatch path be made iterative, eliminating O(N) stack growth from left-heavy binary nesting, while preserving: (1) Phase 1 Mirror-based wrapper detection, (2) left-to-right rendering order, (3) sequential `inout` context mutation, (4) zero overhead on the static dispatch path, and (5) marker protocol architecture?

## Analysis

### Current Dispatch Architecture

The rendering engine has two dispatch levels:

**Static dispatch** (compile-time): When all types in a `_Tuple` conform to `PDF.HTML.View`, the compiler generates direct calls via variadic pack expansion:

```swift
// _Tuple+Transform.swift:10–21
extension Rendering._Tuple: PDF.HTML.View where repeat each Content: PDF.HTML.View {
    public static func _render(_ view: Self, context: inout PDF.HTML.Context) {
        func render<T: PDF.HTML.View>(_ element: T) {
            T._render(element, context: &context)
        }
        repeat render(each view.content)
    }
}
```

This path is O(1) stack depth — `repeat` expands at compile time with no recursion through `renderHTMLView`. It is NOT affected by this issue.

**Dynamic dispatch** (runtime): When types are unknown at compile time (wrapper types obscure conformances), the engine falls back to `renderHTMLView`, which detects `_TupleContent` via `as?` cast (`PDF.HTML.swift:520–523`) and calls:

```swift
// _Tuple+Transform.swift:25–32
extension Rendering._Tuple: _TupleContent where repeat each Content: HTML.View {
    public func _renderEachElementDynamically(context: inout PDF.HTML.Context) {
        func renderElement<T: HTML.View>(_ element: T) {
            PDF.HTML.renderHTMLView(element, context: &context)
        }
        repeat renderElement(each content)
    }
}
```

For `_Tuple<_Tuple<A, B>, C>`, `repeat` expands to two calls: `renderElement(_Tuple<A, B>)` and `renderElement(C)`. The first call re-enters `renderHTMLView`, which detects the inner `_Tuple` and recurses — producing O(N) stack depth for N elements.

### Existing Iterative Pattern: `renderFlattenedStyledContent`

The codebase already solves an identical problem for `HTML.Styled` wrappers (`PDF.HTML.swift:577–748`). Nested `Styled<Styled<Styled<Element, A>, B>, C>` wrappers are flattened into an `[any _HTMLStyledContent]` array via a `while let` loop (`PDF.HTML.swift:597–605`), then styles are applied iteratively (`PDF.HTML.swift:610–621`).

This is the template for a `_Tuple` solution: collect elements into a flat collection, then process iteratively.

### Two Call Sites

The `_TupleContent` dynamic dispatch is reached from two call sites:

1. **`renderHTMLView`** (`PDF.HTML.swift:520–523`): Main entry, Phase 2 `as? any _TupleContent`
2. **`renderInnerContent`** (`PDF.HTML.swift:1104–1107`): After Mirror-based wrapper unwrapping, the extracted content may itself be a `_Tuple`

Both call sites must be updated for the fix to be complete.

---

### Option A: Protocol Method `_collectElements` + Iterative Rendering

Add a method to `_TupleContent` that pushes elements into a collection using variadic pack expansion, then flatten the `_Tuple` binary tree iteratively at the call site.

**Protocol change** (`PDF.HTML.swift:1292–1295`):

```swift
package protocol _TupleContent {
    func _renderEachElementDynamically(context: inout PDF.HTML.Context)
    func _collectElements(into collection: inout [Any])
}
```

**Conformance** (`_Tuple+Transform.swift`):

```swift
extension Rendering._Tuple: _TupleContent where repeat each Content: HTML.View {
    public func _renderEachElementDynamically(context: inout PDF.HTML.Context) {
        func renderElement<T: HTML.View>(_ element: T) {
            PDF.HTML.renderHTMLView(element, context: &context)
        }
        repeat renderElement(each content)
    }

    public func _collectElements(into collection: inout [Any]) {
        func collect<T: HTML.View>(_ element: T) {
            collection.append(element)
        }
        repeat collect(each content)
    }
}
```

**Iterative rendering helper** (new function in `PDF.HTML.swift`):

```swift
/// Flatten a _Tuple binary tree and render each leaf element iteratively.
///
/// The binary nesting from `buildPartialBlock(accumulated:next:)`:
///   _Tuple<_Tuple<_Tuple<A, B>, C>, D>
/// is flattened to [A, B, C, D] using a stack-based DFS, then each
/// leaf element is rendered via `renderInnerContent`. This converts
/// O(N) stack depth to O(1) stack depth with O(N) heap allocation.
///
/// Rendering order (left-to-right) is preserved by pushing children
/// in reverse order onto the LIFO stack.
static func renderTupleIteratively(
    _ tuple: any _TupleContent,
    context: inout PDF.HTML.Context
) {
    var stack: [Any] = []

    // Seed the stack with the top-level _Tuple's children (reversed for LIFO order)
    tuple._collectElements(into: &stack)
    stack.reverse()

    while let next = stack.popLast() {
        if let nestedTuple = next as? any _TupleContent {
            // Flatten: replace _Tuple node with its children
            let base = stack.count
            nestedTuple._collectElements(into: &stack)
            // Reverse the newly appended segment so first child is on top
            stack[base...].reverse()
        } else {
            // Leaf element: render via the existing dispatch pipeline
            renderInnerContent(next, context: &context)
        }
    }
}
```

**Call site changes**:

```swift
// PDF.HTML.swift:520–523 (renderHTMLView)
if let tuple = view as? any _TupleContent {
    renderTupleIteratively(tuple, context: &context)
    return
}

// PDF.HTML.swift:1104–1107 (renderInnerContent)
if let tuple = value as? any _TupleContent {
    renderTupleIteratively(tuple, context: &context)
    return
}
```

| Property | Value |
|---|---|
| Stack depth after fix | O(1) for `_Tuple` rendering (constant, independent of element count) |
| Heap cost | One `[Any]` array: 32 bytes × N elements (existential container). For 100 elements: 3.2 KB |
| Protocol changes | One new method on package-visible `_TupleContent` |
| Affected conformers | 1 (`Rendering._Tuple` in `_Tuple+Transform.swift`) |
| Implementation complexity | Low — 30 lines of new code |
| Phase 1 Mirror safety | Preserved — no changes to wrapper detection |
| Static path impact | None — `repeat render(each)` path untouched |
| Rendering order | Preserved — LIFO stack with reversed children ensures left-to-right |
| Context threading | Preserved — `renderInnerContent` passes `context` as `inout`, elements rendered sequentially |

---

### Option B: Mirror-Only Flattening (Zero Protocol Changes)

Instead of adding `_collectElements` to the protocol, extract `_Tuple` elements via Mirror reflection on the `content` tuple field.

**Mechanism**: `_Tuple<each Content>` has a single stored property `content: (repeat each Content)`. When reflected, Mirror shows one child with label `"content"` whose value is a Swift tuple. Reflecting that tuple yields its elements as children.

```swift
static func renderTupleIteratively(
    _ view: Any,
    context: inout PDF.HTML.Context
) {
    var stack: [Any] = [view]

    while let next = stack.popLast() {
        if next is any _TupleContent {
            // Extract elements via Mirror on the content tuple
            let mirror = Mirror(reflecting: next)
            for child in mirror.children {
                if child.label == "content" {
                    let contentMirror = Mirror(reflecting: child.value)
                    let base = stack.count
                    for element in contentMirror.children {
                        stack.append(element.value)
                    }
                    stack[base...].reverse()
                    break
                }
            }
        } else {
            renderInnerContent(next, context: &context)
        }
    }
}
```

| Property | Value |
|---|---|
| Stack depth after fix | O(1) |
| Heap cost | Same as Option A, plus Mirror overhead per `_Tuple` node |
| Protocol changes | None |
| Implementation complexity | Low — self-contained in `PDF.HTML.swift` |
| Reliability | Depends on Mirror internals — `_Tuple`'s field name `"content"` and tuple displayStyle |
| Performance | Slower than Option A — creates 2 Mirror instances per `_Tuple` node (one for the struct, one for the content tuple), vs. zero reflection in Option A |

**Concern**: The field name `"content"` is also used by `HTML.Styled` and `HTML._Attributes`. While these are already filtered by Phase 1 before reaching the `_TupleContent` check, relying on Mirror internals for element extraction is fragile. A future type with a `"content"` tuple field could be misidentified.

---

### Option C: Trampoline / Continuation-Passing

Replace the recursive `renderHTMLView` call with a trampoline that returns work items instead of calling recursively.

**Mechanism**: `_renderEachElementDynamically` would return `[Any]` (the elements to render) instead of rendering them inline. A top-level loop drives the rendering:

```swift
enum RenderAction {
    case render(Any)
    case expandTuple(any _TupleContent)
}

static func renderHTMLViewIterative(_ view: some HTML.View, context: inout PDF.HTML.Context) {
    var worklist: [RenderAction] = [.render(view)]
    while let action = worklist.popFirst() {
        switch action {
        case .render(let v):
            // Phase 1 + Phase 2, but instead of recursing,
            // push RenderActions onto worklist
            ...
        case .expandTuple(let tuple):
            // Insert tuple's elements at front of worklist
            ...
        }
    }
}
```

| Property | Value |
|---|---|
| Stack depth after fix | O(1) for ALL recursion (not just `_Tuple`) |
| Heap cost | Higher — every rendering action goes through the worklist |
| Protocol changes | Significant — the entire dispatch engine is restructured |
| Implementation complexity | High — complete rewrite of `renderHTMLView` |
| Risk | Very high — must replicate all Phase 1 and Phase 2 logic in the trampoline |

**Assessment**: A full trampoline eliminates all recursion, not just `_Tuple` recursion. This is maximally safe but requires rewriting the 120-line `renderHTMLView` and 100-line `renderInnerContent` functions. The non-`_Tuple` recursion (custom view `.body`, `_Conditional` branches, `_Optional` unwrapping) adds at most 2–3 frames per level and is bounded by the logical view hierarchy depth (typically 5–10), not by element count. The engineering cost is disproportionate to the problem.

---

### Option D: Explicit Worklist with Primitives Infrastructure

Use `Stack` or `Queue.DoubleEnded` from `swift-stack-primitives` / `swift-queue-primitives` instead of `[Any]`.

**Finding from investigation**: Stack primitives use concrete type parameters (`Stack<Element: ~Copyable>`) and cannot hold heterogeneous `Any` values. `Machine.Value<Mode>` from `swift-machine-primitives` provides type-erased storage but is designed for defunctionalized parser combinators, not tree traversal.

| Property | Value |
|---|---|
| Stack depth after fix | O(1) |
| Heap cost | Similar to `[Any]`, but with small-buffer optimization via `Stack.Small` |
| Protocol changes | Same as Option A (need `_collectElements`) |
| Implementation complexity | Medium — requires type-erased wrapper around elements to use Stack |
| New dependency | `swift-pdf-html-rendering` would need to depend on `swift-stack-primitives` |

**Assessment**: The core algorithm is the same as Option A, but with `Stack<AnyElement>` instead of `[Any]`. The new dependency adds build complexity for minimal benefit — Swift's `Array<Any>` already provides dynamic resizing and contiguous storage. The small-buffer optimization from `Stack.Small` would save one heap allocation for shallow trees (< K elements inline), but the `_Tuple` worklist is typically small (< 20 elements) and the allocation is amortized.

---

### Option E: Machine-Based Rendering

Model the dispatch engine as a `Machine` from `swift-machine-primitives`, with states for each dispatch phase and transitions replacing function calls.

**Assessment**: Over-engineering. The machine primitives are designed for parser combinator programs with defunctionalized closures, backtracking, and choice points. The rendering dispatch is a simple tree walk with sequential state mutation. A state machine abstraction would obscure the logic without solving the core problem (deep recursion).

---

### Option F: Thread-Based Workaround

Use `Thread(stackSize: 2_097_152)` to run the rendering pipeline on a thread with 2 MB stack.

```swift
public static func pages<H: PDF.HTML.View>(
    configuration: PDF.HTML.Configuration = .init(),
    @HTML.Builder html: () -> H
) -> [PDF.Page] {
    var result: [PDF.Page] = []
    let thread = Thread {
        result = _renderPages(configuration: configuration, html: html)
    }
    thread.stackSize = 2 * 1024 * 1024
    thread.start()
    // ... synchronize
    return result
}
```

| Property | Value |
|---|---|
| Stack depth after fix | Unchanged (still O(N) recursive) |
| Stack budget | ~2 MB → sufficient for ~2000+ elements |
| Protocol changes | None |
| Implementation complexity | Medium — thread synchronization, `@Sendable` constraints |
| Portability | Thread API varies by platform; `stackSize` behavior is implementation-defined |
| Root cause | NOT fixed — just increases the limit |

**Assessment**: This masks the symptom without fixing the root cause. The rendering pipeline is still O(N) stack depth; a sufficiently deep view tree would still crash. Thread synchronization adds complexity and potential for concurrency bugs. Not recommended as a primary solution, but could serve as a temporary mitigation while the iterative fix is implemented.

---

### Option G: Hybrid — Iterative Only for Dynamic Path

Keep the static dispatch path (`repeat render(each)`) untouched. Only make the dynamic dispatch path (`_renderEachElementDynamically` → `renderHTMLView`) iterative.

**This is what Option A implements.** The static path uses compile-time pack expansion and never recurses through the central dispatcher. The dynamic path is the only recursive bottleneck. Option A's `renderTupleIteratively` replaces only the dynamic path.

### Comparison

| Criterion | A: Protocol Method | B: Mirror-Only | C: Trampoline | D: Stack Primitives | E: Machine | F: Thread | G: Hybrid |
|---|---|---|---|---|---|---|---|
| Fixes root cause | Yes | Yes | Yes | Yes | Yes | No | = A |
| Stack depth | O(1) | O(1) | O(1) | O(1) | O(1) | O(N) still | O(1) |
| Protocol changes | 1 method | None | Major | 1 method | Major | None | 1 method |
| New dependencies | None | None | None | stack-primitives | machine-primitives | None | None |
| Implementation size | ~30 lines | ~25 lines | ~200+ lines | ~40 lines | ~300+ lines | ~20 lines | = A |
| Performance vs current | Comparable | Slower (Mirror) | Comparable | Comparable | Unknown | Comparable | Comparable |
| Risk | Low | Medium (Mirror) | High (rewrite) | Low | High | Medium | Low |
| Preserves static path | Yes | Yes | N/A (replaces) | Yes | N/A | Yes | Yes |
| Cross-protocol pattern | Yes | No (PDF.HTML-specific) | No | Yes | No | No | Yes |

## Outcome

**Status**: RECOMMENDATION

**Recommended approach**: **Option A** — add `_collectElements(into:)` to `_TupleContent` protocol + iterative rendering helper `renderTupleIteratively` at both call sites.

### Rationale

1. **Minimal change**: 1 new protocol method, 1 new conformance method, 1 new helper function, 2 call site changes. Total: ~30 lines of new code.

2. **Type-safe element extraction**: Uses variadic pack expansion (`repeat collect(each content)`) instead of Mirror reflection. The compiler enumerates elements; no runtime reflection overhead or field-name dependencies.

3. **Follows existing pattern**: Mirrors the `renderFlattenedStyledContent` approach (`PDF.HTML.swift:577–748`) which already solves the same problem for `HTML.Styled` wrappers. The team is familiar with this iterative flattening pattern.

4. **Safe `as?` cast for nested detection**: `_Tuple` types are safe to cast via `as? any _TupleContent` even when deeply nested. The SIGBUS crashes from `as?` only affect wrapper types (`Styled`, `CSS`, `Attributes`) with deeply nested generic parameters, not `_Tuple` whose nesting is structural (type parameters are `_Tuple` nodes, not wrapper layers). The existing code at `PDF.HTML.swift:520` already relies on this cast working.

5. **Zero impact on static path**: The `repeat render(each view.content)` path in `_Tuple+Transform.swift:10–21` (and equivalent paths in `_Tuple+PDF.View.swift`, `_Tuple+HTML.swift`, `SVG._Tuple.swift`) is completely untouched.

6. **O(1) stack, O(N) heap**: Stack depth for `_Tuple` rendering becomes constant. Heap cost is one `[Any]` array sized to N elements (32 bytes per existential container). For typical view trees (10–100 elements): 320 bytes – 3.2 KB. The dynamic dispatch path already pays the cost of existential boxing via `as? any _TupleContent`.

### Alternatives Rejected

- **Option B** (Mirror-only): Fragile dependency on `"content"` field name and tuple displayStyle. Slower due to double Mirror reflection per `_Tuple` node. No protocol changes is appealing but not worth the fragility.
- **Option C** (Trampoline): Solves a broader problem (all recursion) that doesn't need solving — non-`_Tuple` recursion is bounded by logical view hierarchy depth (5–10 levels, ~5 KB). The 200+ line rewrite risk is not justified.
- **Option D** (Stack primitives): Same algorithm as Option A with an unnecessary dependency. `[Any]` is sufficient.
- **Option F** (Thread): Masks the symptom. Not a fix.

## Affected Files

| File | Lines | Change |
|---|---|---|
| `swift-pdf-html-rendering/.../PDF.HTML.swift` | 520–523 | Replace `_renderEachElementDynamically` call with `renderTupleIteratively` |
| `swift-pdf-html-rendering/.../PDF.HTML.swift` | 1104–1107 | Same replacement in `renderInnerContent` |
| `swift-pdf-html-rendering/.../PDF.HTML.swift` | 1292–1295 | Add `_collectElements(into:)` to `_TupleContent` protocol |
| `swift-pdf-html-rendering/.../PDF.HTML.swift` | new (after 1295) | Add `renderTupleIteratively` helper function |
| `swift-pdf-html-rendering/.../_Tuple+Transform.swift` | 25–32 | Add `_collectElements(into:)` conformance |

Total: 2 files modified, ~30 lines added.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Rendering order change | Low | High | LIFO stack with reversed children preserves left-to-right order. Verify with existing PDF test suite. |
| Context mutation ordering | Low | High | `renderInnerContent` is called sequentially for each leaf — same `inout` threading as before. |
| `as? any _TupleContent` fails for deeply nested `_Tuple` | Very low | Medium | Already used at `PDF.HTML.swift:520` without issues. `_Tuple` nesting is structural, not wrapper-generic nesting. If a future Swift runtime change breaks this, the existing code would break too. |
| Performance regression from `[Any]` allocation | Very low | Low | One array allocation per `_Tuple` tree. Amortized over the full rendering pass (which already does extensive Mirror reflection, PDF operator emission, etc.), this is negligible. |
| Existing `_renderEachElementDynamically` becomes dead code | None | None | Can be removed or kept for backward compatibility. `_TupleContent` is package-visible with 1 conformer — removal is safe. |

## Migration Plan

### Minimal Viable Change (Single Commit)

The fix is self-contained and can be implemented in a single commit:

1. Add `_collectElements(into:)` to `_TupleContent` protocol in `PDF.HTML.swift`
2. Add conformance in `_Tuple+Transform.swift`
3. Add `renderTupleIteratively` helper in `PDF.HTML.swift`
4. Replace both call sites (`renderHTMLView:520`, `renderInnerContent:1104`)
5. Run existing PDF test suite to verify rendering output is identical
6. Add a dedicated test with a 100-element view body to confirm no stack overflow under Swift Testing

### Optional Follow-Up

- Remove `_renderEachElementDynamically` from the protocol and conformance if no other callers exist
- Add the same pattern to other rendering protocols if they ever develop central dispatchers
- Consider adding `_collectElements` to `Rendering._Tuple` at the primitives layer (in `swift-rendering-primitives`) if multiple rendering packages need the same capability — currently unnecessary since only `PDF.HTML` has dynamic dispatch

## References

- `swift-pdf-html-rendering/.../PDF.HTML.swift` — central dispatch engine
- `swift-pdf-html-rendering/.../_Tuple+Transform.swift` — `_TupleContent` conformance
- `swift-rendering-primitives/.../Rendering._Tuple.swift` — type definition
- `swift-rendering-primitives/.../Rendering.Builder.swift` — `buildPartialBlock` producing binary nesting
- `swift-rendering-primitives/Experiments/result-builder-stack-overflow-html/` — HTML-only stack experiment
- `swift-pdf/Experiments/result-builder-stack-overflow/` — full PDF pipeline stack experiment
- `renderFlattenedStyledContent` (`PDF.HTML.swift:577–748`) — existing iterative pattern for `HTML.Styled`
