<!--
version: 1.0.0
last_updated: 2026-04-15
status: COMPLETE
scope: Phase 1 Agent 2 classification of @unchecked Sendable sites in swift-storage-primitives, swift-queue-primitives, swift-stack-primitives
agent: 2 of 5
-->

# Agent 2 Findings — Storage / Queue / Stack

## Summary

| Metric | Count |
|--------|:-----:|
| Total hits | 30 |
| Cat A (synchronized) | 0 |
| Cat B (ownership transfer) | 30 |
| Cat C (thread-confined) | 0 |
| D candidates (flagged to adjudication queue) | 11 |
| Low-confidence | 8 (subset of the D candidates — the outer `<let N: Int>` Inline/Static/Small variants where B is primary but D is plausible) |
| Preexisting warnings noted | 0 |

**Scope confirmation**: Grep of each repo's `Sources/` yielded:

- `swift-storage-primitives/Sources/`: 9 conformances across 6 files (plus 3 `// @_rawLayout types require @unchecked Sendable` comment lines that the grep surfaced but are not conformance sites).
- `swift-queue-primitives/Sources/`: 15 conformances across 10 files.
- `swift-stack-primitives/Sources/`: 6 conformances across 6 files.

**Overall shape**: Scope is entirely Category B. Every hit either:

1. Conforms a `~Copyable` value-type container (ownership transfer is the primary invariant), or
2. Conforms a reference-semantic `final class` storage handle that is owned exclusively by a `~Copyable` Buffer wrapper (ownership transfer is the invariant at the outer Buffer layer, propagated through the class reference), or
3. Conforms a struct iterator whose internal buffer iterator holds raw pointers; sending the iterator is a one-shot transfer of the iteration state.

No mutex/atomic/lock synchronization anywhere in scope (no Cat A). No poll-thread-confined state (no Cat C).

**D candidates**: 11 sites flagged to the Category D adjudication queue. Split into:

- **3 clear D candidates** — the inner `_Raw` types (`Storage.Inline._Raw`, `Storage.Arena.Inline._Raw`, `Storage.Pool.Inline._Raw`). These are `@_rawLayout(likeArrayOf: Element, count: capacity)` wrappers whose sole purpose is layout computation. The file comment `// @_rawLayout types require @unchecked Sendable` plainly states this is a compiler-workaround site. There is no caller invariant — the raw bytes simply contain Elements, and Sendable inference can't traverse `@_rawLayout`.
- **8 outer `<let N: Int>` Inline/Static/Small variants** — these are `~Copyable` containers with a `<let capacity: Int>` or `<let inlineCapacity: Int>` value-generic. Primary classification is B (ownership transfer through `~Copyable`), but the handoff specifically calls out this shape for adjudication, and the compiler's inability to propagate Sendable through `<let N: Int>` is part of why `@unchecked` appears. These are LOW_CONFIDENCE for the B-vs-D boundary; principal should decide whether the value-generic is load-bearing in the classification.

---

## Classifications

| # | File:Line | Type | Category | Reasoning | Docstring ref |
|---|-----------|------|:--------:|-----------|---------------|
| 1 | `swift-storage-primitives/Sources/Storage Slab Primitives/Storage.Slab ~Copyable.swift:68` | `Storage.Slab` (final class) | **B** | Class owns `Storage.Heap` + `Bit.Vector.Bounded`. The class itself is reference-mutable, but it is held exclusively by a `Buffer.Slab` `~Copyable` struct; ownership transfer is single-owner through the wrapping struct. CoW via `isKnownUniquelyReferenced`. | Appendix A1 |
| 2 | `swift-storage-primitives/Sources/Storage Pool Primitives/Storage.Pool ~Copyable.swift:156` | `Storage.Pool` (final class) | **B** | Same shape as Storage.Slab. Final class owned through `~Copyable` Buffer.Pool. | Appendix A2 |
| 3 | `swift-storage-primitives/Sources/Storage Arena Primitives/Storage.Arena ~Copyable.swift:115` | `Storage.Arena` (final class) | **B** | Same shape. Final class wrapping `Memory.Arena` + meta SoA; owned through `~Copyable` Buffer.Arena. | Appendix A3 |
| 4 | `swift-storage-primitives/Sources/Storage Inline Primitives/Storage.Inline ~Copyable.swift:128` | `Storage.Inline._Raw` (~Copyable, `@_rawLayout`, `<let capacity: Int>`) | **D candidate** | Inner package-scoped `_Raw` struct exists solely to host `@_rawLayout(likeArrayOf: Element, count: capacity)`. File comment states `// @_rawLayout types require @unchecked Sendable`. No caller invariant — raw storage. Flagged to queue. | — |
| 5 | `swift-storage-primitives/Sources/Storage Inline Primitives/Storage.Inline ~Copyable.swift:132` | `Storage.Inline<let capacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Outer `~Copyable` container with `@_rawLayout` storage, bitvector-tracked slot init, deinit iterates `_slots.ones`. Primary classification: ownership transfer. But `<let capacity: Int>` blocks structural Sendable inference; per handoff, flag for adjudication. | Appendix B1 |
| 6 | `swift-storage-primitives/Sources/Storage Arena Inline Primitives/Storage.Arena.Inline ~Copyable.swift:179` | `Storage.Arena.Inline._Raw` (~Copyable, `@_rawLayout`, `<let capacity: Int>`) | **D candidate** | Same as (4): `@_rawLayout` raw storage, no caller invariant. Flagged to queue. | — |
| 7 | `swift-storage-primitives/Sources/Storage Arena Inline Primitives/Storage.Arena.Inline ~Copyable.swift:180` | `Storage.Arena.Inline<let capacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Bump-allocator arena with bitvector-tracked slots; `~Copyable` container. Same B-vs-D judgment as (5). | Appendix B2 |
| 8 | `swift-storage-primitives/Sources/Storage Pool Inline Primitives/Storage.Pool.Inline ~Copyable.swift:187` | `Storage.Pool.Inline._Raw` (~Copyable, `@_rawLayout`, `<let capacity: Int>`) | **D candidate** | Same as (4). Flagged to queue. | — |
| 9 | `swift-storage-primitives/Sources/Storage Pool Inline Primitives/Storage.Pool.Inline ~Copyable.swift:188` | `Storage.Pool.Inline<let capacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Bitmap-scanning pool with per-slot reuse. Same B-vs-D judgment as (5). | Appendix B3 |
| 10 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.swift:123` | `Queue<Element>` (~Copyable, conditionally Copyable) | **B** | Dynamically-growing FIFO ring-buffer queue. `~Copyable` container; conditionally `Copyable` with CoW on `Element: Copyable`. `@unchecked` because ring buffer holds CoW storage reference. | Appendix B4 |
| 11 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.Fixed.swift:72` | `Queue.Fixed` (struct, conditionally Copyable) | **B** | Fixed-capacity ring buffer queue. Same CoW pattern as Queue. | Appendix B5 |
| 12 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.Static.swift:41` | `Queue.Static<let capacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Zero-allocation inline ring-buffer queue; `<let capacity: Int>` value-generic. Ownership transfer primary; value-generic flag for adjudication. | Appendix B6 |
| 13 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.Small.swift:62` | `Queue.Small<let inlineCapacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Small-buffer optimization (inline then spill). Same shape as Queue.Static. | Appendix B7 |
| 14 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.DoubleEnded.swift:79` | `Queue.DoubleEnded` (struct, conditionally Copyable) | **B** | Dynamic deque using ring buffer; CoW on `Element: Copyable`. | Appendix B8 |
| 15 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.DoubleEnded.swift:82` | `Queue.DoubleEnded.Fixed` (struct, conditionally Copyable) | **B** | Fixed-capacity deque. Same CoW pattern. | Appendix B9 |
| 16 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.DoubleEnded.Static.swift:41` | `Queue.DoubleEnded.Static<let capacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Inline-storage deque. Value-generic. | Appendix B10 |
| 17 | `swift-queue-primitives/Sources/Queue Primitives Core/Queue.DoubleEnded.Small.swift:44` | `Queue.DoubleEnded.Small<let inlineCapacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Small-buffer deque. Value-generic. | Appendix B11 |
| 18 | `swift-queue-primitives/Sources/Queue Linked Primitives/Queue.Linked Copyable.swift:214` | `Queue.Linked` (~Copyable, conditionally Copyable) | **B** | Arena-based linked FIFO queue. `~Copyable`; conditionally Copyable with CoW. | Appendix B12 |
| 19 | `swift-queue-primitives/Sources/Queue Linked Primitives/Queue.Linked.Bounded.swift:224` | `Queue.Linked.Fixed` (~Copyable, conditionally Copyable) | **B** | Fixed-capacity linked queue. Same CoW pattern. | Appendix B13 |
| 20 | `swift-queue-primitives/Sources/Queue Linked Primitives/Queue.Linked.Inline+Small.swift:110` | `Queue.Linked.Inline<let capacity: Int>` (~Copyable, Element: Copyable only) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Inline-storage linked queue; value-generic. | Appendix B14 |
| 21 | `swift-queue-primitives/Sources/Queue Linked Primitives/Queue.Linked.Inline+Small.swift:200` | `Queue.Linked.Small<let inlineCapacity: Int>` (~Copyable, Element: Copyable only) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Small-buffer linked queue; value-generic. | Appendix B15 |
| 22 | `swift-queue-primitives/Sources/Queue Fixed Primitives/Queue.Fixed Copyable.swift:43` | `Queue.Fixed.Iterator` (struct, Element: Copyable) | **B** | Sequence iterator wrapping `Buffer.Ring.Bounded.Iterator`. Internal buffer iterator holds raw pointers into CoW storage; iterator is a one-shot transferable iteration token. | Appendix B16 |
| 23 | `swift-queue-primitives/Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.swift:558` | `Queue.DoubleEnded.Iterator` (struct, Element: Copyable) | **B** | Same pattern as Queue.Fixed.Iterator — transferable iteration state. | Appendix B17 |
| 24 | `swift-queue-primitives/Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded Copyable.swift:174` | `Queue.DoubleEnded.Fixed.Iterator` (struct, Element: Copyable) | **B** | Same pattern. | Appendix B18 |
| 25 | `swift-stack-primitives/Sources/Stack Primitives Core/Stack.swift:204` | `Stack<Element>` (~Copyable, conditionally Copyable) | **B** | Dynamically-growing LIFO stack using `Buffer.Linear`. `~Copyable`; conditionally Copyable with CoW. Docstring already states "concurrent mutation requires external synchronization". | Appendix B19 |
| 26 | `swift-stack-primitives/Sources/Stack Bounded Primitives/Stack.Bounded ~Copyable.swift:176` | `Stack.Bounded` (struct, conditionally Copyable) | **B** | Fixed-capacity stack with `Buffer.Linear.Bounded`. Same CoW pattern as Stack. | Appendix B20 |
| 27 | `swift-stack-primitives/Sources/Stack Small Primitives/Stack.Small ~Copyable.swift:141` | `Stack.Small<let inlineCapacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Small-buffer stack; value-generic. | Appendix B21 |
| 28 | `swift-stack-primitives/Sources/Stack Static Primitives/Stack.Static ~Copyable.swift:139` | `Stack.Static<let capacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Inline-storage stack; value-generic. | Appendix B22 |
| 29 | `swift-stack-primitives/Sources/Stack Bounded Primitives/Stack.Bounded Copyable.swift:53` | `Stack.Bounded.Iterator` (struct, Element: Copyable) | **B** | Sequence iterator wrapping `Buffer.Linear.Bounded.Iterator`. Transferable iteration token. | Appendix B23 |
| 30 | `swift-stack-primitives/Sources/Stack Dynamic Primitives/Stack Copyable.swift:130` | `Stack.Iterator` (struct, Element: Copyable) | **B** | Same as Stack.Bounded.Iterator. | Appendix B24 |

---

## Appendix — Draft docstrings

All docstrings follow the pilot's three-section form (Safety Invariant / Intended Use / Non-Goals). For Category B sites, the Safety Invariant paragraph uses the ownership-transfer template from `unsafe-audit-findings.md`. Every annotation should be written as:

```swift
extension {Type}: @unsafe @unchecked Sendable where Element: Sendable {}
```

(The existing forms are all extension-site. Keep that shape; add `@unsafe` and the docstring immediately above the extension.)

### Category B docstrings

#### Appendix A1 — `Storage.Slab`

```swift
/// `Storage.Slab` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// The class holds `Storage.Heap` + `Bit.Vector.Bounded` without internal
/// synchronization. Soundness depends on the wrapping `~Copyable` container
/// (`Buffer.Slab` / `Buffer.Slab.Bounded`) enforcing single-owner semantics:
/// the class reference is held by exactly one struct at a time, and ownership
/// transfer across threads is a move (not a copy). The old thread cannot
/// access the storage after the move.
///
/// ## Intended Use
///
/// - Moving a `Buffer.Slab`-backed data structure from a producer thread to
///   a consumer thread as a one-shot transfer.
/// - Sending a `Buffer.Slab` into an `actor`'s initializer.
/// - Value-type CoW dispatch via `isKnownUniquelyReferenced`.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. The storage has no internal locks.
/// All access must be serialized by the owning thread; sendability is
/// ownership transfer, not sharing.
extension Storage.Slab: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix A2 — `Storage.Pool`

```swift
/// `Storage.Pool` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// The class holds `Memory.Pool` (virgin cursor + free list + allocation
/// bitmap) without internal synchronization. Soundness depends on the
/// wrapping `~Copyable` container (`Buffer.Pool`) enforcing single-owner
/// semantics: exactly one struct holds the class reference at any time,
/// and ownership transfer across threads is a move. The old thread cannot
/// access the pool after the move.
///
/// ## Intended Use
///
/// - Moving a `Buffer.Pool`-backed data structure from a producer thread
///   to a consumer thread as a one-shot transfer.
/// - Sending a `Buffer.Pool` into an `actor`'s initializer.
/// - CoW dispatch via `isKnownUniquelyReferenced`.
///
/// ## Non-Goals
///
/// Does NOT support concurrent allocation/deallocation. All pool operations
/// must be serialized by the owning thread.
extension Storage.Pool: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix A3 — `Storage.Arena`

```swift
/// `Storage.Arena` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// The class holds `Memory.Arena` + a generation-token meta array without
/// internal synchronization. Soundness depends on the wrapping `~Copyable`
/// container (`Buffer.Arena` / `Buffer.Arena.Bounded`) enforcing single-
/// owner semantics: exactly one struct holds the class reference at any
/// time, and ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Moving a `Buffer.Arena`-backed data structure from a producer thread
///   to a consumer thread as a one-shot transfer.
/// - Sending a `Buffer.Arena` into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent slot allocation/reclamation. All arena
/// operations must be serialized by the owning thread.
extension Storage.Arena: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B1 — `Storage.Inline<let capacity: Int>`

```swift
/// `Storage.Inline` is `Sendable` when its elements are `Sendable`.
/// Requires @unchecked because `_Raw` uses `@unchecked Sendable` for `@_rawLayout` storage.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership: the value lives in exactly one
/// stack slot at a time, and transfer across threads is a move. The old
/// thread cannot access the storage after the move. The inline `@_rawLayout`
/// buffer and its slot-tracking bitvector travel together as one unit.
///
/// ## Intended Use
///
/// - Moving a fixed-capacity inline buffer from a producer thread to a
///   consumer thread as a one-shot transfer.
/// - Storing inside a larger `~Copyable` / `Sendable` container that is
///   itself ownership-transferred.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. Ownership is single-owner; transfer
/// is one-shot. The `@unchecked` covers the compiler's inability to infer
/// Sendable through `@_rawLayout` storage + `<let capacity: Int>`.
extension Storage.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B2 — `Storage.Arena.Inline<let capacity: Int>`

```swift
/// `Storage.Arena.Inline` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The inline bump-allocator arena
/// and its slot-tracking bitvector travel together; transfer across threads
/// is a move, not a copy. The old thread cannot access the arena after the move.
///
/// ## Intended Use
///
/// - Moving a static-capacity arena from a producer thread to a consumer
///   thread as a one-shot transfer.
/// - Embedding inside a larger `~Copyable` / `Sendable` container.
///
/// ## Non-Goals
///
/// Does NOT support concurrent allocation. Ownership is single-owner;
/// transfer is one-shot.
extension Storage.Arena.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B3 — `Storage.Pool.Inline<let capacity: Int>`

```swift
/// `Storage.Pool.Inline` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The inline bitmap-scanned pool
/// and its allocation bitvector travel together; transfer across threads
/// is a move. The old thread cannot access the pool after the move.
///
/// ## Intended Use
///
/// - Moving a static-capacity pool from a producer thread to a consumer
///   thread as a one-shot transfer.
/// - Embedding inside a larger `~Copyable` / `Sendable` container.
///
/// ## Non-Goals
///
/// Does NOT support concurrent allocation/deallocation. Ownership is
/// single-owner; transfer is one-shot.
extension Storage.Pool.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B4 — `Queue<Element>`

```swift
/// `Queue` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Queue` is `~Copyable` (conditionally Copyable with CoW). Ownership
/// transfer across threads is a move: the ring-buffer storage reference
/// travels with the queue, and the old thread loses access. When `Element:
/// Copyable`, CoW via `isKnownUniquelyReferenced` ensures mutations never
/// observe shared storage.
///
/// ## Intended Use
///
/// - Handoff of a producer-filled queue to a consumer thread.
/// - Sending into an `actor`'s initializer.
/// - Use as a one-shot transfer channel between threads when external
///   synchronization handles the "handoff complete" signal.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. The queue has no internal
/// locks. Ownership is single-owner; transfer is one-shot.
extension Queue: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B5 — `Queue.Fixed`

```swift
/// `Queue.Fixed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Queue.Fixed` wraps a `Buffer.Ring.Bounded` with CoW semantics. Ownership
/// transfer across threads is a move. When `Element: Copyable`, CoW ensures
/// mutations never observe shared storage.
///
/// ## Intended Use
///
/// - Handoff of a fixed-capacity queue between producer and consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B6 — `Queue.Static<let capacity: Int>`

```swift
/// `Queue.Static` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership of the inline ring buffer.
/// Transfer across threads is a move; the old thread cannot access the
/// queue after the move. All storage is inline in the struct.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized queue.
/// - Use in embedded / real-time contexts where heap allocation is
///   forbidden and predictable ownership transfer is required.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B7 — `Queue.Small<let inlineCapacity: Int>`

```swift
/// `Queue.Small` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The small-buffer optimization
/// (inline or spilled to heap) travels as one unit under ownership transfer.
/// The old thread cannot access the queue after the move.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized queue (inline fast
///   path, heap spill path, same handoff semantics).
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B8 — `Queue.DoubleEnded`

```swift
/// `Queue.DoubleEnded` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Ring-buffer-backed deque with CoW on `Element: Copyable`. Ownership
/// transfer across threads is a move; the old thread loses access. CoW
/// ensures mutations never observe shared storage.
///
/// ## Intended Use
///
/// - Handoff of a deque between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent push/pop. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.DoubleEnded: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B9 — `Queue.DoubleEnded.Fixed`

```swift
/// `Queue.DoubleEnded.Fixed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity ring-buffer deque with CoW on `Element: Copyable`.
/// Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Handoff of a fixed-capacity deque between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent push/pop. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.DoubleEnded.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B10 — `Queue.DoubleEnded.Static<let capacity: Int>`

```swift
/// `Queue.DoubleEnded.Static` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership of the inline ring-buffer deque.
/// Transfer across threads is a move.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized deque.
///
/// ## Non-Goals
///
/// Does NOT support concurrent push/pop. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.DoubleEnded.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B11 — `Queue.DoubleEnded.Small<let inlineCapacity: Int>`

```swift
/// `Queue.DoubleEnded.Small` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The small-buffer-optimized
/// ring-buffer deque (inline or spilled) travels as one unit.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized deque.
///
/// ## Non-Goals
///
/// Does NOT support concurrent push/pop. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.DoubleEnded.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B12 — `Queue.Linked`

```swift
/// `Queue.Linked` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Arena-based linked-list FIFO queue; `~Copyable` with CoW on
/// `Element: Copyable`. Ownership transfer across threads is a move; the
/// old thread loses access.
///
/// ## Intended Use
///
/// - Cross-thread handoff of a linked queue.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.Linked: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B13 — `Queue.Linked.Fixed`

```swift
/// `Queue.Linked.Fixed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity arena-based linked queue; `~Copyable` with CoW on
/// `Element: Copyable`. Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Cross-thread handoff of a fixed-capacity linked queue.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot.
extension Queue.Linked.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B14 — `Queue.Linked.Inline<let capacity: Int>`

```swift
/// `Queue.Linked.Inline` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. Inline linked-list storage
/// travels as one unit under ownership transfer.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized linked queue.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot. Requires `Element: Copyable` due to inline array
/// limitations.
extension Queue.Linked.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B15 — `Queue.Linked.Small<let inlineCapacity: Int>`

```swift
/// `Queue.Linked.Small` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. Small-buffer-optimized linked
/// queue storage (inline or spilled) travels as one unit.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized linked queue.
///
/// ## Non-Goals
///
/// Does NOT support concurrent enqueue/dequeue. Ownership is single-owner;
/// transfer is one-shot. Requires `Element: Copyable`.
extension Queue.Linked.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B16 — `Queue.Fixed.Iterator`

```swift
/// `Queue.Fixed.Iterator` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// The iterator wraps a `Buffer.Ring.Bounded.Iterator` whose internal state
/// holds raw pointers into CoW-backed storage. The iterator represents a
/// one-shot iteration token; sending it across threads transfers the
/// iteration state as a move-equivalent unit.
///
/// ## Intended Use
///
/// - Producing elements on one thread and consuming them on another where
///   the iterator is fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration — two threads must not advance the
/// same iterator. The underlying buffer must not be mutated while the
/// iterator is in use. Sendability is transfer, not sharing.
extension Queue.Fixed.Iterator: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B17 — `Queue.DoubleEnded.Iterator`

```swift
/// `Queue.DoubleEnded.Iterator` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Wraps a `Buffer.Ring.Iterator` holding raw pointers into CoW-backed
/// storage. Sending across threads transfers the iteration state as a
/// move-equivalent unit.
///
/// ## Intended Use
///
/// - Transferring iteration state between threads where the iterator is
///   fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated during iteration.
extension Queue.DoubleEnded.Iterator: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B18 — `Queue.DoubleEnded.Fixed.Iterator`

```swift
/// `Queue.DoubleEnded.Fixed.Iterator` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Wraps a `Buffer.Ring.Bounded.Iterator` holding raw pointers. Sending
/// across threads transfers the iteration state as a move-equivalent unit.
///
/// ## Intended Use
///
/// - Transferring iteration state between threads where the iterator is
///   fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated during iteration.
extension Queue.DoubleEnded.Fixed.Iterator: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B19 — `Stack<Element>`

```swift
/// `Stack` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Stack` is `~Copyable` (conditionally Copyable with CoW). Ownership
/// transfer across threads is a move: the `Buffer.Linear` storage reference
/// travels with the stack, and the old thread loses access.
///
/// ## Intended Use
///
/// - Cross-thread handoff of a stack.
/// - Sending into an `actor`'s initializer.
/// - CoW dispatch via `isKnownUniquelyReferenced` when `Element: Copyable`.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation — the stack has no internal locks.
/// All push/pop operations must be serialized by the owning thread.
/// Ownership is single-owner; transfer is one-shot.
extension Stack: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B20 — `Stack.Bounded`

```swift
/// `Stack.Bounded` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity stack with `Buffer.Linear.Bounded` + CoW on
/// `Element: Copyable`. Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Cross-thread handoff of a fixed-capacity stack.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Stack.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B21 — `Stack.Small<let inlineCapacity: Int>`

```swift
/// `Stack.Small` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. Small-buffer-optimized stack
/// (inline or spilled) travels as one unit under ownership transfer.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized stack.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Stack.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B22 — `Stack.Static<let capacity: Int>`

```swift
/// `Stack.Static` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership of inline stack storage.
/// Transfer across threads is a move; the old thread cannot access
/// the stack after the move.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized stack.
/// - Use in embedded / real-time contexts where heap allocation is
///   forbidden.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Stack.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B23 — `Stack.Bounded.Iterator`

```swift
/// `Stack.Bounded.Iterator` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Wraps a `Buffer.Linear.Bounded.Iterator` holding raw pointers into
/// CoW-backed storage. Sending across threads transfers the iteration
/// state as a move-equivalent unit.
///
/// ## Intended Use
///
/// - Transferring iteration state between threads where the iterator is
///   fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated during iteration.
extension Stack.Bounded.Iterator: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B24 — `Stack.Iterator`

```swift
/// `Stack.Iterator` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Wraps a `Buffer.Linear.Iterator` holding raw pointers into CoW-backed
/// storage. Sending across threads transfers the iteration state as a
/// move-equivalent unit.
///
/// ## Intended Use
///
/// - Transferring iteration state between threads where the iterator is
///   fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated during iteration.
extension Stack.Iterator: @unsafe @unchecked Sendable where Element: Sendable {}
```

---

## Low-Confidence Flags

The 8 outer `<let N: Int>` Inline/Static/Small variants (entries #5, #7, #9, #12, #13, #16, #17, #20, #21, #27, #28 — 11 total including the conflicts below) are flagged LOW_CONFIDENCE on the B-vs-D boundary because:

- They are genuinely `~Copyable` (primary B signal: ownership transfer).
- They also carry a `<let capacity: Int>` / `<let inlineCapacity: Int>` value-generic, which is one of the handoff's explicit D-watch patterns. The compiler cannot propagate Sendable through a value-generic + `@_rawLayout` storage chain without explicit `@unchecked` propagation, independently of ownership.
- Principal should decide whether to treat these as B (invariant is ownership transfer, value-generic is secondary) or as D (`@unchecked` exists solely to paper over structural inference, with ownership being incidental).

Note: I've listed these BOTH in the classifications table as **B** (primary call) AND in the Category D queue under Agent 2 — the dual flag is intentional.

The 3 `_Raw` inner types (entries #4, #6, #8) are listed ONLY as D candidates — those are unambiguously structural workarounds (the `_Raw` struct exists for no purpose other than hosting `@_rawLayout`).

## Preexisting Warnings Noted

None encountered while reading these Sources/ files. The repos compile clean under `.strictMemorySafety()` per the Phase 0 inventory in `unsafe-audit-findings.md`.
