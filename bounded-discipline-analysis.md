# Bounded Discipline Analysis

<!--
---
version: 1.0.0
last_updated: 2026-06-23
status: RECOMMENDATION
tier: 2
scope: cross-package
packages: [swift-finite-primitives, swift-buffer-linear-primitives, swift-buffer-ring-primitives, swift-buffer-slab-primitives, swift-bit-vector-primitives, swift-list-linked-primitives, swift-stack-primitives, swift-pool-primitives, swift-column-primitives]
---
-->

## Context

A `.Bounded` type appears across ≥8 primitive packages. A first grep (handoff
`.handoffs/HANDOFF-bounded-proliferation.md`, 2026-06-23) showed `.Bounded` is
**not one concept**: an English-word collision masks at least two unrelated axes,
and within the capacity axis the bound-enforcement vocabulary is duplicated. This
is a class-(c) ecosystem question (re-implemented disciplines that should be
single-sourced — `feedback_name_conflicts_indicate_missing_reuse`): inventory +
one recommendation, no source edits.

This analysis sits **under** the already-ratified Decoupling Charter
(`[DS-025]`–`[DS-027]`, ratified 2026-06-18; rationale in
`adt-buffer-storage-decoupling-shape.md`, tier 3) and the occupancy DECISION
(`occupancy-lives-in-the-leaf.md`, ratified 2026-06-07). It is a consistency /
pattern-extraction pass (`[RES-014]`/`[RES-017]`) that confirms the bound already
originates at the buffer tier and isolates the residual duplication. It does **not**
re-open the Charter.

## Question

Per the dispatch, with per-package evidence:

1. **Homonym** — is `Finite`'s `.Bounded` a distinct axis (value-range, not
   capacity)? Recommend disambiguation.
2. **Type vs discipline** — are the per-container `.Bounded` *types* genuinely
   distinct (bounded ring ≠ bounded stack ≠ bounded list), hence NOT mergeable
   into one `Bounded<C>` wrapper?
3. **Mechanism duplication** — is the bound-enforcement (capacity field +
   reject-at-limit check + per-container `.Bounded.Error`) *copied* per container
   or *consumed* from a shared primitive? If copied, draft the shared primitive.
4. **Layering** — where does the bound *originate*? Flag any higher ADT that
   **re-implements** bounding instead of composing the bounded buffer beneath it.

## Method

READ-ONLY. All file:line claims verified against live source on 2026-06-23
(`[RES-023]`). `swift-buffer-slab-primitives` is mid-dissolution in a parallel
chat — read-only, and any slab claim is marked **in-flux / deferred**; no
recommendation gates on its transient internal state. Prior research grepped per
`[RES-019]`/`[HANDOFF-013]` (see *Prior Art*); this doc cites-and-extends, it does
not duplicate.

---

## Inventory — every `.Bounded`, Bucket A vs B

### Bucket A — value-range / finite-position (the homonym)

`swift-finite-primitives` uses "Bound", "Bounded", "Capacity" for a **value-range**
axis — a position/value provably in a compile-time range, with **`N` a value-generic**.
This is categorically not a runtime container capacity.

| Symbol | Site | Meaning | Verified |
|--------|------|---------|----------|
| `Finite.Bounded` (protocol) | `Finite Bounded Primitives/Finite.Bounded.swift:64-70` | Haskell `Bounded` typeclass: intrinsic `minBound`/`maxBound`; *"`Ordinal<5>` always has bounds 0..4"*. **Entirely commented-out**, pending value-generic `where N > 0` support — not a live symbol. | 2026-06-23 |
| `Ordinal.Finite<N>` | `Finite Bounded Primitives/Ordinal.Finite.swift`; defn at `Index.Bounded.swift:24` = `Tagged<Finite.Bound<N>, Ordinal>` | a position bounded by `N` (value-range `[0,N)`) | 2026-06-23 |
| `Index<Element>.Bounded<N>` | `Finite Bounded Primitives/Index.Bounded.swift:35` = `Tagged<Tag, Ordinal.Finite<N>>` | a **compile-time bounded index** in `[0,N)`; the *live* collision. Doc header even reads "Capacity-bounded index" (`:2`) — borrowing "capacity" words for a value-range concept. | 2026-06-23 |
| `Finite.Bound<N>` (tag) | `swift-finite-primitives` (`Index.Bounded.swift:24`) | phantom tag for the finite position | 2026-06-23 |

> **Three senses of "Bound(ed)" exist**, not two: (1) **capacity** (Bucket B);
> (2) **value-range position** (`Index<Element>.Bounded<N>`, `Ordinal.Finite<N>`,
> `Finite.Bound<N>`); (3) **min/max typeclass** (`Finite.Bounded`). Senses 2 and 3
> are the value-range axis the handoff calls "Bucket A". `N` is a value-*generic*
> for the value-range axis; the capacity axis stores a runtime `Index<Element>.Count`.

### Bucket B — capacity-bounded container family

One discipline: fixed capacity, *bound-is-the-contract*, mutation seams
reject/trap at the limit. Each ships its **own** overflow error.

| Type | Package | Storage / representation | Bound origin | Reject seam | Own `.Error` (case) | Verified |
|------|---------|--------------------------|--------------|-------------|---------------------|----------|
| `Buffer.Linear.Bounded` | swift-buffer-linear-primitives | `{ Header, S storage }` (`Buffer.Linear.Bounded.swift:13`) | `Header.capacity` (`Buffer.Linear.Header.swift:24-29`) — set to `storage.capacity`, the **PHYSICAL/rounded-up** value (`+Lifecycle.swift:20`) | `append() -> Element?` returns rejected (`+Lifecycle.swift:45`); builder throws (`+Builder.swift:42-43`) | `capacityExceeded` (`Error.swift:5`) | 2026-06-23 |
| `Buffer.Ring.Bounded` | swift-buffer-ring-primitives | ring (Cyclic Index dep, `Package.swift:53`) | `header.isFull` (`+Operations.swift:31`) | `if header.isFull { return element }` (`+Operations.swift:40,52`) — return-rejected | `capacityExceeded` (`Error.swift:5`) | 2026-06-23 |
| `Buffer.Slab.Bounded` | swift-buffer-slab-primitives **[IN-FLUX]** | sparse slab | (deferred — mid-dissolution) | (deferred) | `capacityExceeded` (`Error.swift:8`) | 2026-06-23 (error only) |
| `Bit.Vector.Bounded` | swift-bit-vector-primitives | packed bits + own `…Bounded.Capacity.swift`; **only dep is Index** (`Package.swift:67`) | own (leaf) | own (`+mutating`) | `bounds`/`invalidCount`/`overflow` (`Error.swift:17-19`) | 2026-06-23 |
| `Stack.Bounded` | swift-stack-primitives | `Shared<Element, Column.Bounded<Element>>` + own `requestedCapacity` (`Stack.Bounded.swift:106,113`) | composes `Column.Bounded` (= `Buffer.Linear.Bounded`) **AND** stores own `requestedCapacity` | `push`: `guard _buffer.count < requestedCapacity → .overflow` THEN buffer `append`, `guard rejected == nil → .overflow` (`Stack.Bounded ~Copyable.swift:60-77`) | `overflow` (`Error.swift:28-30`) | 2026-06-23 |
| `List.Linked.Bounded` | swift-list-linked-primitives | `_buffer: Buffer.Linked` (pool-backed; `Package.swift:48`); **no `Buffer.Linked.Bounded` exists** | `_buffer.isFull` — **delegated to the pool-backed buffer** (`List.Linked.Bounded.swift:31`) | `guard !isFull → .overflow` then `try! _buffer.insert.…` (`:44-46`, `:55-57`) | `__ListLinkedBoundedError { overflow, empty }` (`List.Linked.Error.swift:41-43`) | 2026-06-23 |
| `Pool.Bounded` | swift-pool-primitives | `Fixed<Column.Bounded<Entry>>` + `Fixed<Column.Bounded<Slot>>` (`Pool.Bounded.swift:90`, `Pool.Bounded.State.swift:47`) | composes `Column.Bounded` (= `Buffer.Linear.Bounded`) | via `Fixed`/buffer | `Pool.Bounded.Fill.Error { notEager, shutdown, full }` (`Fill.Error.swift:16,19,22`) | 2026-06-23 |

**Related, out of the named set but load-bearing:**

| Symbol | Site | Note | Verified |
|--------|------|------|----------|
| `Column.Bounded` | `swift-column-primitives/.../Column.swift:67-68` | **Pure typealias** `= Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear.Bounded`. Zero re-implementation; documented "`Array.Bounded`'s replacement" (`:44-45`). | 2026-06-23 |
| `Array.Bounded` | swift-array-primitives | **Absent from source** — already retired in favour of `Column.Bounded`. (`[DS-003]`'s `Array<E>.Bounded<N>` catalog row is stale.) | 2026-06-23 (grep empty) |

---

## Analysis

### Q1 — Homonym: confirmed distinct axis

**Verdict: CONFIRMED — value-range, not capacity.** `Finite.Bounded.swift:1-99`
documents the concept verbatim as *"a concept from Haskell's `Bounded` typeclass"*
— types with intrinsic `minBound`/`maxBound`, *"bounds are intrinsic — not
configurable,"* `Ordinal<5>` → `0..4`. The live value-range types
(`Ordinal.Finite<N>`, `Index<Element>.Bounded<N>`) refine a **position** to a
compile-time range; the container family limits a **runtime element count**. These
are orthogonal axes (`[RES-029]` IS-A: a bounded *position* is NOT-A bounded
*container*).

This is **already half-decided.** `array-bounded-index-revisit-2026-05-08.md`
(DECISION, tier 2) rebound the value-range index off `Algebra.Z<N>` onto a
phantom-typed bounded-linear position (`Tagged<Bound<N>, Ordinal>`, the
`Finite.Bound<N>` tag now live at `Index.Bounded.swift:24`) precisely because it
is *"a bounded LINEAR position … not modular wraparound."* The value-range axis is
therefore settled; what remains is the **name collision** with the capacity family.

The collision is sharpened by the value-range side itself borrowing capacity
words: `Index.Bounded.swift:2` calls `Index<Element>.Bounded<N>` a
"Capacity-bounded index." The live offender is `Index<Element>.Bounded<N>`, not
the commented-out `Finite.Bounded` protocol.

### Q2 — Type vs discipline: keep the types (NOT mergeable)

**Verdict: CONFIRMED — keep the per-container types.** The `.Bounded` types are one
shared *discipline* over genuinely distinct *representations* (`[RES-029]`:
operational behaviour of adjacent types is dispositive, not a wrapper's
convenience):

- `Buffer.Linear.Bounded` — contiguous, count+capacity header.
- `Buffer.Ring.Bounded` — circular, Cyclic-Index wrap + Checkpoint.
- `Buffer.Slab.Bounded` — sparse, bitmap-addressed.
- `Bit.Vector.Bounded` — packed bits.
- `Stack.Bounded` — LIFO over a bounded linear column.
- `List.Linked.Bounded` — pool-backed nodes.
- `Pool.Bounded` — async resource pool (slots, waiters, effects) over `Fixed<Column.Bounded>`.

A single `Bounded<C>` wrapper cannot unify a ring, a slab, a linked node-pool, and
a packed bit-array — their reject points, iteration, and element layouts differ.
This is **already ratified policy**: `occupancy-lives-in-the-leaf.md:109,176`
dissolves the `.Inline`/`.Small` occupancy types but explicitly **"keep[s]
`.Bounded` — a capacity axis"** (echoed in `[DS-023]`: *"`.Bounded` is a separate,
already-lawful capacity axis — retained, not a carve-out"*). Q2 needs no action
beyond recording the confirmation.

### Q3 — Mechanism duplication: the value/check are largely single-sourced; the **overflow vocabulary is copied 7×** (the win)

The mechanism decomposes into three parts; only one is duplicated in a fixable way:

| Part | State | Evidence |
|------|-------|----------|
| Capacity **quantity** | **Single-sourced** | Every container's bound is `Index<Element>.Count` (swift-index-primitives) — the type is shared; per-instance storage is not duplication. |
| Reject **predicate** | **Single-sourced *per buffer*** | The canonical check lives in the buffer header: `Buffer.Linear.Bounded.append → Element?` (`+Lifecycle.swift:45`), `Buffer.Ring.Bounded`'s `header.isFull` (`+Operations.swift:31,40,52`). ADTs ride it (Stack `_buffer.…append`, List `_buffer.isFull`, Pool `Fixed<Column.Bounded>`). |
| Overflow **error** | **COPIED 7×, inconsistently named** | One condition — "rejected because at capacity" — spelled three ways across seven independent enums. |

Overflow-error duplication (the concrete finding):

| Spelling | Sites |
|----------|-------|
| `capacityExceeded` | `Buffer.Linear.Bounded.Error.swift:5`, `Buffer.Ring.Bounded.Error.swift:5`, `Buffer.Slab.Bounded.Error.swift:8` — **three identical single-case enums** |
| `overflow` | `Stack.Bounded.Error.swift:30`, `List.Linked.Error.swift:41` (`__ListLinkedBoundedError`), `Bit.Vector.Bounded.Error.swift:19` |
| `full` | `Pool.Bounded.Fill.Error.swift:22` (among `notEager`/`shutdown`) |

No shared `Capacity`/`Bound`/overflow primitive exists (grep of
cardinal/index/finite/buffer found only `Finite.Bound<N>`, the *position* tag).
This is corroborated by `deque-ring-bounded-queue-archaeology.md:61-65`, which
already documents the `Buffer.Ring.Bounded.Error.capacityExceeded` /
push-returns-element shape against Apple's RigidDeque "reject" precedent.

**The win is a single shared capacity-overflow vocabulary**, not a merged
container. Caveat: `[API-ERR-001]` (typed throws, one error per throwing type)
means per-type `.Error` enums are *expected*; the defect is not "many enums" but
"the same semantic case re-invented under three names." The extraction is the
*condition*, not the per-type enum — see R3.

### Q4 — Layering: bound originates at the buffer tier; one genuine re-implementation flagged

**Verdict: layering is CORRECT** — the bound originates at the buffer/storage tier
and higher ADTs compose it, exactly as the Decoupling Charter prescribes
(`[DS-025]`/`[DS-004]`; `adt-buffer-storage-decoupling-shape.md`):

- `Column.Bounded` = **typealias** for `Buffer.Linear.Bounded` (`Column.swift:67`) — zero re-implementation.
- `Pool.Bounded` = `Fixed<Column.Bounded<…>>` (`Pool.Bounded.swift:90`) — composes.
- `Stack.Bounded` stores `Shared<Element, Column.Bounded>` (`Stack.Bounded.swift:106`) — composes.
- `List.Linked.Bounded` rides `Buffer.Linked` and **delegates `isFull` to `_buffer.isFull`** (`:31`) — the bound is the pool-backed buffer's, not re-implemented.
- `Bit.Vector.Bounded` is a **leaf** (only Index dep) below the buffer tier; it legitimately owns its capacity (`[DS-007]`: Bit.Vector is occupancy infrastructure *under* Storage/Buffer). **Not** a misplacement.

**One genuine re-implementation flagged — `Stack.Bounded`.** Its `push`
(`Stack.Bounded ~Copyable.swift:60-77`) guards `_buffer.count < requestedCapacity`
against a **separately stored `requestedCapacity`** *before* delegating to the
buffer's own reject. The cause is a semantic gap, not carelessness: the bounded
buffer enforces at the **physical, rounded-up** capacity —
`Header(capacity: storage.capacity)` (`+Lifecycle.swift:20`), and `+clone.swift:26-27`
states *"fresh storage rounds up physically; the header is the bound-enforcer
(extra physical slots stay unused and untracked)."* So the buffer would accept more
than the requested count; Stack re-checks to honour its *"reject at exactly this
count"* contract (`Stack.Bounded.swift:108-113`). This is a **minimum-vs-exact
bound** divergence: the buffer's bound is `minimumCapacity` (rounds up); the ADT
wants exact. List does **not** re-implement the bound (it delegates `isFull`); it
only re-declares the error (Q3).

---

## Prior Art & Theoretical Grounding (`[RES-021]`/`[RES-022]`/`[RES-026]`)

- **Dijkstra bounded buffer** — `variant-naming-audit.md:83` grounds `.Bounded` as
  *"Capacity-limited, mutable count (Dijkstra bounded buffer)"*: a fixed-capacity
  buffer that blocks/rejects at the limit. The capacity axis is the classical
  bounded-buffer; the value-range axis (Q1) is the type-theoretic refinement-type
  `{ x : Ordinal | x < N }`.
- **Apple `RigidArray`/`RigidDeque`** — `deque-ring-bounded-queue-archaeology.md:61-65`:
  Swift's own fixed-capacity collections `precondition` on overflow and offer
  *rejection* as the secondary path — the same "reject-at-limit" the family
  implements via return-rejected (`append → Element?`) + typed throw.
- **`array-bounded-index-revisit-2026-05-08.md`** (DECISION) — settled the
  value-range index as a bounded-linear position distinct from algebra; this doc
  extends that disambiguation to the *name*.
- **The Decoupling Charter** `[DS-025]`–`[DS-027]` /
  `adt-buffer-storage-decoupling-shape.md` (tier 3) — the ratified "ADT rides
  buffer rides storage" law that Q4 confirms is honoured.
- **`occupancy-lives-in-the-leaf.md`** (DECISION) — `.Bounded` is a retained
  capacity axis (Q2).
- **`column-spelling-ergonomics-alias-vocabulary.md`** /
  **`pool-bounded-storage-refactor.md`** — the Column-vocabulary and
  Pool-over-`Fixed<Column.Bounded>` decisions Q4 observes in source.

---

## Outcome

**Status: RECOMMENDATION.** No source changed. The recommendation gates a later
arc; it is one integrated move with four ranked steps (structural correctness over
diff-size, `[RES-022]`; compose-first, `[DS-020]`/`[RES-018]`).

### The single recommendation: *split the homonym → keep the types → single-source the overflow vocabulary → close the minimum-vs-exact bound gap.*

**R1 — Keep the per-container `.Bounded` types (Q2). Confirm-only; no action.**
Already ratified (`occupancy-lives-in-the-leaf`, `[DS-023]`). Record that
`.Bounded` is the lawful capacity axis and the types are not mergeable.

**R2 — Disambiguate the homonym (Q1).** Reserve `.Bounded` for the **capacity**
axis. Rename the live value-range collision `Index<Element>.Bounded<N>` →
`Index<Element>.Finite<N>`, mirroring the already-live `Ordinal.Finite<N>` and the
owning package (`swift-finite-primitives`); this also stops `Index.Bounded.swift`
from describing a value-range type as "Capacity-bounded". If the commented-out
`Finite.Bounded` typeclass is ever uncommented, name it for its content
(`Finite.Limits` / `Finite.MinMax`), not `Bounded`. Lower priority than R3/R4 (the
protocol is inert; the index alias is the only live collision) but it makes the
capacity family analyzable in isolation. Driver is semantic identity, not
cosmetics (`[RES-029]`).

**R3 — Single-source the capacity-overflow vocabulary (Q3 — the likely win).**
Introduce one shared *"rejected at capacity"* condition consumed by the whole
family, replacing the 7-way `capacityExceeded`/`overflow`/`full` split. Two tiers,
pick per the implementing arc:
- *Minimal (high confidence):* a single shared overflow error (e.g.
  `Capacity.Overflow` / `Bound.Overflow`) that each bounded type's typed-throws
  surface adopts or composes — honouring `[API-ERR-001]` (the per-type enum may
  remain, but the overflow *case* is the shared symbol, standardised on one name).
- *Optional (gated):* a thin `Capacity` value bundling `Index<…>.Count` + the
  `isFull`/reject predicate, if the ecosystem wants the predicate single-sourced
  too. Compose-first (`[DS-020]`/`[RES-018]`): the catalog already shares the
  *quantity* (`Index.Count`) but has **no** shared overflow vocabulary — the gap
  is real and cross-cutting across the container catalog, so a thin primitive is
  justified; do not introduce the `Capacity` value-type unless the predicate
  duplication is judged worth it.
- *Placement (semantic identity, `[RES-029]`/`[MOD-DOMAIN]`):* the shared symbol
  must sit **at or below the lowest consumer**. `Bit.Vector.Bounded` depends only
  on swift-index-primitives (it is *below* the buffer tier), so the symbol cannot
  live in swift-buffer-primitives without a layering inversion. Recommended home:
  **swift-index-primitives** (alongside `Index.Count`) or **swift-cardinal-primitives**
  (capacity is a Cardinal quantity) — both are universal lower-tier deps.

**R4 — Close the minimum-vs-exact bound gap (Q4).** Make `Buffer.Linear.Bounded`
enforce at the **requested** bound, not the physical one: store the requested
`minimumCapacity` as the header's enforced `capacity` (extra physical slots remain
untracked — which `+clone.swift:26-27` already declares is the intent). Then
`Stack.Bounded` drops its separate `requestedCapacity` field and the redundant
`guard _buffer.count < requestedCapacity` (`~Copyable.swift:63`), delegating fully
to the buffer's reject — eliminating the only genuine bound re-implementation. The
implementing arc must reconcile the header-capacity-vs-`storage.capacity` semantics
at the `+OutputSpan`/`+clone` sites (`+OutputSpan.swift:44`); flagged, not resolved
here. List and Bit.Vector need no Q4 change — List delegates the bound; Bit.Vector
is a legitimate leaf — they only adopt R3's shared error.

**Sequencing:** R1 is confirm-only. R2/R3/R4 are independent and each gate-able;
R3 is the highest-value (touches all 9 packages, removes 6 redundant enums) and
R4 the most surgical (one buffer + one ADT). None require a new container package
(`[DS-027]` unaffected); R3 may add one thin lower-tier symbol.

---

## References

Source (verified 2026-06-23):
- `swift-finite-primitives/Sources/Finite Bounded Primitives/Finite.Bounded.swift:1-99` — Haskell `Bounded` typeclass, commented out
- `swift-finite-primitives/Sources/Finite Bounded Primitives/Index.Bounded.swift:2,24,35` — `Index<Element>.Bounded<N> = Tagged<Tag, Ordinal.Finite<N>>`; `Ordinal.Finite<N> = Tagged<Finite.Bound<N>, Ordinal>`
- `swift-buffer-linear-primitives/Sources/Buffer Linear Bounded Primitive/Buffer.Linear.Bounded.swift:13`; `+Lifecycle.swift:20,45`; `+clone.swift:26-27`; `+Builder.swift:42-43`; `Buffer.Linear.Bounded.Error.swift:5`
- `swift-buffer-linear-primitives/Sources/Buffer Linear Primitive/Buffer.Linear.Header.swift:24-29` — `count` + `let capacity: Index<S.Element>.Count`
- `swift-buffer-ring-primitives/Sources/Buffer Ring Bounded Primitive/Buffer.Ring.Bounded+Operations.swift:31,40,52`; `Buffer.Ring.Bounded.Error.swift:5`; `Package.swift:53` (Cyclic Index)
- `swift-buffer-slab-primitives/Sources/Buffer Slab Bounded Primitive/Buffer.Slab.Bounded.Error.swift:8` [in-flux]
- `swift-bit-vector-primitives/Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded.Error.swift:17-19`; `Bit.Vector.Bounded.Capacity.swift`; `Package.swift:67` (Index only)
- `swift-stack-primitives/Sources/Stack Bounded Primitive/Stack.Bounded.swift:90,106,113`; `Stack.Bounded ~Copyable.swift:47,60-77`; `Stack.Bounded.Error.swift:28-30`; `Package.swift:84-85` (Buffer Linear Bounded)
- `swift-list-linked-primitives/Sources/List Linked Primitives/List.Linked.Bounded.swift:31,44-46,55-57`; `List Linked Primitive/List.Linked.Error.swift:41-43`; `Package.swift:48` (Buffer Linked — no `.Bounded` variant)
- `swift-pool-primitives/Sources/Pool Bounded Primitives/Pool.Bounded.swift:90`; `Pool.Bounded.State.swift:47`; `Pool.Bounded.Fill.Error.swift:16,19,22`; `Package.swift:185-186` (Column, Buffer Linear Bounded)
- `swift-column-primitives/Sources/Column Primitives/Column.swift:44-45,67-68` — `Column.Bounded` typealias = `Buffer.Linear.Bounded`
- `swift-array-primitives` — `Array.Bounded` absent (retired in favour of `Column.Bounded`)

Prior research (cite-and-extend):
- `swift-institute/Research/array-bounded-index-revisit-2026-05-08.md` (DECISION, tier 2) — value-range index disambiguation; `[RES-029]` worked example
- `swift-institute/Research/adt-buffer-storage-decoupling-shape.md` (tier 3, COMPANION to `[DS-025]`–`[DS-027]`)
- `swift-institute/Research/occupancy-lives-in-the-leaf.md` (DECISION, tier 3) — `.Bounded` retained as capacity axis
- `swift-institute/Research/variant-naming-audit.md:83` — Dijkstra bounded-buffer grounding
- `swift-institute/Research/deque-ring-bounded-queue-archaeology.md:61-65` — RigidDeque prior art; `Buffer.Ring.Bounded.Error` shape
- `swift-institute/Research/column-spelling-ergonomics-alias-vocabulary.md`; `swift-institute/Research/pool-bounded-storage-refactor.md`

Skills:
- `[DS-002]` variant selection (`.Bounded` = heap, fixed-at-init, non-growable); `[DS-003]`/`[DS-004]` container/buffer selection; `[DS-007]` Bit.Vector as occupancy infrastructure; `[DS-023]` `.Bounded` capacity axis; `[DS-020]` compose-first gate; `[DS-025]`–`[DS-027]` Decoupling Charter
- `[INFRA-105]` Finite bounded indices (value-range)
- `[ARCH-LAYER-006]`/`[ARCH-LAYER-008]` correctness/domain-completeness, not consumer count
- `[API-ERR-001]` typed throws (per-type error); `[RES-018]` compose-first; `[RES-022]` structural-correctness framing; `[RES-029]` semantic-identity-first
