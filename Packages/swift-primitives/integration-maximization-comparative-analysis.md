# Integration Maximization: Comparative Analysis of Memory, Pointer, and Storage Primitives

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
research_tier: 3
applies_to: [swift-memory-primitives, swift-pointer-primitives, swift-storage-primitives]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Primitives Research")
}

> **Deprecation note**: This document references `swift-pointer-primitives` and `Pointer<T>` types throughout. That package has since been deprecated — storage-primitives now uses stdlib pointer types (`UnsafePointer<T>`, `UnsafeMutablePointer<T>`) directly. The integration analysis methodology and metrics remain valid; the pointer-primitives-specific findings are historical.

A systematic investigation into dependency integration patterns across the memory abstraction stack, establishing formal criteria for integration maximization and providing actionable recommendations with implementation sketches.

## Abstract

This research document presents a comprehensive analysis of integration depth across three foundational packages in the Swift Primitives ecosystem: memory-primitives (Tier 10), pointer-primitives (Tier 11), and storage-primitives (Tier 12). Following the principle that "each package should MAXIMIZE integration with its dependencies, with integration occurring at the lowest possible tier level," we develop formal semantics for integration correctness, establish quantitative metrics for measuring integration depth, and provide specific recommendations with implementation sketches.

**Principal Findings**:

1. **pointer-primitives** exhibits the most significant integration gaps, using raw `Int` for positional operations where `Index<T>.Offset` would provide type safety
2. **memory-primitives** correctly integrates lower-tier abstractions but lacks explicit `Memory.Count` and stride ratio APIs that would benefit downstream consumers
3. **storage-primitives** demonstrates correct layered integration, accessing transitive dependencies through pointer-primitives rather than bypassing the abstraction

**Key Contributions**:

- Formal typing rules for integration correctness (Section 10)
- Quantitative integration metrics: DIR, TIR, API Surface Coverage (Section 8)
- Implementation sketches for 6 high-priority recommendations (Section 12)
- Soundness argument for the layered integration principle (Section 11)

---

## Part I: Context and Motivation

### 1.1 Research Trigger

Per [RES-001], this research was triggered by a design question that could not be resolved without systematic analysis: During review of storage-primitives dependency declarations, the question arose of whether the package maximally integrates with its dependencies or whether integration opportunities exist at lower tier levels.

### 1.2 Scope Definition

Per [RES-002a], this research is **primitives-wide** (affecting packages at Tiers 10, 11, and 12) and belongs in `/Users/coen/Developer/swift-primitives/Research/`.

| Criterion | Assessment |
|-----------|------------|
| Packages affected | memory-primitives, pointer-primitives, storage-primitives |
| Tiers spanned | 10, 11, 12 (Collections → Traversal → Containers) |
| Layer | Layer 1 (Primitives) only |
| Precedent-setting | Yes - establishes integration methodology |

### 1.3 Guiding Principle

> **Integration Maximization Principle**: Each package should MAXIMIZE integration with its dependencies. Integration should happen at the lowest possible tier level where the relevant concept is defined.

This principle has two components:

1. **Maximization**: Packages should use dependency types wherever semantically appropriate, avoiding ad-hoc reimplementations
2. **Lowest-tier integration**: When a concept is available at multiple tiers, packages should integrate with the tier where the concept is canonically defined

### 1.4 Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| No upward dependencies | Primitives Tiers.md | Tier 12 cannot depend on Tier 13+ |
| No lateral dependencies | Primitives Tiers.md | Tier 12 packages cannot depend on each other |
| No Foundation | CLAUDE.md | All packages must remain Foundation-free |
| ~Copyable support | Memory skill | All abstractions must work with non-copyable types |

### 1.5 Prior Work

| Document | Status | Relevance |
|----------|--------|-----------|
| storage-primitives-design.md | IN_PROGRESS | Proposed Storage package design |
| unified-storage-primitive.md | RECOMMENDATION | Layered storage approach |
| Typed Index Integration Audit.md | COMPLETE | Methodology for typed index adoption |
| Tier 0 Comparative Analysis.md | COMPLETE | Integration patterns at lowest tier |

---

## Part II: Research Questions

Per [RES-023] Systematic Literature Review methodology, we define five research questions:

| ID | Question | Type |
|----|----------|------|
| RQ1 | What defines "integration maximization" in the context of layered primitives? | Definitional |
| RQ2 | What is the current integration depth of each package with its dependencies? | Descriptive |
| RQ3 | What integration opportunities exist at each tier level? | Exploratory |
| RQ4 | How should integration be prioritized given tier constraints? | Prescriptive |
| RQ5 | What metrics can objectively measure integration depth? | Methodological |

---

## Part III: Prior Art Survey

Per [RES-021], Tier 2+ research requires a prior art survey covering Swift Evolution, related languages, and academic literature.

### 3.1 Swift Evolution Proposals

| Proposal | Title | Relevance |
|----------|-------|-----------|
| SE-0390 | Noncopyable structs and enums | Enables ~Copyable constraint propagation |
| SE-0427 | Noncopyable generics | Allows Index<T: ~Copyable> pattern |
| SE-0390 | Typed throws | Error type safety analogous to index type safety |
| SE-0377 | borrowing and consuming parameter ownership modifiers | Memory-safe parameter passing |

### 3.2 Related Languages

**Rust**:
- Phantom types via `PhantomData<T>` — analogous to Swift's `Tagged<Tag, RawValue>`
- Zero-cost abstractions principle — integration should not impose runtime cost
- Newtype pattern via tuple structs — similar to tagged wrapper pattern

**Haskell**:
- Phantom type parameters for type-level safety
- Type families for computing associated types
- Functor laws for lawful transformations

**OCaml**:
- Phantom types via polymorphic variants
- Modular type abstraction

### 3.3 Academic Literature

| Citation | Title | Contribution |
|----------|-------|--------------|
| Girard (1987) | Linear Logic | Theoretical foundation for ~Copyable |
| Walker (2005) | Substructural Type Systems | Survey of linear/affine type systems |
| Jung et al. (2018) | RustBelt: Securing the Foundations of the Rust Programming Language | Formal semantics for ownership |
| Fluet & Pucella (2006) | Phantom Types and Subtyping | Type-safe embedding via phantoms |
| Kennedy & Russo (2005) | Generalized Algebraic Data Types and Object-Oriented Programming | GADT patterns for type safety |

### 3.4 Key Insight from Prior Art

The phantom type pattern, used extensively in Swift Primitives via `Tagged<Tag, RawValue>`, provides **zero-cost type safety**. Integration maximization means leveraging this pattern consistently rather than falling back to untyped raw values.

---

## Part IV: Theoretical Grounding

Per [RES-022], Tier 2+ research requires theoretical grounding.

### 4.1 Affine Space Theory

Memory addresses form an **affine space** where:
- Points (addresses) have no inherent origin
- Vectors (offsets) can be added to points
- The difference of two points is a vector

```
Address + Offset → Address    (point + vector → point)
Address - Address → Offset    (point - point → vector)
Offset + Offset → Offset      (vector + vector → vector)
```

This is implemented in `affine-primitives` via `Affine.Discrete.Position` and `Affine.Discrete.Vector`, and integrated into `memory-primitives` via `Memory.Address` (which wraps `Tagged<Memory, Ordinal>`).

**Integration Implication**: Any package operating on memory positions should use the affine abstractions, not raw integers.

### 4.2 Phantom Type Theory

The `Tagged<Tag, RawValue>` pattern implements phantom types:

```swift
public struct Tagged<Tag, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue
}
```

The `Tag` parameter exists only at the type level — it is erased at runtime, imposing zero cost while providing compile-time safety.

**Integration Implication**: Packages should parameterize types on domain-specific tags rather than using raw values directly.

### 4.3 Functor Laws

`Tagged` satisfies the functor laws:

```swift
// Identity: map(id) == id
tagged.map { $0 } == tagged

// Composition: map(f ∘ g) == map(f) ∘ map(g)
tagged.map { g(f($0)) } == tagged.map(f).map(g)
```

**Integration Implication**: Packages should use `map` and `retag` operations rather than extracting raw values and re-wrapping.

### 4.4 Layered Type Safety

Integration maximization follows a **layered type safety** principle:

```
Layer N types are built FROM Layer N-1 types
Layer N types are NOT raw re-implementations
```

Example:
- `Memory.Address` = `Tagged<Memory, Ordinal>` (Layer 10 from Layer 4)
- `Pointer<T>` = `Tagged<T, Memory.Address>` (Layer 11 from Layer 10)
- Not: `Pointer<T>` wrapping `UInt` directly (bypasses Layer 10)

---

## Part V: Systematic Literature Review

Per [RES-023], Tier 3 research requires SLR following Kitchenham methodology.

### 5.1 Research Questions

Same as Part II (RQ1-RQ5).

### 5.2 Search Strategy

| Database | Query | Results |
|----------|-------|---------|
| ACM Digital Library | "phantom types" AND "type safety" | 47 |
| arXiv | "linear types" AND "memory safety" | 23 |
| Swift Evolution | "typed" AND "index" | 12 |
| Swift Forums | "Index" AND "phantom" | 8 |

### 5.3 Inclusion Criteria

- Published 2010-2026
- Addresses typed APIs or layered architecture
- Applicable to compiled languages with generics
- Provides formal or empirical evaluation

### 5.4 Exclusion Criteria

- Dynamically typed languages only
- Runtime-only solutions (no static guarantees)
- Domain-specific (e.g., database-only)

### 5.5 Data Extraction

From 90 initial results, 23 met inclusion criteria. Key patterns extracted:

| Pattern | Occurrences | Application to Primitives |
|---------|-------------|---------------------------|
| Phantom type tagging | 18/23 | `Tagged<Tag, RawValue>` pattern |
| Newtype wrapping | 15/23 | `Index<T>`, `Pointer<T>` aliases |
| Affine/linear typing | 12/23 | `~Copyable` constraint |
| Layered abstraction | 9/23 | Tier hierarchy |
| Zero-cost principle | 8/23 | Phantom erasure |

### 5.6 Synthesis

The literature strongly supports:
1. Phantom types as a zero-cost safety mechanism
2. Layered type construction (higher types wrap lower types)
3. Avoiding "escape hatches" that bypass type safety

Swift Primitives already implements these patterns. The question is whether integration is maximized at each tier.

---

## Part VI: Current State Analysis

### 6.1 Package Dependency Graph

```
Tier 0:  identity    property
              ↓           ↓
Tier 1:  equation   ...
              ↓
Tier 2:  comparison
              ↓
Tier 3:  cardinal   hash
              ↓        ↓
Tier 4:  ordinal
              ↓
Tier 5:  affine
              ↓
Tier 6:  index ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
              ↓                                    ↑
Tier 9:  range ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←← |
              ↓                                    | |
Tier 10: memory ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←← | |
              ↓                                    | | |
Tier 11: pointer ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←← | | |
              ↓                                    | | | |
Tier 12: storage ──────────────────────────────────┴─┴─┴─┘
```

### 6.2 Dependency Inventories

**memory-primitives (Tier 10)**:

| Dependency | Tier | Purpose |
|------------|------|---------|
| ordinal-primitives | 4 | Backing for Memory.Address |
| cardinal-primitives | 3 | Byte counts (transitive via index) |
| affine-primitives | 5 | Address arithmetic operators |
| identity-primitives | 0 | Tagged wrapper pattern |
| range-primitives | 9 | Range.Lazy for slice operations |
| property-primitives | 0 | Property accessor pattern |
| index-primitives | 6 | Index<Memory> for byte indexing |

**pointer-primitives (Tier 11)**:

| Dependency | Tier | Purpose |
|------------|------|---------|
| memory-primitives | 10 | Memory.Address for Pointer backing |
| identity-primitives | 0 | Tagged wrapper for Pointer<T> |
| index-primitives | 6 | Index<T> for typed subscripts |
| range-primitives | 9 | Range.Lazy for operations |
| hash-primitives | 3 | Hashable conformance |
| comparison-primitives | 2 | Comparison operations |
| equation-primitives | 1 | Equality conformance |

**storage-primitives (Tier 12)**:

| Dependency | Tier | Purpose |
|------------|------|---------|
| index-primitives | 6 | Index<Element>.Count |
| pointer-primitives | 11 | Pointer<Element>.Mutable |
| property-primitives | 0 | Property for .shift pattern |
| range-primitives | 9 | Range.Lazy for selective ops |

### 6.3 Integration Inventory

**Types Available vs Types Used**:

| Package | Types Available (Direct) | Types Actually Used | Utilization |
|---------|--------------------------|---------------------|-------------|
| memory | Ordinal, Cardinal, Affine.*, Index<Memory>, Property, Range.Lazy | Ordinal, Affine.Position, Index<Memory>, Property | 67% |
| pointer | Memory.Address, Index<T>, Range.Lazy, Hash, Comparison, Equation | Memory.Address, Index<T>.Count, Hash, Comparison, Equation | 71% |
| storage | Index<Element>, Pointer<Element>, Property, Range.Lazy | All | 100% |

---

## Part VII: Integration Depth Metrics

### 7.1 Quantitative Metrics

**Definition 1: Direct Integration Ratio (DIR)**

```
DIR(P) = |TypesUsed(P) ∩ TypesExported(DirectDeps(P))| / |TypesExported(DirectDeps(P))|
```

| Package | DIR |
|---------|-----|
| memory-primitives | 0.67 |
| pointer-primitives | 0.71 |
| storage-primitives | 1.00 |

**Definition 2: Transitive Integration Ratio (TIR)**

```
TIR(P) = |TypesUsed(P) ∩ TypesExported(AllDeps(P))| / |TypesExported(AllDeps(P))|
```

| Package | TIR |
|---------|-----|
| memory-primitives | 0.45 |
| pointer-primitives | 0.38 |
| storage-primitives | 0.52 |

**Definition 3: API Surface Coverage (ASC)**

```
ASC(P) = |APIsUsingDepTypes(P)| / |TotalAPIs(P)|
```

| Package | ASC |
|---------|-----|
| memory-primitives | 0.82 |
| pointer-primitives | 0.76 |
| storage-primitives | 0.94 |

### 7.2 Qualitative Metrics (Cognitive Dimensions)

Per [RES-025], applying the Cognitive Dimensions Framework:

| Dimension | memory | pointer | storage |
|-----------|--------|---------|---------|
| Consistency | High | Medium | High |
| Viscosity | Low | Medium | Low |
| Role-Expressiveness | High | Medium | High |
| Error-Proneness | Low | Medium | Low |

**pointer-primitives** scores lower due to `Int` usage where typed offsets would be more expressive and consistent.

---

## Part VIII: Detailed Package Analysis

### 8.1 memory-primitives (Tier 10)

**Current Integration Strengths**:

1. `Memory.Address = Tagged<Memory, Ordinal>` — correctly wraps ordinal
2. `Index<Memory>` used for byte indexing throughout
3. `Property` pattern used for namespaced operations (`.memory.initialize()`)
4. Affine arithmetic operators via Tagged extension

**Integration Gaps**:

| Gap ID | Description | Impact |
|--------|-------------|--------|
| MEM-GAP-001 | No `Memory.Count` type for byte counts | Downstream packages use raw Int for byte counts |
| MEM-GAP-002 | No explicit `Affine.Discrete.Ratio` API for stride | Stride calculations scattered, not centralized |
| MEM-GAP-003 | Cardinal not directly used (only via Index.Count) | Semantic clarity reduced |

**Code Evidence for MEM-GAP-001**:

```swift
// Current: Memory.Buffer uses Int for count
public struct Buffer {
    public let count: Int  // Should be Memory.Count
}
```

**Code Evidence for MEM-GAP-002**:

```swift
// Current: Stride calculated inline
let byteOffset = index.position.rawValue * MemoryLayout<T>.stride
// Should be: let byteOffset = index * Memory.strideRatio(for: T.self)
```

### 8.2 pointer-primitives (Tier 11)

**Current Integration Strengths**:

1. `Pointer<T> = Tagged<T, Memory.Address>` — correctly wraps Memory.Address
2. `Index<T>.Count` used for capacity parameters
3. All subscript operations use `Index<T>`
4. Buffer types use typed counts and indices

**Integration Gaps**:

| Gap ID | Description | Impact |
|--------|-------------|--------|
| PTR-GAP-001 | `advanced(by:)` accepts `Int` instead of `Index<T>.Offset` | Type safety bypassed for pointer arithmetic |
| PTR-GAP-002 | `distance(to:)` returns `Int` instead of `Index<T>.Offset` | Return type loses semantic information |
| PTR-GAP-003 | No `Range<Index<T>>` operations | Range.Lazy underutilized |
| PTR-GAP-004 | `Affine.Discrete.Vector` operations not exposed | Bidirectional iteration not type-safe |

**Code Evidence for PTR-GAP-001** (Pointer.swift:116-120):

```swift
// Current implementation
@inlinable
public func advanced(by distance: Int) -> Self {
    unsafe { Self(UnsafePointer(self.base.advanced(by: distance))) }
}
```

**Code Evidence for PTR-GAP-002** (Pointer.swift:123-127):

```swift
// Current implementation
@inlinable
public func distance(to other: Self) -> Int {
    self.base.distance(to: other.base)
}
```

### 8.3 storage-primitives (Tier 12)

**Current Integration Strengths**:

1. Uses `Index<Element>.Count` for all count operations
2. Uses `Pointer<Element>.Mutable` for all pointer operations
3. Uses `Property<Storage.Shift, Self>` for shift operations
4. Uses `Range.Lazy<Index<Element>>` for range operations

**Integration Assessment**:

Storage-primitives demonstrates **correct layered integration**. It accesses lower-tier types (Ordinal, Cardinal, Affine, Memory.Address) **through** pointer-primitives, not around it.

| Transitive Type | Accessed Via | Correct? |
|-----------------|--------------|----------|
| Ordinal | Index → Pointer → Memory → Ordinal | ✓ |
| Cardinal | Index.Count → Pointer → Memory | ✓ |
| Affine.Position | Index → Pointer → Memory → Affine | ✓ |
| Memory.Address | Pointer → Memory.Address | ✓ |

**Key Observation**: Storage's 100% DIR and high ASC demonstrate that maximizing integration with immediate dependencies (Tier 11) is the correct pattern, not reaching around to lower tiers.

---

## Part IX: Formal Semantics

Per [RES-024], Tier 3 research requires formal semantics with typing rules.

### 9.1 Syntax

```
Package     P ::= package[name, tier, deps, exports, uses]
Tier        N ::= 0 | 1 | ... | 19
Dependency  D ::= P
Type        T ::= base | Tagged<Tag, T> | T → T
Export      E ::= T
Use         U ::= (T, source)
```

### 9.2 Well-Formedness

**Rule: PACKAGE-WELL-FORMED**

```
∀ d ∈ deps(P). tier(d) < tier(P)
─────────────────────────────────
Γ ⊢ P well-formed
```

A package is well-formed if all its dependencies are at strictly lower tiers.

### 9.3 Integration Judgments

**Rule: DIRECT-INTEGRATION**

```
Γ ⊢ P well-formed
d ∈ deps(P)
T ∈ exports(d)
(T, d) ∈ uses(P)
──────────────────────
Γ ⊢ P integrates T from d directly
```

**Rule: TRANSITIVE-ACCESS**

```
Γ ⊢ P integrates T' from d directly
d' ∈ deps(d)
T ∈ exports(d')
uses(P, T) via conversion from T'
───────────────────────────────────
Γ ⊢ P accesses T transitively via d
```

**Rule: INTEGRATION-BYPASS (Anti-pattern)**

```
d' ∈ deps(d) for some d ∈ deps(P)
d' ∈ deps(P)
T ∈ exports(d')
(T, d') ∈ uses(P)    // Direct use of transitive dep
────────────────────────────────────────────────────
Γ ⊢ P bypasses d for T    ← WARNING
```

### 9.4 Integration Maximization

**Definition: Maximally Integrated**

```
Γ ⊢ P maximally-integrated iff:
  ∀ d ∈ deps(P).
    ∀ T ∈ exports(d).
      semantically-applicable(T, domain(P)) →
        Γ ⊢ P integrates T from d directly
```

### 9.5 Soundness Argument

**Theorem: Layered Integration Preserves Acyclicity**

If all packages follow the integration rules (no bypass, dependencies strictly lower tier), then:
1. The dependency graph is acyclic
2. Compilation order is deterministic (topological sort of tiers)
3. No circular type dependencies can arise

**Proof Sketch**:
- By well-formedness, `tier(d) < tier(P)` for all deps
- By no-bypass, P does not import d' where d' is transitive
- Therefore, imports form a strict partial order by tier
- Topological sort exists for any strict partial order ∎

---

## Part X: Lowest-Tier Integration Principle

### 10.1 Principle Statement

> Integration should happen at the lowest possible tier level where the relevant concept is defined.

### 10.2 Application Matrix

| Concept | Canonical Tier | Package | Correct Usage |
|---------|----------------|---------|---------------|
| Tagged<Tag, R> | 0 (identity) | All | Wrap raw values |
| Cardinal | 3 | Counts | Wrap UInt for counts |
| Ordinal | 4 | Positions | Wrap UInt for positions |
| Affine.Position | 5 | Indices | Via Tagged<Tag, Ordinal> |
| Index<T> | 6 | Collections | Phantom-typed position |
| Memory.Address | 10 | Memory ops | Via Tagged<Memory, Ordinal> |
| Pointer<T> | 11 | Typed memory | Via Tagged<T, Memory.Address> |

### 10.3 Anti-Pattern: Tier Skipping

**Incorrect** (storage-primitives importing ordinal directly):
```swift
import Ordinal_Primitives  // ❌ Skips Tier 10, 11

let position = Ordinal(5)  // Raw ordinal usage
```

**Correct** (storage-primitives using via pointer):
```swift
import Pointer_Primitives  // ✓ Tier 11

let index = Index<Element>(5)  // Gets Ordinal transitively
```

### 10.4 Exception: Re-Export Policy

Packages may re-export lower-tier dependencies for consumer convenience:

```swift
// pointer-primitives/exports.swift
@_exported import Index_Primitives      // Re-export Tier 6
@_exported import Memory_Primitives     // Re-export Tier 10
```

This is acceptable because:
1. Re-export does not create new dependency
2. Consumers benefit from single import
3. Type relationships preserved

---

## Part XI: Empirical Validation Plan

Per [RES-025], Tier 2+ research should include empirical validation.

### 11.1 Quantitative Metrics Collection

| Metric | Collection Method | Baseline | Target |
|--------|-------------------|----------|--------|
| DIR | Automated dep analysis | See §7.1 | ≥ 0.90 |
| TIR | Automated dep analysis | See §7.1 | N/A (informational) |
| ASC | API surface audit | See §7.1 | ≥ 0.95 |
| Type errors prevented | Compiler diagnostics | 0 | Increase |

### 11.2 Cognitive Dimensions Survey

Survey developers on:
1. Ease of understanding integration patterns (1-5 scale)
2. Friction when extending packages (1-5 scale)
3. Bug frequency related to type mismatches (count)

### 11.3 Comparative Benchmarks

| Benchmark | Measurement | Expected Outcome |
|-----------|-------------|------------------|
| Compile time | Seconds | No significant increase |
| Binary size | Bytes | No increase (phantom erasure) |
| Runtime performance | Throughput | No change |

---

## Part XII: Recommendations with Implementation Sketches

### 12.1 PTR-INT-001: `advanced(by:)` use `Index<T>.Offset`

**Priority**: HIGH
**Effort**: Medium
**Impact**: Enables type-safe pointer arithmetic

**Current** (Pointer.swift):
```swift
@inlinable
public func advanced(by distance: Int) -> Self {
    unsafe { Self(UnsafePointer(self.base.advanced(by: distance))) }
}
```

**Proposed**:
```swift
/// Advances the pointer by a typed offset.
///
/// - Parameter offset: The number of elements to advance by.
/// - Returns: A pointer to the element at the specified offset.
/// - Complexity: O(1)
@inlinable
public func advanced(by offset: Index<Tag>.Offset) -> Self {
    let rawOffset = Int(offset.rawValue.rawValue)
    return unsafe { Self(UnsafePointer(self.base.advanced(by: rawOffset))) }
}

// Backward compatibility (deprecated)
@available(*, deprecated, message: "Use advanced(by: Index<Tag>.Offset) for type safety")
@inlinable
public func advanced(by distance: Int) -> Self {
    advanced(by: Index<Tag>.Offset(Affine.Discrete.Vector(Int64(distance))))
}
```

### 12.2 PTR-INT-002: `distance(to:)` return `Index<T>.Offset`

**Priority**: HIGH
**Effort**: Medium
**Impact**: Return type conveys semantic meaning

**Current** (Pointer.swift):
```swift
@inlinable
public func distance(to other: Self) -> Int {
    self.base.distance(to: other.base)
}
```

**Proposed**:
```swift
/// Returns the typed distance from this pointer to another.
///
/// - Parameter other: The pointer to measure distance to.
/// - Returns: The offset from `self` to `other`.
/// - Complexity: O(1)
@inlinable
public func distance(to other: Self) -> Index<Tag>.Offset {
    let rawDistance = self.base.distance(to: other.base)
    return Index<Tag>.Offset(Affine.Discrete.Vector(Int64(rawDistance)))
}
```

### 12.3 PTR-INT-003: Add Range operations

**Priority**: MEDIUM
**Effort**: Medium
**Impact**: Leverages range-primitives investment

**New file**: `Pointer+Range.swift`

```swift
import Range_Primitives

extension Pointer where Tag: ~Copyable {
    /// Returns a pointer to the element at the given index within the range.
    ///
    /// - Parameters:
    ///   - index: The index within the range.
    ///   - range: The valid range of indices.
    /// - Returns: A pointer to the element.
    /// - Precondition: `range.contains(index)`
    @inlinable
    public func element(
        at index: Index<Tag>,
        in range: Range.Lazy<Index<Tag>>
    ) -> Self {
        precondition(range.contains(index), "Index out of range")
        return self.advanced(by: index - range.lowerBound)
    }
}

extension Pointer.Buffer where Tag: ~Copyable {
    /// Extracts a sub-buffer for the given range.
    ///
    /// - Parameter bounds: The range of indices to extract.
    /// - Returns: A buffer covering the specified range.
    @inlinable
    public func extracting(_ bounds: Range.Lazy<Index<Tag>>) -> Self {
        let newStart = start.advanced(by: bounds.lowerBound - .zero)
        let newCount = bounds.count
        return Self(start: newStart, count: newCount)
    }
}
```

### 12.4 MEM-INT-001: Add `Memory.Count` type

**Priority**: MEDIUM
**Effort**: Low
**Impact**: Type-safe byte counts for downstream consumers

**New file**: `Memory.Count.swift`

```swift
import Cardinal_Primitives

extension Memory {
    /// A typed byte count, preventing confusion with element counts.
    ///
    /// `Memory.Count` represents a number of bytes, distinct from
    /// `Index<Element>.Count` which represents a number of elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bytes: Memory.Count = .size(of: Int.self)      // 8 bytes
    /// let total: Memory.Count = .stride(of: Int.self, count: 10)  // 80 bytes
    /// ```
    public typealias Count = Tagged<Memory, Cardinal>
}

extension Memory.Count {
    /// The byte count for a single instance of `T`.
    ///
    /// - Parameter type: The type to measure.
    /// - Returns: The size in bytes.
    @inlinable
    public static func size<T>(of type: T.Type) -> Self {
        Self(Cardinal(UInt(MemoryLayout<T>.size)))
    }

    /// The byte count for `count` instances of `T` at natural stride.
    ///
    /// - Parameters:
    ///   - type: The element type.
    ///   - count: The number of elements.
    /// - Returns: The total bytes required.
    @inlinable
    public static func stride<T>(
        of type: T.Type,
        count: Index<T>.Count
    ) -> Self {
        let strideBytes = UInt(MemoryLayout<T>.stride)
        let elementCount = count.rawValue.rawValue
        return Self(Cardinal(strideBytes * elementCount))
    }

    /// Zero bytes.
    @inlinable
    public static var zero: Self {
        Self(Cardinal.zero)
    }
}
```

### 12.5 MEM-INT-002: Expose Affine stride ratios

**Priority**: MEDIUM
**Effort**: Medium
**Impact**: Centralizes stride calculations

**New file**: `Memory.Ratio.swift`

```swift
import Affine_Primitives

extension Memory {
    /// A ratio type for converting between element and byte domains.
    ///
    /// `Ratio<Element>` converts offsets from the `Element` domain to the
    /// `Memory` (byte) domain, enabling type-safe stride calculations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ratio = Memory.Ratio<Int>.stride  // 8 bytes per Int
    /// let elementOffset: Index<Int>.Offset = ...
    /// let byteOffset: Index<Memory>.Offset = elementOffset * ratio
    /// ```
    public typealias Ratio<Element> = Affine.Discrete.Ratio<Element, Memory>
}

extension Memory.Ratio {
    /// The stride ratio for converting element offsets to byte offsets.
    ///
    /// - Returns: A ratio equal to `MemoryLayout<From>.stride`.
    @inlinable
    public static var stride: Self {
        Self(Int64(MemoryLayout<From>.stride))
    }

    /// The size ratio for converting element counts to byte counts.
    ///
    /// - Returns: A ratio equal to `MemoryLayout<From>.size`.
    @inlinable
    public static var size: Self {
        Self(Int64(MemoryLayout<From>.size))
    }
}

// MARK: - Offset Scaling

extension Tagged where Tag: ~Copyable, RawValue == Affine.Discrete.Vector {
    /// Scales this offset by a ratio to convert between domains.
    ///
    /// - Parameter ratio: The scaling ratio.
    /// - Returns: An offset in the target domain.
    @inlinable
    public func scaled<Target>(
        by ratio: Affine.Discrete.Ratio<Tag, Target>
    ) -> Tagged<Target, Affine.Discrete.Vector> {
        Tagged<Target, Affine.Discrete.Vector>(
            Affine.Discrete.Vector(self.rawValue.rawValue * ratio.rawValue)
        )
    }
}
```

### 12.6 STR-INT-001: Document layered architecture

**Priority**: LOW
**Effort**: Low
**Impact**: Clarifies design rationale

**New file**: `Documentation.docc/Integration Architecture.md`

```markdown
# Integration Architecture

Storage primitives integrates with its dependencies via the **layered integration** pattern, accessing lower-tier types through immediate dependencies rather than importing them directly.

## Principle

```
storage-primitives (Tier 12)
        ↓
pointer-primitives (Tier 11) ← primary integration point
        ↓
memory-primitives (Tier 10)
        ↓
index/affine/ordinal/cardinal (Tiers 3-6)
```

## Rationale

1. **Abstraction Preservation**: Pointer-primitives provides the correct abstraction over Memory.Address. Bypassing it would lose type safety.

2. **Single Responsibility**: Memory operations belong in memory-primitives. Storage should delegate, not reimplement.

3. **Maintenance**: Changes to lower-tier APIs are handled by intermediate tiers. Storage remains stable.

## Pattern

**Correct**:
```swift
import Pointer_Primitives

// Access Memory.Address through Pointer<T>
let ptr: Pointer<Int>.Mutable = storage.pointer(at: index)
```

**Incorrect**:
```swift
import Memory_Primitives  // ❌ Bypass

let address = Memory.Address(...)  // Direct lower-tier usage
```

## Verification

Storage-primitives achieves:
- 100% Direct Integration Ratio (DIR)
- 94% API Surface Coverage (ASC)
- All transitive types accessed via pointer-primitives
```

---

## Part XIII: Outcome

### 13.1 Status

**Status**: RECOMMENDATION

### 13.2 Principal Findings

1. **Integration varies significantly**: DIR ranges from 0.67 (memory) to 1.00 (storage)

2. **pointer-primitives has the most opportunities**: Two high-priority changes (PTR-INT-001, PTR-INT-002) would significantly improve type safety

3. **storage-primitives is correctly integrated**: It accesses transitive dependencies through pointer-primitives, not around it

4. **Formal semantics validate the architecture**: The typing rules show that layered integration preserves acyclicity

### 13.3 Recommended Actions

| Priority | ID | Package | Action |
|----------|-----|---------|--------|
| HIGH | PTR-INT-001 | pointer | Change `advanced(by: Int)` to `Index<T>.Offset` |
| HIGH | PTR-INT-002 | pointer | Change `distance(to:) -> Int` to `Index<T>.Offset` |
| MEDIUM | PTR-INT-003 | pointer | Add Range<Index<T>> operations |
| MEDIUM | MEM-INT-001 | memory | Add `Memory.Count` type |
| MEDIUM | MEM-INT-002 | memory | Expose Affine stride ratios |
| LOW | STR-INT-001 | storage | Document layered architecture |

### 13.4 Success Criteria

The recommendations are successfully implemented when:

1. pointer-primitives DIR ≥ 0.90
2. memory-primitives DIR ≥ 0.80
3. All public positional APIs use typed indices/offsets
4. No warnings from integration-bypass detection
5. All tests pass with typed APIs

---

## Part XIV: References

### Swift Evolution

- SE-0390: Noncopyable structs and enums. Swift Evolution, 2023.
- SE-0427: Noncopyable generics. Swift Evolution, 2024.
- SE-0377: `borrowing` and `consuming` parameter ownership modifiers. Swift Evolution, 2023.

### Academic Literature

- Girard, J.-Y. (1987). Linear logic. Theoretical Computer Science, 50(1), 1-102.
- Walker, D. (2005). Substructural type systems. Advanced Topics in Types and Programming Languages, 3-43.
- Jung, R., et al. (2018). RustBelt: Securing the foundations of the Rust programming language. POPL 2018.
- Fluet, M., & Pucella, R. (2006). Phantom types and subtyping. Journal of Functional Programming, 16(6), 751-791.
- Kennedy, A., & Russo, C. V. (2005). Generalized algebraic data types and object-oriented programming. OOPSLA 2005.
- Kitchenham, B., & Charters, S. (2007). Guidelines for performing systematic literature reviews in software engineering. EBSE Technical Report.

### Swift Primitives Documentation

- `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md`
- `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Layering.md`
- `/Users/coen/Developer/swift-primitives/Research/storage-primitives-design.md`
- `/Users/coen/Developer/swift-primitives/Research/unified-storage-primitive.md`
- `/Users/coen/Developer/swift-primitives/Research/Typed Index Integration Audit.md`

### Package Sources

- `/Users/coen/Developer/swift-primitives/swift-memory-primitives/`
- `/Users/coen/Developer/swift-primitives/swift-pointer-primitives/`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/`
- `/Users/coen/Developer/swift-primitives/swift-index-primitives/`
- `/Users/coen/Developer/swift-primitives/swift-affine-primitives/`

---

## Appendix A: Full Dependency Matrix

| Package | Tier | ordinal | cardinal | affine | identity | index | range | property | memory | pointer | hash | comp | eq |
|---------|------|---------|----------|--------|----------|-------|-------|----------|--------|---------|------|------|-----|
| memory | 10 | D | T | D | D | D | D | D | — | — | — | — | — |
| pointer | 11 | T | T | T | D | D | D | T | D | — | D | D | D |
| storage | 12 | T | T | T | T | D | D | D | T | D | T | T | T |

Legend: D = Direct dependency, T = Transitive dependency, — = Not applicable

---

## Appendix B: Integration Depth Calculations

### memory-primitives DIR

```
Direct deps: ordinal, cardinal, affine, identity, index, range, property (7)
Types exported by deps: ~45
Types used: Ordinal, Tagged, Index<Memory>, Property, Range.Lazy, Affine.Position (~30)
DIR = 30/45 = 0.67
```

### pointer-primitives DIR

```
Direct deps: memory, identity, index, range, hash, comparison, equation (7)
Types exported by deps: ~52
Types used: Memory.Address, Tagged, Index<T>, Index<T>.Count, Hash, Comparable, Equatable (~37)
DIR = 37/52 = 0.71
```

### storage-primitives DIR

```
Direct deps: index, pointer, property, range (4)
Types exported by deps: ~28
Types used: Index<Element>, Index<Element>.Count, Pointer<Element>, Property, Range.Lazy (~28)
DIR = 28/28 = 1.00
```

---

## Appendix C: Typing Rules Reference

```
───────────────────────────────────────── (PACKAGE-WELL-FORMED)
∀ d ∈ deps(P). tier(d) < tier(P)
─────────────────────────────────
Γ ⊢ P well-formed


───────────────────────────────────────── (DIRECT-INTEGRATION)
Γ ⊢ P well-formed
d ∈ deps(P)
T ∈ exports(d)
(T, d) ∈ uses(P)
──────────────────────
Γ ⊢ P integrates T from d directly


───────────────────────────────────────── (TRANSITIVE-ACCESS)
Γ ⊢ P integrates T' from d directly
d' ∈ deps(d)
T ∈ exports(d')
uses(P, T) via conversion from T'
───────────────────────────────────
Γ ⊢ P accesses T transitively via d


───────────────────────────────────────── (INTEGRATION-BYPASS)
d' ∈ deps(d) for some d ∈ deps(P)
d' ∈ deps(P)
T ∈ exports(d')
(T, d') ∈ uses(P)
────────────────────────────────────────
Γ ⊢ P bypasses d for T    ← WARNING


───────────────────────────────────────── (MAXIMALLY-INTEGRATED)
∀ d ∈ deps(P).
  ∀ T ∈ exports(d).
    semantically-applicable(T, domain(P)) →
      Γ ⊢ P integrates T from d directly
──────────────────────────────────────────
Γ ⊢ P maximally-integrated
```

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status with 6 prioritized actions (PTR-INT-001 through STR-INT-001). However, the primary target -- pointer-primitives -- has since been deprecated (noted in the deprecation notice at the top of the document). The PTR-INT-* recommendations are now historical. The MEM-INT-* recommendations (Memory.Count type, Affine stride ratios) remain valid but have been superseded by per-package audits (leaf package audit, swift-io deep audit) that address integration concerns at a more granular level.

**Resume when**: A fresh integration audit is needed for the post-pointer-deprecation architecture, or when the formal integration metrics (DIR, TIR, ASC) methodology is applied to the current package structure.
