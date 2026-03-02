# Parser Combinator Algebraic Foundations

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide (swift-algebra-*-primitives, swift-parser-primitives, swift-parsers)
---
-->

## Context

The Swift Institute ecosystem contains two independently-developed bodies of work that address overlapping mathematical territory:

1. **Algebra primitives** (13 packages): A witness-based algebraic hierarchy from Magma through Field, Module, VectorSpace, and Kleene-adjacent structures (Cardinal, Modular). These model algebraic operations as first-class values (`Algebra.Monoid<Element>`, `Algebra.Semiring<Element>`, etc.) with law-verification infrastructure (`Algebra.Law.*`).

2. **Parser primitives + Parsers** (2 packages): A combinator library providing `map`, `flatMap`, `OneOf`, `Take`, `Many`, `Always`, `Fail`, and related combinators over `Parser.Protocol`. These *implicitly* implement well-known algebraic structures (Functor, Monad, Alternative, Semiring) without referencing the algebra packages.

The question is whether this overlap is accidental or reveals a deeper connection that could be made explicit — and whether doing so would improve either system.

## Question

**Can the parser combinator infrastructure explicitly depend on or interoperate with the algebra primitives packages, and should it?**

Sub-questions:

1. What algebraic structures do parser combinators form, precisely?
2. At what level of abstraction does the overlap exist (value-level vs. type-constructor-level)?
3. What would an explicit algebraic parser design look like in Swift's type system?
4. What are the costs and benefits of coupling these systems?

---

## Prior Art Survey

### Systematic Literature Review

**Research questions**: (RQ1) What algebraic structures have parser combinators been shown to satisfy? (RQ2) Has the semiring structure of parsing been exploited in practice? (RQ3) How do languages without higher-kinded types express these abstractions?

**Search strategy**: ACM DL, arXiv, Springer, Google Scholar. Terms: "parser combinator" AND ("algebra" OR "semiring" OR "monoid" OR "Kleene"). Inclusion: formal treatment of parser combinators as algebraic structures; practical implementations exploiting algebraic parameterization. Exclusion: pure grammar theory without computational interpretation.

**Screening**: 47 candidates → 19 included after full-text review.

### Key Sources

#### Foundational Theory

| Ref | Authors | Year | Venue | Key Contribution |
|-----|---------|------|-------|------------------|
| [CS63] | Chomsky, Schutzenberger | 1963 | North-Holland | Formal languages form a semiring under ∪ (addition) and · (concatenation) |
| [Koz94] | Kozen | 1994 | Inf. & Comp. | Complete equational axiomatization of Kleene algebras (semiring + star) |
| [Good99] | Goodman | 1999 | Comp. Ling. | Semiring-parameterized parsing: single parser description, multiple semirings yield boolean/Viterbi/forest computations |
| [Brz64] | Brzozowski | 1964 | JACM | Derivatives of regular expressions; algebraic differentiation over language semiring |

#### Typeclass Hierarchy (Haskell)

| Ref | Authors | Year | Venue | Key Contribution |
|-----|---------|------|-------|------------------|
| [MP08] | McBride, Paterson | 2008 | JFP | Applicative functors as intermediate point between Functor and Monad; Applicative parsers are statically analyzable, Monadic parsers are context-sensitive |
| [LM01] | Leijen, Meijer | 2001 | UU-CS | Parsec: Functor/Applicative/Monad/Alternative instances; commit-on-consumption violates Alternative monoid laws |

#### Algebraic Parsing

| Ref | Authors | Year | Venue | Key Contribution |
|-----|---------|------|-------|------------------|
| [MDS11] | Might, Darais, Spiewak | 2011 | ICFP | Parsing with derivatives: extend Brzozowski to CFGs; grammar IS the algebra, parsing IS evaluation |
| [FHW10] | Fischer, Huch, Wilke | 2010 | ICFP | Regular expression matching parameterized over arbitrary semiring; single algorithm, multiple interpretations |
| [KY19] | Krishnaswami, Yallop | 2019 | PLDI (Distinguished) | Context-free expressions form idempotent semiring; type system ensures LL(1); staging yields performance. **Most directly relevant to this research.** |
| [HN11] | Henglein, Nielsen | 2011 | POPL | Regular expression containment via coinductive axiomatization of idempotent semiring + Kleene star |
| [RO10] | Rendel, Ostermann | 2010 | Haskell Symp. | Invertible syntax descriptions: partial isomorphisms unify parsing and printing |

#### Practical Implementations (Non-Haskell)

| Ref | Authors | Year | Language | Algebraic Traits? |
|-----|---------|------|----------|-------------------|
| [nom] | Couprie | 2015– | Rust | No. Function-based combinators, no algebraic traits |
| [combine] | Westerlind | 2015– | Rust | No. Parser trait with .map/.and_then/.or, not algebraic |
| [chumsky] | Barretto | 2021– | Rust | No. Parser trait, algebraic structure implicit |
| [PF-parsing] | Williams, Celis | 2020– | Swift | No. Parser protocol with .map/.flatMap/OneOf, no algebra dependency |

**Synthesis**: No production parser combinator library in Swift or Rust explicitly depends on algebraic abstraction packages. The algebraic structure is universally present but universally implicit. Haskell achieves explicit structure through its typeclass hierarchy (Functor → Applicative → Monad, Alternative) enabled by higher-kinded types. Languages lacking HKTs have not found a practical way to make the connection explicit.

---

## Theoretical Grounding

### The Two Levels of Algebra

Parser combinators exhibit algebraic structure at **two distinct levels**, and conflating them is the central source of confusion in this area.

#### Level 1: Constructor-Level Algebra (Higher-Kinded)

For a type constructor `P` where `P<A>` is "a parser producing values of type `A`":

| Structure | Operation | Identity | Swift Equivalent |
|-----------|-----------|----------|------------------|
| **Functor** | `map: (A → B) → P<A> → P<B>` | — | `parser.map { f($0) }` |
| **Applicative** | `<*>: P<A → B> → P<A> → P<B>` | `pure: A → P<A>` | `Take { p1; p2 }` / `Always(x)` |
| **Monad** | `>>=: P<A> → (A → P<B>) → P<B>` | `return: A → P<A>` | `parser.flatMap { ... }` / `Always(x)` |
| **Alternative** | `<\|>: P<A> → P<A> → P<A>` | `empty: P<A>` | `OneOf { p1; p2 }` / `Fail(...)` |

These abstractions require **higher-kinded types** to express as protocols. Swift cannot express them. The algebra primitives packages cannot model them because they operate at the value level (`Algebra.Monoid<Element>` where `Element` is a concrete type, not a type constructor).

#### Level 2: Value-Level Algebra (Expressible in Swift)

For a **fixed** Input, Output, and Failure type, the set of all parsers `Parser<I, O, E>` forms algebraic structures:

| Structure | Carrier | Addition | Multiplication | Zero | One |
|-----------|---------|----------|----------------|------|-----|
| **Monoid under choice** | `{P : Parser<I, O, E>}` | `OneOf { p1; p2 }` | — | `Fail(...)` | — |
| **Monoid under sequence** | `{P : Parser<I, Void, E>}` | — | `Take { p1; p2 }` | — | `Always(())` |
| **Semiring** | `{P : Parser<I, O, E>}` | `OneOf` | `Take` (via output mapping) | `Fail` | `Always` |
| **Kleene algebra** | `{P : Parser<I, O, E>}` | `OneOf` | `Take` | `Fail` | `Always` + `Many` as star |

This level IS expressible with the existing algebra packages. `Algebra.Monoid<SomeParser>` and `Algebra.Semiring<SomeParser>` are well-typed if `SomeParser` is a concrete (possibly type-erased) parser type.

### Formal Semantics

#### Definition 1: Parser Denotation

A parser `p : Parser<I, A, E>` denotes a partial function:

```
⟦p⟧ : I → (A × I) ∪ {⊥_e | e : E}
```

where `I` is the input type, `A` is the output type, `E` is the error type, and `⊥_e` represents failure with error `e`. On success, the parser returns a value and the remaining input.

#### Definition 2: Language Semantics

The **language** of a parser is the set of inputs it accepts:

```
L(p) = { i ∈ I | ∃ a, i'. ⟦p⟧(i) = (a, i') }
```

#### Theorem 1: Parsers Form a Near-Semiring Under Language Semantics

For fixed `I`, `A`, `E`:

**(S1) Additive Monoid.** `(Parser<I,A,E>, OneOf, Fail)` forms a monoid:
- Associativity: `L(OneOf { OneOf { p; q }; r }) = L(OneOf { p; OneOf { q; r } })`
- Identity: `L(OneOf { p; Fail }) = L(p) = L(OneOf { Fail; p })`

**(S2) Multiplicative Monoid.** `(Parser<I,Void,E>, Take, Always(()))` forms a monoid:
- Associativity: `L(Take { Take { p; q }; r }) = L(Take { p; Take { q; r } })`
- Identity: `L(Take { p; Always(()) }) = L(p) = L(Take { Always(()); p })`

**(S3) Left Distributivity.** `L(Take { OneOf { p; q }; r }) = L(OneOf { Take { p; r }; Take { q; r } })`

**(S4) Zero Annihilation.** `L(Take { Fail; p }) = ∅ = L(Take { p; Fail })`

**Caveat**: We say "near-semiring" because:
- Commutativity of addition holds in language semantics (`L(p) ∪ L(q) = L(q) ∪ L(p)`) but NOT operationally (OneOf tries alternatives in order; first-match semantics break commutativity for error reporting and side effects).
- Right distributivity holds in language semantics but may not hold operationally (backtracking semantics affect right distribution).

#### Theorem 2: Kleene Star Correspondence

`Many` corresponds to the Kleene star:

```
L(Many(p)) = L(p)* = ∪_{n≥0} L(p)^n = {ε} ∪ L(p) ∪ L(p·p) ∪ ...
```

With the Kleene star, parsers satisfy the unfolding equations:
- `L(Many(p)) = L(OneOf { Always(()); Take { p; Many(p) } })`

This gives `(Parser, OneOf, Take, Fail, Always, Many)` the structure of a Kleene algebra under language semantics.

### The Operational vs. Denotational Gap

The critical subtlety: parser combinators satisfy algebraic laws **denotationally** (in terms of which strings they accept) but may violate them **operationally** (in terms of error messages, performance, side effects, and backtracking behavior).

| Law | Denotational | Operational |
|-----|-------------|-------------|
| Choice commutativity | Holds | Fails (first-match, error reporting) |
| Choice associativity | Holds | Holds (modulo error nesting) |
| Sequence associativity | Holds | Holds (modulo tuple nesting) |
| Left distributivity | Holds | Holds if both sides backtrack |
| Right distributivity | Holds | May fail (commit-on-consumption) |
| Zero annihilation | Holds | Holds |
| Kleene unfolding | Holds | Holds |

This gap is precisely what Parsec/Megaparsec demonstrate: they satisfy monad laws but violate Alternative monoid laws operationally due to commit-on-consumption. Attoparsec always backtracks, satisfying more laws operationally but at performance cost.

---

## Analysis

### Option A: No Explicit Dependency (Status Quo)

**Description**: Parser primitives and algebra primitives remain independent. The algebraic structure of parser combinators is documented but not reified in the type system.

**Advantages**:
- Zero coupling: changes to algebra packages cannot break parsers
- No performance overhead from witness indirection
- Simpler dependency graph
- Parser API remains self-contained and discoverable

**Disadvantages**:
- Algebraic laws are implicit, not mechanically verified
- No composability with generic algebraic algorithms
- Duplicated conceptual work (both systems model monoids independently)
- Documentation burden to explain algebraic properties

### Option B: Parser Types Conform to Algebra Protocols

**Description**: Parser types provide `Algebra.Monoid`, `Algebra.Semiring`, or `Algebra.KleeneAlgebra` witness instances. E.g., `Parser.Always` provides an `Algebra.Monoid` witness for choice composition.

**Advantages**:
- Algebraic structure becomes mechanically verifiable via `Algebra.Law.*`
- Parsers compose with generic algebraic algorithms
- Single source of truth for algebraic concepts across the ecosystem

**Disadvantages**:
- **Type mismatch**: The algebra packages use `Algebra.Monoid<Element>` as a *witness struct* containing closures. The "element" would need to be a type-erased parser (`AnyParser<I, O, E>` or an existential). This introduces boxing overhead on every algebraic operation.
- **Output type variation**: The semiring structure only works when parsers share the same output type. But `Take { intParser; stringParser }` produces `(Int, String)` — the output type changes with composition. This means the "multiplicative monoid" only works for `Void`-output parsers, severely limiting applicability.
- **Error type composition**: `OneOf` produces `Parser.OneOf.Errors<E0, E1>`, not `E0`. The error type grows with each choice. This means two parsers with different error types cannot be placed in the same `Algebra.Monoid` — the carrier type keeps changing.
- **Layer violation**: Parser primitives (Layer 1) and algebra primitives (Layer 1) are peers, not hierarchically related. Adding a dependency of parsers on algebra increases coupling between primitives.
- **Witness overhead**: Closure-based witness structs (`Algebra.Monoid<AnyParser<...>>`) introduce allocation and indirect-call overhead in what should be a zero-cost abstraction layer.

### Option C: Semiring-Parameterized Parsing

**Description**: Following Goodman [Good99] and Fischer et al. [FHW10], provide parser combinators that are parameterized over an arbitrary semiring. A single grammar description computes different results by substituting the semiring: boolean recognition, parse forests, probability distributions, etc.

**Advantages**:
- This IS a genuine, proven use of the algebra-parser connection
- Directly exploits `Algebra.Semiring<S>` as a parameter
- Documented benefits in NLP (Viterbi, inside-outside, n-best) and formal verification (model checking)
- Does not require type erasure — the semiring is over *values* (scores, counts, probabilities), not over parsers
- Clean dependency: a semiring-parameterized parser module depends on `Algebra.Semiring` naturally

**Disadvantages**:
- Requires a different parser architecture: grammar descriptions as data, not combinator composition
- Significant engineering effort; essentially a new parsing framework alongside the existing one
- Most applicable to NLP/probabilistic parsing, less so to the deterministic byte-level parsing that swift-parsers targets
- The existing combinator architecture (inout mutation, zero-copy, typed throws) is optimized for a *specific* semiring (boolean: parse succeeds or fails) and would need fundamental redesign

### Option D: Algebraic Documentation and Law Testing

**Description**: Document the algebraic structure explicitly in parser primitives documentation. Provide test-time law verification using `Algebra.Law.*` without runtime dependency. The algebra packages become a *test dependency*, not a production dependency.

**Advantages**:
- Makes implicit algebra explicit without production coupling
- `Algebra.Law.Associativity.check(of:over:)` can verify OneOf associativity on concrete parser instances
- `Algebra.Law.Identity.left(of:over:)` can verify Fail as left identity for OneOf
- Zero runtime overhead — law checks only run in tests
- Documents which laws hold operationally vs. only denotationally
- Incremental: can be added without changing any existing API

**Disadvantages**:
- Requires type-erased parser wrappers for law testing (test-only cost)
- Law checking is sampling-based, not exhaustive
- Does not enable generic algebraic composition at the API level
- The algebra-parser connection remains documentation, not type-system-enforced

### Option E: Typed Algebraic Parsing (Krishnaswami-Yallop Style)

**Description**: Following [KY19], build a typed grammar expression language where the type system ensures parseability class (LL(1), etc.). Grammar expressions form an idempotent semiring. Use staging or code generation for performance.

**Advantages**:
- Strongest theoretical foundation (PLDI Distinguished Paper)
- Type-level guarantee of parser correctness properties
- Performance through staging
- Grammar IS the algebra, fully explicit

**Disadvantages**:
- Requires MetaOCaml-style staging capabilities that Swift lacks
- Fundamentally different architecture from the existing combinator library
- Would be a new Layer 1 package, not an integration of existing packages
- Research-grade; no production implementation outside OCaml exists
- The existing `Parser.Protocol` design (monadic, context-sensitive) cannot be retrofitted into this framework, which is specifically LL(1)/Applicative

---

## Comparison

| Criterion | A: Status Quo | B: Conform | C: Semiring-Param | D: Doc + Law Tests | E: K-Y Style |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Production coupling | None | High | Medium | None (test-only) | N/A (new system) |
| Runtime overhead | None | Witness closures | Semiring dispatch | None | Staging gains |
| Type system expressibility | N/A | Poor (type erasure) | Good (value-level) | N/A | Excellent (in OCaml) |
| Engineering effort | None | Medium | Very high | Low | Very high |
| Practical benefit | Baseline | Limited | NLP/probabilistic | Moderate | Theoretical |
| Law verification | Manual | Mechanical | Inherited | Mechanical (test) | By construction |
| Compatibility with existing API | Full | Partial | None (new arch) | Full | None (new arch) |
| Swift type system fit | N/A | Poor | Good | Good | Poor (no staging) |

## Outcome

**Status**: RECOMMENDATION

### Primary Recommendation: Option D (Algebraic Documentation + Law Testing)

**Rationale**: The overlap between parser combinators and algebra packages is real and theoretically deep, but the connection exists primarily at the **constructor level** (Functor, Monad, Alternative), which Swift's type system cannot express. The value-level connection (parsers-as-semiring-elements) requires type erasure that undermines the zero-cost abstraction design of the parser primitives.

Option D captures the benefits — explicit documentation of algebraic properties, mechanical law verification — without the costs of production coupling or type erasure overhead.

**Implementation path**:

1. **Document algebraic structure** in parser primitives DocC:
   - `map` implements Functor (laws: identity, composition)
   - `flatMap` implements Monad (laws: left identity, right identity, associativity)
   - `OneOf` implements Alternative (near-monoid: associativity holds, commutativity fails operationally)
   - `Take` + `OneOf` approximate a near-semiring (distributivity holds denotationally)
   - `Many` approximates Kleene star (unfolding equation holds)

2. **Add law-verification tests** using `Algebra.Law.*` as a test dependency:
   - Create type-erased wrapper `AnyParser<I, O, E>` in test support
   - Verify `OneOf` associativity, `Fail` identity, `Always` identity
   - Document which laws hold operationally and which only denotationally
   - Use `Algebra.Law.Violation` to produce clear failure diagnostics

3. **Cross-reference documentation**: Parser primitives DocC should reference the algebra packages as "the value-level counterpart" and explain the level distinction.

### Secondary Recommendation: Investigate Option C for Future Work

Semiring-parameterized parsing is the one area where the algebra packages provide *genuine, direct* value to parsing — not as structure-over-parsers but as structure-over-parse-results. A parser that computes over an arbitrary `Algebra.Semiring<S>` could unify:

- Boolean parsing (current): `Algebra.Semiring<Bool>.boolean`
- Counting: number of parse trees
- Probabilistic: Viterbi, inside-outside for NLP
- Forest: full parse forest construction

This would be a **new package** (e.g., `swift-algebraic-parser-primitives` or a module within `swift-parser-primitives`) that depends on both parser and algebra primitives. It would provide a grammar DSL (data representation, not combinator composition) parameterized over `Algebra.Semiring<S>`. This is a significant design effort and should be preceded by its own Tier 2 research document when the use case arises.

### What NOT to Do

- Do NOT make parser primitives depend on algebra primitives at the production level
- Do NOT add `Algebra.Monoid` witnesses to parser types — the type erasure overhead contradicts the zero-cost design
- Do NOT attempt to express Functor/Monad/Alternative as Swift protocols — the language lacks higher-kinded types
- Do NOT conflate the value-level semiring (algebra packages) with the constructor-level algebraic structure (parser typeclass hierarchy) — they are related but distinct

---

## References

- [CS63] Chomsky, N., Schutzenberger, M.P. (1963). "The Algebraic Theory of Context-Free Languages." In *Computer Programming and Formal Systems*, pp. 118–161. North-Holland.
- [Brz64] Brzozowski, J.A. (1964). "Derivatives of Regular Expressions." *JACM* 11(4), pp. 481–494.
- [Koz94] Kozen, D. (1994). "A Completeness Theorem for Kleene Algebras and the Algebra of Regular Events." *Information and Computation* 110(2), pp. 366–390.
- [Good99] Goodman, J. (1999). "Semiring Parsing." *Computational Linguistics* 25(4), pp. 573–606.
- [LM01] Leijen, D., Meijer, E. (2001). "Parsec, a fast combinator parser." UU-CS-2001-27.
- [MP08] McBride, C., Paterson, R. (2008). "Applicative Programming with Effects." *JFP* 18(1), pp. 1–13.
- [FHW10] Fischer, S., Huch, F., Wilke, T. (2010). "A Play on Regular Expressions." *ICFP '10*, pp. 357–368.
- [RO10] Rendel, T., Ostermann, K. (2010). "Invertible Syntax Descriptions." *Haskell Symposium '10*, pp. 1–12.
- [MDS11] Might, M., Darais, D., Spiewak, D. (2011). "Parsing with Derivatives." *ICFP '11*, pp. 189–195.
- [HN11] Henglein, F., Nielsen, L. (2011). "Regular Expression Containment: Coinductive Axiomatization and Computational Interpretation." *POPL '11*, pp. 385–398.
- [KY19] Krishnaswami, N.R., Yallop, J. (2019). "A Typed, Algebraic Approach to Parsing." *PLDI '19*, pp. 379–393. (Distinguished Paper)
- [PF-parsing] Williams, B., Celis, S. (2020–). *swift-parsing*. github.com/pointfreeco/swift-parsing.
