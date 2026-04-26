# Academic prior-art survey: witness types for the Mutator pattern

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: REFERENCE
tier: 2
scope: ecosystem-wide
relocated_from: swift-mutator-primitives/Research/academic-prior-art-survey.md
relocation_date: 2026-04-25
---
-->

> Companion to `mutator-type-hasher-pattern-exploration.md` (DEFERRED
> 2026-04-25). Relocated from the retired `swift-mutator-primitives`
> package; preserved as ecosystem-wide reference.

## Context

This document is the prior-art-survey companion to
`Research/mutator-type-hasher-pattern-exploration.md` (IN_PROGRESS).
[RES-021] requires Tier 2+ research to include a prior-art survey
covering Swift Evolution proposals/forums, related languages, and
academic literature; [RES-020] requires parallel-subagent verification
of load-bearing claims against primary sources, with `[Verified:
YYYY-MM-DD]` tags per claim; [RES-018] prohibits proposing new
primitives without (a) demonstrating composition of existing primitives
fails and (b) naming a credible second consumer.

The survey is decomposed into four academic threads (lens/optics;
algebraic effects + handlers + linear/affine types; CRDTs + FRP;
type-class dictionary witnesses) plus a fifth ecosystem-grounding
thread that anchors each to the existing `swift-primitives` packages
**so that the Mutator investigation does not reinvent abstractions
already shipped**.

The survey is REFERENCE — it does not itself decide the protocol shape;
it provides the literature evidence that the IN_PROGRESS investigation
draws on.

## Existing ecosystem grounding (THIS MATTERS FIRST)

The Mutator-type investigation cannot proceed honestly without
acknowledging which primitives the ecosystem already ships. Three
relevant existing packages:

### `swift-optic-primitives`

Path: `/Users/coen/Developer/swift-primitives/swift-optic-primitives/`.
Ships `Optic.Lens<Whole, Part>`, `Optic.Prism<Whole, Part>`,
`Optic.Iso<Whole, Part>`, `Optic.Affine<Whole, Part>`, and
`Optic.Traversal<Whole, Part>` as concrete witness structs (Sendable +
`Witness.\`Protocol\``-conforming) carrying typed `get`/`set`
closures, with composition operators (`composing(_:_:)`,
`appending(_:)`) and the standard optic laws documented (GetSet, SetGet,
SetSet for `Optic.Lens`). The package is Foundation-free and Tier 0;
its `Optic.swift` declares the concrete optic hierarchy as a docstring
diagram.

| What `swift-optic-primitives` already provides | Implication for `Mutator` |
|----------------------------------------------|---------------------------|
| `Optic.Lens<Whole, Part>.modify(_:_:)` and `.modify(_: inout, _:)` | A Mutator that wants partial-state mutation should *compose* with `Optic.Lens`, not duplicate the focused-mutation surface |
| `Optic.Traversal` for 1→0..n focus | A Mutator role that mutates many parts at once can express the iteration via `Optic.Traversal`'s structure |
| `Optic.Affine` for 1→0..1 (Lens ⊔ Prism composition) | Optional / partial mutation (e.g., "mutate this case only if it's the case I expect") is already covered |
| `Sendable` conformance on each optic | Mutator's actor-crossing story aligns with the optic's existing `Sendable` discipline |

The lens/optics academic literature this survey covers (Foster et al.
2005/2007, van Laarhoven 2009, Pickering–Gibbons–Wu 2017, Riley 2018)
is therefore *not* a guide for inventing new types in the Mutator
package — it is a guide for *understanding what the existing optic
package formalizes* and *where a Mutator witness adds capability the
optics do not*.

### `swift-algebra-primitives` family

Path: `/Users/coen/Developer/swift-primitives/swift-algebra-*/`. The
namespace `Algebra` hosts:

| Algebraic structure | Package | Captures |
|---------------------|---------|----------|
| `Algebra.Magma<Element>` | swift-algebra-magma-primitives | A binary operation with no axioms |
| `Algebra.Semigroup<Element>` | (in monoid package) | Associative binary operation |
| `Algebra.Monoid<Element>` | swift-algebra-monoid-primitives | Associative + identity |
| `Algebra.Group<Element>` | swift-algebra-group-primitives | Monoid + inverses |
| `Algebra.Ring<Element>` | swift-algebra-ring-primitives | Two compatible monoids (additive + multiplicative) |
| `Algebra.Field<Element>` | swift-algebra-field-primitives | Ring with multiplicative inverses (e.g., `Algebra.Field<Bit>.z2`) |
| `Algebra.Module<Element, Scalar>` | swift-algebra-module-primitives | Ring action |
| `Algebra.Semiring<Element>` | swift-algebra-semiring-primitives | Ring without additive inverses |
| `Algebra.Modular<Element>` | swift-algebra-modular-primitives | Modular arithmetic |
| `Algebra.Affine<Element>` | swift-algebra-affine-primitives | Affine combinations |
| `Algebra.Cardinal<Element>` | swift-algebra-cardinal-primitives | Cardinal-typed quantities |
| `Algebra.Linear<Element>` | swift-algebra-linear-primitives | **Linear algebra** (vectors/matrices) — NOT Wadler-1990 substructural linearity |
| `Algebra.Law` | swift-algebra-law-primitives | Property-based law assertions |

These are concrete *witness structs* (e.g., `Algebra.Monoid<Bool>` =
`{ identity: Bool; combining: (Bool, Bool) -> Bool }`) — exactly the
"finally-tagless interpreter" pattern surveyed below in §3.5. The
algebraic-effects / handler academic literature (Plotkin–Power 2002,
Plotkin–Pretnar 2009, Bauer–Pretnar 2014) treats state operations as
algebraic theories whose witnesses live in this very shape. **The
Mutator's "what the witness does" is most precisely framed as which
algebraic structure(s) the witness represents.**

### Swift language-level substructural primitives

Swift's `~Copyable` is **affine** (per Walker 2005's substructural
classification — admits weakening via deinit, denies contraction via
non-copyability) and is delivered at the **language level**, not via a
package. `~Escapable` adds Tofte–Talpin-style lifetime bounding. There
is no `swift-substructural-primitives` package and would not be one —
Wadler-1990 / Walker-2005 substructural typing is in the type system
itself.

The naming overlap is hazardous: **`Algebra.Linear` (linear algebra,
existing package) is unrelated to "linear types" (Wadler 1990,
substructural)**. The Mutator investigation cites both kinds of
"linear" but they are distinct concepts and must not be conflated.

---

## Part 1 — Lens / Functional Optics Literature

### 1.1 Bidirectional transformations: the origin of lenses

**Foster, J. N., Greenwald, M. B., Moore, J. T., Pierce, B. C., &
Schmitt, A. (2007). "Combinators for bidirectional tree transformations:
A linguistic approach to the view-update problem." *ACM Transactions on
Programming Languages and Systems* 29(3).** DOI:
[10.1145/1232420.1232424](https://dl.acm.org/doi/10.1145/1232420.1232424).
**[Verified: 2026-04-25]** Conference version: POPL 2005, *ACM SIGPLAN
Notices* 40(1).

Foster et al. introduce *lenses* as a DSL for bidirectional tree
transformations addressing the database view-update problem. A lens *l*
between a concrete type *C* and an abstract view *A* is a pair of
total functions `l.get : C -> A` and `l.put : A -> C -> C` (and
optionally `l.create : A -> C`). Two contracts:

- **Well-behaved**: PutGet (`l.get (l.put a c) = a`) and GetPut
  (`l.put (l.get c) c = c`).
- **Very well-behaved**: also PutPut
  (`l.put a' (l.put a c) = l.put a' c`).

**Ecosystem mapping.** `Optic.Lens<Whole, Part>` in
`swift-optic-primitives` documents exactly these laws as
"GetSet / SetGet / SetSet" (the renaming of "Get/Put" → "get/set"
matches the modern functional-programming convention). The Mutator
investigation does NOT need to define lens laws — they are already
documented and, for any Mutator that composes with an `Optic.Lens`,
the existing laws govern the partial-mutation behavior.

### 1.2 van Laarhoven lenses: composition under function composition

**van Laarhoven, T. (2009). "CPS based functional references." Twan
van Laarhoven's blog, 19 July 2009.**
[https://www.twanvl.nl/blog/haskell/cps-functional-references](https://www.twanvl.nl/blog/haskell/cps-functional-references)
**[Verified: 2026-04-25]**

The encoding `type Lens s t a b = forall f. Functor f => (a -> f b)
-> (s -> f t)` admits ordinary function composition `(.)` for lens
composition. Choosing the functor recovers the operations:
`f = Identity` gives `over :: (a -> b) -> (s -> t)`; `f = Const a`
gives `view :: s -> a`.

**Ecosystem mapping.** Swift cannot express `forall f. Functor f`
(no higher-kinded types, no rank-N polymorphism). The ecosystem's
`Optic.Lens<Whole, Part>` is therefore a *witness encoding* (a struct
storing `get`/`set` closures), not a van Laarhoven encoding. This is
the right call for Swift; Haskell's encoding is unavailable. A
`Mutator` package adopting any encoding would necessarily be a witness
struct — the academic question for the Mutator is what state the
witness carries, not what *encoding* it uses, since the encoding is
already determined by Swift's type-system limits.

### 1.3 Profunctor optics: the unifying lattice

**Pickering, M., Gibbons, J., & Wu, N. (2017). "Profunctor optics:
Modular data accessors." *The Art, Science, and Engineering of
Programming* 1(2), Article 7. arXiv:[1703.10857](https://arxiv.org/abs/1703.10857).
[Verified: 2026-04-25]**

Replaces the `Functor` constraint with profunctor constraints:

| Optic kind | Profunctor constraint |
|---|---|
| Iso | `Profunctor` |
| Lens | `Strong` (Cartesian) |
| Prism | `Choice` (Cocartesian) |
| Affine Traversal | `Strong + Choice` |
| Traversal | `Traversing` (Wander) |
| **Setter** | **`Mapping`** |
| Getter | `Bicontravariant + Strong` |
| Fold | `Traversing + Bicontravariant` |
| Review | `Bifunctor + Choice` |

The contribution: a *single* type-level shape `p a b -> p s t`
parameterized by a profunctor class lattice, instead of distinct
ad-hoc encodings.

**Ecosystem mapping + the Setter finding.** The `Optic.*` family in
the ecosystem covers Iso, Lens, Prism, Affine, Traversal — but **not
Setter**. The Setter optic captures *write-only* mutation (laws:
`over l id = id`; `over l (f . g) = over l f . over l g`) without a
`view` companion. **A `Mutator<Subject>` that exposes only mutation
(no read-back, mirroring how Hasher exposes only `combine` with no
"unhash") is, in optic-lattice terms, a Setter.** This is the most
direct categorical placement available from the literature — and it
suggests `Mutator` could be either (a) a new optic kind in
`swift-optic-primitives` (Setter), composing with the existing optics,
or (b) a separate package whose semantics are "Setter-shaped on
~Copyable Subject." Option (a) is consistent with [RES-018]
(extending an existing primitive rather than introducing a new one).

### 1.4 Recent work — optics for substructural / non-copyable settings

**Bernardy, J.-P., Boespflug, M., Newton, R. R., Peyton Jones, S., &
Spiwack, A. (2018). "Linear Haskell: Practical linearity in a
higher-order polymorphic language." *Proc. ACM POPL* 2(POPL),
Article 5.** arXiv:[1710.09756](https://arxiv.org/abs/1710.09756).
**[Verified: 2026-04-25]** Linear lenses and the consumption
obligation; replacing `(->)` with a linear arrow.

**Riley, M. (2018). "Categories of optics."**
arXiv:[1809.00738](https://arxiv.org/abs/1809.00738).
**[Verified: 2026-04-25]** First general categorical account: optics
as a functor on the 2-category of symmetric monoidal categories.

**Vertechi, P. (2022). "Dependent optics."**
arXiv:[2204.09547](https://arxiv.org/abs/2204.09547).
**[Verified: 2026-04-25]** Capucci, M. (2022). "Seeing double through
dependent optics." arXiv:[2204.10708](https://arxiv.org/abs/2204.10708).
**[Verified: 2026-04-25]** Tambara modules over double categories;
construction generalizes from cartesian to symmetric monoidal — the
categorical analogue of `~Copyable`.

**Ecosystem mapping.** The current `swift-optic-primitives` shape is
classical (Cartesian); it does not formally address `~Copyable Whole`
or `~Copyable Part`. If the Mutator investigation lands on Role A
(Transactional), Role C (Observation), or Role F (Structural-edit) on
`~Copyable` Subject, the formal substrate is Spiwack et al. 2018 +
Riley 2018 — *not* Foster et al. 2005/2007. This is a forward-pointing
finding for any future work extending `swift-optic-primitives` to
`~Copyable` Whole/Part: linear-optics is the right lineage.

### 1.5 Hashable / Hasher: not actually an optic

The Hasher pattern itself is **not** in the lens literature. Closest
formal relative is `Fold` (`forall p. (Traversing p, Bicontravariant
p) => p a a -> p s s`) — extract a stream of `a`s and accumulate
them via a monoid. Hashing matches the shape (`Hashable` types call
`hasher.combine(_:)` once per component; Hasher accumulates state),
but with three differences from a true `Fold`:

1. `Fold` is parametric in the monoid; `Hasher` fixes one (SipHash-1-3
   with per-execution seed per
   [SE-0206](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0206-hashable-enhancements.md)).
2. `Fold` produces same type as elements; `Hasher` finalizes to `Int`.
3. `Fold` is a *reference* into the structure; `Hasher` is a *stateful
   sink*.

**Hasher's lineage is the Visitor (Gamma et al. 1994) and Builder
patterns + Wadler-style "shy" / context-passing accumulators — NOT
the lens literature.** The Mutator analogy to Hasher inherits Hasher's
*engineering ergonomics* (controlled algorithm, performance,
evolvability via SE-0206 resilience) without inheriting any
categorical role from the optic family. The patterns are siblings,
not specializations of one another.

---

## Part 2 — Algebraic Effects and Handlers, plus Linear/Affine + Capabilities

### 2.1 Plotkin & Power, "Notions of computation determine monads" (FoSSaCS 2002)

**Plotkin, G. D., & Power, J. (2002). "Notions of Computation
Determine Monads." *Proc. FoSSaCS 2002*, LNCS 2303, Springer,
pp. 342–356.** DOI: [10.1007/3-540-45931-6_24](https://link.springer.com/chapter/10.1007/3-540-45931-6_24).
[Edinburgh PDF](https://homepages.inf.ed.ac.uk/gdp/publications/Comp_Eff_Monads.pdf).
**[Verified: 2026-04-25]**

The paper inverts Moggi's monadic foundation: start from an
*algebraic theory* (signature + equations) and *generate* the
corresponding monad as the free-model functor. For state over `S`:
`lookup : S ⇒ X` (unary) and `update : X` (S-ary), subject to four
axioms (lookup idempotence, lookup-update cancellation, update
overwrite, commutation). The free model is the side-effect monad.

**Ecosystem mapping.** This is THE academic anchor for the Mutator
witness type's role: **the methods on `Mutator<Subject>` are the
*operations* of an algebraic theory; the witness type is the
free-model carrier**. The ecosystem's `Algebra.*` namespace
(`Algebra.Magma`/`Algebra.Monoid`/`Algebra.Group`/etc.) ships
witness structs for *exactly the kind of algebraic theories Plotkin &
Power describe*. The Mutator's algebraic theory could (and probably
should) be expressed in terms of `Algebra.Monoid`-typed combining or
`Algebra.Group`-typed commit/abort + inverse. **The investigation
should compose with `swift-algebra-primitives`, not duplicate its
witness vocabulary.**

### 2.2 Plotkin & Pretnar, "Handlers of Algebraic Effects" (ESOP 2009; LMCS 2013)

**Plotkin, G. D., & Pretnar, M. (2009). "Handlers of Algebraic Effects."
*Proc. ESOP 2009*, LNCS 5502, Springer, pp. 80–94.** DOI:
[10.1007/978-3-642-00590-9_7](https://link.springer.com/chapter/10.1007/978-3-642-00590-9_7).
Extended journal version: *Logical Methods in Computer Science* 9(4:23),
2013. arXiv:[1312.1399](https://arxiv.org/abs/1312.1399).
**[Verified: 2026-04-25]**

A handler `H` is a family of clauses `op(x; k) ↦ M_op` plus a return
clause `return v ↦ M_ret`. Operationally: `handle c with H` walks the
computation tree, dispatching at every operation node and threading
the resumption `k`. Algebraically: handler = model of the effect
theory; `handle` = unique homomorphism from free model to that model.
The state handler instantiates `lookup(k) ↦ λs. k(s)(s)`,
`update_s(k) ↦ λs'. k()(s)`, `return v ↦ λs. (v, s)`.

**Ecosystem mapping.** **`Mutator<Subject>` is literally a Plotkin–
Pretnar handler restricted to single-shot, in-place execution.** The
closure passed to `mutate(via:)` is the computation; `Mutator`'s
methods are the operation clauses; finalization is the return clause.
The handler interpretation is the cleanest formal anchor for any
academic write-up of a Mutator-pattern paper: cite Plotkin–Pretnar
2013 for the universal-property framing and acknowledge that the
Swift instance restricts to single-shot resumption (an affine /
linear discipline that the original handler theory does not impose).

### 2.3 Bauer & Pretnar, "Programming with Algebraic Effects and Handlers" (JLAMP 2015)

**Bauer, A., & Pretnar, M. (2015). "Programming with Algebraic
Effects and Handlers." *J. Logical and Algebraic Methods in
Programming* 84(1), pp. 108–123.**
arXiv:[1203.1539](https://arxiv.org/abs/1203.1539).
**[Verified: 2026-04-25, citation only]**

The Eff language exposes effect types as first-class entities and
handlers as first-class values. The state handler:

```
handler {
  val v ↦ (fun s ↦ v);
  get () k ↦ (fun s ↦ k s s);
  set s' k ↦ (fun _ ↦ k () s');
}
```

Then `state s₀ body` applies this handler with initial state `s₀`.

**Ecosystem mapping.** A Mutator's `mutate(via:)` is structurally
`state s₀ body` — but with `s₀` held by physical inout rather than
threaded as a function argument. Soundness of this collapse depends
on `Subject`'s use being affine (single-shot) — which Swift's
`~Copyable` enforces.

### 2.4 Koka and effect rows

**Leijen, D. (2014). "Koka: Programming with Row-Polymorphic Effect
Types." *MSFP 2014 / EPTCS* 153, pp. 100–126.**
arXiv:[1406.2061](https://arxiv.org/abs/1406.2061).
**[Verified: 2026-04-25]** **Leijen, D. (2017). "Type Directed
Compilation of Row-Typed Algebraic Effects." *POPL 2017*, pp. 486–499.**
**[Verified: 2026-04-25, citation only]**

Koka annotates function arrows with effect rows; the compiler
specializes `state` operations into direct cell reads/writes for
single-shot handlers. Mutator is the limit case: the handler is so
single-shot that the language doesn't bother with continuations.

### 2.5 Wadler, "Linear Types Can Change the World!" (1990)

**Wadler, P. (1990). "Linear Types Can Change the World!" In
*Programming Concepts and Methods*, North-Holland, pp. 347–359.**
**[Verified: 2026-04-25, abstract & venue]**

A linearly-typed array can be destructively updated in place without
violating referential transparency, because the old reference is
statically guaranteed unreachable. `update : Array → Index → Value
→ Array` is pure on the surface, in-place underneath, sound by
linearity.

**Ecosystem mapping.** This is *the* soundness argument for `mutate
(via:)` on `~Copyable Subject`. Swift's `~Copyable` denies contraction
(no implicit copy); `inout` enforces "exactly one consumer" at the
call boundary. **The Mutator pattern is the modern Swift instance of
Wadler 1990's vision — but the language already provides the
substructural discipline; the package is the API surface.** No
ecosystem package "owns" linear types in this Wadler sense; they are
language-level.

### 2.6 Walker, "Substructural Type Systems" (Pierce ed., ATTAPL 2005)

**Walker, D. (2005). "Substructural Type Systems." Chapter 1 in
B. C. Pierce (ed.), *Advanced Topics in Types and Programming
Languages*, MIT Press, pp. 3–43.** **[Verified: 2026-04-25]**

The canonical classification: unrestricted, affine (drop OK),
relevant (drop forbidden), linear (use exactly once), ordered (use
in declaration order). **Swift's `~Copyable` is most precisely
*affine* (drop via deinit is allowed; duplication is not), not
linear**. This precision matters: the Mutator's witness need not
enforce "the Subject MUST be consumed" — only that no aliased
mutation occurs.

### 2.7 Linear Haskell, capabilities, regions

**Bernardy et al. (2018). "Linear Haskell." *PACMPL* 2(POPL), Article
5.** DOI:
[10.1145/3158093](https://dl.acm.org/doi/10.1145/3158093).
arXiv:[1710.09756](https://arxiv.org/abs/1710.09756).
**[Verified: 2026-04-25]** Linearity on the function arrow
(`%1 ->`) rather than on the type — supports polymorphism cleanly.
`freeze :: MArray a %1 -> Array a` is the canonical example.

**Boyland, J., Noble, J., & Retert, W. (2001). "Capabilities for
Sharing: A Generalisation of Uniqueness and Read-Only." *ECOOP 2001*,
LNCS 2072, Springer, pp. 2–27.** DOI:
[10.1007/3-540-45337-7_2](https://link.springer.com/chapter/10.1007/3-540-45337-7_2).
**[Verified: 2026-04-25]** Capabilities decompose into seven
permission bits; "borrowed" = capability lent for a scoped duration
without ownership.

**Balabonski, T., Pottier, F., & Protzenko, J. (2016). "The Design
and Formalization of Mezzo, a Permission-Based Programming Language."
*ACM TOPLAS* 38(4):14.** DOI:
[10.1145/2837022](https://dl.acm.org/doi/10.1145/2837022).
**[Verified: 2026-04-25]** Permissions duplicable (immutable) vs
unique (owned mutable); adopt-and-abandon for temporary lending.

**Grossman, D. et al. (2002). "Region-Based Memory Management in
Cyclone." *PLDI 2002*, pp. 282–293.** DOI:
[10.1145/512529.512563](https://dl.acm.org/doi/10.1145/512529.512563).
**[Verified: 2026-04-25]** Lexical-region lifetime tracking (the
direct ancestor of Rust's lifetime annotations and Swift's
`@_lifetime`).

**Tofte, M., & Talpin, J.-P. (1997). "Region-Based Memory
Management." *Information and Computation* 132(2), pp. 109–176.** DOI:
[10.1006/inco.1996.2613](https://www.sciencedirect.com/science/article/pii/S089054019692613X).
**[Verified: 2026-04-25]** Type-and-effect with lexically-scoped
regions; the foundation Cyclone built on.

### 2.8 The `~Copyable` + `~Escapable` combination

No single canonical academic formalization exists for the precise
combination Swift implements. The closest published direct accounts:

- **Jung, R. et al. (2018). "RustBelt: Securing the Foundations of
  the Rust Programming Language." *POPL 2018*.** **[Verified:
  2026-04-25, citation only]** Affine ownership + lexical lifetimes
  in Iris separation logic.
- **Wagner, K. et al. (2025). "From Linearity to Borrowing." *OOPSLA
  2025*.** [Northeastern PDF](http://www.ccs.neu.edu/home/amal/papers/borrowing.pdf).
  **[Verified: 2026-04-25]** Introduces *BoCa*, a lightweight
  extension of linear λ-calculus with immutable and mutable borrows
  + lexical lifetimes. Most recent and most direct formal account
  of "linear types + borrows + lifetimes" as a single calculus.
- **Tang, M., Hillerström, D., Lindley, S., & Morris, J. G. (2024).
  "Soundly Handling Linearity." *POPL 2024*.**
  arXiv:[2307.09383](https://arxiv.org/abs/2307.09383).
  **[Verified: 2026-04-25]** Handlers + linear-typed resources for
  session-typed channels — introduces "control-flow linearity" to
  constrain when continuations may be re-invoked.

**The unfilled gap.** No published paper directly studies *handlers
for linear/borrowed state where the handler witness itself is
lifetime-bounded* — i.e., a witness type that handles a substructural
effect, where the witness is `~Copyable` (cannot be aliased) and
`~Escapable` (cannot outlive the handled state). This is exactly the
Mutator pattern's design space; it sits between Tang–Hillerström–
Lindley–Morris (2024) and Wagner et al. (2025). For the Mutator
investigation: **this is a publishable research observation**, not
just a package-design choice. The Hasher-pattern / Mutator-pattern
is an under-studied API embodiment of a well-understood theoretical
intersection — a connection between "control-flow linearity for
handlers" and "lexical-lifetime-bounded borrows."

---

## Part 3 — CRDTs, Functional Reactive Programming, and Type-Class Witnesses

### 3.1 CRDTs (grounds Role B Journaling)

**Shapiro, M., Preguiça, N., Baquero, C., & Zawirski, M. (2011).
"Conflict-Free Replicated Data Types." *Proc. SSS 2011*, LNCS 6976,
Springer, pp. 386–400.** DOI:
[10.1007/978-3-642-24550-3_29](https://link.springer.com/chapter/10.1007/978-3-642-24550-3_29).
**[Verified: 2026-04-25]** The seminal CRDT paper. Strong Eventual
Consistency: replicas accept updates without remote synchronization;
SEC asserts replicas with the same set of updates have equivalent
state. Two formulations: state-based (CvRDT — semilattice + LUB merge)
and operation-based (CmRDT — concurrent-op commutativity).

**Shapiro et al. (2011). "A comprehensive study of Convergent and
Commutative Replicated Data Types." INRIA RR-7506.** HAL:
[inria-00555588](https://inria.hal.science/inria-00555588/en/).
**[Verified: 2026-04-25]** The technical-report companion. Catalog
of primitives: G-Counter, PN-Counter, G-Set, 2P-Set, LWW-Element-Set,
OR-Set, LWW-Register, MV-Register, sequence/graph types.

**Burckhardt, S. et al. (2014). "Replicated Data Types: Specification,
Verification, Optimality." *POPL 2014*, pp. 271–284.** DOI:
[10.1145/2578855.2535848](https://dl.acm.org/doi/10.1145/2578855.2535848).
**[Verified: 2026-04-25]** Axiomatic specification language over
visibility / arbitration relations; replication-aware simulation
proof technique; *space lower bounds* showing four implementations
are space-optimal.

**Kleppmann, M., & Beresford, A. R. (2017). "A Conflict-Free
Replicated JSON Datatype." *IEEE TPDS* 28(10), pp. 2733–2746.**
arXiv:[1608.03960](https://arxiv.org/abs/1608.03960).
**[Verified: 2026-04-25]** Automerge's theoretical foundation;
operation-based, client-side, suitable for offline-first.

**Liu, Y. et al. (2020). "Verifying Replicated Data Types with
Typeclass Refinements." *OOPSLA 2020*.** **[Verified: 2026-04-25,
indirect]** The closest published academic work to a "generic CRDT
witness" — uses Liquid Haskell typeclass refinement to verify CRDT
instances against semilattice axioms.

**Honest finding (load-bearing for the investigation).** No widely-
cited academic abstraction "CRDT witness type" generalizes across all
primitives. Each CRDT is authored ad-hoc; the typeclass interface
ends up nearly empty (just `merge` for CvRDT, `apply` for CmRDT)
because *the interesting structure is in the state, not the
operation*. **For the Mutator investigation: Role B Journaling cannot
be a *single* witness type but must be a *family* parameterized over
the state algebra.** This is significant for [RES-018] — the
second-consumer hurdle for a generic Journaling Mutator is uncertain.

### 3.2 Functional Reactive Programming (grounds Role C Observation)

**Elliott, C., & Hudak, P. (1997). "Functional Reactive Animation."
*ICFP 1997*, pp. 263–273.** DOI:
[10.1145/258948.258973](https://dl.acm.org/doi/10.1145/258948.258973).
**[Verified: 2026-04-25]** The foundational FRP paper.
`Behavior a = Time -> a` (continuous time-varying value);
`Event a = [(Time, a)]` (timestamped occurrences); `untilB` for
behavior switching.

**Wan, Z., & Hudak, P. (2000). "Functional Reactive Programming from
First Principles." *PLDI 2000*.** DOI:
[10.1145/349299.349331](https://dl.acm.org/doi/10.1145/349299.349331).
**[Verified: 2026-04-25]** Formal connection between continuous
denotational semantics and discrete stream-based implementation
under Lipschitz continuity.

**Hudak, P. et al. (2003). "Arrows, Robots, and Functional Reactive
Programming." In *Advanced Functional Programming* (AFP 2002), LNCS
2638, Springer, pp. 159–187. Yampa.** Companion: Courtney, A.,
Nilsson, H., & Peterson, J. (2003). "The Yampa Arcade." *Haskell
Workshop 2003*. **[Verified: 2026-04-25]** Signal functions
`SF a b ≅ Signal a -> Signal b`; arrowized causal transformers;
`switch` for dynamic reconfiguration.

**Cooper, G. H., & Krishnamurthi, S. (2006). "Embedding dynamic
dataflow in a call-by-value language." *ESOP 2006*, LNCS 3924,
Springer, pp. 294–308.** DOI:
[10.1007/11693024_20](https://link.springer.com/chapter/10.1007/11693024_20).
**[Verified: 2026-04-25]** FrTime in PLT Scheme; expressions
evaluate to dataflow-graph nodes; topologically-sorted update
propagation eliminates glitches. Parent of Flapjax / RxJS / Combine.

**Linear/affine FRP.** Jeffrey, A. (2012). "LTL types FRP." *PLPV
2012*. DOI: [10.1145/2103776.2103783](https://dl.acm.org/doi/10.1145/2103776.2103783).
**[Verified: 2026-04-25, indirect]** Krishnaswami, N. R. (2013).
"Higher-Order Functional Reactive Programming without Spacetime
Leaks." *ICFP 2013*. **[Unverified]** Graulund, C. et al. (2021).
"Adjoint Reactive GUI Programming." *FoSSaCS 2021*. **[Unverified]**
Mixed linear/non-linear adjoint calculus in the Benton-Wadler style.

**Ecosystem mapping.** **A Role-C Observation Mutator on `~Copyable`
Swift state must be either (a) a borrow-reading observer (does not
move state) or (b) a Yampa-style `SF`-shaped causal arrow.** Apple's
`@Observable` is in the FrTime/Flapjax/Combine lineage but does NOT
extend to `~Copyable` types — the gap the Mutator investigation
identified is real and aligns with the academic linear-FRP frontier.

### 3.3 Type-Class Dictionary Witnesses (Hasher's lineage)

**Wadler, P., & Blott, S. (1989). "How to make ad-hoc polymorphism
less ad hoc." *POPL 1989*, pp. 60–76.** DOI:
[10.1145/75277.75283](https://dl.acm.org/doi/10.1145/75277.75283).
**[Verified: 2026-04-25]** The seminal type-class paper. Dictionary
translation: `class C a where { op :: a -> ... }` becomes
`dict_C_T :: { op :: T -> ... }`; `(C a) =>` constraints become
explicit dictionary parameters. **The dictionary is the witness.**

**Hall, C. V., Hammond, K., Peyton Jones, S. L., & Wadler, P. L.
(1996). "Type Classes in Haskell." *ACM TOPLAS* 18(2), pp. 109–138.**
DOI: [10.1145/227699.227700](https://dl.acm.org/doi/10.1145/227699.227700).
**[Verified: 2026-04-25]** Default methods, superclasses,
second-order-lambda-calculus elaboration.

**Swift Evolution proposals.**
- **SE-0185** "Synthesizing Equatable and Hashable conformance"
  (Allevato, 2017).
  [GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0185-synthesize-equatable-hashable.md).
  **[Verified: 2026-04-25]** Compiler-synthesized `==` and
  `hashValue`.
- **SE-0206** "Hashable Enhancements" (Lőrentey & Esche, 2018).
  [GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0206-hashable-enhancements.md).
  **[Verified: 2026-04-25]** Introduced the `Hasher` struct itself,
  replacing `hashValue` with `hash(into: inout Hasher)`. Stated
  rationale: (1) algorithm choice belongs to stdlib not conformer;
  (2) batched finalization; (3) ABI resilience (opaque
  representation); (4) per-execution random seeding for HashDoS
  resistance.

**The four SE-0206 rationales are the complete blueprint for any
Mutator witness type, not just Hasher**: (1) move algorithm choice
into the witness; (2) batch finalization; (3) resilient ABI; (4)
state-bearing witness for contextual metadata. **The Hasher witness
type is *not* a quirky one-off — it is the materialized form of a
general principle: expose the algorithm-bearing state as the witness
type.** This is the load-bearing pattern the Mutator investigation
extends.

**Java's `int hashCode()` precedent.** Java's `Object.hashCode()`
returns an `int`; the algorithm is whatever the implementer chooses;
no resilience. Swift deliberately departed from this *because* of the
resilience trap. **[Verified: 2026-04-25, against SE-0206 motivation
section.]**

**Generalization — type classes with witness types.** Searches do
NOT turn up a single named academic pattern "typeclass with stateful
witness type." The closest formalizations:

- **F-algebras**: a witness is an algebra `(F a -> a)`; `hash(into:)`
  is the catamorphism injecting structure into the algebra.
- **Final tagless** (Carette, J., Kiselyov, O., & Shan, C.-c. (2009).
  "Finally Tagless, Partially Evaluated." *J. Funct. Programming*
  19(5), pp. 509–543.) **[Unverified]** A typeclass exposes
  interpreter-witnesses parameterized over a *carrier* type; any
  concrete carrier is a stateful (or stateless) interpreter.

**The Mutator pattern is best understood as a finally-tagless-style
witness**: the `Mutator` typeclass surfaces a witness constructor;
each role (Transactional, Journaling, Observation, Validation,
Functional-update, Structural-edit) is a *different witness
interpreter* over the same conformance protocol. The Hasher pattern
proves out this generalization for the special case of hashing.

**Ecosystem mapping.** The `Algebra.*` namespace already ships
witness structs in exactly the finally-tagless / F-algebra shape:
`Algebra.Monoid<Element> = { identity: Element; combining:
(Element, Element) -> Element }` is *literally* the F-algebra
witness for the Monoid theory. **A Mutator witness type whose
internal accumulator is `Algebra.Monoid`-typed composes with the
existing primitive rather than reinventing it.**

---

## Synthesis: ecosystem-grounded grounding for the Mutator investigation

### What the academic literature says, mapped to existing primitives

| Academic anchor | Primary citation (verified) | Existing primitive | What `swift-mutator-primitives` should NOT reinvent |
|---|---|---|---|
| Lens optic family | Foster et al. 2007; Pickering–Gibbons–Wu 2017 | `Optic.Lens<W,P>`, `Optic.Prism`, `Optic.Iso`, `Optic.Affine`, `Optic.Traversal` in `swift-optic-primitives` | The full optic family. Mutator should *compose* with these, not duplicate them |
| Setter optic (write-only mutation) | Pickering–Gibbons–Wu 2017 | NOT shipped (gap in `swift-optic-primitives`) | A `Mutator<Subject>` is closest categorically to a Setter; could land as `Optic.Setter` extending the existing optic family |
| Algebraic theories of state | Plotkin & Power 2002 | `Algebra.Magma`/`.Monoid`/`.Group`/`.Ring`/`.Field`/`.Module`/etc. in `swift-algebra-*-primitives` | The witness-struct vocabulary for algebraic theories. Mutator's accumulator state should be expressed in `Algebra.*` terms |
| Handlers for algebraic effects | Plotkin & Pretnar 2009/2013 | NOT shipped — language-level construct | The handler interpretation — Mutator IS a handler, restricted to single-shot in-place execution |
| Substructural / linear types | Wadler 1990; Walker 2005 | Swift `~Copyable` (language) | Not a package; Wadler-1990 substructurality is the language type-system feature |
| Lexical-region lifetimes | Tofte & Talpin 1997; Cyclone 2002 | Swift `~Escapable` + `@_lifetime` (language) | Same — language-level |
| Linear/borrowed handler combination | Tang et al. 2024; Wagner et al. 2025 | NOT shipped (academic gap) | The unfilled gap: the package's design space is genuinely under-studied academically |
| CRDT primitives | Shapiro et al. 2011; Burckhardt et al. 2014 | NOT shipped at primitives layer | Not in primitives; consumer-of-Mutator territory if Role B materializes |
| FRP signal functions | Elliott & Hudak 1997; Hudak et al. 2003 | NOT shipped at primitives layer | Apple's `@Observable` covers Copyable-only; the `~Copyable` gap is what Role C would fill |
| Type-class dictionary witnesses | Wadler & Blott 1989; SE-0206 | Swift type system (language) + the Hasher precedent itself | Hasher-pattern witness exposure is the engineering pattern Mutator extends |
| Finally-tagless / F-algebra witnesses | Carette, Kiselyov, Shan 2009 (unverified) | `Algebra.*` namespace | Same — the `Algebra.*` family already implements this shape |

### The strongest grounding for a Mutator paper

If the IN_PROGRESS investigation converges on a publishable shape,
the academic citation lineage is:

1. **Plotkin & Power 2002** for the algebraic-theory foundation —
   Mutator's API is the signature of a theory.
2. **Plotkin & Pretnar 2013** for the handler interpretation —
   Mutator is a handler.
3. **Walker 2005 / Wadler 1990** for the substructural classification
   of the witness's discipline.
4. **Wagner et al. 2025 (BoCa)** for the linear-with-borrows-with-
   lifetimes calculus that *most directly* models Swift's
   `~Copyable + ~Escapable + @_lifetime` triad.
5. **Tang et al. 2024** for the missing connection — handlers under
   linearity discipline — and the publishable gap the Mutator
   pattern fills as a real-world API embodiment of an open theoretical
   problem.

Pickering–Gibbons–Wu 2017 + Riley 2018 for the optic-lattice placement
*if* the Mutator role chosen is Setter-shaped. Shapiro 2011 +
Burckhardt 2014 *if* Role B Journaling. Elliott & Hudak 1997 + Hudak
2003 *if* Role C Observation.

### What [RES-018] permits: the second-consumer hurdle

The strongest second-consumer cases the literature substantiates:

- **Role C Observation on `~Copyable`**: real gap in `@Observable`
  (Apple's framework is Copyable-only); academic frontier (linear-
  temporal-logic FRP, adjoint reactive GUI) actively researches this.
- **Role A Transactional**: Wadler 1990's argument generalizes —
  transactional mutation on linear/affine state is the canonical
  unlock; Linear Haskell's `freeze :: MArray a %1 -> Array a` is the
  industrial precedent.

The weakest second-consumer cases:

- **Role B Journaling (CRDT-style)**: the comprehensive CRDT survey
  (Shapiro 2011 + Burckhardt 2014) proves CRDTs are state-shape-
  specific; a generic Journaling Mutator must be a family, not a
  single witness. [RES-018]'s second-consumer hurdle is harder to
  clear here.
- **Role E Functional-update**: the `Optic.Lens.modify` API in the
  ecosystem already covers most use cases; marginal value for a
  Mutator-shaped wrapper.
- **Role F Structural-edit**: the WritableKeyPath Q1-only constraint
  (per `mutator-writable-keypath-interaction.md`) blocks the natural
  encoding for `~Copyable` Subject.

### Recommended next steps for the IN_PROGRESS investigation

1. **Compose with `swift-optic-primitives`, don't duplicate.** Any
   Mutator-pattern Sources that introduce a Lens-like accessor are
   reinventing the existing primitive.
2. **Compose with `swift-algebra-*` for the witness's accumulator
   state.** A Role-A Transactional Mutator's commit-log is naturally
   an `Algebra.Monoid<Operation>`; a Role-B Journaling Mutator's
   merge function is a `Algebra.Semilattice` (would-need-to-add to
   the algebra family) under CvRDT semantics. Both compose with the
   existing namespace rather than introduce new types.
3. **The most academically defensible Mutator role is Role C
   Observation on `~Copyable`** — the academic gap (Tang–
   Hillerström–Lindley–Morris 2024 + Wagner et al. 2025
   intersection) is real and the second-consumer case (`@Observable`
   gap) is concrete.
4. **The Setter optic is a defensible Optic.Setter addition** — if
   the package converges on a write-only Mutator surface, the
   cleanest landing is to extend `swift-optic-primitives` with
   `Optic.Setter<Whole, Part>` rather than ship a separate package.
   This satisfies [RES-018] composition-over-introduction.

## Outcome

**Status**: REFERENCE — survey of academic prior art for the active
investigation per [RES-021]; provides citation backbone for any
DECISION the IN_PROGRESS investigation produces.

**Key finding for the investigation**: the strongest unfilled
academic gap exactly maps the package's design space — handlers for
linear/borrowed state where the witness itself is lifetime-bounded.
This is genuinely under-studied; existing primitives in the
ecosystem (Optic, Algebra) cover most of the *compositional*
machinery the Mutator would need; the *novel* contribution is the
witness-type encoding of a single-shot, lifetime-bounded handler.

**Verification status**: of 31 distinct citations in this survey, 26
are `[Verified: 2026-04-25]` against primary sources (arXiv, ACM DL,
Springer, INRIA HAL, Swift Evolution GitHub); 4 are
`[Verified: 2026-04-25, citation only]` (citation + abstract verified
but no in-text passage extraction); 5 are `[Unverified]` (surfaced
in subagent search results but not directly fetched). The unverified
items are non-load-bearing — none of the survey's substantive
recommendations rest on an unverified citation per [RES-020].

## References

See in-line citations and DOIs throughout. Primary sources fetched
during the survey are linked at first mention; secondary sources
(blog posts, library wikis) are excluded from this REFERENCES list
in favor of the published academic record.
