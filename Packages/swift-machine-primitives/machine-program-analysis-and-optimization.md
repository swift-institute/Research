# Machine Program Analysis and Optimization

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: RECOMMENDATION
tier: 2
scope: machine-primitives, graph-primitives, parser-machine-primitives
---
-->

## Context

The `Machine.Program → Graph.Sequential` migration (2026-02-23) replaced opaque `[Node]` storage with `Graph.Sequential<Node, Node>`, making parser programs inspectable directed graphs. The program's `analyze` accessor now provides forward/backward reachability, dead node detection, cycle detection, strongly connected components, topological ordering, transitive closure, shortest paths, and subgraph extraction — all via `Graph.Adjacency.Extract` on `Machine.Node`.

This document maps the analysis capabilities now available, identifies optimization passes enabled by the graph substrate, catalogs debugging and visualization opportunities, and consolidates open design questions from the closure-free parser combinators analysis and its companion notes.

Builds on:
- `machine-program-graph-sequential-migration.md` — migration rationale and what it enables
- `Analysis - Closure-Free Parser Combinators.md` — defunctionalized architecture analysis
- `Companion - Analysis Notes and Refinements.md` — error recovery and borrowed output design space

---

## Available Now — Analysis Capabilities

All analysis is accessed via `program.analyze`, which delegates to `program.graph.analyze(using: Node.extract)`. The `Node.extract` witness extracts structurally visible edges from each node variant. Dynamic edges (`.flatMap`'s runtime `next` closure) are opaque to static analysis.

### Reachability — Live Fragment Extraction

```swift
let live = program.analyze.reachable(from: rootID)
// live: Set<Node.ID>.Ordered — all nodes reachable from root
```

**Use case**: Given a program built from multiple combinators, determine which nodes actually participate in parsing from a given entry point. Nodes outside the reachable set are dead code.

**Limitation**: `.flatMap` targets are determined at runtime. A node reachable only via dynamic dispatch appears unreachable to static analysis. Conservative analysis should treat all `.flatMap` children as live.

### Dead Node Detection — Program Size Reduction

```swift
let dead = program.analyze.dead(from: [rootID])
// dead: Set<Node.ID>.Ordered — nodes unreachable from root
```

**Use case**: After program composition (e.g., `embed()` in binary-parser), some nodes may become unreachable. Dead node detection identifies them. Combined with `transform.subgraph()`, dead nodes can be stripped to produce a smaller program.

### Cycle Detection — Recursion Validation

```swift
let hasCycles = program.analyze.hasCycles(from: rootID)
// true if program contains recursive references (.ref nodes forming cycles)
```

**Use case**: Validate whether a program requires the recursive execution machinery (depth tracking, memoization). Non-recursive programs can use a simpler execution path without stack depth checking or memoization overhead.

### Strongly Connected Components — Mutual Recursion Groups

```swift
let components = program.analyze.scc(from: rootID)
// [[Node.ID]] — components in reverse topological order (sinks first)
```

**Use case**: Identify mutual recursion groups. Each SCC with more than one node represents mutually recursive combinators (e.g., `expr` ↔ `term` ↔ `factor`). This information enables:
- Per-group memoization strategies (shared memo tables within an SCC)
- Recursion depth analysis scoped to each group
- Targeted optimization within recursion boundaries

### Topological Ordering — Dependency-Ordered Processing

```swift
let ordered = program.graph.traverse.topological(from: rootID, using: Node.extract)
for (node, payload) in ordered {
    // Process nodes in dependency order (dependencies before dependents)
}
```

**Use case**: Process non-recursive programs in dependency order. Enables bottom-up analysis where each node's children are processed before the node itself. Required for:
- Bottom-up type inference
- Cost estimation (sum child costs)
- Lookahead computation (compose child lookahead sets)

**Limitation**: Undefined for cyclic programs. The `hasCycles` property on the result indicates whether the ordering is valid.

### Transitive Closure — Full Reachability Matrix

```swift
let closure = program.analyze.transitiveClosure()
// Graph.Sequential<Node, Adjacency.List> — edge (u,v) iff v reachable from u
```

**Use case**: Precompute "can node A eventually reach node B?" for O(1) lookup. Useful for:
- Determining whether two sub-parsers can interact
- Validating that error recovery points are reachable from failure sites
- Computing influence sets for incremental recompilation

**Cost**: O(V·(V+E)) construction, O(V²) space. Appropriate for small-to-medium programs. For large programs, on-demand reachability queries are more efficient.

### Reverse Graph — Backward Analysis

```swift
let predecessors = program.graph.reverse(using: Node.extract).reachable(to: targetID)
// Set<Node.ID>.Ordered — all nodes that can reach targetID
```

**Use case**: "What depends on this node?" Backward reachability answers:
- If node N changes, which ancestors are affected? (incremental recompilation)
- Which entry points can reach a given leaf? (coverage analysis)
- What combinators contribute to a given parse result? (debugging)

### Subgraph Extraction — Sub-Program Isolation

```swift
let keep: Set<Node.ID>.Ordered = program.analyze.reachable(from: subtreeRoot)
let subprogram = program.graph.transform.subgraph(inducedBy: keep, using: Node.remap)
// Extracted sub-program with compacted node IDs
```

**Use case**: Extract a self-contained sub-program rooted at a specific node. The extracted graph has fresh node IDs (compacted to 0..<count). Enables:
- Testing individual combinators in isolation
- Sharing common sub-parsers across programs
- Size measurement of specific program regions

---

## Optimization Passes — Enabled by Graph Structure

### Dead Node Elimination

**Graph algorithm**: `analyze.dead(from: [root])` + `transform.subgraph()`

**Effect**: Strip unreachable nodes, producing a smaller program with compacted IDs.

**Complexity**: O(V+E) for dead detection + O(V+E) for subgraph extraction = O(V+E) total.

**Implementation path**: Compose existing algorithms. No new graph-primitives code required.

```swift
let live = program.analyze.reachable(from: [rootID])
let optimized = program.graph.transform.subgraph(inducedBy: live, using: Node.remap)
```

**When valuable**: After `embed()` composition where multiple programs are merged and some branches become unreachable from the new root.

### Linear Chain Fusion

**Graph algorithm**: Custom traversal — detect chains where a node has exactly one predecessor and exactly one successor.

**Effect**: Reduce interpreter dispatch overhead by fusing chains of single-path nodes. A→B→C becomes A→C with combined operation.

**Complexity**: O(V+E) for chain detection. Requires in-degree computation (reverse graph or degree query).

**Implementation path**: Requires degree queries from graph-primitives (currently missing — priority #1 in graph-primitives roadmap). Then:
1. Compute in-degree for all nodes
2. Identify interior chain nodes: `inDegree(n) == 1 && outDegree(n) == 1`
3. Walk chains to find endpoints
4. Fuse using a payload combiner: `(Node, Node) -> Node`

**Fusable node patterns**:
- `.map(child, t1)` → `.map(child, t2)` → fuse to `.map(child, compose(t1, t2))`
- `.pure(v)` → `.map(_, t)` → fuse to `.pure(t(v))`
- Chains of single-child nodes with no branching

**When valuable**: Programs generated from deeply nested combinator expressions that produce long linear chains.

### Common Subexpression Elimination (CSE)

**Graph algorithm**: Structural subtree comparison (requires graph equality from graph-primitives).

**Effect**: Deduplicate identical sub-parsers. If two subtrees are structurally identical (same node variants, same adjacency, equal captures), merge them into one.

**Complexity**: O(V) with Merkle hashing, O(V²) worst case with pairwise comparison.

**Implementation path**: Requires structural hashing/equality from graph-primitives (priority #3 in graph-primitives roadmap). Then:
1. Compute structural hash bottom-up (leaves first, via topological order)
2. Group nodes by hash
3. For each collision group, verify structural equality
4. Rewrite parent references to point to canonical representative
5. Strip now-dead duplicates via dead node elimination

**Complication**: `Machine.Node` contains type-erased operations (`Transform.Erased`, `Combine.Erased`, `Next.Erased`) with `RawID` references into the capture store. Two structurally identical subtrees may have different capture IDs pointing to the same captured function. CSE must compare capture equality, which requires either:
- Capture deduplication (normalize capture IDs during build)
- Capture-aware equality (compare captured values, not IDs)

**When valuable**: Parsers that repeat the same sub-pattern (e.g., parsing the same delimiter, whitespace, or keyword in multiple places).

### Lookahead Analysis

**Graph algorithm**: Static per-node analysis: can this node fail without consuming input?

**Effect**: Enable predictive parsing. If the lookahead set for each alternative in `.oneOf` is disjoint, the parser can select the correct branch without backtracking — eliminating checkpoint save/restore overhead.

**Complexity**: O(V+E) for nullability and FIRST set computation.

**Implementation path**: This is a domain-specific analysis on `Machine.Node`, not a generic graph algorithm. It requires:
1. **Nullability**: Can this node succeed consuming zero input? (`.pure` → yes, `.optional` → yes, `.many` → yes, `.leaf` → depends on leaf semantics)
2. **FIRST sets**: What input prefixes can this node match? (requires leaf-level introspection)
3. **Conflict detection**: For each `.oneOf`, check if FIRST sets of alternatives overlap

**Limitation**: Requires knowledge of `Leaf` semantics. Graph-primitives provides the traversal infrastructure; the analysis logic belongs in machine-primitives or parser-machine-primitives.

**When valuable**: `.oneOf` with many alternatives (e.g., keyword dispatch, binary format tag parsing). Converts O(n) backtracking to O(1) dispatch.

### Recursion Depth Bounds

**Graph algorithm**: SCC analysis + maximum nesting within each SCC.

**Effect**: Static verification of `maxDepth`. If the maximum recursion depth can be bounded statically, the runtime depth check (`maxDepth` guard in the run loop) can be replaced with a compile-time proof — eliminating per-`.ref` branching overhead.

**Complexity**: O(V+E) for SCC + O(V+E) for nesting analysis.

**Implementation path**:
1. Compute SCCs via `program.analyze.scc()`
2. For each SCC, compute the maximum number of `.ref` edges on any cycle within the component
3. If all SCCs have bounded cycle lengths and the input is finite, `maxDepth` is statically bounded
4. Annotate the program with the bound, or emit a proof that the runtime check is unnecessary

**Limitation**: Programs with `.flatMap` may have unbounded recursion depth if the dynamic `next` function can re-enter the same SCC. Conservative analysis must treat `.flatMap` as potentially unbounded.

**When valuable**: Recursive descent parsers where the grammar's recursion depth is structurally bounded (e.g., arithmetic expressions with finite nesting).

---

## Debugging and Visualization

### DOT Export

**Implementation path**: Generic DOT export belongs in graph-primitives (priority #2 in graph-primitives roadmap). Machine-primitives provides a domain-specific label function:

```swift
// In graph-primitives (generic)
let dot = program.graph.export.dot(label: { node in
    // Machine-specific labeling
    switch node {
    case .leaf(let leaf): return "leaf: \(leaf)"
    case .pure: return "pure"
    case .map(let child, _): return "map → \(child)"
    case .sequence(let a, let b, _): return "seq(\(a), \(b))"
    case .oneOf(let ids): return "oneOf[\(ids.count)]"
    case .many: return "many"
    case .fold: return "fold"
    case .optional: return "optional"
    case .ref(let id): return "ref → \(id)"
    case .flatMap: return "flatMap"
    case .tryMap: return "tryMap"
    case .hole: return "HOLE"
    }
})
```

**Output**: Standard DOT text renderable by Graphviz, OmniGraffle, or any DOT-compatible tool.

**Value**: Immediate visual debugging of parser programs. "Why does my parser fail?" becomes "look at the graph."

### Execution Profiling Overlay

**Implementation path**: Instrument the run loop in `parser-machine-primitives` to record per-node hit counts and timing. Annotate graph nodes with profiling data. Render as colored DOT (hot nodes in red, cold in blue).

**Requirements**:
- Per-node counters: `[Node.ID: UInt64]` for hit count
- Per-node timing: `[Node.ID: Duration]` for cumulative time
- Overlay onto DOT export via node attributes (`color`, `fillcolor`, `label` annotation)

**When valuable**: Performance debugging. "Which combinator is slowest?" becomes visible.

### Program Diff

**Implementation path**: Requires graph diff from graph-primitives (priority #6 in graph-primitives roadmap).

**Use case**: Compare two versions of a parser program to identify what changed. Enables:
- Incremental recompilation: only re-analyze changed nodes and their dependents
- Regression diagnostics: "version N is slower because these 3 nodes changed"
- Development workflow: visualize the effect of a combinator change

### Interactive Explorer

**Implementation path**: Future — render graph in a development UI. Layer 4 (Components) or Layer 5 (Applications) concern.

**Sketch**: Web-based or SwiftUI graph renderer that displays the program, supports node selection, shows payload details, and highlights paths/reachability interactively.

**Status**: Not appropriate for primitives layer. Documented here as a consumer use case that motivates the primitives-layer capabilities (DOT export, analysis algorithms).

---

## Open Design Questions

These are the two primary gaps identified in the closure-free parser combinators analysis and its companion notes. Both are unresolved and affect the machine architecture at a fundamental level.

### 1. Error Recovery

**Source**: `Analysis - Closure-Free Parser Combinators.md` §8.1, `Companion - Analysis Notes and Refinements.md` §6.

**The gap**: Error recovery is the primary capability difference between this architecture and mature parser combinator libraries (Megaparsec, Chumsky). Without error recovery, the parser stops at the first failure. Production parsers need to:
- **Synchronize**: Skip to a known-good position after failure (e.g., skip to next semicolon, next closing brace)
- **Accumulate multiple errors**: Report all errors in a file, not just the first
- **Label expectations**: "Expected 'if' keyword" rather than "match failed at byte 42"
- **Commit/cut**: After consuming input past a decision point, prevent backtracking (improves error messages and performance)

**How this manifests in the machine**:

Three design paths, not yet chosen:

**Path A — New `Machine.Node` variants**:
- `.synchronize(child: ID, synchronizeTo: Leaf, fallback: ID)` — on child failure, skip input until `synchronizeTo` matches, then continue at `fallback`
- `.label(child: ID, expectation: String)` — annotate child with human-readable expectation
- `.commit(child: ID)` — after child succeeds and consumes input, prevent backtracking past this point

Pros: Error recovery is explicit in the graph, visible to analysis, optimizable.
Cons: Increases node variant count. Every graph algorithm must handle new variants.

**Path B — New `Machine.Frame` variants**:
- Error recovery as runtime frame types rather than graph nodes
- `.recovery(synchronizeTo: Leaf, fallback: ID)` pushed onto the frame stack when entering a recovery region
- Graph structure unchanged; recovery is purely a runtime concern

Pros: Graph algorithms unaffected. Simpler node type.
Cons: Recovery invisible to static analysis. Cannot optimize recovery paths.

**Path C — Graph transformation**:
- Error recovery as a graph-to-graph transformation applied after the base program is built
- A "recovery pass" inserts synchronization nodes at strategic points (statement boundaries, block boundaries)
- The base program remains simple; recovery is layered on

Pros: Clean separation. Base program is analyzable; recovery is a well-defined transformation.
Cons: Requires the transformation to understand grammar structure (where are "statement boundaries"?). May need user annotation.

**Recommendation from companion notes**: Path A or C. Path B hides recovery from analysis, which undermines the inspectability advantage of the graph architecture.

**Status**: Unresolved. Requires dedicated investigation research before implementation.

### 2. Borrowed Output Discipline

**Source**: `Companion - Analysis Notes and Refinements.md` §10.

**The gap**: How do borrowed slices (zero-copy references into the input) flow through the machine as parse results? When a leaf parser matches bytes, the result should ideally be a slice of the input — not a copy. But borrowed values cannot be stored in `Machine.Value` (which is heap-allocated and `Sendable`).

**Three resolution strategies** identified in the companion analysis:

**Strategy A — Copy at leaf**:
Every leaf parser copies matched bytes into owned storage. Simple, correct, but defeats zero-copy parsing.

**Strategy B — Stratified Value types**:
Two value types: `Value.Owned` (heap, `Sendable`, current design) and `Value.Borrowed` (stack, non-escaping, lifetime-scoped to input). Transforms must handle both. Complex type-level machinery.

**Strategy C — Input-relative handles** (recommended):
Parse results store `(offset: Int, length: Int)` relative to the input buffer. Handles are plain integers — `Sendable`, copyable, storable in `Machine.Value`. Actual byte access requires the input at the use site. Similar to tree-sitter's approach.

**Interactions**:
- **Memoization**: Cached values must outlive the current parse position. Handles (Strategy C) are position-independent and safe to cache. Borrowed slices (Strategy B) would require lifetime tracking in the memo table.
- **`~Escapable`**: Strategy B interacts deeply with `~Escapable` types — borrowed values cannot escape the parse scope. Strategy C sidesteps this entirely.
- **Arena**: Current `Machine.Value.Arena` stores owned values. Strategy C stores handles (integers); no arena change needed. Strategy B would require a parallel borrowed-value arena with lifetime tracking.

**Recommendation from companion notes**: Strategy C (input-relative handles). Simplest, most compatible with existing architecture, no `~Escapable` complications.

**Status**: Unresolved. Recommended strategy (input-relative handles) not yet designed as concrete `Machine.Node` or `Machine.Value` types.

---

## Execution Model Improvements

These are runtime optimizations to the interpreter, orthogonal to graph-level analysis.

### Threaded Interpretation

**Current**: Switch-based dispatch in the run loop. Each node is dispatched via `switch node { case .leaf: ... case .map: ... }`.

**Improvement**: Replace switch dispatch with computed goto or direct threading, where each node handler ends with a jump to the next handler. Eliminates the central dispatch overhead.

**Swift limitation**: Swift does not expose computed goto. However, `withUnsafePointer`-based function table dispatch is possible:
- Build a function pointer table `[Node.ID: (inout State) -> Void]` indexed by node variant
- Each handler reads the next node ID and jumps directly

**Feasibility**: Medium. Swift's optimizer may already convert dense switches to jump tables. Benchmarking required to determine if manual threading provides measurable improvement.

### Batch Checkpoint Management

**Current**: Each `.oneOf`, `.many`, `.optional`, and `.fold` saves a checkpoint (cursor position + state). Individual allocation per checkpoint.

**Improvement**: Pool checkpoint allocations. Pre-allocate a checkpoint stack sized to the maximum nesting depth (computable from graph analysis). Reuse slots rather than allocating per operation.

**Implementation path**:
1. Compute maximum `.oneOf`/`.many`/`.optional`/`.fold` nesting depth via graph analysis
2. Pre-allocate checkpoint stack of that size
3. Replace individual checkpoint save/restore with stack push/pop

**Complexity**: Low. Graph analysis provides the bound; runtime uses a pre-sized stack.

### Arena Generational Compaction

**Current**: `Machine.Value.Arena` allocates slots with generation counters for ABA prevention. Released slots are individually tracked.

**Improvement**: Detect when all handles from a generation are released, and reclaim the entire generation in bulk. This converts per-slot deallocation to per-generation compaction.

**Implementation path**:
1. Track handle count per generation
2. When a generation's live count reaches zero, reclaim all slots in that generation
3. Compact the arena by removing empty generations

**When valuable**: Long-running parsers (streaming input) where the arena grows over time. Generational compaction prevents unbounded arena growth.

---

## Outcome

**Status**: RECOMMENDATION

The graph migration unlocks a rich space of analysis and optimization capabilities. The immediate priority is exploiting what already works:

**Ready to implement now** (no new graph-primitives code needed):
1. Dead node elimination — compose `analyze.dead()` + `transform.subgraph()`
2. Recursion validation — `analyze.hasCycles()` to select execution path
3. Mutual recursion grouping — `analyze.scc()` for per-group memoization strategy

**Blocked on graph-primitives roadmap**:
4. Linear chain fusion — requires degree queries (graph-primitives priority #1)
5. CSE — requires structural hashing/equality (graph-primitives priority #3)
6. DOT visualization — requires generic DOT export (graph-primitives priority #2)
7. Program diff — requires graph diff (graph-primitives priority #6)

**Requires dedicated research**:
8. Error recovery — three design paths identified, no decision yet
9. Borrowed output discipline — recommended strategy (input-relative handles) needs concrete design

**Execution model improvements** (batch checkpoints, arena compaction) are independent of graph analysis and can proceed in parallel.

## References

- `machine-program-graph-sequential-migration.md` — Migration rationale and enabled capabilities (2026-02-23)
- `Analysis - Closure-Free Parser Combinators.md` — Defunctionalized architecture analysis, §8.1 error recovery, §8.3 borrowed output (2026-01-19)
- `Companion - Analysis Notes and Refinements.md` — Error recovery design space (§6), borrowed output strategies (§10) (2026-01-19)
- `swift-graph-primitives/Research/graph-primitives-roadmap.md` — Graph-primitives gap analysis and prioritization (2026-02-23)
- `swift-graph-primitives/Research/graph-operations-audit.md` — Canonical Graph ADT coverage (2026-02-16)
