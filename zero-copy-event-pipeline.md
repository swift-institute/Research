# Zero-Copy Event Pipeline

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: RECOMMENDATION
tier: 2
---
-->

## Context

The swift-io deep audit (H-3 in [swift-io-deep-audit.md](swift-io-deep-audit.md)) identified a per-poll heap allocation in the event pipeline:

```swift
// IO.Event.Poll.Loop.swift:83
let batch = Array(eventBuffer.prefix(count))
eventBridge.push(.events(batch))
```

Every non-empty poll allocates a new `Array<IO.Event>` copying `count` events (up to 256 × 24 bytes = 6 KiB) from the pre-allocated buffer into a fresh heap allocation. The copy exists because:

1. The poll thread owns `eventBuffer` and reuses it across iterations
2. `Async.Bridge.push()` takes ownership of the pushed value
3. `IO.Event.Poll` is `enum { case events([IO.Event]); case tick }` — it owns the array

The selector iterates the array exactly once, dispatches per-handle per-interest, then discards it. The array's lifetime is a single event loop turn.

## Question

How can the event pipeline transfer events from the poll thread to the selector actor without per-poll heap allocation?

## Analysis

### Current Architecture

```
Poll Thread                    Selector Actor
───────────                    ──────────────
driver.poll(into: &eventBuffer)
  │
  ├─ Array(eventBuffer.prefix(count))  ← ALLOCATION
  │
  ├─ bridge.push(.events(batch))
  │     │
  │     └─ Mutex { Deque.push(poll) }  ← ownership transfer
  │
  │                                    await bridge.next()
  │                                      │
  │                                      ├─ for event in batch { processEvent(event) }
  │                                      │     └─ per-interest dispatch, waiter resume
  │                                      │
  │                                      └─ batch dropped (ARC → dealloc)
  │
  └─ eventBuffer reused next iteration
```

**Key observation**: The events flow through a producer→consumer pipeline where:
- Producer fills a fixed buffer (reused)
- Consumer reads each element exactly once
- Buffer lifetime is one poll→process cycle

This is the classic "bounded buffer pool" pattern.

### Option A: Memory.Pool — Pre-Allocated Buffer Slots

Use `Memory.Pool` to pre-allocate N event buffer slots. The poll thread checks out a slot, fills it with events, and hands the slot index to the selector. The selector reads events from the slot and returns it to the pool.

**Type changes**:

```swift
// New: Pooled event batch handle
extension IO.Event {
    /// A batch of events backed by a pooled memory buffer.
    ///
    /// The batch borrows from a `Memory.Pool`. The selector
    /// processes events and then returns the slot to the pool.
    public struct Batch: Sendable {
        /// Pool slot index for returning the buffer.
        public let slot: Index<Memory.Pool.Slot>

        /// Number of valid events in the buffer.
        public let count: Int

        /// Base pointer to the event array (valid for slot lifetime).
        public let base: UnsafePointer<IO.Event>
    }
}

// Replace IO.Event.Poll
extension IO.Event {
    public enum Poll: Sendable {
        case events(IO.Event.Batch)  // was: events([IO.Event])
        case tick
    }
}

// Bridge remains: Async.Bridge<IO.Event.Poll>
```

**Poll thread changes**:

```swift
// IO.Event.Poll.Loop.run()
let pool = Memory.Pool(
    slotSize: Memory.Address.Count(MemoryLayout<IO.Event>.stride * maxEvents),
    slotAlignment: Memory.Alignment(MemoryLayout<IO.Event>.alignment),
    capacity: poolCapacity  // e.g., 4 slots (pipeline depth)
)

while !shutdownFlag.isSet {
    processRequests(...)

    do {
        // Allocate a buffer slot from the pool
        let slot = try pool.allocateSlot()
        let base = pool.pointer(at: slot)
            .assumingMemoryBound(to: IO.Event.self)

        // Poll directly into the pooled buffer
        let count = try driver.poll(handle, deadline: deadline, into: base, capacity: maxEvents)

        if count > 0 {
            let batch = IO.Event.Batch(slot: slot, count: count, base: UnsafePointer(base))
            eventBridge.push(.events(batch))
        } else {
            // No events — return slot immediately
            pool.deallocate(at: slot)
            eventBridge.push(.tick)
        }
    } catch {
        eventBridge.finish()
        replyBridge.finish()
        break
    }
}
```

**Selector changes**:

```swift
// IO.Event.Selector.runEventLoop()
while let poll = await eventBridge.next() {
    switch poll {
    case .events(let batch):
        for i in 0..<batch.count {
            processEvent(batch.base[i])
        }
        // Return buffer to pool
        pool.deallocate(at: batch.slot)

    case .tick:
        break
    }
    drainCancelledWaiters()
    drainExpiredDeadlines(now: Kernel.Clock.Continuous.now())
}
```

**Allocation profile**: Zero per-poll allocations after init. Pool pre-allocates `poolCapacity × maxEvents × sizeof(IO.Event)` bytes at startup.

**Complexity**: Medium. Requires:
1. Pool shared between poll thread and selector (both own a reference)
2. `driver.poll()` API change to accept raw pointer + capacity (or keep `inout [IO.Event]` and memcpy once into pool slot)
3. `IO.Event.Poll` enum change (breaking)
4. Selector consumption change

### Option B: Ring Buffer — Single Shared Buffer with Read/Write Cursors

Use a single pre-allocated ring buffer shared between poll thread and selector. The poll thread writes events at the write cursor; the selector reads from the read cursor.

**Advantages**: Zero allocation, zero copy. Events are written once by the kernel and read once by the selector.

**Disadvantages**: Requires lock-free coordination (or Mutex-based cursor updates). The poll thread must not overwrite events the selector hasn't consumed yet. Back-pressure is implicit (poll blocks when ring is full). This is fundamentally a different concurrency model than the current bridge-based design.

**Complexity**: High. Replaces `Async.Bridge` entirely with a custom SPSC ring buffer. Loses the clean `push`/`next` abstraction.

### Option C: Swap Buffers — Double-Buffered Arrays

Use two pre-allocated arrays. The poll thread fills one while the selector processes the other. Swap atomically.

```swift
// Two pre-allocated buffers
var bufferA = [IO.Event](repeating: .empty, count: maxEvents)
var bufferB = [IO.Event](repeating: .empty, count: maxEvents)

// Poll fills bufferA, passes reference to selector
// Next poll fills bufferB while selector processes bufferA
// Swap on each cycle
```

**Advantages**: Simple, no pool management.

**Disadvantages**: Still requires ownership transfer across the bridge. `Array` is a value type with CoW — passing it through the bridge would trigger a copy unless we use unsafe pointers. Essentially degenerates into Option A with N=2.

**Complexity**: Low conceptually, but the bridge ownership model makes it equivalent to Option A.

### Option D: Bridge Redesign — Lend/Return Protocol

Redesign `Async.Bridge` to support a lend/return pattern where the producer lends a buffer reference and the consumer returns it after processing.

```swift
extension Async {
    /// Bridge that lends pooled buffers instead of transferring ownership.
    public final class PooledBridge<Element: Sendable>: @unchecked Sendable {
        /// Push a batch. Caller retains buffer ownership until selector returns it.
        public func push(buffer: UnsafeMutableBufferPointer<Element>, count: Int)

        /// Get next batch. Returns (buffer, count) or nil.
        /// Caller MUST call `release()` after processing.
        public func next() async -> (UnsafeBufferPointer<Element>, Int)?

        /// Return the buffer to the producer.
        public func release()
    }
}
```

**Advantages**: Clean abstraction. Decouples pool management from bridge protocol.

**Disadvantages**: New bridge primitive. `release()` must be called correctly (lifetime discipline). Not compatible with existing `Async.Bridge<Element>` API.

**Complexity**: High. New primitive in swift-async.

## Comparison

| Criterion | A: Memory.Pool | B: Ring Buffer | C: Swap Buffers | D: Bridge Redesign |
|-----------|---------------|----------------|-----------------|-------------------|
| Per-poll allocation | **Zero** | **Zero** | **Zero** | **Zero** |
| Per-poll copy | **Zero** (if driver API changed) or **1 memcpy** | **Zero** | **1 swap** | **Zero** |
| Concurrency model | Existing bridge | New SPSC ring | Existing bridge | New bridge |
| Breaking changes | `IO.Event.Poll` enum, `driver.poll()` | Replace bridge entirely | `IO.Event.Poll` enum | New bridge, `IO.Event.Poll` enum |
| Pool management | `Memory.Pool` (existing) | N/A | N/A | Internal to bridge |
| Back-pressure | Pool exhaustion → block/fail | Ring full → poll blocks | Swap contention | Internal to bridge |
| Complexity | **Medium** | High | Low→Medium | High |
| Primitives reuse | `Memory.Pool` from swift-memory-primitives | None | None | None |

## Constraints

1. **Poll thread is synchronous**: No `async` code. Must use `push()` (non-blocking).
2. **Selector is actor-isolated**: Receives events via `await bridge.next()`.
3. **Single-consumer invariant**: Only one task calls `next()`.
4. **Sendable boundary**: Anything crossing poll→selector must be `Sendable`.
5. **driver.poll() signature**: Currently `(Handle, deadline:, into: inout [IO.Event]) throws(IO.Event.Error) -> Int`. Changing to accept raw pointer is possible but affects all driver backends (kqueue, epoll, IOCP).
6. **Event lifetime**: Events are consumed exactly once per selector turn. No retention.

## Recommendation

**Option A: Memory.Pool** — with a phased approach.

### Phase 1: Pool + Bridge (No Driver API Change)

Keep `driver.poll(into: &eventBuffer)` unchanged. After polling, `memcpy` from `eventBuffer` into a pool slot. This eliminates the `Array` allocation (the current cost) while keeping the driver API stable.

```swift
// Phase 1: memcpy from stack buffer into pool slot
let count = try driver.poll(handle, deadline: deadline, into: &eventBuffer)
if count > 0 {
    let slot = try pool.allocateSlot()
    let dest = pool.pointer(at: slot).assumingMemoryBound(to: IO.Event.self)
    eventBuffer.withUnsafeBufferPointer { src in
        dest.initialize(from: src.baseAddress!, count: count)
    }
    eventBridge.push(.events(IO.Event.Batch(slot: slot, count: count, base: UnsafePointer(dest))))
}
```

**Cost**: One `memcpy` per poll (same as today's `Array(prefix:)` but no heap allocation). Pool pre-allocated at init.

### Phase 2: Direct-to-Pool Polling (Driver API Change)

Add a raw-pointer overload to `IO.Event.Driver`:

```swift
extension IO.Event.Driver {
    /// Poll directly into a raw buffer.
    public func poll(
        _ handle: borrowing Handle,
        deadline: Kernel.Clock.Deadline?,
        into buffer: UnsafeMutablePointer<IO.Event>,
        capacity: Int
    ) throws(IO.Event.Error) -> Int
}
```

Each backend (kqueue, epoll, IOCP) already writes into a buffer — this just changes where that buffer lives (pool slot instead of stack array).

**Cost**: Zero copy. Events written by kernel directly into pool slot.

### Pool Sizing

The pool needs enough slots to prevent the poll thread from blocking on pool exhaustion while the selector processes events:

| Pipeline depth | Slots | Memory (256 events × 24 bytes) |
|---------------|-------|-------------------------------|
| Single-buffered | 2 | 12 KiB |
| Double-buffered | 3 | 18 KiB |
| Deep pipeline | 4 | 24 KiB |

**Recommendation**: 4 slots (24 KiB). This allows 2 in-flight batches, 1 being processed by selector, and 1 spare. The bridge's internal `Deque` can buffer up to 2 pending poll results before the poll thread would block.

### Pool Ownership

`Memory.Pool` is `~Copyable` (move-only struct). Both the poll thread and selector need access:

**Option**: Wrap in a `final class PoolRef: @unchecked Sendable` that owns the `Memory.Pool` behind a `Mutex`. The poll thread calls `allocateSlot()` under the lock; the selector calls `deallocate(at:)` under the lock. Lock contention is minimal — each side holds the lock for O(1) slot operations, not during event processing.

```swift
/// Sendable wrapper for shared Memory.Pool access.
final class EventBufferPool: @unchecked Sendable {
    private let lock: Mutex<Memory.Pool>

    init(maxEvents: Int, poolCapacity: Int) throws {
        let pool = try Memory.Pool(
            slotSize: ...,
            slotAlignment: ...,
            capacity: ...
        )
        self.lock = Mutex(pool)
    }

    func allocateSlot() throws -> Index<Memory.Pool.Slot> {
        try lock.withLock { try $0.allocateSlot() }
    }

    func deallocate(at slot: Index<Memory.Pool.Slot>) {
        lock.withLock { try! $0.deallocate(at: slot) }
    }

    func pointer(at slot: Index<Memory.Pool.Slot>) -> UnsafeMutableRawPointer {
        lock.withLock { $0.pointer(at: slot) }
    }
}
```

### Type Changes Summary

| Type | Current | After |
|------|---------|-------|
| `IO.Event.Poll` | `enum { case events([IO.Event]); case tick }` | `enum { case events(IO.Event.Batch); case tick }` |
| `IO.Event.Batch` | N/A | `struct { slot, count, base }` (new) |
| `IO.Event.Bridge` | `Async.Bridge<IO.Event.Poll>` | Same (no change) |
| `IO.Event.Poll.Loop.run()` | `Array(prefix:)` copy | Pool allocate + memcpy (Phase 1) / direct poll (Phase 2) |
| `IO.Event.Selector.runEventLoop()` | `for event in batch` | `for i in 0..<batch.count { process(batch.base[i]) }; pool.deallocate(batch.slot)` |

### Files Changed

| File | Change |
|------|--------|
| `IO Events/IO.Event.Poll.swift` | Replace `events([IO.Event])` with `events(IO.Event.Batch)` |
| `IO Events/IO.Event.Batch.swift` | New file: `IO.Event.Batch` struct |
| `IO Events/IO.Event.Poll.Loop.swift` | Pool init + allocate/memcpy instead of Array copy |
| `IO Events/IO.Event.Selector.swift` | Pointer-based iteration + pool dealloc |
| `IO Events/IO.Event.Buffer.Pool.swift` | New file: `EventBufferPool` Sendable wrapper |
| Backend drivers (Phase 2 only) | Add raw-pointer `poll()` overload |

### Back-Pressure

If the pool is exhausted (selector falling behind):

- **Phase 1**: The poll thread blocks on `pool.allocateSlot()` until the selector returns a slot. This provides natural back-pressure — the poll thread can't outrun the selector by more than `poolCapacity` batches.
- **Alternative**: If blocking the poll thread is unacceptable, fall back to `Array` allocation when pool is exhausted. This degrades gracefully to current behavior under load.

## Outcome

**Status**: RECOMMENDATION

Option A (Memory.Pool) with phased rollout:
- **Phase 1**: Pool + memcpy. Eliminates per-poll `Array` allocation. No driver API change. Can be implemented entirely within swift-io.
- **Phase 2**: Direct-to-pool polling. Eliminates the memcpy. Requires driver API change across backends.

Phase 1 alone eliminates the hot-path allocation identified in H-3. Phase 2 is an optimization that removes the remaining memcpy.

## References

- [swift-io-deep-audit.md](swift-io-deep-audit.md) — H-3 finding and triage
- [foundations-dependency-utilization-audit.md](foundations-dependency-utilization-audit.md) — Previous dependency audit
- `Memory.Pool` — `/Users/coen/Developer/swift-primitives/swift-memory-primitives/Sources/Memory Pool Primitives/Memory.Pool.swift`
- `Async.Bridge` — `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Bridge.swift`
