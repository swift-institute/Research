---
date: 2026-03-30
session_objective: Create centralized concurrency conventions research and execute bottom-up sendability pass across swift-kernel-primitives, swift-kernel, swift-async-primitives, swift-async
packages:
  - swift-kernel-primitives
  - swift-async-primitives
  - swift-kernel
  - swift-async
  - swift-institute
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: package_insight
    target: swift-async-primitives
    description: Async.Mutex Sendable constraint cascade — highest-leverage refactor
  - type: skill_update
    target: implementation
    description: Add [IMPL-076] no @unchecked Sendable on struct-wrapping-class
  - type: research_topic
    target: async-mutex-rawlayout-inline-storage.md
    description: Can Async.Mutex adopt @_rawLayout for inline storage?
---

# Modern Concurrency Conventions and Sendability Pass

## What Happened

Session had two phases: (1) create a centralized research document synthesizing PF #356/#357/#360, 9 internal research docs, and the swift-io case study into a single normative concurrency reference; (2) execute a bottom-up sendability pass across 4 packages.

Research doc (`modern-concurrency-conventions.md`) establishes the isolation hierarchy: actors > ~Copyable ownership > `sending` region transfer > Mutex > `@unchecked Sendable`. Codifies 8 conventions and a 3-phase migration plan.

Sendability pass results:
- **swift-kernel-primitives**: 2 → 0 `@unchecked Sendable`. Both `Kernel.File.Handle` and `Kernel.Memory.Map.Region` had all-Sendable stored properties.
- **swift-async-primitives**: 38 → 19 `@unchecked Sendable`. Dropped from 13 channel struct types wrapping Sendable class references.
- **swift-kernel**: 6 `@unchecked Sendable`, all genuinely justified (synchronization primitives themselves).
- **swift-async**: 8 `@unchecked Sendable`, all genuinely justified (non-@Sendable isolation-preserving closures).

Discovered that `Async.Mutex<Value: ~Copyable & Sendable>` forces the `Sendable` constraint onto all channel State types — 7 `@unchecked Sendable` annotations exist solely to satisfy this. Stdlib's `Synchronization.Mutex` has no such constraint (uses `sending` instead). Handoff written for next session to refactor this.

## What Worked and What Didn't

**Worked**: Bottom-up ordering was exactly right. kernel-primitives changes were trivial; the real density was in async-primitives. Having clean lower layers meant every async-primitives change could be verified against already-correct foundations.

**Worked**: Batch-editing all 13 channel structs and letting the compiler verify was fast and decisive — zero errors on first build.

**Didn't work initially**: Assumed `~Copyable` structs can't get synthesized `Sendable` conformance and need `@unchecked`. User challenged this — and was right. The ecosystem already has many `~Copyable, Sendable` (plain) types. This false assumption would have led to documenting escape hatches as "necessary" when they should be eliminated.

**Didn't work initially**: First plan proposed only adding justification comments. User pushed for actual refactoring (dropping `@unchecked`, using `sending`). The "document what exists" approach was too conservative — the right approach was "fix what's wrong."

## Patterns and Root Causes

**The `@unchecked` propagation cascade**: `Async.Mutex` requires `Value: Sendable`. Channel State contains `Deque<Element>` where Element may be `~Copyable` (not Sendable). So State must be `@unchecked Sendable` to satisfy Mutex. This is the wrong design — stdlib's Mutex uses `sending` for the region transfer, not a `Sendable` constraint. One wrong constraint at the infrastructure level creates 7+ escape hatches downstream.

**Struct-wrapping-class pattern**: When a struct's only stored property is a reference to an `@unchecked Sendable` class, the struct itself can be plain `Sendable` — the class IS Sendable (even if unchecked). 13 of 38 `@unchecked` annotations in async-primitives were this pattern. The `@unchecked` had been applied reflexively to every type in the channel hierarchy, when only the classes genuinely needed it.

**The verification pattern**: For sendability changes, "edit → build → check" is the fastest feedback loop. The compiler is the authority on whether Sendable synthesis works. Reasoning about it from first principles (as I initially tried) is slower and error-prone.

## Action Items

- [ ] **[package]** swift-async-primitives: Refactor `Async.Mutex<Value: ~Copyable & Sendable>` to `Async.Mutex<Value: ~Copyable>` using `sending` for region transfer. This is the highest-leverage single change — it unblocks 7+ `@unchecked Sendable` removals. (Handoff written: `HANDOFF-async-mutex-sending-refactor.md`)
- [ ] **[skill]** implementation: Add guidance that `@unchecked Sendable` on structs wrapping Sendable class references is unnecessary — plain Sendable works and should be preferred.
- [ ] **[research]** Investigate whether `Async.Mutex` can adopt stdlib's `@_rawLayout` pattern for inline storage, eliminating the class indirection entirely.
