# Sequencer-Primitives Reconciliation Refactor (Draft)

<!--
---
version: 0.10.1
last_updated: 2026-05-26
status: DRAFT
tier: 3
scope: ecosystem-wide
changelog:
  - "0.10.1 (2026-05-26): naming: bulk tier Iterator.Span/Contiguous → Iterator.Chunk; Memory.Contiguous.Iterator example → Memory.Contiguous. All 12 references to the iterator-primitives bulk tier `Iterator.Span.Protocol` brought current to `Iterator.Chunk.Protocol` (§1–§2 tables, §4b, Stage-A A5, §7 spike, §9). The bulk method (`next(maximumCount:)`) is unchanged; sequence-side `nextSpan` / `Sequence.Iterator.Protocol` / `Sequence.Borrowing.Protocol`, the retracted `Sequencer.Span.Protocol` sugar, `Iterator.Borrow.Protocol` (keep-and-lend), and `Swift.Span` are all left untouched."
  - "0.10.0 (2026-05-26): §15 `Sequence.Borrow.Viewing` REMOVED (`62088d8`) as redundant — on review it was a
     near-clone of `Sequence.Borrow.Map` whose hand-rolled `Borrowed` view duplicated `Ownership.Borrow<Output>`
     (both `Output: Escapable`; no capability difference, just plain vs Borrow protocol conformance). It did NOT
     deliver `~Escapable` output. CORRECTS 0.9.0's over-claim. Clean model: two things at the element level —
     `Element` (role) + `Ownership.Borrow<T>` (the one borrow-element type). Borrow package back to 4 tests / 2
     suites green debug+release. Genuine `~Escapable` output stays the SE-0507/0519-gated frontier (unchanged)."
  - "0.9.0 (2026-05-26): §15 ~Escapable-output Map SHIPPED — `Sequence.Borrow.Viewing` @ 79627a0 in
     swift-sequence-borrow-primitives (local, 7 tests green debug+release): plain `Iterator.Protocol`
     conformer, `Element` = a `~Escapable` view of an iterator-owned slot, deinit teardown; coexists with
     the `Ownership.Borrow`-lending Map. Frontier pinned: the only case that walls today is a transform
     *re-lending a view of a `_read`-yielded base input* (`Ownership.Borrow.value` is a statement-scoped
     `_read` coroutine) — exact diagnostic `lifetime-dependent value escapes its scope`; gated on SE-0507/0519
     in a production compiler. Viewing sidesteps it by viewing self-owned storage. So ~Escapable output IS
     delivered today; only the view-of-a-_read-yielded-input case is the documented frontier."
  - "0.8.0 (2026-05-26): §15 decompose-and-compose RESOLUTION (principal directive: improve/reuse, not
     bespoke). Confirmed by experiment `swift-iterator-primitives/Experiments/escapable-element-iterator-conformance`
     (6.3.2 debug+release, sum=30): the `~Escapable`-output Map is a PLAIN `Iterator.Protocol` conformer whose
     `Element` is the `~Escapable` view (the foundation already declares `Element: ~Copyable & ~Escapable` +
     `@_lifetime(&self)` 'to admit ~Escapable element types … views into iterator-owned storage'). NOT a bespoke
     per-Map type, NOT an `Ownership.Borrow` change (improving it is the wrong lever: different element-shape, and
     impossible on 6.3.2 — the raw-pointer→Builtin.Borrow/SE-0519 gap). `Ownership.Borrow`/`Iterator.Borrow.Protocol`
     is the narrower sugar for lend-a-stored-`Escapable`-value; forcing produced-view output through it was the
     category error. deinit teardown (no finish()). Two element-shapes, two clean primitives."
  - "0.7.0 (2026-05-26): §15 ~Escapable-output claim CORRECTED by experiment
     `swift-institute/Experiments/escapable-output-borrow-lend` (6.3.2 release + main-snapshot-2026-05-12-a
     dev, debug+release, cross-module). The 0.5.0 'walls in BOTH worlds / Borrowed: Escapable hard
     constraint' claim is REFUTED as fundamental — it was scoped to the `Ownership.Borrow` + `UnsafeMutablePointer<Out>`
     slot shape only. Lending a `~Escapable` output is ACHIEVABLE TODAY on 6.3.2 (verified cross-module
     debug+release) via either a stored `~Escapable` property returned under `@_lifetime(&self)` (P2a) OR a
     bespoke nested `~Escapable Borrowed` vending struct over an Escapable iterator-owned slot (P4). The
     ergonomic stdlib path (SE-0519, which ships as `Ref<Value>` not `Borrow<Value>`, + SE-0507 `borrow`-accessor
     read-back) is production-GATED — live on the dev line under `BorrowAndMutateAccessors`/`@available(9999)`,
     absent on 6.3.2. Nothing fundamentally impossible on any toolchain. (Also covers 0.6.0: as-built
     borrow package @ 41cae37, finish()→deinit footgun fix, §15 Implemented note.)"
  - "0.5.0 (2026-05-26): D-2 RESOLVED (§4b) from first principles (principal: evergreen,
     semantics, optimize decomposition/composition) — RETIRE the bulk-span borrowing protocol;
     do NOT relocate it as `Sequencer.Span.Protocol`. Borrowing-sequence decomposes to
     `Iterable where Iterator: Iterator.Borrow.Protocol` (= §4a `Sequencer.Borrow.Protocol`,
     scalar, storage-agnostic); bulk-span = contiguous-memory property → `Memory.Contiguous.Protocol`
     (lone conformer `Sequence.Span` migrates there; every call site already passes `Cardinal(UInt.max)`
     = no chunking). New §15 — World-B borrowing-Map spike (/tmp) PASSED debug+release: owned-heap-slot
     + `Ownership.Borrow(unsafeAddress:borrowing: self)` + `@_lifetime(&self)`. Composes over ~Escapable
     BASE elements; `Borrowed`/output MUST be Escapable (`~Escapable` output walls in BOTH worlds with
     today's `Ownership.Borrow` — no slot, no read-back; awaits SE-0519 or a bespoke Borrowed type).
     A8 (Stage A): World-A Map Output stays Escapable = correct world-boundary, not a concession."
  - "0.4.0 (2026-05-26): §14 — surface decision for iteration terminals. Property.Borrow
     cannot host iteration on a production compiler (its `_read`-coroutine base access is
     statement-scoped → iterator escapes the loop); Property.Inout is mutating (wrong for a
     non-destructive scan); Property requires an Escapable Base (excludes ~Escapable
     iterables). The SE-0507 `borrow` accessor IS the clean fix and IS validated to solve it
     (Swift 6.4-dev/6.5-dev), but is gated out of production releases (≤ 6.3.2). DECISION:
     iteration terminals ship as plain `borrowing func` (modern ~Escapable; iterator tied to
     stable borrowing-self; reaches ~Escapable iterables). forEach shipped (31c419c). Revisit
     the Property surface when SE-0507 reaches a production compiler."
  - "0.3.0 (2026-05-25): Spike A0 EXECUTED against the real protocols — gate
     PASSED (§11). D-1 resolved: Sequenceable (consuming) reuses Iterator.Protocol
     and a type CAN dual-conform to Sequenceable+Iterable via @_implements (the
     associated-type-trap escape hatch); Map collapses to scalar (unsafe nextSpan
     deleted); lifetime-annotation rule learned (@_lifetime rejected on Escapable
     yields — omit it). Decisions locked: stem=Sequencer; relocate the
     borrowing-terminal suite to Iterable now (§12, upgrades drawback #1).
     Execution sequencing added (§13): Phase 0 = terminal suite on Iterable
     (additive, safe, FIRST); the breaking sequencer rename is GATED on the
     parallel WIP in swift-sequence-primitives clearing. Iterable doc corrected
     (commits d0e0f54, 094b465)."
  - "0.2.0 (2026-05-25): Added §9 Performance and §10 Drawbacks (honest
     assessment). Key addition: the inverted foundation makes bulk-capability
     CONDITIONAL — transforming combinators (Map/Filter) already cap spans at 1
     element behind a uniform nextSpan facade, so the inversion surfaces an
     existing truth rather than regressing, but the price is conditional
     Iterator.Chunk.Protocol conformance on preserving combinators (Drop/Prefix
     are bulk only when their base is). Net perf is neutral-to-slightly-positive;
     performance is a constraint to preserve, not a driver. Drawbacks: the reuse
     win is thin (one protocol) for a large breaking cascade; D-1 may have no
     clean answer; tension with collection-sequence detachment Step-C (which
     slates Sequence.Borrowing for removal); package sprawl; building on a
     just-stabilized foundation."
  - "0.1.0 (2026-05-25): Initial draft. Reconciles swift-sequence-primitives
     onto the swift-iterator-primitives foundation (the World-A/B element-type
     collapse applied to the sequence domain) and remodels it to
     swift-sequencer-primitives + swift-sequencer-borrow-primitives. Grounded in
     a full read of the current sequence protocol stack + representative
     combinators on 2026-05-25 (Apple Swift 6.3.2). Two-stage plan, NOT executed
     — Stage A is gated on a 3-combinator foundation-reuse spike and sign-off."
---
-->

> **Status — DRAFT plan, not a decision.** This is the refactor draft the
> 2026-05-25 iterator arc was asked to produce. The naming decisions (§0) are
> locked by the principal; the architecture (§2–§4) is grounded in the current
> source but the central protocol decision (§3, D-1) is **gated on a spike** and
> the cascade (§5) on sign-off. It is class-(c) ecosystem work: surfaced here,
> not auto-dispatched.
>
> Predecessor: `two-world-traversal-decomposition.md` (v1.2.1) established that a
> borrowing iterator is the *existing* `Iterator.`Protocol`` with
> `Element = Ownership.Borrow<T>`. This doc carries that collapse into the
> sequence domain.

## 0. Decisions already made (principal, 2026-05-25)

| # | Decision | Source |
|---|----------|--------|
| N-1 | Naming follows **iterator-primitives' lead** | principal |
| N-2 | `Sequence.Borrowing` (bulk-span) **splits into a borrow package**, mirroring the `swift-iterator-borrow-primitives` precedent | principal |
| N-3 | Scalar borrowing-sequence shape — **my call** (see §4, resolved) | principal (delegated) |
| N-4 | Timing — **draft now** (this document) | principal |

**The lead already wrote the names down.** iterator-primitives' own doc comments
forward-reference the counterpart package and attachable:

- `Iterator.Protocol.swift:29` — "an atomic peer of **`swift-sequencer-primitives`**".
- `Iterable.swift:16-18` — "**`Sequenceable`** (in `swift-sequencer-primitives`,
  when it lands) refines it with the algorithm suite (map/filter/reduce/…). A
  type that is `Sequenceable` is automatically `Iterable`."

So "follow the lead" resolves concretely (one item flagged for confirmation in §6):

| Role | iterator-primitives | sequencer-primitives (this refactor) |
|------|---------------------|--------------------------------------|
| World-A package | `swift-iterator-primitives` | `swift-sequencer-primitives` |
| Namespace | `Iterator` | `Sequencer` (renamed from `Sequence`) |
| World-A attachable | `Iterable` | `Sequenceable` |
| World-B package | `swift-iterator-borrow-primitives` | `swift-sequencer-borrow-primitives` |
| World-B scalar protocol | `Iterator.Borrow.Protocol` | `Sequencer.Borrow.Protocol` |

> The forward-reference doc comment is over-optimistic on one point ("a type that
> is `Sequenceable` is automatically `Iterable`"). §3/D-1 shows why that is
> probably **false** as written and must be corrected as part of Stage A.

## 1. What is actually being reconciled

swift-sequence-primitives carries a **complete, siloed iterator stack** that
predates and duplicates swift-iterator-primitives, and does **not depend on it**
(its deps are property/index/cardinal-primitives only). The reuse target:

| Siloed today (swift-sequence-primitives) | Foundation it duplicates (swift-iterator-primitives) |
|---|---|
| `Sequence.Iterator.Protocol` (`Sequence.Iterator.Protocol.swift:109`) | `Iterator.Protocol` (`Iterator.Protocol.swift:31`) |
| `Sequence.Protocol` (attachable, `Sequence.Protocol.swift:97`) | `Iterable` (`Iterable.swift:19`) — but see D-1 |
| `Sequence.Borrowing.Protocol` (`Sequence.Borrowing.Protocol.swift:43`) | `Iterator.Chunk.Protocol` + `Iterable` (§4) |

## 2. Finding A — the two iterator foundations are *inverted*

This is the structural fact the in-chat memo missed, and it sets the migration shape.

| | Requirement | Derived |
|---|---|---|
| **`Iterator.Protocol`** (iterator-primitives) | `next() -> Element?` (**scalar-first**) | `nextSpan` added by the `Iterator.Chunk.Protocol` refinement |
| **`Sequence.Iterator.Protocol`** (sequence-primitives) | `nextSpan(maximumCount:) -> Span<Element>` (**bulk-first, sole requirement**) | `next()` derived via `nextSpan(maximumCount: 1)` |

The sequence iterator is **bulk-first**; the foundation iterator is
**scalar-first**. Reconciliation is not a rename — it is rectifying an inverted
foundation. The combinators split cleanly along the inversion (verified against
source):

| Combinator class | Current `nextSpan` impl | Maps onto | Effect of reconciliation |
|---|---|---|---|
| **Element-transforming** — `Map`, `CompactMap`, `FlatMap`, `Filter` | "Optional inline": `var _element: Element?` + `Span(_unsafeStart:)` + `_overrideLifetime` (`Sequence.Map.Eager.Iterator.swift:44-61`) | scalar **`Iterator.Protocol`** (`next()` only) | **Net simplification** — the entire unsafe-`Span` block deletes; the clean `next()` (already present, `…:66-69`) becomes the sole impl. Removes `unsafe`. |
| **Element-preserving forward-to-base** — `Drop.First/While`, `Prefix.First/While` | forwards `nextSpan` to base for bulk throughput via `extracting(droppingFirst:)` (`Sequence.Drop.While.Iterator.swift:52-67`) | **`Iterator.Chunk.Protocol`** (refines `Iterator.Protocol`; carries `nextSpan`) | **Preserved** — keep bulk forwarding; `next()` comes along via the refinement |

The two foundations' `nextSpan` signatures are compatible up to the count
parameter: foundation uses `some Carrier.Protocol<Cardinal>`
(`Iterator.Chunk.Protocol.swift:30-32`); sequence uses bare `Cardinal`. The
forward-to-base iterators need only widen the parameter — mechanical.

**Bonus relaxation.** `Sequence.*.Protocol.Element` is `~Copyable` but **not**
`~Escapable` ("BLOCKED until `Swift.Span<Element>` accepts `Element: ~Escapable`",
`Sequence.Iterator.Protocol.swift:113-115`). That block is a *consequence of
being bulk-first* (the `Span` ceiling). On the scalar `Iterator.Protocol`
(`Element: ~Copyable & ~Escapable`) the block lifts for the element-transforming
path. Scalar combinators can relax to `~Escapable`-admitting elements; only the
bulk path stays `Escapable`-narrowed (the `Span` ceiling, unchanged).

## 3. Finding B — the central decision: `consuming` vs `borrowing` makeIterator (D-1)

`Sequence.Protocol.makeIterator()` is **`consuming`** (`@_lifetime(copy self)`,
`Sequence.Protocol.swift:126-127`). `Iterable.makeIterator()` is **`borrowing`**
(`@_lifetime(borrow self)`, `Iterable.swift:41-42`). These are different ownership
contracts on the *same* method, and a `consuming` requirement cannot satisfy a
`borrowing` one. So the lead's "`Sequenceable` *refines* `Iterable`" claim is, as
written, **probably false**.

This is not a detail — it is the same orthogonality that
`collection-sequence-protocol-detachment.md` (DECISION, v1.1.0) already ruled on:

- `consuming makeIterator` → single-pass, give-away container; enables the lazy
  pipeline (`.map{}.filter{}.collect()` stores each consumed stage) **and** admits
  genuinely single-pass `~Copyable` sources (network streams, one-shot generators)
  — the entire reason `Sequence` exists distinct from `Collection`.
- `borrowing makeIterator` → multipass; the container survives and re-vends. That
  is the **Collection** side. `Iterable` (borrowing) sits with Collection, not
  Sequence.

Forcing `Sequenceable` to refine `borrowing` `Iterable` would re-introduce exactly
the coupling that detachment removed, and would **exclude single-pass `~Copyable`
sources** — gutting `Sequence`.

**Options for D-1:**

| | Shape | Verdict |
|---|---|---|
| **D-1a (recommended)** | `Sequenceable` keeps `consuming makeIterator`; does **not** refine `Iterable`. Reuse is at the **iterator** level only: swap the `Iterator` associatedtype bound from `Sequence.Iterator.Protocol` → `Iterator.Protocol`. Correct the `Iterable.swift:16-18` doc comment. | Aligns with the detachment decision; preserves single-pass sources; smallest semantic change |
| D-1b | `Sequenceable` adopts `borrowing makeIterator` to genuinely refine `Iterable` | **Rejected** — loses single-pass `~Copyable` sources; re-couples Sequence to the multipass (Collection) side |
| D-1c | `Sequenceable` declares **both** a `consuming` and a `borrowing` `makeIterator` (ownership-overloaded) | **Spike required** — unknown whether Swift accepts two `makeIterator()` overloads differing only in self-ownership at a protocol-witness level |

**Recommended target (D-1a):**

```swift
public protocol Sequenceable<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable                       // §2: scalar path may relax to ~Escapable
    associatedtype Iterator: Iterator_Primitive.Iterator.`Protocol`, ~Copyable, ~Escapable
        where Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}
```

i.e. today's `Sequence.Protocol` with one bound changed (`Sequence.Iterator.Protocol`
→ `Iterator.Protocol`) and renamed to the top-level `Sequenceable`. The combinator
algebra (map/filter/reduce/…) hangs off it exactly as it hangs off `Sequence.Protocol`
today (`Sequence.Protocol+Map.swift`, `…+ForEach.swift`).

> **The reuse is real, but it is at the iterator, not the attachable.** World A's
> *attachable* (`Sequenceable`, consuming) and the multipass attachable
> (`Iterable`, borrowing) stay distinct — they are the two-world duality at the
> container level, not a refinement chain. Both reuse the one `Iterator.Protocol`.

## 4. World B — the borrow package (N-2, N-3 resolved)

Two World-B sequence shapes, both **dissolve** by the same element-type / iterator-type
collapse the iterator arc proved — neither needs a bespoke protocol hierarchy:

**(a) Scalar borrowing-sequence (N-3, my decision).** A borrowing sequence that
lends one `Ownership.Borrow<T>` per step is just a **multipass `Iterable` whose
`Iterator` is an `Iterator.Borrow.Protocol`**. Following the
`Iterator.Borrow.Protocol` precedent exactly — provide a thin, opt-in **sugar**
refinement, no new mechanism:

```swift
// swift-sequencer-borrow-primitives
extension Sequencer.Borrow {
    public protocol `Protocol`<Borrowed>: Iterable, ~Copyable, ~Escapable
    where Iterator: Iterator.Borrow.`Protocol`, Iterator.Borrowed == Borrowed {
        associatedtype Borrowed: ~Copyable & ~Escapable
    }
}
```

Decision rationale: keeps the family symmetric (`Iterator.Borrow` ↔
`Sequencer.Borrow`), is multipass via the existing `Iterable` (correct for
keep-and-lend), and — like its iterator sibling — is **opt-in sugar over
`Iterable where Iterator: Iterator.Borrow.Protocol`**, directly usable without it.
It does *not* refine `Sequenceable` (that one is consuming/single-pass; borrowing
sequences are multipass — they belong on the `Iterable` side, consistent with D-1a).

**(b) Bulk-span borrowing (`Sequence.Borrowing.Protocol`, N-2).** Today's
`Sequence.Borrowing.Protocol` is `borrowing makeIterator` + a `nextSpan`-iterator
— i.e. structurally **`Iterable where Iterator: Iterator.Chunk.Protocol`**. It
dissolves the same way: a thin `Sequencer.Span.Protocol` sugar, OR no protocol at
all (constrain on the bare form). **But** `collection-sequence-protocol-detachment.md`
(Step C) already reframes this shape as a *"chunked span access optimization over
`Memory.Contiguous.Protocol`, not borrowing iteration,"* eventually removable, with
canonical borrowing iteration routed through `Collection.ForEach` (index-based).

→ **D-2 (RESOLVED 2026-05-26 — RETIRE).** Decided from first principles (principal directive:
evergreen, work from semantics, optimize decomposition/composition). The bulk-span borrowing
shape does **not** survive as `Sequencer.Span.Protocol`. Reasoning:

- **Decomposition.** Strip "borrowing sequence" to its axes → three non-overlapping primitives:
  lend-one-borrowed-element = `Iterator.Borrow.Protocol` (`Ownership.Borrow<T>`, storage-agnostic);
  have-contiguous-storage = `Memory.Contiguous.Protocol` (`var span`); multipass container = `Iterable`.
  A "borrowing sequence" is the **composition** `Iterable where Iterator: Iterator.Borrow.Protocol`
  (= §4a `Sequencer.Borrow.Protocol`) — the whole evergreen concept, and it composes over *any*
  structure. `Sequencer.Span.Protocol` would name a synonym for `Iterable where Iterator: Iterator.Chunk.Protocol`
  **and** miscategorize a contiguous-memory optimization as a sequence kind — both anti-decomposition.
- **Semantics.** Lending a `Span` *requires contiguous memory*; "produce span chunks" is a property of
  contiguous storage, not a kind of sequence. Its home is `Memory.Contiguous.Protocol`.
- **Evidence.** The only real conformer to today's `Sequence.Borrowing.Protocol` is `Sequence.Span`
  (contiguous, span-backed); `Memory.ContiguousProtocol` (+ borrowed variant) already exists; and per
  detachment Step C (C4) **every call site passes `Cardinal(UInt.max)`** — nobody chunks, so the
  "bulk-span iterator" is functionally just `Memory.Contiguous.span`.

**Consequence:** the borrow package's scope = `Sequencer.Borrow.Protocol` (scalar) + the borrowing Map
(§15); **no bulk-span protocol.** `Sequence.Span` is reframed as a `Memory.Contiguous.Protocol` conformer
(its span access lives where contiguous storage lives), sequenced with the detachment Step-C audit so the
lone existing conformer is not broken abruptly. The earlier "relocate as opt-in sugar, preserve conformers"
recommendation is **retracted** — that was consumer-preservation reasoning, not first-principles. Does not
block Stage A.

## 5. The two stages

Staged because A is a large mechanical reuse cascade over a shipped/consumed
package and B is conceptually subtle; stabilize A before compounding B onto a
moving foundation.

**Stage A — structural reuse (World A, no borrowing).**

| Step | Change | Scope |
|---|---|---|
| A0 | **Spike gate** (see §7) — re-express 3 representative combinators on the foundation before cascading | /tmp |
| A1 | Add `swift-iterator-primitives` dep; resolve D-1 (recommend D-1a) | Package.swift + 1 protocol |
| A2 | `Sequence.Protocol` → `Sequenceable` (top-level); `Iterator` bound → `Iterator.Protocol` | 1 file + renames |
| A3 | Delete the siloed `Sequence.Iterator.Protocol` / `Sequence.Iterator` target; repoint conformers | target removal |
| A4 | Migrate element-transforming iterators (Map/CompactMap/FlatMap/Filter) to scalar `Iterator.Protocol` — **delete the unsafe `nextSpan` blocks** | ~6 iterators |
| A5 | Migrate element-preserving iterators (Drop/Prefix) to `Iterator.Chunk.Protocol` (widen count param to `some Carrier.Protocol<Cardinal>`) | ~4 iterators |
| A6 | Repoint terminals (ForEach/Reduce/Contains/First/Satisfies/Hint/Drain/Consume/Clearable) + Difference onto `Sequenceable` + reused `next()` | suite |
| A7 | Namespace rename `Sequence` → `Sequencer`; package rename → `swift-sequencer-primitives`; product/target/module renames | package-wide |
| A8 | Relax scalar-path `Element` to `~Escapable`-admitting where the iterator is scalar (§2 bonus) | targeted |
| A9 | Correct `swift-iterator-primitives/Iterable.swift:16-18` doc comment (`Sequenceable` does *not* auto-refine `Iterable` under D-1a) | 1 file, upstream |

**Stage B — borrowing (World B).**

| Step | Change |
|---|---|
| B1 | Create `swift-sequencer-borrow-primitives` (deps: sequencer-primitives + iterator-borrow-primitives + ownership-primitives) |
| B2 | Add `Sequencer.Borrow.Protocol` scalar sugar (§4a) |
| B3 | Relocate `Sequence.Borrowing.Protocol` → `Sequencer.Span.Protocol` sugar (§4b), tagged deprecation-candidate per D-2 |
| B4 | Land the parked `Experiments/borrowing-sequence-pitch` findings here (note: that experiment dir is **parallel-session WIP** — coordinate, do not clobber) |

## 6. Naming item to confirm before execution

One genuine fork (the principal typed "sequence-borrow-primitives" but also said
"follow iterator-primitives' lead", and the lead writes `swift-sequencer-primitives`):

- **Stem:** is the World-A package renamed `swift-sequence-primitives` →
  **`swift-sequencer-primitives`** (with namespace `Sequence` → `Sequencer`), making
  the pair `sequencer` / `sequencer-borrow`? This draft assumes **yes** — it is what
  the iterator-primitives doc comments already commit to, it disambiguates from
  `Swift.Sequence`, and it keeps the stem shared (per the iterator-borrow precedent).
  The only alternative is keeping `swift-sequence-primitives` + `swift-sequence-borrow-primitives`
  (no namespace rename). **Confirm the stem before A7.**

## 7. De-risking — the Stage-A spike (A0)

Before any cascade, in /tmp (sequence-primitives is consumed; do not iterate
in-package — cf. parallel WIP in its tree): re-express **three** combinators
against the *real* foundation protocols —

1. `Map` (element-transforming → scalar `Iterator.Protocol`; confirm the unsafe
   `nextSpan` block is unnecessary),
2. `Drop.While` (element-preserving → `Iterator.Chunk.Protocol`; confirm bulk
   forwarding holds with the widened count param),
3. one bulk-span consumer (confirm `Iterable where Iterator: Iterator.Chunk.Protocol`
   drives multipass),

plus the **D-1 probe**: can a single type expose the consuming `Sequenceable`
pipeline while a sibling type exposes borrowing `Iterable` multipass over the same
storage (D-1a), and separately test D-1c (overloaded `makeIterator` by ownership).
Bring the spike's findings back before proposing the A4–A6 cascade.

## 8. Blast radius / risks

- **Consumed package.** `swift-sequence-primitives` has downstream consumers; this
  is breaking. Pre-1.0, so breaking is acceptable (no compat shim), but the consumer
  cascade must be scoped before A7's rename (`grep` for `Sequence.Protocol` /
  `Sequence.Iterator` / module `Sequence_*` across the ecosystem).
- **Parallel work in the tree (do not clobber).** `Experiments/borrowing-sequence-pitch/Sources/main.swift`
  is modified by a parallel session; `Research/_index.json` + 3 docs are modified by
  a parallel session. This draft touches neither. The `_index.json` entry for this
  doc is **pending** (left untouched per no-interference, consistent with how the
  two-world doc's entry was handled).
- **D-1 is the gate.** If the D-1a recommendation is wrong (spike refutes it), the
  whole attachable story changes; everything downstream of A2 depends on it.

## 9. Performance

Performance is a **constraint to preserve, not a driver** of this refactor. The
honest summary: neutral-to-slightly-positive in the common case, with real
downside risk if discipline slips.

**The inversion makes bulk-capability conditional — and surfaces a hidden truth.**
Today every sequence iterator is bulk-capable (`nextSpan` is the sole
requirement), but that uniformity is partly illusory: the element-transforming
iterators return **at most one element per `nextSpan`** (`Sequence.Map.Eager.Iterator.swift:54-60`
does one `_base.next()` → transform → 1-span; Filter/CompactMap/FlatMap use the
same single `_element` inline slot). So Map/Filter already **cap any chain's
throughput at 1 element/step** behind a uniform facade. The only genuine bulk
path is `contiguous source → element-preserving combinator → terminal`
(`Drop.While.nextSpan` forwards `_base.nextSpan` + `extracting(droppingFirst:)`,
`…:52-67`). Post-inversion, this becomes explicit: `Drop`/`Prefix` conform to
`Iterator.Chunk.Protocol` **conditionally — only when their base does**
(`drop` over a contiguous source = bulk; `drop` over a `map` = scalar, because a
scalar Map has no `nextSpan` to forward). No throughput is lost (the fake bulk
had none); the cost is conditional-conformance complexity. **This is the primary
thing the §7 spike must validate.**

| Move | Effect |
|------|--------|
| Transforming → scalar `Iterator.Protocol` | **Win** — deletes the `Span(_unsafeStart:)` + `_overrideLifetime` ceremony (the code itself flags its overhead: "alignment check, `mark_dependence`, COW"); removes `unsafe`. The fake 1-element bulk had no throughput value. |
| Preserving → `Iterator.Chunk.Protocol` (conditional) | **Neutral iff** the existing tuned `next()` overrides (`@_lifetime(self: immortal)`, direct `_base.next()`) are **preserved**. **Regression** if they fall back to the foundation default `next()`, which routes through `nextSpan(1)` (span construction per element). Migration invariant: keep the overrides. |
| Cross-package split | iterator protocols move to a separate module; cross-boundary specialization now **depends on `@inlinable` discipline** on `next`/`nextSpan`. Same-package optimizer help is gone. Load-bearing. |
| World-B scalar `Ownership.Borrow<T>` vs bulk `Span<T>` | **Genuine tradeoff, not redundancy.** Scalar borrow = one `mark_dependence`/element; bulk span amortizes bounds + lifetime over a run. Contiguous byte/numeric workloads are materially faster on the span path → argument against retiring it (D-2). |
| Count param `some Carrier.Protocol<Cardinal>` | Minor — monomorphizes under `@inlinable`; witness-table dispatch only if specialization fails cross-module. |

## 10. Drawbacks (honest assessment)

Per the workspace collaboration protocol — challenging the proposal, not
rubber-stamping it.

1. **Large breaking cascade for thin delivered value.** The reuse win collapses
   essentially **one** duplicated protocol (`Sequence.Iterator.Protocol` →
   `Iterator.Protocol`). Under D-1a, `Sequenceable` and `Iterable` stay fully
   separate (consuming vs borrowing), so the "unification" is shallow: both merely
   bound their `Iterator` to the same protocol. Against that: rename a package +
   namespace ecosystem-wide, migrate ~10 iterators, repoint the whole
   combinator/terminal suite, break every consumer. The justification is coherence
   + evergreen, **not capability and not meaningful perf** — a legitimately
   questionable cost/benefit that the principal should weigh explicitly.

2. **D-1 may have no clean answer.** If the spike refutes D-1a *and* D-1c
   (ownership-overloaded `makeIterator`) does not compile, there is no graceful
   relation between `Sequenceable` and `Iterable`, and the counter-intuitive
   result "a `Sequenceable` is **not** `Iterable`" (contra stdlib `Sequence`) ships
   — likely needing copyable-only bridge conformances, i.e. *more* surface, not
   less.

3. **Tension with an existing DECISION.** `collection-sequence-protocol-detachment.md`
   Step C reframes `Sequence.Borrowing.Protocol` as a chunked-span optimization
   over `Memory.Contiguous.Protocol` and slates it for **eventual removal**, routing
   canonical borrowing iteration through `Collection.ForEach`. §4b proposes
   *relocating* it as `Sequencer.Span.Protocol` — standing up a package for a
   protocol the ecosystem already decided to retire. Must reconcile before B3.

4. **Package sprawl.** The iteration family becomes iterator + iterator-borrow +
   empty + single + 2 bridges + sequencer + sequencer-borrow. The deterministic
   "extra dep → own package" rule is principled, but the cumulative CI / dependency-edge
   / cognitive cost is real and worth naming.

5. **Building on a just-stabilized foundation.** Memory note
   `project_seq_reconcile_after_iterator` says reconcile *after* the iterator
   packages stabilize — and they changed **this session**. Plus live parallel WIP
   in the sequence tree (`Experiments/borrowing-sequence-pitch`). Any further
   iterator adjustment re-churns sequence. Argues for letting the foundation soak.

6. **Naming-churn payoff is disambiguation only.** Renaming `Sequence` →
   `Sequencer` ecosystem-wide breaks every `Sequence.Protocol` / `Sequence.Map` /
   `import Sequence_*` site to buy "doesn't shadow `Swift.Sequence`". And
   `Sequencer.Map` / `Sequencer.Filter` reads oddly — a *sequencer* is an agent,
   while Map/Filter are views/operations, not agents.

> **Bottom line.** The strongest case for proceeding is evergreen/correctness
> (remove the inverted-foundation confusion, one iterator protocol instead of two)
> and family symmetry — not performance and not new capability. The strongest case
> for *waiting* is (1)+(5): thin value over a just-moved foundation. A principled
> middle path: run the §7 spike (cheap, settles D-1 and the conditional-bulk
> question), then decide execute-vs-defer with that evidence in hand.

## 11. Spike executed (A0) — gate PASSED; decisions locked

The §7 de-risk spike ran against the REAL iterator-primitives protocols (Apple
Swift 6.3.2), `/tmp/sequencer-reconcile-spike`. All probes green:

| Probe | Result |
|-------|--------|
| `Sequenceable` (consuming) reusing the real `Iterator.Protocol`, move-only give-away | ✓ — the cell `Iterable` cannot reach |
| Map element-transforming → scalar `Iterator.Protocol`, unsafe `nextSpan` deleted | ✓ |
| Copyable container as `Sequenceable` (consuming pipeline) | ✓ |
| ONE type as BOTH `Sequenceable` + `Iterable` via `@_implements(Protocol, Iterator)` | ✓ |

**Findings that update the plan:**

1. **D-1 RESOLVED.** `Sequenceable` stays consuming/single-pass, reuses
   `Iterator.Protocol`, does not refine `Iterable`. The worlds are **not mutually
   exclusive**: a single type CAN conform to both via the associated-type-trap escape
   hatch `@_implements(Sequenceable, Iterator)` / `@_implements(Iterable, Iterator)` —
   both protocols name the iterator associatedtype `Iterator`, which Swift unifies, so
   the dual conformer splits the bindings (per `2026-04-20-associated-type-trap.md`;
   applied in swift-html-rendering). `Iterable.swift` doc corrected (`d0e0f54`, `094b465`).

2. **Map simplification CONFIRMED.** Element-transforming iterators drop the unsafe
   `Span(_unsafeStart:)` / `_overrideLifetime` block; scalar `next()` suffices.

3. **Lifetime-annotation rule (migration invariant).** `@_lifetime` is *rejected* on an
   Escapable result/target. A `next()`/`makeIterator()` yielding an Escapable
   element/iterator must **omit** the annotation (cf. `Iteration.next()` ships bare);
   only ~Escapable yields carry `@_lifetime(&self)` / `@_lifetime(borrow self)` /
   `@_lifetime(copy self)`. The real `Sequence.Protocol` doc's "accepted but has no
   effect" for Escapable conformers is WRONG — it is rejected. Every migrated combinator
   iterator follows this per-element-escapability rule.

**Decisions locked (principal):**
- **Stem = `Sequencer`** — `swift-sequence-primitives` → `swift-sequencer-primitives`;
  namespace `Sequence` → `Sequencer`; borrow pkg `swift-sequencer-borrow-primitives`.
- **Relocate the borrowing-terminal suite to `Iterable` now** (this refactor).

## 12. New phase — borrowing-terminal suite on `Iterable` (foundation-first)

The non-destructive terminal suite — `forEach`, `contains`, `first`,
`satisfies.all/any/none`, observing `reduce` — is **multipass/borrowing** and belongs
on `Iterable` in `swift-iterator-primitives`, not on the single-pass `Sequenceable`.
Relocating it makes the suite generic over *every* iterable (buffers, storage,
Single/Empty, cursors, later collections):
`func sum<I: Iterable>(_ x: borrowing I) where I.Iterator.Element == Int`. The consuming
terminals (`drain`, `consume`, `collect`) stay on `Sequenceable`.

This **upgrades drawback #1**: the refactor no longer delivers just "one collapsed
protocol" — it lands a foundation-level iteration vocabulary reusable ecosystem-wide.

Sub-decisions (settle during execution):
- **Surface form:** plain typed-throws methods on `Iterable` (dependency-light) vs the
  `Property<…>.Inout` tag pattern (pulls `property-primitives` into iterator-primitives).
  Recommend plain methods at the foundation; keep tag sugar (`.forEach.borrowing { }`)
  in sequencer if wanted.
- **Element ownership:** Copyable-element terminals relocate trivially; ~Copyable /
  borrowing-element forms carry the known closure-borrow patterns (two-world experiments).
- **Modularization:** in-`Iterable`-target extensions vs dedicated `Iterable * Primitives`
  targets per [MOD-*].

## 13. Execution sequencing (and a parallel-work gate)

1. **Phase 0 (safe, additive, FIRST): the §12 terminal suite on `Iterable`** in
   swift-iterator-primitives. Clean tree (verified `094b465`), non-breaking, no consumer
   cascade — and it is the substrate the sequencer reconciliation reuses. Start here.
2. **Phase A/B (breaking: sequencer rename + iterator reconciliation)** is **GATED** on
   the parallel-session WIP in `swift-sequence-primitives`
   (`Experiments/borrowing-sequence-pitch/Sources/main.swift`, confirmed present
   2026-05-25) clearing. A package/namespace rename is the most destructive operation
   w.r.t. parallel work; per the no-interference rule it MUST NOT start while uncommitted
   parallel work exists in that tree. Surface + wait for the principal to confirm the
   tree is clear (or coordinate).

## 14. Surface decision — iteration terminals are plain `borrowing func` (SE-0507 finding)

The §12 relocation raised a surface question — plain methods vs the institute's Property
fluent-accessor tags. Resolved empirically:

- **`Property.Borrow` cannot host iteration on a production compiler.** Its base access is
  a `_read` coroutine (statement-scoped), so an iterator derived through it escapes when
  held across a loop (`error: lifetime-dependent variable 'iterator' escapes its scope`,
  iterator-primitives build). `Property.Inout` gives a stable base but is *mutating* —
  semantically wrong for a non-destructive multipass scan and uncallable on a `let`. And
  `Property` requires an **Escapable Base**, so `~Escapable` iterables (cursors) are
  excluded regardless.
- **The SE-0507 `borrow` accessor is the clean fix** — it returns a borrow with a real
  lifetime dependency on `self`, holdable across a loop. Validated end-to-end on **Swift
  6.4-dev / 6.5-dev** (a `borrow`-accessor wrapper drives a held iterator to a correct
  result, `/tmp/borrow-hold-spike`). But `BorrowAndMutateAccessors` is **gated out of every
  production release** (≤ 6.3.2: *"cannot be enabled in production compiler"*), and the
  ecosystem targets production 6.3.2.
- **Decision (principal):** iteration terminals are **plain `borrowing func`** methods on
  `Iterable`. This is the modern ~Escapable shape that works today — the iterator is a
  `~Escapable` value tied to the *stable* borrow of `self` (no closure, no coroutine, no
  `unsafe`) — and it reaches `~Escapable` iterables, which the Property surface cannot.
  `forEach` shipped this way (`31c419c`).
- **Future:** when SE-0507 reaches a production compiler, revisit — replacing
  property-primitives' `_read` stopgaps (`Ownership.Borrow.value`, `Property.Borrow`) with
  `borrow` accessors would make the modern Property-tag iteration surface viable
  ecosystem-wide. (Aside: the property-primitives [PRP-001] table omits `Property.Borrow`
  and calls pointer variants "mandatory" for ~Copyable — both worth a skill-lifecycle pass.)

## 15. World-B borrowing Map — spike-validated design (Stage B)

The Stage-A A8 analysis surfaced that a transform yielding a *borrowed view* is a **lend**, which is
keep-and-lend (World B), not World-A give-away. A /tmp spike (`/tmp/borrowing-map-spike`, Apple Swift
6.3.2, debug **and** release) validated the World-B borrowing Map against the real
`Iterator.Borrow.Protocol` + `Ownership.Borrow`. **Verdict: SOUND — build it**, with two constraints
baked into the canonical implementation from day one.

**Canonical shape (owned heap slot — recommended over the heap-`init(borrowing:)` path, which
re-allocates per step):**

```swift
@safe struct BorrowingMap: ~Copyable, ~Escapable {
    let base: ...; let transform: (In) -> Out; var index: Int
    let slot: UnsafeMutablePointer<Out>          // self-owned, one element, stable address

    @_lifetime(immortal)
    init(...) { /* allocate + initialize slot once */ }

    consuming func finish() { slot.deinitialize(count: 1); slot.deallocate() }
}
extension BorrowingMap: Iterator.`Protocol` {
    typealias Element = Ownership.Borrow<Out>; typealias Failure = Never
    @_lifetime(&self)
    mutating func next() -> Ownership.Borrow<Out>? {
        guard index < base.count else { return nil }
        slot.pointee = transform(...); index += 1
        return Ownership.Borrow(unsafeAddress: UnsafePointer(slot), borrowing: self)  // tied to self
    }
}
extension BorrowingMap: Iterator.Borrow.`Protocol` { typealias Borrowed = Out }
```

Key: construct via `Ownership.Borrow(unsafeAddress:borrowing: self)` (`@_lifetime(borrow owner)`, matches
the `@_lifetime(&self)` return) — **not** `init(_ pointer:)` (its `@_lifetime(borrow pointer)` ties the
borrow to the local arg, not self → escapes).

**Two load-bearing constraints (bake into the package's canonical impl):**

1. **Exclusivity — read-input-borrow-then-release, *then* lend-output.** When composing over a borrowing
   base (`base.next()` lends a borrow tied to `&self.base`), consuming that input borrow's value into the
   slot must finish (inner scope, borrow dead) *before* `next()` lends the output borrow that re-accesses
   `&self`. Two borrows of `self` can never be simultaneously live (`#ExclusivityViolation` otherwise).
2. **Explicit `~Copyable & ~Escapable` extension suppression.** `extension BorrowingMap: Iterator.Protocol {}`
   silently re-imposes `Base: Copyable & Escapable`; write `extension … where Base: ~Copyable & ~Escapable`
   (per `feedback_extension_implies_copyable`).

**Boundary (characterized, not a blocker):**

| Axis | Result |
|---|---|
| `~Escapable` **base element**, Escapable output (borrowed view in → Copyable summary out) | ✅ works (debug+release) — the realistic World-B Map |
| `~Escapable` **output** (`Borrowed`), **as shipped** (`Ownership.Borrow` + `UnsafeMutablePointer<Out>` slot) | ❌ walls — `UnsafeMutablePointer<Out>` requires `Out: Escapable` (no slot); `Ownership.Borrow.value` is `where Value: Escapable` (no read-back). **But this is the *shape's* limit, not the compiler's** (see below). |
| `~Escapable` **output**, via a **bespoke vending shape** | ✅ **achievable TODAY on 6.3.2** — verified cross-module debug+release (experiment `escapable-output-borrow-lend`, P2a/P4). |

**CORRECTED (v0.7.0, experiment `escapable-output-borrow-lend`):** `Borrowed: Escapable` is **not** a fundamental
constraint — it is specific to the as-shipped `Ownership.Borrow` + `UnsafeMutablePointer<Out>` slot design. Two
shapes lend a `~Escapable` output **today on 6.3.2** (cross-module, debug + release): **(P2a)** store the output as a
plain `~Escapable` stored property and return it under `@_lifetime(&self)`; **(P4)** a bespoke nested `~Escapable
Borrowed` vending struct pointing into an Escapable iterator-owned slot, lifetime-tied to `self`. The W1/W2 walls
fall away because neither uses `UnsafeMutablePointer<Out>` nor `Ownership.Borrow.value`. The *ergonomic stdlib* path
— SE-0519 (which ships as `Ref<Value>`, **not** `Borrow<Value>`; it does **not** carry `Ownership.Borrow`'s
`where Value: Escapable` limit) + SE-0507 `borrow`-accessor read-back — is **production-gated**: live on the dev line
(`main-snapshot-2026-05-12-a`) under `BorrowAndMutateAccessors`/`@available(9999)`, absent on 6.3.2. So: a
`~Escapable`-output Map is buildable now (bespoke-vending) and gets ergonomic stdlib support when SE-0507/0519 reach
a production compiler.

→ **Design conclusion (v0.8.0, decompose-and-compose — confirmed by experiment
`swift-iterator-primitives/Experiments/escapable-element-iterator-conformance`, 6.3.2 debug+release, `sum = 30`):**
the `~Escapable`-output Map is **not** a bespoke type and is **not** an `Ownership.Borrow` improvement — it is a
**plain `Iterator.Protocol` conformer whose `Element` is the `~Escapable` view**. The foundation `Iterator.Protocol`
already declares `associatedtype Element: ~Copyable & ~Escapable` with `@_lifetime(&self) next()`, and its doc states
this is verbatim "to admit `~Escapable` element types (e.g., views into iterator-owned storage)" — so the general
primitive already composes for this. `Ownership.Borrow` / `Iterator.Borrow.Protocol` is the *narrower opt-in sugar*
for the distinct shape "lend a reference to an `Escapable` value stored elsewhere" — forcing the produced-view output
through it (`Element == Ownership.Borrow<Output>`) is the category error that created the false `Borrowed: Escapable`
constraint. Improving `Ownership.Borrow` to carry `~Escapable` read-back is the wrong lever twice over: (a) different
element-shape, (b) impossible on 6.3.2 anyway (it's the raw-pointer→`Builtin.Borrow`/SE-0519 gap). **Rework:** the
borrow package's `Map` for `~Escapable` output conforms to plain `Iterator.Protocol` (`Element` = the view), with
`deinit` teardown (no `finish()`); the `Ownership.Borrow`-lending Map stays for the lend-a-stored-`Escapable`-value
case. Two element-shapes, each on its own clean primitive.

→ **REMOVED (v0.10.0) — `Sequence.Borrow.Viewing` was redundant.** It was briefly added (`79627a0`) and then
removed (`62088d8`) after review. With `Output: Escapable` it was a near-clone of `Sequence.Borrow.Map` — same
slot/transform/deinit — that lent a hand-rolled `Borrowed` view *duplicating* `Ownership.Borrow<Output>`, differing
only in conforming to plain `Iterator.Protocol` vs `Iterator.Borrow.Protocol`: **no capability difference.** It did
**not** deliver `~Escapable` output (its `Output` is `Escapable`); it delivered a `~Escapable` *element*, which `Map`
already does (`Ownership.Borrow<Output>` is itself `~Escapable`). The clean model has exactly two things at the
element level: **`Element`** (the role/slot, any `~Copyable & ~Escapable` type) and **`Ownership.Borrow<T>`** (the one
canonical concrete type that fills it for "a borrow of a stored `T`"). A bespoke per-Map view earns its place only if
it does something `Ownership.Borrow` can't — and for an `Escapable` output it doesn't. The lesson (decompose-and-compose):
"plain `Iterator.Protocol` admits a `~Escapable` element" is true, but it only delivers a NEW capability when the
element is a genuinely `~Escapable` type `Ownership.Borrow` can't represent — i.e. the walled frontier below — not a
view-of-stored-`Escapable`.

→ **The frontier, now pinned precisely (empirical, /tmp probe 6.3.2):** the ONE case that genuinely walls today is a
transform that *reads the borrowing base's input via `Ownership.Borrow.value`* (a `_read` coroutine, `Escapable`-only)
and *re-lends a `~Escapable` view of that input* — exact diagnostic: `error: lifetime-dependent value escapes its
scope … it depends on the lifetime of this parent value` (at the input view). The `_read`-yielded borrow can't escape
its statement. So it is NOT "~Escapable output is impossible" (Viewing ships it) — it is specifically "a view *of a
`_read`-yielded base input* can't be re-lent," gated on the SE-0507/0519 ergonomic stdlib path reaching a production
compiler. `Viewing` sidesteps it by viewing iterator-owned storage rather than the transient input. (Separately
confirmed: a stored `@escaping (borrowing In) -> ~EscapableOut` closure compiles — the original §15 wall was the
closure-*plus-`UnsafeMutablePointer<Out>`-slot* combination, not the closure type.)

**Open follow-up:** slot lifecycle is a `consuming func finish()` today; whether a `~Escapable` struct can
carry a `deinit` cleanly for automatic cleanup is a Stage-B design decision.

### Implemented (2026-05-26) — `swift-sequence-borrow-primitives` @ `9129926`, green debug+release

Built §4a + §15 (local, unpushed; `Sequence.Borrow` namespace — rename deferred per §10). As-built refinements
to this section:

- **Init lifetime is `@_lifetime(copy _base)`, not `@_lifetime(immortal)`.** The §15 spike's base was a plain
  `[Int]` array (immortal-able); the real Map is built over a *borrowing* base (`Iterator.Borrow.Protocol`,
  `~Escapable`), so `self` cannot be immortal while holding it — it derives its lifetime from `_base`. (Building
  over a borrowing base is also what actually exercises constraints #2 exclusivity and #3 suppression; an array
  base has neither.)
- **`Failure = Either<Transform, Base.Failure>`** (per the principal's Either-not-Never direction): `.left` =
  transform error, `.right` = base-iteration error, mirroring `Iterable.forEach`'s fallible overload. Both channels
  default to `Never` for infallible uses.
- **The `finish()` footgun is CONFIRMED**, and it's a resource *leak* (not use-after-free — the `@_lifetime(&self)`
  + exclusivity keep the lent borrows sound). Resolution (the `~Escapable`-`deinit` or scoped-`with` API) is the
  must-settle item before this package ships; analogous to the executor-shutdown footgun.
- **Pre-push convention fix:** the package currently uses relative-path deps (`.package(path:)`); switch to the
  ecosystem `.package(url:)` + mirror form (and add mirror entries) before any push.

## References

- `two-world-traversal-decomposition.md` (v1.2.1) — the element-type collapse this extends
- `2026-04-20-associated-type-trap.md` (Blog) — same-named associated types unify; `@_implements` escape hatch (§11 D-1)
- `collection-sequence-protocol-detachment.md` (v1.1.0, DECISION) — Sequence/Collection orthogonality; `Sequence.Borrowing` reframe (Step C)
- `swift-iterator-primitives` — `Iterator.Protocol.swift:29`, `Iterable.swift:16-18` (the baked-in forward references)
- `swift-iterator-borrow-primitives` — `Iterator.Borrow.Protocol.swift` (the sugar-refinement precedent for §4a)
- Current source read 2026-05-25: `Sequence.Protocol.swift`, `Sequence.Iterator.Protocol.swift`, `Sequence.Borrowing.Protocol.swift`, `Sequence.Map.Eager.Iterator.swift`, `Sequence.Drop.While.Iterator.swift`, `Sequence.Protocol+Map.swift`, `Sequence.Protocol+ForEach.swift`
