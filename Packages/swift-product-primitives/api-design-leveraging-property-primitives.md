# Product API Design — Leveraging Property-Primitives

<!--
---
version: 1.0.0
last_updated: 2026-05-08
status: RECOMMENDATION
tier: 2
scope: per-package
---
-->

## Context

`Product<each Element>` is the n-ary cartesian product type, recently extracted
from `swift-algebra-primitives` into the standalone `swift-product-primitives`
package. Its current public surface
(`/Users/coen/Developer/swift-primitives/swift-product-primitives/Sources/Product Primitives/Product.swift:25-73`,
*Verified: 2026-05-08*) consists of:

* the storage `var values: (repeat each Element)`;
* a single canonical initializer `init(_ values: repeat each Element)`;
* a `@dynamicMemberLookup` subscript that re-exposes tuple positions
  (`product.0`, `product.1`, …);
* conditional conformances to `Sendable`, `Equatable`, `Hashable`, and
  `Swift.Error`.

The type ships **no transformations**. There is no `map`, no `bimap`, no
`swap`, no projection beyond the key-path subscript. The README, DocC, and
test suite (`Product Tests.swift`, *Verified: 2026-05-08*) collectively
exercise only construction, equality, hashing, and dynamic-member access. The
single commit `49d9a4c` is the extraction baseline.

Two parallel facts shape the question:

1. **A peer document exists for `Either`.** The sibling coproduct package
   `swift-either-primitives` recently completed an analogous Tier 2
   investigation
   (`/Users/coen/Developer/swift-primitives/swift-either-primitives/Research/api-design-property-leverage.md`
   v1.0.0, *Verified: 2026-05-08*), which classified Either's functor surface
   as **single-form** (one verb `map`, label-disambiguated `(left:)` /
   `(right:)` / `(left:right:)`) and recommended labeled-method overloads
   over the `Property.View` namespace pattern. The Either document explicitly
   notes (lines 881–896) that `Pair` and Either share the same anti-pattern
   and "the migration is parallel". It also names "API-mirror for tagged
   scalars beyond Either / Pair" (line 952) as a candidate convention to
   codify if a third or fourth instance arrives. Product is one such
   instance — the n-ary generalization of Pair.

2. **The user's vision** offers two illustrative shapes to evaluate:
   `.map.left` / `.map.first` (Property.View namespace) versus
   `.map(left:)` / `.map(first:)` (labeled-method overloads). Both shapes
   are explicitly compatible with [API-NAME-002] (no compound identifiers).
   This document evaluates them — and several alternatives — for the n-ary
   case.

The shape Product picks now will mirror across `Pair`, `Either`, and any
future tagged scalar / cartesian-product / coproduct family the ecosystem
introduces. This is precedent-setting work — Tier 2 under [RES-020].

**Trigger**: convention-violation surfaced in the parent
`swift-algebra-primitives` package; scope split during the cohort that
created `swift-product-primitives` (49d9a4c) and `swift-either-primitives`.
Picking the final API shape now is cheaper than deferring; the package has
**zero** non-trivial functor consumers and the migration cost is bounded.

**Scope**: per-package — the surface change is local to
`swift-product-primitives` and its test suite. The recommended shape SHOULD
mirror to `swift-pair-primitives` and SHOULD harmonize with the recommendation
already in `swift-either-primitives/Research/api-design-property-leverage.md`.

**Peer document**: a parallel research agent is producing
`academic-and-ecosystem-survey.md` covering academic and broader-ecosystem
prior art (Haskell, Idris, OCaml, Scala, Rust, TypeScript). This document
focuses on **Swift-ecosystem precedent** (existing packages, SE proposals,
type-system reach in Swift 6.3.1 / 6.4-dev) and is the structurally-grounded
companion. Both documents inform the same recommendation.

---

## Question

The Tier 2 mandate decomposes into five sub-questions:

1. **Q1. What does Product semantically support?** Enumerate the
   categorically-valid operations on a cartesian product (projection, functor
   map, n-functor map, total transform, swap/permutation, fold, append/prepend,
   zip, currying, applicative apply/pure) and, for each, document
   whether Swift parameter packs in 6.3.1 / 6.4-dev can express it, and what
   the call site reads like under each candidate API shape.

2. **Q2. What candidate API shapes exist?** Enumerate the design space
   (Either-style compound names; labeled-method overloads;
   `Property.View` namespace; key-path-driven; free-function operators;
   hybrids; pack-iterating closures). For each shape, address
   [API-NAME-008] fit, [API-NAME-002] compliance,
   [API-ERR-001] typed-throws ergonomics, variadic arity reach,
   `~Copyable` extensibility, and discoverability.

3. **Q3. Property-primitives integration.** Property-primitives ships five
   variants ([PRP-001]). For each variant, evaluate whether `Product<each
   Element>` can adopt it. The hard question: does Property.View's
   phantom-tag mechanism survive a parameter-pack base type?

4. **Q4. Codable / Comparable / additional conformances.** Verify the
   `Product.swift:72-73` comment against current Swift 6.3.1 (the comment
   claims Codable "may not be directly expressible in current Swift"). Also
   evaluate Comparable, CustomStringConvertible, ExpressibleByArrayLiteral,
   and Collection-shaped iteration.

5. **Q5. Recommendation.** Per [RES-022], structural correctness dominates
   diff-size. Recommend the shape that maximizes intent at the call site
   ([IMPL-INTENT]), maximizes compiler-enforced strictness ([IMPL-COMPILE]),
   scales to arbitrary arity, threads typed throws cleanly, is consistent
   with existing ecosystem precedent, and is implementable in Swift 6.3.1
   today. Provide a concrete implementation sketch.

---

## Constraints

| ID | Statement | Where it bites Product |
|----|-----------|------------------------|
| [API-NAME-001] | Nest.Name pattern; no compound type names. | Tags must nest *under* `Product`, but **`enum` cannot declare a type pack** (see Q3). Tag enums must live at module scope or use a workaround. |
| [API-NAME-001a] | Single-inhabitant namespace is a variant label, not a namespace. | `Product.Map` containing only `.first` / `.second` / `.all` is borderline — see Q5. |
| [API-NAME-002] | No compound method/property names. | Bans `mapFirst`, `mapSecond`, `bimap`, `trimap`, etc. The current package complies *by absence* — there are no such methods yet. |
| [API-NAME-008] | Multi-form → Property.View; single-form → labeled method. | Decides between `product.map.first { }` and `product.map(first: )` for the per-position case. |
| [API-ERR-001] | Typed throws required. | Every transform closure must accept `(T) throws(E) -> U` and propagate `E`. |
| [API-IMPL-005] | One type per file. | Tag enums (if used) and Product itself split across files. Currently complied with — `Product.swift` is the only declaration file. |
| [API-IMPL-008] | Minimal type body. | All methods in extensions; type body holds only the tuple field and canonical init. Currently complied with. |
| [API-IMPL-012] | Closure parameters trail the signature. | Any `map(first: f, second: g)` call already complies; reorderings violate. |
| [API-IMPL-013] | Multiple closures follow lifecycle order. | Per-position closures are NOT a "lifecycle"; their ordering is **positional** (first → second → third), which matches type-parameter order — coincidentally compatible. |
| [IMPL-INTENT] | Code reads as intent, not mechanism. | The chosen shape must read as a *what* (apply this transform to that side), not a *how* (yield this property, mutate it via a coroutine). |
| [IMPL-020] | Verb-as-property + `callAsFunction` for tag types. | Available if Property.View is chosen, but the pack interaction is non-trivial — see Q3. |
| [IMPL-021] | Use `Property.Inout` / `Property.Borrow` for `~Copyable`; `Property` / `Property.Typed` for `Copyable`. | Selects the right variant. Product is `Copyable` today; `~Copyable` is **blocked** by the language (`each Element: ~Copyable` is rejected — see Q4). |
| [IMPL-023] | Core logic in static methods; instance methods delegate. | Static layer can keep compound names per [IMPL-024]. Mirrors the Either decision. |
| [IMPL-024] | Compound identifiers permitted at the static layer; banned in public instance API. | Lets a hypothetical `Product.mapFirst` (static) survive while `instance.mapFirst` cannot. |
| [PRP-001] | Pick Property variant by `Copyable`/`~Copyable` × method/property axis. | Product is `Copyable`; either `Property` (method-case) or `Property.Typed` (property-case) is in play. |
| [PRP-002] | Tags are empty enums nested in the container. | **Cannot apply directly** — Swift forbids `enum Map {}` inside `extension Product { … }` (compile error: "enums cannot declare a type pack"). Workaround: declare the tag at module scope, or as a nested `struct` (which does compile). |
| [PRP-003] | `typealias Property<Tag>` scoped to the container. | **Works** for Product per `test1` / `test2` (Verified: 2026-05-08). |
| [PRP-005] | Method extensions use `Property<Tag>`. | Method extensions on `Property` carrying their own pack parameter compile (`test15b`, *Verified: 2026-05-08*); methods extending an extension's outer pack do **not** (`test15`, *Verified: 2026-05-08*). |
| [PRP-007] | The CoW-safe `_modify` recipe. | Product is a value-type with full payload — no shared storage, no CoW concern. The recipe machinery is overhead with no payoff (same defect Either has). |
| [PRP-013] | Accessor names follow [API-NAME-002] in consumer code too. | Cannot fall back to `.mapped.first { }` or `.transformed.first { }`. |

**Forward-compatibility constraint**: in Swift 6.3.1 (and as far as I can
verify on 6.4-dev) `each Element: ~Copyable` is rejected — see Q4 result for
`test16`. The "future `~Copyable` Product" the user asked about is therefore
**blocked at the language level today**. Any recommendation must remain
clean to migrate IF that blocker lifts in a later toolchain, but should not
require it.

---

## Pre-Survey: Internal Research Grep

Per [RES-019], I grepped:

```bash
grep -rl -i 'product\|cartesian\|bimap\|n-ary\|parameter pack' \
    /Users/coen/Developer/swift-institute/Research/

grep -rli 'property.view\|property.typed\|property.consuming' \
    /Users/coen/Developer/swift-institute/Research/

grep -rl 'product\|cartesian\|bimap' \
    /Users/coen/Developer/swift-primitives/swift-either-primitives/

ls /Users/coen/Developer/swift-primitives/swift-property-primitives/Research/ 2>/dev/null
```

Material results (*Verified: 2026-05-08*):

| Document | Relevance |
|---------|-----------|
| `swift-either-primitives/Research/api-design-property-leverage.md` (v1.0.0, RECOMMENDATION) | **Direct precedent** — same convention question on the binary coproduct sibling. Recommends labeled-method overloads. Cited extensively below. |
| `swift-primitives/swift-property-primitives/Research/property-type-family.md` (v1.0.0, IMPLEMENTED) | Foundational Property type-family paper. Three pattern taxonomy. |
| `swift-primitives/swift-property-primitives/Research/case-study-dictionary-primitives-migration-failure.md` | Case where Property-pattern does NOT fit (multiple generic parameters, doubly-nested chains). Shape-similarity to Product warrants citing. |
| `swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md` | Tag semantics under different role categories. |
| `swift-institute/Research/comparative-list-stack-primitives.md` | Multi-form Property.View precedent. |

**No internal research exists on Product** (or on n-ary generalizations of
either/pair) prior to this document. The closest precedents are Either's
recent v1.0.0 doc and the foundational Property type-family paper. This
document extends both.

---

## Q1. Operations on the Cartesian Product

The cartesian product `A × B × C × …` is the universal object of products in
the category of types. Operations on it fall into seven families. For each,
I document: (a) the categorical motivation, (b) Swift 6.3.1 expressibility
(verified empirically), and (c) what the call site reads like under each
candidate shape.

### Q1.1 Projection (πᵢ)

**Categorical**: every product object has projection morphisms `πᵢ: A × B ×
… → Tᵢ` for each component `i`. They are the defining property of the
product (universal property).

**Swift 6.3.1**: Already shipped via three independent mechanisms:

| Mechanism | Call site | Source |
|-----------|-----------|--------|
| Stored field + tuple-index | `product.values.0` | `Product.swift:27` |
| `@dynamicMemberLookup` subscript | `product.0` | `Product.swift:39-41` |
| Pack-typed key path on stored field | `product.values[keyPath: \.0]` | implied by `@dynamicMemberLookup` |

These three forms are well-served. **No design action required** for
projection.

### Q1.2 Functor Map (Per-Position)

**Categorical**: a product is a *bifunctor* (binary), *trifunctor* (ternary),
or in general an **n-functor**. The per-position map `mapᵢ: (Tᵢ → Uᵢ) →
A × … × Tᵢ × … → A × … × Uᵢ × …` transforms one component while preserving
the rest. For `n = 2` this is conventionally `mapFirst` / `mapSecond`; for
`n ≥ 3` it generalizes to `map_at_i`.

**Swift 6.3.1 empirical findings** (*Verified: 2026-05-08*):

* **`extension Product<First, Second>` is rejected** by the compiler:
  `error: same-type requirements between packs and concrete types are not
  yet supported` (`test14.swift`). This blocks every "concrete-arity instance
  method" approach. Cf. `MEMORY.md` `pack-concrete-same-type.md` —
  generalizes beyond extensions.

* **Free functions with concrete arity work**:
  ```swift
  public func map<First, Second, NewFirst, E: Error>(
      _ p: Product<First, Second>,
      first transform: (First) throws(E) -> NewFirst
  ) throws(E) -> Product<NewFirst, Second> { … }
  ```
  (`test13.swift`, *Verified: 2026-05-08*) — concrete-arity overloads are
  fine **only** when written as free functions or as static methods on a
  *different* type.

* **A `static func` on `Product` with `where repeat each Element == Never`
  fails** with the same error (`test9.swift`).

* **Pack-iterating total map works**:
  ```swift
  extension Product {
      public func map<each NewElement, E: Error>(
          _ transforms: repeat (each Element) throws(E) -> each NewElement
      ) throws(E) -> Product<repeat each NewElement> { … }
  }
  ```
  (`test7.swift`, `test10.swift`, *Verified: 2026-05-08*) — this transforms
  ALL components in one call, taking one closure per position. It is the
  n-ary generalization of `bimap`/`trimap`.

* **Per-position labeled instance methods do NOT work** as
  `product.map(first: …)` — there is no way to constrain `extension Product`
  to "exactly two elements", so the labeled-method form is reachable only
  through free functions or a fixed-arity sister type.

**Call-site readings under each shape** (n=2 example, mapping the first):

| Shape | Call site | Compiles in 6.3.1 | Notes |
|-------|-----------|-------------------|-------|
| Either-style compound | `pair.mapFirst { $0 + 1 }` | No (no `extension Product<First, Second>`) | Would need free function |
| Labeled overload — instance | `pair.map(first: { $0 + 1 })` | No | Same blocker |
| Labeled overload — free function | `Product.map(pair, first: { $0 + 1 })` or `map(pair, first: …)` | Yes | Awkward at call site |
| Property.View namespace | `pair.map.first { $0 + 1 }` | Yes (with workaround for tag enum) | See Q3 |
| Pack-iterating total | `pair.map({ $0 + 1 }, { $0 })` | Yes | Verbose for "just first" — must supply identity for second |
| Key-path-driven | `pair.modifying(\.0) { $0 + 1 }` | Partially — `\.0` exists on the tuple, but the function would need pack arithmetic to reconstruct a new Product | Awkward |

The single per-position labeled-instance form **is genuinely unavailable in
Swift 6.3.1**. This is not a design-preference question; it is a language
constraint.

### Q1.3 Total Transform (n-Functor Map)

**Categorical**: the total map `(T₁ → U₁) × (T₂ → U₂) × … × (Tₙ → Uₙ) → (T₁ × T₂ × … → U₁ × U₂ × …)`.

**Swift 6.3.1**: Cleanly expressible via a pack of closure types
(`test7.swift`, *Verified: 2026-05-08*):

```swift
extension Product {
    @inlinable
    public func map<each NewElement, E: Swift.Error>(
        _ transforms: repeat (each Element) throws(E) -> each NewElement
    ) throws(E) -> Product<repeat each NewElement> {
        Product<repeat each NewElement>(
            repeat try (each transforms)(each values)
        )
    }
}

// Call site:
let transformed = try product.map({ $0 + 1 }, { $0.uppercased() }, { !$0 })
```

This is the **most natural fit** for a parameter-pack-based product type:
one closure per position, all packed together. It also subsumes the partial
case — supply identity for positions you don't want to change — at a cost
of verbosity.

### Q1.4 Swap / Permutation / Reorder

**Categorical**: products are commutative up to isomorphism. The binary swap
is `(A, B) → (B, A)`; for n ≥ 3, every permutation σ of `{1, …, n}` lifts to
an isomorphism `(T₁ × T₂ × … × Tₙ) → (T_{σ(1)} × T_{σ(2)} × … × T_{σ(n)})`.

**Swift 6.3.1**: Binary swap requires concrete-arity, which means free
function:
```swift
public func swapped<First, Second>(
    _ p: Product<First, Second>
) -> Product<Second, First> {
    Product(p.values.1, p.values.0)
}
```

For arbitrary `n`, expressing every permutation is impractical at the type
level. The pragmatic choice is to expose only the binary swap as an
opt-in extension (free function or constrained static), and forgo
permutation in general.

### Q1.5 Append / Prepend (Pack Composition)

**Categorical**: the cartesian product is the right adjoint of the
diagonal; n-ary products compose via append/prepend. There is no formal
categorical name for the operation `Product<A, B> + C → Product<A, B, C>`,
but it is a standard parameter-pack manipulation.

**Swift 6.3.1**: Both append and prepend work directly
(`test17.swift`, *Verified: 2026-05-08*):

```swift
extension Product {
    @inlinable
    public func append<T>(_ value: T) -> Product<repeat each Element, T> {
        Product<repeat each Element, T>(repeat each values, value)
    }
    @inlinable
    public func prepend<T>(_ value: T) -> Product<T, repeat each Element> {
        Product<T, repeat each Element>(value, repeat each values)
    }
}
// Verified by example:
//   Product(1, "hi").append(true)  → Product<Int, String, Bool>
//   Product(1, "hi").prepend(0.5)  → Product<Double, Int, String>
```

This is unique to n-ary products — Either / Pair cannot grow this way, but
Product can. Worth shipping.

### Q1.6 Zip

**Categorical**: zip is the natural transformation `Product<A, B> ×
Product<C, D> → Product<(A,C), (B,D)>`. It demonstrates that products are
"applicative" in their own right.

**Swift 6.3.1**: Works via pack iteration (`test18.swift`,
*Verified: 2026-05-08*):

```swift
extension Product {
    @inlinable
    public func zip<each Other>(
        _ other: Product<repeat each Other>
    ) -> Product<repeat (each Element, each Other)> {
        Product<repeat (each Element, each Other)>(
            repeat (each values, each other.values)
        )
    }
}
// Product(1, "hi").zip(Product(true, 0.5))  →  Product<(Int, Bool), (String, Double)>
```

The shape requirement (same arity) is enforced by the compiler — mismatched
packs produce a "shape" error.

### Q1.7 Fold / Reduce

**Categorical**: a fold collapses a product into a single value via a
function `(T₁ × T₂ × … × Tₙ) → R`. For binary, this is the pair
catamorphism; for n-ary, it is just function uncurrying.

**Swift 6.3.1**: An n-ary reduce that takes one closure of n arguments is
expressible only via a tuple-shaped closure parameter:
```swift
extension Product {
    public func fold<R, E: Swift.Error>(
        _ body: (repeat each Element) throws(E) -> R
    ) throws(E) -> R {
        try body(repeat each values)
    }
}
```
This compiles. The call site reads `product.fold { (a, b, c) in … }`.
Practical and clean.

### Q1.8 Diagonal

**Categorical**: `Δ: A → A × A × … × A` (n copies of the same value).

**Swift 6.3.1**: Requires same-type pack constraint. As of 6.3.1,
`extension Product where repeat each Element == T` is **not** an
expressible constraint. The feature is filed under
[Same Element Requirements](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md)
(SE-0398) which landed in Swift 5.9, but I could not get it to constrain a
pack to all-same-element in 6.3.1. Skipping diagonal as out-of-scope.

### Q1.9 Currying / Uncurrying

**Categorical**: `(A × B → C) ↔ (A → B → C)` — products and exponentials
compose via the Curry-Howard / closure-as-argument duality.

**Swift 6.3.1**: Pack-typed closures permit
`(repeat each Element) -> R ↔ (T₁) -> (T₂) -> … -> (Tₙ) -> R` only if all
arity steps are declared individually — there is no general n-ary curry
without recursion on the type level. Out-of-scope for v1.

### Q1.10 Apply / Pure (Applicative)

**Categorical**: `pure: A → F<A>` and `apply: F<A → B> → F<A> → F<B>`. For
products, "apply" needs functions paired with values element-wise. With
parameter packs:
```swift
public func apply<each U, E: Swift.Error>(
    _ functions: Product<repeat (each Element) throws(E) -> each U>
) throws(E) -> Product<repeat each U>
```

**Swift 6.3.1**: Expressible (similar shape to total `map` above), but
adoption demand is unclear. Would be worth shipping at version 0.2; not
v0.1.

### Operation Inventory Summary

| Op | n=2 | n=3 | n≥3 general | Swift 6.3.1 expressibility |
|----|-----|-----|-------------|---------------------------|
| Projection (πᵢ) | YES | YES | YES | Already shipped (`@dynamicMemberLookup`). |
| Per-position map | NO instance | NO instance | NO instance | Free-function only. |
| Total n-functor map | YES | YES | YES | Pack of closures. |
| Swap | YES (free func) | NO | NO (intractable) | Binary only, free function. |
| Append / prepend | YES | YES | YES | Pack expansion. |
| Zip | YES | YES | YES | Pack iteration over both. |
| Fold | YES | YES | YES | Tuple-shaped closure. |
| Diagonal | NO | NO | NO | Same-element requirement gap. |
| Curry / Uncurry | NO general | NO general | NO general | Type-level recursion needed. |
| Apply | YES | YES | YES | Pack of closure-typed elements (pack-of-functions). |

The headline finding is the **per-position-map gap**. The single most-asked
operation (transform one component, leave the rest) is the only one that
**cannot be expressed as an instance method** on `Product<each Element>`.
Every other categorically-meaningful operation either ships already (πᵢ),
generalizes via packs (total map, append, prepend, zip, fold, apply), or is
honestly out-of-reach for n-ary today (diagonal, swap≥3, general curry).

---

## Q2. Candidate API Shapes

### Shape A — Either-Style Compound Names (`mapFirst`, `mapSecond`, `bimap`, `trimap`, …)

The current Either-primitives shape (lines 41–134 of
`Either.swift`, *Verified: 2026-05-08*) for n=2: separate static + instance
methods named `mapLeft`, `mapRight`, `bimap`. For Product, the n-ary
generalization is `mapFirst`, `mapSecond`, …, `mapNth`, plus all subsets
(`bimap = mapFirstSecond`, `trimap = mapFirstSecondThird`, …).

**Compliance**: violates [API-NAME-002] outright at the public API.
Deprecated by the Either v1.0.0 RECOMMENDATION already.

**Arity reach**: combinatorial blow-up for n ≥ 3 — `n choose k` named
methods for selecting `k` positions to transform. Catastrophic.

**Verdict**: rejected for the same reasons Either rejected it. Documented
as the baseline only. **Not a contender.**

### Shape B — Labeled-Method Overloads (`map(first:)`, `map(first:second:)`, …)

The Either v1.0.0 RECOMMENDATION's recommended shape, generalized to n-ary.

**Compliance**: complies with [API-NAME-002] (verb is single-word `map`;
labels disambiguate). [API-NAME-008] classifies this as "single-form" —
one verb, parameter-disambiguated.

**Swift 6.3.1 expressibility**: **Blocked for instance methods.** As
demonstrated in Q1.2, `extension Product<First, Second>` is rejected, so
`func map(first:)` cannot be written as an instance method on Product.
Only free-function form works:

```swift
public func map<First, Second, NewFirst, E: Swift.Error>(
    _ p: Product<First, Second>,
    first transform: (First) throws(E) -> NewFirst
) throws(E) -> Product<NewFirst, Second> { … }

// Call site:
let q = try map(p, first: { $0 + 1 })
```

The free-function shape works and looks reasonable in some languages, but
in Swift it sacrifices method-call ergonomics: no chaining, no
`@dynamicMemberLookup`-style paths through it, no `.` discoverability.

**Combinatorial scaling**: still `n choose k` — for n=2 the overload set is
{first; second; first+second} = 3; for n=3 it is {first; second; third;
first+second; first+third; second+third; first+second+third} = 7; for n=4
it is 15. Each overload is its own free function. Doable for small n;
unmanageable for n ≥ 5.

**Arity reach**: works for fixed n, free-function form only. **Cannot be a
universal n-ary shape on Product instance methods.**

**Verdict**: usable for n=2 and n=3 as **free functions**, with the
understanding that callers write `map(p, first: …)` rather than
`p.map(first: …)`. The instance form is blocked.

### Shape C — Property.View Nested Namespace (`product.map.first { }`)

The user's first illustrative example. Property.View is the multi-form
choice per [API-NAME-008].

**Compliance**: complies with [API-NAME-002] (`.map` is the verb-as-property
namespace; `.first` is the operation-name within it).

**Swift 6.3.1 expressibility**: Three layers must compose successfully —
verified empirically (*Verified: 2026-05-08*):

* **`enum` declared in `extension Product { … }` is rejected** — `error:
  enums cannot declare a type pack` (`test1.swift`). Workarounds:
  a) declare the tag at module scope (`public enum ProductMap {}`), or
  b) declare the tag as a nested `struct` (`extension Product { public
     struct Map_Tag {} }` works — `test3.swift`, `test5.swift`).

* **`typealias Property<Tag>` on Product works** (`test2.swift`,
  *Verified: 2026-05-08*):
  ```swift
  extension Product {
      public typealias Property<Tag> =
          Property_Primitives.Property<Tag, Product<repeat each Element>>
  }
  ```

* **Method extensions on `Property` where the method declares its OWN pack
  parameter and binds via `where Base == Product<repeat each E2>`** compile
  and run correctly (`test15b.swift`, *Verified: 2026-05-08*):
  ```swift
  extension Property where Tag == ProductMap {
      @inlinable
      public func callAsFunction<each E2, each NewElement, Err: Error>(
          _ transforms: repeat (each E2) throws(Err) -> each NewElement
      ) throws(Err) -> Product<repeat each NewElement>
      where Base == Product<repeat each E2> {
          Product<repeat each NewElement>(
              repeat try (each transforms)(each base.values)
          )
      }
  }
  ```

* **The naive shape — `extension Property where Tag == ProductMap` and
  using `each Element` directly** — does NOT compile:
  `error: cannot find type 'Element' in scope` (`test15.swift`,
  *Verified: 2026-05-08*). The extension does not bring Product's pack
  into scope, even with a `where Base == Product<repeat each Element>`
  clause. The method must declare its own `each E2` and rebind.

This is a **structural ceremony cost** that does not afflict Either or any
binary primitive. The labeled-overload-on-Property pattern adds an extra
generic parameter pack `each E2` *per method*.

**Per-position support**: Property.View can host `.first` / `.second` / etc.,
but each requires the same concrete-arity blocker. `.first` (the per-position
projection) and `.second` need to constrain the pack to "at least n
elements", which Swift 6.3.1 does not directly support. The most natural
fits are:

* `.all` — multi-arg total map (works via pack of closures);
* `.map { (a, b, c) in … }` — total uncurry/fold-map;
* per-position projections `.first` / `.second` — only if implemented as
  *free functions* taking a Property value, which defeats the namespace.

Net: Property.View yields a usable namespace for **total maps** but does
NOT solve the per-position-map gap any more than Shape B does. The blocker
is the same: concrete-arity.

**Discoverability**: After typing `product.map`, autocomplete shows the
property; the user must dot again to see `.all`, `.first` (if it exists),
etc. Two-step disclosure.

**`~Copyable` extensibility**: Property.View *is* the
`~Copyable`-ready shape. The blocker is that **Product itself cannot be
`~Copyable` today** because `each Element: ~Copyable` is rejected
(`test16.swift`, *Verified: 2026-05-08*). When SE-NNNN (TBD) lifts that
restriction, the Property.View pattern would extend cleanly. So the
"forward-compatibility win" of Property.View is conditional on a language
change neither shipped nor scheduled.

**Verdict**: usable for total transforms, scales gracefully via pack of
closures, but adds extra-pack-parameter ceremony per method, requires a
top-level (or struct-rather-than-enum) tag, and does not address the
per-position-map gap any better than Shape B. **Available but heavy.**

### Shape D — Key-Path-Driven (`product.modifying(\.0) { … }`)

Leverage the `@dynamicMemberLookup` precedent already in Product.

**Compliance**: complies with [API-NAME-002].

**Swift 6.3.1 expressibility**: A `func modifying<T>(_ keyPath: WritableKeyPath<…, T>, transform: (T) -> T) -> Self` shape needs the keypath to address into a *pack-typed tuple*, which works for read-only `KeyPath` (already used) but does NOT work for `WritableKeyPath` returning a new `Product` with a *different* type at that position. The keypath cannot change types.

**Verdict**: too limited to be the primary shape — keypaths preserve type. Useful for *in-place* modifications when the type is preserved (e.g., `product.modifying(\.0) { $0 + 1 }` for `Product<Int, …>`), but cannot express the type-changing per-position map. **Niche supplement, not primary shape.**

### Shape E — Free-Function Operators (`Product.map(at: 0, of: product) { … }`)

A static-only API on Product or a sibling namespace.

**Compliance**: complies. Mirrors `swift-collection-primitives`-style static APIs.

**Swift 6.3.1 expressibility**: Per-position via runtime `at:` parameter is type-unsafe (the closure must be type-erased). Per-position via `KeyPath` is the same story as Shape D. Per-position via overload (`Product.map<First, Second>(_ p:, first: …)`) is just Shape B's free-function form rebranded.

**Verdict**: equivalent to Shape B's free-function form. **Subsumed.**

### Shape F — Hybrid (Property.View + Labeled Overloads)

Both `product.map.all { … }` and `product.map(transforms…)` available simultaneously.

**Compliance**: passes [API-NAME-002] but conflicts with [API-NAME-008]'s "MUST use one or the other".

**Verdict**: has the same flaws Either's Option C did — two ways to do the same thing, two layers of API to maintain, confused autocomplete. **Rejected.**

### Shape G — Pack-Iterating Closure (`product.mapEach { … }`)

A single closure applied to every component. Requires either:
* a same-type constraint on the pack (`each Element == T`) — which is **not yet supported** in Swift 6.3.1, OR
* a polymorphic closure type (`<T> (T) -> T`) — which Swift does not have either.

**Verdict**: **blocked at the language level**. Not available today.

---

### Comparison Table

| Criterion | A: Compound names | B: Labeled overloads (free fn) | C: Property.View | D: Key-path | E: Free fn | F: Hybrid | G: Pack-iterating |
|-----------|-------------------|-------------------------------|------------------|-------------|------------|-----------|-------------------|
| [API-NAME-002] compliance | NO | YES | YES | YES | YES | YES (in pieces) | YES |
| [API-NAME-008] decision-rule fit | N/A (rejected) | Single-form labeled method | Multi-form Property.View | Single-form labeled method | Same as B | Mixed (rule violation) | Single-form |
| Per-position map (n=2 instance method) | Blocked | Blocked | Blocked | Limited (no type change) | Blocked | Blocked | Blocked |
| Per-position map (n=2 free function) | n/a | Works | Works (via Property + free fn) | n/a | Works | Works | Blocked |
| Total n-ary map | n/a | Works (pack of closures) | Works (callAsFunction with pack) | Limited | Works | Works | Blocked (same-type only) |
| [API-ERR-001] typed-throws | n/a | Clean | Clean (with extra ceremony) | Clean | Clean | Mixed | n/a |
| Variadic arity reach | Combinatorial blow-up | Combinatorial blow-up (free fn) | Total form scales; per-position blocked | Limited | Combinatorial | Mixed | Blocked |
| `~Copyable` Product extensibility | n/a | Conditional on lang. | Conditional on lang. | n/a | Conditional | Conditional | Conditional |
| Tag enum compiles? | n/a | n/a | NO (use struct or top-level) | n/a | n/a | n/a | n/a |
| Discoverability (autocomplete) | n/a | One-step (`map(`) | Two-step (`.map.`) | One-step | One-step | Two-paths | n/a |
| New transitive dep (`swift-property-primitives`) | No | No | YES | No | No | YES | No |
| Single-inhabitant namespace risk ([API-NAME-001a]) | n/a | n/a | High (`Product.Map` solo) | n/a | n/a | n/a | n/a |
| Migration cost from current state | n/a | Small | Medium | Small | Small | Large | n/a |
| Sibling-package consistency (Either v1.0.0) | n/a | High | Low | n/a | High | Low | n/a |

---

## Q3. Property-Primitives Integration

`Property` ships in five variants per [PRP-001]. Per-variant fit for
`Product<each Element>`:

### `Property<Tag, Base>` — method-case for Copyable

Product is `Copyable` (since `each Element` is forced to `Copyable` in
6.3.1). This variant fits structurally. The mechanism is the one verified
in `test15b.swift` above: declare a top-level (or nested-struct) tag, add a
`typealias Property<Tag>` on Product, and put method extensions on
`Property` carrying their own `each E2` pack.

**Cost**: extra ceremony per method (rebinding the pack). Per-method
boilerplate is two lines (the where-clause + the `each E2` declaration).

**Verdict**: usable, but adds ceremony with no offsetting payoff.

### `Property<Tag, Base>.Typed<Element>` — property-case for Copyable

Property.Typed exists to bring `Element` into scope so `var` properties can
return `Element?` etc. Product has multiple element types — `each Element`
— so a single `Element` type parameter does not fit. **Not applicable** to
the n-ary case.

If we restricted to a constrained subview (e.g., `where each Element ==
Same`), `Property.Typed<Same>` would work, but that subview is the same
language gap that blocks Shape G — same-type-pack-requirement support.

**Verdict**: not applicable today.

### `Property<Tag, Base>.Consuming<Element>` — borrow + consume

Only fits when Product itself is consumed. Useful for an operation like
`.fold.consuming { … }` (consume the product to produce a value), but the
single-element parameter does not match Product's multi-element nature.

**Verdict**: marginally fits for fold-style consumption; same single-Element
limitation as `Property.Typed`.

### `Property<Tag, Base>.View` and `.View.Read` — for `~Copyable`

Only relevant if Product becomes `~Copyable`. **Blocked**:
`each Element: ~Copyable` is rejected by Swift 6.3.1 (`test16.swift`,
*Verified: 2026-05-08*). Until that lifts, these variants do not apply.

### Phantom-Tag Survival Under Parameter Packs

The hard question. Concretely, can a Property.View operation be parameterized
on `Tag == Product<repeat each Element>.SomeMap`?

* **Tag declaration**: `enum SomeMap {}` inside `extension Product {}`
  fails (`test1.swift`, *Verified: 2026-05-08*). `struct SomeMap {}` inside
  `extension Product {}` works (`test3.swift`, *Verified: 2026-05-08*).
  Workaround: use struct-as-tag, or top-level enum.

* **Property typealias**: works fine with `repeat each Element` in the
  Base argument (`test2.swift`).

* **Method extension on `Property` where `Tag == Product<repeat each Element>.SomeMap`**: the where-clause itself binds, but **the method body cannot
  access `each Element`** — the extension does not bring Product's pack
  into scope (`test15.swift`).

* **Workaround — declare a fresh pack at the method level**: works
  (`test15b.swift`).

This means the Property.View pattern is **technically expressible** for
Product, but adds a distinctive ceremony at every method extension point:
each method must redeclare its own pack and bind it via the where-clause.
That ceremony is not present for binary primitives like Either, Pair,
Result.

The ceremony is a **structural cost** that should be weighed against the
gain. The gain is: a multi-form namespace (`product.map.{all, fold, …}`).
The cost is: each method extension carries `each E2, each NewElement` plus
`where Base == Product<repeat each E2>`. The cost compounds across every
method.

---

## Q4. Codable / Comparable / Additional Conformances

### Q4.1 Codable — verify the current comment

`Product.swift:72-73` (*Verified: 2026-05-08*) carries the comment:
> `Note: Codable conformance for parameter packs requires more complex handling and may not be directly expressible in current Swift.`

This is **stale** as of Swift 6.3.1. Empirical verification
(`test20.swift`, `test22.swift`, *Verified: 2026-05-08*):

```swift
extension Product: Encodable where repeat each Element: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in repeat each values {
            try container.encode(value)
        }
    }
}

extension Product: Decodable where repeat each Element: Decodable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init(repeat try container.decode((each Element).self))
    }
}
```

Both compile **and run correctly** (`test22.swift` round-trips
`Product(1, "hi", true)` through JSON without loss):
```text
[1,"hi",true]
(1, "hi", true)
```

The comment should be removed and Codable conformances added under
`#if !hasFeature(Embedded)` mirroring Either's pattern at `Either.swift:36-38`.

### Q4.2 Comparable

Lexicographic comparison via pack iteration with short-circuit
(`test12.swift`, *Verified: 2026-05-08*) compiles and runs correctly:

```swift
extension Product: Comparable where repeat each Element: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        for cmp in repeat compare(each lhs.values, each rhs.values) {
            switch cmp {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: continue
            }
        }
        return false
    }
}
```

Worth shipping. Same logic Either could use (Either's Comparable is
deferred per its v1.0.0).

### Q4.3 CustomStringConvertible

Pack iteration over `.description` (`test11.swift`,
*Verified: 2026-05-08*) compiles and produces `(1, hi, true)` for
`Product(1, "hi", true)`. Worth shipping.

### Q4.4 ExpressibleByArrayLiteral

Requires same-type constraint on the pack. Blocked by the same
`each Element == T` gap. Out-of-scope for v0.1.

### Q4.5 Collection-Shaped Iteration

Requires same-type constraint. Same blocker.

### Q4.6 ExpressibleByTupleLiteral

[SE-0469](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0469-tuple-literal-typealias.md)
is for tuple-literal typealias, not for arbitrary tuple-literal-from-type.
There is no language facility today to make `let p: Product<Int, String> = (1, "hi")` compile. Out-of-scope.

### Q4.7 Identifiable

Not applicable — Product has no canonical id.

### Conformance Recommendation Summary

Add to v0.1: `Encodable`, `Decodable`, `Comparable`, `CustomStringConvertible`,
`CustomDebugStringConvertible` (to mirror tuple-debug behaviour). Remove the
stale `Codable` comment. Defer `ExpressibleByArrayLiteral`, `Collection`,
`ExpressibleByTupleLiteral`, `Identifiable` until language gaps lift or
demand surfaces.

---

## Q5. Recommendation

### Recommendation Header

**Status**: RECOMMENDATION
**Decision axis**: structural correctness ([RES-022]) over diff-size.
**Mirror to**: `swift-pair-primitives` (binary case) at the next migration
wave; harmonize with `swift-either-primitives/Research/api-design-property-leverage.md` v1.0.0.
**Implementable in**: Swift 6.3.1 today. No nightly-only features required.

### Recommended Shape: B + (light) C — Labeled Free Functions for Per-Position; Pack-Native Total Maps as Instance Methods

The recommendation is a **two-tier design** that respects the asymmetry
between "per-position" and "total" operations. Per-position operations are
fundamentally concrete-arity in Swift today and must live as **free
functions with labeled arguments**; total operations are pack-native and
should live as **instance methods using pack-of-closures**.

### Why Not a Single Shape?

The Either v1.0.0 RECOMMENDATION reaches a clean single-shape solution
(labeled overloads, all instance) because Either is binary — `extension
Either<First, Second>` is implicitly the only arity. Product is variadic.
The pack-vs-concrete-arity gap means **no single shape covers both
per-position and total operations as instance methods**.

The honest design — per [IMPL-001] (principled absences) — is to:

1. Ship the **total-map instance method** (pack-native, scales to all n).
2. Ship the **per-position labeled overloads** as free functions for
   `n=2` and `n=3` (no obvious demand for higher).
3. Keep the static layer minimal (compound names permitted per
   [IMPL-024], but not required — using the same labeled shape at both
   layers eliminates dual vocabulary).
4. **Skip Shape C (Property.View)** — the per-method ceremony does not pay
   rent. The Either decision applies symmetrically: tagged scalars/products
   are not CoW containers, the Property machinery exists for shared-storage
   types and `~Copyable` resources, and Product is neither.

**Why this resolves the user's two illustrative shapes**:

* User's example "(a) `.map.left` over `.mapLeft`" — per-position is a
  Property.View namespace shape: rejected for the per-method ceremony cost
  (every method redeclares the pack), the absence of `~Copyable` Product
  benefit (blocked), and the single-inhabitant-namespace risk
  ([API-NAME-001a]).
* User's example "(b) `.map(left:)` and `.map(left:right:)` over `bimap`"
  — per-position is a labeled instance method: rejected as an *instance*
  shape because `extension Product<First, Second>` is not yet supported.
  Accepted as a **free-function** shape — `map(p, first: …)`,
  `map(p, second: …)`, `map(p, first: …, second: …)` — for `n=2` and
  `n=3`. The total form `p.map(transforms…)` provides the n-ary instance
  method in addition.

### Concrete Implementation Sketch

The sketch below is the **complete v0.1 public surface**. It is
plug-compatible with the existing `Product.swift:25-73` and adds the
operations validated empirically above. One file per type as required by
[API-IMPL-005].

```swift
// File: Sources/Product Primitives/Product.swift
// Type body — minimal per [API-IMPL-008]; only stored field + canonical init.

@dynamicMemberLookup
public struct Product<each Element> {
    /// Tuple of component values.
    public var values: (repeat each Element)

    /// Creates a product from component values.
    @inlinable
    public init(_ values: repeat each Element) {
        self.values = (repeat each values)
    }

    /// Direct access to tuple elements via key paths.
    ///
    /// Enables `product.0` instead of `product.values.0`.
    @inlinable
    public subscript<T>(dynamicMember keyPath: KeyPath<(repeat each Element), T>) -> T {
        values[keyPath: keyPath]
    }
}
```

```swift
// File: Sources/Product Primitives/Product+Conformances.swift
// All conditional conformances per [COPY-FIX-004] (same file as type, since
// Product is Copyable and there is no module-boundary issue, this could split
// per [API-IMPL-007]; chose +Conformances suffix to keep them grouped).

extension Product: Sendable where repeat each Element: Sendable {}

extension Product: Equatable where repeat each Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        func eq<T: Equatable>(_ a: T, _ b: T) -> Bool { a == b }
        for r in repeat eq(each lhs.values, each rhs.values) {
            if !r { return false }
        }
        return true
    }
}

extension Product: Hashable where repeat each Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        func combine<T: Hashable>(_ x: T, into hasher: inout Hasher) {
            hasher.combine(x)
        }
        repeat combine(each values, into: &hasher)
    }
}

extension Product: Comparable where repeat each Element: Comparable {
    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        // Lexicographic. Short-circuit on the first non-equal pair.
        // Helper lifts the per-element comparison into a side-effecting call
        // so we can unroll and break inside the for-loop body.
        func cmp<T: Comparable>(_ a: T, _ b: T) -> _Order {
            if a < b { return .ascending }
            if a > b { return .descending }
            return .same
        }
        for order in repeat cmp(each lhs.values, each rhs.values) {
            switch order {
            case .ascending:  return true
            case .descending: return false
            case .same:       continue
            }
        }
        return false
    }
}

@usableFromInline
internal enum _Order { case ascending, descending, same }

extension Product: CustomStringConvertible
where repeat each Element: CustomStringConvertible {
    @inlinable
    public var description: String {
        var parts: [String] = []
        for desc in repeat (each values).description {
            parts.append(desc)
        }
        return "(\(parts.joined(separator: ", ")))"
    }
}

extension Product: Swift.Error where repeat each Element: Swift.Error {}

#if !hasFeature(Embedded)
extension Product: Encodable where repeat each Element: Encodable {
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in repeat each values {
            try container.encode(value)
        }
    }
}

extension Product: Decodable where repeat each Element: Decodable {
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init(repeat try container.decode((each Element).self))
    }
}
#endif
```

```swift
// File: Sources/Product Primitives/Product+Map.swift
// Total n-ary map — instance method. Pack-native; works for all arities.

extension Product {
    /// Transforms every component, producing a new Product with the
    /// per-position result types.
    ///
    /// ```swift
    /// let triple = Product(1, "hi", true)
    /// let transformed = try triple.map(
    ///     { $0 + 1 },
    ///     { $0.uppercased() },
    ///     { !$0 }
    /// )
    /// // Product<Int, String, Bool> = (2, "HI", false)
    /// ```
    @inlinable
    public func map<each NewElement, E: Swift.Error>(
        _ transforms: repeat (each Element) throws(E) -> each NewElement
    ) throws(E) -> Product<repeat each NewElement> {
        Product<repeat each NewElement>(
            repeat try (each transforms)(each values)
        )
    }
}
```

```swift
// File: Sources/Product Primitives/Product+Map+Binary.swift
// Per-position map for n=2. Free functions because
// `extension Product<First, Second>` is rejected by Swift 6.3.1.

/// Transforms the first component of a binary Product while preserving the second.
@inlinable
public func map<First, Second, NewFirst, E: Swift.Error>(
    _ p: Product<First, Second>,
    first transform: (First) throws(E) -> NewFirst
) throws(E) -> Product<NewFirst, Second> {
    Product(try transform(p.values.0), p.values.1)
}

/// Transforms the second component of a binary Product while preserving the first.
@inlinable
public func map<First, Second, NewSecond, E: Swift.Error>(
    _ p: Product<First, Second>,
    second transform: (Second) throws(E) -> NewSecond
) throws(E) -> Product<First, NewSecond> {
    Product(p.values.0, try transform(p.values.1))
}

/// Transforms both components of a binary Product (a.k.a. bimap).
@inlinable
public func map<First, Second, NewFirst, NewSecond, E: Swift.Error>(
    _ p: Product<First, Second>,
    first  ft: (First)  throws(E) -> NewFirst,
    second st: (Second) throws(E) -> NewSecond
) throws(E) -> Product<NewFirst, NewSecond> {
    Product(try ft(p.values.0), try st(p.values.1))
}
```

```swift
// File: Sources/Product Primitives/Product+Map+Ternary.swift
// Per-position map for n=3. Same shape, three positions. Combinatorial
// blow-up means we cap at n=3 unless explicit demand surfaces.

@inlinable
public func map<First, Second, Third, NewFirst, E: Swift.Error>(
    _ p: Product<First, Second, Third>,
    first transform: (First) throws(E) -> NewFirst
) throws(E) -> Product<NewFirst, Second, Third> {
    Product(try transform(p.values.0), p.values.1, p.values.2)
}

@inlinable
public func map<First, Second, Third, NewSecond, E: Swift.Error>(
    _ p: Product<First, Second, Third>,
    second transform: (Second) throws(E) -> NewSecond
) throws(E) -> Product<First, NewSecond, Third> {
    Product(p.values.0, try transform(p.values.1), p.values.2)
}

@inlinable
public func map<First, Second, Third, NewThird, E: Swift.Error>(
    _ p: Product<First, Second, Third>,
    third transform: (Third) throws(E) -> NewThird
) throws(E) -> Product<First, Second, NewThird> {
    Product(p.values.0, p.values.1, try transform(p.values.2))
}

// Combinations (first+second, first+third, second+third, first+second+third)
// follow the same pattern — seven total overloads for n=3 (2³−1 = 7
// non-empty subsets).

// All seven overloads written out — omitted here for brevity but each
// follows the same shape. Cap at n=3; users who need n≥4 per-position
// transforms call .map(transforms…) on the n-ary instance form with
// identity closures for unchanged positions, accepting the verbosity.
```

```swift
// File: Sources/Product Primitives/Product+Append.swift
// Pack composition — append/prepend a single component.

extension Product {
    /// Returns a new Product with `value` appended as the last component.
    ///
    /// ```swift
    /// let pair = Product(1, "hi")
    /// let triple = pair.append(true)   // Product<Int, String, Bool>
    /// ```
    @inlinable
    public func append<T>(_ value: T) -> Product<repeat each Element, T> {
        Product<repeat each Element, T>(repeat each values, value)
    }

    /// Returns a new Product with `value` prepended as the first component.
    ///
    /// ```swift
    /// let pair = Product(1, "hi")
    /// let triple = pair.prepend(0.5)   // Product<Double, Int, String>
    /// ```
    @inlinable
    public func prepend<T>(_ value: T) -> Product<T, repeat each Element> {
        Product<T, repeat each Element>(value, repeat each values)
    }
}
```

```swift
// File: Sources/Product Primitives/Product+Zip.swift
// Element-wise pairing of two same-arity Products.

extension Product {
    /// Returns a Product whose i-th component is the tuple `(self.i, other.i)`.
    /// Both Products must have the same arity.
    ///
    /// ```swift
    /// let a = Product(1, "hi")
    /// let b = Product(true, 0.5)
    /// let z = a.zip(b)   // Product<(Int, Bool), (String, Double)>
    /// ```
    @inlinable
    public func zip<each Other>(
        _ other: Product<repeat each Other>
    ) -> Product<repeat (each Element, each Other)> {
        Product<repeat (each Element, each Other)>(
            repeat (each values, each other.values)
        )
    }
}
```

```swift
// File: Sources/Product Primitives/Product+Fold.swift
// Total catamorphism — collapse all components into a single value.

extension Product {
    /// Eliminates the Product by handling all components in a single closure.
    ///
    /// ```swift
    /// let triple = Product(1, "hi", true)
    /// let s = triple.fold { (a, b, c) in "\(a) \(b) \(c)" }
    /// // "1 hi true"
    /// ```
    @inlinable
    public func fold<R, E: Swift.Error>(
        _ body: (repeat each Element) throws(E) -> R
    ) throws(E) -> R {
        try body(repeat each values)
    }
}
```

```swift
// File: Sources/Product Primitives/Product+Swap.swift
// Binary commutativity. Free function only because n=2 is concrete-arity.

/// Returns a binary Product with components swapped.
@inlinable
public func swapped<First, Second>(
    _ p: Product<First, Second>
) -> Product<Second, First> {
    Product(p.values.1, p.values.0)
}
```

### What This Does NOT Add

* **No `Property.View` namespace** for `.map.first` / `.map.all` etc. The
  pack-rebinding ceremony per method, combined with the
  single-inhabitant-namespace risk and the `~Copyable` Product blocker,
  outweighs the call-site readability gain.
* **No diagonal**, **no curry/uncurry**, **no apply** for v0.1 — language
  gaps and absent demand. The fold instance method covers
  uncurried-application use cases.
* **No per-position map for n ≥ 4** as named overloads. Users with `n ≥ 4`
  typed positions can chain `.map(transforms…)` with identity closures for
  unchanged positions; if frequent demand surfaces, the binary/ternary
  overload sets can be generalized.
* **No Property.View `.fold.consuming { }`** — Product is `Copyable` today;
  the consuming variant adds nothing.

### Decisions Catalogue (mirroring Either's structure)

| # | Question | Resolution |
|---|----------|------------|
| 1 | Property.View namespace shape (`.map.first { }`, `.map.all { }`)? | **Rejected.** Pack-rebinding ceremony per method (each extension declares its own `each E2` and `where Base == Product<repeat each E2>`); single-inhabitant-namespace risk ([API-NAME-001a]); `~Copyable` Product is blocked by the language; no CoW machinery to amortize. |
| 2 | Labeled-method shape — instance? | **Blocked.** `extension Product<First, Second>` rejected by Swift 6.3.1 (verified empirically). |
| 3 | Labeled-method shape — free function? | **Adopted for n=2 and n=3.** Argument-label autocomplete is one-step (`map(p,` reveals all overloads). Capped at n=3 to control combinatorial blow-up; consumers needing `n ≥ 4` use the n-ary instance map. |
| 4 | Total n-ary map — instance method? | **Adopted as the primary multi-arity functor surface.** Pack of closures, scales to all n. Verified empirically. |
| 5 | Hybrid (Property.View + labeled)? | **Rejected** for the same reasons Either rejected its hybrid: two ways to do the same thing, no clear win, doc burden. |
| 6 | Codable comment in `Product.swift:72-73`? | **Stale; remove.** Empirically verified (`test22.swift`) that both `Encodable` and `Decodable` work via pack iteration. Add under `#if !hasFeature(Embedded)` mirroring Either. |
| 7 | Comparable / CustomStringConvertible? | **Add.** Both work via pack iteration (verified). |
| 8 | Static-dispatch layer? | **Same labeled shape at both layers.** Mirrors Either's resolution: compound static names are PERMITTED per [IMPL-024] but not REQUIRED; using the same labeled shape avoids dual vocabulary. |
| 9 | Sibling Pair / Either evolution? | See "Recommendation: Sibling Package Evolution". Pair (`swift-pair-primitives`) should mirror this shape. Either v1.0.0 already aligns; the only delta is generalizing to "labeled overloads" as the cross-package convention with Pair and Product joining the family. |
| 10 | Append / prepend / zip / fold / swap? | **All add.** Append/prepend/zip/fold are pack-native instance methods. Swap is binary-only via free function. |

---

### Empirical Validation: Cognitive Dimensions Framework

[RES-025] applies the Cognitive Dimensions Framework to API-facing
decisions. For the recommended shape:

| Dimension | Reading | Notes |
|-----------|---------|-------|
| **Visibility** | Total `.map(transforms…)` is one-step (`product.map(`). Per-position `map(p, first:)` is one-step at the free-function call site (`map(` reveals all overloads). | Both forms have one-step disclosure. Property.View would have been two-step. |
| **Consistency** | One verb `map` for all transformations. Labels disambiguate position. | Pair migration plan applies the same shape — `pair.map(first:)` etc. as free functions. Either v1.0.0 instance form is equivalent for binary. |
| **Viscosity** (resistance to change) | Adding a new arity (e.g., `n=4` per-position overloads) is mechanical. Migrating call sites if the shape changes is moderate cost. | No worse than Either's labeled-overload shape. |
| **Role expressiveness** | `map(first:)` reads as intent (apply to first); `.map(transforms…)` reads as intent (apply per position). | Argument labels carry the role per [API-IMPL-013]. |
| **Error proneness** | Typed throws preserved through every overload via `throws(E)`. The free-function form risks call-site confusion (is `map` part of Swift's stdlib `map`?) — namespace pollution. Consumers `import Product_Primitives` and the free `map` overloads are public; this can shadow other `map`s in scope. | **Real concern**: namespace-pollution from a free `map` function. Mitigation in "Open Questions" below. |
| **Abstraction** | Total `.map` and per-position `map` share a verb. The relationship is parameterization (one verb, position labels). | Matches the Either v1.0.0 reading. |

The single empirical concern is **error-proneness from free-function `map`
overloads**. Three mitigations exist:

1. **Wrap the free functions in a static-namespace enum**, e.g.,
   `Product.map(_, first: …)` instead of bare `map(_, first: …)`. Adds two
   characters per call site and eliminates the namespace-pollution risk.
   [IMPL-001] frame: the verb `map` is precious; declaring it free-floating
   is principled-absence-violating.

2. **Move the free functions into an extension on the *static-method
   surface* of Product**, e.g., `Product.map<First, Second, NewFirst>(...)`.
   Then call site reads `Product.map(p, first: …)`. Per the
   pack-vs-concrete-arity gap, this *static* form on Product is also
   blocked (`test9.swift` showed `static func` with concrete-pack
   constraint fails the same way). So static-on-`Product` is **also
   blocked**.

3. **Move the free functions into an extension on a sibling type** —
   Product*Helpers or Product*Operations namespace enum — so the call site
   reads `Product.Operations.map(p, first: …)`. Verbose but unambiguous.

The recommendation as written uses the bare free function. Mitigation
chosen: **document the namespace-pollution risk explicitly in DocC**, ship
the bare form (matching ecosystem precedent for free Swift functions — `min`,
`max`, `swap`, `zip` are all in the stdlib at module scope), and revisit
if a consumer reports collision. If collision arises, retreat to a sibling
namespace per option 3 above.

---

### Recommendation: Sibling Package Evolution

The shape recommended here is a **superset** of the Either v1.0.0 RECOMMENDATION.
Specifically:

* Either's v1.0.0 shape is **labeled-overload-on-instance** (allowed
  because Either is binary). Translating to "labeled-overload-on-free-function"
  for n-ary is structurally analogous — the same `map(left:)` /
  `map(left:right:)` semantics, expressed where the language permits the
  instance form (Either) and where it does not (Product n-ary).

* Pair (`swift-pair-primitives`) currently ships
  `mapFirst` / `mapSecond` / `bimap`. It should migrate to
  **labeled instance methods** (binary, no free-function detour required —
  Pair is fixed-arity at 2). Lockstep migration with Either is recommended
  by Either v1.0.0 lines 882–897.

* Future cartesian-product / coproduct families (Result variants,
  These / Validation, etc.) should follow the same convention. The
  cross-package convention is therefore:

| Type | Arity | Per-position form | Total form |
|------|-------|-------------------|------------|
| Either | binary (variant) | `e.map(left:)` / `e.map(right:)` (instance) | `e.map(left:right:)` (instance) |
| Pair | binary (product) | `p.map(first:)` / `p.map(second:)` (instance) | `p.map(first:second:)` (instance) |
| Result | binary (variant) | `r.map(success:)` / `r.map(failure:)` (instance, mirror) | — |
| Product (n-ary) | variadic (product) | `map(p, first:)` etc. (free function for n≤3) | `p.map(transforms…)` (instance, pack-native) |

This is **the convention to codify** if a third instance arrives. Per Either
v1.0.0 line 952, this is already a candidate for skill-lifecycle promotion.

---

### Migration Plan

| File | Change | LOC delta |
|------|--------|-----------|
| `Sources/Product Primitives/Product.swift` | Remove stale `// Note: Codable…` comment. Move conditional conformances to `+Conformances`. | ~−6 |
| `Sources/Product Primitives/Product+Conformances.swift` | New file. Existing conformances (Sendable, Equatable, Hashable, Error) plus new (Comparable, CustomStringConvertible, Encodable, Decodable). | ~+90 |
| `Sources/Product Primitives/Product+Map.swift` | New file. n-ary instance `.map(transforms…)`. | ~+15 |
| `Sources/Product Primitives/Product+Map+Binary.swift` | New file. Three free `map` overloads for n=2. | ~+30 |
| `Sources/Product Primitives/Product+Map+Ternary.swift` | New file. Seven free `map` overloads for n=3. | ~+70 |
| `Sources/Product Primitives/Product+Append.swift` | New file. `append` / `prepend` instance methods. | ~+15 |
| `Sources/Product Primitives/Product+Zip.swift` | New file. `zip` instance method. | ~+15 |
| `Sources/Product Primitives/Product+Fold.swift` | New file. `fold` instance method. | ~+15 |
| `Sources/Product Primitives/Product+Swap.swift` | New file. Free `swapped` for n=2. | ~+10 |
| `Tests/Product Primitives Tests/Product Tests.swift` | Add tests for every new method. | ~+200 |
| `README.md` | Update examples to show new operations. | ~+40 |
| Production consumers | None today — Product was just extracted; no functor-method consumers exist yet. | 0 |

The package is pre-1.0 and its only consumer is its own test suite. The
migration is purely additive — no breaking changes — except for removing
the stale Codable comment.

---

## Loose Ends / Open Questions

Per [RES-027], distinguishing **premises** (load-bearing for downstream
design) from **directions** (informational).

### Premises (require empirical follow-up before downstream commits)

1. **Free-function `map` namespace-pollution risk.** The recommendation
   uses bare free `map` overloads (matching stdlib precedent for `min`,
   `max`, `zip`). If a consumer reports collision with another `map`
   in scope, retreat to `Product.Operations.map` namespace pattern. The
   refutation experiment is straightforward: build a sample consumer
   importing both `Product_Primitives` and a hypothetical other package
   that defines a free `map` with overlapping argument types, observe
   whether `import` precedence resolves cleanly. Owned by the v0.2
   adoption pass.

2. **Pack-rebinding ceremony cost in Property.View.** The cost of redeclaring
   `each E2` per Property method is structural — would it ever be worth it
   if Product gained 8+ multi-form sub-operations under a single tag? The
   refutation experiment: count the multi-form sub-operations Product is
   likely to grow (transform.first, transform.second, transform.all,
   transform.skip, …). If we expect ≥4 such operations, Property.View's
   tag-namespace economy starts to dominate the per-method ceremony cost.
   Today Product has 1 (total transform). Reassess at v0.5 or earlier if
   user demand surfaces.

### Directions (informational, no follow-up required)

3. **Diagonal**, **curry / uncurry**, **applicative apply** — language gaps
   today; revisit when same-element-pack-requirement support lifts.

4. **`~Copyable` Product** — blocked at the language level. The shape
   recommended here is forward-compatible: instance methods using
   pack-of-closures would become `consuming`; free functions would take
   `consuming Product<...>`. No structural change required.

5. **Cross-package convention codification.** Once a third instance
   (Validation? These? Some future Result variant?) joins Either, Pair, and
   Product, the labeled-overload-on-shared-verb convention becomes worth
   promoting to a skill-rule per skill-lifecycle. Owned by the institute
   once a fourth tagged-scalar / cartesian-product family lands.

6. **Per-position map for `n ≥ 4`.** Combinatorial blow-up reaches 15 for
   n=4 and 31 for n=5. If demand surfaces, generalize via macro generation
   (e.g., a `@VariadicProductOverloads(arity: 4)` macro). Macros are
   compound-named at file scope per [API-NAME-001] exception, so this is
   feasible. Out-of-scope for v0.1.

7. **Zip-of-3+ Products.** The current `zip` is binary
   (`a.zip(b)`). Higher-arity zip (`a.zip(b, c)` returning `Product<(A,
   C, E), (B, D, F)>`) is expressible via pack-of-packs but requires
   more complex pack expansion. Defer until demand surfaces.

8. **Reorder for n ≥ 3.** `swap` is binary-only. General permutations are
   intractable to type at the surface level. Out-of-scope; users
   needing reorder construct a new Product manually.

---

## References

### Internal

* This package's source:
  `/Users/coen/Developer/swift-primitives/swift-product-primitives/Sources/Product Primitives/Product.swift`
  (*Verified: 2026-05-08*).
* Peer document — Either:
  `/Users/coen/Developer/swift-primitives/swift-either-primitives/Research/api-design-property-leverage.md`
  v1.0.0 RECOMMENDATION (*Verified: 2026-05-08*).
* Sibling document — academic and ecosystem survey (parallel agent):
  `academic-and-ecosystem-survey.md`.
* Foundational paper — Property type family:
  `/Users/coen/Developer/swift-primitives/swift-property-primitives/Research/property-type-family.md`
  v1.0.0 IMPLEMENTED (*Verified: 2026-05-08*).
* Skill `code-surface`:
  `/Users/coen/Developer/.claude/skills/code-surface/SKILL.md` —
  [API-NAME-001], [API-NAME-001a], [API-NAME-002], [API-NAME-008],
  [API-IMPL-005], [API-IMPL-008], [API-IMPL-012], [API-IMPL-013],
  [API-IMPL-014], [API-IMPL-015], [API-ERR-001], [API-NAME-013].
* Skill `implementation`:
  `/Users/coen/Developer/.claude/skills/implementation/SKILL.md` and
  `accessors.md` — [IMPL-INTENT], [IMPL-COMPILE], [IMPL-000], [IMPL-001],
  [IMPL-020], [IMPL-021], [IMPL-022], [IMPL-023], [IMPL-024], [IMPL-025],
  [IMPL-026], [IMPL-064], [IMPL-067], [IMPL-080], [IMPL-100].
* Skill `property-primitives`:
  `/Users/coen/Developer/swift-primitives/swift-property-primitives/Skills/SKILL.md` —
  [PRP-001] through [PRP-013].
* Skill `research-process`:
  `/Users/coen/Developer/.claude/skills/research-process/SKILL.md` —
  [RES-003], [RES-013a], [RES-019], [RES-020], [RES-021], [RES-022],
  [RES-023], [RES-025], [RES-026], [RES-027].
* Memory `pack-concrete-same-type.md` — same-type requirements between
  packs and concrete types are not yet supported (Swift 6.3.1 verified;
  generalizes the "extension Product<First, Second>" failure observed
  here).

### Existing Patterns in the Ecosystem

* `swift-either-primitives/Sources/Either Primitives/Either.swift`
  (binary coproduct sibling, current API surface — to be migrated per its
  own v1.0.0 RECOMMENDATION).
* `swift-pair-primitives/Sources/Pair Primitives/Pair.swift`
  (binary product sibling — same anti-pattern; recommended to migrate to
  labeled instance methods in lockstep with Product).
* `swift-property-primitives/Sources/Property Primitives Core/Property.swift`
  (Property core type — verified the typealias pattern compiles when
  parameterizing on `Product<repeat each Element>`).

### External

* Swift Evolution: SE-0393 (Value and Type Parameter Packs), SE-0398
  (Same Element Requirements), SE-0408 (Pack Iteration), SE-0427 (Noncopyable
  Generics) — listed as the four main proposals shaping pack ergonomics.
* Swift Forums: discussions on pack-iterating Codable conformance,
  variadic-generic Equatable / Hashable patterns. Not directly cited; the
  empirical verification in this document supersedes forum-thread evidence
  for current-toolchain expressibility.

### Empirical Verification Trail

All compiler-behavior claims backed by experiments at
`/tmp/product-experiment/`:

| Claim | File | Result | Date |
|-------|------|--------|------|
| Top-level `enum Tag {}` works as Property tag | `test2.swift` | typecheck OK | 2026-05-08 |
| `enum Tag {}` inside `extension Product { … }` is rejected | `test1.swift` | error: enums cannot declare a type pack | 2026-05-08 |
| `struct Tag {}` inside `extension Product { … }` works | `test3.swift` | typecheck OK | 2026-05-08 |
| `extension Product<Int, String>` is rejected | `test14.swift` | error: same-type requirements between packs and concrete types are not yet supported | 2026-05-08 |
| `static func` on `Product` with concrete-pack constraint is rejected | `test9.swift` | same error | 2026-05-08 |
| Free `func map(p, first: …)` for `Product<First, Second>` works | `test13.swift` | run OK | 2026-05-08 |
| Pack-of-closures `func map(transforms…)` instance method works | `test7.swift`, `test10.swift`, `test15b.swift` | run OK | 2026-05-08 |
| `each Element: ~Copyable` is rejected | `test16.swift` | error: cannot suppress '~Copyable' on type 'each Element' | 2026-05-08 |
| `Product: Comparable` via pack iteration works | `test12.swift` | run OK (lexicographic comparison verified) | 2026-05-08 |
| `Product: CustomStringConvertible` via pack iteration works | `test11.swift` | run OK | 2026-05-08 |
| `Product: Encodable` + `Decodable` via pack iteration works (Codable comment is stale) | `test20.swift`, `test22.swift` | run OK; JSON round-trip verified for Product(1, "hi", true) | 2026-05-08 |
| `func append<T>` and `func prepend<T>` work via pack composition | `test17.swift` | run OK | 2026-05-08 |
| `func zip<each Other>` works via pack iteration | `test18.swift` | run OK | 2026-05-08 |
| Pack `count` via repeat-iteration works | `test19.swift` | run OK | 2026-05-08 |
| `extension Property where Tag == ProductMap` does NOT bring `each Element` into scope | `test15.swift` | error: cannot find type 'Element' in scope | 2026-05-08 |
| `extension Property where Tag == ProductMap` works when method declares its own `each E2` | `test15b.swift` | run OK | 2026-05-08 |
