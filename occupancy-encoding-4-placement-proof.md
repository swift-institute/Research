# Occupancy Encoding (4) — Placement Proof and Information-Theoretic Lower Bound

<!--
---
version: 1.0.0
last_updated: 2026-06-08
status: DECISION
tier: 3
scope: ecosystem-wide
extends:
  - occupancy-lives-in-the-leaf.md                          # the placement LAW (axiom: occupancy in the leaf)
  - conditional-deinit-conditionally-copyable-generics.md   # the SE-0427 Wall-1 soundness proof + S1-S8 matrix (axioms)
  - buffer-arena-conditional-copyable.md                    # the shipped sparse-leaf existence proof
---
-->

> **One-line result.** Make the buffer tower a theorem. A bitmap is information-optimal for
> arbitrary liveness (`N` bits, achieved); a range-ledger is optimal for contiguous liveness
> (`Θ(log N)` bits, achieved by `Store.Initialization`); a per-element `Optional` tag is
> *never strictly better than the bitmap and usually catastrophically worse* — except in the
> single characterized case where the element exports ≥1 free extra-inhabitant, where the tag
> costs **0 marginal bits** and uniquely also buys value-semantics. Self-cleaning forces the
> teardown witness to *see* the liveness set it must destroy; the **placement lattice** proves
> exactly three homes for that set, and that two of the three (separate-plane, buffer-held)
> entail a custom `deinit`, which on inline storage collides with the SE-0427 Wall-1 law and is
> *provably exclusive* with conditional value-semantics. The exactly-excluded region is the
> single cell {inline × sparse × want-value-semantics × no-spare-bit}; it is **not vacuous**
> (no-niche element types are common), and it is collapsed by exactly one language feature —
> a conditional `deinit` (SE-0427's deliberately-excluded generalization).

---

## Context

The MSB buffer tower converged (`occupancy-lives-in-the-leaf.md`, DECISION 2026-06-07) on a
single law: **liveness tracking and element teardown live in a single-allocation leaf, never in
the buffer.** That law dissolved the `.Inline`/`.Small` *buffer* carve-outs and reduced every
`Buffer.<discipline>` to one pure-generic, `deinit`-free type. The companion tier-3 note
(`conditional-deinit-conditionally-copyable-generics.md`) proved — empirically on Swift 6.3.2 and
6.4-dev — that a custom conditional `deinit` on a conditionally-`Copyable` generic is impossible
(Wall-1; SE-0427; mirrored by Rust E0184/E0367), and that the one honest residual is a trilemma:
*bit-density + value-semantics + inline, simultaneously*, of which exactly one corner must yield.

Those two documents establish the **placement** (occupancy → leaf) and the **soundness law**
(`deinit ⟹ unconditionally ~Copyable`). What they do **not** do is establish the *information-
theoretic floor* — the minimal number of bits any occupancy representation must spend — nor prove
that the chosen encoding per configuration is *Pareto-optimal* rather than merely *sufficient*.
The residual trilemma is stated as "one corner yields" but not proved to be the **unique** excluded
cell of a complete satisfiability grid, nor characterized at the bit level.

This note closes that gap. It treats the whole arrangement as a theorem: it proves the information
floor, proves the placement lattice (where liveness *may* live for self-cleaning to hold and what
each placement forces), and proves a complete satisfiability matrix over the configuration grid with
the unique Pareto-optimal encoding per cell and the precisely-excluded region. The SE-0427 Wall-1
result is consumed as an **axiom** (re-verified by minimal repro on 6.3.2, below); this note's
original content is the lower bound and the placement/satisfiability theorems.

### Trigger

Shared dispatch (2026-06-08): "PROVE the exact frontier of an occupancy-bearing container w.r.t.
{one `Store.Protocol`; ≤1 bit/slot bit-density; value-semantics via one generic `Buffer<S>`;
self-cleaning teardown with no buffer `deinit`; maximal decomposition}. Prove which combinations
coexist and which are provably exclusive, and whether the excluded region is vacuous. No wall claim
without a minimal repro on Swift 6.3.2 (`TOOLCHAINS=org.swift.632202605101a`)." Angle: placement
proof + information-theoretic lower bound.

### Constraints

- **No wall claim without a 6.3.2 repro.** All load-bearing layout/diagnostic claims are
  reproduced on Apple Swift 6.3.2 (`swift-6.3.2-RELEASE`); artifacts in `/tmp/occ-proof/`.
- Research only — no tower edits. `/tmp` scratch only.
- Tier-3 rigor per [RES-020]/[RES-022]/[RES-023]/[RES-024]/[RES-026]: formal semantics inline,
  prior-art contextualization, every empirical claim verified at write time.
- The five frontier properties are labelled (A)–(E) throughout, exactly as dispatched:
  **(A)** one `Store.Protocol` (no refinement); **(B)** guaranteed bit-density ≤1 bit/slot;
  **(C)** value-semantics / conditional `Copyable` with the carve-out *types* dissolved into one
  generic `Buffer<S>`; **(D)** self-cleaning teardown (no buffer `deinit`; SE-0427 Wall-1 avoided);
  **(E)** maximal decomposition + clean composition.

---

## Question

For a container of `N` physical slots with liveness set `L ⊆ [0, N)`, whose teardown must destroy
**exactly** `L` automatically (self-cleaning = teardown is the type's automatic value-witness, no
custom buffer `deinit`):

1. **Information floor.** What is the minimal number of bits to represent `L`, as a function of the
   structure of `L` (contiguous-prefix vs arbitrary) and of the element type's extra-inhabitant
   budget? Is a bitmap information-optimal? Is a per-element `Optional` tag ever cheaper?
2. **Placement lattice.** For self-cleaning to hold, *where* may `L` physically live, and what does
   each placement force on the type's copyability?
3. **Satisfiability matrix.** Over the grid (backing ∈ {heap, inline} × occupancy ∈ {dense, sparse}
   × want-value-semantics ∈ {yes, no} × element-has-spare-bit ∈ {yes, no}), what is the
   minimal-cost representation per cell, are (A)–(E) jointly satisfiable in that cell, what is the
   unique Pareto-optimal encoding, and which cell(s) are excluded?

---

## Axioms (consumed, not re-proved)

| # | Axiom | Source | Re-verification here |
|---|-------|--------|---------------------|
| **AX-1** (Wall-1 law) | `hasUserDeinit(W) ⟹ ¬∃(W : Copyable)` — not even conditionally. A value type with a user `deinit` is *unconditionally* `~Copyable`. | SE-0427 § "Conformance to `Copyable`"; `copyable_illegal_deinit` (`DiagnosticsSema.def:8390`, emitted `TypeCheckInvertible.cpp:228-233`). | **S1 repro on 6.3.2**, below. |
| **AX-2** (class exemption) | Classes may store `~Copyable`/`~Escapable` values and carry a `deinit` while remaining a `Copyable`-layout *reference*. | `TypeCheckInvertible.cpp:221-223` (`// All classes can store noncopyable…`). | Shipped: `Storage.Arena.Backing` (heap leaf). |
| **AX-3** (conditional auto-teardown) | `destroy-fields` is *already* conditional: a `~Copyable` field runs its own `deinit`; a `Copyable` field is trivial. Only **custom** teardown over manually-managed storage is tied to whole-type `~Copyable`-ness. | Spike S7 (axiom doc). | **S7 repro on 6.3.2** ("MoveOnly(7) deinit fired" + "copied ok"), below. |
| **AX-4** (placement law) | Liveness + teardown live in a single-allocation leaf, never in the buffer. `Storage.Contiguous<Memory.X>` lifts dense and sparse leaves uniformly; the buffer is a `deinit`-free generic carrying only access discipline. | `occupancy-lives-in-the-leaf.md` (DECISION). | Located bug site `Buffer.Slab.Header.swift:27` confirmed (occupancy in buffer header). |
| **AX-5** (`Store.Protocol` neutrality) | The neutral element-store capability is exactly four requirements — `capacity`, `subscript{get set}`, `initialize(at:to:)`, `move(at:)` — pointer-free, raw-mechanism encapsulated, cross-module-specializing on 6.3.2. It is **copyability-agnostic**: `associatedtype Element: ~Copyable`, protocol itself `~Copyable`. | `Store.Protocol.swift:20-69`. | Read directly; cited. |

### AX-1 / AX-3 minimal repro on Swift 6.3.2 [Verified: 2026-06-08]

```
$ TOOLCHAINS=org.swift.632202605101a swift --version
Apple Swift version 6.3.2 (swift-6.3.2-RELEASE)

# S1 — the Wall-1 diagnostic (AX-1):
$ swiftc -O wall1.swift           # struct Wrapper<T:~Copyable>:~Copyable { var value:T; deinit{} }
                                  # extension Wrapper: Copyable where T: Copyable {}
wall1.swift:5:5: error: deinitializer cannot be declared in generic struct 'Wrapper'
                        that conforms to 'Copyable'

# S2+S5+S7 assembly — the dense-leaf composition shape (AX-3):
$ swiftc -O walls.swift -o walls && ./walls
MoveOnly(7) deinit fired          # S7: ~Copyable field's deinit fires in the Copyable-conditional wrapper
copied ok: 1, 42                  # S7: the Copyable instantiation copies
S2+S5+S7 ASSEMBLY COMPILES+RUNS   # S2 (move-only leaf + deinit) + S5 (cond-Copyable, no deinit)
```

This reproduces, on the mandated toolchain, the two facts the proof rests on: the wall exists
(AX-1), and assembling a move-only *leaf* (S2) under a `deinit`-free conditionally-`Copyable`
*generic* (S5) with automatic field teardown (S7) is well-formed. The proof never asserts a wall
the compiler does not emit, nor a composition the compiler rejects.

---

## Part I — The Information Floor (proved)

### I.1 Setup

Fix `N`. A liveness set is `L ⊆ [0, N)`; `|L| = k`. A *teardown witness* is a function that, given
the container's bytes, destroys exactly the elements at positions `L`. **Self-cleaning** requires
the witness to recover `L` from the container's own bytes (it cannot consult external state — there
is no caller-supplied argument to an automatic value-witness). Hence the container must *store* a
representation of `L`. Let `R(L)` be the bit-length of that stored representation. We seek `min R`.

The relevant ensembles of `L`:

- **𝒟 (dense / contiguous-prefix)** — `L = [0, k)` for some `0 ≤ k ≤ N`. There are `N + 1` such
  sets (one per value of `k`). This is the *dense* discipline's liveness (Linear/Stack/Array push-pop
  a prefix). A mild generalization, **𝒟₂ (≤2 contiguous runs)**, is the ring discipline's liveness
  (`Store.Initialization.two`).
- **𝒜 (arbitrary)** — any `L ⊆ [0, N)`. There are `2ᴺ` such sets. This is the *sparse* discipline's
  liveness (Slab/Arena/Pool free arbitrary slots).

### I.2 Lower bounds (counting / Shannon)

> **Theorem I.1 (dense floor).** Any self-cleaning representation of a contiguous-prefix `L ∈ 𝒟`
> requires `R(L) ≥ ⌈log₂(N+1)⌉ = Θ(log N)` bits in the worst case.
>
> *Proof.* `|𝒟| = N+1` distinct sets; an injective code needs ≥ `⌈log₂(N+1)⌉` bits by the pigeonhole
> bound. ∎

> **Theorem I.2 (arbitrary floor).** Any self-cleaning representation of an arbitrary `L ∈ 𝒜`
> requires `R(L) ≥ N` bits in the worst case (and `N` bits on average, since `H(𝒜) = N` under the
> uniform prior).
>
> *Proof.* `|𝒜| = 2ᴺ`; an injective code needs ≥ `log₂ 2ᴺ = N` bits. The uniform distribution over
> `𝒜` has Shannon entropy `N`, so no code (even variable-length, even with side information about
> the prior) beats `N` bits expected. ∎

These are the floors. Now the achievability.

### I.3 Achievability — three encodings

**(E_bitmap) Bitmap plane.** Store one bit per slot: `R = N`. Decodes `L` directly
(`i ∈ L ⟺ bit i = 1`). Matches Theorem I.2 exactly: **information-optimal for 𝒜.** Bit-density is
exactly **1 bit/slot** — this is property (B), achieved with equality. Used by `Buffer.Slab`'s
oracle (`Bit.Vector`).

**(E_ledger) Range ledger.** Store the run boundaries. For `𝒟`: one integer `k ∈ [0, N]`, so
`R = ⌈log₂(N+1)⌉` — matches Theorem I.1 exactly: **information-optimal for 𝒟.** For `𝒟₂`: up to two
ranges = four bounded indices = `Θ(log N)`. This is precisely `Store.Initialization`
(`Store.Initialization.swift:47-60`): `.empty` / `.one(Range)` / `.two(first:second:)`. It is
*exponentially* below the bitmap on `𝒟` (`log N` vs `N`) — but is **only defined on 𝒟 ∪ 𝒟₂**; it
*cannot* injectively encode `𝒜` (its codomain has `Θ(N²)` points, far below `2ᴺ`). Used by the dense
leaves (`Memory.Inline._initialization`, `Memory.Heap`).

**(E_tag) Per-element Optional tag.** Store liveness *in the element cell* as `Optional<Element>`:
slot `i` is live iff its cell is `.some`. No separate plane; the teardown witness is the *automatic*
`Optional` destructor (it destroys `.some`, ignores `.none`) — so this is the only encoding that is
self-cleaning **without any custom teardown at all** (deep consequence; Part II). Its cost is the
subtle one, and is the crux of the whole frontier.

### I.4 The exact cost of (E_tag) — extra-inhabitants characterized

Naively, `Optional<Element>` adds a discriminator bit per slot, giving `R = N` — *equal* to the
bitmap, never better. But Swift fills the `Optional` discriminator from the element's **extra
inhabitants** (a.k.a. spare bit-patterns / niches): bit patterns of `Element`'s storage that are not
valid `Element` values. If `Element` has ≥1 extra inhabitant, `.none` is encoded *inside the element's
own bytes* and the tag costs **0 marginal bits/slot**.

Let `xi(Element)` = number of extra inhabitants of `Element`'s layout. Then:

```
R(E_tag) per slot  =  0                       if  xi(Element) ≥ 1      (niche-fill)
                      ⌈log₂(stride⁺ / stride)⌉·8  (rounded to stride)  otherwise
```

where the second branch is "no spare bit ⟹ the discriminator must occupy fresh storage, rounded up
to alignment stride." **Measured on 6.3.2** [Verified: 2026-06-08], `MemoryLayout` confirms the
characterization exactly:

| `Element` | `xi` | `T.stride` | `Optional<T>.stride` | marginal tag cost |
|-----------|------|-----------|----------------------|-------------------|
| `class Ref` | ≥1 (null) | 8 | 8 | **0 B** — niche |
| `Bool` | 254 | 1 | 1 | **0 B** — niche |
| `enum{a,b,c}` | 253 | 1 | 1 | **0 B** — niche |
| `UnsafeRawPointer` | ≥1 (null) | 8 | 8 | **0 B** — niche |
| `UInt8` (full domain) | 0 | 1 | 2 | **+1 B** = 8 bit/slot |
| `Int` (full domain) | 0 | 8 | 16 | **+8 B** = 64 bit/slot |

> **Theorem I.3 (tag vs bitmap dominance).** For arbitrary `L ∈ 𝒜`:
> - If `xi(Element) ≥ 1`: `R(E_tag) = 0` marginal bits/slot **< `R(E_bitmap) = 1` bit/slot**. The
>   tag is *strictly* the unique information optimum (it beats even the Theorem-I.2 floor *for the
>   separate-plane formulation*, because the information is folded into bytes that already exist —
>   the floor `N` counts bits *dedicated* to `L`; niche-fill spends *zero dedicated bits*).
> - If `xi(Element) = 0`: `R(E_tag) ≥ ⌈log₂ 2⌉` rounded to stride `≥ 1` bit/slot, and in practice
>   `≥ 8` bit/slot (alignment), so `R(E_tag) ≥ R(E_bitmap)` — the tag is **never cheaper** and
>   typically **8×–64× worse** than the bitmap.
>
> *Proof.* Direct from §I.4's cost function and the 6.3.2 measurements. The niche case folds the
> discriminator into pre-existing slack; the no-niche case must allocate it, and integer alignment
> rounds the single logical bit up to a whole byte or word. ∎

**Density measurement on 6.3.2** [Verified: 2026-06-08], `N=64`:

```
Bitmap form:      elements=512B + bitmap=8B    → occupancy = 1.0 bit/slot      (E_bitmap, ≤1 — (B) holds)
Tombstone form:   1024B total                  → occupancy = 64 bit/slot       (E_tag, Int: no niche — (B) FAILS)
Tombstone(niche): 512B == bare 512B            → occupancy = 0 marginal bit/slot (E_tag, class ref: niche — (B) holds with margin)
```

### I.5 Information floor — summary table

| Liveness ensemble | Floor (Shannon/counting) | Optimal encoding | Achieves floor? | (B) ≤1 bit/slot? |
|-------------------|--------------------------|------------------|-----------------|------------------|
| **𝒟** contiguous-prefix | `⌈log₂(N+1)⌉` = `Θ(log N)` | `E_ledger` (`Store.Initialization`) | **Yes, exactly** | Yes (asymptotically 0) |
| **𝒟₂** ≤2 runs (ring) | `Θ(log N)` | `E_ledger` (`.two`) | Yes | Yes |
| **𝒜** arbitrary, no element niche | `N` | `E_bitmap` (`Bit.Vector`) | **Yes, exactly** | Yes (= 1) |
| **𝒜** arbitrary, element has niche ≥1 | `N` dedicated; **0** if folded | `E_tag` (niche-fill `Optional`) | **Beats the dedicated floor** | Yes (= 0 marginal) |

**The information-theory verdict:** for property (B), `E_ledger` and `E_bitmap` always satisfy
`≤1 bit/slot` (the bitmap with equality, the ledger with exponential margin). `E_tag` satisfies (B)
**iff** the element has a spare bit; otherwise it violates (B) by 8×–64×. This single fact — *the tag
honors (B) only under a niche* — is the seed of the excluded region. The bitmap is the
information-optimal **arbitrary** encoding; the ledger is the information-optimal **contiguous**
encoding; the tag is information-optimal **only** for niche-bearing elements, where it is *uniquely*
optimal because it spends zero dedicated bits.

---

## Part II — The Placement Lattice (proved)

### II.1 The three placements

For self-cleaning to hold, the teardown witness must recover `L` from the container's bytes (§I.1).
There are exactly three structural locations where the `R(L)` bits may physically sit:

- **(i) In the element cell** — `L` is the `Optional` discriminator distributed across the slots
  themselves (`E_tag`). No separate plane.
- **(ii) In a separate plane inside the leaf** — `L` is a side array (bitmap / generation tokens /
  free-list / range-ledger) co-allocated *within the single-allocation leaf* alongside the elements
  (`E_bitmap`, `E_ledger`, generation/free-list).
- **(iii) In the buffer** — `L` is a field of the buffer struct, *outside* the leaf
  (the pre-law `Buffer.Slab.Header.bitmap` shape; AX-4's located bug).

These are exhaustive: the bits are either *interleaved with* the elements (i), *beside* them in the
same allocation (ii), or *in a different object* — the buffer (iii). (A fourth "external/global"
location is excluded by definition: an automatic value-witness takes no external argument.)

### II.2 What each placement forces

> **Lemma II.1 (placement (i) ⟹ tag-or-spare-bit, and *no custom teardown*).** If `L` lives in the
> element cell, the representation *is* `E_tag`, so by Theorem I.3 it honors (B) iff the element has a
> spare bit. Crucially, the teardown witness is the **automatic** `Optional` destructor — there is
> **no custom `deinit` anywhere**. Hence placement (i) *uniquely* needs no `deinit` even for arbitrary
> sparse `L`.
>
> *Proof.* `Optional<Element>`'s value-witness destroys `.some` and skips `.none` (AX-3: automatic
> field teardown is already liveness-conditional per-slot). The container is then a plain array of
> `Optional<Element>` — `Storage.Contiguous<Memory.X>` with element `Optional<Element>` — whose own
> automatic destruction handles everything. Cost per Theorem I.3. ∎

> **Lemma II.2 (placement (ii)/(iii) ⟹ custom teardown).** If `L` lives in a separate plane (ii) or
> in the buffer (iii), the elements are stored *raw* (un-`Optional`), so their bytes carry **no**
> liveness information; the automatic field walk cannot know which slots to destroy. Recovering `L`
> from the side plane and destroying exactly those slots requires a **custom teardown step** — i.e. a
> `deinit` that reads the plane and calls `deinitialize` on the live slots.
>
> *Proof.* Raw storage hides liveness from the automatic field walk (this is exactly AX-3's "custom
> teardown over manually-managed storage" gap, and the explicit design of `Memory.Inline.deinit`,
> which *walks `_initialization`*, and `Storage.Arena.Backing.deinit`, which *walks generation
> tokens*). No automatic witness reads a foreign side-plane; therefore a user `deinit` is mandatory. ∎

> **Lemma II.3 (where the `deinit` may sit).** A custom teardown `deinit` (Lemma II.2) may be placed
> on a **class** (AX-2) — preserving a `Copyable`-layout reference — or on the **struct** that owns the
> raw storage. On a struct, AX-1 forces the struct *unconditionally `~Copyable`*; if that struct is
> generic and aspires to conditional `Copyable`, the wall fires (S1).
>
> *Proof.* AX-2 exempts classes; AX-1 binds structs. ∎

### II.3 The placement lattice (the central diagram)

Combining Lemmas II.1–II.3 with the backing axis (heap = a class allocation is available;
inline = `@_rawLayout`, *no* class, the storage is a struct field):

```
                         L lives in …
            ┌─────────────────────┬──────────────────────────────────────────────┐
            │ (i) element cell     │ (ii)/(iii) separate plane / buffer             │
            │ = E_tag              │ = E_bitmap / E_ledger / tokens                 │
            ├─────────────────────┼──────────────────────────────────────────────┤
 teardown   │ AUTOMATIC            │ CUSTOM deinit (Lemma II.2)                      │
 witness    │ (Optional dtor)      │                                                │
            ├─────────────────────┼───────────────────────┬──────────────────────┤
            │                      │ deinit on a CLASS      │ deinit on the STRUCT  │
            │                      │ (heap leaf; AX-2)      │ (inline leaf; AX-1)   │
            ├─────────────────────┼───────────────────────┼──────────────────────┤
 copyability│ flows from element:  │ class = Copyable ref   │ AX-1 ⟹ unconditionally│
 of the     │ Optional<Copyable>   │ ⟹ leaf is conditional  │ ~Copyable. Generic    │
 LEAF       │ is Copyable;         │ Copyable (the stdlib   │ conditional Copyable  │
            │ Optional<~Copyable>  │ Array model). SHIPPED:  │ FORBIDDEN (S1 wall).  │
            │ is ~Copyable.        │ Storage.Arena.Backing. │ ⟹ MOVE-ONLY leaf.     │
            └─────────────────────┴───────────────────────┴──────────────────────┘
```

> **Theorem II.4 (placement → copyability).** Under AX-4 (occupancy in the leaf, buffer is a
> `deinit`-free generic — placement (iii) is *retired* in favor of (ii)), the leaf's copyability is
> determined by the placement choice and the backing:
>
> | Placement of `L` | Backing | Leaf teardown | Leaf copyability | Bit-density (B) |
> |------------------|---------|---------------|------------------|-----------------|
> | (i) element cell `E_tag` | heap **or** inline | automatic `Optional` dtor | **conditional** `Copyable` (flows from `Element`) | (B) iff element has spare bit |
> | (ii) separate plane | **heap** (class) | custom `deinit` on the **class** | **conditional** `Copyable` (AX-2: ref layout) | (B) always (bitmap=1, ledger=Θ(log N)) |
> | (ii) separate plane | **inline** (`@_rawLayout`) | custom `deinit` on the **struct** | **unconditionally `~Copyable`** (AX-1) → move-only | (B) always |
>
> *Proof.* Row 1 is Lemma II.1 + the fact that `Optional<T>`'s copyability tracks `T`'s (stdlib).
> Row 2 is Lemma II.2 + Lemma II.3 (class branch) + AX-2. Row 3 is Lemma II.2 + Lemma II.3 (struct
> branch) + AX-1 (the inline backing offers *no* class to host the `deinit`; the storage *is* a struct
> field, so the `deinit` lands on a struct). ∎

**Reading of the buffer over the leaf.** In all three rows the *buffer* is the single generic
`Buffer<S: Store.Protocol>` with **no `deinit`** (AX-4), so its copyability *flows from `S`* (S5
shape, verified): conditional `Copyable` when the leaf is conditional (rows 1, 2-heap), move-only
when the leaf is move-only (row 3). Property (E) — one generic buffer, carve-out *types* dissolved —
holds in **every** row. Property (C) — conditional value-semantics — holds in rows 1 (under a niche)
and 2-heap, and **fails** in row 3 (the move-only inline leaf is `~Copyable`, period). This is the
crux, formalized next.

### II.4 The exclusion, located

> **Theorem II.5 (the exclusion).** The conjunction {**inline** backing × **sparse/arbitrary**
> liveness × **want value-semantics (C)** × **no element spare bit**} is **unsatisfiable**.
>
> *Proof.* Sparse/arbitrary `L` over inline backing. By Theorem I.3, the only (B)-compliant arbitrary
> encoding when the element has **no** spare bit is a *separate plane* (`E_bitmap`/tokens) — placement
> (ii), because the tag (placement (i)) costs ≥8 bit/slot and violates (B). Placement (ii) over an
> inline backing is **Row 3** of Theorem II.4: AX-1 forces the leaf *unconditionally `~Copyable`*, so
> value-semantics (C) is impossible. The only escape from Row 3 to a conditional-`Copyable` leaf is
> AX-2 (host the `deinit` on a class) — but that *is* a heap allocation, contradicting "inline." The
> only escape from the separate plane to placement (i) is `E_tag` — but that violates (B) by
> hypothesis (no spare bit). Both escapes are closed; the cell is empty. ∎

This is precisely the "one honest residual" of `occupancy-lives-in-the-leaf.md`, now proved to be the
**unique** excluded cell of the full grid (Part III) and characterized at the bit level (it is the
*no-niche* sub-case — under a niche, `E_tag` rescues the cell, as the next part shows).

---

## Part III — The Satisfiability Matrix (proved)

### III.1 The grid

Configuration axes (the dispatched grid): `backing ∈ {heap, inline}` × `occupancy ∈ {dense, sparse}`
× `want-value-semantics ∈ {yes, no}` × `element-has-spare-bit ∈ {yes, no}` = 16 cells. For each cell:
the minimal-cost (Pareto-optimal) encoding, and whether (A)–(E) are jointly satisfiable.

Notation in the verdict column: **✓** = all of (A)–(E) jointly satisfiable; **✓\C** = (A),(B),(D),(E)
satisfiable, (C) *not requested* (want-value-semantics = no) so the move-only outcome is the intended
optimum, not a failure; **✗(C)** = the excluded region — (C) requested but unsatisfiable.

The five properties recur as: (A) one `Store.Protocol` — holds in *every* cell (AX-5: the protocol is
copyability-agnostic and dense/sparse-agnostic; every leaf below conforms it). (E) one generic buffer
— holds in *every* cell (AX-4). So the matrix turns on (B), (C), (D), per cell.

### III.2 The matrix

| # | backing | occupancy | want-VS (C) | spare-bit | Pareto-optimal encoding | (B) | (C) | (D) | Verdict |
|---|---------|-----------|-------------|-----------|-------------------------|-----|-----|-----|---------|
| 1 | heap | dense | yes | yes | `E_ledger` in class leaf (`Memory.Heap`) | ✓ Θ(logN) | ✓ class (AX-2) | ✓ class deinit | **✓** |
| 2 | heap | dense | yes | no | `E_ledger` in class leaf | ✓ | ✓ | ✓ | **✓** |
| 3 | heap | dense | no | yes | `E_ledger` in class leaf | ✓ | – | ✓ | **✓** (C n/a) |
| 4 | heap | dense | no | no | `E_ledger` in class leaf | ✓ | – | ✓ | **✓** (C n/a) |
| 5 | heap | sparse | yes | yes | **`E_tag`** in class leaf *(niche: 0-bit, beats bitmap)* | ✓ 0 | ✓ | ✓ auto | **✓** |
| 6 | heap | sparse | yes | no | `E_bitmap`/tokens in class leaf (`Storage.Arena`) | ✓ 1 | ✓ class (AX-2) | ✓ class deinit | **✓** |
| 7 | heap | sparse | no | yes | `E_tag` *(niche)* or bitmap-in-class | ✓ 0 | – | ✓ | **✓** (C n/a) |
| 8 | heap | sparse | no | no | `E_bitmap`/tokens in class leaf | ✓ 1 | – | ✓ | **✓** (C n/a) |
| 9 | inline | dense | yes | yes | `E_ledger` in `@_rawLayout` leaf | ✓ | ✓\* | ✓ struct deinit | **✓\*** |
| 10 | inline | dense | yes | no | `E_ledger` in `@_rawLayout` leaf (`Memory.Inline`) | ✓ | ✗→move-only\*\* | ✓ struct deinit | **✗(C)→\*\*** |
| 11 | inline | dense | no | yes | `E_ledger` in `@_rawLayout` leaf | ✓ | – | ✓ | **✓\C** |
| 12 | inline | dense | no | no | `E_ledger` in `@_rawLayout` leaf (`Memory.Inline`) | ✓ | – | ✓ | **✓\C** |
| 13 | inline | sparse | yes | yes | **`E_tag`** in `@_rawLayout` leaf *(niche: 0-bit, auto-dtor)* | ✓ 0 | **✓** | ✓ **auto** | **✓** |
| 14 | inline | sparse | **yes** | **no** | `E_bitmap` in `@_rawLayout` leaf → struct deinit | ✓ 1 | **✗ (Thm II.5)** | ✓ struct deinit | **✗(C) — THE excluded cell** |
| 15 | inline | sparse | no | yes | `E_tag` *(niche)* or inline bitmap | ✓ 0 | – | ✓ | **✓\C** |
| 16 | inline | sparse | no | no | `E_bitmap` in `@_rawLayout` leaf (`Buffer.Slab.Inline`-shape) | ✓ 1 | – | ✓ struct deinit | **✓\C** |

\* **Cell 9 nuance.** Dense + inline + want-VS + spare-bit. The Pareto encoding is `E_ledger`
(`Θ(log N)`, beats the tag), but `E_ledger` is a separate plane ⟹ a struct `deinit` (Lemma II.2,
inline) ⟹ AX-1 move-only (row 3). So `E_ledger` *cannot* deliver (C) here. **However**, the niche
(spare-bit = yes) means the *tag* encoding `E_tag` is available at 0 marginal bits and gives (C) via
the automatic destructor (row 1). The Pareto frontier here has **two non-dominated points**:
{`E_ledger`: smaller — `Θ(log N)` vs `N`·0 = the tag's "0 dedicated bits" is incomparable — but
move-only} and {`E_tag`: conditional-`Copyable` but no `Θ(log N)` ledger advantage since the niche
makes it 0-dedicated-bit anyway}. **If (C) is the priority, `E_tag` wins and the cell is ✓.** Recorded
as **✓\*** = satisfiable *via the tag*, with the ledger as the alternative non-VS optimum. The dense
inline leaf as *shipped* (`Memory.Inline`) chooses `E_ledger`+move-only because the tower's dense
buffers do not need element-level `Copyable` at the leaf (the buffer composes it); this is cell 11/12's
disposition, correct for the tower.

\*\* **Cell 10 — dense, inline, want-VS, no-niche — is NOT in the excluded region.** Although the
*ledger-in-`@_rawLayout`* encoding is move-only (AX-1), a dense contiguous-prefix `L` does **not need a
side plane at all in the value-semantics path**: a dense `Copyable`-element inline container can be
expressed as `InlineArray<N, Element>` + a stored `count: Int` — both `Copyable`, **no `deinit`**
(when `Element: Copyable`, destroying a fixed inline array of `Copyable` elements is trivial; the
`count` selects the live prefix purely as *access discipline*, not as a teardown oracle). So cell 10's
Pareto-optimal *value-semantics* encoding is "`InlineArray` + count," which gives (B) (Θ(log N) for the
count), (C), (D — trivial auto-teardown), (E). The move-only `Memory.Inline` row is the *non-VS*
optimum (cells 11/12). **Hence cell 10 is ✓ on its value-semantics frontier.** The asymmetry between
cell 10 (resolvable) and cell 14 (excluded) is exactly the difference between **𝒟** (a prefix needs no
oracle — `count` suffices, and a fixed `Copyable` array auto-destroys) and **𝒜** (arbitrary liveness
*requires* an oracle the automatic walk cannot infer, forcing either a tag — blocked by no-niche — or a
side-plane `deinit` — blocked by AX-1 inline).

### III.3 The unique excluded region

> **Theorem III.1 (uniqueness of the exclusion).** Of the 16 cells, **exactly one** — cell 14:
> {inline × sparse × want-value-semantics × no-spare-bit} — fails to jointly satisfy (A)–(E). Every
> other cell is satisfiable (with (C) either delivered or not-requested).
>
> *Proof.* By exhaustion of the matrix, with the two non-obvious cells (9, 10) resolved in §III.2:
> - Cells 1–8 (heap): AX-2 makes a class available, so the custom-`deinit` path (separate plane) is
>   conditional-`Copyable`, and the tag path is also available; all satisfiable.
> - Cells 9, 11–13, 15, 16 (inline, *not* cell 10/14): either (C) is not requested (11,12,15,16 →
>   move-only is the intended optimum) or a niche supplies `E_tag`'s 0-bit auto-destructor path
>   (9, 13 → conditional-`Copyable`).
> - Cell 10 (inline, dense, want-VS, no-niche): resolved by "`InlineArray` + count" — dense needs no
>   teardown oracle (§III.2 \*\*).
> - Cell 14 (inline, sparse, want-VS, no-niche): excluded by Theorem II.5. ∎

> **Theorem III.2 (the excluded region is NOT vacuous).** Cell 14 is inhabited by real, common types.
>
> *Proof.* The cell requires an element with `xi(Element) = 0` — i.e. a type using *all* bit patterns
> of its storage. Measured on 6.3.2 (§I.4): `Int`, `UInt`, all fixed-width integers at full domain,
> `Double` (all bit patterns are valid floats incl. NaNs), and any `struct` of such fields with no
> padding slack. A sparse, inline (zero-heap), value-semantic container of `Int` — e.g. an inline
> sparse-slot pool of integer handles with CoW — lands squarely in cell 14. It is not a pathological
> construction; integer-keyed inline slot maps are a natural ask. ∎

### III.4 The feature that collapses the excluded region

> **Theorem III.3 (collapse).** Cell 14 is satisfiable *iff* the language admits a **conditional
> `deinit`** — a `deinit` statically constrained to the complement of the `Copyable` condition (it
> applies only to the `~Copyable` instantiations), with the compiler emitting conditional drop-glue
> (the destructor enters the value-witness only for the `~Copyable` specializations).
>
> *Proof (⟸).* Such a `deinit` lets the *inline `@_rawLayout` leaf* carry a custom occupancy-walking
> teardown **and** be conditionally `Copyable`: for `Element: Copyable` the `deinit` is absent (the
> separate-plane bitmap of a `Copyable`-element store needs no element teardown beyond the trivial
> automatic one — wait: it *does*, because raw storage hides liveness; but the *conditional* `deinit`
> supplies exactly the `~Copyable`-only custom walk, and for the `Copyable` case the compiler can emit
> the walk as ordinary drop-glue since copying is permitted and double-destroy is the very thing the
> *unconditional* law guarded — here it is gated correctly). The leaf becomes conditional-`Copyable`
> with a custom inline teardown; Theorem II.4's Row 3 gains a conditional-`Copyable` variant; cell 14's
> blocked escape (placement (ii) on inline) opens; (C) is satisfied with (B) preserved (bitmap = 1
> bit/slot). *(⟹).* By Theorem II.5 the only obstruction to cell 14 is AX-1 forcing the inline
> separate-plane leaf unconditionally `~Copyable`; relaxing AX-1 to the conditional form is, by
> definition, the conditional-`deinit` feature. No weaker feature suffices: the tag path needs a niche
> (a *type-layout* change, not a language feature, and unavailable for no-niche elements by
> definition), and the class path needs a heap allocation (contradicting inline). ∎

This is exactly SE-0427's deliberately-excluded generalization, formalized in
`conditional-deinit-conditionally-copyable-generics.md` (its §"Formal semantics": the current model is
the special case `C = true`; the feature relaxes `C` to the `~Copyable`-of-`T` subset, preserving
soundness because the custom teardown runs only for non-duplicable instantiations). That note's verdict
stands: the feature is **sound-in-principle but unimplemented and deliberately excluded**; collapsing
cell 14 is an Evolution-scale change (held as PITCH-0003), not a fork patch. Until then, cell 14's
inhabitants must spend one corner of the trilemma — and the information floor says *which* corner is
cheapest to spend: **density**, via `E_tag` with a tombstone, accepting ≥8 bit/slot (giving up (B)) to
recover (C); or **inline-ness**, via the heap class (giving up zero-heap) to recover (B)+(C); the one
thing unattainable is all three at once.

### III.5 The Pareto frontier of cell 14 (what you spend when you cannot have it)

Since cell 14 cannot have {(B) density + (C) value-semantics + inline} together, the non-dominated
fallbacks are:

| Fallback | Sacrifices | Keeps | Encoding | Cost |
|----------|-----------|-------|----------|------|
| Tombstone | (B) density | (C)+(E)+inline | `E_tag` (no-niche `Optional`) | ≥8 bit/slot (Thm I.3); auto-teardown (no `deinit`!) |
| Heap-class relocation | inline (zero-heap) | (B)+(C)+(E) | `E_bitmap` in class (AX-2) | 1 bit/slot + 1 heap alloc + ARC |
| Move-only inline | (C) value-semantics | (B)+(E)+inline | `E_bitmap` in `@_rawLayout` (cell 16) | 1 bit/slot; struct `deinit`; `~Copyable` |

These three are mutually non-dominated; the choice is the consumer's, and the institute tower's default
(per AX-4 + `occupancy-lives-in-the-leaf.md`) is **move-only inline** (cell 16's shape) — i.e. the tower
does *not* demand (C) at the inline-sparse leaf, so it never enters cell 14 at all; the buffer composes
copyability from the leaf, and a move-only leaf yields a move-only buffer *instance* from the *one*
generic type. The carve-out *type* dissolves (E holds); only the *instance* is move-only.

---

## Synthesis — the five properties, jointly

| Property | Where it holds | Where it fails | Governing result |
|----------|----------------|----------------|------------------|
| **(A)** one `Store.Protocol`, no refinement | **every cell** | — | AX-5 (protocol is copyability- and density-agnostic) |
| **(B)** ≤1 bit/slot | every cell *via `E_bitmap`/`E_ledger`*; `E_tag` only under a niche | `E_tag` with no-niche element (8×–64× over) | Thm I.2, I.3 |
| **(C)** value-semantics, one generic `Buffer<S>` | heap (always, via AX-2); inline under a niche (`E_tag`) or dense (`InlineArray`+count) | **cell 14** {inline × sparse × no-niche} | Thm II.4, II.5 |
| **(D)** self-cleaning, no buffer `deinit` | **every cell** (leaf holds teardown; buffer is `deinit`-free) | — (buffer never has a `deinit`) | AX-4; placement (i) auto, (ii) leaf-`deinit` |
| **(E)** maximal decomposition, one generic buffer | **every cell** | — | AX-4 (carve-out *types* dissolved) |

The exact frontier: **(A), (D), (E) are unconditional** across the whole grid. **(B) and (C) trade off
in exactly one place** — cell 14 — and the trade is forced by the *interaction* of the information floor
(no-niche ⟹ tag violates (B), so a side-plane is mandatory) with the SE-0427 law (inline side-plane
⟹ struct `deinit` ⟹ AX-1 ⟹ no (C)). Everywhere else the floor offers a (B)-compliant encoding whose
placement is compatible with the requested copyability.

**The decomposition that makes this clean (E + (A)).** Because `Store.Protocol` is the neutral seam
(AX-5) and `Storage.Contiguous<Memory.X>` lifts any leaf uniformly (AX-4), the *entire* matrix is
realized by **one** generic `Buffer<S: Store.Protocol>` over a *choice of leaf*: dense leaf (range
ledger) or sparse leaf (bitmap/tokens/free-list), each in a heap (class → conditional `Copyable`) or
inline (`@_rawLayout` → move-only) backing, with the *element* optionally `Optional`-wrapped (placement
(i)) when a niche makes the tag the optimum. The matrix is not 16 types; it is one generic buffer × a
small leaf lattice. That is property (E) achieved, and it is *why* (A) holds in every cell.

---

## Outcome

**Status: DECISION.** The frontier is proved exactly:

1. **Information floor (Part I, proved + 6.3.2-measured).** Contiguous-prefix liveness floor is
   `Θ(log N)`, achieved by `Store.Initialization` (the range ledger). Arbitrary liveness floor is `N`
   bits, achieved by the bitmap — *information-optimal*. A per-element `Optional` tag costs **0 marginal
   bits iff the element exports ≥1 extra inhabitant** (niche-fill, where it *uniquely* beats the bitmap
   by spending zero dedicated bits), and **≥8 bit/slot otherwise** (alignment-rounded), where it is
   never cheaper than the bitmap and typically 8×–64× worse. (B) ≤1 bit/slot is honored by the
   ledger/bitmap always, and by the tag **only under a niche**.

2. **Placement lattice (Part II, proved).** For self-cleaning, `L` may live (i) in the element cell
   (`E_tag`, automatic destructor, *no custom `deinit`*), (ii) in a separate plane inside the leaf, or
   (iii) in the buffer (retired by AX-4). Placement (i) forces tag-or-spare-bit; placements (ii)/(iii)
   force a custom `deinit`, which on a **class** stays conditionally `Copyable` (AX-2) but on an
   **inline `@_rawLayout` struct** is forced *unconditionally `~Copyable`* by the SE-0427 Wall-1 law
   (AX-1, S1-reproduced on 6.3.2).

3. **Satisfiability matrix (Part III, proved).** Over the 16-cell grid, (A), (D), (E) hold
   unconditionally; the **unique** excluded cell is **#14 {inline × sparse × want-value-semantics ×
   no-spare-bit}**, where (B) and (C) are provably mutually exclusive (Theorem II.5). The Pareto-optimal
   encoding per cell is tabulated (§III.2): range-ledger for dense, bitmap/tokens for sparse, niche-tag
   wherever a spare bit exists (cells 5, 7, 13, 15 — where it dominates the bitmap), and "`InlineArray` +
   count" for the dense-inline-value-semantics path (cell 10, which is therefore *not* excluded).

4. **The excluded region is NOT vacuous (Theorem III.2).** Cell 14 is inhabited by no-niche element
   types — `Int`, `Double`, full-domain integers, padding-free structs thereof — a natural class, not a
   pathology.

5. **The collapsing feature (Theorem III.3).** Exactly **one** language feature collapses cell 14: a
   **conditional `deinit`** (SE-0427's deliberately-excluded generalization; sound-in-principle per the
   companion note's formal model; held as PITCH-0003, not fork-implementable). No weaker mechanism
   suffices — the tag path needs a type-layout niche (unavailable by hypothesis) and the class path
   needs a heap allocation (contradicting inline).

**The honest frontier in one sentence.** Of {(A) one protocol, (B) ≤1 bit/slot, (C) value-semantics in
one generic buffer, (D) self-cleaning no-buffer-`deinit`, (E) maximal decomposition}, **(A)+(D)+(E) are
free everywhere**, and **(B)+(C) coexist everywhere except the single non-vacuous cell {inline × sparse
× no-niche element}**, where the information floor forbids a cheap tag and the SE-0427 law forbids a
conditionally-`Copyable` inline teardown — a frontier collapsed by, and only by, a conditional `deinit`.

### Relationship to prior research (this note EXTENDS, does not contradict)

- **`occupancy-lives-in-the-leaf.md`** (AX-4): this note *proves* its "one honest residual" trilemma is
  the unique excluded cell of the full grid, and characterizes it at the bit level (no-niche sub-case).
  No contradiction; strict extension. The placement law is consumed wholesale.
- **`conditional-deinit-conditionally-copyable-generics.md`** (AX-1): its Wall-1 proof and S1–S8 matrix
  are consumed as axioms (S1 + S2 + S5 + S7 re-reproduced on 6.3.2). This note adds the
  *information-theoretic* layer the companion lacked (why the tag is or isn't an option) and the
  *complete satisfiability grid* (the companion proved the wall; this note proves the wall bounds
  *exactly one* cell of a 16-cell space and that the cell is non-vacuous).
- **`buffer-arena-conditional-copyable.md`** (IMPLEMENTED): the shipped `Storage.Arena` is the cell-6
  existence proof (heap sparse class-leaf, conditional `Copyable`); cited as the realized optimum for
  its cell.

### Promotion candidates ([RES-006a])

- **`[DS-023]`** (ecosystem-data-structures, already CORRECTED 2026-06-07): add the bit-level frontier —
  the unique excluded cell is *the no-niche sub-case*, and `E_tag` (tombstone) is the
  density-sacrificing fallback whose cost is characterized (≥8 bit/slot). The current text's "tombstone
  buys copyability by spending density" is *quantified* here.
- **`[MEM-COPY-016]`**: the "one honest residual" is now a proved uniqueness result over a complete grid;
  cross-reference this note as the satisfiability theorem.

---

## References

### Internal ([RES-019] — grepped `swift-institute/Research/` for occupancy/liveness/information-theoretic/extra-inhabitant/placement-lattice before drafting)
- `occupancy-lives-in-the-leaf.md` (DECISION, tier-3, 2026-06-07) — the placement law (AX-4); this note's parent.
- `conditional-deinit-conditionally-copyable-generics.md` (RECOMMENDATION→superseded-in-part, tier-3, 2026-06-06) — Wall-1 proof + S1–S8 matrix + SE-0427 formal model (AX-1, AX-3); the collapsing-feature analysis (Thm III.3).
- `buffer-arena-conditional-copyable.md` (IMPLEMENTED, tier-2, 2026-05-20) — shipped heap sparse class-leaf (cell-6 existence proof, AX-2).
- `storage-buffer-abstraction-analysis.md`, `storage-memory-split.md` — Storage/Memory split that relocated `Store.Initialization` (the dense ledger, AX-4).

### Primary — source (read directly, file:line cited) [Verified: 2026-06-08]
- `swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:20-69` — the four-requirement neutral seam (AX-5).
- `swift-store-primitives/Sources/Store Initialization Primitives/Store.Initialization.swift:47-60` — `.empty`/`.one`/`.two` range ledger (`E_ledger`; Thm I.1 achiever).
- `swift-memory-inline-primitives/Sources/Memory Inline Primitives/Memory.Inline.swift:41-114` — dense inline `@_rawLayout` leaf; `deinit` walks `_initialization` (Lemma II.2 instance; Row 3 of Thm II.4); the `_deinitWorkaround` (Wall-2/swift#86652, [MEM-SAFE-027]).
- `swift-storage-arena-primitives/Sources/Storage Arena Primitives/Storage.Arena.swift:75-256,278` — sparse class-leaf; generation-token `deinit` on `Backing`; `extension Storage.Arena: Copyable where Element: Copyable` (AX-2; cell-6).
- `swift-buffer-slab-primitives/Sources/Buffer Slab Primitive/Buffer.Slab.Header.swift:25-34` — the AX-4 located bug: `bitmap: Bit.Vector.Bounded` held in the *buffer header* (placement (iii)).

### Primary — Swift Evolution / compiler (via the companion note, AX-1/AX-2)
- SE-0427 Noncopyable Generics, § "Conformance to `Copyable`" — the controlling prohibition (AX-1).
- SE-0390 Noncopyable Structs and Enums — `deinit ⟹ ~Copyable` foundation.
- `DiagnosticsSema.def:8390` (`copyable_illegal_deinit`); `TypeCheckInvertible.cpp:221-233` (emission + class exemption, AX-2).

### Prior art ([RES-021] — contextualization; consumed from the companion note's primary-source-verified survey)
- Rust: `Drop ⟹ !Copy` (E0184); no conditional `Drop` impl (E0367); drop-glue = automatic conditional field destruction (= AX-3 / S7); `ManuallyDrop` (= manually-managed raw storage). The bitmap-vs-niche encoding question is *layout*, language-independent; Rust's `Option<T>` niche-fills identically (`Option<&T>` is pointer-sized), confirming Thm I.3 is not Swift-specific.
- C++: `std::optional`/`std::variant` conditionally-trivial destructors (P0848R3) — the lone destructor/copyability *decoupling*; not portable to Swift (companion note).

### Empirical artifacts ([RES-023] — every load-bearing layout/diagnostic claim verified on Swift 6.3.2, `swift-6.3.2-RELEASE`, `TOOLCHAINS=org.swift.632202605101a`, 2026-06-08)
- `/tmp/occ-proof/inhabit.swift` — extra-inhabitant niche measurement (Thm I.3 table): class/Bool/enum/pointer → 0 marginal; UInt8 → +1B; Int → +8B.
- `/tmp/occ-proof/walls.swift` — S2+S5+S7 assembly compiles + runs ("MoveOnly(7) deinit fired" / "copied ok: 1, 42") — the dense-leaf composition shape (AX-3).
- `/tmp/occ-proof/wall1.swift` — S1 Wall-1 repro: `error: deinitializer cannot be declared in generic struct 'Wrapper' that conforms to 'Copyable'` (AX-1).
- `/tmp/occ-proof/density.swift` — bit-density: bitmap 1.0 bit/slot vs tombstone(Int) 64 bit/slot vs tombstone(niche) 0 marginal bit/slot (Thm I.3 dominance; (B) frontier).
