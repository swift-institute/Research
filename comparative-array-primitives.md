# Comparative Analysis: swift-array-primitives vs swift-io Array Usage

<!--
---
version: 1.0.0
date: 2026-02-24
scope: Layer 1 (Primitives) × Layer 3 (Foundations)
status: RECOMMENDATION
---
-->

## 1. swift-array-primitives Type Catalog

Six modules, re-exported through `Array_Primitives`:

### 1.1 Array (Growable, Heap-Allocated)

| Property | Value |
|----------|-------|
| **Backing** | `Buffer<Element>.Linear` (ManagedBuffer, CoW) |
| **Count** | Variable, 0…∞ |
| **Storage** | Heap |
| **~Copyable** | Element and Array itself |
| **Sendable** | Conditional (`Element: Sendable`) |
| **Module** | `Array_Dynamic_Primitives` |

Equivalent to `Swift.Array` but with `~Copyable` element support. Shadows `Swift.Array`.

### 1.2 Array.Fixed (Fixed-Count, Heap-Allocated)

| Property | Value |
|----------|-------|
| **Backing** | `Buffer<Element>.Linear.Bounded` (ManagedBuffer, CoW) |
| **Count** | Fixed at init, cannot grow or shrink |
| **Storage** | Heap |
| **~Copyable** | Element and Fixed itself |
| **Sendable** | Conditional |
| **Key API** | `init(count:initializingWith:)`, `init(repeating:count:)` |
| **Module** | `Array_Fixed_Primitives` |

Provides `Array.Fixed.Indexed<Tag>` for phantom-typed index access. Supports `Span` and `MutableSpan`. Conforms to `Swift.RandomAccessCollection` when `Element: Copyable`.

### 1.3 Array.Static (Fixed-Capacity, Inline Storage)

| Property | Value |
|----------|-------|
| **Backing** | `Buffer<Element>.Linear.Inline<capacity>` |
| **Count** | Variable, 0…capacity |
| **Storage** | Inline (stack) |
| **~Copyable** | Unconditionally (has deinit) |
| **Sendable** | Conditional |
| **Constraints** | Max element stride 64 bytes, alignment ≤ `MemoryLayout<Int>.alignment` |
| **Module** | `Array_Static_Primitives` |

Equivalent to C++'s `static_vector` / Rust's `ArrayVec`. No heap allocation.

### 1.4 Array.Small (SmallVec Pattern)

| Property | Value |
|----------|-------|
| **Backing** | `Buffer<Element>.Linear.Small<inlineCapacity>` |
| **Count** | Variable, 0…∞ (spills to heap) |
| **Storage** | Inline up to `inlineCapacity`, then heap |
| **~Copyable** | Element and Small itself |
| **Sendable** | (inherits from buffer) |
| **Module** | `Array_Small_Primitives` |

### 1.5 Array.Bounded (Compile-Time Dimensioned, Heap-Allocated)

| Property | Value |
|----------|-------|
| **Backing** | `Buffer<Element>.Linear.Bounded` |
| **Count** | Fixed at N (value generic) |
| **Storage** | Heap (CoW) |
| **Index type** | `Algebra.Z<N>` — compile-time bounded |
| **~Copyable** | Element and Bounded itself |
| **Module** | `Array_Bounded_Primitives` |

Index construction is bounds-checked; subscript access is then guaranteed safe.

### 1.6 Array.Inline (Typealias)

| Property | Value |
|----------|-------|
| **Definition** | `typealias Inline<let N: Int> = Swift.InlineArray<N, Element>` |
| **Count** | Fixed (always N) |
| **Storage** | Inline |

Not a custom type — just a namespace-consistent alias to `Swift.InlineArray`.

---

## 2. swift-io Array Usage Sites

### 2.1 Fixed-at-init arrays (`private let … [T]`)

These are set once during initialization and never mutated afterward.

#### 2.1.1 IO.Executor.Shards — `registries`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO/IO.Executor.Shards.swift:56`

```swift
private let registries: [IO.Handle.Registry<Resource>]
```

- Created via `(0..<count).map { ... }` in `init`
- Accessed by index via `registries[shardIndex]`, `registries[Int(id.shard)]`
- Iterated in `shutdown()` for concurrent teardown
- Count accessed via `registries.count`
- **Never mutated after init.**

#### 2.1.2 IO.Blocking.Lane.Sharded.Selector — `threads`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Lane.Sharded.Selector.swift:20`

```swift
private let threads: [IO.Blocking.Threads]
```

- Created from `init(threads:selection:)` parameter
- Accessed by index via `threads[index]`
- Count accessed via `threads.count`
- **Never mutated after init.**

#### 2.1.3 IO.Blocking.Lane.Sharded.Snapshot.Storage — `threads`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Lane.Sharded.Snapshot.Storage.swift:21`

```swift
private let threads: [IO.Blocking.Threads]
```

- Created from `init(threads:)` parameter
- Accessed by index via `threads[lane].state.gauge.*`
- Count stored separately as `laneCount`
- **Never mutated after init.**

#### 2.1.4 IO.Blocking.Lane.sharded (generic) — `lanes` (captured)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking/IO.Blocking.Lane.swift:244-267`

```swift
let lanes = (0..<Int(laneCount)).map { _ in make() }
// ... captured in closures:
let lane = lanes[Int(index % UInt64(lanes.count))]
```

- Created via `.map` and captured by value in closures
- Accessed by index with modular arithmetic
- Iterated in shutdown
- **Never mutated after creation.**

#### 2.1.5 IO.Blocking.Lane.sharded (NUMA-aware) — `threads` (captured)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Lane.Sharded+Threads.swift:58,146`

```swift
let threads = (0..<Int(laneCount)).map { make($0) }
let threads = nodes.map { make($0) }
```

- Same pattern as 2.1.4 — created, captured, never mutated.

#### 2.1.6 IO.Blocking.Lane.sharded (NUMA) — `nodes`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Lane.Sharded+Threads.swift:123`

```swift
let nodes: [System.Topology.NUMA.Node]
```

- Created from topology detection switch
- Iterated once via `.map` to create threads
- **Never mutated; short-lived.**

### 2.2 Pre-allocated reusable scratch buffers

These are allocated once and reused across iterations with `removeAll(keepingCapacity: true)`.

#### 2.2.1 IO.Event.Poll.Loop — `eventBuffer`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Poll.Loop.swift:63-66`

```swift
var eventBuffer = [IO.Event](
    repeating: .empty,
    count: driver.capabilities.maxEvents
)
```

- Pre-allocated to `maxEvents` capacity
- Written into via `driver.poll(handle, deadline:, into: &eventBuffer)`
- Read from via `eventBuffer.withUnsafeBufferPointer` for memcpy to pool
- Size never changes; contents overwritten each iteration
- **Fixed-capacity scratch buffer.**

#### 2.2.2 IO.Completion.Poll — `submissionBuffer` and `eventBuffer`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Poll.swift:52-56`

```swift
var submissionBuffer: [IO.Completion.Operation.Storage] = []
submissionBuffer.reserveCapacity(driver.capabilities.maxSubmissions)

var eventBuffer: [IO.Completion.Event] = []
eventBuffer.reserveCapacity(driver.capabilities.maxCompletions)
```

- Pre-allocated with `reserveCapacity`, then `removeAll(keepingCapacity: true)` + `append(contentsOf:)` each loop
- Variable element count per iteration (0 to capacity)
- **Growable but bounded in practice.**

#### 2.2.3 IO.Event.Poll.Operations (epoll) — `rawEvents`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Poll.Operations.swift:229-232`

```swift
var rawEvents = [Kernel.Event.Poll.Event](
    repeating: ...,
    count: buffer.count
)
```

- Local scratch buffer for kernel event conversion
- Allocated per `poll()` call (not reused across calls)
- Size matches input buffer size
- **Ephemeral fixed-size buffer.**

### 2.3 Growable runtime arrays

#### 2.3.1 IO.Blocking.Threads.Runtime — `threads`

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Runtime.swift:24`

```swift
private(set) var threads: [Kernel.Thread.Handle.Reference] = []
```

- Starts empty
- Appended to during `start()` (one per worker + deadline manager)
- Iterated during `joinAllThreads()`, then `removeAll()`
- **Grows once during startup, fixed afterward until shutdown.**

### 2.4 Drain-result arrays

#### 2.4.1 Queue.drain() return values

**Files**:
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Registration.Queue.swift:26-33`
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Submission.Queue.swift:25-34`

```swift
public func drain<Element>() -> [Element] {
    mutable.value.withLock { deque in
        var elements: [Element] = []
        elements.reserveCapacity(...)
        deque.drain { elements.append($0) }
        return elements
    }
}
```

- Ephemeral arrays returned from `drain()`, immediately iterated by caller
- Size varies per drain
- **Transient collection; not storage.**

---

## 3. Replacement Assessment

### 3.1 Fixed-at-init arrays → `Array.Fixed`

**Sites**: 2.1.1 through 2.1.5 (Shards.registries, Selector.threads, Storage.threads, captured lanes/threads)

**Fit**: STRONG

| Criterion | Assessment |
|-----------|------------|
| Count known at init | Yes — always created from a range or `.map` |
| Never mutated | Yes — all are `let` bindings |
| Index-accessed | Yes — `registries[shardIndex]`, `threads[index]`, etc. |
| Iterated | Yes — `for registry in registries`, `for lane in lanes` |
| Count queried | Yes — `.count` used for modular arithmetic |
| Element is Copyable | Mostly — `IO.Handle.Registry` is a class (reference type), `IO.Blocking.Threads` is a class, `IO.Blocking.Lane` is a Sendable struct |
| Element is Sendable | Yes — all captured in `@Sendable` closures |

**Benefits of `Array.Fixed`**:

1. **Semantic clarity**: `Array.Fixed` communicates "this collection never grows or shrinks" in the type system. Currently, this invariant exists only in documentation and `let` binding.

2. **No accidental mutation**: `Array.Fixed` prevents `append`, `insert`, `remove` at compile time. The current `[T]` only prevents mutation because of `let` — a refactoring to `var` would silently break the invariant.

3. **CoW overhead**: Both `Swift.Array` and `Array.Fixed` use CoW. Since these are all `let` bindings on classes (`final class Shards`, `final class Selector`, `final class Storage`), there is no CoW overhead for either — the reference count is 1. **No performance difference.**

4. **API compatibility**: `Array.Fixed` conforms to `Swift.RandomAccessCollection` when `Element: Copyable`, so `for-in`, `.count`, and subscript all work identically.

**Obstacles**:

1. **Construction**: `Array.Fixed.init(count:initializingWith:)` takes `Array.Index.Count` (typed count) rather than `Int`. The `.map` pattern `(0..<count).map { ... }` would need to become the initializer-closure pattern:
   ```swift
   try Array<IO.Handle.Registry<Resource>>.Fixed(
       count: Array.Index.Count(UInt(count)),
       initializingWith: { index in
           IO.Handle.Registry<Resource>(
               lane: laneFactory(),
               policy: policy,
               shardIndex: UInt16(Int(bitPattern: index))
           )
       }
   )
   ```

2. **Dependency**: swift-io (Layer 3) would need to depend on `Array_Primitives` (Layer 1). This is architecturally valid (downward dependency), but adds a new import.

3. **Captured `let` arrays**: Sites 2.1.4 and 2.1.5 capture the array in closures. `Array.Fixed` is `Copyable` when `Element: Copyable`, so capture works for reference-type elements. For `IO.Blocking.Lane` (a struct), capture also works since `Lane: Sendable` and `Array.Fixed: @unchecked Sendable where Element: Sendable`.

**Verdict**: Replacement is viable and architecturally sound. The benefit is semantic (expressing the fixed-size invariant in the type system) rather than performance-based. Worth doing for the three stored-property sites (Shards, Selector, Storage) where the type annotation is visible to readers. Less valuable for the two captured-local sites where the `let` binding already communicates immutability.

### 3.2 Pre-allocated scratch buffers

#### 3.2.1 Event poll loop `eventBuffer` → `Array.Fixed`?

**File**: IO.Event.Poll.Loop.swift:63

This buffer is created at a runtime-determined size (`driver.capabilities.maxEvents`), pre-filled with `.empty`, and overwritten each poll iteration via `inout [IO.Event]` parameter. The count never changes.

**Fit**: MODERATE

- `Array.Fixed` would express the invariant that the buffer never grows/shrinks.
- **Obstacle**: The `driver.poll` API takes `inout [IO.Event]`. Changing this to `inout Array<IO.Event>.Fixed` would ripple through the `IO.Event.Driver` protocol witness. This is a much larger change.
- The buffer is immediately memcpy'd to a pool slot via `withUnsafeBufferPointer`. `Array.Fixed` provides `withUnsafeBufferPointer` for `Copyable` elements, so this works.

**Verdict**: Viable but requires coordinated API change across the driver interface. Consider for a future driver API revision, not as a standalone change.

#### 3.2.2 Completion poll buffers → No change

**File**: IO.Completion.Poll.swift:52-56

These use `removeAll(keepingCapacity: true)` + `append(contentsOf:)` — variable element count each iteration. This is genuinely dynamic behavior.

**Fit**: POOR — these need growable semantics. `Array.Fixed` does not support append.

#### 3.2.3 Epoll rawEvents → `Array.Fixed` or `Array.Inline`?

**File**: IO.Event.Poll.Operations.swift:229

Created with `repeating:count:` at a known size, then passed as `inout` to `Kernel.Event.Poll.wait`. Ephemeral — created and consumed within a single function call.

**Fit**: WEAK — the buffer is local and short-lived. The overhead of typed construction outweighs the semantic benefit. Additionally, the count comes from `buffer.count` (runtime), so `Array.Inline` (compile-time N) does not apply.

### 3.3 Growable runtime array → No change

**File**: IO.Blocking.Threads.Runtime.swift:24

The `threads` array starts empty and grows during `start()`. It needs `append`. This is correctly modeled as a growable array.

**Fit**: NONE — this is genuinely dynamic.

### 3.4 Drain-result arrays → No change

**Files**: Registration.Queue.swift, Submission.Queue.swift

These are ephemeral return values with variable size. They are consumed immediately by the caller.

**Fit**: NONE — transient, variable-size results.

---

## 4. Recommendations

### 4.1 Immediate Replacements (Low Risk, High Clarity)

| Site | Current | Proposed | Benefit |
|------|---------|----------|---------|
| `IO.Executor.Shards.registries` | `[IO.Handle.Registry<Resource>]` | `Array<IO.Handle.Registry<Resource>>.Fixed` | Type-level immutability invariant |
| `Selector.threads` | `[IO.Blocking.Threads]` | `Array<IO.Blocking.Threads>.Fixed` | Type-level immutability invariant |
| `Snapshot.Storage.threads` | `[IO.Blocking.Threads]` | `Array<IO.Blocking.Threads>.Fixed` | Type-level immutability invariant |

These three are stored properties on `final class` types, visible in type declarations, and would benefit most from expressing the fixed-size contract.

### 4.2 Deferred (Requires API Coordination)

| Site | Current | Proposed | Blocker |
|------|---------|----------|---------|
| Poll loop `eventBuffer` | `[IO.Event]` | `Array<IO.Event>.Fixed` | Driver `poll` API takes `inout [IO.Event]` |
| Captured lane arrays | `[IO.Blocking.Lane]` | `Array<IO.Blocking.Lane>.Fixed` | Local captures; benefit is marginal |

### 4.3 No Change

| Site | Reason |
|------|--------|
| Completion poll buffers | Dynamic append/remove semantics required |
| Threads.Runtime.threads | Grows during startup via append |
| Queue.drain() results | Ephemeral, variable-size |
| Epoll rawEvents | Short-lived local; not worth typed overhead |

### 4.4 General-Purpose Additions for IO's Needs

No new types are needed. The existing `Array.Fixed` covers all identified fixed-at-init cases. Two ergonomic improvements would smooth adoption:

1. **`Array.Fixed.init(fromSequence:count:)`** — A convenience initializer that consumes a `Sequence` and validates the count matches. This would replace the `(0..<n).map { ... }` pattern directly without forcing callers to restructure into index-based initialization closures.

2. **`Array.Fixed.init(fromArray:)` / `init(_ array: consuming Swift.Array<Element>)`** — A conversion initializer from `Swift.Array` that freezes a dynamic array into a fixed one. This enables gradual migration: callers can continue using `.map` patterns and freeze the result.

---

## 5. Summary

swift-array-primitives provides exactly the type (`Array.Fixed`) needed to express the "set once at init, never mutated" invariant that appears in three key swift-io infrastructure classes. The replacement is architecturally valid (Layer 1 → Layer 3), provides compile-time immutability enforcement, and requires no behavioral changes. The main cost is construction ergonomics — the `.map` pattern must be adapted to the initializer-closure pattern, or convenience initializers should be added to smooth the transition.

The benefit is semantic, not performance: both `Swift.Array` and `Array.Fixed` use CoW, and in these `let`-binding-on-class scenarios, neither triggers CoW overhead. The value is in making the fixed-size invariant visible in the type system, preventing accidental mutation during future refactoring.
