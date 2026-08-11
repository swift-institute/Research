# Buffer.Ring Consumer API Boundary

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
---
-->

## Context

Queue-primitives is migrating from hand-rolled `Queue.Storage : ManagedBuffer` to `Buffer<Element>.Ring` from buffer-primitives. The migration stalled because `Buffer.Ring`'s stored properties (`header`, `storage`) and methods (`_makeUnique()`) are `package`-scoped, inaccessible from a separate SwiftPM package.

The naive fix - promoting internals to `public` - was rejected. `_makeUnique` should remain `package` at best. The correct approach: buffer-primitives handles all buffer concerns; queue-primitives is a thin semantic layer providing only queue vocabulary (enqueue/dequeue/peek).

## Question

What public API must `Buffer.Ring` (and its variants) provide so that consumers in separate SwiftPM packages can build data structures without accessing `header`, `storage`, or `_makeUnique()` directly?

## Analysis

### Inventory: What Buffer.Ring Already Provides (Public)

| Category | API | Available On |
|----------|-----|-------------|
| Init | `init(minimumCapacity:)` | Ring, Bounded, Inline, Small |
| Query | `count`, `isEmpty`, `capacity`, `isFull` | All variants |
| Mutation | `pushBack(_:)`, `popFront()` | All variants |
| Mutation | `pushFront(_:)`, `popBack()` | All variants |
| Mutation | `removeAll()` | All variants |
| Capacity | `reserveCapacity(_:)` | Ring, Small |
| Capacity | `compact()` | Ring |
| Peek | `peekFront`, `peekBack` | All variants (Copyable only) |
| CoW | `ensureUnique()` | Small (Copyable only) |
| Iteration | `Sequence.Protocol`, `Swift.Sequence` | Ring, Bounded, Inline (Copyable) |
| Consume | `Sequence.Consume.Protocol` | Ring, Bounded, Small |
| Drain | `Sequence.Drain.Protocol` | All variants |

### Inventory: What Queue Needs But Cannot Access

| Need | Current Queue Code | Why Internal Access? |
|------|-------------------|---------------------|
| CoW-safe Copyable mutations | `_makeUnique()` then `pushBack()` | `_makeUnique()` is `package` |
| Borrowing peek (~Copyable) | `storage.pointer(at: header.head)` | Needs `header` and `storage` |
| Element at logical index | `header.head + index.rawValue` via `storage.pointer()` | Physical slot computation + pointer |
| forEach (~Copyable) | `switch header.initialization { .one, .two }` | Wrap-around region traversal |
| Checkpoint save | `header.head.position`, `count` | Reads head position |
| Checkpoint restore | `header.head = ..., header.count = ...` | Writes head and count |
| CoW identity | `ObjectIdentifier(storage)` | Needs storage reference |

### Option A: Add Missing Public API to Buffer.Ring

Extend Buffer.Ring with public methods that encapsulate all internal knowledge. Queue calls only public API.

**A1. CoW-safe Copyable mutation overloads**

Buffer.Ring already has `pushBack` etc. for ~Copyable. Add Copyable overloads that call `_makeUnique()` internally:

```swift
// Buffer.Ring where Element: Copyable
public mutating func pushBack(_ element: consuming Element)   // calls _makeUnique() + base
public mutating func popFront() -> Element                    // calls _makeUnique() + base
public mutating func pushFront(_ element: consuming Element)  // calls _makeUnique() + base
public mutating func popBack() -> Element                     // calls _makeUnique() + base
public mutating func removeAll()                              // calls _makeUnique() + base
```

**Precedent**: `Buffer.Ring.Small` already provides exactly this pattern — Copyable overloads in `Buffer.Ring.Small Copyable.swift` that call `_heapBuffer!._makeUnique()` before mutation.

**A2. Borrowing element access for ~Copyable**

```swift
// Buffer.Ring where Element: ~Copyable
public func withFront<R>(_ body: (borrowing Element) -> R) -> R?
public func withBack<R>(_ body: (borrowing Element) -> R) -> R?
public func withElement<R>(at logicalIndex: Index<Element>, _ body: (borrowing Element) -> R) -> R
```

These encapsulate physical slot computation (`Index.Modular.physical`) and pointer access. Queue.peek delegates directly.

**A3. Subscript by logical index (Copyable)**

```swift
// Buffer.Ring where Element: Copyable
public subscript(logicalIndex: Index<Element>) -> Element {
    _read { /* physicalSlot + pointer */ }
    _modify { /* _makeUnique() + physicalSlot + pointer */ }
}
```

**A4. Borrowing forEach for ~Copyable**

```swift
// Buffer.Ring where Element: ~Copyable
public func forEach(_ body: (borrowing Element) -> Void)
```

Handles `header.initialization` switch internally — one region or two. Queue.forEach delegates directly.

**Precedent**: `Buffer.Linear` already provides subscript and forEach publicly. Ring is the missing piece.

**A5. Checkpoint save/restore**

```swift
// Buffer.Ring where Element: Copyable
public struct Checkpoint: Sendable, Comparable { ... }
public var checkpoint: Checkpoint
public mutating func restore(to checkpoint: Checkpoint)
```

Buffer owns the invariant that checkpoint restore must update `storage.initialization` to reflect the new head/count state.

**A6. CoW identity**

```swift
// Buffer.Ring where Element: Copyable
public var _identity: ObjectIdentifier { ObjectIdentifier(storage) }
```

Or via a protocol like `CoW.Identifiable`.

**A7. Apply same additions to Bounded, Inline, Small**

Each variant needs the same set of additions adapted to its storage model:

| Addition | Ring | Bounded | Inline | Small |
|----------|------|---------|--------|-------|
| CoW Copyable overloads | Add | Add | N/A (no CoW) | Already exists |
| withFront/withBack | Add | Add | Add | Add |
| withElement(at:) | Add | Add | Add | Add |
| subscript(logicalIndex:) | Add | Add | Add | Add |
| forEach (~Copyable) | Add | Add | Add | Add |
| Checkpoint | Add | Add | Add | Add |
| Identity | Add | Add | N/A (~Copyable) | N/A (~Copyable) |

**Pros**:
- Clean API boundary — buffer owns all buffer concerns
- Queue becomes truly thin (5-10 line delegating methods)
- No `package` → `public` promotion of internals
- Consistent with existing Linear patterns

**Cons**:
- ~15-20 new methods per variant (~60-80 methods total)
- Some methods are thin wrappers (forEach is substantive, peekFront is trivial)
- Checkpoint semantics are queue-specific, potentially awkward on buffer

### Option B: Move Queue Targets Into Buffer-Primitives Package

Make `swift-queue-primitives` targets part of `swift-buffer-primitives` so `package` access works.

**Pros**:
- Zero API changes to buffer-primitives
- `package` access works immediately
- Queue code stays as-written

**Cons**:
- Violates separation of concerns (buffer ≠ queue)
- Bloats buffer-primitives with consumer-specific types
- Sets bad precedent — should Stack, PriorityQueue also move in?
- Makes buffer-primitives harder to consume independently

### Option C: Hybrid — Public API + Package Escape Hatch

Add public API for common operations (A1-A4), but also provide a structured "expert access" pattern for advanced operations like checkpoint:

```swift
// Buffer.Ring
public mutating func withUnsafeHeader<R>(_ body: (inout Header) -> R) -> R
public borrowing func withUnsafeStorage<R>(_ body: (Storage<Element>.Heap) -> R) -> R
```

**Pros**:
- Covers 90% of needs with clean API
- Escape hatch for remaining 10% without promoting all internals
- `withUnsafe*` naming signals "you own the invariants"

**Cons**:
- Two access patterns is more complex than one
- `withUnsafeHeader` can break invariants if misused

### Comparison

| Criterion | Option A (Full API) | Option B (Same Package) | Option C (Hybrid) |
|-----------|--------------------|-----------------------|-------------------|
| API cleanliness | Excellent | N/A (unchanged) | Good |
| Separation of concerns | Excellent | Poor | Good |
| Implementation effort | Medium (~80 methods) | Zero | Low (~40 methods + escape) |
| Buffer invariant safety | Excellent | Depends on consumer | Good (escape hatch risks) |
| Extensibility to Stack, etc. | Excellent | Poor | Good |
| Follows existing patterns | Yes (Linear.Small) | N/A | Partially |

## Constraints

1. **Separate SwiftPM packages**: `swift-buffer-primitives` and `swift-queue-primitives` are separate packages. `package` access does not cross this boundary.
2. **~Copyable support**: All APIs must work with `~Copyable` elements. Borrowing/closure-based access is mandatory for element reads.
3. **Performance**: Ring buffer operations must remain O(1). No linearization for forEach or subscript.
4. **Existing patterns**: `Buffer.Linear` and `Buffer.Ring.Small` already provide subscripts, forEach, CoW-safe Copyable overloads. Ring/Bounded/Inline are the gaps.

## Outcome

**Status**: IN_PROGRESS

**Recommendation**: Option A (Full Public API).

Rationale:
- Buffer.Ring.Small and Buffer.Linear already demonstrate the exact patterns needed
- Queue becomes a true thin layer — each method is 1-3 lines delegating to buffer
- Buffer owns ALL buffer invariants (CoW, physical slots, wrap-around, initialization tracking)
- The effort is moderate because most additions follow established templates
- Other consumers (Stack, PriorityQueue) benefit from the same API surface

**Implementation order**:
1. A4 (forEach) — highest-intrusion gap, most code reduction in queue
2. A1 (CoW Copyable overloads) — eliminates all `_makeUnique()` calls from queue
3. A2 (withFront/withBack/withElement) — eliminates all pointer access from queue
4. A3 (subscript) — eliminates physical slot computation from queue
5. A5 (Checkpoint) — eliminates direct header mutation from queue
6. A6 (Identity) — minor, for testing only

## References

- `Buffer.Ring.Small Copyable.swift` — Demonstrates CoW-safe Copyable overload pattern
- `Buffer.Ring.Small.swift` — Demonstrates ~Copyable borrowing patterns
- `Buffer.Linear+Subscript.swift` — Demonstrates subscript by logical index on linear buffer
- `Buffer.Ring+Span.swift` — Demonstrates Iterator pattern with two-region wrap-around
- `Buffer.Ring.Inline Copyable.swift` — Demonstrates Iterator using `Index.Modular.physical`

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-10)
**New status**: DEFERRED

**Blocker/Reason**: Document recommends Option A (full public API additions to Buffer.Ring and variants) with a clear implementation order (A4 forEach, A1 CoW overloads, A2 withFront/withBack, A3 subscript, A5 checkpoint, A6 identity). The analysis is complete but implementation across ~80 methods across 4 variants has not been started. Deferred due to other priorities (leaf package audit, typed throws conversion, ~Copyable deinit workarounds).

**Resumption trigger**: When queue-primitives migration to Buffer.Ring resumes, or when buffer-primitives public API surface is next expanded.
