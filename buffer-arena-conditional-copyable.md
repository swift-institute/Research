# Buffer Arena Conditional Copyable

<!--
---
version: 1.1.0
last_updated: 2026-02-11
status: RECOMMENDATION
tier: 2
---
-->

## Context

Three of the six heap-backed buffer disciplines achieve conditional Copyable
conformance:

```swift
extension Buffer.Ring: Copyable where Element: Copyable {}
extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linked: Copyable where Element: Copyable {}
extension Buffer.Slots: Copyable where Element: Copyable {}
```

Two disciplines are unconditionally `~Copyable` because they require a `deinit`
for sparse-occupancy element cleanup:

- **Buffer.Slab** / **Buffer.Slab.Bounded** — deinit iterates `header.bitmap.ones`
  to deinitialize occupied slots. Additionally, `Slab.Header` is `~Copyable`
  because it contains `Bit.Vector` (a heap-allocated dynamic bit vector).
- **Buffer.Arena** / **Buffer.Arena.Bounded** — deinit iterates `_meta` tokens
  to deinitialize occupied slots and deallocates the separately heap-allocated
  `_meta` array.

This document focuses on Arena because it is the immediate blocker for `Tree.N`
conditional Copyable with CoW. Slab's situation is analyzed in SQ7 below.

Arena is unconditionally `~Copyable` because it manages a separately
heap-allocated meta array (`_meta: UnsafeMutablePointer<Meta>`) whose lifecycle
requires a `deinit`:

```swift
// Buffer.swift:1114-1120
// Cannot conform to Copyable: Arena has deinit (manages _meta allocation lifecycle).
// extension Buffer.Arena: Copyable where Element: Copyable {}

// Cannot conform to Copyable: Arena.Bounded has deinit (manages _meta allocation lifecycle).
// extension Buffer.Arena.Bounded: Copyable where Element: Copyable {}
```

This is blocking downstream consumers — specifically `Tree.N` in
swift-tree-primitives — from having conditional Copyable conformance with CoW
semantics. All other data structures (Stack, Queue, Array, Set, Dictionary) that
use buffer disciplines get conditional Copyable for free. Trees cannot because
`Buffer.Arena` cannot.

### Trigger

Design question arose during tree-primitives migration planning
(`tree-primitives-buffer-arena-migration.md`, Q6). That document identified the
problem and proposed three high-level options but deferred the structural analysis
of how Arena's storage representation could change. This document provides that
analysis.

### Constraints

1. Arena must remain self-cleaning for standalone use (no manual `removeAll()` before destruction)
2. Meta is `BitwiseCopyable` (8 bytes per slot: `token: UInt32` + `nextFree: UInt32`)
3. Element occupancy is sparse (token parity is the sole oracle, not contiguous ranges)
4. Arena capacity is bounded to `UInt32.max`
5. No Foundation imports
6. Must support `~Copyable` elements (conditional Copyable, not unconditional)

## Question

How can `Buffer.Arena` be restructured so that it conforms to `Copyable where
Element: Copyable`, enabling CoW semantics for downstream consumers like `Tree.N`?

## Analysis

### SQ1: Why Some Buffer Disciplines Achieve Conditional Copyable

Ring, Linear, and Linked achieve conditional Copyable because they store only
Copyable fields — a value-type header plus a reference-type storage class:

```swift
public struct Ring: ~Copyable {
    package var header: Header          // value type, always Copyable
    package var storage: Storage<Element>.Heap  // reference type (ManagedBuffer), always Copyable
}
```

`Storage<Element>.Heap` is a `ManagedBuffer` subclass (class = reference type).
Its deinit handles element deinitialization using `Storage.Initialization` —
a small enum describing contiguous initialized regions that Ring/Linear keep
synchronized with header state:

```swift
storage.initialization = header.initialization  // sync after every mutation
```

When the last reference to `Storage.Heap` drops, `ManagedBuffer`'s deinit
frees the allocation, and element deinitialization happens based on
`Storage.Initialization`. No custom deinit is needed on Ring/Linear themselves.

Linked uses a different variant — `Storage<Node>.Pool` (a class wrapping
`Memory.Pool`) whose deinit iterates its allocation bitmap. Same principle:
the storage class owns element lifecycle, so the buffer struct needs no deinit.

Slots uses `Storage<Element>.Split` which has *no* element deinit at all —
element lifecycle is consumer-managed (Hash.Table handles cleanup). This is
correct but fragile: elements leak if the consumer forgets to clean up.

**The fundamental rule:** A buffer struct can be conditionally Copyable if and
only if (a) it has no `deinit`, and (b) all its stored properties are Copyable
when `Element: Copyable`. Types with `deinit` cannot conform to `Copyable` —
this is a Swift language constraint (SE-0390).

**Arena adds a third field:**

```swift
public struct Arena: ~Copyable {
    package var header: Header                       // value type ✓
    package var storage: Storage<Element>.Heap        // reference type ✓
    package var _meta: UnsafeMutablePointer<Meta>     // raw pointer ✗
}
```

`_meta` is a separately heap-allocated array requiring manual `deallocate()`.
This forces Arena to have a deinit, which forces `~Copyable`. Additionally,
Arena's element occupancy is sparse (arbitrary slots can be freed via the
free-list), so `Storage.Initialization` cannot represent Arena's state — Arena
deliberately keeps `storage.initialization = .empty` and uses meta token parity
as the sole occupancy oracle.

**Root cause summary:** Arena's deinit serves two purposes:
1. Iterate meta to deinitialize occupied elements (token & 1 == 1)
2. Deallocate the `_meta` pointer

Both are required because (1) `Storage.Heap` doesn't know which elements to
deinitialize, and (2) `_meta` has no automatic lifecycle management.

### Option A: Arena-Aware Storage Class (Recommended)

**Approach:** Create a new `ManagedBuffer` subclass that stores both meta and
elements in a single allocation with a deinit that understands arena semantics.

```
┌─────────────────────────────────────────────────────────────────────┐
│ ManagedBuffer Header: Arena.Header                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Meta_0 │ Meta_1 │ ... │ Meta_{n-1} │ [align pad] │ Elem_0 │ ... │  │
└─────────────────────────────────────────────────────────────────────┘
│←──────── n × 8 bytes ───────────→│              │←── elements ──→│
```

**Arena struct becomes:**

```swift
public struct Arena: ~Copyable {
    package var header: Header
    package var _arenaStorage: Storage<Element>.Arena  // new class
}
// extension Buffer.Arena: Copyable where Element: Copyable {} ← NOW POSSIBLE
```

Both fields are Copyable when `Element: Copyable`:
- `Header` is a value type (always Copyable)
- `Storage<Element>.Arena` is a class (reference type, always Copyable)

**Storage.Arena class:**

```swift
extension Storage where Element: ~Copyable {
    public final class Arena: ManagedBuffer<Buffer<Element>.Arena.Header, UInt8> {
        deinit {
            withUnsafeMutablePointers { headerPtr, base in
                let header = headerPtr.pointee
                let hw = Int(bitPattern: header.highWater)
                // Meta starts at byte 0 of elements region
                let metaBase = UnsafeMutableRawPointer(base)
                    .assumingMemoryBound(to: Buffer<Element>.Arena.Meta.self)
                // Elements start after meta array, aligned
                let elementBase = /* aligned offset computation */
                for i in 0..<hw {
                    if metaBase[i].token & 1 == 1 {
                        elementBase.advanced(by: i * MemoryLayout<Element>.stride)
                            .assumingMemoryBound(to: Element.self)
                            .deinitialize(count: 1)
                    }
                }
            }
        }
    }
}
```

**Header synchronization:** Same dual-authority pattern as Ring/Linear. The Arena
struct stores `header` inline for fast access. Before the storage is released,
the header in `ManagedBuffer` must reflect the current state. Two approaches:

1. **Write-through**: Every Arena mutation writes header back to storage
   (`_arenaStorage.header = header`). Small cost per operation.
2. **Write-on-release**: Sync header to storage only before `makeUnique()` or
   when the Arena is about to be consumed. Cheaper for batch operations.

Ring/Linear use write-through for `storage.initialization`. The same pattern
applies here.

**Advantages:**
- Self-cleaning: `Storage.Arena` deinit handles element deinitialization and
  allocation freeing — no downstream burden
- Single allocation: meta + elements share one `ManagedBuffer` (better cache
  locality, fewer allocations)
- Follows the established pattern: header (value) + managed storage (reference),
  identical architecture to Ring/Linear
- `isKnownUniquelyReferenced(&_arenaStorage)` works directly for CoW

**Disadvantages:**
- New storage class to implement and maintain
- Layout computation for dual-region storage (SoA within ManagedBuffer) is
  non-trivial — though `Storage.Split` already has this code
- Static method signatures must change or need an adapter (they currently take
  `Storage<Element>.Heap` + `UnsafeMutablePointer<Meta>` separately)
- Header synchronization adds a small write cost per mutation

### Option B: Reuse Storage.Split (Consumer-Managed Lifecycle)

**Approach:** Replace `Storage<Element>.Heap + _meta` with
`Storage<Element>.Split<Meta>`, which already provides the exact SoA layout
needed (lane = Meta array, elements = Element array, single ManagedBuffer).

```swift
public struct Arena: ~Copyable {
    package var header: Header
    package var _storage: Storage<Element>.Split<Buffer<Element>.Arena.Meta>
}
// extension Buffer.Arena: Copyable where Element: Copyable {} ← NOW POSSIBLE
```

**No Arena deinit needed** — `_meta` is absorbed into the Split allocation. Meta
is `BitwiseCopyable`, so it needs no cleanup. The ManagedBuffer frees the
allocation when the reference count hits zero.

**Problem: Element deinitialization.** `Storage.Split` deliberately has no
element-aware deinit (its contract is "consumer-managed element lifecycle").
When the last reference to Split drops, occupied elements are NOT deinitialized.

For downstream CoW consumers like `Tree.N`, this is acceptable — Tree.N's
Storage class deinit calls `arena.removeAll()` before releasing the arena.
But for standalone Arena usage, elements leak silently.

**Advantages:**
- Zero new code: reuses existing `Storage.Split`
- Layout computation already implemented and tested
- Simplest implementation path

**Disadvantages:**
- **Breaks Arena's self-cleaning contract**: standalone users must call
  `removeAll()` before destruction or elements leak
- Error-prone: no compiler enforcement of the cleanup requirement
- Semantic regression from current behavior where Arena's deinit handles cleanup

### Option C: Reference-Type Wrapper for Meta

**Approach:** Wrap `_meta` in a class whose deinit frees the pointer:

```swift
final class MetaStorage: @unchecked Sendable {
    let pointer: UnsafeMutablePointer<Buffer<Element>.Arena.Meta>
    let capacity: Int
    init(pointer: UnsafeMutablePointer<Meta>, capacity: Int) { ... }
    deinit { pointer.deallocate() }
}

public struct Arena: ~Copyable {
    package var header: Header
    package var storage: Storage<Element>.Heap
    package var _metaRef: MetaStorage
}
```

All three fields are Copyable when `Element: Copyable`. `_meta` lifetime is
reference-counted via `MetaStorage`.

**Problem: Element deinitialization is NOT solved.** Arena still needs to
deinitialize occupied elements in its deinit. `Storage.Heap`'s deinit cannot
handle Arena's sparse occupancy (it uses `Storage.Initialization` which tracks
contiguous ranges, not arbitrary slot sets). So Arena still needs a deinit for
element cleanup → still `~Copyable`.

**Verdict: Does not solve the problem.** Only addresses `_meta` lifetime, not
the fundamental element deinitialization issue.

### Option D: @unchecked Copyable

Swift does not have `@unchecked Copyable`. The `@unchecked` attribute only
applies to `Sendable`. Even if it existed, Swift lacks custom copy constructors,
so there is no way to implement deep-copy semantics for `_meta` on copy.

**Verdict: Not viable.** Language feature does not exist.

### Option E: AoS — Store Meta Inline with Elements

**Approach:** Instead of separate arrays, store `(Meta, Element)` per slot:

```swift
public struct Arena: ~Copyable {
    package var header: Header
    package var storage: Storage<(Meta, Element)>.Heap
}
```

**Problems:**
1. `(Meta, Element)` where `Element: ~Copyable` is itself `~Copyable` — doesn't
   help unless wrapped in Optional, which adds per-slot overhead
2. Memory layout: each slot = 8 bytes Meta + Element + padding. Significant
   overhead for small Element types
3. `Storage.Initialization` still can't represent sparse occupancy for the
   Heap deinit — same fundamental problem as Option C

**Verdict: Not viable.** Memory overhead and sparse-occupancy problem remain.

### Option F: Box Arena in Reference Type (Keep ~Copyable)

**Approach:** Don't change Arena at all. Downstream consumers that need CoW
wrap Arena in a class (box):

```swift
// In Tree.N:
final class ArenaBox<Element: ~Copyable>: ~Copyable {
    var arena: Buffer<Element>.Arena
    deinit { arena.removeAll() }
}
extension ArenaBox: Copyable where Element: Copyable {}
```

Tree.N uses `isKnownUniquelyReferenced(&arenaBox)` for CoW and adds an
`Arena.copy() -> Arena` method for deep-copying.

**This is the approach identified in `tree-primitives-buffer-arena-migration.md`
(Option A).**

**Advantages:**
- No changes to Arena
- Proven pattern (boxing for CoW)

**Disadvantages:**
- Every Arena consumer wanting CoW must independently implement the boxing
  pattern — boilerplate proliferation
- `Arena.copy()` must deep-copy both the storage (elements) and meta — requires
  new method on Arena
- Arena remains unconditionally `~Copyable`, limiting generic composition
  (any `T: Copyable` constraint propagation fails if T contains an Arena)

### SQ3: Can Buffer.Arena Use Storage.Split Directly?

Yes — this is **Option B** above. `Storage.Split<Meta>` provides the exact
layout: lane array (Meta, BitwiseCopyable) + element array (Element), single
ManagedBuffer allocation. Meta access via `storage.pointer(laneField, at:)`,
element access via `storage.pointer(elementField, at:)`.

The layout is functionally identical to what Arena needs. The gap is purely
about element lifecycle management — Split delegates it to the consumer,
while Arena's current contract is self-cleaning.

### SQ5: Reference-Type Wrapper Approach

This is **Option C** above. It solves `_meta` lifetime but not element
deinitialization. Not viable on its own.

However, combining Option C with a modified `Storage.Heap` that accepts an
external deinitialization callback would work in principle. This is
over-engineered — Option A achieves the same result more cleanly.

### SQ6: Impact on Buffer.Arena API Surface

**Instance methods (public):** Unchanged. `insert`, `remove`, `allocateSlot`,
`freeSlot`, `removeAll`, `isValid`, `isOccupied`, `token`, `position`,
`forEachOccupied`, `ensureCapacity`, `grow` — all survive as-is. Their
implementations delegate differently internally but the signatures are stable.

**Static methods (public):** Must change. Currently:

```swift
public static func insert(
    _ element: consuming Element,
    header: inout Header,
    storage: Storage<Element>.Heap,      // ← changes
    meta: UnsafeMutablePointer<Meta>     // ← absorbed
) -> Position
```

With Option A, these become:

```swift
public static func insert(
    _ element: consuming Element,
    header: inout Header,
    storage: Storage<Element>.Arena      // ← new type, meta is inside
) -> Position
```

Or, the static methods could accept decomposed pointers (element pointer + meta
pointer) computed from `Storage<Element>.Arena`, preserving the current
parameter pattern. This avoids tying the statics to a specific storage type.

**Nested types:** `Header`, `Meta`, `Position`, `Error` — all unchanged.

### SQ7: Slab Has the Same Structural Problem

`Buffer.Slab` and `Buffer.Slab.Bounded` share Arena's fundamental problem:
sparse occupancy requires a buffer-level deinit that `Storage.Heap` cannot
provide. But Slab has a **double blocker**:

1. **deinit** — Slab iterates `header.bitmap.ones` to deinitialize occupied
   elements (`Buffer.swift:376-386`). Same as Arena's token iteration.
2. **~Copyable Header** — `Slab.Header` contains `Bit.Vector` which is
   `~Copyable` (heap-allocated dynamic bit vector). Even without the deinit,
   Slab's Header field would prevent Copyable conformance.

The source confirms this is a conscious design choice:
```swift
// MARK: - Sequence.Clearable — not applicable (Slab is never Copyable)
```

**Could Option A apply to Slab?** In principle, yes — create a
`Storage<Element>.Slab` ManagedBuffer whose header contains the bitmap and
whose deinit iterates it. Slab struct would store a Copyable header (without
bitmap) plus the storage reference.

**Additional complexity vs Arena:**
- Slab's bitmap (`Bit.Vector`) is dynamically-sized. Syncing it to storage
  after every mutation means either copying the entire bitmap (expensive for
  large capacities) or keeping the bitmap only in the storage class (every
  bitmap read/write goes through the reference).
- Arena's meta is already in a separate allocation, so absorbing it into a
  ManagedBuffer is a natural restructuring. Slab's bitmap is currently inline
  in the Header, so the restructuring is more invasive.

**Priority:** Slab's Copyable status has no known downstream blocker — no
data structure currently requires Slab to be Copyable. Arena is the immediate
priority because Tree.N depends on it. Slab can be revisited if a consumer
emerges that needs it.

**Note:** `Buffer.Slab.Inline` uses `Header.Static<wordCount>` which contains
`Bit.Vector.Static<wordCount>` (Copyable). Combined with `Storage.Inline`
being ~Copyable due to `@_rawLayout`, Slab.Inline is blocked by the Inline
issue rather than the bitmap issue.

### SQ8: Cross-Layer Taxonomy of ~Copyable/Copyable Solutions

The Memory → Storage → Buffer stack uses three distinct strategies at each
layer to handle the Copyable question:

**Layer 1 — Memory (raw, untyped):**

All resource-owning Memory types (`Memory.Arena`, `Memory.Pool`) are
unconditionally `~Copyable` with deinit. This is correct — they manage raw
allocations. Non-owning views (`Memory.Buffer`, `Memory.Address`) are Copyable.

**Layer 2 — Storage (typed, lifecycle-aware):**

| Type | Kind | Copyable | Lifecycle |
|------|------|----------|-----------|
| Storage.Heap | class (ManagedBuffer) | Always (ARC) | Self-cleaning via Initialization |
| Storage.Pool | class | Always (ARC) | Self-cleaning via Memory.Pool bitmap |
| Storage.Arena | class | Always (ARC) | Self-cleaning via Bit.Vector |
| Storage.Split | class (ManagedBuffer) | Always (ARC) | Consumer-managed (no deinit) |
| Storage.Inline | struct (@_rawLayout) | Never | Self-cleaning via Bit.Vector.Static |
| Storage.Pool.Inline | struct (@_rawLayout) | Never | Self-cleaning via Bit.Vector.Static |
| Storage.Arena.Inline | struct (@_rawLayout) | Never | Self-cleaning via Bit.Vector.Static |

Key insight: **Storage classes solve Copyable by being reference types.** The
deinit lives on the class (ARC manages it). Consumers hold a reference, which
is always Copyable. Storage structs use `@_rawLayout` and are permanently
~Copyable — a Swift language limitation.

**Layer 3 — Buffer (composed, user-facing):**

Five strategies exist for buffer-level Copyable:

| Strategy | Occupancy | Storage Handles It? | Buffer deinit? | Copyable? | Used By |
|----------|-----------|---------------------|----------------|-----------|---------|
| Initialization sync | Contiguous (1-2 ranges) | Yes | No | **Yes** | Ring, Linear |
| Storage.Pool deinit | Arbitrary (bitmap) | Yes | No | **Yes** | Linked |
| Consumer-managed | None | No (Split has no deinit) | No | **Yes*** | Slots |
| Buffer bitmap deinit | Arbitrary (bitmap) | No | **Yes** | No | Slab |
| Buffer meta deinit | Arbitrary (tokens) | No | **Yes** | No | Arena |

*Slots is Copyable but elements leak if consumer doesn't clean up.

The root cause for Slab and Arena: **`Storage.Initialization` only supports
1-2 contiguous ranges**, which cannot represent arbitrary sparse occupancy.
Ring/Linear succeed because their occupancy is always contiguous. Linked
succeeds because `Storage.Pool` has its own bitmap-based deinit. Slab and
Arena fail because their sparse occupancy outstrips `Storage.Heap`'s tracking
capability, forcing a buffer-level deinit.

**All `.Inline` and `.Small` variants** are ~Copyable due to `@_rawLayout` in
`Storage.Inline`. This is orthogonal to the sparse-occupancy problem and
requires Swift language evolution (or migration to `InlineArray`-based storage)
to resolve.

## Comparison

| Criterion | Option A (Arena Storage) | Option B (Split) | Option F (Box) |
|-----------|:------------------------:|:-----------------:|:--------------:|
| Conditional Copyable | Yes | Yes | No (boxed only) |
| Self-cleaning deinit | Yes | **No** (consumer-managed) | Yes (via box deinit) |
| Single allocation (meta + elements) | Yes | Yes | No (separate allocs) |
| New code required | ~120 lines (new class) | ~30 lines (rewire) | ~40 lines (box + copy) |
| Instance API unchanged | Yes | Yes | Yes |
| Static API unchanged | No (storage param type) | No (storage param type) | Yes |
| Follows Ring/Linear pattern | Yes | Partially | No |
| Standalone Arena use safe | Yes | **No** (leaks) | Yes |
| CoW via isKnownUniquelyReferenced | Yes | Yes | Yes |
| Downstream boilerplate | None | None | Per-consumer boxing |

## Prior Art

### Swift Evolution
- **SE-0427** (Noncopyable generics): Enables classes with `~Copyable` stored
  properties. Relevant for `Storage<Element>.Arena` class containing element
  slots for non-Copyable types.
- **SE-0390** (Noncopyable structs and enums): Foundation for `~Copyable` buffer
  types. Established the deinit-implies-noncopyable constraint.

### Related Languages
- **Rust**: Arena allocators (`bumpalo`, `typed-arena`) are not Clone by default
  for the same reason — deallocation semantics. Rust's `ManuallyDrop` would be
  analogous to consumer-managed lifecycle (Option B).
- **C++ `std::pmr::polymorphic_allocator`**: Memory resources are not copyable;
  containers using them implement copy construction by allocating into a new
  resource. Analogous to the `Arena.copy()` approach.

### Internal
- **Storage.Split** (`Storage.Split.swift`): Existing dual-array ManagedBuffer
  pattern with consumer-managed lifecycle. Demonstrates the layout computation
  and field-handle access pattern.
- **Storage.Heap**: Existing ManagedBuffer with `Storage.Initialization`-based
  deinit. Demonstrates the self-cleaning pattern that Option A replicates.

## Outcome

**Status**: RECOMMENDATION

**Recommended: Option A — Arena-Aware Storage Class**

Create `Storage<Element>.Arena`, a `ManagedBuffer` subclass with SoA layout
(meta + elements) and an arena-semantics-aware deinit that iterates meta tokens
to deinitialize occupied elements. Restructure `Buffer.Arena` to store
`header: Header + _arenaStorage: Storage<Element>.Arena`. Remove Arena's deinit.
Declare `extension Buffer.Arena: Copyable where Element: Copyable {}`.

### Rationale

1. **Preserves self-cleaning contract.** Unlike Option B, standalone Arena use
   remains safe — `Storage.Arena`'s deinit handles cleanup automatically.

2. **Follows the established pattern.** Ring/Linear use `header (value) +
   Storage.Heap (reference)`. Arena would use `header (value) +
   Storage.Arena (reference)`. Same architecture, same CoW mechanism.

3. **Single allocation.** Meta and elements share one `ManagedBuffer`, reducing
   allocation count and improving cache locality vs the current separate
   `_meta` allocation.

4. **No downstream boilerplate.** Unlike Option F, every consumer gets
   conditional Copyable for free — no per-consumer boxing required. Tree.N's
   CoW becomes the standard `isKnownUniquelyReferenced` pattern.

5. **Layout code exists.** `Storage.Split` already solves the dual-array-in-
   ManagedBuffer layout problem. `Storage.Arena` can reuse or adapt the
   same offset/stride computation.

### Implementation Outline

| Step | Package | Change |
|------|---------|--------|
| 1 | swift-storage-primitives | Implement `Storage<Element>.Arena` class with SoA layout + arena deinit |
| 2 | swift-buffer-primitives (Core) | Change `Buffer.Arena` struct: replace `storage + _meta` with `_arenaStorage: Storage<Element>.Arena` |
| 3 | swift-buffer-primitives (Core) | Remove `Buffer.Arena.deinit` and `Buffer.Arena.Bounded.deinit` |
| 4 | swift-buffer-primitives (Core) | Add `extension Buffer.Arena: Copyable where Element: Copyable {}` |
| 5 | swift-buffer-primitives (Arena) | Update static methods to work with `Storage<Element>.Arena` |
| 6 | swift-buffer-primitives (Arena) | Update instance methods to delegate through new storage |
| 7 | swift-buffer-primitives (Arena) | Add `Buffer.Arena Copyable.swift` for CoW-safe mutations |
| 8 | swift-buffer-primitives (Tests) | Update Arena tests for new storage representation |
| 9 | swift-tree-primitives | Simplify Tree.N to use Arena directly (remove manual boxing/copy) |

### Open Questions

1. **Should `Storage.Arena` reuse `Storage.Split`'s layout code?** Could
   subclass Split (if made non-final) or duplicate the offset computation.
   Trade-off: code reuse vs keeping Split final for optimization.

2. **Header synchronization strategy.** Write-through (every mutation syncs
   header to storage) vs write-on-release (sync only before storage is shared).
   Ring/Linear use write-through; recommend the same for consistency.

3. **`Buffer.Arena.Bounded` treatment.** Same restructuring applies. Bounded
   can use the same `Storage<Element>.Arena` class (capacity is fixed but the
   storage class doesn't enforce it — the Header `isFull` check does).

4. **`Buffer.Slab` Copyable (future).** The same "push deinit into Storage
   class" approach could make Slab conditionally Copyable, but it has additional
   complexity (dynamic bitmap sync) and no known downstream blocker. Defer
   until a consumer requires it. See SQ7.

### Supersedes

This document extends `tree-primitives-buffer-arena-migration.md` Q6, which
identified the problem and high-level options. This analysis provides the
structural recommendation for Arena's storage representation change.

## References

### Internal
- `swift-primitives/Research/tree-primitives-buffer-arena-migration.md` (IN_PROGRESS) — migration plan that surfaced Q6
- `swift-primitives/Research/memory-storage-composition-feasibility.md` (RECOMMENDATION) — Memory/Storage composition patterns
- `swift-vector-primitives/Research/noncopyable-conditional-copyable.md` (DECISION) — establishes deinit-implies-noncopyable constraint; confirms `@_rawLayout` blocks conditional Copyable for Inline types
- `swift-institute/Research/minimal-type-declaration-pattern.md` (DECISION) — ~Copyable exception for nested types in type body
- `swift-primitives/Research/primitives-taxonomy-naming-layering-audit.md` (DECISION) — Memory → Storage → Buffer → Data Structure four-layer stack validation
- `swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift:816-1025` — Arena declaration and deinit
- `swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift:363-443` — Slab declaration and deinit (parallel problem)
- `swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift:1050-1121` — all conditional conformances (Copyable and Sendable)
- `swift-storage-primitives/Sources/Storage Primitives Core/Storage.Split.swift` — Split layout and lifecycle contract
- `swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift` — Storage.Heap, Storage.Pool, Storage.Arena, Storage.Inline declarations
- `swift-buffer-primitives/Sources/Buffer Arena Primitives/Buffer.Arena.swift` — Arena instance methods
- `swift-buffer-primitives/Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift` — Arena static methods

### Swift Evolution
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
