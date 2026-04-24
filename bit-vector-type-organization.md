# Bit Vector Type Organization

<!--
---
version: 1.0.0
last_updated: 2026-02-08
status: RECOMMENDATION
---
-->

## Context

Two primitives packages provide bit vector types with overlapping roles:

| Package | Tier | Types | Storage | Copyable | Growable |
|---------|:----:|-------|---------|:--------:|:--------:|
| swift-bit-vector-primitives | 12 | `Bit.Vector` | `UnsafeMutablePointer<UInt>` (heap) | No | No |
| | | `Bit.Vector.Static<N>` | `InlineArray<N, UInt>` (inline) | Yes | No |
| swift-array-primitives | 15 | `Array<Bit>.Vector` | `ContiguousArray<UInt>` (heap) | Yes | Yes |
| | | `Array<Bit>.Vector.Fixed` | `ContiguousArray<UInt>` (heap) | Yes | No |
| | | `Array<Bit>.Vector.Inline<N>` | `InlineArray<N, UInt>` (inline) | Yes | No |

The array-primitives package is being refactored so that all `Array` variants wrap `Buffer` types. `Array Bit Primitives` is the only target that doesn't follow this pattern — it uses `ContiguousArray<UInt>` directly rather than wrapping `Buffer.Linear`. This refactoring is the trigger for this research.

## Question

What is the correct organizational home for bit vector types, given:
1. Overlapping type roles across two packages
2. Different design philosophies (infrastructure ~Copyable vs. user-facing Copyable)
3. The ongoing array-primitives Buffer-wrapping refactoring
4. Tier architecture constraints

## Analysis

### Decision Inventory

#### Bit.Vector (bit-vector-primitives, tier 12)

**Role**: Low-level infrastructure bitmap. Fixed-capacity, heap-allocated, ~Copyable.

**Consumers** (imports `Bit_Vector_Primitives`):
- `Storage Primitives Core` — `Storage.swift` (slot tracking via `Bit.Vector.Static<4>`)
- `Storage Inline Primitives` — 5 files (slot initialization/move/deinit)
- `Memory Pool Primitives` — `Memory.Pool._allocationBits: Bit.Vector` (double-free detection)
- `Buffer Primitives Core` — `Buffer.Slab.Header.bitmap: Bit.Vector` (slab allocator)
- `Buffer Primitives Core` — `Buffer.Slab.Header.Static<N>.bitmap: Bit.Vector.Static<N>`

**Design characteristics**:
- ~Copyable — forces move semantics, prevents accidental copies of heap bitmaps
- `nonmutating set` on subscript — mutation through raw pointer without exclusive access
- `Ones.View` captures pointer for non-mutating iteration (usable from `deinit`)
- No `append`/`remove`/`resize` — fixed at construction
- Property-based: `.set.all()`, `.clear.all()`, `.set.range()`, `.clear.range()`
- Operations: set, clear, popcount, isEmpty, isFull, ones iteration, word access

#### Array<Bit>.Vector (array-primitives, tier 15)

**Role**: User-facing packed bit array. Dynamically growable, Copyable, collection-conforming.

**Consumers**: None. Only re-exported by the `Array Primitives` aggregate. Zero external imports of `Array_Bit_Primitives`.

**Design characteristics**:
- Copyable — standard value semantics via `ContiguousArray`
- Conforms to `Swift.Sequence`, `Swift.RandomAccessCollection`
- Full collection API: `append`, `removeLast`, `resize`, `removeAll`
- Typed throws: `throws(Array<Bit>.Vector.Error)`
- Bit order support (LSB/MSB) — unique to this type
- Property-based: `.ones.forEach`, `.statistic.true/.false`, `.all.true/.false`, `.toggle.returning()`, `.set.returning()`, `.clear.returning()`, `.byte(at:order:)`
- Byte-level access — unique to this type

#### Array<Bit>.Vector.Fixed (array-primitives, tier 15)

**Role**: Fixed-capacity variant with bounds-checked append/remove.

**Overlaps with**: `Bit.Vector` — both are heap-backed, fixed-capacity. But Fixed is Copyable (ContiguousArray) while Bit.Vector is ~Copyable (UnsafeMutablePointer).

**Unique**: capacity property views (`.capacity.maximum`, `.capacity.remaining`), overflow error on append.

#### Array<Bit>.Vector.Inline<N> (array-primitives, tier 15)

**Role**: Inline-storage variant with bounds-checked append/remove.

**Overlaps with**: `Bit.Vector.Static<N>` — both use `InlineArray<N, UInt>`, both are inline-stored. But Inline has `_count` (variable occupancy) while Static always uses full capacity.

**Unique**: variable count within fixed capacity, append/remove, overflow error.

### Option A: Move All Bit Vectors to bit-vector-primitives

Add growable and bounded variants alongside existing types:

```
Bit.Vector              — existing (~Copyable, heap, fixed)
Bit.Vector.Static<N>    — existing (Copyable, inline, fixed)
Bit.Vector.Dynamic      — new (Copyable, heap, growable)
Bit.Vector.Bounded      — new (Copyable, heap, fixed-capacity + variable count)
Bit.Vector.Inline<N>    — new (Copyable, inline, fixed-capacity + variable count)
```

**Advantages**:
- All bit vector logic in one package — single source of truth for packed-bit operations
- Shared implementation: word masking, Wegner/Kernighan iteration, popcount are identical across all variants
- Clear namespace: `Bit.Vector.*` instead of `Array<Bit>.Vector.*`
- Removes `Array Bit Primitives` target from array-primitives, completing the Buffer-wrapping refactoring
- No tier inflation: bit-vector-primitives stays at tier 12 (no new dependencies needed — the existing dependency set covers everything)

**Disadvantages**:
- Increases bit-vector-primitives scope from 2 types to 5 types
- Collection conformances (`Sequence`, `RandomAccessCollection`) would need `Collection Primitives` as a dependency, potentially raising the tier
- Mixes infrastructure concern (~Copyable `Bit.Vector`) with user-facing concern (Copyable `Bit.Vector.Dynamic`)

### Option B: Keep Separated — bit-vector-primitives for Infrastructure, array-primitives for User-Facing

Leave `Bit.Vector` and `Bit.Vector.Static` in bit-vector-primitives. Keep Array<Bit>.Vector variants in array-primitives but acknowledge they don't follow the Buffer-wrapping pattern.

**Advantages**:
- No changes to working code
- Clear separation: ~Copyable infrastructure vs Copyable user-facing
- bit-vector-primitives stays minimal

**Disadvantages**:
- Array Bit Primitives remains the odd target that doesn't wrap Buffer
- Duplicated bit-packing logic across packages (identical word masking, popcount, iteration)
- Confusing namespace: `Array<Bit>.Vector` implies it's an Array specialization, but it shares zero implementation with `Array<Element>`
- `Array<Bit>.Vector.Inline<N>` and `Bit.Vector.Static<N>` have identical storage (`InlineArray<N, UInt>`) with different APIs — hard to justify two types
- Zero external consumers of `Array_Bit_Primitives`

### Option C: Consolidate into bit-vector-primitives, Without Collection Conformances

Move all types to bit-vector-primitives but keep them as primitives — no `Sequence`/`RandomAccessCollection` conformance. Users who need collection conformance would use a higher-tier integration target.

```
Bit.Vector              — existing (~Copyable, heap, fixed)
Bit.Vector.Static<N>    — existing (Copyable, inline, fixed)
Bit.Vector.Dynamic      — new (Copyable, heap, growable, no collection conformance)
Bit.Vector.Bounded      — new (Copyable, heap, bounded, no collection conformance)
Bit.Vector.Inline<N>    — new or rename Static with added _count)
```

**Advantages**:
- All bit vector logic in one package
- No tier inflation — no collection-primitives dependency
- Clean primitives: bit-level operations without collection protocol baggage
- Collection conformances can be added by a higher-tier integration target if needed
- Consistent with how other primitives work: `Buffer` doesn't conform to `Collection` either

**Disadvantages**:
- Loses `RandomAccessCollection` conformance (subscript-by-index, slicing, etc.)
- Loses `Sequence` conformance on the container (though `ones` iteration remains)
- Users must use `.ones.forEach` pattern instead of `for bit in vector`

### Option D: Consolidate into bit-vector-primitives, Keep Collection via Sequence Primitives

Move all types to bit-vector-primitives. Use `Sequence.Protocol` (already a dependency) for iteration. Add `Swift.Sequence` conformance (already present on `Ones.View`). Skip `RandomAccessCollection`.

**Advantages**:
- All bit vector logic in one package
- No new dependencies — `Sequence_Primitives` is already imported
- `for bit in vector` works via `Swift.Sequence`
- No `Collection Primitives` dependency — tier stays at 12
- Matches existing pattern: `Bit.Vector.Ones.View` already conforms to both `Sequence.Protocol` and `Swift.Sequence`

**Disadvantages**:
- No `RandomAccessCollection` — no O(1) `count`, no slicing, no `index(after:)`
- But: bit vectors already expose `.count` and `.popcount` as direct properties, and subscript access is O(1) — collection protocol conformance adds ceremony more than capability

### Comparison

| Criterion | A: Full consolidation | B: Keep separated | C: No collection | D: Sequence only |
|-----------|:----:|:----:|:----:|:----:|
| Single source of truth | Yes | No | Yes | Yes |
| No duplicated logic | Yes | No | Yes | Yes |
| Clean namespace | Yes | No | Yes | Yes |
| Completes array refactoring | Yes | No | Yes | Yes |
| No tier inflation | Maybe | Yes | Yes | Yes |
| Collection conformance | Full | Full | None | Sequence |
| Infrastructure/user separation | Mixed | Clean | Mixed | Mixed |
| External consumers affected | 0 | 0 | 0 | 0 |
| Implementation effort | High | Zero | Medium | Medium |

### Constraint Analysis

1. **Tier constraint**: bit-vector-primitives is tier 12. Adding `Collection Primitives` (tier 8) would NOT raise the tier — bit-vector already depends on packages at tier 11 (bit-pack). However, it would add a new lateral dependency that isn't strictly necessary.

2. **Zero consumers**: `Array_Bit_Primitives` has zero external consumers. Removal has zero breakage risk.

3. **Naming**: `Array<Bit>.Vector` is semantically misleading. It's not an `Array` specialization — it shares no implementation or conformances with `Array<Element>`. `Bit.Vector.Dynamic` is more honest.

4. **Static vs Inline**: `Bit.Vector.Static<N>` uses full capacity (no `_count`). `Array<Bit>.Vector.Inline<N>` has variable count. These are genuinely different — Static is a pure bitmap, Inline is a bounded container. Both should exist but with clear naming:
   - `Bit.Vector.Static<N>` — full-capacity bitmap (existing)
   - `Bit.Vector.Inline<N>` — variable-count bounded container (new, from Array<Bit>.Vector.Inline)

5. **Buffer pattern**: The array-primitives refactoring wraps Buffer types. A bit vector is NOT a buffer — it doesn't store elements at indices, it stores bits packed into words. The Buffer-wrapping pattern is semantically wrong for bit vectors, which is exactly why Array Bit Primitives doesn't use it.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option D — Consolidate into bit-vector-primitives with Sequence conformance.

### Rationale

1. **Bit vectors are not arrays.** They don't store elements — they pack bits into words. The `Array<Bit>` namespace implies a specialization of `Array` that doesn't exist. `Bit.Vector.*` is the honest namespace.

2. **Zero breakage.** No external consumers of `Array_Bit_Primitives` exist. The only reference is the aggregate re-export in `Array Primitives`.

3. **Completes the array-primitives refactoring.** Removing `Array Bit Primitives` means every remaining array target wraps a Buffer type, achieving the refactoring goal.

4. **No duplicated logic.** Word masking, Wegner/Kernighan iteration, popcount, set/clear/toggle — all identical across both packages. One implementation, one test suite.

5. **No tier inflation.** `Sequence_Primitives` is already a dependency of bit-vector-primitives. `Swift.Sequence` conformance is free.

6. **Collection conformance is unnecessary.** Bit vectors expose `count`, `popcount`, `isEmpty`, `isFull`, and O(1) subscript as direct API. `RandomAccessCollection` conformance would add protocol machinery without adding capability. The primary iteration pattern is `ones.forEach` (sparse iteration of set bits), not sequential traversal — `Sequence` conformance for dense traversal is sufficient.

### Proposed Type Family

| Type | Storage | ~Copyable | Count | Role |
|------|---------|:---------:|-------|------|
| `Bit.Vector` | `UnsafeMutablePointer<UInt>` | Yes | Fixed at capacity | Infrastructure bitmap |
| `Bit.Vector.Static<N>` | `InlineArray<N, UInt>` | No | Fixed at capacity | Inline infrastructure bitmap |
| `Bit.Vector.Dynamic` | `ContiguousArray<UInt>` | No | Variable, growable | User-facing growable bit array |
| `Bit.Vector.Bounded` | `ContiguousArray<UInt>` | No | Variable, bounded | Fixed-capacity with variable count |
| `Bit.Vector.Inline<N>` | `InlineArray<N, UInt>` | No | Variable, bounded | Inline bounded bit container |

### Implementation Path

1. Create `Bit.Vector.Dynamic` in bit-vector-primitives (migrate from `Array<Bit>.Vector`)
2. Create `Bit.Vector.Bounded` in bit-vector-primitives (migrate from `Array<Bit>.Vector.Fixed`)
3. Create `Bit.Vector.Inline<N>` in bit-vector-primitives (migrate from `Array<Bit>.Vector.Inline<N>`)
4. Add `Swift.Sequence` conformance to new types (already have the dependency)
5. Verify all operations are preserved: append, remove, resize, popcount, set, clear, toggle, byte access, property views
6. Remove `Array Bit Primitives` target from swift-array-primitives
7. Update the aggregate `Array Primitives` exports to remove `@_exported import Array_Bit_Primitives`

### Open Questions for Implementation

1. **Should `Bit.Vector.Dynamic` gain byte-level access?** The current `Array<Bit>.Vector` has `.byte(at:order:)`. This is a useful operation but may belong in a separate extension or integration target.

2. **Should `Bit.Vector.Dynamic` gain bit-order support?** The current `subscript(index:order:)` with LSB/MSB support is useful for protocol implementations. Likely yes — it's a bit-level concern.

3. **Should `Bit.Vector.Inline<N>` replace or coexist with `Bit.Vector.Static<N>`?** They have identical storage but different semantics: Static always uses full capacity (pure bitmap), Inline has variable count (bounded container). Both roles are legitimate. Recommendation: coexist.

## References

- Tier architecture: `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md`
- Bit.Vector source: `/Users/coen/Developer/swift-primitives/swift-bit-vector-primitives/Sources/Bit Vector Primitives/`
- Array<Bit>.Vector source: `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Bit Primitives/`
- Storage.Inline usage: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift:185`
- Memory.Pool usage: `/Users/coen/Developer/swift-primitives/swift-memory-primitives/Sources/Memory Pool Primitives/Memory.Pool.swift:75`
- Buffer.Slab usage: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift:347`
