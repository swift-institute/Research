# Iterator Span Buffer Elimination

<!--
---
version: 5.0.0
last_updated: 2026-03-04
status: DECISION
tier: 2
---
-->

## Context

The `Sequence.Iterator.Protocol` unification (Feb 2026) established `nextSpan(maximumCount:) -> Span<Element>` as the sole protocol requirement. A full ecosystem inventory (97 conformers, 65 `Sequence.Protocol` types) reveals **seven distinct `nextSpan` implementation patterns**. Of these, 32 iterators heap-allocate for span backing storage. This research asks: can all 32 be eliminated?

**Trigger**: [RES-001] — Pattern selection. Post-rollout ecosystem-wide audit of `nextSpan` implementations.

**Cross-reference**: `swift-primitives/Research/nextspan-delegation-reduction.md` (RECOMMENDATION) — covers migrating array-buffer iterators to delegation. This research subsumes that into a unified ecosystem-wide analysis.

## Question

Across all 97 `Sequence.Iterator.Protocol` conformers, what is the theoretical minimum number of heap-allocating iterators?

## Analysis

### Ecosystem Inventory

| Pattern | Count | Description | Packages |
|---------|-------|-------------|----------|
| **delegation** | 36 | Forwards `nextSpan` to inner buffer iterator | set, dictionary, array, heap, stack, queue, list, sequence |
| **array-buffer** | 24 | `var _spanBuffer: [Element]` with append loop | tree, graph, hash-table, dictionary, buffer, input |
| **inline-array** | 13 | `InlineArray<1, Element>` fixed storage | bit-vector, cyclic, finite |
| **heap-buffer** | 8 | `UnsafeMutablePointer<Element>.allocate(capacity: 1)` | sequence (Map, Filter, CompactMap), infinite (Observable, Map, Scan, Zip, Cycle) |
| **pointer-based** | 4 | `Span(_unsafeStart:count:)` from contiguous storage | buffer (Linear variants) |
| **span-forwarding** | 4 | Sub-span extraction from owned storage | sequence (Span.Iterator, Difference), parser |
| **two-region** | 3 | Ring buffer split into two pointer regions | buffer (Ring variants) |
| **inline-property** | 2 | `var _spanValue: Element` + `withUnsafeMutablePointer(to: &_spanValue)` | vector |
| **no-nextSpan** | 3 | Declares conformance but missing implementation | bitset, windows |
| **Total** | **97** | | |

### Already Optimal (47 iterators)

| Pattern | Count | Why |
|---------|-------|-----|
| delegation | 36 | Zero overhead — forwards to already-optimal buffer iterator |
| pointer-based | 4 | Zero-copy pointer arithmetic |
| two-region | 3 | Zero-copy ring buffer split |
| span-forwarding | 4 | Zero-copy sub-span extraction |

### The Two Proven Inline Patterns

**Pattern 1: Inline stored property** — production at `Vector.Iterator`:

```swift
var _spanValue: Bound  // needs initial value at init time
@_lifetime(&self)
mutating func nextSpan(maximumCount: Cardinal) -> Span<Bound> {
    _spanValue = computeNext()
    let ptr = withUnsafeMutablePointer(to: &_spanValue) { p in
        unsafe UnsafePointer(p)
    }
    let span = unsafe Span(_unsafeStart: ptr, count: 1)
    return unsafe _overrideLifetime(span, mutating: &self)
}
```

Confirmed by `swift-sequence-primitives/Experiments/stored-property-span-access/` (V1, V3). The `InlineArray<1, T>` pattern used by 13 bit-vector/cyclic/finite iterators is the same thing.

**Limitation**: Requires a valid `Element` value at `init` time. Works for infinite iterators (can eagerly compute first element) and concrete Element types (can use a default). Does NOT work for generic `Element` where the source may be empty.

**Pattern 2: Optional inline** — `Optional<T>` as inline `MaybeUninit<T>`:

```swift
var _element: Element? = nil  // no initial value needed
@_lifetime(&self)
mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
    guard maximumCount > .zero else { return emptySpan() }
    _element = computeNext()
    let ptr = withUnsafeMutablePointer(to: &_element) { p in
        unsafe UnsafePointer<Element>(
            UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
        )
    }
    let s = unsafe Span(_unsafeStart: ptr, count: 1)
    return unsafe _overrideLifetime(s, mutating: &self)
}
```

**Why this works**: `Optional<T>` is a single-payload enum. Swift's ABI (stable since 5.0) defines single-payload enum layout: the `.some` payload is at byte offset 0. For types without extra inhabitants, a tag byte is appended after the payload. For types with extra inhabitants (pointers, enums), one inhabitant represents `.none` and `.some` has identical layout to bare `T`.

In both cases, when `_element` is `.some(value)`, the bytes at `&_element` are a valid `T` at offset 0. The `assumingMemoryBound(to: Element.self)` reinterprets the `Optional<T>` pointer as a `T` pointer. This is physically correct per the ABI layout guarantee.

`Optional<T>` provides everything needed:
- **Inline storage** — same struct, no heap allocation
- **No initial value** — starts as `nil`
- **Deferred initialization** — set to `.some(value)` on first `nextSpan` call
- **Initialization tracking** — `.some` vs `.none` replaces `_bufferInitialized: Bool`

**Critical constraint** (shared with Pattern 1): Only `withUnsafeMutablePointer(to: &_element)` works. The borrowing `withUnsafePointer(to: _element)` may copy for Copyable types (V2 REFUTED).

### Comparison of All Single-Element Patterns

| Metric | Heap Buffer | Inline Property | InlineArray<1> | Optional Inline |
|--------|-------------|-----------------|----------------|-----------------|
| Stored properties | 3 | 1 | 1 | 1 |
| Heap allocation | 1 per iterator | **0** | **0** | **0** |
| Requires `deinit` | Yes | **No** | **No** | **No** |
| Requires `@safe` | Yes | **No** | **No** | **No** |
| Boilerplate | ~25 lines | ~5 lines | ~3 lines | **~5 lines** |
| Needs initial value | No | **Yes** | **Yes** | **No** |
| Works for generic Element | Yes | Only with eager init | Only with default | **Yes** |
| Finite + empty source | Yes | No | No | **Yes** |
| ABI layout dependency | No | No | No | Yes (stable since 5.0) |

The Optional inline pattern supersedes the heap buffer in ALL cases. It has the same universality (works for any `Element`, any source, including empty) with zero heap allocation.

### Applicability by Iterator Category

**Category A: Use inline stored property** (initial value trivially available):

| Iterator | Count | Initial Value |
|----------|-------|--------------|
| `__InfiniteObservableIterator` | 1 | `source.head` |
| `Infinite.Cycle.Iterator` | 1 | `base[base.startIndex]` |
| `Infinite.Scan.Iterator` | 1 | `initial` accumulator |
| `Infinite.Map.Iterator` | 1 | `transform(source.next()!)` |
| `Infinite.Zip.Iterator` | 1 | `(first.next()!, second.next()!)` |
| Concrete-Element non-contiguous | 4–5 | Default value for concrete type |

**Category B: Use Optional inline** (generic Element, finite, may be empty):

| Iterator | Count | Why Optional needed |
|----------|-------|---------------------|
| `Sequence.Map.Iterator` | 1 | Generic `Output`, source may exhaust |
| `Sequence.Filter.Iterator` | 1 | Generic `Element`, filtering + exhaustion |
| `Sequence.CompactMap.Iterator` | 1 | Generic `Output`, compact-mapping + exhaustion |
| Dictionary.Ordered (4 variants) | 4 | Generic `(Key, Value)` tuple |
| Dictionary slab-backed | 1 | Same |
| Tree traversal (11 iterators) | 11 | Generic `Element` |
| Graph traversal (2 iterators) | 2 | Generic `Element` |
| Input.Slice.CollectionIterator | 1 | Generic `Base.Element` |

**Category C: Delegation/pointer (no single-element buffer needed)**:

| Migration | Count |
|-----------|-------|
| Array-buffer → delegation | 19 |
| Array-buffer → pointer upgrade | 3 |
| Buffer.Ring.Inline → two-region | 1 |

### Batch Throughput Tradeoff

Converting array-buffer iterators (tree, graph, dictionary, linked, slab, hash) from `_spanBuffer: [Element]` to single-element `Optional<Element>` loses batch capability. Key consumer: `forEach` calls `nextSpan(maximumCount: .max)`.

| Approach | Alloc | Span Size | Function Calls |
|----------|-------|-----------|----------------|
| array-buffer | 1 heap | Up to n | 1 per batch |
| Optional inline | **0 heap** | 1 | n per sequence |

**Empirical result** (`batch-vs-single-element-span` experiment, release mode, arm64):

| Variant | Nodes | Batch (s) | Single (s) | Ratio |
|---------|-------|-----------|------------|-------|
| V1 (depth 5) | 63 | 0.0685 | 0.0196 | 0.29x |
| V2 (depth 10) | 2,047 | 0.1136 | 0.0496 | 0.44x |
| V3 (depth 15) | 65,535 | 0.0737 | 0.0350 | 0.47x |
| V4 (depth 18) | 524,287 | 0.0606 | 0.0286 | 0.47x |

Single-element is **2-3x faster** than batch. The array-buffer overhead (`removeAll(keepingCapacity:)`, `append`, array metadata) exceeds any batching amortization. The `next()` baseline shows equal performance for both patterns (~0.02-0.04s), confirming the difference is purely in `nextSpan` path overhead.

The original hypothesis was conservative ("negligible difference"). The empirical result is stronger: single-element wins because the batch pattern's array management has its own per-call cost that scales with iteration count, not with batch size.

### Full Improvement Matrix

| Category | Count | Current | Target | Allocation Change |
|----------|-------|---------|--------|-------------------|
| Already optimal | 47 | 0 heap | 0 heap | — |
| InlineArray<1> (already) | 13 | 0 heap | 0 heap | — |
| Inline property (already) | 2 | 0 heap | 0 heap | — |
| Array-buffer → delegation | 19 | 1 heap | **0 heap** | **−19** |
| Array-buffer → pointer upgrade | 3 | 1 heap | **0 heap** | **−3** |
| Buffer.Ring.Inline → two-region | 1 | 1 heap | **0 heap** | **−1** |
| Infinite heap-buffer → inline property | 5 | 1 heap | **0 heap** | **−5** |
| Infinite heap-buffer → inline eager | 3 | 1 heap | **0 heap** | **−3** |
| Non-contiguous concrete → InlineArray<1> | 5 | 1 heap | **0 heap** | **−5** |
| Array-buffer generic → Optional inline | 17 | 1 heap | **0 heap** | **−17** |
| Heap-buffer generic → Optional inline | 3 | 1 heap | **0 heap** | **−3** |
| No nextSpan → implement (inline) | 3 | N/A | 0 heap | N/A |
| **Total** | **97** | **32 heap** | **0 heap** | **−32** |

### Theoretical Minimum

**Zero.** Every heap-allocating iterator in the ecosystem can be converted to a zero-allocation pattern:

- 25 via delegation or pointer upgrade (existing contiguous storage)
- 1 via two-region upgrade (Buffer.Ring.Inline)
- 8 via inline stored property (initial value available)
- 5 via InlineArray<1> (concrete Element with default)
- 20 via Optional inline (generic Element, deferred initialization)
- 3 via InlineArray<1> or Optional (missing nextSpan implementations)

No new language features are required. `Optional<T>` is the inline `MaybeUninit<T>` — Swift's ABI guarantees `.some` payload at offset 0 for all types.

## Outcome

**Status**: DECISION

### ~~Recommendation~~ Decision 1: Optional Inline for All Generic Generating/Non-Contiguous Iterators (P0)

The Optional inline pattern is the universal replacement for both heap-buffer and array-buffer (single-element) patterns when Element is generic. Apply to all 20 iterators in Category B.

**Pattern**:

```swift
struct Iterator: ~Copyable, Sequence.Iterator.`Protocol` {
    var source: Source.Iterator
    var _element: Element? = nil  // inline, zero heap

    @_lifetime(&self) @inlinable
    public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        guard maximumCount > .zero else {
            let ptr = withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<Element>(
                    UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
                )
            }
            let span = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        guard let value = source.next() else {
            // same empty span
        }
        _element = value
        let ptr = withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Element>(
                UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }
}
```

**Eliminates**: 20 heap allocations, all `deinit` implementations, all `@safe` annotations, ~400 lines of boilerplate.

**Verified**: Optional payload-at-offset-0 confirmed across Int, String, class, protocol existential, 2-tuple, and Copyable iterator. See `optional-inline-span` experiment (6 variants, all CONFIRMED). Throughput validated by `batch-vs-single-element-span` (single-element 2-3x faster than batch).

**Applied** (2026-03-04):
- infinite-primitives: 5 iterators converted (Map, Cycle, Scan, Observable, Zip) — commit `bcb8ba3`
- sequence-primitives: 3 iterators converted (Map, Filter, CompactMap) — commit `f4be5ce`

### Recommendation 2: Inline Stored Property for Infinite Iterators (P0)

Convert 8 infinite heap-buffer iterators to inline stored property (Category A). These have natural initial values; Optional overhead is unnecessary.

| Iterator | Initial Value |
|----------|--------------|
| `__InfiniteObservableIterator` | `source.head` |
| `Infinite.Cycle.Iterator` | `base[base.startIndex]` |
| `Infinite.Scan.Iterator` | `initial` accumulator |
| `Infinite.Map.Iterator` | `transform(source.next()!)` |
| `Infinite.Zip.Iterator` | `(first.next()!, second.next()!)` |

**Eliminates**: 5 heap allocations, 5 `deinit`s, 5 `@safe` annotations, ~100 lines boilerplate.

### Recommendation 3: Delegation Migration (P1, per existing research)

Execute `nextspan-delegation-reduction.md`: 19 array-buffer → delegation, 3 → pointer upgrade.

**Eliminates**: 22 heap allocations, 22 per-element copy loops.

### Recommendation 4: Buffer.Ring.Inline Two-Region Upgrade (P2)

Upgrade `Buffer.Ring.Inline.Iterator` from array-buffer to two-region pointer pattern.

**Eliminates**: 1 heap allocation.

### Recommendation 5: InlineArray<1> for Concrete Non-Contiguous (P2)

Convert `Buffer.Linked.Iterator`, `Buffer.Linked.Inline.Iterator`, `Buffer.Slab.Inline.Iterator`, `Hash.Occupied.View.Iterator`, `Hash.Occupied.Static.Iterator` from `_spanBuffer: [Element]` to `InlineArray<1, Element>`.

**Eliminates**: 5 heap allocations.

### Recommendation 6: Missing nextSpan Implementations (P3)

Implement `nextSpan` for `Bitset.Iterator`, `Bitset.Small.Iterator`, `Windows.Kernel.Environment.Entries.Iterator`. Use InlineArray<1> (concrete Element types).

### Summary

| Metric | Current | After All Recommendations |
|--------|---------|--------------------------|
| Heap-allocating iterators | 32 | **0** |
| `deinit` for span buffers | 8 | **0** |
| `@safe` for span buffers | 8 | **0** |
| Duplicated unsafe boilerplate | ~800 lines | ~100 lines (Optional pattern is concise but still unsafe) |
| Missing nextSpan | 3 | 0 |

## References

- `swift-sequence-primitives/Experiments/stored-property-span-access/` — Confirmed inline pattern (V1, V3, V4)
- `swift-vector-primitives/Sources/Vector Primitives Core/` — Production inline-property exemplar
- `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Span+Property.View.swift` — Batch consumer
- `swift-storage-primitives/Research/inline-storage-read-pointer-escape.md` — Pointer escape analysis
- `swift-primitives/Research/nextspan-delegation-reduction.md` — Delegation pattern (subsumed)
- `swift-ownership-primitives/Sources/Ownership Primitives/` — Checked: not suitable
- `swift-reference-primitives/Sources/Reference Primitives/` — Checked: not applicable
- `swift-sequence-primitives/Experiments/optional-inline-span/` — Optional<T> ABI layout verified (6 variants, all CONFIRMED)
- `swift-sequence-primitives/Experiments/batch-vs-single-element-span/` — Batch vs single-element throughput (single 2-3x faster)
- `/tmp/iterator-inventory.md` — Full 97-iterator ecosystem inventory
- `/tmp/sequence-protocol-inventory.md` — Full 65-type Sequence.Protocol inventory
