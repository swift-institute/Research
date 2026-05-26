# World-B / Bulk-Span Decomposition

<!--
---
version: 1.2.0
last_updated: 2026-05-27
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - "1.2.0 (2026-05-27): Data-structures-split CONCLUDED → W1 owns the FULL cascade (no parallel owner;
     the earlier 'data-structure layer rides with the split' delegation is moot). Two dimensions now in
     W1 scope: (i) iterator-remap (Sequence.Iterator.`Protocol` → Iterator_Primitive.Iterator.`Protocol`;
     delete fake-bulk nextSpan) — the original concern (d); and (ii) attachable-match for the A2 rename
     (Sequence.`Protocol` → `Sequenceable` landed on swift-sequence-primitives main, breaking every live
     Sequence.Protocol consumer), routed per the consume/borrow PLACEMENT LAW: MULTIPASS (non-consuming
     makeIterator; container survives) → `Iterable`; SINGLE-PASS (consuming/give-away) → `Sequenceable`;
     classify per conformer; check iterator escapability (Copyable+Escapable satisfies Iterable's
     borrowing/@_lifetime automatically — bit-vector's one-line case; ~Copyable/~Escapable iterators need
     explicit `@_lifetime(borrow self) borrowing func makeIterator()`). Fresh conformance-anchored cascade
     (doc-comments/Experiments excluded): 22 packages = 17 attach-needing + 5 remap-only;
     collection-primitives confirmed CLEAN (0 live conformances — prior count was doc-comment false
     positives). Wave plan re-derived in DEPENDENCY order (rename-clean closure first), superseding the
     below/above-data-structure split. bit-vector landed as the combined-pattern sample
     (swift-bit-vector-primitives 9d0d229: 11 iterators remapped + 8 multipass conformers → Iterable; 70
     tests/11 suites green debug+release). Do-Not-Touch list now largely moot; sequencer-refactor branch
     stays off-limits; W4 target-removal stays [ARCH-LAYER-009]-gated."
  - "1.1.0 (2026-05-26): Decomposition APPROVED by principal. W0 re-scope folded in: (i) TRUE breaking
     cascade re-measured — 83 files / 214 reference lines across 21 consumer packages (not the ~17
     'mechanical' framing); wave plan re-sized on references, not conformer counts. (ii) Bulk iterator
     name finalized: Iterator.Contiguous → `Iterator.Chunk`, COMMITTED at swift-iterator-primitives
     `cbc7636`; doc now uses `Iterator.Chunk` throughout and the interim naming caveat is dropped.
     Execution gated: consumers-first waves, STOP before [ARCH-LAYER-009] target removal."
  - "1.0.0 (2026-05-26): Initial decomposition + migration mapping + wave plan; reconciles D-2 / Step-C /
     two-world / fold-vs-separate; Memory.Contiguous interrogated as first-class subject."
---
-->

> **Status — decomposition APPROVED (principal, 2026-05-26); execution GATED.** The
> dissolve-don't-relocate decomposition below is approved. Execution proceeds **consumers-first in
> waves, re-sized on the true cascade (W0), and STOPS before the physical removal of the three
> sequence-side targets** (which is `[ARCH-LAYER-009]`-gated, awaiting explicit authorization).
> **One-line thesis:** the three sequence-side bulk-span targets are four *facets of one historical
> artifact* — the bulk-first iterator inversion — and each facet's concern already has a canonical
> foundation home, so the correct move is **dissolve into existing compositions, add no new protocol.**

## Context

The iterator and memory foundations were built bottom-up; the ecosystem is now being **perfected
bottom-to-top**. `swift-iterator-primitives`, `swift-iterator-borrow-primitives`, and
`swift-memory-primitives` are the substrate being perfected first; the consumer data-structure
packages that ride the sequence-side iterator stack are **expected to refactor as a downstream
consequence**. Analysing the existing consumers is therefore *confirmatory* (it bounds the cascade
and shows the remap is mechanical), not the intellectual core — the core is *where each concern
correctly lives* once the foundation is right (principal's lens; supervisor ground rule #2).

The handoff (`HANDOFF-world-b-span-decomposition.md`) frames four World-B concerns to home:

- **(a)** raw contiguous-span access,
- **(b)** the consumer span-iteration API (`.span.forEach` / `.elements` / `.reduce`),
- **(c)** borrowing iteration over contiguous storage,
- **(d)** the bulk-first `nextSpan` iterator.

It asks for the semantically-correct decomposition (where each lives, optimizing decompose/compose),
the migration target for the consumers, and a wave plan — and to treat `Memory.Contiguous.Protocol`
as a *first-class subject*, not an assumed destination.

**The bulk iterator's name is settled.** The bulk-span iterator is **`Iterator.Chunk`** (in
`swift-iterator-primitives`, target `Iterator Chunk Primitives`), a *manner* name — it yields a
chunk/batch per step. It was renamed from the interim `Iterator.Contiguous` (which itself renamed
`Iterator.Span`), reserving the word `Contiguous` for the memory *subject* (`Memory.Contiguous`).
The rename is **committed at `cbc7636`** ("Rename Iterator.Contiguous -> Iterator.Chunk (bulk-tier
manner name)"); this doc uses `Iterator.Chunk` throughout. (Older predecessor docs that say
`Iterator.Span.Protocol` / `Iterator.Contiguous.Protocol` refer to the same type by its earlier
names.) The naming itself is the iteration-packages-finalization arc's decision, not this doc's; it
is recorded here only so the decomposition reads against the current name.

## Question

What is the semantically-correct home for each of concerns (a)–(d), under *decompose/compose +
semantic correctness*? Is `Memory.Contiguous.Protocol` the right home for (a), and is its shape
correctly decomposed? What is the (mechanical) consumer migration target, and in what wave order
does the cascade run?

## Reconciliation of standing decisions

Per supervisor ground rule #1 and `[HANDOFF-013]`, the cited prior work is reconciled explicitly —
extended, not overridden.

| Prior decision | Status | This doc's relationship |
|---|---|---|
| `collection-sequence-protocol-detachment.md` §Step-C (DECISION v1.1.0) — `Sequence.Borrowing.Protocol` is a *chunked-span optimization over `Memory.Contiguous.Protocol`*, **eventually removable**; borrowing iteration routes through `Collection.ForEach`; "Memory.Contiguous.Protocol exists — no need for new span protocol" (Constraint #4). | **Standing; extended.** | This doc *operationalizes* Step-C: confirms (a)'s home is `Memory.Contiguous`, confirms `Collection.ForEach` as the index-based borrowing route, and carries Step-C's "eventually removable" to *removed*. |
| `sequencer-primitives-reconciliation-refactor.md` §4b **D-2 (RESOLVED 2026-05-26 — RETIRE)** — a "borrowing sequence" decomposes to three non-overlapping primitives (`Iterator.Borrow.Protocol` + `Memory.Contiguous.Protocol` + `Iterable`); **no bulk-span protocol**; `Sequence.Span` reframed as a `Memory.Contiguous.Protocol` conformer; the "relocate as `Sequencer.Span.Protocol`" path **retracted**. | **Standing; controlling decision.** | This doc *agrees and completes* D-2: applies the same first-principles decomposition to all four handoff concerns, extends it to the consumer cascade, and supplies the Memory.Contiguous interrogation D-2 did not cover. |
| `sequencer-…-refactor.md` §15 / v0.10.0 — `Sequence.Borrow.Viewing` **REMOVED** as redundant: it duplicated `Ownership.Borrow<Output>` with no capability difference. Lesson: *a bespoke per-Map view earns its place only if it does something `Ownership.Borrow` can't.* | **Standing; governing anti-pattern.** | Applied here as the **redundancy-trap test** for Memory.Contiguous and the consumer remap. |
| `two-world-traversal-decomposition.md` (RECOMMENDATION v1.2.x) — "a borrowing iterator is the *existing* `Iterator.\`Protocol\`` with `Element == Ownership.Borrow<T>`"; no new top-level primitive. | **Standing; foundation.** | This doc fills the framework's "implicit-position span/bulk" World-B slot with **`Memory.Contiguous` (the span property) + `Iterator.Chunk` (the bulk iterator)** rather than a sequence-side protocol — the refinement D-2 introduced after two-world v1.2.x. |
| `bulk-span-iteration-fold-vs-separate.md` v1.0.0 (RECOMMENDATION, tier 3, 2026-05-26) — external-evidence survey (stdlib SE-0516, SE proposals, Forums); leans **decisively SEPARATE**, rejecting FOLD. Crux: `Span<Element>` requires `Element: Escapable` (SE-0447), so folding a Span-bulk hook onto one iterator protocol destroys `~Escapable`-element scalar iteration. | **Standing; corroborates this doc.** | Independent confirmation: bulk is a *separate* refinement of the scalar iterator (not folded), and D-2's "route contiguous-bulk to `Memory.Contiguous`" is its option (c), "evidence-compatible." This doc's decomposition agrees on substance. |
| `HANDOFF-iteration-packages-finalization.md` (Key Decisions / G1–G4) — the *separate* arc that settled the bulk-tier's placement + naming; it landed `Iterator.Chunk` (manner-name; `cbc7636`), reserving `Contiguous` for the memory *subject*, and builds the bulk tier on `Memory.Contiguous`. | **Out of scope here** (handoff: "Out: the iteration-package finalization"). | This doc consumes that arc's *outputs* (the `Iterator.Chunk` name; bulk-on-`Memory.Contiguous`) but does not make iteration-package decisions. Its "bulk composes over `Memory.Contiguous`" thesis is *reinforced* by that arc. |
| `memory/contiguous-memory-access-standardization.md` (DECISION) — uniform `var span` / `mutableSpan` / `withUnsafeBufferPointer` for **all** contiguous types. | **Standing.** | Confirms `Memory.Contiguous` is the canonical (a) surface. |
| `memory/span-access-abstraction.md` (DECIDED 2026-01-23) — "no protocol; ad-hoc `span` methods", artifacts removed incl. the old `Sequence.Span.Protocol`. | **Partially superseded** (`[RES-013a]`). | Verified against current source: `Memory.Contiguous.Protocol` now exists with **13 conformers** — the ecosystem evolved *from* "no protocol" *to* a shared span-access protocol. The Jan-23 "no protocol" stance no longer holds; its companion conclusion (retire the *sequence-side* span protocol) does, carried forward to today's `Sequence.Span` tag. |
| `nextspan-delegation-reduction.md` + `iterator-span-buffer-elimination.md` (DECISION v5.0.0) — across 97 conformers the theoretical-minimum heap-allocating bulk iterators is **zero**; empirically **single-element is 2–3× faster than batch**. | **Standing; key evidence.** | The data-structure `nextSpan` "bulk" carries *negative* performance value — retiring it is a win, not a regression. |

## Analysis

### The reframe: four concerns are facets of one inverted foundation

`Sequence.Iterator.Protocol` (`Sequence Iterator Primitives/Sequence.Iterator.Protocol.swift:109-131`,
*Verified: 2026-05-26*) makes `nextSpan(maximumCount:) -> Span<Element>` the **sole** iterator
requirement, deriving `next()` from it. The foundation iterator is the opposite —
`Iterator.Protocol` (`swift-iterator-primitives/.../Iterator.Protocol.swift:31-47`) makes
`next() -> Element?` the foundation and treats bulk as a *composed-on-top* refinement. The
sequencer doc §2 named this the **inverted foundation**.

The inversion is what spawned all four concerns. Making "lend a span" foundational forced every
container to: **(d)** implement a `nextSpan` iterator; **(c)** expose a `borrowing makeIterator`
returning it (`Sequence.Borrowing.Protocol`); **(b)** wrap that in a `.span.forEach` convenience
(`Sequence.Span`); and **(a)** ultimately have contiguous storage to lend a *real* span. Righting
the foundation (scalar-first, bulk as opt-in) collapses the four facets back into their true axes.

### The three true primitives — each already homed

Decomposed to first principles (identical to D-2's decomposition), a "World-B / bulk-span"
container is the composition of **three** orthogonal capabilities, each owning a canonical
foundation home today:

| True primitive | Canonical home (verified) | Shape |
|---|---|---|
| **"I have contiguous storage"** (the span) | `Memory.Contiguous.Protocol` (owned) / `Memory.Contiguous.Borrowed.Protocol` (borrowed) — `swift-memory-primitives` | `var span: Span<Element>` (+ `withUnsafeBufferPointer`); `Memory.ContiguousProtocol.swift:90-115`, `__Memory_Contiguous_Borrowed_Protocol.swift:41-56` |
| **"I produce elements one at a time"** (the iterator) | `Iterator.Protocol` (scalar foundation) — `swift-iterator-primitives` | `next() throws(Failure) -> Element?`, `Element: ~Copyable & ~Escapable` |
| **"I can be iterated, keeping myself"** (multipass attachable) | `Iterable` (+ borrowing terminal suite) — `swift-iterator-primitives`; `Collection.ForEach` (index route) — `swift-collection-primitives` | `borrowing makeIterator()`; `Iterable+ForEach.swift:21-46` |

…plus **two opt-in refinements that are named compositions, not new concepts**:

- **`Iterator.Chunk.Protocol`** (`= __IteratorChunkProtocol`, `swift-iterator-primitives/Sources/Iterator Chunk Primitives/`, committed `cbc7636`): *refines* `Iterator.Protocol`, narrowing `Element: Escapable` (a `Span` cannot hold `~Escapable` elements), adding `next(maximumCount:) -> Span<Element>`. Its concrete conformer `Iterator.Chunk` (`Iterator.Chunk.swift`) **wraps any `Swift.Span` and lends successive sub-spans** — so it composes over *any* `Memory.Contiguous.span`. This **is** the bulk-first iterator (concern (d)).
- **`Iterator.Borrow.Protocol`** (`swift-iterator-borrow-primitives/.../Iterator.Borrow.Protocol.swift:69-77`): *refines* `Iterator.Protocol` with `Element == Ownership.Borrow<Borrowed>`. Documented verbatim as "not a new concept — it is `Iterator.Protocol` instantiated with an `Ownership.Borrow` element." The scalar borrowing iterator.

### Decomposition: where each concern lives

| Concern | Sequence-side artifact retired | Correct home | Mechanism |
|---|---|---|---|
| **(a) raw contiguous-span access** | — (never sequence-side) | `Memory.Contiguous.Protocol` (owned) / `Memory.Contiguous.Borrowed.Protocol` (borrowed) | already canonical (13 conformers); Step-C #4; D-2 semantics ("lending a `Span` requires contiguous memory; its home is `Memory.Contiguous`"). |
| **(b) span-iteration convenience API** | `Sequence.Span` (tag + `Property.Inout` API) — **0 external consumers** | **Dissolves into composition**: element terminals → `Iterable` borrowing terminal suite (`forEach`/`reduce`/`contains`/`first`); the raw span → `Memory.Contiguous.span`; sub-span batching → `Iterator.Chunk(memory.span)`. | adding `.forEach`/`.reduce` *onto* a span would duplicate the `Iterable` suite + `Iterator.Chunk` (§15 trap). Per `iterator-span-buffer-elimination`, single-element beats batch 2–3×, so the batch API has *negative* value. |
| **(c) borrowing iteration** | `Sequence.Borrowing.Protocol` — **2 external consumers** (buffer-linear, buffer-ring) | element, index-addressable → `Collection.ForEach` (Step-C); element, non-indexed → `Iterable where Iterator: Iterator.Borrow.Protocol`. The "borrowing sequence" *is* that composition (D-2 §4a). | no bulk-span protocol; the concept is the composition, not a named type. |
| **(d) bulk-first `nextSpan` iterator** | `Sequence.Iterator.Protocol` — **22 conformers** | **genuine span-lenders** → `Iterator.Chunk.Protocol` (bulk); **everything else** → `Iterator.Protocol` (scalar). | the foundation inversion (sequencer §2); `a3953bb` already started the repoint. |

**Net: all three sequence-side targets dissolve; no new protocol is created.** (a) was already a
memory concern; (d) is an iterator concern with a canonical home; (b) and (c) are *compositions* of
(a)+iterator/iterable, never primitives in their own right.

### Memory.Contiguous as a first-class subject — verdict: correctly shaped; keep

1. **Right home for (a)?** **Yes.** Memory-domain "I have contiguous storage", clean owned/borrowed
   split, broad adoption (13 conformers incl. buffer-linear, binary, string, path, storage, lexer,
   cursors). Step-C #4 and D-2 both land here. No competing home should exist.
2. **Should (b) live *on* it, compose *over* it, or be `Collection.ForEach`?** **Compose over it /
   `Collection.ForEach` — never on it.** A `Memory.Contiguous` value has *one* span; "iterate it" is
   `for i in span.indices { span[i] }` (trivial), `Iterator.Chunk(memory.span)` (bulk abstraction),
   or element-borrowing via `Iterable` / `Collection.ForEach`. Putting `.forEach`/`.reduce` *on*
   `Memory.Contiguous` would duplicate the `Iterable` suite and `Iterator.Chunk` — the §15
   redundancy trap. "Iterate the span of a contiguous thing" is an **iterator/iterable** concern, not
   a **memory** concern. `Memory.Contiguous.Protocol` stays a pure *access* protocol (`var span` +
   `withUnsafeBufferPointer`).
3. **Is its `var span` + hoisted `Borrowed` variant correctly decomposed?** **Yes — no reshape.** The
   owned (`Memory.ContiguousProtocol`, `~Copyable`, `var span` borrowing self) vs borrowed
   (`__Memory_Contiguous_Borrowed_Protocol`, `~Copyable & ~Escapable` Self, `var span` with
   `@_lifetime(copy self)`) two-protocol split is **principled**: the witness-table contract for
   `var span` differs by lifetime regime, and a single protocol cannot polymorphically express both
   (documented at `__Memory_Contiguous_Borrowed_Protocol.swift:26-40`, precedent
   `__Ownership_Borrow_Protocol`). `Memory.Contiguous.Borrowed` (Pattern-1 passive projection) sits
   **parallel to** `Byte.Borrowed` / `Binary.Borrowed` / `Ownership.Borrow`, not duplicating them.
4. **Composition / redundancy trap:**
   - `Iterator.Chunk` *composes over* `Memory.Contiguous.span` → bulk iteration; no per-container
     bulk iterator needed for singly-contiguous types.
   - `Ownership.Borrow<T>` (a **one**-element borrow) vs `Memory.Contiguous.Borrowed` (a borrow of
     **many** / a span) are different cardinalities — **parallel, not redundant** (§15 satisfied).
   - `Collection.ForEach` (index/subscript borrowing) is orthogonal to `Memory.Contiguous` (raw
     span); a type can be both.

   **Non-blocking observations** (cosmetic): (i) `Memory.Contiguous` is a concrete generic struct
   that *also* acts as a namespace (hosts `.Protocol`/`.Borrowed` via typealias-on-the-struct,
   `Memory.Contiguous.swift:75`), slightly unlike the caseless-enum norm — documented, works. (ii)
   the owned protocol's hoisted spelling `Memory.ContiguousProtocol` is the standard SE-0404
   nesting workaround. Neither warrants a reshape.

### Redundancy elimination (the §15 lesson, applied to the consumers)

`buffer-linear` is the canonical instance (`Buffer.Linear+Sequence.Protocol.swift:13,44,56`,
*Verified: 2026-05-26*): its nested `Iterator` conforms `Sequence.Iterator.\`Protocol\`,
IteratorProtocol` and hand-rolls a contiguous `nextSpan`, **while Buffer.Linear separately conforms
`Memory.Contiguous.Protocol`** (so it already vends `.span`). The bespoke contiguous `nextSpan`
*duplicates* `Iterator.Chunk(self.span)`; it deletes (bulk = `Iterator.Chunk(span)`, scalar =
`Iterator.Protocol`).

The non-contiguous consumers are the other redundancy: tree, dictionary (verified) — and per
`iterator-span-buffer-elimination`'s 97-conformer inventory, the rest — implement `nextSpan` as the
**"Optional-inline" fake-bulk** pattern (`var _element: Element?` + `withUnsafeMutablePointer` +
`Span(_unsafeStart: ptr, count: ≤1)` + `_overrideLifetime`): a one-element span dressed as bulk,
pure `unsafe` ceremony duplicating `next()`. Repointing them to scalar `Iterator.Protocol`
**deletes the unsafe block** — a net simplification, and faster (single-element beats batch 2–3×).

## Outcome

**Status: RECOMMENDATION — decomposition APPROVED by principal (2026-05-26); execution gated.**

### Decision (approved): dissolve, don't relocate

Retire all three sequence-side bulk-span targets; route each concern to its existing canonical home;
**add no new protocol**:

- **(a)** raw span access → **`Memory.Contiguous.Protocol` / `.Borrowed.Protocol`** (keep as-is).
- **(b)** `.span.forEach`/`.elements`/`.reduce` → **dissolve** into `Iterable`'s borrowing terminal
  suite + `Memory.Contiguous.span` + `Iterator.Chunk`. Retire `Sequence.Span`.
- **(c)** borrowing iteration → **`Collection.ForEach`** (index) or **`Iterable where Iterator:
  Iterator.Borrow.Protocol`** (composition). Retire `Sequence.Borrowing.Protocol`.
- **(d)** bulk `nextSpan` iterator → **`Iterator.Chunk.Protocol`** (genuine span-lenders) or
  **`Iterator.Protocol`** (everything else). Retire `Sequence.Iterator.Protocol`.

### W0 re-scope (completed; the true cascade)

The wave plan is sized on **references that fail on deletion**, not conformer counts. Measured
workspace-wide on `main`, *Verified: 2026-05-26*:

- **Bulk iterator name: settled + stable.** `Iterator.Chunk` is **committed** at
  `swift-iterator-primitives cbc7636` (working tree clean for the `Iterator Chunk Primitives`
  target). Consumers may migrate onto a stable target — the in-flight concern is cleared.
- **True breaking cascade: 83 files / 214 reference lines across 21 consumer packages** (vs the
  ~17 "mechanical" framing). The decomposition is unchanged, but the *effort* is a genuine multi-wave
  migration. Per-package file counts (heaviest first):

  | Package | files | refs | | Package | files | refs |
  |---|---|---|---|---|---|---|
  | tree | 11 | 22 | | set | 4 | 12 |
  | bit-vector | 11 | 22 | | stack | 4 | 12 |
  | queue | 8 | 30 | | array | 3 | 9 |
  | dictionary | 7 | 16 | | bitset | 2 | 4 |
  | infinite | 6 | 11 | | buffer-linked | 2 | 4 |
  | heap | 5 | 15 | | graph | 2 | 4 |
  | buffer-linear | 4 | 13 | | hash-table | 2 | 4 |
  | buffer-ring | 4 | 13 | | list | 2 | 6 |
  | vector | 2 | 7 | | (buffer-slab, cyclic, finite, input) | 1 each | 2–3 |

  The work is still overwhelmingly *deletion* (fake-bulk `nextSpan` blocks), but across ~83 files.

### Migration target (mechanical mapping)

Per nested iterator, by its true shape:

| Class | Test | Target | Edit |
|---|---|---|---|
| **Scalar** (default; ~17 pkgs, the file-bulk: bit-vector, tree, dictionary, heap, queue, set, stack, list, vector, bitset, cyclic, finite, hash-table, buffer-linked, buffer-slab, graph, infinite) | non-contiguous; `nextSpan` is Optional-inline 1-element fake-bulk | `Iterator.Protocol` | **delete** the `nextSpan` block; keep `next()`; keep `Swift.IteratorProtocol` for interop. *Net deletion of `unsafe` code.* |
| **Contiguous** (array, buffer-linear) | singly-contiguous; conforms / can conform `Memory.Contiguous.Protocol` | `Memory.Contiguous.Protocol` + `Iterator.Protocol` | delete bespoke contiguous `nextSpan`; bulk = `Iterator.Chunk(span)`; retire `Sequence.Borrowing.Protocol` conformance. |
| **Piecewise** (buffer-ring) | genuinely multi-run (two-region) bulk — does something `Iterator.Chunk(one span)` can't | `Iterator.Chunk.Protocol` (direct conformer) | the one legitimate non-redundant bulk conformer; retire `Sequence.Borrowing.Protocol`. |

`graph` / `infinite` conform `Sequence.Iterator.Protocol` but **not** `Swift.IteratorProtocol` (pure
bulk-protocol conformers) → **Scalar** (their fake-bulk `nextSpan` → `Iterator.Protocol.next()`).

### Wave plan (gated; consumers-first; downstream-moot per principal)

| Wave | Scope | Notes |
|---|---|---|
| **W0 — re-scope + preconditions** ✅ done | True cascade measured (83 files / 214 refs); `Iterator.Chunk` confirmed committed (`cbc7636`); this doc updated to `Iterator.Chunk`. | Reported back before W1 per principal gate. |
| **W1 — Scalar remap (the bulk: ~17 pkgs / ~70 files)** | nested `Iterator` → `Iterator.Protocol`; delete fake-bulk `nextSpan`. | Independent per package → parallelizable. Net deletion of `unsafe`. Heaviest: tree (11), bit-vector (11), queue (8), dictionary (7), infinite (6), heap (5). Build + test GREEN (debug+release for borrow/span paths) and commit **per package/wave with explicit paths** (commit-as-you-go). |
| **W2 — Contiguous** | array, buffer-linear: ensure `Memory.Contiguous.Protocol`; delete bespoke `nextSpan`; bulk via `Iterator.Chunk`; retire `Sequence.Borrowing` conformance. | |
| **W3 — Piecewise** | buffer-ring: conform `Iterator.Chunk.Protocol` directly; retire `Sequence.Borrowing` conformance. | |
| **W4 — Sequence-side targets EMPTY but NOT removed** | After W1–W3, the three targets (`Sequence Borrowing`/`Span`/`Iterator` Primitives) have zero remaining consumers. | **STOP. `[ARCH-LAYER-009]` gate:** physical `Sources/<X>/` removal is forbidden pre-1.0 without explicit principal authorization. Surface the "ready to remove" state + verified zero-remaining-consumers proof; **do not delete.** |
| **W5 — Termination gate** | Workspace-wide grep (literal + generic-instantiated + conformance-position per `[HANDOFF-040]`/`[HANDOFF-050]`) → zero residual references; ecosystem `swift build --build-tests` across transitive consumers → green. | Completeness criterion. |

### Constraints honored / open

- **`Iterator.Chunk` is the stable target** (`cbc7636`); consumers migrate onto it, not onto a moving
  type. iterator-primitives has one unrelated dirty file — not touched.
- **`[ARCH-LAYER-009]`:** target *removal* (W4) is authorization-gated; the implementer STOPS before it.
- **Parallel work / no-interference:** Do-Not-Touch = swift-collection-primitives,
  swift-storage-pool-primitives, swift-storage-split-primitives, the `sequencer-refactor` branch.
  `Research/_index.json` has uncommitted parallel-session edits — **this doc's index entry is left for
  the index-owner** (suggested entry in `HANDOFF-world-b-span-decomposition.md` § Findings); not edited
  here per `[RES-003c]` transition clause + no-interference.
- **No push / no repo creation** during this work.

## References

- `swift-institute/Research/collection-sequence-protocol-detachment.md` v1.1.0 (DECISION) — Step-C; `Collection.ForEach`; Constraint #4.
- `swift-institute/Research/sequencer-primitives-reconciliation-refactor.md` v0.10.0 (DRAFT, tier 3) — D-2 retire; §2 inverted foundation; §15 `Sequence.Borrow.Viewing` redundancy lesson.
- `swift-institute/Research/two-world-traversal-decomposition.md` v1.2.x (RECOMMENDATION) — borrowing iterator = `Iterator.Protocol<Ownership.Borrow<T>>`.
- `swift-institute/Research/iterator-span-buffer-elimination.md` v5.0.0 (DECISION) — 97-conformer inventory; single-element 2–3× faster than batch; Optional-inline pattern.
- `swift-institute/Research/bulk-span-iteration-fold-vs-separate.md` v1.0.0 (RECOMMENDATION, tier 3) — SEPARATE-not-FOLD; the `Span`-requires-`Escapable` crux; stdlib SE-0516 corroboration. *Sibling in this arc; corroborates.*
- `swift-institute/Research/nextspan-delegation-reduction.md` (RECOMMENDATION) — delegation within the bulk world.
- `swift-institute/Research/view-vs-span-borrowed-access-types.md` v1.0.0 (DECISION) — layered borrowed-access hierarchy, each level dropping one guarantee.
- `swift-institute/Research/ownership-borrow-protocol-unification.md` (DECISION) — hoisted-Protocol + Type/Type.Borrowed convention (precedent for `Memory.Contiguous.Borrowed.Protocol`).
- `swift-memory-primitives/Research/contiguous-memory-access-standardization.md` (DECISION) — uniform `var span` for all contiguous types.
- `swift-memory-primitives/Research/span-access-abstraction.md` (DECIDED 2026-01-23) — *partially superseded* ("no protocol"; `Memory.Contiguous.Protocol` now exists, 13 conformers).
- `HANDOFF-iteration-packages-finalization.md` — the separate arc that landed the bulk-tier name `Iterator.Chunk` (`cbc7636`) + bulk-on-`Memory.Contiguous`; out of this doc's scope.
- Code (current `main`, *Verified: 2026-05-26*): `swift-iterator-primitives/Sources/{Iterator Protocol, Iterator Chunk Primitives, Iterable}` (`Iterator.Chunk` @ `cbc7636`); `swift-iterator-borrow-primitives/.../Iterator.Borrow.Protocol.swift`; `swift-memory-primitives/Sources/Memory Contiguous Primitives/*`; `swift-collection-primitives/Sources/Collection ForEach Primitives/*`; `swift-sequence-primitives/Sources/{Sequence Iterator, Sequence Span, Sequence Borrowing} Primitives/*`. Cascade scope: 83 files / 214 refs across 21 consumer packages.
