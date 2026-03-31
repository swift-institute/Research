---
date: 2026-03-27
session_objective: Restructure bounded and unbounded channel state machines for ~Copyable element flow
packages:
  - swift-async-primitives
status: pending
---

# Async Channel ~Copyable Restructure — Closure Capture as the Real Blocker

## What Happened

Set out to implement the design in `HANDOFF-zero-copy-noncopyable-restructure.md`: make `~Copyable` elements flow through both bounded and unbounded channel state machines without implicit copies. Researched 5 approaches from the handoff, evaluated against existing ~Copyable research in swift-institute/Research and Experiments.

Chose a hybrid of Approach 1 (inout Element?) + Approach 3 (Slot staging). Initial implementation used `consuming Element` on `trySend` with the element returned in the action enum on the suspend path. This hit the real blocker: **non-escaping closures cannot consume a ~Copyable capture without reinitializing it** — even when the capture is consumed exactly once. The `withLock { state in state.trySend(element) }` pattern triggers `"missing reinitialization of closure capture 'element' after consume"`.

Pivoted to Slot-per-send: stage element in `Ownership.Slot` before the lock. Slot is a Copyable reference — no closure capture issue. This adds one heap allocation + two atomic CAS operations per send on the fast path. Bounded and unbounded channels both restructured. Unbounded also required: making State `~Copyable`, removing the Receive wrapper (which copied State), replacing Copyable-only Deque accessors (`back.push`/`front.take`) with ~Copyable-compatible methods (`push(_:to:)`/`take(from:)`), and adding Signal+deliverySlot pattern. Fixed pre-existing unbounded compilation errors (67 errors before my changes). All 88 tests pass.

## What Worked and What Didn't

**Worked**: The Slot-per-send approach compiles cleanly and is semantically correct on all paths. ARC manages Slot lifetime naturally — no manual cleanup needed. Making `Sender` store `Ownership.Slot<Element>` instead of `Element` made it `Sendable` (no ~Copyable field), simplifying the queue storage. The Signal+deliverySlot pattern (already proven on bounded) transferred cleanly to unbounded.

**Didn't work**: The "element-in-action" approach (`trySend` consuming element and returning it in `.suspend(id, element)`) failed on the closure capture rule, despite the element being consumed exactly once on all paths. The compiler can't reason about conditional consumption through a `consuming` function parameter — it sees the capture passed to a consuming parameter and demands reinitialization regardless. Spent significant time analyzing `inout Element?` extraction patterns for ~Copyable before pivoting.

**Confidence concern**: The Slot-per-send overhead on the fast path is non-zero. For high-throughput channels, one class allocation per send may matter. The audit handoff tracks this.

## Patterns and Root Causes

**The real blocker isn't ownership — it's closure capture semantics.** The `~Copyable` element ownership model works fine (Optional, Result, switch, enum associated values all work). The blocker is specifically that `withLock`-style APIs require closures, and closures have blunt capture-consumption rules. The compiler requires captured values to be reinitialized after consume on ALL lexical paths, even when the consuming function's signature guarantees total consumption. This is a compiler limitation, not an ownership model limitation.

**Pattern**: Any `withLock { state in state.method(consuming element) }` pattern where `element: ~Copyable` is captured will hit this. The workaround is always the same: wrap in a Copyable reference before the closure boundary. `Ownership.Slot` is the ecosystem's canonical wrapper for this.

**The unbounded channel was already broken.** 67 pre-existing errors from incomplete ~Copyable propagation. The State was `Sendable` (Copyable) but stored `Deque<Element>?` which is ~Copyable when Element is. The Receive wrapper copied State. The Deque Property.View accessors (`back.push`, `front.take`) required Copyable. These weren't caught because the test target couldn't link (due to the errors), masking the failure.

## Action Items

- [ ] **[research]** Can the closure capture reinitialize rule be relaxed for non-escaping closures where the consuming callee guarantees total consumption? If so, a compiler pitch would eliminate the Slot-per-send overhead.
- [ ] **[skill]** implementation: Add [IMPL-064] documenting the ~Copyable closure capture workaround pattern: wrap in Ownership.Slot before withLock boundaries. Reference this session.
- [ ] **[package]** swift-async-primitives: Benchmark Slot-per-send overhead vs direct element passing (pre-restructure) to quantify the cost and determine if optimization is warranted.
