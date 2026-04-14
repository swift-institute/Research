# Comparative Analysis: Bitset/Bit-Vector Primitives vs. swift-io Bit-Level Patterns

<!--
---
status: DECISION
date: 2026-02-24
scope: swift-bitset-primitives, swift-bit-vector-primitives, swift-io
---
-->

## 1. Primitives Inventory

### 1.1 swift-bitset-primitives

The bitset package provides four set-of-integers variants, all Copyable and Sendable:

| Type | Storage | Capacity | Growth |
|------|---------|----------|--------|
| `Bitset` | `ContiguousArray<UInt>` | Dynamic | Auto-grow on insert |
| `Bitset.Fixed` | `ContiguousArray<UInt>` | Fixed (heap) | Throws on overflow |
| `Bitset.Static<let wordCount: Int>` | `InlineArray<wordCount, UInt>` | Compile-time | Throws on overflow |
| `Bitset.Small<let inlineWordCount: Int>` | `InlineArray` + optional `ContiguousArray` | Inline with spill | Auto-spill to heap |

**Operations per variant:**

- **Membership**: `contains(_:)`, `insert(_:)`, `remove(_:)`, `removeAll()`, `clear()`
- **Properties**: `count` (popcount), `isEmpty`, `capacity`, `min`, `max`
- **Iteration**: `Sequence` conformance via `Bitset.Iterator` (Wegner/Kernighan sparse), `forEach(_:)`
- **Set Algebra** (via `.algebra` accessor): `union(_:)`, `intersection(_:)`, `subtract(_:)`, `symmetric.difference(_:)`
- **Set Relations** (via `.relation` accessor): `isSubset(of:)`, `isSuperset(of:)`, `isDisjoint(with:)`
- **Mutating algebra**: `form { $0.union(other) }`
- **Protocols**: `Equatable`, `Hashable`, `CustomStringConvertible`, `Sequence`

All errors use typed throws: `__BitsetError`, `__BitsetFixedError`, `__BitsetStaticError`, `__BitsetSmallError`.

### 1.2 swift-bit-vector-primitives

The bit-vector package provides five packed-bit-array variants:

| Type | Storage | Capacity | Copyability | Growth |
|------|---------|----------|-------------|--------|
| `Bit.Vector` | `UnsafeMutablePointer<UInt>` | Fixed | `~Copyable` | None |
| `Bit.Vector.Static<let wordCount: Int>` | `InlineArray<wordCount, UInt>` | Compile-time | Copyable | None |
| `Bit.Vector.Bounded` | `ContiguousArray<UInt>` | Fixed (heap) | Copyable | Throws on overflow |
| `Bit.Vector.Inline<let wordCount: Int>` | `InlineArray<wordCount, UInt>` | Compile-time | Copyable | Throws on overflow |
| `Bit.Vector.Dynamic` | `ContiguousArray<UInt>` | Dynamic | Copyable | Auto-grow |

**Protocol**: `Bit.Vector.Protocol` (supports `~Copyable` conformers) with requirements:
- `var bitCapacity: Bit.Index.Count`
- `borrowing func word(at index: Int) -> UInt`
- `mutating func setWord(at index: Int, to value: UInt)`
- `subscript(index: Bit.Index) -> Bool { get set }`

**Default implementations** (via Protocol extension):
- `var wordCount: Int`
- `var popcount: Bit.Index.Count` (hardware popcount)
- `var allFalse: Bool`, `var allTrue: Bool`, `var any: Bool`
- `static func clearAll(_:)`, `static func setAll(_:)`
- `mutating func popFirst() -> Bit.Index?` (Wegner/Kernighan)

**Property.View accessors**:
- `.pop.first()` — pop lowest set bit
- `.set.all()`, `.set.range(_:)` — bulk set
- `.clear.all()`, `.clear.range(_:)` — bulk clear

**Iteration**:
- `.ones` — `Ones.View` for iterating set bits (non-mutating, safe from deinit)
- `.zeros` — `Zeros.View` for iterating clear bits
- Per-variant `Sequence` conformances via `Ones.*.Iterator` and `Zeros.*.Iterator`
- `toggle(_:)` — XOR single bit

**Key difference from Bitset**: Bit.Vector models a *packed boolean array* (indexed by `Bit.Index`) while Bitset models a *set of non-negative integers* (indexed by `Int`). The API surfaces reflect this: Bit.Vector has `subscript`, `append`, `popFirst`; Bitset has `insert`, `remove`, `contains`, set algebra.

### 1.3 Sibling Packages

| Package | Purpose |
|---------|---------|
| `swift-bit-primitives` | `Bit` type, `Bit.Order`, `Bit.Value`, `Bit.Mask`, `Bit.Set`, boolean algebra, bitwise operators |
| `swift-bit-index-primitives` | `Bit.Index`, `Bit.Index.Count`, byte-to-bit ratios |
| `swift-bit-pack-primitives` | `Bit.Pack<Word>`, `Bit.Pack.Location`, `Bit.Pack.Words`, `Bit.Pack.Bits` — word/bit decomposition |

### 1.4 Existing Usage: Slab via Buffer.Slab

The `Slab<Element>` primitive already uses `Bit.Vector` internally through `Buffer<Element>.Slab.Bounded`:
- `header.bitmap` is a `Bit.Vector` (the ~Copyable, pointer-backed variant)
- `occupancy` → `bitmap.popcount`
- `isEmpty` → `bitmap.popcount == .zero`
- `isFull` → `bitmap.popcount >= bitmap.capacity.maximum`
- `isOccupied(at:)` → `bitmap[slot]`
- `firstVacant(max:)` → `bitmap.zeros.first(max:)`

This is the canonical example of Bit.Vector serving as infrastructure bitmap in a data structure.

---

## 2. swift-io Bit-Level Pattern Inventory

### 2.1 Waiter State Machines (Two Instances)

**Files**:
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Waiter.State.swift` (lines 17-34)
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Waiter.swift` (lines 51-68)

Both implement the same pattern:

```swift
struct State: RawRepresentable, AtomicRepresentable, Equatable {
    var rawValue: UInt8
    static let unarmed          = State(rawValue: 0b000)
    static let cancelledUnarmed = State(rawValue: 0b001)
    static let armed            = State(rawValue: 0b010)
    static let armedCancelled   = State(rawValue: 0b011)
    static let drained          = State(rawValue: 0b110)
    static let cancelledDrained = State(rawValue: 0b111)

    var isCancelled: Bool { rawValue & 0b001 != 0 }
    var isArmed: Bool     { rawValue & 0b010 != 0 }
    var isDrained: Bool   { rawValue & 0b100 != 0 }
}
```

This is a 3-bit state machine where each bit is an independent flag:
- Bit 0: cancelled
- Bit 1: armed (continuation bound)
- Bit 2: drained (continuation taken)

Used with `Atomic<State>` via `compareExchange` for lock-free state transitions.

### 2.2 Blocking Lane Job State

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking/IO.Blocking.Lane.Abandoning.Job.State.swift` (lines 10-20)

```swift
enum State: UInt8, AtomicRepresentable {
    case pending = 0
    case running = 1
    case completed = 2
    case timeout = 3
    case cancelled = 4
    case failed = 5
}
```

This is a linear state machine (enum, not a bitset). States are mutually exclusive.

### 2.3 Completion Flags (OptionSet)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Flags.swift` (lines 21-46)

```swift
public struct Flags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public static let more         = Flags(rawValue: 1 << 0)
    public static let bufferSelect = Flags(rawValue: 1 << 1)
    public static let shortCount   = Flags(rawValue: 1 << 2)
}
```

3 independent flags packed into `UInt8`, using Swift's `OptionSet`.

### 2.4 Completion Kind Set (OptionSet)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Kind.Set.swift` (lines 19-68)

```swift
public struct Set: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16
}
```

Capability set of operation kinds (nop, read, write, accept, connect, send, recv, fsync, close, cancel, wakeup).

### 2.5 Half-Close State (OptionSet)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Channel.HalfClose.State.swift` (lines 8-22)

```swift
struct State: OptionSet, Sendable {
    let rawValue: UInt8
    static let read  = State(rawValue: 1 << 0)
    static let write = State(rawValue: 1 << 1)
}
```

2 independent flags: read-closed and write-closed.

### 2.6 Shutdown Flag (Atomic)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Poll.Shutdown.Flag.swift` (lines 11-17)

```swift
public typealias Flag = Tagged<IO.Completion.Poll.Shutdown, Kernel.Atomic.Flag>
```

Single atomic boolean via `Kernel.Atomic.Flag`.

### 2.7 Metrics Counters

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Metrics.swift` (lines 35-73)

9 independent `Cell` instances (each wrapping `Atomic<UInt64>`), with nested accessor structs for fluent API. Not a bitset — these are monotonic counters.

### 2.8 Advisory Gauges

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift` (lines 406-419)

3 independent `Atomic<Int>` values for lock-free reads. Not a bitset.

### 2.9 Executor Handle State

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO/IO.Executor.Handle.State.swift` (lines 34-41)

Linear state enum with associated data (`reserved(waiterToken:)`). Not bit-based.

### 2.10 Slab Bitmap (via Acceptance Queue)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift`

Uses `Slab<Entry>` (which internally uses `Bit.Vector` bitmap). Already leveraging bit-vector primitives transitively.

---

## 3. Assessment

### 3.1 Could Bitset Replace Waiter State Machines?

**Verdict: No.**

The waiter state machines (`IO.Event.Waiter.State`, `IO.Completion.Waiter.State`) use 3 bits packed into a `UInt8` with `AtomicRepresentable` conformance for lock-free `compareExchange` operations. This is a fundamentally different use case from what Bitset provides:

1. **AtomicRepresentable requirement**: The entire state must be atomically loaded, compared, and exchanged as a single unit. Bitset variants are not `AtomicRepresentable` and cannot be — they use multi-word storage. The waiter needs `Atomic<State>` with CAS, not a set collection.

2. **Semantic mismatch**: These are *state machines*, not *sets*. The "bits" represent a compound state where certain combinations are valid (armed|cancelled) and others are invalid. The bit layout encodes this efficiently, but the intent is "atomic state machine" not "set of members". Set operations (union, intersection) are meaningless here.

3. **Already optimal**: The hand-rolled `UInt8` with 3-bit layout is as minimal as possible. Any wrapper type would add indirection without benefit. The code is clear, documented, and correct.

4. **What would help**: A general-purpose `AtomicStateMachine<Flags>` primitive that encodes flag-based state machines with compile-time validation of legal transitions. But that is a different abstraction than Bitset.

### 3.2 Could Event Flags Benefit from a Typed Bitset?

**Verdict: No — `OptionSet` is the correct abstraction.**

Three sites use `OptionSet`:
- `IO.Completion.Flags` (3 flags in `UInt8`)
- `IO.Completion.Kind.Set` (11 kinds in `UInt16`)
- `IO.Event.Channel.HalfClose.State` (2 flags in `UInt8`)

These are all:
1. **Fixed, small flag sets** — 2-11 members, fitting in a single integer
2. **Using Swift's built-in OptionSet** — which provides `contains`, `union`, `intersection`, `subtract` for free
3. **Value types with no allocation** — trivially Copyable, hashable, sendable

Bitset would be a *downgrade*:
- Bitset uses `ContiguousArray<UInt>` (heap allocation) or `InlineArray` (unnecessary complexity for <=16 flags)
- OptionSet is a stdlib protocol, universally understood
- No additional operations from Bitset are needed — these never need iteration over set bits, popcount, or min/max

`Bitset.Static<1>` could technically replace them, but provides no benefit over `OptionSet` while adding a dependency and using a less idiomatic API. The current code is correct.

### 3.3 Could Counters Use Bitset or Bit-Vector?

**Verdict: No.**

The counters in `IO.Blocking.Threads.Counters` are 9 independent monotonic `Atomic<UInt64>` values. They track quantities (enqueued, started, completed, etc.), not membership. Neither Bitset (set of integers) nor Bit.Vector (packed boolean array) is applicable.

Similarly, the advisory gauges (`Gauge.Storage`) are independent `Atomic<Int>` values for queue depth, acceptance depth, and sleeper count. These are scalar metrics, not bit-level structures.

### 3.4 Could Slab Occupancy Tracking Be Improved?

**Verdict: Already using Bit.Vector.**

The `Slab<Element>` type uses `Buffer<Element>.Slab.Bounded`, which contains a `Bit.Vector` bitmap for occupancy tracking. The `IO.Blocking.Threads.Acceptance.Queue` uses `Slab<Entry>` and therefore already benefits from bit-vector primitives transitively:

- `slots.firstVacant()` → `bitmap.zeros.first(max:)` (Bit.Vector.Zeros scan)
- `slots.insert(_:at:)` → sets bit in bitmap
- `slots.remove(at:)` → clears bit in bitmap
- `slots.isFull` → `bitmap.popcount >= bitmap.capacity.maximum`

No changes needed here.

### 3.5 What About the Blocking Lane Job State?

**Verdict: No.**

`IO.Blocking.Lane.Abandoning.Job.State` is a linear enum (pending → running → completed/timeout/cancelled/failed) used with `Atomic<State>` via CAS. States are mutually exclusive — this is not a flag set. Neither Bitset nor Bit.Vector applies.

---

## 4. Potential Primitives Additions That Would Serve IO

While the existing Bitset and Bit.Vector packages do not map to IO's current bit patterns, the analysis reveals a pattern gap:

### 4.1 Atomic Flag-Based State Machine

IO has two identical hand-rolled implementations of a flag-based atomic state machine (the Waiter.State pattern). A potential primitive:

```swift
/// A fixed set of flags that compose into states, with atomic CAS transitions.
struct Atomic.Flags<let flagCount: Int>: AtomicRepresentable {
    // Bit 0..flagCount packed into UInt8/UInt16/UInt32
    // Named flags via static properties
    // Compound state queries (isCancelled, isArmed, etc.)
}
```

**However**, this would need to be in `Kernel` or a new atomics-adjacent package (not bitset-primitives or bit-vector-primitives), since the core value is the `AtomicRepresentable` conformance and CAS-based transition discipline. The Bitset package is about *collections of integers*; this is about *atomic state encoding*.

**Assessment**: The duplication (Event.Waiter.State vs Completion.Waiter.State) is real but the code is small (15 lines each), well-documented, and domain-specific. The cancellation model, memory ordering, and continuation semantics are tightly coupled to each waiter variant. Extracting a generic primitive risks over-abstraction for 15 lines of code. **Not recommended at this time.**

### 4.2 Typed OptionSet Primitive

IO's OptionSet types (`Flags`, `Kind.Set`, `HalfClose.State`) use Swift's built-in `OptionSet` protocol, which requires manual `rawValue` boilerplate. A potential primitive could reduce this, but Swift's `OptionSet` macro (if/when available) would be the right answer. **Not a bitset/bit-vector concern.**

---

## 5. Summary

| IO Pattern | Candidate Primitive | Verdict | Reason |
|-----------|-------------------|---------|--------|
| Waiter.State (3-bit atomic state machine) | Bitset | **No** | Not AtomicRepresentable, semantic mismatch (state machine, not set) |
| IO.Completion.Flags (OptionSet) | Bitset.Static | **No** | OptionSet is simpler, no-allocation, stdlib-idiomatic |
| IO.Completion.Kind.Set (OptionSet) | Bitset.Static | **No** | Same as above |
| HalfClose.State (OptionSet) | Bitset.Static | **No** | Same as above |
| Blocking.Lane.Abandoning.Job.State (enum) | Bitset | **No** | Linear state machine, mutually exclusive states |
| Counters (9x Atomic<UInt64>) | Bit.Vector | **No** | Scalar metrics, not bit-level |
| Advisory Gauges (3x Atomic<Int>) | Bit.Vector | **No** | Scalar metrics, not bit-level |
| Slab bitmap occupancy | Bit.Vector | **Already used** | Slab internally uses Bit.Vector |
| Executor.Handle.State (enum) | Bitset | **No** | Linear enum with associated data |
| Shutdown.Flag (Atomic<Bool>) | Bit.Vector | **No** | Single boolean, not a collection |

**Conclusion**: swift-io's bit-level patterns are already well-served by the current infrastructure. The hand-rolled patterns are either too small to benefit from abstraction (waiter state machines at 15 lines), already using the correct stdlib abstraction (OptionSet), or already leveraging bit-vector primitives (Slab occupancy bitmaps). There are **zero replacement opportunities** for Bitset or Bit.Vector in swift-io's direct code.

The duplication between `IO.Event.Waiter.State` and `IO.Completion.Waiter.State` is the only notable pattern that *could* be unified, but this is a cross-cutting concern within swift-io itself (extract a shared waiter state module), not a primitives package concern.
