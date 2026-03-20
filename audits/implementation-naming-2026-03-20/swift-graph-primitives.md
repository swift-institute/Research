# swift-graph-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Scope**: 56 source files across 17 modules
**Rules**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-033], [PATTERN-017], [API-IMPL-005], [API-ERR-001]

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 1 |
| MEDIUM | 3 |
| LOW | 3 |
| INFO | 2 |

The package has excellent Nest.Name discipline and clean one-type-per-file compliance. The main findings center on `Int(bitPattern:)` usage in algorithm internals, one compound method name, and `.rawValue` usage in `Graph.Sequential.nodes`.

## Findings

### [GRAPH-001] `.rawValue` at call site in `Graph.Sequential.nodes`
**Rule**: [IMPL-002], [PATTERN-017]
**Severity**: HIGH
**File**: `Sources/Graph Primitives Core/Graph.Sequential.swift`, line 54
**Finding**: `result.reserveCapacity(Int(bitPattern: count.rawValue))` -- `.rawValue` is accessed in a non-boundary location to extract the raw `UInt` from a `Count` type for `reserveCapacity`. This violates [IMPL-002] (no `.rawValue` at call sites) and [PATTERN-017] (`.rawValue` confined to boundary code).
**Recommendation**: Add a boundary overload `reserveCapacity(_: Count)` or use `Int(bitPattern: count)` if a conversion path exists.

### [GRAPH-002] `Int(bitPattern:)` in `Graph.Sequential.nodes` property
**Rule**: [IMPL-010]
**Severity**: MEDIUM
**File**: `Sources/Graph Primitives Core/Graph.Sequential.swift`, line 54
**Finding**: `(0..<Int(bitPattern: count)).lazy.map { Node<Tag>(__unchecked: (), Ordinal(UInt($0))) }` -- `Int(bitPattern: count)` is used inline in a computed property to produce a range, not in a boundary overload. The `__unchecked` + `Ordinal(UInt($0))` further shows raw manipulation that could be encapsulated.
**Recommendation**: Consider a typed `nodes` implementation using `Index<Tag>` range infrastructure if available.

### [GRAPH-003] `Int(bitPattern:)` in `Graph.Traversal.Topological` result capacity
**Rule**: [IMPL-010]
**Severity**: LOW
**File**: `Sources/Graph Topological Primitives/Graph.Traversal.Topological.swift`, line 54
**Finding**: `result.reserveCapacity(Int(bitPattern: count.rawValue))` -- same pattern as [GRAPH-001]. Additionally `.rawValue` is accessed here.

### [GRAPH-004] `popNextSender`-style compound not present (clean)
**Rule**: [API-NAME-002]
**Severity**: N/A (PASS)
**Finding**: Graph API uses nested accessors: `graph.traverse.first.depth(from:)`, `graph.analyze.reachable(from:)`, `graph.path.shortest(from:to:)`, `graph.transform.payloads { }`. Exemplary nested accessor pattern throughout.

### [GRAPH-005] `reconstructPath` and `reconstructWeightedPath` are compound method names
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**File**: `Sources/Graph Shortest Path Primitives/Graph.Sequential.Path.Shortest.swift`, line 58; `Sources/Graph Weighted Path Primitives/Graph.Sequential.Path.Weighted.swift`, line 100
**Finding**: `reconstructPath(to:predecessors:source:)` and `reconstructWeightedPath(to:predecessors:source:)` are compound identifiers. These are `@usableFromInline` internal helpers, not public API, which reduces impact.
**Recommendation**: Could be restructured as a nested type or namespace, e.g., `Path.Reconstruct.from(predecessors:source:)`, but given their `@usableFromInline` visibility, this is lower priority.

### [GRAPH-006] Multiple `for ... in` loops over graph nodes in algorithm internals
**Rule**: [IMPL-033]
**Severity**: INFO
**Files**: Multiple algorithm files (SCC, Dead, Reachable, TransitiveClosure, etc.)
**Finding**: Algorithm implementations use `for root in roots`, `for adjacent in extract.adjacent(payload)`, `for source in graph.nodes`, etc. These are appropriate -- graph algorithms inherently require iteration over node collections, and the stdlib `Sequence` protocol mandates `for-in` syntax. Not a violation.

### [GRAPH-007] `Graph.Adjacency.Extract` uses `Swift.Sequence` not `Sequence.Protocol`
**Rule**: N/A (design observation)
**Severity**: INFO
**File**: `Sources/Graph Primitives Core/Graph.Adjacency.Extract.swift`, line 18
**Finding**: `Adjacent: Swift.Sequence<Graph.Node<Tag>>` uses stdlib `Sequence` throughout the graph package for adjacency iteration. This is intentional -- graph algorithms use `for-in` syntax which requires `Swift.Sequence`. Consistent and correct.

### [GRAPH-008] `Sequence.Difference.Hunk.patchMark` string interpolation with typed values
**Rule**: [IMPL-002]
**Severity**: LOW
**File**: N/A (this is sequence-primitives, recorded here by mistake -- see SEQ findings)
**Correction**: Disregard; this belongs to sequence-primitives.

### [GRAPH-009] `Graph.Channel` / `Async.Channel` naming pattern not applicable
**Rule**: [API-NAME-001]
**Severity**: N/A (PASS)
**Finding**: All types follow Nest.Name: `Graph.Sequential`, `Graph.Adjacency.List`, `Graph.Adjacency.Extract`, `Graph.Traversal.First.Depth`, `Graph.Traversal.First.Breadth`, `Graph.Traversal.Topological`, `Graph.Sequential.Builder`, `Graph.Sequential.Analyze`, `Graph.Sequential.Path`, `Graph.Sequential.Transform`, `Graph.Sequential.Reverse`, `Graph.Remappable.Remap`, `Graph.Default.Value`. No compound type names.

### [GRAPH-010] `hasCycles` is a compound property name
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**Files**: `Sources/Graph Cycles Primitives/Graph.Sequential.Analyze.Cycles.swift`, lines 10, 20, 29; `Sources/Graph Topological Primitives/Graph.Traversal.Topological.swift`, line 107
**Finding**: `hasCycles` is a compound identifier (has + Cycles). The nested accessor pattern would be `graph.analyze.cycles.exist` or similar. However, `hasCycles` is a read-only `Bool` property -- restructuring it as a nested accessor adds overhead for a simple predicate.
**Recommendation**: Consider `graph.analyze.cycles(from:)` returning a result type, or accept the compound property as an exception for simple Boolean predicates.

### [GRAPH-011] `allocateHole` is a compound method name
**Rule**: [API-NAME-002]
**Severity**: LOW
**File**: `Sources/Graph Primitives Core/Graph.Sequential.Builder.swift`, lines 81, 104
**Finding**: `allocateHole(using:)` and `allocateHole()` are compound identifiers. Could be `allocate.hole(using:)` via nested accessor. Since these are builder methods called during graph construction (not hot-path), the compound name is a minor stylistic issue.

## Clean Passes

| Rule | Status |
|------|--------|
| [API-NAME-001] Nest.Name | PASS -- All types use proper nesting. |
| [IMPL-002] No .rawValue at call sites | FAIL -- 2 occurrences (GRAPH-001, GRAPH-003). |
| [API-ERR-001] Typed throws | PASS -- Package is fully non-throwing. |
| [API-IMPL-005] One type per file | PASS -- 56/56 files contain exactly one primary type or namespace. |

## Overall Assessment

swift-graph-primitives demonstrates excellent architecture with the nested accessor pattern (`graph.traverse.first.depth`, `graph.analyze.reachable`, `graph.path.shortest`). The HIGH finding is the `.rawValue` leak in `Graph.Sequential.nodes` and `Topological.computeOrder`. The MEDIUM findings are compound identifiers in internal helpers and one public predicate. The algorithm implementations are clean and well-structured.
