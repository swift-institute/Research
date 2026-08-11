# Hash Table Storage-Buffer Layering

<!--
---
version: 3.0.0
last_updated: 2026-06-03
status: DECISION
research_tier: 2
applies_to: [swift-hash-table-primitives, swift-buffer-primitives, swift-storage-primitives, swift-hash-primitives, swift-storage-split-primitives, swift-buffer-slots-primitives]
normative: true
collaborative_review: Claude (Anthropic) + ChatGPT (OpenAI), 3 rounds, converged
---
-->

## Context

`Hash.Table<Element>` (hash-table-primitives) is an open-addressed hash table that manages its own memory via a custom `Storage` class inheriting from `ManagedBuffer<Header, Int>`. This stands apart from the ecosystem's canonical pattern where data structures delegate element lifecycle to `Storage<Element>.Heap` (from storage-primitives) and buffer discipline to `Buffer.Linear`, `Buffer.Ring`, or `Buffer.Slab` (from buffer-primitives).

**Trigger**: [RES-001] Investigation — should `Hash.Table.Storage` be replaced with a buffer from buffer-primitives?

**Scope**: Per [RES-002a], this is a cross-package investigation: the decision affects hash-table-primitives, and the answer depends on the capabilities of buffer-primitives, bit-vector-primitives, and storage-primitives.

## Question

Should `Hash.Table`'s internal `Storage : ManagedBuffer<Header, Int>` be replaced with a buffer from buffer-primitives, and if so, which buffer discipline (Linear, Ring, Slab) matches the hash table's access pattern?

## Analysis

### Current Hash.Table Storage Design

`Hash.Table.Storage` at `Hash.Table.swift:104-172`:

```swift
package final class Storage: ManagedBuffer<Header, Int> {
    package static func create(capacity: Index<Bucket>.Count) -> Storage
    package var hashesPointer: UnsafeMutablePointer<Int>
    package var positionsPointer: UnsafeMutablePointer<Int>
    package func readHash(at bucket: BucketIndex) -> Int
    package func readPosition(at bucket: BucketIndex) -> Index<Element>
    package func writeHash(at bucket: BucketIndex, value: Int)
    package func writePosition(at bucket: BucketIndex, value: Index<Element>)
}
```

**Key characteristics**:
1. **Dual-array layout**: A single allocation holds `[hashes...][positions...]` — two logically separate arrays of `Int`, packed contiguously
2. **Element type is `Int`**: Both hashes and positions are stored as `Int`. The `Element` phantom type parameterizes `Hash.Table`, not `Storage`
3. **Power-of-two capacity**: Always a power of two for fast modulo via bitmasking
4. **No initialization tracking**: All slots are initialized at creation (`repeating: 0`). The sentinel `0` means "empty"
5. **No growth tracking**: Growth is handled at the `Hash.Table` level, not in Storage
6. **No element lifecycle**: `Int` is trivial — no `deinit`, no move semantics, no `~Copyable` concerns
7. **Reference semantics**: `final class` (ARC-managed, single owner)

### The Ecosystem's Canonical Layering Pattern

From the storage-primitives comparative analysis (§3.2), the canonical pattern is:

```
Collection/ADT (Stack, Queue, Set.Ordered)
        ↓ uses
Buffer (Linear, Ring, Slab)
        ↓ uses
Storage (Heap, Inline)
        ↓ uses
Pointer (UnsafeMutablePointer<T>)
```

Real implementations vary:

| Data Structure | Uses Buffer? | Uses Storage? | Notes |
|---------------|-------------|--------------|-------|
| Stack | No | Yes (Storage.Heap) | Implicit linear discipline |
| Queue | Buffer.Ring.Header | Custom ManagedBuffer | Ring discipline via header |
| Set.Ordered | No | Yes (Storage) + Hash.Table | Two independent stores |

**Observation**: Not every data structure follows the full stack. Stack skips Buffer and goes directly to Storage. Queue uses Buffer.Ring.Header but creates its own ManagedBuffer. Set.Ordered composes Storage + Hash.Table side-by-side. The pattern is a guideline, not a rigid requirement.

### What Hash.Table Stores vs What Buffers Manage

The fundamental mismatch:

| Aspect | Hash.Table.Storage | Buffer.Linear/Ring/Slab |
|--------|-------------------|------------------------|
| **Element type** | `Int` (trivial) | `Element: ~Copyable` (arbitrary) |
| **Initialization** | All slots always initialized (sentinel = 0) | Tracks init/deinit lifecycle |
| **Layout** | Dual-array: `[hashes...][positions...]` | Single-array: `[elements...]` |
| **Occupancy** | Tracked via sentinels (0 = empty, Int.min = deleted) | Tracked via count/header/bitmap |
| **Growth** | Table-level (create new, rehash all) | Buffer-level (grow, copy) |
| **Access pattern** | Random (hash → bucket → probe) | Sequential (Linear), circular (Ring), sparse (Slab) |

### Option A: Replace Storage with Buffer.Linear

Use two `Buffer.Linear` instances — one for hashes, one for positions.

```swift
public struct Table<Element: ~Copyable>: ~Copyable {
    var _hashes: Buffer.Linear    // of Int
    var _positions: Buffer.Linear // of Int
}
```

**Problems**:
1. **Two heap allocations** instead of one. Buffer.Linear wraps `Storage<Int>.Heap`, each with its own `ManagedBuffer`. The current design uses a single allocation for both arrays
2. **Unnecessary initialization tracking**. Buffer.Linear tracks `count` and initialization state. Hash.Table needs all slots always initialized with sentinels — no lifecycle tracking needed
3. **Growth mismatch**. Buffer.Linear grows by appending. Hash.Table grows by creating a completely new table and rehashing all entries — the old buffer would be discarded entirely, not grown in-place
4. **API overhead**. Buffer.Linear provides `append`, `consumeFront`, `removeLast` — none of which apply to a hash table. The relevant operation is random access by bucket index

**Verdict**: Poor fit. Buffer.Linear's append-based discipline is the opposite of hash table random access.

### Option B: Replace Storage with Buffer.Slab

Use a `Buffer.Slab` — sparse, index-addressed slots with bitmap tracking.

```swift
public struct Table<Element: ~Copyable>: ~Copyable {
    var _hashes: Buffer.Slab     // of Int, bitmap = occupancy
    var _positions: Buffer.Slab  // of Int, bitmap = occupancy
}
```

**Better fit than Linear**:
- Slab supports random-access insert/remove at arbitrary indices
- Bitmap tracking aligns with the concept of "occupied" vs "empty" buckets
- No assumption of sequential access

**Problems**:
1. **Still two heap allocations** instead of one
2. **Redundant occupancy tracking**. Slab uses `Bit.Vector` to track which slots are occupied. Hash.Table already tracks this via sentinel values (0 = empty, Int.min = deleted). Adding bitmap tracking on top of sentinels is pure overhead — they encode the same information
3. **No tombstone concept**. Slab has a binary state: occupied or vacant. Hash.Table needs a ternary state: empty / occupied / deleted (tombstone). The tombstone is essential for linear probing correctness — removing it breaks probe chains
4. **Slab manages `~Copyable` lifecycle**. Hash.Table stores `Int`, which needs no lifecycle management. The `~Copyable` tracking machinery (deinit iteration, move semantics) is dead weight
5. **Slab expects `Element: ~Copyable`**. Hash.Table's element type is `Int` (always Copyable). The `Element` phantom type on `Hash.Table<Element>` parameterizes the *positions* (what the indices point to), not the stored values

**Verdict**: Closer, but the sentinel-based ternary state, dual-array layout, and trivial element type make Slab a poor semantic fit.

### Option C: Replace Storage with Buffer.Slab + Bit.Vector (Custom)

Use `Bit.Vector` from bit-vector-primitives directly for occupancy, replacing sentinels.

```swift
public struct Table<Element: ~Copyable>: ~Copyable {
    var _hashes: Storage<Int>.Heap    // raw hash values
    var _positions: Storage<Int>.Heap // raw positions
    var _occupancy: Bit.Vector        // which buckets are occupied
    var _deleted: Bit.Vector          // which buckets are tombstones
}
```

**Analysis**:
- Replaces sentinel encoding with explicit bitmaps
- Eliminates sentinel-collision normalization (`0` and `Int.min` no longer special)
- Enables hardware `popcount` for fast count
- Enables efficient iteration via set-bit enumeration

**Problems**:
1. **Four separate allocations** (two Storage.Heap + two Bit.Vector) instead of one
2. **More memory** for small tables: two Bit.Vectors at `ceil(capacity/64) × 8` bytes each, vs zero overhead for sentinel encoding
3. **Sentinel normalization is cheap**: The `normalize()` function is 2 branches — the "problem" it solves is marginal
4. **Breaks the existing API contract**: All current users depend on the sentinel protocol
5. **No functional gain**: The current sentinel approach is correct, tested, and performant. The bitmap approach trades one correct encoding for another

**Verdict**: Technically possible but net negative. Trades a simple, proven sentinel encoding for a more complex multi-allocation scheme without meaningful benefit.

### Option D: Keep Current Design (No Change)

Keep `Hash.Table.Storage : ManagedBuffer<Header, Int>` as-is.

**Arguments for**:
1. **Single allocation**: One `ManagedBuffer` for header + hashes + positions. Optimal memory locality
2. **Trivial element type**: `Int` has no lifecycle — no `~Copyable` concerns, no deinit, no move semantics. The entire buffer/storage machinery exists to solve problems Hash.Table doesn't have
3. **Sentinel-based state is correct**: Ternary state (empty/occupied/deleted) encoded in the hash value is a classic, proven technique for open-addressed hash tables. It's used in CPython's `dict`, Rust's `hashbrown`, Go's `map`, and abseil's `flat_hash_map`
4. **Dual-array layout is deliberate**: Separating hashes from positions enables cache-friendly scanning of hashes during probing (only positions are touched on match). This layout optimization would be lost if each bucket were stored as a `(hash, position)` tuple in a buffer
5. **Hash table growth is incompatible with buffer growth**: Buffer growth policies (doubling, copying existing elements) assume the old elements remain valid. Hash table growth requires complete rehashing — every entry must be re-probed into the new table. No buffer growth policy handles this
6. **Pattern precedent**: Queue also creates its own custom `ManagedBuffer` subclass rather than using `Storage.Heap` directly. This is an established pattern in the ecosystem when the data structure's internal requirements diverge from the generic storage contract

**What about the Static variant?**

`Hash.Table.Static<let bucketCapacity: Int>` already follows the inline pattern:
```swift
var _hashes: InlineArray<bucketCapacity, Int>
var _positions: InlineArray<bucketCapacity, Int>
```

This mirrors `Storage<Element>.Inline<capacity>` in spirit (stack-allocated, compile-time capacity) but appropriately uses `InlineArray<N, Int>` directly rather than `Storage<Int>.Inline<capacity>`, because:
- `Storage.Inline` uses `@_rawLayout` and tracks per-slot initialization via `Bit.Vector.Static<4>` — 32 bytes of tracking overhead for slots that are *always initialized* with sentinels
- `InlineArray` is the stdlib's native fixed-capacity inline array — it's what `Storage.Inline` itself is built on

### Why Hash.Table Is Not a Storage-Buffer-ADT Type

The storage→buffer→ADT pattern serves types that need to **manage element lifecycle** (initialization, deinitialization, move semantics) over **dynamically occupied** slots with **growth discipline** (linear append, ring wrap, slab insert/remove).

Hash.Table does none of these:

| Concern | Storage→Buffer→ADT | Hash.Table |
|---------|-------------------|------------|
| Element lifecycle | Yes — `~Copyable` elements need init/deinit/move | No — stores `Int`, always trivial |
| Dynamic occupancy | Yes — count tracks how many slots are "alive" | No — all slots always initialized with sentinel |
| Growth discipline | Yes — append to end, push to ring, insert in slab | No — growth = complete rebuild via rehash |
| Access pattern | Sequential, circular, or sparse | Random probe sequences |
| Stored values | The elements themselves | *Indices into* external element storage |

Hash.Table is an **index structure** (maps hash values to positions in external storage), not a **container** (owns elements). The storage-buffer-ADT pattern is for containers. Index structures manage their own internal representation because their requirements are fundamentally different.

This is exactly like how a B-tree's internal node structure wouldn't use `Buffer.Linear` — the access pattern (binary search within a node, split/merge between nodes) doesn't match any buffer discipline.

### Comparison with Set.Ordered

Set.Ordered illustrates the correct decomposition:

```
Set.Ordered
├── elementStorage: Storage<Element>    ← Container concern: owns elements
└── hashTable: Hash.Table<Element>      ← Index concern: maps hash→position
```

`elementStorage` follows the storage-buffer pattern (elements need lifecycle management). `hashTable` manages its own internal representation (sentinel-based, dual-array, hash-aware). **They serve different roles and correctly use different patterns.**

If Hash.Table delegated to Buffer, it would be an index structure pretending to be a container. The abstraction boundary would be at the wrong level.

## Outcome

**Status**: DECISION (Normative) — realized 2026-06-03

> **v3.0.0 — Realized end state (normative).** The principled redesign below is no longer future state: it is implemented. `Hash.Table` now composes the canonical **`Hash.Table → Buffer.Slots → Storage.Split`** layering. Workstream 3 (§ Principled Redesign) shipped as `Buffer<Element>.Slots<Metadata>` (`swift-buffer-slots-primitives`), a metadata-parametric **buffer** discipline — a peer to Linear/Ring/Slab — backed by `Storage<Element>.Split<Metadata>` (`swift-storage-split-primitives`). `Hash.Table.Storage : ManagedBuffer<Header, Int>` is **removed**; `Hash.Table.swift:78` is now `package var _buffer: Buffer<Int>.Slots<Int>`. The buffer-level discipline (copy-on-write `ensureUnique()`, predicate `deinitialize(where:)`) lives on `Buffer.Slots`, **not** on `Storage.Split` (see § GAP-O Fold and Reversal). Verified green 2026-06-03: storage-split 18 / buffer-slots 22 / hash-table 27 tests. The provisional decision below is preserved as the historical record of why the ManagedBuffer design was tolerated in the interim.

### GAP-O Fold and Reversal (2026-06-03) — the "buffer = occupancy" premise is REFUTED

A June 2026 GAP-O excursion ("Q2") folded `Buffer.Slots` *out* of the stack — re-pointing `Hash.Table` directly onto `Storage<Int>.Split<Int>` and emptying `Buffer.Slots` to a shell — on the premise that **"a buffer IS an occupancy discipline,"** so a slot buffer that tracks no occupancy "isn't really a buffer." That premise is **REFUTED**:

- `Buffer.Slots` deliberately tracks **no** occupancy/lifecycle — its locked requirement R4 in `metadata-parametric-slots.md`. Occupancy is the **consumer's**, expressed through the metadata lane (`Hash.Table` reads the hash-lane sentinel; a Swiss-table reads `0x80`/`h2`). "Non-conformer of an occupancy protocol" ≠ "not a buffer." `Buffer.Slots` is a legitimate buffer discipline whose discipline is *metadata-parametric random-access slots*, not occupancy tracking. Its peer status (alongside Linear/Ring/Slab) is established in `metadata-parametric-slots.md` § SQ5.
- The fold "worked" only because it smuggled the buffer-level discipline (CoW + predicate-deinit) **down** into `Storage.Split`, which by `[DS-005]` tracks no lifecycle ("NO element deinit; consumer manages lifecycle") — already the loosest-fit member of the Memory/Storage/Buffer triad. The apparent success was the **symptom** of layer-boundary overreach, not validation of the bypass.
- Both this document (the principled end state is a metadata-parametric slot **buffer** — *"lack of a fitting buffer is a signal that buffer-primitives is incomplete, not that Hash.Table is exempt"*) and `metadata-parametric-slots.md` (Outcome #8: **"`Hash.Table → Buffer.Slots → Storage.Split` — no bypass"**) had already settled this through converged collaborative research. The fold contradicted both; the root cause was skipping the `[RES-019]` prior-research grep until late.

The fold was reversed 2026-06-03 by dropping the three local, unpushed fold commits (`reset --hard`); the researched layering is restored and green. The separate, still-open question — whether `Storage.Split` should slim to a **Memory-tier** SoA region with `Buffer.Slots` carrying the full discipline (the Memory/Storage/Buffer boundary-definition consolidation) — is tracked as a Class-(c) ecosystem-architecture item and does **not** affect the `Hash.Table → Buffer.Slots → Storage.Split` chain established here.

---

**Historical provisional decision (v2.0.0, 2026-02-07):**

**Status**: DECISION (Provisional)

**Decision**: Retain `Hash.Table.Storage : ManagedBuffer<Header, Int>` as a provisional implementation. The current design is **semantically incorrect** at the storage tier but **operationally sound**. It is tolerated until the required buffer-primitives infrastructure exists.

### Why Provisional

The initial analysis (Options A-D above) correctly identifies that no **existing** buffer discipline fits Hash.Table. However, collaborative review (Claude + ChatGPT, 3 rounds) established that this is a signal that **buffer-primitives is incomplete**, not that Hash.Table is exempt from the layering pattern.

The current design has three semantic violations (§Semantic Violations below). The principled end state requires three independent workstreams (§Principled Redesign below). Until those workstreams deliver, the current design is the best available implementation.

### Operational Rationale (Why Current Design Is Tolerated)

These arguments justify retaining the current design **provisionally**:

1. **The dual-array, single-allocation layout is optimal**. Splitting into two buffers doubles heap allocations and loses cache locality. No buffer type supports the dual-array-in-one-allocation pattern
2. **Growth semantics are incompatible with existing buffers**. Buffer growth preserves existing elements. Hash table growth requires complete rehashing. No buffer growth policy can express this
3. **Ecosystem precedent**. Queue similarly creates its own custom `ManagedBuffer` subclass. Custom storage for specialized data structures is an established pattern when the data structure's internal requirements diverge from the generic storage contract
4. **The API layer is already typed**. `Index<Bucket>`, `Index<Element>`, `BucketIndex`, typed counts — the public and package-level API respects the typed coordinate system. The violations are in the storage representation, not the semantic interface

### What This Research Clarifies About the Pattern

The storage→buffer→data structure→ADT layering pattern applies to **container types that own elements**:

| Type | Owns elements? | Uses Storage/Buffer? | Correct? |
|------|---------------|---------------------|----------|
| Stack | Yes | Storage.Heap | Yes |
| Queue | Yes | Custom ManagedBuffer + Buffer.Ring.Header | Yes |
| Set.Ordered | Yes (via elementStorage) | Storage + Hash.Table (side-by-side) | Yes |
| Hash.Table | No (stores indices) | Own ManagedBuffer | Provisional |
| Buffer.Linear/Ring/Slab | Yes | Storage.Heap / Storage.Inline | Yes |

**Hash.Table is a leaf dependency** — it is consumed by container types (Set.Ordered, Dictionary.Ordered) alongside their element storage. It should not itself consume the **current** storage-buffer stack, but it should consume the **principled** stack once it exists.

**Note on "index vs container" framing**: The initial analysis used this taxonomy as the primary justification. Collaborative review established that this distinction is rhetorically useful but structurally insufficient. The actual justification is the **representation constraints** (dual-array layout, ternary bucket state, rehash growth, single allocation). These are the load-bearing reasons, not the taxonomy.

---

## Semantic Violations (Known and Accepted)

The current design contains three semantic violations. These are documented as known debt, not as acceptable permanent state.

### SV-1: Sentinel Encoding Mixes Concerns

**Violation**: Bucket state (empty / occupied / deleted) is encoded in the hash value lane using sentinels (`0` = empty, `Int.min` = deleted). This means the hash value carries both "what is the hash?" and "what is the bucket state?" in a single `Int`.

**Evidence**: The `normalize()` function maps `0 → 1` and `Int.min → 1` to avoid sentinel collisions. This is a normalization hack that exists solely because state and value share a domain.

**Principled requirement**: Bucket state MUST be separate from hash value. Per-slot metadata should be an explicit type, not sentinel-encoded into the payload.

### SV-2: Typed Values Stored as Raw Integers

**Violation**: `Index<Element>` values are stored as bit-pattern-cast `Int` in the `ManagedBuffer`. The storage layer violates typed index semantics internally, even though the API boundary converts to/from typed coordinates on every access.

**Evidence**: `Hash.Table.swift:170` — `positionsPointer[idx] = Int(bitPattern: value.position.rawValue)` stores a typed index as a raw integer. `Hash.Table.swift:156` reconstructs it via `Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: raw)))`.

**Principled requirement**: Storage layers MUST NOT store typed values as raw integers. `Index<Element>` should be stored as `Index<Element>`, not as a bit-pattern-cast `Int` that happens to be layout-compatible.

### SV-3: Bucket Arithmetic Uses Ad-Hoc Masking

**Violation**: The probe sequence `hash & (capacity - 1)` and `(bucket + 1) & (capacity - 1)` are correct but model cyclic ring arithmetic (Z_{2^n}) using ad-hoc bitwise operations rather than the ecosystem's `Cyclic_Index_Primitives`.

**Principled requirement**: Bucket arithmetic MUST be modeled as cyclic arithmetic using the existing `Cyclic_Index_Primitives` infrastructure.

---

## Principled Redesign (Future State)

The principled end state requires three independent, non-blocking workstreams.

### Workstream 1: `Hash.Value` Newtype (hash-primitives)

**Status**: DONE — implemented as `Hash.Value = Tagged<Hash, Int>`. See `/Users/coen/Developer/swift-primitives/swift-hash-primitives/Research/hash-value-newtype.md`

**Scope**: hash-primitives package

**Requirement**: Introduce `Hash.Value` as a newtype over `Int` that:
- Wraps the raw hash value from `Hashable.hashValue`
- Owns normalization responsibility (currently in `Hash.Table.normalize()`)
- Provides typed arithmetic for hash operations
- Eliminates the "raw Int" from the hash domain

**Dependency**: None. Can proceed immediately.

### Workstream 2: Cyclic Bucket Arithmetic (hash-table-primitives)

**Status**: DONE — replaced all ad-hoc masking with `Modular.successor` and `Ordinal % Cardinal` from `Cyclic_Index_Primitives`

**Scope**: hash-table-primitives package

**Requirement**: Replace ad-hoc masking with `Cyclic_Index_Primitives`:
- Model `BucketIndex` as a cyclic index in Z_{2^n}
- Probe advancement (`nextBucket`) becomes typed cyclic increment
- Initial bucket computation (`bucketFor(hash:)`) becomes typed cyclic projection
- Power-of-two capacity is enforced by the cyclic index type, not by runtime preconditions

**Dependency**: `Cyclic_Index_Primitives` already exists (used by `Buffer.Ring`). No new infrastructure needed.

### Workstream 3: Metadata-Parametric Random-Access Slots (buffer-primitives)

**Status**: DONE — shipped as `Buffer<Element>.Slots<Metadata: BitwiseCopyable>` in `swift-buffer-slots-primitives`, backed by `Storage<Element>.Split<Metadata>` (`swift-storage-split-primitives`). Design + resolved open questions in `swift-buffer-primitives/Research/metadata-parametric-slots.md` (v2.0.0). `Hash.Table` migrated 2026 (`_buffer: Buffer<Int>.Slots<Int>`); the brief GAP-O fold reversal (§ Outcome) preserved the layering.

**Scope**: buffer-primitives package

**Requirement**: A new buffer discipline that provides:
1. **Fixed-capacity, addressable slots** — random access by typed index
2. **Explicit per-slot metadata** — parameterized by metadata type `M`, not hard-coded
3. **Typed payload storage** — no raw-Int representation leaks
4. **No lifetime tracking** — payloads are overwrite-semantic, not init/deinit-semantic
5. **No buffer-level growth** — growth is the consumer's responsibility (rehash-as-growth)
6. **SwissTable-compatible** — metadata type must accommodate byte-granularity control bytes, not just enum states

**Naming constraints** (locked, concrete name deferred to research):
- MUST communicate random-access slots, not contiguity
- MUST NOT encode hash-specific semantics
- MUST fit Nest.Name without suffix inflation
- MUST leave room for SwissTable-style metadata

**Consumer analysis**: Hash.Table is the primary consumer today. The abstraction is justified because "random-access slots with per-slot metadata" is a **fundamental** data-structure primitive (hash tables, Swiss tables, Robin Hood tables, sparse tables with deletion markers, graph adjacency structures). Under the ecosystem's design philosophy, a missing fundamental abstraction is a design bug even with a single current consumer.

**Dependency**: Requires its own Tier 2+ research document before implementation.

### Migration Path

Once all three workstreams deliver:

1. `Hash.Table` adopts `Hash.Value` for hash storage (eliminates SV-1 partially)
2. `Hash.Table` adopts cyclic bucket indices (eliminates SV-3)
3. `Hash.Table` migrates to the new buffer discipline (eliminates SV-1 fully, SV-2)
4. `Hash.Table.Storage : ManagedBuffer<Header, Int>` is removed
5. `Hash.Table.Static` migrates analogously (inline variant of the new buffer)

Each step is independently valuable. Steps 1-2 can proceed before step 3.

---

## Disposition of Original Open Questions

1. **Hash.Table.Storage naming**: Moot. Storage will be replaced by the new buffer discipline. No renaming needed in the interim.

2. **Span.Protocol conformance**: Not applicable. The dual-array layout is a representation concern that will be resolved by the new buffer discipline. Protocol conformance should be evaluated after migration.

3. **Future Swiss-table / SIMD probing**: Addressed by Workstream 3. The metadata-parametric buffer discipline is designed to accommodate Swiss-table control bytes as a natural instantiation.

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-02-06 | Initial analysis. Options A-D evaluated. DECISION: keep current design |
| 2.0.0 | 2026-02-07 | Collaborative review (Claude + ChatGPT, 3 rounds). Reframed to DECISION (Provisional). Added Semantic Violations and Principled Redesign sections. Identified three independent workstreams |
| 3.0.0 | 2026-06-03 | Promoted Provisional → **normative** DECISION. Workstream 3 (`Buffer.Slots`) shipped; `Hash.Table` migrated to `Hash.Table → Buffer.Slots → Storage.Split`. Recorded the GAP-O fold (Q2) reversal and the **refutation** of the "buffer = occupancy discipline" premise. Flagged the open Memory/Storage/Buffer boundary-definition consolidation as a separate Class-(c) item |

## References

- Storage-primitives comparative analysis: `/Users/coen/Developer/swift-primitives/Research/storage-primitives-comparative-analysis.md`
- Inline hash table research: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Research/inline-hash-table.md`
- `Hash.Table.swift`: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift`
- Buffer primitives core: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift`
- Storage primitives: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/`
- Cyclic index primitives: `/Users/coen/Developer/swift-primitives/swift-cyclic-index-primitives/`
- Collaborative discussion transcript: `/tmp/hash-table-storage-layering-transcript.md`
- CPython dict implementation: Objects/dictobject.c (sentinel-based open addressing)
- Rust hashbrown: Swiss-table SIMD probing with control bytes
- abseil flat_hash_map: Swiss-table variant
