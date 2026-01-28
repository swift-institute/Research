# Ordinal and Cardinal Foundations for Swift Primitives

## Abstract

This document investigates the mathematical foundations for organizing discrete position and cardinality types in the Swift Primitives ecosystem. We analyze whether the current `Affine.Discrete` model correctly captures the semantics of indices (ordinals) and counts (cardinals), and whether a principled reorganization into `swift-ordinal-primitives` and `swift-cardinal-primitives` is warranted. This is Tier 3 research establishing foundational semantic commitments for the primitives layer.

---

## 1. Context

### 1.1 Trigger

During implementation of saturating subtraction (`subtract.saturating`) for `Affine.Discrete.Count`, the question arose: **Does `Count` belong in `swift-affine-primitives`?**

The operation implemented—monus (a ∸ b = max(0, a - b))—is the canonical subtraction on natural numbers viewed as **cardinals** (cardinalities of finite sets). This is not an affine geometry concept.

### 1.2 Current State

The existing organization mixes mathematical domains:

| Type | Package | Mathematical Concept |
|------|---------|---------------------|
| `Affine.Discrete.Position` | swift-affine-primitives | Finite ordinal |
| `Affine.Discrete.Count` | swift-affine-primitives | Finite cardinal |
| `Affine.Discrete.Displacement` | swift-affine-primitives | Signed integer (ℤ) |
| `Index<Tag>` | swift-index-primitives | Phantom-typed ordinal |
| `Index<Tag>.Count` | swift-index-primitives | Phantom-typed cardinal |

### 1.3 Scope and Precedent

This decision is **precedent-setting** and **hard to undo**:

- Affects naming, dependencies, and conceptual model across all primitives
- Establishes foundational vocabulary for the entire ecosystem
- Future packages will depend on these semantic distinctions
- Incorrect organization will propagate through Standards and Foundations layers

### 1.4 Tier Justification

| Criterion | Assessment |
|-----------|------------|
| Scope | Ecosystem-wide |
| Precedent-setting | Yes, hard to undo |
| Semantic commitment | Normative/foundational |
| Cost of error | Very high |
| Expected lifetime | "Timeless infrastructure" |

**Conclusion**: Tier 3 research is required.

---

## 2. Research Questions

**RQ1**: What are the precise mathematical definitions of ordinals and cardinals, and how do they differ?

**RQ2**: What operations are canonical for ordinals vs. cardinals, and where do current operations belong?

**RQ3**: How do existing programming languages and type systems model ordinals and cardinals?

**RQ4**: What is the correct package organization for Swift Primitives?

**RQ5**: How should finite and transfinite cases be accommodated?

---

## 3. Systematic Literature Review

### 3.1 Search Strategy

**Databases**:
- Mathematical foundations: Kunen (Set Theory), Jech (Set Theory), Halmos (Naive Set Theory)
- Type theory: Pierce (TAPL), Harper (PFPL), HoTT Book
- Programming languages: ACM DL, arXiv cs.PL, POPL/ICFP/OOPSLA proceedings
- Language-specific: Swift Evolution, Rust RFCs, Haskell GHC proposals

**Keywords**: ordinal number, cardinal number, cardinality, well-ordering, index type, phantom type, affine type, linear type, natural number arithmetic, monus, truncated subtraction

**Date range**: Foundational texts (any date), PL research (2010-2026)

### 3.2 Inclusion/Exclusion Criteria

**Include**:
- Foundational set theory texts defining ordinals/cardinals
- Type-theoretic treatments of natural numbers
- PL papers on index types, sized types, cardinality tracking
- Language designs with explicit ordinal/cardinal distinction

**Exclude**:
- Purely infinite/transfinite-focused work (defer to future research)
- Implementation-only papers without semantic foundations
- Non-constructive set theory (focus on computable/finite cases)

### 3.3 Data Extraction

#### 3.3.1 Set-Theoretic Foundations

| Source | Definition of Ordinal | Definition of Cardinal |
|--------|----------------------|------------------------|
| Kunen (1980) | Equivalence class of well-ordered sets under order isomorphism | Equivalence class of sets under bijection |
| Halmos (1960) | Transitive set well-ordered by ∈ | Least ordinal equinumerous with a set |
| Jech (2003) | Von Neumann ordinal: α = {β : β < α} | Initial ordinal of equinumerosity class |

**Key insight**: For **finite** sets, ordinals and cardinals coincide—both are the natural numbers ℕ. But they answer different questions:

- **Ordinal n**: "The position that comes after n-1 positions" (which one?)
- **Cardinal n**: "A set with n elements" (how many?)

#### 3.3.2 Canonical Operations

| Operation | Domain | Semantics | Totality |
|-----------|--------|-----------|----------|
| Successor S(n) | Ordinals | Next position | Total |
| Predecessor P(n) | Ordinals | Previous position | Partial (undefined at 0) |
| Addition a + b | Both | Ordinal: concatenation; Cardinal: disjoint union | Total |
| Subtraction a - b | Both | Partial (undefined when b > a) | Partial |
| Monus a ∸ b | Cardinals | max(0, a - b) | Total |
| Multiplication a × b | Both | Ordinal: lexicographic; Cardinal: Cartesian product | Total |
| Comparison a < b | Ordinals | Well-order comparison | Total |
| Comparison |A| < |B| | Cardinals | Injection exists A → B but no bijection | Total (finite); complex (infinite) |

**Critical finding**: **Monus (∸) is a cardinal operation**, not an ordinal operation. It answers "how many remain after removing some?" which is a cardinality question.

#### 3.3.3 Type-Theoretic Models

| System | Ordinal Model | Cardinal Model |
|--------|---------------|----------------|
| Martin-Löf Type Theory | Fin n (finite ordinals as a type) | ℕ with cardinality interpretation |
| Agda | Fin n, well-founded trees | Nat, sized types |
| Idris | Fin n | Nat |
| Haskell | No standard; libraries vary | Natural (base), Word |
| Rust | No distinction; usize for both | No distinction |
| Swift (current) | No distinction; Int for both | No distinction |

**Observation**: Most mainstream languages conflate ordinals and cardinals into a single unsigned integer type. Only dependently-typed languages (Agda, Idris) distinguish them at the type level.

#### 3.3.4 Prior Art in Programming Languages

**Rust**: Uses `usize` for both indices and lengths. No semantic distinction. The type system does not prevent using a length where an index is expected.

**Haskell**: The `base` library provides `Natural` for non-negative integers but does not distinguish ordinal from cardinal use. The `fin` package provides `Fin n` for bounded ordinals.

**Agda**:
```agda
data Fin : ℕ → Set where
  zero : {n : ℕ} → Fin (suc n)
  suc  : {n : ℕ} → Fin n → Fin (suc n)
```
This is the canonical type-theoretic representation of finite ordinals bounded by n.

**Swift Evolution**: No proposals specifically address ordinal/cardinal distinction. SE-0370 (Sendable), SE-0302 (Distributed actors) touch on type safety but not mathematical foundations.

### 3.4 Synthesis of Findings

1. **Ordinals and cardinals are mathematically distinct** even for finite cases
2. **Most languages do not distinguish them** at the type level
3. **The operations differ in totality**: ordinal predecessor is partial; cardinal monus is total
4. **Dependently-typed languages get this right** with `Fin n` vs `ℕ`
5. **Current Swift Primitives conflate the concepts** in `Affine.Discrete`

---

## 4. Theoretical Grounding

### 4.1 Set-Theoretic Definitions

**Definition 4.1 (Finite Ordinal)**. A finite ordinal is a natural number n ∈ ℕ interpreted as a position in a well-ordered sequence. The ordinal n represents "the (n+1)th position" in 0-indexed terms, or equivalently, "the position that has exactly n predecessors."

**Definition 4.2 (Finite Cardinal)**. A finite cardinal is a natural number n ∈ ℕ interpreted as the cardinality (size) of a finite set. The cardinal n represents "any set with exactly n elements."

**Definition 4.3 (Monus)**. The monus operation ∸ : ℕ × ℕ → ℕ is defined as:
```
a ∸ b = max(0, a - b) = { a - b  if a ≥ b
                        { 0      if a < b
```
Monus is the canonical total subtraction on cardinals, answering "how many remain?"

### 4.2 Type-Theoretic Formalization

We define types for finite ordinals and cardinals with their operations.

#### 4.2.1 Ordinal Type

```
────────────────────────────────
Ordinal : Type

n : ℕ, n ≥ 0
────────────────────────────────
Ordinal.finite(n) : Ordinal

o : Ordinal
────────────────────────────────
successor(o) : Ordinal

o : Ordinal, o ≠ 0
────────────────────────────────
predecessor(o) : Ordinal
```

**Typing Rules for Ordinal Operations**:

```
Γ ⊢ o : Ordinal
─────────────────────────────── (T-Succ)
Γ ⊢ successor(o) : Ordinal

Γ ⊢ o : Ordinal    Γ ⊢ o > 0
─────────────────────────────── (T-Pred)
Γ ⊢ predecessor(o) : Ordinal

Γ ⊢ o₁ : Ordinal    Γ ⊢ o₂ : Ordinal
─────────────────────────────────────── (T-OrdLt)
Γ ⊢ o₁ < o₂ : Bool
```

#### 4.2.2 Cardinal Type

```
────────────────────────────────
Cardinal : Type

n : ℕ, n ≥ 0
────────────────────────────────
Cardinal.finite(n) : Cardinal

c₁ : Cardinal, c₂ : Cardinal
────────────────────────────────
c₁ + c₂ : Cardinal

c₁ : Cardinal, c₂ : Cardinal
────────────────────────────────
c₁ ∸ c₂ : Cardinal              [Total—always defined]

c₁ : Cardinal, c₂ : Cardinal, c₂ ≤ c₁
────────────────────────────────
c₁ - c₂ : Cardinal              [Partial—requires proof]
```

**Typing Rules for Cardinal Operations**:

```
Γ ⊢ c₁ : Cardinal    Γ ⊢ c₂ : Cardinal
──────────────────────────────────────── (T-CardAdd)
Γ ⊢ c₁ + c₂ : Cardinal

Γ ⊢ c₁ : Cardinal    Γ ⊢ c₂ : Cardinal
──────────────────────────────────────── (T-Monus)
Γ ⊢ c₁ ∸ c₂ : Cardinal

Γ ⊢ c₁ : Cardinal    Γ ⊢ c₂ : Cardinal    Γ ⊢ c₂ ≤ c₁
──────────────────────────────────────────────────────── (T-CardSub)
Γ ⊢ c₁ - c₂ : Cardinal
```

#### 4.2.3 Conversion Functions

```
Γ ⊢ o : Ordinal
─────────────────────────────── (T-OrdToCard)
Γ ⊢ cardinality(o) : Cardinal

Γ ⊢ c : Cardinal
─────────────────────────────── (T-CardToOrd)
Γ ⊢ ordinal(c) : Ordinal
```

**Semantics**: For finite ordinals/cardinals, `cardinality(ordinal.finite(n)) = cardinal.finite(n)` and `ordinal(cardinal.finite(n)) = ordinal.finite(n)`. The representations coincide but the types differ.

### 4.3 Operational Semantics

#### 4.3.1 Ordinal Operations

```
successor(ordinal.finite(n)) ⟶ ordinal.finite(n + 1)

predecessor(ordinal.finite(n)) ⟶ ordinal.finite(n - 1)    [n > 0]

predecessor(ordinal.finite(0)) ⟶ ⊥                        [undefined]
```

#### 4.3.2 Cardinal Operations

```
cardinal.finite(a) + cardinal.finite(b) ⟶ cardinal.finite(a + b)

cardinal.finite(a) ∸ cardinal.finite(b) ⟶ cardinal.finite(max(0, a - b))

cardinal.finite(a) - cardinal.finite(b) ⟶ cardinal.finite(a - b)    [a ≥ b]

cardinal.finite(a) - cardinal.finite(b) ⟶ ⊥                         [a < b]
```

### 4.4 Soundness Argument

**Theorem 4.1 (Type Soundness)**. If Γ ⊢ e : τ, then either:
1. e is a value, or
2. e ⟶ e' and Γ ⊢ e' : τ (preservation), or
3. e is stuck only at explicitly partial operations with unsatisfied preconditions

**Proof sketch**:
- Cardinal monus (∸) is total by construction
- Cardinal subtraction (-) is partial; stuck configurations occur only when precondition c₂ ≤ c₁ is violated
- Ordinal predecessor is partial; stuck at ordinal.finite(0)
- All other operations are total

**Corollary 4.2 (Monus Totality)**. For all cardinals c₁, c₂, the expression c₁ ∸ c₂ reduces to a cardinal value. Monus never produces a stuck configuration.

This justifies `subtract.saturating` as a **total function** on `Count` types.

---

## 5. Analysis of Options

### 5.1 Option A: Status Quo (Affine Model)

**Structure**:
```
swift-affine-primitives/
  Affine.Discrete.Position    # Ordinal
  Affine.Discrete.Count       # Cardinal
  Affine.Discrete.Displacement # ℤ
```

**Advantages**:
- No migration required
- Geometric interpretation is intuitive for some users
- Simpler dependency graph

**Disadvantages**:
- **Mathematically imprecise**: Count is not an affine concept
- **Mixed operations**: Cardinal monus lives alongside affine operations
- **Unclear semantics**: "Affine" suggests geometric, but Count is set-theoretic
- **Future confusion**: Transfinite cardinals don't fit affine model

**Assessment**: Mathematically unsound. Convenience over correctness.

### 5.2 Option B: Full Separation (Ordinal + Cardinal Packages)

**Structure**:
```
swift-ordinal-primitives/
  Ordinal.Finite              # Position semantics
  Ordinal.Successor
  Ordinal.Limit               # For bounded ordinals (future)

swift-cardinal-primitives/
  Cardinal.Finite             # Count semantics
  Cardinal.Monus              # subtract.saturating
  Cardinal.Limit              # For bounded cardinals (future)

swift-affine-primitives/
  Affine.Discrete.Point       # Wraps Ordinal.Finite
  Affine.Discrete.Vector      # ℤ displacement
  # Pure affine geometry operations
```

**Advantages**:
- **Mathematically correct**: Each package has coherent semantics
- **Clear operation ownership**: Monus is in Cardinal, not Affine
- **Future-proof**: Transfinite extensions have natural homes
- **Principled naming**: Types reflect mathematical concepts
- **Educational**: Users learn correct mathematical vocabulary

**Disadvantages**:
- Migration required
- More packages to manage
- Deeper dependency chains

**Assessment**: Mathematically sound. Correctness over convenience.

### 5.3 Option C: Hybrid (Cardinal Package, Keep Affine Position)

**Structure**:
```
swift-cardinal-primitives/
  Cardinal.Finite             # Cardinality
  Cardinal.Monus

swift-affine-primitives/
  Affine.Discrete.Position    # Keep as-is (ordinal interpretation)
  Affine.Discrete.Displacement # ℤ
  # Count moved out
```

**Advantages**:
- Less disruptive than Option B
- Separates the clearly misplaced Count
- Affine operations remain coherent

**Disadvantages**:
- Half-measure: Position is still an ordinal in an affine package
- Inconsistent: Why is Position "affine" but Count is "cardinal"?
- Future technical debt

**Assessment**: Compromise. Better than status quo, worse than full separation.

### 5.4 Comparison Matrix

| Criterion | Option A (Status Quo) | Option B (Full Separation) | Option C (Hybrid) |
|-----------|----------------------|---------------------------|-------------------|
| Mathematical correctness | ✗ | ✓✓ | ✓ |
| Semantic clarity | ✗ | ✓✓ | ✓ |
| Migration cost | ✓✓ (none) | ✗ | ✓ |
| Future extensibility | ✗ | ✓✓ | ✓ |
| Dependency complexity | ✓✓ | ✗ | ✓ |
| Educational value | ✗ | ✓✓ | ✓ |
| Timeless infrastructure | ✗ | ✓✓ | ✗ |

---

## 6. Relationship Between Types

### 6.1 Finite Case Isomorphism

For finite values, ordinals and cardinals are **isomorphic as sets** but **distinct as types**:

```
Ordinal.Finite ≅ ℕ ≅ Cardinal.Finite    (as sets)
Ordinal.Finite ≠ Cardinal.Finite         (as types)
```

This is analogous to how meters and seconds are both real numbers but represent different physical quantities.

### 6.2 Conversion Semantics

| Conversion | Meaning | Totality |
|------------|---------|----------|
| Ordinal → Cardinal | "How many positions before this one?" | Total |
| Cardinal → Ordinal | "The position at this count" | Total |
| Count → Index (endIndex) | "Position one past the last element" | Total |
| Index → Count | "How many positions from start?" | Total (for non-negative) |

### 6.3 Affine Operations on Ordinals

The affine interpretation remains valid for ordinals:

| Operation | Type | Meaning |
|-----------|------|---------|
| position + displacement | Ordinal × ℤ → Ordinal | Move position by offset |
| position - position | Ordinal × Ordinal → ℤ | Distance between positions |
| displacement + displacement | ℤ × ℤ → ℤ | Compose offsets |

These are geometric operations on ordinals, justifying an `Affine` layer that uses ordinals.

### 6.4 Cardinal Operations (Not Affine)

| Operation | Type | Meaning |
|-----------|------|---------|
| count + count | Cardinal × Cardinal → Cardinal | Disjoint union size |
| count ∸ count | Cardinal × Cardinal → Cardinal | Remaining after removal |
| count × count | Cardinal × Cardinal → Cardinal | Cartesian product size |

These are set-theoretic operations on cardinals. They do not belong in `Affine`.

---

## 7. Transfinite Considerations

### 7.1 Why This Matters Now

Even though we implement only finite ordinals/cardinals, the **structure** must accommodate future transfinite extensions:

| Finite | Transfinite Ordinal | Transfinite Cardinal |
|--------|---------------------|---------------------|
| 0, 1, 2, ... | ω, ω+1, ω·2, ω², ... | ℵ₀, ℵ₁, 2^ℵ₀, ... |

### 7.2 Structural Requirements

**Ordinal hierarchy** (well-founded):
```
Ordinal.Finite       ⊂ Ordinal (includes ω, ω+1, ...)
Ordinal.Limit        ⊂ Ordinal (limit ordinals: ω, ω², ...)
Ordinal.Successor    ⊂ Ordinal (successor ordinals: 1, 2, ω+1, ...)
```

**Cardinal hierarchy**:
```
Cardinal.Finite      ⊂ Cardinal (includes ℵ₀, ℵ₁, ...)
Cardinal.Countable   ⊂ Cardinal (≤ ℵ₀)
Cardinal.Uncountable ⊂ Cardinal (> ℵ₀)
```

### 7.3 Use Cases for Transfinite

- **Lazy sequences**: Countably infinite (cardinality ℵ₀)
- **Function spaces**: Potentially uncountable
- **Well-founded recursion**: Requires transfinite ordinals
- **Termination proofs**: Ordinal measures

The package structure must not preclude these extensions.

---

## 8. Proposed Package Organization

### 8.1 Package Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    swift-primitives                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │ swift-ordinal-      │    │ swift-cardinal-     │        │
│  │ primitives          │    │ primitives          │        │
│  │                     │    │                     │        │
│  │ Ordinal.Finite      │    │ Cardinal.Finite     │        │
│  │ Ordinal.Successor   │    │ Cardinal.Monus      │        │
│  │ Ordinal.Predecessor │    │ Cardinal.Sum        │        │
│  │ Ordinal.Comparison  │    │ Cardinal.Product    │        │
│  └─────────┬───────────┘    └──────────┬──────────┘        │
│            │                           │                    │
│            └───────────┬───────────────┘                    │
│                        │                                    │
│            ┌───────────▼───────────┐                        │
│            │ swift-affine-         │                        │
│            │ primitives            │                        │
│            │                       │                        │
│            │ Affine.Discrete.Point │ ← Ordinal.Finite      │
│            │ Affine.Discrete.Vector│ ← ℤ                   │
│            │ (affine operations)   │                        │
│            └───────────┬───────────┘                        │
│                        │                                    │
│            ┌───────────▼───────────┐                        │
│            │ swift-index-          │                        │
│            │ primitives            │                        │
│            │                       │                        │
│            │ Index<Tag>            │ ← Phantom Ordinal     │
│            │ Index<Tag>.Count      │ ← Phantom Cardinal    │
│            │ Index<Tag>.Offset     │ ← Phantom ℤ           │
│            └───────────────────────┘                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Dependency Graph

```
swift-ordinal-primitives ←──┐
                            ├── swift-affine-primitives ←── swift-index-primitives
swift-cardinal-primitives ←─┘
```

### 8.3 Type Mapping

| Current Type | New Location | New Name |
|--------------|--------------|----------|
| `Affine.Discrete.Position` | swift-ordinal-primitives | `Ordinal.Finite` |
| `Affine.Discrete.Count` | swift-cardinal-primitives | `Cardinal.Finite` |
| `Affine.Discrete.Count.subtract.saturating` | swift-cardinal-primitives | `Cardinal.Monus.callAsFunction` |
| `Affine.Discrete.Displacement` | swift-affine-primitives | `Affine.Discrete.Vector` |

### 8.4 Backward Compatibility

Typealiases in `swift-affine-primitives` preserve existing API:

```swift
// swift-affine-primitives/Sources/Affine Primitives/Compatibility.swift

@available(*, deprecated, renamed: "Ordinal.Finite")
public typealias Position = Ordinal.Finite

@available(*, deprecated, renamed: "Cardinal.Finite")
public typealias Count = Cardinal.Finite
```

---

## 9. API Design

### 9.1 Ordinal.Finite API

```swift
// swift-ordinal-primitives/Sources/Ordinal Primitives/Ordinal.Finite.swift

public struct Ordinal {
    /// A finite ordinal (position in a well-ordered sequence).
    public struct Finite: Hashable, Comparable, Sendable {
        public let rawValue: Int

        public init(_ rawValue: Int) throws(Error)
        public init(__unchecked rawValue: Int)

        public static var zero: Self

        /// Successor: S(n) = n + 1
        public var successor: Self

        /// Predecessor: P(n) = n - 1 (partial)
        public func predecessor() throws(Error) -> Self
    }
}

extension Ordinal.Finite {
    public enum Error: Swift.Error, Hashable, Sendable {
        case negativeOrdinal(Int)
        case predecessorOfZero
    }
}
```

### 9.2 Cardinal.Finite API

```swift
// swift-cardinal-primitives/Sources/Cardinal Primitives/Cardinal.Finite.swift

public struct Cardinal {
    /// A finite cardinal (cardinality of a finite set).
    public struct Finite: Hashable, Comparable, Sendable {
        public let rawValue: Int

        public init(_ rawValue: Int) throws(Error)
        public init(__unchecked rawValue: Int)

        public static var zero: Self
        public static var one: Self

        /// Addition: |A| + |B| = |A ⊔ B|
        public static func + (lhs: Self, rhs: Self) -> Self

        /// Monus (saturating subtraction): total function
        public var subtract: Property<Subtract, Self>
    }
}

extension Cardinal.Finite {
    public enum Subtract {}
}

extension Property where Tag == Cardinal.Finite.Subtract, Base == Cardinal.Finite {
    /// Saturating subtraction: max(0, self - other)
    @inlinable
    public func saturating(_ other: Base) -> Base

    /// Exact subtraction (partial)
    @inlinable
    public func exact(_ other: Base) throws(Base.Error) -> Base

    /// Default: exact subtraction
    @inlinable
    public func callAsFunction(_ other: Base) throws(Base.Error) -> Base
}

extension Cardinal.Finite {
    public enum Error: Swift.Error, Hashable, Sendable {
        case negativeCardinal(Int)
    }
}
```

### 9.3 Conversion API

```swift
// swift-ordinal-primitives or swift-cardinal-primitives

extension Ordinal.Finite {
    /// Convert ordinal to cardinal: "how many predecessors?"
    public var cardinality: Cardinal.Finite {
        Cardinal.Finite(__unchecked: rawValue)
    }
}

extension Cardinal.Finite {
    /// Convert cardinal to ordinal: "position at this count"
    public var ordinal: Ordinal.Finite {
        Ordinal.Finite(__unchecked: rawValue)
    }
}
```

---

## 10. Empirical Validation (Cognitive Dimensions)

### 10.1 Visibility

**Question**: Can users find the API they need?

| Scenario | Status Quo | Proposed |
|----------|------------|----------|
| "I need a position type" | Search Affine.Discrete | Search Ordinal |
| "I need a count type" | Search Affine.Discrete | Search Cardinal |
| "I need saturating subtraction" | ??? (not discoverable) | Cardinal.subtract.saturating |

**Assessment**: Proposed organization improves discoverability by aligning package names with mathematical concepts.

### 10.2 Consistency

**Question**: Do similar things work similarly?

| Operation | Status Quo | Proposed |
|-----------|------------|----------|
| Position arithmetic | In Affine | In Ordinal (successor/predecessor) + Affine (geometric) |
| Count arithmetic | In Affine (misplaced) | In Cardinal |

**Assessment**: Proposed organization is more consistent—each package has coherent operations.

### 10.3 Role-Expressiveness

**Question**: Is the purpose of each element clear?

| Type | Status Quo | Proposed |
|------|------------|----------|
| Position | "Affine... discrete... position?" | "Ordinal: a position" |
| Count | "Why is count in Affine?" | "Cardinal: a cardinality" |

**Assessment**: Proposed names directly communicate mathematical role.

### 10.4 Abstraction Level

**Question**: Is the level of abstraction appropriate?

- **Ordinal/Cardinal**: Mathematical foundations—correct abstraction for primitives
- **Affine**: Geometric interpretation—appropriate for operations, not for the underlying number types

---

## 11. Migration Strategy

### 11.1 Phase 1: Create New Packages

1. Create `swift-ordinal-primitives` with `Ordinal.Finite`
2. Create `swift-cardinal-primitives` with `Cardinal.Finite` and monus
3. Both packages have no dependencies (foundational)

### 11.2 Phase 2: Update Affine Primitives

1. Add dependencies on ordinal and cardinal packages
2. Redefine `Affine.Discrete.Position` as wrapper/alias for `Ordinal.Finite`
3. Move `Count` usage to `Cardinal.Finite`
4. Keep `Displacement` as `Affine.Discrete.Vector` (ℤ)

### 11.3 Phase 3: Update Index Primitives

1. `Index<Tag>` wraps `Ordinal.Finite` with phantom type
2. `Index<Tag>.Count` wraps `Cardinal.Finite` with phantom type
3. Update `subtract.saturating` to delegate to `Cardinal.Finite`

### 11.4 Phase 4: Deprecation

1. Add deprecated typealiases for backward compatibility
2. Document migration path
3. Remove deprecations in future major version

---

## 12. Outcome

### 12.1 Status

**Status**: RECOMMENDATION

This research recommends **Option B: Full Separation** with dedicated `swift-ordinal-primitives` and `swift-cardinal-primitives` packages.

### 12.2 Rationale

1. **Mathematical correctness**: Ordinals and cardinals are distinct concepts with different operations
2. **Semantic clarity**: Package names communicate mathematical meaning
3. **Future-proof**: Structure accommodates transfinite extensions
4. **Educational value**: Users learn correct mathematical vocabulary
5. **Timeless infrastructure**: Foundations should be principled, not convenient

### 12.3 Implementation Priority

| Priority | Action |
|----------|--------|
| High | Create `swift-cardinal-primitives` (monus is already implemented) |
| High | Create `swift-ordinal-primitives` (position semantics) |
| Medium | Refactor `swift-affine-primitives` to use new foundations |
| Medium | Update `swift-index-primitives` |
| Low | Remove deprecated aliases |

### 12.4 Open Questions

1. **Naming precision**: Should it be `Ordinal.Finite` or just `Ordinal` with transfinite as extension?
2. **Phantom type location**: Should phantom wrappers be in ordinal/cardinal or index?
3. **Affine retention**: Should `Affine.Discrete` exist at all, or just use ordinals directly?

These questions require follow-up research or implementation experimentation.

---

## 13. References

### 13.1 Set Theory

- Kunen, K. (1980). *Set Theory: An Introduction to Independence Proofs*. North-Holland.
- Jech, T. (2003). *Set Theory* (3rd ed.). Springer.
- Halmos, P. (1960). *Naive Set Theory*. Van Nostrand.

### 13.2 Type Theory

- Pierce, B. C. (2002). *Types and Programming Languages*. MIT Press.
- Harper, R. (2016). *Practical Foundations for Programming Languages* (2nd ed.). Cambridge.
- The Univalent Foundations Program. (2013). *Homotopy Type Theory*.

### 13.3 Programming Languages

- Rust Reference. "Primitive Types." https://doc.rust-lang.org/reference/types.html
- Agda Documentation. "Data.Fin." https://agda.github.io/agda-stdlib/
- Haskell `base` library. "Numeric.Natural."

### 13.4 API Usability

- Green, T. R. G., & Petre, M. (1996). "Usability Analysis of Visual Programming Environments." *Journal of Visual Languages & Computing*, 7(2), 131-174.

---

## Appendix A: Extended Formal Definitions

### A.1 Von Neumann Ordinals

The von Neumann construction defines ordinals as:
- 0 = ∅
- S(α) = α ∪ {α}

For finite ordinals:
- 0 = ∅
- 1 = {∅}
- 2 = {∅, {∅}}
- n = {0, 1, ..., n-1}

### A.2 Cardinal Arithmetic

For finite cardinals:
- |A| + |B| = |A ⊔ B| (disjoint union)
- |A| × |B| = |A × B| (Cartesian product)
- |A| ∸ |B| = max(0, |A| - |B|) (monus)

### A.3 Monus Properties

The monus operation satisfies:
1. a ∸ 0 = a (identity)
2. 0 ∸ a = 0 (annihilation)
3. a ∸ a = 0 (self-inverse)
4. (a ∸ b) ∸ c = a ∸ (b + c) (associativity with addition)
5. a ∸ b ≤ a (non-increasing)

These properties justify monus as the canonical total subtraction on ℕ.

---

## Appendix B: Agda Reference Implementation

```agda
-- Finite ordinals
data Fin : ℕ → Set where
  zero : {n : ℕ} → Fin (suc n)
  suc  : {n : ℕ} → Fin n → Fin (suc n)

-- Finite cardinals (just ℕ with cardinality interpretation)
Cardinal : Set
Cardinal = ℕ

-- Monus
_∸_ : ℕ → ℕ → ℕ
zero  ∸ _     = zero
suc m ∸ zero  = suc m
suc m ∸ suc n = m ∸ n

-- Conversion
toCardinal : {n : ℕ} → Fin n → Cardinal
toCardinal zero    = zero
toCardinal (suc i) = suc (toCardinal i)
```

---

*Document version 1.0.0 — 2026-01-26 — Status: IN_PROGRESS*
