# The Decomposition Layer-Placement Package Map

<!--
---
version: 1.0.0
last_updated: 2026-06-06
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
normative: false (research; the end-state target Cleave #7 executes + [MOD-PLACE] encodes — neither done here)
type: investigation/architecture
companion_of: swift-institute/Research/decomposition-layer-placement-calculus.md   (the calculus — the AUTHORITY this applies)
depends_on:
  - swift-institute/Research/decomposition-layer-placement-calculus.md            (the placement calculus)
  - .handoffs/GOAL-msb-tower-end-state.md                                          (ratified end-state + D1 correction)
  - .handoffs/GOAL-cleave-6-sparse-occupancy.md                                    (Cleave-6 Shape-α — the sparse-inline forced-keeps)
  - .probe-bank/prism-endstate/end-state-research-note.md                          (the consolidated inventory)
provenance: tier-3 /research-process applied follow-up (HANDOFF-strata-package-map.md). Read-only on
  production; the in-scope tower (~50 packages) classified empirically against the live tree via five
  parallel verification subagents ([RES-020], 2026-06-06); every row + every Package.swift file-verified.
  The Research repo is PUBLIC — held for seat verification; not pushed.
---
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

> **What this is.** The FINAL, definitive package/module map + strata dependency DAG for the MSB
> data-structure tower. The calculus (`decomposition-layer-placement-calculus.md`) established the
> *principles* (which layer owns which axis); this note applies them **exhaustively and empirically** to
> the live `swift-primitives` tree to produce the **north-star** every cleave arc drives toward — every
> in-scope package classified once (layer · axis · disposition · end-state form · hard-floor flag), the
> verified dependency graph, and the dependency-ordered delta-list that becomes Cleave #7's worklist.
> **The calculus is the authority — applied here, not re-derived.**

---

## Context & method

Placement issues kept surfacing ad hoc — `buffer-arena` dissolves, `Buffer.Linked.Inline` naming, `Storage.Pool`
is a smell, Arena/Pool duplicated across three tiers. This map fixes the target **once**, so Cleave #6/#7,
the `[MOD-PLACE]` rule, and all future placement work share one source of truth.

- **Empirical throughout.** Every row is file-verified against the live tree (read each `Package.swift`,
  `ls Sources/`, grep namespace decls) via five tier-partitioned parallel subagents — zero classification
  from memory. Load-bearing facts carry `file:line`.
- **Reconciled, not overruling.** Cross-checked against the ratified `GOAL-msb-tower-end-state.md` (+ D1
  correction) and the **Cleave-6 Shape-α** ratification (2026-06-06). Where the pure-calculus reading and a
  ratified decision could diverge, it is **surfaced** (§D), never silently overruled.
- **Hard floor honored.** A forced exception (bd04f32, the empty-corner, leak-freedom) is **KEPT and
  flagged**, never "cleaned up." The hard-floor column is the load-bearing line between Cleave-6's keeps and
  Cleave-7's renames.

### Phase-0 boundary (confirmed)

**In scope (~50 packages):** the Memory / Storage / Buffer / ADT tower + its cross-cutting axes (Span,
Store-seam, Index, Iteration, Algebra-bridge) + the occupancy-bitmap substrate. **Out of scope (boundary
edges, noted not classified):** `memory-{map,lock,shared,cursor,iterator,sequence}` (OS/sync/iteration
facilities, `[MOD-035]`-excluded); and the broad ecosystem the tower depends *down* on (the foundational
capability primitives — tagged/carrier/ordinal/cardinal/affine/comparison/hash/property/bit; algebra
families; parsers/coders; compiler-toolchain; IO/system/numeric/geometry). The in-scope set **is** the tower
— not materially larger — so no scope-expansion gate fired (`HANDOFF` ground rule 5a).

---

## §A — End-state package/module overview (exhaustive)

Disposition legend: **KEEP** (correctly placed) · **RENAME** (placement smell in the name) · **DISSOLVE**
(duplicate/variant → composition) · **MERGE** · **RELOCATE** (wrong layer). Hard-floor column: **FK** =
forced-keep (an apparent smell the wall forces; KEPT) · **OOS** = capacity axis, out-of-scope this arc
(Prism) · **gap** = the calculus end-state names it but it is unrealized · **—** = none.

### A.1 — Memory tier (Location ⊥ Allocation-discipline ⊥ Liveness ⊥ Growth ⊥ Addressing)

| Package | Canonical layer · axis | Disposition | End-state form | Floor/flag |
|---|---|---|---|---|
| **swift-memory-primitives** | Memory · substrate + markers (`Memory.{Address,Alignment,Allocation,Contiguous,Shift,Allocator/Allocatable,Tracked,Unique,Move}`) | **KEEP** | the Memory home: namespace + cores + the four leaf-private markers | — (ledger `Memory.Tracked` is contiguous-only — D1) |
| **swift-memory-inline-primitives** | Memory · Location = **in-struct** (`@_rawLayout`); conforms `Store.Protocol + Memory.Tracked` (NOT `Allocator` — *the tell*) | **KEEP** | the in-struct Location leaf; `Storage.Contiguous<Memory.Inline>` composes it | FK: D1 — Inline *carries* `Memory.Tracked` (conditionally-Copyable struct can't self-deinit → consumer needs the live-extent) |
| **swift-memory-heap-primitives** | Memory · Location = **out-of-line**, Allocation = **single-buffer**; conforms `Store + Tracked + Allocatable + Unique` | **KEEP** | the out-of-line single-buffer Location leaf; teardown oracle in the leaf's backing `class` | FK: leak-freedom record in the leaf `deinit` (bd04f32 — not pushable up or into a generic composer) |
| **swift-memory-arena-primitives** | Memory · Allocation = **bump** | **KEEP** (namespace already `Memory.*`) | `Memory.Arena` leaf | **gap**: does *not* conform `Memory.Allocator.Protocol` (the §1.2.1 allocation seam) — end-state should add it |
| **swift-memory-pool-primitives** | Memory · Allocation = **free-list** | **KEEP** | `Memory.Pool` leaf | **gap**: same missing-allocator-seam; dep on `bit-vector` (slot bitmap) is **downward**, verified clean |
| **swift-memory-small-primitives** | Memory · Location = **hybrid** (inline ≤ n ⊕ heap-spill) | **KEEP** | the hybrid Location leaf; dissolves `Storage.Small` | sanctioned intra-rung leaf→leaf dep on `memory-{heap,inline}` (§1.2.1: Small *is* inline⊕heap) |
| **swift-memory-aligned-primitives** | Memory · Location = alignment-constrained **out-of-line** (owns `bytePointer`, raw alloc/deinit) | **MERGE / RENAME** | fold into `Memory.Heap` with an alignment parameter, OR keep as the explicit aligned-allocation leaf | design-needed: a parallel hand-rolled Heap; does *not* conform the `Store/Tracked` seam (predates it) |
| **swift-memory-unbounded-primitives** | Memory · **Growth** composition over `Memory.Aligned` (growable byte region) | **DISSOLVE / RELOCATE** | a Location leaf ⊗ the `Growable` marker (§5.3: growth is a leaf capability) — not a standalone namespace | design-needed; intra-rung dep on `memory-aligned` |
| **swift-memory-buffer-primitives** | Memory→**cross-cutting** · integer-address **non-owning VIEW** (Copyable descriptor over `Memory.Address`) | **RELOCATE / MERGE → Span** | a Span-family raw view in `swift-span-primitives` (§1.3 — don't bake a cross-cutting view into a core) | the canonical §1.3 smell (a view mis-homed under `Memory.*`) |

### A.2 — Seam, markers, sibling axis (the Tier-0 capabilities below Memory)

| Package | Canonical layer · axis | Disposition | End-state form | Floor/flag |
|---|---|---|---|---|
| **swift-store-primitives** | Seam · `Store.Protocol` (FROZEN 4-op) + `Store.Initialization` (ledger vocab) | **KEEP** | the canonical Store seam + ledger vocabulary; the *universal* `Store.Tracked.Protocol` is **eliminated** (leaf-private `Memory.Tracked`) | — |
| **swift-span-primitives** | Cross-cutting · `Span.Protocol` (vend a contiguous view) | **KEEP** (+ delete `My*` scratch types) | the namespace-neutral Span capability; the home `Memory.Buffer`'s raw view migrates toward | — (clean; `My*` is debris) |
| **swift-index-primitives** | Sibling axis · `Index<Element>` (typed slot) | **KEEP** | the typed-Index package; end-state **adds `Index<Element>.Bounded<N>`** | **gap**: `Index.Bounded<N>` is **absent** — the §5.3 typed-bounded-index home (the only reason `Array.Bounded<N>` carries `<N>`) |
| **swift-growth-primitives** | Memory-sub-axis (hoisted) · `Growth.Policy` | **KEEP** (+ add the `Growable` marker) | the Growth-policy package + a `Growable` leaf-marker | **gap**: the `Growable` *marker* the calculus posits (§5.3) is **absent** — only the `Policy` value exists |

### A.3 — Storage tier (Region-Topology ⊥ init-Tracking)

| Package | Canonical layer · axis | Disposition | End-state form | Floor/flag |
|---|---|---|---|---|
| **swift-storage-primitives** | Storage · Topology(single-region) + Tracking; `Storage.Contiguous<M>`, `Storage.Protocol` (marker) | **KEEP** | `Storage.Contiguous<M>` over the Store seam (canonical) | residual `Storage.{Heap,Inline,Small}` *type* decls = **ZERO** (target met; the 8 hits are retrospective doc-comments) |
| **swift-storage-split-primitives** | Storage · Topology(**multi-region/SoA**) | **KEEP** | `Storage.Split<Lanes,Elements>` (the cleanest axis→layer datum) | — |
| **swift-storage-pool-primitives** | **§5.4 SMELL** · axis is **Allocation(free-list)** = Memory's | **DISSOLVE** | content → `Memory.Pool`; consumers retype to `Storage.Contiguous<Memory.Pool>` (`Storage.Pool` composes `Memory.Pool` at `Storage.Pool.swift:133`) | **deferred-arc** (out-of-line allocation arc, NOT mechanical Cleave-7); `Storage.Pool.Inline` carries the Cleave-6 bitmap-occupancy ORACLE template |
| **swift-storage-arena-primitives** | **§5.4 SMELL** · axis is **Allocation(bump)** = Memory's | **DISSOLVE** | content → `Memory.Arena`; consumers retype to `Storage.Contiguous<Memory.Arena>` (`Storage.Arena.swift:56`) | **deferred-arc**; `Storage.Arena.Inline` carries the oracle template |

### A.4 — Buffer tier (Occupancy/Order ⊥ Overflow-signal)

Sparse-inline forced-keeps per **Cleave-6 Shape-α**: bd04f32 + sparse occupancy force teardown to the lowest
unconditionally-`~Copyable` owner = the inline **Buffer** (the empty-corner specialization). Dense
`.Inline` correctly dissolved.

| Package / variant | Canonical layer · axis | Disposition | End-state form | Floor/flag |
|---|---|---|---|---|
| **swift-buffer-primitives** | Buffer · root marker `Buffer.Protocol` (`count`) | **KEEP** | the `Buffer.Protocol` seam | — |
| **swift-buffer-linear-primitives** | Buffer · Occupancy = **dense** | **KEEP** | `Buffer.Linear<S: Storage>` | dense `.Inline` correctly **DISSOLVED** (no residual) |
| ↳ `Buffer.Linear.Bounded` | Capacity axis | **KEEP** | Prism-decided | **OOS** |
| **swift-buffer-ring-primitives** | Buffer · Occupancy = **dense** (FIFO) | **KEEP** | `Buffer.Ring<S>` | dense `.Inline` correctly **DISSOLVED** |
| ↳ `Buffer.Ring.Bounded` | Capacity axis | **KEEP** | Prism-decided | **OOS** |
| **swift-buffer-slab-primitives** | Buffer · Occupancy = **sparse** | **KEEP** | `Buffer.Slab<S>` (sparse sibling of Linear/Ring) | — |
| ↳ `Buffer.Slab.Inline` / `.Small` | Buffer · sparse-**INLINE** | **KEEP** | retain `.Inline`/`.Small` | **FK** (Shape-α) |
| ↳ `Buffer.Slab.Bounded` | Capacity axis | **KEEP** | Prism-decided | **OOS** |
| **swift-buffer-slots-primitives** | Buffer · Occupancy = **sparse** (stable handles) | **KEEP** | `Buffer.Slots<S>` (SoA-capable via Split) | `→ storage-split` is a downward Buffer→Storage edge (clean) |
| **swift-buffer-linked-primitives** | Buffer · Occupancy = **node-linked** | **KEEP** (base) | `Buffer.Linked` over `Memory.Pool` (reached via `storage-pool` → retargets on the deferred-arc) | — |
| ↳ `Buffer.Linked.Inline` / `.Small` | Buffer · sparse-**INLINE** | **KEEP** | retain `.Inline`/`.Small` | **FK** (Shape-α) |
| **swift-buffer-arena-primitives** | Buffer · Occupancy **over Arena allocation** | **KEEP** (base) | `Buffer.Arena` over `Storage.Contiguous<Memory.Arena>` post-arc | base name retargets when `storage-arena` dissolves (deferred-arc) |
| ↳ `Buffer.Arena.Inline` / `.Small` | Buffer · sparse-**INLINE** (the Shape-α *precedent mechanism*) | **KEEP** | retain `.Inline`/`.Small` | **FK** (Shape-α; "mirror the mechanism, not the Arena name") |
| ↳ `Buffer.Arena.Bounded` | Capacity axis | **KEEP** | Prism-decided | **OOS** |

### A.5 — ADT tier (abstract Contract)

| Package | Contract · composes | Disposition | End-state form | Floor/flag |
|---|---|---|---|---|
| **swift-array-primitives** | sequence · `Buffer.Linear` (`Array.swift:63`) | **KEEP** | `Array = Buffer<Storage.Contiguous<Memory.Heap>>.Linear` (verbose form in place) | `.Bounded`/`.Fixed` **OOS**; Inline/Static/Small MARK sections **empty** (dissolved) |
| **swift-stack-primitives** | LIFO · `Buffer.Linear` (`Stack.swift:87`) | **KEEP** | `Stack` over Linear | `.Bounded` **OOS** |
| **swift-queue-primitives** | FIFO · `Buffer.Ring` (`Queue.swift:90`) | **KEEP** | `Queue` over Ring | `.Fixed` **OOS** |
| **swift-queue-linked-primitives** | FIFO over node-linked · `Buffer.Linked<1>` (`Queue.Linked.swift:58`) | **KEEP** (base) | `Queue.Linked` over `Buffer.Linked` | `.Fixed`/`.Bounded` **OOS** |
| ↳ `Queue.Linked.Inline` / `.Small` | ADT **location** variant (delegates to `List.Linked.{Inline,Small}`) | **DISSOLVE** | delete; consumers compose the linked inline path directly | **residual** location variant |
| **swift-deque-primitives** | double-ended · `Buffer.Ring` (reuses Queue's Ring) | **KEEP** | `Deque` over Ring | `.Fixed` **OOS**; lateral-intra-tier `→ queue` (peer reuse) |
| **swift-heap-primitives** | priority · `Buffer.Linear` (`Heap.swift:109`) | **KEEP** | `Heap` over Linear | `.Fixed`/`.MinMax.Fixed` **OOS**; `Heap.Min/Max/MinMax` = **contract** variants (KEEP at ADT) |
| **swift-list-primitives** | sequence · namespace shell only (`enum List {}`) | **KEEP** | the namespace root; disciplines live in sibling packages | umbrella `→ list-linked` re-export |
| **swift-list-linked-primitives** | sequence over node-linked · `Buffer.Linked` (composes, not re-implements) | **KEEP** (base) | `List.Linked` over `Buffer.Linked` | `.Bounded` **OOS** |
| ↳ `List.Linked.Inline` / `.Small` | ADT **location** variant (`Buffer.Linked.{Inline,Small}`) | **DISSOLVE** | delete; consumers compose the inline/spill discipline directly | **residual** location variant (root of the Queue.Linked.{Inline,Small} pass-throughs) |
| **swift-set-primitives** | membership · pure `Set.Protocol` core (no buffer; algebra lifted out) | **KEEP** | unchanged — canonical membership contract | — |
| **swift-set-ordered-primitives** | insertion-ordered membership · `Buffer.Linear` + `Hash.Table` | **KEEP** (base) | unchanged | `.Fixed` **OOS**; strip dead `__SetOrderedInlineError` + empty Static/Small MARK residue |
| **swift-dictionary-primitives** | key→value · `Buffer.Slab` over `Storage.Contiguous<Memory.Heap>` | **KEEP** | unchanged (already on end-state spelling) | — |
| **swift-dictionary-ordered-primitives** | insertion-ordered key→value · `Buffer.Linear` + `Hash.Table.Static` | **KEEP** (base + `.Bounded`) | unchanged | `.Bounded` **OOS**; strip "Static/Small" header + `memory-small` dep residue |
| **swift-tree-primitives** | hierarchy · namespace shell (`enum Tree {}`) | **KEEP** | the namespace root | — |
| **swift-tree-n-primitives** | n-ary hierarchy · `Buffer.Arena` (`Tree.N.Inline.swift:57`) | **KEEP** (base, `.Bounded`) | base over `Buffer.Arena` | `.Inline`/`.Small` = **residual** location variants → **DISSOLVE**; `.Bounded` **OOS** |
| **swift-tree-keyed-primitives** | hash-indexed hierarchy · `Dictionary` + `Dictionary.Ordered` + `Buffer.Arena` | **KEEP** | unchanged | lateral ADT→ADT `→ {dictionary, dictionary-ordered}` (`Package.swift:26-27`) — legit keyed-tree HAS-A; **confirm** |
| **swift-tree-unbounded-primitives** | unbounded-arity hierarchy · `Buffer.Arena` | **KEEP** | unchanged | strip dead `__TreeUnbounded{Small,Bounded}Error` enum residue |
| **swift-bitset-primitives** | bit-set (dense integer membership) · own word substrate (no Buffer) | **KEEP** (base) | base; future RELOCATE onto bit-primitives substrate (OOS) | `.Static`/`.Fixed` = **OOS** capacity; **`.Small` = residual** location spill → **DISSOLVE** (realize via `Memory.Small`) |
| **swift-hash-table-primitives** | **SUBSTRATE** (open-addressed bucket array under Set/Dict) · owns `Buffer.Slots` over `Storage.Contiguous<Memory.Heap>` | **KEEP** | unchanged | `.Static` = independent compile-time-capacity per **[DS-002]** (capacity, **NOT** a location dissolve) |
| **swift-pool-primitives** | **async resource/connection-pool ADT** (`Pool.Bounded`: mutex-guarded acquire/release) — **NOT an allocator** | **KEEP** | unchanged — distinct concurrency ADT | **triplication resolved**: `Pool` ≠ `Memory.Pool` (homonyms, different axes) — no MERGE |
| **swift-slab-primitives** | sparse fixed-capacity typed slot-map ADT · thin façade over `Buffer.Slab.Bounded` (`Slab.swift:36`) | **KEEP** (low-pri **RELOCATE/MERGE** review) | unchanged; or fold the near-empty façade into `Buffer.Slab` / its sole consumer | distinct contract (not a `Buffer.Slab` duplicate); 1 ecosystem consumer; `.Static` = OOS capacity |
| **swift-cache-primitives** | eviction-policy key→value cache · `Dictionary` + `Array` + `Async.Mutex` | **KEEP** | unchanged | lateral ADT→ADT `→ dictionary` (`Package.swift:29`) — legit cache HAS-A index; **confirm** |

### A.6 — Cross-cutting capabilities & substrates (composed over cores; boundary-adjacent)

| Package | Role · IN-tower vs boundary | Disposition | End-state form | Floor/flag |
|---|---|---|---|---|
| **swift-iterator-primitives** | Iteration core (`Iterable`) — IN (composed over every core) | **KEEP** | canonical Iteration substrate (the `Iterable` attach-point) | — |
| **swift-sequence-primitives** | Iteration mid-rung (`Sequenceable`) — IN | **KEEP** | unchanged | pending seq↔iterator reconcile (separate deferred arc) |
| **swift-collection-primitives** | Iteration top-rung (`Collection.Protocol`, access capability) — IN | **KEEP** | the ADT-tier access *capability surface* (not a container) | — |
| **swift-set-algebra-primitives** | Algebra **bridge** (`extension Set.Protocol where Self: Set.Protocol & Iterable`) — boundary, owns no core | **KEEP** | canonical algebra bridge; deps strictly **down** (`Set.Ordered` refs are comments only) — no violation | — |
| **swift-bit-vector-primitives** | **bit-domain representation substrate** *below* the Memory line — boundary | **KEEP** | the occupancy-bitmap substrate consumed **downward** by storage/pool/arena/buffer-slab/dict | per-variant `.Static/.Bounded/.Inline/.Dynamic` split = the §5.3 capacity-bundle pattern (bit-domain; OOS) |
| **swift-slice-primitives** | empty reserved `Slice` namespace (no types, no consumers) | **KEEP (provisional)** / candidate **DISSOLVE** | reserve if a Slice-view capability is forthcoming; else fold into the core that vends the view | empty namespace-only package — decide reserve-vs-dissolve |

---

## §B — Strata/layer dependency DAG (verified)

### B.1 — The canonical strata order (intra-L1; downward-only)

All ~50 packages are **L1 Primitives**, so the five-macro-layer `[ARCH-LAYER-001]` is trivially satisfied
(no package depends up to L2/L3). The *operative* ordering is the **intra-L1 tower strata** the calculus
fixes — a package may depend only *downward* within it:

```
   ADT            (array, stack, queue, deque, heap, set(.ordered), dictionary(.ordered),
                   list(.linked), tree(.n/.keyed/.unbounded), bitset, hash-table*, pool‡, slab, cache)
     │ HAS-A
   BUFFER         (buffer · linear, ring · slab, slots · linked · arena⌫)
     │ HAS-A
   STORAGE        (storage · split · pool⌫ · arena⌫)
     │ HAS-A (generic over the Store seam)
   MEMORY         (memory · inline, heap, small · arena, pool · aligned✗, unbounded✗, buffer→span)
     │ conform / depend
   SEAMS & SIDE-AXES (below/beside Memory):  store(Store.Protocol) · span(Span.Protocol) ·
                   index(Index, sibling) · growth(Growth) · ITERATION tower: iterator ⊏ sequence ⊏
                   collection · ALGEBRA bridge: set-algebra · SUBSTRATE: bit-vector (bit-domain, ⊏ Memory)
   ─────────────  boundary (down): tagged · carrier · ordinal · cardinal · affine · comparison · hash ·
                   property · bit · finite · range · pair · either · async · time · effect · ownership …
   ⌫ = dissolve (deferred allocation-arc)   ✗ = dissolve/merge (Memory-tier cleanup)   ‡ = resource-pool ADT (homonym)   * = substrate
```

### B.2 — Current dependency adjacency (file-verified) + violation scan

**Strata-direction scan result: ZERO upward/lateral *cross-rung* violations.** Every Buffer→Storage,
Storage→Memory, Memory→seam, and ADT→(Buffer|substrate) edge is **downward**. The two load-bearing edges
that *looked* suspect both verified **downward**:

- `swift-memory-pool-primitives → swift-bit-vector-primitives` (`Package.swift:26/37`) — `Bit.Vector` is a
  self-allocating **bit-domain representation primitive** (`UnsafeMutablePointer<UInt>`, imports only
  `Bit_Primitives`), sitting *at/below* the Memory line. **Downward — not a violation.**
- `swift-set-algebra-primitives → swift-algebra-primitives` — a **pure downward** bridge; depends on no
  concrete ADT (`Set.Ordered` appears only in comments). **Not a violation.**

**Intra-rung lateral edges (within one strata rung — enumerated, all sanctioned or to-confirm):**

| Edge | Rung | Verdict |
|---|---|---|
| `memory-small → {memory-heap, memory-inline}` | Memory | **Sanctioned** (§1.2.1: Small *is* inline⊕heap-spill — composition, not re-impl) |
| `memory-unbounded → memory-aligned` | Memory | Sanctioned-shape (growth over a location leaf) — but the package itself DISSOLVEs |
| `queue-linked → {queue, list-linked}` · `deque → queue` · `list ↔ list-linked` | ADT | Peer/sub-product reuse + umbrella re-export — not cross-macro-layer; OK |
| `tree-keyed → {dictionary, dictionary-ordered}` · `cache → dictionary` | ADT | Legit container-HAS-A (keyed-tree / cache index) — **confirm intended, not a missing pull-down** |
| `set-ordered → hash-table` · `dictionary → {set, hash-table}` | ADT | Compose the `Hash.Table` *substrate* (not peer ADTs) — clean |

**The only structural smell is placement, not dependency-direction:** the §5.4 allocation-axis duplication
(`Storage.Pool`/`Storage.Arena` compose `Memory.Pool`/`Memory.Arena`; `Buffer.Arena` rides `Storage.Arena`),
already dispositioned **DISSOLVE/deferred-arc** in §A.

### B.3 — End-state dependency deltas (after the §A dispositions land)

| Change | Edge effect |
|---|---|
| `storage-pool` / `storage-arena` **DISSOLVE** | `buffer-linked → storage-pool` becomes `buffer-linked → memory-pool` (via `Storage.Contiguous<Memory.Pool>`); `buffer-arena → storage-arena` becomes `→ memory-arena`. The two §5.4 façade packages' inbound edges re-route to the Memory leaves; the packages retire. |
| `memory-unbounded` **DISSOLVE** | its `→ memory-aligned` + `→ growth` edges retire; consumers use a Location leaf ⊗ `Growable`. |
| `memory-buffer` **RELOCATE → span** | its raw-view role + inbound edges move under `swift-span-primitives`. |
| `memory-aligned` **MERGE → Memory.Heap** (option) | folds the aligned-allocation leaf into Heap (alignment param); else stays as an explicit sibling leaf. |
| `slab` ADT **RELOCATE/MERGE** (low-pri) | its single consumer composes `Buffer.Slab` directly; the façade folds. |
| **gaps realized** | `index` gains `Index.Bounded<N>`; `growth` gains the `Growable` marker; `memory-arena`/`memory-pool` gain `Memory.Allocator.Protocol` conformance. |

---

## §C — Delta-list (dependency-ordered worklist for Cleave #7)

Ordered leaves-first (dissolve/relocate the leaves before the roots). **Mechanical** = rename/dissolve/strip,
no design decision. **Design-needed** = a forced-exception adjudication or a calculus-gap to realize.

### C.1 — Mechanical (Cleave-7 scope; no new design)

1. **DISSOLVE residual ADT location variants** (leaves first):
   `List.Linked.{Inline,Small}` (root) → then the `Queue.Linked.{Inline,Small}` pass-throughs that delegate to
   them → `Tree.N.{Inline,Small}` → `Bitset.Small`. (Consumers compose the inline/spill discipline directly.)
2. **Strip dead variant residue** (no live type; comments/enums only): `__SetOrderedInlineError` +
   set-ordered Static/Small MARKs; `__TreeUnbounded{Small,Bounded}Error`; dict-ordered "Static/Small" header
   + stray `memory-small` dep; the dead `.Static/.Small` doc-comments in array/queue/deque/heap/list-linked.
3. **Delete `span` `My*` scratch types** (`MyView`/`MyOwnedRegion`/`MyMutableRegion`).
4. **Resolve the `Buffer.Linked.Inline` naming question** (the spec's open item): the sparse-inline buffer
   variants are **forced-keeps** — `Buffer.{Slab,Linked,Arena}.{Inline,Small}` retain their suffix (Shape-α).
   No rename. (This is the C-list's *answer*, not an action.)

### C.2 — Design-needed (forced-exception adjudications + calculus gaps — surface to the seat)

5. **The deferred out-of-line allocation arc** (its own cleave, NOT mechanical Cleave-7): DISSOLVE
   `Storage.Pool`/`Storage.Arena` → `Memory.Pool`/`Memory.Arena` + `Storage.Contiguous<…>`; retarget
   `Buffer.Arena`; add `Memory.Allocator.Protocol` conformance to `Memory.{Arena,Pool}`; resolve the
   `Allocator`(calculus) vs `Allocatable`(live) naming. Seat-acknowledged (Shape-α §5.4-smell), execution parked.
6. **`memory-aligned`**: MERGE into `Memory.Heap` (alignment param) vs keep as an explicit aligned leaf.
7. **`memory-unbounded`**: DISSOLVE into a Location leaf ⊗ `Growable` (depends on realizing the `Growable` marker).
8. **`memory-buffer`**: RELOCATE the integer-address raw view into `swift-span-primitives`.
9. **`slab` ADT**: RELOCATE/MERGE the near-empty façade into `Buffer.Slab` or its sole consumer.
10. **`slice`**: reserve the namespace vs DISSOLVE the empty package.
11. **Realize the calculus end-state gaps**: `Index<Element>.Bounded<N>` (index); the `Growable` leaf-marker
    (growth). These are the §5.3 capacity-axis homes the map proves are currently unbuilt.

### C.3 — The hard-floor line (KEPT — never "cleaned up")

| Forced exception | The wall that forces it |
|---|---|
| `Buffer.{Slab,Linked,Arena}.{Inline,Small}` KEPT as concrete variants (not pure-generic) | **Wall 1** — SE-0427 `deinit ⟹ unconditionally ~Copyable`: a conditionally-`Copyable` generic buffer cannot host the buffer-level `deinit` the sparse occupancy teardown needs (`copyable_illegal_deinit`). A **converged design equilibrium** (Apple's `Box`; Rust's hoist-the-bound), NOT debt. |
| `Memory.Heap` teardown oracle in the leaf's backing `class` | bd04f32 — a conditionally-`Copyable` generic struct cannot carry `deinit` |
| `Memory.Inline` carries `Memory.Tracked` | D1 — a conditionally-`Copyable` inline struct can't self-deinit → the consumer needs the leaf's live-extent |
| `.Bounded`/`.Fixed`/`.Static`(capacity) KEPT this arc | capacity axis is Prism's; `Hash.Table.Static` independent per [DS-002] |

**The sparse-inline KEEP is permanent-but-removable (Cleave-7 resolution; [MOD-PLACE]).** Two distinct
compiler facts, kept separate:

- **Wall 1 (Sema, language law).** `deinit ⟹ unconditionally ~Copyable` (SE-0427) forces the concrete
  `.Inline`/`.Small` variant — the pure-generic spelling would need a *conditional* `deinit` (runs only for the
  `~Copyable` instantiations), which Swift does not have and which SE-0427 explicitly excludes. Cross-language
  norm (Rust E0184/E0367); the Swift team resolved the identical shape the same way (`[Pitch] Box`). **Removal
  gate:** dissolve to `Buffer<Storage.Contiguous<Memory.Inline>>.*` if/when Swift gains a conditional `deinit`
  for `~Copyable` — **LOW horizon**.
- **Wall 2 (IRGen, `swiftlang/swift#86652`).** Even the unconditionally-`~Copyable` composed buffer's `deinit`
  is *skipped cross-package* (its `@_rawLayout` is reached cross-module via `Storage.Contiguous<Memory.Inline>`).
  This is a **codegen bug, not a design leak** — same-package teardown is correct (the buffer-tier canaries
  pass). **Phase-2 reconciliation (2026-06-06):** the in-tower cross-package deinit *consumers*
  (`List.Linked.{Inline,Small}`, the `Queue.Linked` pass-throughs, `Tree.N.{Inline,Small}`, `Bitset.Small`) were
  **DISSOLVED** in §C.1 — so the #86652 cross-package deinit-skip **no longer manifests in the tower** (no
  in-tower ADT composes the kept inline buffers cross-package). The 6 family-2 tests were `.disabled(swift#86652)`
  only for the **Phase-1→Phase-2 interim**, then dissolved with `List.Linked.Inline`/`.Small` — they are **NOT**
  preserved-disabled. **Removal-gate tripwire (recommended, optional):** keep one preserved
  `.disabled(swift#86652)` cross-package deinit canary over a kept inline buffer so a future #86652 fix is
  detected (re-enable → it passes → remove the §C.3 KEEP-exception's Wall-2 framing). **Removal gate:** the
  upstream `#86652` fix (a parked ready-option — *not* this arc; it makes the kept composed inline buffers
  leak-free again whenever they ARE consumed cross-package).

`Memory.Inline._deinitWorkaround` is the SOLE `#86652` workaround in the nesting and is load-bearing (do NOT
remove; do NOT add a second buffer-level workaround — the double SIGSEGV-miscompiles on the nested substrate).
**Authority:** `Research/conditional-deinit-conditionally-copyable-generics.md` (the two-wall analysis +
empirical probe matrix S1–S8); `swift-compiler-bug-catalog.md` §A14 (Wall 2). Documented at three sites: each
variant source header; the `_deinitWorkaround` comments (`Memory.Inline`, `Buffer.Arena.Inline`); here.

---

## §D — Reconciliation findings (surfaced, not overruled — ground rules 3/4/5)

1. **Arena/Pool — aligned with the ratified docs, execution deferred.** `GOAL-msb-tower-end-state.md:12`
   keeps "Slab, Arena, Linked, **Pool**, Split, Slots" as *"topology disciplines KEPT (different topology, not
   location)"* — i.e. **kept because they are not *location* variants** (the location-dissolution arc doesn't
   touch them), NOT a ratification that Arena/Pool are permanently topology. **Cleave-6 Shape-α itself** calls
   `Buffer.Arena`'s name "a §5.4 placement-smell" and parks `Memory.Pool` leaf-ification as "a separate
   out-of-line allocation arc." So the calculus (Arena/Pool = *allocation* → Memory) and the ratified docs
   **agree on the smell**; the map classifies `Storage.Pool`/`Storage.Arena` **DISSOLVE (end-state)** + flags
   execution as that deferred arc. **No ratified keep is overruled.**
2. **The Pool/Slab "triplication" is mostly homonymy.** `swift-pool-primitives` `Pool` = an **async
   resource-pool ADT** (KEEP); `Memory.Pool` = the **free-list allocation leaf** (KEEP); `Storage.Pool` = the
   **façade to dissolve**. Two distinct concepts + one dissolve-target, not three copies of one. `Slab` ADT is a
   thin façade over the genuine `Buffer.Slab` discipline (KEEP, low-pri merge). **Confirm** the principal reads
   `GOAL`'s "Pool kept" as the discipline-not-dissolved-in-the-location-arc (it is), distinct from the
   resource-pool ADT.
3. **Sparse-inline forced-keeps** (`Buffer.{Slab,Linked,Arena}.{Inline,Small}`) are KEPT per Shape-α —
   structurally distinct from the dissolved **dense** `Buffer.{Linear,Ring}.Inline`. This is the hard-floor
   column's spine and the answer to the open `Buffer.Linked.Inline` naming question.
4. **Four calculus-vs-reality gaps** (per ground rule 4 — surfaced, not silently patched; these are
   *implementation* deltas from the calculus end-state, **not** flaws in the calculus): (a) `Memory.Arena/Pool`
   don't conform `Memory.Allocator.Protocol`; (b) `Index.Bounded<N>` unrealized; (c) the `Growable` leaf-marker
   unrealized; (d) `Allocator`(calculus) vs `Allocatable`(live) naming drift. Each is an end-state-form entry in
   §A and a delta in §C.2.

---

## Outcome

**Status: RECOMMENDATION.** The MSB tower's ~50 in-scope packages are classified once, exhaustively and
empirically: the Memory leaves + Storage/Buffer disciplines + ADT contracts + cross-cutting capabilities are
**overwhelmingly KEEP** (correctly placed); the live placement smells are the **§5.4 allocation-axis
duplication** (`Storage.Pool`/`Storage.Arena` DISSOLVE — a *deferred allocation arc*) and a short tail of
**residual ADT location variants** + **Memory-tier cleanup** (`memory-{aligned,unbounded,buffer}`). The
**strata dependency DAG is downward-clean — zero `[ARCH-LAYER-001]` violations** — the two suspect edges
(`memory-pool→bit-vector`, `set-algebra→algebra`) verified downward. The **hard-floor line** is the
sparse-inline forced-keeps (Shape-α) + the bd04f32 leaf-class teardown + the D1 `Memory.Inline` ledger. Four
calculus end-state forms are **unrealized gaps** (`Index.Bounded<N>`, the `Growable` marker, the
`Memory.Allocator.Protocol` conformance, the `Allocator/Allocatable` naming).

**What it feeds:** §C is **Cleave #7's worklist** (mechanical dissolves/strips now; the allocation arc +
Memory-tier merges as design-needed adjudications); the map is the target `[MOD-PLACE]` encodes. **Not in
scope and not done here:** production edits, executing the deltas (Cleave #6/#7 own that), the broader
ecosystem beyond the tower.

**Held for seat verification.** The swift-institute Research repo is **PUBLIC**; this note is **not pushed**.
No production source was touched; no competing probes were run.

---

## References

- **The calculus (authority):** `swift-institute/Research/decomposition-layer-placement-calculus.md` (Tier 3) —
  the placement principles applied here; see esp. §1.2.1 (Memory sub-axes), §5.4 (the partial inventory this
  makes exhaustive), §7 (`[MOD-PLACE]`).
- **Ratified reconciliation:** `.handoffs/GOAL-msb-tower-end-state.md` (+ D1/D1-correction);
  `.handoffs/GOAL-cleave-6-sparse-occupancy.md` (Cleave-6 **Shape-α**, 2026-06-06);
  `.handoffs/cleave-{5,6}-PROGRESS.md`; `.probe-bank/prism-endstate/end-state-research-note.md`.
- **Empirical basis:** five parallel verification subagents over the live `swift-primitives/` tree
  (2026-06-06); every row + every `Package.swift` file-verified, load-bearing `file:line` inline.
- **Skills:** `[ARCH-LAYER-001]` (downward-only deps); `[MOD-DOMAIN]`/`[MOD-031]`/`[MOD-035]`/`[MOD-RENT]`;
  `[DS-002]` (independent compile-time-capacity types); `[RES-013a]`/`[RES-019]`/`[RES-020]`/`[RES-023]`.
