<!--
version: 1.0.0
last_updated: 2026-04-15
status: COMPLETE
scope: swift-primitives Phase 2 application of @unsafe audit
-->

# Ecosystem `@unsafe` Audit — Phase 2 Primitives Report

## Summary

| Metric | Count |
|--------|------:|
| Total `@unsafe @unchecked Sendable` sites applied | 143 |
| Total `// WHY:` comment sites applied | 32 |
| **Total sites edited** | **175** |
| Submodules edited | 34 |
| Commits (1 per submodule) | 34 |
| Build status | **PASS** (superrepo `swift build`, 63.33s) |
| Test status | N/A (superrepo has no Tests directory; per-submodule builds pass) |

Expected: ~177 edits. Actual: 175. Delta: 2 (1.1%) — within 5% tolerance.

## Category Breakdown

| Category | Sites | Action taken |
|----------|------:|-------------|
| A (synchronized) | 9 | `@unsafe @unchecked Sendable` + three-section docstring |
| B (ownership transfer) | 134 | `@unsafe @unchecked Sendable` + three-section docstring |
| D (structural workaround) | 32 | `// WHY:` comment with rationale, tracking, removal criteria |
| **Total** | **175** | |

## Per-Submodule Breakdown

| Submodule | A | B | D | Total |
|-----------|--:|--:|--:|------:|
| swift-hash-table-primitives | 0 | 2 | 1 | 3 |
| swift-stack-primitives | 0 | 6 | 0 | 6 |
| swift-heap-primitives | 0 | 10 | 0 | 10 |
| swift-list-primitives | 0 | 4 | 0 | 4 |
| swift-memory-primitives | 0 | 5 | 2 | 7 |
| swift-storage-primitives | 0 | 6 | 3 | 9 |
| swift-queue-primitives | 0 | 15 | 0 | 15 |
| swift-buffer-primitives | 0 | 41 | 1 | 42 |
| swift-async-primitives | 4 | 1 | 0 | 5 |
| swift-clock-primitives | 2 | 0 | 3 | 5 |
| swift-tree-primitives | 0 | 6 | 0 | 6 |
| swift-set-primitives | 0 | 6 | 2 | 8 |
| swift-array-primitives | 0 | 9 | 1 | 10 |
| swift-dictionary-primitives | 0 | 6 | 0 | 6 |
| swift-slab-primitives | 0 | 3 | 0 | 3 |
| swift-infinite-primitives | 0 | 0 | 5 | 5 |
| swift-ownership-primitives | 2 | 5 | 0 | 7 |
| swift-sample-primitives | 0 | 1 | 1 | 2 |
| swift-cache-primitives | 2 | 0 | 1 | 3 |
| swift-rendering-primitives | 0 | 1 | 0 | 1 |
| swift-path-primitives | 0 | 1 | 0 | 1 |
| swift-predicate-primitives | 0 | 0 | 1 | 1 |
| swift-string-primitives | 0 | 1 | 0 | 1 |
| swift-bit-vector-primitives | 0 | 0 | 3 | 3 |
| swift-handle-primitives | 0 | 1 | 0 | 1 |
| swift-machine-primitives | 0 | 0 | 3 | 3 |
| swift-sequence-primitives | 0 | 0 | 1 | 1 |
| swift-property-primitives | 0 | 0 | 1 | 1 |
| swift-lifetime-primitives | 0 | 1 | 0 | 1 |
| swift-structured-queries-primitives | 0 | 0 | 1 | 1 |
| swift-input-primitives | 0 | 1 | 0 | 1 |
| swift-loader-primitives | 0 | 0 | 1 | 1 |
| swift-parser-machine-primitives | 0 | 0 | 1 | 1 |
| swift-test-primitives | 1 | 0 | 0 | 1 |
| **Total** | **9** | **134** | **32** | **175** |

## D Adjudication Decisions Applied

| SP | Decision | Sites affected |
|----|----------|---------------:|
| SP-1 | `<let N: Int>` + `~Copyable` → B | ~31 |
| SP-2 | `@_rawLayout` bridge types → D | 4 |
| SP-3 | Hash.Table → B, Hash.Table.Static → D | 2 |
| SP-4 | Infinite iterators, phantom params → D | ~14 |
| SP-5 | Pointer-backed Copyable descriptors → D | ~5 |
| SP-6 | CoW macro-generated storage → D | 1 |
| SP-7 | Misc structural workarounds → D | ~8 |
| SP-8 | `~Copyable` containers conditional Sendable → B | ~8 |

## Spot-Check Corrections Applied

- `Stack.Bounded`: Agent 2 flagged as D-candidate for `<let N: Int>`, but Stack.Bounded has no value-generic. Primary B classification confirmed. Applied `@unsafe`.
- `Hash.Occupied.View`: LOW_CONFIDENCE deferred site. Applied `@unsafe @unchecked Sendable` with pointer-lifetime safety invariant docstring (the type already has `@unsafe` on the struct itself).

## Branch State

- Parent repo: `unsafe-audit` branch in `/Users/coen/Developer/swift-primitives/`
- Each submodule: `unsafe-audit` branch
- Not pushed to remote (per audit protocol — push after review).

## References

- `unsafe-audit-findings.md` — master findings with D adjudication
- Agent findings: `unsafe-audit-agent{2-7}-findings.md`
- Pilot: commit `da86a35` on swift-threads main (Phase 0)
