# Linked List Layered Architecture

<!--
---
version: 2.0.0
last_updated: 2026-02-10
status: DECISION
research_tier: 2
applies_to: [swift-list-primitives, swift-storage-primitives, swift-buffer-primitives]
normative: false
---
-->

## Context

List.Linked currently hand-rolls its own ManagedBuffer/Header/Node/Storage, duplicating patterns that other data structures (Queue, Stack, Deque, HashTable) solve through the canonical layered stack:

```
Data Structure (List, Queue, Stack, ...)
        |
Buffer (Ring, Linear, Slab, ...)
        |
Storage (Heap, Inline, Split, ...)
        |
Memory (Arena, Pool, Address, ...)
```

The attempt to split list-primitives into Core + Linked modules exposed a cross-module partial consumption error on `Node` — the compiler rejects `(nodes + index).move().element` across module boundaries for non-frozen `~Copyable` structs. Rather than patching this with `@frozen` or helpers, this is an architectural signal: the element lifecycle operations belong in a Storage-tier type, not hand-rolled in the data structure.

### Prior Research (Internal)

- **storage-primitives-comparative-analysis.md** (REC-001, REC-002): Recommends `Storage.Arena` and `Storage.Pool` at Tier 14 as HIGH priority additions.
- **split-storage-design.md**: Designs `Storage<Element>.Split<Lane>` for dual-lane storage (metadata + payload). Field-handle-based access to co-located heterogeneous arrays.
- **Buffer.Slab**: Existing pattern for bitmap-tracked sparse slot storage over `Storage.Heap`.

## Question

What Storage and Buffer equivalents are needed for linked list structures, following the `memory <- storage <- buffer <- data structure` layered architecture?

---

## Part I: Prior Art Survey

### 1.1 Foundational Allocation Theory

#### 1.1.1 The Slab Allocator (Bonwick, USENIX 1994)

Bonwick's slab allocator introduced the principle of **type-segregated allocation**: objects of a given type are grouped into dedicated caches, each cache containing fixed-size slabs, each slab containing fixed-size buffers (Bonwick, 1994). The key innovations:

1. **Object caching**: Retaining constructed state between allocations, amortizing expensive initialization.
2. **Coloring**: Offsetting objects within slabs to prevent hardware cache aliasing.
3. **Separation of allocation from construction**: The allocator manages memory; the caller manages object state.

This separation principle directly informs our layered architecture: Memory.Pool handles allocation (Bonwick's "cache"), Storage handles typed lifecycle (Bonwick's "construction"), and Buffer manages the data structure's logical state.

Bonwick's design evolved into SLUB (Christoph Lameter, 2007) for Linux, which eliminated per-slab metadata queues, and SLOB for memory-constrained embedded systems.

#### 1.1.2 Free-List Pool Allocators

The in-band free-list technique — storing the "next free" pointer in the memory of freed slots — is a classical O(1) allocation strategy that appears independently in multiple contexts:

- **Kernel slab allocators** store free-list pointers within freed object slots (Bonwick, 1994).
- **Game engine object pools** use a union overlaying live object data with a free-list pointer (Nystrom, 2014). The key constraint: each slot must be large enough to hold the free-list pointer (`sizeof(Node*) <= sizeof(Element)`).
- **Memory.Pool** in swift-memory-primitives implements this pattern with `Bit.Vector` double-free detection, typed `Index<Slot>` addressing, and `Affine.Discrete.Ratio<Slot, Memory>` stride-aligned access.

The O(1) property is critical for linked lists where every insert and remove requires one allocation and one deallocation respectively. Bitmap-scan allocation (as in Buffer.Slab) is O(n/64) amortized — adequate for sparse access patterns but suboptimal for linked list workloads with high allocation throughput.

#### 1.1.3 Arena Allocators

Arena (bump/region) allocators provide O(1) allocation with batch deallocation (no individual free). Tofte and Talpin (1994, 1997) formalized region-based memory management for ML, where each region is implemented as a linked list of large blocks. The key insight:

> "Although it required many operations to construct the linked list, it can be destroyed quickly in a single operation by destroying the region in which the nodes were allocated."

Fleury (2021) provides a modern systems-programming perspective: arenas spread allocation across a variably-sized linked list of large blocks, with 3-5x performance improvement for workloads requiring many small allocations like binary trees or linked lists.

However, arena semantics (no individual deallocation) do not match linked list needs. Lists require per-node allocation and deallocation for O(1) insert/remove. **Conclusion**: Memory.Pool (not Memory.Arena) is the correct memory-layer foundation for linked lists.

**Exception**: Append-only linked structures (e.g., log-structured lists) where elements are never individually removed could use arena allocation. This is a specialized variant, not the general case.

### 1.2 Linked List Storage Strategies

#### 1.2.1 Arena-Based (Index-Linked) Lists

The pattern of storing linked list nodes in a contiguous array, linked by index rather than pointer, appears across multiple domains:

**Rust ECS / Generational Arenas**: The `generational-arena` crate (Fitzgerald, inspired by West's RustConf 2018 keynote) stores nodes in a `Vec` with generational indices to solve the ABA problem. The `slotmap` crate extends this with compact hop-representation for faster iteration in the presence of holes. The typed-generational-arena crate adds phantom-typed keys, directly analogous to our `Index<Node>`.

**Ferrous Systems Dancing Links (2022)**: Implements Knuth's Dancing Links (DLX) algorithm in Rust using arena-allocated nodes with index-based linking. The key insight for ownership-constrained languages:

> "Rather than using references, arena allocation stores all nodes in a contiguous Vec. This sidesteps the ownership problem by centralizing mutable access through a single container."

This is precisely the pattern List.Linked already uses — and the pattern that must be preserved through the layered architecture.

**Knuth's Dancing Links (2000)**: Uses a sparse doubly-linked matrix where removed nodes retain their link information, enabling O(1) restoration during backtracking. The critical property: removed but not deallocated nodes still know their neighbors. In pool-based storage, this means a node's links must be preserved (or extractable) before deallocation — which List.Linked's `_moveAllElements` linearization already handles.

#### 1.2.2 Intrusive Linked Lists

The Linux kernel uses intrusive linked lists (`struct list_head`) extensively: the link metadata is embedded in the data structure rather than wrapping it. The `container_of` macro recovers the enclosing struct from a `list_head` pointer.

**Relevance**: List.Linked's `Node` bundles `element + links` — it is **extrusive** (links wrap the element). The alternative — storing links separately from elements — corresponds to our Option C (split storage). Intrusive lists avoid the dual-allocation problem but sacrifice generality: the data type must be designed to participate in a list.

For a generic `List<Element>` where `Element` is user-defined and `~Copyable`, intrusive linking is not an option. The extrusive `Node` pattern is the correct choice, and the layered architecture must accommodate it.

#### 1.2.3 Unrolled Linked Lists

Shao, Reppy, and Appel (1994) introduced unrolled linked lists: each node stores K elements (typically filling a cache line) with a single link pointer. This reduces:
- Memory overhead: one pointer per K elements instead of one per element.
- Cache misses: K elements per cache line load instead of one.

Empirical results show up to 3x performance improvement for iteration-heavy workloads, with theoretical O(n/K) cache misses for traversal versus O(n) for standard linked lists (cf. Shao et al., LFP 1994).

**Relevance**: An unrolled variant could be expressed as `Buffer.Linked<N, K>` where K is the unroll factor. The storage layer would manage blocks of K elements rather than individual nodes. This is a future extension — the current design focuses on the single-element-per-node case (K=1), which is the canonical linked list.

### 1.3 Cache Performance of Linked Structures

#### 1.3.1 The Cache-Oblivious Model

Frigo, Leiserson, Prokop, and Ramachandran (1999) introduced the ideal-cache model and cache-oblivious algorithms. Prokop's van Emde Boas layout guarantees O(log_B N) cache misses for tree traversal, where B is the cache line size.

For linked lists specifically: standard pointer-chasing traversal incurs one cache miss per node in the worst case (O(n) misses). Arena-based storage improves this by co-locating nodes in contiguous memory, achieving O(n/B) misses when nodes are allocated sequentially (Demaine, 2002).

**Critical distinction**: Cache performance of arena-based linked lists depends on **allocation order** relative to **traversal order**. If nodes are allocated in traversal order (e.g., append-only list), cache performance matches arrays. If nodes are allocated in arbitrary order with interleaved inserts and deletes, cache performance degrades toward the pointer-chasing worst case.

List.Linked's `_moveAllElements(to:)` linearization during growth restores optimal cache layout by compacting nodes in traversal order. This is analogous to defragmentation — the pool may have holes from deleted nodes, and growth is an opportunity to compact.

#### 1.3.2 Empirical Cache Analysis

Drepper's "What Every Programmer Should Know About Memory" (2007) quantifies the cache penalty of pointer-chasing: sequential array access at ~4 cycles/element vs. random pointer-chasing at ~400 cycles/element (100x) on modern hardware with L3 cache misses.

Arena-based lists fall between these extremes. With fresh (non-fragmented) arenas, performance approaches sequential access. After many insert/delete cycles creating fragmentation, performance degrades toward random access. The growth-linearization strategy is essential for maintaining cache performance over time.

### 1.4 Typed Memory Management

#### 1.4.1 Linear and Substructural Type Systems

Girard (1987) introduced linear logic, where the linear implication A ⊸ B consumes its input exactly once. Wadler (1990) demonstrated the programming-language interpretation: "Linear types can change the world" — values that must be used exactly once enable safe memory management without garbage collection.

The substructural type system taxonomy (Walker, 2005):

| Type System | Weakening (drop) | Contraction (copy) | Use Count |
|-------------|-------------------|--------------------|-----------|
| Unrestricted | Yes | Yes | Any |
| Affine | Yes | No | ≤ 1 |
| Linear | No | No | = 1 |
| Ordered | No (+ no exchange) | No | = 1, in order |

Swift's `~Copyable` implements **affine semantics**: values can be consumed (moved) or dropped, but not copied. This is the foundation for safe memory management of linked list nodes — each node is consumed exactly zero or one times, with the storage layer managing the lifecycle.

#### 1.4.2 Typed Capabilities for Memory Access

Crary, Walker, and Morrisett (1999) introduced the Capability Calculus: a compiler intermediate language where region-based memory management is governed by **static capabilities** — typed permissions that control memory access and deallocation.

**Direct relevance**: `Index<Node>` in our architecture functions as a typed capability — it grants access to a specific physical slot in storage. The phantom type parameter constrains which storage instance the index can be used with. This is an informal, partial realization of the formal capability calculus.

#### 1.4.3 Linear Regions (Fluet, Morrisett, Ahmed, ESOP 2006)

The λ_rgnUL calculus showed that a single substructural type system can encode both Tofte-Talpin lexically-scoped regions and Cyclone's dynamic regions using linear capabilities. The key insight: region lifetime is controlled by a **linear capability token** that must be consumed to deallocate the region.

**Relevance**: Storage.Heap's ARC-managed lifetime is analogous to a shared capability (multiple references, deallocated when all references drop). Storage.Pool's slot-level allocation/deallocation is analogous to individual capability tokens per slot. The affine `~Copyable` constraint on our Node type ensures each node is consumed at most once — matching the affine fragment of λ_rgnUL.

#### 1.4.4 Region-Based Memory Management in Cyclone (Grossman et al., PLDI 2002)

Cyclone extended C with region-based memory management including unique pointers (guaranteed sole reference, explicit deallocation with flow analysis preventing dangling dereferences), region subtyping, and integration with stack allocation.

**Relevance**: Cyclone's unique pointers are the closest prior-art equivalent to Swift's `consuming` ownership transfer. The storage layer's `move(at:)` operation corresponds to Cyclone's explicit deallocation of a unique pointer — the caller takes ownership, and the storage slot becomes uninitialized.

### 1.5 Formal Verification of Allocators

#### 1.5.1 Verified Sequential Malloc/Free (Appel & Naumann, ISMM 2020)

Appel and Naumann verified a segregated free-list malloc/free system using the Verified Software Toolchain (VST) in Coq, with separation logic specifications over CompCert's Clight semantics. Key results:

1. **Resource-aware specification**: Guarantees when malloc will successfully return a block (unlike POSIX which allows arbitrary NULL returns).
2. **Free-list invariant**: Each free list is well-formed (acyclic, all blocks properly sized, no overlap with allocated blocks).
3. **Separation property**: The separating conjunction P * Q proves that the free list and allocated memory are disjoint heap regions.

**Relevance**: The free-list invariant proven by Appel is precisely the invariant that Memory.Pool's `_checkInvariants()` asserts at runtime in debug builds. A formal verification of Memory.Pool's free-list would follow the same separation logic structure.

#### 1.5.2 StarMalloc (Reitz, Fromherz, Protzenko, OOPSLA 2024)

StarMalloc is a verified, concurrent, security-hardened allocator built on the Steel separation logic framework. Its layered architecture is directly analogous to our design:

> "Separating into different composable abstractions enables modular verification where each component can be verified in isolation."

StarMalloc's layers: operating system interface → slab management → size-class dispatch → user-facing API. Changes to upper layers remain entirely unchanged when lower layers are modified — the same principle that drives our Memory → Storage → Buffer → Data Structure separation.

**Relevance**: StarMalloc validates that layered allocator architectures are amenable to formal verification. If swift-primitives ever pursues formal verification (cf. GAP-005 in comparative analysis), the layered architecture provides natural verification boundaries.

#### 1.5.3 RustBelt (Jung et al., POPL 2018)

RustBelt provides machine-checked safety proofs for Rust's type system using Iris, a higher-order concurrent separation logic framework in Coq. The key innovation: a **lifetime logic** with borrow propositions that mirrors Rust's borrowing mechanism.

**Relevance**: Swift's `~Copyable` and `borrowing`/`consuming` annotations are structurally analogous to Rust's ownership model. A future "SwiftBelt" could verify that storage operations maintain the invariant that initialized slots contain valid elements and uninitialized slots are in the free list — the same separation property that RustBelt proves for Rust's `Vec<T>`.

### 1.6 Modern Allocator Architectures

These systems validate specific design patterns in our architecture:

| Allocator | Architecture | Relevant Pattern |
|-----------|-------------|------------------|
| **mimalloc** (Leijen et al., 2019) | Per-page free-list sharding, 3 sharded free lists per page | Free-list locality — nodes allocated from the same page have better cache behavior |
| **jemalloc** (Evans, 2006) | Arena → Bin → Slab → Run, 4 sizes per doubling | Type-segregated allocation into fixed-size bins — same principle as `Storage.Pool<Node>` |
| **TCMalloc** (Google, 2021) | Per-CPU cache → Transfer cache → Page heap, hugepage-aware | Hierarchical caching — relevant if Storage.Pool adds thread-local allocation caches |
| **snmalloc** (Liétar et al., ISMM 2019) | Message-passing cross-thread deallocation | Relevant for concurrent linked lists (future extension) |
| **Mesh** (Powers et al., PLDI 2019) | Virtual memory remapping for compaction without relocation | List.Linked's growth-linearization is a simplified form of compaction (with relocation) |

### 1.7 The Rust Store RFC (RFC 3446, Draft)

Matthieu-m's Store RFC introduces an abstract `Handle` type to replace raw pointers in Rust collections:

```rust
unsafe trait StoreSingle: StoreDangling {
    type Handle;
    fn allocate(&mut self, layout: Layout) -> Result<(Self::Handle, usize), AllocError>;
    unsafe fn resolve(&self, handle: Self::Handle) -> NonNull<u8>;
    unsafe fn deallocate(&mut self, handle: Self::Handle, layout: Layout);
}
```

Handle can be a pointer (heap), `()` (inline single-element), an offset (shared memory), or an index (arena). Collections parameterize over `S: StoreSingle`.

**Status**: After 2+ years of design iteration, the RFC remains pre-RFC. The trait hierarchy complexity (`StoreSingle`, `StoreMultiple`, `StoreStable`, `StorePinning`) demonstrates that unifying storage behind a single protocol is genuinely hard.

**Implication for Swift Primitives**: The comparative analysis already rejected a `Storage.Protocol` approach (§8.3) in favor of the variant system. The Store RFC's ongoing difficulty validates this decision. Our architecture achieves composability through the variant catalog (Heap, Inline, Pool) rather than trait-based parameterization.

---

## Part II: Analysis

### 2.1 Current List.Linked Internals

List.Linked currently manages four concerns in one monolithic ManagedBuffer:

| Concern | Current Implementation | Canonical Layer |
|---------|----------------------|-----------------|
| **Memory allocation** | `ManagedBuffer<Header, Node>.create(minimumCapacity:)` | Memory |
| **Free-list management** | `_storeFreeNext(at:next:)`, `_loadFreeNext(at:)`, `_allocateSlot()` | Memory (Pool) |
| **Element lifecycle** | `_initializeNode(at:element:links:)`, `_deinitializeNode(at:)`, `deinit` traversal | Storage |
| **Node link management** | `Node.nextIndex`, `Node.prevIndex`, link rewiring in insert/remove | Buffer |
| **Head/tail/count tracking** | `Header.head`, `Header.tail`, `Header.count` | Buffer |
| **Growth policy** | `ensureCapacity()`, `_moveAllElements(to:)` | Buffer |
| **Public API** | `prepend(_:)`, `append(_:)`, `popFirst()`, `popLast()` | Data Structure |
| **CoW** | `makeUnique()`, `isKnownUniquelyReferenced` | Data Structure |

### 2.2 What Exists at Each Layer

#### Memory Layer (Tier 13)

**Memory.Pool** already provides exactly the allocation pattern List.Linked needs:

| Memory.Pool Feature | List.Linked Equivalent |
|--------------------|-----------------------|
| Fixed-slot O(1) allocation via free list | `_allocateSlot()` |
| O(1) deallocation via free list push | Free-list push in `popFirst`/`popLast` |
| In-band free-list storage (raw bytes in freed slots) | `_storeFreeNext(at:next:)` / `_loadFreeNext(at:)` |
| BitVector double-free detection | Not currently present in List.Linked |
| `pointer(at: Index<Slot>)` typed access | `_nodesPointer + index` |

**Memory.Arena** provides bulk allocation but Arena semantics (no individual deallocation, batch reset only) don't match linked list needs (§1.1.3).

**Conclusion**: Memory.Pool is the correct memory-layer foundation for linked lists.

#### Storage Layer (Tier 14)

**Storage.Pool does not yet exist.** The comparative analysis recommends it (REC-002).

For linked lists, the storage layer must provide **typed element lifecycle over a pool allocator**:

| Operation | Semantics |
|-----------|-----------|
| `insert(element, at: slot)` | Initialize element at pool slot |
| `remove(at: slot) -> Element` | Move element out, return it |
| `deinitialize(at: slot)` | Destroy element without returning |
| `pointer(at: slot)` | Typed pointer access |
| `[slot]` subscript | Read/write for Copyable elements |

This maps directly to the Buffer.Slab pattern, where:
- `Buffer.Slab.insert(element, at:, header:, storage:)` = `storage.initialize(to:at:)` + `header.bitmap[slot] = true`
- `Buffer.Slab.remove(at:, header:, storage:)` = `storage.move(at:)` + `header.bitmap[slot] = false`

But linked lists have a wrinkle: **each node stores both an element AND link metadata**. The element is `~Copyable`, but the links (`InlineArray<N, Int>`) are always `Copyable`.

### 2.3 The Split Storage Question

List.Linked's `Node` bundles `element: Element` and `links: InlineArray<N, Int>` into one struct. This creates the cross-module partial consumption problem — you can't `move().element` across modules on a non-frozen struct.

Three storage approaches:

#### Option A: Storage with Node as Compound Element Type

Store `Node` as the element type in storage: `Storage<Node>.Heap`.

```swift
var storage: Storage<Node>.Heap   // where Node has element + links
```

**Pro**: Simple, matches current architecture and Buffer.Slab pattern. Best cache locality (element and links co-located, as in intrusive list design).
**Con**: Still bundles element and links. The cross-module partial consume issue remains if callers try to partially consume Node as a value. However, `storage.pointer(at:).pointee.element` works — `UnsafeMutablePointer` access doesn't trigger ownership checking.

**Key insight from Ferrous Systems DLX**: Arena-based linked structures in Rust solve the ownership problem by centralizing mutable access through a single container. `pointer(at:)` is our equivalent — it provides a stable reference without triggering the borrow checker / ownership system.

#### Option B: Storage.Split with Separate Lanes

Use `Storage<Element>.Split<InlineArray<N, Int>>` for separate element and link arrays:

```swift
var storage: Storage<Element>.Split<InlineArray<N, Int>>
storage.pointer(storage.elementField, at: slot)     // element access
storage[storage.laneField, at: slot]                 // link access (Copyable subscript)
```

**Pro**: Clean separation. No partial consumption issue. Links always Copyable.
**Con**: Storage.Split doesn't exist yet. Two-lane layout adds complexity. Not clear this generality is needed when pointer-based access to compound Node works fine.

#### Option C: Separate Element Pool + Link Array

Two separate storage regions:

```swift
var elementPool: Storage<Element>.Heap
var links: ManagedBuffer<_, InlineArray<N, Int>>
```

**Pro**: Element lifecycle cleanly separated from link management.
**Con**: Two allocations, worse cache locality (element and its links on different cache lines). This is the opposite of the intrusive linked list insight (§1.2.2) — separating links from data *hurts* performance.

#### Evaluation

| Criterion | Option A (Compound Node) | Option B (Split) | Option C (Separate) |
|-----------|-------------------------|-------------------|---------------------|
| Implementation complexity | Low | High (Split doesn't exist) | Medium |
| Cross-module safety | Safe via `pointer(at:)` | Safe by design | Safe by separation |
| Memory locality | Best (co-located) | Good (same allocation) | Worst (two allocations) |
| Cache performance (§1.3) | Best | Good | Worst |
| Dependency cost | None (existing Storage.Heap) | Storage.Split (new) | Custom link storage |
| Matches Buffer.Slab pattern | Yes | Partially | No |

**Recommendation**: **Option A** — `Storage<Node>.Heap` where Node bundles element + links, with element access via `pointer(at:).pointee`. This matches Buffer.Slab, has best cache locality (validated by intrusive list literature §1.2.2), and requires no new Storage types.

### 2.4 Buffer Layer Design

The Buffer layer manages **positional tracking** (head/tail/count) and **growth policy** over Storage. For linked lists:

| Buffer.Ring Responsibility | Buffer.Linked Equivalent |
|---------------------------|-------------------------|
| Head/tail cyclic positions | Head/tail node indices (`Index<Node>?`) |
| Count tracking | Count tracking (`Index<Element>.Count`) |
| Wrap-around arithmetic | Link following (`pointer(at:).pointee.links[0]`) |
| Growth (resize + copy) | Growth (new storage + move + relink) |
| Storage.Initialization maintenance | Free-list management |

A `Buffer<Element>.Linked<let N: Int>` type would provide:

```
Buffer.Linked<N>
  - header: Header (head, tail, count, freeHead)
  - storage: Storage<Node>.Heap

  Static Operations:
  - insertFront(element:, header:, storage:) -> allocate slot, link head, update head
  - insertBack(element:, header:, storage:) -> allocate slot, link tail, update tail
  - removeFront(header:, storage:) -> unlink head, deallocate slot, return element
  - removeBack(header:, storage:) -> unlink tail, deallocate slot, return element
  - grow(minimumCapacity:, header:, storage:) -> new storage, move all, relink
  - forEach(header:, storage:, body:) -> traverse from head following links
```

#### Free-List at the Buffer Layer

Buffer.Slab manages slot occupancy via `Bit.Vector` in its header. Buffer.Linked manages it via a **free list** in the buffer header + in-band storage in freed Node slots. The free-list pattern provides O(1) allocation (vs. O(n/64) bitmap scan), which is critical for linked list workloads (§1.1.2).

The free-list is stored **in-band**: after `storage.move(at: slot)` (which deinitializes the Node), the freed slot's raw memory is reused to store the next-free index. This is the same Bonwick in-band technique (§1.1.1), Nystrom's union trick (§1.1.2), and exactly what the current implementation does.

### 2.5 The Growth Problem

Currently, List.Linked's `ensureCapacity` creates a new ManagedBuffer, then `_moveAllElements(to:)` linearizes the list (traverses links, moves each Node to contiguous slots 0..count-1, rewires links to be sequential).

This linearization is a form of **compaction** (§1.6, cf. Mesh): it eliminates fragmentation by placing nodes in traversal order, restoring optimal cache performance (§1.3.1). Unlike Mesh's virtual-memory remapping, this is a physical copy — acceptable because growth is amortized O(1).

With the layered architecture, growth becomes:

1. Create new `Storage<Node>.Heap` with larger capacity
2. Traverse old storage following links from head
3. For each node: allocate sequential slot in new storage, move element via `storage.pointer(at:)`, create new links for linearized order
4. Update header to point to new storage
5. Old storage destroyed (ARC deallocation)

This is exactly what `_moveAllElements(to:)` does today, factored through the Storage API.

### 2.6 Does Storage.Pool Fit?

Memory.Pool is **fixed-capacity** — it has N slots and cannot grow. But `List.Linked` (the dynamic variant) needs to grow. Two paths:

#### Path 1: Fixed Storage + Growth at Buffer Layer

Buffer.Linked manages growth by creating a new, larger Storage and moving elements. Storage itself is fixed-size once created. This matches how Buffer.Ring works: `Storage.Heap` is fixed-size, and `Buffer.Ring.grow()` creates a new `Storage.Heap` and moves elements.

#### Path 2: Storage.Heap with Buffer-Level Free List

Use existing `Storage<Node>.Heap` for element lifecycle. Buffer header includes a free-list head index. Free-list next pointers stored in raw bytes of freed Node slots (using the same `_loadFreeNext`/`_storeFreeNext` pattern).

| Criterion | Path 1 (Storage.Pool + Buffer growth) | Path 2 (Storage.Heap + Buffer free list) |
|-----------|---------------------------------------|------------------------------------------|
| Matches existing patterns | Yes (Buffer.Ring does this) | Yes (Buffer.Slab manages occupancy) |
| Separation of concerns | Clean (pool = fixed, buffer = growth) | Clean (storage = lifecycle, buffer = occupancy) |
| Reuse by other packages | Storage.Pool usable by hash tables too | Free-list pattern specific to Buffer.Linked |
| Dependency on new types | Needs Storage.Pool first | Uses existing Storage.Heap |
| Implementation complexity | Higher (3 packages) | Lower (2 packages) |

**Recommendation**: **Path 2** — use existing `Storage<Node>.Heap` with buffer-level free-list management. This follows the Buffer.Slab precedent (buffer manages which slots are in use, storage manages element lifecycle), uses existing infrastructure, and doesn't block on Storage.Pool.

When Storage.Pool is eventually built (for hash tables and other consumers), Buffer.Linked's free-list logic can be extracted and delegated to it.

### 2.7 Variant Mapping

| Current Variant | Layered Equivalent | Storage | Notes |
|----------------|--------------------|---------|-------|
| `List.Linked<N>` | `Buffer.Linked<N>` over `Storage<Node>.Heap` | Growable, ARC, CoW | Dynamic capacity |
| `List.Linked<N>.Bounded` | `Buffer.Linked<N>.Bounded` over `Storage<Node>.Heap` | Fixed capacity | Throws on overflow |
| `List.Linked<N>.Inline` | `Buffer.Linked<N>.Inline` over `Storage<Node>.Inline` | Stack-allocated | ~Copyable supported |
| `List.Linked<N>.Small` | `Buffer.Linked<N>.Small` | Inline + heap hybrid | ~Copyable supported |

---

## Part III: Architecture

### 3.1 Proposed Stack

```
List<Element>.Linked<N>                    (swift-list-primitives)
    Public API: prepend, append, popFirst, popLast, CoW
    Stores: Buffer<Element>.Linked<N>
        |
Buffer<Element>.Linked<N>                  (swift-buffer-primitives)
    Header: head, tail, count, freeHead
    Node: ~Copyable struct { element: Element, links: InlineArray<N, Int> }
    Static ops: insertFront, insertBack, removeFront, removeBack, grow
    Free-list management: in-band raw byte storage in freed Node slots
    Stores: Storage<Buffer<Element>.Linked<N>.Node>.Heap
        |
Storage<Node>.Heap                         (swift-storage-primitives)
    Element lifecycle: initialize, move, deinitialize, pointer(at:)
    ManagedBuffer-based, ARC, CoW-ready
        |
UnsafeMutablePointer<Node>                 (Swift stdlib)
```

### 3.2 Node Declaration

Per [PATTERN-022] (~Copyable constraint poisoning), Node must be declared in the same file as `Buffer.Linked` because it references the `~Copyable` Element parameter:

```swift
extension Buffer where Element: ~Copyable {
    public struct Linked<let N: Int>: ~Copyable {
        @usableFromInline
        package struct Node: ~Copyable {
            @usableFromInline package var element: Element
            @usableFromInline package var links: InlineArray<N, Int>
        }

        @usableFromInline
        package struct Header {
            @usableFromInline package var head: Index<Node>?
            @usableFromInline package var tail: Index<Node>?
            @usableFromInline package var freeHead: Index<Node>?
            @usableFromInline package var count: Index<Element>.Count
        }

        @usableFromInline package var header: Header
        @usableFromInline package var storage: Storage<Node>.Heap
    }
}
```

### 3.3 What Needs to Be Built

| # | Type | Layer | Package | Description |
|---|------|-------|---------|-------------|
| 1 | `Buffer<Element>.Linked<N>` | Buffer (15) | swift-buffer-primitives | Header + Node + static ops. Free-list management in buffer. Growth via storage replacement. |
| 2 | `List<Element>.Linked<N>` rewrite | Data Structure | swift-list-primitives | Thin wrapper. Public API delegates to Buffer.Linked static ops. CoW for Copyable. |

No new types needed in swift-storage-primitives or swift-memory-primitives.

---

## Part IV: Open Questions

1. **Index domain**: Buffer operations use `Index<Node>` for slot addressing (Node is the storage element type). The data structure layer exposes `Index<Element>.Count` for count/capacity (users don't see Nodes). Conversion at the boundary: `count.retag(Node.self).map(Ordinal.init)` for virgin slot allocation.

2. **Storage.Initialization**: Like Buffer.Slab, `storage.initialization` stays `.empty`. The buffer's free-list is the source of truth. Deinit traverses the linked structure, calling `storage.deinitialize(at:)` for each active node, then sets `storage.initialization = .empty`.

3. **Typed free-list pointers**: After `storage.move(at: slot)`, store `Index<Node>?` as raw bytes. The helpers become:
   ```swift
   func _loadFreeNext(at slot: Index<Node>) -> Index<Node>? { ... }
   func _storeFreeNext(at slot: Index<Node>, next: Index<Node>?) { ... }
   ```

4. **Storage.Pool extraction**: When hash-table-primitives or tree-primitives also need pool-style allocation, extract Buffer.Linked's free-list logic to `Storage.Pool` at Tier 14. This is a refactoring, not a redesign — the API surface would be identical.

5. **Unrolled variant**: An `Unrolled<K>` variant (§1.2.3) storing K elements per node could be added as `Buffer.Linked<N>.Unrolled<K>`. This is a future extension.

---

## Part V: Outcome

**Status**: DECISION

### Decision

Built `Buffer<Element>.Linked<N>` in swift-buffer-primitives using `Storage<Node>.Pool` for element lifecycle and buffer-level free-list management. Rewrote both `List<Element>.Linked<N>` and `Queue<Element>.Linked` as thin wrappers delegating to `Buffer.Linked<N>`.

Implementation details:
- `Buffer<Element>.Linked<1>` (singly-linked) used by `Queue.Linked` and `List.Linked<1>`
- `Buffer<Element>.Linked<2>` (doubly-linked) used by `List.Linked<2>`
- Node uses `InlineArray<N, Index<Node>>` for links — no memory waste for N=1
- Peek/Reversed view types use `Property.View.Read.Typed<Element>.Valued<N>` to avoid ~Copyable constraint poisoning
- `Int` boundary overloads on `create(capacity:)` and `ensureCapacity(_:)` per [IMPL-010]
- All existing tests pass (70 queue tests, list builds clean)

---

## References

### Academic Literature

- Bonwick, J. (1994). The Slab Allocator: An Object-Caching Kernel Memory Allocator. [USENIX Summer 1994 Technical Conference](https://people.eecs.berkeley.edu/~kubitron/courses/cs194-24-S14/hand-outs/bonwick_slab.pdf).
- Tofte, M. & Talpin, J.-P. (1997). [Region-Based Memory Management](https://www.sciencedirect.com/science/article/pii/S0890540196926139). Information and Computation, 132(2), 109-176.
- Grossman, D. et al. (2002). [Region-based Memory Management in Cyclone](https://dl.acm.org/doi/10.1145/512529.512563). PLDI 2002.
- Fluet, M., Morrisett, G. & Ahmed, A. (2006). [Linear Regions Are All You Need](https://link.springer.com/chapter/10.1007/11693024_2). ESOP 2006.
- Crary, K., Walker, D. & Morrisett, G. (1999). [Typed Memory Management in a Calculus of Capabilities](https://dl.acm.org/doi/10.1145/292540.292564). POPL 1999.
- Walker, D. (2005). Substructural Type Systems. In Advanced Topics in Types and Programming Languages.
- Girard, J.-Y. (1987). Linear Logic. Theoretical Computer Science, 50(1), 1-102.
- Wadler, P. (1990). Linear Types Can Change the World.
- Reynolds, J. C. (2002). Separation Logic: A Logic for Shared Mutable Data Structures. LICS 2002.
- Jung, R. et al. (2018). [RustBelt: Securing the Foundations of the Rust Programming Language](https://dl.acm.org/doi/10.1145/3158154). POPL 2018.
- Appel, A. W. & Naumann, D. A. (2020). [Verified Sequential Malloc/Free](https://dl.acm.org/doi/abs/10.1145/3381898.3397211). ISMM 2020.
- Reitz, A., Fromherz, A. & Protzenko, J. (2024). [StarMalloc: Verifying a Modern, Hardened Memory Allocator](https://dl.acm.org/doi/10.1145/3689773). OOPSLA 2024.
- Shao, Z., Reppy, J. H. & Appel, A. W. (1994). [Unrolling Lists](https://dl.acm.org/doi/10.1145/182590.182453). ACM Conference on LISP and Functional Programming.
- Frigo, M., Leiserson, C. E., Prokop, H. & Ramachandran, S. (1999). Cache-Oblivious Algorithms. FOCS 1999.
- Demaine, E. D. (2002). [Cache-Oblivious Algorithms and Data Structures](https://erikdemaine.org/papers/BRICS2002/paper.pdf). BRICS Lecture Series.
- Knuth, D. E. (2000). [Dancing Links](https://arxiv.org/abs/cs/0011047). arXiv:cs/0011047.

### Modern Allocator Research

- Leijen, D., Zorn, B. & de Moura, L. (2019). [Mimalloc: Free List Sharding in Action](https://www.microsoft.com/en-us/research/publication/mimalloc-free-list-sharding-in-action/). MSR-TR-2019-18.
- Evans, J. (2006). [A Scalable Concurrent malloc(3) Implementation for FreeBSD](https://papers.freebsd.org/2006/bsdcan/evans-jemalloc/). BSDCan 2006.
- Hunter, A. et al. (2021). [Beyond malloc efficiency to fleet efficiency: a hugepage-aware memory allocator](https://www.usenix.org/system/files/osdi21-hunter.pdf). OSDI 2021 (TCMalloc/Temeraire).
- Liétar, P. et al. (2019). [snmalloc: A Message Passing Allocator](https://dl.acm.org/doi/10.1145/3315573.3329980). ISMM 2019.
- Powers, B. et al. (2019). [Mesh: Compacting Memory Management for C/C++ Applications](https://dl.acm.org/doi/10.1145/3314221.3314582). PLDI 2019.

### Industry and Systems

- Nystrom, R. (2014). [Object Pool](https://gameprogrammingpatterns.com/object-pool.html). Game Programming Patterns.
- Fleury, R. (2021). [Untangling Lifetimes: The Arena Allocator](https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator).
- Matklad (2022). [Dancing Links in Rust](https://ferrous-systems.com/blog/dlx-in-rust/). Ferrous Systems.
- West, C. (2018). Using Rust For Game Development. RustConf 2018 Keynote.
- fitzgen. [generational-arena](https://github.com/fitzgen/generational-arena). Rust crate.
- matthieu-m. [Rust Store RFC 3446](https://github.com/matthieu-m/rfcs/blob/store/text/3446-store.md). Draft.
- Linux kernel. [Intrusive Linked Lists (list_head)](https://0xax.gitbooks.io/linux-insides/content/DataStructures/linux-datastructures-1.html).

### Swift Primitives Internal

- `/Users/coen/Developer/swift-primitives/Research/storage-primitives-comparative-analysis.md` (REC-001, REC-002)
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/split-storage-design.md`
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Slab Primitives/` (reference pattern)
- `/Users/coen/Developer/swift-primitives/swift-memory-primitives/` (Memory.Pool, Memory.Arena)
