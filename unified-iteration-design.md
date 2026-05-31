# Unified Iteration Design — the Single Design Authority + ×16 Fan-Out Template

<!--
---
version: 2.2.0
last_updated: 2026-05-30
status: APPROVED
tier: 2
scope: cross-package
supervises_gate: "RE-ALIGNED 2026-05-30 (user-ratified) to the SPAN-PRIMITIVE shape per SE-0516 (`iterable-se0516-alignment.md`, RECOMMENDATION, principal-verified from disk + the stdlib clone). `Iterable`'s iterator is now the SPAN protocol (`__IteratorChunkProtocol`, element bound relaxed Escapable→~Copyable, scalar-protocol refinement dropped), NOT the scalar `Iterator.Protocol`. ONE span iterator (`Iterator.Chunk` over `span`) serves BOTH element kinds (`span[i]` is a borrowing addressor — never a move-out). Set.Ordered + the buffer family get `Iterable` (~Copyable) FOR FREE via the memory→Iterable bridge relaxed Copyable→~Copyable over `span` — no per-variant makeIterator, no Storage composition, no public base, no Iterator.Borrow.Scalar vend. `Iterator.Borrow.Scalar`'s ITERATION role is WITHDRAWN; the package is PARKED (not reverted — [ARCH-LAYER-009]). The ×16 fan-out (§4) is still GATED. Per-action YES still required for: publish · visibility flip · tag · starting the fan-out. Execution coordination: HANDOFF-data-structure-iteration-arc.md. NEXT STEP: a verify-plan agent re-verifies this plan, assesses ground-state, and produces the implementation plan."
consolidates: "This doc is the SINGLE design authority for the iteration arc (2026-05-30). It folds in and REPLACES (the originals removed to stop drift): iteration-architecture-expressibility-envelope.md (Angles A/B/C), two-world-traversal-decomposition.md (World A/B), world-b-span-decomposition.md (World-B decomposition), memory-contiguous-iteration-bridge.md (the bridge + Memory.Cursor + withdrawn Iterator.Walk), sequencer-primitives-reconciliation-refactor.md (terminal relocation + Sequencer naming), swift-iterator-primitives/Research/iterable-iteration-terminal-surface.md (the borrowing-func surface decision). Empirical evidence is retained in Experiments/iteration-architecture-toy + Experiments/memory-cursor-generic-witness-demangle (NOT removed)."
builds_on:
  - "iterable-se0516-alignment.md (Tier 2, RECOMMENDATION, principal-ratified 2026-05-30) — the span-primitive realignment; the SE-0516 ↔ institute mapping, the delta D1–D8, the Iterator.Borrow disposition. THIS is the superseding source for §2.1/§2.3/§2.5/§3/§6."
  - "bulk-span-iteration-fold-vs-separate.md (Tier 3, RECOMMENDATION) — the Span<~Copyable> crux verified against the stdlib clone; SE-0516's rejection of element-wrapping. Its SEPARATE-vs-FOLD recommendation is NARROWED, not overturned (it governs ~Escapable-element scalar iteration, which stays on Iterator.Protocol)."
  - "Experiments/iteration-architecture-toy 8ae35fb (the Angle A/B/C empirical proof, debug+release, full ecosystem flags)"
  - "memory-cursor-generic-witness-demangle-reshape.md v1.0.0 (the consuming-iterator reshape — KEPT)"
  - "swift-iterator-borrow-primitives (Iterator.Borrow.Scalar shipped f31ce11/dd60699; iteration role WITHDRAWN under the span realignment — PARKED, not reverted, for a possible non-iteration scalar keep-and-lend cursor role)"
changelog:
  - "2.2.0 (2026-05-30): SPAN-PRIMITIVE RE-ALIGNMENT (user-ratified; supersedes the v2.1.x Option-C keystone). Root cause of the week-long iteration knot, found via the user's SE-0516 anchor + verified from disk: the institute `Iterable` was SCALAR-primitive (its iterator = the move-out `Iterator.Protocol.next() -> Element?`, Iterable.swift:45 / Iterator.Protocol.swift:46), which is the ~Copyable move-out wall — the entire Iterator.Borrow detour was solving a problem SE-0516 designs away. SE-0516 is SPAN-primitive: the iterator's sole element-access is `nextSpan(maximumCount:) -> Span<Element>` (no scalar next()); `Span<Element: ~Copyable>` (Span.swift:29) + the borrowing-addressor subscript make ONE span iterator serve both kinds (span[i] borrows, never moves out). The institute ALREADY ships the machinery — `Iterator.Chunk` ≅ SpanIterator, `__IteratorChunkProtocol` ≅ BorrowingIteratorProtocol — so alignment is RE-POINTING + RELAXATION, not invention: (D2) re-point `Iterable.Iterator` from the scalar protocol to `__IteratorChunkProtocol`; (D1) relax that protocol's element bound Escapable→~Copyable AND drop its `: Iterator.\\`Protocol\\`` refinement (verified __IteratorChunkProtocol.swift:34-35 — the Escapable bound + the scalar refinement; the Chunk struct itself has no bound, Iterator.Chunk.swift:26); (D3) rebuild `forEach` on the span loop (subsumes the bespoke Memory.Contiguous floor; drops the Copyable gate; both kinds); (D4) relax the memory→Iterable bridge Copyable→~Copyable; (D5) Set.Ordered + buffers get `Iterable` (~Copyable) via the bridge over `span` — ONE conformance, the dual-element-kind split DISSOLVES, NO per-variant makeIterator / NO Storage composition / NO public base / NO Iterator.Borrow.Scalar vend; (D6) Iterator.Borrow.Scalar iteration role WITHDRAWN — PARK, do NOT revert f31ce11/dd60699 ([ARCH-LAYER-009]). The scalar `Iterator.Protocol` STAYS as the consuming/give-away foundation for `Sequenceable` (World A) and the ~Escapable-element ceiling. T1 (associatedtype Storage on Buffer.Protocol) stays rejected. One open build-verify gate: Iterator.Chunk(span) over inline @_rawLayout storage for ~Copyable. §1.2/§2.1/§2.3/§2.5/§3/§4/§5/§6.1/§6.3/§6.5/§7 re-aligned."
  - "2.1.1 (2026-05-30): CORRECTED the v2.1.0 mechanism — `Buffer.Linear: Storage.Protocol` is a CATEGORY ERROR (subordinate + user caught it; supervisor accepted). Buffer is the logical capability (count/isEmpty), storage the physical (pointer(at:)/capacity); the chain is storage→buffer, so conforming buffer→storage inverts the layer and is the refinement-stacking §1 forbids — and the codebase already composes (linear ops are Storage.Protocol statics taking storage:+count:; Small's two-armed _Representation has no single Storage to surface). REVISED to OPTION C (composition): each Buffer.Linear variant conforms Iterable (~Copyable) with a thin per-variant makeIterator constructing Iterator.Borrow.Scalar(base: storage.pointer(at:.zero), count:, borrowing: self) (Small switches); storage stays @usableFromInline internal — NO public base, NO Buffer.Linear:Storage.Protocol, NO separate bridge (better encapsulation than v2.1.0, [MOD-031] preserved; gate-de-risked via the InlineBag shape). Set.Ordered delegates. §2.5/§1.2/§3/§4/§5/§6.3/§7 corrected. [SUPERSEDED by 2.2.0 — Option C is replaced by the span-primitive shape; Iterator.Borrow.Scalar is parked.]"
  - "2.1.0 (2026-05-30): LOCKED Option C (user-authorized) for the ~Copyable borrow-iteration home. Iterator.Borrow.Scalar shipped (iterator-borrow f31ce11). DECISION: borrow-iteration composes over the Storage.Protocol (pointer(at:)→escaping base) + Buffer.Protocol (count) cores — NOT Swift.Span (verified wall: Span<~Copyable> has no escaping element address) and NOT the Memory.Contiguous bridge. Buffer.Linear conforms Storage.Protocol publicly, dissolving the per-type _iteratorBase() window ([ARCH-LAYER-011] hand-rolled duplicate); an `extension Iterable where Self: Storage.Protocol & Buffer.Protocol` bridge vends it; buffer-backed containers delegate. REJECTED Option A (escaping base on Memory.Contiguous — pollutes the safe-view core) + Option B′ (widen _iteratorBase() — perpetuates the duplicate). §2.5 + §1.2 rewritten. Open: the @_rawLayout inline variants' Storage.Protocol escaping-pointer(at:) soundness (build-verify gate)."
  - "2.0.0 (2026-05-30): CONSOLIDATION. Promoted to the single design authority; folded in the six iteration Research docs (Angles/World/bridge/terminal-relocation/terminal-surface) + their Dead-Ends + the D1–D5 rubric (§6). RECONCILED TO DISK on two axes the prior version got wrong: (1) CONSUME — Sequence.Consume.Protocol/View/ConsumeState was DELETED (sequence-primitives 309c1b9), NOT kept-and-widened; the consuming drain is now the closure terminal Sequenceable.consume(_:) (Sequenceable+Consume.swift:35/:59); §2.7 rewritten, §6.4 ConsumeState-widening escalation REMOVED (dead — the type was deleted), takeBuffer deleted (set-ordered 13ab89f). (2) RELEASE — set-ordered now builds RELEASE-clean via field-reorder (buffer-linear 2b82466, buffer-ring e103122); the #86652/debug-green caveats are removed. The A2 boxed-tree release SIL crash is separate and still stands."
  - "1.3.0–1.0.0 (2026-05-28): prior versions (recoverable via git). 1.3.0 escalated a ConsumeState ~Copyable widening that reality overtook by deleting the type."
---
-->

> **APPROVED — the single design authority for the data-structure iteration arc.** This realizes the
> decided iteration shape (UNIFIED family delegation) across the ~16 data-structure packages, with
> **set-ordered as the reference exemplar**. Execution state, gates, and loose ends live in the companion
> **`HANDOFF-data-structure-iteration-arc.md`** (the only working/coordination doc). This doc is the durable
> WHY: the protocols, the element-kind coverage, the folded rationale (Angles A/B/C, World A/B), and the
> fan-out recipe.
>
> **Reconciled to disk 2026-05-30 (v2.0.0):** the consuming drain is the closure terminal
> `Sequenceable.consume(_:)` (the `Sequence.Consume.Protocol`/`View`/`ConsumeState` module was *deleted*,
> not kept); set-ordered builds **release-clean** (the `#86652` caveats are gone; the A2 boxed-tree release
> crash is separate and still stands).
>
> **⚑ SPAN-PRIMITIVE RE-ALIGNMENT 2026-05-30 (v2.2.0, user-ratified) — read this first.** The v2.1.x
> Option-C keystone (§2.5: `~Copyable` pull-style via `Iterator.Borrow.Scalar` composed over the
> Storage+Buffer cores) is **SUPERSEDED**. The institute `Iterable` is realigned to **SE-0516's
> span-primitive shape**: its iterator is the **span** protocol (`__IteratorChunkProtocol`, element bound
> relaxed `Escapable → ~Copyable`, scalar-protocol refinement dropped), **not** the scalar
> `Iterator.\`Protocol\``. Because `Span<Element: ~Copyable>` exists and `Span`'s subscript is a *borrowing
> addressor* (never a move-out), **one span iterator (`Iterator.Chunk` over `span`) serves both element
> kinds** — which dissolves the move-out wall, the dual-element-kind split, AND the entire `Iterator.Borrow`
> detour. Set.Ordered + the buffer family get `Iterable` (~Copyable) **for free via the memory→Iterable
> bridge relaxed to `~Copyable`** — no per-variant `makeIterator`, no `Storage` composition, no public base.
> **The full WHY + the SE-0516 mapping + the delta (D1–D8) is `iterable-se0516-alignment.md`** (Tier 2,
> RECOMMENDATION, principal-ratified). The sections below are re-aligned to it; `Iterator.Borrow.Scalar` is
> **parked, not reverted** ([ARCH-LAYER-009]). One build-verify gate remains: `Iterator.Chunk(span)` over
> inline `@_rawLayout` storage for `~Copyable`.

---

## 1. Context

The data-structure iteration rebuild perfects **set-ordered** (+ **set-primitives**) as the exemplar, then
replicates to **~16** packages on a single iteration shape. The capability-protocol model that gated the
arc is **APPROVED (2026-05-28)**; the MODEL-FIRST pause is lifted.

The decided shape — **UNIFIED family delegation** — is proven end-to-end (debug+release, full ecosystem
flags) by the toy at `Experiments/iteration-architecture-toy` (`8ae35fb`), Phases 8–11 (the v1.3.0
re-attack). See §6 for the folded Angle A/B/C / World A/B rationale.

### 1.1 Verified current state (set-ordered HEAD `6af55a2`, 2026-05-30)

Per-variant iteration conformances today — `Iterable`/`Memory.Contiguous` gated `where Element: Copyable`:

| Conformance | Where | Notes |
|---|---|---|
| `Iterable` | iterator-primitives | `extension Set.Ordered: Iterable where Element: Copyable` (×4 variants) |
| `Sequenceable` | sequence-primitives | consuming `makeIterator()` → backing `Buffer<Element>.Linear.{variant}.Scalar` (hand-written scalar) |
| `Memory.Contiguous.\`Protocol\`` | memory | span-projecting substrate; `Set.Ordered` is `Memory.Contiguous` **where `Element: ~Copyable`** |
| `Sequence.Clearable` | sequence-primitives | `public protocol Clearable: Sequenceable & ~Copyable` (set-ordered conforms; ~Copyable-capable) |

- `forEach` is a per-variant `(borrowing Element) throws(E) -> Void` method (the borrow terminal) — to
  become the inherited `Iterable` floor. **Load-bearing caveat:** today it is the *only* ~Copyable forEach
  path (the `Iterable` conformance is `where Element: Copyable`), so do NOT delete it before the ~Copyable
  `Iterable` conformance (§2.5) is in place.
- **Consuming drain:** `Sequenceable.consume(_:)` — a CLOSURE terminal,
  `consuming func consume<E>(_ body: (consuming Element) throws(E) -> Void) throws(E)` (+ `Either` overload),
  symmetric to `forEach`. set-ordered uses it (folded `13ab89f`); the old `Sequence.Consume.Protocol`/`View`/
  `ConsumeState` + `takeBuffer` are **gone**.
- `Swift.Sequence` is **NOT** currently conformed (input-only) — a deliberate **re-add** target (§2.8).
- `makeIterator()` is **consuming** (the `Sequenceable` route), delegating to the backing's `.Scalar`.
- Small's `drain()` compiles for `~Copyable` only via a take-and-put-back workaround
  (`Set.Ordered.Small ~Copyable.swift` ~ll.139–141; direct `hashTable?.remove.all()` crashes
  `DiagnoseStaticExclusivity`). Evergreen redesign in §2.9.
- **Release:** set-ordered builds **release-clean** (field-reorder `2b82466`/`e103122` dodged `#86652`).

### 1.2 Real ecosystem protocol topology

| Concept | Real type | Package |
|---|---|---|
| Element-iteration floor (borrow-style) — **ground home for the terminal suite**; iterator is now **span-primitive** (§2.3) | `Iterable` | swift-iterator-primitives |
| Scalar foundation iterator (`next() -> Element?`, `@_lifetime(&self)`, move-out, extraction → `Escapable`) — **the consuming/give-away foundation for `Sequenceable` (World A) and the `~Escapable`-element ceiling; NO LONGER `Iterable`'s iterator** | `Iterator.\`Protocol\`` | swift-iterator-primitives |
| **Span-primitive bulk iterator** — `next(maximumCount:) -> Span<Element>` (the SE-0516 `nextSpan`); **now `Iterable`'s iterator** (§2.3). Element bound relaxes `Escapable → ~Copyable`; the `: Iterator.\`Protocol\`` refinement is dropped; **`Iterator.Chunk` over `span` serves BOTH element kinds** (`span[i]` borrows, never moves out) | `Iterator.Chunk` / `__IteratorChunkProtocol` | swift-iterator-primitives |
| `~Copyable` borrow-yielding **scalar** pull-style — `Element == Ownership.Borrow<Borrowed>`; `Iterator.Borrow.Scalar` shipped (`f31ce11`/`dd60699`). **ITERATION ROLE WITHDRAWN** under the span realignment (SE-0516 rejected this element-wrapping design); **PARKED, not reverted** ([ARCH-LAYER-009]); possible future non-iteration scalar keep-and-lend cursor | `Iterator.Borrow.\`Protocol\`` + `Iterator.Borrow.Scalar` | swift-iterator-borrow-primitives |
| Addressable storage core (`pointer(at:)` → escaping base, `capacity`) — composed (has-a) by buffers; **NOT the iteration vehicle** under the span realignment (the buffer exposes `span`, the bridge vends `Iterator.Chunk`) | `Storage.\`Protocol\`` | swift-storage-primitives |
| Sized core (`count`) | `Buffer.\`Protocol\`` | swift-buffer-primitives |
| Copyable + `~Escapable` borrow handle (the lent element) | `Ownership.Borrow<Value: ~Copyable & ~Escapable>: ~Escapable` | swift-ownership-primitives |
| Consuming / single-pass sibling (`~Copyable & ~Escapable`) — orthogonal, **NOT** refining `Iterable` | `Sequenceable` | swift-sequence-primitives |
| Span-projecting substrate witness (`var span: Span<Element>`) | `Memory.Contiguous.\`Protocol\`` | swift-memory-primitives |
| Lazy / eager consuming cursors (the deferred owned-cursor sibling; `Iterator.Walk` was withdrawn) | `Memory.Cursor` / `Memory.Snapshot.Cursor` (dormant) | swift-memory-cursor-primitives |
| Index-based collection (standalone; refines `Iterable` only at fan-out — §2.2) | `Collection.\`Protocol\`` | swift-collection-primitives |

`Sequenceable` carries the **extraction-vs-borrow split** (`associatedtype Element: ~Copyable & ~Escapable`;
borrowing terminals admit `~Escapable`, extraction terminals `collect`/`first` constrain `Element:
Escapable`) — the load-bearing prior art the decided shape rests on.

---

## 2. The decided shape, realized

Each sub-section states **(decided)** the locked element, **(realize)** the concrete mapping, and any
**(open)** item.

### 2.1 `forEach` floor on `Iterable` — the universal vehicle (Angle C); plain `borrowing func`

- **(decided)** `forEach` is the universal floor on `Iterable`: **every** structure gets it, including
  `~Copyable` (borrowing closure). The closure receives `(borrowing Element)` **directly** (NOT an
  `Ownership.Borrow` handle). `forEach` returns `Void`, so there is no lifetime-dependent return.
- **(RE-ALIGNED v2.2.0 — mechanism)** `forEach` is now built on the **span loop** over `Iterable`'s
  span-primitive iterator (§2.3), NOT the scalar `next()`: `var it = makeIterator(); while true { let span =
  it.next(maximumCount: .max); if span.isEmpty { break }; for i in span.indices { body(span[i]) } }`. Because
  `Span`'s subscript is a **borrowing addressor** (`span[i]` borrows, never moves out — `Span.swift:455-461`),
  this carries `(borrowing Element)` for **both** element kinds with **no Copyable gate**. This **subsumes the
  bespoke `Memory.Contiguous` span-lending `forEach` floor** (which already did exactly this loop) — the
  duplication dissolves. Angle C's insight (Void return → no lifetime-dependent return → no move-out wall) is
  preserved and now realized by the span primitive rather than a backing-delegating scalar default.
- **(decided — surface)** The terminal suite (`forEach`, `contains`, `first`, `reduce`, `satisfies`) is a
  plain **`borrowing func`** on `Iterable`, **NOT** a `Property.View` accessor. The Property surface cannot
  hold an iterator across the loop on a production compiler (≤6.3.2): `Property.Borrow`'s base is a `_read`
  coroutine (statement-scoped → the iterator escapes the loop); `Property.Inout` is mutating (wrong for a
  non-destructive scan); `Property` requires an Escapable Base (excludes `~Escapable` cursors). The
  `borrowing func` is the modern `~Escapable` shape that works today and reaches `~Escapable` iterables.
  **Revisit when SE-0507 `BorrowAndMutateAccessors` reaches a production compiler** (validated on 6.4/6.5-dev;
  gated out of ≤6.3.2). This DIVERGES from the ecosystem's Property-tag terminal surface — accepted, because
  no Property flavor can host iteration on a production compiler.
- **(realize)** `func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` —
  same signature as today, new body (the span loop above). The per-variant hand-written `forEach`s inherit it.
  `contains`/`first`/`reduce`/`allSatisfy` continue to compose **from** `forEach` (or directly from the span
  loop). The extraction terminals that *return an element by value* (`first`/`reduce` collecting) keep their
  `Iterator.Element: Copyable & Escapable` gate (`Iterable+First.swift:10-11`) — that gate is intrinsic to
  *extracting past the borrow*, NOT to iteration, and is correct/unchanged.
- **(open)** The one build-verify gate: `Iterator.Chunk(span)` over **inline `@_rawLayout` storage** for
  `~Copyable` (§2.5 / `iterable-se0516-alignment.md` §6) — the span path borrows through the safe `span` view
  (weaker than the old escaping-base path), so it should be at least as sound, but it is a gate, not a settled
  claim.

### 2.2 `Collection` refines `Iterable` — DEFERRED to fan-out

- **(decided)** `Collection.\`Protocol\`` **refines** `Iterable`. Element-iteration is inherited;
  index-based `Collection.ForEach` collapses; `Collection` keeps only index-specific ops
  (`subscript`/`Range`/`Slice`/`firstIndex`). **`forEach` semantically belongs on `Iterable`, not
  `Collection`** (a collection IS-A iterable; the reverse is false).
- **(realize / fan-out only)** Add `: Iterable` to `Collection.\`Protocol\``; delete `Collection.ForEach`;
  re-point its consumers. set-ordered conforms `Iterable` **directly** (not `Collection`), so this is a
  **NO-OP for the reference rework** — it is a fan-out-phase cascade (~14 conformers / 5 packages:
  array/buffer/deque/input/ascii-parser). Enumerate workspace-wide ([HANDOFF-050]) before it lands.
- **(status)** Collection.Protocol is currently **standalone** on disk (does not refine Iterable) — correct
  for this phase.

### 2.3 `makeIterator` — the span-primitive iterator, vended by the bridge (RE-ALIGNED v2.2.0)

- **(decided — RE-ALIGNED)** `Iterable.makeIterator()` returns the **span-primitive** iterator
  `Iterator.Chunk` (`__IteratorChunkProtocol`: `next(maximumCount:) -> Span<Element>`), **not** the scalar
  `Iterator.\`Protocol\``. `Iterable.Iterator` is re-pointed to `__IteratorChunkProtocol` (D2); that protocol's
  element bound relaxes `Escapable → ~Copyable` and **drops its `: Iterator.\`Protocol\`` refinement** (D1 —
  otherwise a `~Copyable` `Iterator.Chunk` would still owe the scalar move-out `next() -> Element?`). **One
  iterator serves both element kinds.**
- **(realize)** For span-projecting backings (the **whole `Memory.Contiguous` family** — buffers, Set.Ordered,
  storage-backed containers) the **memory→Iterable bridge** vends `makeIterator() -> Iterator.Chunk(span)`
  **for free**, relaxed to `Element: ~Copyable` (§6.3). The lifetime composes through the safe view:
  `Memory.Contiguous.span` is `@_lifetime(borrow self)` and `Iterator.Chunk` is `@_lifetime(copy span)`, so the
  iterator is tied to the container borrow — **no escaping base, no `@_lifetime(borrow <local>)`.** Non-span
  backings either project a span directly or use a one-element-span adapter (the SE-0516 `IterableIteratorAdapter`
  analog — optional, D8). **The v2.1.x Angle-B "one requirement, two escapability-gated defaults (copy-self vs
  plain)" is superseded:** there is one span iterator; per-conformer escapability juggling is no longer the
  mechanism.
- **(correctness invariant — retained)** Omit `@_lifetime` on any **Escapable** result/target (the compiler
  *rejects* it); only `~Escapable` yields carry `@_lifetime`.
- **(open)** The `@_implements(Iterable, Iterator)` / `@_implements(Sequenceable, Iterator)` dual-conformer
  split **persists** — `Iterable` now binds `Iterator = Iterator.Chunk` (span) while `Sequenceable` binds the
  scalar consuming iterator, so a type conforming to both still splits the shared `associatedtype Iterator`
  via `@_implements` (already live on the 4 variants).

### 2.4 Flat-pool representation — trees/hashes become span-projecting (Angle A)

- **(decided)** Trees/hashes are represented as **flat pools** (nodes/values in one contiguous array, links
  by index) → span-projecting → they ride the same copy-self `makeIterator` default + the `forEach` floor.
  Angle A1 (flat tree) + A3 (chaining hash flattened to one `[Int]` pool) CONFIRMED.
- **(realize)** Not a set-ordered concern (contiguous via `Buffer.Linear`). This is the **fan-out doctrine**
  for tree/hash/graph packages.
- **(release-only gate, not design)** Pure-pointer **boxed** structures through a generic family default hit
  the **A2 release SIL crash** (`forwardToInit`; §6). Flat-pool **is** the dodge (a real borrowed region =
  A2b happy case). `/issue-investigation` + upstream candidate; not a design gate.

### 2.5 `~Copyable` iteration — the span iterator (RE-ALIGNED v2.2.0; `Iterator.Borrow` PARKED)

> **This section is RE-ALIGNED.** The v2.1.x keystone — `~Copyable` pull-style via `Iterator.Borrow.Scalar`
> composed over the Storage+Buffer cores (Option C) — is **SUPERSEDED** by the span-primitive shape. Full WHY +
> SE-0516 mapping: `iterable-se0516-alignment.md` §5/§6.

- **(decided — RE-ALIGNED)** `~Copyable` iteration is **not** a separate pull-style mechanism — it is the
  **same span iterator** (`Iterator.Chunk` over `span`, §2.3) that serves Copyable elements. `Iterator.Chunk`'s
  primitive is `next(maximumCount:) -> Span<Element>` with `Element: ~Copyable` (D1); the consumer reads
  elements via `span[i]`, which is a **borrowing addressor** (`Span.swift:455-461`) — the element is **borrowed
  in place, never moved out by value**. So the move-out wall that motivated a `~Copyable`-specific iterator
  simply **does not arise** under the span primitive. `Span<Element: ~Copyable>` (`Span.swift:29`) is the
  keep-and-lend mechanism; no `Ownership.Borrow` wrapper, no escaping base, no `Storage` composition.
- **(realize — span-primitive; DECIDED 2026-05-30, user-ratified)** `Set.Ordered` and **every** `Buffer.Linear`
  variant get their `Iterable` (~Copyable) conformance **for free from the memory→Iterable bridge over `span`**
  (§6.3, D4/D5). `Memory.Contiguous.span` is already `~Copyable`-capable (`Memory.ContiguousProtocol.swift:90-101`;
  `Set.Ordered.span` is `where Element: ~Copyable`); once the bridge relaxes `Copyable → ~Copyable`, it vends
  `Iterator.Chunk(span)` for both kinds. So this is **ONE conformance** — the dual-element-kind split
  **dissolves** — with **NO per-variant `makeIterator`, NO `Buffer.Linear: Storage.Protocol`, NO public base,
  NO escaping `pointer(at:)`, NO `Iterator.Borrow.Scalar` vend, NO separate bridge package.** The buffer just
  exposes `span` (which it already does) and the existing bridge does the rest. This is **strictly simpler**
  than v2.1.x Option C.
  - **The Option-C-era rejections are now moot for iteration** (the bridge-over-`span` sidesteps all of them):
    the `Buffer.Linear: Storage.Protocol` **category error**, **Option A** (escaping base on `Memory.Contiguous`),
    and **Option B′** (`_iteratorBase()` → public) were all about routing an *escaping base* to a borrow iterator;
    the span primitive never needs an escaping base. **T1** (`associatedtype Storage` on `Buffer.Protocol`)
    **stays rejected** (§6.5) — independent of this realignment.
- **(`Iterator.Borrow` disposition — PARKED, not reverted)** `Iterator.Borrow.\`Protocol\`` /
  `Iterator.Borrow.Scalar` exist solely to give `~Copyable` **scalar** pull-style via an
  `Element == Ownership.Borrow<Borrowed>` wrapper past the move-out wall. Under the span primitive that wall
  never arises, so the **iteration role is WITHDRAWN.** **SE-0516 explicitly rejected this exact design**
  ("Basing `~Copyable` iteration on `IteratorProtocol`" with a `Borrow<Element>`-returning `next()`) on
  call-site-ergonomics grounds — predicates would be written over `(borrowing Borrow<T>)` instead of the
  element type. Per [ARCH-LAYER-009] (no pre-1.0 deletion): **PARK `f31ce11`/`dd60699` on disk, do NOT revert
  or delete.** The package may retain a *non-iteration* scalar keep-and-lend cursor role (cheap `peek`/`zip`/
  early-exit — affordances a span `forEach` lacks); re-evaluate at 1.0 against whether a consumer needs it.
  `Ownership.Borrow<Value>` itself (a general borrow handle) is **untouched**.
- **(build-verify gate — the one open item)** `Iterator.Chunk(span)` over **inline `@_rawLayout` storage**
  (the `.Inline`/`.Small`/`.Static` variants) for `~Copyable` elements must compile + iterate correctly in
  **debug AND release**. The span path borrows through the **safe `span` view** (`@_lifetime(borrow self)`) —
  strictly *weaker* than the old escaping-base path the v2.1.x soundness gate already passed — so it should be
  **at least as sound**; but it is a gate, not a settled claim ([RES-021]/[RES-027]). This gate replaces the
  v2.1.x "literal `Buffer.Linear.Inline: Storage.Protocol`" gate (which no longer exists — no Storage conformance).
- **(no cave — retained discipline)** No Copyable-gated fallback for `~Copyable` iteration; no degrade to
  `[Swift.String]`. If the build-verify gate walls → escalate (architecture-shape call), do not retreat.

### 2.6 The consuming-iterator choice (`Sequenceable.makeIterator`, consuming)

- **(decided)** The consuming `makeIterator` shape folds into this design (NOT adopted standalone). Three
  shapes (from `memory-cursor-generic-witness-demangle-reshape.md` v1.0.0 — KEPT):

  | Shape | Witness mangling | Cost | `~Copyable` | Verdict for set-ordered |
  |---|---|---|---|---|
  | lazy `Memory.Cursor<Base>` | deep → **corrupt for the `@_rawLayout` inline family** (demangle SIGABRT) | per-`next()`, no alloc | yes | **REJECT** for Static/Small (back onto `@_rawLayout` Inline/Small) |
  | `Memory.Snapshot.Cursor<Element>` | shallow → safe | one `[Element]` alloc + bulk copy | no | the demangle-safe **generic** option (dormant; name pending) |
  | **hand-written scalar** (`Buffer.Linear.{variant}.Scalar`) | concrete → safe | no alloc, per-variant | per backing | **current production; green; keep for set-ordered** |

- **(recommendation, confirmed)** set-ordered **stays hand-written-scalar**; do NOT adopt the lazy
  `Memory.Cursor<Self>` bridge (crashes on the inline family); keep `Memory.Snapshot.Cursor` reserved as the
  generic fan-out option (the `swift-memory-sequence-primitives` bridge is **dormant** — the generic
  conformer demangle crash; no live consumer). Per-backing choice, made where the backing lives.

### 2.7 Consuming drain = `Sequenceable.consume(_:)` (closure terminal) — DONE

- **(decided + DONE)** The consuming drain is a **closure terminal** on `Sequenceable`:
  `consuming func consume<E: Swift.Error>(_ body: (consuming Element) throws(E) -> Void) throws(E)` (+ an
  `Either<E, Iterator.Failure>` overload) — `Sequenceable+Consume.swift:35/:59`. It is symmetric to
  `Iterable.forEach` (borrow terminal) but consuming. `forEach` stays purely the borrow terminal (no
  consuming overload → no ambiguity, no `@_disfavoredOverload`).
- **(history — reconciliation)** The earlier design kept a `Sequence.Consume.\`Protocol\`` witness
  (`consume() -> View<Element, ConsumeState>`) reached via an interim `package consuming func takeBuffer()`,
  and escalated a `ConsumeState` `~Copyable` widening. **Reality overtook it:** the entire `Sequence.Consume`
  module (`Protocol`/`View`/`ConsumeState`) was **DELETED** (sequence-primitives `309c1b9`) and folded into
  the closure terminal; `takeBuffer` deleted (set-ordered `13ab89f`). So there is **no witness protocol, no
  ConsumeState, no widening to escalate** — that escalation is dead. The closure terminal carries `~Copyable`
  elements natively (the closure receives `(consuming Element)`); no Copyable gate.
- **(open)** None for set-ordered — `consume(_:)` is the shape and is landed.

### 2.8 `Swift.Sequence`-where-Copyable bridge (re-add)

- **(decided)** Keep `Swift.Sequence` as the **stdlib bridge** (`where Element: Copyable`); institute
  iteration primary. **Load-bearing:** the `@inline(always)` `Swift.Sequence` dual-conformer `forEach`
  bridge (`Sequenceable+ForEach.swift:40`) dodges a CopyPropagation SIL crash on `~Copyable` deinits and
  serves Copyable `Swift.Sequence` dual-conformers — keep it.
- **(realize)** Re-add `extension X: Swift.Sequence where Element: Copyable` bridging the institute iterator
  to stdlib for-in + algorithms; `@_implements` disambiguates. Re-adds after §2.3/§2.6 settle.
- **(open)** Sequencing only — in the reference rework after §2.3/§2.6.

### 2.9 Small's optional-`~Copyable`-hashTable redesign — commit the evergreen

- **(decided)** Non-optional + sentinel-empty redesign is the **sole correct structural shape** — it **MUST
  land** in the rework and **delete** the take-and-put-back workaround.
- **(realize)** Make the hash table non-optional with a sentinel-empty state (always-present `Hash.Table`,
  empty while unspilled), so `drain()` mutates a definitely-present `~Copyable` value with no optional
  in-place mutate — the `if var ht = hashTable { … }` workaround (~ll.139–141) is **deleted**; direct
  `hashTable.remove.all(...)` stands. `isSpilled` becomes a capacity predicate (no longer an `Optional` test).
- **(no cave)** Committed evergreen. If sentinel-empty walls → escalate, do not retreat. The
  `DiagnoseStaticExclusivity` crash (A11) is a `/issue-investigation` candidate, tracked separately.

---

## 3. The unified protocol-layering picture (target)

```
Iterable  (iterator-primitives)        ── element-iteration floor, GROUND HOME for the terminal suite
  ├─ forEach (plain borrowing func, UNIVERSAL incl. ~Copyable)  ◄ §2.1  span-loop body; (borrowing Element)
  ├─ contains / first / reduce / satisfies                      ◄ compose from forEach (span loop)
  └─ makeIterator (borrowing) -> Iterator.Chunk  [SPAN-PRIMITIVE] ◄ §2.3  ONE span iterator, BOTH element kinds
        next(maximumCount:) -> Span<Element>                          (the SE-0516 nextSpan); span[i] borrows.
        Element bound ~Copyable; NOT : Iterator.`Protocol`.           Memory.Contiguous family: vended FREE
                                                                      by the memory→Iterable bridge over span.

Iterator.`Protocol` (iterator-primitives)  next() -> Element?   ── scalar/move-out FOUNDATION
  └─ the consuming/give-away iterator for Sequenceable (World A) + the ~Escapable-element ceiling.
     NO LONGER Iterable's iterator (the move-out wall lived here).

Collection.`Protocol` (collection-primitives)   [standalone now; : Iterable at FAN-OUT]   ◄ §2.2
  └─ subscript / Range / Slice / firstIndex (index-specific only)

Sequenceable (sequence-primitives)  : ~Copyable, ~Escapable   [orthogonal sibling — does NOT refine Iterable]
  ├─ forEach borrow-terminals → admit ~Escapable; + the @inline(always) Swift.Sequence dual-conformer bridge
  ├─ collect / first extraction-terminals → Element: Escapable
  ├─ makeIterator (CONSUMING, owning drain) -> scalar Iterator.`Protocol`  ◄ §2.6  hand-written scalar
  └─ consume(_: (consuming Element) throws(E)->Void)   ◄ §2.7  CLOSURE terminal (Sequence.Consume DELETED;
                                                               symmetric to forEach; no View/ConsumeState/takeBuffer)

Iterator.Borrow.`Protocol` + Iterator.Borrow.Scalar (iterator-borrow-primitives)   ◄ §2.5  PARKED
  Element == Ownership.Borrow<T> scalar pull-style. ITERATION ROLE WITHDRAWN under the span realignment
  (SE-0516 rejected this element-wrapping). f31ce11/dd60699 stay on disk ([ARCH-LAYER-009]); possible
  future non-iteration scalar keep-and-lend cursor. NOT vended by any container.

Swift.Sequence  (stdlib)  where Element: Copyable     ◄ §2.8  re-add; stdlib bridge, institute primary
```

**Element-kind coverage (target):**

| Element kind | Push-style (internal) | Pull-style (external) |
|---|---|---|
| `Copyable` | `Iterable.forEach` (floor, span loop) | `Iterable.makeIterator` → `Iterator.Chunk` (span) + `Sequenceable.makeIterator` (consuming) + `Swift.Sequence` bridge |
| **`~Copyable`** | `Iterable.forEach` (floor — `(borrowing Element)`, span loop) | **`Iterable.makeIterator` → `Iterator.Chunk` (span)** — the **same** span iterator; `span[i]` borrows, never moves out (§2.5). Vended by the bridge over `span`; **no `Iterator.Borrow`** |
| `~Escapable` **element** | scalar `Iterator.\`Protocol\`` / `Sequenceable` borrow-terminals (language-blocked at the `Span` ceiling — span cannot carry `~Escapable`) | scalar `Iterator.\`Protocol\`` (the `~Escapable`-element foundation) |

`forEach` is the **floor covering every cell**; the pull-style is now the **same span iterator** for both
Copyable and `~Copyable` (not a separate borrow mechanism). The consuming drain `consume(_:)` (§2.7) is the
consuming sibling of `forEach`. **`~Escapable`-*element* iteration** (lending a view of a genuinely
non-escaping element) stays on the scalar `Iterator.\`Protocol\`` — `Span` excludes `~Escapable` (`Span.swift:29`),
so the span primitive cannot carry it; this is the same language-blocked ceiling SE-0516 hits (§6.1).

---

## 4. The ×16 fan-out recipe (the template — GATED, not authorized)

For each data-structure variant, **after** the set-ordered reference validates the shape AND the supervisor
re-verifies it (the fan-out is NOT pre-authorized; the per-action YES gate stands):

1. **Inherit `forEach` from the `Iterable` floor** (§2.1) — delete the per-variant body; declare `: Iterable`
   per-variant (the lift via protocol extension is refuted per Angle "shape A" — bodies inherit, conformance
   is per-variant).
2. **Choose the representation** (§2.4): contiguous/piecewise → span-projecting directly; tree/hash/graph →
   **flat-pool**. Avoid pure-pointer boxed nodes through generic defaults (A2 release bug); flat-pool is the dodge.
3. **Expose `span` (`Memory.Contiguous.\`Protocol\``)** so the memory→Iterable bridge vends the span-primitive
   `Iterable.makeIterator() -> Iterator.Chunk(span)` for free (§2.3/§6.3) — for **both** element kinds. Piecewise
   backings (ring/deque) that project more than one span need a multi-span iterator or per-segment handling
   (**open** at fan-out — surface it, do not assume one span).
4. **Consuming route** (§2.6/§2.7): delegate `Sequenceable.makeIterator` (consuming) to the backing's
   hand-written `.Scalar`; the consuming drain is the inherited `Sequenceable.consume(_:)` closure terminal —
   **no `takeBuffer`, no `Sequence.Consume.Protocol`**. Use `Memory.Snapshot.Cursor` only if a package needs
   a generic contiguous bridge, its backing trips the demangle, and it has no hand-written scalar.
5. **`~Copyable` iteration** (§2.5, span-primitive): there is **no separate pull-style mechanism** — the same
   span iterator (`Iterator.Chunk` over `span`, vended by the bridge relaxed to `~Copyable`) serves `~Copyable`
   elements via `span[i]` borrowing access. `~Copyable` variants get **both** `forEach` (push) and
   `makeIterator → Iterator.Chunk` (pull) from the one bridge conformance — **no `Iterator.Borrow.Scalar`, no
   per-variant `makeIterator`, no `Storage` conformance, no public base, no fallback.**
6. **`Swift.Sequence` bridge** (§2.8): re-add `where Element: Copyable` once the iterator shape is settled.
7. **`Collection` refinement cascade** (§2.2): for `Collection.\`Protocol\`` conformers, drop
   `Collection.ForEach` for the inherited floor — workspace-enumerate first ([HANDOFF-050]).
8. **MOD-036 type/ops boundary**: apply the windowless-interim recipe. **Do NOT replicate `takeBuffer`** (gone).

**The recipe is data-shaped-vs-resource-shaped aware** ([DS-021]): `Copyable` (data-shaped) variants
additionally get the consuming `Sequenceable` route + the `Swift.Sequence` bridge; `~Copyable`
(resource-shaped) variants get `forEach` (push) + the span iterator (pull) from the one bridge conformance.
Institute containers pass `~Copyable` through — no `[Swift.String]` fallbacks.

**Per-container iteration-order gate:** for ordered-set / ordered-dict, **halt-and-surface if iteration
order is index-maintained rather than in-storage** (the span-direct floor walks storage order). **Cascade
enumeration:** the 8 buffer-backed containers (array, stack, queue, heap, dictionary, ordered-set, deque,
ordered-dict, queue-linked) + graph / tree-keyed / tree-n (level-4, last). **Fan-out debt:** deque / queue /
queue-linked carry stale `Sequence.Protocol` refs (→ `Sequenceable`, renamed at sequence-primitives
`26c8cf3`) the fan-out MUST migrate.

---

## 5. set-ordered reference-rework delta (current → target)

Set-ordered reference rework **AUTHORIZED**. **Fan-out (§4) NOT authorized** until the validated reference is
re-verified.

| # | Change | Current | Target | Element |
|---|---|---|---|---|
| 1 | `forEach` → inherited floor | per-variant method (Copyable; ~Copyable hand-written) | inherited from the `Iterable` **span-loop** default; works for both element kinds, no Copyable gate; subsumes the bespoke `Memory.Contiguous` floor | §2.1 |
| 2 | borrowing `makeIterator` | only consuming exists | `Iterable.makeIterator() -> Iterator.Chunk(span)` (span-primitive) **vended by the bridge** (relaxed `~Copyable`); `@_implements` split vs `Sequenceable`'s consuming scalar iterator | §2.3 |
| 3 | consuming drain | `Sequenceable.consume(_:)` closure terminal — **DONE** (`13ab89f`; Sequence.Consume + takeBuffer deleted) | no change needed | §2.7 |
| 4 | consuming iterator | backing `.Scalar` (hand-written) | **keep** | §2.6 |
| 5 | `~Copyable` `Iterable` | not vended; `Iterable` is `where Element: Copyable` | **span-primitive (D4/D5)**: relax the memory→Iterable bridge `Copyable → ~Copyable`; `Set.Ordered` + buffers get **ONE** `Iterable` conformance via the bridge over `span` — the dual-element-kind split **dissolves**. **NO `Iterator.Borrow.Scalar`, NO per-variant `makeIterator`, NO `Buffer.Linear:Storage.Protocol`, NO public base.** Open: the `Iterator.Chunk(span)`-over-inline-`@_rawLayout` build-verify gate | §2.5 |
| 6 | `Swift.Sequence` | not conformed (input-only) | **re-add** `where Element: Copyable` | §2.8 |
| 7 | Small `drain()` evergreen | take-and-put-back workaround (~ll.139–141) | non-optional + sentinel-empty; **delete the workaround**; escalate-don't-retreat if walled | §2.9 |
| 8 | promote recipe note | gitignored at `swift-set-ordered-primitives/Audits/mod-036-type-ops-boundary.md` | promote to tracked `swift-institute/Research/` | recipe note |
| + | stale `Set.Protocol` comment | `swift-set-primitives/.../Set.Protocol.swift:22-39` — "family-protocol `Backing` lift NOT expressible" + dead cite to a nonexistent doc | reconcile/remove — pre-victory pessimism (pull-style lives on `Iterable`) | §2.2 |

Build/test green on **debug AND release** (set-ordered is release-clean via field-reorder); the test floor
must not regress.

---

## 6. Folded rationale (the empirical envelope + the two-world model + the bridge)

The decisions above rest on these results, proven in `Experiments/iteration-architecture-toy` (`8ae35fb`,
Phases 8–11; debug+release, full ecosystem flags) and the consuming-iterator reshape doc (KEPT).

> **Note (v2.2.0):** §6.2's Angle-A/B framing (the `~Escapable` copy-self walker + the "two escapability-gated
> `makeIterator` defaults") predates the span-primitive realignment and is **retained as empirical evidence**
> of what the toy proved. Where it differs from §2.3/§2.5 (RE-ALIGNED), those sections govern: `Iterable`'s
> iterator is the span `Iterator.Chunk` (one iterator, both kinds, vended by the bridge), not a per-conformer
> copy-self/plain default. Angle C (the `forEach` floor) carries through unchanged — now realized by the span
> loop. §6.1 (two-world) and §6.3 (bridge) are RE-ALIGNED in place.

### 6.1 The two-world duality (load-bearing claim)
**give-away vs keep-and-lend.** For move-only elements, `owned ⇒ single-pass` and `borrowed ⇒ multipass`.
- **World A — owned iteration (give-away, single-pass):** the iterator world. `Iterator.\`Protocol\`` +
  `Sequenceable` (consuming `makeIterator`). A World-A step gives an element away.
- **World B — borrowing traversal (keep-and-lend, multipass):** `Iterable` (borrowing `makeIterator`, already
  `@_lifetime(borrow self)`). The container survives and re-vends. **Multipass comes from the EXISTING
  `Iterable` — no new attachable.** **(RE-ALIGNED v2.2.0)** `~Copyable` multipass is the **span iterator**
  (`Iterator.Chunk` over `span`): `next(maximumCount:) -> Span<Element>` lends a borrowed span and `span[i]`
  borrows each element in place — keep-and-lend **without** moving the element out and **without** an
  `Ownership.Borrow<T>` wrapper. (The earlier framing — `Iterator.\`Protocol\`` with
  `Element == Ownership.Borrow<T>` = `Iterator.Borrow` — is superseded; SE-0516 rejected element-wrapping, §2.5.)
  The `~Escapable`-*element* axis — lending a view of a genuinely non-escaping element — stays language-blocked
  at the `Swift.Span` ceiling (`Span` excludes `~Escapable`) and lives on the scalar `Iterator.\`Protocol\``;
  revisit when the language matures.

### 6.2 The expressibility angles (the decided shape)
- **Angle A — `~Escapable` self-tied walker via a copy-self family default.** Flat trees, hashes, and boxed
  trees *with a real borrowed region* ride one `@_lifetime(copy self)` default (debug+release). The
  external-iterator route is **inherently Copyable-only** — A4: `next() -> Element?` moving a `~Copyable` out
  of a borrowed span CRASHES SILGen; `~Copyable` iterates via the `forEach` floor (Angle C), not the external
  iterator. **A2 (release-only):** a genuinely-boxed pure-pointer walker through the generic default hits a
  release SIL inliner crash (`forwardToInit … Cannot initialize a nonCopyable type with a guaranteed value`)
  — a SIL-optimizer bug, **not** a language wall, dodged by a real borrowed region (A2b) or the direct path.
  **This A2 release crash is SEPARATE from `#86652` and still stands** (`/issue-investigation` candidate).
- **Angle B — one protocol, two conditional same-named `makeIterator` defaults** gated by `Backing.Iterator`
  escapability (copy-self vs plain). The compiler accepts both and dispatches per-conformer. §2.3.
- **Angle C — one `forEach` family default unifies everything (the most complete).** One backing-delegating
  `forEach` default serves a span array, a boxed tree, and `~Copyable` elements via one body; closure
  `(borrowing Element) -> Void`, `Void` return → no lifetime-dependent return, no A4 move-out wall,
  `~Copyable` carried natively. **Cost:** internal iteration only — no pull-style `next()`, lazy, `zip`,
  `peek`, cheap early-exit (those are the pull-style affordances, §2.3/§2.5). §2.1.

### 6.3 The memory→Iterable bridge — the load-bearing vehicle (RE-ALIGNED v2.2.0)
`Memory.Contiguous.\`Protocol\`` (`var span: Span<Element>`, `Element: ~Copyable`) is the span-projecting
substrate. The memory→Iterable bridge is **witness-only**: a constrained extension supplying
`borrowing func makeIterator() -> Iterator.Chunk(span)` (reusing the canonical span iterator; no iterator of
its own) + the span-lending `forEach` floor. **The realignment turns on this bridge:**
- **(D4) Relax the bridge `Element: Copyable → ~Copyable`.** Today it is `Copyable`-gated only because
  `Iterator.Chunk`'s *conformance* was `Escapable`-narrowed (`__IteratorChunkProtocol.swift:35`) and `Iterable`
  consumed the scalar move-out. Once `Iterator.Chunk`'s bound relaxes to `~Copyable` (D1) and `Iterable`'s
  primitive is the span (D2), the bridge vends `Iterator.Chunk(span)` for **both** element kinds —
  `Memory.Contiguous.span` is already `~Copyable`-capable (`Memory.ContiguousProtocol.swift:90-101`).
- **(D3) The bridge's span-lending `forEach` floor becomes the GENERAL `Iterable.forEach`** (§2.1) — the
  bespoke `Memory.Contiguous+Iterable.swift:55-67` floor and the general floor converge on the same span loop;
  the duplication dissolves.
- **No escaping base anywhere.** The bridge borrows through the **safe `span` view** (`@_lifetime(borrow self)`),
  not an escaping `pointer(at:)`. So the entire v2.1.x escaping-base decomposition — the `Buffer.Linear:
  Storage.Protocol` **category error**, **Option A** (escaping base on `Memory.Contiguous`), **Option B′**
  (`_iteratorBase()` → public) — is **moot for iteration** (it was solving where the escaping base lives; the
  span primitive needs none). `Buffer.Protocol` (logical `count`) **has-a** `Storage.Protocol` (physical
  `pointer(at:)`) as before — the chain is storage→buffer — but storage is **not** the iteration vehicle now.

A v1.0.0 `Iterator.Walk` (a new owning iterator type) was **withdrawn**: the owning iterator is the deferred
owned-`Cursor` sibling (`Memory.Cursor`, homed in the existing `swift-memory-cursor-primitives`), not a new
type — and a borrowed-view cursor + an owned cursor are two types because escapability is fixed at declaration.
`Ownership.Borrow`'s typed-pointer init refused `@_lifetime` on an Escapable result (OQ-2 V1 refuted: "invalid
lifetime dependence on an Escapable result").

### 6.4 Terminal relocation + the `Sequencer` rename (folded from the sequencer-reconciliation DRAFT)
The non-destructive terminal suite (`forEach`, `contains`, `first`, `satisfies`, observing `reduce`) is
**multipass/borrowing → relocated DOWN onto `Iterable`** in swift-iterator-primitives so *every* iterable
(buffers, storage, cursors, Single/Empty, later collections) gets them; the consuming terminals stay on
`Sequenceable`. `Sequenceable` stays consuming/single-pass and **does NOT refine `Iterable`** (a `consuming`
requirement cannot satisfy a `borrowing` one) — they are orthogonal siblings reusing the one
`Iterator.\`Protocol\`` at the iterator level; a dual-conformer splits the two `Iterator` bindings with
`@_implements`. The bulk-span borrowing protocol (`Sequence.Borrowing.Protocol`) is to RETIRE (not relocate
as `Sequencer.Span.Protocol`) — open (D-2). **Pending rename (A7, unexecuted):** `swift-sequence-primitives`
→ `swift-sequencer-primitives`; namespace `Sequence` → `Sequencer`; borrow pkg →
`swift-sequencer-borrow-primitives` — a breaking rename gated on the principal's execute-vs-defer call.

### 6.5 Dead ends — refuted, do NOT re-derive
- `forEach.consuming` as a `Sequenceable` `Property.Inout` accessor: NOT expressible ≤6.3.2 (`_read`
  statement-scoped wall; SE-0507 gated out).
- `@_disfavoredOverload` on a `consuming func forEach`: rejected (Copyability-dependent asymmetry).
- `forEach`-as-the-consuming-terminal (one name, no `consume`): blocked — `Sequenceable`'s non-consuming
  `forEach` (incl. the `@inline(always)` `Swift.Sequence` bridge) is load-bearing → the consuming terminal
  must have a distinct name → `consume(_:)`.
- Family-protocol `Backing`-lift via a generic `var backing` accessor / `extension Family.Protocol: Iterable
  where Backing: Iterable`: lifetime-escape / "extension of protocol cannot have an inheritance clause" → the
  floor lives on `Iterable`; conformance is **per-variant** (bodies inherit).
- A by-value `next() -> Element?` for raw `~Copyable` multipass (A4): SILGen crash (move-out) → the
  span-primitive `Iterable` (RE-ALIGNED v2.2.0) **never does this** — its iterator yields `Span<Element>`
  and `span[i]` borrows in place. So `~Copyable` uses the span iterator (`Iterator.Chunk` over `span`) for
  **both** push (`forEach`) and pull (`makeIterator`); no by-value scalar `next()` on `Iterable`.
- **Scalar-primitive `Iterable`** (`Iterable.Iterator = scalar Iterator.\`Protocol\``, `next() -> Element?`):
  this **was** the institute's shape (`Iterable.swift:45` pre-realignment) and is the **root** of the
  week-long `~Copyable` move-out wall. **Superseded v2.2.0** by the span-primitive `Iterable` (D2) per SE-0516.
  The scalar `Iterator.\`Protocol\`` stays — but as `Sequenceable`'s consuming foundation, not `Iterable`'s iterator.
- **`Iterator.Borrow.Scalar` as `Iterable`'s `~Copyable` iterator** (the v2.1.x Option C: `Element ==
  Ownership.Borrow<Borrowed>` scalar pull-style over the Storage+Buffer cores): **superseded v2.2.0.** The span
  iterator covers `~Copyable` without the wrapper, and **SE-0516 explicitly rejected this element-wrapping
  design** on call-site ergonomics (`iterable-se0516-alignment.md` §5). `Iterator.Borrow` is parked, not
  reverted ([ARCH-LAYER-009]). Do NOT re-derive an `Ownership.Borrow`-yielding iterator as the `~Copyable`
  iteration path.
- **`associatedtype Storage: Storage.Protocol` on `Buffer.Protocol`** (the "maximum-for-free via one generic
  extension" instinct): **rejected** — it is **anti-precedented** (cross-language survey
  `buffer-storage-associatedtype-prior-art.md`: Swift SE-0256 *ContiguousCollection* rejected + SE-0447 *deferred*
  `ContiguousStorage` → shipped `Span`; Rust T2 allocator + T4 deref-to-slice, its lone storage-as-type attempt
  unstable 2+ yrs; C++ `contiguous_range` is a *concept* not a type; Python `Py_buffer` is a scoped accessor —
  **nobody exposes storage as a member type**) AND it contradicts the APPROVED
  `cross-layer-capability-protocol-model.md` ("Buffer.Protocol … no `Storage` refinement … has-a"). The universal
  shape is contiguity-as-a-**capability** + per-conformer provision. **(RE-ALIGNED v2.2.0)** Under the
  span-primitive shape, "for free" lands even more cleanly: the iterator is `Iterator.Chunk` over `span`, vended
  by the **memory→Iterable bridge** (relaxed to `~Copyable`) — buffers expose only `span` (the safe-view
  capability they already provide), not storage, not an escaping base, not a per-variant `makeIterator`. T1's
  rejection stands independently of the realignment.

### 6.6 D1–D5 design-acceptance rubric (for fan-out re-review against any future model)
- **D1** — the shape is proven on the real ecosystem flags (debug+release), not just the toy.
- **D2** — `~Copyable` is carried, never degraded to Copyable / `[Swift.String]` fallbacks.
- **D3** — the specialization invariant holds (0-`witness_method` on hot ops; SIL re-prove); the
  protocol-topology boundary is respected (the iteration vehicle is `Memory.Contiguous`/`Iterable`, not
  `Set.Protocol`; `Set.Protocol` carries algebra + the `forEach` floor only, NOT pull-style `makeIterator`).
- **D4** — traceability: stale comments/dead cites reconciled (e.g. `Set.Protocol.swift:22-39`).
- **D5** — no cave: every "fall back to X" / "stays gated until proven" / "take-and-put-back" framing is
  rejected for the evergreen; walls escalate, not retreat.

---

## 7. Outcome

**Status: APPROVED** (re-aligned to disk + SE-0516, v2.2.0; span-primitive). The institute `Iterable` is
realigned to SE-0516's span-primitive shape: re-point `Iterable.Iterator` to the span `__IteratorChunkProtocol`
(D2) + relax its element bound `Escapable → ~Copyable` and drop the scalar-protocol refinement (D1). ONE span
iterator (`Iterator.Chunk` over `span`) serves both element kinds; the memory→Iterable bridge relaxed to
`~Copyable` (D4) gives Set.Ordered + buffers their `Iterable` (~Copyable) conformance **for free**, dissolving
the dual-element-kind split (D5) and retiring the `Iterator.Borrow` detour (D6 — **PARKED, not reverted**;
`f31ce11`/`dd60699` stay on disk). The one open build item is the **build-verify gate: `Iterator.Chunk(span)`
over inline `@_rawLayout` storage for `~Copyable`** (debug+release). The consuming drain
(`Sequenceable.consume(_:)`) and release-cleanliness are **done**. T1 (`associatedtype Storage` on
`Buffer.Protocol`) stays rejected. **Next: a verify-plan agent (1) re-verifies this realignment, (2) assesses
ground-state vs the plan, (3) produces the implementation plan** (delta D1–D8 + the `: Iterable` blast-radius
enumeration); then implement → re-verify → promote the recipe → ×16 fan-out (§4) — each gate per-action. Full
WHY + SE-0516 mapping + delta: **`iterable-se0516-alignment.md`**.

---

## 8. References

- **Execution / coordination:** `HANDOFF-data-structure-iteration-arc.md` (the single working doc — current
  state, gates, queue, loose ends).
- **Span-primitive realignment (the superseding WHY for §2.1/§2.3/§2.5/§3/§6, v2.2.0):**
  `iterable-se0516-alignment.md` (Tier 2, RECOMMENDATION, principal-ratified 2026-05-30) — the SE-0516 ↔
  institute mapping, the delta D1–D8, the `Iterator.Borrow` disposition; `bulk-span-iteration-fold-vs-separate.md`
  (Tier 3) — the `Span<~Copyable>` crux verified against the stdlib clone + SE-0516's rejection of element-wrapping.
- **Empirical evidence (KEPT):** `Experiments/iteration-architecture-toy` `8ae35fb` (Angle A/B/C, Phases
  8–11); `Experiments/memory-cursor-generic-witness-demangle` (the demangle repro);
  `memory-cursor-generic-witness-demangle-reshape.md` v1.0.0 (the consuming-iterator reshape).
- **Live protocol sources:** `swift-iterator-primitives` (`Iterable`, `Iterator.\`Protocol\``,
  `Iterator.Chunk`, the borrowing-func `forEach` floor); `swift-iterator-borrow-primitives`
  (`Iterator.Borrow.\`Protocol\``); `swift-ownership-primitives` (`Ownership.Borrow`); `swift-sequence-primitives`
  (`Sequenceable`, `Sequenceable.consume(_:)`, `Sequence.Clearable`); `swift-memory-iterator-primitives`
  (the bridge); `swift-memory-cursor-primitives` (`Memory.Cursor`, dormant).
- **Compiler bugs:** `swift-compiler-bug-catalog.md` (A2 boxed-tree release crash; A11
  `DiagnoseStaticExclusivity`; + the queue Signal-6 reduction to file).
- Skills: [RES-002/003/019/020/023]; [DS-021/022]; [MOD-015a/036/037]; [HANDOFF-050]; [API-NAME-001/001b];
  [API-ERR-001]; [IMPL-078]; `feedback_extension_implies_copyable`.

> **Consolidation note (2026-05-30):** this doc folds in and replaces the removed
> `iteration-architecture-expressibility-envelope.md`, `two-world-traversal-decomposition.md`,
> `world-b-span-decomposition.md`, `memory-contiguous-iteration-bridge.md`,
> `sequencer-primitives-reconciliation-refactor.md`, and `swift-iterator-primitives/Research/
> iterable-iteration-terminal-surface.md`. Their decisions live in §2/§6 here; their detailed prose is
> recoverable from git history; their empirical evidence is in the Experiments above.
