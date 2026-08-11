# Graph and Machine Primitives Modularization

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: SUPERSEDED
superseded_by: modularization-strategy.md
tier: 2
scope: graph-primitives, machine-primitives
workflow: investigation
---
-->

## Context

Graph-primitives (38 files, 1 module) and machine-primitives (35 files, 2 modules) each contain code at different rates of change. Core data structures (graph storage, type-erased values, capture storage) are timeless — they have no reason to change once correct. Algorithm modules, carrier patterns, and program composition are additive — they grow as new capabilities are needed.

A single module conflates these rates of change. When an algorithm is added or a carrier pattern evolves, the entire module's version moves. Modularization isolates the timeless core from focused capability modules, with an umbrella re-export that makes the split invisible to consumers.

This is not motivated by constraint poisoning ([PATTERN-022]) — neither package has `~Copyable`-generic types that need `Copyable`-specific extensions across module boundaries. The motivation is **implementation purity**: each module has a single responsibility, and the core is protected from churn.

## Question

What are the natural module boundaries for graph-primitives and machine-primitives, and what does each module contain?

---

## Analysis

### Part 1: Graph Primitives

#### Current State

38 source files in one module. 13 package dependencies, of which 5 (Collection, Dictionary, Input, Bit, Sequence) are re-exported but not used by any implementation file.

#### Dependency Analysis

Actual dependencies by file group (verified by source inspection):

| Group | Files | Dependencies |
|-------|-------|-------------|
| **Core** | Sequential, Builder, Node, Index, Adjacency (Extract, List), Remappable (Remap), Default (Value, list) | Identity, Index, Array |
| **Traversal** | Traverse (First, Topological), Traversal iterators (Depth, Breadth, Topological) | + Stack, Queue, Bit_Vector |
| **Analysis** | Analyze (Reachable, Dead, SCC, Cycles, TransitiveClosure) | + Stack, Bit_Vector, Set |
| **Path** | Path (Exists, Shortest, Weighted) | + Queue, Heap, Bit_Vector |
| **Transform** | Transform (Payloads, Subgraph) | + Set |
| **Reverse** | Reverse (Graph, Reachable) | + Stack, Bit_Vector, Set |

Key observation: Core needs only 3 dependencies. The heavy dependencies (Stack, Queue, Heap, Bit_Vector, Set) are entirely algorithm-specific. Separating Core from algorithms gives it a dramatically smaller dependency footprint.

#### Proposed Modules

```
Graph Primitives Core           (10 files)
       ↑
Graph Primitives Traversal      (7 files)
Graph Primitives Analysis       (6 files)
Graph Primitives Path           (4 files)
Graph Primitives Transform      (3 files)
Graph Primitives Reverse        (3 files)
       ↑
Graph Primitives                (umbrella — re-exports all)
```

**Graph Primitives Core** (timeless — the data structure):

| File | Type |
|------|------|
| Graph.swift | Namespace |
| Graph.Node.swift | `Graph.Node<Tag>` typealias |
| Graph.Index.swift | Index re-export |
| Graph.Sequential.swift | `Graph.Sequential<Tag, Payload>` |
| Graph.Sequential.Builder.swift | `Graph.Sequential.Builder` |
| Graph.Adjacency.swift | Namespace |
| Graph.Adjacency.Extract.swift | `Graph.Adjacency.Extract<Tag, Payload, Adjacency>` |
| Graph.Adjacency.List.swift | `Graph.Adjacency.List<Tag, Payload>` |
| Graph.Remappable.swift | Namespace |
| Graph.Remappable.Remap.swift | `Graph.Remappable.Remap<Tag, Payload, Adjacency>` |
| Graph.Default.swift | Namespace |
| Graph.Default.Value.swift | Default payload construction |
| Graph.Default.list.swift | Default adjacency list |
| exports.swift | `@_exported import Tagged_Primitives`, `Index_Primitives`, `Array_Primitives` |

Dependencies: `Tagged Primitives`, `Index Primitives`, `Array Primitives`

**Graph Primitives Traversal** (DFS, BFS, topological ordering):

| File | Type |
|------|------|
| Graph.Sequential.Traverse.swift | Accessor namespace |
| Graph.Sequential.Traverse.First.swift | `.traverse.first` accessor |
| Graph.Sequential.Traverse.Topological.swift | `.traverse.topological` accessor |
| Graph.Traversal.swift | Iterator namespace |
| Graph.Traversal.First.swift | Iterator base |
| Graph.Traversal.First.Depth.swift | `~Copyable` DFS iterator |
| Graph.Traversal.First.Breadth.swift | `~Copyable` BFS iterator |
| Graph.Traversal.Topological.swift | `~Copyable` topological iterator |

Dependencies: Core + `Stack Primitives`, `Queue Primitives`, `Bit Vector Primitives`

**Graph Primitives Analysis** (reachability, dead nodes, SCC, cycles):

| File | Type |
|------|------|
| Graph.Sequential.Analyze.swift | `.analyze` accessor |
| Graph.Sequential.Analyze.Reachable.swift | Reachable node set |
| Graph.Sequential.Analyze.Dead.swift | Dead node detection |
| Graph.Sequential.Analyze.SCC.swift | Tarjan's SCC |
| Graph.Sequential.Analyze.Cycles.swift | Cycle detection |
| Graph.Sequential.Analyze.TransitiveClosure.swift | Transitive closure |

Dependencies: Core + `Stack Primitives`, `Bit Vector Primitives`, `Set Primitives`

**Graph Primitives Path** (existence, shortest, weighted):

| File | Type |
|------|------|
| Graph.Sequential.Path.swift | `.path` accessor |
| Graph.Sequential.Path.Exists.swift | Path existence |
| Graph.Sequential.Path.Shortest.swift | Unweighted shortest path |
| Graph.Sequential.Path.Weighted.swift | Dijkstra's weighted path |

Dependencies: Core + `Queue Primitives`, `Heap Primitives`, `Bit Vector Primitives`

**Graph Primitives Transform** (payload mapping, subgraph extraction):

| File | Type |
|------|------|
| Graph.Sequential.Transform.swift | `.transform` accessor |
| Graph.Sequential.Transform.Payloads.swift | Payload mapping |
| Graph.Sequential.Transform.Subgraph.swift | Induced subgraph |

Dependencies: Core + `Set Primitives`

**Graph Primitives Reverse** (reversed graph, backward reachability):

| File | Type |
|------|------|
| Graph.Sequential.Reverse.swift | `.reverse` accessor |
| Graph.Sequential.Reverse.Graph.swift | Full graph reversal |
| Graph.Sequential.Reverse.Reachable.swift | Backward reachable set |

Dependencies: Core + `Stack Primitives`, `Bit Vector Primitives`, `Set Primitives`

**Graph Primitives** (umbrella):

```swift
// exports.swift
@_exported import Graph_Primitives_Core
@_exported import Graph_Primitives_Traversal
@_exported import Graph_Primitives_Analysis
@_exported import Graph_Primitives_Path
@_exported import Graph_Primitives_Transform
@_exported import Graph_Primitives_Reverse
```

No source files of its own. Zero implementation — pure re-export.

#### Unused Re-Exports

The current exports.swift re-exports 7 packages. Of these, 5 are not used by any implementation:

| Package | Used By | Action |
|---------|---------|--------|
| Tagged Primitives | Core (Node, Tagged) | Keep in Core exports |
| Index Primitives | Core (Graph.Node is Index<Tag>) | Keep in Core exports |
| Array Primitives | Core (Sequential storage) | Keep in Core exports |
| Set Primitives | Analysis, Transform, Reverse | Keep in respective module exports |
| Collection Primitives | **Nothing** | Remove from exports |
| Dictionary Primitives | **Nothing** | Remove from exports |
| Input Primitives | **Nothing** | Remove from exports |

The unused re-exports were likely added speculatively for consumer convenience. They should be removed — consumers that need Collection or Dictionary should import those directly. The re-export chain should reflect actual dependencies, not anticipated ones.

#### No Lateral Dependencies

Algorithm modules depend only on Core. No algorithm module depends on another:

- Analysis does not use Traversal iterators (it has its own stack-based walks)
- Path does not use Analysis (it has its own BFS/Dijkstra)
- Reverse does not use Transform (it builds the reversed graph directly)
- Transform does not use Analysis (subgraph takes a node set, doesn't compute one)

This is the ideal module topology: a flat fan from Core with no lateral edges.

---

### Part 2: Machine Primitives

#### Current State

35 source files in `Machine Primitives` + 2 files in `Machine Primitives Conveniences`. The module depends on Handle, Identity, Index, Bit, and Graph primitives.

#### Structural Dependencies

The type dependency chain is:

```
Value, Capture, Frame, Arena, Handle, Mode    (self-contained runtime infrastructure)
       ↑
Transform, Combine, Next, Finalize            (type-erased carriers — reference Value, Capture)
       ↑
Node                                          (enum cases store carrier instances)
       ↑
Program, Builder                              (store Graph.Sequential<Node>, Capture.Store)
       ↑
Conveniences                                  (Builder factory methods, Program+Apply)
```

Each level depends only on the level below. No upward or lateral dependencies.

#### Proposed Modules

```
Machine Primitives Core         (19 files)
       ↑
Machine Primitives Carriers     (11 files)
       ↑
Machine Primitives Program      (2 files)
Machine Primitives Conveniences (2 files, existing)
       ↑
Machine Primitives              (umbrella — re-exports all)
```

**Machine Primitives Core** (timeless — runtime infrastructure):

| File | Type |
|------|------|
| Machine.swift | Namespace |
| Machine.Index.swift | Index re-export |
| Machine.Value.swift | `Value<Mode>` — type-erased container, `apply`, `combine`, `read` |
| Machine.Value.Arena.swift | `Value.Arena` — slot-addressed value storage |
| Machine.Value.Box.swift | `Value.Box` — single-value container |
| Machine.Value.Handle.swift | `Value.Handle` — arena handle typealias |
| Machine.Capture.swift | Namespace |
| Machine.Capture.ID.swift | `Capture.ID<T>` — typed capture identifier |
| Machine.Capture.RawID.swift | `Capture.RawID` — type-erased capture identifier |
| Machine.Capture.Slot.swift | `Capture.Slot` — type-erased capture storage |
| Machine.Capture.Store.swift | `Capture.Store<Mode>` — mutable capture collection |
| Machine.Capture.Store+Reference.swift | Reference mode store operations |
| Machine.Capture.Store+Unchecked.swift | Unchecked mode store operations |
| Machine.Capture.Frozen.swift | `Capture.Frozen<Mode>` — immutable capture snapshot |
| Machine.Capture.Frozen+Reference.swift | Reference mode frozen operations |
| Machine.Capture.Frozen+Unchecked.swift | Unchecked mode frozen operations |
| Machine.Capture.Mode.swift | Mode namespace |
| Machine.Capture.Mode.Reference.swift | `Mode.Reference: Sendable` |
| Machine.Capture.Mode.Unchecked.swift | `Mode.Unchecked` |
| Machine.Frame.swift | `Frame<Leaf, Failure, Mode>` — execution frame |
| Machine.Frame.Sequence.swift | `Frame.Sequence` — sequence frame state |
| exports.swift | `@_exported import Tagged_Primitives`, `Index_Primitives`, `Handle_Primitives`, `Bit_Primitives` |

Dependencies: `Tagged Primitives`, `Index Primitives`, `Handle Primitives`, `Bit Primitives`

No dependency on Graph Primitives. The core runtime infrastructure is graph-agnostic.

**Machine Primitives Carriers** (type-erased operation bridge):

| File | Type |
|------|------|
| Machine.Transform.swift | Namespace |
| Machine.Transform.Erased.swift | `Transform.Erased<Mode>` — non-throwing unary |
| Machine.Transform.Throwing.swift | `Transform.Throwing<Mode, Failure>` — throwing unary |
| Machine.Combine.swift | Namespace |
| Machine.Combine.Erased.swift | `Combine.Erased<Mode>` — binary combination |
| Machine.Next.swift | Namespace |
| Machine.Next.Erased.swift | `Next.Erased<Mode, NodeID>` — next-node selection |
| Machine.Finalize.swift | Namespace |
| Machine.Finalize.Array.swift | `Finalize.Array<Mode>` — array collection |
| Machine.Node.swift | `Node<Leaf, Failure, Mode>` — program node enum |

Dependencies: Core only

Node lives here because its enum cases structurally reference carrier types (`.map` stores `Transform.Erased`, `.sequence` stores `Combine.Erased`, etc.). Node cannot exist without carriers.

**Machine Primitives Program** (graph-based program structure):

| File | Type |
|------|------|
| Machine.Program.swift | `Program<Leaf, Failure, Mode>` — `Graph.Sequential<Node>` |
| Machine.Program.Builder.swift | `Builder<Leaf, Failure, Mode>: ~Copyable` |

Dependencies: Core + Carriers + `Graph Primitives Core`

This is the only module that depends on graph-primitives. It composes the graph storage with the carrier-bearing nodes into an inspectable program.

Note: Program depends on `Graph Primitives Core` specifically — it needs `Graph.Sequential` and `Graph.Sequential.Builder`, not the graph algorithms. Machine-level analysis (dead node elimination, etc.) uses graph algorithms, but that happens in parser-machine-primitives or future optimization modules, not in the Program type itself.

**Machine Primitives Conveniences** (existing — factory methods):

| File | Type |
|------|------|
| Machine.Builder+Carriers.swift | Builder carrier factory methods |
| Machine.Program+Apply.swift | Program convenience accessor |

Dependencies: Core + Carriers + Program

Unchanged from current structure.

**Machine Primitives** (umbrella):

```swift
// exports.swift
@_exported import Machine_Primitives_Core
@_exported import Machine_Primitives_Carriers
@_exported import Machine_Primitives_Program
@_exported import Machine_Primitives_Conveniences
```

#### Graph Dependency Isolation

A key benefit: `Machine Primitives Core` and `Machine Primitives Carriers` have **no dependency on graph-primitives**. The graph dependency is confined to `Machine Primitives Program`. A consumer that only needs the runtime infrastructure (Value, Capture, Frame, carriers) — for example, a custom execution engine with a different program representation — can depend on Core + Carriers without pulling in the entire graph package.

---

### Part 3: Parser-Machine Primitives

Parser-machine-primitives (22 files, 1 module) has a tightly coupled run loop, compilation pipeline, and memoization system. The run loop reads from Program and drives Frame processing. Memoization is woven into the run loop's hot path. Compiled/Prepared are thin wrappers around compilation + run invocation.

**Recommendation: Keep as single module.** The entire package IS the execution engine. Splitting would create a module boundary through the middle of a single algorithm. If memoization becomes pluggable in the future, it could become a separate module — but that's speculative.

---

### Part 4: Consumer Impact

The umbrella modules make the split invisible to consumers:

**Before:**
```swift
import Machine_Primitives
```

**After:**
```swift
import Machine_Primitives  // identical — umbrella re-exports everything
```

Consumers that want finer-grained dependencies can opt in:
```swift
import Machine_Primitives_Core      // just Value, Capture, Frame
import Graph_Primitives_Analysis    // just graph analysis algorithms
```

No existing consumer code changes. The umbrella product name and import path are identical.

---

### Part 5: Test Organization

Each new module gets its own test files within the existing test target. No new test targets needed — the test target depends on the umbrella, which provides everything.

If test support modules are added later, they follow the same umbrella pattern:
```
Graph Primitives Core Test Support
       ↑
Graph Primitives Test Support          (umbrella — re-exports all)
```

---

## Outcome

**Status**: RECOMMENDATION

### Graph Primitives — 7 Modules

| Module | Files | Dependencies | Rate of Change |
|--------|-------|-------------|----------------|
| Graph Primitives Core | 14 | Identity, Index, Array | Timeless |
| Graph Primitives Traversal | 8 | Core + Stack, Queue, Bit Vector | Stable |
| Graph Primitives Analysis | 6 | Core + Stack, Bit Vector, Set | Grows with new analyses |
| Graph Primitives Path | 4 | Core + Queue, Heap, Bit Vector | Stable |
| Graph Primitives Transform | 3 | Core + Set | Grows with new transforms |
| Graph Primitives Reverse | 3 | Core + Stack, Bit Vector, Set | Stable |
| Graph Primitives | 1 | Re-exports all | Never changes |

No lateral dependencies between algorithm modules. Flat fan from Core.

### Machine Primitives — 5 Modules

| Module | Files | Dependencies | Rate of Change |
|--------|-------|-------------|----------------|
| Machine Primitives Core | 21 | Identity, Index, Handle, Bit | Timeless |
| Machine Primitives Carriers | 10 | Core | Grows with new combinators |
| Machine Primitives Program | 2 | Core + Carriers + Graph Core | Stable |
| Machine Primitives Conveniences | 2 | Core + Carriers + Program | Grows with ergonomics |
| Machine Primitives | 1 | Re-exports all | Never changes |

Graph dependency confined to Program module.

### Parser-Machine Primitives — No Change

Keep as single module. Tightly integrated execution engine.

### Cross-Reference: Future Additions

The graph-primitives roadmap (`graph-primitives-roadmap.md`) identifies 8 missing capabilities. The machine analysis document (`machine-program-analysis-and-optimization.md`) identifies optimization passes, error recovery, and borrowed output as future work. The graph operations audit (`graph-operations-audit.md`) identifies missing basic operations. Each future addition must land cleanly in the proposed module structure.

#### Graph-Primitives — Roadmap Items Mapped to Modules

| Priority | Addition | Target Module | Notes |
|----------|----------|---------------|-------|
| 1 | Degree queries (`inDegree`, `outDegree`, `hasEdge`) | **Analysis** | Same dependency profile as existing analysis algorithms. Adds files to Analysis module. |
| 2 | DOT/Graphviz export | **New: Graph Primitives Export** | Does not fit existing algorithm modules — it's output generation, not graph analysis or transformation. Depends on Core only (traverses nodes, emits string). Low file count (1–2 files). |
| 3 | Structural equality/hashing | **Core** (`Equatable`/`Hashable` conformance) + **Analysis** (Merkle subtree hashing) | `Graph.Sequential: Equatable where Payload: Equatable` is a Core conformance. Structural subtree hashing for CSE is an analysis algorithm. Split across two modules. |
| 4 | Dominator trees | **Analysis** | Same pattern as SCC, reachable. Adds files to Analysis module. |
| 5 | Node contraction (chain fusion) | **Transform** | Structural graph-to-graph transformation, same as subgraph. Requires degree queries from Analysis (cross-module dependency from Transform → Analysis — first lateral edge). |
| 6 | Graph diff | **Analysis** | Comparison algorithm, depends on structural equality from Core. |
| 7 | Edge metadata (new type) | **Core** | New graph type alongside `Graph.Sequential`. Additive to Core. |
| 8 | Incremental builder | **Core** | Builder variant. Additive to Core. |

**One lateral dependency emerges**: Node contraction (Transform) needs degree queries (Analysis). This is the only cross-module dependency among algorithm modules. Two resolution options:

1. Move degree queries to Core (they're basic enough — `outDegree` is just `extract.adjacent(payload).count`). This preserves the flat fan topology.
2. Accept the lateral edge. Transform → Analysis is a natural dependency direction (transforms may use analysis results).

Option (1) is cleaner. Degree queries are fundamental properties, not analysis algorithms. They should live in Core alongside `count` and `isEmpty`.

**DOT export** warrants its own module rather than being folded into Transform. It produces `String` output (not a new graph), has different consumers (debugging tools, not graph algorithms), and its dependency footprint is Core-only. Adding it to the umbrella:

```swift
@_exported import Graph_Primitives_Export
```

#### Machine-Primitives — Future Work Mapped to Modules

| Addition | Source | Target Module | Notes |
|----------|--------|---------------|-------|
| Error recovery (new Node variants) | Analysis & Optimization §Error Recovery | **Carriers** | Node lives in Carriers. New `.synchronize`, `.label`, `.commit` variants add to the existing Node enum. |
| Borrowed output (new Value types) | Analysis & Optimization §Borrowed Output | **Core** | New Value handle types are runtime infrastructure. Additive to Core. |
| Optimization passes (dead node elimination, chain fusion, CSE) | Analysis & Optimization §Optimization | **New: Machine Primitives Optimization** | Composes graph algorithms with machine-specific logic. Depends on Core + Carriers + Program + Graph Primitives Analysis. Not yet proposed — additive module when optimization work begins. |
| Lookahead analysis | Analysis & Optimization §Lookahead | **New: Machine Primitives Optimization** or parser-machine-primitives | Domain-specific analysis on Node semantics. May belong in parser-machine-primitives if it requires Leaf knowledge. |

**No proposed boundary conflicts**. All future additions land in existing modules (additive) or create new modules (also additive). The umbrella pattern absorbs new modules without consumer impact.

#### Revised Module Count

With future additions accounted for:

- Graph Primitives: 7 → **8 modules** (add Export)
- Machine Primitives: 5 → **6 modules** (add Optimization, when needed)

Both additions are additive — the initial modularization proceeds as proposed, and new modules are added when the work that motivates them begins.

---

### Collateral Changes

1. Remove unused re-exports from graph-primitives (Collection, Dictionary, Input)
2. Graph Primitives product becomes a multi-target library (umbrella)
3. Machine Primitives product becomes a multi-target library (umbrella)
4. Existing consumers unchanged — umbrella preserves import path

### Implementation Order

1. Graph Primitives Core (extract timeless data structure)
2. Graph algorithm modules (one at a time, each is independent)
3. Graph Primitives umbrella
4. Machine Primitives Core (extract runtime infrastructure)
5. Machine Primitives Carriers (extract type-erased bridge)
6. Machine Primitives Program (extract graph-dependent composition)
7. Machine Primitives umbrella
8. Verify parser-machine-primitives builds against umbrellas

## References

- `implementation-quality-audit-graph-machine-parser.md` — Module organization analysis (constraint poisoning criterion)
- `machine-program-analysis-and-optimization.md` — Optimization passes, error recovery, borrowed output design space
- `machine-program-graph-sequential-migration.md` — Migration rationale and enabled capabilities
- `swift-graph-primitives/Research/graph-primitives-roadmap.md` — 8 gap items with prioritization
- `swift-graph-primitives/Research/graph-operations-audit.md` — Canonical Graph ADT coverage (degree queries, hasEdge, Equatable)
- [PATTERN-022] — `~Copyable` constraint poisoning (not the driver here)
- [API-IMPL-005] — One type per file
- [RES-003] — Research document structure
- array-primitives Core/public split — Reference implementation (different motivation: constraint poisoning)
