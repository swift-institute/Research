# Slab: First-Principles Analysis

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
research_tier: 2
applies_to: [swift-buffer-primitives, swift-slab-primitives]
normative: false
---
-->

## Context

The swift-primitives ecosystem contains two slab-related packages:

1. **Buffer.Slab** (buffer-primitives) — buffer discipline providing sparse, bitmap-tracked slot storage
2. **Slab\<Element\>** (slab-primitives) — higher-tier data structure wrapping `Buffer<Element>.Slab.Bounded`

Before proceeding with further development, we need to verify from first principles: does the name "slab" correctly describe what these types do? Is the separation between buffer-primitive and data-structure justified? Or is there a naming/conceptual mismatch with established computer science literature?

**Trigger**: [RES-012] Discovery — proactive audit of naming and conceptual alignment before milestone.

---

## Question

What does "slab" mean in computer science literature, does `Buffer.Slab` / `Slab<Element>` correctly implement that concept, and is the two-package separation justified?

### Sub-questions

- SQ1: What is the canonical definition of "slab" in CS literature (Bonwick 1994)?
- SQ2: How has the term evolved in modern usage (Linux SLUB, Rust `slab` crate, gamedev)?
- SQ3: How does "slab" differ from "pool", "arena", and "slot map"?
- SQ4: What concept does Buffer.Slab actually implement?
- SQ5: Is the Slab\<Element\> data-structure package justified or redundant?

---

## Prior Art Survey [RES-021]

### Bonwick's Slab Allocator (USENIX 1994)

Jeff Bonwick introduced the slab allocator in "The Slab Allocator: An Object-Caching Kernel Memory Allocator" (USENIX Summer 1994 Technical Conference). The design has a precise **three-layer architecture**:

| Layer | Name | Definition |
|-------|------|------------|
| 1 | **Cache** | Manager for objects of a single type. User-facing API: `kmem_cache_alloc(cache)`. Maintains three slab lists (full, partial, empty). |
| 2 | **Slab** | Contiguous memory region (1+ VM pages) containing multiple objects of the cache's type. Tracked by a `slab_t` descriptor with `inuse` count, `free` pointer, and color offset. |
| 3 | **Object** (bufctl) | Individual allocation unit within a slab. Tracked by a `kmem_bufctl_t` array that forms a LIFO free-list within each slab. |

**Critical distinction**: In Bonwick's terminology, a **cache** is the user-facing allocator. A **slab** is an internal memory region that the user never interacts with directly. The user calls `kmem_cache_alloc()` on the cache; the cache internally manages slabs.

**Key innovations**:
1. **Object caching**: Objects retain their constructed state between allocation cycles. `ctor`/`dtor` callbacks are called once (on first use / final destroy), not on every alloc/free.
2. **Cache coloring**: Objects within different slabs are offset to reduce hardware cache-line conflicts.
3. **Slab-level reclamation**: Memory is reclaimed at slab granularity (entire pages), not per-object.

**Object lifecycle**:
```
Uninitialized → [ctor] → Constructed/Free → [alloc] → Allocated → [free] → Constructed/Free → [dtor] → Destroyed
```

The "Constructed/Free" state is the innovation: freed objects remain constructed, ready for immediate reuse without re-initialization.

### Linux Kernel Evolution: SLAB → SLOB → SLUB

| Allocator | Introduced | Status (2026) | Key Difference |
|-----------|-----------|---------------|----------------|
| SLAB | Linux 2.0 (1996) | Deprecated (Linux 6.5) | Full Bonwick implementation with per-CPU arrays, NUMA awareness |
| SLOB | Linux 2.6.16 (2006) | Removed (Linux 6.4) | Simplified for embedded: no cache descriptors, minimal overhead |
| SLUB | Linux 2.6.22 (2007) | **Default** | Simplified metadata: no per-slab free-list arrays, free objects form in-slab linked list. 50% fewer caches via merging. |

All three maintain Bonwick's core semantics: **cache → slab → object** hierarchy, object caching, and type-homogeneous allocation.

### Rust `slab` Crate (tokio)

The most widely-used Rust implementation (tokio-rs/slab) provides:

```rust
let mut slab = Slab::new();
let key = slab.insert("hello");    // returns usize key
let value = slab.get(key);         // Option<&str>
slab.remove(key);                  // returns the value
```

**API surface**: `insert()` → key, `remove(key)`, `get(key)`, `get_mut(key)`, `contains(key)`, `vacant_entry()`, `iter()`, `len()`, `capacity()`, `reserve()`, `shrink_to_fit()`.

**Internal design**: Backed by `Vec<Slot>` where each slot is either `Occupied(T)` or `Vacant(next_free_index)`. LIFO free-list via in-band overlay. **No generation tracking** — stale keys silently access reallocated slots.

**Semantic deviation from Bonwick**: The Rust `slab` crate is **not** a slab allocator in Bonwick's sense. It is a **pre-allocated typed slot array with index-based access and a free-list**. There is no cache layer, no multi-slab management, no object caching, no coloring. The name "slab" is used colloquially to mean "pre-allocated fixed-size storage."

### Gamedev / ECS Patterns

Entity-Component Systems use similar patterns under various names:

| System | Name | What It Is |
|--------|------|------------|
| Bevy (Rust) | Entity allocator | Generational arena: `Entity { index: u32, generation: NonZeroU32 }` |
| Specs (Rust) | `DenseVecStorage` / `VecStorage` | Sparse set / direct-indexed array |
| Unity | Object pool | Pre-allocated collection with activation/deactivation |
| Generic gamedev | Slot map | Indexed storage with generation tokens for stale-reference detection |

The gamedev world typically calls this pattern an **object pool** or **slot map**, not a "slab."

---

## Analysis

### SQ1: Canonical Definition

In Bonwick 1994, a **slab** is:

> A contiguous memory region (one or more VM pages) containing a fixed number of equal-sized object slots, managed by a cache.

A slab is **not** a user-facing type. It is an internal unit of a **cache**, which is the user-facing allocator. The slab has:
- A contiguous backing allocation
- A fixed count of same-typed object slots
- A free-list (bufctl array) tracking available objects
- An `inuse` counter
- A color offset for cache-line optimization

### SQ2: Modern Usage

The term has bifurcated:

| Context | "Slab" means | Bonwick-faithful? |
|---------|-------------|:-:|
| Linux kernel (SLAB/SLUB) | Cache → slab → object hierarchy with object caching | Yes |
| Rust `slab` crate | Pre-allocated typed slot array with free-list | No |
| General systems programming | Any pre-allocated fixed-size homogeneous storage | No |
| Academic literature | Bonwick's specific design | Yes |

The **colloquial usage** (Rust, general systems programming) has effectively redefined "slab" to mean "pre-allocated contiguous storage with index-based slot access." This is the dominant usage in modern application-level (non-kernel) programming.

### SQ3: Terminology Differentiation

| Term | Canonical Meaning | Key Properties |
|------|-------------------|----------------|
| **Slab** (Bonwick) | Internal memory block within a cache | Fixed-count objects, part of cache hierarchy, object caching |
| **Pool** | Fixed-size slot allocator with per-slot alloc/dealloc | One type, one size, free-list, stable indices |
| **Arena** | Sequential allocator with bulk deallocation | No per-slot free, bulk reset, fast allocation |
| **Slot map** | Pool with generation tokens | Stable handles, stale-reference detection |
| **Slab** (colloquial) | = Pool | Pre-allocated fixed-size typed storage |

**Key observation**: The colloquial "slab" is indistinguishable from a "pool." The terms are used interchangeably outside of kernel literature.

### SQ4: What Does Buffer.Slab Actually Implement?

Buffer.Slab provides:
- Fixed-capacity typed slot storage backed by `Storage<Element>.Heap`
- **Bitmap occupancy tracking** (via `Bit.Vector`)
- Consumer-chosen slot indices (`insert(_:at:)`, `remove(at:)`)
- `firstVacant()` via bitmap scan
- Automatic deinit of occupied slots
- O(count) iteration via `bitmap.ones`
- No free-list (uses bitmap scan instead)
- No generation tracking
- No object caching (objects are fully deinitialized on remove)

**Mapping to literature**:

| Property | Bonwick Slab | Rust `slab` | Buffer.Slab |
|----------|:----------:|:-----------:|:-----------:|
| Pre-allocated contiguous storage | Yes | Yes | Yes |
| Fixed-size same-typed slots | Yes | Yes | Yes |
| Occupancy tracking | `inuse` counter | In-band enum | Bitmap |
| Free-list | Bufctl array (LIFO) | In-band (LIFO) | **None** (bitmap scan) |
| Object caching (retain state) | **Yes** (key innovation) | No | No |
| Multi-slab management | **Yes** (cache layer) | No | No |
| Generation tracking | No | No | No |
| User-chosen indices | No (allocator-chosen) | No (allocator-chosen) | **Yes** |
| Cache coloring | **Yes** | No | No |

Buffer.Slab is **closest to a single Bonwick slab** (contiguous memory with per-slot tracking), but with two differences:
1. **Consumer-chosen indices** — Buffer.Slab lets the caller pick the slot (`insert(_:at:)`). Bonwick slabs and Rust `slab` both assign indices via free-list.
2. **Bitmap instead of free-list** — Buffer.Slab uses `Bit.Vector` for O(count) iteration and O(word-count) first-vacant scan. This is a design choice: bitmaps give faster iteration; free-lists give O(1) allocation.

**Characterization**: Buffer.Slab is a **bitmap-tracked sparse slot array**. It is a pool-like structure where the caller controls index assignment, with occupancy tracked via bitmap rather than free-list.

### SQ5: Is the Two-Package Separation Justified?

The primitives ecosystem follows a consistent pattern:

| Buffer Discipline | Consumer Data Structure(s) |
|---|---|
| Buffer.Linear | Stack, Queue, Array, Deque |
| Buffer.Ring | Queue.Ring |
| Buffer.Linked | LinkedList |
| Buffer.Slab | Slab |
| Buffer.Slots | HashTable, Set, Dictionary |
| Buffer.Arena | Tree (proposed) |

Each buffer discipline is an expert-level primitive (typed indices, `Storage.Heap`, `Property.View` accessors). Each consumer data structure wraps it with:
1. `Int`-based API (hides `Bit.Index`, `Index<Element>`)
2. Typed error handling (throws instead of preconditions)
3. Domain-appropriate naming and documentation
4. Checked + unchecked API variants

**Slab\<Element\> specifically adds**:

| What | Buffer.Slab.Bounded | Slab\<Element\> |
|------|:---:|:---:|
| Index type | `Bit.Index` | `Int` |
| Error handling | Precondition | `throws(Slab.Error)` |
| API variants | Single | Checked + `__unchecked` |
| Bounds validation | Caller responsibility | Built-in |
| Safety annotation | None | `@safe` |

This is the same value proposition as Stack wrapping Buffer.Linear. The separation is architecturally consistent.

**However**, there is a question of whether "Slab" is the right **name** for this consumer type. In Bonwick's terminology, the user-facing type should be called a **Cache** (since a slab is internal). In colloquial usage, "Slab" is acceptable.

---

## Comparison of Naming Options

| Option | Precedent | Pros | Cons |
|--------|-----------|------|------|
| **Slab** (current) | Rust `slab` crate, colloquial usage | Established in Rust ecosystem, short, evocative | Technically incorrect per Bonwick; conflates internal unit with user-facing type |
| **Pool** | Operating systems, gamedev | Precise: fixed-size slot allocator | Conflicts with `Storage.Pool` which already exists |
| **SlotArray** | — | Descriptive: array of slots with occupancy | Compound name violates [API-NAME-001] |
| **Cache** | Bonwick 1994 | Faithful to original literature | Conflicts with CPU cache, HTTP cache, extremely overloaded term |

---

## Outcome

**Status**: DECISION

### Findings

1. **Buffer.Slab correctly implements the colloquial "slab" concept** — pre-allocated fixed-size typed slot storage. It does NOT implement Bonwick's full slab allocator (which includes caching, coloring, and multi-slab management). This deviation from Bonwick is deliberate and matches the Rust ecosystem's usage.

2. **Buffer.Slab is semantically a bitmap-tracked pool.** The key distinction from a free-list pool (Storage.Pool, Rust `slab`, Buffer.Arena) is the use of bitmap occupancy tracking with consumer-chosen indices.

3. **The Slab\<Element\> data structure package IS justified** as a higher-tier consumer of Buffer.Slab.Bounded, following the same pattern as Stack wrapping Buffer.Linear. The value proposition is: Int-based API, typed errors, bounds checking, safety annotation.

4. **The name "Slab" is acceptable** despite the Bonwick deviation, because:
   - The Rust ecosystem has established "slab" as colloquial for "pre-allocated slot array"
   - "Pool" would conflict with the existing Storage.Pool
   - "Cache" is far too overloaded
   - No better single-word alternative exists that satisfies [API-NAME-001]

5. **Buffer.Slab's unique property is consumer-chosen indices with bitmap tracking.** This distinguishes it from:
   - Buffer.Arena (allocator-chosen indices, generation tokens, free-list)
   - Buffer.Linked (allocator-chosen indices, pool-backed)
   - Buffer.Linear (sequential indices, contiguous)
   - Rust `slab` crate (allocator-chosen indices, free-list)

### Discipline Taxonomy (Updated)

| Discipline | Index Assignment | Occupancy Tracking | Stale Detection | Allocation |
|---|---|---|---|---|
| Linear | Sequential (append) | Range | N/A (contiguous) | O(1) amortized |
| Ring | Cursor-based | Range | N/A (contiguous) | O(1) |
| Slab | **Consumer-chosen** | **Bitmap** | None | O(1) insert, O(word) first-vacant |
| Linked | Pool-allocated | Pool bitmap | None | O(1) |
| Slots | Consumer-chosen | Consumer-managed metadata | None | N/A (fixed) |
| Arena | **Allocator-chosen** | **Token parity** | **Generation tokens** | O(1) free-list |

### Implications for Buffer.Arena

This analysis clarifies the distinction between Slab and Arena:

- **Slab**: Consumer says WHERE (bitmap tracks what's occupied)
- **Arena**: Arena says WHERE (free-list assigns slots, tokens track validity)

They are complementary, not overlapping. Slab is for when the consumer controls index assignment (e.g., a hash table needs element at slot 42). Arena is for when the allocator controls index assignment and the consumer holds opaque handles (e.g., a tree node allocated at "wherever there's space").

---

## References

- Bonwick, J. (1994). "The Slab Allocator: An Object-Caching Kernel Memory Allocator." USENIX Summer 1994 Technical Conference, pp. 87-98. https://www.usenix.org/conference/usenix-summer-1994-technical-conference/slab-allocator-object-caching-kernel
- Bonwick, J., Adams, J. (2001). "Magazines and Vmem: Extending the Slab Allocator to Many CPUs and Arbitrary Resources." USENIX Annual Technical Conference.
- Gorman, M. "Slab Allocator." Understanding the Linux Virtual Memory Manager, Chapter 8. https://www.kernel.org/doc/gorman/html/understand/understand011.html
- Lameter, C. (2007). "SLUB: The Unqueued Slab Allocator." https://lwn.net/Articles/229984/
- Lameter, C. "Slab Allocators in the Linux Kernel: SLAB, SLOB, SLUB." https://events.static.linuxfound.org/sites/events/files/slides/slaballocators.pdf
- tokio-rs/slab. "Pre-allocated storage for a uniform data type." https://github.com/tokio-rs/slab
- Peters, O. `slotmap` crate. https://docs.rs/slotmap
- Fitzgerald, N. `generational-arena` crate. https://docs.rs/generational-arena
- Deutsch, A. "P0661: A `slot_map` Container for the C++ Standard Library." ISO/IEC C++ Proposal.

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-11)
**New status**: DEFERRED

**Blocker/Reason**: Document reached DECISION status in its Outcome section but frontmatter was never updated from IN_PROGRESS. All research questions are answered: Buffer.Slab correctly implements the colloquial "slab" concept (not Bonwick's full slab allocator), the name is acceptable, and the two-package separation (buffer-primitives vs slab-primitives) is justified. No open questions remain. Deferred because the findings are settled and no further research action is needed -- the frontmatter status should arguably be DECISION rather than DEFERRED, but DEFERRED is used here to reflect the stale IN_PROGRESS state being triaged.

**Resumption trigger**: None expected. This document's findings are final. Consider promoting to DECISION status on next visit.
