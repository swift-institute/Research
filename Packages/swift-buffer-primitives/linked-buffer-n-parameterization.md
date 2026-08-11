# Linked Buffer N-Parameterization

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
research_tier: 1
applies_to: [swift-buffer-primitives]
normative: false
---
-->

## Context

`Buffer<Element>.Linked` was implemented as an always-doubly-linked buffer with named `next`/`prev` fields per node. The Tier 2 research document `linked-list-layered-architecture.md` recommended parameterizing by link count N, allowing both singly-linked (N=1) and doubly-linked (N=2) configurations. This is now required because:

- `List<Element>.Linked<1>` is singly-linked (one pointer per node)
- `Queue<Element>.Linked` is also singly-linked
- Using a doubly-linked buffer for N=1 wastes 8 bytes per node — a memory regression

## Question

How should `Buffer.Linked` be parameterized to support both singly and doubly-linked node layouts without memory waste?

## Analysis

### Option A: InlineArray<N, Index<Node>>

Replace named `next`/`prev` fields with `links: InlineArray<N, Index<Node>>`:

```swift
@frozen
public struct Node: ~Copyable {
    public var element: Element
    public var links: InlineArray<N, Index<Node>>
}
```

Convention: `links[0]` = next, `links[1]` = prev (when N >= 2).

**Pros**:
- Zero memory waste: N=1 stores exactly one link per node
- Compiler specializes `Buffer.Linked<1>` and `Buffer.Linked<2>` separately
- Dead N>=2 branches eliminated in N=1 specialization
- Matches the recommendation from `linked-list-layered-architecture.md`

**Cons**:
- Slightly less readable than named fields (mitigated by computed properties)
- Requires `N >= 2` guards on prev-link access

### Option B: Conditional fields via protocol

Define separate Node types for singly/doubly-linked via a protocol.

**Pros**:
- Named fields preserved

**Cons**:
- Protocol witness tables for ~Copyable types are fragile
- Two separate Node types means two code paths, not one parameterized path
- Cannot nest both inside `Buffer.Linked` without additional complexity

### Comparison

| Criterion | Option A (InlineArray) | Option B (Protocol) |
|-----------|:---------------------:|:-------------------:|
| Memory efficiency | Optimal | Optimal |
| Code duplication | Minimal (one path) | High (two paths) |
| Compiler specialization | Automatic | Manual |
| Readability | Good (with conventions) | Better (named fields) |
| ~Copyable compatibility | Proven (List.Linked uses this) | Fragile |

## Outcome

**Status**: DECISION

**Conclusion**: Option A — `InlineArray<N, Index<Node>>` with the convention `links[0]` = next, `links[1]` = prev.

**Rationale**: This approach is already proven in `List.Linked<N>` which uses `InlineArray<N, Int>` for its links. The same pattern translates directly to `Buffer.Linked<N>` using typed `Index<Node>` instead of `Int`. The compiler generates specialized code for each N value, eliminating dead branches.

### Performance Characteristics (no regression)

| Operation | N=1 (singly) | N=2 (doubly) |
|-----------|:------------:|:------------:|
| insertFront | O(1) | O(1) |
| insertBack | O(1) | O(1) |
| removeFront | O(1) | O(1) |
| removeBack | O(n) traverse | O(1) |
| forEach | O(n) | O(n) |
| forEachReversed | N/A | O(n) |
| Memory per node | Element + 1 Index | Element + 2 Index |

### Storage.Pool Stride Precondition

`Storage<Node>.Pool` requires `MemoryLayout<Node>.stride >= MemoryLayout<Index<Node>>.size` for in-band free list storage. Since Node contains at least one `Index<Node>` (for N >= 1), its stride is always >= 8 bytes, satisfying this precondition.

## References

- `linked-list-layered-architecture.md` (Tier 2, swift-list-primitives) — Original recommendation for N-parameterization
- `theoretical-buffer-primitives-design.md` (Tier 3, swift-buffer-primitives) — Buffer discipline design
