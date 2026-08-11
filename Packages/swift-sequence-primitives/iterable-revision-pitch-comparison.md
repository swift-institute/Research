# `Iterable` (formerly `BorrowingSequence`) Revision Pitch ↔ `sequence-primitives` Comparison

<!--
---
version: 1.0.0
last_updated: 2026-05-21
status: ANALYSIS
tier: 2
scope: cross-package
---
-->

## Context

The revision pitch [_Iterable_ (formerly _BorrowingSequence_)] is
actively under review on Swift Forums. It proposes a new
stdlib-level iteration protocol family explicitly designed to support
move-only and (per the pitch text) nonescapable elements, with a span-
based iteration model.

Our `swift-sequence-primitives` was designed before this pitch, against
the prior `BorrowingSequence` proposal, and has been in iteration for
about 3 months. The protocols are structurally close but not identical
to the pitch. This document is the comparison — what aligns, what we
do that the pitch doesn't, what the pitch does that we don't, and what
we deferred (with reasoning).

The comparison informs three things:

1. Whether to align our protocols closer to the pitch (where we can).
2. Whether to keep our architectural extensions where they exceed the
   pitch (where the pitch has no equivalent).
3. Whether to file forum engagement on any gaps we've identified that
   the pitch thread hasn't surfaced.

[_Iterable_ (formerly _BorrowingSequence_)]: https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834

## Question

Across the iteration-protocol design space — protocol shape, element
constraints, iteration mechanism, ownership model, algorithms layer,
termination signaling — how do `sequence-primitives` and the active
revision pitch differ, and what should we do about each delta?

## Analysis

### Convergent design choices

These axes were independently reached by both designs:

| Axis | Pitch | `sequence-primitives` |
|---|---|---|
| Protocol + iterator both `~Copyable, ~Escapable` | ✓ | ✓ (`Sequence.Protocol.swift:92`, `Sequence.Iterator.Protocol.swift:109`) |
| Span-based batched iteration via `nextSpan(maximumCount:)` | ✓ | ✓ (`Sequence.Iterator.Protocol.swift:114-125`) |
| `@_lifetime(&self)` on returned span | ✓ | ✓ (`Sequence.Iterator.Protocol.swift:124`) |
| Borrowing `makeIterator` (`@_lifetime(borrow self)`) | ✓ | ✓ (`Sequence.Borrowing.Protocol.swift:69`) |
| Empty-span sentinel for exhaustion | ✓ | ✓ |
| `~Copyable` elements supported | ✓ | ✓ |
| Bridge to existing stdlib `Sequence` | ✓ (`IterableIteratorAdapter`) | ✓ (`Sequence.Protocol+Swift.Sequence.swift`) |

These represent independent convergence on the same set of primitives,
which is positive evidence that the shape is well-founded.

### Where the pitch claims something we cannot match today

#### 1. `Element: ~Copyable, ~Escapable` on the protocol

The pitch's revision broadens `Element` to `~Copyable, ~Escapable`. Per
quoted "Changes from Original Version":

> Nonescapable elements: `Element` is now constrained to `~Copyable & ~Escapable`,
> instead of just `~Copyable`.

We DEFERRED on this axis. The full empirical investigation is in the
companion document — see [`element-tilde-escapable-stdlib-span-blocker.md`].
Summary: `Swift.Span<Element>` requires `Element: Escapable` across
both Swift 6.3.2 stable and the 6.5-dev May 12 nightly; the relaxation
cannot compile. The pitch's own concrete `extension Span: Iterable`
conformance reverts to `Element: ~Copyable` for the same reason. The
stdlib's actually-shipped `BorrowingIteratorProtocol` (in 6.5-dev)
likewise uses `Element: ~Copyable` only — backing off from the pitch's
broader text.

This is a **gap unexamined on the pitch thread** — see the "Forum
engagement opportunity" section below.

[`element-tilde-escapable-stdlib-span-blocker.md`]: ./element-tilde-escapable-stdlib-span-blocker.md

#### 2. Typed throws (`Failure`)

The pitch:

```swift
associatedtype Failure: Error = Never

@_lifetime(&self)
mutating func nextSpan(maximumCount: Int) throws(Failure) -> Span<Element>
```

We have no `Failure` axis on `Sequence.Iterator.Protocol`. The pitch's
rationale is Embedded Swift's typed-throws requirement and integration
with throwing iteration via `for try ... in`.

**Decision: do NOT adopt.** Per the institute's existing architecture
(`project_parser_serializer_coder_system_framing.md`), throwing
pipelines belong to `Parser.Protocol` / `Coder.Protocol`, not the
sequence layer. Adding `Failure` to our iteration protocol would either
duplicate codec-error machinery into sequence-primitives (architectural
inversion) or force every consumer to either propagate `Failure` or
specialize on `Failure == Never`, doubling the algorithm surface area.

The pitch made a different architectural call because they don't have
a separate parser-primitive layer.

#### 3. `underestimatedCount` and `_customContainsEquatableElement`

Two hint-shaped customization points on the pitch's protocol:

```swift
var underestimatedCount: Int { get }
func _customContainsEquatableElement(_ element: borrowing Element) -> Bool?
```

We ADOPTED both — but as a new `Sequence.Hint` namespace rather than
direct protocol requirements. See the companion design doc
[`count-direct-vs-fluent-and-hint-namespace.md`] for the full Option 1/
Option 2 / Option 3 analysis. Summary:

- `seq.hint.count: Cardinal` — landed in commit `ac09a43`. Default
  `.zero`, conformer-overridable on `Property.Inout<Sequence.Hint, ConcreteType>`.
- `seq.hint.contains(_:): Bool?` — namespace is in place; concrete
  hint not yet shipped (queued for when `Set.Primitives` /
  `Dictionary.Primitives` adopt fast-path overrides).

The `Sequence.Hint` namespace lets us collect both pitch hints (and
future hints) under one root without polluting the protocol surface.

[`count-direct-vs-fluent-and-hint-namespace.md`]: ./count-direct-vs-fluent-and-hint-namespace.md

#### 4. `skip(by maximumOffset:)`

Pitch makes it a protocol requirement (with default impl). We have it
as a default extension on `Sequence.Iterator.Protocol` (`Iterator.Protocol.swift:149-169`),
not as a requirement. The pitch's design encourages every conformer to
consider whether they have an O(1) skip; ours lets conformers silently
inherit the O(n) default.

Not adopted. The cost of forcing every iterator to acknowledge `skip`
is mostly noise for lazy wrappers (where O(n) is unavoidable anyway).
Conformers with O(1) skip override via the same default-extension
mechanism that the pitch uses.

### Where `sequence-primitives` exceeds the pitch

#### A. Consuming + Borrowing dual-protocol design

The pitch has only `Iterable` with `borrowing func makeIterableIterator()`.
We split:

- `Sequence.Protocol` — `consuming makeIterator()`: enables lazy
  pipelines where each wrapper (`Sequence.Map`, `Sequence.Filter`,
  …) consumes the previous one. The whole chain is `~Copyable` and
  lifetime-tracked.
- `Sequence.Borrowing.Protocol` — `borrowing makeIterator()`: matches
  the pitch's design exactly. For contiguous storage that lends
  without consuming.

The pitch's single-protocol model can't represent
`source.map { }.filter { }.collect()` lazy chains without every wrapper
holding a borrow of the previous wrapper — a tower of nested borrow
scopes. Our consuming model flattens this: wrapper owns base, iterator
owns wrapper, lifetime is one chain.

**This is the key architectural advantage and the chief reason a
single-protocol pitch would be a regression for us.**

#### B. `Nest.Name` naming

Pitch (acknowledged on the thread by reviewers as "obviously not
great"):

- `Iterable`, `IterableIterator`, `IterableIteratorProtocol`,
  `makeIterableIterator()`, `SpanIterator`, `IterableIteratorAdapter`

Ours, per `[API-NAME-001]` / `[API-NAME-002]`:

- `Sequence.Protocol`, `Sequence.Iterator.Protocol`,
  `Sequence.Borrowing.Protocol`, `Sequence.Map.Iterator`,
  `Sequence.Span`

No compound identifiers. The collision the pitch is trying to avoid
(`makeIterableIterator` vs `makeIterator`) doesn't arise for us
because we use a nested namespace — `Sequence.Iterator.Protocol` is a
distinct identifier from `Swift.IteratorProtocol`, and our
`makeIterator()` on `Sequence.Protocol` doesn't collide with stdlib
because consumers explicitly write `import Sequence_Primitives` and
call against the nested type.

#### C. Typed `Cardinal` instead of `Int`

Pitch:

```swift
mutating func nextSpan(maximumCount: Int) throws(Failure) -> Span<Element>
mutating func skip(by maximumOffset: Int) throws(Failure) -> Int
```

Ours (`Sequence.Iterator.Protocol.swift:114`):

```swift
mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>
```

`Cardinal` (from `swift-index-primitives`) is a typed unsigned count —
no negative `maximumCount`, no domain confusion with `Offset`, no
implicit narrowing at the platform boundary. The pitch will inherit
`Int`'s problems forever.

#### D. `Drain.Protocol` / `Consume.Protocol` / `Clearable`

Pitch has no story for "consume the container while iterating," which
is essential for `~Copyable` element ownership transfer. Our three-way
distinction:

- `Sequence.Clearable` — `mutating func removeAll()`; enables
  `.forEach.consuming { borrowing element in /* move out */ }`
- `Sequence.Drain.Protocol` — `mutating func drain(_: (consuming Element) -> Void)`;
  container survives empty
- `Sequence.Consume.Protocol` — `consuming func consume() -> View<Element, State>`;
  container destroyed

Without these, the pitch can't model "transfer ownership of every
element from this `Array<NonCopyable>` to a closure." A future pitch
would have to bolt this on; we have it now.

#### E. Property.Inout fluent terminals

Our terminal-operations layer (`Sequence.ForEach`, `Sequence.Satisfies`,
`Sequence.Contains`, `Sequence.First`, `Sequence.Reduce`,
`Sequence.Hint`) routes through phantom-tagged `Property<Tag, Base>.Inout`,
giving us:

```swift
seq.satisfies.all { $0.isValid }         // Bool
seq.satisfies.any { $0.matches(query) }  // Bool
seq.satisfies.none { $0.isExpired }      // Bool
seq.reduce.into([:]) { acc, x in ... }   // Dictionary
seq.forEach.consuming { x in ... }       // requires Clearable
seq.hint.count                            // Cardinal (underestimate)
```

The pitch will need to add each of these as ad-hoc method names. We
can add new terminal operations by introducing a tag enum + a single
extension — no proliferation of `Sequence.Protocol` requirements.

(Note: `seq.count` itself is NOT routed through Property.Inout — see
[`count-direct-vs-fluent-and-hint-namespace.md`] for the design
rationale on that single-form vs multi-form decision.)

### Philosophical divergences

Three axes where the pitch is more ergonomic for users but only with
language-level support we don't have:

| Axis | Pitch | `sequence-primitives` |
|---|---|---|
| `for-in` syntax | Compiler desugaring of `for x in iterable` | Use `.forEach { }` (deliberate non-goal) |
| `next() -> Element?` single-element | Declined (intentional, due to ~Copyable+Optional issue) | Provided as default extension on `Element: Copyable` |
| Single vs split protocol | Unified `Iterable` | `Sequence.Protocol` (consuming) + `Sequence.Borrowing.Protocol` (borrowing) |

The `for-in` axis is a Swift Evolution-only capability. The other two
are deliberate institute design calls.

### Stdlib integration adapter gaps

Five adapter gaps identified during the audit, all queued as deferred
follow-ups:

1. `Swift.Span: Sequence.Borrowing.Protocol` — direct conformance.
   Iterator types exist (`Swift.Span.Iterator` and `Swift.Span.Iterator.Batch`),
   but `Span` itself doesn't conform. Pitch has `extension Span: Iterable`.
2. `Swift.MutableSpan: Sequence.Borrowing.Protocol`
3. `Swift.RawSpan: Sequence.Borrowing.Protocol`
4. `Swift.InlineArray: Sequence.Protocol`
5. Generic `Sequence.Iterator.Adapter<I: IteratorProtocol>` wrapping
   any stdlib iterator (the pitch's `IterableIteratorAdapter`).

### Forum engagement opportunity

Per the focused re-read of the pitch thread:

- The revision deliberately broadened `Element` to `~Copyable, ~Escapable`
  with a stated changelog entry.
- The thread has **zero discussion** of the `Swift.Span<Element>`
  Escapable-requirement contradiction.
- The pitch's own concrete `extension Span: Iterable` uses
  `Element: ~Copyable` only — the broadened protocol declaration is
  not satisfied by the pitch's own primary conformance.
- The actually-shipped stdlib `BorrowingIteratorProtocol` (already in
  6.5-dev) backed off to `Element: ~Copyable`.

This is a real reviewer catch. A forum reply identifying the gap would
likely affect the pitch's eventual proposal: either authors commit to a
parallel `Swift.Span<Element: ~Escapable>` relaxation, or they walk
back the broader `Element` constraint to match implementation reality.

Not auto-dispatched — `/engagement-process` is the right channel for
the writeup, gated on principal direction.

## Outcome

**Status: ANALYSIS**

This document is the analytical record; the actionable decisions live
in the companion documents:

- **DEFERRED** (Element `~Escapable` relaxation) →
  [`element-tilde-escapable-stdlib-span-blocker.md`]
- **DECISION** (count + hint shape) →
  [`count-direct-vs-fluent-and-hint-namespace.md`]
- **NOT ADOPTED** (typed `Failure`) → no separate doc; architectural
  divergence rationale recorded in §2 above
- **DEFERRED** (5 stdlib integration adapters) → recorded in §5 above;
  any single adapter can be picked up as a small follow-up arc

**Open follow-ups across the comparison**:

1. **Cross-package alignment.** `swift-collection-primitives` mirrors
   the old `.count.all` / `.count.where` shape on its own
   `Collection.Count` tag. The naming convention diverges between
   `sequence-primitives` (post-DECISION direct count) and
   `collection-primitives` (still Property.Inout fluent). Class-(c)
   ecosystem decision queued separately.

2. **Forum engagement.** The `Element: ~Escapable` vs `Swift.Span<Element>`
   gap is unraised on the pitch thread. High-leverage reviewer-style
   contribution.

3. **Stdlib integration adapter cohort.** Land one or more of the 5
   gaps. `Swift.Span: Sequence.Borrowing.Protocol` is the smallest and
   most-isolated; the others scale similarly.

4. **`Sequence.Hint.contains(_:)`** — the second inhabitant of the
   new hint namespace, queued for when `Set.Primitives` /
   `Dictionary.Primitives` ship fast-path overrides.

## References

- [Revision pitch: _Iterable_ (formerly _BorrowingSequence_)](https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834)
  — Swift Forums
- [`element-tilde-escapable-stdlib-span-blocker.md`] — empirical investigation
- [`count-direct-vs-fluent-and-hint-namespace.md`] — count + hint design
- `swiftlang/swift` source at commit `e578b3a` (2026-05-05) —
  `stdlib/public/core/Span/Span.swift:29` for the Span constraint
- `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a` toolchain swiftinterface —
  for the actually-shipped `BorrowingIteratorProtocol` and `SpanIterator`
- Commit `ac09a43` — landing of the count + hint design
- Commit `6f2f9e3` (D8) — prior removal of the `underestimatedCount`
  ambiguity that motivated the `seq.hint.*` namespace name choice
