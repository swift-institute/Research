# Algebra Primitives Package Split

<!--
---
version: 1.0.0
last_updated: 2026-02-04
status: RECOMMENDATION
---
-->

## Context

`swift-algebra-primitives` sits at package tier 8 due to its aggregate product pulling in `finite-primitives` (tier 7), `comparison-primitives` (tier 2), and `optic-primitives` (tier 0). The abstract algebraic hierarchy (Magma→Field, Module, Law) only needs `witness-primitives` (tier 2) — placing its effective product-level tier at 3–10 depending on the product, while the package-level tier is forced to 8.

This creates a tier inversion: `numeric-primitives` (tier 1) cannot depend on any algebra product, so algebraic witnesses for numeric types (e.g., "Int forms a Ring", "Double forms a Field") must live in algebra-primitives rather than in numeric-primitives where they semantically belong.

Product-level tier analysis (see `Computed Primitives Tiers.md`) shows algebra has a spread of 19 (product tiers 0–19), confirming that the package bundles concerns at very different abstraction levels.

**Trigger**: Tier architecture analysis identified the numeric/algebra ordering as the primary architectural issue in the primitives layer.

**Related research**: `algebra-adt-package-relationship.md` (dependency direction between algebra and container packages).

## Question

How should `swift-algebra-primitives` be decomposed into separate packages to lower the tier of the abstract algebraic hierarchy, and what remains for a temporary aggregate package?

## Analysis

### Current Structure

`swift-algebra-primitives` contains 11 library products backed by 10 source targets plus 1 test support target. The abstract hierarchy is a linear chain of internal targets:

```
Core → Magma → Monoid → Group  → Ring → Field → Module
                     ↘ Semiring ↗            ↘ Law
```

The aggregate "Algebra Primitives" target (66 files) depends on all hierarchy targets plus three external packages (finite, optic, comparison). It contains:

- 9 enum classification types (Parity, Sign, Bound, etc.) with `Finite.Enumerable` conformances
- Z/nZ residue class system (8 files) using `Finite.Capacity`
- Optic-based Z₂ group/field transport (7 files) using `Optic.Iso`
- Comparison integration (1 file) — retroactive `Finite.Enumerable` on `Comparison`
- Bool algebraic witnesses (3 files) — monoid, semiring
- Parity direct algebraic witnesses (2 files) — group, field (no Optic)
- Product types (2 files) — Pair, Product
- Re-export manifest (1 file)

### Option A: Split Hierarchy into Packages

Each hierarchy level becomes its own package. The concrete types and integration code go into a temporary aggregate.

**New package tiers:**

| Package | Content | Tier | Dependencies |
|---------|---------|:----:|--------------|
| swift-algebra-primitives | Algebra namespace, Pair, Product, enum types (without Finite.Enumerable), Bool+XOR | **0** | *(none)* |
| swift-algebra-magma-primitives | Magma, Semigroup | **3** | algebra@0, witness@2 |
| swift-algebra-monoid-primitives | Monoid, Monoid.Commutative, Bool monoid witnesses | **4** | algebra-magma@3 |
| swift-algebra-group-primitives | Group, Group.Abelian, Parity group witness | **5** | algebra-monoid@4 |
| swift-algebra-semiring-primitives | Semiring, Semiring.Commutative, Bool semiring witness | **5** | algebra-monoid@4 |
| swift-algebra-ring-primitives | Ring, Ring.Commutative | **6** | algebra-group@5, algebra-semiring@5 |
| swift-algebra-field-primitives | Field, Field.Unit, Parity field witness | **7** | algebra-ring@6 |
| swift-algebra-module-primitives | Module, VectorSpace | **8** | algebra-field@7 |
| swift-algebra-law-primitives | All Law types | **9** | algebra-module@8 |
| swift-algebra-aggregate-primitives | *(temporary — see below)* | **8** | algebra-field@7, finite@7, optic@0, comparison@2 |

**Total: 10 packages** (9 hierarchy + 1 temporary aggregate), replacing the current 1 package.

### What Moves Into the Hierarchy Packages

Files from the current aggregate that have no dependency on finite, optic, or comparison can be absorbed into the hierarchy packages where they naturally belong.

#### Into algebra-primitives (core, tier 0) — 12 files

All of these have zero external dependencies:

| File | Content |
|------|---------|
| Pair.swift | Generic binary product `Pair<First, Second>` |
| Product.swift | N-ary product with parameter packs |
| Bool+XOR.swift | `^` operator for Bool |
| Parity.swift | `enum Parity: Sendable, Hashable, CaseIterable` — type definition, arithmetic, `Value<Payload>` typealias. **Strip** `Finite.Enumerable` conformance block (lines 103–122). |
| Sign.swift | `enum Sign` — type definition, negation, multiplication. **Strip** `Finite.Enumerable` block (lines 99–119). |
| Polarity.swift | `enum Polarity` — **strip** conformance. |
| Ternary.swift | `enum Ternary: Int` — **strip** conformance. |
| Monotonicity.swift | `enum Monotonicity` — **strip** conformance. |
| Bound.swift | `enum Bound` — **strip** conformance. |
| Boundary.swift | `enum Boundary` — **strip** conformance. |
| Endpoint.swift | `enum Endpoint` — **strip** conformance. |
| Gradient.swift | `enum Gradient` — **strip** conformance. |

All enum types retain their `Sendable`, `Hashable`, `CaseIterable`, and `Codable` conformances (standard library only). The `.Value<Payload>` typealiases reference `Pair`, which is in the same core package.

#### Into algebra-monoid-primitives (tier 4) — 1 file

| File | Content |
|------|---------|
| Algebra.Monoid+Bool.swift | `.conjunction` (AND monoid) and `.disjunction` (OR monoid) witnesses for Bool. Only needs Monoid + stdlib. |

#### Into algebra-semiring-primitives (tier 5) — 1 file

| File | Content |
|------|---------|
| Algebra.Semiring+Bool.swift | `.boolean` commutative semiring witness for Bool (OR/AND). Only needs Semiring + stdlib. |

#### Into algebra-group-primitives (tier 5) — 1 file

| File | Content |
|------|---------|
| Algebra.Group+Parity.swift | `.additive` Z₂ group witness for Parity. Constructs witness directly from `Parity.adding` — does NOT use `Optic.Iso`. Needs Group + Parity (from core). |

#### Into algebra-field-primitives (tier 7) — 1 file

| File | Content |
|------|---------|
| Algebra.Field+Parity.swift | `.z2` field witness for Parity. Constructs witness directly from `Parity.adding` and `Parity.multiplying` — does NOT use `Optic.Iso`. Needs Field + Parity (from core). |

**Movement total: 16 files absorbed into hierarchy packages with zero new external dependencies.**

### What Remains in swift-algebra-aggregate-primitives

**25 files** that require finite-primitives, optic-primitives, or comparison-primitives. Organized into four subsystems:

#### A. Finite.Enumerable Conformances (9 files)

The `Finite.Enumerable` conformance blocks extracted from the enum type definitions. Each becomes a `@retroactive` conformance since the types are now defined in algebra-primitives (core, a different module).

| File | Conformance | Depends On |
|------|------------|------------|
| Parity+Finite.swift | `extension Parity: @retroactive Finite.Enumerable` | finite |
| Sign+Finite.swift | `extension Sign: @retroactive Finite.Enumerable` | finite |
| Polarity+Finite.swift | `extension Polarity: @retroactive Finite.Enumerable` | finite |
| Ternary+Finite.swift | `extension Ternary: @retroactive Finite.Enumerable` | finite |
| Monotonicity+Finite.swift | `extension Monotonicity: @retroactive Finite.Enumerable` | finite |
| Bound+Finite.swift | `extension Bound: @retroactive Finite.Enumerable` | finite |
| Boundary+Finite.swift | `extension Boundary: @retroactive Finite.Enumerable` | finite |
| Endpoint+Finite.swift | `extension Endpoint: @retroactive Finite.Enumerable` | finite |
| Gradient+Finite.swift | `extension Gradient: @retroactive Finite.Enumerable` | finite |

Each conformance provides `count: Cardinal`, `ordinal: Ordinal`, and `init(__unchecked:ordinal:)`.

#### B. Z/nZ Residue Class System (9 files)

The modular arithmetic system is structurally coupled to finite-primitives: `Algebra.Residual` extends `Finite.Capacity`, and `Algebra.Z<n>` is a typealias for `Tagged<Residue<n>, Ordinal>` which gains `Finite.Enumerable` from finite-primitives' `Tagged` extensions.

| File | Content |
|------|---------|
| Algebra.Residual.swift | `protocol Algebra.Residual: Finite.Capacity` |
| Algebra.Residue.swift | `enum Algebra.Residue<let n: Int>: Residual, Hashable, Sendable` |
| Algebra.Z.swift | `typealias Algebra.Z<n> = Tagged<Residue<n>, Ordinal>` |
| Algebra.Z.Error.swift | Error enum: `.modulus`, `.bounds(Int)`, `.arithmetic` |
| Algebra.Z+Arithmetic.swift | Zero, one, negation, +, -, * on Z/nZ |
| Algebra.Z+Semiring.swift | `semiring` property returning commutative semiring witness |
| Algebra.Z+Ring.swift | `ring` property returning commutative ring witness |
| Algebra.Z+Field.swift | `field()` function returning field witness for prime modulus |
| Algebra.Z+Primality.swift | `isPrime(_:)` and extended Euclidean `inverse(_:modulus:)` |

Not separable from finite-primitives.

#### C. Optic-Based Z₂ Transport (7 files)

Generic factory methods that construct Z₂ algebraic structures via `Optic.Iso<Element, Parity>`, plus concrete instances for four binary classification types.

| File | Content | Uses |
|------|---------|------|
| Algebra.Group+Z2.swift | `Group.z2(via: Optic.Iso<Element, Parity>)` | optic, Parity(core) |
| Algebra.Group.Abelian+Z2.swift | `Group.Abelian.z2(via: Optic.Iso<Element, Parity>)` | optic, Parity(core) |
| Algebra.Field+Z2.swift | `Field.z2(via: Optic.Iso<Element, Parity>)` | optic, Parity(core) |
| Algebra.Group+Endpoint.swift | `Group<Endpoint>.z2` via inline iso | optic, Endpoint(core) |
| Algebra.Group+Bound.swift | `Group<Bound>.z2` via inline iso | optic, Bound(core) |
| Algebra.Group+Boundary.swift | `Group<Boundary>.z2` via inline iso | optic, Boundary(core) |
| Algebra.Group+Gradient.swift | `Group<Gradient>.z2` via inline iso | optic, Gradient(core) |

The generic factories use `Optic.Iso` in their signatures. The concrete instances construct `Optic.Iso` inline and delegate to the generic factories.

#### D. Comparison Integration (1 file)

| File | Content | Uses |
|------|---------|------|
| Comparison+Algebra.swift | `extension Comparison: @retroactive Finite.Enumerable` + `Comparison.Value<Payload>` typealias | comparison, finite, Pair(core) |

Retroactive conformance on a type from comparison-primitives.

#### Aggregate Dependencies

```
swift-algebra-aggregate-primitives
├── swift-algebra-field-primitives  (tier 7)  — Z/nZ witnesses, Z₂ field transport
├── swift-finite-primitives         (tier 7)  — Finite.Enumerable, Finite.Capacity, Tagged
├── swift-optic-primitives          (tier 0)  — Optic.Iso for Z₂ transport
├── swift-comparison-primitives     (tier 2)  — Comparison type for retroactive conformance
└── swift-algebra-primitives        (tier 0)  — Parity, Sign, Bound, etc. type definitions
```

**Aggregate tier: max(7, 7, 0, 2, 0) + 1 = 8.** Same as the current algebra package tier.

Note: the current aggregate also re-exports `Algebra Law Primitives` (tier 9) and `Algebra Module Primitives` (tier 8) for consumer convenience. If the temporary aggregate drops these re-exports (consumers import them directly), the aggregate stays at tier 8. If it re-exports them, it rises to tier 10.

**Recommendation**: Drop the re-exports. Consumers of the split packages should import what they need explicitly.

### Downstream Consumer Impact

Packages currently depending on `swift-algebra-primitives`:

| Consumer | Current Tier | Can Switch To | New Dep Tier | Cascade |
|----------|:-----------:|--------------|:-----------:|:-------:|
| bit-primitives | 9 | aggregate | 8 | none |
| dimension-primitives | 9 | aggregate | 8 | none |
| complex-primitives | 10 | needs analysis | — | — |
| region-primitives | 10 | needs analysis | — | — |
| algebra-linear-primitives | 11 | needs analysis | — | — |
| symmetry-primitives | 12 | needs analysis | — | — |
| geometry-primitives | 13 | needs analysis | — | — |
| space-primitives | 13 | needs analysis | — | — |
| transform-primitives | 13 | needs analysis | — | — |

Each "needs analysis" consumer requires auditing which algebra products it actually uses. If a consumer only uses the abstract hierarchy (e.g., `Algebra.Field`), it can depend on `swift-algebra-field-primitives` (tier 7) instead of the aggregate (tier 8). This audit is future work.

**numeric-primitives**: The primary motivator. After the split, numeric can depend on `swift-algebra-field-primitives` (tier 7), moving from tier 1 → tier 8. All numeric consumers are already at tier 9+, so zero cascade.

### Comparison of Options

| Criterion | A: Full Split (recommended) | B: Extract Core Only | C: Status Quo |
|-----------|:--:|:--:|:--:|
| Algebra hierarchy at low tier | tier 0–7 per level | tier 3 (one new package) | tier 8 (unchanged) |
| numeric can own its witnesses | Yes, at tier 8 | Yes, at tier 4 | No |
| Number of new packages | 9 new + 1 temp | 1 new + 1 residual | 0 |
| Consumers can target hierarchy level | Yes | Partially | No (all-or-nothing) |
| Maintenance cost | Higher (10 Package.swift files) | Low (2 Package.swift files) | None |
| Follows existing patterns | Yes (mirrors current multi-product structure as packages) | Yes | — |
| Enables future aggregate dissolution | Yes — consumers migrate to specific level | Partially | No |

Option B would create `swift-algebra-core-primitives` containing Core through Field (the abstract hierarchy as a single package, tier 3), leaving the current package as the aggregate. This is simpler but doesn't let consumers target a specific algebraic level.

### @retroactive Conformance Implications

Splitting the enum type definitions (in core, tier 0) from their `Finite.Enumerable` conformances (in aggregate, tier 8) requires `@retroactive` annotations. This is:

- **Correct**: The conformances are genuinely retroactive — added in a different module from the type definition.
- **Safe**: There is exactly one conformance provider (the aggregate). No duplicate conformance risk.
- **Standard**: The same pattern already exists in the codebase (`Comparison+Algebra.swift` already uses `@retroactive`).

When the aggregate is eventually dissolved, these conformances move to their final homes. Each move is a `@retroactive` → direct conformance transition (or remains `@retroactive` if the final home is still a different module from the type definition).

## Outcome

**Status**: RECOMMENDATION

### Recommended Approach

Option A: Split the algebraic hierarchy into individual packages. Move 16 files out of the aggregate into their natural hierarchy packages. The remaining ~25 files form a temporary `swift-algebra-aggregate-primitives` at tier 8.

### Implementation Sequence

1. **Create 9 hierarchy packages** from the existing targets (Core, Magma, Monoid, Group, Semiring, Ring, Field, Module, Law). Each gets its own `Package.swift` with the dependency chain.

2. **Move 12 files into algebra-primitives (core)**: Pair, Product, Bool+XOR, and the 9 enum types with `Finite.Enumerable` conformance blocks stripped.

3. **Move 4 witness files into hierarchy packages**: Bool monoid → monoid, Bool semiring → semiring, Parity group → group, Parity field → field.

4. **Create swift-algebra-aggregate-primitives**: Contains the remaining ~25 files with a new exports.swift. Dependencies: algebra-field, algebra-core, finite, optic, comparison.

5. **Update all consumers**: Change `.package(path: "../swift-algebra-primitives")` references to target the specific hierarchy package or the aggregate as appropriate.

6. **Regenerate computed tiers**: Run `./Scripts/compute-tiers.sh` to verify the new tier assignments.

### Future Work

- **Consumer audit**: Analyze each of the 9 downstream packages to determine if they can depend on a specific hierarchy package instead of the aggregate.
- **Aggregate dissolution**: Determine final homes for the ~25 aggregate files. Candidate strategies: conformances move to consuming packages, Z/nZ becomes its own package, Optic Z₂ transport moves to optic-primitives or a dedicated integration package.
- **numeric-primitives reordering**: Once the split is complete, add `swift-algebra-field-primitives` as a dependency of numeric-primitives to own algebraic witnesses for numeric types.

## References

- `Computed Primitives Tiers.md` — product-level tier analysis showing algebra spread of 19
- `Primitives Tiers.md` — architectural issue: numeric/algebra ordering
- `algebra-adt-package-relationship.md` — dependency direction between algebra and container packages
- `vector-primitives-role-and-dependency-analysis.md` — vector-primitives dependency audit (related)
