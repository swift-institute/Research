# Bit Vector Primitives Reducibility Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-08
status: RECOMMENDATION
depends_on: [bit-vector-type-organization]
---
-->

## Context

swift-bit-vector-primitives (tier 12) contains five types after the consolidation recommended in [bit-vector-type-organization](bit-vector-type-organization.md):

| Type | Storage | Copyable | Count Tracking | Growth |
|------|---------|:--------:|:--------------:|:------:|
| `Bit.Vector` | `UnsafeMutablePointer<UInt>` | No | No (capacity only) | None |
| `Bit.Vector.Static<N>` | `InlineArray<N, UInt>` | Yes | No (full capacity) | None |
| `Bit.Vector.Dynamic` | `ContiguousArray<UInt>` | Yes | Yes | Unbounded |
| `Bit.Vector.Bounded` | `ContiguousArray<UInt>` | Yes | Yes | Bounded (throws) |
| `Bit.Vector.Inline<N>` | `InlineArray<N, UInt>` | Yes | Yes | Bounded (throws) |

Primitives are defined as irreducible building blocks — atomic types that cannot be decomposed further. They answer "what must exist?" (Layer 1 in the five-layer architecture). This document asks: are Dynamic, Bounded, and Inline truly irreducible?

## Question

Are the five types in swift-bit-vector-primitives all genuinely primitive, or should some be relocated to a higher layer?

## Analysis

### 1. Irreducibility Assessment

**Bit.Vector** — Irreducible. Heap-allocated via `UnsafeMutablePointer<UInt>`, ~Copyable, `nonmutating set` through raw pointer, `Ones.View` captures pointer for deinit-safe iteration. No stdlib container can replicate these semantics. This is a raw infrastructure bitmap.

**Bit.Vector.Static\<N\>** — Irreducible. Fixed-capacity inline bitmap with zero overhead beyond `InlineArray<N, UInt>`. No count tracking — every bit position is valid. Pure bitmap with set/clear/popcount/ones. The minimal possible representation for a compile-time-sized bit map.

**Bit.Vector.Dynamic** — Reducible in principle. Wraps `ContiguousArray<UInt>` (stdlib) plus a `_count: Bit.Index.Count` field. Growth logic (`append`, `resize`, `removeAll(keepingCapacity:)`) delegates to `ContiguousArray.append` and `ContiguousArray.reserveCapacity`. The type COULD be decomposed into "Bit.Vector.Static\<N\> + ContiguousArray growth logic" — but this decomposition would duplicate the word-level bit packing that the type shares with the rest of the family.

**Bit.Vector.Bounded** — Reducible in principle. Same storage as Dynamic (`ContiguousArray<UInt>`) plus a fixed `_capacity`. Pre-allocates storage at creation; append throws `.overflow` at capacity. Could be decomposed into "pre-allocated ContiguousArray + bit packing."

**Bit.Vector.Inline\<N\>** — Reducible in principle. Same storage as Static (`InlineArray<N, UInt>`) plus a `_count`. Could be decomposed into "Bit.Vector.Static\<N\> + count field."

**The bit-packing kernel is irreducible.** All five types share the same irreducible operations: word-level masking (`word |= mask`, `word &= ~mask`, `word ^= mask`), `Bit.Pack<UInt>.Location` computation, Wegner/Kernighan sparse iteration (`word &= word &- 1`), hardware popcount aggregation. These cannot be decomposed further. The question is whether the container/growth logic layered atop this kernel makes the overall type non-primitive.

### 2. Precedent Analysis

#### swift-array-primitives (tier 15)

Array-primitives includes five variants with varying growth characteristics:

| Type | Growth | Primitive? |
|------|--------|:----------:|
| `Array` (Dynamic) | Unbounded via `Buffer.Linear` | Yes |
| `Array.Fixed` | None (fixed at creation) | Yes |
| `Array.Static<N>` | Bounded (throws overflow) | Yes |
| `Array.Small<N>` | Unbounded (inline → heap spillover) | Yes |
| `Array.Bounded<N>` | None (compile-time dimension) | Yes |

**Verdict**: Growth semantics do NOT disqualify a type from being primitive. `Array` (Dynamic) has unbounded growth via buffer reallocation and is treated as a first-class primitive. `Array.Small` has automatic inline-to-heap spillover and is also primitive.

#### swift-buffer-primitives (tier 15)

Buffer-primitives includes growable types:

| Type | Growth | Primitive? |
|------|--------|:----------:|
| `Buffer.Linear` | Unbounded (`_grow()` doubles capacity) | Yes |
| `Buffer.Linear.Bounded` | None (fixed capacity) | Yes |
| `Buffer.Linear.Inline<N>` | None (inline, fixed) | Yes |
| `Buffer.Ring` | Unbounded (wrapping + growth) | Yes |
| `Buffer.Slab` | Unbounded (bitmap-tracked slots) | Yes |

**Verdict**: `Buffer.Linear._grow()` performs heap reallocation with capacity doubling. This is explicit growth logic in a primitives package. The pattern is: Core declares headers (irreducible bookkeeping), Composed targets add growth and operations.

#### swift-storage-primitives (tier 14)

Storage-primitives does NOT include growth:

| Type | Growth | Primitive? |
|------|--------|:----------:|
| `Storage.Heap` | None (fixed at creation) | Yes |
| `Storage.Inline<N>` | None (fixed capacity) | Yes |

**Verdict**: Storage is purely irreducible. But Storage is the lowest-level substrate — Buffer builds growth ON TOP of Storage. The growth lives one layer up (Buffer), not in Storage itself.

#### Summary of Precedent

| Package | Includes growth? | Justification |
|---------|:----------------:|---------------|
| storage-primitives | No | Substrate — growth belongs in Buffer |
| buffer-primitives | Yes | Buffer = Storage + growth discipline |
| array-primitives | Yes | Array = Buffer + element semantics |
| bit-vector-primitives | Yes | Bit.Vector.Dynamic = word storage + bit packing + growth |

Growth at the primitives layer is established practice. The project treats "primitive" as "Foundation-free atomic building block," not "zero-growth fixed-size type."

### 3. Semantic Coherence

The Primitives Layering document defines the semantic coherence test:

1. **Can you describe the package's purpose in one sentence without using "and"?**
   → "Packed boolean storage in word-sized units." — Yes.

2. **Would a type from another domain fit naturally in this package's namespace?**
   → No. `Bit.Vector.Dynamic` is a packed bit container. `Array.Dynamic` is an element container. They share a word ("Dynamic") but not a domain.

3. **If you split this package, would the halves each have coherent identities?**
   → "Infrastructure bitmaps" (Vector + Static) vs. "User-facing bit containers" (Dynamic + Bounded + Inline). Both halves have identities, but they share ALL implementation — word masking, popcount, Wegner/Kernighan iteration, `Bit.Pack<UInt>` addressing. Splitting forces duplicating this shared kernel.

**All five types answer the same conceptual question**: "How do I store and manipulate packed bits?" They share:
- The same algebra: bitwise AND/OR/XOR/NOT at the word level
- The same addressing: `Bit.Pack<UInt>.Location` for word/bit decomposition
- The same iteration: Wegner/Kernighan for sparse ones traversal
- The same statistics: popcount via `nonzeroBitCount` aggregation

They differ only in **storage strategy** (heap vs. inline, pointer vs. ContiguousArray) and **capacity discipline** (fixed, bounded, growable). These are variants of one concept, not different concepts.

### 4. Dependency Direction

| Type | Dependencies | Conclusion |
|------|-------------|------------|
| `Bit.Vector` | stdlib (`UnsafeMutablePointer`) | Primitive — raw memory |
| `Bit.Vector.Static<N>` | stdlib (`InlineArray`) | Primitive — inline storage |
| `Bit.Vector.Dynamic` | stdlib (`ContiguousArray`), `Bit_Pack_Primitives` (tier 11) | Valid primitive dependency |
| `Bit.Vector.Bounded` | stdlib (`ContiguousArray`), `Bit_Pack_Primitives` (tier 11) | Valid primitive dependency |
| `Bit.Vector.Inline<N>` | stdlib (`InlineArray`), `Bit_Pack_Primitives` (tier 11) | Valid primitive dependency |

No standards dependencies. No Foundation. No upward or cross-layer dependencies. All dependencies flow strictly downward. Dynamic/Bounded/Inline add no new package dependencies beyond what Vector and Static already require.

The tier stays at 12 regardless of which types are included.

### 5. Consumer Analysis

**Current consumers** (from dependency search):

| Type | Consumer | Purpose |
|------|----------|---------|
| `Bit.Vector` (~Copyable) | `Storage.Inline._slots` | Per-slot initialization tracking |
| `Bit.Vector` (~Copyable) | `Memory.Pool._allocationBits` | Double-free detection |
| `Bit.Vector` (~Copyable) | `Buffer.Slab.Header.bitmap` | Slab occupancy tracking |
| `Bit.Vector.Static<N>` | `Storage.Inline._slots` | 256-bit inline tracking |
| `Bit.Vector.Static<N>` | `Buffer.Slab.Header.Static<N>.bitmap` | Copyable slab tracking |
| `Bit.Vector.Dynamic` | — | Zero current consumers |
| `Bit.Vector.Bounded` | — | Zero current consumers |
| `Bit.Vector.Inline<N>` | — | Zero current consumers |

**All current consumers are infrastructure** (Storage, Buffer, Memory) — all Layer 1 primitives packages.

**Dynamic, Bounded, and Inline have zero consumers.** They exist because the [bit-vector-type-organization](bit-vector-type-organization.md) consolidation moved them from `Array<Bit>.Vector.*` in array-primitives (where they also had zero external consumers).

**Projected consumers**: Bit set operations, bloom filters, permission bitmasks, feature flags, protocol negotiation fields — all of which could appear at any layer. The Dynamic/Bounded/Inline types provide user-facing interfaces for these use cases that Bit.Vector (~Copyable) cannot serve.

### 6. Alternative Organization

#### Option A: Split — Infrastructure vs. User-Facing

```
swift-bit-vector-primitives (tier 12, unchanged)
├── Bit.Vector           (~Copyable, heap, fixed)
└── Bit.Vector.Static<N> (Copyable, inline, fixed)

swift-bit-container-primitives (new, tier 12)
├── Bit.Vector.Dynamic   (Copyable, heap, growable)
├── Bit.Vector.Bounded   (Copyable, heap, bounded)
└── Bit.Vector.Inline<N> (Copyable, inline, bounded)
```

**Pro**: Clean separation — infrastructure bitmaps vs. user-facing containers.
**Con**: Duplicated bit-packing kernel across two packages. Forces the new package to either duplicate `Bit.Pack<UInt>` usage patterns or depend on bit-vector-primitives (making them the same tier with artificial separation). The Primitives Layering doc warns against splits that "create artificial boundaries" — users needing both infrastructure and user-facing bitmaps would import two packages for one concept.

#### Option B: Relocate to Foundations

Move Dynamic/Bounded/Inline to swift-foundations as composed building blocks.

**Pro**: Honest about composition — these wrap stdlib containers with bit-packing logic.
**Con**: Violates precedent — Array (Dynamic) and Buffer.Linear are growable types in primitives. Would require either relocating Array and Buffer too (massive disruption) or accepting inconsistency. Also, foundations have dependencies on standards; these types have no standards dependency, making them a poor fit for Layer 3.

#### Option C: Keep Current Organization (All Five in bit-vector-primitives)

**Pro**: Consistent with Array and Buffer precedent. Shared implementation kernel. Clean namespace. No artificial boundaries. No tier inflation.
**Con**: Broadens the scope of "primitive" to include container-like types. Dynamic/Bounded/Inline currently have zero consumers.

### 7. The "Must Exist" Test

The Five Layer Architecture defines primitives as answering "what must exist?"

- **Bit.Vector**: Must exist — Storage.Inline, Memory.Pool, and Buffer.Slab depend on it.
- **Bit.Vector.Static\<N\>**: Must exist — Storage.Inline and Buffer.Slab.Header.Static depend on it.
- **Bit.Vector.Dynamic**: Does not currently MUST exist. Zero consumers.
- **Bit.Vector.Bounded**: Does not currently MUST exist. Zero consumers.
- **Bit.Vector.Inline\<N\>**: Does not currently MUST exist. Zero consumers.

However, the "must exist" test is forward-looking, not retrospective. Array-primitives defined `Array` (Dynamic) before any consumer used it — the type was created because a growable, Foundation-free array primitive MUST exist for the ecosystem to function without stdlib's `Array` (which brings Foundation). The same argument applies to bit vectors: a growable, Foundation-free packed bit container MUST exist for the ecosystem.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Keep the current organization — all five types remain in swift-bit-vector-primitives.

### Rationale

1. **Consistent with established precedent.** Array-primitives includes unbounded-growth types (`Array`, `Array.Small`). Buffer-primitives includes growable types (`Buffer.Linear`, `Buffer.Ring`). Excluding growth from bit-vector-primitives would create an inconsistency that requires either (a) accepting the inconsistency or (b) relocating Array and Buffer too. Neither is justified.

2. **Semantic coherence holds.** All five types answer the same question ("how do I store packed bits?"), share the same algebra (word-level bitwise operations), share the same addressing (`Bit.Pack<UInt>.Location`), and share the same iteration (Wegner/Kernighan). They differ only in storage strategy and capacity discipline — variants of one concept, not different concepts.

3. **Splitting would duplicate the irreducible kernel.** The word masking, popcount, `Bit.Pack<UInt>` addressing, and Wegner/Kernighan iteration are identical across all five types. Splitting into two packages forces either code duplication or a dependency from the new package back to bit-vector-primitives (which achieves nothing architecturally).

4. **No dependency concern.** Dynamic/Bounded/Inline add zero new package dependencies. The tier stays at 12. All dependencies flow strictly downward.

5. **Foundations is the wrong home.** Layer 3 (Foundations) is defined as "composed building blocks from primitives + standards." Dynamic/Bounded/Inline have no standards dependencies — they compose only stdlib types and lower-tier primitives. They fit Layer 1's definition: "Foundation-free atomic building blocks."

6. **Zero consumers is a timing issue, not an architectural signal.** The types were consolidated from array-primitives where they also had zero external consumers. They exist to provide the ecosystem with Foundation-free packed bit containers. Array-primitives created its growable types proactively on the same basis.

### Qualification

The recommendation is conditional on this implicit contract being maintained: **primitives packages may include growth/container semantics when the underlying data representation (bit packing into words) is itself irreducible and domain-specific.** Bit packing is not a general composition pattern — it is a specific representation that requires domain knowledge (word masking, popcount, sparse iteration). This distinguishes bit vectors from a hypothetical "Wrapper<ContiguousArray<UInt>>" that merely delegates to stdlib.

If the project ever tightens the definition of "primitive" to exclude growth semantics entirely, this decision should be revisited — but that change would also require relocating `Array`, `Array.Small`, `Buffer.Linear`, and `Buffer.Ring`, which is a much larger architectural question outside the scope of this document.

### No Action Required

The current organization is correct. No types need to be relocated.

## References

- Prior consolidation research: [bit-vector-type-organization](bit-vector-type-organization.md)
- Primitives definition: `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Requirements.md`
- Tier architecture: `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md`
- Layering philosophy: `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Layering.md`
- Five Layer Architecture: `/Users/coen/Developer/swift-institute/Documentation.docc/Five Layer Architecture.md`
- Bit.Vector source: `/Users/coen/Developer/swift-primitives/swift-bit-vector-primitives/Sources/Bit Vector Primitives/`
- Array precedent: `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.swift`
- Buffer precedent: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Linear Primitives/Buffer.Linear.swift`
- Storage precedent: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift`
