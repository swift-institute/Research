# @_lifetime Annotations on Escapable Types in Swift 6.3

<!--
---
version: 1.0.0
last_updated: 2026-03-25
status: SUPERSEDED
superseded_by: nonescapable-ecosystem-state.md
---
-->

> **SUPERSEDED** (2026-04-02) by [nonescapable-ecosystem-state.md](nonescapable-ecosystem-state.md) (swift-institute).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

Swift 6.3 (swiftlang-6.3.0.123.5) introduces two new diagnostics that reject
`@_lifetime` annotations on Escapable types:

1. **"invalid lifetime dependence on an Escapable result"** — `@_lifetime(...)`
   on a function whose return type is Escapable
2. **"invalid lifetime dependence on an Escapable target"** — `@_lifetime(self: ...)`
   where self is Escapable

Previously (Swift 6.2), these annotations were silently accepted. This is an
**intentional language change**: lifetime dependencies are semantically meaningless
on Escapable values, which by definition can escape their scope and have no
lifetime constraints.

### References

- SE-0446: Non-Escapable Types
- SE-0456: Span-Providing Properties (experimental `@_lifetime` support)
- SE-0465: Nonescapable Stdlib Primitives
- Andrew Trick's design gists on lifetime dependence with generic types

### Trigger

Build failures across swift-primitives submodule packages after toolchain upgrade
to swiftlang-6.3.0.123.5. Errors surface when building submodules individually
(not the superrepo, which doesn't compile all targets).

## Question

Which `@_lifetime` annotations in swift-primitives are invalid under Swift 6.3,
and what is the correct fix for each pattern?

## Analysis

### Annotation Semantics

| Syntax | Meaning | Invalid When |
|--------|---------|-------------|
| `@_lifetime(borrow x)` | Result depends on borrow of x | Result is Escapable |
| `@_lifetime(copy x)` | Result depends on copy of x | Result is Escapable |
| `@_lifetime(&self)` | Result depends on mutation of self | Result is Escapable |
| `@_lifetime(self: immortal)` | Self has no external lifetime dependency | Self is Escapable |
| `@_lifetime(self: copy x)` | Self's lifetime depends on copy of x | Self is Escapable |

### Pattern Classification

#### Pattern A: `@_lifetime(self: immortal)` on Escapable Iterator `next()`

**Symptom**: "invalid lifetime dependence on an Escapable target"

Escapable iterators conforming to `Sequence.Iterator.Protocol` override `next()`
with `@_lifetime(self: immortal)`. The annotation was intended to express that
the return value (owned Copyable element) has no lifetime dependency on self.
Since the iterator is Escapable, the annotation is now rejected.

**Fix**: Remove `@_lifetime(self: immortal)`. An Escapable type inherently has no
lifetime dependencies — the annotation is tautological.

**Correctness argument**: The protocol's default `next()` lives in an extension
`where Self: ~Copyable & ~Escapable` and correctly carries
`@_lifetime(self: immortal)` because in that context, Self may be ~Escapable.
Concrete Escapable conformers that override `next()` should NOT redeclare it.

**Note**: The companion `@_lifetime(&self)` on `nextSpan() -> Span<Element>` is
**VALID** because `Span<Element>` is `~Escapable`. This annotation is required
even on Escapable iterators to tell the compiler that the Span borrows from self.

#### Pattern B: `@_lifetime(&self)` on Methods Returning Escapable Types

**Symptom**: "invalid lifetime dependence on an Escapable result"

`Collection.Remove.View` (which is `~Copyable, ~Escapable`) has
`@_lifetime(&self)` on `last() -> Element?` and `all() -> Void`. Both return
Escapable types (Element?, Void), so the annotation is invalid.

**Fix**: Remove `@_lifetime(&self)` from these methods. The methods mutate self
but do not return borrowed views — the return values are independent of self's
lifetime.

#### Pattern C: `@_lifetime(copy/borrow self)` on Functions Returning Escapable Types

**Symptom**: "invalid lifetime dependence on an Escapable result"

- `collect() -> [Element]` had `@_lifetime(copy self)` — Array is Escapable
- `makeIterator() -> Iterator` had `@_lifetime(borrow self)` where Iterator is
  Escapable (in `Sequence.Borrowing.Protocol`)

**Fix**: Remove the annotation. Already applied in commit 9c6251e.

### Valid Annotations (No Change Needed)

| Pattern | Why Valid |
|---------|----------|
| `@_lifetime(&self)` on `nextSpan() -> Span<E>` | Span is ~Escapable |
| `@_lifetime(borrow self)` on `var span: Span<E>` | Span is ~Escapable |
| `@_lifetime(&self)` on `var mutableSpan: MutableSpan<E>` | MutableSpan is ~Escapable |
| `@_lifetime(copy _base)` on ~Escapable wrapper init | Wrapper is ~Escapable |
| `@_lifetime(copy self)` on ~Escapable wrapper `makeIterator()` | Wrapper is ~Escapable |
| `@_lifetime(self: immortal)` on ~Escapable iterator `next()` | Self is ~Escapable |
| `@_lifetime(borrow pointer)` on ~Escapable view init | View is ~Escapable |
| `@_lifetime(immortal)` on ~Escapable free functions | Result is ~Escapable |

### Discriminating Rule

> An `@_lifetime` annotation is valid if and only if its **target** is
> `~Escapable`:
>
> - For result-lifetime annotations (`@_lifetime(x)`, `@_lifetime(&self)`):
>   the **return type** must be `~Escapable`.
> - For self-lifetime annotations (`@_lifetime(self: ...)`): **self's type**
>   must be `~Escapable`.

## Affected Files — Full Audit

### Error Type 1: "invalid lifetime dependence on an Escapable target"

All are `@_lifetime(self: immortal)` on `next()` of Escapable iterators.

**swift-bitset-primitives**:
- `Bitset.Iterator.swift:67` — Verified: CONFIRMED error
- `Bitset.Small.Iterator.swift:107` — Verified: CONFIRMED error

**swift-hash-table-primitives**:
- `Hash.Occupied.Static.Iterator.swift:65`
- `Hash.Occupied.View.Iterator.swift:65`

**swift-tree-primitives** (Tree Primitives Core):
- `Tree.N.Order.In.Iterator.swift:61`
- `Tree.N.Order.Level.Iterator.swift:59`
- `Tree.N.Order.Post.Iterator.swift:64`
- `Tree.N.Order.Pre.Iterator.swift:58`

**swift-tree-primitives** (Tree N Bounded Primitives):
- `Tree.N.Bounded.Order.In.Iterator.swift:62`
- `Tree.N.Bounded.Order.Level.Iterator.swift:59`
- `Tree.N.Bounded.Order.Pre.Iterator.swift:59`
- `Tree.N.Bounded.Order.Post.Iterator.swift:63`

**swift-tree-primitives** (Tree Keyed Primitives):
- `Tree.Keyed.Order.Pre.Iterator.swift:56`
- `Tree.Keyed.Order.Post.Iterator.swift:72`
- `Tree.Keyed.Order.Level.Iterator.swift:57`

**swift-infinite-primitives**:
- `Infinite.Observable.Iterator.swift:56`
- `Infinite.Scan.swift:144`
- `Infinite.Cycle.swift:112`
- `Infinite.Zip.swift:130`
- `Infinite.Map.swift:110`

**swift-buffer-primitives-modularization**:
- `Buffer.Linked Copyable.swift:228`
- `Buffer.Slab.Inline Copyable.swift:98`
- `Buffer.Linked.Inline Copyable.swift:95`
- `Buffer.Linear.Inline Copyable.swift:79`
- `Buffer.Ring.Inline Copyable.swift:105`

**swift-buffer-primitives** (duplicate structure):
- `Buffer.Linked Copyable.swift:228`
- `Buffer.Slab.Inline Copyable.swift:98`
- `Buffer.Linked.Inline Copyable.swift:95`
- `Buffer.Linear.Inline Copyable.swift:79`
- `Buffer.Ring.Inline Copyable.swift:105`

**swift-stack-primitives**:
- `Stack.Small Copyable.swift:45`
- `Stack.Static Copyable.swift:45`
- `Stack.Bounded Copyable.swift:46`
- `Stack Copyable.swift:123`

**swift-array-primitives**:
- `Array.Dynamic.swift:74`
- `Array.Fixed ~Copyable.swift:77` (Iterator declared within ~Copyable extension, but is Escapable)
- `Array.Small.swift:63`

**swift-dictionary-primitives**:
- `Dictionary Copyable.swift:74`
- `Dictionary.Ordered.Bounded Copyable.swift:67`
- `Dictionary.Ordered Copyable.swift:67`
- `Dictionary.Ordered.Small Copyable.swift:80`
- `Dictionary.Ordered.Static Copyable.swift:80`
- `Dictionary.Ordered.Keys.swift:119`
- `Dictionary.Ordered.Values.swift:189`

**swift-sequence-primitives** (already fixed):
- `Sequence.Difference.Steps.Iterator.swift` — REMOVED in 9c6251e
- `Sequence.Difference.Changes.Iterator.swift` — REMOVED in 9c6251e

**swift-sequence-primitives** (Tests — needs fix):
- `Tests/Support/Sequence Primitives Test Support.swift:59`

**swift-parser-primitives** (Tests — needs fix):
- `Tests/Support/Parser Primitives Test Support.swift:36`

### Error Type 2: "invalid lifetime dependence on an Escapable result"

**swift-collection-primitives** — Verified: CONFIRMED errors:
- `Collection.Remove.swift:66` — `@_lifetime(&self)` on `last() -> Element?`
- `Collection.Remove.swift:83` — `@_lifetime(&self)` on `all() -> Void`

**swift-sequence-primitives** (already fixed):
- `Sequence.Protocol+collect.swift` — REMOVED in 9c6251e
- `Sequence.Borrowing.Protocol.swift` — REMOVED in 9c6251e

### Not Affected

Types with `@_lifetime(&self)` on `nextSpan() -> Span<E>` only (no
`@_lifetime(self: immortal)` on `next()`):

- `Buffer.Linear.Iterator` / `Buffer.Linear.Bounded.Iterator` — no override of `next()`
- `Buffer.Ring` iterators (span-only variants)
- `Bit.Vector.*` iterators (all variants)
- `Cyclic.Group.Static.Iterator`
- `Vector+Sequence.Protocol` (MutableSpan returns)
- `Windows.Kernel.Environment.Entries.Iterator`
- All `@_lifetime(borrow self)` on Span/MutableSpan property getters

## Outcome

**Status**: DECISION

### Fix Strategy

**Remove the annotation.** In all cases, the annotation is semantically
meaningless on Escapable types and was only accepted by accident in earlier
toolchains. No behavioral change results from removal — the compiler was never
enforcing these dependencies.

| Error | Pattern | Fix |
|-------|---------|-----|
| Escapable target | `@_lifetime(self: immortal)` on next() | Delete annotation |
| Escapable result | `@_lifetime(&self)` on `last()`, `all()` | Delete annotation |
| Escapable result | `@_lifetime(copy self)` on `collect()` | Already done |
| Escapable result | `@_lifetime(borrow self)` on `makeIterator()` | Already done |

### Scope

- **~50 files** across 15+ packages need `@_lifetime(self: immortal)` removed
  from Escapable iterator `next()` overrides
- **2 methods** in `Collection.Remove.View` need `@_lifetime(&self)` removed
- **4 files** already fixed in commit 9c6251e (Difference iterators, collect, makeIterator)

### Alternative Considered: Make Iterators ~Escapable

Making all iterators `~Escapable` would make the annotations valid. Rejected:
- Most of these iterators (Bitset, Hash, Tree, Buffer Copyable, Stack, Array,
  Dictionary) are independent value types that own their data — they don't borrow
  from any source.
- Adding `~Escapable` would require `@_lifetime` on their constructors and
  propagate through all call sites.
- The `~Escapable` sequence iterators (Map, Filter, etc.) are ~Escapable because
  they store a base iterator whose lifetime they depend on. Independent iterators
  have no such dependency.

### Reference Pattern

Buffer.Linear.Iterator demonstrates the correct pattern for an Escapable
iterator:

```swift
public struct Iterator: Sequence.Iterator.Protocol, IteratorProtocol {
    // No ~Escapable, no @_lifetime on init, no @_lifetime on next()

    public mutating func next() -> Element? {
        // No @_lifetime annotation — Escapable type, Escapable return
        ...
    }

    @_lifetime(&self)
    public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        // @_lifetime(&self) is valid — Span is ~Escapable
        ...
    }
}
```

### Sequence.Borrowing.Protocol Note

The `@_lifetime(borrow self)` removal from `makeIterator()` leaves a semantic
gap: the protocol doc says the iterator borrows from self, but there is no
compiler-enforced annotation. Comment preserved at line 64:

> `@_lifetime(borrow self)` removed — invalid on Escapable Iterator.
> Will be restored when Iterator gains `~Escapable`.

When `Iterator` gains `& ~Escapable` on the associated type, the annotation
should be restored.
