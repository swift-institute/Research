# Bit Collections Stack Migration Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
tier: 2
depends_on: [bitset-architecture-ideal-model, bit-vector-type-organization, bit-vector-primitives-reducibility, "data structures/Bit Collections Assessment"]
---
-->

## Context

The "Bit Collections Assessment" document (`Research/data structures/Bit Collections Assessment.md`) evaluated the migration status of `swift-bit-vector-primitives` and `swift-bitset-primitives` and concluded with a deferred recommendation:

> - **Bitset**: Prerequisite — adopt Bit.Pack addressing. Then compose Bit.Vector to gain stack backing transitively.
> - **Bit Vector**: Base type → `Storage.Heap<UInt>` (via a buffer type), Dynamic/Bounded → `Buffer.Linear<UInt>`.

This research investigates whether putting Bitset and Bit.Vector on the `Storage ← Buffer ← Data Structure` stack is **structurally feasible, semantically correct, and architecturally desirable**.

**Trigger**: [RES-001] — Design question cannot be answered without systematic analysis of the dependency graph, semantic alignment, and architectural constraints.

**Scope**: Primitives-wide — affects `swift-bit-vector-primitives` (tier 12), `swift-bitset-primitives` (tier 12), `swift-storage-primitives` (tier 14), `swift-buffer-primitives` (tier 15), and `swift-memory-primitives` (tier 13). [RES-002a]

## Question

Should `Bit.Vector` and `Bitset` be migrated onto the `Storage ← Buffer ← Data Structure` stack, or should they remain independent packages with their own storage management?

## Analysis

### Constraint 1: Circular Dependency (Hard Blocker)

The most critical finding is structural. Three higher-tier packages already depend on `swift-bit-vector-primitives`:

| Package | Tier | Dependency | Usage |
|---------|------|-----------|-------|
| `swift-memory-primitives` | 13 | `Bit_Vector_Primitives` | `Memory.Pool` allocation bitmap |
| `swift-storage-primitives` | 14 | `Bit_Vector_Primitives` | `Storage.Inline._slots: Bit.Vector.Static<4>` for per-slot initialization tracking |
| `swift-buffer-primitives` | 15 | `Bit_Vector_Primitives` | `Buffer.Slab.Header.bitmap: Bit.Vector` for slab occupancy tracking |

If `swift-bit-vector-primitives` were to depend on any of these packages, SPM would reject the package graph as a **circular dependency**:

```
swift-bit-vector-primitives (tier 12)
    ↓ proposed: depends on
swift-storage-primitives (tier 14)
    ↓ existing: depends on
swift-bit-vector-primitives (tier 12)  ← CYCLE
```

This is not a convention or style issue. It is a hard constraint enforced by the Swift Package Manager. The dependency graph cannot contain cycles, period.

**Verification**: `swift-storage-primitives/Package.swift:54` declares `.package(path: "../swift-bit-vector-primitives")`. `Storage Primitives Core` target (line 64) and `Storage Inline Primitives` target (line 103) both depend on `"Bit Vector Primitives"`. The usage is structural — `Bit.Vector.Static<4>` is embedded as a stored property in `Storage.Inline.Header`, `Storage.Pool.Inline.Header`, and `Storage.Arena.Inline.Header` for per-slot initialization tracking.

### Constraint 2: Tier Ordering (Architectural Invariant)

The five-layer architecture enforces downward-only dependencies:

```
Bit Vector Primitives       (tier 12)
Memory Primitives           (tier 13)  ← depends on Bit Vector
Storage Primitives          (tier 14)  ← depends on Bit Vector
Buffer Primitives           (tier 15)  ← depends on Bit Vector
Data Structures             (tier 15+) ← depends on Buffer
```

Bit Vector at tier 12 cannot depend on Storage (tier 14) or Buffer (tier 15) without violating the tier invariant. This is not just convention — the tier numbers are computed from the dependency graph, and the dependency graph has the cycle constraint above.

### Constraint 3: Semantic Mismatch

Even if the structural constraints were somehow resolved, the semantic fit is poor.

#### 3a. Element Granularity Mismatch

The Storage/Buffer stack is **element-oriented**. `Storage.Heap<Element>` allocates contiguous memory for `Element`-sized values. `Buffer.Linear<Element>` manages a growable array of `Element`-sized slots.

For bit collections:
- **Storage element** = `UInt` (8 bytes, the word)
- **Logical element** = a single bit (1/64th of a word)
- `Bit.Pack<UInt>` bridges between the two granularities

If `Bit.Vector` composed `Storage.Heap<UInt>`, the storage would manage `UInt` words. But `Bit.Vector`'s public API operates on bits, not words. Every public method would need to translate between the two abstraction levels — which is exactly what `Bit.Pack` already does, without the overhead of a storage layer.

#### 3b. Count Semantics Mismatch

| Concept | Storage/Buffer | Bit.Vector | Bitset |
|---------|---------------|------------|--------|
| **Count** | Number of elements (words) | Number of bit positions | Popcount (cardinality) |
| **Capacity** | Maximum elements (words) | Maximum bit position | Maximum representable member |
| **isEmpty** | No elements | No bit positions | No members (all bits zero) |
| **Growth trigger** | Element insertion | Append (extend sequence) | Member insertion (expand universe) |

`Buffer.Linear.Header` tracks word count. But `Bit.Vector.Dynamic._count` tracks *bit count*. Composing Buffer.Linear would give Bit.Vector a word-count tracker it doesn't need, while still requiring its own bit-count field. The buffer's count/capacity tracking is wasted overhead.

#### 3c. Initialization Tracking Mismatch

`Storage.Heap` tracks which slots are initialized via `Storage.Initialization` (range-based for Heap, bitmap-based for Inline). This is essential for data structures with ~Copyable elements — deinit must know which slots to clean up.

Bit collections have **no initialization tracking need**. All words are zero-initialized at creation and remain valid `UInt` values throughout their lifetime. There is no partial initialization, no moved-from slots, no element lifecycle to track. The initialization tracking in Storage.Heap would be pure overhead.

#### 3d. Initialization Tracking Circularity

`Storage.Inline` uses `Bit.Vector.Static<4>` *for* its initialization tracking. If `Bit.Vector` composed `Storage`, the resulting type would contain a `Bit.Vector.Static<4>` for tracking the initialization state of `UInt` words that are always fully initialized. This is architecturally absurd — a bitmap tracking the initialization of a bitmap's own backing words, with the tracking never triggering because all words are always valid.

### Could Package Splitting Break the Cycle?

One could split `swift-bit-vector-primitives` into:
- `swift-bit-vector-static-primitives` (tier 12): Just `Bit.Vector.Static`
- `swift-bit-vector-primitives` (tier 15+): Base `Bit.Vector`, Dynamic, Bounded, Inline — composing Storage/Buffer

Storage would depend on the static-only package. The main package would depend on Storage. No cycle.

**Evaluation**: This introduces significant costs for negligible benefit:

| Cost | Impact |
|------|--------|
| **Package fragmentation** | Splits a cohesive 5-type family across two packages at different tiers |
| **Semantic incoherence** | `Bit.Vector.Static` at tier 12, `Bit.Vector` at tier 15+ — the "base" type at a higher tier than the variant |
| **Dependency multiplication** | Every package that needs both variants must import two packages |
| **Maintenance burden** | Shared logic (popcount, ones iteration, Bit.Pack addressing) must be factored into a third shared package or duplicated |
| **Benefit** | Replaces 10 lines of init/deinit in `Bit.Vector` with Storage.Heap composition |

The 10 lines being replaced (`Bit.Vector.swift:63-81`):

```swift
if _wordCount > .zero {
    unsafe self._words = .allocate(capacity: _wordCount)
    unsafe _words.initialize(repeating: 0, count: _wordCount)
} else {
    unsafe self._words = .init(bitPattern: 0x1)!
}

deinit {
    if _wordCount > .zero {
        unsafe _words.deallocate()
    }
}
```

This is well-encapsulated, correct, and minimal. The cost of package splitting far exceeds the benefit of eliminating these lines.

### What About Bitset Composing Bit.Vector?

The deferred comment proposed: "Bitset: compose Bit.Vector to gain stack backing transitively."

This contradicts the **DECIDED** architecture from `bitset-architecture-ideal-model.md` (status: DECISION). That research document — with extensive prior art survey including Swift Collections, Rust `bit-set`/`bit-vec`, C++ `std::bitset`, and rhalbersma/bit_set — concluded:

> **Architecture**: Shared Kernel pattern. Both `Bit.Vector.*` and `Bitset.*` independently compose `Bit.Pack<UInt>` for bit-to-word addressing. Neither wraps the other.

Five reasons the composition pattern was rejected:

1. **Forces API bloat on Bit.Vector** — Bitset needs word-level bulk access for O(n/64) set algebra. Bit.Vector shouldn't expose this.
2. **Semantic mismatch on count** — Bit.Vector's count tracks positions; Bitset's count is popcount.
3. **Growth model mismatch** — Bit.Vector grows via append; Bitset grows by expanding universe.
4. **Leaky abstraction** — Rust's `get_ref()`/`get_mut()` demonstrates the problem.
5. **Precedent rejects it** — Swift Collections started with composition (GSoC PR #83) and moved to shared kernel.

Even if Bit.Vector were on the stack, the "compose Bit.Vector to gain stack backing transitively" plan is architecturally wrong. Bitset and Bit.Vector are siblings, not parent-child.

### What IS Appropriate for Bitset?

The Bit Collections Assessment correctly identifies that Bitset should **adopt Bit.Pack addressing**. This is independently valuable:

| Current (hand-rolled) | With Bit.Pack |
|----------------------|---------------|
| `member / bitsPerWord` | `Bit.Pack<UInt>.Location(...)` |
| `member % bitsPerWord` | `location.bit` |
| `1 << bitIndex` | `location.mask` |
| `bitsPerWord` constant per variant | Shared `Bit.Pack<UInt>` |

This eliminates duplicated addressing logic across all four Bitset variants without requiring any stack dependency. It is a pure internal refactor — the public API (which uses `Int` members) does not change.

### Comparison: Stack Migration vs. Current Architecture

| Criterion | Stack Migration | Current Architecture |
|-----------|----------------|---------------------|
| **Feasibility** | Blocked by circular dependency | Working |
| **Tier compliance** | Requires package split (tier 12 → tier 15+) | Compliant (tier 12) |
| **Semantic fit** | Poor — element-oriented stack vs. sub-element bit addressing | Natural — Bit.Pack bridges word/bit granularity |
| **Overhead** | Initialization tracking, count duplication, ARC wrapper | Zero overhead — direct pointer/ContiguousArray |
| **Complexity** | Package split, cross-tier imports, dual count tracking | Self-contained |
| **Lines eliminated** | ~10 (init/deinit in Bit.Vector) | N/A |
| **Lines added** | Package infrastructure, tier management, semantic translation | N/A |
| **Consistency with ecosystem** | Would match Stack, Set.Ordered, Array | Does not match — but bit collections are structurally different from element collections |

### Prior Art: Do Other Ecosystems Put Bit Collections on Their Buffer Stack?

**No.**

| Ecosystem | Bit Collection Storage | Uses Buffer/Allocator Stack? |
|-----------|----------------------|------------------------------|
| Rust `bitvec` | `Vec<usize>` directly | No — uses stdlib Vec, not custom allocator |
| Rust `bit-set` | `BitVec<u32>` (which wraps `Vec<u32>`) | No — uses stdlib Vec |
| Swift Collections | `[_Word]` directly | No — uses stdlib Array |
| C++ `std::bitset` | Inline array | No — no allocator |
| C++ `boost::dynamic_bitset` | `std::vector<Block>` | No — uses stdlib vector |
| Java `BitSet` | `long[]` | No — primitive array |
| .NET `BitArray` | `int[]` | No — primitive array |

In every ecosystem, bit collections store their words in the simplest available container (`Vec`, `Array`, `vector`, primitive array). None uses a custom storage or buffer abstraction. The word array is an implementation detail; the bit-level addressing is the abstraction.

## Outcome

**Status**: DECISION

### Decision: Do NOT migrate Bit.Vector or Bitset to the Storage ← Buffer stack.

The migration is:

1. **Structurally impossible** without package splitting — circular dependency between `swift-bit-vector-primitives` (tier 12) and `swift-storage-primitives` (tier 14) via `Bit.Vector.Static<4>` in Storage.Inline headers.

2. **Semantically mismatched** — the stack manages element-granularity lifecycle; bit collections operate at sub-element (bit) granularity with different count, capacity, growth, and initialization semantics.

3. **Architecturally undesirable** — package splitting would fragment a cohesive type family for negligible benefit (replacing 10 lines of well-encapsulated init/deinit).

4. **Without precedent** — no shipped production system in any ecosystem puts bit collections on a custom buffer/storage stack.

### What SHOULD happen (independent actions):

| Action | Priority | Justification |
|--------|----------|---------------|
| **Bitset adopts Bit.Pack addressing** | Medium | Eliminates hand-rolled `member / bitsPerWord` across 4 variants. Pure internal refactor, no public API change, no dependency change. |
| **Bit.Vector sentinel pattern documented** | Low | The `0x1` non-null sentinel in `Bit.Vector.init` is unusual but correct. A `// WORKAROUND` comment per [PATTERN-016] suffices. |
| **No composition of Bitset over Bit.Vector** | — | Per DECIDED architecture (shared kernel, not composition). Both compose Bit.Pack independently. |
| **No stack migration for any variant** | — | Per this analysis. |

### Supersedes

This document supersedes the "Deferred" recommendations in `Research/data structures/Bit Collections Assessment.md` §Cross-Cutting Observations regarding stack migration. The Assessment's observation about Bit.Pack adoption for Bitset remains valid and is carried forward.

## References

### Structural evidence
- `swift-storage-primitives/Package.swift:54` — dependency on `swift-bit-vector-primitives`
- `swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift:327` — `Bit.Vector.Static<4>` stored property
- `swift-memory-primitives/Package.swift:45` — dependency on `swift-bit-vector-primitives`
- `swift-buffer-primitives/Package.swift:52` — dependency on `swift-bit-vector-primitives`

### Prior research
- [bitset-architecture-ideal-model](bitset-architecture-ideal-model.md) — DECISION: shared kernel, not composition
- [bit-vector-type-organization](bit-vector-type-organization.md) — RECOMMENDATION: all variants in one package
- [bit-vector-primitives-reducibility](bit-vector-primitives-reducibility.md) — RECOMMENDATION: all five types are primitive
- [Bit Collections Assessment](data%20structures/Bit%20Collections%20Assessment.md) — ASSESSMENT: migration status (deferred items superseded here)
- [storage-primitives-comparative-analysis](storage-primitives-comparative-analysis.md) — Storage stack design rationale

### Source
- `swift-bit-vector-primitives/Sources/Bit Vector Primitives/Bit.Vector.swift` — base type with manual allocation
- `swift-bit-vector-primitives/Sources/Bit Vector Primitives/Bit.Vector.Dynamic.swift` — ContiguousArray-backed variant
- `swift-bitset-primitives/Sources/Bitset Primitives/Bitset.swift` — hand-rolled bit addressing
