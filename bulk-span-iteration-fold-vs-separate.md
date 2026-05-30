# Bulk/Span Iteration: Fold-vs-Separate Under the Ownership Model

<!--
---
version: 1.0.1
last_updated: 2026-05-26
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - "1.0.1 (2026-05-26): naming: bulk tier Iterator.Span/Contiguous → Iterator.Chunk; Memory.Contiguous.Iterator example → Memory.Contiguous. Institute on-disk-shape refs (§Context, §6 table, §7 option (c), References) brought current to Iterator.Chunk.`Protocol`; the Iterator.Borrow→Iterator.Span→Iterator.Chunk rename history is preserved (§Implications #3). All SE-0516 / stdlib citations (nextSpan, BorrowingIteratorProtocol, BorrowingSequence, SpanIterator, stdlib Iterable, Span<Element>, Swift.Span) kept verbatim."
  - "1.0.0 (2026-05-26): Initial draft. External-evidence survey (stdlib SE-0516 in-flight
     source on the local swiftlang/swift clone + the SE-0516 review/revision history +
     Forums) commissioned to inform the in-progress institute decision on whether the bulk/
     chunk (Span-based) capability should be FOLDED into the one Iterator.`Protocol` as an
     optional fast-path, kept as a SEPARATE refining protocol, or something else. Extends
     (does not duplicate) unified-iteration-design.md, sequencer-primitives-
     reconciliation-refactor.md, collection-sequence-protocol-detachment.md, and the
     /tmp/iter-bulk-spike findings (Swift 6.3.2). The principal decides; this doc presents
     evidence + implications only."
---
-->

> **Status — RECOMMENDATION, not a decision.** This is an evidence survey for the in-progress
> `Iterator.`Protocol`` / sequencer end-state decision (`HANDOFF-data-structure-iteration-arc.md`,
> `unified-iteration-design.md` v0.10.0). It synthesizes external evidence
> (Swift stdlib in-flight source + Swift Evolution + Forums) against the institute's existing
> internal decisions. **It does not make the institute design decision** — it states where the
> evidence leans and why, for the principal to weigh.

## Context

A 2026-05-26 `/tmp` spike (`/tmp/iter-bulk-spike/findings.md`, Apple Swift 6.3.2,
`swiftlang-6.3.2.1.108`) tested whether a **folded** iterator design works: one move-only
(`~Copyable & ~Escapable`) protocol with `next()` *plus* an optional defaulted bulk hook
`withNextChunk<R>(maximumCount:_:) -> R?`. The folded shape **compiles and runs**, and a
conformer's override of the defaulted bulk hook **is dynamically dispatched** through a generic
constraint on the move-only protocol (the only dispatch mechanism available — move-only protocols
cannot form existentials, and this is exactly what the real consumer uses, so the result transfers).

The spike surfaced one mandatory caveat that **changes the protocol's exact text**: the
`associatedtype Element` must be `~Copyable` (Escapable retained), **NOT** `~Copyable & ~Escapable`,
because **`Span<Element>` requires `Element: Escapable`**. The verbatim compiler error for the
maximally-permissive shape is:

```
folded.swift:21:23: error: instance method requirement 'withNextChunk(maximumCount:_:)'
  cannot add constraint 'Self.Element: Escapable' on 'Self'
```

So a maximally-permissive iterator protocol that admits `~Escapable` element *views* CANNOT expose
a `Span`-based bulk hook on that same protocol. **This Span-element-escapability constraint is the
crux** of the fold-vs-separate decision.

The institute already shipped a **separate** shape on disk: `Iterator.`Protocol`` (scalar, admits
`~Escapable` Element) + an `Iterator.Chunk.`Protocol`` refinement (bulk, narrows Element to
`Escapable`). This doc asks whether the external Swift ecosystem corroborates or contradicts that
separation, and what it implies for the open `Iteration.Bulk` naming/placement decisions.

**Trigger**: [RES-001] architecture choice — the bulk-tier decision is gated on the principal
(`HANDOFF-data-structure-iteration-arc.md` §"Open Decisions"; G4) and must stay consistent with
the sequencer D-2 decision (one rule, both layers). The spike is empirical input; the prompt asked
for the external-evidence half (stdlib/SE/Forums).

**Tier**: 3 — ecosystem-wide; precedent-setting (iteration is foundational to sequence, collection,
parser, lexer, serializer, every container); cost of error very high; timeless infrastructure.

## Question

Under Swift's ownership model (`~Copyable` / `~Escapable`), how should iteration protocols model
**bulk/chunk (`Span`-based) iteration alongside scalar iteration** — (a) FOLDED into the one
iterator protocol as an optional defaulted fast-path, (b) a SEPARATE refining protocol, or (c)
something else? And specifically: how does the wider Swift ecosystem (stdlib / Swift Evolution /
Forums) resolve the `Span<Element>`-requires-`Element: Escapable` tension — keep `~Escapable`-element
iteration scalar + a separate bulk protocol, or narrow the element to gain a folded bulk hook?

## Analysis

### 1. The crux, confirmed at the language level: `Span` has no `~Escapable` element form

The spike's caveat is not a quirk of one toolchain — it is the actual stdlib declaration. In the
local clone:

```swift
@frozen
public struct Span<Element: ~Copyable>: ~Escapable, Copyable, BitwiseCopyable {
```
— `stdlib/public/core/Span/Span.swift:25-29` (`Verified: 2026-05-26`).

`Span` relaxes `Element` to `~Copyable` but **does not** admit `~Escapable` — the element bound is
`~Copyable` only (Escapable retained). SE-0447 (the `Span` proposal, **Implemented Swift 6.2**) is
the source of this contract. Consequently **any** API whose signature mentions `Span<Element>` while
`Element` is a protocol's `~Escapable` associated type silently tries to add `Self.Element: Escapable`
and is rejected — the exact spike error. This is a hard, language-level constraint, not routable
around for an element-typed `Span` hook. (A `RawSpan`/byte-level bulk hook could sidestep it for
trivial elements but changes the element model — out of scope; noted as a frontier.)

This crux is already recorded internally in three places, which this doc extends rather than
re-derives:

- `iterator-span-buffer-elimination.md` (DECISION, v5.0.0) — the bulk tier is the `nextSpan`
  surface; 32 heap-allocating conformers reducible to zero, but every `nextSpan` is
  `Escapable`-element-bound.
- `unified-iteration-design.md` (RECOMMENDATION, v1.2.1) §4.3 — names the blocker
  verbatim: "`~Escapable` relaxation is BLOCKED until `Swift.Span<Element>` accepts
  `Element: ~Escapable` upstream"; classifies the bulk/span tier as a *distinct position-shape*
  from the scalar tier.
- `unified-iteration-design.md` (DRAFT, v0.10.0) §2 — "that block is a
  *consequence of being bulk-first* (the `Span` ceiling). On the scalar `Iterator.`Protocol``
  (`Element: ~Copyable & ~Escapable`) the block lifts for the element-transforming path."

### 2. The Swift stdlib went SEPARATE — and the in-flight source proves it

The local clone `swiftlang/swift` contains in-flight stdlib work (`@available(SwiftStdlib 6.4, *)`)
that is the implementation of **SE-0516: Borrowing Sequence** (status **Returned for revision**, per
the proposal header at `swift-evolution/proposals/0516-borrowing-sequence.md`, `Verified: 2026-05-26`).
The shape is decisive:

```swift
@available(SwiftStdlib 6.4, *)
public protocol BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable {
  associatedtype Element: ~Copyable          // Escapable retained — NOT ~Escapable
  @_lifetime(&self)
  @_lifetime(self: copy self)
  mutating func nextSpan(maximumCount: Int) -> Span<Element>
  @_lifetime(self: copy self)
  mutating func skip(by maximumOffset: Int) -> Int
}

@available(SwiftStdlib 6.4, *)
@reparentable
public protocol BorrowingSequence<Element>: ~Copyable, ~Escapable {
  associatedtype Element: ~Copyable
  associatedtype BorrowingIterator: BorrowingIteratorProtocol<Element> & ~Copyable & ~Escapable
  @lifetime(borrow self)
  func makeBorrowingIterator() -> BorrowingIterator
  var underestimatedCount: Int { get }
  func _customContainsEquatableElement(_ element: borrowing Element) -> Bool?
}
```
— `stdlib/public/core/BorrowingSequence.swift:15-72, 143-163` (`Verified: 2026-05-26`).

Four facts establish the SEPARATE disposition:

1. **`BorrowingIteratorProtocol` is a distinct protocol from `IteratorProtocol`.** The scalar
   `IteratorProtocol` (`Sequence.swift`, `Verified: 2026-05-26`) is unchanged — bare
   `associatedtype Element` (Copyable, Escapable), `mutating func next() -> Element?`, no `Span`.
   The bulk protocol is a separate type with `nextSpan(maximumCount:) -> Span<Element>` as its
   **sole** element-access requirement. **There is no scalar `next()` anywhere in the bulk protocol**
   (confirmed: the SE-0516 GitHub text states "There is **no scalar `next()` method** in either
   protocol").

2. **The element bound is `~Copyable` (Escapable retained), exactly matching the spike.** The
   stdlib *cannot* and *does not* fold a `Span`-returning bulk method onto a `~Escapable`-element
   protocol — for the identical reason the spike found. `BorrowingIteratorProtocol.Element: ~Copyable`
   (`BorrowingSequence.swift:16`).

3. **The two worlds are bridged by an ADAPTER, not folded.** A separate
   `BorrowingIteratorAdapter<Iterator: IteratorProtocol>` wraps a scalar iterator and serves up
   one-element spans (via `Optional._span()`); a `@_disfavoredOverload`
   `makeBorrowingIterator()` on `Sequence where Self: BorrowingSequence` supplies it
   (`BorrowingSequence.swift:196-228`). This is the stdlib choosing *composition at the boundary*
   over *folding into one protocol*.

4. **Reparenting is future work, kept out of the core protocol.** `@reparentable` on
   `BorrowingSequence` plus the explicit FIXME — "Eliminate these overloads once Sequence is
   reparented, they break ambiguity for types that conform to both BorrowingSequence and Sequence
   or Collection" (`BorrowingSequence.swift:173-174`) — shows that even the *relationship* between
   the scalar and bulk worlds is deferred to a separate proposal, not resolved by folding.

### 3. The stdlib EXPLICITLY rejected the folded/scalar alternative

SE-0516's *Alternatives Considered* contains a subsection "Basing `~Copyable` iteration on
`IteratorProtocol`" — the closest analogue to the institute's FOLD option and to the spike's scalar
companion. It sketches a scalar design where the iterator's `next()` returns a *borrowed-element
wrapper* (e.g. `Span` would return `Borrow<Element>` from `next()`), then **rejects it** for two
reasons (quoted from the SE-0516 proposal text, `Verified: 2026-05-26` via the GitHub proposal and
the Forums revision pitch):

1. **Performance / "fundamental, not optional".**
   > "Primarily, the bulk iteration aspect of the proposed `BorrowingSequence` is a critical part of
   > improving performance when working with a wide variety of collections."

   and the principle: *"having fundamental functionality defined in the most basic, underlying
   protocol is important for predictable performance."* The pitch author's framing (Ben Cohen, via
   Michael Tsai's summary, `Verified: 2026-05-26`): *"Iterating a `Span` in the inner loop is a lot
   closer to the 'ideal' model of advancing a pointer over a buffer and accessing the elements
   directly."* The bulk path is treated as the **base capability**, not a fast-path bolted onto a
   scalar base.

2. **Call-site awkwardness of the wrapped element.**
   > "the different element types used in this alternative design lead to awkward usage at the call
   > site"

   — users would write predicates over `(borrowing Borrow<NoncopyableInt>) -> Bool` instead of the
   intended element type, which "doesn't meet our usability expectations."

This is the **inverse** of the institute's current `Iterator.Borrow.`Protocol`` choice (which *does*
wrap: `Element == Ownership.Borrow<Borrowed>`). The stdlib rejected element-wrapping for *general
borrowing iteration* on usability grounds; the institute accepted it for its *scalar keep-and-lend*
tier (`unified-iteration-design.md` §4.5) precisely because that tier is **not** the bulk
tier — it is the scalar dual of `Iterator.`Protocol``, and the wrapper is the named `Borrowed`
surface, not a throughput device. These are not in conflict; they are two different axes (scalar
keep-and-lend vs bulk/contiguous), which is itself evidence *for* separation along the granularity
axis.

### 4. The unresolved tension in the latest revision — and why it does NOT overturn the crux

The latest Forums revision pitch ("[Revision/Pitch] `Iterable` (formerly `BorrowingSequence`)",
`Verified: 2026-05-26`) renames `BorrowingSequence` → `Iterable` for "a more universal role" and
makes three changes: (a) the rename, (b) **`Element` relaxed to `~Copyable & ~Escapable`**, (c)
typed-throws `Failure`. Change (b) appears to *contradict* §1's crux. It does not, on close reading:

- The revision's iterator method is still `nextSpan(maximumCount:) throws(Failure) -> Span<Element>`
  (per the revision-pitch declarations), and the revision **provides no mechanism** for returning a
  `~Escapable` element through a `Span` (which still requires `Element: Escapable`). This is a
  **genuine open inconsistency in the in-flight pitch**, not a solved design: the introduction
  claims `~Escapable` elements are "now allowed," but the only element-access method shown cannot
  carry them, and the discussion does not reconcile it. (Stated as *forum-pitch state*, not
  stdlib-fact: the *shipped* clone source — §2 — still has `Element: ~Copyable`.)
- The LSG's stated reasons for returning SE-0516 for revision (Forums, "[Returned for revision]…",
  `Verified: 2026-05-26`, dated 2026-04-07) are **"the future evolution of `BorrowingSequence` …
  within the broader design direction(s) of generalized containers of `~Copyable` types"**, plus
  **API naming** and **whether to support throwing sequences** — i.e. *scope and naming*, not a
  reversal of the separate-protocol/bulk-first architecture. The separation is not what was sent
  back.

**Net for the institute**: even the most aggressive in-flight relaxation (`Element: ~Copyable &
~Escapable` on the *Iterable container*) has not produced a `Span`-based bulk hook that admits
`~Escapable` elements. The crux holds on every toolchain examined; the revision's claim is an
unreconciled aspiration, and the institute should treat it as `(forum-pitch, unverified)` until a
production compiler ships a `~Escapable`-element span mechanism (none exists today — SE-0447 `Span`
is `Element: ~Copyable` only, **Implemented Swift 6.2**).

### 5. The language-level alternative (`for borrow` / `for inout`) is older and orthogonal

The `for borrow` / `for inout` pitch (Forums, dated 2023-01-13, `Verified: 2026-05-26`) is the
language-syntax route to non-copying iteration. It is **index/subscript-based** (scalar:
`inout n = &$collection[$i]`), pre-dates the protocol work, and its own discussion flags the open
choice between "index-based iteration" and "a noncopyable borrowing iterator protocol" — with John
McCall advocating "a new generator-function requirement that yields borrowed values" as future work.
It is not an accepted resolution and does not fold bulk and scalar. It corroborates the broader
picture (`for-in` over `~Copyable` is unfinished, routed through *either* indices *or* a borrowing
iterator protocol) but adds no fold-vs-separate signal beyond §2-§3.

### 6. Internal prior art is already SEPARATE and consistent with the stdlib

The institute's shipped shape and decisions line up with the stdlib direction on the granularity
axis:

| Internal artifact | Disposition | Bearing on fold-vs-separate |
|---|---|---|
| `Iterator.`Protocol`` (scalar) + `Iterator.Chunk.`Protocol`` (bulk refinement) on disk in `swift-iterator-primitives` | **SEPARATE** — scalar admits `~Escapable` Element; bulk **narrows** Element to `Escapable` (the `Span` ceiling) | Matches stdlib `IteratorProtocol` vs `BorrowingIteratorProtocol` split exactly: scalar protocol keeps the permissive element, bulk protocol carries the `Escapable`-narrowed `Span` method. (`unified-iteration-design.md` §3 table) |
| `unified-iteration-design.md` v0.10.0, **D-2 (RESOLVED — RETIRE)** | Retire the bulk-span *borrowing-sequence* protocol; bulk-span = contiguous-memory property → `Memory.Contiguous.Protocol`; scalar borrowing-sequence = `Iterable where Iterator: Iterator.Borrow.Protocol` | The institute went *further* than "separate protocol": it moved the bulk/contiguous capability out of the *iteration* hierarchy entirely and onto a *memory* abstraction, because "produce span chunks is a property of contiguous storage, not a kind of sequence." Stdlib keeps bulk in the iteration hierarchy (`BorrowingIteratorProtocol`); the institute routes contiguous-bulk to `Memory.Contiguous`. Both are *non-fold* answers; they differ on *where* the bulk surface lives. |
| `collection-sequence-protocol-detachment.md` v1.1.0 (DECISION), Step C | `Sequence.Borrowing.Protocol` reframed as "chunked span access optimization over `Memory.Contiguous.Protocol`, not borrowing iteration"; every call site passes `Cardinal(UInt.max)` (nobody chunks) | Reinforces D-2: the institute's empirical finding is that the *bulk* path is, in practice, "give me the whole span" = `Memory.Contiguous.span`, not a chunking iterator. |
| `HANDOFF-data-structure-iteration-arc.md` (Key Decisions 1-4; G1-G3) | Keep the bulk tier; build it on `Memory.Contiguous` (not raw `Swift.Span`); name the manner `Iterator.Chunk` (NOT `Contiguous`, which is reserved for the memory *subject* `Memory.Contiguous`) | These are *placement/naming* decisions atop an already-separate architecture. The external evidence (§2-§3) does not disturb them; it supports keeping bulk distinct. |

No internal doc currently compares the institute's choice against SE-0516's *explicit*
Alternatives-Considered rejection of the folded/scalar design — this doc supplies that link.

### 7. Option comparison (the question's (a)/(b)/(c), against the evidence)

| Option | Description | What the evidence says | Element admissibility |
|--------|-------------|------------------------|-----------------------|
| **(a) FOLD** — one protocol, optional defaulted `Span` bulk hook | Spike proves it *compiles + dispatches* | **Stdlib rejected the analogous fold** (SE-0516 Alternatives: bulk is "fundamental, not optional"; wrapper-element is awkward). Folding forces the **whole** protocol's `Element` to `Escapable` (the `Span` ceiling), **losing `~Escapable`-element scalar iteration** — the institute's load-bearing capability (views into iterator-owned storage; `two-world` §4.5). | **Element MUST be `Escapable`** — `~Escapable` element iteration is sacrificed. |
| **(b) SEPARATE** — scalar protocol (admits `~Escapable` Element) + bulk refinement (narrows to `Escapable`) | The institute's current on-disk shape; the stdlib's shape (`IteratorProtocol` + `BorrowingIteratorProtocol`) | **Strongly corroborated.** Stdlib went separate; the institute went separate; both keep the scalar protocol permissive and isolate the `Escapable` narrowing to the bulk protocol where `Span` lives. | **Scalar admits `~Escapable`; bulk is `Escapable`-only.** Best of both. |
| **(c) ELSEWHERE** — bulk/contiguous capability lives on a *memory* abstraction, not the iterator hierarchy | The institute's D-2 resolution: `Memory.Contiguous.Protocol` owns `span`; "bulk iteration" = `Iterable where Iterator: Iterator.Chunk.Protocol`, or just `Memory.Contiguous.span` | **Institute-specific, evidence-compatible.** Goes beyond stdlib (which keeps bulk in the iteration hierarchy) but is *more* aligned with the decomposition principle and with the empirical "nobody chunks" finding. Not contradicted by any external evidence. | Scalar iteration stays `~Escapable`-admitting; contiguous-bulk is a memory property (`Escapable` elements). |

## Outcome

**Status**: RECOMMENDATION (evidence survey; the principal decides).

### Where the evidence leans: SEPARATE (decisively)

Across every external source examined, the Swift ecosystem leans **SEPARATE**, not FOLD:

- The shipped stdlib clone implements bulk borrowing iteration as a **distinct protocol**
  (`BorrowingIteratorProtocol` / `BorrowingSequence`) from scalar `IteratorProtocol` / `Sequence`,
  bridged by an **adapter**, with **reparenting deferred** to a future proposal
  (`BorrowingSequence.swift`).
- SE-0516 **explicitly considered and rejected** the folded/scalar-with-wrapper design in
  *Alternatives Considered*, on two grounds: bulk-span throughput is **"a critical part of improving
  performance … fundamental functionality defined in the most basic, underlying protocol"** (so it
  must be a base capability, not an optional hook), and the wrapped-element call-site ergonomics
  **"[do] not meet our usability expectations."**
- The LSG's return-for-revision concerns were **scope and naming**, *not* the separate-protocol /
  bulk-first architecture — that part of the design was not sent back.

### The single strongest reason

**`Span<Element>` admits `Element: ~Copyable` but NOT `~Escapable` (SE-0447, Implemented Swift 6.2;
`Span/Span.swift:25-29`).** Folding a `Span`-based bulk hook onto the one iterator protocol therefore
**forces the entire protocol's `Element` to `Escapable`**, which **destroys `~Escapable`-element
scalar iteration** — the institute's load-bearing capability of iterating views into iterator-owned
storage (`unified-iteration-design.md` §4.5; the foundation `Iterator.`Protocol`` declares
`Element: ~Copyable & ~Escapable` verbatim "to admit `~Escapable` element types"). The stdlib hit
the identical wall and resolved it by **separation** (`BorrowingIteratorProtocol.Element: ~Copyable`,
isolated from the permissive scalar `IteratorProtocol`). The institute's spike hit the identical
wall with the identical error. Separation is the only shape that **keeps both** `~Escapable`-element
scalar iteration **and** a `Span`-based bulk fast-path; folding can keep at most one.

### On retaining `~Escapable`-element iteration

The evidence is unambiguous that **`~Escapable`-element iteration must be retained on a *scalar*
protocol** if the institute wants it at all — and the institute's existing architecture, the stdlib's
shipped `IteratorProtocol`, and the spike all keep the scalar protocol's `Element` permissive
(`~Copyable & ~Escapable`) precisely because no `Span`-based bulk method can carry `~Escapable`
elements on any production toolchain today. The latest SE-0516 revision pitch's claim that `Iterable`
elements may be `~Copyable & ~Escapable` is, as of 2026-05-26, an **unreconciled aspiration**
(`(forum-pitch, unverified)`): its only element-access method still returns `Span<Element>`, which
still requires `Escapable`. The institute should not treat that claim as settled; the shipped clone
(§2) still narrows the bulk element to `Escapable`.

### Implications for the open institute decisions (do not pre-empt the principal)

1. **Fold-vs-separate (the prompt's core question)**: external evidence supports the institute's
   *already-separate* architecture and supports **rejecting FOLD**. The spike proving FOLD *compiles*
   is necessary-but-not-sufficient: the stdlib proves the community can fold technically and chose
   not to, for reasons (capability loss + ergonomics + "bulk is fundamental") that apply identically
   here.
2. **Option (b) vs option (c)**: the *external* evidence does not adjudicate between the institute's
   two non-fold answers — keep a bulk *iteration* refinement (`Iterator.Chunk.`Protocol``, stdlib-shaped)
   vs route contiguous-bulk to a *memory* abstraction (`Memory.Contiguous`, the D-2 resolution). That
   is an internal decomposition call already resolved as D-2 (RETIRE the bulk-span *sequence* protocol;
   bulk = contiguous-memory property), and the external evidence is *compatible* with it. The
   `HANDOFF` Key Decisions (build the bulk manner on `Memory.Contiguous`; the memory bridge vends
   `Iterator.Chunk` over the `Memory.Contiguous` subject) sit on top of this and are undisturbed.
3. **Naming**: the stdlib's own naming is in flux (`BorrowingSequence` → `Iterable`; the "Borrow"
   stem was a known hazard the institute *also* hit and resolved by renaming `Iterator.Borrow` →
   `Iterator.Span` → `Iterator.Chunk`, `two-world` §3). This is corroboration that the bulk tier
   should be named for *what it does* (chunk/bulk), not for *ownership* — consistent with `HANDOFF`
   G2 (do NOT name the manner `Contiguous`; that word belongs to the memory *subject*).

## References

### Local stdlib clone (`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/`)
- `Span/Span.swift:25-29` — `public struct Span<Element: ~Copyable>: ~Escapable, …` (the crux: no `~Escapable` element). `Verified: 2026-05-26`.
- `BorrowingSequence.swift:15-72` — `BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable`, `associatedtype Element: ~Copyable`, `nextSpan(maximumCount:) -> Span<Element>`, `skip(by:)`. `Verified: 2026-05-26`.
- `BorrowingSequence.swift:99-140` — `SpanIterator<Element>` (the contiguous-storage bulk iterator). `Verified: 2026-05-26`.
- `BorrowingSequence.swift:143-163` — `@reparentable public protocol BorrowingSequence<Element>: ~Copyable, ~Escapable`. `Verified: 2026-05-26`.
- `BorrowingSequence.swift:173-228` — the `BorrowingIteratorAdapter` bridge + the "Eliminate … once Sequence is reparented" FIXME (separation, not fold). `Verified: 2026-05-26`.
- `Sequence.swift` — `public protocol IteratorProtocol<Element>` with bare `associatedtype Element` + `mutating func next() -> Element?` (unchanged scalar protocol). `Verified: 2026-05-26`.

### Swift Evolution (statuses from `swift-evolution` proposal headers, `Verified: 2026-05-26`)
- [SE-0447: Span — Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) — **Implemented (Swift 6.2)**. Source of `Element: ~Copyable` (no `~Escapable`).
- [SE-0516: Borrowing Sequence](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md) — **Returned for revision**. Separate bulk protocol; *Alternatives Considered* → "Basing `~Copyable` iteration on `IteratorProtocol`" rejects the scalar/folded design.
- [SE-0446: Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md) — **Implemented (Swift 6.2)**.
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) — **Implemented (Swift 6.0)**.
- [SE-0437: Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) — **Implemented (Swift 6.0)**.
- [SE-0465: Nonescapable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md) — **Implemented (Swift 6.2)**.
- [SE-0503: Suppressed Associated Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md) — **Accepted**. Enables `associatedtype Element: ~Copyable` in user protocols.
- [SE-0507: Borrow and Mutate Accessors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md) — **Implemented (Swift 6.4)** (gated out of production ≤ 6.3.2 per institute findings).

### Swift Forums (`Verified: 2026-05-26`)
- [[Returned for revision] SE-0516: Borrowing Sequence](https://forums.swift.org/t/returned-for-revision-se-0516-borrowing-sequence/85846) — LSG concerns: future evolution / generalized `~Copyable` containers, API naming, throwing support (dated 2026-04-07).
- [[Revision/Pitch] `Iterable` (formerly `BorrowingSequence`)](https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834) — rename + three changes incl. the (unreconciled-with-`Span`) `Element: ~Copyable & ~Escapable` claim; "names … specifically chosen to not conflict with existing names on `Sequence`."
- [[Pitch] Borrowing Sequence](https://forums.swift.org/t/pitch-borrowing-sequence/84332) and [Michael Tsai — Swift Pitch: Borrowing Sequence](https://mjtsai.com/blog/2026/01/27/swift-pitch-borrowing-sequence/) — Ben Cohen's span-as-fundamental rationale ("advancing a pointer over a buffer").
- [Pitch: Introduce `for borrow` and `for inout`](https://forums.swift.org/t/pitch-introduce-for-borrow-and-for-inout-to-provide-non-copying-collection-iteration/62549) — language-level, index-based, scalar; older (2023-01-13); not an accepted resolution.

### Empirical input
- `/tmp/iter-bulk-spike/findings.md` (Apple Swift 6.3.2, `swiftlang-6.3.2.1.108`) — FOLD compiles + dispatches; mandatory caveat `Element: ~Copyable` (NOT `~Copyable & ~Escapable`) because `Span<Element>` requires `Element: Escapable`; verbatim error captured. Fallback shapes (b) `next(maximumCount:) -> Span` + `providesBulk`, (c) separate refining protocol — both compile + run.

### Internal prior art extended (not duplicated)
- `iterator-span-buffer-elimination.md` (DECISION, v5.0.0) — `nextSpan` bulk surface; zero-heap reducibility.
- `unified-iteration-design.md` (RECOMMENDATION, v1.2.1) — four traversal axes; the `Span` ceiling; scalar `Iterator.`Protocol`` admits `~Escapable` Element, bulk `Iterator.Chunk.`Protocol`` narrows to `Escapable`.
- `unified-iteration-design.md` (DRAFT, v0.10.0) — D-2 RETIRE the bulk-span borrowing protocol; bulk = `Memory.Contiguous` property.
- `collection-sequence-protocol-detachment.md` (DECISION, v1.1.0) — `Sequence.Borrowing.Protocol` reframed as chunked-span optimization over `Memory.Contiguous.Protocol`; "nobody chunks" (all call sites `Cardinal(UInt.max)`).
- `HANDOFF-data-structure-iteration-arc.md` — bulk-tier placement/naming decisions (the bulk manner `Iterator.Chunk` on `Memory.Contiguous`; the memory bridge vends `Iterator.Chunk` over the `Memory.Contiguous` subject).
