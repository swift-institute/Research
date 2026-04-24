# Zip Primitive Placement

<!--
---
version: 2.0.0
last_updated: 2026-02-06
status: RECOMMENDATION
tier: 3
---
-->

## Context

The parallel-iteration-primitives research (RECOMMENDATION) established that binary zip (φ₂) is the universal primitive for N-ary parallel iteration. The experiment (`parallel-iteration-test`, 17/19 CONFIRMED) validated that `Pair<~Copyable, ~Copyable>`, N-ary zip via parameter packs (Copyable), and nested binary composition all work in Swift 6.2.3.

The remaining question: where does the zip primitive live in the 20-tier architecture, and what form should it take?

### Trigger

[RES-001] Architecture choice: multiple packages could host zip. The placement establishes a lasting precedent for all multi-input combinators in the primitives layer.

### Scope

[RES-002a] This affects algebra-primitives (Tier 0, product types), sequence-primitives (Tier 7, iteration protocols), and range-primitives (Tier 9, Range.Lazy). Primitives-wide per RES-002a. Tier 3 per RES-020 (precedent-setting, hard to undo, normative).

### Assumptions

No backwards-compatibility constraints. Breaking changes are acceptable. The goal is the correct abstraction, not migration cost.

## Question

In which package and at which tier should the zip primitive live, and what form should it take (free function, method, Property tag, witness)?

## Constraints

### Hard Constraints

1. **Tier compliance** [PRIM-*]: Dependencies flow strictly downward.
2. **~Copyable support**: The 6 dual-index sites in storage-primitives use ~Copyable bounds. zip must handle them.
3. **No Foundation** [PRIM-FOUND-001].
4. **One type per file** [API-IMPL-005].
5. **Nest.Name pattern** [API-NAME-001].

### Swift Language Constraints (Immovable)

These are compiler/language limitations. No amount of breaking changes can circumvent them.

6. **No HKTs**: Cannot write `zip<F: Functor>(F<A>, F<B>) → F<Pair<A, B>>`. Must specialize per container type.
7. **No ~Copyable on parameter packs**: `each Element: ~Copyable` is a compiler error (experiment V4 REFUTED). N-ary zip via packs requires Copyable elements.
8. **Sequence.Protocol.Element requires Copyable**: SE-0427 deferred `~Copyable` suppression on associated types. `Sequence.Protocol` cannot support `~Copyable` elements regardless of breaking changes to our code. The constraint is in the language, not our design. `Range.Lazy: Sequence.Protocol where Bound: Copyable` is the maximum possible conformance.

### Removable Constraints

These existed in v1.0.0 of this document but are eliminated by accepting breaking changes.

9. ~~**`transform` is `@usableFromInline`**~~: Removed. We will add a public subscript to `Range.Lazy`, making it a proper representable functor with public `tabulate` (init) and `index` (subscript). External modules could then implement zip for `Range.Lazy`. **The recommendation no longer rests on this constraint.**

### Soft Constraints

10. **Generality**: Should be usable beyond Range.Lazy if possible.
11. **Laziness**: zip of lazy things should produce a lazy result.
12. **N-ary extensibility**: Should support or compose to N-ary.
13. **Prior art alignment**: Should feel natural to Swift developers.

## Prior Art Survey

[RES-021] Required for Tier 2+.

### Placement Patterns

| Language | zip Form | Module/Namespace | Lives With | Variadic? |
|----------|----------|-----------------|------------|-----------|
| Swift stdlib | Free function | `Swift` (core) | `Sequence` protocol | No (`Zip2Sequence`) |
| Rust | Free function + method | `core::iter` | `Iterator` trait | No |
| C++23 | View adaptor | `<ranges>` | `view_interface` | Yes (parameter pack) |
| Haskell | Free function | `Prelude` / `Data.List` | `[]` type | Manual (`zip3`..`zip7`) |
| Haskell (semialign) | Typeclass method | `Data.Zip` | `Semialign` superclass | No |

### Consensus

**Every language places zip at the same layer as the iteration protocol it operates on.** Swift puts it in `stdlib/core` alongside `Sequence`. Rust puts it in `core::iter` alongside `Iterator`. C++ puts it in `<ranges>` alongside `view_interface`. Haskell puts it in `Prelude` alongside `[]`.

**Every language uses free functions or view types for zip.** Even Rust, which has `Iterator::zip` as a method, added the free function `core::iter::zip` later (PR #82917) for symmetry and cleaner nesting.

The product type (tuple/pair) is a **dependency**, not the host. No language places zip on the product type.

### Rust Free Function Rationale (Documented)

From PR #82917:

1. **Symmetry**: Both arguments are function parameters, treating them equally. The method form creates false asymmetry.
2. **More permissive bounds**: Free function takes `IntoIterator` for both; method requires receiver to already be `Iterator`.
3. **Cleaner nesting**: `zip(zip(xs, ys), zs)` vs `xs.into_iter().zip(ys).zip(zs)`.
4. **Better formatting**: Naturally accommodates complex iterators.

## Theoretical Grounding

[RES-022] Required for Tier 2+.

### zip is the Lax Monoidal Functor Multiplication

```
φ_{A,B} : F(A) × F(B) → F(A × B)
```

This natural transformation:
- **Belongs to the functor F** (it's structure on F, categorically)
- **Uses the product type** (A × B) as codomain structure
- **Is NOT a property of the product type**

### Range.Lazy as Representable Functor

A functor F is **representable** when `F(A) ≅ (R → A)` for some representing object R. For representable functors, the applicative (zip) is uniquely determined:

```
zip(fa, fb) = tabulate(λk. (index(fa, k), index(fb, k)))
```

`Range.Lazy` is representable with `R = Range.Index`:
- `tabulate` = `Range.Lazy.init(count:transform:)` (public)
- `index` = element access at a position (currently `@usableFromInline`, **should be public**)

Making `index` public (via subscript) completes the representable functor interface and enables zip to be defined externally. However, **the correct package placement does not change** — see Analysis.

### Why No Generic zip Without HKTs

A generic zip requires expressing "for any lax monoidal functor F":

```swift
func zip<F: LaxMonoidal, A, B>(_ fa: F<A>, _ fb: F<B>) -> F<Pair<A, B>>
```

Swift has no higher-kinded types. The only viable approach is **per-type overloads** with consistent naming, consistent product types, and Swift overload resolution selecting the right one.

### Why No Algebraic Witness for zip

The algebra-primitives witness pattern (Magma → Field) works for **endomorphisms on a carrier type**: `(Element, Element) -> Element`. zip is a **type-changing** operation: `(F<A>, F<B>) -> F<Pair<A, B>>`. The witness pattern cannot express type-changing natural transformations. No `Zip<Container>` witness is possible in Swift's type system.

## Analysis

### Option A: algebra-primitives (Tier 0)

Algebra-primitives hosts `Pair` and `Product` — the product types that zip produces. Could zip live here?

**Impossible.** Algebra-primitives has zero dependencies (Tier 0). It cannot see `Range.Lazy` (Tier 9), `Sequence.Protocol` (Tier 7), or any container type. It provides the **codomain structure** for zip, not the zip operation itself.

This is the categorical insight: the product type is in the **target category's monoidal structure**. zip is a property of the **functor**, not the monoidal product.

**Role**: Export `Pair` and `Product`. Nothing more.

### Option B: sequence-primitives (Tier 7)

Sequence-primitives defines `Sequence.Protocol`, which `Range.Lazy` conditionally conforms to.

```swift
// Hypothetical: generic Sequence.Zip in sequence-primitives
public struct Sequence.Zip<First: Sequence.Protocol, Second: Sequence.Protocol>
    : Sequence.Protocol {
    public typealias Element = Pair<First.Element, Second.Element>
    ...
}
```

**Advantages**:
- Most general — works for any `Sequence.Protocol` conformer
- Lower tier (7) means more packages can depend on it
- Follows Swift stdlib's `Zip2Sequence` pattern

**Disadvantages**:
- **Cannot serve the primary use case.** SE-0427 prevents `Sequence.Protocol.Element: ~Copyable`. This is a language limitation, not our design — breaking changes to our code cannot fix it. The 6 storage-primitives sites that need zip use ~Copyable bounds. Option B is blocked by the Swift compiler.
- **Loses indexed structure.** The result would be `Sequence.Zip<...>` (sequential), not `Range.Lazy<Pair<...>>` (indexed, representable). Cannot be passed to APIs expecting `Range.Lazy`.
- **Eager convention.** Existing Sequence operations (`map`, `filter`) return `[U]` (arrays). A lazy `Sequence.Zip` would break that convention.
- **The Property.View pattern is single-input.** zip takes two equal-weight inputs — requires a new pattern.

### Option C: range-primitives (Tier 9)

Range-primitives defines `Range.Lazy<Bound: ~Copyable>`, the specific functor being zipped.

```swift
// Free function in range-primitives
public func zip<A: ~Copyable, B: ~Copyable>(
    _ a: Range.Lazy<A>, _ b: Range.Lazy<B>
) -> Range.Lazy<Pair<A, B>>
```

**Advantages**:
- **Handles ~Copyable.** Binary overload works with `~Copyable` bounds — covers all 6 sites.
- **Produces lazy result.** Returns `Range.Lazy<Pair<A, B>>`, preserving indexed structure and laziness.
- **Categorically correct.** zip belongs with the functor, and Range.Lazy is the functor.
- **Prior art unanimous.** Matches every studied language: zip lives with its container.
- **Free function naming.** `zip(a, b)` — general name enables overloading by future packages.
- **Legal dependency.** Needs algebra-primitives (Tier 0) for `Pair`. Tier 9 → Tier 0 is downward-only.

**Note on `transform` accessibility**: v1.0.0 of this document cited `transform` being `@usableFromInline` as "architecturally decisive." With breaking changes accepted, we will add a public subscript to `Range.Lazy`, making the representable functor interface complete. zip *could* then be implemented externally. **The recommendation stands on category theory and prior art, not on visibility modifiers.**

**Disadvantages**:
- Implementation is Range.Lazy-specific (inherent — unfixable without HKTs).
- Higher tier (9) means packages between 0–8 can't use it. But no package in tiers 0–8 currently needs zip on Range.Lazy.

### Option D: New swift-zip-primitives Package

Dedicated package for zip infrastructure.

**Disadvantages dominate**:
- If it zips `Range.Lazy`, depends on range-primitives (Tier 9) → placed at Tier 10. Worse than Option C.
- If it only defines a tag/protocol, actual implementations still live in container packages.
- Adds a package for a single function with no reusable abstraction.
- No prior art for zip as a separate module/package in any language studied.

### Comparison

| Criterion | A: algebra | B: sequence | C: range | D: new pkg |
|-----------|-----------|------------|---------|-----------|
| **Can host zip?** | No | Copyable only (language limit) | Yes | Adds tier |
| **~Copyable support** | N/A | Blocked by SE-0427 | Yes | Same as C |
| **Lazy result** | N/A | Novel type, loses indexing | `Range.Lazy<Pair>` | Same as C |
| **Categorical fit** | Product, not functor | Wrong functor | Correct functor | Same as C |
| **Tier** | 0 | 7 | 9 | 10 |
| **Prior art** | None | Swift stdlib | All languages | None |
| **New dependency** | N/A | +algebra | +algebra | +everything |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option C — free function `zip` in range-primitives, with Range.Lazy upgraded to a proper representable functor.

### Rationale

The recommendation rests on three independent arguments. Any one is sufficient; together they are conclusive.

1. **Category theory**: zip is the tensorator (φ₂) of a lax monoidal functor. It belongs with the functor, not the product type. The functor is `Range.Lazy`. The product types (`Pair`, `Product`) are in algebra-primitives — codomain structure, not the host. Placing zip in algebra would be categorically backwards.

2. **Prior art unanimous**: Every language studied places zip with the container/iterator type. Swift stdlib: `zip` alongside `Sequence`. Rust: `core::iter::zip` alongside `Iterator`. C++23: `zip_view` in `<ranges>`. Haskell: `zip` in `Prelude` alongside `[]`. Zero counter-examples across 5 languages and 4 decades.

3. **Swift language constraint (SE-0427)**: `Sequence.Protocol.Element` cannot be `~Copyable`. This is immovable — no breaking change to our code can fix a language limitation. The primary use case (6 storage-primitives sites) requires ~Copyable bounds. Only Range.Lazy-level zip can serve it.

### Breaking Changes Required

| Change | Package | Impact |
|--------|---------|--------|
| Add public subscript `Range.Lazy[_: Range.Index] -> Bound` | range-primitives | Completes representable functor interface |
| Add algebra-primitives dependency | range-primitives Package.swift | Tier 9 → Tier 0, legal |
| Re-export `Algebra_Primitives` | range-primitives exports.swift | Transitive availability |
| Upgrade `Pair` to `~Copyable` | algebra-primitives | Breaking: existing Pair users get conditional Copyable |
| Drop `paired(from:)` plan | parallel-iteration-primitives.md | zip subsumes it |

### Superseded: forEach-Level `paired(from:)`

The parallel-iteration-primitives.md recommended `paired(from:)` on `Property<Range.ForEach, _>`. With breaking changes accepted, **zip replaces it entirely**:

| Aspect | `paired(from:)` (superseded) | `zip` (recommended) |
|--------|-----|-----|
| Level | Operation (forEach) | Container |
| Result | Void | `Range.Lazy<Pair<A, B>>` |
| Composability | Inline only | First-class value |
| Counter pattern | Direct | `zip(range, (.zero..<count))` |
| Generality | Range.ForEach only | Any consumer of Range.Lazy |

The counter-advancement pattern (advancing `Index<T>` alongside iteration) is expressed as zip with an identity range:

```swift
// Before (paired):
range.forEach.paired(from: .zero) { element, index in ... }

// After (zip):
zip(range, (.zero..<count)).forEach { pair in
    let (element, index) = (pair.first, pair.second)
    ...
}
```

zip is strictly more general. `paired(from:)` is unnecessary.

### Design Specifics

**Binary overload** (~Copyable):
```swift
public func zip<A: ~Copyable, B: ~Copyable>(
    _ a: Range.Lazy<A>, _ b: Range.Lazy<B>
) -> Range.Lazy<Pair<A, B>>
```

**N-ary overload** (Copyable, parameter packs):
```swift
public func zip<each Bound>(
    _ ranges: repeat Range.Lazy<each Bound>
) -> Range.Lazy<Product<repeat each Bound>>
```

**Overload resolution**:

| Call | Winner | Return Type |
|------|--------|-------------|
| `zip(a, b)` where A, B: Copyable | Binary (non-variadic preferred) | `Range.Lazy<Pair<A, B>>` |
| `zip(a, b)` where A: ~Copyable | Binary (only match) | `Range.Lazy<Pair<A, B>>` |
| `zip(a, b, c)` | N-ary (only match) | `Range.Lazy<Product<A, B, C>>` |
| ~Copyable 3+ | `zip(zip(a,b),c)` | `Range.Lazy<Pair<Pair<A,B>,C>>` |

### Precedent Established

This research establishes the convention for multi-input combinators in the primitives layer:

| Aspect | Convention |
|--------|-----------|
| **Form** | Free function (not method, not Property, not witness) |
| **Naming** | General name (`zip`), not container-prefixed (`Range.zip`) |
| **Location** | Same package as the primary container type (functor) |
| **Product types** | `Pair<A, B>` (binary, ~Copyable) and `Product<each Element>` (N-ary, Copyable) from algebra-primitives |
| **Overloading** | Each package adds overloads for its types. Swift resolution picks the most specific. |

### Implementation Path

1. Upgrade `Pair` to `~Copyable` in algebra-primitives
2. Document `Product` ~Copyable limitation in algebra-primitives
3. Add public subscript to `Range.Lazy` (representable functor `index`)
4. Add algebra-primitives dependency to range-primitives `Package.swift`
5. Re-export `Algebra_Primitives` from range-primitives
6. Implement `zip` free functions in range-primitives

### Future: Sequence-Level zip

A `Sequence.Zip` type in sequence-primitives could be added later for generic Copyable sequences, if/when SE-0427 is relaxed or a use case demands it. This would not conflict with the Range.Lazy overloads. This is a separate decision not required for the current work.

### Cross-References

- `swift-range-primitives/Research/parallel-iteration-primitives.md` — theoretical foundations (superseded in its `paired(from:)` recommendation)
- `swift-range-primitives/Experiments/parallel-iteration-test/` — empirical validation
- `swift-primitives/Research/algebra-primitives-package-split.md` — algebra tier architecture

## Changelog

### v2.0.0 (2026-02-06)
- Removed backwards-compatibility constraint
- Removed Constraint 9 (`transform` visibility) as rationale — recommendation now stands on category theory and prior art alone
- Added representable functor analysis: Range.Lazy should gain public subscript (`index`)
- Superseded `paired(from:)` — zip replaces it entirely
- Added "Why No Algebraic Witness" section
- Added breaking changes table

### v1.0.0 (2026-02-06)
- Initial analysis

## References

[RES-026]

- Fridlender, D. & Indrika, M. (1998). *An n-ary zipWith in Haskell*. BRICS RS-98-38.
- Kmett, E. (2008). *Zipping and Unzipping Functors*. The Comonad.Reader.
- Kmett, E. (2013). *Representing Applicatives*. The Comonad.Reader.
- SE-0312: Indexed and Collection conformances for enumerated() and zip(). Returned for revision.
- SE-0398: Allow Generic Types to Abstract Over Packs.
- SE-0427: Noncopyable generics. (Deferred ~Copyable on associated types.)
- Rust PR #82917: Add function `core::iter::zip`.
- C++ P2321R2: zip.
- Haskell `Data.Zip` (semialign package).
