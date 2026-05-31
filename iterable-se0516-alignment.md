# Iterable ↔ SE-0516 Alignment — the Span-Primitive Realignment

<!--
---
version: 1.0.0
last_updated: 2026-05-30
status: RECOMMENDATION
tier: 2
scope: cross-package
builds_on:
  - "bulk-span-iteration-fold-vs-separate.md (Tier 3, RECOMMENDATION) — the SEPARATE-vs-FOLD survey; the Span<~Copyable> crux verified against the local swiftlang/swift clone"
  - "unified-iteration-design.md (Tier 2, APPROVED v2.1.1) — the current single design authority for the iteration arc; this doc proposes a delta against §2.1/§2.3/§2.5/§3"
  - "Local stdlib clone in-flight SE-0516 source: swiftlang/swift/stdlib/public/core/BorrowingSequence.swift; Span/Span.swift"
changelog:
  - "1.0.0 (2026-05-30): Initial. Precise SE-0516 ↔ institute mapping; the aligned span-primitive Iterable design (institute-named); delta from current; Iterator.Borrow disposition."
---
-->

> **Status — RECOMMENDATION (delta RATIFIED by the principal 2026-05-30).** The principal directs that the
> institute `Iterable` be kept as close as possible to SE-0516 "Iterable (formerly BorrowingSequence)", matching
> institute patterns. This doc produces the mapping, the aligned design, the delta, and the explicit
> `Iterator.Borrow` disposition. **The proposed delta to the APPROVED `unified-iteration-design.md` was RATIFIED
> by the principal (user) on 2026-05-30; `unified-iteration-design.md` v2.2.0 now reflects the span-primitive
> shape (§2.1/§2.3/§2.5/§3/§6 re-aligned; §2.5 Option C superseded; `Iterator.Borrow` parked).** This doc
> remains the durable WHY + SE-0516 mapping; it still does **not** itself authorize code changes — a
> verify-plan agent re-verifies the realignment + assesses ground-state + produces the implementation plan,
> and the implementation is per-action gated.

## Context

**Trigger** ([RES-001] — architecture choice + framing realignment). The institute's `Iterable` was
designed **scalar-primitive** (its iterator is the move-out `Iterator.`Protocol`.next() -> Element?`),
with bulk/span as a *separate* refinement (`Iterator.Chunk.`Protocol``) and `~Copyable` pull-style
shunted onto a *third* protocol (`Iterator.Borrow.`Protocol`` / `Iterator.Borrow.Scalar`,
`swift-iterator-borrow-primitives`, commits `f31ce11`/`dd60699`). SE-0516 took the opposite shape:
**span-primitive** — the iterator's *sole* element-access requirement is
`nextSpan(maximumCount:) -> Span<Element>`, with **no scalar `next()`**, and `Span<Element: ~Copyable>`
makes one span-iterator serve **both** element kinds.

The principal's directive forces a re-examination of a decision the prior survey
(`bulk-span-iteration-fold-vs-separate.md`, Tier 3) reached: that survey recommended **SEPARATE**
(scalar protocol permissive + bulk refinement narrowed), corroborated by the stdlib's own
`IteratorProtocol` + `BorrowingIteratorProtocol` split. That recommendation answered a *different*
question ("fold the bulk hook onto the *existing scalar* `Iterator.`Protocol``?") — and its load-bearing
reason was preserving **`~Escapable`-element** scalar iteration. The principal's directive is narrower
and orthogonal: make **`Iterable`'s** iterator span-primitive (à la SE-0516), which does **not** fold
anything onto the permissive scalar protocol and does **not** sacrifice `~Escapable`-element scalar
iteration (that stays on `Iterator.`Protocol`` / `Sequenceable`, untouched). §4 below reconciles the
two so the prior Tier-3 recommendation is *narrowed*, not contradicted.

**Constraint** — this is research/design only. No package touched, no code changed, no other doc
edited. Every load-bearing claim cites SE-0516 (the in-flight stdlib clone + the revision pitch) or
disk `file:line`. Unverified items are tagged `(forum-pitch, unverified)`.

**Volatility** — SE-0516 is **Returned for Revision** (LSG, 2026-04-07; the revision pitch is dated
May 2026). We are tracking a moving proposal; §7 records the risk.

---

## 1. Mapping table: SE-0516 ↔ institute

Verified against the local clone `swiftlang/swift/stdlib/public/core/BorrowingSequence.swift`
(`Verified: 2026-05-30`, file present, 8164 bytes) and the institute disk shape.

| SE-0516 concept | SE-0516 shape (stdlib clone / revision pitch) | Institute concept (current) | Already matches? |
|---|---|---|---|
| `Iterable<Element, Failure>: ~Copyable, ~Escapable` (revision) / `BorrowingSequence<Element>: ~Copyable, ~Escapable` (clone) | `associatedtype Element: ~Copyable`; assoc iterator `: …IteratorProtocol & ~Copyable & ~Escapable`; `@lifetime(borrow self) func makeBorrowingIterator()` (`BorrowingSequence.swift:143-163`) | `protocol Iterable: ~Copyable, ~Escapable { associatedtype Iterator: Iterator.`Protocol`, ~Copyable, ~Escapable; @_lifetime(borrow self) borrowing func makeIterator() }` (`Iterable.swift:33-57`) | **Container shape MATCHES** — `~Copyable & ~Escapable`, `@_lifetime(borrow self)`, suppressed iterator. **Diverges:** institute has no top-level `Element` PAT (it flows through `Iterator.Element`); institute has no `underestimatedCount`/`_customContainsEquatableElement`. |
| `IterableIteratorProtocol` / `BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable` | `associatedtype Element: ~Copyable`; **primitive** `@_lifetime(&self) mutating func nextSpan(maximumCount: Int) throws(Failure) -> Span<Element>` (clone `:15-58`, infallible; revision adds `throws(Failure)`); `skip(by:)`; **NO scalar `next()`** | `__IteratorChunkProtocol<Element, Failure>: Iterator.`Protocol`, ~Copyable, ~Escapable where Element: Escapable`; `@_lifetime(&self) mutating func next(maximumCount:) throws(Failure) -> Span<Element>` (`__IteratorChunkProtocol.swift:34-46`) | **The span method MATCHES in shape** (`maximumCount` → `Span`, `@_lifetime(&self)`, typed `throws(Failure)`). **Diverges on TWO axes:** (a) institute `Iterator.Chunk` **refines** the scalar `Iterator.`Protocol`` (carries its `next()`); SE-0516's bulk protocol does **not** refine the scalar one. (b) institute narrows `Element: Escapable` (`:35`); SE-0516 admits `Element: ~Copyable` (`:16`) — **the central delta**, see §2. |
| `nextSpan(maximumCount:)` | sole element-access primitive; empty span = exhaustion | `Iterator.Chunk.next(maximumCount:)` (`Iterator.Chunk.swift:51-60`) — but **on `Iterable` the primitive is the scalar `next()`**, not this | The *method exists* and is shaped identically; the divergence is that the institute makes it a *secondary refinement*, not `Iterable`'s primitive. |
| `SpanIterator<Element: ~Copyable>` (clone `:99-140`) — the contiguous-storage bulk iterator | stores `Span<Element>` + start + count; `init(_ : Span<Element>)` `@_lifetime(copy elements)`; `nextSpan` extracts sub-spans | `Iterator.Chunk<Element>` (`Iterator.Chunk.swift:26-39`) — stores `Swift.Span<Element>` + `Cardinal` count + position; `init(_ : Span<Element>)` `@_lifetime(copy span)` | **MATCHES structurally** (span + position, sub-span extraction). **Diverges:** `Iterator.Chunk<Element>` has **no `~Copyable` element bound** on the struct, but its *conformance* via `__IteratorChunkProtocol` forces `Element: Escapable`; `SpanIterator` is `where Element: ~Copyable`. |
| `IterableIteratorAdapter` / `BorrowingIteratorAdapter<Iterator: IteratorProtocol>` (clone `:198-228`) — bridges `Sequence` | wraps `Iterator.next()`, materializes a one-element `Span` via `Optional._span()`; supplied by `@_disfavoredOverload makeBorrowingIterator()` on `Sequence where Self: BorrowingSequence` | The institute has **no adapter** — `Swift.Sequence` is a *separate* re-add target (`unified-iteration-design.md` §2.8) and `Sequenceable` is the consuming sibling | **DIVERGES — institute has no `Iterable`-from-`Iterator.`Protocol`` adapter.** The institute's orthogonality is achieved differently (see next row). |
| Orthogonality to `Sequence` (distinct `makeBorrowingIterator`/`BorrowingIterator` names so a type can conform to both) | dedicated names avoid the `makeIterator`/`Iterator` collision; reparenting deferred (`@reparentable` + FIXME `:173`) | `Iterable.makeIterator` vs `Sequenceable.makeIterator` collide on the shared `associatedtype Iterator`; the institute uses `@_implements(Protocol, Iterator)` to split a dual conformer (`Iterable.swift:28-32`, `Sequenceable.swift:24-26`) | **Same GOAL, different MECHANISM.** SE-0516 renames to avoid collision; the institute keeps the `makeIterator` name on both siblings and pays the `@_implements` cost per dual conformer. Both are "orthogonal, not a refinement chain." |

**Net:** the institute's *container* protocol (`Iterable`) already matches SE-0516's container almost
exactly. The institute's *span iterator* (`Iterator.Chunk` / `__IteratorChunkProtocol`) matches
SE-0516's `SpanIterator` / `BorrowingIteratorProtocol` **in shape** but differs on (1) what `Iterable`
uses as its *primitive* (scalar vs span) and (2) the element bound (`Escapable` vs `~Copyable`).

---

## 2. The core finding, verified: scalar-primitive vs span-primitive, and the false `Escapable` narrowing

**Claim (confirmed):** the institute `Iterable` is **scalar-primitive** and the institute bulk
iterator is **gratuitously `Escapable`-narrowed** relative to what `Span` actually requires.

- **Institute `Iterable`'s primitive is the scalar move-out `next()`.** `Iterable.makeIterator()`
  returns an `Iterator: Iterator.`Protocol`` (`Iterable.swift:45,56`); the scalar primitive is
  `mutating func next() throws(Failure) -> Element?` (`Iterator.Protocol.swift:46`). Every `Iterable`
  terminal (`forEach`, `first`, `contains`, `reduce`) drives that scalar `next()`
  (`Iterable+ForEach.swift:42`, `Iterable+First.swift:31`). Returning `Element?` by value is a
  **move-out**, which is why the terminal suite and the `Memory.Contiguous → Iterable` bridge are
  **Copyable-gated** (`Memory.Contiguous+Iterable.swift:28` — `Element: Copyable`;
  `Iterable+First.swift:10-11` — `Iterator.Element: Copyable & Escapable`). `[Verified: 2026-05-30]`

- **SE-0516 `Iterable`'s primitive is `nextSpan -> Span<Element>` — no scalar `next()` anywhere.**
  `BorrowingIteratorProtocol` (clone `:15-58`) has `nextSpan(maximumCount:) -> Span<Element>` as its
  **sole** element-access method; for-in over it desugars to a `nextSpan` loop with `span[i]` borrowing
  access (clone doc-comment `:44-49`; revision pitch §"for-in"). `[Verified: 2026-05-30]`

- **`Span` admits `~Copyable` (the decisive fact).** `public struct Span<Element: ~Copyable>:
  ~Escapable, Copyable, BitwiseCopyable` — `Span/Span.swift:29` `[Verified: 2026-05-30]`. So a
  `Span<Element>` carries move-only elements; `Span.subscript(_:) -> Element` is an **`unsafeAddress`
  addressor** (`Span/Span.swift:455-461`), i.e. it lends a *borrow* of the element rather than moving
  it out — exactly the access SE-0516's for-in uses. `BorrowingIteratorProtocol.Element: ~Copyable`
  (clone `:16`), and `SpanIterator<Element: ~Copyable>` (clone `:100-101`) confirm one span-iterator
  serves both kinds. `[Verified: 2026-05-30]`

- **The institute's `Iterator.Chunk` `Escapable` narrowing is STRICTER than `Span` requires.**
  `__IteratorChunkProtocol` constrains `where Element: Escapable` (`__IteratorChunkProtocol.swift:35`)
  with the rationale "`Span<Element>` requires escapable elements (there is no `Span<some ~Escapable>`)"
  (`:27-30`). That rationale **conflates `~Copyable` with `~Escapable`.** `Span` requires
  `Element: ~Copyable`-OK, `~Escapable`-NOT. `~Copyable` is fine; only `~Escapable` is excluded. The
  `Escapable` bound therefore **over-narrows** — it excludes the `~Copyable & Escapable` elements that
  `Span` accepts and that SE-0516's bulk iterator carries. The earlier survey
  (`bulk-span-iteration-fold-vs-separate.md` §1) correctly identified the `Span` ceiling as `~Escapable`
  but the institute *disk* narrowed all the way to `Escapable` (excluding `~Copyable`), which is the gap
  this realignment closes. `[Verified: 2026-05-30 against __IteratorChunkProtocol.swift:35 + Span.swift:29]`

- **`Iterator.Chunk` the *struct* is already kind-agnostic.** `Iterator.Chunk<Element>` (struct,
  `Iterator.Chunk.swift:26`) declares **no** `Element: Escapable` bound; it stores
  `Swift.Span<Element>` (`:27`). Only its *conformance* to `__IteratorChunkProtocol` (`:45`) inherits the
  protocol's `Escapable` bound. So the bulk *iterator type* needs no structural change to serve
  `~Copyable` — only the protocol bound it conforms to must relax from `Escapable` to `~Copyable`.
  `[Verified: 2026-05-30]`

**Conclusion of §2:** the institute already *has* the span-primitive machinery
(`Iterator.Chunk`/`__IteratorChunkProtocol`, structurally identical to `SpanIterator`/
`BorrowingIteratorProtocol`); it merely (a) does not make it `Iterable`'s **primitive** (the scalar
`next()` is), and (b) **over-narrows** its element bound to `Escapable` when `~Copyable` is the correct
ceiling. Aligning to SE-0516 is therefore a **re-pointing + bound-relaxation**, not new invention.

---

## 3. The aligned `Iterable` design (institute-pattern, span-primitive)

The aligned shape makes the **span iterator the primitive** of `Iterable`, keeping institute Nest.Name
conventions, typed throws, the lifetime annotations, and the `~Copyable`/`~Escapable` suppression. The
SE-0516 names map to existing institute names — **no SE-0516 literal names are introduced**.

### 3.1 Name mapping (institute keeps its names)

| SE-0516 | Institute (aligned) | Note |
|---|---|---|
| `IterableIteratorProtocol` / `BorrowingIteratorProtocol` | `Iterator.Chunk.`Protocol`` (the alias) / `__IteratorChunkProtocol` (hoisted) | The bulk span iterator protocol IS the institute's `IterableIteratorProtocol` analog. Already exists. |
| `nextSpan(maximumCount:)` | `Iterator.Chunk.next(maximumCount:)` | `next(maximumCount:)` is the institute's `nextSpan`. The bare `next()` name is the institute's scalar overload — distinguished by argument label, consistent with [API-NAME-002] nested accessors. Already exists. |
| `SpanIterator<Element: ~Copyable>` | `Iterator.Chunk<Element>` | Already exists; relax its conformance bound (§2). |
| `IterableIteratorAdapter` (`Sequence` bridge) | `Iterator.Chunk` over a one-element span, OR the existing `Swift.Sequence` re-add path | See §4 / §6. |
| `makeBorrowingIterator()` | `Iterable.makeIterator()` | Keep the institute name; `@_implements` resolves the dual-conformer collision (already live). |

### 3.2 The aligned protocols (institute-named)

```swift
// swift-iterator-primitives — UNCHANGED container; this already matches SE-0516.
public protocol Iterable: ~Copyable, ~Escapable {
    // ALIGNED: the associated iterator is now the SPAN-primitive bulk protocol,
    // not the scalar Iterator.`Protocol`. (Was: Iterator: Iterator.`Protocol`.)
    associatedtype Iterator: __IteratorChunkProtocol, ~Copyable, ~Escapable
    @_lifetime(borrow self)
    borrowing func makeIterator() -> Iterator
}

// swift-iterator-primitives — the span-primitive iterator protocol (the SE-0516
// IterableIteratorProtocol analog). RELAXED Element bound: Escapable → ~Copyable.
public protocol __IteratorChunkProtocol<Element, Failure>: ~Copyable, ~Escapable
where Element: ~Copyable {                                   // ◄ was: Element: Escapable
    associatedtype Element: ~Copyable                        // ◄ SE-0516 BorrowingIteratorProtocol:16
    associatedtype Failure: Swift.Error = Never
    @_lifetime(&self)
    mutating func next(
        maximumCount: some Carrier.`Protocol`<Cardinal>
    ) throws(Failure) -> Span<Element>                       // ◄ the SE-0516 nextSpan; Span<~Copyable> OK
    @_lifetime(&self)
    mutating func skip(by maximumOffset: Int) throws(Failure) -> Int   // ◄ ADD (SE-0516 skip(by:))
}
```

Critical institute-pattern preservations:
- **Typed throws** ([API-ERR-001]): `throws(Failure)`, `Failure: Swift.Error = Never`. SE-0516's clone
  is infallible; the *revision pitch* adds `Failure` — the institute already has it (it is ahead of the
  clone on this axis, aligned with the revision pitch). `[Verified: 2026-05-30 — __IteratorChunkProtocol already carries Failure]`
- **`~Copyable`/`~Escapable` suppression** on both protocol and iterator — already present.
- **`@_lifetime(&self)`** on `next(maximumCount:)` — already present; matches SE-0516 `nextSpan`.
- **Nest.Name** ([API-NAME-001]): `Iterator.Chunk.`Protocol``, `Iterator.Chunk` — kept; no `SpanIterator`/
  `BorrowingIteratorProtocol` literal names.
- **`maximumCount: some Carrier.`Protocol`<Cardinal>`** — the institute's count-parameter idiom is
  *richer* than SE-0516's bare `Int`; this is a justified institute divergence (§7).

### 3.3 The key structural consequence: ONE iterator serves BOTH element kinds

Because `Span<Element: ~Copyable>` and `Iterator.Chunk<Element>` (no `Escapable` bound on the struct)
both carry `~Copyable`, the **single** `Iterator.Chunk` conformance serves Copyable and `~Copyable`
elements alike. The scalar move-out (`next() -> Element?`) — the thing that forced Copyable-gating — is
**no longer `Iterable`'s primitive**. For-in / `forEach` desugar to the span loop with `span[i]`
borrowing access (`Span.subscript` is an `unsafeAddress` addressor, §2), so move-only elements are
**borrowed, never moved out**. This is precisely SE-0516's model and it dissolves the institute's
Copyable-gate on `Iterable`.

### 3.4 Where the scalar `Iterator.`Protocol`` and `Sequenceable` go (orthogonal, untouched)

- `Iterator.`Protocol`` (scalar `next() -> Element?`, `Element: ~Copyable & ~Escapable`) **stays** —
  it is the *consuming/give-away* iterator and the foundation for `Sequenceable` (consuming
  `makeIterator`). It is **NOT** `Iterable`'s iterator anymore. This is the institute's World-A
  (give-away) vs World-B (keep-and-lend) duality (`unified-iteration-design.md` §6.1) made cleaner:
  `Iterable` = World-B = span-primitive; `Sequenceable` = World-A = scalar-primitive.
- `Sequenceable` (`swift-sequence-primitives`) is the **consuming sibling**, orthogonal, not refining
  `Iterable` — exactly as SE-0516 keeps `Sequence` orthogonal to `Iterable` (`Sequenceable.swift:17-26`).
  The `IterableIteratorAdapter` analog (a `Sequence`→`Iterable` bridge) is the institute's `Swift.Sequence`
  re-add path (§6); SE-0516's adapter materializes one-element spans, which the institute can mirror
  with `Iterator.Chunk` over a one-element span if a direct `Iterator.`Protocol`→Iterable` bridge is
  wanted.

### 3.5 `~Escapable`-element iteration — the ONE thing the span model cannot carry

`Span` excludes `~Escapable` elements (`Span.swift:29`). So the span-primitive `Iterable` **cannot**
carry a genuinely `~Escapable` element (a view into iterator-owned storage). This is the institute's
documented language-blocked ceiling (`bulk-span-iteration-fold-vs-separate.md` §1; SE-0516 hits the
identical wall). For `~Escapable`-*element* iteration the institute retains the scalar
`Iterator.`Protocol`` (which declares `Element: ~Copyable & ~Escapable`) and `Sequenceable`'s borrowing
terminals. **This is the same conclusion the prior Tier-3 survey reached** — it is *preserved*, not
overturned: `~Escapable`-element iteration lives on the scalar protocol; the principal's directive only
re-points **`Iterable`** to span-primitive, leaving the scalar protocol's `~Escapable` capability intact
on its own protocol. §4 reconciles.

---

## 4. forEach reconciliation

SE-0516 has **no `forEach` requirement** — it relies on for-in over `nextSpan`. The institute relocated
a `forEach` terminal *onto* `Iterable` as the universal floor (`unified-iteration-design.md` §2.1;
`Iterable+ForEach.swift`).

**Recommendation: keep the `forEach` terminal suite, but rebuild it on the span primitive** (an
extension over the span loop), not the scalar `next()`:

```swift
extension Iterable where Self: ~Copyable & ~Escapable, Iterator.Failure == Never {
    @inlinable
    public borrowing func forEach<E: Swift.Error>(
        _ body: (borrowing Iterator.Element) throws(E) -> Void
    ) throws(E) {
        var iterator = makeIterator()
        while true {
            let span = iterator.next(maximumCount: Cardinal(UInt.max))   // ◄ nextSpan
            if span.isEmpty { break }
            for i in span.indices { try body(span[i]) }                  // ◄ borrowing span[i]
        }
    }
}
```

Why this shape:
- It works for **both** element kinds: `span[i]` is a borrow (`unsafeAddress` addressor), so
  `(borrowing Iterator.Element)` carries `~Copyable` natively — **no Copyable gate**. The current
  `Iterable+ForEach.swift:42` drives the scalar `next()` and is Copyable-gated via the bridge; the span
  loop removes that gate at the floor.
- It **subsumes** the bespoke `Memory.Contiguous+Iterable.swift:55-67` span-lending `forEach` (which
  already does exactly `for span; for i { body(span[i]) }`) — that bespoke floor becomes the *general*
  `Iterable.forEach` once `Iterable`'s primitive is the span. The duplication dissolves.
- `contains`/`first`/`reduce`/`allSatisfy` continue to **compose from `forEach`** (or directly from the
  span loop). `first`/`reduce` that *return an element by value* keep their `Iterator.Element: Copyable &
  Escapable` gate (`Iterable+First.swift:10-11`) — that gate is intrinsic to *extracting* an element past
  the borrow, NOT to iteration; it is correct and unchanged.
- The fallible overload (fusing closure `E` + `Iterator.Failure` into `Either`,
  `Iterable+ForEach.swift:50-81`) is preserved verbatim, driving the span loop instead of scalar `next()`.

So: **keep the terminal suite; build it on the span primitive.** The terminals are an institute value-add
SE-0516 lacks (SE-0516 relies on raw for-in); keeping them is a justified, additive divergence.

---

## 5. Disposition of `Iterator.Borrow` / `Ownership.Borrow` / `Iterator.Borrow.Scalar`

### 5.1 The finding: `Iterator.Borrow` is UNNECESSARY for iteration under the span model

`Iterator.Borrow.`Protocol`` + `Iterator.Borrow.Scalar` exist **solely** to give `~Copyable`
*scalar* pull-style iteration without moving the element out — by wrapping each element in a
`Copyable & ~Escapable` `Ownership.Borrow<Borrowed>` handle and yielding it from a scalar `next() ->
Ownership.Borrow<Borrowed>?` (`Iterator.Borrow.Scalar.swift:106-111`;
`Iterator.Borrow.Protocol.swift:69-70`). The entire reason for the wrapper is that the **scalar**
`next()` would otherwise move-out a `~Copyable` element (the A4 SILGen wall,
`unified-iteration-design.md` §6.2).

Under the **span-primitive** `Iterable`:
- `~Copyable` iteration goes through `nextSpan -> Span<Element>` + `span[i]` borrowing access. The
  element is **borrowed via the `Span` addressor**, never moved out, **without** an `Ownership.Borrow`
  wrapper. The `Span` *itself* is the keep-and-lend mechanism.
- This is **exactly why SE-0516 explicitly rejected** the wrapper approach: its *Alternatives Considered*
  ("Basing `~Copyable` iteration on `IteratorProtocol`" with a `Borrow<Element>`-returning `next()`) was
  rejected because "the different element types used in this alternative design lead to awkward usage at
  the call site" — users would write predicates over `(borrowing Borrow<NoncopyableInt>)` instead of the
  element type. (`bulk-span-iteration-fold-vs-separate.md` §3, quoting SE-0516, `Verified: 2026-05-26`.)
  `Iterator.Borrow.Scalar`'s `Element == Ownership.Borrow<Borrowed>` is **precisely the rejected design.**

So under the aligned shape, the `~Copyable` pull-style that `Iterator.Borrow` provides is **subsumed by
the span iterator** — one `Iterator.Chunk` conformance covers `~Copyable` (§3.3), and `forEach` over the
span covers internal iteration (§4). `Iterator.Borrow` is **not needed for iteration.**

### 5.2 Concrete disposition recommendation: PARK, do not (yet) revert `f31ce11`/`dd60699`

Per [ARCH-LAYER-009] (no package/source removal during pre-1.0) and [ARCH-LAYER-006] (domain
completeness, not consumer count, determines existence), the recommendation is **nuanced, not a blunt
revert**:

| Question | Disposition |
|---|---|
| Is `Iterator.Borrow` needed for **iteration** under the aligned shape? | **NO** — the span iterator covers `~Copyable` iteration (§3.3, §5.1). |
| Should `Set.Ordered` / buffers vend `Iterator.Borrow.Scalar` for their `~Copyable` `Iterable` (per `unified-iteration-design.md` §2.5 Option C)? | **NO** — that plan is **superseded** by this realignment. They vend `Iterator.Chunk` over their `span` instead (§6). The `unified-iteration-design.md` §2.5 keystone is the thing this doc changes. |
| Revert commits `f31ce11` (Scalar) / `dd60699` (owner-anchored init)? | **PARK, do not delete.** `Iterator.Borrow.`Protocol`` names a *legitimate composition* (`Iterator.`Protocol` ∘ Ownership.Borrow`) that may serve a NON-iteration purpose: a **scalar keep-and-lend cursor** for callers that genuinely want pull-style `next()` over `~Copyable` with cheap early-exit / `peek` / `zip` (the affordances a span `forEach` lacks). Whether any consumer needs that is a separate question; pre-1.0 we keep the source on disk. Mark the *iteration role* withdrawn; leave the package intact. [ARCH-LAYER-009] forbids deletion during pre-1.0 regardless. |
| Is `Ownership.Borrow` itself affected? | **NO** — `Ownership.Borrow<Value>` (`swift-ownership-primitives`) is a general borrow handle with uses far beyond iteration; untouched. |

**Bottom line for the principal:** `Iterator.Borrow.Scalar`'s **iteration** role becomes unnecessary
under the span model — do **not** route `Iterable`'s `~Copyable` path through it (reversing
`unified-iteration-design.md` §2.5 Option C). Do **not** revert/delete `f31ce11`/`dd60699` during pre-1.0
([ARCH-LAYER-009]); park the package with its iteration role withdrawn and re-evaluate at 1.0 readiness
against whether a scalar `~Copyable` keep-and-lend *cursor* (a non-iteration affordance) has a consumer.

---

## 6. Buffer + Set.Ordered resolution under the aligned shape

**Current disk state (the dual-element-kind split, verified):**

| Conformance | Set.Ordered current | Source |
|---|---|---|
| `Memory.Contiguous.`Protocol`` (`var span`) | `where Element: ~Copyable` ✓ | `Set.Ordered+Memory.Contiguous.Protocol.swift:28`; `Set.Ordered+Iteration.swift:27-35` |
| `Iterable` (vends `Iterator.Chunk`) | `where Element: Copyable` (the move-out gate, via the bridge) | `Memory.Contiguous+Iterable.swift:28`; `unified-iteration-design.md` §1.1 |
| `Sequenceable.makeIterator()` (consuming) | `where Element: Copyable` | `Set.Ordered+Iteration.swift:37-44` |
| `forEach` (`~Copyable`) | bespoke per-variant `(borrowing Element)` + the `Memory.Contiguous` span-lending floor | `Memory.Contiguous+Iterable.swift:55-67` |

**Under the aligned shape:** the dual-conformer / element-kind split **dissolves** for `Iterable`:

1. The **memory→Iterable bridge relaxes from `Element: Copyable` to `Element: ~Copyable`.** The bridge
   (`Memory.Contiguous+Iterable.swift:28,75`) currently vends `Iterator.Chunk` only for `Element:
   Copyable` because `Iterator.Chunk`'s *conformance* was `Escapable`-narrowed. Once
   `__IteratorChunkProtocol` admits `Element: ~Copyable` (§3.2) and `Span<~Copyable>` is the carrier
   (§2), the bridge vends `Iterator.Chunk(span)` for **`Element: ~Copyable`** — `Memory.Contiguous.span`
   is **already** `~Copyable`-capable (`Memory.ContiguousProtocol.swift:90-101`,
   `associatedtype Element: ~Copyable`; `Set.Ordered.span` is `where Element: ~Copyable`,
   `Set.Ordered+Iteration.swift:27`). `[Verified: 2026-05-30]`

2. **ONE span-iterator conformance covers both kinds.** `Set.Ordered: Iterable` (and every
   `Buffer.Linear` variant) gets its `Iterable` conformance vended by the bridge over `span`, **relaxed
   to `~Copyable`** — a single conformance, no Copyable/`~Copyable` fork, no `@_implements` split *for
   `Iterable`* (the dual-conformer split with `Sequenceable` persists, because `Sequenceable` is the
   orthogonal consuming sibling that still uses the scalar `Iterator.`Protocol``).

3. **The `forEach` floor is inherited from the general span `forEach`** (§4), subsuming the bespoke
   `Memory.Contiguous` span-lending floor (`Memory.Contiguous+Iterable.swift:55-67`) and the per-variant
   hand-written `forEach`.

4. **`Iterator.Borrow.Scalar` is NOT vended** (reversing `unified-iteration-design.md` §2.5 Option C, §5
   above). The buffer does not need to expose its storage base, build an `Iterator.Borrow.Scalar`, or
   conform `Storage.Protocol` — it just exposes `span` (which it already does) and the bridge does the
   rest. This is **simpler** than Option C: no escaping `pointer(at:)`, no owner-anchored init, no
   `@_rawLayout` inline-storage soundness gate (`unified-iteration-design.md` §2.5 "Remaining
   build-verify").

**One open soundness item to verify (not assumed):** the bridge's `Iterator.Chunk(span)` for `~Copyable`
elements over **inline / `@_rawLayout` storage** must be lifetime-sound — the `Span` is `@_lifetime(borrow
self)` and `Iterator.Chunk` is `@_lifetime(copy span)`, so the chain ties the iterator to the container
borrow. `unified-iteration-design.md` §2.5 already proved (debug+release) that driving a borrow iterator
over real `@_rawLayout Storage.Inline` is multipass-sound; the span path is *weaker* (it borrows through
the safe `span` view, never an escaping base), so it should be **at least as sound**. **Tag this a
build-verify gate**, not a settled claim (`[RES-021]`/`[RES-027]`: a verification spike confirming
`Iterator.Chunk(span)` over the inline `Set.Ordered.Static`/`.Small` variants compiles + iterates
`~Copyable` correctly in debug+release should gate the DECISION).

---

## 7. Delta + risks

### 7.1 Concrete change-list (to align)

| # | Change | File(s) | Risk |
|---|---|---|---|
| D1 | Relax `__IteratorChunkProtocol`'s element bound `Escapable → ~Copyable`; add `skip(by:)` | `__IteratorChunkProtocol.swift:34-46` | Low — `Iterator.Chunk` struct already has no `Escapable` bound; relaxation widens admissibility. Verify `Span` ops used (`extracting`) stay valid for `~Copyable` (they do — `Span<~Copyable>` has `extracting`). |
| D2 | Re-point `Iterable.Iterator` from `Iterator.`Protocol`` (scalar) to `__IteratorChunkProtocol` (span) | `Iterable.swift:45` | **Highest blast radius** — every `Iterable` conformer's `makeIterator()` must now return a span iterator (`Iterator.Chunk`), not a scalar one. Bridge-vended conformers (memory) get this for free; hand-rolled scalar `Iterable` conformers must migrate. **Enumerate workspace-wide before landing.** |
| D3 | Rebuild `Iterable.forEach` (+ fallible) on the span loop | `Iterable+ForEach.swift` | Low — same signature, different body; subsumes the bespoke `Memory.Contiguous` floor. |
| D4 | Relax the memory→Iterable bridge `Element: Copyable → ~Copyable`; delete the bespoke span `forEach` (now general) | `Memory.Contiguous+Iterable.swift:28,55-67,75` | Low-medium — dissolves the Copyable gate; verify no ambiguity with the general `forEach`. |
| D5 | `Set.Ordered: Iterable` collapses to one `~Copyable` conformance via the bridge; drop the Copyable gate | `swift-set-ordered-primitives` (ops module) | Medium — the exemplar; gate per `unified-iteration-design.md` reference-rework discipline. |
| D6 | Withdraw `Iterator.Borrow.Scalar`'s iteration role; do NOT vend it; do NOT delete the package | `swift-iterator-borrow-primitives` (no code change — park) | Low — reverses `unified-iteration-design.md` §2.5 Option C as the *plan*; no deletion ([ARCH-LAYER-009]). |
| D7 | Amend `unified-iteration-design.md` §2.1/§2.3/§2.5/§3 to the span-primitive shape | `unified-iteration-design.md` (separate doc edit, principal-ratified) | **This doc proposes; principal ratifies.** §2.5 Option C keystone is replaced. |
| D8 | (optional) `IterableIteratorAdapter` analog: a `Sequence`/`Iterator.`Protocol`→Iterable` bridge via one-element `Iterator.Chunk` spans | new, swift-iterator-primitives | Low — additive; only if a scalar→Iterable bridge is wanted (SE-0516 has one). |

### 7.2 Blast radius

- **Conformers:** every `Iterable` conformer (D2). The bridge-vended ones (anything `Memory.Contiguous`
  — buffers, Set.Ordered, storage-backed containers) migrate **for free** via D4. Hand-rolled scalar
  `Iterable` conformers (if any outside the memory family) must switch to a span iterator. Enumerate via
  `grep -rl ": Iterable" swift-primitives/*/Sources` before landing ([RES-023] — run at execution time,
  not assumed here).
- **Consumers:** `Iterable.forEach`/`first`/`contains`/`reduce` call sites are **source-stable** (same
  signatures, §4). For-in is not currently wired to `Iterable` (the institute uses `forEach`,
  `Sequenceable.swift:86`), so there is no for-in desugaring to migrate.
- **`Collection.`Protocol`: Iterable` (the deferred fan-out refinement, `unified-iteration-design.md`
  §2.2) inherits the span primitive — fine, a collection projects a span.

### 7.3 Where the institute MUST diverge from SE-0516 (justified)

1. **Keep the `forEach` terminal suite** (§4). SE-0516 has none. Justified: institute value-add;
   built on the span primitive; carries both kinds.
2. **`maximumCount: some Carrier.`Protocol`<Cardinal>`** not bare `Int` (§3.2). Justified: institute's
   typed count-parameter idiom ([API-NAME-001b], the Cardinal carrier convention). A bare `Int` would
   violate institute typed-arithmetic conventions.
3. **Keep `Iterator.Borrow.`Protocol`` parked** (not deleted), even though SE-0516 has no analog and
   rejected the wrapper for iteration (§5). Justified: [ARCH-LAYER-009] (no pre-1.0 deletion) +
   potential non-iteration cursor role.
4. **`@_implements`-based orthogonality** vs SE-0516's distinct-names orthogonality (§1 last row).
   Justified: the institute keeps the `makeIterator` name on both siblings (`Iterable`/`Sequenceable`)
   for call-site uniformity; the `@_implements` cost is per dual conformer and already paid.
5. **Typed throws `Failure`** — the institute is *ahead* of the shipped clone (which is infallible) and
   aligned with the revision pitch; this is convergence, not divergence ([API-ERR-001]).

### 7.4 SE-0516 volatility risk

SE-0516 is **Returned for Revision** (LSG 2026-04-07; revision pitch May 2026). We are tracking a moving
proposal:
- The revision pitch's claim that `Iterable.Element` may be `~Copyable & ~Escapable` is, per the prior
  Tier-3 survey, an **unreconciled aspiration** — its only element-access method still returns
  `Span<Element>` which requires `Escapable` (`bulk-span-iteration-fold-vs-separate.md` §4,
  `(forum-pitch, unverified)`). **The institute should align to `Element: ~Copyable`** (the *shipped*
  clone bound, `BorrowingSequence.swift:16`), NOT the pitch's `~Copyable & ~Escapable` aspiration — and
  keep `~Escapable`-element iteration on the scalar `Iterator.`Protocol`` (§3.5). If the language later
  ships a `~Escapable`-element span mechanism, revisit.
- The LSG's return reasons were **scope, naming, throwing-support** — NOT the span-primitive / separate-
  protocol architecture (which was not sent back). The span-primitive shape is the stable core; the
  *names* (`BorrowingSequence` → `Iterable`) are in flux — but the institute uses its own names
  (`Iterable`, `Iterator.Chunk`), so naming churn upstream does not destabilize the institute surface.
- **Mitigation:** align to the verified *shipped-clone* shape (span-primitive, `Element: ~Copyable`,
  typed-throws-ready), treat the revision pitch's relaxations as aspirational, and re-verify against the
  clone on each SE-0516 status change. The institute's name independence is the chief insulation.

---

## 8. Outcome

**Status: RECOMMENDATION.** The institute `Iterable` can — and per the principal's directive, should —
be realigned to SE-0516's **span-primitive** shape with **minimal, mostly-relaxation** changes, because
the institute already ships the structural machinery (`Iterator.Chunk` ≅ `SpanIterator`,
`__IteratorChunkProtocol` ≅ `BorrowingIteratorProtocol`). The two substantive changes are: (1) **re-point
`Iterable`'s iterator** from the scalar `Iterator.`Protocol`` to the span `__IteratorChunkProtocol` (D2),
and (2) **relax that span protocol's element bound** from the over-narrow `Escapable` to the correct
`~Copyable` (D1) — which `Span` has always permitted (`Span.swift:29`). This makes **one span-iterator
serve both element kinds**, dissolves the Copyable-gate on `Iterable`, dissolves the dual-conformer /
element-kind split on buffers + `Set.Ordered`, and makes **`Iterator.Borrow.Scalar` unnecessary for
iteration** (SE-0516 explicitly rejected its element-wrapping design for exactly the call-site-ergonomics
reason). `Iterator.Borrow` is **parked, not reverted** ([ARCH-LAYER-009]); its iteration role is
withdrawn but the package stays on disk for a possible non-iteration cursor role.

**This RECOMMENDATION proposes a delta to the APPROVED `unified-iteration-design.md` (§2.1/§2.3/§2.5/§3)
— specifically replacing its §2.5 Option C keystone (`~Copyable` borrow-iteration over Storage+Buffer
via `Iterator.Borrow.Scalar`) with the span-primitive shape.** That doc is the locked authority; the
principal must ratify this delta before any execution. One soundness item (`Iterator.Chunk(span)` over
inline `@_rawLayout` storage for `~Copyable`) is flagged as a build-verify gate ([RES-021]/[RES-027]),
not a settled claim.

## 9. References

### SE-0516 primary sources (`Verified: 2026-05-30` against the local clone)
- `swiftlang/swift/stdlib/public/core/BorrowingSequence.swift:15-58` — `BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable`, `associatedtype Element: ~Copyable`, `nextSpan(maximumCount:) -> Span<Element>`, no scalar `next()`.
- `BorrowingSequence.swift:99-140` — `SpanIterator<Element: ~Copyable>`.
- `BorrowingSequence.swift:143-163` — `@reparentable BorrowingSequence<Element>: ~Copyable, ~Escapable`; `@lifetime(borrow self) makeBorrowingIterator()`.
- `BorrowingSequence.swift:196-228` — `BorrowingIteratorAdapter` + the `@_disfavoredOverload` `Sequence` bridge + the reparenting FIXME.
- `swiftlang/swift/stdlib/public/core/Span/Span.swift:29` — `public struct Span<Element: ~Copyable>: ~Escapable, …` (the `~Copyable`-yes/`~Escapable`-no crux).
- `Span/Span.swift:455-461` — `Span.subscript(_:) -> Element` via `unsafeAddress` addressor (borrowing access, no move-out).
- [SE-0516 revision pitch — `Iterable` (formerly `BorrowingSequence`)](https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834) — rename + typed-throws `Failure` + `Element: ~Copyable & ~Escapable` (the unreconciled-with-`Span` aspiration). Status: **Returned for Revision (May 2026)**.

### Institute disk sources (`Verified: 2026-05-30`)
- `swift-iterator-primitives/Sources/Iterable/Iterable.swift:33-57` — `Iterable` container (scalar-iterator primitive currently).
- `.../Iterator Protocol/Iterator.Protocol.swift:31-47` — scalar `Iterator.`Protocol`.next() -> Element?`, `Element: ~Copyable & ~Escapable`.
- `.../Iterator Chunk Primitives/__IteratorChunkProtocol.swift:34-46` — span protocol, `where Element: Escapable` (the over-narrow bound).
- `.../Iterator Chunk Primitives/Iterator.Chunk.swift:26-61` — `Iterator.Chunk<Element>` struct (no `Escapable` bound) storing `Swift.Span<Element>`.
- `.../Iterable/Iterable+ForEach.swift:38-81` — the scalar-`next()`-driven `forEach` floor + fallible overload.
- `.../Iterable/Iterable+First.swift:9-31` — `first(where:)` with the extraction `Copyable & Escapable` gate.
- `swift-memory-iterator-primitives/.../Memory.Contiguous+Iterable.swift:28,55-67,75` — the bridge (`Element: Copyable` gate) + bespoke span `forEach`.
- `swift-memory-primitives/.../Memory.ContiguousProtocol.swift:90-101` — `var span: Span<Element>`, `Element: ~Copyable`.
- `swift-iterator-borrow-primitives/.../Iterator.Borrow.Protocol.swift:69-77`, `Iterator.Borrow.Scalar.swift:48-117` — the parked scalar-borrow iterator (`Element == Ownership.Borrow<Borrowed>`); commits `f31ce11`/`dd60699`.
- `swift-sequence-primitives/.../Sequenceable.swift:90-122` — the consuming sibling.
- `swift-set-ordered-primitives/.../Set.Ordered+Iteration.swift:27-44`, `Set.Ordered+Memory.Contiguous.Protocol.swift:28` — the exemplar's dual-element-kind split.

### Internal prior art (extended, not duplicated)
- `bulk-span-iteration-fold-vs-separate.md` (Tier 3, RECOMMENDATION) — the SEPARATE-vs-FOLD survey; the `Span<~Copyable>` crux; SE-0516's rejection of element-wrapping. **This doc narrows that survey's recommendation** (§1, §3.5, §4).
- `unified-iteration-design.md` (Tier 2, APPROVED v2.1.1) — the current authority; **this doc proposes a delta to §2.1/§2.3/§2.5/§3** (D7).
- `iterator-span-buffer-elimination.md` (DECISION v5.0.0) — the `nextSpan` bulk surface; zero-heap reducibility.
- `cross-layer-capability-protocol-model.md` (APPROVED) — iteration as an orthogonal concern composed `where Self: Core`.

### Skills
[RES-001/002/003/019/020/021/023/027]; [ARCH-LAYER-006/008/009]; [API-NAME-001/001b]; [API-ERR-001]; [MOD-031/035/036].
