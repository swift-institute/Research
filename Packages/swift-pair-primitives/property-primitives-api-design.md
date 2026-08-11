# Property-Primitives API Design

<!--
---
version: 1.1.0
last_updated: 2026-05-08
status: DECISION
tier: 2
scope: per-package
applies_to: [swift-pair-primitives]
---

## Changelog
- v1.2.0 (2026-05-08): Empirical verification added per /experiment-process.
  `Experiments/property-view-pair-attempt/` (5 variants) provides the receipts:
  V1 (REFUTED — two-generic blocker without bridge), V2 (CONFIRMED partial —
  PairLike bridge works for Copyable read-only methods, matches dictionary
  case-study §4.2.1 "Protocol Witness" approach), V3+V4+V5 (REFUTED — the
  type-changing-transform blocker is structural, surfaced across Property.Typed
  consuming methods, Property.Consume's explicit `consume()`, and
  Property.Inout's `_modify` borrow contract). New finding from the experiment:
  Pair is nominally `~Copyable` (with conditional Copyable extension); the
  implicit copy that powers property-primitives' Stack example does not fire
  for nominally-~Copyable types — a separate friction axis from the two
  blockers Stream A originally identified.
- v1.1.0 (2026-05-08): Promoted RECOMMENDATION → DECISION. Option C
  implemented in `Sources/Pair Primitives/Pair.swift`; `mapFirst` →
  `map(first:)`, `mapSecond` → `map(second:)`, `bimap(first:second:)` →
  `map(first:second:)` for both `~Copyable` static tier and `Copyable`
  instance tier; `allFirsts` deleted; `swapped`, `apply`, init, and tuple
  conversion unchanged. Tests updated (21 passing). README updated.
  Open questions resolved: (1) labels are forced — overload resolution
  on three closure-bearing `map` shapes makes unlabeled trailing closures
  ambiguous; (2) `typealias Property<Tag>` deferred — no consumer demand;
  (3) `allFirsts` deleted as proposed.
- v1.0.0 (2026-05-08): Initial RECOMMENDATION; Option C identified as the
  structurally-correct shape.
-->

## Context

`swift-pair-primitives` was extracted recently as a standalone L1 primitive providing
`Pair<First, Second>: ~Copyable where First: ~Copyable, Second: ~Copyable`. The
public API was authored before property-primitives became the canonical
fluent-accessor mechanism in the swift-primitives ecosystem.

Three concerns motivate a redesign review:

1. **Compound-name [API-NAME-002] strict reading**: `mapFirst`, `mapSecond`, `bimap`,
   `allFirsts` are compound identifiers (verb-noun, multi-word noun). Per the
   strict reading codified in [API-NAME-002] and elaborated in [API-NAME-005] /
   [API-NAME-007] (the `swapAt` post-ship-rename incident), these warrant either
   nested-accessor decomposition or labeled-method renaming.
2. **Property.View ecosystem alignment**: Sibling packages
   (`swift-array-primitives`, `swift-deque-primitives`, `swift-heap-primitives`,
   the test-support `Container` / `Stack` / `Box` / `Slice` patterns)
   adopted `Property<Tag, Base>` accessor namespaces. Pair predates this
   adoption.
3. **Migration cost is unusually low**: the consumer survey (§Prior Art /
   Ecosystem usage) shows zero downstream call sites currently depend on any
   transformation method (`map`, `mapFirst`, `mapSecond`, `bimap`, `swapped`,
   `apply`, `tuple`, `allFirsts`). Five consumer packages use `Pair` solely as
   a typealias target (`Pair<Tag, Payload>`) and as constructor.
   The redesign is materially de-risked.

## Question

What is the optimal public API surface for `Pair<First, Second>` given:
- the swift-institute property-primitives ecosystem (`swift-property-primitives`
  variants `Property` / `Property.Typed` / `Property.Inout` / `Property.Borrow` /
  `Property.Consume`)
- [API-NAME-002] no compound identifiers; [API-NAME-008] multi-form vs single-form
  decision rule
- [IMPL-020] / [IMPL-021] / [IMPL-022] / [IMPL-023] Property.View patterns and
  static-method architecture for `~Copyable` generics
- [API-IMPL-005] one type per file
- the dual-tier obligation: `~Copyable` (resource-pair) AND `Copyable`
  (value-pair) overload sets
- the **two-generic-parameter constraint** that disqualified
  `swift-dictionary-primitives` from the Property pattern (Property.Typed
  smuggles only one generic — Pair has First AND Second)

## Prior Art

### Internal (Step-0 grep results) [RES-019]

| Path | Relevance | Status |
|------|-----------|--------|
| `swift-pair-primitives/Research/` | Empty. No prior research on the package. | [Verified: 2026-05-08] |
| `swift-property-primitives/Research/case-study-dictionary-primitives-migration-failure.md` | **DECISION 2026-01-21**: Property pattern unsuitable for two-generic-parameter base types. `Property.Typed<Element>` smuggles ONE generic; `Dictionary<Key, Value>` failed because the second-level accessor cannot introduce both K and V. **Pair<First, Second> has the same shape.** | [Verified: 2026-05-08] |
| `swift-property-primitives/Research/property-tagged-semantic-roles.md` | RECOMMENDATION 2026-04-23. Tagged vs Property semantic taxonomy: Tagged for identity, Property for verb namespaces. Pair's `mapFirst`/`mapSecond` is verb-shape. | [Verified: 2026-05-08] |
| `swift-institute/Research/binary-primitives-package-decomposition.md` | Worked example of [API-NAME-008] applied to a sibling package: rejects Property.View for single-form serialization, keeps it for multi-form encoding. | [Verified: 2026-05-08] |
| `swift-institute/Research/binary-base-n-encoding-family-architecture.md` | Worked example: `instance.encode.{hex,url,b64}` is canonical multi-form Property.View. | [Verified: 2026-05-08] |
| `swift-institute/Research/Reflections/2026-04-24-post-hoc-api-name-compliance-swap-rename.md` | Origin of [API-NAME-008]: Option A (`swap(at:with:)`, single-form labeled) chosen over Option B (`swap.at(_, with:)`, Property.View) because `swap` has one form. **`swapped` on Pair has the same single-form shape.** | [Verified: 2026-05-08] |
| `swift-institute/Research/skill-verification-taxonomy-pilot.md` | Confirms [API-NAME-008] is a *semantic* judgment rule — must identify "two or more related sub-operations under one root noun." | [Verified: 2026-05-08] |
| `swift-property-primitives/Research/property-view-escapable-removal.md` | DECISION 2026-03-22: Property.View is `~Copyable` only (no `~Escapable`) due to CopyPropagation crash. Affects `_modify` lifetime story for any Pair adoption. | [Verified: 2026-05-08] |

**Carried-forward findings tagged below**:

- [Verified: 2026-05-08] — Property.Typed smuggles one generic only;
  `Dictionary<Key, Value>` migration failed for this reason
  (case-study-dictionary-primitives-migration-failure.md §4.2 lines 132–166).
- [Verified: 2026-05-08] — [API-NAME-008]'s decision frame: 2+ sub-operations
  under one root → Property.View; 1 operation disambiguated by labels →
  labeled method (`code-surface/SKILL.md:844-882`).
- [Verified: 2026-05-08] — Layer-consistency soft tie-breaker
  (`code-surface/SKILL.md:864`): match the name at the layer below; no
  layer-below for Pair, so this tiebreaker doesn't fire.

### Ecosystem usage of Pair (consumer survey)

Five primitive packages depend on Pair-Primitives. A grep across all five
Sources/ trees and Tests/ trees produces:

| Package | Pair use form | Usage count | Method calls |
|---------|---------------|-------------|--------------|
| `swift-symmetry-primitives/Sources/.../Rotation.Phase.swift:59` | `typealias Value<Payload> = Pair<Phase, Payload>` | 1 | None |
| `swift-algebra-primitives/Sources/.../{Monotonicity,Sign,Ternary,Polarity,Parity}.swift` | `typealias Value<Payload> = Pair<<X>, Payload>` | 5 | None |
| `swift-finite-primitives/Sources/.../{Comparison+Finite,Gradient,Bound,Endpoint,Boundary}.swift` | `typealias Value<Payload> = Pair<<X>, Payload>` | 5 | None |
| `swift-region-primitives/Sources/.../{Clock,Edge,Sextant,Octant,Cardinal,Corner,Quadrant}.swift` | `typealias Value<Payload> = Pair<<X>, Payload>` | 7 | None |
| `swift-algebra-primitives/Tests/.../Algebra Smoke Tests.swift:22,29` | `Pair(.negative, "minus")` constructor | 2 | None |

**Verbatim grep output** (2026-05-08):
```
$ grep -rnE "\.bimap\(|\.mapFirst\(|\.mapSecond\(|Pair\.map\(|\.swapped\(|Pair\.swapped\(|allFirsts|\.apply\(\{" \
    swift-symmetry-primitives/Sources/ swift-algebra-primitives/Sources/ \
    swift-finite-primitives/Sources/ swift-region-primitives/Sources/
(no results)
```

Confirmed [Verified: 2026-05-08]: **zero downstream call sites** invoke
`map`, `mapFirst`, `mapSecond`, `bimap`, `swapped`, `apply`, `tuple`, or
`allFirsts`. All consumers use `Pair` exclusively as a typealias target
`Pair<Tag, Payload>` (the classifier-value pattern: a finite-domain enum
paired with a payload of arbitrary type) and the constructor
`Pair(_, _)` once in tests.

The package's own `Pair Tests.swift` (270 lines) drives every transformation
method; the in-package test surface is the only confirmed consumer of
the transformation API.

### Property-primitives adoption patterns (test-support)

Validated patterns from `swift-property-primitives/Tests/Support/`:

| Base | Tier | Variant | Pattern | File |
|------|------|---------|---------|------|
| `Container<Element>: Copyable` | Copyable | `Property<Tag, Base>` (push/pop/merge) and `Property.Consume<Element>` (forEach) | `_read`/`_modify` with five-step CoW recipe | `Container.swift:30-98` |
| `Box: ~Copyable` | ~Copyable | `Property.Borrow` | `_read` only — read-only namespace | `Box.swift:16-28` |
| `Slice<Element: ~Copyable>` | ~Copyable, one generic | `Property.Borrow.Typed<Element>` and `Property.Inout.Typed<Element>` | `_read` for Borrow, `mutating _read`/`_modify` for Inout | `Slice.swift:15-37` |
| `Slice.Inline<Element, n>` | ~Copyable, generic + value-generic | `Property.{Borrow,Inout}.Typed<Element>.Valued<n>` | Same shape, two extra generic levels | `Slice.Inline.swift:13-29` |

**No two-generic-parameter base** appears in test-support. The
non-`.Valued` variants of Property.Typed accept only `<Element>`; the only
two-axis pattern (`Typed<Element>.Valued<n>`) keeps the second axis as a value
generic (`let n: Int`), not a type generic. Pair has *two type generics*, which
matches no existing adoption pattern.

## Analysis

### Specific design questions

The supervisor enumerated 12 specific questions; analysis answers them in the
context of each option below, with a consolidated answer table in
**§Outcome**. Key questions concentrated:

- Q1 (`map.first` / `map.second` shape): see §Option A and §Type-Changing
  Transformation Analysis.
- Q2 (`bimap` shape): see §Option A and §Type-Changing Transformation Analysis.
- Q3 (`apply` shape): see §Option A and §Outcome.
- Q4 (`swapped` shape): see §Option C — `swap` is single-form per [API-NAME-008].
- Q5 (`tuple` conversion): unchanged across all options; see §Outcome.
- Q6 (`allFirsts`): see §Outcome migration table.
- Q7–Q9 (Property.View on type-changing transforms): see §Type-Changing
  Transformation Analysis.
- Q10 (existential / inferred `<New>`): supported in all options; see code
  examples.
- Q11 (`zip` / `unzip` symmetry): out of scope — defer until a consumer
  surfaces the demand per [RES-018].
- Q12 (`fst` / `snd` shorthand): keep `first` / `second`; established stored
  property names already adhere to ecosystem convention. No change.

### Option A: Full Property.View accessor surface

Adopt `Property<Tag, Pair<First, Second>>.Inout` for the `~Copyable` tier and
`Property<Tag, Pair<First, Second>>` (or `.Typed<First, Second>` if invented)
for the `Copyable` tier. Move `map.first`, `map.second`, `map.both`, `swap`,
`apply` under nested accessor surfaces.

**Concrete code sketch** (illustrative — does NOT compile as written):

```swift
extension Pair where First: ~Copyable, Second: ~Copyable {
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Pair<First, Second>>
}

extension Pair where First: ~Copyable, Second: ~Copyable {
    public enum Map {}
    public enum Swap {}
}

extension Pair where First: ~Copyable, Second: ~Copyable {
    public var map: Property<Map>.Inout {
        mutating _read  { yield .init(&self) }
        mutating _modify {
            var accessor = Property<Map>.Inout(&self)
            yield &accessor
        }
    }
}

// Type-changing transformations — fundamental obstacle, see analysis below
extension Property.Inout
where Tag == Pair<First, Second>.Map, Base == Pair<First, Second>,
      First: ~Copyable, Second: ~Copyable {
    // ❌ Cannot return Pair<NewFirst, Second> from an _modify-coroutine view —
    //    Property.Inout's `base.value` yields exclusive ref to Base, not a
    //    means to *replace* self with a different type.
    public consuming func first<NewFirst: ~Copyable, E: Swift.Error>(
        _ transform: (consuming First) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Second> { /* impossible */ }
}
```

**Pros**:
- Aligns with binary-base-n / encoding-family / dictionary-primitives prior
  art (when applicable).
- Visual consistency with `stack.push.back` / `box.inspect.first` shape.

**Cons**:
- **Disqualified by the two-generic-parameter constraint**
  (case-study-dictionary-primitives-migration-failure.md §4.2). Pair has
  `<First, Second>`; Property.Typed smuggles only one type generic. The
  case-study explicitly enumerates this as a Property-pattern blocker.
- **Disqualified by the type-changing nature of `map`**: Property.Inout's
  `_modify` coroutine yields `inout Base` of the *same* type. `mapFirst`
  returns `Pair<NewFirst, Second>` — a *different* type. There is no way to
  return a different type through an `_modify` coroutine without consuming
  self, and consuming self defeats the Property.View access model entirely.
  The Property.View surface is fundamentally a borrow-style mutating
  accessor for in-place modification of the SAME base type. (See
  property-view-escapable-removal.md §Context for the design intent.)
- Misalignment with [API-NAME-008] semantic test: the candidate
  sub-operations of `map` are `first`, `second`, `both` — but only `first` and
  `second` could conceivably appear under a single accessor; `both` (currently
  `bimap(first:second:)`) is not naturally a sibling of `first`/`second` since
  it accepts two transforms. The [API-NAME-008] table treats `peek.{front,
  back}` (two sub-ops, one root, no type change) as the canonical
  multi-form. `map.{first, second, both}` introduces a TYPE-CHANGING
  axis the canonical examples don't carry. Cited:
  `code-surface/SKILL.md:849-855`.
- Adds a hard dependency on `swift-property-primitives` and (transitively)
  `swift-tagged-primitives` and `swift-ownership-primitives` to a package
  that today has zero dependencies (`Package.swift:20`). For a Tier-1
  primitive whose ecosystem role is to be a foundational typealias target
  (consumer survey: 18 typealias sites across 4 packages), this dependency
  inversion violates [RES-018]: do not add infrastructure to a primitive
  ahead of demand.

**Verdict**: **REJECTED** on three independent structural grounds. The
two-generic-parameter constraint and the type-changing-transformation
constraint each disqualify this option without further consideration; the
[RES-018] dependency-cost concern reinforces the rejection.

### Option B: Hybrid — Property.View for sub-grouping, labeled methods for type-changing transforms

Recognize that type-changing `map` cannot live under Property.View, but split
the API surface so that:
- a `pair.swap` namespace owns `pair.swap.copy()` (returning `Pair<Second,
  First>`, the existing `swapped()`) and possibly `pair.swap.in_place()` (a
  same-type swap if First == Second, requiring constraint).
- type-changing transforms (`map`, `mapFirst`, `bimap`) remain top-level
  labeled methods.

Code sketch:

```swift
extension Pair where First: ~Copyable, Second: ~Copyable {
    // Same-type-axis namespace
    public var swap: Property<Swap>.Inout { ... }
}

extension Property.Inout where Tag == Pair<F, S>.Swap, Base == Pair<F, S> {
    // pair.swap.in_place() — only meaningful when First == Second
    public mutating func in_place() where F == S { /* same-type swap */ }
}

// Top-level labeled methods for type-changing transforms
extension Pair where First: ~Copyable, Second: ~Copyable {
    public consuming func swapped() -> Pair<Second, First> { ... }
    public static func map(...) ...
}
```

**Pros**:
- Surfaces a `swap.in_place` future without dropping the existing `swapped()`.
- Preserves single-form `map` / `mapFirst` / `bimap` as labeled methods (their
  natural shape after [API-NAME-008] decomposition).

**Cons**:
- The `swap` Property.Inout namespace adds the property-primitives dependency
  to enable a single same-type method `swap.in_place()` that has no existing
  consumer demand (consumer survey: zero `.swap*` invocations, zero in-place
  swap demand). [RES-018]: premature primitive.
- `pair.swap.copy()` is a redundant alias for `pair.swapped()` (the existing
  consuming form). Two paths to the same operation are worse than one.
- Single-form Property.View ceremony — the same anti-pattern [API-NAME-008]'s
  Option B rejected for `swap.at(_, with:)`. If `swap` ever expands to two
  related sub-operations, promotion to Property.View is mechanical; today's
  solo case takes the labeled-method form per [API-NAME-001a]'s "promote
  when the second sibling actually arrives" spirit.

**Verdict**: REJECTED. The structural reason matches Option B in
[API-NAME-008] origin: Property.View ceremony around a single-form
operation is wrong-shape; the labeled-method form is correct.

### Option C: Minimal-change labeled-method renames (no Property.View adoption)

Apply [API-NAME-002]'s decomposition strictly without invoking property-primitives.
Rename per single-form / multi-form analysis:

- `mapFirst` / `mapSecond` are *labeled-method peers of `map`* per [API-NAME-008]
  single-form: each takes one transform; argument labels disambiguate which
  component is mapped. The unified signature is `map(first:)` / `map(second:)`,
  i.e., a labeled method with one-and-only-one labeled argument selecting the
  axis. Existing instance `map(_:)` (the unlabeled "map second") is dropped —
  the unlabeled form is ambiguous about which axis is mapped.
- `bimap(first:second:)` is *the same `map` operation with both labels supplied
  simultaneously*: `map(first:second:)`. Single overload of `map` covers all
  three current methods; argument labels disambiguate.
- `swapped()` stays as the consuming instance method on the `~Copyable` tier
  ([API-NAME-008] single-form: one operation, no sub-forms; the case is
  isomorphic to the `swap(at:with:)` origin example).
  - Static `swapped(_:)` (`Pair.swapped(pair)`) is removed; the consuming
    instance form covers both tiers.
- `apply(_:)` stays as the consuming method (single-form: fold both
  components into a single result; no sub-forms). Per [API-NAME-008] this
  is the canonical labeled-method shape.
- `allFirsts` becomes a static under a renamed namespace: `Pair.first.cases`
  (where `Pair.first` is a static namespace placeholder, NOT the stored
  property — see §Outcome migration table for the resolution).

**Concrete proposed surface** (`~Copyable` tier):

```swift
@frozen
public struct Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable {
    public var first: First
    public var second: Second
    public init(_ first: consuming First, _ second: consuming Second)
}

// MARK: Static core (~Copyable tier)

extension Pair where First: ~Copyable, Second: ~Copyable {
    // Type-changing maps
    public static func map<NewSecond: ~Copyable, E: Swift.Error>(
        _ pair: consuming Pair,
        second transform: (consuming Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<First, NewSecond>

    public static func map<NewFirst: ~Copyable, E: Swift.Error>(
        _ pair: consuming Pair,
        first transform: (consuming First) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Second>

    public static func map<NewFirst: ~Copyable, NewSecond: ~Copyable, E: Swift.Error>(
        _ pair: consuming Pair,
        first firstTransform: (consuming First) throws(E) -> NewFirst,
        second secondTransform: (consuming Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<NewFirst, NewSecond>

    // Fold
    public consuming func apply<R: ~Copyable, E: Swift.Error>(
        _ body: (consuming First, consuming Second) throws(E) -> R
    ) throws(E) -> R

    // Swap
    public consuming func swapped() -> Pair<Second, First>
}
```

`Copyable` instance convenience tier (each method delegates to its static):

```swift
extension Pair where First: Copyable, Second: Copyable {
    public func map<NewSecond, E: Swift.Error>(
        second transform: (Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<First, NewSecond>

    public func map<NewFirst, E: Swift.Error>(
        first transform: (First) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Second>

    public func map<NewFirst, NewSecond, E: Swift.Error>(
        first firstTransform: (First) throws(E) -> NewFirst,
        second secondTransform: (Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<NewFirst, NewSecond>

    // Tuple conversion (unchanged)
    public init(_ tuple: (First, Second))
    public var tuple: (First, Second) { (first, second) }
}
```

**Note on instance map (Copyable tier) and overload disambiguation**:
The argument labels (`first:`, `second:`, `first:second:`) disambiguate
the three overloads at every call site:

```swift
let p = Pair(1, 2)
let a = p.map(first: { $0 + 10 })          // Pair(11, 2) — Pair<Int, Int>
let b = p.map(second: { String($0) })      // Pair(1, "2") — Pair<Int, String>
let c = p.map(first: { $0 + 10 },
              second: { String($0) })      // Pair(11, "2") — Pair<Int, String>
```

The current `pair.map { ... }` (unlabeled, defaults to `mapSecond` semantics) is
intentionally removed: the unlabeled form privileges Second over First without
visual cue, surprising readers. Forcing the label on every call surfaces the
asymmetry intent. `pair.bimap(first:second:)` becomes `pair.map(first:second:)`,
collapsing the bifunctor surface into a single overloaded method — `bimap`
was a Haskell loanword for the same operation.

**Compiler check (`code-surface/SKILL.md:825-840`, [API-NAME-007])**:
- `mapFirst` / `mapSecond` / `bimap` all have internal capitals AND
  pedigree from Haskell/PointFree (`bimap` is the Haskell `Bifunctor.bimap`,
  `mapSecond` mirrors `Tagged.map` but on the second component). [API-NAME-007]
  triggers fire in BOTH directions; both checks demand
  re-verification against [API-NAME-002].
- The proposed names (`map(first:)`, `map(second:)`, `map(first:second:)`,
  `swapped()`, `apply(_:)`) contain no internal capitals and no external-API
  pedigree carrying compound semantics.
- [API-NAME-008] decision test (verbatim from `code-surface/SKILL.md:851-857`):
  - `map.{first, second, both}` would be 3 sub-operations under one `map`
    root. *Form-shape*: candidate multi-form. **But** the type-changing axis
    is incompatible with Property.View (see §Type-Changing Transformation
    Analysis below). **Conclusion**: can't use Property.View; falls back to
    labeled methods.
  - Among labeled-method options, `map(first:)` / `map(second:)` /
    `map(first:second:)` is the natural overload set. The argument labels
    discriminate; the return type changes per overload.

**Pros**:
- **Zero new dependencies**. Pair stays a foundation-free, dependency-free
  primitive (`Package.swift:20` — the current state).
- **Honors the two-generic-parameter constraint**. No Property.View adoption
  attempt to fail on the same shape that disqualified
  `swift-dictionary-primitives`.
- **Honors the type-changing-transformation constraint**. Static methods
  return `Pair<NewFirst, Second>` naturally; no impedance mismatch with
  `_modify` coroutine semantics.
- **Strict [API-NAME-002] compliance**. All compound names removed.
  `mapFirst`/`mapSecond`/`bimap`/`allFirsts` decomposed into argument labels.
- **Migration cost is minimal**. Per the consumer survey, no production call
  site invokes the old method names. Migration is the in-package test
  rewrite (lines 47–144 of `Pair Tests.swift`) plus the README example
  rewrite. Estimated: 2 file changes, ~30 line edits, no consumer-package
  cascade.
- **Layer-consistency soft tie-breaker** ([API-NAME-008] step 4): no
  layer-below alternative to consult for Pair (it IS the bottom layer for
  cartesian-product types). The soft tie-breaker is silent; the multi-form
  vs single-form analysis stands on its own.

**Cons**:
- Loses visual consistency with the `instance.namespace.method` shape
  fashionable elsewhere in the ecosystem. This is a presentation cost.
  However, presentation consistency cannot override structural
  disqualifications (Option A's two failures).
- Three `map` overloads create a small overload-resolution surface. SE-0286
  forward-scan with argument labels handles this cleanly; tested in
  `swift-buffer-primitives/Buffer.Linear.swap(at:with:)` precedent
  (cited in `code-surface/SKILL.md:865-866` as the layer-consistency
  example).

### Option D: Static-method core + thin instance facade ([IMPL-023] layered)

Apply [IMPL-023] static-method architecture: keep the existing static-method
core, expose it as instance methods on the `~Copyable` tier with consuming
self, and add the Copyable-tier convenience layer.

This is *almost* the current shape (the existing code already has static
methods plus a Copyable instance facade — `Pair.swift:55-148`). The only
change [IMPL-023] adds is removal of the "instance convenience for ~Copyable"
extensions (currently only `swapped()`), routing all `~Copyable` method calls
through `Pair.<verb>(pair, ...)`.

**Pros**:
- Crisp [IMPL-023] adherence.
- Eliminates `~Copyable` overload-recursion potential per [IMPL-023]'s motivation.

**Cons**:
- Doesn't address [API-NAME-002] compound names. Still has `mapFirst`,
  `mapSecond`, `bimap`, `allFirsts` — Option D is orthogonal to the naming
  question.
- Removes the `pair.swapped()` consuming method, requiring callers to write
  `Pair.swapped(pair)` (or `Pair<F, S>.swapped(pair)` when type inference
  fails). [IMPL-023] permits but doesn't require this — its motivation is
  overload-recursion avoidance, which is a non-issue for Pair (no
  `~Copyable` / `Copyable` overload pair shares a name in the current
  surface; the Copyable-tier methods are explicitly distinct extensions
  per `Pair.swift:115-148`).
- A no-op for the ergonomic question: `Pair.swapped(pair)` is strictly more
  verbose than `pair.swapped()` and offers no compile-time or
  call-site-clarity benefit.

**Verdict**: REJECTED. [IMPL-023]'s value is overload-recursion avoidance,
which Pair doesn't experience (the two extensions don't share method names).
The static-method-only style without [API-NAME-002] cleanup leaves the core
problem unsolved. Option C is strictly superior.

### Comparison

| Criterion | A (Property.View) | B (Hybrid) | C (Labeled methods) | D (Static-only) |
|-----------|-------------------|------------|---------------------|-----------------|
| [API-NAME-002] strict compliance | ✓ (avoids compounds) | ✓ | ✓ | ✗ (compounds remain) |
| [API-NAME-008] correct shape | ✗ (single-form forced into multi-form ceremony) | ✗ (`swap` single-form ceremony) | ✓ (single-form labeled) | n/a (orthogonal) |
| Two-generic-parameter constraint | ✗ (disqualifies; case-study migration failure precedent) | ✗ (same) | ✓ (no Property pattern adoption) | ✓ (no Property pattern adoption) |
| Type-changing-transformation fit | ✗ (`_modify` cannot return new type) | ✗ (same; pushed to top-level) | ✓ (statics return `Pair<NewFirst, Second>` naturally) | ✓ (same) |
| Migration cost (per consumer survey) | High (rewrite + dep) | Medium-high | Low (tests + README only) | Low (tests + README only) |
| New external dependency | Yes (3 transitive: property-, tagged-, ownership-) | Yes (same) | None | None |
| Compiler stability (Swift 6.3.1) | Property.View is `~Copyable` only post-2026-03-22 (`property-view-escapable-removal.md`); CopyPropagation false-positive history; no demonstrated benefit for Pair | Same | No new compiler surface | No new compiler surface |
| [RES-018] (don't add infra ahead of demand) | ✗ (zero consumer demand for fluent surface) | ✗ | ✓ | ✓ |
| [API-NAME-002] new-rename trigger ([API-NAME-007]) | n/a | n/a | Triggered & resolved | Not triggered (no rename) |

Option C wins on every active criterion and is structurally required by
two independent constraints (two-generic-parameter, type-changing
transformations).

### Type-Changing Transformation Analysis

This is the hardest of the supervisor's questions and the load-bearing
disqualifier for Options A and B.

**Setup**: `pair.map.first { ... }` (the imagined Property.View shape) reads
as "modify the first component in place via a Property.Inout namespace."
But the actual operation is type-changing: `pair: Pair<First, Second>`
becomes `Pair<NewFirst, Second>`. The new pair is a *different type*, with
different generic args.

**Property.View / Property.Inout mechanics** (sourced from
`Property Inout Primitives/Property.Inout.swift:5-118`,
`Property Primitives Core/Property.swift:46-79`):

1. `Property.Inout` is `~Copyable, ~Escapable`, wraps a tagged
   `Ownership.Inout<Base>` exclusive borrow (`Property.Inout.swift:66-67`).
2. The accessor pattern is `mutating _read { yield .init(&self) }` and
   `mutating _modify { var v = ...(&self); yield &v }` — the yielded view
   borrows `self` for its lifetime.
3. `base.value` (the inner `Ownership.Inout<Base>.value`) yields `inout Base`
   — the SAME type as the wrapper's `Base` parameter. Mutation flows
   through `nonmutating _modify` on `Ownership.Inout`.
4. The Property.View access model is **in-place modification of the SAME
   base type**. There is no API in any of the five Property variants for
   "consume self and produce a new wrapper over a different base type."
5. Confirmed by reading `Property Inout Primitives/Property.Inout.swift:121-132`:
   `var base: Ownership.Inout<Base>` is a `_read`-only accessor; no setter
   that would accept a different `Base`.

**Why this disqualifies the type-changing maps**:

```swift
// Imagined shape:
extension Property.Inout
where Tag == Pair<F, S>.Map, Base == Pair<F, S>,
      F: ~Copyable, S: ~Copyable {
    mutating func first<NewFirst: ~Copyable>(
        _ transform: (consuming F) -> NewFirst
    ) -> Pair<NewFirst, S> {
        // base.value is Ownership.Inout<Pair<F, S>> — its `value` is
        // `inout Pair<F, S>`. We have an exclusive mutable reference to
        // a Pair<F, S>. There is no way to:
        //   (a) replace it with a Pair<NewFirst, S> (different type), OR
        //   (b) consume the F component and produce a new pair from
        //       within an _modify scope without violating exclusivity.
        // The closest we can do is consume self entirely — but then
        // we're not in a Property.Inout method, we're back to a
        // Pair-level consuming method. The Property.Inout layer adds
        // only ceremony.
    }
}
```

The semantic gap is fundamental. Property.View is built on `_modify`
coroutines that yield `inout`. `inout` requires the writeback type-match
the readout. Type-changing maps require type-mismatch. There is no
mechanism in the Swift type system that makes these compose.

**Prior art on type-changing operations under accessor namespaces**:

A targeted grep across `swift-property-primitives` and `swift-buffer-primitives`
(2026-05-08) for Property.Inout / Property.View extensions returning a
different type than `Base` finds **zero examples**. Every Property.View
extension returns either `Void`, `Element?`, an Element-of-Base, an
Index-of-Base, or another non-`Base`-shaped scalar — never a transformed
container of a different generic instantiation.

This is not coincidence: the access model fundamentally precludes it.

**The static-method alternative is the canonical answer**:

```swift
public static func map<NewFirst: ~Copyable, E: Swift.Error>(
    _ pair: consuming Pair,
    first transform: (consuming First) throws(E) -> NewFirst
) throws(E) -> Pair<NewFirst, Second>
```

Statics consume the input pair and return the new-type output. There is
no `_modify` coroutine in flight. The type system is happy. The Copyable
tier wraps with `pair.map(first: { ... })` (an instance method that
calls `Self.map(self, first:)` via [IMPL-023]).

**The supervisor's framing was correct**:

> *"Type-changing transformations don't fit Property.View's _modify pattern
> — `_modify` yields a mutable reference; it can't change the type. So
> `map.first` returning `Pair<NewFirst, Second>` means it's NOT a
> Property.View `_modify` — it's a consuming method on the View, or on
> the type directly."*

The view-route requires the consuming method to live as
`extension Property.Inout where ... { consuming func first ... }`. But
`Property.Inout` is `~Escapable` — its lifetime is bound to the borrow
of `self`. A consuming method on a `~Escapable` view that returns a
fresh `Pair<NewFirst, Second>` requires the borrow to outlive the
returned pair, which contradicts `~Escapable`. The view route is
mechanically blocked.

This leaves "or on the type directly" as the only viable route: top-level
labeled methods on `Pair` itself, which is Option C.

**Property.Consume alternative**: `Property.Consume<Element>` is a
state-tracked consume variant (`Property Consume Primitives/Property.Consume.swift:61-129`).
It supports `borrow()` / `consume()` and can hand out `Base` for
arbitrary use. **But**:
- Property.Consume requires `Base: Copyable` (line 3:
  `extension Property where Base: Copyable`). Pair's `~Copyable` tier is
  excluded by construction.
- For the `Copyable` tier, Property.Consume's value-add over a plain
  consuming method is the `borrow()` / `consume()` / `restore()` state
  machine that lets a single accessor expose both read-only and consuming
  paths (`container.forEach { ... }` vs `container.forEach.consuming { ... }`).
  Pair's transformation methods are unconditionally consuming on the
  `~Copyable` tier and unconditionally non-consuming on the `Copyable`
  tier; there is no mode-switching demand.

Property.Consume is not the right tool for type-changing pair transforms.

### Outcome resolution of the 12 supervisor questions

| # | Question | Answer (post-analysis) |
|---|----------|----------------------|
| 1 | `map.first` / `map.second` shape — Property.View vs labeled? | **Labeled** — type-changing semantics force out of Property.View; multi-form-vs-single-form yields *labeled overloads* with `first:` / `second:` arg labels, not a Property.View namespace. |
| 2 | `bimap` shape | Collapse into the same `map` overload set: `map(first:second:)`. The bifunctor name is removed; the operation is just "`map` with both labels supplied." |
| 3 | `apply` shape | Stays as consuming labeled method `apply(_:)`. Single-form (one operation). [API-NAME-008] gives labeled-method form. |
| 4 | `swapped` / `swap` shape | Stays as consuming labeled method `swapped()`. Single-form, isomorphic to the `swap(at:with:)` origin example. No `swap.in_place` namespace; no consumer demand ([RES-018]). The static `swapped(_:)` is removed (instance form covers both tiers). |
| 5 | Tuple conversion | Unchanged: `init(_ tuple: (First, Second))` and `var tuple: (First, Second)`. Both are single-form, [API-NAME-002]-clean. |
| 6 | `allFirsts` | Remove. Replace with a *namespace* projection: `Pair<First, Second>.First.allCases` is *already available* via `First.allCases` whenever `First: CaseIterable` — the existing static is a thin re-export with a compound name. [API-NAME-002] strict reading flags `allFirsts`; the static is redundant. The right path is to delete it entirely; consumers write `First.allCases` directly. |
| 7 | ~Copyable tier complexity for `pair.map.first` | Mooted by §Type-Changing Transformation Analysis — the .map.first shape is mechanically blocked. No complexity to engineer. |
| 8 | `_modify` cannot change type — confirmed | §Type-Changing Transformation Analysis verifies this in detail and rules out Property.View. |
| 9 | Property.Consume route | Rejected — `Base: Copyable` constraint excludes Pair's `~Copyable` tier; no value-add for Pair's consuming-only transforms. |
| 10 | Inferred `<New>` from closure | All `map` overloads use a fresh generic param inferred from the transform closure. Standard practice. |
| 11 | `zip` / `unzip` symmetry | DEFER. No consumer demand surfaces in the consumer survey; [RES-018] requires waiting for a real demand before adding the surface. Reconsider when an algebra/symmetry/region/finite consumer asks. |
| 12 | `fst` / `snd` shorthand | Reject. Stored properties are already `first` / `second` per Swift API Design Guidelines. No change. Note in §Open Questions that some functional-style consumers might prefer shorthand; defer until a demand surfaces. |

## Outcome

**Status**: DECISION (implemented 2026-05-08 in `Sources/Pair Primitives/Pair.swift`)

**Chosen option**: **Option C** — minimal-change labeled-method renames
without Property.View adoption.

### Concrete proposed API surface

#### `~Copyable` tier (static core + consuming instance methods)

```swift
@frozen
public struct Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable {
    public var first: First
    public var second: Second
    public init(_ first: consuming First, _ second: consuming Second)
}

// Conditional conformances unchanged
extension Pair: Copyable where First: Copyable, Second: Copyable {}
extension Pair: Sendable where First: Sendable & ~Copyable, Second: Sendable & ~Copyable {}
#if compiler(>=6.4)
extension Pair: Equatable where First: Equatable & ~Copyable, Second: Equatable & ~Copyable {}
extension Pair: Hashable where First: Hashable & ~Copyable, Second: Hashable & ~Copyable {}
#else
extension Pair: Equatable where First: Equatable, Second: Equatable {}
extension Pair: Hashable where First: Hashable, Second: Hashable {}
#endif
#if !hasFeature(Embedded)
extension Pair: Codable where First: Codable, Second: Codable {}
#endif

// MARK: ~Copyable transformation core

extension Pair where First: ~Copyable, Second: ~Copyable {
    /// Transforms the second component, preserving the first.
    public static func map<NewSecond: ~Copyable, E: Swift.Error>(
        _ pair: consuming Pair,
        second transform: (consuming Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<First, NewSecond>

    /// Transforms the first component, preserving the second.
    public static func map<NewFirst: ~Copyable, E: Swift.Error>(
        _ pair: consuming Pair,
        first transform: (consuming First) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Second>

    /// Transforms both components.
    public static func map<NewFirst: ~Copyable, NewSecond: ~Copyable, E: Swift.Error>(
        _ pair: consuming Pair,
        first firstTransform: (consuming First) throws(E) -> NewFirst,
        second secondTransform: (consuming Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<NewFirst, NewSecond>

    /// Folds both components into a single result.
    public consuming func apply<R: ~Copyable, E: Swift.Error>(
        _ body: (consuming First, consuming Second) throws(E) -> R
    ) throws(E) -> R

    /// Returns the pair with components swapped.
    public consuming func swapped() -> Pair<Second, First>
}
```

#### `Copyable` tier (instance facade, delegates to static core)

```swift
extension Pair where First: Copyable, Second: Copyable {
    /// Transforms the second component, preserving the first.
    public func map<NewSecond, E: Swift.Error>(
        second transform: (Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<First, NewSecond>

    /// Transforms the first component, preserving the second.
    public func map<NewFirst, E: Swift.Error>(
        first transform: (First) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Second>

    /// Transforms both components.
    public func map<NewFirst, NewSecond, E: Swift.Error>(
        first firstTransform: (First) throws(E) -> NewFirst,
        second secondTransform: (Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<NewFirst, NewSecond>

    /// Creates a pair from a tuple.
    public init(_ tuple: (First, Second))

    /// Returns the pair as a tuple.
    public var tuple: (First, Second)
}
```

#### Surface dropped (no replacement needed)

- `Pair.allFirsts` — redundant with `First.allCases` when `First: CaseIterable`.
- `Pair.swapped(_:)` static — covered by the consuming instance method, which
  is already available on the `~Copyable` tier (see [IMPL-023] note below).

#### [IMPL-023] note

The current code already has the Copyable instance facade calling the static core (`Pair.swift:115-148`). The recommendation preserves that delegation pattern for the three `map` overloads (each instance method calls `Self.map(self, ...)`). The `~Copyable` tier needs no instance/static distinction for `map` — only the static is used; consumers call `Pair<F, S>.map(pair, first: ...)`. (For `swapped` and `apply`, the consuming-instance form is sufficient and idiomatic; no static is required, since [IMPL-023]'s overload-recursion problem doesn't exist here — Copyable and ~Copyable instance methods exist in disjoint extensions with no shared name.)

### Migration table — current to proposed

| Current | Proposed | Migration |
|---------|----------|-----------|
| `Pair.map(pair, transform: f)` (static, ~Copyable tier) | `Pair.map(pair, second: f)` | Add `second:` label |
| `Pair.mapFirst(pair, transform: f)` | `Pair.map(pair, first: f)` | Rename `mapFirst` → `map`, change `transform:` → `first:` |
| `Pair.bimap(pair, first: f, second: g)` | `Pair.map(pair, first: f, second: g)` | Rename `bimap` → `map` |
| `pair.map { ... }` (instance, Copyable tier) | `pair.map(second: { ... })` | Add `second:` label, can no longer use trailing closure for the unlabeled form |
| `pair.mapSecond { ... }` | `pair.map(second: { ... })` | Rename, then same as above |
| `pair.mapFirst { ... }` | `pair.map(first: { ... })` | Rename, add label |
| `pair.bimap(first: f, second: g)` | `pair.map(first: f, second: g)` | Rename `bimap` → `map` |
| `pair.swapped()` (instance, ~Copyable consuming) | `pair.swapped()` | Unchanged |
| `Pair.swapped(pair)` (static) | `pair.swapped()` | Use instance form |
| `Pair.allFirsts` | `First.allCases` (where `First: CaseIterable`) | Direct call; the static was a thin re-export |
| `pair.tuple` / `Pair(tuple)` | unchanged | — |
| `pair.apply { ... }` | unchanged | — |

### Migration cost (per [RES-022])

- Production code: **0 sites** affected (consumer survey: no consumer calls
  any transformation method).
- In-package tests: ~10 sites in `Pair Tests.swift:46-145, 226-269` to be
  rewritten. Estimated 30 line edits.
- README example: 4 lines (`README.md:22, 38-46`).
- Total scope: 2 files, ~35 line edits, single commit.

This is a remarkably low-cost rename for a public-API breaking change.
The recommendation is bounded by structural correctness ([API-NAME-002]
strict, two-generic-parameter, type-changing-transformation), not by
diff-size — but in this case structural correctness and minimal diff
align cleanly.

### Open questions (deferred sub-questions)

1. **`Pair.first` static namespace shape**: should `First.allCases` access
   be available as `Pair.first.cases` via a static namespace? The proposed
   resolution is "no — direct call" because the existing `allFirsts`
   is a thin re-export. Reconsider only if multi-form sub-operations
   surface (`Pair.first.{cases, count, indices}` etc.). Today: single sub-form
   → labeled call → no namespace.
2. **`zip` / `unzip` companion methods**: deferred per [RES-018] — no consumer
   demand.
3. **`fst` / `snd` shorthand**: deferred per Swift API Design Guidelines —
   `first` / `second` are the canonical Swift names for this operation.
4. **Should `pair.map(second: ...)` also expose an unlabeled form for the
   most common Haskell-style "map second" idiom?** The proposed answer is
   "no — force the label" (per the [API-NAME-008] / [API-NAME-002] strict
   reading). A future reflection could revisit if the in-package test
   ergonomics complain.
5. **Does Pair want a `Property<Tag, Pair<First, Second>>` typealias for
   *future* consumer-side fluent extensions** (e.g., a downstream package
   that wants `myPair.normalize.range()` for domain-specific operations)?
   The proposed answer is "yes — but as a downstream-extension entry point,
   not a Pair-owned namespace." Pair itself doesn't ship the typealias;
   consumers add it locally if they want fluent surfaces over a specific
   `Pair<F, S>` instantiation. This avoids the dependency-cost concern
   while preserving extensibility. Defer formal codification until a
   downstream package asks.
6. **Embedded support**: the Codable conformance is gated `#if !hasFeature(Embedded)`.
   The proposed surface preserves this gate. No change needed.

### Recommendation framing per [RES-022]

The recommendation prioritizes structural correctness:
- [API-NAME-002] strict reading — Option D fails this; A/B/C all pass.
- [API-NAME-008] correct shape — Option A and B fail this (multi-form
  ceremony around single-form operations); C passes.
- Two-generic-parameter constraint — Options A and B mechanically blocked;
  C and D pass.
- Type-changing-transformation constraint — A and B mechanically blocked;
  C and D pass.

Diff-size is a *tiebreaker only*. C and D are tied on structural correctness
for the type-changing constraint, but D fails [API-NAME-002] strict, leaving
C alone.

## References

### Skill rules
- [API-NAME-001] Nest.Name pattern — `code-surface/SKILL.md:34-58` [Verified: 2026-05-08]
- [API-NAME-002] No compound identifiers — `code-surface/SKILL.md:105-150` [Verified: 2026-05-08]
- [API-NAME-005] Pre-rename mechanical check — `code-surface/SKILL.md:797-810` [Verified: 2026-05-08]
- [API-NAME-007] Convention-known-convention-unapplied heuristic — `code-surface/SKILL.md:814-841` [Verified: 2026-05-08]
- [API-NAME-008] Property.View vs labeled method decision rule — `code-surface/SKILL.md:844-882` [Verified: 2026-05-08]
- [API-IMPL-005] One type per file — `code-surface/SKILL.md:320-342` [Verified: 2026-05-08]
- [API-IMPL-008] Minimal type body — `code-surface/SKILL.md:401-463` [Verified: 2026-05-08]
- [API-IMPL-012] Closure parameters trail signature — `code-surface/SKILL.md:594-622` [Verified: 2026-05-08]
- [API-IMPL-013] Multiple closures lifecycle order — `code-surface/SKILL.md:626-663` [Verified: 2026-05-08]
- [API-IMPL-014] Configuration parameter placement — `code-surface/SKILL.md:667-718` [Verified: 2026-05-08]
- [API-ERR-001] Typed throws — `code-surface/SKILL.md:230-244` [Verified: 2026-05-08]
- [IMPL-020] Verb-as-property with callAsFunction — `implementation/accessors.md:13-26` [Verified: 2026-05-08]
- [IMPL-021] Property vs Property.View — `implementation/accessors.md:30-42` [Verified: 2026-05-08]
- [IMPL-022] _read + _modify for mutating accessors — `implementation/accessors.md:46-58` [Verified: 2026-05-08]
- [IMPL-023] Core logic in static methods — `implementation/accessors.md:120-132` [Verified: 2026-05-08]
- [IMPL-024] Compound identifiers in static layer — `implementation/accessors.md:136-145` [Verified: 2026-05-08]
- [IMPL-025] Two-tier overload resolution — `implementation/accessors.md:149-153` [Verified: 2026-05-08]
- [IMPL-079] Property.View terminal ~Escapable layer — `implementation/accessors.md:90-98` [Verified: 2026-05-08]
- [RES-005] Analysis methodology — `research-process/SKILL.md:306` [Verified: 2026-05-08]
- [RES-013a] Synthesis verification — `research-process/SKILL.md:522` [Verified: 2026-05-08]
- [RES-018] Premature primitive (cited via prior art) — referenced in `binary-primitives-package-decomposition.md` [Verified: 2026-05-08]
- [RES-019] Step-0 internal research grep — `research-process/SKILL.md:615` [Verified: 2026-05-08]
- [RES-022] Recommendation-section framing heuristic — `research-process/SKILL.md:708` [Verified: 2026-05-08]
- [RES-023] Empirical-claim verification — `research-process/SKILL.md:754` [Verified: 2026-05-08]
- [RES-026] Citations — `research-process/SKILL.md:481` [Verified: 2026-05-08]

### Source files (current state)
- `swift-pair-primitives/Sources/Pair Primitives/Pair.swift` (entire file, lines 1-186) [Verified: 2026-05-08]
- `swift-pair-primitives/Tests/Pair Primitives Tests/Pair Tests.swift` (lines 46-269) [Verified: 2026-05-08]
- `swift-pair-primitives/README.md` (lines 22, 38-46) [Verified: 2026-05-08]
- `swift-pair-primitives/Package.swift` (line 20: `dependencies: []`) [Verified: 2026-05-08]
- `swift-property-primitives/Sources/Property Primitives Core/Property.swift:46-79` (Property base) [Verified: 2026-05-08]
- `swift-property-primitives/Sources/Property Typed Primitives/Property.Typed.swift:38-78` (Typed variant — single-Element generic only) [Verified: 2026-05-08]
- `swift-property-primitives/Sources/Property Inout Primitives/Property.Inout.swift:5-132` (Inout — `~Escapable`, type-locked Base) [Verified: 2026-05-08]
- `swift-property-primitives/Sources/Property Borrow Primitives/Property.Borrow.swift:5-82` (Borrow — read-only) [Verified: 2026-05-08]
- `swift-property-primitives/Sources/Property Consume Primitives/Property.Consume.swift:3-157` (Consume — `Base: Copyable` only) [Verified: 2026-05-08]
- `swift-property-primitives/Tests/Support/{Container,Box,Slice,Slice.Inline}.swift` (adoption-pattern verification) [Verified: 2026-05-08]
- `swift-property-primitives/Tests/Tutorial/Getting Started Final Step Tests.swift` (Stack canonical Quick Start; introduces `<E>` via method generic) [Verified: 2026-05-08]

### Prior research (internal)
- `swift-property-primitives/Research/case-study-dictionary-primitives-migration-failure.md` (DECISION 2026-01-21) — disqualifies Property.Typed for two-generic-parameter base types [Verified: 2026-05-08]
- `swift-property-primitives/Research/property-tagged-semantic-roles.md` (RECOMMENDATION 2026-04-23) — Tagged vs Property semantic taxonomy [Verified: 2026-05-08]
- `swift-property-primitives/Research/property-view-escapable-removal.md` (DECISION 2026-03-22) — Property.View `~Copyable`-only, no `~Escapable` [Verified: 2026-05-08]
- `swift-institute/Research/binary-primitives-package-decomposition.md` — worked example of [API-NAME-008] applied to a sibling package [Verified: 2026-05-08]
- `swift-institute/Research/binary-base-n-encoding-family-architecture.md` — canonical multi-form Property.View example [Verified: 2026-05-08]
- `swift-institute/Research/Reflections/2026-04-24-post-hoc-api-name-compliance-swap-rename.md` — origin of [API-NAME-008]; `swap` single-form precedent [Verified: 2026-05-08]
- `swift-institute/Research/skill-verification-taxonomy-pilot.md` — confirms [API-NAME-008] is a semantic judgment rule [Verified: 2026-05-08]

### Consumer-package empirical evidence
- `swift-symmetry-primitives/Sources/Symmetry Primitives/Rotation.Phase.swift:59` [Verified: 2026-05-08]
- `swift-algebra-primitives/Sources/Algebra Primitives Core/{Monotonicity,Sign,Ternary,Polarity,Parity}.swift` [Verified: 2026-05-08]
- `swift-finite-primitives/Sources/Finite Primitives*/{Comparison+Finite,Gradient,Bound,Endpoint,Boundary}.swift` [Verified: 2026-05-08]
- `swift-region-primitives/Sources/Region Primitives/{Clock,Edge,Sextant,Octant,Cardinal,Corner,Quadrant}.swift` [Verified: 2026-05-08]
- `swift-algebra-primitives/Tests/Algebra Primitives Tests/Algebra Smoke Tests.swift:22, 29` (only test-site Pair construction) [Verified: 2026-05-08]
