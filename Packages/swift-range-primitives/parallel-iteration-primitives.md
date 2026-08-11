# Parallel Iteration Primitives

<!--
---
version: 1.0.0
last_updated: 2026-02-06
status: RECOMMENDATION
tier: 3
---
-->

## Context

`Range.Lazy.forEach` currently supports single-index iteration. Six sites across three packages (`swift-storage-primitives`, `swift-buffer-primitives`, `swift-queue-primitives`) contain dual-index `while` loops that advance a source index through a range and a destination index from zero in lockstep. A naive `paired(from:)` method solves the immediate problem but only handles arity 2. This research asks whether a more general primitive exists and what it would take to support N-ary parallel iteration.

### Trigger

[RES-001] Design question: is the right abstraction a fixed-arity `paired(from:)` method, a variadic N-ary primitive using parameter packs, or something else entirely?

### Scope

[RES-002a] This is primitives-wide (affects `swift-range-primitives` and all consumers). The decision establishes a long-lived semantic contract, making it Tier 3 per [RES-020].

## Question

What is the correct algebraic abstraction for N-ary parallel iteration over `~Copyable` index ranges, and can Swift express it today?

## Prior Art Survey

[RES-021] Required for Tier 2+.

### Haskell

**Fixed-arity family**: `zipWith` through `zipWith7` in `Data.List`. GHC provides no built-in variadic mechanism.

**`ZipList` applicative**: The key insight. `ZipList` wraps `[]` with a different `Applicative` instance where `<*>` is `zipWith ($)` instead of Cartesian product. N-ary zip becomes applicative chaining: `f <$> ZipList xs <*> ZipList ys <*> ZipList zs`. The `pure` must produce an infinite list (for the identity law), making the `ZipList` applicative **the** canonical pointwise applicative for lists.

**Representable functors**: Kmett's `Data.Functor.Rep` establishes that every representable functor (isomorphic to `(->) r` for some `r`) has a unique "zippy" applicative: `zipWithRep f fa fb = tabulate (\k -> f (index fa k) (index fb k))`. All representable functors are distributive and their applicative is necessarily pointwise.

**Variadic approaches**: Fridlender & Indrika (1998) showed that true `zipWithN` is impossible to type without dependent types or type-class tricks. Template Haskell generates fixed-arity definitions. Type-level natural numbers with `DataKinds` can infer arity from the function type.

### Rust

**Standard library**: `Iterator::zip` is binary only. Chaining produces nested tuples `((A, B), C)`.

**`itertools`**: `izip!` macro flattens nested tuples via code generation. `multizip` implements `Iterator` for tuples up to arity 12 via macro-generated trait impls. Both are arity-limited workarounds for the lack of variadic generics.

**Consensus**: Variadic generics are needed first. Until then, macros remain pragmatic.

### C++23

**`std::views::zip`**: True N-ary via variadic templates. Element type is `std::tuple<range_reference_t<Views>...>`. Shortest-wins semantics. Concept propagation (`forward_range`, `bidirectional_range`, etc.) when all inputs qualify.

**`std::views::zip_transform`**: `zipWith` for C++. Internally wraps `zip_view`. Made first-class rather than `zip | transform` to preserve correct value category semantics.

This is the most mature standard-library solution to N-ary zip in any systems language.

### Swift

**Current**: `Zip2Sequence` (`@frozen`, binary only, `Sequence` conformance only).

**SE-0398** uses variadic `ZipSequence<each S: Sequence>` as its **primary motivating example**. SE-0408 (Pack Iteration, Swift 6.0) enables `for (left, right) in repeat (each lhs, each rhs)` — parallel iteration over multiple packs in a single `for`-`in` loop.

**ABI constraint**: `Zip2Sequence` is `@frozen`. A variadic `ZipSequence` would be a separate type.

### APL / J / K

**Zip does not exist as a named concept.** Scalar functions automatically lift element-wise over conformable arrays. Dyadic Each (`f'`) explicitly pairs corresponding elements for non-scalar functions — it IS zip. The rank operator generalizes further, selecting which sub-cells to pair. Array languages make the zip structure implicit in their evaluation model.

### Summary Table

| Language | N-ary Mechanism | Variadic? | Truncation |
|----------|----------------|-----------|------------|
| Haskell | `ZipList` applicative chaining | No (type-class tricks) | Shortest |
| Rust | `izip!` macro | No (macro) | Shortest |
| C++23 | Variadic templates | Yes | Shortest |
| Swift | SE-0398 `ZipSequence<each S>` (not in stdlib) | Yes (parameter packs) | Shortest |
| APL/J/K | Implicit scalar extension | N/A | Conformable (error) |

## Theoretical Grounding

[RES-022, RES-024] Required for Tier 3.

### Zip as Monoidal Functor Structure

A **lax monoidal functor** `F : (C, ×, I) → (D, ×, I)` is equipped with:

```
φ   : F a × F b → F (a × b)     -- "zip" / "combine"
φ₀  : I → F I                    -- "unit" / "pure"
```

In Haskell notation:

```haskell
class Functor f => Monoidal f where
    (>*<) :: (f a, f b) -> f (a, b)     -- this IS zip
    unit  :: f ()                        -- this IS pure ()
```

**Zip is the monoidal multiplication of a lax monoidal functor.** The `Applicative` type class is the equivalent formulation using the internal hom (closed structure) rather than tensor products. `liftA2 f xs ys = fmap (uncurry f) (zip xs ys)`.

### Monoid in Day Convolution

The deepest characterization: an applicative functor is a **monoid in the functor category `[C, Set]` under Day convolution**:

```
(F ⊛ G)(c) = ∫^{a,b} C(a ⊗ b, c) × F(a) × G(b)
```

- The tensor product is Day convolution (not functor composition, which gives monads).
- The monoid multiplication `μ : F ⊛ F → F` corresponds to zip / `liftA2`.
- The monoid unit `η : C(I, −) → F` corresponds to `pure`.

This distinguishes applicatives from monads categorically: monads use composition as tensor (sequential effects), applicatives use Day convolution (parallel/independent effects).

### Representable Functors

A functor `F` is representable when `F a ≅ r → a` for some representing object `r`. For representable functors, zip is completely determined:

```
zip(fa, fb) = tabulate(λk. (index(fa, k), index(fb, k)))
```

This is pointwise application over the index type. **`Range.Lazy` is a representable functor**: its representing object is `Range.Index`, `tabulate` is the constructor (taking a transform function), and `index` is subscript access. Therefore its applicative instance is necessarily zippy — there is no other choice.

### N-ary Generalization

The monoidal functor structure generalizes to N-ary naturally:

```
φ₀ : I → F I                          -- arity 0 (pure)
φ₁ : F a → F a                        -- arity 1 (identity/fmap)
φ₂ : F a × F b → F (a × b)           -- arity 2 (zip / liftA2)
φₙ : F a₁ × ... × F aₙ → F (a₁ × ... × aₙ)   -- arity N (liftAN)
```

By associativity of the monoidal structure, `φₙ` can always be decomposed into nested binary applications: `φₙ = φ₂ ∘ (id × φₙ₋₁)`. **This means binary zip is the universal primitive** — N-ary zip composes from it without loss.

### The Diagonal Functor

The diagonal functor `Δ : C → C × C` sends `X ↦ (X, X)`. Its right adjoint is the product functor `Π : C × C → C` sending `(A, B) ↦ A × B`. For sequences, `Π` applied to `(Seq A, Seq B)` is precisely zip. The diagonal functor "sets up" the domain; zip is the right adjoint's action.

### Formal Typing for Range.Lazy

Let `R[B]` denote `Range.Lazy<B>` where `B: ~Copyable`. The current interface:

```
forEach     : R[B] → (B → ()) → ()
forEach[E]  : R[B] → (B →[E] ()) →[E] ()    -- with typed throws
```

The proposed parallel iteration adds a second index domain:

```
forEach.paired : R[B] × Index<T> → ((B, Index<T>) → ()) → Index<T>
```

The return type `Index<T>` captures the final position of the paired counter, enabling composition for multi-range linearization (ring buffer unwrapping).

## Analysis

### Option A: Fixed `paired(from:)` — Arity 2 Only

```swift
extension Property where Tag == Range.ForEach {
    @discardableResult @inlinable
    public func paired<Bound: ~Copyable, PairedTag: ~Copyable, E: Swift.Error>(
        from start: Index<PairedTag>,
        _ body: (borrowing Bound, Index<PairedTag>) throws(E) -> Void
    ) throws(E) -> Index<PairedTag>
    where Base == Range.Lazy<Bound> { ... }
}
```

**Advantages**:
- Implementable today, no compiler limitations
- Works with `~Copyable` bounds
- Covers all 6 existing dual-index sites (none need arity > 2)
- Returns final position, enabling composition
- ~25 lines total

**Disadvantages**:
- Only handles arity 2
- Adding arity 3+ later requires new methods (`tripled(from:and:)` etc.)

### Option B: Parameter Pack Variadic `forEach`

```swift
extension Property where Tag == Range.ForEach {
    @inlinable
    public func callAsFunction<Bound: ~Copyable, each Counter: ~Copyable, E: Swift.Error>(
        tracking start: (repeat Index<each Counter>),
        _ body: (borrowing Bound, repeat Index<each Counter>) throws(E) -> Void
    ) throws(E) -> (repeat Index<each Counter>)
    where Base == Range.Lazy<Bound> { ... }
}
```

**Advantages**:
- Handles arbitrary arity in a single definition
- Categorically elegant (full N-ary φₙ)

**Disadvantages**:
- **Cannot mutate pack members during iteration**: Swift parameter packs do not support in-place mutation. Advancing N counters requires a copy-mutate-reassemble pattern per iteration step.
- **Closure signature is unwieldy**: `(borrowing Bound, repeat Index<each Counter>) -> Void` — callers must destructure with pack expansion syntax.
- **`~Copyable` + parameter packs interaction is untested**: No known usage of `~Copyable` bounds within parameter pack expansion in production code.
- **No existing site needs arity > 2**: Zero empirical demand.
- **Tuple return type**: Returning `(repeat Index<each Counter>)` is correct but ergonomically worse than returning a single `Index<T>`.

### Option C: Binary Primitive + Composition (Recommended)

The category theory tells us: **binary zip is the universal primitive**. N-ary decomposes into nested binary applications by monoidal associativity. Rather than building N-ary into the `forEach` API, provide a clean binary `paired(from:)` and rely on composition:

```swift
// Arity 2: direct
Range.Lazy(range).forEach.paired(from: .zero) { src, dst in
    destination.initialize(to: base.move(at: src), at: dst)
}

// Arity 2 + continuation (ring buffer linearization):
let mid = Range.Lazy(first).forEach.paired(from: .zero) { src, dst in ... }
Range.Lazy(second).forEach.paired(from: mid) { src, dst in ... }

// Hypothetical arity 3 (not needed today):
// Compose two paired iterations, or use a local var for the third counter.
```

**Advantages**:
- Categorically sound (φ₂ is the universal primitive)
- Covers all current and foreseeable use cases
- Simple API surface
- No parameter pack limitations
- Return value enables clean composition
- Can be upgraded to N-ary later if parameter packs mature

**Disadvantages**:
- Arity 3+ requires manual composition (but no site needs it)

### Comparison

| Criterion | A: Fixed paired | B: Variadic | C: Binary + compose |
|-----------|----------------|-------------|---------------------|
| Implementable today | Yes | Uncertain | Yes |
| Works with ~Copyable | Yes | Uncertain | Yes |
| Covers all 6 sites | Yes | Yes | Yes |
| Arity > 2 | No | Yes | Via composition |
| API complexity | Low | High | Low |
| Categorical soundness | Partial | Full | Full |
| Future-proof | Moderate | High | High |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option C (binary primitive with composition). This is equivalent to Option A in implementation but framed as the canonical choice rather than a stopgap.

### Rationale

1. **Binary zip is the universal primitive** — category theory proves that φₙ decomposes into iterated φ₂. There is no theoretical benefit to a direct N-ary primitive.

2. **Zero empirical demand for arity > 2** — all 6 sites use exactly 2 parallel indices. The ring buffer case (2 sequential ranges) composes naturally via the return value.

3. **Parameter pack limitations block Option B today** — mutation during pack iteration is unsupported, the `~Copyable` interaction is untested, and the ergonomics are poor.

4. **The return value is the composition mechanism** — `@discardableResult` returning the final `Index<T>` position enables chaining without state leaking through closures.

5. **Forward-compatible** — if parameter packs mature and arity > 2 demand emerges, a variadic overload can be added alongside `paired(from:)` without breaking changes.

### Implementation Path

| Step | File | Lines |
|------|------|-------|
| 1. Add `_borrowingForEachPaired` | `Range.Lazy.swift` | ~12 |
| 2. Add `paired(from:)` on `Property<Range.ForEach, _>` | New `Range.ForEach+Paired.swift` | ~15 |
| 3. Update 5 call sites | storage + buffer packages | Each → single expression |

### Experiment Recommendation

[EXP-001] Before implementation, create an experiment to verify:
- `Range.Lazy` iteration with a closure receiving `(borrowing Bound, Index<T>)` compiles with `~Copyable` bounds
- The `@discardableResult` return pattern works with typed throws
- Performance is equivalent to the manual `while` loop after inlining

## References

[RES-026]

- Fridlender, D. & Indrika, M. (1998). *An n-ary zipWith in Haskell*. BRICS RS-98-38. https://www.brics.dk/RS/98/38/BRICS-RS-98-38.pdf
- Kmett, E. (2008). *Zipping and Unzipping Functors*. The Comonad.Reader. http://comonad.com/reader/2008/zipping-and-unzipping-functors/
- Kmett, E. (2013). *Representing Applicatives*. The Comonad.Reader. http://comonad.com/reader/2013/representing-applicatives/
- Milewski, B. (2017). *Applicative Functors*. https://bartoszmilewski.com/2017/02/06/applicative-functors/
- nLab. *Applicative functor*. https://ncatlab.org/nlab/show/applicative+functor
- nLab. *Day convolution*. https://ncatlab.org/nlab/show/Day+convolution
- SE-0393: Value and Type Parameter Packs. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md
- SE-0398: Allow Generic Types to Abstract Over Packs. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md
- SE-0408: Pack Iteration. https://www.swift.org/blog/pack-iteration/
- C++23 `zip_view`. https://en.cppreference.com/w/cpp/ranges/zip_view
- C++23 `zip_transform_view`. https://en.cppreference.com/w/cpp/ranges/zip_transform_view
- Hackage. *Data.Functor.Rep* (adjunctions). https://hackage.haskell.org/package/adjunctions/docs/Data-Functor-Rep.html
- Swift Forums. *Pack Destructuring & Pack Splitting* (pitch). https://forums.swift.org/t/pitch-pack-destructuring-pack-splitting/79388
