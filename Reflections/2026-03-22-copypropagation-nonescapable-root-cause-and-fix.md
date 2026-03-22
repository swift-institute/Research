---
date: 2026-03-22
session_objective: Reproduce and solve the SIL CopyPropagation false positive triggered by Property.View (~Copyable, ~Escapable, @_lifetime(borrow)), eliminating 149 @_optimize(none) workaround annotations
packages:
  - swift-property-primitives
  - swift-buffer-primitives
  - swift-async-primitives
  - swift-parser-primitives
  - swift-stack-primitives
  - swift-queue-primitives
  - swift-array-primitives
  - swift-heap-primitives
  - swift-set-primitives
  - swift-dictionary-primitives
  - swift-graph-primitives
status: pending
---

# CopyPropagation ~Escapable Root Cause: mark_dependence Classification and Fix

## What Happened

Session objective: find and eliminate the root cause of Bug 2 (SIL CopyPropagation false positive) that required 149 `@_optimize(none)` annotations across 12 sub-repos and was growing with every new `@inlinable` function using Property.View.

**Phase 1 — Compiler source analysis.** Read the Swift compiler source (`swiftlang/swift`) to trace the exact mechanism:
- `OSSACanonicalizeOwned.cpp:216-219`: CopyPropagation bails out on `OperandOwnership::PointerEscape`
- `OperandOwnership.cpp:699-720`: `mark_dependence` without `[nonescaping]` flag classified as `PointerEscape`
- `LifetimeDependenceInsertion.swift`: All `mark_dependence` for `@_lifetime(borrow)` created with `.Unresolved` kind
- `LifetimeDependenceDiagnostics.swift`: Unresolved dependencies resolved to `[nonescaping]` or settled to `[escaping]`
- `OSSACanonicalizeOwned.cpp:40-46`: **TODO comment from compiler team** acknowledging the mark_dependence/PointerEscape interaction as a known limitation

The chain: `~Escapable` + `@_lifetime(borrow base)` → `mark_dependence [unresolved/escaping]` → `PointerEscape` classification → partial canonicalization bailout → double `end_lifetime` generation on `~Copyable ~Escapable` values across control flow joins.

**Phase 2 — Standalone reproducer.** Created a 3-module experiment (`copypropagation-nonescapable-mark-dependence`) that reliably triggers the crash. Previous attempts (7 standalone patterns) had failed because they didn't include both `~Escapable` + `@_lifetime(borrow)` — the specific combination that generates `mark_dependence`. The reproducer crashes on `swift build -c release` with "Found over consume?!" showing double `end_lifetime` for the same View.Typed value.

**Phase 3 — Fix evaluation.** Tested 4 variants:
- V1 (baseline): `~Copyable, ~Escapable` view + control flow → **CRASH**
- V2 (drop `~Escapable`): Remove `~Escapable` + `@_lifetime` → **BUILD SUCCEEDS**
- V3 (`@_optimize(none)` on `_read` accessor): Keep `~Escapable`, suppress accessor inlining → **BUILD SUCCEEDS**
- V4 (`@_optimize(none)` on View.init): Keep `~Escapable`, suppress init → **CRASH** (wrong level)

**Phase 4 — Apply Fix A (drop `~Escapable`) to superrepo.** Removed `~Escapable` from 7 Property.View struct declarations, removed `@_lifetime(borrow base)` from inits, removed `@_lifetime(&self)` from Property.View extension methods, removed all 149 `@_optimize(none)` annotations, inlined 4 extracted static methods in async-primitives back into closures. `swift build -c release` passes clean.

## What Worked and What Didn't

**Worked well:**
- Reading the compiler source was decisive. The TODO comment at `OSSACanonicalizeOwned.cpp:40-46` confirmed the hypothesis before any code was written.
- The reproducer was created on the first attempt once the mechanism was understood (`~Escapable` + `@_lifetime(borrow)` = `mark_dependence` = trigger). Previous 7 attempts had failed because they tested general `~Copyable`/`@_rawLayout` patterns without the specific `~Escapable` ingredient.
- Fix A (drop `~Escapable`) is a clean root-cause elimination with zero performance cost. The `_read`/`_modify` coroutine scope already provides lifetime confinement — `~Escapable` was defense-in-depth that triggered a compiler bug.

**What didn't work:**
- Bulk `sed` removal of `@_lifetime(&self)` was too coarse. Some files contained BOTH Property.View extensions AND methods on other `~Escapable` types (e.g., `nextSpan() -> Span<Element>` on Iterator types). The sed removed the Iterator annotations too, requiring targeted restoration. A grep-then-sed pipeline filtering to Property.View-only methods would have been cleaner.
- The suggestion to "split accessor chains" (`var buf = _buffer; buf.remove.all()`) was evaluated and rejected — doesn't work for `~Copyable` buffers. The suggestion to "remove @inlinable" was already tried in prior sessions and confirmed non-viable (WMO still optimizes).

## Patterns and Root Causes

**The `~Escapable` tax is a compiler limitation, not a design feature.** The `~Escapable` annotation on Property.View provided compile-time lifetime safety that was *redundant* with the `_read`/`_modify` coroutine scope. The coroutine machinery (`begin_apply`/`end_apply`) already prevents the yielded value from escaping. Adding `~Escapable` created `mark_dependence` instructions in SIL that the optimizer couldn't handle, turning a safety annotation into a correctness hazard.

**Pattern: defense-in-depth annotations can interact with optimizer bugs.** The `~Escapable` + `@_lifetime(borrow)` combination is sound from a type-system perspective. The bug is in the SIL optimizer (CopyPropagation's handling of `mark_dependence`). But the pragmatic reality is: if a sound type annotation triggers an optimizer crash, the annotation's value must be weighed against the workaround cost. In this case, 149 `@_optimize(none)` annotations with unbounded growth is an unacceptable cost for a redundant safety layer.

**The 7-attempt reproducer failure was a search-space problem, not a technique problem.** The [EXP-004a] incremental construction methodology was correct — the missing ingredient was understanding *which* feature combination to construct. The prior experiments tested `~Copyable`, `@_rawLayout`, coroutine yields, control flow patterns — all necessary but not sufficient. The key was `~Escapable` + `@_lifetime(borrow)` generating `mark_dependence`. Once the compiler source revealed this, the reproducer succeeded immediately.

**Compiler source reading as investigation tool.** For optimizer bugs, reading the optimizer source is more efficient than empirical exploration. The TODO comment at `OSSACanonicalizeOwned.cpp:40-46` provided more signal in 5 lines than 7 experiments.

## Action Items

- [ ] **[experiment]** copypropagation-nonescapable-mark-dependence: Update EXPERIMENT.md with full results per [EXP-006], add to `_index.md`
- [ ] **[research]** File a Swift bug report for the `mark_dependence` classification issue. The standalone reproducer is ready. The compiler team's TODO comment confirms they're aware of the general limitation but may not have a concrete reproducer for the `~Escapable` coroutine yield case.
- [ ] **[skill]** implementation: Add guidance that `~Escapable` on coroutine-yielded view types triggers CopyPropagation Bug 2. Property.View intentionally omits `~Escapable` — the `_read`/`_modify` coroutine scope provides lifetime confinement. Do not re-add `~Escapable` until swiftlang/swift fixes `mark_dependence` canonicalization.
