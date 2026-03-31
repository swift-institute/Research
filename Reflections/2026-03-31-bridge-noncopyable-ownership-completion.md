---
date: 2026-03-31
session_objective: Complete remaining ~Copyable ownership improvements from Bridge handoff
packages:
  - swift-queue-primitives
  - swift-async-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: testing-swiftlang
    description: Expanded [SWIFT-TEST-014] with ~Copyable Optional nil-check pattern (if let, not == nil)
  - type: skill_update
    target: implementation
    description: Added [IMPL-078] Widen, Don't Duplicate — prefer widening Copyable→~Copyable over parallel extensions
  - type: no_action
    description: Ownership.Borrow peek wiring — superseded by Entry 7 finding (closure-based peek is final)
---

# Bridge ~Copyable Ownership Completion — Unification Over Duplication

## What Happened

Session picked up from `HANDOFF-bridge-noncopyable-ownership.md` with two remaining imperfections: (1) Deque `.front`/`.back` Property.View accessors for ~Copyable elements, and (2) `push(draining:)` batch API for ~Copyable elements on Bridge.

For imperfection 5 (Deque accessors), the initial approach was to add separate `~Copyable` extensions alongside the existing `Copyable` ones. The developer intervened: "can't we just update the same code to work for both?" This led to **unifying** the existing Copyable extensions to `~Copyable`, changing `push` to `consuming`, replacing value-returning `peek` with closure-based, and keeping `var peek: Element?` as a small Copyable-only convenience. One extension instead of two.

For imperfection 3 (`push(draining:)`), significant time was spent exploring protocol-based approaches (`Sequence.Drain.Protocol`), `sending`/region isolation interactions, and whether the coroutine Mutex or `Ownership.Borrow` changed the design. The principled answer turned out to be simple: one closure-based method on Bridge (`push(draining: () -> Element?)`), following the same `withLock` pattern as the existing Copyable `push(contentsOf:)`.

## What Worked and What Didn't

**What worked**: The unification approach for Deque accessors was cleaner than duplication — fewer lines, single source of truth, no performance cost. The developer's instinct to question the additive approach was correct.

**What didn't work**: The investigation into `push(draining:)` went through too many design iterations before converging on the simple answer. Explored Sequence.Drain.Protocol threading through locks, Ownership.Slot staging, coroutine Mutex implications, and Ownership.Borrow — when the answer was just a closure parameter inside `withLock`, matching the existing Copyable pattern. The coroutine Mutex and Ownership.Borrow are valuable infrastructure but were red herrings for this specific problem.

**Compiler friction**: `#expect` macro cannot handle `~Copyable` optionals in binary comparisons (`#expect(deque.front.take == nil)`) or property access on ~Copyable bases (`#expect(deque.isEmpty)`). Workarounds: extract to local Bool, use `if let` for nil checks.

## Patterns and Root Causes

**Pattern: Widen, don't duplicate.** When adding ~Copyable support to an existing Copyable API, the first instinct is to add a parallel extension. The better approach is to widen the existing constraint from `Copyable` to `~Copyable` when the operations are compatible. Only split where semantics genuinely diverge (peek: value-returning vs closure-based). This avoids dual maintenance and the overload resolution ambiguity surface.

**Pattern: Match the existing pattern before innovating.** The `push(draining:)` answer was always "closure inside withLock, same as push(contentsOf:)." The investigation explored whether new infrastructure (coroutine Mutex, Drain protocol, Ownership.Borrow) changed the fundamental approach — it didn't. The Bridge needs transactional multi-step access (drain + isFinished check + continuation), which requires `withLock` regardless. New infrastructure is valuable for other use cases but wasn't the right tool here.

**Pattern: `#expect` macro has a Copyable boundary.** Swift Testing's `#expect` macro decomposition requires Copyable bases for property access and binary operations. This will recur in every ~Copyable test suite. Extract values to local variables before `#expect`.

## Action Items

- [ ] **[skill]** testing-swiftlang: Add guidance for `#expect` limitations with ~Copyable types — extract to local Bool/Int before assertions, use `if let` instead of `== nil` for ~Copyable optionals
- [ ] **[skill]** implementation: Document "widen, don't duplicate" as a corollary of [IMPL-025] — when adding ~Copyable support, prefer widening existing Copyable extensions to ~Copyable over adding parallel extensions
- [ ] **[package]** swift-queue-primitives: Wire `Ownership.Borrow` into `.front`/`.back` peek accessors per the noncopyable-peek-escapable handoff resolution (import already added)
