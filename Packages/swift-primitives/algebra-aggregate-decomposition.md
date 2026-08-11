# Algebra Aggregate Decomposition

<!--
---
version: 1.0.0
last_updated: 2026-02-05
status: RECOMMENDATION
---
-->

## Context

`swift-algebra-aggregate-primitives` was created as a temporary holding package during the algebra hierarchy split. It currently sits at tier 8 with 28 source files bundling four distinct concerns:

1. **Retroactive Finite.Enumerable conformances** (9 files) — Parity, Sign, Polarity, Ternary, Monotonicity, Bound, Boundary, Endpoint, Gradient
2. **Z/nZ modular arithmetic** (9 files) — Algebra.Z, Algebra.Residual, Algebra.Residue, arithmetic, semiring, ring, field, primality
3. **Optic-based Z₂ transport** (7 files) — Group+Z2, Group.Abelian+Z2, Field+Z2, plus concrete witnesses for Bound, Boundary, Endpoint, Gradient
4. **Comparison+Algebra integration** (1 file) — Finite.Enumerable conformance + Value typealias for Comparison

**Trigger**: Post-split architecture review to determine if the aggregate can be eliminated.

**Constraints**:
- Retroactive conformances require both the type definition package AND the protocol definition package as dependencies
- Z/nZ depends on Finite.Capacity (from finite-primitives)
- Z₂ transport depends on Optic.Iso (from optic-primitives) AND group/field (from hierarchy)
- Consumers currently depend on aggregate as the "one import for everything" facade

## Question

Can `swift-algebra-aggregate-primitives` be decomposed into existing packages or eliminated entirely, and what are the tier implications?

## Analysis

### Component 1: Retroactive Finite.Enumerable Conformances

**Files**: 9 `{Type}+Finite.swift` files

**Dependencies**:
- Type definitions from `swift-algebra-primitives` (tier 0)
- `Finite.Enumerable` protocol from `swift-finite-primitives` (tier 7)

**Options**:

| Option | Description | Tier Effect |
|--------|-------------|-------------|
| A1. Keep in aggregate | Status quo | Aggregate stays tier 8 |
| A2. Move to finite-primitives | finite adds algebra@0 dependency, conformances in finite | finite stays tier 7 (algebra@0 < index@6) |
| A3. Move to algebra-primitives | algebra adds finite@7 dependency, conformances in algebra | algebra rises 0→8 ❌ |
| A4. New package: algebra-finite-primitives | Dedicated integration package | New tier 8 package |

**Recommendation**: **A2 — Move to finite-primitives**

Finite-primitives already depends on index@6. Adding algebra@0 doesn't change its tier. The conformances are "types from algebra that are finite" — logically belongs where Finite.Enumerable is defined.

### Component 2: Comparison+Algebra Integration

**Files**: 1 `Comparison+Algebra.swift`

**Dependencies**:
- `Comparison` type from `swift-comparison-primitives` (tier 2)
- `Finite.Enumerable` from `swift-finite-primitives` (tier 7)
- `Pair` from `swift-algebra-primitives` (tier 0)

**Options**:

| Option | Description | Tier Effect |
|--------|-------------|-------------|
| B1. Keep in aggregate | Status quo | — |
| B2. Move to finite-primitives | Along with other Finite conformances | finite stays tier 7 (needs comparison@2) |
| B3. Move to comparison-primitives | comparison adds finite@7, algebra@0 | comparison rises 2→8 ❌ |
| B4. New package: comparison-finite-primitives | Dedicated integration | New tier 8 package |

**Recommendation**: **B2 — Move to finite-primitives**

Same logic as A2. The `Pair` typealias can be dropped (it's just `Pair<Comparison, Payload>` which consumers can write directly), or finite can add algebra@0 to enable it.

### Component 3: Z/nZ Modular Arithmetic

**Files**: 9 files (Algebra.Z, Algebra.Residual, Algebra.Residue, +Arithmetic, +Semiring, +Ring, +Field, +Primality, .Error)

**Dependencies**:
- `Algebra.Residual` extends `Finite.Capacity` — needs finite-primitives (tier 7)
- `Algebra.Z<n>` is `Tagged<Residue<n>, Ordinal>` — needs identity-primitives (tier 0) and ordinal-primitives (tier 4)
- Ring/Field extensions need algebra-ring (tier 6) and algebra-field (tier 7)
- Uses `Cardinal`, `Ordinal` from ordinal/cardinal-primitives

**Options**:

| Option | Description | Tier Effect |
|--------|-------------|-------------|
| C1. Keep in aggregate | Status quo | — |
| C2. New package: swift-algebra-modular-primitives | Dedicated Z/nZ package | Tier 8 (max dep: field@7) |
| C3. Move to algebra-field-primitives | field adds finite@7 | field stays tier 7 (finite@7 = ring@6+1) — NO, would be 8 |
| C4. Move to algebra-ring-primitives | ring adds finite@7 | ring rises 6→8 ❌ |

**Analysis of C2**:
- Creates `swift-algebra-modular-primitives` at tier 8
- Dependencies: algebra-field@7, finite@7 (for Capacity), identity@0 (for Tagged)
- Contains: All Z/nZ files
- Clean separation: "modular arithmetic" is a distinct mathematical domain

**Analysis of C3**:
- Field is tier 7 (max dep: ring@6)
- Adding finite@7 would make field tier 8 (max dep: finite@7)
- This cascades: module@8→9, law@9→10, aggregate elimination impossible
- ❌ Rejected

**Recommendation**: **C2 — New package: swift-algebra-modular-primitives**

Z/nZ is mathematically distinct from the abstract algebraic hierarchy. A dedicated package at tier 8 is appropriate.

### Component 4: Optic-based Z₂ Transport

**Files**: 7 files (Group+Z2, Group.Abelian+Z2, Field+Z2, Group+Bound, Group+Boundary, Group+Endpoint, Group+Gradient)

**Dependencies**:
- `Optic.Iso` from swift-optic-primitives (tier 0)
- `Algebra.Group`, `Algebra.Field` from hierarchy packages
- Concrete witnesses reference Parity (tier 0), Bound/Boundary/etc (tier 0)

**Options**:

| Option | Description | Tier Effect |
|--------|-------------|-------------|
| D1. Keep in aggregate | Status quo | — |
| D2. Move generic Z2 to group/field | Group+Z2 → group-primitives, Field+Z2 → field-primitives | group adds optic@0, field adds optic@0 — no tier change |
| D3. Move concrete witnesses to algebra-primitives | Bound/Boundary/etc witnesses → algebra@0 | algebra adds group@5, field@7 → tier 8 ❌ |
| D4. New package: swift-algebra-z2-primitives | Dedicated Z₂ transport | Tier 8 package |
| D5. Split: generic to hierarchy, concrete to new package | Best of D2 + D4 | group/field unchanged, new tier 8 for concrete |

**Analysis of D2**:
- `Algebra.Group.z2(via:)` is a generic factory — belongs with Group
- `Algebra.Field.z2` is a generic factory — belongs with Field
- Adding optic@0 to group@5 and field@7 doesn't change their tiers
- ✓ Clean ownership

**Analysis of D5**:
- Generic `z2(via:)` methods → group-primitives and field-primitives
- Concrete `.z2` witnesses for Bound, Boundary, Endpoint, Gradient → stays in aggregate OR new package
- These concrete witnesses depend on both the enum types (algebra@0) AND the group/field transport methods

**Recommendation**: **D2 for generic methods, keep concrete in aggregate (or modular package)**

The concrete `.z2` static properties for Bound/Boundary/Endpoint/Gradient can stay with whatever package holds the Finite.Enumerable conformances, since they're closely related (both extend the same types with algebraic structure).

### Synthesis: Optimal Decomposition

Based on the analysis:

| Component | Destination | Files | Tier Impact |
|-----------|-------------|-------|-------------|
| Finite.Enumerable conformances (9 types) | swift-finite-primitives | 9 | finite stays 7 |
| Comparison+Finite.Enumerable | swift-finite-primitives | 1 | finite stays 7 |
| Generic Z₂ transport (Group.z2(via:), Field.z2) | swift-algebra-group/field-primitives | 3 | unchanged |
| Concrete Z₂ witnesses (Bound.z2, etc.) | swift-finite-primitives (with conformances) | 4 | finite stays 7 (needs group@5) |
| Z/nZ modular arithmetic | swift-algebra-modular-primitives (NEW) | 9 | new tier 8 |

**Wait — tier recalculation for finite**:
- Current finite deps: index@6, ordinal@4, identity@0 → tier 7
- Add algebra@0: still max 6 → tier 7 ✓
- Add comparison@2: still max 6 → tier 7 ✓
- Add group@5: still max 6 → tier 7 ✓ (group@5 < index@6)

All components can move to finite-primitives without changing its tier, EXCEPT Z/nZ which needs field@7 (would push finite to tier 8).

### Revised Optimal Decomposition

| Component | Destination | Tier Impact |
|-----------|-------------|-------------|
| Finite.Enumerable conformances (all 10) | swift-finite-primitives | finite stays 7 |
| Generic Z₂ transport | swift-algebra-group/field-primitives | group/field unchanged |
| Concrete Z₂ witnesses | swift-finite-primitives | finite stays 7 |
| Z/nZ modular arithmetic | swift-algebra-modular-primitives (NEW) | new tier 8 |

**Result**: Aggregate is eliminated. One new package (modular) at tier 8.

### Consumer Migration

Current consumers import `Algebra_Aggregate_Primitives` to get:
- Enum types (from algebra-primitives) ✓ re-exported through hierarchy
- Finite.Enumerable conformances → now from finite-primitives
- Z/nZ → now from algebra-modular-primitives
- Algebra hierarchy → unchanged

Consumers would need:
```swift
// Before
import Algebra_Aggregate_Primitives

// After
import Algebra_Field_Primitives   // or whatever hierarchy level needed
import Finite_Primitives          // if using Finite.Enumerable on algebra types
import Algebra_Modular_Primitives // if using Z/nZ
```

Most consumers (bit, dimension, complex, region, linear, geometry) only need the hierarchy + finite conformances. Z/nZ is specialized.

## Comparison

| Criterion | Keep Aggregate | Decompose to Existing + New Modular |
|-----------|----------------|-------------------------------------|
| Package count | 10 (current) | 10 (aggregate removed, modular added) |
| Max tier | 8 (aggregate) | 8 (modular) |
| Single import convenience | ✓ | ✗ (2-3 imports) |
| Semantic clarity | ✗ (bundled concerns) | ✓ (each package has one purpose) |
| Dependency precision | ✗ (all or nothing) | ✓ (import only what you need) |
| finite-primitives scope | Types only | Types + algebra/comparison conformances |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Decompose the aggregate as follows:

### Phase 1: Move Finite.Enumerable conformances to finite-primitives
1. Add `swift-algebra-primitives` and `swift-comparison-primitives` as dependencies to finite-primitives
2. Move all 10 `{Type}+Finite.swift` files to finite-primitives
3. Update finite-primitives exports to include conformances

### Phase 2: Move generic Z₂ transport to hierarchy packages
1. Move `Algebra.Group+Z2.swift` and `Algebra.Group.Abelian+Z2.swift` to swift-algebra-group-primitives
2. Move `Algebra.Field+Z2.swift` to swift-algebra-field-primitives
3. Add `swift-optic-primitives` dependency to both (tier 0, no impact)

### Phase 3: Move concrete Z₂ witnesses to finite-primitives
1. Add `swift-algebra-group-primitives` as dependency to finite-primitives (tier 5 < index@6, no tier change)
2. Move `Algebra.Group+Bound.swift`, `+Boundary.swift`, `+Endpoint.swift`, `+Gradient.swift` to finite-primitives

### Phase 4: Create swift-algebra-modular-primitives
1. Create new package at tier 8
2. Dependencies: algebra-field@7, finite@7, identity@0
3. Move all Z/nZ files (Algebra.Z.*, Algebra.Residual, Algebra.Residue)

### Phase 5: Update consumers
1. Replace `import Algebra_Aggregate_Primitives` with appropriate specific imports
2. Test all consumers build

### Phase 6: Delete swift-algebra-aggregate-primitives
1. Remove submodule
2. Archive GitHub repo

**Tier verification after decomposition**:
- finite-primitives: max(index@6, group@5, comparison@2, algebra@0) = 6 → tier 7 ✓
- algebra-modular-primitives: max(field@7, finite@7) = 7 → tier 8 ✓
- Consumers: same or lower tiers (no aggregate@8 dependency)

## References

- `/Users/coen/Developer/swift-primitives/Research/algebra-primitives-package-split.md`
- `/Users/coen/Developer/swift-primitives/Research/algebra-split-tier-analysis.md`
- `/Users/coen/Developer/swift-primitives/Documentation.docc/Computed Primitives Tiers.md`
