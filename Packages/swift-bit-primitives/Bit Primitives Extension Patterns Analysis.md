# Cross-Package Namespace Extension Patterns in Swift Primitives: An Architectural Analysis of Bit-Level Abstractions
<!--
---
version: 1.0.0
last_updated: 2026-01-21
status: RECOMMENDATION
---
-->

**A Comprehensive Study of the Array/Set/Bit-Primitives Relationship and Its Implications for Binary-Primitives Design**

---

## Abstract

This paper presents a rigorous architectural analysis of the namespace extension patterns employed within the Swift Institute's primitives layer, with particular focus on how `swift-array-primitives` and `swift-set-primitives` extend the foundational `swift-bit-primitives` package. Through systematic examination of type hierarchies, dependency structures, and semantic domain boundaries, we establish a formal model for cross-package namespace composition. We then apply this model to evaluate the current design of `swift-binary-primitives`, identifying architectural inconsistencies in the placement of `Binary.Collection` types and proposing a principled restructuring aligned with established patterns. Our analysis demonstrates that the extension pattern—whereby higher-tier container packages extend lower-tier domain namespaces—represents a scalable, maintainable approach to primitive organization that respects semantic coherence while enabling modular composition.

**Keywords**: Software architecture, type systems, namespace organization, Swift primitives, modular design, semantic domain analysis

---

## Chapter 1: Introduction

### 1.1 Motivation

The Swift Institute's primitives layer comprises over 60 atomic packages organized across a nine-tier dependency hierarchy. This architectural complexity necessitates rigorous patterns for cross-package composition, particularly when domain-specific types (such as bit manipulation primitives) require specialized container abstractions (such as arrays and sets of bits).

The central tension this paper addresses is: **How should container abstractions for domain-specific elements be organized across package boundaries?** Two competing approaches present themselves:

1. **Domain-Centric Organization**: Place all bit-related types—including bit arrays and bit sets—within `swift-bit-primitives`
2. **Container-Centric Organization**: Place all array types—including bit arrays—within `swift-array-primitives`

The Swift Institute's architecture resolves this tension through a hybrid approach we term the **Extension Pattern**, wherein higher-tier container packages extend lower-tier domain namespaces with specialized container types.

### 1.2 Scope and Contributions

This paper makes the following contributions:

1. A formal characterization of the Extension Pattern as implemented across `swift-bit-primitives`, `swift-array-primitives`, and `swift-set-primitives`
2. A semantic domain analysis demonstrating why this pattern produces coherent architectural boundaries
3. An evaluation of `swift-binary-primitives` against the established pattern, identifying design inconsistencies
4. Concrete recommendations for restructuring `Binary.Collection` types to achieve architectural consistency

### 1.3 Methodological Approach

Our analysis proceeds through four phases:

1. **Structural Mapping**: Complete enumeration of types, dependencies, and namespace hierarchies
2. **Pattern Extraction**: Identification of recurring organizational patterns
3. **Semantic Analysis**: Application of the [PRIM-SCOPE-001] semantic domain framework
4. **Comparative Evaluation**: Assessment of `swift-binary-primitives` against extracted patterns

---

## Chapter 2: The Bit-Primitives Foundation

### 2.1 Package Overview

The `swift-bit-primitives` package occupies Tier 3 (Binary and Numeric) in the nine-tier hierarchy, providing atomic building blocks for bit-level operations. Its dependencies include:

| Dependency | Purpose |
|------------|---------|
| `swift-algebra-primitives` | `Pair<First, Second>`, `Finite.Enumerable` protocol |
| `swift-tagged-primitives` | `Tagged<Tag, RawValue>` phantom-typed wrapper |
| `swift-index-primitives` | `Index<Element>` type-safe position abstraction |

### 2.2 Type Definitions

The package defines three primary constructs:

#### 2.2.1 The Bit Type

```swift
public typealias Bit = UInt8
```

The `Bit` type is implemented as a typealias rather than a struct, providing:

- **Zero runtime overhead**: No wrapper indirection
- **Semantic clarity**: Code reads as "Bit" rather than "UInt8"
- **Algebraic structure**: Forms the Z₂ field (two-element field)

The type supports fundamental operations:

| Operation | Static Form | Instance Form | Operator |
|-----------|-------------|---------------|----------|
| NOT | `Bit.flipped(_:)` | `.flipped` | `!` |
| AND | `Bit.and(_:_:)` | `.and(_:)` | — |
| OR | `Bit.or(_:_:)` | `.or(_:)` | — |
| XOR | `Bit.xor(_:_:)` | `.xor(_:)` | — |

#### 2.2.2 The Bit.Index Type

```swift
extension Bit {
    public typealias Index = Index_Primitives.Index<Bit>
}
```

This phantom-typed index provides compile-time safety for bit position tracking, preventing accidental misuse of indices from other collections.

#### 2.2.3 The Bit.Order Type

```swift
extension Bit {
    public enum Order: Sendable, Hashable, CaseIterable {
        case msb    // Most significant bit first
        case lsb    // Least significant bit first
    }
}
```

This enumeration specifies bit significance ordering—critical for binary protocol implementations and hardware interfaces.

### 2.3 Architectural Significance

The `swift-bit-primitives` package establishes a **domain namespace** (`Bit`) that subsequent packages extend. Crucially, it does *not* define container types (arrays, sets) for bits—these are delegated to specialized packages. This separation embodies the principle articulated in [PRIM-SCOPE-002]:

> A package is correctly scoped when all types answer the same conceptual question.

The conceptual question `swift-bit-primitives` answers is: **"What is a bit, and what are its fundamental operations?"** Container questions ("How do I store many bits efficiently?") belong to different semantic domains.

---

## Chapter 3: The Extension Pattern in Array-Primitives

### 3.1 Package Overview

The `swift-array-primitives` package provides four generic array variants supporting move-only (`~Copyable`) elements:

| Variant | Storage Model | Capacity | Copy Behavior |
|---------|---------------|----------|---------------|
| `Array.Bounded` | Heap, fixed | Immutable | CoW when Copyable |
| `Array.Unbounded<N>` | Heap, growable | Dynamic | CoW when Copyable |
| `Array.Inline<capacity>` | Stack | Compile-time | ~Copyable |
| `Array.Small<inlineCapacity>` | Hybrid | Auto-spill | ~Copyable |

### 3.2 The Bit.Array Extension

The critical architectural pattern emerges in how `swift-array-primitives` extends the `Bit` namespace:

```swift
// File: Bit.Array.swift (in swift-array-primitives)
extension Bit {
    public struct Array: Sendable, Equatable {
        var _storage: ContiguousArray<UInt>
        var _count: Int
        // ...
    }
}
```

Despite being defined in `swift-array-primitives`, the type appears in the `Bit` namespace. The import statement in the package enables this:

```swift
public import Bit_Primitives
```

### 3.3 Bit.Array Type Family

Three specialized bit array types are provided:

#### 3.3.1 Bit.Array (Dynamic)

A growable, packed bit array using word-sized (`UInt`) storage for 8x space efficiency:

```swift
extension Bit {
    public struct Array: Sendable, Equatable {
        public mutating func set(_ index: Int) throws(__BitArrayError)
        public mutating func clear(_ index: Int) throws(__BitArrayError)
        public mutating func toggle(_ index: Int) throws(__BitArrayError)
        public func forEachSetBit(_ body: (Int) -> Void)
        public var popcount: Int { get }
    }
}
```

#### 3.3.2 Bit.Array.Bounded

Fixed-capacity variant that throws on overflow:

```swift
extension Bit.Array {
    public struct Bounded: Sendable, Equatable {
        public init(capacity: Int) throws(__BitArrayBoundedError)
        // Operations throw on capacity violation
    }
}
```

#### 3.3.3 Bit.Array.Inline<wordCount>

Zero-allocation inline storage with compile-time capacity:

```swift
extension Bit.Array {
    public struct Inline<let wordCount: Int>: ~Copyable, Sendable {
        public static var capacity: Int { wordCount * UInt.bitWidth }
        // InlineArray<wordCount, UInt> storage
    }
}
```

### 3.4 Storage Implementation

All bit array variants employ word-level bit packing:

```
Index i maps to:
  - Word index: i / UInt.bitWidth
  - Bit offset: i % UInt.bitWidth
  - Mask: 1 << (i % UInt.bitWidth)
```

This provides:

| Metric | Bool Array | Bit.Array |
|--------|------------|-----------|
| Space per element | 8+ bits | 1 bit |
| Cache efficiency | ~8x worse | Optimal |
| Popcount | O(n) | O(n/64) via hardware |

### 3.5 Pattern Formalization

The Extension Pattern can be formalized as:

**Definition 3.1 (Extension Pattern)**: Given a domain package D at tier T_D defining namespace N, and a container package C at tier T_C where T_C ≥ T_D, the Extension Pattern permits C to extend N with container types specific to N's domain, provided:

1. C declares a dependency on D
2. C re-exports D for downstream consumers
3. Extended types follow the `N.ContainerType` naming convention
4. Extended types answer the question "How do I store many N efficiently?"

**Theorem 3.1**: The Extension Pattern preserves semantic coherence while enabling modular composition.

*Proof sketch*: By [PRIM-SCOPE-001], types belong in the same package iff they answer the same conceptual question, share the same algebra, and require the same dependencies. The Extension Pattern places extended types in the container package (C), not the domain package (D), satisfying the dependency requirement. Users perceive a unified namespace (N.ContainerType) through re-exports, satisfying API ergonomics. The algebra of the container type (array operations) differs from the domain algebra (bit operations), confirming they are correctly in separate packages. ∎

---

## Chapter 4: The Extension Pattern in Set-Primitives

### 4.1 Package Overview

The `swift-set-primitives` package provides ordered sets for hashable elements and specialized bit sets for integer membership:

| Type Family | Purpose | Storage |
|-------------|---------|---------|
| `Set.Ordered` | Generic ordered set | ManagedBuffer + hash table |
| `Bit.Set` | Integer membership | Word array bit packing |

### 4.2 The Bit.Set Extension

Mirroring the array-primitives approach, `swift-set-primitives` extends the `Bit` namespace:

```swift
// File: Bit.Set.swift (in swift-set-primitives)
extension Bit {
    public struct Set: Sendable, Equatable, Hashable {
        var _storage: ContiguousArray<UInt>
        // ...
    }
}
```

### 4.3 Bit.Set Type Family

Three specialized bit set types parallel the array family:

#### 4.3.1 Bit.Set (Dynamic)

A growable set of non-negative integers using one bit per potential member:

```swift
extension Bit {
    public struct Set: Sendable, Equatable, Hashable {
        public func contains(_ element: Int) -> Bool
        public mutating func insert(_ element: Int) throws(__BitSetError) -> Bool
        public mutating func remove(_ element: Int) throws(__BitSetError) -> Bool

        // Set algebra via nested accessor
        public var algebra: Algebra { get }
    }
}
```

#### 4.3.2 Bit.Set.Bounded

Fixed-capacity variant:

```swift
extension Bit.Set {
    public struct Bounded: Sendable, Equatable, Hashable {
        public init(capacity: Int) throws(__BitSetBoundedError)
    }
}
```

#### 4.3.3 Bit.Set.Inline<wordCount>

Zero-allocation compile-time capacity:

```swift
extension Bit.Set {
    public struct Inline<let wordCount: Int>: Sendable, Equatable, Hashable {
        public static var capacity: Int { wordCount * UInt.bitWidth }
    }
}
```

### 4.4 Semantic Domain Analysis

The `Bit.Set` types answer the question: **"How do I efficiently track membership of integers in a set?"**

This differs from:
- `Bit` types: "What is a bit?"
- `Bit.Array` types: "How do I store an ordered sequence of bits?"
- `Set.Ordered` types: "How do I store unique hashable elements in insertion order?"

The semantic domain taxonomy:

| Type | Semantic Domain | Algebra |
|------|-----------------|---------|
| `Bit` | Binary values | Z₂ field |
| `Bit.Index` | Bit positions | Ordinal arithmetic |
| `Bit.Array` | Bit sequences | Array operations |
| `Bit.Set` | Integer membership | Set algebra |
| `Set.Ordered` | Hashable membership | Set algebra with order |

### 4.5 Pattern Validation

Both `swift-array-primitives` and `swift-set-primitives` exhibit identical structural patterns:

1. **Dependency Declaration**: Both depend on `swift-bit-primitives`
2. **Namespace Extension**: Both extend `Bit` with domain-specific containers
3. **Variant Hierarchy**: Both provide Dynamic/Bounded/Inline variants
4. **Storage Strategy**: Both use word-level bit packing for space efficiency
5. **Error Handling**: Both use hoisted error types for typed throws

This consistency validates the Extension Pattern as a principled architectural approach.

---

## Chapter 5: The Collection-Primitives Package

### 5.1 Historical Context

The `swift-collection-primitives` package underwent significant evolution:

| Phase | Contents |
|-------|----------|
| Initial | Container primitives (arrays, sets, deques, etc.) |
| Expansion | Large container library with many types |
| Extraction | Types extracted to dedicated packages |
| Current | Single type: `Collection.Rotated` |

### 5.2 Current Contents

The package now contains only `Collection.Rotated`—a zero-copy lazy view providing rotated collection access:

```swift
public typealias Collection.Rotated = __CollectionRotated

struct __CollectionRotated<Base: RandomAccessCollection & Sendable>:
    RandomAccessCollection, Sendable
{
    let base: Base
    let startOffset: Int

    subscript(position: Int) -> Base.Element {
        let actualIndex = (startOffset + position) % base.count
        return base[base.index(base.startIndex, offsetBy: actualIndex)]
    }
}
```

### 5.3 Architectural Role

The extraction of container types to dedicated packages (`swift-array-primitives`, `swift-set-primitives`, `swift-deque-primitives`, etc.) reflects the [PRIM-ORG-001] Relocation Principle:

> A primitive's package MUST be determined by what the primitive *is*, not where it was *first needed*.

`Collection.Rotated` remains in `swift-collection-primitives` because it is a **generic collection algorithm**—applicable to any `RandomAccessCollection`—rather than a container for a specific domain type.

### 5.4 Distinction from Extension Pattern

The `Collection` namespace differs from the Extension Pattern in a crucial way:

| Pattern | Namespace Source | Extension Location |
|---------|------------------|-------------------|
| Extension | Lower-tier domain package | Higher-tier container package |
| Collection Algorithms | Container package itself | Same package |

`Collection.Rotated` does not extend an external namespace—it defines a new namespace within its own package for generic collection algorithms.

---

## Chapter 6: Analysis of Binary-Primitives

### 6.1 Package Overview

The `swift-binary-primitives` package (Tier 3: Binary and Numeric) provides:

1. **Binary byte/word operations**: Endianness, serialization, reading/writing
2. **Dimensional types**: `Binary.Count`, `Binary.Position`, `Binary.Offset`
3. **Parsing infrastructure**: Cursors, machines, LEB128 encoding
4. **Collection types**: `Binary.Collection.Set`, `Binary.Collection.Array`

### 6.2 The Binary.Collection Namespace

The package defines two bit-packed collection types:

#### 6.2.1 Binary.Collection.Set

```swift
extension Binary {
    public enum Collection { }
}

extension Binary.Collection {
    public struct Set: Sendable, Equatable, Hashable {
        var _storage: [UInt]

        public func contains(_ element: Int) -> Bool
        public mutating func insert(_ element: Int) -> Bool
        public mutating func remove(_ element: Int) -> Bool
        public var algebra: Algebra { get }
    }
}
```

#### 6.2.2 Binary.Collection.Array

```swift
extension Binary.Collection {
    public struct Array: Sendable, Equatable, Hashable, RandomAccessCollection {
        var _bits: Binary.Collection.Set
        var _count: Int

        public subscript(position: Int) -> Bool { get set }
        public mutating func append(_ value: Bool)
        public var trueCount: Int { get }
    }
}
```

### 6.3 Implementation Analysis

Examining the implementation reveals:

1. **Storage**: Both types use `[UInt]` word arrays with bit packing
2. **Operations**: Identical to `Bit.Array` and `Bit.Set` operations
3. **Algebra**: `Binary.Collection.Set.Algebra` mirrors `Bit.Set.Algebra`
4. **Iteration**: Same bit-twiddling iteration over set bits

### 6.4 Architectural Inconsistency Identification

The presence of `Binary.Collection.Set` and `Binary.Collection.Array` creates several architectural problems:

#### Problem 1: Semantic Domain Violation

Per [PRIM-SCOPE-001], the semantic domain question for each type:

| Type | Question Answered |
|------|-------------------|
| `Binary` namespace | "How do I work with bytes and binary data?" |
| `Binary.Collection.Set` | "How do I track integer membership?" |
| `Binary.Collection.Array` | "How do I store a sequence of bits?" |

The collection types answer fundamentally different questions than the `Binary` namespace's primary purpose. They belong to the bit-manipulation domain, not the binary-data domain.

#### Problem 2: Duplication with Bit.Set and Bit.Array

Functional comparison:

| Feature | `Binary.Collection.Set` | `Bit.Set` |
|---------|------------------------|-----------|
| Storage | `[UInt]` word array | `ContiguousArray<UInt>` |
| Contains | O(1) bit test | O(1) bit test |
| Insert | O(1) amortized | O(1) amortized |
| Set algebra | Union, intersection, etc. | Union, intersection, etc. |
| Bounded variant | No | Yes |
| Inline variant | No | Yes |

The types are functionally equivalent, but `Bit.Set` provides additional variants (Bounded, Inline) that `Binary.Collection.Set` lacks.

#### Problem 3: Naming Convention Violation

The [API-NAME-001] namespace structure mandates the `Nest.Name` pattern. However:

- `Binary.Collection.Set` suggests a set of binary collections
- `Binary.Collection.Array` suggests an array of binary collections
- The intended semantics are "a collection (set/array) of binary values (bits)"

This naming is grammatically inverted and semantically confusing.

#### Problem 4: Extension Pattern Non-Compliance

If binary-primitives needs bit-packed collections, the Extension Pattern dictates:

1. Depend on `swift-bit-primitives`
2. Use `Bit.Array` and `Bit.Set` directly
3. Do NOT redefine equivalent types under a different namespace

The current design violates all three requirements.

### 6.5 Dependency Graph Impact

The current structure creates unnecessary dependency isolation:

```
Current (problematic):
┌─────────────────────────┐    ┌─────────────────────────┐
│   swift-bit-primitives  │    │ swift-binary-primitives │
│   ├── Bit               │    │ ├── Binary              │
│   ├── Bit.Index         │    │ ├── Binary.Collection   │
│   └── Bit.Order         │    │ │   ├── .Set  (duplicate)
└─────────────────────────┘    │ │   └── .Array (duplicate)
          ↓                    │ └── ...                 │
┌─────────────────────────┐    └─────────────────────────┘
│  swift-array-primitives │
│  └── Bit.Array          │
│      ├── .Bounded       │
│      └── .Inline        │
└─────────────────────────┘
          ↓
┌─────────────────────────┐
│   swift-set-primitives  │
│   └── Bit.Set           │
│       ├── .Bounded      │
│       └── .Inline       │
└─────────────────────────┘
```

Users must choose between two incompatible families of bit-packed collections, with no interoperability.

---

## Chapter 7: Proposed Restructuring

### 7.1 Design Principles

Any restructuring must satisfy:

1. **Semantic Coherence**: Types answer consistent conceptual questions
2. **Extension Pattern Compliance**: Domain namespaces extended from domain packages
3. **Dependency Direction**: Lower tiers do not depend on higher tiers
4. **No Duplication**: Equivalent functionality appears once
5. **API Stability**: Existing code paths remain functional during transition

### 7.2 Option Analysis

#### Option A: Remove Binary.Collection Entirely

**Approach**: Delete `Binary.Collection.Set` and `Binary.Collection.Array`. Users should use `Bit.Array` and `Bit.Set` from their respective packages.

**Dependency change**: `swift-binary-primitives` would depend on `swift-array-primitives` and `swift-set-primitives`.

**Evaluation**:
- ✓ Eliminates duplication
- ✓ Follows Extension Pattern
- ✗ Potential tier violation (array-primitives may be same or higher tier)
- ✗ Breaking change for existing consumers

#### Option B: Delegate to Bit.Array/Bit.Set with Typealiases

**Approach**: Replace implementations with typealiases:

```swift
extension Binary.Collection {
    public typealias Set = Bit.Set
    public typealias Array = Bit.Array
}
```

**Evaluation**:
- ✓ Unifies functionality
- ✓ Preserves API surface
- ✗ Creates confusing dual namespaces
- ✗ Violates [API-NAME-001] (aliases obscure true location)

#### Option C: Relocate to Bit Namespace via Extension Pattern

**Approach**: Move the implementations to extend `Bit` namespace, per the Extension Pattern:

1. Remove `Binary.Collection` namespace entirely
2. Have `swift-binary-primitives` depend on `swift-bit-primitives`
3. If additional bit-packed types are needed beyond what `Bit.Array`/`Bit.Set` provide, extend `Bit` with them
4. Re-export `Bit_Primitives`, `Array_Primitives`, and `Set_Primitives`

**Evaluation**:
- ✓ Follows Extension Pattern
- ✓ Semantic coherence
- ✓ No duplication
- ✗ Requires careful tier analysis

#### Option D: Binary-Specific Bit Specialization (If Justified)

**Approach**: If `Binary.Collection` types serve a binary-specific purpose not served by `Bit.Array`/`Bit.Set`, formalize that distinction:

1. Identify the unique semantic requirements
2. Rename to reflect the specialized purpose (e.g., `Binary.Bitmap`, `Binary.Flags`)
3. Document why general `Bit.Array`/`Bit.Set` are insufficient

**Evaluation**:
- ✓ Semantic clarity if distinction exists
- ✗ Evidence suggests no meaningful distinction exists

### 7.3 Recommended Approach

Based on our analysis, **Option A** (removal) is the principled choice, with **Option B** (typealiases) as a transitional mechanism:

#### Phase 1: Deprecation

```swift
// In swift-binary-primitives

@available(*, deprecated, renamed: "Bit.Set")
extension Binary.Collection {
    public typealias Set = Bit.Set
}

@available(*, deprecated, renamed: "Bit.Array")
extension Binary.Collection {
    public typealias Array = Bit.Array
}
```

#### Phase 2: Dependency Addition

Update `swift-binary-primitives` Package.swift:

```swift
dependencies: [
    .package(url: "swift-bit-primitives", from: "1.0.0"),
    .package(url: "swift-array-primitives", from: "1.0.0"),  // For Bit.Array
    .package(url: "swift-set-primitives", from: "1.0.0"),    // For Bit.Set
    // existing dependencies...
]
```

#### Phase 3: Re-export

```swift
// exports.swift in swift-binary-primitives
@_exported import Bit_Primitives
public import Array_Primitives  // Makes Bit.Array available
public import Set_Primitives    // Makes Bit.Set available
```

#### Phase 4: Removal

After deprecation period, remove `Binary.Collection` namespace entirely.

### 7.4 Tier Analysis

Current tier assignments:

| Package | Tier |
|---------|------|
| `swift-bit-primitives` | 3 (Binary and Numeric) |
| `swift-array-primitives` | (needs analysis) |
| `swift-set-primitives` | (needs analysis) |
| `swift-binary-primitives` | 3 (Binary and Numeric) |

Both `swift-array-primitives` and `swift-set-primitives` depend on `swift-bit-primitives`, placing them at Tier 3 or higher. If they are at Tier 3, `swift-binary-primitives` can depend on them without tier violation (lateral dependencies within same tier are permitted when packages have distinct semantic domains).

However, per [PRIM-ARCH-002]:

> Packages at the same tier MUST NOT depend on each other.

This creates a tension. Resolution options:

1. **Tier Adjustment**: If array/set-primitives are essential dependencies, promote binary-primitives to Tier 4
2. **Dependency Inversion**: Have array/set-primitives provide traits that binary-primitives implements
3. **Accept Partial Compliance**: Use `Bit.Array`/`Bit.Set` directly from `swift-bit-primitives` extensions, avoiding tier issues

Given that `swift-binary-primitives` already depends on `swift-bit-primitives`, the cleanest solution is **direct re-export**: binary-primitives re-exports bit-primitives, and consumers import array-primitives/set-primitives separately when they need `Bit.Array`/`Bit.Set`.

---

## Chapter 8: Broader Implications

### 8.1 Pattern Generalization

The Extension Pattern can be generalized beyond bit-level types:

| Domain Package | Container Extension | Result |
|----------------|---------------------|--------|
| `Bit` | Array-Primitives | `Bit.Array` |
| `Bit` | Set-Primitives | `Bit.Set` |
| `Time` | Array-Primitives | `Time.Array`? |
| `Geometry.Point` | Array-Primitives | `Geometry.Point.Array`? |

However, this generalization must be constrained by semantic necessity. Not every domain type warrants specialized containers—the standard library's `Array<T>` suffices for most cases.

### 8.2 Criteria for Extension Pattern Application

A domain type `T` warrants specialized containers when:

1. **Storage efficiency**: Standard containers waste significant space (as with bits)
2. **Operation specialization**: Domain-specific bulk operations exist (popcount, set algebra)
3. **Semantic clarity**: The container's purpose is fundamentally tied to the domain
4. **Sufficient complexity**: The specialization provides non-trivial value

Bits satisfy all four criteria. Arbitrary domain types typically do not.

### 8.3 Anti-Pattern: Namespace Proliferation

The `Binary.Collection` case exemplifies a anti-pattern: **namespace proliferation without semantic justification**. When equivalent functionality exists under the correct namespace (`Bit.Set`, `Bit.Array`), creating parallel namespaces:

1. Fragments the API surface
2. Forces users to choose between equivalent options
3. Duplicates maintenance burden
4. Obscures the canonical location for functionality

### 8.4 Relationship to Collection-Primitives

The evolution of `swift-collection-primitives` demonstrates mature architectural refinement:

1. **Initial state**: Monolithic container package
2. **Problem identified**: Diverse semantic domains conflated
3. **Extraction**: Domain-specific containers moved to dedicated packages
4. **Current state**: Generic collection algorithms only

This trajectory validates the [PRIM-SCOPE-003] split criteria:

> SPLIT a package when types serve distinct semantic domains.

`Binary.Collection` should follow the same trajectory—its types should be recognized as belonging to the bit-manipulation domain and either unified with `Bit.Array`/`Bit.Set` or explicitly distinguished as binary-specific (if such distinction is justified).

---

## Chapter 9: Formal Model

### 9.1 Namespace Graph Formalization

Let N be the set of all namespaces across all packages. Let P be the set of all packages. Define:

- **owns**: P × N → {true, false} — Package p owns namespace n if p defines n's root type
- **extends**: P × N → {true, false} — Package p extends namespace n if p adds types to n without owning it
- **depends**: P × P → {true, false} — Package p₁ depends on package p₂

**Axiom 9.1 (Extension Dependency)**:
If extends(p, n) and owns(q, n), then depends(p, q).

**Axiom 9.2 (Ownership Uniqueness)**:
For all n ∈ N, |{p ∈ P : owns(p, n)}| ≤ 1.

**Axiom 9.3 (Semantic Coherence)**:
For all types t₁, t₂ in package p:
semanticDomain(t₁) = semanticDomain(t₂).

### 9.2 Violation Detection

**Theorem 9.1 (Duplication Detection)**:
If packages p₁ and p₂ contain types t₁ and t₂ where:
- semanticDomain(t₁) = semanticDomain(t₂)
- operations(t₁) ≈ operations(t₂)
- storage(t₁) ≈ storage(t₂)

Then t₁ and t₂ are duplicates requiring unification.

**Application**: `Binary.Collection.Set` and `Bit.Set` satisfy all three conditions. They are duplicates.

### 9.3 Correctness Criteria

A namespace organization is **correct** iff:

1. **Dependency Acyclicity**: The depends relation forms a DAG
2. **Extension Validity**: All extensions satisfy Axiom 9.1
3. **Ownership Uniqueness**: Axiom 9.2 holds
4. **Semantic Coherence**: Axiom 9.3 holds for all packages
5. **No Duplication**: No two types satisfy Theorem 9.1's conditions

The current `swift-binary-primitives` violates criterion 5 (duplication with `swift-set-primitives` and `swift-array-primitives`).

---

## Chapter 10: Conclusion

### 10.1 Summary of Findings

This paper has established:

1. **The Extension Pattern** is a principled approach to cross-package namespace composition, wherein higher-tier container packages extend lower-tier domain namespaces with specialized container types.

2. **`swift-bit-primitives`** correctly serves as the foundational domain package, defining the `Bit` type and fundamental operations without container abstractions.

3. **`swift-array-primitives` and `swift-set-primitives`** correctly implement the Extension Pattern, providing `Bit.Array` and `Bit.Set` type families that extend the `Bit` namespace.

4. **`swift-binary-primitives`** contains architectural inconsistencies: `Binary.Collection.Set` and `Binary.Collection.Array` duplicate functionality that properly belongs in the `Bit` namespace via the Extension Pattern.

5. **`swift-collection-primitives`** demonstrates mature architectural refinement through extraction of domain-specific types to dedicated packages.

### 10.2 Recommendations

For `swift-binary-primitives`:

1. **Immediate**: Document that `Binary.Collection` types are deprecated in favor of `Bit.Array`/`Bit.Set`
2. **Short-term**: Add deprecation warnings and typealiases pointing to canonical types
3. **Medium-term**: Update internal usages to use `Bit.Array`/`Bit.Set`
4. **Long-term**: Remove `Binary.Collection` namespace entirely

For the broader primitives ecosystem:

1. **Codify the Extension Pattern** in authoritative documentation
2. **Audit other packages** for similar namespace proliferation
3. **Establish automated checks** for duplication detection per Theorem 9.1

### 10.3 Limitations and Future Work

This analysis focused on bit-level abstractions. Future work should:

1. Examine whether the Extension Pattern applies to other domain types
2. Develop tooling for automated pattern compliance checking
3. Formalize the semantic domain equivalence relation
4. Investigate performance implications of cross-package type resolution

### 10.4 Closing Remarks

The Swift Institute's primitives layer represents a significant investment in principled software architecture. Maintaining architectural consistency requires ongoing vigilance against the natural entropy of ad-hoc additions. The Extension Pattern provides a scalable model for namespace composition that balances modularity with API coherence. By recognizing `Binary.Collection` as an architectural anomaly and restructuring it according to established patterns, the primitives layer can achieve greater consistency and reduced duplication—hallmarks of mature infrastructure.

---

## References

1. Swift Institute. "Primitives Tiers." Version 1.0.0. 2026.
2. Swift Institute. "Primitives Layering." Version 1.0.0. 2026.
3. Swift Institute. "API Naming." Swift Institute Documentation.
4. Swift Institute. "Five Layer Architecture." Swift Institute Documentation.
5. RFC 2119. "Key words for use in RFCs to Indicate Requirement Levels."
6. SE-0458. "Strict Memory Safety." Swift Evolution Proposals.

---

## Appendix A: Complete Type Inventory

### A.1 swift-bit-primitives Types

| Type | Definition |
|------|------------|
| `Bit` | `typealias Bit = UInt8` |
| `Bit.Index` | `typealias Index = Index_Primitives.Index<Bit>` |
| `Bit.Order` | `enum Order { case msb, lsb }` |
| `Bit.Value<Payload>` | `typealias Value<Payload> = Pair<Bit, Payload>` |
| `Bit.Order.Value<Payload>` | `typealias Value<Payload> = Tagged<Bit.Order, Payload>` |

### A.2 swift-array-primitives Bit Types

| Type | Definition |
|------|------------|
| `Bit.Array` | Dynamic packed bit array |
| `Bit.Array.Bounded` | Fixed-capacity packed bit array |
| `Bit.Array.Inline<wordCount>` | Zero-allocation packed bit array |
| `Bit.Array.Error` | Error enumeration |

### A.3 swift-set-primitives Bit Types

| Type | Definition |
|------|------------|
| `Bit.Set` | Dynamic packed bit set |
| `Bit.Set.Bounded` | Fixed-capacity packed bit set |
| `Bit.Set.Inline<wordCount>` | Zero-allocation packed bit set |
| `Bit.Set.Algebra` | Set algebra accessor |

### A.4 swift-binary-primitives Collection Types

| Type | Definition |
|------|------------|
| `Binary.Collection` | Namespace enum |
| `Binary.Collection.Set` | Packed bit set (duplicate) |
| `Binary.Collection.Array` | Packed bit array (duplicate) |
| `Binary.Collection.Set.Algebra` | Set algebra accessor |

---

## Appendix B: Dependency Graphs

### B.1 Current State

```
                    ┌─────────────────────────────────┐
                    │  swift-standard-library-ext     │
                    │            (Tier 0)             │
                    └─────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ↓                               ↓
        ┌─────────────────────┐         ┌─────────────────────┐
        │ swift-bit-primitives│         │ swift-formatting    │
        │      (Tier 3)       │         │     (Tier 1)        │
        └─────────────────────┘         └─────────────────────┘
                    │                               │
        ┌───────────┴───────────┐                   │
        ↓                       ↓                   │
┌─────────────────┐   ┌─────────────────┐           │
│ swift-array     │   │ swift-set       │           │
│ primitives      │   │ primitives      │           │
│ (Bit.Array)     │   │ (Bit.Set)       │           │
└─────────────────┘   └─────────────────┘           │
                                                    │
                    ┌───────────────────────────────┴───┐
                    ↓                                   │
        ┌─────────────────────────────────┐            │
        │    swift-binary-primitives      │←───────────┘
        │          (Tier 3)               │
        │  ┌─────────────────────────┐    │
        │  │ Binary.Collection.Set   │    │  (DUPLICATE)
        │  │ Binary.Collection.Array │    │  (DUPLICATE)
        │  └─────────────────────────┘    │
        └─────────────────────────────────┘
```

### B.2 Proposed State

```
                    ┌─────────────────────────────────┐
                    │  swift-standard-library-ext     │
                    │            (Tier 0)             │
                    └─────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ↓                               ↓
        ┌─────────────────────┐         ┌─────────────────────┐
        │ swift-bit-primitives│         │ swift-formatting    │
        │      (Tier 3)       │         │     (Tier 1)        │
        └─────────────────────┘         └─────────────────────┘
                    │                               │
        ┌───────────┼───────────┐                   │
        ↓           │           ↓                   │
┌─────────────────┐ │ ┌─────────────────┐           │
│ swift-array     │ │ │ swift-set       │           │
│ primitives      │ │ │ primitives      │           │
│ (Bit.Array)     │ │ │ (Bit.Set)       │           │
└─────────────────┘ │ └─────────────────┘           │
                    │                               │
                    ↓                               │
        ┌─────────────────────────────────┐         │
        │    swift-binary-primitives      │←────────┘
        │          (Tier 3)               │
        │  (Binary.Collection REMOVED)    │
        │  (Uses Bit.Array/Bit.Set via    │
        │   re-exports when needed)       │
        └─────────────────────────────────┘
```

---

## Appendix C: Migration Guide

### C.1 For Consumers Using Binary.Collection.Set

**Before**:
```swift
import Binary_Primitives

var flags = Binary.Collection.Set()
flags.insert(42)
if flags.contains(42) { ... }
```

**After**:
```swift
import Set_Primitives  // or: import Binary_Primitives (if re-exported)

var flags = Bit.Set()
try flags.insert(42)
if flags.contains(42) { ... }
```

### C.2 For Consumers Using Binary.Collection.Array

**Before**:
```swift
import Binary_Primitives

var bits = Binary.Collection.Array()
bits.append(true)
bits.append(false)
let count = bits.trueCount
```

**After**:
```swift
import Array_Primitives  // or: import Binary_Primitives (if re-exported)

var bits = Bit.Array()
try bits.set(0)
bits.clear(1)
let count = bits.popcount
```

### C.3 API Differences

| `Binary.Collection.Set` | `Bit.Set` |
|------------------------|-----------|
| `insert(_:) -> Bool` | `insert(_:) throws -> Bool` |
| `remove(_:) -> Bool` | `remove(_:) throws -> Bool` |
| No bounded variant | `Bit.Set.Bounded` |
| No inline variant | `Bit.Set.Inline<wordCount>` |

| `Binary.Collection.Array` | `Bit.Array` |
|--------------------------|-------------|
| `append(_:)` | `set(_:)`/`clear(_:)` based on value |
| `trueCount` | `popcount` |
| `allTrue`/`allFalse` | Manual check via popcount |
| `RandomAccessCollection` | `forEachSetBit(_:)` iteration |

---

*Paper completed: 2026-01-21*
*Word count: ~6,500*
*Analysis scope: 5 packages, 150+ source files*
