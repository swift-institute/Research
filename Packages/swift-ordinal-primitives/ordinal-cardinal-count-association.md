# Ordinal-Cardinal Count Association

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 2
---
-->

## Context

During refactoring of `swift-storage-primitives` from `Index<Storage>` to `Index<Element>`, a type system question arose: to make `Swift.Range<Index<Element>>.count` return `Index<Element>.Count`, we need to add a `Count` associated type to `Ordinal.Protocol`.

This raises the mathematical question: **Is it sound to associate a "count" type with ordinal types?**

## Question

Is it mathematically and type-theoretically sound to define:
- `Ordinal.Protocol.Count` as an associated type
- Where `Ordinal.Count = Cardinal`
- And `Tagged<T, Ordinal>.Count = Tagged<T, Cardinal>` (i.e., `Index<T>.Count`)

Specifically: does the distance/difference between two ordinal positions correctly yield a cardinal quantity?

## Prior Art Survey

### Set Theory Foundations

According to standard set-theoretic definitions ([Murphy, UChicago](https://www.math.uchicago.edu/~may/VIGRE/VIGRE2009/REUPapers/Murphy.pdf), [nLab](https://ncatlab.org/nlab/show/ordinal+number)):

**Ordinal numbers** answer "which one?" — they denote position in a well-ordered sequence.

**Cardinal numbers** answer "how many?" — they measure the size/quantity of sets.

The fundamental relationship:
> "A cardinal number can be defined as a special ordinal number, specifically an ordinal which is not equipollent to any smaller ordinal." — nLab

For **finite ordinals** specifically:
> "Every finite ordinal (natural number) is initial, and no other ordinal associates with its cardinal." — [Set-theoretic definition of natural numbers](https://en.wikipedia.org/wiki/Set-theoretic_definition_of_natural_numbers)

This means: for finite ordinals, the ordinal and cardinal notions coincide—both are natural numbers, but used differently (position vs. quantity).

### The Distance Operation

Given ordinals α ≤ β, there exists a unique γ such that α + γ = β ([ProofWiki: Ordinal Subtraction](https://proofwiki.org/wiki/Ordinal_Subtraction_when_Possible_is_Unique)).

For **finite ordinals** (natural numbers), this γ is precisely the cardinal count of the interval [α, β).

Mathematically: |[α, β)| = β - α (for finite ordinals)

This is the cardinality of the interval—a cardinal quantity derived from two ordinal positions.

### Type Theory Precedent

**Length-Indexed Vectors** ([Agda Documentation](https://agda.readthedocs.io/en/latest/getting-started/what-is-agda.html), [Lean: Indexed Families](https://leanprover.github.io/functional_programming_in_lean/dependent-types/indexed-families.html)):

The canonical example of dependent types:
```
Vec : Nat → Type → Type
Vec n a  -- a vector of n elements of type a
```

Here:
- The **index** `n` is a natural number used as an ordinal (position/bound)
- The **length** `n` is simultaneously a cardinal (count)

For finite naturals, this dual use is sound because finite ordinals and cardinals coincide.

**Fin n Type** ([Lean: Finite Natural Numbers](https://lean-lang.org/doc/reference/latest/Basic-Types/Finite-Natural-Numbers/)):

```
Fin n  -- the type of natural numbers less than n
```

- `n` acts as a cardinal bound
- Elements of `Fin n` are ordinal positions 0..(n-1)
- The *count* of elements in `Fin n` is the cardinal `n`

**Phantom Types** ([HaskellWiki](https://wiki.haskell.org/Phantom_type), [Rust PhantomData](https://bluishcoder.co.nz/2013/08/15/phantom_types_in_rust.html)):

Phantom types tag values with compile-time type information without runtime cost:
> "A phantom type is a parameterised type whose parameters do not all appear on the right-hand side of its definition."

Our `Index<T>` = `Tagged<T, Ordinal>` follows this pattern—`T` is a phantom tag preserving domain information.

### Type-Theoretic Ordinals

Recent work confirms ([arXiv:2301.10696](https://arxiv.org/html/2301.10696)):
> "Set-Theoretic and Type-Theoretic Ordinals Coincide"

And ([arXiv:2208.03844](https://arxiv.org/abs/2208.03844)) develops ordinal theory in homotopy type theory, showing that type-theoretic treatments faithfully capture classical ordinal properties.

## Analysis

### Option A: Add `Count` to `Ordinal.Protocol`

```swift
extension Ordinal {
    public protocol `Protocol` {
        associatedtype Count
        var ordinal: Ordinal { get }
        init(_ ordinal: Ordinal)
    }
}

extension Ordinal: Ordinal.Protocol {
    public typealias Count = Cardinal
}

extension Tagged: Ordinal.Protocol where RawValue == Ordinal, Tag: ~Copyable {
    public typealias Count = Tagged<Tag, Cardinal>  // Already exists as Index<T>.Count
}
```

**Advantages:**
- Mathematically sound: distance between ordinals is a cardinal
- Preserves phantom typing: `Index<T>` → `Index<T>.Count`
- Follows established patterns (Vec, Fin n)
- Enables clean API: `range.count` returns typed count

**Disadvantages:**
- Expands `Ordinal.Protocol` responsibility
- Requires update to ordinal-primitives

### Option B: Separate `Ordinal.Measurable` Protocol

```swift
extension Ordinal {
    public protocol Measurable: Ordinal.Protocol {
        associatedtype Count
    }
}
```

**Advantages:**
- Keeps `Ordinal.Protocol` minimal
- Explicit opt-in to measurability

**Disadvantages:**
- More protocol ceremony
- All ordinal types are measurable anyway (finite ordinals)

### Option C: Compute Inline

Don't add associated type; compute counts from raw values where needed.

**Advantages:**
- No protocol changes

**Disadvantages:**
- Loses type safety
- Ugly `.rawValue.rawValue` patterns
- Doesn't scale

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Mathematical soundness | ✓ | ✓ | ✓ |
| Type preservation | ✓ | ✓ | ✗ |
| Protocol simplicity | Medium | Low | High |
| API ergonomics | ✓ | ✓ | ✗ |
| Required changes | ordinal-primitives | ordinal-primitives | None |

## Mathematical Justification

### Theorem: For finite ordinals, the count of an interval is a cardinal

Given ordinal positions α, β where α ≤ β:
- The interval [α, β) contains exactly β - α elements
- This count is a cardinal number (non-negative quantity)
- For phantom-typed ordinals `Index<T>`, the count preserves the tag: `Index<T>.Count`

**Proof sketch:**
1. Finite ordinals are isomorphic to natural numbers (von Neumann construction)
2. For naturals, |[a, b)| = b - a is well-defined and non-negative
3. This difference is a cardinal (it answers "how many?")
4. Phantom tagging is orthogonal to the mathematical content
5. Therefore `Index<T>.distance → Index<T>.Count` is sound ∎

### The Key Insight

Ordinals and cardinals are **different uses** of the same underlying values (for finite cases):
- Ordinal: "this is position 5"
- Cardinal: "there are 5 things"

The **distance between positions** naturally yields a **quantity**—this is the ordinal→cardinal operation that justifies `Count`.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option A — Add `Count` associated type to `Ordinal.Protocol`

**Rationale**:
1. **Mathematically sound**: The cardinality of an ordinal interval is definitionally a cardinal
2. **Type-theoretically precedented**: `Vec n`, `Fin n`, and phantom types all follow this pattern
3. **Preserves invariants**: Phantom-typed ordinals yield phantom-typed cardinals
4. **Enables clean API**: `range.count: Index<T>.Count` with no raw value extraction

**Implementation path**:
1. Update `swift-ordinal-primitives/Ordinal.Protocol` to add `associatedtype Count`
2. Add `Count = Cardinal` conformance to `Ordinal`
3. Add `Count = Tagged<Tag, Cardinal>` conformance to `Tagged<T, Ordinal>` (may already exist via `Index<T>.Count`)
4. Update `swift-storage-primitives` Range extension to use `Bound.Count`

## References

### Set Theory
- [Cardinal and Ordinal Numbers (Murphy, UChicago)](https://www.math.uchicago.edu/~may/VIGRE/VIGRE2009/REUPapers/Murphy.pdf)
- [Ordinal number - nLab](https://ncatlab.org/nlab/show/ordinal+number)
- [Set-theoretic definition of natural numbers](https://en.wikipedia.org/wiki/Set-theoretic_definition_of_natural_numbers)
- [Ordinal Subtraction when Possible is Unique - ProofWiki](https://proofwiki.org/wiki/Ordinal_Subtraction_when_Possible_is_Unique)

### Type Theory
- [Set-Theoretic and Type-Theoretic Ordinals Coincide (arXiv:2301.10696)](https://arxiv.org/html/2301.10696)
- [Type-Theoretic Approaches to Ordinals (arXiv:2208.03844)](https://arxiv.org/abs/2208.03844)
- [Dependent Types - Agda Documentation](https://agda.readthedocs.io/en/latest/getting-started/what-is-agda.html)
- [Indexed Families - Lean](https://leanprover.github.io/functional_programming_in_lean/dependent-types/indexed-families.html)
- [Finite Natural Numbers - Lean](https://lean-lang.org/doc/reference/latest/Basic-Types/Finite-Natural-Numbers/)

### Phantom Types
- [Phantom Types - HaskellWiki](https://wiki.haskell.org/Phantom_type)
- [Phantom Types in Rust](https://bluishcoder.co.nz/2013/08/15/phantom_types_in_rust.html)

### Programming Language Theory
- [Practical Affine Types (Tov & Pucella)](https://users.cs.northwestern.edu/~jesse/pubs/alms/tovpucella-alms.pdf)
- [Dependent Types for Low-Level Programming](https://people.eecs.berkeley.edu/~necula/Papers/deputy-esop07.pdf)

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status (Option A: add `Count` associated type to `Ordinal.Protocol`). The mathematical justification is complete -- distance between finite ordinals is definitionally a cardinal. Implementation requires updating `swift-ordinal-primitives` (Ordinal.Protocol), adding `Count = Cardinal` conformance, and updating storage-primitives Range extension. This was deprioritized because the ordinal/cardinal foundations work shifted focus to memory-primitives scope (Index<T>.Count already exists and works), and the protocol change would ripple across many downstream packages.

**Resume when**: Ordinal-primitives undergoes a protocol revision, or when the `Range<Index<T>>.count` return type is actively needed to return `Index<T>.Count` instead of `Int`.
