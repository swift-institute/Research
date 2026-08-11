# Waiter Two-Phase Design: Cell vs Entry Refactor

<!--
---
version: 1.0.0
last_updated: 2026-03-23
status: RECOMMENDATION
tier: 2
---
-->

## Context

swift-io implements two custom waiter types (`IO.Event.Waiter`, `IO.Completion.Waiter`) with identical atomic state machines because the ecosystem's `Async.Waiter.Entry` only supports single-phase creation (continuation bound at init). The IO pattern requires two-phase creation: create unarmed → store in dictionary → arm with continuation later.

This is a design question for the ecosystem primitives layer, not for swift-io.

**Trigger**: [RES-011] Research-first — blocked on whether to add `Async.Waiter.Cell<T>` or refactor `Async.Waiter.Entry` to support multi-phase arming.

## Question

Should the ecosystem add a new `Async.Waiter.Cell<T>` type, or refactor `Async.Waiter.Entry` to support optional late-binding of continuations?

## Current State

### Async.Waiter.Entry (single-phase)

```swift
struct Entry<Outcome: Sendable, Metadata: ~Copyable & Sendable>: ~Copyable, Sendable {
    let continuation: Async.Continuation<Outcome>  // bound at init
    let flag: Async.Waiter.Flag                     // external atomic
    var metadata: Metadata                          // caller-defined
}
```

- Created with continuation already available
- `consuming func resumption(with:) -> Resumption` — single-use
- Lives in a `Queue.Bounded` or `Queue.Unbounded` (FIFO)
- Consumers: Pool.Bounded, Cache, IO.Handle.Waiters

### IO.Event.Waiter / IO.Completion.Waiter (two-phase)

```swift
final class Waiter: @unchecked Sendable {
    let _state: Atomic<UInt8>                       // 3-bit state machine
    var continuation: CheckedContinuation<T, Never>? // nil until armed
    let id: ID                                       // lookup key
}
```

- Created without continuation (`init(id:)`)
- Stored in dictionary by key
- Armed later via `arm(continuation:) -> Bool`
- Cancelled atomically from any thread via `cancel()`
- Drained by owner via `take.forResume()`
- Does NOT live in a queue — lives in a dictionary

### Why two-phase exists

The pattern is: create waiter → store in `waiters[key]` → call `withCheckedContinuation { waiter.arm($0) }`. The continuation isn't available at waiter creation time because `withCheckedContinuation` hasn't been entered yet.

## Analysis

### Option A: New type `Async.Waiter.Cell<T>`

Add a standalone cell type alongside the existing Entry:

```swift
public final class Cell<Outcome: Sendable>: @unchecked Sendable {
    let _state: Atomic<UInt8>
    var continuation: Async.Continuation<Outcome>?

    public init()
    public func arm(continuation: Async.Continuation<Outcome>) -> Bool
    public func cancel()
    public func takeForResume() -> (continuation: Async.Continuation<Outcome>, wasCancelled: Bool)?
    public var wasCancelled: Bool { get }
    public var isArmed: Bool { get }
}
```

**Advantages:**
- Zero impact on existing Entry consumers (Pool.Bounded, Cache, IO.Handle.Waiters)
- Clear semantic distinction: Entry = queue element (value, ~Copyable), Cell = dictionary-stored latch (reference, Sendable)
- The two types serve genuinely different roles: Entry flows through a FIFO queue, Cell sits in a keyed dictionary
- Cell is `final class` (reference semantics for dictionary storage), Entry is `struct: ~Copyable` (value semantics for queue ownership)
- No Optional overhead on Entry's continuation (stays non-optional)
- Atomic state machine is self-contained — no dependency on external Flag

**Disadvantages:**
- Two waiter concepts in the ecosystem instead of one
- The atomic state machine in Cell duplicates Flag's purpose partially (cancelled bit)
- Naming might confuse: "when do I use Entry vs Cell?"

### Option B: Refactor Entry to support optional continuation

Make Entry's continuation optional, supporting both single-phase and two-phase:

```swift
struct Entry<Outcome: Sendable, Metadata: ~Copyable & Sendable>: ~Copyable, Sendable {
    var continuation: Async.Continuation<Outcome>?  // was non-optional
    let flag: Async.Waiter.Flag
    var metadata: Metadata

    // Single-phase (existing)
    init(continuation: Async.Continuation<Outcome>, flag: Flag, metadata: consuming Metadata)

    // Two-phase (new)
    init(flag: Flag, metadata: consuming Metadata)
    mutating func arm(_ continuation: Async.Continuation<Outcome>) -> Bool
}
```

**Advantages:**
- Single concept: one Entry type serves both patterns
- Existing queue infrastructure (popEligible, reapFlagged) works unchanged
- Flag already handles cancellation atomically

**Disadvantages:**
- **Breaks value semantics contract.** Entry is `~Copyable` struct stored in a `Queue.Fixed`/`Queue`. Once enqueued, the entry is moved INTO the queue. You cannot arm it after enqueue because you no longer own it. The two-phase pattern requires the cell to be accessible BY KEY in a dictionary, not by position in a FIFO queue.
- **Optional continuation for all consumers.** Every existing `resumption(with:)` call would need to handle the `nil` case, even for consumers that always use single-phase. This is [PATTERN-020] false-security: the optional applies a runtime check for an invariant that single-phase consumers structurally guarantee.
- **Thread safety gap.** Entry is a struct with no internal synchronization. `arm()` would be a mutation. But in the IO pattern, `cancel()` can be called from ANY thread while `arm()` is called from the actor. Entry's Flag handles cross-thread cancellation, but `arm()` mutating the continuation field is not atomic. You'd need to either:
  - Make Entry a class (breaking ~Copyable value semantics)
  - Add an Atomic<Bool> for the armed state (duplicating Cell's design inside Entry)
  - Require arm() to happen before enqueue (but that defeats the purpose of two-phase)

### Option C: Extend Entry with a "pre-arm" factory

Keep Entry as-is, but add a factory that creates an unarmed wrapper:

```swift
struct Pending<Outcome: Sendable, Metadata: ~Copyable & Sendable>: ~Copyable, Sendable {
    let flag: Async.Waiter.Flag
    var metadata: Metadata

    func arm(_ continuation: Async.Continuation<Outcome>) -> Entry<Outcome, Metadata>?
}
```

**Advantages:**
- Entry stays unchanged
- Type system enforces that you can't enqueue a Pending (it's not an Entry)

**Disadvantages:**
- Doesn't solve the core problem: the IO pattern stores the waiter in a dictionary and arms LATER from a different context. `Pending` is a struct — once stored in the dictionary, arming requires mutable access. And `arm()` can race with `cancel()`.
- Fundamentally the same thread-safety problem as Option B

### Comparison

| Criterion | A: New Cell | B: Refactor Entry | C: Pending Factory |
|-----------|------------|-------------------|-------------------|
| Impact on existing consumers | None | All consumers handle Optional | None |
| Thread safety | Atomic class — safe | Struct mutation — unsafe | Struct mutation — unsafe |
| Semantic clarity | Two types, clear roles | One type, two modes | Three types |
| Storage model | Dictionary (by key) | Queue (by position) | Dictionary → Queue |
| Ownership model | Reference (class) | Value (~Copyable struct) | Value → Value |
| Complexity | Low (self-contained) | Medium (backwards compat) | High (conversion step) |
| Fits IO pattern | Yes — stored in dict, armed from actor, cancelled from any thread | No — struct can't be mutated after dict storage without & access | No — same mutation problem |

### The fundamental divergence

Entry and Cell serve **structurally different roles**:

| | Entry | Cell |
|--|-------|------|
| **Storage** | Queue position (FIFO) | Dictionary key |
| **Ownership** | Moved into queue, consumed on dequeue | Shared reference in dictionary |
| **Semantics** | Value type (~Copyable struct) | Reference type (class, Sendable) |
| **Lifecycle** | create → enqueue → dequeue → resume | create → store → arm → cancel? → drain |
| **Synchronization** | External lock for queue; Flag for cancel | Internal atomic state machine |
| **Continuation** | Bound at creation (always present) | Bound later (may be nil until armed) |

These are not the same abstraction parameterized differently. They are two distinct patterns that share the concept of "something that holds a continuation and can be cancelled."

## Outcome

**Status**: RECOMMENDATION

**Recommended**: Option A — new `Async.Waiter.Cell<T>` type.

**Rationale**: Entry and Cell serve fundamentally different storage and ownership models. Entry is a value type that flows through queues. Cell is a reference type that sits in dictionaries. Refactoring Entry to serve both roles (Option B) breaks its value semantics contract and introduces thread-safety issues that require re-inventing Cell's atomic state machine inside Entry anyway. Option C has the same mutation problem.

The naming distinction is clear:
- `Async.Waiter.Entry` — "I'm an entry in a waiter queue" (queue element)
- `Async.Waiter.Cell` — "I'm a waiter cell stored by key" (dictionary value)

**Proposed location**: `swift-async-primitives`, in a new `Async Waiter Primitives` file `Async.Waiter.Cell.swift`.

**Proposed API**:

```swift
extension Async.Waiter {
    public final class Cell<Outcome: Sendable>: @unchecked Sendable {
        public init()
        public func arm(_ continuation: Async.Continuation<Outcome>) -> Bool
        public func cancel()
        public func takeForResume() -> Take?
        public var wasCancelled: Bool { get }
        public var isArmed: Bool { get }
    }
}

extension Async.Waiter.Cell {
    public struct Take: ~Copyable, Sendable {
        public let continuation: Async.Continuation<Outcome>
        public let wasCancelled: Bool

        public consuming func resumption(with outcome: Outcome) -> Async.Waiter.Resumption
    }
}
```

**Impact**: Eliminates both `IO.Event.Waiter` and `IO.Completion.Waiter` from swift-io. The shared state machine moves from L3 to L1, available to any ecosystem consumer with the same pattern.

## References

- [data-structure-ecosystem-triage.md](../../swift-io/Research/data-structure-ecosystem-triage.md) — triage identifying the gap
- `Async.Waiter.Entry` — `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Waiter Primitives/Async.Waiter.Entry.swift`
- `IO.Event.Waiter` — `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO.Event.Waiter.swift`
- `Pool.Bounded` consumer — `/Users/coen/Developer/swift-primitives/swift-pool-primitives/Sources/Pool Bounded Primitives/Pool.Bounded.Acquire.swift`
