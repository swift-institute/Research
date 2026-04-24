# Linked List Theoretical Perfect

<!--
---
version: 1.0.0
last_updated: 2026-04-01
status: RECOMMENDATION
---
-->

## Context

Follow-up to `linked-list-cursor-and-arena-backing-improvements.md`, which found two blocking gaps preventing `List.Linked<E, 2>` from replacing the timer wheel's ad-hoc intrusive list, and recommended (a) adding a cursor API, (b) keeping the ad-hoc code.

This research has unlimited scope. The question is not "what's practical next?" but "what would the theoretical perfect look like if we could break anything?"

### Trigger

User request: investigate the theoretical perfect for linked list infrastructure, considering whether a breaking refactor could make `List.Linked` obsolete by unifying intrusive and non-intrusive patterns.

### Scope

Primitives-wide. Potentially affects: `buffer-primitives-modularization`, `list-primitives`, `storage-primitives`, `async-primitives`, `tree-primitives`, `queue-primitives`.

### Tier

Tier 2 — cross-package, precedent-setting for buffer discipline architecture, informed by exhaustive prior art.

### Prior Art (Internal)

| Document | Relevance |
|----------|-----------|
| `linked-list-cursor-and-arena-backing-improvements.md` | Predecessor; identified gaps and Pool/Arena boundary |
| `HANDOFF-timer-wheel-intrusive-list.md` | Timer wheel investigation; full findings |
| `list-discipline-boundary-analysis.md` | Cursor API as #1 gap; STL/Rust prior art |
| `list-operations-audit.md` | 3 fundamental gaps: insert_after, delete, splice |
| `memory-pool-arena-buffer-usage-analysis.md` | Pool vs Arena semantic boundary |
| `storage-arena-architecture.md` | Storage.Arena structure and Meta composition |

### Prior Art (External)

| System | Pattern | Key Insight |
|--------|---------|-------------|
| Linux kernel `list_head` | AoS intrusive, `container_of` | Link struct is separate from payload; same `list_add`/`list_del` functions regardless of what contains the links |
| Boost.Intrusive | AoS intrusive, template hooks | Node hooks declare link fields; algorithms are generic over hooks |
| Rust `intrusive-collections` | AoS intrusive, adapter pattern | Adapter provides offset to link field; algorithms don't know the node type |
| C++ STL `std::list` | AoS non-intrusive, allocator-parameterized | Fused allocation+linking; no intrusive support |
| Rust `LinkedList` + RFC 2570 | AoS non-intrusive, cursor API | Cursor enables positional mutation; no intrusive support |
| Data-Oriented Design (Acton, Kelley) | SoA advocacy | Separate "hot" (links) from "cold" (payload) data for cache efficiency during traversal |

#### Contextualization (per [RES-021])

Linux kernel and Boost.Intrusive demonstrate that link operations can be generic over node type — the key abstraction is **how to access prev/next given a node handle**, not the node's element type or storage backend. This principle translates directly to the ecosystem's typed index model: replace `container_of`/pointer offsets with `(Index<Tag>) -> UnsafeMutablePointer<InlineArray<N, Index<Tag>>>`.

The SoA pattern (separate link array from element array) is academically interesting but unnecessary for current use cases — no ecosystem consumer needs a single element to be in multiple independent lists simultaneously. SoA is noted as a future option but not part of the primary design.

## Question

What is the theoretical perfect for linked list infrastructure in the primitives? Can a refactor make `List.Linked` obsolete? If not, what design minimizes duplicated link logic across intrusive and non-intrusive use cases?

## First Principles: What IS a Linked List?

A linked list is **O(1) positional mutation given a stable handle**. This is its defining characteristic — the one thing that justifies choosing a linked list over an array or ring buffer.

The operations are:

| Operation | Complexity | Notes |
|-----------|:---:|-------|
| Append to tail | O(1) | Requires tail pointer |
| Prepend to head | O(1) | |
| Remove at known position | O(1) | Requires doubly-linked (N=2) |
| Insert after known position | O(1) | |
| Pop head | O(1) | |
| Pop tail | O(1) | Requires doubly-linked |
| Splice (transfer all from one list to another) | O(1) | Signature linked-list operation |
| Traverse | O(n) | |

Every one of these operations is **pure index algebra** — given a way to read/write the prev/next links at a given index, the algorithm doesn't need to know:

- How memory is allocated (Pool, Arena, Inline)
- What the element type is
- Whether links are embedded in a wrapper node or in the user's own type
- Whether the allocator has generation tokens

This is the core insight.

## The Current Architecture: Fused Concerns

### Buffer.Linked (Verified: 2026-04-01)

`Buffer.Linked<E, N>` fuses three concerns:

```
Buffer.Linked
├── Allocation    — Storage<Node>.Pool.allocate() / .deallocate()
├── Linking       — pointee.links[0] / pointee.links[1] manipulation
└── Element I/O   — pointer.initialize(to:) / pointer.move()
```

Every method interleaves these three. `insertBack` for example:

```
1. Allocate slot from pool          ← Allocation
2. Initialize links[0], links[1]    ← Linking
3. Initialize node (element+links)  ← Element I/O
4. Update old tail's links[0]       ← Linking
5. Update header head/tail/count    ← Linking
```

Steps 2, 4, 5 are pure link topology. They use `Index<Node>` arithmetic and sentinel comparisons — nothing else. They could operate on any storage backend that provides `(Index<Node>) -> UnsafeMutablePointer<InlineArray<N, Index<Node>>>`.

### Timer Wheel (Verified: 2026-04-01)

The timer wheel's ad-hoc list is the same algorithm with different storage:

```
Timer Wheel ad-hoc list
├── Allocation    — Buffer<Node>.Arena.Bounded.insert() / .free()
├── Linking       — pointee.prev / pointee.next manipulation
└── Element I/O   — pointee.id, pointee.deadline (direct field access)
```

`slotAppend` implementation is structurally identical to `Buffer.Linked.insertBack`'s link manipulation — just with different field names (`prev`/`next` vs `links[1]`/`links[0]`) and different nil representation (Optional vs sentinel).

### Survey: The Pattern Recurs (Verified: 2026-04-01)

| Structure | Storage | Links | Fused? |
|-----------|---------|-------|:---:|
| `List.Linked` | `Storage<Node>.Pool` | `InlineArray<N, Index<Node>>` embedded in Node | Yes |
| `Queue.Linked` | `Storage<Node>.Pool` via `Buffer<E>.Linked<1>` | `InlineArray<1, Index<Node>>` embedded in Node | Yes |
| `Tree.N` | `Buffer<Node>.Arena` (growable) | `parentIndex: Index<Node>?` + `childIndices: InlineArray<n, Index<Node>?>` embedded in Node | Yes |
| Timer Wheel | `Buffer<Node>.Arena.Bounded` (fixed) | `prev: Index<Node>?` + `next: Index<Node>?` embedded in Node | Yes (ad-hoc) |

Four data structures, three storage backends, same fundamental pattern: index-based link manipulation fused with allocation.

## The Decomposition

### The New Primitive: `Buffer.Link<N>`

Factor the link topology out of `Buffer.Linked` into a standalone discipline:

```
Buffer.Link<N>      — pure link topology operations
                       parametric over link access
                       no allocation, no element I/O
                       
Buffer.Linked<E, N> — re-derived as Buffer.Link<N> + Storage.Pool + element I/O
Timer Wheel         — uses Buffer.Link<N> + Buffer.Arena.Bounded + element I/O
Queue.Linked        — uses Buffer.Link<1> + Storage.Pool (through Buffer.Linked)
```

`Buffer.Link<N>` would provide the link algorithm once. Consumers compose it with their storage backend.

### Proposed Type Hierarchy

```swift
extension Buffer where Element: ~Copyable {
    /// Pure link topology discipline.
    ///
    /// Provides O(1) linked-list operations parametric over link access.
    /// Does not allocate, deallocate, or touch elements — only manages
    /// prev/next indices.
    ///
    /// - Parameter N: Link count per node. 1 = singly-linked, 2 = doubly-linked.
    enum Link<let N: Int> {}
}
```

#### Header (the state of one independent list)

```swift
extension Buffer.Link {
    /// State of one independent linked list.
    ///
    /// A value type. Multiple headers can share one backing storage,
    /// enabling the multi-head pattern (e.g., timer wheel's 384 slots).
    @frozen
    public struct Header: Copyable, Sendable {
        public var head: Index<Element>
        public var tail: Index<Element>
        public var count: Index<Element>.Count
        public let sentinel: Index<Element>
    }
}
```

Note: this is identical to `Buffer.Linked.Header` but lives on `Buffer.Link`, establishing it as the canonical header for any linked topology — intrusive or non-intrusive.

#### Operations (pure index algebra)

All operations take a `links` closure — the single abstraction point that decouples topology from storage:

```swift
extension Buffer.Link {
    /// Appends `index` to the tail of the list. O(1).
    @inlinable
    public static func append(
        _ index: Index<Element>,
        header: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    )
    
    /// Prepends `index` to the head of the list. O(1).
    @inlinable
    public static func prepend(
        _ index: Index<Element>,
        header: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    )
    
    /// Unlinks `index` from the list. O(1) for N >= 2. Does NOT deallocate.
    @inlinable
    public static func unlink(
        _ index: Index<Element>,
        header: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    )
    
    /// Unlinks the head node and returns its index. O(1).
    @inlinable
    public static func unlinkFirst(
        header: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    ) -> Index<Element>?
    
    /// Unlinks the tail node and returns its index.
    /// O(1) for N >= 2, O(n) for N == 1.
    @inlinable
    public static func unlinkLast(
        header: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    ) -> Index<Element>?
    
    /// Inserts `index` after `position` in the list. O(1).
    @inlinable
    public static func insert(
        _ index: Index<Element>,
        after position: Index<Element>,
        header: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    )
    
    /// Transfers all nodes from `source` to the tail of `target`. O(1).
    /// Both headers must share the same backing storage.
    @inlinable
    public static func splice(
        from source: inout Header,
        to target: inout Header,
        links: (Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
    )
    
    /// Visits each node index from head to tail. O(n).
    @inlinable
    public static func forEach(
        header: Header,
        links: (Index<Element>) -> UnsafePointer<InlineArray<N, Index<Element>>>,
        body: (Index<Element>) -> Void
    )
}
```

#### The `links` Closure

The single abstraction that makes the decomposition work:

```
(Index<Element>) -> UnsafeMutablePointer<InlineArray<N, Index<Element>>>
```

Given a node's index, return a pointer to its link array. How this works depends on the storage:

```swift
// Pool-backed (Buffer.Linked):
{ idx in unsafe pool.pointer(at: idx).pointerToField(\.links) }

// Arena-backed (timer wheel, after Node refactor):
{ idx in unsafe arena.pointer(at: idx).pointerToField(\.links) }

// Inline-backed (Buffer.Linked.Inline):
{ idx in unsafe storage.pointer(at: idx).pointerToField(\.links) }
```

The closure is `@inlinable` and monomorphized at the call site — zero runtime overhead.

### Re-Derived Buffer.Linked

`Buffer.Linked<E, N>` becomes a thin orchestration layer:

```swift
extension Buffer.Linked {
    public static func insertBack(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Node>.Pool
    ) throws(Error) {
        // 1. Allocate
        let slot: Index<Node> = try storage.allocate()
        
        // 2. Initialize node with sentinel links
        let links = InlineArray<N, Index<Node>>(repeating: header.sentinel)
        let node = Node(element: element, links: links)
        unsafe storage.pointer(at: slot).initialize(to: node)
        
        // 3. Delegate linking to Buffer.Link
        Buffer<Element>.Link<N>.append(slot, header: &header) { idx in
            unsafe storage.pointer(at: idx).pointerToField(\.links)
        }
    }
    
    public static func removeFront(
        header: inout Header,
        storage: Storage<Node>.Pool
    ) -> Element? {
        // 1. Delegate unlinking to Buffer.Link
        guard let slot = Buffer<Element>.Link<N>.unlinkFirst(
            header: &header
        ) { idx in
            unsafe storage.pointer(at: idx).pointerToField(\.links)
        } else { return nil }
        
        // 2. Extract element
        let node = unsafe storage.pointer(at: slot).move()
        
        // 3. Deallocate
        try! storage.deallocate(at: slot)
        
        return node.element
    }
}
```

The pattern is: allocate → delegate to Link → extract element → deallocate.

### Re-Derived Timer Wheel

The timer wheel's `Slot` becomes `Buffer<Node>.Link<2>.Header`, and the ad-hoc list operations are replaced by `Buffer.Link` calls:

```swift
extension Async.Timer.Wheel {
    // Node gains InlineArray links (breaking change)
    struct Node {
        var id: ID
        var deadline: Deadline
        var level: UInt8
        var slot: UInt16
        var links: InlineArray<2, Index<Node>>  // was: prev/next Optional
    }
    
    // Slot becomes a type alias
    typealias Slot = Buffer<Node>.Link<2>.Header
    
    // slotAppend → Buffer.Link.append
    mutating func slotAppend(_ index: Index<Node>, to slot: inout Slot) {
        Buffer<Node>.Link<2>.append(index, header: &slot) { idx in
            unsafe self.storage.pointer(at: idx).pointerToField(\.links)
        }
    }
    
    // slotRemove → Buffer.Link.unlink
    mutating func slotRemove(_ index: Index<Node>, from slot: inout Slot) {
        Buffer<Node>.Link<2>.unlink(index, header: &slot) { idx in
            unsafe self.storage.pointer(at: idx).pointerToField(\.links)
        }
    }
    
    // slotPopFirst → Buffer.Link.unlinkFirst
    mutating func slotPopFirst(from slot: inout Slot) -> Index<Node>? {
        Buffer<Node>.Link<2>.unlinkFirst(header: &slot) { idx in
            unsafe self.storage.pointer(at: idx).pointerToField(\.links)
        }
    }
}
```

The timer wheel still owns its `Buffer<Node>.Arena.Bounded` for allocation + generation tokens. `Buffer.Link` handles only linking. The concerns are cleanly separated.

## Does This Make List.Linked Obsolete?

**No.** `List.Linked` is not obsolete — it's re-derived.

```
List.Linked<E, 2> = Buffer.Link<2>       (link topology — shared)
                   + Storage<Node>.Pool   (allocation — Pool-specific)
                   + Node wrapper         (element I/O — non-intrusive)
                   + convenience API      (append, popFirst, forEach)
```

`List.Linked`'s value is ergonomics: a user who wants a linked list writes `List.Linked<Int, 2>()` and calls `.append(42)`. They don't need to know about `Buffer.Link`, `Header`, sentinels, or link closures. That convenience remains.

What changes is the implementation. Instead of `Buffer.Linked` containing ~200 lines of link manipulation fused with allocation, it delegates the ~100 lines of pure link algebra to `Buffer.Link` and orchestrates the remaining ~100 lines of allocation and element I/O.

### Why List.Linked Cannot Be Made Obsolete

A single type that subsumes both intrusive and non-intrusive patterns would need to be parametric over:

| Axis | Non-intrusive | Intrusive |
|------|:---:|:---:|
| Storage backend | Pool | Arena, Inline, user-managed |
| Node structure | Wrapper (`Node { element, links }`) | User's own type with embedded links |
| Allocation ownership | List owns it | Caller owns it |
| Element access | Through wrapper | Direct |
| Handle semantics | Internal (list manages validity) | External (caller manages validity, ABA) |

A type parametric over all five axes would be unusable. The combinatorial API surface — `List<E, N, Storage, NodeType, HandlePolicy>` — is worse than having two clean types.

The right answer is the decomposition: share the **algorithm** (`Buffer.Link`), compose with **storage** and **element access** at the consumer level. `List.Linked` is one composition. The timer wheel is another. Neither is a special case of the other — they share the same link algebra but differ in ownership and handle semantics.

## Representation Standardization

The decomposition requires a unified link representation. Currently:

| Consumer | Link representation | Nil representation |
|----------|--------------------|--------------------|
| `Buffer.Linked` | `InlineArray<N, Index<Node>>` | Sentinel (`capacity.map(Ordinal.init)`) |
| Timer Wheel | Separate `prev: Index<Node>?`, `next: Index<Node>?` | `Optional.none` |

`Buffer.Link` would standardize on `InlineArray<N, Index<Tag>>` with sentinel values:

- **InlineArray over separate fields**: Generalizes to any N. Convention (`[0]`=next, `[1]`=prev) is already established in `Buffer.Linked.Node`. The timer wheel's `prev`/`next` fields become `links: InlineArray<2, Index<Node>>`.

- **Sentinel over Optional**: Avoids Optional's 1-byte tag overhead per link. Sentinel is `let` (immutable, set at initialization from capacity). Already used by `Buffer.Linked.Header`. The timer wheel's `head: Index<Node>?` / `tail: Index<Node>?` become sentinel-based.

**Semantic correctness**: Both changes are isomorphic — they encode the same information in a different representation. No behavioral change.

**Breaking change**: Yes, for the timer wheel's Node type. The fields `prev: Index<Node>?` and `next: Index<Node>?` become `links: InlineArray<2, Index<Node>>`. All `slotAppend`/`slotRemove`/`slotPopFirst` code is replaced by `Buffer.Link` calls, so this is mechanical.

## Semantic Correctness Assessment

| Change | Semantically correct? | Rationale |
|--------|:---:|---------|
| Factor link operations out of `Buffer.Linked` | **Yes** | Pure refactoring; link algebra doesn't depend on allocation |
| `Buffer.Link<N>` as a new discipline | **Yes** | Link topology is an independent concern; factoring it out creates a reusable primitive without changing any existing type's contract |
| `Buffer.Link.Header` as canonical header | **Yes** | Identical to `Buffer.Linked.Header`; establishing it on the more primitive type is the correct layering |
| `links` closure as abstraction point | **Yes** | The closure is a projection from index to link storage — pure accessor, no semantic content |
| Standardizing on `InlineArray<N, Index<Tag>>` | **Yes** | Isomorphic to separate fields; no information lost |
| Standardizing on sentinel (not Optional) | **Yes** | Isomorphic to Optional; sentinel is already the convention in `Buffer.Linked` |
| `List.Linked` re-derived (not obsoleted) | **Yes** | API unchanged; implementation delegates to more primitive layer |
| Timer wheel using `Buffer.Link` | **Yes** | Replaces ad-hoc code with the same algorithm from a shared source |
| Pool/Arena boundary preserved | **Yes** | `Buffer.Link` doesn't touch allocation or temporal safety; Pool and Arena remain distinct |

No semantic boundary violations. The decomposition is a pure factoring of an existing algorithm.

## What the Theoretical Perfect Provides

### Operations That Fall Out Naturally

The cursor API — the #1 missing feature identified in three prior research documents — is a natural member of `Buffer.Link`:

| Operation | Status Today | In Theoretical Perfect |
|-----------|:---:|:---:|
| Append to tail | Exists (in Buffer.Linked) | `Buffer.Link.append` |
| Prepend to head | Exists | `Buffer.Link.prepend` |
| Pop head | Exists | `Buffer.Link.unlinkFirst` |
| Pop tail | Exists | `Buffer.Link.unlinkLast` |
| **Remove at position** | **Missing** | `Buffer.Link.unlink` |
| **Insert after position** | **Missing** | `Buffer.Link.insert(_:after:)` |
| **Splice** | **Missing** | `Buffer.Link.splice` |
| Traverse | Exists | `Buffer.Link.forEach` |

The three "fundamental gaps" from `list-operations-audit.md` — delete, insert_after, splice — are all first-class operations on `Buffer.Link`.

### Patterns That Become Natural

| Pattern | Today | Theoretical Perfect |
|---------|-------|---------------------|
| Non-intrusive list | `List.Linked` | `List.Linked` (re-derived from `Buffer.Link` + Pool) |
| Intrusive list with arena | Ad-hoc (`slotAppend`, etc.) | `Buffer.Link` + caller's Arena |
| Multi-head sharing one storage | Not supported at API level | Multiple `Buffer.Link.Header`s, one backing storage |
| O(1) cancel-by-index | Ad-hoc (`slotRemove`) | `Buffer.Link.unlink` |
| O(1) list-to-list transfer | Not supported | `Buffer.Link.splice` |
| Singly-linked queue | `Queue.Linked` via `Buffer.Linked<1>` | `Queue.Linked` via `Buffer.Link<1>` + Pool |

### What It Does NOT Provide

- **ABA protection**: Remains in `Buffer.Arena` / `Buffer.Arena.Bounded`. Orthogonal to linking.
- **Element access**: Remains in the consumer. `Buffer.Link` operates on indices, not elements.
- **Allocation**: Remains in Pool / Arena / Inline. `Buffer.Link` does not allocate or deallocate.
- **Multi-list membership** (one element in N independent lists simultaneously): Would require N independent link arrays. Possible with SoA (separate link arrays per list) but no current consumer needs this.

## Architecture Diagram

```
                     ┌──────────────────────────────────────────┐
                     │           Buffer.Link<N>                 │
                     │    (pure link topology discipline)       │
                     │                                          │
                     │  append · prepend · unlink · unlinkFirst │
                     │  unlinkLast · insert(after:) · splice    │
                     │  forEach                                 │
                     │                                          │
                     │  Parametric over:                        │
                     │   (Index<Tag>) → Pointer<InlineArray<N>> │
                     └────────────┬─────────────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼
   ┌─────────────────┐ ┌──────────────────┐ ┌─────────────────┐
   │ Buffer.Linked   │ │  Timer Wheel     │ │  Future LRU,    │
   │ = Link + Pool   │ │  = Link + Arena  │ │  Scheduler, ... │
   │                 │ │                  │ │  = Link + ???   │
   │ Non-intrusive   │ │  Intrusive       │ │                 │
   │ Single-head     │ │  Multi-head      │ │                 │
   │ No ABA needed   │ │  ABA via Arena   │ │                 │
   └────────┬────────┘ └────────┬─────────┘ └─────────────────┘
            │                   │
            ▼                   ▼
   ┌─────────────────┐ ┌──────────────────┐
   │ List.Linked     │ │ Async.Timer.Wheel│
   │ (user-facing)   │ │ (internal)       │
   └─────────────────┘ └──────────────────┘
```

## Comparison with Current Architecture

| Criterion | Current | Theoretical Perfect |
|-----------|---------|---------------------|
| Link algorithm duplication | Buffer.Linked + timer wheel ad-hoc (~200 lines duplicated) | One source: Buffer.Link (~100 lines) |
| Cursor API (remove-at, insert-after) | Missing | First-class operations |
| Splice (O(1) list transfer) | Missing | First-class operation |
| Intrusive list support | Ad-hoc only | Natural composition |
| Multi-head pattern | Not in API | First-class: Header is a value type |
| List.Linked API | Unchanged | Unchanged |
| Pool/Arena boundary | Preserved | Preserved |
| Allocation concerns in link code | Interleaved | Separated |
| Buffer.Linked implementation | ~200 lines (fused) | ~100 lines (orchestration) |
| Timer wheel list code | ~120 lines (ad-hoc) | ~15 lines (delegate to Buffer.Link) |
| New types required | — | `Buffer.Link<N>`, `Buffer.Link.Header` |
| Breaking changes | — | Timer wheel Node representation (internal) |

## Outcome

**Status**: RECOMMENDATION

### The Theoretical Perfect

**`Buffer.Link<N>`** — a pure link topology discipline at the Buffer layer, parametric over link access via an `@inlinable` closure.

This is the single new primitive. Everything else is composition:

| Composition | What it is |
|-------------|------------|
| `Buffer.Linked<E, N>` | `Buffer.Link<N>` + `Storage<Node>.Pool` + element wrapper |
| Timer Wheel | `Buffer.Link<2>` + `Buffer<Node>.Arena.Bounded` + domain node |
| `Queue.Linked<E>` | `Buffer.Link<1>` + `Storage<Node>.Pool` + element wrapper |
| Future intrusive consumer | `Buffer.Link<N>` + any storage backend |

### List.Linked Is Not Obsolete

`List.Linked` remains the user-facing convenience type. Its value is ergonomics — hiding the decomposition behind `append`, `popFirst`, `forEach`. The theoretical perfect re-derives it from more primitive components; it does not replace it.

A single type that subsumes both intrusive and non-intrusive patterns would be parametric over five axes (storage, node structure, allocation ownership, element access, handle semantics). The combinatorial API surface would be unusable. The correct design shares the **algorithm**, not the **type**.

### Implementation Path (If Pursued)

1. Create `Buffer.Link<N>` with `Header` and all static operations
2. Implement the full cursor API: `unlink`, `insert(_:after:)`, `splice`
3. Re-derive `Buffer.Linked` as thin orchestration over `Buffer.Link` + Pool
4. Verify `List.Linked` API is unchanged (pure internal refactor)
5. Refactor timer wheel Node to use `InlineArray<2, Index<Node>>` + sentinel
6. Replace timer wheel's `slotAppend`/`slotRemove`/`slotPopFirst` with `Buffer.Link` calls
7. Consider whether `Queue.Linked` benefits from the same delegation

### Deferred: SoA Link Storage

For future multi-list-membership use cases (one element in N independent lists), a SoA variant — where links are stored in a parallel array separate from elements — would be needed. This is architecturally compatible with `Buffer.Link` (the `links` closure would project into the parallel array instead of into the node). No current consumer needs this. Revisit if a consumer appears.

## References

- `swift-primitives/Research/linked-list-cursor-and-arena-backing-improvements.md` — Predecessor research
- `swift-async-primitives/HANDOFF-timer-wheel-intrusive-list.md` — Timer wheel investigation
- `swift-list-primitives/Research/list-discipline-boundary-analysis.md` — Cursor API gap analysis, STL/Rust prior art
- `swift-list-primitives/Research/list-operations-audit.md` — Three fundamental gaps
- `swift-primitives/Research/memory-pool-arena-buffer-usage-analysis.md` — Pool/Arena distinction
- Buffer.Linked implementation: `swift-buffer-primitives-modularization/Sources/Buffer Linked Primitives/Buffer.Linked+Pool ~Copyable.swift`
- Buffer.Linked.Node: `swift-buffer-primitives-modularization/Sources/Buffer Linked Primitives Core/Buffer.Linked.Node.swift`
- Timer wheel: `swift-async-primitives/Sources/Async Timer Primitives/Async.Timer.Wheel+Slot.swift`
- Linux kernel `list.h` — intrusive linked list, `list_add`/`list_del` generic over container type
- Boost.Intrusive — template-parameterized hook-based intrusive containers
- Rust `intrusive-collections` — adapter pattern for offset-based link access
- Rust RFC 2570 — Linked List Cursors (stabilized cursor API)
