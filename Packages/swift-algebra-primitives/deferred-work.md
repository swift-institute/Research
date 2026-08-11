# Deferred Work

<!--
---
version: 2.0.0
last_updated: 2026-02-03
status: DECISION
---
-->

## Context

During the algebra-primitives correctness round (2026-01–02), we redesigned the algebraic witness hierarchy: Field gained typed throws, `Algebra.Field.Unit` was introduced for the multiplicative group of units, Ring projections were added, and CaseSet was deleted. The implementation converged across multiple rounds of research and planning.

This document records all work that was explicitly identified during that process but intentionally excluded from the current patch set. Items 1–6 have since been implemented. Item 7 remains deferred.

## Question

What future work was identified but deferred during the algebra-primitives correctness round, and what are the dependency relationships between these items?

## Analysis

### 1. `Algebra.Z.Modulo<let n: Int>`

**Status**: Implemented.

Canonical modular integer carrier parameterized by modulus. Provides:

- Checked init (`throws(Error)`), wrapping init, and unchecked init
- Overflow-safe arithmetic: `+`, `-` (total for valid residues), `*` (`throws(Error)` for overflow)
- `Finite.Enumerable` conformance via `count`, `ordinal`, `init(__unchecked:ordinal:)`
- `static var ring: Algebra.Ring<Self>.Commutative?` — returns nil if `(n-1)²` overflows `Int`
- `static func field() -> Algebra.Field<Self>?` — returns nil when n is not prime (trial division primality, extended Euclidean inverse)

**Implementation**: `Algebra.Z.swift`, `Algebra.Z.Modulo.swift`, `Algebra.Z.Modulo.Error.swift`, `Algebra.Z.Modulo+Arithmetic.swift`, `Algebra.Z.Modulo+Finite.swift`, `Algebra.Z.Modulo+Ring.swift`, `Algebra.Z.Modulo+Semiring.swift`, `Algebra.Z.Modulo+Field.swift`, `Algebra.Z.Modulo+Primality.swift`

---

### 2. Z₂ Witness Consolidation via Isomorphism

**Status**: Implemented.

Z₂ group witnesses for Bound, Boundary, Endpoint, and Gradient are now derived via Parity isomorphism transport rather than hand-written XOR-style combining logic.

Transport functions:
- `Algebra.Group.z2(via: Optic.Iso<Element, Parity>)` — transports Parity's additive group
- `Algebra.Group.Abelian.z2(via:)` — wraps `Group.z2`
- `Algebra.Field.z2(via:)` — transports Parity's Z₂ field

Parity remains the canonical Z₂ representative. The four carriers now use `.z2(via:)` with forward/backward mappings.

**Implementation**: `Algebra.Group+Z2.swift`, `Algebra.Group.Abelian+Z2.swift`, `Algebra.Field+Z2.swift`. Modified: `Algebra.Group+Bound.swift`, `Algebra.Group+Boundary.swift`, `Algebra.Group+Endpoint.swift`, `Algebra.Group+Gradient.swift`.

---

### 3. Semiring Witnesses

**Status**: Implemented.

`Algebra.Semiring<Element>` stores additive `Monoid<Element>.Commutative` + multiplicative `Monoid<Element>`. `Algebra.Semiring<Element>.Commutative` wraps a semiring and documents multiplicative commutativity.

Ring→Semiring projection added via `Algebra.Ring+Semiring.swift` in the Ring Primitives module.

**Implementation**: `Algebra Semiring Primitives` module with `Algebra.Semiring.swift`, `Algebra.Semiring.Commutative.swift`, `Algebra.Semiring+Convenience.swift`, `Algebra.Semiring+Monoid.swift`, `exports.swift`. Ring Primitives gains `Algebra.Ring+Semiring.swift`.

---

### 4. Law Test Harnesses (Finite Carriers)

**Status**: Implemented.

`Algebra Law Primitives` module provides total pure-function harnesses returning `Violation?`. No `#expect`, no traps. Test code wraps with `#expect(violation == nil)`.

Harnesses implemented:

| Law | Namespace | Members |
|-----|-----------|---------|
| Associativity | `Algebra.Law.Associativity` | `.check(of:over:)` |
| Identity | `Algebra.Law.Identity` | `.left(of:over:)`, `.right(of:over:)` |
| Inverse | `Algebra.Law.Inverse` | `.left(of:over:)`, `.right(of:over:)` |
| Commutativity | `Algebra.Law.Commutativity` | `.check(of:over:)` |
| Distributivity | `Algebra.Law.Distributivity` | `.left(of:over:)`, `.right(of:over:)` |
| Annihilation | `Algebra.Law.Annihilation` | `.zero(of:over:)` |
| Reciprocal | `Algebra.Law.Reciprocal` | `.check(of:over:)` |
| Compatibility | `Algebra.Law.Compatibility` | `.scalar(of:over:)` |
| Action | `Algebra.Law.Action` | `.identity(of:over:)` |

Exhaustive verification tests confirm all Parity Z₂ laws, all Z₂ group transport witnesses (Bound, Boundary, Endpoint, Gradient), and Z.Modulo<5>/Z.Modulo<7> ring and field laws.

**Implementation**: `Algebra Law Primitives` module. Verification tests in `Algebra.Law.Verification Tests.swift`.

---

### 5. Module / VectorSpace Witnesses

**Status**: Implemented.

`Algebra.Module<Scalar, Vector>` stores `scalars: Ring<Scalar>`, `vectors: Group<Vector>.Abelian`, `scaling: @Sendable (Scalar, Vector) -> Vector`.

`Algebra.VectorSpace<Scalar, Vector>` stores `scalars: Field<Scalar>`, `vectors: Group<Vector>.Abelian`, `scaling: @Sendable (Scalar, Vector) -> Vector`. Provides `.module` projection (forgets field→ring).

**Implementation**: `Algebra Module Primitives` module with `Algebra.Module.swift`, `Algebra.Module+Convenience.swift`, `Algebra.VectorSpace.swift`, `Algebra.VectorSpace+Convenience.swift`, `Algebra.VectorSpace+Module.swift`, `exports.swift`.

---

### 6. Canonical Instances Beyond Parity

**Status**: Implemented (Bool semiring and monoids).

| Carrier | Instance | File |
|---------|----------|------|
| `Bool` | `Algebra.Semiring<Bool>.boolean` (OR/AND) | `Algebra.Semiring+Bool.swift` |
| `Bool` | `Algebra.Monoid<Bool>.conjunction` (AND, `true`) | `Algebra.Monoid+Bool.swift` |
| `Bool` | `Algebra.Monoid<Bool>.disjunction` (OR, `false`) | `Algebra.Monoid+Bool.swift` |

FixedWidthInteger modular ring witnesses deferred further — requires careful overflow handling beyond the scope of this work.

All instances verified via law harnesses.

**Implementation**: `Algebra.Semiring+Bool.swift`, `Algebra.Monoid+Bool.swift`. Tests in `Algebra.Bool Tests.swift`.

---

### 7. CaseSet Reintroduction in optic-primitives

**Status**: Deferred, moved out of this package.

`CaseSet` was deleted from algebra-primitives during the correctness round (213 lines of implementation, 252 lines of tests removed in commit `ce7793f`). It had unclear semantics (ordered list vs true set) and compound naming issues.

Reintroduction requires:

- Correct naming per [API-NAME-001] (`Nest.Name` pattern)
- Clear semantics (set vs ordered collection)
- Placement in optic-primitives (due to `Optic.Prism` dependency)

**Reason deferred**: Wrong package. CaseSet's semantics depend on Prism, which lives in optic-primitives.

**Dependencies**: optic-primitives must define `Optic.Prism` first.

## Comparison

| Item | Status | Summary |
|------|--------|---------|
| 1. `Algebra.Z.Modulo<n>` | Implemented | Modular carrier with ring/field witnesses |
| 2. Z₂ witness consolidation | Implemented | Parity isomorphism transport |
| 3. Semiring | Implemented | New module below Ring |
| 4. Law test harnesses | Implemented | Total pure-function verification |
| 5. Module / VectorSpace | Implemented | New module above Field |
| 6. Canonical instances | Implemented | Bool semiring/monoids |
| 7. CaseSet reintroduction | Deferred | Blocked on optic-primitives |

## Constraints

1. **No Foundation** — all items remain Foundation-free ([PRIM-FOUND-001])
2. **Downward dependencies only** — no lateral or upward tier dependencies
3. **Nest.Name pattern** — all new types follow [API-NAME-001]
4. **One type per file** — [API-IMPL-005]
5. **Typed throws** — all throwing operations use typed throws ([API-ERR-001])

## Outcome

**Status**: DECISION

Items 1–6 are implemented and verified. The algebra witness hierarchy now includes:

```
Magma → Monoid → Semiring ─┐
              └─> Group ───┼─> Ring → Field ──┬─> Law
                           └────────/         └─> Module
```

All 290 tests pass across all modules. Exhaustive law verification confirms correctness of all witnesses over finite carriers. Item 7 (CaseSet) remains deferred pending optic-primitives work.

## References

- `Algebra.Field+Parity.swift` — canonical Z₂ field witness
- `Algebra.Group+Z2.swift` — Z₂ transport function
- `Algebra.Z.Modulo.swift` — modular integer carrier
- `Algebra.Law.swift` — law harness namespace
- `Algebra.Module.swift`, `Algebra.VectorSpace.swift` — higher algebra witnesses
- `Algebra.Semiring+Bool.swift` — canonical Bool semiring
- `phase-rotation-placement.md` — related research on Phase/Z₄ placement
