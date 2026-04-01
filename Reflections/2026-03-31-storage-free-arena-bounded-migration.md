---
date: 2026-03-31
session_objective: Investigate whether ecosystem data structures replace Timer.Wheel.Storage.Free, then implement the migration
packages:
  - swift-async-primitives
  - swift-buffer-primitives
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: ecosystem-data-structures
    description: Added naming confusion note to [DS-010] — Buffer.Slab vs Buffer.Arena disambiguation
  - type: package_insight
    target: swift-async-primitives
    description: Timer.Wheel arena migration complete; schedule/cancel/advance methods unimplemented
  - type: research_topic
    target: handle-vs-arena-position-unification.md
    description: Could Handle<_Entry> be replaced by Arena.Position for Timer.Wheel.ID?
---

# Storage.Free to Buffer.Arena.Bounded — Prior Audit Retraction and Migration

## What Happened

Session received a handoff brief (`HANDOFF-storage-free-data-structure.md`) directing an ecosystem-data-structures audit scoped to `Async.Timer.Wheel.Storage.Free`. The prior audit (2026-03-18, Finding #1) had recommended `Buffer.Slab` as the replacement. The investigation concluded that recommendation was wrong — `Buffer.Slab` is bitmap-tracked with no free-list and no generation tokens. `Buffer.Arena.Bounded` is the correct match: it implements the exact LIFO free-list + generation-token algorithm that Storage.Free hand-rolls.

The audit was written (6 findings, all resolved same-session), then the migration was planned and implemented:
- Replaced `nodes: [Node?]`, `free: Free`, `generation: UInt32`, `capacity: Int` with a single `Buffer<Node>.Arena.Bounded` field
- Changed `Storage.Index` from `Tagged<Node, UInt32>` to `Index<Node>` across 6 files
- Replaced 9 optional-chaining subscript sites with pointer-based access
- Updated ID boundary to bridge `Handle<_Entry>` and `Arena.Position`
- Clean build verified (2104 steps, zero errors)

Artifact cleanup: deleted `HANDOFF-storage-free-data-structure.md` (all items complete), updated all 5 audit findings to RESOLVED.

## What Worked and What Didn't

**Worked well**: The investigation phase was thorough and caught the prior audit's error before implementation. Reading the actual `Buffer.Slab` source revealed it's bitmap-tracked (O(word) allocation via `firstVacant()`) with no generation tokens — a downgrade from the hand-rolled code. `Buffer.Arena.Bounded` was discovered by following the [DS-010] decision tree: "Need use-after-free detection? Yes -> Buffer.Arena."

**Worked well**: The dependency analysis was clean. `Buffer.Arena.Bounded` was already transitively available through 4 layers of `@_exported import`. The `Index<Node>` type and all supporting types (`Ordinal`, `Cardinal`, `Index.Count`) were verified available before writing any code. Zero Package.swift changes needed.

**Moderate confidence**: The pointer-based access pattern (`unsafe storage.pointer(at:).pointee.next = value`) replaces the optional-chaining pattern (`storage[index]?.next = value`). The new pattern is more correct (occupied slots are guaranteed initialized) but introduces `unsafe` at 9 call sites. This matches the Tree.N.Bounded precedent in the ecosystem, so it's a known pattern, but the increased unsafe surface area is worth noting.

## Patterns and Root Causes

**Pattern: Name-based recommendations vs. semantic-based recommendations.** The prior audit recommended `Buffer.Slab` because the hand-rolled code was labeled a "slab allocator" in comments. But `Buffer.Slab` in the ecosystem is a bitmap-tracked sparse container — a different data structure sharing the same name. The correct match was found by analyzing the algorithmic requirements (LIFO free-list + generation tokens) and following the decision tree in `ecosystem-data-structures` skill. This is the difference between searching by name ("what's called a slab?") and searching by semantics ("what provides O(1) free-list allocation with ABA tokens?").

**Pattern: Arena.Position and Handle<_Entry> are the same concept from different packages.** Both encode (index: UInt32, token/generation: UInt32) as an ephemeral capability handle. Handle comes from handle-primitives (general-purpose), Position comes from buffer-arena-primitives (arena-specific). The Timer.Wheel bridges between them at the boundary. This suggests a potential future unification — Handle could be defined in terms of Arena.Position, or vice versa — but the current bridge is clean enough.

**Observation: Most of the deleted code was free-list bookkeeping.** The parallel `[UInt32]` array, sentinel-value chain initialization loop, `allocate()`'s pop-and-advance, `deallocate()`'s push-and-link — all of this exists inside `Buffer.Arena.Bounded` already. The migration deleted ~90 lines and added ~30, with the additions being thin wrappers. This validates the four-layer composition architecture: when the ecosystem has the right primitive, consumers should compose it, not reimplement it.

## Action Items

- [ ] **[skill]** ecosystem-data-structures: Add a "common naming confusion" note in [DS-010] decision tree — `Buffer.Slab` is bitmap-tracked (no free-list, no generation tokens), `Buffer.Arena` is free-list + generation tokens. The "slab" label in user code does not imply `Buffer.Slab`.
- [ ] **[package]** swift-async-primitives: Timer.Wheel `schedule()`/`cancel()`/`advance()` are still unimplemented. The arena infrastructure is now in place — these methods should use `storage.insert()`, `storage.free()`, and `storage.isValid()`.
- [ ] **[research]** Investigate whether `Handle<_Entry>` could be replaced with `Buffer.Arena.Position` as the public `Timer.Wheel.ID` type, eliminating the handle-primitives dependency and the boundary bridge. Trade-off: tighter coupling to arena internals vs. 8-byte IDs and built-in validation.
