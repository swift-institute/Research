# Algebra Split Tier Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-05
status: DECISION
---
-->

## Context

The algebra-primitives package was split into 10 packages per the plan in `abstract-stargazing-kahan.md` and research in `algebra-primitives-package-split.md`. Post-split tier computation reveals tier drift from plan intentions and identifies the root cause as a dependency chain issue.

**Trigger**: Post-implementation tier verification showed consumer packages at higher tiers than expected.

## Question

Why did the algebra split cause tier inflation, and what optimizations are possible to achieve intended tiers?

## Analysis

### Tier Comparison: Plan vs Actual

| Package | Plan Tier | Actual Tier | Delta | Notes |
|---------|:---------:|:-----------:|:-----:|-------|
| swift-algebra-primitives (core) | 0 | 0 | ✓ | As planned |
| swift-algebra-magma-primitives | 3 | 3 | ✓ | As planned |
| swift-algebra-monoid-primitives | 4 | 4 | ✓ | As planned |
| swift-algebra-group-primitives | 5 | 5 | ✓ | As planned |
| swift-algebra-semiring-primitives | 5 | 5 | ✓ | As planned |
| swift-algebra-ring-primitives | 6 | 6 | ✓ | As planned |
| swift-algebra-field-primitives | 7 | 7 | ✓ | As planned |
| swift-algebra-module-primitives | 8 | 8 | ✓ | As planned |
| swift-algebra-law-primitives | 9 | 9 | ✓ | As planned |
| swift-algebra-aggregate-primitives | **8** | **10** | **+2** | Root cause |

The hierarchy packages (core through law) are all at their planned tiers. The aggregate is 2 tiers higher than planned.

### Root Cause Analysis

The plan stated aggregate should be tier 8 with dependencies:
- algebra-field@7, finite@7, optic@0, comparison@2

Actual aggregate dependencies:
- algebra-field@7, algebra-group@5, **algebra-law@9**, algebra@0, comparison@2, finite@7, optic@0

**The issue**: `algebra-law@9` was added as a package dependency (for test target use). This pulled the aggregate's package tier to 10 (`law@9 + 1`).

Looking at Package.swift:
```swift
dependencies: [
    .package(path: "../swift-algebra-primitives"),
    .package(path: "../swift-algebra-field-primitives"),
    .package(path: "../swift-algebra-group-primitives"),
    .package(path: "../swift-comparison-primitives"),
    .package(path: "../swift-finite-primitives"),
    .package(path: "../swift-optic-primitives"),
    .package(path: "../swift-algebra-law-primitives"),  // ← This is the +2 culprit
],
```

The law-primitives dependency was added for the **test target** only, not the source target. But SPM computes package-level tier from all package dependencies regardless of which target uses them.

### Consumer Tier Cascade

The aggregate tier inflation cascades to consumers:

| Consumer | Pre-Split Tier | Plan Tier | Actual Tier | Delta |
|----------|:--------------:|:---------:|:-----------:|:-----:|
| swift-bit-primitives | 9 | 9 | 11 | +2 |
| swift-dimension-primitives | 9 | 9 | 11 | +2 |
| swift-complex-primitives | 10 | 10 | 12 | +2 |
| swift-region-primitives | 10 | 10 | 12 | +2 |
| swift-algebra-linear-primitives | 11 | 11 | 12 | +1 |
| swift-geometry-primitives | 13 | 13 | 14 | +1 |
| swift-symmetry-primitives | 12 | — | 13 | — |

The +2 delta on bit and dimension cascades: dimension's consumers get +1 to +2, etc.

### Total Tier Inflation

Before split: max tier 19
After split: max tier 21

The +2 at aggregate level adds +2 to the entire downstream chain (kernel→darwin→cache at the top).

## Options

### Option A: Remove law-primitives from aggregate package dependencies

Move law-primitives out of the aggregate Package.swift entirely. The aggregate's test target currently imports `Algebra_Law_Primitives` for exhaustive law verification tests.

**Resolution**: Move law-dependent tests to a separate test-only package, or duplicate the minimal law verification logic in aggregate tests.

**Tier effect**: Aggregate drops from 10 to 8 (max dep becomes law@9→field@7). All consumers drop by 2 tiers.

**Trade-off**: Law verification tests would need restructuring.

### Option B: Create algebra-aggregate-test-support package

Keep aggregate at tier 8 with field@7 as max dependency. Create a separate `swift-algebra-aggregate-test-support-primitives` package at tier 10 that depends on aggregate + law. Only test code depends on this.

**Tier effect**: Same as A — aggregate at 8, consumers drop.

**Trade-off**: Additional package complexity.

### Option C: Accept tier inflation

Law-based exhaustive verification is valuable. Keep the structure as-is.

**Tier effect**: None — current state.

**Trade-off**: Entire downstream chain is +2 tiers from optimal.

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Aggregate tier | 8 | 8 | 10 |
| Max ecosystem tier | 19 | 19 | 21 |
| Test coverage | Reduced or duplicated | Full | Full |
| Package count | 10 | 11 | 10 |
| Implementation effort | Medium | High | None |

## Constraints

1. SPM computes package tier from ALL package dependencies, not per-target
2. Test targets can depend on packages that inflate package-level tier
3. Law-primitives at tier 9 is structurally necessary (depends on module@8)

## Outcome

**Status**: DECISION

**Resolution**: Option A implemented — law verification tests moved to law-primitives package.

The law verification tests (`Algebra.Law.Verification Tests.swift`, `Algebra.Bool Tests.swift`) were moved from aggregate to a new test target `Algebra Aggregate Law Verification Tests` in law-primitives. This inverts the test ownership: law tests aggregate types rather than aggregate depending on law.

### Changes Made

1. Added `swift-algebra-aggregate-primitives` as test dependency to law-primitives
2. Created new test target `Algebra Aggregate Law Verification Tests` in law-primitives
3. Moved test files with updated imports (`import` instead of `@testable import`)
4. Removed `swift-algebra-law-primitives` from aggregate Package.swift
5. Regenerated computed tiers

### Verified Tier Results

| Package | Before | After | Delta |
|---------|:------:|:-----:|:-----:|
| swift-algebra-aggregate-primitives | 10 | 8 | -2 |
| swift-bit-primitives | 11 | 9 | -2 |
| swift-dimension-primitives | 11 | 9 | -2 |
| Ecosystem max tier | 21 | 19 | -2 |

All tiers now match the original plan.

## References

- `/Users/coen/Developer/swift-primitives/Research/algebra-primitives-package-split.md`
- `/Users/coen/.claude/plans/abstract-stargazing-kahan.md`
- `/Users/coen/Developer/swift-primitives/Documentation.docc/Computed Primitives Tiers.md`
- `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md`
