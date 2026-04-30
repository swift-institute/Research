<!--
---
title: Path Decomposition Delegation Strategy
version: 1.1.0
last_updated: 2026-04-30
status: DEFERRED
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

**Status**: DEFERRED (2026-04-30)

**Disposition**: Investigation didn't advance past the three-option enumeration. Both backing experiments (`path-primitives-decomposition`, `path-parent-span-return`) are CONFIRMED, so the technical feasibility of either span-based or offset-based delegation is settled — what's missing is the API-shape decision when L3 actually consumes L1's decomposition.

**Blocker**: `Paths.Path` (L3) currently re-implements decomposition independently of `Path.View` (L1). The unification work hasn't been triggered because nothing else in the ecosystem is forcing it — the L3 reimplementation works, the L1 scanning is complete, and the boundary inefficiency is bounded.

**Resumption trigger** (any of):
- A consumer of `Paths.Path` decomposition surfaces a performance issue traceable to the L3 re-implementation
- L1 `Path.View` gains additional decomposition variants and the L3 wants to consume them without re-implementing
- A general L3-over-L1 delegation pattern is being formalized (e.g., per [PLAT-ARCH-008e] L3-unifier composition discipline) and this Doc becomes the worked example for span-vs-offset

**Held findings** (apply when the question reactivates): Option C (Hybrid — both `parentBytes() -> Span<Char>?` for direct consumers and `parentLength() -> Int?` for stored/deferred consumers) is the most flexible; the storable-via-Int variant accommodates the `~Escapable` constraint at the API boundary that Span-only delegation cannot.

## Provenance

- Source reflection: 2026-03-31-path-type-compliance-audit-and-l1-decomposition-design.md
- Experiments: path-primitives-decomposition, path-parent-span-return (both CONFIRMED)
