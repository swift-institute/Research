# Principled Absence — `Sequence` / `Collection`

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` declares `Tagged<Tag, Underlying>: Sequence where Underlying: Sequence` (and `Collection where Underlying: Collection`), with the iterator and index forwarded to `Underlying`. This makes `Tagged<Tag, [Int]>` itself iterable: `for x in tagged { … }` walks the wrapped Array.

Swift Institute's `swift-tagged-primitives` deliberately removes both conformances. The argument is **wrapper-vs-content conflation**:

A `Tagged<Tag, [Int]>` is conceptually "an Array tagged for type-safety" — the wrapper exists because we want to distinguish it from another `Tagged<OtherTag, [Int]>`. Making the wrapper itself iterable obscures the type boundary: consumers writing `for x in tagged { … }` are operating on the wrapped Array's elements through the wrapper, treating the wrapper as a transparent passthrough. The wrapper's purpose was the opposite — to *enforce* the type boundary.

The correct consumer pattern is `for x in tagged.underlying { … }` — explicit unwrap, then iterate. The unwrap is the place where the consumer acknowledges they are now operating on the wrapped value, not the wrapper.

Sequence and Collection are treated together because:
1. The wrapper-vs-content rationale applies identically.
2. Collection's requirements are a superset of Sequence's; a verdict on Sequence determines Collection.
3. Pointfreeco conforms both unconditionally; the Institute removes both unconditionally.

This document establishes the rationale and empirically classifies the absence.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `Sequence` and/or `Collection` (when `Underlying` does)? If absent by default, what is the legitimate opt-in path, and is the conformance even authorable on Swift 6.3.1?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.6 — original removal rationale (one paragraph).
- [`principled-absence-rawrepresentable.md`](./principled-absence-rawrepresentable.md) / [`principled-absence-strideable.md`](./principled-absence-strideable.md) / [`principled-absence-identifiable.md`](./principled-absence-identifiable.md) / [`principled-absence-losslessstringconvertible.md`](./principled-absence-losslessstringconvertible.md) — same-day pattern instances; established the empirical-classification methodology.

## Analysis

### Option A — Conform unconditionally (pointfreeco pattern)

```swift
extension Tagged: Sequence where Underlying: Sequence {
    public func makeIterator() -> Underlying.Iterator {
        underlying.makeIterator()
    }
}

extension Tagged: Collection where Underlying: Collection {
    public typealias Index = Underlying.Index
    public typealias Element = Underlying.Element
    public var startIndex: Index { underlying.startIndex }
    public var endIndex: Index { underlying.endIndex }
    public subscript(position: Index) -> Element { underlying[position] }
    public func index(after i: Index) -> Index { underlying.index(after: i) }
}
```

**Pros**:
- Drop-in `for x in tagged { … }` ergonomics for `Tagged<Tag, [T]>`, `Tagged<Tag, Set<T>>`, etc.
- Compatible with stdlib functions taking `T: Sequence` or `T: Collection`.

**Cons**:
1. **Conflates wrapper with contents**. `tagged.first` is supposed to be a property of the wrapper; consumers who know they're working with `Tagged<Tag, [Int]>` will reach for `tagged.first` and get `Int?`, not realizing they crossed the type boundary. The wrapper became transparent.
2. **`for x in tagged` reads identically to `for x in tagged.underlying`** but only one of those is honest about what's happening. Implicit semantic shift.
3. **Generic algorithms over `T: Sequence` operating on Tagged values silently iterate the wrapped collection** — a `T: Sequence` constraint is broad and many algorithms will accept Tagged + iterate it as if it were the inner Array, in code paths the consumer didn't expect to apply to a wrapper type.
4. **Defeats the phantom-typing claim for collection-valued Tagged**. The whole point of `Tagged<Tag, [Int]>` was to distinguish it from `Tagged<OtherTag, [Int]>`. Once Sequence is conformed, generic `for-in` and stdlib algorithms treat them as functionally identical (same Element, same iteration).

### Option B — SLI opt-in

```swift
// In Sources/Tagged Primitives Standard Library Integration/Tagged+Sequence.swift
extension Tagged: Sequence
where Tag: ~Copyable & ~Escapable, Underlying: Sequence & Escapable {
    public func makeIterator() -> Underlying.Iterator {
        underlying.makeIterator()
    }
}
```

**Pros**:
- Default safety preserved.
- Opt-in for consumers who want collection-style ergonomics.

**Cons**:
- Wrapper-vs-content conflation cost remains, behind import gate.
- Consumers who import SLI for Strideable accidentally pick up Sequence/Collection too — package-level granularity.

### Option C — Hard absence + explicit `.underlying` unwrap

```swift
let tagged: Tagged<User, [Int]> = ...

// Honest pattern — consumer unwraps explicitly:
for x in tagged.underlying { ... }
let first = tagged.underlying.first
let count = tagged.underlying.count
```

**Pros**:
- Honest about the wrapper boundary. Every iteration / first / count is preceded by `.underlying`, marking the type-boundary crossing.
- Generic algorithms over `T: Sequence` cannot accidentally consume Tagged values as if they were the inner collection.
- Preserves the wrapper's purpose: type discrimination.

**Cons**:
- Slightly more verbose call sites (`.underlying` per access).
- Cannot pass Tagged to `T: Sequence`-constrained APIs without unwrapping (which is, by design, the point).

## Empirical verification

[`Experiments/tagged-no-sequence-collection/`](../Experiments/tagged-no-sequence-collection/) tests Option B's authorability on Swift 6.3.1 for both Sequence and Collection. See experiment for the empirical SOFT/HARD classification.

## Outcome

**[Updated post-experiment]**:

The experiment empirically verified that **Option B IS authorable on Swift 6.3.1** for both Sequence and Collection — function-style witnesses (`makeIterator`, `subscript`, `index(after:)`) bypass the structural `~Escapable` blocker.

**Soft / Hard classification**: **SOFT** absence — **shipped in SLI** at [`Sources/Tagged Primitives Standard Library Integration/Tagged+Sequence.swift`](../../Sources/Tagged%20Primitives%20Standard%20Library%20Integration/Tagged+Sequence.swift) and [`Sources/Tagged Primitives Standard Library Integration/Tagged+Collection.swift`](../../Sources/Tagged%20Primitives%20Standard%20Library%20Integration/Tagged+Collection.swift) (2026-04-30). Consumers `import Tagged_Primitives_Standard_Library_Integration` to opt in.

**However**: the **default-safe** Option C (`tagged.underlying.first`) is the recommended consumer pattern. The wrapper-vs-content conflation cost from Option B is meaningful for Tagged-family consumers who care about type-boundary visibility (which is most of the Institute primitives ecosystem). SLI opt-in is for Tagged consumers integrating with external `Sequence` / `Collection`-constrained APIs that they cannot refactor to take `.underlying`.

The experiment also demonstrates the conflation cost — generic algorithms over `T: Sequence` treat a `Tagged<Tag, [Int]>` and a `[Int]` interchangeably once the conformance is opt-in, which is the type-boundary erosion phantom-typing was meant to prevent.

**Forward-compatibility note**: Empirical finding specific to Swift 6.3.1; revalidate on toolchain updates.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.6 (the seed paragraph).
- [Swift stdlib Sequence](https://developer.apple.com/documentation/swift/sequence) and [Collection](https://developer.apple.com/documentation/swift/collection) — the protocol contracts.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: Sequence` / `extension Tagged: Collection`.
