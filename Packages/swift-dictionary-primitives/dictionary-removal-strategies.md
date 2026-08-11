# Dictionary Removal Strategies

<!--
---
version: 1.1.0
last_updated: 2026-02-24
status: DECISION
tier: 2
escalated_from: swift-io Research/io-events-primitives-alignment.md (F-4)
---
-->

## Context

The IO Events primitives alignment audit ([swift-io F-4](../../../swift-foundations/swift-io/Research/io-events-primitives-alignment.md)) identified that `Dictionary.Ordered` has O(n) removal, making it unsuitable for unordered maps with frequent removal — a pattern common in event loops, registries, and caches. The [dictionary-operations-audit](dictionary-operations-audit.md) (line 376) already notes this: "O(n) due to index shifting."

The canonical Dictionary/Map ADT expects O(1) average removal. `Dictionary.Ordered` delivers O(n) because insertion-order preservation requires shifting elements in the linear buffer. This is a principled consequence of the ordering invariant — not a bug. But the primitives ecosystem currently offers no dictionary variant optimised for the unordered, removal-heavy use case.

This document analyses why removal is O(n), evaluates three strategies to provide O(1) removal, and recommends a path forward.

## Question

Should swift-dictionary-primitives provide an O(1)-removal dictionary variant, and if so, what backing-store strategy should it use?

---

## Analysis

### Why Removal Is O(n)

`Dictionary.Ordered.remove(_:)` incurs two compounding costs, both rooted in the `Buffer.Linear` backing store:

**Cost 1 — Element shifting**: `Buffer.Linear.remove(at:)` calls `moveInitialize(from:count:)` to shift all subsequent elements left by one slot. This is O(n) where n is the number of elements after the removal point.

```
Before: [A, B, C, D, E]  remove(B)
After:  [A, C, D, E, _]  ← C, D, E shifted left
```

Source: `Buffer.Linear+Heap ~Copyable.swift:54-81`

**Cost 2 — Position update**: After shifting, the absolute positions stored in the hash table are stale. `Hash.Table.decrementAllPositions(after:)` scans every bucket to decrement positions greater than the removed index. This is O(bucket_capacity).

Source: `Hash.Table.Static+PositionUpdates.swift:13-29`

**Combined**: A single removal costs O(n + bucket_capacity). For k removals in a batch (e.g., an event loop draining waiters), total cost is O(k * (n + bucket_capacity)).

### Why This Is Principled for Dictionary.Ordered

The O(n) removal preserves two invariants:

1. **Insertion ordering**: Elements remain in the order they were inserted. Consumers iterating `keys` or `values` see a deterministic, stable order.
2. **Dense storage**: No gaps in the linear buffer. Iteration is a contiguous memory scan — cache-friendly and branch-free.

These invariants justify the cost for Dictionary.Ordered's use case: ordered key-value storage where iteration is frequent and removal is infrequent. Python 3.7+ `dict`, Rust's `indexmap` (shift-remove mode), and Swift Collections' `OrderedDictionary` make the same trade-off.

### Ecosystem Gap

The current ecosystem:

| Need | Available | Removal |
|------|-----------|---------|
| Ordered, ~Copyable values | `Dictionary.Ordered` | O(n) |
| Unordered, Copyable values | stdlib `Dictionary` | O(1) amortized |
| Unordered, ~Copyable values | **nothing** | — |

The third row is the gap. Any type managing ~Copyable resources in an unordered map (event registrations, connection pools, handle tables) has no O(1)-removal dictionary.

Even for Copyable values, consuming `Dictionary.Ordered` for an unordered map pays for ordering it never uses.

---

### Option A: Swap-Remove on Dictionary.Ordered

**Mechanism**: Instead of shifting, swap the removed element with the last element, then pop the last.

```
Before: [A, B, C, D, E]  swapRemove(B)
After:  [A, E, C, D, _]  ← E swapped into B's position
```

**Complexity**: O(1) — one swap, one position update (for the moved element), one decrement of count.

**Precedent**: Rust's `IndexMap::swap_remove()` provides this alongside `shift_remove()`. Both coexist on the same type. The caller chooses whether to preserve insertion order (shift, O(n)) or sacrifice it (swap, O(1)).

**Implementation sketch**:
```swift
extension Dictionary.Ordered where Key: Hash.Protocol, Value: ~Copyable {
    /// Removes the key-value pair, swapping the last entry into the gap.
    ///
    /// O(1) but does NOT preserve insertion order.
    /// The last-inserted key moves to the removed key's position.
    @discardableResult
    public mutating func swapRemove(_ key: Key) -> Value? {
        guard let removedPosition = _hashTable.remove(
            hashValue: key.hashValue,
            equals: { idx in _keys[idx] == key }
        ) else { return nil }

        let lastPosition = /* count - 1 */
        if removedPosition != lastPosition {
            // Swap last element into the gap
            _keys.swapAt(removedPosition, lastPosition)
            _values.swapAt(removedPosition, lastPosition)
            // Update hash table: the swapped element's position changed
            _hashTable.updatePosition(forHash: _keys[removedPosition].hashValue,
                                      equals: { $0 == lastPosition },
                                      newPosition: removedPosition)
        }
        // Pop the last element (now at lastPosition)
        _ = _keys.removeLast()
        return _values.removeLast()
    }
}
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Removal complexity | O(1) |
| New type required | No — method on existing Dictionary.Ordered |
| Ordering preserved | No — last element moves to gap |
| Dense storage | Yes — no gaps |
| Iteration order | Unpredictable after swap-removes |
| ~Copyable support | Yes (operates on existing variants) |
| Implementation effort | Small — requires `swapAt` on Buffer.Linear, one hash position update |

**Requires**: `Buffer.Linear.swapAt(_:_:)` and `Buffer.Linear.removeLast()`. Neither exists today — both are infrastructure gaps. `swapAt` is O(1) (two pointer operations). `removeLast` is O(1) (move last element, decrement count).

**Trade-off**: Simple, low-effort, no new types. But the type is still `Dictionary.Ordered` — the name promises ordering that `swapRemove` violates. Callers must know which removal method to use. Mixed usage (some `remove`, some `swapRemove`) produces surprising iteration order.

---

### Option B: Dictionary Backed by Buffer.Slab

**Mechanism**: Replace `Buffer.Linear` with `Buffer.Slab` as the backing store. Slab uses bitmap-tracked sparse storage — removal marks a bit as vacant without shifting.

```
Before: [A, B, C, D, E]  bitmap: 11111  remove(B)
After:  [A, _, C, D, E]  bitmap: 10111  ← gap at B's position
```

**Complexity**: O(1) — one `storage.move(at:)`, one bitmap flip. No position updates needed because positions are stable (nothing shifts).

**Implementation**:

A new type `Dictionary` (not `.Ordered`), composed of:
- `Hash.Table<Key>` — hash-to-position lookup (existing)
- `Buffer<Key>.Slab` — sparse key storage (existing)
- `Buffer<Value>.Slab` — sparse value storage (existing)

Removal:
1. Hash table: tombstone the bucket — O(1) (existing `Hash.Table.remove`)
2. Key slab: mark slot vacant — O(1) (existing `Buffer.Slab.remove`)
3. Value slab: mark slot vacant — O(1) (existing `Buffer.Slab.remove`)
4. **No `decrementAllPositions` call** — positions are stable

Insertion:
1. Find vacant slot — currently O(n) scan in `Buffer.Slab.firstVacant`. This is a known limitation; a free-list or popcount-based vacancy finder would make this O(1). Alternatively, hash table insertion already finds the right bucket — the slab slot can be the same index.
2. Initialize element in slab — O(1)
3. Insert into hash table — O(1) amortized

Iteration:
- `bitmap.ones.forEach { }` — visits only occupied slots, skips gaps. Uses Wegner/Kernighan bit iteration (popcount-based). O(count) work, O(capacity/64) bitmap words traversed.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Removal complexity | O(1) |
| New type required | Yes — `Dictionary` (unordered) |
| Ordering preserved | No ordering guarantee |
| Dense storage | No — sparse with bitmap-tracked gaps |
| Iteration order | Arbitrary (bitmap-determined) |
| Cache locality | Worse than linear — gaps reduce spatial locality |
| ~Copyable support | Yes (Buffer.Slab supports ~Copyable) |
| Implementation effort | Medium — new type composing existing primitives |

**Requires**: `Buffer.Slab` already exists. The main new work is the `Dictionary` type itself (composition + API surface). `firstVacant` scan is O(n) today — acceptable for now, improvable later with a free-list.

**Trade-off**: Clean type-level separation. `Dictionary.Ordered` = ordered, O(n) remove. `Dictionary` = unordered, O(1) remove. The name accurately reflects semantics. But adds a new type to maintain, and sparse storage has worse iteration cache behaviour than dense.

---

### Option C: Dictionary Backed by Buffer.Linked

**Mechanism**: Replace `Buffer.Linear` with `Buffer.Linked<2>` (doubly-linked list in arena). Removal unlinks the node without shifting.

**Complexity**: O(1) removal (unlink node), O(1) insertion (append to tail). Iteration follows link chain — O(n) but with pointer chasing (poor cache locality).

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Removal complexity | O(1) |
| Ordering preserved | Yes — link chain preserves insertion order |
| Dense storage | No — arena-allocated nodes |
| Cache locality | Worst — pointer chasing per element |
| ~Copyable support | Yes |
| Implementation effort | Medium-high — arena lifecycle, node management |

**Trade-off**: Preserves insertion order AND achieves O(1) removal, but at the cost of iteration performance. Event loop hot paths iterate frequently (draining waiters, processing events) — pointer chasing is a significant regression vs contiguous buffers.

---

### Comparison

| | Option A: Swap-Remove | Option B: Slab-Backed | Option C: Linked-Backed |
|---|---|---|---|
| Removal | O(1) | O(1) | O(1) |
| Insertion | O(1) amortized | O(1) amortized* | O(1) |
| Lookup | O(1) amortized | O(1) amortized | O(1) amortized |
| Iteration | O(n), contiguous | O(n), bitmap-guided | O(n), pointer-chasing |
| Cache locality | Best (dense) | Good (sparse, word-aligned) | Worst (pointer-chasing) |
| Ordering | Disrupted on remove | None | Preserved |
| New type | No | Yes | Yes |
| Effort | Small | Medium | Medium-high |
| Name clarity | Ambiguous (`.Ordered` but unordered after swap) | Clear (`Dictionary` vs `Dictionary.Ordered`) | Clear but niche |

\* `firstVacant` is O(n) scan today; improvable to O(1) with free-list.

---

## Prior Art

| Language/Library | Type | Removal Strategy | Complexity |
|-----------------|------|-----------------|------------|
| Rust `IndexMap` | Ordered hash map | `shift_remove()` O(n), `swap_remove()` O(1) | Both available |
| Rust `HashMap` | Unordered hash map | Tombstone, no backing array | O(1) |
| Rust `SlotMap` | Generational slab | Mark vacant, generation bump | O(1) |
| Python 3.7+ `dict` | Insertion-ordered | Tombstone in compact array | O(1) amortized* |
| Swift stdlib `Dictionary` | Unordered hash map | Tombstone in hash table | O(1) amortized |
| Swift Collections `OrderedDictionary` | Insertion-ordered | Shift elements | O(n) |

\* Python's dict uses a compact array with a separate sparse index table. Removal tombstones the compact array entry. Iteration skips tombstones. Periodic compaction reclaims space.

**Observation**: Rust provides both `shift_remove` and `swap_remove` on `IndexMap`, letting the caller choose. This is the lowest-effort approach that covers both use cases without a new type.

---

## Decision

**Primary investment: Dictionary (unordered, slab-backed) — Option B.**

Building an unordered `Dictionary` type supersedes the need for `swapRemove` on `Dictionary.Ordered`. The slab-backed type provides O(1) removal *and* clean type-level separation — the name accurately reflects semantics (`Dictionary` = unordered, `Dictionary.Ordered` = ordered), and there is no ambiguity from mixing removal strategies on a single type.

### Build Order

#### Phase 1: Buffer.Slab.firstVacant improvement

**Effort**: Small. **Impact**: Removes the O(n) per-bit scan bottleneck in `Buffer.Slab.Header.firstVacant`.

The current implementation scans individual bits. Word-level scanning — invert each `UInt` word, use `trailingZeroBitCount` — reduces this to O(capacity/64). The pattern already exists in `Bit.Vector.Protocol.popFirst()` and the `Zeros` iterators.

**Location**: `Buffer.Slab.Header.swift` in swift-buffer-primitives.

#### Phase 2: Dictionary (unordered, slab-backed)

**Effort**: Medium. **Impact**: Fills the ~Copyable ecosystem gap; provides O(1) removal for unordered maps.

A new type `Dictionary` composed of:
- `Hash.Table<Key>` — hash-to-position lookup (existing)
- `Buffer<Key>.Slab` — sparse key storage (existing)
- `Buffer<Value>.Slab` — sparse value storage (existing)

**Depends on**: Phase 1 (firstVacant improvement).

#### Phase 3: swift-io alignment

With the unordered Dictionary available, the IO Events module can evaluate migrating its five stdlib `Dictionary` instances. This depends on `Hash.Protocol` conformances for `IO.Event.ID`, `Permit.Key`, and `Reply.ID`.

### Deferred: swapRemove on Dictionary.Ordered (Option A)

`swapRemove` remains a valid future addition following Rust `IndexMap`'s dual-API pattern. However, the primary use cases (IO Events, connection pools) are unordered maps — Option B serves them directly without the naming ambiguity of an `.Ordered` type with order-disrupting removal. If a future use case requires both ordered iteration and occasional O(1) removal on the same collection, `swapRemove` can be revisited.

### Not recommended: Option C (Linked-Backed)

Pointer-chasing iteration is incompatible with event loop hot paths. The ordering preservation it offers over Option B does not justify the cache locality regression.

## References

- [dictionary-operations-audit](dictionary-operations-audit.md) — Line 376: "O(n) due to index shifting"
- [dictionary-discipline-boundary-analysis](dictionary-discipline-boundary-analysis.md) — Boundary between dictionary and lower layers
- [swift-io F-4](../../../swift-foundations/swift-io/Research/io-events-primitives-alignment.md) — Escalation source
- [Rust IndexMap](https://docs.rs/indexmap/latest/indexmap/) — `shift_remove()` / `swap_remove()` dual API
- [Rust SlotMap](https://docs.rs/slotmap/latest/slotmap/) — Generational slab with O(1) removal
- [IMPL-INTENT] — Code reads as intent, not mechanism
- [API-NAME-002] — No compound identifiers; nested accessor pattern
- `Hash.Table.Static+PositionUpdates.swift:34-44` — `updatePositionInternal` (existing, supports swap)
- `Buffer.Slab+Heap ~Copyable.swift:29-37` — O(1) slab removal via bitmap
- Arena buffer research: `swift-buffer-primitives/Research/arena-buffer-design.md:268` — swap-on-remove trade-off analysis
