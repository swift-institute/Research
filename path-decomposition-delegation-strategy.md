<!--
---
title: Path Decomposition Delegation Strategy
version: 1.0.0
last_updated: 2026-04-01
status: IN_PROGRESS
tier: 2
scope: cross-package
applies_to: [swift-path-primitives, swift-paths]
normative: false
---
-->

# Path Decomposition Delegation Strategy

## Context

`Paths.Path` (L3) reimplements path decomposition (parent, lastComponent, appending)
independently of `Path.View` (L1). Adding decomposition to L1 creates a delegation
question: how should L3 consume L1's scanning results?

## Question

Should `Paths.Path` decomposition delegate to L1 via `Span<Char>` (zero-alloc sub-view)
or via raw offset computation (`parentLength: Int`)?

## Analysis

### Option A: Span-Based Delegation

L1 returns `Span<Char>?` from `parentBytes()`. L3 constructs owned `Path` from span.

**Pros**: Type-safe, zero-alloc scanning, L1 handles all platform edge cases.
**Cons**: `Span<Char>` is `~Escapable` — cannot be stored or returned from Property.View
methods without closure-based access ([MEM-LIFE-005], [IMPL-079]). Adds lifetime complexity
at the delegation boundary.

### Option B: Offset-Based Delegation

L1 returns `Int` (byte count of parent prefix). L3 slices its own storage at that offset.

**Pros**: No `~Escapable` complexity, trivially storable/returnable, minimal API surface.
**Cons**: Exposes a raw integer at the API boundary, caller must validate offset correctness.

### Option C: Hybrid

L1 provides both: `parentBytes() -> Span<Char>?` for direct consumers and
`parentLength() -> Int?` for stored/deferred consumers.

## Outcome

(Pending investigation)

## Provenance

- Source reflection: 2026-03-31-path-type-compliance-audit-and-l1-decomposition-design.md
- Experiments: path-primitives-decomposition, path-parent-span-return (both CONFIRMED)
