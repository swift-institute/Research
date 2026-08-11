# Iterator Protocol Hierarchy for ~Copyable Elements

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: DECISION
tier: 2
---
-->

## Context

The prior research document (`sequence-protocol-noncopyable-elements.md`, v2.0.0, DECISION) determined that `Sequence.Protocol` should adopt `SuppressedAssociatedTypes` for `~Copyable` elements. That decision introduced a new question: what should `Sequence.Protocol` require of its `Iterator` associated type?

The plan proposed changing:

```swift
// BEFORE
associatedtype Iterator: IteratorProtocol where Iterator.Element == Element

// AFTER
associatedtype Iterator: Sequence.Iterator.`Protocol` where Iterator.Element == Element
```

This change cascades — every downstream `Sequence.Protocol` conformer must ensure its iterator conforms to `Sequence.Iterator.Protocol`. During implementation, this required adding `Sequence.Iterator.Protocol` to 11 buffer iterator types and 2 vector iterator types, even though 6 of those already conform to `Sequence.Iterator.Borrowing.Protocol`.

**Trigger**: "Why isn't `Sequence.Iterator.Borrowing.Protocol` enough?" — the cascade revealed a protocol hierarchy design question.

## Question

What is the ideal relationship between the iterator protocols, and what should `Sequence.Protocol` require of its `Iterator` associated type?

## Constraints

1. **stdlib is immutable**: `IteratorProtocol.Element` is implicitly `Copyable`. We cannot change this.
2. **Same-type propagation**: `where Iterator.Element == Element` with `Iterator: IteratorProtocol` forces `Element: Copyable` because `IteratorProtocol.Element` requires it. This is why `IteratorProtocol` cannot be kept as the constraint.
3. **`Optional` supports `~Copyable`**: `next() -> Element?` works for `~Copyable` elements. No custom return type needed.
4. **Escapable semantics**: Protocols that don't suppress `~Escapable` implicitly require Escapable conformers. A child protocol cannot suppress `~Escapable` if its parent requires it — the parent's constraint wins.
5. **~Escapable iterators exist**: `Swift.Span.Iterator` and `Swift.Span.Iterator.Batch` are `~Escapable, ~Copyable`. They borrow from a span and cannot outlive it.
6. **Batch iterators lack `next()`**: `Span.Iterator.Batch` conforms to `Sequence.Iterator.Borrowing.Protocol` and provides `nextSpan()` but deliberately does NOT provide `next() -> Element?`. It is a pure batch iterator.

## Current Protocol Landscape

### The Three Iterator Protocols

| Protocol | Method | Yields | Self | Element |
|----------|--------|--------|------|---------|
| `Sequence.Iterator.Protocol` | `next() -> Element?` | Owned element | `~Copyable` | `~Copyable` |
| `Sequence.Iterator.Borrowing.Protocol` | `nextSpan(maximumCount:) -> Span<Element>` | Borrowed span | `~Copyable, ~Escapable` | `~Copyable` |
| `IteratorProtocol` (stdlib) | `next() -> Element?` | Owned element | `Copyable` | `Copyable` |

### Relationships

None of these protocols refine each other. They are three independent protocols with no inheritance relationship.

### The Two Sequence Protocols

| Protocol | Iterator Constraint | Purpose |
|----------|-------------------|---------|
| `Sequence.Protocol` | `Iterator: Sequence.Iterator.Protocol` | Element-at-a-time iteration |
| `Sequence.Borrowing.Protocol` | `Iterator: Sequence.Iterator.Borrowing.Protocol` | Span-based batch iteration |

### Concrete Iterator Types

| Iterator | `Sequence.Iterator.Protocol` | `Sequence.Iterator.Borrowing.Protocol` | `IteratorProtocol` | Escapable? |
|----------|------------------------------|---------------------------------------|-------------------|-----------|
| Buffer.Linear.Iterator | needed | yes | yes | yes |
| Buffer.Ring.Iterator | needed | yes | yes | yes |
| Buffer.Linked.Iterator | needed | no | yes | yes |
| Vector.Iterator | needed | no | yes (conditional) | yes (conditional) |
| Swift.Span.Iterator | no | no | no | **no** (~Escapable) |
| Swift.Span.Iterator.Batch | no | yes | no | **no** (~Escapable) |

## Analysis

### Option A: Parallel Protocols (current design)

Keep `Sequence.Iterator.Protocol` and `Sequence.Iterator.Borrowing.Protocol` as independent, parallel protocols. Downstream iterators explicitly add `Sequence.Iterator.Protocol` conformance.

```
Sequence.Iterator.Protocol          Sequence.Iterator.Borrowing.Protocol
(~Copyable)                         (~Copyable, ~Escapable)
next() -> Element?                  nextSpan() -> Span<Element>
       ↑                                       ↑
       |                                       |
  [buffer iterators conform to both]   [Span.Iterator.Batch]
```

**Advantages**:
- No Escapable complications — protocols have independent Escapable semantics
- `Span.Iterator.Batch` is unaffected — pure batch iterators never need `next()`
- Simple to understand — each protocol has one method family
- Matches the conceptual distinction: element-at-a-time vs span-based

**Disadvantages**:
- Cascade: every `Sequence.Protocol` conformer's Iterator must explicitly add `Sequence.Iterator.Protocol`
- Buffer iterators list 3 protocols: `Sequence.Iterator.Protocol, Sequence.Iterator.Borrowing.Protocol, IteratorProtocol`

**Cascade scope**: 13 iterator types across 3 packages (buffer, vector, potentially more).

### Option B: Borrowing Refines Non-Borrowing

Make `Sequence.Iterator.Borrowing.Protocol` a refinement of `Sequence.Iterator.Protocol`:

```swift
extension Sequence.Iterator.Borrowing {
    public protocol `Protocol`: Sequence.Iterator.`Protocol`, ~Copyable, ~Escapable {
        @_lifetime(&self)
        mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>
        mutating func skip(by maximumCount: Cardinal) -> Cardinal
    }
}
```

**Why this fails**:

1. **Escapable conflict**: `Sequence.Iterator.Protocol` does not suppress `~Escapable`. Conformers must be Escapable. `Sequence.Iterator.Borrowing.Protocol` suppresses `~Escapable` — but the parent's requirement wins. All conformers of the child would be forced Escapable. `Swift.Span.Iterator.Batch` (which is `~Escapable`) could no longer conform.

2. **Forced `next()` on batch iterators**: `Span.Iterator.Batch` would be forced to implement `next() -> Element?`. But batch iterators deliberately don't provide single-element access — they exist for efficient bulk processing. Adding `next()` would be semantically wrong.

**Verdict**: Ruled out by Constraint 4 (Escapable) and Constraint 6 (batch iterators).

### Option C: Add `~Escapable` to Base Iterator Protocol

Add `~Escapable` suppression to `Sequence.Iterator.Protocol`, then make Borrowing refine it:

```swift
extension Sequence.Iterator {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        mutating func next() -> Element?
    }
}

extension Sequence.Iterator.Borrowing {
    public protocol `Protocol`: Sequence.Iterator.`Protocol`, ~Copyable, ~Escapable {
        // nextSpan, skip...
    }
}
```

**Why this is problematic**:

1. **Cascades into `Sequence.Protocol`**: If `Sequence.Iterator.Protocol` allows `~Escapable` conformers, then `Sequence.Protocol`'s `Iterator` associated type could be `~Escapable`. The return type of `makeIterator() -> Iterator` would need a lifetime annotation:

   ```swift
   // Would need:
   @_lifetime(borrow self)
   borrowing func makeIterator() -> Iterator
   ```

   This changes the protocol contract — all existing conformers would need the lifetime annotation.

2. **Overly permissive for element-at-a-time**: Element-at-a-time iterators are almost always Escapable. They copy data out of the container. The `~Escapable` suppression serves no purpose for this iteration model and adds complexity.

3. **Still forces `next()` on batch iterators**: Even with the Escapable fix, `Span.Iterator.Batch` would still need `next() -> Element?`. Semantically wrong.

**Verdict**: Solves the Escapable conflict but forces `next()` on batch iterators and cascades lifetime complexity into `Sequence.Protocol`. Batch iterator issue remains fatal.

### Option D: Don't Change Iterator Constraint (keep `IteratorProtocol`)

Leave `Sequence.Protocol` with `Iterator: IteratorProtocol`:

```swift
associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
```

**Why this fails**: Same-type constraint `Iterator.Element == Element` propagates `Copyable` from `IteratorProtocol.Element` onto `Element`, overriding the `~Copyable` suppression. The whole point of the change is eliminated. (Constraint 2.)

**Verdict**: Ruled out. Fundamental type system conflict.

### Option E: Remove Same-Type Constraint

Keep `IteratorProtocol` but drop the `where` clause:

```swift
associatedtype Element: ~Copyable
associatedtype Iterator: IteratorProtocol
borrowing func makeIterator() -> Iterator
```

**Why this fails**: `Element` and `Iterator.Element` become unrelated types. Property.View extensions call `iterator.next()` (yielding `Iterator.Element`) but declare closures taking `Base.Element`. Without same-type, these are different types.

**Verdict**: Breaks the type system. Not viable.

### Option F: Remove Iterator Associated Type Entirely

Make `Sequence.Protocol` closure-based with no iterator requirement:

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    func forEach(_ body: (borrowing Element) -> Void)
}
```

**Why this is wrong**: Eliminates composability. Algorithms like `map`, `reduce`, `first`, `contains` all need to control iteration flow (early exit, accumulation). A single `forEach` method can't support these. The iterator abstraction exists precisely to enable algorithm composition.

**Verdict**: Architecturally wrong. Loses the primary value of the protocol.

### Comparison

| Criterion | A: Parallel | B: Refine | C: ~Escapable Base | D: Keep IteratorProtocol | E: No Same-Type | F: No Iterator |
|-----------|------------|-----------|-------------------|------------------------|-----------------|---------------|
| Works today | Yes | No (Escapable) | Partial | No (Copyable) | No (type mismatch) | Yes |
| Batch iterators unaffected | Yes | **No** | **No** | Yes | Yes | N/A |
| ~Escapable iterators | Unaffected | **Broken** | Complex | Unaffected | Unaffected | N/A |
| Downstream churn | 13 iterators | 0 (6 auto) | Lifetime annotations | 0 | N/A | Total rewrite |
| Conceptual clarity | High | Medium | Low | N/A | N/A | Low |
| Algorithm composability | Full | Full | Full | N/A | N/A | **None** |

## Outcome

**Status**: DECISION

**Decision**: **Option A — Parallel protocols with explicit `Sequence.Iterator.Protocol` conformance.**

**Rationale**:

1. **Batch iterators are real**: `Span.Iterator.Batch` is a concrete type that conforms to `Sequence.Iterator.Borrowing.Protocol` and deliberately does NOT provide `next() -> Element?`. Any refinement relationship would force it to implement a method that is semantically wrong for its purpose. This is the decisive constraint.

2. **Escapable semantics are genuinely different**: Element-at-a-time iterators copy data out and are Escapable. Borrowing iterators hold references and are `~Escapable`. These are different ownership models that correctly map to different protocol requirements. Merging them creates Escapable conflicts or forces all iterators into lifetime-annotated territory.

3. **The cascade is mechanical and one-time**: Adding `Sequence.Iterator.Protocol` to 13 iterator types is a one-line change per type, requiring no new method implementations. The iterators already structurally satisfy the protocol. This is a fixed, bounded cost.

4. **Three conformances is correct, not excessive**: Buffer iterators list `Sequence.Iterator.Protocol, Sequence.Iterator.Borrowing.Protocol, IteratorProtocol` because they genuinely serve three roles: our element-at-a-time protocol, our span-based protocol, and stdlib's protocol. Each serves a different consumer. This is not redundancy — it is precision.

5. **In the perfect world**: stdlib's `IteratorProtocol` would support `~Copyable` elements, eliminating the need for `Sequence.Iterator.Protocol` entirely. When that day comes, we deprecate `Sequence.Iterator.Protocol` and change `Sequence.Protocol` to use `IteratorProtocol` again. The parallel design makes this future migration trivial — just remove the one protocol from each conformance list.

**The perfect world is `IteratorProtocol.Element: ~Copyable` in stdlib. Until then, `Sequence.Iterator.Protocol` is the correct bridge — and it must remain independent of `Sequence.Iterator.Borrowing.Protocol` because they serve fundamentally different iteration models.**

## References

- Research: `sequence-protocol-noncopyable-elements.md` v2.0.0 — decision to adopt SuppressedAssociatedTypes
- `Swift.Span.Iterator.Batch` — concrete ~Escapable batch iterator that would break under refinement
- `Swift.Span.Iterator` — concrete ~Escapable element iterator (independent, no protocol conformance)
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
