# Machine.Program → Graph.Sequential Migration

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: DECISION
tier: 2
scope: machine-primitives, binary-parser-primitives, parser-machine-primitives
---
-->

## Context

`Machine.Program` stores a dense array of `Node` values referenced by ID, forming a directed graph (DAG for most combinators, cyclic for recursive grammars via `.ref`). Before this migration, the storage was a plain `[Node]` with `Int`-tagged IDs:

```swift
// Before
public struct Program<Leaf, Failure: Error, Mode> {
    public let nodes: [Node<Leaf, Failure, Mode>]
    subscript(id: Node.ID) -> Node { nodes[id.rawValue] }  // rawValue: Int
}
```

This representation worked but created three problems:

1. **Duplicated graph infrastructure** — Traversal, reachability, cycle detection, topological ordering, SCC, and dead code analysis all apply to parser programs but had to be reimplemented or were simply unavailable.
2. **Untyped IDs** — `Node.ID = Tagged<Self, Int>` used `Int` as the raw value, leaking `rawValue` extraction into call sites for ID arithmetic, bounds checking, and cross-type conversions.
3. **No structural analysis** — Without adjacency extraction, the program was opaque to generic graph algorithms.

Meanwhile, `swift-graph-primitives` provides `Graph.Sequential<Tag, Payload>` — an immutable dense directed graph with `Ordinal`-backed node IDs, a `~Copyable` builder, and composable analysis algorithms. Machine.Program IS a sequential graph. The relationship is essential, not incidental.

## Decision

Replace `[Node]` storage with `Graph.Sequential<Node, Node>` and change `Node.ID` from `Tagged<Self, Int>` to `Graph.Node<Self>` (= `Index<Self>` = `Tagged<Self, Ordinal>`).

### Changes by Package

**machine-primitives** (4 files):
- `Machine.Node.swift` — `ID = Graph.Node<Self>`, added `adjacent` property and `extract` for graph algorithms
- `Machine.Program.swift` — `graph: Graph.Sequential<Node, Node>`, added `analyze` accessor, `Sendable` constraints
- `Machine.Program.Builder.swift` — Wraps `Graph.Sequential.Builder`, `~Copyable`, subscript for hole patching
- `Package.swift` — Added `swift-graph-primitives` dependency

**binary-parser-primitives** (2 files):
- `Binary.Bytes.Machine.Builder.swift` — `~Copyable`, `embed()` uses typed ordinal arithmetic (`root + offset`)
- `Binary.Bytes.Machine.Build.swift` — Hole patching via subscript

**parser-machine-primitives** (8 files):
- `Parser.Machine.Failure.swift` — `Recovery.ID = Tagged<Tag, Ordinal>`
- `Parser.Machine.Frame.swift` — `memoization(node: Ordinal, ...)`
- `Parser.Machine.Memoization.Key.swift` — `node: Ordinal`
- `Parser.Machine.Run.swift` — `.retag()` pattern replaces `rawValue` round-trips (~8 sites)
- `Parser.Machine.Run.Memoization.swift` — Same `.retag()` pattern (~6 sites)
- `Parser.Machine.Combinators.swift` — Removed `flatMap` `rawValue` leak
- `Parser.Machine.Recursive.swift` — Hole patching via `builder.inner[holeID]`
- `Parser.Machine.swift` — `Builder: ~Copyable`

## What This Enables

### Available Now

**Graph analysis on parser programs** — via `program.analyze`:

| Algorithm | Use Case |
|-----------|----------|
| **Reachability** | From any root, which nodes are reachable? Identifies live program fragments. |
| **Dead node detection** | Nodes unreachable from the root — dead code in the parser program. |
| **Cycle detection** | Does the program contain cycles? (Yes, via `.ref` for recursive grammars.) |
| **Strongly connected components** | Which nodes form mutual recursion groups? |
| **Topological ordering** | Execution ordering for non-recursive programs. |
| **Transitive closure** | Full reachability matrix — which node can eventually reach which? |
| **Shortest path** | Minimum combinator depth between two nodes. |
| **Subgraph extraction** | Extract a sub-program rooted at a specific node. |
| **Reverse graph** | Backward reachability — which nodes lead TO a given node? |

All algorithms compose with the `Graph.Adjacency.Extract` closure provided by `Node.extract`, which extracts structurally adjacent IDs from each node variant. Dynamic edges (`.flatMap`'s closure-based `next`) are not included — these are runtime-determined and opaque to static analysis.

**Typed ID arithmetic** — zero `rawValue` extraction at call sites:

| Before | After |
|--------|-------|
| `Node.ID(recovered.rawValue)` | `recovered.retag(Node.self)` |
| `Recovery.ID(alternatives[index].rawValue)` | `alternatives[index].retag(Recovery.Tag.self)` |
| `Node.ID(__unchecked: (), next(output).node.rawValue)` | `next(output).node` |
| `current.rawValue >= 0 && current.rawValue < program.nodes.count` | `current < program.graph.count` |
| `builder.inner.nodes[holeID.rawValue] = .ref(root.node)` | `builder.inner[holeID] = .ref(root.node)` |
| `let offset = inner.nodes.count; ... Node.ID(__unchecked: (), root.rawValue + offset)` | `let offset = inner.count; ... root + offset` |

### Enabled for Future Work

**Program optimization passes** — graph analysis enables transformation:

- **Dead node elimination**: `program.analyze.dead(from: [root])` identifies unreachable nodes. A subgraph pass can strip them, producing a smaller program.
- **Common subexpression elimination**: If two subtrees are structurally identical (same node types, same adjacency), they can be merged. Graph comparison algorithms support this.
- **Recursion depth analysis**: SCC analysis identifies mutual recursion groups. Combined with `.ref` cycle detection, this enables static verification of `maxDepth` bounds.
- **Incremental recompilation**: When a parser combinator changes, backward reachability identifies which nodes are affected, enabling targeted recompilation rather than full rebuild.

**Program visualization** — the graph structure is directly renderable:

- DOT/Graphviz export for debugging
- Node-level profiling overlays (execution count, time per node)
- Interactive program exploration during development

**Cross-program analysis** — `embed()` in binary-parser composes programs. Graph analysis enables:

- Verifying no dangling references after embedding
- Computing the combined program's reachability from the adjusted root
- Detecting conflicts between embedded sub-programs

## Design Notes

### Sendable Constraints

`Graph.Sequential<Tag, Payload>` requires `Payload: Sendable`. This propagated `Sendable` constraints to `Program`'s generic parameters (`Leaf: Sendable`, `Failure: Error & Sendable`, `Mode: Sendable`). All existing consumers already required these constraints — binary-parser uses `Mode.Reference` (Sendable), parser-machine requires `Failure: Error & Sendable`. Source-compatible.

The one casualty was `Mode.Unchecked` convenience extensions in `Machine.Builder+Carriers.swift`. `Mode.Unchecked` is intentionally NOT Sendable. No downstream consumers use Unchecked mode — the extensions were dead code and were removed.

### ~Copyable Propagation

`Graph.Sequential.Builder` is `~Copyable` (consuming `build()`). This made `Machine.Builder` `~Copyable`, which propagated to `Binary.Bytes.Machine.Builder` and `Parser.Machine.Builder`. All consumers already used `var` with `inout` passing — no behavioral change.

### Adjacency Extraction

`Node.extract` is a static property returning `Graph.Adjacency.Extract<Self, Self, [ID]>`. It extracts structurally visible edges:

- `.leaf`, `.pure`, `.hole` → `[]`
- `.map(child, _)`, `.tryMap(child, _)`, `.flatMap(child, _)` → `[child]`
- `.sequence(a, b, _)` → `[a, b]`
- `.oneOf(ids)` → `ids`
- `.many(child, _)`, `.fold(child, _, _)`, `.optional(child, _, _)` → `[child]`
- `.ref(id)` → `[id]`

`.flatMap`'s dynamic `next` closure is opaque — it returns a `Node.ID` at runtime based on the parsed output. Static analysis sees only the child edge, not the dynamically-selected continuation. This is a fundamental limitation of defunctionalized programs with runtime dispatch, not a gap in the extraction.

## Tier Impact

| Package | Before | After |
|---------|--------|-------|
| machine-primitives | Tier 11 | Tier 18 (depends on graph-primitives) |
| binary-parser-primitives | Tier 15 | Tier 19 |
| parser-machine-primitives | Tier 16 | Tier 19 |

## References

- `swift-graph-primitives/` — `Graph.Sequential`, `Graph.Node`, `Graph.Adjacency.Extract`, analysis algorithms
- `Analysis - Closure-Free Parser Combinators.md` — foundational analysis of the defunctionalized Machine architecture
- [INFRA-102] Ordinal positions — typed `<` comparison between ordinal and cardinal
- [INFRA-103] Tagged functors — `.retag()` for zero-cost cross-domain ID conversion
- [IMPL-INTENT] Code reads as intent — elimination of `rawValue` mechanism at call sites
