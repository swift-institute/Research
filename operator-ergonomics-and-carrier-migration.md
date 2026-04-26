# Operator Ergonomics and Carrier Migration

<!--
---
version: 1.0.0
last_updated: 2026-04-26
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

In Phase 2b of the carrier-ecosystem migration (cf.
`swift-institute/Research/carrier-ecosystem-application-inventory.md`),
the goal is to phase out per-type capability protocols
(`Cardinal.\`Protocol\``, `Ordinal.\`Protocol\``,
`Affine.Discrete.Vector.\`Protocol\``) in favor of `Carrier<Underlying>`.
The migration of `Cardinal` and `Affine.Discrete.Vector` proceeded
cleanly — their operators are `Self + Self → Self`-shaped and slot
into `extension Carrier where Underlying == X` directly.

The migration of `Ordinal.\`Protocol\`` did NOT proceed cleanly. Its
typed-advance operator —

```swift
extension Ordinal.`Protocol` {
    static func + (lhs: Self, rhs: Count) -> Self
}
```

— relied on the protocol's `associatedtype Count: Cardinal.\`Protocol\``,
which gives DIFFERENT concrete `Count` types per conformer:

- `Ordinal.Count == Cardinal`
- `Tagged<Slot, Ordinal>.Count == Tagged<Slot, Cardinal>`

This per-conformer concreteness is what made `slot + .one` infer cleanly
at call sites: `Self.Count` resolves to `Tagged<Slot, Cardinal>` for
`slot: Tagged<Slot, Ordinal>`, and `.one` is unambiguously the
`Tagged<Slot, Cardinal>.one` static var.

`Carrier<Underlying>` has no `Count` associatedtype. A free generic
operator —

```swift
public func + <O: Carrier<Ordinal>, C: Carrier<Cardinal>>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain
```

— is type-correct but **does not infer `.one` at call sites**: `C` is
unbound at use, and `.one` could be any `Carrier<Cardinal>` with
matching `Domain`.

Empirical evidence: ~97 files across the ecosystem use the
`slot + .one`/`i += .one`/`w += .one`/`current = current + .one` idiom
on `Tagged<Tag, Ordinal>`-typed positions. Removing
`Ordinal.\`Protocol\`` breaks all of them.

**Trigger**: [RES-001] Investigation — design question arose during
implementation; cannot be resolved without systematic analysis of
alternatives.

**Tier**: 2 (Standard) — cross-package, sets ecosystem-wide direction
for whether/which per-type protocols are retained alongside Carrier.
Not Tier 3 because it does not establish a new normative semantic
contract; it resolves the migration question using existing patterns.

**Scope**: cross-package (`swift-carrier-primitives`,
`swift-cardinal-primitives`, `swift-ordinal-primitives`,
`swift-affine-primitives`, plus all consumers — kernel, memory,
buffer, vector, bit-vector, sequence, etc.).

**Stakeholders**: ecosystem maintainers; ~97 consumer files.

## Prior research and constraints

The following are LOAD-BEARING and not relitigated:

| Source | Locks in |
|--------|----------|
| `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0 RECOMMENDATION | Recommendation #3: don't make `V.\`Protocol\`` REFINE Carrier (V2 double-Tagged-conformance cost). Recommendation #6: witness protocols (Hash, Equation, Comparison) stay distinct from Carrier — sibling, not refinement. |
| `swift-carrier-primitives/Research/carrier-vs-rawrepresentable-comparative-analysis.md` DECISION | Carrier and RawRepresentable are non-substitutable. |
| `swift-carrier-primitives/Sources/Carrier Primitives/Carrier.swift` | `Carrier<Underlying>` has only `associatedtype Domain` (default `Never`) and `associatedtype Underlying`. **No `Count`.** |
| `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.swift` (Phase 1, this session) | `Tagged: Carrier` shipped with cascading `Underlying = RawValue.Underlying`. Tagged is unambiguously a Carrier; that conformance is fixed. |

User constraints stated in this session:
- **Don't refine Carrier** (Path B rejected per Rec #3).
- **Don't migrate the ~97 call sites** (Path D rejected — too much downstream churn).
- **Don't add operator overloads** to recreate the legacy magic.

## Question

How should we preserve `slot + .one`-style typed-advance operator
ergonomics during the Phase 2b migration, given that `Carrier` has no
`Count` associatedtype, refinement is rejected, and call-site
migration is rejected?

Sub-questions:
1. Does the user's stated goal ("phase out per-type protocols in favor
   of Carrier") apply uniformly to all three per-type protocols, or
   does it fragment by per-protocol structure?
2. If a per-type protocol must be retained, what is its relationship
   to Carrier (sibling vs refinement vs disjoint)?
3. What ergonomic and architectural costs does each path carry?

## Analysis

### Methodology

Per [RES-004]: enumerate options, identify criteria, analyze
trade-offs against constraints, recommend.

Per [RES-019]: internal grep run — `swift-carrier-primitives/Research/`
and `swift-institute/Research/` searched for `associatedtype Count`,
`Self.Count`, `per-conformer`, `per-type associatedtype`. Surfaced:
- `capability-lift-pattern.md` — recommendations on protocol shape
- `mutability-design-space.md` — sibling-not-refinement reasoning for
  orthogonal capability protocols
- `self-projection-default-pattern.md` — meta-pattern for sibling
  generic structs paired with capability protocols (DEGENERATE for
  Hash-shape since it lacks the sibling generic)

The capability-lift-pattern document covers per-type protocols broadly
but does NOT specifically analyze the "associatedtype Count provides
operator ergonomics that Carrier lacks" case. That's the gap this
document fills.

### Per-protocol decomposition

The three protocols being migrated are NOT structurally uniform.
Decomposing by what each protocol's operators rely on:

| Protocol | Operators | Operator shape | Needs `associatedtype`? |
|----------|-----------|----------------|------------------------|
| `Cardinal.\`Protocol\`` | `+`, `+=`, `zero`, `one` | `Self + Self → Self` | **No** — `Self` alone is enough |
| `Affine.Discrete.Vector.\`Protocol\`` | `+`, `-`, `+=`, `-=`, `zero`, `one`, `prefix -` | `Self + Self → Self`, `Self - Self → Self` | **No** — `Self` alone is enough |
| `Ordinal.\`Protocol\`` | `+`, `+=` (via `Count`); also cross-type with Cardinal/Vector | `Self + Self.Count → Self` | **Yes** — `Self.Count` is per-conformer concrete |

Cardinal and Affine.Discrete.Vector's operators slot cleanly into
`extension Carrier where Underlying == X { static func + (Self, Self) -> Self }`.
`.one` infers because `Self+Self` means rhs's type is the same as
lhs's, and `.one` resolves on Self via the static var on the
constrained extension.

Ordinal's operator is the only one that needs per-conformer Count,
because the typed-advance operation crosses TWO carriers (Ordinal +
Cardinal → Ordinal) with matching Domain. Without an associatedtype
that maps Self → its-matching-Cardinal-Carrier, the RHS type cannot
be resolved per-conformer.

**This is the asymmetry the migration must respect.**

### Option A: Self.Domain-derived `Count` typealias on the constrained Carrier extension

```swift
extension Carrier where Underlying == Ordinal {
    public typealias Count = Tagged<Self.Domain, Cardinal>
    public static func + (lhs: Self, rhs: Self.Count) -> Self { ... }
}
```

For `Tagged<Slot, Ordinal>`: Self.Domain = Slot, Self.Count =
Tagged<Slot, Cardinal>. ✓ — `slot + .one` infers.

For bare `Ordinal`: Self.Domain = Never, Self.Count =
Tagged<Never, Cardinal>. **Not Cardinal.** Bare callers writing
`ord + Cardinal(5)` get a type error; they must write
`ord + Tagged<Never, Cardinal>(Cardinal(5))`, which is awkward and
introduces a previously-absent type spelling at bare call sites.

**Verdict**: Tagged-Ordinal call sites work; bare-Ordinal call sites
break. Bare Ordinal is rare in production code (mostly tests and
internal Ordinal-package code), but not zero. Asymmetric ergonomic
cost.

### Option B: Refine `Carrier where Underlying == Ordinal` with a `Count` associatedtype

```swift
extension Ordinal {
    public protocol `Protocol`: Carrier where Underlying == Ordinal {
        associatedtype Count: Carrier<Cardinal>
    }
}
```

**Rejected by capability-lift-pattern.md Recommendation #3** (V2
double-Tagged-conformance dance: Tagged conforms to V.\`Protocol\` and
must conform to Carrier with the same bounds — duplicate extensions).

**Rejected by user** in this session.

Not analyzed further.

### Option C: Per-type-extension `Count` typealiases referenced as `Self.Count` from a generic operator

```swift
extension Ordinal { public typealias Count = Cardinal }
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public typealias Count = Tagged<Tag, Cardinal>
}

extension Carrier where Underlying == Ordinal {
    public static func + (lhs: Self, rhs: Self.Count) -> Self { ... }
}
```

**Empirically refuted in this session.** Compile error:

```
error: 'Count' is not a member type of type 'Self'
```

Swift's protocol-extension generic lookup does not see typealiases
defined on conforming types unless the typealias is declared on the
protocol (as an associatedtype) or on an enclosing constrained
extension. Type-extension typealiases are visible at the
concrete-type spelling site, not through generic Self.

**Verdict**: technically infeasible at Swift 6.3.1.

### Option D: Migrate the ~97 call sites to `.successor.saturating()` / explicit Tagged spelling

**Rejected by user** in this session. Real downstream churn; cost
exceeds value.

Not analyzed further.

### Option E: Concrete operator overloads (bare + Tagged)

```swift
public func + (lhs: Ordinal, rhs: Cardinal) -> Ordinal { ... }
public func + <Tag>(lhs: Tagged<Tag, Ordinal>, rhs: Tagged<Tag, Cardinal>) -> Tagged<Tag, Ordinal> { ... }
```

**Rejected by user** in this session ("we shouldn't add overloads as
part of this — that's not the right approach"). Also tracks the
"don't add multiple-tier operator overloads" anti-pattern.

Not analyzed further.

### Option F: Retain `Ordinal.\`Protocol\`` as a SIBLING to Carrier (not a refinement)

```swift
// In swift-ordinal-primitives — NOT a refinement of Carrier.
extension Ordinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        associatedtype Count: Carrier<Cardinal>
        var ordinal: Ordinal { get }
        init(_ ordinal: Ordinal)
    }
}

extension Ordinal: Ordinal.`Protocol` {
    public typealias Domain = Never
    public typealias Count = Cardinal
    // ...
}

extension Tagged: Ordinal.`Protocol`
where RawValue: Ordinal.`Protocol`, Tag: ~Copyable {
    public typealias Domain = Tag
    public typealias Count = Tagged<Tag, Cardinal>
    // ...
}

extension Ordinal.`Protocol` {
    public static func + (lhs: Self, rhs: Count) -> Self { ... }
    public static func += (lhs: inout Self, rhs: Count) { ... }
}
```

**Key property**: `Ordinal.\`Protocol\`` does NOT refine Carrier.
Tagged conforms to Carrier (Phase 1) AND to `Ordinal.\`Protocol\``
**independently** — two single-extension conformances, no V2
double-conformance Tagged dance because there's no parent-child
relationship between the two protocols.

This is structurally equivalent to how `Hash.\`Protocol\``,
`Equation.\`Protocol\``, `Comparison.\`Protocol\`` already coexist
with Carrier in the ecosystem (per Recommendation #6 of
capability-lift-pattern.md): they're siblings, each providing its own
capability surface, neither refining nor depending on Carrier.

**Verdict**: works ergonomically (`slot + .one` resolves cleanly via
`Self.Count`), works architecturally (sibling pattern, no V2 cost,
matches existing Hash/Equation/Comparison precedent), and preserves
all ~97 call sites.

### Option G: Targeted retention — keep `Ordinal.\`Protocol\`` as a sibling, but migrate `Cardinal.\`Protocol\`` and `Affine.Discrete.Vector.\`Protocol\`` to Carrier as planned

This is **Option F applied selectively**, scoped to where the
associatedtype machinery is actually load-bearing.

The asymmetry from §"Per-protocol decomposition":
- Cardinal: operators are Self+Self → migrate to Carrier cleanly.
- Affine.Discrete.Vector: operators are Self+Self → migrate to Carrier cleanly.
- Ordinal: operator is Self+Count → retain per-type protocol as sibling.

**Verdict**: surgical. Migrates two of three protocols (cleaning up
the legacy where it's redundant) and retains the third where the
per-type machinery provides genuine value Carrier cannot replicate.

### Comparison

| Criterion | A (Self.Domain) | B (refine) | C (per-type Count) | D (migrate sites) | E (overloads) | F (retain all) | G (selective retain) |
|-----------|---|---|---|---|---|---|---|
| `slot + .one` works for Tagged | ✓ | ✓ | ✗ (compile error) | ✓ via successor | ✓ | ✓ | ✓ |
| `ord + Cardinal(5)` works for bare Ordinal | ✗ (need Tagged<Never, …>) | ✓ | ✗ | ✓ via successor | ✓ | ✓ | ✓ |
| Avoids V2 double-Tagged-conformance | ✓ | ✗ | n/a | ✓ | ✓ | ✓ | ✓ |
| Avoids ~97-file churn | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ |
| Avoids new operator overloads | ✓ | ✓ | n/a | ✓ | ✗ | ✓ | ✓ |
| Phases out redundant per-type protocols | partial | no | n/a | yes | yes | **no** | **partial (2 of 3)** |
| Aligns with Recommendation #6 sibling precedent | n/a | no | n/a | n/a | n/a | yes | yes |
| User constraint compliance | bare-asymmetry | rejected | infeasible | rejected | rejected | ✓ | ✓ |

### Constraint summary

Per the user's stated constraints in this session:
- B, D, E rejected directly.
- C is technically infeasible.
- A introduces an asymmetric ergonomic cost (bare-Ordinal callers see
  awkward `Tagged<Never, Cardinal>` type spelling).
- F and G satisfy all constraints.

The choice between F and G is whether to retain ALL three per-type
protocols (F) or only `Ordinal.\`Protocol\`` (G), letting Cardinal and
Affine.Discrete.Vector migrate to Carrier where the migration is
clean.

### Architectural framing

The capability-lift-pattern.md framework distinguishes:

- **Capability-lift recipe** (Cardinal/Ordinal/Hash): per-type
  protocols whose role is "abstract value-carrying capability." Carrier
  is intended to subsume this role.
- **Witness protocols** (Hash producing a hash; Equation;
  Comparison): per-type protocols whose role is BEHAVIORAL — "I
  produce X" or "I am orderable." Recommendation #6 keeps these
  distinct from Carrier.

The case in this investigation reveals a third role:

- **Operator-ergonomics protocols**: per-type protocols whose role is
  to provide ASSOCIATEDTYPE-DRIVEN OPERATOR DISPATCH (e.g.,
  `Self + Self.Count → Self` where Count is per-conformer). Carrier
  cannot replicate this because it lacks the associatedtype.

`Ordinal.\`Protocol\``'s primary role is the third: typed-advance via
`Self.Count`. The capability-lift role (which Carrier subsumes) is
secondary.

This re-framing converts the migration question from
"phase out per-type protocols" (universal) to
"phase out per-type protocols whose role Carrier subsumes; retain
those whose role Carrier cannot subsume" (selective).

### Prior art — per [RES-021]

The "per-type protocol with associatedtype Output/Count for operator
dispatch" pattern is **universal across statically-typed languages**:

- **Rust** [`std::ops::Add`](https://doc.rust-lang.org/std/ops/trait.Add.html):
  `trait Add<Rhs = Self> { type Output; fn add(self, rhs: Rhs) -> Self::Output; }`.
  Each impl declares its own `Output`. Operator dispatch is per-impl.
  Verified 2026-04-26.
- **Haskell** type classes with associated types (TypeFamilies extension):
  `class Add a where type Sum a b; (+) :: a -> b -> Sum a b`.
  Identical machinery to Rust's `Add::Output`.
- **Scala** type classes via implicits + dependent types: `trait Add[A]
  { type Sum; def add(a: A, b: A): Sum }`.

**Contextualization step (per [RES-021])**: the universal-adoption
pattern *exists* in Swift via per-type protocols with associatedtypes
— precisely the legacy `Ordinal.\`Protocol\``. Removing it without a
replacement removes a feature Swift idiomatically supports and that is
universally adopted in peer languages. The capability-lift-pattern.md's
push toward parameterized super-protocols (`Carrier<Underlying>`)
serves a DIFFERENT purpose (cross-type generic dispatch / Form-D
algorithms), not operator-Output dispatch. The two patterns are
complementary, not substitutive — and that's the resolution this
document recommends.

**Swift Evolution prior art**: SE-0346 (lightweight same-type
requirements for primary associated types) enables `Carrier<X>` syntax
but does NOT address the operator-Output use case. SE-0353
(constrained existential types) is also tangential. There is no Swift
Evolution proposal that obsoletes the per-type-protocol-with-
associatedtype pattern — because the pattern remains a first-class
Swift idiom for operator-Output dispatch.

### Why Recommendation #3 doesn't bite for sibling Ordinal.`Protocol`

Capability-lift-pattern.md Recommendation #3 says "don't make
`V.\`Protocol\`` a refinement of Carrier." The V2 cost it cites is:

> Tagged conformance must be authored twice: when Tagged conforms to a
> refinement `V.\`Protocol\``, Swift's diagnostic explicitly says
> *"conditional conformance to a protocol does not imply conformance
> to its inherited protocol."* The Tagged extension must first conform
> Tagged to `Carrier.\`Protocol\`` with the same bounds, THEN conform
> Tagged to `V.\`Protocol\``.

The cost is specifically caused by REFINEMENT (V.Protocol: Carrier).

For sibling protocols (V.Protocol does NOT inherit from Carrier), this
cost does NOT apply. Tagged conforms to Carrier and to V.Protocol
independently. There's no "first conform to the parent then to the
refinement" requirement because there's no parent-child relationship.

This is why Hash.`Protocol`, Equation.`Protocol`, Comparison.`Protocol`
already coexist with Carrier as siblings without V2 cost — and why
sibling-Ordinal.`Protocol` would be the same shape.

## Outcome

**Status**: RECOMMENDATION — adoption of Option G recommended;
principal stamp pending.

### Recommendation: Option G — Selective Retention

1. **Migrate `Cardinal.\`Protocol\``** to `Carrier where Underlying == Cardinal`
   constrained extensions (operators are Self+Self; clean migration;
   no per-conformer associatedtype needed). Remove the
   `Cardinal.\`Protocol\`` declaration.

2. **Migrate `Affine.Discrete.Vector.\`Protocol\``** to `Carrier where Underlying == Affine.Discrete.Vector`
   constrained extensions. Same shape as Cardinal. Remove the
   `Affine.Discrete.Vector.\`Protocol\`` declaration.

3. **RETAIN `Ordinal.\`Protocol\``** as a SIBLING to Carrier (not a
   refinement). Restore its `associatedtype Count: Carrier<Cardinal>`,
   its `Self + Count` operator, and the per-conformer typealiases.
   The protocol does NOT inherit from Carrier — both protocols
   coexist on the same conforming types (Ordinal, Tagged-of-Ordinal),
   matching the Hash/Equation/Comparison precedent (Rec #6).

4. **Conformers retain dual conformance**:
   - `Ordinal: Carrier` (Phase 1) — provides Form-D dispatch + cross-Carrier algorithms.
   - `Ordinal: Ordinal.\`Protocol\`` (retained) — provides typed-advance ergonomics.
   - `Tagged<Tag, Ordinal>: Carrier` — provided automatically by `extension Tagged: Carrier where RawValue: Carrier`.
   - `Tagged<Tag, Ordinal>: Ordinal.\`Protocol\`` — declared independently with `where RawValue: Ordinal.\`Protocol\`` cascading constraint.

5. **Update `capability-lift-pattern.md`** to articulate the
   "operator-ergonomics protocols" role as a third category (alongside
   capability-lift and witness protocols), and to clarify that Rec #6's
   sibling-precedent extends to operator-ergonomics protocols when
   they need per-conformer associatedtypes that Carrier cannot
   provide.

### Implementation impact

- **Cardinal-primitives**: Phase 2b proceeds as already done in this
  session (Cardinal.\`Protocol\` removed; operators on Carrier extension).
  No re-work.
- **Affine.Discrete.Vector-primitives**: Phase 2b proceeds as already
  done. No re-work.
- **Ordinal-primitives**: REVERT the Phase 2b removal of
  `Ordinal.\`Protocol\``. Restore the protocol declaration, restore
  the `Count` associatedtype, restore operators on the protocol
  extension. Coexists with `Ordinal: Carrier` (Phase 2a addition,
  retained).
- **Downstream call sites (~97 files)**: NO CHANGE. `slot + .one`
  continues to work via the retained `Ordinal.\`Protocol\``'s
  Self.Count machinery.

### What this document does NOT do

- Propose a new ecosystem primitive (per [RES-018], no new primitive
  proposed; existing per-type protocol pattern retained for one
  protocol).
- Re-litigate Recommendation #3 (don't refine Carrier) — the
  recommendation stands; sibling pattern doesn't trigger it.
- Establish a normative rule that ALL operator-ergonomics protocols
  must coexist with Carrier — only Ordinal.`Protocol` is identified
  as needing per-conformer associatedtype machinery in this
  investigation. Future protocols must justify retention via the same
  test (operators rely on per-conformer associatedtype).
- Modify `Carrier<Underlying>` (e.g., add a `Count` associatedtype) —
  Carrier remains a minimal value-carrying super-protocol per its
  shipped declaration.

### Constraints honored

- ✓ User constraint: don't refine Carrier (B rejected).
- ✓ User constraint: don't migrate ~97 call sites (D rejected).
- ✓ User constraint: don't add operator overloads (E rejected).
- ✓ Recommendation #3 (don't refine Carrier).
- ✓ Recommendation #6 (sibling precedent: Hash/Equation/Comparison).
- ✓ [RES-018] (no new primitive — uses existing per-type protocol
  pattern, applied selectively).

### Acceptance gate

Before this recommendation reaches DECISION:
1. Restore `Ordinal.\`Protocol\`` (revert Phase 2b for Ordinal only).
2. Verify build clean across ordinal-primitives + downstream
   consumers (memory, buffer, vector, bit-vector, sequence, kernel,
   etc.) WITHOUT call-site migration.
3. Verify `slot + .one` resolves cleanly at consumer sites.
4. Run all existing tests (35 in ordinal-primitives, plus downstream)
   — green.

## References

### Primary sources

- `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0
  RECOMMENDATION — Recommendation #3 (don't refine Carrier),
  Recommendation #6 (sibling protocols stay distinct).
- `swift-carrier-primitives/Sources/Carrier Primitives/Carrier.swift` —
  protocol declaration; no `Count` associatedtype.
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.swift`
  (Phase 1, this session) — Tagged: Carrier with cascading Underlying.
- `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift`
  (legacy, removed in Phase 2b, **to be restored per this
  recommendation**) — the protocol whose `Count` machinery this
  document analyzes.

### Cited research

- `swift-institute/Research/carrier-ecosystem-application-inventory.md` —
  the Phase 1 inventory that scoped the migration.
- `swift-carrier-primitives/Research/mutability-design-space.md` —
  precedent for "orthogonal sibling protocols" (Mutatable as a
  separate package, not refining Carrier).
- `swift-institute/Research/self-projection-default-pattern.md` —
  V4 Hash-shape "DEGENERATE" (capability-default, not self-projection)
  — relevant precedent for sibling capability protocols.

### Convention sources

- **[PKG-NAME-002]** — `Namespace.\`Protocol\`` is the canonical
  capability-protocol pattern. Sibling protocols use the same
  spelling.
- **[API-IMPL-009]** — Hoisted protocol with nested typealias.
- **[RES-001]** — Investigation triggers.
- **[RES-019]** — Step-0 internal research grep.
- **[RES-020]** — Tier 2 prior-art-survey requirements.
- **[RES-021]** — Universal-adoption contextualization step.

### Language references

- **SE-0346** — Lightweight same-type requirements for primary
  associated types. Enables `Carrier<Underlying>`. Does NOT obsolete
  per-type protocols with associatedtypes.
- **SE-0319** — Conditional conformances. Relevant to the Tagged
  conditional-conformance pattern.
- **SE-0353** — Constrained existential types (`any P<X>`). Relevant
  to existential dispatch over Carrier.

### Cross-language prior art

- [Rust `std::ops::Add`](https://doc.rust-lang.org/std/ops/trait.Add.html)
  — universal pattern for operator-Output via per-impl associated
  type. Verified 2026-04-26.
- Haskell type classes with associated types (TypeFamilies extension)
  — same shape.
- Scala type classes with dependent types — same shape.
