# Bounded vs. Unbounded Index Access in Storage.Inline Public API

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
---
-->

## Context

Storage.Inline is a static-capacity type (`let capacity: Int`) at tier 14. Per [IMPL-050], static-capacity types MUST accept `Index<Element>.Bounded<N>`. A plan removed unbounded `Index<Element>` from Storage.Inline's public API. Storage-primitives built and all 187 tests passed, but buffer-primitives (~40+ errors) broke.

The initial analysis (v1.0.0) concluded "dual public API" — keep both bounded and unbounded as public. That conclusion was challenged: can we instead upgrade the entire chain to produce and consume bounded indices end-to-end?

## Question

Can every index producer in the buffer layer be upgraded to yield bounded indices, making Storage.Inline's bounded-only public API correct by construction?

## Analysis

### Architecture of Index Flow

```
Index PRODUCERS                    Index CONSUMER
─────────────────────────────────  ──────────────────
Bit.Vector.Static<4>.ones          Storage.Inline<capacity>
  → Bit.Index (unbounded)            pointer(at: Bounded<capacity>)
  → .retag(Element.self)             initialize(to:at: Bounded<capacity>)
  → Index<Element> (unbounded)       move(at: Bounded<capacity>)
  ← NEEDS: Bounded<capacity>         deinitialize(at: Bounded<capacity>)

Header.firstVacant()
  → Bit.Index (unbounded)
  ← NEEDS: Bit.Index.Bounded<capacity>

count.map(Ordinal.init)
  → Index<Element> (unbounded)
  ← NEEDS: Index<Element>.Bounded<capacity>

header.head (Ring modular)
  → Index<Element> (unbounded)
  ← NEEDS: Index<Element>.Bounded<capacity>

Free-list slot (Linked)
  → Index<Element> (unbounded)
  ← NEEDS: Index<Element>.Bounded<capacity>
```

### The Bitmap Mismatch

Storage.Inline uses `_slots: Bit.Vector.Static<4>` (hardcoded 4 words = 256 bits). The value generic `capacity` is separate. Swift does not support value generic arithmetic, so `Bit.Vector.Static<(capacity + 63) / 64>` is impossible (confirmed by experiment `bitvector-slot-tracking`).

This means `_slots.ones` yields `Bit.Index` bounded by 256, while element operations need `Bounded<capacity>` where capacity ∈ [1, 256]. The TYPE cannot bridge this gap.

### The Key Insight: Narrowing at the Producer Boundary

The `!` in `Bounded(unbounded)!` is principled when it's inside the type that maintains the invariant. It's unprincipled when it leaks to arbitrary consumer code.

Analogy: `Array` has internal unsafe pointer arithmetic, but its public API is safe. The unsafety is encapsulated.

**Pattern**: Each layer narrows at its own boundary, yielding only bounded indices to its consumers.

### Option F: Upgrade Producers to Yield Bounded (The Bounded Chain)

Each index producer narrows internally, exposing only bounded indices.

#### Source 1: Bitmap Iteration (Buffer.Slab deinit, forEach)

**Current**: `header.bitmap.ones.forEach { bitIndex in storage.deinitialize(at: bitIndex.retag()) }`

**Upgraded**: Buffer.Slab.Header provides bounded iteration:

```swift
extension Buffer.Slab.Header.Static {
    func forEachOccupied(_ body: (Bit.Index.Bounded<wordCount>) -> Void) {
        bitmap.ones.forEach { bitIndex in
            // SAFE: bitmap invariant guarantees only bits [0, wordCount) are set
            body(Bit.Index.Bounded<wordCount>(bitIndex)!)
        }
    }
}
```

The `!` is inside `Header.Static` — the type that maintains the bitmap invariant. Consumers receive `Bit.Index.Bounded<wordCount>`, which retags to `Index<Element>.Bounded<wordCount>`.

#### Source 2: Slot Allocation (Buffer.Slab.Header.firstVacant)

**Current**: Returns `Bit.Index?` (unbounded)

**Upgraded**: Returns `Bit.Index.Bounded<wordCount>?`:

```swift
extension Buffer.Slab.Header.Static {
    func firstVacant(max: Bit.Index.Count) -> Bit.Index.Bounded<wordCount>? {
        var idx: Bit.Index = .zero
        let end = max.map(Ordinal.init)
        while idx < end {
            if !bitmap[idx] {
                // SAFE: idx < max ≤ wordCount
                return Bit.Index.Bounded<wordCount>(idx)!
            }
            idx += .one
        }
        return nil
    }
}
```

#### Source 3: Count-to-Index (Buffer.Linear append, consumeBack)

**Current**: `header.count.map(Ordinal.init)` → `Index<Element>` (unbounded)

**Upgraded**: Narrow after mapping:

```swift
let slot = header.count.map(Ordinal.init)
let bounded = Index<Element>.Bounded<capacity>(slot)!
// SAFE: count ≤ capacity (container invariant)
storage.initialize(to: element, at: bounded)
```

The `!` is inside Buffer.Linear's static method — the type that maintains count ≤ capacity.

#### Source 4: Public API Parameters (remove(at:), replace, swap, subscript)

**Current**: Accept `Index<Element>` from user

**Upgraded per [IMPL-050]**: Accept `Index<Element>.Bounded<capacity>` in public API:

```swift
// Buffer.Linear.Inline
public mutating func remove(at index: Index<Element>.Bounded<capacity>) -> Element
public subscript(index: Index<Element>.Bounded<capacity>) -> Element

// Buffer.Slab.Inline
public mutating func insert(_ element: consuming Element, at slot: Bit.Index.Bounded<wordCount>)
public mutating func remove(at slot: Bit.Index.Bounded<wordCount>) -> Element
```

The USER provides bounded indices obtained from the collection's own API (iterator, position lookup, etc.).

#### Source 5: Ring Head/Tail (Buffer.Ring)

**Current**: `header.head: Index<Element>` (unbounded modular)

**Upgraded**: Store `Index<Element>.Bounded<capacity>`:

```swift
struct Header {
    var head: Index<Element>.Bounded<capacity>
    var count: Index<Element>.Count
}
```

Modular arithmetic on bounded produces bounded (successor wraps to zero, predecessor wraps to max).

#### Source 6: Free-List Slots (Buffer.Linked)

**Current**: `_allocateSlot()` returns `Index<Element>` from free list

**Upgraded**: Returns `Index<Element>.Bounded<capacity>`:

```swift
func _allocateSlot() -> Index<Element>.Bounded<capacity> {
    let slot = header.freeHead
    // SAFE: all free-list entries are in [0, capacity) by construction
    let bounded = Index<Element>.Bounded<capacity>(slot)!
    header.freeHead = nextPointer(at: bounded)
    return bounded
}
```

#### Source 7: Storage.Inline Internal (deinit, deinitialize.all)

**Current**: `_slots.ones.forEach { bitIndex in pointer(at: bitIndex.retag()) }`

**Same package** — uses `package func pointer(at: Index<Element>)`. No change needed. Can optionally add:

```swift
package func forEachOccupied(_ body: (Index<Element>.Bounded<capacity>) -> Void) {
    _slots.ones.forEach { bitIndex in
        body(Index<Element>.Bounded<capacity>(bitIndex.retag(Element.self))!)
    }
}
```

### Where the `!` Lives — Encapsulation Audit

| Layer | Narrowing Site | Invariant Owner | Principled? |
|-------|---------------|-----------------|-------------|
| Storage.Inline.deinit | `pointer(at: bitIndex.retag())` | Storage.Inline (same package, unbounded OK) | N/A — package access |
| Storage.Inline.forEachOccupied | `Bounded(bitIndex.retag())!` | Storage.Inline | Yes — maintains `_slots` invariant |
| Buffer.Slab.Header.firstVacant | `Bounded(idx)!` | Header (maintains bitmap) | Yes — `idx < max ≤ wordCount` |
| Buffer.Slab.Header.forEachOccupied | `Bounded(bitIndex)!` | Header (maintains bitmap) | Yes — only set bits < wordCount |
| Buffer.Linear static methods | `Bounded(count.map(...))!` | Buffer.Linear (maintains count ≤ capacity) | Yes — invariant guaranteed |
| Buffer.Ring.Header | Stored as `Bounded<capacity>` | Header (modular arithmetic) | Yes — arithmetic wraps within bound |
| Buffer.Linked._allocateSlot | `Bounded(slot)!` | Linked (free-list construction) | Yes — all slots in [0, capacity) |

**No `!` at consumer call sites.** All narrowing is inside the type that maintains the invariant.

### Comparison with Option C (Dual API)

| Criterion | C (dual public) | F (upgrade producers) |
|-----------|----------------|----------------------|
| [IMPL-050] compliance | Yes | Yes |
| [IMPL-052] end-to-end bounded | No — unbounded leaks to call sites | Yes — bounded flows everywhere |
| Cross-package compatibility | Yes (both overloads public) | Yes (only bounded needed) |
| Unprincipled narrowing | None (no narrowing at all) | Principled (inside invariant owners) |
| API surface | Larger (2 overloads per op) | Smaller (1 overload per op) |
| Downstream upgrade cost | Zero | Medium — buffer types need work |
| End-user guidance | Via `@_disfavoredOverload` | Enforced — only bounded is available |
| Type safety guarantee | Weaker — user CAN pass unbounded | Stronger — compile-time proof |

### What Needs No Change

- `Bit.Vector.Static` — stays word-count parameterized, yields `Bit.Index`
- `Bit.Vector.Ones.Static` — stays unbounded iteration
- Range-based operations (`deinitialize(range:)`, `move(range:to:)`, `copy(range:to:)`) — stay `Range<Index<Element>>`, used for contiguous bulk operations. Range construction from count/capacity provides safety.
- Storage.Inline internal methods — same package, use package-scoped unbounded

### What Needs Change

**swift-storage-primitives** (already done):
- [x] `pointer(at: Bounded<capacity>)` overloads — public, preferred
- [x] `pointer(at: Index<Element>)` — package access
- [x] `initialize(to:at: Bounded<capacity>)` — public
- [x] `move(at: Bounded<capacity>)` — public
- [x] `deinitialize(at: Bounded<capacity>)` — public
- [ ] Optional: `forEachOccupied` yielding bounded (nice-to-have)

**swift-buffer-primitives** (the upstream upgrade):
- [ ] `Buffer.Slab.Header.Static.firstVacant()` → return `Bit.Index.Bounded<wordCount>?`
- [ ] `Buffer.Slab.Header.Static.forEachOccupied()` → yield `Bit.Index.Bounded<wordCount>`
- [ ] Buffer.Slab.Inline public API → bounded parameters
- [ ] Buffer.Slab static operations → bounded parameters + internal narrowing
- [ ] Buffer.Linear.Inline public API → `Index<Element>.Bounded<capacity>`
- [ ] Buffer.Linear static operations → internal narrowing for count-derived indices
- [ ] Buffer.Ring.Inline → bounded head/tail, bounded modular arithmetic
- [ ] Buffer.Linked.Inline → bounded slot allocation/traversal
- [ ] Deinit paths → delegate through bounded iteration or forEachOccupied

### Swift Language Limitation

Value generic arithmetic (`Bit.Vector.Static<(capacity + 63) / 64>`) does not exist. This means:
1. `Bit.Vector.Static<4>` stays hardcoded in Storage.Inline
2. `Bit.Vector.Static<wordCount>` in Buffer.Slab uses wordCount as a misleading parameter name (it's actually element capacity passed to both bitmap and storage)
3. The narrowing from unbounded `Bit.Index` to `Bounded<capacity>` requires a runtime check (the `!`), which is safe when encapsulated in the invariant owner

If Swift adds value generic arithmetic in the future, `_slots: Bit.Vector.Static<(capacity + UInt.bitWidth - 1) / UInt.bitWidth>` would eliminate the hardcoded `4` and enable typed narrowing. Until then, the `!` inside invariant owners is the correct bridge.

## Outcome

**Status**: DECISION

**Choice**: Option F — Upgrade producers to yield bounded indices. Storage.Inline's bounded-only public API (per-slot operations) is correct. The fix is upgrading buffer types to produce bounded indices internally, not restoring unbounded on Storage.Inline.

### Design Principle

**Narrowing belongs inside the invariant owner.** Each layer that maintains an index invariant (bitmap occupancy, count ≤ capacity, modular arithmetic, free-list construction) narrows unbounded indices to bounded at its own boundary. Consumers never see unbounded; they receive bounded indices from the layer's API.

```
Bit.Vector.Static<4>.ones  →  Bit.Index (unbounded)
        ↓ (narrowing inside Header/Buffer — the invariant owner)
Header.forEachOccupied     →  Bit.Index.Bounded<capacity>
        ↓ (.retag — zero cost)
                               Index<Element>.Bounded<capacity>
        ↓ (passed to storage)
Storage.Inline.pointer(at:) ← Index<Element>.Bounded<capacity>  ✅
```

### Implementation Path

1. **Phase 1** (done): Storage.Inline has bounded-only public per-slot API
2. **Phase 2** (next): Upgrade buffer-primitives producers to yield bounded
3. **Phase 3** (optional): Add `Storage.Inline.forEachOccupied` for same-package convenience

The band-aid `Bounded(...)!` in Buffer.Slab.Inline deinit was a preview of where the narrowing belongs — inside the buffer type. But it should be encapsulated in `Header.forEachOccupied`, not at the deinit call site.

## References

- [IMPL-050]: Bounded Indices for Static-Capacity Types
- [IMPL-051]: Bounded Construction: Narrowing and Widening
- [IMPL-052]: Bounded Index Flow Through APIs
- Prior research: `per-slot-initialization-tracking.md`, `inline-bitvector-wordcount.md`
- Experiment: `double-tagged-bounded-index` (confirms retag on bounded types works)
- Experiment: `bitvector-slot-tracking` (confirms value generic arithmetic unavailable)
