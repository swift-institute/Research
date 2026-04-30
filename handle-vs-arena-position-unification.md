<!--
---
title: Handle vs Arena.Position Unification
version: 1.1.0
last_updated: 2026-04-30
status: DEFERRED
tier: 1
scope: cross-package
applies_to: [swift-handle-primitives, swift-buffer-primitives, swift-async-primitives]
normative: false
---
-->

# Handle vs Arena.Position Unification

## Context

`Handle<T>` (from handle-primitives) and `Buffer.Arena.Position` (from buffer-arena-primitives)
encode the same concept: (index: UInt32, token/generation: UInt32) as an ephemeral capability
handle with use-after-free detection. Timer.Wheel currently bridges between them at the boundary.

## Question

Could `Handle<_Entry>` be replaced with `Buffer.Arena.Position` as the public `Timer.Wheel.ID`
type, eliminating the handle-primitives dependency and the boundary bridge?

## Analysis

### Trade-offs

| Factor | Keep Handle | Use Arena.Position |
|--------|------------|-------------------|
| Dependency | handle-primitives required | Eliminated |
| Boundary bridge | Required (Handle ↔ Position) | Eliminated |
| Abstraction | General-purpose capability handle | Arena-specific |
| Coupling | Loose — ID type independent of storage | Tight — ID type exposes storage strategy |
| Size | 8 bytes (same) | 8 bytes (same) |
| Built-in validation | Via handle-primitives | Via arena `isValid()` |

### Key Question

Is Timer.Wheel.ID a general capability handle that happens to be backed by an arena,
or is it fundamentally an arena position? If the storage strategy could change (e.g.,
to a hash map), Handle is the correct abstraction. If arena storage is permanent, Position
is simpler.

## Outcome

**Status**: DEFERRED (2026-04-30)

**Disposition**: Investigation never started past the trade-off table; no urgent driver in the ecosystem today. The trade-offs sketched are sound enough to inform the decision when the question becomes live, but no consumer is currently blocked.

**Blocker**: The decision turns on a question Timer.Wheel hasn't faced yet — *will the storage strategy ever change away from arena*? Today Timer.Wheel uses arena storage and the boundary bridge is cheap; the unification question only matters if (a) Timer.Wheel migrates to a different storage strategy, OR (b) handle-primitives is being cleaned up and the dep-elimination becomes the goal, OR (c) a second package surfaces the same Handle-vs-Position pattern.

**Resumption trigger** (any of):
- Timer.Wheel storage strategy is being reconsidered (e.g., for hash-map backing or for ~Copyable adoption)
- handle-primitives is being audited for [MOD-RENT] / consolidation per the post-2026-04-26 ecosystem-rent test
- A second consumer surfaces the same pattern (a `Handle<T>`-shaped type backed by arena storage in a different package)

## Provenance

- Source reflection: 2026-03-31-storage-free-arena-bounded-migration.md
