# Pool Free List Representation

<!--
---
version: 1.0.0
last_updated: 2026-02-10
status: DECISION
---
-->

## Context

`Memory.Pool` uses an in-band free list: each free slot stores the index of the
next free slot in its own memory. The original implementation serialized
`Index<Slot>?` to raw `UInt` with `UInt.max` as the nil sentinel. This required
`.rawValue.rawValue` extraction at every store and `__unchecked` reconstruction
at every load — violating [IMPL-002].

An intermediate fix confined these chains to helper methods (`_storeFreeNext`,
`_loadFreeNext`). This masks the problem without solving it. The type system
should enforce the invariants directly.

## Question

What is the type-theoretically correct representation for the Pool's in-band
free list links, such that no raw value extraction or unchecked construction
appears anywhere in the implementation?

## Analysis

### Option A: Helper Methods (status quo after first fix)

Confine `.rawValue.rawValue` and `__unchecked` to two internal methods.

- **Advantages**: Minimal change; call sites are clean.
- **Disadvantages**: Helpers mask the gap. The raw extraction still exists — it's
  just in fewer places. Not a type-system solution.

### Option B: Typed Sentinel with Direct Store/Load

Change the free list link type from `Optional<Index<Slot>>` serialized as `UInt`
to `Index<Slot>` stored directly, using the capacity-as-ordinal as a typed
end-of-list sentinel.

Key observations:

1. `Index<Slot>` = `Tagged<Slot, Ordinal>` = single-field struct wrapping
   `Ordinal` wrapping `UInt`. It is trivial (no references, no deinit).
   `MemoryLayout<Index<Slot>>.size == MemoryLayout<UInt>.size`.

2. `UnsafeMutableRawPointer.storeBytes(of:as:)` and `.load(as:)` operate on
   the byte representation. For trivial single-field wrappers, the bytes are
   identical to the inner value's bytes.

3. The sentinel value `_capacity.map(Ordinal.init)` is the natural end position
   of the index space — analogous to `endIndex` in Swift collections. It is a
   valid `Ordinal` (non-negative) but not a valid slot (>= capacity). No
   special encoding needed.

4. `_freeHead` becomes `Index<Slot>` (non-Optional). Exhaustion is checked by
   `_freeHead == _sentinel` — a typed comparison per [IMPL-004].

- **Advantages**: Zero raw value extraction. Zero `__unchecked` construction.
  Zero helpers. The type flows through store/load directly. The sentinel is
  derivable from capacity, not an arbitrary magic constant. All comparisons are
  typed.
- **Disadvantages**: Requires that `Index<Slot>` is trivially storable via raw
  pointer operations. This holds because `Tagged` and `Ordinal` are single-field
  value types with no references.

### Option C: Generic Boundary Overloads on UnsafeMutableRawPointer

Add `storeBytes(of: Tagged<T, Ordinal>)` and `load(as: Tagged<T, Ordinal>.Type)`
overloads to the stdlib integration layer.

- **Advantages**: Reusable across the ecosystem.
- **Disadvantages**: Does not address the sentinel/Optional conversion. Still
  needs Option A or B for the sentinel logic. Additive — could complement
  Option B if the direct store/load approach ever needs explicit overloads.

### Option D: Dedicated FreeList.Link Type

Wrap the sentinel convention in a dedicated `Pool.FreeList.Link` type.

- **Advantages**: Fully explicit about the sentinel encoding.
- **Disadvantages**: Over-engineering. The sentinel is a single comparison. A
  dedicated type adds abstraction for a pattern that's standard in systems
  programming (one-past-end sentinel in array-based free lists).

### Comparison

| Criterion            | A (helpers) | B (typed sentinel) | C (overloads) | D (link type) |
|----------------------|-------------|---------------------|---------------|---------------|
| Raw extraction sites | 2           | 0                   | 2 (in layer)  | 0             |
| `__unchecked` sites  | 1           | 0                   | 1 (in layer)  | 0             |
| Optional conversion  | Yes         | No                  | Yes           | No            |
| Type flows through   | No          | Yes                 | Partially     | Yes           |
| New infrastructure   | None        | None                | Generic       | Package-local |
| Complexity           | Low         | Low                 | Medium        | High          |

## Outcome

**Status**: DECISION

**Option B: Typed Sentinel with Direct Store/Load.**

The representation change eliminates raw extraction at the source. The free list
stores `Index<Slot>` values directly via `storeBytes(of:as:)` / `load(as:)`.
End-of-list is the typed sentinel `_capacity.map(Ordinal.init)`. `_freeHead`
becomes non-Optional. All comparisons remain typed. No helpers, no raw
extraction, no `__unchecked` reconstruction.

The sentinel is principled: it is the one-past-end position of the slot index
space, the same concept as `endIndex` in Swift collections. It is not an
arbitrary magic constant (`UInt.max`) — it is derivable from the pool's own
capacity.

## References

- [IMPL-002] Write the Math, Not the Mechanism
- [IMPL-004] Typed Comparisons
- [IMPL-010] Push Int to the Edge
- [PATTERN-017] rawValue and Property Access Location
- Swift stdlib: `UnsafeMutableRawPointer.storeBytes(of:toByteOffset:as:)`
- Swift stdlib: `UnsafeMutableRawPointer.load(fromByteOffset:as:)`
