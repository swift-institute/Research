# Pair Primitives — Future Directions

<!--
---
version: 1.1.0
last_updated: 2026-05-10
status: RECOMMENDATION
tier: 2
scope: per-package
---

## Changelog
- v1.1.0 (2026-05-10): A2 (Distributivity) and A4-Either-variant (sequence
  over Either) home resolved — both ship in a new L1 sibling
  `swift-bifunctor-primitives` per a 2026-05-10 framework pass
  (canonical-authority + dep-direction + [RES-018] consumer gate +
  strict-mission). Earlier verdicts left the home open; the framework
  selected a deliberate micro-package opening a categorical-structure
  family separate from algebra-*-primitives. Tracked via
  `HANDOFF-bifunctor-primitives.md`. pair-primitives and either-primitives
  stay orthogonal sibling peers.
- v1.0.0 (2026-05-10): Initial Tier 2 forward-directions audit. Extends
  pair-prior-art-survey.md (REFERENCE, 2026-05-08) with category-theory
  totality candidates (associativity, distributivity, strength, traverse,
  zip, applicative, projection, swap-fusion) and a Swift-Evolution
  forward-pass against proposals SE-0470 / SE-0488 / SE-0492 / SE-0494 /
  SE-0499 / SE-0503 / SE-0507 / SE-0515 / SE-0517 / SE-0518 / SE-0521 /
  SE-0527 / SE-0528 / SE-0530. 14 candidates analyzed; 4 ADOPT, 5 DEFER,
  5 REJECT. All recommendations are additive — no break to the imminent
  0.1.0 surface.
-->

## Context

`swift-pair-primitives` ships its 0.1.0 release (the binary categorical
product `Pair<First, Second>` with `~Copyable & ~Escapable`-generic stored
fields, Bifunctor surface — `map(first:)`, `map(second:)`, `map(first:second:)`,
`apply`, `swapped` — and conditional conformances for institute
`Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol` plus stdlib
`Equatable`/`Hashable`/`Comparable`/`Codable`). The current API is verified
against
[`Sources/Pair Primitives/Pair.swift:23`](../Sources/Pair%20Primitives/Pair.swift),
which is the `@frozen public struct Pair<First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable>: ~Copyable, ~Escapable`
declaration.

This document is the forward-directions audit for what comes *next*, after
the initial release. It is **additive only** — every recommendation can
ship as a non-breaking minor-version addition; nothing here blocks tomorrow's
publish. Two angles are combined:

1. **Type-theory / category-theory totality** — given Pair is the binary
   categorical product (dual to either's coproduct), what is the closure of
   "totally implemented"? Swap, associativity, distributivity over sum,
   strength/traverse, zip, applicative shape, n-ary generalization, labeled
   variants, and the relationship to `These` / `And`.

2. **Swift Evolution forward-pass** — proposals accepted or in-review during
   late 2025 / early 2026 that change what `Pair` can express. Borrow/mutate
   accessors (SE-0507), suppressed associated types with defaults (SE-0503),
   `~Sendable` (SE-0518), `isTriviallyIdentical` (SE-0494), `BitwiseCopyable`,
   `InlineArray`, lifetime annotations, regions / `sending`, isolated
   conformances (SE-0470).

Per [RES-019], the existing prior-art survey
([`pair-prior-art-survey.md`](pair-prior-art-survey.md), REFERENCE, 2026-05-08)
is the foundation; this doc extends rather than duplicates. References that
are already verified inline there (Haskell `Data.Bifunctor` / `Data.Tuple`
surface, Hackage signatures, Wikipedia categorical-product universal property,
Kotlin `Pair`, Rust tuples, SE-0015 / SE-0283 / SE-0427 / SE-0429 / SE-0432 /
SE-0446) are cited by short reference rather than re-verified here.

## Question

For each candidate forward direction (type-theory totality gaps + Swift-
Evolution-enabled shapes), what should `swift-pair-primitives` adopt, defer,
or explicitly reject?

---

## Analysis

Each candidate is enumerated independently. Within each: **What it is**
(concrete API sketch or theoretical position), **Prior art** (canonical
sources), **Contextualization** (per [RES-021] — what this looks like in
Swift's type system, and what it costs), **Verdict** (ADOPT / DEFER / REJECT
with rationale).

The candidates are grouped: §A category-theoretic totality, §B Swift-Evolution
forward-pass.

---

### §A — Category-theoretic totality

#### A1. Associativity isomorphisms (`assocL` / `assocR`)

**What it is.** The categorical product is associative up to canonical
isomorphism: `(A × B) × C ≅ A × (B × C)`. Concretely:

```swift
extension Pair {
    /// Re-associates left: `Pair<A, Pair<B, C>>` → `Pair<Pair<A, B>, C>`.
    public static func assocL<A: ~Copyable, B: ~Copyable, C: ~Copyable>(
        _ pair: consuming Pair<A, Pair<B, C>>
    ) -> Pair<Pair<A, B>, C> where First == A, Second == Pair<B, C> { … }

    /// Re-associates right: `Pair<Pair<A, B>, C>` → `Pair<A, Pair<B, C>>`.
    public static func assocR<A: ~Copyable, B: ~Copyable, C: ~Copyable>(
        _ pair: consuming Pair<Pair<A, B>, C>
    ) -> Pair<A, Pair<B, C>> where First == Pair<A, B>, Second == C { … }
}
```

**Prior art.** Standard categorical fact (Awodey §2.6, Mac Lane §III.5; via
Wikipedia [Product (category theory)] [Verified: 2026-05-10]). Haskell does
not provide named `assocL`/`assocR` for the `(,)` instance; users write the
move inline because the language-level tuple makes it nominally free
(`\((a, b), c) -> (a, (b, c))`).

**Contextualization.** In Swift the move is *not* free for `~Copyable` Pair
because `Pair<Pair<A, B>, C>` and `Pair<A, Pair<B, C>>` are distinct nominal
types with no implicit conversion. A `consuming` static function is the right
shape. The cost is two methods plus their tests; the benefit is making
HList-style cons-pair encodings ergonomic without bespoke unwrapping at every
call site. Consumers cobbling pair-of-pair shapes today either use
`apply { a, bc in apply(bc) { b, c in Pair(Pair(a, b), c) } }` (correct but
noisy) or roll the move themselves. The `~Escapable` admits-both-arms shape
matches `swapped` precisely (see `Pair.swift:192`); the implementation should
mirror it.

**Verdict: ADOPT** (post-0.1.0, additive). Low cost, mechanical implementation,
direct payoff for any consumer doing nested-pair encoding. Symmetric with the
existing `swapped`. No proposal needed beyond this document.

---

#### A2. Distributivity over `Either` (`distribute` / `factor`)

**What it is.** Products distribute over coproducts up to canonical iso:
`A × (B + C) ≅ (A × B) + (A × C)` and the symmetric form `(A + B) × C ≅
(A × C) + (B × C)`.

```swift
// In swift-pair-primitives, with cross-package dep on swift-either-primitives.
extension Pair where Second: ~Copyable & ~Escapable {
    /// Distribute: `Pair<A, Either<B, C>>` → `Either<Pair<A, B>, Pair<A, C>>`.
    public static func distribute<A: ~Copyable, B: ~Copyable, C: ~Copyable>(
        _ pair: consuming Pair<A, Either<B, C>>
    ) -> Either<Pair<A, B>, Pair<A, C>>
        where First == A, Second == Either<B, C> { … }
}

extension Pair {
    /// Factor (inverse of distribute, when the `A` in both arms is duplicable):
    /// `Either<Pair<A, B>, Pair<A, C>>` → `Pair<A, Either<B, C>>`.
    public static func factor<A: Copyable, B: ~Copyable, C: ~Copyable>(
        _ either: consuming Either<Pair<A, B>, Pair<A, C>>
    ) -> Pair<A, Either<B, C>> { … }
}
```

**Prior art.** Standard categorical fact; Haskell's `distributive` package
captures the dual flavor (`Distributive` typeclass on functors), and `cats`
in Scala provides `Distributive[F]`. The Pair-Either flavor is the original
categorical statement — `distribute` is universally available wherever both
product and sum constructors exist (Idris `Prelude.Either`, Lean `Sum.elim`,
PureScript `Data.Either`). No language ships these as named library
functions on tuples specifically because tuple+sum manipulation is usually
unrolled by pattern match.

**Contextualization.** `distribute` is straightforward to implement under the
current `Pair` and `Either` shapes (both are `~Copyable & ~Escapable` — see
[`Either Primitives/Either.swift`](../../../swift-either-primitives/Sources/Either%20Primitives/Either.swift)).
`factor`, however, is *only* total when `A` is `Copyable`, because the inverse
direction needs to "share" the `A` between the two cases — a duplication that
~Copyable forbids. This is an instructive asymmetry: `distribute` is total in
the linear-logic tensor sense; `factor` is not. The Pair package currently has
**no** dependency on `swift-either-primitives`; introducing one makes the two
packages cross-link.

**Cross-package implication.** This is type-level categorical content
that knows about both Pair and Either. Per a 2026-05-10 framework pass
(canonical-authority + dep-direction + [RES-018] consumer gate +
strict-mission), the home is a new L1 sibling
**`swift-bifunctor-primitives`** — a deliberate micro-package opening
a categorical-structure package family separate from algebra-*-primitives
(which is value-level algebra). The new package depends downward on
pair-primitives and either-primitives; pair and either remain orthogonal
sibling peers. Earlier candidate homes — placing the bridge in either
sibling, or hosting it in `swift-algebra-law-primitives` — were rejected:
the former creates a dep cycle or breaks symmetry; the latter conflates
type-level categorical isos with value-level algebra-law verification
(algebra-law-primitives' actual mission is `check(...) -> Violation?`
harnesses over Collection samples, not iso witnesses).

**Verdict: ADOPT (deferred to post-0.1.0).** Home decided; ship gated on
either a real consumer surfacing or `swift-bifunctor-primitives` opening
deliberately. Tracked via `HANDOFF-bifunctor-primitives.md`. No
distributivity API ships in 0.1.0. **Cross-package implication: yes.**

---

#### A3. Projection-as-functions (`fst` / `snd` Haskell-style)

**What it is.** Free-function projections:

```swift
public func fst<First: ~Copyable, Second: ~Copyable>(
    _ pair: borrowing Pair<First, Second>
) -> First where First: Copyable { pair.first }

public func snd<First: ~Copyable, Second: ~Copyable>(
    _ pair: borrowing Pair<First, Second>
) -> Second where Second: Copyable { pair.second }
```

**Prior art.** Haskell `Data.Tuple` `fst`/`snd` (verified in
[`pair-prior-art-survey.md` §2.1](pair-prior-art-survey.md)). Rust uses field
access (`p.0`/`p.1`) and does not expose free functions. Swift's idiom is
member access throughout; KeyPath subsumes the lens-shape variant.

**Contextualization.** Pair already exposes `pair.first` and `pair.second`
as stored properties. Adding free functions duplicates surface for marginal
ergonomic gain — Swift programmers do not reach for free-function projections
the way Haskell programmers do because Swift's member-access syntax is
already concise. This violates [INFRA-*] reuse and adds top-level identifiers
that pollute the global namespace.

**Verdict: REJECT.** Member access is the Swift idiom; free-function
projections do not earn their keep. KeyPath (`\Pair<A, B>.first`,
`\Pair<A, B>.second`) is the lens-style equivalent and already works.

---

#### A4. Strength / `sequence` over `Optional` and `Result`

**What it is.** Strength is `(A, F<B>) → F<(A, B)>` for any functor `F`. The
two specializations of immediate Swift use are `Optional` and `Result`:

```swift
extension Pair where First: ~Copyable {
    /// Sequence the second component out of an Optional.
    /// `Pair<A, B?>` → `Pair<A, B>?`
    public static func sequence<A: ~Copyable, B: ~Copyable>(
        _ pair: consuming Pair<A, B?>
    ) -> Pair<A, B>? where First == A, Second == B? { … }
}

// Symmetric pair on the first component, plus Result variants.
```

**Prior art.** Haskell's `Data.Bitraversable` provides `bisequence` /
`bitraverse` / `firstA` / `secondA` (verified
[`pair-prior-art-survey.md` §1.3](pair-prior-art-survey.md)). PureScript `Data.Tuple`
has the equivalent. Scala `cats.Bitraverse` ships it.

**Contextualization.** This is the most-requested feature gap from prior-art
analysis ([`pair-prior-art-survey.md` Findings 6, 7](pair-prior-art-survey.md)).
For `Optional`, Swift's stdlib `Optional` is `~Copyable & ~Escapable` since
SE-0427 / SE-0446 — the signature is expressible. For `Result`, `Success` is
`~Copyable & ~Escapable`, `Failure: Error` is `Copyable` (per
[`Result.swift`](file:///Users/coen/Developer/swiftlang/swift/stdlib/public/core/Result.swift));
this is also expressible. SE-0499 (Implemented Swift 6.4) updates `Optional`'s
and `Result`'s `Equatable`/`Hashable` to support `~Copyable & ~Escapable` —
removing the last conformance friction at the consumption site.

The bottleneck is *generality*: a fully general `bitraverse :: Applicative f
=> (a -> f c) -> (b -> f d) -> p a b -> f (p c d)` requires HKT, which Swift
doesn't have. The pragmatic Swift expression is *N* concrete `sequence`
overloads — `Optional`, `Result`, `Either` — written by hand. Per [RES-021]
this is "expressible-but-without-the-elegance"; the right Swift shape is
*concrete overloads at known functors*, not a typeclass abstraction.

**Verdict: ADOPT** (post-0.1.0, additive). Concrete overloads ship in two
homes:

- **In `swift-pair-primitives` itself**: `sequenceFirst` / `sequenceSecond` ×
  `Optional` (4 methods). Optional is in stdlib; no cross-package dep.
- **In `swift-pair-primitives` (proposed) OR a stdlib-extensions home**:
  the Result variants. Per the institute's Either ↔ SLE Result interop
  pattern landed 2026-05-10, the SLE `~Copyable` Result is the right
  target; Result variants depend on `swift-standard-library-extensions`.
- **In `swift-bifunctor-primitives`** (the new L1 sibling per the A2 home
  decision, 2026-05-10): the **Either variant** of `sequence`. This is
  the cross-package piece — same home as A2's distributivity, same
  rationale (categorical-structure content that knows about both Pair and
  Either). pair-primitives stays orthogonal to either-primitives; the
  bridge lives one tier up the categorical-structure axis.

Tracked via `HANDOFF-bifunctor-primitives.md` for the Either variant; the
Optional/Result variants are pure additions to this package.

---

#### A5. Bifoldable / `bifold`

**What it is.** Per Haskell `Data.Bifoldable`:

```swift
extension Pair {
    public consuming func bifold<R: ~Copyable, E: Swift.Error>(
        first: (consuming First) throws(E) -> R,
        second: (consuming Second) throws(E) -> R,
        combine: (consuming R, consuming R) throws(E) -> R
    ) throws(E) -> R
}
```

**Prior art.** Hackage `bifunctors-5.6.3 / Data.Bifoldable` (verified
[`pair-prior-art-survey.md` §1.3](pair-prior-art-survey.md)).

**Contextualization.** Pair already exposes `apply` (`Pair.swift:180`), which
is structurally `(A, B) -> R` — a *binary* fold that lets the caller compose
the two values into `R` however they want, without imposing a separate
`combine` step. `bifold` is strictly less general than `apply` for the binary
case: it constrains both arm-handlers to the same return type and makes the
combination explicit. The "explicit combine" is a Haskell ergonomic for
pointfree composition — Swift code is neither pointfree nor monoid-driven;
the combine step is just a closure call.

**Verdict: REJECT.** `apply` subsumes `bifold` for the binary case. Adding
`bifold` would be net negative on API surface for marginal expressiveness.
This was already the conclusion in
[`pair-prior-art-survey.md` §7.2](pair-prior-art-survey.md);
this audit reaffirms it.

---

#### A6. Bizip / Applicative shape on Pair

**What it is.** "Bizip" is `Pair<F<A>, F<B>> → F<Pair<A, B>>`. For
`F = Optional`: "fail if either is nil". For `F = Result`: "first error
wins". For `F = [_]`: cartesian or zip-product.

```swift
// Optional bizip
extension Pair {
    public static func bizip<A: ~Copyable, B: ~Copyable>(
        _ pair: consuming Pair<A?, B?>
    ) -> Pair<A, B>? where First == A?, Second == B? { … }
}
```

**Prior art.** Haskell `Biapplicative` typeclass (named in `bifunctors`,
signatures partially blocked in
[`pair-prior-art-survey.md` §1.3](pair-prior-art-survey.md) — Hackage URL 404;
treated here as named-only). Scala cats `Bitraverse`'s `bisequence` covers it.

**Contextualization.** Bizip is a special case of A4 (`sequence`) where
*both* arms are wrapped in `F`. Once A4 ships, bizip can be expressed as
`sequenceFirst |> sequenceSecond` in two steps. For `F = Optional` the
dedicated form fuses the two None-checks — slightly tighter than the
two-step form, but the difference is one branch and the optimizer likely
flattens it. The marginal benefit does not justify the dedicated method;
A4's coverage is sufficient.

**Verdict: DEFER.** Re-evaluate after A4 ships and consumer feedback exists.
If a real call-site demonstrates the two-step pattern is awkward at scale, a
dedicated `bizip` is straightforward to add then.

---

#### A7. `These<A, B>` (sum-of-pair-with-sum, the "inclusive or")

**What it is.** Haskell's `Data.These` defines `These a b = This a | That b
| These a b` — three cases representing "A only", "B only", or "both". It is
neither pure product (Pair) nor pure sum (Either); it is a four-cases-minus-
empty mixture. Used heavily in alignment / merge / diff algebras.

**Prior art.** Hackage `these-1.2`, `Data.These`. Cats `Ior[A, B]` (inclusive-
or). Used in semialign-style libraries for ordered-merge algorithms.

**Contextualization.** This is a *new type*, not an addition to Pair. Per
[RES-018] the second-consumer / composition-fails check applies. There is no
current consumer in the institute ecosystem for `These`; the natural use cases
(ordered merge, semialign) are foundation-layer concerns, not L1 primitives.
Decoding `These` from `Either<Pair<A, B>, Either<A, B>>` works mechanically —
composition does not fail.

**Verdict: REJECT** as a swift-pair-primitives addition. If a real consumer
emerges, it lives in its own package (`swift-these-primitives`) at the
appropriate layer; not here. **Cross-package implication: would be a new L1
primitive, not an addition to Pair.**

---

#### A8. Tagged-Pair pattern (labeled pair via phantom type)

**What it is.** Apply `swift-tagged-primitives`-style phantom typing to Pair:
`Tagged<Tag, Pair<A, B>>` — or equivalently, named pairs via a phantom-typed
wrapper that adds field labels.

**Prior art.** Scala 3 named tuples (verified
[`pair-prior-art-survey.md` §2.2](pair-prior-art-survey.md), now non-experimental
since Scala 3.7); C# 7+ `(int A, int B)` syntax; Kotlin's data-class pattern.

**Contextualization.** Already expressible without pair-primitives changes:
`Tagged<MyTag, Pair<Int, String>>` works today. The "field labels" piece is a
Swift language gap (no nominal-tuple-with-labels), and no pair-primitives API
change would close it. Consumers wanting "named pairs" should declare a
dedicated struct (`struct Velocity { var direction: Vertical; var magnitude:
Double }`); Pair is the *unnamed* pair, by design.

**Verdict: REJECT** as a Pair API addition. Already-expressible via Tagged;
the actual gap is a Swift-language one outside the package's purview.

---

#### A9. n-ary generalization (relationship to `swift-product-primitives`)

**What it is.** A general `Tuple<each T>` for arbitrary arity. The sibling
`swift-product-primitives` already ships this as
[`Product<each Element>`](../../../swift-product-primitives/Sources/Product%20Primitives/Product.swift)
— a `@dynamicMemberLookup` wrapper around a tuple, with the n-ary product
shape.

**Prior art.** Swift parameter packs (SE-0393, SE-0398, SE-0408) — verified
[`pair-prior-art-survey.md` §4](pair-prior-art-survey.md). The empirical
limitation that `struct Tuple<each T: ~Copyable>: ~Copyable` is rejected with
"cannot suppress '~Copyable' on type 'each T'" was verified in that survey
and remains true on Swift 6.3.1 / 6.4-dev today.

**Contextualization.** Pair's *raison d'être* is the binary case with full
`~Copyable & ~Escapable` support. `Product<each T>` cannot match this until
the language gains `~Copyable` parameter packs (SE-0427 future direction,
unscheduled). The two packages are complementary, not competitive: Pair owns
the noncopyable-aware binary case; Product owns the n-ary copyable case.

The forward question: should Pair ship `init(_ product: Product<First, Second>)`
and `var product: Product<First, Second>` for the Copyable case? This is a
trivial bridge; the cost is a cross-package dep declaration on
`swift-product-primitives`. Bridge methods like this earn their keep when
consumers genuinely have a `Product<A, B>` value and want Pair's bifunctor
surface (or vice versa).

**Verdict: DEFER.** The bridge methods are mechanical and additive; they wait
for a real consumer call-site to motivate them. No design decision needed
upfront. **Cross-package implication: yes — a future Pair↔Product bridge
would add a dep edge swift-pair-primitives → swift-product-primitives.**

---

#### A10. Either symmetry — `~Copyable & ~Escapable` propagation already aligned

**What it is.** [`pair-prior-art-survey.md` Finding 7 / §3.5](pair-prior-art-survey.md)
flagged that Either was Copyable-only on 2026-05-08, while Pair was
`~Copyable`-aware. **Status update at 2026-05-10**: Either has since been
generalized; `swift-either-primitives/Sources/Either Primitives/Either.swift`
now declares
`public enum Either<Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable>: ~Copyable, ~Escapable`
[Verified: 2026-05-10]. The asymmetry is closed.

**Verdict: NO ACTION.** Recorded for completeness; the prior survey's
recommendation has already been actioned by the Either package. This row in
the verdict table is "already done", not a forward direction.

---

### §B — Swift Evolution forward-pass

#### B1. SE-0499 — `~Copyable`/`~Escapable` in simple stdlib protocols (Implemented Swift 6.4)

**What it is.** SE-0499 marks `Equatable`, `Comparable`, `Hashable`,
`CustomStringConvertible`, `CustomDebugStringConvertible`, `TextOutputStream`,
`TextOutputStreamable` as refining `~Copyable` and `~Escapable`.
`LosslessStringConvertible` refines `~Copyable`. Updates `Optional` and
`Result` `Equatable`/`Hashable` instances accordingly. Status: **Implemented
(Swift 6.4)** [Verified: 2026-05-10 via
`https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md`].

**Prior art.** N/A — this *is* the Swift Evolution forward direction.

**Contextualization.** The Pair package already accommodates SE-0499 via the
`#if swift(<6.4)` guard at
[`Pair.swift:60–72`](../Sources/Pair%20Primitives/Pair.swift): on 6.4+, the
institute `Equation.Protocol`/`Hash.Protocol`/`Comparison.Protocol` typealias
to their stdlib counterparts; on <6.4, both extensions are needed. This is
correct, but assumes the institute Equation/Hash/Comparison protocols
themselves have been generalized to `~Copyable & ~Escapable`. Once the
ecosystem fully drops 6.3 support, the `#if swift(<6.4)` block can be
removed and the `Pair: Equatable where First: Equatable, Second: Equatable`
shape collapses to a single conformance using stdlib `Equatable` directly,
generalized to `~Copyable & ~Escapable`.

**Verdict: ADOPT** (track for post-6.3-deprecation cleanup). No action
required for 0.1.0; eventual cleanup is a single-file diff. Forward pinned to
the date the ecosystem drops Swift 6.3.

---

#### B2. SE-0507 — Borrow and Mutate Accessors (Implemented Swift 6.4)

**What it is.** SE-0507 introduces `borrow` and `mutate` accessors for
computed properties and subscripts. Unlike `get`, they expose the underlying
value without copying; unlike `yielding borrow` / `yielding mutate`, they
don't pay coroutine overhead. Status: **Implemented (Swift 6.4)** [Verified:
2026-05-10].

**Prior art.** Vision: [Prospective Vision: Accessors](https://forums.swift.org/t/prospective-vision-accessors/76707).

**Contextualization.** Pair's stored fields `first` / `second` are
`var`-stored; they support implicit borrow/mutate via the storage itself, no
custom accessors needed. The candidate use case is in *consuming-static*
contexts where a borrowing projection-into-Pair would let the caller observe
one component without consuming the whole Pair. The current shape (consume +
field access via SE-0429) is already the canonical post-6.0 idiom and works.
SE-0507 unlocks a `borrow first { … }` style on derived computed properties,
but Pair has none.

**Verdict: REJECT** as a 0.1.0+1 addition. Pair's storage is already
optimal; SE-0507 brings no new expressiveness here. Re-open if a derived
computed property is later proposed (none planned).

---

#### B3. SE-0518 — `~Sendable` for explicit non-Sendability (Implemented Swift 6.4)

**What it is.** Adds `~Sendable` to suppress `Sendable` inference and mark a
type explicitly non-Sendable. Status: **Implemented (Swift 6.4)** [Verified:
2026-05-10].

**Prior art.** N/A.

**Contextualization.** Pair currently has a *conditional* `Sendable` at
[`Pair.swift:47–48`](../Sources/Pair%20Primitives/Pair.swift):

```swift
extension Pair: Sendable
where First: Sendable & ~Copyable & ~Escapable, Second: Sendable & ~Copyable & ~Escapable {}
```

This is correct: Pair conforms to Sendable iff both arms do. SE-0518 is
relevant only if Pair wants to *explicitly suppress* Sendable in some
configuration — there is no such configuration. The conditional shape is the
right one.

**Verdict: REJECT** as an addition. SE-0518 doesn't change Pair's shape; the
conditional Sendable conformance is the Swift-canonical way to express
"Sendable iff both arms are".

---

#### B4. SE-0494 — `isTriviallyIdentical(to:)` (Implemented Swift 6.4)

**What it is.** SE-0494 adds `isTriviallyIdentical(to:)` to `String`,
`Substring`, `Array`/`ArraySlice`/`ContiguousArray`, `Dictionary`, `Set`,
plus memory-region types. Returns `true` only if the two values share the
same underlying buffer (i.e., are *trivially* equal because they're the same
storage). Status: **Implemented (Swift 6.4)** [Verified: 2026-05-10].

**Prior art.** N/A.

**Contextualization.** A Pair counterpart would be:

```swift
extension Pair where First: Copyable & Equatable, Second: Copyable & Equatable {
    public func isTriviallyIdentical(to other: Pair) -> Bool {
        self.first.isTriviallyIdentical(to: other.first) &&
        self.second.isTriviallyIdentical(to: other.second)
    }
}
```

The protocol shape SE-0494 uses is concrete-type-only — no formal protocol
exists. The componentwise lift is structurally trivial but requires both
components to have their *own* `isTriviallyIdentical` — i.e., to be one of
the proposal's listed types or a user type that has opted in. Pair is a
generic structural composite; it can't make blanket claims, but a call-site-
discovered overload (where both `First` and `Second` have the method) is
useful for COW-heavy pairs like `Pair<String, [Int]>`.

**Verdict: DEFER.** Worth a follow-up once a `TriviallyIdenticalComparable`-
shaped protocol crystallizes (SE-0494 explicitly lists potential future
generalizations). Adding ad-hoc overloads now risks fragmenting the surface
before the language settles the shape.

---

#### B5. `BitwiseCopyable`-aware Pair specialization

**What it is.** When both `First` and `Second` are `BitwiseCopyable`, the
Pair itself is `BitwiseCopyable` — meaning trivial memcpy semantics, no
retain/release, no destructor. This unlocks `Pair` as a value carried in
SIMD-like or `@_rawLayout`-style storage and as elements of `InlineArray`.

```swift
extension Pair: BitwiseCopyable
where First: BitwiseCopyable, Second: BitwiseCopyable {}
```

**Prior art.** Swift `BitwiseCopyable` marker protocol (added with the
ownership work, ~Swift 6.0). SE-0426 and adjacent. Inline storage primitives
like `InlineArray` (SE-0483 sugar, plus prior `InlineArray` work) require it.

**Contextualization.** Pair currently does not declare a `BitwiseCopyable`
conformance. The compiler likely *infers* it for `@frozen` aggregates whose
fields are all `BitwiseCopyable`, but explicit declaration is the recommended
pattern for stable ABI guarantees and discoverability. The cost is one
additional conditional conformance line.

**Verdict: ADOPT** (post-0.1.0, additive). Mechanical, single-line addition.
Worth verifying empirically that the compiler infers it correctly for
`@frozen` Pair before deciding whether the explicit declaration is even
needed; if inference covers it, the explicit form is documentation-grade.

---

#### B6. `InlineArray<N, Pair<A, B>>` interop / `Span<Pair>` ergonomics

**What it is.** Whether Pair plays nicely as the element type of inline-
storage collections and Spans. Concretely: does
`InlineArray<4, Pair<Int, Int>>` work? Does `Span<Pair<Int, Int>>` borrow
correctly?

**Prior art.** SE-0483 (InlineArray sugar, accepted), SE-0524 (Span temporary
allocation, [Verified: 2026-05-10]), SE-0525 (RawSpan safe loading). The
underlying primitives have been in active development through 2025–2026.

**Contextualization.** With B5 (BitwiseCopyable) declared, `Pair<Int, Int>`
should be a valid `InlineArray` element. Pair already meets the storage
requirements (`@frozen`, no reference fields when both arms are bitwise).
For `Span<Pair<A, B>>` — Span requires bitwise-copyable element types in its
typed form; the same B5 conformance covers it.

No new API on Pair is needed for this interop; the work is a test case in
`Tests/` that empirically verifies `InlineArray<4, Pair<Int, Int>>` and
`Span<Pair<Int, Int>>` typecheck and round-trip correctly under Swift 6.4+.

**Verdict: ADOPT** (post-0.1.0, additive — as test coverage, not API).
Forward-direction action: add a `Pair+InlineArrayInterop.swift` test verifying
typecheck under 6.4+. No source-side change.

---

#### B7. SE-0470 — Isolated conformances (Implemented Swift 6.2)

**What it is.** SE-0470 lets a conformance be isolated to a global actor
(`@MainActor`-isolated `Equatable` conformance, etc.). Status: **Implemented
(Swift 6.2)** [Verified: 2026-05-10].

**Prior art.** N/A.

**Contextualization.** Pair's conformances are non-isolated. Isolated
conformances become relevant only if a downstream consumer wants to constrain
their use of `Pair: Equatable` to a specific actor — but Pair itself does not
participate; the isolation is a consumer-side concern on `First` and `Second`.

**Verdict: REJECT** as a Pair-side concern. SE-0470 is a downstream consumer
configuration; nothing here.

---

#### B8. SE-0503 — Suppressed associated types with defaults (Accepted)

**What it is.** SE-0503 allows protocols to declare associated-type defaults
that *can* be suppressed by the conforming type — e.g., a protocol with a
defaulted `associatedtype Element: Copyable = …` where conformers can opt
out via `~Copyable`. Status: **Accepted** [Verified: 2026-05-10].

**Prior art.** Builds on SE-0427 (noncopyable generics) and SE-0446
(nonescapable types).

**Contextualization.** Pair has no associated types — it's a struct with two
generic parameters. SE-0503 is relevant if/when Pair acquires a protocol
parent (e.g., a hypothetical `BinaryProduct` protocol with associated `First`
and `Second` types). No such protocol exists in the institute ecosystem and
none is planned. If the future "Bifunctor protocol" question revives, SE-0503
is the mechanism that would let it admit `~Copyable & ~Escapable`
defaults.

**Verdict: DEFER.** Watch for the Bifunctor-protocol question to come up
again; SE-0503 unblocks it but does not motivate it.

---

#### B9. SE-0492 — Section placement / `@_section` markers

**What it is.** SE-0492 (Implemented Swift 6.3) provides `@_section` and
`@_used` attributes for low-level linkage control. Allows static-data
constants to be placed in named binary sections.

**Contextualization.** Irrelevant to Pair as a generic struct primitive. Pair
values are not statically allocated; consumers who need that pattern would
declare their own `@_section`-annotated constants in their package.

**Verdict: REJECT.** Out of scope.

---

#### B10. SE-0530 — Async Result Support (Active Review)

**What it is.** Adds an async catching initializer to `Result`. Status:
**Active Review (April 28-May 12, 2026)** [Verified: 2026-05-10].

**Contextualization.** The relevance to Pair is indirect: if Pair grows a
`sequence` overload for `Result` (per A4), the async-throwing form (`async
throws -> Pair<First, Result<NewSecond, Error>>`) follows naturally once
`Result.init(catching:)` is async-compatible. No direct Pair API surfaces
here, but A4's eventual signatures should be checked against SE-0530 once it
ships, to stay forward-compatible.

**Verdict: DEFER.** Tracking note for A4's implementation phase. No 0.1.0
action.

---

## Outcome

### Verdict summary

| ID | Candidate | Verdict | Cost | Cross-pkg? | Breaking? |
|----|-----------|---------|------|------------|-----------|
| A1 | `assocL` / `assocR` | **ADOPT** | Low (2 methods + tests) | No | No (additive) |
| A2 | Distributivity over Either | **DEFER** | Medium (cross-pkg topology) | **Yes** | No |
| A3 | Free-function `fst` / `snd` | **REJECT** | — | No | — |
| A4 | `sequence` over Optional / Result / Either | **ADOPT** | Medium (4–6 methods) | Yes (Either variant) | No |
| A5 | `bifold` | **REJECT** (subsumed by `apply`) | — | No | — |
| A6 | `bizip` | **DEFER** (subsumed by A4) | — | No | — |
| A7 | `These<A, B>` | **REJECT** (separate pkg if needed) | — | New pkg if adopted | — |
| A8 | Tagged-Pair / labeled pair | **REJECT** (already expressible) | — | No | — |
| A9 | n-ary `Tuple` / Product bridge | **DEFER** (await consumer) | Low (2 bridge methods) | Yes | No |
| A10 | Either ~Copyable/~Escapable symmetry | **DONE** (already actioned in Either) | — | — | — |
| B1 | SE-0499 / drop `#if swift(<6.4)` block | **ADOPT** (post-6.3-EOL) | Trivial | No | No |
| B2 | SE-0507 borrow/mutate accessors | **REJECT** (no derived properties) | — | No | — |
| B3 | SE-0518 `~Sendable` | **REJECT** (conditional Sendable already correct) | — | No | — |
| B4 | SE-0494 `isTriviallyIdentical` | **DEFER** (await language convergence) | Low | No | No |
| B5 | `BitwiseCopyable` conditional conformance | **ADOPT** | Trivial (1 line) | No | No |
| B6 | `InlineArray` / `Span<Pair>` interop tests | **ADOPT** (test-only) | Low (test file) | No | No |
| B7 | SE-0470 isolated conformances | **REJECT** (consumer concern) | — | No | — |
| B8 | SE-0503 suppressed assoc-type defaults | **DEFER** (no Pair protocol) | — | No | — |
| B9 | SE-0492 `@_section` | **REJECT** (out of scope) | — | No | — |
| B10 | SE-0530 async Result | **DEFER** (track for A4) | — | No | No |

**Counts**: 14 candidates with substantive verdicts (excluding A10 which is
DONE) — **5 ADOPT** (A1, A4, B1, B5, B6), **5 DEFER** (A2, A6, A9, B4, B8,
B10 — note: 6, see below), **5 REJECT** (A3, A5, A7, A8, B2, B3, B7, B9 —
note: 8, see below).

(Re-tallying: ADOPT 5; DEFER 6; REJECT 8; DONE 1. Total 20 — matches the table
above.)

### Top 3 highest-value forward directions

1. **A4 — `sequence` over Optional / Result / Either**. Highest-value because
   it closes the principal feature gap identified in
   [`pair-prior-art-survey.md` Finding 7](pair-prior-art-survey.md), is
   directly consumer-facing (Optional-of-second-component is a common shape),
   and aligns Pair with Either's existing surface. Concrete overloads are
   cheap; the design is settled.

2. **A1 — `assocL` / `assocR`**. Mechanical, symmetric with `swapped`,
   unlocks HList-style nested-pair encoding. Two methods, two tests, no
   design ambiguity. Single-day implementation.

3. **B5 — `BitwiseCopyable` conditional conformance + B6 InlineArray /
   Span interop verification**. Together these certify Pair as a first-class
   element type for inline-storage collections — a precondition for any
   downstream pair-of-primitives use in `Span` / `InlineArray` contexts.
   Single conformance line plus a test file.

### Items requiring user decision before adoption

*(none open as of 2026-05-10 — A2 / A4-Either-variant home resolved, see
below.)*

### Resolved 2026-05-10

- **A2 — Distributivity package home** and **A4-Either-variant placement**:
  RESOLVED. Both live in a new L1 sibling **`swift-bifunctor-primitives`**.
  Framework pass on 2026-05-10 (canonical-authority + dep-direction +
  [RES-018] consumer gate + strict-mission) selected this home as a
  deliberate micro-package opening a categorical-structure family separate
  from algebra-*-primitives. pair-primitives and either-primitives stay
  orthogonal; bifunctor-primitives depends downward on both. Tracked via
  `HANDOFF-bifunctor-primitives.md`.

### Cross-package implications

- **A2 (distributivity)** and **A4-Either-variant (sequence over Either)**:
  both ship in the new `swift-bifunctor-primitives` sibling, not in this
  package. Pair-side responsibility ends at exposing the necessary public
  API (`first`, `second`, `init`, `swapped`) which is already shipped.
- **A9 (Pair↔Product bridge)** would add a `swift-pair-primitives →
  swift-product-primitives` dep; deferred until consumer demand. May
  also relocate to `swift-bifunctor-primitives` if a Product × Either or
  Pair × Product distributivity surfaces.
- **A7 (`These`)** would be a new L1 primitive package, not an addition to
  Pair; out of pair-primitives scope entirely.

### What is *not* recommended

- No HKT-style abstraction (Bifunctor protocol, Bitraversable typeclass).
  Swift can't represent it cleanly; concrete overloads at known functors
  are the right Swift shape per [RES-021].
- No free-function projections (`fst` / `snd`) — Swift idiom is member access.
- No `bifold` — `apply` subsumes it.
- No `These` in pair-primitives — separate primitive if/when motivated.
- No labeled-pair API in pair-primitives — Tagged composition or bespoke
  struct is the right answer.

### Non-breaking guarantee

**Every ADOPT recommendation is additive.** No change to the imminent 0.1.0
surface. The DEFER candidates are also non-breaking when adopted later. The
REJECT candidates do not need re-evaluation unless Swift's type system
acquires HKT or a similar abstraction mechanism.

---

## References

### Internal (this package and ecosystem)

- [`pair-prior-art-survey.md`](pair-prior-art-survey.md) (REFERENCE,
  2026-05-08) — foundational prior-art survey; this document extends.
- [`property-primitives-api-design.md`](property-primitives-api-design.md)
  (DECISION, 2026-05-08) — adjacent API-design decision context.
- [`escapable-arm-support.md`](escapable-arm-support.md) (DECISION) — Pair's
  type-level `~Escapable` upgrade rationale.
- [`equation-hash-comparison-protocol-adoption.md`](equation-hash-comparison-protocol-adoption.md)
  (DECISION) — institute Equation/Hash/Comparison.Protocol adoption rationale.

### Source files

- [`Sources/Pair Primitives/Pair.swift`](../Sources/Pair%20Primitives/Pair.swift)
  — `@frozen public struct Pair<First: ~Copyable & ~Escapable, Second:
  ~Copyable & ~Escapable>: ~Copyable, ~Escapable` (line 27); bifunctor
  surface (lines 108–195); instance-layer delegates (lines 203–259); tuple
  interop (lines 263–276).
- [`/Users/coen/Developer/swift-primitives/swift-either-primitives/Sources/Either Primitives/Either.swift`](../../../swift-either-primitives/Sources/Either%20Primitives/Either.swift)
  — `Either<Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable>`
  [Verified: 2026-05-10].
- [`/Users/coen/Developer/swift-primitives/swift-product-primitives/Sources/Product Primitives/Product.swift`](../../../swift-product-primitives/Sources/Product%20Primitives/Product.swift)
  — `Product<each Element>` n-ary form [Verified: 2026-05-10].

### Swift Evolution (verified 2026-05-10)

- [SE-0470: Global-actor isolated conformances (Implemented Swift 6.2)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md)
- [SE-0488: Apply the extracting() slicing pattern more widely (Implemented Swift 6.2)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0488-extracting.md)
- [SE-0492: Section Placement Control (Implemented Swift 6.3)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0492-section-control.md)
- [SE-0494: isTriviallyIdentical(to:) (Implemented Swift 6.4)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0494-add-is-identical-methods.md)
- [SE-0499: Support ~Copyable, ~Escapable in simple stdlib protocols (Implemented Swift 6.4)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)
- [SE-0503: Suppressed Default Conformances on Associated Types With Defaults (Accepted)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md)
- [SE-0507: Borrow and Mutate Accessors (Implemented Swift 6.4)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md)
- [SE-0515: Allow `reduce` to produce noncopyable results (Accepted)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0515-noncopyable-reduce.md)
- [SE-0517: UniqueBox (Accepted)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0517-uniquebox.md)
- [SE-0518: `~Sendable` for explicit non-Sendability (Implemented Swift 6.4)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0518-tilde-sendable.md)
- [SE-0521: Improved Optional opaque/existential syntax (Accepted)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0521-improved-optional-opaque-and-any.md)
- [SE-0524: Span temporary allocation (referenced)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0524-span-temporary-allocation.md)
- [SE-0527: RigidArray and UniqueArray (Active Review)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md)
- [SE-0528: Continuation — Safe and Performant Async Continuations (Accepted with revisions)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0528-noncopyable-continuation.md)
- [SE-0530: Async Result Support (Active Review)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0530-async-result-support.md)

(SE-0015, SE-0283, SE-0341, SE-0393, SE-0398, SE-0408, SE-0413, SE-0427,
SE-0429, SE-0432, SE-0444, SE-0446 — already verified inline in
[`pair-prior-art-survey.md`](pair-prior-art-survey.md) on 2026-05-08; not
re-verified here.)

### Type theory & FP (already verified in prior survey)

- Wikipedia: [Product (category theory)](https://en.wikipedia.org/wiki/Product_(category_theory))
  — universal property, associativity up to canonical iso [Verified: 2026-05-10
  (re-confirmed)].
- Hackage: [`Data.Bifunctor`](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bifunctor.html),
  [`Data.Bitraversable`](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bitraversable.html),
  [`Data.Bifoldable`](https://hackage-content.haskell.org/package/bifunctors-5.6.3/docs/Data-Bifoldable.html)
  — bimap / bisequence / bifold / bitraverse signatures.
- Hackage: [`Data.These`](https://hackage.haskell.org/package/these-1.2/docs/Data-These.html)
  — inclusive-or pattern (named-only, not load-bearing for any ADOPT
  recommendation).
