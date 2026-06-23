# Container-Protocol Lattice & Borrowing Iteration — the Audit-#5 Root Cause

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

R2 of the post-archaeology research arc. The W4 confidence audit flagged (Audit #5,
`.handoffs/REPORT-W4-seat-open-questions.md:121`):

> Shipping `Array<Element>` claimed the Collection lattice for `~Copyable` elements via the relaxed span
> bridge; the reshaped `Array<S>` chains through `Buffer.Linear: Span.Protocol`, whose current bound is
> `S.Element: Copyable` — so move-only-element direct columns lost `Collection.Protocol`/`Iterable`
> membership … Cause is the buffer-side bound, not Array. Either the buffer bridge re-relaxes … or this
> is accepted and recorded. Not yet root-caused — flagged for the W5 pass.

The dispatch instruction (STATUS:93): root-cause it — "do NOT record-and-accept." The decision fork named
in the brief: **re-relax the `S.Element: Copyable` bound, or adopt a borrowing-iteration protocol?** This
note answers with a verified bound census, a deciding compiler probe (preserved at
`.handoffs/probes-2026-06-10/r2-lattice-probe/`), and the upstream state as of today (SE-0516 is in
active review **until June 18, 2026**).

Verification: 12 load-bearing claims re-derived by an independent [RES-020] verifier 2026-06-10 (12/12
confirmed; one location correction — `__IteratorChunkProtocol` lives in swift-iterator-primitives, not
sequence-primitives — incorporated). Probe run by the author on Swift 6.3.2
(`TOOLCHAINS=org.swift.632202605101a`), debug and `-O`.

## Question

Why exactly did move-only-element direct columns lose `Collection.Protocol`/`Iterable` membership on the
reshaped tower, and what is the structurally correct restoration: re-relax the bound, adopt a
borrowing-iteration protocol layer, or both — judged against the upstream lattice (SE-0516 `Iterable`,
the `Container` future direction, swift-collections' ContainersPreview)?

## Headline answer

**The root cause is three-layered, and the fork is false — the answer is "both, and the borrowing-
iteration protocol layer already exists in the tower."**

1. **Layer 1 — a conformance-bundling accident (re-relaxable now).** The lattice *protocols* all already
   admit `Element: ~Copyable` (`Span.Protocol`, `Iterable`/`__IteratorChunkProtocol`,
   `Collection.Protocol` — verified declarations below). The exclusion enters at **conformance files**:
   `Buffer.Linear: Span.Protocol` is granted only `where … S.Element: Copyable`
   (`Buffer Linear Primitives/Buffer.Linear+Span.Protocol.swift:15`) — in the same file as
   the `withUnsafeBufferPointer` C-interop hatch that motivated the bound — while the raw `span`
   accessor one file over is unbounded (`Buffer Linear Primitive/Buffer.Linear+Span.swift:7`,
   `extension Buffer.Linear where S: Span.Protocol, S: ~Copyable`). [Verified: 2026-06-10] Array's own
   `Span.Protocol` conformance is unbounded (`Array.Conformances.swift:50`) but dispatches through `S:
   Span.Protocol` — so when the buffer conformance excludes move-only elements, the entire chain above
   falls off. The fix shape is mechanical: split the conformance from the C-interop extension; conform
   unbounded; keep the unsafe hatch separately gated.

2. **Layer 2 — the suspected structural wall is NOT a wall (probe-decided).** `Collection.Protocol`'s
   value-shaped `subscript(_:) -> Element { get }` requirement (Collection.Protocol.swift:76) looked like
   a genuine Copyable floor (you cannot return a `~Copyable` element by value from a borrow — upstream
   comments its Container subscript out for exactly this, pending `borrow` accessors). The probe refutes
   the generalization: on 6.3.2, **generic borrow-through-call reads through a `{ get }` requirement over
   `~Copyable` Element compile and run correctly (debug and `-O`), and the consume-out case
   (`let v = t[0]`) is compiler-rejected** — i.e. the requirement behaves as a borrow for `~Copyable`
   instantiations, with escape/consume soundly walled. So `Collection.Protocol` membership CAN extend to
   move-only-element columns; only the element-*returning* conveniences (`.first` etc., already
   `Element: Copyable`-gated extensions) stay Copyable-only — the same restriction split SE-0516
   documents for `Iterable` ("*None* of these restrictions apply when an `Iterable` type's element is
   `Copyable`").

3. **Layer 3 — upstream is mid-churn; do not chase it.** The tower's chunk-iterator layer is already
   structurally convergent with SE-0516's *revised* design — `__IteratorChunkProtocol` requires
   `next(maximumCount:) throws(Failure) -> Span<Element>` + `skip(by:)` with
   `associatedtype Failure: Error = Never` (swift-iterator-primitives), which is SE-0516's
   `nextSpan(maximumCount:) throws(Failure) -> Span<Element>` + `skip(by:)` shape including the
   Failure revision. Upstream's names are actively contested mid-review (the author floated
   `IterableIterator → SpanIterator` renames in the review thread on 2026-06-09, post #25); the
   Collection-analog (`Container`) exists only as a future-directions draft plus a default-off
   swift-collections preview that its own author labels "no project- or team-wide consensus on any of
   these constructs." Hold naming alignment until SE-0516 resolves; the structure needs no new protocol.

**One discovery with arc-wide consequences:** the entire lattice's `associatedtype Element: ~Copyable`
spellings ride the **experimental `SuppressedAssociatedTypes` flag** — bare 6.3.2 rejects the spelling
outright ("cannot suppress 'Copyable' requirement of an associated type"); the lattice packages all
enable the flag in `Package.swift` (collection/iterator/sequence/span/array-primitives, verified).
SE-0516 builds on the accepted form of this feature (it cites SE-0503 suppressed associated types). This
is a standing experimental-feature dependency to carry in the gate-bump dossier: when the gate moves,
verify the SE-0503-accepted spelling matches what the flag accepts today.

## The bound census (where Copyable actually enters)

Full census ran across span/iterator/sequence/collection/buffer-linear/array/shared sources; the
load-bearing rows [Verified: 2026-06-10]:

| Site | Bound | Role |
|---|---|---|
| `Span.Protocol` decl (span-primitives, Span.Protocol.swift:122–133) | `Element: ~Copyable` | capability ADMITS move-only |
| `__IteratorChunkProtocol` decl (iterator-primitives, :42–64) | `Element: ~Copyable`, `Failure = Never` | chunk iteration ADMITS move-only |
| `Collection.Protocol` decl (collection-primitives, :58–76) | `Element: ~Copyable`; `subscript -> Element { get }` | lattice ADMITS move-only; subscript probe-cleared |
| **`Buffer.Linear: Span.Protocol` conformance** (+Span.Protocol.swift:15) | **`S.Element: Copyable`** | **the Layer-1 gate** (bundled with `withUnsafeBufferPointer`) |
| `Buffer.Linear` raw `span` accessor (+Span.swift:7) | none | proof the bound is not needed for the span itself |
| `Buffer.Linear: Iterable` (+Iterable.swift:18) | `S: Copyable, S.Element: Copyable` | inherited gate + an `S: Copyable` to re-examine (chunk iteration borrows; the iterator wraps a `Span`, which is Copyable regardless of Element) |
| Array/Fixed lattice extensions (Array ~Copyable.swift:37,41,45; Array.Conformances.swift:25,63; Fixed twins) | `S.Element: Copyable` | downstream propagation of Layer 1 |
| `Collection.Protocol+First.swift:8` etc. | `Element: Copyable` | correct — element-returning conveniences |
| Scalar single-pass iterators (Buffer.Linear[.Bounded].Scalar) | `S(.Element): Copyable` | genuinely structural (`next()` copies out); the Bounded Scalar reshape is already on the W4 ledger |

## The probe (preserved: `.handoffs/probes-2026-06-10/r2-lattice-probe/`)

Shape: `protocol P: ~Copyable { associatedtype E: ~Copyable; subscript(i: Int) -> E { get } }`, a
`~Copyable` conformer witnessing via `_read`, and a generic `func useBorrow<T: P & ~Copyable>(_ t:
borrowing T)` reading `peek(t[0])` with `peek(_: borrowing NC)`.

| Variant | 6.3.2 result |
|---|---|
| bare toolchain, the protocol decl itself | REJECTED — `cannot suppress 'Copyable' requirement of an associated type` (hence the flag dependency) |
| + `SuppressedAssociatedTypes` + `LifetimeDependence`: borrow-through-call (`peek(t[0])`) | **compiles exit=0, debug AND `-O`; runs: `peek 7` with no premature deinit** |
| same flags: `let v = t[0]` (consume out) | **REJECTED** — `noncopyable 't.subscript' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type` |

Verdict: the value-`{ get }` requirement is usable as a borrow for `~Copyable` elements in generic
contexts; only escape/consume is walled. This removes the only structural objection to extending
`Collection.Protocol` membership to move-only-element columns on the current gate.

## Upstream state (so the recommendation ages well)

- **SE-0516 "Iterable"** — Active review June 4–18, 2026. Core: `protocol Iterable<Element, Failure>:
  ~Copyable, ~Escapable { associatedtype Element: ~Copyable; associatedtype Failure: Error = Never; …
  makeIterableIterator() }` + `IterableIteratorProtocol.nextSpan(maximumCount:) throws(Failure) ->
  Span<Element>` + `skip(by:)`. History: first review **returned for revision** with LSG direction to
  situate it in "the broader design direction(s) of generalized containers of ~Copyable types"; revision
  added the `Failure` type and the Iterable rename; the second review has live naming churn (author
  post #25, 2026-06-09, floating `SpanIterator`/`makeSpanIterator`). The dual-conformance rule means
  `for`-loop borrowing iteration initially applies only to span types and `InlineArray`.
  [Verified: 2026-06-10]
- **`Container`** — exists only as SE-0516's Future Directions draft (indexed `nextSpan(after:…)` + a
  `borrow`-accessor subscript) and as swift-collections' default-off, underscore-named preview whose
  per-element subscript is literally commented out awaiting borrow accessors
  (`ContainersPreview/Protocols/Container/Container.swift:168` @ `af174fe`). lorentey (1.4.1
  announcement): "there is no project- or team-wide consensus on any of these constructs."
  [Verified: 2026-06-10]
- **SE-0527 acceptance shape** — UniqueArray accepted **in principle**, RigidArray NOT accepted, placed
  in the Swift module (no Containers module); its only iteration conformance is SE-0516's
  (`makeBorrowingIterator() -> SpanIterator<Element>` built from `self.span`); all Collection-style API
  ships as concrete members. I.e. upstream's move-only containers run span-first with sequence-level
  borrowing iteration and NO Collection analog — the same posture the tower would have after the Layer-1
  fix even before any Collection relaxation. [Verified: 2026-06-10]
- **Convergence table** (institute ↔ upstream): `Sequence.Borrowing.Protocol` ↔ `Iterable` (borrowing
  `makeIterator` ↔ `makeIterableIterator`); `__IteratorChunkProtocol` ↔ `IterableIteratorProtocol`
  (`next(maximumCount:)->Span` ↔ `nextSpan(maximumCount:)->Span`, both with `skip(by:)` + `Failure`);
  `Collection.Protocol` ↔ `Container` (future direction); institute typed `maximumCount: some
  Carrier.Protocol<Cardinal>` vs upstream `Int` — the one deliberate divergence (typed-arithmetic
  discipline).

## Outcome

**Status: RECOMMENDATION** (research only; the edits belong to the executor/W5 owner — change-shapes
below are verified, not applied).

1. **Re-relax Layer 1 (the Audit-#5 fix):** split `Buffer.Linear: Span.Protocol` out of the C-interop
   file and conform `where S: Span.Protocol & ~Copyable` with no element bound (the raw accessor already
   proves it); same for `.Bounded`; keep `withUnsafeBufferPointer` in its own `S.Element: Copyable`
   extension (separately: check whether 6.3.2's `UnsafeBufferPointer` generalization would even allow
   relaxing the hatch — executor verification, not assumed). Re-examine the `S: Copyable` on the
   `Iterable` conformances — chunk iteration borrows and the iterator wraps a (Copyable) `Span`, so the
   storage-column Copyability looks unnecessary; verify at implementation.
2. **Extend the lattice to move-only elements (probe-cleared):** after Layer 1, drop
   `S.Element: Copyable` from the Array/Fixed `Collection.Protocol`/`Bidirectional`/`Access.Random`/
   `Iterable` extensions; keep every element-RETURNING convenience `Element: Copyable`-gated (already
   the file layout). Witnesses stay `_read`/`borrowing get` coroutines. Add the borrow-through-call read
   idiom to the family docs (binding `let x = a[i]` on move-only elements is — correctly — a compile
   error; reads happen via borrowing arguments, `withElement`, or spans).
3. **Adopt no new protocol and no upstream names now:** the borrowing-iteration layer the brief asks
   about is already shipped (Sequence.Borrowing + __IteratorChunkProtocol) and matches SE-0516's revised
   structure including `Failure`. Revisit naming alignment ONCE, after SE-0516's outcome (review closes
   **2026-06-18** — watch item), via the existing `iterable-revision-pitch-comparison.md` track.
4. **Gate-bump dossier entries (rider):** the `SuppressedAssociatedTypes` experimental-flag dependency
   (whole lattice; verify the SE-0503-accepted spelling at the bump); borrow/`mutate` accessors (SE-0474
   spelling absent on 6.3.2 per the W4 Q5 probe) as the eventual replacement for the probe-cleared
   `{ get }`-as-borrow pattern and for upstream-`Container` parity.
5. **Record the SE-0516 dual-conformance caveat:** types conforming BOTH `Sequence` and a future stdlib
   `Iterable` get value-based `for` loops; the tower's own `for`-style iteration over move-only elements
   remains explicit (chunk loops / `withElement`) until upstream's `for` integration applies to
   third-party types.

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Generic borrow-reads through `{ get }` requirements over ~Copyable Element on 6.3.2 | **premise** (load-bearing for rec. 2) | Probe-verified 2026-06-10, debug+`-O`; artifacts preserved at `.handoffs/probes-2026-06-10/r2-lattice-probe/` (p1/p2 + RESULTS.md); formalize into `Experiments/` if/when the relaxation lands |
| The relaxed conformances compile + behave across the REAL lattice (witness-level, cross-module) | premise for the executor's change | The executor's gated build is the verification (per its GOAL discipline); this doc supplies the verified change-shape only |
| `withUnsafeBufferPointer` relaxability (UBP ~Copyable Element on 6.3.2) | direction | Executor check at implementation; not assumed anywhere above |
| SE-0516 outcome + names | direction (watch: review closes 2026-06-18) | Single rename-alignment pass post-resolution |
| `Buffer.Linear.Bounded.Scalar` reshape (`S: Copyable` vs move-only Storage.Contiguous) | direction | Already on the W4 withdrawal ledger; unaffected by this doc |
| Shared-column span conformance ("Shared joins when it gains a span") | direction | Future; `ensureUnique()`-before-vend constraint carries (archaeology Q5) |

## References

- **Internal**: `.handoffs/REPORT-W4-seat-open-questions.md` :121 (Audit #5), :94–109 (Q5 accessor
  probe); `.handoffs/HANDOFF-tower-flag-day-migration.md` STATUS :93; the bound census sources —
  span-primitives `Span.Protocol.swift:122–133`, `Span.Mutable.Protocol.swift:26–39,68–79`;
  iterator-primitives `__IteratorChunkProtocol.swift:42–64`; sequence-primitives
  `Sequence.Borrowing.Protocol.swift:45–77`; collection-primitives `Collection.Protocol.swift:58–76`,
  `+First.swift:8`; buffer-linear `Buffer.Linear+Span.swift:7`,
  `Buffer.Linear+Span.Protocol.swift:15`, `Buffer.Linear+Iterable.swift:18`;
  array-primitives `Array ~Copyable.swift:37,41,45`, `Array.Conformances.swift:25,50,63`;
  sequence-primitives Research `element-tilde-escapable-stdlib-span-blocker.md` (the ~Escapable-element
  ceiling — unchanged by this note), `iterable-revision-pitch-comparison.md`;
  `stdlib-array-family-source-archaeology.md` (parent).
- **Upstream**: SE-0516 `0516-borrowing-sequence.md` (decls :68–139; Container FD :544–584; status :6) +
  review threads t/85846 (returned-for-revision), t/87106 (second review; post #25 renames); SE-0527
  `0527-rigidarray-uniquearray.md` :1489–1497 + acceptance t/86943; apple/swift-collections @ `af174fe`
  ContainersPreview (BorrowingSequence_/BorrowingIteratorProtocol_/Container :17–204 incl. the :168
  commented subscript; Producer/Drain), BasicContainers `RigidArray+Container.swift:23–48`; lorentey,
  Swift Collections 1.4.1 announcement t/85425 (the no-consensus sentence).
- **Probe**: `.handoffs/probes-2026-06-10/r2-lattice-probe/{p1.swift,p2.swift,RESULTS.md}` (Swift 6.3.2,
  2026-06-10).

### Verification

[RES-020] parallel verification 2026-06-10: 12 claims re-derived (upstream decls/status/review posts;
local bound sites; s-c preview state) — 12/12 confirmed, one location correction incorporated
(`__IteratorChunkProtocol` home = swift-iterator-primitives). Probe run twice (raw + clean exit-code
harness), debug and `-O`, results identical.
