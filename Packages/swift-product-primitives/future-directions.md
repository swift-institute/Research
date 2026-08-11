# Forward Directions: `swift-product-primitives`

<!--
---
version: 1.0.0
last_updated: 2026-05-10
status: RECOMMENDATION
tier: 2
scope: cross-package
peer_docs:
  - academic-and-ecosystem-survey.md
  - api-design-leveraging-property-primitives.md
  - escapable-blocked.md
trigger: 0.1.0 release tomorrow; consolidate forward-looking research that is *additive* to the shipping surface — does not block release.
---
-->

## Context

`swift-product-primitives` ships `Product<each Element>` 0.1.0 alongside
`swift-pair-primitives` and `swift-either-primitives`. The 0.1.0 surface is
firm: storage `var values: (repeat each Element)`, `init(repeat each Element)`,
`@dynamicMemberLookup`, conditional `Sendable`/`Equatable`/`Hashable`/
`Comparable`/`CustomStringConvertible`/`Codable`/`Swift.Error`, an n-ary
`map` (consuming, typed-throws), `append`/`prepend`, binary `zip`, `fold`
(catamorphism), arity-2 `swapped` free function, and the institute
`Equation.Protocol`/`Comparison.Protocol`/`Hash.Protocol` witnesses.

Three peer documents already settle the *baseline*:

* `academic-and-ecosystem-survey.md` (v1.0.0) — 50+ primary sources covering
  category theory, languages (Haskell/OCaml/Rust/Scala 3/F#/Idris/TS),
  stdlib, SE proposals, and 6.4-dev compiler work. **All citations there are
  verified 2026-05-08; this document does not re-verify them and instead
  cites by section reference (Q-codes).**
* `api-design-leveraging-property-primitives.md` (v1.0.0) — settles the
  *call-site shape* (consuming instance + static delegate, n-ary closures,
  no `bimap`).
* `escapable-blocked.md` (v1.0.0) — closes the `~Escapable`/`~Copyable` arm
  question for the foreseeable future: blocked on three upstream pack-syntax
  features, no SE proposal in flight.

This document is the **forward-directions** axis. It does not propose any
0.1.0-blocking change. It enumerates discrete, additive candidate directions
and assigns each a verdict (ADOPT / DEFER / REJECT) with one-paragraph
rationale, so that post-0.1.0 work has a concrete decision record to cite
rather than re-deriving from prior art each cycle.

**Scope**: cross-package — most candidates apply equally to Pair (binary
specialisation) and a few (associativity, distributivity with Either) span
all three primitives.

## Question

For each candidate forward direction — split across two angles:

1. **Type-theory totality** (n-ary closure of the categorical product:
   permute/transpose, associativity flatten, distributivity with sum types,
   labeled vs positional records, sigma-shaped extensions, applicative/
   monoidal layer, hetero-list interop), and
2. **Swift-Evolution forward-pass** (in-flight features that change what
   `Product` *can* express: parameter-pack progression, noncopyable packs,
   `BitwiseCopyable`-when-all-elements, `~Escapable` propagation, isolated
   conformances, `@_rawLayout`, Span-of-products / SoA, lifetime
   annotations) —

what should `swift-product-primitives` **adopt**, **defer**, or **explicitly
reject**?

The central question subordinate to all candidates: **what is `Product`'s
durable identity once the Swift stdlib has user-defined tuple conformances
(SE-0283 revival) and noncopyable parameter packs?** Is `Product` (a) a
richer-API wrapper over `(each T)`, (b) a different semantic type, or
(c) absorbed by stdlib eventually?

## Analysis

### Conventions for this section

Each candidate is presented as:

* **What it is** — concrete API sketch or one-line theoretical position.
* **Prior art** — pointer (Q-code into `academic-and-ecosystem-survey.md`,
  or external link with `[Verified: 2026-05-10]` for *new* claims this
  document introduces).
* **Contextualization** — what it costs in *this* package, given Swift's
  constraints and the existing 0.1.0 surface; explicitly checks whether
  Swift tuples or parameter-pack expansion already cover the use case.
* **Verdict** — ADOPT / DEFER / REJECT, with rationale.

`[RES-021]` discipline is enforced throughout: "universal adoption
elsewhere" is not "universal necessity here."

`[RES-018]` discipline is enforced for any candidate that proposes a *new
ecosystem package* (e.g., HList-primitives): the second-consumer + the
"composition fails without it" check apply. During pre-1.0 development,
`feedback_correctness_sole_driver_during_development` permits primitive
existence on correctness/totality grounds without consumer hurdles, but
candidates here are post-0.1.0 forward-looking; if a candidate's only
beneficiary is a hypothetical future consumer, the verdict bias is DEFER.

---

### Candidate A — Permutation / general arity rearrangement

**What it is.** A family of methods that permute a Product's pack:

```swift
// Strawman
extension Product {
    consuming func transposed() -> Product<repeat each Reversed>  // unspellable
    consuming func rotated() -> /* one-position rotate */
    consuming func dropping<I>(_: I) -> /* arity n-1 */
}
```

**Prior art.** Haskell `Data.Tuple` carries only `swap` (binary). Scala 3's
`Tuple.Concat` and `Tuple.Drop` are *type-level match-types*; the only
language to express n-ary permutation as type-level computation
(`academic-and-ecosystem-survey.md` Q2.d). `frunk::HList` exposes
`pluck`/`sculpt` (Q2.c). HList-style heterogeneous-list libraries
(`Data.Vinyl`, `generics-sop`) treat permutation as a primary operation.

**Contextualization.** The blocker is fundamental: SE-0398 limits a generic
type to **one** type parameter pack. A method signature like
`func transposed<each Reversed>() -> Product<repeat each Reversed>`
where `Reversed` is "the reverse of `Element`" requires *type-level
computation on packs* — Swift has no equivalent of Scala 3's match-types.
The compiler cannot derive the reversed pack from the input pack; the user
would have to spell out the result type at the call site, defeating the
purpose. Even single-position rotation runs into the same wall: there is
no way to spell "the pack with first element moved to last."

A weaker form — *positional* permutation by tuple-key-path
(`product.permuted(\.values.2, \.values.0, \.values.1)`) — runs into a
similar wall: the result-pack arity and order must be *statically known*
in the signature.

**Verdict — REJECT (as Product API).** Pack-level permutation is genuinely
unspellable in Swift today and has no in-flight SE proposal. Document as a
principled absence (mirror `escapable-blocked.md` shape). Re-evaluate only
if Swift gains type-level pack pattern-matching (no signal as of
2026-05-10). Users who need reverse/rotate on a fixed arity should use
`Pair.swapped` (binary) or explicit tuple destructure-reconstruct.

---

### Candidate B — Associativity flatten / unflatten (`Product<Product<A,B>,C>` ↔ `Product<A,B,C>`)

**What it is.** Categorical associator: products are associative up to
isomorphism. APIs to witness the iso:

```swift
extension Product {
    consuming func flattened() -> /* one-level un-nest */
    consuming func nested<P: Int>(_ p: P) -> /* group at position p */
}
```

**Prior art.** Scala 3 `Tuple.Concat` (Q2.d) handles flatten at the
type-level. Lean / Idris encode tuples as nested binary pairs natively
(Q2.f) — the iso is the identity. nLab `associator` (categorical setting)
treats associativity as a coherent natural isomorphism, not a constructive
operation.

**Contextualization.** Same wall as Candidate A: spelling `Product<A, B>`
unwrapped to `Product<A, B, C>` from inside a generic over `each Element`
requires type-level pack-of-pack manipulation. The current package already
provides the *additive* form of associator via `append`/`prepend`/`zip`
(Q2 of peer doc) — these grow/shrink arity by exactly one or pair-wise.

The *only* point at which flatten is locally spellable is a fixed-arity
free function:

```swift
public func flattened<A, B, C>(
    _ p: consuming Product<Product<A, B>, C>
) -> Product<A, B, C> {
    let outer = (consume p).values
    let inner = (consume outer.0).values
    return Product(inner.0, inner.1, outer.1)
}
```

This is `swapped`'s pattern (Q2 peer doc) extended to associativity. It
works, but it's per-arity boilerplate identical to the Scala 22-wall and
Rust 12-wall regrets (Q2.c, Q2.d). Shipping a tower of
`flattened<A,B,C,D>` / `flattened<A,B,C,D,E>` recreates exactly the design
regret the survey identifies.

**Verdict — REJECT.** No general form is spellable; per-arity towers are a
documented design regret. If a future Swift gains type-level pack
match-types, revisit. Until then: nested products are a user-side concern;
the `fold` API (existing) lets the consumer destructure to plain values
and reconstruct without involving Product's machinery.

---

### Candidate C — Distributivity with `Either` (`Product<A, Either<B, C>>` ↔ `Either<Product<A, B>, Product<A, C>>`)

**What it is.** The categorical distributive law `A × (B + C) ≅ (A × B) + (A × C)`,
exposed as a free function spanning `swift-product-primitives` and
`swift-either-primitives`.

**Prior art.** Standard category-theory result; nLab `distributive
category`. Implemented in Haskell as `distribute`/`undistribute` over
`(a, Either b c)`. PureScript `Data.Distributive`. Not a stdlib feature
in any mainstream imperative language.

**Contextualization.** Concretely spellable today (no pack issues, since
the binary case is just plain generics):

```swift
// Sketch — would live where, exactly?
public func distributed<A, B, C>(
    _ p: consuming Product<A, Either<B, C>>
) -> Either<Product<A, B>, Product<A, C>> {
    let (a, e) = (consume p).values
    switch consume e {
    case .left(let b):  return .left(Product(a, b))
    case .right(let c): return .right(Product(a, c))
    }
}
```

The cost question is **placement**, not feasibility. Three options:

1. **In `swift-product-primitives`** — adds a dep on `swift-either-primitives`
   (currently no such dep), inverting the natural import direction (Either
   is the dual; both packages live at the same tier).
2. **In `swift-either-primitives`** — adds a dep on `swift-product-primitives`
   (currently no such dep). Symmetric problem.
3. **In a new `swift-product-either-distributive-primitives` (or
   simpler, an Integration target on one side)** — gives the dep direction
   a single home.

`[RES-018]` check: is there a *concrete* second consumer that needs this
operation today? No. Is there a composition that *fails* without it? No;
consumers can hand-roll the switch. The function is mathematically
canonical but operationally trivial — five lines at the call site.

**Verdict — DEFER.** Mathematically valid; no current consumer; placement
is genuinely awkward (would create a new cross-package edge). Re-evaluate
when (a) a second consumer surfaces or (b) the cohort grows a shared
Integration package for cross-package laws. Document in
`Documentation.docc/Principled-Absences/` as "available on request; ask
which side wants the dep."

---

### Candidate D — Labeled (record-shaped) Product

**What it is.** A nominal product with labeled components instead of
positional, mirroring PureScript records / OCaml records / TS object
types:

```swift
// Strawman — does NOT compile today
public struct Record<each Label: StaticString, each Element> {
    public var values: (repeat (each Label, each Element))
}
let r = Record(name: "x", count: 3)
r.name   // String
r.count  // Int
```

**Prior art.** PureScript records (`{ name :: String, count :: Int }`),
TypeScript object types, Haskell `Data.Vinyl` field-tagged records,
GHC `OverloadedRecordDot` extension, Idris named-field records, OCaml
records. Swift itself has labeled tuples (`(name: String, count: Int)`),
which `Product`'s `@dynamicMemberLookup` actually surfaces today via the
underlying tuple keypath.

**Contextualization.** Two walls:

1. **Two parallel packs disallowed.** SE-0398 forbids two type parameter
   packs in the same generic context (Q3.b of peer survey). `<each Label,
   each Element>` is rejected.
2. **`StaticString` cannot parameterise a generic.** Swift has no const
   generics over strings; SE-0309-style integer const generics
   (`InlineArray<5, T>`) are integer-only. The label values would have to
   be runtime-only, defeating the static-typing point.

But — and this is the load-bearing observation — Swift **already** has
labeled tuples *as a structural feature of the underlying tuple type*.
`Product`'s storage `values: (repeat each Element)` does not carry labels,
but a user who wants labels can name their *own* type:

```swift
struct UserRecord {
    var name: String
    var count: Int
}
```

— and pay the cost (no automatic Equatable/Hashable across labels, no
n-ary functor map). Or they can use a labeled tuple directly:
`(name: String, count: Int)` already has structural typing, dot-access by
label, and stdlib `==` up to arity 6.

The "Product but with labels" niche is genuinely unfilled — but the cost
to fill it at the type-system level (two const-generic packs, one of
`StaticString`) is well beyond any reasonable language-evolution horizon.

**Verdict — REJECT (long-term).** Labeled n-ary records are a different
type than `Product`. They are not buildable in current or near-future
Swift. They would not live in `swift-product-primitives` even if buildable
— they would be `swift-record-primitives`. Document as principled absence
with a pointer to "use a custom struct or labeled tuple for label-typed
fields; use Product for positional homogeneous-shape n-ary values."

---

### Candidate E — Anonymous-tuple bridging (zero-friction Product↔tuple)

**What it is.** Cheap, lossless conversion between `Product<each E>` and
`(repeat each E)`:

```swift
extension Product {
    /// Already exists implicitly via `.values`.
    public var tuple: (repeat each Element) { values }
}
public init(tuple: (repeat each Element)) { ... }
public init<each E>(_ tuple: (repeat each E)) where Element == ... // unspellable
```

**Prior art.** Scala 3 `Tuple.fromProduct` / `productElement`; F#
struct-tuples `let (a, b) = struct (1, 2)` (Q2.e). Idris pattern-match on
nested pairs (Q2.f). Haskell tuple syntax is the universal target.

**Contextualization.** Today, `Product(values.0, values.1, ...)` and
`product.values` already cover both directions for *known* arities. The
constructor `init(_:repeat each Element)` *unpacks* component-by-component;
there is no `init(_ tuple: (repeat each Element))` because pack-from-tuple
would need to spread the tuple back into a pack, which `(repeat each
tuple)` does not currently spell (the pack-of-tuple-elements operation is
not exposed as a language form — Q5 of peer survey, "pack-of-pack
unspellable" theme).

For known arity 2 (`Pair`-shaped):

```swift
extension Product where (repeat each Element) == (Element1, Element2) // unspellable today
```

is again rejected by the same-type-on-pack constraint.

The practical workaround that already exists: `Product(t.0, t.1, ...)` at
the call site for any concrete arity. This is *exactly* what `Product`'s
`init` does. The anonymous-tuple bridge is therefore already in place;
the missing piece is a *type-level same-type relation between Product and
tuple*, which is what SE-0283 / TupleConformances is moving toward
externally.

**Verdict — DEFER.** Wait for SE-0283 revival / TupleConformances to land
(Q3.c, Q5.a of peer survey). Once tuples can conform to protocols natively,
the question becomes: should `Product` provide `init(tuple:)` /
`tuple` accessor, or should the user just use the tuple directly? Likely
answer at that point: *neither*. The `.values` accessor already exposes
the tuple; the named form's value comes from being nominal, not from
hiding the tuple.

---

### Candidate F — Applicative / Monoidal `pure` and `<*>` on Product

**What it is.** Lift the n-ary functor surface (`map`, existing) to an
applicative shape with `pure` (constant injection) and `<*>` (apply a
Product of functions to a Product of values):

```swift
extension Product {
    static func pure<T>(_ value: T) -> Product<T>  // arity-1
    consuming func apply<each From, each To>(
        _ functions: consuming Product<repeat (each From) -> each To>
    ) -> Product<repeat each To>
        where /* Element == From, with same-arity */
}
```

**Prior art.** Haskell `Control.Applicative` for tuples
(`(<*>) :: Applicative f => f (a -> b) -> f a -> f b`); Scala cats
`Apply[Tuple2]`; PureScript `Apply` instance for records.

**Contextualization.** The same-type-on-two-packs constraint hits again.
The "Product of functions" Product would need a pack `repeat (each From)
-> each To` matched element-wise to the `each Element` of the input
Product — and Swift has no way to express the constraint that two packs
have the same arity *and* an element-wise relation. SE-0398's one-pack-
per-type rule applies.

Even if buildable, the user value is questionable. The existing `map`
already handles the common case (transform each component with its own
function); `apply` adds the layer of "the functions themselves are
wrapped in a Product," which is structure no current consumer needs and
which the `.values` destructure handles in two lines.

**Verdict — REJECT.** Unspellable with current pack constraints; weak
user-value justification. The nLab/Haskell applicative surface is
mathematically clean but operationally redundant given `map` + `fold`.
Document as principled absence; cross-reference Either's analogous
applicative absence (peer Either survey).

---

### Candidate G — N-ary `mapAt(index:)` / single-position transform

**What it is.** Transform exactly one component, keeping the rest:

```swift
extension Product {
    consuming func mapAt<I, T>(_: I, transform: (Element[I]) -> T) -> Product<...> // unspellable
}
```

**Prior art.** Scala `_1`/`_2` plus `copy`. Haskell `lens` `_1`/`_2`/etc.
with `over`. The peer `api-design-leveraging-property-primitives.md`
explicitly considers and rejects the position-indexed shape (Q2 of peer
doc).

**Contextualization.** Genuinely unspellable: cannot index a pack by a
type-level `Int`, cannot type-replace one slot in a pack while keeping
others. Even with key-path + dynamicMember, the *result type* requires
"replace position i of `each Element` with `T`" — no language
construction exists for that.

**Verdict — REJECT.** Already considered and rejected by peer
api-design doc. Confirm here for forward-direction completeness. The
existing `map` (transform every component, including identity for
unchanged ones) is the only generally-spellable form.

---

### Candidate H — Conditional `BitwiseCopyable` conformance

**What it is.**

```swift
extension Product: BitwiseCopyable where repeat each Element: BitwiseCopyable {}
```

**Prior art.** SE-0426 (Q4 of peer survey, *Verified: 2026-05-08*) auto-
synthesises `BitwiseCopyable` for tuples whose components all conform.
`Product` is a struct wrapping a tuple; the tuple is bitwise-copyable
under the same constraint, but the struct's conditional conformance must
be declared explicitly.

**Contextualization.** This is one of the only candidates with no
language-level blocker. The peer survey explicitly flags this as a
"verify with a short experiment" candidate (Q6, item 1). Adding the
conformance is one line; the Tests target gains a test that
`MemoryLayout<Product<Int, Int>>.size == 16` and that the conformance is
satisfied.

Open question: does Swift 6.3.1 / 6.4-dev synthesise the conformance for
a parameter-pack-backed struct, or does it require the explicit
extension? Empirical verification needed. If synthesis works, this
candidate is a no-op; if not, ship the one-line extension.

The *user-visible value*: enables `UnsafeBufferPointer<Product<Int, Int>>`
copy-by-memcpy, enables `withUnsafeBytes` on `Product` arrays, eligible
for `@_rawLayout` adjacent optimisations. Concrete downstream consumer:
SoA / Span-of-Product use cases (Candidate K).

**Verdict — ADOPT (post-0.1.0 minor bump).** Additive; no breaking
change; one line plus an experiment. Validate on Swift 6.3.1 stable
first; if 6.4-dev synthesises automatically, consider whether the
explicit declaration is still wanted (yes, for ABI-stability and
documentation). Pair-primitives and (where applicable) Either-primitives
should mirror.

---

### Candidate I — Conditional `~Copyable` Equatable / Hashable / Comparable refinements

**What it is.** Once `~Copyable` parameter packs land (status: deferred,
no SE in flight per peer survey Q5.c), thread the suppressed-copy
constraint through:

```swift
extension Product: Equatable
    where repeat each Element: Equatable & ~Copyable  // unspellable today
{ ... }
```

**Prior art.** SE-0499 (Swift 6.4, *Verified: 2026-05-08*, peer Q4) —
`Equatable`/`Comparable`/`Hashable` themselves now refine `~Copyable`/
`~Escapable`. The protocol-side blocker is removed; the only remaining
blocker is pack-level `~Copyable` syntax.

**Contextualization.** Triple-blocked per `escapable-blocked.md`:
(1) `each T: ~Copyable` admittance, (2) `each T: ~Escapable` admittance,
(3) lifetime-annotation propagation. Verdict locked at REJECT-FOR-NOW
in `escapable-blocked.md`.

This document affirms that decision and adds a forward note: when
upstream lands (estimate 12-24 months from 2026-05-10, no public proposal
yet), the migration is mechanical (drop the suppression-blocker
extensions, add `~Copyable` suppressions to the existing institute-witness
extensions, ship a minor bump). The cohort siblings Pair and Either
already admit `~Escapable` arms; Product mechanically catches up at that
point.

**Verdict — DEFER (tracked).** Already decided in `escapable-blocked.md`;
restated here for forward-directions completeness. Tracking pointer:
revisit when all three upstream items in `escapable-blocked.md` § Tracking
land.

---

### Candidate J — `Sendable` conformance refinements

**What it is.** The current 0.1.0 has
`extension Product: Sendable where repeat each Element: Sendable {}`. The
forward-looking refinements:

* Auto-derived `Sendable` once Swift adds parameter-pack-aware Sendable
  synthesis (status: not in flight).
* Region-based isolation (SE-0414) interaction with `consume product`
  across actor boundaries.
* `@Sendable` closure parameters in `map` / `fold` (currently the
  closures inherit the caller's isolation).

**Prior art.** SE-0414 (Region based Isolation), SE-0470 (Isolated
Conformances). Pack-aware Sendable synthesis is in the broader stdlib
roadmap; no specific SE proposal targets Product-shaped types.

**Contextualization.** The conditional Sendable is already correct and
already shipping. The "auto-derived" question is moot — explicit is fine
and matches the rest of the cohort. Region isolation works today via
`consume` semantics on the existing API.

The *one* concrete forward question: should `map` accept a `@Sendable`
closure (or equivalent)? Today it accepts a non-Sendable closure with
typed-throws, which is correct for non-isolated callers. Crossing actors
requires the caller to manage isolation; Product itself is shape-neutral.

**Verdict — REJECT (no change).** The current Sendable surface is
correct; no forward refinement is buildable or desirable today. Revisit
only if a downstream consumer surfaces a concrete cross-actor
isolation case the current API blocks.

---

### Candidate K — Span-of-Product / structure-of-arrays (SoA) story

**What it is.** Whether `Product` enables a structure-of-arrays layout
story when used as the element type of `Span` / `InlineArray` /
`UnsafeBufferPointer`. The dual question: should `Product` have a
*native* SoA mode where `Product<each Element>` is *secretly* stored as
`(repeat [each Element])` instead of `[(repeat each Element)]`?

```swift
// Hypothetical
let aos: Span<Product<Int, String, Bool>> = ...      // Array of Structures
let soa: Product.Span<repeat each Element> = ...     // Structure of Arrays
```

**Prior art.** Game engines (Unity DOTS, Unreal Mass), Rust `soa-derive`
crate, C++ `std::experimental::simd`, Mojo's struct-of-arrays as a
language primitive. Apple's `swift-collections` does not address SoA.
SE-0453 (`InlineArray`) explicitly distinguishes "fixed-size array" from
"tuple" (peer Q4) — the InlineArray is array-shape, Product is record-shape.

**Contextualization.** Two distinct questions:

1. *AoS over Product* — does `Span<Product<Int, String>>` work today?
   Yes, when all elements are `BitwiseCopyable` (Candidate H). `Span`
   provides borrowing access; the consumer indexes into a flat array of
   Product structs. **No new API needed.**
2. *SoA Product Span* — a new container type that stores per-component
   buffers instead of an array of structs. This is a *fundamentally
   different type* than `Product`; it would be a generic `SoA<each
   Element>` or `Vector.SoA<each Element>` living in `swift-buffer-
   primitives` or a new `swift-soa-primitives` package. It is **not** an
   addition to `Product`'s surface — Product is a *single value*; a
   collection-of-Products with SoA layout is a *container*.

`[RES-018]`: a hypothetical SoA primitive needs a second consumer. No
current consumer in any layer. Game-engine-shaped consumers are not in
the institute's near-term roadmap.

**Verdict — REJECT (as Product API addition); DEFER (as separate
package).** The AoS use case works today via Candidate H. The SoA use
case is a different package, blocked on consumer demand. Document the
distinction in `Documentation.docc/Layout-and-Spans.md` (post-0.1.0):
"Product is record-shape; for collections of records, use Span<Product>.
For per-component buffers, see (future) swift-soa-primitives."

---

### Candidate L — `@_rawLayout` for tightly-packed Product

**What it is.** Annotate `Product` (or a sibling type `Product.Packed`)
with `@_rawLayout` to control byte-level packing, eliminate padding, etc.

**Prior art.** Underscored attribute, used in `swift-atomics` (`Atomic<T>`
uses `@_rawLayout(like:)` / `@_rawLayout(size:alignment:)`). Not a
public Swift Evolution feature; underscored / "experimental" indefinitely.

**Contextualization.** `@_rawLayout` requires a concrete layout
specification (size + alignment, or "like" another type). Both fail for
generic-over-packs `Product`: the size depends on the pack instantiation,
which is not knowable at attribute-application site. The attribute
applies to *concrete* types, not to a generic-over-many-shapes type.

A sibling `Product.Packed<each Element>` would face the same wall.

**Verdict — REJECT.** Genuinely unbuildable on a parameter-pack-backed
type. Users with concrete-arity packing needs should use a hand-rolled
struct with `@_rawLayout`; Product cannot express that abstraction
across arities.

---

### Candidate M — Isolated conformances (SE-0470)

**What it is.** Allow conditional conformances where the witness lives on
a specific actor:

```swift
extension Product: Equatable
    where repeat each Element: Equatable, /* isolated to MainActor */
{ ... }
```

**Prior art.** SE-0470 (Isolated Conformances, accepted). The proposal
targets cross-isolation conformance hosting; tuple-shaped types are not
specifically addressed.

**Contextualization.** No current consumer has surfaced an isolated-
conformance use case for Product. The default non-isolated conformance is
correct for all known consumers; isolated conformance would create an
asymmetry the cohort siblings (Pair, Either) do not share.

`InferIsolatedConformances` is enabled in Package.swift (line 65), which
means the *infrastructure* is in place; the *application* to Product
would require a concrete consumer driving the choice.

**Verdict — DEFER.** Infrastructure is ready; no consumer demand. If a
concrete cross-actor consumer surfaces, revisit per-conformance. Mirror
to Pair / Either at that point.

---

### Candidate N — Lifetime-annotated projections (`borrowing each` accessors)

**What it is.** Per-component accessors that *borrow* rather than copy:

```swift
extension Product {
    public borrowing func element<I>(at: I) -> /* &borrow Element[I] */
}
```

**Prior art.** SE-0446 (Nonescapable Types), SE-0427 (Noncopyable
Generics). The `Lifetimes` experimental feature is enabled in
Package.swift (line 63). Rust's pattern: `&self.0`, `&self.1` borrows the
component without consuming the struct.

**Contextualization.** Today's `@dynamicMemberLookup` returns by value
(implicit copy when the element is Copyable, requires consume when
not — and `~Copyable` packs are not buildable per Candidate I). A
borrowing projection would require: pack-aware borrowing key paths,
lifetime-dependence inference through pack expansion, both of which are
upstream-blocked (peer survey Q5.b).

**Verdict — DEFER (tracked with Candidate I).** Same upstream blockers.
Mechanical follow-up once `~Copyable` packs land.

---

### Candidate O — N-ary `unzip` (inverse of binary zip)

**What it is.** Inverse of the existing `zip`:

```swift
extension Product where /* repeat each Element == (each L, each R) */ {
    consuming func unzipped() -> (Product<repeat each L>, Product<repeat each R>)
}
```

**Prior art.** Haskell `unzip :: [(a, b)] -> ([a], [b])`; Scala
`Tuple.unzip` (Scala 3 type-level). The existing `zip` (`Product+Zip.swift`)
takes `Product<each Element>` and `Product<each Other>` to
`Product<repeat (each Element, each Other)>`.

**Contextualization.** The inverse requires constraining the input pack
to *be of tuple shape* — `each Element == (each L, each R)`. SE-0398
prohibits same-type constraints that decompose pack elements into
sub-packs. The constraint `each Element == (some, some)` cannot be
spelled.

For arity-fixed cases:
`func unzipped<A, B, C, D>(_ p: consuming Product<(A, B), (C, D)>) ->
(Product<A, C>, Product<B, D>)` is spellable but per-arity, recreating
the Scala 22-wall regret.

**Verdict — REJECT.** Unspellable in pack form; per-arity towers are a
documented design regret (Q2.c, Q2.d). The existing `zip` is asymmetric;
this is a property of the pack system, not Product.

---

### Candidate P — Sigma-type / dependent-product extension

**What it is.** A dependent product where each component's type may
depend on previous component values:

```swift
struct Sigma<First, Second: First> {  // pseudo-syntax
    var first: First
    var second: Second  // type depends on `first`'s value
}
```

**Prior art.** Idris `(x : a ** p)` (Q2.f); Lean `Sigma`; Agda
`Σ`. Mathematically, `Product` is the special case where the dependency
is trivial (peer Q1.f).

**Contextualization.** Swift has no dependent types. None of the SE
proposals or in-flight compiler work introduces them. The existing
peer survey explicitly says "Swift has no dependent types; `Product
<each E>` is therefore *just* the non-dependent product. The peer doc
need not address dependent products at all" (Q1.f).

**Verdict — REJECT (out of language reach).** Dependent products are not
a Swift-side question. Affirm and move on.

---

### Candidate Q — Tuple-conformance bridge once SE-0283 revival ships

**What it is.** When `(repeat each Element): Equatable` becomes possible
natively (peer Q3.c, Q5.a — `TupleConformances` flag, currently
experimental + off, blocked on `swiftlang/swift#82172`), should `Product`'s
existing institute conformances delegate to the tuple-side conformance,
or remain self-witnessed?

**Prior art.** Vanishing-tuple-conformance machinery in
`lib/AST/ProtocolConformance.cpp:1052-1085` (peer Q3.d). PR #85373
("De-gyb Tuple.swift.gyb", closed-without-merge Nov 2025, peer Q3.b).

**Contextualization.** When tuples natively conform (estimate: 12-24
months, blocked on a SILGen bug), Product has two paths:

1. **Delegate.** Replace the institute-witness extensions with a single
   `extension Product: Equatable where (repeat each Element): Equatable`.
   Trade-off: depends on the stdlib feature; loses control over
   short-circuiting / typed-error semantics.
2. **Maintain own conformances.** Keep the SE-0408 pack-iteration impl
   that ships in 0.1.0. Trade-off: minor duplication with stdlib once
   the stdlib version arrives, but full control over semantics, typed
   throws, and short-circuiting.

`[RES-022]` (structural correctness dominates diff-size): control over
semantics + typed-throws is a real property the stdlib delegate cannot
preserve. The institute-witness pattern (Equation/Comparison/Hash
Protocol) explicitly chose self-witnessed conformances for cross-package
uniformity.

**Verdict — DEFER (with directional preference: maintain own).** Wait
for the stdlib feature to actually ship; at that point, if the stdlib
conformance preserves typed-error and short-circuiting semantics,
delegate; otherwise, maintain. Default expectation is "maintain" because
the stdlib's Equatable shape is `(any Error)`-throwing not
typed-throws-aware.

---

### Candidate R — N-ary curry / uncurry interop

**What it is.** Convert between an n-ary function and a function taking
a Product:

```swift
extension Product {
    static func uncurried<each From, R, E: Swift.Error>(
        _ f: @escaping (repeat each From) throws(E) -> R
    ) -> (Product<repeat each From>) throws(E) -> R
    // and curried inverse
}
```

**Prior art.** Haskell `curry :: ((a, b) -> c) -> a -> b -> c`,
`uncurry :: (a -> b -> c) -> (a, b) -> c` (Q2.a); Scala curries-by-method.

**Contextualization.** The `fold` API (`Product+Fold.swift`) is already
the n-ary uncurry: `product.fold { a, b, c in ... }` *is* the un-curried
form. The `init(repeat each Element)` is the n-ary apply / re-curry.
Adding explicit `curried`/`uncurried` would just rename existing
operations.

**Verdict — REJECT.** The existing `fold` is the uncurry; `init` is the
curry. Renaming them would break 0.1.0 without value. Document the
correspondence in DocC instead.

---

### Candidate S — Heterogeneous-list (HList) interop

**What it is.** A separate `swift-hlist-primitives` package providing
HList-style head/tail/cons operations, with `Product ↔ HList` bridges.

**Prior art.** `frunk::HList` (Rust, Q2.c), `Data.Vinyl` (Haskell),
`generics-sop` (Haskell), HList paper (Kiselyov / Lämmel / Schupke 2004).

**Contextualization.** HLists encode tuples as nested `Cons<H, T>`
structures. Swift parameter packs *are* HLists, expressed as a single
type-level construct. The HList-to-Product bridge would require
converting between nested-binary and flat-pack representations — exactly
the associativity-flatten problem (Candidate B), unspellable.

A separate HList package without the bridge is buildable but redundant
with parameter packs as a representation. The *only* use case where HList
beats packs is when type-level pattern-matching / structural recursion
is needed — and Swift has neither.

`[RES-018]`: zero current consumers; the conceptual gap (HList vs pack)
is filled by SE-0398 + SE-0408 + SE-0399.

**Verdict — REJECT (as separate package); REJECT (as Product API).**
HList is the language Swift would use *if it didn't have* parameter
packs. It does. The redundant primitive should not exist.

---

### Candidate T — Product-of-Product flattening type alias

**What it is.** Type alias for "the flattened pack":

```swift
typealias Flattened<P> = ...  // unspellable; would require type-level recursion
```

**Prior art.** Scala 3 `Tuple.Concat` (type-level), TypeScript variadic
tuple types `[...A, ...B]`.

**Contextualization.** Same wall as Candidate B (associativity flatten):
Swift has no type-level pack pattern-matching. Cannot define a recursive
type-level function over packs.

**Verdict — REJECT.** Subsumed by Candidate B. Listed separately for
forward-directions completeness; absent type-level pack matching,
unbuildable.

---

### Candidate U — N-ary `mapTransform`-by-key-path

**What it is.** Functor surface keyed on key-paths:

```swift
extension Product {
    consuming func map<T>(_ keyPath: KeyPath<(repeat each Element), T>,
                         _ transform: (T) -> T) -> Self
}
```

**Prior art.** Haskell `lens` `set` / `over`; Scala `cats` `Lens`; the
peer api-design doc evaluates and rejects this shape (peer Q2).

**Contextualization.** Already evaluated and rejected in
`api-design-leveraging-property-primitives.md`. Confirmed for
forward-directions completeness. The peer doc's reasoning: key-path-
addressed mutation is at odds with `consuming` semantics, breaks pack
arity preservation, and creates a parallel API surface to the existing
positional `map`.

**Verdict — REJECT.** Already settled by peer doc.

---

### Summary table

| ID | Candidate | Verdict | Reason (one line) |
|---|---|---|---|
| A | Permutation / transpose | REJECT | Unspellable: no type-level pack match |
| B | Associativity flatten | REJECT | Unspellable; per-arity towers = design regret |
| C | Distributivity with Either | DEFER | Buildable, no consumer, awkward placement |
| D | Labeled (record) Product | REJECT | Two parallel packs disallowed; different type |
| E | Anonymous-tuple bridge | DEFER | Wait for SE-0283 revival / TupleConformances |
| F | Applicative `pure`/`<*>` | REJECT | Unspellable + redundant given `map`/`fold` |
| G | `mapAt(index:)` single-position | REJECT | Already rejected by peer api-design |
| H | `BitwiseCopyable` conditional | **ADOPT** | One line; enables AoS Span use cases |
| I | `~Copyable` arms | DEFER | Tracked in `escapable-blocked.md` |
| J | Sendable refinements | REJECT | Current surface correct; no consumer demand |
| K | Span-of-Product / SoA | REJECT/DEFER | AoS works today; SoA = separate package |
| L | `@_rawLayout` packing | REJECT | Generic-over-packs incompatible with attribute |
| M | Isolated conformances (SE-0470) | DEFER | Infra ready; no consumer demand |
| N | Lifetime-annotated borrowing accessors | DEFER | Same upstream blockers as Candidate I |
| O | N-ary `unzip` | REJECT | Same-type pack-decomposition unspellable |
| P | Sigma / dependent product | REJECT | Out of Swift's language reach |
| Q | Tuple-conformance bridge (SE-0283) | DEFER | Wait for landing; preference = maintain own |
| R | Curry / uncurry interop | REJECT | `fold` + `init` already cover this |
| S | HList interop | REJECT | Subsumed by parameter packs |
| T | Flatten type alias | REJECT | Same as B |
| U | Key-path `mapTransform` | REJECT | Settled by peer api-design |

**Counts**: 21 candidates. **ADOPT: 1**, **DEFER: 6**, **REJECT: 14**.

### Top 3 highest-value forward directions

1. **Candidate H — `BitwiseCopyable` conditional conformance.**
   The single ADOPT. One-line additive change after empirical
   verification on Swift 6.3.1; enables AoS `Span<Product<...>>` use
   cases for `BitwiseCopyable` packs; mirrors to Pair-primitives.

2. **Candidate Q — Tuple-conformance bridge once SE-0283 revival ships.**
   Highest-value tracked DEFER. When the stdlib lifts native tuple
   conformances, Product's identity question (richer-API wrapper vs
   absorbed) gets its definitive answer. Maintaining own conformances
   keeps typed-throws and short-circuiting under institute control.

3. **Candidate I — `~Copyable` arms (joint with Candidate N).** Largest
   user-visible surface unlock; mechanical migration once
   `escapable-blocked.md`'s three upstream items land. The Pair / Either
   cohort already admits `~Escapable` arms; Product mechanically catches
   up at that point.

## Outcome

**Status**: RECOMMENDATION

This document is *additive* to 0.1.0 — none of the 21 candidates blocks
tomorrow's release, and no candidate proposes a breaking change. The
single ADOPT (Candidate H, `BitwiseCopyable`) is a one-line conditional
conformance suitable for a 0.1.x patch or 0.2.0 minor bump after
empirical verification.

### Answer to the central question

**What is `swift-product-primitives`' durable identity vs stdlib tuples
+ parameter packs?**

Product's durable identity is **the named, n-ary, dynamic-member-lookup-
enabled, error-aggregation-ready wrapper around `(repeat each Element)`.
It is not absorbed by the stdlib; it is the institute-shaped surface
*on top of* the stdlib's tuple/pack primitives.** Three load-bearing
properties remain after the predicted SE-0283 revival lands:

1. **Nominal identity.** A `Product<Int, String>` is type-distinct from
   `(Int, String)`; this is the basis for `Equation.Protocol` /
   `Comparison.Protocol` / `Hash.Protocol` witness conformances and any
   future ecosystem trait that targets "the n-ary product type
   specifically." Bare tuples cannot host institute-defined witnesses.
2. **Typed-throws-friendly transformations.** The current `map`, `fold`,
   `append`, `prepend`, `zip` all carry `throws(E)` where `E: Swift.Error`.
   The stdlib's predicted tuple conformances target `Equatable`/
   `Hashable`/`Comparable` — *not* a transformation surface. Product
   owns the n-ary functor surface in a way the stdlib does not plan to
   reach.
3. **`@dynamicMemberLookup` to the underlying tuple keypath.**
   `product.0` continues to work seamlessly while letting the consumer
   reach into the named struct for institute-witness conformances. The
   stdlib's tuple form has no nominal hook for `@dynamicMemberLookup`-
   style affordances.

What Product is *not*: a labeled-record type (Candidate D — different
package, unbuildable), a structure-of-arrays container (Candidate K —
different package, deferred), an HList replacement (Candidate S —
subsumed by packs). The 21-candidate analysis above gives 14 REJECTs
precisely because Product's identity is *narrow on purpose*: it is the
positional n-ary product, not the universal n-ary container.

### User decision points

The following candidates would benefit from explicit user decision before
post-0.1.0 work proceeds:

* **Candidate C (Distributivity with Either) placement.** If a
  consumer surfaces, where does the `distributed` free function live?
  Three options: this package (adds Either dep), Either-primitives (adds
  Product dep), or a new cross-cutting Integration target. No default
  answer is correct without a concrete consumer.
* **Candidate H (`BitwiseCopyable`) timing.** Ship in 0.1.x patch (small
  additive conformance) or wait for 0.2.0 minor bump (paired with other
  additive conformances)? Recommend 0.1.x patch after empirical
  verification, but timing is a release-cadence call.
* **Candidate Q (Tuple-conformance bridge) directional preference.**
  When SE-0283 revival lands, the document recommends *maintain own
  conformances*; user may prefer *delegate* if stdlib semantics evolve
  in a typed-throws-friendly direction. Re-decide at that point.

### Cross-package implications

* **Candidate H** mirrors to `swift-pair-primitives` (binary case) and,
  where applicable, to non-`map`-shaped institute primitives.
* **Candidate I** is *jointly* tracked with `swift-pair-primitives`
  (already admits `~Escapable`) and `swift-either-primitives` (already
  admits `~Escapable`). Product is the laggard; mechanical catch-up.
* **Candidate C** spans `swift-product-primitives` ×
  `swift-either-primitives`. Cross-package edge would be new.
* **Candidate K** flagged as a *separate-package candidate* (`swift-soa-
  primitives`) outside this package's scope.

No candidate requires changes to `Package.swift` for 0.1.0. Candidate H
adds one extension; Candidate I (when unblocked) modifies existing
extensions; all others are documentation-only or out-of-scope.

## References

This document deliberately does not duplicate the 50+ primary citations in
`academic-and-ecosystem-survey.md` (Q7 bibliography). Candidates above
cite the survey by Q-code (e.g., "peer Q3.c"). Net-new claims introduced
by this document are tagged `[Verified: 2026-05-10]` inline.

### Cross-document references

* `academic-and-ecosystem-survey.md` (this Research/ dir) — academic and
  ecosystem prior art; 50+ verified primary sources (2026-05-08).
* `api-design-leveraging-property-primitives.md` (this Research/ dir) —
  call-site shape, instance-canonical pattern, typed-throws threading.
* `escapable-blocked.md` (this Research/ dir) — `~Escapable`/`~Copyable`
  blocker tracking; cohort asymmetry note.
* `swift-institute/Research/escapable-support-pair-either-product.md` —
  ecosystem-wide `~Escapable` adoption state.
* `swift-institute/Research/nonescapable-ecosystem-state.md` — broader
  context for nonescapable type rollout.
* `swift-pair-primitives/Research/escapable-arm-support.md` — sibling
  primitive's `~Escapable` adoption (succeeded; cohort precedent).
* `swift-either-primitives/Research/escapable-arm-support.md` — sibling
  primitive's `~Escapable` adoption (succeeded; cohort precedent).
* `swift-either-primitives/Research/api-design-property-leverage.md` —
  coproduct-side API shape; informs duality framing.

### Verification scope of this document

This document *originates* the following claims (not present in prior
research) and tags them `[Verified: 2026-05-10]`:

* **Candidate D, two-pack constraint.** `<each Label, each Element>` is
  rejected by SE-0398's one-pack-per-type rule. *(Inferred from peer
  Q3.b + SE-0398 text already verified 2026-05-08; restated here as a
  forward-direction blocker.)*
* **Candidate L, `@_rawLayout` incompatibility with packs.** The
  attribute requires concrete size/alignment; pack-instantiated types do
  not. *(Architectural inference from underscored-attribute usage in
  swift-atomics; no SE-track public documentation as of 2026-05-10.)*
* **Candidate K, AoS-vs-SoA distinction.** The current `Span<Product>`
  AoS path works today via Candidate H; SoA is a separate-package
  question. *(New framing this document introduces.)*

All other claims trace to prior-research citations dated 2026-05-08 or
to peer documents in this Research/ dir.
