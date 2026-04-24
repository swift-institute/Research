# Memory-Storage Composition Feasibility: Can Memory Types Be Modified to Enable Composition?

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-memory-primitives, swift-storage-primitives]
normative: false
---
-->

## Context

The previous research (`memory-pool-arena-buffer-usage-analysis.md`) recommended
removing Memory.Pool, Memory.Arena, and Memory.Buffer based on zero consumers.
The `storage-pool-architecture.md` research chose independent implementation for
Storage.Pool, citing fundamental mismatches with Memory.Pool.

This follow-up challenges that conclusion. Rather than asking "are these types
used?" it asks "can they be MADE usable?" — specifically, what changes to
memory-primitives types would enable storage-primitives to compose them, and
do any of those changes degrade either layer?

## Question

Can Memory.Pool, Memory.Arena, and Memory.Buffer be modified such that
Storage.Pool, Storage.Arena, and (future) Storage.Buffer can compose them
without drawbacks to either the memory-primitives or storage-primitives types?

## Prior Art

### Allocator Literature: Composition is the Norm

As documented in `storage-pool-architecture.md` §Prior Art, every major allocator
layers typed pools on raw backing allocators (Bonwick slab cache on vmem, jemalloc
bins on extent allocator, C++ pmr pool_resource on upstream_resource, Rust
typed-arena on GlobalAlloc). The industry consensus is that typed allocation
composes raw allocation.

### SE-0107: The Raw/Typed Split is the Intended Pattern

Swift's own memory model (SE-0107) prescribes: raw allocate → bind → typed access
→ deinitialize → raw deallocate. This is exactly what composition would look like:
Memory.Pool handles raw allocate/deallocate; Storage.Pool handles bind/typed/deinit.

### SE-0427: Classes Can Store ~Copyable Properties

`final class` can store `~Copyable` struct properties. This means Storage.Pool
(class) can store Memory.Pool (struct: ~Copyable) directly. No boxing or
indirection needed.

## Analysis

### Friction Point Inventory

A line-by-line comparison of Memory.Pool (326 lines) and Storage.Pool (~310 lines
across 3 files) identifies 11 friction points. Each is evaluated for resolvability
and impact on both layers.

#### F1: Value type (struct) vs Reference type (class)

**Memory.Pool**: `struct: ~Copyable`
**Storage.Pool**: `final class`

**Resolution**: Storage.Pool stores Memory.Pool as a property inside the class.
SE-0427 permits `~Copyable` struct properties in classes. Memory.Pool's deinit
runs automatically when the class deinits.

**Impact on Memory.Pool**: None.
**Impact on Storage.Pool**: One property instead of six stored properties.

#### F2: Raw pointers vs Typed pointers

**Memory.Pool._storage**: `UnsafeMutableRawPointer`
**Storage.Pool._storage**: `UnsafeMutablePointer<Element>`

**Memory.Pool.pointer(at:)**: returns `UnsafeMutableRawPointer`
**Storage.Pool.pointer(at:)**: returns `UnsafeMutablePointer<Element>`

**Resolution**: Storage.Pool calls `_pool.pointer(at:).assumingMemoryBound(to:)`.
Per SE-0107, `assumingMemoryBound` is a zero-cost type cast — it changes the
pointer type without any runtime operation.

**Impact on Memory.Pool**: None.
**Impact on Storage.Pool**: One `assumingMemoryBound` call per pointer access.
Zero runtime cost.

#### F3: Index\<Slot\> vs Index\<Element\>

**Memory.Pool**: uses `Index<Slot>` (where `Slot` is its own phantom type)
**Storage.Pool**: uses `Index<Element>` (where `Element` is the generic parameter)

**Resolution**: `.retag()` at each composition boundary. Since `Index<T>` is
`Tagged<T, Ordinal>`, retag is a compile-time phantom type change with zero
runtime cost. All typed arithmetic (Offset, Count) also retags at zero cost.

**Impact on Memory.Pool**: None.
**Impact on Storage.Pool**: One `.retag()` call per index crossing. Zero runtime
cost.

#### F4: O(n) free list pre-build vs O(1) virgin cursor

**Memory.Pool**: Pre-builds entire free list in init, O(n):
```swift
// Memory.Pool.init, lines 138-148:
var slot: Index<Slot> = .zero
while slot < sentinel {
    let next = slot + .one
    unsafe _pointer(at: slot).storeBytes(
        of: (next < sentinel) ? next : sentinel,
        as: Index<Slot>.self
    )
    slot += .one
}
```

**Storage.Pool**: O(1) virgin cursor (`_nextUnused`), defers free list construction.

**Resolution**: Add virgin cursor to Memory.Pool. This is a **pure improvement** —
O(1) init is strictly better than O(n) for all consumers. The virgin cursor pattern:

```swift
// allocate() checks free list first, then virgin cursor:
if _freeHead != _sentinel {
    // pop from free list (reused slot)
} else if _nextUnused < _sentinel {
    // advance virgin cursor (fresh slot)
} else {
    throw .exhausted(capacity:)
}
```

**Impact on Memory.Pool**: Performance improvement. One new stored property
(`_nextUnused: Index<Slot>`). Init changes from O(n) to O(1). Allocate adds
one branch. Reset remains O(n) (must rebuild free list for reused slots, or
simply reset virgin cursor — actually becomes O(1) too).

**Impact on Storage.Pool**: Removes the O(n) vs O(1) mismatch entirely.

#### F5: allocate() returns pointer vs index

**Memory.Pool.allocate()**: returns `UnsafeMutableRawPointer`
**Storage.Pool.allocate()**: returns `Index<Element>`

**Resolution**: Add index-based allocate to Memory.Pool:

```swift
/// Allocates a slot and returns its index.
public mutating func allocateSlot() throws(Error) -> Index<Slot>
```

The existing `allocate() -> UnsafeMutableRawPointer` becomes a convenience
that calls `allocateSlot()` and converts:

```swift
public mutating func allocate() throws(Error) -> UnsafeMutableRawPointer {
    let slot = try allocateSlot()
    return _pointer(at: slot)
}
```

**Impact on Memory.Pool**: Pure API extension. Existing API preserved. New
method is the natural primitive — the original pointer-based API was always
computing an index internally and then converting.

**Impact on Storage.Pool**: Direct access to slot index. No reverse-lookup
needed.

#### F6: deallocate takes pointer vs index

**Memory.Pool.deallocate()**: takes `UnsafeMutableRawPointer`, reverse-lookups
via `slotIndex(for:)` which validates alignment, bounds, and stride.

**Storage.Pool.deallocate(at:)**: takes `Index<Element>` directly.

**Resolution**: Add index-based deallocate to Memory.Pool:

```swift
/// Returns a slot to the free list by index.
public mutating func deallocate(at slot: Index<Slot>) throws(Error)
```

The existing pointer-based `deallocate(_:)` becomes a convenience that
reverse-lookups the index and delegates. The index-based version skips
the foreign pointer check (indices are inherently bounded by construction).

**Impact on Memory.Pool**: Pure API extension. Eliminates unnecessary
foreign-pointer validation for index-based consumers.

**Impact on Storage.Pool**: Direct index-based deallocation. No reverse-lookup.

#### F7: \_allocationBits is internal — Storage.Pool needs it for deinit

Storage.Pool's `deinit` iterates allocation bits to deinitialize elements.
Memory.Pool's `_allocationBits` is `internal`.

**Resolution**: Expose allocated-slot iteration:

```swift
/// Indices of all currently allocated slots.
public var allocatedSlotIndices: Bit.Vector.Ones { _allocationBits.ones }
```

This is a natural API — any consumer that needs to iterate occupied slots
(for cleanup, serialization, inspection) needs this.

**Impact on Memory.Pool**: One public computed property. Exposes existing
Bit.Vector.Ones iterator (already public type from bit-vector-primitives).

**Impact on Storage.Pool**: Clean deinit via iteration.

#### F8: Runtime slot size vs Compile-time MemoryLayout

**Memory.Pool**: `slotSize: Memory.Address.Count` (runtime parameter)
**Storage.Pool**: Uses `MemoryLayout<Element>.stride` (compile-time)

**Resolution**: No change needed. Storage.Pool passes the compile-time
value as Memory.Pool's runtime parameter:

```swift
try Memory.Pool(
    slotSize: Memory.Address.Count(UInt(MemoryLayout<Element>.stride)),
    slotAlignment: Memory.Alignment(MemoryLayout<Element>.alignment),
    capacity: capacity.retag(Memory.Pool.Slot.self)
)
```

Memory.Pool's runtime parameter is MORE flexible — it serves raw-byte
consumers with non-standard slot sizes. Storage.Pool simply constrains
it to `MemoryLayout<Element>.stride`.

**Impact on Memory.Pool**: None.
**Impact on Storage.Pool**: None (passes compile-time value as runtime parameter).

#### F9: No copy capability for CoW

Storage.Pool needs deep copy for copy-on-write. Memory.Pool is `~Copyable`
with no duplication method. This was identified by the previous research
as the hardest friction point.

**Resolution**: Add `duplicate(copySlotContents:)` to Memory.Pool:

```swift
/// Creates a new pool with identical allocation topology.
///
/// For each allocated slot, calls `copySlotContents` with source and
/// destination raw pointers. The caller is responsible for typed
/// element copying. Free list links are copied automatically.
///
/// - Parameter copySlotContents: Called once per allocated slot.
/// - Returns: A new pool with identical structure and caller-copied contents.
public borrowing func duplicate(
    copySlotContents: (_ source: UnsafeRawPointer,
                       _ destination: UnsafeMutableRawPointer) -> Void
) -> Memory.Pool
```

Implementation:
1. Allocate new backing storage (same capacity)
2. Copy virgin cursor, free head, allocated count
3. Iterate slots below virgin cursor:
   - Allocated (bit set): call `copySlotContents(source, destination)`
   - Freed (bit clear): raw-copy free list link bytes
4. Return new Memory.Pool with new storage and copied allocation bits

Storage.Pool.copy() becomes:

```swift
public func copy() -> Storage.Pool {
    let newPool = _pool.duplicate { source, destination in
        let src = source.assumingMemoryBound(to: Element.self)
        let dst = UnsafeMutablePointer<Element>(
            mutating: destination.assumingMemoryBound(to: Element.self)
        )
        dst.initialize(to: src.pointee)
    }
    return Storage.Pool(wrapping: newPool)
}
```

**Impact on Memory.Pool**: One new public method. Well-motivated even without
Storage.Pool — any consumer that needs to fork a pool's state needs this. The
callback pattern cleanly separates raw structure duplication (Memory.Pool's
responsibility) from typed element copying (caller's responsibility). This
aligns with SE-0107's raw/typed separation.

**Impact on Storage.Pool**: CoW becomes a one-method delegation with a typed
callback. Simpler than the current 35-line manual implementation.

#### F10: Affine.Discrete.Ratio stride type

**Memory.Pool**: `_slotStride: Affine.Discrete.Ratio<Slot, Memory>` for
byte-domain stride arithmetic.

**Storage.Pool**: Uses typed pointer arithmetic where stride is implicit.

**Resolution**: No change needed. Storage.Pool uses `pointer(at:)` which
handles the stride internally. The Ratio type is an internal implementation
detail of Memory.Pool that Storage.Pool never sees.

**Impact on Memory.Pool**: None.
**Impact on Storage.Pool**: None (encapsulated behind `pointer(at:)` API).

#### F11: foreignPointer error case

**Memory.Pool**: Has `foreignPointer` error for pointer-based deallocate.
**Storage.Pool**: No equivalent (index-based API, indices are bounded by
construction).

**Resolution**: No change needed. Index-based `deallocate(at:)` (F6) skips
this check entirely. The pointer-based API retains the check for raw-byte
consumers.

**Impact on Memory.Pool**: None.
**Impact on Storage.Pool**: None (uses index-based API).

### Friction Summary

| # | Friction | Resolution | Memory.Pool Impact | Storage.Pool Impact | Runtime Cost |
|---|---------|-----------|-------------------|--------------------|----|
| F1 | struct vs class | Store as property | None | One property | Zero |
| F2 | Raw vs typed ptr | assumingMemoryBound | None | One cast/access | Zero |
| F3 | Index\<Slot\> vs Index\<Element\> | .retag() | None | One retag/operation | Zero |
| F4 | O(n) vs O(1) init | Add virgin cursor | **Improvement** | None | **Negative** (faster) |
| F5 | allocate returns ptr vs idx | Add index-based API | API extension | Direct access | Zero |
| F6 | deallocate takes ptr vs idx | Add index-based API | API extension | Direct access | Zero |
| F7 | \_allocationBits internal | Expose iteration | API extension | Clean deinit | Zero |
| F8 | Runtime vs compile-time size | Pass as runtime param | None | None | Zero |
| F9 | No copy for CoW | Add duplicate(copy:) | API extension | Simpler copy() | Zero |
| F10 | Stride type | Encapsulated | None | None | Zero |
| F11 | foreignPointer check | Use index-based API | None | None | Zero |

**Key finding**: Every friction point is resolvable. No resolution degrades
Memory.Pool — F4 is an outright improvement, F5/F6/F7/F9 are natural API
extensions, and the rest require no changes at all. The total runtime overhead
of composition is **zero** — all bridge operations (`retag`, `assumingMemoryBound`)
are compile-time type conversions that produce identical machine code.

### What Changes in Memory.Pool

| Change | Type | Lines | Risk |
|--------|------|-------|------|
| Add `_nextUnused` stored property | Improvement | ~5 | Low (O(1) init is strictly better) |
| Add `allocateSlot() -> Index<Slot>` | API extension | ~15 | Low (new method, no existing API change) |
| Add `deallocate(at: Index<Slot>)` | API extension | ~10 | Low (new method, no existing API change) |
| Add `allocatedSlotIndices` property | API extension | ~3 | Negligible |
| Add `duplicate(copySlotContents:)` | API extension | ~25 | Low (new method, well-defined semantics) |
| Modify `allocate()` to call `allocateSlot()` | Refactor | ~5 | Low (same logic, different return) |
| Modify `deallocate(_:)` to call `deallocate(at:)` | Refactor | ~3 | Low (same logic, one indirection) |
| Modify `init` to use virgin cursor | Improvement | ~10 | Medium (changes init behavior, needs test updates) |
| Modify `reset()` to reset virgin cursor | Improvement | ~3 | Low |

**Total**: ~80 lines of changes/additions. All tests remain valid (behavior-
compatible). Init test for pre-built free list needs update to virgin cursor.

### What Changes in Storage.Pool

| Change | Type | Lines | Risk |
|--------|------|-------|------|
| Replace 6 stored properties with 1 `_pool: Memory.Pool` | Simplification | -20 | Low |
| Replace manual allocate with `_pool.allocateSlot().retag()` | Simplification | -5 | Low |
| Replace manual deallocate with `_pool.deallocate(at:).retag()` | Simplification | -5 | Low |
| Replace manual pointer(at:) with `_pool.pointer(at:).assumingMemoryBound(to:)` | Bridge | 0 | Low |
| Replace manual deinit with `_pool.allocatedSlotIndices` iteration | Simplification | -3 | Low |
| Replace 35-line copy() with `_pool.duplicate(copySlotContents:)` | Simplification | -25 | Low |
| Add `init(wrapping: Memory.Pool)` internal initializer | Addition | +5 | Low |

**Total**: Net reduction of ~50 lines. Storage.Pool becomes a thin typed
wrapper over Memory.Pool, consistent with SE-0107's raw/typed layering.

### What a Composed Storage.Pool Would Look Like

```swift
extension Storage {
    public final class Pool {
        @usableFromInline
        package var _pool: Memory.Pool

        @inlinable
        public init(capacity: Index<Element>.Count) throws(Pool.Error) {
            guard capacity > .zero else { throw .invalidCapacity }
            precondition(
                MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size,
                "Element stride must be >= MemoryLayout<Index<Element>>.size"
            )
            do {
                self._pool = try Memory.Pool(
                    slotSize: Memory.Address.Count(UInt(MemoryLayout<Element>.stride)),
                    slotAlignment: Memory.Alignment(MemoryLayout<Element>.alignment),
                    capacity: capacity.retag(Memory.Pool.Slot.self)
                )
            } catch {
                // Map Memory.Pool.Error to Storage.Pool.Error
                throw .invalidCapacity
            }
        }

        deinit {
            _pool.allocatedSlotIndices.forEach { slotIndex in
                unsafe _pool.pointer(at: slotIndex)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: 1)
            }
            // Memory.Pool deinit runs automatically → deallocates raw memory
        }
    }
}

extension Storage.Pool where Element: ~Copyable {
    @inlinable
    public func allocate() throws(Error) -> Index<Element> {
        do {
            return try _pool.allocateSlot().retag(Element.self)
        } catch {
            throw .exhausted(capacity: _pool.capacity.retag(Element.self))
        }
    }

    @inlinable
    public func deallocate(at slot: Index<Element>) throws(Error) {
        do {
            try _pool.deallocate(at: slot.retag(Memory.Pool.Slot.self))
        } catch {
            throw .doubleFree
        }
    }

    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _pool.pointer(at: slot.retag(Memory.Pool.Slot.self))
            .assumingMemoryBound(to: Element.self)
    }
}

extension Storage.Pool where Element: Copyable {
    @inlinable
    public func copy() -> Storage.Pool {
        let newPool = _pool.duplicate { source, destination in
            unsafe destination.assumingMemoryBound(to: Element.self)
                .initialize(to: source.assumingMemoryBound(to: Element.self).pointee)
        }
        return Storage.Pool(_wrapping: newPool)
    }
}
```

### Memory.Arena Composition

Memory.Arena is simpler than Memory.Pool. Friction analysis:

| Friction | Resolution | Runtime Cost |
|----------|-----------|------|
| struct vs class/struct | Store as property or use directly | Zero |
| Address return vs Index return | Stride division to compute slot index | One division per allocate |
| No init tracking | Storage.Arena adds Bit.Vector separately | None |
| reset() is O(1) | Storage.Arena adds deinit-then-reset | Deinit cost only |

Memory.Arena requires **no modifications** for composition. Its API is already
minimal and general. Storage.Arena wraps it and adds:
- `Index<Element>` typed coordinates (via stride arithmetic on returned Address)
- Per-slot Bit.Vector for initialization tracking
- Typed element deinit on reset

The one overhead is a stride division in `allocate()` to convert the returned
`Memory.Address` to a slot `Index<Element>`. This is one integer division per
allocation — negligible for an allocator.

### Memory.Buffer Composition

Memory.Buffer has no natural storage-tier consumer. Storage.Heap uses
ManagedBuffer (stdlib). Storage.Inline uses @_rawLayout. Storage.Pool uses
typed pointer allocation.

Memory.Buffer's value proposition is the non-null guarantee over
UnsafeRawBufferPointer. This is useful for:
- C interop where APIs require non-null pointers
- Binary protocol implementations
- Raw buffer management at the Foundations layer

Memory.Buffer stands or falls on its own merits as a raw buffer primitive.
It is not part of the composition question.

### Reassessing the storage-pool-architecture.md Objections

The original research cited 5 "required changes to Memory.Pool" as disadvantages
of composition (Option A). Let me evaluate each against this analysis:

| Original Objection | This Analysis | Verdict |
|-------------------|---------------|---------|
| "Add index-based allocate/deallocate" | F5, F6: Natural API extensions, no drawback | **Resolved** |
| "Add virgin cursor option" | F4: Pure improvement to Memory.Pool | **Resolved** |
| "Expose bitmap iteration API" | F7: Natural API extension | **Resolved** |
| "Add copy capability" | F9: `duplicate(copySlotContents:)` — clean callback pattern | **Resolved** |
| "Non-trivial changes to recently stabilized type" | All changes are additive or improvements; no existing behavior changes | **Mitigated** |

The original research also cited "~20 lines of shared pattern" as too little to
justify composition. This undercounts. The shared implementation includes:

| Shared Code | Lines |
|-------------|-------|
| Virgin cursor + free list allocation logic | ~20 |
| Free list push (deallocate) | ~10 |
| Bit.Vector allocation tracking | ~10 |
| Sentinel computation | ~3 |
| Capacity/allocated/available properties | ~10 |
| Reset logic | ~10 |
| Duplicate/copy infrastructure | ~25 |
| **Total shared** | **~88** |

The actual shared implementation is ~88 lines, not ~20. The original research
counted only the structurally identical lines without considering the duplicate
logic that differs only in phantom type.

### The Storage.Heap Precedent Re-examined

The original research argued: "Storage.Heap extends ManagedBuffer directly —
it does not compose Memory.Buffer. Therefore Storage.Pool should not compose
Memory.Pool."

This precedent is weaker than it appears:

1. **ManagedBuffer IS the raw allocator.** Storage.Heap DOES compose a raw
   allocator — it just uses stdlib's ManagedBuffer rather than Memory.Buffer.
   The pattern is: Storage.Heap = ManagedBuffer (raw) + typed tracking.
   Memory.Buffer was never the right raw layer for Heap because ManagedBuffer
   provides ARC and header storage that Memory.Buffer does not.

2. **Memory.Pool IS the right raw layer for Pool.** Unlike the Buffer case,
   Memory.Pool provides exactly what Storage.Pool needs: fixed-slot allocation
   with free list and bitmap. There is no stdlib type that fills this role.

3. **The precedent actually SUPPORTS composition.** Storage.Heap composes
   a raw allocator (ManagedBuffer). Storage.Pool should compose a raw
   allocator (Memory.Pool). The pattern is consistent — the specific raw
   allocator differs because the allocation strategy differs.

## Comparison

| Criterion | Independent (status quo) | Composition (proposed) |
|-----------|:-----------------------:|:---------------------:|
| Runtime performance | 4/4 | 4/4 (zero overhead) |
| Code duplication | 2/4 (~88 lines duplicated) | 4/4 (eliminated) |
| Memory.Pool improvement | 1/4 (no changes) | 4/4 (virgin cursor, richer API) |
| Memory.Pool consumer count | 1/4 (zero consumers) | 4/4 (one real consumer) |
| Storage.Pool simplicity | 3/4 (self-contained) | 4/4 (thinner, delegates) |
| Architecture consistency | 2/4 (Storage ignores Memory layer) | 4/4 (Storage composes Memory) |
| SE-0107 compliance | 2/4 (Storage does raw+typed) | 4/4 (Memory=raw, Storage=typed) |
| Change risk | 4/4 (no changes) | 3/4 (Memory.Pool changes, needs test updates) |
| Future Arena consistency | 2/4 (uncertain) | 4/4 (establishes composition pattern) |

## Outcome

**Status**: RECOMMENDATION

**Composition is feasible and should be pursued.** Every friction point is
resolvable, no resolution degrades Memory.Pool, and the total runtime overhead
is zero.

### Recommended Changes to Memory.Pool

1. **Add virgin cursor** (`_nextUnused: Index<Slot>`) — pure performance
   improvement, O(1) init replaces O(n).

2. **Add `allocateSlot() -> Index<Slot>`** — the natural allocation primitive.
   Existing `allocate() -> UnsafeMutableRawPointer` delegates to it.

3. **Add `deallocate(at: Index<Slot>)`** — index-based deallocation.
   Existing pointer-based `deallocate(_:)` delegates to it.

4. **Add `allocatedSlotIndices`** — exposes Bit.Vector.ones iteration for
   occupied slots.

5. **Add `duplicate(copySlotContents:) -> Memory.Pool`** — callback-based
   structure duplication for CoW. Clean separation: Memory.Pool copies
   structure, caller copies typed contents.

### Recommended Changes to Storage.Pool

6. **Replace 6 stored properties with `_pool: Memory.Pool`** — Storage.Pool
   becomes a typed wrapper over Memory.Pool.

7. **Delegate allocate/deallocate/pointer to Memory.Pool** — with `.retag()`
   and `.assumingMemoryBound(to:)` at the boundary (zero runtime cost).

8. **Delegate copy() to `_pool.duplicate(copySlotContents:)`** — callback
   performs typed element copy.

### Storage.Arena

9. **Implement Storage.Arena composing Memory.Arena** — Memory.Arena needs
   no modifications. Storage.Arena adds `Index<Element>` coordinates,
   per-slot Bit.Vector, and typed element deinit on reset.

### Memory.Buffer

10. **Keep Memory.Buffer independent** — no natural storage-tier consumer
    exists. Stands on its own merits as a raw buffer primitive with non-null
    guarantees.

### Implementation Order

| Step | Package | Change | Blocked By |
|------|---------|--------|------------|
| 1 | swift-memory-primitives | Add virgin cursor to Memory.Pool | — |
| 2 | swift-memory-primitives | Add index-based allocate/deallocate | Step 1 |
| 3 | swift-memory-primitives | Add allocatedSlotIndices | — |
| 4 | swift-memory-primitives | Add duplicate(copySlotContents:) | Step 1 |
| 5 | swift-memory-primitives | Update Memory.Pool tests | Steps 1-4 |
| 6 | swift-storage-primitives | Refactor Storage.Pool to compose Memory.Pool | Steps 1-5 |
| 7 | swift-storage-primitives | Update Storage.Pool tests (behavior-compatible) | Step 6 |
| 8 | swift-storage-primitives | Implement Storage.Arena composing Memory.Arena | — |

### Supersedes

This document supersedes the DECISION in `storage-pool-architecture.md` for
Storage.Pool's implementation strategy. The original research was thorough but
did not explore the possibility of modifying Memory.Pool to resolve friction
points. With the modifications identified here — all of which are improvements
or neutral extensions — composition becomes strictly superior to independent
implementation.

## References

### Internal
- `swift-storage-primitives/Research/storage-pool-architecture.md` (DECISION) — original composition vs independence analysis
- `swift-primitives/Research/memory-pool-arena-buffer-usage-analysis.md` (RECOMMENDATION) — usage analysis and disposition
- `swift-primitives/Research/storage-primitives-comparative-analysis.md` (RECOMMENDATION) — state of the art evaluation

### Swift Evolution
- SE-0107: UnsafeRawPointer API — raw/typed separation model
- SE-0427: Noncopyable generics — classes with ~Copyable properties
- SE-0426: BitwiseCopyable — storeBytes/load constraint for free list links

### Academic
- Bonwick, "The Slab Allocator" (USENIX 1994) — typed cache layered on raw vmem
- Bonwick & Adams, "Magazines and Vmem" (USENIX 2001) — multi-tier allocator composition
