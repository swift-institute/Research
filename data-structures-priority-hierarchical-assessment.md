# Priority / Hierarchical -- Post-Refactor Assessment

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
supersedes: v1.0.0 (Stack Migration Assessment)
---
-->

## Context

The three foundational storage packages -- `swift-buffer-primitives`, `swift-storage-primitives`, and `swift-memory-primitives` -- have been refactored, now compile, and pass tests. This assessment audits the Priority / Hierarchical tier (Heap, Tree, Graph) against the refactored stack.

**v1.0.0** documented the pre-refactor state: Heap was 98% migrated (4 legacy `_storage` references in Heap Binary Primitives), Tree was entirely unmigrated (raw `ManagedBuffer` subclass with manual pointers), and Graph was N/A (compositional).

**v2.0.0** documents the post-refactor state. All three packages have been fully updated.

## Summary

**All three packages are fully migrated.** Heap uses `Buffer.Linear` family types for all variants. Tree has been completely rewritten from raw `ManagedBuffer` to `Buffer.Arena` family types. Graph remains compositional (no own storage) and benefits transitively. The v1.0.0 legacy `_storage` references in Heap Binary Primitives have been resolved. Zero Foundation imports. All typed throws. Naming conventions compliant.

---

## Heap (swift-heap-primitives)

### Current State

Heap provides ten variants across nine modules:

| Variant | Module | Storage Field | Buffer Type |
|---------|--------|---------------|-------------|
| `Heap<Element>` | Heap Primitives Core | `_buffer: Buffer<Element>.Linear` | Growable linear buffer |
| `Heap<Element>.Fixed` | Heap Fixed Primitives | `_buffer: Buffer<Element>.Linear.Bounded` | Fixed-capacity linear buffer |
| `Heap<Element>.Static<capacity>` | Heap Static Primitives | `_buffer: Buffer<Element>.Linear.Inline<capacity>` | Compile-time inline storage |
| `Heap<Element>.Small<inlineCapacity>` | Heap Small Primitives | `_buffer: Buffer<Element>.Linear.Small<inlineCapacity>` | Small-buffer optimization |
| `Heap<Element>.MinMax` | Heap MinMax Primitives | `_buffer: Buffer<Element>.Linear` | Growable linear buffer |
| `Heap<Element>.MinMax.Fixed` | Heap MinMax Primitives | `_buffer: Buffer<Element>.Linear.Bounded` | Fixed-capacity linear buffer |
| `Heap<Element>.MinMax.Static<capacity>` | Heap MinMax Primitives | `_buffer: Buffer<Element>.Linear.Inline<capacity>` | Compile-time inline storage |
| `Heap<Element>.MinMax.Small<inlineCapacity>` | Heap MinMax Primitives | `_buffer: Buffer<Element>.Linear.Small<inlineCapacity>` | Small-buffer optimization |
| `Heap<Element>.Min` | Heap Min Primitives | N/A (fatalError stub) | N/A |
| `Heap<Element>.Max` | Heap Max Primitives | N/A (fatalError stub) | N/A |

### Dependencies

```
Buffer_Linear_Primitives    (primary storage)
Comparison_Primitives        (borrowing comparison for ~Copyable)
Index_Primitives             (Heap.Index typealias)
Property_Primitives          (Property.View.Typed accessors)
Collection_Primitives        (Sequence.Protocol, Sequence.Clearable)
Input_Primitives             (input conversion)
Sequence_Primitives          (Sequence.Drain.Protocol, Sequence.ForEach, etc.)
```

### Storage Mechanism

All variants delegate to `Buffer.Linear` family types. No manual memory management (`UnsafeMutablePointer.allocate/deallocate`, `initialize/deinitialize`) exists in the heap package. All capacity management, growth, and CoW are handled by the buffer layer.

### Findings

| ID | Severity | File | Line(s) | Convention | Description |
|----|----------|------|---------|------------|-------------|
| H1 | LOW | `Heap Primitives Core/Heap.swift` | 62-247 | [COPY-FIX-002] | Multiple types declared in `Heap` struct body: `Order`, `Error`, `Fixed`, `Push`, `Push.Outcome`, `Static`, `Small`, `MinMax`, `Binary` typealias. This is a **principled exception** -- value-generic types (`Static`, `Small`) and the `MinMax` type must be nested in the primary declaration for proper `~Copyable` constraint propagation. Documented with `// per COPY-FIX-002` comments. |
| H2 | LOW | `Heap Primitives Core/Heap.Storage.swift` | all | -- | Intentionally emptied file. Comment states "Heap.Storage has been replaced by Buffer.Linear from swift-buffer-primitives." Consider removing the file entirely to reduce confusion. |
| H3 | LOW | `Heap Primitives Core/Heap.Storage.Inline.swift` | all | -- | Same as H2. Intentionally emptied stub referencing old `Buffer.Linear.Inline` replacement. |
| H4 | LOW | `Heap Min Primitives/Heap.Min.swift` | 31 | -- | `fatalError("Heap.Min is not yet implemented.")` stub. Users hitting this at runtime get no compile-time protection. |
| H5 | LOW | `Heap Max Primitives/Heap.Max.swift` | 31 | -- | Same as H4 for `Heap.Max`. |
| H6 | LOW | `Heap MinMax Primitives/Heap.MinMax.Fixed ~Copyable.swift` | all | -- | Declared with correct `Buffer<Element>.Linear.Bounded` storage but no operations beyond init. Stub for future implementation. |
| H7 | LOW | `Heap MinMax Primitives/Heap.MinMax.Static ~Copyable.swift` | all | -- | Stub file -- comment only: "Stub for future Heap.MinMax.Static ~Copyable operations." |
| H8 | LOW | `Heap MinMax Primitives/Heap.MinMax.Small ~Copyable.swift` | all | -- | Same as H7 for `Heap.MinMax.Small`. |
| H9 | **RESOLVED** | `Heap Binary Primitives/Heap Copyable.swift` | 28, 181-186 | -- | v1.0.0 identified 4 legacy `_storage` references. Now fully resolved: `underestimatedCount` uses `Int(bitPattern: count.rawValue)` (line 28), `drain` method uses `_buffer.ensureUnique()`, `_buffer.isEmpty`, `_buffer.removeLast()` (lines 182-184). |
| H10 | LOW | `Heap MinMax Primitives/Heap.MinMax ~Copyable.swift` | varies | -- | `Node` struct contains raw `Int` fields (`offset`, `level`). `_binaryLogarithm()` extension on `Int`. These are internal implementation details for the min-max heap level determination algorithm. Principled use of raw `Int` for bit-level computation. |
| H11 | PASS | all files | -- | [PRIM-FOUND-001] | Zero Foundation imports across entire package. |
| H12 | PASS | all files | -- | [API-ERR-001] | All throwing functions use typed throws: `throws(Heap.Error)`, `throws(Heap.Fixed.Error)`, `throws(Heap.Static.Error)`, `throws(Heap.Small.Error)`. |

### ~Copyable Status

Clean separation between `~Copyable` base operations (push, pop, bubbleUp, trickleDown, heapify) and `Copyable`-only extensions (Sequence conformance, Equatable, Hashable, ExpressibleByArrayLiteral, CoW). Value-generic types (`Static`, `Small`) are unconditionally `~Copyable` due to deinit requirements. `Heap`, `Heap.Fixed`, and `Heap.MinMax` are conditionally `Copyable where Element: Copyable`.

---

## Tree (swift-tree-primitives)

### Current State

Tree has been **completely rewritten** since v1.0.0. The raw `ManagedBuffer` subclass with manual `UnsafeMutablePointer` management has been replaced with `Buffer.Arena` family types from `swift-buffer-primitives`.

**Tree.N (bounded-arity, n children per node):**

| Variant | Storage Field | Buffer Type |
|---------|---------------|-------------|
| `Tree.N<Element, n>` (dynamic) | `_arena: Buffer<Node>.Arena` | Growable arena with CoW |
| `Tree.N.Bounded` | `_arena: Buffer<Node>.Arena.Bounded` | Fixed-capacity arena |
| `Tree.N.Inline<capacity>` | `_arena: Buffer<Node>.Arena.Inline<capacity>` | Zero-allocation inline arena |
| `Tree.N.Small<inlineCapacity>` | `_arena: Buffer<Node>.Arena.Small<inlineCapacity>` | Inline with spill to heap |

**Tree.Unbounded (dynamic children per node):**

| Variant | Storage Field | Buffer Type |
|---------|---------------|-------------|
| `Tree.Unbounded<Element>` (dynamic) | `_arena: Buffer<Node>.Arena` | Growable arena with CoW |
| `Tree.Unbounded.Bounded` | Error type only | Not yet implemented |
| `Tree.Unbounded.Small` | Error type only | Not yet implemented |

**Convenience:**
- `Tree.Binary<Element>` = `Tree.N<Element, 2>`

### Dependencies

```
Buffer_Arena_Primitives      (primary storage -- NEW since v1.0.0)
Stack_Primitives             (traversal stacks)
Queue_Primitives             (level-order traversal)
Array_Primitives             (re-exported)
Index_Primitives             (Tree.Index typealias)
Input_Primitives             (input conversion)
Bit_Primitives               (re-exported)
Collection_Primitives        (re-exported)
```

### Storage Mechanism

All implemented variants now use `Buffer<Node>.Arena` family types. The arena provides:
- Contiguous node storage with generation-token validation
- LIFO free-list recycling for O(1) slot reuse
- Parallel auxiliary arrays (tokens, free-list next pointers) managed by the buffer layer
- Automatic growth for dynamic variants
- CoW via `_arena.ensureUnique()` for `Copyable` elements

The `Node` struct stores `element: Element`, `childIndices: InlineArray<n, Int>` (for bounded-arity) or `childIndices: Swift.Array<Int>` (for unbounded), `childCount: Int`, and `parentIndex: Int`. Nodes reference each other by raw `Int` index with `-1` as the empty sentinel.

### Findings

| ID | Severity | File | Line(s) | Convention | Description |
|----|----------|------|---------|------------|-------------|
| T1 | **RESOLVED** | `Tree.N.swift` | 121 | -- | v1.0.0 identified `ManagedBuffer<Header, Node>` subclass. Now `_arena: Buffer<Node>.Arena`. Complete migration to Buffer.Arena stack. |
| T2 | **RESOLVED** | `Tree.N.swift` | all | -- | v1.0.0 identified ~4000 lines of manual memory management. Now zero `UnsafeMutablePointer.allocate/deallocate/initialize/deinitialize` calls. All memory management delegated to Buffer.Arena. |
| T3 | **RESOLVED** | `Tree.N.swift` | all | -- | v1.0.0 identified cached raw pointers (`_cachedPtr`, `_tokens`, `_nextFree`). These no longer exist. Arena manages all pointer access internally. |
| T4 | LOW | `Tree.N.swift` | 103, 107, 125 | -- | Raw `Int` used for `childIndices`, `childCount`, `parentIndex`, `_rootIndex`. This is arena-internal indexing where typed `Index<T>` would add overhead without safety benefit. The conversion to typed `Index<Node>` happens at the `_slot()` boundary (line 131-133). Principled. |
| T5 | LOW | `Tree.N.swift` | 131-133 | -- | `_slot(_ index: Int) -> Index<Node>` converts raw `Int` to typed index via `Index<Node>(Ordinal(UInt(index)))`. This is the single conversion point, keeping the typed/raw boundary clean. |
| T6 | LOW | `Tree.N.ChildSlot.swift` | all | [API-EXC-001] | Hoisted type `__TreeNChildSlot<n>` at module level with typealias `Tree.N.ChildSlot`. Documented exception per [API-EXC-001] due to Swift limitation with nested types inside generic types with value generic parameters. |
| T7 | LOW | `Tree.N.InsertPosition.swift` | all | [API-EXC-001] | Same as T6 for `__TreeNInsertPosition<n>`. |
| T8 | LOW | `Tree.N.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeNError` with typealias `Tree.N.Error`. |
| T9 | LOW | `Tree.N.Bounded.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeNBoundedError` with typealias `Tree.N.Bounded.Error`. |
| T10 | LOW | `Tree.N.Inline.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeNInlineError` with typealias `Tree.N.Inline.Error`. |
| T11 | LOW | `Tree.N.Small.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeNSmallError` with typealias `Tree.N.Small.Error`. |
| T12 | LOW | `Tree.Unbounded.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeUnboundedError`. |
| T13 | LOW | `Tree.Unbounded.InsertPosition.swift` | all | [API-EXC-001] | Hoisted `__TreeUnboundedInsertPosition`. |
| T14 | LOW | `Tree.Unbounded.Bounded.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeUnboundedBoundedError`. Error type exists but no corresponding implementation type. |
| T15 | LOW | `Tree.Unbounded.Small.Error.swift` | all | [API-EXC-001] | Hoisted `__TreeUnboundedSmallError`. Same as T14 -- error type without implementation. |
| T16 | MEDIUM | `Tree.N.Inline.swift`, `Tree.N.Small.swift` | varies | -- | Navigation/traversal methods are `mutating` on Inline and Small variants (required for arena pointer access on `~Copyable` inline/small arenas) but non-mutating on `Tree.N` and `Tree.N.Bounded`. This is a principled asymmetry but could surprise users who swap between variants. |
| T17 | LOW | multiple traversal files | varies | -- | Post-order traversal logic (leftmost/rightmost child detection, visited tracking) is duplicated identically across `Tree.N.swift` (removeSubtree + forEachPostOrder), `Tree.N.Bounded.swift`, `Tree.N.Inline.swift`, `Tree.N.Small.swift`, and `Tree.Unbounded.swift`. Six copies of essentially the same algorithm. Not a correctness issue but a maintenance burden. |
| T18 | PASS | all files | -- | [PRIM-FOUND-001] | Zero Foundation imports. |
| T19 | PASS | all files | -- | [API-ERR-001] | All throwing functions use typed throws: `throws(__TreeNError)`, `throws(__TreeNBoundedError)`, `throws(__TreeNInlineError)`, `throws(__TreeNSmallError)`, `throws(__TreeUnboundedError)`. |
| T20 | PASS | `exports.swift` | 11 | -- | `@_exported import Buffer_Arena_Primitives` confirms arena dependency is properly propagated to consumers. |

### ~Copyable Status

Clean separation. `Tree.N` and `Tree.Unbounded` are conditionally `Copyable where Element: Copyable` with explicit `extension Tree.N.Node: Copyable where Element: Copyable {}` and `extension Tree.N: Copyable where Element: Copyable {}` conformances. The `Inline` and `Small` variants are unconditionally `~Copyable` due to inline arena deinit requirements. All traversal closures use `(borrowing Element) -> Void` for ~Copyable element access.

---

## Graph (swift-graph-primitives)

### Current State

Graph provides an immutable sequential graph (`Graph.Sequential<Tag, Payload>`) built via a consumed `Builder` pattern. Graph is purely compositional -- it does not manage any contiguous element buffer itself.

| Type | Storage | Source |
|------|---------|--------|
| `Graph.Sequential` | `storage: Array<Payload>.Indexed<Tag>` | Array_Primitives |
| `Graph.Sequential.Builder` | `[Payload]` (Swift.Array) | Swift stdlib |
| `Graph.Traversal.First.Depth` | `Stack<Graph.Node<Tag>>` + `Array<Bit>.Vector` | Stack_Primitives, Bit_Primitives |
| `Graph.Traversal.First.Breadth` | `Queue<Graph.Node<Tag>>` + `Array<Bit>.Vector` | Queue_Primitives, Bit_Primitives |
| `Graph.Traversal.Topological` | `Stack` with two-phase pattern | Stack_Primitives |
| `Graph.Sequential.Path.Weighted` | `Heap<Entry>` + `Array<Bit>.Vector` + `[Int]` + `[Graph.Node<Tag>?]` | Heap_Primitives, Bit_Primitives |
| `Graph.Sequential.Analyze.SCC` | `Stack` (Tarjan's iterative) | Stack_Primitives |
| `Graph.Adjacency.List` | `[Graph.Node<Tag>]` | Swift stdlib |

### Dependencies

```
Tagged_Primitives          (re-exported)
Bit_Primitives               (Array<Bit>.Vector for visited tracking)
Stack_Primitives             (DFS traversal, topological sort, SCC)
Queue_Primitives             (BFS traversal)
Heap_Primitives              (priority queue in Dijkstra)
Index_Primitives             (Graph.Index, Graph.Node typealiases)
Input_Primitives             (input conversion)
Array_Primitives             (Array.Indexed for graph storage)
Collection_Primitives        (re-exported)
Set_Primitives               (set operations in analysis)
Dictionary_Primitives        (remapping, SCC analysis)
```

### Storage Mechanism

Graph does not manage contiguous storage directly. It composes primitives that do. Since those underlying primitives (Array, Stack, Queue, Heap) are all on the refactored buffer stack, Graph benefits transitively.

### Findings

| ID | Severity | File | Line(s) | Convention | Description |
|----|----------|------|---------|------------|-------------|
| G1 | **CRITICAL** | `Graph.Sequential.Path.Weighted.swift` | 9 | -- | `Entry` struct conforms to `__HeapOrdering` protocol. This protocol has **no Swift source definition** anywhere in the monorepo -- it exists only in documentation/research markdown files. This will cause a compile error when this file is built. The protocol should be replaced with `Comparison.Protocol` from `Comparison_Primitives` (which is what current Heap uses), or removed entirely since `Entry` already conforms to `Comparable`. |
| G2 | LOW | `Graph.Sequential.Path.Weighted.swift` | 65 | -- | `var heap = Heap<Entry>()` creates a heap without specifying order. Default is `.ascending` (min-heap), which is correct for Dijkstra. But `Entry` conforms to `Comparable`, not `Comparison.Protocol`. Need to verify `Heap` can accept `Comparable`-only types or if `Comparison.Protocol` conformance is required. |
| G3 | LOW | `Graph.Sequential.Path.Weighted.swift` | 67-68 | -- | Uses `[Int](repeating:count:)` and `[Graph.Node<Tag>?](repeating:count:)` with raw `Int` count via `Int(bitPattern: count)`. Principled -- these are stdlib arrays sized from graph node count. |
| G4 | LOW | `Graph.Sequential.Builder.swift` | all | -- | Builder uses `[Payload]` (Swift.Array) for accumulation, consumed on `build()`. Appropriate for a mutable accumulator pattern. No need to replace with Buffer.Linear. |
| G5 | LOW | `Graph.Sequential.Builder.swift` | all | -- | `Builder: ~Copyable` is unconditionally non-copyable (consumed on `build()`). This is correct -- prevents accidental double-build. |
| G6 | PASS | all files | -- | [PRIM-FOUND-001] | Zero Foundation imports. |
| G7 | PASS | all files | -- | [API-ERR-001] | Graph uses no throwing functions (operations return `nil` or empty results for invalid inputs). No typed-throws concern. |
| G8 | PASS | all files | -- | [API-NAME-001] | All types follow `Nest.Name` pattern: `Graph.Sequential`, `Graph.Adjacency.List`, `Graph.Traversal.First.Depth`, `Graph.Sequential.Path.Weighted`, etc. |
| G9 | LOW | all files | -- | -- | No `~Copyable` support for `Payload` type parameter. `Graph.Sequential` requires `Payload: Sendable`. This is appropriate for an immutable graph structure. |
| G10 | LOW | `Graph.Sequential.swift` | all | -- | `Graph.Node<Tag>` is a typealias to `Graph.Index<Tag>` which is a typealias to `Index_Primitives.Index<Tag>`. Proper typed index usage. |

### ~Copyable Status

Graph types do not support `~Copyable` payloads. `Graph.Sequential` requires `Payload: Sendable`. The `Builder` is `~Copyable` (consumed on build). This is appropriate for an immutable, sharable graph structure.

---

## Cross-Cutting Concerns

### 1. Buffer Migration Complete

All three packages are fully on the refactored buffer stack:

| Package | Buffer Family | Status |
|---------|--------------|--------|
| Heap | `Buffer.Linear` (Linear, Bounded, Inline, Small) | **Complete** |
| Tree | `Buffer.Arena` (Arena, Bounded, Inline, Small) | **Complete** (rewritten from ManagedBuffer) |
| Graph | N/A (compositional) | **N/A** -- benefits transitively |

The v1.0.0 finding that Tree was "entirely unmigrated" with "~4000 lines of manual memory management" has been fully resolved. The v1.0.0 finding that Heap had 4 legacy `_storage` references has been fully resolved.

### 2. No Foundation Imports

Zero Foundation imports across all three packages. Verified via grep.

### 3. Typed Throws

All throwing functions use typed throws per [API-ERR-001]:
- Heap: `throws(Heap.Error)`, `throws(Heap.Fixed.Error)`, `throws(Heap.Static.Error)`, `throws(Heap.Small.Error)`
- Tree: `throws(__TreeNError)`, `throws(__TreeNBoundedError)`, `throws(__TreeNInlineError)`, `throws(__TreeNSmallError)`, `throws(__TreeUnboundedError)`
- Graph: No throwing functions (returns nil/empty for invalid inputs)

### 4. Naming Compliance

All types follow `Nest.Name` pattern per [API-NAME-001]. No compound identifiers found.

### 5. Hoisted Types

Tree uses 10 hoisted `__`-prefixed types at module level, all documented per [API-EXC-001]:
- `__TreeNChildSlot<n>`, `__TreeNInsertPosition<n>`, `__TreeNError`, `__TreeNBoundedError`, `__TreeNInlineError`, `__TreeNSmallError`, `__TreeUnboundedError`, `__TreeUnboundedInsertPosition`, `__TreeUnboundedBoundedError`, `__TreeUnboundedSmallError`

Each has a corresponding typealias inside the parent type (e.g., `public typealias Error = __TreeNError`).

### 6. Raw Int Pattern

Both Heap and Tree use raw `Int` for internal index arithmetic:
- Heap: Array indices for heap bubbleUp/trickleDown (parent = `(i-1)/2`, children = `2*i+1`, `2*i+2`)
- Tree: Arena slot indices (`_rootIndex: Int`, `childIndices: InlineArray<n, Int>`, `parentIndex: Int`)

In both cases, the raw `Int` is converted to typed `Index<T>` at a single boundary function (`_slot(_ index: Int) -> Index<Node>` in Tree, `Heap.Navigate` methods in Heap). This pattern is principled -- it keeps the typed/raw boundary explicit and avoids wrapping/unwrapping overhead in tight inner loops.

---

## Recommendations

### Priority 1: Fix Graph `__HeapOrdering` (CRITICAL)

**File**: `/Users/coen/Developer/swift-primitives/swift-graph-primitives/Sources/Graph Primitives/Graph.Sequential.Path.Weighted.swift`, line 9

The `Entry` struct conforms to `__HeapOrdering`, a protocol that has no Swift source definition. This will prevent Graph from compiling when the weighted path module is exercised.

**Action**: Remove `__HeapOrdering` from the conformance list. `Entry` already conforms to `Comparable` and provides `isLessThan(_:_:)`. If `Heap` requires `Comparison.Protocol`, add that conformance instead. If `Heap` accepts `Comparable` types (via conditional conformance or protocol refinement), the existing `Comparable` conformance may suffice.

### Priority 2: Implement Unbounded.Bounded and Unbounded.Small

**Files**: Error types exist (`Tree.Unbounded.Bounded.Error`, `Tree.Unbounded.Small.Error`) but no implementation types. These should either be implemented using `Buffer<Node>.Arena.Bounded` and `Buffer<Node>.Arena.Small` respectively, or the error types should be removed if the variants are not planned.

### Priority 3: Consider Removing Empty Heap.Storage Files

**Files**: `Heap.Storage.swift`, `Heap.Storage.Inline.swift`

These are intentionally emptied stubs from the pre-refactor era. They serve as migration breadcrumbs but may confuse new contributors. Consider removing them.

### Priority 4: Implement MinMax Variant Operations

**Files**: `Heap.MinMax.Fixed`, `Heap.MinMax.Static`, `Heap.MinMax.Small`

These have correct storage declarations but no operations. The pattern from `Heap.Fixed`, `Heap.Static`, `Heap.Small` should be replicated for the MinMax algorithm.

### Priority 5: Evaluate Post-Order Traversal Deduplication

**Files**: Six copies of the post-order traversal algorithm across Tree variants.

Consider extracting the traversal logic into a shared internal function parameterized by the arena access pattern. This would reduce maintenance burden when the algorithm needs to change.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1.0.0 | 2026-01-XX | Initial "Stack Migration Assessment" |
| v2.0.0 | 2026-02-12 | Complete rewrite as "Post-Refactor Assessment". Tree fully migrated to Buffer.Arena. Heap legacy `_storage` references resolved. Identified critical `__HeapOrdering` compile blocker in Graph. |
