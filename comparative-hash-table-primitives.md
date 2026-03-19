---
title: "Comparative Analysis: Hash-Table-Primitives vs swift-io Hash-Based Structures"
version: 1.0.0
status: RECOMMENDATION
last_updated: 2026-02-24
---

# Comparative Analysis: Hash-Table-Primitives vs swift-io Hash-Based Structures

<!--
---
date: 2026-02-24
scope: swift-hash-table-primitives, swift-dictionary-primitives, swift-io
status: RECOMMENDATION
---
-->

## 1. Hash-Table-Primitives Catalog

**Location**: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/`

### 1.1 Module Structure

| Module | Purpose |
|--------|---------|
| `Hash Table Primitives Core` | Core types, storage, bucket access, sentinel management |
| `Hash Table Primitives` | Public API surface: Property.View accessors, CoW, Sequence conformance |

### 1.2 Core Types

#### `Hash.Table<Element: ~Copyable>` (heap-allocated, growable)

- **Strategy**: Open-addressed linear probing
- **Storage**: `Buffer<Int>.Slots<Int>` (metadata = hash values, payload = positions)
- **Load factor**: 70% threshold, power-of-two bucket sizing
- **Sentinels**: `empty = 0`, `deleted = Int.min` (tombstone)
- **Growth**: Automatic doubling via `grow()` when `shouldGrow` is true
- **CoW**: `ensureUnique()` delegates to `Buffer.Slots.ensureUnique()` (Copyable only)
- **Conditional conformances**: `Copyable where Element: Copyable`, `@unchecked Sendable where Element: Sendable`

#### `Hash.Table<Element>.Static<let bucketCapacity: Int>` (inline, fixed-capacity)

- **Strategy**: Open-addressed linear probing (same as heap variant)
- **Storage**: `InlineArray<bucketCapacity, Int>` for hashes + positions (zero heap allocation)
- **Capacity**: Compile-time constant, must be power of two
- **Positions**: `Index<Element>.Bounded<bucketCapacity>` (compile-time bounded)
- **Growth**: Cannot grow; `isFull` and `shouldGrow` are diagnostic signals for spill-to-heap patterns
- **Rehash**: In-place `rehash()` to compact tombstones without reallocation
- **Conditional conformances**: Same as heap variant

#### `Hash.Occupied<Source: ~Copyable>` (bucket scan result)

- **Fields**: `bucket: BucketIndex`, `hash: Int`, `position: Index<Source>`
- **Iteration views**: `Hash.Occupied<Source>.View` (pointer-based, heap), `Hash.Occupied<Source>.Static<let bucketCapacity>` (InlineArray copy-based, inline)
- **Sequence conformance**: Both views conform to `Sequence.Protocol` and `Swift.Sequence`

### 1.3 Full API Surface

**Lookup**:
- `position(forHash:equals:)` -> `Index<Element>?` / `Index<Element>.Bounded<cap>?`
- `bucketIndex(forHash:equals:)` -> `BucketIndex?`
- `contains(hashValue:equals:)` -> `Bool` (Static only)

**Insertion**:
- `insert(position:hashValue:equals:)` -> `Bool` (duplicate-checking)
- `insert(__unchecked:position:hashValue:)` (no duplicate check)

**Removal**:
- `remove(hashValue:equals:)` -> removed position or nil
- `remove(at:)` / `remove(atBucket:)` (direct bucket removal)
- `remove.all(keepingCapacity:)` (heap) / `remove.all()` (Static)

**Position updates**:
- `positions.decrement(after:)` — shift positions down after external removal
- `positions.update(forHash:equals:newPosition:)` — update stored position

**Iteration**:
- `forEach.occupied { bucket, position in }` — all occupied buckets
- `forEach.position { position in }` (Static only)
- `occupied` property — Sequence view over occupied buckets

**Bucket operations** (via Property.View):
- `bucket.for(hash:)` — compute bucket for hash
- `bucket.next(_:)` — next in probe sequence

**Diagnostics**:
- `count`, `isEmpty`, `capacity`, `occupancy`, `shouldGrow`, `isFull`

### 1.4 What Hash-Table-Primitives Does NOT Offer

- No Robin Hood hashing or other advanced probing strategies
- No lock-free / concurrent variant
- No chaining-based collision resolution
- No built-in key-value storage (it is a position index, not a map)
- No direct `subscript[key]` — it maps hashes to positions in external storage

---

## 2. Hash-Primitives Catalog

**Location**: `/Users/coen/Developer/swift-primitives/swift-hash-primitives/`

| Type | Purpose |
|------|---------|
| `Hash` | Namespace enum |
| `Hash.Protocol` | `~Copyable`-aware Hashable (refines `Equation.Protocol`) |
| `Hash.Value` | `Tagged<Hash, Int>` wrapper for hash values |
| `Hash Primitives Standard Library Integration` | Bridges `Swift.Hashable` types to `Hash.Protocol` |

---

## 3. Dictionary-Primitives Catalog

**Location**: `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/`

Dictionary-primitives is a **consumer** of Hash-table-primitives. It provides the full key-value map abstraction:

| Variant | Storage | Growth | Hash Table Used |
|---------|---------|--------|-----------------|
| `Dictionary<K, V>` | Slab (sparse, O(1) removal) | Dynamic | `Hash.Table<Key>` (heap) |
| `Dictionary<K, V>.Ordered` | Linear (dense, insertion-ordered) | Dynamic | Via `Set<Key>.Ordered` which uses `Hash.Table<Key>` |
| `Dictionary<K, V>.Ordered.Bounded` | Linear bounded | Fixed capacity | Via `Set<Key>.Ordered` |
| `Dictionary<K, V>.Ordered.Static<cap>` | InlineArray | Fixed (compile-time) | `Hash.Table<Key>.Static<cap>` |
| `Dictionary<K, V>.Ordered.Small<cap>` | Inline + spill-to-heap | Hybrid | Inline scan / heap `Set.Ordered` |

**Key insight**: Every Dictionary variant internally uses a `Hash.Table` for index lookup. The Dictionary layer adds key storage, value storage, and the full map API. Hash-table-primitives is the position-index engine underneath.

---

## 4. swift-io Hash-Based Structures

### 4.1 Inventory of Dictionary/Hash Usage Sites

| Site | Type | Key | Value | Location |
|------|------|-----|-------|----------|
| **Handle.Registry** | `[IO.Handle.ID: IO.Executor.Handle.Entry<Resource>]` | `IO.Handle.ID` | Entry (class, ~Copyable Resource) | `IO/IO.Handle.Registry.swift:93` |
| **Event.Registry** | `Mutex<[Int32: [IO.Event.ID: IO.Event.Registration.Entry]]>` | `Int32` (outer), `IO.Event.ID` (inner) | Registration.Entry | `IO Events/IO.Event.Registry.swift:13` |
| **epoll Operations** | Same as Event.Registry (module-level `registry`) | Same | Same | `IO Events/IO.Event.Poll.Operations.swift:17` |
| **kqueue Operations** | Same as Event.Registry (via shared) | Same | Same | `IO Events/IO.Event.Queue.Operations.swift` |
| **IOCP.Registry** | `[IO.Completion.ID: Entry]` | `IO.Completion.ID` | Entry (id, kind, resource, header ptr) | `IO Completions/IO.Completion.IOCP.Registry.swift:105` |
| **IOCP.State.associatedHandles** | `Set<UInt>` | `UInt` | — | `IO Completions/IO.Completion.IOCP.swift:65` |
| **Acceptance.Queue.index** | `Dictionary<IO.Blocking.Ticket, Coordination>.Ordered.Bounded` | Ticket | Coordination | `IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift:64` |

### 4.2 Per-Site Analysis

#### 4.2.1 Handle.Registry (`handles: [IO.Handle.ID: Entry]`)

- **Access pattern**: Actor-isolated. Single writer, no concurrent reads.
- **Lifecycle**: Entries added on `register()`, removed on `destroy()` or `shutdown()`.
- **Size**: Typically tens to hundreds of handles per registry.
- **Key type**: `IO.Handle.ID` — a struct with `raw: UInt64`, `scope: UInt64`, `shard: UInt16`. Conforms to `Hashable`.
- **Value type**: `IO.Executor.Handle.Entry<Resource>` — a class wrapping ~Copyable resource.
- **Operations**: subscript lookup, insert, removeValue(forKey:), iteration during shutdown.
- **Growth**: Unbounded — handles can be registered at any rate.

**Assessment**: This is a classic unbounded dynamic dictionary. The key is a small struct. The value is a class reference (8 bytes). Swift's standard `Dictionary` is well-suited here. A primitives replacement would need to be the slab-backed `Dictionary<K, V>` for O(1) removal, but the class-reference value means ARC overhead dominates. The existing `[IO.Handle.ID: Entry]` is fine.

**Verdict**: No replacement benefit.

#### 4.2.2 Event.Registry (`Mutex<[Int32: [IO.Event.ID: Entry]]>`)

- **Access pattern**: Mutex-protected. Accessed from static methods.
- **Outer dictionary**: Keyed by epoll/kqueue fd (Int32). Very few entries (one per selector).
- **Inner dictionary**: Keyed by registration ID (UInt-based). Entries added on register, removed on deregister.
- **Size**: Outer: 1-4 entries. Inner: tens to thousands of registrations.
- **Operations**: lookup, insert, removeValue(forKey:), iteration to build Set for stale filtering.

**Assessment**: The outer dictionary is tiny (1-4 fds). The inner dictionary grows proportionally to registered descriptors. This is accessed under a Mutex, so contention is a concern. The `poll()` path builds `Set<IO.Event.ID>` from the inner dict keys on every poll call — this is an allocation per poll.

A bounded hash table would help IF the maximum registration count were known ahead of time (e.g., per-selector). Since these are global shared registries, the count is truly unbounded. However, the per-poll `Set(keys)` construction is wasteful and could be replaced by direct membership queries against the inner dictionary — that is an algorithmic fix, not a data structure replacement.

**Verdict**: No replacement benefit from Hash-table-primitives. The per-poll `Set(keys)` allocation is a performance concern but is an algorithmic issue, not a container issue.

#### 4.2.3 IOCP.Registry (`[IO.Completion.ID: Entry]`)

- **Access pattern**: Poll-thread-confined (single-threaded, no synchronization).
- **Size**: Proportional to in-flight IOCP operations. Could be hundreds.
- **Operations**: insert (precondition unique), peek, remove, removeAll.
- **Key type**: `IO.Completion.ID` — likely a UInt64-based tagged type.

**Assessment**: This is poll-thread-confined, so no synchronization overhead. The operations are simple: insert, lookup, remove. A fixed-capacity hash table would be appropriate IF the maximum number of in-flight operations were bounded (e.g., by io_uring ring size or IOCP thread count). Windows IOCP does not inherently bound in-flight operations, so the dynamic dictionary is correct.

However, if a submission cap were imposed (which is common in production IO systems), `Hash.Table.Static<N>` would eliminate all heap allocation from the registry path. This is a candidate for a bounded variant.

**Verdict**: Potential benefit if a submission cap is added. Currently correct as unbounded.

#### 4.2.4 IOCP.State.associatedHandles (`Set<UInt>`)

- **Access pattern**: Poll-thread-confined.
- **Size**: Grows monotonically (handles are associated once, never removed).
- **Operations**: `contains`, `insert`.

**Assessment**: A simple "seen before" set. Grows forever. No removal needed. This is a candidate for a Bloom filter or a bitset if handles are dense integers, but those are separate primitives. `Set<UInt>` is fine.

**Verdict**: No replacement benefit.

#### 4.2.5 Acceptance.Queue.index (`Dictionary<Ticket, Coordination>.Ordered.Bounded`)

- **Access pattern**: Protected by `Runtime.State.lock`. Single-threaded mutation.
- **Size**: Fixed capacity (2x the queue capacity, for load factor).
- **Operations**: `set`, `remove`, iteration in debug.

**Assessment**: **Already uses Dictionary-primitives.** This is the one site that has adopted the primitives stack. It uses `Dictionary.Ordered.Bounded` which internally uses `Set<Key>.Ordered` which uses `Hash.Table<Key>`. The chain is complete.

**Verdict**: Already optimal. No change needed.

---

## 5. Comparative Assessment

### 5.1 What Hash-Table-Primitives Offers vs Dictionary-Primitives

| Capability | Hash.Table | Dictionary |
|-----------|-----------|------------|
| Direct position-index engine | Yes — this IS the engine | No — it consumes it |
| Key-value storage | No — external storage only | Yes — full map abstraction |
| Fixed-capacity inline variant | `Hash.Table.Static<N>` | `Dictionary.Ordered.Static<N>` (uses Static internally) |
| Bounded heap variant | `Hash.Table(minimumCapacity:)` (growable) | `Dictionary.Ordered.Bounded` (throws on overflow) |
| ~Copyable element support | Full | Full |
| Typed positions | `Index<Element>`, `Index<Element>.Bounded<N>` | Via Set.Ordered internally |
| CoW | `ensureUnique()` | Via Set.Ordered |

**Answer to Question 1**: Hash-table-primitives is strictly lower-level than Dictionary-primitives. It provides the bare hash-to-position index engine. Dictionary-primitives builds on top of it to provide the full key-value abstraction. They are not alternatives — they are layers.

### 5.2 Could swift-io Registries Benefit from Fixed-Capacity Hash Tables?

| Registry | Bounded? | Benefit of Hash.Table.Static | Practical? |
|----------|----------|------------------------------|-----------|
| Handle.Registry | No — handles are unbounded | None | No |
| Event.Registry | No — registrations are unbounded | None | No |
| IOCP.Registry | Could be bounded by submission ring size | Eliminates heap allocation in submit/poll hot path | Yes, if submission cap is added |
| associatedHandles | No — monotonically growing | None | No |
| Acceptance.Queue | Already bounded | Already uses Dictionary.Ordered.Bounded | Already done |

**Answer to Question 2**: Only one site (IOCP.Registry) could potentially benefit from `Hash.Table.Static`, and only if a submission cap were imposed. The remaining sites either need unbounded growth or already use primitives. Swift's standard `Dictionary` is appropriate for the unbounded cases because its O(1) amortized operations and automatic resizing match the usage patterns.

### 5.3 What General-Purpose Additions to Hash-Table-Primitives Would Serve IO Registries?

#### 5.3.1 Recommended Additions

1. **`Hash.Table.Bounded` (heap-allocated, fixed-capacity, throws on overflow)**

   Currently there is `Hash.Table` (growable heap) and `Hash.Table.Static` (inline fixed). The missing piece is a heap-allocated fixed-capacity variant that pre-allocates but does not grow. This would serve:
   - IOCP.Registry if a submission cap is imposed
   - Any IO subsystem with a known upper bound on in-flight operations
   - The pattern: allocate once at creation, no allocation during operation

   ```swift
   extension Hash.Table {
       struct Bounded: ~Copyable {
           // Pre-allocated Buffer.Slots, throws on overflow instead of growing
       }
   }
   ```

2. **`Hash.Table.Static` with `removeCompact()`**

   The current `remove(hashValue:equals:)` uses tombstones. For small inline tables in tight loops (like IOCP poll), tombstone accumulation degrades linear probe chains. A `removeCompact()` that performs backward-shift deletion (Robin Hood style, but simpler for linear probing) would avoid tombstone pollution entirely. This is O(1) amortized for random deletions from a linear-probing table.

3. **Direct membership test without position retrieval**

   The Event.Registry's `poll()` path builds a `Set<IO.Event.ID>` just to call `.contains()` for stale event filtering. If the inner dictionary exposed a direct `contains(key:)` method (which it already does via `Dict.contains(key)`), the poll hot path would avoid the per-poll Set allocation entirely. This is not a Hash.Table addition — it is an algorithmic improvement in swift-io.

#### 5.3.2 Not Recommended

- **Robin Hood hashing**: The current linear probing with tombstones is simple and correct. Robin Hood reduces worst-case probe length but adds complexity. For IO registries with moderate load factors, the benefit is marginal.

- **Lock-free hash table**: IO registries are either actor-isolated (Handle.Registry) or thread-confined (IOCP.Registry) or Mutex-protected (Event.Registry). None require a lock-free hash table. Adding one would be significant complexity with no consumer.

- **Chaining-based tables**: Open addressing with linear probing is cache-friendly and appropriate for the element sizes involved (Int-sized keys and positions). Chaining adds per-bucket allocation overhead.

---

## 6. Summary

| Question | Answer |
|----------|--------|
| Does Hash-table-primitives offer something Dictionary-primitives doesn't? | Yes — it is the lower layer. Hash.Table is the position-index engine that Dictionary uses internally. Direct use of Hash.Table is appropriate when you need a hash-to-position index without key-value storage overhead. |
| Could swift-io registries benefit from fixed-capacity hash tables? | Marginally. Only IOCP.Registry is a candidate, and only if a submission cap is imposed. The Acceptance.Queue already uses Dictionary.Ordered.Bounded. All other registries need unbounded growth. |
| What additions to Hash-table-primitives would serve IO registries? | (1) `Hash.Table.Bounded` — heap-allocated fixed-capacity variant. (2) `removeCompact()` — backward-shift deletion for tombstone-free inline tables. (3) Algorithmic fix in swift-io: eliminate per-poll `Set(keys)` allocation by querying the dictionary directly. |

### Priority Ranking

1. **High (algorithmic fix, no primitives change)**: Remove per-poll `Set<IO.Event.ID>` allocation in `IO.Event.Poll.Operations.poll()` and `IO.Event.Queue.Operations.poll()`. Replace with direct dictionary `contains` check. This is a swift-io change, not a primitives change.

2. **Medium (new primitive)**: Add `Hash.Table.Bounded` for pre-allocated, non-growing hash tables. Useful beyond IO — any system with known capacity bounds benefits.

3. **Low (optimization)**: Add backward-shift deletion to `Hash.Table.Static` as `removeCompact()`. Only matters for workloads with high churn in small inline tables.
