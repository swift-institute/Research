# W5 Consumer-Migration Playbook — Ledger, Census, Classification, Legs

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

Lane-2 of the post-ADT-tranche parallel dispatch (`HANDOFF-tower-flag-day-migration.md` STATUS, 2026-06-10):
read-only recon producing the W5 consumer-migration playbook. The five-layer tower (Memory → Allocator →
Storage → Buffer → ADTs) is reshaped through W4 plus the ADT-families tranche (legs 1–7 seat-verified;
leg 8 set/dict executing in parallel — its packages are EXCLUDED from this census's scope and owned by
that executor). W5 migrates every consumer of the withdrawn/re-spelled surfaces.

Inputs consolidated here: the W5-ledger entries scattered across the flag-day `## STATUS` (array W4b ·
queue leg-5 · deque leg-6 · linked W3b · slots W3b · Q3-B Fixed reshape); the Audit-#5 root-cause doc
(`container-protocol-lattice-borrowing-iteration.md`, R2); the alias-vocabulary doc
(`column-spelling-ergonomics-alias-vocabulary.md`, R4); the seat's `Fixed<S>` extraction recommendation
(`HANDOFF-tower-SEAT.md:34–37`).

[RES-019] prior-art check: no existing W5/consumer-migration doc in Research/ (closest structural
precedent: `collection-index-escapable-consumer-fallout.md`). All greps run 2026-06-10 against the live
trees of `~/Developer/{swift-primitives,swift-standards,swift-foundations}`; the set/dict family is
mid-edit by the leg-8 executor, so its counts are snapshots, not commitments.

## Question

Which consumers, exactly, does W5 touch; what does each need (mechanical re-spell · alias vocabulary ·
Audit-#5 relaxation · `Fixed<S>` · linked-round); how big is the cascade; in what order do the legs run;
and what do the two principal-decision riders (alias-vocabulary naming, `Fixed<S>` extraction) look like
concretely?

## §1 The consolidated W5 withdrawal ledger

One row per withdrawn/re-spelled surface, with the migration target. Sources: STATUS lines for W4b
(array), leg 5 (queue), leg 6 (deque), W3b (linked, slots), Q3-B ruling.

| # | Withdrawn surface | Origin | Migration target |
|---|---|---|---|
| L1 | `Array<E>` element-keyed spelling | W4b | `Array<S>` over a column (`Array<Column.Heap<E>>` once the vocabulary exists) |
| L2 | `Array<E>.Fixed` (nested) | Q3-B | top-level `@frozen Fixed<S>` (currently in array-primitives, modules `Array Fixed Primitive(+s)`) |
| L3 | `Array.Bounded` | Q3-B | DELETED — bounded buffer column `Buffer.Linear.Bounded` is the seam-conforming column instead |
| L4 | `ExpressibleByArrayLiteral` + `Array.Builder` | W4b | none (conformances cannot pin a free element param); literal call sites re-materialize as constructors |
| L5 | `Collection.Remove.Last` conformance on Array | W4b | generic `removeLast()` member (ungated seam witness was a CoW violation) |
| L6 | base-`Array` `Equation`/`Hash.Protocol` carriers | W4b | `Shared` is the element-keyed carrier; ADTs chain S5 (`where S: Equatable`); `Fixed` KEEPS both |
| L7 | `Array<E>.Small` | pre-W4 | Q2 straggler — `Store.Small<E,n>` storage-tier column (UNSCHEDULED; consumers blocked on it) |
| L8 | `Queue<E>` element-keyed + `Queue.Fixed`(+`.Error`) | leg 5 | `Queue<S>`; Fixed dissolves to `Queue<Buffer.Ring.Bounded column>` with typed-throws `Queue<S>.Error.full` |
| L9 | `Queue.Builder` · `Input.Streaming` conformance · `Sequence.Drain` view · hand-rolled Copyable `Equatable`/`Hashable`/CoW · queue re-exports (Collection/Index/Input) | leg 5 | generic `drain()`; Input.Streaming re-chainable on demand; S5 carriers; explicit imports |
| L10 | `Deque<E>` element-keyed + `.Fixed`(+Error) + Copyable-keyed `Iterable`/`Sequenceable` + `.Accessor` views + hand-rolled CoW | leg 6 | `Queue<S>.DoubleEnded` (+ welded `Deque<S>` typealias); `Queue<Ring.Bounded>.DoubleEnded` for Fixed |
| L11 | `Buffer.Linked` phantom-element surface: `.insert`/`.remove` nested-accessor views; `Buffer.Protocol`/`Equatable`/`Hashable`/`Iterable`/`Sequence`/`Drain` conformances; conditional Copyable+CoW; `.Inline`/`.Small` variant modules | W3b | direct pinned ops `insertFront`/`insertBack`/`removeFront`/`removeBack`; element-keyed semantics re-materialize at the linked-round ADT (queue-linked deferred per ruling D). `Link<N>` untouched (Async.Timer.Wheel safe) |
| L12 | `Buffer.Slots` returning pointer hatches `metadataPointer()`/`pointer(at:)` + CoW | W3b | scoped closure windows via `Store.Split.withLanes`/`withElements` etc. |
| L13 | pre-W2 arity `Buffer<Storage<E>.Contiguous<Memory.Heap<E>>>.X` | W2 | `Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.X` (the alias vocabulary exists to spell this) |
| L14 | element-typed `Memory.Inline<E, n>` + `.pointer(at:)` | W1 | raw `Memory.Inline<n>` (bytes) is W1's type; TYPED inline elements = `Store.Inline<E, n>` (4-op seam, per-op in-place access — no returning pointers) |
| L15 | `Memory.Tracked` chain · old product names "Storage Initialization Primitives" / "Storage Arena Primitives" / "Memory Tracked Primitives" | W2 | `Store.Protocol` seam · `Store Initialization Primitives` · `Storage Generational Primitives` |
| L16 | Audit-#5 regression: move-only-element direct columns lost `Collection.Protocol`/`Iterable` | W4 | the §4 relaxation (root-caused, change-shape verified — not record-and-accept) |

## §2 Consumer census (grep evidence, 2026-06-10)

Combined-pattern sweep (`Array<E>.Fixed/.Small`, `Array.Bounded`, `Queue.Fixed`, element-keyed
`Queue</Deque</Array<`, `Buffer.Linked` + views, old storage arity, `Memory.Inline<E,n>`,
`Sequence.Drain`, `.pointer(at:)`) across the three orgs, Sources + Tests, `.build` excluded.

**False positives, verified and excluded**: `swift-standards/swift-standards` (`Collections.Array.Fixed`
is standards' OWN type — no institute import); `swift-standard-library-extensions` + standards
`Array.Builder` (result-builders over `Swift.Array`); `swift-index-primitives`/`swift-input-primitives`
`Array.Bounded` (doc comments + Experiments only); all `Shared<` hits outside the tower are
`Ownership.Shared` (swift-ownership-primitives — a different type; coexists with top-level
`Shared<E,B>` without clash since one is nested). `property-primitives` hits are doc comments +
Experiments (no live source consumer).

**In-flight (leg-8 executor owns — NOT W5 scope)**: set, set-ordered, dictionary, dictionary-ordered,
hash-table (their RED pre-W2 spellings reshape inside the §6 legs).

### The W5 consumer set (Sources files affected / classification)

| Package | Files | What it uses | Class |
|---|---|---|---|
| swift-heap-primitives | 17 | old arity `Buffer<…>.Linear` throughout; `Sequence.Drain` | **A** + §6 disposition (pre-W2 ADT) |
| swift-tensor-primitives | 11 | old arity | **A** + §6 (also: no GitHub repo — publication gap) |
| swift-stack-primitives | 11 | old arity `.Linear` + `.Linear.Scalar` iterator (`Stack.swift:87`) | **A** |
| swift-async-primitives | 10 | `Queue<E>`/`Queue<E>.Fixed` typealiases + 3 `Queue.Fixed` extension files (`Async.Waiter.Queue.swift:70,76,82`); `Deque<E>` (Bridge/Broadcast/Mutex+Deque, old `.front.take` API); Timer.Wheel on buffer-ARENA + `Link<N>` (safe) | **B** (+E for Timer.Wheel) |
| swift-graph-primitives | 9 | 6+ `Array<Int>.Fixed(repeating:count:)` scratch tables (SCC/Subgraph/Path/Closure/Reverse); BFS `Queue<Index<Node>>` | **D** + A |
| swift-foundations/swift-async | 9 | old arity `…Ring.Bounded` stored fields (`Async.Stream.Buffer.Count.State.swift:30` etc.) | **A** |
| swift-buffer-slab-primitives | 12 | old arity + deleted product "Storage Initialization Primitives" ×4 | **F** (Slab W1-deferred; old dictionary's substrate dissolves at §6) |
| swift-buffer-arena-primitives | 6 | renamed product "Storage Arena Primitives" ×6 + old arity | **F** (superseded by Storage.Generational/SlotMap; Timer.Wheel is its consumer) |
| swift-list-linked-primitives | 6 | `_buffer.insert.front/.back`, `.remove.front/.back` (withdrawn views), old arity | **E** |
| swift-queue-linked-primitives | 10 | `Queue.Linked` over deleted `Buffer<…>.Linked<1>` shape | **E** (ruling D: RED through the tranche) |
| swift-pool-primitives | 5 | `Pool.Bounded.State.slots: Array<Slot>.Fixed` (:37), `entries: Tagged<Slot, Array<Entry>.Fixed>` (`Pool.Bounded.swift:81`); `Array<Async.Waiter.Resumption>` enum payloads; manifest product "Array Fixed Primitives" | **D** + B |
| swift-builder-primitives | 3–7 | old arity | **A** |
| swift-slab-primitives | 4 | old arity | **F** (rides buffer-slab disposition) |
| swift-memory-small-primitives | 4 | Memory.Tracked + old products; backs withdrawn `Array.Small` | **F** (Q2 → `Store.Small<E,n>`, unscheduled) |
| swift-tree-n-primitives | 4 | BFS `Queue<Index<Node>>` (`Tree.N.swift:641` etc.) | **A** |
| swift-tree-keyed-primitives | 2 | same | **A** |
| swift-tree-unbounded-primitives | 2 | `Queue<Int>` | **A** |
| swift-executor-primitives | 2 | `Executor.Job.Queue._storage: Deque<UnownedJob>` (:23); `Executor.Job.Deque.Static._storage: Memory.Inline<UnownedJob, N>` + `.pointer(at:)` (:31,92,112,135) | **A** (Job.Queue) + **L14** (Job.Deque.Static → `Store.Inline`) |
| swift-cache-primitives | 1 | `Array<Async.Waiter.Resumption>()` ×4 sites (`Cache.swift:260+`) | **B** |
| swift-byte-parser-primitives | 1 | `Input.Slice<Array<Byte>>` load-bearing typealias + `where Base == Array<Byte>` extension (`Byte.Input.swift:36,41`) | **C** + B (column choice: direct column is move-only; `Input.Slice` Base copyability to verify) |
| swift-foundations/swift-json | 3 | `Array<Byte>.Small<24>` ×2 (`JSON.Decode.Implementation.swift:580`, `JSON.Pull.Stream+Payload.swift:260`); Input.Streaming doc refs | **L7** (blocked on Q2 Store.Small) |
| swift-collection-primitives | 2 | `Collection.Remove.Last` home + Buffer.Linked doc ref | lattice home — rides §4, not a migration target |
| swift-sequence-primitives | 8 | `Sequence.Drain` home + conformers | lattice home — reconcile-later per standing memory |
| swift-foundations/swift-kernel, swift-glob, swift-version, swift-parser | ≤2 each | imports / light or test-only hits | **A** (verify at leg; likely manifest-only) |
| tail (machine, byte, ascii, binary[-parser/-serializer], memory-pool/-sequence/-cursor, file-system, foundations/swift-executors Experiments) | 1–4 each | mostly `Array<Byte>(` constructions, Drain mentions, experiment code | **A** tail — sweep at the end with guard greps |

**Manifests**: ~25 consumer `Package.swift` files declare deps on tower packages (grep `.product(name:`
— [HANDOFF-035]); 3 packages reference DELETED/RENAMED products today (buffer-slab ×4,
buffer-arena ×6, memory-small ×1).

## §3 Classification key + cascade size

- **A — mechanical re-spell** (~70 source files): old arity pins and element-keyed ADT spellings over
  Copyable elements; pure spelling change once the alias vocabulary exists. No design decisions.
- **B — needs the alias vocabulary in type position** (~20 files, subset overlaps A): stored
  properties/typealiases/enum payloads (async waiter typealiases, pool/cache payloads, byte-parser
  Input typealias, executor Deque field). Per-site COLUMN CHOICE rider: a direct column makes the
  enclosing type move-only; value-semantic enum payloads (pool/cache `Array<Resumption>`) take the
  `Shared` column. The R4 gate number (≈4.3 ns worst-case, 0 on direct columns; span-first bulk
  guidance) goes into the migration notes.
- **C — needs the Audit-#5 relaxation** (§4): any consumer needing `Collection.Protocol`/`Iterable`
  through the new ADTs — byte-parser's `Input.Slice<Array<Byte>>` is the concrete instance found;
  async's `~Copyable`-entry waiter queues benefit (generic `drain()` covers them today).
- **D — needs `Fixed<S>`** (§6): pool (stored invariant types) + graph (6+ scratch tables). Both
  currently spell `Array<E>.Fixed` (RED), so they migrate exactly once if the extraction lands first.
- **E — blocked-on-linked-round**: queue-linked (whole package), list-linked, async Timer.Wheel
  (partially — `Link<N>` safe, but it ALSO composes buffer-arena). Per ruling D the linked column rides
  the slot-map/linked round; these consumers CANNOT migrate now and must not be "unblocked" ad hoc.
- **F — straggler packages needing their own disposition** (NOT call-site migration): buffer-slab +
  slab, buffer-arena, memory-small (Q2), standalone memory-pool/memory-arena, memory-sequence,
  memory-cursor, plus the pre-W2 ADT packages heap/tensor/builder (and stack if not re-spelled
  interim). Each needs a reshape-vs-dissolve proposal to the principal; silently re-spelling them
  would bake in pre-tower designs.

**Total cascade (W5 proper, excluding E + F dispositions and the in-flight family): ~25 packages,
~110–130 source files + ~25 manifests.** Largest single legs: async-primitives (~10 files, real API
deltas) and the A-wave (~70 files, mechanical).

## §4 The Audit-#5 fix plan (from R2 — change-shapes verified, edits belong to the executor)

Root cause (3 layers, `container-protocol-lattice-borrowing-iteration.md`): the lattice protocols all
admit `~Copyable` elements; the gate is the CONFORMANCE `Buffer.Linear: Span.Protocol … S.Element:
Copyable` (`Buffer Linear Primitives/Buffer.Linear+Memory.Contiguous.Protocol.swift:15`), bundled in
the same file as the `withUnsafeBufferPointer` C-interop hatch; the raw `span` accessor one file over
is unbounded. The suspected `Collection.Protocol` structural wall is probe-REFUTED (borrow-through-call
reads through `{ get }` over `~Copyable` Element compile and run, debug + `-O`; consume-out correctly
rejected; probe preserved at `.handoffs/probes-2026-06-10/r2-lattice-probe/`).

Executor work items, in order:

1. Split `Buffer.Linear: Span.Protocol` (and `.Bounded`) out of the C-interop file; conform
   `where S: Span.Protocol & ~Copyable` with NO element bound; keep `withUnsafeBufferPointer` in its
   own `S.Element: Copyable` extension (check UBP generalization at implementation, not assumed).
2. Re-examine `Buffer.Linear: Iterable`'s extra `S: Copyable` (`+Iterable.swift:18`) — the chunk
   iterator wraps a Copyable `Span`; the storage-column bound looks unnecessary; verify at build.
3. Drop `S.Element: Copyable` from the Array/Fixed lattice extensions (`Array ~Copyable.swift:37,41,45`,
   `Array.Conformances.swift:25,63`, `Fixed ~Copyable.swift:35` + twins); keep every element-RETURNING
   convenience Copyable-gated (already the file layout). Witnesses stay `_read`/`borrowing get`.
4. NO new protocol, NO upstream-name chase: the borrowing-iteration layer ships already
   (`Sequence.Borrowing` + `__IteratorChunkProtocol`, SE-0516-convergent). One rename-alignment pass
   AFTER SE-0516 resolves (review closes **2026-06-18** — watch).
5. Gate-bump dossier riders: `SuppressedAssociatedTypes` flag dependency (whole lattice); SE-0474
   borrow/mutate accessors as the eventual `{ get }`-as-borrow replacement.

Sequencing constraint: this edits buffer-linear + array — **NOT parallel-safe** while the set/dict
executor runs (STATUS parallel-lanes note). It is also the W5-1 unblocker for every move-only-element
consumer, so it goes first once the tranche closes.

## §5 The alias-vocabulary module (R4 Option A, concretized — naming = principal's call)

Mechanism is settled (R4, probe-verified): generic typealiases under a non-generic namespace enum,
shipped as ONE importable module; consumers import it explicitly (Audit-#9 verbatim). What the
principal must pick: the namespace noun, the member nouns, and the package home.

**Namespace candidates** (one to pick):

| | Candidate | Spelling at a call site | For | Against |
|---|---|---|---|---|
| N1 | **`Column`** (recommended) | `Array<Column.Heap<Int>>` | the corpus's own design term ("two-column design", "direct column"); shortest; R4's lean | "column" is internal jargon — it leaks design vocabulary into every consumer signature |
| N2 | `Backing` | `Array<Backing.Heap<Int>>` | reads naturally to an outsider ("array with heap backing"); jargon-free | not a corpus term; one syllable longer |
| N3 | `Substrate` | `Array<Substrate.Heap<Int>>` | matches the ratified prose ("move-only substrate") | longest; prose term, not an API noun anywhere yet |

**Member-noun candidates** (orthogonal pick; nested second-level namespaces are probe-lawful, so
`Ring.Bounded` avoids compound names):

| | Set | Members | Note |
|---|---|---|---|
| M1 | **resource-true** (recommended) | `Heap<E>` · `Bounded<E>` (linear bounded) · `Ring<E>` + `Ring.Bounded<E>` · `Inline<E, n>` · `Generational<E>` · `Shared<E>` (= `Shared<E, Heap<E>>`) + as families land | mirrors the type names consumers already see in diagnostics; zero new vocabulary |
| M2 | role-named | `Growable<E>` · `Fixed<E>`(capacity) · `Cyclic<E>` (+`.Bounded`) · `Value<E>` (the CoW column — "value semantics") | reads as intent; but `Value` vs `Shared` renames the ratified combinator's role, and `Fixed<E>` collides with the `Fixed<S>` ADT noun — confusing |
| M3 | minimal start | `Heap<E>` + `Shared<E>` only; add members on demand | smallest permanent surface; defers the ring/inline nouns to their first consumer |

**Home**: a NEW package (e.g. `swift-column-primitives` per N-choice), single target, depending on
shared + buffer-linear + buffer-ring (+ slot-map/store-inline as members land). It cannot live in
`swift-buffer-primitives` (the namespace package is a DEPENDENCY of the column packages — inverted
direction) nor in a generic type (R4: nested-in-generic aliases are unusable). Zero re-exports; pure
typealiases; @frozen does not apply (no stored types). Ships BEFORE or WITH the first consumer leg —
every B-class site spells through it.

## §6 The `Fixed<S>` extraction plan (seat recommendation, concretized — principal ratifies)

**What moves**: `Fixed<S>` + its column/ops/carrier files (targets `Array Fixed Primitive(+s)` in
swift-array-primitives) → NEW repo `swift-fixed-primitives`, truth-renamed modules
`Fixed Primitive(+s)`. The seat's premise "zero external consumers until W5 keeps the window cheap" is
REFUTED in the letter (pool + graph consume `Array<E>.Fixed` today, incl. the manifest product
"Array Fixed Primitives" at `swift-pool-primitives/Package.swift:80`) but holds in spirit: both spell
the WITHDRAWN nested form, are RED against the new tower, and migrate exactly once if extraction lands
before their leg.

**The `__ArrayProtocol` home decides with it** (`Array Protocol Primitives` target;
`Array.Protocol.swift:20`; refines `Collection.Bidirectional`; conformers: `Array`
(`Array ~Copyable.swift:45`) and `Fixed` (`Fixed ~Copyable.swift:35` — currently Audit-#5-gated, bound
drops with §4). Post-extraction, `Fixed` can no longer reach a protocol housed in array-primitives
without depending on Array — wrong truth. Options:

- **P1 (recommended): own package** `swift-array-protocol-primitives` (or hoist the target into the
  extraction repo set as its own repo) — dep direction true (array → protocol ← fixed), tiny, matches
  the one-protocol-package precedent (Store Ledgered). The `Array.Protocol` namespaced alias STAYS in
  array-primitives (the alias needs the `Array` namespace); `Fixed` keeps conforming the hoisted
  `__ArrayProtocol` name it already uses.
- P2: hoist into swift-collection-primitives — fewest packages, but a family protocol named Array
  living in collection-primitives blurs the family boundary.
- P3: keep in array-primitives; fixed-primitives declares a product-level dep on it — smallest diff,
  but repo-level Fixed→Array dependency contradicts the truth-rename's whole point.

**Mechanical sequence**: create repo (PRIVATE; repo creation = principal YES; register in mirrors.json
like shared/slot-map) → move targets + truth-rename → array-primitives drops the products + umbrella
line → pool/graph manifests repoint at their leg → guard grep `Array_Fixed_|Array<.*>\.Fixed` zero-hit.
Sequencing: AFTER set/dict completes (mutates the executor's dep graph), BEFORE the pool/graph legs.

## §7 W5 leg sequencing

Gate G0 (hard): the §6 set/dict legs complete + seat-blessed. The three tower-side items (§4
relaxation, §5 vocabulary, §6 extraction) all mutate the live dep graph — STATUS lists them as
not-parallel-safe.

| Leg | Content | Preconditions |
|---|---|---|
| W5-1 | Tower-side unblockers: §4 Audit-#5 relaxation (buffer-linear + array/fixed) · §5 vocabulary package · §6 Fixed extraction + protocol home | G0 + principal picks (§5 names, §6 ratification + repo YES) |
| W5-2 | Mechanical A-wave: trees ×3 · graph (+`Fixed<S>`) · stack · foundations/swift-async · cache · executor (Job.Queue re-spell; Job.Deque.Static → `Store.Inline<E,n>`) · kernel/glob/version/parser verify | W5-1 |
| W5-3 | async-primitives (waiter typealiases → bounded/growable queue columns; Deque API deltas `.front.take` → `take(from:)`; Bridge/Broadcast/Mutex+Deque; Timer.Wheel DEFERRED to W5-6) · pool (Fixed stored types + `Shared`-column payloads) | W5-1 (+W5-2 experience) |
| W5-4 | Parser chain: byte-parser `Input.Slice<Array<Byte>>` column decision (verify `Input.Slice` Base-copyability; expect `Shared` column or §4-relaxed borrow path) · json `Array<Byte>.Small` rides Q2 (`Store.Small<E,n>` — propose scheduling or interim heap column) | W5-1; Q2 decision for json |
| W5-5 | Straggler dispositions (PROPOSE, don't silently migrate): heap/tensor/builder (template-ADT reshape vs interim re-spell) · buffer-slab+slab (dissolve toward §6 substrate?) · buffer-arena (dissolve toward Storage.Generational; unblocks Timer.Wheel) · memory-small (Q2) · standalone memory-pool/arena/sequence/cursor | per-package principal rulings |
| W5-6 | Linked round consumers: queue-linked, list-linked, Timer.Wheel — AFTER the linked-column ADT round ships (ruling D) | the linked/slot-map ADT round |
| W5-7 | Closure: manifest sweep (~25 `Package.swift`, incl. the 11 stale-product references) · guard greps zero-hit (the L1–L16 patterns) · full tower build + test on 6.3.2 | all above |

Per-leg discipline = the flag-day rules verbatim: 6.3.2 only, commit-per-package explicit paths, never
push, zero warnings full-grep, debug+release, [DS-024] laws where a new column composes, HALT-on-wall
with minimal repro, STATUS entry per leg.

## Outcome

**Status: RECOMMENDATION** (read-only recon; no package edited). Deliverables: this playbook + the
draft W5 executor goal at `.handoffs/GOAL-tower-w5-consumers.md`. Held for the principal: §5 naming
(N×M pick + package name), §6 ratification (+ repo-creation YES, P1/P2/P3), Q2 scheduling (json
blocked), the W5-5 straggler dispositions, and G0 timing.

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Census completeness | premise | grep-based over live trees; spelling-pattern misses (e.g. literal-init `= [...]` sites for L4) surface at the per-leg builds — the legs' gates are the backstop |
| set/dict-family counts | snapshot | leg-8 executor owns them; re-census at G0 |
| `Input.Slice` Base-copyability requirement | direction | verify at W5-4 (decides Shared-column vs borrow path) |
| `Ownership.Shared` vs top-level `Shared` coexistence | noted | distinct types (nested vs top-level); no clash found; watch first package importing both unqualified |
| Pre-W2 ADT packages' end-state (heap/stack/tensor/builder) | direction | W5-5 proposals; interim re-spell keeps them building but bakes nothing |
| Timer.Wheel's buffer-arena dependency | direction | rides the W5-5 buffer-arena disposition + W5-6 linked round |

## References

- **Ledger sources**: `.handoffs/HANDOFF-tower-flag-day-migration.md` STATUS (W4b :92; leg-5 :61;
  leg-6 :60; linked :79; slots :82; Q3-B :97; W5 guard :107); `HANDOFF-tower-SEAT.md:34–37` (Fixed
  extraction), :117 (Audit-#5 flag).
- **Research parents**: `container-protocol-lattice-borrowing-iteration.md` (R2; §4 here);
  `column-spelling-ergonomics-alias-vocabulary.md` (R4; §5 here);
  `stdlib-array-family-source-archaeology.md`; `collection-index-escapable-consumer-fallout.md`
  (structural precedent).
- **Census sites** (load-bearing examples): graph `Graph.Sequential.Analyze.SCC.swift:24–25`; pool
  `Pool.Bounded.swift:81`, `Pool.Bounded.State.swift:37`, `Package.swift:80`; async
  `Async.Waiter.Queue.swift:70,76,82`, `Queue.Fixed+Async.Waiter.swift:16+`, `Async.Bridge.swift:77`;
  executor `Executor.Job.Queue.swift:23`, `Executor.Job.Deque.Static.swift:31,92`; foundations-async
  `Async.Stream.Buffer.Count.State.swift:30`; byte-parser `Byte.Input.swift:36,41`; json
  `JSON.Decode.Implementation.swift:580`; stack `Stack.swift:87`; trees `Tree.N.swift:641`,
  `Tree.Keyed.Traversal.swift:90`, `Tree.Unbounded.swift:557`; list-linked
  `List.Linked Copyable.swift:25–48`; array `Array.Protocol.swift:20`, `Fixed ~Copyable.swift:35`.
- **Probes**: `.handoffs/probes-2026-06-10/r2-lattice-probe/`, `r4-alias-gate-probe/` (preserved).
