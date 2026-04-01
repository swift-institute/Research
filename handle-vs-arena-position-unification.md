<!--
---
title: Handle vs Arena.Position Unification
version: 1.0.0
last_updated: 2026-04-01
status: IN_PROGRESS
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

(Pending investigation)

## Provenance

- Source reflection: 2026-03-31-storage-free-arena-bounded-migration.md
