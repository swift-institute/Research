# Graph Primitives Roadmap

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: RECOMMENDATION
tier: 2
scope: graph-primitives, machine-primitives, future graph consumers
---
-->

## Context

`swift-graph-primitives` provides `Graph.Sequential<Tag, Payload>` — an immutable dense directed graph with phantom-tagged node IDs, a `~Copyable` builder with forward-reference support, and composable analysis algorithms. The package currently serves one consumer (`machine-primitives`) and was designed as consumer-agnostic infrastructure per the "Timeless Substrate" analysis.

The `Machine.Program → Graph.Sequential` migration (completed 2026-02-23) validated the architecture: machine programs are now inspectable directed graphs with full analysis capabilities. This migration also revealed specific gaps — capabilities that consumers need but graph-primitives does not yet provide.

This document inventories what exists, identifies gaps driven by consumer needs, prioritizes additions, and defines what graph-primitives should NOT become.

## Current Inventory

### Core Types

| Type | Purpose | File |
|------|---------|------|
| `Graph.Node<Tag>` | Phantom-tagged vertex identity (`= Index<Tag>`) | `Graph.Node.swift` |
| `Graph.Sequential<Tag, Payload>` | Immutable dense directed graph (node ID = array index) | `Graph.Sequential.swift` |
| `Graph.Sequential.Builder` | `~Copyable` builder with hole support for forward references | `Graph.Sequential.Builder.swift` |
| `Graph.Adjacency.List<Tag>` | Canonical adjacency list payload | `Graph.Adjacency.List.swift` |
| `Graph.Adjacency.Extract<Payload, Tag, Adjacent>` | Protocol-free adjacency extraction (closure witness) | `Graph.Adjacency.Extract.swift` |
| `Graph.Remappable.Remap<Payload, Tag, Adjacent>` | Node reference remapping for structural transforms | `Graph.Remappable.Remap.swift` |
| `Graph.Default.Value<Payload>` | Hole payload witness for forward-reference construction | `Graph.Default.Value.swift` |

### Traversals (3 algorithms)

| Algorithm | Type | Complexity |
|-----------|------|------------|
| Depth-first (first-visit) | `Graph.Traversal.First.Depth` — `~Copyable` stack-based iterator | O(V+E) |
| Breadth-first (first-visit) | `Graph.Traversal.First.Breadth` — `~Copyable` queue-based iterator | O(V+E) |
| Topological ordering | `Graph.Traversal.Topological` — Kahn's algorithm with cycle detection | O(V+E) |

### Analysis (6 algorithms)

| Algorithm | Method | Complexity |
|-----------|--------|------------|
| Forward reachability | `analyze.reachable(from:)` → `Set.Ordered` | O(V+E) |
| Dead node detection | `analyze.dead(from:)` → complement of reachable set | O(V+E) |
| Cycle detection | `analyze.hasCycles()` — delegates to topological sort | O(V+E) |
| Strongly connected components | `analyze.scc()` — iterative Tarjan | O(V+E) |
| Transitive closure | `analyze.transitiveClosure()` — per-node DFS | O(V·(V+E)) |
| Backward reachability | `reverse.reachable(to:)` — reverse graph + forward DFS | O(V+E) |

### Path Finding (3 algorithms)

| Algorithm | Method | Complexity |
|-----------|--------|------------|
| Path existence | `path.exists(from:to:)` — BFS | O(V+E) |
| Shortest unweighted path | `path.shortest(from:to:)` — BFS with predecessors | O(V+E) |
| Weighted shortest path | `path.weighted(from:to:weight:)` — Dijkstra | O((V+E) log V) |

### Transforms (2 operations)

| Operation | Method | Complexity |
|-----------|--------|------------|
| Payload map | `transform.payloads(_:)` — structure-preserving functor | O(V) |
| Induced subgraph | `transform.subgraph(inducedBy:using:)` — node subset with remapping | O(V+E) |

### Reverse (1 operation)

| Operation | Method | Complexity |
|-----------|--------|------------|
| Edge reversal | `reverse.reversed()` → new graph with all edges transposed | O(V+E) |

**Total: 48 source files, 70+ public API members, 15 algorithms.**

### Accessor Pattern

All operations use a consistent namespace accessor pattern:

```swift
graph.traverse.first.depth(from: root)    // Traversal
graph.analyze.reachable(from: root)        // Analysis
graph.path.shortest(from: a, to: b)        // Path finding
graph.transform.subgraph(inducedBy: keep)  // Transformation
graph.reverse.reversed()                   // Reverse
```

Custom payload types use `Extract` witnesses; `Adjacency.List` payloads get convenience overloads.

---

## Gap Analysis — What Consumers Need

### 1. Graph Structural Equality

**Consumer need**: Common subexpression elimination in machine programs — detect structurally identical subtrees to deduplicate sub-parsers.

**Status**: Missing.

**What it requires**: A function that compares two subgraphs rooted at given nodes, returning whether they are structurally isomorphic (same topology, equal payloads). This is not full graph isomorphism (NP-complete for general graphs) — it is rooted subtree comparison on DAGs, which is O(V) with hashing or O(V²) with pairwise comparison.

**Design considerations**:
- Requires `Payload: Equatable` constraint, or an equality witness analogous to `Extract`
- Hash-based approach: compute structural hash per node (Merkle-style), compare hashes first, verify on collision
- The `graph-operations-audit` recommended adding `Equatable` conformance to `Graph.Sequential` — this is the generalization

**Complexity**: Medium. Requires new analysis algorithm + equality witness pattern.

### 2. Dominator Trees

**Consumer need**: Standard compiler analysis — identify dominators for optimization passes. A node D dominates node N if every path from root to N passes through D. Dominator trees enable loop detection, code motion, and SSA construction.

**Status**: Missing.

**What it requires**: Lengauer-Tarjan algorithm or Cooper et al. simple dominator algorithm. Input: graph + root. Output: dominator tree (each node maps to its immediate dominator).

**Design considerations**:
- Lengauer-Tarjan: O(V·α(V)) nearly-linear, complex implementation
- Cooper et al.: O(V²) worst case but simpler, fast in practice for reducible graphs
- Machine programs are mostly reducible (cycles only via `.ref`), favoring Cooper
- Returns a new `Graph.Sequential` representing the dominator tree, or a flat mapping `Node → Node` (immediate dominator)

**Complexity**: Medium. Well-understood algorithm, one new analysis method.

### 3. DOT/Graphviz Export

**Consumer need**: Debugging visualization for any graph consumer. Machine programs rendered as labeled directed graphs for development inspection.

**Status**: Missing.

**What it requires**: A traversal that emits DOT syntax. Nodes labeled by a user-provided closure (to render payload-specific labels). Edges derived from `Extract`.

**Design considerations**:
- Belongs in graph-primitives as a generic capability (consumer-agnostic)
- Output is `String` — no Foundation dependency (string interpolation only)
- Node labels via closure: `(Payload) -> String`
- Edge labels optional: `(Payload, Node<Tag>) -> String?`
- Cluster/subgraph support is a future extension, not required initially
- Should live under `graph.export.dot(label:)` or similar accessor

**Complexity**: Low. String generation, no algorithmic novelty.

### 4. Node Contraction (Linear Chain Fusion)

**Consumer need**: Fuse linear chains in machine programs. When node B has exactly one predecessor (A) and A has exactly one successor (B), the chain A→B→C can be contracted to A→C with combined payload.

**Status**: Missing.

**What it requires**: A transform that identifies linear chains (in-degree 1, out-degree 1 interior nodes) and contracts them using a user-provided fusion function.

**Design considerations**:
- Requires in-degree computation (currently only forward adjacency exists)
- Chain detection: traverse nodes, check `inDegree(node) == 1 && outDegree(node) == 1`
- The `graph-operations-audit` recommended adding `degree(of:)` and `inDegree(of:)` — prerequisite for this
- Fusion function signature: `(Payload, Payload) -> Payload` (combine chain payloads)
- Result: new graph with fewer nodes

**Complexity**: Medium. Requires degree queries (prerequisite) + new transform.

### 5. First-Class Edge Metadata

**Consumer need**: Edge weights, labels, and annotations beyond closure-based extraction. Currently weights are closure-only via `path.weighted(from:to:weight:)`.

**Status**: Missing — weights are closure-only.

**What it requires**: An edge-attributed graph type or an edge annotation layer over `Graph.Sequential`.

**Design considerations**:
- `Graph.Sequential` encodes adjacency IN payloads (no separate edge storage). This is a deliberate design decision per "Timeless Substrate" — adding separate edge storage would be a new graph type, not a modification.
- Alternative: `Graph.Sequential.Attributed<Tag, NodePayload, EdgePayload>` with adjacency stored as `[(Node<Tag>, EdgePayload)]`
- Alternative: Keep current design, provide `EdgeExtract` witness that extracts `(Node<Tag>, Weight)` pairs from payloads
- The closure-based approach (`path.weighted(from:to:weight:)`) already works for algorithms. First-class edges would improve ergonomics but add structural complexity.

**Complexity**: High. Architectural decision — new type vs. witness pattern. Needs dedicated investigation research.

### 6. Incremental Builder (Graph Mutation)

**Consumer need**: Modify existing graph (add/remove nodes) without full rebuild. Currently the builder is consuming — once `build()` is called, the graph is frozen.

**Status**: Missing — builder is consuming.

**What it requires**: Either a mutable graph type or an incremental builder that can extend an existing graph.

**Design considerations**:
- Current design is immutable-by-construction (Builder → Frozen). This is load-bearing for `Sendable` guarantees and prevents data races.
- Adding mutation would require either copy-on-write semantics or a separate mutable graph type
- For machine programs, the typical workflow is: build complete program, then analyze/transform to produce a new program. This is functional (transform old → new), not imperative (mutate in place).
- Incremental modification could be modeled as: take existing graph, extract subgraph, build new graph incorporating old nodes + new nodes. This works within the current architecture.

**Complexity**: High. Challenges immutability invariant. May not be needed if functional transforms suffice.

### 7. Graph Diff

**Consumer need**: Compare two versions of a program for incremental recompilation diagnostics. When a parser combinator changes, identify which nodes changed and which dependents are affected.

**Status**: Missing.

**What it requires**: A function that takes two graphs and produces a diff: added nodes, removed nodes, changed payloads, changed edges.

**Design considerations**:
- Requires `Payload: Equatable` or an equality witness
- Node identity across versions: by position (index stability) or by structural hash
- If graphs are produced by the same builder in sequence, positional identity may hold for unchanged prefixes
- Related to graph equality (#1) — diff is the generalization of equality

**Complexity**: Medium-High. Depends on identity model across graph versions.

---

## Prioritization

Ranked by: number of consumers served, enabling power for downstream work, implementation complexity.

| Priority | Capability | Consumers | Enables | Complexity | Recommendation |
|----------|-----------|-----------|---------|------------|----------------|
| **1** | Degree queries (`inDegree`, `outDegree`, `hasEdge`) | All graph consumers | Node contraction, dominator trees, general graph analysis | Low | Implement first — prerequisite for #4 and #5. Already recommended by `graph-operations-audit`. |
| **2** | DOT/Graphviz export | All graph consumers | Debugging, documentation, visualization | Low | High value-to-effort ratio. Generic capability useful to every consumer. |
| **3** | Graph structural equality / hashing | Machine-primitives (CSE) | Common subexpression elimination, graph diff | Medium | Core analysis primitive. Hash-based approach (Merkle) enables both equality and diff. |
| **4** | Dominator trees | Machine-primitives (optimization) | Loop detection, code motion, SSA-style analysis | Medium | Standard compiler infrastructure. Well-understood algorithms. |
| **5** | Node contraction | Machine-primitives (optimization) | Linear chain fusion, dispatch reduction | Medium | Requires degree queries (#1). High impact for machine program optimization. |
| **6** | Graph diff | Machine-primitives (incremental recompilation) | Change detection, targeted recompilation | Medium-High | Requires equality (#3). Important for development workflow, not runtime. |
| **7** | First-class edge metadata | Future consumers (weighted graphs) | Ergonomic weighted analysis | High | Architectural decision needed. Current closure-based approach works. Defer until a concrete consumer demands it. |
| **8** | Incremental builder | Future consumers (mutable graphs) | Dynamic graph construction | High | Challenges core immutability invariant. Functional transforms may suffice. Defer. |

---

## Non-Goals

Graph-primitives MUST NOT become:

1. **A general-purpose graph database.** No persistence, no indexing, no query language. `Graph.Sequential` is an in-memory data structure for algorithmic analysis, not a storage engine.

2. **A visualization library.** DOT export produces text that external tools render. Graph-primitives does not render pixels, host servers, or provide interactive UIs. Visualization belongs in Layer 4 (Components) or Layer 5 (Applications).

3. **A mutable graph with stable identity across mutations.** The current `Builder → Frozen` architecture is load-bearing. Stable-identity mutable graphs (like `petgraph::StableGraph`) require fundamentally different storage (generational arenas, free lists). If needed, this would be a separate type, not a modification of `Graph.Sequential`.

4. **A sparse graph library.** `Graph.Sequential` uses dense allocation (node ID = array index). Sparse graphs with non-contiguous IDs, node deletion, and stable handles belong to a different package — possibly `swift-graph-foundations` at Layer 3.

5. **A parallel/concurrent graph processor.** Analysis algorithms are single-threaded. Parallel BFS, concurrent graph construction, and actor-based graph processing are higher-layer concerns.

---

## Outcome

**Status**: RECOMMENDATION

Graph-primitives has a strong foundation: 15 algorithms, composable accessors, phantom-typed safety, `~Copyable` builder, and zero Foundation dependency. The gap analysis reveals 8 missing capabilities, of which 6 are clearly appropriate for the primitives layer and 2 (edge metadata, incremental builder) need further investigation before committing.

Recommended implementation order:
1. Degree queries and `hasEdge` — low effort, unblocks later work
2. DOT export — high visibility, aids debugging of everything else
3. Structural hashing and equality — enables CSE and diff
4. Dominator trees — standard compiler analysis
5. Node contraction — optimization pass enabler
6. Graph diff — development workflow improvement

Items 7–8 should be deferred pending concrete consumer demand. If edge metadata is needed, a targeted investigation research document should evaluate the architectural trade-off between a new graph type and an enhanced witness pattern.

## References

- `graph-operations-audit.md` — Canonical Graph ADT coverage audit (2026-02-16)
- `graph-discipline-boundary-analysis.md` — Layer boundary validation (2026-02-14)
- `Analysis - Graph Primitives as Timeless Substrate.md` — Foundational design principles (2026-01-19)
- `machine-program-graph-sequential-migration.md` — Migration rationale and enabled capabilities (2026-02-23)
- Lengauer, T. & Tarjan, R.E. (1979). "A fast algorithm for finding dominators in a flowgraph." — Dominator tree algorithm
- Cooper, K., Harvey, T., & Kennedy, K. (2001). "A Simple, Fast Dominance Algorithm." — Practical dominator computation
- Mokhov, A. (2017). "Algebraic Graphs with Class." — Algebraic graph construction patterns
- CLRS (Cormen et al.) — Canonical graph algorithm reference
