# Iterable Span-Primitive Realignment — Implementation Plan

<!--
---
version: 1.0.0
last_updated: 2026-05-30
status: RECOMMENDATION
tier: 2
scope: cross-package
builds_on:
  - "iterable-se0516-alignment.md (Tier 2, RECOMMENDATION, principal-ratified 2026-05-30) — the WHAT/WHY: SE-0516 ↔ institute mapping + delta D1–D8 (§7.1) + Iterator.Borrow disposition. THIS doc is the HOW; it EXTENDS that doc per [HANDOFF-013], does not duplicate it."
  - "unified-iteration-design.md (Tier 2, APPROVED v2.2.0) — the single design authority; §2.1/§2.3/§2.5/§3/§6.3 the span-primitive target."
  - "HANDOFF-data-structure-iteration-arc.md — the arc's execution doc; §0 dispatch + acceptance, §3.4 the D1→D6 step order, §8 binding disciplines, §10 build/mirror notes."
  - "bulk-span-iteration-fold-vs-separate.md (Tier 3) — the Span<~Copyable> crux + SE-0516's rejection of element-wrapping."
changelog:
  - "1.0.0 (2026-05-30): Initial. Verify-plan subordinate output (Pattern B, [SUPER-023]). (1) Re-verification of the span-primitive realignment from disk + the stdlib clone; (2) ground-state assessment (4 packages, no drift); (3) the implementation plan for the in-scope 3-package reference rework + the workspace-wide `: Iterable` blast-radius enumeration. Surfaces the Ground-Rule-6(a)/6(c) escalation: D2 breaks 21 conformers across 9 packages outside the authorized scope."
---
-->

> **Verify-plan subordinate output — NOT an execution authorization.** This is the output of the verify-plan
> dispatch (`HANDOFF-iterable-span-primitive-verify-plan.md`) under Pattern B supervision ([SUPER-023]). It
> (1) re-verifies the span-primitive realignment from primary source, (2) assesses ground-state, and (3)
> produces the implementation plan. Implementation is a **separate, per-action-gated** dispatch after the
> supervisor reviews this. The **WHAT/WHY** lives in `iterable-se0516-alignment.md` (the delta D1–D8) and
> `unified-iteration-design.md` v2.2.0 (the design authority); this doc is the **HOW** and EXTENDS them
> ([HANDOFF-013]). **⚑ Read `## Open Scope Question` first — the D2 re-point has a workspace-wide blast radius
> that requires a supervisor scope decision before D2 can land (Ground Rule 6(a)/6(c) fired).**

## Context

The institute `Iterable` is being re-aligned to SE-0516's **span-primitive** shape (user-ratified 2026-05-30):
its iterator becomes the span protocol (`__IteratorChunkProtocol`, element bound relaxed `Escapable → ~Copyable`,
scalar-protocol refinement dropped), so **one span iterator** (`Iterator.Chunk` over `span`) serves both
element kinds, and the memory→Iterable bridge relaxed `Copyable → ~Copyable` gives `Set.Ordered` + buffers
their `Iterable` (~Copyable) conformance for free. Design docs are updated; **no code has changed yet.** This
plan is the verify-plan agent's three deliverables. The delta to execute is D1–D8 (`iterable-se0516-alignment.md`
§7.1).

---

## Verification

Per Supervisor Ground Rule 2 ([SUPER-002]/[SUPER-009]/[HANDOFF-047]): every load-bearing claim independently
re-confirmed from **primary source** (disk `file:line` + the local `swiftlang/swift` clone), NOT from the docs'
prose. The supervisor already verified these; this is independent confirmation.

### V0 — Ground-state (re-derived from `git`, [HANDOFF-029] pre-fire re-check)

All four packages sit **exactly at the handoff baselines** with **clean working trees** — **NO DRIFT** since
handoff-write (the user co-commits in parallel; re-checked).

| Package | Baseline | Live HEAD | Match | Unpushed | Tree |
|---|---|---|---|---|---|
| `swift-iterator-primitives` | b7277fb | `b7277fb` | ✓ | 0 (no upstream configured) | clean |
| `swift-memory-iterator-primitives` | 1c6d694 | `1c6d694` | ✓ | 2 | clean |
| `swift-set-ordered-primitives` | 6af55a2 | `6af55a2` | ✓ | 8 | clean |
| `swift-iterator-borrow-primitives` | dd60699 | `dd60699` | ✓ | 2 | clean |

**Doc-state (premise check, [HANDOFF-016]):** `unified-iteration-design.md` is at **v2.2.0 / APPROVED /
2026-05-30** with the span-primitive banner (verified head + changelog); `iterable-se0516-alignment.md` is
v1.0.0 RECOMMENDATION. The handoff premise — *"design docs updated, no code changed"* — **holds**: disk still
shows the scalar-primitive shape (see V1) while both design docs describe the span-primitive target.

### V1–V5 — The five load-bearing claims (primary source)

| # | Claim | Evidence (`file:line`) | Verdict |
|---|---|---|---|
| **V1** | `Iterable` is **scalar-primitive** today | `Iterable.swift:45` (`associatedtype Iterator: …Iterator.\`Protocol\`, ~Copyable, ~Escapable`) + `Iterator.Protocol.swift:46` (`mutating func next() throws(Failure) -> Element?`, the move-out; `Element: ~Copyable & ~Escapable` `:33`) + `Iterable+ForEach.swift:41-44` (the floor drives the scalar `next()`) | **VERIFIED** |
| **V2** | `__IteratorChunkProtocol` carries `where Element: Escapable` **AND** refines `Iterator.\`Protocol\`` | `__IteratorChunkProtocol.swift:34` (`: Iterator.\`Protocol\`, ~Copyable, ~Escapable` — the refinement) + `:35` (`where Element: Escapable` — the over-narrow bound); doc rationale `:26-30` ("`Span<Element>` requires escapable elements") | **VERIFIED (both)** |
| **V3** | `Iterator.Chunk` *struct* is **bound-free + span-storing** | `Iterator.Chunk.swift:26` (`struct Chunk<Element>: ~Copyable, ~Escapable` — no `Escapable` bound) + `:27` (`let span: Swift.Span<Element>`); only its *conformance* `:45` inherits the protocol's bound | **VERIFIED** |
| **V4** | `Span<~Copyable>` exists + subscript is a **borrowing addressor** (no move-out) | `Span/Span.swift:29` (`public struct Span<Element: ~Copyable>: ~Escapable, Copyable, BitwiseCopyable`) + `:455-461` (`subscript(_:) -> Element { unsafeAddress { … } }` — borrow, never moves out) | **VERIFIED** |
| **V5** | `Span.Protocol`'s `span` is `~Copyable`-capable | `Span.Protocol.swift` (`protocol Protocol: ~Copyable { associatedtype Element: ~Copyable; var span: Span<Element> { get } }`) + `Set.Ordered+Iteration.swift:27-34` (span witness `where Element: ~Copyable`) | **VERIFIED** |

### V6 — Independent confirmation from the `swiftlang/swift` clone (`/Users/coen/Developer/swiftlang/swift`)

`BorrowingSequence.swift` is 8164 bytes (matches the alignment doc's cited size). Confirmed:

- `BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable` with **`associatedtype Element: ~Copyable`**
  (`:15-16`) — NOT `Escapable`-narrowed; the shipped-clone bound the institute should align to.
- `mutating func nextSpan(maximumCount: Int) -> Span<Element>` (`:56-58`) is the **sole** element-access
  primitive — **no scalar `next()`**; plus `skip(by:)` (`:60-71`, with a default impl `:86-96`).
- `SpanIterator<Element>: BorrowingIteratorProtocol … where Element: ~Copyable` (`:100-101`) — structurally ≅
  `Iterator.Chunk`. Its `nextSpan` (`:121-128`) uses `_span.extracting(droppingFirst:).extracting(first:)` on
  a `Span<~Copyable>` — **byte-identical pattern to `Iterator.Chunk.next` (`Iterator.Chunk.swift:57`)**, which
  **corroborates D1's risk note that `extracting` is `~Copyable`-safe** (the stdlib uses it on `Span<~Copyable>`).
- `BorrowingSequence<Element>` container (`:145-155`) ≅ `Iterable` (post-D2); `BorrowingIteratorAdapter` +
  `@_disfavoredOverload makeBorrowingIterator()` (`:198-228`) is the **D8 `Sequence`→`Iterable` adapter analog**
  (materializes one-element spans via `Optional._span()`).

The clone is **infallible** (no `throws(Failure)`) and uses bare `Int` for `maximumCount`; the institute is
**ahead** on typed throws (`Failure`) and richer on the count param (`some Carrier.\`Protocol\`<Cardinal>`) —
both justified divergences per `iterable-se0516-alignment.md` §7.3.

### V7 — Delta D1–D8 applicability + one precision note for the implementer

D1–D8 (`iterable-se0516-alignment.md` §7.1) **still apply to current disk** (no drift; the scalar-primitive
shape verified in V1–V3 is exactly what the delta targets). **No claim refuted → Ground Rule 6(a) does not fire
on verification grounds.**

**Precision note (D1 is a 4-part change, not 2):** §7.1's D1 row reads tersely — *"relax the bound `Escapable
→ ~Copyable`; add `skip(by:)`."* The full D1, as captured by the **design authority** (`unified-iteration-design.md`
v2.2.0 changelog + §2.3 + the §3.2 aligned-protocol code, and arc §0/§3.2/Objective), additionally requires:
1. **Drop the `: Iterator.\`Protocol\`` refinement** (`__IteratorChunkProtocol.swift:34`) — load-bearing:
   otherwise a `~Copyable` `Iterator.Chunk` still owes the scalar move-out `next() -> Element?`, re-introducing
   the very wall the realignment removes.
2. **Add explicit `associatedtype Element: ~Copyable` + `associatedtype Failure: Swift.Error = Never`** —
   currently `__IteratorChunkProtocol` inherits both from the refined `Iterator.\`Protocol\``; once the
   refinement is dropped, the `<Element, Failure>` primary associated types must be declared locally (mirrors
   stdlib `BorrowingIteratorProtocol:16`).

The realignment is therefore **fully specified across the doc set**; only §7.1's one-line D1 row is terse. The
implementer should treat D1 as the 4-part change above (no escalation needed — the design authority is
unambiguous).

---

## `: Iterable` Blast-Radius Enumeration (Ground Rule 4 — workspace-wide, [HANDOFF-050]/[HANDOFF-040])

Enumerated workspace-wide across all org-mirror dirs (literal `: Iterable`, generic-instantiated, AND
conformance-position incl. attribute-prefixed forms). **[HANDOFF-040]/[HANDOFF-031] lesson:** the literal
`(:|,) *Iterable\b` regex **silently missed** the `@unsafe Iterable` / `@retroactive Iterable` attribute-prefixed
conformances (Buffer.Ring/Slab/Linked inline variants, Single, Cyclic.Group.Static, Storage.Contiguous). An
attribute-aware grep (`extension .*:.*\bIterable\b`) was required for completeness. No conformers exist outside
`swift-primitives` (standards/foundations/legal/coenttb dirs returned none); no generic-instantiated `Iterable<…>`
forms (the institute `Iterable` is unparameterized).

**Verification mechanism (re-runnable, [HANDOFF-021]):**
```bash
cd /Users/coen/Developer
grep -rnE "extension .*:.*\bIterable\b" --include="*.swift" swift-primitives swift-standards \
  swift-foundations swift-institute 2>/dev/null | grep -v "/.build/" | grep -v "CaseIterable"
```

### Classification — 34 production conformers

**A. BRIDGE-VENDED (13) — migrate FREE via D4; D2-safe.** `Iterable.Iterator` is already `Iterator.Chunk`
(the span iterator), vended by the memory→Iterable bridge over `span`. `Iterator.Chunk: __IteratorChunkProtocol`,
so the binding still satisfies `Iterable.Iterator: __IteratorChunkProtocol` after D2; D4 additionally enables
`~Copyable` (each conformer opts in by relaxing its own `where Element: Copyable`). **No source change to keep
building.**

| Package | Conformers | n | Evidence |
|---|---|---|---|
| `swift-set-ordered-primitives` | `Set.Ordered`, `.Fixed`, `.Small`, `.Static` | 4 | the **D5 exemplar**; `Set.Ordered.Iterator.swift:46` etc. via bridge over `span` |
| `swift-buffer-linear-primitives` | `Buffer.Linear`, `.Inline`, `.Small`, `.Bounded` | 4 | `Buffer.Linear+Sequence.Protocol.swift:30-32` `@_implements typealias IterableIterator = Iterator.Chunk<Element>` |
| `swift-array-primitives` | `Array`, `.Static`, `.Small`, `.Fixed` | 4 | `Array.Conformances.swift:64` (`: Span.\`Protocol\`` + `Iterator.Chunk` "vended FOR FREE by the bridge") |
| `swift-memory-iterator-primitives` | `Storage.Contiguous` | 1 | `Span.Protocol+Iterable.swift` (the contiguous ⇄ iteration bridge; per-conformer `@retroactive` opt-in) |

**B. HAND-ROLLED SCALAR (18) — BREAK under D2; need migration. FLAGGED per Ground Rule 4.** `Iterable.Iterator`
is a scalar `Iterator.\`Protocol\`` conformer (`next() -> Element?`); after D2 re-points `Iterable.Iterator` to
`__IteratorChunkProtocol`, the scalar `makeIterator()` no longer satisfies the constraint → compile failure.

| Package | Conformers | n | Iterator / why it can't ride the bridge |
|---|---|---|---|
| `swift-bit-vector-primitives` | `Bit.Vector.{Ones,Zeros}.{Inline,Bounded,Static}` + `.{Ones,Zeros}.View` | 8 | synthesized bit-walker (`Element = Bit.Index`); bits **computed, not stored** as `Bit.Index` → no `Span<Bit.Index>` |
| `swift-vector-primitives` | `Vector`, `Vector.Reversed` | 2 | "SCALAR generator … no contiguous span backing" (`Vector+Iterable.swift:18-21`) |
| `swift-buffer-ring-primitives` | `Buffer.Ring.Inline` | 1 | scalar `Walk`; "NOT a bulk iterator … does not synthesize `Swift.Span`" (`:46-47`) — dodges the `@_rawLayout` span demangle-crash |
| `swift-buffer-slab-primitives` | `Buffer.Slab.Inline` | 1 | pointer + **sparse bitmap** scalar iterator (`:42`); occupancy is sparse → no dense span |
| `swift-buffer-linked-primitives` | `Buffer.Linked`, `Buffer.Linked.Inline` | 2 | link-chain scalar cursor; "SCALAR generator with no contiguous span backing" (`Buffer.Linked+Iterable.swift:12-15`) |
| `swift-single-iterator-primitives` | `Single` | 1 | `Iterator.Once<Element>` (one-element scalar; `Single+Iterable.swift:20`) |
| `swift-input-primitives` | `Input.Slice` | 1 | scalar Collection-index walker (`Input.Slice.Iterator.next()`); `Base` may be non-contiguous |
| `swift-hash-table-primitives` | `Hash.Occupied.Static` | 1 | scalar `Hash.Occupied.Static.Iterator` yielding computed `Hash.Occupied<Source>` wrappers |
| `swift-cyclic-iterator-primitives` | `Cyclic.Group.Static` | 1 | scalar `Iterator` (`: Iterator.\`Protocol\``, `next() -> Element?`); `@retroactive Iterable` (`+Sequence.Protocol.swift:19`) |

**C. PIECEWISE / NEEDS-PER-FILE-VERIFICATION (3) — BREAK under D2; need migration.**

| Package | Conformers | n | Status |
|---|---|---|---|
| `swift-buffer-ring-primitives` | `Buffer.Ring` (base) | 1 | `Buffer.Ring.Segments` — owns ≤2 `Iterator.Chunk`, drains via `Iterator.Chunk.next(maximumCount:)`. Already **bulk-shaped**; needs `Segments` to conform to `__IteratorChunkProtocol` (yield sub-spans across both segments). Moderate migration; machinery exists. |
| `swift-buffer-ring-primitives` | `Buffer.Ring.Small`, `.Bounded` | 2 | `@unsafe Iterable` in `+Span.swift`; not directly read — **likely** scalar `Walk` (like `.Inline`) OR piecewise (like base). Re-verify at execution; **breaks under D2 either way.** |

**Net:** **13 migrate free** (the dense-contiguous `Span.Protocol` family); **21 break under D2** (18
hand-rolled scalar + 3 ring) across **9 packages outside the authorized 3-package reference scope**
(bit-vector, vector, buffer-ring, buffer-slab, buffer-linked, single, input, hash-table, cyclic). This is the
basis for the escalation below.

*(Out of scope: test fixtures `Set.Fixture`, `IntSource` ×3 in iterator-primitives' own tests, `FixtureBorrowed`,
`TokenBuffer`, and the `Experiments/` conformers (`ToySet`, `RegionDual`, `RawRegion`, `EBuffer.Linear.Inline`).
Note the in-package iterator-primitives test fixtures `IntSource`/`FailingSource` are scalar and must migrate
**within** the iterator-primitives commits — see Plan step 3.)*

---

## Implementation Plan

**Scope: the AUTHORIZED 3-package reference rework only** (iterator-primitives + memory-iterator + set-ordered),
per arc §3/§5 + Ground Rule 1. The cross-package cascade for cohorts **B + C** is **PENDING the supervisor scope
decision** (`## Open Scope Question`). Step order follows arc §3.4, made concrete with per-package commits, gates,
and acceptance mapping. Binding disciplines (arc §8): verify from disk/git/SIL never attestation; compose over
refinement; never cave (walls escalate, don't retreat); 0-`witness_method` on hot ops; pre-1.0 = delete not
deprecate; **git work-forward, stage explicit paths, never `git add -A`**; commit at stable points.

### Package 1 — `swift-iterator-primitives` (D1, D2, D3)

- **Commit 1 — D1** (`Iterator Chunk Primitives/__IteratorChunkProtocol.swift`): the 4-part change (V7):
  (i) drop `: Iterator.\`Protocol\`` refinement (`:34`); (ii) relax `where Element: Escapable → ~Copyable`
  (`:35`); (iii) add `associatedtype Element: ~Copyable` + `associatedtype Failure: Swift.Error = Never`;
  (iv) add the `skip(by:)` requirement (model the default impl on stdlib `BorrowingSequence.swift:86-96`).
  Reconcile the doc-comment rationale (`:26-30`) that conflates `~Copyable` with `~Escapable`.
  **Gate:** package builds; `Iterator.Chunk` still conforms (`Iterator.Chunk.swift:45`) — its `extracting`-based
  `next(maximumCount:)` is `~Copyable`-safe (V6 corroboration). `skip(by:)` may need an `Iterator.Chunk` impl.
- **Commit 2 — D2** (`Iterable/Iterable.swift:45`): re-point `associatedtype Iterator:
  Iterator_Primitive.Iterator.\`Protocol\`` → `__IteratorChunkProtocol` (keep `~Copyable, ~Escapable`).
  **⚠ This is the highest-blast-radius line in the workspace — see the escalation.** Within this package it
  also breaks the **scalar test fixtures** (`Tests/Iterable Tests/`: `IntSource` in `Iterable.ForEach Tests.swift:5`
  + `Iterable.Terminals Tests.swift:5`; `FailingSource` in `Iterable.ForEach.Fallible Tests.swift:21`).
- **Commit 3 — D3** (`Iterable/Iterable+ForEach.swift`): rebuild `forEach` (infallible) + the fallible `Either`
  overload on the **span loop** (`var it = makeIterator(); while true { let span = it.next(maximumCount:
  Cardinal(UInt.max)); if span.isEmpty { break }; for i in span.indices { try body(span[i]) } }`). Verify
  `Iterable+First/Contains/Reduce` compose from `forEach`/the span loop (not the scalar `next()`); the
  *extraction* gate `Iterator.Element: Copyable & Escapable` on `first`/`reduce` (`Iterable+First.swift:10-11`)
  is intrinsic to extracting-past-the-borrow and **stays unchanged**. Migrate the in-package test fixtures
  (commit 2) to vend `Iterator.Chunk` (span).
  **Gate:** `swift test` green (debug) on `swift-iterator-primitives`; fixtures iterate both element kinds.

### Package 2 — `swift-memory-iterator-primitives` (D4)

- **Commit 4 — D4** (`Memory Iterator Primitives/Span.Protocol+Iterable.swift`): relax the **owned bridge**
  (`:28`, `where … Element: Copyable → ~Copyable`) and the **borrowed bridge** (`:74-75`, same); **delete the
  bespoke span-lending `forEach` floor** (`:55-67`) now subsumed by the general span-loop `forEach` (D3).
  Verify no overload ambiguity between the general `Iterable.forEach` and any residual (the `:48-54` comment
  documents the prior intra-`Iterable`-vs-cross-protocol ambiguity wall — confirm the general floor resolves
  for `Span.Protocol` conformers). Migrate the in-package fixture (`FixtureBorrowed`, `Span.Protocol
  Iterable Tests.swift:27`) if affected.
  **Gate (mirror discipline, arc §10.1):** commit Package 1 locally **and purge**
  `~/Library/Caches/org.swift.swiftpm/repositories` before this package resolves the change; then
  `rm -rf .build Package.resolved && swift package update && swift test` (debug).

### Package 3 — `swift-set-ordered-primitives` (D5, D6-park)

- **★ BUILD-VERIFY GATE (Ground Rule 2 / arc §3.4 step 5) — MUST pass BEFORE D5 completes.** Named explicitly:
  **`Iterator.Chunk(span)` over inline `@_rawLayout` storage (the `.Inline` / `.Small` / `.Static` variants)
  iterating a `~Copyable` element, in DEBUG AND RELEASE.** The span path borrows through the safe `span` view
  (`@_lifetime(borrow self)` → `Iterator.Chunk` `@_lifetime(copy span)`) — strictly *weaker* than the v2.1.x
  escaping-base gate that already passed — so it *should* be ≥ as sound, but it is a gate, not a settled claim
  ([RES-021]/[RES-027]). **Soundness assessment on inspection: PLAUSIBLE — no unsoundness found** (the lifetime
  chain ties the iterator to the container borrow; `span[i]` is the stdlib `unsafeAddress` addressor; the
  identical pattern is what stdlib `SpanIterator<~Copyable>` runs). Therefore Ground Rule 6(b) does **not** fire.
  **If it walls at execution → escalate (architecture-shape call), do NOT retreat to a Copyable gate** (arc §8 no-cave).
- **Commit 5 — D5** (`Set Ordered {,Fixed,Small,Static} Primitives/Set.Ordered*.Iterator.swift`): collapse to
  **ONE** `Iterable` conformance vended by the relaxed bridge over `span`; relax each `extension … : Iterable
  where Element: Copyable` → `~Copyable`; the dual-element-kind split dissolves (the `@_implements` split vs
  `Sequenceable`'s consuming scalar iterator persists — arc §3.2). **Delete the per-type hand-written `~Copyable`
  `forEach` (×4 on `Set.Ordered ~Copyable.swift`) ONLY AFTER the ~Copyable `Iterable` conformance is green**
  (Ground Rule 3 / arc §3.3 — premature deletion regresses `~Copyable` `forEach`).
- **D6 — park:** **NO edit** to `swift-iterator-borrow-primitives` (`f31ce11`/`dd60699` stay on disk;
  [ARCH-LAYER-009]). Confirm intact via `git -C swift-iterator-borrow-primitives status` (must stay `dd60699`,
  clean). Ground Rule 5 forbids revert/delete.
- **Gates:** build-verify gate passed (above); `swift test` green **debug AND release** (set-ordered is
  release-clean via field-reorder); **SIL re-prove 0-`witness_method`** on the hot path (cross-module `-O`
  probe, recipe `/tmp/set-decouple-sil/SIL-RECEIPT.md`, arc §10.5); test counts not regressed.

### Acceptance criteria (arc §0 acceptance 1–7 — each verified from disk/git/SIL/build, [SUPER-009])

| # | Criterion | Verification source |
|---|---|---|
| 1 | `__IteratorChunkProtocol` bound is `~Copyable`, **not** refining `Iterator.\`Protocol\``; `Iterable.Iterator` re-pointed; `Iterator.Chunk` still conforms | disk Read + grep; build |
| 2 | `Iterable.forEach` (+ fallible) driven by the span loop; bespoke span-lending floor subsumed/deleted; both element kinds, no Copyable gate | disk Read `Iterable+ForEach.swift` + `Span.Protocol+Iterable.swift` |
| 3 | bridge is `~Copyable` (not Copyable-gated); `Set.Ordered: Iterable` is ONE conformance; per-type `forEach` deleted; `x.forEach { }` resolves for both kinds | disk grep + `/tmp` consumer over a `~Copyable`-element set |
| 4 | **build-verify gate** passes (`Iterator.Chunk(span)` over inline `@_rawLayout`, `~Copyable`, debug AND release) | build/test — supervisor runs |
| 5 | 0-`witness_method` on the hot path | SIL grep (cross-module `-O`) |
| 6 | `swift test` green (debug) on the 3 packages; counts not regressed | build/test — supervisor runs |
| 7 | NO `Iterator.Borrow.Scalar` in the iteration path; iterator-borrow **intact** (parked); NO `Buffer.Linear: Storage.Protocol`, NO per-variant `makeIterator`, NO new bridge package, NO public base, NO fan-out, NO push | `git diff --stat` scoped + `git -C swift-iterator-borrow-primitives status` |

### Mirror / build operational notes (arc §10 — load-bearing)

1. Dep form is **url + mirror + `branch:"main"`**, serving each dep's **committed `main` HEAD** (not the working
   tree). After editing a dependency you MUST **commit it AND purge**
   `~/Library/Caches/org.swift.swiftpm/repositories` before a dependent resolves. **⇒ Committing D2 to
   iterator-primitives' `main` propagates the breaking change to every downstream consumer on next resolve —
   this is why the cross-package scope (below) must be settled before D2 is committed.**
2. Stale `Package.resolved` pins → `swift package update` (the `cardinal-primitives` /
   `Span.extracting(first: Cardinal)` build-blocker class). `Package.resolved` is gitignored — do not commit it.
3. Clean gate per package: `rm -rf .build Package.resolved && swift package update && swift test`. Linker
   "undefined symbols" after a symbol move = stale `.build` → `rm -rf .build` before concluding.

---

## Open Scope Question — Escalation (Ground Rule 6(a) / 6(c); [SUPER-012]/[SUPER-042])

> **✅ RESOLVED — supervisor-ratified 2026-05-30 (relayed).** Decision: **Option C, then Option A — gate-first.**
> The 3-package reference rework is validated in isolation **without committing the breaking D1/D2 to
> `swift-iterator-primitives`' shared `main`** (local branch + path-dep override, or a scratch workspace — the
> 21 downstream conformers MUST NOT break on the mirror). The 21-conformer cascade **IS** the gated ×16 fan-out
> (Option A: D2-commit + migration) and **stays gated** — it requires a separate explicit YES after the
> reference is supervisor-verified. **Option B (transition adapter) is REJECTED** — a transition adapter is a
> deprecation-shim (against pre-1.0=delete / structural-fixes-over-shims) and is likely infeasible given the
> single `associatedtype Iterator` + the `@_disfavoredOverload` name already consumed by the
> `Iterable`/`Sequenceable` split; **do not spike B.** The implementing dispatch is scoped to Option C only,
> with a **Step-0 fail-fast build-verify-gate spike** (`Iterator.Chunk(span)` over real `@_rawLayout` inline
> storage iterating a `~Copyable` element, debug+release) — if it walls, escalate immediately (deeper
> inline-storage problem), do not proceed. `Iterator.Borrow` stays parked (no edit). The Options A/B/C analysis
> below is retained as the decision record.

**The escalation trigger fired.** The arc dispatch Ground Rule 6(a) and this dispatch's Ground Rule 6(c) both
require escalation BEFORE finalizing the plan if the blast-radius enumeration surfaces hand-rolled **scalar**
`Iterable` conformers outside the `Span.Protocol` family. **It surfaced 21** (cohorts B + C) across **9
packages**.

**The structural problem.** D2 lands in `swift-iterator-primitives` (a foundational dependency) and changes
the `Iterable.Iterator` associated-type constraint from the scalar protocol to the span protocol. The 3-package
reference rework **can build/test green in isolation** (none of the 3 has a hand-rolled scalar `Iterable`
conformer). **But** the workspace dep model serves each package's committed `main` HEAD via the mirror (arc
§10.1), so **the moment D2 is committed, the 21 downstream conformers fail to compile** on next resolve — the
ecosystem-wide build gate ([HANDOFF-035]) cannot be green. This is a workspace-wide protocol API change, not a
set-ordered-local one.

**Why most of cohort B cannot simply "migrate to a span iterator":**
- **Generators** (bit-vector ×8, Vector ×2, Single, Input.Slice, Hash.Occupied.Static, Cyclic) compute/sparse-
  yield elements that are **not contiguously stored as `Element`** — there is no `Span<Element>` to project.
- **Inline `@_rawLayout` buffer variants** (Buffer.Linked.Inline, Buffer.Slab.Inline, Buffer.Ring.Inline)
  **deliberately** use hand-written scalar iterators to **dodge the `@_rawLayout` span demangle-crash** — the
  exact failure mode the build-verify gate exists to check.

So the migration is non-trivial. **The supervisor's scope/sequencing call:**

- **Option A — D2 is one atomic workspace cascade.** Land D1–D6 *and* migrate all 21 downstream conformers in
  the same commit wave ([HANDOFF-035] termination: workspace-wide grep + ecosystem `swift build` gate). Each
  cohort-B generator gets an SE-0516-style **materialize-into-temp-span adapter** (D8; Copyable-only — all 21
  are `where Element/Bound: Copyable`); each ring/piecewise gets a multi-span `__IteratorChunkProtocol` conformer.
  Largest scope; keeps every package building. *(This contradicts the arc's "reference rework first, fan-out
  gated" staging — it folds the fan-out into the reference landing.)*
- **Option B — transition adapter so D2 is non-breaking.** Provide a default `makeIterator` (the D8 adapter) on
  a constrained extension so existing scalar conformers keep compiling without per-type edits, then migrate them
  incrementally. *Feasibility caveat:* `Iterable` has a single `associatedtype Iterator`; a clean default that
  doesn't force every conformer to re-bind is non-obvious (unlike SE-0516's distinct `makeBorrowingIterator`
  name + `@_disfavoredOverload`). Needs a spike before it can be relied on.
- **Option C — reference rework validates in isolation; D2 is NOT committed to `main` yet.** Land D1/D3/D4/D5
  and validate the span shape on the 3 packages on a branch / uncommitted, but **defer committing D2 to
  iterator-primitives `main`** until the downstream cascade (Option A's migrations) is planned and dispatched as
  the (currently gated) fan-out. The reference is *proven* without breaking the workspace; D2 + the cascade land
  together later. *(Closest to the arc's stated staging; needs a way to validate D2's shape without committing it
  to the shared mirror — e.g. a path-dep or local-only branch for the 3 packages.)*

**My recommendation (subordinate, non-binding):** **Option C** for the immediate reference rework — it honors
the arc's "reference first, fan-out gated" staging (§4/§5) and the "no broken `main`" discipline, validates the
span shape end-to-end on the 3 packages, and keeps the 21-conformer migration as the explicit first step of the
(gated) ×16 fan-out. Then dispatch the cascade as **Option A** (one atomic wave, [HANDOFF-035] gates) once the
reference is supervisor-verified. **The decision is the supervisor's** — it changes whether D2 is committed now
(and thus whether the immediate dispatch is 3 packages or ~12), and whether cohort-B generators get a D8 adapter
vs. drop `: Iterable` for `Sequenceable`-only. I have **not** finalized the cross-package scope; the 3-package
plan above stands regardless of the choice.

---

## Option C — Execution Outcome & Premise Correction (2026-05-30)

**Option C COMPLETE, green in isolation** (implementing dispatch; independently spot-checked from disk/git/SIL).
Step-0 gate + all 7 acceptance criteria PASS; D1–D4 applied in a scratch workspace (`_scratch-iterable-span-c/`);
the 4 real packages remain clean at baselines (`b7277fb`/`1c6d694`/`6af55a2`/`dd60699`, `main`) — **D1/D2 NOT on
shared `main`, nothing pushed, `Iterator.Borrow` parked-untouched.** SIL hot path **0-`witness_method`** (residuals
off-path: `Int.description`/print + generic witness thunks). The span-primitive shape is proven via the **Step-0
`@_rawLayout` spike + a synthetic `Storage.Contiguous` `~Copyable` consumer** (the accepted isolated proof per the
D5 adjudication).

**Premise correction ([HANDOFF-016]).** This doc's earlier claim — *"the 3-package reference rework can build/test
green in isolation"* — is corrected: it holds for **iterator-primitives + memory-iterator**, but **NOT set-ordered.**
`Set.Ordered.{Static,Small}`'s *transitive dependency closure* contains cohort-B scalar `: Iterable` conformers
(`Set.Ordered.Static` → `Hash Table Static Primitives` [`set-ordered Package.swift:99`] → scalar
`Hash.Occupied.Static: Iterable`; + `Bit Vector Static Primitives` transitively). Under SwiftPM single-package-identity,
a D2 path-override recompiles that closure against the re-pointed `Iterable.Iterator`, breaking those conformers →
`Set.Ordered.Static/.Small` (the build-verify gate's required variants) **cannot compile in isolation.** The real
`Set.Ordered` exemplar is therefore **inseparable from the Option-A cascade** — relocated from C to A. The soundness
proof is unaffected: Step-0 already validated `Iterator.Chunk(span)` over real `@_rawLayout` inline storage.

**Option A blast-radius sizing refinement.** The cascade MUST include **`swift-hash-table-primitives` (static)** and
**`swift-bit-vector-primitives` (static)** as *transitive-dep breakers that gate `Set.Ordered.Static/.Small`* — not
merely as standalone cohort-B conformers. They must migrate before/with the real `Set.Ordered` exemplar in Option A's
first wave.

**Two D-step refinements (from execution; fold into the Option-A dispatch):**
- **D4 mechanism:** "relax `Copyable → ~Copyable`" is realized by **removing the positive `Element: Copyable`
  narrowing** on the bridge extensions, NOT by writing `where Element: ~Copyable` (the compiler rejects re-suppressing
  Copyable on an already-`~Copyable` outer-scope associated type — `Span.Protocol.Element` is already
  `~Copyable`).
- **D3 scope:** D2 breaks **every** terminal that drove the scalar `next()` — `first`/`contains`/`reduce` migrate to
  the span loop too, not just `forEach` (+ fallible). The extraction gate (`Element: Copyable & Escapable`) on `first`
  stays intact (correctly unavailable for `~Copyable` elements).

---

## Outcome

**Status: RECOMMENDATION.** The span-primitive realignment is **re-verified from primary source** — all five
load-bearing claims VERIFIED (V1–V5), independently corroborated against the `swiftlang/swift` clone (V6); **no
claim refuted.** Ground-state has **no drift** (V0). The delta D1–D8 applies to current disk, with one
implementer precision note (D1 is a 4-part change — V7). The **3-package reference-rework implementation plan**
(D1–D6, per-package commits, the named build-verify gate, SIL gate, acceptance mapping) is ready. The **`:
Iterable` blast-radius enumeration** is complete: 13 conformers migrate free, **21 break under D2 across 9
out-of-scope packages** — which **fires the Ground Rule 6(a)/6(c) escalation**. The cross-package cascade
scope/sequencing (Options A/B/C) is **escalated to the supervisor**; the in-scope 3-package plan stands
independent of that decision. **No code changed; no doc edited beyond this plan output + the handoff `## Findings`
pointer.** This doc is the HOW; `iterable-se0516-alignment.md` is the WHAT/WHY ([HANDOFF-013]).

## References

- `iterable-se0516-alignment.md` (Tier 2, RECOMMENDATION, principal-ratified 2026-05-30) — the delta D1–D8, the
  SE-0516 ↔ institute mapping, the `Iterator.Borrow` disposition. **This plan extends it.**
- `unified-iteration-design.md` (Tier 2, APPROVED v2.2.0) — the design authority (§2.1/§2.3/§2.5/§3/§6.3).
- `HANDOFF-data-structure-iteration-arc.md` — execution doc (§0 dispatch + acceptance, §3.4 step order, §8
  disciplines, §10 build/mirror notes).
- `bulk-span-iteration-fold-vs-separate.md` (Tier 3) — the `Span<~Copyable>` crux + SE-0516's rejection of
  element-wrapping.
- Primary sources (`Verified: 2026-05-30`): institute disk per V1–V5; `swiftlang/swift` clone
  `stdlib/public/core/BorrowingSequence.swift`, `Span/Span.swift` per V6.
- Skills: [RES-002/003/003c/013a/020/021/023/027]; [ARCH-LAYER-009]; [HANDOFF-013/021/035/040/047/050];
  [SUPER-009/012/023/042]; [API-ERR-001]; [API-NAME-001b].
