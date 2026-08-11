# Initialization Primitives: Improvement Analysis and Prior-Art Survey

<!--
---
version: 1.0.0
last_updated: 2026-05-30
status: RECOMMENDATION
tier: 2
scope: cross-package
trigger: "Post-restructure improvement study requested by principal (2026-05-30), immediately after swift-initialization-primitives was decomposed into the operation-domain normal form (HEAD 4e3ddf0). Includes a literature study / prior-art survey, with the iterator-primitives operation-domain pattern as the internal anchor."
methodology: "research-process skill. Internal corpus grep first ([RES-019]); external prior-art survey with independent parallel primary-source verification ([RES-020]/[RES-021]); empirical package-state claims verified at write time ([RES-023])."
---
-->

## Context

`swift-initialization-primitives` (L1 / Primitives) was just decomposed into the
ecosystem's **operation-domain normal form** (`operation-domain-naming-and-organization.md`,
HEAD `4e3ddf0`), mirroring `swift-iterator-primitives`:

| Role | Symbol |
|------|--------|
| Namespace (deverbal noun — *relation/value* domain) | `enum Initialization` |
| Active protocol + gerund alias | `Initialization.\`Protocol\`` / `Initializing` — `borrowing func make() throws(Failure) -> Element` |
| Witness (nested, plain `Copyable`) | `Initialization.Witness<Element, Failure>` |
| Passive attachable (top-level `-able`) | `Initiable` — `associatedtype Failure: Swift.Error = Never; init() throws(Failure)` |
| Passive→active bridge (`where Self: Copyable`) | `Initiable.initializer -> Initialization.Witness<Self, Failure>` |
| Standard-library integration (empty-only) | `Array`, `ContiguousArray`, `ArraySlice`, `Set`, `Dictionary`, `String`, `Substring` |

The shape is settled. This document asks the orthogonal question the naming spec
explicitly fences out (§11, "the protocol-*contract* axis … deferred to a future
protocol-architecture piece"): **given the correct shape, how should the package
be improved — in semantics, breadth, and sibling parity — and what does prior art
teach?**

The study was prompted by two recurring principal questions during the restructure:
(1) the empty-vs-default boundary of the standard-library integration (why scalars
and `Optional` are excluded), and (2) whether the orphaned generic `Buildable`
relates correctly to the live family-specific set builder.

## Question

1. **Semantic identity ([RES-029]).** Is `Initiable.init()` a *monoid identity* (`mempty`), an arbitrary *`Default`*, or `AdditiveArithmetic.zero`? This determines everything downstream.
2. **Breadth.** Which stdlib types should conform `Initiable`, and why are scalars / `Optional` excluded?
3. **Combinators.** Should the active `Initialization.\`Protocol\`` / `Initialization.Witness` grow terminals/combinators (the way `Iterable` has `forEach`/`reduce` and `Parser` has a combinator family)? Which are *coherent*?
4. **Ergonomics.** `Sendable`, move-only (`~Copyable`) element production, the `Copyable`-gated bridge.
5. **`Buildable` reconciliation.** How should the orphaned generic `Buildable: Initiable` relate to the live family-specific `Set.Buildable.\`Protocol\`` + `Set.Builder`?

## Analysis

### 1. Internal prior art (governs — [RES-019])

Per [RES-019], the internal corpus was surveyed before any external source; where
internal research conflicts with external commentary, internal governs.

| Document | Governing finding | Bearing |
|----------|-------------------|---------|
| `operation-domain-naming-and-organization.md` (tier 3, DECISION) | Initialization is the **relation/value** sub-class; the protocol-*contract* axis (terminals, `~Copyable` support, what `make()` requires) is **out of scope** of the naming spec. | This doc is (part of) that deferred contract-axis analysis, scoped to initialization. |
| `cross-layer-capability-protocol-model.md` (tier 3, RECOMMENDATION, supervisor-approved 2026-05-28) | The capability-protocol **normal form**: a core declares only its *irreducible primitives* and PROVIDES only derivations from its own requirements; every larger family attaches **orthogonally** (`extension P where Self: Q`), never baked into the core. "refine only when the type's identity IS the supertype's concern; compose otherwise." Diagnosed the root error: "set algebra was baked into `Set.Protocol`'s requirements when it is a third orthogonal concern." | Decides combinator *placement* (Witness/extension, not Protocol requirement) and the empty-vs-default layering (orthogonal axes, do not conflate). |
| `self-projection-default-pattern.md` (tier 2, CONFIRMED Swift 6.3.1) | The self-projection-default pattern fits only when the associated type is a *projection of Self*; §V5 "DOES NOT FIT" when it is an *attribute/output of the conformer*. | `Initialization.Witness<Element, Failure>` is parameterized over what it **produces** (output-containment) → §V5. The existing `Initiable.initializer` computed-property bridge is the correct shape; a `Witnessed = Initialization.Witness<Self>` associatedtype default would be **wrong**. `[Verified: 2026-05-30]` |
| `labeled-cross-domain-init-convention.md` (tier 2, DECISION) + `cross-domain-init-overload-resolution-footgun.md` | Init *shape* encodes a semantic contract; unlabeled `init(_:)` + literal conformance caused a confirmed runtime crash via silent overload selection. | The package's **nullary** `init()` / `make()` are *immune* to that footgun (no parameter to mis-infer) — a point in favor of keeping the surface nullary. |

`[Verified: 2026-05-30]` The ecosystem already ships the monoid-identity shape:
`Algebra.Monoid` ("a semigroup with an identity element … `e` such that `e ∗ a = a ∗ e = a`")
with an `.identity` accessor, at
`swift-algebra-primitives/Sources/Algebra Monoid Primitives/Algebra.Monoid.swift`.

### 2. Prior-art survey (external — [RES-021], independently verified [RES-020])

Each external claim below was produced by a survey agent citing a primary source,
then **independently re-verified** by a separate agent re-fetching that source on
2026-05-30. All load-bearing claims came back CONFIRMED (two non-load-bearing
paraphrase nits flagged and corrected; no fabricated sources/versions/APIs). The
Rust `Default` survey agent failed to return structured output; its substance is
covered by the FP/category-theory and provider surveys, and the one Rust fact used
below (`Default` is a per-type trait, each collection's `default()` == empty) is
marked accordingly.

| Tradition | Mechanism (primary source) | Finding | Lesson | Verdict |
|-----------|---------------------------|---------|--------|---------|
| Swift stdlib | `RangeReplaceableCollection.init()` ("Creates a new, empty collection") | Empty-`init()` is legitimate stdlib practice **scoped to a growable discipline**; stdlib *fuses* empty+grow on one protocol. | `Initiable`'s closest analogue. The Institute *splits* empty (`Initiable`) from grow (family `insert`/`append`) — the more orthogonal decomposition. The empty-only conformer set is exactly the RangeReplaceable/SetAlgebra family. | CONFIRMED ×2 |
| Swift stdlib + Evolution | `AdditiveArithmetic.zero` (SE-0233) | SE-0233 **rejected** `init()`, using a **named** `static var zero` instead, to avoid the `Matrix()` zero-vs-identity ambiguity. | **Decisive on Q1.** The stdlib faced the exact empty-vs-default-vs-`init()` fork and resolved it by *not* using `init()`, using a *named* requirement, and binding it to an algebraic structure. A numeric default must NOT fold into `Initiable.init()`. | CONFIRMED ×2 |
| Swift Forums | Three stalled pitches for `protocol DefaultConstructible { init() }` (threads 4771 / 12263 / 53723) | Core-team objection (Abrahams, Wu, Lattner): `init()` has **no universal semantics**; "identities are associated with (type, operation) pairs, not types alone"; legitimate only domain-scoped (collections=empty, integers). Recurring counter-recommendation: **pass `() -> T`** rather than constrain `T`. | **The single most important external finding — it validates the current design.** A bare `init()` capability protocol is coherent only domain-scoped; `Initiable`'s narrow scoping (with scalars/`Optional` excluded) is precisely the carve-out the core team endorsed. `Initialization.Witness` *is* the endorsed `() -> T`. | CONFIRMED ×2 |
| Swift stdlib | `ExpressibleByNilLiteral: ~Copyable, ~Escapable { @_lifetime(immortal) init(nilLiteral: ()) }` | A single-canonical-value `init` protocol already migrated to `~Copyable, ~Escapable` with `@_lifetime(immortal)`. | Worked template for the `~Escapable` question (Q4/OPT-9): the mechanism to admit non-escapable conformers is `@_lifetime(immortal)` on `init()`. The stdlib is *moving toward* the Institute's posture. Also corroborates excluding `Optional`: `nil` = *absence* (a default), not an empty. | CONFIRMED ×2 |
| Haskell | `Monoid`'s `mempty` (`base` Data.Monoid) — two-sided identity of an associative op (`x <> mempty == x`) | `Set()`/`[]`/`""`/`Dictionary()` are each the `mempty` of a monoid (union/concat/merge). | **Q1 answer.** `Initiable.init()` **IS `mempty`** — the identity element of a grow monoid — not a `Default`. The excluded scalars are excluded because they have **no single** canonical monoid identity: `Int` has Sum-`0` *and* Product-`1`; `Bool` has Any-`False` *and* All-`True`. That ambiguity is *why* they are correctly excluded. | CONFIRMED ×2 |
| Haskell | `Alternative`'s `empty` (a producer that produces *nothing* — `[]`/`Nothing`) | Monoid structure lifted to producers; `empty` is a *failing/zero* producer. | **Decisive on Q3.** `make()` is **total** (must always yield an `Element`), so a monoidal `empty`/zero *producer* combinator is **incoherent** here (it would have to fail). `orElse`/`fallback` (semigroup of total producers, no identity) and `map` are coherent. | CONFIRMED ×2 |
| Haskell | `data-default`'s `Default`/`def` + its community critique | Documented as **lawless**; criticized ("no universal default", "makes incorrect code typecheck", "you never abstract over it"). Its most-criticized instances are `Int`, `Bool`, `Maybe`, `()`. | **Cautionary tale that vindicates the exclusions.** `data-default` IS the `Defaultable`/`Zeroable` axis in pure lawless form, and its worst instances are exactly the types `Initiable` excludes. Do **not** add a lawless `Defaultable { static var default }`. "you never abstract over it" = the [RES-018] second-consumer gate restated. | CONFIRMED ×2 |
| Scala (Cats) | `Monoid[A].empty` ("the identity element for this monoid") | Cats keeps the **lawful** type-class `empty` (Monoid) separate from arbitrary per-call defaults (default *arguments*). | Cross-language consensus corroborating Haskell: canonical-empty belongs on a lawful capability; arbitrary defaults belong at the call site, never as a protocol. | CONFIRMED ×2 |
| Category theory (nLab) | *Global element / pointed object*: a point is a morphism `1 -> X` from the **terminal** object; a pointed object carries a basepoint as **structure, not a property**. | A `() -> Element` thunk is a **global element / point**; a type bearing a bare `init()` is a **pointed object**, which is **lawless** (basepoint is structure, not a law). | Pins the categorical identity: `mempty` (Monoid, law-bearing) is the **lawful species**; pointed-object/`Default` is the **lawless genus**. Frame `Initiable` as `mempty`, never as `def`. | CONFIRMED ×2 |
| Java/Guice/Guava/C++ | The `() -> A` provider lineage: `Supplier<T>`, JSR-330/Guice `Provider<T>` (zero combinators), Guava `Suppliers` (combinators in a *separate* layer), C++ `std::function` (copyable) vs `std::move_only_function` C++23 | The bare nullary-producer abstraction stays **combinator-free** on the core interface; combinators live on a separate layer. C++23's `function`/`move_only_function` split is the direct precedent for the `~Copyable` story. | Combinators belong on the concrete `Witness`, not on `Initialization.\`Protocol\``. The `~Copyable` story is an **additive move-only witness**, not a relaxation of the `Copyable` bridge. `throws(Failure)` is a genuine advance over the entire provider lineage (none has a typed error channel). | CONFIRMED ×2 |
| Kotlin/Rust | `lazy`/`Lazy`, `LazyCell`/`OnceCell.get_or_try_init` | A **memoized** provider (compute-once-cache, retry-on-failure) is a *distinct* capability from a re-producing one. | `memoize` is the one combinator that *changes* the capability; it is stateful/likely-not-`Copyable`, so it belongs on a *distinct* memoized witness, never the plain `Copyable` `Witness`. Thread-safety modes are a deliberate Foundation-free boundary (out of scope at L1). | CONFIRMED ×2 |
| pointfree swift-dependencies / SwiftUI | `DependencyKey.liveValue` (`associatedtype Value: Sendable`), `EnvironmentKey.defaultValue` | Every mainstream *default-value* mechanism uses a **named static** keyed by an associated type, never a bare `init()`; pointfree **requires** `Value: Sendable`. | Corroborates that `init()` is reserved-for-empty and named-statics are the default idiom. For `Sendable` (Q4): the Institute's *conform-not-require* posture ([MEM-SEND-012]/[013]) means a **conditional** `Sendable` on the witness gated on a `@Sendable` closure — never a requirement (the opposite of pointfree). | DependencyKey CONFIRMED ×2; EnvironmentKey declaration confirmed via OSS re-implementations |

**Contextualization step ([RES-021]).** The pattern *universally adopted elsewhere
but absent here* is a general `Default`/`def`. Concretized in the Institute type
system it would be `protocol Defaultable { static var `default`: Self { get } }` —
and the survey shows its cost is precisely the lawlessness Haskell's `data-default`
and category theory both condemn: it "makes incorrect code typecheck", admits the
ambiguous scalars, and has no consumer that can't take the value as a parameter.
Universal adoption (Rust `Default`, `data-default`) is **not** universal necessity:
the absence of a general `Defaultable` here is a *deliberate, vindicated* design
decision, and the one lawful slice anyone actually needs (the monoid identity) is
already shipped as `Algebra.Monoid.identity`.

### 3. Semantic-identity determination ([RES-029] — drive on identity first)

**`Initiable.init()` is `mempty`: the two-sided identity element of a type's grow
monoid (union / concatenation / key-merge) — not a `Default`, not `AdditiveArithmetic.zero`.**

Four independent traditions converge (every primary source verified twice): the
Swift core team's explicit `init()`-protocol rejection (named `zero`, stalled
`DefaultConstructible` pitches on "(type, operation) pairs, not types alone"),
Haskell `Monoid`, the `data-default` lawlessness critique + Scala Cats, and the
category-theoretic result that a bare `init()` is a lawless *pointed object* while
`mempty` is the lawful species. The package's prose currently **hedges** —
`Initiable.swift:22` says "empty (or default) value" `[Verified: 2026-05-30]` —
while its conformer set is empty-only. That is a latent trap: a future contributor
reads "or default" and adds `extension Int: Initiable`, silently widening the
protocol's meaning into the exact lawless territory prior art condemns.

### 4. Improvement options

| # | Option | Recommendation | Confidence |
|---|--------|----------------|------------|
| OPT-1 | Commit `Initiable` to **`mempty`** semantics in prose; purge the "or default" hedge; cross-reference `Algebra.Monoid.identity`. | **DO FIRST** — keystone, doc-only, zero risk | HIGH |
| OPT-2 | Reconcile the orphaned generic `Buildable` vs the live family-specific `Set.Buildable.\`Protocol\``. | **SURFACE-and-STOP** (class-(c) ecosystem decision) | MED-HIGH (diagnosis) |
| OPT-3 | Add `Initialization.constant(_:)` / `Always` — the constant/injection witness. | DO (smallest, highest-parity additive win) | HIGH |
| OPT-4 | Add `map` (and `orElse`) on the produced value, **on the Witness, never as Protocol requirements**. | DO `map`; DEFER `tryMap`+ on [RES-018] | HIGH (placement) |
| OPT-5 | Promote `Failure` to a primary associated type: `protocol Initiable<Failure>`. | DO (mechanical; removes active/passive asymmetry) | MED-HIGH |
| OPT-6 | Document the passive-side divergence (`Initiable` deliberately carries no machine-reference requirement). | DO (symmetric to the recorded active-side divergences) | HIGH |
| OPT-7 | **Experiment**: can a non-closure (metatype/inline) witness carry `~Copyable` `Element` and ungate the bridge? | DISPATCH bounded experiment | LOW-MED (ungate); HIGH (separate witness shape) |
| OPT-8 | Conditional `Sendable` on `Initialization.Witness` gated on `@Sendable` storage. | ESCALATE (tower-wide witness posture) | HIGH (shape); LOW (local) |
| OPT-9 | Document the SLI **exclusion rationale** (conform iff `mempty` of a single canonical monoid); surface `Empty: Initiable` as a coupled `~Escapable` decision. | DO doc; SURFACE `Empty` conformance | HIGH (doc); MED (conformance) |
| OPT-10 | Add a hand-written `Initializing` fixture that **produces a `~Copyable` Element** (compile-prove the headline capability). | DO (closes a real test gap) | HIGH |

**Coherent-combinator boundary (OPT-3/4), settled formally, not by taste:**
- ✅ `constant`/`Always` (a *point* — categorically `1 -> Element`; Guava `ofInstance`; `Parser.Always`/`Iterator.repeating` sibling).
- ✅ `map` (functor over the produced value; the one combinator that transfers cleanly to a nullary producer).
- ✅ `orElse`/`fallback` (semigroup of *total* producers over the `Failure` channel; the typed-throws analogue of `RawRepresentable`'s `init?` recovery).
- ❌ A monoidal **empty/zero producer** — incoherent: `make()` is total (Alternative `empty` would have to fail).
- ❌ `contramap` — a nullary producer has no input to contramap.
- ❌ `retry` — subsumed by `orElse`; a stateless nullary factory has nothing to retry against. (`memoize` is a *separate, stateful, non-`Copyable`* witness, not a combinator on this one.)

**Placement is fixed by both the internal normal form and three external data points:**
combinators live on the concrete `Initialization.Witness` (and protocol-extension forms
returning `Witness`), **never** as `Initialization.\`Protocol\`` requirements — exactly
as `Iterable` puts terminals in `Iterable+ForEach.swift` etc. and as Java/Guice/C++
keep the provider core combinator-free.

## Outcome

**Status: RECOMMENDATION.** The package's *shape* is already correct and faithfully
reconciled to the governing research; the improvements concern *semantics*, *breadth*,
and *sibling parity*. Structural-correctness-first ordering ([RES-022]):

1. **Settle semantic identity (OPT-1, HIGH, do first).** `Initiable.init()` = `mempty`. Doc-only; every later decision inherits the vocabulary.
2. **Surface the orphaned `Buildable` (OPT-2).** Recommend: deprecate/justify the generic `Buildable` per [RES-018]; refine `Set.Buildable.\`Protocol\`.init()` onto `Initiable` (low-risk init-only reuse). Class-(c) — surface-and-stop; do not auto-execute. Defer Builder-grammar unification.
3. **Restore sibling parity (OPT-3 + OPT-4-`map`).** Constant witness + `map`/`orElse` on the Witness.
4. **Clean up asymmetries / gaps (OPT-5, OPT-6, OPT-9-doc, OPT-10).**
5. **Dispatch the one experiment (OPT-7); escalate the two ecosystem questions (OPT-8, Defaultable).**

### Premises vs directions ([RES-027])

**Load-bearing premises (settled by verified prior art / grep — no experiment needed):**
- **P1** `Initiable == mempty` (settled; OPT-1 inherits everything).
- **P2** A monoidal empty *producer* is incoherent (`make()` total); `map`/`orElse` are the coherent set (settled by Alternative + category theory).
- **P3** Combinators/`Sendable` belong on the Witness / as conditional conformances, never as Protocol requirements (settled by the normal form + three external data points).
- **P4** The generic `Buildable` has **zero production conformers** and parallels the live family-specific set builder `[Verified: 2026-05-30]` (diagnosis is a premise; the *resolution mechanism* is a direction).

**Directions (deferrable; a wrong guess is cheap):**
- **D-A** the `~Copyable` witness story (OPT-7) — needs an experiment, but nothing downstream blocks on it (the `Copyable` witness + gated bridge are already correct).
- **D-B** `Buildable` resolution mechanism (deprecate vs refine vs unify-grammars).
- **D-C** per-type SLI breadth additions (each [RES-018]-gated; the *breadth rule* — conform iff `mempty` of a single canonical monoid — is itself premise-grade).
- **D-D** `Failure` as a primary associated type (OPT-5) — reversible, symmetry-driven.

### Ecosystem-wide escalations ([RES-004b] — belong in `swift-institute/Research`, not here)

- **E1 — a separate `Defaultable`/`Zeroable` axis.** "Empty" (`Initiable` = `mempty`) and "default/zero" are *different* capability cores; conflating them repeats the `Set.Protocol` error. Recommended default answer: do **not** author a new lawless `Defaultable`; the one lawful slice is already `Algebra.Monoid.identity`. [RES-018]-gated; spans initialization + algebra + numerics.
- **E2 — the tower-wide witness-`Sendable` posture.** `Initialization.Witness`/`Iterator.Witness`/`Parser.Witness`/`Serializer.Witness` are all `Sendable`-silent. Decide *once* for all operation-domain witnesses; correct shape is conditional `Sendable` gated on `@Sendable` storage, never required.
- **E3 — Builder-grammar unification** (generic `Builder` over `Buffer.Linear` vs `Set.Builder` over `[Element]`, differing on `~Copyable` support) — a standalone architecture topic.

### Do-not list (structurally important anti-recommendations)

Do **not**: widen `Initiable` to admit `Int()`=0 / `Bool()`=false / `nil`; add a
lawless `Defaultable { static var default }`; add combinators as Protocol
*requirements*; add a monoidal empty *producer*; "upgrade" the bridge to a
self-projection associatedtype default (§V5 "DOES NOT FIT" — the witness is
output-parameterized); *require* `Sendable`; or add machine facets (cursor state,
`Body`/result-builder, `inout`, manner-variant tiers) to match the iterator
template — that would violate the relation/value classification.

## References

Primary sources (each verified against the cited source on 2026-05-30; load-bearing
claims independently re-verified per [RES-020]):

- Swift Evolution **SE-0233** *Make `Numeric` Refine a new `AdditiveArithmetic` Protocol* — `static var zero`, `init()` rejected in Alternatives Considered. <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0233-additive-arithmetic-protocol.md>
- Swift stdlib `RangeReplaceableCollection.init()`, `AdditiveArithmetic.zero`, `ExpressibleByNilLiteral` (`~Copyable, ~Escapable, @_lifetime(immortal)`) — <https://github.com/swiftlang/swift> (`stdlib/public/core/`).
- Swift Forums pitches: *DefaultConstructible* / *DefaultInit* (threads 4771, 12263, 53723) — core-team semantic-coherence objections; "pass `() -> T`" counter-recommendation. <https://forums.swift.org>
- Haskell `base` — `Data.Monoid` (`Monoid`/`mempty`), `Control.Applicative` (`Alternative`/`empty`). <https://hackage.haskell.org/package/base/docs/Data-Monoid.html>
- Haskell `data-default` (`Default`/`def`) + critiques (Karpov; Haskell Discourse). <https://hackage.haskell.org/package/data-default>
- Scala **Cats** `Monoid` (`def empty`). <https://github.com/typelevel/cats>
- nLab — *global element*, *pointed object*. <https://ncatlab.org/nlab/show/global+element> · <https://ncatlab.org/nlab/show/pointed+object>
- Java SE `java.util.function.Supplier`; JSR-330/Guice `Provider`; Guava `Suppliers`; C++ `std::function` / `std::move_only_function` (C++23); Kotlin `lazy`/`Lazy`; Rust `LazyCell`/`OnceCell`.
- pointfree **swift-dependencies** `DependencyKey` (`associatedtype Value: Sendable`); SwiftUI `EnvironmentKey.defaultValue`.

Internal (governing):

- `swift-institute/Research/operation-domain-naming-and-organization.md`
- `swift-institute/Research/cross-layer-capability-protocol-model.md`
- `swift-institute/Research/self-projection-default-pattern.md`
- `swift-institute/Research/labeled-cross-domain-init-convention.md` · `cross-domain-init-overload-resolution-footgun.md`
- `swift-primitives/swift-algebra-primitives/Sources/Algebra Monoid Primitives/Algebra.Monoid.swift` (the `mempty` shape, packaged)
- `swift-primitives/swift-iterator-primitives/` (the sibling operation-domain template)
