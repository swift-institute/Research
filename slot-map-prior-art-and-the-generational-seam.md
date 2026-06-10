# Slot-Map Prior Art & the Generational Seam

<!--
---
version: 1.0.0
last_updated: 2026-06-10
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

R3 of the post-archaeology research arc. The ADT-families executor must surface-and-halt on
"slot-map vs the deliberately-deferred `Storage.Generational` seam" (`GOAL-tower-adt-families.md`
worklist), and the W3b handle-carrier entry records the standing posture
(`HANDOFF-tower-flag-day-migration.md` STATUS:65):

> SEAM NOTE (the seat's open question, answered from the reference): Linked drives Generational through
> its HANDLE API (insert→Handle / validated subscript / remove) — the deferred `Storage.Generational:
> Store.Protocol` conformance is NOT composed and stays deferred (not added preemptively, per
> instruction).

This note settles the question with prior art (Rust `slotmap`/`generational-arena`/`thunderdome`, C++
EnTT) and the verified local state, and answers the two adjacent design axes: sparse iteration strategy
and generation/ABA mechanics. All load-bearing claims [RES-020]-verified 2026-06-10 (12/12; one wording
precision folded in).

## Question

1. Should `Storage.Generational` ever conform the 4-op `Store.Protocol` seam — or is the Handle API its
   permanent access discipline?
2. What sparse-iteration strategy should a `SlotMap` ADT adopt (slot-scan / dense-mirror / hop)?
3. Do the leaf's generation mechanics match prior-art consensus?

## Headline answer

**Never conform the seam as-is. The Handle API *is* the generational seam.** Three independent reasons,
each sufficient:

1. **Ledger-shape mismatch.** The 4-op seam self-maintains a *linear-prefix* ledger (the W3b ring rule:
   "the W2 seam's self-maintenance is linear-prefix-shaped"); generational occupancy is scattered
   per-slot state. This is the same non-prefix-ledger argument that forces the sparse hashed leaf in R1
   (`hashed-container-substrate-archaeology.md`) — the seam's ledger cannot describe it, and an inert
   ledger over owned scattered elements is the Slots leak-by-construction hazard.
2. **Validation bypass.** The leaf's entire purpose is stale-handle rejection
   (`contains`: `_generations[handle.index] == handle.generation`,
   `Storage.Generational.swift:137` [Verified: 2026-06-10]). A raw `Index<Element>`-addressed seam
   subscript would bypass the generation check — re-opening exactly the use-after-reuse class the
   generations exist to close. Prior art is unanimous that *keyed access is the primary surface*:
   `slotmap` exposes **no** positional element access at all (opaque `KeyData`, every lookup takes a
   key — method lists verified); where the arena crates DO offer a raw-slot tier it is (i) loudly named
   (`get_unknown_gen`, `get_by_slot` — "disregarding any generational information"), (ii)
   occupancy-checked (returns `Option`), and (iii) hands back the **matching/true generational
   handle** so callers re-enter the validated world. Bare unvalidated indexing exists nowhere.
3. **The shipped reference already chose.** `Buffer.Linked` drives the store exclusively through
   `insert → Handle` / validated `storage[handle]` / `storage.remove(handle)`
   (`Buffer.Linked ~Copyable.swift:57,87,88`), with zero `initialize(at:)`/`move(at:)` seam calls in the
   package (grep-verified absence). The "deferred" conformance was never needed by its one composer.

**Consequences for the ADT family:** `SlotMap<S>` (target naming per the DESIGN doc:
`Buffer.SlotMap` — "rename the occupancy disciplines … so 'arena/pool/slab' name allocation only") is a
**pinned-column family**, not a gate+seam-generic one: its ops pin the concrete generational column
(`where S == …Generational<…>`), exactly the ratified occupancy-pin composition (`Buffer.Arena`
precedent, occupancy law: "buffers pin the concrete leaf for occupancy ops — zero occupancy protocol").
The seam-generic Array playbook applies to its *dense* surfaces only if it ever grows any. If a raw-slot
tier is ever wanted (the external-bit-index use case `generational-arena` documents), adopt the
prior-art bypass shape — a separate, loudly-named, occupancy-checked accessor returning the true
`Handle` — never a `Store.Protocol` conformance.

## Prior art census [Verified: 2026-06-10]

| Design | Key | Occupancy/iteration | Raw-slot access | Teardown |
|---|---|---|---|---|
| Rust `slotmap.SlotMap` | versioned key; "each slot … is a `(value, version)` tuple"; opaque `KeyData` | slot-scan: "must iterate over all slots, empty or not … can be inefficient" | **none** | Drop walks slots |
| `slotmap.HopSlotMap` | same | hop over vacant runs | none | — **DEPRECATED since 1.1.0**: "no longer maintained and will be removed in 2.0" |
| `slotmap.DenseSlotMap` | same | dense mirror: "two indirections per random access … iteration … as fast as a normal `Vec`"; swap-and-pop | none (bulk `as_slices` only, positions unstable) | dense Vec drop |
| `generational-arena` | `Index` (index+generation) | slot-scan; yields `(Index, &T)` | `get_unknown_gen(usize) -> Option<(&T, Index)>` — checked, returns the matching `Index` | Drop |
| `thunderdome` | 8-byte `Index`, niche-packed ("still 8 bytes … inside of an `Option<T>`") | slot-scan; yields pairs | `get_by_slot`/`remove_by_slot`/`contains_slot` — "disregarding any generational info", `contains_slot` returns "the true `Index`" | Drop |
| EnTT (C++ ECS) | entity = index+version ("the version of an entity is increased" on release) | sparse page table → packed dense arrays, swap-and-pop; "There is nothing as fast as a single type view. They just walk through packed … arrays" | by entity only; tombstoned in-place mode optional | pool-managed |
| **Swift (stdlib · swift-collections · SE · forums)** | — | — | — | **nothing exists** — zero hits everywhere (greps + code/issue searches shown in the survey record); the field is open |

ABA mechanics consensus: per-slot generation/version word; bump on free; key validity = stored-version
equality. `slotmap` documents the wraparound bound ("after 2³¹ deletions and insertions to the same
underlying slot … a spurious reference could potentially occur … in all circumstances is the behavior
safe"). The tower's `Int` (64-bit) generation makes wraparound practically unreachable — strictly
stronger than both Rust crates' 32-bit versions.

## The local state (verified anatomy)

`Storage.Generational<Element: ~Copyable>: ~Copyable` (`swift-storage-arena-primitives`,
`Storage.Generational.swift:47`): a `Pool` allocation (bytes + in-band free list) + per-slot
`_generations: [Int]` (:66) + `_occupied: [Bool]` (:70) + count; deinit is the occupancy-guarded drain
(`if _occupied[i] { _ptr(at: i).deinitialize(count: 1) }`, :101–107). API: `insert(consuming Element)
-> Handle` (:188), validated `subscript(_ handle: Handle)` `_read/_modify` with
`precondition(contains(handle))` (:142 — the only public element subscript in the file), `remove(_
handle:) -> Element?` bumping the generation (`&+= 1`, :206). The handle is the W3b non-generic carrier
`Store.Generational.Handle { index: Int; generation: Int }: Hashable, Sendable`. No span/Iterable
surface; no raw-index access — i.e. **the local design already sits on the `slotmap` (strictest) end of
the prior-art spectrum**. [Verified: 2026-06-10]

## Sparse iteration — recommendation

Census signal: the hop variant is the one the ecosystem killed; the live space is **slot-scan**
(simple, O(capacity), what the leaf's own deinit already does) vs **dense-mirror** (O(live) iteration +
swap-and-pop + two-indirection access — `DenseSlotMap`/EnTT, chosen when iteration dominates).

Recommendation: **slot-scan now; dense-mirror as a separate consumer-evidence-gated variant later; never
hop.** Rationale: (a) today's only composer (`Buffer.Linked`) iterates by *links*, not slots — there is
no iteration-hungry consumer yet (census: graph and pool use no generational storage); (b) slot-scan
needs zero new state and matches the deinit walk; (c) when chunked iteration is wanted, the
occupied-region span iterator is the proven shape (swift-collections `RigidSet.BorrowingIterator_`
yields piecewise spans via `nextOccupiedRegion` — the R1 record), and it slots into the institute's
`__IteratorChunkProtocol` (`next(maximumCount:) -> Span<Element>`) without new protocol work — though
spans over *scattered* slots only cover occupied runs, which the region iterator handles by
construction; (d) a dense-mirror variant changes the handle→position relationship (indirection table)
and is precisely the kind of variant [RES-022]/consumer-evidence should gate.

## Findings beyond the brief

1. **Arena-model divergence (surface to the seat).** The occupancy law prescribes sparse leaves track
   per-slot state "SoA *within the one allocation they own*" (the `Storage.Arena` `[Meta | elements]`
   model; stdlib's hashed storage ships the same shape — R1). `Storage.Generational` instead keeps its
   per-slot state in **two stdlib-`Array` side allocations** (`_generations: [Int]`,
   `_occupied: [Bool]` — genuine `Swift.Array(repeating:…)` stored properties, verified :66/:70/:87–88)
   inside the move-only leaf: two extra heap allocations plus CoW machinery riding inside a `~Copyable`
   struct. Functionally sound (the drain is occupancy-guarded; handles validate), but structurally
   off-model. Candidate alignment: fold generations+occupancy into the leaf's single allocation as SoA
   planes (the Arena/stdlib shape). This is a structural-correctness observation for the seat, not a
   blocker — flagged, not prescribed.
2. **Handle packing (direction).** `Handle` is 2×`Int` (16 bytes); `thunderdome`'s headline is an
   8-byte niche-packed index (`Option<Index>` still 8 bytes). If handle-dense structures appear
   (e.g. graphs storing handles per edge), a packed `Handle` repr is the known optimization; today's
   only consumer stores a handful of links — not worth it yet.
3. **Naming already settled in the DESIGN doc**: "rename the occupancy disciplines (e.g.
   `Buffer.SlotSet`, `Buffer.SlotMap`) so 'arena/pool/slab' name allocation only"
   (`DESIGN-msb-ideal-type-signatures.md:168–170, 185–186`) — this note's findings are consistent and
   add the prior-art backing (every surveyed ecosystem names the *container* slot-map/arena distinctly
   from its *allocator*).

## Tower impact

| # | Finding | Tower element | Verdict |
|---|---|---|---|
| 1 | Prior art: keyed access primary everywhere; raw tiers loud+checked+handle-returning where they exist at all | The deferred `Storage.Generational: Store.Protocol` | **Retire "deferred" → NEVER (as-is)**; the Handle API is the seam; optional future raw tier per the bypass shape |
| 2 | Seam prefix-ledger vs scattered occupancy (R1's argument, second application) | SlotMap family composition | Pinned-column family (occupancy-pin pattern), not gate+seam generic |
| 3 | Hop deprecated upstream; dense-mirror = the iteration-heavy alternative | SlotMap iteration | Slot-scan now; occupied-region chunk iterator when Iterable wanted; dense-mirror variant gated on consumer evidence |
| 4 | 64-bit generations vs prior art's 32-bit + documented wraparound | Generation mechanics | Already stronger than consensus; no change |
| 5 | Per-slot state in stdlib-Array side allocations | Occupancy law (single-allocation SoA) | **Divergence — surface to seat** (alignment candidate, not a blocker) |
| 6 | Swift ecosystem has zero slot maps | Positioning | Open field; the tower's would be first — naming/API can follow prior-art consensus freely |

## Outcome

**Status: RECOMMENDATION** (research only). For the executor's halt item:

1. Resolve "slot-map vs the deferred seam" as: **Handle API permanently; no `Store.Protocol`
   conformance on `Storage.Generational`** (reasons §Headline). Record the retirement of "deferred" in
   the STATUS at the family's surface-ratification.
2. Compose `SlotMap` as a pinned-column family over the generational column (target naming
   `Buffer.SlotMap` per the DESIGN doc); ops = insert/contains/subscript[handle]/remove + slot-scan
   iteration; chunked `Iterable` later via an occupied-region iterator if consumers want it.
3. Surface finding §F1 (side-array vs single-allocation SoA) to the seat alongside the family's
   surface-first halt — it is the same review moment.
4. Skip dense-mirror and handle-packing now; both recorded as consumer-evidence-gated directions.

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| All §Headline/§Local claims | premises | Source-verified 2026-06-10 (local file:line; web primary docs re-fetched by the verifier) |
| Dense-mirror variant; packed Handle | directions | Consumer-evidence-gated; no experiment owed now |
| Arena-model alignment of the leaf's per-slot state | direction (structural) | Seat's call at the family surface-ratification; the executor's gated build would verify any chosen reshape |
| Occupied-region chunk iterator over generational slots | direction | Shape proven upstream (s-c `nextOccupiedRegion`); build when Iterable membership is wanted |

## References

- **Prior art (fetched 2026-06-10)**: docs.rs/slotmap v1.1.1 (crate docs; SlotMap/DenseSlotMap/
  HopSlotMap struct pages incl. the 1.1.0 deprecation; KeyData); docs.rs/generational-arena v0.2.9
  (`get_unknown_gen`); docs.rs/thunderdome v0.6.1 (`get_by_slot` family; 8-byte niche Index);
  github.com/skypjack/entt `docs/md/entity.md` @ master (versions; sparse pages; single-type views).
- **Absence evidence**: stdlib pinned worktrees greps (`slotmap|slot map` → 0); swift-collections @
  `af174fe` + code search → 0; swift-evolution proposals/visions → 0; forums searches → no on-topic
  threads.
- **Local**: `swift-storage-arena-primitives` `Storage.Generational.swift:47,66,70,87–88,101–107,133–142,188–206`;
  `Store.Generational.swift:14–26` (Handle carrier); `swift-buffer-linked-primitives`
  `Buffer.Linked ~Copyable.swift:36,57,59,87,88` (+ seam-absence grep);
  `.handoffs/HANDOFF-tower-flag-day-migration.md` STATUS:65 (SEAM NOTE), :63 (ring ledger rule);
  `.handoffs/DESIGN-msb-ideal-type-signatures.md:168–186` (SlotMap naming);
  `occupancy-lives-in-the-leaf.md` (the law; Arena model); `hashed-container-substrate-archaeology.md`
  (R1 — the non-prefix-ledger argument, first application); `storage-protocol-family-rollout.md`
  (carried forward: the conformance was deferred at Wave 2, not designed-in).

### Verification

[RES-020] parallel verification 2026-06-10: 12 claims re-derived (5 web-primary, 7 local) — 12/12
confirmed; one wording precision folded in ("true Index" is thunderdome's phrase; generational-arena
says "matching Index").
