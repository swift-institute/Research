# Count Direct vs Fluent + New `Sequence.Hint` Namespace

<!--
---
version: 1.0.0
last_updated: 2026-05-21
status: DECISION
tier: 1
scope: package
---
-->

## Context

The revision pitch [_Iterable_ (formerly _BorrowingSequence_)] adds two
optimization-hint customization points to its protocol — `underestimatedCount`
and `_customContainsEquatableElement`. We don't have direct equivalents.

Concurrently, our existing `seq.count` shape used `Property.Inout` as a
fluent root:

```swift
seq.count             // Property.Inout<Sequence.Count, Self>
seq.count.all         // Cardinal (eager total)
seq.count.where { p } // Cardinal (filtered)
```

— a deliberate institute pattern but one where the most-common case
(eager total count) carried `.all` ceremony absent from stdlib's
`Collection.count`. The user instinct surfaced during the pitch
comparison: "ideal is `seq.count: Cardinal` direct, AND a place for
`.underestimated`."

A prior arc (commit `6f2f9e3`, D8) had already removed an
`underestimatedCount: Int { 0 }` extension from
`Sequence.Protocol+Swift.Sequence.swift` because it collided with
`Swift.Sequence`'s same-name default for dual-conformers. Any
re-introduction has to avoid that collision shape.

[_Iterable_ (formerly _BorrowingSequence_)]: https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834

## Question

What is the right shape for: (a) the eager total count, (b) the
predicate-filtered count, and (c) an under-estimate hint for capacity
reservation?

In particular: how can `seq.count` give the total directly AND
`.underestimated`-style hints still attach to a meaningful root, given
that Swift names resolve `seq.count` to a single declaration?

## Analysis

### Option 1 — additive (preserve fluent root)

Status quo plus new accessor on the existing `Sequence.Count` tag.

```swift
seq.count              // Property.Inout<Sequence.Count, Self>  (existing)
seq.count.all          // Cardinal (existing)
seq.count.where { p }  // Cardinal (existing)
seq.count.underestimated // Cardinal — NEW (default .zero)
```

| Axis | Effect |
|---|---|
| Migration cost | Zero |
| Match stdlib `Collection.count` mental model | No — direct count remains `.count.all` |
| Hint extensibility | Bound to `Sequence.Count`; future `.contains` hint must invent a parent |
| Eager-count ergonomics | Worse than stdlib |

### Option 2 — direct `count` + method overload + separate `estimate`

```swift
seq.count             // Cardinal (NEW shape; eager total)
seq.count(where: { }) // Cardinal (NEW shape; filtered, method overload)
seq.estimate          // Cardinal (NEW; hint)
```

| Axis | Effect |
|---|---|
| Migration cost | Breaks `.count.all` / `.count.where` callers (this package + 1 experiment + 1 test file + ~6 doc references) |
| Match stdlib mental model | Yes |
| Hint extensibility | "estimate" doesn't generalize — the pitch's second hint (`_customContainsEquatableElement`) has no natural sibling |
| Semantic precision | "estimate" reads "approximate"; "underestimate" reads "≤ actual". Subtle but distinct. |

### Option 3 — direct `count` + method overload + `seq.hint.*` namespace

```swift
seq.count             // Cardinal (eager total)
seq.count(where: { }) // Cardinal (filtered, method overload)
seq.hint.count        // Cardinal (NEW; under-estimate)
seq.hint.contains(_:) // Bool? (FUTURE; pitch's _customContainsEquatableElement)
```

| Axis | Effect |
|---|---|
| Migration cost | Same as Option 2 — same callers migrate |
| Match stdlib mental model | Yes |
| Hint extensibility | YES — `seq.hint.*` is a coherent namespace for cheap, conformer-supplied advisory values. Both pitch hints land naturally. |
| Semantic precision | "underestimated" preserved; hint name un-collides with stdlib's `underestimatedCount` (so the D8 dual-conformance issue does NOT recur) |
| Architectural shape | New `Sequence.Hint` Property.Inout tag; `Sequence.Count` tag retires; tests migrate from `extension Sequence.Count { @Suite struct Test }` to the flat `extension Sequence { @Suite struct \`Count Test\` }` shape (already used by `Sequence.Map Tests.swift`) |

### Why not "all three"

A hybrid `seq.count` returning a Cardinal-coercing struct that ALSO
carries `.underestimated`/`.where` accessors was explored. Swift has no
implicit conversion mechanism for arbitrary types; the only way to make
`seq.count` be both a Cardinal value at one call site AND a fluent root
at another is via a single declaration whose return type implements
both, which doesn't exist in Swift's type system.

### Why the `Sequence.Hint` namespace is load-bearing

The pitch carries TWO hint-shaped customization points:

| Pitch hint | Default | Conformer override use |
|---|---|---|
| `var underestimatedCount: Int { get }` | `0` | Containers with stored count avoid O(n) capacity probing |
| `func _customContainsEquatableElement(_:) -> Bool?` | `nil` | Sets/dicts override O(N) `contains` walk with O(1) hash lookup |

Both are "cheap, conformer-supplied advisory values." Both belong under
the same root in an institute-flavored API. Options 1 and 2 give the
first hint a home but force the second hint to invent its own root
later. Option 3 establishes the root now and lets the second hint
attach naturally when adoption follows.

The cost of establishing `seq.hint.*` today is one new tag enum
(`Sequence.Hint`) + one accessor (`var hint`) + one Property.Inout
extension (`var count: Cardinal { .zero }`) — three small files. The
cost of NOT establishing it is having to bikeshed the second hint's
parent later, and possibly stranding the first hint at a name that
doesn't compose.

### How the D8 collision is avoided

Commit `6f2f9e3` removed `underestimatedCount: Int { 0 }` from a
`Sequence.Protocol where Self: Copyable, Element: Copyable` extension
because dual-conformers (types that conform to both
`Sequence.Protocol` AND `Swift.Sequence`) saw two equally-valid
defaults of the same property name.

Option 3's `seq.hint.count: Cardinal` uses a different property name
(`hint` then `count`, not `underestimatedCount`), accessed through a
Property.Inout root. There is no `Swift.Sequence.hint` to collide with;
the D8 ambiguity shape does not recur.

## Outcome

**Status: DECISION** (implemented in commit `ac09a43`).

**Choice**: Option 3.

**Why this option dominates**:

- Honors the stdlib-aligned `seq.count: Cardinal` ergonomics for the
  common case.
- Establishes `seq.hint.*` as the institute's hint namespace, future-
  proofing the pitch's second customization point with one architectural
  decision instead of two ad-hoc ones.
- Migration scope is bounded: `Tests/Sequence Primitives Tests/Sequence.Count Tests.swift`
  +
  `Experiments/sequence-operations-discovery/Sources/main.swift` + ~6
  doc-comment references in the package's source. No downstream consumer
  in the workspace imports `Sequence_Primitives`'s `.count.all` /
  `.count.where` paths (verified by grep across `swift-primitives`,
  `swift-standards`, `swift-foundations` at write time, 2026-05-21).
- The D8 collision shape does NOT recur because the institute-side name
  is `seq.hint.count`, not `underestimatedCount`.

**Implementation shape** (landed in `ac09a43`):

```swift
// Sequence.Hint.swift — new tag enum
extension Sequence { public enum Hint {} }

// Sequence.Protocol+Hint.swift — fluent accessor on Sequence.Protocol
extension Sequence.`Protocol` where Self: ~Copyable {
    public var hint: Property<Sequence.Hint, Self>.Inout { ... }
}

// Sequence.Hint+Property.Inout.swift — the count hint
extension Property.Inout
where Base: Sequence.`Protocol`, Base: ~Copyable, Tag == Sequence.Hint {
    public var count: Cardinal { .zero }
}

// Sequence.Protocol+Count.swift — direct count + method overload
extension Sequence.`Protocol` where Self: ~Copyable, Element: Copyable {
    public var count: Cardinal {
        consuming get { /* eager iteration */ }
    }
    
    public consuming func count(
        where predicate: (borrowing Element) -> Bool
    ) -> Cardinal { /* filtered iteration */ }
}
```

`Sequence.Count` tag and `Sequence.Count+Property.Inout.swift` removed.
Test file `Sequence.Count Tests.swift` migrated to use the flat
`extension Sequence { @Suite struct \`Count Test\` }` shape.

`Sequence.Protocol+collect.swift` wired to `self.hint.count` for
`Array.reserveCapacity` before iteration.

**Cross-package coordination note**: `swift-collection-primitives` mirrors
the prior `.count.all` / `.count.where` Property.Inout shape on its own
`Collection.Count` tag. With this DECISION, `sequence-primitives` and
`collection-primitives` diverge on the `count` API shape. Migrating
`collection-primitives` to match is a class-(c) ecosystem decision queued
separately; not done in this arc (deferred per
`feedback_class_c_ecosystem_stop_not_dispatch`).

**Future**: when adopting `_customContainsEquatableElement`-shape fast-
path overrides (e.g., when shipping `Set.Primitives` / `Dictionary.Primitives`
overrides), the second inhabitant of `Sequence.Hint` lands as:

```swift
extension Property.Inout
where Base: Sequence.`Protocol`, Base: ~Copyable, Tag == Sequence.Hint {
    public func contains(_ element: borrowing Base.Element) -> Bool? { nil }
}
```

— no further architectural decision needed; the namespace is in place.

## References

- [Revision pitch: _Iterable_ (formerly _BorrowingSequence_)](https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834) — Swift Forums
- Commit `6f2f9e3` (D8) — prior removal of `underestimatedCount` from
  `Sequence.Protocol+Swift.Sequence.swift`; the dual-conformance
  ambiguity this DECISION sidesteps
- Commit `ac09a43` — landing of Option 3
- Companion: `element-tilde-escapable-stdlib-span-blocker.md` — the
  axis on which we matched the pitch is the protocol's `Element`
  constraint (where we DEFERRED due to upstream `Swift.Span<Element>`),
  while this DECISION covers the axes where we exceeded the pitch (the
  count + hint shape, and especially the namespace for future hints)
- Companion comparison: `iterable-revision-pitch-comparison.md`
