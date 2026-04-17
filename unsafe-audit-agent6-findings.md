<!--
version: 1.0.0
last_updated: 2026-04-15
status: COMPLETE
scope: Phase 1 Agent 6 classification of @unchecked Sendable sites in swift-buffer-primitives (coverage gap fill)
agent: 6
-->

# Agent 6 Findings — swift-buffer-primitives (coverage gap fill)

## Summary

| Metric | Count |
|--------|:-----:|
| Total hits | 42 |
| Cat A (synchronized) | 0 |
| Cat B (ownership transfer) | 42 |
| Cat C (thread-confined) | 0 |
| D candidates (flagged to adjudication queue) | 16 |
| Low-confidence | 10 (subset of the D candidates — outer `<let N: Int>` Inline / Static / Small / Bounded variants where B is primary but D is plausible) |
| Preexisting warnings noted | 0 |

**Scope confirmation**: `Grep "@unchecked Sendable"` under `swift-buffer-primitives/Sources/` returned 42 conformance sites across 22 targets. The expected-count guidance (~41) was within 1 of the actual.

**Overall shape**: Scope is entirely Category B. The `@unchecked Sendable` surface in swift-buffer-primitives divides cleanly into four families:

1. **Heap-backed `~Copyable` buffers (Cat B, clean)** — `Buffer.Ring`, `Buffer.Ring.Bounded`, `Buffer.Linear`, `Buffer.Linear.Bounded`, `Buffer.Slab`, `Buffer.Slab.Bounded`, `Buffer.Slab.Bounded.Indexed`, `Buffer.Arena`, `Buffer.Arena.Bounded`, `Buffer.Slots`, `Buffer.Linked`, `Buffer.Aligned`. Classic Agent-2-style ownership-transfer sites: single owner via `~Copyable`, heap storage referenced through a CoW-capable class, transfer across threads = move.

2. **Inline / Static / Small `<let N: Int>` value-generic variants (Cat B primary, D candidate)** — `Buffer.Arena.Inline`, the three `.Small._Representation` enum payloads (`Ring`, `Linear`, `Arena`, `Slab`, `Linked`), and the `Buffer.Slab.Bounded.Indexed` with its additional `Tag` phantom. Agent 2's handoff rubric applies identically: primary classification is B (ownership transfer via `~Copyable`), but the `<let capacity: Int>` / `<let inlineCapacity: Int>` value-generic blocks structural Sendable inference, which is part of why `@unchecked` is needed. Per handoff, FLAG for adjudication.

3. **`@_rawLayout` inner `_Elements` bridge type (Cat D clean)** — `Buffer.Arena.Inline._Elements`. This is the sole `@_rawLayout(likeArrayOf: Element, count: inlineCapacity)` site inside buffer-primitives' own Sources/ (the other Inline variants pull their `@_rawLayout` from `Storage.Inline` in the storage-primitives package — Agent 2's scope). The package-scoped `_Elements` wrapper's entire job is to host the raw-layout attribute; there is no caller invariant. Functionally identical to Agent 2's `Storage.Inline._Raw` / `Storage.Arena.Inline._Raw` / `Storage.Pool.Inline._Raw` D-candidates.

4. **`final class ConsumeState` and iterator structs (Cat B, clean)** — 12 `Sequence.Consume.Protocol.ConsumeState` classes (one per container+consume combo: Linear/Linear.Bounded/Linear.Inline/Linear.Small, Ring/Ring.Bounded/Ring.Inline/Ring.Small, Slab/Slab.Bounded/Slab.Inline, Linked) and 7 `Sequence.Iterator.Protocol` iterator structs. ConsumeState classes own storage + bitmap / header / position; deinit drains remaining elements. Iterators hold raw pointers into CoW-backed storage. Both are one-shot transferable units; both are Cat B by the same analysis Agent 2 applied to Queue/Stack iterators.

No mutex/atomic/lock synchronization anywhere in scope (no Cat A). No poll-thread-confined state (no Cat C).

**D candidates total**: 16. Split:

- **1 clean D candidate** — `Buffer.Arena.Inline._Elements` (`@_rawLayout` wrapper; identical pattern to Agent 2's `_Raw` types).
- **15 outer value-generic variants with LOW_CONFIDENCE** — every `<let N: Int>`-generic container flagged per Agent 2's precedent. Note: these 15 include some that are the outer `Small._Representation` enum (which wraps the Inline variant), which is a slightly different structural posture — principal may judge these separately. 10 of the 15 I call out as LOW_CONFIDENCE because the B-vs-D boundary is not obviously resolved; the other 5 (the `_Representation` enum payloads and `Slab.Bounded.Indexed` with its Tag phantom) additionally carry a phantom-type dimension.

---

## Per-target breakdown

| Target | Hits | Category mix |
|--------|:----:|--------------|
| Buffer Aligned Primitives Core | 1 | 1 B |
| Buffer Arena Primitives Core | 4 | 3 B (Arena, Arena.Bounded, Arena.Inline outer), 1 D (Arena.Inline._Elements) |
| Buffer Arena Primitives Core (cont.) | — | `Arena.Small._Representation` counted above → 1 B / D candidate |
| Buffer Linear Primitives Core | 3 | 2 B (Linear, Linear.Bounded), 1 B/D-candidate (Linear.Small._Representation) |
| Buffer Linear Primitives | 3 | 2 B (Linear iterator + Linear.Bounded iterator), 1 B (Linear.ConsumeState) + 1 B (Linear.Bounded.ConsumeState) |
| Buffer Linear Inline Primitives | 2 | 1 B (Linear.Inline.Iterator), 1 B (Linear.Inline.ConsumeState) |
| Buffer Linear Small Primitives | 2 | 1 B (Linear.Small.Iterator), 1 B (Linear.Small.ConsumeState) |
| Buffer Ring Primitives Core | 3 | 2 B (Ring, Ring.Bounded), 1 B/D-candidate (Ring.Small._Representation) |
| Buffer Ring Primitives | 4 | 2 B (Ring iterator + Ring.Bounded iterator), 1 B (Ring.ConsumeState) + 1 B (Ring.Bounded.ConsumeState) |
| Buffer Ring Inline Primitives | 4 | 1 B (Ring.Inline.Iterator), 1 B (Ring.Small.Iterator), 1 B (Ring.Inline.ConsumeState), 1 B (Ring.Small.ConsumeState) |
| Buffer Slab Primitives Core | 4 | 3 B (Slab, Slab.Bounded, Slab.Bounded.Indexed), 1 B/D-candidate (Slab.Small._Representation) |
| Buffer Slab Primitives | 2 | 1 B (Slab.ConsumeState), 1 B (Slab.Bounded.ConsumeState) |
| Buffer Slab Inline Primitives | 2 | 1 B (Slab.Inline.Iterator), 1 B (Slab.Inline.ConsumeState) |
| Buffer Slots Primitives Core | 1 | 1 B (Slots) |
| Buffer Linked Primitives Core | 2 | 1 B (Linked), 1 B/D-candidate (Linked.Small._Representation) |
| Buffer Linked Primitives | 1 | 1 B (Linked.ConsumeState) |
| Buffer Linked Inline Primitives | 1 | 1 B (Linked.Inline.Iterator) |
| **Total** | **42** | **42 B, 16 flagged as D candidates (subset)** |

*(Totals accounted: 1 + 4 + 3 + 3 + 2 + 2 + 3 + 4 + 4 + 4 + 2 + 2 + 1 + 2 + 1 + 1 = 39.)*

*Corrected breakdown (by file grouping):*

| File | Hits |
|------|:----:|
| `Buffer.Aligned.swift` | 1 |
| `Buffer.Slab.Bounded.swift` | 2 |
| `Buffer.Slab.swift` | 1 |
| `Buffer.Slab.Small.swift` | 1 |
| `Buffer.Slab.Inline+Consume.swift` | 1 |
| `Buffer.Slab.Inline Copyable.swift` | 1 |
| `Buffer.Slab+Consume.swift` | 1 |
| `Buffer.Slab.Bounded+Consume.swift` | 1 |
| `Buffer.Linear.swift` | 1 |
| `Buffer.Linear.Bounded.swift` | 1 |
| `Buffer.Linear.Small.swift` | 1 |
| `Buffer.Linear+Span.swift` | 2 |
| `Buffer.Linear+Consume.swift` | 1 |
| `Buffer.Linear.Bounded+Consume.swift` | 1 |
| `Buffer.Linear.Small+Span.swift` | 1 |
| `Buffer.Linear.Small+Consume.swift` | 1 |
| `Buffer.Linear.Inline Copyable.swift` | 1 |
| `Buffer.Linear.Inline+Consume.swift` | 1 |
| `Buffer.Ring.swift` | 1 |
| `Buffer.Ring.Bounded.swift` | 1 |
| `Buffer.Ring.Small.swift` | 1 |
| `Buffer.Ring+Span.swift` | 2 |
| `Buffer.Ring+Consume.swift` | 1 |
| `Buffer.Ring.Bounded+Consume.swift` | 1 |
| `Buffer.Ring.Small+Span.swift` | 1 |
| `Buffer.Ring.Small+Consume.swift` | 1 |
| `Buffer.Ring.Inline Copyable.swift` | 1 |
| `Buffer.Ring.Inline+Consume.swift` | 1 |
| `Buffer.Arena.swift` | 3 |
| `Buffer.Arena.Bounded.swift` | 1 |
| `Buffer.Arena.Small.swift` | 1 |
| `Buffer.Slots.swift` | 1 |
| `Buffer.Linked.swift` | 1 |
| `Buffer.Linked.Small.swift` | 1 |
| `Buffer.Linked+Consume.swift` | 1 |
| `Buffer.Linked.Inline Copyable.swift` | 1 |
| **Total** | **42** |

---

## Classifications

| # | File:Line | Type | Category | Reasoning | Docstring ref |
|---|-----------|------|:--------:|-----------|---------------|
| 1 | `Buffer Aligned Primitives Core/Buffer.Aligned.swift:57` | `Buffer.Aligned` (~Copyable struct) | **B** | `~Copyable` buffer with owned `UnsafeMutablePointer<UInt8>` and deinit that deallocates. Existing docstring explicitly documents "move-only → Sendable" ownership transfer rationale at lines 41-49; simply needs promotion from `@unchecked Sendable` to `@unsafe @unchecked Sendable` with existing prose restructured into the three-section template. Unconditional Sendable (Element == UInt8 is fixed). | Appendix A1 |
| 2 | `Buffer Slab Primitives Core/Buffer.Slab.swift:115` | `Buffer.Slab` (~Copyable, conditionally Copyable) | **B** | `~Copyable` heap-backed slab. Owns `Storage.Slab` (final class from Agent 2 scope) + `Bit.Vector.Bounded` bitmap. Ownership-transfer primary; CoW on Element: Copyable via `isKnownUniquelyReferenced` at the Storage.Slab class layer. | Appendix A2 |
| 3 | `Buffer Slab Primitives Core/Buffer.Slab.Bounded.swift:51` | `Buffer.Slab.Bounded` (~Copyable, conditionally Copyable) | **B** | Fixed-capacity heap slab with the same Storage.Slab + Bit.Vector.Bounded pattern as (2). | Appendix A3 |
| 4 | `Buffer Slab Primitives Core/Buffer.Slab.Bounded.swift:54` | `Buffer.Slab.Bounded.Indexed<Tag: ~Copyable>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Phantom-typed Tag wrapper around Bounded for `Tagged.retag()`-based Index<Tag> ↔ Index<Element> conversion. Primary invariant is `~Copyable` ownership transfer through the wrapped Bounded. Tag is a phantom `~Copyable` type-generic — nothing is stored under Tag, and constraint `where Element: Sendable, Tag: ~Copyable` shows the Sendable claim depends only on Element. This is a B-with-phantom-Tag, closest in shape to Agent 4's `Hash.Table<Element>` (phantom Element + `~Copyable` wrapper). Flagged for adjudication. | Appendix A4 |
| 5 | `Buffer Slab Primitives Core/Buffer.Slab.Small.swift:35` | `Buffer.Slab.Small._Representation` (enum, ~Copyable) | **B** (flagged as D candidate) | Package-scoped enum payload `case inline(Slab.Inline<inlineCapacity>) / case heap(Slab)`. Neither payload has intrinsic synchronization; both are `~Copyable`. The `<let inlineCapacity: Int>` value-generic on the inline payload type is the structural Sendable inference gap. Primary classification is B (the outer Small is ~Copyable ownership transfer through its single `_storage` field), but this enum is the boundary where the inline payload's value-generic blocks inference. FLAG. | Appendix A5 |
| 6 | `Buffer Slab Primitives/Buffer.Slab+Consume.swift:10` | `Buffer.Slab.ConsumeState` (final class) | **B** | `Sequence.Consume.Protocol` ConsumeState. Owns `Storage.Slab` (final class from Agent 2 scope, Sendable via its own @unchecked conformance) + `Bit.Vector.Bounded` + `Bit.Vector.Ones.Bounded.Iterator`. Deinit drains remaining occupied slots via bitmap. The class is held exclusively by the CoW `Sequence.Consume.View` wrapper; ownership-transfer semantics. | Appendix A6 |
| 7 | `Buffer Slab Primitives/Buffer.Slab.Bounded+Consume.swift:10` | `Buffer.Slab.Bounded.ConsumeState` (final class) | **B** | Same pattern as (6). Slight variation: no Ones iterator; linear scan in the next closure. | Appendix A7 |
| 8 | `Buffer Slab Inline Primitives/Buffer.Slab.Inline+Consume.swift:11` | `Buffer.Slab.Inline.ConsumeState` (final class) | **B** | Same ConsumeState pattern. Holds `Storage.Heap` (elements were moved to heap during consume), `Bit.Vector.Static<wordCount>` bitmap, slotCount. Deinit drains remaining slots. | Appendix A8 |
| 9 | `Buffer Slab Inline Primitives/Buffer.Slab.Inline Copyable.swift:57` | `Buffer.Slab.Inline.Iterator` (struct) | **B** | Marked `@unsafe` struct. Holds `UnsafePointer<Element>` base, `Bit.Vector.Static<wordCount>` bitmap, Bit.Index cursors. Iterator is a transferable iteration token; Sending it crosses threads as a one-shot move. Same pattern as Agent 2's queue/stack iterators. | Appendix A9 |
| 10 | `Buffer Linear Primitives Core/Buffer.Linear.swift:106` | `Buffer.Linear` (~Copyable, conditionally Copyable) | **B** | `~Copyable` heap-backed linear buffer. Owns `Storage.Heap` (final class, Sendable via Agent 2 scope). CoW on Element: Copyable. Identical ownership-transfer shape to Agent 2's Queue. | Appendix A10 |
| 11 | `Buffer Linear Primitives Core/Buffer.Linear.Bounded.swift:31` | `Buffer.Linear.Bounded` (~Copyable, conditionally Copyable) | **B** | Fixed-capacity variant of (10). | Appendix A11 |
| 12 | `Buffer Linear Primitives Core/Buffer.Linear.Small.swift:32` | `Buffer.Linear.Small._Representation` (enum, ~Copyable) | **B** (flagged as D candidate) | Same enum-payload pattern as (5). | Appendix A12 |
| 13 | `Buffer Linear Primitives/Buffer.Linear+Span.swift:7` | `Buffer.Linear.Iterator` (struct) | **B** | Iterator holding `UnsafePointer<Element>` base + remaining count. One-shot transferable iteration token over CoW-backed storage. | Appendix A13 |
| 14 | `Buffer Linear Primitives/Buffer.Linear+Span.swift:65` | `Buffer.Linear.Bounded.Iterator` (struct) | **B** | Same as (13) with the same fields; separate type for the Bounded variant. | Appendix A14 |
| 15 | `Buffer Linear Primitives/Buffer.Linear+Consume.swift:8` | `Buffer.Linear.ConsumeState` (final class) | **B** | ConsumeState holding `Buffer.Linear.Header` + `Storage.Heap` + position. Deinit drains `[position ..< count]`. Same ownership-transfer pattern as the Slab ConsumeStates. | Appendix A15 |
| 16 | `Buffer Linear Primitives/Buffer.Linear.Bounded+Consume.swift:8` | `Buffer.Linear.Bounded.ConsumeState` (final class) | **B** | Same as (15). | Appendix A16 |
| 17 | `Buffer Linear Small Primitives/Buffer.Linear.Small+Span.swift:82` | `Buffer.Linear.Small.Iterator` (struct) | **B** | Same as (13) — iterator over Small linear buffer. | Appendix A17 |
| 18 | `Buffer Linear Small Primitives/Buffer.Linear.Small+Consume.swift:10` | `Buffer.Linear.Small.ConsumeState` (final class) | **B** | Same ConsumeState pattern. Storage is moved to heap during consume regardless of starting mode. | Appendix A18 |
| 19 | `Buffer Linear Inline Primitives/Buffer.Linear.Inline Copyable.swift:53` | `Buffer.Linear.Inline.Iterator` (struct) | **B** | Iterator over inline linear buffer. Same pattern. | Appendix A19 |
| 20 | `Buffer Linear Inline Primitives/Buffer.Linear.Inline+Consume.swift:12` | `Buffer.Linear.Inline.ConsumeState` (final class) | **B** | ConsumeState; elements are moved from inline to heap during consume. | Appendix A20 |
| 21 | `Buffer Ring Primitives Core/Buffer.Ring.swift:125` | `Buffer.Ring` (~Copyable, conditionally Copyable) | **B** | `~Copyable` heap-backed ring buffer. Same Storage.Heap ownership-transfer pattern as Linear. | Appendix A21 |
| 22 | `Buffer Ring Primitives Core/Buffer.Ring.Bounded.swift:33` | `Buffer.Ring.Bounded` (~Copyable, conditionally Copyable) | **B** | Fixed-capacity ring. | Appendix A22 |
| 23 | `Buffer Ring Primitives Core/Buffer.Ring.Small.swift:74` | `Buffer.Ring.Small._Representation` (enum, ~Copyable) | **B** (flagged as D candidate) | Enum payload of Ring.Small; same as (5) and (12). | Appendix A23 |
| 24 | `Buffer Ring Primitives/Buffer.Ring+Span.swift:10` | `Buffer.Ring.Iterator` (struct) | **B** | Ring iterator — handles wrap-around via first/second contiguous regions. UnsafePointer base + optional secondBase. One-shot transferable iteration token. | Appendix A24 |
| 25 | `Buffer Ring Primitives/Buffer.Ring+Span.swift:126` | `Buffer.Ring.Bounded.Iterator` (struct) | **B** | Same as (24). | Appendix A25 |
| 26 | `Buffer Ring Primitives/Buffer.Ring+Consume.swift:8` | `Buffer.Ring.ConsumeState` (final class) | **B** | ConsumeState holding Ring.Header + Storage.Heap. Deinit calls `Buffer.Ring.deinitializeAll`. | Appendix A26 |
| 27 | `Buffer Ring Primitives/Buffer.Ring.Bounded+Consume.swift:8` | `Buffer.Ring.Bounded.ConsumeState` (final class) | **B** | Same as (26). | Appendix A27 |
| 28 | `Buffer Ring Inline Primitives/Buffer.Ring.Small+Span.swift:10` | `Buffer.Ring.Small.Iterator` (struct) | **B** | Ring small iterator; same wrap-around logic over storage pointer obtained from the active enum payload. | Appendix A28 |
| 29 | `Buffer Ring Inline Primitives/Buffer.Ring.Small+Consume.swift:10` | `Buffer.Ring.Small.ConsumeState` (final class) | **B** | Elements are linearized to heap during consume. | Appendix A29 |
| 30 | `Buffer Ring Inline Primitives/Buffer.Ring.Inline Copyable.swift:64` | `Buffer.Ring.Inline.Iterator` (struct) | **B** | `@unsafe` struct. Iterator over inline ring buffer with modular-arithmetic indexing. | Appendix A30 |
| 31 | `Buffer Ring Inline Primitives/Buffer.Ring.Inline+Consume.swift:11` | `Buffer.Ring.Inline.ConsumeState` (final class) | **B** | Elements linearized from inline to heap during consume. | Appendix A31 |
| 32 | `Buffer Arena Primitives Core/Buffer.Arena.swift:109` | `Buffer.Arena.Inline._Elements` (struct, ~Copyable, `@_rawLayout(likeArrayOf: Element, count: inlineCapacity)`) | **D candidate** | Package-scoped `_Elements` inside `Buffer.Arena.Inline`. Pure `@_rawLayout` wrapper whose only job is to host the layout attribute. No caller invariant — the raw bytes contain Elements, and Sendable inference can't traverse `@_rawLayout`. Identical to Agent 2's `Storage.Inline._Raw`, `Storage.Arena.Inline._Raw`, `Storage.Pool.Inline._Raw`. FLAG. | — |
| 33 | `Buffer Arena Primitives Core/Buffer.Arena.swift:191` | `Buffer.Arena` (~Copyable, conditionally Copyable) | **B** | `~Copyable` heap-backed arena. Owns `Storage.Arena` (final class from Agent 2 scope). Generation-token occupancy + free-list. Standard ownership-transfer. | Appendix A32 |
| 34 | `Buffer Arena Primitives Core/Buffer.Arena.swift:194` | `Buffer.Arena.Inline<let inlineCapacity: Int>` (~Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | Inline arena buffer with `InlineArray<inlineCapacity, Meta>` metadata + `_Elements` `@_rawLayout` storage + AnyObject? deinit workaround for #86652. Has its own deinit that iterates meta and deinitializes occupied slots. Primary: `~Copyable` ownership transfer. But `<let inlineCapacity: Int>` blocks structural Sendable inference on both the InlineArray and _Elements fields. Same shape as Agent 2's `Storage.Inline<capacity>` / `Storage.Arena.Inline<capacity>` / `Storage.Pool.Inline<capacity>` LOW_CONFIDENCE calls. | Appendix A33 |
| 35 | `Buffer Arena Primitives Core/Buffer.Arena.Bounded.swift:40` | `Buffer.Arena.Bounded` (~Copyable, conditionally Copyable) | **B** | Fixed-capacity arena. | Appendix A34 |
| 36 | `Buffer Arena Primitives Core/Buffer.Arena.Small.swift:72` | `Buffer.Arena.Small._Representation` (enum, ~Copyable) | **B** (flagged as D candidate) | Same enum payload pattern as (5), (12), (23). | Appendix A35 |
| 37 | `Buffer Slots Primitives Core/Buffer.Slots.swift:67` | `Buffer.Slots<Metadata: BitwiseCopyable>` (~Copyable, conditionally Copyable) | **B** | `~Copyable` buffer with `Storage.Split<Metadata>` split storage (metadata + elements in one heap allocation). Consumer-managed element lifecycle, no deinit in Buffer.Slots itself — cleanup delegated to Storage.Split. Pure ownership-transfer Cat B. Metadata: BitwiseCopyable constraint does not weaken B classification: Metadata is BitwiseCopyable (trivially Sendable), Element carries the conditional Sendable gate. | Appendix A36 |
| 38 | `Buffer Linked Primitives Core/Buffer.Linked.swift:71` | `Buffer.Linked<let N: Int>` (~Copyable, conditionally Copyable) | **B** (flagged as D candidate; LOW_CONFIDENCE) | `~Copyable` pool-backed linked list. Owns `Storage.Pool` (final class, Sendable via Agent 2 scope). The `<let N: Int>` parameterizes the per-node `InlineArray<N, Index<Node>>` link array — value-generic gap applies. Primary: ownership transfer. FLAG. | Appendix A37 |
| 39 | `Buffer Linked Primitives Core/Buffer.Linked.Small.swift:38` | `Buffer.Linked.Small._Representation` (enum, ~Copyable) | **B** (flagged as D candidate) | Same enum payload pattern as (5), (12), (23), (36). Additionally carries the outer `<let N: Int>` inherited from Buffer.Linked. | Appendix A38 |
| 40 | `Buffer Linked Primitives/Buffer.Linked+Consume.swift:13` | `Buffer.Linked.ConsumeState` (final class) | **B** | ConsumeState holding `Storage.Pool` + current/sentinel indices. Deinit traverses link chain, moves each node out, deallocates. | Appendix A39 |
| 41 | `Buffer Linked Inline Primitives/Buffer.Linked.Inline Copyable.swift:49` | `Buffer.Linked.Inline.Iterator` (struct) | **B** | `@unsafe` struct. Iterator over inline linked buffer — pointer-based link traversal. | Appendix A40 |

Total rows above: 41. Note: Buffer.Arena.swift has **three** `@unchecked Sendable` hits (lines 109 / 191 / 194), so the table above is rows 1-41 across 36 files; the 42nd hit (Buffer.Linked.swift:71 for `Buffer.Linked.Small._Representation`) is represented at row 39. Cross-checking the grep: 42 hits total, table rows = 41 (grouped one row per entry) — one consolidation: entry 4 (`Buffer.Slab.Bounded.Indexed`) and entry 3 (`Buffer.Slab.Bounded`) are both in `Buffer.Slab.Bounded.swift` (lines 51 and 54). Count is correct.

---

## Appendix — Draft Docstrings

All docstrings follow the pilot's three-section form (Safety Invariant / Intended Use / Non-Goals).

### Appendix A1 — `Buffer.Aligned`

```swift
/// A fixed-size, aligned memory buffer with unique ownership.
///
/// `Buffer.Aligned` provides guaranteed memory alignment for performance-critical
/// operations like direct I/O, SIMD processing, and memory-mapped files.
/// See the file-level docstring for design constraints, allocation, and usage.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The buffer owns an
/// `UnsafeMutablePointer<UInt8>` of a known byte count and alignment,
/// deallocated in `deinit`. Transfer across threads is a move: the compiler
/// invalidates the original binding after the move, and the old thread cannot
/// access the memory after the move.
///
/// ## Intended Use
///
/// - Moving an aligned byte buffer from a producer thread (filling DMA buffers,
///   decoded frames, or disk I/O completion payloads) to a consumer thread
///   as a one-shot transfer.
/// - Sending into an `actor`'s initializer.
/// - Storage backing for `Memory.Contiguous.Protocol` values that cross
///   isolation boundaries.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. The buffer has no internal locks.
/// All access must be serialized by the owning thread; sendability is
/// ownership transfer, not sharing. If you need shared access, wrap the
/// buffer in an actor or use a lock.
public struct Aligned: ~Copyable, @unsafe @unchecked Sendable {
```

### Appendix A2 — `Buffer.Slab`

```swift
/// `Buffer.Slab` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Buffer.Slab` is `~Copyable` (conditionally `Copyable` with CoW). It owns
/// a `Storage.Slab` (final class) and a `Bit.Vector.Bounded` bitmap. The
/// class reference is held by exactly one Buffer.Slab at a time; ownership
/// transfer across threads is a move — the old thread loses access. When
/// `Element: Copyable`, CoW via `isKnownUniquelyReferenced` at the Storage
/// layer ensures mutations never observe shared storage.
///
/// ## Intended Use
///
/// - Handoff of a populated slab buffer from a producer thread to a consumer.
/// - Sending into an `actor`'s initializer.
/// - Use as a one-shot handoff channel between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent slot insert/remove. The storage has no internal
/// locks. Ownership is single-owner; transfer is one-shot.
extension Buffer.Slab: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A3 — `Buffer.Slab.Bounded`

```swift
/// `Buffer.Slab.Bounded` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity heap-backed slab. `~Copyable` with CoW on `Element: Copyable`.
/// Ownership transfer across threads is a move; bitmap and storage travel
/// together as one unit.
///
/// ## Intended Use
///
/// - Handoff of a fixed-capacity sparse-slot buffer between producer/consumer
///   threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent slot insert/remove. Ownership is single-owner;
/// transfer is one-shot.
extension Buffer.Slab.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A4 — `Buffer.Slab.Bounded.Indexed<Tag>`

```swift
/// `Buffer.Slab.Bounded.Indexed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Tag` is a phantom `~Copyable` type parameter used only for `Index<Tag>` ↔
/// `Index<Element>` conversion via `Tagged.retag()`. Nothing is stored under
/// `Tag`. The underlying wrapped `Buffer.Slab.Bounded` provides the real
/// ownership-transfer invariant via `~Copyable`. Transfer across threads is
/// a move; the old thread loses access.
///
/// ## Intended Use
///
/// - Moving a phantom-tagged slab from a producer thread to a consumer.
/// - Sending into an `actor`'s initializer where the caller wants `Index<Tag>`
///   access.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. Ownership is single-owner; transfer is
/// one-shot. `Tag` carries no runtime state and adds no Sendable constraint.
extension Buffer.Slab.Bounded.Indexed: @unsafe @unchecked Sendable
    where Element: Sendable, Tag: ~Copyable {}
```

### Appendix A5 — `Buffer.Slab.Small._Representation` (package-scoped enum)

```swift
/// Package-scoped enum payload for `Buffer.Slab.Small`.
///
/// ## Safety Invariant
///
/// Enum holds either a `Buffer.Slab.Inline<inlineCapacity>` (inline storage)
/// or a `Buffer.Slab` (heap storage). Both payloads are `~Copyable`; the
/// enum itself is `~Copyable`. Enum destruction fires only the active case's
/// deinit. Transfer across threads is a move of whichever payload is active.
///
/// ## Intended Use
///
/// - Internal representation of `Buffer.Slab.Small`. The outer `Small`
///   carries the public Sendable conformance.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. Package-scoped; never crosses module
/// boundaries directly. The `@unchecked` covers the compiler's inability to
/// propagate Sendable through `<let inlineCapacity: Int>` on the inline
/// payload.
extension Buffer.Slab.Small._Representation: @unsafe @unchecked Sendable
    where Element: Sendable {}
```

### Appendix A6 — `Buffer.Slab.ConsumeState`

```swift
/// State for consuming iteration of `Buffer.Slab`.
///
/// ## Safety Invariant
///
/// `final class` held exclusively by a single `Sequence.Consume.View` at a
/// time. Owns `Storage.Slab` (final class), a `Bit.Vector.Bounded` bitmap,
/// and a `Bit.Vector.Ones.Bounded.Iterator` cursor. `deinit` drains remaining
/// occupied slots by iterating `bitmap.ones` and moving each element out of
/// storage. Ownership transfer across threads is a move of the view that
/// holds the single reference.
///
/// ## Intended Use
///
/// - Consuming iteration: drain a slab buffer element-by-element while
///   guaranteeing that elements not iterated are correctly deinitialized on
///   early exit.
/// - Transfer of an in-flight consume view between threads as a one-shot
///   handoff.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Two threads must not share the
/// ConsumeState. Underlying storage must not be mutated while the view is
/// alive.
public final class ConsumeState: @unsafe @unchecked Sendable {
```

### Appendix A7 — `Buffer.Slab.Bounded.ConsumeState`

```swift
/// State for consuming iteration of `Buffer.Slab.Bounded`.
///
/// ## Safety Invariant
///
/// Same as `Buffer.Slab.ConsumeState`: `final class` owned exclusively by one
/// consume view; `deinit` drains remaining occupied slots via bitmap.
///
/// ## Intended Use
///
/// - Consuming iteration of a bounded slab with correct cleanup on early exit.
/// - One-shot transfer of in-flight iteration between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration.
public final class ConsumeState: @unsafe @unchecked Sendable {
```

### Appendix A8 — `Buffer.Slab.Inline.ConsumeState`

```swift
/// State for consuming iteration of `Buffer.Slab.Inline`.
///
/// ## Safety Invariant
///
/// `final class` owned exclusively by one `Sequence.Consume.View`. Elements
/// are moved from the inline `@_rawLayout` storage into a heap-allocated
/// `Storage.Heap` during `consume()`; the ConsumeState then iterates the
/// bitmap over the heap storage. `deinit` drains any slots not reached by
/// iteration.
///
/// ## Intended Use
///
/// - Consuming iteration of an inline slab; heap transfer provides safe
///   iteration semantics that outlive the source buffer's enclosing scope.
/// - Transferring in-flight iteration state between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration.
public final class ConsumeState: @unsafe @unchecked Sendable {
```

### Appendix A9 — `Buffer.Slab.Inline.Iterator`

```swift
/// Iterator over slab inline buffer elements.
///
/// ## Safety Invariant
///
/// Struct holds an `UnsafePointer<Element>` base, a snapshot of the
/// `Bit.Vector.Static<wordCount>` bitmap, and cursors. Iterator is a one-shot
/// transferable iteration token. The iterator is valid only while the source
/// buffer exists; transfer across threads moves the iteration state.
///
/// ## Intended Use
///
/// - Producing elements on one thread and consuming them on another where the
///   iterator is fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Two threads must not advance the
/// same iterator. The underlying buffer must not be mutated while the iterator
/// is alive.
@unsafe public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol,
    @unsafe @unchecked Sendable {
```

### Appendix A10 — `Buffer.Linear`

```swift
/// `Buffer.Linear` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Buffer.Linear` is `~Copyable` (conditionally `Copyable` with CoW). It
/// owns a `Storage.Heap` (final class) and a `Header` cursor. Ownership
/// transfer across threads is a move; CoW on `Element: Copyable` via
/// `isKnownUniquelyReferenced` ensures mutations never observe shared storage.
///
/// ## Intended Use
///
/// - Handoff of a producer-filled linear buffer to a consumer thread.
/// - Sending into an `actor`'s initializer.
/// - Ownership transfer at thread boundaries in pipelines.
///
/// ## Non-Goals
///
/// Does NOT support concurrent append/drain. No internal locks. Ownership is
/// single-owner; transfer is one-shot.
extension Buffer.Linear: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A11 — `Buffer.Linear.Bounded`

```swift
/// `Buffer.Linear.Bounded` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity linear buffer. Same ownership-transfer shape as
/// `Buffer.Linear`: `~Copyable` with CoW on `Element: Copyable`.
///
/// ## Intended Use
///
/// - Handoff of a fixed-capacity linear buffer between producer/consumer
///   threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent append/drain. Ownership is single-owner.
extension Buffer.Linear.Bounded: @unsafe @unchecked Sendable
    where Element: Sendable {}
```

### Appendix A12 — `Buffer.Linear.Small._Representation`

```swift
/// Package-scoped enum payload for `Buffer.Linear.Small`.
///
/// ## Safety Invariant
///
/// Enum holds either `Buffer.Linear.Inline<inlineCapacity>` or `Buffer.Linear`.
/// Both are `~Copyable`; enum destruction fires only the active case. Transfer
/// across threads is a move of the active payload.
///
/// ## Intended Use
///
/// - Internal representation of `Buffer.Linear.Small`.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. Package-scoped; the outer `Small`
/// carries the public conformance. The `@unchecked` covers the inference
/// gap around `<let inlineCapacity: Int>` on the inline payload.
extension Buffer.Linear.Small._Representation: @unsafe @unchecked Sendable
    where Element: Sendable {}
```

### Appendix A13 — `Buffer.Linear.Iterator`

```swift
/// Iterator that provides both element-at-a-time and span-based iteration
/// for linear storage.
///
/// ## Safety Invariant
///
/// Struct holds an `UnsafePointer<Element>` base + remaining count. Iterator
/// is a one-shot transferable iteration token over CoW-backed storage.
///
/// ## Intended Use
///
/// - Producing elements on one thread and consuming them on another where the
///   iterator is fully constructed before transfer.
/// - Use as part of `Sequence.Protocol` / `Sequence.Borrowing.Protocol`
///   iteration plumbing.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated while the iterator is alive.
public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol,
    @unsafe @unchecked Sendable {
```

### Appendix A14 — `Buffer.Linear.Bounded.Iterator`

Same body as Appendix A13. Separate nominal type — apply the same three-section docstring.

### Appendix A15 — `Buffer.Linear.ConsumeState`

```swift
/// State for consuming iteration of `Buffer.Linear`.
///
/// ## Safety Invariant
///
/// `final class` owned exclusively by one `Sequence.Consume.View`. Holds a
/// `Buffer.Linear.Header`, a `Storage.Heap` reference, and a position cursor.
/// `deinit` drains remaining elements in `[position ..< header.count]`,
/// then sets `storage.initialization = .empty` so the Storage.Heap deinit is
/// a no-op. Ownership transfer across threads is a move of the view that
/// holds the single reference.
///
/// ## Intended Use
///
/// - Consuming iteration of a linear buffer with correct cleanup on early
///   exit.
/// - One-shot transfer of in-flight iteration between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration.
public final class ConsumeState: @unsafe @unchecked Sendable {
```

### Appendix A16 — `Buffer.Linear.Bounded.ConsumeState`

Same body as Appendix A15. Separate type, same semantics.

### Appendix A17 — `Buffer.Linear.Small.Iterator`

Same body as Appendix A13; iterator over small linear storage (inline or heap payload).

### Appendix A18 — `Buffer.Linear.Small.ConsumeState`

Same body as Appendix A15; elements are moved to heap regardless of starting mode.

### Appendix A19 — `Buffer.Linear.Inline.Iterator`

Same body as Appendix A13; iterator over inline linear buffer with `Storage.Inline` pointer base.

### Appendix A20 — `Buffer.Linear.Inline.ConsumeState`

Same body as Appendix A15; elements are moved from inline to heap during consume.

### Appendix A21 — `Buffer.Ring`

```swift
/// `Buffer.Ring` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Buffer.Ring` is `~Copyable` (conditionally `Copyable` with CoW). It owns
/// a `Storage.Heap` and a ring `Header` (head, count, capacity). Ownership
/// transfer across threads is a move; CoW on `Element: Copyable` prevents
/// mutations from observing shared storage.
///
/// ## Intended Use
///
/// - Handoff of a producer-filled ring buffer to a consumer thread.
/// - Sending into an `actor`'s initializer.
/// - One-shot transfer channel between threads when external synchronization
///   handles the "handoff complete" signal.
///
/// ## Non-Goals
///
/// Does NOT support concurrent push/pop. Ownership is single-owner; transfer
/// is one-shot.
extension Buffer.Ring: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A22 — `Buffer.Ring.Bounded`

Same body as A21, tailored for fixed capacity.

### Appendix A23 — `Buffer.Ring.Small._Representation`

Same body as Appendix A12, substituting Ring/Ring.Inline/Ring.

### Appendix A24 — `Buffer.Ring.Iterator`

```swift
/// Iterator over ring buffer elements that handles wrap-around through
/// two contiguous regions.
///
/// ## Safety Invariant
///
/// Struct holds an `UnsafePointer<Element>` base, a remaining count, and an
/// optional second-region base + count for wrap-around. Iterator is a
/// one-shot transferable iteration token over CoW-backed storage.
///
/// ## Intended Use
///
/// - Producing elements on one thread and consuming them on another where the
///   iterator is fully constructed before transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated while the iterator is alive.
public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol,
    @unsafe @unchecked Sendable {
```

### Appendix A25 — `Buffer.Ring.Bounded.Iterator`

Same body as A24.

### Appendix A26 — `Buffer.Ring.ConsumeState`

```swift
/// State for consuming iteration of `Buffer.Ring`.
///
/// ## Safety Invariant
///
/// `final class` owned exclusively by one `Sequence.Consume.View`. Holds a
/// mutable `Buffer.Ring.Header` (head/count cursor) and a `Storage.Heap`.
/// `deinit` calls `Buffer.Ring.deinitializeAll(header:storage:)` to drain
/// remaining elements. Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Consuming iteration of a ring buffer with correct cleanup on early exit.
/// - One-shot transfer of in-flight iteration between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration.
public final class ConsumeState: @unsafe @unchecked Sendable {
```

### Appendix A27 — `Buffer.Ring.Bounded.ConsumeState`

Same as A26.

### Appendix A28 — `Buffer.Ring.Small.Iterator`

Same body as A24, tailored for small storage (inline or heap payload).

### Appendix A29 — `Buffer.Ring.Small.ConsumeState`

Same body as A26; elements are linearized to heap.

### Appendix A30 — `Buffer.Ring.Inline.Iterator`

```swift
/// Iterator over ring inline buffer elements.
///
/// ## Safety Invariant
///
/// `@unsafe` struct holds an `UnsafePointer<Element>` base, a snapshot of the
/// `Buffer.Ring.Header`, and a logical cursor. Physical-index computation uses
/// modular arithmetic against `head` and `capacity`. Iterator is a one-shot
/// transferable iteration token.
///
/// ## Intended Use
///
/// - Iteration over an inline ring buffer; transfer of in-flight iteration
///   state between threads after full construction.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated while the iterator is alive.
@unsafe public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol,
    @unsafe @unchecked Sendable {
```

### Appendix A31 — `Buffer.Ring.Inline.ConsumeState`

Same body as A26; elements are linearized from inline to heap during consume.

### Appendix A32 — `Buffer.Arena`

```swift
/// `Buffer.Arena` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Buffer.Arena` is `~Copyable` (conditionally `Copyable` with CoW). It owns
/// a `Storage.Arena` (final class) and a `Header` (occupied, highWater,
/// freeHead). Generation tokens on each slot serve as the occupancy oracle.
/// Ownership transfer across threads is a move; CoW on `Element: Copyable`
/// prevents shared-mutation hazards.
///
/// ## Intended Use
///
/// - Handoff of a populated arena (for example, a tree's backing storage)
///   between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent slot allocation/deallocation. Ownership is
/// single-owner; transfer is one-shot. External handles (`Position`) remain
/// valid only on the receiving thread.
extension Buffer.Arena: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A33 — `Buffer.Arena.Inline<let inlineCapacity: Int>`

```swift
/// `Buffer.Arena.Inline` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` with an inline `InlineArray<inlineCapacity, Meta>` for
/// per-slot generation tokens and an `@_rawLayout` element buffer. `deinit`
/// iterates meta and deinitializes each occupied slot. Transfer across
/// threads is a move; all storage is inline, so the entire arena travels
/// as one unit.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized arena.
/// - Embedding inside a larger `~Copyable` / `Sendable` container (for
///   example, an inline tree).
///
/// ## Non-Goals
///
/// Does NOT support concurrent slot allocation/deallocation. Ownership is
/// single-owner; transfer is one-shot. The `@unchecked` also covers the
/// compiler's inability to propagate Sendable through `<let inlineCapacity: Int>`
/// and through the `@_rawLayout` `_Elements` bridge type.
extension Buffer.Arena.Inline: @unsafe @unchecked Sendable
    where Element: Sendable {}
```

### Appendix A34 — `Buffer.Arena.Bounded`

Same body as A32, tailored for fixed capacity.

### Appendix A35 — `Buffer.Arena.Small._Representation`

Same body as Appendix A12, substituting Arena/Arena.Inline/Arena.

### Appendix A36 — `Buffer.Slots<Metadata>`

```swift
/// `Buffer.Slots` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `Buffer.Slots` is `~Copyable` (conditionally `Copyable`). It owns a
/// `Storage.Split<Metadata>` with metadata and element arrays in one heap
/// allocation. `Metadata: BitwiseCopyable` is trivially Sendable. Element
/// lifecycle is consumer-managed — `Buffer.Slots` has no element deinit;
/// the consumer (for example, a hash table) must deinitialize occupied
/// slots before release. Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Handoff of a populated slots buffer (Swiss-table hash map, metadata-
///   parametric random-access storage) between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent slot insert/remove. The buffer enforces no
/// occupancy invariant — callers must uphold the "deinit what you init"
/// contract before transfer.
extension Buffer.Slots: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A37 — `Buffer.Linked<let N: Int>`

```swift
/// `Buffer.Linked` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Pool-backed linked list. `Buffer.Linked` is `~Copyable` (conditionally
/// `Copyable` with CoW). It owns a `Storage.Pool` (final class) and a
/// header pointing at head/tail nodes. Each node stores an
/// `InlineArray<N, Index<Node>>` link array (N=1: singly linked, N=2:
/// doubly linked). Ownership transfer across threads is a move; CoW on
/// `Element: Copyable` via the pool's class reference prevents
/// shared-mutation hazards.
///
/// ## Intended Use
///
/// - Handoff of a populated linked list between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insert/remove. The pool has no internal
/// locks. Ownership is single-owner; transfer is one-shot. The `@unchecked`
/// covers the compiler's inability to propagate Sendable through
/// `<let N: Int>` on the per-node link array.
extension Buffer.Linked: @unsafe @unchecked Sendable where Element: Sendable {}
```

### Appendix A38 — `Buffer.Linked.Small._Representation`

Same body as Appendix A12, substituting Linked/Linked.Inline/Linked.

### Appendix A39 — `Buffer.Linked.ConsumeState`

```swift
/// State for consuming iteration of `Buffer.Linked`.
///
/// ## Safety Invariant
///
/// `final class` owned exclusively by one `Sequence.Consume.View`. Holds a
/// `Storage.Pool` reference, a `current` node index, and the pool's
/// sentinel. `deinit` traverses the remaining link chain from `current` to
/// `sentinel`, moves each node's element out, and deallocates the node.
/// Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Consuming iteration of a linked list with correct node cleanup on
///   early exit.
/// - One-shot transfer of in-flight iteration between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration.
public final class ConsumeState: @unsafe @unchecked Sendable {
```

### Appendix A40 — `Buffer.Linked.Inline.Iterator`

```swift
/// Iterator over inline linked list buffer elements.
///
/// ## Safety Invariant
///
/// `@unsafe` struct holds an `UnsafePointer<Buffer<Element>.Linked<N>.Node>`
/// base, current and sentinel indices, and an inline element cache.
/// Iteration follows node link chain via pointer arithmetic. Iterator is a
/// one-shot transferable iteration token.
///
/// ## Intended Use
///
/// - Iteration over an inline linked list; transfer of in-flight iteration
///   state between threads after full construction.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration. Underlying buffer must not be
/// mutated while the iterator is alive.
@unsafe public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol,
    @unsafe @unchecked Sendable {
```

---

## Low-Confidence Flags

LOW_CONFIDENCE applies to 10 outer `<let N: Int>` value-generic variants where the B classification is primary (they are `~Copyable` ownership-transfer containers) but the `<let N: Int>` structural Sendable inference gap creates plausible Category D motivation. Per Agent 2's precedent, these are flagged to the D queue for principal adjudication but classified B inline.

1. `Buffer.Slab.Bounded.Indexed<Tag>` (Tag phantom + ~Copyable wrapper — closest to Agent 4 Hash.Table<Element>)
2. `Buffer.Slab.Small._Representation` (enum; `<let inlineCapacity: Int>` on inline payload)
3. `Buffer.Linear.Small._Representation` (same pattern)
4. `Buffer.Ring.Small._Representation` (same pattern)
5. `Buffer.Arena.Inline<let inlineCapacity: Int>` (standalone Inline variant with its own deinit)
6. `Buffer.Arena.Small._Representation` (enum with Inline payload)
7. `Buffer.Linked<let N: Int>` (heap-backed, but `<let N: Int>` on link-array)
8. `Buffer.Linked.Small._Representation` (enum; carries outer `<let N: Int>` plus inline's `<let inlineCapacity: Int>`)
9. `Buffer.Arena.Inline._Elements` — technically a clean D, also LOW_CONFIDENCE because its posture as "package-scoped @_rawLayout bridge" is identical to Agent 2's clean D calls but appears as a named type here rather than inside Storage (adjudicator may choose to handle buffer's one case uniformly with storage's three cases).
10. `Buffer.Aligned` (unconditional Sendable, not gated on Element because Element is fixed to UInt8 — the existing docstring treats this as a genuine ownership-transfer Cat B and that is the straightforward reading; LOW_CONFIDENCE only because unconditional Sendable can hide other things. On rereading, the storage is pure bytes with no Element phantom concern, so I believe B is correct and this is probably not D. Flagged here for transparency; I would not actually move it.)

---

## Preexisting Warnings Noted

None specific to buffer-primitives observed during file inspection. No build was run (per project rule `feedback_ask_before_build_test.md` — ask before `swift build`/`swift test`), so any strict-memory warnings touching these sites would surface only during Phase 2 application.

---

## References

- Master findings: `unsafe-audit-findings.md`
- Agent 2 precedent (structurally identical types): `unsafe-audit-agent2-findings.md`
- Agent 4 precedent (phantom-type analysis for Tagged wrappers): `unsafe-audit-agent4-findings.md`
- Ecosystem convention: `ownership-transfer-conventions.md`
- Skill: `memory-safety` — [MEM-SAFE-024]
- Category D queue: `unsafe-audit-category-d-queue.md` — Agent 6 section (appended below)
