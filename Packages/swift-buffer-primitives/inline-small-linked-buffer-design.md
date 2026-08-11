# Inline and Small Linked Buffer Design

<!--
---
tier: 2
type: architecture-analysis
status: DECISION
date: 2026-02-11
applies_to: [Buffer.Linked.Inline, Buffer.Linked.Small]
---
-->

## Context

The dynamic and bounded `List.Linked` / `Queue.Linked` variants delegate to `Buffer<Element>.Linked<N>`, following the layered `storage <- buffer <- data structure` architecture. But the Inline and Small variants remain hand-rolled:

- **List.Linked.Inline**: Uses `InlineArray<capacity, Element?>` + `InlineArray<capacity, InlineArray<N, Int>>` with manual free-list (~330 lines)
- **List.Linked.Small**: Same inline fields + `_heap: Storage?` (old ManagedBuffer class) with dual-mode branching (~830 lines)
- **Queue.Linked.Inline/Small**: Thin wrappers over `List.Linked<1>.Inline/Small`

Other data structures (Stack, Array, Set.Ordered) follow the layered pattern — they compose `Buffer.*.Inline` / `Buffer.*.Small`. The linked variants are the exception.

**Goal**: Create `Buffer.Linked.Inline` and `Buffer.Linked.Small`, then refactor List/Queue Inline/Small to delegate.

## Question: Storage Strategy for Inline Linked Buffers

### Option A: `InlineArray<capacity, Node?>` (Status Quo)

Uses InlineArray for both element and link storage. Requires `Element: Copyable` because InlineArray's `init(repeating:)` requires Copyable.

Rejected:
- Requires `Element: Copyable` — loses ~Copyable support
- InlineArray `init(repeating:)` writes `nil` to all capacity slots on construction — O(capacity) even for empty lists
- The `Optional` wrapper wastes 1 byte per element (tag) and prevents move-only elements

### Option B: `Storage.Pool.Inline` (New Dedicated Type)

A new `Storage<Element>.Pool.Inline<capacity>` type combining Storage.Inline raw storage with Pool's free-list pattern.

Rejected:
- Over-engineering — only Buffer.Linked.Inline would use this type
- Adds a new type to `swift-storage-primitives` for a single consumer
- The free-list logic is simple enough to live at the buffer level

### Option C: `Storage<Node>.Inline<capacity>` + Buffer-Level Free-List (Chosen)

`Buffer.Linked.Inline` stores:
```swift
header: Header                           // reuses existing Header (head, tail, count, sentinel)
storage: Storage<Node>.Inline<capacity>  // @_rawLayout node storage + 256-bit bitmap
freeHead: Index<Node>                    // free-list head (buffer-managed)
nextUnused: Index<Node>                  // virgin slot cursor (buffer-managed)
```

Why this works:
- `Storage<Node>.Inline` provides raw storage + bitmap tracking + automatic deinit cleanup
- Free-list management lives at the buffer level (same pattern as Pool manages free-list for dynamic)
- In-band free-list: freed node slots store next-free index in raw bytes (`stride(Node) >= size(Index<Node>)`, since Node contains at least one `Index<Node>` link)
- Bitmap serves deinit (iterate `.ones` to find active nodes); free-list serves O(1) alloc/dealloc
- `Storage<Node>.Inline` supports `~Copyable` elements (uses `@_rawLayout`, not InlineArray)

### Option D: Bitmap-Scan Allocation (No Free-List)

Use only the bitmap from Storage.Inline — scan for the first zero bit to find a free slot.

Rejected:
- O(n/64) per allocation instead of O(1)
- Inconsistent with Pool pattern used by dynamic variant
- Performance degrades as capacity grows

## Decision

**Option C**: `Storage<Node>.Inline<capacity>` + buffer-level free-list.

## Capability Upgrade: ~Copyable Element Support

Current Inline/Small require `Element: Copyable` because they use `InlineArray<capacity, Element?>`. With `Storage<Node>.Inline` (which uses `@_rawLayout`), this restriction lifts:

| Variant | Current | After Refactoring |
|---------|---------|-------------------|
| `List.Linked.Inline` | Copyable only | **~Copyable supported** |
| `List.Linked.Small` | Copyable only | **~Copyable supported** |
| `Queue.Linked.Inline` | Copyable only | **~Copyable supported** |
| `Queue.Linked.Small` | Copyable only | **~Copyable supported** |

The Inline/Small variants get the same ~Copyable / Copyable split as the dynamic variant:
- `~Copyable` path: `consuming` insert, `-> Element?` remove, `peekFront { body }` closure
- `Copyable` path: `first`/`last` direct return, Sequence, Equatable, Hashable

## Buffer.Linked.Small Pattern

Follows `Buffer.Ring.Small` exactly:
```swift
_inlineBuffer: Inline<inlineCapacity>
_heapBuffer: Buffer<Element>.Linked<N>?
```

All operations check `_heapBuffer != nil` and route. After spill, all operations route to `_heapBuffer` permanently (never revert to inline).
