# The Decomposition Layer-Placement Calculus

<!--
---
version: 1.0.0
last_updated: 2026-06-05
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
normative: false (research; feeds a later /modularization skill-lifecycle step + a /blog-process — both deferred)
type: investigation/architecture
depends_on:
  - swift-institute/Research/cross-layer-capability-protocol-model.md   (CLCPM — the capability normal form this generalizes)
  - swift-institute/Research/memory-byte-bit-domain-orthogonality.md     (the location ⊥ representation axis model)
  - swift-institute/Research/storage-memory-split.md                     (case study 1 — the #3 split, DECISION)
  - swift-institute/Research/store-capability-elimination.md             (case study 2 — the store warts)
  - swift-institute/Research/sub-product-split-decision-rubric.md        (the package-promotion rubric this EXTENDS, does not override)
  - .probe-bank/prism-capacity/findings.md                              (case study 3 — the capacity axes; Prism)
  - .probe-bank/prism-wart/findings.md                                  (case study 2 receipts; Prism)
  - .probe-bank/prism-endstate/end-state-research-note.md               (the consolidated end-state inventory; Prism)
provenance: tier-3 /research-process dispatch (HANDOFF-decomposition-layer-placement.md). Read-only on
  production; six external prior-art clusters parallel-subagent-verified [RES-020] 2026-06-05. The Research
  repo is PUBLIC — held for seat verification; not pushed.
---
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

> **What this note is.** A first-principles, formally-grounded calculus that answers, for *any* variant or
> capability in the MSB data-structure tower (**M**emory → **S**torage → **B**uffer → ADT), the question
> *"which layer canonically owns this concern?"* — mechanically, before the mistake is made, rather than
> discovering it after the fact. It is the **theory layer** above two in-flight empirical arcs (Cleave-4.5,
> which is dissolving `Storage.{Heap,Inline,Small}` into `Storage.Contiguous<Memory.X>`; and Prism, which is
> empirically placing `.Bounded/.Fixed/.Static`). It **generalizes their specific findings into one reusable
> placement framework** and supplies the scientific basis for a later `/modularization` skill refactor.

---

## Context

The MSB capability tower keeps **mis-placing variant concepts**, and each correction has been ad hoc:

- `.Small` / `.Inline` were parked at **Storage** but are byte-**LOCATION** concerns that belong at
  **Memory** — corrected, case by case, by `storage-memory-split.md` and the consolidated end-state note.
- The store-tier capability warts `Store.Creatable` / `Store.Tracked` encoded **memory-leaf properties**, not
  store properties — corrected by `store-capability-elimination.md`.
- `.Bounded` / `.Fixed` / `.Static` are under live empirical investigation (Prism's capacity note).

Each correction re-derived the same judgment from scratch. There was **no science** — no first-principles
calculus that, given a variant or capability, *says which layer owns it*. This note supplies it. The
recurring lens that the corpus had already converged on informally —

> **Memory** = *how/where addressable slots are obtained* (allocation, addressing, liveness, growth);
> **Storage** = *how live slots are arranged across regions* (single- vs multi-region topology);
> **Buffer** = *the logical occupancy/order of elements* (count, front/back, FIFO/LIFO, sparse, handles)
> *(`prism-endstate/end-state-research-note.md` §"The governing principle")* —

is here **derived from first principles, formalized as placement typing rules with a soundness sketch, and
validated against the three case studies**, so it can become `[MOD-*]` rules instead of folklore.

### Question (precise)

For a concern `C` (a variant axis, a capability, a stored requirement, a protocol), what is the function
`place(C) = L` that assigns `C` to a tower layer `L`, such that:

1. `C` sits at the **lowest** layer that can correctly own it (**maximum decomposition** — the cure for the
   `.Small`-at-Storage *too-high* mistake), **but**
2. `C` is **not** pushed below the layer where it stays correct (the **honest hard floor** — the cure for the
   inverse *too-low* mistake, e.g. a bounded cap crushed into a leaf that silently overflows)?

This is a **placement / membership question** in the sense of `[RES-029]`: it is answered by **semantic
identity first** (which design-decision-*secret* is `C`; which abstraction barrier existentially binds it),
with cost axes (dep-graph weight, the 0-`witness_method` specialization boundary) admissible only as
**tiebreakers among already-correct placements**, never as selectors. Per the standing principal directive
and `[RES-029]`'s ranking, "where does `C` live" is not a cost calculation.

### Internal Research Survey & Reconciliation ([RES-019] / [HANDOFF-013])

Each prior-art artifact was read in full and is **extended, not duplicated**. Verification tags per
`[RES-013a]`/`[RES-023]`.

| Artifact | Status read | Disposition | What this note takes |
|---|---|---|---|
| `cross-layer-capability-protocol-model.md` (CLCPM, v1.5.0, Tier 3) | `[Verified: 2026-06-05]` | **GENERALIZE** | The HAS-A stack of *minimal cores* + *orthogonal cross-cutting concerns*; the three edge kinds (R/C/D); the **(R)-vs-(C) decision rule** ("refine only when identity is the supertype's concern; compose otherwise"); the 0-`witness_method` specialization boundary. The calculus is CLCPM's *normal form* applied to **placement** rather than to protocol-shape. |
| `memory-byte-bit-domain-orthogonality.md` (v1.0.0, Tier 3) | `[Verified: 2026-06-05]` | **EXTEND** | The **location ⊥ representation** axis split (`H : Address ⇀ Value`, Reynolds); span as a namespace-neutral *capability* lifted out of a core. Its memory/byte/bit prior art was itself parallel-verified `[Verified: 2026-06-03]` and is cited, not re-run. |
| `storage-memory-split.md` (v1.1.2, Tier 3, **DECISION**) | `[Verified: 2026-06-05]` | **VALIDATE (case 1)** | The Memory/Storage boundary; the `Store.Protocol ⊂ Store.Tracked.Protocol ⊂ Storage.Protocol` stack; the **hard floor** (the `bd04f32` wall). The note's §1b academic lineage register is folded into the SLR (§6) and independently re-verified. |
| `store-capability-elimination.md` (v1.0.0, Tier 2) + `prism-wart/findings.md` | `[Verified: 2026-06-05]` | **VALIDATE (case 2)** | The wart principle and its receipts (`Tracked.live = 0` leaf-private vs `5` leaked). |
| `prism-capacity/findings.md` (+ ADDENDUM, 2026-06-05) | `[Verified: 2026-06-05]` | **VALIDATE (case 3)** | The 4-axis decomposition of `.Bounded/.Fixed/.Static`; the overflow-signaling floor; the explicit naming of the *too-low* inverse mistake. |
| `prism-endstate/end-state-research-note.md` (v1.0.0, Tier 2, consolidated) | `[Verified: 2026-06-05]` | **GENERALIZE** | The governing lens + the placement of the six discipline families + the two honest floors. This note is the *theory above* that *inventory*. |
| `sub-product-split-decision-rubric.md` (v1.0.0) | `[Verified: 2026-06-05]` | **EXTEND, do NOT override** | Its Gate-0→3 rubric governs **package-promotion** (should a sibling become its own `Package.swift`). This note governs **concern-placement** (which tower layer a concern lives at). The two are **orthogonal**; §7 threads the placement calculus *through* the rubric without weakening Gate 1. |
| `buffer-storage-associatedtype-prior-art.md` (v1.0.0, Tier 2) | `[Verified: 2026-06-05]` | **EXTEND** | "Compose-don't-refine"; the floor's canonical wording ("the wall as signal-not-defect / wrong shape"); T4 (capability-yields-a-base) is the dominant precedent. |
| `nonescapable-support-memory-storage-buffer.md` (v2.1.0, Tier 2, **DECISION**) | `[Verified: 2026-06-05]` | **EXTEND** | The 5-category ownership taxonomy; "owners MUST NOT be `~Escapable`"; "annotate a relationship the compiler can't enforce" — a second instance of the hard floor on the lifetime axis. |
| `memory-storage-composition-feasibility.md` (v1.0.0, Tier 2) | `[Verified: 2026-06-05]` | **EXTEND** | The SE-0107 **raw/typed** split (raw = Memory, typed = Storage); composition (has-a) over re-implementation. |
| `data-structures-variant-catalog-*.md` (4) + `variant-naming-audit.md` | `[Verified: 2026-06-05]` | **CLASSIFY** | The variant inventory (§5.4); the audit's "placement token at all three infra layers" convention, refined by the end-state note's deletion of `Storage.{Inline,Heap,Small}` (noted in §7). |

**No corpus document contradicts the calculus.** The single *tension* — the package-promotion rubric's Gate-1
brake on decomposition — is resolved in §7 by distinguishing the two orthogonal calculi. Where this note
*refines* an earlier convention (the variant-naming-audit's "location token legitimately lives at Memory ∧
Storage ∧ Buffer"), it does so by **consuming an existing supersession** (the end-state note already deletes
`Storage.{Inline,Heap,Small}`), not by minting a new disagreement — per `[META-003]`/`[META-004]`.

---

## §1 — Ontology: what each tower layer canonically owns

### 1.1 First-principles derivation

A data structure is, at bottom, a **typed view over a store**. Following Reynolds' separation-logic model,
a store is a finite partial function

```
    σ : Location ⇀ Value          (Reynolds 2002: H : Address ⇀ Value, finite, Addresses ⊥ Values)
```

where **Location and Value are disjoint sorts**. Building a data structure from this primitive requires a
sequence of **design decisions**, and — this is the crux — those decisions are **mutually orthogonal**: each
can be varied while the others are held fixed. By Parnas (1972), the correct decomposition assigns **one
design decision (one "secret") to one module**; by Mitchell & Plotkin (1988), a module *owns* a decision
exactly when that decision is the module's **existentially-bound representation variable** `∃X.T` — packed
behind its interface and, by Reynolds' abstraction theorem (1983), unobservable to any well-typed client
above it. The four tower layers are precisely the four orthogonal decisions one must make to turn `σ` into a
data structure, in dependency order:

| # | Question (the design decision) | The orthogonal axis | Layer | Why it is *this* layer's secret |
|---|---|---|---|---|
| 1 | *Where does a value physically live, and who frees it?* | **LOCATION ⊥ ALLOCATION** — a *partial product* of orthogonal sub-axes over `dom(σ)`: where the bytes sit (inline/out-of-line/hybrid) ⊥ how an out-of-line region is recycled (single-buffer/bump/free-list) ⊥ liveness ⊥ growth ⊥ addressing (§1.2.1) | **Memory** | This *is* the algebra of `dom(σ)`. By Tofte–Talpin and RustBelt, allocation, liveness, and the right to free are intrinsic to the owner of the region — they cannot be named by any lower thing (there is none) nor seen by any higher one. |
| 2 | *Given live slots, how are they arranged across regions?* | **TOPOLOGY + init-TRACKING** — one contiguous run vs multiple planes (SoA); the initialization-status ledger | **Storage** | Arrangement-across-regions is meaningful only *given* that slots exist (HAS-A Memory). Whether the live set is `[0,count)` or a sparse range-set is a typestate (Strom–Yemini) discipline over the slots. |
| 3 | *Given an arrangement, what is the logical occupancy/order?* | **OCCUPANCY DISCIPLINE** — count, front/back, FIFO/LIFO, dense vs sparse, stable handles | **Buffer** | Occupancy/order is meaningful only *given* a slot arrangement (HAS-A Storage). It is bookkeeping *over* slots, blind to where the bytes live. |
| 4 | *Given an occupancy discipline, what abstract contract holds?* | **CONTRACT** — membership, key→value, ordering, priority, the laws | **ADT / Collection** | The abstract semantics is meaningful only *given* an occupancy substrate (HAS-A Buffer). It is the type's externally-observable algebra. |

This is exactly CLCPM's HAS-A chain of minimal cores — `Memory ◄has─ Storage ◄has─ Buffer ◄has─
Collection` — read **ontologically**: each `◄has─` edge is *"this layer's decision presupposes, but does not
observe, the layer below's."* None **IS-A** the layer below (CLCPM's (R)-vs-(C) rule: refine only when
identity holds; here identity never holds across the HAS-A edges, so the relation is always composition).

### 1.2 The four owners, and the question each answers

| Layer | The question it answers | Owns (its secret) | Capability surface (CLCPM / the split) |
|---|---|---|---|
| **Memory** | *Where do the bytes live, and who owns their lifetime?* | a **partial product** of orthogonal sub-axes (§1.2.1): byte-LOCATION ⊥ ALLOCATION-discipline ⊥ liveness/teardown ledger ⊥ growth + relocation ⊥ addressing | the leaves are *points* in that product, not one-axis siblings: `Memory.Inline`/`Heap`/`Small` differ on **Location**, `Heap`/`Arena`/`Pool` differ on **Allocation-discipline** — all conforming the FROZEN 4-op `Store.Protocol`; `Memory.Allocator.Protocol` marks the allocation sub-axis (`Inline` does *not* conform — the tell); a `Growable` marker the growth sub-axis |
| **Storage** | *How are live slots arranged across regions?* | slot-TOPOLOGY (single-region `Contiguous` vs multi-region `Split`/SoA) · the init-TRACKING vocabulary | `Storage.Contiguous<M>` / `Storage.Split<…>`; `Store.Tracked.Protocol` (the ledger as a requirement); `Storage.Protocol` (pure marker) |
| **Buffer** | *What is the logical occupancy/order?* | access/occupancy DISCIPLINE (dense `Linear`/`Ring`; sparse `Slab`/`Slots`; node-linked) | `Buffer.{Linear,Ring,Slab,Slots,Linked}<S>`; `Buffer.Protocol` (`count`) |
| **ADT** | *What abstract contract does the type satisfy?* | the abstract CONTRACT (membership, key→value, order, priority) + laws | `Set`/`Dictionary`/`Stack`/`Queue`/`Heap`/`Tree`/`List`; `Set.Protocol` + the algebra bridge |

### 1.2.1 Within Memory: orthogonal sub-axes, not one-axis siblings (why `Arena`/`Pool` are `Memory.*`)

Memory is one tower *layer* but **not one axis**. Its secret is a **partial product** of orthogonal
sub-axes, all flooring at Memory because each is a property of *the owned region*:

- **Location** — where the element bytes sit: `in-struct` (inline) · `out-of-line` (indirected/ARC) ·
  `hybrid` (inline ≤ n ⊕ spill).
- **Allocation discipline** — *how an out-of-line region is obtained and recycled*: `single-buffer` (Heap) ·
  `bump` (Arena) · `free-list` (Pool). **Inhabited only when Location = out-of-line** — an in-struct buffer
  has no region to manage.
- **Growth-ability**, **Liveness/teardown ledger**, **Addressing** — the three further leaf-private
  capabilities (the end-state note's "FOUR leaf-private capabilities" = these three + Allocation).

A concrete leaf is a *point* in this product, not a sibling on a single enum:

| Leaf | Location | Allocation discipline | conforms `Memory.Allocator.Protocol`? |
|---|---|---|---|
| `Memory.Inline<n>` | in-struct | — (none) | **No** — *the tell* |
| `Memory.Heap` | out-of-line | single-buffer | Yes |
| `Memory.Arena` | out-of-line | bump | Yes |
| `Memory.Pool` | out-of-line | free-list | Yes |
| `Memory.Small<n>` | hybrid | single-buffer (spill arm) | Yes (on spill) |

So **`Arena`/`Pool` are `Memory.*` because Allocation-discipline is a Memory-owned sub-axis — *not* because
they are Location-peers of `Inline`.** This answers *"wouldn't they then also have an `Inline` variant?"*:
`Memory.Arena.Inline` is the **empty corner** of the partial product. The two sub-axes are
orthogonal-but-**correlated** — an allocation discipline *presupposes* an out-of-line region, while `Inline`
*is* the `(in-struct, no-discipline)` corner — so they do not freely cross. (A stack-/inline-bump scratch
buffer is a real general-systems pattern, but it would be a *Location* refinement of the allocator's own
backing, not a tower element-storage leaf crossing `Arena × Inline`.) The `Memory.Allocator.Protocol`
conformance **is** this axis boundary: Heap/Arena/Pool conform; `Inline` does not — `store-capability-
elimination.md`/`prism-wart` call this *"the tell"*.

The layering, then: the **inter-layer** basis `Memory ⊏ Storage ⊏ Buffer ⊏ ADT` (the HAS-A chain) refines at
each layer into an **intra-layer** product of orthogonal sub-axes — richest at Memory. This is
`[MOD-PLACE-DECOMPOSE]` (§7.1) applied *one level down*: "Memory = Location + Allocation" is itself a mild
bundle, decomposed into Location ⊥ Allocation-discipline ⊥ Growth ⊥ Liveness ⊥ Addressing. **The calculus is
fractal** — `min⊏` selects the *layer*; within the layer the same orthogonal-decomposition discipline selects
the *leaf* as a point in the sub-axis product. (A shallow sub-layering exists even here: an allocation
discipline *composes over* a raw out-of-line region, so Allocation HAS-A a Location for its own backing — but
because Arena/Pool/Heap all back out-of-line, that sub-layering is one rung deep and does not surface as a
tower layer.)

### 1.3 Orthogonal cross-cutting capabilities (composed *over* cores, never owned by one)

Three concerns are **not** layer axes at all — they are namespace-neutral capabilities that *multiple* cores
supply, composed via `where Self: Core & Capability` (CLCPM §3.1; the orthogonality note §"two orthogonal
axes; span is a third, cross-cutting capability"):

- **Span** (vending a contiguous view) — Memory, contiguous Storage, `Byte.Borrowed`, and `Binary.Borrowed`
  all conform; lifting `span` out of the `Storage.Contiguous` *namespace* into `swift-span-primitives` is the
  canonical *"don't bake a cross-cutting concern into a core"* move.
- **Iteration** — `Iterable` / `Sequenceable` / `Iterator.Borrow`, orthogonal to every core (a set's identity
  is membership, not iteration).
- **Algebra** — set algebra is a *third* concern bridged to the `swift-algebra-*` family, not a `Set.Protocol`
  requirement.

A **fifth, sibling** axis — the **typed-Index** layer (`Index<Element>.Bounded<N>`) — is orthogonal to the
tower entirely: it types *which slot*, independent of where the bytes live, how slots are arranged, or what
contract holds. (It is the home of the typed-bound sub-axis of the capacity case study, §5.3.)

> **The ontology in one line.** The tower is the unique **orthogonal basis** of the design-decision space of
> a stored data structure: `Memory ⊥ Storage ⊥ Buffer ⊥ ADT`, with `Span`, `Iteration`, `Algebra`, and the
> `Index` axis composed across it. *Placing a concern correctly = expressing it in this basis.*

---

## §2 — The calculus

### 2.1 Definitions

Let the tower layers form a total order under the HAS-A relation, lowest first:

```
    Memory ⊏ Storage ⊏ Buffer ⊏ ADT          (Index is a sibling axis, ⊏-incomparable)
```

For a layer `L` and an axis `A`, define the two primitive predicates that the ontology (§1) supplies:

- **`owns(L, A)`** — *L's abstraction barrier owns axis A*: every value of `A` is expressible in `L`'s own
  vocabulary **and** `A` is existentially bound at `L` (a client above `L` cannot observe which value of `A`
  is chosen — Reynolds/Mitchell–Plotkin). Read: *A is L's design-decision secret.*
- **`enforceable(L, inv(C))`** — *L can see and maintain concern C's invariant*: `inv(C)` is expressible
  using only notions available at `L`. (If `inv(C)` references a notion only a higher layer possesses — e.g.
  "the caller", which a leaf does not have — then `enforceable(L, inv(C))` is **false**.)

For a concern `C`, let **`axes(C)`** be the set of orthogonal axes it varies, and **`inv(C)`** its correctness
invariant. The placement judgment is written **`Γ ⊢ C @ L  ok`** ("`C` is correctly placed at `L`").

### 2.2 The decision procedure

Given any variant or capability `C`:

1. **Project onto the basis.** Compute `axes(C)` — which of `{Location, Allocation, Topology, Tracking,
   Occupancy, Contract}` (plus the cross-cutting capabilities and the `Index` axis) does `C` vary? This is
   the **semantic-identity** step (`[RES-029]` tier 1): read `C`'s *operational behavior*, not its name. (The
   name lies: `.Bounded` *names* one thing and *is* four — §5.3.)
2. **Decompose bundles first.** If `|axes(C)| > 1`, `C` is a **mis-bundle** of orthogonal concerns
   (van Wijngaarden's anti-orthogonality smell). Split `C ≡ C₁ ⊗ … ⊗ Cₙ` with each `axes(Cᵢ)` a singleton,
   and place each independently. *No monolithic placement of a bundle is ever correct.*
3. **Find the lowest owner.** For each single-axis `Cᵢ` with `axes(Cᵢ) = {A}`, the **canonical owner** is
   `L* = min⊏ { L : owns(L, A) }` — the lowest layer whose secret `A` is.
4. **Apply the floor.** If `¬enforceable(L*, inv(Cᵢ))` — placing `Cᵢ` at its axis-owner would crush an
   invariant that layer cannot see — **STOP and surface the hard floor**: the correct layer is
   `min⊏ { L : owns(L, A) ∧ enforceable(L, inv(Cᵢ)) }`, the lowest layer that owns the axis **and** can
   enforce the invariant. (When the axis-owner already enforces, the floor is the owner; the two coincide.)
5. **Express by decompose/compose, never by an ad-hoc protocol.** Realize the placement with **distinct leaf
   types** (compile-time type-selection), **composition/delegation** (`Storage.Contiguous<Memory.X>`), and
   **constrained extensions over canonical seams** (`where M: Memory.Allocator.Protocol`). **Do not** mint a
   capability protocol or a protocol-refinement to carry the concern (the standing principal directive;
   `Store.Creatable` / `Sequence.Clearable` / Path-D were rejected on exactly these grounds — §5.2,
   `mutator-orthogonal-vs-refinement-stance.md`).
6. **Tiebreak only among correct placements.** If two placements both satisfy steps 3–4 (rare), break the tie
   by the 0-`witness_method` specialization boundary (CLCPM §3.3) and dep-graph weight — **never** by these as
   selectors over a structurally-distinct option (`[RES-022]`/`[RES-029]`).

The decision is **correctness-driven, not adoption-driven** (`[ARCH-LAYER-008]`): consumer count never enters
steps 3–4.

### 2.3 Worked micro-example

`C = Memory.Heap`'s cleanup behavior. Step 1: `axes(C) = {Allocation/liveness}`. Step 3: the lowest owner of
allocation/liveness is **Memory** (§1). Step 4: `inv(C)` = *leak-freedom for ARC-backed `~Copyable` memory*;
is it `enforceable` below Memory? There is no layer below Memory. Is it enforceable *at* Memory but in the
generic composer above the leaf? **No** — the `bd04f32` wall (conditionally-Copyable generic structs cannot
carry `deinit`) means the teardown oracle can only live in the **leaf's class**. So the floor pins the oracle
to `Memory.Heap`'s backing class. Step 5: realized as a leaf-private record + the leaf's `deinit`, no store
protocol. This *is* case study 2 (§5.2), produced mechanically by the procedure.

---

## §3 — The two symmetric failure modes

The calculus is the unique placement that commits **neither** of two opposite errors. They are exact mirror
images: one leaks a *lower* secret *upward*, the other crushes a *higher* policy *downward*.

### 3.1 Too-high — a concern parked above its axis (the `.Small`-at-Storage mistake)

**Definition.** `place(C) = L` but `∃ L* ⊏ L` with `owns(L*, axis(C)) ∧ enforceable(L*, inv(C))`.

**Formal symptom (an information-hiding violation, Parnas 1972).** Because `axis(C)` is `L*`'s secret, a
correct `L` *cannot* express `C` without naming `L*`'s representation — so `L` is forced to **know a lower
layer's hidden decision**, the precise "connection" Parnas's information hiding forbids. By Reynolds, `axis(C)`
is no longer existentially bound at its owner, so representation independence is lost.

**Operational symptom (the wart triad).** A concern generic over a *broad* super-axis it does not belong to
forces:
- a **runtime override** where compile-time **type-selection** would suffice;
- a **universal stored requirement** where a **leaf-private record** would suffice;
- an **awkward non-conformance** where an **honest absence** would suffice.

(All three are the store-capability warts, §5.2.) **Cure:** push `C` down to `L*`; the triad inverts —
override → type-selection, universal requirement → leaf-private record, non-conformance → honest absence.

### 3.2 Too-low — a policy crushed into a leaf (the inverse mistake)

**Definition.** `place(C) = L` but `¬enforceable(L, inv(C))` — `L` cannot see the invariant `C` must enforce
— while some `L* ⊐ L` can.

**Formal symptom (a separation-of-concerns failure, Dijkstra 1974).** `L` is forced to enforce an invariant
defined in vocabulary it does not possess; it must either drop the invariant (it **silently breaks**) or
fabricate a leaf-local policy that cannot reference the thing the invariant is about. Two distinct aspects —
the mechanism and the policy — are conflated into one unit, the opposite of separation of concerns.

**Canonical instances (corpus-named).**
- A **`Memory.Bounded` leaf** that "caps" but **silently overflows**: overflow *signaling*
  (reject-return / throw / trap) is *how the caller is told*, and a memory leaf has no notion of "the caller"
  — `enforceable(Memory, overflow-signal) = false`. Prism names this exactly: *"Forcing a `Memory.Bounded`
  leaf would be the inverse of the `Storage.Small`-parked-too-high mistake"* (`prism-capacity/findings.md`).
- Pushing the **leak-freedom record below the allocation owner**: by RustBelt's `DeallocSize(ℓ, n, …)`, the
  right to free is an *owned* resource held *at* the allocation owner; no lower layer holds it, so teardown
  cannot be enforced there (§5.2, §6).
- Making **owners `~Escapable`**: that would "annotate a relationship the compiler can't enforce"
  (`nonescapable-support-memory-storage-buffer.md`) — the lifetime-safety axis has a hard floor at the
  borrowed-view layer and must not be pushed down into owners.

**Cure:** stop at the honest hard floor — the lowest layer that *can* hold the invariant — and **name it**.

### 3.3 The symmetry

| | Too-high | Too-low |
|---|---|---|
| Direction of error | secret leaks **up** | policy crushed **down** |
| Violated principle | information hiding (Parnas) | separation of concerns (Dijkstra) |
| Lost property | representation independence (Reynolds) | invariant enforceability |
| Detect by | `∃ L*⊏L. owns(L*,A) ∧ enforceable(L*,inv)` | `¬enforceable(L, inv)` |
| Examples | `.Small`/`.Inline` @ Storage; `Store.Creatable`/`Store.Tracked` @ store | `Memory.Bounded` silent overflow; leak-record below owner; `~Escapable` owners |

The calculus's output `L* = min⊏ {L : owns(L,A) ∧ enforceable(L,inv)}` is the **unique** layer that is neither
too high (it is the *minimum*, so nothing lower owns the axis-and-enforces) nor too low (the `enforceable`
clause is the floor). *Maximum decomposition, bounded by correctness.*

---

## §4 — Formal semantics ([RES-024])

A light formal system for the judgment `Γ ⊢ C @ L ok`. `Γ` is the ontology of §1 (the fixed predicates
`owns`, `enforceable`, the order `⊏`). This is a **soundness sketch**, not a mechanized proof (bounded rigor,
§6.5).

### 4.1 Syntax

```
    Layers      L  ::=  Memory | Storage | Buffer | ADT          (totally ordered by ⊏, Memory least)
    Axes        A  ::=  Location | Allocation | Topology | Tracking | Occupancy | Contract
    Concerns    C  ::=  base concern with axes(C) ⊆ A and invariant inv(C)
                     |  C₁ ⊗ C₂        (a bundle: axes(C₁ ⊗ C₂) = axes(C₁) ∪ axes(C₂))
    Placement   place : C → L
```

### 4.2 Placement typing rules

```
                       axes(C) = {A}        owns(L, A)        enforceable(L, inv(C))
                       ∀ L′ ⊏ L.  ¬owns(L′, A)  ∨  ¬enforceable(L′, inv(C))
  (P-Place) ─────────────────────────────────────────────────────────────────────────
                                       Γ ⊢ C @ L  ok


               axes(C) = {A₁,…,Aₙ},  n > 1        C ≡ C₁ ⊗ … ⊗ Cₙ,  axes(Cᵢ) = {Aᵢ}
                            Γ ⊢ Cᵢ @ Lᵢ  ok      (for all i)
  (P-Decompose) ────────────────────────────────────────────────────────────────────────
                            Γ ⊢ C  ok      (only by decomposition; no monolithic placement)


             owns(L, A)        ¬enforceable(L, inv(C))        L′ = min⊏{ L″ ⊐ L : enforceable(L″, inv(C)) }
  (P-Floor) ──────────────────────────────────────────────────────────────────────────────────────────────
                                       Γ ⊢ C @ L′  ok      (the honest hard floor)
```

`(P-Place)` is the common case: `L` is the **lowest** layer that both owns the axis and can enforce the
invariant. `(P-Decompose)` forbids placing a multi-axis bundle as a unit. `(P-Floor)` is the explicit
escape used when the axis-owner cannot enforce the invariant — it lifts the concern to the lowest *enforcing*
super-layer and **requires** that the lift be surfaced (the side condition makes the floor a *named* layer,
not a silent compromise).

The two failure modes are the rule's negations:

```
  (Too-High)  place(C)=L,  axes(C)={A},  ∃L*⊏L.  owns(L*,A) ∧ enforceable(L*,inv(C))     ⟹  ¬(Γ ⊢ C @ L ok)
  (Too-Low)   place(C)=L,  ¬enforceable(L, inv(C))                                        ⟹  ¬(Γ ⊢ C @ L ok)
```

### 4.3 Soundness sketch — "concern C at layer L is correct" ⟺ `Γ ⊢ C @ L ok`

We argue two properties; together they justify reading the judgment as correctness.

**Lemma 1 (No-Leak / representation independence).** *If `Γ ⊢ C @ L ok` via `(P-Place)`, then no layer
`L′ ⊐ L` must name `L`'s representation of `axis(C)`.*
*Sketch.* `owns(L, A)` means `A` is existentially bound at `L` (`∃X.T`, Mitchell–Plotkin). By Reynolds'
abstraction theorem, any well-typed term at a layer `L′ ⊐ L` is parametric in `X` — it cannot inspect which
value of `A` was chosen. Hence `L′` depends only on `L`'s *interface*, never its *secret*. The `(Too-High)`
configuration is exactly the failure of this: there `C` sits at `L` while its axis is owned at `L* ⊏ L`, so
expressing `C` at `L` forces `L` to name `L*`'s representation — contradicting `owns(L*, A)`. `(P-Place)`'s
minimality side-condition (`∀L′⊏L. ¬owns(L′,A) ∨ ¬enforceable(L′,inv)`) rules this out by construction. ∎

**Lemma 2 (No-Crush / invariant safety).** *If `Γ ⊢ C @ L ok`, then `inv(C)` is maintainable at `L`.*
*Sketch.* Both `(P-Place)` and `(P-Floor)` carry `enforceable(L, inv(C))` as a premise (for `(P-Floor)`, at
the chosen `L′`). `enforceable` means `inv(C)` is expressible in `L`'s vocabulary, so `L` can state and check
it. The `(Too-Low)` configuration is the negation `¬enforceable(L, inv(C))`, which no derivation admits. ∎

**Theorem (Correct placement).** *`Γ ⊢ C @ L ok` holds iff `L` is the unique lowest layer that both owns
`C`'s axis and enforces `C`'s invariant; equivalently, `L` commits neither failure mode.*
*Sketch.* Decompose `C` to single-axis components by `(P-Decompose)` (a bundle has no monolithic correct
placement — placing it anywhere violates `(P-Place)`'s singleton premise, matching the empirical fact that
`.Bounded` cannot live at one layer, §5.3). For a single-axis `C`, the set `S = { L : owns(L, axis(C)) ∧
enforceable(L, inv(C)) }` is upward-closed in `⊏` on the `owns` factor below the floor and bounded below by
the floor; `(P-Place)`/`(P-Floor)` together select `min⊏ S`. By Lemma 1 this `L` admits no `(Too-High)`
witness (it is the minimum of `S`), and by Lemma 2 no `(Too-Low)` witness (`enforceable` holds). Conversely a
layer committing neither failure mode satisfies both premises and the minimality condition, so it is
`min⊏ S`. Hence the judgment characterizes exactly the correct placement. ∎

**Two corollaries that match the corpus exactly:**

- **(C1) Maximum decomposition is the *minimum* of `S`.** "Push as low as correct" is literally `min⊏`. The
  `Memory ⊏ Storage ⊏ Buffer ⊏ ADT` order makes "lowest" well-defined; the leaves of the tower are the
  bottom, which is why so many mis-placed concerns resolve *downward* to Memory leaves (the dominant
  empirical direction, §5).
- **(C2) The floor is `enforceable`, not `owns`.** A concern may be *owned* by no layer at or below its
  natural axis yet still need an enforcer — overflow-signaling is owned by *no* core (it is an API contract)
  and floors at the **discipline** (Buffer) layer, the lowest with a notion of "the caller". This is why the
  honest floor is a separate rule, not just "stop at the axis owner".

---

## §5 — Case-study validation (the calculus reproduces every prior correction)

Each case is **folded in, not re-derived**: the calculus is run forward and shown to land on the same
placement the corpus reached empirically, citing the source note. None contradicts the calculus.

### 5.1 `.Small` / `.Inline` → **Memory** (a *too-high* correction)

- **Project (step 1).** `axes(.Inline) = {Location}` (in-struct vs out-of-line); `.Small` = `{Location}` with
  an inline→heap *hybrid* representation (still one axis — *where the bytes live*, with a spill threshold).
- **Lowest owner (step 3).** Location is **Memory**'s secret (§1.1): `min⊏ = Memory`.
- **Floor (step 4).** `inv` = correct teardown of the live extent. Owned at Memory, but — by the `bd04f32`
  wall — `enforceable` only in the **leaf's class**, not in the generic composer above it. So the oracle pins
  to the leaf; the *axis* still floors at Memory. (Both directions bounded: location can't rise to Storage,
  teardown can't rise into the generic.)
- **Express (step 5).** Distinct leaves `Memory.Inline<n>` / `Memory.Heap` / `Memory.Small<n>`; Storage
  *composes* them as `Storage.Contiguous<Memory.X>`. No `Storage.Inline`/`.Heap`/`.Small` type.
- **Verdict.** The earlier `Storage.{Inline,Small}` placement was **too-high** — Storage was forced to name
  the location secret. **Validated by** `storage-memory-split.md` (DECISION: `Storage<E>.Heap →
  Storage.Contiguous<Memory.Heap<E>>`) and `prism-endstate/end-state-research-note.md` (*"DELETED:
  Storage.Inline / Storage.Heap / Storage.Small → always Storage.Contiguous<Memory.X>"*; `.Small` resolved to
  `Memory.Small<Element, let n>`). The `storage-small-substrate.md` `Storage<E>.Small` spelling is the
  *intermediate*; the end-state is the Memory leaf. `[Verified: 2026-06-05]`

### 5.2 `Store.Creatable` / `Store.Tracked` → **memory-leaf property** (a *too-high* correction)

- **Project.** `Store.Creatable` = `{Allocation}` (+ relocation); `Store.Tracked` = `{Allocation/liveness}`
  (the init-ledger). Both were *store-tier protocols generic over **all** stores* — the breadth is the tell.
- **Lowest owner.** Allocation and liveness are **Memory**'s secret. `min⊏ = Memory`.
- **Floor.** `inv` = leak-freedom for ARC-backed `~Copyable` memory. By RustBelt's `DeallocSize(ℓ,n,…)`, the
  dealloc-right is owned *at* the allocation owner; `enforceable` at the **leaf** (`Memory.Heap`-private),
  nowhere lower. The ledger *concept* is **irreducible** — but private, not a universal protocol.
- **Express (the wart triad inverts).** allocation override → `where M: Memory.Allocator.Protocol`
  type-selection (`Memory.Inline` honestly *lacks* it); relocation override → `where M: ContiguousMem`
  static bulk-selection; universal `Store.Tracked` requirement → a `Memory.Heap`-private liveCount read by
  its `deinit`.
- **Verdict.** The store-tier placement was **too-high** — *"the warts were the store-tier placement + the
  fusion"*. **Validated by** `store-capability-elimination.md` and `prism-wart/findings.md` receipts
  (`allocation-relocation-typeselected.txt`: 0-`witness_method`; `ledger-private-oracle-and-leak-floor.txt`:
  leaf-private → `Tracked.live = 0`; no record → `Tracked.live = 5` **leaks** — the floor demonstrated).
  This is the calculus's §3.1 wart-triad cure verbatim. `[Verified: 2026-06-05]`

### 5.3 `.Bounded` / `.Fixed` / `.Static` → **a 4-axis bundle** (decomposition + the floor)

The names are *"misleading bundles of 4 orthogonal axes; there is no single 'capacity variant' concern"*
(`prism-capacity/findings.md`). Step 2 (decompose) is the whole story:

| Sub-axis (step 1–2) | `axes` | Lowest owner (step 3) | Floor (step 4) | Placement (step 5) |
|---|---|---|---|---|
| Capacity **value** (the size) | `{Location}` | **Memory** | owner enforces | `Memory.Inline<n>` (compile-time) / `Memory.Heap` `create(minimumCapacity:)` (runtime) |
| **Growth-ability** + relocation | `{Allocation}` | **Memory** | owner enforces (leaf-internal grow) | a `Growable` leaf capability; "bounded/fixed" = the leaf *not* being `Growable` (the firm-foundation ADDENDUM moved this *down* from discipline once addressing joined the leaf) |
| **Overflow signaling** (reject/throw/trap) | `{}` — an API contract, no core axis | none (no core owns it) | **Buffer discipline** — the lowest layer with a notion of "the caller" | the **honest hard floor** — a thin discipline surface; **`(P-Floor)`** fires here |
| Typed **bounded index** | `{Index}` (sibling axis) | **Index layer** | owner enforces | `Index<Element>.Bounded<N>` (the only reason `Array.Bounded<N>` carried `<N>`) |

- **The *too-low* inverse, explicit.** A `Memory.Bounded` leaf would put overflow-signaling at Memory, where
  `enforceable` is **false** (no "caller") → it would silently overflow. Prism names this as *"the inverse of
  the `Storage.Small`-parked-too-high mistake"* — the §3.2 failure mode, predicted by the calculus.
- **Verdict.** `.Bounded/.Fixed/.Static` is not one concern at one layer; it is four concerns at four homes
  (Memory, Memory, Buffer-floor, Index), and the per-container variant *types* dissolve. The `.Fixed`-as-a-
  separate-leaf-type-on-7-ADTs pattern (variant inventory, §5.4) is a *too-low* contract-policy crush — the
  immutable-count *contract* belongs as an ADT-surface constraint over the shared bounded substrate, not a
  minted storage-named leaf. **Validated by** `prism-capacity/findings.md` (+ ADDENDUM) and the consolidated
  `prism-endstate` placement table. `[Verified: 2026-06-05]`

### 5.4 Inventory cross-check (the whole variant catalog, classified)

Running step 1 over the full variant inventory (`data-structures-variant-catalog-*.md`,
`variant-naming-audit.md`) confirms the basis and surfaces the residual mis-placements the calculus flags:

| Family | Axis | Canonical layer | Status today |
|---|---|---|---|
| `Inline` / `Heap` / `Small` | Location | **Memory** | mis-placed at Storage/Buffer → end-state moves to Memory leaves (§5.1) |
| `Arena` / `Pool` | Allocation strategy | **Memory** | **mis-placed** — `Storage.Arena`/`Buffer.Arena`/`Storage.Pool` duplicate an allocation strategy across 3 layers → dissolve to `Storage.Contiguous<Memory.Arena\|Pool>` |
| `Contiguous` / `Split` | Topology | **Storage** | correct (`Storage.Split` is the cleanest axis→layer datum) |
| `Linear` / `Ring` / `Slab` / `Slots` / `Linked` | Occupancy discipline | **Buffer** | correct at Buffer; `Storage.Slab` is a stray discipline-at-Storage |
| `Bounded` / `Fixed` / `Static` | Capacity bundle | **Memory + Buffer-floor + Index** | mis-bundled (§5.3); `.Fixed`-as-leaf on 7 ADTs is a contract crush |
| `Indexed<Tag>` / `Index.Bounded<N>` | Typed-index | **Index layer** | under-propagated; co-located with containers |
| `Ordered` / `MinMax` / `Keyed` / `DoubleEnded` / `N` | Contract | **ADT** | correct |

The dominant empirical signal: the **cleanest** axis→layer binding is *topology → Storage*; the **muddiest**
is *allocation-strategy*, which today has **no single owner** (Arena/Pool spread across Memory/Storage/Buffer)
— precisely the recurring *too-high* duplication the calculus eliminates by pinning allocation to Memory.

> **Refinement note (`[META-003]`).** The `variant-naming-audit.md` convention "the `Inline` placement token
> legitimately lives at Memory **and** Storage **and** Buffer" is refined here: under the calculus, *Location*
> is Memory's secret, so the token lives at **Memory only**, with Storage/Buffer *composing* the leaf. This is
> not a new disagreement — it consumes the supersession already made by `prism-endstate` (which deletes
> `Storage.{Inline,Heap,Small}`). The audit's *collection-layer* `.Static` spelling (a user-facing
> compile-time-capacity property) remains valid as an ADT-surface name over a `Memory.Inline<n>` substrate.

---

## §6 — Prior-art systematic literature review ([RES-023] Kitchenham; [RES-021] contextualization)

### 6.1 Research questions, search strategy, inclusion/exclusion

- **RQ1.** Does the PL/type-theory literature justify "a concern belongs at the lowest layer whose abstraction
  barrier owns it"? **RQ2.** Does the memory/region literature make allocation/liveness intrinsic to the
  lowest layer, with a floor below which a liveness record cannot go? **RQ3.** Do modularity classics ground
  the two symmetric failure modes? **RQ4.** Is the discipline-over-allocation / inline-vs-heap-as-parameter
  shape industry-standard cross-language, and how does the institute diverge?
- **Search strategy.** Four clusters, each dispatched to an independent verification subagent against
  **primary sources** (paper text, language std docs, RFCs, WG21 papers) per `[RES-020]`; 2026-06-05.
  Inclusion: primary or author-authoritative sources. Exclusion: tutorials/blogs except as transcription
  cross-checks of an otherwise-confirmed primary. Each load-bearing claim carries a `[Verified: 2026-06-05]`
  or `[UNVERIFIED]` tag (§6.5).

### 6.2 Data abstraction & representation independence (RQ1)

- **Reynolds (1983), "Types, Abstraction and Parametric Polymorphism"** (IFIP Information Processing 83,
  pp. 513–523). The abstraction theorem / relational parametricity: a well-typed client cannot observe which
  representation lies behind a type abstraction. *[Verified: 2026-06-05 — bibliographic + content via
  authoritative summaries; primary PDF is scan-only, so **paraphrased, not quoted**.]*
- **Mitchell & Plotkin (1988), "Abstract Types Have Existential Type"** (ACM TOPLAS 10(3):470–502,
  doi:10.1145/44501.45065). An ADT *is* an existential type `∃X.T`; the representation `X` is packed/hidden;
  clients use it only through the interface. *[Verified: 2026-06-05 — bibliographic confirmed; thesis via
  authoritative summaries; **paraphrased, not quoted** (ACM 403, PDF scan-only).]*
- **Wadler (1989), "Theorems for Free!"** (FPCA '89, pp. 347–359). Free theorems follow "courtesy of
  Reynolds' abstraction theorem" — a consequence of representation independence. *[Verified: 2026-06-05 —
  abstract quoted verbatim.]*
- **Liskov & Zilles (1974), "Programming with Abstract Data Types"** (SIGPLAN Notices 9(4):50–59). The ADT is
  "completely characterized by the operations available on those objects"; "the language completely hides all
  implementation details." *[Verified: 2026-06-05.]*

→ **Grounds §1/§2/Lemma 1:** a layer's barrier *owns* a decision iff that decision is its existentially-bound
representation variable; parking a concern *above* its barrier forces a higher layer to name a lower layer's
hidden representation — a leak of the secret.

### 6.3 Region/memory management & separation logic (RQ2)

- **Reynolds (2002), "Separation Logic"** (LICS 2002, pp. 55–74). `Heap = (A ⇀_fin Values⁺)`, with Integers,
  Atoms, Addresses **disjoint** — Locations and Values are separate sorts. *[Verified: 2026-06-05 — model
  definition quoted verbatim.]* Grounds the `σ : Location ⇀ Value` ontology of §1.1.
- **Tofte & Talpin (1997), "Region-Based Memory Management"** (Information and Computation 132(2):109–176).
  "All values are put into regions. The store consists of a stack of regions. All points of region
  allocation and deallocation are inferred automatically." Allocation/deallocation are a *static* discipline
  of where values live and when they die. *[Verified: 2026-06-05 — quoted verbatim.]*
- **Jung, Jourdan, Krebbers & Dreyer (2018), "RustBelt"** (PACMPL 2(POPL), Art. 66, doi:10.1145/3158154). The
  ownership predicate for an owned pointer carries `DeallocSize(ℓ, n, ⟦τ⟧.size)`, which "manages the right to
  deallocate the location ℓ"; uninitialized memory is tracked (a `poison`/`MaybeUninit` value). *[Verified:
  2026-06-05 — quoted verbatim.]*
- **Blazy & Leroy (2008), "Formal Verification of a Memory Model for C-Like Imperative Languages"** (J.
  Automated Reasoning 41(1):1–31, doi:10.1007/s10817-008-9099-0). A pointer value is "a pair of a block
  identifier … and an offset"; `Vundef` marks uninitialized cells. *[Verified: 2026-06-05 — quoted verbatim.]*

→ **Grounds §1 (Memory owns location/allocation/liveness) and the floor of Lemma 2 / §3.2:** because the
dealloc-right is an *owned, non-duplicable* resource held *at* the allocation owner (RustBelt `DeallocSize`),
no layer **below** the owner legitimately knows the extent or holds the right to free — so a leak-freedom
liveness record **cannot be pushed below the allocation owner**. (This *universal* "no-record-below-owner"
phrasing is a **synthesis across these sources, grounded by `DeallocSize`, not a single verbatim theorem** —
§6.5.)

### 6.4 Separation of concerns, information hiding, orthogonality, the expression problem (RQ3)

- **Parnas (1972), "On the Criteria To Be Used in Decomposing Systems into Modules"** (CACM 15(12):1053–1058).
  "It is almost always incorrect to begin the decomposition … on the basis of a flowchart"; instead "each
  module … hide[s] such a [design] decision from the others." *[Verified: 2026-06-05 — quoted verbatim.]*
- **Dijkstra (1974), "On the role of scientific thought"** (EWD447). "…what I sometimes have called 'the
  separation of concerns' …" — **his coinage**, confirmed. *[Verified: 2026-06-05 — quoted verbatim from the
  EWD Archive.]*
- **Wadler (1998), "The Expression Problem"** (Java-Genericity note). Adding both new data variants and new
  operations "without recompiling existing code, and while retaining static type safety." *[Verified:
  2026-06-05 — quoted verbatim.]*
- **van Wijngaarden (1965), "Orthogonal design and description of a formal language"** (Mathematisch Centrum
  MR 76/65). The origin of "orthogonality" as a PL-design principle (independent features combinable freely).
  *[Verified: 2026-06-05 — report metadata/attribution confirmed; the definitional gloss rests on secondary
  historical summaries, **not a quote from the 1965 report body**.]*

→ **Grounds §3:** a layer *is* a Parnas module (one secret), so "which layer owns `C`" ≡ "`C` is which
design-decision-secret"; **too-high** is the information-hiding violation (a higher layer forced to know a
lower secret); **too-low** is the Dijkstra SoC failure (mechanism and policy conflated); and a name that
**bundles** orthogonal axes (`.Bounded` = 4 axes) is the anti-orthogonality smell (van Wijngaarden) and a
downstream expression-problem trap (you cannot extend one axis without touching the others).

### 6.5 Cross-language analogues & the institute's divergence (RQ4)

- **Rust `Vec<T>` over `RawVec<T>`** (rust-lang/rust `alloc/src/raw_vec`): `RawVec` owns `ptr`+`cap`
  (allocate/grow/dealloc); `Vec` adds `len` — the discipline/allocation split, in the standard library.
  *[Verified: 2026-06-05.]*
- **`smallvec::SmallVec` (inline ⊕ spill-to-heap) vs `arrayvec::ArrayVec` (fixed inline, never spills)** —
  inline-vs-heap is a *storage-location property*, parameterized by an inline-capacity constant. *[Verified:
  2026-06-05.]* (Direct precedent for `Memory.Small` vs `Memory.Inline`.)
- **Allocation strategy as a composed parameter**: C++ `std::vector<T, Allocator>` + `std::pmr`
  (`memory_resource` / `polymorphic_allocator`); Rust's `Allocator` trait (allocator_api). *[Verified:
  2026-06-05 — caveat: Rust's `Allocator` is **nightly/unstable**, not "stable Rust".]*
- **Provisioning vs typed-construction wrongly fused**: WG21 **P0619R3** — `std::allocator::construct`/
  `destroy` deprecated C++17, removed C++20, routed through `allocator_traits` instead. *[Verified:
  2026-06-05 — the deprecation/rationale; the specific **Alexandrescu** attribution is **[UNVERIFIED]** and is
  softened to "widely critiqued".]* (Mirrors the store/memory un-fusion.)
- **Bonwick (1994), "The Slab Allocator"** (USENIX Summer 1994, pp. 87–98) — object caches separate slab
  provisioning from cached typed construction. *[Verified: 2026-06-05.]*
- **Stepanov & McJones (2009), "Elements of Programming"** — minimal affiliated operations derived from the
  *consuming* algorithms (the minimal seam; grounds the FROZEN 4-op `Store.Protocol`). *[Verified:
  2026-06-05.]*
- **Strom & Yemini (1986), "Typestate"** (IEEE TSE SE-12(1):157–171) — compile-time tracking of a variable's
  initialization state; the initialization-ledger lineage. *[Verified: 2026-06-05.]*
- **Haskell `vector` (Boxed/Unboxed/Storable/Primitive)** — one logical container, representation chosen at
  the type level. *[Verified: 2026-06-05.]* (OCaml `Bigarray` is a further witness — *[UNVERIFIED this
  pass]*.)

→ **Contextualization ([RES-021]).** The discipline-over-allocation split and inline-vs-heap-as-a-parameter
are **universal** — so their presence in the tower is no innovation. The institute **diverges deliberately**
on two axes, and the divergence is exactly what the calculus formalizes: (a) it selects storage via **distinct
leaf *types* resolved at compile time** (type-selection → 0-`witness_method`) rather than runtime allocator
objects (vtable-dispatched `memory_resource` / `dyn Allocator`); and (b) it makes liveness **leaf-private and
statically enforced** rather than an analysis pass (typestate) or a cooperative convention (Bonwick). Universal
adoption does **not** imply the institute must copy the *runtime-allocator* shape — the typed twist is a
deliberate, stronger design (the contextualization step prevents mistaking "everyone parameterizes the
allocator at runtime" for "you should too").

### 6.6 Bounded rigor (the honest record, per ground rule 3)

This is a **soundness *sketch***, not a mechanized proof: `owns`/`enforceable` are taken as ontology-given
predicates (§1), not derived inside a proof assistant; the metatheory (Lemmas 1–2, the Theorem) is argued in
prose grounded by the cited results, not checked in Coq. Citation caveats carried forward: Reynolds (1983) and
Mitchell & Plotkin (1988) are **paraphrased, not quoted** (scan-only primaries); the "no-liveness-record-below
-the-owner" slogan is a **synthesis grounded by RustBelt's `DeallocSize`**, not a single verbatim theorem; the
van Wijngaarden orthogonality gloss rests on **secondary** summaries; Rust's `Allocator` trait is **unstable**;
the C++ allocator critique's **Alexandrescu** attribution is **unverified** (the deprecation fact is verified).
These bounds do not affect the calculus's load-bearing claims, each of which has at least one verbatim primary.

---

## §7 — `[MOD-*]` refactor basis (the deliverable for the later skill-lifecycle step)

This section enumerates the concrete modularization-skill changes the calculus implies. **It is the basis,
not the edit** — the actual skill amendment is a separate `/skill-lifecycle` step (per the dispatch and ground
rule 4). Each item is written so the skill author can lift it into a `[MOD-*]` requirement.

### 7.1 New rules to author

- **`[MOD-PLACE]` (axiom) — Lowest-Correct-Layer Placement.** *A concern (variant axis, capability, stored
  requirement) MUST be placed at the lowest tower layer that **owns its axis** AND can **enforce its
  invariant** (§2.2 procedure; §4 rules). Placement is decided by semantic identity (which design-decision-
  secret the concern is — `[RES-029]` tier 1), with the 0-`witness_method` boundary and dep-graph weight as
  tiebreakers only.* Companion to `[MOD-DOMAIN]` ("factor the law, not the module") — `[MOD-PLACE]` is
  `[MOD-DOMAIN]` applied **across layers**: factor each law to the layer that owns it.
- **`[MOD-PLACE-DECOMPOSE]` — Bundle Decomposition Before Placement.** *A variant or capability whose name
  spans ≥ 2 orthogonal axes MUST be decomposed into single-axis concerns and each placed independently; no
  monolithic placement of a multi-axis bundle is permitted* (the `.Bounded` = {capacity, growth,
  overflow-signal, typed-index} lesson; §4 `(P-Decompose)`).
- **`[MOD-PLACE-FLOOR]` — The Honest Hard Floor.** *Maximum decomposition is bounded by correctness: a
  concern MUST NOT be pushed below the lowest layer that can enforce its invariant. When the axis-owner cannot
  enforce the invariant, lift to the lowest enforcing super-layer and **name the floor explicitly*** (§4
  `(P-Floor)`; the overflow-signaling, leak-freedom, and `~Escapable`-owner floors).
- **`[MOD-PLACE-AUDIT]` — The Two-Failure-Mode Lens.** *When auditing a variant's placement, check both: (i)
  **too-high** — does a strictly lower layer own this axis and enforce this invariant? (ii) **too-low** — can
  this layer actually see the invariant it must enforce? A "no" to (i)'s lower-owner means push down; a "no"
  to (ii) means the floor was crossed.* (§3; mechanizes the post-hoc `.Small`-class discovery into a pre-hoc
  check.)
- **`[MOD-PLACE-EXPRESS]` — Express Placement by Decompose/Compose, Not by Protocol.** *A placement MUST be
  realized by distinct leaf types (compile-time type-selection), composition/delegation, and constrained
  extensions over canonical seams — NOT by minting an ad-hoc capability protocol or a protocol refinement to
  carry the concern.* (Ground-rule-4 directive; `mutator-orthogonal-vs-refinement-stance.md`: sets-overlap →
  sibling + dual-conformance, never refinement; CLCPM compose-don't-refine.)

### 7.2 Existing rules to amend (the `.Small`-class mistakes the calculus would have caught)

- **`[MOD-009]` (Inline Variant Satellite: Core → Heap → Inline → Small) — RESHAPE.** This rule encodes the
  **old** location-at-Storage/Buffer satellite chain. Under `[MOD-PLACE]`, *Location* is **Memory**'s axis:
  the `Heap`/`Inline`/`Small` satellites are **Memory leaves**, and the higher layers **compose** them
  (`Storage.Contiguous<Memory.X>`), not subclass them. `[MOD-009]` should be re-expressed as
  composition-over-Memory-leaves, or scoped to the genuine intra-Memory satellite (`Memory.Small` spilling to
  `Memory.Heap`). *This is the canonical example of a `[MOD-*]` rule that bakes a too-high placement.*
- **`[MOD-012]` (Target Naming) — note the placement token.** The `{Variant}` token for a *location/allocation*
  concern (`Inline`/`Heap`/`Small`/`Arena`/`Pool`) belongs on a **Memory** target; a `Storage.Arena`/
  `Buffer.Arena` target name is a placement smell (§5.4). Add a cross-reference to `[MOD-PLACE]`.
- **`[MOD-035]` (Scope Statement) — derive the boundary from the calculus.** A package's "Out of scope" list
  is exactly the set of axes the calculus assigns to *other* layers. `swift-memory-primitives`' scope ("memory
  is addressing + alignment + allocation, NOT occupancy/topology/contract") is `[MOD-PLACE]` read as a
  per-package boundary. Recommend scope statements cite the owned axis explicitly.

### 7.3 Relationship to the package-promotion rubric (do NOT conflate; do NOT override)

`sub-product-split-decision-rubric.md` (Gate 0 `[MOD-DOMAIN]` → Gate 1 upstream-pruning → Gate 2 `[MOD-003]`
→ Gate 3 `[MOD-RENT]`) answers a **different** question: *should this sibling become its own `Package.swift`?*
`[MOD-PLACE]` answers *which tower layer does this concern live at?* They are **orthogonal**:

- A concern can be correctly **placed** at Memory (concern-placement: yes) while its sibling **stays a target**
  rather than a package (Gate 1: no upstream-pruning) — e.g. `Memory.Pool` *composes into* `Storage.Pool`
  (placement) yet is a **Gate-1 FAIL** as a package-split candidate. **Composition ≠ package-split.** The
  rubric's Gate-1 brake is **not** weakened by `[MOD-PLACE]`.
- The integration is one-directional: `[MOD-PLACE]` decides *where the concern goes*; *then* the rubric
  decides *whether that home is a new package or a sibling target*. Recommend adding `[MOD-PLACE]` as a
  **Priority -1 / Gate -1 framing step** ("first place the concern by axis; *then* run Gate 0→3 on the
  resulting home"), explicitly noted as non-overriding of Gate 1.

### 7.4 Companion skill-promotion candidate (cross-reference, not owned here)

The orthogonality note already flags a `[ARCH-LAYER-*]`/`[SEM-DEP-*]` companion: *"location ⊥ representation;
quantity-typed-by-its-domain; capabilities namespace-neutral."* `[MOD-PLACE]` is the **placement** half of
that two-axis model; the representation-axis half (Bit→Byte→Binary) and the capability-neutrality half (Span)
are its siblings. Recommend authoring them together so the tower's *placement* rule and the representation
axis's *typing* rule land as one coherent `[ARCH-LAYER-*]` family.

---

## Outcome

**Status: RECOMMENDATION.** The decomposition layer-placement calculus is: **project a concern onto the
orthogonal axis basis `Memory ⊥ Storage ⊥ Buffer ⊥ ADT` (plus the cross-cutting Span/Iteration/Algebra
capabilities and the sibling Index axis); decompose any name that bundles ≥ 2 axes; place each single-axis
concern at the lowest layer that owns its axis AND can enforce its invariant (`min⊏ { L : owns(L,A) ∧
enforceable(L,inv) }`); express the placement by distinct leaf types + composition + constrained extensions,
never an ad-hoc protocol; and stop at the honest hard floor.** The two failure modes are exact mirror images —
*too-high* leaks a lower secret upward (a Parnas information-hiding violation; loses Reynolds representation
independence), *too-low* crushes a higher policy downward (a Dijkstra separation-of-concerns failure; breaks an
invariant) — and the calculus's output is the unique placement committing neither. The framework **reproduces
every prior ad-hoc correction** (`.Small`/`.Inline` → Memory; `Store.Creatable`/`Store.Tracked` → memory-leaf;
`.Bounded`/`.Fixed`/`.Static` → a 4-axis bundle with an overflow-signaling Buffer-floor) and **predicts the
inverse mistakes** the corpus had to discover empirically (the silently-overflowing `Memory.Bounded` leaf).

**What it feeds (both deferred, gated on this note landing):** a `/modularization` skill refactor (the §7
`[MOD-PLACE*]` basis), then a `/blog-process`. **Not in scope and not done here:** production edits, the skill
edit itself, the blog, re-running Prism's capacity empirics.

**Held for seat verification.** The swift-institute Research repo is **PUBLIC**; this note is **not pushed**
(the push is a separate seat-staged window). No production source was touched; no competing capacity probes
were run.

---

## References

### Internal (governs / validated against) — per [RES-019]

- **Companion (the calculus applied):** `swift-institute/Research/decomposition-layer-placement-package-map.md`
  (Tier 3) — the FINAL exhaustive per-package map + strata dependency DAG + Cleave-#7 delta-list that applies
  this calculus to the live `swift-primitives` tree (every package classified; §5.4's inventory made exhaustive).
- `swift-institute/Research/cross-layer-capability-protocol-model.md` (CLCPM, v1.5.0, Tier 3) — the capability
  normal form (HAS-A cores + orthogonal concerns; R/C/D edge kinds; the 0-`witness_method` boundary).
- `swift-institute/Research/memory-byte-bit-domain-orthogonality.md` (v1.0.0, Tier 3) — location ⊥
  representation; span as a lifted cross-cutting capability; its prior art `[Verified: 2026-06-03]`.
- `swift-institute/Research/storage-memory-split.md` (v1.1.2, Tier 3, DECISION) — case study 1; the
  `Store.Protocol ⊂ Store.Tracked.Protocol ⊂ Storage.Protocol` stack; the `bd04f32` hard floor; §1b lineage.
- `swift-institute/Research/store-capability-elimination.md` (v1.0.0, Tier 2) — case study 2 (the wart
  principle).
- `swift-institute/Research/sub-product-split-decision-rubric.md` (v1.0.0) — the package-promotion rubric this
  note extends, does not override (§7.3).
- `swift-institute/Research/buffer-storage-associatedtype-prior-art.md` (v1.0.0, Tier 2) — compose-don't-
  refine; the floor's "wall as signal-not-defect" wording.
- `swift-institute/Research/nonescapable-support-memory-storage-buffer.md` (v2.1.0, Tier 2, DECISION) — the
  5-category ownership taxonomy; the `~Escapable`-owner floor.
- `swift-institute/Research/memory-storage-composition-feasibility.md` (v1.0.0, Tier 2) — SE-0107 raw/typed
  (raw = Memory, typed = Storage); composition over re-implementation.
- `swift-institute/Research/mutator-orthogonal-vs-refinement-stance.md` (v1.0.0, REFERENCE) — sets-overlap →
  sibling + dual-conformance, not refinement (the express-by-compose directive).
- `swift-institute/Research/data-structures-variant-catalog-{data-structures,infrastructure,parsers,systems}.md`
  + `variant-naming-audit.md` — the variant inventory (§5.4).
- `~/Developer/.probe-bank/prism-capacity/findings.md` (+ ADDENDUM, 2026-06-05) — case study 3 (the capacity
  axes; the named *too-low* inverse).
- `~/Developer/.probe-bank/prism-wart/findings.md` — case study 2 receipts (leaf-private ledger; leak floor).
- `~/Developer/.probe-bank/prism-endstate/end-state-research-note.md` (v1.0.0, Tier 2) — the consolidated
  end-state inventory + the governing lens + the two honest floors (proposed home:
  `swift-institute/Research/msb-tower-end-state.md`, pending filing).

### External primary sources (parallel-subagent-verified 2026-06-05, [RES-020]/[RES-026]; caveats in §6.5/§6.6)

- John C. Reynolds (1983). *Types, Abstraction and Parametric Polymorphism.* IFIP Information Processing 83,
  pp. 513–523. *(paraphrased)*
- John C. Mitchell & Gordon D. Plotkin (1988). *Abstract Types Have Existential Type.* ACM TOPLAS 10(3):470–502.
  [doi:10.1145/44501.45065](https://doi.org/10.1145/44501.45065) *(paraphrased)*
- Philip Wadler (1989). *Theorems for Free!* FPCA '89, pp. 347–359.
  [Edinburgh](https://www.research.ed.ac.uk/en/publications/theorems-for-free/)
- Barbara Liskov & Stephen Zilles (1974). *Programming with Abstract Data Types.* SIGPLAN Notices 9(4):50–59.
  [doi:10.1145/800233.807045](https://doi.org/10.1145/800233.807045)
- John C. Reynolds (2002). *Separation Logic: A Logic for Shared Mutable Data Structures.* LICS 2002, pp. 55–74.
  [CMU](https://www.cs.cmu.edu/~jcr/seplogic.pdf)
- Mads Tofte & Jean-Pierre Talpin (1997). *Region-Based Memory Management.* Information and Computation
  132(2):109–176. [PDF](http://ropas.snu.ac.kr/lib/dock/ToTa1997.pdf)
- Ralf Jung, Jacques-Henri Jourdan, Robbert Krebbers & Derek Dreyer (2018). *RustBelt: Securing the Foundations
  of the Rust Programming Language.* PACMPL 2(POPL), Art. 66.
  [doi:10.1145/3158154](https://doi.org/10.1145/3158154)
- Sandrine Blazy & Xavier Leroy (2008). *Formal Verification of a Memory Model for C-Like Imperative Languages.*
  J. Automated Reasoning 41(1):1–31. [PDF](https://xavierleroy.org/publi/memory-model.pdf)
- David L. Parnas (1972). *On the Criteria To Be Used in Decomposing Systems into Modules.* CACM 15(12):1053–1058.
  [doi:10.1145/361598.361623](https://doi.org/10.1145/361598.361623)
- Edsger W. Dijkstra (1974). *On the role of scientific thought* (EWD447).
  [EWD Archive](https://www.cs.utexas.edu/~EWD/transcriptions/EWD04xx/EWD447.html)
- Philip Wadler (1998). *The Expression Problem.* Java-Genericity mailing list.
  [Edinburgh](https://homepages.inf.ed.ac.uk/wadler/papers/expression/expression.txt)
- Adriaan van Wijngaarden (1965). *Orthogonal design and description of a formal language.* Mathematisch
  Centrum MR 76/65. [CWI](https://ir.cwi.nl/pub/9208) *(attribution verified; definitional gloss secondary)*
- Jeff Bonwick (1994). *The Slab Allocator: An Object-Caching Kernel Memory Allocator.* USENIX Summer 1994,
  pp. 87–98.
- Alexander Stepanov & Paul McJones (2009). *Elements of Programming.* Addison-Wesley.
  [PDF](https://www.elementsofprogramming.com/eop.pdf)
- Robert E. Strom & Shaula Yemini (1986). *Typestate: A Programming Language Concept for Enhancing Software
  Reliability.* IEEE TSE SE-12(1):157–171.
- Cross-language: Rust [`RawVec`](https://github.com/rust-lang/rust/blob/master/library/alloc/src/raw_vec/mod.rs),
  [`smallvec`](https://docs.rs/smallvec/) / [`arrayvec`](https://docs.rs/arrayvec/),
  [`Allocator`](https://doc.rust-lang.org/std/alloc/trait.Allocator.html) *(nightly)*; C++
  [`std::vector`](https://en.cppreference.com/w/cpp/container/vector) /
  [`std::pmr`](https://en.cppreference.com/w/cpp/memory/polymorphic_allocator),
  [WG21 P0619R3](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2018/p0619r3.html); Haskell
  [`vector`](https://hackage.haskell.org/package/vector).

### Skills

- `[RES-019]`/`[RES-020]`/`[RES-021]`/`[RES-022]`/`[RES-023]`/`[RES-024]`/`[RES-026]`/`[RES-029]`/`[RES-031]`/`[RES-032]`
  (research process); `[META-003]`/`[META-004]` (supersession); `[ARCH-LAYER-001]`/`[ARCH-LAYER-008]`
  (layering + correctness-driver); `[MOD-DOMAIN]`/`[MOD-003]`/`[MOD-009]`/`[MOD-012]`/`[MOD-035]`/`[MOD-RENT]`
  (modularization); `[SEM-DEP-006]`/`[SEM-DEP-008]`/`[SEM-DEP-009]`; `[API-NAME-002]` (compose-don't-precompose).
