# Per-Slot Initialization Tracking

<!--
---
version: 1.0.0
last_updated: 2026-02-05
status: RECOMMENDATION
---
-->

## Context

**Trigger**: During implementation of `Storage.Inline`, a footgun emerged where callers must manually keep `_initialization` state in sync with actual slot state. When elements are moved out via `move(at:)`, the caller must update `initialization` or deinit will attempt to clean up already-moved slots, causing crashes.

**Current Design**: `Storage.Initialization` enum tracks initialized slots as ranges:
- `.empty` — no slots initialized
- `.one(Range)` — single contiguous range
- `.two(first, second)` — two disjoint ranges (for ring buffers)

This is space-efficient (enum + 1-2 ranges) but requires **manual state management**.

**Observed Failures**:
1. Explicit `deinitialize()` without resetting `initialization` → double-free on deinit
2. `move(at:)` without updating `initialization` → deinit cleans up empty slots

**Workaround Applied**: Idempotent guard (`_DeinitGuard`) prevents double-deinitialize. Does NOT prevent stale state from moves.

## Question

Should `Storage.Inline` use per-slot initialization tracking via `Bit.Vector.Static` to eliminate manual state management entirely?

## Analysis

### Option A: Current Design (Range-Based + Guard)

**Description**: Keep `Initialization` enum for range tracking. Caller manages state. Guard prevents double-deinitialize.

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    var _storage: _Raw
    var _initialization: Initialization  // .empty | .one | .two
    let _guard: _DeinitGuard
}
```

**Memory Overhead**:
- `Initialization` enum: ~34 bytes (enum tag + two Range values)
- `_DeinitGuard`: 8 bytes (class reference) + heap allocation

**Advantages**:
- Minimal per-slot overhead (no bits)
- Efficient for common patterns (linear fill, ring buffer)
- Already implemented

**Disadvantages**:
- Manual state management required
- Footgun: `move()` without state update → crash
- Limited to 1-2 contiguous ranges
- Guard adds heap allocation

**Constraints**:
- Caller must update `initialization` after every `move()` or partial `deinitialize()`
- Cannot represent arbitrary sparse patterns (e.g., slots 0, 3, 7 initialized)

---

### Option B: Per-Slot Tracking via Bit.Vector.Static

**Description**: Replace `Initialization` enum with `Bit.Vector.Static<wordCount>` where each bit represents one slot's initialization state. Operations auto-update bits.

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    var _storage: _Raw
    var _slots: Bit.Vector.Static<wordCount>  // wordCount = ceil(capacity / 64)
    // No guard needed — state is always accurate
}

// wordCount calculation (compile-time)
// capacity 1-64:   1 word  =  8 bytes
// capacity 65-128: 2 words = 16 bytes
// capacity 129-192: 3 words = 24 bytes
```

**Auto-updating operations**:
```swift
public mutating func initialize(to element: consuming Element, at slot: Index<Element>) {
    unsafe pointer(at: slot).initialize(to: element)
    _slots[slot.asBitIndex] = true  // Automatic
}

public mutating func move(at slot: Index<Element>) -> Element {
    let value = unsafe pointer(at: slot).move()
    _slots[slot.asBitIndex] = false  // Automatic
    return value
}

deinit {
    _slots.ones.forEach { bitIndex in
        deinitialize(at: bitIndex.asSlotIndex)
    }
}
```

**Memory Overhead**:
| Capacity | Words | Bytes | vs Current (~42B) |
|----------|-------|-------|-------------------|
| 1-64     | 1     | 8     | -34 bytes (81% less) |
| 65-128   | 2     | 16    | -26 bytes (62% less) |
| 129-192  | 3     | 24    | -18 bytes (43% less) |
| 193-256  | 4     | 32    | -10 bytes (24% less) |
| 257-320  | 5     | 40    | -2 bytes (5% less) |
| 321-384  | 6     | 48    | +6 bytes (14% more) |

**Advantages**:
- **Zero caller responsibility** — state auto-updates
- **Impossible stale state** — operations self-track
- **Any initialization pattern** — not limited to ranges
- **Less memory** for typical capacities (≤256)
- **No heap allocation** — no guard class needed
- **Efficient iteration** — `ones.forEach` uses hardware popcount

**Disadvantages**:
- More memory for large capacities (>320 slots)
- Bit manipulation on every operation (negligible on modern CPUs)
- Breaking API change (removes `initialization` property)
- Dependency on `Bit_Vector_Primitives`

**Constraints**:
- Requires `Bit.Vector.Static` to support generic `wordCount` computed from `capacity`
- Need compile-time `wordCount = (capacity + 63) / 64` computation

---

### Option C: Hybrid — BitVector for Inline, Ranges for Heap

**Description**: Use per-slot tracking for `Storage.Inline` (bounded capacity) but keep range-based tracking for `Storage.Heap` (unbounded capacity).

**Rationale**:
- `Inline` has compile-time bounded capacity → BitVector overhead is predictable
- `Heap` can have arbitrary capacity → per-slot bits could be expensive

**Advantages**:
- Best of both worlds
- Inline gets automatic safety
- Heap avoids per-slot overhead for large buffers

**Disadvantages**:
- Inconsistent API between Inline and Heap
- Two mental models

---

### Option D: Per-Slot Tracking with Lazy BitVector

**Description**: Use BitVector but allocate lazily only when needed (e.g., after first move operation that creates sparse state).

```swift
enum SlotTracking {
    case ranges(Initialization)           // Efficient for dense patterns
    case sparse(Bit.Vector.Static<N>)     // For arbitrary patterns
}
```

**Advantages**:
- Optimal for common case (ranges)
- Falls back to precise tracking when needed

**Disadvantages**:
- Complex implementation
- Runtime branching
- Memory layout complexity

---

## Comparison

| Criterion | A: Current | B: BitVector | C: Hybrid | D: Lazy |
|-----------|------------|--------------|-----------|---------|
| Zero caller responsibility | ❌ | ✅ | ✅ (Inline) | ✅ |
| Impossible stale state | ❌ | ✅ | ✅ (Inline) | ✅ |
| Memory (typical ≤128) | ~42B | 8-16B | 8-16B | ~42B+ |
| Memory (large >320) | ~42B | >40B | ~42B | variable |
| Any init pattern | ❌ | ✅ | ✅ | ✅ |
| No heap allocation | ❌ | ✅ | ✅ | ❌ |
| Consistent API | ✅ | ✅ | ❌ | ✅ |
| Implementation complexity | Low | Medium | Medium | High |
| Breaking change | ❌ | ✅ | ✅ | ✅ |

## Technical Considerations

### Computing wordCount from capacity

Swift value generics allow:
```swift
public struct Inline<let capacity: Int>: ~Copyable {
    // Compute word count at compile time
    var _slots: Bit.Vector.Static<(capacity + 63) / 64>
}
```

Need to verify this compiles. If not, may need explicit wordCount parameter:
```swift
public struct Inline<let capacity: Int, let wordCount: Int>: ~Copyable
```

### Index Conversion

`Bit.Index` vs `Index<Element>` — need safe conversion:
```swift
extension Index where Element: ~Copyable {
    var asBitIndex: Bit.Index {
        Bit.Index(rawValue.rawValue)  // Both are ordinal-based
    }
}
```

### Deinit Iteration Performance

Current: O(1) or O(2) — just deinitialize 1-2 ranges
BitVector: O(popcount) — iterate set bits via `ones.forEach`

For typical use (most slots initialized), performance is similar. BitVector may be faster for sparse patterns (many empty slots).

### Sendable Conformance

`Bit.Vector.Static` is `Sendable` when its backing `InlineArray<N, UInt>` is. Should maintain `Storage.Inline: Sendable where Element: Sendable`.

## Outcome

**Status**: RECOMMENDATION

### Recommendation: Option B (Per-Slot BitVector)

**Rationale**:

1. **Eliminates the footgun entirely** — the primary goal
2. **Less memory for typical use** — most inline storage has ≤256 capacity
3. **Simpler mental model** — no manual state management
4. **No heap allocation** — removes `_DeinitGuard` class
5. **Enables sparse patterns** — future flexibility

**Migration Path**:

1. Add `Bit_Vector_Primitives` dependency to `Storage_Primitives_Core`
2. Replace `_initialization: Initialization` with `_slots: Bit.Vector.Static<wordCount>`
3. Remove `_DeinitGuard` (no longer needed)
4. Update `initialize(to:at:)` to set bit
5. Update `move(at:)` to clear bit
6. Update `deinitialize(at:)` to clear bit
7. Update `deinit` to iterate `_slots.ones`
8. Deprecate/remove `initialization` property (breaking change)
9. Update all tests

### Experimental Results (2026-02-05)

Experiment `Experiments/bitvector-slot-tracking` confirmed:

1. **Value generic arithmetic**: Needs explicit `wordCount` parameter (fallback)
   - `Bit.Vector.Static<(capacity + 63) / 64>` does NOT compile
   - Use `Storage.Inline<let capacity: Int, let wordCount: Int>` instead

2. **Memory comparison** (measured):
   | Design | Size |
   |--------|------|
   | Current `Initialization` enum | 33 bytes |
   | Current + guard ref | ~41 bytes |
   | BitVector 1 word (≤64 slots) | 8 bytes |
   | BitVector 2 words (≤128 slots) | 16 bytes |
   | BitVector 4 words (≤256 slots) | 32 bytes |

3. **Automatic slot tracking**: CONFIRMED
4. **Sparse pattern support**: CONFIRMED
5. **Deinit cleanup via `ones.forEach`**: CONFIRMED

### Open Questions

1. Should we keep `initialization` property as computed (derive from bits)?
2. Should `Storage.Heap` also migrate to BitVector?
3. API for specifying wordCount (explicit param vs computed default)?

### Next Steps

1. ✅ ~~Create experiment to verify value generic arithmetic for wordCount~~
2. Prototype implementation with explicit wordCount parameter
3. Benchmark performance vs current
4. Decide on API (remove vs deprecate `initialization`)

## References

- `Research/inline-deinitialize-state-reset.md` — Original footgun analysis
- `Experiments/deinit-guard-idempotence/` — Guard pattern validation (SUPERSEDED — consolidated into `swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/` V02-guard-idempotence)
- `swift-bit-vector-primitives/` — BitVector implementation
- Swift Evolution: SE-0393 Value and Type Parameter Packs
