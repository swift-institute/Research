# Coproduct Primitive Design and Blockers

## Blog Post

This finding was published as:
- [The missing fourth corner: why swift-coproduct-primitives can't ship today](https://swift-institute.org/documentation/swift_institute/the-missing-fourth-corner) (2026-05-12)

<!--
---
version: 1.2.0
last_updated: 2026-05-12
status: GATED
changelog:
  - 1.2.0 (2026-05-12): Gated sources committed at `Sources/Coproduct Primitives/`, gated `#if hasFeature(VariadicEnum)`. Package status upgraded from DEFERRED (no sources) to GATED (sources present, gated false today). Outcome section gains "Source-gating path" subsection capturing the design and the unblock-time patch surface (single gate identifier + speculative pack-eliminator body bits).
  - 1.1.0 (2026-05-10): swiftlang/swift survey performed against upstream main 51b4c9b. Both blockers verified UNCHANGED with concrete evidence (test-file expected-error annotations, zero commits matching blocker keywords since 2026-01-01, zero open PRs, no SE proposals 0500-0528 touching either blocker). Verification tags upgraded from "Carried forward, re-verified" to "[Verified: 2026-05-10]" with citations to specific files and grep results. Package created as private repo at https://github.com/swift-primitives/swift-coproduct-primitives.
  - 1.0.0 (2026-05-10): initial DEFERRED research; sibling-vs-absorbed open item resolved (sibling).
tier: 2
scope: per-package
trigger: stub-creation of swift-coproduct-primitives, the missing fourth corner of the typed-composition cohort (Pair / Either / Product shipped 2026-05-09; Coproduct held back behind language constraints). External prior art (Genaro-Chris/SwiftUtils Variant) prompted explicit examination of the design space.
related:
  - swift-either-primitives/Research/future-directions.md (Candidate 6, "DEFER compiler-blocked")
  - swift-either-primitives/Research/either-academic-and-ecosystem-survey.md (Q3.2, Q1.6)
  - swift-product-primitives/Research/escapable-blocked.md (sibling pack-constraint blocker)
  - swift-institute/Research/escapable-support-pair-either-product.md (cohort-wide ~Escapable adoption)
external_prior_art:
  - https://github.com/Genaro-Chris/SwiftUtils/blob/main/Sources/SwiftUtils/Variant.swift
---
-->

## Context

The 2026-05-09 cohort shipped three of the four corners of the typed-composition matrix:

|                | binary    | n-ary                                |
|----------------|-----------|--------------------------------------|
| **product**    | `Pair`    | `Product`                            |
| **coproduct**  | `Either`  | `Coproduct` *(this package, deferred)* |

The fourth corner — the **n-ary coproduct** — is conceptually well-defined: a typed sum that holds exactly one value out of a list of types, generalising `Either<Left, Right>` to arbitrary arity in the same way `Product<each Element>` generalises `Pair<First, Second>`.

Internal prior research has already considered this package in two places:

- `swift-either-primitives/Research/future-directions.md` (Candidate 6) explicitly proposes "n-ary `Coproduct<each T>` / `OneOf<each T>`" and concludes "**DEFER (compiler-blocked).** Track via Features.def (`VariadicEnum` flag would be the canary), the `enum_with_pack` diagnostic, and the proposals index. When the language opens this up, decide between absorbing-into-either-primitives vs. sibling-package."
- `swift-either-primitives/Research/either-academic-and-ecosystem-survey.md` (Q3.2) verifies the compiler block: the diagnostic `enum_with_pack` ("enums cannot declare a type pack") is the canonical rejection, accompanied by a "Temporary limitations" comment in `swift/test/Generics/variadic_generic_types.swift:7`. No feature flag, no proposal, no PR work as of 2026-05-08. `[Carried forward, re-verified 2026-05-10]`

External prior art — Genaro-Chris's `SwiftUtils.Variant<each Item>` — implements an n-ary coproduct *today* using `Builtin.RawPointer` storage + runtime metatype matching. The implementation is informative as a counterpoint: it demonstrates exactly which tradeoffs the institute would have to make to ship under current language constraints. `[Verified: 2026-05-10 against https://raw.githubusercontent.com/Genaro-Chris/SwiftUtils/main/Sources/SwiftUtils/Variant.swift, 450 LoC]`

Per [RES-019], this document extends the prior research rather than duplicating it. The prior `future-directions.md` Candidate 6 entry framed Coproduct as a sibling-vs-absorption *open question*; this document resolves that question (sibling package, this stub), codifies the natural-shape declaration, and enumerates the unblock conditions in actionable form.

## Question

What should `swift-coproduct-primitives` look like in a shipped-form context (when the language constraints lift), and what specifically blocks its implementation today?

Three sub-questions:

1. Does an n-ary coproduct earn its place as a separate primitive, or can the use cases compose existing primitives (per [RES-018]'s composition-check requirement)?
2. What is the *natural-shape declaration* — the API surface and storage model the package should adopt once language constraints lift?
3. What are the *named blockers* — the specific Swift-evolution gates whose lifting would unblock the package, and what would the package look like under each?

## Analysis

### Composition check (per [RES-018])

Can the use cases for an n-ary coproduct be covered by composing `Either`?

**Right-associative nesting**: `Either<A, Either<B, Either<C, D>>>`.

**Balanced nesting** (power-of-2 arity only): `Either<Either<A, B>, Either<C, D>>`.

Both compile and are type-safe. The cost is in the *call-site shape*, not in the type system. Three concrete failure modes:

| Failure mode | Example | Cost |
|---|---|---|
| Pattern matching is nested, not flat | `case .right(.right(.left(let c)))` for arity-4 right-associated | O(arity) syntactic depth per match |
| Position is opaque at the type level | `Either<A, Either<B, C>>.right(.left(b))` carries no positional name | Reader has to count `.left`/`.right` to identify the arm |
| Functor / fold operations don't compose cleanly | `bimap` over a 4-arm right-associated chain requires 3 levels of `bimap` | Quadratic syntactic blowup for full transforms |

For arity 2: `Either` is the right tool, no composition needed. For arity 3: the right-associated `Either<A, Either<B, C>>` is *acceptable* with effort. For arity ≥ 4: composition is hostile. The pattern-match depth, the positional opacity, and the bimap quadratic make right-associated `Either` chains a bad shape for the use cases enumerated below.

**Verdict**: composition technically covers the n-ary use cases but the API hostility scales with arity. A flat `Coproduct<each Element>` is not a primitive that exists *only* for catalogue neatness — it solves a real ergonomic problem at arity ≥ 4 that nested `Either` cannot solve.

### Second-consumer check (per [RES-018])

Five independent consumer shapes that need an n-ary coproduct *and* would not be adequately served by nested `Either`:

| Consumer | Shape | Why nested `Either` fails |
|---|---|---|
| Multi-cause typed throws (input-side) | `func parse() throws(Coproduct<Lex.Error, Parse.Error, Validation.Error>)` — the function throws *one of* N errors, not all of them | `throws(Either<Lex.Error, Either<Parse.Error, Validation.Error>>)` is readable on the throw site but the catch site has to nest-match: ergonomics worse than `any Error` for ≥ 3 |
| Parser combinator alternatives | A combinator branching across N typed productions, each with a different result type | `OneOf` parsers are universal in parser-combinator literature; nested `Either<A, Either<B, ...>>` makes the result-type computation viral |
| State machine output type | A machine where each step emits one of N typed events (mouse / keyboard / system / window-state in a UI machine, etc.) | Nested-`Either` events are not introspectable by index; debuggers and serializers see opaque tagged depth |
| Pipeline stage dispatch | Each stage emits one of N typed results consumed by the next stage's match | Pattern-match depth scales with arity; pipeline visualization becomes nested rather than flat |
| DSL node sum types | An AST node that can be one of N typed sub-nodes | Today's DSLs hand-roll an enum per AST. A first-class `Coproduct<Statement, Expression, Declaration, ...>` is a generic alternative that doesn't require per-DSL boilerplate |

These five consumer shapes are mostly satisfied today by hand-rolled enums. A first-class `Coproduct<each Element>` would replace the boilerplate. The second-consumer check passes — there are multiple independent consumers; this is not a one-off dressed up as infrastructure.

### Theoretical grounding (per [RES-022])

Categorically, the **n-ary coproduct** of objects `X₁, X₂, ..., Xₙ` in a category with finite coproducts is `X₁ ⊔ X₂ ⊔ ... ⊔ Xₙ` together with `n` injection morphisms `inj_k: X_k → ⊔ᵢ Xᵢ` satisfying the n-ary universal property: for any object `Q` and morphisms `f_k: X_k → Q`, there exists a unique morphism `[f₁, ..., f_n]: ⊔ᵢ Xᵢ → Q` (the n-ary copairing) making each diagram commute.

This is the same shape as the binary coproduct (covered in `swift-either-primitives/Research/either-academic-and-ecosystem-survey.md` §Q1.1) extended to arbitrary arity. The categorical statement does not change with arity; the implementation cost does, because Swift's enum syntax is binary-friendly and pack-unfriendly.

The catamorphism (the n-ary copairing) is what `fold(_ closures: repeat (each Element) -> Result)` would expose — exactly one of the N closures runs, the one matching the active arm.

### Prior art survey (per [RES-021])

The internal Either survey (`swift-either-primitives/Research/either-academic-and-ecosystem-survey.md`) covers most of the relevant external prior art for binary coproducts. This survey extends to the **n-ary case specifically**.

| System | n-ary coproduct mechanism | Source-language status | Relevance to Swift |
|---|---|---|---|
| F# | `Choice<T1, ..., T7>` — manually replicated up to arity 7 | Stable, shipping | Bounded-arity is a viable today-shape if pack-enums never land |
| Scala 3 | Union types `A \| B \| C` (structural) | Stable, shipping | Structural unions are not a Swift shape; nominal `Coproduct` is closer |
| TypeScript | Discriminated unions `type T = A \| B \| C` (structural) | Stable, shipping | Same — structural |
| OCaml | Polymorphic variants `[\`A of int \| \`B of string]` (open, row-typed) | Stable, shipping | Row types are not a Swift shape |
| Rust | Native `enum` is the n-ary coproduct (each `case` is an injection); plus `frunk::coproduct::Coproduct` HList for type-level n-ary | Stable, shipping | Rust enums are pack-variadic-friendly because they are not generic-pack-parameterised — Swift's enum gap is the difference |
| Haskell | `Data.Sum` (Either chain), `OpenSums` libraries (HList-style), `frunk` analogue | Stable, shipping | Type-level lists are not a Swift shape |
| Coq / Lean / Idris | n-ary coproduct via dependent inductive types | Stable | Dependent-typed; not a Swift shape |
| Genaro-Chris/SwiftUtils | `Variant<each Item>: ~Copyable` with `Builtin.RawPointer` + runtime metatype dispatch + throwing `init(with:)` | Shipping today on Swift 6.x | The today-shape *is* this kind of construction; the institute would need to choose its own tradeoffs (see "Today-feasible shapes" below) |

`[Verified: 2026-05-10 against package sources for Variant; cited but not re-verified for F# / Scala / Rust / OCaml — covered in detail at swift-either-primitives/Research/either-academic-and-ecosystem-survey.md Q1.6 / Q6.4]`

**Contextualization step (per [RES-021])**: universal adoption of n-ary coproducts in adjacent languages does not imply a Swift-language gap. Rust's solution is "use `enum`" — Rust's enums *are* the n-ary coproduct, with one syntactic case per arm and pattern matching as the eliminator. Swift's gap is specifically the `each T`-parameterised variadic case, which is what would let one type cover all arities. Without that, every language above either ships per-arity types (F# Choice2..Choice7) or accepts structural unions (Scala 3, TS), or uses HList-style type-level lists (Haskell, frunk). The institute's typed-correctness convention rejects structural unions and HList complexity, so the realistic path is per-arity types or a generic-pack struct with the today-shape tradeoffs documented below.

### Natural-shape declaration

Once Swift admits **parameter-pack enum cases** (the canary feature flag would be `VariadicEnum`; the diagnostic `enum_with_pack` would gain a parameter or feature gate, per `Q3.2` `[Carried forward, re-verified 2026-05-10]`), `Coproduct<each Element>` collapses to the shape it morally already has:

```swift
public enum Coproduct<each Element: ~Copyable & ~Escapable>: ~Copyable & ~Escapable {
    case at<i>(each Element)   // hypothetical pack-expanded case syntax
}
```

This requires *both* unblocked items: pack-expanded cases AND pack-`~Copyable`/`~Escapable` admission. Under that future, the API mirrors `Either` extended to N arms:

| Operation | Signature (sketch) | Role |
|---|---|---|
| Inject | `.at<k>(value)` for each pack position k | Build a `Coproduct` from one arm |
| `swapped` | rotation / permutation over the pack | Limited utility at general n-ary; arity-2 special case mirrors `Either.swapped` |
| `map` | `(repeat (each Element) -> each NewElement) -> Coproduct<repeat each NewElement>` | n-ary functor map (only the active arm's closure runs) |
| `fold` | `(repeat (each Element) -> Result) -> Result` | n-ary copairing — the catamorphism |
| `value` | `Element_k where every other Element_i is Never` | Generalised `Never`-elimination |
| `value(of:)` | free function consuming the coproduct | move-only path mirroring `Either.value(of:)` |

Conditional conformances follow the same pattern as `Either`: `Sendable / Equatable / Hashable / Codable` when each arm is, conditional `Swift.Error` when each arm is, etc.

The natural-shape declaration is *exactly the shape `Either` ships today*, extended over a parameter pack. The convergence is mechanical: once the language admits pack-expanded enum cases, `Either<L, R>` is morally `Coproduct<L, R>` with two-arm-specific `.left` / `.right` ergonomic spellings. (Whether `Either` becomes a typealias for `Coproduct<L, R>` or stays as a binary specialisation is a downstream cohesion question — the open item the prior `future-directions.md` flagged. This document does not pre-commit either way; both options remain on the table.)

### Today-feasible shapes (with named tradeoffs)

Three implementable shapes today, each sacrificing something:

| Shape | What it is | Sacrifice | Verdict |
|---|---|---|---|
| **A. Per-arity types** (`Coproduct2`, `Coproduct3`, …, `Coproduct7`) | A separate enum per arity, mirroring F#'s `Choice<T1..T7>` | Bounded arity (caps at the highest declared); typename arity number is a compound identifier (compounds with [API-NAME-002]) | Possible, but the per-arity numbering invents a `Coproduct.Two` / `Coproduct.Three` Nest.Name vocabulary that does not currently exist in the institute |
| **B. Generic struct + `Builtin.RawPointer` storage** (Variant-style) | One generic type `Coproduct<each Element>`; runtime tag + raw-pointer buffer sized for the largest arm; runtime metatype matching on init | `Builtin.RawPointer` is compiler-internal; throwing init defeats compile-time correctness; runtime traps replace type-system guarantees; same pack-`~Copyable` blocker as Product | Rejected — contradicts institute typed-correctness conventions |
| **C. Generic struct + tag + tuple-of-Optionals storage** | One generic type `Coproduct<each Element>`; storage is `(repeat (each Element)?)` with exactly one non-nil at a time | O(arity) wasted space; storage-as-optionals erases that "exactly one is present" is an invariant rather than a possibility | Possible; preserves type safety and compile-time injection but pays storage cost |

**Shape A** mirrors F#'s pragmatic choice. Acceptable if pack-enums never land, but the Nest.Name compound (`Coproduct.N`) is awkward and the bounded-arity ceiling means consumers hit the wall and revert to nesting.

**Shape B** is the Variant approach. Rejected — `Builtin.RawPointer` and runtime-throwing init are not institute-compatible regardless of any other trade-off.

**Shape C** is type-clean and compile-time-correct but pays storage. For low-arity it's negligible; for high-arity it's a real cost. Whether the cost is acceptable depends on whether n-ary coproducts at arity ≥ 8 are a real consumer use case (the second-consumer check above named consumers up to arity ~5; ≥ 8 is speculative).

**None of A/B/C ships the natural-shape declaration.** All three encode the absent language feature with workarounds whose costs scale unfavourably. The institute precedent (Pair vs Product) is to wait for the language: Pair shipped with full `~Copyable` / `~Escapable` arms because the binary case is enum-natural; Product shipped without `~Copyable` / `~Escapable` arms because the pack constraint is not yet liftable, and the package's `escapable-blocked.md` documents the deferred state. `swift-coproduct-primitives` follows the Product precedent at the type-shape level: defer the implementation until the language allows the natural form, rather than ship a workaround that future-readers would have to migrate off of.

### Named blockers (and unblock conditions)

Two specific Swift-evolution gates control this package's implementability. The state below is verified directly against `swiftlang/swift` upstream `main` at commit `51b4c9b7d0f` (HEAD as of `2026-05-09 20:25 PT`); the `[Verified: 2026-05-10]` tags refer to that anchor.

**Blocker 1: `enum_with_pack` (parameter-pack enum cases).**
- *Diagnostic*: `include/swift/AST/DiagnosticsSema.def` — `ERROR(enum_with_pack,none, "enums cannot declare a type pack", ())`. Present on `origin/main` `[Verified: 2026-05-10]`.
- *Test*: `test/Generics/variadic_generic_types.swift:7` — `// Temporary limitations` header followed by `enum EnumWithPack<each T> { // expected-error {{enums cannot declare a type pack}}`. The same expected-error fires for nested cases (`OuterStruct<each T> { enum NestedEnum { ... } }` at line 16). `[Verified: 2026-05-10]`.
- *Feature flag*: none. `Features.def` contains `BASELINE_LANGUAGE_FEATURE(ParameterPacks, 393, ...)` (the foundational pack support that already shipped) but no `VariadicEnum`, `EnumPack`, `ParameterPackEnum`, `AnonymousSumTypes`, or `UnionTypes` flag. `[Verified: 2026-05-10]`.
- *Recent commit history*: `git log origin/main --since=2026-01-01 -S "enum_with_pack"` returns **zero** commits. `git log origin/main --since=2026-01-01 -- test/Generics/variadic_generic_types.swift` returns **zero** commits. `git log origin/main --since=2026-01-01 --grep="variadic enum\|enum pack\|enum_with_pack\|pack.*enum case\|enum.*type pack"` returns **zero** commits. `[Verified: 2026-05-10]`.
- *Open PRs*: `gh pr list --repo swiftlang/swift --search "enum_with_pack"` returns **zero** open PRs; `--search "variadic enum"` returns two PRs (`#87244` is a crash fix in pack-conformance diagnostics, NOT introducing variadic enum support; `#81148` is unrelated to enums entirely). `[Verified: 2026-05-10]`.
- *Swift Evolution*: most recent proposals 0500–0528 (through 2026-05) include nothing on variadic enum cases. SE-0503 (Suppressed Associated Types) lifts `~Copyable`/`~Escapable` for *associated types* in protocols — adjacent but does not address pack `each` constraints. `[Verified: 2026-05-10]`.
- *Unblock canary*: `VariadicEnum` (or equivalently-named) feature flag appears in `Features.def`, OR the `enum_with_pack` diagnostic gains a feature gate, OR a Swift Forums pitch with PR-level work surfaces, OR an SE proposal with `variadic-enum` / `enum-pack` in the name lands in `swiftlang/swift-evolution/proposals/`.

**Blocker 2: pack-`~Copyable` / `~Escapable` admission.**
- The blocker is the parameter-pack syntax not admitting suppressed-conformance constraints on `each` requirements.
- *Direct test evidence*: `test/Generics/inverse_copyable_requirement_errors.swift` enforces the rejection with two test cases:
  - `func packingUniqueHeat_1<each T: ~Copyable>(_ t: repeat each T) {}` → `expected-error {{cannot suppress '~Copyable' on type 'each T'}}` plus `expected-note {{'where each T: Copyable' is implicit here}}`.
  - `func packingUniqueHeat_2<each T>(_ t: repeat each T) where repeat each T: ~Copyable {}` → same expected-error.
  - `[Verified: 2026-05-10]`. These tests are CONTRADICTED by lifting the blocker — they would fail if pack suppression were admitted. Their continued passing on `origin/main` is direct evidence the rejection is still in force.
- *Adjacent landing*: `BASELINE_LANGUAGE_FEATURE(NoncopyableGenerics, 427, "Noncopyable generics")` lifts the constraint for *scalar* generic parameters (`<T: ~Copyable>` works) but explicitly NOT for pack `each` requirements. Same for `BASELINE_LANGUAGE_FEATURE(NonescapableTypes, 446, ...)` and `LANGUAGE_FEATURE(SuppressedAssociatedTypesWithDefaults, 503, ...)` — none cover pack constraints. `[Verified: 2026-05-10]`.
- *Recent commit history*: `git log origin/main --since=2026-01-01 --grep="pack.*~Copyable\|each.*~Copyable\|pack.*noncopyable\|pack-element.*Copyable"` returns **zero** commits. `[Verified: 2026-05-10]`.
- *Open PRs*: `gh pr list --repo swiftlang/swift --search "pack noncopyable"` returns **zero** open PRs. `[Verified: 2026-05-10]`.
- *Sibling cohort precedent*: `swift-product-primitives/Research/escapable-blocked.md` v1.0.0 DECISION 2026-05-09 documents the same blocker for Product. Defer is the cohort precedent.
- *Unblock canary*: `Product`'s `escapable-blocked.md` flips to DECISION/IMPLEMENTED; the cohort-wide research at `swift-institute/Research/escapable-support-pair-either-product.md` adds a Phase N entry describing pack-suppression progress; OR `inverse_copyable_requirement_errors.swift` removes the `expected-error` annotations on the `packingUniqueHeat_*` cases.

**Combined unblock state**: Blocker 1 alone unlocks Shape C (tuple-of-Optionals storage with proper enum-like cases) for `Copyable & Escapable` arms; Blocker 2 alone is necessary but not sufficient. Both together unlock the natural-shape declaration.

**Survey conclusion (2026-05-10)**: Both blockers are firmly in place on upstream `main`. No commits, open PRs, feature flags, or SE proposals are addressing either of them. The DEFERRED status of this package is correct, and the package will remain DEFERRED until a canary fires.

## Outcome

**Status: GATED.** (upgraded from DEFERRED 2026-05-12 — see Source-gating path subsection)

`swift-coproduct-primitives` is a real package with a real second-consumer base (parser combinators, multi-cause input-side throws, state-machine output, pipeline dispatch, DSL ASTs). Its implementation is gated on Swift-evolution work that has not begun: parameter-pack enum cases (Blocker 1) is the primary gate; pack `~Copyable` / `~Escapable` admission (Blocker 2) is the secondary gate that controls whether the package can match `Either`'s move-only-arm support.

As of v1.2.0 (2026-05-12), the package ships the **natural-shape sources behind `#if hasFeature(VariadicEnum)`. Today's compilers do not define `VariadicEnum`; the gate evaluates to `false`, the target compiles to zero public symbols, and the package builds clean. When upstream Swift lifts the blockers, the gate flips and the API ships. The deliverable today is this research document plus the gated source files plus the README — the package is on the watch-list for both blockers; when either fires, the gate identifier is updated and this document gets revisited.

### Source-gating path (added v1.2.0)

The gating approach replaces the DEFERRED "sources absent until blockers lift" posture with "sources present, gated false until blockers lift". Rationale and design:

**Why ship gated sources rather than wait.** The research-doc-only posture made the natural-shape declaration implicit — readers had to reconstruct it from prose. Gated sources make it explicit: the type declaration, conformance ladder, fold / map / flatMap / swap / Never-elim signatures, and institute-protocol conformances are all in the file tree, in the canonical institute style, today. Three concrete benefits:

| Benefit | Mechanism |
|---|---|
| Forcing function for design clarity | Writing the actual signatures surfaced the equal-arm-convenience asymmetry: Map's same-arity-replace shape is *not expressible* in current pack syntax (needs `repeat _ in each Element`); FlatMap's NEW-pack-result is fine. Pure prose would have missed this. |
| Migration target | The day the gate fires, the package's public surface is already declared. Consumers don't wait for a separate "write the API" phase. |
| Pedagogical signal | Readers see exactly what the design will look like, including the speculative spots (case syntax, pack-eliminator dispatch, pack-position discriminator retrieval) flagged inline. |

**File inventory** (`Sources/Coproduct Primitives/`):

- `Coproduct.swift` — type declaration, conditional conformances (Copyable, Escapable, Sendable, BitwiseCopyable, stdlib Equatable/Hashable gated `<6.4`, Codable gated `!Embedded`, Swift.Error)
- `Coproduct+Fold.swift` — n-ary catamorphism (the n-ary copairing)
- `Coproduct+Map.swift` — n-ary functor (equal-arm convenience deliberately omitted, see below)
- `Coproduct+FlatMap.swift` — n-ary monadic bind (with equal-arm convenience — return pack is independent of input pack so it's expressible)
- `Coproduct+Swap.swift` — arity-2 binary swap (free function form, mirroring Product's `swapped(_:)` precedent)
- `Coproduct+Never.swift` — single-arm-inhabited extraction via `value(of:)` free function
- `Coproduct+Equation.Protocol.swift`, `Coproduct+Hash.Protocol.swift`, `Coproduct+Comparison.Protocol.swift` — institute protocols with `@_disfavoredOverload` for Swift <6.4 dual-residence
- `Coproduct+CustomStringConvertible.swift`, `Coproduct+Encodable.swift`, `Coproduct+Decodable.swift` — auxiliary conformances
- `Coproduct Primitives.docc/Coproduct Primitives.md` — module-level DocC

**Speculative components** (one-identifier patches at unblock time):

| Component | Speculative bit | Likely shipped form |
|---|---|---|
| Gate name | `#if hasFeature(VariadicEnum)` | Whatever Features.def names the flag (`VariadicEnum`, `EnumPack`, etc.) — single grep-and-replace if different |
| Case spelling | `case at(each Element)` | The indicative placeholder. Actual syntax follows the eventual proposal; the case-arity-1 spelling is the conceptual anchor — `.at(value)` injection and `case .at(let value)` matching |
| Pack-eliminator dispatch | `(each handlers)(consume value)` in fold/map/flatMap bodies | Depends on shipped pack-position-aware dispatch syntax. The contract is "exactly one handler in the pack runs, matching the active arm" |
| Pack-position discriminator | `value.hash(into:)` lacks position-tag injection in Hash conformance | Whatever the eventual mechanism is for reading the active position as an integer |
| Pack-element-equality constraint | `repeat each Element == FirstElement` (FlatMap equal-arm); `repeat each Other == Never` (Never-elim) | Pack-equality is in active Swift Evolution; the constraint syntax may be `repeat (each X) == Y` or differ slightly |
| Map equal-arm convenience | Deliberately omitted (would need `repeat _ in each Element` to mean "same arity, every position replaced by NewBoth" — not expressible today, no clear path) | Either expressible once pack-replicate / pack-reshape syntax exists, or remains the gap between `Either<T, T>` (binary) and the n-ary case |

**Gate semantics.** Swift's `#if` is parsing-aware: inactive `#if` blocks are *parsed* (syntax errors are reported) but not *semantically checked*. The gated body must therefore use only syntax the current parser accepts. The speculative bits above all parse cleanly under Swift 6.3.1 / 6.4-dev — the constraint that bit during initial authoring was Map's same-arity-replacement, which has no parseable spelling today and was dropped. Future additions need to satisfy "parses today, semantically checks once the gate is true."

**Blocker-1-only transition window.** If Blocker 1 lifts before Blocker 2, the gate flips true and the file activates — but the `~Copyable & ~Escapable` constraints on `each Element` then fail Blocker 2. Two recovery paths:

1. **Stage-1 carveout**: temporarily edit `Coproduct.swift`'s type declaration to drop the pack suppressions (`public enum Coproduct<each Element>` instead of `<each Element: ~Copyable & ~Escapable>`), matching Product's current state. Operators that take `consuming` parameters keep their bodies; closure-bearing methods drop the `~Copyable` constraint on handler parameters until Blocker 2 also clears.
2. **Wait for Blocker 2**: leave the gate as-is, but introduce a secondary gate guarding the suppressions specifically. Concretely: `#if hasFeature(VariadicEnum) && hasFeature(NoncopyableTypePack)` (the secondary feature name is speculative).

The cohort-precedent answer is path 1: Product shipped Stage-1 today (Copyable-only) and waits on the secondary blocker. Coproduct would mirror that posture during the transition.



**Decisions codified by this document** (resolving open items from prior research):

1. *Sibling package, not absorbed into either-primitives.* The earlier `future-directions.md` Candidate 6 entry left this open ("decide between absorbing-into-either-primitives vs. sibling-package"). This document chooses sibling. Rationale: `Either`'s 2026-05-09 release cohort treats the binary case as a first-class type with `.left` / `.right` ergonomic spellings; absorbing the n-ary case into the same package would mix two semantic surfaces (the `Either.left` / `Either.right` ergonomics for arity-2 with the `.at<k>(...)` ergonomics for arity-N). Sibling-package keeps each type's eliminator API uniform.

2. *Defer over ship-with-workaround.* Shape A (per-arity), B (RawPointer), and C (tuple-of-Optionals) are all available today. None matches the natural-shape declaration. Following the Pair-vs-Product precedent, this document chooses defer. The cost of waiting is low (no second-consumer is actively blocked today; the named consumers all hand-roll enums and the package's existence is not yet a blocker on their work). The cost of shipping a workaround is migration: future readers carry forward a vocabulary they did not need.

3. *Watch-list, not back-burner.* The document carries explicit unblock canaries (Features.def flag entries, diagnostic gates, sibling research-doc state changes) so that future sessions can detect the blocker lift and re-enter this analysis. This is the actionable form of the prior research's "track via Features.def" guidance.

**Loose ends** (per [RES-027]):

- *Shape choice between `Coproduct.at<k>(...)` and `Coproduct.left/.right/.middle/...`*: a *direction*, not a premise. No downstream design depends on the spelling today; the API will be designed when the package implements.
- *Whether `Either<L, R>` becomes a typealias for `Coproduct<L, R>` post-unblock*: a *direction*. Both options remain valid; the choice depends on whether `.left`/`.right` ergonomics are preserved as binary specialisations.
- *Whether to ship Shape A as an interim*: *premise* if anyone needs the package now, *direction* otherwise. Today, no consumer has stated they need it; if a second-consumer with a hard requirement materialises, this document gets revisited and Shape A becomes a candidate. No experiment package is created at this time because the premise is not currently load-bearing on any in-flight design.

## References

- `swift-either-primitives/Research/future-directions.md` — Candidate 6 (n-ary Coproduct/OneOf, DEFER verdict)
- `swift-either-primitives/Research/either-academic-and-ecosystem-survey.md` — Q3.2 (Variadic generic enums feature-flag inventory), Q1.6 (OCaml polymorphic variants, Scala 3 union types, F# Choice)
- `swift-product-primitives/Research/escapable-blocked.md` — pack-`~Copyable`/`~Escapable` blocker; sibling precedent for "defer over ship-with-workaround"
- `swift-institute/Research/escapable-support-pair-either-product.md` — cohort-wide cohort-research; the entry-point for tracking pack-suppression progress
- [Genaro-Chris/SwiftUtils — Variant.swift](https://github.com/Genaro-Chris/SwiftUtils/blob/main/Sources/SwiftUtils/Variant.swift) — third-party prior art demonstrating Shape B today
- [`swift/include/swift/AST/DiagnosticsSema.def`](https://github.com/swiftlang/swift/blob/main/include/swift/AST/DiagnosticsSema.def) — `enum_with_pack` diagnostic
- [`swift/test/Generics/variadic_generic_types.swift`](https://github.com/swiftlang/swift/blob/main/test/Generics/variadic_generic_types.swift) — "Temporary limitations" comment
- [`swift/include/swift/Basic/Features.def`](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Features.def) — feature-flag inventory
