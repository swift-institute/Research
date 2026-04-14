---
title: "Comparative Analysis: swift-Slab-primitives vs swift-io Slab/Pool Usage"
version: 1.0.0
status: DECISION
last_updated: 2026-02-24
---

# Comparative Analysis: swift-Slab-primitives vs swift-io Slab/Pool Usage

<!--
---
created: 2026-02-24
scope: swift-slab-primitives, swift-buffer-primitives, swift-memory-primitives, swift-io
status: DECISION
---
-->

## 1. Inventory: swift-Slab-primitives

### 1.1 Package Structure

**Location**: `https://github.com/swift-primitives/swift-slab-primitives`

Four modules organized in a layered structure:

| Module | Contents | Dependencies |
|--------|----------|--------------|
| `Slab Primitives Core` | `Slab<Element>`, `Slab.Static<wordCount>`, `Slab.Indexed<Tag>`, `Slab.Error` | Buffer Slab Primitives, Buffer Slab Inline Primitives, Index Primitives, Bit Primitives, Ownership Primitives, Property Primitives |
| `Slab Dynamic Primitives` | Copyable extensions: `Slab.peek(at:)`, `Slab.Indexed` drain conformance | Slab Primitives Core, Collection Primitives, Sequence Primitives |
| `Slab Static Primitives` | Copyable extensions: `Slab.Static.peek(at:)`, drain conformance | Slab Primitives Core, Buffer Slab Inline Primitives, Sequence Primitives |
| `Slab Primitives` | Umbrella re-export of all three | All above |

### 1.2 Public Types

#### `Slab<Element: ~Copyable>: ~Copyable`

Fixed-capacity, heap-backed typed slot storage with bitmap occupancy tracking.

- **Backing**: `Buffer<Element>.Slab.Bounded` (heap-allocated, `Bit.Vector` bitmap)
- **Indexing**: `Index<Element>` (typed phantom index)
- **Occupancy**: `Bit.Vector` with O(word) `firstVacant()` via `zeros.first(max:)`
- **Iteration**: O(count) via Wegner/Kernighan bit extraction on `bitmap.ones`

**Operations** (all `where Element: ~Copyable`):

| Operation | Complexity | Throws |
|-----------|-----------|--------|
| `init()` | O(1) | -- |
| `init(minimumCapacity:)` | O(n) alloc | -- |
| `occupancy` | O(popcount) | -- |
| `isEmpty`, `isFull` | O(popcount) | -- |
| `isOccupied(at:)` | O(1) | -- |
| `firstVacant()` | O(capacity/64) | -- |
| `insert(_:at:)` | O(1) | `.occupied` |
| `insert(_:__unchecked:)` | O(1) | -- |
| `insert(_:)` (auto) | O(capacity/64) | `.full` |
| `remove(at:)` | O(1) | `.vacant` |
| `remove(__unchecked:)` | O(1) | -- |
| `update(at:with:)` | O(1) | `.vacant` |
| `removeAll()` | O(count) | -- |
| `drain(_:)` | O(count) | -- |
| `peek(at:)` (Copyable only) | O(1) | -- |

#### `Slab.Static<let wordCount: Int>: ~Copyable`

Fixed-capacity, inline (stack-allocated) slab using `Buffer<Element>.Slab.Inline<wordCount>`.

- Compile-time capacity via generic value parameter
- Bounded indices: `Index<Element>.Bounded<wordCount>`
- Same operation set as `Slab`, with bounded index variants

#### `Slab.Indexed<Tag: ~Copyable>: ~Copyable`

Zero-cost phantom-typed wrapper over `Slab<Element>`.

- Consumer provides `Tag` type; indices are `Index<Tag>` instead of `Index<Element>`
- All operations delegate via `.retag()` (zero-overhead at runtime)
- Enables domain-specific indexing without type confusion

#### `Slab.Error`

```swift
public enum Error: Swift.Error, Sendable, Equatable {
    case full      // No vacant slot
    case vacant    // Slot not occupied
    case occupied  // Slot already occupied
}
```

### 1.3 Underlying Buffer Infrastructure

The slab primitives build on `Buffer Slab Primitives` and `Buffer Slab Inline Primitives` from `swift-buffer-primitives`:

| Type | Role |
|------|------|
| `Buffer<Element>.Slab` | Growable heap slab (header + storage) |
| `Buffer<Element>.Slab.Bounded` | Fixed-capacity heap slab |
| `Buffer<Element>.Slab.Bounded.Indexed<Tag>` | Phantom-typed bounded slab |
| `Buffer<Element>.Slab.Header` | Runtime bitmap header (`Bit.Vector`) |
| `Buffer<Element>.Slab.Header.Static<wordCount>` | Compile-time bitmap header |
| `Buffer<Element>.Slab.Inline<wordCount>` | Stack-allocated slab with inline storage |
| `Buffer<Element>.Slab.Small<inlineCapacity>` | Inline-to-heap spilling slab |
| `Buffer<Element>.Slab.Bounded.ConsumeState` | Class-based consuming iterator state |

Key features of the buffer layer:
- `Storage<Element>.Slab` manages the heap allocation and bitmap persistence
- Static operations (`insert`, `remove`, `update`, `firstVacant`, `deinitializeAll`) are defined on the `Buffer.Slab` namespace
- Bitmap uses `Bit.Vector` (dynamic) or `Bit.Vector.Bounded` (static)
- Iteration via `bitmap.ones.forEach` uses Wegner/Kernighan algorithm

---

## 2. Inventory: swift-io Slab/Pool Usage

### 2.1 `Slab<Entry>` in Acceptance Queue

**File**: `IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift` (line 58)

```swift
private var slots: Slab<Entry>
```

Where `Entry: ~Copyable` holds a move-only `Job.Instance`. This is the **only direct Slab import** in swift-io. Usage:

| Operation | Call Site | Purpose |
|-----------|-----------|---------|
| `Slab<Entry>(minimumCapacity:)` | `Queue.init(capacity:)` | Pre-allocate slots for bounded queue |
| `slots.firstVacant()` | `enqueue(ticket:job:deadline:)` | Find free slot for new job |
| `slots.insert(_:at:)` | `enqueue(ticket:job:deadline:)` | Store entry at slot |
| `slots.remove(at:)` | `dequeue()` | Take entry out of slot |
| `slots.remove(at:)` | `cancel(ticket:disposition:)` | Reclaim slot on cancellation |
| `slots.isFull` | `isFull` property | Backpressure check |
| `slots.drain { ... }` | `drain(_:)` | Shutdown: consume all entries |

The acceptance queue uses a three-plane architecture:
1. **Storage plane**: `Slab<Entry>` -- bitmap-tracked typed slots for `~Copyable` jobs
2. **Order plane**: `Queue<Ticket>.Fixed` -- FIFO sequence of ticket references
3. **Coordination plane**: `Dictionary<Ticket, Coordination>.Ordered.Bounded` -- O(1) cancel lookup

The slab primitive is an excellent fit here: move-only jobs require stable slot storage with O(1) insert/remove, and bitmap occupancy tracking replaces an external free list.

### 2.2 `Memory.Pool` in Slot.Pool (Transaction Slots)

**File**: `IO/IO.Executor.Slot.Pool.swift`

```swift
final class Pool: @unchecked Sendable {
    private let _pool: Mutex<Memory.Pool>
}
```

Wraps `Memory.Pool` behind a `Mutex` for pre-allocated transaction slot memory. Used in `IO.Handle.Registry` for the `transaction()` method to avoid per-transaction heap allocation.

| Operation | Call Site | Purpose |
|-----------|-----------|---------|
| `Memory.Pool(slotSize:slotAlignment:capacity:)` | `Pool.init(...)` | Pre-allocate 16 raw memory slots |
| `pool.allocateSlot()` | `allocateSlot()` | Get slot index + raw pointer |
| `pool.pointer(at:)` | `allocateSlot()` | Get raw pointer for slot |
| `pool.deallocate(at:)` | `deallocate(at:)` | Return slot to pool |

The allocated raw pointer is then passed to `Slot.Container<Resource>` which manages the typed lifecycle (initialize, access via address, take, deallocate).

### 2.3 `Memory.Pool` in Buffer.Pool (Event Buffers)

**File**: `IO Events/IO.Event.Buffer.Pool.swift`

```swift
public final class Pool: @unchecked Sendable {
    private let _pool: Mutex<Memory.Pool>
}
```

Same `Mutex<Memory.Pool>` pattern. Pre-allocates fixed-size event buffer slots for the poll loop, each holding `maxEvents * stride(IO.Event)` bytes.

| Operation | Call Site | Purpose |
|-----------|-----------|---------|
| `Memory.Pool(slotSize:slotAlignment:capacity:)` | `Pool.init(maxEvents:slotCount:)` | Pre-allocate 4 event buffer slots |
| `pool.allocateSlot()` | `allocateSlot()` | Get slot + typed event pointer |
| `pool.pointer(at:).assumingMemoryBound(to:)` | `allocateSlot()` | Cast to `UnsafeMutablePointer<IO.Event>` |
| `pool.deallocate(at:)` | `deallocate(at:)` | Return event buffer slot |

### 2.4 `Slot.Container<Resource>` (Raw Pointer Lifecycle)

**File**: `IO/IO.Executor.Slot.Container.swift`

```swift
internal struct Container<Resource: ~Copyable & Sendable>: ~Copyable {
    private var raw: UnsafeMutableRawPointer?
    private var isInitialized: Bool
    private var isConsumed: Bool
    private var ownsMemory: Bool
}
```

Hand-rolled raw pointer lifecycle manager with manual state tracking. Two allocation paths:
1. **Pool-backed**: `Container.allocate(from: pointer)` -- pool manages memory
2. **Heap-backed**: `Container.allocate()` -- container owns memory

Operations: `initialize(with:)`, `markInitialized()`, `take()`, `deallocateRawOnly()`, plus static methods `withResource(at:)` and `initializeMemory(at:with:)` that work through opaque address tokens.

### 2.5 `IO.Event.Batch` (Pool Slot Reference)

**File**: `IO Events/IO.Event.Batch.swift`

Sendable struct holding a pool slot index, event count, and base pointer. Crosses the poll-thread-to-selector boundary. The selector reads events via `base` pointer and returns the slot via `pool.deallocate(batch.slot)`.

---

## 3. Assessment

### 3.1 What Does Slab-primitives Offer Beyond What swift-io Already Uses?

**Already used well**: The acceptance queue correctly uses `Slab<Entry>` for its storage plane. This is the canonical use case -- move-only elements with bitmap occupancy, O(1) insert/remove at stable indices, and O(count) drain.

**Available but unused capabilities**:

| Capability | Slab Primitive | IO Status |
|------------|---------------|-----------|
| Typed phantom indexing | `Slab.Indexed<Tag>` | Not used -- `Slab<Entry>` uses `Index<Entry>` directly |
| Stack-allocated slab | `Slab.Static<wordCount>` | Not used -- all slabs are heap-allocated |
| Peek (non-destructive read) | `Slab.peek(at:)` | Not applicable (entries are `~Copyable`) |
| Update in place | `Slab.update(at:with:)` | Not used -- entries are moved, not updated |
| Unchecked operations | `insert(__unchecked:)`, `remove(__unchecked:)` | Not used -- checked variants preferred for safety |

The phantom-typed indexing (`Slab.Indexed<Tag>`) could provide type-level separation between acceptance slot indices and other index domains, but the current code is already well-structured with the coordination dictionary bridging the gap.

### 3.2 Could Slot.Container's Raw Pointer Management Be Replaced with a Typed Slab?

**Assessment: No -- the use cases are fundamentally different.**

`Slot.Container<Resource>` serves a very specific role: it bridges `~Copyable` resources across `@Sendable` closure boundaries during lane execution. Key constraints:

1. **Cross-thread address token**: The `Address` (encoded `UInt`) must be Sendable and passable through escaping closures. Slab's typed interface does not expose raw addresses.

2. **Two-phase lifecycle**: `Container` has distinct phases (allocate -> initialize -> access via address -> take -> deallocate) with different code running on different threads. The slab primitive assumes single-owner mutation.

3. **Static method access**: `Container.withResource(at:address)` and `Container.initializeMemory(at:address:with:)` use the opaque address token for lane-side access. This pattern requires raw pointer arithmetic, not typed slab access.

4. **Pool/heap fallback**: The container transparently switches between pool-backed (no memory ownership) and heap-backed (owns memory) allocation. This dual-path lifetime is outside slab's domain.

5. **Single-slot scope**: Each container holds exactly one resource for one transaction. A slab manages N slots. The container is conceptually a one-shot cell, not a collection.

**Verdict**: `Slot.Container` is a correctly-scoped ownership transfer mechanism, not a collection. Replacing it with a slab would add unnecessary abstraction without eliminating any unsafety.

### 3.3 Could Memory.Pool Wrappers Benefit from Slab-Based Allocation?

**Assessment: No -- `Memory.Pool` and `Slab` serve different abstraction levels.**

| Dimension | `Memory.Pool` | `Slab<T>` |
|-----------|---------------|-----------|
| Typing | Untyped (`UnsafeMutableRawPointer`) | Typed (`Element`) |
| Slot size | Runtime-determined (bytes) | Compile-time (`MemoryLayout<Element>`) |
| Free tracking | In-band free list (O(1) LIFO) | Bitmap scan (O(capacity/64)) |
| Double-free detection | `Bit.Vector` allocation bits | Bitmap occupancy |
| Thread safety | Consumer adds Mutex | Consumer adds Mutex |
| Element lifecycle | Consumer manages init/deinit | Slab manages init/deinit |

The `Memory.Pool` wrappers in swift-io (`Slot.Pool`, `Buffer.Pool`) operate on untyped memory specifically because:

1. **Event Buffer.Pool**: Each slot holds `maxEvents * stride(IO.Event)` bytes -- a dynamically-sized array, not a single typed element. `Slab<[IO.Event]>` would add an unnecessary indirection. The pool's job is to eliminate per-poll `Array` allocation by providing a fixed buffer of raw bytes that gets `memcpy`'d into.

2. **Slot.Pool**: Each slot holds one `Resource` but the Resource type is erased at the pool level (the pool is created once with stride/alignment parameters). The `Slot.Container` then casts via `assumingMemoryBound`. A `Slab<Resource>` would require the slab to be generic over `Resource`, but the pool is shared across all transactions regardless of resource type.

3. **Free list vs bitmap**: `Memory.Pool` uses an in-band LIFO free list (O(1) allocate from freed slots, O(1) deallocate). `Slab` uses bitmap scanning (O(capacity/64) for `firstVacant`). For the small capacities used (4 event slots, 16 transaction slots), the difference is negligible, but the pool's free list is architecturally simpler for pure allocate/deallocate workloads without iteration.

4. **No iteration needed**: Neither `Slot.Pool` nor `Buffer.Pool` ever iterates occupied slots. They only allocate and deallocate. The bitmap's `ones` iteration (slab's main advantage) goes unused.

**Verdict**: The `Memory.Pool` wrappers are correctly using untyped pool allocation for what is fundamentally a memory management concern, not a typed collection concern. Replacing with slab would add typing overhead without benefit.

### 3.4 General-Purpose Additions That Would Serve IO's Slot Management Patterns

After examining all usage sites, the slab and pool primitives are well-matched to their current roles. However, some observations about potential improvements:

#### 3.4.1 No Gaps Found

The acceptance queue's use of `Slab<Entry>` is idiomatic and correct. The `Memory.Pool` wrappers are correctly scoped for untyped memory management. The `Slot.Container` is a correctly-designed ownership transfer cell. No replacement opportunities exist.

#### 3.4.2 Potential Future Utility

If swift-io were to introduce additional bounded collections of `~Copyable` elements (e.g., a slab-backed ready queue, a connection pool with stable indices), `Slab.Indexed<Tag>` would be the natural choice for type-safe slot indexing across domains. The current acceptance queue could adopt `Slab.Indexed<Acceptance.Entry>` for extra type safety on the slot index, but this is aesthetic rather than functional.

---

## 4. Summary

| IO Component | Current Primitive | Replacement Candidate | Recommendation |
|-------------|-------------------|----------------------|----------------|
| `Acceptance.Queue.slots` | `Slab<Entry>` | -- | **Already using slab. Correct.** |
| `Slot.Pool` | `Mutex<Memory.Pool>` | `Slab<Resource>` | **No.** Untyped pool is correct for erased resource types. |
| `Buffer.Pool` | `Mutex<Memory.Pool>` | `Slab<IO.Event>` | **No.** Dynamic buffer sizing requires untyped pool. |
| `Slot.Container` | Manual raw pointer | Typed slab slot | **No.** Cross-thread address token pattern is outside slab's domain. |
| `Event.Batch` | Pool slot reference | -- | **No.** Correctly references pool slot by index. |

**Conclusion**: swift-io already uses slab-primitives where appropriate (acceptance queue). The Memory.Pool-based components operate at a different abstraction level (untyped memory management) and should not be replaced with typed slab primitives. No changes recommended.
