# Comparative Analysis: swift-dictionary-primitives vs. swift-io Dictionary Usage

<!--
---
date: 2026-02-24
scope: swift-dictionary-primitives, swift-io
type: replacement-opportunity analysis
status: RECOMMENDATION
---
-->

## 1. swift-dictionary-primitives Catalog

### 1.1 Type Hierarchy

```
Dictionary<Key: Hash.Protocol, Value: ~Copyable>          — unordered, slab-backed, O(1) removal
  ├── .Entry                                               — key-value pair (supports ~Copyable)
  └── .Ordered                                             — insertion-ordered, linear-backed, O(n) removal
        ├── .Entry                                         — key-value pair (supports ~Copyable)
        ├── .Bounded                                       — fixed-capacity, throws on overflow
        ├── .Static<let capacity: Int>                     — inline/zero-allocation, compile-time capacity
        └── .Small<let inlineCapacity: Int>                — inline with auto-spill to heap
```

### 1.2 Module Structure

| Module | Purpose |
|--------|---------|
| `Dictionary Primitives Core` | ~Copyable base types, no Sequence conformance |
| `Dictionary Ordered Primitives` | Sequence/Collection for `Dictionary.Ordered` (Value: Copyable) |
| `Dictionary Bounded Primitives` | Sequence/Collection for `Dictionary.Ordered.Bounded` (Value: Copyable) |
| `Dictionary Slab Primitives` | Sequence/Subscript/Drain for `Dictionary` unordered (Value: Copyable) |
| `Dictionary Primitives` | Umbrella re-export of all above |

### 1.3 API Surface (all variants)

**Common to all variants** (on ~Copyable path):
- `count`, `isEmpty`, `contains(_:)`
- `set(_:_:)` — insert or update
- `remove(_:)` -> Value? — remove by key
- `clear()` / `clear(keepingCapacity:)`
- `withValue(forKey:_:)` -> R? — borrow-based access
- `withValue(at:_:)` -> R — index-based borrow access
- `forEach(_:)` — borrow iteration
- `drain(_:)` — consuming iteration

**Copyable-only additions** (on Value: Copyable path):
- `subscript(key:)` -> Value? { get set }
- `subscript(at:)` -> (key: Key, value: Value) { get }
- Swift.Sequence, Collection, BidirectionalCollection, RandomAccessCollection
- Equatable, Hashable, CustomStringConvertible
- `merge.keep.first(_:)`, `merge.keep.last(_:)` (Ordered only)
- CoW semantics via `makeUnique()`

**Bounded/Static-only**:
- `isFull` — capacity check
- `throws(Error)` on `set` overflow

**What is NOT available**:
- No `subscript(key:, default:)` equivalent
- No `removeValue(forKey:)` (the method is `remove(_:)`)
- No `for (key, value) in dict where ...` filtering during iteration (relies on Swift.Sequence)
- No `.keys` iteration that returns `Swift.Dictionary.Keys` (returns `Set<Key>.Ordered`)
- No `mapValues`, `filter`, `compactMapValues`

### 1.4 Conditional Conformances

| Type | Copyable when... | Sendable when... |
|------|------------------|------------------|
| `Dictionary` | Value: Copyable | Key: Sendable, Value: Sendable |
| `Dictionary.Ordered` | Value: Copyable | Key: Sendable, Value: Sendable |
| `Dictionary.Ordered.Bounded` | Value: Copyable | Key: Sendable, Value: Sendable |
| `Dictionary.Ordered.Static` | **Never** (~Copyable always) | Key: Sendable, Value: Sendable |
| `Dictionary.Ordered.Small` | **Never** (~Copyable always) | Key: Sendable, Value: Sendable |

---

## 2. swift-io Dictionary Usage Inventory

### 2.1 IO.Handle.Registry (actor-isolated)

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.Handle.Registry.swift`

```swift
private var handles: [IO.Handle.ID: IO.Executor.Handle.Entry<Resource>] = [:]
```

**Key type**: `IO.Handle.ID` — custom Hashable struct (raw: UInt64, scope: UInt64, shard: UInt16).

**Value type**: `IO.Executor.Handle.Entry<Resource>` — class (reference type), where Resource: ~Copyable & Sendable.

**Operations used** (lines in parentheses):
- `handles[id]` — subscript get (451, 475, 586, 601, 630, 705, 764, 965)
- `handles[id] = entry` — subscript set (409, 429)
- `handles.removeValue(forKey: id)` — remove by key (458, 477, 877, 986, 989)
- `handles.removeAll()` — clear (373)
- `handles.count` — count (1019)
- `for (_, entry) in handles` — iteration during shutdown (344, 353)

**Access pattern**: Predominantly lookup-by-key and insert/remove. Iteration only during shutdown. Values are reference types (class). No ordering requirement.

**Concurrency**: Actor-isolated, no external synchronization needed. Values are class instances, so always Copyable at the storage level.

### 2.2 IO.Event.Selector (actor-isolated, 5 dictionaries)

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO.Event.Selector.swift`

#### 2.2.1 registrations

```swift
private var registrations: [ID: Registration] = [:]
```

**Operations**: subscript set (309), `removeValue(forKey:)` (743), `registrations.keys` iteration (1034), `removeAll()` (1037).

**Pattern**: Insert on register, remove on deregister, iterate keys on shutdown. Simple map, no ordering needed.

#### 2.2.2 waiters

```swift
private var waiters: [Permit.Key: Waiter] = [:]
```

**Operations**: subscript get (491, 894, 937), subscript set (455, 678), `removeValue(forKey:)` (748, 861, 908, 964), `waiters.keys where key.id == id` filtered iteration (747), `for (key, waiter) in waiters where waiter.wasCancelled` filtered iteration (860), `for (_, waiter) in waiters` full iteration (1012), `removeAll()` (1018).

**Pattern**: Hot path — insert/lookup/remove on every arm/event/cancel cycle. Filtered iteration for cancellation drain and deregistration. Most performance-critical dictionary in the system.

#### 2.2.3 permits

```swift
private var permits: [Permit.Key: IO.Event.Flags] = [:]
```

**Operations**: `removeValue(forKey:)` (445, 644, 760), subscript set (974, 991, 995).

**Pattern**: Write on event arrival, read-and-remove on arm. Classic permit/token store. No iteration.

#### 2.2.4 deadlineGeneration

```swift
private var deadlineGeneration: [Permit.Key: UInt64] = [:]
```

**Operations**: subscript get with default `[key, default: 0]` (462, 498, 704, 925), subscript set (705), subscript get (887, 935), `removeValue(forKey:)` (761), `removeAll()` (1022).

**Pattern**: Counter per key. Read-modify-write via `[key, default:]` pattern. Hot path on every arm/event cycle.

#### 2.2.5 pendingReplies

```swift
private var pendingReplies: [IO.Event.Registration.Reply.ID: CheckedContinuation<...>] = [:]
```

**Operations**: subscript set (297, 770), `removeValue(forKey:)` (841), `for (_, continuation) in pendingReplies` iteration (1028), `removeAll()` (1031).

**Pattern**: Insert on register/deregister request, remove on reply. Iteration only during shutdown. Low-frequency operations.

### 2.3 IO.Event.Registry (global Mutex-protected)

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO.Event.Registry.swift`

```swift
typealias Registry = Synchronization.Mutex<[Int32: [IO.Event.ID: IO.Event.Registration.Entry]]>
```

**Pattern**: Nested dictionary — outer keyed by file descriptor (Int32), inner keyed by event ID. Mutex-protected global singleton. Only used as a typealias with shared instance.

### 2.4 IO.Completion.Queue (actor-isolated)

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Completions/IO.Completion.Queue.swift`

```swift
private var entries: [IO.Completion.ID: Entry] = [:]
```

**Operations**: subscript set (261), subscript get (399, 442), `removeValue(forKey:)` (298), `for (id, _) in entries` iteration (473), `for (_, entry) in entries` iteration (479).

**Pattern**: Insert on submit, remove on completion. Iteration only during shutdown/cancel-all. Entry is a small struct containing a Waiter + Storage.

### 2.5 IO.Completion.IOCP.Registry (poll-thread-confined, Windows only)

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Completions/IO.Completion.IOCP.Registry.swift`

```swift
private var entries: [IO.Completion.ID: Entry] = [:]
```

**Operations**: subscript set via `entries[id] = entry` (134), subscript get (146), `removeValue(forKey:)` wrapped as `remove(id:)` (158), `entries.values` + `removeAll()` (167-169), `entries.count` (175).

**Pattern**: Insert-peek-remove lifecycle. Poll-thread-confined, no concurrent access. Windows only.

### 2.6 IO.Blocking.Threads.Acceptance.Queue

**File**: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift`

```swift
private var index: Dictionary<IO.Blocking.Ticket, Coordination>.Ordered.Bounded
```

**Already uses Dictionary Primitives.** This is the coordination plane in the three-plane acceptance queue design. Initialized with `try! .init(capacity: try! .init(capacity * 2))`.

**Operations**: `index.set(ticket, coord)` (133), `index.remove(ticket)` (158, 201, 240, 263), `index.clear()` (276), `for (_, coord) in index` filtered iteration (390-393 in debug invariant checking).

---

## 3. Replacement Assessment

### 3.1 Direct Replacement Candidates

#### 3.1.1 IO.Handle.Registry.handles — PARTIAL REPLACEMENT

**Current**: `[IO.Handle.ID: IO.Executor.Handle.Entry<Resource>]`

**Best candidate**: `Dictionary<IO.Handle.ID, IO.Executor.Handle.Entry<Resource>>` (unordered slab-backed).

**Fit assessment**:
- O(1) insert/lookup/remove: matches perfectly (slab positions are stable)
- `count`: available
- Iteration during shutdown: available via `forEach` and `drain`
- No ordering requirement: unordered `Dictionary` is ideal

**Blockers**:
1. **Value is a class type** — `IO.Executor.Handle.Entry<Resource>` is a `class`, so Value is always Copyable at the storage level. However, `Dictionary` in dictionary-primitives requires `Key: Hash.Protocol`, not `Key: Hashable`. If `IO.Handle.ID` does not conform to `Hash.Protocol`, it cannot be used directly.
2. **`removeValue(forKey:)` API** — Dictionary primitives use `remove(_:)` returning `Value?`. Semantically identical, but call sites would need renaming.
3. **`[key, default:]` subscript** — Not available. Not needed here (not used).
4. **`for (_, entry) in handles`** — Requires Copyable conformance to the Sequence bridge. Since values are class references (Copyable), this works via `Dictionary Slab Primitives`.

**Breaking changes**: Rename `removeValue(forKey:)` to `remove(key)` at all call sites. Conform `IO.Handle.ID` to `Hash.Protocol`.

**Verdict**: Feasible. Moderate effort. Benefits: stable positions, ~Copyable readiness for future value types.

#### 3.1.2 IO.Event.Selector.registrations — LOW PRIORITY

**Current**: `[ID: Registration]`

**Best candidate**: `Dictionary<ID, Registration>` (unordered).

**Assessment**: Low-frequency operations (register/deregister). Same blockers as 3.1.1 (Hash.Protocol conformance, API renaming). Low benefit — this dictionary is cold path.

**Verdict**: Feasible but low priority.

#### 3.1.3 IO.Completion.Queue.entries — PARTIAL REPLACEMENT

**Current**: `[IO.Completion.ID: Entry]`

**Best candidate**: `Dictionary<IO.Completion.ID, Entry>` (unordered).

**Assessment**: Similar to Handle.Registry. Insert/lookup/remove on every submit/complete cycle. Iteration only at shutdown.

**Blockers**: Same as 3.1.1.

**Verdict**: Feasible. Moderate effort.

#### 3.1.4 IO.Completion.IOCP.Registry.entries — DIRECT REPLACEMENT

**Current**: `[IO.Completion.ID: Entry]`

**Best candidate**: `Dictionary<IO.Completion.ID, Entry>` (unordered).

**Assessment**: Insert-peek-remove lifecycle matches perfectly. Poll-thread-confined, no concurrency concerns. `entries.values` iteration would become `forEach` or drain.

**Blockers**: Hash.Protocol conformance, API renaming.

**Verdict**: Cleanest replacement candidate. Isolated (Windows-only), low risk.

### 3.2 Problematic Replacement Candidates

#### 3.2.1 IO.Event.Selector.waiters — NOT DIRECTLY REPLACEABLE

**Current**: `[Permit.Key: Waiter]`

**Critical operations not supported by dictionary-primitives**:
1. **`for (key, waiter) in waiters where waiter.wasCancelled`** — Filtered iteration over key-value pairs. Dictionary primitives' `forEach` does not support `where` clauses natively. Would need to be rewritten as `forEach { key, value in if value.wasCancelled { ... } }` with deferred removal.
2. **`waiters.keys where key.id == id`** — Filtered iteration over keys matching a predicate. No direct equivalent.
3. **Mutation during iteration** — `drainCancelledWaiters()` removes entries while iterating. Swift.Dictionary tolerates this because `.keys` creates a snapshot. Dictionary primitives' `forEach` borrows the dictionary, preventing mutation. Would need `drain` or a collect-then-remove pattern.

**Assessment**: The waiter dictionary is the most performance-critical dictionary in the selector. The filtered-iteration-with-mutation pattern is deeply embedded in the event processing logic. Replacing it would require significant restructuring of the drain/cancel code paths.

**Required general-purpose additions**:
- `filter(_:)` -> Array or callback-based filtered drain
- `removeAll(where:)` — remove entries matching a predicate

**Verdict**: Not feasible without new primitives. High-risk refactor.

#### 3.2.2 IO.Event.Selector.permits — PARTIAL REPLACEMENT

**Current**: `[Permit.Key: IO.Event.Flags]`

**Assessment**: Pure insert/remove store, no iteration. Good candidate in principle.

**Blocker**: Uses `removeValue(forKey:)` which returns the removed value. Dictionary primitives' `remove(_:)` returns `Value?` — semantically identical but differently named.

**Verdict**: Feasible. Low risk.

#### 3.2.3 IO.Event.Selector.deadlineGeneration — NOT DIRECTLY REPLACEABLE

**Current**: `[Permit.Key: UInt64]`

**Critical missing API**: `dict[key, default: 0] += 1` — subscript with default value for read-modify-write. This pattern appears at lines 462, 498, 704, 925. Dictionary primitives have no `[key, default:]` subscript.

**Workaround**: Could use `withValue(forKey:)` for reads and `set(key, newValue)` for writes, but the read-modify-write idiom becomes two calls instead of one expression.

**Required general-purpose addition**:
- `subscript(key:, default:)` or equivalent `modify(key:, default:, transform:)` method

**Verdict**: Not feasible without new primitives. The `[key, default:]` pattern is too ergonomic to give up.

#### 3.2.4 IO.Event.Selector.pendingReplies — LOW PRIORITY

**Current**: `[IO.Event.Registration.Reply.ID: CheckedContinuation<...>]`

**Assessment**: Low-frequency. Insert on request, remove on reply. Iteration only at shutdown.

**Blocker**: CheckedContinuation is not ~Copyable — it requires `Copyable` values, which is fine for dictionary-primitives' Copyable path.

**Verdict**: Feasible but no compelling reason to change.

#### 3.2.5 IO.Event.Registry — NOT REPLACEABLE

**Current**: `Mutex<[Int32: [IO.Event.ID: IO.Event.Registration.Entry]]>`

**Assessment**: Nested dictionary pattern. Dictionary-primitives does not support nested dictionaries natively. Would need `Dictionary<Int32, Dictionary<IO.Event.ID, Entry>>` — each inner dictionary would need to be heap-allocated (since `Dictionary` is conditionally Copyable). The Mutex wrapping adds another layer of complexity.

**Verdict**: Not a candidate. Keep as Swift.Dictionary.

### 3.3 Already Using Dictionary Primitives

#### 3.3.1 IO.Blocking.Threads.Acceptance.Queue.index

**Current**: `Dictionary<IO.Blocking.Ticket, Coordination>.Ordered.Bounded`

**Status**: Already migrated. Uses the correct primitive for its bounded, ordered, O(1)-cancellation semantics.

---

## 4. Gap Analysis: Missing Primitives

| Gap | Swift.Dictionary feature | Dictionary-primitives equivalent | Impact |
|-----|-------------------------|----------------------------------|--------|
| G-1 | `dict[key, default: defaultValue]` | None | Blocks deadlineGeneration replacement |
| G-2 | `removeValue(forKey:)` naming | `remove(_:)` exists (same semantics) | API naming friction only |
| G-3 | `for (k, v) in dict where predicate` | No filtered iteration | Blocks waiters replacement |
| G-4 | `removeAll(where:)` | None | Blocks waiters replacement |
| G-5 | Mutation during `for-in` iteration | `drain` consumes; `forEach` borrows | Blocks waiters replacement |
| G-6 | `Key: Hashable` | `Key: Hash.Protocol` | Migration friction for all IO types |
| G-7 | Nested dictionary `[K1: [K2: V]]` | None | Blocks Registry replacement |

### 4.1 Recommended Additions to Dictionary Primitives

**High impact (unblocks 4+ replacements)**:

1. **`Hash.Protocol` conformance bridge** — Either provide a blanket conformance `extension Hash.Protocol where Self: Hashable` or add a protocol-bridging adapter. Without this, every IO key type needs explicit `Hash.Protocol` conformance. This is the single largest blocker.

2. **`subscript(key:, default:)` for Copyable values** — Enables the read-modify-write pattern used pervasively in the Selector. Implementation: `func subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value { get set }`.

**Medium impact (enables cleaner replacements)**:

3. **`removeAll(where:)` on unordered Dictionary** — Removes entries matching a predicate. For slab-backed storage, this iterates occupied slots and removes matching ones. Enables the waiter drain pattern.

4. **Filtered forEach** — `forEach(where:)` or equivalent that allows borrowing iteration with a predicate. Combined with a separate removal pass, this replaces the `for (k, v) in dict where ...` pattern.

**Low impact (nice-to-have)**:

5. **`values` collection accessor on unordered Dictionary** — For the IOCP registry's `Array(entries.values)` pattern. Currently only available on `Dictionary.Ordered`.

---

## 5. Prioritized Replacement Roadmap

### Phase 0: Foundation (no swift-io changes)

1. Add `Hash.Protocol` conformance for standard Hashable types, OR document the bridging pattern for custom types.
2. Add `subscript(key:, default:)` to `Dictionary` and `Dictionary.Ordered` for Copyable values.
3. Add `removeAll(where:)` to `Dictionary` (unordered).

### Phase 1: Low-Risk Replacements

| Target | Risk | Effort | Benefit |
|--------|------|--------|---------|
| IO.Completion.IOCP.Registry | Low | Small | Validation of approach, Windows-isolated |
| IO.Event.Selector.permits | Low | Small | Pure insert/remove, no iteration |

### Phase 2: Medium-Risk Replacements

| Target | Risk | Effort | Benefit |
|--------|------|--------|---------|
| IO.Handle.Registry.handles | Medium | Medium | ~Copyable readiness, stable positions |
| IO.Completion.Queue.entries | Medium | Medium | Stable positions, O(1) removal |

### Phase 3: High-Risk (Deferred)

| Target | Risk | Effort | Benefit |
|--------|------|--------|---------|
| IO.Event.Selector.waiters | High | Large | Requires G-3, G-4, G-5 gaps filled |
| IO.Event.Selector.deadlineGeneration | Medium | Small | Requires G-1 gap filled |
| IO.Event.Registry | High | N/A | Not recommended — nested dict pattern |

---

## 6. Summary

**Current state**: 1 of 10 dictionary usages in swift-io already uses dictionary-primitives (Acceptance.Queue.index).

**Immediately replaceable** (after Hash.Protocol bridging): 2 dictionaries (IOCP.Registry, permits).

**Replaceable with moderate effort**: 3 dictionaries (Handle.Registry, Completion.Queue, registrations).

**Blocked on new primitives**: 3 dictionaries (waiters, deadlineGeneration, pendingReplies).

**Not candidates**: 1 dictionary (Event.Registry nested dict).

**Critical enabler**: Hash.Protocol bridging for Hashable types. Without this, zero replacements are practical because every key type in swift-io conforms to `Hashable`, not `Hash.Protocol`.

**Highest-value single addition**: `subscript(key:, default:)` — unblocks deadlineGeneration and improves ergonomics for all counter/accumulator patterns.
