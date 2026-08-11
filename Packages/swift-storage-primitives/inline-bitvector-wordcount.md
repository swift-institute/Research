# Inline BitVector WordCount Parameter

<!--
---
version: 1.1.0
last_updated: 2026-02-05
status: DECISION
---
-->

## Context

**Trigger**: During implementation of per-slot initialization tracking for `Storage.Inline`, we added a `wordCount` generic parameter to specify how many 64-bit words the tracking bit vector needs:

```swift
public struct Inline<let capacity: Int, let wordCount: Int>: ~Copyable {
    var _storage: _Raw
    var _slots: Bit.Vector.Static<wordCount>
}
```

This creates an ergonomic regression — users must specify both `capacity` and `wordCount`:
```swift
var storage = Storage<Int>.Inline<8, 1>()  // Annoying
```

**Observation**: `@_rawLayout(likeArrayOf: Element, count: capacity)` already solves automatic sizing for element storage. Why can't we do the same for bit tracking?

**Root Cause**: Swift value generics don't support compile-time arithmetic. This fails:
```swift
var _slots: Bit.Vector.Static<(capacity + 63) / 64>  // Does NOT compile
```

## Question

How should `Storage.Inline` handle per-slot initialization tracking without requiring an explicit `wordCount` parameter?

## Analysis

### Option A: Explicit wordCount Parameter (Current)

**Description**: User specifies both `capacity` and `wordCount` as generic parameters.

```swift
public struct Inline<let capacity: Int, let wordCount: Int>: ~Copyable {
    var _slots: Bit.Vector.Static<wordCount>
}

// Usage
var storage = Storage<Int>.Inline<8, 1>()
var storage = Storage<Int>.Inline<128, 2>()
var storage = Storage<Int>.Inline<256, 4>()
```

**Advantages**:
- Precise — no wasted memory
- Type-safe — wordCount is part of the type
- Flexible — supports any capacity

**Disadvantages**:
- Ergonomic regression — user must compute wordCount
- Error-prone — user might specify wrong wordCount
- Verbose — every instantiation needs two parameters

**Constraints**:
- User must know the formula: `wordCount = ⌈capacity / 64⌉`

---

### Option B: Fixed-Size BitVector (4 Words)

**Description**: Always use 4 words (256 bits) regardless of capacity. Covers capacities up to 256.

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    var _slots: Bit.Vector.Static<4>  // Always 256 bits
}

// Usage
var storage = Storage<Int>.Inline<8>()    // Uses 32 bytes for tracking
var storage = Storage<Int>.Inline<64>()   // Uses 32 bytes for tracking
var storage = Storage<Int>.Inline<256>()  // Uses 32 bytes for tracking
```

**Advantages**:
- Simple API — single generic parameter
- No user computation required
- Covers typical inline capacities (≤256)

**Disadvantages**:
- Wastes memory for small capacities (32 bytes vs 8 bytes for ≤64 slots)
- Hard limit at 256 slots
- Less precise typing — `Inline<8>` and `Inline<64>` have same tracking overhead

**Memory Overhead Comparison**:
| Capacity | Option A | Option B | Waste |
|----------|----------|----------|-------|
| 1-64     | 8 bytes  | 32 bytes | 24 bytes |
| 65-128   | 16 bytes | 32 bytes | 16 bytes |
| 129-192  | 24 bytes | 32 bytes | 8 bytes |
| 193-256  | 32 bytes | 32 bytes | 0 bytes |

**Constraints**:
- Capacity > 256 not supported (use Heap storage)

---

### Option C: Tiered Fixed Sizes via Typealiases

**Description**: Provide typealiases for common capacity tiers with pre-computed wordCount.

```swift
// In Storage.Inline
public struct Inline<let capacity: Int, let wordCount: Int>: ~Copyable { ... }

// Convenience typealiases
extension Storage where Element: ~Copyable {
    public typealias Inline64<let capacity: Int> = Inline<capacity, 1>   // ≤64
    public typealias Inline128<let capacity: Int> = Inline<capacity, 2>  // ≤128
    public typealias Inline256<let capacity: Int> = Inline<capacity, 4>  // ≤256
}

// Usage
var storage = Storage<Int>.Inline64<8>()
var storage = Storage<Int>.Inline128<100>()
```

**Advantages**:
- Precise memory usage
- Somewhat simpler than raw Option A
- Clear tier indication

**Disadvantages**:
- Still requires user to pick correct tier
- Multiple type names to learn
- Typealias with value generics may not work (needs verification)

**Constraints**:
- Swift typealias + value generics interaction untested

---

### Option D: Runtime Word Count (Non-Generic BitVector)

**Description**: Store word count as runtime value, use maximum-sized backing storage.

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    var _slots: Bit.Vector.Dynamic  // Runtime-sized, max 4 words allocated
}

// Bit.Vector.Dynamic implementation
struct Dynamic {
    var _storage: (UInt64, UInt64, UInt64, UInt64)  // 4 words inline
    let wordCount: Int  // Actual words used
}
```

**Advantages**:
- Simple `Inline<N>` API
- Runtime flexibility

**Disadvantages**:
- Same memory overhead as Option B (always 32+ bytes)
- Additional runtime field (wordCount)
- Runtime bounds checking
- Deviates from static BitVector design

**Constraints**:
- Requires new `Bit.Vector.Dynamic` type or modification to existing

---

### Option E: Inline BitVector via @_rawLayout

**Description**: Use `@_rawLayout` for the bit tracking storage itself, matching capacity.

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    struct _Raw: ~Copyable {}

    @_rawLayout(likeArrayOf: UInt64, count: /* ??? */)
    struct _Bits: ~Copyable {}  // Can't compute count from capacity

    var _storage: _Raw
    var _bits: _Bits
}
```

**Advantages**:
- Would be ideal if it worked

**Disadvantages**:
- **Does not work** — can't compute `(capacity + 63) / 64` in @_rawLayout
- Same fundamental limitation as Bit.Vector.Static

**Constraints**:
- Swift limitation — no compile-time arithmetic on value generics

---

### Option F: Conditional Compilation / Overloads

**Description**: Provide multiple `Inline` struct definitions for different capacity ranges.

```swift
// For capacities 1-64
public struct Inline<let capacity: Int>: ~Copyable where capacity <= 64 {
    var _slots: Bit.Vector.Static<1>
}

// For capacities 65-128
public struct Inline<let capacity: Int>: ~Copyable where capacity <= 128, capacity > 64 {
    var _slots: Bit.Vector.Static<2>
}
```

**Advantages**:
- Simple API
- Precise memory

**Disadvantages**:
- **Does not work** — Swift doesn't support value generic constraints like `where capacity <= 64`
- Would require separate type names

**Constraints**:
- Swift limitation — no value generic constraints

---

## Comparison

| Criterion | A: Explicit | B: Fixed-4 | C: Typealiases | D: Runtime | E: RawLayout | F: Overloads |
|-----------|-------------|------------|----------------|------------|--------------|--------------|
| Simple API | ❌ | ✅ | ⚠️ | ✅ | N/A | N/A |
| Memory efficient | ✅ | ❌ | ✅ | ❌ | N/A | N/A |
| Works today | ✅ | ✅ | ⚠️ | ✅ | ❌ | ❌ |
| No user computation | ❌ | ✅ | ⚠️ | ✅ | N/A | N/A |
| Supports >256 | ✅ | ❌ | ✅ | ❌ | N/A | N/A |

Legend: ✅ = Yes, ❌ = No, ⚠️ = Partial, N/A = Not applicable (doesn't work)

## Technical Considerations

### Typical Inline Capacities

Inline storage is for **small, fixed-size** collections. Typical use cases:
- Small vectors: 4-16 elements
- Small strings: 16-32 bytes
- Small buffers: 64-128 elements

Capacities >256 are unusual for inline storage — Heap is more appropriate.

### Memory Budget Perspective

For a typical `Storage<Int>.Inline<8>`:
- Element storage: 8 × 8 = 64 bytes
- BitVector (Option A, 1 word): 8 bytes → Total: 72 bytes
- BitVector (Option B, 4 words): 32 bytes → Total: 96 bytes
- Overhead: 24 bytes (33% more tracking overhead)

For `Storage<UInt8>.Inline<64>`:
- Element storage: 64 × 1 = 64 bytes
- BitVector (Option A, 1 word): 8 bytes → Total: 72 bytes
- BitVector (Option B, 4 words): 32 bytes → Total: 96 bytes
- Overhead: 24 bytes (33% more tracking overhead)

The waste is constant (24 bytes) regardless of element size.

### Comparison to Previous Design

Previous design (`Initialization` enum + `_DeinitGuard`):
- `Initialization`: ~33 bytes
- `_DeinitGuard` reference: 8 bytes
- Total: ~41 bytes

Option B (4 words): 32 bytes — **actually smaller** than previous design!

## Outcome

**Status**: DECISION

### Decision: Option B (Fixed 4 Words) with Structural Bound

**Rationale**:

1. **Simpler API** — Single generic parameter, matches `@_rawLayout` elegance
2. **Actually smaller** — 32 bytes vs ~41 bytes in previous design
3. **Defines the type's operating envelope** — Not a compromise, a design constraint
4. **No user error** — Can't specify wrong wordCount
5. **Future-proof** — If Swift adds value generic arithmetic, easy to optimize later

### Design Constraints (Normative)

**[INV-INLINE-CAPACITY-001]**: `Storage.Inline` MUST only target capacities in the range `0...256`.

**[INV-INLINE-CAPACITY-002]**: Capacities above 256 MUST use `Storage.Heap` or another non-inline strategy.

**[INV-INLINE-TRACKING-001]**: `_slots` has 256 bits (4 × UInt64); only the low `capacity` bits are semantically meaningful.

### Type Invariants

```
- capacity is a compile-time constant
- 0 <= capacity <= 256
- _slots has 256 bits; only bits 0..<capacity are used
- Bit i is set iff slot i contains an initialized element
```

### Enforcement

Swift can't express `where capacity <= 256`, but we enforce at runtime:

```swift
public init() {
    precondition(capacity <= 256, "Storage.Inline capacity must be ≤256; use Storage.Heap for larger capacities")
    _storage = _Raw()
    _slots = Bit.Vector.Static<4>()
}
```

This catches misuse deterministically in debug builds and prevents accidental UB.

### Expert API (Deferred)

If a compelling use case emerges for exact bitset sizing, add a separate type:
- `Storage.Inline<capacity>` — Ergonomic, fixed-256 tracking, bounded (primary)
- `Storage.Inline.Exact<capacity, wordCount>` — Expert-only, explicit, unchecked

**Current decision**: Do NOT add the expert API unless a real use case demands it. Keep the mainstream API clean.

### Implementation Changes

1. Remove `wordCount` generic parameter
2. Use `Bit.Vector.Static<4>` (256 bits) for all capacities
3. Add `precondition(capacity <= 256)` in `init()`
4. Update doc-comments with capacity constraint
5. Update all tests to use `Inline<N>` (single parameter)

## References

- `Research/per-slot-initialization-tracking.md` — Original BitVector recommendation
- `Experiments/bitvector-slot-tracking/` — Value generic arithmetic limitation confirmed
- Swift Forums: Value and Type Parameter Packs (SE-0393)
