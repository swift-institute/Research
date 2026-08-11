# Arena Buffer Design

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-buffer-primitives, swift-tree-primitives, swift-slab-primitives]
normative: false
---
-->

## Context

Tree.N, Tree.Unbounded, and potentially other graph-like data structures require **arena-style slot management**: O(1) allocation, O(1) deallocation with slot recycling, and stale-reference detection via generation tokens. Currently, Tree.N implements this as a 500-line `ManagedBuffer` subclass with manually managed auxiliary buffers (`_tokens`, `_nextFree`). This pattern should be extracted into buffer-primitives as a reusable discipline.

**Trigger**: [RES-001] Investigation — the arena pattern appears in Tree.N, Tree.Unbounded, and is needed by any graph/ECS/handle-table data structure. No existing buffer discipline provides slot recycling with generation validation.

**Scope**: Per [RES-002a], this is cross-package (buffer-primitives is the home; tree-primitives, slab-primitives, and future graph-primitives are consumers). The new discipline lives in buffer-primitives and follows the established three-layer architecture.

**Existing disciplines** (for context):

| Discipline | Access Pattern | Lifecycle Tracking | Slot Assignment |
|------------|---------------|-------------------|-----------------|
| Linear | Contiguous 0..count | Range-tracked (Storage.Heap) | Sequential append |
| Ring | Circular wrap-around | Range-tracked (Storage.Heap) | Head/tail cursor |
| Slab | Sparse, bitmap-indexed | Bitmap (Bit.Vector) | Consumer-chosen |
| Linked | Linked traversal | Pool bitmap | Pool-allocated |
| Slots | Metadata-parametric | Consumer-managed | Consumer-chosen |
| **Arena** | **Handle-based random** | **Generation tokens** | **Arena-allocated** |

**Upstream documents**:
- `swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md` — three-discipline design foundation
- `swift-buffer-primitives/Research/metadata-parametric-slots.md` — Slots discipline design (closest precedent)

---

## Question

What is the type design, storage layout, generation tracking strategy, free-list architecture, and variant structure for an **arena buffer discipline** that provides O(1) slot allocation/deallocation with generation-based stale-reference detection?

### Sub-questions

- SQ1: What storage type should back the element array — Storage.Heap, Storage.Pool, or a new type?
- SQ2: How should generation tokens be stored — in-band (overlaid on element memory), separate array, or in an auxiliary storage type?
- SQ3: How should the free-list be structured — in-band overlay, separate array, or via existing Pool free-list?
- SQ4: What should the Position (handle) type look like — generation width, index width, niche optimization?
- SQ5: Should the arena support dense iteration (O(count)) or only sparse iteration (O(capacity))?
- SQ6: What variants are needed — Bounded, Inline, Small?
- SQ7: Who manages element lifecycle — the arena's deinit, or the backing storage?

---

## Prior Art Survey [RES-021]

### Rust Ecosystem

| Crate | Index Size | Generation Bits | Free-List | Iteration | Unsafe |
|-------|-----------|----------------|-----------|-----------|--------|
| `generational-arena` | 24 bytes (usize+u64) | 64 | In-band LIFO | O(capacity) | None |
| `slotmap` (basic) | 8 bytes (u32+u32) | 31 (1 bit tag) | In-band union | O(capacity) | Yes |
| `slotmap` (Dense) | 8 bytes | 31 | In-band + indirection | O(count) | Yes |
| `slotmap` (Hop) | 8 bytes | 31 | In-band + skip metadata | O(count) amortized | Yes |
| `thunderdome` | 8 bytes (u32+u32 NonZero) | 32 (NonZero) | In-band LIFO | O(capacity) | Minimal |
| `slab` (tokio) | 8 bytes (usize) | 0 (none) | In-band LIFO | O(capacity) | Minimal |

**Key observations**:

1. **8-byte handles are the sweet spot.** `generational-arena`'s 24-byte `Option<Index>` is widely considered a design mistake. `slotmap` and `thunderdome` both use 32-bit index + 32-bit generation = 8 bytes total. With NonZero generation, `Optional<Position>` is also 8 bytes.

2. **In-band free-lists dominate.** All major implementations store next-free pointers in the freed slot's element memory. This avoids a separate allocation. The constraint is `sizeof(Element) >= sizeof(FreePointer)`.

3. **Generation-per-slot, not global.** `slotmap` and `thunderdome` store generation per slot (incremented on reuse). `generational-arena` uses a global generation counter (incremented on every remove). Per-slot is more space-efficient and allows more reuse cycles per slot.

4. **O(capacity) iteration is accepted.** Only `DenseSlotMap` achieves O(count) iteration, at the cost of an indirection layer and swap-on-remove. Most implementations accept O(capacity) iteration as the pragmatic choice.

5. **`slotmap`'s LSB tag trick** uses the least significant bit of the version field to distinguish occupied/free. This saves a separate discriminant byte.

### C++ P0661 `slot_map` Proposal

The C++ standards proposal by Allan Deutsch describes a dense slot map with contiguous value storage, an indirection layer (slots → values), and swap-and-pop removal. Keys decompose into `(index, generation)` via `std::get<>`. This is the most formally specified variant.

### ECS Patterns (Bevy, Specs, Legion)

Bevy uses `Entity { index: u32, generation: NonZeroU32 }` (8 bytes, niche-optimized). Allocation is two-stage: fast mutable path + lock-free concurrent path. The free-list is a standard LIFO stack. Generation increments on each reuse cycle. Bevy's entity allocation is essentially a generational arena.

### Swift Ecosystem

**No published generational arena or slot map exists in the Swift ecosystem.** This implementation would be novel. The closest building blocks are `ManagedBuffer` (raw header + elements) and the existing `Storage.Pool` (free-list + bitmap).

---

## Analysis

### SQ1: Storage Substrate

**Options**:

#### A: Storage.Heap + separate auxiliary arrays

Use `Storage<Element>.Heap` for elements. Manage generation tokens and free-list pointers as separate `UnsafeMutablePointer` allocations owned by the buffer type.

- **Pro**: Follows Slab's pattern (Storage.Heap + separate tracking state)
- **Pro**: Storage.Heap already supports `slotCapacity`, `deinitialize(at:)`, `pointer(at:)`
- **Con**: 3 allocations total (ManagedBuffer + tokens + nextFree)
- **Con**: Must keep `storage.initialization = .empty` since arena manages lifecycle

#### B: Storage.Pool as backing store

Use `Storage<Element>.Pool` for elements (it already provides free-list + bitmap). Layer generation tokens on top as a separate array.

- **Pro**: Reuses existing free-list and bitmap infrastructure
- **Pro**: Pool's deinit handles element cleanup automatically
- **Con**: Pool's free-list uses in-band overlay (requires `stride(Element) >= stride(Index)`)
- **Con**: Pool doesn't have generation tracking — we'd layer it on top, creating split responsibility
- **Con**: Pool allocates only via bitmap scan or virgin cursor; doesn't expose its free-list head for Position construction
- **Con**: 2 allocations (Pool + tokens array)

#### C: In-band free-list + separate token array

Use `Storage<Element>.Heap` for elements. Overlay free-list next-pointers in freed element memory (like Rust's `slotmap`). Keep a separate token array.

- **Pro**: Only 2 allocations (Storage.Heap + tokens)
- **Pro**: Matches the dominant Rust pattern
- **Con**: Requires `MemoryLayout<Element>.stride >= MemoryLayout<Int>.stride` — fails for small types (`Bool`, `UInt8`)
- **Con**: Unsafe memory reinterpretation in Swift's strict safety model
- **Con**: Complicates `@safe` and `strictMemorySafety()`

#### D: Token-only tracking (no bitmap, no separate free-list array)

Use `Storage<Element>.Heap` for elements. Store generation tokens per slot. Use a separate `UnsafeMutablePointer<Int>` for free-list next pointers (not overlaid). Derive occupancy from token parity (odd = occupied) instead of maintaining a bitmap.

- **Pro**: 3 allocations but no Bit.Vector dependency
- **Pro**: Token parity gives O(1) occupancy check per slot
- **Pro**: Clean separation: tokens track state, nextFree tracks recycling
- **Con**: Deinit iterates all capacity slots to find occupied ones (O(capacity))
- **Con**: No fast popcount-based "count occupied" operation

#### E: Storage.Split<UInt32> for tokens + elements in one allocation

Use `Storage<Element>.Split<UInt32>` where the lane is the generation token. Manage free-list separately.

- **Pro**: 2 allocations (Split + nextFree), tokens co-located with elements for cache locality
- **Pro**: Field-handle pattern for type-safe access
- **Con**: Split doesn't support occupancy tracking — consumer must scan tokens
- **Con**: Split has no deinit — arena must handle all cleanup
- **Con**: Free-list still needs separate storage

**Recommendation**: **Option D** (Token-only with separate nextFree array). Rationale:

1. **Simplest mental model**: Token parity IS the source of truth. No bitmap to keep in sync.
2. **Matches Rust ecosystem**: The dominant pattern stores generation per slot and derives occupancy from it.
3. **Clean Slab parallel**: Slab uses Header + Storage.Heap with `storage.initialization = .empty`. Arena uses the same pattern with tokens instead of bitmap.
4. **O(capacity) deinit is acceptable**: Rust's `generational-arena`, `slotmap`, and `thunderdome` all iterate capacity on drop. For arenas, capacity is typically close to peak occupancy.
5. **Avoids Pool coupling**: Storage.Pool's API doesn't expose generation tracking. Layering tokens on top of Pool creates split responsibility and makes CoW harder.

### SQ2: Generation Token Storage

**Options**:

#### A: UInt32 per slot, parity-tagged (even=free, odd=occupied)

This is the `slotmap` approach. The LSB distinguishes state:
- Token `0` → free (never allocated)
- Token `1` → occupied (first allocation)
- Token `2` → free (after first deallocation)
- Token `3` → occupied (second allocation)

31 effective generation bits → ~2 billion reuse cycles per slot before wraparound.

#### B: UInt32 per slot, NonZero for occupied

This is the `thunderdome` approach. Generation starts at 1 (NonZero), enabling `Optional<Position>` niche optimization. Occupancy tracked separately (bitmap or enum discriminant).

#### C: UInt64 per slot, global monotonic counter

This is the `generational-arena` approach. One global counter incremented on every removal. 64 bits → effectively infinite reuse safety. But 16 bytes per Position.

**Recommendation**: **Option A** (UInt32, parity-tagged). Rationale:

1. **Compact**: 4 bytes per slot, 8 bytes per Position.
2. **Self-describing**: Token parity IS the occupancy flag — no separate bitmap needed.
3. **Sufficient generations**: 2^31 reuse cycles per slot. At 1 billion alloc/free cycles per slot, this would take decades.
4. **Proven**: `slotmap` uses exactly this scheme and is the most widely adopted Rust implementation.

### SQ3: Free-List Architecture

**Options**:

#### A: Separate `UnsafeMutablePointer<Int>` array

Each slot has a dedicated `Int` storing the next-free index. Sentinel value (-1 or `capacity`) marks end of list. LIFO stack: free prepends, allocate pops head.

- **Pro**: Works for any element size (even `Bool`)
- **Pro**: No memory reinterpretation needed
- **Pro**: Clean separation of concerns
- **Con**: Extra allocation, 8 bytes per slot overhead

#### B: In-band overlay on element memory

When a slot is freed, store the next-free pointer in the now-deinitialized element memory. Requires `MemoryLayout<Element>.stride >= MemoryLayout<Int>.stride`.

- **Pro**: Zero additional memory
- **Pro**: Matches Rust ecosystem pattern
- **Con**: Size constraint excludes small elements
- **Con**: Requires `unsafe` memory reinterpretation
- **Con**: Complicates strict memory safety

#### C: Hybrid (in-band when possible, fallback to separate)

Use in-band overlay when element stride is sufficient, separate array otherwise. Compile-time check via generic constraint or runtime branch.

- **Pro**: Best of both worlds
- **Con**: Two code paths, increased complexity
- **Con**: Compile-time element size check not ergonomic in Swift generics

**Recommendation**: **Option A** (separate array). Rationale:

1. **Universality**: Works for all element types, including `Bool`, zero-sized types (if Swift ever gets them), and types smaller than a pointer.
2. **Safety**: No memory reinterpretation. Compatible with `@safe` and `strictMemorySafety()`.
3. **Simplicity**: One code path for all element types.
4. **Acceptable overhead**: 8 bytes per slot. For a 1024-slot arena, that's 8 KB — trivial.
5. **Matches Tree.N**: The existing implementation already uses this approach.

### SQ4: Position (Handle) Type Design

**Options**:

#### A: `(index: UInt32, token: UInt32)` — 8 bytes total

Matches `slotmap`/`thunderdome`. Maximum 2^32 slots. 31 effective generation bits.

#### B: `(index: Int, token: UInt32)` — 12 bytes (16 with padding)

Matches Tree.N's current design. 64-bit index for large arenas. 31 generation bits.

#### C: `(index: Int, token: Int)` — 16 bytes

Maximum precision. 63 generation bits. Large Position type.

**Recommendation**: **Option A** (UInt32 + UInt32 = 8 bytes). Rationale:

1. **Compact**: 8 bytes is cache-friendly and fits in a register pair.
2. **2^32 slots is sufficient**: 4 billion slots. No practical arena needs more.
3. **Niche optimization**: With NonZero token, `Optional<Position>` can be 8 bytes (when Swift supports it).
4. **Matches industry standard**: Every major Rust implementation uses 32+32.

However, the public API of Buffer.Arena should use `Index<Element>` (which wraps `Ordinal`/`UInt`) for the slot coordinate, maintaining consistency with the typed index system. The `Position` type wraps `(Index<Element>, UInt32)` internally but presents a clean API.

**Note**: For Swift interop, the Position stores the index as the buffer-primitives `Index<Element>` type (which is `UInt`-based, so 64-bit on 64-bit platforms). The internal storage uses `UInt32` for the token. Total Position size: 12 bytes on 64-bit (8 index + 4 token), potentially 16 with alignment. This is a pragmatic compromise: we preserve typed-index consistency at the cost of 4 extra bytes versus the Rust ideal.

**Revised recommendation**: Store `index: Int` (matching the buffer-primitives convention where all indices are `Int`-width) + `token: UInt32`. This gives 12 bytes (16 with padding). The alternative is to break from the typed-index convention and use `UInt32` for the index, saving 4-8 bytes per Position.

**Decision**: Use `Int` + `UInt32` for now. If Position size becomes a concern (e.g., trees with millions of positions), a compact 8-byte variant can be added later. Tree.N already uses `(Int, UInt32)` and it works fine.

### SQ5: Iteration Strategy

**Options**:

#### A: Sparse iteration — O(capacity)

Scan all slots, skip free entries (odd token = occupied). Simple, no extra data structures.

#### B: Dense iteration — O(count) via indirection layer

Maintain a packed array of occupied indices + reverse mapping. Like `DenseSlotMap`: contiguous values with swap-on-remove.

#### C: Bitmap-accelerated — O(capacity/64)

Maintain a `Bit.Vector` alongside tokens. Use `bitmap.ones` for fast iteration.

**Recommendation**: **Option A** (sparse, O(capacity)). Rationale:

1. **Simplicity**: No indirection layer, no secondary data structure.
2. **Proven adequate**: `generational-arena`, `thunderdome`, basic `slotmap` all use O(capacity) iteration.
3. **Capacity ≈ count in practice**: Arenas typically have moderate fragmentation. The constant factor is small (one branch per slot).
4. **Dense adds complexity**: Swap-on-remove invalidates indices, which defeats the purpose of stable handles. The `DenseSlotMap` works around this with an indirection layer, but that adds a pointer chase per access.
5. **Bitmap can be added later**: If O(capacity) iteration proves insufficient, a bitmap layer (like Slab's) can be composed on top without changing the core API.

### SQ6: Variants

Following the established buffer-primitives pattern:

| Variant | Storage | Growth | Deinit | Use Case |
|---------|---------|--------|--------|----------|
| **Arena** | Heap + aux pointers | Auto-grow | Scan tokens | General-purpose trees, graphs |
| **Arena.Bounded** | Heap + aux pointers | Fixed, throws | Scan tokens | Fixed-size pools, ECS |
| **Arena.Inline\<capacity\>** | Inline + InlineArray | Fixed, throws | Scan tokens | Small trees, zero-alloc |
| **Arena.Small\<inlineCapacity\>** | Inline → Heap spill | Spill to heap | Scan tokens | Hybrid: small fast, large ok |

All four variants follow the same pattern as Ring, Linear, Slab, and Linked.

**Recommendation**: Implement **Arena** (growable) and **Arena.Bounded** (fixed) first. These cover Tree.N and Tree.N.Bounded directly. Add Inline and Small later for Tree.N.Inline and Tree.N.Small.

### SQ7: Element Lifecycle Management

**Options**:

#### A: Arena deinit scans tokens, deinitializes occupied elements

Arena owns element lifecycle. `storage.initialization = .empty` (Storage.Heap's deinit does nothing). Arena's deinit iterates all slots, checks token parity, deinitializes occupied elements, then deallocates auxiliary arrays.

#### B: Storage.Pool handles lifecycle via bitmap

Pool's deinit iterates bitmap, deinitializes allocated elements. Arena only manages tokens.

#### C: Consumer-managed (like Slots)

Arena has no deinit. Consumer must call `removeAll()` before dropping.

**Recommendation**: **Option A** (arena-managed, token-driven). Rationale:

1. **Safety**: Automatic cleanup prevents resource leaks for `~Copyable` elements.
2. **Follows Slab pattern**: Slab has explicit deinit that iterates bitmap. Arena iterates tokens instead.
3. **No split responsibility**: Arena owns everything — elements, tokens, free-list. Clean boundary.
4. **Compiler workaround**: Use `for i in 0..<capacity` loop instead of closure in deinit (same workaround as Slab for the MoveOnlyChecker deinit closure crash).

---

## Design Summary

### Three-Layer Architecture

```
Layer 1: Header         — count, capacity, freeHead (Copyable, Sendable)
Layer 2: Static Ops     — allocateSlot, freeSlot, validate, insert, remove, forEach
Layer 3: Composed Types — Arena, Arena.Bounded (+ future Inline, Small)
```

### Storage Layout

```
Buffer<Element>.Arena {
    header:    Header                           // count, capacity, freeHead
    storage:   Storage<Element>.Heap            // element slots
    _tokens:   UnsafeMutablePointer<UInt32>     // generation per slot
    _nextFree: UnsafeMutablePointer<Int>        // free-list links per slot
}
```

Memory per slot: `stride(Element) + 4 (token) + 8 (nextFree)` = `stride(Element) + 12 bytes`.

### Position Type

```swift
Buffer<Element>.Arena.Position {
    let index: Int          // slot coordinate (compatible with Index<Element>)
    let token: UInt32       // generation at allocation time
}
```

Size: 16 bytes (8 + 4 + padding). `Copyable`, `Sendable`, `Equatable`, `Hashable`.

### Header Type

```swift
Buffer<Element>.Arena.Header: Copyable, Sendable {
    var count: Int          // number of occupied slots
    var capacity: Int       // total slot count
    var freeHead: Int       // index of first free slot, -1 = none
}
```

### Token Scheme

- Even token → free slot
- Odd token → occupied slot
- Token starts at 0 (free, never allocated)
- Allocate: increment token (even → odd)
- Free: increment token (odd → even)
- Validate: `tokens[position.index] == position.token && token & 1 == 1`

### Core Operations (Static, Layer 2)

```
allocateSlot(header:, storage:, _tokens:, _nextFree:) -> Position
    If freeHead >= 0: pop from free-list, increment token
    Else: use next virgin slot (index = count-of-ever-allocated, i.e. header.capacity track)
    Return Position(index, new_token)

freeSlot(at:, header:, storage:, _tokens:, _nextFree:)
    Deinitialize element at slot
    Increment token (odd → even)
    Push slot onto free-list head

validate(position:, _tokens:) -> Bool
    tokens[position.index] == position.token && position.token & 1 == 1

insert(element:, header:, storage:, _tokens:, _nextFree:) -> Position
    allocateSlot + initialize element at slot

remove(at:, header:, storage:, _tokens:, _nextFree:) -> Element
    validate + move element + freeSlot

forEachOccupied(_tokens:, capacity:, body:)
    for i in 0..<capacity where tokens[i] & 1 == 1: body(i)

deinitializeAll(header:, storage:, _tokens:, _nextFree:)
    forEachOccupied: deinitialize element, reset token to 0
    Reset header (count=0, freeHead=-1)
```

### Growth (Growable Variant Only)

```
ensureCapacity(minimumCapacity:)
    newCapacity = max(minimumCapacity, max(capacity * 2, 4))
    Allocate new storage + tokens + nextFree
    Copy occupied elements (move, not copy)
    Copy tokens and nextFree arrays (memcpy)
    Set old storage.initialization = .empty
    Deallocate old auxiliary arrays
    Replace storage + auxiliary pointers
```

### CoW (When Element: Copyable)

```
ensureUnique()
    if !isKnownUniquelyReferenced(&storage):
        Create new storage + tokens + nextFree
        Copy elements (init, not move) for occupied slots
        Copy tokens + nextFree (memcpy)
        Replace storage + auxiliary pointers
```

### Deinit

```
deinit {
    for i in 0..<capacity where tokens[i] & 1 == 1:
        storage.deinitialize(at: Index<Element>(i))
    storage.initialization = .empty
    _tokens.deallocate()
    _nextFree.deallocate()
}
```

### Error Type

```swift
Buffer<Element>.Arena.Error: Swift.Error, Sendable, Equatable {
    case invalidPosition
    case full                   // Bounded only
}
```

---

## Comparison with Existing Disciplines

| Aspect | Slab | Arena | Linked |
|--------|------|-------|--------|
| **Slot assignment** | Consumer-chosen | Arena-chosen | Pool-chosen |
| **Occupancy tracking** | Bitmap (Bit.Vector) | Token parity | Pool bitmap |
| **Stale reference detection** | None | Generation tokens | None |
| **Free-list** | None (bitmap scan) | Separate array, LIFO | In-band overlay |
| **First vacant** | O(word-count) bitmap scan | O(1) free-list pop | O(1) pool alloc |
| **Iteration** | O(count) via bitmap.ones | O(capacity) via token scan | O(count) via link traversal |
| **Storage** | Storage.Heap | Storage.Heap + aux | Storage.Pool |
| **Header** | ~Copyable (owns Bit.Vector) | Copyable (just ints) | Copyable |
| **Deinit** | Iterates bitmap.ones | Iterates tokens | Pool deinit |

**Key differentiator**: Arena is the only discipline with **stale reference detection**. This makes it suitable for graph data structures where handles are stored externally and may outlive the element they point to.

---

## Naming Analysis

The name `Arena` in buffer-primitives conflicts terminologically with `Storage.Arena` (bump allocator). However:

1. They operate at different layers: `Storage.Arena` is Layer 0 (raw memory); `Buffer.Arena` is Layer 1 (typed element management).
2. The buffer layer adds: typed elements, generation tracking, slot recycling, automatic deinit. These are categorically different from bump allocation.
3. The term "arena" is well-established in the Rust/gamedev ecosystem for this exact pattern (`generational-arena`, Bevy entities).
4. Alternative names considered: `Buffer.Pool` (conflicts with `Storage.Pool`), `Buffer.SlotMap` (compound name violates [API-NAME-001]), `Buffer.Generational` (adjective, not a noun).

**Decision**: `Buffer.Arena` is the correct name. The layer distinction (`Storage` vs `Buffer`) provides sufficient disambiguation.

---

## Resolved Questions

### Q1: Virgin Cursor — RESOLVED: Use `count` as implicit virgin cursor

When the free-list is empty, `count` (occupied slots) equals the high-water mark of ever-allocated slots. The invariant: `count + free_list_size = next_virgin_index`. When free-list is empty, `count = next_virgin_index`. This is exactly what Tree.N does. No separate `nextVirgin` field needed.

Proof by trace:
- Allocate 0,1,2 (count=3). Free 0 (count=2, freeHead=0). Free 1 (count=1, freeHead=1→0). Re-allocate from free-list: slot 1 (count=2). Re-allocate from free-list: slot 0 (count=3). Free-list empty, count=3 → next virgin at index 3. Correct.

### Q2: Why Storage.Heap over Storage.Pool — RESOLVED

**Storage.Pool was considered** (it has free-list + bitmap), but rejected because:
1. **Index stability on growth**: Pool's `allocate()` assigns arbitrary indices. Arena needs to copy elements to the SAME indices in a grown storage, bypassing Pool's allocation API.
2. **In-band free-list constraint**: Pool requires `stride(Element) >= size(Index<Element>)`. Arena's separate nextFree array has no such constraint.
3. **Split responsibility**: Pool manages both allocation and element memory. Arena needs to own the full lifecycle (tokens drive cleanup, not Pool's bitmap).
4. **Inline variant**: Pool is a class; inline Arena needs value-type storage.

**Storage.Heap is the right choice**: Simple element storage with `pointer(at:)`, `initialize(to:at:)`, `move(at:)`, `deinitialize(at:)`. Arena manages lifecycle via tokens + nextFree. Consistent with Slab pattern.

### Q3: Secondary maps — DEFERRED

Consumer-level concern, not a buffer primitive.

### Q4: Subscript access — RESOLVED: Precondition

Subscript traps on invalid position (precondition per [IMPL-040]). Separate `isValid(_:)` method for safe checking. This matches the existing pattern where `pointer(at:)` and subscripts precondition, while high-level tracked operations throw.

### Q5: Infrastructure gaps — RESOLVED: None

Thorough survey of memory-primitives, storage-primitives, index-primitives, and buffer-primitives confirms **all necessary infrastructure exists**:

| Need | Provided By |
|------|------------|
| Element storage | `Storage<Element>.Heap` with `create(minimumCapacity:)` |
| Element access | `storage.pointer(at: Index<Element>)` |
| Element init/move/deinit | `storage.initialize(to:at:)`, `storage.move(at:)`, `storage.deinitialize(at:)` |
| Lifecycle bypass | `storage.initialization = .empty` |
| Capacity query | `storage.slotCapacity` |
| CoW check | `isKnownUniquelyReferenced(&storage)` |
| Typed indices | `Index<Element>` = `Tagged<Element, Ordinal>` |
| Typed counts | `Index<Element>.Count` = `Tagged<Element, Cardinal>` |
| Zero-cost retagging | `.retag(Element.self)`, `.retag(Bit.self)` |
| Count→Index conversion | `.map(Ordinal.init)` |
| Int→Ordinal | `Ordinal(UInt(i))` |
| Int↔Count | `Int(bitPattern: count)`, `Index<Element>.Count(Cardinal(UInt(n)))` |
| Drain protocol | `Sequence.Drain.Protocol` with `mutating func drain(_:)` |
| Property views | `Property<Tag, Base>.View` with `_read`/`_modify` |

No additions to memory-primitives, storage-primitives, or index-primitives are required.

---

## Outcome

**Status**: IN_PROGRESS

**Recommendation**: Implement `Buffer<Element>.Arena` as a sixth buffer discipline following the design summarized above. Start with Arena (growable) and Arena.Bounded (fixed), using Storage.Heap + separate token and nextFree arrays, UInt32 parity-tagged tokens, and Copyable Position handles.

**Implementation path**:
1. Add Arena struct declarations to `Buffer Primitives Core/Buffer.swift`
2. Create `Sources/Buffer Arena Primitives/` module
3. Implement static operations (allocateSlot, freeSlot, insert, remove, validate, forEach)
4. Implement composed types (Arena, Arena.Bounded)
5. Add to Package.swift
6. Unit tests

**Next steps**:
- Resolve open question 1 (virgin cursor) during implementation
- Migrate Tree.N to Buffer.Arena (Phase 3b)
- Add Inline and Small variants for Tree.N.Inline and Tree.N.Small (Phase 3b/3c)

## References

- Catherine West, "Using Generational Indices to Avoid the ABA Problem," RustConf 2018 Closing Keynote
- Orson Peters, `slotmap` crate, [docs.rs/slotmap](https://docs.rs/slotmap)
- Nick Fitzgerald, `generational-arena` crate, [docs.rs/generational-arena](https://docs.rs/generational-arena)
- Lucien Greathouse, `thunderdome` crate, [docs.rs/thunderdome](https://docs.rs/thunderdome)
- Allan Deutsch, "P0661: A `slot_map` Container for the C++ Standard Library," ISO/IEC C++ Proposal
- Bevy Engine Entity Allocation, [deepwiki.com/bevyengine/bevy/2.1](https://deepwiki.com/bevyengine/bevy/2.1-world-and-entity-management)
