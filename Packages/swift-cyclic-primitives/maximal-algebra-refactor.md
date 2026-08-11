# Maximal Algebra Refactor

<!--
---
version: 1.0.0
last_updated: 2026-02-04
status: RECOMMENDATION
tier: 2
packages: [swift-cyclic-primitives, swift-algebra-primitives]
---
-->

## Context

swift-cyclic-primitives defines cyclic groups (ℤ/nℤ) with hand-rolled group operations. Meanwhile, swift-algebra-primitives provides the canonical algebraic vocabulary: `Algebra.Group<Element>`, `Algebra.Group.Abelian<Element>`, `Algebra.Ring<Element>`, `Algebra.Field<Element>`, plus `Algebra.Z<n>` — a complete ℤ/nℤ implementation with ring and field witnesses.

The abstract algebraic vocabulary (what a group IS, what a ring IS) is conceptually more foundational than any concrete instance of it. Cyclic groups are instances built on that vocabulary. The tier document is non-final; from first principles, algebra-primitives' core hierarchy (Magma → Field, Module, Law) depends only on witness-primitives and belongs at a low tier. Cyclic-primitives should depend on algebra, not the reverse.

## Question

How should swift-cyclic-primitives be maximally refactored to use algebra-primitives, eliminating all re-implementation of algebraic concepts? All breaking changes are allowed.

## Inventory

### Source Files

| File | Type | Content |
|------|------|---------|
| `Cyclic.swift` | Namespace | `enum Cyclic {}` |
| `Cyclic.Group.swift` | Namespace | `extension Cyclic { enum Group {} }` |
| `Cyclic.Group.Modulus.swift` | Value type | Dynamic modulus wrapper (> 0 invariant) |
| `Cyclic.Group.Modulus.Error.swift` | Error | `.zeroModulus` |
| `Cyclic.Group.Element.swift` | Value type | Dynamic-modulus element with operations |
| `Cyclic.Group.Static.swift` | Value type | Compile-time modulus group, iterable |
| `Cyclic.Group.Static.Element.swift` | Value type | Static-modulus element with `+`, `-`, `.inverse` |
| `Cyclic.Group.Static.Element.Error.swift` | Error | `.invalidModulus`, `.outOfBounds(Int)` |
| `Cyclic.Group.Static.Iterator.swift` | Iterator | Produces 0..<modulus |
| `Tagged+Cyclic.swift` | Extensions | Tagged arithmetic for phantom-typed cyclic elements |

### Operation-by-Operation Overlap with Algebra.Z<n>

| Cyclic Operation | Algebra.Z<n> Equivalent | Duplicated? |
|-----------------|------------------------|-------------|
| `Static<N>.Element.zero` | `Algebra.Z<N>.zero` | **Yes** |
| `Static<N>.Element.one` | `Algebra.Z<N>.one` | **Yes** |
| `+` (modular addition) | `+` (modular addition) | **Yes** |
| `-` (modular subtraction) | `-` (modular subtraction) | **Yes** |
| `prefix -` (negation) | `.negated` | **Yes** |
| `.inverse` | `.negated` | **Yes** |
| `init(_:)` bounds check | `init(_:)` bounds check | **Yes** |
| `init(wrapping:)` | `init(wrapping:)` | **Yes** |
| `+=`, `-=` | (not provided) | Cyclic-only |
| `Sequence` conformance | (not provided) | Cyclic-only |
| `Iterator` | (not provided) | Cyclic-only |
| Dynamic modulus variant | (not provided) | Cyclic-only |
| Ring multiplication | `*` (modular multiplication) | Z-only |
| Field inverse | `.inverse()` via extended Euclidean | Z-only |
| Primality test | `isPrime()` | Z-only |

### Representation Comparison

| Aspect | `Cyclic.Group.Static<N>.Element` | `Algebra.Z<N>` |
|--------|----------------------------------|----------------|
| Backing | `position: Ordinal` | `Tagged<Residue<N>, Ordinal>` |
| Generic param | `let N: Int` (value generic) | `let n: Int` (value generic) |
| Algebraic scope | Additive group only | Ring, field, semiring witnesses |
| Multiplication | No | Yes (throwing) |
| Protocols | `Equation.Protocol`, `Comparison.Protocol`, `Hash.Protocol` | `Equatable`, `Hashable`, `Comparable` |
| `~Copyable` support | Yes (via custom protocols) | No (uses stdlib protocols) |
| Sequence/iteration | Yes (group is iterable) | No |
| Dynamic modulus | Yes (`Cyclic.Group.Element`) | No |

## Analysis

### Option A: Unify — Replace Static Element with Algebra.Z<N>

Delete `Cyclic.Group.Static<N>.Element` entirely. The compile-time cyclic group element becomes `Algebra.Z<N>`. Cyclic-primitives depends on algebra-primitives and re-exports or wraps `Algebra.Z`.

**Advantages**:
- Eliminates ALL duplication (~50 lines of modular arithmetic)
- Single canonical ℤ/nℤ type in the ecosystem
- Ring, field, and semiring witnesses are immediately available
- Law verification harnesses work out of the box

**Disadvantages**:
- `Algebra.Z<N>` currently lacks `~Copyable`-safe protocols (`Equation.Protocol`, `Hash.Protocol`)
- `Algebra.Z<N>` lacks `Sequence` conformance (iterating group elements)
- `Algebra.Z<N>` uses `Tagged<Residue<N>, Ordinal>` — different internal representation
- Breaking change: all downstream consumers of `Cyclic.Group.Static<N>.Element` must migrate

**Resolution of disadvantages**:
- Add `Equation.Protocol`, `Comparison.Protocol`, `Hash.Protocol` conformances to `Algebra.Z<N>` (these are extensions, not breaking changes to algebra)
- Add `Sequence` conformance to a group-level abstraction or to `Algebra.Z<N>` directly
- The representation difference is internal; the public API can be preserved via typealiases

### Option B: Delegate — Keep Type, Replace Operations

Keep `Cyclic.Group.Static<N>.Element` as a distinct type but replace all hand-rolled arithmetic with calls to `Algebra.Z<N>` operations or algebra witnesses.

**Advantages**:
- Preserves the `Cyclic.Group` namespace and API surface
- `~Copyable` protocol conformances remain undisturbed
- Dynamic modulus variant (`Cyclic.Group.Element`) stays as-is
- Less disruptive to downstream consumers

**Disadvantages**:
- Still two types representing the same concept
- Duplication is reduced but not eliminated (still need conversion layer)
- Ring/field structure requires going through Algebra.Z anyway

### Option C: Witness-Only — Add Group Witness, Keep Implementation

Keep all existing implementation. Add `Algebra.Group.Abelian` witness property.

**Advantages**:
- Zero breaking changes
- Enables law verification

**Disadvantages**:
- Duplication remains fully intact
- Two parallel ℤ/nℤ types with no connection

### Comparison

| Criterion | A: Unify | B: Delegate | C: Witness-Only |
|-----------|----------|-------------|-----------------|
| Duplication eliminated | **100%** | ~80% | 0% |
| Breaking changes | High | Medium | None |
| Single canonical type | **Yes** | No | No |
| Ring/field access | **Immediate** | Via conversion | None |
| `~Copyable` protocols | Requires extension work | Preserved | Preserved |
| Dynamic modulus | Unaffected (stays) | Unaffected | Unaffected |
| Law verification | **Full** | Full | Full |

## Recommendation

**Option A (Unify)** with a migration path.

### Phase 1: Make Algebra.Z<N> the canonical ℤ/nℤ

1. Add `Equation.Protocol`, `Comparison.Protocol`, `Hash.Protocol` conformances to `Algebra.Z<N>` in algebra-primitives (additive, non-breaking)
2. Add `Sequence` support: make `Algebra.Z<N>` iterable (static method or companion type that produces all residues 0..<N)

### Phase 2: Typealias and migrate cyclic-primitives

1. Add `swift-algebra-primitives` as a dependency of cyclic-primitives
2. Typealias: `Cyclic.Group.Static<N>.Element = Algebra.Z<N>` (or define a thin wrapper that is `Algebra.Z<N>` with added protocol conformances)
3. Remove hand-rolled `+`, `-`, `prefix -`, `.inverse`, `.zero`, `.one`, `init(_:)`, `init(wrapping:)` — these are all provided by `Algebra.Z<N>`
4. Keep `Cyclic.Group.Static<N>` as the iterable group type (it can vend `Algebra.Z<N>` elements)
5. Keep `Cyclic.Group.Element` + `Cyclic.Group.Modulus` (dynamic variant) unchanged — no algebra equivalent exists

### Phase 3: Provide algebra witnesses

The unified type already has ring/field/semiring witnesses from `Algebra.Z<N>`:
- `Algebra.Z<N>.ring` — additive abelian group + multiplicative monoid
- `Algebra.Z<N>.semiring` — projects from ring
- `Algebra.Z<N>.field()` — available for prime moduli

### What Stays Unique to Cyclic-Primitives

| Feature | Reason |
|---------|--------|
| `Cyclic.Group.Element` + `Cyclic.Group.Modulus` | Dynamic modulus has no algebra equivalent |
| `Cyclic.Group.Static<N>` as `Sequence` | Group-level iteration is a cyclic concept |
| `Tagged+Cyclic.swift` phantom-typed operations | Domain-specific indexing |
| `~Copyable` protocol conformances | Move-only support |

### Package.swift Change

```swift
dependencies: [
    .package(path: "../swift-algebra-primitives"),
    .package(path: "../swift-comparison-primitives"),
    .package(path: "../swift-hash-primitives"),
    .package(path: "../swift-ordinal-primitives"),
    .package(path: "../swift-cardinal-primitives"),
    .package(path: "../swift-sequence-primitives"),
],
```

Add `Algebra Ring Primitives` (or the aggregate `Algebra Primitives`) product to the target dependencies.

### Breaking Changes

| Removed | Replacement | Migration |
|---------|-------------|-----------|
| `Cyclic.Group.Static<N>.Element` (struct) | `Algebra.Z<N>` (typealias or re-export) | Mechanical rename |
| Hand-rolled `+`, `-`, `prefix -` | `Algebra.Z<N>` operators | Same signatures, drop-in |
| `.inverse` property | `.negated` property | Rename |
| `init(_:)` | `Algebra.Z<N>.init(_:)` | Same semantics |
| `init(wrapping:)` | `Algebra.Z<N>.init(wrapping:)` | Same semantics |

## Outcome

**Status**: RECOMMENDATION

Unify `Cyclic.Group.Static<N>.Element` with `Algebra.Z<N>` to eliminate all duplication. The dynamic modulus variant (`Cyclic.Group.Element`) remains unique to cyclic-primitives. The tier document should be updated to place algebra's core hierarchy at a low tier, reflecting that abstract algebraic vocabulary is more foundational than concrete cyclic group instances.

## References

- `/Users/coen/Developer/swift-primitives/swift-cyclic-primitives/Sources/Cyclic Primitives/` — All source files
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Primitives/Algebra.Z.swift` — Z<n> implementation
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Primitives/Algebra.Z+Arithmetic.swift` — Z<n> arithmetic
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Primitives/Algebra.Z+Ring.swift` — Z<n> ring witness
- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Primitives/Algebra.Z+Field.swift` — Z<n> field witness
