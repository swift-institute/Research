# Cyclic Algebra Unification

<!--
---
version: 1.0.0
last_updated: 2026-02-05
status: DECISION
---
-->

## Context

The `swift-cyclic-primitives` package provides cyclic group operations for ring buffer indices and circular navigation. The recently created `swift-algebra-modular-primitives` package provides Z/nZ (integers modulo n) with full algebraic structure (group, ring, field witnesses).

Mathematically, these are the **same object**: the cyclic group Z/nZ under addition. The question is whether we should express cyclic operations using the algebra system rather than maintaining a separate implementation.

**Trigger**: Aggregate decomposition revealed the overlap between `Cyclic.Group.Static<N>.Element` and `Algebra.Z<n>`.

## Question

Should `swift-cyclic-primitives` be eliminated by expressing cyclic group operations through `swift-algebra-modular-primitives`?

## Mathematical Identity

Both packages implement the same algebraic structure:

| Property | Cyclic Group Z/nZ | Implementation |
|----------|-------------------|----------------|
| Set | {0, 1, ..., n-1} | `Ordinal` in [0, n) |
| Identity | 0 | `.zero` |
| Generator | 1 | `.one` |
| Operation | (a + b) mod n | `+` operator |
| Inverse | (n - a) mod n | `.inverse` / `.negated` |

The cyclic group Z/nZ IS the additive group of the ring Z/nZ. There is no mathematical distinction.

## Analysis

### Option A: Keep Both Packages (Status Quo)

**Description**: Maintain `cyclic-primitives` for practical index operations and `algebra-modular-primitives` for algebraic structure.

**Current architecture**:
```
cyclic-primitives:
  Cyclic.Group.Static<N>.Element  — custom struct with position: Ordinal
  Cyclic.Group.Element + Modulus  — dynamic modulus variant

algebra-modular-primitives:
  Algebra.Z<n> = Tagged<Residue<n>, Ordinal>  — compile-time only
```

**Advantages**:
- No migration needed
- Packages serve different abstraction levels
- Dynamic modulus support preserved

**Disadvantages**:
- Duplicate implementations of identical mathematics
- Conceptual confusion: two names for one thing
- Maintenance burden: parallel evolution
- Violates DRY principle

### Option B: Unify Under Algebra (Delete cyclic-primitives)

**Description**: Express all cyclic operations through `algebra-modular-primitives`. Delete `cyclic-primitives`.

**Proposed architecture**:
```
algebra-modular-primitives:
  Algebra.Z<n> = Tagged<Residue<n>, Ordinal>     — static (existing)
  Algebra.Z.Dynamic + Algebra.Z.Modulus          — dynamic (new)

  // Type aliases for practical use:
  typealias Cyclic<n> = Algebra.Z<n>             — ring buffer indices
```

**Migration path**:
1. Add dynamic modulus support to `algebra-modular-primitives`
2. Add `Finite.Enumerable` iteration (already have via `Residue<n>: Finite.Capacity`)
3. Update consumers to use `Algebra.Z<n>` instead of `Cyclic.Group.Static<N>.Element`
4. Provide type aliases if naming is important for domain clarity
5. Delete `cyclic-primitives` and `cyclic-index-primitives`

**Advantages**:
- Single source of truth for Z/nZ
- Consistent with "express algebra through algebra types" philosophy
- Reduces package count
- Full algebraic structure available (multiplication, ring/field witnesses)

**Disadvantages**:
- Consumer migration required (vector-primitives, range-primitives)
- Different naming convention (Algebra.Z vs Cyclic.Group)
- Need to add dynamic modulus support

### Option C: Merge cyclic-primitives INTO algebra-modular-primitives

**Description**: Move cyclic-primitives source files into algebra-modular-primitives, keeping both APIs temporarily for migration.

**Proposed architecture**:
```
algebra-modular-primitives:
  // Core (existing)
  Algebra.Z<n> = Tagged<Residue<n>, Ordinal>

  // Cyclic namespace (migrated from cyclic-primitives)
  Cyclic.Group.Static<N>.Element  — forwards to Algebra.Z<N>
  Cyclic.Group.Element + Modulus  — dynamic variant

  // Deprecation path
  @available(*, deprecated, renamed: "Algebra.Z")
  typealias Cyclic.Group.Static<N>.Element = Algebra.Z<N>
```

**Advantages**:
- Gradual migration
- Preserves existing consumer code temporarily
- Consolidates all modular arithmetic

**Disadvantages**:
- Temporary API duplication
- More complex package
- Delays clean unification

## Evaluation Criteria

**Note**: Implementation difficulty and consumer migration effort are explicitly NOT evaluation criteria. We seek the principally correct solution.

| Criterion | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| Mathematical coherence | Critical | Poor | Excellent | Good |
| Single source of truth | Critical | No | Yes | Partial |
| Algebra-first philosophy | High | Violates | Upholds | Partial |
| API simplicity | Medium | Poor | Good | Fair |
| Naming clarity | Low | Good | Fair | Fair |

## Gap Analysis: What algebra-modular-primitives Needs

To fully replace cyclic-primitives:

### 1. Dynamic Modulus Support (Critical)

cyclic-primitives provides:
```swift
Cyclic.Group.Element        // stores residue only
Cyclic.Group.Modulus        // wraps Cardinal, validates > 0
Cyclic.Group.add(_:_:modulus:)
Cyclic.Group.successor(_:modulus:)
Cyclic.Group.predecessor(_:modulus:)
Cyclic.Group.inverse(_:modulus:)
Cyclic.Group.advanced(_:by:modulus:)
```

algebra-modular-primitives needs equivalent:
```swift
extension Algebra.Z {
    struct Dynamic: Hashable, Sendable { let residue: Ordinal }
    struct Modulus: Hashable, Sendable { let value: Cardinal }

    static func add(_:_:modulus:) -> Dynamic
    static func successor(_:modulus:) -> Dynamic
    // etc.
}
```

### 2. Sequence/Iteration Support

cyclic-primitives provides:
```swift
extension Cyclic.Group.Static: Sequence { ... }
for element in Cyclic.Group.Static<5>() { ... }
```

algebra-modular-primitives has via Finite.Enumerable:
```swift
for element in Algebra.Z<5>.allCases { ... }
```

**Status**: Already supported via `Tagged+Finite.Enumerable`.

### 3. Index Integration

cyclic-index-primitives provides:
```swift
typealias Index<Tag>.Cyclic<N> = Tagged<Tag, Cyclic.Group.Static<N>.Element>
```

Equivalent with algebra:
```swift
typealias Index<Tag>.Modular<N> = Tagged<Tag, Algebra.Z<N>>
// or keep Cyclic name:
typealias Index<Tag>.Cyclic<N> = Tagged<Tag, Algebra.Z<N>>
```

**Note**: This wraps `Tagged<..., Tagged<Residue<N>, Ordinal>>` — double-tagged. May want to flatten.

## Consumer Impact Analysis

### vector-primitives

Current:
```swift
public typealias Index = Cyclic.Group.Static<N>.Element
```

Migration:
```swift
public typealias Index = Algebra.Z<N>
```

**Impact**: Minimal — type alias change only. API surface identical (both have +, -, .zero, .one).

### cyclic-index-primitives

Current: Provides `Index<Tag>.Cyclic<N>` and `Modular` operations.

Migration:
- Move `Modular` operations into algebra-modular-primitives as `Algebra.Z.Dynamic` operations
- `Index<Tag>.Cyclic<N>` becomes `Tagged<Tag, Algebra.Z<N>>`
- Package can be deleted

**Impact**: Medium — need to add dynamic operations to algebra-modular-primitives.

### range-primitives

Current: Only re-exports `Cyclic_Primitives`.

Migration: Remove re-export or replace with `Algebra_Modular_Primitives`.

**Impact**: Minimal — likely no actual usage of Cyclic types.

## Decision

**Option B: Unify Under Algebra — Delete cyclic-primitives**

This is the only principally correct option.

### Mathematical Argument

The cyclic group Z/nZ under addition is **identical** to the additive group of the ring Z/nZ. There is no mathematical distinction whatsoever. Maintaining two implementations of the same mathematical object:

1. **Violates mathematical truth** — pretends two things exist when only one does
2. **Creates conceptual confusion** — users must learn that `Cyclic.Group.Static<5>.Element` and `Algebra.Z<5>` are the same thing
3. **Fragments the type system** — cannot use ring/field operations on "cyclic" values without conversion

### Architectural Argument

The Swift Institute algebra system exists precisely to express algebraic structure through witnesses. If cyclic groups bypass this system:

1. **Undermines the architecture** — ad-hoc implementations exist alongside the principled ones
2. **Sets bad precedent** — other algebraic structures might also get ad-hoc implementations
3. **Duplicates effort** — every improvement to algebra must be mirrored in cyclic

### The Correct Model

```
Algebra.Z<n>                           // The type (compile-time modulus)
Algebra.Z<n>.group                     // The group witness
Algebra.Z<n>.ring                      // The ring witness (when applicable)
Algebra.Z<n>.field()                   // The field witness (when prime)

Algebra.Z.Dynamic                      // Runtime modulus variant
Algebra.Z.Modulus                      // Validated positive modulus
```

Ring buffer indices, circular navigation, and all other "cyclic" use cases are simply **applications** of Z/nZ arithmetic. The domain-specific naming (`Cyclic`) obscures rather than clarifies.

## Implementation Plan

### Phase 1: Add Dynamic Modulus to algebra-modular-primitives

```swift
// Algebra.Z.Dynamic.swift
extension Algebra {
    enum Z {
        struct Dynamic: Hashable, Sendable {
            let residue: Ordinal
        }

        struct Modulus: Hashable, Sendable {
            let value: Cardinal
            init(_ value: Cardinal) throws(Error) { ... }
        }
    }
}

// Algebra.Z.Dynamic+Arithmetic.swift
extension Algebra.Z {
    static func successor(_ element: Dynamic, modulus: Modulus) -> Dynamic
    static func predecessor(_ element: Dynamic, modulus: Modulus) -> Dynamic
    static func add(_ lhs: Dynamic, _ rhs: Dynamic, modulus: Modulus) -> Dynamic
    static func subtract(_ lhs: Dynamic, _ rhs: Dynamic, modulus: Modulus) -> Dynamic
    static func negate(_ element: Dynamic, modulus: Modulus) -> Dynamic
}
```

### Phase 2: Update Index Integration

Move `Modular` operations from cyclic-index-primitives to index-primitives or a new location:

```swift
// In index-primitives or new package
extension Index {
    typealias Cyclic<let N: Int> = Tagged<Tag, Algebra.Z<N>>
}

enum Modular {
    static func successor<Tag>(of: Index<Tag>, capacity: Index<Tag>.Count) -> Index<Tag>
    // Uses Algebra.Z.Dynamic internally
}
```

### Phase 3: Update Consumers

1. **vector-primitives**: Change `Cyclic.Group.Static<N>.Element` to `Algebra.Z<N>`
2. **range-primitives**: Remove Cyclic re-export

### Phase 4: Delete Packages

1. Delete `swift-cyclic-primitives`
2. Delete `swift-cyclic-index-primitives`

## Resolved Questions

1. **Naming**: No. `Cyclic` obscures mathematical truth. Use `Algebra.Z<n>` directly. Consumers learn the correct terminology.

2. **Double-tagging**: `Tagged<Tag, Algebra.Z<N>>` is acceptable. The outer tag provides domain context (e.g., `Index<Buffer>`), the inner structure (`Algebra.Z<N>`) provides the arithmetic. This is the correct layering.

3. **Package location**: Dynamic modulus operations belong in `algebra-modular-primitives`. They are algebra operations, not index-specific operations. Index-primitives may provide convenience wrappers that delegate to the algebra.

## Outcome

**Status**: DECISION

**Delete `swift-cyclic-primitives` and `swift-cyclic-index-primitives`.**

Express all cyclic/modular arithmetic through `Algebra.Z<n>` and the new `Algebra.Z.Dynamic` for runtime modulus.

The mathematical identity is clear: cyclic groups ARE Z/nZ. The architecture demands we use the algebra system. Implementation difficulty is not a factor.

## References

- `swift-cyclic-primitives/Sources/` — current implementation
- `swift-algebra-modular-primitives/Sources/` — target package
- Algebra Aggregate Decomposition Plan — context for this research
