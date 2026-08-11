# Graph Discipline Boundary Analysis

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

`graph-primitives` sits at the top of this chain, wrapping `Array.Indexed<Tag>` (and its underlying buffer/storage) to present a consumer-facing graph abstraction. The question: does `graph-primitives` contain ONLY graph-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-graph-primitives).

## Question

What semantics belong SOLELY to the graph abstraction layer, and does `graph-primitives` currently contain anything that properly belongs to the buffer, slab, or array layer?

---

## Prior Art Survey

### Source 1: Formal ADT Definition (Liskov & Guttag, classical CS)

The graph abstract data type is formally defined as a pair G = (V, E) where V is a finite set of vertices and E is a set of edges (pairs of vertices). The canonical operations:

```
Operations: vertices(G), edges(G), adjacent(G,u,v), neighbors(G,v),
            addVertex(G,v), addEdge(G,u,v), removeVertex(G,v), removeEdge(G,u,v)

Axioms:
  adjacent(addEdge(G,u,v), u, v) = true                                       (edge creation)
  adjacent(addEdge(G,u,v), x, y) = adjacent(G,x,y)  where (x,y) != (u,v)     (non-interference)
  neighbors(addEdge(G,u,v), u) = neighbors(G,u) U {v}                         (neighborhood growth)
  |vertices(addVertex(G,v))| = |vertices(G)| + 1   where v not in vertices(G)
```

The ADT mentions NO implementation concerns: no arrays, no pointers, no contiguous memory, no slab allocation. The graph is purely the **vertex-edge-adjacency contract with topological laws**.

Key distinction from Array ADT: the graph ADT has no notion of *position* or *index*. Vertices are identities, not positions. The mapping from vertex identity to storage location is a representation concern, not a graph concern.

### Source 2: Mokhov's Algebraic Graphs (Haskell, 2017)

Mokhov defines graphs purely algebraically with four constructors and a minimal axiom set:

```haskell
data Graph a = Empty | Vertex a | Overlay (Graph a) (Graph a) | Connect (Graph a) (Graph a)
```

**Operations**:
- `Empty` (epsilon): the empty graph
- `Vertex v`: a single isolated vertex
- `Overlay (+)`: union of vertices and edges -- `(V1, E1) + (V2, E2) = (V1 U V2, E1 U E2)`
- `Connect (->)`: creates all cross-edges -- `(V1, E1) -> (V2, E2) = (V1 U V2, E1 U E2 U V1 x V2)`

**Axioms**:
1. Overlay is commutative and associative, with Empty as identity
2. Overlay is idempotent: `x + x = x`
3. Connect is associative, with Empty as identity
4. Connect distributes over Overlay: `x -> (y + z) = x -> y + x -> z`
5. **Decomposition**: `x -> y -> z = x -> y + x -> z + y -> z`

**Key insight**: The algebraic formulation contains ZERO storage concerns. Graph construction is compositional (overlay, connect), not positional (insert at index). The `AdjacencyMap` representation is a separate module -- a performance-oriented implementation of the same algebra.

### Source 3: Rust petgraph

Petgraph provides five graph implementations, each with different storage trade-offs:

| Type | Storage | Trade-off |
|------|---------|-----------|
| `Graph` | Adjacency list (Vec of nodes/edges) | General purpose |
| `StableGraph` | Stable indices across removals | Index stability |
| `GraphMap` | HashMap-backed | Key-based access |
| `MatrixGraph` | Adjacency matrix | Dense graphs |
| `CSR` | Compressed sparse row | Sparse, read-only |

**Separation pattern**: Petgraph separates graph *topology* from graph *storage* through traits:
- **Topology traits**: `IntoEdges`, `IntoNeighbors`, `IntoNodeIdentifiers` -- what edges exist, what is adjacent
- **Visit traits**: `Visitable` -- traversal state (visited set)
- **Data traits**: `NodeWeight`, `EdgeWeight` -- associated data

Algorithms (`algo` module) are generic over these traits: BFS, DFS, topological sort, Dijkstra, Tarjan SCC, transitive closure. They do not know or care about the underlying storage format.

**Key insight**: The node index type (`NodeIndex<Ix>`) is a *graph-level* concept, not a storage concept. It provides type safety between graphs (different `Ix` types prevent cross-graph confusion). This directly parallels `Graph.Node<Tag>` in graph-primitives.

### Source 4: C++ Boost Graph Library (BGL)

BGL separates concerns through *concepts* (C++ named requirements):

| Concept | What it provides | Layer |
|---------|-----------------|-------|
| `VertexListGraph` | Iterate all vertices | Graph topology |
| `EdgeListGraph` | Iterate all edges | Graph topology |
| `IncidenceGraph` | Out-edges of a vertex | Graph topology |
| `AdjacencyGraph` | Adjacent vertices | Graph topology |
| `BidirectionalGraph` | In-edges + out-edges | Graph topology |
| `MutableGraph` | Add/remove vertices/edges | Graph mutation |
| `PropertyGraph` | Attached vertex/edge data | Graph payload |

Storage types (`adjacency_list`, `adjacency_matrix`) *model* these concepts but are not the concepts themselves. The library enforces that algorithms depend on concepts, not concrete storage.

**Key insight**: BGL's `graph_traits<G>` is the boundary type. It extracts `vertex_descriptor`, `edge_descriptor`, `directed_category`, `edge_parallel_category` from any graph type. These are purely topological descriptors -- they say nothing about memory layout.

### Source 5: Haskell Data.Graph (GHC stdlib)

Haskell's `Data.Graph` represents graphs as `Array Vertex [Vertex]` -- an adjacency list stored in an immutable array. Key functions:

- `vertices :: Graph -> [Vertex]`
- `edges :: Graph -> [Edge]`
- `dfs :: Graph -> [Vertex] -> Forest Vertex` -- depth-first forest
- `bfs :: Graph -> [Vertex] -> [Vertex]` -- breadth-first order
- `topSort :: Graph -> [Vertex]` -- topological ordering
- `scc :: Graph -> Forest Vertex` -- strongly connected components
- `reachable :: Graph -> Vertex -> [Vertex]` -- reachability
- `path :: Graph -> Vertex -> Vertex -> Bool` -- path existence
- `transposeG :: Graph -> Graph` -- edge reversal

**Key insight**: The `Array Vertex [Vertex]` representation is visible in the type, but all graph algorithms are defined in terms of `Vertex` (which is `Int`) and adjacency -- topological concepts, not array concepts. The array is the container; the graph is the structure.

### Source 6: Graph vs Slab (arena/storage distinction)

A slab (or arena) allocator provides:
- Dense allocation of identically-typed objects
- O(1) allocation by index
- Stable indices (no moving)
- Bulk deallocation

A graph provides:
- **Topological structure** over objects allocated somewhere
- **Edge semantics**: directed, undirected, weighted, labeled
- **Connectivity queries**: reachability, path, cycle detection
- **Structural algorithms**: traversal, ordering, decomposition (SCC), closure

The slab asks: "where does this object live?" The graph asks: "how are these objects related?"

In graph-primitives, `Array.Indexed<Tag>` serves the role of a slab -- it provides dense storage with typed indexing. `Graph.Sequential` adds the topological interpretation of adjacency over that storage.

---

## Analysis

### What is SOLELY Graph Discipline

#### A. Topological Identity and Vertex Semantics

The graph's primary contribution: defining what a "node" means as a topological entity, not a storage position.

| Concept | What it provides | Why not in Buffer/Array/Slab |
|---------|-----------------|------------------------------|
| `Graph.Node<Tag>` (typealias to `Index<Tag>`) | Phantom-tagged vertex identity | Buffer/Array tracks *positions*; the graph interprets positions as *vertex identities* in a topological structure |
| `Graph.Index<Tag>` (typealias to `Index<Tag>`) | Type-safe cross-graph prevention | Prevents mixing vertices from different graphs at compile time -- a graph-discipline invariant |
| `Graph.Sequential.nodes` | Enumerate all vertices | Exposes the *vertex set* V -- a topological concept |
| `Graph.Sequential.count` | \|V\| -- number of vertices | Topological cardinality |
| `Graph.Sequential.isEmpty` | Whether V = {} | Empty graph predicate |

#### B. Edge/Adjacency Semantics

| Concept | What it provides | Why not in Buffer/Array/Slab |
|---------|-----------------|------------------------------|
| `Graph.Adjacency.List<Tag>` | Edge representation (directed adjacency lists) | Defines E -- the edge set. Buffer has no concept of "this element points to that element" |
| `Graph.Adjacency.Extract<Payload, Tag, Adjacent>` | Generic edge extraction from payload | Protocol-free adjacency abstraction -- the graph's analog of BGL's `IncidenceGraph` concept |
| `Graph.Remappable.Remap<Payload, Tag, Adjacent>` | Node reference remapping under structural transforms | Preserves edge semantics under vertex renaming -- a purely topological operation |
| `Graph.Default.Value<Payload>` | Default/hole payload for two-phase construction | Supports forward-reference patterns (allocate node, fill edges later) -- a graph construction pattern |

#### C. Traversal Algorithms

| Algorithm | What it provides | Why solely graph |
|-----------|-----------------|------------------|
| `Graph.Traversal.First.Depth` | DFS with visited tracking | Graph traversal follows *edges*, not array indices. The stack is an implementation detail; the edge-following is the semantic |
| `Graph.Traversal.First.Breadth` | BFS with visited tracking | Same -- the queue follows *adjacency*, not contiguous memory |
| `Graph.Traversal.Topological` | Topological ordering with cycle detection | Topological sort is defined ONLY for directed graphs. It has no meaning for arrays, buffers, or slabs |
| `Graph.Sequential.Traverse` accessor | Fluent `.traverse.first.depth(from:)` API | Namespace for graph-specific operations |
| `Graph.Sequential.Traverse.First` accessor | `.traverse.first(using:).depth(from:)` | First-visit semantics are graph concepts (each vertex visited at most once) |

#### D. Structural Analysis

| Analysis | What it provides | Why solely graph |
|----------|-----------------|------------------|
| `analyze.reachable(from:)` | Forward reachability set | "Can I reach vertex v from vertex u?" is a graph connectivity question |
| `analyze.dead(from:)` | Unreachable vertices | Complement of reachability -- dead code analysis pattern |
| `analyze.hasCycles(from:)` / `hasCycles()` | Cycle detection | Cycles exist in *graphs*, not in arrays or buffers |
| `analyze.scc(from:)` / `scc()` | Strongly connected components (Tarjan) | SCC decomposition is a fundamental graph property -- partitions V by mutual reachability |
| `analyze.transitiveClosure()` | Transitive closure graph | "If u reaches v and v reaches w, then u reaches w" -- purely topological |

#### E. Path-Finding

| Operation | What it provides | Why solely graph |
|-----------|-----------------|------------------|
| `path.exists(from:to:)` | Path existence (BFS) | "Is there a walk from u to v?" -- topological |
| `path.shortest(from:to:)` | Shortest path by hop count (BFS) | Unweighted shortest path -- graph distance metric |
| `path.weighted(from:to:weight:)` | Shortest weighted path (Dijkstra) | Weighted shortest path -- graph + edge weight semantics |

#### F. Graph Transformations

| Transform | What it provides | Why solely graph |
|-----------|-----------------|------------------|
| `reverse.reversed()` | Edge reversal (transpose graph) | Reversing all edges A->B to B->A is a purely topological operation |
| `reverse.reachable(to:)` | Backward reachability | "What can reach me?" -- requires reverse graph, a graph concept |
| `transform.payloads(_:)` | Map over payloads (functor) | Structure-preserving transformation -- the graph is the functor, not the array |
| `transform.subgraph(inducedBy:using:)` | Induced subgraph extraction | "Keep only these vertices and edges between them" -- topological subsetting with vertex remapping |

#### G. Construction

| Feature | What it provides | Why solely graph |
|---------|-----------------|------------------|
| `Graph.Sequential.Builder` (~Copyable) | Mutable graph construction phase | Two-phase pattern: allocate nodes (possibly with holes for forward references), then freeze to immutable graph |
| `Builder.allocate(_:)` | Node allocation returning `Node<Tag>` | Returns a *vertex identity*, not a buffer position -- even though they coincide |
| `Builder.allocateHole(using:)` | Forward-reference node allocation | Graph-specific: allocate vertex now, fill edges later (needed for cyclic graphs) |
| `Builder.fill(_:with:)` | Fill a hole with actual payload | Completes the forward reference -- graph construction semantics |
| `Builder.build()` (consuming) | Freeze to immutable `Sequential` | Linear ownership: builder consumed, immutable graph produced |
| `Builder[node]` subscript | Read/modify payload during construction | Allows edge mutation before freeze -- graph construction pattern |

### What Array/Buffer Owns (Graph Merely Delegates)

| Concern | Owned by Array/Buffer/Storage |
|---------|-------------------------------|
| Memory allocation/deallocation | `Array` -> `Buffer.Linear` -> `Storage.Heap` |
| Contiguous memory layout | `Array` provides dense storage |
| Element lifecycle (init/deinit) | `Buffer.Linear` manages element lifecycle |
| Growth policy | `Array.Dynamic` growth -- not applicable (Graph.Sequential is immutable) |
| CoW mechanism | `Array` provides CoW -- not applicable (Graph.Sequential is immutable, Builder is ~Copyable) |
| Index arithmetic | `Index<Tag>` provides `position`, `retag`, comparisons |
| Typed indexed subscript | `Array.Indexed<Tag>` provides `subscript(Index<Tag>)` |
| Bit vector tracking | `Array<Bit>.Vector` provides visited/state tracking |
| Stack/Queue data structures | `Stack`, `Queue`, `Heap` -- used as algorithm working state |

---

## Audit: Current graph-primitives

### Audit Methodology

For each file in `graph-primitives/Sources/Graph Primitives/`, classify every public API member as:
- **GRAPH**: Solely graph discipline (topological semantics, vertex/edge contract, traversal, analysis)
- **DELEGATE**: Pure delegation to underlying storage (thin wrapper calling storage operations)
- **CONTESTED**: Could belong to either layer
- **LEAK**: Storage/buffer concern that has leaked into the graph layer

### Findings

#### Pure Graph Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `Graph` namespace enum | Architecture | `Graph.swift` |
| `Graph.Traversal` namespace | Architecture | `Graph.Traversal.swift` |
| `Graph.Traversal.First` namespace | Architecture | `Graph.Traversal.First.swift` |
| `Graph.Adjacency` namespace | Architecture | `Graph.Adjacency.swift` |
| `Graph.Remappable` namespace | Architecture | `Graph.Remappable.swift` |
| `Graph.Default` namespace | Architecture | `Graph.Default.swift` |
| `Graph.Node<Tag>` typealias | Vertex identity | `Graph.Node.swift` |
| `Graph.Index<Tag>` typealias | Vertex index | `Graph.Index.swift` |
| `Graph.Adjacency.List<Tag>` | Edge representation | `Graph.Adjacency.List.swift` |
| `Graph.Adjacency.Extract<Payload, Tag, Adjacent>` | Adjacency extraction | `Graph.Adjacency.Extract.swift` |
| `Graph.Adjacency.Extract.list` (static) | Canonical extract for List | `Graph.Adjacency.List.swift` |
| `Graph.Remappable.Remap<Payload, Tag, Adjacent>` | Node remapping | `Graph.Remappable.Remap.swift` |
| `Graph.Remappable.Remap.list` (static) | Canonical remap for List | `Graph.Remappable.Remap.swift` |
| `Graph.Remappable.Remap.extract` (computed) | Convert Remap to Extract | `Graph.Remappable.Remap.swift` |
| `Graph.Default.Value<Payload>` | Default/hole value | `Graph.Default.Value.swift` |
| `Graph.Default.list()` (static) | Default for List payload | `Graph.Default.list.swift` |
| `Graph.Sequential<Tag, Payload>` | Immutable graph type | `Graph.Sequential.swift` |
| `Graph.Sequential.count` | Vertex count \|V\| | `Graph.Sequential.swift` |
| `Graph.Sequential.isEmpty` | Empty graph test | `Graph.Sequential.swift` |
| `Graph.Sequential.nodes` | Vertex set enumeration | `Graph.Sequential.swift` |
| `Graph.Sequential[node]` subscript | Payload access by vertex | `Graph.Sequential.swift` |
| `Graph.Sequential.Builder` (~Copyable) | Mutable construction | `Graph.Sequential.Builder.swift` |
| `Builder.init()` | Empty builder | `Graph.Sequential.Builder.swift` |
| `Builder.init(capacity:)` | Pre-sized builder | `Graph.Sequential.Builder.swift` |
| `Builder.count` | Allocated vertex count | `Graph.Sequential.Builder.swift` |
| `Builder.allocate(_:)` | Node allocation | `Graph.Sequential.Builder.swift` |
| `Builder[node]` subscript (get/set) | Payload mutation during build | `Graph.Sequential.Builder.swift` |
| `Builder.build()` (consuming) | Freeze to immutable | `Graph.Sequential.Builder.swift` |
| `Builder.allocateHole(using:)` | Forward-reference allocation | `Graph.Sequential.Builder.swift` |
| `Builder.allocateHole()` (List convenience) | List-specific hole | `Graph.Sequential.Builder.swift` |
| `Builder.fill(_:with:)` | Fill forward reference | `Graph.Sequential.Builder.swift` |
| `Graph.Sequential.traverse` accessor | Traversal namespace | `Graph.Sequential.Traverse.swift` |
| `Graph.Sequential.Traverse` struct | Traversal accessor type | `Graph.Sequential.Traverse.swift` |
| `traverse.first(using:)` | First-visit accessor | `Graph.Sequential.Traverse.First.swift` |
| `traverse.first` (List convenience) | List-specific first-visit | `Graph.Sequential.Traverse.First.swift` |
| `Traverse.First.depth(from:)` (roots) | DFS from multiple roots | `Graph.Sequential.Traverse.First.swift` |
| `Traverse.First.depth(from:)` (single) | DFS from single root | `Graph.Sequential.Traverse.First.swift` |
| `Traverse.First.breadth(from:)` (roots) | BFS from multiple roots | `Graph.Sequential.Traverse.First.swift` |
| `Traverse.First.breadth(from:)` (single) | BFS from single root | `Graph.Sequential.Traverse.First.swift` |
| `Graph.Traversal.First.Depth` | DFS iterator (Sequence + IteratorProtocol) | `Graph.Traversal.First.Depth.swift` |
| `Graph.Traversal.First.Breadth` | BFS iterator (Sequence + IteratorProtocol) | `Graph.Traversal.First.Breadth.swift` |
| `traverse.topological(from:using:)` (roots) | Topological order from roots | `Graph.Sequential.Traverse.Topological.swift` |
| `traverse.topological(from:using:)` (single) | Topological order from root | `Graph.Sequential.Traverse.Topological.swift` |
| `traverse.topological(using:)` | Topological order (all nodes) | `Graph.Sequential.Traverse.Topological.swift` |
| `traverse.topological(from:)` (List, roots) | List convenience | `Graph.Sequential.Traverse.Topological.swift` |
| `traverse.topological(from:)` (List, single) | List convenience | `Graph.Sequential.Traverse.Topological.swift` |
| `traverse.topological()` (List) | List convenience | `Graph.Sequential.Traverse.Topological.swift` |
| `Graph.Traversal.Topological` | Topological ordering type | `Graph.Traversal.Topological.swift` |
| `Topological.hasCycles` | Cycle detection result | `Graph.Traversal.Topological.swift` |
| `Topological.makeIterator()` | Iterate topological order | `Graph.Traversal.Topological.swift` |
| `graph.analyze(using:)` | Analysis accessor | `Graph.Sequential.Analyze.swift` |
| `graph.analyze` (List convenience) | List analysis accessor | `Graph.Sequential.Analyze.swift` |
| `Graph.Sequential.Analyze` struct | Analysis accessor type | `Graph.Sequential.Analyze.swift` |
| `analyze.reachable(from:)` (roots) | Forward reachability | `Graph.Sequential.Analyze.Reachable.swift` |
| `analyze.reachable(from:)` (single) | Single-root reachability | `Graph.Sequential.Analyze.Reachable.swift` |
| `analyze.dead(from:)` | Unreachable nodes | `Graph.Sequential.Analyze.Dead.swift` |
| `analyze.hasCycles(from:)` (roots) | Cycle detection | `Graph.Sequential.Analyze.Cycles.swift` |
| `analyze.hasCycles(from:)` (single) | Single-root cycle detection | `Graph.Sequential.Analyze.Cycles.swift` |
| `analyze.hasCycles()` | Full-graph cycle detection | `Graph.Sequential.Analyze.Cycles.swift` |
| `analyze.scc(from:)` (roots) | Tarjan SCC | `Graph.Sequential.Analyze.SCC.swift` |
| `analyze.scc(from:)` (single) | Single-root SCC | `Graph.Sequential.Analyze.SCC.swift` |
| `analyze.scc()` | Full-graph SCC | `Graph.Sequential.Analyze.SCC.swift` |
| `analyze.transitiveClosure()` | Transitive closure | `Graph.Sequential.Analyze.TransitiveClosure.swift` |
| `graph.path(using:)` | Path accessor | `Graph.Sequential.Path.swift` |
| `graph.path` (List convenience) | List path accessor | `Graph.Sequential.Path.swift` |
| `Graph.Sequential.Path` struct | Path accessor type | `Graph.Sequential.Path.swift` |
| `path.exists(from:to:)` | Path existence (BFS) | `Graph.Sequential.Path.Exists.swift` |
| `path.shortest(from:to:)` | Shortest unweighted path | `Graph.Sequential.Path.Shortest.swift` |
| `path.weighted(from:to:weight:)` | Dijkstra shortest path | `Graph.Sequential.Path.Weighted.swift` |
| `Graph.Sequential.Path.Entry` | Priority queue entry for Dijkstra | `Graph.Sequential.Path.Weighted.swift` |
| `graph.reverse(using:)` | Reverse accessor | `Graph.Sequential.Reverse.swift` |
| `graph.reverse` (List convenience) | List reverse accessor | `Graph.Sequential.Reverse.swift` |
| `Graph.Sequential.Reverse` struct | Reverse accessor type | `Graph.Sequential.Reverse.swift` |
| `reverse.reversed()` | Edge reversal (transpose) | `Graph.Sequential.Reverse.Graph.swift` |
| `reverse.reachable(to:)` | Backward reachability | `Graph.Sequential.Reverse.Reachable.swift` |
| `graph.transform` accessor | Transform accessor | `Graph.Sequential.Transform.swift` |
| `Graph.Sequential.Transform` struct | Transform accessor type | `Graph.Sequential.Transform.swift` |
| `transform.payloads(_:)` | Functor map over payloads | `Graph.Sequential.Transform.Payloads.swift` |
| `transform.subgraph(inducedBy:using:)` | Generic induced subgraph | `Graph.Sequential.Transform.Subgraph.swift` |
| `transform.subgraph(inducedBy:)` (List) | List-specific induced subgraph | `Graph.Sequential.Transform.Subgraph.swift` |
| `Graph.Sequential` (namespace for `Traverse`, `Analyze`, `Path`, `Reverse`, `Transform`) | Fluent accessor pattern | Multiple files |

#### Pure Delegation (correctly placed -- thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `storage.count` | `Array.Indexed<Tag>.count` | **OK** -- Graph surfaces vertex count; array stores it |
| `var isEmpty` -> `storage.isEmpty` | `Array.Indexed<Tag>.isEmpty` | **OK** |
| `subscript(node:)` -> `storage[node]` | `Array.Indexed<Tag>[node]` | **OK** -- Graph interprets this as "payload for vertex", not "element at index" |
| `Builder.storage` (internal `[Payload]`) | Swift stdlib `Array` | **OK** -- Builder is ~Copyable, consumes into immutable graph |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `Graph.Node<Tag>` = `Index<Tag>` (which = `Index_Primitives.Index<Tag>`) | Node identity is a typealias to the same type used for array indexing. There is no separate vertex identity type. | **ACCEPTABLE** -- In a sequentially-allocated graph, vertex identity IS position. This is the defining choice of `Graph.Sequential`. Petgraph makes the same choice (`NodeIndex<Ix>`). The phantom `Tag` provides the graph-discipline safety (cross-graph prevention). A fully abstract graph ADT would use opaque identities, but sequential allocation makes position-as-identity a legitimate simplification. |
| `Graph.Sequential.nodes` accesses `storage._storage.count` | Reaches through `Array.Indexed` to the underlying stdlib array's count to generate node indices via `lazy.map`. | **MINOR LEAK** -- The `.nodes` property constructs vertex identities by mapping over `0..<storage._storage.count`. The `_storage` access reaches into `Array.Indexed`'s internal storage. Ideally this would use a public API on `Array.Indexed` such as `indices` or `count`, but `count` is already typed as `Node<Tag>.Count` which cannot directly be used in `0..<`. The leak is structural, not semantic -- the generated sequence is correct graph semantics (all vertices in allocation order). |
| `Builder` uses stdlib `[Payload]` directly, not `Array.Indexed` | Builder stores payloads in a raw `[Payload]` and only wraps into `Array.Indexed<Tag>` on `build()`. | **ACCEPTABLE** -- Builder is a transient construction helper, not a persistent data structure. Using stdlib Array during construction and converting on freeze is pragmatic. The type boundary is enforced at `build()`. |
| Traversal/analysis algorithms access `graph.storage[node]` directly | DFS, BFS, Topological, SCC, Reachable, Dead, TransitiveClosure, Path, Reverse all access `graph.storage[node]` (the `Array.Indexed<Tag>` subscript). | **OK** -- This is correct delegation. The algorithms use typed indexed access to read payloads, then apply graph-specific logic (edge following, visited tracking, cycle detection). The storage access is read-only. |
| `@_exported import` of 11 dependency modules | `exports.swift` re-exports `Tagged_Primitives`, `Bit_Primitives`, `Stack_Primitives`, `Set_Primitives`, `Heap_Primitives`, `Index_Primitives`, `Input_Primitives`, `Array_Primitives`, `Collection_Primitives`, `Queue_Primitives`, `Dictionary_Primitives`. | **CONTESTED** -- Re-exporting implementation dependencies leaks internal data structure choices to consumers. A consumer of graph-primitives should not need to know that graphs use `Stack`, `Queue`, `Heap`, or `Bit` vectors internally. However, some re-exports are justified: `Index_Primitives` (for `Graph.Node<Tag>` / `Graph.Index<Tag>`) and `Array_Primitives` (for `Array.Indexed<Tag>` in return types) are part of the public API surface. The re-export of `Stack_Primitives`, `Queue_Primitives`, `Heap_Primitives`, `Bit_Primitives`, and `Set_Primitives` exposes algorithm implementation details. See Recommendations. |
| `Entry` struct for Dijkstra conforms to `__HeapOrdering` | `Graph.Sequential.Path.Entry` conforms to `__HeapOrdering`, an underscored protocol from `Heap_Primitives`. | **MINOR** -- The underscore prefix suggests this is an internal protocol. The `Entry` type itself is `@usableFromInline` (not public), so the conformance does not leak publicly. However, it creates a coupling between graph-primitives and a heap implementation detail. |
| Algorithms use `[Int]`, `[Graph.Node<Tag>?]` as working state | SCC uses `[Int]` for `nodeIndex`/`lowLink`. Path algorithms use `[Graph.Node<Tag>?]` for predecessors. | **OK** -- These are algorithm-local working state. Using stdlib arrays for temporary algorithm state is pragmatic and correct. They are not part of the public API. |
| `transform.subgraph` uses `position` on nodes | The subgraph extraction accesses `node.position` and `adjacent.position` directly for index mapping. | **ACCEPTABLE** -- In `Graph.Sequential`, position IS the vertex identity. The `position` access is the defined way to extract the integer backing from a typed index. This is consistent with the sequential allocation model. |

### What's MISSING from Graph (things that are solely graph discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `Equatable where Payload: Equatable` | Algebraic | Medium -- graph equality is vertex-set + edge-set equality, independent of allocation order (but in Sequential, order is deterministic, so element-wise comparison is correct) |
| `Hashable where Payload: Hashable` | Algebraic | Medium -- follows from Equatable |
| Undirected graph variant | Graph type | Medium -- current package is directed-only; undirected graphs are a fundamental graph variant |
| Weighted edge type | Edge semantics | Low -- currently weight is extracted via closure in `path.weighted(from:to:weight:)`, not encoded in the type system |
| `degree(of:)` / `inDegree(of:)` / `outDegree(of:)` | Vertex property | Medium -- degree is a fundamental graph metric; currently requires manual adjacency counting |
| `edges` property | Graph property | Low -- enumerate all (source, target) pairs; currently implicit in adjacency lists |
| `hasEdge(from:to:)` | Edge query | Medium -- direct edge existence check (not path existence) |
| Condensation graph (from SCC) | Analysis | Low -- collapsing SCCs to single nodes produces a DAG; useful follow-on to `scc()` |
| `CustomStringConvertible` / `CustomDebugStringConvertible` | Ergonomics | Low |
| Graph union / overlay / connect (Mokhov algebra) | Algebraic | Low -- compositional graph construction; would require vertex remapping |
| Bipartiteness check | Analysis | Low -- classifying vertices into two independent sets |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: graph-primitives is well-layered

The current `graph-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Topological semantics** -- vertex identity, edge/adjacency representation, traversal, analysis, path-finding, structural transforms -- solely graph discipline
2. **Pure delegation** -- thin access to `Array.Indexed<Tag>` for payload storage, with graph-level interpretation
3. **Construction** -- `Builder` pattern providing a graph-specific two-phase allocate-then-freeze workflow

The package demonstrates a clear architectural principle: **the graph layer owns topology; the array/buffer layer owns storage**. The `Graph.Adjacency.Extract` pattern is particularly well-designed -- it decouples graph algorithms from payload types without requiring protocol conformance, acting as a function-value witness akin to BGL's concept maps.

### Specific Recommendations

#### 1. Audit `@_exported import` in `exports.swift` (Medium Priority)

The current `exports.swift` re-exports 11 dependency modules. Several of these are implementation details:

| Module | Public API? | Recommendation |
|--------|-------------|----------------|
| `Index_Primitives` | Yes -- `Graph.Node<Tag>`, `Graph.Index<Tag>` | Keep `@_exported` |
| `Array_Primitives` | Yes -- `Array.Indexed<Tag>` in `Graph.Sequential.storage` | Keep `@_exported` (or make storage fully opaque) |
| `Tagged_Primitives` | Likely -- phantom tag patterns | Keep `@_exported` |
| `Set_Primitives` | Yes -- `Set.Ordered` in return types of `reachable`, `dead` | Keep `@_exported` |
| `Collection_Primitives` | Possibly | Evaluate |
| `Stack_Primitives` | No -- algorithm working state only | Consider removing `@_exported` |
| `Queue_Primitives` | No -- BFS working state only | Consider removing `@_exported` |
| `Heap_Primitives` | No -- Dijkstra working state only | Consider removing `@_exported` |
| `Bit_Primitives` | No -- visited tracking only | Consider removing `@_exported` |
| `Input_Primitives` | Unclear | Evaluate |
| `Dictionary_Primitives` | Unclear | Evaluate |

Re-exporting implementation dependencies is not a layering *violation* (the dependency direction is correct -- downward), but it exposes implementation choices to consumers who should only see graph-level types.

#### 2. Fix `nodes` property internal access (Minor)

`Graph.Sequential.nodes` accesses `storage._storage.count` -- an internal member of `Array.Indexed`. Consider providing a public `indices`-like API on `Array.Indexed<Tag>` that returns a sequence of `Index<Tag>`, or use the already-public `storage.count` with appropriate conversion:

```swift
// Current (reaches into internals):
public var nodes: some Swift.Sequence<Node<Tag>> {
    (0..<storage._storage.count).lazy.map { Node<Tag>(__unchecked: (), position: $0) }
}

// Suggested (uses public API):
// Requires Array.Indexed to expose a typed node sequence
```

#### 3. Add `Equatable` / `Hashable` (Medium Priority)

Graph equality (same vertices, same edges) is a fundamental graph-discipline concept. For `Graph.Sequential` where vertex order is deterministic, element-wise payload comparison is the correct implementation.

#### 4. Add degree queries (Medium Priority)

`outDegree(of:)` and `inDegree(of:)` (the latter requiring reverse traversal) are fundamental graph metrics referenced in every graph theory textbook. They are lightweight to implement and purely topological.

#### 5. Consider `hasEdge(from:to:)` (Medium Priority)

Direct edge existence is distinct from path existence. Currently a consumer must extract adjacency and search manually. A `hasEdge(from:to:)` method on the analyze or adjacency accessor would be a natural graph-discipline API.

#### 6. No buffer/slab/storage concerns have leaked upward

The audit found **zero instances** of graph-primitives performing work that properly belongs to the buffer, storage, or memory layer. All element lifecycle, memory allocation, contiguous layout, and capacity management are handled by the underlying `Array.Indexed<Tag>` and its dependencies. The graph layer reads payloads and follows edges -- nothing more.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure graph discipline (topology, traversal, analysis, path, transform) | 70+ distinct API members | Correctly placed |
| Pure delegation (thin access to Array.Indexed) | 4 passthrough properties/subscripts | Correctly placed -- thin wrapping is the design intent |
| Storage/buffer concern leaked into graph | **0** | Clean separation |
| Minor internal access leak (`_storage`) | 1 (`nodes` property) | Cosmetic, not semantic |
| `@_exported` over-exposure | 5-7 modules | Not a layering violation, but exposes implementation choices |
| Graph concern missing | 8-11 items | Future work, not a layering violation |

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": Graph ADT axioms
- Mokhov, "Algebraic Graphs with Class" (Haskell Symposium, 2017): [An algebra of graphs](https://blogs.ncl.ac.uk/andreymokhov/an-algebra-of-graphs/)
- [Algebra.Graph (Haskell)](https://hackage.haskell.org/package/algebraic-graphs/docs/Algebra-Graph.html): Algebraic graph implementation
- [petgraph (Rust)](https://docs.rs/petgraph/latest/petgraph/): Graph library with trait-based storage abstraction
- [Boost Graph Library](https://www.boost.org/doc/libs/latest/libs/graph/doc/adjacency_list.html): Concept-based graph abstraction in C++
- Haskell `Data.Graph`: Stdlib graph algorithms
- Cormen, Leiserson, Rivest, Stein (CLRS), "Introduction to Algorithms": BFS, DFS, Topological Sort, SCC
- Tarjan, "Depth-first search and linear graph algorithms" (1972): SCC algorithm
- Dijkstra, "A note on two problems in connexion with graphs" (1959): Shortest path
- [Graph (abstract data type) -- Wikipedia](https://en.wikipedia.org/wiki/Graph_(abstract_data_type)): Formal ADT definition
- [Graph ADT and Basic Operations](https://fiveable.me/data-structures/unit-10/graph-adt-basic-operations/study-guide/vWOgZLIBmamAdk6X): ADT operations reference
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md` -- Template and prior art
