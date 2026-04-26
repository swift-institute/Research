# Orthogonal vs refinement stance: `Mutator.\`Protocol\`` is a sibling of `Carrier`, not a refinement

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: REFERENCE
tier: 2
scope: cross-package
relocated_from: swift-mutator-primitives/Research/orthogonal-vs-refinement-stance.md
relocation_date: 2026-04-25
---
-->

> Reframed from DECISION to REFERENCE on 2026-04-25 when the
> `swift-mutator-primitives` package was retired (see
> `swift-carrier-primitives/Research/mutability-design-space.md` v1.1.0
> §Investigation outcome). The orthogonal-vs-refinement reasoning still
> applies if a future Mutator-shape ecosystem package emerges.

## Context

`swift-carrier-primitives/Research/mutability-design-space.md` (DECISION,
2026-04-25) deferred the question of how to express generic mutation
dispatch and recorded option C — *"separate `swift-mutable-primitives`
package with `Mutatable` protocol"* — as the principled future shape.
The deferral document framed Mutatable as *"orthogonal to Carrier, not
refining it,"* but the structural argument was carried by an asymmetry
about Tagged-as-noun-vs-Carrier-as-capability. The question of why
the protocol is *semantically* orthogonal — and not just structurally
inconvenient to refine — was left implicit.

This note states the orthogonal stance precisely and grounds it in the
empirical evidence from
`swift-institute/Experiments/mutator-dual-conformance-carrier-mutable/` (CONFIRMED, 2026-04-25)
and `swift-institute/Experiments/mutator-modify-across-quadrants/` (CONFIRMED, 2026-04-25).

## Question

Three sub-questions:

1. **Why is mutation a separate capability from carrying?** What
   conformer set distinguishes "is a Carrier" from "is Mutable"? If the
   sets are identical, refinement (or even merger) is the right shape.
2. **What does the dual-conformance look like in practice?** A
   concrete worked example — Carrier's `borrowing get` over `Underlying`
   composes with Mutable's `borrowing get + set` over `Value`. With
   `Underlying == Value`, what's left over?
3. **Should Mutable refine Carrier?** Both have a `borrowing get`. A
   protocol-refinement implementation is mechanically possible. Why
   would that be wrong?

## Analysis

### The conformer set is genuinely different

`Carrier` and `Mutator.\`Protocol\`` (`Mutable`) describe overlapping but
non-identical capability sets.

| Conformer | Carrier? | Mutable? | Notes |
|-----------|---------|----------|-------|
| `User.ID` (phantom-typed identifier wrapper, Copyable) | yes | typically NO | Phantom-typed identifiers exist precisely to keep raw values distinct at the type level. Mutation through `.underlying = newRaw` would erode the discrimination |
| `Cardinal`, `Ordinal` (number-domain wrappers) | yes | NO | Mutating an `Ordinal` in place via a generic `value = newOrdinal` setter is a category error — Ordinals are values you replace, not identities you mutate |
| `File.Handle` over `~Copyable File.Descriptor` | yes | NO | Resource handles are immutable references. Mutation goes through the resource's own typed API (e.g. `handle.write(...)`), not through the protocol's `value` setter |
| `Counter` (a state-bearing struct with mutation) | yes | yes | Genuine dual-conformance candidate; both surfaces are semantically correct |
| `Ownership.Inout<Int>` (mutable reference) | NO | yes | Inout is purely about projection-with-mutation; it has no phantom Domain or carrier semantics. Conforming to Carrier would imply construction via `init(_ value: consuming Int)` rebuilding the Inout — wrong shape |
| `Atomic<Int>` (concurrent shared mutation) | NO | yes (with reservations) | The mutation surface differs (atomic operations vs `_modify`), but the capability "this exposes a mutable value" still applies |

The key column is the second-to-last: **types that conform to Carrier but
NOT Mutable are common and load-bearing.** The phantom-typed identifier
case (User.ID, Cardinal, Ordinal, Hash.Value) is the dominant Carrier
conformer in the ecosystem; mutation is meaningless or actively harmful
for them.

If `Mutable` refined `Carrier`, conforming to `Mutable` would imply
*"this type is also a Carrier"* — and conversely, conforming a Carrier
type would imply *"this type rejects Mutable."* But identifier types
genuinely have a Carrier role and genuinely have NO mutation role. The
correct shape is two siblings, with each conformer picking its
participation independently.

If `Mutable` *forced* the same `init(_ value: consuming Value)`
requirement Carrier ships, the inout-style conformers (`Ownership.Inout`,
`Atomic`) would also struggle: their construction takes a pointer or
storage, not a fresh consumed Value. The siblings stance lets each
protocol declare exactly its own initializer story (Carrier requires
`init(_ underlying:)`; Mutable does not).

### Empirical worked example

From `swift-institute/Experiments/mutator-dual-conformance-carrier-mutable/` (CONFIRMED):

```swift
struct CounterBox {
    var raw: Int
    init(_ underlying: consuming Int) { self.raw = underlying }
}

extension CounterBox: Carrier {
    typealias Underlying = Int
    var underlying: Int { borrowing get { raw } }
}

extension CounterBox: Mutable {
    typealias Value = Int
    var value: Int {
        _read { yield raw }
        _modify { yield &raw }
    }
}

func transform<T: Carrier & Mutable>(_ t: inout T)
    where T.Underlying == T.Value, T.Underlying == Int
{
    let snapshot = t.underlying       // Carrier surface
    t.value = snapshot * 2            // Mutable surface
}

var c = CounterBox(7)
transform(&c)
// c.value = 14, c.underlying = 14 — both surfaces agree
```

The two surfaces compose without either protocol knowing about the
other. The `where T.Underlying == T.Value` constraint is the bridge for
generic algorithms that need both. When the two associated types align,
both protocols address the same underlying field; when they don't (a
type whose Carrier-Underlying is a phantom-typed identifier and whose
Mutable-Value is a separate state field), the protocols address
different aspects of the type. Both shapes are admissible.

For ~Copyable Self, the same pattern applies (V3/V4 in the experiment):

```swift
struct UniqueBox: ~Copyable {
    var _storage: Int
    init(_ underlying: consuming Int) { self._storage = underlying }
}

extension UniqueBox: Carrier {
    typealias Underlying = Int
    var underlying: Int { _read { yield _storage } }
}

extension UniqueBox: Mutable {
    typealias Value = Int
    var value: Int {
        _read { yield _storage }
        _modify { yield &_storage }
    }
}

func transformUnique<T: Carrier<Int> & Mutable<Int> & ~Copyable>(_ t: inout T) {
    t.value = t.underlying &+ 100
}
```

The `~Copyable` suppression is required on the constraint because
Swift's default constraint admits Copyable & Escapable. With the
suppression, the dual conformance composes cleanly across all four
quadrants.

### Refinement: structurally possible, semantically wrong

A refinement implementation would look like:

```swift
public protocol Mutable<Value>: Carrier where Value == Underlying {
    var value: Value {
        @_lifetime(borrow self) borrowing get
        set
    }
}
```

This compiles in Swift 6.3.1 (the experiment's V2 in
`swift-carrier-primitives/Experiments/capability-lift-pattern/` proved
the refinement form generally works). Three problems with it for the
Carrier-Mutable case specifically:

1. **It coerces the conformer sets.** Conforming `Mutable` to `Carrier`
   implies every Mutable conformer is also a Carrier. `Ownership.Inout`
   and `Atomic` would acquire a Carrier role they don't semantically
   have — and the `init(_ underlying: consuming Value)` requirement
   from Carrier becomes a forced ceremony their construction story
   doesn't fit.

2. **It muddles the user.** The phantom-typed identifier case (`User.ID`)
   that motivates Carrier is *exactly* the case mutation is wrong for.
   Refinement signals *"every Carrier should be Mutable in principle,
   adoption is gated on willingness to author the witnesses."* The
   ecosystem would acquire pressure to make `User.ID` Mutable for
   completeness — pressure that runs against the very design rationale
   (phantom discrimination) that motivated Carrier.

3. **It doesn't pay for the dual-accessor cost.** The capability-lift
   pattern's V2 finding (refinement) was that conforming Tagged to a
   refinement requires *two* extensions (one to Carrier, one to the
   refining protocol) per the SE-0335 conditional-conformance rule
   *"conditional conformance to a protocol does not imply conformance
   to its inherited protocol."* The same friction applies to refinement
   here — every dual-conforming type would author two separate
   `extension X: Mutable` and `extension X: Carrier` extensions, with
   identical bounds, just to satisfy Swift's separation rule. Sibling
   conformance has the same authoring cost (two extensions, one per
   protocol) and is honest about the protocols being separate.

### Composition vs refinement: the rule

The general principle, applied to this case:

| Sets identical | Sets overlap | Sets disjoint |
|---|---|---|
| Merge (one protocol) | Sibling protocols + dual conformance | Separate, no relationship |
| n/a here | Carrier ∩ Mutable ≠ Carrier ∪ Mutable; ≠ ∅ | n/a here |

Carrier and Mutable overlap (state-bearing wrappers conform to both) but
neither subsumes the other (phantom identifiers are Carrier-only;
mutable references are Mutable-only). The composition+dual-conformance
shape is the right call.

### Cross-protocol generic algorithms

The orthogonal stance preserves API expressiveness:

```swift
// Read-only over any Carrier:
func observe<C: Carrier>(_ c: C) -> C.Underlying { ... }

// Mutate-only over any Mutable:
func bump<M: Mutable>(_ m: inout M, by amount: M.Value) { ... }

// Compose for types that need both:
func transformBoth<T: Carrier & Mutable>(_ t: inout T)
    where T.Underlying == T.Value { ... }
```

A refinement would force the third form to be the only one; the read-
only and mutate-only forms collapse into special cases of the combined
constraint. The orthogonal form keeps each generic shape independent
and lets call sites reach for the narrowest constraint.

### Relationship to other ecosystem patterns

`swift-ownership-primitives/Research/self-projection-default-pattern.md`
(RECOMMENDATION, 2026-04-24) characterizes the pattern of "a protocol
whose associated type defaults to N<Self>" exemplified by
`Ownership.Borrow.\`Protocol\``. The same pattern is recommended for a
hypothetical `Ownership.Mutate.\`Protocol\`` / `Ownership.Inout.\`Protocol\``
("V1 FITS — parallel shape").

That pattern is **not** what this package implements. The self-
projection default protocol's associated type is the *projection
wrapper* (`Ownership.Mutate<Self>`); this package's protocol's
associated type is the *value being mutated* (`Value`). They address
different abstractions:

- `Ownership.Mutate.\`Protocol\`` (hypothetical, in
  swift-ownership-primitives) — *"Self can be projected into an
  Ownership.Mutate<Self> wrapper for inout/move semantics."*
- `Mutator.\`Protocol\`` (this package) — *"Self exposes a Value field
  that can be read and modified through the protocol surface."*

A type can participate in both, neither, or one. The relationship to
the capability-lift pattern (in
`swift-carrier-primitives/Research/capability-lift-pattern.md`) is
similarly orthogonal: capability-lift is about Tagged-forwarding for
value carriers (Cardinal, Ordinal, Hash); this package is about
mutation-capability dispatch.

The three patterns compose freely:

| Pattern | Subject | This package's relationship |
|---------|---------|----------------------------|
| Capability-lift (Carrier family) | "is a wrapper of Underlying" | sibling — composes via dual conformance |
| Self-projection default (Borrow/Mutate-projection family) | "Self projects to N<Self>" | orthogonal — addresses different abstraction |
| Mutator (this package) | "Self exposes mutable Value" | the new pattern |

## Outcome

**Status**: DECISION — `Mutator.\`Protocol\`` is a sibling capability of
`Carrier`, not a refinement. Types that need both conform to both
independently; generic algorithms compose the two via
`T: Carrier & Mutable` with optional `where T.Underlying == T.Value`
binding.

**Rationale**:

1. **Conformer sets differ**: phantom-typed Carrier conformers (User.ID,
   Cardinal, Ordinal, Hash) actively reject mutation; mutable-reference
   types (Ownership.Inout, Atomic) actively reject Carrier's
   construction story. Two siblings cleanly partition the capability
   space; refinement would force unwanted relationships.
2. **Dual conformance is empirically validated**: the experiment in
   `swift-institute/Experiments/mutator-dual-conformance-carrier-mutable/` shows the
   composition works for both Copyable and ~Copyable Self, and that
   generic algorithms over `T: Carrier & Mutable` typecheck and
   execute.
3. **API expressiveness preserved**: independent constraints
   (`some Carrier`, `some Mutable`, or both via `Carrier & Mutable`)
   let consumers reach for the narrowest applicable bound; refinement
   would collapse the bounds.
4. **Authoring cost identical**: dual conformance and refinement both
   require two extensions per dual-conforming type (one to Carrier,
   one to the refining/sibling protocol). Sibling honest about the
   protocols' independence; refinement misleads.

**Revisit triggers**:

- A concrete consumer surfaces a generic algorithm that would benefit
  from refinement-style dispatch and cannot be expressed with
  `T: Carrier & Mutable`. To date none has surfaced; the orthogonal
  stance is the principled default.
- Swift evolves to permit nesting protocols inside protocols (currently
  forbidden by SE-0404), making `Carrier.Mutable` (refinement) cheap to
  spell. Even then, the conformer-set argument remains: refinement
  would be syntactically cheaper but still semantically wrong for the
  phantom-identifier subset of Carrier.

## References

### Primary sources

- `swift-institute/Experiments/mutator-dual-conformance-carrier-mutable/Sources/main.swift`
  — V1–V5 (CONFIRMED, 2026-04-25): single concrete type conforms to
  both protocols; generic algorithms over both work; ~Copyable Self
  case works with explicit suppression.
- `swift-institute/Experiments/mutator-modify-across-quadrants/Sources/modify-across-quadrants/main.swift`
  — V1–V5 (CONFIRMED, 2026-04-25): four-quadrant trivial-self defaults
  for `Mutable` parallel the Carrier pattern, plus distinct-Value
  wrapper.

### Foundational research

- `swift-carrier-primitives/Research/mutability-design-space.md`
  (DECISION, 2026-04-25) — option C deferred. This package implements
  it.
- `swift-carrier-primitives/Research/capability-lift-pattern.md`
  (RECOMMENDATION, 2026-04-22) — the ecosystem-pattern characterization
  of Carrier-as-super-protocol; specifically §"Tagged as the canonical
  Carrier" frames the abstract-interface-vs-concrete-impl relationship.
  Recommendation 1 (parameterization over refinement) generalizes to
  this package's choice of sibling-with-typealias over refinement.
- `swift-ownership-primitives/Research/self-projection-default-pattern.md`
  (RECOMMENDATION, 2026-04-24) — characterizes the
  `associatedtype X = N<Self>` pattern; explicitly distinct from this
  package's pattern.

### Convention sources

- **[PKG-NAME-002]** — capability protocol = `Namespace.\`Protocol\``;
  this package's `Mutator.\`Protocol\`` adopts the convention.
- **[ARCH-LAYER-001]** — Layer 1 placement; Tier 0 sub-classification
  per primitives skill.
- **[RES-018]** — Premature Primitive Anti-Pattern. This protocol clears
  the second-consumer hurdle: known consumers include any state-bearing
  Carrier conformer (e.g., a cell type), `Ownership.Inout`-shaped
  references, and atomic wrappers. The protocol is the abstract
  interface that downstream mutation APIs can dispatch on.

### Language references

- **SE-0335** — Constrained existentials and the conditional-conformance
  rule that complicates refinement-style protocols.
- **SE-0427** — Noncopyable generics; this package's `Self: ~Copyable`
  suppressions on the protocol declaration.
- **SE-0506** — Noncopyable associated types; the `Value: ~Copyable &
  ~Escapable` associated-type bound.
