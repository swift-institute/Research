# swift-user-interface — Graph Transactions

<!--
---
version: 1.1.0
last_updated: 2026-04-21
status: RECOMMENDATION
changelog:
  - 1.0.0 (2026-04-21): Initial — recommended separate L1 package swift-attribute-graph-primitives
  - 1.1.0 (2026-04-21): REVERSED placement decision. Target-split inside swift-graph-primitives, not a new package. Dependency criterion favors in-package targets
tier: 2
scope: cross-package
---
-->

## Context

Follow-up to `danceui-architectural-analysis.md`. DanceUI (and SwiftUI, and
anything attribute-graph-shaped) needs a mutation/transaction discipline on
top of a graph: mutations batched into transactions, transactions carrying a
version seed, downstream payloads lazy-recomputed on read, merged phases
composing in-flight transactions. DanceUI externalizes this as `DanceUIGraph`
(separate repo) exposing `_Graph`, `_GraphValue<T>`, `GraphInput`,
`GraphMutation`, `AsyncTransaction`, `VersionSeed`, `GraphHost`,
`CachedEnvironment`, `MergedEnvironment`, `MergedPhase`, `MergedTransaction`.

The prior analysis claimed this is expressible on top of our existing
`swift-graph-primitives`. That claim needed verification before a UI
framework is built on top of it.

## Question

Does `swift-graph-primitives` already support attribute-graph
transaction/phase semantics? If not, does the gap belong inside the package
(as new sub-targets) or as a separate L1 package?

## Analysis

### What `swift-graph-primitives` models today

Surveyed across `Sources/Graph Primitives Core/`, `Graph Primitives/`,
`Graph Namespace/`, and the thirteen algorithmic sub-targets (BFS, DFS,
SCC, Topological, Cycles, Reachable, Backward Reachable, Dead, Transitive
Closure, Shortest Path, Weighted Path, Path Exists, Reverse, Payload Map,
Subgraph).

Core types:

| Type                                                      | Role                                             |
|-----------------------------------------------------------|--------------------------------------------------|
| `Graph.Namespace`                                         | Root enum container                              |
| `Graph.Node<Tag>`                                         | Phantom-typed node identity                      |
| `Graph.Index<Tag>`                                        | Typed index for node positions                   |
| `Graph.Sequential<Tag, Payload>`                          | Immutable graph, sequentially-allocated storage  |
| `Graph.Sequential.Builder: ~Copyable`                     | Construction-phase API; `consuming build()`      |
| `Graph.Adjacency.List<Tag>`                               | Edge list payload                                |
| `Graph.Adjacency.Extract<Payload, Tag, Adjacent>`         | Witness extracting adjacency from payload        |
| `Graph.Remappable.Remap<Payload, Tag, Adjacent>`          | Witness extracting + remapping node refs         |
| `Graph.Payload.Map` in `Graph Payload Map Primitives`     | Transformation over a fixed snapshot             |

Promise: **compile-safe traversal and analysis over an immutable adjacency
structure**. Every algorithmic sub-target is a one-shot analysis; `Builder`
is a construction-only tool that consumes itself into an immutable graph.

### Mutation / transaction discipline: absent

- `Graph.Sequential` is immutable after construction (struct, no mutating
  methods beyond the builder).
- `Graph.Sequential.Builder.build()` is `consuming`; there is no API to
  edit after build.
- No edge-insertion-under-recomputation, no mutation batching, no phase,
  no transaction, no abort/retry.
- Traversals consume a fixed snapshot, not an in-flight mutation stream.

### Lazy payload recomputation: absent

`Graph.Payload.Map` transforms eagerly from `Graph.Sequential<Tag, A>` to
`Graph.Sequential<Tag, B>`. There is no notion of "if an upstream payload
changes, this payload recomputes." `Graph.Default.Value<Payload>` is a
hole-filling witness during build, not a reactive rule.

### Version / epoch concept: absent

No `VersionSeed`, no per-node version tracking, no staleness detection.

### What would be needed

| Piece                                  | Shape                                                                       |
|----------------------------------------|-----------------------------------------------------------------------------|
| Transaction container                   | Batches mutations between checkpoints; carries a version seed              |
| Mutable graph under transaction         | Edge insertion/deletion within a transaction scope; dirty-set tracking     |
| Lazy payload-recompute rule             | Closure keyed by node with explicit upstream dependencies; cache-until-dirty |
| Per-node version tracking               | Sparse bitset or array; incremented on payload change                       |
| Invalidation propagation                | Mark-dirty via transitive downstream; topological update order              |
| Commit semantics                        | Atomic apply; recompute in topological order; consistent snapshot on read   |

### Placement: target-split inside `swift-graph-primitives`

The ecosystem's modularization unit is the **target**, not the package.
`swift-graph-primitives` already uses fine-grained targets (one per
algorithm family: BFS, DFS, SCC, Topological, Reachable, Weighted Path,
Payload Map, Transitive Closure, …) each shipped as its own library
product. Adding reactive-runtime targets alongside the algorithmic ones
is the natural fit — a consumer that only needs topological sort imports
`Graph Topological Primitives` and pays nothing for transactions.

The deciding criterion is **dependency delta**: if reactive-runtime
targets need deps that `swift-graph-primitives` does not already carry,
a separate package is justified. Otherwise, target-split is strictly
lighter.

### Current `swift-graph-primitives` external deps

From `swift-graph-primitives/Package.swift` lines 93–103:

```
swift-tagged-primitives, swift-bit-primitives, swift-stack-primitives,
swift-set-primitives, swift-heap-primitives, swift-index-primitives,
swift-array-primitives, swift-queue-primitives, swift-bit-vector-primitives,
swift-sequence-primitives
```

### What reactive targets would add

| Target                                   | Additional deps                              |
|------------------------------------------|----------------------------------------------|
| `Graph Attribute Primitives Core`        | none (just Version seed)                     |
| `Graph Transaction Primitives`           | none (uses existing set / queue primitives)  |
| `Graph Rule Primitives`                  | maybe `swift-cache-primitives` (memoization) |
| `Graph Invalidation Primitives`          | none (uses reverse + transitive closure)     |

At most **one** new package-level dep (`swift-cache-primitives`), and only
if rule memoization lives at L1. Scheduling concerns (a `Driver.Loop`)
live in the *consumer*, not the primitive — a UI framework composes the
primitive's transactional types with a scheduler from elsewhere. This
removes the earlier motivation for `swift-driver-primitives` as a graph
dependency.

### Option A — target-split inside `swift-graph-primitives`

New targets alongside existing algorithm targets:

- `Graph Attribute Primitives` (umbrella)
- `Graph Attribute Primitives Core` (Version, core types)
- `Graph Transaction Primitives` (Transaction, Phase, Merge)
- `Graph Rule Primitives` (lazy recompute witness)
- `Graph Invalidation Primitives` (dirty set, propagation)

Pros: matches the existing one-concept-per-target granularity; consumers
of structural graph algorithms pay nothing; single repo to evolve the
primitive surface; no cross-package dependency plumbing. The only
package-level dep shift is a possible addition of
`swift-cache-primitives`, and even that is not guaranteed.

Cons: the `swift-graph-primitives` repository grows a new *conceptual*
area (reactive runtime) alongside its existing (pure graph algorithms)
area. Mitigated by target-level isolation — no cross-contamination of
APIs.

### Option B — separate L1 `swift-attribute-graph-primitives`

Pros: conceptually clean separation; mirrors DanceUI's separate
`DanceUIGraph` repo.

Cons: by the dependency criterion, it is not justified. Conceptual
separation is already achieved by target isolation. Extra package churn
for zero dependency benefit.

### Comparison

| Criterion                          | Option A (target-split)   | Option B (new L1)       |
|------------------------------------|---------------------------|-------------------------|
| New package-level deps              | 0–1 (cache-primitives)    | 2+ (graph + maybe cache) |
| Graph-only consumer cost            | Zero (target isolation)   | Zero                     |
| Package proliferation                | No                        | Yes                      |
| Matches ecosystem granularity        | Yes (one-per-target)      | No                       |
| Single repo to evolve primitive      | Yes                        | No                       |
| Conceptual separation                | At target level           | At package level         |

## Outcome

**Status**: RECOMMENDATION. Research-only; no edits to
`swift-graph-primitives` are made by this document.

**Decision**: when the time comes to implement, add reactive-runtime
**targets inside `swift-graph-primitives`** rather than creating a new
package. Dependency delta is at most one additional package-level dep
(`swift-cache-primitives`), and even that is avoidable.

### Proposed target shape (inside existing `swift-graph-primitives`)

```
swift-graph-primitives/Sources/
    ├── Graph Namespace/                     (existing)
    ├── Graph Primitives Core/               (existing)
    ├── Graph Primitives/                    (existing umbrella)
    ├── Graph BFS Primitives/                (existing)
    ├── Graph DFS Primitives/                (existing)
    ├── ...                                   (existing algorithm targets)
    ├── Graph Attribute Primitives/          (NEW — umbrella)
    ├── Graph Attribute Primitives Core/     (NEW — Version, core types)
    ├── Graph Transaction Primitives/        (NEW — Transaction, Phase, Merge)
    ├── Graph Rule Primitives/               (NEW — lazy recompute witness)
    └── Graph Invalidation Primitives/       (NEW — dirty set + propagation)
```

Key types (naming follows Nest.Name):

| Type                                      | Target                                 |
|-------------------------------------------|----------------------------------------|
| `Graph.Attribute.Version`                 | Graph Attribute Primitives Core         |
| `Graph.Attribute.Transaction<Tag>`        | Graph Transaction Primitives            |
| `Graph.Attribute.Phase<Tag>`              | Graph Transaction Primitives            |
| `Graph.Attribute.Rule<Tag, Payload>`      | Graph Rule Primitives                   |
| `Graph.Attribute.Transactional<Tag, Payload>` | Graph Transaction Primitives        |
| `Graph.Attribute.Invalidation<Tag>`       | Graph Invalidation Primitives           |

Consumer imports:
- Consumers that only want structural graph algorithms import e.g.
  `Graph Topological Primitives` unchanged.
- Consumers that want reactive runtime import `Graph Attribute Primitives`
  (umbrella) or a specific sub-target.
- `swift-user-interface` imports both kinds on a per-use basis.

### Scheduling lives in the consumer

A scheduler / update loop that drives transactions-on-commit is **not**
part of this primitive surface. The primitive exposes types
(`Transaction`, `Phase`, `Rule`, `Invalidation`) and pure operations
(commit in topological order, propagate invalidation). A UI framework
composes these with its own driver / effect runtime. This is why no
`swift-driver-primitives` dependency is introduced at the primitive
layer.

### Next actions (when implementation is authorized)

1. Write a short experiment in `swift-primitives/Experiments/` standing
   up a minimum-viable reactive graph using the proposed types plus the
   existing `Graph Topological Primitives` to verify commit-order
   computation works without new machinery.
2. Decide whether rule memoization lives at L1 (pull in
   `swift-cache-primitives`) or at the consumer (no new dep).
3. Add the five new targets to `swift-graph-primitives/Package.swift`.

None of these happen until the user authorizes touching the package.

## References

- `/Users/coen/Developer/swift-primitives/swift-graph-primitives/Sources/` — actual surface
- `/Users/coen/Developer/bytedance/DanceUI/Sources/DanceUI/Internal/Graph/` — DanceUI transaction machinery
- `danceui-architectural-analysis.md` — parent research
- Swift Institute primitive decomposition pattern (`swift-state-primitives`
  vs `swift-property-primitives`) — cited as precedent for the split
