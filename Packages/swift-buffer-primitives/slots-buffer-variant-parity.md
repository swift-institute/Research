# Slots Buffer Variant Parity

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
research_tier: 1
applies_to: [swift-buffer-primitives, swift-hash-table-primitives]
normative: false
---
-->

## Context

Buffer.Ring, Buffer.Linear, Buffer.Linked, Buffer.Slab, and Buffer.Arena all follow a consistent internal pattern:

1. **Static methods** for core operations taking `header: inout Header` and `storage: Storage<...>` — the logic lives in static methods, instance methods delegate to them.
2. **`ensureUnique()` semantics** — checks `isKnownUniquelyReferenced`, copies if shared, returns `true` if a copy was made.
3. **`copy()` method** — produces an independent copy of the buffer with its own storage.

Buffer.Slots deviated from all three conventions. This was identified while aligning Buffer.Linked with the static method pattern (see [linked-cow-safe-overloads](linked-cow-safe-overloads.md)).

**Trigger**: [RES-012] Discovery — proactive consistency audit after aligning Buffer.Linked.

**Scope**: Package-specific (buffer-primitives + hash-table-primitives consumer).

## Question

Should Buffer.Slots be brought into alignment with the static method pattern and `ensureUnique()` convention used by all other buffer variants?

## Analysis

### Issue 1: `ensureUnique()` Semantics Were Inverted

Every buffer variant follows this contract:

```swift
// Ring, Linear, Linked, Arena, Slab
@discardableResult
public mutating func ensureUnique() -> Bool {
    if !isKnownUniquelyReferenced(&storage) {
        self = copy()
        return true   // copy WAS made
    }
    return false      // already unique
}
```

Buffer.Slots had:

```swift
// Slots — INVERTED (FIXED)
@discardableResult
public mutating func ensureUnique() -> Bool {
    isKnownUniquelyReferenced(&storage)
    // returned true = already unique (no copy), false = shared (no copy made either)
}
```

Two problems:
- **Return value was inverted**: `true` meant "already unique" instead of "copy was made."
- **No copy was performed**: The doc comment said "the caller is responsible for copying when `ensureUnique()` returns `false`." Every other variant handles the copy internally.

### Issue 2: No `copy()` Method

Ring, Linear, Linked, Arena all provide:

```swift
@usableFromInline
package func copy() -> Self
```

Buffer.Slots had no `copy()`. This was required to implement the standard `ensureUnique()`.

### Issue 3: Hash.Table Consumer Was Broken

`Hash.Table+ensureUnique.swift:28` called:

```swift
if !_buffer.isStorageUnique() {
```

`isStorageUnique()` did not exist on `Buffer.Slots`. Hash.Table worked around Buffer.Slots' non-standard `ensureUnique()` by implementing its own uniqueness check and manual copy — but the method it called didn't exist.

### Issue 4: Static Method Pattern

All other buffer variants extract core logic into static methods:

| Buffer | Static Methods File | Operations |
|--------|-------------------|-----------|
| Ring | `Buffer.Ring+Heap ~Copyable.swift` | pushBack, popFront, pushFront, popBack, deinitializeAll |
| Linear | `Buffer.Linear+Heap ~Copyable.swift` | append, removeFirst, remove(at:), replace(at:with:) |
| Linked | `Buffer.Linked+Pool ~Copyable.swift` | insertFront, insertBack, removeFront, removeBack, removeAll |
| Slab | `Buffer.Slab+Heap ~Copyable.swift` | insert, remove, update, forEachOccupied, deinitializeAll |
| Arena | `Buffer.Arena+Heap ~Copyable.swift` | allocate, insert, remove, forEach, deinitialize |
| **Slots** | `Buffer.Slots+Split ~Copyable.swift` | initialize, move, deinitialize, deinitializeAll |

### Comparison

| Criterion | Align | Keep as-is |
|-----------|-------|-----------|
| `ensureUnique()` contract | Matches all 5 other buffers | Inverted semantics, unique to Slots |
| `copy()` method | Consistent API surface | Missing |
| Hash.Table compile error | Fixed by adding proper `ensureUnique()` | Broken (`isStorageUnique()` undefined) |
| Static methods | Consistent file structure | One-liner delegations add indirection |
| Metadata-parametric-slots alignment | Matches proposed Layer 2 design | Diverges from planned architecture |
| Code complexity | Minimal — operations are trivial | Slightly less code |

## Outcome

**Status**: DECISION — IMPLEMENTED (v2.0.0)

All four issues resolved. Buffer.Slots now matches the pattern of all other buffer variants.

### Static Methods — IMPLEMENTED

Created `Buffer.Slots+Split ~Copyable.swift` with static methods for core element lifecycle operations:

```swift
Buffer.Slots.initialize(to:at:storage:)
Buffer.Slots.move(at:storage:)
Buffer.Slots.deinitialize(at:storage:)
Buffer.Slots.deinitializeAll(where:header:storage:)
```

Instance methods in `Buffer.Slots ~Copyable.swift` delegate to these statics. Slots' statics take `storage:` only (no `header: inout Header`) for the per-slot operations, since the header is immutable. The bulk `deinitializeAll` takes `header: Header` (not `inout`) for the capacity loop bound.

### Copy and `ensureUnique()` — IMPLEMENTED

Two tiers of copy support, reflecting Storage.Split's consumer-managed element lifecycle:

**`where Element: Copyable`** — predicate-based:
```swift
package func copy(where isOccupied: (Metadata) -> Bool) -> Self
public mutating func ensureUnique(where isOccupied: (Metadata) -> Bool) -> Bool
```

Metadata is bulk-copied (BitwiseCopyable). Elements are copied individually for occupied slots. The predicate matches the existing `deinitialize(where:)` pattern.

**`where Element: BitwiseCopyable`** — bulk copy:
```swift
package func copy() -> Self
public mutating func ensureUnique() -> Bool
```

Both metadata and element arrays are bulk-copied via `initialize(from:count:)`. No predicate needed — all bit patterns are valid for BitwiseCopyable types.

### Hash.Table — IMPLEMENTED

Hash.Table's manual copy logic (create new buffer, bulk-copy metadata via pointer, loop-copy payload via subscript) replaced with a single delegation:

```swift
public mutating func ensureUnique() -> Bool {
    _buffer.ensureUnique()
}
```

Hash.Table uses `Buffer<Int>.Slots<Int>` — both `Int` types are `BitwiseCopyable`, so the no-predicate `ensureUnique()` applies. CoW is now a buffer concern, not a data-structure concern.

### Files Changed

| File | Change |
|------|--------|
| `Buffer.Slots+Split ~Copyable.swift` | **Created** — static methods |
| `Buffer.Slots ~Copyable.swift` | **Rewritten** — instance methods delegate to statics |
| `Buffer.Slots Copyable.swift` | **Rewritten** — copy(), copy(where:), ensureUnique(), ensureUnique(where:) |
| `Hash.Table+ensureUnique.swift` | **Simplified** — delegates to `_buffer.ensureUnique()` |

## References

- [linked-cow-safe-overloads](linked-cow-safe-overloads.md) — trigger for this audit
- [buffer-variant-parity-analysis](buffer-variant-parity-analysis.md) — broader parity audit
- [metadata-parametric-slots](metadata-parametric-slots.md) — planned redesign with Layer 2 statics
