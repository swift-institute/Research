---
date: 2026-04-01
session_objective: Resolve 2 DEFERRED compound method name findings from async-primitives code-surface audit
packages:
  - swift-async-primitives
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: testing-swiftlang
    description: "Add requirement for extracting ~Copyable/~Escapable property accesses to local variables before #expect — macro's __checkPropertyAccess requires Copyable + Escapable"
  - type: skill_update
    target: implementation
    description: "Document generic scoping limitation — extension Outer<T>.Inner cannot reference Outer<T>.Sibling — forces methods to live on outer type"
  - type: package_insight
    target: swift-async-primitives
    description: "Renamed slot operations (append/remove/popFirst) have zero external call sites — verify when schedule/cancel/advance are implemented"
---

# Deferred Compound Methods — Generic Scoping Constraint and Dead Code Discovery

## What Happened

Investigated and resolved the last 2 DEFERRED findings from the async-primitives code-surface audit:

**Group 1 (Broadcast.State)**: `minCursor()` and `pruneBuffer()`. Investigation revealed `pruneBuffer()` was dead code — defined but never called; `send()` had equivalent inline logic. Removed it entirely. Renamed `minCursor()` to `var cursor: UInt64?` — State's cursor is unambiguously the minimum subscriber cursor (the pruning threshold), so `cursor` is not compound and needs no nested accessor chain.

**Group 2 (Timer.Wheel)**: `slotAppend`, `slotRemove`, `slotPopFirst`, `withSlot`. First checked the parallel investigation (`HANDOFF-timer-wheel-intrusive-list.md`) — verdict was NO, `List.Linked` cannot replace the intrusive list (no ABA generation tokens, no remove-by-index, no multi-head shared store). So Group 2 remained applicable.

Initial design: move operations from `Wheel` methods to `Slot` methods with `borrowing Storage` parameter. This failed — `extension Async.Timer.Wheel.Slot` cannot reference sibling types `Node` and `Storage` because `Wheel<C>` is generic and the `C` parameter is unnamed in the nested type's extension scope. Fully-qualified names (`Async.Timer.Wheel.Node`) also failed: "reference to generic type 'Async.Timer.Wheel' requires arguments in <...>".

Final implementation: methods stayed on `Wheel`, prefix dropped. `slotAppend` -> `append(_:to:)`, `slotRemove` -> `remove(_:from:)`, `slotPopFirst` -> `popFirst(from:)`. `withSlot` removed (zero call sites). This resolves [API-NAME-002] without fighting the type system.

Also fixed pre-existing test failure: `#expect(state.shutdown.isActive)` where `Shutdown` is `~Copyable ~Escapable`. The `#expect` macro's `__checkPropertyAccess` requires `Copyable + Escapable`. Fix: extract to local `Bool` variable first.

## What Worked and What Didn't

**Worked**: Dead code detection through call-site analysis before designing. Finding that `pruneBuffer()` was never called simplified Group 1 from a two-method restructuring to a one-property rename plus deletion.

**Worked**: Checking the dependency (timer-wheel handoff) first, as instructed. The findings were already written, so no wasted investigation time.

**Didn't work**: The initial "methods on Slot" design. Confidence was medium going in — the concern about generic scoping was noted in the findings but not fully worked through until the compiler rejected it. The attempt to use fully-qualified names was a reasonable next step but also failed due to Swift's requirement for explicit generic arguments.

**Worked well**: The fallback (drop prefix, keep on `Wheel`) was simple and correct. Sometimes the least ambitious refactor is the right one. The compound name violation was the `slot` prefix, not the method location — removing the prefix was sufficient.

## Patterns and Root Causes

**Swift generic scoping constraint**: `extension Outer<T>.Inner` creates a scope where `T` exists but is unnamed, and sibling types `Outer<T>.Sibling` cannot be referenced — not via bare name, not via fully-qualified path. This is a fundamental limitation of Swift's extension model for nested types of generic types. The workaround is to define methods on the outer type instead.

This is the same family of constraint as [MEM-COPY-006] constraint poisoning (types that can't be extracted to separate files because they reference generic parameters). The pattern: Swift's generic scoping rules sometimes force code to live at a higher scope than semantically ideal.

**Dead code as audit artifact**: `pruneBuffer()` was likely written as a clean interface but then the `send()` method was optimized with inline pruning logic that superseded it. The method survived because it compiled and had a WORKAROUND annotation that discouraged touching it. Audit findings that tag code as DEFERRED can inadvertently preserve dead code by discouraging investigation.

**`#expect` macro and ~Copyable**: The Swift Testing `#expect` macro expands to `__checkPropertyAccess` which has implicit `Copyable + Escapable` constraints. Any `~Copyable` or `~Escapable` value accessed via property chain inside `#expect` will fail. The fix is always the same: extract to a local variable of the result type (typically `Bool`) and `#expect` on that.

## Action Items

- [ ] **[skill]** testing-swiftlang: Add requirement for extracting ~Copyable/~Escapable property accesses to local variables before `#expect` — the macro's `__checkPropertyAccess` requires Copyable + Escapable
- [ ] **[skill]** implementation: Document the generic scoping limitation — `extension Outer<T>.Inner` cannot reference `Outer<T>.Sibling` — as a known constraint that forces methods to live on the outer type
- [ ] **[package]** swift-async-primitives: All 4 slot operations (`append`/`remove`/`popFirst`/`withSlot`-deleted) have zero external call sites — `schedule`/`cancel`/`advance` are not yet implemented; when they are, verify the renamed methods work with the exclusivity model
