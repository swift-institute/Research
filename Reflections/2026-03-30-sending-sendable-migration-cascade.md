---
date: 2026-03-30
session_objective: Fix build breaks from Channel dropping Element: Sendable, investigate whether Async.Stream should also drop it
packages:
  - swift-async-primitives
  - swift-async
  - swift-institute
status: pending
---

# Sending/Sendable Migration Cascade: Primitives → Foundations

## What Happened

Picked up a handoff to fix swift-async (L3) after swift-async-primitives (L1) dropped `Element: Sendable` from `Async.Channel`. Two issues:

1. **async-primitives**: An uncommitted change to `send(contentsOf:)` had dropped the `Element: Sendable` where clause but left the region transfer broken — 3 compiler errors about task-isolated state inside `withLock`.

2. **swift-async**: `Async.Stream+Bridge.swift` lines 191-215 — `Receiver.stream()` methods construct `Async.Stream<Element>` which requires `Element: Sendable`, but Channel no longer guarantees it.

Fixed (1) using the Slot staging pattern: collect elements into `Ownership.Slot(Array(elements))` before the lock, iterate from the Slot inside, stage delivery element through `storage.deliverySlot` (bound locally to avoid storage capture). Added `sending S` parameter. Fixed (2) with `where Element: Sendable` on the bridge extensions.

User then asked whether `Async.Stream` could drop `Element: Sendable` entirely. This triggered a Tier 2 research investigation that synthesized the `stream-isolation-preservation` experiment (13 test variants), `stream-isolation-preserving-operators.md`, `stream-isolation-propagation.md`, and `modern-concurrency-conventions.md`. Wrote `Research/async-stream-sendable-requirement.md` analyzing 4 options. Created handoff for swift-io sendability pass.

## What Worked and What Didn't

**Worked well**: The Slot staging pattern from the experiment (`sending-mutex-noncopyable-region`) directly solved the `send(contentsOf:)` region transfer. The first attempt (just adding `sending S` to the parameter) failed — the captured sequence still taints state. The second attempt (Slot staging) compiled immediately. The experiment's findings were directly applicable without adaptation.

**Didn't work**: First attempt at `send(contentsOf:)` — adding `sending` to the parameter alone. The experiment had documented this: "any inout capture of a non-Sendable variable in the withLock closure merges the closure's region with the variable's region." Capturing `elements` (even as `sending`) has the same effect. Should have gone straight to Slot staging.

**High confidence**: The bridge fix (`where Element: Sendable`) is clearly correct — Stream structurally requires it. The research conclusion (Option C: two-tier architecture) is well-supported by prior experiments.

## Patterns and Root Causes

**The Slot pattern is becoming the universal solution for non-Sendable values crossing lock boundaries.** It appeared in single-element `send()`, now in batch `send(contentsOf:)`, and is used by `Iterator.Box` (via `Ownership.Mutable.Unchecked`). The pattern: stage through an `@unchecked Sendable` container before the lock, take from it inside. The compiler can't track regions through `@unchecked Sendable` wrappers, which is exactly the escape hatch needed.

**The `sending` annotation on parameters is necessary but not sufficient for withLock closures.** `sending` transfers region ownership at the call boundary, but inside the closure, the captured value may still merge with the `inout sending State` parameter's region. The Slot breaks the chain because it's `@unchecked Sendable` — the compiler treats values taken from it as "disconnected" from any region.

**Research synthesis was more valuable than fresh investigation.** The `stream-isolation-preservation` experiment (from 2026-02-25) had already answered the core question — concrete types preserve isolation, @Sendable closures break it. The research document assembled existing findings rather than running new experiments. This is a good use pattern: run experiments early, synthesize when questions arise.

## Action Items

- [ ] **[skill]** memory-safety: Add batch-send Slot staging pattern — `Ownership.Slot(Array(elements))` before lock, iterate from Slot inside. Distinct from single-element Slot pattern (which stages one value). Applicable whenever a Sequence of non-Sendable elements must enter a `withLock` closure.
- [ ] **[package]** swift-async-primitives: The `store()` return value warning on `Ownership.Slot.store()` appears at 3 sites in channel senders. Either suppress with `@discardableResult` on Slot.store() or use `_ = slot.store(element)` at call sites.
- [ ] **[research]** Concrete async operator types (Option C from async-stream-sendable-requirement.md) — when/whether to implement the ~20 concrete operator types that would enable non-Sendable elements and isolation preservation in async pipelines.
