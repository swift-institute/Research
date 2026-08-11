# Heap Discipline Boundary Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute primitives architecture establishes a strict four-layer dependency chain:

```
Memory (Tier 13) -> Storage (Tier 14) -> Buffer (Tier 15) -> Data Structure (Tier 16+)
```

`heap-primitives` sits at the top of this chain, wrapping `Buffer.Linear` (and its variants) to present a consumer-facing heap/priority-queue abstraction. The question: does `heap-primitives` contain ONLY heap-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-heap-primitives).

## Question

What semantics belong SOLELY to the heap abstraction layer, and does `heap-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Priority Queue ADT -- Formal Axioms (Liskov & Guttag / Wikipedia)

The priority queue is an abstract data type where each element has an associated priority that determines its order of service. The formal ADT specification defines:

```
Operations: new(), insert(v, PQ), find-minimum(PQ), delete-minimum(PQ)

Axioms:
  min(insert(v, new())) = v
  min(insert(v, insert(w, PQ))) =
    if priority(v) < priority(min(insert(w, PQ)))
    then v
    else min(insert(w, PQ))
  dm(insert(v, insert(w, PQ))) =
    if priority(v) < priority(min(insert(w, PQ)))
    then insert(w, PQ)
    else insert(v, dm(insert(w, PQ)))
```

The ADT mentions NO implementation concerns: no array, no tree, no capacity, no pointers. The priority queue is purely the **priority-ordered insertion/extraction contract with ordering laws**. A heap is one maximally efficient implementation of this ADT.

**Key distinction from Array ADT**: An array provides an indexed read-write contract (get/set at position). A heap provides a priority-ordered insertion/extraction contract. The heap does NOT expose positional indexing to consumers -- the internal array positions are an implementation detail of the implicit tree encoding.

### Source 2: Rust `BinaryHeap<T>` (std::collections)

Rust's `BinaryHeap` is a max-heap by default. Its public API surface:

- `push(item)` -- O(log n) insertion
- `pop() -> Option<T>` -- O(log n) extract-max
- `peek() -> Option<&T>` -- O(1) view max
- `into_sorted_vec()` -- consumes heap, returns sorted
- `into_vec()` -- consumes heap, returns unordered backing vec
- `len()`, `is_empty()`, `capacity()`, `reserve()`, `shrink_to_fit()`
- `drain()` -- removes all elements as iterator
- `retain()` -- keeps elements matching predicate
- `iter()` -- unordered iteration (NOT sorted)
- `append(&mut other)` -- merges two heaps
- `peek_mut() -> Option<PeekMut<T>>` -- mutable access to max with auto-sift on drop

Rust exposes `into_vec()` and `capacity()` -- buffer-level concerns -- because `BinaryHeap` is the ONLY abstraction layer (no separate buffer). In our architecture, `Buffer.Linear` already owns capacity/growth/CoW. The heap layer should be thinner.

Critically: Rust documents that "it is a logic error for an item to be modified in such a way that the item's ordering relative to any other item changes while it is in the heap." This is the **ordering invariant contract** -- solely heap discipline.

### Source 3: C++ STL `std::priority_queue` and `make_heap`/`push_heap`/`pop_heap`

C++ provides TWO levels of heap abstraction:

1. **Algorithm-level** (`<algorithm>`): `make_heap`, `push_heap`, `pop_heap`, `sort_heap`, `is_heap`, `is_heap_until` -- operate on random-access iterators. These are the heap *discipline* operations separated from any container.

2. **Container adaptor** (`std::priority_queue`): wraps a container (default `std::vector`) and calls the algorithm functions automatically. Public API: `push()`, `pop()`, `top()`, `empty()`, `size()`.

The C++ design makes the layering explicit: the heap algorithms are pure ordering discipline, and the container adaptor is consumer ergonomics wrapping a buffer. This maps perfectly to our architecture:

- `make_heap` / `push_heap` / `pop_heap` = our `heapify()` / `bubbleUp()` / `trickleDown()`
- `std::priority_queue` = our `Heap` type wrapping `Buffer.Linear`

### Source 4: Haskell `Data.Heap` (Purely Functional)

Haskell's `Data.Heap` from Okasaki's "Purely Functional Data Structures" provides:

- `MinHeap`, `MaxHeap`, `MinPrioHeap`, `MaxPrioHeap` -- typed by ordering
- `empty`, `null`, `size` -- construction and query
- `insert`, `viewMin`, `extractMin` -- core operations
- `union`, `unions` -- mergeable heap (leftist-heap specific)
- `map`, `filter`, `partition`, `foldl`, `toList`, `fromList`

Haskell uses a leftist tree (not array-backed), making the distinction between "implicit tree in array" and "heap discipline" even clearer. The heap discipline is the ordering property and the extract-extremum contract. The array representation is an implementation choice, not part of the ADT.

### Source 5: Heap vs Sorted Array vs BST -- What Heap SOLELY Owns

| Property | Heap | Sorted Array | BST |
|----------|------|-------------|-----|
| Find-min/max | O(1) | O(1) | O(log n) |
| Insert | O(log n) | O(n) | O(log n) |
| Extract-min/max | O(log n) | O(1)/O(n) | O(log n) |
| Decrease-key | O(log n) | O(n) | O(log n) |
| Ordering type | **Partial** (parent-child only) | Total | Total |
| Access pattern | Priority-first | Position-first | Key-first |

The heap's unique contribution is the **partial ordering invariant**: given two nodes' positions, we can only determine their relative order if one is an ancestor of the other. This is weaker than a BST's total ordering but enables more efficient priority operations. The heap deliberately sacrifices positional access (unlike Array) and total ordering (unlike BST) to optimize for the priority-extraction use case.

### Source 6: The Implicit Tree Question -- Is It Heap Discipline or Buffer Concern?

A binary heap stores elements in an array using Eytzinger's method (breadth-first layout), computing parent-child relationships via arithmetic: `parent(i) = (i-1)/2`, `left(i) = 2i+1`, `right(i) = 2i+2`.

This decomposes into two concerns:

1. **Buffer concern**: The contiguous memory, capacity management, element lifecycle, and indexed access. Buffer provides `_buffer[index]`, `_buffer.swap(at:with:)`, `_buffer.append()`, `_buffer.removeLast()`.

2. **Heap concern**: The *interpretation* of array indices as tree positions. The parent/child arithmetic, the decision to swap or not based on ordering, and the invariant that parent <= children (min-heap) or parent >= children (max-heap).

**Verdict**: The implicit tree navigation (parent/child computation) is **solely heap discipline**. The buffer knows nothing about tree structure -- it just provides indexed storage. The heap layer adds the tree *interpretation* of those indices. This is analogous to how Array adds the *density invariant* interpretation of buffer positions.

### Source 7: Min-Max Heap (Atkinson, Sack, Santoro, Strothotte 1986)

The min-max heap is a complete binary tree where levels alternate between min-levels and max-levels. The root is at a min-level. A node at a min-level is less than or equal to all its descendants; a node at a max-level is greater than or equal to all its descendants.

This introduces a **level-parity invariant** that goes beyond the simple parent-child comparison of a standard binary heap. The level classification (`isMinLevel`) and the dual trickle-down procedures (`trickleDownMin`/`trickleDownMax`) are additional heap-discipline concerns that have no analogue in the buffer layer.

---

## Analysis

### What is SOLELY Heap Discipline

#### A. The Ordering Invariant (Heap Property)

The heap's primary contribution: maintaining a partial ordering over elements such that the priority element (min or max) is always accessible at the root in O(1).

| Invariant | What it provides | Why not in Buffer |
|-----------|-----------------|-------------------|
| Parent <= children (min-heap) | O(1) min access, O(log n) insert/extract | Buffer has no concept of element ordering |
| Parent >= children (max-heap) | O(1) max access, O(log n) insert/extract | Same |
| Alternating min/max levels (MinMax) | O(1) access to BOTH extremes | Same |
| Ordering preserved after mutation | `bubbleUp`/`trickleDown` restore invariant | Buffer mutations are order-agnostic |

#### B. Implicit Tree Navigation

The interpretation of array indices as positions in a complete binary tree is purely heap discipline.

| Navigation | What it provides | Why not in Buffer |
|------------|-----------------|-------------------|
| `Navigate.parent(of:)` | `(i-1)/2` parent computation | Buffer indices are flat/linear |
| `Navigate.child(.left, of:)` | `2i+1` left child computation | Same |
| `Navigate.child(.right, of:)` | `2i+2` right child computation | Same |
| `Navigate.lastNonLeaf` | Starting point for Floyd's heapify | Same |
| `isMinLevel(for:)` | Level-parity classification for MinMax | Same |
| `Navigate.isValid(_:)` | Bounds check in tree context | Buffer has its own bounds checking |

#### C. Heap Algorithms

| Algorithm | What it provides | Why not in Buffer |
|-----------|-----------------|-------------------|
| `bubbleUp(_:)` | Restore heap property after insertion | Buffer has no ordering concept |
| `trickleDown(_:)` | Restore heap property after extraction | Same |
| `trickleDownMin(_:)` | MinMax: restore min-level invariant | Same |
| `trickleDownMax(_:)` | MinMax: restore max-level invariant | Same |
| `heapify()` | Floyd's O(n) bottom-up construction | Same |
| `insert(_:)` | Append + bubbleUp | Same |
| `removePriority()` | Swap root with last + removeLast + trickleDown | Same |
| `removeMin()` / `removeMax()` | MinMax: targeted extremum removal | Same |

#### D. Priority Contract (Public API)

| API | What it provides | Why not in Buffer |
|-----|-----------------|-------------------|
| `push(_:)` | Insert with heap property maintenance | Buffer `append` has no ordering |
| `pop() throws` | Extract priority element with typed error | Buffer has no priority concept |
| `take -> Element?` | Optional priority extraction | Same |
| `peek -> Element?` | O(1) read of priority element | Buffer has no "priority" position |
| `withPriority(_:)` | Borrowing access to root (~Copyable) | Same |
| `withMin(_:)` / `withMax(_:)` | MinMax: borrowing access to extremes | Same |
| `min.peek` / `min.pop()` / `min.take` | MinMax: min-end operations | Same |
| `max.peek` / `max.pop()` / `max.take` | MinMax: max-end operations | Same |
| `peek.min` / `peek.max` | MinMax: non-mutating read of extremes | Same |

#### E. Ordering Configuration

| Feature | What it provides | Why not in Buffer |
|---------|-----------------|-------------------|
| `Heap.Order` (.ascending / .descending) | Configurable heap polarity | Buffer is order-agnostic |
| `Heap.MinMax.Position` (.min / .max) | Which end to operate on | Same |
| `Comparison.Protocol` constraint | Element ordering requirement | Buffer works with any element type |

#### F. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Heap.Fixed` -- bounded priority queue | Fixed-capacity heap with overflow semantics |
| `Heap.Static<capacity>` -- inline heap | Compile-time capacity, zero allocation |
| `Heap.Small<inlineCapacity>` -- SBO heap | Small-buffer optimized priority queue |
| `Heap.MinMax` -- double-ended | Both min and max in O(1) |
| `Heap.Push.Outcome` (.inserted / .overflow) | Type-safe overflow handling for bounded variants |
| `Heap.Binary` typealias | API symmetry with `Heap.MinMax` |
| `Heap.Min` / `Heap.Max` (stubs) | Future single-ended specializations |
| Conditional Copyable/Sendable | Element-dependent type-level guarantees |

#### G. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `Heap`/`Fixed`/`Static`/`Small`/`MinMax` family |
| `Heap.Iterator` / `Heap.Fixed.Iterator` / etc. | Iterator types wrapping buffer internals |
| `init(_ elements:order:)` | Sequence-based construction with O(n) heapify |
| `ExpressibleByArrayLiteral` | `[1, 2, 3]` syntax (heapifies on construction) |
| `Equatable` / `Hashable` | Structural equality (heap-order dependent) |
| `CustomStringConvertible` | Debug-friendly descriptions |
| `Sequence.Protocol` / `Swift.Sequence` | Iteration (in heap order, NOT sorted) |
| `Sequence.Clearable` / `Sequence.Drain.Protocol` | Drain/consuming patterns |
| Property.View patterns | `.remove.all()`, `.drain { }`, `.forEach { }`, `.min.pop()`, `.max.take` |
| Error types with descriptions | `Heap.Error`, `Fixed.Error`, `Static.Error`, `Small.Error` |
| `unordered` view | Explicit "this is NOT sorted" access |
| `truncate(to:)` | Reduce count (Fixed/Static/Small variants) |

### What Buffer.Linear Owns (Heap Merely Delegates)

| Concern | Owned by Buffer.Linear |
|---------|----------------------|
| Memory allocation/deallocation | Creates/destroys `Storage.Heap` |
| Capacity tracking | `Header.capacity` |
| Count tracking | `Header.count` |
| Growth policy | `Buffer.Growth.Policy` |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via `Storage` |
| Raw pointer access | `pointer(at:)` |
| Contiguous memory guarantee | `Span.Protocol` |
| Header state machine | `isEmpty`, `isFull` |
| Indexed subscript | Direct pointer arithmetic (`_buffer[index]`) |
| `swap(at:with:)` | Element exchange by index |
| `append(_:)` | Add element to end |
| `removeLast()` | Remove element from end |
| `removeAll()` | Destroy all elements |
| Span/MutableSpan access | Contiguous element views |

---

## Audit: Current heap-primitives

### Audit Methodology

For each file in `heap-primitives`, classify every public API member as:
- **HEAP**: Solely heap discipline (ordering invariant, priority contract, tree navigation, heap algorithms, ergonomics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo`)
- **CONTESTED**: Could belong to either layer

### Findings

#### Pure Heap Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `Heap.Order` enum (.ascending/.descending) | Ordering config | `Heap.swift` |
| `Heap.MinMax.Position` enum (.min/.max) | Ordering config | `Heap.MinMax.swift` |
| `Heap.Navigate` struct | Tree navigation | `Heap.Navigate.swift` |
| `Navigate.parent(of:)` | Tree navigation | `Heap.Navigate.swift` |
| `Navigate.child(_:of:)` | Tree navigation | `Heap.Navigate.swift` |
| `Navigate.isValid(_:)` | Tree navigation | `Heap.Navigate.swift` |
| `Navigate.lastNonLeaf` | Tree navigation | `Heap.Navigate.swift` |
| `Navigate.leftChildOfRoot` / `rightChildOfRoot` | Tree navigation | `Heap.Navigate.swift` |
| `Navigate.Child` enum (.left/.right) | Tree navigation | `Heap.Navigate.swift` |
| `isMinLevel(for:)` | MinMax level classification | `Heap.MinMax ~Copyable.swift` |
| `Int._binaryLogarithm()` | MinMax level computation | `Heap.MinMax ~Copyable.swift` |
| `bubbleUp(_:)` (all variants) | Heap algorithm | All `~Copyable.swift` files |
| `trickleDown(_:)` (all variants) | Heap algorithm | All `~Copyable.swift` files |
| `trickleDownMin(_:)` / `trickleDownMax(_:)` | MinMax heap algorithm | `Heap.MinMax ~Copyable.swift` |
| `heapify()` (all variants) | Floyd's algorithm | All `~Copyable.swift` files |
| `insert(_:)` (all variants) | Append + bubbleUp | All `~Copyable.swift` files |
| `removePriority()` (all variants) | Swap + removeLast + trickleDown | All `~Copyable.swift` files |
| `removeMin()` / `removeMax()` | MinMax extraction | `Heap.MinMax ~Copyable.swift` |
| `push(_:)` (all variants) | Public insert API | All `~Copyable.swift` + `Copyable.swift` |
| `pop() throws` (all variants) | Typed-throw extraction | All `Copyable.swift` and `~Copyable.swift` files |
| `take -> Element?` (all variants) | Optional extraction | All files |
| `peek -> Element?` (all variants) | O(1) read of priority | All `Copyable.swift` files |
| `peek.min` / `peek.max` (MinMax) | Non-mutating peek accessor | `Heap.MinMax Copyable.swift` |
| `min.peek` / `min.pop()` / `min.take` | MinMax min-end operations | `Heap.MinMax Copyable.swift` |
| `max.peek` / `max.pop()` / `max.take` | MinMax max-end operations | `Heap.MinMax Copyable.swift` |
| `withPriority(_:)` | Borrowing access to root | All `~Copyable.swift` |
| `withMin(_:)` / `withMax(_:)` | MinMax borrowing access | `Heap.MinMax ~Copyable.swift` |
| `root -> Heap.Index?` | Root index accessor | All `~Copyable.swift` |
| `navigate -> Navigate` | Navigation accessor | All `~Copyable.swift` |
| `Heap.Push.Outcome` (.inserted/.overflow) | Bounded push result | `Heap.swift` |
| `element(at:) -> Element?` | Bounds-checked index access | `Heap Copyable.swift`, `Heap.Fixed Copyable.swift` |
| `unordered -> Buffer<Element>.Linear` | Explicit unordered view | `Heap Copyable.swift` |
| `replacePriority(with:)` | Replace root + trickleDown | `Heap Copyable.swift` |
| `init(_ elements:order:)` | Sequence init with heapify | `Heap Copyable.swift`, `Heap.Fixed Copyable.swift`, `Heap.MinMax Copyable.swift` |
| `ExpressibleByArrayLiteral` | Array literal with heapify | `Heap Copyable.swift`, `Heap.MinMax Copyable.swift` |
| `Equatable` / `Hashable` | Structural comparison | `Heap Copyable.swift`, `Heap.MinMax Copyable.swift` |
| `CustomStringConvertible` | Debug descriptions | `Heap Copyable.swift`, `Heap.MinMax Copyable.swift` |
| `Sequence.Protocol` / `Swift.Sequence` | Heap-order iteration | All `Copyable.swift` files |
| `Heap.Iterator` / `Fixed.Iterator` / etc. | Iterator types | All `Copyable.swift` files |
| `Sequence.Clearable` / `Sequence.Drain.Protocol` | Drain/consuming patterns | All `Copyable.swift` files |
| Property.View accessors (remove, drain, forEach, etc.) | Consumer ergonomics | All files |
| `truncate(to:)` | Reduce count | `Heap.Fixed ~Copyable.swift`, `Heap.Static ~Copyable.swift`, `Heap.Small ~Copyable.swift` |
| `remove.all(keepingCapacity:)` | Remove all elements | `Heap ~Copyable.swift`, `Heap.MinMax.swift` |
| Error types + descriptions | Error handling | All `Error.swift` files |
| Conditional `Copyable` / `Sendable` | Type-level guarantees | `Heap.swift` |
| Variant taxonomy and namespace | Architecture | `Heap.swift` |
| `Heap.Index` typealias | Type-safe indexing | `Heap.Index.swift` |
| `Heap.Ordering` typealias | Comparison protocol alias | `Heap.swift` |
| `Heap.Binary` typealias | API symmetry | `Heap.swift` |
| `Heap.Min` / `Heap.Max` stubs | Future specialization | `Heap.Min.swift`, `Heap.Max.swift` |

#### Pure Delegation (correctly placed -- thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `_buffer.count` | Buffer.Linear.Header | **OK** -- Heap surface for buffer state |
| `var isEmpty` -> `_buffer.isEmpty` | Buffer.Linear.Header | **OK** |
| `var capacity` -> `_buffer.capacity` | Buffer.Linear.Header | **OK** (Fixed/Small only) |
| `var isFull` -> `_buffer.isFull` | Buffer.Linear.Header | **OK** (Fixed/Static only) |
| `forEach(_:)` -> `_buffer.forEach(_:)` | Buffer.Linear | **OK** -- heap-order traversal delegates to buffer |
| `var span` -> `_buffer.span` | Buffer.Linear | **OK** |
| `var mutableSpan` -> `_buffer.mutableSpan` | Buffer.Linear | **OK** |
| `var isSpilled` -> `_buffer.isSpilled` | Buffer.Linear.Small | **CONTESTED** (see below) |
| `makeUnique()` / `ensureUnique()` | Buffer.Linear CoW | **OK** -- CoW is buffer's, heap triggers it before mutation |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `isSpilled` on `Heap.Small` | Exposes buffer implementation detail (inline vs heap storage). | **CONTESTED** -- a user reasonably wants to know if their small-buffer-optimized heap has spilled to the heap. This is a valid consumer-facing diagnostic property. The SmallVec pattern's value proposition depends on knowing when you've spilled. Keep it, but acknowledge it leaks buffer abstraction. |
| `mutableSpan` on Fixed/Small | Provides mutable access to heap elements with warning "may break heap invariant". | **CONTESTED** -- exposing raw mutable access to heap-ordered storage is inherently risky. The warning is appropriate, but this essentially exposes buffer internals. Justified for advanced use cases (e.g., custom re-heapify after batch mutation), but should be clearly documented as an escape hatch. |
| `span` on Fixed/Small | Read-only contiguous view of heap-ordered elements. | **MINOR** -- useful for zero-copy inspection, but exposes the contiguous nature of the underlying buffer. Acceptable because the implicit-tree-in-array layout is part of binary heap's identity. |
| `unordered` on Heap | Returns a `Buffer<Element>.Linear` copy of elements. | **CONTESTED** -- the return type is `Buffer<Element>.Linear`, directly exposing the buffer layer's type in the heap's public API. Consider returning an opaque collection or at minimum documenting this is a copy, not a view into the buffer. Currently correctly documented as O(n) copy. |
| Duplicated `bubbleUp`/`trickleDown`/`heapify` across Heap/Fixed/Static/Small | Code duplication because buffer variants are distinct types. | **ARCHITECTURAL** -- noted in source comments as "duplicated because Buffer.Linear variants are distinct types with no shared protocol." This is not a layering violation but an observation about the buffer layer's type structure. If buffer-primitives adds a shared protocol, these can be consolidated. |
| `Equatable` comparing heap-order arrays | Two heaps are equal iff same count, same order, and same elements in the same heap-order positions. | **NOTE** -- this means two heaps with the same logical elements but different insertion orders may NOT be equal (because heap ordering is not unique). This is correct for structural equality but differs from the mathematical set/multiset equality that a priority queue ADT might suggest. |
| `appendWithoutHeapify(_:)` | Package-scoped method that bypasses heap invariant for bulk loading. | **OK** -- this is correctly package-scoped (not public). Used only by `init(_ elements:)` before calling `heapify()`. The invariant is temporarily violated but restored before any public operation. |

### What's MISSING from Heap (things that are solely heap discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `decrease-key` / `increase-key` | Core heap operation | Medium -- requires index tracking; the ADT defines it but many implementations omit it |
| `merge` / `union` of two heaps | ADT operation | Low -- O(n) for binary heaps, only efficient for mergeable heaps (binomial, Fibonacci) |
| `init(order:minimumCapacity:)` | Capacity hint | Low -- allows pre-allocation without elements |
| Sorted drain (`while let e = heap.take { }`) | Ergonomic | Low -- already possible via `take` in a loop; a dedicated sorted iterator would be O(n log n) |
| `contains(_:)` on all variants | Query | Low -- O(n) linear scan, useful but not heap-specific |
| `Heap.MinMax.Fixed` full operations | Completeness | Medium -- currently stub only |
| `Heap.MinMax.Static` full operations | Completeness | Medium -- currently stub only |
| `Heap.MinMax.Small` full operations | Completeness | Medium -- currently stub only |
| `Heap.Min` / `Heap.Max` implementations | Completeness | Low -- `Heap(order: .ascending)` covers this |
| `Equatable` / `Hashable` for `Heap.Fixed` | Algebraic | Medium -- present on `Heap` and `Heap.MinMax` but not variants |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: heap-primitives is well-layered

The current `heap-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Heap algorithms** -- `bubbleUp`, `trickleDown`, `heapify`, `removePriority`, and their MinMax variants are purely heap discipline. The buffer knows nothing about tree structure or ordering.
2. **Priority contract** -- `push`, `pop`, `take`, `peek`, `withPriority`, and the MinMax `min`/`max` accessors are the heap's unique semantic contribution.
3. **Tree navigation** -- `Navigate` with parent/child computation is solely heap discipline.
4. **Pure delegation** -- count, isEmpty, capacity, isFull, span are thin wrappers surfacing buffer state at the heap level.

The critical test: **could these operations exist on a different backing structure** (e.g., a linked list, a Fibonacci heap tree)? The heap algorithms, priority contract, and tree navigation are all independent of the buffer's internal mechanics. The buffer provides indexed storage; the heap adds the ordering interpretation. This is clean separation.

### Specific Recommendations

#### 1. `mutableSpan` needs stronger documentation (Minor)

`Heap.Fixed` and `Heap.Small` expose `mutableSpan` with a warning that "modifying elements may break the heap invariant." This is correct but should explicitly state that callers MUST call a re-heapify operation after modification, or provide a `withMutableSpan(_:)` method that automatically re-heapifies after the closure returns.

#### 2. `unordered` return type leaks buffer abstraction (Minor)

`Heap.unordered` returns `Buffer<Element>.Linear` -- a buffer-layer type in the heap's public API. Consider whether this should return `[Element]` (Swift Array) or remain as-is for performance. The current approach avoids a copy into a different container type, so it is pragmatically justified. At minimum, this is a conscious design choice, not an accidental leak.

#### 3. `isSpilled` is acceptable (Keep)

`Heap.Small.isSpilled` exposes a buffer detail, but it is a *diagnostic* property that users legitimately need. The SmallVec pattern's value proposition depends on knowing when you've spilled. Keep it.

#### 4. Code duplication across variants is architectural, not a layering violation

The `bubbleUp`/`trickleDown`/`heapify` algorithms are duplicated across `Heap`, `Heap.Fixed`, `Heap.Static`, and `Heap.Small` because the buffer variants (`Buffer.Linear`, `Buffer.Linear.Bounded`, `Buffer.Linear.Inline`, `Buffer.Linear.Small`) are distinct types with no shared protocol. The source code correctly notes this with comments like "duplicated because Buffer.Linear variants are distinct types with no shared protocol. If buffer-primitives adds a shared protocol, consolidate." This is a buffer-layer concern to potentially address in the future.

#### 5. No buffer concerns have leaked upward

The audit found **zero instances** of heap-primitives doing work that properly belongs to the buffer layer. All storage management, growth, CoW, element lifecycle, and contiguous-memory operations are handled by `Buffer.Linear` and its variants. The heap's `_buffer` stored property is the only coupling, and it is correctly `package`-scoped.

#### 6. Equatable semantics are structural, not logical (Document)

The current `Equatable` implementation compares heaps by their array representation (same count, same order, same elements at same positions). This means two heaps containing the same multiset of elements but with different internal arrangements (due to different insertion orders) will NOT be equal. This is correct for structural equality but should be documented to avoid confusion with logical priority-queue equivalence.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure heap discipline (algorithms + navigation + priority contract) | 40+ distinct APIs | Correctly placed |
| Consumer ergonomics (iterators, literals, conformances, error types) | 20+ distinct APIs | Correctly placed |
| Pure delegation | 9 passthrough properties/methods | Correctly placed -- thin wrapping is the design intent |
| Buffer concern leaked into heap | **0** | Clean separation |
| Heap concern missing | 8-10 items | Future work, not a layering violation |
| Contested (acceptable) | 4 items | `isSpilled`, `mutableSpan`, `span`, `unordered` -- all justified |

---

## References

- Wikipedia, "Priority queue": formal ADT axioms (insert, find-minimum, delete-minimum)
- Wikipedia, "Heap (data structure)": heap property definition, implementation variants
- Wikipedia, "Min-max heap": Atkinson et al. 1986 double-ended priority queue
- Wikipedia, "Binary heap": implicit tree representation, Eytzinger's method
- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms
- Okasaki, "Purely Functional Data Structures": leftist heaps, mergeable heaps
- [Rust `std::collections::BinaryHeap` documentation](https://doc.rust-lang.org/std/collections/struct.BinaryHeap.html): API surface, ordering invariant contract
- [C++ `std::priority_queue`](https://cplusplus.com/reference/queue/priority_queue/): container adaptor wrapping heap algorithms
- [C++ `make_heap` / `push_heap` / `pop_heap`](https://hackingcpp.com/cpp/std/algorithms/heap_operations.html): algorithm-level heap discipline
- [Haskell `Data.Heap`](https://hackage.haskell.org/package/heap): functional heap variants
- [Sedgewick & Wayne, "Algorithms" -- Priority Queues](https://algs4.cs.princeton.edu/24pq/): priority queue implementations
- [Yale CS (Aspnes) -- Heaps](https://www.cs.yale.edu/homes/aspnes/pinewiki/Heaps.html): heap partial ordering vs BST total ordering
- [Baeldung -- Decrease-Key Operation for Min-Heaps](https://www.baeldung.com/cs/min-heaps-decrease-key): decrease-key analysis
- [OpenDSA -- Heaps and Priority Queues](https://opendsa-server.cs.vt.edu/ODSA/Books/CS3/html/Heaps.html): heap vs sorted array vs BST comparison
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md` (template)
