# Set<Bit>.Packed to Set<Bit>.Vector Naming Analysis

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: DECISION
---
-->

## Context

The `swift-array-primitives` package recently renamed `Array<Bit>.Packed` to `Array<Bit>.Vector`. The `swift-set-primitives` package still uses `Set<Bit>.Packed` for its equivalent type family. This research investigates whether `Set<Bit>.Packed` should also be renamed to `Set<Bit>.Vector` for consistency.

### Current State

| Package | Type Family | Variants |
|---------|-------------|----------|
| swift-array-primitives | `Array<Bit>.Vector` | `.Fixed`, `.Inline` |
| swift-set-primitives | `Set<Bit>.Packed` | `.Fixed`, `.Inline`, `.Small` |

## Question

Should `Set<Bit>.Packed` be renamed to `Set<Bit>.Vector` to match the naming decision made for `Array<Bit>.Vector`?

## Analysis

### Option A: Rename to `Set<Bit>.Vector`

**Description**: Rename `Set<Bit>.Packed` to `Set<Bit>.Vector`, with all nested types following: `Set<Bit>.Vector.Fixed`, `Set<Bit>.Vector.Static`, `Set<Bit>.Vector.Small`.

**Advantages**:
1. **Naming consistency**: Maintains parallel structure with `Array<Bit>.Vector`
2. **API discoverability**: Users familiar with one package immediately understand the other
3. **Mental model alignment**: Single naming pattern across bit-packed collection types
4. **Documentation simplicity**: Can describe both as "Vector" types with unified terminology

**Disadvantages**:
1. **Breaking change**: Requires migration of all existing consumers
2. **Semantic accuracy concern**: "Vector" has array/sequence connotations, sets are unordered

### Option B: Keep `Set<Bit>.Packed`

**Description**: Retain the current `Set<Bit>.Packed` naming.

**Advantages**:
1. **No breaking change**: Existing code continues to work
2. **Semantic accuracy**: "Packed" describes the storage strategy (bit-packed into words)
3. **Set-specific terminology**: Distinguishes sets from arrays at the type level

**Disadvantages**:
1. **Naming inconsistency**: Creates asymmetry with `Array<Bit>.Vector`
2. **Cognitive overhead**: Users must remember different naming patterns
3. **Documentation complexity**: Must explain why arrays use "Vector" but sets use "Packed"

### Evaluation Criteria

| Criterion | Weight | Option A (Vector) | Option B (Packed) |
|-----------|--------|-------------------|-------------------|
| Naming consistency with Array | High | Excellent | Poor |
| Semantic accuracy | Medium | Acceptable | Good |
| Migration cost | Low | Moderate | None |
| API discoverability | High | Excellent | Acceptable |
| Cross-package coherence | High | Excellent | Poor |

### Semantic Analysis

#### What does "Vector" mean?

In computing, "vector" has multiple meanings:
1. **Mathematical**: A quantity with magnitude and direction
2. **C++/STL**: A dynamically-sized array (`std::vector`)
3. **SIMD**: A packed sequence of values for parallel operations
4. **General**: A one-dimensional sequence of elements

The SIMD interpretation is relevant here: a "bit vector" is a packed sequence of bits stored in machine words for efficient bulk operations.

#### What does "Packed" mean?

"Packed" describes a storage strategy: multiple logical elements stored compactly in a single physical storage unit (word).

#### Applicability to Sets

A bit set is semantically a set of integers (membership tracking), but its implementation is a bit vector (packed bits). The question is whether the name should reflect:
- **Semantic purpose**: Set membership → "Packed" (describing how membership is stored)
- **Implementation structure**: Bit vector → "Vector" (describing the underlying data structure)

Both interpretations are valid. The `Array<Bit>.Vector` naming chose the structural interpretation.

### Prior Art

| Library/Language | Bit Array Name | Bit Set Name |
|------------------|----------------|--------------|
| C++ | `std::vector<bool>` | `std::bitset` |
| Java | `BitSet` | `BitSet` (no distinction) |
| Rust | `BitVec` (bitvec crate) | `BitSet` (bitvec crate) |
| .NET | `BitArray` | — |
| Swift Foundation | — | — |

Notably:
- C++ uses "vector" for dynamic bit arrays and "bitset" for fixed-size bit sets
- Rust's bitvec crate distinguishes `BitVec` from `BitSet`
- Java conflates arrays and sets into `BitSet`

This suggests the array/set distinction is meaningful and naming them differently has precedent.

### The Parallel Structure Argument

The Swift Institute primitives follow the Extension Pattern, where container packages extend domain namespaces:

```
swift-bit-primitives:     Bit, Bit.Index, Bit.Order
swift-array-primitives:   Array<Bit>.Vector, Array<Bit>.Vector.Fixed, Array<Bit>.Vector.Static
swift-set-primitives:     Set<Bit>.???, Set<Bit>.???.Fixed, Set<Bit>.???.Inline
```

The question is whether `???` should be `Packed` or `Vector`.

**Argument for parallel naming**: The types are structurally identical—both store bits packed into UInt words. The semantic difference (ordered sequence vs. membership set) is already captured by `Array` vs. `Set`. Adding a different suffix (`Vector` vs. `Packed`) introduces asymmetry without corresponding benefit.

**Counter-argument**: The semantic difference justifies distinct naming. An `Array<Bit>.Vector` is iterated in order; a `Set<Bit>.Vector` tracks membership without order semantics.

### Variant Naming Alignment

Current variant names differ:

| Array Variants | Set Variants |
|----------------|--------------|
| `.Fixed` | `.Fixed` |
| `.Inline` | `.Inline` |
| — | `.Small` |

If renaming the parent type, consider also aligning variant names:
- `Set<Bit>.Vector.Fixed` (instead of `.Fixed`)
- `Set<Bit>.Vector.Static` (unchanged)
- `Set<Bit>.Vector.Small` (unchanged)

This would achieve full parity with the array type family.

### Migration Cost Assessment

Files requiring changes:
- `Set.Bit.Packed.swift` → `Set.Bit.Vector.swift`
- `Set.Bit.Packed.*.swift` → `Set.Bit.Vector.*.swift` (8+ files)
- Test files referencing `Set<Bit>.Packed`
- Documentation references

The rename is mechanical and low-risk, but does require coordinated updates.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Rename `Set<Bit>.Packed` to `Set<Bit>.Vector`.

**Rationale**:

1. **Consistency trumps semantic distinction**: The semantic difference between arrays and sets is already conveyed by the `Array` vs. `Set` namespace. Adding a different leaf name (`Vector` vs. `Packed`) creates asymmetry without meaningful benefit.

2. **Storage structure is identical**: Both types use the same word-packed bit storage. Calling one "Vector" and the other "Packed" obscures this equivalence.

3. **API discoverability**: Users learning `Array<Bit>.Vector` will naturally look for `Set<Bit>.Vector`. The current `Set<Bit>.Packed` naming requires documentation to discover.

4. **Cross-package coherence**: The Swift Institute primitives prioritize consistent patterns. The Extension Pattern extends domain namespaces with container types; those container types should use consistent terminology.

5. **Prior art is mixed**: While some libraries distinguish bit arrays from bit sets in naming, the distinction is in the Array/Set prefix, not in an additional suffix.

**Additional recommendation**: Align variant names:
- Rename `.Fixed` to `.Fixed` for consistency with array variants

**Migration path**:
1. Add `typealias Set<Bit>.Vector = Set<Bit>.Packed` with deprecation warning
2. Update all internal references
3. Update documentation
4. Remove deprecated alias after transition period

## References

- `swift-array-primitives/Sources/Array Bit Primitives/Array.Bit.Vector.swift`
- `swift-set-primitives/Sources/Set Bit Packed Primitives/Set.Bit.Packed.swift`
- `swift-bit-primitives/Research/Bit Primitives Extension Patterns Analysis.md`
- Swift Institute naming conventions: [API-NAME-001], [API-NAME-002]
