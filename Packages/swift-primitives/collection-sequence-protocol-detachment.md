# Collection.Protocol / Sequence.Protocol Detachment

<!--
---
version: 1.1.0
last_updated: 2026-02-23
status: DECISION
tier: 2
---
-->

## Context

`Collection.Protocol` currently inherits from `Sequence.Protocol`, mirroring stdlib's `Collection: Sequence`. This inheritance forces all collections to provide `makeIterator()` and an iterator with `next() -> Element?`. For `~Copyable` elements, `next() -> Element?` returns an owned value — a destructive consuming move. This makes the iterator model fundamentally incompatible with multi-pass borrowing access, which is the primary access mode for collections with `~Copyable` elements.

The consequence: `__ArrayProtocol` (the protocol unifying all Array variants) cannot conform to `Collection.Protocol`. Instead, it conforms to `Collection.Bidirectional`, which inherits from `Collection.Indexed` — a separate protocol tree that intentionally avoids `Sequence.Protocol` inheritance. This creates a split hierarchy:

```
Tree 1 (supports ~Copyable elements):
  Collection.Indexed → Collection.Bidirectional → __ArrayProtocol

Tree 2 (requires iterator, Copyable-element iteration):
  Sequence.Protocol → Collection.Protocol
```

These trees cannot be unified under the current design.

**Trigger**: During forEach architecture cleanup (2026-02-23), discovered that multi-protocol forEach ambiguity was caused by competing defaults from `__ArrayProtocol`, `Sequence.Protocol`, and `Collection.Protocol`. Resolving the ambiguity revealed the deeper issue: the Collection/Sequence inheritance was the wrong abstraction boundary.

**Prior research**: `swift-array-primitives/Research/array-protocol-unification.md` (v1.0.0, 2026-02-16) identified `associatedtype Element: ~Copyable` as unsupported and deferred element access unification to "Phase 4 — when Swift gains support." `SuppressedAssociatedTypes` (adopted 2026-02-12 in sequence-primitives) now enables this. The current `__ArrayProtocol` already has `associatedtype Element: ~Copyable` and subscript access.

**Collaborative discussion**: Claude (Anthropic) + ChatGPT (OpenAI), 5 rounds, converged. Transcript at `/tmp/collection-protocol-hierarchy-transcript.md`.

## Question

Should `Collection.Protocol` inherit from `Sequence.Protocol`? If not, what is the target protocol architecture?

## Constraints

| # | Constraint | Impact |
|---|-----------|--------|
| 1 | `next() -> Element?` returns an owned value | For ~Copyable elements, this is a consuming move — incompatible with multi-pass borrowing |
| 2 | `Optional<~Copyable>` compiles in Swift 6.2 | The blocker is not the type system but ownership semantics |
| 3 | `SuppressedAssociatedTypes` is available | `associatedtype Element: ~Copyable` works in user-defined protocols |
| 4 | `Memory.Contiguous.Protocol` exists (memory-primitives) | Provides `var span: Span<Element>` + `withUnsafeBufferPointer` — no need for new span protocol |
| 5 | 4 generic algorithms use `makeIterator()` on `Collection.Protocol` | `count.where`, `count.all`, `min`, `max` — all trivially rewritable to index-based |
| 6 | 2 downstream conformers | `Buffer.Linear` (where Element: Copyable), `Input.Slice` (via conditional extensions) |
| 7 | Collection.ForEach already uses index-based iteration | The index/subscript iteration pattern is proven and deployed |

## Analysis

### Option A: Keep Inheritance (Status Quo)

Maintain `Collection.Protocol: Sequence.Protocol & ~Copyable`.

**Advantages**:
- No migration
- Matches stdlib's `Collection: Sequence`

**Disadvantages**:
- `__ArrayProtocol` cannot conform to `Collection.Protocol` — hierarchy remains split
- Collections must provide iterators even when index-based access is more appropriate
- For ~Copyable elements, `next() -> Element?` forces consuming semantics on what should be borrowing access
- Multi-protocol ambiguity in forEach defaults
- Two parallel protocol trees must be maintained indefinitely

### Option B: Remove Inheritance (Proposed)

Make `Collection.Protocol` standalone:

```swift
extension Collection {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable
        typealias Index = Index_Primitives.Index<Element>
        var startIndex: Index { get }
        var endIndex: Index { get }
        subscript(_ position: Index) -> Element { get }
        func index(after i: Index) -> Index
    }
}
```

**Advantages**:
- `__ArrayProtocol` can conform to `Collection.Protocol` — hierarchy unifies
- Collection and Sequence become orthogonal: Collection = indexed borrowing access, Sequence = iterator consuming access
- No iterator requirement for collections — index/subscript provides borrowing access natively
- Types can conform to both Collection.Protocol and Sequence.Protocol independently when appropriate
- `Collection.ForEach` (index-based) is THE iteration mechanism for collections
- Enables `~Copyable` elements throughout the Collection hierarchy

**Disadvantages**:
- Migration: 4 algorithms rewritten, 2 downstream conformers updated
- Types previously getting Sequence.Protocol "for free" must conform explicitly if they need iterators
- Diverges from stdlib's `Collection: Sequence` pattern

### Option C: Bridge Protocol

Create `Collection.Iterable: Collection.Protocol & Sequence.Protocol` to provide a convenience for types wanting both.

**Advantages**:
- Single conformance for dual-behavior types
- Explicit name for the combined capability

**Disadvantages**:
- Audit found zero algorithms needing both simultaneously
- Every algorithm uses either index-based or iterator-based access, never both
- Adds a third concept without solving a real problem
- Types can already conform to both independently

### Comparison

| Criterion | A: Keep | B: Remove | C: Bridge |
|-----------|---------|-----------|-----------|
| Unifies hierarchy | No | **Yes** | Partial |
| ~Copyable element support | Split | **Full** | Full |
| Migration cost | None | Small (4 algs + 2 types) | Same as B + extra protocol |
| Conceptual clarity | Low (conflated) | **High** (orthogonal) | Medium (three concepts) |
| Matches stdlib | Yes | No | No |
| forEach ambiguity | Present | **Resolved** | Resolved |
| Algorithms needing both | 0 | 0 | 0 |

## Outcome

**Status**: DECISION

**Decision**: **Option B — Remove `Sequence.Protocol` inheritance from `Collection.Protocol`.**

### Rationale

1. **Collection and Sequence are orthogonal concepts.** "I have indexed, multi-pass, subscriptable storage" (Collection) and "I can produce elements one at a time via an iterator" (Sequence) are independent capabilities. The stdlib conflation is an artifact of a Copyable-only world where `next() -> Element?` was indistinguishable from borrowing. With `~Copyable` elements, the ownership difference is concrete and observable.

2. **The split hierarchy is the symptom, not the disease.** `__ArrayProtocol` cannot conform to `Collection.Protocol` because `Collection.Protocol: Sequence.Protocol` requires `makeIterator()`. Removing the inheritance cures the disease — the split hierarchy collapses into one tree.

3. **The migration is small and bounded.** 4 generic algorithms (`count.where`, `count.all`, `min`, `max`) use `makeIterator()` on `Collection.Protocol`. All are trivially rewritten to index-based loops — the exact pattern `Collection.ForEach+Property.View.swift` already uses. The index-based versions are actually better: they support `~Copyable` elements via borrowing subscript, which the iterator-based versions cannot.

4. **No new protocols needed.** `Memory.Contiguous.Protocol` (memory-primitives) already provides span access for contiguous storage. `Sequence.Borrowing.Protocol` is reframed as a chunked span optimization, not a borrowing iteration mechanism. The final architecture has four non-overlapping concepts, three of which already exist.

5. **Bridge protocol has zero use cases.** The audit found no algorithms that need both Collection.Protocol and Sequence.Protocol simultaneously. Every algorithm uses one access mode. Types can conform to both independently.

### Final Architecture

```
Memory tier (memory-primitives):
  Memory.Contiguous.Protocol     → "I have contiguous storage" (span + unsafe pointer)

Sequence tier (sequence-primitives):
  Sequence.Protocol              → "I produce owned elements one at a time" (consuming)
  Sequence.Borrowing.Protocol    → "I produce span chunks" (optimization, eventually removable)

Collection tier (collection-primitives):
  Collection.Protocol            → "I have indexed, subscriptable storage" (borrowing)
  Collection.Indexed             → "I have index navigation" (Step B: merge/keep TBD)
  Collection.Bidirectional       → "I also support backward traversal"

Array tier (array-primitives):
  __ArrayProtocol                → Collection.Bidirectional + mutable subscript
```

### ForEach Tags

Two tags with non-overlapping roles:

| Tag | Iteration Model | Constrained To | Access Mode |
|-----|----------------|----------------|-------------|
| `Collection.ForEach` | Index/subscript loop | `Base: Collection.Protocol` | Borrowing |
| `Sequence.ForEach` | Iterator `next()` loop | `Base: Sequence.Protocol` | Consuming/owned |

Array types migrate from `Sequence.ForEach` to `Collection.ForEach`.

### Experimental Validation

**Experiment**: `swift-collection-primitives/Experiments/collection-sequence-detachment/` — **CONFIRMED** on Swift 6.2.3.

All 23 tests pass. Results:

| Risk | Result |
|------|--------|
| Standalone `Collection.Protocol` with `Element: ~Copyable` + subscript | **CONFIRMED** |
| Index-based Count.all, Count.where, Min, Max | **CONFIRMED** — all produce correct results |
| `__ArrayProtocol: CollectionBidirectional & CollectionProtocol` | **CONFIRMED** — unified hierarchy works |
| Dual conformance (Collection.Protocol + Sequence.Protocol independently) | **CONFIRMED** — no ambiguity |
| ForEach overload resolution with two tags | **CONFIRMED** — `CollectionForEach` and `SequenceForEach` resolve without ambiguity |
| ~Copyable elements through unified hierarchy | **CONFIRMED** — subscript via `_read` coroutine, generic `forEach` |
| `Collection.Clearable` standalone (no `Sequence.Clearable`) | **CONFIRMED** |
| Multiple iteration over ~Copyable collection | **CONFIRMED** — index-based borrowing, container not consumed |

**Key implementation finding**: `_read` coroutine accessor is required for subscripts returning `~Copyable` elements. Protocol declares `{ get }`, but `_read` satisfies it. This is consistent with the production code's use of `{ _read _modify }`.

### Implementation Plan

**Collaborative review**: Claude (Anthropic) + ChatGPT (OpenAI), 4 rounds, converged (2026-02-23). Transcript at `/tmp/collection-sequence-detachment-impl-transcript.md`. Converged plan at `/tmp/collection-sequence-detachment-impl-converged.md`.

**Key decisions from implementation review**:
- `min.index(by:)` / `max.index(by:)` ship with detachment — return `Index?`, canonical for ~Copyable elements
- Copyable `min(by:)` / `max(by:)` reimplemented via minIndex + subscript, constrained `where Element: Copyable`
- `Ordering.Comparator<T: ~Copyable>` audited — already stores `(borrowing T, borrowing T) -> Comparison`, no predicate fallback needed
- `Collection.Indexed` endgame = deletion (Step B), not merge
- `Collection.Bidirectional: Collection.Protocol` after Step B
- `for-in` not at protocol level; types opt into `Swift.Sequence` independently
- `withNext` iterator lending is a separate, sequential migration

**Step A: Detach Sequence from Collection.Protocol**

| Step | Change | Files |
|------|--------|-------|
| A1 | Rewrite `Collection.Protocol` standalone (remove Sequence inheritance, add `Element: ~Copyable`, add `subscript`) | 1 |
| A2 | Rewrite `Count.all`, `Count.where` to index-based | 1 |
| A3 | Add `min.index(by:)` / `max.index(by:)` with `Ordering.Comparator<Element>` → `Index?` | 2 |
| A4 | Rewrite Copyable `min(by:)` / `max(by:)` via minIndex + subscript, `where Element: Copyable` | 2 |
| A5 | Update `Collection.Clearable` — remove `Sequence.Clearable` inheritance, add own `removeAll()` | 1 |
| A6 | Update `Collection.Protocol+Swift.Collection.swift` docs | 1 |
| A7 | Update downstream conformers (Buffer.Linear, Input.Slice + ecosystem audit) | 2+ |
| A8 | Verify `Collection.ForEach` callAsFunction works with standalone Protocol | 1 |
| A9 | Migrate array types from `Sequence.ForEach` to `Collection.ForEach` | 5 |
| A10 | Add `__ArrayProtocol: Collection.Protocol` (dual conformance) | 1 |
| A11 | Mark `Collection.Indexed` as legacy in docs | 1 |
| A12 | Add withNext roadmap note to sequence-primitives docs | 1 |

**Regression guards**:
- `makeIterator()` in `where Base: Collection.Protocol` constraints → must be zero after A2
- New `Collection.Indexed` adoptions → must be zero after A11
- Ownership docs on min/max: `min.index`/`max.index` are canonical for ~Copyable; `min`/`max` require `Element: Copyable`

**Step B: Delete Collection.Indexed, Unify Hierarchy**

| Step | Change |
|------|--------|
| B1 | Make `Collection.Bidirectional: Collection.Protocol` (replace `: Collection.Indexed`) |
| B2 | Delete `Collection.Indexed` |
| B3 | Remove `__ArrayProtocol`'s explicit `: Collection.Protocol` (now inherited via Bidirectional) |
| B4 | Migrate all former `Collection.Indexed` conformers to `Collection.Protocol` or `Collection.Bidirectional` |

**Step C: Reframe Sequence.Borrowing.Protocol**

| Step | Change |
|------|--------|
| C1 | Update docs: "chunked span access optimization over Memory.Contiguous.Protocol, not borrowing iteration" |
| C2 | Add explicit relationship statement: "Conformers typically also conform to Memory.Contiguous.Protocol" |
| C3 | Canonical borrowing iteration guidance → `Collection.ForEach` |
| C4 | Defer deletion until audit confirms zero bounded-chunk usage (all call sites currently pass `Cardinal(UInt.max)`) |

### Verification

```bash
swift build   # in swift-collection-primitives
swift build   # in swift-array-primitives
swift build   # in swift-buffer-primitives
swift test    # across all affected packages
```

## References

- `swift-sequence-primitives/Research/sequence-protocol-noncopyable-elements.md` v2.0.0 — SuppressedAssociatedTypes adoption decision
- `swift-sequence-primitives/Research/iterator-protocol-hierarchy.md` v1.0.0 — parallel iterator protocol architecture
- `swift-sequence-primitives/Research/sequence-protocol-surface-simplification.md` v1.0.0 — six sequence protocols, each distinct
- `swift-array-primitives/Research/array-protocol-unification.md` v1.0.0 → v1.1.0 — Phase 4 now unlocked
- `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Contiguous.Protocol.swift` — existing span access protocol
- Collaborative discussion 1 (design): `/tmp/collection-protocol-hierarchy-transcript.md`
- Converged plan 1 (design): `/tmp/collection-protocol-hierarchy-converged.md`
- Collaborative discussion 2 (implementation): `/tmp/collection-sequence-detachment-impl-transcript.md`
- Converged plan 2 (implementation): `/tmp/collection-sequence-detachment-impl-converged.md`
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
