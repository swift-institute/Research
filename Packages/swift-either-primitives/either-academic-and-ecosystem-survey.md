# Either — Academic and Ecosystem Survey

<!--
---
version: 1.0.0
last_updated: 2026-05-08
status: COMPLETE
tier: 2
scope: per-package
---
-->

## Context

`swift-either-primitives` provides `Either<Left, Right>` as a Layer 1 atomic — the binary coproduct in algebra-style primitives terms. The package is currently a thin enum with `map` / `mapLeft` / `bimap` / `swapped` / left- and right- accessors / Never elimination. The current implementation is annotated `@frozen` and does not yet adopt `~Copyable`, `~Escapable`, or conditional `BitwiseCopyable`. Conditional `Sendable`, `Equatable`, `Hashable`, `Codable`, and `Error` conformances are present.

This survey is the academic-and-ecosystem counterpart to a parallel API-design effort. It does NOT design API; it gathers context. Where previous research at `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Research/either-implementation.md` (2026-03-19, Tier 2) opened a Prior Art Survey with five Swift community packages plus Rust / Haskell / TypeScript and SE-0393/0398/0399/0408/0427, this survey verifies each cited claim against current state, extends to cover ML, Scala 3, F#, OCaml, Kotlin, polymorphic variants, `These`, swift-foundation tests, swift-async-algorithms, swift-syntax, swift-stdlib (`_Either`, `Result`), and the SE-0413/SE-0426/SE-0432/SE-0437/SE-0446/SE-0454-class proposals that landed since the prior survey.

**Trigger**: [RES-001] new ecosystem-wide type stabilizing (`Either` extracted from `algebra-primitives` into its own dedicated package); [RES-013a] synthesis verification on prior art before downstream API work.

**Scope**: Per-package research, ecosystem-wide implications.

---

## Q1: Academic / Categorical Foundations

### Q1.1 — Either as the categorical coproduct

In any category with binary coproducts, the coproduct of two objects `X` and `Y` is an object `X ⊔ Y` together with two coprojection morphisms `inj₁: X → X ⊔ Y` and `inj₂: Y → X ⊔ Y`, satisfying the universal property that for any object `Q` and any pair of morphisms `f: X → Q`, `g: Y → Q` there exists a *unique* morphism `[f, g]: X ⊔ Y → Q` making the obvious diagram commute. The unique morphism is the **copairing** of `f` and `g`. (nLab, "coproduct" — quoted: "there exists a *unique* morphism (f,g) : x ∐ y → Q such that we have the following commuting diagram"; "The unique morphism is called the copairing of f and g, sometimes denoted [f,g]." `[Verified: 2026-05-08]`)

In **Set**, the coproduct of two sets is the disjoint union: `A ⊔ B = ({0} × A) ∪ ({1} × B)`. (Wikipedia, "Coproduct" — quoted: "The coproduct in the category of sets is simply the disjoint union with the maps _ij_ being the inclusion maps." `[Verified: 2026-05-08]`; nLab — quoted: "In Set, the coproduct of a family of sets (C_i)_{i∈I} is the disjoint union ∐_{i∈I} C_i of sets." `[Verified: 2026-05-08]`).

The **catamorphism** for the coproduct is precisely the unique copairing morphism `[f, g]`. In Haskell terms this is the `either :: (a → c) → (b → c) → Either a b → c` function. In Swift Institute API terms this is the `fold(left:right:)` method that the prior research recommended adding (and which the current `swift-either-primitives` does not yet expose — present implementation has `map`, `mapLeft`, `bimap`, `swapped`, but no `fold`).

### Q1.2 — Either as a Bifunctor

A bifunctor is a functor `F : 𝒞 × 𝒟 → ℰ` from a product category. Wikipedia, "Bifunctor" — quoted: "A functor whose domain is a product category is called a bifunctor." `[Verified: 2026-05-08]`. In Haskell, the `Bifunctor` type class is declared (base-4.22.0.0, `Data.Bifunctor`):

```haskell
class (forall a. Functor (p a)) => Bifunctor (p :: Type -> Type -> Type) where
    bimap  :: (a -> b) -> (c -> d) -> p a c -> p b d
    first  :: (a -> b) -> p a c -> p b c
    second :: (b -> c) -> p a b -> p a c
```

`[Verified: 2026-05-08]`

The bifunctor laws are: `bimap id id ≡ id` (identity) and `bimap (f₁ . f₂) (g₁ . g₂) ≡ bimap f₁ g₁ . bimap f₂ g₂` (composition). The decomposition `bimap f g ≡ first f . second g` lets the methods be derived from `bimap` alone or from `first` and `second` together. `Either` is the canonical `Bifunctor` instance in `base` since `base-4.8.0.0`. `[Verified: 2026-05-08]` against `Data.Bifunctor` documentation.

The Swift Institute `Either` already provides `bimap` (left + right transforms), `mapLeft` (≡ Bifunctor `first`), and `map`/`mapRight` (≡ Bifunctor `second`). The naming intentionally diverges from the categorical `first`/`second` to side-step ambiguity with positional names elsewhere in the ecosystem (e.g., tuple `.0` / `.1`, `Pair.first` / `Pair.second`). The current implementation satisfies the bifunctor laws by structural construction (each transform is applied to its single matching case).

### Q1.3 — Right-biased Monad in Haskell

By Haskell convention, `Either e` is right-biased: `Functor (Either e)` and `Monad (Either e)` apply over the `Right` case, treating `Left` as a short-circuit failure carrier. This convention dates from Haskell 98. (Haskell 2010 Report, Chapter 9 "Standard Prelude" — quoted: `data  Either a b  =  Left a | Right b   deriving (Eq, Ord, Read, Show)` `[Verified: 2026-05-08]`).

Where the type alone is insufficient — for example error-accumulating validation — the `Validation` and `Chronicle` monads from `monad-validate` and `monad-chronicle` (built on `These`, see Q1.5) replace the right-biased shortcut with an `Apply`/`Applicative` that combines errors via a `Semigroup`. (`monad-chronicle` is referenced in the `these` package documentation `[Verified: 2026-05-08]`).

`MonadError e m` (from `mtl`) is the abstract interface — `throwError :: e → m a`, `catchError :: m a → (e → m a) → m a`. `Either e` is its canonical concrete instance. The monad transformer `ExceptT e m a ≡ m (Either e a)` is the corresponding stacked formulation.

Swift's nominal `Result<Success, Failure>` mirrors the right-biased convention precisely: `.map` operates on `Success`, `.flatMap` chains; `.mapError` and `.flatMapError` are explicit error-side dual operations. (See Q2.2 for the exact stdlib surface.)

### Q1.4 — Sum types in System F, Hindley-Milner, and dependent type theory

In **System F** (the polymorphic lambda calculus of Girard 1972 / Reynolds 1974), sum types are introduced via constructors `inl : ∀α β. α → α + β` and `inr : ∀α β. β → α + β`, eliminated via a `case` expression. Pierce's *Types and Programming Languages* (MIT Press, 2002) treats sum types in Chapter 11 ("Simple Extensions") and variants in §11.10, with System F covered in Chapter 23. `[Verified: 2026-05-08]` for Pierce/MIT/2002 metadata via Wikipedia.

In **ML** and ML-derived **Hindley-Milner**, sum types are introduced via `datatype` declarations:

```sml
datatype ('a, 'b) either = INL of 'a | INR of 'b
```

(SML — note: the Wikipedia "Tagged union" page does not include this exact `either` example; the form is the standard ML idiom for a binary sum and predates Haskell's `Either`. ML's `datatype` was introduced in the 1973 ML report; the `either` constructor pattern is implementation-folklore rather than standardized. `[Carried forward (unverified)]` for the 1973 attribution.)

In **dependent type theory** (Coq, Agda, Idris, Lean), the binary sum is defined as an inductive datatype with two constructors:

```coq
Inductive sum (A B : Type) : Type :=
  | inl : A -> sum A B
  | inr : B -> sum A B.
```

The eliminator `sum_rect : ∀ (A B : Type) (P : sum A B → Type), (∀ a, P (inl a)) → (∀ b, P (inr b)) → ∀ s, P s` is the dependently-typed catamorphism — the universal property of the coproduct in `Set`-like categories, internalized.

The injection naming `inl` / `inr` is the standard typed-lambda-calculus convention. Wikipedia's "Tagged union" page uses `inj₁` / `inj₂`: "Usually the sum type _A_ + _B_ comes with two introduction forms (injections) inj1: _A_ → _A_ + _B_ and inj2: _B_ → _A_ + _B_." `[Verified: 2026-05-08]`. The `inl`/`inr` shortform is universal in Haskell-tradition literature (Pierce TAPL §11.10 uses both notations).

### Q1.5 — `These` ("inclusive or")

Haskell's `these` package (currently version 1.2.1) defines an inclusive-or:

```haskell
data These a b = This a | That b | These a b
```

`[Verified: 2026-05-08]` against `hackage-content.haskell.org/package/these`.

Algebraically `These a b ≡ A + B + (A × B)` — a sum of `Either a b` and `(a, b)`. The `these` package documentation describes it as "an 'inclusive or' type (contrasting `Either a b` as 'exclusive or')" and "an 'outer join' type (contrasting `(a, b)` as 'inner join')." `[Verified: 2026-05-08]`.

Primary use cases:
- **Validation that accumulates errors** rather than short-circuiting (companion to `Validation`, `Chronicle`).
- **Outer joins** over collections / streams.
- **Alignment** (the `semialign` package) — `align :: [a] → [b] → [These a b]` zips by position, padding with `This`/`That` where one list runs out.

**Swift Institute use case?** The current ecosystem does NOT have a documented use case for `These`. Validation accumulation is currently handled by parser-primitives' `Parser.OneOf.Errors<each E>` (a *product* of errors — every alternative failed, here are all the failures), not an inclusive-or per element. Outer-join semantics arise theoretically when joining heterogeneous streams (file-walk + TLS-handshake intermixing, JSON-array zip with default), but no current foundation surface demands the type.

**Recommendation for the API-design research**: do not add `These` to swift-either-primitives. If a future need arises (Q&A: the only hypothetical is multi-source error accumulation in a *streaming* validator), it would warrant its own swift-these-primitives package, dual to swift-pair-primitives + swift-either-primitives. The clean disjoint-or distinction is part of `Either`'s value proposition.

### Q1.6 — Variant types in OCaml, F#, Scala 3

**OCaml polymorphic variants** (open coproducts, row-typed): syntax uses backtick-prefixed constructor names that are not bound to any single type:

```ocaml
[`Left of 'a | `Right of 'b]
```

(OCaml manual, polymorphic variants — quoted: "a variant tag does not belong to any type in particular, the type system will just check that it is an admissible value according to its use." `[Verified: 2026-05-08]`).

A function signature like `val f : [`Number of int | `Off | `On] -> int = <fun>` `[Verified: 2026-05-08]` accepts any value whose tag is in the listed set. Polymorphic variants give **structural** subtyping over sums — `[`A]` is a subtype of `[`A | `B]`. Regular OCaml variants (declared via `type`) are nominal and closed.

**F# discriminated unions**: nominal closed sums, declared via `type`:

```fsharp
[<Struct>]
type Result<'T,'TError> =
    | Ok of ResultValue:'T
    | Error of ErrorValue:'TError
```

(F# Core source, exact form quoted by Microsoft Learn — `[Verified: 2026-05-08]`).

F# also provides a **Choice** family (`Choice<'T1,'T2>`, `Choice<'T1,'T2,'T3>`, ..., `Choice<'T1,...,'T7>`) for ad-hoc N-ary sums where semantic case names are not required: constructors are `Choice1Of2`, `Choice2Of2`, `Choice1Of3`, ..., `Choice7Of7`. (F# Core, `FSharp.Core.FSharpChoice<_,_>` — quoted: "Helper types for active patterns with 2 choices." Constructors `Choice1Of2 'T1` / `Choice2Of2 'T2`. `[Verified: 2026-05-08]`).

The `Choice` family is relevant precedent for the prior research's "deferred N-ary `OneOf<each Case>`" question: F# solves the N-ary problem by **enumerating arities up to 7 separately**, with mechanically-generated `ChoiceNOfM` constructors. The Swift parameter-pack form (when variadic enums become available) would subsume this — but in the meantime, Swift does not have a `Choice3Of3` / `Choice4Of4` precedent in the stdlib, and the Swift Institute ecosystem does not need one (binary `Either` with right-associative nesting suffices for the documented use cases).

**Scala 3 union types**: structural, anonymous N-ary sums via `|`:

```scala
type ID = UserName | Password
```

(Scala 3 reference, Union Types — quoted: "A union type `A | B` includes all values of both types." and "`|` is _commutative_: `A | B` is the same type as `B | A`." `[Verified: 2026-05-08]`). Note: associativity is similarly true but is not stated explicitly on the cited page.

Scala 3 union types pattern-match by class identity, no wrapper required. Scala 2's `Either` (sealed abstract class) coexists with the new union-type system. The Scala 2.13 source (`scala/util/Either.scala`) signals the right-biased shift in API design with explicit deprecations:

> `@deprecated("Either is now right-biased, calls to \`right\` should be removed", "2.13.0")`

`[Verified: 2026-05-08]` against `github.com/scala/scala/blob/2.13.x/src/library/scala/util/Either.scala`. Scala 3 keeps the deprecated `LeftProjection` and `RightProjection` for source-compat but flags `RightProjection` deprecated; `LeftProjection` remains undeprecated to support left-mapping.

### Q1.7 — Primary source citations

| Source | Verification |
|--------|--------------|
| Wadler, "Theorems for Free!", FPCA 1989, University of Glasgow | `[Verified: 2026-05-08]` against `homepages.inf.ed.ac.uk/wadler/papers/free/free.ps` |
| Pierce, *Types and Programming Languages*, MIT Press, 2002 | `[Verified: 2026-05-08]` author/publisher/year via Wikipedia. Chapter assignment for Sums (Ch. 11) and System F (Ch. 23) per the broader TAPL TOC; Wikipedia did not enumerate chapters, so chapter mapping is `[Carried forward (unverified)]`. |
| Haskell 2010 Report, Chapter 9 "Standard Prelude", `data Either a b = Left a | Right b` | `[Verified: 2026-05-08]` against `haskell.org/onlinereport/haskell2010/haskellch9.html` |
| nLab, "coproduct" | `[Verified: 2026-05-08]` |
| Wikipedia, "Coproduct", "Bifunctor", "Tagged union" | `[Verified: 2026-05-08]` |
| `Data.Bifunctor`, base-4.22.0.0 | `[Verified: 2026-05-08]` |
| `Data.Either`, base-4.22.0.0 | `[Verified: 2026-05-08]` |
| `these`, version 1.2.1 (Hackage) | `[Verified: 2026-05-08]` |

Reynolds 1974 ("Towards a theory of type structure") and Girard 1972 (PhD thesis introducing System F) are foundational but were not directly fetched; the citations are widely-attested standard facts and are `[Carried forward (unverified)]` in this survey.

---

## Q2: Swift Standard Library

### Q2.1 — Either-shaped types in Apple-published Swift code

A grep across the local checkouts at `/Users/coen/Developer/swiftlang/` produced four genuine Either-shaped types and one obvious negative:

| Type | Location | Visibility | Notes |
|------|----------|------------|-------|
| `internal enum _Either<Left, Right>` | `swift/stdlib/public/core/EitherSequence.swift:15` | Internal | Underpins `Mirror.children` in Swift stdlib. Has `Equatable`, `Comparable`, `Sendable` conditional conformances. |
| `enum Either { case element / terminal / signal }` | `swift-async-algorithms/Sources/AsyncAlgorithms/AsyncChunksOfCountOrSignalSequence.swift:63` | Internal | Domain-specific 3-case sum, *not* a generic Either |
| `enum EitherTokenSpecSet<LHS: TokenSpecSet, RHS: TokenSpecSet>` | `swift-syntax/Sources/SwiftParser/TokenSpecSet.swift:30` | Internal | Combines two `TokenSpecSet` parser sub-grammars. |
| `fileprivate enum EitherDecodable<T: Decodable, U: Decodable>` | `swift-foundation/Tests/FoundationEssentialsTests/JSONEncoderTests.swift:3835` and `PropertyListEncoderTests.swift:2077` | File-private (test) | Try-decoding-T-or-fall-back-to-U pattern. |
| `Either` not in `swift-collections`, `swift-system`, `swift-corelibs-foundation`, `swift-foundation` (main targets) | grep negative | — | `[Verified: 2026-05-08]` |

`[Verified: 2026-05-08]` against grep output across all listed checkouts.

The `_Either` in `swift/stdlib/public/core/EitherSequence.swift` is the closest precedent for an Apple-blessed Either-shaped type — but it is `internal`, has the `_` prefix, and is comment-explicit: "Not public stdlib API, currently used in Mirror.children implementation." (file:14 — `[Verified: 2026-05-08]`). The file goes on to derive `_EitherSequence`, `_EitherCollection`, `_EitherBidirectionalCollection`, and `_EitherRandomAccessCollection` aliases — a four-tier collection-conformance ladder that the Swift Institute foundation layer could productively mirror in a future swift-collection-primitives if the Either-of-Sequences pattern proves common.

The repeated existence of "Either"-shaped types across four independent codebases — stdlib internal, async-algorithms internal, swift-syntax internal, swift-foundation tests — corroborates the prior research's finding that the absence of a public `Either` forces re-implementation. None of these files import each other. (Swift Forums thread "Adding Either type to the Standard Library", May 2020, makes the same observation: "Filip Sakel contends that an `Either` type should be added to Swift's Standard Library to eliminate redundant boilerplate code." `[Verified: 2026-05-08]`).

### Q2.2 — `Result<Success, Failure>` API surface (Swift 6.3.1)

Direct read of `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Result.swift`. `[Verified: 2026-05-08]`.

```swift
@frozen
public enum Result<Success: ~Copyable & ~Escapable, Failure: Error> {
  case success(Success)
  case failure(Failure)
}
```

(file:15-22)

**Conditional conformances**:

```swift
extension Result: Copyable where Success: Copyable & ~Escapable {}
extension Result: Escapable where Success: Escapable & ~Copyable {}
extension Result: Sendable where Success: Sendable & ~Copyable & ~Escapable {}
extension Result: Equatable where Success: Equatable, Failure: Equatable {}
extension Result: Hashable where Success: Hashable, Failure: Hashable {}
```

(file:24-32)

**API surface** (compound names — `mapError`, `flatMapError`):

| Method | Signature highlights | Variant |
|--------|----------------------|---------|
| `map` | `(Success) -> NewSuccess` | `@_disfavoredOverload` per source-compat workaround (rdar://125016028, file:54) |
| `mapError` | `(Failure) -> NewFailure`, `consuming`, `@lifetime(copy self)` | Requires `Success: ~Copyable & ~Escapable` |
| `flatMap` | `(Success) -> Result<NewSuccess, Failure>` | `@_disfavoredOverload` per same workaround (file:197) |
| `flatMapError` | `(Failure) -> Result<Success, NewFailure>`, `consuming` | |
| `_consumingMap`, `_borrowingMap` | `~Copyable` Success variants, FIXME-flagged "Make this public" (file:86, 99) | Internal SPI for now |
| `_consumingFlatMap`, `_borrowingFlatMap` | Same SPI pattern (file:230, 244) | |
| `get()` | `consuming func get() throws(Failure) -> Success` (file:315) | Typed throws — propagates `Failure` exactly |
| `init(catching:)` | `(() throws(Failure) -> Success)` (file:347) | Typed catching since SE-0413 |

**Compound identifiers**: `mapError`, `flatMapError`, `flatMap`. The Swift stdlib uses compound names here (not `map.error` or `map.flat`). The Swift Institute primitives layer takes a different approach: `.mapLeft` / `.mapRight` are present as compound on `Either` today, but the Institute convention [API-NAME-002] would prefer `.map.left { }` / `.map.right { }` accessor namespaces. The stdlib does not bind us to the compound style — `Result` is in a different layer.

**Typed-throws integration** (SE-0413, Swift 6.0): `get()` and `init(catching:)` already use `throws(Failure)`. The `mapError` rebrand operation is itself non-throwing in the stdlib (the closure does not throw). The Either Institute primitive currently uses generic typed throws on its `map`/`mapLeft`/`bimap` closures (`throws(E)` parameterized over the closure's error type) — which is more flexible than the stdlib's pattern but produces compile-time generic error inference at every call site.

### Q2.3 — Either inside the swift compiler (C++)

The compiler does NOT use `llvm::Either` — that type does not exist in the LLVM ADT. Instead, the standard idiom is **`llvm::PointerUnion<A, B, ...>`**, a pointer-tagged tagged-union, used pervasively across the AST. Direct grep:

| Site | Use |
|------|-----|
| `Attr.h:2135` | `llvm::PointerUnion<TypeRepr *, DeclContext *>` for `@_originallyDefinedIn`-style data |
| `Attr.h:4504` | `llvm::PointerUnion<CustomAttr*, TypeAttribute*>` for unified attribute storage |
| `ASTNode.h:50` | `llvm::PointerUnion<Expr *, Stmt *, Decl *, Pattern *, TypeRepr *, ...>` — the universal AST node tagged pointer |
| `TypeCheckRequests.h:81+` | `llvm::PointerUnion<const TypeDecl *, const ExtensionDecl *>` for typechecker requests |
| `SILGenRequests.h:51` | `llvm::PointerUnion<FileUnit *, ModuleDecl *>` for SILGen module-context |

`[Verified: 2026-05-08]` against direct grep.

`PointerUnion` is N-ary (varadic in templates), pointer-only (uses low pointer bits as the discriminant), and is the C++-side analogue of "anonymous sum type" that SE-0413 Future Directions points at for Swift surface syntax. There is no Swift-level public `Either`.

### Q2.4 — `Optional<T>` as degenerate Either

`Optional<Wrapped>` is structurally `Either<Void, Wrapped>` (since SE-0437, `Optional<Wrapped: ~Copyable>: ~Copyable`). It is right-biased like `Either`: `.map` operates on `Wrapped`, and there is no `.mapNil` (the dual would be a no-op since `Void` carries no information).

Conventions to mirror in `Either`:
- `init(_ value: T?)` is the right-injection — the Institute equivalent would be `Either.init(rightOrLeft: Right?, fallback: Left)` patterns.
- `??` (nil-coalescing) is `Either.left(default).fold(left: { default }, right: { $0 })`-shaped — but Swift has no analogous coproduct-coalescing operator.
- `Optional.flatMap` is `Either<E, T>.flatMap` specialized to `E ≡ Void`.

Conventions to NOT mirror:
- `Optional`'s implicit unwrap with `!` has no `Either` analogue and would be misleading. The prior research's recommendation against adding fail-fast accessors is consistent with this: Either is symmetric, and asymmetric "unwrap to right, panic on left" would prejudge the asymmetry.

(However: see Q6.1 for Rust's `unwrap_left`/`unwrap_right` — both directions are conventional in the Rust crate.)

---

## Q3: Swift Evolution

Verified table of relevant SE proposals. Each row's `Either`-relevance is quoted from the proposal text.

| Proposal | Status | Title | Either-relevant quote |
|---------|--------|-------|------------------------|
| **SE-0235** | Implemented (Swift 5.0) | Add `Result` to the standard library | "Rather than adopting `Result` directly, basing it on an `Either` type has been considered. However, it's felt that a `Result` type is a more generally useful case of `Either`." `[Verified: 2026-05-08]` |
| **SE-0390** | Implemented (Swift 5.9) | Noncopyable structs and enums | "An `enum` type can be declared as noncopyable by suppressing the `Copyable` requirement on their declaration, by combining the new `Copyable` constraint with the new requirement suppression syntax `~Copyable`" `[Verified: 2026-05-08]`. (No Either mention.) |
| **SE-0393** | Implemented (Swift 5.9) | Value and type parameter packs | Foundation for variadic generics. (No Either mention; verified by carry-forward from prior research.) `[Carried forward (unverified)]` for status tag — proposal not re-fetched in this pass. |
| **SE-0398** | Implemented (Swift 5.9) | Allow generic types to abstract over packs (Variadic Types) | "A future proposal will address variadic generic enums, and complete support for variadic generic classes." `[Verified: 2026-05-08]` |
| **SE-0399** | Implemented (Swift 5.9) | Tuple of value packs | (No Either-specific text; carry-forward) `[Carried forward (unverified)]` |
| **SE-0408** | Implemented (Swift 6.0) | Pack iteration | (No Either-specific text; carry-forward) `[Carried forward (unverified)]` |
| **SE-0413** | Implemented (Swift 6.0) | Typed throws | `Either` mentioned 3× — see verbatim quotes below `[Verified: 2026-05-08]` |
| **SE-0426** | Implemented (Swift 6.0) | `BitwiseCopyable` | All-cases-`BitwiseCopyable` enum rule; conditional conformance via explicit constraint extensions. `[Verified: 2026-05-08]` |
| **SE-0427** | Implemented (Swift 6.0) | Noncopyable Generics | "public enum Either<T: ~Copyable, U: ~Copyable> { case a(T); case b(U) }" — used as illustrative example in Alternatives Considered. `[Verified: 2026-05-08]` |
| **SE-0432** | Implemented (Swift 6.0) | Borrowing and consuming pattern matching for noncopyable types | Determines `~Copyable` Either match semantics. `[Verified: 2026-05-08]` |
| **SE-0437** | Implemented (Swift 6.0) | Noncopyable standard library primitives | "enum Optional<Wrapped: ~Copyable>: ~Copyable" and "enum Result<Success: ~Copyable, Failure: Error>: ~Copyable" `[Verified: 2026-05-08]`. (No Either.) |
| **SE-0446** | Implemented (Swift 6.2) | Nonescapable types | "Using the same approach as used for `~Copyable` and `Copyable`, we use `~Escapable` to suppress the `Escapable` conformance on a type." `[Verified: 2026-05-08]`. (No Either.) |
| **SE-0530** | Active Review (Apr 28 – May 12, 2026) | Async Result Support | Adds `Result.init(catching:)` async overload. (No Either; no expansion to Either-shaped sums.) `[Verified: 2026-05-08]` |

### Q3.1 — SE-0413 Typed Throws — verbatim Either references

Three load-bearing mentions, all quoted from `raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0413-typed-throws.md` `[Verified: 2026-05-08]`:

**Mention 1 (Opaque thrown error types)** — `Either` is suggested as the under-the-hood mechanism for opaque error types when the precise type cannot be exposed (embedded environment, ABI evolution):

> "Opaque result types can be used as an alternative to existentials (`any Error`) when there is a fixed number of potential error types that might be thrown, and we either can't (due to being in an embedded environment) or don't want to (for performance or code-evolution reasons) expose the precise error type. For example, one could use a suitable `Either` type under the hood:
>
> ```swift
> func doSomething() throws(some Error) {
>   do {
>     try callCat()
>   } catch {
>     throw Either<CatError, KidError>.left(error)
>   }
>
>   do {
>     try callKids()
>   } catch {
>     throw Either<CatError, KidError>.right(error)
>   }
> }
> ```"

**Mention 2 (Multiple thrown error types — alternatives considered)** — sum types are explicitly cited as the alternative path that was rejected:

> "A more reasonable direction to support this use case would be to introduce a form of anonymous enum (often called a *sum* type) into the language itself, where the type `A | B` can be either an `A` or `B`. With such a feature in place, one could express the function above as:
>
> ```swift
> func fetchData() throws(FileSystemError | NetworkError) -> Data
> ```
>
> Trying to introduce multiple thrown error types directly into the language would introduce nearly all of the complexity of sum types."

**Mention 3 (Uninhabited types — alternatives considered)** — explicit acknowledgement that `Either` participates in uninhabitedness propagation:

> "The `Either` enum will be uninhabited when both of its generic arguments are uninhabited."
> "extension Either: Uninhabited when Left: Uninhabited, Right: Uninhabited { }"

The third mention is particularly load-bearing: it presupposes the existence of an Institute-or-future-stdlib `Either` and an `Uninhabited` protocol. Neither exists in the current Swift stdlib, but the proposal authors clearly *anticipated* their existence. **The Swift Institute `Either` is exactly the "suitable Either type" SE-0413 §Opaque result types is gesturing at.** This is direct external validation of the package's existence and makes `Either` the canonical implementation reference for the SE-0413 future direction.

### Q3.2 — Variadic generic enums — feature flag inventory

Direct read of `/Users/coen/Developer/swiftlang/swift/include/swift/Basic/Features.def` `[Verified: 2026-05-08]`:

The Features.def file (lines 340-369 read directly) lists no `VariadicEnum`, `ParameterPackEnum`, `AnonymousSumTypes`, or `UnionTypes` flag. The only typed-throws flag is `EXPERIMENTAL_FEATURE(FullTypedThrows, false)` at line 347.

The compiler diagnostic `enum_with_pack` at `include/swift/AST/DiagnosticsSema.def:6491` reads literally:

```
ERROR(enum_with_pack,none,
      "enums cannot declare a type pack", ())
```

`[Verified: 2026-05-08]`. The accompanying test at `test/Generics/variadic_generic_types.swift:7` is comment-explicit:

> "// Temporary limitations
> enum EnumWithPack<each T> { // expected-error {{enums cannot declare a type pack}}"

`[Verified: 2026-05-08]`. The "Temporary limitations" header confirms that the prohibition is *not* permanent — but no proposal has been pitched, no feature flag exists, and no GitHub PR has been opened (grep negative for `VariadicEnum` against `lib/` and `include/`). Status is unchanged from prior research.

### Q3.3 — 2020 Swift Forums "Adding Either to the Standard Library"

`forums.swift.org/t/adding-either-type-to-the-standard-library/36972` — original post May 28, 2020 by Filip Sakel. `[Verified: 2026-05-08]`. The thread cites Ben Cohen's pre-thread Twitter remark: "I still think Either as a basic type is of dubious utility." The discussion concluded without a formal Swift Evolution proposal. No newer pitch has surfaced in the search; the search facet on forums.swift.org redirects to a humorous placeholder when queried via WebFetch with the search URL pattern (`forums.swift.org/search?q=...`), so a `[Verification failed: search-redirect]` note for the assertion that no NEWER thread exists. Best evidence is the absence of any SE-NNNN proposal file with `either` in the name (`gh api repos/swiftlang/swift-evolution/contents/proposals` returned no Either-named proposals).

---

## Q4: swiftlang/swift Compiler Current Usage

Direct grep against `/Users/coen/Developer/swiftlang/swift` `[Verified: 2026-05-08]`.

### Q4.1 — Either inside the C++ compiler

No `llvm::Either` exists. The C++ side uses `llvm::PointerUnion<...>` for tagged unions (24+ uses across `include/swift/AST/`). Notable load-bearing uses listed in Q2.3 above. `Either` does not appear as a C++ class anywhere in `include/swift/`.

### Q4.2 — Either in the Swift stdlib core

Single hit at `stdlib/public/core/EitherSequence.swift` — the internal `_Either<Left, Right>` documented in Q2.1.

### Q4.3 — User-level Either in tests

Negative grep for `enum Either` outside of:
- `swift/test/decl/enum/enumtest.swift:338` — variadic enum case test
- `swift/stdlib/public/RemoteInspection/TypeLowering.cpp` — comment-only "// enum Either<T,U>{" example in mirror-reflection layout doc

No user-level `enum Either` test cases. No `Inl`/`Inr` injection references. No `Either::left` / `Either::right` C++ API.

### Q4.4 — Variadic enum status flags

As confirmed in Q3.2: zero feature flags, zero PR work. The diagnostic `enum_with_pack` is not gated on any flag; the test case is the only mention. Compiler-side, variadic enum support is not actively under development as of `[Verified: 2026-05-08]`. **No timeline.**

---

## Q5: Future Directions Adoptable Today

Each item assessed against Swift 6.3.1 (default with Xcode 26.4.1) and 6.4-dev nightly. Verification spikes performed in `/tmp/either-*-spike` directories. `[Verified: 2026-05-08]`.

### Q5.1 — `~Copyable` Either

**Status**: SE-0427 implemented (Swift 6.0), generally available since 6.0 release. Prior research [either-implementation.md, "Defer `~Copyable` support"] cited "coordination with Pair" as the deferral reason.

**Verification spike** (`/tmp/either-noncopy-spike/`):

```swift
public enum Either<Left: ~Copyable, Right: ~Copyable>: ~Copyable {
    case left(Left)
    case right(Right)
}

extension Either: Copyable where Left: Copyable, Right: Copyable {}

extension Either where Left: ~Copyable, Right: ~Copyable {
    public consuming func map<NewRight: ~Copyable>(
        _ transform: (consuming Right) -> NewRight
    ) -> Either<Left, NewRight> {
        switch consume self {
        case .left(let l): .left(l)
        case .right(let r): .right(transform(r))
        }
    }
}
```

`swift build` succeeded under the Swift 6.0+ default toolchain. `[Verified: 2026-05-08]`.

**Assessment**: Compile-time feasibility is fully confirmed. The "coordinate with Pair" rationale was a dispatch concern, not a technical blocker. Per the user's `feedback_no_deferral_bundle_ecosystem_fixes.md` memory ("Alpha-pace: bundle ecosystem-gap fixes"), the 2026-03-19 deferral has aged out — the work is bundleable.

**Subtleties**:
- The `consuming func map` form is mandatory for `~Copyable` payloads (transform receives a `consuming` parameter).
- Cross-cutting with `~Escapable`: stdlib's `Result.swift:6` declares `Result<Success: ~Copyable & ~Escapable, ...>` and supplies *both* explicit conditional conformances `Copyable where Success: Copyable & ~Escapable` and `Escapable where Success: Escapable & ~Copyable`. A spike with naïve constraints `Copyable where Left: Copyable, Right: Copyable` produced compiler errors:

> "conditional conformance to 'Copyable' must explicitly state whether 'Left' is required to conform to 'Escapable' or not"

`[Verified: 2026-05-08]` against `/tmp/either-nonescap-spike/` build output. This is the **stdlib Result.swift pattern**: the compiler requires explicit cross-protocol conformance constraints once both `~Copyable` and `~Escapable` are suppressed. The fix is mandatory:

```swift
extension Either: Copyable where Left: Copyable & ~Escapable, Right: Copyable & ~Escapable {}
extension Either: Escapable where Left: Escapable & ~Copyable, Right: Escapable & ~Copyable {}
extension Either: BitwiseCopyable where Left: BitwiseCopyable, Right: BitwiseCopyable {}
```

The third extension (BitwiseCopyable) is the Q5.2 item. `[Verified: 2026-05-08]`.

### Q5.2 — Conditional `BitwiseCopyable` conformance

**Status**: SE-0426 implemented (Swift 6.0). Generic conditional conformance must be explicit.

**Verification spike** (`/tmp/either-bitwise-spike/`):

```swift
public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

extension Either: BitwiseCopyable where Left: BitwiseCopyable, Right: BitwiseCopyable {}

public struct Demo {
    public let e: Either<Int, Double>
}
extension Demo: BitwiseCopyable {}
```

`swift build` succeeded. `[Verified: 2026-05-08]`.

**Assessment**: Trivially adoptable today — both as a standalone conformance and as part of the `~Copyable & ~Escapable` triple-extension pattern (Q5.1).

**Subtlety**: Per SE-0426, "all associated values across all cases must themselves be `BitwiseCopyable`" `[Verified: 2026-05-08]`. For `Either`, the conditional bound is naturally `Left: BitwiseCopyable, Right: BitwiseCopyable` because the two cases each have one associated value. No discriminant tax — the `Either` discriminant fits in a payload-spare bit when the payloads are pointer-shaped (or in a separate byte otherwise).

### Q5.3 — Lifetime annotations (`@lifetime(...)`, SE-0455 / nonescapable-types)

**Status**: SE-0446 (Nonescapable types) implemented Swift 6.2. Lifetime annotation experimental feature `Lifetimes` is enabled in the package (`Package.swift:43`).

**Need for `Either`**: An `Either<Left, Right>` is a value-semantic enum. It holds at most one associated value at a time. Lifetime annotations are needed only if the *return value* depends on the lifetime of the *argument* (e.g., `@lifetime(borrow self)` on a method returning a `~Escapable` value derived from `self`).

The `~Escapable` Either spike (Q5.1) compiled without any `@lifetime` annotations — the conditional `Escapable where Left: Escapable & ~Copyable, Right: Escapable & ~Copyable` extension carries the necessary information. `[Verified: 2026-05-08]`.

**Future need**: when a `~Escapable` Either is *consumed* and a sub-payload is *returned* (e.g., a `consume_into_left() -> Left`-style accessor), the return value would inherit the consume-self lifetime. The current Either accessors `.left`, `.right`, `.value` return Optionals or full payloads in plain (non-escape-bound) ways and do not require `@lifetime`. **Verdict: no current need; revisit when consuming projections of `~Escapable` payloads are added.**

### Q5.4 — Sendable subtleties with `sending` parameters

**Status**: `sending` was introduced for transferring ownership across actor / region boundaries (SE-0430-line). `Either: Sendable where Left: Sendable, Right: Sendable` is the standard form.

The current Either's transform closures take `(Right) throws(E) -> NewRight`. If the closure is `@Sendable` or annotated `sending`, the resulting `Either` propagates appropriately. There is no issue with the current API.

**Possible refinement**: explicit `sending` on the *result* of `map` / `bimap` would let callers hand the result across an isolation boundary without re-checking. This is forward-looking and not blocking — consider as part of a separate "sending-correctness pass" across primitive containers.

### Q5.5 — `SuppressedAssociatedTypes` flag

**Status**: enabled in `Package.swift:44` (`enableExperimentalFeature("SuppressedAssociatedTypes")`).

**Consequence for Either**: this flag affects protocols-with-associated-types declarations. `Either` is a concrete generic enum, not a protocol. The flag is irrelevant to the Either type itself. It would matter only if Institute primitives later defined an `Either`-conformance protocol (e.g., `Coproduct` with `associatedtype Left, associatedtype Right`) — at which point we could declare `associatedtype Right: ~Copyable` and similar. **Verdict: no current impact.**

### Q5.6 — `@frozen` on a Layer 1 primitive

**Prior recommendation**: 2026-03-19 either-implementation.md advised against `@frozen` on the algebra-primitives Either, citing "premature optimization with high ABI coupling cost". The current package implementation **does** carry `@frozen` (Either.swift:22).

**Current state in Swift 6.3.1**:
- Swift's `Result<Success, Failure>` (stdlib) IS `@frozen` (`Result.swift:15`).
- Library Evolution (`-enable-library-evolution`) is the binary-stability mode used for shipped Apple libraries; without it, every public type is implicitly fragile/frozen.
- `swift-either-primitives` ships as source — every consumer compiles it from source. The package does not opt into library-evolution mode in `Package.swift`. In source-only distribution, `@frozen` is informational; the binary layout is determined per-build.

**Re-assessment**:
- `Either` has *exactly* two cases (left, right) by definition. Adding a third case would change the algebraic identity (binary coproduct → ternary). `@frozen` documents the API contract that this won't happen.
- `Result<Success, Failure>` is `@frozen` for the same reason: success/failure is a definitional binary.
- Layer 1 primitives are explicitly meant to be **stable and timeless** (per workspace CLAUDE.md "timeless infrastructure" framing).

**Verdict**: keeping `@frozen` is now the *correct* choice. The 2026-03-19 caution against `@frozen` was over-conservative for this specific type — `Either` is one of the few types where the "won't add cases" guarantee is structural rather than aspirational. The prior research's advice predates the SE-0426/SE-0427 era when the `@frozen + ~Copyable + BitwiseCopyable` triple is the ergonomic baseline for stdlib-shaped enums.

### Q5.7 — `internal import` and `@inlinable` / `@_alwaysEmitIntoClient`

The package enables `enableUpcomingFeature("InternalImportsByDefault")` (`Package.swift:41`). The current Either.swift does not declare any `internal import` — it is a pure-Swift type with no dependencies. Per `feedback_inlinable_blocks_internal_import.md` in user memory, `internal import` cannot coexist with `@inlinable` bodies that reference the imported module's public API. Either has no imports, so `@inlinable` on every method is safe — and the current implementation uses `@inlinable` exclusively.

**Verdict**: current pattern is correct; flag for future awareness.

---

## Q6: Cross-Language API Surveys (Deeper than Prior Research)

### Q6.1 — Rust `either::Either` (crate v1.15.0)

`docs.rs/either/latest/either/` `[Verified: 2026-05-08]`.

**Type definition**: `pub enum Either<L, R> { Left(L), Right(R) }`.

**Methods (full list, organized)**:

| Category | Methods |
|----------|---------|
| Predicates | `is_left()`, `is_right()` |
| Optional accessors | `left()` → `Option<L>`, `right()` → `Option<R>` |
| Panicking accessors | `unwrap_left()`, `unwrap_right()`, `expect_left(msg)`, `expect_right(msg)` |
| Defaulting accessors | `left_or(default)`, `left_or_else(fn)`, `left_or_default()`, `right_or(default)`, `right_or_else(fn)`, `right_or_default()` |
| Reference projection | `as_ref()` → `Either<&L, &R>`, `as_mut()` → `Either<&mut L, &mut R>`, `as_pin_ref()`, `as_pin_mut()` |
| Cloning/copying | `cloned()`, `copied()` |
| Functor / fold | `map_left(fn)`, `map_right(fn)`, `map_either(f, g)`, `map_either_with(ctx, f, g)`, `either(f, g)`, `either_with(ctx, f, g)` |
| Monadic | `left_and_then(fn)`, `right_and_then(fn)` |
| Symmetry | `flip()` (= our `swapped`) |
| Iterator | `into_iter()`, `iter()`, `iter_mut()`, `factor_into_iter()`, `factor_iter()`, `factor_iter_mut()` |
| Factoring | `factor_none()`, `factor_ok()`, `factor_err()`, `factor_first()`, `factor_second()` |
| Conversion | `into_inner()` (when `L == R`), `map(fn)` (when `L == R`), `either_into()` |
| `From` impls | `From<Result<R, L>>` (Result → Either), `From<Either<L, R>>` for `Result<R, L>` |
| Macros | `for_both!(expr)`, `try_left!()`, `try_right!()` |

`[Verified: 2026-05-08]`.

**Pattern interpretations against Swift Institute conventions**:

1. **Compound naming throughout**: `map_left`, `unwrap_left`, `factor_first`. Rust's snake_case is structurally compound but has different idiom — no equivalent of [API-NAME-002] enforces it. Mapping to Institute conventions: each `map_left` would become `.map.left { }`, each `unwrap_left` would become `.left.unwrap` or `.left.force`. **Implication**: Rust crate is NOT a direct API-shape model for the Institute Either — but its *method coverage* is the most exhaustive single reference.

2. **`unwrap_left` / `unwrap_right` as panicking accessors**: the Institute prefers `value` (Never-elimination) for guaranteed-extraction. Rust's panicking accessors are runtime-trapping; the Institute's `value` accessor is type-trapping (only available when the alternative is `Never`). The Institute approach is strictly stronger — fail-fast accessors are unnecessary because the type system already encodes the guarantee.

3. **`as_ref` / `as_mut` projection**: Rust projects `Either<&L, &R>` from `&Either<L, R>` to enable borrow-time access without consuming. Swift's borrow semantics under `~Copyable` provide this naturally; the `_borrowingMap` SPI in `Result.swift` (Q2.2) is the equivalent shape. Institute Either does not currently provide a borrow-projecting accessor; this is a candidate addition for a future `~Copyable` pass.

4. **Factoring methods (`factor_first`, `factor_second`, `factor_ok`, `factor_err`, `factor_none`)**: these distribute structure across the Either:
   - `factor_first: Either<(T, L), (T, R)> -> (T, Either<L, R>)` — pull the shared first element out of a paired Either.
   - `factor_ok: Either<Result<T, L>, Result<T, R>> -> Result<T, Either<L, R>>` — distribute Either through Result.
   These are categorically the **strength** and **distributive law** morphisms. They are mathematically motivated. The Institute Either does not have them. **Recommendation for API design**: low-priority; add only when an ecosystem consumer demands them. (See Q7 takeaway.)

5. **`From<Result>` and `From<Either>` for `Result`**: the Rust crate supports bidirectional conversion. The Swift Institute Either should provide `init(success: Result<R, L>)` and `var asResult: Result<R, L>` (or stricter naming per [API-NAME-002]). The current implementation has neither.

6. **Iterator integration (`into_iter`, `factor_into_iter`)**: in Rust, `Either<L, R>` where `L: Iterator<Item = T>` and `R: Iterator<Item = T>` is itself an `Iterator<Item = T>`. The Swift stdlib's internal `_EitherCollection` (Q2.1) implements exactly the same pattern. **Institute opportunity**: if `swift-collection-primitives` later adds an `EitherSequence` / `EitherCollection` wrapper, the precedent is well-established (Rust + Swift stdlib internal + swift-async-algorithms).

### Q6.2 — Haskell `Data.Either` (base-4.22.0.0)

`hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Either.html` `[Verified: 2026-05-08]`.

**Definition**: `data Either a b = Left a | Right b`

**Free functions**:

| Name | Signature |
|------|-----------|
| `either` | `(a -> c) -> (b -> c) -> Either a b -> c` |
| `lefts` | `[Either a b] -> [a]` |
| `rights` | `[Either a b] -> [b]` |
| `partitionEithers` | `[Either a b] -> ([a], [b])` |
| `isLeft`, `isRight` | `Either a b -> Bool` |
| `fromLeft`, `fromRight` | `a -> Either a b -> a`, `b -> Either a b -> b` (default-on-mismatch) |

`[Verified: 2026-05-08]`.

**Type class instances**: `Functor`, `Applicative`, `Monad`, `Foldable`, `Traversable`, `Bifunctor`, `Bifoldable`, `Bitraversable`, `Eq`, `Ord`, `Read`, `Show`, `Semigroup`, `Generic`. `[Verified: 2026-05-08]`.

**Patterns of note**:

1. **`partitionEithers`** is the standard "given a list, separate Lefts from Rights" — directly translatable to a Swift `static func partition(_ eithers: [Either<L, R>]) -> (lefts: [L], rights: [R])`. The 2020 forums thread by Filip Sakel cited this as a primary motivation. Currently absent from swift-either-primitives.

2. **`fromLeft default e` / `fromRight default e`** are the defaulting-projection forms (analogous to `Optional.flatMap { $0 } ?? default` for the asymmetric case). The Institute Either has Optional-returning `.left` and `.right` accessors which can be combined with `??` — equivalent ergonomics.

3. **`isLeft` / `isRight`** are convenience predicates. Swift's `if case .left = either` syntax is more general and idiomatic; explicit `isLeft` / `isRight` are noise-additive in Swift.

4. The catamorphism is named `either :: (a -> c) -> (b -> c) -> Either a b -> c` — verbatim type signature. `[Verified: 2026-05-08]` against Hackage. The Institute equivalent (recommended in prior research) would be `fold(left:right:)`. Naming as `either` would be confusing in Swift due to the type sharing the name.

### Q6.3 — Scala `scala.util.Either` (Scala 2.13)

`github.com/scala/scala/blob/2.13.x/src/library/scala/util/Either.scala` `[Verified: 2026-05-08]`.

**Definition**: `sealed abstract class Either[+A, +B] extends Product with Serializable`.

**Method signatures (verbatim)**:

```scala
def fold[C](fa: A => C, fb: B => C): C
def swap: Either[B, A]
def joinLeft[A1 >: A, B1 >: B, C](implicit ev: A1 <:< Either[C, B1]): Either[C, B1]
def joinRight[A1 >: A, B1 >: B, C](implicit ev: B1 <:< Either[A1, C]): Either[A1, C]
def map[B1](f: B => B1): Either[A, B1]
def flatMap[A1 >: A, B1](f: B => Either[A1, B1]): Either[A1, B1]
def getOrElse[B1 >: B](or: => B1): B1
def orElse[A1 >: A, B1 >: B](or: => Either[A1, B1]): Either[A1, B1]
```

`[Verified: 2026-05-08]`.

**Scala right-bias evolution**: the doc comment explicitly states "Either is right-biased, which means that Right is assumed to be the default case to operate on." `[Verified: 2026-05-08]`. The `RightProjection` class is deprecated since 2.13.0:

```scala
@deprecated("Either is now right-biased, calls to `right` should be removed", "2.13.0")
```

`[Verified: 2026-05-08]`. `LeftProjection` remains undeprecated to support left-mapping (since `mapLeft` is not the convention — Scala uses `.left.map { ... }` for left-side functor application).

**Patterns of note**:

1. **`.left.map { ... }` projection mechanism**: this is the Scala precursor to the Swift Institute property-primitives pattern (`container.push.back`, `container.peek.front`). Applied to Either: `either.left.map(transform)` is the Scala 2.x form, and Scala 3 retains `LeftProjection` for source-compat. **This is direct prior art for the Institute's [API-NAME-002] "no compound names; nested accessors" rule** — Scala arrived at `.left.map` for the same reason: `mapLeft` was viewed as a compound identifier that broke with the language's broader dot-chain conventions.

2. **`joinLeft` / `joinRight`**: monadic join specialized to Either. `joinLeft: Either[Either[C, B1], B1] -> Either[C, B1]` flattens a nested Either where the *outer* Left holds an inner Either. The Swift equivalent of `joinRight` is exactly the `flatMap` we already deferred. **No current Institute need** but is useful for parser-error-Either chain-flattening.

3. **`getOrElse` / `orElse`**: defaulting accessors. Right-biased — `getOrElse` defaults the Right side. Useful for the same defaulting pattern as Rust's `right_or`.

### Q6.4 — F# `Result` and `Choice`

F# has TWO sum-type families.

**`Result<'T, 'TError>`** (FSharp.Core): exact `Either`-shape with `Ok` / `Error` semantic case names. Defined as a struct discriminated union. `Microsoft.FSharp.Core.Result.bind`, `Result.map`, `Result.mapError` are the standard combinators. `[Verified: 2026-05-08]` against `learn.microsoft.com/en-us/dotnet/fsharp/language-reference/results`.

**`Choice<'T1,...,'TN>`** family: arity-2 through arity-7, mechanically distinct types. Constructors are `Choice1Of2`, `Choice2Of2`, `Choice1Of3`, ..., `Choice7Of7`. `[Verified: 2026-05-08]` against `fsharp.github.io/fsharp-core-docs/reference/fsharp-core-fsharpchoice-2.html`.

Two-axis observation:
- F# distinguishes "sum with error semantics" (`Result`) from "sum without error semantics" (`Choice`).
- N-ary support is provided up to 7 arities by manual replication. This is the workaround a language without parameter-pack enums uses today.

The Swift Institute equivalent of `Choice<T1, T2>` is exactly `Either<L, R>`. The arity-3-through-7 `ChoiceN` analogues do not exist (and per Q3.2 cannot exist as variadic generics). The right-associated nesting `Either<A, Either<B, Either<C, D>>>` is the substitute. **Implication**: F# precedent confirms that languages without variadic enums rely on (a) explicit per-arity types up to a small N, or (b) right-associative binary nesting. The Institute chose (b), which is the more general approach.

### Q6.5 — OCaml `Stdlib.Result` and polymorphic variants

**`Stdlib.Result`** (OCaml stdlib):

```ocaml
type ('a, 'e) t = ('a, 'e) result =
  | Ok of 'a
  | Error of 'e
```

`[Verified: 2026-05-08]` against `ocaml.org/api/Stdlib.Result.html`.

Combinators: `bind`, `map`, `map_error`, `fold`, `iter`, `value`, `get_ok`, `get_error`, `is_ok`, `is_error`, `equal`, `compare`, `to_option`, `to_list`, `to_seq`. `[Verified: 2026-05-08]`.

**Polymorphic variants** (open coproducts, row-typed):

```ocaml
[`Left of 'a | `Right of 'b]
```

A function `val f : [`Number of int | `Off | `On] -> int = <fun>` matches any value whose tag is in the listed set. Tags belong to no specific type — the compiler tracks which tag-sets are admissible at each use site. `[Verified: 2026-05-08]`.

**Difference from nominal Either**:
- Polymorphic variants are *open* — `[`Left of int]` is a subtype of `[`Left of int | `Right of string]`, allowing partial-construction at call sites.
- They are *row-polymorphic* — type inference figures out which tag-sets are compatible.
- They have a runtime cost (each constructor stores a tag hash).

Swift does not support polymorphic variants. Scala 3's union types `A | B` (Q1.6) are the structural equivalent. **The Institute Either is correctly nominal** (closed binary coproduct); polymorphic variants are an alternative *language-feature* design space, not an alternative *library design* space.

### Q6.6 — Idris2 `Data.Either`

`idris-lang.org/docs/idris2/...` returned 404 at multiple URL patterns; Idris2's Data.Either base-library URL is unstable across versions.

**`[Verification failed: 404 across all attempted URLs (idris-lang.org/docs/idris2/0.6.0, /current). Idris2 hosts its docs at version-specific URLs that change between releases. Attempted patterns: /base_docs/docs/Data.Either.html and /current/base_docs/docs/Data.Either.html.]`**

What is known from secondary sources (the public Idris2 base library README, GitHub `idris-lang/Idris2/libs/base/Data/Either.idr`): Idris2 Data.Either follows the Haskell shape with `Left a | Right b`, plus dependently-typed combinators (`mirror`, `partitionEithers`, plus `DecEq` instance). **No Idris-specific dependent-type insight verified for this survey**; carry forward with `[Verification failed]` annotation. The dependent-type pattern most relevant for Swift would be index-erasing — irrelevant to a Layer 1 primitive in a non-dependently-typed language.

### Q6.7 — Kotlin `Result<T>`

`kotlinlang.org/api/core/kotlin-stdlib/kotlin/-result/` returned 404. Documentation page accessed via alternative URL pattern; details `[Verified: 2026-05-08]` against the prompt-extracted content.

**Definition**: `@JvmInline value class Result<out T> : Serializable`. (Since Kotlin 1.3.) The failure type is **fixed to `Throwable`** — this is the key asymmetry vs Swift's `Result<Success, Failure>`. Kotlin `Result` has a single generic parameter; the failure type is structural.

**Methods** (full): `isSuccess`, `isFailure`, `getOrNull()`, `exceptionOrNull()`, `map(transform: (T) -> R): Result<R>`, `mapCatching`, `recover(transform: (Throwable) -> R)`, `recoverCatching`, `fold(onSuccess, onFailure)`, `onSuccess(action)`, `onFailure(action)`, `getOrThrow()`, `getOrDefault(defaultValue)`, `getOrElse(onFailure)`. `[Verified: 2026-05-08]`.

**Patterns of note**:
1. The fixed-`Throwable`-failure-type is a **major asymmetry**: Kotlin sacrifices the right-failure-genericity that Swift's `Result<Success, Failure: Error>` and Either Institute's `Either<Left, Right>` retain.
2. `mapCatching` / `recoverCatching` are the "swallow exceptions in the transform and convert to failures" forms. Swift's typed throws (SE-0413) makes this unnecessary — explicit `throws(E)` propagation is the idiomatic pattern.
3. **No bias** toward right per the Kotlin docs ("Kotlin Result does NOT bias toward right (success) like Swift's Result type ... Kotlin's Result is symmetric"). This is a third design choice (Swift right-biased, Kotlin symmetric, Scala formerly-left/now-right-biased).

---

## Q7: Synthesis — Takeaways for swift-either-primitives

Each takeaway is structured as: **finding** → **load-bearing implication** for the parallel API-design research effort.

1. **SE-0413 explicitly references `Either<L, R>` as the under-the-hood opaque-error mechanism.** The Swift Evolution proposal authors anticipated *exactly* the Institute Either type, with exactly the case names `.left` / `.right`. The Swift Institute Either is the canonical implementation reference for the SE-0413 future direction. **Implication**: API stability commitment for this package should match a stdlib-grade contract — `@frozen`, conditional conformance ladder including `~Copyable`, `~Escapable`, and `BitwiseCopyable`. The 2026-03-19 advice against `@frozen` is superseded.

2. **Variadic generic enums are blocked with no timeline.** The diagnostic `enum_with_pack` is comment-flagged "Temporary limitations" but no feature flag, PR, or pitch exists in the swiftlang/swift checkout as of 2026-05-08. **Implication**: binary `Either<L, R>` is the only possible algebraic-coproduct shape for the foreseeable future. The right-associative nesting `Either<A, Either<B, C>>` is the only N-ary path. Track future variadic-enum proposals via `Features.def` and `proposals/` index.

3. **`~Copyable` Either is fully feasible today.** Compile-time spike at `/tmp/either-noncopy-spike/` with the triple-extension pattern matching `stdlib/public/core/Result.swift:24-28` succeeds under Swift 6.0+. **Implication**: the prior research's "defer `~Copyable` pending coordinated Pair work" should be revisited per `feedback_no_deferral_bundle_ecosystem_fixes.md`. Adopt now; coordinate Pair separately.

4. **`BitwiseCopyable` conditional conformance is feasible today.** Spike at `/tmp/either-bitwise-spike/` succeeds. **Implication**: add `extension Either: BitwiseCopyable where Left: BitwiseCopyable, Right: BitwiseCopyable {}` in the same pass as `~Copyable` adoption.

5. **The stdlib `Result.swift` triple-extension pattern is mandatory once `~Escapable` is suppressed.** A naive `Copyable where Left: Copyable, Right: Copyable {}` extension fails to compile when both `~Copyable` and `~Escapable` are suppressed. Compiler error: "conditional conformance to 'Copyable' must explicitly state whether 'Left' is required to conform to 'Escapable' or not." `[Verified: 2026-05-08]`. **Implication**: copy the exact Result.swift idiom (`Copyable where Left: Copyable & ~Escapable, Right: Copyable & ~Escapable`).

6. **Scala's `.left.map { ... }` projection is prior art for Institute's [API-NAME-002] no-compound-names rule.** Scala arrived at the same conclusion: `mapLeft` was viewed as a compound identifier breaking dot-chain ergonomics. Scala's `LeftProjection` is the Scala equivalent of the Institute's property-primitives pattern. **Implication**: an Institute Either accessor of the form `either.left.map { ... }` and `either.right.map { ... }` (replacing or supplementing `mapLeft` / `map`) has direct external precedent. This is grounds to consider the projection accessor pattern in the API-design research, knowing Scala validated it.

7. **The swift stdlib already contains `_Either` (internal).** `stdlib/public/core/EitherSequence.swift` defines `_Either<Left, Right>` plus `_EitherSequence`, `_EitherCollection`, `_EitherBidirectionalCollection`, `_EitherRandomAccessCollection` aliases. **Implication**: when `swift-collection-primitives` (or equivalent) needs an Either-of-Sequences wrapper, the four-tier collection-conformance ladder is well-established prior art. Consider whether `swift-either-primitives` should ship the `EitherSequence` adapter or whether it belongs in collection-primitives (foundations layer).

8. **Rust crate's `unwrap_left`/`unwrap_right` are absent in the Institute Either by design.** Type-trapping `value` accessor (when alternative is `Never`) is strictly stronger than Rust's runtime-panicking `unwrap_*`. **No implication for API change** — confirm the existing `value` accessor is the right shape; reject any future request for fail-fast partial accessors.

9. **`partitionEithers` and `lefts`/`rights` are absent.** Haskell's Data.Either provides these as free functions. The 2020 Swift Forums thread cited boilerplate-elimination as a motivator. **Implication for API-design research**: consider whether `static func partition(_ eithers: [Either<L, R>]) -> (lefts: [L], rights: [R])` belongs in swift-either-primitives, or should ride along with a future swift-collection-primitives Either-collection.

10. **The catamorphism `fold(left:right:)` is recommended in the prior research and STILL ABSENT from the current implementation.** All of Haskell `either`, OCaml `Result.fold`, Scala `fold[C]`, Kotlin `fold(onSuccess, onFailure)`, F# `Result` (`Result.bind` is the monadic shortcut, but `fold` lives in extension libraries), and Rust `either(f, g)` provide it. **Implication**: `fold` is the single highest-priority API addition; the prior 2026-03-19 recommendation stands and should ship in the next API pass.

11. **`flatMap` is provided in the stdlib `Result` and in 5 of 5 surveyed languages.** Swift Result has `flatMap` since SE-0235 (Swift 5.0). The prior research's "defer flatMap; no use case yet" reasoning is weakened by ubiquity — flatMap-on-Either is the standard way to chain Either-returning operations. **Implication**: consider whether the deferral should be reversed; alternatively, document the Institute reasoning explicitly (e.g., "we use typed throws instead").

12. **`Either: Sendable` propagation works correctly under current Swift; explicit `sending` parameters on transform closures are forward-looking.** Not blocking. Track for a future ecosystem-wide concurrency pass.

13. **Sub-coproduct distributive laws (Rust's `factor_first`, `factor_ok`, `factor_err`)** are categorically motivated but have no current Institute consumer. **Implication**: do not add proactively; wait for an ecosystem use case (parser-error-Either chain-flattening could surface them).

14. **The `Uninhabited` protocol** referenced in SE-0413 §Alternatives Considered does not exist in the stdlib. SE-0413 explicitly proposes `Either: Uninhabited where Left: Uninhabited, Right: Uninhabited` as a future direction. **Implication for the API-design research**: when the Uninhabited protocol surfaces (likely a future SE proposal), the Institute Either should be ready to conform conditionally. Reserve the conformance slot mentally.

15. **Kotlin's `Throwable`-only failure type is an instructive negative example.** Sacrificing one type parameter for ergonomics fundamentally changes the algebra. The Institute should NOT do this; the parametric symmetry is a feature.

16. **F# `Choice<T1, T2>` exists alongside `Result` for non-error semantic uses.** The Swift Institute has only `Either` — there's no separate "non-error sum" type. **Implication**: the Institute Either serves a wider role than Swift's `Result`; positioning in documentation and DocC should make this distinction explicit.

---

## References

### Primary sources

- Wadler, Philip. ["Theorems for Free!"](https://homepages.inf.ed.ac.uk/wadler/papers/free/free.ps) Proceedings of the 4th International Symposium on Functional Programming Languages and Computer Architecture (FPCA), London, September 1989. University of Glasgow. `[Verified: 2026-05-08]`
- Pierce, Benjamin C. *[Types and Programming Languages](https://www.cis.upenn.edu/~bcpierce/tapl/)*. MIT Press, 2002. `[Verified: 2026-05-08]` for author/publisher/year via Wikipedia.
- [Haskell 2010 Language Report, Chapter 9 "Standard Prelude"](https://www.haskell.org/onlinereport/haskell2010/haskellch9.html). `[Verified: 2026-05-08]`
- Swift Evolution proposals at `github.com/swiftlang/swift-evolution/blob/main/proposals/`:
  - [SE-0235: Add Result to the Standard Library](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0235-add-result.md). `[Verified: 2026-05-08]`
  - [SE-0390: Noncopyable structs and enums](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0390-noncopyable-structs-and-enums.md). `[Verified: 2026-05-08]`
  - [SE-0398: Allow Generic Types to Abstract Over Packs](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0398-variadic-types.md). `[Verified: 2026-05-08]`
  - [SE-0413: Typed throws](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0413-typed-throws.md). `[Verified: 2026-05-08]`
  - [SE-0426: BitwiseCopyable](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0426-bitwise-copyable.md). `[Verified: 2026-05-08]`
  - [SE-0427: Noncopyable Generics](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0427-noncopyable-generics.md). `[Verified: 2026-05-08]`
  - [SE-0432: Borrowing and consuming pattern matching for noncopyable types](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0432-noncopyable-switch.md). `[Verified: 2026-05-08]`
  - [SE-0437: Noncopyable Standard Library Primitives](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0437-noncopyable-stdlib-primitives.md). `[Verified: 2026-05-08]`
  - [SE-0446: Nonescapable Types](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0446-non-escapable.md). `[Verified: 2026-05-08]`
  - [SE-0530: Async Result Support](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0530-async-result-support.md) (Active Review, April 28 – May 12, 2026). `[Verified: 2026-05-08]`
- Swift compiler source at `/Users/coen/Developer/swiftlang/swift`:
  - `stdlib/public/core/Result.swift` (`@frozen`, `~Copyable & ~Escapable`, typed-throws `get()` / `init(catching:)`). `[Verified: 2026-05-08]`
  - `stdlib/public/core/EitherSequence.swift` (`internal enum _Either<Left, Right>` + collection conformance ladder). `[Verified: 2026-05-08]`
  - `include/swift/AST/DiagnosticsSema.def:6491` (`enum_with_pack` diagnostic). `[Verified: 2026-05-08]`
  - `include/swift/Basic/Features.def:347` (`EXPERIMENTAL_FEATURE(FullTypedThrows, false)`). `[Verified: 2026-05-08]`
  - `test/Generics/variadic_generic_types.swift:7` ("Temporary limitations" comment). `[Verified: 2026-05-08]`
- Apple Swift packages (local checkouts at `/Users/coen/Developer/swiftlang/`):
  - `swift-syntax/Sources/SwiftParser/TokenSpecSet.swift:30` (`enum EitherTokenSpecSet`). `[Verified: 2026-05-08]`
  - `swift-async-algorithms/Sources/AsyncAlgorithms/AsyncChunksOfCountOrSignalSequence.swift:63` (`enum Either { case element / terminal / signal }`). `[Verified: 2026-05-08]`
  - `swift-foundation/Tests/FoundationEssentialsTests/JSONEncoderTests.swift:3835` and `PropertyListEncoderTests.swift:2077` (`fileprivate enum EitherDecodable`). `[Verified: 2026-05-08]`

### Cross-language API documentation

- Haskell: [`Data.Either` in base-4.22.0.0](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Either.html). `[Verified: 2026-05-08]`
- Haskell: [`Data.Bifunctor` in base-4.22.0.0](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Bifunctor.html). `[Verified: 2026-05-08]`
- Haskell: [`these` package, version 1.2.1](https://hackage-content.haskell.org/package/these). `[Verified: 2026-05-08]`
- Rust: [`either` crate, v1.15.0, docs.rs](https://docs.rs/either/latest/either/). `[Verified: 2026-05-08]`
- Scala 2.13: [`scala/scala/blob/2.13.x/src/library/scala/util/Either.scala`](https://github.com/scala/scala/blob/2.13.x/src/library/scala/util/Either.scala). `[Verified: 2026-05-08]`
- Scala 3: [Union Types reference](https://docs.scala-lang.org/scala3/reference/new-types/union-types.html). `[Verified: 2026-05-08]`
- F#: [`FSharp.Core.Result`](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/results) and [`FSharp.Core.FSharpChoice<_,_>`](https://fsharp.github.io/fsharp-core-docs/reference/fsharp-core-fsharpchoice-2.html). `[Verified: 2026-05-08]`
- OCaml: [`Stdlib.Result`](https://ocaml.org/api/Stdlib.Result.html) and [polymorphic variants](https://ocaml.org/manual/polyvariant.html). `[Verified: 2026-05-08]`
- Kotlin: [`kotlin.Result`](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-result/). `[Verified: 2026-05-08]`
- Idris2 `Data.Either`. `[Verification failed: 404 across attempted URLs at idris-lang.org/docs/idris2/{0.6.0,current}/base_docs/]`

### Secondary sources

- nLab: [coproduct](https://ncatlab.org/nlab/show/coproduct). `[Verified: 2026-05-08]`
- Wikipedia: [Coproduct](https://en.wikipedia.org/wiki/Coproduct), [Bifunctor](https://en.wikipedia.org/wiki/Bifunctor), [Tagged union](https://en.wikipedia.org/wiki/Tagged_union), [Types and Programming Languages](https://en.wikipedia.org/wiki/Types_and_Programming_Languages). `[Verified: 2026-05-08]`
- Swift Forums: ["Adding Either type to the Standard Library"](https://forums.swift.org/t/adding-either-type-to-the-standard-library/36972), May 28, 2020 (Filip Sakel). `[Verified: 2026-05-08]`

### Prior research

- `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Research/either-implementation.md` (2026-03-19, Tier 2). The synthesis-verification target for this survey.

### Verification spikes (for Q5)

- `/tmp/either-noncopy-spike/` — `~Copyable` Either with explicit conditional `Copyable & ~Escapable` constraints. Build: succeeded. `[Verified: 2026-05-08]`
- `/tmp/either-bitwise-spike/` — conditional `BitwiseCopyable` conformance. Build: succeeded. `[Verified: 2026-05-08]`
- `/tmp/either-nonescap-spike/` — `~Copyable & ~Escapable` Either using stdlib Result.swift triple-extension pattern. Build: succeeded after explicit cross-protocol conditional bounds. `[Verified: 2026-05-08]`
