# Storage and Buffer Abstraction Analysis

<!--
---
version: 1.2.0
last_updated: 2026-02-12
changelog:
  - 1.2.0 (2026-02-12): Completed Spill building block experiment
    (swift-buffer-primitives/Experiments/spill-building-block/). All 6 variants
    CONFIRMED mechanically feasible but net savings marginal (~10 shared lines per
    discipline). Updated outcome: Option D evaluated and deferred. Added §6.5
    (Inline Storage Skeleton Duplication) with per-discipline line counts and §6.6
    (Test Infrastructure Gap) — test duplication is large (~2,800 lines) but faces
    the same ~Copyable protocol blocker; shared infrastructure reduces boilerplate
    but not structure. Status quo confirmed for both types and tests.
  - 1.1.0 (2026-02-12): Revised Option D assessment after code inspection — Small type
    declarations are ~10 lines each but discipline-specific operations cannot be shared;
    net savings marginal. Strengthened Option E analysis with specific compiler blocker
    (associatedtype ~Copyable, per protocol-abstraction-for-phantom-typed-wrappers.md).
  - 1.0.0 (2026-02-12): Initial analysis with SLR, formal semantics, comparative analysis.
status: RECOMMENDATION
tier: 3
applies_to: [swift-storage-primitives, swift-buffer-primitives, swift-binary-buffer-primitives]
normative: false
---
-->

## Context

The swift-primitives monorepo contains two packages with significant variant proliferation:

- **swift-storage-primitives** (Tier 14): 7 storage types across 6 modules — `Storage.Heap`, `Storage.Inline<capacity>`, `Storage.Pool`, `Storage.Pool.Inline<capacity>`, `Storage.Arena`, `Storage.Arena.Inline<capacity>`, `Storage.Split<Lane>`
- **swift-buffer-primitives** (Tier 15): 6 buffer disciplines — `Buffer.Ring`, `Buffer.Linear`, `Buffer.Slab`, `Buffer.Linked<N>`, `Buffer.Slots<Metadata>`, `Buffer.Arena` — each with up to 4 storage-strategy variants (Base, Bounded, Inline, Small), yielding ~22 concrete buffer types
- **swift-binary-buffer-primitives** (Tier 16): `Buffer.Aligned`, `Buffer.Unbounded` — byte-specialized buffers

The total public type surface exceeds 45 types with 250+ public methods. This research investigates whether an abstraction exists that would:

1. Reduce variant proliferation without sacrificing type safety
2. Avoid the protocol approach (explicitly scoped out)
3. Preserve the ~Copyable/Copyable distinction
4. Maintain the reference-type/value-type semantic split

**Trigger**: Design audit per [RES-012]. The variant count crossed a threshold where the question of underlying structure became architecturally significant.

**Scope**: Ecosystem-wide per [RES-002a] — spans Memory (Tier 13), Storage (Tier 14), Buffer (Tier 15), and Collection (Tier 16+) layers.

---

## Question

**Is there a non-protocol abstraction that unifies the storage and buffer variant families, and if so, should it be pursued?**

Sub-questions:

1. What structural commonalities exist across storage variants?
2. What structural commonalities exist across buffer variants?
3. Does the literature provide a theoretical framework for these commonalities?
4. What abstraction mechanisms are available within Swift's type system that are not protocols?
5. What is the cost-benefit of each candidate abstraction?

---

## Part I: Decision Inventory

### 1.1 Storage Variant Inventory

Seven concrete storage types exist, organized along two axes:

| Type | Placement | Semantics | Copyability | Mutability | Init Tracking | Index Type |
|------|-----------|-----------|-------------|------------|---------------|------------|
| `Storage.Heap` | Heap (ManagedBuffer) | Reference | Always Copyable | Non-mutating | `Storage.Initialization` (range enum) | `Index<Element>` |
| `Storage.Inline<capacity>` | Stack (@_rawLayout) | Value | Always ~Copyable | Mutating | `Bit.Vector.Static<4>` (bitmap) | `Index<Element>` |
| `Storage.Pool` | Heap (class + Memory.Pool) | Reference | Always Copyable | Non-mutating | In-band free list | `Index<Element>` |
| `Storage.Pool.Inline<capacity>` | Stack (@_rawLayout) | Value | Always ~Copyable | Mutating | `Bit.Vector.Static<4>` (bitmap) | `Index<Element>.Bounded<capacity>` |
| `Storage.Arena` | Heap (class + Memory.Arena) | Reference | Always Copyable | Non-mutating | Parity tokens (per-slot Meta) | `Index<Element>` |
| `Storage.Arena.Inline<capacity>` | Stack (@_rawLayout) | Value | Always ~Copyable | Mutating | `Bit.Vector.Static<4>` (bitmap) | `Index<Element>.Bounded<capacity>` |
| `Storage.Split<Lane>` | Heap (ManagedBuffer) | Reference | Always Copyable | Non-mutating | Consumer-managed | `Index<Element>` + `Storage.Field<Value>` |

### 1.2 Storage API Surface Commonality

Every storage type provides:

| API Element | Heap | Inline | Pool | Pool.Inline | Arena | Arena.Inline | Split |
|-------------|------|--------|------|-------------|-------|--------------|-------|
| `slotCapacity` | ✓ | ✓ | ✓ (as `capacity`) | ✓ | ✓ | ✓ | ✓ |
| `pointer(at:)` | ✓ | ✓ | ✓ | ✓ | — | — | ✓ (field-qualified) |
| `isEmpty` | ✓ | ✓ | ✓ | ✓ | — | ✓ | — |
| `.initialize` accessor | ✓ (Property) | ✓ (Property.View) | — | — | ✓ (direct) | — | ✓ (Property) |
| `.move` accessor | ✓ (Property) | ✓ (Property.View) | — | — | ✓ (direct) | — | ✓ (Property) |
| `.deinitialize` accessor | ✓ (Property) | ✓ (Property.View) | ✓ (Property) | ✓ (Property.View) | ✓ (direct) | ✓ (Property.View) | ✓ (Property) |
| `.copy` accessor | ✓ (Property) | ✓ (ext) | ✓ (ext) | — | — | — | — |
| `allocate()` | — | — | ✓ | ✓ | — | ✓ | — |
| `deallocate(at:)` | — | — | ✓ | ✓ | — | — | — |

**Observation**: The "common core" (`slotCapacity`, `pointer(at:)`, lifecycle accessors) covers ~60% of the API surface but is expressed through two incompatible mechanisms:
- Reference types: `Property<Tag, Self>` (non-mutating)
- Value types: `Property<Tag, Self>.View` (mutating, via `_read`/`_modify`)

### 1.3 Buffer Variant Inventory

Six buffer disciplines, each with up to four storage-strategy variants:

| Discipline | Base | Bounded | Inline | Small | Header Type | Storage Type |
|------------|------|---------|--------|-------|-------------|-------------|
| Ring | ✓ | ✓ | ✓ | ✓ | Ring.Header / Header.Cyclic | Heap / Inline |
| Linear | ✓ | ✓ | ✓ | ✓ | Linear.Header | Heap / Inline |
| Slab | ✓ | ✓ | ✓ | ✓ | Slab.Header / Header.Static | Heap / Inline |
| Linked\<N\> | ✓ | — | ✓ | ✓ | Linked.Header | Pool / Inline |
| Slots\<M\> | ✓ | — | — | — | Slots.Header | Split |
| Arena | ✓ | ✓ | ✓ | ✓ | Arena.Header | Arena / Inline |

### 1.4 Buffer Structural Pattern

Every discipline follows the same three-layer architecture:

```
Layer 1: Header       — Pure cursor/bookkeeping state (Copyable, Sendable)
Layer 2: Static Ops   — Expert-level functions on raw storage
Layer 3: Composed Type — header: Header + storage: Storage<Element>.X
```

The four storage-strategy variants per discipline follow a mechanical pattern:

| Variant | Structure | Capacity | Growth |
|---------|-----------|----------|--------|
| **Base** | `header: Header` + `storage: Storage<E>.Heap` | Dynamic | Policy-driven |
| **Bounded** | `header: Header` + `storage: Storage<E>.Heap` | Fixed at init | None (throws on overflow) |
| **Inline\<capacity\>** | `header: Header` + `storage: Storage<E>.Inline<capacity>` | Compile-time | None (throws on overflow) |
| **Small\<inlineCapacity\>** | `_inlineBuffer: Inline<N>` + `_heapBuffer: Base?` | Inline then spill | Spill to heap |

---

## Part II: Systematic Literature Review

### 2.1 Research Questions

Per Kitchenham methodology [RES-023]:

- **RQ1**: How do other systems programming languages abstract over storage strategy?
- **RQ2**: What theoretical frameworks formalize the structure of parameterized containers?
- **RQ3**: What are the known failure modes of storage abstraction attempts?

### 2.2 Search Strategy

**Databases**: arXiv, ACM DL, Springer, IEEE Xplore, Swift Forums, Rust Internals, GHC proposals.

**Search terms**: "storage abstraction" AND ("type system" OR "generic programming"), "allocator API" AND "parameterized", "region-based memory" AND "type safety", "container" AND "type theory" AND "positions", "linear types" AND "buffer management".

**Inclusion criteria**: (1) Addresses parameterization of containers over storage/allocation strategy; (2) provides formal or empirical results; (3) published 1987–2026.

**Exclusion criteria**: (1) Application-domain papers without type-system contribution; (2) unpublished blog posts without implementation evidence.

### 2.3 Theme 1: The Storage Strategy Problem

The fundamental tension: **how to parameterize a container over its storage strategy without duplicating the container's logic.**

#### Rust: Allocator API → Storage API

Rust's `Allocator` trait (RFC 1398, tracking issue #32838) defines allocation in terms of `NonNull<u8>` pointers: `allocate`, `deallocate`, `grow`, `shrink`. The critical limitation: **moving a container invalidates pointers to inline storage**, so `Vec<T, A: Allocator>` cannot express inline storage.

The ecosystem responded with ad-hoc type proliferation: **SmallVec** (servo/rust-smallvec), **tinyvec** (Lokathor/tinyvec), **heapless** (rust-embedded/heapless). Each reimplements container logic because the Allocator trait cannot express inline storage.

The **Storage API** (Pre-RFC, May 2023; proof-of-concept matthieu-m/storage-poc) proposes **handle-centric storage**:

- `Handle<T>`: An opaque, `Copy + Clone` associated type. Not a pointer. Can be a `u32` index, a `()` for inline storage, or a `NonNull<T>` for heap.
- Trait hierarchy: `Storage` (base) → `MultipleStorage` (concurrent allocations) → `StableStorage` (stable pointers) → `PinningStorage` (relocation-safe).
- Concrete implementations: `InlineSingleStorage`, `AllocSingleStorage`, `SmallStorage` (inline + spill), `FallbackStorage`.

**Status**: In design for 2+ years without stabilization. The Rust Internals thread "Combining the Allocator and Storages APIs" and wg-allocators issue #93 document ongoing difficulties.

**Key insight**: The handle-based design separates *addressing* from *storage strategy*. A handle that is not a pointer enables relocatable storage — precisely what is needed for inline storage in value-typed languages. However, the trait hierarchy required to express all combinations has proven intractable in practice.

#### C++: Polymorphic Memory Resources

C++17's `std::pmr` (polymorphic memory resources) solved the type-infection problem where `vector<int, A1>` and `vector<int, A2>` were different types. `pmr::memory_resource` uses runtime polymorphism (virtual `do_allocate`, `do_deallocate`, `do_is_equal`). `scoped_allocator_adaptor` propagates allocators to nested containers.

P3002R1 (WG21, 2024) proposes standing policy that all new Standard Library facilities accepting memory should accept an allocator — Bloomberg's experience shows most of their C++ codebase is allocator-enabled.

**Key insight**: Runtime polymorphism (vtable dispatch) solves the type-infection problem but at performance cost. The propagation model shows allocation strategy must be **compositional** — nested structures must participate. C++ demonstrates the design pressure but its solution is inappropriate for Swift's performance-critical primitives layer.

#### Zig: Explicit Allocator Passing

`std.mem.Allocator` is a struct containing a VTable with function pointers — manual vtable without language-level inheritance. Every function needing memory takes an `Allocator` parameter. No hidden allocations.

**Key insight**: Explicit allocator threading can be ergonomic when universal. The "no hidden allocations" principle maps to the Swift Institute's primitives layer philosophy.

### 2.4 Theme 2: Ownership, Linearity, and Substructural Type Systems

| Source | Key Contribution | Relevance |
|--------|-----------------|-----------|
| Girard (1987), "Linear Logic" (TCS 50) | Exponential modality `!A` converts linear resources to reusable ones | `~Copyable` removes the `!` modality; `Copyable` preserves it. Storage over ~Copyable elements is in the linear fragment. |
| Wadler (1990), "Linear Types Can Change the World!" | Linear types for modeling state changes | Storage/buffers representing unique resources ARE linear values |
| Baker (1992/1995), "Lively Linear Lisp", "Use-Once Variables" | Linearity eliminates GC overhead entirely | Historical proof that linearity eliminates GC for resource types |
| Walker (2005), "Substructural Type Systems" (ATTAPL) | Taxonomy: linear (no weakening + no contraction), affine (no contraction), relevant (no weakening), ordered (all restricted) | Swift's `~Copyable` is **affine** (can drop via deinit, cannot duplicate). True linearity would require compiler enforcement against silent drops. |
| Reynolds (2002), "Separation Logic" (LICS) | Separating conjunction P ∗ Q for disjoint heap ownership | Formal foundation for non-overlapping buffer ownership; basis for Law of Exclusivity |

**Critical finding**: The reference-type/value-type split in storage-primitives is not an implementation accident — it reflects a fundamental distinction in substructural type theory. Reference types (Heap, Pool, Arena, Split) model **shared ownership** via ARC (Girard's `!` modality). Value types (Inline, Pool.Inline, Arena.Inline) model **affine/linear ownership** via `~Copyable`. A protocol abstracting over both would need to be parametrically polymorphic over the structural rule itself — which is precisely what Linear Haskell's multiplicity polymorphism does, and Swift does not yet support.

### 2.5 Theme 3: Region-Based Memory Management

| Source | Key Contribution | Relevance |
|--------|-----------------|-----------|
| Tofte & Talpin (1997), "Region-Based Memory Management" (Info & Comp 132) | Type-and-effects system with lexically-scoped regions | Regions are the original "storage strategy" abstraction; LIFO restriction is the key limitation |
| Grossman et al. (2002), "Region-Based Memory Management in Cyclone" (PLDI) | Four coexisting memory management mechanisms under unified region types | **Multiple storage strategies can coexist** under a unified type system. Directly validates Swift Institute's design. |
| Crary, Walker, Morrisett (1999/2000), "Typed Memory Management in a Calculus of Capabilities" (POPL/TOPLAS) | Static capabilities for memory access permission | Capabilities map to Swift's `borrowing`/`consuming`/`inout` |
| Fluet, Morrisett, Ahmed (2006), "Linear Regions Are All You Need" (ESOP) | Linear types encode all known region-based schemes | **Unification result**: `~Copyable` capabilities are sufficient to express all storage lifetime patterns |

**Critical finding**: Cyclone's practical experience with four coexisting memory management mechanisms directly validates having multiple storage types without a unifying protocol. The theoretical unification (Fluet et al.) works at the *capability* level (ownership modifiers), not the *container* level (storage types). This suggests the right abstraction point is the **ownership discipline** (already captured by Swift's type system), not the storage type.

### 2.6 Theme 4: Container Theory

| Source | Key Contribution | Relevance |
|--------|-----------------|-----------|
| Abbott, Altenkirch, Ghani (2005), "Containers: Constructing Strictly Positive Types" (TCS 342) | Container = (Shape S, Position P : S → Type); Extension = (s : S, P s → X) | Storage type = Shape; Valid indices = Position family; Stored values = Extension |
| Altenkirch et al. (2015), "Indexed Containers" (JFP 25) | Indexed containers carry state transitions in their indices | Buffer initialization tracking IS an indexed container: the type-level index changes as elements are added/removed |
| Stepanov & McJones (2009), "Elements of Programming" | Concept-based decomposition for generic programming | Storage abstraction = concept parameterized over allocation strategy |

**Critical finding**: Container theory provides the formal structure for understanding WHY the variants exist and what they share. A container `(S, P)` has:

- **S** (Shape) = the storage strategy: `Heap(capacity)`, `Inline(capacity)`, `Pool(capacity, allocated)`, `Arena(capacity, highWater)`, `Split(capacity, laneType)`
- **P** (Position) = the valid indices: `Index<Element>` or `Index<Element>.Bounded<capacity>`
- **Extension** = the stored values at each position

The shapes are genuinely different types — they carry different data (capacity vs. capacity + bitmap vs. capacity + parity tokens). The position families differ (bounded vs unbounded). This is not accidental variation that an abstraction would reduce — it is **essential** variation dictated by the shape of each storage strategy.

### 2.7 Theme 5: Haskell and Multiplicity Polymorphism

| Source | Key Contribution | Relevance |
|--------|-----------------|-----------|
| Bernardy et al. (2018), "Linear Haskell" (POPL) | Multiplicity-polymorphic arrows `a %m -> b` where m ∈ {One, Many} | Avoids type bifurcation: one function works for both linear and unrestricted use. Maps to the Copyable/~Copyable challenge. |
| GHC Primitives: ByteArray# / MutableByteArray# | Primitive unlifted mutable storage; PrimMonad state phantom type | State phantom parameterizes mutability context |

**Critical finding**: Linear Haskell's multiplicity polymorphism is the *only* known mechanism that avoids the Copyable/~Copyable bifurcation without protocols. Swift does not have multiplicity polymorphism. Until it does, the bifurcation between `Property<Tag, Self>` (non-mutating, for reference types) and `Property<Tag, Self>.View` (mutating, for value types) is an essential consequence of the type system, not a design flaw.

### 2.8 Theme 6: Graded Modalities and Effects

| Source | Key Contribution | Relevance |
|--------|-----------------|-----------|
| Orchard, Liepelt, Eades (2019), "Quantitative Program Reasoning with Graded Modal Types" (ICFP) | Granule language: graded modal types combining linear types, indexed types, and quantitative resource tracking | Future direction: track reference counts at the type level |
| Reinking et al. (2021), "Perceus: Garbage Free Reference Counting with Reuse" (PLDI) | Reuse analysis for in-place mutation without aliasing analysis | Directly applicable to ~Copyable buffer types and CoW optimization |

---

## Part III: Comparative Analysis

### 3.1 Evaluation Criteria

| Criterion | Weight | Rationale |
|-----------|--------|-----------|
| **Type safety preservation** | Critical | Must not weaken existing ~Copyable/Copyable guarantees |
| **API bifurcation cost** | High | How much duplication does the approach eliminate? |
| **Runtime overhead** | High | Primitives layer has zero-overhead requirement |
| **Cognitive load** | Medium | How much must a user learn to use the system? |
| **Composability** | Medium | How well does the abstraction compose at higher layers? |
| **Implementation feasibility** | Medium | Can this be built with Swift 6.2 today? |
| **Future-proofness** | Low | Will future Swift features change the calculus? |

### 3.2 Candidate Abstractions

Since protocols are explicitly excluded, the candidate space is:

#### Option A: Status Quo — Shared Infrastructure, No Unifying Type

The current design. Shared infrastructure captures commonalities:
- `Index<Element>` — universal addressing
- `Storage.Initialization` — initialization tracking for contiguous types
- `Bit.Vector.Static<4>` — initialization tracking for inline types
- `Property<Tag, Base>` / `Property<Tag, Base>.View` — lifecycle accessor pattern
- `Buffer.Growth.Policy` — growth strategy for growable buffers
- Tag enums (`Storage.Initialize`, `.Move`, `.Copy`, `.Deinitialize`) — compile-time operation dispatch

| Criterion | Assessment |
|-----------|------------|
| Type safety | ★★★★ — Full. Each variant's constraints are precise. |
| Bifurcation cost | ★★☆☆ — 4 variants × 6 disciplines = 24 buffer types; substantial repetition in the Small pattern |
| Runtime overhead | ★★★★ — Zero. All specialization is compile-time. |
| Cognitive load | ★★★☆ — Each variant is self-contained, but the total count is high |
| Composability | ★★★★ — Each variant composes independently with the layer above |
| Implementation feasibility | ★★★★ — Already implemented |
| Future-proofness | ★★★★ — No dependencies on unshipped features |

#### Option B: Generic Small<Discipline> via Macro Generation

Generate the four storage-strategy variants mechanically for each discipline using a Swift macro or build-time code generation:

```
@BufferDiscipline(header: Ring.Header, operations: Ring.Operations)
enum Ring { }
// Generates: Ring, Ring.Bounded, Ring.Inline<N>, Ring.Small<N>
```

| Criterion | Assessment |
|-----------|------------|
| Type safety | ★★★★ — Generated code preserves all constraints |
| Bifurcation cost | ★★★★ — Write once, generate four variants |
| Runtime overhead | ★★★★ — Zero. Generated code is fully specialized. |
| Cognitive load | ★★☆☆ — Macro magic obscures what types actually exist |
| Composability | ★★★☆ — Generated types compose, but macro constraints may limit flexibility |
| Implementation feasibility | ★★☆☆ — Requires mature Swift macro system; @_rawLayout + ~Copyable in macro context is uncharted territory |
| Future-proofness | ★★★☆ — Depends on macro ecosystem stability |

#### Option C: Enum-Based Storage Strategy Selector

An enum encoding the storage strategy at runtime:

```swift
enum Storage<Element: ~Copyable>.Strategy {
    case heap(Storage.Heap)
    case inline(/* ... */)  // Cannot hold ~Copyable inline storage in an enum
}
```

| Criterion | Assessment |
|-----------|------------|
| Type safety | ★☆☆☆ — Loses compile-time capacity guarantees; ~Copyable inline types cannot be enum payloads today |
| Bifurcation cost | ★★★☆ — Single enum, but match/switch at every access point |
| Runtime overhead | ★☆☆☆ — Branch at every operation |
| Implementation feasibility | ★☆☆☆ — ~Copyable enum payload support is incomplete |
| Cognitive load | ★★☆☆ — Simple concept but hidden runtime costs |

**Eliminated**: Fails type safety and runtime overhead criteria.

#### Option D: Compositional Building Blocks for the Small Pattern

The Small pattern is the most mechanically repetitive: each discipline's Small variant follows the same structure. Factor it:

```swift
// Shared building block
public struct Buffer.Spill<Inline: ~Copyable, Heap: ~Copyable>: ~Copyable {
    var _inline: Inline
    var _heap: Heap?
    var isSpilled: Bool
}
```

Each discipline's Small becomes `Buffer.Spill<Ring.Inline<N>, Ring>`.

| Criterion | Assessment |
|-----------|------------|
| Type safety | ★★★☆ — Preserves constraints but requires careful generic bounds |
| Bifurcation cost | ★★★☆ — Eliminates Small duplication (5 types reduced to 1 generic + 5 typealiases) |
| Runtime overhead | ★★★★ — Zero. Struct composition is free. |
| Cognitive load | ★★★☆ — Adds one concept (Spill) but eliminates 5 near-identical types |
| Composability | ★★★☆ — Spill composes well but discipline-specific spill logic may not factor cleanly |
| Implementation feasibility | ★★★☆ — ~Copyable generics + optional ~Copyable values are supported in Swift 6.2; discipline-specific header coordination is the challenge |
| Future-proofness | ★★★★ — No dependency on unshipped features |

#### Option E: Shared Header Protocol (Internal)

Factor the shared header shape into a package-internal protocol (not public-facing):

```swift
// Package-internal only
package protocol _BufferHeader: Copyable, Sendable {
    var count: Index<Element>.Count { get }
    var isEmpty: Bool { get }
}
```

| Criterion | Assessment |
|-----------|------------|
| Type safety | ★★★★ — Internal protocol doesn't leak to public API |
| Bifurcation cost | ★★★☆ — Enables shared implementations for header-based operations |
| Runtime overhead | ★★★★ — Protocol with concrete types is devirtualized at compile time |
| Cognitive load | ★★★★ — Users never see the protocol |
| Composability | ★★★☆ — Internal protocol enables shared extensions |
| Implementation feasibility | ★★★☆ — Package-internal protocols work today; constraint propagation with ~Copyable associated types may hit compiler limitations |
| Future-proofness | ★★★★ — Internal protocol can be evolved freely |

**Note**: This technically uses a protocol, but the user's constraint was against protocol-based *abstraction for storage/buffer types themselves*. An internal protocol for headers is a different scope. Including for completeness but flagging the boundary.

### 3.3 Comparison Matrix

| Criterion | A (Status Quo) | B (Macro Gen) | C (Enum) | D (Spill Building Block) | E (Internal Header) |
|-----------|---------------|---------------|----------|--------------------------|---------------------|
| Type safety | ★★★★ | ★★★★ | ★☆☆☆ | ★★★☆ | ★★★★ |
| Bifurcation cost | ★★☆☆ | ★★★★ | ★★★☆ | ★★★☆ | ★★★☆ |
| Runtime overhead | ★★★★ | ★★★★ | ★☆☆☆ | ★★★★ | ★★★★ |
| Cognitive load | ★★★☆ | ★★☆☆ | ★★☆☆ | ★★★☆ | ★★★★ |
| Composability | ★★★★ | ★★★☆ | ★★★☆ | ★★★☆ | ★★★☆ |
| Implementation feasibility | ★★★★ | ★★☆☆ | ★☆☆☆ | ★★★☆ | ★★★☆ |
| Future-proofness | ★★★★ | ★★★☆ | ★☆☆☆ | ★★★★ | ★★★★ |
| **Weighted total** | **25** | **23** | **12** | **23** | **25** |

---

## Part IV: Formal Semantics

### 4.1 Container-Theoretic Foundation

Following Abbott, Altenkirch, and Ghani (2005), we model the storage-buffer hierarchy as a category of containers.

**Definition (Storage Container)**. A storage container is a triple `(S, P, E)` where:
- `S` is the **shape** — a dependent record encoding the storage strategy and its state
- `P : S → Type` is the **position family** — the valid indices for a given shape
- `E : (s : S) → P(s) → Type` is the **element access** — mapping positions to element types

For our system:

```
Shape_Heap(T)       = { capacity : ℕ, init : Initialization(T) }
Shape_Inline(T, N)  = { capacity : N, slots : BitVector(N) }
Shape_Pool(T)       = { capacity : ℕ, allocated : ℕ, freeList : List(ℕ) }
Shape_Arena(T)      = { capacity : ℕ, highWater : ℕ, meta : Array(Meta) }
Shape_Split(T, L)   = { capacity : ℕ }
```

```
Position(Shape_Heap(T))         = { i : ℕ | i < capacity }           ≅ Index<T>
Position(Shape_Inline(T, N))    = { i : ℕ | i < N ∧ slots[i] = 1 }  ≅ Index<T>.Bounded<N>
Position(Shape_Pool(T))         = { i : ℕ | i < capacity ∧ allocated[i] } ≅ Index<T>
Position(Shape_Arena(T))        = { i : ℕ | i < capacity ∧ meta[i].isOccupied } ≅ Index<T>
Position(Shape_Split(T, L))     = { i : ℕ | i < capacity } × { field : {lane, element} } ≅ Index<T> × Field
```

**Observation**: The position families are structurally different — Inline positions are statically bounded, Pool/Arena positions depend on dynamic occupancy state, and Split positions are product types. A functor abstracting over these position families would require a higher-kinded type — which Swift does not support.

### 4.2 Substructural Typing Rules

The storage types inhabit different fragments of the substructural type system:

```
                         ┌── Contraction ──┐
                         │   (can copy?)   │
                    ─────┼────────┬────────┼─────
                         │  Yes   │   No   │
              ┌──────────┼────────┼────────┤
Weakening     │   Yes    │ Unrestricted │ Affine  │
(can drop?)   │          │ (Copyable)   │ (~Copyable) │
              ├──────────┼────────┼────────┤
              │   No     │ Relevant     │ Linear  │
              └──────────┼────────┴────────┤
                         └─────────────────┘

Reference storage types (Heap, Pool, Arena, Split):
  Γ ⊢ s : Storage.Heap<T>
  ────────────────────────── (REF-UNRESTRICTED)
  s : Unrestricted           // Can copy (ARC), can drop (ARC deinit)

Value storage types (Inline, Pool.Inline, Arena.Inline):
  Γ ⊢ s : Storage.Inline<T, N>
  ────────────────────────── (VAL-AFFINE)
  s : Affine                 // Cannot copy (@_rawLayout), can drop (deinit)
```

**Theorem (Structural Incompatibility)**. No single Swift type can inhabit both the Unrestricted and Affine fragments simultaneously. A protocol `StorageProtocol` with conformers from both fragments would need to abstract over the structural rule — requiring multiplicity polymorphism (Bernardy et al. 2018), which Swift does not provide.

*Proof sketch*: A protocol conformer must have a fixed Copyability. `Copyable` conformers inhabit Unrestricted; `~Copyable` conformers inhabit Affine. A protocol cannot be simultaneously `Copyable` and `~Copyable`. The `~Copyable` constraint on a protocol removes the `Copyable` requirement, but this makes ALL conformers affine — losing the reference semantics of Heap/Pool/Arena. ∎

### 4.3 Morphisms Between Storage Strategies

The four buffer variants per discipline form a subtype lattice (not in Swift's type system, but semantically):

```
                    Small<N>
                   ╱        ╲
            Inline<N>      Base
                   ╲        ╱
                    Bounded
```

- **Bounded → Base**: A bounded buffer IS a base buffer with capacity fixed at init
- **Bounded → Inline<N>**: A bounded buffer's capacity constraint IS an inline capacity constraint (but placed differently)
- **Inline<N> → Small<N>**: An inline buffer IS a small buffer that hasn't spilled
- **Base → Small<N>**: A base buffer IS a small buffer that has spilled
- **Small<N>**: The join — subsumes both inline and base

This lattice is a **diamond subtyping** pattern. In languages with subtype polymorphism, a function taking `Small<N>` accepts both `Inline<N>` (as unspilled) and `Base` (as spilled). In Swift's value-typed system, this is expressed through the `isSpilled` runtime check — which is exactly what the current Small implementations do.

### 4.4 Initialization Tracking as Indexed Container

Buffer initialization state transitions form an indexed container (Altenkirch et al. 2015):

```
State : Type
State = Empty | Partial(count : ℕ) | Full(capacity : ℕ)

Transition : State → State → Type
Transition Empty        (Partial 1) = Initialize_First
Transition (Partial n)  (Partial (n+1)) = Initialize_Next
Transition (Partial n)  (Partial (n-1)) = Remove
Transition (Partial n)  Full = Initialize_Last (when n+1 = capacity)
Transition _            Empty = Deinitialize_All
```

The Property accessor pattern (`storage.initialize.next(to:)`, `storage.move.last()`) is a **shallow embedding** of these transitions into Swift — the state index is tracked at runtime (via `Storage.Initialization` or `Bit.Vector`) rather than at the type level. A deep embedding (where the type changes after each operation) would require dependent types or indexed monads, neither of which Swift supports.

### 4.5 The Handle Resolution Pattern

Following the Rust Storage API analysis, every storage type implements the same abstract pattern:

```
Handle : Type
resolve : Storage × Handle → Pointer<Element>
```

| Storage Type | Handle | resolve | Handle Safety |
|-------------|--------|---------|---------------|
| Heap | `Index<Element>` | `pointer(at:)` | Precondition (bounds) |
| Inline | `Index<Element>` | `pointer(at:)` | Precondition (bounds + init) |
| Pool | `Index<Element>` | `pointer(at:)` | Precondition (allocated) |
| Pool.Inline | `Index<Element>.Bounded<N>` | `pointer(at:)` | Compile-time safe |
| Arena | `Index<Element>` | via `Memory.Arena` | Precondition (occupied) |
| Arena.Inline | `Index<Element>.Bounded<N>` | `_pointer(at:)` | Compile-time safe |
| Split | `Index<Element> × Field<V>` | `pointer(_:at:)` | Precondition (bounds) |

The handle resolution pattern IS already abstracted via `Index<Element>` and `Index<Element>.Bounded<N>`. The resolution function (`pointer(at:)`) cannot be unified because:
1. Reference types return non-mutating results; value types require `mutating` access
2. Split requires an additional `Field` parameter
3. Bounded indices provide compile-time safety that unbounded indices cannot

---

## Part V: Empirical Validation — Cognitive Dimensions Analysis

Per [RES-025], evaluating each option against the Cognitive Dimensions Framework:

| Dimension | Status Quo (A) | Spill Building Block (D) |
|-----------|---------------|--------------------------|
| **Visibility** | High — each type is explicit, no hidden dispatch | Medium — Spill type adds indirection |
| **Consistency** | High — every discipline follows the same 4-variant pattern | Medium — Spill generic introduces a new composition pattern |
| **Viscosity** | Medium — adding a new discipline requires writing 4 variants | Low — only write discipline logic, Spill handles 1 variant |
| **Role-expressiveness** | High — type name tells you exactly what it is | Medium — `Buffer.Spill<Ring.Inline<4>, Ring>` is less clear than `Ring.Small<4>` |
| **Error-proneness** | Low — explicit types prevent misuse | Low — generic bounds prevent misuse |
| **Abstraction** | None needed — each type stands alone | One new abstraction (Spill) |

**Assessment**: The Status Quo scores highest on visibility, consistency, and role-expressiveness. The Spill Building Block reduces viscosity but at the cost of role-expressiveness. For "timeless infrastructure" quality, **visibility and role-expressiveness take priority over viscosity reduction**.

---

## Part VI: Synthesis

### 6.1 Why the Variants Exist

The variant proliferation is not accidental. It reflects three orthogonal choices:

1. **Discipline** (Ring, Linear, Slab, Linked, Slots, Arena) — determines the access pattern, header shape, and invariants. These are genuinely different data structures with different algorithms.

2. **Placement** (Heap vs Inline) — determines reference vs value semantics, Copyability, mutating vs non-mutating API, and Property vs Property.View accessor pattern. This is a fundamental type-system distinction, not a parameter.

3. **Capacity** (Dynamic vs Bounded vs Compile-time) — determines growth policy, index safety, and error handling. Dynamic capacity enables growth but requires runtime checks; compile-time capacity enables bounded indices but forbids growth.

The number of variants is `|Disciplines| × |Placements| × |Capacities|` plus the Small join type. This is a Cartesian product of genuinely orthogonal concerns.

### 6.2 What IS Already Abstracted

The existing design already captures the abstractable commonalities through shared infrastructure:

| Shared Type | What It Abstracts | Used By |
|-------------|-------------------|---------|
| `Index<Element>` | Universal addressing, phantom-typed safety | All storage and buffer types |
| `Index<Element>.Bounded<N>` | Compile-time safe addressing | Inline variants |
| `Storage.Initialization` | Range-based initialization tracking | Heap, Inline |
| `Bit.Vector.Static<4>` | Bitmap-based initialization tracking | All inline variants |
| `Property<Tag, Base>` | Lifecycle operation namespacing (ref types) | Heap, Pool, Arena, Split |
| `Property<Tag, Base>.View` | Lifecycle operation namespacing (value types) | Inline, Pool.Inline, Arena.Inline |
| `Storage.Initialize/Move/Copy/Deinitialize` | Operation tag enums | All storage types |
| `Buffer.Growth.Policy` | Growth strategy parameterization | All growable buffers |
| `Buffer.*.Header` | Pure cursor state (Copyable, Sendable) | All buffer types |
| `Storage.Field<Value>` | Type-safe field handle for SoA access | Split |
| `Storage.Arena.Meta` | Per-slot generation token + free-list link | Arena |

This is **11 shared types** providing the common vocabulary. The variant-specific logic atop this vocabulary is genuinely variant-specific.

### 6.3 What a Protocol Would Cost

For completeness, even though protocols are excluded from consideration:

A `StorageProtocol` would need to abstract over:
1. Reference vs value semantics (mutating vs non-mutating)
2. Property vs Property.View accessor pattern
3. Index<Element> vs Index<Element>.Bounded<N>
4. Presence/absence of allocation operations
5. Presence/absence of field-qualified access
6. Different initialization tracking mechanisms
7. Copyable vs ~Copyable conformers

This would require associated types for Handle, Header, InitTracking, plus conditional requirements for `allocate`/`deallocate`. The Rust Storage API's failure to stabilize after 2+ years — with a more uniform type system — validates that this abstraction is intractable.

### 6.4 What Future Swift Features Would Change

| Feature | Impact | Timeline |
|---------|--------|----------|
| Multiplicity polymorphism (`a %m -> b`) | Could unify Property/Property.View into single mechanism | No proposal exists |
| Higher-kinded types | Could abstract over the Position family `P : S → Type` | No proposal exists |
| Dependent types | Could encode initialization state transitions at type level | No proposal exists |
| `@_rawLayout` conditional Copyable | Would allow `Storage.Inline: Copyable where Element: Copyable` | Compiler limitation, no timeline |
| Variadic generics maturation | Might enable macro-free variant generation | Partially available (Swift 5.9+) |

None of these features are imminent. The design should be optimized for Swift 6.2, not hypothetical futures.

### 6.5 Inline Storage Skeleton Duplication

The five Inline buffer variant declarations share a structural skeleton — but the shared portion is small and the discipline-specific portions are irreducible:

| Discipline | Header Type | Fields | Deinit | Skeleton Lines |
|-----------|-------------|--------|--------|----------------|
| Ring.Inline | `Header` | 2 (header, storage) | None | 19 |
| Linear.Inline | `Header` | 2 (header, storage) | None | 19 |
| Slab.Inline | `Header.Static<wordCount>` | 2 (header, storage) | Bitmap-driven (15 lines) | 34 |
| Linked.Inline | `Header` | 4 (header, storage, freeHead, nextUnused) | None | 28 |
| Arena.Inline | `Header` | 3 + nested `_Elements` struct | Token-driven (14 lines) | 38 |

Ring.Inline and Linear.Inline are character-for-character identical (19 lines each). Beyond that pair, the variations are essential:

- **Slab** requires `Header.Static<wordCount>` (compile-time bitmap) and a 15-line bitmap-driven deinit
- **Linked** requires 2 additional fields (`freeHead`, `nextUnused`) for free-list management
- **Arena** requires a nested `@_rawLayout` `_Elements` struct, an `InlineArray` for metadata, and a 14-line token-driven deinit

**Net savings from deduplication**: ~19 lines (the Ring/Linear pair). The remaining 3 disciplines diverge too much for a shared template. A macro-based approach would cost ~150+ lines of macro definition to save ~40-60 lines across all 5 types — a negative ROI.

### 6.6 Test Infrastructure Gap

The buffer-primitives test suite (29 files, ~4,665 lines) exhibits significantly more duplication than the type declarations:

| Metric | Value |
|--------|-------|
| Test files | 29 (27 test files + 2 support files) |
| Shared test utilities | 13 lines (1 helper + 1 re-export) |
| Estimated duplicated test code | 60-70% of total |
| Common lifecycle tested identically across disciplines | init → fill → spill → drain → removeAll |

Every discipline independently re-implements the same test sequences: create empty buffer, fill to inline capacity, verify no spill, overflow to trigger spill, verify elements survive, drain, verify ordering, removeAll. The only variation is method names (`pushBack` vs `append` vs `insert`).

**Comparison with type duplication**:

| Duplication Target | Duplicated Lines | Abstraction Cost | ROI |
|-------------------|-----------------|------------------|-----|
| Inline type skeletons | ~40-60 lines | High (macro system) | Negative |
| Small type skeletons | ~50 lines (per experiment) | Medium (generic wrapper) | Marginal |
| **Test lifecycle code** | **~2,800-3,200 lines** | **Low (parametrized harness)** | **High** |

A parametrized test harness was considered but faces the same `~Copyable` protocol blocker that prevents type abstraction: you cannot write a test-internal protocol that `Ring.Small<4>` and `Linear.Small<4>` both conform to, because the `associatedtype ~Copyable` limitation applies equally to test code. The shareable portions are limited to header state machine tests (headers are Copyable), assertion helpers, model-based comparison utilities, and operation sequence generators — collectively ~1,100-1,600 lines of boilerplate reduction, not structural deduplication. The per-discipline lifecycle test bodies remain regardless.

**Assessment**: The test duplication is structurally similar to the type duplication — it looks repetitive, but the per-discipline method signatures (`pushBack` vs `append` vs `insert`) and spill semantics make each test body genuinely discipline-specific. Shared infrastructure would reduce boilerplate but not eliminate test files. The explicit, self-contained per-discipline tests prioritize clarity over deduplication — consistent with the status quo recommendation for the types themselves.

---

## Outcome

**Status**: RECOMMENDATION

### Primary Recommendation: Maintain Status Quo (Option A)

The analysis demonstrates that the variant proliferation in storage-primitives and buffer-primitives is **essential complexity**, not accidental duplication. The variants exist because they inhabit different fragments of the substructural type system (Unrestricted vs Affine), encode genuinely different position families (bounded vs unbounded), and implement genuinely different initialization tracking mechanisms (ranges vs bitmaps vs parity tokens).

**The existing shared infrastructure IS the abstraction.** Eleven shared types already capture every commonality that can be factored without crossing the reference-type/value-type boundary. Further abstraction would either:
1. Require a protocol (excluded, and shown to be intractable by Rust's 2+ year failure to stabilize the Storage API), or
2. Lose type safety (enum-based strategy, eliminated), or
3. Obscure the system (macro generation, unproven with @_rawLayout + ~Copyable)

### Option D (Spill Building Block): Evaluated and Deferred

The experiment `swift-buffer-primitives/Experiments/spill-building-block/` empirically tested whether a generic `Buffer.Spill<Inline, Heap>` type could factor the Small buffer pattern. Six variants were tested against Ring and Linear disciplines.

**Findings** (all CONFIRMED mechanically, but net savings marginal):

| Variant | Result |
|---------|--------|
| V1: `Spill<Inline: ~Copyable, Heap: ~Copyable>` struct + `Optional._modify` | CONFIRMED |
| V2: Internal protocol for shared count/capacity/isFull | CONFIRMED |
| V3: Discipline-specific extensions for dual-route mutations | CONFIRMED |
| V4: Typealiases for readability | CONFIRMED (but diagnostics expose expanded form) |
| V5: Value generics + nested enum typealiases | CONFIRMED |
| V6: Extensions generic over value generic parameter | CONFIRMED with LIMITATION — cannot match `InlineN<any N>` without a protocol |

**Why the savings are marginal**: `Spill<Inline, Heap>` shares only ~10 lines across disciplines: the 2-field struct layout, `isSpilled` (1 line), and the `heap` accessor (4 lines). Every discipline-specific operation — spill logic, mutations, queries — must still be written in constrained extensions. The spill logic is genuinely different per discipline: Ring linearizes wrapped elements via initialization ranges, Linear moves sequentially, Slab preserves bitmap state, Arena preserves generation tokens and free-list links, Linked traverses node pointers.

**Decision**: Defer. The mechanism works but does not justify the costs: reduced role-expressiveness in error messages (`Spill<Ring.Inline<4>, Ring>` vs `Ring.Small<4>`), an additional generic type in the public API surface, and the implicit-Copyable constraint trap documented in V6.

### What This Research Establishes

1. **The 7 storage types are the canonical set.** They match the academically-derived canonical forms (Inline, Heap, Arena, Pool per Tofte-Talpin, Bonwick, and the storage-ownership-reference-synthesis), with Split and the inline variants as justified extensions.

2. **The 4-variant buffer pattern (Base/Bounded/Inline/Small) is a Cartesian product of orthogonal concerns** — not duplicated logic. Each variant's implementation differs because the storage semantics differ.

3. **The reference-type/value-type split is a consequence of substructural type theory**, not a design flaw. It reflects the fundamental incompatibility between the Unrestricted (`Copyable`) and Affine (`~Copyable`) fragments.

4. **The shared infrastructure (11 types) already captures the maximum abstractable surface** without protocols or type-system features Swift doesn't have.

5. **The Rust Storage API's failure to stabilize validates this finding externally.** If a language with a more uniform type system cannot unify storage strategies under a trait after 2+ years of design, Swift — with the additional reference/value type split — should not attempt it.

6. **The Spill building block is mechanically feasible but not worth pursuing.** The experiment confirmed all compiler capabilities work but demonstrated that only ~10 lines per discipline are shared — the discipline-specific operations dominate.

7. **Test duplication mirrors type duplication — both are essential.** The ~2,800 lines of test duplication across disciplines looks repetitive but faces the same `~Copyable` protocol blocker. Per-discipline method signatures and spill semantics make each test body genuinely discipline-specific. Explicit, self-contained tests are the right trade-off.

---

## References

### Formal Foundations

1. Girard, J.-Y. "Linear Logic." *Theoretical Computer Science* 50(1), pp. 1-101, 1987.
2. Wadler, P. "Linear Types Can Change the World!" *IFIP TC 2*, 1990.
3. Baker, H.G. "Lively Linear Lisp: 'Look Ma, No Garbage!'" *ACM SIGPLAN Notices* 27(8), 1992.
4. Baker, H.G. "'Use-Once' Variables and Linear Objects." *ACM SIGPLAN Notices* 30(1), 1995.
5. Tofte, M. and Talpin, J.-P. "Region-Based Memory Management." *Information and Computation* 132(2), pp. 109-176, 1997.
6. Clarke, D.G.; Potter, J.M.; Noble, J. "Ownership Types for Flexible Alias Protection." *OOPSLA 1998*.
7. Crary, K.; Walker, D.; Morrisett, G. "Typed Memory Management in a Calculus of Capabilities." *POPL 1999 / TOPLAS 22(4)*, 2000.
8. Reynolds, J.C. "Separation Logic: A Logic for Shared Mutable Data Structures." *LICS 2002*.
9. Grossman, D.; Morrisett, G.; et al. "Region-Based Memory Management in Cyclone." *PLDI 2002*.
10. Walker, D. "Substructural Type Systems." Chapter 1 in Pierce (ed.), *Advanced Topics in Types and Programming Languages*, MIT Press, 2005.
11. Abbott, M.; Altenkirch, T.; Ghani, N. "Containers: Constructing Strictly Positive Types." *TCS 342(1)*, pp. 3-27, 2005.
12. Fluet, M.; Morrisett, G.; Ahmed, A. "Linear Regions Are All You Need." *ESOP 2006*.
13. Stepanov, A.; McJones, P. *Elements of Programming*. Semigroup Press, 2009.
14. Altenkirch, T.; Ghani, N.; Hancock, P.; McBride, C.; Morris, P. "Indexed Containers." *Journal of Functional Programming* 25, 2015.
15. Bernardy, J.-P.; Boespflug, M.; Newton, R.R.; Peyton Jones, S.; Spiwack, A. "Linear Haskell: Practical Linearity in a Higher-Order Polymorphic Language." *POPL 2018*.
16. Jung, R.; Jourdan, J.-H.; Krebbers, R.; Dreyer, D. "RustBelt: Securing the Foundations of the Rust Programming Language." *POPL 2018*.
17. Weiss, A.; et al. "Oxide: The Essence of Rust." 2019.
18. Orchard, D.; Liepelt, V.-B.; Eades, H. "Quantitative Program Reasoning with Graded Modal Types." *ICFP 2019*.
19. Reinking, A.; et al. "Perceus: Garbage Free Reference Counting with Reuse." *PLDI 2021*.

### Language Prior Art

20. Rust RFC 1398: Kinds of Allocators. https://rust-lang.github.io/rfcs/1398-kinds-of-allocators.html
21. Rust Pre-RFC: Storage API (May 2023). https://internals.rust-lang.org/t/pre-rfc-storage-api/18822
22. matthieu-m/storage-poc. https://github.com/matthieu-m/storage-poc
23. servo/rust-smallvec. https://github.com/servo/rust-smallvec
24. Lokathor/tinyvec. https://github.com/Lokathor/tinyvec
25. rust-embedded/heapless. https://docs.rs/heapless/latest/heapless/
26. C++ std::pmr::polymorphic_allocator. https://en.cppreference.com/w/cpp/memory/polymorphic_allocator.html
27. C++ P3002R1: Policies for Using Allocators (2024). https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2024/p3002r1.html
28. Zig Allocator (std.mem.Allocator). https://github.com/ziglang/zig/blob/master/lib/std/mem/Allocator.zig

### Swift Prior Art

29. Lattner, C.; McCall, J.; et al. "Ownership Manifesto." https://github.com/swiftlang/swift/blob/main/docs/OwnershipManifesto.md
30. SE-0377: borrowing and consuming parameter ownership modifiers.
31. SE-0390: Noncopyable structs and enums.
32. SE-0427: Noncopyable generics.
33. SE-0437: Noncopyable stdlib primitives.
34. SE-0446: Nonescapable Types.
35. SE-0447: Span: Safe access to contiguous storage.
36. ManagedBuffer. https://developer.apple.com/documentation/swift/managedbuffer

### Internal Research

37. storage-ownership-reference-synthesis.md (v3.0.0, 2026-02-05) — Master synthesis for storage primitives.
38. protocol-abstraction-for-phantom-typed-wrappers.md (v1.3.0, 2026-02-04) — Protocol approach for phantom-typed wrapper operations.
39. noncopyable-copyable-conditional-audit.md — ~Copyable/Copyable conditional support audit.
40. storage-pool-architecture.md — Storage.Pool composition vs independence analysis.
