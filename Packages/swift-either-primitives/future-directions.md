# Either — Future Directions

<!--
---
version: 1.2.0
last_updated: 2026-05-10
changelog:
  - "1.2.0 (2026-05-10): Candidate 3 (Distributivity) verdict updated REJECT → ADOPT (deferred to post-0.1.0). Home is a new L1 sibling `swift-bifunctor-primitives` — opens a categorical-structure micro-package family separate from algebra-*-primitives (which is value-level algebra). First-pass framework had wrongly selected algebra-law-primitives based on a 'canonical home for laws' premise that didn't survive package-source inspection (it's value-algebra verification harnesses, not type-level iso witnesses)."
  - "1.1.1 (2026-05-10): Semigroup relocation landed — `Algebra.Semigroup` now lives at `swift-algebra-semigroup-primitives/Sources/Algebra Semigroup Primitives/Algebra.Semigroup.swift`."
  - "1.1.0 (2026-05-10): Correct Candidate 5 (Validation) infrastructure-gate claim."
status: RECOMMENDATION
tier: 2
scope: cross-package
trigger: Forward-pass research before 0.1.0 publish; combines categorical totality audit (what does the binary coproduct's "fully realized" closure look like?) with a Swift-Evolution forward-pass (what proposals change the design space, and is typed throws cannibalising Either?). Status RECOMMENDATION — additive to 0.1.0; no recommendation here blocks tomorrow's publish.
toolchains_referenced:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a
preceded_by:
  - either-academic-and-ecosystem-survey.md (COMPLETE, 2026-05-08) — load-bearing prior art
  - api-design-property-leverage.md (RECOMMENDATION, 2026-05-08) — current call-site shape
  - escapable-arm-support.md (DECISION, 2026-05-09) — operationalized ~Escapable cohort
relates_to:
  - swift-institute/Research/escapable-support-pair-either-product.md
  - swift-institute/Research/typed-throws-mixed-error-domains.md
  - swift-institute/Research/algebra-adt-package-relationship.md
  - swift-institute/Research/algebra-primitives-package-split.md
---
-->

## Context

Three primitives — `swift-either-primitives`, `swift-pair-primitives`,
`swift-product-primitives` — publish 0.1.0 tomorrow (2026-05-11). The shipping
surface for Either is well-characterized:

* `@frozen public enum Either<Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable>: ~Copyable, ~Escapable`
* Functor surface: `map(right:)` / `map(left:)` / `map(left:right:)` (labeled
  overloads); equal-arm `map { f }`.
* Monadic surface: `flatMap(right:)` / `flatMap(left:)`; equal-arm `flatMap { f }`.
* Catamorphism: `fold(left:right:)`.
* Symmetry: `swapped()` (instance + static).
* Accessors: `var left: Left?`, `var right: Right?`, peek accessors via
  `@_lifetime(borrow self)` for `Copyable & ~Escapable` arms.
* Never elimination: `var value` on each arm.
* Conformance ladder: `Copyable`, `Escapable`, `Sendable`, `BitwiseCopyable`,
  `Equatable`, `Hashable`, `Codable`, `Swift.Error`, plus institute
  `Equation.Protocol`, `Hash.Protocol`, `Comparison.Protocol`.

The prior surveys
(`either-academic-and-ecosystem-survey.md` v1.0.0, 2026-05-08;
`api-design-property-leverage.md` v1.0.0, 2026-05-08;
`escapable-arm-support.md` v1.0.0, 2026-05-09) characterize what exists and
why. None of them frames the *forward* question:

> Given everything that the binary coproduct could in principle support
> (categorical totality), and given the Swift-Evolution surface in flight or
> recently-accepted as of 2026-05-10, what should `swift-either-primitives`
> adopt, defer, or explicitly reject?

This document is that forward-pass. Per [RES-019], it cites and extends
prior research rather than duplicating it. Per [RES-021], every "X exists in
Haskell/Scala/Rust" finding is contextualized against Swift's actual
constraints — universal adoption elsewhere is not universal necessity here.
Per [RES-018], any candidate that proposes a new ecosystem package faces the
"second consumer + composition fails" check.

**Trigger**: pre-0.1.0 forward pass; identify post-0.1.0 work for backlog
ranking. Status RECOMMENDATION (no item is a 0.1.0 blocker).

**Scope**: cross-package — several candidates touch
`swift-pair-primitives` (the dual product) and a hypothetical
`swift-validation-primitives` / `swift-these-primitives`.

## Question

For each candidate forward direction (type-theory totality gaps + Swift-
Evolution-enabled shapes), what should `swift-either-primitives` adopt,
defer, or explicitly reject?

This decomposes into thirteen candidates, organized in two angles:

**Angle 1 — Categorical totality** (what's missing from the binary coproduct
closure?)
1. Associativity isomorphisms (`assocL` / `assocR`)
2. Commutativity (already `swapped`; promote to documented isomorphism?)
3. Distributivity over product (`Either<A,B> × C ≅ Either<A×C, B×C>`)
4. `These<A,B>` — inclusive-or
5. `Validation<E,A>` — Either with semigroup-accumulating left
6. n-ary `Coproduct<each T>` / `OneOf<each T>`
7. Bifunctor laws as compile-time tests (`bimap id id ≡ id`, composition)
8. Distributive law / strength morphisms (`factor_first`, `factor_ok`)
9. `partitionEithers` / `lefts` / `rights` collection operations
10. Bidirectional `Result<Success, Failure>` ↔ `Either<Failure, Success>` interop

**Angle 2 — Swift Evolution forward-pass** (what proposals reshape the design space?)
11. Typed throws (SE-0413, accepted; in-flight refinements) — does it cannibalise
    Either's error-channel role?
12. Parameter packs in enums (blocked, see Q3.2 of survey) — n-ary `Either<each T>`
13. `Uninhabited` protocol (referenced in SE-0413 future directions) — conditional
    conformance reservation

The Outcome section ranks these and produces a verdict table.

## Constraints

| ID | Statement | Bite for forward directions |
|----|-----------|------------------------------|
| [API-NAME-001/002] | Nest.Name pattern; no compound identifiers. | Forces `assocL` → `Either.associate.left(...)` or `Either.associated(left:)`; rejects `Validation`-as-method. |
| [API-NAME-003] | Spec-mirroring names. | `These` follows Haskell `these` package naming verbatim if shipped. |
| [API-ERR-001] | Typed throws required. | Affects every closure parameter on every candidate. |
| [PRIM-FOUND-001] | No Foundation in primitives. | Excludes any candidate that requires Foundation types. |
| [ARCH-LAYER-*] | Primitives = atomic; foundations = composed. | Drives "this candidate stays here vs. moves to a new package" decision. |
| [RES-018] | Second-consumer + composition-fails check before extracting new package. | Validation, These, and OneOf face this check. |
| [RES-021] | Contextualize prior art in Swift's actual constraints. | Several candidates are expressible-but-pointless given typed throws. |
| [RES-022] | Structural correctness over diff size. | If the right shape is breaking-change, flag and defer; do not rationalize. |
| [MEM-COPY-*] / [MEM-LIFE-*] | Cohort policy on `~Copyable` / `~Escapable`. | Determines whether a candidate must thread Gap A. |

**Forward-compatibility constraint**: every recommendation that adds API must
either (a) be additive (no breaking change to 0.1.0) or (b) be flagged
explicitly as breaking, with a rationale and a target version. No
recommendation should silently break consumers using Either today.

## Analysis

### Candidate 1 — Associativity isomorphisms (`assocL` / `assocR`)

**What it is.** The binary coproduct is associative up to isomorphism:
`Either<Either<A,B>,C> ≅ Either<A, Either<B,C>>`. Concretely:

```swift
extension Either {
    /// Re-associates a right-nested coproduct as left-nested.
    /// `Either<A, Either<B, C>>` → `Either<Either<A, B>, C>`.
    public static func associated<A, B, C>(_ either: Either<A, Either<B, C>>) -> Either<Either<A, B>, C>
    where Left == Either<A, B>, Right == C { ... }

    /// Re-associates a left-nested coproduct as right-nested.
    public static func associated<A, B, C>(_ either: Either<Either<A, B>, C>) -> Either<A, Either<B, C>>
    where Left == A, Right == Either<B, C> { ... }
}
```

**Prior art.** No standard library exposes `assocL` / `assocR` as named
combinators on `Either`. Haskell's `bifunctors` package provides `Bifunctor`
infrastructure but leaves associativity implicit (it falls out of `bimap`
plus pattern-matching). Idris2's `Data.Either` and PureScript's `Data.Either`
similarly do not name it. The categorical name comes from the coherence
diagrams of a symmetric monoidal category with respect to the coproduct
(nLab, "coproduct"; `[Verified: 2026-05-10]` — same source as survey Q1.1).

**Contextualization.** In Swift, the "right-associative nested Either"
pattern is the only N-ary substitute we have (per survey takeaway 2:
variadic generic enums blocked, no timeline). Parser-primitives composes
errors as `Either<P0.Failure, Either<P1.Failure, P2.Failure>>` already (cf.
`api-design-property-leverage.md` Existing Call Sites Inventory). When
those nest 3+ deep, the order of nesting matters for case-pattern
exhaustiveness.

But: in practice, parser composition builds the nesting incrementally
(`Skip.First.Failure = Either<P0.Failure, P1.Failure>`; `Skip.Second.Failure
= Either<...>` rebuilds). Re-associating an *existing* `Either<Either<A,B>,
C>` to `Either<A, Either<B,C>>` mid-stream has no current consumer. The
operation is a categorical correctness witness, not a working tool.

The cost is non-zero: two static methods (the type signature is awkward
because `Self == Either<X, Y>` constrains both type parameters; the
associativity-witness signatures need a *different* `Either` instantiation
on each side). The instance form would not exist (no obvious `self`).

**Verdict: REJECT (for now).** No consumer demand; the value is purely
documentary. Document the categorical isomorphism in DocC prose instead of
as code. Revisit if a parser-primitives or rfc-9112 deserialization site
emerges that needs to flatten / reshape nested-Either errors. If the time
comes, ship as a free-static pair on `Either`.

### Candidate 2 — Commutativity isomorphism (already `swapped`)

**What it is.** Either is symmetric: `Either<A, B> ≅ Either<B, A>` via
`swapped()`. The current API ships this. The forward-direction question is
only: should we promote `swapped` to a formal isomorphism (witness type
that ships round-trip-identity tests in the conformance suite)?

**Prior art.** Haskell `Data.Bifunctor.Swap` (in `bifunctors` package)
provides a `Swap` typeclass with `swap :: p a b -> p b a` plus the law
`swap . swap ≡ id`. `[Verified: 2026-05-10]` against
`hackage.haskell.org/package/bifunctors/docs/Data-Bifunctor-Swap.html`.

**Contextualization.** Swift Institute does not ship a `Bifunctor.Swap`
protocol. Adding one would be a research direction in
`swift-bifunctor-primitives` or similar — not in either-primitives.
`swapped()` already exists; the round-trip test
`Either.swapped(Either.swapped(e)) == e` is straightforward to add as a
swift-testing case but is not gated on any future direction.

**Verdict: ADOPT (test-only, low priority).** Add a `swapped . swapped =
id` test under `Tests/Either Primitives Tests/`. No production code change.
Track a hypothetical `swift-bifunctor-primitives` only if a second consumer
emerges (Pair has the same `swapped()`, so a shared protocol would have two
inhabitants — but two is the floor for [RES-018], not a clear motivation).

### Candidate 3 — Distributivity over product

**What it is.** In a category with finite products and coproducts, there is
a distributive law `Either<A,B> × C → Either<A×C, B×C>` (and its dual).
Concretely:

```swift
// Right-distribute a Pair over an Either-in-first-position
public static func distributed<A, B, C>(
    _ pair: Pair<Either<A, B>, C>
) -> Either<Pair<A, C>, Pair<B, C>>

// And the inverse, factor_first from Rust's `either` crate (survey Q6.1)
public static func factored<A, B, C>(
    _ either: Either<Pair<A, C>, Pair<B, C>>
) -> Pair<Either<A, B>, C>
where /* C is duplicable, or available on the Copyable arm only */
```

**Prior art.** Rust `either` crate provides `factor_first`, `factor_second`,
`factor_ok`, `factor_err`, `factor_none` — five flavors of distributive
witness (survey Q6.1). Haskell has no analogue in `Data.Either` directly;
the `categories` package and `bicategories` literature treat the
distributive law abstractly. Cats (Scala) has `Distribute` and
`InvariantSemigroupal` typeclasses with limited Either-specific methods.
`[Verified: 2026-05-10]` against
`docs.rs/either/latest/either/enum.Either.html` for Rust.

**Contextualization.** This is a cross-package operation — it requires
`Pair<First, Second>` from `swift-pair-primitives` to even type. It would
live either (a) in `swift-pair-primitives` as
`Pair.Either.distributed(...)`, (b) in `swift-either-primitives` as
`Either.distributed(_ : Pair<...>)`, or (c) in a hypothetical
`swift-distributivity-primitives` aggregating both directions.

[RES-018] check: zero current consumers; the only discussed use case
(parser error × context-tag) does not exist in the ecosystem today.
Composition-fails: a consumer can manually pattern-match
`Pair<Either<A,B>, C>` and rebuild — composition is verbose but does not
fail outright.

**Verdict: ADOPT (deferred to post-0.1.0).**
Updated 2026-05-10. After a corrected framework pass, the home is a
new L1 sibling **`swift-bifunctor-primitives`**. Decision rationale:
the first-pass framework selected `swift-algebra-law-primitives`, but
inspection showed that package is *value-algebra law-verification
harnesses* (namespace `enum`s with `check(...) -> Violation?` over
`Collection` samples), not a home for *type-level categorical
isomorphisms*. Hosting iso witnesses there would be mission creep on
a one-way door. The institute distinguishes value-level algebra
(magma → semigroup → monoid → ring → module, plus verification at
algebra-law-primitives) from type-level categorical structure (Pair as
product, Either as coproduct, bifunctor laws, distributivity isos);
the latter has no canonical home today. `swift-bifunctor-primitives`
opens that home as a deliberate micro-package per the institute's
"micro packages accepted" stance. [RES-018] second-consumer gate
clears: Pair × Either, Either × Product, Pair × Product, plus future
bifunctor-law instances on each are the natural inhabitants. Ship is
deferred to post-0.1.0; the framework decides *where*, not *when*.
Tracked via `HANDOFF-bifunctor-primitives.md`.

### Candidate 4 — `These<This, That>` (inclusive-or)

**What it is.** `These<A, B>` extends Either with a "both" case:

```swift
public enum These<This: ~Copyable & ~Escapable, That: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    case this(This)
    case that(That)
    case both(This, That)
}
```

Algebraically `These a b ≡ A + B + (A × B)` — survey Q1.5 notes this
verbatim. Conformance ladder mirrors Either's. Functor surface generalizes
bimap to ternary fold (`fold(this:that:both:)`).

**Prior art.** Haskell `these` package, version 1.2.1 (`[Verified: 2026-05-08]`
in survey Q1.5). PureScript `Data.These`. Scala cats `Ior`. Used in:
`semialign.align` (outer-join over lists/streams), `Validation`-style
accumulating-error monads, and outer-join SQL-translation libraries
(`relational-algebra-haskell`).

**Contextualization in Swift.** The survey already concludes (Q1.5) that
the institute ecosystem has no documented `These` consumer. Re-checking as
of 2026-05-10:

* Validation accumulation: handled by `Parser.OneOf.Errors<each E>` (a
  *product* of errors, not an inclusive-or).
* Outer joins: no streaming consumer.
* Semialign / list alignment: not in any foundation.

The prior survey's recommendation (Q1.5): "do not add `These` to
swift-either-primitives. If a future need arises, it would warrant its own
`swift-these-primitives` package." That recommendation stands. The
[RES-018] check: zero current consumers; pretty-much-zero hypothetical
consumers; composition-fails fails ("just don't do it" is fine).

The case for `These`-in-Either-package is structurally weak: `These` is
*not* a binary coproduct — it is a coproduct of a coproduct and a product.
It is a different algebraic object. Putting it in
`swift-either-primitives` would muddle the package's identity (the binary
coproduct).

**Verdict: REJECT (don't add to this package).** If a consumer emerges,
ship as `swift-these-primitives` — sibling of either + pair, not a
modification of either. The clean disjoint-or is part of Either's value
proposition, and `These` muddies it. The forward-direction here is
*defensive*: preserve Either's identity by NOT absorbing `These`.

### Candidate 5 — `Validation<Failure, Success>` (semigroup-accumulating Either)

**What it is.** `Validation<E, A>` is structurally `Either<E, A>` but with
an `Applicative` instance that *accumulates* failures via a `Semigroup`
instead of short-circuiting:

```swift
public enum Validation<Failure: Semigroup, Success>: ~Copyable {
    case invalid(Failure)
    case valid(Success)
}

extension Validation {
    /// Combines two Validations: both valid → valid; either invalid → invalid;
    /// both invalid → invalid with semigroup-combined failures.
    public static func zip<A, B>(
        _ lhs: Validation<Failure, A>,
        _ rhs: Validation<Failure, B>
    ) -> Validation<Failure, (A, B)>
}
```

**Prior art.** Haskell `validation` package (1.1.3); Scala cats `Validated`
(verified in survey Q1.3 transitively); F#'s `Result.Apply` extensions in
`FsToolkit.ErrorHandling`. The defining feature is the `Apply` /
`Applicative` instance that combines errors via `Semigroup`. The same
feature is *why* `Validation` is not just an `Either` newtype — its monad
instance is intentionally absent (it would force short-circuit semantics,
defeating the purpose).

**Contextualization in Swift.**

This is the most interesting candidate in the list. The Swift Institute
ecosystem has *one* validation accumulation site:
`Parser.OneOf.Errors<each E>` (parameter-pack product of errors). That is
*not* `Validation`-shaped — it is a product, not a coproduct-with-
accumulation. The semantics are different: `OneOf.Errors` accumulates
because *every alternative failed*; `Validation` accumulates because
*every step accumulated its own error*.

The legal-encoding side (rule-law / rule-institute) has stronger validation
accumulation patterns — multi-rule legal validation naturally accumulates
errors. But that surface is in flux (per CLAUDE.md: "topology under
review"; legal skills moved to rule-institute on 2026-05-08).

Two routes:

**Route A — ship `Validation` in this package as a dual variant.**
Cost: the package identity blurs from "the binary coproduct" to "the
binary coproduct family". `Validation` is structurally the same data, with
a different `Apply` instance. Swift does not have `Apply` /
`Applicative` typeclasses, so the difference would manifest only in
free functions like `Validation.zip(_:_:)`, not in protocol conformance.
This dilutes the package's identity for an empty consumer surface.

**Route B — ship `swift-validation-primitives` separately (when a consumer emerges).**
[RES-018] check: zero current consumers; one foreseeable consumer
(rule-institute legal validation), but its shape is unstable. Defer until
shape stabilizes. The eventual package would depend on `Algebra.Semigroup`,
which lives at
`swift-primitives/swift-algebra-semigroup-primitives/Sources/Algebra Semigroup Primitives/Algebra.Semigroup.swift`
`[Verified: 2026-05-10]` (relocated from `swift-algebra-magma-primitives`
the same day). Infrastructure gate is satisfied; the remaining defer driver
is consumer-stability only.

**Route C — express Validation via Either + a free `Either.zip` overload conditioned on `Left: Semigroup`.**
This is the lightest-weight path. `extension Either where Left: Semigroup`
adds a `static func zip<A, B>(...)` that combines failures. The
semantic difference (validation vs. Either) is encoded in the `where`
clause, not a new type. Pros: no new package; cost is one extension and
a (now-permitted) dep on `swift-algebra-semigroup-primitives` (post-split)
or `swift-algebra-magma-primitives` (pre-split). Cons: the `Validation`
semantic is implicit (the user must remember `zip` short-circuits when
called as a method but accumulates when used as the static
`where Left: Semigroup` overload — confusing). The semantic-conflation
cost is the dominant rejection reason, not infrastructure availability.

**Either-vs-typed-throws nuance.** Typed throws short-circuits by
construction. `Validation` exists *because* typed throws / monadic Either
short-circuits. So typed throws does *not* subsume `Validation`. `Validation`
is the answer when you want to keep going and accumulate.

**Verdict: DEFER.** The structural answer is Route B (separate
`swift-validation-primitives`). Gate (a) — consumer-surface stability —
is the sole remaining defer driver. Gate (b) — Semigroup infrastructure —
is already satisfied (existing in `swift-algebra-magma-primitives` today;
relocating to `swift-algebra-semigroup-primitives` per parallel split).
Track via the rule-institute legal-validation work; if a second non-legal
consumer appears, the [RES-018] gate opens. Until then, do not absorb
into either-primitives.

### Candidate 6 — n-ary `Coproduct<each T>` / `OneOf<each T>`

**What it is.** A variadic-generic enum representing a coproduct of N
arbitrary types:

```swift
public enum OneOf<each Element>: ~Copyable {
    case value(/* one of each Element */)
}
```

This subsumes `Either<A, B>`, the right-associative nesting
`Either<A, Either<B, C>>`, and arbitrary N-ary sums in one type.

**Prior art.** F# `Choice<T1,…,T7>` (survey Q6.4) — manually replicated up
to arity 7. TypeScript union types `A | B | C` (structural; not nominal).
Scala 3 union types `A | B | C` (Q1.6) — structural. Rust crates: `frunk`
HList / Coproduct. Haskell `Data.HCons` and `OpenSums`-style libraries.
`[Verified: 2026-05-10]` against `docs.rs/frunk/latest/frunk/coproduct/index.html`.

**Contextualization in Swift.** Survey takeaway 2 is unchanged: variadic
generic enums are blocked at the language level. Compiler diagnostic
`enum_with_pack` reads "enums cannot declare a type pack" with a
"Temporary limitations" comment in `test/Generics/variadic_generic_types.swift`.
**No proposal, no PR, no feature flag** as of 2026-05-10. Re-checking the
Swift evolution proposals index since the prior survey: SE-0530 (Async
Result Support) is in active review (Apr 28 – May 12, 2026); does not
touch variadic enums. No newer parameter-pack proposal opens the door.
`[Verified: 2026-05-10]` against `github.com/swiftlang/swift-evolution/tree/main/proposals` index list.

If/when `OneOf<each T>` becomes possible, the migration is:

* `Either<A, B>` becomes a typealias for `OneOf<A, B>` (or stays as a
  binary specialization for ergonomics — the `.left` / `.right` case
  names are nicer than `OneOf<A, B>.value(...)` projections).
* `swift-either-primitives` either (a) absorbs `OneOf` (rename to
  `swift-coproduct-primitives`?) or (b) stays as the binary specialization
  and a sibling package owns the variadic form.

**Verdict: DEFER (compiler-blocked).** Track via Features.def
(`VariadicEnum` flag would be the canary), the
`enum_with_pack` diagnostic, and the proposals index. When the language
opens this up, decide between absorbing-into-either-primitives vs. sibling-
package.

### Candidate 7 — Bifunctor laws as compile-time / property tests

**What it is.** Either is the canonical `Bifunctor` instance (survey
Q1.2). The bifunctor laws — `bimap id id ≡ id` (identity) and `bimap (f₁ . f₂) (g₁ . g₂) ≡ bimap f₁ g₁ . bimap f₂ g₂` (composition) — are
provable structurally by case analysis. They could ship as:

* swift-testing cases that assert the laws on Int / String instantiations.
* DocC prose statements citing structural correctness.
* (Hypothetical) a `Bifunctor` protocol in `swift-bifunctor-primitives`.

**Prior art.** Haskell `Data.Bifunctor` documents the laws in the class
documentation comment but does not test them in `base` (the laws are
treated as obligations on instance authors). QuickCheck-style libraries
test them per-instance. Cats (Scala) ships law-test scaffolding via
`cats-laws`.

**Contextualization.** Adding swift-testing cases for the laws is cheap
and useful — they catch regressions in the implementation (e.g., a future
optimization that breaks identity for some payload types). The package
already has 65/65 tests passing on triple-toolchain (per
`escapable-arm-support.md`). Adding three or four bifunctor-law tests is
additive, ~30 LOC.

A `Bifunctor` protocol is a separate question — that is a
`swift-bifunctor-primitives` design, with [RES-018] gate (Pair would be
the second consumer; that meets the floor but is a thin floor).

**Verdict: ADOPT (tests only).** Add swift-testing cases under
`Tests/Either Primitives Tests/Either+BifunctorLaws.swift` covering
identity and composition. No production code change. Defer the
`Bifunctor` protocol pending a third consumer.

### Candidate 8 — Distributive / strength morphisms (`factor_first`, `factor_ok`)

**What it is.** Rust's `either` crate provides `factor_first`,
`factor_second`, `factor_ok`, `factor_err`, `factor_none` — five
distributive-law witnesses (Q6.1 of the survey).

**Prior art.** Rust `either::Either` (verified 2026-05-08 in survey).
Haskell does not provide them in `Data.Either` directly but they are
trivially derivable. Categorically these are the strength of the coproduct
functor over the product structure of the underlying category.

**Contextualization.** This is essentially Candidate 3 in another guise.
Same verdict: zero current consumers; if foundation-layer use emerges,
ship as Pair-side or distributivity-side, not Either-side.

**Verdict: REJECT (subsumed by Candidate 3).**

### Candidate 9 — `partitionEithers` / `lefts` / `rights` collection operations

**What it is.** Free functions over `[Either<L, R>]`:

```swift
extension Sequence {
    public func lefts<L, R>() -> [L] where Element == Either<L, R>
    public func rights<L, R>() -> [R] where Element == Either<L, R>
    public func partition<L, R>() -> (lefts: [L], rights: [R]) where Element == Either<L, R>
}
```

**Prior art.** Haskell `Data.Either` provides `lefts`, `rights`,
`partitionEithers` (survey Q6.2). Scala cats provides `partitionMap`. Rust
`Iterator::partition_map` is the analogue. The 2020 Swift Forums thread
(survey Q3.3) explicitly cited boilerplate-elimination from this pattern as
a motivator for a stdlib `Either`.

**Contextualization in Swift.**

* This is a `Sequence` extension. `swift-either-primitives` does not
  depend on Sequence-related primitives, and adding such a dep crosses a
  layer boundary (Either is a tier-0 primitive; Sequence operations are
  collection-tier).
* The natural home is `swift-collection-primitives` (when extended for
  Either) or a foundation-layer sequence package that already imports
  Either.
* Requires `Array` allocation, which is not an either-primitives concern.

[RES-018] check: zero consumers in the institute today; the 2020 Swift
Forums motivation is hypothetical institute-side. Composition-fails: no —
a consumer can write `let lefts = sequence.compactMap { $0.left }` in two
lines.

**Verdict: REJECT (wrong package).** Document in DocC as a recipe
("`compactMap { $0.left }` recovers `lefts`"). If a foundation site needs
the operation often enough to motivate dedicated functions, ship in
`swift-array-primitives` or `swift-collection-primitives` extensions, not
here.

### Candidate 10 — Bidirectional `Result<S, F>` ↔ `Either<F, S>` interop

**What it is.** Initializers:

```swift
extension Either where Left: Swift.Error {
    public init(_ result: Result<Right, Left>)
}
extension Result where Failure == Left /* + Either-shaped extension */ {
    public init(_ either: Either<Failure, Success>)
}
```

**Prior art.** Rust `either` crate: `From<Result<R, L>> for Either<L, R>`
and `From<Either<L, R>> for Result<R, L>` (survey Q6.1, point 5). No
Haskell analogue (Haskell does not have a built-in `Result`-shaped type
distinct from `Either`).

**Contextualization in Swift.** Either's `where Left: Swift.Error`
extension already conforms `Either: Swift.Error`. Adding a constructor
from `Result` is mechanically straightforward. The reverse direction
(`Result(_ either: Either)`) is also straightforward but requires
`extension Result` in this package, which crosses a stdlib-extension
boundary that institute primitives have so far avoided ([API-NAME-001] /
spec-mirroring rules say `Result` is stdlib's spec, not ours).

The asymmetry: Result is stdlib-asymmetric (success-side is
`Failure: Error`-bounded); Either is symmetric. The conversion
`Either<E, A> → Result<A, E>` requires `E: Error`. Going the other way
(`Result<A, E> → Either<E, A>`) requires nothing. Both directions are
useful: SE-0413 (typed throws) gives consumers `Result<Success, Failure>`
in catch-blocks via `init(catching:)`, and converting that to an
`Either<Failure, Success>` for use in a `throws(Either<...>)` clause is a
real ecosystem pattern (cf. `api-design-property-leverage.md` Existing
Call Sites Inventory: 14+ `throws(Either<...>)` sites today).

[RES-018] check: 14+ existing consumers using `throws(Either<L, R>)` —
many of them produce `Result`-shaped intermediate values. The
composition-fails check flags real friction here: a consumer writing
`Result(catching: ...).map(...)` and wanting to feed the result into a
`throws(Either<...>)` site has to write a 5-line `switch`. A constructor
removes that.

**Verdict: ADOPT (one direction only).** Ship
`extension Either where Left: Swift.Error { public init(_ result: Result<Right, Left>) }`
in a follow-up release post-0.1.0. **Reject** the reverse direction
(`Result.init(_ either: Either)`) because it requires extending stdlib
Result; instead, document the equivalent `either.fold(left: { Result.failure($0) }, right: { Result.success($0) })`
as the institute-side pattern. Additive change; no breaking effect.

### Candidate 11 — Typed throws (SE-0413) cannibalisation

**The central question.** Does Swift's typed throws subsume Either's
error-channel role? If so, what is left for Either to do?

**SE-0413 status (verified 2026-05-10).** Implemented in Swift 6.0 (Q3 of
the prior survey). SE-0530 (Async Result Support) is in active review (Apr
28 – May 12, 2026), expanding `Result.init(catching:)` to async; does not
remove Either's role. No newer typed-throws-related proposal in flight as
of 2026-05-10 against the proposals index.
`[Verified: 2026-05-10]` against
`github.com/swiftlang/swift-evolution/tree/main/proposals`.

**The cannibalisation argument (the strong form).**

```swift
// Pre-typed-throws era:
func parse() -> Either<ParseError, Document>

// Typed-throws era:
func parse() throws(ParseError) -> Document
```

The second form is strictly cleaner: it integrates with `try`, `catch`,
`do`, async, the stdlib `Result.init(catching:)`. There is no role for
Either in the *single-error-domain return-channel* use case.

**The remaining roles for Either (the answer).**

Survey Q4 inventories existing institute use; the load-bearing finding is
`api-design-property-leverage.md`'s 14+ `throws(Either<L, R>)` sites
across 7 packages. These all share a structural feature: **the function
genuinely throws TWO different error types**. Concretely:

* `Parser.Skip.First.Failure = Either<P0.Failure, P1.Failure>` — two
  different parsers, each with its own error type.
* `POSIX.Kernel.File.Handle.writeAll throws(Either<Error, Interrupt>)` —
  a domain error and a cross-cutting interrupt.
* `Pool.Bounded.Acquire async throws(Either<Pool.Lifecycle.Error, E>)` —
  a pool error and a caller-supplied error.

Typed throws REQUIRES a single error type: `throws(E)` where `E: Error`.
When you have *two* error types, you must combine them — and the
combination is precisely a binary coproduct: `throws(Either<E1, E2>)`.
SE-0413 itself acknowledges this verbatim (survey Q3.1, Mention 1):

> "one could use a suitable `Either` type under the hood: `func doSomething() throws(some Error)`"

**Conclusion: typed throws does NOT cannibalise Either.** They are
**complementary**:

| Use case | Tool |
|----------|------|
| Single error domain | `throws(E)` directly |
| Two-or-more error domains in one throw site | `throws(Either<E1, E2>)` (or right-nested for N ≥ 3) |
| Validation accumulation across steps | `Validation<Semigroup, Success>` (not Either; see Candidate 5) |
| Symmetric-disjunction return value (no privileged failure side) | `-> Either<L, R>` |
| Asymmetric success/failure return value | `-> Result<S, F>` |

The institute already uses Either correctly: as the *combinator* over
multiple error types in typed-throws clauses, plus as a return-channel
for symmetric disjunctions (parser cases, classifier outputs). No
cannibalisation.

**The forward-direction implication.** Document this complementarity
explicitly in DocC. The current Either.swift doc-comment already gestures
at it ("For the error-channel variant where one side is privileged as
'the failure', the standard library's `Result<T, E>` is the right tool")
but does not articulate the typed-throws-multi-domain role, which is the
14+-site reality. Strengthen the doc.

**Verdict: ADOPT (DocC update).** Add a "Either vs. Result vs. typed
throws" section to the package DocC. Cite the 14+ existing sites as
evidence of the complementary role. Include the truth table above.
Additive, no production code change.

### Candidate 12 — Parameter packs in enums (n-ary Either)

Subsumed by Candidate 6. **Verdict: DEFER (compiler-blocked).**

### Candidate 13 — `Uninhabited` protocol conformance reservation

**What it is.** SE-0413 §Alternatives Considered references an
`Uninhabited` protocol that does not exist in the stdlib (survey Q3.1,
Mention 3). The proposal explicitly anticipates:

```swift
extension Either: Uninhabited where Left: Uninhabited, Right: Uninhabited {}
```

**Status as of 2026-05-10.** No `Uninhabited` protocol in the stdlib.
No SE proposal in review or implementation. Searching swift-evolution
proposals index for `Uninhabited` returns no proposal file. The reference
in SE-0413 is a future-direction signal, nothing more.
`[Verified: 2026-05-10]` against the proposals index.

**Contextualization.** When/if `Uninhabited` lands, the conditional
conformance is a one-line addition. The package's `Either where Left ==
Never` and `where Right == Never` extensions already exhibit the pattern
specialized to `Never` (the canonical uninhabited type).

**Verdict: DEFER (track upstream).** Reserve the conformance slot
mentally; no action today. When SE proposes `Uninhabited`, add the
conditional conformance in the same release.

## Outcome

### Verdicts

| # | Candidate | Verdict | Cost / Trigger |
|---|-----------|---------|----------------|
| 1 | Associativity (`assocL` / `assocR`) | **REJECT** | No consumer; document categorically only |
| 2 | Commutativity round-trip test | **ADOPT (test only)** | ~10 LOC swift-testing |
| 3 | Distributivity (`distributed`) | **REJECT** | Wrong package; revisit if foundation-layer site appears |
| 4 | `These<This, That>` | **REJECT** | Different algebra; preserve Either's identity. Future `swift-these-primitives` if consumer appears |
| 5 | `Validation<Failure, Success>` | **DEFER** | Future `swift-validation-primitives` when (a) consumer stabilizes (b) `Semigroup` lands |
| 6 | n-ary `OneOf<each T>` | **DEFER** | Compiler-blocked (variadic enums); track Features.def + proposals |
| 7 | Bifunctor-law tests | **ADOPT (test only)** | ~30 LOC swift-testing |
| 8 | Strength / `factor_*` morphisms | **REJECT** | Subsumed by #3 |
| 9 | `partitionEithers` / `lefts` / `rights` | **REJECT** | Wrong package (collection layer) |
| 10 | `Either(_ result: Result)` | **ADOPT (post-0.1.0)** | ~5 LOC; one-direction only |
| 11 | Typed-throws complementarity DocC | **ADOPT (DocC update)** | Document the complementary roles; cite 14+ existing sites |
| 12 | Parameter packs in enums | **DEFER** | Compiler-blocked (subsumed by #6) |
| 13 | `Uninhabited` conformance | **DEFER** | Upstream-blocked (SE not pitched) |

**Summary by verdict class:**

* **ADOPT (post-0.1.0, additive)**: 4 candidates
  — #2 (round-trip test), #7 (bifunctor laws tests), #10 (Result init), #11 (DocC strengthen).
  Combined cost: ~50 LOC tests + 1 init + DocC prose. Zero breaking change.
* **DEFER (track upstream)**: 4 candidates
  — #5 Validation (consumer + algebra-primitives), #6 OneOf (variadic
  enums), #12 (subsumed), #13 Uninhabited (SE proposal).
* **REJECT**: 5 candidates
  — #1 (no consumer), #3 (wrong package), #4 (preserve identity),
  #8 (subsumed by #3), #9 (wrong package).

### Top 3 highest-value forward directions

1. **#11 — Typed-throws complementarity DocC**. The single
   highest-leverage change. The 14+ existing `throws(Either<...>)` sites
   prove that typed throws and Either are complementary; explicit DocC
   articulation of this is what makes the package's identity defensible
   against "isn't Either obsolete now that we have typed throws?" The
   answer is no, and the package should say so explicitly.

2. **#10 — `init(_ result: Result<Right, Left>)`**. Removes real
   friction at the typed-throws-multi-domain boundary. Consumers writing
   `Result(catching: ...)` and feeding into `throws(Either<...>)` sites
   currently pay 5 lines per site; this constructor reduces it to one.
   Mechanical, additive, post-0.1.0.

3. **#5 — `swift-validation-primitives` (deferred)**. The single most
   interesting future package extraction. Validation is the answer to
   "we have typed throws; what else does the binary-coproduct family
   need to express?" — error accumulation across steps. The deferral is
   warranted (consumer surface unstable, `Semigroup` not in primitives
   yet), but the trigger conditions are concrete and trackable.

### Either-vs-typed-throws verdict

**Complementary, not cannibalising.** Typed throws (SE-0413) supersedes
Either for *single*-error-domain return channels, where it strictly wins
(integration with `try` / `catch` / `async` / stdlib Result). Either's
durable role is the *multi*-error-domain combinator: `throws(Either<E1, E2>)`
and right-nested forms when 3+ domains compose. Plus the symmetric-
return-value role (parser branch, classifier output) where neither side
is privileged as failure. SE-0413 itself acknowledges Either as the
under-the-hood mechanism for opaque multi-domain throws (survey Q3.1).
The 14+ existing institute sites are the empirical proof. **The package's
identity is durable; document it.**

### `These` / `Validation` verdict

**Separate packages, not part of either-primitives.**

* **`These<This, That>`** — REJECT for either-primitives. Algebraically
  it is a coproduct of a coproduct and a product (`A + B + (A × B)`), not
  a binary coproduct. Belongs in `swift-these-primitives` if and when a
  consumer emerges (currently zero institute consumers; the survey Q1.5
  finding is unchanged at 2026-05-10).
* **`Validation<Failure, Success>`** — DEFER for any package. The
  semantic difference (accumulating-Apply vs. short-circuiting-Monad)
  cannot be expressed without a `Semigroup` protocol, which does not
  yet exist in institute primitives. The eventual home is
  `swift-validation-primitives`, gated on (a) `Semigroup` landing in
  `swift-algebra-primitives` (or wherever it lands), (b) a consumer
  stabilizing — most likely rule-institute legal validation, but that
  topology is in flux per CLAUDE.md.

### Decisions requiring user authorization before adoption

None of the ADOPT items in the table block 0.1.0; all are additive and
post-0.1.0. However, two items want explicit user/principal sign-off
before scheduling:

1. **#11 DocC strengthening** — the framing "Either is complementary to
   typed throws, not subsumed" is a *positioning* claim that affects how
   the package is announced (forums review, blog, README). User should
   confirm the framing matches their intended public stance before the
   DocC text lands.

2. **#10 `init(_ result: Result)`** — additive, but it pulls
   `Swift.Result` into the package's public API surface (via the
   `Left: Swift.Error` constraint plus stdlib `Result` reference). Per
   [PRIM-FOUND-001] this is fine (Result is stdlib, not Foundation), but
   the package has so far avoided cross-stdlib-type interop. User should
   confirm the institute is comfortable taking on this stdlib-interop
   surface here vs. in a foundation-layer adapter package.

The DEFER items (#5, #6, #13) require no immediate authorization; their
trigger conditions are external (compiler progress, SE proposals,
consumer emergence).

## References

### Internal (institute)

* `swift-either-primitives/Research/either-academic-and-ecosystem-survey.md`
  v1.0.0 (2026-05-08, COMPLETE) — load-bearing prior art for Q1–Q7.
* `swift-either-primitives/Research/api-design-property-leverage.md`
  v1.0.0 (2026-05-08, RECOMMENDATION) — current call-site shape; 14+
  consumer sites inventoried.
* `swift-either-primitives/Research/escapable-arm-support.md`
  v1.0.0 (2026-05-09, DECISION) — operationalized ~Escapable cohort.
* `swift-institute/Research/escapable-support-pair-either-product.md`
  v1.1.0 (2026-05-09, DECISION) — ecosystem-wide ~Escapable cohort.
* `swift-institute/Research/typed-throws-mixed-error-domains.md`
  v1.0.0 (2026-03-03, RECOMMENDATION) — multi-error-domain typed-throws
  pattern; cites Either as the combinator.
* `swift-institute/Research/algebra-adt-package-relationship.md` —
  algebra-primitives ADT relationships (referenced for hypothetical
  `Semigroup` placement).

### Swift Evolution (verified against
`github.com/swiftlang/swift-evolution/tree/main/proposals` index, 2026-05-10)

* SE-0413 (Typed throws, implemented Swift 6.0) — verbatim Either
  references re-verified `[Verified: 2026-05-10]`. Three load-bearing
  mentions cataloged in survey Q3.1.
* SE-0426 (BitwiseCopyable, implemented Swift 6.0).
* SE-0427 (Noncopyable Generics, implemented Swift 6.0) — Either example
  in Alternatives Considered.
* SE-0437 (Noncopyable stdlib primitives, implemented Swift 6.0) —
  Optional / Result `~Copyable`.
* SE-0446 (Nonescapable types, implemented Swift 6.2).
* SE-0499 (institute-protocol collapse, Swift 6.4) — drives
  Equation/Hash/Comparison conformance ladder.
* SE-0530 (Async Result Support, Active Review Apr 28 – May 12, 2026)
  `[Verified: 2026-05-10]` — does not affect Either's design space.
* No `Uninhabited` SE proposal exists `[Verified: 2026-05-10]` —
  candidate #13 deferred upstream.
* No variadic-generic-enum SE proposal exists `[Verified: 2026-05-10]` —
  candidate #6 / #12 deferred upstream.

### External

* Haskell `bifunctors` package, `Data.Bifunctor.Swap`
  `[Verified: 2026-05-10]`
  (`hackage.haskell.org/package/bifunctors/docs/Data-Bifunctor-Swap.html`).
* Haskell `validation` package — version 1.1.3, `Data.Validation`
  `[Verified: 2026-05-10 via metadata; instance laws documented].`
* Haskell `these` package, version 1.2.1 — referenced via prior survey
  Q1.5 `[Verified: 2026-05-08]`; no change at 2026-05-10.
* Rust `frunk` crate — Coproduct / HList variadic generics
  `[Verified: 2026-05-10]` (`docs.rs/frunk/latest/frunk/coproduct/index.html`).
* Rust `either` crate v1.15.0 — referenced via prior survey Q6.1
  `[Verified: 2026-05-08]`; factor_*, From<Result> impls.
* Scala cats `Validated`, `Ior` — referenced via prior survey
  `[Verified: 2026-05-08]`.
* nLab "coproduct" — referenced via survey Q1.1 `[Verified: 2026-05-08]`.

### Verification spikes

None for this document — all candidates analyzed in prose against prior
empirical work. The `~Escapable` empirical reproduction at
`Experiments/escapable-arm-support/` covers the lifetime-related
constraints that limit candidates with closure-bearing methods (Gap A).
