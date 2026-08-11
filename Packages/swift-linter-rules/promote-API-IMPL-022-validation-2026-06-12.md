# Validation receipt: [API-IMPL-022]
Date: 2026-06-12
Rule: frozen tower type
Placement tier: primitives (pack: Primitives Linter Rule Tower — new; name avoids the universal-tier Structure collision)
Detection method: test-target validation harness (FileManager walk + SwiftParser + visitor; harness deleted post-receipt). Regex pre-scan unsuitable (nesting-aware namespace-root resolution).

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 (5 raw) | all 5 in `*.docc/Resources/` tutorial SNIPPETS — harness walked non-compiled files; the lint driver lints target sources only; harness artifact, not rule surface |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

Hard-level budget ([PROMOTE-004]): 0 ≤ 10 ✓. The ladder (non-tower) result doubles as the
self-scoping proof: the namespace-allowlist keeps the rule silent outside the tower.

## Tower probe (the rule's home turf — ground truth beyond the ladder)

44 findings across 9 of 27 tower packages; the other 18 (incl. every Q4-swept package:
storage, storage-split, storage-arena, buffer-linear core, shared, array + the reshaped
families set/dict/ordered/hash-table/queue/deque/slot-map/fixed/column/store) are CLEAN —
the sweep held. Findings = the sweep's unfinished tail (branch 1, real violations):

| Package | Count | Shape |
|---|---|---|
| swift-graph-primitives | 15 | Graph.Sequential + nests, Adjacency, Traversals — never swept |
| swift-tree-n-primitives | 11 | tree structs + Nested.Node (real) + 5 Order.*.Sequence wrappers (classification ask) |
| swift-tree-unbounded-primitives | 6 | ditto (3 Sequence wrappers) |
| swift-tree-keyed-primitives | 4 | ditto (3 Sequence wrappers) |
| swift-heap-primitives | 4 | Heap, Navigate, MinMax.Fixed — its template round never ran |
| swift-stack-primitives | 2 | Stack, Stack.Bounded (A-1 interim kept publics unfrozen) |
| swift-buffer-linear-primitives | 1 | Buffer.Linear.Header (missed by de2487f) |
| swift-buffer-linked-primitives | 1 | Buffer.Linked (linked round deferred) |

Classification ask for the seat: the 11 `Order.*.Sequence` wrappers store the tree BY VALUE
(`package let tree: Tree.N<n>`) — stored-by-mechanics, view-by-role. Freeze vs add
`Sequence` to the curated exemption list = seat ruling; the rule fires on them until ruled.

Branch: 1 (batch-fix worklist → the tower lanes; warnings non-blocking per [PROMOTE-009]).
