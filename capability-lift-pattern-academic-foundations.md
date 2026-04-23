# Capability-Lift Pattern: Academic Foundations

<!--
---
version: 1.0.0
last_updated: 2026-04-23
status: ANALYSIS
tier: 2
scope: cross-package
---
-->

## Context

`swift-primitives/Research/capability-lift-pattern.md` (v1.1.0,
RECOMMENDATION) characterizes the *.\`Protocol\` recipe used by
`Cardinal.\`Protocol\``, `Ordinal.\`Protocol\``, `Hash.\`Protocol\``
and probes a `Carrier<Underlying>` super-protocol. It draws empirical
verdicts but only gestures at academic literature.

This companion document supplies the academic grounding: how the
pattern relates to phantom types, type classes, polymorphism
taxonomy, free constructions, parametricity, higher-kinded
polymorphism, parameterised monads, and tagless final encoding.
It also enumerates **frames we hadn't considered** in the original
characterization — angles that change what we'd recommend if we
revisited.

Per [feedback_verify_cited_sources.md], every citation in this
document has been verified against primary sources. Citations
without confirmed bibliographic detail are not included.

**Trigger**: [RES-012] Discovery — proactive theoretical grounding
for a pattern under active design consideration.

**Scope**: Cross-package — the pattern recurs across the primitives
layer and any academic framing applies ecosystem-wide. [RES-002a]

**Tier**: 2 (Standard) — supplies prior art survey [RES-021] and
theoretical grounding [RES-022] for the parent capability-lift-pattern
RECOMMENDATION. Not tier 3 because no normative semantic contract is
established. [RES-020]

## Question

The capability-lift pattern's recipe (`V.\`Protocol\`` capability
protocol with `Domain` associatedtype, value accessor, round-trip
init, and Tagged forwarding) recurs in academic literature under
several guises. Three sub-questions:

1. **What academic frames best explain the pattern?** Which
   well-known constructions IS this pattern an instance of, and
   what does each frame illuminate?

2. **What angles did the original characterization miss?**
   Specifically, what novel implications fall out of frames that
   weren't applied?

3. **Do any of those implications change the design recommendations?**

## Methodology

Six lenses applied to the pattern, each grounded in a verified
primary source:

| Lens | Primary source |
|------|----------------|
| Phantom types as a programming idiom | Leijen & Meijer 1999; Hinze 2003 |
| First-class phantom types / type witnesses | Cheney & Hinze 2003 |
| Type classes & ad-hoc polymorphism | Wadler & Blott 1989 |
| Polymorphism taxonomy | Cardelli & Wegner 1985 |
| Parametricity & free theorems | Reynolds 1983; Wadler 1989 |
| Higher-kinded polymorphism encoding | Yallop & White 2014 |
| Parameterised / graded monads | Atkey 2009 |
| Tagless final encoding | Carette, Kiselyov, Shan |

For each lens: a brief summary of the academic content, how the
capability-lift pattern is an instance (or relative), and what the
frame illuminates that we hadn't articulated.

The "Things we hadn't considered" section (§5) collects the most
significant new angles that emerged from applying these lenses.

## Survey

### §4.1 Phantom types as a programming idiom

**Source**: Leijen & Meijer, *"Domain Specific Embedded Compilers"*,
USENIX DSL '99 (1999). Hinze, *"Fun with Phantom Types"*, in
*The Fun of Programming* (Gibbons & de Moor, eds.), Palgrave
Macmillan 2003, pp. 245–262.

A phantom type is a type parameter that does not appear in any of
the type's data constructors. In Leijen & Meijer's HaskellDB
encoding, phantom variables enforce SQL safety properties: queries
parameterised by `Expr Int` and `Expr String` cannot be mixed even
though `Expr` carries no runtime distinction.

In the capability-lift pattern, `Tag` in `Tagged<Tag, V>` is exactly
a phantom type — it constrains type-level reasoning without
affecting storage. `Domain` in the `V.\`Protocol\`` capability
protocol surfaces the phantom at the protocol-associated-type level,
which is what makes phantom-preserving operations expressible
(`func f<C: V.\`Protocol\`>(_ c: C) -> C` returns a value with the
SAME phantom Domain).

**What the frame illuminates**: the pattern's primary type-system
contribution is phantom-type *preservation through generic
dispatch.* Bare phantom types (Leijen-Meijer) only enforce
non-mixing; the capability-lift pattern additionally lets generic
algorithms USE the phantom (via `C.Domain`) and PRESERVE it (via
`Self`-typed return). This is one step beyond classical phantom
typing.

### §4.2 First-class phantom types / type witnesses

**Source**: Cheney & Hinze, *"First-Class Phantom Types"*, Cornell
Technical Report TR2003-1901 (2003).

Cheney & Hinze extend phantom types so the type parameter can be
inspected at runtime via type-equality witnesses (essentially
GADT-style indexed types in a typed-Hindley-Milner setting). This
gives type-safe `eqT :: Rep a -> Rep b -> Maybe (a :=: b)` style
operations.

The capability-lift pattern does NOT make phantoms first-class —
`Domain` cannot be inspected (it's `~Copyable`, often `Never`).
This is a deliberate restriction: parametricity (§4.5) buys us
"free theorems" precisely because Domain is not inspectable. The
two designs occupy different points on a tradeoff curve.

**What the frame illuminates**: Cheney & Hinze's design admits
runtime type case; ours forbids it. Each gains different reasoning
power. The capability-lift pattern's `Domain: ~Copyable` constraint
is doing more theoretical work than it appears — see §5.4.

### §4.3 Type classes & ad-hoc polymorphism

**Source**: Wadler & Blott, *"How to make ad-hoc polymorphism less
ad hoc"*, POPL '89, pp. 60–76 (1989). DOI: 10.1145/75277.75283.

Wadler & Blott introduced type classes as a disciplined form of
ad-hoc polymorphism, extending Hindley-Milner with type-class
constraints (`(Eq a) => a -> a -> Bool`).

Swift protocols are the lineal descendant of Haskell type classes.
`V.\`Protocol\`` is exactly a type class: it constrains a type
variable to admit specific operations. The Tagged conditional
conformance (`extension Tagged: V.\`Protocol\` where RawValue == V`)
is exactly an *instance declaration* in Haskell terms:

```haskell
-- Haskell analogue of Cardinal.`Protocol` + Tagged conformance:
class CardinalLike c where
    cardinal :: c -> Cardinal
    fromCardinal :: Cardinal -> c
instance CardinalLike Cardinal where ...
instance CardinalLike (Tagged tag Cardinal) where ...
```

**What the frame illuminates**: the pattern is type classes,
nothing more exotic. The novelty is in the *recipe* (Domain
associatedtype + Tagged forwarding) which is a Swift idiom —
the underlying mechanism is well-understood and has been since
1989. This is a strength: the pattern inherits 35+ years of
literature on type-class semantics, instance coherence, and
dictionary passing.

### §4.4 Polymorphism taxonomy

**Source**: Cardelli & Wegner, *"On Understanding Types, Data
Abstraction, and Polymorphism"*, ACM Computing Surveys 17(4):
471–523 (December 1985). DOI: 10.1145/6041.6042.

Cardelli & Wegner's taxonomy distinguishes:

| Polymorphism | Mechanism |
|--------------|-----------|
| Universal — Parametric | One implementation for all types (`fmap`) |
| Universal — Inclusion (subtype) | Subtypes inherit operations |
| Ad-hoc — Overloading | Compile-time dispatch (Swift's `func f(_:Int)` / `func f(_:String)`) |
| Ad-hoc — Coercion | Implicit conversion between types |

Where does the capability-lift pattern fit?

- `func f<C: Cardinal.\`Protocol\`>(_ c: C) -> C` is **universal
  parametric** in C, with an ad-hoc-bounded constraint (C must
  conform).
- The dispatch via `C(Cardinal(...))` reaches the conformer's
  init, which is **ad-hoc overloading** at the conformance site.
- Tagged conditional conformance (`where RawValue == V`) is a
  PARAMETRIC family of instances — one declaration covering
  infinitely many `Tagged<Tag, V>` types.

**What the frame illuminates**: the pattern is a *hybrid*.
Parametric outside (single algorithm, many types), ad-hoc inside
(each conformer's init does type-specific work). The Tagged
parametric family is what makes the ad-hoc inside scalable — without
it, we'd write per-Tagged-instance instances by hand. This is the
same observation underlying Wadler's later work on type families.

### §4.5 Parametricity & free theorems

**Source**: Reynolds, *"Types, Abstraction and Parametric
Polymorphism"*, Information Processing 83 (1983). Wadler,
*"Theorems for free!"*, FPCA '89 (1989). DOI: 10.1145/99370.99404.

Reynolds' Abstraction Theorem (a.k.a. parametricity) says: a
parametrically polymorphic function `forall a. T[a]` cannot
inspect `a` — it must behave uniformly. Wadler operationalized
this: from a type, derive a free theorem about every function of
that type.

In the capability-lift pattern, `Domain: ~Copyable` is the
parametricity discipline. Conformers cannot inspect `Domain`'s
value (there isn't one — it's a phantom). This means:

- `align<C: Cardinal.\`Protocol\`>(_ c: C) -> C` cannot branch
  on whether C's Domain is `Bytes` or `Frames`.
- The *only* way `align` returns a value with the same Domain as
  its input is via `C(Cardinal(...))` — which dispatches to the
  conformer's init. The phantom is preserved because the
  conformer reconstructs it.

**What the frame illuminates**: phantom preservation isn't a
courtesy; it's a **theorem** derivable from the type signature.
For any `f<C: Cardinal.\`Protocol\`>(_ c: C, ...) -> C`, Wadler's
free theorem says: f's input Domain equals f's output Domain.
This is a guarantee independent of the implementation — a true
"free theorem." The pattern's phantom-preservation property
isn't a programmer convention; it's parametricity at work.

### §4.6 Higher-kinded polymorphism encoding

**Source**: Yallop & White, *"Lightweight Higher-Kinded
Polymorphism"*, FLOPS 2014, Springer LNCS. DOI:
10.1007/978-3-319-07151-0_8.

OCaml lacks native higher-kinded polymorphism. Yallop & White
encode HKT via an abstract type `app` and opaque "brands"
(`type ('a, 'f) app`), making `app(int, list_brand)` represent
`list int`.

Swift is in the same boat: `Carrier<Underlying>` is HKT-adjacent
but not full HKT. We can write `Carrier<Cardinal>` (constraint
on the second-position type), but we cannot write `Carrier<F>`
where F is itself a type constructor (e.g., a generic function
"works for any Carrier-builder").

**What the frame illuminates**: the pattern's expressiveness is
bounded by Swift's lack of HKT. SE-0346's primary associated
types ARE Swift's "lightweight HKT" move — they make
`Carrier<Underlying>` syntactically clean but stop short of
full HKT. If you find yourself wanting `func f<F where F: HasCarrier>`
where F itself produces Carriers, you'd need an OCaml-style
encoding.

In practice for this pattern: HKT-adjacent is enough. We don't
have demonstrated need for "any Carrier-builder."

### §4.7 Parameterised / graded monads

**Source**: Atkey, *"Parameterised notions of computation"*,
Journal of Functional Programming 19(3-4):335–376 (2009).

Atkey introduces parameterised monads: `M : C × C^op -> Set` —
monads indexed by pairs of objects (think pre/post-conditions).
`bind : M a b -> (a -> M b c) -> M a c` composes by matching
indices.

The capability-lift pattern is structurally similar: each Carrier
has `(Domain, Underlying)` indices. Operations that compose
Carriers must match indices (e.g., `Index<Buffer> + Index<Buffer>.Count`
both have `Buffer` Domain).

**What the frame illuminates**: there's a **graded** interpretation
of the pattern. The type-level distinction between `Index<Buffer>`
and `Index<File>` is exactly an indexed/graded structure. Operations
are *vertical* (Domain-preserving — `+`) or *horizontal*
(Domain-changing — explicit conversion). The pattern enforces this
distinction by where you put `where Self.Domain == Other.Domain`
constraints. This is not gratuitously categorical — Atkey-style
parameterised structures DIRECTLY justify the recipe.

The implication for design (§5.6): the pattern could expose
Domain-changing operations as first-class via "horizontal"
functions, formalizing what's currently ad-hoc.

### §4.8 Tagless final encoding

**Source**: Carette, Kiselyov & Shan, *"Finally Tagless, Partially
Evaluated"*, Journal of Functional Programming (Cambridge
University Press), and the workshop precursor.

Tagless final encodes object-language terms via combinator
functions over a type class, rather than via algebraic data
constructors. Different interpretations (evaluator, compiler,
pretty-printer) become different instances of the type class.

The capability-lift pattern shares the spirit: rather than
making `Cardinal` an enum case of a sum type ("kinds of carriers"),
the protocol IS the interface, and conformers are the
"interpretations." Tagged conditional conformance is the
parametric "deep embedding" — it gives an interpretation for
every (Tag, Cardinal) pair.

**What the frame illuminates**: the pattern's "no central
registry of carriers" property is a tagless-final virtue. New
Carriers can be added (new Tagged instantiations, new bare value
types) without modifying existing code — open-extensibility, like
a tagless-final DSL. This is the technical reason Cardinal can
sit in one package and downstream packages can add their own
phantom Tags without touching swift-cardinal-primitives.

## Things we hadn't considered

### §5.1 Tagged is the FREE Carrier (universal arrow)

The capability-lift document characterizes Tagged as the "canonical
generic implementation" of Carrier. The categorical statement is
sharper: **Tagged is the FREE Carrier construction.**

Specifically, considering the category whose objects are Carriers
and morphisms preserve Domain and Underlying:

- There is a forgetful functor `U : Carrier -> Type × Type` that
  strips a Carrier to its `(Domain, Underlying)` pair.
- There is a left adjoint `F : Type × Type -> Carrier` that takes
  any `(Tag, V)` to `Tagged<Tag, V>`.
- The unit of the adjunction `η : (Tag, V) -> U(F(Tag, V))` is the
  identity (Tagged carries the (Tag, V) pair faithfully).
- The counit `ε : F(U(C)) -> C` for any Carrier C says: any Carrier
  with `(Domain, Underlying) = (T, V)` factors uniquely through
  `Tagged<T, V>`.

The classical free-monoid analogy holds:

| Free construction | Free object | Forgetful |
|-------------------|-------------|-----------|
| Free monoid on a set | List of set elements | Underlying set |
| Free monad on a functor | Tree of functor applications | Underlying functor |
| Free Carrier on `(Tag, V)` | `Tagged<Tag, V>` | `(Tag, V)` |

This is not a categorial flourish — it has design consequences
(§6.1).

### §5.2 Phantom-type fibration

The family `{ Tagged<T, V> | T : Type }` is a Tag-indexed family of
Carriers. In categorical language, this is a **fibration** over the
category of Tags: fibers are Carriers with a fixed Tag, and morphisms
between fibers are operations that change Tag.

This frame gives precise vocabulary to a distinction the design
already cares about:

- **Vertical morphisms**: stay within a fiber (Tag-preserving).
  Example: `Index<Buffer> + Index<Buffer>.Count -> Index<Buffer>`.
  These should be the protocol-extension defaults — every Carrier
  gets them.
- **Horizontal morphisms**: cross fibers (Tag-changing). Example:
  `func reroot<C1: Carrier, C2: Carrier>(_ c: C1) -> C2 where C1.Underlying == C2.Underlying`.
  These MUST be opt-in (you usually want to forbid casual Tag
  changes).

The fibration view says: the design's "preserve Tag" instinct is
fiber-preservation, and "occasionally need to change Tag" is moving
between fibers along an explicitly-declared morphism. This isn't
new mathematics — it's existing vocabulary that names what we
already do.

References for fibred categories: Streicher's "Fibered Categories
à la Bénabou" notes (TU Darmstadt, ongoing); the Wikipedia entry
on Fibred Categories.

### §5.3 Σ-type / dependent-pair interpretation

In a dependent type theory, `Tagged<Tag, V>` could be read as a
Σ-type: `Σ(t : Tag) V` — "a value of type V together with a tag
inhabitant of type Tag." Swift doesn't have Σ-types directly, but
the structural reading helps.

With phantom Tag (no inhabitant — `Tag` is `~Copyable` and never
constructed at runtime), the Σ-type degenerates: `Σ(t : Tag) V ≡ V`
extensionally, but distinguished AT THE TYPE LEVEL from
`Σ(s : OtherTag) V`. The phantom Tag plays the role of a *type-
level token* indexing the family.

The interesting consequence: many type-theoretic tools that apply
to Σ-types apply to phantom-Tagged types too — first projection
(`var rawValue: V`), second projection (would be `var tag: Tag`,
trivial since Tag is uninhabited), pairing (the `Tagged.init`).

**What we hadn't considered**: framing Tagged as a degenerate
Σ-type opens the door to non-degenerate variants. If Tag could be
*inhabited* (a concrete singleton type with a single value), we'd
get a "labelled Tagged" — a tagged value carrying a runtime tag
value too. This would be a new kind of Carrier with richer
Domain semantics. Whether useful is open.

### §5.4 Parametricity is doing real work for `Domain: ~Copyable`

The capability-lift document treats `Domain: ~Copyable` as an
ergonomic suppression. The parametricity frame (§4.5) reveals
it's doing theoretical work too.

Because Domain is ~Copyable AND has no operations defined on it
(no `var domain: Domain { get }` accessor), no algorithm CAN
inspect Domain's identity. By Reynolds' abstraction theorem, every
generic function over Carrier obeys a free theorem about its
treatment of Domain.

**Concrete free theorems**:

- For `f<C: Carrier>(_ c: C) -> C`: the input's Domain equals the
  output's Domain. (This is what "phantom preservation" means
  technically — it's a theorem, not a convention.)
- For `f<C: Carrier>(_ c: C) -> C.Underlying`: f's behavior is
  uniform across Domains. Two inputs with the same Underlying but
  different Domains must produce the same Underlying output.
- For `g<C: Carrier>(_ c1: C, _ c2: C) -> C`: c1 and c2 must
  share a Domain (compile-time) AND the output shares it (runtime).

These are not aspirational properties — they're theorems we get
free from the type signature.

**Implication**: relaxing `Domain: ~Copyable` (e.g., adding
`var domain: Domain { get }`) would BREAK parametricity. Conformers
could observe Domain, branch on it, and the free theorems no longer
apply. The current restriction is load-bearing — strengthen it
intentionally only.

### §5.5 Forgetful functor / adjunction (deeper free-Carrier framing)

§5.1 names Tagged as the free Carrier. The full framing is an
adjunction:

```
                 F (free)
   Type × Type  ─────────►  Carrier
                ◄─────────
                 U (forgetful)
```

The unit `η : Id ⇒ U ∘ F` says: every `(Tag, V)` admits a free
embedding into a Carrier (via Tagged).

The counit `ε : F ∘ U ⇒ Id` says: every Carrier C arises from some
`(Tag, V)`, and the canonical Tagged construction over them maps
back to C via a unique morphism.

**Design consequences**:

1. Bare value types' "trivial Carrier with Domain = Never"
   conformance is the SPECIAL CASE of `(Tag, V) = (Never, V)` —
   the free Carrier with the trivial Domain. It's not a hack; it's
   the unit at a degenerate point.

2. Any custom Carrier (some hypothetical heap-allocated wrapper or
   inline-storage variant) factors uniquely through Tagged via the
   counit. Concretely: there's a canonical conversion
   `tagged(c: CustomCarrier<V>) -> Tagged<C.Domain, V>` that
   preserves all observable behavior. The custom Carrier is
   *equivalent* to its image in Tagged.

3. **Whenever you'd reach for a custom Carrier, ask: what does it
   give that Tagged doesn't?** If nothing observable, use Tagged.
   The adjunction guarantees Tagged is the simplest possible
   Carrier-shape.

### §5.6 Carrier as graded structure (Atkey-style)

Atkey-style parameterised monads (§4.7) suggest the capability-lift
pattern admits a graded reading: `Carrier<V>` is a `Domain`-graded
structure — Carriers form a family indexed by Domain, with
operations preserving or changing the index.

**What we hadn't considered**: making the graded structure
explicit could yield a Carrier-aware `bind`-like operation:

```swift
extension Carrier {
    // Vertical (Tag-preserving) bind:
    func map<C2: Carrier>(_ f: (Underlying) -> C2.Underlying) -> C2
        where Self.Domain == C2.Domain { ... }
    
    // Horizontal (Tag-changing) bind:
    func rebrand<C2: Carrier>(_: C2.Domain.Type) -> C2
        where C2.Underlying == Self.Underlying { ... }
}
```

These ARE the vertical and horizontal morphisms from §5.2,
exposed at the API surface. Whether this generalization buys
enough to be worth implementing depends on demand for cross-tag
conversions — currently not pressing in the ecosystem, but
academic literature (Atkey 2009) provides a fully-worked design
space if it becomes pressing.

### §5.7 Coherence (multiple instances)

Type-class literature (Wadler-Blott §4.2 onward) wrestles with
*coherence*: when multiple instance declarations apply, which
fires? Haskell forbids overlapping instances by default. Scala
requires implicit prioritization rules. Swift's protocol
conformance lookup is generally non-overlapping by design.

In the capability-lift pattern: we don't currently HAVE coherence
issues because Tagged conditional conformance is parametric with
disjoint constraints (`where RawValue == V`). Each `Tagged<Tag, V>`
gets exactly one Cardinal.\`Protocol\` instance.

**What we hadn't considered**: if we add a Carrier super-protocol,
coherence questions arise. If there's `extension Tagged: Carrier where RawValue == Cardinal`
AND `extension Tagged: Carrier where RawValue == Ordinal`, what
about `Tagged<Tag, SomeBareThingThatConformsToBoth>`? Swift's
non-overlapping rule typically forbids this — verify before
recommending Carrier.

The empirical experiment (V0–V5) didn't probe this; it only tests
each Underlying separately. A coherence variant is missing.

### §5.8 HKT-encoding hidden costs

Yallop & White (§4.6) document the OCaml HKT encoding's costs:
runtime indirection (boxed `app`), syntactic overhead (`inj`/`prj`
operations), loss of inferability. SE-0346's primary associated
types avoid these because they're a syntactic feature, not an
encoding — `some Carrier<Cardinal>` compiles to the same code as
`some Carrier where Carrier.Underlying == Cardinal`.

**What we hadn't considered**: SE-0346 IS Swift's HKT-lite. The
capability-lift pattern's super-protocol Option B (parameterized)
is using exactly this feature for exactly this purpose. We're
benefiting from a Swift Evolution decision aligned with academic
literature on lightweight HKT.

The implication: future Swift Evolution work that strengthens
SE-0346 (e.g., higher-order primary associated types — a la
Scala's `F[_]` constraints) would unlock new variants of this
pattern. Worth tracking.

## Implications for design

The original capability-lift-pattern.md gives Recommendations #1–#6.
This survey supports those AND adds:

7. **Use the fibration vocabulary** when discussing Tag-preserving
   vs Tag-changing operations (§5.2). It's a cleaner shared
   vocabulary than "preserves the phantom" / "changes the
   phantom." Adoption: in code comments and documentation, not
   as new types.

8. **Don't relax `Domain: ~Copyable`** without intentional
   parametricity loss (§5.4). The current constraint is
   load-bearing for free-theorem-style guarantees, not an
   ergonomic preference.

9. **If a custom non-Tagged Carrier is proposed, demand
   justification** (§5.5). The free-Carrier framing says any custom
   Carrier factors through Tagged; the cost of the custom
   construction must exceed the benefit it provides over Tagged.

10. **Audit coherence before adding the Carrier super-protocol**
    (§5.7). The empirical experiment didn't probe overlapping
    conformances; do that variant before production adoption.

11. **Track Swift Evolution on HKT extensions** (§5.8). The pattern
    benefits directly from SE-0346 and would benefit further from
    higher-order primary associated types if/when they ship.

The survey does NOT change the original recommendations — it
provides theoretical justification for them, and adds these
five supplementary ones grounded in academic frames the original
hadn't applied.

### What this document does NOT do

- Prove free theorems formally for the pattern (only sketches the
  parametricity argument).
- Survey beyond the eight lenses chosen. There may be other
  relevant frames (linear logic for ~Copyable, ornaments for
  refinement-typed extensions, lenses/optics for Carrier-as-getter)
  not explored here.
- Propose new variants of the pattern. The novel frames in §5
  could SUGGEST new variants (graded Carrier-bind, labelled
  Tagged), but proposing them is design work outside this
  document's scope.

## References

All citations below have been verified via primary-source web
search. Verification date: 2026-04-23.

### Phantom types

- **Leijen & Meijer, *"Domain Specific Embedded Compilers"***,
  Proceedings of the 2nd USENIX Conference on Domain-Specific
  Languages (DSL '99), Austin, TX, October 1999.
  Full paper: https://www.usenix.org/legacy/events/dsl99/full_papers/leijen/leijen.pdf
- **Hinze, *"Fun with Phantom Types"***, in *The Fun of Programming*,
  Jeremy Gibbons & Oege de Moor (eds.), Palgrave Macmillan, 2003,
  pp. 245–262. Full paper: https://www.cs.ox.ac.uk/ralf.hinze/publications/With.pdf
- **Cheney & Hinze, *"First-Class Phantom Types"***, Cornell
  University Technical Report TR2003-1901, 2003. Full paper:
  https://ecommons.cornell.edu/items/850fddd8-da52-4ecb-8e01-d068b3488bdb

### Type classes & polymorphism

- **Wadler & Blott, *"How to make ad-hoc polymorphism less ad hoc"***,
  Proceedings of the 16th ACM SIGPLAN-SIGACT Symposium on Principles
  of Programming Languages (POPL '89), pp. 60–76. ACM, 1989.
  DOI: https://dl.acm.org/doi/10.1145/75277.75283
- **Cardelli & Wegner, *"On Understanding Types, Data Abstraction,
  and Polymorphism"***, ACM Computing Surveys 17(4):471–523,
  December 1985. DOI: https://dl.acm.org/doi/10.1145/6041.6042

### Parametricity

- **Reynolds, *"Types, Abstraction and Parametric Polymorphism"***,
  Information Processing 83, Proceedings of the IFIP 9th World
  Computer Congress, Paris, September 19–23, 1983. Full paper:
  https://people.mpi-sws.org/~dreyer/tor/papers/reynolds.pdf
- **Wadler, *"Theorems for free!"***, Proceedings of the 4th
  International Conference on Functional Programming Languages
  and Computer Architecture (FPCA '89), 1989. DOI:
  https://dl.acm.org/doi/10.1145/99370.99404

### Higher-kinded polymorphism

- **Yallop & White, *"Lightweight Higher-Kinded Polymorphism"***,
  Functional and Logic Programming (FLOPS 2014), Springer LNCS,
  pp. 119–135. DOI: https://link.springer.com/chapter/10.1007/978-3-319-07151-0_8
  Companion library: https://github.com/yallop/higher

### Parameterised / graded structures

- **Atkey, *"Parameterised notions of computation"***, Journal of
  Functional Programming 19(3-4):335–376, 2009. Full paper:
  https://bentnib.org/paramnotions-jfp.pdf

### Tagless final encoding

- **Carette, Kiselyov & Shan, *"Finally Tagless, Partially Evaluated:
  Tagless staged interpreters for simpler typed languages"***,
  Journal of Functional Programming, Cambridge University Press.
  Reference page (with workshop and JFP versions):
  https://okmij.org/ftp/tagless-final/index.html

### Swift Evolution

- **SE-0346, *"Lightweight same-type requirements for primary
  associated types"***, accepted via second review March 2022.
  Proposal: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md
  Forum reviews: https://forums.swift.org/t/se-0346-lightweight-same-type-requirements-for-primary-associated-types/55869

### Category theory background (textbooks; not paper-cited)

- The "free monoid as universal construction" content is standard
  textbook material; nLab's free monoid entry is a reasonable
  starting reference: https://ncatlab.org/nlab/show/free+monoid
- Streicher, *"Fibered Categories à la Bénabou"*, lecture notes,
  TU Darmstadt (April 1999 – ongoing). Notes:
  https://www2.mathematik.tu-darmstadt.de/~streicher/FIBR/FiBo.pdf

### Companion documents in this corpus

- `swift-primitives/Research/capability-lift-pattern.md` (v1.1.0,
  2026-04-22, RECOMMENDATION) — the parent characterization this
  document supplies academic grounding for.
- `swift-primitives/Research/self-projection-default-pattern.md`
  (v1.0.0, 2026-04-22, RECOMMENDATION) — orthogonal pattern,
  referenced for taxonomy completeness.
- `swift-primitives/Experiments/capability-lift-pattern/Sources/main.swift`
  (CONFIRMED on Apple Swift 6.3.1) — the empirical six-variant
  experiment.
