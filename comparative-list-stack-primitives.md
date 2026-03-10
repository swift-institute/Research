# Comparative Analysis: List/Stack Primitives vs swift-io Patterns

<!--
---
version: 1.0.0
date: 2026-02-24
scope: swift-list-primitives, swift-stack-primitives, swift-io
type: dependency-utilization-audit
status: DECISION
---
-->

## 1. Primitives Catalog

### 1.1 swift-list-primitives

**Location**: `/Users/coen/Developer/swift-primitives/swift-list-primitives/`

**Modules** (3):
- `List Primitives Core` — namespace, index, error types
- `List Linked Primitives` — operations for all variants
- `List Primitives` — umbrella re-export

**Public Types**:

| Type | Description | Storage | Copyable |
|------|-------------|---------|----------|
| `List<Element>` | Namespace enum | — | — |
| `List<Element>.Linked<N>` | Dynamic linked list (N=1 singly, N=2 doubly) | Arena-based `Buffer.Linked<N>`, CoW | Conditional |
| `List<Element>.Linked<N>.Bounded` | Fixed-capacity linked list | Arena-based `Buffer.Linked<N>`, CoW | Conditional |
| `List<Element>.Linked<N>.Inline<capacity>` | Zero-allocation inline storage | `Buffer.Linked<N>.Inline` (`@_rawLayout`) | Never (~Copyable) |
| `List<Element>.Linked<N>.Small<inlineCapacity>` | Inline with heap spill | `Buffer.Linked<N>.Small` | Never (~Copyable) |
| `List<Element>.Index` | Type-safe index (alias for `Index<Element>`) | — | — |

**Key design characteristics**:
- Arena-based node storage (contiguous allocation, index-referenced nodes) -- NOT traditional pointer-chasing linked lists
- Generic link count: `N=1` (singly-linked), `N=2` (doubly-linked)
- Full `~Copyable` element support across all variants
- `peek.first { }` / `peek.last { }` borrowing accessor pattern via `Property.View`
- `reversed.forEach { }` for doubly-linked traversal
- `Sequence` conformance when `Element: Copyable`
- No intrusive linked list variant
- No lock-free variant

**Operations** (uniform across all variants):

| Operation | N=1 | N=2 |
|-----------|-----|-----|
| `prepend(_:)` | O(1) | O(1) |
| `append(_:)` | O(1) via tail pointer | O(1) |
| `popFirst()` | O(1) | O(1) |
| `popLast()` | O(n) | O(1) |
| `forEach(_:)` | O(n) | O(n) |
| `clear()` | O(n) | O(n) |

### 1.2 swift-stack-primitives

**Location**: `/Users/coen/Developer/swift-primitives/swift-stack-primitives/`

**Modules** (5):
- `Stack Primitives Core` — namespace, index, error types, type declarations
- `Stack Dynamic Primitives` — operations for `Stack<Element>`
- `Stack Bounded Primitives` — operations for `Stack<Element>.Bounded`
- `Stack Static Primitives` — operations for `Stack<Element>.Static<capacity>`
- `Stack Small Primitives` — operations for `Stack<Element>.Small<inlineCapacity>`
- `Stack Primitives` — umbrella re-export

**Public Types**:

| Type | Description | Storage | Copyable |
|------|-------------|---------|----------|
| `Stack<Element>` | Dynamic LIFO stack | `Buffer.Linear`, CoW | Conditional |
| `Stack<Element>.Bounded` | Fixed-capacity LIFO stack | `Buffer.Linear.Bounded`, CoW | Conditional |
| `Stack<Element>.Static<capacity>` | Zero-allocation inline storage | `Buffer.Linear.Inline` (`@_rawLayout`) | Never (~Copyable) |
| `Stack<Element>.Small<inlineCapacity>` | Inline with heap spill | `Buffer.Linear.Small` | Never (~Copyable) |
| `Stack<Element>.Index` | Type-safe index (alias for `Index<Element>`) | — | — |

**Key design characteristics**:
- Linear (contiguous array) storage -- standard LIFO semantics
- Full `~Copyable` element support across all variants
- `peek { }` borrowing accessor pattern for `~Copyable` elements
- `peek()` returning copy for `Copyable` elements
- `Span` / `MutableSpan` access for zero-copy reads
- `Sequence.Protocol` conformance (custom iterator)
- `Sequence.Drain.Protocol` conformance with `drain { }` pattern
- No lock-free (Treiber) stack variant
- No concurrent stack variant

**Operations** (uniform across all variants):

| Operation | Complexity |
|-----------|-----------|
| `push(_:)` | O(1) amortized (Dynamic/Small), O(1) (Bounded/Static) |
| `pop()` | O(1) |
| `peek { }` / `peek()` | O(1) |
| `forEach(_:)` | O(n) |
| `clear()` | O(n) |
| `truncate(to:)` | O(k) |
| `compact()` | O(n) (Dynamic only) |
| `drain { }` | O(n) |

---

## 2. swift-io Usage Sites

### 2.1 Queue Patterns (FIFO)

swift-io makes **extensive** use of FIFO queues but uses existing queue/deque primitives, not linked lists:

#### 2.1.1 `Kernel.Thread.Queue<T>` (1 site)

**File**: `IO Blocking/IO.Blocking.Lane.Abandoning.Runtime.State.swift:15`
```swift
var queue = Kernel.Thread.Queue<IO.Blocking.Lane.Abandoning.Job>()
```

This is a simple FIFO queue backed by `Deque<T>` from the kernel module. Used under external lock (`Kernel.Thread.DualSync`). Operations: `enqueue(_:)`, `dequeue()`, `isEmpty`, `count`.

**Relevance to List primitives**: `Kernel.Thread.Queue` wraps a `Deque`. A `List.Linked<1>` (singly-linked) could theoretically serve as a FIFO with O(1) `append`/`popFirst`, but `Deque` already provides O(1) amortized for both operations with better cache locality (contiguous storage). **No replacement opportunity.**

#### 2.1.2 `Queue<T>.DoubleEnded.Fixed` (2 sites)

**File**: `IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift:35`
```swift
var queue: Queue<IO.Blocking.Threads.Job.Instance>.DoubleEnded.Fixed
```

**File**: `IO Blocking Threads/IO.Blocking.Threads.Worker.swift:53`
```swift
var localBatch = Queue<IO.Blocking.Threads.Job.Instance>.DoubleEnded.Fixed(capacity: ...)
```

Bounded double-ended queue supporting `~Copyable` job instances. The main queue uses FIFO or LIFO scheduling (`pop(from: .front)` vs `pop(from: .back)`). The local batch buffer collects jobs under a single lock acquisition.

**Relevance to List/Stack primitives**: The `.lifo` scheduling path pops from `.back`, which is stack-like. However, `Queue.DoubleEnded.Fixed` supports both ends with O(1) complexity, which neither `List.Linked` nor `Stack` can match simultaneously. **No replacement opportunity.**

#### 2.1.3 `Queue_Primitives.Queue<T>.Fixed` (1 site)

**File**: `IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift:61`
```swift
private var order: Queue_Primitives.Queue<IO.Blocking.Ticket>.Fixed
```

FIFO order tracking in the three-plane acceptance queue. Tickets are `Copyable` (just identifiers). Used purely for ordering with tombstone skipping on dequeue.

**Relevance**: Neither `List` nor `Stack` is appropriate here. **No replacement opportunity.**

#### 2.1.4 `Deque<T>` via `Mutex` wrappers (2 sites)

**File**: `IO Events/IO.Event.Registration.Queue.swift:15`
```swift
public typealias Queue<T> = Ownership.Mutable<Mutex<Deque<T>>>.Unchecked
```

**File**: `IO Completions/IO.Completion.Submission.Queue.swift:17`
```swift
public typealias Queue = Ownership.Mutable<Mutex<Deque<IO.Completion.Operation.Storage>>>.Unchecked
```

Thread-safe MPSC queues for actor-to-poll-thread handoff. Uses `Deque` with `Mutex` for push/drain semantics. These are FIFO pipelines.

**Relevance**: Deque is the correct primitive for MPSC FIFO queues with batched drain. **No replacement opportunity.**

### 2.2 LIFO / Stack Patterns

#### 2.2.1 LIFO Scheduling in Worker

**File**: `IO Blocking Threads/IO.Blocking.Threads.Worker.swift:74-78`
```swift
switch scheduling {
case .fifo:
    firstJob = state.queue.pop(from: .front)
case .lifo:
    firstJob = state.queue.pop(from: .back)
}
```

The `.lifo` scheduling option provides LIFO job ordering for cache locality benefits. This uses `Queue.DoubleEnded.Fixed` which supports both FIFO and LIFO via the same container.

**Relevance to Stack**: A `Stack.Bounded` could replace the LIFO case, but then the FIFO case would need a separate container. The double-ended queue elegantly supports both modes in a single allocation. **No replacement opportunity.**

#### 2.2.2 No Explicit Stack Usage

There are **zero** imports of `Stack_Primitives` in swift-io. No push/pop stack patterns exist outside of the deque-backed FIFO/LIFO scheduling.

### 2.3 Linked List Patterns

#### 2.3.1 No Intrusive Linked Lists

swift-io uses **no intrusive linked lists** (where nodes contain `next`/`prev` pointers embedded in the element type). All queue patterns use index-based or contiguous storage.

#### 2.3.2 io_uring Ring Buffers

**File**: `IO Completions/IO.Completion.IOUring.Ring.swift`

The `head`/`tail` patterns in io_uring are kernel-managed ring buffers with mmap'd memory. These are fundamentally different from linked lists -- they are fixed-size circular arrays indexed by `head & mask` / `tail & mask`. The head/tail pointers are atomic `UInt32` values in shared memory between userspace and kernel.

**Relevance**: This is a hardware/OS-level ring buffer interface with atomic shared memory semantics. No primitives replacement is possible or desirable. **No replacement opportunity.**

#### 2.3.3 `Async.Waiter.Queue.Bounded` (1 site)

**File**: `IO/IO.Handle.Waiters.swift:56`
```swift
var queue: Async.Waiter.Queue.Bounded<Void, Waiter.Token>
```

Bounded FIFO waiter queue from `Async_Primitives`. Supports push/popFront/popEligible with atomic cancellation flags. This is a specialized concurrent data structure, not a general linked list.

**Relevance**: `List.Linked.Bounded` could theoretically back this, but the waiter queue has specialized semantics (atomic cancellation flags, eligible-entry skipping, flagged drain) that require its own implementation. **No replacement opportunity.**

### 2.4 Heap / Priority Queue Patterns

**Files**: Multiple sites use `Heap<T>.Fixed` for deadline management:
- `IO Events/IO.Event.Selector.swift:105` — `deadlineHeap: Heap<DeadlineScheduling.Entry>`
- `IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift:68` — `deadlineHeap: Heap<Deadline.Entry>.Fixed`

These are min-heaps for O(1) earliest-deadline lookup, O(log n) push. Neither `List` nor `Stack` primitives are relevant here.

### 2.5 Memory Pool (Slab) Patterns

**File**: `IO/IO.Executor.Slot.Pool.swift`

Uses `Memory.Pool` for pre-allocated transaction slot memory. The pool's internal free-list is a stack-like allocate/deallocate pattern, but it's encapsulated within `Memory.Pool` from `Memory_Pool_Primitives`.

**Relevance**: The internal free-list is already handled by the memory pool primitive. **No replacement opportunity.**

---

## 3. Assessment

### 3.1 Summary: Zero Replacement Opportunities

| swift-io Pattern | Current Primitive | List/Stack Fit? | Verdict |
|------------------|-------------------|-----------------|---------|
| `Kernel.Thread.Queue` (Abandoning) | `Deque` | No -- Deque has better locality | No change |
| `Queue.DoubleEnded.Fixed` (Threads) | `Queue_DoubleEnded_Primitives` | No -- needs both-end access | No change |
| `Queue.Fixed` (Acceptance order) | `Queue_Primitives` | No -- FIFO only | No change |
| `Deque` via `Mutex` (Registration/Submission) | `Buffer_Primitives` Deque | No -- MPSC FIFO with batch drain | No change |
| LIFO scheduling | `Queue.DoubleEnded.Fixed` | Partial -- but FIFO also needed | No change |
| io_uring ring buffers | Kernel mmap'd memory | No -- OS-level shared memory | No change |
| `Async.Waiter.Queue.Bounded` | `Async_Primitives` | No -- specialized cancellation | No change |
| Deadline heaps | `Heap_Fixed_Primitives` | No -- priority queue, not list/stack | No change |
| `Memory.Pool` free-list | `Memory_Pool_Primitives` | No -- encapsulated internally | No change |

### 3.2 Why No Opportunities Exist

1. **swift-io does not use linked lists.** All queue patterns use contiguous-storage data structures (deques, ring buffers, arrays). The arena-based `List.Linked` would offer no advantage over `Deque` for FIFO patterns, and would have worse cache locality for the sizes involved (typically <100 elements).

2. **swift-io does not use standalone stacks.** The one LIFO pattern (worker scheduling) is served by `Queue.DoubleEnded.Fixed`, which must also support FIFO scheduling. Introducing `Stack` would require maintaining two separate containers or losing the dual-mode capability.

3. **Specialized concurrent structures dominate.** The waiter queues (`Async.Waiter.Queue`), acceptance queues (three-plane Slab+Queue+Dictionary design), and completion bridges have domain-specific semantics (atomic cancellation, tombstone skipping, flagged drain) that go far beyond what generic list/stack primitives provide.

4. **Hardware-level ring buffers are not replaceable.** The io_uring head/tail patterns are shared-memory interfaces between userspace and kernel. These are fundamentally fixed-size circular arrays with atomic index management.

### 3.3 Where List/Stack Primitives *Would* Be Useful in IO

If swift-io were to gain features that need these primitives, the likely sites would be:

- **Intrusive linked lists for timer wheels**: If the deadline system moved from a heap to a hierarchical timer wheel, an intrusive doubly-linked list per wheel slot would be natural. `List.Linked<2>` could serve this if an intrusive variant were added.

- **Undo/history stacks**: If an IO debugging or transaction system needed undo semantics, `Stack.Bounded` or `Stack.Static` would be a natural fit.

- **Connection pool free-lists**: If connection pooling moved from slab-based allocation to explicit LIFO free-lists (for temporal locality), `Stack.Bounded` could serve that role.

None of these features exist today.

### 3.4 Quality Observations on the Primitives

Both packages are well-designed and production-ready:

**List Primitives**:
- The arena-based storage model (index-referenced nodes in contiguous memory) is a significant improvement over traditional pointer-chasing linked lists
- The `N` generic parameter for link count is elegant and avoids separate Singly/Doubly types
- `~Copyable` support is thorough (4 variants, all with borrowing peek)
- Missing: intrusive linked list variant (nodes embedded in elements), lock-free variant

**Stack Primitives**:
- Clean four-variant taxonomy matching the Buffer discipline (Dynamic/Bounded/Static/Small)
- `Span`/`MutableSpan` access is a differentiator over ad-hoc stack implementations
- `Sequence.Drain.Protocol` conformance with `drain { }` is well-integrated
- Missing: lock-free (Treiber) stack variant, concurrent stack

---

## 4. Conclusion

**swift-io has zero sites where `List_Primitives` or `Stack_Primitives` could replace existing implementations.** The IO subsystem's data structures are dominated by deques, double-ended queues, ring buffers, and specialized concurrent structures -- all of which are already served by appropriate primitives (`Buffer_Primitives` Deque, `Queue_DoubleEnded_Primitives`, `Queue_Primitives`, `Async_Primitives`, `Heap_Fixed_Primitives`).

The list and stack primitives remain valuable for their intended audience (general-purpose application code, embedded systems with predictable memory, data-structure-heavy algorithms) but are not a match for the concurrent IO runtime's requirements.
