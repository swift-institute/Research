# Zero-Allocation nextSpan for Generating Iterators

<!--
---
version: 2.0.0
last_updated: 2026-02-26
status: DECISION
---
-->

## Context

The unified `Sequence.Iterator.Protocol` uses `nextSpan(maximumCount:) -> Span<Element>` as its sole requirement. This works naturally for contiguous-storage iterators (Buffer, Span) that slice existing memory. But generating iterators — those that compute elements on-the-fly with no backing storage (Cyclic groups, graph traversals, tree iterators, queue/stack/heap iterators) — cannot satisfy `nextSpan` without somewhere to store the computed element so Span can borrow from it.

~80 iterator types across the swift-primitives monorepo are affected. Currently they implement only `next() -> Element?` with zero heap allocation. Any solution must preserve that zero-allocation property.

## Question

How can generating iterators satisfy `nextSpan(maximumCount:) -> Span<Element>` with zero heap allocation?

## Constraints

1. **Span requires a pointer** — `Span(_unsafeStart: UnsafePointer<Element>, count: Int)` needs a stable address
2. **Span as closure result is blocked** — `withUnsafePointer` requires `Result: Escapable`, Span is `~Escapable`
3. **`@_lifetime(&self)` on nextSpan** — returned Span borrows from the iterator via mutable borrow
4. **`withUnsafePointer(to: val)` creates a copy** — only `withUnsafeMutablePointer(to: &var)` gives in-place pointer (confirmed by `stored-property-span-access` experiment)

## Analysis

### Option A: Heap Buffer (`UnsafeMutablePointer.allocate`)

Store a heap-allocated single-element buffer as a field. Confirmed in experiment V1/V6.

```swift
struct Iterator: ~Copyable, Sequence.Iterator.Protocol {
    let _buffer: UnsafeMutablePointer<Element>
    // ...
    init() { _buffer = .allocate(capacity: 1) }
    deinit { _buffer.deallocate() }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        _buffer.pointee = computeNext()
        return unsafe Span(_unsafeStart: UnsafePointer(_buffer), count: 1)
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| Heap allocation | **1 allocation per iterator** |
| Iterator copyability | `~Copyable` (needs `deinit`) |
| Implementation complexity | Low |
| Element constraint | None (`~Copyable` elements supported) |

### Option B: `Storage<Element>.Inline<1>` (from storage-primitives)

Stack-allocated single-element storage with `@_rawLayout`. Provides direct `pointer(at:)` — no closure needed. Uses `_overrideLifetime` to chain Span lifetime to iterator.

```swift
struct Iterator: ~Copyable, Sequence.Iterator.Protocol {
    var _storage: Storage<Element>.Inline<1>
    // ...

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        if !_storage.isEmpty { _ = _storage.move.last() }
        _storage.initialize.next(to: computeNext())
        let span = unsafe Span(
            _unsafeStart: UnsafePointer(_storage.pointer(at: .zero)),
            count: 1
        )
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| Heap allocation | **Zero** |
| Iterator copyability | `~Copyable` (`@_rawLayout` types are `~Copyable`) |
| Implementation complexity | Medium (Storage.Inline API) |
| Size overhead | ~32 bytes (256-bit initialization bitmap) |
| Element constraint | None (`~Copyable` elements supported) |

### Option C: Keep `next()` as Alternate Requirement

Don't force `nextSpan` on generating iterators. Instead, make the protocol accept either:
- `nextSpan` as primary (contiguous-storage iterators implement this)
- `next()` for Copyable elements (generating iterators implement this)

The default `next()` calls `nextSpan(maximumCount: 1)`. No default for `nextSpan` from `next()` (impossible without storage).

Types must implement at least one. If neither is implemented, `next()` calls `nextSpan` calls... compiler error (no `nextSpan` implementation).

| Criterion | Assessment |
|-----------|------------|
| Heap allocation | **Zero** (generating iterators keep `next()`) |
| Iterator copyability | **Preserved** (no `~Copyable` requirement) |
| Implementation complexity | Low |
| Protocol design | Dual-requirement with asymmetric defaults |
| Risk | Types implementing only `next()` — calling `nextSpan` would fail at runtime (infinite recursion) if default exists, or compile-time error if no default |

**Problem**: If `nextSpan` has no default, it's a compile error for types implementing only `next()`. If it has a default calling `next()`, we need storage (back to square one). If it has a default returning empty Span, `next()` (which calls `nextSpan`) always returns nil — broken.

**Variant C2**: Remove the default `next()`. Both are independent requirements. Types implement whichever they can:
- Contiguous iterators: implement `nextSpan`, get `next()` free via extension
- Generating iterators: implement `next()`, but `nextSpan` must still be satisfied somehow

This doesn't work because `nextSpan` is a protocol requirement — it MUST have an implementation.

### Option D: Protocol Hierarchy — Two Protocols, One Refining the Other

```swift
// Base protocol: element-at-a-time
protocol IteratorProtocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @_lifetime(self: immortal)
    mutating func next() -> Element?  // for Copyable only
}

// Refinement: adds span access
protocol SpanIteratorProtocol: IteratorProtocol {
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element>
}
```

| Criterion | Assessment |
|-----------|------------|
| Heap allocation | **Zero** (generating iterators stay on base protocol) |
| Iterator copyability | **Preserved** |
| Protocol design | Clean hierarchy, clear semantics |
| Cost | Sequence.Protocol must choose which protocol to require |

**Problem**: This is essentially what we had before the unification (two protocols). It undoes the plan's central goal.

### Option E: `Storage.Inline<1>` with Zero-Overhead Wrapper

Create a lightweight wrapper around `Storage.Inline<1>` optimized for single elements, removing the 256-bit bitmap overhead. Or use a simpler raw-layout type:

```swift
@_rawLayout(like: Element)
struct SingleElementBuffer<Element: ~Copyable>: ~Copyable {
    // Same layout as Element, direct pointer access
    // No initialization tracking (caller manages)
}
```

| Criterion | Assessment |
|-----------|------------|
| Heap allocation | **Zero** |
| Iterator copyability | `~Copyable` |
| Size overhead | Zero (same size as Element) |
| Element constraint | None |
| Implementation | Requires new type in storage-primitives |

### Option F: Regular Stored Property + `withUnsafeMutablePointer`

No new type at all. Just add `var _element: Element` as a regular stored property. Extract a pointer via `withUnsafeMutablePointer(to: &_element)` — the `&inout` form gives an in-place pointer (not a copy). Create Span outside the closure, `_overrideLifetime` to `&self`.

```swift
struct Iterator: ~Copyable, Sequence.Iterator.Protocol {
    var _current: Int
    let _end: Int
    var _element: Element  // regular stored property — always initialized

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        guard _current < _end, maximumCount > 0 else {
            let ptr = withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer(p)
            }
            let empty = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(empty, mutating: &self)
        }
        _element = computeNext()
        let ptr = withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer(p)
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| Heap allocation | **Zero** |
| Iterator copyability | `~Copyable` (due to `@_lifetime(&self)` on nextSpan) |
| Size overhead | 1 byte (Optional tag) for `~Copyable` elements; **Zero** for concrete Copyable |
| Element constraint | **Copyable preferred**; `~Copyable` viable via `Optional<Element>` + `consume` (with 1-byte overhead and payload-offset layout assumption) |
| Implementation | **Minimal** — no new types, no experimental features |
| `@_rawLayout` required | **No** |
| `_initialized` Bool needed | **No** — Optional's `.none` serves as uninitialised state |

**Critical distinction**: `withUnsafeMutablePointer(to: &_element)` gives the in-place address (inout contract). `withUnsafePointer(to: _element)` selects the `borrowing` overload, which does not guarantee address identity with the original storage for Copyable types — the compiler may materialize a temporary copy. Only the `&` form works.

**Safety argument**: The pointer is at a fixed offset within `self`. `@_lifetime(&self)` ensures `self` cannot move while the Span is alive. This is the same safety model as `@_rawLayout` — both escape a pointer from `withUnsafe*` closures, both rely on the containing struct's lifetime encompassing the Span's lifetime.

## Comparison

| | Allocation | Copyable | Size overhead | Complexity | ~Copyable elements |
|---|---|---|---|---|---|
| **A: Heap buffer** | 1 per iterator | No | Pointer (8 bytes) | Low | Yes |
| **B: Storage.Inline<1>** | Zero | No | ~32 bytes bitmap | Medium | Yes |
| **C: Dual requirement** | Zero | Yes | None | Low | Broken (no default nextSpan) |
| **D: Two protocols** | Zero | Yes | None | Low | Yes (undoes unification) |
| **E: Minimal raw-layout** | Zero | No | Zero | Medium (new type) | Yes |
| **F: Stored property** | Zero | No | 1 byte (Optional tag) | **Minimal** | **Yes** (via Optional + consume) |

## Key Insight

The fundamental tension: **Span requires stable addressable storage, and stable addressable storage requires `~Copyable` ownership.** There is no way to return a `Span<Element>` from a stored property without the type being `~Copyable` (either via `@_rawLayout`, `deinit` for heap pointer, or `Storage.Inline`).

For generating iterators that are currently Copyable, ANY solution that provides `nextSpan` will make them `~Copyable`. The only way to preserve Copyability is to not require `nextSpan` (Options C/D).

## Outcome

**Status**: DECISION — Option E (`@_rawLayout` wrapper) is the primary approach. Option F (stored property) is viable for `~Copyable` elements via `Optional<Element>` + `consume`, but Option E is preferred for zero overhead, no layout assumptions, and explicit ownership semantics.

### Decision Matrix

| Context | Recommended approach |
|---------|---------------------|
| **Generic iterators** (`Element: ~Copyable`) | **Option E** — `@_rawLayout` wrapper (primary) |
| **Concrete Copyable iterators** (Int, Vertex, etc.) | **Option F** — regular stored property (simpler) |
| When heap allocation is acceptable | **Option A** — heap buffer |

### Design Rationale

`Sequence.Iterator.Protocol` declares `associatedtype Element: ~Copyable`. A generic iterator can use `Optional<Element>` with `_element = consume value` for `~Copyable` elements, but this introduces a payload-offset layout assumption (`UnsafeRawPointer(optionalPtr).assumingMemoryBound(to: Element.self)` assumes payload-first layout) and 1-byte overhead per element. `@_rawLayout` provides zero-overhead, correctly-typed pointer access without layout assumptions.

Additional reasons for Option E as primary:
1. **No layout assumptions**: `@_rawLayout` provides direct pointer access — no reinterpret cast on Optional's internal layout
2. **Zero overhead**: `SingleElementBuffer<Int>` = 8 bytes (same as `Int`); `Optional<Int>` = 9 bytes
3. **Explicit ownership**: `pointer().initialize(to:)` / `deinitialize(count:)` aligns with the primitives ecosystem's philosophy
4. **Generalises**: The `@_rawLayout` wrapper naturally becomes `Memory.Inline<Element, capacity>` for multi-element inline storage

### Option E: @_rawLayout Wrapper (Primary)

Validated by `inline-rawlayout-nextspan` experiment (2026-02-26). All 6 variants CONFIRMED.

**Pattern** (generic, works for all element types):

```swift
@_rawLayout(like: Element)
struct _Raw: ~Copyable { init() {} }

struct SingleElementBuffer<Element: ~Copyable>: ~Copyable {
    var _storage: _Raw
    func pointer() -> UnsafeMutablePointer<Element> {
        withUnsafePointer(to: _storage) { base in
            UnsafeMutablePointer(mutating: UnsafeRawPointer(base)
                .assumingMemoryBound(to: Element.self))
        }
    }
}
```

Key: return the `UnsafePointer` (Escapable) from `withUnsafePointer` closure, then create `Span` outside with `_overrideLifetime`. This bypasses the limitation where creating `Span` *inside* `withUnsafePointer` fails because `Span` is `~Escapable`.

This wrapper belongs in memory-primitives as `Memory.Inline<Element, capacity>` — raw typed addressable inline storage is a memory-layer concern (see `inline-storage-layering.md` research in storage-primitives).

### Option F: Stored Property (Secondary — Concrete Copyable Types)

Validated by `stored-property-span-access` experiment (2026-02-26):

| Variant | What | Result |
|---------|------|--------|
| V1 | `withUnsafeMutablePointer(to: &_element)` | CONFIRMED |
| V2 | `withUnsafePointer(to: _element)` | REFUTED (copies value) |
| V3 | Full generating iterator | CONFIRMED |
| V4 | Optional stored property | CONFIRMED |

**Critical rule**: MUST use `withUnsafeMutablePointer(to: &_element)` (inout `&`). NEVER `withUnsafePointer(to: _element)` — that passes by value, creating a dangling pointer.

Useful for concrete iterators with known Copyable element types where the `@_rawLayout` machinery is unnecessary overhead. For `~Copyable` elements, `Optional<Element>` + `consume` is viable but introduces a payload-offset layout assumption and 1-byte overhead — prefer Option E in generic contexts.

### Implementation Plan

1. Create `Memory.Inline<Element, capacity>` in memory-primitives (the `@_rawLayout` wrapper, domain-correct home)
2. Refactor `Storage.Inline<N>` internals to compose `Memory.Inline` + bitmap (preserves API)
3. Generic generating iterators use `Memory.Inline<Element, 1>` — supports `~Copyable` elements, zero overhead
4. Concrete Copyable iterators MAY use stored property (Option F) for simplicity
5. All generating iterators become `~Copyable` (acceptable — iterators are consumed linearly)
6. Existing `next()` implementations remain as performance overrides

## References

- `swift-sequence-primitives/Experiments/stored-property-span-access/` — Option F validation (V1,V3,V4 CONFIRMED; V2,V5 REFUTED)
- `swift-sequence-primitives/Experiments/inline-rawlayout-nextspan/` — Option E validation (ALL CONFIRMED)
- `swift-sequence-primitives/Experiments/lazy-iterator-nextspan-strategies/` — V1 (heap buffer CONFIRMED), V2 (inline optional REFUTED)
- `swift-storage-primitives/Sources/Storage Inline Primitives/` — `Storage.Inline<N>` implementation
- `swift-buffer-primitives/Sources/Buffer Linear Small Primitives/Buffer.Linear.Small+Span.swift` — `_overrideLifetime` pattern
