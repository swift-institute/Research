# Modularization Strategy: Per-Primitive vs Thematic Grouping

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: DECISION
tier: 2
scope: graph-primitives, machine-primitives
workflow: investigation
---
-->

## Context

The `graph-machine-modularization.md` document proposed splitting graph-primitives into 7 modules and machine-primitives into 5 modules, using **thematic grouping**: algorithms grouped by category (Traversal, Analysis, Path, Transform, Reverse). This groups DFS and BFS together because they're "both traversals," and groups Reachable and SCC together because they're "both analysis."

But the Swift Institute ecosystem already answers the modularization question at the package level: 61 atomic packages, each one primitive. Stack is a package. Queue is a package. Heap is a package. They don't share a "Data Structures" package. Module boundaries within a package should follow the same principle: **modularize per primitive, compose the primitives**.

This document investigates whether per-primitive modularization is the correct strategy, compared to thematic grouping.

## Question

What is the correct modularization strategy for graph-primitives and machine-primitives: grouping by theme, or one module per primitive?

---

## Analysis

### Option A: Thematic Grouping (Current Proposal)

Group algorithms/types by abstract category. Each module contains multiple related primitives.

**Graph-primitives (7 modules)**:

| Module | Contents |
|--------|----------|
| Core | Sequential, Builder, Node, Adjacency types, accessor namespace declarations |
| Traversal | DFS, BFS, Topological |
| Analysis | Reachable, Dead, SCC, Cycles, Transitive Closure |
| Path | Exists, Shortest, Weighted |
| Transform | Payload Map, Subgraph |
| Reverse | Reversed, Backward Reachable |
| Umbrella | Re-exports all |

**Machine-primitives (5 modules)**:

| Module | Contents |
|--------|----------|
| Core | Value, Capture, Frame |
| Carriers | Transform, Combine, Next, Finalize, Node |
| Program | Program, Builder |
| Conveniences | Factory methods |
| Umbrella | Re-exports all |

---

### Option B: Per-Primitive

Each algorithm or type is its own module. Composition happens via import dependencies.

#### Graph-Primitives — Per-Primitive Modules

Source inspection reveals that each algorithm is self-contained. Of 9 algorithm files:
- **7 implement their own traversal** (own DFS or BFS loop, own Stack/Queue allocation, own Bit.Vector visited tracking)
- **1 delegates**: Cycles → Topological (`hasCycles()` calls `traverse.topological().hasCycles`)
- **1 composes**: Backward Reachable → Reverse (`reachable(to:)` calls `reversed()` then does its own DFS)

No other lateral dependencies exist. Dead currently reimplements its own DFS rather than calling Reachable — but per-primitive composition favors `dead = allNodes - reachable`, making Dead depend on Reachable. Transitive Closure reimplements per-node DFS — self-contained.

**Architecture**: Core declares accessor namespace structs (`Traverse`, `Analyze`, `Path`, `Transform`, `Reverse`) with their graph + extract stored properties. Each algorithm module extends the appropriate accessor struct with its method. This is the same pattern as Property.View extensions across the ecosystem.

```
Core declares:           struct Analyze<Adjacent> { let graph; let extract }
                         var analyze: Analyze { ... }

Reachable module adds:   extension Analyze { func reachable(from:) -> ... }
SCC module adds:         extension Analyze { func scc(from:) -> ... }
Dead module adds:        extension Analyze { func dead(from:) -> ... }
```

| # | Module | Files | Dependencies | External Primitives |
|---|--------|-------|-------------|---------------------|
| 1 | **Graph Primitives Core** | 14 | Identity, Index, Array | — |
| 2 | **Graph DFS Primitives** | 2 | Core | Stack, Bit Vector |
| 3 | **Graph BFS Primitives** | 2 | Core | Queue, Bit Vector |
| 4 | **Graph Topological Primitives** | 2 | Core | Stack, Bit Vector |
| 5 | **Graph Reachable Primitives** | 1 | Core | Stack, Bit Vector, Set |
| 6 | **Graph Dead Primitives** | 1 | Core + Reachable | Set |
| 7 | **Graph SCC Primitives** | 1 | Core | Stack, Bit Vector |
| 8 | **Graph Cycles Primitives** | 1 | Core + Topological | — |
| 9 | **Graph Transitive Closure Primitives** | 1 | Core | Stack, Bit Vector |
| 10 | **Graph Path Exists Primitives** | 1 | Core | Queue, Bit Vector |
| 11 | **Graph Shortest Path Primitives** | 1 | Core | Queue, Bit Vector |
| 12 | **Graph Weighted Path Primitives** | 1 | Core | Heap, Bit Vector |
| 13 | **Graph Payload Map Primitives** | 1 | Core | — |
| 14 | **Graph Subgraph Primitives** | 1 | Core | — |
| 15 | **Graph Reverse Primitives** | 1 | Core | — |
| 16 | **Graph Backward Reachable Primitives** | 1 | Core + Reverse | Stack, Bit Vector, Set |
| 17 | **Graph Primitives** | 1 | Re-exports all | — |

**Dependency graph**:

```
                        Core
    ┌──┬──┬──┬──┬──┬──┬──┼──┬──┬──┬──┬──┬──┐
    │  │  │  │  │  │  │  │  │  │  │  │  │  │
   DFS BFS Top Rch SCC TC PE SP WP PM Sub Rev│
            ↑   ↑                          ↑ │
         Cycles Dead              BackwardReachable
```

Flat fan from Core, with exactly 3 composition edges:
- Cycles → Topological (delegation)
- Dead → Reachable (composition: `dead = allNodes - reachable`)
- Backward Reachable → Reverse (composition)

17 modules total. Most are 1–2 files.

#### Machine-Primitives — Per-Primitive Modules

Each carrier is an independent type-erased bridge. Node composes carriers. Program composes Node + Graph. The dependency chain is strictly vertical:

| # | Module | Files | Dependencies |
|---|--------|-------|-------------|
| 1 | **Machine Primitives Core** | 3 | Identity, Index, Handle, Bit |
| 2 | **Machine Value Primitives** | 4 | Core |
| 3 | **Machine Capture Primitives** | 10 | Core |
| 4 | **Machine Frame Primitives** | 2 | Value, Capture |
| 5 | **Machine Transform Primitives** | 3 | Value, Capture |
| 6 | **Machine Combine Primitives** | 2 | Value, Capture |
| 7 | **Machine Next Primitives** | 2 | Value, Capture |
| 8 | **Machine Finalize Primitives** | 2 | Value, Capture |
| 9 | **Machine Node Primitives** | 1 | Value, Transform, Combine, Next, Finalize |
| 10 | **Machine Program Primitives** | 2 | Node, Capture, Graph Primitives Core |
| 11 | **Machine Convenience Primitives** | 2 | Program, all carriers |
| 12 | **Machine Primitives** | 1 | Re-exports all |

**Machine Primitives Core** declares the `Machine` namespace enum, the `Machine.Index` re-export, and the common `exports.swift` with `@_exported import` of shared dependencies (Identity, Index, Handle, Bit). All other machine modules depend on Core for the namespace declaration.

**Dependency graph**:

```
          Core
        ╱      ╲
    Value    Capture
      │ ╲    ╱ │
      │  Frame │
      │        │
  ┌───┼──┬─────┼──┐
  │   │  │     │  │
 Xfm Comb Next Fin│
  │   │    │   │  │
  └───┴────┴───┘  │
        │         │
       Node       │
        │  ╲      │
        │   ╲─────┘
     Program
        │
   Convenience
```

12 modules total. Core declares the namespace. Value and Capture are independent primitives. Carriers are independent siblings. Node is their composition point.

**Value**: A consumer building a custom execution engine with different value semantics imports only `Machine Primitives Value`.

**Carriers**: A consumer building a pipeline machine (no branching, no repetition) imports only `Transform` and `Combine`, never `Next` or `Finalize`.

---

### Option C: Hybrid

Core + thematic algorithm groups, but per-primitive types for machine-primitives. This is the original proposal.

---

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Ecosystem consistency** | High | Does the module strategy match the package-level strategy? |
| **Single responsibility** | High | Does each module have exactly one reason to change? |
| **Dependency minimality** | High | Can consumers import only what they need? |
| **Future extensibility** | High | Where does a new algorithm go? Is the answer obvious? |
| **Consumer ergonomics** | Medium | Is the umbrella sufficient? Is fine-grained import discoverable? |
| **Package.swift complexity** | Low | How many targets? (One-time cost, template-based) |
| **Build time** | Low | More modules = more compilation units = better incremental builds |

---

## Comparison

| Criterion | A: Thematic (7+5) | B: Per-Primitive (17+11) | C: Hybrid |
|-----------|--------------------|--------------------------|-----------|
| **Ecosystem consistency** | Breaks convention. Packages are per-primitive, but modules are per-theme. Two modularization strategies in one ecosystem. | **Matches convention.** Same principle at both levels. DFS is a primitive like Stack is a primitive. | Mixed — one package follows convention, the other doesn't. |
| **Single responsibility** | No. "Analysis" has 5 reasons to change (one per algorithm). Adding dominator trees changes the Analysis module even though SCC is unaffected. | **Yes.** Each module has exactly one primitive. Adding dominator trees adds a new module; existing modules untouched. | Mixed. |
| **Dependency minimality** | Partial. A consumer that needs only reachability pulls in SCC, cycles, transitive closure, and dead node detection. | **Optimal.** Import only what you use. Need reachability? Import `Graph Primitives Reachable`. | Mixed. |
| **Future extensibility** | Ambiguous. Where does "dominator trees" go? Analysis? New module? Degree queries — Analysis or Core? The theme boundaries create classification debates. | **Unambiguous.** New algorithm → new module. Always. No classification debate. | Mixed. |
| **Consumer ergonomics** | Umbrella works for most. Fine-grained options limited to 5 algorithm groups. | **Umbrella works for most.** Fine-grained options are precise. A consumer knows exactly what they're importing. | Umbrella works. |
| **Package.swift complexity** | 7 + 5 = 12 targets per package | 17 + 11 = 28 targets per package | 12 targets |
| **Build time** | Moderate parallelism | **Maximum parallelism.** 14 graph algorithm modules compile in parallel (all depend only on Core). | Moderate. |

---

## Constraints

### Swift Module Extension Compatibility

Each algorithm module extends accessor structs declared in Core. Verified: Swift supports adding methods to types from other modules via extensions. This is the same mechanism used by Property.View extensions across the ecosystem.

```swift
// In Graph Primitives Core:
extension Graph.Sequential {
    public struct Analyze<Adjacent> { let graph: ...; let extract: ... }
    public func analyze<Adjacent>(using extract: ...) -> Analyze<Adjacent> { ... }
}

// In Graph Primitives Reachable (separate module):
import Graph_Primitives_Core

extension Graph.Sequential.Analyze {
    public func reachable(from root: Graph.Node<Tag>) -> Set<Graph.Node<Tag>>.Ordered { ... }
}
```

This compiles. The consumer sees `graph.analyze.reachable(from:)` regardless of which module provides the method.

### No Access Control Issues

Algorithm methods are `public` extensions on `public` types with `public` stored properties (`graph`, `extract`). The extension in a different module can access these properties. No `@usableFromInline` or `internal` access concerns.

### The 1-File Module Question

Several modules would contain a single source file. Is this too granular? No — the ecosystem already has single-file modules. The module boundary exists for dependency isolation, not file organization. A module with 1 file and clear responsibility is better than a module with 8 files and mixed responsibility.

### Accessor Namespace Declarations

The accessor namespace structs (`Traverse`, `Analyze`, `Path`, `Transform`, `Reverse`) and their accessor properties (`graph.traverse`, `graph.analyze`, etc.) MUST live in Core. Algorithm modules extend these types. This is load-bearing: without Core declaring the accessor, algorithm modules cannot extend it.

The `Traverse.First` sub-accessor also lives in Core. DFS and BFS modules extend it with `.depth(from:)` and `.breadth(from:)`.

### Iterator Types

DFS declares `Graph.Traversal.First.Depth`. BFS declares `Graph.Traversal.First.Breadth`. Topological declares `Graph.Traversal.Topological`. These are **new type declarations** in their respective modules, not extensions. The `Graph.Traversal` and `Graph.Traversal.First` namespace enums must be declared in Core to enable this nesting.

---

## Prior Art

### Within the Ecosystem

The primitives ecosystem modularizes by primitive at the package level:

| Package | Primitive |
|---------|-----------|
| swift-stack-primitives | Stack |
| swift-queue-primitives | Queue |
| swift-heap-primitives | Heap |
| swift-bit-vector-primitives | Bit Vector |
| swift-set-primitives | Set.Ordered |

These are not grouped into "swift-data-structures-primitives." Each is atomic and composable. Consumers import exactly what they need.

Within packages, the same principle appears:

| Package | Module | Primitive |
|---------|--------|-----------|
| swift-array-primitives | Array Primitives Core | ~Copyable base |
| | Array Dynamic Primitives | Dynamic array (Copyable Collection) |
| | Array Fixed Primitives | Fixed array (Copyable Collection) |
| | Array Static Primitives | Static array (copy subscript) |
| | Array Small Primitives | Small array (iterator) |
| | Array Bounded Primitives | Bounded array (modular, hash) |

Each module is one concrete capability, not a thematic group.

### External

**Rust**: The Rust ecosystem's "small crate" philosophy aligns with per-primitive. Many Rust graph libraries split algorithms into separate crates. `petgraph` is a notable exception (single crate), widely considered to have dependency bloat as a result.

**Haskell**: `containers` provides `Data.Graph` as a single module but the broader ecosystem has per-algorithm packages (`algebraic-graphs`, `fgl` with per-algorithm modules).

---

## Outcome

**Status**: DECISION

Per-primitive modularization (Option B). One module per primitive. Compose the primitives.

### Rationale

Per-primitive is superior on every high-weight criterion:

- **Ecosystem consistency**: Matches the package-level strategy. One principle, applied uniformly. DFS is a module like Stack is a package.
- **Single responsibility**: Each module IS the primitive it provides.
- **Dependency minimality**: Consumers compose exactly what they need.
- **Future extensibility**: New primitive → new module. Always obvious, no classification debates.

The cost (more targets in Package.swift) is a one-time, low-weight concern offset by better incremental build parallelism.

### Resolved Questions

**Dead composes Reachable**: `dead = allNodes - reachable`. Dead depends on `Graph Reachable Primitives` and computes the complement. The current reimplemented DFS should be replaced with a call to `reachable(from:)`. This makes Dead smaller and validates the composition principle.

**Naming convention**: `{Type} {Qualifier} Primitives` — qualifier before "Primitives." Verified against array-primitives (`Array Dynamic Primitives`), buffer-primitives (`Buffer Ring Inline Primitives`), and bit-primitives (`Bit Field Primitives`). Core modules use `{Type} Primitives Core`. Umbrellas use `{Type} Primitives`.

**Machine Capture stays as one module**: Store and Frozen are deeply coupled (Frozen is an immutable snapshot of Store). The 10 files represent one primitive with multiple facets, not 10 primitives.

**Prior thematic grouping document**: `graph-machine-modularization.md` updated to SUPERSEDED status.

### Graph Primitives — 17 Modules

| Module | Import Name | Files | Dependencies |
|--------|-------------|-------|-------------|
| Graph Primitives Core | `Graph_Primitives_Core` | 14 | Identity, Index, Array |
| Graph DFS Primitives | `Graph_DFS_Primitives` | 2 | Core + Stack, Bit Vector |
| Graph BFS Primitives | `Graph_BFS_Primitives` | 2 | Core + Queue, Bit Vector |
| Graph Topological Primitives | `Graph_Topological_Primitives` | 2 | Core + Stack, Bit Vector |
| Graph Reachable Primitives | `Graph_Reachable_Primitives` | 1 | Core + Stack, Bit Vector, Set |
| Graph Dead Primitives | `Graph_Dead_Primitives` | 1 | Core + Reachable + Set |
| Graph SCC Primitives | `Graph_SCC_Primitives` | 1 | Core + Stack, Bit Vector |
| Graph Cycles Primitives | `Graph_Cycles_Primitives` | 1 | Core + Topological |
| Graph Transitive Closure Primitives | `Graph_Transitive_Closure_Primitives` | 1 | Core + Stack, Bit Vector |
| Graph Path Exists Primitives | `Graph_Path_Exists_Primitives` | 1 | Core + Queue, Bit Vector |
| Graph Shortest Path Primitives | `Graph_Shortest_Path_Primitives` | 1 | Core + Queue, Bit Vector |
| Graph Weighted Path Primitives | `Graph_Weighted_Path_Primitives` | 1 | Core + Heap, Bit Vector |
| Graph Payload Map Primitives | `Graph_Payload_Map_Primitives` | 1 | Core |
| Graph Subgraph Primitives | `Graph_Subgraph_Primitives` | 1 | Core |
| Graph Reverse Primitives | `Graph_Reverse_Primitives` | 1 | Core |
| Graph Backward Reachable Primitives | `Graph_Backward_Reachable_Primitives` | 1 | Core + Reverse + Stack, Bit Vector, Set |
| Graph Primitives | `Graph_Primitives` | 1 | Re-exports all |

### Machine Primitives — 12 Modules

| Module | Import Name | Files | Dependencies |
|--------|-------------|-------|-------------|
| Machine Primitives Core | `Machine_Primitives_Core` | 3 | Identity, Index, Handle, Bit |
| Machine Value Primitives | `Machine_Value_Primitives` | 4 | Core |
| Machine Capture Primitives | `Machine_Capture_Primitives` | 10 | Core |
| Machine Frame Primitives | `Machine_Frame_Primitives` | 2 | Value, Capture |
| Machine Transform Primitives | `Machine_Transform_Primitives` | 3 | Value, Capture |
| Machine Combine Primitives | `Machine_Combine_Primitives` | 2 | Value, Capture |
| Machine Next Primitives | `Machine_Next_Primitives` | 2 | Value, Capture |
| Machine Finalize Primitives | `Machine_Finalize_Primitives` | 2 | Value, Capture |
| Machine Node Primitives | `Machine_Node_Primitives` | 1 | Value, Transform, Combine, Next, Finalize |
| Machine Program Primitives | `Machine_Program_Primitives` | 2 | Node, Capture, Graph Primitives Core |
| Machine Convenience Primitives | `Machine_Convenience_Primitives` | 2 | Program, all carriers |
| Machine Primitives | `Machine_Primitives` | 1 | Re-exports all |

### Parser-Machine Primitives — No Change

Keep as single module. Tightly integrated execution engine.

### Implementation Order

1. Graph Primitives Core (extract data structure + accessor namespaces)
2. Graph algorithm modules (each independent from Core, implement in any order)
3. Graph composition modules (Dead, Cycles, Backward Reachable — after their dependencies)
4. Graph Primitives umbrella
5. Machine Primitives Core (extract namespace + exports)
6. Machine Value Primitives, Machine Capture Primitives (independent, parallel)
7. Machine Frame Primitives, carrier modules (depend on Value + Capture)
8. Machine Node Primitives (composes carriers)
9. Machine Program Primitives (composes Node + Graph)
10. Machine Convenience Primitives, Machine Primitives umbrella
11. Verify parser-machine-primitives builds against umbrellas

### Collateral Changes

1. Remove unused re-exports from graph-primitives (Collection, Dictionary, Input)
2. Refactor Dead to compose Reachable (replace reimplemented DFS with `reachable(from:)` call)
3. Graph Primitives product becomes a multi-target library (umbrella)
4. Machine Primitives product becomes a multi-target library (umbrella)
5. Existing consumers unchanged — umbrella preserves import path

## References

- `graph-machine-modularization.md` — Prior thematic grouping proposal (may be superseded)
- `graph-primitives-roadmap.md` — Future additions (each would be a new per-primitive module)
- `graph-operations-audit.md` — Canonical Graph ADT coverage
- `machine-program-analysis-and-optimization.md` — Future optimization modules
- `implementation-quality-audit-graph-machine-parser.md` — Source inspection confirming no lateral dependencies
- [RES-004] — Investigation methodology
- [RES-010b] — Architecture analysis template
- swift-array-primitives — Per-primitive module split reference implementation
