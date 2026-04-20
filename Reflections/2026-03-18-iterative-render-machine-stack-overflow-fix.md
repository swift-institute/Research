---
date: 2026-03-18
session_objective: Implement Strategy B (iterative render machine) to fix cooperative pool stack overflow in rendering pipeline
packages:
  - swift-rendering-primitives
  - swift-html-rendering
  - swift-pdf-html-rendering
status: processed
processed_date: 2026-03-20
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-035] heap-deferred traversal all-or-nothing rule
  - type: package_insight
    target: swift-rendering-primitives
    description: Pair._render limitation with push/pop views + @_owned tracking
---

# Iterative Render Machine — Stack Overflow Fix via Heap-Deferred Traversal

## What Happened

Session implemented the iterative render machine (Strategy B) to eliminate recursive `_render -> body -> _render` stack overflow on the 544 KB cooperative thread pool. The production crash occurred at ~20 nesting levels in a deeply-nested PDF rendering consumer.

The implementation progressed through validated experiment (`iterative-render-machine/`, 15 tests) then production changes across three packages:

**L1 (Rendering Primitives Core)**: New types `Rendering.Thunk` (dispatch + destroy closures) and `Rendering.Work` (work item enum). Modified `Rendering.Context` (added `_stack`, `render(_:)`, `open(push:pop:)`, `_cleanupStack()`, `_reverseAbove(_:)`). Changed default `_render` from recursive body delegation to heap-allocate + push work item. Changed `_Tuple`, `ForEach`, `Array` to defer ALL children as work items with segment reversal.

**L2 (HTML Rendering)**: `HTML.Element.Tag._render`, `HTML.Styled._render`, `HTML._Attributes._render` — all changed from manual `context.push/pop` to `context.open(push:pop:)` with deferred pop.

**L3 (PDF HTML Rendering)**: 5 entry points changed from `V._render(view, context:)` to `context.render(view)`.

Four deviations from the original plan emerged and were validated:
1. `context.open(push:pop:)` instead of closure-based `bracket` (borrowing capture blocked)
2. `_Tuple` must defer ALL children including leaves (mixed immediate/deferred breaks interleaving)
3. `Thunk` name instead of `Witness` (avoids protocol witness confusion)
4. "Store VIEW not BODY" approach: constraint is `Self: Copyable` not `Body: Copyable`, enabling ~Copyable bodies through the iterative path

## What Worked and What Didn't

**Worked well**:
- Phased experiment-first approach. Every production issue was caught in the experiment before touching production code. The experiment's recursive-vs-iterative fidelity assertions caught the `_Tuple` interleaving bug immediately.
- External agent review between experiment and production identified the `StyledBracket` gap, naming violations, and the silent fallback problem. All four review points were valid and addressable.
- The "store VIEW not BODY" insight (from a parallel research agent) completely resolved the `~Copyable` body constraint without protocol changes or compiler features.

**Didn't work**:
- First three experiment build attempts failed on borrowing/ownership issues. Each was a different issue: `SuppressedAssociatedTypes` needed in Package.swift, `if let` consumes on borrowing Optional (must use `switch`), `unsafe {}` block syntax doesn't exist (prefix `unsafe` per expression). These were time-consuming but the fixes were well-documented in existing experiments (`borrowing-pattern-matching`).
- The `@_owned` compiler attribute was researched but doesn't exist in Swift 6.2.4. The research correctly identified it in compiler source but didn't verify toolchain availability. Cost: one round-trip build attempt.
- The plan didn't anticipate that push/pop views (`Tag`, `Styled`, `_Attributes`) would need changes. The plan assumed `bracket(push:pop:content:)` with a closure, but borrowing capture of `view` in the closure is blocked. This required `open(push:pop:)` (no closure) which is a cross-package API change the plan didn't scope.

## Patterns and Root Causes

**Pattern: "The experiment always finds what the plan didn't anticipate."** The plan was detailed (750 lines), yet four significant deviations emerged during implementation. Two were ownership/borrowing constraints invisible at the design stage (closure capture, body extraction). Two were correctness issues visible only with concrete test cases (mixed leaf/composite interleaving, push/pop ordering). This matches previous sessions (typed throws, ~Copyable deinit workaround) — plans built from reading code miss runtime interaction effects.

**Pattern: "Immediate/deferred mixing is always wrong."** The `_Tuple` interleaving bug (leaves execute immediately, composites defer) is the same class of bug as the push/pop ordering issue (push is immediate, pop is deferred). The universal fix is the same: make everything deferred. This is the heap-vs-stack dichotomy — once you move to heap-deferred traversal, you must be all-in. Partial deferral creates ordering violations.

**Pattern: "Constraint axis matters — Self vs Body."** The breakthrough was realizing the constraint could shift from `Body: Copyable` to `Self: Copyable`. The body is the wrong thing to store — it's a computed property whose value is needed only transiently during dispatch. Storing the view and computing the body on demand preserves the `borrowing` flow that already works in production. This is a general principle: when ownership blocks you, ask what the minimal storable unit is.

## Action Items

- [ ] **[skill]** implementation: Add guidance for heap-deferred traversal — when converting recursive tree walks to iterative, ALL children at each level must be deferred (no mixing immediate + deferred execution). Reference `_Tuple` interleaving bug as cautionary example.
- [ ] **[research]** Track `@_owned` / `UnderscoreOwned` availability across Swift toolchain releases. When it ships, `@_owned @Builder var body` on the protocol would enable `~Copyable` views (not just bodies) through the iterative path. Currently blocked — not in 6.2.4, not in release/6.3 branch.
- [ ] **[package]** swift-rendering-primitives: `Pair._render` with push/pop views (e.g. `BlockWrapper`) has incorrect ordering because `~Copyable` elements can't be heap-allocated from a borrow. Document this limitation. In practice, `Pair` is for `~Copyable` leaf composition only; the builder generates `_Tuple` for multi-child Copyable composition.
