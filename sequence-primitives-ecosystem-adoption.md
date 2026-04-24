# Sequence Primitives Ecosystem Adoption

<!--
---
version: 1.0.0
last_updated: 2026-02-06
status: RECOMMENDATION
---
-->

## Context

sequence-primitives (Tier 7) provides `Sequence.Protocol` (supports `~Copyable` conformers), `Sequence.Iterator.Borrowing.Protocol` (span-based iteration), `Sequence.Drain.Protocol` (consuming iteration), and `Sequence.Consume.Protocol` (move-based iteration). When a Copyable type conforms to `Sequence.Protocol`, it can also conform to `Swift.Sequence` for `forEach`/`map`/`filter`/`for-in` — but must provide an explicit `var underestimatedCount: Int` to disambiguate between two default implementations.

The dependency maximum utilization principle requires that packages at Tier 7+ use sequence-primitives rather than reimplementing iteration patterns.

## Question

Which packages should adopt sequence-primitives, in what order, and what patterns should they follow?

## Analysis

### Audit Methodology

Every package at Tier 7+ was checked for:
1. Existing sequence-primitives dependency
2. Custom `forEach` methods that could be replaced by `Sequence.Protocol` conformance
3. `IteratorProtocol` / `makeIterator()` patterns that could conform to `Sequence.Protocol`
4. Bare iteration reimplementations

### Already Adopted (9 packages)

| Package | Tier | Notes |
|---------|------|-------|
| sequence-primitives | 7 | Defines the protocols |
| collection-primitives | 8 | Already depends |
| cyclic-primitives | 8 | Already depends |
| range-primitives | 9 | Already depends |
| bit-vector-primitives | 9 | Adopted 2026-02-06 — `Ones.View` + `Ones.Static` conform to `Sequence.Protocol` + `Swift.Sequence` |
| heap-primitives | 10 | Already depends |
| set-primitives | 16 | Already depends |
| array-primitives | 15 | Already depends |
| buffer-primitives | 15 | Adopted 2026-02-06 — `Linear`, `Linear.Bounded`, `Ring`, `Ring.Bounded` conform to `Swift.Sequence`; Inline types stubbed pending `Storage.Inline` conditional Copyable (INV-INLINE-004a) |

### Candidates for Adoption

Ordered bottom-up by tier (lowest first).

#### REC-SEQ-ADOPT-001: hash-table-primitives (Tier 7)

**Priority**: High
**Pattern**: Custom `forEach` methods on hash table types.
**Action**: Conform to `Sequence.Protocol`. If types are Copyable, also `Swift.Sequence` with `underestimatedCount`.
**Constraint**: Same tier as sequence-primitives — verify no circular dependency.

#### REC-SEQ-ADOPT-002: infinite-primitives (Tier 10)

**Priority**: High
**Pattern**: Multiple `Iterator` types already implementing `IteratorProtocol`.
**Action**: Add `Sequence.Protocol` conformance to types that have `makeIterator()`. Unifies iteration under the protocol.

#### REC-SEQ-ADOPT-003: list-primitives (Tier 10)

**Priority**: High
**Pattern**: Custom iterator infrastructure for linked-list traversal.
**Action**: Conform list types to `Sequence.Protocol` via existing iterators.

#### REC-SEQ-ADOPT-004: vector-primitives (Tier 10)

**Priority**: Medium
**Pattern**: Iterator types for inline and fixed-size vector variants.
**Action**: Conform to `Sequence.Protocol` + `Swift.Sequence` where Copyable.

#### REC-SEQ-ADOPT-005: stack-primitives (Tier 15)

**Priority**: Medium
**Pattern**: Iterator types for stack traversal.
**Action**: Conform to `Sequence.Protocol` + `Swift.Sequence` where Copyable.

#### REC-SEQ-ADOPT-006: queue-primitives (Tier 16)

**Priority**: Medium
**Pattern**: Iterator types for queue traversal.
**Action**: Conform to `Sequence.Protocol` + `Swift.Sequence` where Copyable.

#### REC-SEQ-ADOPT-007: dictionary-primitives (Tier 16)

**Priority**: Medium
**Pattern**: Iterator types for key/value iteration.
**Action**: Conform to `Sequence.Protocol` + `Swift.Sequence` where Copyable.

#### REC-SEQ-ADOPT-008: tree-primitives (Tier 17)

**Priority**: High (largest opportunity)
**Pattern**: 21 iterator/sequence types across pre-order, in-order, post-order, and level-order traversals.
**Action**: Conform traversal types to `Sequence.Protocol`. This is the highest-volume adoption opportunity in the ecosystem.

#### REC-SEQ-ADOPT-009: graph-primitives (Tier 17)

**Priority**: High
**Pattern**: Multiple traversal iterator types (BFS, DFS, etc.).
**Action**: Conform traversal types to `Sequence.Protocol`.

### Deliberately Excluded

| Package | Tier | Reason |
|---------|------|--------|
| bit-primitives | 9 | `Bit.Set.forEach` is the innermost Wegner/Kernighan bit-extraction loop — called BY iterators, not a sequence reimplementation |
| finite-primitives | 7 | No iteration patterns |
| algebra-primitives | 8 | No iteration patterns |
| cyclic-index-primitives | 9 | No iteration patterns |
| dimension-primitives | 9 | No iteration patterns |
| input-primitives | 9 | No iteration patterns |
| bit-index-primitives | 10 | No iteration patterns |
| complex-primitives | 10 | No iteration patterns |
| handle-primitives | 10 | No iteration patterns |
| parser-primitives | 10 | No iteration patterns |
| region-primitives | 10 | No iteration patterns |
| slab-primitives | 10 | No iteration patterns |
| slice-primitives | 10 | No iteration patterns |
| time-primitives | 10 | No iteration patterns |
| binary-buffer-primitives | 15 | No iteration patterns |

## Implementation Pattern

Each adoption follows the same pattern established by bit-vector-primitives and buffer-primitives:

### Step 1: Add dependency

```swift
// Package.swift
.package(path: "../swift-sequence-primitives"),
// target dependencies:
.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
```

### Step 2: Export

```swift
// exports.swift
@_exported import Sequence_Primitives
```

### Step 3: Conform to Sequence.Protocol

```swift
extension MyType: Sequence.`Protocol` where Element: Copyable {
    @inlinable
    public func makeIterator() -> Iterator { /* ... */ }
}
```

### Step 4: Conform to Swift.Sequence (Copyable types only)

```swift
extension MyType: Swift.Sequence where Element: Copyable {
    @inlinable
    public var underestimatedCount: Int { /* exact or lower-bound count */ }
}
```

**Critical**: The `underestimatedCount` property is REQUIRED to disambiguate between two default implementations when conforming to both `Sequence.Protocol` and `Swift.Sequence`. Omitting it causes a compiler error.

### Step 5: Disambiguate shadowed globals

`Swift.Sequence` brings `min()` and `max()` instance methods into scope, shadowing `Swift.min(_:_:)` and `Swift.max(_:_:)`. Any existing `min(...)` or `max(...)` calls in the same type scope must be qualified as `Swift.min(...)` / `Swift.max(...)`.

## Outcome

**Status**: RECOMMENDATION

Nine packages have already adopted sequence-primitives. Nine more are candidates, ordered bottom-up:

1. hash-table-primitives (Tier 7)
2. infinite-primitives (Tier 10)
3. list-primitives (Tier 10)
4. vector-primitives (Tier 10)
5. stack-primitives (Tier 15)
6. queue-primitives (Tier 16)
7. dictionary-primitives (Tier 16)
8. tree-primitives (Tier 17)
9. graph-primitives (Tier 17)

Each adoption is independent and can be executed in parallel across packages, but bottom-up ordering minimizes cascading issues.

## References

- sequence-storage-integration-analysis.md — Original analysis that drove bit-vector and buffer adoption
- bit-vector-primitives `Experiments/sequence-protocol-conformance/` — Validated the conformance pattern
- buffer-primitives `Experiments/slab-deinit-workaround/` — MoveOnlyChecker workaround discovered during adoption
