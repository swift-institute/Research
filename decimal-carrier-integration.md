# Decimal Carrier Integration

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

Phase 4 of the carrier-ecosystem migration (cf.
`swift-institute/Research/carrier-ecosystem-application-inventory.md`)
ranked `Decimal.Exponent` / `Decimal.Precision` / `Decimal.Payload`
as the top "Tagged refactor" candidate — three single-field wrapper
structs in `swift-decimal-primitives` whose v1.0.0 inventory verdict
recommended replacing each with a `Tagged<Tag, RawValue>` alias.

Implementation revealed multiple structural obstacles that the
inventory had not surfaced. This investigation re-evaluates the
question: should Decimal's three wrapper types integrate with the
Carrier ecosystem, and if so, how?

The inventory's CAN-yes / SHOULD-positive verdict was written without
verifying:
- whether the ecosystem has any consumer that needs cross-type generic
  dispatch over Decimal-exponent-shaped types
- whether the Tagged refactor's required phantom-tag naming has a
  natural fit
- whether the gating on Tagged's literal conformances is currently
  satisfied
- whether a non-Tagged Carrier conformance (trivial-self-carrier or
  Underlying-erasure) would carry weight

**Trigger**: [RES-001] Investigation — Phase 4 implementation revealed
the inventory's verdict was ungrounded. Multiple constraints converge
on Decimal that did not converge on Cardinal, Ordinal, or
Affine.Discrete.Vector.

**Tier**: 2 (Standard) — cross-package, sets ecosystem-wide precedent
for similar domain-specific value types (Time.Duration components,
RFC-spec'd magnitude types, etc.). Not Tier 3 because it does not
establish a normative semantic contract; it answers a single
integration question with implications for similarly-shaped types.

**Scope**: cross-package. Touches `swift-decimal-primitives`,
`swift-tagged-primitives`, `swift-carrier-primitives`, and the
downstream `swift-foundations/swift-decimals` consumer (which uses
all three Decimal wrapper types extensively).

## Prior research and constraints (load-bearing)

| Source | Locks in |
|--------|----------|
| `swift-tagged-primitives/Research/tagged-literal-conformances.md` v3.0 DECISION | Production literal conformance contingent on labeling 3 non-identity inits — not yet implemented as of 2026-04-26. |
| `swift-tagged-primitives/Research/tagged-literal-conformances-fresh-perspective.md` v1.0 RECOMMENDATION (2026-04-21) | The footgun is currently dormant only because Tagged isn't Strideable in production. Adding Strideable (independently approved) reactivates the footgun. The v3.0 plan understates costs. Production literal conformance remains gated. |
| `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` §3 | Tagged deliberately omits ExpressibleByIntegerLiteral and Strideable from production for footgun-prevention reasons. |
| `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.2.0 Recommendation #5 | Migration to Carrier should be driven by Form-D demand, not factored-for-its-own-sake. |
| `swift-carrier-primitives/Research/carrier-vs-rawrepresentable-comparative-analysis.md` DECISION | Validating-init wrappers (e.g. with `init throws`) belong in RawRepresentable space, not Carrier. |
| `[RES-018]` Premature Primitive Anti-Pattern | New ecosystem integration requires demonstrated second-consumer demand. Symmetric-completeness ("we migrated Cardinal and Affine.Discrete.Vector, so Decimal too") is explicitly disallowed as sole justification. |
| `[IMPL-001]` Principled Absences | Operations that mix domain semantics (e.g., treating power-of-10 exponents as just-another-Int) are principled absences, not gaps. |
| `[API-NAME-*]` naming conventions | Phantom tag types use real domain names (User, Memory, Bit, Kernel.User). Synthesized `*Tag` suffixes (e.g., `ExponentTag`, `PayloadTag`) are forbidden — the role-suffix is naming-leak. |

## Question

Should `Decimal.Exponent`, `Decimal.Precision`, and `Decimal.Payload`
integrate with the Carrier ecosystem? Three sub-questions:

1. **Tagged refactor**: replace each standalone struct with a
   `Tagged<Tag, RawValue>` typealias?
2. **Carrier conformance** (without Tagged refactor): conform each
   standalone struct to Carrier (trivial-self or Underlying-erasure)?
3. **No integration**: keep as standalone domain-specific types?

## Analysis

### Empirical baseline

Pre-investigation grep across `swift-primitives/`, `swift-standards/`,
`swift-foundations/`:

| Pattern | Hits |
|---------|------|
| `Tagged<_, Decimal.Exponent>` | **0** |
| `Tagged<_, Decimal.Precision>` | **0** |
| `Tagged<_, Decimal.Payload>` | **0** |
| `Carrier<Decimal.Exponent>` | **0** |
| `Carrier<Decimal.Precision>` | **0** |
| `Carrier<Decimal.Payload>` | **0** |
| `func f<C: Carrier<Int>>` | **0** that consume Decimal types |

`Decimal.Exponent` / `Precision` / `Payload` are used across two
packages (`swift-decimal-primitives` and `swift-foundations/swift-decimals`)
but never as phantom-tag bases nor as Carrier conformers in consumer
code. There is no second consumer wanting cross-type generic dispatch
over decimal-exponent-shaped values [Verified: 2026-04-26].

### Option 1 — Tagged refactor

```swift
// Aspirational shape (NOT VIABLE — see analysis below):
extension Decimal {
    public typealias Exponent  = Tagged<???, Int>
    public typealias Precision = Tagged<???, Int>
    public typealias Payload   = Tagged<???, UInt64>
}
```

**Naming obstacle (load-bearing)**: each Tagged needs a concrete
phantom Tag. The natural domain name `Decimal.Exponent` IS the value
type — it cannot also be the tag (recursive typealias). Synthesized
`*Tag` types (`ExponentTag`, `PrecisionTag`, `PayloadTag`) violate
[API-NAME-*]'s phantom-tag naming convention — the convention uses
real domain names (User, Memory, Bit, Kernel.User), not role-suffixes.

| Convention conformer | Tag |
|---------------------|-----|
| `Tagged<User, UUID>` | `User` (domain type) |
| `Tagged<Memory, Ordinal>` | `Memory` (namespace) |
| `Tagged<Bit, Ordinal>` | `Bit` (namespace) |
| `Tagged<Kernel.User, UInt32>` | `Kernel.User` (domain type) |
| `Tagged<???, Int>` for `Decimal.Exponent` | **No natural domain name** |

The three Decimal wrapper types are sub-axes within one domain
(Decimal). They aren't distinct phantom domains — they're distinct
roles within the same domain. Tagged's phantom-tag mechanism is
designed for phantom-typed wrappers, not role-typed wrappers within
one domain. The naming break is signal.

**Literal-conformance obstacle**: Decimal.Exponent and Decimal.Precision
both rely on `ExpressibleByIntegerLiteral` for ergonomic construction
(`Decimal.Exponent.Format32.max = 96`, `Decimal.Precision.format32 = 7`).
Tagged's production literal conformance is **gated**: the v3.0 DECISION
to land it was deferred per
`tagged-literal-conformances-fresh-perspective.md` because Strideable
(independently approved) reactivates the cross-domain overload-resolution
footgun. Tagged literal conformance currently lives in test support only.

A Tagged refactor would either (a) lose the literal-init ergonomics or
(b) force consumers of decimal-primitives to import test-support, both
unacceptable.

**Verdict**: Tagged refactor is **structurally blocked**. The naming
mechanism doesn't fit; the literal-conformance gating isn't satisfied;
no consumer demand justifies the friction.

### Option 2 — Carrier conformance without Tagged refactor

Two sub-options on the Underlying type.

#### Option 2a — Trivial-self-Carrier (Underlying = Self)

```swift
extension Decimal.Exponent: Carrier {
    public typealias Underlying = Decimal.Exponent
    // var underlying + init(_:) inherited from Carrier where Underlying == Self default
}
```

This mirrors `Cardinal: Carrier`, `Ordinal: Carrier`,
`Affine.Discrete.Vector: Carrier`. APIs `func f(_ c: some Carrier<Decimal.Exponent>)` would accept bare `Decimal.Exponent` and any
hypothetical `Tagged<X, Decimal.Exponent>` variant.

But: per the empirical baseline, no `Tagged<X, Decimal.Exponent>`
exists, and nobody writes `func f(_ c: some Carrier<Decimal.Exponent>)`.
The conformance adds API surface with zero current consumer benefit.
Per [RES-018], the second-consumer hurdle is unmet.

**Cost**: small (~5 lines added). **Benefit**: zero current consumer.
**Risk**: introduces a Carrier conformance that future readers will
expect to be load-bearing somewhere; if no demand emerges, it becomes
dead surface.

**Verdict**: Premature per [RES-018]. Status quo is the principled
default; revisit when concrete demand surfaces.

#### Option 2b — Underlying = Int (or UInt64 for Payload)

```swift
extension Decimal.Exponent: Carrier {
    public typealias Underlying = Int
    public var underlying: Int { rawValue }
    public init(_ underlying: Int) { self.rawValue = underlying }
}
```

This treats `Decimal.Exponent` as a Carrier-of-Int. APIs
`func f<C: Carrier<Int>>(_ c: C)` would accept Decimal.Exponent
alongside `Tagged<X, Int>`, `Cardinal`, and any other Int-carrying type.

**Domain-erasure problem (load-bearing)**: per [IMPL-001] principled
absences, treating power-of-10 exponent arithmetic generically as
"Int operations" violates the type-system enforcement that makes
`Decimal.Exponent` a domain-typed value rather than a raw Int. Adding
`+ : (Decimal.Exponent, Decimal.Exponent) -> Decimal.Exponent` is
exponent addition (compose powers of 10); adding
`+ : (Carrier<Int>, Carrier<Int>) -> Carrier<Int>` (the Carrier-where-Underlying-Int extension's hypothetical operator) is generic Int addition
applied to a value that happens to be backed by Int. The two operations
are semantically distinct; the second discards the domain.

The [IMPL-001] table's pattern matches: "scaling an index" / "subtracting
counts" are principled absences because they violate the dimensional
algebra of the types involved. Same principle applies: "treating a
decimal exponent as Int-shaped Carrier" violates the dimensional
algebra of decimal arithmetic.

**Verdict**: Wrong shape. Carrier<Int> would erase the domain identity
that motivates the type's existence.

### Option 3 — No integration (status quo)

Leave Decimal.Exponent / Precision / Payload as standalone struct types
in `swift-decimal-primitives`. They:
- Have their own type identity (distinct from Int / UInt64 / each other)
- Have their own ExpressibleByIntegerLiteral (struct-level, no Tagged
  literal-conformance gating)
- Have their own arithmetic (domain-typed: exponent-add is power-of-10
  composition, not generic Int add)
- Have their own format-limit constants (Format32/64/128 nested enums)
- Are used directly by downstream consumers (swift-decimals) without
  any Carrier or Tagged dispatch needed

Cost: zero (no change). Benefit: preserves domain identity, avoids
the naming and gating obstacles, matches actual ecosystem usage.

The principle: not every value-wrapping struct in the ecosystem needs
to be a Carrier. Carrier exists for **value-carrying types whose
phantom-typed variants need cross-type generic dispatch**. Decimal's
wrapper types have no phantom-typed variants and no cross-type
dispatch use case. They're domain types — distinct values with
domain-specific arithmetic — not Carrier candidates.

This is the **third role-class** beyond what
`carrier-ecosystem-application-inventory.md` v1.1.0 enumerated:

- Section A: capability-lift adopters (Cardinal, Ordinal, Affine.Discrete.Vector) — value-carrying, Tagged variants wanted
- Section H: multi-field types (Complex.Number, Geometry shapes) — single-Underlying mismatch
- **(new) domain-specific value types** — single-field but domain-typed arithmetic; phantom-typed variants and cross-type dispatch are not part of the type's role

Decimal.Exponent / Precision / Payload populate this third role-class.
Other candidates likely include: Time refinement types (Time.Second,
Time.Minute) which already have validating inits and are RawRepresentable-shaped per
`carrier-vs-rawrepresentable-comparative-analysis.md`.

### Comparison

| Criterion | Tagged refactor | Carrier 2a (self) | Carrier 2b (Int) | Status quo |
|-----------|----|----|----|----|
| Naming convention compliance | ✗ (no domain-typed phantom Tag) | ✓ | ✓ | ✓ |
| Literal-init ergonomics preserved | ✗ (gated) | ✓ | ✓ | ✓ |
| Domain-arithmetic identity preserved | partial | ✓ | ✗ (Int-erased) | ✓ |
| Demonstrated second consumer | ✗ | ✗ | ✗ | n/a (no integration) |
| Form-D dispatch enabled | ✓ (unused) | ✓ (unused) | ✓ (wrong domain) | ✗ (none needed) |
| Migration cost | high | low | low | zero |
| Reversibility if demand changes | medium (alias-rename) | high (extension delete) | high (extension delete) | high (just add Carrier conformance later) |

### Cross-package precedent

The pattern of "domain-specific value-wrapping struct that does NOT
conform to Carrier" is already in the ecosystem:

- `Time.Second`, `Time.Minute`, `Time.Hour`, `Time.Day`, `Time.Month`,
  `Time.Year`, `Time.Month.Day` — refinement types with `init throws`
  (RawRepresentable-shaped per
  `carrier-vs-rawrepresentable-comparative-analysis.md`).
- `EmailAddress`, `Domain` — multi-field validating wrappers
  (RawRepresentable + Codable).
- IPv4, IPv6 family — RFC-validating types.

Decimal.Exponent / Precision / Payload aren't validating (no `init
throws`), but they share the "domain-specific value-wrapping struct;
not a Carrier candidate" classification for the same underlying reason:
the domain identity is the type's primary purpose, and Carrier's
generic-dispatch role doesn't apply.

## Outcome

**Status**: RECOMMENDATION

**Decision**: Decimal.Exponent, Decimal.Precision, Decimal.Payload
remain **standalone struct types**. No Tagged refactor. No Carrier
conformance. No integration with carrier-primitives.

### Rationale

1. **No second-consumer demand** [RES-018]. Empirically zero
   `Tagged<_, Decimal.*>` and zero `Carrier<Decimal.*>` usage across
   the ecosystem. Form-D dispatch over decimal-shaped types is not
   needed by any current consumer.

2. **Tagged refactor is structurally blocked**. The naming convention
   does not fit (no domain-typed phantom for the role-axes within
   Decimal); Tagged's production literal conformance is gated per
   `tagged-literal-conformances-fresh-perspective.md` and unblocking
   it would reactivate the cross-domain overload-resolution footgun.

3. **Carrier<Int> conformance is principled-absence territory**. Per
   [IMPL-001], treating power-of-10 exponent arithmetic generically
   as Int operations erases the domain identity the type exists to
   enforce.

4. **Trivial-self-Carrier conformance is premature**. Per [RES-018]
   the second-consumer hurdle is unmet. Adding a conformance with no
   call site introduces API surface that decays to dead infrastructure.

5. **The status-quo shape correctly classifies the type**. Decimal's
   wrapper types are domain-specific value types — not Carrier
   candidates — alongside the existing precedent of Time refinement
   types and RFC-spec'd validating wrappers.

### Codification

Promote a new role-class to `capability-lift-pattern.md` v1.3.0 (per
[RES-006a]):

> **Recommendation #8 (proposed)**: Domain-specific value-wrapping
> structs whose phantom-typed variants don't exist and whose
> cross-type generic dispatch isn't a use case stay distinct from
> Carrier — same reasoning as Recommendation #6 (witness protocols)
> and Recommendation #7 (operator-ergonomics protocols), now extended
> to non-protocol value types. Apply the [IMPL-001]-flavored test:
> would treating the type's arithmetic as generic Carrier<Underlying>
> arithmetic violate the type's domain semantics? If yes, retain as
> standalone domain type.

### Revisit triggers

This recommendation can be revisited when:

1. A consumer surfaces with a concrete need to dispatch generically
   over decimal-exponent-shaped types (e.g., a context where Decimal.Exponent and a phantom-tagged variant of it must share a generic
   API). At that point, evaluate Option 2a (trivial-self-Carrier).

2. Tagged production literal conformance lands per the
   tagged-literal-conformances v3.0 DECISION (after the 3 non-identity
   inits are labeled and the Strideable interaction is resolved). Tagged
   refactor becomes mechanically possible — though the naming obstacle
   still applies.

3. A new ecosystem convention emerges for naming role-axis sub-tags
   within a single domain (i.e., a way to name `Decimal.Exponent`'s
   "exponent" axis distinctly from `Decimal.Precision`'s "precision"
   axis at the type level). At that point, Tagged refactor becomes
   naming-feasible.

Neither trigger is currently active.

### What this document does NOT do

- Modify any source code in `swift-decimal-primitives` or
  `swift-foundations/swift-decimals`. Decimal types remain as they
  are.
- Modify the inventory's CAN-yes verdict in v1.0.0 — instead, the
  inventory's v1.1.0 implementation log records the Phase 4 deferral
  and this document supplies the rationale.
- Apply the same recommendation to all single-field wrapper structs
  in the ecosystem. Each candidate should be evaluated against the
  same test (second consumer; phantom-typed variants; domain-arithmetic
  identity). Some Section F candidates from the inventory may still be
  valid Tagged-refactor / Carrier-conformance targets when the test
  yields different answers.

## References

### Primary sources

- `swift-decimal-primitives/Sources/Decimal Primitives/Decimal.Exponent.swift` —
  the standalone struct under analysis (var rawValue: Int; manually-rolled
  arithmetic; Format32/64/128 nested enums).
- `swift-decimal-primitives/Sources/Decimal Primitives/Decimal.Precision.swift` —
  same shape as Exponent.
- `swift-decimal-primitives/Sources/Decimal Primitives/Decimal.Payload.swift` —
  similar shape over UInt64; only the `none = 0` constant.
- `swift-foundations/swift-decimals/Sources/Decimals/Decimal.Operation.*.swift` —
  primary downstream consumers; use Decimal.Exponent / Precision /
  Payload extensively, never via Tagged or Carrier dispatch.

### Cited research

- `swift-tagged-primitives/Research/tagged-literal-conformances.md` v3.0 DECISION
- `swift-tagged-primitives/Research/tagged-literal-conformances-fresh-perspective.md` v1.0 RECOMMENDATION
- `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` DECISION
- `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.2.0 — Recommendations #5, #6, #7
- `swift-carrier-primitives/Research/carrier-vs-rawrepresentable-comparative-analysis.md` DECISION
- `swift-institute/Research/carrier-ecosystem-application-inventory.md` v1.1.0 — Phase 4 inventory entry (this investigation supersedes that verdict)
- `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` v1.0 RECOMMENDATION — articulates the role-class distinction this document extends to non-protocol value types

### Convention sources

- **[RES-001]** — investigation triggers
- **[RES-018]** — premature primitive anti-pattern; second-consumer hurdle
- **[RES-019]** — step-0 internal research grep
- **[RES-021]** — universal-adoption contextualization step
- **[IMPL-001]** — principled absences; domain-arithmetic identity
- **[IMPL-INTENT]** — code reads as intent, not mechanism
- **[API-NAME-*]** — phantom-tag naming convention (real domain types,
  not synthesized `*Tag` suffixes)

### Language references

- **SE-0346** — Lightweight same-type requirements for primary
  associated types. Enables `Carrier<Underlying>` parametric form.
  Does not by itself motivate Carrier conformance for any specific
  type.
- **SE-0353** — Constrained Existential Types (`any Carrier<X>`).
  Same: enables, doesn't motivate.
