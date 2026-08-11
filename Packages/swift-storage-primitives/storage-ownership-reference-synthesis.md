# Storage, Ownership, and Reference Primitives: Research Synthesis

<!--
---
version: 3.0.0
last_updated: 2026-02-05
status: DECISION
tier: 3
applies_to: [swift-storage-primitives, swift-memory-primitives]
normative: true
---
-->

## Axis Ownership Policy

> **Storage type names encode placement only.**
> Count semantics, access discipline, and mutability are layered above storage.

> **A storage primitive MUST own memory or control its reclamation.**
> Views, spans, and non-owning projections are not storage primitives.

---

## Context

This document synthesizes academic literature and design decisions into the theoretical foundation for storage primitives.

**Purpose**: Establish the conceptual model, canonical primitive set, and layering strategy for storage, ownership, and reference primitives.

**Implementation Note (2026-02-05)**: The `@_rawLayout` migration removed the 64-byte slot overhead from `Storage.Inline`. Elements are now stored at natural stride, eliminating the physical/logical slot distinction that originally motivated `Index<Storage>` as separate from `Index<Element>`.

---

## Part I: Conceptual Map

### 1.1 The Design Space: Five Fundamental Axes

The literature converges on five orthogonal axes that fully characterize how a program relates to memory. Every memory-touching primitive can be located in this space.

```
Axis 1: PLACEMENT — Where does state live?
        (inline | stack | heap | arena | pool | external)

Axis 2: OWNERSHIP — Who is responsible for the state?
        (unique | shared | borrowed | transferred)

Axis 3: LIFETIME — When does state cease to exist?
        (static | lexical | dynamic/ARC | bulk/region | external)

Axis 4: MUTABILITY — What access rights exist?
        (immutable | exclusive-mutable | shared-immutable)

Axis 5: STRUCTURAL DISCIPLINE — How many times can state be used?
        (unrestricted/Copyable | affine/~Copyable | linear/exactly-once)
```

**Critical insight**: These axes are orthogonal, not hierarchical. A value can be:
- Heap-placed, uniquely-owned, dynamically-lifetimed, mutable, affine (`ManagedBuffer` with `~Copyable` elements)
- Inline-placed, uniquely-owned, lexically-lifetimed, immutable, unrestricted (a `let` struct field)
- Arena-placed, region-owned, bulk-lifetimed, mutable, linear (a region-allocated resource)

No single axis subsumes another. This is why a taxonomy organized along one axis (e.g., placement only) will always feel incomplete.

### 1.2 Three Distinct Abstraction Layers

The research consistently identifies three layers that use memory differently. These are not synonyms; conflating them is a category error.

```
Layer         | Question Answered              | Formal Model
──────────────|────────────────────────────────|────────────────────────
Storage       | How does memory EXIST?         | Store = Location → Value
              | (placement, ownership,         | (Scott-Strachey 1971)
              |  lifetime, reclamation)        |
              |                                |
Buffer        | How is data TRANSFERRED?       | Temporal holding with
              | (access pattern, rate          | access discipline
              |  matching, I/O discipline)     |
              |                                |
ADT/Container | What OPERATIONS are available? | ADT = (D, Ops, Axioms)
              | (semantics, invariants,        | (Liskov & Zilles 1974)
              |  behavior contracts)           |
```

**Dependency**: ADTs use buffers; buffers use storage. The arrows point down.

```
Queue                    ← ADT: enqueue/dequeue with FIFO axiom
 └─ uses Buffer.Ring     ← Buffer: circular access discipline
     └─ backed by Storage.Heap  ← Storage: heap-placed, ARC-lifetimed
```

### 1.3 Relationship to Existing Primitives Architecture

The tier stack maps onto this model:

| Tier | Package | Role in Model |
|------|---------|---------------|
| 10 | memory-primitives | Raw substrate (Memory.Address, Memory.Arena, Memory.Buffer) |
| 12 | storage-primitives | Typed element storage (Storage.Heap, Storage.Inline) |
| 13 | buffer-primitives | Access discipline over storage (Buffer.Ring, Buffer.Linear, Buffer.Slots) |
| 14+ | ADT packages | Containers (Array, Queue, Stack, Deque, etc.) |

Typed pointer access uses Swift standard library types (`UnsafeMutablePointer<Element>`, `UnsafePointer<Element>`, `Span<Element>`) directly. There is no separate pointer-primitives tier — stdlib provides the typed lens over raw memory.

The memory→storage chain maps to: untyped substrate → typed element management. This is sound.

### 1.4 Where Ownership and References Fit

Ownership and references are not separate packages—they are **cross-cutting concerns** that manifest differently at each layer:

| Concept | At Memory Layer | At Storage Layer | At Buffer Layer | At ADT Layer |
|---------|----------------|-----------------|-----------------|--------------|
| **Ownership** | Who allocated? | Storage class owns allocation | Buffer owns storage | Container owns buffer |
| **Borrowing** | — | `borrowing` parameter | `borrowing` access | `borrowing` subscript |
| **Lifetime** | Address validity | ARC / scope / region | Delegates to storage | Value semantics |
| **Mutability** | — | `mutating` methods | `mutating` access discipline | CoW |
| **Copyability** | — | `~Copyable` elements | Conditional `Copyable` | Conditional `Copyable` |

**Key finding**: Ownership and reference semantics are expressed through Swift's type system (`~Copyable`, `borrowing`, `consuming`, `inout`) at every layer. They do not need their own package. They need correct expression at each tier.

### 1.5 Relationship to Adjacent Packages

Three existing packages sit adjacent to storage-primitives. None belong inside it:

| Package | What It Provides | Relationship to Storage |
|---------|-----------------|------------------------|
| **ownership-primitives** | Single-value ownership wrappers: `Ownership.Unique`, `.Shared`, `.Mutable`, `.Slot`, `.Transfer` | Orthogonal. These manage ownership of individual values across isolation boundaries, not collection storage. Not a storage concern. |
| **reference-primitives** | Non-owning reference types: `Reference.Weak`, `.Unowned`, `.Sendability.Unchecked` | Orthogonal. ARC reference discipline primitives. Not a storage concern. |
| **slab-primitives** | `Slab<Element>`: fixed-capacity typed allocation with RAII and bounds checking | Overlapping but distinct. Slab is raw typed allocation without the coordination layer (no initialization tracking, no spans, no bulk operations). If coordination is needed, use `Storage.Heap`. If only raw typed allocation is needed, this is a memory-tier concern. |

---

## Part II: Canonical Primitive Set

### 2.1 What Is Primitive vs Derived

A type is **primitive** if it appears independently across multiple paradigms, decades, and systems. A type is **derived** if it can be composed from primitives.

**Primitives** (irreducible storage forms from literature):

| Variant | Academic Source | Key Property | Reclamation |
|---------|---------------|--------------|-------------|
| **Inline** | Activation records, struct layout | Embedded in container, zero allocation | With container |
| **Heap** | Heap semantics, pointer machines | Independent lifetime, individual allocation | ARC/manual |
| **Arena/Region** | Tofte & Talpin 1997 | Bulk allocation, bulk free | Region reset |
| **Pool/Slab** | Bonwick 1994 | Fixed-size slot reuse, bounded capacity | Slot recycle |
| **View** | Borrowing, fat pointers, slices | Non-owning reference to existing storage | Never (doesn't own) |
| **External** | MMIO, foreign memory | Lifetime managed outside language runtime | External system |

**Derived** (composed from primitives):

| Type | Composed From | Composition |
|------|--------------|-------------|
| **COW/Shared** | Heap + reference counting | Heap storage with copy-on-write semantics |
| **Small** | Inline + Heap | Inline with heap spill on overflow |
| **Buffer.Ring** | Heap (or Inline) + access discipline | Storage + circular index arithmetic |
| **Buffer.Linear** | Heap (or Inline) + sequential access | Storage + linear read/write discipline |

**Intentionally excluded** (not storage primitives):

| Concept | Why Excluded |
|---------|-------------|
| Stack (as storage variant) | In Swift, stack vs heap is a compiler optimization, not a user-level storage choice. Inline captures the user-level intent. |
| Persistent/Immutable | This is a value discipline (structural sharing), not a storage variant. Implemented via COW at the ADT layer. |
| Weak/Unowned references | These are reference *disciplines*, not storage variants. Expressed through Swift's `weak`/`unowned`. |

### 2.2 Proposal A: Minimal — Two Primitives + Extensions

Keep the current split but rename for clarity.

```
Storage.Inline<Element, let capacity>   (current: Storage.Static)
Storage.Heap                   (current: Storage.Dynamic)
```

**What's primitive**: Inline and Heap.
**What's derived**: Everything else is composed at higher layers.
**What's excluded**: Arena, Pool, View, External — pushed to memory-primitives or higher layers.

**Rationale**: This matches what Swift can actually express today. Arena is already `Memory.Arena` at Tier 10. Pool requires runtime mechanisms (free lists) that may belong at a higher tier. View is `Span`. External is domain-specific.

### 2.3 Proposal B: Full Canonical Set — Six Primitives

Implement the full academically-derived set at the storage layer.

```
Storage.Inline<Element, let capacity>   ← Embedded, zero allocation
Storage.Heap                   ← Independent lifetime, ARC
Storage.Arena<Element>                  ← Typed wrapper over Memory.Arena
Storage.Pool<Element, let slotCount>    ← Fixed-size reusable slots
Storage.View<Element>                   ← Non-owning typed reference
Storage.External<Element>               ← Foreign memory bridge
```

**What's primitive**: All six.
**What's derived**: COW, Small, Ring, Linear — composed at ADT layer.
**What's excluded**: Stack (compiler-managed), Persistent (ADT-level).

### 2.4 Proposal C: Layered Split — Three at Storage, Three at Memory

Distribute primitives across tiers based on whether they are typed or untyped.

```
memory-primitives (Tier 10):
  Memory.Arena          ← Untyped bulk allocation (already exists)
  Memory.Pool           ← Untyped slot reuse (new)
  Memory.Buffer         ← Untyped view (already exists)

storage-primitives (Tier 12):
  Storage.Inline<E, N>  ← Typed inline storage
  Storage.Heap<E>       ← Typed heap storage
  Storage.External<E>   ← Typed foreign memory bridge
```

**Principle**: Memory-primitives handles untyped substrate concerns. Storage-primitives handles typed element concerns. Each variant appears at exactly one tier.

**What's primitive**: Six variants split across two tiers.
**What's derived**: Arena\<Element\> is `Memory.Arena` + typed access (via stdlib `UnsafeMutablePointer<Element>`). Pool\<Element\> is `Memory.Pool` + typed access.
**What's excluded**: View (use `Span<Element>` directly).

---

## Part III: Trade-off Analysis

### 3.1 Proposal A: Minimal (Two Primitives)

| Criterion | Assessment |
|-----------|------------|
| **Expressiveness** | Sufficient for current ADTs (Array, Queue, Stack, Deque, Heap, List all use Inline or Heap). Users needing arena/pool must compose manually. |
| **Cognitive load** | Minimal. Two types to learn. |
| **Implementation complexity** | Low. Already implemented (rename only). |
| **Scalability** | Limited. As ADTs grow (Slab, Graph), they'll need arena/pool and will reinvent them inconsistently. |
| **Research alignment** | Partial. Captures the most common axis (inline vs heap) but misses 4 of 6 canonical forms. |

**Risk**: The "users will reinvent" problem. Every ADT needing arena semantics will build its own, with inconsistent APIs, duplicated bugs, and no shared optimization.

### 3.2 Proposal B: Full Canonical Set (Six Primitives)

| Criterion | Assessment |
|-----------|------------|
| **Expressiveness** | Complete. Every canonical storage variant is first-class. |
| **Cognitive load** | Moderate. Six types, but each is self-explanatory with clear use cases. |
| **Implementation complexity** | High. Arena and Pool require careful lifetime and thread-safety design. External requires platform abstraction. |
| **Scalability** | Excellent. New ADTs pick from existing storage primitives without reinvention. |
| **Research alignment** | Full. Matches academic consensus exactly. |

**Risk**: Over-engineering. Storage.External may have no consumers for years. Storage.Pool's slab allocator semantics may be too low-level for most Swift users.

### 3.3 Proposal C: Layered Split (Three + Three)

| Criterion | Assessment |
|-----------|------------|
| **Expressiveness** | Complete. Same coverage as B, but distributed across tiers. |
| **Cognitive load** | Higher than B. User must understand which tier provides which variant, and compose typed wrappers manually for arena/pool usage. |
| **Implementation complexity** | Medium. Untyped variants at memory tier are simpler. Typed wrappers are thin. |
| **Scalability** | Good. Clean separation of concerns. Memory layer evolves independently. |
| **Research alignment** | Full, and respects the untyped/typed distinction. |

**Risk**: Composition overhead. Using `Memory.Arena` for typed elements requires manual typed pointer access via stdlib `UnsafeMutablePointer<Element>`, which is correct architecturally but adds API steps.

### 3.4 Comparison Matrix

| Criterion | A (Minimal) | B (Full) | C (Layered) |
|-----------|-------------|----------|-------------|
| Expressiveness | ★★☆☆ | ★★★★ | ★★★★ |
| Cognitive load | ★★★★ (low) | ★★★☆ | ★★☆☆ |
| Implementation effort | ★★★★ (low) | ★★☆☆ | ★★★☆ |
| Consistency with existing arch | ★★★★ | ★★☆☆ | ★★★★ |
| Long-term scalability | ★★☆☆ | ★★★★ | ★★★★ |
| Research alignment | ★★☆☆ | ★★★★ | ★★★★ |
| Avoids reinvention problem | ★☆☆☆ | ★★★★ | ★★★☆ |
| Swift-expressible today | ★★★★ | ★★★☆ | ★★★★ |

---

## Part IV: Recommendation

### 4.1 Recommended Approach: Proposal C (Layered Split) with Staged Rollout

**Primary recommendation**: Adopt Proposal C — distribute storage variants across the tier stack based on typed vs untyped semantics — with a staged implementation that starts from the current Proposal-A base and extends incrementally.

### 4.2 Rationale

1. **Respects existing architecture**. The memory→storage tier split embodies the untyped→typed progression. Arena and Pool at the memory tier is where they belong by the Integration Maximization Principle — typed access to them flows through stdlib pointer types naturally.

2. **Avoids the reinvention problem without over-engineering**. The current ADT catalog (data-structures-catalog.md) already lists `Slab` (arena-style allocation) and `Buffer.Slots.Bounded` (pool-like reuse). These will need storage primitives. But Storage.External can wait until there's a concrete consumer.

3. **Staged rollout manages risk**. Phase 1 is a rename (low risk). Phase 2 adds `Memory.Pool` (medium risk, well-understood from slab allocator literature). Phase 3 adds `Storage.External` only if/when needed.

4. **Matches the formal model**. The research consistently shows storage = placement × ownership × lifetime. The layered split maps these dimensions to the right tier:
   - Memory tier: placement + raw lifetime (untyped)
   - Storage tier: typed element management + initialization tracking

### 4.3 Concrete Design

#### Tier 10 (memory-primitives) — Untyped Substrate

```
Memory.Arena           ← EXISTS. Bump allocator with bulk reset.
Memory.Pool            ← NEW (when needed). Fixed-slot reuse with free list. Untyped bytes.
Memory.Buffer          ← EXISTS. Non-owning view of contiguous bytes.
Memory.Address         ← EXISTS. Byte-level position.
Memory.Allocator       ← EXISTS. Protocol + system allocator.
```

Typed pointer access uses Swift stdlib types directly: `UnsafeMutablePointer<Element>`, `UnsafePointer<Element>`, `Span<Element>`, `MutableSpan<Element>`.

#### Tier 12 (storage-primitives) — Typed Element Storage

```
Storage.Heap                  ← EXISTS. ARC-managed ManagedBuffer.
Storage.Inline<Element, let capacity>  ← EXISTS. @_rawLayout for element-sized slots.

Storage.Initialization  ← EXISTS. Tracks which slots are initialized.
Storage.Span            ← EXISTS. Range of initialized slots.
Index<Storage>            ← EXISTS. Physical slot coordinate.
Storage.Header          ← EXISTS. ManagedBuffer header.
```

Two storage variants. Complete for all ADT storage needs.

#### Tier 13 (buffer-primitives) — Access Discipline

```
Buffer.Ring         → circular access discipline over Storage.Heap
Buffer.Linear       → sequential access discipline
Buffer.Slots        → indexed slot access with occupancy tracking
```

#### Tier 14+ (ADT packages) — Derived Variants

```
Array               → uses Storage.Heap (growable)
Array.Static<N>     → uses Storage.Inline (fixed capacity)
Array.Small<N>      → uses Storage.Inline + Storage.Heap (spill, composed at ADT layer)
Queue               → uses Buffer.Ring → Storage.Heap
Stack               → uses Storage.Heap
```

### 4.4 Ownership and Reference Semantics — Not Separate Packages

Based on the analysis in §1.4, ownership and reference semantics do NOT warrant their own primitives packages. They are cross-cutting concerns expressed through Swift's type system at every layer:

| Concern | How It's Already Expressed |
|---------|---------------------------|
| Unique ownership | `~Copyable` types, `consuming` parameters |
| Shared ownership | ARC (class-based storage), conditional `Copyable` |
| Borrowing | `borrowing` parameters, `Span` (non-escapable) |
| Move semantics | `consuming` parameters, `~Copyable` |
| Lifetimes | `@_lifetime` annotations, `~Escapable` |
| Mutability | `mutating` methods, `UnsafeMutablePointer` vs `UnsafePointer` |

**What does need documentation**: A normative document (skill) that codifies how these Swift features map to the academic ownership/reference model. The `memory` and `memory-safety` skills already cover most of this. They should be updated to include the formal mapping.

### 4.5 What Moves Where in the Current Implementation

Based on the first-principles research observation that `Storage.Ring` is access discipline (not storage):

| Current | Proposed | Rationale |
|---------|----------|-----------|
| `Storage.Static<E, N>` | `Storage.Inline<E, N>` | Clarifies placement semantics — **DONE** |
| `Storage.Dynamic<E>` | `Storage.Heap<E>` | Clarifies lifetime semantics — **DONE** |
| `Storage.Ring` (if present) | Move to ADT layer | Access discipline, not storage |
| `Storage.Heap.Header` | Keep (part of Heap) | Metadata for ManagedBuffer header |
| `Storage.Initialization` | Keep | Fundamental to any typed storage |
| `Storage.Span` | Keep | Fundamental to initialization tracking |
| `Index<Storage>` | Keep | Physical coordinate system |

### 4.6 Staged Implementation Plan

**Phase 1: Rename and Clarify** — **COMPLETED 2026-02-03**
- Renamed `Storage.Static` → `Storage.Inline`
- Renamed `Storage.Dynamic` → `Storage.Heap`
- Updated all dependents (buffer, array, set, dictionary, heap, stack primitives)
- Module names updated: "Storage Dynamic Primitives" → "Storage Heap Primitives", "Storage Static Primitives" → "Storage Inline Primitives"

**Phase 2: Memory.Pool** (when Slab or Buffer.Slots implementation begins)
- Add `Memory.Pool` to memory-primitives
- Untyped fixed-slot allocator with free list
- Typed access via stdlib `UnsafeMutablePointer<Element>`

**Phase 3: Storage.External** (when MMIO/GPU consumer exists)
- Add typed foreign memory bridge
- Requires investigation of platform-specific access protocols

### 4.7 Open Questions

| ID | Question | Blocking? |
|----|----------|-----------|
| OQ-1 | Should `Storage.Inline` remain unconditionally `~Copyable` (due to `@_rawLayout`), or should conditional `Copyable` be achieved through compiler improvements? | No — current design is sound; `@_rawLayout` requires ~Copyable |
| OQ-2 | Should `Memory.Pool` live at Tier 10 or get its own tier? | No — Tier 10 is correct (same abstraction level as Arena) |
| OQ-3 | Does `Storage.Heap.Header` generalize across Heap and Arena, or is it Heap-specific? | Yes — needs investigation before Phase 2 |

---

## Part V: Research Corpus Status

### 5.1 Current Documents (swift-storage-primitives/Research/)

| Document | Topic | Status |
|----------|-------|--------|
| storage-ownership-reference-synthesis | Master synthesis (this document) | DECISION |
| storage-contiguous-api-design | Span API surface | DECISION |
| storage-contiguous-protocol-conformance | Span.Protocol conformance | DECISION |
| storage-inline-invariants | Complete invariant catalog | DECISION |
| inline-slot-type-organization | @_rawLayout recommendation | RECOMMENDATION |
| inline-storage-read-pointer-escape | Closure-based pointer access | DECISION |
| ring-buffer-index-arithmetic | Cyclic index arithmetic | DECISION |
| Collection Primitives Architecture | ADT storage patterns | DECISION |

### 5.2 Relocated Documents

| Document | New Location | Reason |
|----------|--------------|--------|
| buffer-algebraic-structure | swift-memory-primitives/Research/ | Buffer is memory-level concept |
| buffer-base-nullability | swift-memory-primitives/Research/ | Buffer is memory-level concept |
| integration-maximization-comparative-analysis | swift-primitives/Research/ | Cross-package analysis |
| finite-collection-join-point-integration | swift-primitives/Research/ | Ecosystem-level pattern |
| range-sequence-collection-semantic-analysis | swift-primitives/Research/ | Collection semantics |
| data-structures-catalog | swift-institute/Documentation.docc/ | Reference catalog |

### 5.3 Architectural Changes Since v2.0

| Change | Impact |
|--------|--------|
| `@_rawLayout` migration | Eliminates 64-byte slot overhead; elements stored at natural stride |
| Element-sized slots | Physical slot = logical element position (1:1 correspondence) |
| Span support for Inline | Now possible for Copyable elements (dense layout) |
| `Storage.Span` superseded | Use `Range<Index<Storage>>` for slot ranges |

---

## Part VI: Formal Semantics

### 6.1 Storage Typing Rules

```
Γ ⊢ s : Storage.Inline<T, N>
─────────────────────────────── (INLINE-OWNS)
lifetime(s) = lifetime(container(s))
Γ owns s exclusively

Γ ⊢ s : Storage.Heap<T>
─────────────────────────────── (HEAP-OWNS)
lifetime(s) = ARC(refcount(s) > 0)
Γ owns s, may share via ARC

Γ ⊢ a : Memory.Arena
Γ ⊢ p : UnsafeMutablePointer<T> allocated-in a
─────────────────────────────── (ARENA-ACCESS)
lifetime(p) ≤ lifetime(a)
Γ borrows p from a

Γ ⊢ s : Span<T>
─────────────────────────────── (VIEW-BORROWS)
lifetime(s) ≤ lifetime(source(s))
Γ borrows s, read-only
```

### 6.2 Layer Separation Rules

```
Γ ⊢ adt : ADT<T>
adt uses buf : Buffer.Ring<T>
buf uses s : Storage.Heap<T>
─────────────────────────────── (LAYER-SEPARATION)
adt does NOT access s directly
adt accesses s only through buf's API

Γ ⊢ s : Storage.Heap<T>
s uses p : UnsafeMutablePointer<T>   (stdlib)
─────────────────────────────── (TIER-CHAIN)
s accesses elements through stdlib pointer types
s uses ManagedBuffer for allocation/deallocation
```

---

## References

### Academic Foundations

1. Scott, D. & Strachey, C. (1971). "Toward a Mathematical Semantics for Computer Languages"
2. Girard, J.-Y. (1987). "Linear Logic" — TCS 50
3. Wadler, P. (1990). "Linear Types Can Change the World!"
4. Bonwick, J. (1994). "The Slab Allocator" — USENIX Summer
5. Tofte, M. & Talpin, J.-P. (1997). "Region-Based Memory Management" — Info & Comp 132
6. Clarke, D. et al. (1998). "Ownership Types for Flexible Alias Protection" — OOPSLA
7. Reynolds, J.C. (2002). "Separation Logic" — LICS
8. Boyland, J. (2003). "Fractional Permissions" — SAS
9. Boyapati, C. et al. (2003). "Ownership Types for Safe Region-Based Memory Management"
10. Walker, D. (2005). "Substructural Type Systems" — ATTAPL
11. Jung, R. et al. (2018). "RustBelt" — POPL
12. Weiss, A. et al. (2019-2021). "Oxide: The Essence of Rust"

### Internal Research

See `_index.json` for current document inventory.
