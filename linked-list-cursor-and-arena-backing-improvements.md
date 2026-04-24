# Linked List Cursor and Arena-Backing Improvements

<!--
---
version: 1.0.0
last_updated: 2026-04-01
status: RECOMMENDATION
---
-->

## Context

A code-surface audit of `swift-async-primitives` identified that `Async.Timer.Wheel` manages ~384 independent intrusive doubly-linked lists via ~120 lines of manual list management (`slotAppend`, `slotRemove`, `slotPopFirst`, `withSlot`). The ecosystem provides `List.Linked<E, 2>`, which prompted an investigation into whether the ad-hoc code could be replaced.

The investigation (`HANDOFF-timer-wheel-intrusive-list.md`) found two blocking gaps:

1. **No positional removal** — `List.Linked` and `Buffer.Linked` only expose end operations (`removeFront`/`removeBack`). There is no `remove(at: Index)` for O(1) arbitrary removal.
2. **No ABA protection** — `Storage<Node>.Pool` has no generation tokens. The timer wheel depends on `Buffer.Arena.Bounded`'s per-slot generation tokens and `isValid(Position)` to prevent stale cancel handles from removing wrong timers.

This research investigates whether either gap can be closed by improving the primitives, and evaluates the semantic correctness of each potential improvement.

### Trigger

[RES-001] Investigation trigger: design question (can primitives subsume an ad-hoc pattern?) cannot be answered without systematic analysis of alternatives.

### Scope

Primitives-wide. Affects: `list-primitives`, `buffer-primitives-modularization`, `storage-primitives`, `memory-primitives`. Consumer: `async-primitives`.

### Tier

Tier 2 — Cross-package, significant API implications, informed by existing research and prior art.

### Prior Art (Internal)

| Document | Location | Relevance |
|----------|----------|-----------|
| List Discipline Boundary Analysis | `swift-list-primitives/Research/list-discipline-boundary-analysis.md` | Identifies cursor API as #1 missing feature; surveys STL and Rust RFC 2570 |
| List Operations Audit | `swift-list-primitives/Research/list-operations-audit.md` | Catalogs `delete(node)` and `insert_after` as high-priority gaps |
| Memory-Pool-Arena-Buffer Usage Analysis | `swift-primitives/Research/memory-pool-arena-buffer-usage-analysis.md` | Establishes Pool vs Arena semantic distinction |
| Memory-Storage Composition Feasibility | `swift-primitives/Research/memory-storage-composition-feasibility.md` | Evaluates composability of Memory.Pool/Arena with Storage layer |
| Storage Arena Architecture | `swift-primitives/Research/storage-arena-architecture.md` | Reconciles Memory.Arena composition with Buffer.Arena conditional Copyable |
| Timer Wheel Investigation | `swift-async-primitives/HANDOFF-timer-wheel-intrusive-list.md` | Source investigation with full findings |

## Question

Can the primitives (`List.Linked`, `Buffer.Linked`, `Storage.Pool`) be improved to close the two blocking gaps? Are those improvements semantically correct — i.e., do they respect the existing abstraction boundaries and type-level contracts?

## Analysis

### The Pool/Arena Semantic Boundary

Before evaluating options, the ecosystem's allocator distinction must be stated precisely, because it determines which improvements are semantically valid.

| Property | `Storage<E>.Pool` / `Memory.Pool` | `Storage<E>.Arena` / `Buffer<E>.Arena` |
|----------|:---:|:---:|
| **Design intent** | Internal allocator for data structures | External handle allocator for user-facing APIs |
| **Who manages consistency?** | The data structure (e.g., `Buffer.Linked`) | The handle holder (e.g., timer wheel caller) |
| **Temporal safety** | None — freed indices are immediately reusable | Per-slot generation tokens (UInt32, odd=occupied, even=free) |
| **Validation API** | None | `isValid(Position)` — O(1) generation check |
| **Handle type** | Bare `Index<E>` | `Position(index: UInt32, token: UInt32)` — 8-byte stamped handle |
| **Occupancy oracle** | `Bit.Vector` bitmap | Token parity (bit 0) |
| **Free-list links** | In-band in deinitialized slots | Per-slot `Meta.link` field (8 bytes/slot overhead) |
| **Memory semantics** | Reference type (`final class`) with CoW | Value type (`~Copyable`) or reference (`final class`) |

This distinction is architectural, not incidental. Pool-backed data structures guarantee consistency internally (the list manages its own head/tail/links). Arena-backed handles are given to external code that may hold them across allocation/deallocation cycles, requiring temporal safety.

### Gap 1: Cursor / Positional Removal

#### Current State

`Buffer.Linked` and `List.Linked` expose only end operations:

| Operation | Buffer.Linked | List.Linked |
|-----------|:---:|:---:|
| `insertFront` / `prepend` | Yes | Yes |
| `insertBack` / `append` | Yes | Yes |
| `removeFront` / `popFirst` | Yes | Yes |
| `removeBack` / `popLast` | Yes (O(1) for N≥2) | Yes |
| `remove(at:)` | **No** | **No** |
| `insert(after:)` | **No** | **No** |

Existing research consensus (list-discipline-boundary-analysis.md:379, list-operations-audit.md:445):

> "Cursor / position-based mutation — Core list semantics — **High** — The defining list operation per STL and Rust. O(1) insert/remove at a known position is what justifies using a list over an array. Without cursors, the list is just a deque."

> "3 are fundamental gaps (insert_after, delete, splice) that should be added at the primitives layer."

#### Semantic Correctness: YES

Adding positional removal to `Buffer.Linked` and `List.Linked` is semantically correct:

1. **Consistent with type identity.** A linked list's defining characteristic is O(1) positional mutation given a stable reference. Without it, the type is functionally a deque that happens to use nodes internally. The cursor API completes the semantic contract.

2. **Consistent with internal index model.** `Buffer.Linked` already uses `Index<Node>` internally for linking. The indices are stable across insertions/deletions at other positions (pool doesn't shift memory). Exposing positional removal surfaces an existing capability, not a new one.

3. **Consistent with `~Copyable` element model.** `remove(at:) -> Element` transfers ownership of the element to the caller via `consuming` return. This is the only correct API for `~Copyable` elements — it matches `removeFront`/`removeBack` semantics exactly.

4. **No abstraction violation.** The operation stays within the list's consistency domain — the list manages its own head/tail/links. No external temporal safety is needed because the list controls when indices are valid.

5. **Consistent with prior art.** C++ STL `std::list::erase(iterator)`, Rust `LinkedList::CursorMut::remove_current`, Java `LinkedList.ListIterator.remove()` — all provide O(1) positional removal as core API.

#### Proposed API Surface

At `Buffer.Linked` level (static methods, per existing convention):

```swift
// Remove node at known position, relink neighbors, return element.
public static func remove(
    at slot: Index<Node>,
    header: inout Header,
    storage: Storage<Node>.Pool
) -> Element

// Insert element after known position, return new node's index.
public static func insert(
    _ element: consuming Element,
    after slot: Index<Node>,
    header: inout Header,
    storage: Storage<Node>.Pool
) -> Index<Node>
```

At `List.Linked` level (instance methods):

```swift
public mutating func remove(at position: Index<Element>) -> Element
public mutating func insert(_ element: consuming Element, after position: Index<Element>) -> Index<Element>
```

#### Scope and Dependencies

- **No new types required.** Uses existing `Index<Node>` / `Index<Element>`.
- **No new storage infrastructure.** Pool already provides `deallocate(at:)` and `pointer(at:)`.
- **Doubly-linked (N≥2) constraint.** O(1) arbitrary removal requires prev pointer. For N=1 (singly-linked), `remove(at:)` would be O(n) — either constrain to N≥2 or document the complexity difference.

### Gap 2: ABA Protection / Generation Tokens

#### Current State

`Storage<Node>.Pool` has no generation tokens. Confirmed by exhaustive grep — zero matches for `generation`, `token`, `ABA`, `isValid` in `Storage.Pool.swift` and `Memory.Pool.swift`.

The timer wheel's cancel path requires generation-based validation:
1. External `ID` carries `index + generation` (via `Handle<_Entry>`)
2. `_position(id)` reconstructs `Buffer.Arena.Position`
3. `storage.isValid(position)` checks generation before removal
4. Without this, a stale cancel could silently remove a different timer

#### Option A: Add Generation Tokens to Storage.Pool

**Semantic Correctness: NO**

This would violate the Pool/Arena boundary:

1. **Pool is an internal allocator.** Its consumers (`Buffer.Linked`, `List.Linked`) manage their own consistency. The pool's contract is: "I give you slots; you manage what's in them." Adding temporal safety changes the contract to: "I validate your access patterns" — that's Arena's job.

2. **Breaks existing invariants.** `Storage.Pool` uses a `Bit.Vector` for allocation tracking. The arena uses token parity. Adding tokens would create two redundant occupancy oracles (bitmap AND parity), or require removing the bitmap — which is used for bulk iteration in deinit (`_allocationBits.ones`).

3. **8-byte overhead per slot.** Generation tokens require per-slot `Meta` (token + link = 8 bytes). `Storage.Pool` currently has zero per-slot metadata overhead beyond the bitmap (1 bit/slot). For a timer wheel with 65,536 slots, this adds 512KB — not prohibitive, but it penalizes every Pool consumer for a feature most don't need.

4. **Conflates two abstractions.** The ecosystem has a clear separation: Pool for internal use, Arena for handle-based use. Making Pool arena-like eliminates the reason Arena exists as a separate type.

**Verdict: Do not add generation tokens to Storage.Pool.**

#### Option B: Arena-Backed Linked Buffer (`Buffer.Arena.Linked`)

Create a new buffer discipline that combines `Buffer.Arena` allocation (with generation tokens) and doubly-linked list operations.

**Semantic Correctness: PARTIALLY**

1. **Correct composition.** Arena provides temporal safety; linked list provides O(1) positional operations. These are orthogonal concerns that compose cleanly.

2. **But introduces semantic tension.** Arena is designed for external handle patterns — callers hold `Position` handles and validate them. A linked list manages its own links internally. If the list manages its own consistency (head/tail/links), the generation tokens are redundant for the list's internal operations. They're only useful at the boundary where external code interacts with the list.

3. **Multi-head sharing is unnatural for Arena.** `Buffer.Arena` is designed as one arena = one allocation domain. Multiple independent lists sharing one arena is an intrusive pattern, not a list-manages-itself pattern. The arena would need to be shared by reference or passed explicitly, which complicates the ownership model.

4. **API surface confusion.** Users would need to decide between `Buffer.Linked` (pool-backed, no generation tokens) and `Buffer.Arena.Linked` (arena-backed, generation tokens). The distinction maps to an advanced concurrent systems concept (ABA prevention) that most users don't need.

**Verdict: Architecturally viable but adds complexity for a narrow use case. Not recommended as a general primitive.**

#### Option C: Reusable Intrusive List Helper

Extract the timer wheel's `slotAppend`/`slotRemove`/`slotPopFirst` into a reusable type that operates on user-managed storage. The caller provides the allocation backend (arena, pool, inline — doesn't matter); the helper manages linking only.

```swift
// Conceptual API (not a proposal):
struct List.Intrusive<Node: IntrusiveLinked> {
    var head: Index<Node>?
    var tail: Index<Node>?
    var count: Int
    
    mutating func append(_ index: Index<Node>, using access: (Index<Node>) -> UnsafeMutablePointer<Node>)
    mutating func remove(_ index: Index<Node>, using access: (Index<Node>) -> UnsafeMutablePointer<Node>)
    mutating func popFirst(using access: (Index<Node>) -> UnsafeMutablePointer<Node>) -> Index<Node>?
}
```

**Semantic Correctness: YES, with caveats**

1. **Correct abstraction level.** Intrusive lists are a recognized systems programming pattern. The type manages linking; the caller manages allocation. This matches the timer wheel's actual architecture.

2. **No abstraction violation.** Doesn't change Pool or Arena semantics. The intrusive list is a new, orthogonal concern.

3. **Reusability.** Any arena-backed, pool-backed, or inline-backed data structure with per-element linking can use this. Timer wheels, LRU caches, wait queues, scheduler run queues — all use this pattern.

4. **Caveat: Protocol requirement.** The node type must provide prev/next accessors. This could be:
   - A protocol (`IntrusiveLinked { var prev: Index<Self>? { get set }; var next: Index<Self>? { get set } }`)
   - A key-path-based API
   - A closure-based API (as shown above)

   The closure-based approach avoids protocol constraints but is less ergonomic. The protocol approach is more natural but requires nodes to conform — which is exactly what "intrusive" means.

5. **Caveat: Ownership.** The `using:` closure provides `UnsafeMutablePointer<Node>`, which is inherently unsafe. The caller must guarantee the pointer is valid for the operation's duration. This is the same safety contract as the timer wheel's current code — it doesn't make things worse, but it doesn't make them safer either.

**Verdict: Semantically sound. Modest benefit (saves ~60 lines per consumer) but the pattern is rare enough that the cost/benefit may not justify a new primitive type.**

#### Option D: Status Quo

Keep the timer wheel's ad-hoc intrusive list. Accept that the pattern is specialized enough to not warrant ecosystem infrastructure.

**Semantic Correctness: YES (trivially)**

1. **The current code is correct.** The timer wheel's ~120 lines are well-structured, efficient, and tailored to its exact requirements.

2. **The pattern is rare.** Only 1 of 61+ primitives packages uses intrusive linking. The timer wheel was the only type in the async-primitives audit that didn't delegate to ecosystem infrastructure.

3. **The cost of duplication is low.** ~120 lines across 4 files. If a second intrusive list consumer appears, extraction can be revisited.

**Verdict: Pragmatic default. The investigation confirmed the ad-hoc code is correct for its use case.**

### Comparison

| Criterion | Gap 1: Cursor API | Gap 2A: Pool tokens | Gap 2B: Arena.Linked | Gap 2C: Intrusive helper | Gap 2D: Status quo |
|-----------|:-:|:-:|:-:|:-:|:-:|
| **Semantically correct** | Yes | **No** | Partially | Yes | Yes |
| **Closes timer wheel gap** | Partially (no ABA) | Would close (if correct) | Yes | Yes | N/A |
| **Benefits beyond timer wheel** | High (all list users) | None (wrong abstraction) | Low (narrow) | Medium (LRU, scheduler) | N/A |
| **Implementation effort** | Medium | Medium | High | Medium | None |
| **Abstraction risk** | Low | **High** (Pool/Arena conflation) | Medium (API confusion) | Low | None |
| **Prerequisite for timer wheel** | Necessary but not sufficient | — | Depends on cursor API | Independent | — |

### Key Insight

The two gaps have fundamentally different natures:

**Gap 1 (cursor API)** is a missing feature that belongs in `List.Linked`. It completes the type's semantic contract. Every linked list in every language provides this. It should be added regardless of the timer wheel.

**Gap 2 (ABA protection)** is not a missing feature in `Storage.Pool` — it's a feature that belongs in a *different abstraction* (`Buffer.Arena`), which the timer wheel already uses correctly. The timer wheel's architecture is: Arena (allocation + ABA) + intrusive linking (list operations). Trying to push ABA into Pool or create a hybrid Arena.Linked conflates distinct concerns.

The timer wheel doesn't need `List.Linked` to gain ABA protection. It needs its ad-hoc list operations to remain coupled to its Arena allocation — which is exactly the intrusive pattern.

## Outcome

**Status**: RECOMMENDATION

### Recommended Actions

**1. Add cursor API to `Buffer.Linked` and `List.Linked` (Gap 1)**

Priority: **High** — independently justified, not just for the timer wheel.

- Add `remove(at: Index<Node>)` and `insert(_:after: Index<Node>)` to `Buffer.Linked`
- Surface as `remove(at:)` and `insert(_:after:)` on `List.Linked`
- Constrain to N≥2 (doubly-linked) for O(1) guarantee, or document O(n) for N=1
- This is already tracked as the #1 gap in list-primitives research

**2. Do NOT add generation tokens to `Storage.Pool` (Gap 2A)**

This would violate the Pool/Arena semantic boundary. The correct abstraction for temporal safety is Arena, which the ecosystem already provides.

**3. Do NOT create `Buffer.Arena.Linked` (Gap 2B)**

Adds complexity for a narrow use case. The intrusive pattern (decoupled allocation + linking) is a better fit for arena-backed concurrent data structures than a self-contained list type.

**4. Defer intrusive list extraction (Gap 2C)**

Semantically sound but premature. The timer wheel is the only consumer. If a second intrusive list consumer appears (LRU cache, scheduler run queue, wait queue), extract at that point.

**5. Timer wheel keeps its current design (Gap 2D)**

The ad-hoc intrusive list is correct, efficient, and well-matched to the timer wheel's requirements. The cursor API improvement (action 1) would not change this — the timer wheel needs Arena-backed allocation with generation tokens, which `List.Linked` (Pool-backed) cannot provide even with a cursor API.

### Net Effect on Timer Wheel

After implementing recommendation 1 (cursor API): **the timer wheel's intrusive list is still the correct design.** The cursor API benefits `List.Linked` users broadly, but the timer wheel's requirements (Arena-backed allocation + multi-head sharing + generation-stamped handles) are inherently an intrusive pattern, not a self-contained list pattern.

The ~120 lines of manual list management remain justified.

## References

- `swift-list-primitives/Research/list-discipline-boundary-analysis.md` — STL and Rust RFC 2570 prior art for cursor API
- `swift-list-primitives/Research/list-operations-audit.md` — Gap analysis identifying delete(node) as high priority
- `swift-async-primitives/HANDOFF-timer-wheel-intrusive-list.md` — Source investigation with complete findings
- `swift-primitives/Research/memory-pool-arena-buffer-usage-analysis.md` — Pool vs Arena semantic distinction
- `swift-primitives/Research/storage-arena-architecture.md` — Storage.Arena architecture and Memory.Arena composition
- C++ STL `std::list::erase(iterator)` — positional removal as core list API
- Rust RFC 2570 (Linked List Cursors) — cursor API design for doubly-linked lists
