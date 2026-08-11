# Inline Storage Layering

<!--
---
version: 1.0.0
last_updated: 2026-02-26
status: RECOMMENDATION
---
-->

## Context

**Trigger**: While implementing zero-allocation `nextSpan` for ~80 generating iterators across the monorepo, we need a single-element inline buffer with a stable address for Span creation. `Storage.Inline<1>` works but adds 32 bytes of initialization tracking overhead (`Bit.Vector.Static<4>`) that the iterator doesn't need — it manages initialization with a single `Bool`.

This overhead is a known compromise. The original plan (per `Research/per-slot-initialization-tracking.md`) was proportional bitmap sizing via `Bit.Vector.Static<(capacity + 63) / 64>`, but Swift does not support computed value generic parameters. The fixed 4-word bitmap was chosen over a second generic parameter (`Inline<capacity, wordCount>`) for ergonomic reasons.

The deeper question: `Storage.Inline<N>` bundles two distinct concerns:

| Concern | Domain | Overhead |
|---------|--------|----------|
| Raw typed addressable storage (`@_rawLayout`) | Memory layout | **Zero** |
| Per-slot initialization tracking (`Bit.Vector.Static<4>`) | Storage lifecycle | **32 bytes** |

The five-layer architecture separates memory-primitives (Tier 13) from storage-primitives (Tier 14). Raw addressable storage is a memory concern. Initialization tracking is a storage concern. These are currently co-mingled.

**Constraint**: Swift 6.2 does not support computed value generic parameters. `@_rawLayout(likeArrayOf:count:)` does not accept expressions. This is confirmed by experiment `bitvector-slot-tracking` and research `inline-bitvector-wordcount.md`.

## Question

Should raw typed inline storage (the `@_rawLayout` part of `Storage.Inline`) be separated from initialization tracking (the `Bit.Vector.Static` part), and if so, where should each concern live in the package layering?

## Constraints

1. **Package domain boundaries**: memory-primitives handles memory layout; storage-primitives handles element lifecycle
2. **No computed value generics in Swift 6.2**: Bitmap size cannot be derived from capacity
3. **~80 generating iterators** need single-element inline storage with zero overhead
4. **Buffer consumers** (ring, linear, slab) need initialization tracking for deinit safety
5. **Naming**: Must follow Nest.Name convention. No compound names. Must feel natural in each package's namespace

## Analysis

### Option A: Add `Memory.Inline<Element, capacity>` to memory-primitives

Introduce a zero-overhead typed inline storage type in memory-primitives. This is the raw `@_rawLayout` wrapper — addressable typed memory with no lifecycle tracking. `Storage.Inline<N>` is then refactored to compose it with tracking.

**memory-primitives (Tier 13)**:
```swift
extension Memory {
    /// Fixed-capacity typed memory region embedded inline in the containing struct.
    /// Provides addressable storage with zero overhead. Does not track element
    /// initialization — callers manage lifecycle.
    public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        struct _Raw: ~Copyable { init() {} }

        @usableFromInline
        var _storage: _Raw

        public init() { _storage = _Raw() }

        /// Stable pointer to element at slot. Valid while self is alive.
        @unsafe
        @_lifetime(borrow self)
        public func pointer(at slot: /* bounded index */) -> UnsafeMutablePointer<Element> {
            unsafe withUnsafePointer(to: _storage) { base in
                unsafe UnsafeMutablePointer(
                    mutating: UnsafeRawPointer(base)
                        .advanced(by: /* slot offset */)
                        .assumingMemoryBound(to: Element.self)
                )
            }
        }
    }
}
```

**storage-primitives (Tier 14)** — refactored to compose:
```swift
extension Storage<Element> {
    public struct Inline<let capacity: Int>: ~Copyable {
        @usableFromInline
        var _memory: Memory.Inline<Element, capacity>

        @usableFromInline
        var _slots: Bit.Vector.Static<4>

        // pointer(at:) delegates to _memory.pointer(at:)
        // initialize/move/deinitialize auto-update _slots
    }
}
```

**Iterator usage** (zero overhead):
```swift
struct CyclicIterator: ~Copyable {
    var _buffer: Memory.Inline<Int, 1>  // 8 bytes, no bitmap
    var _initialized: Bool              // 1 byte
    // ...
}
```

| Criterion | Assessment |
|-----------|------------|
| Domain correctness | Memory layer owns layout, storage layer owns tracking |
| Overhead for iterators | **Zero** (same size as Element) |
| Overhead for buffers | **Unchanged** (Storage.Inline still has bitmap) |
| Breaking change | Refactor Storage.Inline internals (API surface preserved) |
| Naming | `Memory.Inline` parallels `Storage.Contiguous`, `Memory.Buffer` |
| Dependency direction | Correct (storage depends on memory, not reverse) |
| Existing precedent | `Storage.Contiguous<Element>` already provides typed owned memory |
| Implementation | Medium — new type + refactor Storage.Inline internals |

### Option B: Separate tracked and untracked variants within storage-primitives

Keep everything in storage-primitives. Add an untracked variant alongside the existing `Storage.Inline`.

```swift
extension Storage<Element> {
    /// Untracked inline storage — no initialization bitmap.
    public struct Slot<let capacity: Int>: ~Copyable {
        var _storage: _Raw
        // pointer(at:) only — no initialize/move/deinitialize API
    }

    /// Tracked inline storage — with initialization bitmap.
    public struct Inline<let capacity: Int>: ~Copyable {
        var _storage: _Raw
        var _slots: Bit.Vector.Static<4>
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| Domain correctness | **Mixed** — raw layout is a memory concern in a storage package |
| Overhead for iterators | **Zero** |
| Overhead for buffers | **Unchanged** |
| Breaking change | None (additive) |
| Naming | `Storage.Slot` or similar, but naming "raw layout" in a storage package feels misplaced |
| Implementation | Low — new type, no refactoring |

### Option C: Use `Storage.Inline<1>` as-is, accept 32-byte overhead

No architectural change. Iterators use `Storage.Inline<1>` and pay the 32-byte bitmap cost.

| Criterion | Assessment |
|-----------|------------|
| Domain correctness | N/A (no change) |
| Overhead for iterators | **32 bytes** per iterator instance |
| Breaking change | None |
| Implementation | None |

For context: if 10 iterators are alive simultaneously, that's 320 bytes of wasted bitmap. Small in absolute terms, but these are meant to be lightweight value types. The overhead is 4x the useful payload for `Int` elements.

### Option D: Wait for Swift computed value generics

If Swift gains `Bit.Vector.Static<(capacity + 63) / 64>`, the bitmap becomes proportional:

| Capacity | Bitmap bytes |
|----------|-------------|
| 1 | 8 (1 word) |
| 8 | 8 |
| 64 | 8 |
| 128 | 16 |
| 256 | 32 |

This would make `Storage.Inline<1>` cost 8 bytes for the bitmap (1 word), not 32. Combined with the 1-byte `_initialized` bool becoming unnecessary, the total overhead would be 8 bytes — acceptable.

| Criterion | Assessment |
|-----------|------------|
| Domain correctness | Doesn't address the mixing |
| Overhead for iterators | **8 bytes** (once available) |
| Timeline | **Unknown** — no Swift Evolution proposal exists |
| Implementation | Refactor `Storage.Inline` when feature ships |

## Comparison

| | Domain correct | Iterator overhead | Buffer overhead | Breaking | Complexity | Available now |
|---|---|---|---|---|---|---|
| **A: Memory.Inline** | Yes | **0 bytes** | Unchanged | Internal | Medium | Yes |
| **B: Storage.Slot** | Partial | **0 bytes** | Unchanged | None | Low | Yes |
| **C: As-is** | N/A | **32 bytes** | Unchanged | None | None | Yes |
| **D: Wait** | No | **8 bytes** | Reduced | Future | Low | No |

## Key Insight

The architectural question is not "how do we shrink the bitmap?" but "should the bitmap be bundled with the storage at all?"

Buffer types already maintain their own headers with initialization state. They sync to `_slots` at boundaries. Pool and Arena types within storage-primitives use `_slots` directly, but they're specialized allocators — a different domain from raw addressable memory.

For the iterator use case (and any future use case needing just addressable typed inline memory), the bitmap is pure overhead. Separating it into the correct layer makes both layers cleaner:

- **Memory.Inline**: "I provide typed addressable inline memory. Period."
- **Storage.Inline**: "I compose Memory.Inline with initialization tracking for lifecycle safety."

This parallels existing layering:
- `Memory.Buffer` → raw byte buffer (memory layer)
- `Storage.Heap` → heap storage with lifecycle tracking (storage layer)

## Recommendation

**Option A: `Memory.Inline<Element, capacity>` in memory-primitives.**

1. **Domain-correct**: Raw typed inline memory belongs in the memory layer
2. **Zero overhead**: Iterators use `Memory.Inline<Element, 1>` directly — 8 bytes for `Int`, no bitmap
3. **Clean composition**: `Storage.Inline<N>` composes `Memory.Inline` + `Bit.Vector.Static<4>` (preserving its existing API)
4. **Future-compatible**: When Swift gains computed value generics, `Storage.Inline` can shrink its bitmap independently
5. **Parallels existing types**: `Storage.Contiguous<Element>` (heap) ↔ `Memory.Inline<Element, N>` (stack)

### Implementation Path

1. Add `Memory.Inline<Element, capacity>` to memory-primitives with `pointer(at:)` API
2. Refactor `Storage.Inline<N>` internals to compose `Memory.Inline` (preserve public API)
3. Update generating iterators to use `Memory.Inline<Element, 1>` directly
4. Buffer consumers unchanged (they use `Storage.Inline` which retains tracking)

### Open Questions

1. **Naming**: Is `Memory.Inline<Element, capacity>` the right name? Alternatives: `Memory.Embedded`, `Memory.Fixed`. "Inline" is chosen because it describes where the memory lives (inline within the struct), paralleling "Contiguous" (which describes memory topology).
2. **Index type**: Should `pointer(at:)` use `Index<Element>.Bounded<capacity>` (like Storage.Inline) or a simpler subscript? For capacity 1, a parameterless accessor may be cleaner.
3. **Span access**: Should `Memory.Inline` provide a `span` property or `Span.Protocol` conformance? Or leave that to composition?

## Update (2026-02-26): Stored Property Alternative + Iterator Requirement

The `stored-property-span-access` experiment confirmed that regular stored properties can back Span creation using `withUnsafeMutablePointer(to: &_element)` — but only for **Copyable elements**. Since `Sequence.Iterator.Protocol` declares `associatedtype Element: ~Copyable`, generic iterators need `@_rawLayout` + `pointer().initialize(to:)` for `~Copyable` elements. Regular stored properties cannot be assigned with `=` when Element is `~Copyable`.

This confirms `Memory.Inline` is needed:
- **Generic iterators** (`Element: ~Copyable`) need `Memory.Inline<Element, 1>` — the `@_rawLayout` wrapper
- **`Storage.Inline` refactoring** — composition of `Memory.Inline` + bitmap remains the recommended architecture
- **Stored property approach** — secondary technique for concrete Copyable types only

## References

- `Research/per-slot-initialization-tracking.md` — Original bitmap design and trade-offs
- `Research/inline-bitvector-wordcount.md` — Computed wordCount analysis (DECISION: fixed 4 words)
- `Experiments/bitvector-slot-tracking/` — Confirmed value generic arithmetic doesn't compile
- `swift-sequence-primitives/Experiments/inline-rawlayout-nextspan/` — Confirmed `@_rawLayout` works for zero-allocation nextSpan
- `swift-sequence-primitives/Experiments/stored-property-span-access/` — Confirmed regular stored properties work for Span creation
- `swift-sequence-primitives/Research/zero-allocation-nextspan-for-generating-iterators.md` — Context for this investigation
