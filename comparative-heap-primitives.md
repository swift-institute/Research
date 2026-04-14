# Comparative Analysis: swift-heap-primitives vs swift-io Heap Usage

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: RECOMMENDATION
tier: 2
scope: cross-package (swift-heap-primitives, swift-io)
---
-->

## Context

swift-io uses heap primitives in two distinct deadline-scheduling subsystems. This analysis catalogs the heap-primitives API surface, maps it onto the concrete usage in swift-io, identifies friction points, and evaluates whether primitives-layer additions could reduce complexity in the IO layer.

**Trigger**: Cross-package audit -- do the primitives serve the IO consumer well, or is IO forced to build compensating infrastructure around primitive gaps?

---

## Part 1: swift-heap-primitives Catalog

### Type Hierarchy

```
Heap<Element: ~Copyable & Comparison.Protocol>: ~Copyable
  |-- Order { .ascending, .descending }
  |-- Error { .empty }
  |-- Push.Outcome { .inserted, .overflow(Element) }
  |-- Binary (typealias -> Heap)
  |-- Min (stub, fatalError)
  |-- Max (stub, fatalError)
  |-- Fixed: ~Copyable           -- heap-allocated, bounded capacity
  |     |-- Error { .invalidCapacity, .empty }
  |-- Static<let capacity>: ~Copyable  -- inline storage, compile-time capacity
  |     |-- Error { .empty }
  |-- Small<let inlineCapacity>: ~Copyable  -- SBO (inline + spill)
  |     |-- Error { .empty }
  |-- MinMax: ~Copyable           -- double-ended (min + max in O(1))
  |     |-- Position { .min, .max }
  |     |-- Error (= Heap.Error)
  |     |-- Min, Max, Remove, Peek (Property.View namespaces)
  |     |-- Fixed (stub -- declared, no operations)
  |     |-- Static<let capacity> (stub -- declared, no operations)
  |     |-- Small<let inlineCapacity> (stub -- declared, no operations)
  |-- Navigate: Sendable, Hashable
  |     |-- Child { .left, .right }
  |     |-- parent(of:), child(_:of:), isValid(_:), lastNonLeaf
  |-- Index = Index_Primitives.Index<Element>
  |-- Ordering = Comparison.Protocol
```

### Operations by Variant

| Operation | Heap | Fixed | Static | Small | MinMax |
|-----------|:----:|:-----:|:------:|:-----:|:------:|
| `init(order:)` | yes | yes (capacity) | yes | yes | yes (no order) |
| `init(_ elements:)` | yes | yes | -- | -- | yes |
| `push(_:)` | yes | yes -> Outcome | yes -> Outcome | yes | yes |
| `pop() throws` | yes | yes | yes | yes | yes (via min/max) |
| `take -> Element?` | yes | yes | yes | yes | yes (via min/max) |
| `peek -> Element?` | yes | yes | yes (mut) | yes (mut) | yes (peek.min/max) |
| `withPriority(_:)` | yes | yes | yes | yes | withMin/withMax |
| `count` | yes | yes | yes | yes | yes |
| `isEmpty` | yes | yes | yes | yes | yes |
| `isFull` | -- | yes | yes | -- | -- |
| `capacity` | -- | yes | -- | yes | -- |
| `navigate` | yes | yes | yes | yes | -- |
| `remove.all()` | yes | yes | yes | yes | yes |
| `removeAll()` | yes | yes | yes | yes | yes |
| `truncate(to:)` | -- | yes | yes | yes | -- |
| `forEach(_:)` | yes | yes | yes | yes | yes |
| `drain(_:)` | yes | yes | yes | yes | yes |
| `span` | -- | yes | -- | yes | -- |
| `mutableSpan` | -- | yes | -- | yes | -- |
| `element(at:)` | yes | yes | -- | -- | -- |
| `Equatable` | yes | -- | -- | -- | yes |
| `Hashable` | yes | -- | -- | -- | yes |
| `Sequence` | yes | yes | yes* | yes* | yes |
| `Sendable` | cond. | cond. | cond. | cond. | cond. |
| `Copyable` | cond. | cond. | never | never | cond. |

*\*Snapshot-based iterator (O(n) copy).*

### Critically Absent from Primitives (by design)

Per `heap-operations-audit.md` and `heap-discipline-boundary-analysis.md`:

| Operation | Rationale for absence |
|-----------|----------------------|
| **decrease-key / increase-key** | Requires index-tracking handles (heap + handle map). Composed infrastructure, not primitive. |
| **remove(at: Index)** | Not a standard heap ADT operation. Would require trickle-down/bubble-up from arbitrary position. |
| **merge / union** | O(n) for binary heaps. Only efficient with mergeable heap trees (binomial, Fibonacci, pairing). |
| **Indexed / Addressable heap** | Requires a bidirectional map from element identity to heap position. Composed infrastructure. |

---

## Part 2: swift-io Heap Usage Sites

### Site A: `IO.Event.Selector` -- Event Deadline Scheduling

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Selector.swift`

**Declaration** (line 105):
```swift
private var deadlineHeap: Heap<DeadlineScheduling.Entry> = .init()
```

Uses `Heap` (dynamic, unbounded) with default `.ascending` order (min-heap).

**Entry type** (`IO.Event.DeadlineScheduling.Entry`):
```swift
struct Entry: Sendable {
    let deadline: UInt64        // nanoseconds
    let key: Permit.Key         // (ID, Interest) pair
    let generation: UInt64      // stale-entry detection
}
```

**Generation tracking infrastructure** (lines 107-111):
```swift
private var deadlineGeneration: [Permit.Key: UInt64] = [:]
```

A separate `[Permit.Key: UInt64]` dictionary tracks the current generation per key. When a waiter completes (event delivery, cancellation, timeout, deregistration), its generation is bumped via `bumpGeneration(for:)`. Heap entries whose generation does not match are silently skipped.

**Operations used**:

| Operation | Call site | Purpose |
|-----------|-----------|---------|
| `deadlineHeap.push(entry)` | `scheduleDeadline()` (line 712) | Insert new deadline entry |
| `deadlineHeap.peek` | `drainExpiredDeadlines()` (line 877), `updateNextPollDeadline()` (lines 934, 947) | O(1) check of earliest deadline |
| `deadlineHeap.take` | `drainExpiredDeadlines()` (line 884), `updateNextPollDeadline()` (line 940) | Pop expired/stale entries |
| `deadlineHeap = .init()` | `shutdown()` (line 1021) | Complete teardown |

**Compensating infrastructure** built around heap gaps:

1. **Generation counter dictionary** (`deadlineGeneration: [Permit.Key: UInt64]`) -- 6 references, manages stale-entry detection because the heap has no `remove(key:)` or addressable deletion.
2. **`bumpGeneration(for:)` method** -- called whenever a waiter is consumed by any path (event, cancel, timeout, deregister).
3. **Lazy deletion loop in `drainExpiredDeadlines()`** -- pops entries, checks generation match, skips stale.
4. **Lazy deletion loop in `updateNextPollDeadline()`** -- pops stale entries from front to find the first valid deadline.

**Cost of compensating infrastructure**: 1 dictionary allocation + O(1) per waiter lifecycle event for generation bump + amortized O(k) stale-entry cleanup where k is the number of stale entries accumulated since last drain.

### Site B: `IO.Blocking.Threads.Acceptance.Queue` -- Blocking Thread Deadline Scheduling

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift`

**Declaration** (line 68):
```swift
private var deadlineHeap: Heap<Deadline.Entry>.Fixed
```

Uses `Heap.Fixed` (bounded capacity) with `.ascending` order (min-heap).

**Entry type** (`Queue.Deadline.Entry`):
```swift
struct Entry: Comparison.Protocol, Equation.Protocol {
    let deadline: IO.Blocking.Deadline
    let ticket: IO.Blocking.Ticket
}
```

No generation field here -- stale detection relies on the coordination dictionary.

**Operations used**:

| Operation | Call site | Purpose |
|-----------|-----------|---------|
| `deadlineHeap.push(entry)` | `enqueue()` (line 140) | Insert deadline when job has a deadline |
| `deadlineHeap.peek` | `Deadline.earliest` (line 329), `Expired.cancel()` (line 369) | O(1) earliest deadline lookup |
| `deadlineHeap.take` | `Expired.cancel()` (line 370) | Pop expired entries |
| `deadlineHeap.removeAll()` | `drain()` (line 277) | Shutdown teardown |

**Compensating infrastructure**:

1. **Coordination dictionary** (`index: Dictionary.Ordered.Bounded`) -- the `cancel()` method removes from the index, so when `Expired.cancel()` pops a heap entry and calls `queue.cancel(ticket:disposition:)`, the cancel returns `false` for already-cancelled entries.
2. **Lazy deletion in `Expired.cancel()`** -- pops entries from heap front, delegates staleness check to the coordination dictionary (`cancel()` returns false if ticket not found).

**Key difference from Site A**: Site B does NOT maintain a separate generation counter. Instead, it relies on the existing three-plane architecture (slots + order queue + coordination dictionary) where the dictionary `index.remove(ticket)` returning `nil` serves as the stale-entry detector.

---

## Part 3: Assessment

### Question 1: Does Heap-primitives support the generation-based lazy deletion pattern?

**No.** Heap-primitives has no built-in concept of generation, staleness, or entry invalidation. The heap treats all entries as opaque values ordered by `Comparison.Protocol`. The generation-based lazy deletion pattern is entirely built in swift-io's Selector as application-level infrastructure.

This is **architecturally correct** at the primitives layer. Generation tracking is application-specific: it depends on an external identity (Permit.Key) and an external lifecycle (waiter completion). The heap primitive cannot know what constitutes a "stale" entry -- that is domain knowledge.

However, the pattern is common enough in systems programming (timer heaps, expiry queues, deferred cancellation) that it merits analysis of whether a **composed primitive** at a higher layer could encapsulate it.

### Question 2: Could an addressable/indexed heap eliminate the need for generation tracking?

**Partially, but at significant cost.**

An addressable heap (also called an indexed priority queue) maintains a bidirectional map: element identity <-> heap position. This enables:
- `remove(key:)` in O(log n) -- find by key, swap with last, trickle-down
- `decreaseKey(key:, newPriority:)` in O(log n)
- `contains(key:)` in O(1)

If IO used an addressable heap, **Site A** could replace:
- The `deadlineGeneration` dictionary (eliminated entirely)
- The lazy deletion loops (replaced with eager O(log n) removal)
- `bumpGeneration(for:)` calls (replaced with `deadlineHeap.remove(key:)`)

And **Site B** could simplify `Expired.cancel()` to not need the stale-entry loop.

**However**, this has trade-offs:

| Factor | Lazy Deletion (current) | Addressable Heap |
|--------|------------------------|------------------|
| Memory | Heap + generation dict | Heap + position map + key map |
| Insert | O(log n) heap + O(1) dict | O(log n) heap + O(1) map updates |
| Remove | O(1) generation bump + deferred O(log n) | O(log n) eager removal + O(1) map updates |
| Drain expired | O(k log n) for k expired + stale | O(k log n) for k expired only |
| Peek earliest | O(1) amortized (skip stale) | O(1) always valid |
| Complexity | Simple data types | Complex composed structure |
| Stale accumulation | Unbounded between drains | None |
| Cancellation rate sensitivity | Degrades under high cancellation | Constant |

**Verdict**: For Site A (IO.Event.Selector), where the number of concurrent deadline entries is typically moderate (bounded by fd count) and cancellations are processed promptly via event delivery, lazy deletion is reasonable. The generation dictionary adds ~O(1) overhead per waiter lifecycle transition.

For Site B (Acceptance.Queue), the queue is already bounded by a fixed capacity, and the coordination dictionary (`Dictionary.Ordered.Bounded`) already provides O(1) staleness checking. An addressable heap would add redundant infrastructure.

An addressable heap would become compelling if:
1. The number of stale entries between drains grows large (many cancellations without intervening deadline checks)
2. `updateNextPollDeadline()` frequently pops many stale entries to find the first valid one
3. A system requires frequent `contains(key:)` checks against the heap

None of these conditions appear to be pain points in the current IO implementation.

### Question 3: What general-purpose additions to heap-primitives would support IO's deadline scheduling patterns?

Three additions would reduce friction without introducing application-specific concerns:

#### Addition 1: `remove(where:)` -- Predicate-based removal (Priority: Low)

```swift
extension Heap where Element: Copyable & Comparison.Protocol {
    /// Removes the first element matching the predicate.
    /// O(n) scan + O(log n) repair.
    mutating func remove(where predicate: (borrowing Element) -> Bool) -> Element?
}
```

This would let IO remove specific deadline entries without lazy deletion. However, it is O(n) -- no better than the current lazy approach amortized over the entry's lifetime.

**Verdict**: Not worth adding. O(n) removal defeats the purpose; lazy deletion is superior.

#### Addition 2: `drainWhile(_:)` -- Conditional drain from priority end (Priority: Medium)

```swift
extension Heap where Element: Copyable & Comparison.Protocol {
    /// Pops elements while the predicate holds for the priority element.
    /// Stops at the first element that does not match.
    mutating func drainWhile(_ predicate: (borrowing Element) -> Bool, body: (consuming Element) -> Void)
}
```

Both IO sites implement this pattern manually:

**Site A** (`drainExpiredDeadlines`):
```swift
while let entry = deadlineHeap.peek {
    if entry.deadline > now { break }
    _ = deadlineHeap.take
    // ... process entry
}
```

**Site B** (`Expired.cancel`):
```swift
while let top = queue.deadlineHeap.peek, top.deadline.hasExpired {
    _ = queue.deadlineHeap.take
    // ... process entry
}
```

A `drainWhile` method would encapsulate the peek-check-take loop. This is a general-purpose heap operation (drain all elements below a threshold) that appears in any deadline/timer system.

**Verdict**: Worth considering at the primitives layer. It is purely heap discipline (operate on priority end while condition holds) and reusable across domains.

#### Addition 3: `popWhile(_:)` -- Batch pop returning count (Priority: Low)

```swift
extension Heap where Element: Copyable & Comparison.Protocol {
    /// Pops and discards elements while predicate holds. Returns count removed.
    mutating func popWhile(_ predicate: (borrowing Element) -> Bool) -> Int
}
```

Used by `updateNextPollDeadline()` to clear stale entries from the front. However, the IO code needs to inspect each entry (check generation), so a simple discard-based pop is insufficient.

**Verdict**: Too narrow. The IO use case requires per-element inspection, not blind discard. `drainWhile` covers this.

### Question 4: Is there a timer wheel or hierarchical timing wheel that could replace both heaps?

**Short answer**: No, and it should not.

**Long answer**:

A hierarchical timing wheel (Varghese & Lauck, 1987) is an alternative to a heap for managing timeouts. It provides:
- O(1) insert and cancel (vs O(log n) for heap)
- O(1) amortized tick processing
- No ordering -- entries are bucketed by time slot

Timer wheels excel when:
- There are many thousands of concurrent timers
- Most timers fire (vs being cancelled)
- Timer resolution is coarse (millisecond or second granularity)
- The time horizon is bounded

Timer wheels are suboptimal when:
- The number of timers is small (wheel overhead > heap overhead)
- Precise earliest-deadline query is needed (wheels require cascading)
- Timer resolution varies widely (nanosecond to second range in a single system)
- Cancellation rate is high relative to firing rate

**Analysis for IO's use cases**:

| Factor | IO.Event.Selector | IO.Blocking.Acceptance |
|--------|-------------------|----------------------|
| Concurrent timers | Moderate (fd count) | Bounded (pool capacity) |
| Resolution | Nanosecond | Deadline-based |
| Earliest-deadline query | Required (poll timeout) | Required (schedule check) |
| Cancellation rate | Moderate | Moderate |

Both IO subsystems critically depend on **earliest-deadline peek** to compute poll timeouts. The Selector publishes `nextDeadline.store(entry.deadline)` to the poll thread, which uses it as the poll timeout. A timer wheel would require scanning the current slot (and potentially cascading) to find the earliest deadline, losing the O(1) peek guarantee.

Furthermore, timer wheels are composed data structures involving:
- Multiple ring buffers (one per granularity level)
- Cascading logic between levels
- Slot-based linked lists of entries
- A concept of "current tick" that must advance monotonically

This is Foundations-layer (Layer 3) or Components-layer (Layer 4) infrastructure, not a primitive. It would be a separate package (`swift-timer-wheel` or similar), not an addition to heap-primitives.

**Verdict**: A timer wheel is not an appropriate replacement. The heap's O(1) peek + O(log n) insert/remove profile is well-suited to IO's moderate-cardinality deadline scheduling with mandatory earliest-deadline queries.

---

## Part 4: Summary of Findings

### Current Fit Assessment

| Dimension | Rating | Notes |
|-----------|--------|-------|
| API completeness for IO's needs | **Good** | push, peek, take, removeAll cover all required operations |
| Variant selection | **Good** | Dynamic `Heap` for Selector (unbounded), `Heap.Fixed` for Acceptance (bounded) |
| Ordering configuration | **Good** | `.ascending` default is correct for min-heap deadline scheduling |
| ~Copyable support | **N/A** | IO's entry types are Copyable + Sendable |
| Lazy deletion support | **Not needed at primitive layer** | Application-specific pattern correctly built in IO |
| Generation tracking | **Not needed at primitive layer** | Domain-specific identity lifecycle |
| Addressable heap | **Not needed currently** | Would add complexity without proportional benefit for IO's cardinality |
| Timer wheel | **Not appropriate** | Loses O(1) peek; wrong layer |

### Replacement Opportunities

| Current IO Code | Potential Improvement | Priority | Layer |
|-----------------|----------------------|----------|-------|
| Manual peek-check-take loop (2 sites) | `Heap.drainWhile(_:body:)` primitive | Medium | Primitives (heap discipline) |
| `deadlineGeneration` dictionary (Site A) | Addressable heap at Foundations | Low | Foundations (composed) |
| Generation bump on every waiter lifecycle event | Addressable heap would eliminate | Low | Foundations (composed) |
| Stale-entry cleanup in `updateNextPollDeadline()` | Addressable heap would eliminate | Low | Foundations (composed) |

### Recommended Actions

1. **No changes to swift-io's heap usage required.** The current lazy deletion pattern is sound for the cardinality and access patterns involved.

2. **Consider adding `drainWhile(_:body:)` to heap-primitives.** This encapsulates a common deadline-processing pattern (pop from priority end while condition holds) that appears in both IO sites and would appear in any timer/scheduler system. It is purely heap discipline and general-purpose.

3. **Do not add an addressable heap to heap-primitives.** Per the existing `heap-operations-audit.md`, decrease-key and indexed removal require composed infrastructure (heap + handle map) that belongs at Foundations (Layer 3) or above. If demand materializes, create `swift-indexed-priority-queue` as a separate Foundations package.

4. **Do not pursue timer wheels.** The cardinality and access pattern do not warrant it, and the O(1) peek requirement for poll timeout computation is a hard constraint.

5. **The `Heap.MinMax` variants (Fixed, Static, Small) remaining as stubs is acceptable.** IO does not need double-ended heaps for deadline scheduling. Completing these stubs is a variant-completeness concern, not an IO-driven need.

---

## References

- `https://github.com/swift-primitives/swift-heap-primitives/blob/main/Research/heap-operations-audit.md` -- canonical operations inventory
- `https://github.com/swift-primitives/swift-heap-primitives/blob/main/Research/heap-discipline-boundary-analysis.md` -- layering analysis
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Selector.swift` -- event deadline scheduling
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.DeadlineScheduling.Entry.swift` -- generation-based entry
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Arm.Handle.swift` -- generation in arm handles
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift` -- bounded deadline scheduling
- Varghese & Lauck, "Hashed and Hierarchical Timing Wheels" (1987) -- timer wheel reference
- Cormen, Leiserson, Rivest, Stein, "Introduction to Algorithms" -- Chapter 6 (Heapsort), Chapter 19 (Fibonacci Heaps)
