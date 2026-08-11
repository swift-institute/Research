# Bifunctor Primitives — Package Home and Protocol-Deferral Decision

<!--
---
version: 1.0.0
last_updated: 2026-05-10
status: DECISION
tier: 1
scope: per-package
---
-->

## Context

The institute distinguishes **value-level algebra** (`Algebra.Magma`,
`Algebra.Semigroup`, `Algebra.Monoid`, `Algebra.Group`, … under
`swift-algebra-*-primitives`, with verification harnesses at
`swift-algebra-law-primitives`) from **type-level categorical structure**
(Pair as binary product, Either as binary coproduct, bifunctor laws,
distributivity isos). The first is well-staffed; the second had no
canonical home prior to 2026-05-10.

Two pieces of upstream work converge here:

1. The Pair × Either **distributivity** content
   (`distribute` / `factor` / `sequence`) — the categorical iso
   `A × (B + C) ≅ (A × B) + (A × C)` realized as concrete operations on
   `Pair<First, Second>` and `Either<Left, Right>`. Both sibling packages
   (`swift-pair-primitives` and `swift-either-primitives`) had identified
   this as forward-direction work in their respective
   `Research/future-directions.md` (Pair §A2 / §A4, Either Candidate 3),
   but neither could host it without breaking package symmetry or
   introducing a dep cycle.

2. A **Bifunctor protocol** as a categorical-structure protocol — under
   discussion in both Pair and Either future-directions docs (Pair §A4
   contextualization paragraph; Either Candidate 7 verdict).

A 2026-05-10 framework pass selected `swift-algebra-law-primitives` as
the initial home for distributivity, but inspection of that package
revealed it is *value-level law-verification harnesses* (namespace
`enum`s with `check(...) -> Algebra.Law.Violation?` over
`Collection<Element>` samples). Hosting categorical iso witnesses there
would conflate two different kinds of "law" — value-algebra equational
laws (associativity of `+`) versus type-level structural isos
(`Pair × Either ≅ Either × Pair`) — and require mission creep on a
one-way door (`Algebra.Law.Distributivity` is already occupied by
Ring/Module distributivity).

After re-running the framework with the corrected premise, the home is
a **new L1 sibling `swift-bifunctor-primitives`** — a deliberate
micro-package opening a categorical-structure family separate from
algebra-*-primitives. The user ratified the choice: "we don't want
mission creep, we accept 'micro' packages."

## Question

Two questions, decided together:

1. **Where does Pair × Either distributivity live?**
2. **Does the package also ship a `Bifunctor.Protocol` and conformances
   for Pair / Either?**

## Analysis

### Question 1 — Distributivity home

Five candidate homes, evaluated against canonical-authority +
dep-direction + [RES-018] consumer gate + strict-mission rules:

| Candidate | Verdict |
|-----------|---------|
| `swift-pair-primitives` | ❌ Adds dep on `swift-either-primitives`; breaks orthogonal-sibling symmetry. |
| `swift-either-primitives` | ❌ Symmetric problem; adds dep on `swift-pair-primitives`. |
| `swift-algebra-law-primitives` | ❌ Mission creep on a value-algebra law-verification package. `Algebra.Law.Distributivity` is occupied by Ring/Module distributivity. Conflates value-level equational laws with type-level structural isos. |
| `swift-foundations/swift-bifunctor` | ❌ Wrong layer — Pair / Either are L1 primitives; their bridge content belongs at L1, not L3. |
| **`swift-bifunctor-primitives` (new L1 sibling)** | ✓ Correct authority (categorical-structure family, separate from value-algebra), correct dep direction (depends downward on Pair + Either), clears [RES-018] (Pair × Either is the second-consumer pair already; future Product × Pair, Product × Either bridges land here too), strict-mission ("categorical bifunctor structure"). |

**Decision**: New L1 sibling `swift-bifunctor-primitives`.

### Question 2 — Bifunctor protocol

Three findings converged on **defer the protocol**:

#### Finding A — Parameterized associated types are not in Swift today

Empirical compile against Swift 6.3.1 (default toolchain):

```swift
protocol BifunctorAttempt<First, Second>: ~Copyable {
    associatedtype First: ~Copyable & ~Escapable
    associatedtype Second: ~Copyable & ~Escapable

    associatedtype Mapped<NewFirst, NewSecond>
        where NewFirst: ~Copyable & ~Escapable, NewSecond: ~Copyable & ~Escapable
    // error: associated types must not have a generic parameter list
}
```

SE-0346 added *primary associated types* on protocols (`protocol P<A>`),
not *parameterized* associated types (`associatedtype Mapped<A, B>`). The
"`bimap` requirement that returns `Self`-shaped output via an
`associatedtype Mapped<First, Second>`" shape from the original brief is
**not expressible** in Swift 6.3.1 / 6.4-dev.

#### Finding B — The two surviving shapes both fail the rent test

Per [RES-018] (capability + consumer + theoretical content):

| Shape | Compiles | Capability |
|-------|----------|-----------|
| Marker-only protocol (`associatedtype First`, `Second`; no requirements) | Yes (with `SuppressedAssociatedTypes`) | **None.** Pure documentation. Pair / Either each implement `bimap` concretely; the protocol unifies nothing. |
| Endo-`bimap` protocol (`bimap` returning `Self`, transforms must be `First → First`, `Second → Second`) | Yes | **Negative.** Strictly weaker than the existing concrete `Pair.map(first:second:)` and `Either.map(left:right:)`, which admit shape-changing `NewFirst` / `NewSecond`. Adopting the protocol would shadow / compete with the concrete methods. |

Neither clears the capability hurdle.

#### Finding C — Both per-package future-directions docs already converged on "defer the protocol"

- `swift-pair-primitives/Research/future-directions.md` v1.1.0 §What is *not* recommended:

  > **No HKT-style abstraction (Bifunctor protocol, Bitraversable typeclass). Swift can't represent it cleanly; concrete overloads at known functors are the right Swift shape per [RES-021].**

- `swift-either-primitives/Research/future-directions.md` v1.2.0 Candidate 7 verdict:

  > A `Bifunctor` protocol is a separate question — that is a `swift-bifunctor-primitives` design, with [RES-018] gate (Pair would be the second consumer; that meets the floor but is a thin floor). **Defer the `Bifunctor` protocol pending a third consumer.**

Both packages had already independently arrived at the same conclusion.

### Verdicts

**Question 1**: New L1 sibling `swift-bifunctor-primitives`. **DECIDED**.

**Question 2**: Defer the protocol. The package opens with the
**`Bifunctor` namespace** (empty enum) + **`Bifunctor.Distributivity`**
sub-namespace + four concrete static operations
(`distribute` × 2 overloads, `factor` × 2 overloads) for `Pair × Either`.

Re-evaluation triggers for the protocol:

1. Swift gains parameterized associated types (`associatedtype Mapped<A, B>`)
   or higher-kinded types — at which point a clean
   `bimap : (First → NewFirst, Second → NewSecond) → Self<NewFirst, NewSecond>`
   becomes expressible.
2. A third independent consumer of bifunctor structure surfaces —
   beyond Pair and Either, where both can already implement `bimap`
   concretely with shape change.
3. SE-0503 (Suppressed Default Conformances on Associated Types With
   Defaults) is implemented and lifts a constraint that motivates the
   shape change.

Until any of these fire, concrete operations at known type-constructor
pairs are the right Swift shape.

## Outcome

**Status**: DECISION (effective 2026-05-10).

**What ships in 0.1.0**:

- `Bifunctor` namespace (`public enum Bifunctor: Sendable {}`).
- `Bifunctor.Distributivity` sub-namespace
  (`extension Bifunctor { public enum Distributivity: Sendable {} }`).
- `Bifunctor.Distributivity.distribute(_:)` — two overloads
  (Either-in-Pair-second and Either-in-Pair-first variants).
- `Bifunctor.Distributivity.factor(_:)` — two overloads (inverses of
  the above two).
- All four operations admit `~Copyable & ~Escapable` arms.
- Round-trip identity tests (`factor ∘ distribute = id` and
  `distribute ∘ factor = id`) on Copyable arms.

**What does NOT ship**:

- `Bifunctor.Protocol` — deferred per Finding C; re-evaluate on the
  three triggers above.
- `Bifunctor` conformances on Pair / Either — no protocol exists, so
  no conformances.
- Pair × Product or Either × Product distributivity — Product is
  parameter-pack-based and n-ary; the bifunctor framing applies only
  when treating it as binary, which is a separate research direction.
- Bitraversable / Bifoldable / Biapplicative typeclasses — same HKT
  gap as Bifunctor protocol; defer per [RES-021] until either Swift
  gains the necessary expressivity or a real consumer surfaces with
  concrete shape.

## References

### Internal

- [`HANDOFF-bifunctor-primitives.md`](../../HANDOFF-bifunctor-primitives.md)
  — investigation+execution brief from the parent chat (handoff to this work).
- [`swift-pair-primitives/Research/future-directions.md`](../../swift-pair-primitives/Research/future-directions.md)
  v1.1.0 §A2, §A4 — Pair-side distributivity decision; "What is not
  recommended" rejecting HKT-style protocols.
- [`swift-either-primitives/Research/future-directions.md`](../../swift-either-primitives/Research/future-directions.md)
  v1.2.0 Candidate 3 — Either-side distributivity decision; Candidate 7 —
  Bifunctor protocol deferral.
- [`swift-pair-primitives/Research/pair-prior-art-survey.md`](../../swift-pair-primitives/Research/pair-prior-art-survey.md)
  — REFERENCE prior-art survey covering bifunctor / bitraversable
  shapes in Haskell, Scala cats, Rust, PureScript.

### Source

- [`Sources/Pair Primitives/Pair.swift`](../../swift-pair-primitives/Sources/Pair%20Primitives/Pair.swift)
  — `@frozen public struct Pair<First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable>: ~Copyable, ~Escapable`
  [Verified: 2026-05-10].
- [`Sources/Either Primitives/Either.swift`](../../swift-either-primitives/Sources/Either%20Primitives/Either.swift)
  — `@frozen public enum Either<Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable>: ~Copyable, ~Escapable`
  [Verified: 2026-05-10].

### Verification spike

- `/tmp/bifunctor-shape-spike/` — Swift 6.3.1 typecheck probes for
  parameterized associated types (Spike.swift), marker-only protocol
  (Spike2.swift), and endo-`bimap` protocol (Spike3.swift). Confirmed
  parameterized associated types are not supported and the surviving
  shapes do not earn rent. [Verified: 2026-05-10]

### Skills

- [PKG-NAME-001], [PKG-NAME-009] — noun-form package and namespace
  naming; capability-protocol vs noun-type distinction.
- [PKG-DEP-001] — path-form-as-safe-default for pre-publishable
  cross-repo dependencies.
- [RES-018] — premature primitive anti-pattern; second-consumer +
  composition-fails check.
- [RES-021] — prior-art survey contextualization step (universal
  adoption ≠ universal necessity in Swift's type system).
- [MOD-RENT] — three-criteria primitive-package rent test
  (capability + consumer + theoretical content).
- [SWIFT-PKG-NAME-009] — capability protocol vs noun-type backing.
