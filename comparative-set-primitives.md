# Comparative Analysis: swift-set-primitives vs swift-io Set Usage

<!--
---
version: 1.0.0
date: 2026-02-24
scope: swift-io (Layer 3) consumption of swift-set-primitives (Layer 1)
status: DECISION
---
-->

## 1. swift-set-primitives Type Catalog

**Location**: `https://github.com/swift-primitives/swift-set-primitives`

**Modules**: `Set Primitives Core`, `Set Ordered Primitives`, `Set Primitives` (umbrella)

All types live under `Set<Element: Hash.Protocol & ~Copyable>`, which shadows `Swift.Set`.

### 1.1 Set.Ordered — Dynamic, Heap-Allocated

| Aspect | Detail |
|--------|--------|
| Storage | `Buffer<Element>.Linear` + `Hash.Table<Element>` |
| Copyable | Conditionally — when `Element: Copyable` (CoW) |
| Sendable | `@unchecked Sendable` when `Element: Sendable` |
| Growth | Dynamic (reserve, auto-grow) |

**API surface**:
- `init()`, `init(reservingCapacity:)`, `init<S: Sequence>(_ elements:)` (Copyable)
- `count`, `isEmpty`, `capacity`
- `insert(_:) -> (inserted: Bool, index:)`, `remove(_:) -> Element?`, `contains(_:) -> Bool`
- `index(_:) -> Index<Element>?`, `element(at:)`, `subscript`, `first`, `last`
- `withElement(at:_:)`, `forEach(_:)`, `withSpan(_:)`, `withMutableSpan(_:)` (Copyable)
- `drain(_:)`, `consume()` (Copyable), `clear(keepingCapacity:)`
- `algebra.union(_:)`, `algebra.intersection(_:)`, `algebra.subtract(_:)`, `algebra.symmetric.difference(_:)`
- `form(_:)` — mutating algebra
- `makeIterator()` — `Swift.Sequence` conformance (Copyable only)
- `Sequence.Protocol`, `Sequence.Drain.Protocol`, `Sequence.Clearable` conformances

### 1.2 Set.Ordered.Fixed — Fixed-Capacity, Heap-Allocated

| Aspect | Detail |
|--------|--------|
| Storage | `Buffer<Element>.Linear.Bounded` + `Hash.Table<Element>` |
| Copyable | Conditionally — when `Element: Copyable` (CoW) |
| Capacity | Set at init, throws `.overflow` on excess |

**API surface**: Same as `Ordered` minus `reserve`, `algebra`, `consume`. Adds `isFull`, `maximumCapacity`. Insert throws `__SetOrderedFixedError`.

### 1.3 Set.Ordered.Static<let capacity: Int> — Inline, Compile-Time Capacity

| Aspect | Detail |
|--------|--------|
| Storage | `Buffer<Element>.Linear.Inline<capacity>` + `Hash.Table<Element>.Static<capacity>` |
| Copyable | Unconditionally `~Copyable` (has `deinit`) |
| Capacity | Value-generic, must be power of two |

**API surface**: Same as Fixed, plus bounded index support via `Index<Element>.Bounded<capacity>`. No Span access (strided layout incompatible). Conforms to `Sequence.Protocol` (Copyable only).

### 1.4 Set.Ordered.Small<let inlineCapacity: Int> — SmallVec Pattern

| Aspect | Detail |
|--------|--------|
| Storage | `Buffer<Element>.Linear.Small<inlineCapacity>` + optional `Hash.Table<Element>` |
| Copyable | Unconditionally `~Copyable` (has `deinit`) |
| Mode | Inline: O(n) linear scan. After spill: O(1) hash table. |

**API surface**: Same as Ordered. `isSpilled` property. `contains` and `index` are mutating (inline linear scan). Conforms to `Sequence.Protocol` (Copyable only).

### 1.5 Indexed Wrappers

- `Set.Ordered.Indexed<Tag>` — phantom-typed index access over `Set.Ordered`
- `Set.Ordered.Fixed.Indexed<Tag>` — phantom-typed index access over `Set.Ordered.Fixed`

Both provide subscript via `Index<Tag>` instead of `Index<Element>`, with `.retag()` conversion.

### 1.6 Error Types

- `__SetOrderedError<Element>` — `.bounds(index, count)`, `.empty`
- `__SetOrderedFixedError<Element>` — adds `.overflow`, `.invalidCapacity`
- `__SetOrderedInlineError<Element>` — `.overflow`, `.bounds(index, count)`

All use typed throws per [API-ERR-001].

### 1.7 Dependencies

`Set Primitives Core` re-exports: `Standard_Library_Extensions`, `Bit_Primitives`, `Index_Primitives`, `Hash_Primitives`, `Hash_Table_Primitives`, `Storage_Primitives`, `Buffer_Primitives`, `Memory_Primitives`, `Collection_Primitives`.

---

## 2. swift-io Set Usage

**Location**: `https://github.com/swift-foundations/swift-io/tree/main/Sources/`

### 2.1 `Swift.Set<IO.Event.ID>` — Stale Event Filtering (kqueue + epoll)

**Files**:
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Queue.Operations.swift:350`
- `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Events/IO.Event.Poll.Operations.swift:250`

**Pattern** (identical in both):
```swift
let registeredIDs: Set<IO.Event.ID> = IO.Event.Registry.shared.withLock { registrations in
    if let ids = registrations[kq]?.keys {
        return Set(ids)
    }
    return []
}
// ... later in loop:
guard registeredIDs.contains(id) else { continue }
```

**Characteristics**:
- Created once per poll cycle as a snapshot from dictionary keys
- Used only for `contains()` membership testing
- Temporary/local scope — created, iterated, discarded
- Size: bounded by number of registered event sources (typically tens to low hundreds)
- Element type: `IO.Event.ID` (a tagged `UInt`, Hashable, Copyable)

### 2.2 `Swift.Set<UInt>` — IOCP Handle Association Tracking (Windows)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.IOCP.swift:65`

```swift
var associatedHandles: Set<UInt> = []
// ... later:
if !state.associatedHandles.contains(key) {
    // associate with IOCP
    state.associatedHandles.insert(key)
}
```

**Characteristics**:
- Long-lived, grows monotonically (handles are associated once, never removed)
- Only `contains()` and `insert()` — pure membership set
- Single-threaded (poll thread confined)
- Size: bounded by number of distinct file descriptors (typically tens to hundreds)
- Element type: `UInt` (raw handle value)

### 2.3 `IO.Completion.Kind.Set` — Custom OptionSet (NOT Swift.Set)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Completions/IO.Completion.Kind.Set.swift`

This is a custom `OptionSet` with `UInt16` raw value. Not a `Swift.Set` usage — it is a bitmask for capability declarations. **Not a replacement candidate** — it is already an appropriate bit-level representation.

### 2.4 `Swift.Set<Int>` — NUMA CPU Sets (Synthetic Fallback)

**File**: `https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Lane.Sharded+Threads.swift:130,138`

```swift
cpus: Set(0..<topology.cpuCount)
```

**Characteristics**:
- Constructed from a contiguous range, passed to `System.Topology.NUMA.Node` initializer
- The `Node` type is defined externally (likely in a system/topology package)
- One-shot construction, no mutation after creation
- Size: CPU count (typically 1-256)
- **Cannot be replaced** without changing the external `System.Topology.NUMA.Node` API

---

## 3. Replacement Opportunity Assessment

### 3.1 Stale Event Filtering (kqueue + epoll) — LOW priority

| Criterion | Assessment |
|-----------|------------|
| Current type | `Swift.Set<IO.Event.ID>` |
| Candidate | `Set<IO.Event.ID>.Ordered` or `Set<IO.Event.ID>.Ordered.Fixed` |
| Benefit | Typed index, ~Copyable support, ordered iteration |
| Cost | Dependency on `Set_Primitives`, API surface mismatch |
| Verdict | **Not recommended** |

**Rationale**: The set is constructed from dictionary keys via `Set(ids)`, used only for `contains()`, then discarded. This is a classic ephemeral membership test. `Swift.Set` is optimal here:
- No ordering needed (pure membership)
- No iteration over the set itself
- Constructed from a sequence (`.keys`) — `Set.Ordered.init<S: Sequence>` would work but adds no value
- The `Set(ids)` construction idiom is idiomatic Swift
- Adding `Set_Primitives` dependency for this pattern would increase coupling without improving semantics

**Alternative**: If the registry data structure itself were changed from `[Int32: [IO.Event.ID: ...]]` to use `Dictionary.Ordered` from dictionary-primitives, the `.keys` view would already be ordered and a separate set construction would be unnecessary. The `contains()` could be done directly on the dictionary. This is a registry redesign question, not a set replacement question.

### 3.2 IOCP Handle Association Tracking — LOW priority

| Criterion | Assessment |
|-----------|------------|
| Current type | `Swift.Set<UInt>` |
| Candidate | `Set<UInt>.Ordered` |
| Benefit | Insertion ordering (if needed), typed errors |
| Cost | Dependency on `Set_Primitives`, Windows-only code path |
| Verdict | **Not recommended** |

**Rationale**: This is a grow-only membership set with `contains()` and `insert()` only. `Swift.Set` is the right tool:
- No removal, no ordering, no iteration
- Monotonically growing (handles associated once)
- Windows-only, low traffic
- `UInt` does not benefit from `~Copyable` support

### 3.3 NUMA CPU Sets — NOT APPLICABLE

| Criterion | Assessment |
|-----------|------------|
| Current type | `Swift.Set<Int>` |
| Verdict | **Cannot replace** — external API contract |

The `System.Topology.NUMA.Node` initializer expects `Swift.Set<Int>`. Replacing would require changing an external type's API.

### 3.4 IO.Completion.Kind.Set — NOT APPLICABLE

Already a custom `OptionSet`. This is a bitmask, not a collection. No replacement opportunity.

---

## 4. Summary

| Usage Site | Current Type | Replacement? | Priority |
|------------|-------------|--------------|----------|
| Event stale filtering (kqueue) | `Swift.Set<IO.Event.ID>` | No | — |
| Event stale filtering (epoll) | `Swift.Set<IO.Event.ID>` | No | — |
| IOCP handle tracking | `Swift.Set<UInt>` | No | — |
| NUMA CPU sets | `Swift.Set<Int>` | No (external API) | — |
| Completion kind set | `IO.Completion.Kind.Set` (OptionSet) | No (already optimal) | — |

**Conclusion**: swift-io has **zero actionable replacement opportunities** for swift-set-primitives. All `Swift.Set` usage sites are ephemeral membership tests or external API contracts where `Swift.Set` is the correct choice. The set-primitives library's strengths — ordered semantics, `~Copyable` element support, fixed-capacity variants, typed indices, set algebra — are not exercised by any current swift-io pattern.

The most productive future integration point would be if swift-io introduces ordered collections with deduplication guarantees (e.g., an ordered event queue with uniqueness), but no such pattern exists today.
