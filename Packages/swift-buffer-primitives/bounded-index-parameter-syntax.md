# Bounded Index Parameter Syntax for Buffer-Primitives

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
---
-->

## Context

Phase 1 made Storage.Inline's per-slot operations (`initialize`, `move`, `deinitialize`, `pointer`) accept only `Index<Element>.Bounded<capacity>` publicly (unbounded `pointer(at: Index<Element>)` is `package`-scoped). Phase 2's first pass fixed buffer-primitives compilation by wrapping every Storage.Inline call site:

```swift
storage.move(at: Index<Element>.Bounded<capacity>(slot.retag(Element.self))!)
```

This compiles but violates [IMPL-INTENT] — the narrowing expression is mechanism, not intent. The `.retag()` and the storage operation are intent; the `Index<Element>.Bounded<capacity>(...)!` wrapper is machinery.

## Question

How should bounded indices flow through buffer-primitives APIs to maintain **both** compile-time bounded safety **and** elegant syntax?

## Constraint

`.retag()` on bounded types preserves the bound. Confirmed by experiment `double-tagged-bounded-index`:

```
Bit.Index.Bounded<N>.retag(Element.self)  →  Index<Element>.Bounded<N>
```

This is zero-cost (same raw value, different phantom tag). The bound `N` lives in the `RawValue` (`Ordinal.Finite<N>`), not the `Tag`, so retagging the outer `Tag` from `Bit` to `Element` preserves it.

## Analysis

### Option A: Verbose Narrowing at Every Call Site (Current First-Pass)

Accept unbounded `Bit.Index` / `Index<Element>` in API. Narrow to bounded at every storage call.

```swift
// Slab
public static func remove<let capacity: Int>(
    at slot: Bit.Index,
    header: inout Header,
    storage: inout Storage<Element>.Inline<capacity>
) -> Element {
    let element = storage.move(at: Index<Element>.Bounded<capacity>(slot.retag(Element.self))!)
    header.bitmap[slot] = false
    return element
}
```

| Criterion | Rating |
|-----------|--------|
| [IMPL-INTENT] | Fails — narrowing is mechanism at every call site |
| [IMPL-050] | Partial — storage sees bounded, but API accepts unbounded |
| [IMPL-052] | Fails — bounded does not flow end-to-end |
| Syntax elegance | Poor — verbose narrowing repeated per storage operation |
| Single narrowing point | No — every storage call narrows independently |

### Option B: Bounded Parameters with Retag Preservation

Accept `Bit.Index.Bounded<capacity>` / `Index<Element>.Bounded<capacity>` in the API. Method body uses `.retag()` which preserves the bound. Bitmap/header access widens via `Bit.Index(slot)`.

```swift
// Slab
public static func remove<let capacity: Int>(
    at slot: Bit.Index.Bounded<capacity>,
    header: inout Header,
    storage: inout Storage<Element>.Inline<capacity>
) -> Element {
    let element = storage.move(at: slot.retag(Element.self))
    header.bitmap[Bit.Index(slot)] = false
    return element
}
```

| Criterion | Rating |
|-----------|--------|
| [IMPL-INTENT] | Passes — `.retag()` and `.move()` read as intent |
| [IMPL-050] | Passes — API accepts bounded |
| [IMPL-052] | Passes — bounded flows from parameter to storage |
| Syntax elegance | Excellent — method body is cleaner than pre-Phase-1 |
| Single narrowing point | Yes — narrowing is at the producer (`firstVacant()`), not here |
| Widening cost | `Bit.Index(slot)` for bitmap access — one widening per bitmap op |

### Option C: Bounded Statics, Unbounded Instance API

Static methods accept bounded. Instance methods accept unbounded from user, narrow once, delegate to static.

```swift
// Static — bounded
public static func remove<let capacity: Int>(
    at slot: Bit.Index.Bounded<capacity>,
    header: inout Header,
    storage: inout Storage<Element>.Inline<capacity>
) -> Element { ... }

// Instance — unbounded, narrows
public mutating func remove(at slot: Bit.Index) -> Element {
    let bounded = Bit.Index.Bounded<wordCount>(slot)!
    Self.remove(at: bounded, header: &header, storage: &storage)
}
```

| Criterion | Rating |
|-----------|--------|
| [IMPL-INTENT] | Mixed — statics clean, instance has one narrowing |
| [IMPL-050] | Partial — static accepts bounded, instance does not |
| [IMPL-052] | Partial — bounded starts at instance→static boundary |
| Syntax elegance | Good in statics, acceptable in instance |
| Backward compatibility | Better — instance API unchanged |

## Per-Buffer-Type Treatment

### Slab (Slot-Based, Sparse)

**Index type**: `Bit.Index` → becomes `Bit.Index.Bounded<wordCount>`

Slab operations are single-slot: insert, remove, update, peek. No shift loops. Option B applies cleanly to every method.

**Producers** that need upgrading:
- `firstVacant() -> Bit.Index.Bounded<wordCount>?` — narrows once inside (principled: header maintains bitmap invariant)

**Consumers** that accept bounded:
- `insert(at: Bit.Index.Bounded<wordCount>)`
- `remove(at: Bit.Index.Bounded<wordCount>) -> Element`
- `update(at: Bit.Index.Bounded<wordCount>, with:) -> Element`
- `peek(at: Bit.Index.Bounded<wordCount>) -> Element`
- `isOccupied(at: Bit.Index.Bounded<wordCount>) -> Bool`

**Method body pattern**:
```swift
public mutating func insert(_ element: consuming Element, at slot: Bit.Index.Bounded<wordCount>) {
    storage.initialize(to: consume element, at: slot.retag(Element.self))
    header.bitmap[Bit.Index(slot)] = true
}
```

**Syntax comparison**:
```
BEFORE (Option A):  storage.initialize(to: element, at: Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!)
AFTER  (Option B):  storage.initialize(to: element, at: slot.retag(Element.self))
```

The narrowing moves from every storage call to one point: `firstVacant()`.

### Linear (Position-Based, Contiguous)

**Index type**: `Index<Element>` → becomes `Index<Element>.Bounded<capacity>`

Linear has two categories:

**Single-slot operations** — Option B applies directly:
- `replace(at: Index<Element>.Bounded<capacity>, with:) -> Element`
- Subscript `[Index<Element>.Bounded<capacity>]`
- `swap(at: Index<Element>.Bounded<capacity>, with: Index<Element>.Bounded<capacity>)`

```swift
public static func replace<let capacity: Int>(
    at index: Index<Element>.Bounded<capacity>,
    with newElement: consuming Element,
    storage: inout Storage<Element>.Inline<capacity>
) -> Element {
    let old = storage.move(at: index)
    storage.initialize(to: consume newElement, at: index)
    return old
}
```

The bounded index passes directly to storage — zero narrowing.

**Shift operations** — partial benefit:
- `remove(at:)` — element at `index` is directly movable via bounded, but the shift loop traverses subsequent positions. Loop variables use unbounded `Index<Element>` for total arithmetic (`+= .one`), narrowing per iteration for storage access.
- `removeFirst()` — no user-provided index; internal narrowing from count-derived positions.

```swift
public static func remove<let capacity: Int>(
    at index: Index<Element>.Bounded<capacity>,
    header: inout Header,
    storage: inout Storage<Element>.Inline<capacity>
) -> Element {
    let element = storage.move(at: index)           // bounded — direct ✓
    var src = Index<Element>(index) + .one           // widen for total arithmetic
    var dst = Index<Element>(index)
    let end = header.count.map(Ordinal.init)
    while src < end {
        // Loop body still narrows — inside invariant owner, acceptable
        let moved = storage.move(at: Index<Element>.Bounded<capacity>(src)!)
        storage.initialize(to: consume moved, at: Index<Element>.Bounded<capacity>(dst)!)
        src += .one
        dst += .one
    }
    header.count = header.count.subtract.saturating(.one)
    return element
}
```

The shift loop narrowing is acceptable: it's inside the invariant owner (`Buffer.Linear`), count ≤ capacity guarantees all loop indices are valid, and the loop is an implementation detail invisible to consumers.

**Future improvement**: A `Storage.Inline.moveElement(from:to:)` accepting two bounded indices, or range-based shift, would eliminate loop narrowing. Out of scope for this decision.

**Internal producers** (no user-provided index):
- `append` — narrows from `header.count.map(Ordinal.init)`, one point
- `consumeBack` — narrows from `(count - 1).map(Ordinal.init)`, one point

### Ring (Modular, Circular)

**Index type**: `Index<Element>` (logical position, 0 = front)

Ring's unique property: **logical indices** (user-facing, in [0, count)) differ from **physical indices** (storage-facing, in [0, capacity)). The modular conversion is the natural narrowing boundary.

**Approach**: Keep logical indices unbounded in public API (count is dynamic, no compile-time bound). Upgrade `Index.Modular.physical()` to return `Index<Element>.Bounded<capacity>`.

```swift
// Index.Modular returns bounded physical index
static func physical<let capacity: Int>(
    forLogical index: Index<Element>,
    head: Index<Element>,
    capacity: Index<Element>.Count
) -> Index<Element>.Bounded<capacity> {
    let raw = (Index<Element>(head).rawValue.rawValue + index.rawValue.rawValue) % capacity.rawValue.rawValue
    return Index<Element>.Bounded<capacity>(Index<Element>(Ordinal(raw)))!
}
```

Then Ring methods pass the bounded physical index directly to storage:
```swift
public static func pushBack<let capacity: Int>(
    _ element: consuming Element,
    header: inout Header,
    storage: inout Storage<Element>.Inline<capacity>
) {
    let tail = Index.Modular.advanced(header.head, by: header.count, capacity: header.capacity)
    storage.initialize(to: consume element, at: tail)  // bounded — direct ✓
    header.count += .one
}
```

One narrowing point: inside `Index.Modular` (the modular arithmetic invariant owner). All storage operations receive bounded.

**Subscript**: Logical index from user → `Index.Modular.physical()` → bounded physical → storage.

### Linked (No Public Index API)

**Index type**: `Index<Node>` (internal slot indices) — no public index exposure.

All index operations are internal. The pattern is:

- `_allocateSlot() -> Index<Node>.Bounded<capacity>` — narrows from free-list/virgin cursor
- `_deallocateSlot(_ slot: Index<Node>.Bounded<capacity>)` — accepts bounded
- `header.head` / `header.tail` remain unbounded `Index<Node>` (shared with Heap variant)
- Internal methods that access storage: narrow from `header.head` → bounded

```swift
func _allocateSlot() throws(Error) -> Index<Node>.Bounded<capacity> {
    if let freeSlot = header.freeHead {
        let bounded = Index<Node>.Bounded<capacity>(freeSlot)!  // one narrowing point
        ...
        return bounded
    }
    let slot = header.nextUnused
    let bounded = Index<Node>.Bounded<capacity>(slot)!  // one narrowing point
    ...
    return bounded
}
```

**forEach** and traversal: header.head is unbounded, narrow once per traversal start. Link traversal reads `node.links[0]` (unbounded `Index<Node>`), narrows per node access. Acceptable — inside invariant owner.

**Future improvement**: Store `Index<Node>.Bounded<capacity>` in header and node links. This eliminates all per-traversal narrowing but requires parameterizing Header/Node by capacity. Deferred — structural change beyond current scope.

## Comparison

| Criterion | A (verbose narrowing) | B (bounded params) | C (bounded statics) |
|-----------|-----------------------|---------------------|----------------------|
| [IMPL-INTENT] | Fails | **Passes** | Mixed |
| [IMPL-050] | Partial | **Full** | Partial |
| [IMPL-052] | Fails | **Passes** | Partial |
| Slab syntax | `Index<Element>.Bounded<capacity>(slot.retag(Element.self))!` | `slot.retag(Element.self)` | Same as B in statics |
| Linear single-slot | `Index<Element>.Bounded<capacity>(index)!` | `index` (direct) | Same as B in statics |
| Linear shift loop | Narrows per iteration | Narrows per iteration | Same |
| Ring | Narrows per modular result | Direct from `physical()` | Same |
| Linked | Narrows per header access | Narrows per header access | Same |
| Narrowing points | Every storage call | Producers only | Instance→static boundary |
| API change | None | Parameter types change | Statics change, instances don't |

## Outcome

**Status**: RECOMMENDATION

**Choice**: Option B — Bounded parameters with retag preservation.

### Design Principle

**Accept bounded at the API boundary. Let `.retag()` carry the bound to storage.**

The key insight: `.retag()` on bounded types is zero-cost type-level transformation that preserves the bound. By accepting bounded parameters, method bodies use `.retag()` naturally — the same operation that existed pre-Phase-1, with the same syntax, but now carrying compile-time proof.

### Application Summary

| Buffer | Public API Change | Narrowing Points | Method Body |
|--------|-------------------|-------------------|-------------|
| **Slab** | `Bit.Index` → `Bit.Index.Bounded<wordCount>` | `firstVacant()` only | `slot.retag(Element.self)` — direct |
| **Linear** (single-slot) | `Index<Element>` → `Index<Element>.Bounded<capacity>` | Internal producers (`append`, `consumeBack`) | `index` — direct pass-through |
| **Linear** (shift ops) | `Index<Element>` → `Index<Element>.Bounded<capacity>` | Internal producers + loop body | Entry: direct; loop: narrows (acceptable inside invariant owner) |
| **Ring** | Logical stays `Index<Element>`; physical returns `Bounded<capacity>` | `Index.Modular.physical()` only | Physical index — direct |
| **Linked** | No public change (no public index API) | `_allocateSlot()`, header access | Bounded from allocator — direct |

### Widening Pattern

Bitmap and header operations that accept unbounded indices use widening:
```swift
header.bitmap[Bit.Index(slot)] = true   // widen bounded → unbounded for bitmap
```

Widening is always safe per [IMPL-051]. One widening per bitmap access, reads clearly.

### Implementation Path

1. Upgrade Slab.Inline: Change all parameter types to `Bit.Index.Bounded<wordCount>`, simplify bodies
2. Upgrade Slab static methods: Same, using `Bit.Index.Bounded<capacity>`
3. Upgrade Linear.Inline: Subscript, replace, swap — direct pass-through; remove — bounded entry + loop narrowing
4. Upgrade Ring: `Index.Modular.physical()` returns bounded
5. Upgrade Linked: `_allocateSlot()` returns bounded, internal methods chain
6. Upgrade producers: `firstVacant()` returns `Bit.Index.Bounded<wordCount>?`

### What This Does NOT Change

- Range-based operations (`deinitialize(range:)`, `move(range:to:)`) — stay `Range<Index<Element>>`, package-scoped
- Heap storage operations — unchanged, accept unbounded
- `Storage.Inline.deinitialize.all()` — no index parameter
- Linear shift loop internals — still narrow per iteration (infrastructure improvement deferred)

## References

- [IMPL-050]: Bounded Indices for Static-Capacity Types
- [IMPL-051]: Bounded Construction: Narrowing and Widening
- [IMPL-052]: Bounded Index Flow Through APIs
- [IMPL-INTENT]: Code Reads as Intent, Not Mechanism
- Prior research: `swift-storage-primitives/Research/bounded-unbounded-storage-inline-api.md` v2.0.0
- Experiment: `double-tagged-bounded-index` — confirms retag preserves bound
