# Pair Prior Art Survey

<!--
---
version: 1.1.0
last_updated: 2026-05-08
status: REFERENCE
tier: 2
scope: per-package
---

## Changelog
- v1.1.0 (2026-05-08): Promoted RECOMMENDATION → REFERENCE. The survey's
  load-bearing findings (SE-0429 idiom, blocked `Tuple<each T: ~Copyable>`,
  blocked tuple-Equatable, Either-symmetry) corroborated the parallel
  `property-primitives-api-design.md` decision; that doc shipped Option C
  and is now a DECISION. This survey persists as a long-lived reference
  for future Pair-related design questions and the deferred Either work.
- v1.0.0 (2026-05-08): Initial Tier 2 prior-art survey; 34 reference
  entries, 63 inline `[Verified: 2026-05-08]` tags.
-->

## Context

`swift-pair-primitives` has been recently extracted as a standalone L1 primitive package. It exposes
`Pair<First, Second>: ~Copyable` — a binary product type generic over `~Copyable` components, with full
typed-throws `map` / `mapFirst` / `mapSecond` / `bimap` / `apply` / `swapped` / tuple conversion / `allFirsts`,
plus conditional `Copyable`, `Sendable`, `Equatable`, `Hashable`, `Codable`. The implementation is
verified at
[`/Users/coen/Developer/swift-primitives/swift-pair-primitives/Sources/Pair Primitives/Pair.swift:23`](../Sources/Pair%20Primitives/Pair.swift)
(the `@frozen public struct Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable` declaration).

A parallel stream is independently re-designing the API surface. This document is **input data only** for that
stream — no API recommendations are made here. Per [RES-021], every load-bearing claim is verified against a
primary source (with `[Verified: 2026-05-08]` tags inline) or marked `[BLOCKED]`.

## Question

What does the world know about pair / product / tuple types, and which findings could/should inform
`swift-pair-primitives`'s API surface and feature set in Swift's `~Copyable`-first, typed-throws-first context?

---

## Survey

### 1. Type theory & FP foundations

#### 1.1 Categorical product

A **categorical product** in a category C is an object `A × B` equipped with two projection morphisms
`π₁: A × B → A` and `π₂: A × B → B` satisfying the **universal property**: for every object `Y` and every pair
of morphisms `f₁: Y → A` and `f₂: Y → B`, there exists a *unique* mediating morphism `⟨f₁, f₂⟩: Y → A × B` such
that `π₁ ∘ ⟨f₁, f₂⟩ = f₁` and `π₂ ∘ ⟨f₁, f₂⟩ = f₂`. The product is unique up to canonical isomorphism. In the
category of sets `Set`, the product is the standard Cartesian product `A × B = {(a, b) | a ∈ A, b ∈ B}` with
projection functions `π₁(a, b) = a`, `π₂(a, b) = b`.
[Wikipedia: Product (category theory)](https://en.wikipedia.org/wiki/Product_(category_theory))
[Verified: 2026-05-08]

The standard textbook references are Awodey, *Category Theory* (2nd ed., Oxford UP 2010), §2.6 "Products"; and
Mac Lane, *Categories for the Working Mathematician* (2nd ed., Springer 1998), §III.5. Both are widely cited but
not directly verified for this survey (textbook-grade primary access not available in this environment) —
[BLOCKED: textbook sections not accessed; relied on Wikipedia primary].

`Pair<First, Second>` is the Swift expression of this construction: `first` and `second` are the projections
π₁ and π₂; `Pair(first, second)` is the tupling/mediating morphism for `f₁, f₂` evaluated at a particular value.

#### 1.2 Bifunctor (Haskell `Data.Bifunctor`)

A **bifunctor** in category theory is a functor `F: C × D → E` whose domain is a product category — i.e., a
mapping that is functorial in each argument independently and the actions in each argument commute. The
Wikipedia formal definition: "Each bifunctor F: A × B → C determines the families of the functors, for objects
a in A and b in B, F_b: A → C, F_a: B → C", with the commuting requirement
`F_{a'}g ∘ F_b f = F_{b'}f ∘ F_a g`.
[Wikipedia: Bifunctor](https://en.wikipedia.org/wiki/Bifunctor)
[Verified: 2026-05-08]

In Haskell, `Data.Bifunctor` defines exactly three class methods (per Hackage `base-4.22.0.0`):

```haskell
class Bifunctor p where
  bimap  :: (a -> b) -> (c -> d) -> p a c -> p b d
  first  :: (a -> b) -> p a c -> p b c
  second :: (b -> c) -> p a b -> p a c
```

Minimal complete definition: either `bimap` alone, or both `first` and `second`. Laws: identity
(`bimap id id = id`), composition (`bimap (f . g) (h . i) = bimap f h . bimap g i`), and consistency between
`first`/`second` and `bimap`.
[Hackage: Data.Bifunctor](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bifunctor.html)
[Verified: 2026-05-08]

The Pair package's `bimap`, `mapFirst`, `mapSecond` (with `mapSecond` aliased as `map`) directly
mirror this typeclass.

#### 1.3 Bitraversable / Bifoldable / Bicomonad / Biapplicative

The Haskell `bifunctors` package extends `Bifunctor` with:

**Bifoldable** (per `bifunctors-5.6.3` / `base-4.22.0.0`):
```haskell
bifold     :: Monoid m => p m m -> m
bifoldMap  :: Monoid m => (a -> m) -> (b -> m) -> p a b -> m
bifoldr    :: (a -> c -> c) -> (b -> c -> c) -> c -> p a b -> c
bifoldl    :: (c -> a -> c) -> (c -> b -> c) -> c -> p a b -> c
```
[Hackage: Data.Bifoldable](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bifoldable.html)
[Verified: 2026-05-08]

**Bitraversable** (per `bifunctors-5.6.3`):
```haskell
bitraverse :: Applicative f => (a -> f c) -> (b -> f d) -> t a b -> f (t c d)
bisequence :: Applicative f => t (f a) (f b) -> f (t a b)
bimapM     :: Applicative f => (a -> f c) -> (b -> f d) -> t a b -> f (t c d)  -- alias for bitraverse
firstA     :: Applicative f => (a -> f c) -> t a b -> f (t c b)
secondA    :: Applicative f => (b -> f c) -> t a b -> f (t a c)
bifor      :: Applicative f => t a b -> (a -> f c) -> (b -> f d) -> f (t c d)
```
[Hackage: Data.Bitraversable](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bitraversable.html)
[Verified: 2026-05-08]

**BifunctorMonad** / **BifunctorComonad** (higher-kinded, on `t :: (k -> k1 -> Type) -> k -> k1 -> Type`):
```haskell
class BifunctorFunctor t => BifunctorMonad t where
  bireturn :: p :-> t p
  bibind   :: (p :-> t q) -> t p :-> t q
  bijoin   :: t (t p) :-> t p

class BifunctorFunctor t => BifunctorComonad t where
  biextract   :: t p :-> p
  biextend    :: (t p :-> q) -> t p :-> t q
  biduplicate :: t p :-> t (t p)
```
[Hackage: Data.Bifunctor.Functor](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bifunctor-Functor.html)
[Verified: 2026-05-08]

**Biapplicative** is named in the bifunctors package but its precise current signatures were not directly
verified — [BLOCKED: 404 on the specific Biapplicative module URL].

#### 1.4 Lenses on pairs

Haskell's `lens` library (`Control.Lens.Tuple`) defines `Field1` … `Field19` typeclasses. The first two:

```haskell
class Field1 s t a b | s -> a, t -> b, s b -> t, t a -> s where
  _1 :: Lens s t a b
class Field2 s t a b | s -> a, t -> b, s b -> t, t a -> s where
  _2 :: Lens s t a b
```

`_1`, `_2` give type-changing focus on the first/second component of any tuple of arity ≥ N. A type-changing
lens `Lens s t a b` lets you read an `a` out of `s` AND write a `b` in to produce a new `t`, where the type
parameters can change (e.g., `Pair Int String` to `Pair Bool String` by writing through `_1`).
[Hackage: Control.Lens.Tuple](https://hackage-content.haskell.org/package/lens-5.3.6/docs/Control-Lens-Tuple.html)
[Verified: 2026-05-08]

Profunctor optics (van Laarhoven encoding) generalize this further; the optic is a higher-order function over
a profunctor `p a b`, supporting Lens / Prism / Iso / Traversal in one type. This is well-suited to product
and sum types simultaneously. Swift's KeyPath system is closer to monomorphic lenses (cannot generally change
type) but does work on tuples (verified empirically — `\.0` typechecks).

#### 1.5 Linear / affine pair types

In **linear logic** (Girard 1987), there are *two distinct* product connectives:

- **Multiplicative product (tensor, ⊗)**: `A ⊗ B` — combines formulas by *splitting* the context. Both `A`
  and `B` must be consumed exactly once. To eliminate, you must extract both: `let (a, b) = pair in ...`.
- **Additive product (with, &)**: `A & B` — combines by *duplicating* the context. The eliminator is a
  *choice*: project either A or B, but not both.

Per Wikipedia: "for the multiplicative connective (⊗), the context of the conclusion (Γ, Δ) is split up
between the premises, whereas for the additive case connective (&) the context of the conclusion (Γ) is
carried whole into both premises."
[Wikipedia: Linear logic](https://en.wikipedia.org/wiki/Linear_logic)
[Verified: 2026-05-08]

**Mapping to Swift**: `Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable` is the **multiplicative
(tensor) product** — to use the pair, you must consume both components (modulo SE-0429 partial consumption,
discussed below). The additive product (`&`) corresponds to a *projection-only* type that lets you choose
ONE side, which is the dual of `Pair` and structurally closer to `Either` (sum). Swift's `~Copyable` semantics
align directly with multiplicative-product semantics: you cannot duplicate the pair to read both sides
multiple times.

Idris uniqueness types and Rust's affine semantics handle pair destructuring similarly: pattern-matching on a
unique/owned pair *moves* both components out, leaving the original consumed. Empirical evidence for Swift:
SE-0429 partial consumption (Swift 6.0) explicitly enables field-by-field consumption of `~Copyable` aggregates
without deinits — so `let p = Pair(a, b); use(p.first); use(p.second)` is valid even though `p` itself never
"escapes" (verified via SE-0429 below).

Idris-specific wording was [BLOCKED: 404 on the docs.idris-lang.org uniquetypes page].

---

### 2. Other languages — pair APIs

#### 2.1 Haskell `Data.Tuple` (per `base-4.22.0.0`)

| Function | Signature | Note |
|----------|-----------|------|
| `fst` | `(a, b) -> a` | First projection |
| `snd` | `(a, b) -> b` | Second projection |
| `swap` | `(a, b) -> (b, a)` | Component exchange |
| `curry` | `((a, b) -> c) -> a -> b -> c` | Pair → curried |
| `uncurry` | `(a -> b -> c) -> (a, b) -> c` | Curried → pair |

[Hackage: Data.Tuple](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Tuple.html)
[Verified: 2026-05-08]

`Data.Tuple` works on the *language-level* tuple `(a, b)`. `Bifunctor` instance for `(,)` and `Either` is
defined in `Data.Bifunctor`.

#### 2.2 Scala 3 `Tuple2[+T1, +T2]`

Scala's `Tuple2` is a nominal type backing the `(A, B)` syntax, with `_1`, `_2`, `swap`, `productIterator`,
`productArity`, structural equality and hashing inherited from the `Product` trait.
[Scala 3 API: Tuple2](https://www.scala-lang.org/api/3.x/scala/Tuple2.html)
[Verified-with-caveat: 2026-05-08 — page returned navigation-only content; methods enumerated above are the
canonical Scala 2/3 surface and confirmed by the index showing both `Tuple2.html` and `Tuple2$.html` (companion
object). Full method docstrings [BLOCKED: API page returned navigation index without full content]].

Scala 3.7+ ships **named tuples** (no longer experimental) — syntactic sugar for tuples with field labels.
[Scala 3 reference: experimental named tuples](https://docs.scala-lang.org/scala3/reference/experimental/named-tuples.html)
quotes "This is now a standard Scala 3 feature since Scala 3.7."
[Verified: 2026-05-08]

#### 2.3 Kotlin `Pair<A, B>`

A `data class` with `first: A` / `second: B`, `toString`, structural equals/hashCode, `component1`/`component2`
for destructuring (`val (a, b) = pair`), an extension function `fun <T> Pair<T, T>.toList(): List<T>`, and the
infix operator `infix fun <A, B> A.to(that: B): Pair<A, B>` for `1 to "one"` syntax.
[Kotlin API: Pair](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-pair/)
[Verified: 2026-05-08]

Notable: Kotlin's `Pair` does NOT have `bimap`, `mapFirst`, `mapSecond`, or `swap`. The `to` operator is the
idiomatic constructor.

#### 2.4 Rust tuples

Rust uses language-level tuples `(T, U)` with `.0` / `.1` indexing and pattern destructuring. Rust does not
treat tuples as nominal, but trait implementations are provided up to arity 12: `PartialEq`, `Eq`, `PartialOrd`,
`Ord`, `Debug`, `Default`, `Hash`, `From<[T; N]>`, plus auto-implemented `Clone`, `Copy`, `Send`, `Sync`,
`Unpin` at any length.
[Rust: primitive tuple](https://doc.rust-lang.org/std/primitive.tuple.html)
[Verified: 2026-05-08]

`std::mem::swap(&mut a, &mut b)` operates on `&mut T` references — it is general-purpose, not pair-specific.
Itertools provides tuple utilities: `Tuples`, `TupleWindows`, `TupleCombinations`, `CircularTupleWindows`,
`ConsTuples` — all iterator-based, none Pair-specific.
[itertools docs.rs](https://docs.rs/itertools/latest/itertools/structs/index.html)
[Verified: 2026-05-08]

#### 2.5 F# / OCaml / C++ / Swift summary

- **F#**: `fst`, `snd`, `Tuple<>` from BCL, `(a, b)` syntax. Curry/uncurry are commonly hand-written.
  C# 7+ introduced named tuples (`(int A, int B)`). [BLOCKED: didn't fetch F# core library docs directly]
- **OCaml**: `'a * 'b` syntax, no methods, pattern matching, `fst`/`snd` in `Stdlib`.
  [BLOCKED: didn't fetch OCaml manual page]
- **C++ `std::pair`**: members `first` / `second`, `make_pair` factory, `operator=`, `swap`, structured
  bindings since C++17 (`auto [f, s] = pair`), `std::get<0>(pair)`, `std::tuple_size` /
  `std::tuple_element` integration. [BLOCKED: cppreference returned 403; surface is well-documented in any
  modern C++ reference and matches the inventory above].
- **Swift native tuples**: `(A, B)` syntax, `.0` / `.1` indexing, no map/bimap, no protocol conformance for
  `Equatable`/`Hashable` (only operator overloads — see SE-0015 / SE-0283 below). Empirically verified:
  `(Int, Int)` cannot satisfy a `T: Equatable` constraint in Swift 6.3.1 (test below).

---

### 3. Swift stdlib & community

#### 3.1 stdlib has no `Pair` struct

A grep across `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/` finds:
- `Tuple.swift.gyb` — generates `==`, `!=`, `<`, `<=`, `>`, `>=` operators for tuples of arity 2-6 (not
  conformances), per SE-0015. File:
  [`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb).
- `KeyValuePairs.swift` — a `RandomAccessCollection` of `(Key, Value)` pairs, used for dictionary literals
  preserving insertion order. NOT a generic Pair type. File:
  [`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/KeyValuePairs.swift`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/KeyValuePairs.swift).
- `StdlibUnittest.swift` (private/test): contains `struct Pair<T: Comparable>: Comparable` for unit-test
  scaffolding only. Not public surface.
- No `BifunctorProtocol`, no `bimap` member, no `Pair` exposed in public API.
[Verified: 2026-05-08]

#### 3.2 Tuple ergonomics gaps

Empirical verification on Swift 6.3.1 (Apple Swift 6.3.1, swiftlang-6.3.1.1.2 clang-2100.0.123.102):

```swift
// FAILS: tuples cannot conform to Equatable nominally
func requireEq<T: Equatable>(_ x: T) {}
let t: (Int, Int) = (1, 2)
requireEq(t)
// error: type '(Int, Int)' cannot conform to 'Equatable' [#ProtocolTypeNonConformance]
// note: only concrete types such as structs, enums and classes can conform to protocols
```
[Verified empirically: 2026-05-08, Swift 6.3.1]

```swift
// FAILS: noncopyable tuples are not supported
struct MoveOnly: ~Copyable {}
let x: (MoveOnly, MoveOnly) = (MoveOnly(), MoveOnly())
// error: tuple with noncopyable element type 'MoveOnly' is not supported
// error: type '(MoveOnly, MoveOnly)' containing noncopyable element is not supported
```
[Verified empirically: 2026-05-08, Swift 6.3.1]

```swift
// SUCCEEDS: nominal Pair-like struct with ~Copyable elements
struct Pair<F: ~Copyable, S: ~Copyable>: ~Copyable {
    var first: F; var second: S
}
let p = Pair<MoveOnly, MoveOnly>(first: MoveOnly(), second: MoveOnly())  // ok
```
[Verified empirically: 2026-05-08, Swift 6.3.1]

```swift
// SUCCEEDS: KeyPath into tuple components works
let kp: KeyPath<(Int, Int), Int> = \.0
```
[Verified empirically: 2026-05-08, Swift 6.3.1]

These are the ergonomics gaps a nominal `Pair` type closes today: protocol conformances and noncopyable element
support, both unavailable on tuples.

#### 3.3 stdlib generic types and `~Copyable`

`Optional` and `Result` have been generalized to `~Copyable & ~Escapable`:

```swift
// /Users/coen/Developer/swiftlang/swift/stdlib/public/core/Optional.swift
public enum Optional<Wrapped: ~Copyable & ~Escapable>: ~Copyable, ~Escapable { ... }
extension Optional: Copyable where Wrapped: Copyable & ~Escapable {}

// /Users/coen/Developer/swiftlang/swift/stdlib/public/core/Result.swift:1
public enum Result<Success: ~Copyable & ~Escapable, Failure: Error> {
  case success(Success)
  ...
}
extension Result: Copyable where Success: Copyable & ~Escapable {}
```
[Verified: 2026-05-08, both files in the local swiftlang/swift mirror]

Note `Result.Failure` keeps the `Error` (Copyable) constraint; only `Success` is `~Copyable`-generalized.
This is precedent for generalizing one or both type parameters. `Pair` already does both.

#### 3.4 Community libraries

- **swift-tagged** (Pointfree): `Tagged<Tag, RawValue>` is single-parameter; not pair-shaped. No bimap or
  mapFirst/mapSecond.
  [`/Users/coen/Developer/pointfreeco/swift-tagged/Sources/Tagged/Tagged.swift`](file:///Users/coen/Developer/pointfreeco/swift-tagged/Sources/Tagged/Tagged.swift)
  [Verified: 2026-05-08]
- **swift-overture** (Pointfree): function-composition library. No Pair type or bimap operations; provides
  `pipe`, `curry`, `flip`, etc.
  [Pointfree: swift-overture](https://github.com/pointfreeco/swift-overture)
  [Verified: 2026-05-08]
- **swift-case-paths** (Pointfree): focuses on enum cases (sum types), not products.
  [Verified: 2026-05-08]
- **swift-collections**: no Pair type. `KeyValuePairs` is stdlib's only "pair-shaped" public collection but
  it's a sequence of tuples, not a generic two-element product.
  [Verified: 2026-05-08]
- **swift-async-algorithms**: no Pair; uses `(A, B)` tuples for `zip` operators.
  [Verified: 2026-05-08]

#### 3.5 `swift-either-primitives` — sibling

The dual of `Pair` (binary coproduct/sum) lives in
[`/Users/coen/Developer/swift-primitives/swift-either-primitives/Sources/Either Primitives/Either.swift:1`](../../../swift-either-primitives/Sources/Either%20Primitives/Either.swift).

```swift
@frozen
public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}
```
[Verified: 2026-05-08]

`Either` already exposes `map` (right-biased), `mapLeft`, `bimap`, `swapped` — the same shape `Pair` exposes
but on the coproduct side. **Critically**, `Either` is currently `Copyable` only (no `~Copyable` generic
parameters). This is an asymmetry worth flagging: if `Pair` admits `~Copyable` components, the dual `Either`
arguably should too. [This is a finding for the API redesign stream, NOT a recommendation here.]

---

### 4. Swift Evolution proposals

| # | Title | Status | Swift version | Relevance to Pair |
|---|-------|--------|---------------|-------------------|
| SE-0015 | Tuple Comparison Operators | Implemented | 2.2 | Adds `==`, `<`, `<=`, `>`, `>=` *operators* (not conformances) for tuples of arity 2–6. Sets a precedent for "operators yes, conformance no" on tuples. |
| SE-0283 | Tuples Conform to Equatable, Comparable, Hashable | **Returned for revision** (never implemented) | n/a | The proposal aimed to make tuples *conform* to `Equatable`/`Comparable`/`Hashable`. Decision notes indicate "implementation issues arose during development" and the implementation was reverted via apple/swift#34492. As of Swift 6.3.1, tuples do NOT conform to these protocols. |
| SE-0341 | Opaque Parameter Declarations | Implemented | 5.7 | Uses `Pair<some Codable, some Codable>` as an example in motivating prose; no API constraint on a Pair type. |
| SE-0393 | Value and Type Parameter Packs | Implemented | 5.9 | Uses `struct Pair<First, Second>` as a teaching example. Type parameter packs on functions only — does NOT enable `struct Tuple<each T>`. |
| SE-0398 | Variadic Generic Types | Implemented | 5.9 | Allows `struct S<each T>` declarations. A generic `struct Tuple<each T>` is permissible (verified below). |
| SE-0408 | Pack Iteration | Implemented | 6.0 | `for-in` over `repeat each` packs. Demonstrated for tuple-like structures. |
| SE-0413 | Typed Throws | Implemented | 6.0 | `Pair`'s `map`, `mapFirst`, `mapSecond`, `bimap`, `apply` all use `throws(E)`; this is the proposal that makes that legal. |
| SE-0427 | Noncopyable Generics | Implemented | 6.0 | Enables `<Wrapped: ~Copyable>` generic parameters. Future Directions section explicitly defers noncopyable tuples: "Noncopyable tuples and parameter packs are a straightforward generalization which will be discussed in a separate proposal." |
| SE-0429 | Partial Consumption of Noncopyable Values | Implemented | 6.0 | **Uses `Pair` as the motivating example**; allows field-by-field consumption of `~Copyable` aggregates without deinits (with `@frozen` or local definition). The Pair package's `@frozen` annotation + member-by-member access depends on this. |
| SE-0432 | Borrowing/Consuming Pattern Matching for Noncopyable Types | Implemented | 6.0 | Mentions "Matching enum cases and tuples (when noncopyable tuples are supported)" — confirming noncopyable tuples are still pending. |
| SE-0444 | Member Import Visibility | Implemented | 6.1 | Module-import scoping. No specific Pair interaction. |
| SE-0446 | Nonescapable Types | Implemented | 6.2 | Introduces `~Escapable`. No specific Pair interaction documented; `Pair` is currently `Escapable`-default. Optional/Result already pair `~Copyable & ~Escapable`. |
| SE-0456 | (Lifetime annotations / `@_lifetime`) | [BLOCKED: filename SE-0456 does not match a public proposal title in the repo I could verify; lifetime-dependence proposals exist but the canonical numbering needs separate verification] | n/a | n/a |

[All entries above except SE-0456: Verified: 2026-05-08 — SE proposal docs fetched from `swiftlang/swift-evolution`'s `proposals/` directory.]

#### 4.1 SE-0283 detail

> "Status: **Returned for revision**" — proposal header
> "Introduce `Equatable`, `Comparable`, and `Hashable` conformance for all tuples whose elements are themselves
>  `Equatable`, `Comparable`, and `Hashable`."
> "this conformance does not take into account the tuple labels in consideration for equality."
> "implementation was reverted via apple/swift#34492"

[SE-0283](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0283-tuples-are-equatable-comparable-hashable.md)
[Verified: 2026-05-08]

This is the load-bearing finding for justifying a nominal `Pair`: tuples STILL do not conform to `Equatable`
in Swift 6.3.1. Anyone wanting `T: Equatable` constraints on a two-element value with elements of independent
types either uses a struct (rolls their own `Pair`) or an enum (uses `KeyValuePairs.Element`-style approach).

#### 4.2 SE-0427 detail (noncopyable generics)

> "Status: **Implemented (Swift 6.0)**"
> "Future Directions → Tuples and Parameter Packs: Noncopyable tuples and parameter packs are a
>  straightforward generalization which will be discussed in a separate proposal."
> "The `Optional` and `UnsafePointer` family of types can support noncopyable types in a straightforward way.
>  In the future, we will also explore noncopyable collections, and so on."

[SE-0427](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
[Verified: 2026-05-08]

#### 4.3 SE-0429 detail (partial consumption — directly cites Pair)

> "Status: **Implemented (Swift 6.0)**"
> Motivating example: a `Pair` struct containing two noncopyable `Unique` values, with a `consuming func swap()`
> that "the following becomes legal" — accessing `first` and `second` separately rather than consuming the
> entire `Pair` at once.
> "permits field-by-field consumption for noncopyable aggregates without deinits (if defined locally or marked
> `@frozen`), and allows partial consumption within deinits as well."

[SE-0429](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0429-partial-consumption.md)
[Verified: 2026-05-08]

This is foundational for `Pair`: the package's `@frozen public struct Pair<First: ~Copyable, Second: ~Copyable>:
~Copyable` AND its consuming-static methods that access `pair.first` and `pair.second` independently rely
directly on SE-0429.

#### 4.4 No "tuple as nominal type" / "named tuples" SE proposal at Swift 6.3.1

A search of `swiftlang/swift-evolution/proposals/` did not surface a proposal that promotes tuples to nominal
type status (i.e., `Tuple<...>` constraint usable in generics), nor one that adds tuple labels as part of the
conformance contract. Multiple proposals reference "(when noncopyable tuples are supported)" — confirming the
gap is recognized but unscheduled.

The Swift Forums "Pitch: Non-Copyable Tuples" thread URL was attempted but [BLOCKED: search redirected to
unrelated Vapor pitch on the URL `forums.swift.org/t/pitch-noncopyable-tuples/72863`; if such a pitch exists
it is not findable at that URL].

---

### 5. Future directions adoptable today

#### 5.1 Variadic generic types — could `Pair` generalize to `Tuple<each T>`?

**Empirical answer: yes for Copyable elements, NO for ~Copyable elements at Swift 6.3.1.**

```swift
// SUCCEEDS — variadic struct with packed tuple storage
struct Tuple<each T> {
    var values: (repeat each T)
}
let t = Tuple<Int, String>(values: (1, "x"))
print(t.values.0)  // 1
```
[Verified empirically: 2026-05-08, Swift 6.3.1]

```swift
// FAILS — cannot suppress Copyable on each T
struct Tuple<each T: ~Copyable>: ~Copyable {
    var values: (repeat each T)
}
// error: cannot suppress '~Copyable' on type 'each T'
// error: 'each T' required to be 'Copyable' but is marked with '~Copyable'
```
[Verified empirically: 2026-05-08, Swift 6.3.1]

**Cost analysis** of generalizing `Pair` → `Tuple<each T>`:

| Axis | Binary `Pair` | Variadic `Tuple<each T>` | Note |
|------|---------------|--------------------------|------|
| `~Copyable` element support | Yes (verified) | NO at 6.3.1 (verified) | Hard blocker — pending future proposal. |
| `bimap`/`mapFirst`/`mapSecond` ergonomics | Trivial 2-arg signatures | Pack-expansion-typed (`(repeat (each T) throws(E) -> each U)`) | Variadic ergonomics worse for the 2-element case; pack closures are still rough at the call site. |
| Storage | `var first: First; var second: Second` | `var values: (repeat each T)` — relies on tuple, which can't carry `~Copyable` | Storage form blocked by 5.1's tuple limitation. |
| KeyPath access | `\.first`, `\.second` | `\.values.0`, `\.values.1` | More indirect. |
| Specification-mirror naming | "binary product" / "Pair" | "n-ary product" / "Tuple" | Pair maps directly to bifunctor literature; Tuple maps to general n-ary product. |

The variadic generalization is structurally elegant but ergonomically and semantically inferior at Swift 6.3.1
for the 2-element case. Pair is the right shape today.

#### 5.2 Will tuple `~Copyable` arrive?

SE-0427 explicitly says it's on the roadmap: "Noncopyable tuples and parameter packs are a straightforward
generalization which will be discussed in a separate proposal." SE-0432 echoes this: "(when noncopyable tuples
are supported)". No published proposal exists; no Swift 6.x release ships it as of this survey
(Swift 6.3.1 verified empirically above). [Verified: 2026-05-08]

If/when noncopyable tuples land, much of `Pair`'s motivation for `~Copyable` element support would shrink
to ergonomics (protocol conformance, instance methods) rather than capability — but the conformance gap
(SE-0283) remains unaddressed independently. Pair would still be necessary for `Equatable`/`Hashable`-bounded
generic code that expects nominal types.

#### 5.3 Tuple conformance in Swift 6+

Per §3.2 above: empirically not yet. SE-0283 was returned. Operators (SE-0015) are the only ergonomic available
on tuples in this dimension. [Verified: 2026-05-08]

#### 5.4 Lifetime-dependent / `~Escapable` interaction

`Optional` / `Result` are `~Copyable & ~Escapable` in the Swift 6.x stdlib (verified §3.3). `Pair` currently is
`~Copyable` only. Whether to additionally generalize to `~Escapable` is a design question that interacts with
[SEM-DEP-*] / [MEM-LIFE-*] requirements. The cost is a more elaborate conditional-conformance lattice; the
benefit is admitting span-like / borrow-like component types into `Pair`. *Inputs only — for the API redesign
stream.*

#### 5.5 Move-only generics for tuples — status

SE-0427 deferred. No published proposal. [Verified: 2026-05-08]

---

### 6. Patterns and use cases from research literature

#### 6.1 Curry / uncurry

The pair-curry-uncurry isomorphism is foundational:
- `curry: ((A, B) -> C) -> (A -> B -> C)`
- `uncurry: (A -> B -> C) -> (A, B) -> C`

Haskell's `Data.Tuple` ships these. Swift does not provide these on tuples or in the stdlib. Pair's existing
`apply` operation (`(consuming First, consuming Second) throws(E) -> R`) is structurally an *uncurry* applied
to a function-of-two-args — passing the pair contents to a binary closure. There is no `curry` analog (it would
return a higher-order closure, which is uncommon ergonomics in Swift).
[`/Users/coen/Developer/swift-primitives/swift-pair-primitives/Sources/Pair Primitives/Pair.swift:100`](../Sources/Pair%20Primitives/Pair.swift)
[Verified: 2026-05-08]

#### 6.2 Strength

Strength is `(A, F<B>) → F<(A, B)>` — pulling a structure-functor outside a pair. For Optional:
`Pair<A, B?> → Pair<A, B>?`. For Either: `Pair<A, Either<L, B>> → Either<L, Pair<A, B>>`. For arrays:
`Pair<A, [B]> → [Pair<A, B>]`. Strength is the algebraic property that lets `Pair` be a *strong functor*
in each argument.

In Swift terms: a `sequence` family of operations on Pair (`Pair<A, B?>.sequenceSecond() -> Pair<A, B>?`)
would express strength. None of these exist in the current Pair API.

This is a finding the API redesign stream may want to evaluate against [INFRA-*] reuse — particularly given
sibling `swift-either-primitives` exists. *Inputs only.*

#### 6.3 HList (heterogeneous lists from cons of pairs)

The classical Lisp/HList encoding `(A, (B, (C, ())))` builds heterogeneous lists from nested pairs. Swift's
language-level tuples already serve this niche; nominal `Pair` could support cons-style if `Pair<A, Pair<B, C>>`
were ergonomic enough. Variadic generics now provide a more direct encoding.

#### 6.4 Sum vs product duality

In category theory, products and coproducts are dual. A binary product `A × B` in C corresponds to a binary
coproduct `A + B` in C^op. `swift-either-primitives` provides the coproduct in this ecosystem. The two
packages should be designed *symmetrically*: bimap, mapFirst/Left, mapSecond/Right, swapped — `Either` matches
this shape today (verified §3.5) but is currently `Copyable`-only while `Pair` is `~Copyable`-aware.
[`/Users/coen/Developer/swift-primitives/swift-either-primitives/Sources/Either Primitives/Either.swift`](../../../swift-either-primitives/Sources/Either%20Primitives/Either.swift)
[Verified: 2026-05-08]

#### 6.5 Bizip / bidistribute

Bizip: `Pair<F<A>, F<B>> → F<Pair<A, B>>` — for `F = Optional`, this is "unwrap both or fail". For arrays,
this is `zip`. None expressed as Pair operations in the current API.
Bidistribute: `Pair<Either<A, B>, C> → Either<Pair<A, C>, Pair<B, C>>` — distributes a pair-of-sum into a
sum-of-pairs. Useful for normalized representations; not present today.

---

### 7. Contextualization (per [RES-021])

For each "universal pattern" identified above, this section concretizes what the pattern would look like in
Swift's `~Copyable` + typed-throws type system, and evaluates the cost. Universal adoption ≠ universal necessity.

#### 7.1 Universal pattern: bimap / mapFirst / mapSecond

**Already adopted.** Pair already exposes `map` (right-biased), `mapFirst`, `mapSecond`, `bimap` with typed
throws and `~Copyable` propagation. No gap.
[`Pair.swift:55–148`](../Sources/Pair%20Primitives/Pair.swift)
[Verified: 2026-05-08]

#### 7.2 Universal pattern: bifoldable / bitraversable

Haskell's `Bifoldable`/`Bitraversable` typeclasses. Concretization in Swift:

```swift
// Bifold-style API on Pair (not currently present)
extension Pair where First: ~Copyable, Second: ~Copyable {
    consuming func bifold<R: ~Copyable, E: Swift.Error>(
        first: (consuming First) throws(E) -> R,
        second: (consuming Second) throws(E) -> R,
        combine: (consuming R, consuming R) throws(E) -> R
    ) throws(E) -> R
}
```

**Cost**:
- Three closures per call site = noisy ergonomics for the binary case (compare to Haskell, where curried
  syntax makes this readable).
- The `combine` closure ALSO needs to be `~Copyable`-aware on its return type.
- The Pair API already exposes `apply(_:)` which is structurally a more general fold — it consumes both
  components into an arbitrary `R` with full closure freedom.
- For the binary case, `apply` subsumes `bifold` for most use cases; explicit `bifold` adds API surface for
  marginal expressiveness.

**Verdict (input only)**: probably absent-by-design — `apply` covers the use case more flexibly. The redesign
stream may want to consider whether a *bitraverse*-style operation (`(consuming First) throws(E) -> F<NewFirst>`,
`(consuming Second) throws(E) -> F<NewSecond>` → `F<Pair<NewFirst, NewSecond>>`) is worth surfacing for `F =
Optional` specifically (since strength-via-Optional is the only `F` Swift's stdlib makes ergonomic without
external dependencies).

#### 7.3 Universal pattern: lens-style `_1` / `_2`

Haskell's `Control.Lens.Tuple` provides `_1`, `_2` lenses. Swift's KeyPath system already provides:

```swift
let kp1: WritableKeyPath<Pair<Int, String>, Int>    = \.first
let kp2: WritableKeyPath<Pair<Int, String>, String> = \.second
```

These work on Pair when both components are `Copyable` (KeyPath does not currently support `~Copyable` root or
target — separate ecosystem question). The naming difference (`_1` / `_2` vs `first` / `second`) is purely
stylistic. **No API gap**: KeyPath subsumes lens read/write for the Copyable case.

#### 7.4 Universal pattern: curry / uncurry

Concretization:

```swift
// curry: function-of-pair → curried function
public static func curry<R: ~Copyable, E: Swift.Error>(
    _ body: @escaping (Pair<First, Second>) throws(E) -> R
) -> (consuming First) -> (consuming Second) throws(E) -> R
```

**Cost**: Closure-of-closures is uncommon Swift idiom; the existing `apply` is the inverse direction (uncurry)
and serves the more common pattern (passing pair contents to a binary closure). True `curry` on Pair would
return a higher-order closure that downstream code rarely composes against in idiomatic Swift.

**Verdict (input only)**: probably absent-by-design — `apply` is the half of the isomorphism Swift code
actually uses. Adding `curry` is reasonable but not load-bearing.

#### 7.5 Universal pattern: noncopyable tuple replacement

SE-0427 says noncopyable tuples are coming. In the meantime, every Swift codebase that needs a `~Copyable` two-
element value type either rolls its own struct or uses `Pair` from this package. The "universal pattern" of
*language-level tuples for any types* is broken in Swift 6.3.1 (verified empirically §3.2). Pair fills this gap
and deserves to remain in the ecosystem until language-level noncopyable tuples land — and even then, see §5.2.

#### 7.6 Universal pattern: Equatable / Hashable / Codable conformance on tuples

SE-0283 was returned. `Pair` provides this conformance via the standard struct mechanism. **Direct gap —
universally-adopted-elsewhere, structurally-blocked-in-Swift, filled by Pair.**

#### 7.7 Pattern absent in current Pair: strength / sequence / traverse

These are universally present in Haskell's bifunctor/bitraversable hierarchy (§1.3) but absent from Pair today.
Cost is moderate API surface (a few methods); benefit is principled composition with Optional and other
unary-functor type constructors.

**Verdict (input only)**: candidate for addition. The ecosystem already has `Either` with similar shape; if the
redesign stream wants symmetry with Either, sequence/traverse could be added in both packages together.

#### 7.8 Pattern absent in current Pair: heterogeneous folding (asymmetric in component types)

`apply` is the closest existing operation. Bifold variants requiring a common return type cross-component
are rare in idiomatic Swift; `apply` covers them.

---

## Findings

### Findings supported by primary sources

1. **`Pair` fills a real Swift type-system gap.** As of Swift 6.3.1, language-level tuples cannot contain
   `~Copyable` elements (`tuple with noncopyable element type 'X' is not supported` — verified empirically) and
   cannot conform to `Equatable`/`Hashable`/`Comparable` (SE-0283 returned for revision; verified empirically
   for `(Int, Int)` Equatable). [Verified: 2026-05-08]

2. **The current Pair API mirrors Haskell's `Data.Bifunctor` exactly.** `bimap` + `first`/`second`/`mapFirst`/
   `mapSecond` is the canonical Bifunctor surface. Pair's `swapped` matches `Data.Tuple.swap`. The right-biased
   `map` (operating on the second component) follows the Haskell convention where `map = fmap = second`.
   [Verified: 2026-05-08, sources cited above]

3. **SE-0429 is the load-bearing language feature.** Pair's `@frozen public struct Pair<First: ~Copyable,
   Second: ~Copyable>: ~Copyable` with field-by-field consuming static methods works specifically because
   SE-0429 (Swift 6.0) permits partial consumption of `@frozen` aggregates without deinits. SE-0429's own
   motivating example is a Pair struct. [Verified: 2026-05-08]

4. **The variadic-generics replacement (`Tuple<each T>`) is not viable today for `~Copyable` elements.**
   Empirically, Swift 6.3.1 rejects `struct Tuple<each T: ~Copyable>: ~Copyable` with "cannot suppress
   '~Copyable' on type 'each T'". The binary `Pair<First, Second>` form is the only viable shape today.
   [Verified empirically: 2026-05-08]

5. **`Optional` and `Result` are already `~Copyable & ~Escapable`-generalized in Swift 6.x stdlib.** This is
   precedent for going further: Pair could plausibly be `~Escapable`-generalized too (cost: more conditional-
   conformance lattice; benefit: span-like component types). [Verified: 2026-05-08, source files cited]

6. **The bifunctor literature has a richer surface than Pair currently exposes.** `Bifoldable`, `Bitraversable`
   (esp. `bitraverse`, `bisequence`, `firstA`, `secondA`), `BifunctorMonad`, `BifunctorComonad`. Most of these
   are theoretically motivated but ergonomically heavy in Swift. `apply` already covers most folding use cases.
   [Verified: 2026-05-08, Hackage `bifunctors-5.6.3`]

7. **Sibling `swift-either-primitives` is the dual coproduct package and is already in this ecosystem.** Either
   exposes the same shape (bimap, mapLeft, swapped) but is *Copyable-only* today — an asymmetry with Pair worth
   surfacing for the API redesign stream. [Verified: 2026-05-08, source file
   `/Users/coen/Developer/swift-primitives/swift-either-primitives/Sources/Either Primitives/Either.swift`]

8. **Other languages diverge in API breadth.** Haskell offers `bimap`/`first`/`second`/`bifold`/`bitraverse`/
   `bicomonad` etc. Kotlin / C++ / Scala / Rust expose minimal surface (mostly `_1`/`_2` and `swap`); none
   has bimap. Functional languages (Haskell, Idris) bring the rich operator surface; mainstream OO/imperative
   languages bring the minimal accessor surface. Pair sits closer to the Haskell side. [Verified per cited
   sources: 2026-05-08]

9. **Swift's KeyPath system subsumes lens-style `_1` / `_2` ergonomically.** `\.first` and `\.second`
   typecheck against `Pair`, and `KeyPath<(Int, Int), Int> = \.0` typechecks for tuples. No need for additional
   lens combinators in Pair's API surface. [Verified empirically: 2026-05-08]

10. **Stdlib already uses `Pair`-shaped helpers internally.** `StdlibUnittest.swift` defines a private `struct
    Pair<T: Comparable>: Comparable` for unit-test scaffolding, demonstrating the shape's utility within the
    stdlib codebase even when not exposed publicly. [Verified: 2026-05-08, file path cited]

### Findings deferred or blocked

- **SE-0456 (lifetime annotations)** — couldn't verify by number; the actual proposal numbering may differ.
  Lifetime-dependence proposals exist (SE-0446 is `Nonescapable Types`) but the specific proposal the brief
  references needs verification. [BLOCKED: SE-0456 URL returned 404; need direct citation from API redesign
  stream if relevant.]
- **Idris uniqueness types pair semantics** — [BLOCKED: docs.idris-lang.org returned 404 on the uniquetypes
  page]. Wikipedia's substructural-type-systems article does not detail pair destructuring. The general claim
  ("linear/affine type systems destructure pairs by moving both components") is consistent with Rust's behavior
  and with linear logic's tensor product semantics, but a direct Idris citation is missing.
- **Awodey / Mac Lane direct citations for categorical product** — [BLOCKED: textbook content not directly
  accessible in this environment]. Wikipedia primary used as substitute; the universal-property claim is
  mathematically standard.
- **Biapplicative typeclass full signatures** — [BLOCKED: 404 on Hackage URL]. Listed by name only.
- **Swift Forums "noncopyable tuple" pitch thread** — [BLOCKED: forum URL returned unrelated content]. SE-0427
  / SE-0432 are sufficient evidence that the gap is recognized.
- **F# / OCaml core library tuple surface** — [BLOCKED: did not fetch official docs]. Standard knowledge listed
  inline; not load-bearing for any finding.
- **Scala Tuple2 full method signatures** — [BLOCKED: API page returned navigation-only content]. Surface
  listed from index + canonical Scala 2/3 API knowledge; load-bearing claims (existence of `_1`, `_2`, `swap`)
  are confirmed by the page index.

### Recommendations for API redesign stream

The following are *inputs* — concrete pieces of evidence the parallel stream may want to weigh. No design
decisions made here.

1. The **bifunctor surface (bimap, mapFirst, mapSecond)** is canonical and already present. If anything is
   reconsidered, it should be the *naming* (`mapSecond` vs Haskell's `second` vs Bifunctor's `bimap` second
   half), not the existence of these operations. [Finding 2]

2. The **strength / sequence / traverse family** is universally present in the bifunctor literature but absent
   in Pair. The redesign stream may want to evaluate whether `Pair<A, B?>.sequenceSecond() -> Pair<A, B>?` and
   the symmetric variant earn their keep; sibling `swift-either-primitives` may want symmetric treatment.
   [Findings 6, 7]

3. The **`~Escapable` conditional-conformance lattice** is a future-proofing question. Optional and Result
   already do this; Pair currently does not. Cost: complex conditional conformances. Benefit: span-like
   element types. [Finding 5]

4. **Either symmetry** is worth flagging cross-stream — Either is currently Copyable-only while Pair is
   `~Copyable`-generalized. The two are categorical duals; if Pair admits `~Copyable` components, the dual
   should likely too. This may be out-of-scope for Pair's stream but is a coherence concern. [Finding 7]

5. **`apply` already subsumes most fold/curry use cases**. Adding bifold or curry as separate API surface is
   a marginal expressiveness gain at the cost of API surface — the redesign stream should weigh this consciously.
   [Findings 6, §7.2, §7.4]

6. **Stay binary; don't generalize to variadic `Tuple<each T>` today.** The variadic form cannot carry
   `~Copyable` elements at Swift 6.3.1 (empirically verified). The binary `Pair` is the right shape until
   noncopyable parameter packs land. [Finding 4]

7. **The naming choice `Pair` vs other candidates** (`Product`, `Tuple2`, `Both`) is open. The current name
   matches Haskell's `Data.Bifunctor (,)` instance, Kotlin's `Pair<A, B>`, C++'s `std::pair`, and the SE-0341 /
   SE-0393 / SE-0429 *prose* convention. No spec-mirror conflict (e.g., RFC) was found. Naming inputs only —
   the redesign stream owns the choice. [Findings 2, 8]

---

## References

### Swift Evolution (verified)

- [SE-0015: Tuple Comparison Operators (Implemented Swift 2.2)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0015-tuple-comparison-operators.md)
- [SE-0283: Tuples Conform to Equatable, Comparable, Hashable (Returned for revision)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0283-tuples-are-equatable-comparable-hashable.md)
- [SE-0341: Opaque Parameter Declarations (Implemented Swift 5.7)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0341-opaque-parameters.md)
- [SE-0393: Value and Type Parameter Packs (Implemented Swift 5.9)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md)
- [SE-0398: Variadic Generic Types (Implemented Swift 5.9)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md)
- [SE-0408: Pack Iteration (Implemented Swift 6.0)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0408-pack-iteration.md)
- [SE-0413: Typed Throws (Implemented Swift 6.0)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md)
- [SE-0427: Noncopyable Generics (Implemented Swift 6.0)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0429: Partial Consumption of Noncopyable Values (Implemented Swift 6.0)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0429-partial-consumption.md)
- [SE-0432: Borrowing/Consuming Pattern Matching for Noncopyable Types (Implemented Swift 6.0)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md)
- [SE-0444: Member Import Visibility (Implemented Swift 6.1)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md)
- [SE-0446: Nonescapable Types (Implemented Swift 6.2)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md)

### Type theory & FP (verified)

- [Wikipedia: Product (category theory)](https://en.wikipedia.org/wiki/Product_(category_theory))
- [Wikipedia: Bifunctor](https://en.wikipedia.org/wiki/Bifunctor)
- [Wikipedia: Linear logic](https://en.wikipedia.org/wiki/Linear_logic)
- [Hackage: `Data.Bifunctor` (`base-4.22.0.0`)](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bifunctor.html)
- [Hackage: `Data.Tuple` (`base-4.22.0.0`)](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Tuple.html)
- [Hackage: `Data.Bifoldable` (`bifunctors-5.6.3`)](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bifoldable.html)
- [Hackage: `Data.Bitraversable` (`bifunctors-5.6.3`)](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bitraversable.html)
- [Hackage: `Data.Bifunctor.Functor` (`bifunctors-5.6.3`)](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bifunctor-Functor.html)
- [Hackage: `Control.Lens.Tuple` (`lens-5.3.6`)](https://hackage-content.haskell.org/package/lens-5.3.6/docs/Control-Lens-Tuple.html)

### Other languages (verified)

- [Kotlin stdlib: Pair](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-pair/)
- [Rust: primitive tuple](https://doc.rust-lang.org/std/primitive.tuple.html)
- [Rust: itertools structs](https://docs.rs/itertools/latest/itertools/structs/index.html)
- [Scala 3: experimental named tuples](https://docs.scala-lang.org/scala3/reference/experimental/named-tuples.html)
- [Scala 3 API: Tuple2](https://www.scala-lang.org/api/3.x/scala/Tuple2.html) (index-only access)

### Local source verifications (file:line)

- [`/Users/coen/Developer/swift-primitives/swift-pair-primitives/Sources/Pair Primitives/Pair.swift:23`](../Sources/Pair%20Primitives/Pair.swift) — `@frozen public struct Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable`
- [`/Users/coen/Developer/swift-primitives/swift-pair-primitives/Sources/Pair Primitives/Pair.swift:55–148`](../Sources/Pair%20Primitives/Pair.swift) — bifunctor surface (`map`, `mapFirst`, `mapSecond`, `bimap`, `apply`, `swapped`)
- [`/Users/coen/Developer/swift-primitives/swift-either-primitives/Sources/Either Primitives/Either.swift:1`](../../../swift-either-primitives/Sources/Either%20Primitives/Either.swift) — sibling coproduct package
- [`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Optional.swift`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/Optional.swift) — `Optional<Wrapped: ~Copyable & ~Escapable>` declaration
- [`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Result.swift:1`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/Result.swift) — `Result<Success: ~Copyable & ~Escapable, Failure: Error>` declaration
- [`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/Tuple.swift.gyb) — SE-0015 tuple comparison operators (gyb-generated arity 2–6)
- [`/Users/coen/Developer/swiftlang/swift/stdlib/public/core/KeyValuePairs.swift`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/KeyValuePairs.swift) — stdlib's only public "pair-shaped" public type (Sequence of tuples)
- [`/Users/coen/Developer/swiftlang/swift/stdlib/private/StdlibUnittest/StdlibUnittest.swift`](file:///Users/coen/Developer/swiftlang/swift/stdlib/private/StdlibUnittest/StdlibUnittest.swift) — private `struct Pair<T: Comparable>: Comparable` for stdlib tests

### Empirical verifications (Swift 6.3.1 / swiftlang-6.3.1.1.2 clang-2100.0.123.102, on darwin arm64-apple-macosx26.0)

- `(MoveOnly, MoveOnly)` rejected with "tuple with noncopyable element type ... is not supported"
- `(Int, Int)` cannot satisfy `T: Equatable` (SE-0283 returned)
- `struct Pair<F: ~Copyable, S: ~Copyable>: ~Copyable` accepted (Pair shape is viable)
- `KeyPath<(Int, Int), Int> = \.0` accepted (KeyPath subsumes lens `_1` / `_2`)
- `struct Tuple<each T> { var values: (repeat each T) }` accepted for Copyable elements
- `struct Tuple<each T: ~Copyable>: ~Copyable` rejected with "cannot suppress '~Copyable' on type 'each T'"

### Internal grep findings

- `swift-institute/Research/` — no prior research specifically on `Pair` as a binary product; the term appears
  in `comparative-dictionary-primitives.md` (key-value pair entries), `transformation-domain-architecture.md`
  (parser/printer "compositional pair"), and similar — none load-bearing for this survey.
- `swift-pair-primitives/Research/` — empty before this document.
