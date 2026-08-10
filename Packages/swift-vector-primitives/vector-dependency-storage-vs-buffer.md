# Vector Dependency: Storage vs Buffer

<!--
---
version: 2.0.1
last_updated: 2026-03-15
status: DEFERRED
---
-->

## Context

The intended dependency chain for data structures is:

```
storage-primitives ← buffer-primitives ← data structures ← ADTs
```

However, `swift-vector-primitives` currently depends on `swift-buffer-primitives` yet uses **zero** Buffer types. Every Storage reference goes directly to `Storage<Element>.Heap` and `Storage<Element>.Inline<N>`. The Buffer dependency exists only as a pass-through for Storage's re-exports.

This research investigates whether Vector should depend on Buffer (and use Buffer abstractions) or depend on Storage directly — and whether Buffer should be enhanced to support Vector's use case.

## Question

1. Can Vector be expressed in terms of Buffer disciplines instead of raw Storage?
2. If not today, is that a deficiency of Buffer? Could Buffer be improved to make this possible?
3. What is the semantically correct dependency architecture?

## Analysis

### Vector's Storage Usage Inventory

47 Storage references across 11 files. The APIs used:

| Storage API | Count | Purpose |
|---|---|---|
| `Storage<Element>.Heap` (type) | 2 | Stored property, init parameter |
| `Storage<Element>.Heap.create()` | 2 | Allocation |
| `Storage<Element>.Inline<N>` (type) | 5 | Stored property, local variables |
| `.pointer(at:)` | 25 | Element access (read/write) |
| `.initialize(to:at:)` | 6 | Element initialization |
| `.initialization = .linear(count:)` | 4 | State tracking |
| `.copy()` | 1 | CoW uniqueness |
| `.span` | 1 | Span.Protocol witness |
| `.withUnsafeBufferPointer()` | 1 | Span.Protocol witness |

Zero references to any `Buffer.` type.

### What IS a Vector, Semantically?

A Vector is:

- **Fixed-size**: Dimension N is a compile-time constant
- **Always fully initialized**: Every slot in [0, N) contains a valid element
- **Contiguous**: Elements are laid out linearly from slot 0
- **Value type with CoW**: When Element is Copyable, copies share storage until mutation

### What IS a Buffer Discipline?

A buffer discipline defines an initialization pattern within contiguous storage:

| Discipline | Initialization Pattern | Storage.Initialization |
|---|---|---|
| Linear | Contiguous `[0, count)` | `.one(0..<count)` |
| Ring | Wrapped window `[head, head+count) mod capacity` | `.one(...)` or `.two(...)` |
| Slab | Sparse, bitmap-tracked | `.empty` (bitmap is truth) |

### Is Vector a Linear Discipline?

**Yes.** A fully-initialized vector IS a linear buffer where `count == capacity == N`. The initialization pattern is `[0, N)` — precisely `.one(0..<N)`, which is the linear discipline.

The question is not whether Vector's memory layout matches the linear discipline — it does, trivially. The question is whether Buffer.Linear provides the capabilities Vector needs.

### What Buffer.Linear.Bounded Provides Today

`Buffer<Element>.Linear.Bounded` is the closest match: fixed-capacity, heap-backed, non-growing.

```swift
public struct Bounded: ~Copyable {
    package var header: Header      // count + capacity
    package var storage: Storage<Element>.Heap
}
extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
```

**Capabilities:**
- Fixed heap allocation via `Storage.Heap.create()`
- Dynamic count tracking (can be partially filled)
- `append(_:) -> Element?` (rejects when full)
- `consumeFront()`, `consumeBack()`
- Conditionally Copyable when Element: Copyable
- Initialization state tracking via header

**Missing capabilities Vector needs:**

| Capability | Vector Needs | Buffer.Linear.Bounded Has |
|---|---|---|
| Subscript by index | Yes | No |
| `span` property | Yes | No (iterators only) |
| `withUnsafeBufferPointer` | Yes | No |
| `Span.Protocol` | Yes | No |
| CoW (`_makeUnique`) | Yes | No |
| `mutableSpan` | Yes | No |

### Could Buffer Gain These Capabilities?

Each missing capability is analyzed:

#### 1. Subscript Access

Buffer.Linear could provide indexed read/write access. A bounded linear buffer with count elements has well-defined slots in [0, count). Subscript is a natural operation on any linear contiguous buffer.

**Verdict**: General-purpose. Any consumer of a linear buffer could want this. Not Vector-specific.

#### 2. Span / Span.Protocol

A linear buffer's elements are contiguous in [0, count). This is exactly what `Span.Protocol` describes. The conformance is natural.

**Verdict**: General-purpose. Buffer.Linear SHOULD conform to `Span.Protocol`.

#### 3. Copy-on-Write

`Buffer.Linear.Bounded` holds `Storage<Element>.Heap`, which is a class. When `Bounded` is `Copyable` (because `Element: Copyable`), copying produces two structs sharing one `Storage.Heap` — the classic CoW setup. Adding `_makeUnique()` via `isKnownUniquelyReferenced(&storage)` is straightforward.

**Verdict**: General-purpose. Any value-type wrapper over shared heap storage benefits from CoW. This is standard Swift practice.

#### 4. MutableSpan

Once CoW exists, mutable span access follows naturally: ensure uniqueness, then provide `MutableSpan` over `[0, count)`.

**Verdict**: General-purpose. Follows from CoW + span.

### What Would Vector Look Like Built on Buffer?

```swift
public struct Vector<Element: ~Copyable, let N: Int>: ~Copyable {
    package var _buffer: Buffer<Element>.Linear.Bounded

    // Invariant: _buffer.count == _buffer.capacity == N (always full)
}

extension Vector: Copyable where Element: Copyable {}
```

Then:

| Vector API | Delegation |
|---|---|
| `span` | `_buffer.span` |
| `withUnsafeBufferPointer` | `_buffer.withUnsafeBufferPointer(body)` |
| `subscript[index]` | `_buffer[index]` |
| `_makeUnique()` | `_buffer._makeUnique()` |
| `mutableSpan` | `_buffer.mutableSpan` |
| `forEach` | `_buffer.forEach` or iterate over span |

Vector becomes a thin type-level wrapper enforcing the "always full" invariant. All storage management, discipline tracking, CoW, and contiguous access live in Buffer where they belong.

### Is This Semantically Correct?

**Yes.** The semantic relationship is:

```
Buffer.Linear.Bounded  = "contiguous storage with linear discipline, fixed capacity"
Vector                 = "always-full Buffer.Linear.Bounded with compile-time N"
```

Vector's invariant (count == capacity == N) is a *strengthening* of Buffer.Linear.Bounded's invariant (0 <= count <= capacity). This is a valid subtype-like relationship expressed through composition.

The three buffer disciplines describe initialization *patterns*. Vector's pattern IS linear. Claiming Vector doesn't fit the linear discipline because it's "always full" would be like claiming a full glass doesn't follow fluid dynamics because there's no room left.

### What About Vector.Inline?

`Vector.Inline` currently uses `Storage<Element>.Inline<N>`. The equivalent Buffer type would be `Buffer<Element>.Linear.Inline<N>`. The same capabilities (subscript, span, Span.Protocol) would need to exist on the Inline variant.

### Revised Dependency Architecture

```
         storage-primitives
                ↑
         buffer-primitives  (+ subscript, span, CoW, Span.Protocol)
              ↑     ↑
    vector-primitives  data structures (Stack, Queue, Deque)
```

Vector is a consumer of Buffer, just like Stack and Queue. It uses a different subset of Buffer's capabilities (subscript + span rather than push + pop), but the underlying discipline is the same: Linear.

### Comparison: Enhanced Buffer vs Storage-Direct

| Criterion | Enhanced Buffer | Storage-Direct |
|---|---|---|
| Semantic correctness | ✓ Vector IS a linear buffer | ✗ Bypasses discipline layer |
| Code duplication | ✓ CoW, span, subscript shared | ✗ Each consumer re-implements |
| Honest dependency | ✓ Uses what it depends on | ✓ |
| Consistency | ✓ All data structures built on Buffer | ✗ Vector is special-cased |
| Timelessness | ✓ One canonical linear buffer discipline | ✗ Parallel implementations drift |
| Implementation effort | Higher (enhance Buffer first) | Lower (status quo works) |

## Outcome

**Status**: IN_PROGRESS

**Direction**: Enhance `Buffer.Linear.Bounded` (and `.Inline`) with general-purpose capabilities that any consumer of a linear buffer needs:

1. **Subscript access** — indexed read/write into `[0, count)`
2. **`Span.Protocol` conformance** — `span` + `withUnsafeBufferPointer`
3. **Copy-on-Write** — `_makeUnique()` for value-type semantics when Copyable
4. **MutableSpan** — CoW-protected mutable span access

These are not Vector-specific features. They are general capabilities of a bounded linear buffer. Once Buffer provides them, Vector becomes a thin wrapper enforcing `count == capacity == N`.

**Next steps**:

1. Implement capabilities on `Buffer.Linear.Bounded` and `Buffer.Linear.Inline`
2. Migrate Vector to use Buffer instead of raw Storage
3. Verify Vector.Inline works with `Buffer.Linear.Inline`

## Changelog

- v1.0.0 (2026-02-06): Initial analysis recommended Storage-direct (Option B)
- v2.0.0 (2026-02-06): Reframed as Buffer deficiency. The gaps are general-purpose capabilities that Buffer should provide. Vector IS a linear buffer.

## References

- `swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift` — Buffer discipline definitions
- `swift-buffer-primitives/Sources/Buffer Linear Primitives/Buffer.Linear.Bounded.swift` — Bounded variant
- `swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md` — Discipline design philosophy
- `swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift` — Storage type definitions
- `swift-vector-primitives/Sources/Vector Primitives Core/Vector.swift` — Vector type definition

### Deferral

**Date**: 2026-03-15

**Reason**: The document identified that Vector should be built on Buffer.Linear (not raw Storage) after buffer-primitives gains general-purpose capabilities (subscript, Span.Protocol, CoW, MutableSpan). The "next steps" require enhancing Buffer.Linear.Bounded and Buffer.Linear.Inline first. This was blocked by the buffer-primitives inline module split in February 2026, which restructured the buffer modules. The Buffer.Linear enhancements have not been implemented in the post-split structure.

**Resume when**: Buffer.Linear.Bounded gains subscript access, Span.Protocol conformance, and Copy-on-Write support, at which point Vector can be migrated to use Buffer as its substrate.
