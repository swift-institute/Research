# Storage.Pool Architecture: Composition vs Independence

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: SUPERSEDED
tier: 3
applies_to: [swift-storage-primitives, swift-memory-primitives, swift-buffer-primitives]
normative: false
superseded_by: ../Research/memory-storage-composition-feasibility.md
---
-->

> **Status**: SUPERSEDED (2026-03-15)
> **Superseded by**: `memory-storage-composition-feasibility.md` (2026-02-11)
> This document concluded Option B (independent implementation). That conclusion was explicitly reversed by the follow-up feasibility analysis, which demonstrated all friction points are resolvable at zero runtime cost. The current code implements composition: `Storage.Pool` stores `_pool: Memory.Pool` and delegates all operations via `.retag()` and `.assumingMemoryBound(to:)`.
> It remains as historical context for why composition was initially rejected.

## Context

Buffer.Linked needs a typed, reference-semantic pool allocator with:
- O(1) allocate/deallocate via free list
- Per-slot bitmap tracking (Bit.Vector) for deinit iteration
- Reference semantics (for conditional Copyability in buffer compositions)
- CoW support (for value-semantic data structures)
- Index<Element> API (no raw extraction at call sites)
- Automatic element deinit in class deinit (via bitmap iteration)
- Typed sentinel for free list termination (from pool-free-list-representation.md DECISION)

Memory.Pool already exists at Tier 10 implementing the same pattern at the raw memory layer:
typed sentinel, Bit.Vector tracking, in-band free list, O(1) alloc/dealloc.

The normative synthesis document (storage-ownership-reference-synthesis.md, DECISION v3.0.0)
states: "Pool<Element> is `Memory.Pool` + typed access."

## Question

What is the architecturally correct implementation strategy for Storage.Pool?
Specifically: should Storage.Pool compose Memory.Pool, or implement independently?

## Prior Art Survey

### Allocator Literature: Layered Composition is Universal

| System | Typed Layer | Raw Layer | Composition? |
|--------|-------------|-----------|:------------:|
| Bonwick 1994 | Object cache (per-type) | vmem | Yes |
| Bonwick/Adams 2001 | Slab cache | vmem | Yes |
| jemalloc | Bins (per size-class) | Extent allocator | Yes |
| TCMalloc | Size-class free lists | Page heap | Yes |
| mimalloc | Per-page free lists | Segment allocator | Yes |
| C++ pmr | pool_resource | upstream_resource | Yes |
| Rust | typed-arena, slotmap | GlobalAlloc / Allocator trait | Yes |

Every major allocator layers typed pools on raw backing allocators.

### Swift Memory Model: Deliberate Raw/Typed Split

SE-0107 establishes: `raw allocate -> bind -> typed access -> deinitialize -> raw deallocate`.
SE-0426 constrains: `storeBytes`/`load` require BitwiseCopyable. Free list links
(Index<T> = trivial wrapper over UInt) qualify. Arbitrary Element types may not.

The pool already has an inherent raw/typed split:
- Free list operations: raw (`storeBytes`/`load` of Index<T> in deinitialized memory)
- Element operations: typed (`initialize`/`move`/`deinitialize` of Element)

### Existing Codebase: Storage.Heap Precedent

Storage.Heap extends ManagedBuffer<Header, Element> -- a stdlib type.
It does NOT compose Memory.Buffer. The storage layer operates on
UnsafeMutablePointer<Element> directly.

### Key References

- Bonwick, "The Slab Allocator" (USENIX 1994)
- Bonwick & Adams, "Magazines and Vmem" (USENIX 2001)
- Leijen et al., "mimalloc: Free List Sharding in Action" (APLAS 2019)
- Rust slotmap, generational-arena: typed slot reuse with generational indices
- Apple kalloc_type: type-segregated kernel allocation
- Rust RFC 1398: Layout as the raw/typed boundary abstraction
- SE-0107: UnsafeRawPointer API (raw/typed separation)
- SE-0426: BitwiseCopyable (storeBytes/load constraint)
- SE-0390/SE-0427: ~Copyable types -- classes CAN store ~Copyable properties
- SE-0437: ManagedBuffer supports Element: ~Copyable (but Header must be Copyable)

## Analysis

### Option A: Direct Composition -- Storage.Pool wraps Memory.Pool

Storage.Pool (final class) stores Memory.Pool (~Copyable struct) as a property.
Delegates allocate/deallocate to Memory.Pool. Adds typed element access.

```
Storage<Node>.Pool (class, Tier 12)
  +-- Memory.Pool (struct: ~Copyable, Tier 10)
        +-- UnsafeMutableRawPointer (OS allocation)
```

**Implementation sketch:**
```swift
public final class Pool {
    var _rawPool: Memory.Pool  // ~Copyable struct in class (Ownership.Mutable precedent)

    func allocate() throws(Error) -> Index<Element> {
        let rawPtr = try _rawPool.allocate()
        return _rawPool.slotIndex(for: rawPtr)!.retag(Element.self)
    }

    func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _rawPool.pointer(at: slot.retag(Memory.Pool.Slot.self))
            .assumingMemoryBound(to: Element.self)
    }

    deinit {
        for bitIndex in _rawPool._allocationBits.ones {
            unsafe pointer(at: bitIndex.retag(Element.self)).deinitialize(count: 1)
        }
        // Memory.Pool.deinit runs automatically -> deallocates raw memory
    }
}
```

**Advantages:**
- Follows normative synthesis document ("Pool<Element> is Memory.Pool + typed access")
- Follows allocator literature (typed on raw, universal pattern)
- Follows SE-0107 raw/typed lifecycle
- DRY: free list, bitmap, sentinel logic shared with Memory.Pool
- Memory.Pool already tested (121 tests)

**Disadvantages:**
- API translation: every operation needs `.retag()` at the composition boundary
  (Index<Slot> <-> Index<Element>, UnsafeMutableRawPointer -> UnsafeMutablePointer<Element>)
- Memory.Pool.allocate() returns pointer, not index -- must reverse-lookup via slotIndex(for:)
- Memory.Pool pre-builds free list O(n) -- need to modify Memory.Pool for virgin cursor
- Memory.Pool._allocationBits is internal -- need to expose for deinit iteration
- Memory.Pool takes runtime slotSize/alignment -- must compute from MemoryLayout<Element>
- Memory.Pool uses Affine.Discrete.Ratio<Slot, Memory> stride -- unnecessary at storage layer
- CoW copy() requires deep-copying a ~Copyable struct (Memory.Pool has no copy method)
- Changes to a working, tested type (Memory.Pool) introduce regression risk

**Required changes to Memory.Pool:**
1. Add index-based allocate/deallocate (not just pointer-based)
2. Add virgin cursor option (O(1) init)
3. Expose bitmap iteration API (for Storage.Pool deinit)
4. Add copy capability (for CoW)
5. These are non-trivial changes to a recently stabilized type

### Option B: Independent Implementation -- same pattern, different types

Storage.Pool implements its own allocation logic directly.
Uses UnsafeMutablePointer<Element> + Bit.Vector + typed sentinel.
Shares the DESIGN PATTERN with Memory.Pool, not the code.

```
Storage<Node>.Pool (class, Tier 12)
  +-- UnsafeMutablePointer<Element> (stdlib typed allocation)

Memory.Pool (struct: ~Copyable, Tier 10) -- independent, serves raw-byte consumers
  +-- UnsafeMutableRawPointer (OS allocation)
```

**Advantages:**
- Natural Index<Element> API -- no translation at any level
- O(1) virgin cursor init -- clean design from the start
- Simple class with UnsafeMutablePointer -- no wrapping overhead
- Copy for CoW straightforward (allocate new buffer, copy elements via bitmap)
- No changes to Memory.Pool -- no regression risk
- Follows Storage.Heap precedent (doesn't wrap Memory.Buffer)
- All operations are 2-3 lines each -- minimal "duplication"

**Disadvantages:**
- Apparent DRY violation (~40 lines of pattern overlap with Memory.Pool)
- Does not literally compose Memory.Pool as the synthesis document envisions
- Two implementations of the same design pattern to maintain

### Option C: Shared Core Abstraction

Extract the slot allocation pattern into a shared generic type or protocol
used by both Memory.Pool and Storage.Pool.

**Advantages:**
- Maximally DRY
- Both implementations share tested core

**Disadvantages:**
- Premature abstraction per [PATTERN-013] (only 2 conformers)
- The "shared" core would need to be parameterized across:
  struct vs class, Index<Slot> vs Index<Element>, raw vs typed pointer,
  pre-built vs virgin cursor -- becoming more complex than either standalone impl
- Adds infrastructure dependency between memory-primitives and storage-primitives
  (or requires a new shared package)

## Evaluation

### Quantifying the "Duplication"

The shared pattern between Memory.Pool and Storage.Pool:

| Operation | Lines | Identical? |
|-----------|-------|:----------:|
| allocate (pop free list) | 5 | No -- different pointer/index types |
| deallocate (push free list) | 5 | No -- different pointer/index types |
| sentinel computation | 1 | Identical concept, different phantom type |
| bitmap set/clear | 1 each | Near-identical (.retag at boundary) |
| properties (capacity, etc.) | 5 | Near-identical |

Total overlap: ~20 lines of structurally similar (not identical) code.
Per [IMPL-000] absorbed anti-patterns: "three similar lines of code is
better than a premature abstraction."

### Reconciling with the Synthesis Document

The synthesis document (line 218) says: "Pool<Element> is `Memory.Pool` + typed access."

Two valid readings:
1. **Code composition**: Storage.Pool wraps a Memory.Pool instance
2. **Conceptual derivation**: Storage.Pool is the typed-element version of the
   Memory.Pool pattern, just as Storage.Heap is the typed-element version of
   the ManagedBuffer pattern

Reading 2 is consistent with how Storage.Heap works: it IS ManagedBuffer + typed
tracking (initialization state, spans), but it extends ManagedBuffer directly --
it doesn't wrap a Memory.Buffer instance. The typed/untyped relationship is at
the design level, not the composition level.

The synthesis document's Proposal C places Pool at the MEMORY tier, not the
storage tier. It says typed access flows through stdlib pointer types. This
describes the consumer-side pattern: "use Memory.Pool, then bind memory to
typed pointers." It does not prescribe a separate Storage.Pool type.

Storage.Pool emerges from a need the synthesis document didn't anticipate:
**reference-semantic pool storage for conditional Copyability in buffer compositions**.
This is a storage-tier concern (like Storage.Heap being a class for CoW) that
doesn't exist at the memory tier.

### Layer Analysis

| Concern | Memory Tier (Pool) | Storage Tier (Pool) |
|---------|-------------------|---------------------|
| Allocation | UnsafeMutableRawPointer | UnsafeMutablePointer<Element> |
| Free list | Index<Slot>, typed sentinel | Index<Element>, typed sentinel |
| Tracking | Bit.Vector | Bit.Vector |
| Ownership | struct: ~Copyable (value) | final class (reference) |
| Element lifecycle | Caller responsibility | Class deinit via bitmap |
| CoW | N/A | isKnownUniquelyReferenced + copy() |
| Conditional Copyability | Always ~Copyable | Copyable (reference type) |
| Init cost | O(n) pre-built | O(1) virgin cursor |
| Consumer | Raw-byte-level code | Buffer.Linked, data structures |

These are the SAME design pattern at DIFFERENT abstraction levels with DIFFERENT
concrete requirements. The typed pool is the storage-tier analog of the memory-tier
pool, not a wrapper around it.

## Comparison

| Criterion | A (compose) | B (independent) | C (shared core) |
|-----------|:-----------:|:---------------:|:----------------:|
| Follows synthesis doc literally | 4/4 | 2/4 | 3/4 |
| Follows synthesis doc in spirit | 3/4 | 4/4 | 3/4 |
| Follows allocator literature | 4/4 | 2/4 | 3/4 |
| Follows Storage.Heap precedent | 1/4 | 4/4 | 2/4 |
| Natural API (no translation) | 2/4 | 4/4 | 4/4 |
| DRY | 4/4 | 2/4 | 4/4 |
| No changes to Memory.Pool | 0/4 | 4/4 | 2/4 |
| Regression risk | 1/4 | 4/4 | 2/4 |
| Implementation simplicity | 2/4 | 4/4 | 1/4 |
| Supports virgin cursor | 2/4 | 4/4 | 4/4 |
| CoW copy() | 1/4 | 4/4 | 2/4 |
| Premature abstraction risk | 4/4 | 4/4 | 1/4 |

## Outcome

**Status**: DECISION

**Option B: Independent Implementation.**

Storage.Pool implements the typed sentinel pattern independently, using
UnsafeMutablePointer<Element> directly. It shares the design pattern with
Memory.Pool (typed sentinel, Bit.Vector tracking, in-band free list) but
not the code.

**Rationale:**

1. **The design pattern, not the code, is the reusable artifact.** The typed
   sentinel pattern (pool-free-list-representation.md, DECISION) is a design
   decision. Both Memory.Pool and Storage.Pool implement it. The ~20 lines of
   structurally similar code do not warrant a shared abstraction for 2 consumers.

2. **Different abstraction levels have different concrete requirements.** Memory.Pool
   is a value-type, raw-pointer, O(n)-init, Index<Slot> allocator for byte-level
   consumers. Storage.Pool is a reference-type, typed-pointer, O(1)-init,
   Index<Element> allocator for data structure consumers. Forcing composition
   between these mismatched types creates translation overhead everywhere.

3. **Storage.Heap precedent.** Storage.Heap is the typed-element version of
   ManagedBuffer, but it extends ManagedBuffer directly -- it does not compose
   Memory.Buffer. The relationship between memory-tier and storage-tier types
   is analogous (same concept, different layer), not compositional (wrapper/wrappee).

4. **The synthesis document's intent is preserved.** "Pool<Element> is
   `Memory.Pool` + typed access" describes the conceptual relationship:
   Storage.Pool is the typed version of the Memory.Pool pattern. This is
   satisfied by independent implementation of the same design, just as
   Storage.Heap satisfies the typed version of raw heap allocation without
   wrapping Memory.Buffer.

5. **Risk management.** Memory.Pool is recently stabilized (121 tests, typed
   sentinel rewrite just completed). Modifying it to support composition would
   introduce regression risk for no consumer-visible benefit.

**Amendment to synthesis document:** Phase 2 should be updated to reflect that
Storage.Pool is a storage-tier type (final class, Tier 12) implementing the
Memory.Pool design pattern with typed access, not a wrapper around Memory.Pool.
Memory.Pool remains at Tier 10 for raw-byte consumers.

## References

### Academic
- Bonwick, "The Slab Allocator" (USENIX 1994)
- Bonwick & Adams, "Magazines and Vmem" (USENIX 2001)
- Leijen et al., "mimalloc: Free List Sharding in Action" (APLAS 2019, MSR-TR-2019-18)
- Deutsch, "slot_map Container in C++" (WG21 P0661R0, 2017)
- Tofte & Talpin, "Region-Based Memory Management" (1997)

### Swift Evolution
- SE-0107: UnsafeRawPointer API (raw/typed separation)
- SE-0390: Noncopyable Structs and Enums
- SE-0426: BitwiseCopyable (storeBytes/load constraint)
- SE-0427: Noncopyable Generics (classes with ~Copyable properties)
- SE-0437: Noncopyable Standard Library Primitives (ManagedBuffer generalization)

### Industrial
- jemalloc (Facebook): bins -> extent allocator
- TCMalloc (Google): size-class lists -> page heap
- Apple kalloc_type: type-segregated kernel allocation

### Internal
- pool-free-list-representation.md (DECISION) -- typed sentinel pattern
- storage-ownership-reference-synthesis.md (DECISION v3.0.0) -- layered split, Phase 2
- storage-primitives-comparative-analysis.md (RECOMMENDATION) -- gap: no pool at storage tier

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-10)
**New status**: DEFERRED

**Blocker/Reason**: Document reached DECISION status (Option B: independent implementation) on 2026-02-10 but frontmatter was never updated from IN_PROGRESS. The decision is made; remaining work is implementation of Storage.Pool and amendment of the synthesis document. No active research questions remain. Deferred because implementation has not been prioritized.

**Contradiction note**: This document's decision (Option B: Storage.Pool implements independently, sharing the design pattern but not the code with Memory.Pool) contradicts the normative synthesis document `storage-ownership-reference-synthesis.md` (DECISION v3.0.0, line 218), which states "Pool<Element> is Memory.Pool + typed access" (implying composition). Section "Reconciling with the Synthesis Document" argues the synthesis document's intent is satisfied by independent implementation of the same design. This contradiction needs explicit resolution: either amend the synthesis document per this decision's recommendation, or revisit this decision. Until resolved, both documents claim normative authority with incompatible positions.

**Resumption trigger**: When Storage.Pool implementation is prioritized, or when the synthesis document is next revised.
