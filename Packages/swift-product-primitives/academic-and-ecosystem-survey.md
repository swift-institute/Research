# Academic and Ecosystem Survey: Product Types

<!--
---
version: 1.0.0
last_updated: 2026-05-08
status: RECOMMENDATION
tier: 2
scope: per-package
peer_doc: api-design-leveraging-property-primitives.md
---
-->

## Context

`swift-product-primitives` ships `Product<each Element>` — a named, variadic,
parameter-pack-backed wrapper around Swift tuples. The current declaration
(at
`/Users/coen/Developer/swift-primitives/swift-product-primitives/Sources/Product Primitives/Product.swift`)
is a single ~70-line file: a `@dynamicMemberLookup` struct with conditional
`Sendable` / `Equatable` / `Hashable` / `Swift.Error` conformances, plus a
note that "Codable conformance for parameter packs requires more complex
handling and may not be directly expressible in current Swift."

This survey is the prior-art / theoretical / future-direction axis. A peer
research document — `api-design-leveraging-property-primitives.md` — owns the
API-shape decision (`product.map.first { f }` vs `product.map(at: 0, …)`,
nested-namespace vs labeled-method, etc.). This document does **not** propose
API decisions. It asks: where does `Product<each E>` sit in 80 years of
mathematical and language-design precedent, and which direction should we
steer toward?

The trigger is `[RES-018]` (convention-violation surfaced during ecosystem
adoption) compounded with `[RES-020]` (Tier 2 multi-author scrutiny): if we
extract a primitive at this layer with no academic context and no awareness of
the upcoming `TupleConformances` / SE-0283-revival landscape, we will either
prefigure a feature wrong or build a wrapper that vanishes when the stdlib
catches up. The peer doc settles `how to call it`; this doc settles `what it
must remain` once the stdlib catches up.

**Scope**: per-package — informs `swift-product-primitives` only, but cites
ecosystem-wide constraints because `~Copyable` packs and SE-0499 affect every
primitive.

## Question

The survey decomposes into seven primary questions:

1. **Q1 — Foundations.** What *exactly* is the categorical product, the
   product as a functor, and the type-theoretic Σ/Π distinction, and how does
   `Product<each E>` map onto each?
2. **Q2 — Languages.** How do Haskell, OCaml, Rust, Scala, F#, Idris/Agda,
   and TypeScript represent product types — name, shape, max arity,
   functor / bimap / projection / append / zip surface — and what design
   regrets did each accumulate?
3. **Q3 — Stdlib.** Where does the Swift stdlib already handle product-shaped
   values today, and where are the seams a wrapper must respect?
4. **Q4 — Evolution.** Which Swift Evolution proposals shape what `Product`
   can express, and what is each proposal's *exact* status?
5. **Q5 — Compiler.** What is in flight in the `swiftlang/swift` repository
   right now (Swift 6.4-dev, late 2025 / early 2026) that will change what
   `Product` can express in the next 6–12 months?
6. **Q6 — Today's adoption surface.** Which features can `Product` use
   *today*, which behind a flag, which must wait?
7. **Q7 — Citations.** Single bibliography of every primary source.

## Analysis

### Q1. Category-theoretic and type-theoretic foundations

#### Q1.a The categorical product (universal property)

The categorical product is defined by a **universal property**, not by any
particular construction. From nLab's `cartesian product` page (Verified:
2026-05-08):

> "given any other object Q ∈ 𝒞 with morphisms Q → X_i for i ∈ I, then
> there is a unique morphism (f_i)_{i∈I}: Q → ∏X_i which factors the f_i
> through the p_i, i.e. such that all these diagrams commute."
> — `https://ncatlab.org/nlab/show/product` (Verified: 2026-05-08)

Wikipedia's `Product (category theory)` page restates the binary case
(Verified: 2026-05-08):

> "For every object Y and every pair of morphisms f₁: Y → X₁, f₂: Y → X₂,
> there exists a unique morphism f: Y → X₁ × X₂ such that the following
> diagram commutes."
> — `https://en.wikipedia.org/wiki/Product_(category_theory)`

The two morphisms π₁, π₂ are called **canonical projections**. The "unique
mediating morphism" is what `Product.init(_:)` and tuple-construction *are* —
a concrete witness of the universal property.

`Product<each E>` realises the universal property: `init(repeat each Element)`
constructs the unique mediating morphism `f: Y → ∏X_i` from a family of
component morphisms `Y → X_i`, and `values.0`, `values.1`, … are the canonical
projections π_i.

#### Q1.b N-ary products and the iteration question

A central question for a parameter-pack-backed type: do n-ary products reduce
to iterated binary products? The categorical answer (Wikipedia, Verified:
2026-05-08):

> "For objects indexed by a set I, a product of the family is an object X
> equipped with morphisms πᵢ: X → Xᵢ, satisfying the following universal
> property: For every object Y and every I-indexed family of morphisms
> fᵢ: Y → Xᵢ, there exists a unique morphism f: Y → X."
> — `https://en.wikipedia.org/wiki/Product_(category_theory)`

The n-ary product is a *first-class* construction. Iterated binary products
`A × (B × C)` and `(A × B) × C` are isomorphic to the ternary product
`A × B × C` (associator), but **the n-ary form is the more natural one**
when the arity itself varies. This justifies why
`Product<each E>` cannot be defined as `Pair<A, Pair<B, Pair<C, …>>>` even
though the encoding is mathematically equivalent: the iterated form forces
nested projections (`p.values.1.values.1.values.0` instead of
`p.values.2`), and Idris's documented choice to encode tuples this way (see
Q2.f) is the cautionary tale.

#### Q1.c Product as functor; bifunctor signature

If the category C admits I-indexed products, the assignment `(c_i)_{i∈I} ↦
∏c_i` extends to a **functor** `C^I → C` (Wikipedia, Verified: 2026-05-08):

> "If I is a set such that all products for families indexed with I exist,
> then one can treat each product as a functor C^I → C."
> — `https://en.wikipedia.org/wiki/Product_(category_theory)`

For the binary case, this is the **bifunctor**, and the canonical operation
is `bimap` (Hackage `Data.Bifunctor`, Verified: 2026-05-08):

```haskell
bimap :: (a -> b) -> (c -> d) -> p a c -> p b d
first :: (a -> b) -> p a c -> p b c
second :: (b -> c) -> p a b -> p a c
```
— `https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bifunctor.html`
(Verified: 2026-05-08)

For the n-ary parameter-pack form, the bifunctor signature generalises to
something Swift cannot yet spell — an "n-ary functor" `(repeat each From) →
(repeat each To)` parameterised by a *pack of functions*. The peer
`api-design-leveraging-property-primitives.md` doc owns the API-shape question
("what does `product.map.all` mean?"); this doc only flags the *theoretical*
existence of the n-ary functor and notes the Swift-side blocker: pack-of-pack
expansion is not currently spellable except as `(repeat each each P)`, which
is rejected per the SE-0398 constraint that a generic type may declare at
most one type parameter pack (Verified: 2026-05-08, see Q4).

#### Q1.d Distinction from coproduct (Either / sum)

The product holds *all* components; the coproduct (`swift-either-primitives`'
`Either`) holds *exactly one*. Wikipedia (Verified: 2026-05-08):

> "It is the category-theoretic dual notion to the categorical product, which
> means the definition is the same as the product but with all arrows reversed."
> — `https://en.wikipedia.org/wiki/Coproduct`

> "Sum types are the dual of product types."
> — `https://en.wikipedia.org/wiki/Tagged_union` (Verified: 2026-05-08)

This duality matters concretely: `Product<A, B>: Equatable where A: Equatable,
B: Equatable` requires `lhs.0 == rhs.0 && lhs.1 == rhs.1`. The `Either<L, R>:
Equatable` formula instead pattern-matches:
`(.left(a), .left(b)) → a == b`, `(.right(a), .right(b)) → a == b`, otherwise
`false`. The conjunction-vs-disjunction asymmetry corresponds exactly to
multiplicative-vs-additive distinction in linear logic (Q1.e).

#### Q1.e Linear / affine type theory and `~Copyable`

Linear logic (Girard 1987; surveyed by Wikipedia `Linear_logic`, Verified:
2026-05-08) offers **two** product-like connectives:

> "the connectives ⊗, ⅋, 1, and ⊥ are called *multiplicatives*, the
> connectives &, ⊕, ⊤, and 0 are called *additives*"
> — `https://en.wikipedia.org/wiki/Linear_logic`

> "for the multiplicative connective (⊗), the context of the conclusion
> (Γ, Δ) is split up between the premises, whereas for the additive case
> connective (&) the context of the conclusion (Γ) is carried whole into
> both premises."
> — same source

The **multiplicative** product `A ⊗ B` requires *both* resources to be
consumed (the linear pair). The **additive** product `A & B` lets the
consumer choose *which* projection to take. Swift's `~Copyable` parameter
packs (still gated, see Q5) face exactly this design question: when
`Product<each E>` becomes `~Copyable`, is its `values.0` accessor a *consume*
(multiplicative) or a *borrow with choice* (additive)?

The "Linear Haskell" paper (Bernardy, Boespflug, Newton, Peyton Jones, Spiwack
2017, arXiv:1710.09756, Verified-via-secondary-source: arXiv listing —
Verified: 2026-05-08, full PDF body unreachable as binary):

> "The paper proposes a linear type system designed for backward
> compatibility and code reuse in functional languages like Haskell. Rather
> than creating separate linear and non-linear type versions, linearity is
> attached to function arrows, allowing linear functions to operate over both
> linearly-bound and unrestricted values."
> — paraphrase from arXiv abstract; `https://arxiv.org/abs/1710.09756`

The takeaway for `Product`: when the noncopyable-pack feature lands, the
*natural* binary projection `values.0` corresponds to the additive product
(borrow one, leave the other intact); the **consuming** projection
`consume product` and pattern `let (a, b) = consume product` corresponds to
the multiplicative product (split the resource). Swift will likely
distinguish these via ownership annotations on accessors rather than two
separate type constructors — but the *theoretical* distinction is real and
will surface in API design once `~Copyable` packs ship.

#### Q1.f Σ-types vs Π-types — Swift's positioning

`Product<each E>` is a **non-dependent** product. Each component type is
fixed at the declaration site (`Product(1, "x", true)` has type
`Product<Int, String, Bool>`); none of the later types depends on the value
of an earlier one. This is the special case of a Σ-type where the dependency
is trivial (nLab `dependent sum type`, Verified: 2026-05-08):

> "the dependent sum reduces to a standard product type in the special case
> where the dependent type becomes independent: when C_d = C (independent
> of d), the dependent sum simplifies to the product type D × C."
> — `https://ncatlab.org/nlab/show/dependent+sum+type`

Π-types (dependent products / dependent function types) generalise the
non-dependent function type (nLab `dependent product type`, Verified:
2026-05-08):

> "this type 'includes function types as the special case when B is not
> dependent on A, product types as a special case when A is the type of
> Booleans, and dependent sequence types as a special case when A is the
> natural numbers type.'"
> — `https://ncatlab.org/nlab/show/dependent+product+type`

Swift has no dependent types; `Product<each E>` is therefore *just* the
non-dependent product. The peer doc need not address dependent products at
all — they are an Idris/Agda concern (Q2.f).

### Q2. Programming-language precedent

The languages below are surveyed for: name, max-arity wall, projection
surface, functor/bimap surface, n-ary uniformity, design regrets.

#### Q2.a Haskell

Haskell ships built-in tuples `(a, b)`, `(a, b, c)`, …, currently up to
arity 62 (GHC limit, secondary-source). The `Data.Tuple` module exports
(Hackage, Verified: 2026-05-08):

```haskell
fst :: (a, b) -> a
snd :: (a, b) -> b
swap :: (a, b) -> (b, a)
curry :: ((a, b) -> c) -> a -> b -> c
uncurry :: (a -> b -> c) -> (a, b) -> c
```
— `https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Tuple.html`

The 1-tuple is `Solo` (formerly `OneTuple`): "the canonical lifted 1-tuple,
just like `(,)` is the canonical lifted 2-tuple (pair)." The fact that
Haskell needed a *named datatype* for the 1-tuple — because `(x)` is just `x`
— is the cleanest evidence that Swift's choice to wrap the n-ary tuple in a
named `Product<each E>` is *not* redundant: it gives the type system a
distinguishable identity even at arity 1, and avoids the Solo/(,)/(,,)/(,,,)
ad-hoc tower.

The bifunctor surface (`Data.Bifunctor`) is `bimap`, `first`, `second` (Q1.c).
N-ary equivalents do **not** exist in `base`; libraries like `vinyl` and
`generics-sop` provide HList-style heterogeneous-list machinery instead.

**Design regret**: Haskell's `Data.Tuple` *does not generalise*. There is no
`Data.Tuple.Solo`-flavoured `Tuple n` that scales. The `tuples` library
exists on Hackage but is rarely used. The lesson: a single concrete `Product`
type is more useful than 60 hand-written tuple instances.

#### Q2.b OCaml

OCaml tuples `(a, b)` have type `int * string`, and the Stdlib exports `fst`,
`snd` (Verified: 2026-05-08):

```ocaml
val fst : 'a * 'b -> 'a
val snd : 'a * 'b -> 'b
```
— `https://ocaml.org/api/Stdlib.html`

OCaml 5.4 added a `Pair` module (Verified: 2026-05-08):

```ocaml
val swap : 'a * 'b -> 'b * 'a
val make : 'a -> 'b -> 'a * 'b
val map : ('a -> 'c) -> ('b -> 'd) -> 'a * 'b -> 'c * 'd
```
— `https://ocaml.org/api/Pair.html`

The `Pair.map` shape is precisely OCaml's word for `bimap`; this is the
exact name `swift-either-primitives`' peer doc rejects for `Either.bimap`,
but for `Product` the picture is different — Pair-style "transform both
components" reads naturally as `product.map.all { …, …, … }` in the Swift
nested-namespace idiom. (Resolution lives in the peer doc.)

**Design regret**: OCaml's tuples are nominal-only. There is no n-ary
abstraction; n-ary tuples are nested binary pairs at the type-checker level
(`int * string * float` is `int * (string * float)` in many older OCaml
manuals; modern manuals treat triples as a primitive). Pattern matching
papers over the lack.

#### Q2.c Rust

Rust tuples `(A, B, …)` cap at arity 12 for trait impls (Verified:
2026-05-08):

> "Due to a temporary restriction in Rust's type system, the following
> traits are only implemented on tuples of arity 12 or less. In the future,
> this may change"
> — `https://doc.rust-lang.org/std/primitive.tuple.html`

Affected traits: `PartialEq`, `Eq`, `PartialOrd`, `Ord`, `Debug`, `Default`,
`Hash`. Auto-generated traits (`Clone`, `Copy`, `Send`, `Sync`, `Unpin`,
`UnwindSafe`, `RefUnwindSafe`) work at any length — same source.

The third-party `frunk` library exposes `HCons<H, T>` / `HNil` heterogeneous
lists with `head`, `tail`, `pluck`, `sculpt`, `foldr`, `foldl`, `map`
operations (Verified: 2026-05-08, `https://docs.rs/frunk`).

**Design regret**: Rust's tuple ABI is implicit — there is no `Tuple<each E>`
analogue, and the only path to n-ary uniformity is a third-party HList. Rust
RFCs for variadic generics have been open for years without convergence; this
is exactly the gap Swift's parameter packs (SE-0393) closed. Swift's
`Product<each E>` is therefore **the type Rust wishes it had**.

#### Q2.d Scala

Scala 2 famously had `Tuple1` … `Tuple22` — the "22-arity wall" born of the
JVM's lack of variadic class types. Scala 3 dissolved the wall via the
type-level `*:` cons operator (Scala 3 source, Verified: 2026-05-08):

```scala
sealed trait Tuple extends Product
@showAsInfix
sealed abstract class *:[+H, +T <: Tuple] extends NonEmptyTuple

type Map[Tup <: Tuple, F[_ <: Union[Tup]]] <: Tuple = Tup match
  case EmptyTuple => EmptyTuple
  case h *: t => F[h] *: Map[t, F]

type Concat[X <: Tuple, +Y <: Tuple] <: Tuple = X match
  case EmptyTuple => Y
  case x1 *: xs1 => x1 *: Concat[xs1, Y]

type Zip[T1 <: Tuple, T2 <: Tuple] <: Tuple = (T1, T2) match
  case (h1 *: t1, h2 *: t2) => (h1, h2) *: Zip[t1, t2]
  case _ => EmptyTuple
```
— `https://github.com/scala/scala3/blob/main/library/src/scala/Tuple.scala`

This is the most ambitious type-level surface for a tuple type in any major
language: `Map`, `Concat`, `Zip` are *type-level* match-types operating
recursively on `*:`. Swift's parameter packs are a strictly less expressive
mechanism — there is no type-level pattern-match in Swift — but the surface
*hint* is there: any `Product` library that wants a "type-level zip" must
encode it as a generic function returning a tuple of the zipped pairs, not
as a type-level computation.

**Design regret**: Scala 2's `Tuple22` wall was a genuinely traumatic
ecosystem event. Library authors built around it; deprecation took years.
Lesson: any per-arity type tower (`Pair`, `Triple`, `Quadruple`) is a
ticking deprecation bomb the moment variadic abstraction lands. Swift's
choice to start with `Product<each E>` from day one avoids the entire
trajectory.

#### Q2.e F#

F# tuples are reference-tuples by default and struct-tuples on opt-in (MS
Learn docs, Verified: 2026-05-08):

```fsharp
(1, 2)                    // Reference tuple, compiles to System.Tuple<int,int>
struct (1.025f, 1.5f)     // Struct tuple, compiles to System.ValueTuple<float32,float32>
let c = fst (1, 2)
let d = snd (1, 2)
```
— `https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/tuples`

> "Tuples are compiled into objects of one of several generic types, all
> named `System.Tuple`, that are overloaded on the arity, or number of type
> parameters."
> — same source (Verified: 2026-05-08)

F# inherits .NET's `System.Tuple<…>` and `System.ValueTuple<…>` — both
arity-7 with a recursive 8th slot. F# has no built-in n-ary projection
beyond `fst`/`snd`; the documentation explicitly says "There is no built-in
function that returns the third element of a triple, but you can easily
write one as follows: `let third (_, _, c) = c`". This is a clear signal that
**arity-N projection by index is a load-bearing accessor primitive** — F#'s
omission is universally cited as friction.

#### Q2.f Idris / Agda

Idris encodes tuples as nested pairs (Verified: 2026-05-08):

```idris
data Pair a b = MkPair a b
-- (x : a ** p) is the type of a pair of A and P, where the name `x`
-- can occur inside `p`. -- dependent pair / Σ-type
```
— `https://idris2.readthedocs.io/en/latest/tutorial/typesfuns.html`

> "Tuples can contain an arbitrary number of values, represented as nested
> pairs."
> — same source (Verified: 2026-05-08)

This is the **iterated binary** encoding Q1.b warns against. Idris carries it
because dependent products `(x : A ** B(x))` make the nesting linguistically
useful (each pair element can constrain the next), but the projection cost
is high: `(a, (b, (c, d))).snd.snd.fst` reads worse than `tuple.2`. Swift's
parameter-pack form sidesteps this entirely.

#### Q2.g TypeScript

TypeScript ships labeled, fixed-length, variadic tuples (Verified:
2026-05-08):

```typescript
type StringNumberPair = [string, number];
type StringNumberBooleans = [string, number, ...boolean[]];
type StringBooleansNumber = [string, ...boolean[], number];
```
— `https://www.typescriptlang.org/docs/handbook/2/objects.html`

> "A *tuple type* is another sort of `Array` type that knows exactly how
> many elements it contains, and exactly which types it contains at specific
> positions."
> — same source

> "Other than those length checks, simple tuple types like these are
> equivalent to types which are versions of `Array`s that declare properties
> for specific indexes, and that declare `length` with a numeric literal
> type."
> — same source

TypeScript's tuples *are* arrays at runtime — a structural-typing artefact
of TS sitting on top of JS. Swift's `Product` is genuinely heterogeneous and
ABI-distinct from `Array<Any>`; the tuple/array equivalence does not apply.

#### Q2.h Comparison table

| Language | Type name | Max arity | Bimap surface | N-ary primitive? | 1-tuple |
|---|---|---|---|---|---|
| Haskell | `(a, b)` … `(a..a62)` | 62 (GHC) | `bimap`, `first`, `second` | No | `Solo` |
| OCaml 5.4 | `'a * 'b`, `Pair.t` | unlimited (nested) | `Pair.map` | No | implicit |
| Rust | `(A, B, …)` | 12 (trait wall) | none in stdlib; `frunk::HList` | No | `(A,)` |
| Scala 3 | `Tuple`, `*:` | unlimited via `*:` | match-type `Map` | **Yes** | `Tuple1[A]` |
| F# | `int * string`, `struct (..)` | 7 + recursive | none in stdlib | No | n/a |
| Idris2 | nested `Pair a b` | unlimited (nested) | `Bifunctor` instance | No | n/a |
| TypeScript | `[A, B, ...]` | unlimited | none in stdlib | **Yes** (variadic) | `[A]` |
| **Swift** | `(A, B, …)`, `Product<each E>` | **6** (stdlib `==`) / unlimited (pack) | none in stdlib | **Yes** (pack-backed) | `Product<A>` |

Swift sits with Scala 3 and TypeScript as the third major language with
*genuine* n-ary primitives. Unlike Scala, it lacks type-level matching;
unlike TypeScript, it has real heterogeneous typing. The shape of
`Product<each E>` is closer to Scala's `Tuple` than to anything else.

### Q3. Swift stdlib precedent

#### Q3.a Tuple comparison: the arity-6 wall

The single most concrete primary source is
`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb`,
which generates `==`, `!=`, `<`, `<=`, `>`, `>=` for tuples up to arity 6
(Verified: 2026-05-08, lines 108–197):

```python
% for arity in range(2,7):
%   typeParams = [chr(ord("A") + i) for i in range(arity)]
%   tupleT = "({})".format(",".join(typeParams))
```
— `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb`

This is the **stdlib arity wall**. Tuples of arity 7 or more have no built-in
`==`. SE-0015 (`Swift 2.2`, Verified: 2026-05-08) is the originating
proposal:

> "The actual definitions will be generated by gyb."
> — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0015-tuple-comparison-operators.md`

Implication: a `Product<each E>` whose `Equatable` conformance uses pack
iteration (`for r in repeat …` per SE-0408) **can equate at any arity**,
removing the wall. This is observable improvement, not theoretical.

#### Q3.b Stdlib parameter-pack adoption is sparse

Grep across `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/` for
`<each ` or `repeat each` (Verified: 2026-05-08): the *only* hit is
`/Users/coen/Developer/swiftlang/swift/stdlib/public/Concurrency/Actor.swift`
line 108–109:

```swift
public func extractIsolation<each Arg, Result>(
  _ fn: @escaping @isolated(any) (repeat each Arg) async throws -> Result
```
— `/Users/coen/Developer/swiftlang/swift/stdlib/public/Concurrency/Actor.swift`

The stdlib uses parameter packs **once**, for actor-isolation extraction.
Tuple comparison, despite the obvious fit, is *still* gyb'd. PR #85373 ("De-gyb
Tuple.swift.gyb and replace it with variadic generics", harlanhaskins,
November 6–8 2025) attempted the conversion but was **closed without merge**
due to a tuple-shuffle compilation error (Verified: 2026-05-08,
`https://github.com/swiftlang/swift/pull/85373`):

> "This replaces the 2-7ary variadic gyb'd tuple comparison implementations
> with unified variadic implementations that short-circuit when the first
> element fails the test."
> — PR description, paraphrased

This means: even Apple's compiler engineers tried to do exactly what
`Product` does today (`Equatable` via pack iteration), and **the compiler is
not yet stable enough to support it in the stdlib**. The
`/Users/coen/Developer/swiftlang/swift/test/stdlib/MirrorWithPacks.swift` file
(line 28, Verified: 2026-05-08) defines a near-identical type for testing:

```swift
struct Tuple<each T> {
  var elements: (repeat each T)
  init(_ elements: repeat each T) {
    self.elements = (repeat each elements)
  }
}
```
— `/Users/coen/Developer/swiftlang/swift/test/stdlib/MirrorWithPacks.swift`

`Product<each E>` is *literally* the same struct as the stdlib team's test
fixture. This is converging-precedent confirmation: when the stdlib lifts
this to a public type, the shape will match.

#### Q3.c Tuple conformance synthesis is in-tree but gated

The compiler ships an experimental flag `TupleConformances` (default off):

```cpp
EXPERIMENTAL_FEATURE(TupleConformances, false)
```
— `/Users/coen/Developer/swiftlang/swift/include/swift/Basic/Features.def:346`
(Verified: 2026-05-08)

Test fixture
`/Users/coen/Developer/swiftlang/swift/test/Generics/tuple-conformances.swift`
demonstrates the eventual syntax (Verified: 2026-05-08):

```swift
typealias Tuple<each Element> = (repeat each Element)
extension Tuple: Q where repeat each Element: Q { … }
```

The constraints (lines 5–60):
- `extension () { … }` is rejected — must use `(repeat each Element)`.
- A tuple extension MUST declare conformance to exactly one protocol.
- The conditional requirements MUST be exactly `repeat each Element: P`.

The associated bug `swiftlang/swift#82172` (xwu, June 2025) is open, gating
real-world adoption (Verified: 2026-05-08):

> "If (2) were instead written so as not to wrap the parameter pack in a
> tuple, it would be disfavored by today's compiler. But when wrapped in a
> tuple as here, the compiler complains of ambiguity."
> — `https://github.com/swiftlang/swift/issues/82172`

When this lands, native tuple conformances will subsume `Product`'s
`Equatable`/`Hashable` *for the bare tuple shape*. `Product` will retain
value as the **named** form (with `@dynamicMemberLookup`, with `Swift.Error`
conformance, and as a wrapper for typed-throws aggregation).

#### Q3.d "Vanishing tuple conformance"

The compiler implements a special case at
`/Users/coen/Developer/swiftlang/swift/lib/AST/ProtocolConformance.cpp:1052–
1085` (Verified: 2026-05-08):

```cpp
/// Don't form a tuple conformance if the substituted type is unwrapped
/// from a one-element tuple.
///
/// That is, [(repeat each T): P] ⊗ {each T := Pack{U};
///                                  [each T: P]: Pack{ [U: P] }}
///                 => [U: P]
static ProtocolConformanceRef unwrapVanishingTupleConformance(
    SubstitutionMap substitutions) {
```

This is critical compiler intelligence: when `each T` is substituted to a
**single concrete type**, the tuple-conformance machinery *unwraps* — a
1-element pack does not become a wrapped tuple, it becomes the bare element.
For `Product<each E>` this means: `Product<Int>` is **not** isomorphic to
`Int` at the type-checker level (it is a nominal struct), but its conformance
witnesses for `Equatable`/`Hashable` resolve through this same vanishing
path. The peer doc must take care that any future "n-ary functor" surface
behaves correctly at arity 1.

### Q4. Swift Evolution proposals

Each row is verified by reading the proposal body via WebFetch on 2026-05-08.

| SE# | Title | Status | Shipped | Relevance |
|---|---|---|---|---|
| SE-0015 | Tuple comparison operators | Implemented | Swift 2.2 | Established 2-arity-6 wall via gyb |
| SE-0283 | Tuples Conform to Equatable, Comparable, Hashable | **Returned for revision** | **NOT SHIPPED** | The accepted-but-unshipped proposal |
| SE-0390 | Noncopyable structs and enums | Implemented | Swift 5.9 | `~Copyable` syntax; tuples-of-noncopyable listed as future direction |
| SE-0393 | Value and Type Parameter Packs | Implemented | Swift 5.9 | The `each T` syntax `Product` is built on |
| SE-0396 | Conform `Never` to Codable | Implemented | Swift 5.9 | Unblocks `Either<Int, Never>: Codable`; relevant to Product-of-Never |
| SE-0398 | Allow Generic Types to Abstract Over Packs | Implemented | Swift 5.9 | `struct Product<each E>` is what this enables |
| SE-0399 | Tuple of value pack expansion | Implemented | Swift 5.9 | `(repeat each x)` tuple form; underpins `Product.values` |
| SE-0408 | Pack Iteration | Implemented | Swift 6.0 | `for r in repeat …` — `Product`'s `==` and `hash` |
| SE-0413 | Typed throws | Implemented | Swift 6.0 | `throws(Product<E1, E2, …>)` aggregation use case |
| SE-0426 | BitwiseCopyable | Implemented | Swift 6.0 | Tuples-of-BitwiseCopyable get the conformance — Product likely should too |
| SE-0427 | Noncopyable Generics | Implemented | Swift 6.0 | `~Copyable` generics; pack support **deferred** |
| SE-0432 | Borrowing/consuming pattern matching for noncopyable types | Implemented | Swift 6.0 | Relevant when `Product` becomes `~Copyable` |
| SE-0437 | Noncopyable Standard Library Primitives | Implemented | Swift 6.0 | `Optional`, `Result` go `~Copyable`; tuples NOT addressed |
| SE-0446 | Nonescapable Types | Implemented | Swift 6.2 | `~Escapable` syntax; pack interaction undocumented |
| SE-0453 | InlineArray, a fixed-size array | Implemented | Swift 6.2 | Same-arity precedent; explicitly distinguished from tuples |
| SE-0465 | Standard Library Primitives for Nonescapable Types | Implemented | Swift 6.2 | `Optional`/`Result` go `~Escapable`; Product can mirror |
| SE-0489 | Improve EncodingError/DecodingError descriptions | Implemented | Swift 6.3 | Out of scope; included for completeness |
| SE-0499 | Support `~Copyable`, `~Escapable` in simple stdlib protocols | **Implemented Swift 6.4** | **Swift 6.4** | `Equatable`/`Comparable`/`Hashable` themselves now refine `~Copyable`/`~Escapable`; **direct enabler** for noncopyable Product |
| SE-0515 | Allow `reduce` to produce noncopyable results | Accepted | (Swift 6.4 cohort) | Out of scope for Product |
| SE-0528 | Continuation — Safe and Performant Async Continuations | Accepted with revisions | unspecified | Demonstrates ownership-aware API patterns; reference for `Product` consume APIs |

Two non-obvious items deserve quoting:

**SE-0283 (Returned)** — the most-cited tuple proposal:

> "Tuples in Swift currently lack the ability to conform to protocols. This
> has led many users to stop using tuples altogether in favor of structures
> that can conform to protocols."
> — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0283-tuples-are-equatable-comparable-hashable.md`
> (Verified: 2026-05-08)

The implementation was **reverted** (apple/swift#34492). The proposal's
status is "returned for revision" — it has *not* shipped in Swift 6.4. This
means the entire reason `Product<each E>` exists as a wrapper is a concrete
language gap, not a stylistic preference.

**SE-0499 (Swift 6.4)** — the most consequential 2025–2026 proposal for
`Product`:

> "Equatable, Comparable, and Hashable" — and "CustomStringConvertible and
> CustomDebugStringConvertible" — and "TextOutputStream and
> TextOutputStreamable" — gain `~Copyable` (and most also gain `~Escapable`)
> support.
> — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md`
> (Verified: 2026-05-08)

This proposal is implemented in Swift 6.4 (per the Holly Borla review thread,
November 19 2025, Verified: 2026-05-08). Once `Product<each E>` becomes
`~Copyable` (after pack-noncopyable lands), its conditional `Equatable` and
`Hashable` conformances *don't break* — the protocols themselves are now
`~Copyable`-aware. This is the removal of a pre-emptive blocker.

### Q5. Upstream compiler work (Swift 6.4-dev)

#### Q5.a TupleConformances feature, in-tree but gated

Discussed in Q3.c. Status: experimental flag, default off, default-failing
test cases at
`/Users/coen/Developer/swiftlang/swift/test/Generics/tuple-conformances.swift`
and `/Users/coen/Developer/swiftlang/swift/test/SILOptimizer/tuple-conformances.swift`.

The November 9 2025 Forum pitch by Joshua Cleetus
("[Pitch] Automatic `Hashable` Conformance for Tuples (Revival of SE-0283)",
Verified: 2026-05-08):

> "A tuple automatically conforms to Hashable if and only if every element
> conforms to Hashable."
> — `https://forums.swift.org/t/pitch-automatic-hashable-conformance-for-tuples-revival-of-se-0283/83105`

> "Once this works, SILGen should be able to emit witness thunks for tuple
> conformances." — Slava Pestov
> — same thread

> "Recent work includes PR #85373, which replaces the old hard-coded tuple
> operator overloads with concrete parameter pack implementations." —
> compiled from PR description (Verified: 2026-05-08)

PR #85373 is closed-without-merge as of the search date; the underlying
SILGen bug remains the gating issue.

#### Q5.b Active commits relevant to packs (`git log --since='2025-09-01'
`)

Verified in `/Users/coen/Developer/swiftlang/swift` on 2026-05-08:

- `[SIL] Relax pack_pack_index assertion to allow empty trailing slice`
  (#87844)
- `Avoid automatically making pack argument into tuple` (#87361)
- `Allow alloc_pack_metadata to be marked as [non_nested]`
- `Allow pack expansion to bind to no escape`
- `Discover pack param from inside deferred escaping capture`
- `Support finding use of non escaping pack within defer`
- `[VariadicGenerics] Fix memeffect of metadata accessor.`
- `Fix a bug with vanishing tuples in parameter binding.`

The cluster shows **active stabilization work** on parameter packs with
respect to: noescape closures, defer-bodies, region isolation, and SIL
optimizer assertions. Translation: the compiler is shoring up the pack
infrastructure for *later* work (TupleConformances, noncopyable packs). For
`Product` today this means: do not lean on subtle pack-of-pack or
pack-with-noescape patterns; prefer simple positive cases.

#### Q5.c ~Copyable parameter packs

Status: **deferred**, no proposal in flight. From SE-0427 (Verified:
2026-05-08):

> "Tuples and parameter packs are a straightforward generalization which
> will be discussed in a separate proposal."
> — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md`

From SE-0390 (Verified: 2026-05-08):

> "It should be possible for a tuple to contain noncopyable elements,
> rendering the tuple noncopyable if any of its elements are."
> — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md`

Listed as a future direction. The `MoveOnlyTuples` experimental feature
(`Features.def:367`, default true, Verified: 2026-05-08) suggests the
compiler-side support is partially in tree, but no shipped proposal allows a
public `Product<each E: ~Copyable>` declaration. **Today's `Product` cannot
be noncopyable**; consumers must wait.

#### Q5.d Codable for parameter packs

Codable conformance for parameter-pack types is **not in flight** — no SE
proposal exists. The Product source comment ("may not be directly
expressible in current Swift") reflects this. The technical blocker is that
`Encoder.encode(_:)` requires a single `Encodable` argument; encoding `repeat
each E` requires a non-trivial generic function loop, and `Decoder` needs to
know the arity ahead of time, which is statically determined at the call
site but not exposed via a runtime API.

A workaround using pack iteration is plausible:

```swift
// Sketch — not currently exercised
extension Product: Encodable where repeat each Element: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for e in repeat each values {
            try container.encode(e)
        }
    }
}
```

But the symmetric `Decodable` shape requires a `repeat each Element.init(from:
…)` that the compiler **does not yet accept** (per `swiftlang/swift#82172`,
Verified: 2026-05-08, and the broader pack-init-with-throws gating). For
today: **Codable remains documented absent**, with a re-evaluation entry
point when the SILGen pack-init bugs close.

#### Q5.e Pack-element key paths

`@dynamicMemberLookup` already gives `product.0` access via a tuple key path
(`KeyPath<(repeat each Element), T>`). What is **not** available: a key path
that abstracts over the *index* (`KeyPath<Product, eachElement>` is not
spellable). SE-0479 (Method and Initializer Key Paths, May 2025, Verified
via WebSearch — Verified-via-secondary-source: 2026-05-08) does not address
parameter packs.

Implication: `Product`'s only general projection vehicle is `dynamicMember`
keyed on the underlying tuple type. The peer doc owns whether this should
remain or move toward labeled-method projection.

### Q6. Today / nightly / pending / blocked

This is the prefigure-or-wait classification.

| Capability | Today (6.3 stable) | Behind flag | Pending SE | Blocked |
|---|---|---|---|---|
| `Product<each E>` declaration | YES (SE-0398) | — | — | — |
| `Product.init(repeat each E)` | YES (SE-0399) | — | — | — |
| `@dynamicMemberLookup` on tuple keypath | YES | — | — | — |
| Conditional `Sendable` `Equatable` `Hashable` | YES (SE-0408 pack iter) | — | — | — |
| Conditional `Swift.Error` | YES | — | — | — |
| Conditional `BitwiseCopyable` | YES (SE-0426 — auto for tuples) | needs verification for `Product` *struct* | — | — |
| Conditional `CustomStringConvertible` | YES (SE-0408 + native) | — | — | — |
| Conditional `Comparable` (lexicographic) | YES (SE-0408) | — | — | — |
| Conditional `Codable` | NO | — | NO | YES — Encodable/Decodable for packs unstable; document as principled absence |
| `Product<each E: ~Copyable>` | NO | — | NO | YES — pack-noncopyable not shipped; deferred per SE-0427 |
| `Product<each E: ~Escapable>` | NO | — | NO | YES — same as above |
| Pack-of-pack n-ary functor (`bimap`) | NO | — | NO | YES — single pack per type per SE-0398 |
| Native `Tuple: Equatable` (subsumes Product?) | NO | `TupleConformances` (compiler default off) | YES — SE-0283 revival pitched Nov 2025 | Partial — gated on SILGen bugs |
| `Equatable`/`Hashable` themselves `~Copyable`-aware | YES (Swift 6.4 via SE-0499) | — | — | — |

**Adoption recommendations** (defer concrete API moves to peer doc):

1. **Today**: ship `BitwiseCopyable` as conditional conformance (it is
   automatic for tuple-shaped fields per SE-0426). Verify with a short
   experiment.
2. **Today**: ship conditional `Comparable` using SE-0408 short-circuiting
   pack iteration — replicates the stdlib `Tuple.swift.gyb` logic with no
   arity wall.
3. **Today**: ship conditional `CustomStringConvertible` — the
   `description` mirrors a tuple-printing format. SE-0499 makes this
   `~Copyable`-friendly even before `Product` itself becomes `~Copyable`.
4. **Today**: keep `Codable` documented absent. Add a
   `Documentation.docc/Principled-Absences/Codable.md` mirroring the
   tagged-primitives convention.
5. **Today**: do **not** add `bimap` / `mapAll` / per-position transform
   surface. The single-pack-per-type SE-0398 limit makes a true n-ary functor
   unspellable; partial workarounds invite drift. Document this as a
   principled absence with a re-visit pointer.
6. **Nightly**: gate any noncopyable / nonescapable conformance behind
   `#if hasFeature(NoncopyablePacks)` or equivalent — *do not* ship the
   experimental flag publicly.
7. **Pending**: when `TupleConformances` flips to default-on (no SE date
   yet; depends on `swiftlang/swift#82172` closing), `Product`'s value
   collapses to: a *named, dynamic-member-lookup-enabled, error-aggregating*
   wrapper. The "n-ary equatable" raison-d'être evaporates. The
   reflection-into-Documentation entry should explain this contingency.

### Q7. Bibliography

Below is the union of every primary citation used above. Categorized.

#### Categorical / type-theoretic foundations

- nLab, "product"
  `https://ncatlab.org/nlab/show/product` (Verified: 2026-05-08)
- nLab, "cartesian product"
  `https://ncatlab.org/nlab/show/cartesian+product` (Verified: 2026-05-08)
- nLab, "dependent product type"
  `https://ncatlab.org/nlab/show/dependent+product+type` (Verified: 2026-05-08)
- nLab, "dependent sum type"
  `https://ncatlab.org/nlab/show/dependent+sum+type` (Verified: 2026-05-08)
- Wikipedia, "Product (category theory)"
  `https://en.wikipedia.org/wiki/Product_(category_theory)` (Verified: 2026-05-08)
- Wikipedia, "Coproduct"
  `https://en.wikipedia.org/wiki/Coproduct` (Verified: 2026-05-08)
- Wikipedia, "Product type"
  `https://en.wikipedia.org/wiki/Product_type` (Verified: 2026-05-08)
- Wikipedia, "Tagged union"
  `https://en.wikipedia.org/wiki/Tagged_union` (Verified: 2026-05-08)
- Wikipedia, "Linear logic"
  `https://en.wikipedia.org/wiki/Linear_logic` (Verified: 2026-05-08)
- Wikipedia, "Bifunctor"
  `https://en.wikipedia.org/wiki/Bifunctor` (Verified: 2026-05-08)
- Bernardy, J.-P., Boespflug, M., Newton, R. R., Peyton Jones, S., Spiwack,
  A. (2017). "Linear Haskell: practical linearity in a higher-order
  polymorphic language", arXiv:1710.09756 / DOI: 10.1145/3158093.
  `https://arxiv.org/abs/1710.09756`
  (Verified-via-secondary-source: arXiv abstract page; full PDF body
  unreachable as binary — Verified: 2026-05-08)
- Awodey, S. *Category Theory* (Oxford Logic Guides, 2nd ed., 2010).
  `https://global.oup.com/academic/product/category-theory-9780199237180`
  (Verified-via-secondary-source: publisher page lists chapter 2 "Abstract
  Structures" §§2.4–2.7 covering products — Verified: 2026-05-08; full text
  not directly retrievable)
- Jacobs, B. *Categorical Logic and Type Theory* (Studies in Logic vol. 141,
  Elsevier 1999).
  `https://www.cs.ru.nl/B.Jacobs/CLT/bookinfo.html`
  (Verified-via-secondary-source — Verified: 2026-05-08)

#### Programming-language documentation

- Hackage, `Data.Tuple` (base 4.22)
  `https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Tuple.html`
  (Verified: 2026-05-08)
- Hackage, `Data.Bifunctor`
  `https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bifunctor.html`
  (Verified: 2026-05-08)
- OCaml, `Stdlib`
  `https://ocaml.org/api/Stdlib.html` (Verified: 2026-05-08)
- OCaml, `Pair` module (5.4)
  `https://ocaml.org/api/Pair.html` (Verified: 2026-05-08)
- Rust standard library, primitive `tuple`
  `https://doc.rust-lang.org/std/primitive.tuple.html` (Verified: 2026-05-08)
- frunk crate, `hlist`
  `https://docs.rs/frunk/latest/frunk/hlist/index.html` (Verified: 2026-05-08)
- Scala 3 source, `library/src/scala/Tuple.scala`
  `https://github.com/scala/scala3/blob/main/library/src/scala/Tuple.scala`
  (Verified: 2026-05-08)
- Microsoft Learn, "Tuples — F#"
  `https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/tuples`
  (Verified: 2026-05-08)
- Idris 2 docs, "Types and Functions"
  `https://idris2.readthedocs.io/en/latest/tutorial/typesfuns.html`
  (Verified: 2026-05-08)
- TypeScript Handbook, "More on Objects"
  `https://www.typescriptlang.org/docs/handbook/2/objects.html`
  (Verified: 2026-05-08)

#### Swift Evolution proposals

- SE-0015 Tuple comparison operators
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0015-tuple-comparison-operators.md`
  (Verified: 2026-05-08)
- SE-0283 Tuples Conform to Equatable, Comparable, Hashable
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0283-tuples-are-equatable-comparable-hashable.md`
  (Verified: 2026-05-08, status: Returned for revision)
- SE-0390 Noncopyable structs and enums
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md`
  (Verified: 2026-05-08)
- SE-0393 Value and Type Parameter Packs
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md`
  (Verified: 2026-05-08)
- SE-0396 Conform `Never` to Codable
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0396-never-codable.md`
  (Verified: 2026-05-08)
- SE-0398 Allow Generic Types to Abstract Over Packs
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md`
  (Verified: 2026-05-08)
- SE-0399 Tuple of value pack expansion
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0399-tuple-of-value-pack-expansion.md`
  (Verified: 2026-05-08)
- SE-0408 Pack Iteration
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0408-pack-iteration.md`
  (Verified: 2026-05-08)
- SE-0413 Typed throws
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md`
  (Verified: 2026-05-08)
- SE-0426 BitwiseCopyable
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0426-bitwise-copyable.md`
  (Verified: 2026-05-08)
- SE-0427 Noncopyable Generics
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md`
  (Verified: 2026-05-08)
- SE-0432 Borrowing/consuming pattern matching for noncopyable types
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md`
  (Verified: 2026-05-08)
- SE-0437 Noncopyable Standard Library Primitives
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md`
  (Verified: 2026-05-08)
- SE-0446 Nonescapable Types
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md`
  (Verified: 2026-05-08)
- SE-0453 InlineArray, a fixed-size array
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md`
  (Verified: 2026-05-08)
- SE-0465 Standard Library Primitives for Nonescapable Types
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md`
  (Verified: 2026-05-08)
- SE-0489 Improve EncodingError/DecodingError descriptions
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0489-codable-error-printing.md`
  (Verified: 2026-05-08)
- SE-0499 Support `~Copyable`, `~Escapable` in simple stdlib protocols
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md`
  (Verified: 2026-05-08, Implemented Swift 6.4)
- SE-0515 Allow `reduce` to produce noncopyable results
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0515-noncopyable-reduce.md`
  (Verified: 2026-05-08)
- SE-0528 Continuation
  `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0528-noncopyable-continuation.md`
  (Verified: 2026-05-08)

#### Swift Forums threads

- Holly Borla, "A Vision for Variadic Generics in Swift" (Nov 8 2022)
  `https://forums.swift.org/t/a-vision-for-variadic-generics-in-swift/61316`
  (Verified: 2026-05-08)
- Slava Pestov, "Pitch: User-defined tuple conformances" (Sep 6 2023)
  `https://forums.swift.org/t/pitch-user-defined-tuple-conformances/67154`
  (Verified: 2026-05-08)
- Joshua Cleetus, "[Pitch] Automatic Hashable Conformance for Tuples
  (Revival of SE-0283)" (Nov 9 2025)
  `https://forums.swift.org/t/pitch-automatic-hashable-conformance-for-tuples-revival-of-se-0283/83105`
  (Verified: 2026-05-08)
- taylorswift, "Tuple fields are still nuking Equatable" (Apr 12 2026)
  `https://forums.swift.org/t/tuple-fields-are-still-nuking-equatable/85973`
  (Verified: 2026-05-08)
- taylorswift, "Synthesizing Equatable, Hashable, and Comparable for tuple
  types" (Nov 21 2017)
  `https://forums.swift.org/t/synthesizing-equatable-hashable-and-comparable-for-tuple-types/7111`
  (Verified: 2026-05-08)
- Slava Pestov, "Fixes for parameter packs and closures" (Jun 14 2024)
  `https://forums.swift.org/t/fixes-for-parameter-packs-and-closures/72482`
  (Verified: 2026-05-08)
- Geordie_J, "Parameter Packs and InlineArray" (Sep 2 2025)
  `https://forums.swift.org/t/parameter-packs-and-inlinearray/81932`
  (Verified: 2026-05-08)
- Holly Borla, "SE-0499 Review" (Nov 19 2025)
  `https://forums.swift.org/t/se-0499-support-copyable-escapable-in-simple-standard-library-protocols/83297`
  (Verified: 2026-05-08)
- kavon, "[Pitch] Noncopyable Generics" (Nov 1 2023)
  `https://forums.swift.org/t/pitch-noncopyable-generics/68180`
  (Verified: 2026-05-08)
- Ben Cohen, "Noncopyable Generics in Swift: A Code Walkthrough" (Mar 23 2024)
  `https://forums.swift.org/t/noncopyable-generics-in-swift-a-code-walkthrough/70862`
  (Verified: 2026-05-08)

#### Swift compiler source / GitHub

- `swiftlang/swift` `stdlib/public/core/Tuple.swift.gyb` (lines 13–197)
  `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb`
  (Verified: 2026-05-08)
- `swiftlang/swift` `stdlib/public/Concurrency/Actor.swift` (lines 108–109,
  `extractIsolation<each Arg, Result>`)
  `/Users/coen/Developer/swiftlang/swift/stdlib/public/Concurrency/Actor.swift`
  (Verified: 2026-05-08)
- `swiftlang/swift` `test/stdlib/MirrorWithPacks.swift` (lines 28–33,
  `struct Tuple<each T>`)
  `/Users/coen/Developer/swiftlang/swift/test/stdlib/MirrorWithPacks.swift`
  (Verified: 2026-05-08)
- `swiftlang/swift` `test/Generics/tuple-conformances.swift` (full)
  `/Users/coen/Developer/swiftlang/swift/test/Generics/tuple-conformances.swift`
  (Verified: 2026-05-08)
- `swiftlang/swift` `test/SILOptimizer/tuple-conformances.swift` (full)
  `/Users/coen/Developer/swiftlang/swift/test/SILOptimizer/tuple-conformances.swift`
  (Verified: 2026-05-08)
- `swiftlang/swift` `include/swift/Basic/Features.def` (lines 232, 346, 367)
  — `BASELINE_LANGUAGE_FEATURE(ParameterPacks, 393, …)`,
  `EXPERIMENTAL_FEATURE(TupleConformances, false)`,
  `EXPERIMENTAL_FEATURE(MoveOnlyTuples, true)`
  `/Users/coen/Developer/swiftlang/swift/include/swift/Basic/Features.def`
  (Verified: 2026-05-08)
- `swiftlang/swift` `lib/AST/ProtocolConformance.cpp` (lines 1052–1085,
  vanishing-tuple-conformance)
  `/Users/coen/Developer/swiftlang/swift/lib/AST/ProtocolConformance.cpp`
  (Verified: 2026-05-08)
- `swiftlang/swift` PR #85373 "De-gyb Tuple.swift.gyb and replace it with
  variadic generics" (harlanhaskins, Nov 6–8 2025, **closed-without-merge**)
  `https://github.com/swiftlang/swift/pull/85373` (Verified: 2026-05-08)
- `swiftlang/swift` issue #82172 "Unnecessary ambiguity in overload
  resolution involving tuple wrapping parameter pack" (xwu, Jun 11 2025,
  **open**)
  `https://github.com/swiftlang/swift/issues/82172` (Verified: 2026-05-08)
- `swiftlang/swift` issue #75558 "Matching a parameter pack to a tuple of
  closures…" (JessyCatterwaul, Jul 30 2024, **open**)
  `https://github.com/swiftlang/swift/issues/75558` (Verified: 2026-05-08)

#### Adjacent Swift libraries / blog posts

- Sima Nerush, "Iterate Over Parameter Packs in Swift 6.0", swift.org blog
  (Mar 7 2024)
  `https://www.swift.org/blog/pack-iteration/` (Verified: 2026-05-08)
- Mathijs Kadijk & Tom Lokhorst, "Creating Equatable Tuples in Swift using
  Parameter Packs", nonstrict.eu blog (Jun 27 2025)
  `https://nonstrict.eu/blog/2025/creating-equatable-tuples-swift-parameter-packs/`
  (Verified: 2026-05-08)

#### Internal cross-references

- Peer doc: `api-design-leveraging-property-primitives.md` (in this same
  Research/ directory; owned by the parallel agent in this dispatch)
- `swift-either-primitives` peer research:
  `/Users/coen/Developer/swift-primitives/swift-either-primitives/Research/api-design-property-leverage.md`
  (the coproduct-side counterpart; informs the duality framing in Q1.d)

## Outcome

**Status**: RECOMMENDATION

The survey resolves seven structural facts that constrain `Product`'s API
trajectory:

1. **Categorical positioning is firm.** `Product<each E>` is the canonical
   n-ary categorical product (universal property witnessed by `init` and
   `values.0`/`.1`/…). It is the dual of `Either`. Both packages occupy
   their proper category-theoretic slots; no future stdlib change will
   re-shape them.
2. **The arity-6 wall is real.** Stdlib tuple `==` / `<` stops at arity 6 —
   `Tuple.swift.gyb` lines 108–197 (Verified: 2026-05-08). `Product<each
   E>` *removes the wall today* via SE-0408 pack iteration. This is the
   primary user-visible value-add until `TupleConformances` ships.
3. **`TupleConformances` is in tree but gated.** Swift 6.4 ships with the
   experimental flag (off); SE-0283 was revived as a pitch on Nov 9 2025;
   PR #85373 attempted the conversion and was closed-without-merge in
   November 2025 due to SILGen bugs (#82172 still open, Verified:
   2026-05-08). `Product` retains value as the **named** form for the
   ~12-month horizon.
4. **SE-0499 (Swift 6.4) removed the conformance-of-noncopyable blocker.**
   `Equatable` / `Comparable` / `Hashable` themselves now refine
   `~Copyable`/`~Escapable`. Once pack-noncopyable lands (no SE proposal
   yet), `Product`'s conditional conformances will not break.
5. **Codable is principled-absent for now.** SILGen pack-init bugs and the
   absence of an SE proposal mean Codable for parameter packs is
   genuinely unspellable. Document the absence with a re-evaluation entry
   point.
6. **Pack-of-pack n-ary functors are unspellable.** SE-0398's
   one-pack-per-type rule precludes a true `Product.bimap` /
   `Product.mapAll`. Document as a principled absence; do not partial-
   implement.
7. **Most language design regrets the survey turned up are about
   per-arity towers** (Scala's `Tuple22`, Rust's arity-12 wall, Haskell's
   `Solo`/`(,)`/`(,,)` ad-hoc tower). `Product<each E>` from day one is
   the correct shape; the only question is whether to wrap the underlying
   tuple at all once `TupleConformances` ships, and the answer is yes —
   the named form, dynamic-member-lookup, and `Swift.Error` aggregation
   all remain non-trivial value-adds.

The peer doc `api-design-leveraging-property-primitives.md` should treat
this survey as the **constraint baseline**: it sets which features are
buildable today, which are blocked, and which would be foolish to mimic
because the language is moving in a different direction.

## References

See Q7 (above). All 50+ primary sources are listed there with `Verified:
2026-05-08` tags or `Verified-via-secondary-source` annotations where
direct extraction was blocked (e.g., binary PDFs of Awodey, Wadler, Linear
Haskell full body).
