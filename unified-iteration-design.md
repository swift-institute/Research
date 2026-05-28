# Unified Iteration Design — the ×16 Fan-Out Template

<!--
---
version: 1.2.0
last_updated: 2026-05-28
status: APPROVED
tier: 2
scope: cross-package
supervises_gate: "Track-3 design gate — APPROVED 2026-05-28 (v1.1.0 passed D1–D5); set-ordered reference rework (§5) AUTHORIZED. Held gates remain: Consumable sign-off before templating (§6.1); fan-out (§4) NOT authorized until supervisor re-verifies the validated reference (HANDOFF-iteration-arc-supervisor.md §gates)."
builds_on:
  - "iteration-architecture-expressibility-envelope.md v1.3.0 (the empirical proof of the decided shape)"
  - "memory-cursor-generic-witness-demangle-reshape.md v1.0.0 (the consuming-iterator reshape)"
  - "swift-iterator-borrow-primitives (the ~Copyable pull-style, since 2026-05-25; 5/5 green debug)"
  - "swift-set-ordered-primitives/Audits/mod-036-type-ops-boundary.md (the type/ops recipe + consume()/takeBuffer interim)"
changelog:
  - "1.2.0 (2026-05-28): Supervisor APPROVED (v1.1.0 passed D1–D5); §5 rework AUTHORIZED. §2.7/§6.1 corrected per supervisor directive — Consumable witness role is ALREADY served by the EXISTING Sequence.Consume.`Protocol` (verified: `consuming func consume() -> View<Element, ConsumeState>`; set-ordered already conforms); NO new sibling (same check-existing-before-inventing lesson as Iterator.Borrow). takeBuffer elimination is a delegation-shape choice, settled-in-rework + sign-off. Added §5 stale-comment reconciliation row (set-primitives Set.Protocol.swift:22-39 pre-victory-pessimism comment + dead cite). Status → APPROVED."
  - "1.1.0 (2026-05-28): Supervisor review iteration #1. GATE-1 false-premise CORRECTED — Iterator.Borrow EXISTS (swift-iterator-borrow-primitives) and is proven (5 tests/5 suites green debug, verified); ~Copyable pull-style is solved by composition (Iterator.Protocol ∘ Ownership.Borrow), no B1/B2 invention, no validation spike, no forEach fallback. §1.2/§2.5/§3/§4/§5/§6/§7 rewritten: Iterator.Borrow is adopt+verify (integration step, not an architecture gate). GATE-2 reframed (sibling Consumable witness, not makeIterator overload; settled-from-semantics + brought back for sign-off). §2.9 committed to sentinel-empty as the sole correct shape (delete the take-and-put-back workaround; escalate-don't-retreat if walled). #3/#4/#5 confirmed by supervisor."
  - "1.0.0 (2026-05-28): Initial design note (the nine integrated elements + ×16 recipe + set-ordered rework delta)."
---
-->

> **RECOMMENDATION (v1.1.0, 2026-05-28)** — Tier 2, cross-package. This is the **design** that realizes
> the **LOCKED Track-3 iteration shape** (UNIFIED family delegation; shape-b retired) across the ~16
> data-structure packages, with **set-ordered as the reference exemplar**. It maps the decided shape onto
> the **real ecosystem protocol surface** and makes the folded sub-decisions concrete.
>
> **This note does not lock architecture and does not touch the packages.** The iteration *shape* is the
> **supervisor's decision** (LOCKED — see `HANDOFF-iteration-arc-supervisor.md` §Track-3). This note
> proposes the *realization* of that shape and **must pass supervisor review before any rework or
> fan-out** (the gate).
>
> **v1.1.0 — supervisor review iteration #1.** The v1.0.0 GATE-1 premise ("`Iterator.Borrow` is new /
> unproven") was **false** and is corrected: `Iterator.Borrow` **exists** (swift-iterator-borrow-primitives,
> since 2026-05-25) and is **proven** (5 tests / 5 suites green debug — verified, not relayed). `~Copyable`
> pull-style is **already solved by composition** (`Iterator.\`Protocol\` ∘ Ownership.Borrow`); there is
> **no** validation gate, **no** B1/B2 invention, and **no** `forEach` fallback. The only `Iterator.Borrow`
> work is **adoption** — an integration step in §5, not an architecture decision.

---

## 1. Context

The data-structure iteration rebuild perfects **set-ordered** (+ **set-primitives**) as exemplars, then
replicates to **~16** packages on a single iteration shape. Two prerequisites are done:

- **The iteration shape is DECIDED** (supervisor, LOCKED) — UNIFIED family delegation; `shape-b` retired.
  Won by re-attacking the v1.2.0 "REFUTED" with a `~Escapable` self-tied walker; the empirical envelope
  (`iteration-architecture-expressibility-envelope.md` **v1.3.0**, toy at
  `Experiments/iteration-architecture-toy` `8ae35fb`) proves it end-to-end (debug+release) under the full
  ecosystem flags.
- **set-ordered orthogonal perfection is DONE** — MOD-036 type/ops boundary across all 4 variants
  (windowless-interim), per-variant test topology, `~Copyable` bare-extension fix; **156 debug-green**;
  HEAD `d8ea1fd`. Release is blocked by `#86652` (an *ambient* buffer-linear `@_rawLayout`+deinit verifier
  ICE — independent of iteration).

What this note designs is the **iteration rework** to the decided shape, plus the items deliberately
*folded* into it: `Swift.Sequence` re-add, `consume()`/`takeBuffer` elimination + the consuming-iterator
choice, and Small's `drain()` evergreen (optional-hashTable redesign).

### 1.1 Verified current state (set-ordered HEAD `d8ea1fd`, 2026-05-28)

Per-variant iteration conformances today — **all gated `where Element: Copyable`** except `Sequence.Drain`:

| Conformance | Where | Notes |
|---|---|---|
| `Iterable` | iterator-primitives | `extension Set.Ordered: Iterable where Element: Copyable` |
| `Sequenceable` | sequence-primitives | consuming `makeIterator()` → backing `Buffer<Element>.Linear.{variant}.Scalar` (hand-written scalar) |
| `Memory.Contiguous.\`Protocol\`` | memory | span-projecting substrate witness, `where Element: Copyable` |
| `Sequence.Drain.\`Protocol\`` | sequence-primitives | the only conformance not `Copyable`-gated in declaration |
| `Sequence.Clearable` | sequence-primitives | `where Element: Copyable` |
| `Sequence.Consume.View` | sequence-primitives | `consume()` returns it; reaches storage via interim `package consuming func takeBuffer()` (base/Fixed/Static) |

- `forEach` is a `(borrowing Element) throws(E) -> Void` method (route 3) — the universal vehicle, present.
- `Swift.Sequence` is **NOT** currently conformed — input-only (`init<S: Swift.Sequence>`,
  `buildExpression<S: Swift.Sequence>`). Dropped in the MOD-036 rework; a deliberate **re-add** target.
- `makeIterator()` is **consuming** and delegates to the backing buffer's `.Scalar` — set-ordered
  *composes* `Buffer.Linear`; Static/Small back onto `Buffer.Linear.Inline`/`Small` (both `@_rawLayout`).
- Small's `drain()` compiles for `~Copyable` **today**, but only via a take-and-put-back workaround around
  the optional `~Copyable` hash table (`Set.Ordered.Small ~Copyable.swift`, the
  `if var ht = hashTable { ht.remove.all(...); hashTable = ht }` block ~ll.139–141; direct
  `hashTable?.remove.all()` crashes `DiagnoseStaticExclusivity`). See §2.9.

### 1.2 Real ecosystem protocol topology (the names the toy abstracted)

| Concept | Real type | Package |
|---|---|---|
| Element-iteration floor (borrow-style) | `Iterable` | swift-iterator-primitives |
| Scalar foundation iterator (`next()` uniformly `@_lifetime(&self)`, extraction → `Escapable`) | `Iterator.\`Protocol\`` | swift-iterator-primitives |
| Bulk span iterator (`Span` ceiling, `Escapable`-narrowed) | `Iterator.Chunk.\`Protocol\`` | swift-iterator-primitives |
| `~Copyable` **borrow-yielding pull-style** | `Iterator.Borrow.\`Protocol\`<Borrowed>: Iterator.\`Protocol\``, `Element == Ownership.Borrow<Borrowed>`, `Borrowed: ~Copyable & ~Escapable` — **EXISTS, proven 5/5** | swift-iterator-borrow-primitives |
| Copyable + `~Escapable` borrow handle (the lent element) | `Ownership.Borrow<Value: ~Copyable & ~Escapable>: ~Escapable` | swift-ownership-primitives |
| Bulk/scalar sequence (`~Copyable & ~Escapable`; forEach-borrow + collect/first-extraction) | `Sequenceable` | swift-sequence-primitives |
| Borrowing sequence | `Sequence.Borrowing.\`Protocol\`` | swift-sequence-primitives |
| Consuming owning-drain view (`next()`+`forEach`) | `Sequence.Consume.View` | swift-sequence-primitives |
| Span-projecting substrate witness | `Memory.Contiguous.\`Protocol\`` | swift-memory-primitives |
| Lazy / eager consuming cursors | `Memory.Cursor` / `Memory.Snapshot.Cursor` | swift-memory-cursor-primitives |
| Index-based collection | `Collection.\`Protocol\`` | swift-collection-primitives |

`Sequenceable` already carries the decided **extraction-vs-borrow split** (`associatedtype Element:
~Copyable & ~Escapable`; borrowing terminals admit `~Escapable`, extraction terminals `collect`/`first`
constrain `Element: Escapable`) — the load-bearing prior art the decided shape rests on.

---

## 2. The decided shape, realized (the nine integrated elements)

Each sub-section states **(decided)** the locked element, **(realize)** the concrete mapping, and any
**(open)** sign-off item. The supervisor LOCKED the shape; this is its realization.

### 2.1 `forEach` floor on `Iterable` — the universal vehicle (Angle C)

- **(decided)** `forEach` is the universal floor on `Iterable`: **every** structure gets it, including
  `~Copyable` (borrowing closure). Envelope Angle C (`§7.3`) is the **most complete unification** (one
  `forEach` default for span-projecting + traversal-only + `~Copyable`, debug+release) — `forEach` returns
  `Void`, so there is no lifetime-dependent return.
- **(realize)** The floor lives on `Iterable` as `func forEach<E: Swift.Error>(_ body: (borrowing
  Element) throws(E) -> Void) throws(E)`. set-ordered already has exactly this signature — it becomes the
  inherited protocol floor. `contains`/`first`/`reduce`/`allSatisfy` compose **from** `forEach`.
- **(open)** None — proven core. Realization is hoisting the per-variant `forEach` body to the `Iterable`
  default and letting variants inherit it.

### 2.2 `Collection` refines / vends `Iterable` (index-lifetime bug-class removal)

- **(decided)** `Collection.\`Protocol\`` **refines** `Iterable`. Element-iteration is **inherited**;
  index-based `Collection.ForEach` **collapses**; `Collection` keeps only index-specific ops
  (`subscript`/`Range`/`Slice`/`firstIndex`).
- **(realize)** A protocol-layer change in swift-collection-primitives: add `: Iterable` to
  `Collection.\`Protocol\``; delete `Collection.ForEach`; re-point its consumers to the inherited floor.
  set-ordered conforms `Iterable` **directly** today (it does **not** conform `Collection.\`Protocol\``),
  so for set-ordered this is a no-op at the conformance site — but load-bearing for the fan-out
  (array/buffer/deque packages that *do* conform `Collection` shed `Collection.ForEach`).
- **(open / sequencing)** Fan-out-phase cascade (confirmed §6) — enumerate every `Collection.\`Protocol\``
  conformer + `Collection.ForEach` consumer workspace-wide ([HANDOFF-050]) before the refinement lands.

### 2.3 Gated `makeIterator` — one protocol, two escapability-gated defaults (Angle B)

- **(decided)** `makeIterator` (Copyable **pull-style**, borrow-style) is **one** requirement with **two**
  same-named conditional defaults, dispatched by the backing iterator's escapability: **copy-self**
  (`@_lifetime(copy …)`-flattening through a `~Escapable` view) for span-projecting backings, **plain**
  (no `@_lifetime`) for non-span. Envelope Angle B (`§7.2`) CONFIRMED per-conformer dispatch, debug+release.
- **(realize)** The borrowing pull-style route on `Iterable`; the two defaults gate on
  `Backing.Iterator` escapability. Governing principle (envelope §3): a lifetime-dependent iterator
  composes through `@_lifetime(copy …)`, never `@_lifetime(borrow <local>)` — the default delegates
  through a copy-self `~Escapable` view; the variant exposes that view.
- **(open)** set-ordered's *current* `makeIterator()` is **consuming** (the `Sequenceable` route); adding a
  borrowing `Iterable.makeIterator` re-opens the surface (the `Swift.Sequence` re-add brushes this — §2.8).
  The two `makeIterator`s (borrowing-`Iterable` vs consuming-`Sequenceable`) disambiguate via `@_implements`.

### 2.4 Flat-pool representation — trees/hashes become span-projecting (Angle A)

- **(decided)** Trees/hashes are represented as **flat pools** (nodes/values in one contiguous array,
  links by index) → span-projecting → they ride the same `Iterable` copy-self `makeIterator` default and
  the `forEach` floor. Envelope A1 (flat tree) + A3 (chaining hash flattened to one `[Int]` pool) CONFIRMED.
- **(realize)** Not a set-ordered concern (set-ordered is contiguous via `Buffer.Linear`). This is the
  **fan-out doctrine** for tree/hash/graph packages: pick the flat-pool representation so they fall inside
  the span-projecting family.
- **(gate / release-only)** **Pure-pointer boxed** structures routed through a generic family default hit
  the **A2 release compiler bug** (`forwardToInit`; envelope §7.4). Flat-pool **is** the dodge (real
  borrowed region = A2b happy case). `/issue-investigation` + upstream candidate; **not a design gate** (§6).

### 2.5 `Iterator.Borrow` — the `~Copyable` pull-style — **EXISTS + PROVEN** (adopt + verify)

- **(decided)** `Iterator.Borrow` provides `~Copyable` **pull-style** iteration — borrow-yielding, "past
  A4's by-value move-out wall."
- **(realize — already solved by composition; verified primary source)** `Iterator.Borrow` is **not new**.
  `swift-iterator-borrow-primitives` (since 2026-05-25) declares
  `Iterator.Borrow.\`Protocol\`<Borrowed>: Iterator.\`Protocol\`, ~Copyable, ~Escapable where Element ==
  Ownership.Borrow<Borrowed>`, `Borrowed: ~Copyable & ~Escapable`. Because `Ownership.Borrow<Value: ~Copyable
  & ~Escapable>` is **Copyable + `~Escapable`**, `next() -> Ownership.Borrow<Borrowed>?` returns a **Copyable
  handle** — the `~Copyable`-ness lives in `Borrowed`, never moved out by value. This **dodges the envelope's
  A4 wall by construction** (A4 refuted by-value `next() -> Element?` for raw `~Copyable`; here the element
  IS the Copyable `Ownership.Borrow`). The package's suite is **green: 5 tests / 5 suites passed (debug,
  verified by running it)** — exercising a `~Copyable` `Token`, pull-style `while let b = it.next()`,
  multipass `makeIterator`, and generic functions over both `Iterator.\`Protocol\`` and
  `Iterator.Borrow.\`Protocol\``. So **`~Copyable` pull-style is solved** by `Iterator.\`Protocol\` ∘
  Ownership.Borrow` — composition, not invention.
- **(explicitly NOT doing)** No B1 coroutine-yield `next(_ body:)` (it is strictly *more restrictive* than
  the existing pull-style `next()` — do not introduce it); no B2 `~Escapable`-cursor invention; no
  validation spike to "prove the shape" (it is proven); **no `forEach` fallback** (that would be a cave —
  forbidden, and unnecessary since pull-style works).
- **(open — adoption only, an integration step not an architecture gate)** Vend `Ownership.Borrow<Element>`
  over set-ordered's `Buffer.Linear` backing (conform the backing's borrow iterator to
  `Iterator.Borrow.\`Protocol\``) and **build-verify the conformance** (debug; release rides `#86652`).
  Lands in §5.

### 2.6 The consuming-iterator choice — snapshot vs lazy vs hand-written

- **(decided)** The consuming iterator's shape folds into this design (NOT adopted standalone).
- **(realize)** Three shapes (from `memory-cursor-generic-witness-demangle-reshape.md` v1.0.0):

  | Shape | Witness mangling | Cost | `~Copyable` elem | Verdict for set-ordered |
  |---|---|---|---|---|
  | **lazy `Memory.Cursor<Base>`** | deep → **corrupt for the literal `@_rawLayout` inline family** (demangle `'}'` SIGABRT) | per-`next()` re-derivation, no alloc | yes (lazy) | **REJECT** for Static/Small (back onto `@_rawLayout` `Inline`/`Small` → trips the crash) |
  | **`Memory.Snapshot.Cursor<Element>`** | shallow → **safe** | one `[Element]` alloc + bulk copy | no (Copyable & Escapable) | the demangle-safe **generic** option |
  | **hand-written scalar** (current: `Buffer.Linear.{variant}.Scalar`) | concrete → **safe** | no alloc, per-variant | per backing | **current production; green; recommended for set-ordered** |

- **(recommendation — supervisor-CONFIRMED §6 #4)** **set-ordered stays hand-written-scalar** (composes
  `Buffer.Linear.{variant}.Scalar`, dodges the demangle class, no alloc). Do **not** adopt the lazy
  `Memory.Cursor<Self>` bridge (crashes on the inline family Static/Small use). Keep
  **`Memory.Snapshot.Cursor` reserved** as the generic fan-out option (not in production; name pending
  [API-NAME-001]). The choice is **per-backing**, made where the backing lives (buffer-linear), not here.

### 2.7 `consume()` / `takeBuffer` elimination — the EXISTING `Sequence.Consume.\`Protocol\`` is the witness

- **(decided)** Eliminate the interim `package consuming func takeBuffer()`; resolve `consume()` via the
  unified default.
- **(realize — supervisor-directed check-existing-before-inventing; VERIFIED)** The witness role is
  **ALREADY served by the existing `Sequence.Consume.\`Protocol\``** — **no new sibling.** Verified from
  source: `public protocol \`Protocol\`: ~Copyable { associatedtype Element: ~Copyable; associatedtype
  ConsumeState; consuming func consume() -> View<Element, ConsumeState> }`. set-ordered **already conforms**
  it (`consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.ConsumeState>`, body
  `takeBuffer().consume()`). `consume()` is **NOT droppable-as-redundant** (distinct from
  `Sequenceable.makeIterator()`: owning composable drain vs pipeline source; exercised in 8+ tests
  `var view = set.consume(); while let e = view.next()`). So the Consumable design is **adoption of the
  existing protocol**, not invention (same lesson as Iterator.Borrow).
- **(the actual takeBuffer issue — a delegation-shape choice, not a new protocol)** `takeBuffer()` exists
  only because `consume()` returns a `Sequence_Primitives` type and was exiled to the **ops** module, from
  which it reaches storage through the interim `package` accessor (recipe note §"backing-delegation
  principle" — the forbidden **(c)** ops-forwarder shape). Eliminate it with a sanctioned delegation shape:
  **(a)** co-locate `consume()` in the type module (with storage; accept the `Sequence_Primitives` import
  there), or **(b)** an inherited generic default delegating to the backing's own
  `Sequence.Consume.\`Protocol\`.consume()` (the unified-family-delegation-consistent choice —
  `Buffer.Linear` already conforms `Sequence.Consume.\`Protocol\``). Delete `takeBuffer` across
  base/Fixed/Static. **The fan-out MUST NOT replicate `takeBuffer`** (recipe note is explicit).
- **(open — net-new *delegation default* = sign-off)** The settled delegation shape (a vs b), grounded in
  `Sequence.Consume.View`'s actual surface during the reference rework, is **brought back to the supervisor
  for sign-off** before it templates. The witness *protocol* is existing; only the chosen delegation
  default is net-new.

### 2.8 `Swift.Sequence`-where-Copyable bridge (re-add)

- **(decided)** Keep `Swift.Sequence` as the **stdlib bridge** (`where Element: Copyable`); institute
  iteration (`Iterable`/`Sequenceable`) primary.
- **(realize)** Re-add `extension X: Swift.Sequence where Element: Copyable` providing a stdlib
  `makeIterator() -> some IteratorProtocol` bridging the institute iterator to stdlib for-in + algorithms.
  Dropped in the MOD-036 rework because it brushes the `makeIterator` surface; re-adds **after** §2.3/§2.6
  settle (it must bridge the settled iterator). `@_implements` disambiguates stdlib vs the institute ones.
- **(open)** Sequencing only — lands in the reference rework after §2.3/§2.6.

### 2.9 Small's optional-`~Copyable`-hashTable redesign — commit the evergreen

- **(decided)** The non-optional + sentinel-empty redesign is the **sole correct structural shape** — it
  **MUST land** in the rework and **delete** the take-and-put-back workaround.
- **(realize)** Small's storage is `hashTable: Hash.Table?` (optional, spill-only) + `isSpilled` over
  `_buffer: Buffer.Linear.Small<inlineCapacity>`. `drain()` compiles for `~Copyable` **today** only via a
  take-and-put-back workaround (`Set.Ordered.Small ~Copyable.swift`, the
  `if var ht = hashTable { ht.remove.all(keepingCapacity: true); hashTable = ht }` block ~ll.139–141) —
  direct `hashTable?.remove.all()` crashes `DiagnoseStaticExclusivity` on the optional `~Copyable` table.
  **Redesign: make the hash table non-optional with a sentinel-empty state** (an always-present
  `Hash.Table`, empty while unspilled), so `drain()` mutates a definitely-present `~Copyable` value with
  no optional in-place mutate — the workaround is **deleted**, the direct `hashTable.remove.all(...)`
  stands. `isSpilled` is retained as a capacity/threshold predicate (no longer an `Optional` test).
- **(no cave)** This is committed evergreen, not a hypothesis: it **must** land and delete the workaround.
  **If sentinel-empty hits a wall, escalate** (architecture-shape call) — **do not retreat** (no reverting
  to `Copyable`-gated drain). Also a `/issue-investigation` candidate (the `DiagnoseStaticExclusivity`
  crash is a compiler-diagnostic bug worth reducing) — tracked separately, not a design gate.

---

## 3. The unified protocol-layering picture (target)

```
Iterable  (iterator-primitives)        ── element-iteration floor
  ├─ forEach (borrowing, UNIVERSAL incl. ~Copyable)      ◄ §2.1  the floor every structure inherits
  ├─ contains / first / reduce / allSatisfy              ◄ compose from forEach
  └─ makeIterator (borrowing pull-style, Copyable)       ◄ §2.3  ONE requirement, TWO escapability-gated
        ├─ copy-self default  (span-projecting backing)        defaults (Angle B); delegates through a
        └─ plain default      (non-span backing)               ~Escapable copy-self view (Angle A/D1)

Collection.`Protocol` (collection-primitives)  : Iterable          ◄ §2.2  refines Iterable; ForEach collapses
  └─ subscript / Range / Slice / firstIndex (index-specific only)

Sequenceable (sequence-primitives)  : ~Copyable, ~Escapable        ◄ already split borrow vs extraction
  ├─ forEach borrow-terminals → admit ~Escapable
  ├─ collect / first extraction-terminals → Element: Escapable
  ├─ makeIterator (CONSUMING, owning drain)             ◄ §2.6  hand-written scalar (set-ordered) /
  │                                                              Memory.Snapshot.Cursor (generic option)
  └─ consume() -> Sequence.Consume.View                 ◄ §2.7  EXISTING Sequence.Consume.`Protocol` IS
                                                                 the witness (no sibling); NO takeBuffer

Iterator.Borrow.`Protocol` (iterator-borrow-primitives)            ◄ §2.5  ~Copyable PULL-style — EXISTS,
  : Iterator.`Protocol`, Element == Ownership.Borrow<Borrowed>             PROVEN (5/5). adopt + verify.

Swift.Sequence  (stdlib)  where Element: Copyable         ◄ §2.8  re-add; stdlib bridge, institute primary
```

**Element-kind coverage (target):**

| Element kind | Push-style (internal) | Pull-style (external) |
|---|---|---|
| `Copyable` | `Iterable.forEach` (floor) | `Iterable.makeIterator` (borrow) + `Sequenceable.makeIterator` (consuming) + `Swift.Sequence` bridge |
| `~Copyable` | `Iterable.forEach` (floor — universal vehicle) | **`Iterator.Borrow`** (`Iterator.\`Protocol\` ∘ Ownership.Borrow`) — **proven 5/5** |
| `~Escapable` | `forEach` borrow-terminals (Sequenceable) | copy-self view (`@_lifetime(copy self)`) |

`forEach` is the **floor that covers every cell** (the envelope's "most complete unification"); the
pull-style rows are the **affordances layered on top** — including `~Copyable` pull-style, which the
existing `Iterator.Borrow` composition supplies (no fallback needed).

---

## 4. The ×16 fan-out recipe (the template)

For each data-structure variant, after the set-ordered reference rework validates the shape:

1. **Inherit `forEach` from the `Iterable` floor** (§2.1) — delete the per-variant `forEach` body; declare
   `: Iterable` per-variant (one line; the lift is refuted per envelope shape A — bodies inherit,
   conformance is per-variant).
2. **Choose the representation** (§2.4): contiguous/piecewise → span-projecting directly; tree/hash/graph →
   **flat-pool** so it is span-projecting too. Avoid pure-pointer boxed nodes through generic defaults
   (A2 release bug) — flat-pool **is** the dodge.
3. **Expose a `~Escapable` copy-self view** for the borrowing pull-style `Iterable.makeIterator` (§2.3);
   inherit the gated default. Piecewise (ring/deque) views list `@_lifetime(copy s1, copy s2, …)` per
   segment (envelope gap (a)).
4. **Consuming route** (§2.6/§2.7): delegate `Sequenceable.makeIterator` (consuming) to the backing's
   hand-written `.Scalar`; resolve `consume()` via the **existing `Sequence.Consume.\`Protocol\``** (no new
   sibling) with a delegation default to the backing's `consume()` — **no `takeBuffer`**. Use
   `Memory.Snapshot.Cursor` only if the package needs a generic contiguous bridge, its backing trips the
   demangle, and it has no hand-written scalar.
5. **`~Copyable` pull-style** (§2.5): adopt `Iterator.Borrow` — vend `Ownership.Borrow<Element>` over the
   backing and build-verify the conformance. `~Copyable` variants get **both** `forEach` (push) and
   `Iterator.Borrow` (pull) — no conditional, no fallback.
6. **`Swift.Sequence` bridge** (§2.8): re-add `where Element: Copyable` once the iterator shape is settled.
7. **MOD-036 type/ops boundary**: apply the windowless-interim recipe (recipe note §"Base-variant recipe").
   **Do NOT replicate `takeBuffer`** (interim, resolved by step 4).

**The recipe is data-shaped-vs-resource-shaped aware** ([DS-021]): `Copyable` (data-shaped) variants get
the by-value pull-style routes; `~Copyable` (resource-shaped) variants get `forEach` (push) + the proven
`Iterator.Borrow` (pull). Institute containers pass `~Copyable` through — no `[Swift.String]` fallbacks.

---

## 5. set-ordered reference-rework delta (current → target)

Set-ordered reference rework **AUTHORIZED 2026-05-28** (v1.1.0 passed D1–D5). Held gates remain: the row-3
Consumable **delegation-shape sign-off** before it templates; **fan-out (§4) NOT authorized** until the
supervisor re-verifies the validated reference.

| # | Change | Current | Target | Element |
|---|---|---|---|---|
| 1 | `forEach` → inherited floor | per-variant method | inherited from `Iterable` default | §2.1 |
| 2 | borrowing `makeIterator` | only consuming exists | add gated borrowing `Iterable.makeIterator` via copy-self view; `@_implements` split | §2.3 |
| 3 | `consume()`/`takeBuffer` | `takeBuffer` interim (base/Fixed/Static) reaches storage from ops module | resolve `consume()` via the **existing `Sequence.Consume.\`Protocol\``** (no new sibling) + delegation default; **delete `takeBuffer`**; delegation shape (co-locate vs inherited default) → supervisor sign-off | §2.7 |
| 4 | consuming iterator | backing `.Scalar` (hand-written) | **keep** (recommended); `Memory.Snapshot.Cursor` not needed here | §2.6 |
| 5 | `~Copyable` pull-style | not vended | vend `Ownership.Borrow<Element>` over `Buffer.Linear` backing (conform `Iterator.Borrow.\`Protocol\``); **build-verify** the conformance (debug; release rides `#86652`) — integration step | §2.5 |
| 6 | `Swift.Sequence` | not conformed (input-only) | **re-add** `where Element: Copyable` | §2.8 |
| 7 | Small `drain()` evergreen | take-and-put-back workaround (`Set.Ordered.Small ~Copyable.swift` ~ll.139–141) | non-optional + sentinel-empty redesign; **delete the workaround**; escalate-don't-retreat if walled | §2.9 |
| 8 | promote recipe note | gitignored at `swift-set-ordered-primitives/Audits/mod-036-type-ops-boundary.md` | promote final recipe to tracked `swift-institute/Research/` (the OWED item) | recipe note header |
| + | **stale `Set.Protocol` comment** (set-primitives; supervisor §5 add) | `swift-set-primitives/.../Set.Protocol.swift:22-39` — "family-protocol `Backing` lift is NOT expressible" + dead cite to nonexistent `iteration-architecture-set-probe.md` | reconcile/remove — pre-victory pessimism (the `Backing` lift was overturned in the v1.3.0 re-attack; pull-style lives on `Iterable`, not `Set.Protocol`) | §2.2 |

Build/test green on **debug** (release blocked by `#86652`, an ambient unrelated ICE); 156-test floor must
not regress.

---

## 6. Sign-off / sequencing for supervisor re-review

### 6.1 The one net-new-surface sign-off item — the `consume()` delegation default

- **Consumable witness (§2.7) — VERIFIED: no new protocol.** Per the supervisor's check-existing directive,
  the witness role is **already served by the existing `Sequence.Consume.\`Protocol\``** (`consuming func
  consume() -> View<Element, ConsumeState>`); set-ordered already conforms it. **No new sibling.** What
  remains net-new is the **delegation default** that eliminates the interim `takeBuffer` — either
  **(a)** co-locate `consume()` in the type module, or **(b)** an inherited generic default delegating to
  the backing's own `Sequence.Consume.\`Protocol\`.consume()`. The chosen shape, grounded in
  `Sequence.Consume.View`'s actual surface during the reference rework, is **brought back to the supervisor
  for sign-off** before it templates. This is the only item that returns for sign-off mid-rework.

### 6.2 Resolved by supervisor correction (v1.1.0)

- **`Iterator.Borrow` (§2.5)** — **NOT a gate.** It exists (swift-iterator-borrow-primitives) and is proven
  (5/5 green debug, verified). `~Copyable` pull-style = `Iterator.\`Protocol\` ∘ Ownership.Borrow`.
  Remaining work is **adoption** (integration step, §5 row 5) — vend + build-verify. No spike, no B1/B2,
  no `forEach` fallback.

### 6.3 Confirmed by supervisor

- **(#3) Collection-refines-Iterable = fan-out phase** (§2.2) — set-ordered doesn't conform `Collection`;
  `Collection.ForEach` exists. Enumerate workspace-wide ([HANDOFF-050]) at fan-out, not in the set-ordered rework.
- **(#4) set-ordered stays hand-written-scalar** (§2.6); `Memory.Snapshot.Cursor` reserved as the generic
  fan-out option, not in production, name pending [API-NAME-001].
- **(#5) A2 release bug / Small SIL crash / `#86652`** are `/issue-investigation` + release-readiness
  items, **not design gates** (flat-pool + sentinel-empty mitigate the first two; `#86652` is ambient).

---

## 7. Outcome

**Status: RECOMMENDATION** (supervisor review iteration #1 incorporated). The design realizes the LOCKED
Track-3 shape across the real ecosystem protocol surface; **there is no unproven architecture element** —
the prior `Iterator.Borrow` "gate" was a false premise (it exists and is proven; adoption is an
integration step). The **one net-new-surface item that returns for sign-off** is the `Consumable` witness
(§2.7/§6.1), settled-from-semantics during the rework. On supervisor re-review against D1–D5 and pass, the
sequence is: **set-ordered reference rework (§5) → promote the recipe note → ~16-package fan-out (§4)**.

---

## 8. References

- `swift-institute/Research/iteration-architecture-expressibility-envelope.md` v1.3.0 — the empirical
  proof of the decided shape (Angles A/B/C; the §3 governing principle; the A2 release bug; gap a/b/c).
- `swift-institute/Research/memory-cursor-generic-witness-demangle-reshape.md` v1.0.0 — the
  consuming-iterator reshape (lazy vs snapshot vs hand-written; the demangle class; the trade-off table).
- `swift-iterator-borrow-primitives` — `Iterator.Borrow.\`Protocol\`<Borrowed>: Iterator.\`Protocol\``,
  `Element == Ownership.Borrow<Borrowed>`; the `~Copyable` pull-style by composition; suite 5 tests / 5
  suites green debug (verified 2026-05-28).
- `swift-ownership-primitives` — `Ownership.Borrow<Value: ~Copyable & ~Escapable>: ~Escapable` (the
  Copyable + `~Escapable` borrow handle; `~Copyable`-ness lives in `Value`).
- `swift-set-ordered-primitives/Audits/mod-036-type-ops-boundary.md` — the type/ops recipe; the
  `consume()`/`takeBuffer` interim + backing-delegation principle; the Small storage shape; the test-template constraints.
- `swift-institute/Experiments/iteration-architecture-toy` `8ae35fb` — the toy (Phase8–11 = the v1.3.0
  re-attack).
- `swift-institute/Experiments/memory-cursor-generic-witness-demangle` — the demangle reproduction (targets A–F).
- `HANDOFF-iteration-arc-supervisor.md` — the LOCKED Track-3 decisions + the gates + the standing principles.
- Skills: [RES-002]/[RES-003]/[RES-019]/[RES-020]/[RES-023]; [DS-021]/[DS-022]; [MOD-036]/[MOD-037];
  [HANDOFF-050]; [API-NAME-001]; [API-ERR-001]; `feedback_extension_implies_copyable`.
