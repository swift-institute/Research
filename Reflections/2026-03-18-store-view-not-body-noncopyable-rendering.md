---
date: 2026-03-18
session_objective: Reproduce and fix cooperative pool stack overflow in rendering pipeline
packages:
  - swift-rendering-primitives
  - swift-html-rendering
  - swift-css-html-rendering
  - swift-pdf-html-rendering
status: processed
processed_date: 2026-03-20
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-036] store container, compute content transiently
  - type: skill_update
    target: memory
    description: Add [MEM-COPY-012] protocol property dispatch for ~Copyable return types
  - type: package_insight
    target: swift-rendering-primitives
    description: @_owned tracking (deduplicated with entry 1)
---

# Iterative Render Machine — From Reproduction to ~Copyable Body Support

## What Happened

Session started from a SIGBUS crash in PDF rendering on Swift's cooperative thread pool (544 KB stack). The `_render -> body -> _render` recursive chain exhausted the budget at ~20 nesting levels in production (where PDF context operations consume ~11 KB per frame).

**Phase 1 — Reproduction**: Created a self-contained experiment (`cooperative-pool-stack-overflow/`) with 200 nesting levels of `Tag + 6x Styled` wrappers. SIGBUS confirmed at depth 180 on the cooperative pool. Stack measurement: ~2.8 KB per level, ~522 KB available. Main thread (8 MB) passes all depths. This proved the crash is **depth-induced** (cumulative `_render` chain), not width-induced (`_Tuple.init` is just the tipping point).

**Phase 2 — Option evaluation**: Option C (box `_Tuple`) validated as gaining only ~3 levels of headroom. Prior art survey (OpenSwiftUI, Elementary) confirmed only heap-managed indirection handles arbitrary depth. CSS modifier flattening researched and found subsumed by Option F.

**Phase 3 — Strategy B (iterative render machine)**: LIFO work stack with `Thunk` (dispatch + destroy closures) and `Work` enum (`.render` or `.action` for deferred pops). Three deviations from the original plan validated: `open(push:pop:)` replaces closure-based bracket, `_Tuple` must defer ALL children, and `Thunk` replaces `Witness` naming.

**Phase 4 — ~Copyable body support**: The default `_render` initially required `Body: Copyable` because `view.body` on `borrowing Self` yields a borrowed value for ~Copyable Body (protocol witness table dispatches through `_read` coroutine). Investigated `@_owned` (found in compiler source but not shipped in 6.2.4). Investigated `func body()` (works but prohibited — must keep `var body`). **Breakthrough**: store the VIEW (Self: Copyable) instead of the BODY. The body is computed transiently via `view.body` during dispatch and flows as a borrow into `Body._render`. Constraint shifts to `Self: Copyable`, enabling ~Copyable bodies. Validated in experiment (15 tests pass).

**Production implementation** completed by the other agent across L1 (rendering primitives), L2 (html-rendering), L3 (pdf-html-rendering). 102/102 tests pass.

## What Worked and What Didn't

**Worked well**:
- Isolated reproduction was essential. Without measured stack budgets (522 KB available, 2.8 KB/level), the root cause analysis would have been wrong (initially blamed `_Tuple.init` width, actually depth).
- Two-agent collaboration: one agent on research/review, one on implementation. The critical review caught the push/pop ordering issue (FIFO vs LIFO), the CSS modifier test gap, and the naming violations before production.
- The compiler source search (`swiftlang/swift/Features.def`, `TypeCheckStorage.cpp`) directly revealed the `_read` vs `get` ownership semantics and the `@_owned` feature. Without reading the compiler, we would have been stuck at "it's a compiler limitation."

**Didn't work well**:
- Multiple `swift build` commands ran in parallel early on, locking SwiftPM. Need discipline: one build at a time.
- Deep generic nesting (50 levels of `Wrap<Wrap<...>>`) killed the compiler. Concrete nesting (unique struct names) compiled instantly. Lesson: avoid recursive generic type parameters in experiments.
- The `@_owned` finding was a false lead initially — it exists in the source tree but not in the shipped toolchain. Verified with `swiftc` before committing to the approach.

## Patterns and Root Causes

**Pattern: "Where you store it determines what you can store."** The entire ~Copyable body blocker dissolved by asking "what if we store the VIEW instead of the BODY?" The constraint shifted from `Body: Copyable` (blocking) to `Self: Copyable` (trivially satisfied). This is the same pattern as OpenSwiftUI's attribute graph storing handles instead of values — the trick is storing enough to COMPUTE the answer later, not storing the answer itself.

**Pattern: "Protocol witness tables have accessor semantics you don't control."** `var body: Body { get }` goes through `_read` (borrowed) for ~Copyable Body, but function calls go through the function entry (owned). This is a fundamental Swift design choice documented in SE-0390 and implemented in `TypeCheckStorage.cpp`. Anyone building protocols with ~Copyable associated types needs to know this — properties yield borrows, functions return owned.

**Pattern: "Depth vs width are different failure modes with different fixes."** The initial hypothesis (width — `_Tuple.init` allocating too many children) was wrong. The reproduction proved it's depth (cumulative `_render` recursion). Option C (boxing) addresses width, Option F (iterative dispatch) addresses depth. Only measuring the actual stack budget and per-level cost revealed this.

## Action Items

- [ ] **[skill]** implementation: Add pattern for "store the container, compute the content transiently" — when a protocol associated type is ~Copyable and you need to defer computation, store the conforming type (typically Copyable) and extract the ~Copyable value during dispatch, not at enqueue time
- [ ] **[skill]** memory: Document that protocol properties with ~Copyable return types dispatch through `_read` (borrowed), while protocol functions return owned. This affects any design where ~Copyable values need to be extracted from generic protocol contexts
- [ ] **[package]** swift-rendering-primitives: Track `@_owned` (`UnderscoreOwned`, commit `458b62c9ed0`) availability in future toolchains. When shipped, add `@_owned @Builder var body` to enable ~Copyable views in addition to ~Copyable bodies
