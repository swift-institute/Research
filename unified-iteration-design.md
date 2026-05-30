# Unified Iteration Design — the Single Design Authority + ×16 Fan-Out Template

<!--
---
version: 2.1.0
last_updated: 2026-05-30
status: APPROVED
tier: 2
scope: cross-package
supervises_gate: "Re-scoped 2026-05-30 (user-authorized) to OPTION C — land ~Copyable borrow-iteration at the Storage/Buffer cores (Buffer.Linear: Storage.Protocol public + a Storage&Buffer→Iterable-borrow bridge; Set.Ordered the validating consumer). Other buffer-backed containers INHERIT the capability; their active migration is the gated ×16 fan-out (§4), NOT authorized. Per-action YES still required for: publish · visibility flip · tag · starting the fan-out. Execution coordination: HANDOFF-data-structure-iteration-arc.md."
consolidates: "This doc is the SINGLE design authority for the iteration arc (2026-05-30). It folds in and REPLACES (the originals removed to stop drift): iteration-architecture-expressibility-envelope.md (Angles A/B/C), two-world-traversal-decomposition.md (World A/B), world-b-span-decomposition.md (World-B decomposition), memory-contiguous-iteration-bridge.md (the bridge + Memory.Cursor + withdrawn Iterator.Walk), sequencer-primitives-reconciliation-refactor.md (terminal relocation + Sequencer naming), swift-iterator-primitives/Research/iterable-iteration-terminal-surface.md (the borrowing-func surface decision). Empirical evidence is retained in Experiments/iteration-architecture-toy + Experiments/memory-cursor-generic-witness-demangle (NOT removed)."
builds_on:
  - "Experiments/iteration-architecture-toy 8ae35fb (the Angle A/B/C empirical proof, debug+release, full ecosystem flags)"
  - "memory-cursor-generic-witness-demangle-reshape.md v1.0.0 (the consuming-iterator reshape — KEPT)"
  - "swift-iterator-borrow-primitives (the ~Copyable pull-style; concrete Iterator.Borrow.Scalar shipped f31ce11; composes over Storage+Buffer cores per §2.5)"
changelog:
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
| Element-iteration floor (borrow-style) — **ground home for the terminal suite** | `Iterable` | swift-iterator-primitives |
| Scalar foundation iterator (`next()` `@_lifetime(&self)`, extraction → `Escapable`) | `Iterator.\`Protocol\`` | swift-iterator-primitives |
| Bulk span iterator (`Span` ceiling, `Escapable`-narrowed; scalar `next()` Copyable-gated) | `Iterator.Chunk.\`Protocol\`` | swift-iterator-primitives |
| `~Copyable` **borrow-yielding pull-style** — `Element == Ownership.Borrow<Borrowed>`; concrete `Iterator.Borrow.Scalar` **shipped** (`f31ce11`); base+count compose over the **Storage + Buffer cores** (§2.5) | `Iterator.Borrow.\`Protocol\`` + `Iterator.Borrow.Scalar` | swift-iterator-borrow-primitives |
| Addressable storage core (`pointer(at:)` → escaping base, `capacity`) — the home of the escaping base, NOT `Memory.Contiguous` | `Storage.\`Protocol\`` | swift-storage-primitives |
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
  `~Copyable` (borrowing closure). Angle C (§6) is the most complete unification — one `forEach` default for
  span-projecting + traversal-only + `~Copyable`, debug+release. `forEach` returns `Void`, so there is no
  lifetime-dependent return and the closure receives `(borrowing Element)` **directly** (NOT an
  `Ownership.Borrow` handle — that handle is the *pull-style* element, §2.5).
- **(decided — surface)** The terminal suite (`forEach`, `contains`, `first`, `reduce`, `satisfies`) is a
  plain **`borrowing func`** on `Iterable`, **NOT** a `Property.View` accessor. The Property surface cannot
  hold an iterator across the loop on a production compiler (≤6.3.2): `Property.Borrow`'s base is a `_read`
  coroutine (statement-scoped → the iterator escapes the loop); `Property.Inout` is mutating (wrong for a
  non-destructive scan); `Property` requires an Escapable Base (excludes `~Escapable` cursors). The
  `borrowing func` is the modern `~Escapable` shape that works today and reaches `~Escapable` iterables.
  **Revisit when SE-0507 `BorrowAndMutateAccessors` reaches a production compiler** (validated on 6.4/6.5-dev;
  gated out of ≤6.3.2). This DIVERGES from the ecosystem's Property-tag terminal surface — accepted, because
  no Property flavor can host iteration on a production compiler.
- **(realize)** `func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)`.
  set-ordered already has exactly this signature per-variant → hoist the body to the `Iterable` default; the
  per-variant methods inherit it. `contains`/`first`/`reduce`/`allSatisfy` compose **from** `forEach`.
- **(open)** None on the floor itself — the realization is the hoist + the ~Copyable extension (§2.5).

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

### 2.3 Gated `makeIterator` — one protocol, two escapability-gated defaults (Angle B)

- **(decided)** Copyable **pull-style** `makeIterator` is **one** requirement with **two** same-named
  conditional defaults dispatched by the backing iterator's escapability: **copy-self**
  (`@_lifetime(copy …)` through a `~Escapable` view) for span-projecting backings, **plain** (no
  `@_lifetime`) for non-span. Angle B (§6) CONFIRMED per-conformer dispatch, debug+release.
- **(realize)** Governing principle: a lifetime-dependent iterator composes through `@_lifetime(copy …)`,
  **never** `@_lifetime(borrow <local>)` — the default delegates through a copy-self `~Escapable` view; the
  variant exposes that view. **Correctness invariant:** omit `@_lifetime` on any **Escapable** result/target
  (the compiler *rejects* it); only `~Escapable` yields carry `@_lifetime`.
- **(open)** set-ordered's current `makeIterator()` is consuming (the `Sequenceable` route); the borrowing
  `Iterable.makeIterator` is added and disambiguated from the consuming one via `@_implements(Iterable,
  Iterator)` / `@_implements(Sequenceable, Iterator)` (the associated-type-trap escape hatch; already live
  on the 4 variants).

### 2.4 Flat-pool representation — trees/hashes become span-projecting (Angle A)

- **(decided)** Trees/hashes are represented as **flat pools** (nodes/values in one contiguous array, links
  by index) → span-projecting → they ride the same copy-self `makeIterator` default + the `forEach` floor.
  Angle A1 (flat tree) + A3 (chaining hash flattened to one `[Int]` pool) CONFIRMED.
- **(realize)** Not a set-ordered concern (contiguous via `Buffer.Linear`). This is the **fan-out doctrine**
  for tree/hash/graph packages.
- **(release-only gate, not design)** Pure-pointer **boxed** structures through a generic family default hit
  the **A2 release SIL crash** (`forwardToInit`; §6). Flat-pool **is** the dodge (a real borrowed region =
  A2b happy case). `/issue-investigation` + upstream candidate; not a design gate.

### 2.5 `Iterator.Borrow` — the `~Copyable` pull-style (the keystone to build)

- **(decided)** `~Copyable` pull-style iteration is borrow-yielding — past the by-value move-out wall.
  `Iterator.Borrow.\`Protocol\`<Borrowed>: Iterator.\`Protocol\`` where `Element == Ownership.Borrow<Borrowed>`.
  Because `Ownership.Borrow<Value: ~Copyable & ~Escapable>` is **Copyable + `~Escapable`**,
  `next() -> Ownership.Borrow<Borrowed>?` returns a Copyable handle — the `~Copyable`-ness lives in
  `Borrowed`, never moved out by value. This is composition (`Iterator.\`Protocol\` ∘ Ownership.Borrow`), not
  invention; the abstraction exists in `swift-iterator-borrow-primitives` (5/5 green debug).
- **(realize — Option C, the evergreen home; DECIDED 2026-05-30)** The concrete conformer is **shipped**:
  `Iterator.Borrow.Scalar<Borrowed: ~Copyable>` (`base: UnsafePointer<Borrowed>` + count + index) in
  `swift-iterator-borrow-primitives/Sources` (`f31ce11`; the test `TokenIterator` dissolved into it, 5/5 green;
  named for its *manner* — scalar/element-at-a-time, the borrow analog of bulk `Iterator.Chunk`, [API-NAME-001b];
  `Borrowed: ~Copyable` is necessarily Escapable since `UnsafePointer<Pointee>` requires it — the §6.1 ceiling).
  Its `base + count` are **NOT** derivable from `Swift.Span` (verified wall: `Span<~Copyable>` exposes no
  escaping element address — `_unsafeAddressOfElement` is `internal`). They **are the existing minimal cores**:
  `base = Storage.Protocol.pointer(at: .zero)` (escaping `UnsafeMutablePointer`, ~Copyable-capable, public) +
  `count = Buffer.Protocol.count`. So **borrow-iteration composes over the Storage + Buffer cores**, not the
  `Memory.Contiguous` span: `Buffer.Linear` conforms **`Storage.Protocol` publicly** (forwarding `pointer(at:)`
  / `capacity` to its internal storage — the SBO enum-switch the inline variants need is exactly what the
  per-type `_iteratorBase()` window already does, so `_iteratorBase()` **dissolves** into the canonical
  conformance — it was a hand-rolled per-type duplicate of `pointer(at:)+count`, [ARCH-LAYER-011]); a single
  **`extension Iterable where Self: Storage.Protocol & Buffer.Protocol`** bridge vends
  `makeIterator() -> Iterator.Borrow.Scalar`; `Set.Ordered` and the whole buffer-backed family **delegate**
  `makeIterator { buffer.makeIterator() }`. **`Memory.Contiguous`'s safe `span` surface is untouched** — the
  escaping base belongs on the *addressable* `Storage` core, never the *safe-view* `Memory.Contiguous` core.
  - **Rejected:** **Option A** (a base accessor on `Memory.Contiguous.Protocol`) — pollutes the safe core with
    an unsafe escaping capability + forces every L1 conformer to witness it ([MOD-031]'s "NOT Option A" was the
    right instinct). **Option B′** (widen the per-type `_iteratorBase()` window to `@_spi public`) — perpetuates
    the hand-rolled duplicate instead of dissolving it into the `Storage.Protocol` core.
- **(open — build-verify; the one fragile spot)** The **@_rawLayout inline variants**
  (`Buffer.Linear.Inline`/`.Small`, backing `Set.Ordered.Small`/`.Static`) conforming `Storage.Protocol`'s
  escaping `pointer(at:)` is the soundness-fragile case: a pointer into *embedded* storage is valid only under
  the container borrow — the iterator's `@_lifetime(borrow base)` / `@_lifetime(&self)` is what makes it sound.
  Build-verify before the full rework; if it walls → escalate (architecture-shape call), do not retreat to A/B′.
- **(explicitly NOT doing)** No B1 coroutine-yield `next(_ body:)` (strictly more restrictive than pull-style
  `next()`); no B2 `~Escapable`-cursor invention; **no `forEach` fallback for the pull side** (that would be
  a cave — and unnecessary, pull-style works).

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
  ├─ forEach (plain borrowing func, UNIVERSAL incl. ~Copyable)  ◄ §2.1  the floor every structure inherits
  ├─ contains / first / reduce / satisfies                      ◄ compose from forEach
  └─ makeIterator (borrowing pull-style, Copyable)              ◄ §2.3  ONE requirement, TWO escapability-gated
        ├─ copy-self default  (span-projecting backing)               defaults (Angle B); through a
        └─ plain default      (non-span backing)                      ~Escapable copy-self view (Angle A/D1)

Collection.`Protocol` (collection-primitives)   [standalone now; : Iterable at FAN-OUT]   ◄ §2.2
  └─ subscript / Range / Slice / firstIndex (index-specific only)

Sequenceable (sequence-primitives)  : ~Copyable, ~Escapable   [orthogonal sibling — does NOT refine Iterable]
  ├─ forEach borrow-terminals → admit ~Escapable; + the @inline(always) Swift.Sequence dual-conformer bridge
  ├─ collect / first extraction-terminals → Element: Escapable
  ├─ makeIterator (CONSUMING, owning drain)            ◄ §2.6  hand-written scalar (set-ordered)
  └─ consume(_: (consuming Element) throws(E)->Void)   ◄ §2.7  CLOSURE terminal (Sequence.Consume DELETED;
                                                               symmetric to forEach; no View/ConsumeState/takeBuffer)

Iterator.Borrow.`Protocol` + Iterator.Borrow.Scalar (iterator-borrow-primitives)   ◄ §2.5  ~Copyable PULL-style;
  Scalar(base,count) SHIPPED. base = Storage.pointer(at:.zero) + count = Buffer.count → composes over the
  Storage + Buffer cores (Buffer.Linear: Storage.Protocol public; _iteratorBase() dissolved). NOT Swift.Span,
  NOT Memory.Contiguous. A `Iterable where Self: Storage.Protocol & Buffer.Protocol` bridge vends it; containers DELEGATE.

Swift.Sequence  (stdlib)  where Element: Copyable     ◄ §2.8  re-add; stdlib bridge, institute primary
```

**Element-kind coverage (target):**

| Element kind | Push-style (internal) | Pull-style (external) |
|---|---|---|
| `Copyable` | `Iterable.forEach` (floor) | `Iterable.makeIterator` (borrow) + `Sequenceable.makeIterator` (consuming) + `Swift.Sequence` bridge |
| **`~Copyable`** | `Iterable.forEach` (floor — `(borrowing Element)`) | **`Iterator.Borrow.Scalar`** over the `Storage.pointer(at:)` + `Buffer.count` cores (Option C, §2.5); containers delegate to the backing |
| `~Escapable` | `forEach` borrow-terminal | copy-self view (`@_lifetime(copy self)`) |

`forEach` is the **floor covering every cell**; the pull-style rows are affordances layered on top. The
consuming drain `consume(_:)` (§2.7) is the consuming sibling of `forEach`.

---

## 4. The ×16 fan-out recipe (the template — GATED, not authorized)

For each data-structure variant, **after** the set-ordered reference validates the shape AND the supervisor
re-verifies it (the fan-out is NOT pre-authorized; the per-action YES gate stands):

1. **Inherit `forEach` from the `Iterable` floor** (§2.1) — delete the per-variant body; declare `: Iterable`
   per-variant (the lift via protocol extension is refuted per Angle "shape A" — bodies inherit, conformance
   is per-variant).
2. **Choose the representation** (§2.4): contiguous/piecewise → span-projecting directly; tree/hash/graph →
   **flat-pool**. Avoid pure-pointer boxed nodes through generic defaults (A2 release bug); flat-pool is the dodge.
3. **Expose a `~Escapable` copy-self view** for the borrowing pull-style `Iterable.makeIterator` (§2.3);
   inherit the gated default. Piecewise (ring/deque) views list `@_lifetime(copy s1, copy s2, …)` per segment.
4. **Consuming route** (§2.6/§2.7): delegate `Sequenceable.makeIterator` (consuming) to the backing's
   hand-written `.Scalar`; the consuming drain is the inherited `Sequenceable.consume(_:)` closure terminal —
   **no `takeBuffer`, no `Sequence.Consume.Protocol`**. Use `Memory.Snapshot.Cursor` only if a package needs
   a generic contiguous bridge, its backing trips the demangle, and it has no hand-written scalar.
5. **`~Copyable` pull-style** (§2.5, Option C): the backing conforms `Storage.Protocol` (public) + `Buffer.Protocol`;
   the `Iterable where Self: Storage.Protocol & Buffer.Protocol` bridge vends `Iterator.Borrow.Scalar`; the
   container **delegates** `makeIterator { backing.makeIterator() }`. `~Copyable` variants get **both** `forEach`
   (push) and the delegated `Iterator.Borrow.Scalar` (pull) — no per-type `_iteratorBase()`, no fallback.
6. **`Swift.Sequence` bridge** (§2.8): re-add `where Element: Copyable` once the iterator shape is settled.
7. **`Collection` refinement cascade** (§2.2): for `Collection.\`Protocol\`` conformers, drop
   `Collection.ForEach` for the inherited floor — workspace-enumerate first ([HANDOFF-050]).
8. **MOD-036 type/ops boundary**: apply the windowless-interim recipe. **Do NOT replicate `takeBuffer`** (gone).

**The recipe is data-shaped-vs-resource-shaped aware** ([DS-021]): `Copyable` (data-shaped) variants get the
by-value pull-style routes; `~Copyable` (resource-shaped) variants get `forEach` (push) + `Iterator.Borrow`
(pull). Institute containers pass `~Copyable` through — no `[Swift.String]` fallbacks.

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
| 1 | `forEach` → inherited floor | per-variant method (Copyable; ~Copyable hand-written) | inherited from `Iterable` default; works for both element kinds via §2.5 | §2.1 |
| 2 | borrowing `makeIterator` | only consuming exists | add gated borrowing `Iterable.makeIterator` via copy-self view; `@_implements` split | §2.3 |
| 3 | consuming drain | `Sequenceable.consume(_:)` closure terminal — **DONE** (`13ab89f`; Sequence.Consume + takeBuffer deleted) | no change needed | §2.7 |
| 4 | consuming iterator | backing `.Scalar` (hand-written) | **keep** | §2.6 |
| 5 | `~Copyable` pull-style + `Iterable`(~Copyable) | not vended; `Iterable` is `where Element: Copyable` | **Option C**: `Iterator.Borrow.Scalar` SHIPPED (`f31ce11`) · `Buffer.Linear: Storage.Protocol` public (dissolve `_iteratorBase()`) · `Storage&Buffer→Iterable-borrow` bridge vends it · `Set.Ordered: Iterable` ~Copyable **delegates** `makeIterator { buffer.makeIterator() }`. Open: inline-variant `pointer(at:)` soundness (build-verify gate) | §2.5 |
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

### 6.1 The two-world duality (load-bearing claim)
**give-away vs keep-and-lend.** For move-only elements, `owned ⇒ single-pass` and `borrowed ⇒ multipass`.
- **World A — owned iteration (give-away, single-pass):** the iterator world. `Iterator.\`Protocol\`` +
  `Sequenceable` (consuming `makeIterator`). A World-A step gives an element away.
- **World B — borrowing traversal (keep-and-lend, multipass):** `Iterable` (borrowing `makeIterator`, already
  `@_lifetime(borrow self)`). The container survives and re-vends. **Multipass comes from the EXISTING
  `Iterable` — no new attachable.** `~Copyable` multipass is `Iterator.\`Protocol\`` instantiated with
  `Element == Ownership.Borrow<T>` (= `Iterator.Borrow`); the world is chosen by the element binding, not a
  distinct protocol. (The `~Escapable`-*element* axis — lending a view of a genuinely non-escaping element —
  stays language-blocked at the `Swift.Span` ceiling; revisit when the language matures.)

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

### 6.3 The memory→Iterable bridge + the withdrawn `Iterator.Walk`
`Memory.Contiguous.\`Protocol\`` (`var span: Span<Element>`) is the span-projecting substrate. The
memory→Iterable bridge is **witness-only**: a constrained extension supplying
`borrowing func makeIterator() -> Iterator.Chunk(span)` (reusing the canonical bulk iterator; no iterator of
its own) + the span-lending `forEach` floor. The bridge's `makeIterator`/`Iterator.Chunk` scalar path is
**Copyable-gated** (the move-out wall) — which is exactly why the ~Copyable PULL path goes through
`Iterator.Borrow.Scalar` (§2.5), composed over the **Storage + Buffer cores**, NOT the Memory.Contiguous span.
**Decomposition principle (Option C, the truly-correct home):** the escaping base address belongs to the
*addressable* `Storage.Protocol` core (`pointer(at:)`), **never** the *safe-view* `Memory.Contiguous` core
(`span`) — so an escaping-base accessor on `Memory.Contiguous.Protocol` (Option A) pollutes the safe core, and
a per-type `_iteratorBase()` window (Option B′) is a hand-rolled duplicate of `Storage.pointer(at:) +
Buffer.count` ([ARCH-LAYER-011]) that dissolves into `Buffer.Linear`'s public `Storage.Protocol` conformance.
A v1.0.0 `Iterator.Walk` (a new owning iterator type) was
**withdrawn**: the owning iterator is the deferred owned-`Cursor` sibling (`Memory.Cursor`, homed in the
existing `swift-memory-cursor-primitives`), not a new type — and a borrowed-view cursor + an owned cursor are
two types because escapability is fixed at declaration. `Ownership.Borrow`'s typed-pointer init refused
`@_lifetime` on an Escapable result (OQ-2 V1 refuted: "invalid lifetime dependence on an Escapable result").

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
- A by-value `next() -> Element?` for raw `~Copyable` multipass (A4): SILGen crash → use `forEach` (push) +
  `Iterator.Borrow` (pull) instead.

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

**Status: APPROVED** (reconciled to disk, v2.1.0; Option C locked). `Iterator.Borrow.Scalar` is **shipped**
(`f31ce11`); the rework composes ~Copyable borrow-iteration over the **Storage + Buffer cores** (§2.5). The
one genuinely-open build item is the **@_rawLayout inline variants conforming `Storage.Protocol`'s escaping
`pointer(at:)`** soundly — the build-verify gate at the heart of the reference rework. The consuming drain
(`Sequenceable.consume(_:)`) and release-cleanliness are **done**. Sequence: **set-ordered reference rework
(§5: Buffer.Linear:Storage.Protocol public → bridge → Set.Ordered delegates) → re-verify → promote the recipe
→ ×16 fan-out (§4)** — each gate per-action.

---

## 8. References

- **Execution / coordination:** `HANDOFF-data-structure-iteration-arc.md` (the single working doc — current
  state, gates, queue, loose ends).
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
