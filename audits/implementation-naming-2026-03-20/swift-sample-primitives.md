# swift-sample-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Skills**: naming, implementation
**Scope**: All 20 source files in `Sources/`
**Status**: READ-ONLY audit

## Summary Table

| ID | Severity | Rule | Location | Description |
|----|----------|------|----------|-------------|
| SAMP-001 | HIGH | [API-NAME-002] | `Sample.Batch+StandardDeviation.swift` | Compound method `standardDeviation` |
| SAMP-002 | HIGH | [API-NAME-002] | `Sample.Batch+StandardDeviation.swift` | Compound property `standardDeviation` (Duration convenience) |
| SAMP-003 | HIGH | [API-NAME-002] | `Sample.Batch+StandardDeviation.swift` | Compound property `standardDeviation` (Double convenience) |
| SAMP-004 | HIGH | [API-NAME-002] | `Sample.Batch+CoefficientOfVariation.swift` | Compound method `coefficientOfVariation` |
| SAMP-005 | HIGH | [API-NAME-002] | `Sample.Batch+CoefficientOfVariation.swift` | Compound property `coefficientOfVariation` (Duration convenience) |
| SAMP-006 | HIGH | [API-NAME-002] | `Sample.Batch+CoefficientOfVariation.swift` | Compound property `coefficientOfVariation` (Double convenience) |
| SAMP-007 | HIGH | [API-NAME-002] | `Sample.Batch+MedianAbsoluteDeviation.swift` | Compound method `medianAbsoluteDeviation` |
| SAMP-008 | HIGH | [API-NAME-002] | `Sample.Batch+MedianAbsoluteDeviation.swift` | Compound property `medianAbsoluteDeviation` (Duration convenience) |
| SAMP-009 | HIGH | [API-NAME-002] | `Sample.Batch+MedianAbsoluteDeviation.swift` | Compound property `medianAbsoluteDeviation` (Double convenience) |
| SAMP-010 | HIGH | [API-NAME-002] | `Sample.Batch+MedianAbsoluteDeviation.swift` | Compound method `outlierCount` |
| SAMP-011 | HIGH | [API-NAME-002] | `Sample.Batch+MedianAbsoluteDeviation.swift` | Compound method `outlierCount` (Duration convenience) |
| SAMP-012 | HIGH | [API-NAME-002] | `Sample.Batch+MedianAbsoluteDeviation.swift` | Compound method `outlierCount` (Double convenience) |
| SAMP-013 | HIGH | [API-NAME-002] | `Sample.Comparison.swift` | Compound method `isRegression` |
| SAMP-014 | HIGH | [API-NAME-002] | `Sample.Comparison.swift` | Compound method `isImprovement` |
| SAMP-015 | HIGH | [API-NAME-002] | `Sample.Comparison.swift` | Compound method `exceedsTolerance` |
| SAMP-016 | MEDIUM | [API-NAME-002] | `Sample.Comparison.swift` | Compound convenience properties `isRegression`, `isImprovement` (Duration + Double, 4 instances) |
| SAMP-017 | MEDIUM | [API-NAME-002] | `Sample.Comparison.swift` | Compound convenience methods `exceedsTolerance` (Duration + Double, 2 instances) |
| SAMP-018 | LOW | [API-NAME-002] | `Sample.Polarity.swift` | Compound enum cases `lowerIsBetter`, `higherIsBetter` |
| SAMP-019 | LOW | [API-NAME-002] | `Sample.Regression.Fit.swift` | Compound property `meanSquaredError` |
| SAMP-020 | LOW | [IMPL-INTENT] | `Sample.Batch ~Copyable.swift` | `_insertionSort` reads as mechanism, not intent |
| SAMP-021 | INFO | [API-IMPL-005] | `Sample.Batch.Storage.swift` | `_SampleBatchStorage` uses compound name with underscore prefix |
| SAMP-022 | INFO | [API-NAME-002] | `Sample.Regression.Fit.swift` | `rSquared` — domain-standard abbreviation, borderline compound |

**Totals**: 15 HIGH, 4 MEDIUM, 3 LOW, 2 INFO

---

## Detailed Findings

### SAMP-001 — Compound method `standardDeviation` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Batch+StandardDeviation.swift:11`
**Rule**: [API-NAME-002]

```swift
public func standardDeviation(
    using averaging: Sample.Averaging<Element>
) -> Element?
```

`standardDeviation` is a compound identifier joining "standard" and "deviation". Under [API-NAME-002], this should use a nested accessor pattern.

**Suggested remediation**: `deviation.standard(using:)` or introduce a `Sample.Deviation` namespace with a `.standard` accessor. Statistical terminology is well-established, so the nested form `batch.deviation.standard` reads naturally.

---

### SAMP-002, SAMP-003 — Compound property `standardDeviation` (convenience) [HIGH]

**Files**: `Sample.Batch+StandardDeviation.swift:32` (Duration), `:41` (Double)
**Rule**: [API-NAME-002]

Convenience properties mirror the compound name from SAMP-001.

---

### SAMP-004 — Compound method `coefficientOfVariation` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Batch+CoefficientOfVariation.swift:11`
**Rule**: [API-NAME-002]

```swift
public func coefficientOfVariation(
    using averaging: Sample.Averaging<Element>
) -> Double?
```

Three-word compound identifier. The statistical abbreviation "CV" is standard, but the full name violates [API-NAME-002].

**Suggested remediation**: `variation.coefficient(using:)` or just `cv(using:)` since CV is universally understood in statistics. Alternatively, a `Sample.Variation` namespace.

---

### SAMP-005, SAMP-006 — Compound property `coefficientOfVariation` (convenience) [HIGH]

**Files**: `Sample.Batch+CoefficientOfVariation.swift:28` (Duration), `:37` (Double)
**Rule**: [API-NAME-002]

Convenience properties mirror the compound name from SAMP-004.

---

### SAMP-007 — Compound method `medianAbsoluteDeviation` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Batch+MedianAbsoluteDeviation.swift:11`
**Rule**: [API-NAME-002]

```swift
public func medianAbsoluteDeviation(
    using averaging: Sample.Averaging<Element>
) -> Element?
```

Three-word compound identifier. "MAD" is the standard abbreviation.

**Suggested remediation**: `deviation.medianAbsolute(using:)` or `mad(using:)`. If a `Sample.Deviation` namespace is introduced (see SAMP-001), this naturally becomes `deviation.medianAbsolute` or `deviation.mad`.

---

### SAMP-008, SAMP-009 — Compound property `medianAbsoluteDeviation` (convenience) [HIGH]

**Files**: `Sample.Batch+MedianAbsoluteDeviation.swift:73` (Duration), `:88` (Double)
**Rule**: [API-NAME-002]

Convenience properties mirror the compound name from SAMP-007.

---

### SAMP-010 — Compound method `outlierCount` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Batch+MedianAbsoluteDeviation.swift:45`
**Rule**: [API-NAME-002]

```swift
public func outlierCount(
    using averaging: Sample.Averaging<Element>,
    threshold k: Double = 3.0
) -> Int?
```

Compound method joining "outlier" and "count".

**Suggested remediation**: `outliers.count(using:threshold:)` via a nested `outliers` accessor, or simply `outliers(using:threshold:)` returning a count (renaming the return semantics in documentation).

---

### SAMP-011, SAMP-012 — Compound method `outlierCount` (convenience) [HIGH]

**Files**: `Sample.Batch+MedianAbsoluteDeviation.swift:79` (Duration), `:94` (Double)
**Rule**: [API-NAME-002]

Convenience methods mirror the compound name from SAMP-010.

---

### SAMP-013 — Compound method `isRegression` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Comparison.swift:66`
**Rule**: [API-NAME-002]

```swift
public func isRegression(
    using averaging: Sample.Averaging<Element>
) -> Bool
```

Compound name joining "is" and "regression". Standard Swift convention uses `is` prefix for Boolean properties, but the issue here is that "Regression" is a domain noun that deserves its own namespace rather than being flattened into a compound method name.

**Suggested remediation**: `result.isRegression` via a computed `result` accessor that returns a comparison result type, or simply keep `isRegression` — this is borderline since `is` + adjective/noun is standard Swift Boolean naming (`isEmpty`, `isZero`).

**Note**: This finding is HIGH by strict [API-NAME-002] reading, but `is`-prefixed Boolean properties are a well-established Swift convention. Consider whether `is` + noun constitutes a "compound name" under the rule, or an idiomatic pattern. If the latter, downgrade to INFO.

---

### SAMP-014 — Compound method `isImprovement` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Comparison.swift:78`
**Rule**: [API-NAME-002]

Same pattern as SAMP-013. `isImprovement(using:)` follows Swift Boolean naming convention.

---

### SAMP-015 — Compound method `exceedsTolerance` [HIGH]

**File**: `Sources/Sample Primitives Core/Sample.Comparison.swift:90`
**Rule**: [API-NAME-002]

```swift
public func exceedsTolerance(
    _ tolerance: Double,
    using averaging: Sample.Averaging<Element>
) -> Bool
```

Compound verb-noun joining "exceeds" and "tolerance".

**Suggested remediation**: `exceeds(tolerance:using:)` — the tolerance parameter already carries the domain semantics. The method name should just be the verb.

---

### SAMP-016 — Compound convenience properties on Comparison [MEDIUM]

**File**: `Sources/Sample Primitives Core/Sample.Comparison.swift:112-120,140-148`
**Rule**: [API-NAME-002]

Four convenience properties (`isRegression`, `isImprovement` for Duration and Double) mirror SAMP-013/014. MEDIUM because they are downstream of the primary violation.

---

### SAMP-017 — Compound convenience methods on Comparison [MEDIUM]

**File**: `Sources/Sample Primitives Core/Sample.Comparison.swift:124-126,153-155`
**Rule**: [API-NAME-002]

Two convenience methods (`exceedsTolerance` for Duration and Double) mirror SAMP-015.

---

### SAMP-018 — Compound enum cases `lowerIsBetter`, `higherIsBetter` [LOW]

**File**: `Sources/Sample Primitives Core/Sample.Polarity.swift:10-11`
**Rule**: [API-NAME-002]

```swift
public enum Polarity: Sendable, Hashable {
    case lowerIsBetter
    case higherIsBetter
}
```

Three-word compound enum cases. These are descriptive and self-documenting, but violate the no-compound-identifiers rule.

**Suggested remediation**: `.lower` / `.higher` with documentation clarifying the "is better" semantics. The type name `Polarity` already implies directionality. Usage becomes `polarity: .lower` which reads naturally in context: "polarity is lower (is better)".

---

### SAMP-019 — Compound property `meanSquaredError` [LOW]

**File**: `Sources/Sample Primitives Core/Sample.Regression.Fit.swift:34`
**Rule**: [API-NAME-002]

```swift
public let meanSquaredError: Double
```

Three-word compound property. "MSE" is the standard abbreviation.

**Suggested remediation**: Consider `mse` (universally understood) or a nested `error.meanSquared` via a computed accessor. LOW because this is a stored property on a small value type where nesting is less natural.

---

### SAMP-020 — `_insertionSort` reads as mechanism [LOW]

**File**: `Sources/Sample Primitives Core/Sample.Batch ~Copyable.swift:67`
**Rule**: [IMPL-INTENT]

```swift
static func _insertionSort(
    _ base: UnsafeMutablePointer<Element>,
    count: Int,
    comparator: Ordering.Comparator<Element>
)
```

The method name describes the algorithm (mechanism) rather than the intent (sorting). This is an internal/underscored method, so the impact is low.

**Suggested remediation**: `_sort` — the algorithm choice is an implementation detail. The method is `@usableFromInline` and underscored, so this is advisory.

---

### SAMP-021 — `_SampleBatchStorage` compound internal name [INFO]

**File**: `Sources/Sample Primitives Core/Sample.Batch.Storage.swift:8`
**Rule**: [API-IMPL-005]

```swift
final class _SampleBatchStorage<Element: ~Copyable>: @unchecked Sendable
```

The class name is `_SampleBatchStorage` — a compound name with underscore prefix. This is internal API (not public), so the impact is minimal. The file is correctly named `Sample.Batch.Storage.swift`, suggesting the intent is `Sample.Batch.Storage` nesting.

**Suggested remediation**: Nest as `extension Sample.Batch { class _Storage }` if the compiler supports it for generic contexts. Otherwise, acceptable as internal plumbing.

---

### SAMP-022 — `rSquared` borderline compound [INFO]

**File**: `Sources/Sample Primitives Core/Sample.Regression.Fit.swift:29`
**Rule**: [API-NAME-002]

```swift
public let rSquared: Double
```

"rSquared" joins "R" and "squared", but R-squared (R^2) is a universally recognized single concept in statistics — the coefficient of determination. This is analogous to how `UUID` is a single concept, not a compound of "universally", "unique", and "identifier".

**Assessment**: No remediation needed. Domain-standard single concept.

---

## Architectural Observations

### Positive Findings

1. **[API-NAME-001] PASS**: All types correctly use `Nest.Name` pattern: `Sample.Batch`, `Sample.Accumulator`, `Sample.Averaging`, `Sample.Metric`, `Sample.Comparison`, `Sample.Polarity`, `Sample.Regression`, `Sample.Regression.Fit`.

2. **[API-IMPL-005] PASS**: One type per file throughout. File naming correctly mirrors type nesting.

3. **[IMPL-002] / [PATTERN-017] PASS**: No `.rawValue` leakage at call sites. Internal storage access uses `_storage.base[i]` which is appropriately confined to implementation.

4. **[PRIM-FOUND-001] PASS**: No Foundation imports anywhere.

5. **Witness pattern**: `Sample.Averaging<Element>` correctly uses the defunctionalized witness pattern for type-erased arithmetic. Clean static factories (`.duration`, `.real`, `.integer`, `.natural`).

6. **~Copyable support**: Well-structured borrowing accessors (`withMin`, `withMax`, `withMedian`, `withPercentile`) alongside value-returning accessors for `Copyable` elements.

### Remediation Strategy

The 15 compound method/property names cluster into 4 groups that can be addressed systematically:

| Group | Compound Names | Suggested Namespace |
|-------|---------------|-------------------|
| Deviation metrics | `standardDeviation`, `medianAbsoluteDeviation` | `deviation.standard`, `deviation.mad` |
| Variation metrics | `coefficientOfVariation` | `variation.coefficient` or `cv` |
| Outlier detection | `outlierCount` | `outliers.count` or `outliers(threshold:)` |
| Comparison predicates | `isRegression`, `isImprovement`, `exceedsTolerance` | Borderline — `is` prefix is Swift convention; `exceeds(tolerance:)` straightforward fix |

A `Sample.Batch.Deviation` nested accessor type could unify the first two groups, producing:
```swift
batch.deviation.standard(using: .duration)
batch.deviation.mad(using: .real)
batch.deviation.coefficient(using: .real)  // CV
```
