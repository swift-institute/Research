# Lazy Sequence Pipeline Implementation

<!--
---
version: 1.0.0
last_updated: 2026-02-27
status: DECISION
tier: 1
---
-->

## Context

The sequence primitives library had eager Property.View-based operations (map, filter, drop, prefix) that returned `[Element]`. The lazy pipeline redesign replaces these with lazy wrapper types conforming to `Sequence.Protocol`, enabling chained composition with `.collect()` as the terminal operation:

```swift
source.map { $0 * 2 }.filter { $0 > 5 }.collect()  // [Int]
source.drop(first: Cardinal(2)).prefix(first: Cardinal(3)).collect()
```

Two experiments validated the approach before implementation:
- `Experiments/lazy-escapable-patterns/` — full `~Copyable & ~Escapable` suppression with conditional conformance restoration
- `Experiments/lazy-iterator-nextspan-strategies/` — heap buffer (Map/Filter/CompactMap) and forward-to-base (Drop/Prefix) iterator strategies

## Question

How should lazy wrapper types integrate with the existing `Sequence.Protocol` (now `~Copyable, ~Escapable`) and the Property.View pattern for eager operations?

## Analysis

### Decision 1: Consuming makeIterator

**Status**: DECISION — `consuming func makeIterator()` on `Sequence.Protocol`.

The protocol requires `@_lifetime(copy self) consuming func makeIterator() -> Iterator`. This enables the lazy pipeline: consuming self stores it in the wrapper. For Copyable types, consuming from a `let` binding implicitly copies.

Validated by `Experiments/lazy-escapable-patterns/`.

### Decision 2: Full Suppression on Wrapper Types

**Status**: DECISION — All lazy wrappers use `~Copyable, ~Escapable` with conditional restoration.

Pattern:
```swift
public struct Map<Base: Sequence.`Protocol` & ~Copyable & ~Escapable, Output>: ~Copyable, ~Escapable
where Base.Element: Copyable { ... }

extension Sequence.Map: Copyable where Base: Copyable & ~Escapable {}
extension Sequence.Map: Escapable where Base: Escapable & ~Copyable {}
```

The `& ~Escapable` cross-constraint in the conditional conformances prevents circular inference. This pattern is consistent across all 7 wrapper types.

### Decision 3: Protocol Extension Constraints

**Status**: DECISION — Use `where Self: ~Copyable & ~Escapable` on all lazy operation extensions.

```swift
extension Sequence.`Protocol` where Self: ~Copyable & ~Escapable, Element: Copyable {
    @_lifetime(copy self)
    public consuming func map<Output>(...) -> Sequence.Map<Self, Output> { ... }
}
```

This ensures the methods are available for ALL conformers (Copyable+Escapable included, since suppression is permissive).

### Decision 4: Property.View Narrowing

**Status**: DECISION — Narrow Property.View extensions from `Base: Sequence.Protocol & ~Copyable` to `Base: Sequence.Protocol` (Copyable implicit).

**Rationale**: With `consuming func makeIterator()`, calling `base.pointee.makeIterator()` through a Property.View's UnsafeMutablePointer requires the base to be Copyable. For Copyable types, consuming from a borrow implicitly copies (original untouched). For ~Copyable types, consuming through a pointer would destroy the pointee — leaving the borrowed self in an invalid state.

**Impact**: ~Copyable sequences can no longer use `.forEach { }`, `.contains { }`, `.count.all`, etc. through Property.View. They should use:
- Consuming pipeline: `source.map { }.filter { }.collect()`
- Borrowing iteration: `Sequence.Borrowing.Protocol` with `.span.forEach { }` or `.span.elements { }`

This is consistent with the two-tier iteration model: consuming `Sequence.Protocol` for lazy chains, borrowing `Sequence.Borrowing.Protocol` for non-destructive access.

### Discovery 1: Extension Where Clause Propagation

**Finding**: When a generic type has full suppression (`~Copyable, ~Escapable`) and nested types are defined in **separate extension files**, both the nested type extension and the conformance extension need `where Base: ~Copyable & ~Escapable`.

Without the where clause on the conformance extension, the compiler sees the type as Escapable (from conditional conformance) and rejects `@_lifetime(copy self)` with "invalid lifetime dependence on an Escapable value with consuming ownership".

Without the where clause on the nested type extension, the compiler cannot resolve the Iterator type in the conformance extension's context ("type 'Base' does not conform to protocol 'Copyable'", "protocol requires nested type 'Iterator'").

```swift
// CORRECT — Both extensions have the where clause
extension Sequence.Map where Base: ~Copyable & ~Escapable {
    public struct Iterator: ~Copyable, ~Escapable, Sequence.Iterator.`Protocol` { ... }
}

extension Sequence.Map: Sequence.`Protocol` where Base: ~Copyable & ~Escapable {
    @_lifetime(copy self)
    public consuming func makeIterator() -> Iterator { ... }
}

// INCORRECT — Missing where clause on Iterator extension
extension Sequence.Map {
    public struct Iterator: ~Copyable, ~Escapable, Sequence.Iterator.`Protocol` { ... }
}
// ^ Compiler error: can't resolve Iterator in conformance extension
```

**Note**: The validated experiment avoided this by defining iterators inside the struct body. The one-type-per-file convention [API-IMPL-005] requires the separate extension pattern, which reveals this compiler behavior.

### Discovery 2: Iterator Two-Strategy Pattern

**Validated at scale**: Element-transforming iterators (Map, Filter, CompactMap) use heap-allocated single-element buffer with `deinit` cleanup. Element-preserving iterators (Drop.First, Drop.While, Prefix.First, Prefix.While) forward `nextSpan` calls to the base iterator with zero allocation.

Both patterns correctly implement `Sequence.Iterator.Protocol` with `nextSpan(maximumCount:)` as the sole requirement, plus a `next()` override for performance.

## Outcome

**Status**: DECISION

The lazy sequence pipeline is implemented with:
- 7 lazy wrapper types (Map, Filter, CompactMap, Drop.First, Drop.While, Prefix.First, Prefix.While)
- 7 iterator types (3 heap buffer, 4 forward-to-base)
- 6 protocol extensions (map, filter, compactMap, collect, drop, prefix)
- 4 deleted Property.View files (Map, Filter, Drop, Prefix)
- 6 narrowed Property.View files (ForEach, Contains, First, Count, Satisfies, Reduce)
- All 97 tests pass

## References

- `Experiments/lazy-escapable-patterns/Sources/main.swift` — Full suppression validation
- `Experiments/lazy-iterator-nextspan-strategies/Sources/main.swift` — Iterator strategy validation
- `Research/sequence-iterator-protocol-architecture.md` — Protocol architecture decisions
- `Research/implementation-handoff-nextspan-unification.md` — nextSpan unification context
