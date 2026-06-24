# Bounded Discipline — Algebraic Model

<!--
---
version: 1.0.0
last_updated: 2026-06-24
status: RECOMMENDATION
tier: 2
scope: cross-package
packages: [swift-memory-allocation-primitives, swift-storage-primitives, swift-buffer-linear-primitives, swift-buffer-ring-primitives, swift-column-primitives, swift-stack-primitives, swift-pool-primitives, swift-finite-primitives]
---
-->

## Context

Formal companion to `bounded-discipline-analysis.md` (the inventory + recommendation — the
WHAT/WHY). During the design dialogue that produced that doc, three placement questions
recurred — *where does the bounded axis live? is `.Inline` redundant with `.Bounded`?
should it be `Memory.Heap.Bounded`?* — each of which is answered precisely by an algebraic
model rather than by intuition. This doc supplies the `[RES-024]` formal semantics: the
container composition stack and the capacity axis expressed as sum/product/functor
relations, so future placement, merge, and naming questions are decided structurally.

It **formalizes existing structure** — the Decoupling Charter (`[DS-025]`–`[DS-027]`), the
variant lattice (`[DS-002]`), the leaf-occupancy DECISION (`occupancy-lives-in-the-leaf.md`,
`[DS-023]`) — and introduces no new normative contract. Where the model and the code
disagree, the code is ground truth; all representation claims carry source citations
(verified 2026-06-24).

## Question

What are the algebraic (sum / product / functor) relations of **(a)** the container
composition stack — Memory → Storage → Buffer → ADT — and **(b)** the bounded/capacity axis
within it? In particular: **which layer introduces "bounded," and how do the variants
relate as sums and products?**

## Notation

| Symbol | Meaning |
|--------|---------|
| `A × B` | product — a record holding **both** an `A` and a `B` |
| `A + B` | sum (coproduct) — **either** an `A` or a `B` (a tagged union / enum) |
| `0` | the empty type — **`Never`**; no inhabitants; additive identity |
| `1` | the unit type; multiplicative identity |
| `Eⁿ` | `n`-fold product `E × … × E` (a fixed array of `n`) |
| `A → B` | morphism / operation (lives on the *behaviour*, not the data) |
| `μX. F(X)` | least fixed point — a recursive type |
| `Σᵢ Aᵢ` | indexed sum — a choice of `Aᵢ` tagged by `i` (incl. dependent sum) |
| `F(−)` | type constructor / functor (a generic type, e.g. `Buffer<−>`) |
| `≅` | isomorphism |

Standard ADT-algebra identities used below: `Optional<E> ≅ 1 + E` (nil + some); `Never ≅ 0`;
`A + 0 ≅ A`; `A × 1 ≅ A`; the free monoid / list `E* ≅ μL.(1 + E×L) ≅ Σ_{k≥0} Eᵏ`
(Kleene star).

## Analysis

### 1. The value, abstractly — bounded is a *truncated sum*

A LIFO stack's abstract value is the free monoid on `E`:

```
Stack(E)  =  E*  =  μL.(1 + E×L)  =  Σ_{k≥0} Eᵏ  =  1 + E + E² + E³ + ⋯
```

"Growable" is that **infinite** sum. **Bounded at capacity `n` is the same sum truncated:**

```
Stack_≤n(E)  =  Σ_{k=0}^{n} Eᵏ  =  1 + E + E² + ⋯ + Eⁿ
```

So the entire concept in one line: **bounding caps the length-index of the sum.** The two
"where is `n` known" cases differ only in where `n` lives:

```
.Bounded          Σ_{n:ℕ} Stack_≤n(E)     -- n is a VALUE (chosen at runtime)
.Inline / .Static     Stack_≤N(E)         -- n = N is a TYPE INDEX (fixed in the type)
```

This is the precise form of the "runtime vs compile-time capacity" distinction: the *same*
`Σ_{k≤n} Eᵏ`, with `n` at the value level (`.Bounded`) or the type level (`.Inline`). It is
representation-independent — a bounded linked list of `≤ n` nodes has the **same** abstract
value `Σ_{k≤n} Eᵏ`; only its representation (§5) and the layer that enforces `n` differ.

### 2. The representation — bounded and growable share a product

A linear buffer's stored representation is its header times its storage block:

```
Buf.Linear(E)  ≅  (count: ℕ) × (capacity: ℕ) × Storage(E)
                   └──────── Header ────────┘
```

`Header ≅ ℕ × ℕ` is a literal product (`Buffer.Linear.Header.swift:24-29`:
`count: Index.Count`, `capacity: Index.Count`). **`Buf.Linear` and `Buf.Linear.Bounded`
have the *identical* representation product** — bounded adds nothing to the data
(`Buffer.Linear.Bounded.swift:13`: same `{ header, storage }`). The distinction is therefore
**not** in the type's product/sum shape; it is in the morphism (§3).

### 3. The morphism — bounded is a `+Overflow` summand (and `Never = 0`)

The growth-causing operation is where the two diverge:

```
push_growable : Buf × E  →  Buf                  -- total; may reallocate
push_bounded  : Buf × E  →  Buf × (1 + E)        -- returns the REJECTED element (1+E = E?)
```

The `1 + E` is `Optional<E>` — *nil = accepted, or the rejected element returned* — which is
exactly `append(_:) -> S.Element?` (`Buffer.Linear.Bounded+Lifecycle.swift:45`;
`Buffer.Ring.Bounded+Operations.swift:40`, `if header.isFull { return element }`). In
typed-throws form the result carries an error summand:

```
push : Buf × E  →  Buf + Overflow_B          (typing rule, parameterized by buffer B)

      Overflow_growable  =  0   (Never)          ⟹  Buf + 0 ≅ Buf      (no error)
      Overflow_bounded   =  1   (capacityExceeded)   ⟹  Buf + 1          (one failure)
```

Two consequences fall out of the algebra:

1. **`Never = 0` is the additive identity**, so `Buf + 0 ≅ Buf` — this is the algebraic
   reason `throws(Never)` is non-throwing. (Empirically confirmed on Swift 6.3.2: a
   `func push() throws(B.Overflow)` needs no `try` at the call site when `B.Overflow == Never`
   — probe `scratchpad/bounded_probe.swift`.) The single uniform seam over bounded *and*
   growable buffers is therefore sound, not a hack.
2. The two encodings differ only in whether the rejected element survives:
   `Buf × (1+E)` (return-rejected — preserves `E`) vs `Buf + 1` (typed throw — discards `E`).
   Both occur in the corpus (return-rejected for the hot seam; throwing at the builder/array
   boundary, `Buffer.Linear.Bounded+Builder.swift:42`).

**Bounded-ness is precisely the choice of the `Overflow` summand** — `0` vs `1`. The seven
duplicated overflow enums catalogued in the companion (`capacityExceeded`×3 / `overflow`×3 /
`full`×1) are seven spellings of the *same* summand; unifying them ≡ fixing one canonical
`Overflow = 1` (or `1 + E`).

### 4. The variant lattice — a product of orthogonal sums

```
storage location  L  =  Heap + Inline(N) + Small(N)
growth policy     G  =  Growable + Bounded + Fixed
```

The variant set is the grid `L × G`, with **one quotient**: `Inline`/`Small` move `n` into
the *type index* (§1), which forces `G` (you cannot grow what the type fixes). So `G` is a
free choice only when storage leaves `n` at the value level (Heap):

```
Variants  ≅  ( Heap × {Growable, Bounded, Fixed} )  +  Inline(N)  +  Small(N)
```

- `.Bounded`  =  the **`Heap × Bounded`** cell: runtime `n`, heap, `Overflow = 1`.
- `.Inline`   =  its own summand, with `G` pinned by `N` (compile-time `Overflow`).
- `.Fixed`    =  `Heap × Fixed`: constructed full, no `push` morphism (immutable; `count = capacity`).

`.Inline` and `.Bounded` share the *growth policy* (reject) but occupy **different cells** —
they are not redundant; one is `n`-at-type-index, the other `n`-at-value-level. (See
`variant-naming-audit.md:83-85`: `.Bounded` = "Dijkstra bounded buffer"; `.Static` = inline,
compile-time capacity.)

### 5. The composition stack — functors, and where the bound enters

Each layer is a functor over the one below (the Charter shape, `[DS-025]`):

```
Mem ∈ { Heap, Pool(n), Arena(n) }
                 │  Stor(M, E)            -- element lifecycle over allocator M
                 ▼
              Stor ──► Buf(S) ──► Adt(B)

Stack.Heap(E)    = Adt_Stack( Buf_Linear        ( Stor_Contig(Heap, E) ) )
Stack.Bounded(E) = Adt_Stack( Buf_Linear.Bounded( Stor_Contig(Heap, E) ) )
```

Only the middle functor differs (`Buf_Linear` → `Buf_Linear.Bounded`); `Heap` and
`Stor_Contig` are byte-for-byte identical (`Column.swift:62-68`). **Therefore the `+Overflow`
of §3 is introduced by the `Buf` functor — not by `Mem`.** This is the formal answer to
*"is it `Memory.Heap.Bounded`?"* — **no**: `Heap` is the unbounded allocator; bounded is the
buffer's growth policy over an ordinary `Heap` allocation.

**The pool exception.** A pool *is* a fixed-region allocator, so for the pool/linked family
the bound enters at `Mem`:

```
Pool(n) ≅ n cells           full  ⟺  allocator exhausted
LinkedNode(E) = μX.(1 + E × Ref(X))     over Pool(n)  ⟹  ≤ n live nodes ⟹ value Σ_{k≤n} Eᵏ
```

Here the `+Overflow` rides up from `Mem = Pool(n)` (already a bounded allocator), which is
why `List.Linked.Bounded` delegates `isFull` downward (`List.Linked.Bounded.swift:31`)
instead of holding a header cap. Still **not** `Memory.Heap.Bounded` — the bounded allocators
are `Pool`/`Arena`.

| Layer | Role in "bounded" |
|-------|-------------------|
| `Mem` | unbounded (`Heap`) **or** inherently fixed-region (`Pool(n)`/`Arena(n)`). No `Heap.Bounded`. |
| `Stor` | holds one block; reports `capacity`. Same functor for bounded and growable. |
| `Buf` | **introduces the bound** — `capacity` in the Header + the `+Overflow` summand on `push`. |
| `Adt` | introduces nothing — rides the buffer. (Stack's `requestedCapacity` re-check is the one leak, see companion R4.) |

### 6. The proliferation and its cure — enumerated sum → functor image

Today each family hand-writes an **enumerated sum of bespoke concrete types**:

```
StackTypes  =  Stack + Stack.Bounded + Stack.Inline(N) + Stack.Small(N) + ⋯
```

The structural recommendation is the refactor that recognizes each summand as the image of a
**single functor applied to a buffer**, replacing the enumerated sum with a Σ over the buffer
choice:

```
Σᵢ Stackᵢ        ⟶        Σ_{B ∈ Buffers} Stack(B)            -- Stack becomes a functor
Stackᵢ  ≅  Stack(Bᵢ)      (each bespoke type IS an application)
```

`Stack.Bounded` is then not a *summand-type* but the **application** `Stack(Buf_Linear.Bounded)`,
surfaced as a typealias (zero code) — exactly as `Column.Bounded` is already
`Buffer.Linear.Bounded` (`Column.swift:67`). The proliferation was *manually spelling out the
summands of a Σ that one functor generates*.

**Soundness of the refactor.** It preserves the set of representable containers (each `Stackᵢ`
is `Stack(Bᵢ)`, no inhabitant gained or lost) and the seam types (the conditional `+Overflow`
of §3 is sound because `A + 0 ≅ A`). So the move is inhabitant-preserving — a refactor, not a
semantic change.

## Outcome

**Status: RECOMMENDATION** — formal grounding for the structural recommendation in
`bounded-discipline-analysis.md`. It decides nothing new; it makes that recommendation precise
and gives future placement/merge/naming questions a structural test. The model settles the
running questions:

| Question | Algebraic verdict |
|----------|-------------------|
| Where does the bounded axis live? | The `+Overflow` summand on `push`, introduced by the **`Buf`** functor (contiguous) or by **`Mem = Pool(n)/Arena(n)`** (pool family). |
| Is it `Memory.Heap.Bounded`? | **No.** `Heap` is the unbounded allocator; `Buf_Linear` and `Buf_Linear.Bounded` share the same `Heap`/`Stor` functors. |
| Is `.Inline` redundant with `.Bounded`? | **No** — distinct cells of `L × G`: `n` at type-index (`.Inline`) vs value-level (`.Bounded`). |
| Can the per-ADT `.Bounded` *type* be removed? | **Yes**, inhabitant-preservingly: `Σᵢ Stackᵢ ⟶ Σ_B Stack(B)`; `Stack.Bounded ≅ Stack(Buf_Linear.Bounded)`, a typealias. |
| Why does `throws(Never)` unify the seam? | `Never = 0`, `Buf + 0 ≅ Buf` — the additive identity. |
| What does "single-source the overflow vocabulary" mean? | Fix one canonical `Overflow` summand (`1` or `1 + E`) for all bounded buffers. |

**Test for future designers**: a proposed variant is a *new cell* iff it changes a factor of
`L × G` (storage location or growth policy / `Overflow` summand). If it only re-spells an
existing cell, it is a typealias, not a type.

## References

Companion:
- `swift-institute/Research/bounded-discipline-analysis.md` — inventory + recommendation (the WHAT/WHY this doc grounds)

Prior research (cite-and-extend):
- `swift-institute/Research/adt-buffer-storage-decoupling-shape.md` — the Charter rationale (`[DS-025]`–`[DS-027]`): the `Adt(Buf(Stor(Mem)))` functor chain
- `swift-institute/Research/occupancy-lives-in-the-leaf.md` — `.Bounded` retained as a capacity axis; occupancy in the leaf (`[DS-023]`)
- `swift-institute/Research/variant-naming-audit.md:83-85` — the `L × G` cells; `.Bounded` = Dijkstra bounded buffer
- `swift-institute/Research/cross-layer-capability-protocol-model.md` — capability-by-conditional-extension (the alternative seam encoding of §3)

Source (verified 2026-06-24):
- `swift-column-primitives/Sources/Column Primitives/Column.swift:62-68` — `Column.Heap` vs `Column.Bounded` differ only at `Buf`
- `swift-buffer-linear-primitives/Sources/Buffer Linear Primitive/Buffer.Linear.Header.swift:24-29` — `Header ≅ ℕ × ℕ`
- `swift-buffer-linear-primitives/Sources/Buffer Linear Bounded Primitive/Buffer.Linear.Bounded+Lifecycle.swift:45` — `append → 1 + E`
- `swift-buffer-ring-primitives/Sources/Buffer Ring Bounded Primitive/Buffer.Ring.Bounded+Operations.swift:40` — return-rejected seam
- `swift-list-linked-primitives/Sources/List Linked Primitives/List.Linked.Bounded.swift:31` — `isFull` delegated to the pool-backed buffer
- `scratchpad/bounded_probe.swift` — `throws(Never)` ≅ non-throwing, Swift 6.3.2

Theory:
- Free monoid / Kleene star `E* = μL.(1 + E×L)`; algebra of algebraic data types (sum/product/exponential); `Optional ≅ 1 + E`; `Never ≅ 0` (initial object); `A + 0 ≅ A`
- SE-0413 Typed Throws — `throws(Never)` equivalent to non-throwing
- Skills: `[RES-024]` formal semantics, `[RES-022]` structural framing, `[DS-002]` variant system, `[DS-025]` Decoupling Charter
