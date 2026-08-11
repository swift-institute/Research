# Sequence Iterator Borrowing Primitive

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: RECOMMENDATION
tier: 2
---
-->

## Context

The current `Sequence.Iterator.Protocol` requires `mutating func next() -> Element?` — a **giving** primitive that transfers ownership of each element to the caller. For `Copyable` elements this is transparent (implicit copy). For `~Copyable` elements, `next()` performs a destructive move: the element leaves the iterator's storage, the container enters a partially-consumed state, and the iterator must track which slots have been vacated.

Meanwhile, `Sequence.Borrowing.Protocol` (via `Sequence.Iterator.Borrowing.Protocol`) uses `nextSpan(maximumCount:) -> Span<Element>` — a **lending** primitive that borrows elements in place. This works for contiguous storage but requires `~Escapable` on both the iterator and its protocol, introduces `@_lifetime` annotations throughout, and cannot serve non-contiguous structures (linked lists, trees) without internal buffering.

The consequence: two parallel iterator protocols with no inheritance relationship, two parallel sequence protocols, and no path to unification. The `iterator-protocol-hierarchy.md` research (v1.0.0, 2026-02-13, DECISION) confirmed the parallel design is correct given the primitives available. But this research re-examines the question: **is there a third primitive that unifies both models?**

**Trigger**: "I am still interested in unifying Sequence.Borrowing.Protocol with Sequence.Protocol. Also, wouldn't it be better to change the requirement such that Sequence.Protocol works for any ~Copyable type — so we rework the `Sequence.Iterator.Protocol` requirement of `mutating func next() -> Element?` with a more universal requirement?"

**Prior research**:
- `iterator-protocol-hierarchy.md` v1.0.0 — DECISION: parallel protocols (Escapable conflict, batch iterators)
- `sequence-protocol-surface-simplification.md` v1.1.0 — DECISION: six protocols, distinct ownership models
- `collection-sequence-protocol-detachment.md` v1.0.0 — RECOMMENDATION: orthogonal Collection/Sequence
- `sequence-protocol-noncopyable-elements.md` v2.0.0 — DECISION: adopt SuppressedAssociatedTypes

## Question

What is the ideal protocol shape for `Sequence.Iterator.Protocol` — can the iteration primitive be changed from `next() -> Element?` to a more universal requirement that serves both Copyable and ~Copyable elements without requiring `~Escapable`, and can this unify `Sequence.Protocol` with `Sequence.Borrowing.Protocol`?

## Prior Art Survey

### Swift Evolution

| Proposal/Pitch | Status | Relevance |
|----------------|--------|-----------|
| [SE-0437: Noncopyable Stdlib Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) | Accepted | Makes `Optional<~Copyable>` work but explicitly defers `Sequence`/`IteratorProtocol` generalization. "For-in loops currently require a Sequence conformance, which means it will not yet be possible to iterate over...noncopyable elements using a direct for-in loop." |
| [SE-0499: ~Copyable in Simple Stdlib Protocols](https://forums.swift.org/t/accepted-with-modifications-se-0499-support-copyable-escapable-in-simple-standard-library-protocols/83754) | Accepted with modifications | Generalizes `Equatable`, `Hashable`, etc. Does NOT cover `IteratorProtocol` or `Sequence` — deferred pending associated type support. |
| [SE-0503: Suppressed Associated Types With Defaults](https://forums.swift.org/t/accepted-se-0503-suppressed-default-conformances-on-associated-types-with-defaults/84774) | Accepted | Enables `associatedtype Element: ~Copyable` in stdlib protocols. Unblocks future generalization of `IteratorProtocol`/`Sequence`. |
| [[Pitch] Borrowing Sequence](https://forums.swift.org/t/pitch-borrowing-sequence/84332) | Pitch (pre-review) | Proposes `BorrowingIteratorProtocol` with `nextSpan(maximumCount:) -> Span<Element>`. Parallel to `IteratorProtocol`, not a replacement. Plans to reparent `Sequence` on `BorrowingSequence`. |

**Key stdlib direction**: The Swift stdlib team is building `BorrowingSequence` as a **parallel** protocol alongside `Sequence`, with `nextSpan` as the span-based lending primitive. They plan to reparent `Sequence` on top of `BorrowingSequence`, making span-based borrowing the base and element-at-a-time giving the refinement. This mirrors our parallel design but with a planned future merger via reparenting.

### Rust: Lending Iterators

Rust's [`LendingIterator`](https://docs.rs/lending-iterator/latest/lending_iterator/trait.LendingIterator.html) uses Generic Associated Types (GATs) to express items that borrow from the iterator:

```rust
trait LendingIterator {
    type Item<'this> where Self: 'this;
    fn next(&mut self) -> Option<Self::Item<'_>>;
}
```

The lifetime parameter `'this` on `Item` ties each yielded item to the iterator's mutable borrow. **Items from a `LendingIterator` cannot coexist** — calling `next()` invalidates the previous item.

**Key distinction** (from [Niko Matsakis, "Giving, Lending, and Async Closures"](https://smallcultfollowing.com/babysteps/blog/2023/05/09/giving-lending-and-async-closures/)):

| Pattern | Rust Term | Items | Can hold multiple? | Algorithm composition |
|---------|-----------|-------|---------------------|----------------------|
| **Giving** | `Iterator` | Owned, independent of `self` | Yes | Full (`collect`, `zip`, `take_two`) |
| **Lending** | `LendingIterator` | Borrowed from `self` | No | Limited (no `collect`, no multi-element) |

Rust keeps both traits because **giving enables algorithm compositions that lending cannot** (e.g., holding two items simultaneously for comparison). Swift's type system has no GATs, so lending must use either `Span` (the stdlib approach) or closures (proposed below).

### Rust: Iterable Pattern

The [GAT Initiative's Iterable pattern](https://rust-lang.github.io/generic-associated-types-initiative/design_patterns/iterable.html) uses lifetime-parameterized associated types to express that borrowed items have lifetimes tied to the collection:

```rust
trait Iterable {
    type Item<'me> where Self: 'me;
    type Iter<'me>: Iterator<Item = Self::Item<'me>> where Self: 'me;
    fn iter(&self) -> Self::Iter<'_>;
}
```

This is the "lending at the sequence level" — the sequence lends the iterator, and the iterator lends items. Swift's `@_lifetime(borrow self)` on `makeIterator()` serves the same purpose.

## Constraints

| # | Constraint | Impact |
|---|-----------|--------|
| 1 | `next() -> Element?` is a **giving** primitive | For ~Copyable elements, this is a destructive move out of storage |
| 2 | `nextSpan() -> Span<Element>` requires `~Escapable` | Cascades `~Escapable` and `@_lifetime` into all iterators and sequences |
| 3 | Batch iterators (`Span.Iterator.Batch`) have no `next()` | Any refinement that forces `next()` on batch iterators is ruled out |
| 4 | Swift has no GATs | Cannot express `type Item<'self>` — must use closures or Span for lending |
| 5 | `borrowing` closure params are transparent for Copyable | Proven by experiment `two-tier-borrowing-overloads` — no call-site impact |
| 6 | `Sequence.Drain.Protocol` handles consuming iteration | Consuming moves belong to drain, not the base iteration primitive |
| 7 | 13 types conform to Drain without Sequence.Protocol | Consuming iteration is genuinely a separate capability |
| 8 | Closure-based iteration is the primary call-site model | `forEach`, `map`, `reduce`, `contains` — all use closures already |

## Analysis

### Option A: Keep `next() -> Element?` (Status Quo)

Maintain the current giving primitive.

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}
```

**Advantages**:
- No migration
- Full algorithm composition (caller holds the owned element)
- Proven and deployed

**Disadvantages**:
- For ~Copyable elements: destructive move. Iterator and container enter partially-consumed state.
- Does not support borrowing iteration — separate `Borrowing.Protocol` remains required
- Two parallel protocol trees persist
- The "borrowing" forEach actually gives ownership to the local, then borrows from that local — an unnecessary round-trip

**Verdict**: Works but does not advance unification.

### Option B: Change to `nextSpan(maximumCount:) -> Span<Element>` (stdlib-aligned)

Replace `next()` with the stdlib pitch's span-based lending primitive.

```swift
public protocol `Protocol`: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element>
}
```

Derive `next()` for Copyable elements:
```swift
extension Sequence.Iterator.`Protocol` where Element: Copyable {
    mutating func next() -> Element? {
        let span = nextSpan(maximumCount: Cardinal(UInt(1)))
        return span.isEmpty ? nil : span[0]
    }
}
```

**Advantages**:
- Aligned with stdlib direction ([Pitch] Borrowing Sequence)
- Batch access efficient for contiguous storage
- Borrowing is the base — `next()` is a derived convenience

**Disadvantages**:
- **~Escapable cascade**: `Sequence.Iterator.Protocol` becomes `~Escapable`. This cascades into `Sequence.Protocol.makeIterator()` requiring `@_lifetime(borrow self)`. Every conformer gains lifetime complexity.
- **Non-contiguous storage**: Linked lists, trees, ring buffers with wrap-around need internal buffering to produce a `Span`. Single-element `Span` from an iterator-internal buffer is possible but adds allocation/copy overhead for every non-contiguous type.
- **Forces `Sequence.Protocol` to be `~Escapable`**: The sequence itself becomes `~Escapable` to support the lifetime chain from sequence → iterator → span.
- **Batch iterators**: These work (they already have `nextSpan`), but element-level iterators pay span overhead for no benefit.

**Verdict**: Viable but imposes `~Escapable` on the entire hierarchy. This is the stdlib's approach because they plan to reparent `Sequence` on `BorrowingSequence`, accepting the `~Escapable` cascade. For our user-defined protocols where we control the design, the `~Escapable` cascade is avoidable.

### Option C: Change to `withNext<R>(_ body: (borrowing Element) -> R) -> R?` (Closure-Based Lending)

Replace `next()` with a closure-based lending primitive — the iterator calls the closure with a borrowed element:

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R?
}
```

The closure receives a borrowed reference to the element. The iterator's storage remains intact. The closure's return value `R` propagates through `Optional<R>` — `nil` signals exhaustion.

**Derive `next()` for Copyable elements**:
```swift
extension Sequence.Iterator.`Protocol` where Self: ~Copyable, Element: Copyable {
    public mutating func next() -> Element? {
        withNext { $0 }  // implicit copy of Copyable element
    }
}
```

**Algorithm composition via `withNext`**:

```swift
// forEach
var iterator = container.makeIterator()
while let _ = iterator.withNext({ body($0) }) { }

// contains(where:)
func contains(where predicate: (borrowing Element) -> Bool) -> Bool {
    var iterator = container.makeIterator()
    while let found = iterator.withNext({ predicate($0) }) {
        if found { return true }
    }
    return false
}

// reduce(into:_:)
func reduce<R>(into initial: R, _ combine: (inout R, borrowing Element) -> Void) -> R {
    var result = initial
    var iterator = container.makeIterator()
    while let _ = iterator.withNext({ combine(&result, $0) }) { }
    return result
}

// map (Copyable elements — copies out)
func map<R>(_ transform: (borrowing Element) -> R) -> [R] {
    var result: [R] = []
    var iterator = container.makeIterator()
    while let transformed = iterator.withNext({ transform($0) }) {
        result.append(transformed)
    }
    return result
}

// first (Copyable elements only)
func first() -> Element? {
    var iterator = container.makeIterator()
    return iterator.withNext { $0 }  // copies out
}
```

**How iterators implement `withNext`**:

For contiguous storage (array, buffer):
```swift
mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R? {
    guard index < span.count else { return nil }
    defer { index += 1 }
    return body(span[index])  // borrows from span in-place
}
```

For non-contiguous storage (linked list):
```swift
mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R? {
    guard let node = current else { return nil }
    current = node.next
    return body(node.value)  // borrows from heap node
}
```

For ring buffer (wrap-around):
```swift
mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R? {
    guard remaining > 0 else { return nil }
    defer { position = (position + 1) % capacity; remaining -= 1 }
    return body(buffer[position])  // borrows from slot
}
```

**Advantages**:
1. **No `~Escapable` cascade**: The iterator is NOT `~Escapable`. No `@_lifetime` annotations needed on `makeIterator()` or the sequence. The closure provides the lifetime scoping — the element cannot escape the closure body.
2. **Works for ALL storage types**: Contiguous, linked, ring, tree — the closure borrows in-place from whatever storage the iterator references. No `Span` construction needed for non-contiguous types.
3. **Derives `next()` for Copyable**: `withNext { $0 }` performs an implicit copy, yielding the same semantics as the current `next()`.
4. **Borrowing is the base, giving is derived**: The more general operation (borrowing) is the requirement. The more specific (owning) is a default for Copyable types.
5. **Aligned with existing call-site model**: All algorithms (`forEach`, `map`, `reduce`, `contains`) already use closures. `withNext` fits the established closure-based pattern.
6. **Correct ownership for ~Copyable elements**: The element is borrowed, not moved. The iterator's storage remains intact. No partially-consumed state. Consuming iteration stays in `Drain.Protocol` where it belongs.
7. **Unifies the conceptual model**: A single protocol requirement serves both Copyable (via derived `next()`) and ~Copyable (via direct `withNext`) elements.

**Disadvantages**:
1. **No multi-element access**: Cannot hold two elements simultaneously (unlike `next()` which returns owned values). Algorithms like "compare adjacent elements" need workarounds (copy previous for Copyable, or use index-based access for collections).
2. **Closure overhead**: Each element access requires a closure call. For hot loops, this depends on inlining. With `@inlinable`, the optimizer should eliminate the closure overhead, but this needs experimental validation.
3. **Does NOT unify with `Sequence.Borrowing.Protocol`**: The span-based batch protocol remains separate because `withNext` is element-level, not batch. Batch access for contiguous types (`nextSpan`) is an optimization that `withNext` cannot express.
4. **Experimental**: `withNext<R>(_ body: (borrowing Element) -> R) -> R?` with `Element: ~Copyable` in a `~Copyable` protocol has not been tested in the compiler.
5. **Generic method in protocol**: `withNext<R>` has a generic parameter. This is valid in Swift protocols but prevents dynamic dispatch (no witness table entry for open-coded generics). All dispatch is static — acceptable for our use case (all conformers are concrete types).

### Option D: Absorb `Sequence.Borrowing.Protocol` into `Sequence.Protocol` (Full `~Escapable` Unification)

Make `Sequence.Protocol` itself `~Escapable` with `nextSpan` as the base:

```swift
public protocol `Protocol`: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: Sequence.Iterator.`Protocol` & ~Copyable & ~Escapable
        where Iterator.Element == Element
    @_lifetime(borrow self)
    borrowing func makeIterator() -> Iterator
}
```

Iterator:
```swift
public protocol `Protocol`: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element>
}
```

**Advantages**:
- True unification: one protocol, one iterator protocol, one primitive
- Span-based — matches stdlib direction
- Batch access is built-in

**Disadvantages**:
- **~Escapable on everything**: Every sequence, every iterator, every `makeIterator()` call needs lifetime annotations. This is the maximally-invasive option.
- **Non-contiguous types suffer**: Must buffer into single-element spans.
- **Batch iterators (`Span.Iterator.Batch`) would need no changes, but element-only iterators need span wrapping**.
- **Breaks current conformers**: All 15+ buffer types, 2 vector types, all downstream consumers need `~Escapable` and `@_lifetime` annotations.

**Verdict**: Maximally correct but maximally disruptive. This is where the ecosystem arrives eventually (when the stdlib reparents Sequence on BorrowingSequence), but premature for us today.

### Option E: Dual-Requirement Protocol

Require both primitives:

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R?
    mutating func next() -> Element?
}
```

With defaults: `next()` defaults to `withNext { $0 }` for Copyable. But `withNext` CANNOT default to `next()` because `next()` consumes the element — there's no way to borrow from an owned value without prior storage.

**Verdict**: Asymmetric defaults. Only useful if some algorithms genuinely need owned elements from ~Copyable iterators. But consuming iteration belongs to `Drain.Protocol`, not here.

## Comparison

| Criterion | A: `next()` | B: `nextSpan` | C: `withNext` | D: Full ~Escapable | E: Dual |
|-----------|:-----------:|:-------------:|:-------------:|:------------------:|:-------:|
| Works for ~Copyable elements | Move (destructive) | Borrow (in-place) | **Borrow (in-place)** | Borrow (in-place) | Both |
| ~Escapable required | No | **Yes** | **No** | **Yes** | No |
| Non-contiguous storage | Native | Needs buffering | **Native** | Needs buffering | Native |
| Algorithm composition | Full (owned) | Full (span) | **Full (closure)** | Full (span) | Full |
| Derives `next()` for Copyable | N/A (is `next()`) | Yes | **Yes** | Yes | Explicit |
| Unifies with Borrowing.Protocol | No | **Yes** | No (batch separate) | **Yes** | No |
| Migration scope | None | All conformers | **All conformers** | All conformers | All conformers |
| Closure overhead | None | None | Inlinable | None | Both |
| Stdlib alignment | Current stdlib | [Pitch] direction | Novel | Future stdlib | Novel |
| Batch optimization | No | Built-in | Separate protocol | Built-in | No |

## Recommendation

**Option C: `withNext<R>(_ body: (borrowing Element) -> R) -> R?`** — closure-based lending as the universal iteration primitive.

### Rationale

1. **No `~Escapable` cascade is the decisive advantage.** Option B (nextSpan) and Option D (full unification) both force `~Escapable` on every iterator and every sequence. This adds `@_lifetime` annotations to every `makeIterator()`, every conformer, and every algorithm that creates an iterator. Option C achieves lending WITHOUT `~Escapable` — the closure provides lifetime scoping naturally. The element cannot escape the closure body, so no lifetime annotation is needed on the iterator or the protocol.

2. **Works for all storage types.** `nextSpan` requires contiguous storage or internal buffering. Linked lists, trees, ring buffers with wrap-around, and other non-contiguous structures must copy into a single-element `Span` — adding allocation and copy overhead. `withNext` borrows in-place from whatever storage the iterator references. A linked list iterator borrows from the heap node directly. A ring buffer iterator borrows from the slot directly.

3. **Correct ownership model for `Sequence.Protocol`.** The purpose of `Sequence.Protocol` is "iterate and process elements." For ~Copyable elements, this means borrowing — the container keeps its elements, the consumer reads them. `withNext` provides exactly this. For consuming iteration (moving elements out), `Drain.Protocol` exists with its own `drain(_ body: (consuming Element) -> Void)`. The separation is clean: `Sequence.Protocol` borrows, `Drain.Protocol` consumes. Currently, `next() -> Element?` conflates these — it's a giving primitive on what should be a borrowing protocol.

4. **Derives `next()` seamlessly for Copyable elements.** `withNext { $0 }` performs an implicit copy, yielding `Element?`. For Copyable types, all existing code patterns continue working: `while let element = iterator.next()`, `iterator.first()`, etc. The derived `next()` is a zero-cost convenience.

5. **Aligned with the closure-based call-site model.** Every consumer of `Sequence.Protocol` — `forEach`, `map`, `reduce`, `contains`, `first`, `count` — uses closures. `withNext` is the natural element-level primitive for closure-based algorithms. The current `next()` → `while let` → `body(element)` pattern becomes `withNext { body($0) }` — more direct, fewer intermediate moves.

6. **`Sequence.Borrowing.Protocol` remains as a batch optimization.** `withNext` is element-level. `nextSpan` is batch-level. These are complementary, not competing. The batch protocol stays separate as an optimization for contiguous storage types — which is its correct role per `collection-sequence-protocol-detachment.md`. Eventually, when stdlib reparents Sequence on BorrowingSequence, we can align. Until then, `withNext` gives us the correct semantics without the `~Escapable` cost.

### Proposed Protocol Shape

**`Sequence.Iterator.Protocol`** (replaces `next()` with `withNext`):

```swift
extension Sequence.Iterator {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable

        /// Calls `body` with a borrowed reference to the next element.
        /// Returns `body`'s return value wrapped in `.some`, or `nil` if exhausted.
        mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R?
    }
}
```

**Default `next()` for Copyable** (derived from `withNext`):

```swift
extension Sequence.Iterator.`Protocol` where Self: ~Copyable, Element: Copyable {
    /// Returns the next element (owned copy), or `nil` if exhausted.
    public mutating func next() -> Element? {
        withNext { $0 }
    }
}
```

**`Sequence.Protocol`** (unchanged shape):

```swift
extension Sequence {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable
        associatedtype Iterator: Sequence.Iterator.`Protocol` where Iterator.Element == Element
        borrowing func makeIterator() -> Iterator
    }
}
```

**`Sequence.Borrowing.Protocol`** (unchanged, separate batch optimization):

```swift
extension Sequence.Borrowing {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Iterator: Sequence.Iterator.Borrowing.`Protocol`
            where Iterator.Element == Element
        @_lifetime(borrow self)
        borrowing func makeIterator() -> Iterator
    }
}
```

**ForEach implementation** (using `withNext`):

```swift
extension Property.View
where Base: Sequence.`Protocol` & ~Copyable, Tag == Sequence.ForEach {
    public func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        var iterator = unsafe base.pointee.makeIterator()
        while let _ = iterator.withNext({ body($0) }) { }
    }
}
```

### Experimental Validation

**Experiment**: `swift-sequence-primitives/Experiments/borrowing-iterator-primitive/` — **CONFIRMED** on Swift 6.2.3.

All 13 tests pass. Results:

| Risk | Concern | Result |
|------|---------|--------|
| `withNext<R>` in `~Copyable` protocol | Generic method with `(borrowing Element)` where `Element: ~Copyable` | **CONFIRMED** — compiles and runs correctly |
| `next()` default derivation | `withNext { $0 }` implicit copy for `Element: Copyable` | **CONFIRMED** — `while let element = iterator.next()` works |
| Algorithm composition | `forEach`, `contains`, `reduce`, `map`, `count` via `withNext` | **CONFIRMED** — all 5 algorithms work for both Copyable and ~Copyable |
| ~Copyable container + elements | `NoncopyableBuffer` with `UniqueResource` elements | **CONFIRMED** — borrowing access to ~Copyable element fields works |
| Multiple iteration | Container survives multiple `forEach` passes | **CONFIRMED** — `withNext` borrows, does not consume |
| Closure inlining | `@inlinable` `withNext` with closure | **DEFERRED** — needs benchmark or assembly inspection |

**Key implementation findings**:

1. **`associatedtype Iterator: IteratorProtocol & ~Copyable`** is required — without `& ~Copyable` suppression on the associated type, ~Copyable iterators cannot satisfy the protocol witness.

2. **Borrowing operators** (`$0 == 3`, `acc += elem`) in shorthand closures have inference issues with `borrowing` parameters. Resolved by using explicit closure bodies with intermediate `let val = element` copies (for Copyable) or field access (for ~Copyable). This is a call-site ergonomics issue, not a semantic limitation.

3. **`(ptr + index).pointee`** in `withNext` for raw pointer storage passes the pointee as a borrowed value to the closure. The element is NOT moved — it stays in the buffer. This confirms the core lending semantics.

### Migration Path

| Step | Change | Scope |
|------|--------|-------|
| 1 | Experiment: validate `withNext` compiles (this document's companion) | 1 experiment package |
| 2 | Change `Sequence.Iterator.Protocol` from `next()` to `withNext` | 1 file |
| 3 | Add `next()` default extension for Copyable elements | 1 file |
| 4 | Update `Sequence.ForEach+Property.View.swift` to use `withNext` | 1 file |
| 5 | Update all other Property.View algorithms (`map`, `reduce`, `contains`, etc.) | ~8 files |
| 6 | Update all downstream iterator conformers: implement `withNext` | ~15 iterators |
| 7 | Update downstream Property.View extensions that call `next()` | Per-package |

## References

- `iterator-protocol-hierarchy.md` v1.0.0 — parallel iterator protocol DECISION (this research supersedes for the `next()` question)
- `sequence-protocol-noncopyable-elements.md` v2.0.0 — SuppressedAssociatedTypes adoption DECISION
- `sequence-protocol-surface-simplification.md` v1.1.0 — six sequence protocols DECISION
- `collection-sequence-protocol-detachment.md` v1.0.0 — Collection/Sequence orthogonality RECOMMENDATION
- [[Pitch] Borrowing Sequence](https://forums.swift.org/t/pitch-borrowing-sequence/84332) — stdlib BorrowingIteratorProtocol with `nextSpan`
- [SE-0437: Noncopyable Stdlib Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) — defers Sequence/IteratorProtocol generalization
- [SE-0499: ~Copyable in Simple Stdlib Protocols](https://forums.swift.org/t/accepted-with-modifications-se-0499-support-copyable-escapable-in-simple-standard-library-protocols/83754) — does not cover Sequence/IteratorProtocol
- [SE-0503: Suppressed Associated Types](https://forums.swift.org/t/accepted-se-0503-suppressed-default-conformances-on-associated-types-with-defaults/84774) — enables `associatedtype Element: ~Copyable`
- [Rust `LendingIterator`](https://docs.rs/lending-iterator/latest/lending_iterator/trait.LendingIterator.html) — GAT-based lending with lifetime-tied items
- [Niko Matsakis: Giving, Lending, and Async Closures](https://smallcultfollowing.com/babysteps/blog/2023/05/09/giving-lending-and-async-closures/) — giving vs lending trait taxonomy
- [GAT Initiative: Iterable Pattern](https://rust-lang.github.io/generic-associated-types-initiative/design_patterns/iterable.html) — lending at the sequence level
- Experiment: `swift-sequence-primitives/Experiments/borrowing-iterator-primitive/` — compiler validation (companion to this research)
