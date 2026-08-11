# Slab Discipline Boundary Analysis

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
Memory (Tier 13) → Storage (Tier 14) → Buffer (Tier 15) → Data Structure (Tier 16+)
```

`slab-primitives` sits at the top of this chain, wrapping `Buffer<Storage<Element>.Heap>.Slab.Bounded` (heap-backed) and `Buffer<Storage<Element>.Heap>.Slab.Inline<wordCount>` (stack-allocated) to present a consumer-facing slab abstraction. The question: does `slab-primitives` contain ONLY slab-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery — proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-slab-primitives).

## Question

What semantics belong SOLELY to the slab abstraction layer, and does `slab-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Bonwick Slab Allocator (1994)

Jeff Bonwick's original slab allocator, introduced in SunOS 5.4, was a **kernel memory allocator** designed around object caching. The key insight: allocating and freeing complex kernel objects (inodes, task structs, network buffers) repeatedly is expensive because constructors and destructors dominate cost. The slab allocator retains objects in an initialized state between uses, organized into:

- **Caches**: Per-type pools of pre-allocated objects.
- **Slabs**: Contiguous pages of memory divided into fixed-size slots.
- **Free list**: Tracks which slots within a slab are available.

Bonwick's design is fundamentally about **same-type, fixed-size slot management** with O(1) allocate/free. The slab is NOT a general-purpose allocator — it manages a homogeneous pool of identically-sized objects. This maps directly to our `Slab<Element>` generic structure.

**What Bonwick's slab owns as an abstraction:**
- Fixed-size slot granularity (all slots hold the same type).
- Occupancy tracking (which slots are in use).
- Free slot discovery (finding a vacant slot for allocation).
- Per-slot insert/remove without affecting other slots (stable indices).

**What Bonwick's slab does NOT own:**
- The underlying memory pages (that is the page allocator's concern).
- Object construction/destruction semantics (deferred to the cache layer above).
- Growth policy (slabs are fixed-size; the cache manages multiple slabs).

### Source 2: Rust `slab` Crate (tokio-rs)

The dominant Rust slab implementation (89M+ downloads). API surface:

```rust
let mut slab = Slab::new();               // growable
let key: usize = slab.insert(value);      // auto-insert, returns index
let value = slab.remove(key);             // remove by index
let value = &slab[key];                   // subscript (panics on vacant)
slab.contains(key) -> bool;              // occupancy check
slab.len() -> usize;                     // occupied count
slab.capacity() -> usize;               // total slots
slab.is_empty() -> bool;
slab.iter() -> (usize, &T);             // iterate occupied (index, value) pairs
slab.drain() -> (usize, T);             // consuming iteration
slab.retain(|key, &mut val| -> bool);   // filter in-place
slab.vacant_entry() -> VacantEntry;     // reserve-then-insert
slab.compact(|from, to, &mut val|);     // defragment
slab.clear();                           // remove all
slab.get(key) -> Option<&T>;            // safe lookup
slab.get_unchecked(key) -> &T;          // unsafe lookup
slab.vacant_key() -> usize;            // next key without mutation
slab.key_of(&val) -> usize;            // derive key from reference
```

**Key design decisions:**
- Growable by default. No fixed-capacity variant.
- Auto-insert is the primary API (`insert(val) -> key`). Manual index insertion does not exist.
- Uses a **free list** (not bitmap) for O(1) allocation.
- Index type is plain `usize` — untyped.
- No generation counting — keys are reused after removal without versioning.
- `compact()` is a slab-discipline operation: defragment the sparse structure, notifying callers of key changes.
- `retain()` is a slab-discipline operation: filter by occupancy predicate.

**What Rust `slab` considers slab-discipline:**
- Auto-insert returning a key (the slab chooses where to place the element).
- Occupancy-aware access (`contains`, `get` returning `Option`).
- Sparse iteration (skipping vacant slots).
- Compaction (closing gaps).
- `VacantEntry` pattern (reserve a slot, then populate it — essential when objects need to know their own key).

### Source 3: Rust `slotmap` Crate (Generational Slab)

SlotMap extends the slab concept with **generational indices** to solve the ABA problem:

```rust
let mut sm = SlotMap::new();
let key: DefaultKey = sm.insert(value);   // key = (index, generation)
sm.remove(key);                           // increments slot's generation
sm[key];                                  // panics if generation mismatch
sm.contains_key(key) -> bool;            // checks BOTH index AND generation
sm.get(key) -> Option<&V>;              // safe lookup with generation check
```

**Generational index semantics (solely slab/arena discipline):**
- Each slot has a monotonically increasing generation counter.
- Keys are `(index, generation)` pairs.
- On removal, the slot's generation is incremented, invalidating all outstanding keys to that slot.
- On access, the key's generation is compared to the slot's current generation — mismatch means the key is stale (ABA detected).
- `insert_with_key(|key| -> V)` — provide the key to the constructor before insertion (self-referential objects).

**What slotmap adds beyond basic slab:**
- Generation counting (ABA prevention).
- Key validity as a type-level concern (`DefaultKey`, `new_key_type!` macro).
- `SecondaryMap` / `SparseSecondaryMap` — companion data structures keyed to the same keys.
- `detach`/`reattach` — temporarily invalidate a key without losing the generation lineage.

### Source 4: Rust `generational-arena` Crate (fitzgen)

A safe arena allocator (zero `unsafe` code) using generational indices:

```rust
let mut arena = Arena::new();
let idx: Index = arena.insert(value);     // idx = (index, generation)
arena.remove(idx) -> Option<T>;           // checks generation
arena[idx];                                // panics on generation mismatch
arena.get(idx) -> Option<&T>;
arena.contains(idx) -> bool;              // generation-aware
arena.len();
arena.capacity();
arena.is_empty();
arena.iter() -> (Index, &T);             // sparse iteration with generational keys
arena.iter_mut() -> (Index, &mut T);
arena.drain() -> (Index, T);
arena.retain(|idx, &mut val| -> bool);
```

**Key insight from generational-arena's design:**
The `Index` type bundles `(usize, u64)` — the slot position and the generation. This is NOT just a plain integer. The arena's *discipline* is that all external references go through this generational key, and the arena validates the generation on every access. This is a **semantic contract** that the arena owns — the underlying `Vec<Entry<T>>` knows nothing about generations.

### Source 5: Entity-Component-System (ECS) Patterns

Catherine West's RustConf 2018 keynote established the canonical ECS-slab pattern. Entities are stored in a slab (or slotmap); entity IDs are slab keys. Components are stored in parallel slabs or secondary maps keyed to the same entity IDs.

**What ECS demands from the slab abstraction:**
- **Stable indices**: Inserting or removing entity B must not change entity A's index. Arrays violate this (removal shifts elements). Slabs do not.
- **Sparse storage**: Not all entities have all components. The slab handles gaps naturally.
- **O(1) insert/remove**: Entity creation/destruction is performance-critical.
- **Type-safe handles**: `EntityId` should not be confused with `ComponentId`. Phantom-typed indices (`Slab.Indexed<Entity>`) prevent this at the type level.
- **Occupancy queries**: "Is this entity alive?" maps to `isOccupied(at:)`.

### Source 6: ADT Theory (Slab as Abstract Data Type)

Formalizing the slab as an abstract data type, analogous to the array ADT (Liskov & Guttag):

```
Types: Slab<T>, Key, T

Operations:
  new()                                -> Slab<T>
  insert(s: Slab<T>, v: T)           -> (Slab<T>, Key)
  remove(s: Slab<T>, k: Key)         -> (Slab<T>, T)
  get(s: Slab<T>, k: Key)            -> T?
  isOccupied(s: Slab<T>, k: Key)     -> Bool
  occupancy(s: Slab<T>)              -> Nat
  firstVacant(s: Slab<T>)            -> Key?

Axioms:
  get(insert(s,v).slab, insert(s,v).key) = v           (read-after-write)
  get(insert(s,v).slab, k) = get(s,k)  where k != key  (non-interference)
  isOccupied(insert(s,v).slab, insert(s,v).key) = true (insert marks occupied)
  isOccupied(remove(s,k).slab, k) = false              (remove marks vacant)
  occupancy(insert(s,v).slab) = occupancy(s) + 1       (insert increments)
  occupancy(remove(s,k).slab) = occupancy(s) - 1       (remove decrements)
  occupancy(new()) = 0                                   (empty on creation)
```

**Critical axiom: non-interference.** Inserting or removing at key `k` does NOT change the value at any other key `j`. This is the fundamental difference from Array:

| Property | Array | Slab |
|----------|-------|------|
| **Density** | Dense — every index in `[0, count)` maps to an element | Sparse — gaps are allowed between occupied slots |
| **Index stability** | Unstable — `remove(at: i)` shifts all elements after `i` | Stable — `remove(at: k)` affects only slot `k` |
| **Ordering** | Ordered — position encodes insertion/logical order | Unordered — position is an opaque handle, not a rank |
| **Contiguity** | Guaranteed — elements are contiguous in memory | Not guaranteed — occupied slots may be non-contiguous |
| **Vacant slots** | None — count == capacity of initialized region | Natural — slots can be empty (vacancy is a first-class state) |

The ADT mentions NO implementation concerns: no bitmap, no free list, no contiguous memory, no growth policy. The slab is purely the **sparse indexed insert-remove-query contract with stable non-interfering keys**.

### Source 7: Slab vs Buffer — Semantic Boundary

Comparing what the buffer layer owns versus what the slab data structure layer owns:

| Concern | Buffer Layer | Slab Layer |
|---------|-------------|------------|
| Memory allocation | `Storage.Heap.create()` | Delegates |
| Slot storage | Contiguous memory for elements | Delegates |
| Bitmap manipulation | `header.bitmap[slot] = true/false` | Delegates |
| Element init/move/deinit | `storage.initialize()`, `storage.move()` | Delegates |
| Raw occupancy check | `header.bitmap[slot]` | Wraps with typed interface |
| **Typed insert/remove** | Untyped `Bit.Index` parameters | `Index<Element>` parameters |
| **Occupancy checking** | Precondition-based (caller must check) | Throws on violation |
| **Composed auto-insert** | Not provided | `firstVacant()` + `insert(_:at:)` |
| **Error semantics** | No error type | `Slab.Error` with `.full`, `.vacant`, `.occupied` |
| **Phantom-typed access** | `Buffer.Slab.Bounded.Indexed<Tag>` exists but is infrastructure | `Slab.Indexed<Tag>` is the consumer API |
| **Variant taxonomy** | `Buffer.Slab`, `.Bounded`, `.Inline`, `.Small` | `Slab`, `Slab.Static`, `Slab.Indexed` |
| **Conditional conformances** | None (buffer is unconditionally ~Copyable) | `Sendable where Element: Sendable` |
| **Consuming iteration** | `Sequence.Drain.Protocol` at buffer level | `drain` property via `Property.View` at slab level |
| **Value semantics commitment** | No value semantics concept | Future CoW for Copyable elements |

---

## Analysis

### What is SOLELY Slab Discipline

#### A. Typed Error Semantics

The slab's primary semantic contribution beyond the buffer: **occupancy-aware error handling**. The buffer layer uses preconditions (crash on misuse). The slab layer uses typed throws (recoverable errors).

| Error Case | What it means | Why not in Buffer |
|------------|---------------|-------------------|
| `Slab.Error.full` | Auto-insert failed because no vacant slot exists | Buffer has no auto-insert concept |
| `Slab.Error.vacant` | Remove/update targeted an empty slot | Buffer uses preconditions, not errors |
| `Slab.Error.occupied` | Insert targeted an already-occupied slot | Buffer uses preconditions, not errors |

The buffer's contract is: "caller MUST ensure preconditions." The slab's contract is: "caller MAY violate preconditions and receive a typed error." This is a fundamental escalation from mechanism (crash) to semantics (error recovery). Per [API-ERR-001], all throwing functions use typed throws — `throws(Slab<Element>.Error)`.

#### B. Composed Operations

| Operation | Composition | Why not in Buffer |
|-----------|-------------|-------------------|
| `insert(_:) -> Index<Element>` | `firstVacant()` + `insert(_:at:)` | Buffer provides the primitives; slab composes them into the "allocator-chosen placement" pattern |
| `update(at:with:) -> Element` at slab level | Occupancy check + buffer `update` | Buffer's `update` has no occupancy guard; slab adds the vacancy check |

The auto-insert pattern (`insert(_:) throws(Error) -> Index<Element>`) is the canonical slab operation from the prior art. It is the composition of two buffer primitives into a single atomic slab-discipline operation that:
1. Finds the first vacant slot.
2. Inserts the element there.
3. Returns the typed slot index.
4. Throws `.full` if no slot is available.

This composition does NOT exist at the buffer layer.

#### C. Typed Index Surface

| Aspect | Buffer uses | Slab uses | Why this is slab discipline |
|--------|-----------|-----------|---------------------------|
| Insert/remove parameters | `Bit.Index` | `Index<Element>` | Slab presents domain-typed indices; buffer uses bitmap-typed indices |
| Static variant indices | `Bit.Index.Bounded<wordCount>` | `Index<Element>.Bounded<wordCount>` | Same retagging principle at compile-time bounded level |
| Indexed variant | `Index<Tag>` at buffer level (via `Bounded.Indexed<Tag>`) | `Index<Tag>` at slab level (via `Slab.Indexed<Tag>`) | Consumer-facing phantom typing |
| Occupancy count | `Bit.Index.Count` | `Index<Element>.Count` / `Index<Tag>.Count` | Quantities typed to the element domain |

The retag chain is: `Index<Tag>` -> `Index<Element>` -> `Bit.Index` — two zero-cost `.retag()` calls. This is a **type-level commitment** that the slab makes to its consumers: "you operate in the `Element` domain (or `Tag` domain), never in the `Bit` domain."

#### D. Variant Taxonomy and Namespace

| Variant | What it provides | Why not in Buffer |
|---------|-----------------|-------------------|
| `Slab<Element>` | Consumer-facing name for heap-backed fixed-capacity slab | Buffer has `Buffer<Storage<Element>.Heap>.Slab.Bounded` — infrastructure name |
| `Slab<Element>.Static<let wordCount: Int>` | Consumer-facing name for inline slab | Buffer has `Buffer<Storage<Element>.Heap>.Slab.Inline<wordCount>` — infrastructure name |
| `Slab<Element>.Indexed<Tag>` | Consumer-facing phantom-typed wrapper | Buffer has `Buffer<Storage<Element>.Heap>.Slab.Bounded.Indexed<Tag>` — infrastructure name |
| `Slab<Element>.Error` | Domain-specific error type | Buffer has no error type |

The data structure layer provides the **namespace that consumers import**. `import Slab_Primitives` gives you `Slab`, `Slab.Static`, `Slab.Indexed`. The buffer layer's `Buffer.Slab.Bounded.Indexed<Tag>` is infrastructure — it should not appear in consumer code.

#### E. Conditional Conformances

| Conformance | What it provides | Why not in Buffer |
|-------------|-----------------|-------------------|
| `@unchecked Sendable where Element: Sendable` | Thread-safety contract for all variants | Buffer types do not declare Sendable |
| `Sequence.Drain.Protocol` | Consuming iteration protocol conformance | Buffer also conforms, but slab re-declares for its own type identity |

#### F. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| `drain` property via `Property<Sequence.Drain, Self>.View` | Ergonomic consuming iteration (`slab.drain { }`) |
| `peek(at:) -> Element?` (Copyable only) | Non-destructive read returning Optional (occupancy-aware) |
| `@discardableResult` on auto-insert | Caller can ignore the returned index |
| `__unchecked` variants | Escape hatch for performance-critical paths |

#### G. Semantic Contracts

| Contract | Explanation |
|----------|-------------|
| **Sparse occupancy invariant** | Slots can be vacant or occupied. The slab tracks and enforces this distinction. The buffer tracks it mechanically (bitmap bits); the slab elevates it to a semantic contract (typed errors on violation). |
| **Non-interference guarantee** | Insert/remove at slot `k` does not affect any other slot. This is implicit in the buffer (bitmap operations are per-bit) but the slab commits to it as a consumer-facing contract. |
| **Index stability** | Unlike Array (where `remove(at:)` shifts subsequent elements), Slab guarantees that indices are stable across mutations. This is a type-level commitment. |
| **Safe access by default** | Checked operations (`throws(Error)`) are the primary API. Unchecked operations (`__unchecked`) are the escape hatch. Buffer provides only unchecked (precondition) access. |

### What Buffer.Slab Owns (Slab Merely Delegates)

| Concern | Owned by Buffer.Slab |
|---------|---------------------|
| Memory allocation/deallocation | `Storage.Heap.create()`, `Storage.Inline` |
| Bitmap state machine | `header.bitmap[slot] = true/false` |
| Element init/move/deinit lifecycle | `storage.initialize()`, `storage.move()`, `storage.deinitialize()` |
| Occupancy counting | `header.bitmap.popcount` |
| Bitmap scanning | `header.bitmap.ones`, `header.firstVacant(max:)` |
| Raw slot access | `storage.pointer(at:)` |
| Bulk deinitialization | `deinitializeAll(header:storage:)` |
| Consuming iteration mechanics | `bitmap.ones.forEach { storage.move(at:) }` |
| Inline storage layout | `Storage.Inline<capacity>` with `@_rawLayout` |
| Heap storage layout | `Storage.Heap` with `ManagedBuffer` |
| Small buffer optimization | `Buffer.Slab.Small` (inline-to-heap spill) |
| `Sequence.Consume.Protocol` | `ConsumeState` class with cleanup-on-drop |
| `peek(at:)` mechanics | `storage.pointer(at:).pointee` |

---

## Audit: Current slab-primitives

### Audit Methodology

For each file in `slab-primitives/Sources/`, classify every public API member as:
- **SLAB**: Solely slab discipline (typed errors, composed operations, typed indices, variant taxonomy, ergonomics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo` or `_base.foo`)
- **CONTESTED**: Could belong to either layer

### Module: Slab Primitives Core

#### File: `Slab.swift` (type definitions, nested types, conditional conformances)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `struct Slab<Element: ~Copyable>: ~Copyable` | **SLAB** | Consumer-facing type identity and namespace |
| `package var _buffer: Buffer<Storage<Element>.Heap>.Slab.Bounded` | **SLAB** | Encapsulation — buffer is internal, not exposed |
| `init()` | **DELEGATE** | Delegates to `Buffer.Slab.Bounded(minimumCapacity: .zero)` |
| `init(minimumCapacity: Index<Element>.Count)` | **DELEGATE** | Delegates to `Buffer.Slab.Bounded(minimumCapacity:)` |
| `struct Static<let wordCount: Int>: ~Copyable` | **SLAB** | Variant taxonomy — consumer name for inline slab |
| `Static._buffer: Buffer<Storage<Element>.Heap>.Slab.Inline<wordCount>` | **SLAB** | Encapsulation |
| `Static.init()` | **DELEGATE** | Delegates to `Buffer.Slab.Inline()` |
| `struct Indexed<Tag: ~Copyable>: ~Copyable` | **SLAB** | Phantom-typed wrapper — type-safe access |
| `Indexed._base: Slab<Element>` | **SLAB** | Wraps base slab, not buffer directly |
| `Indexed.init()` | **DELEGATE** | Delegates to `Slab()` |
| `Indexed.init(minimumCapacity: Index<Tag>.Count)` | **SLAB** | Retags `Index<Tag>.Count` to `Index<Element>.Count` |
| `enum Error: Swift.Error, Sendable, Equatable` | **SLAB** | Domain error type — `.full`, `.vacant`, `.occupied` |
| `extension Slab: @unchecked Sendable where Element: Sendable` | **SLAB** | Conditional conformance — consumer contract |
| `extension Slab.Static: @unchecked Sendable where Element: Sendable` | **SLAB** | Same |
| `extension Slab.Indexed: @unchecked Sendable where Element: Sendable` | **SLAB** | Same |

#### File: `Slab ~Copyable.swift` (core operations on base Slab)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var occupancy: Index<Element>.Count` | **DELEGATE** | `_buffer.occupancy.retag(Element.self)` — delegation with retag |
| `var isEmpty: Bool` | **DELEGATE** | `_buffer.isEmpty` |
| `var isFull: Bool` | **DELEGATE** | `_buffer.isFull` |
| `func isOccupied(at index: Index<Element>) -> Bool` | **DELEGATE** | `_buffer.isOccupied(at: index.retag(Bit.self))` — adds retag |
| `func firstVacant() -> Index<Element>?` | **DELEGATE** | `_buffer.firstVacant()?.retag(Element.self)` — adds retag |
| `mutating func insert(_:at:) throws(Error)` | **SLAB** | Adds occupancy guard (`guard !_buffer.isOccupied`) + typed throw (`.occupied`) before delegating. Buffer has no error handling. |
| `mutating func insert(_:__unchecked:)` | **DELEGATE** | `_buffer.insert(consume element, at: index.retag(Bit.self))` |
| `mutating func remove(at:) throws(Error) -> Element` | **SLAB** | Adds occupancy guard (`guard _buffer.isOccupied`) + typed throw (`.vacant`) before delegating. Buffer has no error handling. |
| `mutating func remove(__unchecked:) -> Element` | **DELEGATE** | `_buffer.remove(at: index.retag(Bit.self))` |
| `mutating func insert(_:) throws(Error) -> Index<Element>` | **SLAB** | Composed operation: `firstVacant()` + `_buffer.insert`. Throws `.full`. Not in buffer. |
| `mutating func update(at:with:) throws(Error) -> Element` | **SLAB** | Occupancy guard + typed throw (`.vacant`) + buffer `update`. |
| `mutating func removeAll()` | **DELEGATE** | `_buffer.removeAll()` |
| `var drain: Property<Sequence.Drain, Self>.View` | **SLAB** | Property.View ergonomic wrapper for consuming iteration |
| `Slab: Sequence.Drain.Protocol` (`drain(_:)` method) | **DELEGATE** | `_buffer.drain(body)` |

#### File: `Slab.Static ~Copyable.swift` (operations on Slab.Static)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var occupancy: Index<Element>.Count` | **DELEGATE** | `_buffer.occupancy.retag(Element.self)` |
| `var isEmpty: Bool` | **DELEGATE** | `_buffer.isEmpty` |
| `var isFull: Bool` | **DELEGATE** | `_buffer.isFull` |
| `func isOccupied(at: Index<Element>.Bounded<wordCount>) -> Bool` | **SLAB** | Converts `Index<Element>.Bounded` to `Bit.Index` via `Index<Element>(index).retag(Bit.self)`. Presents bounded typed index. |
| `func firstVacant() -> Index<Element>.Bounded<wordCount>?` | **SLAB** | Converts `Bit.Index?` to `Index<Element>.Bounded<wordCount>?`. Compile-time bounded return type. |
| `mutating func insert(_:at:) throws(Error)` | **SLAB** | Occupancy guard + typed throw (`.occupied`) + bounded index conversion |
| `mutating func insert(_:__unchecked:)` | **DELEGATE** | Bounded index conversion + buffer insert |
| `mutating func remove(at:) throws(Error) -> Element` | **SLAB** | Occupancy guard + typed throw (`.vacant`) + bounded index conversion |
| `mutating func remove(__unchecked:) -> Element` | **DELEGATE** | Bounded index conversion + buffer remove |
| `mutating func insert(_:) throws(Error) -> Index<Element>.Bounded<wordCount>` | **SLAB** | Composed auto-insert returning bounded typed index |
| `mutating func update(at:with:) throws(Error) -> Element` | **SLAB** | Occupancy guard + typed throw + bounded index conversion |
| `mutating func removeAll()` | **DELEGATE** | `_buffer.removeAll()` |

#### File: `Slab.Indexed ~Copyable.swift` (operations on Slab.Indexed)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `var occupancy: Index<Tag>.Count` | **DELEGATE** | `_base.occupancy.retag(Tag.self)` |
| `var isEmpty: Bool` | **DELEGATE** | `_base.isEmpty` |
| `var isFull: Bool` | **DELEGATE** | `_base.isFull` |
| `func isOccupied(at: Index<Tag>) -> Bool` | **DELEGATE** | `_base.isOccupied(at: index.retag(Element.self))` |
| `func firstVacant() -> Index<Tag>?` | **DELEGATE** | `_base.firstVacant()?.retag(Tag.self)` |
| `mutating func insert(_:at: Index<Tag>) throws(Error)` | **DELEGATE** | `try _base.insert(consume element, at: index.retag(Element.self))` |
| `mutating func insert(_:__unchecked: Index<Tag>)` | **DELEGATE** | `_base.insert(consume element, __unchecked: index.retag(Element.self))` |
| `mutating func remove(at: Index<Tag>) throws(Error) -> Element` | **DELEGATE** | `try _base.remove(at: index.retag(Element.self))` |
| `mutating func remove(__unchecked: Index<Tag>) -> Element` | **DELEGATE** | `_base.remove(__unchecked: index.retag(Element.self))` |
| `mutating func insert(_:) throws(Error) -> Index<Tag>` | **DELEGATE** | `try _base.insert(consume element).retag(Tag.self)` |
| `mutating func update(at:with:) throws(Error) -> Element` | **DELEGATE** | `try _base.update(at: index.retag(Element.self), with: consume element)` |
| `mutating func removeAll()` | **DELEGATE** | `_base.removeAll()` |

Note: `Slab.Indexed` delegates to `Slab` (not directly to buffer). This is the correct two-level wrapping: `Indexed` -> `Slab` -> `Buffer`. The only work `Indexed` does is retagging `Index<Tag>` to `Index<Element>`. This is pure phantom-typing discipline — zero logic, zero overhead.

#### File: `exports.swift` (Slab Primitives Core)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `@_exported public import Index_Primitives` | **SLAB** | Re-exports typed index infrastructure for consumers |
| `@_exported public import Finite_Primitives` | **SLAB** | Re-exports bounded index infrastructure |
| `@_exported public import Property_Primitives` | **SLAB** | Re-exports Property.View for drain |
| `@_exported public import Buffer_Slab_Primitives` | **CONTESTED** | See analysis below |

### Module: Slab Dynamic Primitives

#### File: `Slab Copyable.swift`

| Item | Classification | Rationale |
|------|---------------|-----------|
| `func peek(at: Index<Element>) -> Element?` | **SLAB** | Occupancy-aware non-destructive read. Returns `nil` on vacant. Buffer's `peek` has a precondition (caller must check). Slab wraps with Optional. |

#### File: `Slab.Indexed Copyable.swift`

| Item | Classification | Rationale |
|------|---------------|-----------|
| `func peek(at: Index<Tag>) -> Element?` | **DELEGATE** | `_base.peek(at: index.retag(Element.self))` |
| `var drain: Property<Sequence.Drain, Self>.View` | **SLAB** | Property.View ergonomics for Indexed variant |
| `Slab.Indexed: Sequence.Drain.Protocol` | **DELEGATE** | `_base.drain(body)` |

#### File: `exports.swift` (Slab Dynamic Primitives)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `@_exported public import Slab_Primitives_Core` | **SLAB** | Re-export chain |
| `@_exported public import Collection_Primitives` | **SLAB** | Collection infrastructure |
| `@_exported public import Sequence_Primitives` | **SLAB** | Sequence infrastructure |

### Module: Slab Static Primitives

#### File: `Slab.Static Copyable.swift`

| Item | Classification | Rationale |
|------|---------------|-----------|
| `func peek(at: Index<Element>.Bounded<wordCount>) -> Element?` | **SLAB** | Occupancy-aware non-destructive read with bounded typed index. Returns `nil` on vacant. |
| `var drain: Property<Sequence.Drain, Self>.View` | **SLAB** | Property.View ergonomics for Static variant |
| `Slab.Static: Sequence.Drain.Protocol` | **DELEGATE** | `_buffer.drain(body)` |

#### File: `exports.swift` (Slab Static Primitives)

| Item | Classification | Rationale |
|------|---------------|-----------|
| `@_exported public import Slab_Primitives_Core` | **SLAB** | Re-export chain |
| `@_exported public import Sequence_Primitives` | **SLAB** | Sequence infrastructure |

### Module: Slab Primitives (Umbrella)

#### File: `exports.swift`

| Item | Classification | Rationale |
|------|---------------|-----------|
| `@_exported public import Slab_Primitives_Core` | **SLAB** | Umbrella |
| `@_exported public import Slab_Dynamic_Primitives` | **SLAB** | Umbrella |
| `@_exported public import Slab_Static_Primitives` | **SLAB** | Umbrella |

### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `@_exported public import Buffer_Slab_Primitives` in Core exports | Re-exports the entire buffer slab module to consumers. This means consumers can access `Buffer<Storage<Element>.Heap>.Slab.Bounded`, `Buffer.Slab.Header`, etc. directly. | **CONTESTED** — This is the standard pattern in other primitives packages (array-primitives also re-exports Buffer_Linear_Primitives). The buffer types are infrastructure, but they are needed for advanced use cases and the `_buffer` stored property is `package`-scoped, not `public`. The re-export does not constitute a layering violation; it ensures that consumers who need lower-level access do not need a separate import. However, it means the buffer API surface is technically reachable from `import Slab_Primitives`. This is acceptable given the monorepo structure where buffer and slab are in the same primitives ecosystem. |
| `Slab` wraps `Buffer.Slab.Bounded` but is documented as growable | The existing research document recommends `Slab` should wrap `Buffer.Slab` (growable), but the current implementation wraps `Buffer.Slab.Bounded` (fixed-capacity). | **OBSERVATION** — This is a known design decision from the prior research. The current implementation is the bounded (non-growable) variant. Growth semantics are deferred. No layering violation — just a noted future evolution. |
| `Sequence.Drain.Protocol` conformance exists at BOTH buffer and slab levels | `Buffer.Slab.Bounded: Sequence.Drain.Protocol` AND `Slab: Sequence.Drain.Protocol`. The slab's `drain(_:)` method simply calls `_buffer.drain(body)`. | **MINOR** — Both conformances are valid. The buffer needs drain for its own type. The slab needs drain for its own type. The slab's conformance is a thin wrapper providing type identity at the data structure level. The `drain` *property* (via `Property.View`) is solely slab discipline — it is the ergonomic accessor. |
| `peek` in Slab returns `Element?` while buffer's `peek` returns `Element` | Slab adds an occupancy guard and returns Optional; buffer requires the caller to ensure occupancy via precondition. | **SLAB** — This is a clear slab-discipline decision: safe access with Optional return. The occupancy awareness is the slab's contribution. |
| `isOccupied(at:)` / `firstVacant()` delegation pattern | These are thin wrappers that add only a `.retag()`. The buffer already exposes `isOccupied` and `firstVacant`. | **DELEGATE** — Correctly placed. The retag is the slab's typed-index contribution. The occupancy logic belongs to the buffer (bitmap operations). The slab's job is to present this in the `Index<Element>` domain. |
| Tests reference old API (`capacity:` init, `initialize`, `deinitialize`, `withUnsafePointer`) | The test file (`Slab Tests.swift`) references an older API that no longer matches the current implementation. | **OBSERVATION** — The tests appear to be from a pre-refactoring era. They reference `init(capacity:)` (not `init(minimumCapacity:)`), `initialize`/`deinitialize` (not `insert`/`remove`), and `withUnsafePointer` (not in current API). This is a test maintenance issue, not a layering concern. |

### What is MISSING from Slab (things that are solely slab discipline but not yet present)

| Missing | Category | Priority | Rationale |
|---------|----------|----------|-----------|
| `Equatable where Element: Equatable` | Algebraic | Medium | Two slabs with same occupied slots and same elements should be equal, regardless of capacity or vacant-slot layout. This is slab discipline because capacity-independent equality is a semantic commitment. |
| `Hashable where Element: Hashable` | Algebraic | Medium | Follows from Equatable. |
| Subscript (`subscript(index: Index<Element>) -> Element { get set }`) | Access | Medium | Non-destructive read/write for Copyable elements. The `peek` method provides read; subscript provides read+write. |
| `Sequence` conformance (iterating occupied `(Index<Element>, Element)` pairs) | Protocol | High | The canonical slab iteration pattern from all prior art (Rust slab, slotmap, generational-arena) yields `(key, value)` pairs. Currently only `drain` (consuming) is available; non-destructive iteration for Copyable elements is missing. |
| `retain(_:)` / `filter(_:)` | Slab operation | Low | In-place filtering by predicate over occupied slots. Present in Rust `slab` and `slotmap`. |
| `compact()` / defragmentation | Slab operation | Low | Close gaps by moving elements to lower indices. Present in Rust `slab`. Would require a callback to notify callers of index changes. |
| `CustomStringConvertible` / `CustomDebugStringConvertible` | Ergonomics | Low | Debug output showing occupied/vacant slot layout. |
| Copy-on-Write | Semantic | Medium | Deferred per prior research. Growable `Slab` with `Storage.Heap` should have CoW for value semantics when `Element: Copyable`. |
| Generational indices | Advanced | Deferred | Generation counting solves the ABA problem but is a different abstraction (arena, not slab). Correctly deferred — would be a separate `Arena` or `Slab.Generational` type. |
| `withElement(at:_:)` for ~Copyable borrowing access | Access | Medium | Borrow an element in-place without ownership transfer. Array provides `withElement(at:_:)` for ~Copyable elements. |
| `capacity: Index<Element>.Count` | Query | High | Current implementation does not expose capacity at the slab level. Buffer has it; slab should surface it. |
| `Slab.Static.Indexed<Tag>` variant | Variant | Low | Phantom-typed inline slab. Deferred per prior research. |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: slab-primitives is well-layered

The current `slab-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Slab-discipline semantics** — typed errors, composed operations, typed indices, variant taxonomy, occupancy-aware safe access
2. **Pure delegation** — thin wrappers with retag and/or occupancy guard added

### Specific Findings

#### 1. No buffer concerns have leaked upward

The audit found **zero instances** of slab-primitives doing work that properly belongs to the buffer layer. All bitmap manipulation, element lifecycle management, storage allocation, and contiguous-memory operations are handled by `Buffer.Slab` variants. The slab's `_buffer` stored property is correctly `package`-scoped, preventing consumers from reaching into the buffer layer.

#### 2. The slab layer adds exactly the right semantics

The slab layer's contributions are precisely the things that distinguish a **data structure** from a **buffer**:

- **Typed throws** instead of preconditions (`.full`, `.vacant`, `.occupied`).
- **Composed auto-insert** (`firstVacant()` + `insert(_:at:)` as an atomic operation).
- **Occupancy-aware safe access** (`peek` returns `Element?`, not `Element`).
- **Typed indices** (`Index<Element>`, `Index<Tag>`, `Index<Element>.Bounded<wordCount>`).
- **Consumer namespace** (`Slab`, `Slab.Static`, `Slab.Indexed`).
- **Conditional conformances** (`Sendable`).
- **Property.View ergonomics** (`drain` property).

#### 3. The Indexed variant is correctly implemented

`Slab.Indexed<Tag>` wraps `Slab<Element>` (not `Buffer` directly), creating a clean two-level delegation: `Indexed` -> `Slab` -> `Buffer`. Every method in `Indexed` does exactly one thing: retag the index from `Index<Tag>` to `Index<Element>` and delegate. This is the textbook phantom-type wrapper pattern — zero logic, zero overhead, full type safety.

#### 4. The Static variant correctly adds bounded index types

`Slab.Static` uses `Index<Element>.Bounded<wordCount>` as its index type, which is a compile-time bounded index. This is a stronger type guarantee than the base `Slab` (which uses unbounded `Index<Element>`). The conversion to `Bit.Index` involves an intermediate `Index<Element>(index)` step followed by `.retag(Bit.self)` — correct and zero-cost.

#### 5. Tests need updating

The test file (`Slab Tests.swift`) references an older API surface (`init(capacity:)`, `initialize`/`deinitialize`, `withUnsafePointer`/`withUnsafeMutablePointer`) that does not match the current implementation. This is a maintenance issue, not a layering concern.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure slab discipline | 20+ distinct APIs | Correctly placed |
| Pure delegation | 25+ passthrough properties/methods | Correctly placed — thin wrapping with retag is the design intent |
| Buffer concern leaked into slab | **0** | Clean separation |
| Contested | 1 item (buffer re-export in exports.swift) | Acceptable — follows established pattern |
| Slab concern missing | 8-12 items | Future work, not a layering violation |

### Recommendations

#### 1. Add `Sequence` conformance for Copyable elements (High Priority)

Iterating `(Index<Element>, Element)` pairs over occupied slots is the canonical slab iteration pattern from every prior art source. Currently only consuming iteration (`drain`) is available. Non-destructive iteration is a core slab-discipline concern.

#### 2. Add `capacity` property (High Priority)

The buffer tracks capacity; the slab should expose it as `capacity: Index<Element>.Count`. This is the most basic query after `occupancy`, `isEmpty`, and `isFull`.

#### 3. Add `Equatable` / `Hashable` (Medium Priority)

Capacity-independent, occupancy-aware equality (two slabs are equal if they have the same occupied slots with the same elements at the same indices) is a slab-discipline semantic commitment.

#### 4. Add subscript access for Copyable elements (Medium Priority)

`subscript(index: Index<Element>) -> Element { get set }` for non-destructive read/write. The `peek` method provides read-only access; a subscript provides the standard Swift accessor pattern.

#### 5. Add `withElement(at:_:)` for ~Copyable borrowing (Medium Priority)

For ~Copyable elements, subscript access is unavailable. A borrowing closure-based accessor (`withElement(at: Index<Element>, _ body: (borrowing Element) -> R) -> R`) is the standard pattern used by Array.

#### 6. Update tests (High Priority)

The test file references a pre-refactoring API. Tests should be updated to match the current implementation surface.

#### 7. Generational indices are correctly deferred

The prior art survey confirms that generational indices (slotmap, generational-arena) are a **separate abstraction** from basic slab semantics. A slab provides stable indices with occupancy tracking; an arena adds generation counting for ABA prevention. This is correctly treated as a different type (future `Arena` or `Slab.Generational`), not something that should be added to the base `Slab`.

---

## References

- Bonwick, J. (1994). ["The Slab Allocator: An Object-Caching Kernel Memory Allocator."](https://people.eecs.berkeley.edu/~kubitron/courses/cs194-24-S14/hand-outs/bonwick_slab.pdf) *Proc. USENIX Summer 1994*.
- [Slab allocation](https://en.wikipedia.org/wiki/Slab_allocation) — Wikipedia.
- [tokio-rs/slab](https://docs.rs/slab/latest/slab/struct.Slab.html) — Rust `slab` crate API documentation.
- [SlotMap](https://docs.rs/slotmap/latest/slotmap/struct.SlotMap.html) — Rust `slotmap` crate API documentation.
- [generational-arena](https://github.com/fitzgen/generational-arena) — Safe arena allocator with generational indices.
- [Generational indices guide](https://lucassardois.medium.com/generational-indices-guide-8e3c5f7fd594) — Lucas Sardois, Medium.
- [Slotmap: The budget allocator](https://electrp.com/posts/slotmap/) — slotmap design explanation.
- [Arenas in Rust](https://manishearth.github.io/blog/2021/03/15/arenas-in-rust/) — Manish Goregaokar, arena design patterns.
- West, C. (2018). "Using Rust for Game Development." RustConf 2018.
- Liskov, B. & Guttag, J. (1986). *Abstraction and Specification in Program Development*. ADT axioms.
- Nystrom, R. (2014). *Game Programming Patterns*, Chapter 19: "Object Pool."
- `/Users/coen/Developer/swift-primitives/swift-slab-primitives/Research/slab-primitives-design-variants-module-architecture.md`
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Slab Primitives/` — Buffer.Slab implementation files.
