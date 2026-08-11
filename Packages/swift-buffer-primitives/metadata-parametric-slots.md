# Metadata-Parametric Random-Access Slots

<!--
---
version: 2.0.0
last_updated: 2026-06-03
status: DECISION
research_tier: 2
applies_to: [swift-buffer-primitives, swift-buffer-slots-primitives, swift-storage-split-primitives, swift-hash-table-primitives]
normative: false
upstream: hash-table-storage-buffer-layering.md (v3.0.0, Workstream 3 — realized)
changelog:
  - 1.1.0: Updated SQ2 to use Storage<Payload>.Split<Metadata> substrate instead of direct ManagedBuffer bypass. Cross-references split-storage-design.md.
  - 2.0.0: Resumed from DEFERRED (resume-condition met — Storage.Split implemented + Hash.Table refactored). Reflected the realized Buffer<Element>.Slots<Metadata> + Storage<Element>.Split<Lane> field-handle API. Resolved OQ-1–OQ-4. Status DEFERRED → DECISION. Flagged the Memory/Storage/Buffer boundary-definition consolidation as a separate open Class-(c) item.
---
-->

## Context

The `hash-table-storage-buffer-layering` research (v2.0.0, DECISION Provisional) established that `Hash.Table.Storage : ManagedBuffer<Header, Int>` is semantically incorrect but operationally sound. No existing buffer discipline (Linear, Ring, Slab) fits hash table storage. The collaborative review (Claude + ChatGPT, 3 rounds, converged) determined this is because **buffer-primitives is incomplete**, not because Hash.Table is exempt from the layering pattern.

Workstream 3 of the principled redesign calls for a new buffer discipline: **metadata-parametric random-access slots**. This research investigates the design space for that abstraction.

**Trigger**: [RES-001] Investigation — design decision cannot be made without systematic analysis of metadata storage layouts, naming, and relationship to existing buffer types.

**Scope**: Per [RES-002a], this is cross-package (buffer-primitives + hash-table-primitives). The new type lives in buffer-primitives but is motivated by hash-table-primitives and must serve future consumers (Swiss-table, Robin Hood, sparse sets).

**Upstream documents**:
- `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Research/hash-table-storage-buffer-layering.md` (v2.0.0) — analysis, semantic violations, principled redesign
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md` (v1.0.0) — three-discipline design (Linear, Ring, Slab)
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/dependency-reuse-audit.md` (v1.0.0) — dependency reuse constraints
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/split-storage-design.md` (v1.0.0) — `Storage<Element>.Split<Lane>` substrate design

**Converged discussion**: `/tmp/hash-table-storage-layering-transcript.md`, converged plan at `/tmp/hash-table-storage-layering-converged.md`

---

## Question

What is the type design, metadata storage layout, naming, initialization semantics, and relationship to existing buffer types for a **metadata-parametric random-access slots** buffer discipline that satisfies the locked requirements from the converged discussion?

### Sub-questions

- SQ1: How should metadata be stored — interleaved with payload, in a separate array, or in a split allocation?
- SQ2: What allocation strategy should the buffer use, and which Storage primitive should it consume?
- SQ3: What initialization semantics should metadata and payload have?
- SQ4: Can this type support `~Copyable` payloads, and should it?
- SQ5: Is this a new peer to `Buffer.Linear` / `Buffer.Ring` / `Buffer.Slab`, or a generalization that subsumes `Buffer.Slab`?
- SQ6: Can the metadata lane efficiently support SIMD-scanned control bytes?
- SQ7: What should this type be named?

---

## Locked Requirements

These requirements are **locked** from the converged collaborative discussion. This research evaluates HOW to satisfy them, not WHETHER they are needed.

| # | Requirement | Source |
|---|------------|--------|
| R1 | Fixed-capacity, addressable slots — random access by typed index | Converged plan |
| R2 | Explicit per-slot metadata — parameterized by metadata type `M`, not hard-coded ternary state | Converged plan |
| R3 | Typed payload storage — no raw-Int representation leaks | Converged plan |
| R4 | No lifetime tracking — payloads are overwrite-semantic, not init/deinit-semantic (OR: lifetime tracking is opt-in, not mandatory) | Converged plan |
| R5 | No buffer-level growth — growth is the consumer's responsibility (rehash-as-growth) | Converged plan |
| R6 | SwissTable-compatible — metadata type must accommodate byte-granularity control bytes, not just enum states | Converged plan |

---

## Prior Art Survey

Per [RES-021], Tier 2 research requires prior art survey of Swift Evolution, related languages, and production implementations.

### Swiss Table (abseil `flat_hash_map`, Rust `hashbrown`)

Swiss table is the state-of-the-art hash table design, deployed in abseil (Google), Rust's standard `HashMap`, and Go 1.24's `map`.

**Metadata**: 1-byte **control byte** (`ctrl_t`, signed `int8_t`) per slot, stored in a **separate, contiguous array** preceding the payload slots in memory. The 64-bit hash is split into H1 (low 57 bits, used as table index) and H2 (top 7 bits, stored in control byte). The control byte encodes:

| State | Value | Hex | Description |
|-------|-------|-----|-------------|
| FULL | `0..127` | `0x00..0x7F` | Occupied; low 7 bits = H2 hash fragment |
| EMPTY | `-128` | `0x80` | Never been occupied |
| DELETED | `-2` | `0xFE` | Tombstone (was occupied, now erased) |
| SENTINEL | `-1` | `0xFF` | End-of-table marker for iterator termination |

The critical encoding: **the high bit distinguishes occupied from non-occupied**. All special states have the high bit set (`≥ 0x80` unsigned). All FULL entries have the high bit clear (`0x00..0x7F`). This enables `_mm_movemask_epi8(ctrl)` to extract the sign bit of each byte, identifying all non-full slots in a group with a single instruction. The H2 fragment provides a 1/128 false-positive rate per slot.

**Layout**: Control bytes form a contiguous array of `capacity + GROUP_WIDTH` bytes. The extra `GROUP_WIDTH` (16) bytes at the end are a **mirror/clone** of the first 16 control bytes — this allows SIMD loads that cross the logical end of the table to wrap around without special-casing. Payload slots follow in a separate contiguous region:

```
Allocation: [ctrl_0..ctrl_{n-1} | ctrl_0..ctrl_15 (cloned) | slot_0 | slot_1 | ... | slot_{n-1}]
             └─ n + 16 control bytes ─────────────────────┘  └─ n payload slots ──────────────┘
```

**SIMD probing**: Groups of 16 control bytes are scanned as a 128-bit SIMD vector:

| Platform | Instruction Set | Group Width | Key Operations |
|----------|----------------|-------------|----------------|
| x86/x86_64 | SSE2 | 16 slots | `_mm_cmpeq_epi8` (compare) + `_mm_movemask_epi8` (extract bitmask) |
| ARM64 | NEON | 16 slots | `vceqq_u8` (compare) + narrowing/shift for bitmask |
| Other | Portable | 8 slots | `u64` bit tricks (broadcast, XOR, isolate zero-bytes) |

The bitmask is scanned with `ctz` (count trailing zeros) to enumerate candidate slots. This reduces a 16-element linear scan to 3 SIMD instructions. Only confirmed H2 matches trigger full key comparison in the payload array.

**Growth**: Load factor target is 7/8 (87.5%), guaranteeing ~2 empty slots per 16-slot group. A `growth_left` counter tracks remaining insertions before resize. When exhausted, the table either:
1. **Doubles capacity and fully rehashes** all elements (common case), or
2. **Rehashes in-place at same capacity** if tombstone accumulation is the cause — converting all DELETED back to EMPTY and re-inserting live elements (compaction without growth).

No incremental rehash — all elements are rehashed in a single operation. H1 values are not cached, so the hash function is re-evaluated for every element during resize.

**Key insight for this research**: The metadata lane is a separate, homogeneously-typed array (all `UInt8`), not interleaved with payload slots. This separation enables SIMD scanning of metadata without touching payload data. The metadata type is fixed at `UInt8` for Swiss table, but the abstraction of "separate metadata array + payload array" is the generalizable pattern.

### Robin Hood Hashing

Robin Hood hashing (Celis, 1986) uses **probe-sequence-length (PSL)** as per-slot metadata — an integer recording how far each entry is displaced from its ideal bucket.

**Metadata**: Integer PSL per slot. Typically stored inline with the element (as a struct field) or in a separate byte/short array. Implementations vary:
- **Inline storage**: `struct Bucket { psl: u8, key: K, value: V }` — PSL occupies 1 byte at the start of each bucket. Cache-friendly for small elements.
- **Separate array**: PSL array + payload array. Cache-friendly for metadata scanning during lookup, at the cost of a second cache line access for the actual element.

**Insertion**: On collision, the entry with the **shorter** PSL yields its slot to the entry with the **longer** PSL ("steal from the rich, give to the poor"). The displaced entry continues probing. This equalizes displacement across all elements, dramatically reducing variance in probe chain lengths.

**Lookup with early termination**: During probing, if the current probe count exceeds the resident element's PSL, the key is absent — any element with the sought key would have displaced this resident during insertion. At load factor 0.9, average probe length is ~2.55 with variance ~0.98 (vs ~16.2 for standard open addressing).

**Deletion**: Two approaches:
- **Tombstones**: Mark slot as deleted. Requires storing hash values even for tombstones to maintain PSL information. Accumulates dead entries.
- **Backward shift** (preferred): Shift subsequent elements backward to fill the gap until encountering PSL=0 or empty. Avoids tombstones entirely, outperforms tombstone approach in practice.

**Key insight for this research**: Robin Hood metadata is an integer, not a byte-sized enum. The metadata type must support at least `UInt8` (for PSL values up to 255), and the layout should support both inline and separate-array configurations.

### CPython Dict (PEP 412, Compact Dict)

CPython 3.6+ uses a **split layout** separating index table from key-value storage:

```
Index table:  [idx_0 | idx_1 | ... | idx_{2^k - 1}]    ← indices into entries
Entries:      [(hash, key, value)_0 | (hash, key, value)_1 | ...]  ← dense, append-only
```

**Metadata**: The index table uses **signed integer** indices with negative sentinel values:

| Constant | Value | Meaning |
|----------|-------|---------|
| `DKIX_EMPTY` | -1 | Slot has never been occupied |
| `DKIX_DUMMY` | -2 | Tombstone (entry deleted) |
| `DKIX_ERROR` | -3 | Error during lookup |
| `DKIX_KEY_CHANGED` | -4 | Dict mutated during iteration |
| Non-negative | 0..n | Index into `dk_entries` array |

Index entries are sized dynamically based on table capacity (since sentinels are negative, signed types are required):

| Table size | Index type | Bytes/slot |
|-----------|-----------|-----------|
| ≤ 128 | `int8_t` | 1 |
| ≤ 32,768 | `int16_t` | 2 |
| ≤ 2^31 | `int32_t` | 4 |
| > 2^31 | `int64_t` | 8 |

The `dk_entries` array is dense and **append-only** (guaranteeing insertion order since Python 3.7). Empty slots in `dk_indices` cost only 1–8 bytes each (vs 24 bytes in pre-3.6 flat layout — a 20–25% memory reduction).

**Key insight for this research**: CPython separates the probing structure (index table with sentinel metadata) from the payload storage (dense entries array). The index table's per-slot "metadata" is actually a fixed-size integer index with sentinel encoding. The variable-width index is an optimization the abstraction should not preclude.

### Google `sparse_hash_map`

Google's `sparse_hash_map` (now superseded by Swiss table) uses **bitmap-tracked groups**:

**Structure**: The `sparsetable` divides its logical address space into **groups of 48 slots** (the `sparsegroup`). Each group contains:

| Component | Size | Purpose |
|-----------|------|---------|
| Bitmap | 48 bits (6 bytes) | 1 bit per logical slot: occupied/empty |
| Data pointer | 4 or 8 bytes | Dynamically allocated array of occupied values only |
| Count | 2 bytes | Number of occupied slots |

**Lookup by position**: To find the element at logical index `i` within a group:
1. Check bit `i` in the bitmap. If 0, the slot is empty.
2. If 1, compute `popcount(bitmap & ((1 << i) - 1))` — count set bits before position `i`.
3. The result is the physical index into the compacted data array.

Insertion reallocs the data array to grow by one element, shifting subsequent entries to maintain bitmap-order correspondence.

**Memory overhead**: Per logical slot, the overhead is `1 + pointer_size×8/48 + 16/48` bits:

| Architecture | Bits/slot | With malloc overhead |
|-------------|----------|---------------------|
| 32-bit | 2 bits | ~4.6 bits |
| 64-bit | 2.67 bits | Higher |

This is dramatically lower than any other surveyed design (Swiss table: 8 bits/slot, Robin Hood: 8+ bits/slot).

**Key insight for this research**: The bitmap metadata is conceptually similar to `Bit.Vector` in buffer-primitives' existing `Buffer.Slab`. The distinction is that sparse_hash_map uses the bitmap to **compress** storage (only allocated entries consume memory), while our abstraction uses fixed-capacity pre-allocated storage. However, the general pattern — per-slot metadata controlling interpretation of a payload array — is the same.

### Comparison Matrix

| System | Metadata Type | Metadata Width | Layout | SIMD? | Growth | Tombstone |
|--------|--------------|---------------|--------|-------|--------|-----------|
| Swiss table | Control byte (h2 + state) | 1 byte | Separate array | Yes (16-byte groups) | Full rebuild | Tombstone byte + in-place rehash |
| Robin Hood | PSL integer | 1–2 bytes | Inline or separate | No (sequential scan) | Full rebuild | Backward shift or tombstone |
| CPython dict | Index + sentinel | 1–8 bytes (variable) | Separate index table | No | Full rebuild | Sentinel in index |
| sparse_hash_map | Bitmap per group | 1 bit/slot | Separate bitmap + compressed payload | No (popcount) | Incremental (group-level) | Required (sentinel key) |
| Hash.Table (current) | Sentinel in hash lane | 0 extra bytes | Dual array (hashes + positions) | No | Full rebuild (rehash) | Sentinel (Int.min) |
| Buffer.Slab (current) | Bit.Vector bitmap | 1 bit/slot | Separate bitmap + payload | No | Optional grow | Binary (occupied/vacant) |

### Synthesis

All surveyed systems share a common pattern: **per-slot metadata that is logically separate from payload storage**, even when physically co-located. The metadata serves different purposes:

| Purpose | Metadata | Examples |
|---------|----------|---------|
| Slot state (empty/occupied/deleted) | Enum, sentinel, or bitmap | Swiss table, CPython, sparse_hash_map |
| Hash fragment for fast rejection | Truncated hash bits | Swiss table (h2), Robin Hood (full hash stored) |
| Displacement metric | Integer distance | Robin Hood (PSL) |
| Index into external storage | Typed integer | CPython (compact dict) |

The fundamental abstraction is a **pair of parallel arrays** — one for metadata, one for payload — with the metadata type parameterized by the consumer. This is precisely what `Hash.Table.Storage` implements ad-hoc with its `[hashes...][positions...]` dual-array layout, but without type safety or generality.

---

## Analysis

### SQ1: Metadata Storage Layout

#### Option M1: Interleaved (Array of Structs)

```swift
// Conceptual: each slot is (metadata, payload) pair
struct Slot<M, P> { var metadata: M; var payload: P }
// Storage: [Slot_0, Slot_1, ..., Slot_{n-1}]
```

**Pros**: Single array, good locality when metadata and payload are accessed together (e.g., Robin Hood inline PSL).
**Cons**: SIMD scanning of metadata requires gather operations (non-contiguous metadata bytes). Wastes cache lines when scanning metadata only (Swiss table's hot path). Alignment padding between `M` and `P` may waste space. Stride depends on both types.

#### Option M2: Separate Arrays (Struct of Arrays)

```swift
// Two parallel arrays in one allocation
// Layout: [M_0, M_1, ..., M_{n-1}][P_0, P_1, ..., P_{n-1}]
```

**Pros**: Metadata array is contiguous — ideal for SIMD scanning (Swiss table reads 16 consecutive bytes). Cache-friendly for metadata-only operations (probing scans metadata, only touches payload on match). Metadata stride is `MemoryLayout<M>.stride`, independent of payload size.
**Cons**: Two pointer computations per access (metadata pointer + payload pointer). Payload access requires offset by `n * MemoryLayout<M>.stride`.

#### Option M3: Separate Allocations

```swift
// Two independent heap allocations
var metadata: Storage<M>.Heap
var payload: Storage<P>.Heap
```

**Pros**: Maximum flexibility. Can use different storage strategies for metadata and payload.
**Cons**: Two heap allocations (doubles ARC overhead, doubles allocation cost). Loses cache locality between metadata and payload.

#### Recommendation: M2 (Separate Arrays in One Allocation)

M2 is the clear winner:

1. **Swiss table mandates it**: SIMD scanning requires contiguous metadata bytes. M1 (interleaved) would prevent the primary use case.
2. **Cache efficiency**: Hash table probing reads metadata repeatedly but payload rarely. Separate arrays keep the metadata hot path cache-clean.
3. **Single allocation**: M2 can be implemented as a single `ManagedBuffer` with metadata at the start and payload after, preserving the single-allocation advantage of the current `Hash.Table.Storage`.
4. **Prior art consensus**: Swiss table, CPython (compact dict), sparse_hash_map, and even Hash.Table's current dual-array layout all use separate arrays.

M1 remains valid for Robin Hood hashing where PSL is always accessed with the element, but M2 still works for Robin Hood (just less optimal per-access). The abstraction should use M2 by default and let consumers who want interleaved access compose their own struct.

### SQ2: Allocation Strategy

The canonical layering is `ADT → Buffer → Storage → Pointer`. Buffer.Slots MUST consume a Storage primitive, not bypass to ManagedBuffer directly.

#### Option A1: Ad-hoc ManagedBuffer (Bypass)

```swift
// One ManagedBuffer<Header, UInt8> with manual layout — bypasses Storage tier
final class Storage: ManagedBuffer<Header, UInt8> { ... }
```

**Rejected**: Violates the layering constraint. Every buffer discipline MUST consume a Storage primitive. Current bypasses (Queue, Array) are known debt; new types must not add more.

#### Option A2: Two Storage.Heap Instances

```swift
var metadata: Storage<M>.Heap
var payload: Storage<P>.Heap
```

**Pros**: Type-safe. Each storage instance has typed coordinates and initialization tracking. No manual layout.
**Cons**: Two heap allocations. Double ARC overhead. Cache locality loss. Prevents SIMD scanning across metadata+payload cache lines.

#### Option A3: `Storage<Payload>.Split<Metadata>`

```swift
// Single allocation via the new Storage.Split type:
var storage: Storage<Payload>.Split<Metadata>
```

`Storage<Element>.Split<Lane>` is a new peer to `Storage.Heap` and `Storage.Inline`, designed in `split-storage-design.md` (storage-primitives). It provides:
- Single `ManagedBuffer<Header, UInt8>` allocation with `[Lane...][padding][Element...]` layout
- Primary lane (`Element`) accessed via `pointer(at: Index<Element>)` — identical to `Storage.Heap`
- Annotation lane (`Lane`) accessed via `lane.pointer(at:)`, `lane[at:]`, `lane.fill(with:)` — Property accessor pattern
- `Lane: Copyable & Sendable` constraint (metadata is always trivial/copyable)
- No initialization tracking — principled absence matching R4
- Shared `Index<Element>` domain across both lanes

**Pros**: Preserves layering. Single allocation. Typed coordinates via `Index<Payload>`. Primary `pointer(at:)` matches `Storage.Heap` API. Lane accessor provides SIMD-friendly contiguous metadata access.
**Cons**: Requires new Storage type (acceptable — the absence is the gap, not the addition).

#### Recommendation: A3 (`Storage<Payload>.Split<Metadata>`)

A3 is the only option that preserves the canonical layering:

- Single allocation preserves cache locality and matches the current Hash.Table.Storage pattern
- `pointer(at:)` on the primary lane is identical to `Storage.Heap` — the API surface is familiar
- `lane[at:]` and `lane.fill(with:)` provide typed metadata access at the API boundary
- Internal alignment handled by `Storage.Split`'s element region offset computation
- The Storage tier now has three primitives: `Heap` (single-typed, init-tracked), `Inline` (single-typed, stack-allocated), `Split` (dual-typed, consumer-managed)
- See `split-storage-design.md` for the full `Storage.Split` design

### SQ3: Initialization Semantics

Hash.Table initializes **all** slots at creation (`repeating: 0` for hashes, `repeating: 0` for positions). This is the overwrite-semantic model: slots are always initialized, writes overwrite without lifecycle concerns.

The existing buffer disciplines handle initialization differently:

| Discipline | Metadata Init | Payload Init |
|-----------|---------------|-------------|
| Buffer.Linear | Count = 0 at creation | Uninitialized; lifecycle tracked |
| Buffer.Ring | Head = 0, Count = 0 | Uninitialized; lifecycle tracked |
| Buffer.Slab | Bitmap all-clear at creation | Uninitialized; lifecycle tracked |
| **This type** | All slots initialized at creation | **See below** |

#### Option I1: Both Metadata and Payload Initialized at Creation

```swift
init(capacity:, metadataInitial: M, payloadInitial: P)
// All metadata slots set to metadataInitial
// All payload slots set to payloadInitial
```

**Matches**: Current Hash.Table.Storage (all zeroed). Swiss table (all control bytes = `0x80` empty).
**Constraint**: Requires `M` and `P` to be trivially copyable (for `memset`-like initialization). This is fine for `Int`, `UInt8`, but not for `~Copyable` types.

#### Option I2: Metadata Initialized, Payload Uninitialized

```swift
init(capacity:, metadataInitial: M)
// All metadata slots set to metadataInitial (indicates "empty")
// Payload slots are uninitialized (raw memory)
```

**Matches**: Swiss table model (control bytes initialized to "empty", payload slots written on first insert).
**Advantage**: No need to initialize payload for the majority of slots that may never be used.
**Constraint**: Consumer must track which payload slots are valid (via metadata — which is the entire point). Payload writes use `initialize(to:at:)`, not assignment.

#### Option I3: Metadata Initialized, Payload Overwrite-Semantic

```swift
init(capacity:, metadataInitial: M, payloadInitial: P)
// All metadata slots set to metadataInitial
// All payload slots set to payloadInitial
// Subsequent writes use assignment (=), not initialize(to:at:)
```

**Matches**: Hash.Table.Storage current model. All slots always hold valid values.
**Advantage**: Simplest model — no lifecycle tracking needed. Works for trivial types.
**Constraint**: Requires both `M` and `P` to be `Copyable` (for the initial fill). Cannot support `~Copyable` payloads.

#### Recommendation: Two Modes — I2 (Default) and I3 (Trivial Optimization)

The type should support **both** models, controlled by how the consumer creates it:

1. **Default (I2)**: Metadata initialized to a caller-supplied sentinel, payload uninitialized. Consumer uses metadata to determine which payload slots contain valid data. This is the general model that works for all `M` and `P` types, including `~Copyable`.

2. **Convenience (I3)**: When both `M: Copyable` and `P: Copyable` (or more precisely, when both are trivial/`BitwiseCopyable`), provide a convenience initializer that fills all slots. This is the optimized path for Hash.Table's `Int`-typed storage.

The buffer type itself **does not track** initialization. The metadata IS the consumer's initialization tracking mechanism. This satisfies R4 (no lifetime tracking) while still allowing the consumer to build its own tracking on top of the metadata lane.

### SQ4: Interaction with `~Copyable` Payloads

The locked requirements state R4: "No lifetime tracking — payloads are overwrite-semantic, not init/deinit-semantic (OR: lifetime tracking is opt-in, not mandatory)."

#### Option C1: `P: Copyable` Only

Restrict payload to `Copyable` types. Simplifies everything: no init/deinit tracking, all operations use assignment.

**Problem**: Prevents future use with `~Copyable` payloads. Contradicts the ecosystem's `~Copyable`-first design philosophy.

#### Option C2: `P: ~Copyable` with Consumer-Managed Lifecycle

Allow `~Copyable` payloads. The buffer provides raw storage operations (`initialize(to:at:)`, `move(at:)`, `deinitialize(at:)`) but does **not** track which slots are initialized. The consumer uses metadata to manage lifecycle.

**Advantage**: Maximum generality. Hash.Table uses trivial `Int` payloads (no lifecycle needed). A future consumer could use `~Copyable` payloads with metadata-driven lifecycle.
**Risk**: Consumer must correctly deinitialize occupied payload slots before deallocation. The buffer cannot assist because it doesn't know which metadata values indicate "occupied."

#### Option C3: `P: ~Copyable` with Optional Lifecycle Callback

The buffer takes an optional closure `isOccupied: (M) -> Bool` that, if provided, is used during `deinit` to identify which payload slots need deinitialization.

**Advantage**: Opt-in lifecycle tracking without hardcoding the interpretation of metadata.
**Risk**: Stored closure has ARC implications. Complicates the type.

#### Recommendation: C2 (Consumer-Managed Lifecycle)

C2 is the right default for a primitives-tier type:

- The type provides raw operations; the consumer manages semantics
- Hash.Table uses `Int` payloads — no lifecycle concern
- Swiss table uses copyable types in the hot path — no lifecycle concern
- Future consumers wanting `~Copyable` payloads accept the responsibility of lifecycle management (which they must do anyway, since only the consumer knows what metadata values mean "occupied")
- The buffer's `deinit` should deinitialize **all metadata** slots (which are always initialized) but NOT payload slots (since the buffer doesn't know which are valid)

For the common case where `P: BitwiseCopyable`, the buffer's `deinit` trivially does nothing for payload (no destructors to call).

### SQ5: Relationship to Existing Buffer Types

The three existing disciplines from the theoretical design:

| Discipline | State | Operations | Metadata |
|-----------|-------|-----------|----------|
| Linear | Count | append, consumeFront | None (implicit: slots [0, count) are live) |
| Ring | Head, Count | pushBack, popFront, pushFront, popBack | None (implicit: modular window) |
| Slab | Bit.Vector | insert(at:), remove(at:) | Binary bitmap (occupied/vacant) |

The new type:

| Discipline | State | Operations | Metadata |
|-----------|-------|-----------|----------|
| **Slots** | Capacity | read/write metadata, read/write payload | Parameterized: `M` per slot |

#### Option R1: Peer to Linear/Ring/Slab

A fourth discipline alongside the existing three. Same tier, same namespace pattern.

**Argument**: The new type has a distinct discipline (random-access with typed metadata) that doesn't reduce to any existing discipline. It shares the same storage substrate but adds a new axis of behavior.

#### Option R2: Generalization that Subsumes Slab

The new type with `M = Bool` (or `M = Bit`) would be equivalent to `Buffer.Slab`. Slab becomes syntactic sugar over the new type with bitmap metadata.

**Problem**: `Buffer.Slab` uses `Bit.Vector` for compact bitmap tracking. The new type stores `M` per slot — if `M = Bool`, that's 1 byte per slot, not 1 bit. To match Slab's space efficiency, the new type would need special-case bit-packing for boolean metadata, which undermines the generality.

**Problem**: Slab has init/deinit lifecycle tracking (it manages `~Copyable` element lifecycle via the bitmap). The new type explicitly avoids lifecycle tracking (R4). These are semantically different even if structurally similar.

#### Recommendation: R1 (Peer)

The new type is a **peer**, not a generalization:

1. **Different lifecycle semantics**: Slab tracks init/deinit; the new type does not (R4)
2. **Different metadata granularity**: Slab uses compact 1-bit-per-slot bitmap; the new type uses `M`-per-slot which is at least 1 byte for any non-bit type
3. **Different operations**: Slab has insert/remove (lifecycle-aware); the new type has read/write (overwrite-semantic)
4. **Slab remains independently justified**: Slab serves collections that need sparse element lifecycle tracking (e.g., sparse arrays, free lists). The new type serves index structures that need per-slot metadata without lifecycle tracking.

The relationship is:

```
Buffer disciplines:
├── Linear   — ordered, contiguous, append/consume
├── Ring     — ordered, circular, push/pop both ends
├── Slab     — unordered, sparse, init/deinit lifecycle
└── Slots    — unordered, dense, metadata-parametric, overwrite-semantic
```

### SQ6: SwissTable SIMD Compatibility

R6 requires SwissTable-compatible metadata. The key SIMD constraint:

**Swiss table scans 16 consecutive control bytes** as a 128-bit SIMD vector. The metadata array must be:
1. Contiguous (no gaps, no interleaving with payload)
2. Byte-addressable (`M` = `UInt8` for Swiss table)
3. 16-byte aligned (for optimal SIMD load)

The M2 (separate arrays) layout satisfies all three constraints when `M = UInt8`:
- Metadata array is contiguous at the start of the allocation
- Array stride is 1 byte (no padding)
- Alignment can be guaranteed by the allocator

**Group-of-16 requirement**: Swiss table probes in groups of 16. The metadata array should have capacity that is a multiple of 16, or the type should pad the metadata array to the next multiple of 16. This is a consumer-level concern (Swiss table enforces power-of-two capacity which is always a multiple of 16 for capacities ≥ 16).

**Sentinel byte at table end**: Swiss table places a sentinel control byte (`0xFF`) after the last group to terminate SIMD scanning. The buffer type should support over-allocating metadata by a small amount (e.g., 1 group = 16 bytes) to accommodate this. Alternatively, the consumer can request capacity + 16 and use the extra slots for sentinels.

**Recommendation**: The type's metadata array layout natively supports SIMD scanning when `M = UInt8`. No special SIMD API is needed at the buffer level — the consumer obtains a `UnsafePointer<M>` to the metadata array and performs SIMD operations directly. The buffer type's responsibility is to provide contiguous, properly-aligned metadata storage. SIMD intrinsics are the consumer's domain.

### SQ7: Naming

Per [API-NAME-001], the name must follow `Nest.Name` pattern. Per the locked constraints, it must communicate random-access slots, not contiguity, and must not encode hash-specific semantics.

#### Option N1: `Buffer.Slots`

```swift
extension Buffer {
    public enum Slots {}
}
// Full type: Buffer.Slots<M, P> or Buffer<P>.Slots<M>
```

**Pros**: Concise. Communicates fixed-capacity addressable positions. Distinct from Linear (sequential), Ring (circular), Slab (sparse lifecycle).
**Cons**: "Slots" alone doesn't communicate the metadata-parametric nature. Could be confused with a generic "array of slots" (which is what all buffers are).

#### Option N2: `Buffer.Labeled`

```swift
extension Buffer {
    public enum Labeled {}
}
// Full type: Buffer.Labeled<M, P>
```

**Pros**: Communicates that each slot carries a label (metadata). Evocative of "labeled array" from database/statistics terminology.
**Cons**: "Labeled" is uncommon in systems programming. Doesn't communicate random-access or fixed-capacity.

#### Option N3: `Buffer.Annotated`

```swift
extension Buffer {
    public enum Annotated {}
}
// Full type: Buffer.Annotated<M, P>
```

**Pros**: Communicates per-slot annotation.
**Cons**: Same weakness as N2. Also overloaded — Swift's `@Annotated` is an attribute pattern.

#### Option N4: `Buffer.Paired`

```swift
extension Buffer {
    public enum Paired {}
}
// Full type: Buffer.Paired<M, P>
```

**Pros**: Communicates the dual-array structure (metadata-payload pair per slot).
**Cons**: Could be read as "pair of buffers" rather than "buffer of pairs." Doesn't communicate the metadata-is-always-initialized semantics.

#### Option N5: `Buffer.Tagged`

```swift
extension Buffer {
    public enum Tagged {}
}
// Full type: Buffer.Tagged<M, P>
```

**Pros**: "Tagged" directly communicates per-slot tags (metadata). Evocative of "tagged union" — each slot is tagged with metadata that determines its interpretation. Established terminology in type theory.
**Cons**: Conflicts with `Tagged<Tag, RawValue>` from identity-primitives, which is the phantom-type wrapper. Using "Tagged" for a different concept in the same ecosystem could cause confusion.

#### Option N6: `Buffer.Tabular`

```swift
extension Buffer {
    public enum Tabular {}
}
// Full type: Buffer.Tabular<M, P>
```

**Pros**: Communicates a table-like structure with rows (slots) and columns (metadata, payload). Evocative of database tables.
**Cons**: Could be confused with `Hash.Table`. "Tabular" is not a standard term for this pattern.

#### Option N7: `Buffer.Catalog`

```swift
extension Buffer {
    public enum Catalog {}
}
// Full type: Buffer.Catalog<M, P>
```

**Pros**: Communicates an indexed collection of categorized entries.
**Cons**: Overloaded term. Not clearly a buffer discipline.

#### Option N8: `Buffer.Indexed`

```swift
extension Buffer {
    public enum Indexed {}
}
// Full type: Buffer.Indexed<Metadata, Payload>
```

**Pros**: Communicates random-access by index. Clean, systems-level term.
**Cons**: All buffers are indexed by position. Doesn't distinguish this from Linear or Slab. Also doesn't communicate the metadata-parametric aspect.

#### Recommendation: N1 — `Buffer.Slots`

`Buffer.Slots` is the strongest candidate:

1. **"Slots" communicates the correct semantics**: Fixed-capacity, random-access, individually-addressable positions. This is the systems-programming term for "pre-allocated positions in a table."
2. **Distinct from existing disciplines**: Linear = sequential, Ring = circular, Slab = sparse lifecycle. Slots = dense metadata-parametric.
3. **Not hash-specific**: "Slots" is general. Hash tables have slots, but so do adjacency matrices, sprite atlases, memory pools, and register files.
4. **Nest.Name compatible**: `Buffer.Slots` follows the pattern perfectly.
5. **Metadata communicated via generic parameter**: The metadata-parametric nature is communicated by the type parameter `M`, not the name. `Buffer.Slots<UInt8, Hash.Value>` clearly says "a slot buffer with byte metadata and Hash.Value payload."
6. **"Slots" vs "Slab"**: The distinction is clear — Slab tracks element lifecycle (sparse init/deinit), Slots provides metadata-annotated positions (dense, overwrite-semantic).

The full type name becomes:

```swift
Buffer.Slots<Metadata, Payload>
```

Where `Metadata` is the per-slot metadata type and `Payload` is the per-slot payload type.

---

## Proposed Type Design

### Type Hierarchy

Following the established three-layer pattern from the theoretical buffer-primitives design:

#### Layer 1: Header (Pure State)

```swift
extension Buffer {
    /// Namespace for the metadata-parametric random-access slots discipline.
    public enum Slots<Metadata: Copyable & Sendable, Payload: ~Copyable> {}
}

extension Buffer.Slots {
    /// The cursor state for a slots buffer.
    ///
    /// Always Copyable and Sendable — contains only the capacity.
    /// Unlike Linear (count) or Ring (head + count), Slots has no
    /// mutable cursor state — all state is in the metadata array.
    public struct Header: Copyable, Sendable, Hashable {
        /// Total slot capacity.
        public let capacity: Index<Payload>.Count

        public init(capacity: Index<Payload>.Count)
    }
}
```

**Note**: The Header is trivial — just capacity. Unlike Linear/Ring/Slab, the Slots discipline has no mutable cursor state. The metadata array IS the state, and it lives in storage, not the header. This is a key distinction.

**Note on `Metadata` constraint**: `Metadata` is required to be `Copyable & Sendable` because:
1. Metadata is always initialized at buffer creation (bulk fill)
2. Metadata is read and written by value (not moved)
3. Metadata must be safe to read from multiple threads (for concurrent hash tables)
4. `UInt8`, `Int`, `Bool` all satisfy this trivially
5. `~Copyable` metadata would require init/deinit lifecycle for the metadata lane itself, adding complexity with no known use case

#### Layer 2: Static Operations (Namespace Methods)

Static operations delegate to `Storage<Payload>.Split<Metadata>` APIs:

```swift
extension Buffer.Slots {
    // === Creation ===

    /// Creates storage with all metadata slots initialized to the given sentinel.
    /// Payload slots are uninitialized.
    @inlinable
    public static func create(
        capacity: Index<Payload>.Count,
        metadataInitial: Metadata
    ) -> Storage<Payload>.Split<Metadata> {
        Storage<Payload>.Split<Metadata>.create(
            capacity: capacity,
            laneInitial: metadataInitial
        )
    }

    // === Metadata Access (delegates to storage.lane) ===

    /// Reads the metadata at the given slot.
    @inlinable
    public static func readMetadata(
        at slot: Index<Payload>,
        storage: Storage<Payload>.Split<Metadata>
    ) -> Metadata {
        storage.lane[at: slot]
    }

    /// Writes metadata at the given slot.
    @inlinable
    public static func writeMetadata(
        _ value: Metadata,
        at slot: Index<Payload>,
        storage: Storage<Payload>.Split<Metadata>
    ) {
        storage.lane[at: slot] = value
    }

    /// Calls body with a pointer to the contiguous metadata lane.
    /// The caller may use this for SIMD operations.
    @inlinable
    public static func withMetadataPointer<R>(
        storage: Storage<Payload>.Split<Metadata>,
        _ body: (UnsafePointer<Metadata>) -> R
    ) -> R {
        storage.lane.withPointer(body)
    }

    // === Payload Access (delegates to storage.pointer(at:)) ===

    /// Initializes the payload at the given slot.
    /// Precondition: The slot's payload must be uninitialized.
    @inlinable
    public static func initializePayload(
        to value: consuming Payload,
        at slot: Index<Payload>,
        storage: Storage<Payload>.Split<Metadata>
    ) {
        unsafe storage.pointer(at: slot).initialize(to: value)
    }

    /// Moves (deinitializes and returns) the payload at the given slot.
    /// Precondition: The slot's payload must be initialized.
    @inlinable
    public static func movePayload(
        at slot: Index<Payload>,
        storage: Storage<Payload>.Split<Metadata>
    ) -> Payload {
        unsafe storage.pointer(at: slot).move()
    }

    /// Reads the payload at the given slot (borrowing).
    /// Precondition: The slot's payload must be initialized.
    @inlinable
    public static func readPayload(
        at slot: Index<Payload>,
        storage: Storage<Payload>.Split<Metadata>
    ) -> Payload where Payload: Copyable {
        unsafe storage.pointer(at: slot).pointee
    }

    /// Writes the payload at the given slot (overwrite, no deinit of old value).
    /// Precondition: The slot's payload must be initialized.
    @inlinable
    public static func writePayload(
        _ value: consuming Payload,
        at slot: Index<Payload>,
        storage: Storage<Payload>.Split<Metadata>
    ) where Payload: Copyable {
        unsafe storage.pointer(at: slot).pointee = value
    }

    // === Bulk Operations ===

    /// Fills all metadata slots with the given value.
    @inlinable
    public static func fillMetadata(
        _ value: Metadata,
        storage: Storage<Payload>.Split<Metadata>
    ) {
        storage.lane.fill(with: value)
    }

    /// Deinitializes all payload slots for which the predicate returns true.
    /// Used during cleanup when the consumer knows which metadata values
    /// indicate initialized payload.
    @inlinable
    public static func deinitializePayloads(
        where predicate: (Metadata) -> Bool,
        header: Header,
        storage: Storage<Payload>.Split<Metadata>
    )
}
```

#### Layer 3: Composed Type (Ergonomic Wrapper)

```swift
extension Buffer.Slots {
    /// A fixed-capacity slots buffer backed by `Storage<Payload>.Split<Metadata>`.
    ///
    /// Provides metadata-parametric random-access slots with a single
    /// heap allocation containing both metadata and payload arrays.
    ///
    /// - `Metadata` is always initialized (to a caller-supplied sentinel)
    /// - `Payload` initialization is managed by the consumer via metadata
    /// - No buffer-level growth — the consumer is responsible for rebuilding
    public struct Fixed: ~Copyable {
        public var header: Header
        public var storage: Storage<Payload>.Split<Metadata>

        /// Creates a fixed-capacity slots buffer.
        ///
        /// All metadata slots are initialized to `metadataInitial`.
        /// Payload slots are uninitialized.
        public init(
            capacity: Index<Payload>.Count,
            metadataInitial: Metadata
        ) {
            self.header = Header(capacity: capacity)
            self.storage = Storage<Payload>.Split<Metadata>.create(
                capacity: capacity,
                laneInitial: metadataInitial
            )
        }

        // Metadata access — delegates to Storage.Split lane accessor:
        public func metadata(at slot: Index<Payload>) -> Metadata {
            storage.lane[at: slot]
        }
        public func setMetadata(_ value: Metadata, at slot: Index<Payload>) {
            storage.lane[at: slot] = value
        }

        // Payload access — delegates to Storage.Split primary pointer:
        public func initializePayload(to value: consuming Payload, at slot: Index<Payload>) {
            unsafe storage.pointer(at: slot).initialize(to: value)
        }
        public func movePayload(at slot: Index<Payload>) -> Payload {
            unsafe storage.pointer(at: slot).move()
        }

        // Copyable payload convenience
        public func payload(at slot: Index<Payload>) -> Payload where Payload: Copyable {
            unsafe storage.pointer(at: slot).pointee
        }
        public func setPayload(_ value: consuming Payload, at slot: Index<Payload>) where Payload: Copyable {
            unsafe storage.pointer(at: slot).pointee = value
        }

        // SIMD access — delegates to Storage.Split lane withPointer:
        public func withMetadataPointer<R>(_ body: (UnsafePointer<Metadata>) -> R) -> R {
            storage.lane.withPointer(body)
        }

        // Bulk — delegates to Storage.Split lane fill:
        public func fillMetadata(_ value: Metadata) {
            storage.lane.fill(with: value)
        }

        /// Deinitializes payload slots where metadata indicates occupancy.
        /// Must be called before deallocation if payloads need deinit.
        public func deinitializePayloads(where predicate: (Metadata) -> Bool) {
            // Iterate all slots, check metadata, deinitialize matching payloads
            // Implementation uses storage.lane[at:] and storage.pointer(at:)
        }

        public var capacity: Index<Payload>.Count { header.capacity }

        deinit {
            // Storage.Split.deinit handles metadata lane cleanup
            // Payload: consumer MUST call deinitializePayloads before dropping
            // For BitwiseCopyable payloads, no deinit needed
        }
    }
}

extension Buffer.Slots.Fixed: Copyable where Payload: Copyable {}
extension Buffer.Slots.Fixed: Sendable where Payload: Sendable {}
```

### Storage Substrate

`Buffer.Slots` delegates all storage management to `Storage<Payload>.Split<Metadata>` from storage-primitives:

```swift
extension Buffer.Slots {
    /// The storage substrate.
    ///
    /// `Storage<Payload>.Split<Metadata>` provides:
    /// - Single `ManagedBuffer<Header, UInt8>` allocation
    /// - Layout: `[Metadata_0..Metadata_{n-1}][padding][Payload_0..Payload_{n-1}]`
    /// - Primary access: `pointer(at: Index<Payload>)` → `UnsafeMutablePointer<Payload>`
    /// - Lane access: `lane[at:]`, `lane.pointer(at:)`, `lane.fill(with:)`
    /// - Shared `Index<Payload>` domain across both lanes
    /// - No initialization tracking (consumer-managed via metadata interpretation)
    public typealias BackingStorage = Storage<Payload>.Split<Metadata>
}
```

No custom ManagedBuffer subclass is needed. The buffer discipline layer (Buffer.Slots) composes the storage primitive (`Storage.Split`), exactly as Buffer.Linear composes `Storage.Heap`.

### Usage Example: Hash.Table Migration

```swift
// Current Hash.Table (ad-hoc dual arrays — bypasses Storage tier):
package final class Storage: ManagedBuffer<Header, Int> {
    var hashesPointer: UnsafeMutablePointer<Int> { ... }
    var positionsPointer: UnsafeMutablePointer<Int> { ... }
}

// Future Hash.Table (using Buffer.Slots → Storage.Split):
// After Workstream 1 (Hash.Value) and Workstream 3 (this):
var slots: Buffer.Slots<Hash.Value, Index<Element>>.Fixed
// Metadata = Hash.Value (encodes hash + bucket state) → Storage.Split lane
// Payload = Index<Element> (typed position) → Storage.Split primary element

// Read hash at bucket — delegates to storage.lane[at:]:
let hash = slots.metadata(at: bucket)

// Write position at bucket — delegates to storage.pointer(at:).pointee:
slots.setPayload(position, at: bucket)

// Probe sequence (no sentinel collision normalization needed):
let h = Hash.Value(element.hashValue)
var bucket = h.bucket(capacity: slots.capacity)
while true {
    let meta = slots.metadata(at: bucket)
    if meta.isEmpty { break }
    if meta.hash == h, slots.payload(at: bucket) == position { return bucket }
    bucket = bucket.next(capacity: slots.capacity)
}
```

### Usage Example: Swiss Table

```swift
// Swiss table uses UInt8 metadata (control bytes)
// Buffer.Slots<UInt8, (Key, Value)>.Fixed → backed by Storage<(Key, Value)>.Split<UInt8>
var table: Buffer.Slots<UInt8, (Key, Value)>.Fixed

// SIMD probing — delegates to storage.lane.withPointer:
table.withMetadataPointer { ctrl in
    // Load 16 control bytes as SIMD vector (contiguous in Storage.Split lane region)
    let group = SIMD16<UInt8>(unsafePointer: ctrl + groupStart)
    // Compare against target h2
    let matches = group .== h2Byte
    // Scan matches with trailing-zeros enumeration
    var mask = matches.bitmask
    while mask != 0 {
        let i = mask.trailingZeroBitCount
        let slot = groupStart + i
        // Check payload at slot — delegates to storage.pointer(at:)
        if table.payload(at: Index(slot)).key == key { return slot }
        mask &= mask - 1
    }
}
```

---

## Comparison with Alternatives

| Criterion | Buffer.Slots\<M,P\> via Storage.Split | Two Storage\<T\>.Heap | Buffer.Slab + Manual | Ad-hoc ManagedBuffer (bypass) |
|-----------|---------------------------------------|---------------------|--------------------|-----------------------------|
| Layering preserved | **Yes** (Buffer → Storage → Pointer) | Yes | Yes | **No** |
| Single allocation | Yes | No (two ARC refs) | No (bitmap + storage) | Yes |
| Typed metadata access | Yes (`lane[at:]`) | Yes (separate) | No (bitmap only) | Manual |
| Typed payload access | Yes (`pointer(at:)`) | Yes | Yes | Manual |
| SIMD-friendly metadata | Yes (contiguous lane) | Yes (contiguous) | No (bit-packed) | Depends on layout |
| Metadata parameterization | Generic \<M\> | Concrete type | Fixed: 1 bit/slot | Concrete type |
| Lifecycle tracking | None (consumer-managed) | Per-storage | Bitmap-driven | None |
| `~Copyable` payload | Yes | Yes | Yes | Depends |
| Growth | None (fixed-capacity) | Per-storage | Optional | Ad-hoc |
| SwissTable compatible | Yes | Yes (but two allocs) | No (bit metadata) | Yes (ad-hoc) |
| Code reuse | General abstraction | None (per-consumer) | Partial | None |

---

## Empirical Validation (Cognitive Dimensions)

Per [RES-025], evaluating API usability via Cognitive Dimensions:

| Dimension | Assessment | Rationale |
|-----------|------------|-----------|
| **Visibility** | HIGH | `Buffer.Slots<UInt8, Hash.Value>` immediately communicates: slots with byte metadata and typed payload. The dual generic parameters make the structure visible. |
| **Consistency** | HIGH | Follows the same three-layer pattern as Linear/Ring/Slab (Header + static ops + composed type). Naming parallel: `Buffer.Linear`, `Buffer.Ring`, `Buffer.Slab`, `Buffer.Slots`. |
| **Viscosity** | LOW | Adding a new consumer (e.g., Robin Hood hash table) requires only choosing `M` and `P` — no changes to the buffer type. |
| **Role-expressiveness** | HIGH | `Buffer.Slots<UInt8, Index<Element>>.Fixed` clearly says "fixed-capacity slots with byte metadata and element-index payload." The composed type name `Fixed` communicates no-growth semantics. |
| **Error-proneness** | MEDIUM | Consumer must correctly manage payload lifecycle via metadata. Forgetting to call `deinitializePayloads` before dropping a buffer with `~Copyable` payloads would leak. For `Copyable` / `BitwiseCopyable` payloads, this is not a concern. |
| **Abstraction** | APPROPRIATE | The type provides the minimum abstraction: dual-array layout in a single allocation, typed access, metadata-first initialization. It does NOT provide: SIMD operations, hash-specific probing, growth policy. These are consumer responsibilities. |

---

## Dependency Analysis

### Required Dependencies

```
Buffer.Slots (Tier 13, buffer-primitives)
  ├── swift-storage-primitives (Tier 12) — Storage<Payload>.Split<Metadata>
  ├── swift-index-primitives (Tier 6) — Index<Payload>, Index<Payload>.Count
  └── swift-cardinal-primitives (via index-primitives) — Cardinal for capacity
```

### NOT Required

- `swift-bit-vector-primitives`: Not needed — Slots uses `M`-per-slot metadata, not bitmaps
- `swift-memory-primitives`: Not needed — alignment computation is internal to `Storage.Split`
- `swift-cyclic-index-primitives`: Not needed — cyclic probing is the consumer's responsibility
- `swift-sequence-primitives`: Not needed — Slots provides random access, not iteration protocols

**Note on Storage.Split vs Storage.Heap**: `Buffer.Slots` consumes `Storage<Payload>.Split<Metadata>`, not `Storage<Payload>.Heap`, because:
1. `Storage.Heap` is single-typed. Slots needs dual-typed storage (Metadata + Payload in one allocation).
2. `Storage.Heap` tracks initialization via `Storage.Initialization`. Slots does not track payload initialization (R4).
3. `Storage.Split` provides the exact layout needed: `[Lane...][padding][Element...]` with typed access to both regions.

This parallels how different buffer disciplines consume different Storage types: Linear/Ring → `Storage.Heap`, Slab → `Storage.Heap` + `Bit.Vector`, Slots → `Storage.Split`.

---

## Module Organization

Following [API-IMPL-005] one type per file:

```
swift-buffer-primitives/Sources/
  Buffer Slots Primitives/
    Buffer.Slots.swift                        → enum Buffer.Slots<Metadata, Payload>
    Buffer.Slots.Header.swift                 → struct Buffer.Slots.Header
    Buffer.Slots.Fixed.swift                  → struct Buffer.Slots.Fixed (backed by Storage.Split)
    Buffer.Slots ~Copyable.swift              → static operations for ~Copyable Payload
    Buffer.Slots Copyable.swift               → static operations for Copyable Payload
```

Note: No `Buffer.Slots.Storage.swift` — storage is provided by `Storage<Payload>.Split<Metadata>` from `swift-storage-primitives`. The module imports `Storage_Primitives_Core`.

---

## Open Questions

| # | Question | Status | Resolution (realized 2026-06-03) |
|---|----------|--------|----------------------------------|
| OQ-1 | Should the buffer auto-deinitialize payloads in `deinit` if the element is `BitwiseCopyable`? | **RESOLVED — no auto-deinit (C2 confirmed)** | `Buffer.Slots` has **no element `deinit`**. The consumer deinitializes occupied slots via the predicate `deinitialize(where:)` (instance) / `deinitializeAll(where:header:storage:)` (static), supplying an `isOccupied: (Metadata) -> Bool`. For `BitwiseCopyable` elements deinit is a no-op anyway. Documented in source as the "capability boundary — the same contract as `Storage.Split`." |
| OQ-2 | A `Buffer.Slots.Static<…, let capacity:>` inline variant? | **RESOLVED — not built; `InlineArray` direct** | No inline `Buffer.Slots` variant shipped. `Hash.Table.Static` uses `InlineArray<bucketCapacity, Int>` directly (see `hash-table-storage-buffer-layering.md` § "What about the Static variant?"). An inline `Buffer.Slots` remains a possible future addition with no current consumer — deferred, not rejected. |
| OQ-3 | Constrain metadata to `BitwiseCopyable`? | **RESOLVED — YES** | The shipped type is `Buffer<Element>.Slots<Metadata: BitwiseCopyable>`. The `BitwiseCopyable` bound (stricter than the proposed `Copyable & Sendable`) is what makes the metadata lane bulk-fillable, bulk-copyable (CoW fast path), and SIMD-scannable. |
| OQ-4 | `count` / `occupancy` on the buffer? | **RESOLVED — consumer concern, not on the buffer** | `Buffer.Slots` exposes only `capacity`. Occupancy scanning lives in the consumer: `Hash.Table+occupied.swift` reads the metadata lane via `metadataPointer`; `deinitializeAll(where:)` and `ensureUnique(where:)` take an `isOccupied:` predicate. No `count` property on the buffer. |

---

## Outcome

**Status**: DECISION (realized 2026-06-03)

> **v2.0.0 — Realized design.** `Buffer.Slots` shipped in `swift-buffer-slots-primitives` and `Hash.Table` consumes it. The realized shape refines the preliminary recommendations below in three ways:
>
> 1. **Generic shape.** Realized as **`Buffer<Element>.Slots<Metadata: BitwiseCopyable>`** — the payload is the enclosing `Buffer<Element>`'s element; `Metadata` is the `Slots` parameter. There is **no `.Fixed` nested type**: `Buffer.Slots` *is* the fixed-capacity buffer (`~Copyable`; `Copyable where Element: Copyable`; `@unsafe @unchecked Sendable where Element: Sendable`). (The preliminary write-up proposed `Buffer.Slots<Metadata, Payload>.Fixed`.)
> 2. **Metadata bound** is `BitwiseCopyable` (OQ-3) — stricter than the proposed `Copyable & Sendable`; it is what enables bulk metadata fill/copy.
> 3. **Substrate API.** `Storage<Element>.Split<Lane>` exposes a typed **field-handle** API rather than a `.lane` accessor: `storage.field` → `(lane: Storage.Field<Lane>, element: Storage.Field<Element>)`, with `storage.pointer(field, at:)`, `storage[field, at:]`, `storage.fill(field, with:)`, `storage.withPointer(field) { … }`, and `initialize/move/deinitialize(field, … at:)`. `Storage.Split` tracks **no** lifecycle ([DS-005]).
>
> The **buffer-level discipline lives on `Buffer.Slots`**, not on `Storage.Split`: copy-on-write (`ensureUnique()` bulk for `BitwiseCopyable`; `ensureUnique(where:)` predicate for `Copyable`) and the predicate `deinitialize(where:)`. This is the load-bearing layer boundary the 2026-06 GAP-O fold violated (it moved CoW + predicate-deinit *into* `Storage.Split`) and that the 2026-06-03 reversal restored. See `hash-table-storage-buffer-layering.md` v3.0.0 § GAP-O Fold and Reversal.
>
> **Still open (Class-(c), separate):** the Memory/Storage/Buffer **boundary-definition** consolidation — whether `Storage.Split` should slim to a Memory-tier SoA region with `Buffer.Slots` carrying the full discipline. That question may refine how the substrate (point 3) is layered/named; it does **not** change the realized `Hash.Table → Buffer.Slots → Storage.Split` composition. Tracked for principal `/goal` dispatch.

### Preliminary Recommendations

1. **Type name**: `Buffer.Slots<Metadata, Payload>` — communicates random-access, metadata-parametric, Nest.Name compliant
2. **Storage substrate**: `Storage<Payload>.Split<Metadata>` — preserves canonical `ADT → Buffer → Storage → Pointer` layering (M2 + A3)
3. **Initialization**: Metadata always initialized at creation; payload uninitialized (I2), with trivial-type convenience (I3)
4. **Lifecycle**: Consumer-managed (C2); buffer provides raw operations, no tracking
5. **Relationship**: Peer to Linear/Ring/Slab (R1), not a generalization
6. **SIMD**: `Storage.Split` lane layout natively supports contiguous metadata scanning; SIMD operations are consumer's responsibility
7. **Naming**: `Buffer.Slots` with composed type `Buffer.Slots.Fixed` for the heap-backed fixed-capacity variant
8. **Layering**: `Hash.Table → Buffer.Slots → Storage.Split → ManagedBuffer` — no bypass

### Next Steps

1. Resolve open questions OQ-1 through OQ-4
2. Implement `Storage<Element>.Split<Lane>` in storage-primitives (per `split-storage-design.md`)
3. Verify `Index<Payload>` coordinate system works for both `pointer(at:)` and `lane[at:]` access
4. Design the `Hash.Value` newtype (Workstream 1) to validate the full integration path
5. Implement `Buffer.Slots.Fixed` as a proof-of-concept consuming `Storage.Split`

### Verification Plan

- **Experiment**: Implement `Storage<Int>.Split<UInt8>`, verify dual-typed pointer access compiles and aligns correctly (storage-primitives)
- **Experiment**: Implement `Buffer.Slots<UInt8, Int>.Fixed` consuming `Storage.Split`, verify SIMD-compatible lane pointer
- **Experiment**: Instantiate `Buffer.Slots<Int, Index<Element>>.Fixed` mimicking Hash.Table.Storage, verify typed access patterns
- **Audit**: Verify all Index/Cardinal/Ordinal usage follows dependency-reuse-audit constraints
- **Audit**: Verify `Storage.Split.pointer(at:)` uses the same `Index<Element>.Offset` pattern as `Storage.Heap.pointer(at:)`

---

## References

### Production Implementations
- abseil `flat_hash_map` (Google) — Swiss-table with SIMD-probed control bytes: https://abseil.io/about/design/swisstables
- abseil `raw_hash_set.h` — canonical Swiss table implementation: https://github.com/abseil/abseil-cpp/blob/master/absl/container/internal/raw_hash_set.h
- Rust `hashbrown` — Rust's `HashMap` backed by Swiss table: https://github.com/rust-lang/hashbrown
- Faultlore "Swisstable, a Quick and Dirty Description" — excellent hashbrown explainer: https://faultlore.com/blah/hashbrown-tldr/
- Go 1.24 `map` — Swiss-table adoption in Go runtime: https://go.dev/blog/swisstable
- CPython `dictobject.c` — Compact dict with split index/entry arrays: https://github.com/python/cpython/blob/main/Objects/dictobject.c
- Google `sparse_hash_map` — Bitmap-tracked sparse groups: https://github.com/sparsehash/sparsehash
- Smerity, "How Google Sparsehash Achieves Two Bits of Overhead": https://smerity.com/articles/2015/google_sparsehash.html

### Academic
- Celis, P. (1986). "Robin Hood Hashing." University of Waterloo PhD thesis.
- Herlihy, M., Shavit, N. & Tzafrir, M. (2008). "Hopscotch Hashing." *DISC 2008*.
- Richter, S., Alvarez, V. & Dittrich, J. (2015). "A Seven-Dimensional Analysis of Hashing Methods." *PVLDB*.

### Robin Hood Hashing
- Goossaert, E. (2013). "Robin Hood Hashing." Code Capsule: https://codecapsule.com/2013/11/11/robin-hood-hashing/
- Goossaert, E. (2013). "Robin Hood Hashing — Backward Shift Deletion." Code Capsule: https://codecapsule.com/2013/11/17/robin-hood-hashing-backward-shift-deletion/
- Sylvan, S. (2013). "Robin Hood Hashing Should Be Your Default." https://www.sebastiansylvan.com/post/robin-hood-hashing-should-be-your-default-hash-table-implementation/

### Swift Institute Internal
- `hash-table-storage-buffer-layering.md` (v2.0.0) — upstream research, semantic violations, principled redesign
- `theoretical-buffer-primitives-design.md` (v1.0.0) — three-discipline design
- `dependency-reuse-audit.md` (v1.0.0) — dependency reuse constraints
- `storage-primitives-comparative-analysis.md` (v1.1.0) — storage tier evaluation framework
- `split-storage-design.md` (v1.0.0) — `Storage<Element>.Split<Lane>` substrate design (storage-primitives)

### Collaborative Discussion
- Transcript: `/tmp/hash-table-storage-layering-transcript.md`
- Converged plan: `/tmp/hash-table-storage-layering-converged.md`

### Deferral

**Date**: 2026-03-15

**Reason**: The document produced preliminary recommendations for `Buffer.Slots<Metadata, Payload>` backed by `Storage<Payload>.Split<Metadata>`, but 4 open questions (OQ-1 through OQ-4) remain unresolved. The next steps require implementing `Storage<Element>.Split<Lane>` in storage-primitives first (per split-storage-design.md), which has not been done. The buffer-primitives inline module split in February restructured existing modules but did not add the Slots discipline. The upstream dependency (Storage.Split) must exist before this design can be validated.

**Resume when**: `Storage<Element>.Split<Lane>` is implemented in storage-primitives, or when hash-table-primitives is actively being refactored to use the canonical `ADT -> Buffer -> Storage` layering.

### Resumption

**Date**: 2026-06-03

**Trigger**: Both resume-conditions are met — `Storage<Element>.Split<Lane>` is implemented (`swift-storage-split-primitives`) and `Hash.Table` is realized on the canonical layering (`_buffer: Buffer<Int>.Slots<Int>`). The 2026-06 GAP-O fold briefly bypassed this layering; its reversal (2026-06-03) is the proximate trigger to firm up this design doc.

**Disposition**: Status DEFERRED → DECISION. OQ-1–OQ-4 resolved against the shipped types (see § Open Questions and § Outcome). The buffer↔storage layer boundary is preserved as designed; the residual Memory/Storage/Buffer boundary-definition question is carried forward as a separate Class-(c) item, not a blocker on this document.
