# Two-World Decomposition of Traversal Primitives

<!--
---
version: 1.2.1
last_updated: 2026-05-25
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - "1.2.1 (2026-05-25): Renamed Iterator.Borrowing → Iterator.Borrow and
     package → swift-iterator-borrow-primitives — the World-A bulk-tier rename
     to Iterator.Span freed the Iterator.Borrow name for its correct meaning
     (yields an Ownership.Borrow; sibling to Iterator.Span which yields a Span)."
  - "1.2.0 (2026-05-25): CONCEPTUAL COLLAPSE of the implicit-position scalar
     World-B protocol. The give-away vs keep-and-lend DUALITY (§2) is unchanged
     and remains the load-bearing claim; what collapses is only the v1.0.0/v1.1.0
     IMPLEMENTATION claim that World B's scalar shape needs its OWN protocol
     hierarchy. It does not: a borrowing iterator is simply the EXISTING
     `Iterator.\`Protocol\`` instantiated with `Element = Ownership.Borrow<T>`.
     The same `Iterator.Protocol.next()` (already `@_lifetime(&self)`, already
     admitting `~Escapable` `Element`) serves BOTH worlds; the world is chosen
     by the element type — `Element = T` is World A (give-away; the move-only T
     is consumed), `Element = Ownership.Borrow<T>` is World B (keep-and-lend; a
     Copyable `~Escapable` borrow-handle is yielded while T stays in the kept
     source). Multipass (World B) comes from the EXISTING `Iterable`
     (`@_lifetime(borrow self) makeIterator()`), NOT a new attachable. Validated
     end-to-end against the REAL `Iterator.\`Protocol\``/`Iterable` on Apple
     Swift 6.3.2 (move-only element, conformance to the real protocols,
     generic-through-protocol drive, multipass — all green). SHIPPED as a thin
     naming refinement, not a new protocol-world: `swift-iterator-borrow-primitives`
     (commit `0565cd6`) provides `Iterator.Borrow.\`Protocol\`<Borrowed>:
     Iterator.\`Protocol\`` where `Element == Ownership.Borrow<Borrowed>`,
     depending on `swift-iterator-primitives` + `swift-ownership-primitives` (a
     composition/integration package per §7), adding NO new attachable. This
     DISSOLVES OQ-1 (the 'generic scalar World-B borrowing-traversal protocol'
     was a phantom — the abstraction already existed) for the implicit-position
     scalar case; the `~Escapable`-ELEMENT axis stays language-blocked, and OQ-2
     (Collection / explicit-position reconciliation) stays parked. The v1.1.0
     internal-iteration `withNext` shape is SUPERSEDED: the external
     `next() -> Ownership.Borrow<T>?` works directly (it IS
     `Iterator.Protocol.next()` with a Borrow element), via `@_lifetime(&self)`
     + the owner-anchored `Ownership.Borrow(unsafeRawAddress:borrowing: self)`.
     RENAME: `Iterator.Borrow.\`Protocol\`` → `Iterator.Span.\`Protocol\``
     (commit `3cb430a`) — World-A's bulk tier, named for what it yields (a
     `Span`), removing the 'Borrow'-reads-as-keep-and-lend hazard; this RESOLVES
     OQ-4. Also lands: `a95e711` (Iterator namespace doc fix). The §3 naming
     hazard is now RESOLVED rather than open."
  - "1.1.0 (2026-05-25): Enriched World B with two ecosystem inputs the v1.0.0
     analysis did not consider — swift-sequence-primitives (a landed
     implicit-position borrowing-traversal protocol family + two CONFIRMED
     experiments realizing the scalar keep-and-lend shape over genuine
     ~Copyable elements) and swift-ownership-primitives' Ownership.Borrow.`Protocol`
     (the institute's existing 'type with an associated borrowed view'
     abstraction). REFINED OQ-1 / §4 'the generic World-B protocol does not
     exist / is language-blocked' from an all-or-nothing claim into a precise
     account of which pieces exist (the scalar borrowing-traversal shape is
     proven expressible TODAY; the borrowed-element-view capability exists as
     Ownership.Borrow.`Protocol`; a span/bulk borrowing protocol is landed) vs
     what is still absent (a shipped generic SCALAR keep-and-lend primitive over
     arbitrary element domains, plus ~Escapable-element relaxation gated on the
     Swift.Span ceiling). RESOLVED OQ-3: swift-empty-iterator-primitives was
     created (commit 27657ae) and iterator-primitives no longer depends on
     empty-primitives (commit ccf061d removed the dep + folded-in
     target/product/test/re-export); §7 placement rule now applies uniformly to
     both bridges."
---
-->

> **Status note.** The *decomposition framework* and the *parked direction*
> (the generic World-B borrowing-traversal protocol, the Collection
> reconciliation) are a **RECOMMENDATION** — they describe a target shape that
> is partly unbuilt and partly language-blocked. The four empirical findings in
> §5 are **decided facts**, each landed in code and backed by an experiment and
> named commits; they are recorded here as the verified substrate the framework
> rests on, not as open proposals. As of v1.1.0 the *symmetric
> integration-package consequence* (formerly OQ-3) is also a decided fact:
> `swift-empty-iterator-primitives` now exists (commit `27657ae`), making the
> §7 placement rule apply uniformly to both `Single` and `Empty`.
>
> **v1.1.0 refinement of "the generic World-B protocol does not exist."** The
> v1.0.0 claim was too coarse. Two ecosystem inputs the original analysis did
> not consider (§4.3, §4.4) show the missing protocol decomposes into separable
> pieces, several of which *already exist*: the scalar keep-and-lend
> *traversal shape* over genuine `~Copyable` elements is proven expressible
> today (sequence-primitives experiments, CONFIRMED), the
> *borrowed-element-view capability* exists as `Ownership.Borrow.`Protocol``,
> and a *span/bulk* borrowing-traversal protocol is landed
> (`Sequence.Borrowing.Protocol`). What remains genuinely absent is a single
> *shipped generic scalar* keep-and-lend primitive over arbitrary element
> domains, plus the `~Escapable`-element axis (gated on the `Swift.Span`
> ceiling). §4 and OQ-1 are refined accordingly; the "entirely missing" framing
> is replaced by a precise inventory of present-vs-absent pieces.
>
> **v1.2.0 collapse — the scalar World-B protocol was a phantom; the duality is
> not.** The give-away vs keep-and-lend duality (§2) is *unchanged and remains
> the load-bearing claim of this document.* What collapses in v1.2.0 is only the
> v1.0.0/v1.1.0 *implementation* claim that World B's implicit-position **scalar**
> shape needs its own protocol hierarchy. It does not. A borrowing iterator is
> simply the **existing `Iterator.`Protocol``** instantiated with
> `Element = Ownership.Borrow<T>`: the same `Iterator.Protocol.next()` — already
> `@_lifetime(&self)`, already admitting `~Escapable` `Element` — serves *both*
> worlds, and the world is chosen by the **element type**, not by a distinct
> protocol. `Element = T` is World A (give-away; the move-only `T` is consumed
> out); `Element = Ownership.Borrow<T>` is World B (keep-and-lend; a `Copyable`,
> `~Escapable` borrow-handle is yielded while `T` stays in the kept source).
> Multipass (World B) comes from the **existing `Iterable`**
> (`@_lifetime(borrow self) makeIterator()`), *not* a new attachable. This was
> validated end-to-end against the **real** `Iterator.`Protocol``/`Iterable` on
> Apple Swift 6.3.2 (a move-only element, conformance to the real protocols, a
> generic-through-protocol drive, and multipass — all green), and is **shipped**
> as a thin naming refinement rather than a new protocol-world:
> `swift-iterator-borrow-primitives` (commit `0565cd6`) provides
> `Iterator.Borrow.`Protocol`` = `Iterator.`Protocol`` with an
> `Ownership.Borrow` element (§4.5). OQ-1 is therefore **dissolved** for the
> implicit-position scalar case (the abstraction already existed; no new protocol
> was needed); only the `~Escapable`-*element* axis remains language-blocked, and
> the explicit-position `Collection` reconciliation (OQ-2) stays parked. In the
> same arc the World-A bulk tier `Iterator.Borrow` was **renamed** to
> `Iterator.Span` (commit `3cb430a`), resolving the §3 naming hazard (OQ-4); it
> was subsequently renamed again to `Iterator.Chunk` (the final bulk-tier manner
> name; `swift-iterator-primitives cbc7636`), which this doc uses below.

## Context

A working session on 2026-05-25 (Apple Swift 6.3.2,
`swiftlang-6.3.2.1.108`) reshaped the foundational iteration primitives across
five packages — `swift-iterator-primitives`, `swift-single-primitives`,
`swift-empty-primitives`, `swift-cursor-primitives`, and a newly created
`swift-single-iterator-primitives`. The reshape was driven by a concrete
failure (the `Iterable` attachable could not vend the family's own canonical
iterators `Once` / `Empty`) but resolving it surfaced a general organizing
principle for *all* traversal primitives: Swift's ownership model forces
traversal into **two worlds** — give-away (owned, single-pass) and keep-and-lend
(borrowed, multipass) — that remain distinct disciplines. (v1.2.0 sharpens the
*implementation* corollary: the two disciplines do not each need their own
protocol — for the implicit-position scalar case they are both the *same*
`Iterator.`Protocol``, selected by the **element type** (`Element = T` vs
`Element = Ownership.Borrow<T>`); see the status note and §4.5. The *duality*
itself is unchanged — it is what makes the element type the discriminator.)

This document captures that principle as durable ecosystem architecture, so
that future traversal primitives (sequence, collection, the scalar
borrowing-traversal protocol — *now shipped*, §4.5 — per-domain cursors) are
placed deliberately rather than rediscovered.

**v1.1.0 scope addition.** The v1.0.0 World-B analysis was written from the
iterator-family reshape and did not consult two adjacent packages that bear
directly on World B: `swift-sequence-primitives` (which ships a span/bulk
borrowing-traversal protocol and carries experiments realizing the scalar
keep-and-lend shape over `~Copyable` elements; §4.3) and
`swift-ownership-primitives` (whose `Ownership.Borrow.`Protocol`` is the
institute's existing borrowed-element-view abstraction; §4.4). v1.1.0 folds both
into the World-B sections and uses them to make the OQ-1 "missing generic
protocol" claim precise. v1.1.0 also records the resolution of OQ-3 (the `Empty`
integration-package asymmetry), now corrected on disk in favor of the §7 rule
via `swift-empty-iterator-primitives` (commits `27657ae`, `ccf061d`).

**v1.2.0 scope addition.** v1.1.0 still treated the implicit-position scalar
World-B protocol as a thing to be *promoted from a spike*. v1.2.0 collapses that:
a borrowing iterator is the *existing* `Iterator.`Protocol`` with
`Element = Ownership.Borrow<T>`, and multipass is the *existing* `Iterable` — no
new protocol hierarchy, no new attachable (§4.5). Validated against the real
protocols on Apple Swift 6.3.2 and shipped as the thin naming refinement
`swift-iterator-borrow-primitives` (commit `0565cd6`, providing
`Iterator.Borrow.`Protocol``), dissolving OQ-1 for the scalar case. In the
same arc the World-A bulk tier was renamed `Iterator.Borrow` → `Iterator.Span`
(commit `3cb430a`, plus namespace-doc fix `a95e711`), resolving the OQ-4 naming
hazard; it was later renamed `Iterator.Span` → `Iterator.Chunk` (the final
bulk-tier manner name; `cbc7636`), used below. The give-away vs keep-and-lend
*duality* of §2 is untouched — only the
v1.0.0/v1.1.0 claim that World B needs its own protocol hierarchy collapses.

**Trigger**: [RES-001] architecture choice + [RES-016] rationale documentation
— a structural decomposition that affects every future traversal primitive's
protocol-conformance and package placement decision.

**Tier**: 3 — ecosystem-wide; precedent-setting (traversal is foundational to
sequence, collection, parser, lexer, serializer, and every container in the
ecosystem); cost of error very high; expected lifetime timeless infrastructure.

### Terminology collision warning (read first)

The word **"World"** is already load-bearing in the cursor corpus, where it
denotes a **cursor-storage** axis:
`cursor-abstractions-l1-ecosystem.md` (SUPERSEDED) and
`cursor-shape-a-vs-three-worlds.md` (IMPLEMENTED) use *World 1 / 2 / 3* (W1
owned-read-only storage, W2 borrowed-Span storage, W3 copyable-input storage)
to classify the `Storage` parameter of the single `Cursor` type.

This document's **World A / World B** is a *different and orthogonal* axis: the
**element-ownership of the yield** (owned vs borrowed). To avoid confusion:

| Term | Axis | Defined by |
|------|------|------------|
| Cursor W1 / W2 / W3 | cursor *storage* shape (owned / borrowed / copyable-input) | cursor-shape-a-vs-three-worlds.md |
| **Traversal World A / World B** (this doc) | *yield element-ownership* (give-away vs keep-and-lend) | this doc |

The two are independent. The byte-stream `Cursor` (cursor W2 storage) is a
*concrete World-B citizen* under this document's axis — see §4.2. Wherever this
doc says "World" unqualified, it means the traversal A/B axis.

## Question

How should traversal primitives be decomposed, and where (which protocol,
which package) does each `(source × world)` combination live, given Swift's
ownership constraints on yielding move-only and non-escaping elements?

## Analysis

### 1. The four orthogonal axes of traversal

Traversal of a sequence of elements decomposes along four independent axes:

| Axis | Values | Meaning |
|------|--------|---------|
| **Element-ownership of the yield** | owned · borrowed | does a step hand out an *owned* element (moved/copied out) or a *borrow* (a view that stays in place)? |
| **Passes** | single · multi | can traversal be restarted (multipass), or is it consumed as it runs (single-pass)? |
| **Granularity** | scalar · bulk | does a step yield one element, or a contiguous run (a `Span`)? |
| **Position** | implicit · explicit | does the traversal carry its own position (implicit, e.g. an iterator), or does the caller hold a position token (explicit, e.g. an `Index`)? |

These axes are *a priori* independent — a design could in principle offer any
combination. Swift's ownership model collapses the first two.

### 2. Ownership × passes collapses to a hard duality

For a **move-only** (`~Copyable`) element, the ownership and passes axes are not
independent:

- An **owned** yield must *move the element out* of the traversal's storage to
  hand it to the caller. After the move, the element is gone from the source ⇒
  the source cannot be traversed again over that element ⇒ **single-pass**.
  This is the **give-away** discipline.
- A **borrowed** yield *leaves the element in place* and hands out a view. The
  source retains the element ⇒ it can be observed again ⇒ **multipass-capable**.
  This is the **keep-and-lend** discipline.

So for move-only elements, `owned ⇒ single-pass` and `borrowed ⇒ multipass`.
The two-by-two `{owned, borrowed} × {single, multi}` grid collapses to a
**diagonal**: only `(owned, single)` and `(borrowed, multi)` are coherent. The
off-diagonal cells (`owned`+`multi`, `borrowed`+`single`) are not expressible
for a move-only element without violating linearity.

> For *copyable* elements the off-diagonal *is* reachable (you can copy an
> element out repeatedly, giving an owned multipass traversal). But a
> foundational primitive family must admit move-only elements, so the family's
> protocol shape is set by the move-only constraint. Copyable elements ride the
> same two worlds; they just additionally get the cheap cross-world bridge of §3.

This is the load-bearing claim of the whole decomposition. It is *not* a Swift
convention — it is a consequence of the language's affine ownership of
`~Copyable` values, which the compiler enforces. (The §5 empirical findings are
the compiler enforcing exactly this.)

### 3. The two worlds

#### World A — owned iteration (give-away, single-pass)

A World-A traversal *owns nothing it can keep*: each step gives an element away.
It is the iterator world.

| Tier | Type | File:line | Notes |
|------|------|-----------|-------|
| Foundation protocol | `Iterator.`Protocol`` | `swift-iterator-primitives/Sources/Iterator Protocol/Iterator.Protocol.swift:31` | `~Copyable, ~Escapable`; `associatedtype Element: ~Copyable & ~Escapable`; `mutating func next() throws(Failure) -> Element?` annotated `@_lifetime(&self)` |
| Bulk tier | `Iterator.Chunk.`Protocol`` | `swift-iterator-primitives/Sources/Iterator Chunk Primitives/Iterator.Chunk.Protocol.swift` | refines `Iterator.`Protocol``; **narrows `Element` to `Escapable`** (because `Span<Element>` has no `~Escapable` form); `next(maximumCount:) -> Span<Element>` annotated `@_lifetime(&self)`. *Renamed `Iterator.Borrow.`Protocol`` → `Iterator.Span.`Protocol`` (commit `3cb430a`, OQ-4 resolved) → `Iterator.Chunk.`Protocol`` (final bulk-tier manner name; `cbc7636`); see hazard callout.* |
| Attachable | `Iterable` | `swift-iterator-primitives/Sources/Iterable/Iterable.swift:19` | a type that *has* an iterator; `associatedtype Iterator: …, ~Copyable, ~Escapable`; `makeIterator()` annotated `@_lifetime(borrow self)` |
| Concrete: one owned element | `Once<Element>` | `swift-iterator-primitives/Sources/Once Primitives/Once.swift:24` | enum `.pending(Element)` / `.done`; `~Copyable, ~Escapable`; *moves* the element out on first `next()` |
| Concrete: zero elements | `Empty<Element>` (+ iterator conformance) | bare type: `swift-empty-primitives/.../Empty.swift:20`; conformance: `swift-iterator-primitives/Sources/Empty Iterator Primitives/Empty+Iterator.Protocol.swift:16` | `next()` always `nil` |
| Concrete: closure witness | `Iteration<Element, Failure>` | `swift-iterator-primitives/Sources/Iteration/Iteration.swift:29` | `~Copyable`; closure-backed; Element limited to closure-capturable (Copyable + Escapable) |
| Concrete: infinite repeat | `Iterator.repeating(_:)` | `swift-iterator-primitives/Sources/Iteration/Iterator.repeating.swift:17` | returns `Iteration`; requires `Copyable` element |

**`Once` is the prototype World-A citizen.** Its doc comment names the
discipline directly: it "owns its element and *gives it away* on the first call
to `next()`". The enum shape is load-bearing — yielding a move-only element
requires `consume self` + full reinitialization (a stored `Element?` field
cannot express partial reinitialization after consume; `swap` requires
`Escapable`).

> **Naming hazard — RESOLVED in v1.2.0 by renaming `Iterator.Borrow` →
> `Iterator.Span`, since renamed to `Iterator.Chunk`.** The bulk tier is still an **owned** (World-A) iterator: each
> step gives away a `Span` that borrows the *iterator* (`@_lifetime(&self)`),
> single-pass — *not* World-B keep-and-lend traversal. Under the old name
> `Iterator.Borrow.`Protocol``, the "Borrow" stem read as the keep-and-lend
> sense and a reader could mistake it for the World-B borrowing-traversal
> protocol — the opposite of what it is. v1.0.0/v1.1.0 flagged this as open
> naming question OQ-4. It is now resolved: the tier was **renamed to
> `Iterator.Span.`Protocol``** (commit `3cb430a`), named for *what it yields* (a
> `Span`) rather than the ownership of the yield, removing the hazard. The irony
> worth recording: "borrow" is now used *correctly* under `Iterator` — for the
> v1.2.0 `Iterator.Borrow.`Protocol`` (§4.5), which genuinely yields an
> `Ownership.Borrow` (keep-and-lend), a payload-named sibling of `Iterator.Span`
> (yields `Span`). See OQ-4.

#### World B — borrowing traversal (keep-and-lend, multipass)

A World-B traversal *keeps* its elements and lends views of them; it is
multipass. It has **three position-shapes** (explicit, implicit-span/bulk,
implicit-scalar), plus one concrete byte-stream-specialized citizen:

| Position shape | Protocol/type | Status |
|----------------|---------------|--------|
| **explicit** (caller holds an `Index`, borrowing subscript) | `Collection` | **Exists** (`swift-collection-primitives` family) |
| **implicit, span/bulk** (the traversal carries its own position and lends a `Span<Element>` per step) | `Sequence.Borrowing.Protocol` | **Exists** (`swift-sequence-primitives`); `Escapable`-element-narrowed by the `Span` ceiling (see §4.3) |
| **implicit, scalar** (the traversal carries its own position and lends one `borrowing Element` per step — the dual of World-A's `Iterator.`Protocol``) | `Iterator.Borrow.`Protocol`` (= `Iterator.`Protocol`` with `Element == Ownership.Borrow<Borrowed>`) | **Shipped** (`swift-iterator-borrow-primitives`, `0565cd6`). v1.2.0: this is *not* a new protocol hierarchy — it is the existing `Iterator.`Protocol`` instantiated with a `Borrow` element, plus the existing `Iterable` for multipass (§4.5; OQ-1 dissolved). The `~Escapable`-*element* axis remains language-blocked (§4.3, §6). |
| concrete, byte-stream-specialized | `Cursor<DomainTag>` | **Exists** (`swift-cursor-primitives`); generic generalization deferred; rides `Ownership.Borrow.`Protocol`` for its borrowed-view storage (see §4.4) |

##### 4.1 The explicit-position shape: `Collection`

`Collection` already realizes World B's explicit-position shape: the caller
holds an `Index`, and the borrowing subscript lends a view of an element that
stays in the collection — multipass over move-only elements without consuming
them. The prior art `collection-sequence-protocol-detachment.md` (DECISION)
records *why* this had to detach from `Sequence`: `Sequence`'s
`next() -> Element?` returns an *owned* value (a destructive consuming move for
`~Copyable` elements), which is fundamentally World A and "incompatible with
multi-pass borrowing access, which is the primary access mode for collections
with `~Copyable` elements." That detachment is the *same* duality this document
generalizes — `Collection` is World B, `Sequence` (via its iterator) is World A,
and they could not share an inheritance edge precisely because the worlds do not
unify.

##### 4.2 The concrete byte-stream citizen: `Cursor`

`Cursor<DomainTag>`
(`swift-cursor-primitives/Sources/Cursor Primitive/Cursor.swift:72`) is the
only concrete implicit-position World-B citizen today. It is
byte-stream-specialized: `DomainTag: Ownership.Borrow.`Protocol` & ~Copyable`,
storage derived as `DomainTag.Borrowed` (canonically `Byte.Borrowed`), so
`Cursor<Byte>` / `Cursor<Text>` traverse a **borrowed `Span`** of bytes. It is
`~Copyable, ~Escapable` with a mutable `_position` and an immutable `storage`
borrow — it keeps the borrowed span and lends positioned reads of it
(multipass: position can seek backward).

Two caveats on `Cursor`'s placement under World B:

1. **It is specialized, not generic.** `Cursor`'s `Storage`-parameterization
   arc (the cursor-storage W1/W2/W3 axis — *not* this doc's A/B axis) landed a
   single-generic `Cursor<DomainTag>` bound to `Ownership.Borrow.`Protocol``,
   and the generalization to arbitrary element domains is **deferred** per its
   own Phase-4 note (Cursor.swift §"Phase 4 scope note" lines 53–59;
   `cursor-w1-expansion.md` DECISION). So `Cursor` is a *point* in World B's
   implicit-position shape, not the generic protocol.

2. **`Cursor` is a stateful traversal, not a passive borrow-projection.**
   `nested-view-vs-borrowed-naming.md` (DECISION) classifies cursor types as
   **Pattern 3** (stateful cursor/iterator, `~Copyable` with mutable position) —
   explicitly *not* `Ownership.Borrow.`Protocol`` conformers (those are
   Pattern 1 passive borrow-views like `String.Borrowed`). `Cursor` *consumes* a
   Pattern-1 borrow-view (`DomainTag.Borrowed`) as its storage but is itself
   Pattern 3. This is consistent with World B: the *yield* is a borrow
   (keep-and-lend), realized by a stateful position over kept storage.

##### 4.3 `swift-sequence-primitives` — a landed span/bulk borrowing protocol, and the scalar shape proven expressible

The v1.0.0 analysis treated the implicit-position World-B protocol as a single
"does not exist yet, language-blocked" cell. `swift-sequence-primitives` (a
landed L1 package — its `README.md` opens "`Sequence.Protocol` … lifts [the
`Element: Copyable`] constraint so move-only element types … can be iterated
without being copied") splits that cell into two and moves the needle on both.

**(a) A landed *span/bulk* implicit-position borrowing-traversal protocol.**
`Sequence.Borrowing.Protocol`
(`swift-sequence-primitives/Sources/Sequence Borrowing Primitives/Sequence.Borrowing.Protocol.swift:43`)
is exactly an implicit-position keep-and-lend protocol:
`borrowing func makeIterator() -> Iterator` annotated `@_lifetime(borrow self)`
(lines 74–75) — "The sequence remains valid during and after iteration. The
returned iterator borrows from `self`" (lines 62–66). Its iterator's sole
requirement is `nextSpan(maximumCount:) -> Span<Element>`
(`Sequence.Iterator.Protocol.swift`, doc lines 5–7, `@_lifetime(&self)` on the
returned span), so each step **lends a `Span` that borrows the kept storage** —
multipass, non-destructive. `Verified: 2026-05-25`.

This is structurally the **same shape as World-A's `Iterator.Span.`Protocol``
bulk tier** (renamed from `Iterator.Borrow.`Protocol`` in `3cb430a`) but with
the opposite ownership disposition at the container: where
`Iterator.Span.`Protocol`` is an *owned* iterator whose span borrows the
*iterator* (give-away, §3 naming hazard), `Sequence.Borrowing.Protocol` is a
*borrowing* traversal whose iterator borrows the *sequence* (keep-and-lend).
The two confirm §2's duality from a fresh direction: the same `nextSpan`
throughput primitive sits in *both* worlds, distinguished only by whether
`makeIterator()` is `consuming` (World A) or `borrowing` (World B). The
`Sequence.Borrowing.swift` namespace doc draws exactly this edge
(`Sequence.Protocol` "← element-at-a-time, owns iterator" → `Sequence.Borrowing.Protocol`
"← span-at-a-time, borrows from container"; lines 12–16).

**Why this is the *bulk/span* tier, not the missing *scalar* protocol.**
`Sequence.Borrowing.Protocol`'s element axis is **narrowed to `Escapable`** by
the `Span` ceiling: although the protocol *declares* `associatedtype Element: ~Copyable`
(line 50), its `Sequence.Borrowing.swift` doc (lines 25–29) records the
operative limitation — "The `Element` type implicitly requires `Copyable`
because Swift does not support `associatedtype Element: ~Copyable`" at the
`Span<Element>` boundary — and `Sequence.Iterator.Protocol.swift:113–115`
states it directly: "`~Escapable` relaxation is BLOCKED until `Swift.Span<Element>`
accepts `Element: ~Escapable` upstream (Swift 6.3.1 requires `Element: Escapable`)."
This is **the same `Span`-escapability blocker §3 already records for
`Iterator.Span.`Protocol``** and §6/OQ-1 invokes via
`2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`. So
`Sequence.Borrowing.Protocol` realizes World-B's *implicit, span/bulk*
position-shape over `Escapable` elements; it is **not** the scalar
`(borrowing Element)` keep-and-lend protocol OQ-1 names. (Confirming the
direction: `Sequence.Iterator.Protocol`'s default scalar `next()` "returns an
owned `Copyable` value, not borrowed" — `Sequence.Iterator.Protocol.swift:68,143`
— so the *scalar* face of the sequence family is World-A give-away, exactly per
§6's seam.)

**(b) The missing *scalar* keep-and-lend shape is proven expressible TODAY.**
This is the load-bearing refinement to OQ-1. Two CONFIRMED experiments in
`swift-sequence-primitives/Experiments/` build the exact dual of
`Iterator.`Protocol`` — a scalar implicit-position protocol that lends one
`borrowing Element` per step over a *genuinely* `~Copyable` element — and prove
it compiles and runs:

- `Experiments/suppressed-associated-types/Sources/main.swift` (CONFIRMED, Apple
  Swift 6.2.3; "Revalidated: Swift 6.3.1 (2026-04-30) — PASSES" on its
  refuted-stdlib variant) declares `protocol IterableProtocol: ~Copyable { associatedtype Element: ~Copyable; borrowing func makeIterator() -> Iterator }`
  + `protocol IterProto: ~Copyable { associatedtype Element: ~Copyable; mutating func next() -> Element? }` (lines 37–50) and conforms a `~Copyable` container with a genuinely `~Copyable` element (`struct Resource: ~Copyable`) — V3 CONFIRMED (lines 76–104). Its Key Findings (lines 169–179) establish that `SuppressedAssociatedTypes` (SE-0503) enables `associatedtype Element: ~Copyable` in *user-defined* protocols (the institute's own protocols, exactly the surface a generic World-B primitive would occupy), while stdlib `IteratorProtocol`/`Sequence` are unaffected (V6 REFUTED) — which is *why* the family is re-implemented rather than conformed onto stdlib.
- `Experiments/two-tier-borrowing-overloads/Sources/main.swift` (CONFIRMED, 6.2.3;
  "Revalidated: Swift 6.3.1 (2026-04-30) — PASSES") replicates the same
  `IterableProtocol`/`IterProto` pair and adds a pointer-backed `ForEachView`
  whose `callAsFunction(_ body: (borrowing Base.Element) -> Void)` walks the
  iterator and hands each element to the closure **by borrow** (lines 48–63).
  V2/V5 CONFIRM `~Copyable`-element borrowing traversal end-to-end
  (`Resource(10)…`, read-but-not-consume); V6 CONFIRMS a two-tier
  borrowing/by-value overload split (with a documented same-name-overload
  MoveOnlyChecker crash, dodged by distinct method names). `Verified: 2026-05-25`.

So the scalar keep-and-lend *traversal shape* — `makeIterator()` →
`mutating next() -> Element?` over `~Copyable Element`, consumed by a
`(borrowing Element)` closure — is **not** language-blocked: it compiles today
under `SuppressedAssociatedTypes`, for genuinely move-only elements, verified on
the same toolchain family this document targets. What is still absent is
narrower than v1.0.0 stated:

1. **A shipped generic *family* primitive of this shape.** *(At v1.1.0 this was
   an unbuilt gap; v1.2.0 closes it — see §4.5.)* The experiments below are
   verification spikes, not a published `swift-*-primitives` protocol. The
   sequence family's *production* implicit-position protocol is the span/bulk
   `Sequence.Borrowing.Protocol` (4.3a); its *production* scalar face is
   World-A give-away (`next() -> owned`). At v1.1.0 no production *scalar
   keep-and-lend* protocol over arbitrary element domains had been promoted from
   the spike — an **unbuilt** gap, not a language gap. **v1.2.0 retires this
   gap**: the production scalar keep-and-lend protocol shipped as
   `Iterator.Borrow.`Protocol`` (`swift-iterator-borrow-primitives`,
   `0565cd6`), and the §4.5 collapse shows it required *no new protocol* — it is
   the existing `Iterator.`Protocol`` with an `Ownership.Borrow` element. The
   spikes below validated the *shape*; §4.5 then proved the abstraction already
   existed and shipped the name. (Note the spikes used *user-defined*
   mini-protocols; §4.5's validation is against the *real* `Iterator.`Protocol``.)
2. **The `~Escapable`-element axis.** Lending a *view* of an `~Escapable`
   element (rather than a `borrowing` of a `~Copyable` one) still runs into the
   `Swift.Span` / lifetime-dependent-associated-value ceiling per §6/OQ-1. This
   remains genuinely **language-blocked** (unchanged by the v1.2.0 collapse).

The net correction (v1.1.0): OQ-1's "does not exist yet —
language-maturity-blocked" was two claims fused. The *scalar borrowing-traversal
shape over `~Copyable` elements* exists (as a proven, revalidated spike) and is
merely unpromoted; only the `~Escapable`-element generalization is
language-blocked. **v1.2.0 sharpens this further**: the unpromoted-scalar-shape
half is not merely promoted but *dissolved* — there was no separate primitive to
build, only the existing `Iterator.`Protocol`` to instantiate and name (§4.5).
Only the `~Escapable`-element half survives as language-blocked.

##### 4.4 `swift-ownership-primitives` — `Ownership.Borrow.`Protocol`` supplies the borrowed-element-view piece

The second input answers a different sub-question: of the pieces a generic
World-B protocol needs, does the institute *already* have the "a type with an
associated borrowed view of an element" abstraction? It does, and §4.2 already
leans on it without naming it as a World-B building block.

`Ownership.Borrow.`Protocol`` — canonical spelling for the module-scope
`__Ownership_Borrow_Protocol`
(`swift-ownership-primitives/Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift:30`)
— is precisely:

```swift
public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable = Ownership.Borrow<Self>
}
```

"Conformers expose a borrowed projection of their content" (doc lines 21–24).
The default `Borrowed = Ownership.Borrow<Self>` is a `Copyable`-but-`~Escapable`
read-only view over `Value: ~Copyable & ~Escapable`
(`Ownership.Borrow.swift:72`; "the ecosystem equivalent of Swift stdlib's
`Borrow<T>` (SE-0519)", lines 18–21); conformers with interior storage override
it with a custom nested type (`Path.Borrowed`, `String.Borrowed`).
`Verified: 2026-05-25`.

**What it provides — the *element-view* axis, exactly the piece §4.2's `Cursor`
already consumes.** `Cursor<DomainTag>` constrains
`DomainTag: Ownership.Borrow.`Protocol` & ~Copyable` and uses `DomainTag.Borrowed`
(canonically `Byte.Borrowed`) as its kept storage
(`swift-cursor-primitives/Sources/Cursor Primitive/Cursor.swift:72`;
`ownership-borrow-protocol-unification.md`, DECISION). Read against this
document's axis, that is `Cursor` obtaining "a borrowed, non-escaping view of
the thing being traversed" from `Ownership.Borrow.`Protocol``, then layering a
stateful position over it. So `Ownership.Borrow.`Protocol`` supplies one of the
two axes a generic implicit-position World-B protocol decomposes into:

| World-B implicit-position protocol needs… | Supplied by | Status |
|---|---|---|
| **a borrowed, `~Escapable`-tolerant view of the element being lent** (the "keep-and-lend" object) | `Ownership.Borrow.`Protocol`` (the `Borrowed` associated type) | **Exists** — `Ownership.Borrow.swift`, `__Ownership_Borrow_Protocol.swift` |
| **a stateful implicit position that walks kept storage and lends that view per step** (the "traversal" object) | the *existing* `Iterator.`Protocol`` — its `next()` already lends per step (§4.5) | **Exists / Shipped.** v1.2.0: this axis was never missing — it is `Iterator.Protocol.next()`, and binding `Element = Ownership.Borrow<Borrowed>` *combines* this row with the row above. Shipped as `Iterator.Borrow.`Protocol`` (`0565cd6`). |

**What it does NOT provide — and the Pattern-1-vs-3 boundary that keeps it
honest.** `Ownership.Borrow.`Protocol`` is a **passive borrow-view capability,
not a traversal**: it has *no* position, *no* `next()`/`nextSpan`, *no* notion
of progress. `nested-view-vs-borrowed-naming.md` (DECISION) classifies exactly
these as **Pattern 1** (passive borrow-views like `String.Borrowed`) and
explicitly *distinguishes* them from **Pattern 3** stateful cursors/iterators
(§4.2 caveat 2 already cites this). A generic World-B protocol *is* Pattern 3 and
*consumes* a Pattern-1 view — precisely as `Cursor` does. So
`Ownership.Borrow.`Protocol`` is a **necessary building block, not a partial
realization**: it closes the element-view axis (and, via its `~Escapable
Borrowed`, even reaches further into the `~Escapable` territory than
`Sequence.Borrowing.Protocol`'s `Span`-bound element), but it contributes
nothing to the implicit-position-traversal axis. The v1.1.0 residue, restated
then, was: *promote the §4.3b scalar keep-and-lend traversal shape to a shipped
generic primitive whose lent object is (or generalizes) an
`Ownership.Borrow.`Protocol`` `Borrowed` view*. **v1.2.0 closes exactly this**,
and reveals the residue was smaller than it looked: the implicit-position-traversal
axis is *already* supplied by `Iterator.Protocol.next()` (§4.5), so the "promote
the shape" residue was satisfied not by building a new protocol but by binding
`Iterator.`Protocol``'s `Element` to `Ownership.Borrow.`Protocol``'s `Borrowed`
view — which is exactly what `Iterator.Borrow.`Protocol``
(`swift-iterator-borrow-primitives`, `0565cd6`) declares. After v1.2.0 the
`~Escapable`-element axis is the only language-gated remainder.

##### 4.5 The scalar World-B protocol is `Iterator.`Protocol`` with a `Borrow` element — OQ-1 dissolved

**v1.2.0 collapse.** §4.3–§4.4 inventoried the pieces a "generic scalar World-B
borrowing-traversal protocol" would need and found most of them already present.
v1.2.0 closes the loop: the protocol itself was a **phantom**. There is no
missing scalar World-B protocol hierarchy to build, because the abstraction
*already exists* — a borrowing iterator is simply the **existing
`Iterator.`Protocol``** (World-A foundation, §3) instantiated with
`Element = Ownership.Borrow<T>`.

**One `next()`, two worlds — the world is the element type.**
`Iterator.Protocol.next()` is *already* `@_lifetime(&self)` and *already* admits
`~Escapable` `Element` (`associatedtype Element: ~Copyable & ~Escapable`,
`Iterator.Protocol.swift:31`). That single signature serves **both** worlds; the
world is chosen by what `Element` is bound to, not by a distinct protocol:

| `Element` binding | World | Discipline | What `next()` does |
|---|---|---|---|
| `Element = T` (move-only) | **World A** | give-away, single-pass | *moves* the `T` out of the iterator's storage; after the move it is gone from the source |
| `Element = Ownership.Borrow<T>` | **World B** | keep-and-lend, multipass | yields a `Copyable`, `~Escapable` **borrow-handle** while the `T` stays in the kept source |

The off-diagonal of §2 is untouched: World A consumes, World B lends, and the
`~Copyable`-element duality is exactly what makes the *element type* — not a
protocol — the discriminator. The `Ownership.Borrow<T>` yield is itself
`Copyable` (you can hold several borrow-handles) and `~Escapable` (none may
outlive the source), so a `next()` returning `Ownership.Borrow<T>?` is
multipass-coherent in precisely the way §2 requires of World B.

**Multipass comes from the existing `Iterable`, not a new attachable.** The
container side needs nothing new either: `Iterable`'s `makeIterator()` is
*already* `@_lifetime(borrow self)` (Finding 2; `Iterable.swift:41`), which
*borrows* — rather than consumes — the container, so a fresh borrowing iterator
can be obtained on every call. That is multipass. v1.1.0 speculated a separate
World-B attachable; v1.2.0 retires that speculation — `Iterable` already
expresses "a kept source that lends an iterator," which is the World-B container
contract.

**Validated end-to-end against the real protocols (Apple Swift 6.3.2).** This is
not an analogy from the ad-hoc spikes of §4.3b (which used *user-defined*
mini-protocols). The collapse was validated against the **real**
`Iterator.`Protocol``/`Iterable` from `swift-iterator-primitives`: a move-only
element type, a conformance to the *actual* protocols with
`Element == Ownership.Borrow<T>`, a generic function driving the iterator
*through the protocol* (not the concrete type), and a multipass loop — all
compile and run green. `Verified: 2026-05-25`.

**Shipped as a thin naming refinement, not a new protocol-world.** The result is
`swift-iterator-borrow-primitives` (commit `0565cd6`,
`/Users/coen/Developer/swift-primitives/swift-iterator-borrow-primitives`),
which declares exactly one protocol and no concrete types:

```swift
extension Iterator.Borrow {
    public protocol `Protocol`<Borrowed>: Iterator.`Protocol`, ~Copyable, ~Escapable
    where Element == Ownership.Borrow<Borrowed> {
        associatedtype Borrowed: ~Copyable & ~Escapable
    }
}
```

(`Iterator.Borrow.Protocol.swift:60–68`, `Verified: 2026-05-25`.) It is a
**composition / integration package** per the §7 deterministic rule: it depends
on `swift-iterator-primitives` *and* `swift-ownership-primitives` and bridges
them, owning neither `Iterator.`Protocol`` nor `Ownership.Borrow`
(`Package.swift:21–30`, `Verified: 2026-05-25`). `Iterator.Borrow.`Protocol``
adds *no* new traversal mechanism — it is `Iterator.`Protocol`` with the element
pinned to `Ownership.Borrow<Borrowed>`, plus a `Borrowed` associated type that
*names* the underlying element being lent. It adds **no new attachable**:
multipass containers conform to the existing `Iterable` (README and
`Iterator.Borrow.Protocol.swift:38–44`, `Verified: 2026-05-25`).
`Iterator.Borrow.`Protocol`` is a **NAMED REFINEMENT / opt-in sugar** over the
bare `Iterator.`Protocol`<Ownership.Borrow<Element>, Never>` — directly usable
via `Iterator.`Protocol``'s primary associated types without the refinement at
all; the refinement's only value is the named `Borrowed` associated type (which
surfaces the underlying element type explicitly) and the declared intent, not new
capability.

**The v1.1.0 `withNext` (internal-iteration) shape is superseded.** A subagent
had recommended an internal-iteration `withNext` shape on the grounds that the
*external* `next() -> Ownership.Borrow<T>?` could not be expressed. That refutation
was built on an **ad-hoc view + the wrong initializer + `@_lifetime(borrow self)`
on a `mutating` method** — a combination that does not type-check and does not
reflect the real recipe. The external shape works directly: it *is*
`Iterator.Protocol.next()` with a `Borrow` element, and the correct recipe is
**`@_lifetime(&self)`** (not `@_lifetime(borrow self)`) on the `mutating next()`,
returning an owner-anchored borrow built with
**`Ownership.Borrow(unsafeRawAddress:borrowing: self)`** — the
`@_lifetime(borrow owner)` initializer at
`swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:280–283`
(`Verified: 2026-05-25`). The external `next() -> Ownership.Borrow<T>?` is the
chosen shape; `withNext` is retired.

**What stays unchanged.** The `~Escapable`-**element** axis — lending a *view* of
a genuinely non-escaping element rather than an `Ownership.Borrow` of a
`~Copyable` one — is still language-blocked at the `Swift.Span` /
lifetime-dependent-associated-value ceiling (§4.3b, §6); the collapse does *not*
unblock it. And this collapse is about the **implicit-position scalar** case
only: the explicit-position `Collection` reconciliation (OQ-2) is a separate,
still-parked question (§4.1).

### 5. Empirical findings — decided facts

These four findings are landed in code, verified against an experiment, and
recorded here as the substrate the framework rests on. Each is
`Verified: 2026-05-25` against current source per [RES-013a]/[RES-023].

**Experiment** (status CONFIRMED, Apple Swift 6.3.2):
`swift-single-primitives/Experiments/single-iterable-ownership-ceiling/Sources/single-iterable-ownership-ceiling/main.swift`.
Its header states the result: *"The ceiling is set by the `Iterable`
protocol's shape, not the element bound."* `Verified: 2026-05-25`.

#### Finding 1 — `Iterable.Iterator` must suppress `~Copyable & ~Escapable`

`Iterable`'s `associatedtype Iterator` was originally declared *without*
suppression, which **silently required a `Copyable` iterator** and so could not
vend `Once` / `Empty` (both `~Copyable`). The fix suppresses
`~Copyable & ~Escapable` on the associated type.

- **Verified at**: `Iterable.swift:31` —
  `associatedtype Iterator: Iterator_Primitive.Iterator.`Protocol`, ~Copyable, ~Escapable`.
  The doc comment (lines 22–27) states: *"Without the suppression the associated
  type silently requires a `Copyable` iterator and rejects every move-only
  iterator in the family."*
- **Experiment V1 (REFUTED branch)**: an associated type with no suppression
  produces `"candidate would match … if 'MiniOnce<Element>' conformed to
  'Copyable'"`.
- **Commit**: `swift-iterator-primitives` `7f6dac7` *"Fix Iterable: suppress
  Copyable & Escapable on the Iterator associatedtype"*. `Verified: 2026-05-25`.

#### Finding 2 — `makeIterator()` must be `@_lifetime(borrow self)`, not `copy self`

The suppression in Finding 1 forces a lifetime annotation on `makeIterator()`
(the vended iterator may be `~Escapable`, so a lifetime relationship is
required). It **must be `@_lifetime(borrow self)`** — `@_lifetime(copy self)` is
rejected for an `Escapable` container with *"cannot copy the lifetime of an
Escapable type"*, and an escapable container (e.g. `Single<Int>`) is the common
case. `borrow self` is the only contract that holds for *both* escapable and
non-escapable containers: the vended iterator borrows the container and may not
outlive it.

- **Verified at**: `Iterable.swift:41` — `@_lifetime(borrow self)` on
  `makeIterator()`, with the rationale spelled out in the doc comment
  (lines 36–40). The bridge `Single+Iterable.swift:14` repeats it: *"`copy self`
  is rejected here because `Single<Element>` is `Escapable` when `Element` is."*
- **Experiment**: V2 (CONFIRMED) uses `@_lifetime(borrow self)`; the header §
  "Lifetime contract" (lines 31–37) records that an earlier `copy self` revision
  was valid only while `Single` was *unconditionally* `~Escapable`, and broke
  once `Single` gained conditional `Escapable`.
- **Commits**: `swift-iterator-primitives` `fd9e2ab` *"Iterable.makeIterator:
  use @_lifetime(borrow self), not copy self"*; experiment correction
  `swift-single-primitives` `156d9ca` *"Experiment: correct makeIterator
  contract to @_lifetime(borrow self)"*. `Verified: 2026-05-25`.

#### Finding 3 — the element bound for `Single: Iterable` is just `Copyable`

With the lifetime handled by the annotation (Finding 2), the element bound for
`Single`'s `Iterable` conformance is simply `Copyable` (not
`Copyable & Escapable`). The container vends `Once` by copying its element out;
`makeIterator()` only *borrows* `self`, so a move-only element cannot be reached
out of the borrow — move-only/borrowing traversal of a `Single` is a separate
(World-B collection-domain) concern.

- **Verified at**: `Single+Iterable.swift:17` —
  `extension Single: @retroactive Iterable where Element: Copyable`. The
  experiment header line 29 states the same: *"The element bound for `Single`'s
  conformance is then just `Copyable`."* `Verified: 2026-05-25`.

#### Finding 4 — `Single`/`Empty` gained conditional `Copyable`/`Escapable`

`Single` and `Empty` are **bare element-shape types**: `~Copyable & ~Escapable`,
carrying no world conformance themselves. Each gained conditional conformances
that restore each capability the bare declaration suppresses, and **each
conformance states the orthogonal axis as not-required** so it applies
regardless of the other capability:

```swift
extension Single: Copyable  where Element: Copyable  & ~Escapable {}
extension Single: Escapable where Element: Escapable & ~Copyable  {}
```

- **Verified at**: `Single.swift:41-43` and `Empty.swift:32-34` (identical
  shape). `swift-empty-iterator-primitives/.../Empty+Iterator.Protocol.swift:20`
  shows the same orthogonal-axis-not-required discipline on the iterator
  conformance (`extension Empty: @retroactive Iterator.`Protocol` where Element: ~Copyable & ~Escapable`)
  — now in its own bridge package per OQ-3 (`Verified: 2026-05-25`; the file
  moved out of `swift-iterator-primitives` in commit `ccf061d`). The
  conditional-conformance gap on `Single` (it was once *unconditionally*
  `~Escapable`) is the same gap whose closure forced Finding 2's `borrow self`.
- **Commits**: `swift-single-primitives` `06f4a7d` *"Add conditional
  Copyable/Escapable conformances to Single"*; `swift-empty-primitives`
  `695ab13` *"Add conditional Copyable/Escapable conformances to Empty"*.
  `Verified: 2026-05-25`.

### 6. The single inter-world seam — A is reached from B by copying out

The two worlds are joined by exactly **one thin, one-directional seam**: a
**World-B container vends a World-A iterator**, **copyable-only**, by copying
each element out.

- `Single` (World-B container) → `Once` (World-A iterator), via
  `Single+Iterable.swift` — `makeIterator()` *"lends a *copy* of its element to
  a fresh owned single-shot iterator … available only when `Element: Copyable`"*
  (`Verified: 2026-05-25`, Single+Iterable.swift:6-10, :17).
- The stdlib analog is `Array` (multipass collection) vending a `Sequence`
  iterator by copying.

The seam is copyable-only and one-directional **by necessity**: a borrow cannot
yield ownership of a move-only element (you cannot move out of something you
only borrow), so the only way World B can produce a World-A owned iterator is to
*copy*. The reverse direction (A→B, "materialize/collect an iterator into a
keepable container") is **an operation, not a conformance** — it allocates a
container and drains the iterator into it; it is not a protocol edge.

### 7. Source × world placement — the deterministic decomposition rule

**Bare element-shape types carry NO world conformance.** `Empty` and `Single`
are bare: `~Copyable & ~Escapable` with only the orthogonal conditional
`Copyable`/`Escapable` conformances of Finding 4. They live in their own
single-purpose packages (`swift-empty-primitives`, `swift-single-primitives`)
and depend on *nothing* world-specific.

**Each `(source × world)` conformance is its own integration package.** The
deterministic rule:

> Any conformance that needs a dependency the bare `*-primitives` package lacks
> → that conformance lives in its own integration package that depends on both
> the bare source package and the world package.

So a bare source never transitively depends on a world it does not use.

| Source | World conformance | Lives in | Status |
|--------|-------------------|----------|--------|
| `Single` (bare) | — | `swift-single-primitives` | landed |
| `Empty` (bare) | — | `swift-empty-primitives` | landed |
| `Single` → `Iterable` (World A) | `Single: @retroactive Iterable` (vends `Once`) | **`swift-single-iterator-primitives`** (deps: `swift-single-primitives` + `Iterable`/`Once Primitives` from `swift-iterator-primitives`) | landed (commit `ff223c3`) — `Verified: 2026-05-25` against its `Package.swift` deps |
| `Empty` → `Iterator.`Protocol`` (World A) | `Empty: @retroactive Iterator.`Protocol`` (always-`nil` `next()`) | **`swift-empty-iterator-primitives`** (deps: `swift-empty-primitives` + `Iterator Protocol` from `swift-iterator-primitives`) | landed (commit `27657ae`; ex-folding removed by `ccf061d`) — `Verified: 2026-05-25` against its `Package.swift` deps — see OQ-3 |

Both World-A bridges are now worked examples of the rule done right, and the §7
rule applies **uniformly** to `Single` and `Empty`. `Verified: 2026-05-25`: each
integration package contains exactly one source file
(`Single+Iterable.swift` / `Empty+Iterator.Protocol.swift`), each conformance is
`@retroactive` (the bridge owns neither type nor protocol), and each declares
deps only on the bare source package + the relevant `swift-iterator-primitives`
product — `swift-single-iterator-primitives/Package.swift:21–30`,
`swift-empty-iterator-primitives/Package.swift:20–30`. The earlier `Empty`
asymmetry (its conformance folded into `swift-iterator-primitives`, forcing a
dep on `swift-empty-primitives`) was the §7 rule's stress test; resolving it
*toward* the rule (commit `ccf061d` removed the fold, the dep, and the umbrella
re-export) confirms the rule's generality rather than carving an exception to
it.

## Outcome

**Status**: RECOMMENDATION (framework + one remaining parked direction, OQ-2).
The §5 findings are DECIDED facts (landed; experiment + commits cited inline). As
of v1.2.0, OQ-1 is DISSOLVED (the scalar World-B protocol was the existing
`Iterator.`Protocol`` with a `Borrow` element, shipped as
`Iterator.Borrow.`Protocol``, `0565cd6`; §4.5) and OQ-4 is RESOLVED (the
`Iterator.Borrow` → `Iterator.Span` rename, `3cb430a`; §3). The only parked
*direction* remaining is OQ-2 (explicit-position `Collection` reconciliation);
the only *language-gated* remainder is the `~Escapable`-element axis (§4.3b, §4.5).

**The decomposition framework** (recommended as durable ecosystem architecture):

1. Traversal decomposes along four axes (element-ownership, passes,
   granularity, position); ownership × passes collapses to the give-away /
   keep-and-lend duality for move-only elements (§2).
2. **World A** (owned, single-pass) = the iterator world:
   `Iterator.`Protocol`` + bulk `Iterator.Span.`Protocol`` (renamed from
   `Iterator.Borrow.`Protocol`` in `3cb430a`, OQ-4 resolved) + `Iterable` +
   concretes `Once`/`Empty`/`Iteration`/`Iterator.repeating` (§3).
3. **World B** (borrowed, multipass) = the borrowing-traversal world:
   explicit-position `Collection` (exists) + implicit-position *span/bulk*
   `Sequence.Borrowing.Protocol` (exists, `Escapable`-element-narrowed by the
   `Span` ceiling; §4.3a) + implicit-position *scalar* keep-and-lend
   `Iterator.Borrow.`Protocol`` — which v1.2.0 shows is simply
   `Iterator.`Protocol`` with `Element == Ownership.Borrow<T>`, **shipped** as
   `swift-iterator-borrow-primitives` `0565cd6` (no new protocol hierarchy,
   no new attachable; OQ-1 dissolved; only its `~Escapable`-element axis is
   language-blocked; §4.5) + the borrowed-element-view capability
   `Ownership.Borrow.`Protocol`` it lends (exists; §4.4) + the byte-stream
   `Cursor` (exists, specialized, rides `Ownership.Borrow.`Protocol``; §4.2)
   (§4).
4. The worlds join at one seam: B vends A copyable-only by copying out; A→B is
   an operation, not a conformance (§6).
5. Placement is deterministic: bare element-shape types carry no world
   conformance; each `(source × world)` conformance is its own integration
   package (§7).

**Why this is not a premature cross-cutting primitive** (per [RES-018]): the
framework proposes *no new top-level primitive*. It is a classification of
*existing* primitives plus a placement rule. The v1.2.0 collapse makes this even
sharper for the implicit-position scalar World-B case (formerly the one parked
*type*, OQ-1): it required **no new primitive at all** — the scalar World-B
"protocol" turned out to be the *existing* `Iterator.`Protocol`` with an
`Ownership.Borrow` element, so what shipped (`swift-iterator-borrow-primitives`,
`0565cd6`) is a thin **composition / integration package** (case (c) /
[ARCH-LAYER-001] composition over two existing L1 packages, §7), naming the
composition rather than introducing a new family. The [RES-018] cross-domain-fit
question is moot for it — there is no new cross-cutting primitive to gate. The
only residue is the `~Escapable`-*element* generalization, which remains gated on
language maturity (§4.3b, §4.5), and the explicit-position `Collection`
reconciliation (OQ-2), which is parked on its own terms.

### Open questions / parked items (NOT decided)

These are recorded as the framework's residual landscape per [RES-027]. Each is
flagged premise vs direction.

- **OQ-1 — DISSOLVED / RESOLVED 2026-05-25 (v1.2.0) — the "generic *scalar*
  World-B borrowing-traversal protocol" was a phantom.** v1.1.0 refined the
  v1.0.0 "does not exist / language-blocked" framing into a present-vs-absent
  inventory and identified the residue as "promote the proven scalar shape to a
  shipped generic primitive." v1.2.0 retires the question entirely for the
  implicit-position scalar case: **there was no missing protocol to promote.** A
  borrowing iterator is simply the *existing* `Iterator.`Protocol``
  (§3) instantiated with `Element = Ownership.Borrow<T>` — the same
  `next()` (already `@_lifetime(&self)`, already admitting `~Escapable` `Element`)
  serves both worlds, the world being chosen by the element type
  (`Element = T` ⇒ World A give-away; `Element = Ownership.Borrow<T>` ⇒ World B
  keep-and-lend), and multipass comes from the *existing* `Iterable`
  (`@_lifetime(borrow self) makeIterator()`), not a new attachable (§4.5). The
  abstraction the question was reaching for already existed; the perceived gap
  was a missing *name*, not a missing protocol. It shipped as the thin naming
  refinement `Iterator.Borrow.`Protocol``
  (`swift-iterator-borrow-primitives`, commit `0565cd6`) — a composition /
  integration package over `swift-iterator-primitives` +
  `swift-ownership-primitives` (§7), adding no new traversal mechanism and no new
  attachable. Validated end-to-end against the *real* `Iterator.`Protocol``/`Iterable`
  on Apple Swift 6.3.2 (move-only element, real-protocol conformance,
  generic-through-protocol drive, multipass — all green; §4.5). The v1.1.0
  `withNext` internal-iteration shape is superseded — the external
  `next() -> Ownership.Borrow<T>?` works directly via `@_lifetime(&self)` +
  `Ownership.Borrow(unsafeRawAddress:borrowing: self)` (§4.5). The **only**
  surviving piece of the original question is the `~Escapable`-*element* axis
  (lending a view of a genuinely non-escaping element rather than an
  `Ownership.Borrow` of a `~Copyable` one), which remains **language-blocked** at
  the `Swift.Span` / lifetime-dependent-associated-value ceiling
  (`Sequence.Iterator.Protocol.swift:113–115`;
  `2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`); revisit that
  axis when the language matures. The explicit-position `Collection` half is a
  *separate* question (OQ-2), still parked.

- **OQ-2 (direction) — the `Collection` reconciliation.** `Single: Collection`
  and `Empty: Collection` (move-only multipass via borrowing subscript) and the
  eventual `swift-single-collection-primitives` /
  `swift-empty-collection-primitives` integration packages are the natural
  World-B explicit-position conformances of the bare `Single`/`Empty` sources.
  `Verified: 2026-05-25`: neither package exists on disk today. This is the
  World-B half of the §7 rule applied to `Single`/`Empty`, mirroring the landed
  World-A half (`swift-single-iterator-primitives`). Direction, not premise —
  governed by `collection-sequence-protocol-detachment.md`'s detached
  `Collection` tree when built.

- **OQ-3 (premise) — RESOLVED 2026-05-25 — the symmetric integration-package
  consequence for `Empty`.** Applying the §7 rule symmetrically implies a
  **`swift-empty-iterator-primitives`** bridge (parallel to
  `swift-single-iterator-primitives`). At v1.0.0 this was *under discussion*:
  the §7 rule said "own integration package," but `Empty`'s `Iterator.`Protocol``
  conformance was **folded into `swift-iterator-primitives`** (which therefore
  depended on `swift-empty-primitives`), an asymmetry with `Single`/`Once`. The
  asymmetry has now been **corrected in favor of the §7 rule** — the rule wins,
  the folding was a violation:

  - **`swift-empty-iterator-primitives` was created** (commit
    `swift-empty-iterator-primitives` `27657ae`, *"Create
    swift-empty-iterator-primitives: Empty: Iterator.`Protocol` bridge"*). It
    contains exactly one source file — `Empty+Iterator.Protocol.swift` — declaring
    `extension Empty: @retroactive Iterator.`Protocol` where Element: ~Copyable & ~Escapable`
    (`Verified: 2026-05-25`, `Empty+Iterator.Protocol.swift:20`; `Failure = Never`,
    `next()` always `nil`). Its `Package.swift` deps are
    `swift-empty-primitives` + the `Iterator Protocol` product of
    `swift-iterator-primitives` (`Verified: 2026-05-25`, `Package.swift:20–30`) —
    structurally identical to `swift-single-iterator-primitives`.
  - **`iterator-primitives` no longer depends on `empty-primitives`** (commit
    `swift-iterator-primitives` `ccf061d`, *"Extract Empty's iterator conformance
    to swift-empty-iterator-primitives"*, which "Remove[d] the Empty Iterator
    Primitives target/product/test, drop[ped] the empty-primitives dependency,
    and drop[ped] the umbrella's re-export"). `Verified: 2026-05-25`:
    `swift-iterator-primitives/Package.swift` lists only `swift-carrier-primitives`
    and `swift-cardinal-primitives` as package dependencies (lines 63–66); there
    is no longer an "Empty Iterator Primitives" target/product, and
    `Sources/Empty Iterator Primitives/` is gone — `iterator-primitives` "now
    exposes only `Once` among the concrete iterators" (commit message).

  **The `@retroactive` detail.** Both bridge packages own *neither the type nor
  the protocol* they connect, so both conformances are `@retroactive` by
  necessity: `swift-empty-iterator-primitives` owns neither `Empty`
  (`swift-empty-primitives`) nor `Iterator.`Protocol``
  (`swift-iterator-primitives`) — `Empty+Iterator.Protocol.swift:17–20`;
  symmetrically `swift-single-iterator-primitives` owns neither `Single` nor
  `Iterable` — `Single+Iterable.swift:15–17` (`extension Single: @retroactive Iterable`).
  `Verified: 2026-05-25`. The integration-package rule now applies **uniformly**
  to both World-A bridges. (The v1.0.0 "may be defensible because `Empty` is
  re-exported to anchor the family — see `Iterator.swift:13-20`" rationale is
  superseded: `ccf061d` removed that re-export. The `Iterator.swift` namespace
  doc comment still describing the re-export is stale post-`ccf061d`; correcting
  that doc comment is a code-level follow-up outside this research doc's scope.)

- **OQ-4 — RESOLVED 2026-05-25 (v1.2.0) — `Iterator.Borrow` naming hazard.**
  `Iterator.Borrow` read like World-B "borrowing" but was World-A bulk (the
  `Span` borrows the iterator; §3). It was **renamed to `Iterator.Span`** (commit
  `swift-iterator-primitives` `3cb430a`), naming the tier for *what it yields* (a
  `Span`) rather than the ownership of the yield, which removes the hazard. The
  rename also frees the "borrow" stem under `Iterator` for its *correct* use: the
  v1.2.0 `Iterator.Borrow.`Protocol`` (§4.5), which genuinely yields an
  `Ownership.Borrow` (keep-and-lend), is a payload-named sibling of
  `Iterator.Span` (yields `Span`). `Verified: 2026-05-25`: the source directory
  is now `Sources/Iterator Span Primitives/`, the protocol is
  `Iterator.Span.`Protocol`` (`Iterator.Span.Protocol.swift:20`), and no
  `Iterator Borrow` directory remains.

### What this document does NOT decide

- The implicit-position scalar World-B "protocol" needed no authoring — it was
  the existing `Iterator.`Protocol`` with an `Ownership.Borrow` element, shipped
  as `Iterator.Borrow.`Protocol`` (`0565cd6`); OQ-1 is dissolved (§4.5). The
  `~Escapable`-*element* axis remains language-blocked and out of scope here.
- It does not build the `Collection` conformances or their packages (OQ-2).
- The `Iterator.Borrow` → `Iterator.Span` rename is **done** (`3cb430a`); OQ-4 is
  resolved (§3, §4.5).
- It does **not** propose any skill update (per session directive); if the §7
  placement rule and the World-A/B vocabulary stabilize, they are candidates for
  promotion to **primitives** / **modularization** per [RES-006a] — flagged, not
  executed.

## References

### Internal prior research (cited and extended, not duplicated)

- `collection-sequence-protocol-detachment.md` (DECISION) — `Collection`
  detached from `Sequence` because `next() -> Element?` is an owned (World-A)
  yield incompatible with multipass borrowing; the same duality this doc
  generalizes. **Closest prior art for World B's explicit-position shape.**
- `cursor-shape-a-vs-three-worlds.md` (IMPLEMENTED, Tier 3) — the *cursor-storage*
  "Three Worlds" (W1/W2/W3); single-generic `Cursor<DomainTag>` over
  `Ownership.Borrow.`Protocol`` storage. **Distinct "World" axis** — see the §0
  terminology-collision table. `Cursor` is this doc's concrete World-B citizen.
- `cursor-w1-expansion.md` (DECISION, Tier 3) — the deferral ("principled
  refuse") of generalizing `Cursor` to owned storage; the Phase-4 note this doc
  cites for `Cursor`'s specialization being deliberate.
- `cursor-abstractions-l1-ecosystem.md` (SUPERSEDED, Tier 3) — predecessor of
  the cursor-storage Three-Worlds framing.
- `ownership-borrow-protocol-unification.md` (DECISION) — `Ownership.Borrow.`Protocol``
  (the borrow-view capability `Cursor`'s storage rides on; §4.4 reads it as the
  generic World-B protocol's borrowed-element-view building block).
- `nested-view-vs-borrowed-naming.md` (DECISION) — Pattern 1 (passive
  borrow-view) vs Pattern 3 (stateful cursor); classifies `Cursor` as Pattern 3
  (§4.2 caveat 2); the same boundary keeps §4.4's "building block not partial
  realization" account honest (`Ownership.Borrow.`Protocol`` is Pattern 1).
- `iterator-span-buffer-elimination.md` (DECISION, Tier 2) — the bulk
  `nextSpan` ecosystem (the throughput tier of World A; the same `nextSpan`
  primitive underlies §4.3a's span/bulk World-B `Sequence.Borrowing.Protocol`).
- `2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`
  (RECOMMENDATION, Tier 3) — the same `~Copyable`/`~Escapable`-across-a-protocol
  language constraints that gate OQ-1's `~Escapable`-element axis (§4.3b).
- `swift-sequence-primitives/Research/element-tilde-escapable-stdlib-span-blocker.md`
  (cited by sequence-primitives' `README.md`) — the package's own record of the
  `Swift.Span<Element>: Element: Escapable` blocker that narrows
  `Sequence.Borrowing.Protocol` to the span/bulk Escapable-element tier (§4.3a).

### Source-code anchors (verified at HEAD 2026-05-25)

- `swift-iterator-primitives/Sources/Iterator Protocol/Iterator.Protocol.swift:31` — `Iterator.`Protocol`` (World-A foundation).
- `swift-iterator-primitives/Sources/Iterator Span Primitives/Iterator.Span.Protocol.swift:20` — World-A bulk tier; Element narrowed to `Escapable`. Renamed from `Iterator.Borrow.`Protocol`` in commit `3cb430a` (OQ-4 resolved; §3 hazard callout).
- `swift-iterator-borrow-primitives/Sources/Iterator Borrow Primitives/Iterator.Borrow.Protocol.swift` — `Iterator.Borrow.`Protocol`<Borrowed>` = `Iterator.`Protocol`` with `Element == Ownership.Borrow<Borrowed>`; the implicit-position scalar World-B protocol (no new hierarchy; OQ-1 dissolved; §4.5). (Package created as `swift-borrowing-iterator-primitives` in commit `0565cd6`, then renamed to `swift-iterator-borrow-primitives`; line numbers may have shifted with the rename.)
- `swift-iterator-borrow-primitives/Sources/Iterator Borrow Primitives/Iterator.Borrow.swift` — `Iterator.Borrow` namespace (hosts the refinement protocol; no concrete types; §4.5).
- `swift-iterator-borrow-primitives/Package.swift:21-30` — composition / integration-package deps (`swift-iterator-primitives` + `swift-ownership-primitives`; §7 / §4.5); adds no new attachable.
- `swift-iterator-primitives/Sources/Iterable/Iterable.swift:19,31,41` — attachable; suppressed associatedtype (Finding 1); `@_lifetime(borrow self)` (Finding 2).
- `swift-iterator-primitives/Sources/Once Primitives/Once.swift:24` — give-away one-element iterator.
- `swift-empty-iterator-primitives/Sources/Empty Iterator Primitives/Empty+Iterator.Protocol.swift:20` — Empty's `@retroactive Iterator.`Protocol`` conformance, now in its own bridge package (OQ-3 RESOLVED; moved out of iterator-primitives by `ccf061d`).
- `swift-empty-iterator-primitives/Package.swift:20-30` — Empty bridge integration-package deps (§7 worked example, symmetric with Single).
- `swift-iterator-primitives/Sources/Iterator Primitive/Iterator.swift:13-20` — `Iterator` namespace doc explaining the family topology. **Caveat**: this doc comment still describes `Empty` as "re-exported here with its iterator conformance"; that re-export was removed by `ccf061d` (OQ-3), so the comment is stale — a code-level follow-up, not relied on by this research doc.
- `swift-iterator-primitives/Sources/Iteration/Iteration.swift:29` + `Iterator.repeating.swift:17` — closure witness + repeat factory.
- `swift-single-primitives/Sources/Single Primitives/Single.swift:24,41-43` — bare container + conditional conformances (Finding 4).
- `swift-empty-primitives/Sources/Empty Primitives/Empty.swift:20,32-34` — bare empty + conditional conformances (Finding 4).
- `swift-single-iterator-primitives/Sources/Single Iterator Primitives/Single+Iterable.swift:15-17` — the inter-world seam (Findings 2+3, §6); `@retroactive` (OQ-3 symmetry).
- `swift-single-iterator-primitives/Package.swift:21-30` — integration-package deps (§7 worked example).
- `swift-cursor-primitives/Sources/Cursor Primitive/Cursor.swift:72` — `Cursor<DomainTag>` (concrete World-B citizen; §4.2; rides `Ownership.Borrow.`Protocol``, §4.4).
- `swift-sequence-primitives/Sources/Sequence Borrowing Primitives/Sequence.Borrowing.Protocol.swift:43,74-75` — `Sequence.Borrowing.Protocol`, the landed span/bulk implicit-position World-B protocol (`borrowing makeIterator()`, `@_lifetime(borrow self)`; §4.3a).
- `swift-sequence-primitives/Sources/Sequence Borrowing Primitives/Sequence.Borrowing.swift:12-29` — namespace doc drawing the consuming-vs-borrowing edge and recording the `Span`/SE-0427 element-`Escapable` narrowing (§4.3a).
- `swift-sequence-primitives/Sources/Sequence Iterator Primitives/Sequence.Iterator.Protocol.swift:68,113-115,143` — the `nextSpan` sole requirement; scalar `next()` returns an *owned* `Copyable` value (World-A face); `~Escapable`-element relaxation BLOCKED by `Swift.Span` (§4.3).
- `swift-ownership-primitives/Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift:30` — `Ownership.Borrow.`Protocol`` (canonical spelling), `associatedtype Borrowed: ~Copyable, ~Escapable` — the borrowed-element-view building block (§4.4).
- `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:72,120` — `Ownership.Borrow<Value>` (`Copyable`, `~Escapable` view over `~Copyable & ~Escapable Value`); the canonical `Protocol` typealias (§4.4).
- `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:280-283` — `Ownership.Borrow(unsafeRawAddress:borrowing:)` (`@_lifetime(borrow owner)`); the owner-anchored initializer that makes the external `next() -> Ownership.Borrow<T>?` recipe work, superseding v1.1.0's `withNext` (§4.5).

### Experiment

- `swift-single-primitives/Experiments/single-iterable-ownership-ceiling/Sources/single-iterable-ownership-ceiling/main.swift` — CONFIRMED, Apple Swift 6.3.2. V1 (no suppression) REFUTED; V2 (suppression + `@_lifetime(borrow self)`) CONFIRMED. Grounds Findings 1–3. Added in commit `swift-single-primitives` `9c0e8a2`.
- `swift-sequence-primitives/Experiments/suppressed-associated-types/Sources/main.swift` — CONFIRMED, Apple Swift 6.2.3; the refuted-stdlib variant (V6) "Revalidated: Swift 6.3.1 (2026-04-30) — PASSES". Builds the scalar World-B shape (`IterableProtocol`/`IterProto` with `associatedtype Element: ~Copyable`, `borrowing makeIterator()`, scalar `next() -> Element?`) over a genuinely `~Copyable` element (`Resource`); V1–V5 CONFIRM, V6 REFUTES stdlib-protocol reuse. Grounds §4.3b (the scalar keep-and-lend shape is expressible, not language-blocked).
- `swift-sequence-primitives/Experiments/two-tier-borrowing-overloads/Sources/main.swift` — CONFIRMED, Apple Swift 6.2.3; "Revalidated: Swift 6.3.1 (2026-04-30) — PASSES". Same `IterableProtocol`/`IterProto` pair plus a pointer-backed `ForEachView` whose `callAsFunction(_ body: (borrowing Base.Element) -> Void)` lends each `~Copyable` element by borrow; V2/V5 CONFIRM `~Copyable` borrowing traversal end-to-end, V6 CONFIRMS a two-tier borrowing/by-value overload split. Grounds §4.3b. `Verified: 2026-05-25`.

### Commits (this arc, verified present 2026-05-25)

| Repo | SHA | Subject |
|------|-----|---------|
| swift-iterator-primitives | `fd9e2ab` | Iterable.makeIterator: use @_lifetime(borrow self), not copy self |
| swift-iterator-primitives | `7f6dac7` | Fix Iterable: suppress Copyable & Escapable on the Iterator associatedtype |
| swift-single-primitives | `06f4a7d` | Add conditional Copyable/Escapable conformances to Single |
| swift-single-primitives | `156d9ca` | Experiment: correct makeIterator contract to @_lifetime(borrow self) |
| swift-single-primitives | `9c0e8a2` | Add experiment: single-iterable-ownership-ceiling |
| swift-empty-primitives | `695ab13` | Add conditional Copyable/Escapable conformances to Empty |
| swift-single-iterator-primitives | `ff223c3` | Create swift-single-iterator-primitives: Single: Iterable bridge |
| swift-empty-iterator-primitives | `27657ae` | Create swift-empty-iterator-primitives: Empty: Iterator.`Protocol` bridge (OQ-3 RESOLVED) |
| swift-iterator-primitives | `ccf061d` | Extract Empty's iterator conformance to swift-empty-iterator-primitives (removes the fold + empty-primitives dep + umbrella re-export; OQ-3 RESOLVED) |
| swift-iterator-primitives | `3cb430a` | Rename Iterator.Borrow → Iterator.Span (World-A bulk tier named for what it yields, a Span; "Borrow" misread as World-B keep-and-lend) — OQ-4 RESOLVED |
| swift-iterator-primitives | `a95e711` | Fix stale Iterator namespace doc: Empty conformance now lives in swift-empty-iterator-primitives (post-ccf061d), no longer re-exported here |
| swift-iterator-borrow-primitives | `0565cd6` | Create swift-iterator-borrow-primitives (created under prior name swift-borrowing-iterator-primitives, then renamed): Iterator.Borrow.`Protocol` — a borrowing iterator is Iterator.`Protocol` with an Ownership.Borrow element (composition of swift-iterator-primitives + swift-ownership-primitives) — OQ-1 DISSOLVED |

### Swift Evolution (background on the ownership model that forces §2)

- [SE-0390 — Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0427 — Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0446 — Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md)
- [SE-0447 — Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [SE-0503 — Suppressed Default Conformances on Associated Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md) — the mechanism Finding 1 uses to suppress `Copyable`/`Escapable` on `Iterable.Iterator`.
