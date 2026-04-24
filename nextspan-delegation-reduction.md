# nextSpan Delegation Reduction

<!--
---
version: 1.0.0
last_updated: 2026-02-27
status: RECOMMENDATION
tier: 2
---
-->

## Context

The `Sequence.Iterator.Protocol` unification (Feb 2026) established `nextSpan(maximumCount: Cardinal) -> Span<Element>` as the sole protocol requirement. Approximately 50 iterators across 12 primitives packages now implement `nextSpan`. During the rollout, a copy-paste "array buffer pattern" was applied to most data structure iterators:

```swift
@usableFromInline var _spanBuffer: [Element] = []

@_lifetime(&self)
@inlinable
public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
    _spanBuffer.removeAll(keepingCapacity: true)
    var remaining = Int(maximumCount.rawValue)
    while remaining > 0, _position < _end {
        _spanBuffer.append(_buffer[_position])
        _position += .one
        remaining -= 1
    }
    return _spanBuffer.span
}
```

This works but redundantly re-implements iteration logic that the underlying `Buffer.*.Iterator` types already provide — often with superior zero-copy, pointer-based spans.

**Trigger**: [RES-001] — Pattern selection. Multiple valid approaches exist; systematic analysis needed to determine which iterators can delegate.

## Question

Which data structure iterators can delegate their `nextSpan` implementation to their underlying buffer type's iterator, and what are the trade-offs?

## Analysis

### Current Implementation Patterns

Five distinct `nextSpan` implementation patterns exist across the ecosystem:

| Pattern | Mechanism | Allocation | Copy | Count |
|---------|-----------|------------|------|-------|
| **Pointer-based** | `Span(_unsafeStart: base, count: n)` | None | None | 8 |
| **Pointer-based (two-region)** | Two contiguous pointer regions for ring wrap | None | None | 3 |
| **Delegation** | `_inner.nextSpan(maximumCount:)` | None (inherits) | None (inherits) | 7 |
| **Array buffer** | `_spanBuffer.append(...)` + `_spanBuffer.span` | Heap `[Element]` | Per-element | ~28 |
| **Single-element** | `InlineArray<1>` or `UnsafeMutablePointer` | None or 1 allocation | 1 element | ~8 |

The array buffer pattern dominates (28 of ~50 iterators), yet in most cases the underlying buffer already has a pointer-based or two-region iterator with zero-copy `nextSpan`.

### Iterator Storage Anatomy

Every array-buffer iterator stores four fields:

```swift
let _buffer: Buffer<Element>.SomeVariant   // the data source
var _position: Index                       // current position
let _end: Index.Count                      // boundary
var _spanBuffer: [Element] = []            // heap allocation for span materialization
```

The delegation alternative stores one field:

```swift
var _inner: Buffer<Element>.SomeVariant.Iterator
```

### Delegation Feasibility by Buffer Type

#### Buffer.Linear — 6 direct candidates

These iterators store a `Buffer<Element>.Linear` and walk it with `_buffer[_position]`:

| Iterator | Buffer Field | Buffer Has `makeIterator()`? |
|----------|-------------|------------------------------|
| `Stack.Iterator` | `_buffer: Buffer<Element>.Linear` | Yes |
| `Heap.Iterator` | `_buffer: Buffer<Element>.Linear` | Yes |
| `Heap.MinMax.Iterator` | `_buffer: Buffer<Element>.Linear` | Yes |
| `Set.Ordered.Iterator` | `buffer: Buffer<Element>.Linear` | Yes |
| `Dictionary.Ordered.Values.Iterator` | `_values: Buffer<Value>.Linear` | Yes |

`Buffer.Linear.Iterator` uses the pointer-based pattern:

```swift
let take = Index<Element>.Count.min(.init(maximumCount), remaining)
let span = unsafe Swift.Span(_unsafeStart: base, count: take)
unsafe base = base + Int(bitPattern: take)
remaining = remaining.subtract.saturating(take)
return span
```

Delegation eliminates: heap allocation, per-element copy, subscript overhead.

#### Buffer.Linear.Bounded — 3 direct candidates

| Iterator | Buffer Field |
|----------|-------------|
| `Stack.Bounded.Iterator` | `_buffer: Buffer<Element>.Linear.Bounded` |
| `Heap.Fixed.Iterator` | `_buffer: Buffer<Element>.Linear.Bounded` |
| `Set.Ordered.Fixed.Iterator` | `buffer: Buffer<Element>.Linear.Bounded` |

Same pointer-based `nextSpan` as `Buffer.Linear.Iterator`.

#### Buffer.Ring — 2 direct candidates

| Iterator | Buffer Field |
|----------|-------------|
| `Queue.Dynamic.Iterator` | `_buffer: Buffer<Element>.Ring` |
| `Queue.DoubleEnded.Iterator` | `_buffer: Buffer<Element>.Ring` |

`Buffer.Ring.Iterator` pre-computes two contiguous pointer regions at init time, yielding true zero-copy spans that never cross the ring boundary. The current `Queue.Dynamic.Iterator` instead walks logical indices through `_buffer[_logicalIndex.map(Ordinal.init)]`, which performs modular arithmetic on every access and copies each element into `_spanBuffer`.

#### Buffer.Ring.Bounded — 2 direct candidates

| Iterator | Buffer Field |
|----------|-------------|
| `Queue.Fixed.Iterator` | `_buffer: Buffer<Element>.Ring.Bounded` |
| `Queue.DoubleEnded.Fixed.Iterator` | `_buffer: Buffer<Element>.Ring.Bounded` |

Same two-region pointer pattern as `Buffer.Ring.Iterator`.

#### Snapshot Buffer.Linear — 12 candidates

These iterators create a `Buffer.Linear` snapshot at `makeIterator()` time (O(n) copy) because their backing storage is inline (non-escapable pointer):

| Iterator | Snapshot Type |
|----------|--------------|
| `Stack.Static.Iterator` | `Buffer<Element>.Linear` |
| `Stack.Small.Iterator` | `Buffer<Element>.Linear` |
| `Queue.Static.Iterator` | `Buffer<Element>.Linear` |
| `Queue.Small.Iterator` | `Buffer<Element>.Linear` |
| `Queue.DoubleEnded.Static.Iterator` | `Buffer<Element>.Linear` |
| `Queue.DoubleEnded.Small.Iterator` | `Buffer<Element>.Linear` |
| `Heap.Static.Iterator` | `Buffer<Element>.Linear` |
| `Heap.Small.Iterator` | `Buffer<Element>.Linear` |
| `Set.Ordered.Static.Iterator` | `Buffer<Element>.Linear` |
| `Set.Ordered.Small.Iterator` | `Buffer<Element>.Linear` |
| `Dictionary.Ordered.Static.Iterator` | `Buffer<Element>.Linear` (×2) |
| `Dictionary.Ordered.Small.Iterator` | `Buffer<Element>.Linear` (×2) |

The O(n) snapshot is already being paid at `makeIterator()` time. Currently the snapshot is then walked *again* via subscript into `_spanBuffer`. Delegating to `snapshot.makeIterator()` eliminates the second copy entirely — the snapshot's pointer-based iterator yields zero-copy spans over the already-paid snapshot.

### Iterators That Cannot Delegate

| Category | Iterators | Reason |
|----------|-----------|--------|
| **Sparse/bitmap** | `Buffer.Slab.Inline`, `Hash.Occupied.View`, `Hash.Occupied.Static`, `Dictionary` (slab) | Occupancy-gated; no contiguous run of elements. `_spanBuffer` required. |
| **Linked** | `Buffer.Linked`, `Buffer.Linked.Inline` | Pointer-chasing between nodes. `_spanBuffer` required. |
| **Ring inline** | `Buffer.Ring.Inline` | Ring wrap within inline storage; no two-region decomposition available at this level. |
| **Traversal** | `Graph.Traversal.First.Depth`, `Graph.Traversal.First.Breadth` | Traversal state (visited set, stack/queue) is integral to iteration. |
| **Transformation** | `Sequence.Map`, `Sequence.Filter`, `Sequence.CompactMap` | Element type changes; no underlying span to forward. |
| **Collection** | `Input.Slice.CollectionIterator` | Generic `Collection` subscript; no buffer to delegate to. |
| **Single-element** | `Vector.Iterator`, `Cyclic.Group.Static`, `Finite.Enumeration`, `Bit.Vector.*` | Already optimal (InlineArray/stored-value pattern). |
| **Span-based** | `Swift.Span.Iterator` | Already optimal (zero-copy sub-span extraction). |

### Constraint: Buffer Iterator init is `internal`

All buffer iterator constructors (`Buffer.Linear.Iterator.init`, `Buffer.Ring.Iterator.init`, etc.) have `internal` access. Data structures **cannot** construct them directly. They must call `buffer.makeIterator()`.

This is the correct design — it encapsulates the unsafe pointer extraction within the buffer module. Every existing delegation (`Array.Small`, `Queue.Linked`, `List.Linked`) uses this pattern:

```swift
public borrowing func makeIterator() -> Iterator {
    Iterator(_inner: _buffer.makeIterator())
}
```

No changes to buffer-primitives are required to enable delegation from downstream packages.

### Pointer-Upgrade Candidates

Three iterators use the array-buffer pattern despite having contiguous `UnsafePointer` storage:

| Iterator | Stored Fields | Why Pointer-Based Would Work |
|----------|--------------|------------------------------|
| `Array.Dynamic.Iterator` | `base: UnsafePointer<Element>`, `end`, `position` | Contiguous; same pointer-arithmetic pattern as `Buffer.Linear.Iterator` |
| `Array.Fixed.Iterator` | `base: UnsafePointer<Element>`, `end`, `index` | Contiguous; identical case |
| `Buffer.Linear.Inline.Iterator` | `base: UnsafePointer<Element>`, `current`, `end` | Contiguous inline storage; pointer is valid for iteration lifetime |

These could adopt the pointer-based pattern directly (inline their own `Span(_unsafeStart:count:)`) rather than delegating, since they already hold the raw pointer.

### Dictionary Tuple Iterators — Partial Delegation

Four ordered dictionary iterators produce `(key: Key, value: Value)` tuples by zipping a key buffer with a value buffer:

| Iterator | Key Source | Value Source |
|----------|-----------|--------------|
| `Dictionary.Ordered.Iterator` | `Set<Key>.Ordered` | `Buffer<Value>.Linear` |
| `Dictionary.Ordered.Bounded.Iterator` | `Set<Key>.Ordered` | `Buffer<Value>.Linear.Bounded` |
| `Dictionary.Ordered.Static.Iterator` | `Buffer<Key>.Linear` (snapshot) | `Buffer<Value>.Linear` (snapshot) |
| `Dictionary.Ordered.Small.Iterator` | `Buffer<Key>.Linear` (snapshot) | `Buffer<Value>.Linear` (snapshot) |

These cannot fully delegate because no single buffer produces the required tuple element type. The `_spanBuffer` is structurally necessary for tuple materialization. However, the individual buffer accesses within the loop body could potentially use buffer iterator advancement rather than subscript indexing.

### Comparison Table

| Criterion | Array Buffer Pattern | Delegation Pattern | Pointer Upgrade |
|-----------|---------------------|-------------------|-----------------|
| Heap allocation | Yes (`[Element]`) | No | No |
| Per-element copy in `nextSpan` | Yes | No | No |
| Code in iterator struct | ~20 lines | ~6 lines | ~15 lines |
| Stored properties | 4 | 1 | 3 |
| Cross-module dependency | None | Buffer module's `Iterator` type | None |
| Works for non-contiguous data | Yes | Only if buffer supports it | No |
| `@_lifetime` complexity | Simple (`&self`) | Forwarded | Same as pointer-based |

### Impact Assessment

| Metric | Current | After Delegation | Reduction |
|--------|---------|-----------------|-----------|
| Iterators using `_spanBuffer` | 28 | 9 | −19 |
| Iterators using pointer-based | 11 | 11 | — |
| Iterators using delegation | 7 | 26 | +19 |
| Iterators using single-element | 8 | 8 | — |
| Heap allocations per iterator creation | 25 | 6 | −19 |
| Redundant per-element copies | 25 | 6 | −19 |

The 3 pointer-upgrade candidates would further reduce `_spanBuffer` usage from 9 to 6.

### Remaining `_spanBuffer` Users (Post-Migration)

After delegation + pointer upgrades, only 6 iterators would retain `_spanBuffer`:

1. `Buffer.Ring.Inline.Iterator` — ring wrap in inline storage
2. `Buffer.Linked.Iterator` — linked node traversal
3. `Buffer.Linked.Inline.Iterator` — inline linked node traversal
4. `Buffer.Slab.Inline.Iterator` — sparse bitmap occupancy
5. `Hash.Occupied.View.Iterator` — sparse bucket scan
6. `Hash.Occupied.Static.Iterator` — sparse InlineArray bucket scan

Plus the 4 dictionary tuple iterators (structural necessity) and the 2 graph traversal iterators (stateful traversal).

### Migration Template

For each delegable iterator, the transformation is mechanical:

**Before:**
```swift
public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
    @usableFromInline let _buffer: Buffer<Element>.Linear
    @usableFromInline let _end: Index.Count
    @usableFromInline var _position: Index = .zero
    @usableFromInline var _spanBuffer: [Element] = []

    @usableFromInline
    init(_buffer: Buffer<Element>.Linear) {
        self._buffer = _buffer
        self._end = _buffer.count
    }

    @_lifetime(&self) @inlinable
    public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        _spanBuffer.removeAll(keepingCapacity: true)
        var remaining = Int(maximumCount.rawValue)
        while remaining > 0, _position < _end {
            _spanBuffer.append(_buffer[_position])
            _position += .one
            remaining -= 1
        }
        return _spanBuffer.span
    }

    @_lifetime(self: immortal) @inlinable
    public mutating func next() -> Element? {
        guard _position < _end else { return nil }
        let element = _buffer[_position]
        _position += .one
        return element
    }
}

public borrowing func makeIterator() -> Iterator {
    Iterator(_buffer: _buffer)
}
```

**After:**
```swift
public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
    @usableFromInline
    var _inner: Buffer<Element>.Linear.Iterator

    @usableFromInline
    init(_inner: Buffer<Element>.Linear.Iterator) {
        self._inner = _inner
    }

    @_lifetime(&self) @inlinable
    public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        _inner.nextSpan(maximumCount: maximumCount)
    }

    @_lifetime(self: immortal) @inlinable
    public mutating func next() -> Element? {
        _inner.next()
    }
}

public borrowing func makeIterator() -> Iterator {
    Iterator(_inner: _buffer.makeIterator())
}
```

4 stored properties → 1. ~20 lines → ~6 lines. Heap allocation eliminated.

## Outcome

**Status**: RECOMMENDATION

### Primary Recommendation

**Migrate 25 data structure iterators from array-buffer pattern to delegation pattern.** The underlying buffer types already provide correct, efficient, pointer-based `nextSpan` implementations. The data structure iterators currently duplicate this work at lower quality (heap allocation + per-element copy vs zero-copy pointer spans).

### Migration Priorities

| Priority | Iterators | Buffer Target | Count | Rationale |
|----------|-----------|---------------|-------|-----------|
| **P0** | Queue.Dynamic, Queue.Fixed, Queue.DoubleEnded, Queue.DoubleEnded.Fixed | `Buffer.Ring{.Bounded}.Iterator` | 4 | Largest perf win: eliminates modular arithmetic + copy on every ring-buffer element |
| **P1** | Stack, Stack.Bounded, Heap, Heap.Fixed, Heap.MinMax, Set.Ordered, Set.Ordered.Fixed, Dict.Ordered.Values | `Buffer.Linear{.Bounded}.Iterator` | 8 | Direct buffer storage; simple 1:1 delegation |
| **P2** | Stack.Static, Stack.Small, Queue.Static, Queue.Small, Heap.Static, Heap.Small, Set.Ordered.Static, Set.Ordered.Small, Q.DE.Static, Q.DE.Small, Dict.Ordered.Static, Dict.Ordered.Small | `Buffer.Linear.Iterator` (snapshot) | 12 | Already pay O(n) snapshot; delegation avoids second copy |
| **P3** | Array.Dynamic, Array.Fixed, Buffer.Linear.Inline | Pointer upgrade (self-contained) | 3 | Already hold UnsafePointer; switch from `_spanBuffer` to `Span(_unsafeStart:count:)` |

### No Changes Required

- **Buffer-primitives**: All buffer iterator `makeIterator()` methods are already public. No access control changes needed.
- **Protocol conformance**: The delegation pattern already satisfies `Sequence.Iterator.Protocol` (proven by 7 existing delegators).
- **`@_lifetime` annotations**: `@_lifetime(&self)` on `nextSpan` and `@_lifetime(self: immortal)` on `next()` remain correct for delegation — the span borrows from `_inner` which is stored in `self`.

### Not Recommended for Migration

- Dictionary ordered iterators producing `(key:, value:)` tuples — structural mismatch
- Graph traversal iterators — stateful traversal logic
- Sparse/bitmap iterators — no contiguous buffer to delegate to
- Linked-list buffer iterators — already the leaf implementation
- Single-element and span-based iterators — already optimal

## References

- `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift` — protocol definition
- `swift-buffer-primitives/Sources/Buffer Linear Primitives/Buffer.Linear+Span.swift` — pointer-based reference implementation
- `swift-buffer-primitives/Sources/Buffer Ring Primitives/Buffer.Ring+Span.swift` — two-region reference implementation
- `swift-array-primitives/Sources/Array Small Primitives/Array.Small.swift` — delegation exemplar
- `swift-queue-primitives/Sources/Queue Linked Primitives/Queue.Linked Copyable.swift` — delegation exemplar
- `swift-primitives/Research/collection-sequence-protocol-detachment.md` — related protocol design
