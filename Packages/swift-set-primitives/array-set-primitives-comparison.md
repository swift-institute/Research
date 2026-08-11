# Array vs Set Primitives Comparative Analysis

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: DECISION
---
-->

## Context

This analysis compares `swift-array-primitives` and `swift-set-primitives` to identify naming patterns, structural differences, and opportunities for alignment.

## Executive Summary

| Aspect | Array Primitives | Set Primitives | Alignment |
|--------|------------------|----------------|-----------|
| Type Families | 2 (Array, Array<Bit>.Vector) | 2 (Set.Ordered, Set<Bit>.Vector) | Aligned |
| Variant Naming | Fixed, Static, Small, Inline | Fixed, Inline, Small | **Divergent** |
| Module Count | 7 | 6 | Similar |
| File Count | ~36 | ~59 | Set larger |
| Copyability Model | Conditional + unconditional | Conditional + unconditional | Aligned |
| Error Hoisting | Yes | Yes | Aligned |

## 1. Type Family Structure

### Array Primitives

```
Array<Element: ~Copyable>
├── (base)                    Growable, heap
├── .Fixed                    Fixed-count, heap
├── .Static<capacity>         Fixed-capacity, inline, variable count
├── .Small<inlineCapacity>    Hybrid inline→heap
├── .Inline<N>                Fixed N, all initialized (typealias)
└── .Indexed<Tag>             Phantom-typed wrapper

Array<Bit>.Vector
├── (base)                    Growable packed bits
├── .Fixed                    Fixed-capacity packed bits
└── .Inline<wordCount>        Inline packed bits
```

### Set Primitives

```
Set<Element: Hash.Protocol & ~Copyable>
└── .Ordered
    ├── (base)                Growable, heap, insertion order
    ├── .Fixed              Fixed-capacity, heap
    ├── .Inline<capacity>     Fixed-capacity, inline
    ├── .Small<inlineCapacity> Hybrid inline→heap
    └── .Indexed<Tag>         Phantom-typed wrapper

Set<Bit>.Vector
├── (base)                    Growable packed bits
├── .Fixed                    Fixed-capacity packed bits
├── .Inline<wordCount>        Inline packed bits
└── .Small<inlineWordCount>   Hybrid inline→heap
```

## 2. Variant Naming Comparison

| Concept | Array | Set.Ordered | Set<Bit>.Vector | Recommendation |
|---------|-------|-------------|-----------------|----------------|
| Fixed-count heap | `.Fixed` | `.Fixed` | `.Fixed` | **Align to `.Fixed`** |
| Variable inline | `.Static<N>` | `.Inline<N>` | `.Inline<N>` | **Align to `.Inline`** |
| Hybrid inline→heap | `.Small<N>` | `.Small<N>` | `.Small<N>` | Already aligned |
| All-initialized inline | `.Inline<N>` | — | — | Array-specific |

### Critical Naming Divergences

#### Issue 1: Fixed vs Fixed

| Package | Type | Name | Semantics |
|---------|------|------|-----------|
| Array | Fixed-count heap | `.Fixed` | Count fixed at init |
| Set.Ordered | Fixed-capacity heap | `.Fixed` | Capacity fixed, count varies |
| Set<Bit>.Vector | Fixed-capacity | `.Fixed` | Capacity fixed, count varies |

**Analysis**: Both "Fixed" in sets mean fixed *capacity* (not count), while Array.Fixed means fixed *count*. The naming is inconsistent:

- `Array.Fixed` = all N elements always initialized
- `Set.Ordered.Fixed` = max N elements, throws on overflow
- `Set<Bit>.Vector.Fixed` = max N bits, throws on overflow

**Recommendation**: `Set.Ordered.Fixed` should remain `.Fixed` because:
1. It matches the semantic meaning (Fixed capacity)
2. `Array.Fixed` has different semantics (all elements initialized)
3. `Set<Bit>.Vector.Fixed` was renamed for consistency with `Array<Bit>.Vector.Fixed` which has the same semantics

#### Issue 2: Static vs Inline

| Package | Type | Name | Semantics |
|---------|------|------|-----------|
| Array | Variable-count inline | `.Static<N>` | 0 to N elements |
| Set.Ordered | Variable-count inline | `.Inline<N>` | 0 to N elements |
| Array | All-initialized inline | `.Inline<N>` | Exactly N elements (typealias) |

**Analysis**: Array uses `.Static` for variable-count inline storage, while Set uses `.Inline`. Array reserves `.Inline` for the all-initialized variant (typealias to `Swift.InlineArray`).

**Recommendation**: This divergence is justified:
- Array has two inline variants with different semantics
- Set only has one inline variant
- Renaming would break the Array type hierarchy

## 3. Module/Target Structure

### Array Primitives (7 modules)

| Module | Purpose |
|--------|---------|
| Array Primitives Core | Type declarations |
| Array Dynamic Primitives | Growable array ops |
| Array Fixed Primitives | Fixed-count ops |
| Array Static Primitives | Fixed-capacity inline ops |
| Array Small Primitives | SmallVec ops |
| Array Bit Primitives | Packed bit arrays |
| Array Primitives | Umbrella |

### Set Primitives (6 modules)

| Module | Purpose |
|--------|---------|
| Set Primitives Core | Type declarations |
| Set Ordered Primitives | Ordered set ops |
| Set Bit Vector Primitives | Packed bit sets |
| Set Primitives Sequence | Collection conformances |
| Set Primitives | Umbrella |
| Set Primitives Test Support | Test utilities |

### Structural Difference

Array separates by *variant* (Dynamic, Fixed, Static, Small).
Set separates by *family* (Ordered, Bit Vector) with variants Static.

**Rationale**: Array variants have more distinct implementations requiring separate constraint handling. Set variants share more code within each family.

## 4. Copyability Model

### Identical Pattern

| Condition | Array | Set |
|-----------|-------|-----|
| Heap + Element: Copyable | Copyable (CoW) | Copyable (CoW) |
| Heap + Element: ~Copyable | ~Copyable | ~Copyable |
| Inline (any Element) | ~Copyable | ~Copyable |
| Bit-packed | Copyable | Copyable |

Both packages correctly implement conditional copyability for heap types and unconditional ~Copyable for inline types (due to deinit requirements).

## 5. Error Type Patterns

### Identical Hoisting Pattern

Both packages hoist error types to module level for typed throws compatibility:

```swift
// Array
public enum __ArrayStaticError { ... }
extension Array.Static { typealias Error = __ArrayStaticError }

// Set
public enum __SetOrderedError { ... }
extension Set.Ordered { typealias Error = __SetOrderedError }
```

### Error Case Comparison

| Error Case | Array | Set |
|------------|-------|-----|
| Index out of bounds | `.indexOutOfBounds` | `.bounds` |
| Capacity exceeded | `.overflow` | `.overflow` |
| Invalid capacity | — | `.invalidCapacity` |
| Empty operation | — | `.empty` |
| Stride too large | `.strideExceedsSlotSize` | — |
| Alignment mismatch | `.alignmentExceedsStorageAlignment` | — |

**Naming difference**: Array uses `.indexOutOfBounds`, Set uses `.bounds`.

**Recommendation**: Align to `.bounds` (shorter, equally clear).

## 6. File Organization

### Identical One-Type-Per-File Pattern

Both follow [API-IMPL-005]:

```
Array.Static.swift           → Array.Static type
Array.Static Copyable.swift  → Copyable extensions
Array.Static ~Copyable.swift → ~Copyable extensions

Set.Ordered.Fixed.swift           → Set.Ordered.Fixed type
Set.Ordered.Fixed.Indexed.swift   → Indexed wrapper
```

### Extension Naming

| Category | Array Pattern | Set Pattern |
|----------|---------------|-------------|
| Copyable-only | `Type Copyable.swift` | `Type Copyable.swift` |
| ~Copyable-only | `Type ~Copyable.swift` | `Type ~Copyable.swift` |
| Algebra ops | — | `Type.Algebra.swift` |
| Relations | — | `Type.Relation.swift` |
| Sequence drain | — | `Type+Sequence.Drain.swift` |
| Memory access | — | `Type+Span.Protocol.swift` |

**Observation**: Set has richer extension categorization due to set algebra operations.

## 7. Nested Accessor Patterns

### Array<Bit>.Vector (Property View)

```swift
bits.ones.forEach { }           // Ones accessor
bits.statistic.true             // Statistic accessor
bits.all.false                  // All accessor
try bits.toggle.returning(i)    // Toggle accessor
bits.byte.set(0xFF, at: 0)      // Byte accessor
```

### Set<Bit>.Vector (Algebra Accessor)

```swift
a.algebra.union(b)              // Union
a.algebra.intersection(b)       // Intersection
a.algebra.subtract(b)           // Difference
a.algebra.symmetric.difference(b)  // Symmetric difference
a.relation.isSubset(of: b)      // Subset test
```

**Pattern Difference**: Array uses property views for bit manipulation. Set uses nested accessors for set algebra.

## 8. Test Structure

| Aspect | Array | Set |
|--------|-------|-----|
| Framework | Swift Testing | Swift Testing |
| File naming | `Array.*.Tests.swift` | `Set.*.Tests.swift` |
| Model tests | — | Yes (`*.Model Tests.swift`) |
| Test support module | No | Yes |

**Gap**: Array lacks model-based testing that Set has.

## 9. Dependencies

### Array Dependencies (8)

- Standard Library Extensions
- Bit Primitives
- Index Primitives
- Collection Primitives
- Property Primitives
- Sequence Primitives
- Range Primitives
- Storage Primitives

### Set Dependencies (12)

- Standard Library Extensions
- Bit Primitives
- Index Primitives
- Hash Primitives
- Hash Table Primitives
- Storage Primitives
- Collection Primitives
- Sequence Primitives
- Property Primitives
- Memory Primitives
- Ordinal Primitives
- Cardinal Primitives

**Observation**: Set has 4 more dependencies due to hash table requirements and richer index arithmetic.

## 10. Recommended Alignments

### Already Aligned

| Aspect | Status |
|--------|--------|
| Bit type naming | `.Vector`, `.Vector.Fixed`, `.Vector.Static` |
| Copyability model | Conditional + unconditional |
| Error hoisting | Module-level with typealias |
| File organization | One type per file |
| Generic parameter style | `<let N: Int>` value generics |
| Sendable conformance | `@unchecked Sendable where Element: Sendable` |

### Justified Divergences

| Aspect | Array | Set | Justification |
|--------|-------|-----|---------------|
| `.Static` vs `.Inline` | `.Static<N>` | `.Inline<N>` | Array reserves `.Inline` for all-initialized |
| `.Fixed` vs `.Fixed` | `.Fixed` (fixed count) | `.Fixed` (fixed capacity) | Different semantics |
| Module split | By variant | By family | Different code sharing patterns |

### Potential Improvements

| Improvement | Package | Action |
|-------------|---------|--------|
| Add `.Small` to Set<Bit>.Vector | Set | Already present |
| Error case naming | Array | Consider `.bounds` over `.indexOutOfBounds` |
| Model-based tests | Array | Add model test files |
| Test support module | Array | Add test support target |

## 11. Summary Table

| Feature | Array | Set | Notes |
|---------|-------|-----|-------|
| Base variant | `Array` | `Set.Ordered` | Both growable, heap |
| Fixed-count heap | `Array.Fixed` | — | Array-specific |
| Fixed-capacity heap | — | `Set.Ordered.Fixed` | Set-specific |
| Variable inline | `Array.Static<N>` | `Set.Ordered.Static<N>` | Different names |
| All-initialized inline | `Array.Inline<N>` | — | Array-specific (typealias) |
| Hybrid SmallVec | `Array.Small<N>` | `Set.Ordered.Small<N>` | Aligned |
| Bit growable | `Array<Bit>.Vector` | `Set<Bit>.Vector` | Aligned |
| Bit fixed | `Array<Bit>.Vector.Fixed` | `Set<Bit>.Vector.Fixed` | Aligned |
| Bit inline | `Array<Bit>.Vector.Static<W>` | `Set<Bit>.Vector.Static<W>` | Aligned |
| Bit SmallVec | — | `Set<Bit>.Vector.Small<W>` | Set has extra |
| Phantom indexing | `Array.Indexed<Tag>` | `Set.Ordered.Indexed<Tag>` | Aligned pattern |
| Error hoisting | `__ArrayXXXError` | `__SetXXXError` | Aligned pattern |
| Typed throws | Yes | Yes | Aligned |
| ~Copyable support | Full | Full | Aligned |

## Conclusion

The two packages are well-aligned on fundamental patterns:
- Conditional copyability
- Error hoisting
- File organization
- Bit type naming (after recent rename)

The naming divergences (`.Static` vs `.Inline`, `.Fixed` vs `.Fixed`) are justified by semantic differences between array and set operations. No further alignment is recommended at this time.

## References

- swift-array-primitives Package.swift
- swift-set-primitives Package.swift
- [API-NAME-001] Namespace Structure
- [API-IMPL-005] One Type Per File
