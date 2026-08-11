# Hash Table Discipline Boundary Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute primitives architecture establishes a strict four-layer dependency chain:

```
Memory (Tier 13) -> Storage (Tier 14) -> Buffer (Tier 15) -> Data Structure (Tier 16+)
```

`hash-table-primitives` sits at the data-structure layer, wrapping `Buffer.Slots` (heap variant) and `InlineArray` (static variant) to present a consumer-facing hash table abstraction. The question: does `hash-table-primitives` contain ONLY hash-table-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-hash-table-primitives).

**Note**: This analysis complements the existing `hash-table-storage-buffer-layering.md` research document, which examined whether `Hash.Table`'s internal storage should be replaced with a buffer from buffer-primitives. That document addresses the *downward* dependency question (what does Hash.Table consume?). This document addresses the *upward* discipline question (does Hash.Table expose only hash-table semantics?).

## Question

What semantics belong SOLELY to the hash table abstraction layer, and does `hash-table-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Formal ADT Axioms (Liskov & Guttag; Software Foundations)

The hash table implements the **associative array** (dictionary / map) abstract data type. The formal equational specification from [Software Foundations](https://softwarefoundations.cis.upenn.edu/vfa-current/ADT.html):

```
Operations: empty, set(t, k, v), get(t, k), delete(t, k)

Axioms:
  get(k, empty)           = default           (empty lookup)
  get(k, set(k, v, t))    = v                 (read-after-write)
  get(k', set(k, v, t))   = get(k', t)  k!=k' (non-interference)
  get(k, delete(k, t))    = default           (read-after-delete)
  get(k', delete(k, t))   = get(k', t)  k!=k' (delete non-interference)
```

The ADT mentions NO implementation concerns: no buckets, no hash functions, no probing, no load factors, no capacity. The hash table is a *particular implementation* of this ADT that adds the **hash function contract** as its defining characteristic: it uses a hash function to achieve O(1) average-case lookup.

**Key distinction**: The *associative array ADT* defines what operations exist and how they compose. The *hash table* adds the hash function as the mechanism for efficient implementation. Both are above the buffer layer. The hash table SOLELY owns the hash function contract, key uniqueness invariant, and collision resolution policy.

### Source 2: Rust hashbrown Architecture (RawTable vs HashMap)

Rust's [hashbrown](https://github.com/rust-lang/hashbrown) provides the clearest modern architectural separation, as documented by [DeepWiki](https://deepwiki.com/rust-lang/hashbrown/2-core-architecture):

**RawTable (Buffer Layer)**:
- Memory allocation and layout (contiguous control bytes + data)
- Bucket management via `Bucket<T>` abstraction
- Control byte system (EMPTY, DELETED, FULL -- 1 byte per entry)
- Probing mechanics (triangular probing, SIMD parallel lookup)
- Raw slot read/write with no knowledge of key/value semantics
- Generic over element type `T` -- completely agnostic about whether `T` is a key-value pair

**HashMap (Data Structure Layer)**:
- Hash computation via configurable `BuildHasher`
- Key-based lookup semantics (the `K` in `(K, V)`)
- Key uniqueness invariant enforcement
- Safe insertion/removal APIs with automatic hashing
- Type-safe iteration over key-value pairs
- `Entry` API for conditional insert/update
- `Eq` + `Hash` trait requirements on keys

**HashTable (Intermediate)**:
- Wraps `RawTable` but requires callers to provide explicit hash values
- Useful when hashing is expensive or types are not `Hash`-conforming
- Still owns lookup/insert/remove semantics, just delegates hashing to caller

**Key parallel**: Our `Hash.Table<Element>` corresponds to hashbrown's `HashTable<T>` -- it accepts explicit hash values and delegates element comparison to the caller via closures. The hash function contract is pushed to the consumer (e.g., `Set.Ordered`), while the probing discipline, bucket state management, and sentinel protocol are internal.

### Source 3: C++ STL `unordered_map` / `unordered_set`

The [C++ standard](https://en.cppreference.com/w/cpp/container/unordered_map.html) exposes bucket-level details as part of the public interface, which is instructive as a *negative example* of layering:

**What C++ puts in the data structure (correctly)**:
- `Hash` and `KeyEqual` template parameters (hash function contract)
- Key uniqueness guarantee (insert returns iterator + bool)
- `find(key)`, `count(key)`, `contains(key)` -- key-based lookup
- Iterator invalidation rules as semantic contract
- `Allocator` parameterization

**What C++ leaks from the buffer layer (incorrectly by our standards)**:
- `bucket_count()`, `bucket_size(n)`, `bucket(key)` -- raw bucket access
- `load_factor()`, `max_load_factor()` -- internal load tracking exposed
- `rehash(n)`, `reserve(n)` -- explicit growth control
- `begin(n)`, `end(n)` -- per-bucket iterators

In our architecture, load factor monitoring, bucket sizing, and rehashing are buffer-level concerns. The C++ interface leaks these to users, coupling consumer code to the probing strategy. Our design should NOT follow this pattern.

### Source 4: Swiss Tables and Robin Hood Hashing

[Swiss tables](https://faultlore.com/blah/hashbrown-tldr/) (Google abseil, Rust hashbrown) and [Robin Hood hashing](https://www.sebastiansylvan.com/post/robin-hood-hashing-should-be-your-default-hash-table-implementation/) are **buffer-level optimizations** that do not change the hash table's ADT semantics:

| Technique | Layer | What it changes |
|-----------|-------|----------------|
| Linear probing | Buffer | Probe sequence: `bucket = (bucket + 1) % capacity` |
| Quadratic probing | Buffer | Probe sequence: `bucket = (bucket + i^2) % capacity` |
| Robin Hood | Buffer | Probe sequence + swap policy (minimize PSL variance) |
| Swiss table (SIMD) | Buffer | Parallel metadata scanning via SIMD control bytes |
| Separate chaining | Buffer | Linked-list per bucket instead of open addressing |

**None of these change**: The insert/lookup/delete axioms, the key uniqueness invariant, the hash function contract, or the collision resolution *policy* (which bucket to choose). They change the collision resolution *mechanism* (how to find that bucket efficiently).

The hash table SOLELY owns the policy: "given a hash collision, we must probe until we find a match or an empty slot." The buffer owns the mechanism: "probing uses linear/quadratic/SIMD scanning."

### Source 5: Load Factor and Rehashing -- Whose Concern?

[Traditional analysis](https://www.geeksforgeeks.org/dsa/load-factor-and-rehashing/) places load factor monitoring and rehashing inside the hash table. However, in a layered architecture, this splits:

| Concern | Layer | Rationale |
|---------|-------|-----------|
| Load factor threshold policy | Hash table | "When should we grow?" is a semantic decision affecting amortized complexity guarantees |
| Growth execution (allocate, copy, rehash) | Buffer/Hash table shared | The hash table must rehash (recompute bucket assignments); the buffer must allocate new storage |
| Capacity tracking | Buffer | Physical slot count is a buffer concern |
| Occupancy tracking | Hash table | Logical count of active + tombstone entries is a hash-table-discipline concern |

**Critical insight**: Hash table growth is fundamentally different from buffer growth. Buffer growth preserves existing element positions (append, memcpy). Hash table growth requires **complete rehashing** -- every entry is re-probed into the new table. This means `grow()` is a hash-table operation that *uses* buffer allocation, not a buffer operation.

---

## Analysis

### What is SOLELY Hash Table Discipline

#### A. Hash Function Contract

The hash table's primary contribution: it uses a hash function to map keys to bucket positions, achieving O(1) average-case access.

| Contract | Explanation |
|----------|-------------|
| **Hash normalization** | `normalize(_:)` ensures hash values avoid sentinel collisions. This is hash-table-specific because sentinels are a hash-table probing concern |
| **Hash-to-bucket mapping** | `bucket(for:)` / `bucket.for(hash:)` maps a hash value to an initial bucket index. This is the defining operation of a hash table |
| **Hash value storage** | Storing the hash alongside the position enables O(1) rehashing and fast hash-comparison before element comparison |
| **Hash-based lookup** | `position(forHash:equals:)` -- find by hash first, then verify by equality. The two-phase protocol (hash filter, then equality check) is the hash table's defining access pattern |

#### B. Key Uniqueness Invariant

| Contract | Explanation |
|----------|-------------|
| **Duplicate detection on insert** | `insert(position:hashValue:equals:)` returns `false` if a duplicate exists. The hash table enforces at-most-one-entry-per-key |
| **Unchecked insert bypass** | `insert(__unchecked:position:hashValue:)` skips duplicate detection when the caller guarantees uniqueness. The escape hatch exists precisely because uniqueness is normally enforced |
| **Contains check** | `contains(hashValue:equals:)` (Static variant) -- membership test is a hash-table semantic |

#### C. Collision Resolution Policy

| Contract | Explanation |
|----------|-------------|
| **Linear probing** | The policy "advance to the next bucket on collision" is owned by the hash table. The buffer provides the cyclic arithmetic |
| **Probe termination** | "Stop when empty bucket found or all buckets probed" -- this termination condition is hash-table logic |
| **Tombstone handling** | The three-state protocol (empty/occupied/deleted) and the rule "skip deleted during lookup, reuse deleted during insert" is hash-table discipline |
| **Tombstone-aware insertion** | Tracking `firstDeleted` during probe and preferring it over empty slots is a hash-table optimization policy |

#### D. Position Mapping (Index Structure Semantics)

`Hash.Table` is an **index structure**: it maps hash values to typed positions in external storage. This is a semantic contract above the buffer layer.

| Contract | Explanation |
|----------|-------------|
| **Typed position storage** | `Index<Element>` and `Index<Element>.Bounded<N>` positions are phantom-typed to prevent index confusion between different collections |
| **Position update after removal** | `positions.decrement(after:)` maintains position coherence when external storage compacts. This is index-structure discipline |
| **Position update by hash** | `positions.update(forHash:equals:newPosition:)` re-targets a hash entry to a new external position. This is index maintenance |
| **Phantom-typed bucket indices** | `Hash.Table.Bucket` as a phantom type, `BucketIndex = Index<Bucket>` -- prevents mixing bucket indices with element positions |

#### E. Load Factor and Growth Policy

| Contract | Explanation |
|----------|-------------|
| **70% load factor threshold** | `shouldGrow` triggers at 70% occupancy. This is a hash-table-level policy decision |
| **Occupancy tracking** | `_occupied` counts active + tombstone entries separately from `_count` (active only). This dual-count is hash-table discipline |
| **Rehash on grow** | `grow()` allocates a new buffer and re-probes every entry. This is hash-table discipline because buffer growth (memcpy) does not work for hash tables |
| **Rehash on demand** | `rehash()` (Static variant) compacts tombstones. This is hash-table maintenance |
| **Full-table detection** | `isFull` prevents insertion when occupancy equals capacity |

#### F. Iteration Semantics

| Contract | Explanation |
|----------|-------------|
| **Occupied-bucket iteration** | `occupied` property, `forEach.occupied { }`, `eachOccupied { }` -- iterating only non-empty, non-deleted buckets is hash-table logic |
| **Position-only iteration** | `eachPosition { }` -- yielding positions without bucket details is a convenience over hash-table iteration |
| **Early-exit iteration** | `eachOccupiedWhile { }` -- short-circuit scan is a hash-table-level traversal pattern |
| **Iterator types** | `Hash.Occupied.View.Iterator` and `Hash.Occupied.Static.Iterator` encode the skip-sentinel scan logic |

#### G. Sequence Protocol Conformance

| Conformance | What it provides | Why not in Buffer |
|-------------|-----------------|-------------------|
| `Sequence.Protocol` on `Hash.Occupied.View` | Multi-pass iteration contract | Buffer.Slots has no concept of "occupied" |
| `Swift.Sequence` on `Hash.Occupied.View` | Interop with stdlib algorithms | Buffer should not carry stdlib coupling for hash-specific iteration |
| `Sequence.Protocol` on `Hash.Occupied.Static` | Same for static variant | Same |
| `Swift.Sequence` on `Hash.Occupied.Static` | Same for static variant | Same |

#### H. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Hash.Table.Static<bucketCapacity>` | Compile-time bucket capacity. Promise: "this never heap-allocates" |
| `Index<Element>.Bounded<bucketCapacity>` positions | Bounded positions guarantee no OOB in the static variant |
| Conditional `Copyable where Element: Copyable` | User-facing copyability guarantee |
| Conditional `@unchecked Sendable where Element: Sendable` | User-facing sendability guarantee |
| `Hash.Occupied<Source>` | Reified occupied-bucket record with typed bucket, hash, and position |

#### I. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | `Hash.Table` (heap) and `Hash.Table.Static<N>` (inline) |
| Property.View patterns | `.forEach.occupied { }`, `.bucket.for(hash:)`, `.bucket.next(_:)`, `.positions.decrement(after:)`, `.remove.all()` |
| Tag-based namespace | `ForEach`, `BucketOps`, `Remove`, `Positions` as operation namespaces |
| `ensureUnique()` | CoW support as a consumer-facing API |
| `underestimatedCount` | Efficient count hint for sequence consumers |

### What Buffer.Slots / InlineArray Own (Hash.Table Merely Delegates)

| Concern | Owned by Buffer.Slots / InlineArray |
|---------|--------------------------------------|
| Memory allocation/deallocation | `Buffer.Slots` creates/destroys heap storage |
| Slot-level read/write | `_buffer[metadata:]`, `_buffer[payload:]` subscripts |
| Capacity tracking | Physical slot count |
| Metadata + payload dual-lane layout | `Buffer.Slots` provides `[metadata...][payload...]` |
| Fill operations | `_buffer.fill(metadata:)`, `_buffer.fill(payload:)` |
| CoW mechanism | `_buffer.ensureUnique()` |
| Inline storage | `InlineArray<N, Int>` for the static variant |
| Pointer access | `_buffer.metadataPointer`, `_buffer.pointer(at:)` |

---

## Audit: Current hash-table-primitives

### Audit Methodology

For each file in `hash-table-primitives`, classify every public API member as:
- **HASH TABLE**: Solely hash-table discipline (hash function contract, key uniqueness, collision resolution, position mapping, load factor policy, iteration semantics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo`)
- **CONTESTED**: Could belong to either layer

### Module: Hash Table Primitives Core

#### `Hash.Table.swift` -- Type Definition, Sentinels, Init, Static Variant

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct Table<Element: ~Copyable>: ~Copyable` | **HASH TABLE** | Type definition with phantom-typed element |
| `struct Bucket: ~Copyable` | **HASH TABLE** | Phantom type preventing bucket/position confusion |
| `typealias BucketIndex = Index<Bucket>` | **HASH TABLE** | Typed coordinate for bucket space |
| `enum BucketOps`, `enum ForEach`, `enum Remove`, `enum Positions` | **HASH TABLE** | Operation namespace tags |
| `_count: Index<Element>.Count` | **HASH TABLE** | Active element count (hash-table semantic: excludes tombstones) |
| `_occupied: Index<Bucket>.Count` | **HASH TABLE** | Occupancy count (hash-table semantic: includes tombstones) |
| `_buffer: Buffer<Int>.Slots<Int>` | **DELEGATE** | Underlying storage |
| `static var empty: Int` | **HASH TABLE** | Sentinel value -- hash-table probing concern |
| `static var deleted: Int` | **HASH TABLE** | Tombstone sentinel -- hash-table probing concern |
| `init(minimumCapacity:)` | **HASH TABLE** | Computes bucket capacity from element capacity, initializes sentinels |
| `static func bucketCapacity(for:)` | **HASH TABLE** | Power-of-two sizing with 70% load factor target |
| `static func normalize(_:)` | **HASH TABLE** | Hash normalization to avoid sentinel collisions |
| `struct Static<let bucketCapacity: Int>` | **HASH TABLE** | Inline variant with compile-time capacity |
| `Static._hashes: InlineArray<N, Int>` | **DELEGATE** | Underlying storage (inline) |
| `Static._positions: InlineArray<N, Int>` | **DELEGATE** | Underlying storage (inline) |
| `Static._count`, `Static._occupied` | **HASH TABLE** | Same dual-count semantics |
| `Static.empty`, `Static.deleted`, `Static.normalize(_:)` | **HASH TABLE** | Mirror parent sentinels |
| `Static.init()` | **HASH TABLE** | Power-of-two precondition, sentinel initialization |
| `Static.bucket(for:)` | **HASH TABLE** | Hash-to-bucket mapping (cyclic projection) |
| `Static.bucket(after:)` | **HASH TABLE** | Linear probe advancement (cyclic successor) |
| `Static.forEachBucketIndex(_:)` | **HASH TABLE** | Bucket iteration |
| `Static.readHash(at:)`, `Static.writeHash(at:value:)` | **CONTESTED** | Typed access to InlineArray -- see discussion below |
| `Static.readPosition(at:)`, `Static.writePosition(at:value:)` | **CONTESTED** | Same -- typed access wrapping raw InlineArray |
| Conditional `Copyable`, `@unchecked Sendable` | **HASH TABLE** | Type-level invariants |

#### `Hash.Occupied.swift` -- Occupied Bucket Record

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct Occupied<Source: ~Copyable>` | **HASH TABLE** | Reified scan result: bucket + hash + position |
| `let bucket: BucketIndex` | **HASH TABLE** | Which bucket was occupied |
| `let hash: Int` | **HASH TABLE** | Stored hash for rehashing / comparison |
| `let position: Index<Source>` | **HASH TABLE** | Typed position in external storage |

#### `Hash.Occupied.Static.swift` -- Static Iteration View

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct Static<let bucketCapacity: Int>` | **HASH TABLE** | Copy-based iteration view for inline tables |
| `func makeIterator() -> Iterator` | **HASH TABLE** | Sequence entry point |

#### `Hash.Occupied.View.swift` -- Heap Iteration View

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct View` | **HASH TABLE** | Pointer-based iteration view for heap tables |
| `func makeIterator() -> Iterator` | **HASH TABLE** | Sequence entry point |

#### `Hash.Occupied.Static.Iterator.swift` -- Static Iterator

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct Iterator` | **HASH TABLE** | Skip-sentinel scan logic (empty/deleted filtering) |
| `mutating func next() -> Hash.Occupied<Source>?` | **HASH TABLE** | The sentinel-aware skip is hash-table discipline |

#### `Hash.Occupied.View.Iterator.swift` -- Heap Iterator

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct Iterator` | **HASH TABLE** | Same skip-sentinel scan, pointer-based |
| `mutating func next() -> Hash.Occupied<Source>?` | **HASH TABLE** | Same sentinel-aware skip |

#### `Hash.Table+BufferAccess.swift` -- Buffer Subscript Bridge

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var bucketCapacity: Index<Bucket>.Count` | **DELEGATE** | Reads `_buffer.capacity` with type retag |
| `subscript(hash bucket:) -> Int` | **CONTESTED** | Typed bridge over `_buffer[metadata:]` -- see discussion |
| `subscript(position bucket:) -> Index<Element>` | **CONTESTED** | Typed bridge over `_buffer[payload:]` with Int<->Index conversion |

#### `Hash.Table+occupied.swift` -- Heap Occupied View

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var occupied: Hash.Occupied<Element>.View` | **HASH TABLE** | Constructs pointer-based iteration view |

#### `Hash.Table.Static+occupied.swift` -- Static Occupied View

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var occupied: Hash.Occupied<Element>.Static<bucketCapacity>` | **HASH TABLE** | Constructs copy-based iteration view |

#### `Hash.Table.Static+Lookup.swift` -- Static Lookup

| Item | Classification | Rationale |
|------|---------------|-----------|
| `func position(forHash:equals:)` | **HASH TABLE** | Hash-first, equality-second lookup with linear probing |
| `func index(forHash:equals:)` | **HASH TABLE** | Same but returns bucket index |
| `func contains(hashValue:equals:)` | **HASH TABLE** | Membership test delegating to `position(forHash:equals:)` |

#### `Hash.Table.Static+Insertion.swift` -- Static Insertion

| Item | Classification | Rationale |
|------|---------------|-----------|
| `mutating func insert(position:hashValue:equals:)` | **HASH TABLE** | Duplicate detection, tombstone reuse, probe chain traversal |
| `mutating func insert(__unchecked:position:hashValue:)` | **HASH TABLE** | Unchecked insert (caller guarantees uniqueness) |

#### `Hash.Table.Static+Removal.swift` -- Static Removal

| Item | Classification | Rationale |
|------|---------------|-----------|
| `mutating func remove(hashValue:equals:)` | **HASH TABLE** | Find-then-tombstone removal |
| `mutating func remove(atBucket:)` | **HASH TABLE** | Direct bucket removal with precondition |
| `package mutating func clearAll()` | **HASH TABLE** | Bulk sentinel reset |
| `mutating func rehash()` | **HASH TABLE** | Tombstone compaction -- hash-table maintenance |

#### `Hash.Table.Static+ForEach.swift` -- Static ForEach

| Item | Classification | Rationale |
|------|---------------|-----------|
| `package func eachOccupied(_:)` | **HASH TABLE** | Sentinel-aware bucket scan |
| `package func eachPosition(_:)` | **HASH TABLE** | Position-only variant |
| `package func eachOccupiedWhile(_:)` | **HASH TABLE** | Early-exit variant |

#### `Hash.Table.Static+PositionUpdates.swift` -- Static Position Maintenance

| Item | Classification | Rationale |
|------|---------------|-----------|
| `package mutating func decrementAllPositions(after:)` | **HASH TABLE** | Index coherence maintenance after external removal |
| `package mutating func updatePositionInternal(forHash:equals:newPosition:)` | **HASH TABLE** | Re-target a hash entry |
| `package mutating func updatePositionInternal(atBucket:newPosition:)` | **HASH TABLE** | Direct position update |

#### `Hash.Table.Static+Properties.swift` -- Static Properties

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var count: Index<Element>.Count` | **HASH TABLE** | Active element count (excludes tombstones) |
| `var isEmpty: Bool` | **HASH TABLE** | Derived from count |
| `var occupancy: BucketIndex.Count` | **HASH TABLE** | Includes tombstones -- hash-table-specific |
| `var capacity: BucketIndex.Count` | **DELEGATE** | Compile-time constant from `bucketCapacity` |
| `var shouldGrow: Bool` | **HASH TABLE** | 70% load factor policy |
| `var isFull: Bool` | **HASH TABLE** | Occupancy saturation check |

### Module: Hash Table Primitives (Public API Layer)

#### `Hash.Table+Lookup.swift` -- Heap Lookup

| Item | Classification | Rationale |
|------|---------------|-----------|
| `func position(forHash:equals:)` | **HASH TABLE** | Hash-first lookup with linear probing via buffer subscripts |
| `func index(forHash:equals:)` | **HASH TABLE** | Same, returns bucket index |

#### `Hash.Table+Properties.swift` -- Heap Properties

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var count: Index<Element>.Count` | **HASH TABLE** | Passthrough of `_count` |
| `var isEmpty: Bool` | **HASH TABLE** | Derived from `_count` |
| `var capacity: Index<Bucket>.Count` | **DELEGATE** | Passthrough of `bucketCapacity` |
| `var shouldGrow: Bool` | **HASH TABLE** | 70% load factor policy |

#### `Hash.Table+Insertion.swift` -- Heap Insertion

| Item | Classification | Rationale |
|------|---------------|-----------|
| `mutating func insert(position:hashValue:equals:)` | **HASH TABLE** | Duplicate detection, tombstone reuse, auto-grow |
| `mutating func insert(__unchecked:position:hashValue:)` | **HASH TABLE** | Unchecked insert with auto-grow |
| `mutating func grow()` | **HASH TABLE** | Allocate new buffer, rehash all entries, replace old buffer |

#### `Hash.Table+Removal.swift` -- Heap Removal

| Item | Classification | Rationale |
|------|---------------|-----------|
| `mutating func remove(hashValue:equals:)` | **HASH TABLE** | Find-then-tombstone removal |
| `mutating func remove(at:)` | **HASH TABLE** | Direct bucket removal |
| `var remove: Remove.View` | **HASH TABLE** | Property.View access point |
| `remove.all(keepingCapacity:)` | **HASH TABLE** | Consumer ergonomic with capacity retention option |

#### `Hash.Table+ensureUnique.swift` -- CoW

| Item | Classification | Rationale |
|------|---------------|-----------|
| `mutating func ensureUnique() -> Bool` | **DELEGATE** | Pure delegation to `_buffer.ensureUnique()` |

#### `Hash.Table+ForEach.swift` -- Heap ForEach

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var forEach: ForEach.View` | **HASH TABLE** | Property.View access point |
| `forEach.occupied(_:)` | **HASH TABLE** | Sentinel-aware bucket scan |

#### `Hash.Table+Bucket.swift` -- Heap Bucket Operations

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var bucket: BucketOps.View` | **HASH TABLE** | Property.View access point |
| `bucket.for(hash:)` | **HASH TABLE** | Hash-to-bucket mapping |
| `bucket.next(_:)` | **HASH TABLE** | Linear probe advancement |

#### `Hash.Table+PositionUpdates.swift` -- Heap Position Maintenance

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var positions: Positions.View` | **HASH TABLE** | Property.View access point |
| `positions.decrement(after:)` | **HASH TABLE** | Index coherence after external removal |

#### `Hash.Occupied.View+Sequence.Protocol.swift` -- Sequence Conformance

| Item | Classification | Rationale |
|------|---------------|-----------|
| `Sequence.Protocol` conformance | **HASH TABLE** | Protocol commitment for occupied-bucket iteration |
| `Swift.Sequence` conformance | **HASH TABLE** | Stdlib interop |
| `var underestimatedCount: Int` | **HASH TABLE** | Efficient count hint |

#### `Hash.Occupied.Static+Sequence.Protocol.swift` -- Sequence Conformance

| Item | Classification | Rationale |
|------|---------------|-----------|
| `Sequence.Protocol` conformance | **HASH TABLE** | Same for static variant |
| `Swift.Sequence` conformance | **HASH TABLE** | Same |
| `var underestimatedCount: Int` | **HASH TABLE** | Same |

#### Static Property.View Wrappers

| File | Items | Classification | Rationale |
|------|-------|---------------|-----------|
| `Hash.Table.Static+ForEach.swift` | `forEach.occupied(_:)`, `forEach.position(_:)` | **HASH TABLE** | Sentinel-aware scan exposed via Property.View |
| `Hash.Table.Static+Bucket.swift` | `bucket.for(hash:)`, `bucket.next(_:)` | **HASH TABLE** | Hash-to-bucket mapping via Property.View |
| `Hash.Table.Static+Removal.swift` | `remove.all()` | **HASH TABLE** | Bulk clear via Property.View |
| `Hash.Table.Static+PositionUpdates.swift` | `positions.decrement(after:)`, `positions.update(forHash:equals:newPosition:)`, `positions.update(atBucket:newPosition:)` | **HASH TABLE** | Position maintenance via Property.View |

### Contested Items Discussion

#### `readHash` / `writeHash` / `readPosition` / `writePosition` (Static variant)

These methods bridge between the hash table's typed coordinate system (`BucketIndex`, `Index<Element>.Bounded<N>`) and the raw `InlineArray<N, Int>` storage. They perform:
1. `BucketIndex` -> `Int` index conversion for array subscript
2. Raw `Int` -> `Index<Element>.Bounded<N>` type reconstruction

**Assessment**: These are **correctly placed**. The typed-to-raw bridge is the hash table's responsibility. `InlineArray` stores raw `Int`; the hash table interprets those integers as typed positions. Without these methods, the type system boundary would not exist. They are analogous to the `subscript(hash:)` and `subscript(position:)` on the heap variant's `BufferAccess` extension.

**Note**: The existing `hash-table-storage-buffer-layering.md` research identifies this raw-Int storage as **Semantic Violation SV-2**: "Typed values stored as raw integers." This is a known and accepted provisional violation in the storage layer. The `readPosition`/`writePosition` methods are the *mitigation* -- they ensure the hash table's public API never exposes raw integers.

#### `subscript(hash bucket:)` and `subscript(position bucket:)` (Heap variant)

Same analysis as above. These bridge `_buffer[metadata:]` / `_buffer[payload:]` to typed coordinates. The buffer stores raw `Int`; the hash table adds type safety.

**Assessment**: **Correctly placed**. Pure typed bridge. The hash table adds `Index<Element>` reconstruction that the buffer cannot provide (it does not know what `Element` means).

#### `grow()` -- Is this Buffer or Hash Table?

`grow()` allocates a new `Buffer.Slots`, iterates all occupied buckets in the old buffer, re-probes each entry into the new buffer, and replaces `_buffer`. This mixes allocation (buffer concern) with rehashing (hash-table concern).

**Assessment**: **Correctly placed as hash-table discipline**. The rehashing logic is inseparable from growth. Buffer-level growth (doubling capacity, memcpy) does not work for hash tables because entries must be re-probed. The allocation of the new buffer is a necessary side effect, not the defining operation. This is the same conclusion reached in `hash-table-storage-buffer-layering.md`, Section "Hash table growth is incompatible with buffer growth."

#### `remove.all(keepingCapacity:)` -- Direct Buffer Manipulation

The `keepingCapacity: true` path calls `_buffer.fill(metadata:)` and `_buffer.fill(payload:)` directly. The `keepingCapacity: false` path creates a new `Buffer.Slots` entirely.

**Assessment**: **Correctly placed but mildly concerning**. The `keepingCapacity: true` path directly manipulates buffer internals (fill operations). This is not a layering violation per se -- the hash table needs to reset sentinels, and `fill(metadata:)` is the efficient way to do it. However, it does mean the hash table has knowledge of the buffer's fill API. This is an acceptable coupling: the hash table *owns* the interpretation of what "empty" means, and it delegates the *mechanism* of writing that interpretation to the buffer.

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: hash-table-primitives is well-layered

The current `hash-table-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Hash-table discipline** -- hash function contract, key uniqueness, collision resolution, position mapping, load factor policy, iteration semantics, type-level invariants
2. **Pure delegation** -- thin wrappers over `Buffer.Slots` / `InlineArray` that add typed coordinate bridges
3. **Correctly shared** -- operations like `grow()` and `remove.all(keepingCapacity:)` that necessarily touch both layers but are driven by hash-table semantics

### Specific Recommendations

#### 1. No Buffer Concerns Have Leaked Upward

The audit found **zero instances** of hash-table-primitives exposing buffer-internal details to consumers. Unlike C++ `unordered_map` which exposes `bucket_count()`, `load_factor()`, and `rehash(n)` to users, our `Hash.Table` keeps all buffer interactions behind the `package`-scoped `_buffer` property and the `package`-scoped buffer subscripts. The consumer sees only typed positions, hash values, and high-level operations.

#### 2. `shouldGrow` Visibility Is Appropriate

`shouldGrow` is `public` on `Hash.Table.Static` but `internal` on `Hash.Table` (heap variant). This asymmetry is correct:
- The heap variant auto-grows in `insert()`, so consumers never need `shouldGrow`
- The static variant **cannot** grow (fixed capacity), so `shouldGrow` serves as a diagnostic: "should you migrate to a larger table or spill to heap?"

This parallels `isSpilled` on `Array.Small` -- a diagnostic property that legitimately exposes an implementation detail.

#### 3. `occupancy` on Static Is Appropriate

`Hash.Table.Static.occupancy` exposes the tombstone-inclusive count. This is hash-table discipline (distinguishing active count from probe-chain occupancy), not a buffer leak. Users of static hash tables legitimately need this for `rehash()` decisions.

#### 4. Sentinel Constants Are Hash Table Discipline

`empty` and `deleted` are `public static var` on both `Hash.Table` and `Hash.Table.Static`. One might argue these are buffer-level constants. However, they define the hash table's probing termination protocol: "stop at empty, skip deleted." This is collision resolution policy, not buffer state. The buffer merely stores the integers; the hash table gives them meaning.

#### 5. Missing APIs (Future Work, Not Layering Violations)

| Missing | Category | Priority |
|---------|----------|----------|
| `contains(hashValue:equals:)` on heap `Hash.Table` | Convenience | Low -- trivially `position(forHash:equals:) != nil` |
| `rehash()` on heap `Hash.Table` | Maintenance | Medium -- tombstone compaction after many deletions |
| `Equatable` conformance | Algebraic | Low -- comparing hash tables by content is rarely needed (compare the containers they serve instead) |

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure hash-table discipline | 50+ distinct APIs | Correctly placed |
| Pure delegation | 5 passthrough properties/methods | Correctly placed -- thin bridging is the design intent |
| Buffer concern leaked into hash table | **0** | Clean separation |
| Hash-table concern missing | 2-3 items | Future work, not a layering violation |

---

## References

- [Software Foundations, "ADT: Abstract Data Types"](https://softwarefoundations.cis.upenn.edu/vfa-current/ADT.html): Formal equational specification of the table ADT
- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms
- [hashbrown -- Rust port of Google's SwissTable](https://github.com/rust-lang/hashbrown): RawTable / HashMap / HashTable layering
- [DeepWiki: hashbrown Core Architecture](https://deepwiki.com/rust-lang/hashbrown/2-core-architecture): Three-tier architecture analysis
- [Swisstable, a Quick and Dirty Description](https://faultlore.com/blah/hashbrown-tldr/): Swiss table control bytes and SIMD probing
- [Robin Hood Hashing Should Be Your Default](https://www.sebastiansylvan.com/post/robin-hood-hashing-should-be-your-default-hash-table-implementation/): Buffer-level probe variance optimization
- [cppreference: std::unordered_map](https://en.cppreference.com/w/cpp/container/unordered_map.html): C++ bucket interface (negative example)
- [Hash table -- Wikipedia](https://en.wikipedia.org/wiki/Hash_table): Overview of open addressing, chaining, load factors
- [Optimizing Open Addressing](https://thenumb.at/Hashtables/): Probing strategies as buffer-level concern
- [Load Factor and Rehashing -- GeeksforGeeks](https://www.geeksforgeeks.org/dsa/load-factor-and-rehashing/): Traditional load factor analysis
- `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Research/hash-table-storage-buffer-layering.md`: Companion research on downward dependency
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`: Template document (array variant of this analysis)
