# Carrier / Tagged / `.Protocol` Ecosystem Application Inventory

<!--
---
version: 1.2.0
last_updated: 2026-04-26
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - v1.2.0 (2026-04-26): Phase 4 (Decimal Tagged refactor) **CANCELLED** per
    `swift-institute/Research/decimal-carrier-integration.md` (RECOMMENDATION,
    2026-04-26). Decimal.Exponent / Precision / Payload remain standalone
    struct types. The v1.0.0 inventory's CAN-yes verdict on Decimal was
    ungrounded — it did not surface the naming-convention obstacle (no
    domain-typed phantom Tag), the gated literal-conformance state per
    tagged-literal-conformances-fresh-perspective.md, the [IMPL-001]
    domain-erasure problem of Carrier<Int> conformance, or the [RES-018]
    second-consumer hurdle (zero `Tagged<_, Decimal.*>` and zero
    `Carrier<Decimal.*>` usage). Decimal types populate a third role-class
    beyond Section A capability-lift adopters and Section H multi-field
    types: domain-specific value types whose arithmetic identity is the
    type's primary purpose and whose phantom-typed variants don't exist.
  - v1.1.0 (2026-04-26): Phase 1 + 2a + 2b + 3 + 5 implementation log added.
    Phase 2b resolved via Option G (selective retention) per
    `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` —
    Cardinal/Affine.Discrete.Vector migrated cleanly to Carrier; Ordinal.`Protocol`
    retained as sibling for typed-advance ergonomics. Phase 3 partial: Clock.Nanoseconds,
    Clock.Offset, Property all conform to Carrier; Algebra.Modular.Modulus reclassified
    as RawRepresentable-shaped (not Carrier candidate). Phase 5 ALREADY-MET
    (Index.Bounded cascade works automatically).
  - v1.0.0 (2026-04-26): Initial Phase 1 inventory + Phase 2 triage.
---
-->

## Context

A two-phase ecosystem inventory + triage for sites where one of three
patterns from the carrier-primitives v0.1.x cycle could land but has not
been applied:

1. **Carrier conformance** (`Carrier<Underlying>` from `swift-carrier-primitives`)
2. **Tagged refactor** (replace standalone single-field wrappers with
   `Tagged<Tag, V>` from `swift-tagged-primitives`)
3. **`.Protocol` capability-lift pattern** (per
   `swift-carrier-primitives/Research/capability-lift-pattern.md`)

The investigation surveys swift-primitives (134 packages),
swift-standards (21), and swift-foundations (137) — 292 packages total.

**Trigger**: [RES-013] Discovery — proactive ecosystem-wide audit prompted
by the user observation that Cardinal/Ordinal/Hash adopted the
capability-lift pattern but no systematic sweep has run since the v0.1.x
cycle, despite the recipe applying to many more candidates.

**Tier**: 2 — cross-package, ecosystem-wide; characterizes adoption
opportunities without prescribing per-package action.

**Scope**: ecosystem-wide, primitives + standards + foundations. The
triage produces a ranked top-N list for follow-up per-package handoff
dispatch (not produced in this document).

**Out of scope**: implementation; per-package conformance work; layer 4
(Components) and layer 5 (Applications).

## Prior research (cited, not relitigated)

This document **extends** the following — every triage verdict that
contradicts these would need explicit override:

| Source | Locks in |
|--------|----------|
| `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0 RECOMMENDATION | The recipe; ecosystem instances Cardinal/Ordinal/Hash; six variant verdicts; Form-D super-protocol payoff; recommendation #6: witness protocols (Hash, Comparison) stay distinct from Carrier |
| `swift-carrier-primitives/Research/carrier-vs-rawrepresentable-comparative-analysis.md` DECISION | RawRepresentable validating-wrapper space ≠ Carrier space; ecosystem types should NOT dual-conform |
| `swift-carrier-primitives/Research/dynamic-member-lookup-decision.md` DECISION | Asymmetric-quadrant ergonomics is the canonical "don't apply" trigger; Q1-only ergonomics fail |
| `swift-carrier-primitives/Research/sli-*.md` DECISIONs | Per-stdlib skip rationales: Array, Set, Dictionary, Optional, Result, Range family, Slice, ContiguousArray, InlineArray, Void, TaskPriority, unsafe-pointers, Span family, Clock.Instant family, all Foundation types — **all hard-skip; do not relitigate** |
| `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` DECISION | Tagged does not conform to RawRepresentable; ecosystem-wide ban on dual conformance |
| `swift-mutator-primitives/Research/orthogonal-vs-refinement-stance.md` (deferred — see Memory) | Carrier and Mutator are orthogonal; types may participate in either, both, or neither |
| `swift-ownership-primitives/Research/self-projection-default-pattern.md` RECOMMENDATION | Ownership.Borrow.\`Protocol\` participates in self-projection pattern, NOT capability-lift; the two are orthogonal taxonomy axes |

## Phase 1 — Inventory

### Methodology

Per [HANDOFF-013] reader-side prior-research grep applied first
(citations above). Then four enumeration commands:

```bash
# Baseline counts
ls /Users/coen/Developer/swift-primitives/  | grep -E '^swift-' | wc -l   # 134
ls /Users/coen/Developer/swift-standards/   | grep -E '^swift-' | wc -l   # 21
ls /Users/coen/Developer/swift-foundations/ | grep -E '^swift-' | wc -l   # 137

# Hoisted-protocol declarations
grep -rln "public protocol \`Protocol\`" \
  /Users/coen/Developer/swift-primitives/*/Sources/ \
  /Users/coen/Developer/swift-standards/*/Sources/ \
  /Users/coen/Developer/swift-foundations/*/Sources/

# Tagged-aliased typealiases
grep -rn "typealias.*= Tagged<" \
  /Users/coen/Developer/swift-primitives/*/Sources/ \
  /Users/coen/Developer/swift-standards/*/Sources/ \
  /Users/coen/Developer/swift-foundations/*/Sources/
```

Output: 26 hoisted-protocol declarations across primitives + standards;
~80 distinct Tagged-typealias sites; remainder enumerated by spot-reading
package structure.

The inventory is organized by **decision class**, not by package, so
that triage applies to the structural decision rather than to the
package's identity. Each entry is one row: package | type/protocol |
current shape | candidate pattern | Q-quadrant.

### Section A — Existing capability-lift adopters (Carrier-shaped)

Types currently following the recipe per `capability-lift-pattern.md`
§"The recipe": value type V + `extension V { public protocol \`Protocol\` { ... } }`
+ self-conformance + Tagged forwarding.

| Package | Type / Protocol | Current shape | Candidate pattern | Q-quadrant |
|---------|-----------------|---------------|-------------------|------------|
| swift-cardinal-primitives | `Cardinal.\`Protocol\`` | Recipe complete; `var cardinal: Cardinal`; `init(_ cardinal: Cardinal)`; `Domain: ~Copyable` | Carrier conformance (already a Carrier in spirit; could conform to `Carrier<Cardinal>` super-protocol) | Q1 (Copyable & Escapable) |
| swift-ordinal-primitives | `Ordinal.\`Protocol\`` | Recipe complete + `Count` refinement; canonical Tagged forwarding | Carrier conformance + `Count: Carrier<Cardinal>` constraint | Q1 |
| swift-hash-primitives | `Hash.Value` (= `Tagged<Hash, Int>`) | Already Tagged; gets Carrier via Tagged forwarding | Already Carrier-of-Int via Tagged | Q1 |
| swift-affine-primitives | `Affine.Discrete.Vector.\`Protocol\`` | **NEW FINDING — recipe complete, NOT cited in capability-lift-pattern.md ecosystem instances**: `var vector`; `init(_ vector:)`; `Domain: ~Copyable`; Tagged forwarding | Already a fourth canonical adopter; should be added to ecosystem instances | Q1 |

**Finding A.1**: `Affine.Discrete.Vector.\`Protocol\`` is a fourth
ecosystem instance of the capability-lift pattern not enumerated in
`capability-lift-pattern.md` v1.1.0's "Existing ecosystem instances"
table. Recommendation: amend that table on the next revision.

### Section B — Witness-style hoisted protocols

Recipe-shaped (capability protocol + Tagged forwarding) but the *role* is
behavioral (a witness), not value-carrying. **Per recommendation #6 of
capability-lift-pattern.md, these stay distinct from Carrier.** Listed
for completeness; not Carrier candidates.

| Package | Protocol | Role | Notes |
|---------|----------|------|-------|
| swift-equation-primitives | `Equation.\`Protocol\`` | Equality witness (`==`) | Stays distinct |
| swift-comparison-primitives | `Comparison.\`Protocol\`` | Total-order witness (`<`); refines Equation | Stays distinct |
| swift-hash-primitives | `Hash.\`Protocol\`` | Hash-production witness | Coexists with Hash.Value (Carrier-of-Int via Tagged) |
| swift-witness-primitives | `Witness.\`Protocol\`` | Marker for struct-with-closures | Not Carrier-shaped at all (empty marker) |
| swift-color-standard | `Color.\`Protocol\`` | Color-canonicalization witness (`canonical() -> Color`) | Witness role, stays distinct |
| swift-coder-primitives | `Coder.\`Protocol\`` | Codec witness | Stays distinct |
| swift-serializer-primitives | `Serializer.\`Protocol\`` | Serialization witness | Stays distinct |
| swift-input-primitives | `Input.\`Protocol\`` | Input-source witness | Stays distinct |
| swift-input-primitives | `Input.Stream.\`Protocol\`` | Streaming-input witness | Stays distinct |
| swift-render-primitives | `Render.Async.Sink.\`Protocol\`` | Rendering-sink witness | Stays distinct |
| swift-memory-primitives | `Memory.Allocator.\`Protocol\`` | Allocator witness | Stays distinct |
| swift-observation-primitives | `Observation.\`Protocol\`` | Observation witness | Stays distinct |
| swift-parser-primitives | `Parser.Parser` (parser witness type) | Parser combinator | Stays distinct |

### Section C — Abstraction-style hoisted protocols

Hoisted protocol shape, but the conformer set is "all collection/sequence
types of shape X", not "all carriers of value V". Carrier abstraction
doesn't fit because there's no single Underlying value.

| Package | Protocol | Conformers | Why not Carrier |
|---------|----------|-----------|-----------------|
| swift-sequence-primitives | `Sequence.\`Protocol\`` | All sequences | Sequence is Element-parameterized; conformers don't share an Underlying value |
| swift-sequence-primitives | `Sequence.Borrowing.\`Protocol\`` | Borrowing sequences | Same |
| swift-sequence-primitives | `Sequence.Iterator.\`Protocol\`` | Iterators | Iterator is a behavior, not a value carrier |
| swift-collection-primitives | `Collection.\`Protocol\`` | All collections | Element-parameterized |
| swift-collection-primitives | `Collection.Slice.\`Protocol\`` | Slice types | View, not wrapper (parallel to sli-slice.md) |
| swift-bit-vector-primitives | `Bit.Vector.\`Protocol\`` | 5 Bit.Vector container variants | Word-level access protocol, not value-carrier |
| swift-array-primitives | `Array.Protocol` | Array variants | Element-parameterized |

### Section D — Self-projection-default-pattern adopters (orthogonal)

Per `self-projection-default-pattern.md`: a protocol's associatedtype
defaults to `N<Self>`. Distinct from capability-lift. Listed for
completeness; the relationship is orthogonal.

| Package | Protocol | Pattern |
|---------|----------|---------|
| swift-ownership-primitives | `Ownership.Borrow.\`Protocol\`` | Self-projection (Borrow IS the projection); not Carrier |

### Section E — Tagged-aliased value carriers (Pattern 2 already done)

These are **already Carrier-of-X via Tagged forwarding** when X has
`.Protocol` (Cardinal, Ordinal, Affine.Discrete.Vector). The triage
question for each is: **does the Underlying type X need its own
`.Protocol` companion** (so that `Tagged<Tag, X>` joins Carrier-of-X)?

Underlying types observed across the ecosystem (deduplicated; package
of declaration in parens):

| Underlying type | Currently has `.Protocol`? | Tagged-aliased site count | Notes |
|-----------------|---------------------------|---------------------------|-------|
| `Cardinal` (cardinal-primitives) | YES | ~12 (Kernel.Completion.Event.Count, Kernel.Link.Count, Kernel.System.Path.Length, …) | ✓ Pattern (3) done |
| `Ordinal` (ordinal-primitives) | YES | ~6 (Index<E>, Memory.Address, Pool.Bounded.Slot.Index, System.Processor.ID, Text.Position, Algebra.Z) | ✓ Pattern (3) done |
| `Affine.Discrete.Vector` (affine-primitives) | YES | ~3 (Affine.Discrete.Ratio.Offset, Text.Offset, Kernel.File.Delta) | ✓ Pattern (3) done |
| `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Int`, `Int64` (stdlib) | N/A — sli-foundation/stdlib | ~25 (Kernel.User.ID, Kernel.Group.ID, Test.Case.ID, Pool.ID.RawValue, Async.Waiter.Queue.Metadata, …) | sli-* DECISIONs already cover these — bare integers don't need `.Protocol`; consumers use `Tagged<Tag, UInt>` directly |
| `Memory.Address` (memory-primitives) | NO — but IS itself `Tagged<Memory, Ordinal>` | 2 (Kernel.Memory.Address, …) | Already a Carrier-of-Ordinal via Tagged; nested Tagged inheritance works |
| `Memory.Address.Offset` (memory-primitives) | NO — derived | 1 (Kernel.Memory.Displacement) | Same |
| `Memory.Alignment` (memory-primitives) | NO | 1 (Kernel.Memory.Allocation.Granularity) | Could gain `.Protocol` if multiple consumers want phantom-typed alignment |
| `Slot.Address` (handle-primitives backing) | NO | 1 (Handle<Phantom>) | Single consumer; not worth `.Protocol` until second consumer |
| `Clock.Nanoseconds` (clock-primitives) | NO | 2 (Continuous.Instant, Suspending.Instant) | Two consumers; candidate for `.Protocol` to support cross-clock generics |
| `Clock.Offset` (clock-primitives) | NO | 3 (Test.Instant, Unimplemented.Instant, Immediate.Instant) | Three consumers; same case |
| `Cyclic.Group.Static<N>.Element` (cyclic-primitives) | NO | 1 (Index.Cyclic) | Single consumer |
| `Ordinal.Finite<N>` (finite-primitives) | NO — could refine `Ordinal.\`Protocol\`` | 1 (Index.Bounded) | Refinement opportunity |
| `Path_Primitives.Path` (path-primitives) | NO | 1 (Kernel.Path) | Single consumer |
| `String_Primitives.String` (string-primitives) | NO | 2 (Kernel.String, …) | Could be useful |
| `Swift.String` (stdlib) | N/A | 1 (Test.Event.Kind) | Tagged<Tag, String> works without `.Protocol` |
| `Tagged<Self, UInt64>` (nested) | N/A — Tagged is itself a Carrier | 2 (Pool.ID.RawValue, Pool.Scope.RawValue) | Nested Tagged; structurally exotic but works |

**Finding E.1**: ~80 Tagged-aliased sites are **already Carriers** by
virtue of `extension Tagged: Carrier where RawValue: ~Copyable & ~Escapable`
(once swift-carrier-primitives's parametric Tagged extension lands —
verify per Phase 2). No per-site action needed for these.

**Finding E.2**: Underlying types worth surveying for new `.Protocol`
companions: `Memory.Alignment`, `Clock.Nanoseconds`, `Clock.Offset`,
`String_Primitives.String`, `Ordinal.Finite<N>`. Each has 2+ consumers
and the `.Protocol` companion would unlock Cardinal/Ordinal-style generic
APIs.

### Section F — Standalone single-field value-wrappers (Tagged refactor + `.Protocol` candidates)

Single-field structs (`public struct X { public let rawValue: Y }` shape)
that are NOT Tagged-aliased. Each is a candidate for **either** Pattern
(2) Tagged refactor **or** Pattern (1) Carrier conformance + Pattern (3)
`.Protocol` companion.

| Package | Type | Current shape | Candidate pattern | Q-quadrant |
|---------|------|---------------|-------------------|------------|
| swift-decimal-primitives | `Decimal.Exponent` | `public struct Exponent { public var rawValue: Int }`; arithmetic + literal manually | Tagged refactor (`= Tagged<Decimal.Exponent.Tag, Int>`) OR Carrier-trivial + `.Protocol` | Q1 |
| swift-decimal-primitives | `Decimal.Precision` | Same shape as Exponent | Same | Q1 |
| swift-decimal-primitives | `Decimal.Payload` | (per file listing) wrapper | TBD — needs file-level inspection | Q1 |
| swift-cyclic-primitives | `Cyclic.Group.Element` | Single-field wrapper; refinement type | Tagged refactor pending Modulus axis | Q1 |
| swift-algebra-modular-primitives | `Algebra.Modular.Modulus` | Single-field wrapper | Tagged refactor candidate | Q1 |
| swift-numeric-primitives | `Numeric.Math.Equals<T>`, `Numeric.Math.Accessor<T>` | Generic wrapper | Phantom-typed; could be Tagged-shaped | Q1 |
| swift-finite-primitives | `Finite.Bound<N>` | Compile-time-int wrapper | Specialized; bare struct works fine | Q1 |
| swift-affine-geometry-primitives | `Affine.Continuous.Point` | (per file listing) | Likely multi-field — probably NOT Carrier candidate | Q1 |

**Finding F.1**: Decimal.Exponent and Decimal.Precision are the
**clearest single-field Tagged-refactor candidates** in the ecosystem.
Both have `var rawValue: Int`, manually-implemented arithmetic, and
manually-implemented literal conformance. Replacing the standalone struct
with `typealias Exponent = Tagged<ExponentTag, Int>` would eliminate
~80 lines of hand-rolled boilerplate per type and gain Carrier
conformance for free.

### Section G — RawRepresentable / validating wrappers (out per Decision 2)

Per `carrier-vs-rawrepresentable-comparative-analysis.md`: validating
wrappers with `init?(rawValue:)` or `init throws` belong in
RawRepresentable space, NOT Carrier space. **Listed for completeness; not
Carrier candidates.**

| Package | Type | Current shape | Why not Carrier |
|---------|------|---------------|-----------------|
| swift-emailaddress-standard | `EmailAddress` | RawRepresentable + multi-field (canonical + RFC variants) | Validating + multi-field |
| swift-domain-standard | `Domain` | RawRepresentable + product type (rfc1035 + rfc1123) | Validating + multi-field |
| swift-time-primitives | `Time.Second`, `Time.Minute`, `Time.Hour`, `Time.Day`, `Time.Month`, `Time.Year` | Refinement types with `init throws` validation | Validating |
| swift-time-primitives | `Time.Month.Day` | Refinement type | Validating |
| swift-ipv4-standard / RFC_791 | `IPv4.Address` | (likely validating) | Probably validating |
| swift-ipv6-standard / RFC_8200 | `IPv6.Address` | (likely validating) | Probably validating |
| swift-uri-standard | `URI` types | (likely validating) | Probably validating |
| Many RFC-* packages in standards | various | (per spec) | Specification-validating |

### Section H — Multi-field types (NOT Carrier candidates)

Carrier requires a single `Underlying`. Types with two-or-more meaningful
stored properties cannot be Carrier without arbitrarily picking one axis.

| Package | Type | Notes |
|---------|------|-------|
| swift-complex-primitives | `Complex.Number<Scalar>` | (real, imaginary) — two equal-status axes; sli-* doesn't apply but the same axis-pre-commit problem applies |
| swift-pool-primitives | `Pool.ID` | (raw, scope) — Pool.ID.RawValue IS a Tagged-Carrier; Pool.ID itself is multi-field |
| swift-numeric-primitives | `Numeric.Fraction<N, D, T>` | (numerator, denominator) compile-time; sometimes (value, fraction-context) at runtime |
| swift-geometry-primitives | `Geometry.Line`, `Geometry.Polygon`, `Geometry.Ball`, `Geometry.Insets`, `Geometry.Path`, `Geometry.Arc`, `Geometry.Bezier`, `Geometry.Hypercube`, `Geometry.Orthotope`, etc. | All multi-field shape types |
| swift-affine-geometry-primitives | `Affine.Continuous.Point`, `Affine.Continuous.Translation`, `Affine.Continuous.Transform` | Multi-field |
| Most swift-foundations swift-* packages | various composed types | Foundations layer composes; rarely value-wrapper-shape |

### Section I — ~Copyable / ~Escapable wrappers (Q2/Q3/Q4 specialized analysis)

Carrier admits all four quadrants. Q1 is Copyable & Escapable (the
common case). Q2/Q3/Q4 conformance requires bespoke analysis per
`dynamic-member-lookup-decision.md`.

| Package | Type | Q-quadrant | Carrier candidate? |
|---------|------|------------|-------------------|
| swift-property-primitives | `Property<Tag, Base: ~Copyable>` | Q2 (~Copyable) when Base is ~Copyable, else Q1 | **Yes** — already phantom-typed; structurally a `Carrier` with `Domain = Tag`, `Underlying = Base`; would unify with Tagged in the Carrier family |
| swift-ownership-primitives | `Ownership.Inout<Base>` | Q3 (~Escapable) | Bespoke; Carrier protocol's `var underlying: Underlying { borrowing get }` may need `borrowing get` lifetime check; one-quadrant adoption may trigger asymmetric ergonomics warning |
| swift-ownership-primitives | `Ownership.Borrow<Base>` | Q3 | Already participates in self-projection-default-pattern; Carrier participation is orthogonal |
| swift-ownership-primitives | `Ownership.Shared<Base>` | Q1/Q2 | Bespoke |
| swift-property-primitives | `Property.Typed<Tag, Base, Value>` | Q2 when Base is ~Copyable | Three-axis (Tag, Base, Value) — not single-Underlying — NOT Carrier candidate |
| swift-buffer-primitives | `Buffer.Ring`, `Buffer.Slab`, `Buffer.Aligned` (~Copyable variants) | Q2 | Containers, not value-wrappers — NOT Carrier candidates (parallel to Section C) |

**Finding I.1**: `Property<Tag, Base>` is the strongest single ~Copyable
Carrier candidate in the ecosystem. Its shape (`var base: Base { _read; _modify }`,
`init(_ base: consuming Base)`, phantom Tag) is nearly isomorphic to
`Tagged<Tag, Base>` for the Q2 case. Adopting Carrier would give it
generic-dispatch parity with Tagged.

## Phase 2 — Triage

### Triage methodology

For each candidate from Section E (Tagged-aliased Underlyings), Section F
(standalone wrappers), and Section I (~Copyable wrappers):

- **CAN** — Q-quadrant compatibility, type shape, dependency layering;
  yes / no / conditional + one-line reason citing relevant skill ID
  or research decision.
- **SHOULD** — ergonomic / generic-dispatch / consistency win; bias
  toward apply when CAN holds and SHOULD is non-negative.

The asymmetric-ergonomic trigger from `dynamic-member-lookup-decision.md`
fires when a feature works in Q1 but breaks in Q2/Q3/Q4 — that is the
canonical "don't apply" signal.

### E.2 — New `.Protocol` companions for Tagged-aliased Underlyings

| Underlying | Consumer count | CAN | SHOULD | Verdict |
|-----------|---------------|-----|--------|---------|
| `Memory.Alignment` | 1 (Kernel.Memory.Allocation.Granularity) | YES — same shape as Cardinal | NEUTRAL — single consumer; symmetric-completeness alone is not justification per [RES-018] | **defer** until 2nd consumer surfaces |
| `Clock.Nanoseconds` | 2 (Continuous.Instant, Suspending.Instant) | YES — Q1 wrapper around UInt64 | POSITIVE — would let `func deadline<C: Clock.Nanoseconds.\`Protocol\`>(_ d: C) -> C` accept both Continuous.Instant and Suspending.Instant generically; consumers exist | **apply** |
| `Clock.Offset` | 3 (Test, Unimplemented, Immediate Instants) | YES — Q1 wrapper around Int64 | POSITIVE — three consumers, generic-dispatch payoff | **apply** |
| `String_Primitives.String` | 2 (Kernel.String, …) | CONDITIONAL — String is itself a complex type; carrier-of-String would expose String as Underlying which may not match consumer ergonomics | NEUTRAL — typed string-views may already cover this | **consider** — design-question first |
| `Ordinal.Finite<N>` | 1 (Index.Bounded) | YES — could refine `Ordinal.\`Protocol\``, mirroring how Tagged forwards | POSITIVE — refinement gives Index.Bounded the Cardinal-like Count refinement automatically; aligns with Ordinal pattern | **apply** |
| `Cyclic.Group.Static<N>.Element` | 1 (Index.Cyclic) | YES — Q1 wrapper around (effectively) Ordinal | NEUTRAL — single consumer | **defer** |
| `Path_Primitives.Path` | 1 (Kernel.Path) | YES | NEUTRAL — single consumer; Path itself isn't a single-underlying carrier | **defer** |
| `Slot.Address` | 1 (Handle<Phantom>) | YES — Q1 | NEUTRAL — single consumer | **defer** |

### F — Standalone single-field wrappers

| Type | CAN | SHOULD | Verdict |
|------|-----|--------|---------|
| `Decimal.Exponent` | YES — `public var rawValue: Int` exact Cardinal-shape; Q1 | POSITIVE — eliminates ~80 lines of hand-rolled arithmetic; gains Carrier-of-Int via Tagged refactor; matches ecosystem convention | **apply (Tagged refactor)** |
| `Decimal.Precision` | YES — same shape | POSITIVE — same payoff | **apply (Tagged refactor)** |
| `Decimal.Payload` | YES (likely) | POSITIVE (probably) | **apply pending file-level confirmation** |
| `Algebra.Modular.Modulus` | YES — Q1 | POSITIVE — modular arithmetic gains generic-dispatch on `some Carrier<Modulus>` | **apply** |
| `Cyclic.Group.Element` | CONDITIONAL — element is per-modulus refinement; not bare wrapper | NEUTRAL — single-consumer modulus | **consider** |
| `Numeric.Math.Equals<T>`, `Numeric.Math.Accessor<T>` | CONDITIONAL — generic Underlying per V5a; each T-instantiation needs Tagged conformance | NEUTRAL — these are accessor namespaces, not values; misclassification on first read | **defer / probably skip** — accessor pattern, not Carrier |
| `Finite.Bound<N>` | YES — Q1, compile-time-N | NEUTRAL — internal | **defer** |

### I — ~Copyable wrappers

| Type | CAN | SHOULD | Verdict |
|------|-----|--------|---------|
| `Property<Tag, Base: ~Copyable>` | YES (Q2) — Carrier protocol admits ~Copyable Self/Underlying; recipe-aligned (`var base { _read }` ≈ `borrowing get`; `init(_ base: consuming Base)`); Domain = Tag fits | POSITIVE — unifies Property with Tagged in the Carrier family; APIs `func f<C: Carrier>(_ c: C)` accept both; Form-D generic algorithms become writable across both | **apply (Q2 conformance)** — but verify the `@_lifetime(borrow self)` annotation lands cleanly per dynamic-member-lookup-decision.md asymmetric-ergonomic check |
| `Ownership.Inout<Base>` | CONDITIONAL — Q3 ~Escapable; round-trip semantics break per V5b/round-trip-semantics-noncopyable-underlyings.md; conformance compiles but `init(_ base: consuming Base)` consumes the Base (no re-extraction) | NEGATIVE — asymmetric-ergonomic trigger: Q1/Q2 conformers round-trip cleanly, Q3 doesn't; per dynamic-member-lookup-decision.md this is the canonical "don't apply" signal | **don't apply** |
| `Ownership.Borrow<Base>` | CONDITIONAL — already participates in self-projection-default; Carrier participation is orthogonal | NEUTRAL — would Carrier add anything self-projection-default doesn't? Not obviously | **defer** — design question: does cross-Borrow Form-D generic algorithm have a use case? |
| `Ownership.Shared<Base>` | YES (Q1/Q2) | NEUTRAL — single point of use | **defer** |

## Top-N ranked recommendations

Ranking biased by (consumer count × ergonomic delta) per the handoff
guidance.

| Rank | Action | Package | Estimated payoff | Per-package handoff target |
|------|--------|---------|------------------|---------------------------|
| 1 | **Tagged refactor**: replace `Decimal.Exponent`, `Decimal.Precision`, `Decimal.Payload` with `Tagged<Tag, Int>` aliases | swift-decimal-primitives | ~150 LOC removed; gains Carrier-of-Int via Tagged; ecosystem-convention alignment | `HANDOFF-decimal-primitives-tagged-refactor.md` |
| 2 | **`.Protocol` companion**: add `Clock.Offset.\`Protocol\`` and `Clock.Nanoseconds.\`Protocol\`` per Cardinal recipe | swift-clock-primitives | Cross-clock generic dispatch (`func deadline<C: Clock.Offset.\`Protocol\`>(_ d: C) -> C` accepts Test/Unimplemented/Immediate Instants); 3 + 2 consumers respectively | `HANDOFF-clock-primitives-protocol-companions.md` |
| 3 | **Carrier conformance (Q2)**: conform `Property<Tag, Base>` to `Carrier` (Domain = Tag, Underlying = Base) | swift-property-primitives | Unifies Property with Tagged; enables Form-D cross-carrier algorithms across Q1+Q2 | `HANDOFF-property-primitives-carrier-q2.md` |
| 4 | **`.Protocol` companion**: add `Algebra.Modular.Modulus.\`Protocol\`` per Cardinal recipe | swift-algebra-modular-primitives | Modular arithmetic generic dispatch; aligns with Cardinal/Ordinal style | `HANDOFF-algebra-modular-protocol-companion.md` |
| 5 | **`.Protocol` refinement**: make `Ordinal.Finite<N>.\`Protocol\`` refine `Ordinal.\`Protocol\`` so Index.Bounded gets Count for free | swift-finite-primitives | Bounded indices automatically gain Cardinal-style Count refinement; matches Ordinal pattern; small surface | `HANDOFF-finite-primitives-protocol-refinement.md` |
| 6 (lower priority) | **Documentation update**: amend `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0 §"Existing ecosystem instances" to add `Affine.Discrete.Vector.\`Protocol\`` as a fourth canonical adopter | swift-carrier-primitives (parent — recommend, don't edit) | Documentation accuracy; future investigators not surprised | Surface as recommendation in this doc's findings |

### Excluded by design (not in ranked list)

- **Witness-style hoisted protocols** (Section B): per recommendation #6 of capability-lift-pattern.md.
- **Abstraction-style hoisted protocols** (Section C): wrong shape.
- **RawRepresentable / validating types** (Section G): per carrier-vs-rawrepresentable DECISION.
- **Multi-field types** (Section H): single-Underlying mismatch.
- **`Ownership.Inout<Base>`**: asymmetric-quadrant trigger from dynamic-member-lookup-decision.md (round-trip breaks in Q3).
- **All sli-*.md cases**: hard-skip per existing DECISION docs.
- **Single-consumer Tagged Underlyings** (Memory.Alignment, Slot.Address, Path, Cyclic.Element): per [RES-018] hurdle rate; revisit when 2nd consumer surfaces.

## Implementation log (2026-04-26)

### Phase 1 — Tagged: Carrier (DONE)

- `swift-tagged-primitives` now depends on `swift-carrier-primitives` (direct, no trait gate).
- `Tagged: Carrier where Tag: ~Copyable & ~Escapable, RawValue: Carrier` shipped with `Underlying = RawValue.Underlying` cascade.
- Tagged-of-Int, Tagged-of-Tagged-of-Int, etc. all participate in Carrier dispatch automatically.
- 65 Tagged tests pass (58 existing + 7 cascade tests). Downstream chain verified.
- Tier reassignment: tagged-primitives moved Tier 0 → Tier 1.

### Phase 2a — Soft deprecation (DONE for Cardinal/Affine, partial for Ordinal)

- Cardinal.\`Protocol\`, Ordinal.\`Protocol\`, Affine.Discrete.Vector.\`Protocol\` marked `@available(*, deprecated)` with migration messages.
- @_disfavoredOverload added to Tagged inits on the deprecated protocols to disambiguate from Carrier's init.

### Phase 2b — Hard migration with Option G (DONE)

Resolution: `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` (RECOMMENDATION, 2026-04-26).

**Migrated cleanly to Carrier**:
- `swift-cardinal-primitives` — Cardinal: Carrier; Cardinal.\`Protocol\` removed; Self+Self operators on Carrier extension. 21 tests pass.
- `swift-affine-primitives` — Affine.Discrete.Vector: Carrier; Affine.Discrete.Vector.\`Protocol\` removed; operators on Carrier extension. Builds clean.

**Retained as sibling to Carrier** (operator-ergonomics protocol with per-conformer `Count: Carrier<Cardinal>` associatedtype):
- `swift-ordinal-primitives` — Ordinal.\`Protocol\` restored AND Ordinal: Carrier added. Both protocols coexist on Ordinal and Tagged-of-Ordinal. 35 tests pass. `slot + .one` works without explicit typing.

**Recommendation #7** added to capability-lift-pattern.md v1.2.0: operator-ergonomics protocols stay distinct from Carrier as siblings (codifies the lesson learned).

### Phase 3 — New value-type Carrier conformances (PARTIAL DONE)

- `swift-clock-primitives` — Clock.Nanoseconds: Carrier and Clock.Offset: Carrier shipped. Cross-clock generic dispatch (`func deadline<I: Carrier<Clock.Nanoseconds>>(_ i: I) -> I` accepts Continuous.Instant + Suspending.Instant uniformly) now writable. 96 tests pass.
- `swift-property-primitives` — Property: Carrier where Base: ~Copyable shipped. Q1+Q2 conformance (Property's generic shape doesn't admit ~Escapable Base; Q3/Q4 deferred until concrete demand surfaces per [RES-018]). 48 tests pass; downstream stack/queue/list/heap consumers build clean.
- `swift-algebra-modular-primitives` — Algebra.Modular.Modulus **reclassified as RawRepresentable-shaped** (has `init(_ cardinal: Cardinal) throws(Error)` validating init). Per `carrier-vs-rawrepresentable-comparative-analysis.md`, validating wrappers belong in RawRepresentable space. **Inventory v1.0.0's CAN-yes verdict was incorrect; corrected to CAN-no.**

### Phase 4 — Decimal Tagged refactor (CANCELLED)

Resolution: `swift-institute/Research/decimal-carrier-integration.md`
(RECOMMENDATION, 2026-04-26).

The v1.0.0 inventory's CAN-yes / SHOULD-positive verdict was ungrounded.
On investigation:

- **No second-consumer demand** [RES-018]: zero `Tagged<_, Decimal.*>`
  and zero `Carrier<Decimal.*>` usage across the ecosystem.
- **Tagged refactor structurally blocked**: naming convention has no
  natural fit (the role-axes Exponent / Precision / Payload within
  Decimal don't have domain-typed phantom Tags; synthesized `*Tag`
  suffixes violate [API-NAME-*]); Tagged production literal conformance
  is gated per tagged-literal-conformances-fresh-perspective.md.
- **Carrier<Int> conformance erases domain** per [IMPL-001]: treating
  power-of-10 exponent arithmetic as generic Int operations violates
  the type's domain identity.
- **Trivial-self-Carrier conformance is premature**: no second consumer.

Decimal.Exponent / Precision / Payload remain standalone struct types.
They populate a **third role-class** beyond Section A (capability-lift
adopters) and Section H (multi-field types): **domain-specific value
types**. This class includes Time refinement types (Time.Second,
Time.Minute, Time.Year — already classified as Section G validating
wrappers) and likely future RFC-spec'd magnitude types.

Codification queued: `capability-lift-pattern.md` v1.3.0 Recommendation #8
(per [RES-006a]).

### Phase 5 — Ordinal.Finite refinement (ALREADY-MET)

Verification spike: `Index.Bounded<N> = Tagged<Tag, Tagged<Bound<N>, Ordinal>>` participates in Ordinal.\`Protocol\` automatically via the cascading Tagged conformance. No new code needed. 79 finite-primitives tests pass.

## Outcome

**Status**: RECOMMENDATION — inventory + triage. No source files modified.
Top-5 ranked candidates surface as future per-package handoff targets;
each is a separate cycle subject to per-package skill review.

### Summary statistics

- **Packages surveyed**: 292 (134 primitives + 21 standards + 137 foundations)
- **Hoisted-protocol declarations found**: 26
  - Carrier-shaped: 4 (Cardinal, Ordinal, Hash.Value, Affine.Discrete.Vector — the last NEW)
  - Witness-style (out per recommendation #6): 13
  - Abstraction-style (out — wrong shape): 7
  - Self-projection-default-pattern (orthogonal): 1 (Ownership.Borrow)
  - Pure marker (out): 1 (Witness)
- **Tagged-aliased value carriers found**: ~80 sites (Pattern 2 already widely adopted)
- **Standalone single-field wrappers identified as candidates**: ~7
- **~Copyable wrappers identified as candidates**: 1 strong (Property), 1 conditional (Ownership.Borrow), 1 don't-apply (Ownership.Inout)

### Candidate verdict tally

- **CAN-yes**: 11 (Decimal.Exponent, Decimal.Precision, Decimal.Payload, Clock.Nanoseconds, Clock.Offset, Algebra.Modular.Modulus, Property, Ordinal.Finite, plus 3 deferred-by-single-consumer)
- **CAN-no**: 1 (Ownership.Inout — round-trip break Q3)
- **CAN-conditional**: 5 (String, Cyclic.Group.Element, Numeric.Math.Equals/Accessor, Ownership.Borrow, Ownership.Shared)

### Top-5 SHOULD-apply

1. Decimal.Exponent / Precision / Payload Tagged refactor
2. Clock.Offset / Clock.Nanoseconds `.Protocol` companions
3. Property<Tag, Base> Carrier (Q2) conformance
4. Algebra.Modular.Modulus `.Protocol` companion
5. Ordinal.Finite<N>.\`Protocol\` refining Ordinal.\`Protocol\`

### What this document does NOT do

- Implement any conformances or refactors.
- Modify swift-carrier-primitives, swift-mutator-primitives, or any other source files (handoff "Do Not Touch" honored).
- Re-litigate sli-*.md cases or capability-lift-pattern.md ecosystem instances (cited, not re-argued).
- Survey layer 4 (Components) or layer 5 (Applications) — out of scope per handoff.
- Produce per-package handoff documents for the top-5 — those are deferred follow-up cycles.

## References

### Primary sources (cited extensively above)

- `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0 RECOMMENDATION
- `swift-carrier-primitives/Research/carrier-vs-rawrepresentable-comparative-analysis.md` DECISION
- `swift-carrier-primitives/Research/dynamic-member-lookup-decision.md` DECISION
- `swift-carrier-primitives/Research/round-trip-semantics-noncopyable-underlyings.md` DECISION
- `swift-carrier-primitives/Research/sli-*.md` (all DECISIONs, 14 docs)
- `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` DECISION
- `swift-ownership-primitives/Research/self-projection-default-pattern.md` RECOMMENDATION

### Convention sources

- **[PKG-NAME-002]** — Namespace.\`Protocol\` is the canonical capability protocol
- **[API-IMPL-009]** — Hoisted protocol with nested typealias pattern
- **[RES-002a]** — Cross-package research lives in swift-institute/Research/
- **[RES-013]** — Discovery methodology
- **[RES-018]** — Premature primitive anti-pattern (second-consumer hurdle)
- **[RES-019]** — Step-0 internal research grep
- **[HANDOFF-013]** — Reader-side prior-research grep

### Language references

- **SE-0346** — Lightweight same-type requirements for primary associated types (enables `Carrier<Underlying>` parameterized form)
- **SE-0427** — Noncopyable generics (enables Q2/Q4 Carrier conformance)
- **SE-0506** — Noncopyable associated types (enables Carrier's `~Copyable & ~Escapable` associated types)
