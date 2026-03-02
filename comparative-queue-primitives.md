# Comparative Analysis: swift-queue-primitives vs. swift-io Queue Usage

<!--
---
version: 1.0.0
date: 2026-02-24
scope: swift-queue-primitives, swift-io
type: replacement-opportunity analysis
---
-->

## 1. swift-queue-primitives Catalog

### 1.1 Package Structure

**Location**: `/Users/coen/Developer/swift-primitives/swift-queue-primitives/`

Seven internal modules re-exported via `Queue_Primitives`:

| Module | Contents |
|--------|----------|
| `Queue_Primitives_Core` | Type declarations, `Queue<E>`, `Queue.Fixed`, `Queue.Static`, `Queue.Small`, `Queue.DoubleEnded`, `Queue.DoubleEnded.Fixed`, `Queue.DoubleEnded.Static`, `Queue.DoubleEnded.Small`, `Queue.Linked`, `Queue.Linked.Fixed`, `Queue.Linked.Inline`, `Queue.Linked.Small` |
| `Queue_Dynamic_Primitives` | `Queue` operations: CoW, Sequence, Collection, Input.Protocol, drain |
| `Queue_Fixed_Primitives` | `Queue.Fixed` operations: bounded enqueue (throws overflow), Sequence, Input.Protocol, drain |
| `Queue_Static_Primitives` | `Queue.Static<capacity>` operations: inline storage, no heap, throws overflow |
| `Queue_Small_Primitives` | `Queue.Small<inlineCapacity>` operations: SmallVec pattern, spills to heap |
| `Queue_Linked_Primitives` | `Queue.Linked`, `Queue.Linked.Fixed`, `Queue.Linked.Inline<capacity>`, `Queue.Linked.Small<inlineCapacity>` operations |
| `Queue_DoubleEnded_Primitives` | `Queue.DoubleEnded` (aliased as `Deque`), `.Fixed`, `.Static<capacity>`, `.Small<inlineCapacity>` operations |

### 1.2 Type Catalog

#### FIFO Queues (single-ended)

| Type | Storage | Capacity | `~Copyable` Elements | `~Copyable` Container |
|------|---------|----------|---------------------|-----------------------|
| `Queue<E>` | Ring buffer (heap) | Dynamic, grows 2x | Yes | Conditionally |
| `Queue<E>.Fixed` | Ring buffer (heap) | Fixed, throws overflow | Yes | Conditionally |
| `Queue<E>.Static<N>` | Inline (InlineArray) | Compile-time fixed | Yes | Always ~Copyable |
| `Queue<E>.Small<N>` | Inline, spills to heap | Grows from inline | Yes | Always ~Copyable |
| `Queue<E>.Linked` | Arena-linked nodes | Dynamic | Yes | Conditionally |
| `Queue<E>.Linked.Fixed` | Arena-linked nodes | Fixed, throws overflow | Yes | Conditionally |
| `Queue<E>.Linked.Inline<N>` | Inline linked | Compile-time fixed | No (requires Copyable) | Always ~Copyable |
| `Queue<E>.Linked.Small<N>` | Inline linked, spills | Grows from inline | No (requires Copyable) | Always ~Copyable |

#### Double-Ended Queues (deques)

| Type | Storage | Capacity | `~Copyable` Elements | `~Copyable` Container |
|------|---------|----------|---------------------|-----------------------|
| `Queue<E>.DoubleEnded` / `Deque<E>` | Ring buffer (heap) | Dynamic, grows 2x | Yes | Conditionally |
| `Queue<E>.DoubleEnded.Fixed` | Ring buffer (heap) | Fixed, throws overflow | Yes | Conditionally |
| `Queue<E>.DoubleEnded.Static<N>` | Inline (InlineArray) | Compile-time fixed | Yes | Always ~Copyable |
| `Queue<E>.DoubleEnded.Small<N>` | Inline, spills to heap | Grows from inline | Yes | Always ~Copyable |

### 1.3 Common Operations (all types)

| Operation | FIFO Queue | DoubleEnded |
|-----------|-----------|-------------|
| Add | `enqueue(_:)` | `push(_:to: .front/.back)` |
| Remove | `dequeue() -> E?` | `pop(from: .front/.back) -> E?` |
| Peek (Copyable) | `peek() -> E?` | `peek(at: .front/.back) -> E?` |
| Peek (~Copyable) | `peek { borrowing E in }` | `peek(at:) { borrowing E in }` |
| Clear | `clear()` / `clear(keepingCapacity:)` | `clear()` / `clear(keepingCapacity:)` |
| Count | `count`, `isEmpty` | `count`, `isEmpty` |
| Full (bounded) | `isFull` | `isFull` |
| Iterate | `forEach(_:)` | `forEach(_:)` |
| Drain | `drain { consuming E in }` | `drain { consuming E in }` |
| Accessor | — | `front.push(_:)`, `front.take`, `back.push(_:)`, `back.take` |

### 1.4 What Queue-Primitives Does NOT Provide

1. **No thread-safe / synchronized queues** — No `Mutex<Queue>` wrapper, no MPSC/MPMC/SPSC.
2. **No composite queues** — No multi-plane structures (Slab + Order + Dictionary).
3. **No priority queues** — These are in `swift-heap-primitives`.
4. **No cancellation / ticket-based lookup** — Pure data structures only.
5. **No deadline tracking** — No integrated min-heap support.

---

## 2. swift-io Queue Usage Sites

### 2.1 `IO.Event.Registration.Queue` — MPSC via `Mutex<Deque<T>>`

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO.Event.Registration.Queue.swift`

**Structure**:
```swift
public typealias Queue<T> = Ownership.Mutable<Mutex<Deque<T>>>.Unchecked
```

**Semantics**: Thread-safe unbounded MPSC queue. Multiple actor tasks call `enqueue()`, a single poll thread calls `dequeue()` and `drain()`.

**Operations**: `enqueue(_:)`, `dequeue() -> E?`, `drain() -> [E]`

**Used as**: `IO.Event.Registration.Queue` = `Queue<IO.Event.Registration.Request>`

**Key property**: Unbounded growth. The `Deque` (from `Queue_DoubleEnded_Primitives`) provides the underlying storage; `Mutex` provides synchronization; `Ownership.Mutable.Unchecked` provides heap allocation + `Sendable`.

### 2.2 `IO.Completion.Submission.Queue` — MPSC via `Mutex<Deque<T>>`

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Completions/IO.Completion.Submission.Queue.swift`

**Structure**:
```swift
public typealias Queue = Ownership.Mutable<Mutex<Deque<IO.Completion.Operation.Storage>>>.Unchecked
```

**Semantics**: Identical pattern to 2.1. Thread-safe unbounded MPSC for actor-to-poll-thread submission handoff.

**Operations**: `enqueue(_:)`, `drain() -> [E]`

**Note**: `drain()` uses `while let` loop instead of `deque.drain {}` — inconsistent with 2.1 which uses `deque.drain { }`.

### 2.3 `IO.Blocking.Threads.Runtime.State` — Shared work queue

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift`

**Structure**:
```swift
var queue: Queue<IO.Blocking.Threads.Job.Instance>.DoubleEnded.Fixed
```

**Semantics**: Fixed-capacity work queue for the blocking thread pool. Capacity is set at init time (`queueLimit`). Elements are `~Copyable` (`Job.Instance` is move-only). Thread safety is external (via `Kernel.Thread.DualSync` lock).

**Operations used**: `queue.isFull`, `queue.isEmpty`, `queue.count`, `queue.capacity`, `queue.pop(from: .front)`, `queue.pop(from: .back)`, `try! queue.push(job, to: .back)`, `queue.clear()`

**Key property**: Uses double-ended access (FIFO via `.front` pop, LIFO via `.back` pop) depending on `Scheduling` mode (`.fifo` vs `.lifo`). The deque API is essential here.

### 2.4 `IO.Blocking.Threads.Worker` — Local batch buffer

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Worker.swift`

**Structure**:
```swift
var localBatch = Queue<IO.Blocking.Threads.Job.Instance>.DoubleEnded.Fixed(capacity: try! .init(Self.drainLimit))
```

**Semantics**: Worker-local fixed-capacity deque for batch dequeue. Capacity is `drainLimit` (16). Used to batch-drain jobs from the shared queue under a single lock acquisition, then execute outside the lock.

**Operations used**: `localBatch.clear()`, `try! localBatch.push(consume job, to: .back)`, `localBatch.isFull`, `localBatch.isEmpty`, `localBatch.count`, `localBatch.drain { job in }`

**Key property**: `~Copyable` element support is critical — jobs are move-only. The drain closure receives `consuming` elements.

### 2.5 `IO.Blocking.Lane.Abandoning.Runtime.State` — `Kernel.Thread.Queue`

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking/IO.Blocking.Lane.Abandoning.Runtime.State.swift`

**Structure**:
```swift
var queue = Kernel.Thread.Queue<IO.Blocking.Lane.Abandoning.Job>()
```

**Semantics**: Unbounded FIFO queue for the abandoning runtime. `Kernel.Thread.Queue` is a thin wrapper around `Deque` (from queue-primitives) with `enqueue/dequeue/peek/removeAll`. Thread safety is external (via `Kernel.Thread.DualSync`).

**Source**: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel/Kernel.Thread.Queue.swift`

```swift
public struct Queue<Element> {
    private var storage: Deque<Element>
    // enqueue, dequeue, peek, removeAll, count, isEmpty, capacity
}
```

**Key observation**: `Kernel.Thread.Queue` is a redundant wrapper. It wraps `Deque` but only exposes FIFO operations (enqueue = push back, dequeue = take front). This is literally `Queue<E>` from queue-primitives — it duplicates the dynamic queue.

### 2.6 `IO.Blocking.Threads.Acceptance.Queue` — Three-plane composite

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift`

**Structure**:
```swift
struct Queue: ~Copyable {
    private var slots: Slab<Entry>                                          // Storage plane
    private var order: Queue_Primitives.Queue<IO.Blocking.Ticket>.Fixed     // Order plane
    private var index: Dictionary<IO.Blocking.Ticket, Coordination>.Ordered.Bounded  // Coordination plane
    private var deadlineHeap: Heap<Deadline.Entry>.Fixed                     // Deadline plane
}
```

**Semantics**: Bounded acceptance queue with O(1) cancellation and immediate capacity reclamation. Four-plane design:

1. **Storage plane**: `Slab<Entry>` — bitmap-indexed move-only job storage
2. **Order plane**: `Queue.Fixed` — FIFO ticket ordering (tombstone-safe)
3. **Coordination plane**: `Dictionary.Ordered.Bounded` — O(1) ticket-to-state lookup
4. **Deadline plane**: `Heap.Fixed` — min-heap for O(1) earliest-deadline lookup

**Operations**: `enqueue(ticket:job:deadline:)`, `dequeue() -> Waiter?`, `cancel(ticket:disposition:)`, `markDisposition(ticket:disposition:)`, `drain(_:)`, deadline accessor, expired accessor

**Key property**: This is a highly domain-specific composite. The `Queue.Fixed` is used purely as an order-tracking FIFO for Copyable tickets — it does not hold the move-only jobs.

---

## 3. Replacement Assessment

### 3.1 `IO.Event.Registration.Queue` (MPSC via Mutex+Deque)

**Can it be replaced by queue-primitives?** Partially.

The underlying `Deque<T>` already IS `Queue.DoubleEnded` from queue-primitives. The composition `Ownership.Mutable<Mutex<Deque<T>>>.Unchecked` is a manual MPSC pattern using:
- `Deque<T>` for storage (queue-primitives)
- `Mutex` for synchronization (Synchronization module)
- `Ownership.Mutable.Unchecked` for heap allocation + Sendable (ownership-primitives)

**What would be needed in queue-primitives?** A `Queue.Synchronized<E>` or `Queue.ThreadSafe<E>` type that encapsulates the `Ownership.Mutable<Mutex<Queue<E>>>.Unchecked` pattern. This would:
- Provide `enqueue(_:)`, `dequeue() -> E?`, `drain() -> [E]`, `drain { }` out of the box
- Enforce `Sendable`
- Be parameterized on the inner queue type (dynamic vs fixed)

**Breaking changes**: Minimal. The current typealias-based approach could be replaced with a direct type. The three methods (`enqueue`, `dequeue`, `drain`) would need identical signatures.

**Recommendation**: LOW PRIORITY. The current pattern works and is explicit. A synchronized wrapper is a convenience, not a correctness improvement. The `Ownership.Mutable.Unchecked` pattern is already well-understood in this codebase.

### 3.2 `IO.Completion.Submission.Queue` (MPSC via Mutex+Deque)

**Same assessment as 3.1.** Identical pattern, same replacement path.

**Additional note**: The `drain()` implementation uses `while let element = deque.front.take` instead of `deque.drain { }`. This should be updated to use `deque.drain { }` for consistency with 2.1, regardless of any queue-primitives changes. This is a swift-io-internal cleanup.

### 3.3 `IO.Blocking.Threads.Runtime.State` (Queue.DoubleEnded.Fixed)

**Can it be replaced by queue-primitives?** Already using it directly.

The field `queue: Queue<Job.Instance>.DoubleEnded.Fixed` is already a queue-primitives type. No replacement needed.

**Assessment**: NO ACTION.

### 3.4 `IO.Blocking.Threads.Worker` (local batch via Queue.DoubleEnded.Fixed)

**Can it be replaced by queue-primitives?** Already using it directly.

The local batch `Queue<Job.Instance>.DoubleEnded.Fixed` is already a queue-primitives type. No replacement needed.

**Assessment**: NO ACTION.

### 3.5 `IO.Blocking.Lane.Abandoning.Runtime.State` (Kernel.Thread.Queue)

**Can it be replaced by queue-primitives?** YES — direct replacement.

`Kernel.Thread.Queue<E>` is a thin FIFO wrapper around `Deque<E>` that exposes `enqueue`, `dequeue`, `peek`, `removeAll`, `count`, `isEmpty`, `capacity`. This is exactly `Queue<E>` from queue-primitives, with minor naming differences:

| `Kernel.Thread.Queue` | `Queue<E>` (primitives) |
|----------------------|------------------------|
| `enqueue(_:)` | `enqueue(_:)` |
| `dequeue() -> E?` | `dequeue() -> E?` |
| `peek() -> E?` | `peek() -> E?` |
| `removeAll(keepingCapacity:)` | `clear(keepingCapacity:)` |
| `count` | `count` |
| `isEmpty` | `isEmpty` |
| `capacity` | `capacity` |

**Breaking changes required**:

1. **In swift-kernel**: Deprecate or remove `Kernel.Thread.Queue` entirely. Replace with a typealias:
   ```swift
   extension Kernel.Thread {
       @available(*, deprecated, renamed: "Queue")
       public typealias Queue<E> = Queue_Primitives.Queue<E>
   }
   ```
   Or simply remove it and update call sites.

2. **In swift-io**: Replace `Kernel.Thread.Queue<IO.Blocking.Lane.Abandoning.Job>()` with `Queue<IO.Blocking.Lane.Abandoning.Job>()`.

3. **API difference**: `removeAll(keepingCapacity:)` vs `clear(keepingCapacity:)`. Call sites need updating.

4. **Default capacity**: `Kernel.Thread.Queue` defaults to `initialCapacity: 64`. `Queue<E>()` starts with zero capacity (lazy allocation). Either:
   - Use `Queue<E>(reservingCapacity: try! .init(64))` at the call site
   - Accept the lazy-allocation behavior (may be acceptable for this use case)

**Recommendation**: HIGH PRIORITY. This is a straightforward deduplication. `Kernel.Thread.Queue` adds no value over `Queue<E>` from queue-primitives. The `Deque` it wraps is itself from queue-primitives. The wrapper just restricts to FIFO semantics — which `Queue<E>` already provides.

### 3.6 `IO.Blocking.Threads.Acceptance.Queue` (composite)

**Can it be replaced by queue-primitives?** No.

This is a highly domain-specific four-plane composite (Slab + Queue.Fixed + Dictionary.Ordered.Bounded + Heap.Fixed). It already uses `Queue.Fixed` from queue-primitives as its order plane. The composite itself is not a general-purpose data structure — it implements O(1) cancellation with immediate capacity reclamation, deadline tracking, and tombstone-safe FIFO ordering.

**What about the Queue.Fixed usage within it?** Already using queue-primitives. No change needed.

**Would a general-purpose addition to queue-primitives help?** Potentially, a `Queue.Cancellable` or `Queue.Ticketed` type could abstract the ticket+slab+order pattern. However:
- The acceptance queue's exact semantics (four planes, lazy expiry, disposition marking) are deeply intertwined with IO.Blocking.Threads semantics.
- Generalizing it would require abstracting the coordination plane, deadline plane, and cancellation semantics — unlikely to be reusable.

**Recommendation**: NO ACTION. The composite is correctly domain-specific. It already composes queue-primitives, slab-primitives, dictionary-primitives, and heap-primitives.

---

## 4. Summary Table

| Site | Current Implementation | Replacement? | Priority | Breaking Changes |
|------|----------------------|-------------|----------|-----------------|
| `IO.Event.Registration.Queue` | `Ownership.Mutable<Mutex<Deque<T>>>.Unchecked` | Optional synchronized wrapper | LOW | Typealias change |
| `IO.Completion.Submission.Queue` | `Ownership.Mutable<Mutex<Deque<T>>>.Unchecked` | Optional synchronized wrapper | LOW | Typealias change |
| `IO.Blocking.Threads.Runtime.State` | `Queue<Job>.DoubleEnded.Fixed` | Already using queue-primitives | NONE | — |
| `IO.Blocking.Threads.Worker` | `Queue<Job>.DoubleEnded.Fixed` | Already using queue-primitives | NONE | — |
| `IO.Blocking.Lane.Abandoning.Runtime.State` | `Kernel.Thread.Queue<Job>` | Replace with `Queue<Job>` | HIGH | `removeAll` → `clear`, default capacity |
| `IO.Blocking.Threads.Acceptance.Queue` | Composite (Slab + Queue.Fixed + Dict + Heap) | Already uses Queue.Fixed | NONE | — |

## 5. Actionable Items

### Immediate (no queue-primitives changes needed)

1. **Replace `Kernel.Thread.Queue` with `Queue` from queue-primitives** in `IO.Blocking.Lane.Abandoning.Runtime.State`. Deprecate `Kernel.Thread.Queue` in swift-kernel.

2. **Fix `IO.Completion.Submission.Queue.drain()`** to use `deque.drain { }` instead of `while let element = deque.front.take` for consistency.

### Future (queue-primitives additions)

3. **Consider `Queue.Synchronized<E>`** — a thread-safe wrapper composing `Ownership.Mutable<Mutex<Queue<E>>>.Unchecked`. This would standardize the MPSC pattern used in IO Events and IO Completions. However, this is low priority since the current manual composition is explicit and well-understood.

### Not recommended

4. **Do NOT generalize Acceptance.Queue** into queue-primitives. It is correctly domain-specific.

---

## 6. Dependency Impact

Currently swift-io already depends on:
- `Queue_DoubleEnded_Primitives` (IO Events, IO Blocking Threads)
- `Queue_Primitives` (IO Blocking Threads)

Replacing `Kernel.Thread.Queue` with `Queue` from queue-primitives would:
- Add `Queue_Primitives` as a dependency of `IO Blocking` (currently only IO Blocking Threads depends on it)
- Or: add `Queue_Dynamic_Primitives` as a lighter-weight dependency (just the FIFO queue without deque/linked variants)

The `IO Blocking` target currently depends on:
```
IO Primitives, Systems, Clock Primitives, Dimension Primitives, Ownership Primitives
```

Adding `Queue_Dynamic_Primitives` (or `Queue_Primitives`) would be a new dependency for this target. Since it is already a transitive dependency (through IO Blocking Threads → Queue Primitives), this adds no new transitives to the graph — only makes an existing transitive dependency direct.
