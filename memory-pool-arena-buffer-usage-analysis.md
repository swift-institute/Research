# Memory.Pool, Memory.Arena, and Memory.Buffer: Usage Analysis and Disposition

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-memory-primitives, swift-storage-primitives]
normative: false
---
-->

> **Update (2026-03-15)**: This document's framing — evaluating types by consumer count — is architecturally incorrect. Layer 1 primitives exist because they belong to their scoped domain, not because something currently imports them. Memory.Pool, Memory.Arena, and Memory.Buffer are valid memory-primitives types regardless of downstream adoption. The question is whether each type is theoretically complete within its domain, not whether it has consumers. Storage.Pool's composition of Memory.Pool (per `memory-storage-composition-feasibility.md`) validates the design, but is not the reason Memory.Pool should exist.

## Context

Storage.Pool was recently implemented as a `final class` in swift-storage-primitives
(Tier 14). The `storage-pool-architecture.md` research document (DECISION) chose
**independent implementation** over composition of Memory.Pool. Storage.Pool shares
the design pattern (typed sentinel, Bit.Vector, in-band free list) but not the code.

Storage.Arena is planned but not yet implemented.

This raises questions about the disposition of Memory.Pool, Memory.Arena, and
Memory.Buffer — all implemented at Tier 13 in swift-memory-primitives. If the
storage tier implements independently rather than composing, are these types serving
any purpose?

## Question

Should Memory.Pool, Memory.Arena, and Memory.Buffer be retained, and if so, under
what justification? Specifically:

1. Are these types used by any consumer outside swift-memory-primitives?
2. Is the Storage.Pool/Memory.Pool mismatch fundamental or incidental?
3. Should Storage.Arena compose Memory.Arena or implement independently?
4. Should any of these types be removed?

## Analysis

### Inventory: Current Usage

A comprehensive search across all swift-primitives packages, swift-standards, and
swift-foundations yields:

| Type | Consumers Outside Own Tests | Nature of Use |
|------|----------------------------|---------------|
| Memory.Buffer | None | — |
| Memory.Buffer.Mutable | None | — |
| Memory.Pool | None | — |
| Memory.Arena | None | — |
| Memory.Contiguous.Protocol | 3 packages | Generic constraints and conformances |
| Memory.Address | Pervasive | Core type used across many packages |
| Memory.Alignment | Several | Used in buffer-primitives growth policy |

**Critical finding**: `Memory.Contiguous.Protocol` (which lives in Memory Primitives
Core, not in the Buffer files) is actively used across swift-binary-primitives
(generic constraints on Cursor/Reader), swift-buffer-primitives (conformances on
Buffer.Linear variants), and swift-storage-primitives (conformances on Storage.Heap
and Storage.Inline). But `Memory.Buffer` and `Memory.Buffer.Mutable` themselves —
the concrete types — have zero consumers outside their own test suite.

Memory.Pool and Memory.Arena similarly have zero consumers outside their own tests.

### The Storage.Pool / Memory.Pool Mismatch

The `storage-pool-architecture.md` research (DECISION) analyzed this exhaustively.
The mismatch is **fundamental, not incidental**:

| Concern | Memory.Pool | Storage.Pool |
|---------|-------------|--------------|
| Ownership | `struct: ~Copyable` (value) | `final class` (reference) |
| Pointer type | `UnsafeMutableRawPointer` | `UnsafeMutablePointer<Element>` |
| Index type | `Index<Slot>` | `Index<Element>` |
| Init cost | O(n) pre-built free list | O(1) virgin cursor |
| Element lifecycle | Caller responsibility | Class deinit via bitmap |
| CoW support | N/A | `isKnownUniquelyReferenced` + `copy()` |
| Conditional Copyability | Always ~Copyable | Copyable (reference type) |
| API return | `allocate() -> UnsafeMutableRawPointer` | `allocate() -> Index<Element>` |

These are not superficial differences. They reflect that Memory.Pool and Storage.Pool
operate at **different abstraction levels** with **different concrete requirements**.
The composition attempt (Option A in the research) would have required 5 non-trivial
modifications to Memory.Pool and translation overhead at every API boundary.

The Storage.Heap precedent confirms the pattern: Storage.Heap extends ManagedBuffer
directly — it does not wrap Memory.Buffer. The memory-to-storage relationship is
**conceptual derivation**, not **code composition**.

### Storage.Arena: Composition or Independence?

The `storage-primitives-comparative-analysis.md` (REC-001) sketched Storage.Arena
composing Memory.Arena:

```swift
extension Storage {
    public struct Arena<Element: ~Copyable>: ~Copyable {
        var memory: Memory.Arena
        var slots: Bit.Vector.Dynamic
    }
}
```

However, the Storage.Pool precedent suggests re-evaluating. Applying the same
analysis:

| Concern | Memory.Arena | Storage.Arena (projected) |
|---------|-------------|--------------------------|
| Ownership | `struct: ~Copyable` (value) | Would need reference semantics for CoW? |
| Allocation return | `Memory.Address?` | Would need `Index<Element>` |
| Tracking | None (bump pointer only) | Per-slot BitVector |
| Element lifecycle | Caller responsibility | Automatic deinit on reset |
| Reset semantics | Reset bump pointer | Deinit all initialized elements, then reset |

The mismatch is **less severe** than Pool because:
- Arena has no free list (no Index<Slot> / Index<Element> translation)
- Arena's `allocate()` returns `Memory.Address?` which maps naturally to
  a slot index via stride arithmetic
- Arena has no bitmap to coordinate (Memory.Arena has none; Storage.Arena adds one)

But composition still requires:
- Converting `Memory.Address?` to `Index<Element>` on every allocation
- Maintaining a separate BitVector that Memory.Arena knows nothing about
- Coordinating reset between Memory.Arena and the BitVector

**Verdict**: The mismatch is less fundamental than Pool but still meaningful.
Independent implementation would be simpler and follow the Storage.Pool/Storage.Heap
precedent. The composition savings would be ~10 lines of bump-pointer logic.

### Option A: Keep All Three (Buffer, Pool, Arena)

**Rationale**: Architectural completeness. The five-layer architecture places raw
allocation strategies at the Memory tier (13). Even if the Storage tier (14)
implements independently, the Memory tier serves future raw-byte consumers:

- Network packet buffers (fixed-size raw byte slots → Memory.Pool)
- Binary protocol parsing (bump-allocated raw regions → Memory.Arena)
- C interop and FFI (raw buffer management → Memory.Buffer)
- Performance-critical code that operates below the Storage abstraction

**Advantages**:
- Architecture-complete: Memory tier has all three allocation patterns
- Well-tested: 121 Pool tests, extensive Arena/Buffer tests
- Design validation: Memory.Pool's design informed Storage.Pool
- Future-proofing: raw-byte consumers at the Foundations layer may need these

**Disadvantages**:
- Currently zero consumers = maintained dead code
- Each type adds build time and cognitive load
- The "future consumer" argument is speculative

### Option B: Remove Pool and Arena, Keep Buffer

**Rationale**: Memory.Buffer provides unique value (non-null guarantees over
UnsafeRawBufferPointer) that no other type offers. Pool and Arena are patterns
that the Storage tier implements independently.

**Advantages**:
- Reduces maintained surface area
- Acknowledges that composition didn't work (Pool) and likely won't (Arena)
- Buffer has the strongest standalone justification (non-null safety invariant)

**Disadvantages**:
- Memory.Buffer also has zero consumers
- Inconsistent: if Buffer stays, why not Pool and Arena?
- Removes types that validated designs (Pool especially)

### Option C: Remove All Three (Buffer, Pool, Arena)

**Rationale**: Strict YAGNI. Zero consumers means zero value. If raw-byte consumers
emerge, they can be rebuilt. The Memory Primitives package retains its core value:
Memory.Address, Memory.Alignment, Memory.Contiguous.Protocol, and stdlib pointer
extensions.

**Advantages**:
- Cleanest: no dead code
- YAGNI-compliant
- Simplifies swift-memory-primitives package structure
- Memory Primitives Core + Standard Library Integration remain valuable

**Disadvantages**:
- Loses validated, tested implementations
- If raw-byte consumers emerge, work must be redone
- Memory.Pool informed Storage.Pool's design — losing the reference implementation

### Option D: Relocate to Foundations Layer

**Rationale**: These types may be premature at the Primitives layer but useful at the
Foundations layer where concrete consumers exist (swift-io for arena allocation,
swift-networking for pool allocation).

**Advantages**:
- Moves types closer to actual consumers
- Primitives layer stays minimal
- Foundations layer already has swift-memory (which re-exports Memory_Primitives)

**Disadvantages**:
- Breaks tier architecture (Foundations depends on Primitives, not the reverse)
- These ARE primitive concepts — allocation strategies are atomic building blocks
- Creates awkward situation where Memory.Address is at Tier 13 but Memory.Pool
  is at Layer 3

## Comparison

| Criterion | A (keep all) | B (keep buffer) | C (remove all) | D (relocate) |
|-----------|:-----------:|:---------------:|:--------------:|:------------:|
| Architecture completeness | 4/4 | 2/4 | 1/4 | 3/4 |
| YAGNI compliance | 1/4 | 2/4 | 4/4 | 2/4 |
| Maintenance burden | 1/4 | 3/4 | 4/4 | 2/4 |
| Future consumer readiness | 4/4 | 2/4 | 1/4 | 3/4 |
| Tier architecture integrity | 4/4 | 4/4 | 4/4 | 1/4 |
| Tested code preservation | 4/4 | 2/4 | 1/4 | 4/4 |
| Package simplicity | 1/4 | 3/4 | 4/4 | 2/4 |

## Outcome

**Status**: RECOMMENDATION

**Option C: Remove Memory.Pool, Memory.Arena, and Memory.Buffer.**

**Rationale**:

1. **Zero consumers after 61+ packages.** These types have had ample opportunity to
   find consumers. Every package that COULD have used them (storage-primitives,
   buffer-primitives, binary-primitives) instead uses either Memory.Contiguous.Protocol
   (different type), stdlib pointer types directly, or independent implementations of
   the same patterns.

2. **The Storage.Pool precedent is dispositive.** The most natural consumer of
   Memory.Pool — Storage.Pool — was explicitly designed NOT to use it. The
   `storage-pool-architecture.md` DECISION documented 5 required modifications to
   Memory.Pool and found ~20 lines of structural similarity insufficient to justify
   composition. If your single best consumer rejects you, you have no product-market fit.

3. **Storage.Arena would follow the same path.** The mismatch analysis above shows
   that Storage.Arena composing Memory.Arena would require address-to-index translation,
   separate tracking coordination, and reset synchronization — all for ~10 lines of
   shared bump-pointer logic. The Storage.Pool/Storage.Heap precedent overwhelmingly
   favors independent implementation.

4. **Memory.Buffer's non-null invariant is useful but unused.** In principle, wrapping
   UnsafeRawBufferPointer with a non-null guarantee is valuable. In practice, no
   package uses it. The Memory Primitives Standard Library Integration target already
   provides extensions on the stdlib pointer types that consumers actually use.

5. **The design knowledge is preserved.** Memory.Pool's design directly informed
   Storage.Pool. The typed sentinel pattern, Bit.Vector tracking, and in-band free
   list are documented in research and implemented in Storage.Pool. Removing
   Memory.Pool doesn't lose the design — it acknowledges that the design found its
   home at the Storage tier, not the Memory tier.

6. **Rebuilding is cheap.** If a genuine raw-byte consumer emerges at the Foundations
   layer (network I/O, binary protocols), Memory.Pool/Arena/Buffer can be rebuilt.
   The research documents, design patterns, and Storage.Pool implementation serve as
   complete blueprints. The cost of rebuilding (~300 lines each) is lower than the
   ongoing cost of maintaining unused code across every build, test, and refactor cycle.

**What remains in swift-memory-primitives**:
- Memory Primitives Core: Memory.Address, Memory.Alignment, Memory.Contiguous.Protocol,
  typed arithmetic — all actively used across the ecosystem
- Memory Primitives Standard Library Integration: Extensions on UnsafeRawPointer,
  UnsafeMutableRawPointer, UnsafeRawBufferPointer, UnsafeMutableRawBufferPointer —
  actively used
- The package remains valuable without Pool, Arena, and Buffer

**What is removed**:
- Memory Pool Primitives target (sources + tests)
- Memory Arena Primitives target (sources + tests)
- Memory.Buffer.swift, Memory.Buffer.Base.swift (from Standard Library Integration)
- Memory.Buffer.Mutable.swift, Memory.Buffer.Mutable.Base.swift (from Standard Library Integration)
- Associated test files

**Amendment to storage-pool-architecture.md**: Update metadata `status: IN_PROGRESS`
→ `status: DECISION` to match the body's stated outcome.

**Amendment to storage-primitives-comparative-analysis.md**: REC-001 (Storage.Arena)
should be updated to recommend independent implementation, not composition of
Memory.Arena, consistent with the Storage.Pool precedent.

## References

### Internal
- `swift-storage-primitives/Research/storage-pool-architecture.md` (DECISION) — Memory.Pool vs Storage.Pool composition analysis
- `swift-primitives/Research/storage-primitives-comparative-analysis.md` (RECOMMENDATION) — Comparative analysis including REC-001 (Storage.Arena)
- `swift-storage-primitives/Research/storage-ownership-reference-synthesis.md` (DECISION v3.0.0) — Layered split, Phase 2

### Design Precedent
- Storage.Heap: extends ManagedBuffer directly, does not compose Memory.Buffer
- Storage.Pool: independent implementation, does not compose Memory.Pool
- Both establish: memory-to-storage relationship is conceptual derivation, not code composition
