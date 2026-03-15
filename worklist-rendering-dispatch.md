# Worklist Rendering Dispatch

<!--
---
version: 4.0.0
last_updated: 2026-03-13
status: SUPERSEDED
tier: 2
supersedes: swift-foundations/swift-pdf-html-rendering/Research/iterative-tuple-rendering.md (partially — retains tuple analysis, replaces solution)
collaborative_discussion: Claude Round 3 + ChatGPT Round 3 — CONVERGED
---
-->

> **Update 2026-03-13**: The worklist interpreter (Cause 3) was superseded by the
> `Rendering.Context` pure static dispatch architecture (commit `40ca61d`). That
> redesign reintroduced SIGBUS via a **fourth** cause: `buildFinalResult` in
> `swift-markdown-html-rendering`'s `HTML.Builder.swift` used `HTML.AnyView { component }`
> (the `@HTML.Builder` closure init), re-entering the result builder in an infinite
> cycle (875 repetitions, 2672 frames). Fixed in commit `bc5798b` by using the direct
> `init(_ base: any HTML.View)` instead.

## Context

The PDF HTML rendering pipeline (`swift-pdf-html-rendering`) crashes with SIGBUS (`___chkstk_darwin`) when rendering moderately nested view trees under Swift Testing's ~64KB async task stack. Four independent stack overflow causes were discovered:

1. **FIXED** (committed `16ce688` in swift-primitives) — `as?` conformance checking recursion on deeply nested `_Tuple` → unconditional `_TupleMarker` protocol
2. **FIXED** (committed `16ce688` in swift-primitives) — Swift runtime type metadata demangling recursion → removed `buildPartialBlock(accumulated:next:)`
3. **SUPERSEDED** (committed `e7bd156` in swift-foundations) — General rendering pipeline stack depth from mutual recursion → worklist interpreter — superseded by `Rendering.Context` static dispatch (`40ca61d`)
4. **FIXED** (committed `bc5798b` in swift-markdown-html-rendering) — `buildFinalResult` infinite recursion: `HTML.AnyView { component }` re-enters the `@HTML.Builder` → infinite cycle

Causes 1+2 are addressed in `swift-foundations/swift-pdf-html-rendering/Research/iterative-tuple-rendering.md`. This document addresses Cause 3. Cause 4 is documented inline above.

### The Remaining Problem

The rendering engine (`renderHTMLView` ↔ `renderInnerContent`) is a **mutual-recursion tree-walking interpreter**. Each custom view nesting level adds 3–4 stack frames. Wrapper types (Styled, CSS, _Attributes, _Conditional, Optional) add 2–3 frames each. These compound multiplicatively. For `ComplexView → TableDemo → CSS(Styled(Tag))`:

```
renderHTMLView(ComplexView)           ┐
  renderBody [inner func]             │ view→body chain: 2 frames per custom view
  renderHTMLView(_Tuple)              ┘
    renderTupleIteratively
    renderInnerContent(TableDemo)     ┐
    _renderInnerWrapperIfDetected     │ view→body chain: 3 frames per custom view
    renderBody [inner func]           │
    renderHTMLView(_Tuple)            ┘
      renderTupleIteratively
      renderInnerContent(CSS(…))
      _renderInnerWrapperIfDetected   ┐
      renderCSSWrapperViaMirror       │ wrapper chain: 2–3 frames per wrapper layer
      renderStyledViaMirror           │
      renderInnerContent(Tag)         ┘
      _renderInnerWrapperIfDetected
      Tag._render
      applyTagStyle → ___chkstk_darwin CRASH
```

### Architectural Root Cause

`renderHTMLView` (`PDF.HTML.swift:439–500`) and `renderInnerContent` (`PDF.HTML.swift:1023–1089`) are **near-duplicate dispatchers** with the same structure:

```
Phase 0: _TupleMarker → renderTupleIteratively  (already iterative)
Phase 1: Mirror → renderStyledViaMirror, renderCSSWrapperViaMirror, etc.
Phase 2: as? → V._render, _renderElementDynamically, etc.
Fallback: custom HTML.View → renderHTMLView(v.body)  (RECURSIVE)
```

Six separate `renderXxxViaMirror` functions each recursively call `renderInnerContent`. A separate `renderTupleIteratively` uses an ad-hoc `[Any]` stack. The view→body fallback recurses through `renderHTMLView`. All three recursion axes compound.

### Pre-Existing Bug: _Attributes Discarded in Dynamic Path

`renderAttributesViaMirror` (`PDF.HTML.swift:1164`) discards HTML attributes with the comment: "ignore 'attributes' — not relevant for PDF." This is **factually wrong**. `Tag._render` reads `context.attributes["href"]` (line 73), `context.attributes["id"]` (line 85), and table cells read `colspan`/`rowspan`. The static dispatch path (`HTML._Attributes+PDF.HTML.View.swift:30–98`) correctly scopes attributes: save → merge → render content → restore via `defer`. The dynamic path discards them entirely. Links, internal anchors, and table cell spanning are broken in the `@_disfavoredOverload` dynamic dispatch path. This semantic bug is fixed as part of the worklist implementation (see `.restoreAttributes` case).

### Ad-Hoc Infrastructure in Current Code

| Location | Ad-hoc pattern | Primitives replacement |
|---|---|---|
| `renderTupleIteratively` | `var stack: [Any] = []` with `popLast`/`append` | `Stack<Dispatch>` from `swift-stack-primitives` |
| `renderFlattenedStyledContent` | `var styledLayers: [any _HTMLStyledContent] = []` | Inline peeling within worklist loop |
| `renderHTMLView ↔ renderInnerContent` | Mutual recursion | Single `Stack<Dispatch>` dispatch loop |
| `renderCSSWrapperViaMirror` | Recursive `renderInnerContent` call | Push `.render(base)` onto worklist |
| `renderConditionalViaMirror` | Recursive `renderInnerContent` call | Push `.render(activeCase)` onto worklist |
| `renderOptionalViaMirror` | Recursive `renderInnerContent` call | Push `.render(someValue)` onto worklist |
| `renderAttributesViaMirror` | Recursive `renderInnerContent` call + **attribute loss** | Push `.restoreAttributes` + `.render(content)` |

## Question

How should the rendering dispatch be restructured to eliminate stack overflow from recursive frame accumulation, composing from existing primitives (`Stack` from `swift-stack-primitives`, iterative traversal pattern from `swift-tree-primitives`) rather than ad-hoc mechanisms?

## Analysis

### Why Machine Is Wrong

`Machine` from `swift-machine-primitives` was evaluated and rejected:

| Aspect | Machine | Rendering dispatch |
|---|---|---|
| Input model | Borrowed cursor over input stream | View tree discovered dynamically via Mirror + `as?` |
| Output model | `Value<Mode>` (functional return) | Side effects on `inout PDF.HTML.Context` |
| Program structure | Static graph built at init time | Dynamic — tree structure unknown until traversal |
| Branching model | `oneOf` with backtracking + checkpoint restore | Deterministic — no ambiguity |
| Closure handling | Defunctionalized via `Capture.Store` (solves `~Escapable`) | Not needed |

Machine is a **parser interpreter** (consume input → produce values → backtrack on failure). Rendering is a **tree-walking interpreter** (traverse tree → mutate context → emit output). The execution models are fundamentally different. Machine's core innovations — backtracking, capture defunctionalization, value arena, memoization — are parsing-specific overhead with no rendering analog.

### Why Tree-Primitives Pattern Is Right

`Tree.N` in `swift-tree-primitives` solves the identical structural problem — deep tree traversal without stack overflow — using `Stack` worklists:

| Traversal | Pattern | Rendering analog |
|---|---|---|
| `forEachPreOrder` | `Stack` + push children reversed → DFS | Push child views onto worklist |
| `forEachPostOrder` | `Stack` + `peek` + `lastVisited` → post-visit action | Style/attribute save/restore (`defer` equivalent) |
| `removeSubtree` | Post-order with cleanup action (`_arena.free`) | Restore context state after children render |

The rendering pipeline needs a **mixed pre/post traversal**: pre-visit (apply styles, merge attributes), process children, post-visit (restore styles/attributes via `defer`). This maps to the `removeSubtree` pattern: push a restore item, then push children. LIFO ordering ensures restore fires after children.

### Reachability Analysis

**`renderFlattenedStyledContent`** is NOT reachable from the dynamic dispatch path. Phase 1 Mirror catches all Styled types via `isStyledType(mirror)` → `renderStyledViaMirror` BEFORE Phase 2's `as?` casts. `renderFlattenedStyledContent` is only reached through the static dispatch path when `HTML.Styled._render` is called with static type knowledge. It does call `renderHTMLView` at the end (via `renderWrappedContent`, line 216), but that re-entry has static type knowledge and immediately matches Phase 2, adding minimal frames. No absorption needed.

**`_renderElementDynamically`** (`HTML.Element+PDF.HTML.View.swift:1396`) is the dynamic-dispatch counterpart of `Tag._render`. It calls `renderBlockDynamic` → `renderHTMLView`, creating a NEW worklist instance at each Tag element nesting boundary. This is the only remaining source of dynamic re-entry after the worklist is implemented.

### Solution: Worklist Interpreter

Replace the mutual recursion with a **defunctionalized worklist** using `Stack<Dispatch>` from `swift-stack-primitives`.

#### Dispatch Defunctionalization

Each recursive call becomes a work item. Each `defer { restore }` becomes a restore item pushed BEFORE content (LIFO ensures restore fires AFTER content renders):

```swift
/// Defunctionalized dispatch continuations.
///
/// Each case is an instruction to the dispatch loop. The rendering pipeline's
/// recursive calls are replaced by work items on an explicit worklist,
/// following the `Tree.N.forEachPreOrder` pattern from `swift-tree-primitives`:
/// push children in reverse order onto a `Stack`, process iteratively.
///
/// Style/attribute save/restore follows the `Tree.N.removeSubtree` pattern:
/// push `.restoreStyle`/`.restoreAttributes` before `.render(content)`.
/// LIFO ordering guarantees content renders first, then the restore fires —
/// equivalent to `defer`.
private enum Dispatch {
    /// Process a value through the type detection pipeline.
    ///
    /// Replaces recursive calls to `renderHTMLView` and `renderInnerContent`.
    case render(Any)

    /// Post-visit: restore style state after children have rendered.
    ///
    /// Equivalent of `defer { context.pdf.style = saved }` in `renderStyledViaMirror`.
    /// Pushed BEFORE `.render(content)` — LIFO ensures content renders first.
    case restoreStyle(PDF.Context.Style)

    /// Post-visit: restore attribute scope after children have rendered.
    ///
    /// Fixes the pre-existing bug where `renderAttributesViaMirror` discards HTML
    /// attributes that `Tag._render` reads (href, id, colspan, rowspan).
    /// Reproduces the static path's save/merge/render/restore semantics.
    case restoreAttributes(Dictionary<String, String>.Ordered)
}
```

**Naming rationale** ([API-NAME-001], [API-NAME-002]):
- `Dispatch` — names the domain operation (defunctionalized dispatch continuations). Scoped as `PDF.HTML.Dispatch`. Not `RenderWorkItem` (compound, violates [API-NAME-001]) or `Work` (too generic).
- `.render(Any)` — instruction: "render this value through type classification."
- `.restoreStyle(...)` — instruction: "restore this style state."
- `.restoreAttributes(...)` — instruction: "restore this attribute scope."
- Cases are parallel in structure: each names what the dispatch loop does with the payload.

#### The Dispatch Loop

```swift
extension PDF.HTML {
    /// Iterative dispatch loop for the dynamic rendering pipeline.
    ///
    /// Replaces the mutual recursion between `renderHTMLView` and
    /// `renderInnerContent` with a single `Stack<Dispatch>` worklist,
    /// following the `Tree.N.forEachPreOrder` pattern from `swift-tree-primitives`.
    ///
    /// ## What becomes iterative
    ///
    /// | Recursion axis | Mechanism |
    /// |---|---|
    /// | Custom view body chain (`A → A.body → B → B.body`) | `.render(body)` pushed, loop continues |
    /// | Tuple children | Children pushed as `.render` items (absorbs `renderTupleIteratively`) |
    /// | CSS wrapper unwrapping | Extract base, push `.render(base)` |
    /// | `_Attributes` wrapper unwrapping | Save/merge/push `.restoreAttributes` + `.render(content)` |
    /// | `_Conditional` case extraction | Extract active case, push `.render(case)` |
    /// | `Optional` unwrapping | Extract `.some` value, push `.render(someValue)` |
    /// | Styled layer peeling | Save style, peel layers, push `.restoreStyle` then `.render(unwrapped)` |
    ///
    /// ## What stays recursive (bounded)
    ///
    /// `Tag._render` and `_renderElementDynamically` are **terminal operations** from
    /// the worklist's perspective. They handle their own children with their own `defer`
    /// blocks. When they call `renderBlockDynamic` → `renderHTMLView`, a new worklist
    /// instance is created. This re-entry is bounded by HTML Tag element nesting depth,
    /// not by wrapper-chain depth or custom-view body expansion.
    ///
    /// This is the correct architectural boundary:
    /// - **Worklist** handles the dispatch layer (type detection, wrapper unwrapping, body resolution)
    /// - **`V._render`** handles the rendering layer (PDF operators, layout, pagination)
    private static func iterativeDispatch(
        _ initial: Any,
        context: inout PDF.HTML.Context
    ) {
        var worklist = Stack<Dispatch>()
        worklist.push(.render(initial))

        while let item = worklist.pop() {
            switch item {
            case .restoreStyle(let saved):
                context.pdf.style = saved

            case .restoreAttributes(let saved):
                context.attributes = saved

            case .render(let value):
                // Phase 0: Tuple — push children (absorbs renderTupleIteratively)
                if let tuple = value as? any Rendering._TupleMarker {
                    var elements: [Any] = []
                    tuple._collectElements(into: &elements)
                    // Push reversed for left-to-right processing (LIFO)
                    for element in elements.reversed() {
                        worklist.push(.render(element))
                    }
                    continue
                }

                // Phase 1: Mirror-based wrapper detection
                //
                // Mirror is allocated in this scope and freed at the end of
                // the switch case — before the next iteration. This replaces
                // the @inline(never) extraction functions (_renderWrapperIfDetected,
                // _renderInnerWrapperIfDetected) which existed solely to free
                // Mirror stack space before recursive calls.
                let mirror = Mirror(reflecting: value)

                if isStyledType(mirror) {
                    let savedStyle = context.pdf.style

                    // Peel consecutive Styled layers iteratively (same as
                    // current renderStyledViaMirror's while loop)
                    var current = value
                    while true {
                        let m = Mirror(reflecting: current)
                        guard isStyledType(m) else { break }

                        var content: Any?
                        var property: Any?
                        for child in m.children {
                            switch child.label {
                            case "content": content = child.value
                            case "property": property = child.value
                            default: break
                            }
                        }

                        if let prop = property {
                            applyStylePropertyViaMirror(prop, context: &context)
                        }

                        guard let c = content else { break }
                        current = c
                    }

                    // Post-visit: push restore BEFORE content (LIFO)
                    worklist.push(.restoreStyle(savedStyle))
                    worklist.push(.render(current))
                    continue
                }

                if isCSSWrapperType(mirror) {
                    for child in mirror.children {
                        if child.label == "base" {
                            worklist.push(.render(child.value))
                            break
                        }
                    }
                    continue
                }

                if isAttributesType(mirror) {
                    let savedAttributes = context.attributes

                    // Peel consecutive _Attributes layers iteratively,
                    // merging attributes at each layer. Reproduces the
                    // static path's save/merge/render/restore semantics.
                    var current = value
                    while true {
                        let m = Mirror(reflecting: current)
                        guard isAttributesType(m) else { break }

                        var contentValue: Any?
                        for child in m.children {
                            if child.label == "attributes",
                               let attrs = child.value as? [String: String] {
                                context.attributes.merge.keep.last(
                                    attrs.lazy.map { ($0.key, $0.value) }
                                )
                            }
                            if child.label == "content" {
                                contentValue = child.value
                            }
                        }

                        guard let c = contentValue else { break }
                        current = c
                    }

                    // Post-visit: push restore BEFORE content (LIFO)
                    worklist.push(.restoreAttributes(savedAttributes))
                    worklist.push(.render(current))
                    continue
                }

                if isConditionalType(mirror) {
                    for child in mirror.children {
                        if child.label == "first" || child.label == "second" {
                            worklist.push(.render(child.value))
                            break
                        }
                    }
                    continue
                }

                if isOptionalType(mirror) {
                    for child in mirror.children {
                        if child.label == "some" {
                            worklist.push(.render(child.value))
                            break
                        }
                    }
                    continue // .none → nothing pushed → nothing rendered
                }

                // Phase 2: as? casts (safe — wrappers filtered by Phase 1)
                //
                // These are terminal operations — they call _render directly.
                // No worklist push needed.

                if let str = value as? String {
                    String._render(str, context: &context)
                    continue
                }

                if let anyView = value as? any _AnyViewContent {
                    anyView._renderAnyViewDynamically(context: &context)
                    continue
                }

                if let pdfView = value as? any PDF.HTML.View {
                    func render<V: PDF.HTML.View>(_ v: V) {
                        V._render(v, context: &context)
                    }
                    render(pdfView)
                    continue
                }

                if let element = value as? any _HTMLElementContent {
                    element._renderElementDynamically(context: &context)
                    continue
                }

                if value is any _HTMLRawContent {
                    continue
                }

                if let optional = value as? any _OptionalContent {
                    optional._renderOptionalDynamically(context: &context)
                    continue
                }

                if let conditional = value as? any _ConditionalContent {
                    conditional._renderConditionalDynamically(context: &context)
                    continue
                }

                if let array = value as? any _ArrayContent {
                    array._renderArrayDynamically(context: &context)
                    continue
                }

                // Fallback: custom HTML.View — push body (LOOP, not recurse)
                if let htmlView = value as? any HTML.View {
                    func pushBody<V: HTML.View>(_ v: V) {
                        worklist.push(.render(v.body as Any))
                    }
                    pushBody(htmlView)
                    continue
                }
            }
        }
    }
}
```

#### Public API (Thin Wrappers)

```swift
extension PDF.HTML {
    /// Dynamic dispatch entry point for rendering arbitrary HTML.View types.
    ///
    /// Delegates to `iterativeDispatch` — the worklist-based interpreter.
    /// The public signature is preserved for backward compatibility.
    public static func renderHTMLView(
        _ view: some HTML.View,
        context: inout PDF.HTML.Context
    ) {
        iterativeDispatch(view, context: &context)
    }

    /// Dynamic dispatch for type-erased values extracted from Mirror children.
    ///
    /// Delegates to `iterativeDispatch` — same loop, same dispatch logic.
    static func renderInnerContent(
        _ value: Any,
        context: inout PDF.HTML.Context
    ) {
        iterativeDispatch(value, context: &context)
    }
}
```

#### Structural Boundedness Claim

This change eliminates recursive mutual dispatch across wrapper layers and custom-view body expansion in the dynamic rendering path. Remaining dynamic re-entry occurs at Tag element nesting boundaries via `_renderElementDynamically` → `renderBlockDynamic` → `renderHTMLView` → new `iterativeDispatch` instance, and is therefore bounded by HTML document depth rather than wrapper-chain depth.

## Outcome

**Status**: IMPLEMENTED (committed `e7bd156` in swift-foundations, 2026-03-12)

### Acceptance Criteria — All Met

1. ✅ Wrapper-layer recursion between `renderHTMLView` and `renderInnerContent` is eliminated
2. ✅ Tuple flattening is absorbed into the worklist
3. ✅ Style state from Styled wrapper processing is restored explicitly via `.restoreStyle`
4. ✅ Attribute state from `_Attributes` wrapper processing is restored explicitly via `.restoreAttributes`, fixing the dynamic path's attribute loss
5. ✅ The crashing test (`"document showing all elements"`) passes
6. ✅ All 84 tests pass (3 pre-existing `breakAfter` failures were separately fixed)

### Implementation Note

The `restoreStyle` case uses `ISO_32000.Context.Style.Resolved` (not `PDF.Context.Style` as in the plan). This is the actual type of `context.pdf.style`.

### Implementation Steps

#### Step 1: Add `swift-stack-primitives` dependency

Add `swift-stack-primitives` to `swift-pdf-html-rendering/Package.swift`. This is a Layer 1 → Layer 3 dependency (architecturally correct per [ARCH-LAYER-001]).

#### Step 2: Define `Dispatch` enum

Private enum in `PDF.HTML.swift` with three cases: `.render(Any)`, `.restoreStyle(PDF.Context.Style)`, `.restoreAttributes(Dictionary<String, String>.Ordered)`.

#### Step 3: Implement `iterativeDispatch`

Single function replacing `renderHTMLView`, `renderInnerContent`, `renderTupleIteratively`, and all six `renderXxxViaMirror` wrapper functions. Uses `Stack<Dispatch>` from `swift-stack-primitives`.

#### Step 4: Reduce `renderHTMLView` and `renderInnerContent` to thin wrappers

Both delegate to `iterativeDispatch`. Public API preserved.

#### Step 5: Remove dead code

| Function | Disposition |
|---|---|
| `renderTupleIteratively` | Absorbed into worklist loop |
| `_renderWrapperIfDetected` | Absorbed into worklist loop (Mirror detection inline) |
| `_renderInnerWrapperIfDetected` | Absorbed into worklist loop |
| `renderCSSWrapperViaMirror` | Absorbed into worklist loop |
| `renderConditionalViaMirror` | Absorbed into worklist loop |
| `renderOptionalViaMirror` | Absorbed into worklist loop |
| `renderAttributesViaMirror` | Absorbed into worklist loop (attribute merge + restore replaces discard) |
| `renderStyledViaMirror` | Absorbed into worklist loop (Styled peeling inline) |

**Preserved** (called from worklist but not absorbed):
- `applyStylePropertyViaMirror` — leaf operation, no recursion
- `isStyledType`, `isCSSWrapperType`, `isAttributesType`, `isConditionalType`, `isOptionalType` — pure predicates
- `renderFlattenedStyledContent` — protocol-based path (static dispatch only, not reachable from dynamic path)
- `Tag._render` / `_renderElementDynamically` — terminal operations, handle own children via `defer`

#### Step 6: Instrument and validate

1. `swift test` in `swift-pdf-html-rendering` — all existing tests must pass
2. `swift test --filter "document showing all elements"` — the crashing test must pass
3. `swift test --filter "IterativeTuple"` — tuple iteration tests must pass
4. Add temporary instrumentation around `iterativeDispatch` entry and `_renderElementDynamically` re-entry to measure observed nesting depth
5. Report observed measurements, replacing speculative estimates

### Dependency Changes

```
swift-pdf-html-rendering
  └─ (new) swift-stack-primitives    // Stack<Dispatch> for worklist
```

### Future Follow-Up (Not Part of This Work)

**Absorb `_renderElementDynamically`**: Could eliminate Tag element re-entry by adding 6 restore cases to the `Dispatch` enum (style, llx, urx, preserveWhitespace, linkURL, internalLinkId). This would make ALL dynamic dispatch fully iterative. Deferred because it substantially widens the refactor surface and should be justified by measurement showing Tag nesting depth is still problematic after the wrapper/body recursion elimination.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Rendering order change | Low | High | LIFO worklist with reversed children preserves left-to-right order. Verified by existing PDF test suite. |
| Style restore ordering | Low | High | `.restoreStyle` pushed before `.render` — LIFO guarantees restore after content. Same semantics as `defer`. |
| Attribute restore ordering | Low | High | `.restoreAttributes` pushed before `.render` — same LIFO guarantee as style restore. |
| Mirror lifetime | Very low | Low | Mirror created in `case .render` scope, freed at case boundary — before next iteration. |
| `Stack<Dispatch>` allocation | Very low | Low | One stack per `iterativeDispatch` call. Amortized over the full rendering pass. |
| Phase 2 `as?` cast ordering | Low | Medium | Unified ordering from `renderHTMLView` (more defensive — checks special types first). Both paths now go through same loop. |
| Attribute merge fidelity | Low | Medium | Dynamic merge uses same `context.attributes.merge.keep.last` API as static path. Save/restore uses `Dictionary<String, String>.Ordered` — exact same type as `context.attributes`. |

## Affected Files

| File | Change |
|---|---|
| `swift-pdf-html-rendering/Package.swift` | Add `swift-stack-primitives` dependency |
| `PDF.HTML.swift` | Replace mutual recursion with `iterativeDispatch` loop; remove 8 absorbed functions; reduce `renderHTMLView` and `renderInnerContent` to thin wrappers |

Total: 2 files modified. Net code reduction (~8 functions absorbed into 1 loop). Semantic bug fix (attribute loss in dynamic path).

## Collaborative Discussion Record

This plan was refined through a structured Claude–ChatGPT collaborative discussion (3 rounds, CONVERGED).

Key decisions from discussion:
- _Attributes fix reclassified from "scope creep" to "dispatch correctness" (ChatGPT Round 2)
- Numeric frame count claim replaced with structural boundedness claim (ChatGPT Round 2)
- `_renderElementDynamically` re-entry discovered and documented (Claude Round 2)
- `renderFlattenedStyledContent` confirmed unreachable from dynamic path (Claude Round 2)
- Enum naming: `Dispatch` preferred over `RenderWorkItem` (compound) and `Work` (too generic) (ChatGPT Round 3)
- Case naming: `.render(Any)` preferred over `.value(Any)` for parallel verb structure (ChatGPT Round 3)

Transcript: `/tmp/worklist-rendering-dispatch-transcript.md`

## References

- `swift-tree-primitives/.../Tree.N.swift:520–579` — `forEachPreOrder` and `forEachPostOrder` patterns
- `swift-tree-primitives/.../Tree.N.swift:456–514` — `removeSubtree` post-order with cleanup action
- `swift-stack-primitives/.../Stack.swift` — `Stack<Element>` API
- `swift-machine-primitives/` — evaluated and rejected (parser interpreter, wrong execution model)
- `swift-foundations/swift-pdf-html-rendering/Research/iterative-tuple-rendering.md` — Causes 1+2 analysis, tuple-specific solution (partially superseded)
- Project memory: `swift-foundations/swift-pdf-html-rendering/Research/iterative-tuple-rendering.md` — full crash chain and three-cause discovery
