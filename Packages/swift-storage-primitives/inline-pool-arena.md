# Inline Pool and Arena Storage

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
tier: 3
applies_to: [swift-storage-primitives]
normative: true
---
-->

## Context

`Storage.Pool` and `Storage.Arena` are heap-backed (`final class`) with runtime capacity.
`Storage.Inline<N>` is stack-backed (`~Copyable struct`) with compile-time capacity but
only supports manual linear discipline (initialize-next / move-last).

We need pool and arena allocation disciplines on stack storage for use cases where:
- Heap allocation is unacceptable (embedded, real-time, hot paths)
- Capacity is known at compile time
- The `Bounded<N>` index type can eliminate bounds preconditions

## Question

How should we add inline (stack-backed) variants of Pool and Arena storage?

## Analysis

### Three Allocation Disciplines, Two Backing Strategies

| Type | Discipline | Backing | Dealloc | Index |
|------|-----------|---------|---------|-------|
| `Storage.Inline<N>` | Manual (linear) | Stack | Per-slot | `Index<Element>` |
| `Storage.Pool` | Free-list (reuse) | Heap | Per-slot | `Index<Element>` |
| `Storage.Pool.Inline<N>` | Bitmap (reuse) | Stack | Per-slot | `Bounded<N>` |
| `Storage.Arena` | Bump (bulk only) | Heap | Bulk reset | `Index<Element>` |
| `Storage.Arena.Inline<N>` | Bump (bulk only) | Stack | Bulk reset | `Bounded<N>` |

### Pool.Inline Allocation Strategy: Bitmap Scanning

The heap `Storage.Pool` uses an in-band free list: deallocated slots store
the index of the next free slot in the slot's own memory. This requires
`MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size`.

For inline pools, **bitmap scanning** is superior:

1. **Single source of truth** — The `Bit.Vector.Static<4>` bitmap is the sole
   allocation tracker. No secondary free-list structure that could become inconsistent.

2. **No stride constraint** — Works with any `Element` type, including `UInt8`.
   The in-band free list requires element stride >= index size.

3. **Performance for N ≤ 256** — Scanning 4 words (256 bits) via bit-by-bit
   subscript access is O(capacity) worst case. For the target range (≤ 256 elements),
   this is acceptable and avoids the complexity of maintaining a free list.

4. **Simpler implementation** — Allocate scans for first unset bit. Deallocate
   flips a single bit. No pointer manipulation, no sentinel values.

### Bounded Index Integration

`Index<Element>.Bounded<N>` from Finite Primitives eliminates the runtime bounds
check at pointer call sites. Pool.Inline and Arena.Inline return `Bounded<capacity>`
from allocate, and their `pointer(at:)` methods accept `Bounded<capacity>` — making
pointer access precondition-free.

### Arena.Inline Allocation Strategy: Sequential Bump

Arena.Inline uses the same bump strategy as the heap Arena: `_allocated` serves as
both the count and the next-slot cursor. Allocation takes the current count as the
slot index, sets the bit, and increments. Returns `nil` when full.

### Error Handling

- Pool.Inline reuses `Storage.Pool.Error` (`.exhausted`, `.doubleFree`)
- Arena.Inline returns `Optional` (matches heap Arena pattern)

### Layout

Both types use identical stored properties:
- `_storage: _Raw` — `@_rawLayout(likeArrayOf: Element, count: capacity)`
- `_slots: Bit.Vector.Static<4>` — 256-bit allocation bitmap
- `_allocated: Index<Element>.Count` — cached count (avoids O(4) popcount recount)
- `_deinitWorkaround: AnyObject? = nil` — swiftlang/swift#86652

### No `copy()` for Inline Variants

Inline variants are `~Copyable` structs. The heap variants provide `copy()` for
CoW support via reference semantics. Inline types have no reference identity and
no CoW use case.

## Decision

1. Add `Storage.Pool.Inline<let capacity: Int>` — bitmap-scanned pool with per-slot reuse
2. Add `Storage.Arena.Inline<let capacity: Int>` — bump-allocated arena with bulk reset
3. Both types return `Index<Element>.Bounded<capacity>` from allocate
4. Both types accept `Index<Element>.Bounded<capacity>` in `pointer(at:)` (precondition-free)
5. Internal `pointer(at: Index<Element>)` for deinit iteration (unbounded, package-visible)
6. Pool.Inline uses bitmap scanning (not in-band free list)
7. Pool.Inline reuses `Storage.Pool.Error`
8. Arena.Inline returns `Optional` from allocate
9. `Finite Primitives` added as dependency to Core, Pool, and Arena targets
