# Ecosystem Data Structures Inventory

<!--
---
version: 1.0.0
last_updated: 2026-03-24
status: DECISION
tier: 1
scope: ecosystem-wide
---
-->

## Context

The Swift Institute ecosystem contains a rich set of data structures spanning Layer 1 (Primitives) and Layer 3 (Foundations). These types are organized in a three-level hierarchy: **Memory** (raw allocation) -> **Storage** (lifecycle-managed backing) -> **Buffer/Collection** (user-facing containers). Understanding which type to reach for — and its available variants — is essential for making correct implementation decisions.

This document catalogs every data structure type across `swift-primitives` and `swift-foundations`, organized by purpose and tier, with guidance on when to use each one.

## Question

What data structures exist in the ecosystem, how are they layered, and when should each one be used?

## Analysis

### Variant System

Most collection types follow a systematic variant pattern. Understanding this pattern is the key to selecting the right type:

| Variant | Storage | Allocation | Growth | Use When |
|---------|---------|------------|--------|----------|
| *(base)* | Heap | Dynamic | Growable | General purpose; unknown or variable size |
| `.Bounded` | Heap | Fixed at init | Fixed capacity | Known max capacity; heap-allocated but non-growable |
| `.Static<N>` | Stack (inline) | Compile-time | Fixed capacity | Capacity known at compile time; zero heap allocation |
| `.Small<N>` | Inline -> Heap | Spills on overflow | Growable | Usually small, occasionally large; SmallVec pattern |
| `.Fixed` | Heap | Fixed at init | Fixed count (immutable) | Immutable after creation; Array only |

> **Note**: `.Static<N>` is the collection-level name; infrastructure layers (Buffer, Storage, Memory) use `.Inline<N>` for the same concept. They are not interchangeable — see `variant-naming-audit.md` §3. `.Fixed` applies only to `Array.Fixed`; other collection types use `.Bounded` for capacity-limited mutable-count variants.

**Copyability**:
- Base, `.Bounded`, `.Fixed`: `~Copyable`; become `Copyable` when `Element: Copyable` (heap-backed CoW)
- `.Static<N>`, `.Small<N>`: unconditionally `~Copyable` (`@_rawLayout` prevents conditional Copyable — compiler limitation, not design choice)

**Sendability**: `@unchecked Sendable` on `~Copyable` types (exclusive ownership guarantees thread safety). Conditional `Sendable` when `Element: Sendable` on `Copyable` variants.

---

### Layer 1: Primitives — Memory Domain (Tier 13)

**Package**: `swift-memory-primitives` | **Import**: `import Memory_Primitives`

Raw memory abstractions. No element lifecycle management. Consumer manages initialization/deinitialization.

| Type | Kind | ~Copyable | Purpose |
|------|------|-----------|---------|
| `Memory.Address` | typealias (Tagged) | No | Non-null memory address as ordinal; typed arithmetic via Affine |
| `Memory.Address.Offset` | typealias | No | Signed byte displacement between addresses |
| `Memory.Address.Count` | typealias | No | Byte count |
| `Memory.Shift` | struct | No | Bit shift count (exponent for 2^n alignment) |
| `Memory.Alignment` | struct | No | Power-of-2 alignment value (exponent-backed) |
| `Memory.Buffer` | struct | No | Read-only raw buffer with non-null guarantee |
| `Memory.Buffer.Mutable` | struct | No | Mutable raw buffer with non-null guarantee |
| `Memory.Inline<Element, capacity>` | struct | Yes | Fixed inline storage; @_rawLayout; no tracking — consumer manages lifecycle |
| `Memory.Contiguous<Element: BitwiseCopyable>` | struct | Yes | Self-owning heap buffer; bulk deallocation only |
| `Memory.Arena` | struct | Yes | Bump allocator; O(1) alloc, no individual dealloc, bulk reset |
| `Memory.Pool` | struct | Yes | Fixed-capacity O(1) alloc/dealloc; in-band free list |
| `Memory.Allocator` | struct | No | System allocator (malloc/free wrapper) |

**When to use Memory types**: You are building infrastructure that needs raw memory control. You manage element lifecycles yourself. Most application code should use Buffer or Collection types instead.

---

### Layer 1: Primitives — Storage Domain (Tier 14)

**Package**: `swift-storage-primitives` | **Import**: `import Storage_Primitives`

Lifecycle-managed backing storage. These are the building blocks that Buffer types compose. Reference semantics (classes) for heap variants; value semantics for inline.

| Type | Kind | Semantics | Purpose |
|------|------|-----------|---------|
| `Storage<E>.Heap` | class | Reference | ManagedBuffer-backed; automatic range-based deinit via `Storage.Initialization` |
| `Storage<E>.Inline<capacity>` | struct | Value, ~Copyable | Fixed inline storage with per-slot bitmap tracking (capacity <= 256) |
| `Storage<E>.Arena` | class | Reference | SoA (Structure-of-Arrays) with generation tokens; automatic occupied-slot deinit |
| `Storage<E>.Arena.Inline<capacity>` | struct | Value, ~Copyable | Inline arena with InlineArray metadata + @_rawLayout elements |
| `Storage<E>.Slab` | class | Reference | Bitmap-tracked heap storage; bitmap-driven deinit |
| `Storage<E>.Pool` | class | Reference | Fixed-capacity O(1) typed pool; bitmap-tracked allocation; automatic element deinit |
| `Storage<E>.Pool.Inline<capacity>` | struct | Value, ~Copyable | Inline pool; bitmap-scanned (no in-band free list) |
| `Storage<E>.Split<Lane>` | class | Reference | Dual-array SoA (Lane + Element); NO element deinit — consumer-managed |
| `Storage.Initialization` | enum | Value | Tracks initialized ranges: `.empty`, `.one(Range)`, `.two(first:second:)` |

**When to use Storage types**: You are building a new Buffer discipline or a custom container that needs lifecycle-managed backing. If a Buffer type already exists for your use case, prefer it.

---

### Layer 1: Primitives — Buffer Domain (Tier 15)

**Package**: `swift-buffer-primitives` | **Import**: `import Buffer_Primitives`

Six buffer disciplines, each composing a Storage type with a Header for state tracking. Buffers are the mid-level building blocks between raw Storage and user-facing Collections.

#### Buffer.Linear — Contiguous Growable

| Type | Storage | Use When |
|------|---------|----------|
| `Buffer.Linear<E>` | `Storage<E>.Heap` | General-purpose contiguous buffer; unknown size |
| `Buffer.Linear<E>.Bounded` | `Storage<E>.Heap` | Known max capacity; heap, non-growable |
| `Buffer.Linear<E>.Inline<capacity>` | `Storage<E>.Inline` | Compile-time capacity; zero heap allocation |
| `Buffer.Linear<E>.Small<inlineCapacity>` | Inline -> Heap | Usually small; spills to heap on overflow |

**Backing for**: `Array`, `Stack`, `Heap`, `Dictionary.Ordered`, `Set.Ordered`

#### Buffer.Ring — Circular FIFO/LIFO

| Type | Storage | Use When |
|------|---------|----------|
| `Buffer.Ring<E>` | `Storage<E>.Heap` | Queue/deque backing; wrap-around without copying |
| `Buffer.Ring<E>.Bounded` | `Storage<E>.Heap` | Fixed-capacity ring |
| `Buffer.Ring<E>.Inline<capacity>` | `Storage<E>.Inline` | Inline ring; zero heap allocation |
| `Buffer.Ring<E>.Small<inlineCapacity>` | Inline -> Heap | Usually small ring; spills to heap |

**Backing for**: `Queue`, `Queue.DoubleEnded`

Additional: `Buffer.Ring.Checkpoint` — snapshot for save/restore operations.

#### Buffer.Slab — Sparse Index-Addressable Slots

| Type | Storage | Use When |
|------|---------|----------|
| `Buffer.Slab<E>` | `Storage<E>.Slab` | O(1) insert/remove by index; stable indices across mutations |
| `Buffer.Slab<E>.Bounded` | `Storage<E>.Slab` | Fixed-capacity slab |
| `Buffer.Slab<E>.Bounded.Indexed<Tag>` | `Storage<E>.Slab` | Phantom-typed index wrapper for Bounded slab |
| `Buffer.Slab<E>.Inline<capacity>` | `Storage<E>.Inline` | Inline slab |
| `Buffer.Slab<E>.Small<inlineCapacity>` | Inline -> Heap | SmallVec slab |

**Backing for**: `Slab`, `Dictionary` (unordered)

#### Buffer.Linked — Pool-Backed Linked List

| Type | Storage | Use When |
|------|---------|----------|
| `Buffer.Linked<E, N>` | `Storage<Node>.Pool` | Linked list with N links (1=singly, 2=doubly); O(1) insert/remove at known position |
| `Buffer.Linked<E, N>.Inline<capacity>` | Pool inline | Inline linked list |
| `Buffer.Linked<E, N>.Small<inlineCapacity>` | Inline -> Heap | SmallVec linked list |

**Backing for**: `List.Linked`, `Queue.Linked`

#### Buffer.Slots — Metadata-Parametric Slot Storage

| Type | Storage | Use When |
|------|---------|----------|
| `Buffer.Slots<E, Metadata>` | `Storage<E>.Split<Metadata>` | Parallel metadata + element arrays; consumer manages element lifecycle |

**Backing for**: `Hash.Table` (metadata = hash+position pairs)

#### Buffer.Arena — Generation-Token Arena

| Type | Storage | Use When |
|------|---------|----------|
| `Buffer.Arena<E>` | `Storage<E>.Arena` | Generational arena with position tokens; detects use-after-free |
| `Buffer.Arena<E>.Bounded` | `Storage<E>.Arena` | Fixed-capacity arena |
| `Buffer.Arena<E>.Inline<capacity>` | Arena inline | Inline arena |

`Buffer.Arena.Position` — 8-byte handle (index:UInt32 + token:UInt32) for safe arena access.

#### Buffer.Aligned / Buffer.Unbounded — Raw Byte Buffers

| Type | Use When |
|------|----------|
| `Buffer.Aligned` | Fixed-size aligned memory block (UInt8 only); ~Copyable |
| `Buffer.Unbounded` | Resizable byte buffer backed by Buffer.Aligned; configurable growth policy |

`Buffer.Growth.Policy` — struct with closure; factories: `.doubling`, `.factor(scale)`, `.exact`, `.pageAligned(alignment)`.

---

### Layer 1: Primitives — Collection Types (Tiers 16-18)

User-facing collection types that compose Buffer disciplines into ergonomic APIs.

#### Array (Tier 16)

**Package**: `swift-array-primitives` | **Import**: `import Array_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Array<E>` | Buffer.Linear | General-purpose growable contiguous sequence |
| `Array<E>.Static<capacity>` | Buffer.Linear.Inline | Fixed compile-time capacity; zero heap allocation |
| `Array<E>.Small<inlineCapacity>` | Buffer.Linear.Small | Usually small; spills to heap |
| `Array<E>.Bounded<N>` | Buffer.Linear.Bounded | Compile-time dimensioned; fixed capacity |
| `Array<E>.Fixed` | Buffer.Linear.Bounded | Fixed count; immutable after creation |

#### Stack (Tier 16)

**Package**: `swift-stack-primitives` | **Import**: `import Stack_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Stack<E>` | Buffer.Linear | LIFO; general-purpose |
| `Stack<E>.Bounded<capacity>` | Buffer.Linear.Bounded | Fixed-capacity LIFO |
| `Stack<E>.Static<capacity>` | Buffer.Linear.Inline | Inline LIFO; zero heap allocation |
| `Stack<E>.Small<inlineCapacity>` | Buffer.Linear.Small | SmallVec LIFO; inline with heap spill |

#### Slab (Tier 16)

**Package**: `swift-slab-primitives` | **Import**: `import Slab_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Slab<E>` | Buffer.Slab | Sparse slot storage; O(1) insert/remove; stable indices |
| `Slab<E>.Static<wordCount>` | Buffer.Slab.Inline | Inline slab; zero heap allocation |
| `Slab<E>.Indexed<Tag>` | Buffer.Slab | Phantom-typed index wrapper for type-safe access |

#### Hash.Table (Tier 16)

**Package**: `swift-hash-table-primitives` | **Import**: `import Hash_Table_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Hash.Table<E>` | Buffer.Slots | Open-addressed hash table; maps elements to typed indices in external storage |

Not a standalone container — backing infrastructure for Dictionary and Set.

#### Heap (Tier 16)

**Package**: `swift-heap-primitives` | **Import**: `import Heap_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Heap<E: Comparison.Protocol>` | Buffer.Linear | Binary min-heap; priority queue |
| `Heap<E>.Fixed` | Buffer.Linear.Bounded | Fixed-capacity heap (rename to `.Bounded` pending — see `variant-naming-audit.md`) |
| `Heap<E>.Static<capacity>` | Buffer.Linear.Inline | Inline heap |
| `Heap<E>.Small<inlineCapacity>` | Buffer.Linear.Small | SmallVec heap |
| `Heap<E>.MinMax` | Buffer.Linear | Double-ended priority queue (min and max) |

#### List (Tier 17)

**Package**: `swift-list-primitives` | **Import**: `import List_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `List.Linked<E, N>` | Buffer.Linked | Linked list; N=1 singly, N=2 doubly; O(1) insert/remove at position |
| `List.Linked<E, N>.Bounded` | Buffer.Linked.Bounded | Fixed-capacity linked list |
| `List.Linked<E, N>.Inline` | Buffer.Linked.Inline | Inline linked list (rename to `.Static` pending — see `variant-naming-audit.md`) |
| `List.Linked<E, N>.Small` | Buffer.Linked.Small | SmallVec linked list |

#### Queue (Tier 17)

**Package**: `swift-queue-primitives` | **Import**: `import Queue_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Queue<E>` | Buffer.Ring | FIFO; general-purpose |
| `Queue<E>.Fixed` | Buffer.Ring.Bounded | Fixed-capacity FIFO (rename to `.Bounded` pending — see `variant-naming-audit.md`) |
| `Queue<E>.Static<capacity>` | Buffer.Ring.Inline | Inline FIFO |
| `Queue<E>.Small<inlineCapacity>` | Buffer.Ring.Small | SmallVec FIFO |
| `Queue<E>.Linked` | Buffer.Linked | Linked-list FIFO |
| `Queue<E>.Linked.Fixed` | Buffer.Linked | Fixed-capacity linked FIFO (rename to `.Bounded` pending) |
| `Queue<E>.Linked.Inline<N>` | Buffer.Linked.Inline | Inline linked FIFO |
| `Queue<E>.Linked.Small<N>` | Buffer.Linked.Small | SmallVec linked FIFO |
| `Queue<E>.DoubleEnded` | Buffer.Ring | Deque; push/pop from both ends |
| `Queue<E>.DoubleEnded.Fixed` | Buffer.Ring.Bounded | Fixed-capacity deque (rename to `.Bounded` pending) |
| `Queue<E>.DoubleEnded.Static<N>` | Buffer.Ring.Inline | Inline deque |
| `Queue<E>.DoubleEnded.Small<N>` | Buffer.Ring.Small | SmallVec deque |

#### Set (Tier 17)

**Package**: `swift-set-primitives` | **Import**: `import Set_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Set.Ordered<E: Hash.Protocol>` | Buffer.Linear + Hash.Table | Insertion-ordered hash set; O(1) membership |
| `Set.Ordered<E>.Fixed` | Buffer.Linear.Bounded + Hash.Table | Fixed-capacity ordered set (rename to `.Bounded` pending — see `variant-naming-audit.md`) |
| `Set.Ordered<E>.Static<N>` | Buffer.Linear.Inline + Hash.Table.Static | Inline ordered set; zero heap |
| `Set.Ordered<E>.Small<N>` | Inline -> Heap | SmallVec ordered set |

#### Dictionary (Tier 18)

**Package**: `swift-dictionary-primitives` | **Import**: `import Dictionary_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Dictionary<K: Hash.Protocol, V>` | Buffer.Slab + Hash.Table | Unordered hash map; slab-backed; O(1) lookup/insert/remove |
| `Dictionary<K, V>.Ordered` | Set.Ordered (keys) + Buffer.Linear (values) | Insertion-ordered hash map; linear-backed |
| `Dictionary<K, V>.Ordered.Bounded` | Buffer.Linear.Bounded | Fixed-capacity ordered dictionary |
| `Dictionary<K, V>.Ordered.Static<N>` | Inline | Inline ordered dictionary; zero heap |
| `Dictionary<K, V>.Ordered.Small<N>` | Inline -> Heap | SmallVec ordered dictionary |

#### Tree (Tier 18)

**Package**: `swift-tree-primitives` | **Import**: `import Tree_Primitives`

| Type | Backing | Use When |
|------|---------|----------|
| `Tree.N<E, n>` | Buffer.Arena | N-ary tree with bounded arity |
| `Tree.Binary` (= `Tree.N<2>`) | Buffer.Arena | Binary tree |
| `Tree.N<E, n>.Bounded` | Buffer.Arena.Bounded | Fixed-capacity n-ary tree |
| `Tree.N<E, n>.Inline` | Buffer.Arena.Inline | Inline n-ary tree (rename to `.Static` pending — see `variant-naming-audit.md`) |
| `Tree.N<E, n>.Small` | Inline -> Heap | SmallVec n-ary tree |
| `Tree.Unbounded<E>` | Buffer.Arena | Variable-arity tree |
| `Tree.Keyed<K: Hash.Protocol>` | Buffer.Arena + Hash.Table | Key-indexed tree (trie-like) |

#### Graph (Tier 18)

**Package**: `swift-graph-primitives` | **Import**: `import Graph_Primitives`

Namespace for graph algorithms (traversal, analysis). Not a container — operates on external graph representations via witnesses.

---

### Layer 1: Primitives — Bit-Level Types (Tiers 8-12)

#### Bitset (Tier 8)

**Package**: `swift-bitset-primitives` | **Import**: `import Bitset_Primitives`

| Type | Use When |
|------|----------|
| `Bitset` | Growable packed bit set; membership testing for integer domains |
| `Bitset.Static` | Fixed inline bitset |
| `Bitset.Small` | SmallVec bitset |
| `Bitset.Fixed` | Fixed-capacity bitset (rename to `.Bounded` pending — see `variant-naming-audit.md`) |

#### Bit.Pack (Tier 11)

**Package**: `swift-bit-pack-primitives` | **Import**: `import Bit_Pack_Primitives`

| Type | Use When |
|------|----------|
| `Bit.Pack<Word>` | Bit packing layout witness; describes how fields are packed into integer words |

Not a container — a layout descriptor.

#### Bit.Vector (Tier 12)

**Package**: `swift-bit-vector-primitives` | **Import**: `import Bit_Vector_Primitives`

| Type | Use When |
|------|----------|
| `Bit.Vector` | Infrastructure bitmap; ~Copyable ownership |
| `Bit.Vector.Static` | Fixed inline bitmap; Copyable |
| `Bit.Vector.Dynamic` | Growable bitmap; Copyable |
| `Bit.Vector.Bounded` | Fixed-capacity bitmap; Copyable |
| `Bit.Vector.Inline<wordCount>` | Inline bitmap with count tracking; Sendable |

Infrastructure type — used internally by Storage and Buffer types for occupancy tracking.

---

### Layer 1: Primitives — Functional & Text Types

#### Vector (Tier 9)

**Package**: `swift-vector-primitives` | **Import**: `import Vector_Primitives`

| Type | Use When |
|------|----------|
| `Vector<Bound>` | Functional vector: `Fin(n) -> Element`; generates values on demand from finite integer domain |

Not a container — a function from index to value. Different from Array.

#### String (Tier 14)

**Package**: `swift-string-primitives` | **Import**: `import String_Primitives`

| Type | Use When |
|------|----------|
| `String` | Owned, null-terminated platform string; ~Copyable; @unchecked Sendable |

No variants. Monolithic type with `.View`, `.Char`, `.Length` support types.

---

### Layer 1: Primitives — Supporting Infrastructure

These are not containers but are used pervasively by the data structure types above.

| Type | Package (Tier) | Purpose |
|------|----------------|---------|
| `Index<E>` | index (6) | Phantom-typed index for type-safe collection access |
| `Index<E>.Offset` | index (6) | Typed signed displacement |
| `Index<E>.Count` | index (6) | Typed element count |
| `Tagged<Tag, Value>` | affine (5) | Phantom-typed value wrapper; base for Index, Memory.Address |
| `Hash.Value` | hash (3) | Typed hash value |
| `Hash.Protocol` | hash (3) | ~Copyable-compatible hashing protocol |
| `Property<Tag, Base>` | property (0) | CoW-safe mutation namespace |
| `Property<Tag, Base>.View` | property (0) | Pointer-based view for ~Copyable borrowed/consuming access |

---

### Layer 3: Foundations (swift-foundations)

Higher-level types that compose Layer 1 primitives with platform capabilities.

#### Memory (swift-memory)

| Type | ~Copyable | Use When |
|------|-----------|----------|
| `Memory.Map` | Yes | Memory-mapped file region; safe mmap wrapper |
| `Memory.Allocation.Histogram` | No | Profiling allocation size distributions |
| `Memory.Allocation.Statistics` | No | Allocation measurement snapshots |

#### Pools (swift-pools)

| Type | Use When |
|------|----------|
| `Pool.Blocking` | Thread-safe blocking resource pool; connection pools, worker pools |

#### Async (swift-async)

| Type | Use When |
|------|----------|
| `Async.Stream<E>` | Composable async stream; operators (map, filter, merge, zip, buffer, etc.) |

Rich operator set: `.map`, `.filter`, `.flatMap`, `.merge`, `.zip`, `.combine`, `.buffer`, `.debounce`, `.throttle`, `.sample`, `.scan`, `.distinct`, `.prefix`, `.drop`.

#### I/O (swift-io)

| Type | ~Copyable | Use When |
|------|-----------|----------|
| `IO.Event.Channel` | Yes | Non-blocking I/O channel for socket operations |
| `IO.Event.Buffer` | No | Buffer management for I/O operations |

#### Serialization

| Type | Use When |
|------|----------|
| `JSON` | JSON value type (wraps RFC_8259.Value) |
| `XML` | XML element representation |
| `Plist` | Property list value type |

#### File System

| Type | Use When |
|------|----------|
| `Path` | Filesystem path; Copyable, Sendable, Hashable |

#### Document Rendering

| Type | Use When |
|------|----------|
| `HTML.View` (protocol) | Composable HTML rendering |
| CSS types (Border, Font, Color.Theme) | Styling for HTML documents |

---

## Decision Guide

### "I need a sequential container"

```
Is the size known at compile time?
  Yes -> Array<E>.Static<N>
  No -> Is it usually small?
    Yes -> Array<E>.Small<N>
    No -> Array<E>
```

### "I need a FIFO queue"

```
Is it linked-list based?
  Yes -> Queue<E>.Linked<N> or List.Linked<E, N>
  No -> Is the capacity fixed?
    Yes -> Queue<E>.Bounded<N>
    No -> Queue<E>
```

### "I need a LIFO stack"

```
Is the capacity known at compile time?
  Yes -> Stack<E>.Static<N>
  No -> Stack<E>
```

### "I need a key-value map"

```
Do you need insertion order?
  Yes -> Dictionary<K, V>.Ordered
  No -> Dictionary<K, V>
```

### "I need a set"

```
Is it an integer domain?
  Yes -> Bitset (or Bitset.Static for fixed)
  No -> Set.Ordered<E>
```

### "I need O(1) insert/remove with stable indices"

```
Do you need generation tokens (use-after-free detection)?
  Yes -> Buffer.Arena<E> (via Buffer.Arena.Position)
  No -> Slab<E>
```

### "I need a priority queue"

```
Do you need both min and max?
  Yes -> Heap<E>.MinMax
  No -> Heap<E>
```

### "I need a tree"

```
Is it key-indexed (trie-like)?
  Yes -> Tree.Keyed<K>
  No -> Is the arity bounded?
    Yes -> Tree.N<E, n> (Tree.Binary for n=2)
    No -> Tree.Unbounded<E>
```

### "I need raw memory management"

```
Is it a bump allocator (no individual dealloc)?
  Yes -> Memory.Arena
  No -> Is it fixed-capacity O(1) alloc/dealloc?
    Yes -> Memory.Pool
    No -> Memory.Allocator (system malloc)
```

### "I need to build a new container type"

Compose from the three layers:
1. Pick a **Storage** discipline (Heap, Inline, Arena, Slab, Pool, Split)
2. Wrap it in a **Buffer** type with a Header for state tracking
3. Build your **Collection** API on top

---

## Composition Architecture

```
Collection (user-facing API)
    |
    +-- Header (state: count, capacity, head/tail, bitmap, etc.)
    +-- Buffer discipline (mutation logic)
           |
           +-- Storage (lifecycle-managed backing)
                  |
                  +-- Memory (raw allocation)
```

Each layer adds one concern:
- **Memory**: allocation and deallocation
- **Storage**: element lifecycle (init/deinit tracking)
- **Buffer**: mutation semantics (grow, insert, remove, rebalance)
- **Collection**: user ergonomics (subscript, iteration, protocol conformances)

---

## Outcome

**Status**: DECISION

This inventory catalogs 50+ data structure types across 2 layers and 15+ tiers of the Swift Institute ecosystem. The systematic variant pattern (base/Bounded/Static/Small/Fixed) applies uniformly. The three-level composition architecture (Memory -> Storage -> Buffer -> Collection) provides clear extension points for new container types.

All types support `~Copyable` elements. All types use typed throws ([API-ERR-001]). All types follow the `Nest.Name` pattern ([API-NAME-001]).

## References

- Primitives Tiers: `https://github.com/swift-primitives/Documentation.docc/tree/main/Primitives Tiers.md`
- Five Layer Architecture: `Documentation.docc/Five Layer Architecture.md`
- Comparative analyses: `swift-institute/Research/comparative-*.md` (per-package deep dives)
- Storage-buffer analysis: `swift-institute/Research/storage-buffer-abstraction-analysis.md`
