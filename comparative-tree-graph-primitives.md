# Comparative Analysis: Tree/Graph Primitives vs swift-io Patterns

<!--
---
version: 1.0.0
date: 2026-02-24
scope: swift-tree-primitives, swift-graph-primitives, swift-io
type: comparative-analysis
status: DECISION
---
-->

## Executive Summary

**Verdict: Minimal overlap. No replacement opportunities exist today.**

swift-tree-primitives provides general-purpose arena-based n-ary trees with traversal. swift-graph-primitives provides immutable directed graph construction and analysis (topological sort, SCC, reachability, shortest path). swift-io has neither hierarchical parent/child structures nor dependency-graph patterns in its runtime. The two potential contact points — deadline scheduling and sharded registries — are already well-served by their current primitives (Heap and Dictionary).

---

## 1. swift-tree-primitives Catalog

**Location**: `/Users/coen/Developer/swift-primitives/swift-tree-primitives/`
**Module**: `Tree Primitives` (single module)

### 1.1 Type Hierarchy

```
Tree                                    (namespace enum)
├── Tree.Position                       (cursor: index + token validation)
├── Tree.Index<Element>                 (typealias → Index_Primitives.Index<Element>)
├── Tree.Binary<Element>                (typealias → Tree.N<Element, 2>)
│
├── Tree.N<Element, let n: Int>         (bounded-arity, dynamic growth, arena-based)
│   ├── Tree.N.Node                     (element + childIndices + parentIndex)
│   ├── Tree.N.ChildSlot                (bounded child slot 0..<n)
│   ├── Tree.N.InsertPosition           (.root | .child(of:slot:))
│   ├── Tree.N.Error                    (invalidPosition, slotOccupied, cannotRemoveNonLeaf)
│   ├── Tree.N.Order                    (namespace for traversal sequences)
│   │   ├── .Pre / .Pre.Sequence / .Pre.Iterator
│   │   ├── .Post / .Post.Sequence / .Post.Iterator
│   │   ├── .Level / .Level.Sequence / .Level.Iterator
│   │   └── .In / .In.Sequence / .In.Iterator  (binary only, n == 2)
│   │
│   ├── Tree.N.Bounded                  (fixed-capacity variant)
│   │   ├── .Error                      (adds .overflow)
│   │   └── (same traversal Order types)
│   │
│   ├── Tree.N.Inline<let capacity>     (zero-allocation, unconditionally ~Copyable)
│   │   └── .Error                      (adds .overflow)
│   │
│   └── Tree.N.Small<let inlineCapacity>(inline + spill-to-heap)
│       └── .Error
│
└── Tree.Unbounded<Element>             (dynamic arity, dynamic children per node)
    ├── Tree.Unbounded.Node             (element + Array<Int> childIndices + parentIndex)
    ├── Tree.Unbounded.InsertPosition   (.root | .child(of:at:) | .appendChild(of:))
    ├── Tree.Unbounded.Error            (invalidPosition, rootOccupied, childIndexOutOfBounds, ...)
    ├── Tree.Unbounded.Bounded          (fixed node capacity)
    └── Tree.Unbounded.Small            (inline + spill)
```

### 1.2 Key Properties

| Property | Detail |
|----------|--------|
| Storage | Arena-based (`Buffer<Node>.Arena` variants) |
| Element constraint | Supports `~Copyable` elements |
| CoW | Yes, when `Element: Copyable` |
| Navigation | O(1) parent/child via arena indices |
| Insertion | O(1) amortized (dynamic), O(1) (bounded/inline) |
| Removal | Leaf only (O(1)), or subtree (post-order) |
| Traversals | Pre-order, post-order, level-order, in-order (binary) |
| Validation | Generation-token per position (stale detection) |
| Sendable | Conditional on `Element: Sendable` |

### 1.3 What tree-primitives does NOT provide

- **No self-balancing trees**: No B-trees, red-black trees, AVL trees, or splay trees
- **No sorted containers**: No sorted maps, sorted sets, or ordered dictionaries
- **No search operations**: No find-by-value, no ordered iteration by key
- **No key-value semantics**: Trees store elements, not key-value pairs

These are explicitly structural trees — they model parent/child relationships, not ordered search structures.

---

## 2. swift-graph-primitives Catalog

**Location**: `/Users/coen/Developer/swift-primitives/swift-graph-primitives/`
**Modules**: 17 modules (Core + 16 algorithm modules)

### 2.1 Type Hierarchy

```
Graph                                   (namespace enum)
├── Graph.Node<Tag>                     (typealias → Index<Tag>, phantom-tagged)
├── Graph.Index<Tag>                    (typealias → Index_Primitives.Index<Tag>)
│
├── Graph.Sequential<Tag, Payload>      (immutable, dense-array-backed)
│   └── Graph.Sequential.Builder        (~Copyable, allocate + build pattern)
│
├── Graph.Adjacency                     (namespace)
│   ├── Graph.Adjacency.List<Tag>       (canonical payload: [Graph.Node<Tag>])
│   └── Graph.Adjacency.Extract<P,T,A>  (closure-based adjacency extraction)
│
├── Graph.Default                       (namespace)
│   ├── Graph.Default.Value<Payload>    (hole values for builder)
│   └── Graph.Default.list()            (convenience for List payload)
│
├── Graph.Remappable                    (namespace)
│   └── Graph.Remappable.Remap<P,T,A>  (node-remapping for subgraphs)
│
├── Graph.Sequential.Traverse           (traversal algorithms)
│   └── .First                          (namespace)
│       ├── .breadth(from:)             → Graph.Traversal.First.Breadth (lazy BFS)
│       ├── .depth(from:)              → Graph.Traversal.First.Depth (lazy DFS)
│       └── .topological(from:)        → Graph.Traversal.Topological (eager, cycle-detecting)
│
├── Graph.Sequential.Analyze            (analysis algorithms)
│   ├── .reachable(from:)              → Set<Node>.Ordered (DFS reachability)
│   ├── .dead(from:)                   → Set<Node>.Ordered (unreachable nodes)
│   ├── .scc(from:)                    → [[Node]] (Tarjan's SCC, iterative)
│   ├── .hasCycles(from:)             → Bool (via topological sort)
│   └── .transitiveClosure()           → Graph.Sequential (all-pairs reachability)
│
├── Graph.Sequential.Path              (path algorithms)
│   ├── .exists(from:to:)             → Bool (BFS path existence)
│   ├── .shortest(from:to:)           → [Node]? (unweighted BFS)
│   └── .weighted(from:to:weight:)    → ([Node], Int)? (Dijkstra with Heap)
│
├── Graph.Sequential.Reverse           (reverse algorithms)
│   ├── .reversed()                    → Graph.Sequential (all edges reversed)
│   └── .reachable(to:)               → Set<Node>.Ordered (backward reachability)
│
└── Graph.Sequential.Transform         (transformation algorithms)
    ├── .payloads(_:)                  → Graph.Sequential (map payloads)
    └── .subgraph(inducedBy:)          → Graph.Sequential? (induced subgraph)
```

### 2.2 Key Properties

| Property | Detail |
|----------|--------|
| Mutability | Immutable after `Builder.build()` |
| Storage | Dense array (`Array<Payload>.Indexed<Tag>`) |
| Node identity | Phantom-tagged `Index<Tag>` (cross-graph safety) |
| Adjacency | Closure-based extraction (no protocol requirement) |
| Algorithm primitives | Stack, Queue, Bit.Vector, Heap (from other primitives) |
| Complexity | All algorithms O(V+E) except transitive closure O(V*(V+E)) and weighted path O((V+E)log V) |

### 2.3 Also found: swift-abstract-syntax-tree-primitives

**Location**: `/Users/coen/Developer/swift-primitives/swift-abstract-syntax-tree-primitives/`

This package exists but contains only a single empty/placeholder file. No public types are defined. It appears to be reserved for future use.

---

## 3. swift-io Pattern Analysis

### 3.1 Hierarchical (Parent/Child) Patterns

**Result: None found.**

swift-io has no parent/child relationships in its data structures. The architecture is flat:

- `IO.Handle.Registry` stores handles in a flat `[IO.Handle.ID: Entry]` dictionary
- `IO.Executor.Shards` uses a flat array of independent registries with round-robin routing
- `IO.Event.Selector` uses flat dictionaries for registrations, waiters, and permits
- `IO.Blocking.Threads.Acceptance.Queue` uses slab + order queue + dictionary (all flat)

There is no recursive ownership, no containment hierarchy, and no parent-child navigation anywhere in the runtime.

### 3.2 Dependency Ordering Patterns

**Result: None found.**

swift-io has no dependency graph construction or topological ordering:

- Teardown is explicitly unordered: "No ordering guarantee between resources" (`IO.Executor.Teardown`)
- Shutdown is sequential per-actor but there is no cross-actor dependency ordering
- Shard indices are assigned via atomic counter, not dependency analysis
- Lane composition (sharding) is flat fan-out, not a DAG

### 3.3 Tree-Like Lookup Patterns

**Result: None found.**

All lookup structures use hash-based primitives:

| swift-io Structure | Backing Primitive | Access Pattern |
|-------------------|-------------------|----------------|
| `registrations` | `[ID: Registration]` (Swift.Dictionary) | O(1) hash lookup |
| `waiters` | `[Permit.Key: Waiter]` (Swift.Dictionary) | O(1) hash lookup |
| `permits` | `[Permit.Key: Flags]` (Swift.Dictionary) | O(1) hash lookup |
| `handles` | `[Handle.ID: Entry]` (Swift.Dictionary) | O(1) hash lookup |
| `deadlineGeneration` | `[Permit.Key: UInt64]` (Swift.Dictionary) | O(1) hash lookup |
| Acceptance Queue index | `Dictionary.Ordered.Bounded` | O(1) hash lookup |

None of these require ordered iteration, range queries, or predecessor/successor lookups that would benefit from balanced tree backing.

### 3.4 Deadline Scheduling Analysis

**Two sites use min-heaps for deadline scheduling:**

1. **`IO.Event.Selector`** (line 105):
   ```swift
   private var deadlineHeap: Heap<DeadlineScheduling.Entry> = .init()
   ```
   Operations: `push`, `peek`, `take` (pop min). Generation-based stale entry invalidation.

2. **`IO.Blocking.Threads.Acceptance.Queue`** (line 68):
   ```swift
   private var deadlineHeap: Heap<Deadline.Entry>.Fixed
   ```
   Operations: `push`, `peek`, `take` (pop min). Lazy deletion of cancelled entries.

**Could a balanced tree replace these heaps?**

No. The access pattern is exclusively:
- Insert (push)
- Peek-min (peek)
- Extract-min (take)

This is exactly the priority queue pattern that heaps are designed for. A balanced BST would provide O(log n) for all three operations (same as heap), but with:
- Higher constant factors (pointer chasing vs array indexing)
- Worse cache locality
- More memory overhead per node

The one operation where a balanced tree would win — delete-by-key — is not needed. Both sites use generation-based lazy deletion instead, which is O(1) at mark time and amortized over extract-min.

---

## 4. Replacement Opportunity Assessment

### 4.1 Tree Primitives → swift-io

| Opportunity | Assessment |
|-------------|------------|
| Replace dictionary lookups with tree-based ordered map | **No** — swift-io never needs ordered iteration or range queries |
| Model handle ownership hierarchy | **No** — handles are flat, independently owned |
| Model channel parent/child relationships | **No** — channels are independent entities |
| Replace heap with balanced BST for deadlines | **No** — heap is optimal for this access pattern |
| Use tree for file system hierarchy (future) | **Possible but out of scope** — would be in a file system layer, not swift-io |

### 4.2 Graph Primitives → swift-io

| Opportunity | Assessment |
|-------------|------------|
| Model shard topology as a graph | **No** — shards are independent, no edges between them |
| Use topological sort for shutdown ordering | **No** — teardown is explicitly unordered by design |
| Use reachability analysis for resource cleanup | **No** — resources have no inter-dependencies |
| Use SCC detection for deadlock detection | **Theoretically interesting but impractical** — the concurrency primitives (waiters, continuations) don't form a graph structure that could be analyzed at runtime |
| Model selector registration dependencies | **No** — registrations are independent |

---

## 5. Honest Assessment

The overlap between these primitives packages and swift-io is **zero in practice**. This is not a deficiency — it reflects a fundamental architectural difference:

1. **swift-io is a flat, concurrent runtime**. Its data structures are optimized for O(1) hash-based lookup, atomic state transitions, and lock-free coordination. It has no hierarchical data and no dependency ordering requirements.

2. **Tree primitives model structural hierarchies**. They are designed for domains where parent/child relationships are intrinsic: file systems, DOM trees, ASTs, organizational charts. swift-io has none of these.

3. **Graph primitives model static dependency analysis**. They operate on immutable graphs built ahead of time. swift-io's relationships are dynamic (handles register/deregister continuously) and would require a fundamentally different graph representation (mutable, concurrent) to model.

The one area where these packages *could* intersect in the future is at **Layer 3 (Foundations) or Layer 4 (Components)**:

- A **file system walker** might use `Tree.Unbounded` to represent directory hierarchies
- A **build system** might use `Graph.Sequential` for dependency resolution
- A **service mesh** might use graph analysis for routing topology

But these would be new packages that depend on *both* swift-io and tree/graph primitives — not replacements within swift-io itself.

---

## 6. Structural Observations

### 6.1 Tree Primitives Quality

The implementation is thorough:
- Four storage variants (dynamic, bounded, inline, small) for both N-ary and Unbounded
- Full `~Copyable` support with explicit ownership throughout
- Arena-based storage with generation-token validation
- Iterative traversals (no stack overflow on deep trees)
- CoW semantics for Copyable elements

Notable gap: No self-balancing search trees. This is likely intentional — search trees with ordering invariants would be a separate package (sorted containers).

### 6.2 Graph Primitives Quality

Clean algorithm library:
- 17 focused modules, each providing one algorithm family
- Closure-based adjacency extraction (no protocol taxation on payloads)
- Phantom-typed nodes prevent cross-graph confusion
- Iterative implementations throughout (no recursion)
- Uses existing primitives (Stack, Queue, Bit.Vector, Heap) rather than reimplementing

Notable design: Graphs are immutable after construction. This is appropriate for analysis but means they cannot model dynamically-evolving topologies.

---

## 7. Conclusion

There are no replacement opportunities for tree or graph primitives in swift-io. The domains are orthogonal. swift-io's flat, concurrent, hash-based architecture has no structural need for hierarchical navigation or static graph analysis. The existing heap primitives are the correct choice for deadline scheduling.
