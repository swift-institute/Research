# Range.Lazy Semantic Identity

<!--
---
version: 2.1.0
last_updated: 2026-02-08
status: SUPERSEDED
tier: 3
---
-->

## SUPERSEDED

This document's recommendation to keep the name `Range.Lazy` has been superseded by `Research/vector-rename-analysis.md` v4.0.0 (DECISION). `Range.Lazy<Bound>` has been renamed to `Vector<Bound>` and moved from swift-range-primitives to swift-vector-primitives. The mathematical identity analysis in this document (`Vec n A = Fin n -> A`) was the decisive factor in the rename.

swift-range-primitives now exists as a deprecation shim: `Range.Lazy<Bound> = Vector<Bound>`.

## Context

During the zip-primitive-placement research, a foundational question arose: is `Range.Lazy<Bound>` correctly named? The question is whether `Range.Lazy` is semantically a Range concept, a Sequence concept, or something else entirely.

This matters because:
- If Range.Lazy is semantically a Sequence, it should be `Sequence.Lazy` and live in sequence-primitives (Tier 7), which would reshape the zip placement decision.
- If Range.Lazy is semantically a Range, the current architecture is correct.
- If it's neither, the naming is imprecise and may need correction.

### Trigger

[RES-001] Architecture choice prompted by zip placement research. The relationship between Range.Lazy and Sequence is unclear from first principles.

### Scope

[RES-002a] Primitives-wide — affects range-primitives (Tier 9), sequence-primitives (Tier 7), and the conceptual foundation for all iteration primitives. Tier 3 per [RES-020]: precedent-setting, normative, hard to undo.

### Assumptions

No backwards-compatibility constraints. Breaking changes acceptable. Analysis is purely from principal correctness, not ecosystem fit or implementation difficulty.

## Question

Is `Range.Lazy<Bound: ~Copyable>` semantically a Range, a Sequence, or something else? Should it be renamed?

## What IS Range.Lazy?

Strip away the name. The type is:

```swift
struct _<Bound: ~Copyable> {
    var start: Index
    var end: Index
    var count: Count
    var transform: @Sendable (Index) -> Bound
}
```

This is a **function from a finite integer domain to values**: `f: [start, end) -> Bound`.

Mathematically, this is:
- A **representable functor** with representing object `Fin(n)`: `F(A) = (Fin(n) -> A)`
- A **Naperian functor** with logarithm `Fin(n)` (Gibbons 2017)
- A **monomial** `y^n` in polynomial functor theory (Niu & Spivak 2024)
- A **container** with single shape and `n` positions (Abbott, Altenkirch, Ghani 2003)
- A **finite tabulated function**: `tabulate(f) = (n, f)`
- A point in the **exponential object** `Bound^n` in **Set**
- An **indexed family** `(x_i)_{i in Fin(n)}` of elements of `Bound`
- Isomorphic to `Vec n Bound` (Agda's `Data.Vec.Functional`)

It is NOT, mathematically, any of the following:
- An interval (a range is a subset of an ordered set, not a function)
- A sequence in the automata-theory sense (single-pass consumption)
- A stored collection (elements are computed, not stored)

## Prior Art Survey

[RES-021, RES-023] Required for Tier 3.

### What Other Languages Call This Concept

| Language | Type Name | Constructor | Lazy? | Structure |
|----------|-----------|-------------|-------|-----------|
| **Scala** | **`View.Tabulate[A]`** | `View.Tabulate(n)(f)` | **Yes** | `n: Int, f: Int => A` |
| **Haskell** (vec) | **`Vec n a`** (Pull) | `tabulate` | Yes | `Fin n -> a` |
| **Haskell** (adjunctions) | `Representable f` | `tabulate` / `index` | Depends | `(Rep f -> a) -> f a` |
| **Haskell** (vector) | `Vector a` | `generate` | No | `Int -> (Int -> a) -> Vector a` |
| **Agda** | **`Vector A n`** | `= Fin n -> A` (definitional) | N/A | literally `Fin n -> A` |
| **Agda** (deprecated) | `Table` | record wrapper | N/A | record around `Fin n -> A` |
| **Rust** | `Map<Range<usize>, F>` | `(0..n).map(f)` | Yes | range + closure |
| **Rust** | `[T; N]` | `array::from_fn` | No | eagerly materialized |
| **C++23** | `transform_view<iota_view<int,int>, F>` | `views::iota \| views::transform` | Yes | base view + function |
| **Kotlin** | `List<T>` | `List(n) { init }` | No | eagerly materialized |
| **OCaml** | `'a array` | `Array.init` | No | `int -> (int -> 'a) -> 'a array` |
| **Python** | `map` object | `map(f, range(n))` | Yes | iterator + closure |
| **NumPy** | `ndarray` | `fromfunction` | No | eagerly materialized |
| **Java** | `Stream<T>` | `IntStream.range().mapToObj()` | Yes | stream pipeline |
| **Swift** (stdlib) | `LazyMapSequence<Range<Int>, T>` | `(0..<n).lazy.map(f)` | Yes | base + transform |

**Key finding: Scala's `View.Tabulate`** is structurally identical to `Range.Lazy`. It stores `n: Int` and `f: Int => A`, is lazy, overrides `isEmpty`, `iterator`, and `knownSize`. The name `Tabulate` comes from the mathematical operation of converting a function into a container.

**Key finding: Agda's `Data.Vec.Functional`** defines `Vector A n = Fin n -> A` as a type alias — literally the mathematical identity of the concept. This was originally named `Data.Table` (a record wrapper), deprecated in v1.2 because the record was "needlessly painful to work with" ([agda-stdlib Issue #870](https://github.com/agda/agda-stdlib/issues/870)).

**Key finding: Haskell's `vec` package** provides `Data.Vec.Pull` where `Vec n a = Fin n -> a` — the "pull" representation of a vector. The name explicitly connects representable functors with vectors. `tabulate` and `index` witness the isomorphism.

### Academic Literature

| Tradition | Term | Key Reference |
|-----------|------|---------------|
| Category theory | Representable functor with `Rep = Fin(n)` | Mac Lane, *CWM* (1971), Section III.2 |
| Functional programming | Naperian functor with `Log F = Fin(n)` | Gibbons, "APLicative Programming with Naperian Functors", ESOP 2017 |
| Polynomial functors | Monomial `y^n` | Niu & Spivak, *Polynomial Functors* (2024); Gambino & Kock (2013) |
| Container theory | Container `(1, Fin(n))` — single shape, `n` positions | Abbott, Altenkirch, Ghani, "Categories of Containers", FoSSaCS 2003 |
| Memoization | Tabulated function / memo trie | Bird (1980); Hinze (2000); Elliott (2008) |
| Dependent type theory | `Vec n A = Fin n -> A` | Agda stdlib; McBride (2000) |
| Mathematics | Indexed family `(x_i)_{i in I}` | Standard; see [Wikipedia](https://en.wikipedia.org/wiki/Indexed_family) |
| Mathematics | Exponential object `A^n` | Mac Lane, *CWM*; nLab |

**Gibbons (2017)** is the most targeted published work. He defines a **Naperian functor** as a representable functor whose logarithm (representing type) is finite. He states: "An n-vector has n positions, so to represent the logarithm we need a type with precisely n inhabitants — the bounded naturals." Naperian functors are "containers of a fixed size, where `r` is the type of positions in the container."

**Container theory:** A container is `(S, P)` where `S` is shapes and `P : S -> Set` is positions per shape. For `Range.Lazy`, `S = {*}` (single shape) and `P(*) = Fin(n)`. A container with one shape degenerates to `Fin(n) -> A` — a representable functor. This is the simplest non-trivial container.

**Memoization connection (Hinze 2000, Elliott 2008):** `tabulate` converts a function into a data structure; `index` retrieves values. Elliott: "one does not memoize functions, one turns functions into data and the language automatically memoizes the data." `Range.Lazy` is exactly a tabulated function that has NOT been memoized — it stores the function directly rather than materializing it.

### Naming Patterns Across Ecosystems

The prior art reveals three distinct naming strategies:

**Strategy 1: Name by the concept itself.** Scala: `View.Tabulate`. Agda: `Vector`. Haskell: `Vec`. These name the type by what it IS — a tabulation, or a vector (function from finite index).

**Strategy 2: Name by composition.** Rust: `Map<Range, F>`. C++: `transform_view<iota_view>`. Swift stdlib: `LazyMapSequence<Range, T>`. These treat the concept as "a mapped range" and give it no independent identity.

**Strategy 3: Name by the domain.** Swift-primitives: `Range.Lazy`. This names the type by its index domain rather than by what it produces.

No ecosystem uses "Sequence" for this concept. None. The concept has strictly more structure than a sequence, and every ecosystem recognizes this.

### Internal Prior Art (swift-primitives)

Within the primitives ecosystem:
- `Range.Lazy` is the ONLY type using `.Lazy` as a nested name across all 61 packages
- The `..<` operator produces `Range.Lazy` values, reinforcing the range-syntax mental model
- `Property<Range.ForEach, Range.Lazy<Bound>>` extensions provide iteration
- Conditional conformance to `Sequence.Protocol where Bound: Copyable` exists (added after initial rejection), implying the type IS richer than a sequence but CAN behave as one
- The `Range` namespace enum's doc comment explicitly says: "Unlike LazySequence, which defers traversal of stored elements, Range.Lazy generates values on demand from an integer index domain"

## First-Principles Analysis

### Testing Against "Range"

**Definition**: A range is a contiguous interval `[a, b)` in an ordered set. It's a SET of values, not a function.

**`Range.Lazy<Index<Node>>` is not an interval of Node indices.** It's a function that PRODUCES Node indices from integer positions. The integer interval `[0, count)` is the DOMAIN of the function, not the thing itself.

**Naming principle**: You name something by what it IS, not by what it's indexed by. A phonebook indexed by names is a "phonebook," not a "Name.Lazy."

**However**, Range.Lazy exists specifically to replace `Swift.Range<Bound>` when `Bound` is `~Copyable` (documented in Range.swift line 34). The motivating use case IS ranges — iterating over typed index ranges. And the operations (reversed, drop, prefix, `..<` operator) all derive from the integer interval structure.

| Criterion | Assessment |
|-----------|-----------|
| Is it an interval? | No — it's a function FROM an interval |
| Does it replace Swift.Range? | Yes — that's its origin |
| Do its operations depend on interval structure? | Yes — reversed, drop, prefix, `..<` |
| Is "Range" what users think of? | Partially — they think of element generation, but use range syntax |

**Verdict**: Range.Lazy is not a range, but its operations and motivation are range-derived. The name prioritizes the domain over the codomain.

### Testing Against "Sequence"

**Definition**: A sequence is an ordered enumeration of elements, typically produced one at a time via an iterator. In programming, sequences are single-pass, unindexed, and may be infinite.

| Property | Range.Lazy | Programming Sequences |
|----------|-----------|----------------------|
| Single-pass | No — forEach leaves it intact | Yes |
| Multi-pass | Yes — can iterate repeatedly | No guarantee |
| Random access | Yes — O(1) via transform(index) | No |
| Known count | Yes — O(1) | No (underestimatedCount) |
| Reversible | Yes — O(1) | No |
| Indexed | Yes — integer positions | No |
| Possibly infinite | No — always finite | Yes |

**Range.Lazy has strictly more structure than a sequence.** Calling it `Sequence.Lazy` would be a **lossy description** — it actively hides indexing, random-access, multi-pass, and reversibility. No prior art ecosystem uses "Sequence" for this concept.

**Verdict**: Sequence.Lazy is semantically the WORST option. It hides essential structure.

### Testing Against "Collection"

**Definition**: A collection is an indexed, multi-pass, finite container with subscript access.

| Property | Range.Lazy | Collections |
|----------|-----------|-------------|
| Indexed | Yes (integer) | Yes (associated type) |
| Multi-pass | Yes | Yes |
| Finite | Yes | Yes |
| Subscript access | Possible (transform) | Required |
| Stored elements | No (computed on demand) | Typically yes |
| Reversible | Yes | Sometimes |

**Verdict**: Collection is a close semantic category, but Range.Lazy specifically has NO stored elements. It's closer to a "virtual collection" or "view."

### Testing Against "Vector" (What Agda and Linear Algebra Call It)

**Definition**: In type theory, `Vec n A = Fin n -> A`. In linear algebra, a vector in `R^n` is a function `{1, ..., n} -> R`. A vector IS a function from a finite index set to values.

| Property | Range.Lazy | Vec n A |
|----------|-----------|---------|
| Function from Fin(n) | Yes | Yes (definitionally) |
| Fixed size | Yes (count) | Yes (n) |
| Random access | Yes | Yes (lookup) |
| Lazy | Yes (not memoized) | No (Agda Vec) / Yes (Agda Vector) |

**This is the mathematically exact name.** `Range.Lazy<Bound>` IS `Vec count Bound` — a finite-dimensional vector. The Agda standard library has `Data.Vec.Functional` where `Vector A n = Fin n -> A` as a type alias. This is literally the same structure.

**Verdict**: "Vector" is the most mathematically precise name for what Range.Lazy IS.

### Testing Against "Tabulate" / "View.Tabulate" (What Scala Calls It)

Scala's `View.Tabulate[A](n: Int)(f: Int => A)` is structurally identical to `Range.Lazy<Bound>`. The name comes from the mathematical operation `tabulate : (Fin(n) -> A) -> Vec n A`, which converts a function into a container.

| Criterion | Assessment |
|-----------|-----------|
| Structurally identical | Yes — same fields (count + transform) |
| Established term | Yes — Haskell, Scala, Agda, OCaml all use "tabulate" |
| Communicates laziness | Yes — View.Tabulate is lazy by definition |
| Communicates structure | Partially — emphasizes construction method over properties |

**Verdict**: "Tabulate" accurately describes the construction (tabulating a function over a finite domain) but emphasizes HOW it was built rather than WHAT it is.

### Testing Against "Representable Functor" / "Naperian" (What Category Theory Calls It)

**Definition**: A functor F is representable when `F(A) = (R -> A)` for some representing object R. When R is finite, Gibbons calls F "Naperian."

Range.Lazy is representable with `R = Fin(count)`:
- `tabulate` = `init(count:transform:)` — construct from function
- `index` = `transform(position)` — evaluate at a point
- `zip` is uniquely determined: `zip(fa, fb) = tabulate(k -> (index(fa,k), index(fb,k)))`

**Verdict**: "Representable Functor" and "Naperian Functor" are the most precise academic terms, but too abstract for an API type name.

## The Five-Way Comparison

| Criterion | Range | Sequence | Collection | Vector | Tabulate |
|-----------|-------|----------|------------|--------|----------|
| Mathematical match | Domain only | Weak (lacks structure) | Close (lacks storage) | **Exact** | Construction, not identity |
| Hides structure? | Somewhat (domain != thing) | Yes (hides indexing) | No | No | No |
| Prior art | Swift.Range | None use "Sequence" | Swift Collection | Agda, Haskell, linear algebra | Scala View.Tabulate |
| Motivating use case | Yes (replaces Swift.Range) | No | Partial | Partial | No |
| Operations derivable? | Yes (reversed, drop, `..<`) | Partially | Yes | Yes | Partially |
| User mental model | Partial | Partial | Partial | Unfamiliar in Swift | Unfamiliar |
| Tier impact | None (stays Tier 9) | Would move to Tier 7 | New package needed | Would need new namespace | Could nest in existing |

## The Decisive Arguments

### Argument FOR "Range.Lazy" (Status Quo)

Every operation on Range.Lazy derives from the integer domain structure:
- `reversed()` — needs the domain to be ordered and bounded
- `drop(_:)` / `prefix(_:)` — needs the domain to be sliceable
- `count` — needs the domain to have cardinality
- `..<` operator — constructs from domain bounds
- `zip` — pairs elements by shared domain position
- `forEach` — traverses the domain in order

Remove the integer domain, and you have a bare function `() -> Bound` with no structure. The domain provides ALL the structure. The function (transform) provides the elements, but structure comes from the domain.

**Sequences have no domain.** They just produce elements. You can't reverse a sequence, slice it, or zip it by position — because there are no positions. Range.Lazy CAN do all of these BECAUSE it has a range domain.

This is why Range is the correct namespace: the integer range domain is the architectural core that enables every operation.

### Argument AGAINST "Range.Lazy" (The Naming Imprecision)

Range.Lazy is technically NOT a range. A range is an interval `[a, b)` — a set of values. Range.Lazy is a function FROM an interval TO values. Naming it "Range.Lazy" is like naming a dictionary "Key.Lazy."

Every other ecosystem that has given this concept its own name uses either:
- **The mathematical identity**: Vector (Agda, Haskell, linear algebra)
- **The construction method**: Tabulate (Scala, Haskell's `tabulate`)

Nobody calls it a "Range." The compositional approaches (Rust, C++, Swift stdlib) call it "a mapped range" — acknowledging it's a transform ON a range, not a range itself.

### Argument FOR "Vector"

The mathematically precise name. `Range.Lazy<Bound>` IS `Vec count Bound`. The Agda standard library canonizes this with `Data.Vec.Functional` where `Vector A n = Fin n -> A`. Linear algebra agrees: a vector in `R^n` is a function from `{1,...,n}` to `R`.

But: "Vector" in the Swift ecosystem strongly connotes SIMD/geometry (via `simd_float3`, SwiftUI's `Vector2D`, etc.). Using it for a general-purpose lazy container would create confusion. The Agda/type-theory sense of "Vector" and the Swift/engineering sense are too far apart.

### Argument FOR "Tabulate"

Scala's precedent is strong. `View.Tabulate` is the only major-language type that is structurally identical AND has a principled name. "Tabulate" comes from `Representable.tabulate` in Haskell — the operation that converts a function into a container. Every ecosystem that formalizes this operation calls it `tabulate` (Haskell, Scala, Agda, Idris, OCaml's docs).

But: "Tabulate" describes HOW the type was constructed, not WHAT it is. A vector constructed by tabulation is still a vector. Naming a type by its construction method is like naming `Array` as `Allocate` — it prioritizes the creation story over the structural identity.

## Outcome

**Status**: RECOMMENDATION

### v1.0 -> v2.0 Change

v1.0 concluded as DECISION (Range.Lazy is correctly named). v2.0 downgrades to RECOMMENDATION after the prior art survey revealed that the question is more nuanced than initially assessed. The prior art unanimously avoids "Sequence" but splits between "Range" (no precedent), "Vector" (Agda/Haskell), and "Tabulate" (Scala).

### Recommendation

**Keep `Range.Lazy` as the name**, but acknowledge the imprecision and strengthen the documentation.

### Rationale

1. **Sequence.Lazy is eliminated.** No prior art ecosystem uses "Sequence" for this concept. The type has strictly more structure than a sequence. Naming it by a weaker abstraction is a semantic error. This is settled.

2. **"Vector" is mathematically precise but pragmatically wrong for Swift.** In the Agda/type-theory tradition, `Vec n A = Fin n -> A` is canonical. But in Swift's ecosystem, "Vector" connotes SIMD/geometry. The confusion cost outweighs the precision benefit.

3. **"Tabulate" is principled but names construction over identity.** Scala's `View.Tabulate` is the strongest competing precedent. But naming a type by how it was built (tabulation) rather than what it IS (a function from a finite domain) prioritizes the origin story. This is defensible but not clearly superior.

4. **"Range.Lazy" prioritizes the domain, which provides all structure.** While Range.Lazy is not mathematically a range, every operation derives from the integer domain. The name tells users "this has bounded integer structure" — which IS the operationally relevant fact. The imprecision (function FROM a range, not a range itself) is documented.

5. **Practical weight: the `..<` operator and ecosystem integration.** Users construct Range.Lazy via `(.zero..<count)`, think in terms of range syntax, and operate with range operations (reversed, drop, prefix). The name matches the user's construction and interaction model.

### What Would Change The Recommendation

This recommendation would be reversed if:
- A "Vector" namespace were introduced at the primitives level for a different purpose, making it available for this concept without SIMD confusion
- Swift's ecosystem established "Tabulate" or "Tabulation" as a recognized pattern
- Container theory vocabulary (shapes/positions) became part of the Swift API vocabulary

### What Range.Lazy Actually Is (Documentation Statement)

> `Range.Lazy<Bound>` is a Naperian functor (representable functor with finite logarithm) over the integer domain `[0, count)`. Mathematically, it is the exponential object `Bound^count` — a function `Fin(count) -> Bound` paired with its domain size. The integer domain provides all structural operations (reversed, drop, prefix, zip, subscript); the transform function provides element generation. It serves as the `~Copyable`-capable replacement for `Swift.Range<Bound>` where `Bound: Strideable`.
>
> In type theory, `Range.Lazy<Bound>` is isomorphic to `Vec count Bound` (Agda's `Data.Vec.Functional`). In Scala, the equivalent type is `View.Tabulate`. In polynomial functor theory, it is the monomial `y^count`.

### Naming Precision Improvement

Update the doc comment for Range.Lazy:

```swift
/// A lazy range that maps integer positions to `~Copyable` bounds on-demand.
///
/// `Range.Lazy<Bound>` is a representable functor (Naperian functor) over
/// a finite integer domain. It stores the domain bounds `[start, end)` and
/// a transform function `(Index) -> Bound`, computing elements lazily at
/// each access. No `Bound` values are ever stored.
///
/// This is the `~Copyable`-capable replacement for `Swift.Range<Bound>`
/// where `Bound: Strideable`. In type-theoretic terms, it is isomorphic
/// to `Vec count Bound` (a function `Fin(count) -> Bound`). In Scala,
/// the equivalent type is `View.Tabulate`.
///
/// ## Structural Properties
///
/// | Property | Value |
/// |----------|-------|
/// | Indexed | Yes — O(1) random access via transform |
/// | Multi-pass | Yes — forEach leaves range intact |
/// | Finite | Yes — bounded by [start, end) |
/// | Reversible | Yes — O(1) |
/// | Elements stored | No — computed on demand |
```

### Implications for zip Placement

This recommendation **reinforces** the zip-primitive-placement recommendation: zip belongs in range-primitives as a free function. Range.Lazy is correctly in range-primitives, and zip belongs with its functor.

## References

[RES-026] Tier 3 requires traceable references.

### Primary Sources

- Mac Lane, S. *Categories for the Working Mathematician*, 2nd ed. Springer, 1998. Section III.2 (Representable functors, Yoneda lemma).
- Gibbons, J. "APLicative Programming with Naperian Functors." ESOP 2017, LNCS 10201, pp. 556-583. ([SpringerLink](https://link.springer.com/chapter/10.1007/978-3-662-54434-1_21))
- Abbott, M., Altenkirch, T., Ghani, N. "Categories of Containers." FoSSaCS 2003, LNCS 2620. ([SpringerLink](https://link.springer.com/chapter/10.1007/3-540-36576-1_2))
- Abbott, M., Altenkirch, T., Ghani, N. "Containers: Constructing strictly positive types." TCS 342(1), pp. 3-27, 2005. ([ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0304397505003373))
- Niu, N. and Spivak, D.I. *Polynomial Functors: A Mathematical Theory of Interaction*. Cambridge University Press, 2024. ([arXiv](https://arxiv.org/abs/2312.00990))

### Memoization and Tabulation

- Bird, R.S. "Tabulation Techniques for Recursive Programs." ACM Computing Surveys 12(4), 1980.
- Bird, R.S. "Zippy Tabulations of Recursive Functions." MPC 2008, LNCS 5133.
- Hinze, R. "Generalizing Generalized Tries." JFP 10(4), pp. 327-351, 2000.
- Elliott, C. "Elegant memoization with functional memo tries." Blog/talk, 2008-2014. [MemoTrie](https://github.com/conal/MemoTrie).

### Language-Specific Prior Art

- Scala: [`scala.collection.View.Tabulate`](https://www.scala-lang.org/api/2.13.x/scala/collection/View$$Tabulate.html) — structurally identical lazy type.
- Haskell: [`Data.Functor.Rep`](https://hackage.haskell.org/package/adjunctions/docs/Data-Functor-Rep.html) (adjunctions package) — `Representable` typeclass with `tabulate`/`index`.
- Haskell: [`Data.Vec.Pull`](http://hackage.haskell.org/package/vec-0.1.1/docs/Data-Vec-Pull.html) (vec package) — `Vec n a = Fin n -> a`.
- Haskell: [`Data.Naperian`](https://hackage.haskell.org/package/naperian-0.1.0.0/docs/Data-Naperian.html) — Gibbons' Naperian functors library.
- Agda: [`Data.Vec.Functional`](http://agda.github.io/agda-stdlib/v2.0/Data.Vec.Functional.html) — `Vector A n = Fin n -> A`.
- Rust: [`std::array::from_fn`](https://doc.rust-lang.org/beta/std/array/fn.from_fn.html) — eager array from function.
- C++23: [`std::ranges::transform_view`](https://en.cppreference.com/w/cpp/ranges/transform_view) — lazy view composition.
- OCaml: [`Array.init`](https://ocaml.org/manual/5.3/api/Array.html) — "tabulates the results of `f` applied in order to the integers 0 to n-1."

### Internal Cross-References

- `swift-primitives/Research/zip-primitive-placement.md` — zip belongs with its functor (Range.Lazy)
- `swift-primitives/Research/range-sequence-collection-semantic-analysis.md` — original semantic relationship analysis
- `swift-range-primitives/Research/parallel-iteration-primitives.md` — Range.Lazy as representable functor
- `swift-range-primitives/Research/comparative-analysis.md` — cross-language range primitive comparison

## Changelog

### v2.1.0 (2026-02-08)

- **Status changed**: RECOMMENDATION → SUPERSEDED. The recommendation to keep `Range.Lazy` was overridden by `vector-rename-analysis.md` v4.0.0. `Range.Lazy<Bound>` renamed to `Vector<Bound>` and moved to swift-vector-primitives. This document's mathematical identity analysis (`Vec n A = Fin n -> A`) was the decisive factor.

### v2.0.0 (2026-02-07)

- **Status changed**: DECISION -> RECOMMENDATION. The conclusion holds but with acknowledged nuance.
- **Added**: Full prior art survey (Tier 3 [RES-021, RES-023] requirement). 14 languages/ecosystems surveyed.
- **Added**: Academic literature survey. 8 traditions identified with specific terminology.
- **Added**: Scala `View.Tabulate` as structurally identical prior art.
- **Added**: Agda `Data.Vec.Functional` as the mathematical canonical form.
- **Added**: Haskell `Data.Vec.Pull` (`Vec n a = Fin n -> a`) as representable vector.
- **Added**: Gibbons (2017) Naperian functor terminology.
- **Added**: Container theory, polynomial functor, and species analysis.
- **Added**: "Vector" and "Tabulate" as competing naming alternatives with assessment.
- **Added**: Five-way comparison table (expanded from three-way).
- **Added**: "What Would Change The Recommendation" section.
- **Added**: Full bibliography with traceable references.
- **Preserved**: Original first-principles analysis (unchanged).

### v1.0.0 (2026-02-06)

- Initial analysis. Concluded Range.Lazy is correctly named. Sequence.Lazy rejected.
