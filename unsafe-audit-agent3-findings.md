<!--
version: 1.0.0
last_updated: 2026-04-15
status: PHASE_1_COMPLETE
agent: Agent 3 (Heap / List / Memory)
scope:
  - swift-primitives/swift-heap-primitives/Sources/
  - swift-primitives/swift-list-primitives/Sources/
  - swift-primitives/swift-memory-primitives/Sources/
companion: unsafe-audit-findings.md, unsafe-audit-category-d-queue.md
-->

# Agent 3 Findings — Heap / List / Memory

## Summary

Total `@unchecked Sendable` hits across scope: **23**

| Category | Count | Action |
|----------|:-----:|--------|
| A — Synchronized | 0 | — |
| B — Ownership transfer (`~Copyable`) | 19 | Apply `@unsafe` + full three-section docstring |
| C — Thread-confined | 0 | — |
| D — Structural Sendable workaround | 2 | Flagged to queue for principal adjudication |
| Low-confidence flags | 2 | Memory.Buffer / Memory.Buffer.Mutable (flagged as D candidates) |

**Per-repo counts** (Sources/ only):

| Repo | Hits | Files |
|------|:----:|:-----:|
| swift-heap-primitives | 10 | 5 |
| swift-list-primitives | 4 | 1 |
| swift-memory-primitives | 9 | 6 |
| **Total** | **23** | **12** |

**Preexisting warnings noted**: None encountered in scope during classification (audit is read-only; no `swift build` run).

**Category D candidates flagged to queue**: 2 — `Memory.Buffer`, `Memory.Buffer.Mutable`. Both are Copyable descriptor structs with stored `Tagged<Memory, Ordinal>` + `Tagged<Memory, Cardinal>` fields. `Tagged<Tag, RawValue>` has conditional Sendable (`where RawValue: Sendable`), but the struct still carries `@unchecked Sendable` — a likely structural-inference workaround. The stored fields are pure value bytes; no mutex, no `~Copyable` ownership invariant. Principal must decide D vs. B.

---

## Classifications

| # | File:Line | Type | Category | Reasoning | Draft reference |
|:-:|-----------|------|:--------:|-----------|-----------------|
| 1 | `swift-heap-primitives/Sources/Heap Primitives Core/Heap.swift:206` | `Heap` | B | `@safe struct ~Copyable`. Conditional Copyable when Element: Copyable. Sendable claim is ownership-transfer. | §Appendix A1 |
| 2 | `swift-heap-primitives/Sources/Heap Primitives Core/Heap.swift:207` | `Heap.Fixed` | B | `@safe struct ~Copyable`. Fixed-capacity heap, owns `Buffer<Element>.Linear.Bounded`. Ownership-transfer. | §Appendix A2 |
| 3 | `swift-heap-primitives/Sources/Heap Primitives Core/Heap.swift:208` | `Heap.MinMax` | B | `@safe struct ~Copyable`. Double-ended heap, owns `Buffer<Element>.Linear`. Ownership-transfer. | §Appendix A3 |
| 4 | `swift-heap-primitives/Sources/Heap Primitives Core/Heap.Static.swift:51` | `Heap.Static<let capacity: Int>` | B | Unconditionally `~Copyable`, inline storage. Ownership-transfer. | §Appendix A4 |
| 5 | `swift-heap-primitives/Sources/Heap Primitives Core/Heap.Small.swift:51` | `Heap.Small<let inlineCapacity: Int>` | B | Unconditionally `~Copyable`, inline + spill storage. Ownership-transfer. | §Appendix A5 |
| 6 | `swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax.swift:37` | `Heap.MinMax.Fixed` | B | `~Copyable`, nested variant. Ownership-transfer. | §Appendix A6 |
| 7 | `swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax.swift:38` | `Heap.MinMax.Static` | B | `~Copyable` with value-generic capacity. Ownership-transfer. | §Appendix A7 |
| 8 | `swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax.swift:39` | `Heap.MinMax.Small` | B | `~Copyable` with inline + spill. Ownership-transfer. | §Appendix A8 |
| 9 | `swift-heap-primitives/Sources/Heap Min Primitives/Heap.Min.swift:42` | `Heap.Min` | B | `~Copyable` stub type (not implemented). Declared `~Copyable` for API compatibility. Ownership-transfer when realized. | §Appendix A9 |
| 10 | `swift-heap-primitives/Sources/Heap Max Primitives/Heap.Max.swift:42` | `Heap.Max` | B | `~Copyable` stub type (not implemented). Declared `~Copyable` for API compatibility. Ownership-transfer when realized. | §Appendix A10 |
| 11 | `swift-list-primitives/Sources/List Primitives Core/List.Linked.swift:244` | `List.Linked<let N: Int>` | B | `@safe struct ~Copyable`. Conditional Copyable when Element: Copyable (COW). Owns arena-based linked buffer. Ownership-transfer. | §Appendix A11 |
| 12 | `swift-list-primitives/Sources/List Primitives Core/List.Linked.swift:245` | `List.Linked.Bounded` | B | `@safe struct ~Copyable`. Fixed-capacity linked list. Ownership-transfer. | §Appendix A12 |
| 13 | `swift-list-primitives/Sources/List Primitives Core/List.Linked.swift:246` | `List.Linked.Inline<let capacity: Int>` | B | Unconditionally `~Copyable` (contains `Storage.Inline` with `@_rawLayout`). Ownership-transfer. | §Appendix A13 |
| 14 | `swift-list-primitives/Sources/List Primitives Core/List.Linked.swift:247` | `List.Linked.Small<let inlineCapacity: Int>` | B | Unconditionally `~Copyable` (inline + spill). Ownership-transfer. | §Appendix A14 |
| 15 | `swift-memory-primitives/Sources/Memory Buffer Primitives/Memory.Buffer.swift:70` | `Memory.Buffer` | **D (flagged)** | **Copyable descriptor struct**, NOT `~Copyable`. Stored fields are `Tagged<Memory, Ordinal>` (address) + `Tagged<Memory, Cardinal>` (count). No mutex, no deinit, no ownership invariant. `@unchecked` appears to be a structural-Sendable workaround. LOW_CONFIDENCE — principal adjudicates D vs. B. | §Queue §D-1 |
| 16 | `swift-memory-primitives/Sources/Memory Buffer Primitives/Memory.Buffer.Mutable.swift:50` | `Memory.Buffer.Mutable` | **D (flagged)** | **Copyable descriptor struct**, NOT `~Copyable`. Same field shape as Memory.Buffer. Allocation lifetime is caller-managed via `deallocate()`; no `deinit`. LOW_CONFIDENCE — principal adjudicates D vs. B. | §Queue §D-2 |
| 17 | `swift-memory-primitives/Sources/Memory Arena Primitives/Memory.Arena.swift:125` | `Memory.Arena` | B | `@safe struct ~Copyable` with `deinit` that deallocates. Owns `UnsafeMutableRawPointer`. Textbook ownership-transfer. | §Appendix A15 |
| 18 | `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Inline ~Copyable.swift:73` | `Memory.Inline._Raw` | B | `@_rawLayout` `package struct ~Copyable`. Raw inline storage. `@_rawLayout` bypasses normal Sendable analysis — ownership-transfer via `~Copyable`. | §Appendix A16 |
| 19 | `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Inline ~Copyable.swift:77` | `Memory.Inline<Element, let capacity: Int>` | B | `public struct ~Copyable` containing `_Raw` (`@_rawLayout`). Explicit dependency on `_Raw`'s `@unchecked Sendable`. Ownership-transfer. | §Appendix A17 |
| 20 | `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Contiguous.swift:45` | `Memory.Contiguous<Element: BitwiseCopyable>` | B | `@frozen @safe struct ~Copyable` with `deinit` that deallocates. Owns `UnsafePointer<Element>`. Existing docstring notes "pointer is read-only after init" — this is an ownership-transfer argument, not synchronization. Ownership-transfer. | §Appendix A18 |
| 21 | `swift-memory-primitives/Sources/Memory Pool Primitives/Memory.Pool.swift:370` | `Memory.Pool` | B | `@safe struct ~Copyable` with `deinit` that deallocates. Owns `UnsafeMutableRawPointer` backing storage. Fixed-slot allocator. Ownership-transfer. | §Appendix A19 |

**Category D candidates** (counted separately, flagged to queue rather than classified):

| # | File:Line | Type | Queue ref |
|:-:|-----------|------|-----------|
| D-1 | `swift-memory-primitives/Sources/Memory Buffer Primitives/Memory.Buffer.swift:70` | `Memory.Buffer` | queue §Agent 3 / D-1 |
| D-2 | `swift-memory-primitives/Sources/Memory Buffer Primitives/Memory.Buffer.Mutable.swift:50` | `Memory.Buffer.Mutable` | queue §Agent 3 / D-2 |

Classification total: **21 B + 2 flagged-D = 23 hits** (zero A, zero C).

---

## Appendix — Full Docstrings and Annotations

### A1. `Heap` — `Heap.swift:206`

Existing extension form:
```swift
extension Heap: @unchecked Sendable where Element: Sendable {}
```

Draft replacement:
```swift
/// Sendable conformance for `Heap`.
///
/// ## Safety Invariant
///
/// `Heap` is `~Copyable` (move-only), so at most one owner exists at any point.
/// Sending across threads is sound because the compiler enforces that the
/// sender loses access after the move — there is no aliasing to race on.
/// The internal `Buffer<Element>.Linear` is owned exclusively by the heap
/// and moves with it.
///
/// ## Intended Use
///
/// - Transferring a prepared priority queue to a worker thread.
/// - Handing off a heap of `~Copyable` resources (e.g., file handles) to
///   another isolation domain for consumption.
/// - Actor-owned priority queue constructed outside the actor and passed
///   in at init.
///
/// ## Non-Goals
///
/// - This conformance does NOT grant concurrent access to a live heap.
/// - This conformance does NOT support multiple references across threads —
///   `~Copyable` forbids that by construction.
/// - This conformance does NOT synchronize push/pop; external synchronization
///   is required if any aliasing view is constructed.
extension Heap: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A2. `Heap.Fixed` — `Heap.swift:207`

```swift
/// Sendable conformance for `Heap.Fixed`.
///
/// ## Safety Invariant
///
/// `Heap.Fixed` is `~Copyable`. Single ownership is enforced by the type
/// system; the fixed-capacity `Buffer<Element>.Linear.Bounded` it owns
/// transfers with it across isolation boundaries.
///
/// ## Intended Use
///
/// - Transferring a pre-sized priority queue to a worker or actor.
/// - Embedded/real-time contexts where capacity is bounded and the heap is
///   constructed at startup then moved to its consumer.
/// - Handing a fixed-capacity heap of `~Copyable` elements across threads.
///
/// ## Non-Goals
///
/// - Not a shared, concurrent fixed-capacity queue — see `Queue.*` with
///   synchronized variants for that.
/// - Does not guarantee overflow safety under concurrent push; single-owner
///   mutation is required.
extension Heap.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A3. `Heap.MinMax` — `Heap.swift:208`

```swift
/// Sendable conformance for `Heap.MinMax`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax` is `~Copyable`; its backing `Buffer<Element>.Linear`
/// transfers under unique ownership. Cross-thread sends relinquish the
/// sender's access, preventing data races by construction.
///
/// ## Intended Use
///
/// - Handing off a double-ended priority queue to a scheduler that needs
///   both min and max access.
/// - Transferring a min-max heap of `~Copyable` resources for deadline-
///   ordered processing.
///
/// ## Non-Goals
///
/// - Does not support concurrent min-pop + max-pop from multiple threads.
/// - Not thread-safe for mutation; external synchronization required if
///   any alias must survive.
extension Heap.MinMax: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A4. `Heap.Static` — `Heap.Static.swift:51`

```swift
/// Sendable conformance for `Heap.Static`.
///
/// ## Safety Invariant
///
/// `Heap.Static` is unconditionally `~Copyable` (inline `@_rawLayout`
/// storage). Unique ownership ensures cross-thread transfer via move is
/// race-free; the inline element bytes travel with the struct.
///
/// ## Intended Use
///
/// - Stack-allocated priority queue moved from constructor to consumer
///   without heap allocation.
/// - Embedded contexts where the compile-time capacity matches a known
///   workload and the heap crosses one isolation boundary during setup.
///
/// - Handing a compile-time-sized heap of `~Copyable` elements to a worker
///   thread.
///
/// ## Non-Goals
///
/// - Not a shared buffer — inline storage is tied to one owner at a time.
/// - No synchronization; mutating access must remain single-threaded.
extension Heap.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A5. `Heap.Small` — `Heap.Small.swift:51`

```swift
/// Sendable conformance for `Heap.Small`.
///
/// ## Safety Invariant
///
/// `Heap.Small` is unconditionally `~Copyable` (inline storage with
/// automatic heap spill). Unique ownership ensures the move across
/// threads relinquishes the sender's access; both the inline bytes and
/// any spilled allocation transfer together.
///
/// ## Intended Use
///
/// - SmallVec-style priority queue handed from builder to consumer where
///   typical workloads fit inline but can spill.
/// - Transferring small-size-optimized heaps of `~Copyable` elements
///   without forcing heap allocation for common cases.
///
/// ## Non-Goals
///
/// - Not safe for concurrent mutation on either the inline or spilled
///   path; single-owner is the only supported model.
/// - Spill transitions are not atomic with respect to external observers.
extension Heap.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A6. `Heap.MinMax.Fixed` — `Heap.MinMax.swift:37`

```swift
/// Sendable conformance for `Heap.MinMax.Fixed`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax.Fixed` is `~Copyable`; nested type declared in an
/// extension, so conditional Copyable cannot propagate (see file
/// comment). The Sendable claim rests on the same unique-ownership
/// argument as other `~Copyable` heap variants — transfer via move
/// relinquishes the sender's access.
///
/// ## Intended Use
///
/// - Fixed-capacity double-ended priority queue built then transferred
///   to a consuming actor or thread.
/// - Embedded scheduler workloads with bounded capacity requirements.
///
/// ## Non-Goals
///
/// - Not a concurrent min-max queue; external synchronization required
///   if aliasing is needed.
/// - Capacity is fixed at init; moves preserve capacity but do not
///   synchronize capacity queries.
extension Heap.MinMax.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A7. `Heap.MinMax.Static` — `Heap.MinMax.swift:38`

```swift
/// Sendable conformance for `Heap.MinMax.Static`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax.Static` is `~Copyable` with compile-time capacity and
/// inline storage. Single ownership guarantees cross-thread transfer is
/// sound; no heap allocation is involved, so the entire structure moves
/// as contiguous bytes.
///
/// ## Intended Use
///
/// - Stack-allocated double-ended priority queues transferred across
///   isolation boundaries during setup.
/// - Zero-allocation min-max heaps moved between phases of a pipeline.
///
/// ## Non-Goals
///
/// - Not shareable; inline storage is bound to the current owner.
/// - No cross-thread mutation; single-owner is the sole supported model.
extension Heap.MinMax.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A8. `Heap.MinMax.Small` — `Heap.MinMax.swift:39`

```swift
/// Sendable conformance for `Heap.MinMax.Small`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax.Small` is `~Copyable` with inline-plus-spill storage.
/// Unique ownership ensures the sender relinquishes access on move; the
/// inline bytes and any spilled heap allocation transfer as one unit.
///
/// ## Intended Use
///
/// - Small-size-optimized double-ended priority queues moved between
///   isolation domains.
/// - Cases where the typical workload fits inline but occasional spill
///   is acceptable.
///
/// ## Non-Goals
///
/// - Not a concurrent min-max queue.
/// - Spill transitions are not synchronized against external observers;
///   the ownership-transfer model forbids those observers by construction.
extension Heap.MinMax.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A9. `Heap.Min` — `Heap.Min.swift:42`

Stub type — `init()` calls `fatalError`. Still `~Copyable`, so the Sendable conformance is prepared for future realization.

```swift
/// Sendable conformance for `Heap.Min` (stub; `Heap` is the realized form).
///
/// ## Safety Invariant
///
/// `Heap.Min` is `~Copyable`; unique ownership will be the safety model
/// once the type is implemented. The Sendable form matches `Heap`.
///
/// ## Intended Use
///
/// - Placeholder for a dedicated single-ended min-heap once implemented.
/// - Consumers should use `Heap` with `.ascending` ordering until then.
///
/// ## Non-Goals
///
/// - Not functional today; init traps.
/// - No synchronization; same constraints as `Heap` will apply.
extension Heap.Min: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A10. `Heap.Max` — `Heap.Max.swift:42`

Symmetric stub to `Heap.Min`.

```swift
/// Sendable conformance for `Heap.Max` (stub; `Heap` is the realized form).
///
/// ## Safety Invariant
///
/// `Heap.Max` is `~Copyable`; unique ownership will be the safety model
/// once the type is implemented. The Sendable form matches `Heap`.
///
/// ## Intended Use
///
/// - Placeholder for a dedicated single-ended max-heap once implemented.
/// - Consumers should use `Heap` with `.descending` ordering until then.
///
/// ## Non-Goals
///
/// - Not functional today; init traps.
/// - No synchronization; same constraints as `Heap` will apply.
extension Heap.Max: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A11. `List.Linked` — `List.Linked.swift:244`

```swift
/// Sendable conformance for `List.Linked`.
///
/// ## Safety Invariant
///
/// `List.Linked<N>` is `~Copyable` (conditionally `Copyable` when
/// `Element: Copyable` via COW). Under the `~Copyable` path the list is
/// a single owner; under COW the backing `Buffer<Element>.Linked<N>`
/// handles its own aliasing via reference-counted arena storage.
/// Sending across isolation boundaries is sound because either ownership
/// is unique (moved) or the COW backing preserves value semantics.
///
/// ## Intended Use
///
/// - Transferring a prepared linked list to a worker thread.
/// - Handing off a linked list of `~Copyable` resources (e.g., file
///   handles) across actors.
/// - Pipeline stages where each stage owns the list in turn.
///
/// ## Non-Goals
///
/// - Does not synchronize mutation — single-owner semantics are required
///   for the `~Copyable` path.
/// - Does not provide lock-free list operations.
/// - Not suitable as a shared concurrent queue.
extension List.Linked: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A12. `List.Linked.Bounded` — `List.Linked.swift:245`

```swift
/// Sendable conformance for `List.Linked.Bounded`.
///
/// ## Safety Invariant
///
/// `List.Linked.Bounded` is `~Copyable` (conditionally `Copyable` when
/// `Element: Copyable`). The fixed capacity is pre-allocated; transfer
/// across threads moves the full buffer under unique ownership.
///
/// ## Intended Use
///
/// - Transferring a bounded linked list to a consumer with predictable
///   memory behavior (embedded, real-time).
/// - Handing off bounded resource queues between phases of a pipeline.
///
/// ## Non-Goals
///
/// - Not a concurrent bounded queue; external synchronization or
///   synchronized variants are required for multi-writer scenarios.
/// - Capacity enforcement happens at push; moves do not reset state.
extension List.Linked.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A13. `List.Linked.Inline` — `List.Linked.swift:246`

```swift
/// Sendable conformance for `List.Linked.Inline`.
///
/// ## Safety Invariant
///
/// `List.Linked.Inline<capacity>` is unconditionally `~Copyable` (it
/// contains `Storage.Inline` which uses `@_rawLayout`). Unique ownership
/// ensures the inline bytes transfer intact across isolation boundaries.
///
/// ## Intended Use
///
/// - Zero-allocation linked list moved from builder to consumer.
/// - Embedded contexts where compile-time capacity is known and the list
///   crosses one isolation boundary during setup.
/// - Stack-allocated singly/doubly linked lists in short-lived contexts.
///
/// ## Non-Goals
///
/// - Not shareable; inline storage is tied to one owner at a time.
/// - No synchronization; single-owner is the only supported model.
/// - `@_rawLayout` bypasses normal Sendable analysis — ownership transfer
///   is the operative safety mechanism.
extension List.Linked.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A14. `List.Linked.Small` — `List.Linked.swift:247`

```swift
/// Sendable conformance for `List.Linked.Small`.
///
/// ## Safety Invariant
///
/// `List.Linked.Small<inlineCapacity>` is unconditionally `~Copyable`
/// (inline-plus-spill storage using `Storage.Inline`). Unique ownership
/// ensures the inline bytes and any spilled heap allocation transfer
/// together across isolation boundaries.
///
/// ## Intended Use
///
/// - Small-size-optimized linked lists handed from builder to consumer
///   where typical workloads fit inline but can spill to heap.
/// - Pipeline stages that avoid heap allocation for the common case.
///
/// ## Non-Goals
///
/// - Not safe for concurrent mutation on either the inline or spilled
///   path.
/// - Spill transitions are not synchronized against external observers;
///   the ownership-transfer model forbids such observers.
extension List.Linked.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A15. `Memory.Arena` — `Memory.Arena.swift:125`

```swift
/// Sendable conformance for `Memory.Arena`.
///
/// ## Safety Invariant
///
/// `Memory.Arena` is `@safe struct ~Copyable` owning an
/// `UnsafeMutableRawPointer` that `deinit` deallocates. Unique ownership
/// guarantees at most one thread accesses the bump pointer at any time;
/// cross-thread transfer via move relinquishes the sender's access, so
/// the deinit cannot race and the monotonic `_allocated` cursor cannot
/// be concurrently mutated.
///
/// ## Intended Use
///
/// - Handing a populated arena to a worker thread for batch processing
///   followed by bulk reset/drop.
/// - Per-stage arena ownership in a processing pipeline where each stage
///   receives, fills, and forwards the arena.
/// - Actor-owned bump allocators constructed outside the actor and moved
///   in at init.
///
/// ## Non-Goals
///
/// - Not a shared allocator — arena is single-owner by construction.
/// - Pointers returned by `allocate(count:alignment:)` are not themselves
///   Sendable; the caller must not share them across isolation domains
///   independently of the arena.
/// - `reset()` invalidates all prior allocations; this is unchanged by
///   sending but must remain the responsibility of the sole owner.
extension Memory.Arena: @unsafe @unchecked Sendable {}
```

### A16. `Memory.Inline._Raw` — `Memory.Inline ~Copyable.swift:73`

```swift
/// Sendable conformance for `Memory.Inline._Raw`.
///
/// ## Safety Invariant
///
/// `Memory.Inline._Raw` is a `@_rawLayout` `~Copyable` package struct.
/// `@_rawLayout` bypasses normal Sendable analysis — the type is a
/// compile-time layout directive, not a conventional struct. Unique
/// ownership (via `~Copyable`) guarantees the raw bytes transfer as one
/// block; there is no aliasing path that could race.
///
/// ## Intended Use
///
/// - Internal raw storage for `Memory.Inline<Element, capacity>`; not a
///   consumer-facing API.
/// - Composition into higher-level inline-storage types that need a
///   Sendable backing when their element type is Sendable.
///
/// ## Non-Goals
///
/// - Not intended for direct use outside `memory-primitives`; marked
///   `package` for this reason.
/// - Does not track element initialization — callers manage lifecycle
///   through pointers; Sendable does not alter that responsibility.
/// - `@_rawLayout` is an implementation-detail attribute; do not rely on
///   its Sendable semantics in downstream code.
extension Memory.Inline._Raw: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A17. `Memory.Inline` — `Memory.Inline ~Copyable.swift:77`

```swift
/// Sendable conformance for `Memory.Inline`.
///
/// ## Safety Invariant
///
/// `Memory.Inline<Element, capacity>` is `~Copyable` and holds its
/// storage inline via `_Raw` (`@_rawLayout`). The `@unchecked` rides on
/// `_Raw`'s `@unchecked Sendable`; the actual safety argument is unique
/// ownership. Transfer across isolation boundaries moves the inline
/// bytes without aliasing.
///
/// ## Intended Use
///
/// - Fixed-capacity typed inline memory moved between phases of a
///   pipeline (e.g., generating iterators, small buffers).
/// - Stack-allocated raw-memory regions handed to worker threads.
///
/// ## Non-Goals
///
/// - Does not track per-slot initialization; callers retain that
///   responsibility. Sendable does not change the initialization
///   contract.
/// - Not shareable — inline storage is bound to the current owner at a
///   time.
/// - Pointers returned by `pointer(at:)` are not Sendable; sharing them
///   independently of the `Memory.Inline` owner is unsafe.
extension Memory.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
```

### A18. `Memory.Contiguous` — `Memory.Contiguous.swift:45`

Existing form (declaration site):
```swift
public struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unchecked Sendable {
```

Existing docstring already contains a partial `## Thread Safety` section. Replace with:

```swift
/// Self-owning contiguous typed memory region.
/// ... (preserve existing summary / BitwiseCopyable / Ownership / Type/View sections) ...
///
/// ## Safety Invariant
///
/// `Memory.Contiguous` is `@frozen @safe struct ~Copyable` owning an
/// `UnsafePointer<Element>` that `deinit` deallocates. The pointer is
/// `internal let` (read-only after init) and the struct provides no
/// mutation API. Under unique ownership, the only reader at any time
/// is the current owner; cross-thread transfer via move relinquishes
/// the sender's access, so no concurrent read + deallocate race is
/// possible.
///
/// ## Intended Use
///
/// - Moving a loaded contiguous buffer (e.g., memory-mapped region,
///   decoded payload) to a worker or actor for read-only processing.
/// - Handing a `BitwiseCopyable` element region across isolation
///   boundaries where bulk deallocation is the cleanup model.
///
/// ## Non-Goals
///
/// - Not shareable — only one owner exists at a time.
/// - Does not expose mutation; consumers that need mutable access must
///   build on a different primitive.
/// - `unsafeBaseAddress` is a deliberate escape hatch; sharing the
///   returned pointer independently of the `Memory.Contiguous` owner is
///   unsafe and unsupported.
@frozen
@safe
public struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unsafe @unchecked Sendable {
```

**Note**: The existing `## Thread Safety` section in the docstring should be removed and replaced with the three canonical sections above to match the ecosystem template.

### A19. `Memory.Pool` — `Memory.Pool.swift:370`

```swift
/// Sendable conformance for `Memory.Pool`.
///
/// ## Safety Invariant
///
/// `Memory.Pool` is `@safe struct ~Copyable` owning an
/// `UnsafeMutableRawPointer` backing buffer and a `Bit.Vector` allocation
/// bitmap; `deinit` deallocates the backing buffer. Unique ownership
/// guarantees at most one thread mutates `_freeHead`, `_nextUnused`,
/// `_allocated`, and `_allocationBits`; cross-thread transfer via move
/// relinquishes the sender's access, eliminating double-free and
/// invariant-violation races.
///
/// ## Intended Use
///
/// - Handing a populated slot allocator to a worker thread for batch
///   allocation/deallocation followed by bulk reset or drop.
/// - Per-stage pool ownership in a processing pipeline where each stage
///   allocates, consumes, and deallocates slots.
/// - Actor-owned pools constructed outside the actor and moved in at
///   init.
///
/// ## Non-Goals
///
/// - Not a concurrent allocator — see `IO.Event.Buffer.Pool` (foundations
///   layer) for a synchronized pool that wraps `Memory.Pool` in `Mutex`.
/// - Pointers returned by `allocate()` are not Sendable; callers must
///   not share them across isolation domains independently of the pool.
/// - Slot indices carry phantom types (`Index<Memory.Pool.Slot>`) and
///   are process-local — do not serialize and restore across boundaries.
extension Memory.Pool: @unsafe @unchecked Sendable {}
```

---

## Low-Confidence Flags

Two sites classified below the 90% threshold, flagged to the Category D queue for principal adjudication:

### LC-1: `Memory.Buffer` — `Memory.Buffer.swift:70`

- **Declaration form**: `public struct Buffer: Hashable, @unchecked Sendable` — declaration-site on a `@safe` struct (NOT `~Copyable`).
- **Stored fields**: `_start: Memory.Address` (= `Tagged<Memory, Ordinal>`), `_count: Memory.Address.Count` (= `Tagged<Memory, Cardinal>`). Both `let`.
- **Why not A (synchronized)**: No mutex, atomic, lock, or condition variable anywhere in the type. No mutation API — struct is effectively immutable after init.
- **Why not B (ownership transfer)**: Type is not `~Copyable`. Consumers can freely copy `Memory.Buffer` values; the struct is a descriptor, not an owner. No `deinit`, no deallocation responsibility.
- **Why not C (thread-confined)**: No "one transfer to a specific thread" protocol — the struct is a shared value descriptor meant to be passed around.
- **Why candidate for D**: `Tagged<Tag, RawValue>` has conditional Sendable (`extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}`). Both stored fields use Tagged with RawValue types (`Ordinal`, `Cardinal`) that should be Sendable by structural inference. The `@unchecked Sendable` appears to be a **structural-Sendable workaround** — defensive annotation where the author wasn't sure phantom-type inference would work through Tagged + sentinel-pointer construction. The sentinel values (`_emptyBufferSentinelMutable`) are `nonisolated(unsafe) let`, which likely triggers a conservative Sendable inference decision somewhere in the chain.
- **Alternate read**: If the principal reads "Memory.Buffer wraps a raw pointer address; pointer dereferencing is inherently unsafe across threads" as a caller-visible invariant, the site becomes Tier 2 (debatable) per `unsafe-audit-findings.md` §Tier 2 — sibling to `Kernel.Memory.Map.Region`. That would defer `@unsafe` application. Principal must decide.
- **Confidence**: ~60%. LOW_CONFIDENCE. Principal adjudicates.

### LC-2: `Memory.Buffer.Mutable` — `Memory.Buffer.Mutable.swift:50`

- **Declaration form**: `public struct Mutable: Hashable, @unchecked Sendable` — declaration-site on a `@safe` struct (NOT `~Copyable`).
- **Stored fields**: `_start: Memory.Address`, `_count: Memory.Address.Count`. Both `let`.
- **Why not A / B / C**: Same structural analysis as LC-1 applies. Not `~Copyable`; not synchronized; not thread-confined.
- **Why candidate for D**: Same structural-Sendable-workaround pattern as LC-1. Additional wrinkle: `Mutable` has `deallocate()` but it is caller-invoked and explicit (not a `deinit`); the type does NOT own its allocation — it describes a buffer that the caller separately allocated and separately deallocates. This strengthens the "descriptor, not owner" reading.
- **Alternate read**: Mutation via `store(_:at:as:)` and `copy(from:)` makes this closer to a shared mutable descriptor. If two threads both hold the same `Memory.Buffer.Mutable` value and both call `copy(from:)`, races on the underlying bytes are possible. However, the type itself has no mutable state — the race is in the memory it describes, not in the struct. That race is the caller's responsibility regardless of Sendable.
- **Confidence**: ~55%. LOW_CONFIDENCE. Principal adjudicates. Recommend D (structural workaround) because the Sendable claim is about the struct's own bytes (which are value bytes), not about the memory it addresses.

---

## Preexisting Warnings Noted

None encountered during read-only classification. No `swift build` was run per audit protocol (classification-only task, no Sources/ edits).

---

## References

- Canonical: `unsafe-audit-findings.md` — classification framework, Category D definition
- Canonical: `ownership-transfer-conventions.md` — Tier 1/2/3 patterns, `~Copyable + Sendable` semantics
- Skill: `[MEM-SAFE-024]` `@unchecked Sendable` Semantic Categories
- Pilot reference: `swift-foundations/swift-threads/Sources/Thread Synchronization/Kernel.Thread.Synchronization.swift` (commit `da86a35`)
- Queue: `unsafe-audit-category-d-queue.md` — Agent 3 section appended with D-1, D-2
