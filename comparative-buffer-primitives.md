# Comparative Analysis: swift-buffer-primitives vs. swift-io Buffer/Pool Patterns

<!--
---
version: 1.0.0
date: 2026-02-24
scope: swift-buffer-primitives (Layer 1), swift-io (Layer 3)
status: DECISION
---
-->

## 1. Buffer-Primitives Type Catalog

### Buffer Primitives Core (`Buffer_Primitives_Core`)

| Type | Description |
|------|-------------|
| `Buffer<Element>` | Top-level namespace enum; generic over `Element: ~Copyable` |
| `Buffer.Growth` | Namespace for growth-related types |
| `Buffer.Growth.Policy` | Configurable growth strategy (doubling, factor, exact, pageAligned) |
| `Buffer.Aligned` | Alignment-constrained buffer |
| `Buffer.Unbounded` | Unbounded buffer type |

### Ring Discipline (`Buffer_Ring_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Ring` | Heap (`Storage.Heap`) | Growable | Double-ended ring with auto-growth. Push/pop front/back. |
| `Buffer.Ring.Bounded` | Heap (`Storage.Heap`) | Fixed | Fixed-capacity ring; push returns rejected element when full. |
| `Buffer.Ring.Header` | Value | N/A | Pure cursor/bookkeeping: head, count, capacity. |
| `Buffer.Ring.Header.Cyclic` | Value | Compile-time | Static-capacity header for inline ring buffers. |
| `Buffer.Ring.Checkpoint` | Value | N/A | Snapshot for save/restore of cursor state. |

### Ring Inline Discipline (`Buffer_Ring_Inline_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Ring.Inline<capacity>` | Stack (`Storage.Inline`) | Fixed (compile-time) | Stack-allocated bounded ring. Push returns rejected element. |
| `Buffer.Ring.Small<inlineCapacity>` | Inline then heap | Starts inline, spills | Small-buffer optimization: inline first, spills to heap `Buffer.Ring`. CoW for Copyable. |

### Linear Discipline (`Buffer_Linear_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Linear` | Heap (`Storage.Heap`) | Growable | Contiguous append-only buffer with remove/replace/swap. |
| `Buffer.Linear.Bounded` | Heap (`Storage.Heap`) | Fixed | Fixed-capacity contiguous buffer. |
| `Buffer.Linear.Header` | Value | N/A | Count + capacity bookkeeping. |

### Linear Inline Discipline (`Buffer_Linear_Inline_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Linear.Inline<capacity>` | Stack (`Storage.Inline`) | Fixed (compile-time) | Stack-allocated contiguous buffer. |
| `Buffer.Linear.Small<inlineCapacity>` | Inline then heap | Starts inline, spills | Small-buffer optimization for linear buffers. |

### Slab Discipline (`Buffer_Slab_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Slab.Bounded` | Heap (`Storage.Heap`) | Fixed | Sparse bitmap-indexed slot allocation. O(1) insert/remove by slot index. `firstVacant()` for allocation. |
| `Buffer.Slab.Bounded.Indexed<Tag>` | Heap (via base) | Fixed | Phantom-typed wrapper for tagged index domains. |
| `Buffer.Slab.Header` | Value | N/A | Bitmap + occupancy tracking. |

### Slab Inline Discipline (`Buffer_Slab_Inline_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Slab.Inline<wordCount>` | Stack (`Storage.Inline`) | Fixed (compile-time) | Stack-allocated slab with bitmap occupancy. |
| `Buffer.Slab.Small<wordCount>` | Inline then heap | Starts inline, spills | Small-buffer optimization for slab buffers. |

### Linked Discipline (`Buffer_Linked_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Linked<N>` | Pool (`Storage.Pool`) | Growable | Pool-backed doubly-linked list (N=2) or singly-linked (N=1). O(1) insert/remove front/back. |
| `Buffer.Linked.Header` | Value | N/A | Head, tail, count, sentinel. |
| `Buffer.Linked.Node` | Value | N/A | Element + InlineArray of N links. |

### Linked Inline Discipline (`Buffer_Linked_Inline_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Linked.Inline<capacity>` | Stack (`Storage.Inline`) | Fixed (compile-time) | Stack-allocated linked list with inline free-list. |
| `Buffer.Linked.Small<N, capacity>` | Inline then heap | Starts inline, spills | Small-buffer optimization for linked lists. |

### Arena Discipline (`Buffer_Arena_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Arena` | Heap (`Storage.Arena`) | Growable | Generation-token arena. O(1) alloc/free with LIFO free-list. Position handles for ABA-safe access. |
| `Buffer.Arena.Bounded` | Heap (`Storage.Arena`) | Fixed | Fixed-capacity arena with typed throws on exhaustion. |
| `Buffer.Arena.Header` | Value | N/A | Occupied count, highWater, freeHead, capacity. |
| `Buffer.Arena.Position` | Value | N/A | Slot index + generation token for validated access. |
| `Buffer.Arena.Meta` | Value | N/A | Per-slot metadata: token + free-list link. |
| `Buffer.Arena.Error` | Value | N/A | `invalidPosition`, `capacityExceeded`. |

### Arena Inline Discipline (`Buffer_Arena_Inline_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Arena.Inline<inlineCapacity>` | Stack (InlineArray) | Fixed (compile-time) | Stack-allocated arena with inline meta array. |
| `Buffer.Arena.Small<inlineCapacity>` | Inline then heap | Starts inline, spills | Small-buffer optimization for arenas. Spills to heap `Buffer.Arena`. |

### Slots Discipline (`Buffer_Slots_Primitives`)

| Type | Storage | Capacity | Description |
|------|---------|----------|-------------|
| `Buffer.Slots<Metadata>` | Heap (`Storage.Split`) | Fixed | Split-lane storage: co-located metadata + elements. SIMD-friendly metadata scanning. Swiss-table building block. |
| `Buffer.Slots.Header` | Value | N/A | Capacity tracking. |

---

## 2. swift-io Buffer/Pool Usage Analysis

### 2a. `IO.Event.Buffer.Pool` (IO Events module)

**Location**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO.Event.Buffer.Pool.swift`

**What it does**: Wraps `Memory.Pool` behind a `Mutex` for thread-safe event buffer allocation. The pool pre-allocates fixed-size slots where each slot holds `maxEvents * stride` bytes of `IO.Event` data.

**Current implementation**:
```swift
final class Pool: @unchecked Sendable {
    private let _pool: Mutex<Memory.Pool>

    init(maxEvents: Int, slotCount: Int = 4) throws {
        let pool = try Memory.Pool(
            slotSize: Memory.Address.Count(stride * maxEvents),
            slotAlignment: Memory.Alignment(alignment),
            capacity: Index<Memory.Pool.Slot>.Count(slotCount)
        )
        self._pool = Mutex(pool)
    }

    func allocateSlot() throws -> (Index<Memory.Pool.Slot>, UnsafeMutablePointer<IO.Event>)
    func deallocate(at slot: Index<Memory.Pool.Slot>)
}
```

**Key characteristics**:
- Untyped slot pool: each slot is raw bytes, reinterpreted as `IO.Event` array via `assumingMemoryBound`.
- Fixed slot count (default 4, the pipeline depth).
- Slots are **variable-length arrays** within a fixed-size slot: `maxEvents * stride` bytes per slot.
- Two operations: allocate slot (returns index + pointer), deallocate slot (by index).
- Thread-safe via Mutex.

### 2b. `IO.Event.Batch` (IO Events module)

**Location**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO.Event.Batch.swift`

**What it does**: Lightweight value type referencing a pool slot. Carries (slot index, count, base pointer). The poll thread creates a Batch after writing events into an allocated slot; the selector reads events via the base pointer, then returns the slot.

**Current implementation**:
```swift
struct Batch: @unchecked Sendable {
    let slot: Index<Memory.Pool.Slot>
    let count: Int
    let base: UnsafePointer<IO.Event>
}
```

**Key characteristics**:
- Zero-copy: pointer into pool-owned memory.
- Lifecycle: allocate slot -> write events -> create Batch -> pass through bridge -> read events -> deallocate slot.
- The Batch itself does no memory management.

### 2c. `IO.Executor.Slot.Pool` (IO module)

**Location**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.Executor.Slot.Pool.swift`

**What it does**: Pre-allocated pool of transaction slot memory. Identical pattern to `IO.Event.Buffer.Pool` but for executor transaction slots rather than event buffers.

**Current implementation**:
```swift
final class Pool: @unchecked Sendable {
    private let _pool: Mutex<Memory.Pool>

    init(resourceStride: Int, resourceAlignment: Int, slotCount: Int = 16) throws {
        let pool = try Memory.Pool(slotSize: ..., slotAlignment: ..., capacity: ...)
        self._pool = Mutex(pool)
    }

    func allocateSlot() throws -> (Index<Memory.Pool.Slot>, UnsafeMutableRawPointer)
    func deallocate(at slot: Index<Memory.Pool.Slot>)
}
```

**Key characteristics**:
- Fixed slot count (default 16).
- Returns raw pointers (not typed).
- Each slot holds one `Resource` instance.
- Fallback to heap allocation when pool is exhausted.

### 2d. `IO.Executor.Slot.Container` (IO module)

**Location**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.Executor.Slot.Container.swift`

**What it does**: Raw pointer lifecycle manager for temporarily holding a `~Copyable` resource during lane execution. Tracks initialization/consumption state with boolean flags.

**Current implementation**:
```swift
struct Container<Resource: ~Copyable & Sendable>: ~Copyable {
    private var raw: UnsafeMutableRawPointer?
    private var isInitialized: Bool = false
    private var isConsumed: Bool = false
    private var ownsMemory: Bool

    static func allocate() -> Self  // heap path
    static func allocate(from pointer: UnsafeMutableRawPointer) -> Self  // pool path
    mutating func initialize(with resource: consuming Resource)
    mutating func markInitialized()
    mutating func take() -> Resource
    mutating func deallocateRawOnly()
}
```

**Key characteristics**:
- Two-phase lifecycle: allocate -> initialize -> take -> deallocate.
- Tracks ownership of memory (pool-backed vs. heap-allocated).
- `~Copyable`-aware: uses `consuming` and `move()`.
- Manual state machine with boolean flags.

### 2e. `IO.Handle.Registry` (IO module)

**Location**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.Handle.Registry.swift`

**Key observation**: The registry stores handles in `Dictionary<IO.Handle.ID, IO.Executor.Handle.Entry<Resource>>`. While this uses Dictionary (covered by the dictionary-primitives analysis), the relevant buffer pattern here is the `transactionPool: IO.Executor.Slot.Pool` which provides pre-allocated memory for transaction slots.

---

## 3. Replacement Assessment

### 3a. Could `Buffer.Slab.Bounded` replace the `Memory.Pool` wrappers?

**Assessment: No — semantic and structural mismatch.**

The `Memory.Pool` and `Buffer.Slab.Bounded` superficially look similar: both provide O(1) allocate/deallocate with bitmap tracking and free-list reuse. However, the fundamental abstraction differs:

| Aspect | `Memory.Pool` | `Buffer.Slab.Bounded` |
|--------|--------------|----------------------|
| **Element type** | Untyped bytes (`UnsafeMutableRawPointer`) | Typed `Element` |
| **Slot size** | Runtime-configurable (bytes) | Compile-time fixed (`MemoryLayout<Element>.stride`) |
| **Use case** | Raw memory allocation (reinterpret-cast at call site) | Typed value container |
| **Thread safety** | None (composed externally via Mutex) | None |
| **Index domain** | `Index<Memory.Pool.Slot>` | `Bit.Index` |
| **Variable-length slots** | Yes (any slot size >= Index size) | No (one Element per slot) |

The critical blocker is **variable-length slots**. `IO.Event.Buffer.Pool` allocates slots of `maxEvents * MemoryLayout<IO.Event>.stride` bytes — each slot is an array of events, not a single value. `Buffer.Slab.Bounded` stores exactly one `Element` per slot. To replace `Memory.Pool`, you would need `Buffer.Slab.Bounded<[IO.Event]>`, which introduces heap allocation per element — defeating the entire point.

For `IO.Executor.Slot.Pool`, the slot size is `MemoryLayout<Resource>.stride` — exactly one element. This is closer to Slab's model. However, the pool operates on raw bytes because `Resource` is `~Copyable & Sendable` and the pool is generic over the resource type at a level that crosses `@Sendable` boundaries. The raw pointer escape-hatch is load-bearing for the container pattern.

**Verdict**: `Memory.Pool` is the correct primitive for IO's needs. The pool operates in a domain (untyped, variable-length raw memory reuse) that is intentionally below buffer-primitives' typed abstraction level.

### 3b. Could `Buffer.Ring.Inline` serve any event processing patterns?

**Assessment: No applicable use site found.**

The IO event processing pipeline does not use a ring buffer pattern. Events flow through a linear pipeline:
1. Driver fills a contiguous event buffer (array-shaped, not ring-shaped).
2. Buffer is passed as a `Batch` (base pointer + count) through a bridge.
3. Selector iterates events sequentially, dispatches each one.

There is no wrap-around, no head/tail cursor, no double-ended access. The event flow is strictly produce-once-consume-once linear.

If swift-io ever needed a bounded producer-consumer channel between the poll thread and selector (e.g., if the bridge became a ring buffer instead of a channel), `Buffer.Ring.Bounded` or `Buffer.Ring.Inline` would be the right primitive. But the current architecture uses `AsyncStream`-style channels, not ring buffers.

**Verdict**: No replacement opportunity. The ring buffer discipline does not match IO's event processing topology.

### 3c. Could `Buffer.Arena.Inline` replace `Slot.Container`'s raw pointer management?

**Assessment: No — fundamentally different problems.**

`Buffer.Arena.Inline` provides:
- Multi-slot storage with generation tokens for ABA-safe access.
- Free-list reuse across slots.
- Position handles that validate stale access.

`IO.Executor.Slot.Container` provides:
- **Single-slot** temporary storage for one `~Copyable` resource.
- Two-phase lifecycle (allocate -> initialize -> take -> deallocate).
- The ability to split the memory address from the ownership (address escapes as Sendable token; Container stays local).

The fundamental mismatch is that `Container` is a **one-shot ownership transfer mechanism**, not a collection. It exists to pass a `~Copyable` resource through an `@escaping @Sendable` closure boundary. The arena model (allocate slot -> store -> retrieve by position -> free) adds generation-token overhead for a single-use pattern that has no ABA risk by construction.

Furthermore, `Container` deliberately operates at the raw pointer level because it must cross `@Sendable` boundaries via an opaque `Address` token. Arena's typed `Position` handle does not solve this problem.

**Verdict**: No replacement opportunity. Container solves an ownership-transfer problem, not a collection problem.

### 3d. Could `Buffer.Arena.Bounded` replace the registry's handle storage?

**Assessment: Partial opportunity — worth investigating but blocked by current architecture.**

`IO.Handle.Registry` currently stores handles in `Dictionary<IO.Handle.ID, IO.Executor.Handle.Entry<Resource>>`. Each entry contains:
- The resource (optional, checked out during transactions)
- State enum (present/checkedOut/reserved/destroyed/pendingRegistration)
- Waiter queue for concurrent access

`Buffer.Arena.Bounded` provides:
- O(1) insert/remove by position
- Generation tokens for stale-access protection
- Stable slot indices

The arena model maps well to the registry concept: handles are allocated, accessed by position, and freed. The generation token could replace the scope + ID validation. However, several blockers exist:

1. **Entry richness**: Registry entries contain mutable state (waiters, state enum) alongside the resource. Arena stores one `Element` per slot — the entire `Entry` struct would need to be the element.
2. **Entry is a class**: `IO.Executor.Handle.Entry<Resource>` is a `class` to allow shared mutable references. Arena would store the class reference, not add value over the dictionary.
3. **Iteration by key**: The registry iterates `handles` during shutdown. Arena supports `forEach(occupied:)` but not key-based lookup.
4. **Small counts**: A typical registry holds handful to dozens of handles. Dictionary is adequate.

**Verdict**: Not a practical replacement. The arena model's strengths (generation tokens, O(1) alloc/free, stable indices) are interesting for handle registries in principle, but the current Entry-as-class design and Dictionary-based lookup make migration impractical without a larger architectural change.

---

## 4. General-Purpose Additions to Buffer-Primitives for IO's Needs

### 4a. `Buffer.Pool` — Typed Pool Primitive

**Opportunity: Medium. Not a replacement for Memory.Pool, but a higher-level complement.**

`Memory.Pool` operates at the untyped memory level. A `Buffer.Pool<Element>` could provide:
- Typed slot allocation returning `(Index<Element>, UnsafeMutablePointer<Element>)`.
- Automatic `MemoryLayout<Element>.stride` and `.alignment` from the generic parameter.
- Same free-list reuse and bitmap tracking as `Memory.Pool`.
- Value-type with `~Copyable` support.

This would not replace `IO.Event.Buffer.Pool` (which needs variable-length slots) but could replace `IO.Executor.Slot.Pool` where each slot holds exactly one `Resource`.

However, `Memory.Pool` already exists at a lower tier and serves this role when combined with `assumingMemoryBound`. The typing convenience may not justify a new buffer discipline.

**Recommendation**: Low priority. `Memory.Pool` is adequate.

### 4b. `Buffer.Slab.Bounded` with Mutex wrapper pattern

**Opportunity: None. IO already has the right abstraction.**

Both `IO.Event.Buffer.Pool` and `IO.Executor.Slot.Pool` are thin `Mutex<Memory.Pool>` wrappers that are IO-specific. Moving the Mutex wrapper into buffer-primitives would violate Layer 1's prohibition on importing Synchronization/concurrency primitives.

### 4c. Single-Slot Transfer Container

**Opportunity: None at the buffer-primitives level.**

`IO.Executor.Slot.Container` solves a concurrency ownership-transfer problem that belongs in the ownership/async-primitives layer, not in buffer-primitives. The existing `Ownership.Transfer.Cell` and `Ownership.Transfer.Storage` in `Ownership_Primitives` are the correct primitives for this pattern.

---

## 5. Summary

| IO Pattern | Buffer-Primitives Candidate | Verdict | Reason |
|------------|---------------------------|---------|--------|
| `IO.Event.Buffer.Pool` (Mutex\<Memory.Pool\>) | `Buffer.Slab.Bounded` | **No** | Untyped variable-length slots; below buffer-primitives' abstraction level |
| `IO.Event.Batch` (slot + count + pointer) | None | **No** | Lightweight reference type, not a container |
| `IO.Executor.Slot.Pool` (Mutex\<Memory.Pool\>) | `Buffer.Slab.Bounded` | **No** | Same Mutex\<Memory.Pool\> pattern; raw pointer escape is load-bearing |
| `IO.Executor.Slot.Container` (raw lifecycle) | `Buffer.Arena.Inline` | **No** | Ownership transfer, not collection; single-slot |
| Event ring/queue patterns | `Buffer.Ring.Inline` | **No** | IO uses linear produce-consume, not ring topology |
| Handle registry | `Buffer.Arena.Bounded` | **No (now)** | Entry-as-class + Dictionary lookup; arena model is interesting for future redesign |

**Overall finding**: swift-io's buffer/pool patterns operate at a fundamentally different abstraction level than swift-buffer-primitives. The IO patterns are:
1. **Untyped memory pools** (`Memory.Pool`) — below buffer-primitives' typed abstraction.
2. **Ownership transfer mechanisms** (`Slot.Container`) — a concurrency problem, not a collection problem.
3. **Linear event flows** — no ring or circular structure to exploit.

Buffer-primitives and Memory.Pool are properly layered: `Memory.Pool` is in `swift-memory-primitives` (lower tier), and `Buffer.Linked` already uses `Storage.Pool` (which wraps `Memory.Pool`) for its node allocation. The fact that IO reaches directly for `Memory.Pool` rather than through buffer-primitives is architecturally correct — IO needs raw memory management, not typed collection abstractions.

No code changes are recommended.
