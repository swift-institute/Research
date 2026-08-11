# Sequence Protocol Surface Simplification

<!--
---
version: 1.1.0
last_updated: 2026-02-23
status: DECISION
tier: 2
---
-->

## Context

The adoption of `SuppressedAssociatedTypes` (`associatedtype Element: ~Copyable`) across all sequence protocols raised a natural question: does the expanded capability make any of the existing protocols redundant?

Before this change, `Sequence.Protocol.Element` was implicitly `Copyable`. Separate protocols like `Sequence.Drain.Protocol` existed partly because they needed to work with `~Copyable` elements that `Sequence.Protocol` could not express. Now that `Sequence.Protocol` supports `~Copyable` elements, can the protocol surface be simplified?

**Trigger**: "Can we now just put drain on Sequence.Protocol and remove the Drain protocol? What about Clearable?"

## Question

Can any of the six sequence-related protocols be merged, absorbed, or eliminated now that `~Copyable` elements are supported throughout?

## Current Protocol Surface

### The Six Protocols

| Protocol | Inherits From | Self | Element | Core Method |
|----------|---------------|------|---------|-------------|
| `Sequence.Protocol` | — | `~Copyable` | `~Copyable` | `makeIterator() -> Iterator` |
| `Sequence.Borrowing.Protocol` | — | `~Copyable, ~Escapable` | `~Copyable` | `makeIterator() -> Iterator` (span-based) |
| `Sequence.Drain.Protocol` | — | `~Copyable` | `~Copyable` | `drain(_ body: (consuming Element) -> Void)` |
| `Sequence.Clearable` | `Sequence.Protocol` | `~Copyable` | `~Copyable` | `removeAll()` |
| `Sequence.Consume.Protocol` | — | `~Copyable` | (Copyable) | `consume() -> View<Element, State>` |
| `Sequence.Iterator.Protocol` | — | `~Copyable` | `~Copyable` | `next() -> Element?` |

### Call-Site Patterns

| Pattern | Requires | Ownership | Container After |
|---------|----------|-----------|-----------------|
| `.forEach { }` | `Sequence.Protocol` | Borrowing | Unchanged |
| `.forEach.borrowing { }` | `Sequence.Protocol` | Borrowing | Unchanged |
| `.forEach.consuming { }` | `Sequence.Clearable` | Iterates, then clears | Empty, usable |
| `.drain { }` | `Sequence.Drain.Protocol` | Consuming (per element) | Empty, usable |
| `.consume().forEach { }` | `Sequence.Consume.Protocol` | Consuming (container destroyed) | Destroyed |

## Constraints

1. **Types exist that conform to Drain without Sequence.Protocol.** 13 types across 4 packages: Buffer.Slab (4), Buffer.Arena (2), Set.Ordered (4), Slab (3). These types support draining but have no iterator — they cannot conform to `Sequence.Protocol`.

2. **Drain and forEach operate on different ownership models.** `forEach` borrows elements through an iterator (`next() -> Element?`). `drain` moves elements out of storage (`consuming Element`). For `~Copyable` elements, these are fundamentally different operations — you cannot borrow a `~Copyable` element through an iterator and then clear the storage, because there is no copy to keep alive during the borrow.

3. **Not all sequences can be cleared.** Read-only views, ranges, and computed sequences have no storage to clear. `removeAll()` is not a universal sequence operation.

4. **Container destruction is a different ownership model.** `consuming func consume()` destroys the container itself. This requires separate state management (a `~Copyable` State type with `deinit` for cleanup on early exit). It cannot be expressed as a method on a borrowed or mutated `self`.

5. **Consume.Protocol.Element lacks ~Copyable suppression.** The protocol declares `associatedtype Element` without `: ~Copyable`. This is a gap, not a simplification opportunity.

6. **Borrowing.Protocol has different Escapable semantics.** Already analyzed in `iterator-protocol-hierarchy.md` — cannot be merged with `Sequence.Protocol` due to `~Escapable` iterators and batch-only iterators.

## Analysis

### Option A: Merge Drain.Protocol into Sequence.Protocol

Add `drain` as a requirement on `Sequence.Protocol`:

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: Sequence.Iterator.`Protocol` where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
    mutating func drain(_ body: (consuming Element) -> Void)  // NEW
}
```

**Why this fails**:

1. **13 types break.** Buffer.Slab, Buffer.Arena, Set.Ordered, and Slab types conform to Drain without Sequence.Protocol. They would need iterators they don't have, or Sequence.Protocol conformance they can't provide.

2. **Semantically wrong.** Not all sequences can be drained. A `Vector` (range-based sequence) has no storage to drain. A read-only span wrapper has no mutable access. Drain is a capability of mutable containers, not an inherent property of sequences.

3. **Default implementation is impossible for ~Copyable elements.** A default `drain` using the iterator would iterate (borrowing), then clear. But for `~Copyable` elements, the iterator borrows — it cannot move elements out. True draining requires knowledge of the storage layout to `moveInitialize` each element. There is no generic way to express "move the next element out" through the iterator protocol.

**Verdict**: Ruled out by Constraint 1 (13 types), Constraint 2 (ownership model), and Constraint 3 (no clear on non-clearable sequences).

### Option B: Merge Clearable into Sequence.Protocol

Add `removeAll` as a requirement on `Sequence.Protocol`:

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: Sequence.Iterator.`Protocol` where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
    mutating func removeAll()  // NEW
}
```

**Why this fails**:

1. **Not all sequences have storage to clear.** `Vector` (a computed range), span wrappers, and lazy transformations cannot implement `removeAll()`. They would need meaningless stub implementations.

2. **35+ conformers would need `removeAll()`.** Every `Sequence.Protocol` conformer would be forced to implement `removeAll()`, even those for which clearing is nonsensical.

3. **Violates protocol design principle.** A protocol should represent a capability that all conformers genuinely possess. Not all iterable things can be cleared.

**Verdict**: Ruled out by Constraint 3. Clearable is correctly a refinement, not a base requirement.

### Option C: Make Drain.Protocol refine Sequence.Protocol

```swift
extension Sequence.Drain {
    public protocol `Protocol`: Sequence.`Protocol` & ~Copyable {
        mutating func drain(_ body: (consuming Element) -> Void)
    }
}
```

**Why this fails**:

Same as Option A, item 1. The 13 types that conform to Drain without Sequence.Protocol (slabs, arenas, ordered sets) would break. These types deliberately do not have iterators — they store elements in non-linear structures (slab allocators, arena pools) where element-at-a-time iteration either doesn't make sense or isn't their primary interface.

**Verdict**: Ruled out by Constraint 1.

### Option D: Make Sequence.Protocol refine Drain.Protocol

Reverse the inheritance — every sequence must also be drainable:

```swift
public protocol `Protocol`: Sequence.Drain.`Protocol` & ~Copyable {
    associatedtype Iterator: Sequence.Iterator.`Protocol` where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
}
```

**Why this fails**:

1. **Not all sequences can be drained.** Same as Option B — read-only sequences, computed sequences, and lazy transformations cannot move elements out.

2. **For Copyable elements, drain has a correct default** (iterate + clear). But for `~Copyable` elements, it does not — the iterator cannot move elements.

3. **Reverses the conceptual hierarchy.** Draining is a more specific capability than iterating. Making all sequences drainable inverts the abstraction level.

**Verdict**: Ruled out. Conceptually and practically wrong.

### Option E: Merge Consume.Protocol into Drain.Protocol

Make consuming iteration a refinement of draining:

```swift
extension Sequence.Drain {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable
        mutating func drain(_ body: (consuming Element) -> Void)
        consuming func consume() -> Sequence.Consume.View<Element, ConsumeState>  // NEW
    }
}
```

**Why this fails**:

1. **Different ownership of `self`.** `drain` is `mutating` — the container survives. `consume` is `consuming` — the container is destroyed. A single protocol cannot require both without forcing all conformers to implement the consuming path.

2. **Different cleanup semantics.** Consume uses a `~Copyable` State type with `deinit` for automatic cleanup on early exit. Drain has no early-exit cleanup mechanism — if the closure returns early, remaining elements stay in the container.

3. **Not all drainable types support consumption.** Slab types can be drained (elements moved out) but destroying the slab itself may not be the right operation — slabs are typically long-lived allocators.

**Verdict**: Ruled out. Different ownership models for `self`.

### Option F: Keep All Protocols (Status Quo)

Maintain the current six protocols with their current relationships.

**Advantages**:

1. **Each protocol captures exactly one capability.** Sequence = iteration. Drain = mutating element extraction. Clearable = storage clearing. Consume = container destruction. Borrowing = span-based batch access.

2. **No forced implementations.** Types conform only to the protocols they genuinely satisfy.

3. **The 13 drain-only types work.** Slabs, arenas, and ordered sets conform to exactly the protocols they support.

4. **Ownership models are correctly separated.** Borrowing (`forEach`), mutating extraction (`drain`), iterate-then-clear (`forEach.consuming`), and container destruction (`consume`) each have distinct safety requirements that the type system can track.

5. **~Copyable element support is correct.** `drain` works for `~Copyable` elements (moves out). `forEach` works for `~Copyable` elements (borrows). Neither depends on the other.

### Comparison

| Criterion | A: Drain→Seq | B: Clear→Seq | C: Drain⊂Seq | D: Seq⊂Drain | E: Consume⊂Drain | F: Status Quo |
|-----------|-------------|-------------|-------------|-------------|------------------|---------------|
| 13 drain-only types | **Break** | OK | **Break** | OK | OK | OK |
| ~Copyable elements | **No default** | OK | **No default** | **No default** | OK | OK |
| Non-clearable sequences | OK | **Forced stub** | OK | **Forced stub** | OK | OK |
| Ownership correctness | Wrong | Wrong | Wrong | Wrong | **Mixed** | Correct |
| Conformer count change | -13 | +35 stubs | -13 | +35 stubs | 0 | 0 |

## Outcome

**Status**: DECISION

**Decision**: **Option F — Keep all six protocols. The protocol surface cannot be simplified.**

**Rationale**:

1. **Drain.Protocol is independent of Sequence.Protocol by necessity, not accident.** 13 concrete types conform to Drain without Sequence.Protocol. These are slab allocators, arena buffers, and ordered sets — types that support element extraction but do not provide element-at-a-time iterators. Any merger in either direction would either break these types or force meaningless implementations.

2. **The three element-access models are genuinely distinct.** Borrowing (`forEach` via iterator), draining (`drain` via element moves), and consuming (`consume` via container destruction) represent different ownership transfers with different safety properties. They cannot be unified without losing type-system enforcement of these distinctions. For `~Copyable` elements, the difference is not just semantic — it determines whether code compiles at all.

3. **Clearable is correctly a refinement, not a base.** Not all sequences have storage to clear. The refinement relationship (`Clearable: Sequence.Protocol`) correctly expresses that clearable sequences are a subset of all sequences. Promoting `removeAll()` to the base would force stub implementations on 35+ types.

4. **The ~Copyable element change did not create redundancy.** The change expanded what each protocol can express, but the protocols were separated by ownership semantics, not by `Copyable` limitations. The separation was always about:
   - Does it have an iterator? → `Sequence.Protocol`
   - Can elements be moved out? → `Drain.Protocol`
   - Can the storage be cleared? → `Clearable`
   - Can the container be destroyed? → `Consume.Protocol`
   - Does it provide span-based access? → `Borrowing.Protocol`

   These are orthogonal capabilities. Supporting `~Copyable` elements in all of them makes each protocol more capable, but does not make any protocol a subset of another.

5. **One potential improvement exists but is additive, not simplifying.** `Sequence.Consume.Protocol.Element` currently lacks `~Copyable` suppression (`associatedtype Element` without `: ~Copyable`). This should be updated for consistency — but this is an expansion of capability, not a simplification of the protocol surface.

**The protocol surface has six protocols because there are six distinct capabilities with six distinct ownership models. ~Copyable element support makes each protocol more powerful, but does not eliminate the distinctions between them.**

## References

- Research: `sequence-protocol-noncopyable-elements.md` v2.0.0 — decision to adopt SuppressedAssociatedTypes
- Research: `iterator-protocol-hierarchy.md` v1.0.0 — parallel iterator protocol analysis
- Buffer.Slab, Buffer.Arena, Set.Ordered, Slab — concrete types conforming to Drain without Sequence.Protocol
- `Sequence.Consume.View` — ~Copyable State with deinit for early-exit cleanup

## Changelog

### v1.1.0 (2026-02-23)

**Sequence.Borrowing.Protocol reframing.** The decision to detach `Collection.Protocol` from `Sequence.Protocol` (see `swift-primitives/Research/collection-sequence-protocol-detachment.md`, RECOMMENDATION, 2026-02-23) changes the role of `Sequence.Borrowing.Protocol`:

- **Before**: The primary mechanism for borrowing iteration over collections with `~Copyable` elements.
- **After**: A chunked span access optimization over `Span.Protocol`, NOT a borrowing iteration mechanism. Borrowing iteration is now handled by `Collection.Protocol` via index/subscript (`Collection.ForEach`).

This does NOT change the decision in v1.0.0 (all six protocols remain). It reframes one protocol's purpose. Doc updates to `Sequence.Borrowing.Protocol` are recommended to reflect this. Deletion is deferred pending audit of bounded-chunk usage (all current call sites pass `Cardinal(UInt.max)`).
