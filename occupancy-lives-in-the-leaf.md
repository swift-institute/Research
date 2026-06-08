# Occupancy Lives in the Leaf — the Buffer-Tower Placement Law

<!--
---
version: 1.0.0
last_updated: 2026-06-07
status: DECISION (ratified by the principal, 2026-06-07)
tier: 3
scope: ecosystem-wide
supersedes_in_part:
  - conditional-deinit-conditionally-copyable-generics.md  # the "permanent carve-out / converged equilibrium" conclusion
  - decomposition-layer-placement-package-map.md           # §C.3 "hard-floor KEEP" for the sparse-inline carve-outs
corrects:
  - "[DS-023]"        # ecosystem-data-structures — "the concrete .Inline variant is forced"
  - "[MEM-COPY-016]"  # memory-safety — "the inline third corner — a forced concrete variant"
---
-->

## The Law

> **Liveness tracking and element teardown live in a single-allocation leaf — never in the Buffer.**
> Dense leaves track liveness as a contiguous range-ledger (`Memory.Tracked`); sparse leaves track it
> per-slot (bitmap / generation / free-list), SoA within the one allocation they own. **A Buffer never
> carries an element-teardown `deinit`** — it is a thin generic over a leaf, carrying only the *access
> discipline* (count / cursor / indices / links). `Storage.Contiguous<Memory.X>` lifts dense and sparse
> leaves uniformly. **There is no `Storage.Sparse` wrapper, no `.Inline`/`.Small` Buffer
> types (the occupancy carve-outs; `.Bounded` is a separate *capacity* axis, already lawful — retained),
> and no raw allocator as a Buffer backing.** Copyability flows from the leaf: a move-only
> `@_rawLayout` inline leaf yields a move-only buffer instance; a class-backed heap leaf yields a
> conditionally-`Copyable` one — from *one* generic Buffer type.

## Why this is the law: the dense side already proved it

The dense disciplines have **no carve-outs** — `Buffer.Linear.Inline` and `Buffer.Ring.Inline` were
correctly dissolved — because liveness + teardown live in the **leaf**:

- `Memory.Inline<E,n>` carries its range-ledger **and** the `deinit` that walks it. It is move-only
  *because* of that `deinit`.
- `Memory.Heap<E>` carries them on its backing **class**, so it is conditionally-`Copyable`.
- `Buffer.Linear<Storage.Contiguous<Memory.X>>` is a thin generic with **no `deinit`** → no Wall-1, no
  carve-out. Copyability flows from the leaf.

The sparse disciplines carry carve-outs for exactly one reason: **the occupancy oracle was put in the
Buffer instead of the leaf.** `Buffer.Slab` holds the bitmap in its own header — *"Buffer.Slab.Bounded
is unconditionally ~Copyable (Bit.Vector in the header is ~Copyable)"*
(the oracle is `swift-buffer-slab-primitives` `Buffer.Slab.Header.swift:27` bitmap + `Buffer.Slab.swift:53-57`
Box `deinit`; the `swift-slab-primitives/.../Slab.swift:57-58` line just describes it). Buffer-held occupancy
⟹ buffer-level `deinit` ⟹ Wall-1 ([MEM-COPY-016]) ⟹ a forced concrete `.Inline` type. Move the oracle into the leaf —
where dense already keeps it — and the buffer needs no `deinit`, so the carve-out dissolves for the *same
reason* dense's did.

**The existence proof for the sparse case already ships:** `Storage.Arena` is a single-allocation sparse
leaf (one `Memory.Arena` allocation, SoA `[Meta | elements]`, teardown on its Backing class —
`swift-storage-arena-primitives/Sources/Storage Arena Primitives/Storage.Arena.swift:52`). `Buffer.Arena`
over it is generic with **no element `deinit`**. The bit-dense (`Buffer.Slab`) and free-list
(`Buffer.Linked`) disciplines are the same shape with a different in-leaf occupancy representation.

## The three questions this answers

1. **Is regrouping `Storage.Pool` → `Storage.Sparse.Pool` the fix?** No — cosmetic. It does not move the
   *bitmap*, which is the thing in the wrong place. The fix is relocating the occupancy oracle from the
   buffer into the leaf.
2. **Can sparse have the `Storage.Contiguous<Memory.X>` shape?** Yes, identically — where `Memory.X` is a
   *sparse* leaf (per-slot occupancy) instead of a dense one (range-ledger). Same lift, same buffer
   genericity, **bit-density preserved** (the bitmap is 1 bit/slot, inside the leaf's single allocation).
3. **Is "sparse" a Storage-layer concern, or more foundational?** More foundational: it is a
   *single-allocation leaf* property — the same tier the dense range-ledger already lives at
   (`Memory.Tracked`, carried by `Memory.Inline`). The access *discipline* (links / cursor / index) stays
   at the Buffer. There is no `Storage.Sparse`. (`Storage.Arena` is structurally such a leaf today; its
   `Storage.*` vs `Memory.*` filing is a deferred naming pass, not a layer question.)

## What this supersedes — and why the prior conclusion was wrong

The tier-3 note `conditional-deinit-conditionally-copyable-generics.md` rigorously proved that a
**custom conditional `deinit` on a conditionally-`Copyable` generic is impossible** (Wall-1; SE-0427;
Rust E0184/E0367). That proof is **correct and stands.** But the note answered the wrong question. It
asked *"can the **Buffer** carry a conditional `deinit`?"* (no) and concluded the `.Inline` carve-out is
a permanent "converged equilibrium." It never asked *"why does the Buffer carry a `deinit` at all, when
the dense Buffer does not?"* Its own probe matrix already holds the answer: **S2** (unconditional
`~Copyable` generic + `deinit` compiles → a move-only leaf is fine) plus **S5** (conditional-`Copyable`
generic with **no** `deinit` compiles → the buffer over that leaf is fine). Assemble S2 + S5 — put the
`deinit` in a move-only *leaf*, make the buffer a no-`deinit` generic — and the wall is moot. **S8 ("no
struct-only escape") does not apply**: it fails a wrapper that *claims* `Copyable` while holding a
concrete unconditionally-`~Copyable` field; our `Buffer.Slab<S>` holds the generic `S` and is simply
*not* `Copyable` when `S` is the move-only leaf (the standard S5 pattern, which compiles).

It also supersedes the **D2 seam** and the `PoolStorage` shape (below). The decomposition map's §5.4
*instinct* — "occupancy is the leaf's axis; dissolve `Storage.Pool`/`Storage.Arena` toward the leaf" —
was right; D2's *execution* (make `Memory.Pool` raw, push typed-slot access into the buffer) was wrong,
and that is what forced `PoolStorage` into existence.

## `PoolStorage` post-mortem (against the law)

`PoolStorage` (`swift-buffer-linked-primitives/.../PoolStorage.swift`, uncommitted) was a **wrapper that
re-typed a raw `Memory.Pool`** inside the buffer module — structurally the deleted `Storage.Pool` typed
façade, re-manufactured. It violated the law two ways: (1) a **raw allocator as the buffer backing**
(raw slots ⟹ hand-deinit ⟹ a buffer `deinit`), and (2) a **wrapper to fake a typed leaf**. The lawful
form is a genuine typed sparse **free-list leaf** (one allocation, in-band or SoA free-list, teardown on
its own Backing/struct) — parallel to `Storage.Arena` — over which `Buffer.Linked` is a thin generic.
The drift was structurally inevitable under an un-pinned law plus a "dissolve now" mandate; the law makes
it impossible.

## Placement matrix (end-state)

| Concept | End-state form | Change |
|---|---|---|
| **Dense leaves** | `Memory.Heap` (class, cond-Copyable) · `Memory.Inline` (`@_rawLayout`, move-only) · `Memory.Small` — range-ledger + teardown in the leaf | keep |
| **Sparse leaves** | single-allocation leaf carrying per-slot occupancy + teardown, conforming the existing `Store.\`Protocol\``; occupancy is **concrete leaf state** (not a protocol): bitmap (Slab) · generation (Arena) · free-list (Pool/Linked); backing heap class-backed → cond-`Copyable`, inline → `InlineArray<n, Slot<E>>` (value-semantics, niche-dense) or `@_rawLayout`+bitmap (move-only, bit-dense) | `Storage.Arena` keep (the model); Slab-leaf relocate bitmap **out of the buffer**; Pool/free-list leaf **restore** (the lawful form `PoolStorage` was faking) |
| **Buffers** `Slab`/`Linked`/`Arena` | one generic each over the sparse leaf; **no `deinit`**; discipline only (links/index/cursor) | **dissolve `.Inline`/`.Small` types** (keep `.Bounded` — capacity axis); delete `PoolStorage`/`NodeStorage` + the D2 raw-`Memory.Pool`-in-buffer |
| **Buffers** `Linear`/`Ring` | already lawful (dense leaf, thin generic) | keep |
| **`Storage.Contiguous<Memory.X>`** | lifts dense **and** sparse leaves uniformly | keep / extend |
| **`Memory.Pool` / `Memory.Arena` (raw)** | explicit-allocation tools and/or a leaf's internal allocator — **never a Buffer backing** | demote |
| **`Storage.Pool` (the old façade)** | stays deleted; its responsibility is the new typed free-list **leaf** | — |
| **ADT location variants** (`List`/`Queue.Linked.{Inline,Small}`, `Tree.N.{Inline,Small}`, `Bitset.Small`) | dissolve — consumers compose the one generic buffer over the chosen leaf | delete |

## The one honest residual

A bit-dense **inline** sparse leaf has a `deinit` (walk the inline bitmap) → it is **move-only**, so
inline-sparse *buffers* are move-only. That is fine — dense inline buffers already are, and the carve-out
**type** still dissolves (copyability flows from the leaf). The only thing unattainable is *bit-density +
value-semantics + inline simultaneously* — the tombstone (`Element?`) form buys copyability by spending
density. That trilemma is the real irreducible core: one corner's copyability, **not** a type explosion — and the
5-angle panel proved it **vacuous in practice** (no real consumer inhabits it; see Composition below).

## Composition: one protocol; occupancy is concrete leaf state (revised 2026-06-08)

A five-angle research panel (`occupancy-encoding-{1..5}-*.md`, all spiked on Swift 6.3.2) explored the encoding and
proved the boundary. The conclusion — after a wrong turn through a `Store.Sparse.Protocol` *refinement*, then a
`Store ⊗ Occupancy` *capability-conjunction protocol* (both **withdrawn** 2026-06-08): **add no occupancy protocol
at all.** The shipping system never used one.

- **One protocol — the existing `Store.\`Protocol\`` — and occupancy is concrete leaf state, not a capability.** A
  sparse leaf is a **concrete type** that *holds* its occupancy (a `Bit.Vector` bitmap / in-band free-list /
  generation tokens) plus the teardown `deinit`, and conforms the **existing** 4-op `Store.\`Protocol\``.
  `allocate`/`free`/`isOccupied` are **concrete methods** on the leaf, not protocol requirements. `Buffer<S:
  Store.\`Protocol\`>` is the one generic buffer (no element `deinit`); its occupancy ops **pin the concrete leaf**
  (`where S == Storage<E>.Slab`). **Verified shipping:** `Buffer.Arena` already does exactly this —
  `Storage.Arena: Store.\`Protocol\`` (`Storage.Arena+Store.Protocol.swift:109`) + 53 `where S == Storage<E>.Arena`
  call-sites, **zero occupancy protocol**. So the carve-out dissolves with **one protocol total** and **no new
  namespace**. *Why no protocol:* a second protocol meaning "this leaf is sparse" is abstraction the shipping system
  does not use; namespace-nesting a non-`Store` capability under `Store` was a smell; and nothing generic dispatches
  over "any sparse leaf" (each buffer pins its concrete leaf — YAGNI). Shared occupancy logic, where any, is a
  **concrete component** (`Bit.Vector`, a free-list helper), never a protocol.
- **Value-level composition uses the *binary* product/coproduct (both `~Copyable`-capable):** `Pair<First: ~Copyable…,
  Second: ~Copyable…>` and `Either<Left: ~Copyable…, Right: ~Copyable…>` carry `~Copyable` (conditional `Copyable`
  when both are) — use them, plus the bespoke `Storage.Split` (dual-plane) and a `Memory.Small`-style enum (SBO), for
  value-level composition. The **variadic** `Product<each Element>` (parameter-pack) and `Coproduct<each Element>`
  (enum-with-pack) do **not** yet carry `~Copyable` (a language constraint) — do not reach for them in the tower.
- **Teardown is a theorem of the composition**, not a hand-written buffer `deinit`: it factors through the leaf's
  value-witness (cell `Optional` self-clean) or the leaf's own `deinit`. Wall-1 is avoided by assembling S2 + S5,
  never S1.

### The proven boundary — and it is vacuous
The full satisfiability matrix (Angle 4) proves **(A) single `Store.\`Protocol\``, (D) self-cleaning, (E)
decomposition hold unconditionally**, and **(B) bit-density ⊥ (C) value-semantics in exactly ONE cell:
{inline × sparse × want-value-semantics × no-spare-bit scalar}** (e.g. a copyable inline slab of raw `Int`). Two
independent walls fuse there — SE-0427 `deinit ⟹ ~Copyable` **and** `@_rawLayout`-cannot-be-`Copyable` (Angle 3) —
and the single feature that collapses it is a conditional `deinit` (PITCH-0003). The cell encoding makes it nearly
free in practice: `Slot<E> = Optional<E>` is **0-marginal-bit** whenever `E` exposes an extra inhabitant (class
refs, enums, `Bool`, pointers, indices, anything nesting them — Angle 1), and `InlineArray<n, Slot<E>>` is the
conditionally-`Copyable` inline leaf (Angle 3). The tag is paid only by no-spare-bit scalars — exactly the excluded
cell — and the consumer census (Angle 5; ADT-tier `Linked.{Inline,Small}` types verified **gone**, live sparse
consumers all heap-backed) finds **no inhabitant** of it. **So all of A–E hold for every real consumer; the
residual is provably vacuous.**

## Implementation (bottom-to-top; active-prune)

1. **Leaves (bottom).** **No new protocol.** Sparse leaves conform the **existing** `Store.\`Protocol\``; occupancy
   is **concrete leaf state** (bitmap / free-list / generation + the teardown `deinit`), exactly the `Storage.Arena`
   shape. Buffers pin the concrete leaf (`where S == Storage<E>.Slab`) for occupancy ops — the shipping `Buffer.Arena`
   pattern, zero occupancy protocol. The **inline**
   sparse leaf is the gating build — confirm it compiles + tears down (incl. cross-module, with the
   `[MEM-SAFE-027]` `_deinitWorkaround` for Wall-2/`#86652`) on **Swift 6.3.2**; STOP + minimal repro on
   any wall (no wall claim without a repro).
2. **Buffers (middle).** Reshape `Buffer.{Slab,Linked,Arena}` to thin generics over the leaves; **delete**
   the `.Inline`/`.Small` types (keep `.Bounded` — a capacity axis), `PoolStorage`/`NodeStorage`, the D2
   raw-pool path, the §C.3 banners.
3. **ADTs (top).** Dissolve the location variants; demote raw `Memory.Pool`/`Arena` to explicit-only.
4. Build + test each layer on 6.3.2 before the next. No backwards-compat shells.

Wall-2 (`swiftlang/swift#86652`, cross-package `@_rawLayout` deinit-skip) is unchanged by this law and
remains governed by [MEM-SAFE-027]; it is a codegen caveat, not a design constraint.

## References

- **Dense precedent (proof):** `swift-memory-inline-primitives` `Memory.Inline` (move-only leaf + range
  deinit); `swift-buffer-linear-primitives` `Buffer.Linear` (generic, no carve-out).
- **Sparse precedent (proof):** `swift-storage-arena-primitives` `Storage.Arena.swift:52` (single-alloc
  sparse leaf, Backing-class teardown); `Buffer.Arena` (generic, no element deinit).
- **The bug, located:** `swift-buffer-slab-primitives` `Buffer.Slab.Header.swift:27` (bitmap) +
  `Buffer.Slab.swift:53-57` (Box `deinit` walking it) — occupancy held in the buffer.
- **Superseded:** `conditional-deinit-conditionally-copyable-generics.md` (the Wall-1 proof stands; the
  "permanent carve-out" conclusion is withdrawn); `decomposition-layer-placement-package-map.md` §C.3.
- **5-angle panel (2026-06-08, verified):** `occupancy-encoding-1-adt-cell-layout.md` (niche / extra-inhabitant
  density); `-2-category-theory-composition.md` (`Store ⊗ Occupancy`; the refinement-is-unnecessary proof);
  `-3-swift-typesystem-mechanisms.md` (the second `@_rawLayout` wall; `InlineArray`; macro limits);
  `-4-placement-proof.md` (information floor + satisfiability matrix); `-5-prior-art-and-vacuity.md` (cross-language
  + the vacuity census).
- **Corrected skills:** [DS-023] (ecosystem-data-structures), [MEM-COPY-016] (memory-safety).
- **Still valid:** [MEM-SAFE-027] (Wall-2 `_deinitWorkaround`); [MEM-COPY-016]'s triangle + one-truth-holder
  invariant + the *heap* class-boundary mechanism (only its "inline third corner = forced" clause is wrong).
