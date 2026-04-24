# Storage Primitives: State of the Art vs Theoretical Perfect

<!--
---
version: 1.1.0
last_updated: 2026-02-06
status: RECOMMENDATION
research_tier: 3
applies_to: [swift-storage-primitives, swift-memory-primitives, swift-buffer-primitives, swift-ownership-primitives]
normative: false
---
-->

@Metadata {
    @TitleHeading("Swift Primitives Research")
}

A systematic comparative analysis of `swift-storage-primitives` against the global state of the art and a theoretically ideal storage substrate, identifying where the ecosystem leads, where it lags, and where no prior art exists for the approach taken.

## Abstract

This document evaluates `swift-storage-primitives` (Tier 14) along seven analytical dimensions against state-of-the-art implementations in Rust, C++, and Zig, as well as against theoretical foundations from region-based memory management, substructural type systems, and separation logic. The analysis establishes that Swift Primitives occupies a **novel position** in the design space: it is the only production system that combines typed physical coordinates, automatic per-slot initialization tracking, first-class ~Copyable element support, and a layered storage-above-allocator separation in a Foundation-free, embedded-compatible substrate.

**Principal Findings**:

1. **Leads state of the art**: Per-slot initialization tracking via BitVector (automatic, zero-caller-responsibility), typed physical coordinates via `Index<Element>`, and the tracked accessor pattern (`storage.initialize.next(to:)`) have no equivalent in any surveyed system
2. **Matches state of the art**: Heap/inline separation, `~Copyable` element support, ManagedBuffer-based heap storage, and `@_rawLayout`-based inline storage are competitive with Rust's SmallVec/ArrayVec and C++26's `inplace_vector`
3. **Behind state of the art**: No allocator parameterization (unlike Rust's `Vec<T, A>`), no storage trait abstraction (unlike Rust's Store RFC), no arena/pool storage variants at the storage tier, and no formal verification framework
4. **Novel territory**: The combination of typed coordinates + automatic tracking + ~Copyable + layered integration has no direct precedent and represents a design point not explored in the literature

**Key Contributions**:

- Seven-dimension evaluation framework for storage substrate packages (Section 4)
- Gap analysis with prioritized recommendations (Section 8)
- Theoretical perfect specification against which real systems can be measured (Section 6)
- Cross-ecosystem abstraction taxonomy (Section 3)

---

## Part I: Context and Scope

### 1.1 Research Trigger

Per [RES-012], this is a **Discovery** research document. The trigger is a proactive audit: `swift-storage-primitives` has reached sufficient maturity (per-slot tracking implemented, contiguous API designed, extensive test coverage) that a systematic comparison against the global state of the art is warranted.

### 1.2 Scope

Per [RES-002a], this research is **primitives-wide** (storage-primitives at Tier 14 defines the substrate for buffer-primitives at Tier 15, which in turn serves all collection primitives).

| Criterion | Assessment |
|-----------|------------|
| Packages directly affected | swift-storage-primitives |
| Packages indirectly affected | swift-buffer-primitives, swift-memory-primitives, all collection primitives |
| Tiers spanned | 13 (memory) → 14 (storage) → 15 (buffer) |
| Precedent-setting | Yes — establishes the evaluation framework for substrate packages |
| Research tier | Tier 3 (establishes long-lived semantic contract, ecosystem-wide implications) |

### 1.3 Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| No Foundation | PRIM-FOUND-001 | Cannot use Foundation.Data, NSMutableData, etc. |
| Swift Embedded compatible | Primitives Requirements | No reflection, no ObjC interop |
| ~Copyable support | Memory skill | All storage must handle non-copyable elements |
| Downward-only dependencies | Primitives Tiers | Storage (14) cannot depend on Buffer (15) |
| Nest.Name pattern | API-NAME-001 | All types must use `Storage.X` namespace |
| One type per file | API-IMPL-005 | Organizational constraint |
| Typed throws | API-ERR-001 | Any error-throwing APIs must use typed throws |

### 1.4 Methodology

Per [RES-004], [RES-013], and [RES-023]:

| Step | Action | Output |
|------|--------|--------|
| 1 | Define evaluation dimensions | Seven-axis framework |
| 2 | Survey state of the art | Rust, C++, Zig, research allocators |
| 3 | Survey theoretical foundations | Region types, linear types, separation logic |
| 4 | Define "theoretical perfect" | Idealized design with no engineering constraints |
| 5 | Evaluate current design | Per-dimension scoring |
| 6 | Identify gaps | Prioritized gap list |
| 7 | Recommend | Actionable next steps |

---

## Part II: Prior Art Survey

### 2.1 Rust Ecosystem

#### 2.1.1 Allocator Trait (Nightly)

The `Allocator` trait provides an untyped allocation interface operating on `Layout` (size + alignment):

```rust
pub unsafe trait Allocator {
    fn allocate(&self, layout: Layout) -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn deallocate(&self, ptr: NonNull<u8>, layout: Layout);
    fn allocate_zeroed(&self, layout: Layout) -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn grow(&self, ptr: NonNull<u8>, old: Layout, new: Layout) -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn shrink(&self, ptr: NonNull<u8>, old: Layout, new: Layout) -> Result<NonNull<[u8]>, AllocError>;
}
```

Collections parameterize over allocators: `Vec<T, A: Allocator = Global>`. This enables arena-backed vectors, pool-backed vectors, etc. without changing the collection's logic.

**Limitation**: Cannot express inline storage — pointers within `self` would be invalidated on move.

#### 2.1.2 Store RFC (RFC 3446, Draft)

The Store RFC (matthieu-m) introduces an abstract `Handle` type to replace raw pointers:

```rust
unsafe trait StoreSingle: StoreDangling {
    type Handle;
    unsafe fn resolve(&self, handle: Self::Handle) -> NonNull<u8>;
    fn allocate(&mut self, layout: Layout) -> Result<(Self::Handle, usize), AllocError>;
    unsafe fn deallocate(&mut self, handle: Self::Handle, layout: Layout);
}
```

The key innovation: `Handle` can be a pointer (heap), a `()` unit (single-element inline), an offset (shared memory), or an index (arena). Collections parameterize over `S: StoreSingle`, gaining inline storage, shared memory, and arena support through a single abstraction.

Marker traits provide additional guarantees:
- `StoreStable`: Handle resolution returns same pointer across calls
- `StorePinning`: Handles survive store moves

**Relevance**: This is the closest external equivalent to Swift Primitives' storage abstraction, but it operates at the untyped `Layout` level without typed coordinates or initialization tracking.

#### 2.1.3 SmallVec / ArrayVec / TinyVec

- **SmallVec<[T; N]>**: Inline storage with heap spill. Uses union for inline/heap discrimination. No initialization tracking beyond `len`.
- **ArrayVec<T, N>**: Fixed-capacity inline-only. Uses `MaybeUninit<[T; N]>` + `len: usize`.
- **TinyVec<[T; N]>**: Like SmallVec but avoids `unsafe` by requiring `T: Default`.

None of these track per-slot initialization. All use a single `len` counter assuming linear (contiguous from 0) initialization.

#### 2.1.4 Slab Crate

Pre-allocated typed storage with O(1) insert/remove. Uses `Vec<Entry<T>>` where `Entry` is `Occupied(T) | Vacant(next_free)`. Tracks occupancy per-slot via the enum discriminant — conceptually similar to per-slot tracking but with higher overhead (full enum per slot vs. one bit).

#### 2.1.5 Bumpalo / typed-arena

Arena allocators providing batch allocation with collective deallocation. Bumpalo is untyped (bump pointer into byte slabs); typed-arena constrains to a single type. Neither tracks per-element initialization independently — the arena owns everything allocated within it.

#### 2.1.6 RawVec

Rust's internal `RawVec<T, A>` separates allocation from collection logic. It manages a `NonNull<T>` pointer and a capacity, delegating to an `Allocator`. `Vec<T, A>` wraps `RawVec<T, A>` and adds `len` for initialization tracking. This separation is analogous to Swift's Storage.Heap providing raw storage while higher-level collections track logical state.

### 2.2 C++ Ecosystem

#### 2.2.1 std::allocator and PMR

C++'s allocator model evolved through three phases:

1. **Classic (C++98)**: `std::allocator<T>` — typed, stateless, rebindable via `rebind<U>::other`. Universally criticized as over-complicated.
2. **PMR (C++17)**: `std::pmr::memory_resource` — untyped virtual base class. Runtime polymorphism via vtable. Concrete resources: `monotonic_buffer_resource` (arena), `pool_resource`, `synchronized_pool_resource`.
3. **Allocator-aware containers**: `std::pmr::vector<T>` = `std::vector<T, std::pmr::polymorphic_allocator<T>>`.

**Strength**: PMR provides runtime-switchable allocation strategies without changing container types.
**Weakness**: Virtual dispatch overhead, no compile-time specialization, no inline storage through allocator mechanism.

#### 2.2.2 inplace_vector (C++26, P0843)

`std::inplace_vector<T, N>` provides fixed-capacity inline storage:

- Contiguous, stores elements within the object itself
- `constexpr`-compatible for trivial types
- Throws `std::bad_alloc` on capacity overflow (or use `try_push_back`)
- Maximum 2^16 - 1 elements
- Tracks initialization via `size_type` counter (linear only, like ArrayVec)

No per-slot tracking, no sparse patterns, no ring buffer support.

#### 2.2.3 folly::small_vector / Boost.Container::small_vector

SBO (Small Buffer Optimization) vectors: inline storage with heap spill. `folly::small_vector<T, N>` stores N elements inline, spills to heap on overflow. Customizable size type and `NoHeap` policy.

These are **collection-level** SBO, not **storage-level** abstractions. The inline/heap transition is internal to the collection, not a composable storage primitive.

### 2.3 Zig Ecosystem

#### 2.3.1 std.mem.Allocator

Zig's allocator is a runtime-polymorphic interface (function pointer vtable):

```zig
pub const Allocator = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        alloc: *const fn (...) ?[*]u8,
        resize: *const fn (...) bool,
        remap: *const fn (...) ?[*]u8,
        free: *const fn (...) void,
    };
};
```

Allocators are passed explicitly to all containers and operations. Composable: `ArenaAllocator` wraps a child allocator, `FixedBufferAllocator` operates on a stack-provided buffer.

**Strength**: Explicit, composable, no hidden allocations.
**Weakness**: Runtime polymorphism only, no typed coordinates, no initialization tracking, no move-only type system.

### 2.4 Research Allocators

| Allocator | Architecture | Key Innovation |
|-----------|-------------|----------------|
| **mimalloc** | Arena → Segment → Page → Block | Free list sharding per page; 2-branch fast path |
| **Mesh** | Span + MiniHeap + virtual memory remapping | Compaction without relocation; breaks Robson bound |
| **jemalloc** | Arena → Bin → Slab → Run | Thread caches; 4 sizes per doubling |
| **snmalloc** | Message-passing cross-thread deallocation | Single atomic op per 1000s of remote frees |
| **TCMalloc** | Per-CPU cache → Transfer cache → Page heap | Hugepage-aware; restartable sequences |

These operate at a **lower layer** than storage primitives — they are system allocators that storage primitives would sit atop. The relevant observation is that all use some form of **per-slot or per-block occupancy tracking** (bitmaps in mimalloc pages, entry states in slab, etc.), validating the per-slot tracking approach in storage-primitives.

### 2.5 Theoretical Foundations

#### 2.5.1 Region-Based Memory Management (Tofte-Talpin, 1994)

Extends the lambda calculus with **regions** — named memory areas with stack discipline:

```
letregion r in e    -- create region r, evaluate e, deallocate r
e at r              -- allocate result of e in region r
```

Region lifetimes are inferred. All allocations within a region are freed collectively when the region exits scope.

**Relevance**: `Storage.Heap` conceptually implements a single-region storage where all elements share the ARC-managed lifetime of the `ManagedBuffer`. `Storage.Inline` implements a stack-scoped region bounded by the struct's lifetime.

#### 2.5.2 Linear Types and Substructural Type Systems

| Type System | Weakening (drop) | Contraction (copy) | Use Count |
|-------------|-------------------|--------------------|-----------|
| Unrestricted | Yes | Yes | Any |
| Affine | Yes | No | ≤ 1 |
| Linear | No | No | = 1 |
| Ordered | No (+ no exchange) | No | = 1, in order |

Swift's `~Copyable` implements **affine semantics**: values can be consumed (moved) but not copied. The `consuming` parameter convention transfers ownership.

**Relevance**: Storage.Inline's `~Copyable` constraint (it is always non-copyable due to `@_rawLayout`) enforces that storage lifetime is tied to a single owner. Elements within storage follow the element's own copyability rules.

#### 2.5.3 Separation Logic

Reynolds and O'Hearn's (2002) separating conjunction `P * Q` asserts disjoint heap ownership. The frame rule enables local reasoning: operations on one heap region provably do not affect other regions.

**RustBelt** (Jung et al., POPL 2018) uses Iris (Coq-based separation logic) to provide machine-checked safety proofs for Rust's ownership model.

**Relevance**: Storage.Inline's per-slot BitVector can be seen as a **concrete reification of separation logic predicates** — each bit asserts "this slot is owned (initialized) by the storage." Operations maintain the invariant that set bits correspond to initialized slots and clear bits to uninitialized slots. This is not formally verified but structurally corresponds to the assertions a separation logic proof would maintain.

#### 2.5.4 Linear Regions Are All You Need (Fluet, Morrisett, Ahmed, ESOP 2006)

Showed that a single substructural type system (`λ_rgnUL`) can encode both lexically-scoped regions (Tofte-Talpin) and dynamic regions (Cyclone) by using **linear capabilities** to control region lifetime.

**Relevance**: A theoretically perfect storage system would use linear capabilities to track which storage regions are accessible. Swift's `~Copyable` provides the affine fragment but lacks the ability to enforce "exactly once" (linear) usage at the type level.

#### 2.5.5 Typed Memory Management via Capabilities (Walker, 2003)

Models memory access permissions as capabilities with algebraic composition rules (splitting, joining, weakening). A capability calculus provides formal guarantees about which regions of memory a computation may access.

**Relevance**: `Index<Element>` functions as a typed capability — it grants access to a specific physical slot in storage. The type parameter constrains which storage the index can be used with. This is an informal, partial implementation of the capability calculus idea.

---

## Part III: State of the Art Abstraction Taxonomy

### 3.1 Cross-Ecosystem Feature Matrix

| Feature | Swift (storage-primitives) | Rust (current) | Rust (Store RFC) | C++ (PMR + inplace_vector) | Zig |
|---------|---------------------------|----------------|-------------------|-----------------------------|-----|
| **Typed coordinates** | `Index<Element>` | Raw `usize` | Raw index via Handle | Raw `size_t` | Raw `usize` |
| **Per-slot init tracking** | BitVector (auto) | `len` only | No | `size_t` only | No |
| **~Copyable/Move-only** | First-class | First-class (default) | First-class | Since C++11 | N/A (all byte-copyable) |
| **Inline storage** | `Storage.Inline<N>` | SmallVec/ArrayVec (ad-hoc) | `InlineStorage<N>` (unified) | `inplace_vector<T,N>` (separate) | `FixedBufferAllocator` (runtime) |
| **Heap storage** | `Storage.Heap` (ManagedBuffer) | `RawVec<T, A>` (allocator-generic) | `AllocatorStorage<A>` (unified) | `vector<T>` (allocator-generic) | `ArrayList` (allocator-generic) |
| **Allocator parameterization** | No | `Vec<T, A>` | `Vec<T, S>` | `vector<T, Allocator>` | Explicit allocator |
| **Storage trait** | No (concrete types) | No (Allocator trait only) | `StoreSingle`/`StoreMultiple` | No (`memory_resource` is allocator) | No (Allocator only) |
| **Arena at storage tier** | No (in memory-primitives) | Via bumpalo | Via Store impl | `monotonic_buffer_resource` | `ArenaAllocator` |
| **Pool at storage tier** | No (in memory-primitives) | Via crate | Via Store impl | `pool_resource` | No standard |
| **Tracked operations** | `initialize.next(to:)` etc. | No | No | No | No |
| **Sparse init patterns** | Yes (BitVector) | No | No | No | No |
| **Foundation-free** | Yes | N/A | N/A | N/A | N/A |
| **Embedded-compatible** | Yes | `no_std` | `no_std` | Freestanding subset | Yes |
| **Formal safety proof** | No | RustBelt (for std types) | No | No | No |

### 3.2 Architectural Comparison

**Swift Primitives**:
```
Collection (Queue, Deque, Heap)
        ↓ uses
Buffer (Linear, Ring, Slab)
        ↓ uses
Storage (Heap, Inline)         ← THIS PACKAGE
        ↓ uses
Pointer (UnsafeMutablePointer<T>)
        ↓ uses
Memory (Memory.Address, Memory.Arena, Memory.Pool)
```

**Rust (Current)**:
```
Collection (Vec, VecDeque, HashMap)
        ↓ parameterized by
Allocator (Global, System, bumpalo::Bump)
        ↓ provides
Raw memory (NonNull<u8>)
```

**Rust (Store RFC)**:
```
Collection (Vec<T, S>, VecDeque<T, S>)
        ↓ parameterized by
Store (InlineStorage, AllocatorStorage, SmallStorage)
        ↓ provides
Handle (pointer, unit, offset)
        ↓ resolves to
Raw memory (NonNull<u8>)
```

**C++ PMR**:
```
Container (pmr::vector, pmr::deque)
        ↓ uses
polymorphic_allocator<T>
        ↓ delegates to
memory_resource (monotonic, pool, new_delete)
        ↓ provides
Raw memory (void*)
```

**Key Architectural Differences**:

1. **Swift separates Storage from Allocator/Memory**: `Memory.Arena` and `Memory.Pool` are at Tier 13. `Storage.Heap` and `Storage.Inline` are at Tier 14. `Buffer.Linear`, `Buffer.Ring`, `Buffer.Slab` are at Tier 15. Three distinct layers.

2. **Rust (Store RFC) unifies inline/heap/arena into one trait**: A single `StoreSingle` trait abstracts over all storage strategies. Collections see only `Handle` and `resolve`.

3. **C++ separates allocator from container but not storage from allocator**: PMR's `memory_resource` is an allocator, not a storage abstraction. `inplace_vector` is a separate container, not a storage variant.

4. **Zig does not separate**: Allocator is the only abstraction; storage is implicit in the allocator implementation.

---

## Part IV: Evaluation Framework

### 4.1 Seven Evaluation Dimensions

| # | Dimension | Question | Weight |
|---|-----------|----------|--------|
| D1 | **Type Safety** | How much compile-time safety does the storage API provide? | Critical |
| D2 | **Initialization Correctness** | How is element lifecycle tracked and enforced? | Critical |
| D3 | **Composability** | Can storage be parameterized, swapped, or composed? | High |
| D4 | **~Copyable Support** | How well does storage handle non-copyable elements? | High |
| D5 | **Performance** | What is the overhead of the storage abstraction? | High |
| D6 | **Completeness** | Does the storage cover all common patterns (inline, heap, arena, pool)? | Medium |
| D7 | **Formal Guarantees** | Are safety properties formally specified or verified? | Medium |

### 4.2 Scoring Scale

| Score | Meaning |
|-------|---------|
| 5 | Best known — no system does this better |
| 4 | Competitive — matches state of the art |
| 3 | Adequate — meets requirements but opportunities exist |
| 2 | Gap — behind state of the art in meaningful ways |
| 1 | Missing — critical capability absent |

---

## Part V: Current State Evaluation

### 5.1 D1: Type Safety

**Score: 5 (Best Known)**

No surveyed system provides typed physical coordinates for storage slot access.

| Aspect | Swift Primitives | Best Alternative |
|--------|------------------|------------------|
| Slot addressing | `Index<Element>` (phantom-typed) | `usize` / `size_t` (untyped) |
| Count types | `Index<Element>.Count` (phantom-typed) | `usize` / `size_t` (untyped) |
| Offset types | `Index<Element>.Offset` (phantom-typed) | `isize` / `ptrdiff_t` (untyped) |
| Pointer types | `UnsafeMutablePointer<Element>` (stdlib) | `*mut T` / `T*` (typed) |

Swift Primitives uses phantom types (`Tagged<Tag, RawValue>`) at the index and memory address levels:

```
Index<Element>           = Tagged<Element, Ordinal>
Index<Element>.Count     = Tagged<Element, Cardinal>
Index<Element>.Offset    = Tagged<Element, Affine.Discrete.Vector>
Memory.Address           = Tagged<Memory, Ordinal>
```

Pointer access uses stdlib types directly (`UnsafePointer<Element>`, `UnsafeMutablePointer<Element>`). The phantom safety boundary is at the index/address level, not the pointer level — `storage.pointer(at:)` converts a phantom-typed `Index<Element>` into a stdlib pointer.

This means an `Index<Int>` cannot be confused with an `Index<String>` at compile time — a category of bug that is possible in every other surveyed system.

**Evidence**: In the integration maximization analysis, storage-primitives achieves 100% Direct Integration Ratio and 94% API Surface Coverage, confirming that typed coordinates are used consistently throughout.

### 5.2 D2: Initialization Correctness

**Score: 5 (Best Known)**

No surveyed system provides automatic per-slot initialization tracking.

| System | Tracking Mechanism | Granularity | Automatic? |
|--------|-------------------|-------------|------------|
| **Swift (Inline)** | BitVector (256 bits) | Per-slot | Yes |
| **Swift (Heap)** | Range enum (.empty/.one/.two) | Per-range | Partially (tracked accessors) |
| Rust Vec | `len: usize` | Linear only | Yes (for push/pop) |
| Rust slab | Enum per entry (Occupied/Vacant) | Per-slot | Yes (but full enum overhead) |
| C++ inplace_vector | `size_type` | Linear only | Yes (for push/pop) |
| C++ PMR | None (resource level) | N/A | N/A |
| Zig | None (convention) | N/A | No |

Swift's `Storage.Inline` is unique in several ways:

1. **Auto-updating**: `initialize(to:at:)` sets the bit, `move(at:)` clears the bit, `deinitialize(at:)` clears the bit. No caller action required.
2. **Sparse patterns**: Arbitrary subsets of slots can be initialized (not just contiguous ranges).
3. **Correct deinit**: `deinit` iterates only set bits, cleaning up exactly the initialized slots.
4. **Compact**: 32 bytes (4 × UInt64) covers 256 slots. Rust's slab uses a full enum per entry (≥2 bytes per slot).

The tracked accessor pattern on `Storage.Heap` (`heap.initialize.next(to:)`, `heap.move.last()`, `heap.deinitialize.all()`) provides safe linear-discipline operations that automatically maintain the initialization range. This has no equivalent in other systems.

**Trade-off acknowledged**: `Storage.Heap` still has manual state management for non-linear patterns. The per-slot-tracking research document recommended potentially extending BitVector tracking to Heap as well.

### 5.3 D3: Composability

**Score: 3 (Principled Gap)**

The composability gap is real but narrower than initially assessed, because the architecture addresses composability through a different mechanism than Rust's protocol-based approach.

| Capability | Swift Primitives | Rust (Store RFC) | C++ PMR |
|------------|------------------|-------------------|---------|
| Collections generic over storage | Via variant system (Base/Bounded/Inline/Small) | `Vec<T, S: StoreSingle>` | `pmr::vector<T>` |
| Swap storage strategy without changing collection | At collection level (variant selection) | At storage level (change `S` parameter) | At resource level (change resource) |
| Compose inline → heap fallback | At Buffer tier (Buffer.Linear) | `SmallStorage<Inline, Alloc>` | `monotonic_buffer_resource` chains |
| User-provided storage | No | Any `StoreSingle` impl | Any `memory_resource` subclass |
| Arena-backed storage | Not yet at storage tier | Via `BumpStore` | `monotonic_buffer_resource` |

**Current situation**: `Storage.Heap` and `Storage.Inline` are concrete types. Higher-layer collections (in `buffer-primitives` and above) choose between them via the variant system (e.g., `Stack` uses Heap, `Stack.Bounded` uses Inline). There is no `Storage.Protocol` for parameterization — and this is a deliberate decision (see §8.3).

**Why this scores 3, not 2**: The variant system already solves the user-facing problem: selecting storage strategy. A user chooses `Stack.Bounded` for inline storage, `Stack` for heap storage. The remaining gap is that Arena and Pool storage variants do not yet exist at the storage tier, forcing users to drop to the Memory tier for those strategies.

**Why this scores 3, not 4**: The absence of Arena and Pool at the storage tier means users cannot get typed coordinates, initialization tracking, and tracked accessors for arena-backed or pool-backed data structures. Adding `Storage.Arena` and `Storage.Pool` (see §8.2) would close this gap.

**Architectural context**: The Swift Primitives architecture deliberately separates concerns across tiers:
- Memory tier (13): Raw allocation strategies (Arena, Pool)
- Storage tier (14): Element lifecycle over raw allocations
- Buffer tier (15): Growth policies and inline→heap transitions

This is a **principled architectural choice**, not an oversight. Composability is achieved by completing the variant catalog at each tier, not by introducing a storage protocol (see §8.3 for analysis).

### 5.4 D4: ~Copyable Support

**Score: 4 (Competitive)**

Swift and Rust both provide first-class support for non-copyable types in storage.

| Aspect | Swift Primitives | Rust |
|--------|------------------|------|
| Non-copyable elements | `~Copyable` constraint throughout | Default (all types are move-only) |
| Conditional copyability | `Storage.Heap: Copyable where Element: Copyable` | Automatic (`Clone` derives) |
| Consuming operations | `consuming Element` parameter | `T` (by value = ownership transfer) |
| Borrowing operations | `borrowing` / `@_lifetime(borrow self)` | `&T` / `&mut T` |
| Separate API surface | Copyable-only extensions (copy, span) | No separate surface needed |

**Swift advantage**: Explicit `Copyable` vs `~Copyable` extension split makes it impossible to accidentally copy a non-copyable element — the API surface itself is different.

**Swift gap**: `Storage.Inline` is *always* `~Copyable` (due to `@_rawLayout`), even when `Element: Copyable`. This means inline-stored copyable elements cannot be trivially duplicated at the storage level. Rust's `ArrayVec<T, N>` is `Clone` when `T: Clone`.

**Rust advantage**: Rust's ownership model is more mature (since 1.0). The borrow checker provides compile-time guarantees that Swift approximates through `@_lifetime` annotations and runtime exclusivity checks.

### 5.5 D5: Performance

**Score: 4 (Competitive)**

| Operation | Swift Primitives | Best Alternative | Notes |
|-----------|------------------|------------------|-------|
| Inline slot access | `pointer(at:)` → raw offset | Direct array access | Both O(1), similar codegen |
| Heap slot access | `pointer(at:)` via ManagedBuffer | `RawVec` pointer + offset | Both O(1), Swift has ARC overhead |
| Init tracking overhead | 1 bit per slot (32B fixed) | 0 bits (len counter) | Swift pays 32B for correctness |
| Heap allocation | ManagedBuffer (ARC) | `RawVec<T, A>` (any allocator) | Swift cannot use arena/pool |
| Span access | `@_lifetime(borrow self)` | Zero-cost borrow | Both zero-cost for reads |

**ARC consideration**: `Storage.Heap` uses `ManagedBuffer`, which implies ARC (reference counting). This adds overhead compared to Rust's `RawVec<T, A>` which uses no reference counting. However, this enables CoW (Copy-on-Write) for `Copyable` elements, which Rust's standard `Vec` does not provide.

**BitVector overhead**: The 32-byte BitVector in `Storage.Inline` is a correctness-for-space trade-off. For capacities ≤ 64, this is 8 bytes more than a simple `len` counter. For capacities 65-256, it provides strictly more information (sparse patterns) with the same or less overhead than alternative per-slot tracking (Rust's slab uses ≥ 2 bytes per slot).

### 5.6 D6: Completeness

**Score: 3 (Adequate)**

| Storage Pattern | Swift Primitives | Present? | Layer |
|----------------|------------------|----------|-------|
| Heap (dynamic) | `Storage.Heap` | Yes | Storage (14) |
| Inline (fixed) | `Storage.Inline<N>` | Yes | Storage (14) |
| Arena | `Memory.Arena` | Yes, but lower tier | Memory (13) |
| Pool | `Memory.Pool` | Yes, but lower tier | Memory (13) |
| SBO (inline → heap) | `Buffer.Linear` | Yes, but higher tier | Buffer (15) |
| Ring buffer storage | `Buffer.Ring` | Yes, but higher tier | Buffer (15) |
| Slab storage | `Buffer.Slab` | Yes, but higher tier | Buffer (15) |
| Shared memory | Not available | No | — |
| Const/static storage | Not available | No | — |

The ecosystem covers all major patterns, but they are distributed across three tiers. This is architecturally sound (each tier has a clear responsibility), but means the storage tier itself offers only two variants.

**Comparison with Rust Store RFC**: The Store RFC envisions `InlineStorage<N>`, `AllocatorStorage<A>`, `SmallStorage<I, A>`, and user-defined stores all implementing a single trait at the same abstraction level.

### 5.7 D7: Formal Guarantees

**Score: 2 (Gap)**

| Guarantee | Swift Primitives | Rust (RustBelt) | C++ | Zig |
|-----------|------------------|-----------------|-----|-----|
| Type safety proof | No | Iris/Coq proofs for std types | No | No |
| Initialization invariant proof | No (tested, not proven) | No | No | No |
| Separation property | Structural (BitVector) | Iris separation logic | No | No |
| Memory safety | Runtime exclusivity + @_lifetime | Compile-time borrow checker | External tools (ASAN) | Runtime checks |

The BitVector-based initialization tracking *structurally corresponds* to separation logic predicates (each bit asserts ownership of a slot), but this has not been formally verified. RustBelt provides machine-checked proofs for Rust's core types via Iris; no equivalent framework exists for Swift.

**Mitigating factor**: The extensive test suite (372 test cases, exhaustive invariant verification, edge case stress testing) provides empirical confidence. The lack of formal verification is an ecosystem-wide gap, not specific to storage-primitives.

---

## Part VI: Theoretical Perfect

### 6.1 Definition

A **theoretically perfect** storage primitive substrate would satisfy all seven dimensions at maximum, subject to no engineering constraints (compile-time limitations, language feature gaps, performance trade-offs).

### 6.2 Specification

#### TP-1: Type-Safe Coordinates (D1 = 5)

Every positional value (index, offset, count, address) is phantom-typed to its domain. Cross-domain operations require explicit conversion.

```swift
// Theoretical perfect — achieved by storage-primitives
let slot: Index<Element> = ...
let count: Index<Element>.Count = ...
let offset: Index<Element>.Offset = ...
```

**Current status**: Achieved.

#### TP-2: Verified Initialization Tracking (D2 = 5)

Per-slot initialization state is automatically maintained. A formal proof guarantees:

- **Soundness**: If bit `i` is set, slot `i` is initialized
- **Completeness**: If slot `i` is initialized, bit `i` is set
- **Deinit correctness**: `deinit` cleans up exactly the initialized slots
- **No double-init**: `initialize(to:at:)` on an already-initialized slot is a compile-time error

```swift
// Theoretical perfect — partially achieved (auto-tracking exists, formal proof and compile-time double-init prevention do not)
storage.initialize(to: value, at: slot)   // Bit set automatically ✓
storage.move(at: slot)                     // Bit cleared automatically ✓
// deinit cleans up exactly set bits ✓
// But: double-init is runtime precondition, not compile-time error
```

**Current status**: Automatic tracking achieved. Formal verification and compile-time double-init prevention not available.

#### TP-3: Universal Composability (D3 = 5)

Every allocation strategy available at the storage tier, with each variant providing the full storage-primitives contract (typed coordinates, initialization tracking, tracked accessors):

```swift
// Theoretical perfect — variant catalog complete
Storage.Heap              // Dynamic capacity, ARC lifetime         ✓ exists
Storage.Inline<N>         // Fixed capacity, stack lifetime          ✓ exists
Storage.Arena             // Bump allocation, batch deallocation     → planned
Storage.Pool              // Fixed-slot, O(1) allocate/deallocate   → planned
```

Collections compose with storage variants through the tier system:

```swift
// Buffer tier composes over storage tier:
Stack         → Buffer.Linear    → Storage.Heap     (dynamic, ARC)
Stack.Bounded → Buffer.Bounded   → Storage.Inline   (fixed, stack)
Stack.Arena   → Buffer.Arena     → Storage.Arena     (bump, batch dealloc)
```

**Current status**: Two of four core variants exist. Arena and Pool are the priority additions (see §8.2).

**Note on protocol-based composability**: A `Storage.Protocol` (à la Rust Store RFC) was considered and rejected. The variant system already solves the user-facing problem, API surfaces diverge meaningfully between storage types, and the Store RFC itself remains pre-RFC after 2+ years of design — validating that this abstraction is genuinely hard. See §8.3 for full analysis.

#### TP-4: Complete ~Copyable Support (D4 = 5)

All storage variants support `~Copyable` elements. Inline storage is conditionally copyable when elements are copyable.

```swift
// Theoretical perfect — partially achieved
// Desired:
extension Storage.Inline: Copyable where Element: Copyable  // Currently impossible due to @_rawLayout
```

**Current status**: `~Copyable` support is first-class. The `Storage.Inline` always-noncopyable constraint is a Swift compiler limitation, not a design choice.

#### TP-5: Zero-Cost Abstraction (D5 = 5)

Storage abstractions compile away entirely. Typed coordinates are phantom-erased. No runtime overhead beyond what the bare minimum unsafe implementation would require.

```swift
// Theoretical perfect — nearly achieved
// Phantom types: erased at runtime ✓
// BitVector: 32 bytes overhead (correctness trade-off) — acceptable
// ARC on Heap: necessary for CoW, not strictly zero-cost
```

**Current status**: Near zero-cost. BitVector overhead justified by correctness. ARC overhead justified by CoW semantics.

#### TP-6: Complete Storage Patterns (D6 = 5)

All core allocation strategies available at the storage tier:

```swift
Storage.Heap              // Dynamic capacity, ARC lifetime          ✓ exists
Storage.Inline<N>         // Fixed capacity, stack lifetime          ✓ exists
Storage.Arena             // Bump allocation, batch deallocation     → planned
Storage.Pool              // Fixed-slot, O(1) allocate/deallocate   → planned
```

**Current status**: Two of four core patterns at the storage tier. Arena and Pool are the priority additions.

**Note**: Shared-memory storage (`Storage.Shared`) and inline→heap fallback (`Storage.Small`) are deferred — shared-memory is a niche use case, and inline→heap fallback is already handled at the Buffer tier (`Buffer.Linear`). Compile-time static storage is a potential future addition.

#### TP-7: Machine-Checked Safety (D7 = 5)

Storage operations carry machine-checked proofs:

- Initialization invariant proven via Iris/Coq-style separation logic
- BitVector ↔ slot correspondence proven sound and complete
- Deinit correctness proven (no leaks, no double-free)
- Type safety proven (phantom types prevent cross-domain confusion)

**Current status**: Not achieved. No formal verification framework for Swift exists.

### 6.3 Theoretical Perfect Scorecard

| Dimension | Theoretical Perfect | Current Score | Gap |
|-----------|--------------------:|:--------------|-----|
| D1: Type Safety | 5 | **5** | None |
| D2: Initialization Correctness | 5 | **5** | Formal verification only |
| D3: Composability | 5 | **3** | Variant catalog incomplete |
| D4: ~Copyable Support | 5 | **4** | Compiler limitation |
| D5: Performance | 5 | **4** | ARC overhead on Heap |
| D6: Completeness | 5 | **3** | Patterns at other tiers |
| D7: Formal Guarantees | 5 | **2** | Ecosystem-wide gap |
| **Weighted Total** | **35** | **26** | |

---

## Part VII: Where Swift Primitives Leads

### 7.1 Innovations Without Precedent

Three capabilities of `swift-storage-primitives` have no equivalent in any surveyed system:

#### 7.1.1 Automatic Per-Slot Initialization Tracking

The BitVector-based approach is unique in combining:
- **Automatic**: Operations self-update (no caller responsibility)
- **Compact**: 1 bit per slot (vs. full enum in Rust's slab)
- **Sparse**: Arbitrary patterns (not just contiguous ranges)
- **Correct deinit**: Cleanup iterates exactly the set bits

This solves the "stale initialization state" footgun that plagues every other system's manual storage:
- Rust: `ManuallyDrop` + `len` requires manual bookkeeping
- C++: `std::construct_at` / `std::destroy_at` are manual
- Zig: Entirely manual

#### 7.1.2 Typed Physical Coordinates

`Index<Element>` as phantom-typed slot address has no equivalent:
- Rust: `usize` for all indices
- C++: `size_t` for all indices, `T*` for typed pointer
- Zig: `usize` for all indices

The phantom tag prevents:
- Using an `Index<Int>` to access a `Storage<String>`
- Confusing byte counts with element counts
- Mixing indices from different storage instances (same domain restriction)

#### 7.1.3 Tracked Accessor Pattern

The `storage.initialize.next(to:)` / `storage.move.last()` / `storage.deinitialize.all()` pattern provides:
- **Self-documenting**: The operation's domain (initialize, move, deinitialize) is syntactically visible
- **Self-tracking**: State maintained automatically
- **Linear discipline**: Operations enforce append-at-end / remove-from-end

This is an API design innovation, not a capability innovation — the same operations could be bare methods. But the nested accessor pattern provides superior code readability and constrains misuse.

### 7.2 Structural Advantages

#### 7.2.1 Storage-Above-Allocator Separation

Swift Primitives uniquely separates:
- **Memory tier**: Raw allocation (Arena, Pool, Address arithmetic)
- **Storage tier**: Element lifecycle over raw allocations
- **Buffer tier**: Growth policies, inline→heap transitions

Rust conflates storage and allocator (Vec owns both allocation and element tracking). C++ PMR separates allocator from container but has no storage layer. The Swift approach enables buffer-primitives to compose freely with storage-primitives without reimplementing element lifecycle management.

#### 7.2.2 Foundation-Free, Embedded-Compatible

Unlike Apple's Swift standard library containers (`Array`, `Dictionary`), which depend on Objective-C runtime bridging, storage-primitives runs on Swift Embedded targets. This is a deployment scope advantage: the same storage substrate serves both server-side Swift and firmware.

### 7.3 Conceptual Lineage with Ownership Primitives

`swift-ownership-primitives` (currently Tier 0) provides single-element ownership containers. Several types exhibit structural correspondence with storage-primitives types:

| Ownership Type | Storage Analogue | Shared Concept |
|----------------|------------------|----------------|
| `Ownership.Unique` (Box) | `Storage.Heap` | Heap-allocated, owned lifecycle |
| `Ownership.Slot` | `Storage.Pool` (single element) | Allocate → initialize → use → deinitialize → deallocate |
| `Ownership.Shared` (ARC immutable) | `Storage.Heap` (CoW) | Reference-counted shared access |

#### 7.3.1 Ownership.Slot as Single-Element Storage.Pool

`Ownership.Slot` manages a single reusable memory location through an atomic state machine (`empty → initializing → full → empty`). This is conceptually a one-element pool: allocate a slot, initialize an element, use it, deinitialize, return the slot.

`Storage.Pool` (planned) manages N reusable typed slots with BitVector-based tracking. The operations are the same — but `Storage.Pool` operates on collections of slots, not individual ones.

#### 7.3.2 Ownership.Unique as Single-Element Storage.Heap

`Ownership.Unique<T>` heap-allocates exactly one `T` with consuming ownership semantics. `Storage.Heap` heap-allocates N elements with ARC-based CoW. Both provide heap indirection for value types, but at different scales and with different lifetime strategies (linear vs reference-counted).

#### 7.3.3 Cross-Package Reuse Analysis

Despite conceptual affinity, **no practical dependency or shared implementation exists**, and none should be introduced:

| Divergence Axis | Ownership | Storage | Why Sharing Fails |
|-----------------|-----------|---------|-------------------|
| Cardinality | Single element | N elements | Fundamentally different data structures |
| Synchronization | Atomic state machine | Not thread-safe | Storage would carry dead weight from atomics |
| Lifetime model | Linear (consuming) | ARC (Heap), scope (Inline) | Different ownership strategies per use case |
| Tracking | Boolean (full/empty) | BitVector (N bits) | Shared abstraction adds overhead to both |
| Tier position | Tier 0 (leaf) | Tier 14 (depends on memory, index, bit-vector) | No tier-compatible dependency direction |

The relationship is **conceptual lineage, not implementation reuse**. Both packages instantiate the same abstract pattern (allocate → track → use → cleanup), but the single-element vs multi-element divergence makes shared infrastructure a net negative. Any shared protocol or base type would force each package to carry abstractions it doesn't need, violating the primitives design principle of minimal, atomic building blocks.

**Implication for Storage.Arena and Storage.Pool design**: These new variants should follow the same pattern as existing storage types — wrapping Memory-tier allocators with typed coordinates and initialization tracking — without attempting to unify with ownership-primitives.

---

## Part VIII: Gap Analysis and Recommendations

### 8.1 Prioritized Gap List

| Priority | Gap ID | Dimension | Gap Description | Difficulty | Impact |
|----------|--------|-----------|-----------------|------------|--------|
| HIGH | GAP-001 | D3, D6 | Arena storage not at storage tier | Medium | Completes allocation strategy coverage, closes composability gap |
| HIGH | GAP-002 | D3, D6 | Pool storage not at storage tier | Medium | Fixed-slot O(1) at storage level, closes composability gap |
| MEDIUM | GAP-003 | D2 | Heap still uses manual range tracking | Medium | Consistency with Inline's auto-tracking |
| MEDIUM | GAP-004 | D4 | Storage.Inline always ~Copyable | Blocked | Swift compiler limitation |
| LOW | GAP-005 | D7 | No formal verification | Very High | Ecosystem-wide limitation |
| LOW | GAP-006 | D6 | No shared-memory storage | High | Niche use case |
| LOW | GAP-007 | D5 | ARC overhead on Storage.Heap | N/A | Necessary for CoW semantics |

### 8.2 Detailed Recommendations

#### REC-001: Arena Storage Variant (GAP-001)

**Priority**: HIGH — this is the most impactful single addition.

`Memory.Arena` (Tier 13) provides raw bump allocation. A `Storage.Arena` (Tier 14) would add the full storage-primitives contract on top:
- Typed element access via `Index<Element>`
- Per-slot initialization tracking via dynamic `Bit.Vector`
- Deinit of all initialized elements on arena reset
- Tracked accessor pattern (`arena.initialize.next(to:)`, etc.)

**Sketch**:
```swift
extension Storage {
    public struct Arena<Element: ~Copyable>: ~Copyable {
        var memory: Memory.Arena
        var slots: Bit.Vector.Dynamic  // Dynamic — arena grows
        // Typed coordinates, tracked accessors, deinit on reset
    }
}
```

**Key design question**: Arena semantics allow batch deallocation (reset), which interacts with initialization tracking. On `reset()`, all initialized elements must be deinitialized first (iterate set bits), then the BitVector and arena are cleared together. This is the novel contribution over raw `Memory.Arena`.

**Dependency**: Only requires Memory.Arena from Tier 13 — fits at Tier 14.

#### REC-002: Pool Storage Variant (GAP-002)

**Priority**: HIGH

`Memory.Pool` (Tier 13) provides fixed-slot O(1) allocation with its own `Bit.Vector` for free-slot tracking. A `Storage.Pool` (Tier 14) would add typed element lifecycle:
- Typed element access via `Index<Element>`
- Initialization tracking — potentially reusing Memory.Pool's existing BitVector via API discipline
- Combined insert (allocate + initialize) and remove (deinitialize + deallocate) operations
- No separate allocate/initialize split exposed to callers

**Sketch**:
```swift
extension Storage {
    public struct Pool<Element: ~Copyable>: ~Copyable {
        var memory: Memory.Pool
        // API discipline: insert() = allocate + initialize
        //                 remove() = deinitialize + deallocate
        // Memory.Pool's BitVector tracks both free slots and init state
    }
}
```

**Key design question**: Should `Storage.Pool` maintain a separate initialization BitVector, or reuse `Memory.Pool`'s existing free-slot BitVector through API discipline (never expose raw allocation without initialization)? The API discipline approach avoids redundant tracking — a slot is either free (in Memory.Pool's BitVector) or initialized (not in the BitVector). This eliminates the intermediate "allocated but uninitialized" state.

**Dependency**: Only requires Memory.Pool from Tier 13 — fits at Tier 14.

#### REC-003: Unify Initialization Tracking (GAP-003)

**Priority**: MEDIUM

The current split (Heap: range-based manual, Inline: BitVector automatic) creates API inconsistency. Potential approaches:

1. **Extend BitVector to Heap**: Use dynamic-size BitVector for heap storage
2. **Keep both**: Accept the split as justified by the unbounded nature of heap storage
3. **Shared implementation**: Extract a common tracking helper used by both variants

The per-slot-tracking research already recommended potentially extending to Heap. This should be re-evaluated now that the Inline implementation has proven the pattern.

### 8.3 Non-Recommendations

#### Storage Protocol (REJECTED)

**Status**: REJECTED after analysis.

A `Storage.Protocol` abstracting over `Heap`, `Inline`, `Arena`, and `Pool` was considered and rejected for the following reasons:

1. **The variant system already solves the user-facing problem**. Collections offer Base/Bounded/Inline/Small variants that select storage strategy. Users choose `Stack.Bounded` for inline storage, `Stack` for heap — no protocol needed.

2. **API surfaces diverge meaningfully**. `Storage.Heap` has ARC (CoW, isKnownUniquelyReferenced), `Storage.Inline` has fixed capacity and stack allocation, `Storage.Arena` would have batch reset, `Storage.Pool` would have O(1) slot management. A unifying protocol must either be so thin as to be useless or so thick as to carry dead weight for every conformer.

3. **The Rust Store RFC validates caution**. After 2+ years of design iteration, the Store RFC remains pre-RFC. The trait hierarchy (`StoreSingle`, `StoreMultiple`, `StoreStable`, `StorePinning`) demonstrates the complexity explosion that a storage protocol entails. Swift's approach of concrete types with a thin variant system avoids this.

4. **Performance cost**. Protocol witness tables add indirection. While specialization can eliminate this for concrete types, the optimization is not guaranteed, and storage operations are performance-critical. Concrete types give the compiler maximum optimization freedom.

5. **The real consumer is buffer-primitives**, not end users. Buffer-primitives knows at compile time which storage variant it uses. It doesn't need dynamic dispatch.

**This is a principled decision, not a gap**. The composability dimension (D3) is addressed by completing the variant catalog (Arena, Pool), not by introducing a unifying protocol.

#### Formal Verification (GAP-005)

**Status**: DEFERRED

No formal verification framework exists for Swift. Creating one is a multi-year research effort outside the scope of storage-primitives. The correct approach is to maintain the structural correspondence to separation logic (BitVector ↔ ownership predicate) and revisit when/if an Iris-like framework becomes available for Swift.

#### Shared Memory Storage (GAP-006)

**Status**: DEFERRED

Shared-memory storage (cross-process, using offset-based handles) is a niche requirement. The Store RFC's handle abstraction elegantly supports this, but the demand in the Swift ecosystem does not currently justify the complexity.

---

## Part IX: Outcome

### 9.1 Status

**Status**: RECOMMENDATION

### 9.2 Principal Findings

1. **Swift storage-primitives leads the state of the art** on type safety (D1) and initialization correctness (D2). No surveyed system provides automatic per-slot tracking with typed coordinates.

2. **Composability (D3) is a principled gap, not a missing abstraction**. The variant system (Base/Bounded/Inline/Small) handles user-facing storage selection. The remaining gap is completing the variant catalog with Arena and Pool at the storage tier. A Storage.Protocol was considered and rejected (§8.3) — the Rust Store RFC's 2+ year design struggle validates this caution.

3. **The tier separation is a strength, not a weakness**. The Memory → Storage → Buffer layering provides cleaner separation of concerns than any surveyed system. Arena and Pool storage variants should be added at the Storage tier, wrapping the existing Memory-tier implementations.

4. **Ownership-primitives shares conceptual lineage but not implementation** (§7.3). `Ownership.Slot` is structurally a single-element `Storage.Pool`, and `Ownership.Unique` is structurally a single-element `Storage.Heap`. The single-element vs multi-element divergence makes shared infrastructure a net negative.

5. **No system achieves theoretical perfect**. All surveyed systems have significant gaps:
   - Rust: No per-slot tracking, no typed coordinates (but best composability and formal guarantees)
   - C++: Fragmented (inplace_vector vs vector), no initialization tracking, no formal guarantees
   - Zig: No type safety beyond basic types, no initialization tracking, no move-only support
   - Swift: Best type safety and tracking; remaining gap is variant catalog completeness

6. **The storage-primitives design occupies novel territory**. The combination of typed coordinates + automatic tracking + ~Copyable + layered architecture is not explored in the academic literature or in any production system. This is genuine innovation, not incremental improvement.

### 9.3 Summary Scorecard

| Dimension | Swift | Rust (current) | Rust (Store RFC) | C++ | Zig | Theory |
|-----------|:-----:|:--------------:|:----------------:|:---:|:---:|:------:|
| D1: Type Safety | **5** | 3 | 3 | 2 | 2 | 5 |
| D2: Init Correctness | **5** | 3 | 3 | 2 | 1 | 5 |
| D3: Composability | 3 | **4** | **5** | 3 | 3 | 5 |
| D4: ~Copyable | 4 | **5** | **5** | 3 | 1 | 5 |
| D5: Performance | 4 | **5** | 4 | 4 | **5** | 5 |
| D6: Completeness | 3 | 3 | **4** | 3 | 2 | 5 |
| D7: Formal Guarantees | 2 | **4** | 2 | 1 | 1 | 5 |
| **Total** | **26** | **27** | **26** | **18** | **15** | **35** |

**Interpretation**: Swift and Rust are now tied at 26 vs 27, excelling in different dimensions. Swift leads on type safety and initialization correctness; Rust leads on ~Copyable maturity and formal guarantees. The composability gap narrowed from 2→3 with the principled decision against a protocol approach in favor of variant-catalog completion. With Arena and Pool implemented, Swift would reach 28 (D3→4, D6→4), surpassing Rust current. The theoretical perfect (35) remains distant for all real systems.

### 9.4 Recommended Next Steps

| Priority | Action | Type | Dependency |
|----------|--------|------|------------|
| 1 | Implement `Storage.Arena` at Tier 14 | Implementation | REC-001 |
| 2 | Implement `Storage.Pool` at Tier 14 | Implementation | REC-002 |
| 3 | Evaluate BitVector tracking for Heap | Research | REC-003 |
| 4 | Update integration-maximization analysis | Research | After REC-001/002 |

---

## Part X: References

### Swift Evolution

- SE-0390: Noncopyable structs and enums. Swift Evolution, 2023.
- SE-0427: Noncopyable generics. Swift Evolution, 2024.
- SE-0377: `borrowing` and `consuming` parameter ownership modifiers. Swift Evolution, 2023.
- SE-0456: Span properties. Swift Evolution, 2024.

### Academic Literature

- Tofte, M. & Talpin, J.-P. (1997). Region-Based Memory Management. Information and Computation, 132(2), 109-176.
- Tofte, M. (2004). A Retrospective on Region-Based Memory Management. Higher-Order and Symbolic Computation, 17(3).
- Grossman, D. et al. (2002). Region-based Memory Management in Cyclone. PLDI 2002.
- Fluet, M., Morrisett, G. & Ahmed, A. (2006). Linear Regions Are All You Need. ESOP 2006.
- Reynolds, J. C. (2002). Separation Logic: A Logic for Shared Mutable Data Structures. LICS 2002.
- Jung, R. et al. (2018). RustBelt: Securing the Foundations of the Rust Programming Language. POPL 2018.
- Walker, D. (2003). Typed Memory Management in a Calculus of Capabilities.
- Girard, J.-Y. (1987). Linear Logic. Theoretical Computer Science, 50(1), 1-102.
- Walker, D. (2005). Substructural Type Systems. Advanced Topics in Types and Programming Languages.
- Wadler, P. (1990). Linear types can change the world.
- Berger, E. et al. (2000). Hoard: A Scalable Memory Allocator for Multithreaded Applications. ASPLOS 2000.
- Powers, B. et al. (2019). Mesh: Compacting Memory Management for C/C++ Applications. PLDI 2019.
- Leijen, D. et al. (2019). Mimalloc: Free List Sharding in Action. Technical Report MSR-TR-2019-18.

### Rust Ecosystem

- [Allocator trait (nightly)](https://doc.rust-lang.org/nightly/core/alloc/trait.Allocator.html)
- [Store RFC draft (matthieu-m)](https://github.com/matthieu-m/rfcs/blob/store/text/3446-store.md)
- [SmallVec](https://github.com/servo/rust-smallvec)
- [Bumpalo](https://github.com/fitzgen/bumpalo)
- [Slab crate](https://docs.rs/slab/latest/slab/)
- [RawVec source](https://doc.rust-lang.org/src/alloc/raw_vec.rs.html)

### C++ Standards and Libraries

- P0843R14: `inplace_vector`. ISO/IEC JTC1/SC22/WG21, 2024.
- P3002R1: Policies for Using Allocators. ISO/IEC JTC1/SC22/WG21, 2024.
- [folly::small_vector](https://github.com/facebook/folly/blob/main/folly/docs/small_vector.md)

### Research Allocators

- [mimalloc (Microsoft)](https://github.com/microsoft/mimalloc)
- [jemalloc](https://jemalloc.net/jemalloc.3.html)
- [snmalloc (Microsoft Research)](https://github.com/microsoft/snmalloc)
- [TCMalloc Design](https://google.github.io/tcmalloc/design.html)

### Swift Primitives Internal

- `/Users/coen/Developer/swift-primitives/Research/integration-maximization-comparative-analysis.md`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/per-slot-initialization-tracking.md`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/storage-contiguous-api-design.md`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/storage-inline-invariants.md`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/Collection Primitives Architecture.md`
- `/Users/coen/Developer/swift-primitives/swift-ownership-primitives/` — Ownership.Unique, Ownership.Slot, Ownership.Shared (conceptual lineage analysis in §7.3)

---

## Appendix A: Detailed Rust Store RFC Analysis

The Store RFC introduces four levels of capability:

```
StoreDangling         → Can produce dangling (well-aligned, invalid) handles
    ↓
StoreSingle           → Can allocate/deallocate a single allocation
    ↓
StoreMultiple         → Can manage multiple concurrent allocations
    ↓
StoreStable           → Handle resolution returns stable pointers
    ↓
StorePinning          → Pointers survive store moves
```

**Handle taxonomy**:

| Store Implementation | Handle Type | Size | Inline? |
|---------------------|-------------|------|---------|
| `AllocatorStorage<A>` | `NonNull<u8>` | 8 bytes | No |
| `InlineSingleStorage<N>` | `()` | 0 bytes | Yes |
| `InlineStorage<N>` | `u8` (offset) | 1 byte | Yes |
| Shared memory store | `u32` (offset) | 4 bytes | No |
| Arena store | `u32` (offset) | 4 bytes | No |

This `Handle` abstraction is the key innovation — it allows collections to work with inline, heap, and shared-memory storage through the same interface. Swift Primitives' `Index<Element>` provides domain-typed addressing but is not an abstract handle that could reference different storage backends.

## Appendix B: Evaluation Methodology

### Scoring Criteria

**D1 (Type Safety)**:
- 5: Phantom-typed coordinates with compile-time cross-domain prevention
- 4: Typed pointers but untyped indices
- 3: Typed containers but untyped internals
- 2: Basic type checking only
- 1: Void pointer / raw integer everywhere

**D2 (Initialization Correctness)**:
- 5: Automatic per-slot tracking with proven invariants
- 4: Automatic linear tracking (len counter) + some per-slot
- 3: Manual tracking with helper functions
- 2: Entirely manual (convention-based)
- 1: No tracking mechanism

**D3 (Composability)**:
- 5: Collections generic over storage; user-defined stores; compose freely
- 4: Collections generic over allocator; standard store variants
- 3: Some abstraction (PMR-style runtime polymorphism)
- 2: Concrete types only; limited parameterization
- 1: No abstraction; everything hardcoded

**D4 (~Copyable Support)**:
- 5: First-class, default, mature (Rust)
- 4: First-class, explicit, maturing (Swift)
- 3: Supported but not default (C++ move semantics)
- 2: Partial support
- 1: Not available

**D5 (Performance)**:
- 5: Zero overhead beyond unsafe implementation
- 4: Minimal overhead (phantom erasure, small tracking)
- 3: Moderate overhead (ARC, vtable dispatch)
- 2: Significant overhead
- 1: Unusable overhead

**D6 (Completeness)**:
- 5: All patterns at single abstraction layer
- 4: Most patterns available, some at adjacent layers
- 3: Core patterns present, others at other layers
- 2: Minimal patterns
- 1: Single pattern only

**D7 (Formal Guarantees)**:
- 5: Machine-checked proofs (Iris/Coq)
- 4: Compile-time guarantees (borrow checker) + partial proofs
- 3: Compile-time guarantees only
- 2: Structural correspondence to formal properties
- 1: No formal or structural guarantees
