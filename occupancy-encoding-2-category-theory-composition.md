# Occupancy Encoding II — Category Theory: Composition Over Refinement

<!--
---
version: 1.0.0
last_updated: 2026-06-08
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
type: investigation/architecture
toolchain_of_record: Apple Swift 6.3.2 (swift-6.3.2-RELEASE, TOOLCHAINS=org.swift.632202605101a), arm64-apple-macosx26.0
builds_on:
  - swift-institute/Research/occupancy-lives-in-the-leaf.md            # DECISION (placement law) — this note supplies the categorical WHY + the refinement-dissolution proof
  - swift-institute/Research/conditional-deinit-conditionally-copyable-generics.md  # the Wall-1 proof (stands); this note builds on its S2/S5/S7/S8 probes
  - swift-institute/Research/storage-memory-split.md                   # DECISION (Storage.Split tensor; §2 G5 "model the tower as ML functors" — this note IS that probe
  - swift-institute/Research/derive-for-free-capability-composition.md # the warranted-refinement test (C1–C4) — applied here to the occupancy/allocation question for the first time
  - swift-institute/Research/cross-layer-capability-protocol-model.md  # the logical/physical capability split (Buffer HAS-A Storage)
companion_to: occupancy-encoding-2-category-theory-composition is the category-theory angle of a multi-angle occupancy-encoding study
provenance: research dispatch (category-theory angle); /tmp/occ-cat spikes 1–4 + cross-module, all compiled+run on 6.3.2
---
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

> **RESEARCH ONLY** — no tower edits. All empirical claims compiled and run on **Apple Swift 6.3.2**
> (`TOOLCHAINS=org.swift.632202605101a`); spike sources + binaries at `/tmp/occ-cat/` (spikes 1–4) and
> `/tmp/occ-cat/xmod/` (cross-module). Every load-bearing claim carries a `[Verified: 2026-06-08]` tag.

## Abstract

The shared problem asks how far Swift's type system can encode an occupancy-bearing container that
*simultaneously* (A) keeps **one** `Store.\`Protocol\`` with **no** `Store.Sparse` refinement, (B)
guarantees ≤1 bit/slot occupancy, (C) has value semantics / conditional `Copyable` with the carve-out
*types* dissolved into one generic `Buffer<S>`, (D) self-cleans on teardown with no buffer `deinit`,
and (E) is maximally decomposed and cleanly composed. The stated tension is that **bit-density ⟹ a
separate occupancy plane ⟹ custom teardown ⟹ a `deinit`**, and that **bitmap-in-leaf ⟹ the leaf owns
allocation ⟹ a surface richer than the 4-op `Store.\`Protocol\``, forcing the refinement.**

This note resolves the tension **categorically**, by *decomposition + composition rather than
subtyping.* The sparse store is modelled as a **product (tensor)** of two **orthogonal** objects in
the category of `~Copyable` value types: a pure addressable `Store` (the 4-op seam) and an
`Occupancy` capability (the allocation/liveness algebra). The two objects are independent protocols
— **`Occupancy` does not refine `Store`** — that a single concrete leaf satisfies *separately*. The
generic buffer is parameterised over the `Store` factor **only**; the allocation algebra attaches by
**capability conjunction in an extension constraint** (`where S: Occupancy`), exactly as the shipping
`Buffer.Arena` already does. The refinement wart therefore **dissolves into a clean product**: the
store never learns about occupancy, and a separately-composable, law-carrying `Occupancy` supplies
allocation.

The central claim — **the prompt's forcing premise is false** — is proven on 6.3.2: the richer
allocation surface lives on a *separate orthogonal capability*, reached by capability conjunction and
concrete specialization, **never by refining the store**. The one honest residual is not a fat
interface and not a type explosion: it is the **single copyability corner** *bit-density ∧
value-semantics ∧ inline*, which is irreducible for the reason `conditional-deinit-…` proved (Wall-1;
SE-0427). A–D are achieved in full; E is achieved; the residual is the copyability of one corner, not
a vacuous interface.

## Context

### Trigger

A research dispatch asked for the **category-theory angle** on the occupancy-encoding problem:
*dissolve the `Store.Sparse` refinement by decomposition + composition, not subtyping.* Concretely:
is the sparse store a **product/tensor** `Store ⊗ Occupancy`? Is liveness a **comonad**? Is allocation
a **free monoid**? Is the bitmap a **lens/optic** into a parallel plane? Does a parameterised
composite keep **one** pure `Store.\`Protocol\`` while a law-carrying `Occupancy` supplies allocation?

### What the ecosystem already decided (and what it left open)

Two Tier-3 documents bracket this question:

- **`occupancy-lives-in-the-leaf.md`** (DECISION, 2026-06-07) established the *placement law*:
  liveness + teardown live in a single-allocation **leaf**, never in the buffer; every
  `Buffer.<discipline>` is a thin no-`deinit` generic. It posited a **`Store.Sparse.Protocol`** (=
  `Store.Protocol` + `allocate`/`deallocate`/occupancy) for sparse leaves. **It did not ask whether
  that refinement is necessary, or whether allocation factors out as a separate composable object.**
  That is this note's question.
- **`conditional-deinit-conditionally-copyable-generics.md`** (RECOMMENDATION, 2026-06-06; superseded
  *in part*) proved the **Wall-1 law** — a custom conditional `deinit` on a conditionally-`Copyable`
  generic is impossible (SE-0427; `copyable_illegal_deinit`). Its probe matrix (S2/S5/S7/S8) is the
  load-bearing prior art this note builds on.

The placement law is settled. The *protocol shape* of the sparse leaf — refine vs compose — is **not**.
`storage-memory-split.md` §2 lists this exact gap as perfect-world delta **G5**: *"model the tower as
ML functors (signature/functor sketch) to validate the decomposition algebraically."* This note is
that probe, executed against the real compiler. [Verified: 2026-06-08 — `storage-memory-split.md:421-424`]

### Constraints

Research-only; no production edits; `/tmp` scratch for spikes. Tier-3 rigor per
[RES-020]/[RES-023]/[RES-024]/[RES-026]. Probe the real compiler before any "wall" claim
([feedback_convention_vs_typesystem_constraint]). Toolchain of record: Swift 6.3.2.

## Internal research survey [RES-019]

| Document | Status | Bearing |
|---|---|---|
| `occupancy-lives-in-the-leaf.md` | DECISION (Tier 3) | GOVERNS placement. This note supplies the categorical *why* and proves the `Store.Sparse` refinement is **avoidable** (the placement law does not require it). |
| `conditional-deinit-conditionally-copyable-generics.md` | RECOMMENDATION (superseded in part) | The Wall-1 law **stands**. S2 (uncond `~Copyable` + deinit ✅), S5 (cond-`Copyable`, no deinit ✅), S7 (automatic conditional field teardown ✅), S8 (no struct-only escape) are reused as the copyability-flow building blocks. |
| `storage-memory-split.md` | DECISION (Tier 3) | The **tensor** is already shipping as `Storage.Split<Lanes, Elements>` (two `Store.\`Protocol\`` factors; `Copyable(Split) ⇔ Copyable(both)`). §2 G5 names this note's task. §6/§8 supply the copyability laws this note generalizes. |
| `derive-for-free-capability-composition.md` | RECOMMENDATION (Tier 3) | The **warranted-refinement test** (C1 Identity / C2 Conformer-set / C3 Expressibility / C4 Cross-package). Principal bias: *"compose by default; refine only when warranted."* Applied to occupancy/allocation **for the first time** here. |
| `cross-layer-capability-protocol-model.md` | RECOMMENDATION (Tier 3, APPROVED) | `Buffer.\`Protocol\`` = occupancy (`count`+`isEmpty`); `Storage.\`Protocol\`` = slot access; Buffer **HAS-A** storage, does **not** refine it. The logical/physical split this note's product realizes at the leaf. |
| `buffer-namespace-membership-occupancy-vs-region.md` | RECOMMENDATION (Tier 2) | Confirms occupancy is the *distinguishing* concern (count ≠ capacity) and is **separable** from raw storage — corroborates the orthogonality the product asserts. |
| `buffer-arena-conditional-copyable.md` | IMPLEMENTED | The heap-sparse precedent: deinit on the `Storage` class, `Buffer.Arena` generic with no element deinit. The shipping existence proof that allocation need not be a generic protocol requirement. |

**No external survey supersedes these.** Per [RES-019] the internal corpus governs; the external
prior art (below) is contextualization, not the primary source for the decision.

## Question

Can the sparse store be encoded as a **product** `Store ⊗ Occupancy` of two **orthogonal** objects —
keeping **one** pure 4-op `Store.\`Protocol\``, with `Occupancy` a separately-composable, law-carrying
capability that **does not refine** `Store` — such that (A)–(E) all hold, teardown **factors through
the composite** (a theorem of the composition, not a hand-written buffer `deinit`), and the residual
(if any) is non-vacuous?

Answered on five axes, each with a 6.3.2 receipt: **the product law** · **refinement dissolution** ·
**teardown-as-theorem** · **where conditional `Copyable` lives** · **which categorical structures are
real vs decorative.**

---

## 1. The categorical model

### 1.1 The category

Let **𝒱** be the category whose objects are Swift value types in the `~Copyable` universe (i.e. types
declared `: ~Copyable`, which *may* regain `Copyable` conditionally) and whose morphisms are
total, ownership-respecting functions. 𝒱 has finite products: the product `A ⊗ B` is the struct with
two stored fields, projections `π_A`, `π_B`, and the pairing `⟨f,g⟩`. (We write `⊗` rather than `×`
to emphasise the *parallel-plane / SoA* reading the ecosystem already uses — `Storage.Split` cites
Accelerate's `DSPSplitComplex` for exactly this.)

The **copyability predicate** is a functor `𝖢: 𝒱 → 𝟐` (the two-element lattice `move-only ⊑ copyable`)
that *preserves finite products*:

```
𝖢(A ⊗ B)  =  𝖢(A) ∧ 𝖢(B)            (the product copyability law)
```

This is not folklore — it is forced by the language: a struct is `Copyable` iff it has no user
`deinit` **and** every stored field is `Copyable` (SE-0427; the formal predicate in
`conditional-deinit-…` §"Formal semantics"). The conjunction over fields **is** product-preservation
of 𝖢. [Verified: 2026-06-08 — Spike 1, the `Split: Copyable where Lanes: Copyable, Elements: Copyable`
extension compiles and a copy succeeds with two copyable planes, is rejected with a move-only plane.]

### 1.2 The two objects

| Object | Role | Surface (the morphisms it exposes) | Copyability |
|---|---|---|---|
| **`Store`** (the 4-op seam) | a pure *addressable* element store — a finite map `slot ↦ Element` with init-state transitions | `capacity`; `subscript(slot) { get set }`; `initialize(at:to:)`; `move(at:)` | flows from its backing leaf |
| **`Occupancy`** | the *allocation/liveness algebra* over the slot index set | `allocate() -> slot?`; `free(slot)`; `isOccupied(slot)`; `occupied` | flows from the same leaf |

The decisive structural fact: **`Occupancy` does not refine `Store`, and `Store` does not mention
`Occupancy`.** They are two independent protocols. A concrete leaf conforms to *both, separately* —
the two conformances live in two extension files that never reference each other (mirroring the
shipping `Storage.Arena+Store.Protocol.swift` vs `Storage.Arena ~Copyable.swift` split, where the
4-op witnesses and the allocate/free methods are in different files).

### 1.3 The composite

The **sparse leaf** is the object `Store ⊗ Occupancy` realised as *one allocation*: an element plane
and an occupancy plane, SoA, both owned by a single leaf that also carries the teardown morphism.
The **generic buffer** is a thin functor `Buffer: 𝒱_Store → 𝒱` that lifts a `Store`-object to a
container by adding only an *access discipline* (count / cursor / index / links) — and **no `deinit`**.

```
Collection           (user API)
   │  (functor: ergonomics)
Buffer<S: Store>     ← parameterised over the Store factor ONLY; no deinit; Copyable iff S Copyable
   │  (functor: access discipline)
S  =  Store ⊗ Occupancy   ← the sparse leaf: one allocation, two orthogonal planes, teardown morphism
   │
{ element plane | occupancy plane }   ← SoA; ≤1 bit/slot in the occupancy plane
```

This is precisely the shipping `Storage.Split` shape pushed down to the leaf, with the *second* plane
specialised from "metadata" to "occupancy bitmap."

---

## 2. Refinement dissolution — the central proof

### 2.1 The prompt's forcing premise, stated precisely

> *bitmap-in-leaf ⟹ the leaf owns allocation ⟹ a surface richer than the 4-op `Store.\`Protocol\``
> ⟹ forcing the refinement (`Store.Sparse`).*

The premise has a hidden quantifier error. "A surface richer than the 4-op seam" is true **of the
concrete leaf type** — `SparseLeaf` has `allocate`/`free`/`isOccupied` in addition to the 4 ops. But
"forcing the refinement" smuggles in *"the generic buffer must dispatch allocation through a protocol
that refines `Store`."* That second step is the false one. The richer surface can be a **separate
orthogonal capability** the generic buffer reaches by **capability conjunction**, with the store
protocol left pure.

### 2.2 The proof (Spike 2, [Verified: 2026-06-08])

`/tmp/occ-cat/spike2_occupancy.swift` declares:

```swift
protocol StoreProtocol: ~Copyable { /* the 4 ops, occupancy-blind */ }
protocol OccupancyProtocol: ~Copyable { mutating func allocate() -> Int?; mutating func free(_:Int); … }
//  ↑ OccupancyProtocol does NOT refine StoreProtocol.

struct SparseInlineLeaf<Element: ~Copyable>: ~Copyable { … }   // one allocation, ≤1 bit/slot bitmap
extension SparseInlineLeaf: StoreProtocol    { … }             // 4-op witnesses; NEVER names occupancy
extension SparseInlineLeaf: OccupancyProtocol { … }            // allocate/free/isOccupied; SEPARATE file-shape

struct Slab<S: StoreProtocol & ~Copyable>: ~Copyable { var _store: S }   // parameterised over Store ONLY
extension Slab where S: OccupancyProtocol, S: ~Copyable {                 // ← composition, not refinement
    mutating func insert(_ e: consuming S.Element) -> Int? { … }
    mutating func remove(at s: Int) -> S.Element { … }
}
```

It **compiles and runs on 6.3.2**, output `slots: 0 1 2 occupied: 2 read a,c: 10 30`. The generic
`Slab<S>` is constrained to `StoreProtocol` only. The allocation API attaches in an extension whose
constraint is the **conjunction** `S: StoreProtocol & OccupancyProtocol` — a *product of constraints*,
which is the type-level shadow of the object product `Store ⊗ Occupancy`. **No protocol refines another.
The 4-op `Store.\`Protocol\`` stays pure and unique.** ∎

### 2.3 The shipping architecture already does exactly this

This is not a hypothetical encoding — it is what `Buffer.Arena` ships **today**. [Verified: 2026-06-08
— `swift-buffer-arena-primitives` source]:

- `Storage.Arena` conforms `Store.\`Protocol\`` (the 4-op seam) — `Storage.Arena+Store.Protocol.swift:109`,
  `extension Storage.Arena: Store.\`Protocol\` where Element: ~Copyable {}`.
- Its `allocate()` / `unallocate()` / generation-token occupancy are **concrete methods**, NOT
  `Store.\`Protocol\`` requirements (`Storage.Arena.Inline ~Copyable.swift:120,140`).
- `Buffer.Arena.Bounded` is `struct Bounded: ~Copyable` over a private `Box` *class* holding the
  **concrete** `Storage<S.Element>.Arena`; its `insert`/`allocate`/`remove`/`free` are gated
  `where S == Storage<E>.Arena` and call **static methods on the concrete arena**, not protocol
  witnesses (`Buffer.Arena.Bounded ~Copyable.swift:57,77,91,121`).
- `extension Buffer.Arena.Bounded: Copyable where S: Copyable {}` — **copyability flows from the leaf.**

So the shipping arena reaches allocation by *concrete specialization* (`where S == concrete`); Spike 2
shows the *generic* route (`where S: Occupancy`) works equally. **Both are composition; neither is a
refinement of `Store.\`Protocol\``.** The `Store.Sparse.Protocol` posited by `occupancy-lives-in-the-leaf`
is therefore **not required** — it is one of (at least) three non-refinement encodings, and the
weakest by the warranted-refinement test (§4).

### 2.4 Where the prompt's premise *is* true — and why it doesn't bite

There is a real residue of truth in the premise: a **consumer that is itself generic over "any sparse
leaf"** (not pinned to a concrete one) and that needs to allocate must name the allocation surface
somehow. It names it as the **conjunction** `S: Store & Occupancy` (Spike 3's `sumLive`, which
specialises cleanly — §3.3). This is a *product of two protocols*, not a *refinement chain*. The
distinction is not cosmetic: a refinement `Store.Sparse: Store` would (i) force every sparse-leaf
author to carry the occupancy vocabulary in the *same* conformance as the store seam, (ii) make
"`Store` but not sparse" types awkward non-conformers, and (iii) bake allocation into the identity of
the storage seam the cross-module mutate-seam deliberately keeps neutral (CLCPM §12). The product
keeps all three clean. [Verified: 2026-06-08 — Spike 3 `sumLive<S: StoreProtocol & OccupancyProtocol>`
specialises to a concrete shared SIL function.]

---

## 3. Teardown is a theorem of the composition, not a hand-written deinit

### 3.1 The claim

Self-cleaning teardown should be **derivable** from the composite's structure: the composite's
value-witness destroys live slots; no buffer `deinit` is written.

### 3.2 The proof (Spikes 1–3, [Verified: 2026-06-08])

In all spikes the generic `Buffer`/`Slab` carries **no `deinit`**. Teardown factors through `S`'s
value-witness:

- **Move-only inline leaf** (`SparseInlineLeaf`): the leaf has a `deinit` that walks its own bitmap
  and deinitializes exactly the occupied-and-initialized slots, then frees. On `Slab` drop, the leaf's
  `deinit` runs automatically. Spike 2 leaves slots live on drop; the leaf self-cleans. The leaf is
  unconditionally `~Copyable` **because** it has that `deinit` (S2 of the prior note; SE-0427).
- **Heap leaf** (`SparseHeap`): the `deinit` is on the refcounted `Backing` class; it fires once at
  last release across `Copyable` copies. Spike 3 copies the heap-sparse `Slab` and both the original
  and copy tear down correctly (the backing is shared, the deinit single-shot).

Formally: teardown is the morphism `destroy: S → 𝟙` supplied by 𝒱's structure on the **leaf** object.
The functor `Buffer` adds no fields requiring cleanup (only `count`/cursor scalars), so `destroy(Buffer<S>)
= destroy(S) ; destroy(scalars)` and `destroy(scalars)` is trivial. **Teardown of the composite is the
teardown of the leaf, lifted for free** — exactly the S7 "automatic conditional field teardown" the
prior note proved Swift already performs. The buffer never needs the *custom* (Wall-1-blocked) deinit
because the custom step lives on the leaf, where it is legal. ∎

### 3.3 SE-0427 Wall-1 is avoided (D), not hit

The cleave-7 fear was: a *generic, conditionally-`Copyable`* buffer would need a `deinit` that runs
only for `~Copyable` instantiations — impossible (Wall-1). The product dissolves the fear: the buffer
is conditionally-`Copyable` (`Slab: Copyable where S: Copyable`) **and carries no `deinit`** (S5 of the
prior note: cond-`Copyable` generic with no deinit compiles). The custom teardown is on the leaf:
move-only leaf with a deinit (S2) **or** class-backed leaf with the deinit on the class. We assemble
**S2 + S5** (or class + S5), never S1 (the wall). [Verified: 2026-06-08 — all spikes compile; no spike
declares a generic buffer `deinit`.]

Wall-2 (`swiftlang/swift#86652`, cross-package `@_rawLayout` deinit-skip) is **orthogonal** to this
note — it is a codegen bug governed by [MEM-SAFE-027], unaffected by the categorical shape. The
shipping `Memory.Inline` carries the `_deinitWorkaround` for it. This note's composition argument is a
*design* result; Wall-2 is a *codegen* caveat for the inline corner specifically.

---

## 4. Refine vs compose — the warranted-refinement test, applied

`derive-for-free-…` supplies a four-part test for when refinement (not composition) is warranted.
Applied to *"should `Occupancy` refine `Store` (i.e. should `Store.Sparse: Store` exist)?"*:

| Criterion | Question | Verdict for `Occupancy` ⊑ `Store`? |
|---|---|---|
| **C1 — Identity** | Is every occupancy-bearing store an addressable store *as a matter of identity*, AND every addressable store occupancy-bearing? | **FAILS the symmetry.** A sparse leaf **HAS-A** occupancy plane; it *is* an addressable store. But `Memory.Heap`, `Memory.Inline`, `Storage.Contiguous` are addressable stores with **no** allocation algebra (dense, range-ledger). So `Store` ⊉ `Occupancy`: the dense stores are `Store` but not `Occupancy`. Refinement `Store.Sparse: Store` is fine *one way*, but it means "occupancy IS-A store-with-extra," which is the **HAS-A** relation mis-stated as IS-A. |
| **C2 — Conformer-set** | Is the conformer set of `Occupancy` a genuine subset of `Store`'s? | The sets **overlap, not nest**: the sparse leaves are both; the dense leaves are `Store`-only; a hypothetical pure free-list allocator with no typed slot access would be `Occupancy`-only. Overlap ⟹ **sibling + dual-conformance**, not refine (the mutator-stance rule). |
| **C3 — Expressibility** | Does refinement block a needed conformance? | A refinement `Store.Sparse: Store` forces every sparse leaf to satisfy occupancy *in the same conformance lineage* as the store seam. It does not hard-block (no `Tagged`-style recursion here), but it **couples** the neutral 4-op seam — which CLCPM §12 froze precisely to keep neutral — to an allocation vocabulary. |
| **C4 — Cross-package mechanics** | Can the edge be declared where needed without an unwanted dep? | A sparse leaf lives in its own package (`swift-storage-arena-primitives`, a future `swift-store-…-sparse`). Composition declares the two conformances at the leaf, pulling each protocol's package as a normal dep. A refinement would push the occupancy protocol *into the store-protocol package's identity* (every `Store` conformer transitively sees the sparse vocabulary), or force retroactive refinement (impossible cross-package). |

**Verdict: composition, decisively.** `Occupancy` and `Store` fail C1's symmetry and C2's nesting —
their conformer sets *overlap* (dense = `Store`-only; sparse = both). The corpus rule is explicit:
*sets overlap ⟹ sibling + dual-conformance, not refine.* **`Store.Sparse.Protocol` should not exist
as a refinement.** If a name for "a store that also allocates" is wanted, it is a **conjunction
typealias** or a marker that *inherits from both* (`protocol SparseStore: Store, Occupancy`) — a
*product in the protocol lattice*, which is composition, not a refinement that *adds* requirements to
`Store`. [Verified: 2026-06-08 — Spike 2/3 use the conjunction form; no refinement declared.]

This **corrects** the `occupancy-lives-in-the-leaf.md` framing of `Store.Sparse.Protocol` as
"`= Store.Protocol + allocate/deallocate/occupancy`": read as *adding requirements to a refinement of
`Store`*, it fails the test; read as *the conjunction `Store ∧ Occupancy`* (a protocol composition /
a marker inheriting both), it is the product this note endorses. The placement law is untouched; only
the protocol-shape reading is sharpened.

---

## 5. Which categorical structures are real — and which are decorative

The dispatch floated four structures. Per [RES-021]'s contextualization rule (universal adoption ≠
necessity), each is judged on whether it **buys** anything in 𝒱, not whether it is nameable.

### 5.1 Product / tensor `Store ⊗ Occupancy` — **REAL and load-bearing**

This is the spine of the whole result (§1–§3). It is a genuine categorical product: two projections,
a pairing, and 𝖢 preserves it. It already ships as `Storage.Split`. **Endorsed.**

### 5.2 Lens / optic into the occupancy plane — **REAL and clarifying**

The occupancy bitmap is a **lawful lens** `view: Slab ⊸ BitPlane` with `get`/`put` satisfying the
three lens laws. Spike 4 checks them on 6.3.2 (`get-put`, `put-get`, `put-put` all hold). The lens is
the right formalism for "the parallel plane": it is the projection `π_Occupancy` of the product,
equipped with focused mutation. It explains *why* plane non-interference holds (the lens's `put`
touches only the occupancy plane). **Endorsed as the precise description of the second projection.**
[Verified: 2026-06-08 — Spike 4 `SPIKE4 OK`.]

### 5.3 Free monoid of alloc/free — **REAL but bounded; a partial monoid action, stated honestly**

The allocation ops generate a monoid acting on the occupancy plane: `alloc`/`free` are generators,
sequencing is the monoid operation, the empty sequence is the identity, and `free(s) ∘ alloc()=s` is
the identity on occupancy (Spike 4: `dealloc∘alloc = id on occupancy plane`). But it is a **partial**
monoid action, not a free monoid simpliciter: `alloc` is *nondeterministic in its result slot* (it
returns the first vacant slot) and *partial* (returns `nil` at capacity); `free(s)` is only defined
when `s` is occupied. So the honest statement is: **alloc/free generate a partial monoid of
slot-state endomorphisms**, with `free` a left-inverse of the corresponding `alloc` on the occupancy
projection. This is enough to ground the "allocation algebra" intuition and the laws downstream
relies on (rollback, monotonicity); it is **not** a clean free monoid, and claiming so would be
decorative. **Endorsed in the partial-monoid-action form; the "free monoid" label is demoted.**
[Verified: 2026-06-08 — Spike 4 monotonicity + rollback checks.]

### 5.4 Comonad of liveness — **DECORATIVE; honestly rejected**

The dispatch asked whether liveness is a comonad (extract = read a slot, extend = propagate). It is
**not**, and forcing it would be the [RES-021] anti-pattern. For a comonad `W` one needs `extract: W A
→ A` and `duplicate: W A → W (W A)` satisfying the comonad laws. Occupancy is `isOccupied: slot →
Bool` — a function `Slot → 𝟐`, i.e. the *reader/store comonad's* counit shape only if the store is
modelled as `W A = (Slot, Slot → A)`. But (i) our slots carry `~Copyable` elements, so `Slot → A` is
not a total copyable function (the comonad's `extend` would duplicate `A`), and (ii) **nothing in
allocation, teardown, or buffer composition consults a `duplicate`/`extend`** — Spike 3 implements the
full sparse buffer with zero comonadic structure. A structure that no operation uses is decorative.
**Rejected.** (The reader-comonad framing of `isOccupied` is at best a *description* of one read
morphism, with no `extend` consumer — it earns no place in the model.)

**Summary:** the model is a **product of two objects**, with the occupancy object presented as a
**lens** and the allocation ops as a **partial monoid action**. Comonad and "free monoid" are demoted
as decorative. This is the [RES-021] contextualization discipline applied to category theory itself.

---

## 6. Formal semantics [RES-024]

### 6.1 Objects, morphisms, copyability functor

𝒱: objects = `~Copyable`-universe value types; morphisms = total ownership-respecting maps; `⊗` = the
two-field struct product with projections `π₁,π₂` and pairing `⟨·,·⟩`. The copyability functor
`𝖢: 𝒱 → 𝟐` is product-preserving:

```
𝖢(A ⊗ B) = 𝖢(A) ∧ 𝖢(B)        and on a leaf:  𝖢(Leaf) = ¬hasUserDeinit(Leaf) ∧ ⋀_f 𝖢(field_f)
```

### 6.2 The two capability objects (protocols as theories)

```
Store    ⊨  { capacity : ℕ,  get/set : Πslot. El,  initialize : slot × El ⊸ 𝟙,  move : slot ⊸ El }
Occupancy⊨  { allocate : 𝟙 ⇀ slot,  free : slot ⊸ 𝟙,  isOccupied : slot → 𝟐,  occupied : ℕ }
```

`Store ⊬ Occupancy` and `Occupancy ⊬ Store` (no entailment either way). A sparse leaf is a model of
**`Store ∧ Occupancy`** (the product theory) over one carrier.

### 6.3 The product theorem (refinement-free)

Let `B` be the buffer functor `B(S) = S ⊗ Scalars` with `Scalars` trivial-copyable (count/cursor).
Then for any `S ⊨ Store`:

```
(i)   B(S) ⊨ Store              — the buffer is itself an addressable store (forwards the 4 ops)
(ii)  𝖢(B(S)) = 𝖢(S)            — copyability flows from S  (Scalars trivially copyable)
(iii) destroy(B(S)) = destroy(S) — teardown factors through S  (Scalars trivial to destroy)
(iv)  B(S) ⊨ Occupancy  iff  S ⊨ Occupancy   — the allocation algebra is present exactly when S has it
```

(i)–(iii) hold for *every* `S` (dense or sparse); (iv) is the conjunction-not-refinement clause: the
buffer gains the allocation surface **by composition with `S`'s second factor**, conditionally,
**without** `Store` ever entailing `Occupancy`. The `Store.Sparse` refinement would replace (iv)'s
biconditional with an unconditional "`B(S) ⊨ Store.Sparse`," over-committing every store. ∎

### 6.4 Soundness of refinement-free teardown

If `S` is move-only (`¬𝖢(S)`), `B(S)` is move-only by (ii), and the unique value of `B(S)` runs
`destroy(S)` exactly once at end of scope — the leaf's `deinit`. If `S` is class-backed
conditionally-`Copyable`, copies of `B(S)` share `S`'s backing; `destroy(S)` fires once at last
release. In neither case does a *generic value-type buffer* declare a `deinit`, so the Wall-1 law
(`hasUserDeinit ⟹ ¬∃ Copyable`) is never triggered for `B`. The custom teardown lives only where it is
legal: a move-only leaf (`hasUserDeinit ∧ ¬Copyable` — consistent) or a class (classes are exempt,
`TypeCheckInvertible.cpp:221-223`). **Soundness reduces to the prior note's S2/S5 results, composed.** ∎

---

## 7. Scorecard — A–E against the composite

| # | Requirement | Verdict | Evidence (6.3.2) |
|---|---|---|---|
| **A** | ONE `Store.\`Protocol\``, no `Store.Sparse` refinement | **ACHIEVED** | Spikes 2/3: generic buffer constrained to the 4-op store only; occupancy is a *non-refining* sibling capability; allocation by conjunction `where S: Occupancy`. §2, §4. |
| **B** | ≤1 bit/slot occupancy | **ACHIEVED** | Spikes 2/3/4: occupancy plane is a `UInt64`-word bitmap inside the leaf's single allocation; exactly 1 bit/slot. |
| **C** | value semantics / conditional `Copyable`; carve-out *types* dissolved into one `Buffer<S>` | **ACHIEVED** | Spike 3: ONE `Slab<S>` covers move-only inline-sparse AND conditionally-`Copyable` heap-sparse; `Slab: Copyable where S: Copyable` (one line). Copyability flows from the leaf. |
| **D** | self-cleaning teardown; no buffer `deinit`; SE-0427 Wall-1 avoided | **ACHIEVED** | §3: no generic buffer carries a `deinit`; teardown factors through the leaf's value-witness; assembled from S2+S5, never S1. |
| **E** | maximal decomposition + clean composition | **ACHIEVED** | The store factor, the occupancy factor, the leaf, the buffer functor, and the access discipline are five separable pieces; composition is a product + a conditional capability conjunction. |

**All five achieved on 6.3.2.** The composite is `Buffer<S>` where `S ⊨ Store` (always) and
`S ⊨ Occupancy` (for sparse leaves), with copyability and teardown lifted from `S`.

---

## 8. The honest residual — and why it is NOT vacuous, NOT a fat interface

The residual is the **single copyability corner**: *bit-density ∧ value-semantics ∧ inline,
simultaneously.*

- A bit-dense **inline** sparse leaf has a `deinit` (walk the inline bitmap) ⟹ it is **move-only**
  (SE-0427; `conditional-deinit-…` Wall-1, which **stands**). So an inline-sparse *buffer instance* is
  move-only.
- This is **fine and expected**: dense inline buffers are already move-only, and the carve-out *type*
  still dissolves — one `Buffer<S>`, copyability flowing from `S` (Spike 3). The residual is **not** a
  forced concrete `.Inline` *type* (that error is corrected by `occupancy-lives-in-the-leaf`); it is
  the *copyability* of one instantiation.
- The only way to buy value-semantics back for the inline corner is the **tombstone** form
  (`Element?` per slot), which spends bit-density (a full optional discriminator per slot, ≫1 bit) to
  gain copyability. So the trilemma `{bit-density, value-semantics, inline}` admits any **two**, never
  all three. This is the **irreducible core** — and it is one corner's *copyability*, not a fat
  interface and not a type explosion.

**Why it is not vacuous.** The residual is a *real* trilemma with a *real* cost curve (density vs
copyability vs heap-indirection), each corner reachable by the same `Buffer<S>` with a different leaf
`S`. It is not a no-op conformance and not an empty interface — it is the precise statement of what
the type system *cannot* give for free, traced to a specific, fundamental language law (SE-0427) with
an open Evolution path (the held PITCH-0003). Contrast a *vacuous* residual (a refinement that adds
nothing, an interface no consumer uses): this residual *forces a design choice at the leaf* and
*changes the copyability of the result* — it is load-bearing.

---

## 9. Drawback ledger (honest)

| Drawback | Severity | Mitigation / note |
|---|---|---|
| **Conjunction ergonomics**: consumers needing allocation write `where S: Store & Occupancy` (two protocols), not one refinement name. | Low | A marker `protocol SparseStore: Store, Occupancy {}` (composition, not requirement-adding refinement) gives a single name while staying a *product in the protocol lattice* — it passes the §4 test because it adds **no** requirements of its own. Distinct from `Store.Sparse: Store` (which adds requirements and fails C1/C2). |
| **Two conformances per sparse leaf** (the `Store` witnesses and the `Occupancy` witnesses live in separate extensions). | Low | This is *exactly* the shipping `Storage.Arena` file layout; the mutator-stance rule notes dual-conformance authors two extensions either way — refinement saves nothing here. |
| **`occupied`/`isOccupied` are O(capacity) popcount/scan in the toy leaves.** | N/A (spike artifact) | The real leaves cache the popcount in the header (`Buffer.Slab` `occupancy`, `Storage.Arena` `occupied`). Not a model property. |
| **Inline-sparse buffer instances are move-only** (the residual). | Inherent | §8. Fundamental (SE-0427), not a flaw of the composition. The carve-out *type* still dissolves. |
| **Wall-2 (`#86652`) cross-package deinit-skip for inline leaves.** | Codegen bug, orthogonal | Governed by [MEM-SAFE-027]; `_deinitWorkaround` on the leaf. Not a design constraint; removable when `#86652` lands. |
| **The conjunction relies on the optimizer specializing two capabilities, not one.** | Low | [Verified: 2026-06-08] cross-module SIL: zero `witness_method` in the client driver of `Slab<SparseHeapBacking<Int>>`; `sumLive<S: Store & Occupancy>` specialises to a concrete function. The product specialises as well as the single seam. |

---

## 10. The boundary

**How far Swift's type system goes (proven on 6.3.2):**

- A **product** `Store ⊗ Occupancy` of two **orthogonal, non-refining** capabilities encodes the
  sparse store with **one** pure 4-op `Store.\`Protocol\``. (A) ✓
- The occupancy plane is a **lawful lens** at ≤1 bit/slot inside one allocation. (B) ✓
- **One** generic `Buffer<S>` covers move-only inline-sparse and conditionally-`Copyable` heap-sparse;
  copyability is a *product-preserving functor* lifting from the leaf. (C) ✓
- Teardown is a **theorem of the composition** — the leaf's value-witness, lifted; no buffer `deinit`;
  Wall-1 avoided by assembling S2/S5. (D) ✓
- Maximal decomposition into five separable pieces, composed by product + conditional conjunction.
  (E) ✓

**Where it stops (the wall, with the repro):**

- The **single corner** *bit-density ∧ value-semantics ∧ inline* is unreachable: an inline bitmap-walking
  `deinit` forces move-only (SE-0427 Wall-1). Minimal repro on 6.3.2: `conditional-deinit-…` S1
  (`deinit` on a conditionally-`Copyable` generic) → `error: deinitializer cannot be declared in
  generic struct that conforms to Copyable`; no spelling, no experimental flag unlocks it
  ([Verified: 2026-06-06] in that note; re-confirmed by this note's reliance on S2/S5 instead). The
  composition does **not** hit this wall — it *routes around* it by placing the custom deinit on the
  leaf — but it cannot *erase* the trilemma: the inline corner pays in copyability.
- This residual is **not vacuous**: it is a real, load-bearing design choice at the leaf, traced to a
  fundamental language law, with an open (but deferred) Evolution path.

**Net:** the categorical reframing **dissolves the refinement entirely** (the `Store.Sparse`
subtyping wart becomes a clean product; the prompt's forcing premise is false) and **achieves A–E in
full**, leaving exactly one irreducible residual — the copyability of one corner, which is the same
SE-0427 boundary `conditional-deinit-…` already mapped, now shown to be the *only* thing the
composition cannot give.

## Outcome

**Status: RECOMMENDATION** (Tier 3, ecosystem-wide).

1. **Model the sparse store as the product `Store ⊗ Occupancy`** of two orthogonal, **non-refining**
   capabilities. The generic buffer is parameterised over `Store` only; allocation attaches by
   conditional conjunction (`where S: Occupancy`). This is the categorical justification for the
   already-decided placement law (`occupancy-lives-in-the-leaf`), and it **sharpens** that note's
   `Store.Sparse.Protocol`: it should be a **conjunction/marker inheriting both** (a protocol-lattice
   product), **never a requirement-adding refinement of `Store`** — which fails the warranted-refinement
   test (C1/C2: overlapping, non-nesting conformer sets).
2. **Endorsed categorical structures**: product/tensor (load-bearing); lens (the occupancy projection);
   partial monoid action (alloc/free). **Demoted**: "free monoid" (it is partial/nondeterministic);
   **rejected**: comonad-of-liveness (decorative — no `extend`/`duplicate` consumer; [RES-021]).
3. **A–E achieved on 6.3.2**; the lone residual is the copyability of the inline corner (SE-0427
   Wall-1), which is non-vacuous and identical to the boundary `conditional-deinit-…` mapped.
4. **No production edits.** The proofs are `/tmp/occ-cat` spikes. If the seat adopts the conjunction
   reading of `Store.Sparse`, the change is a *protocol-shape* note for the leaf packages, not a tower
   edit — sequenced by the principal.

This note **does not** supersede `occupancy-lives-in-the-leaf.md`; it supplies its categorical *why*
and corrects only the *reading* of `Store.Sparse.Protocol` (composition product, not refinement). It
**does not** disturb the Wall-1 proof in `conditional-deinit-…`; it builds on it.

## References

### Internal (governs per [RES-019])
- `swift-institute/Research/occupancy-lives-in-the-leaf.md` — DECISION (Tier 3, 2026-06-07): the placement law; `Store.Sparse.Protocol` posited. This note sharpens its protocol-shape reading.
- `swift-institute/Research/conditional-deinit-conditionally-copyable-generics.md` — RECOMMENDATION (Tier 3, 2026-06-06): the Wall-1 proof + probe matrix S1–S8. S2/S5/S7/S8 reused here.
- `swift-institute/Research/storage-memory-split.md` — DECISION (Tier 3): `Storage.Split` tensor; §2 G5 ("model the tower as ML functors") = this note's task; §6/§8 copyability laws.
- `swift-institute/Research/derive-for-free-capability-composition.md` — RECOMMENDATION (Tier 3): the warranted-refinement test (C1–C4), applied here to occupancy/allocation.
- `swift-institute/Research/cross-layer-capability-protocol-model.md` — RECOMMENDATION (Tier 3, APPROVED): logical/physical capability split; Buffer HAS-A Storage.
- `swift-institute/Research/buffer-namespace-membership-occupancy-vs-region.md` — RECOMMENDATION (Tier 2): occupancy (count ≠ capacity) is the separable distinguishing concern.
- `swift-institute/Research/buffer-arena-conditional-copyable.md` — IMPLEMENTED: the heap-sparse precedent (deinit on the class; generic buffer no element deinit).

### Source (verified on disk 2026-06-08, [RES-023])
- `swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:20-69` — `__StoreProtocol` (the 4-op seam); docstring: `Storage.Protocol` *refines*, `Memory.Contiguous` *conforms to* it.
- `swift-storage-split-primitives/Sources/Storage Split Primitives/Storage.Split.swift:54-77` — `Split<Lanes: Store.\`Protocol\`, Elements: Store.\`Protocol\`>`; `:124` `Copyable where Lanes: Copyable, Elements: Copyable` (the product copyability law, shipping).
- `swift-storage-arena-primitives/Sources/Storage Arena Primitives/Storage.Arena+Store.Protocol.swift:109` — `Storage.Arena: Store.\`Protocol\`` (4-op only); allocate/occupancy are concrete methods, not requirements.
- `swift-buffer-arena-primitives/Sources/Buffer Arena Bounded Primitive/Buffer.Arena.Bounded.swift:21,74` — `struct Bounded: ~Copyable`; `Copyable where S: Copyable`; allocation reached by `where S == Storage<E>.Arena` static calls (`Buffer.Arena.Bounded ~Copyable.swift:57,77,91,121`).
- `swift-memory-inline-primitives/Sources/Memory Inline Primitives/Memory.Inline.swift:38-90` — `@_rawLayout` move-only inline leaf; `_initialization` ledger; self-cleaning `deinit`; `_deinitWorkaround` for `#86652`.

### Empirical artifacts (Swift 6.3.2, [Verified: 2026-06-08])
- `/tmp/occ-cat/spike1_tensor.swift` — the product `Split<Lanes, Elements>`; `𝖢(A⊗B)=𝖢(A)∧𝖢(B)`; thin no-deinit buffer. Output `tensor copy read: 42 lane: 1`.
- `/tmp/occ-cat/spike2_occupancy.swift` — occupancy as a **non-refining** sibling; generic buffer pure-4-op; allocation by `where S: Occupancy`. Output `slots: 0 1 2 occupied: 2`.
- `/tmp/occ-cat/spike3_onebuffer.swift` — ONE `Slab<S>` over inline-sparse (move-only) AND heap-sparse (cond-Copyable); `sumLive<S: Store & Occupancy>` specialises. Output `inline-sparse … sumLive: 400`, `heap-sparse … copy.sumLive: 6`.
- `/tmp/occ-cat/spike4_laws.swift` — lens laws (get-put/put-get/put-put), partial-monoid laws (free∘alloc=id, monotone, rollback), plane non-interference. Output `SPIKE4 OK`.
- `/tmp/occ-cat/xmod/{Lib,Client}.swift` — cross-module composite; **zero `witness_method` in the client driver**; output `xmod occupied: 2 total: 44`.

### Prior art [RES-021] (contextualization; primary-source)
- **SE-0427 Noncopyable Generics**, § "Conformance to `Copyable`" — "A conditional `Copyable` conformance is not permitted if the struct or enum declares a `deinit`. Deterministic destruction requires the type to be unconditionally noncopyable." (the Wall-1 law; the residual's root.)
- **Lens laws** — the optic literature's get-put / put-get / put-put (van Laarhoven / profunctor optics); used as the formal description of the occupancy projection.
- **Rust** `Drop ⟹ !Copy` (E0184), no conditional `Drop` impls (E0367) — the same restriction (per `conditional-deinit-…`'s parallel-subagent-verified survey); confirms the residual is cross-language, not a Swift gap.
- **Category theory** — finite products with a product-preserving functor (`𝖢`); partial monoid actions; comonads (rejected here per [RES-021] — universal nameability ≠ necessity).
