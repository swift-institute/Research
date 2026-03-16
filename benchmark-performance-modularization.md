# Benchmark and Performance Modularization

<!--
---
version: 2.1.0
last_updated: 2026-03-03
status: IMPLEMENTED
tier: 3
---
-->

## Context

swift-tests contains two sibling modules that both deal with performance measurement:

- **Tests Benchmark** (9 files) — trait-integrated benchmarking: `Test.Benchmark.*`
- **Tests Performance** (8 files) — standalone performance utilities: `Tests.*`

An audit against the modularization skill revealed near-duplicate `Measurement`, `Metric`, `Error`, `measure()`, and `printPerformance()` types across both modules. This research investigates where in the five-layer architecture these types optimally belong, applying the Semantic Uniform Ecosystem Principle: one concept, one location, at the lowest correct layer.

**Trigger**: [RES-001] Design decision cannot be made without systematic analysis.
**Scope**: [RES-002a] Ecosystem-wide — affects packages across all three layers.
**Precedent risk**: High. Establishes the measurement data model for the entire ecosystem.

## Question

1. Where should duration-collection, statistical measurement, and metric types live?
2. Should the measurement type be generic over the measured quantity?
3. What is the correct decomposition of the benchmarking/performance domain?

---

## Prior Art Survey [RES-021]

### Ecosystem Comparison

| Ecosystem | Data Collection | Statistical Analysis | Reporting | Separation |
|-----------|----------------|---------------------|-----------|------------|
| Rust/criterion | `Measurement` trait (generic) | `stats/` module | `report.rs`, `plot/` | Module boundaries |
| Haskell | `criterion-measurement` pkg | `statistics` pkg (independent) | `criterion` pkg | **Package boundaries** |
| Go | `testing.B` (stdlib) | `benchstat` (x/perf) | `benchstat` text | **Process boundaries** |
| JMH | Runner + codegen | Internal `Statistics` | `ResultFormatFactory` | Class hierarchy |
| BenchmarkDotNet | `Measurement` struct | `perfolizer` engine | `Summary` + exporters | Library boundaries |
| OpenTelemetry | SDK instruments | Backend (server-side) | Visualization layer | **Network boundaries** |

### Key Architectural Lessons

**Rust criterion**: The `Measurement` trait decouples "what you measure" from "how you analyze." `to_f64()` is the lossy bridge — all statistical machinery operates on `f64` regardless of original quantity. The `stats/` module has zero knowledge of benchmarks.

**Haskell**: Achieves the cleanest separation. Three packages:
- `criterion-measurement` — `Measured` record (data collection only, minimal deps)
- `statistics` — fully generic, completely independent of benchmarking
- `criterion` — runner, analysis, reporting

The `statistics` package's `Estimate e a` type is parameterized over both the value type `a` and the error model `e`. The extraction of `criterion-measurement` was explicitly motivated by enabling "alternative analysis front-ends."

**Go**: Separates by process boundary. Stdlib provides only the runner and raw data (`BenchmarkResult`). Statistical analysis is a different program (`benchstat`). The stdlib has *zero* statistical types.

**JVM**: Three independent ecosystems that never merged: JMH (runner), Commons Math (statistics), Dropwizard Metrics (production telemetry). Each reinvents its own `Statistics` type. Dropwizard's **reservoir pattern** is the most interesting: it separates *which samples to keep* from *what statistics to compute*.

**OpenTelemetry**: Converged on a fundamental distinction — **decomposable** (histograms: mergeable bucket counts) vs **non-decomposable** (summaries: pre-computed quantiles). This drove Summary's deprecation in favor of Histogram.

**BenchmarkDotNet**: `Statistics` class takes `double[]` or `int[]` — generic over numeric input. Computes: N, Min, Max, Q1, Median, Q3, Mean, StdDev, Variance, Skewness, Kurtosis, StandardError, IQR, outlier detection (Tukey fences), confidence intervals, all percentiles P0–P100.

### Academic Foundations

**Georges, Buytaert, Eeckhout (2007)** — "Statistically Rigorous Java Performance Evaluation":
- Distinguish startup from steady-state (JIT invalidates early iterations)
- Report confidence intervals, not just means
- Use effect sizes, not just p-values (practical vs statistical significance)
- ANOVA for multi-factor comparisons

**Kalibera & Jones (2013)** — "Rigorous Benchmarking in Reasonable Time":
- Three-level nested random effects model: builds > executions > iterations
- Variance decomposition via nested ANOVA determines where repetitions are needed
- Most frameworks only repeat at Level 1 (iterations), but Level 2/3 often contribute more variance
- Cost-optimal repetition allocation balances level cost against variance reduction

### The Universal Pipeline

Every ecosystem arrives at the same fundamental pipeline:

```
Collect(raw)  →  Reduce(to numeric)  →  Analyze(statistics)  →  Present(report)
     ^                   ^                      ^                     ^
  domain-specific   lossy bridge         domain-agnostic        format-specific
```

The critical design decision is where the **lossy bridge** lives. Rust: `to_f64()` on the trait. Haskell: polymorphic `Estimate e a`. Go: `map[string]float64`. BenchmarkDotNet: `double[]` constructor.

---

## Theoretical Grounding [RES-022] [RES-024]

### Algebraic Structure

**`Sample<T: Comparable>`** — a non-empty ordered multiset with derived order statistics.

```
Sample<T> ≅ NonEmpty<[T]>  where T: Comparable
```

Statistical properties are morphisms from the sample to its summary:

```
min, max    : Sample<T> → T                  (requires: Comparable)
percentile  : Sample<T> × [0,1] → T          (requires: Comparable)
median      : Sample<T> → T                  (= percentile(0.5))
mean        : Sample<T> → T                  (requires: AdditiveArithmetic, / Int)
stddev      : Sample<T> → Double             (requires: T → Double conversion)
```

The constraint stratification is type-theoretically necessary:

| Tier | Constraint on T | Operations Enabled |
|------|-----------------|-------------------|
| 0 | `Comparable` | min, max, percentile, median, p50–p999 |
| 1 | `Comparable & AdditiveArithmetic` + `/ Int` | + mean |
| 2 | Tier 1 + `T → Double` | + standardDeviation, confidenceInterval |

**`Aggregate`** — a commutative monoid for streaming accumulation.

```
Aggregate = { count: UInt64, sum: UInt64, min: UInt64, max: UInt64 }

empty   = { 0, 0, .max, 0 }
record  : Aggregate × UInt64 → Aggregate
merge   : Aggregate × Aggregate → Aggregate    (commutative, associative)
```

The merge operation: `{ count₁+count₂, sum₁+sum₂, min(min₁,min₂), max(max₁,max₂) }`.

**Relationship**: `Sample → Aggregate` is a lossy homomorphism. You can always compute an Aggregate from a Sample (O(n) fold), but not vice versa. Percentiles require the full sample; count/sum/min/max do not.

This gives two measurement archetypes:

| Archetype | Memory | Percentiles | Use Case |
|-----------|--------|-------------|----------|
| **Sample** (batch) | O(n) — stores all values | Yes | Benchmarking, testing, offline analysis |
| **Aggregate** (streaming) | O(1) — fixed fields | No | Production telemetry, runtime metrics |

### The Metric Selector

The `Metric` enum is a first-class function:

```
Metric ≅ Sample<T> → T
```

Cases: `.min`, `.max`, `.median`, `.mean`, `.p95`, `.p99` — each a different projection from sample to scalar. This is a standard lens/accessor pattern.

### Comparison as Generic Percentage-Change

Regression detection computes `(current - baseline) / baseline`:

```
compare : (T, T) → Double    where T → Double exists
```

This is generic over any quantity with a `Double` projection. Duration-specific `.inSeconds` is one such projection. `Int → Double(x)` is another. The "direction" (lower-is-better vs higher-is-better) parameterizes the regression/improvement classification.

---

## Ecosystem Survey

### Metric Types in Production Code

Exhaustive survey of all types aggregating numeric observations across the ecosystem:

| Type | Package | Category | Fields |
|------|---------|----------|--------|
| `IO.Blocking.Threads.Metrics` | swift-io | Composite | 4 gauges + 8 counters + 3 aggregates |
| `IO.Blocking.Threads.Aggregate` | swift-io | **Streaming sample** | count/sum/min/max (UInt64) |
| `IO.Blocking.Lane.Abandoning.Metrics` | swift-io | Composite | Workers + Queue + Total |
| `IO.Handle.Registry.Metrics` | swift-io | Gauge | registeredCount + lifecycleState |
| `Pool.Blocking.Metrics` | swift-pools | Composite | 5 counters + 3 gauges + 1 high-water |
| `Pool.Metrics` | swift-pool-primitives | Composite | 6 counters + 4 gauges |
| `Memory.Allocation.Statistics` | swift-memory | Counter | allocations/deallocations/bytes |
| `Tests.Measurement` | swift-tests | **Batch sample** | `[Duration]` + percentiles |
| `Test.Benchmark.Measurement` | swift-tests | **Batch sample** | `[Duration]` + percentiles (duplicate) |

**Key finding**: The only streaming sample primitive in the ecosystem (`IO.Blocking.Threads.Aggregate`) is namespace-coupled to IO. Pool metrics have no timing data at all. The only batch sample types are the duplicate `Measurement` types in swift-tests.

### Consumer Survey

24+ packages across all layers use performance measurement:

| Pattern | Adoption | Description |
|---------|----------|-------------|
| `.timed()` trait | ~95% of sites | Declarative test-runner integration |
| Manual `ContinuousClock` | ~5% of sites | Throughput/scaling analysis (ISO 32000, IO) |
| `Test.Benchmark.measure()` | Rare | Stable-state benchmarks |
| `Tests.measure()` | Rare | Generic-return measurement |

ISO 32000 does manual throughput analysis precisely because `Measurement` is trapped inside test infrastructure.

---

## Analysis

### Option A: Merge Benchmark + Performance (no extraction)

Combine into one `Tests Performance` module.

| Criterion | Assessment |
|-----------|------------|
| Eliminates duplication | Yes |
| Ecosystem reuse | No — types stay trapped in L3 test infrastructure |
| Layer correctness | Neutral |
| Dependency minimization | Worse — all consumers pay for Console, Memory, Formatting |
| Prior art alignment | No — violates every ecosystem's separation of data model from runner |

**Verdict**: Pragmatic but architecturally wrong. Every mature ecosystem we surveyed separates the statistical data model from the benchmarking framework.

### Option B: `Sample<T>` at Primitives (Layer 1)

Create `swift-sample-primitives` containing the generic batch sample type.

**Type structure:**

```swift
// Tier 0: Comparable only
public struct Sample<Element: Comparable & Sendable>: Sendable {
    public let values: [Element]  // sorted
    public var count: Int
    public var min: Element
    public var max: Element
    public func percentile(_ p: Double) -> Element
    public var median: Element
    public var p50, p75, p90, p95, p99, p999: Element
}

// Tier 1: + mean (conditional conformance)
extension Sample where Element: AdditiveArithmetic & ... {
    public var mean: Element
}

// Duration-specific (in swift-tests or a time-integration target)
extension Sample where Element == Duration {
    public var standardDeviation: Duration
}
```

Dependencies: **None.** Pure `Comparable` computation. Could sit at Tier 0–2 of primitives.

| Criterion | Assessment |
|-----------|------------|
| Eliminates duplication | Yes |
| Ecosystem reuse | Strong — available to all layers |
| Layer correctness | Strong — pure computation, no deps |
| Prior art alignment | Matches Haskell `statistics`, BenchmarkDotNet `Statistics(double[])` |
| Generic | Yes — `Sample<Duration>`, `Sample<Int>`, `Sample<Double>` |
| Foundation collision | Avoids `Foundation.Measurement` naming conflict |
| Naming | Statistically correct (sample = collection of observations) |

### Option C: `Aggregate` at Primitives (Layer 1)

Extract `IO.Blocking.Threads.Aggregate` to a shared streaming accumulator.

**Type structure:**

```swift
public struct Aggregate: Sendable {
    public var count: UInt64
    public var sum: UInt64
    public var min: UInt64
    public var max: UInt64

    public static var empty: Self
    public mutating func record(_ value: UInt64)
    public func merged(with other: Self) -> Self  // commutative monoid
}
```

Currently exists in swift-io but namespace-coupled. Extraction enables:
- `Pool.Blocking.Metrics` to add latency tracking
- `IO.Blocking.Lane.Abandoning.Metrics` to add latency tracking
- Future health checks, scheduling metrics

### Option D: Both `Sample<T>` and `Aggregate` + Unified Test Module

The complete solution:

**Layer 1 (Primitives):**
1. `swift-sample-primitives` — `Sample<T: Comparable>` with percentile statistics
2. `Aggregate` type (in existing package or new) — streaming O(1) accumulator

**Layer 3 (Foundations — swift-tests):**
3. Merge Benchmark + Performance → single `Tests Performance` module
4. All `Measurement`/`Metric` references point to `Sample_Primitives`
5. Test-specific APIs (`.timed()`, Runner, Suite, assertions, reporting) stay at L3

| Criterion | Assessment |
|-----------|------------|
| Eliminates duplication | Yes |
| Ecosystem reuse | Maximum — both archetypes available to all layers |
| Layer correctness | Strong — data model at L1, test integration at L3 |
| Prior art alignment | Matches Haskell's three-package separation |
| Covers both archetypes | Batch (Sample) + Streaming (Aggregate) |
| Dependency minimization | Sample has zero deps; test module accepts heavy deps |

### Option E: `Sample<T>` at Primitives, keep Benchmark/Performance separate

Same as D but without merging the test modules.

| Criterion | Assessment |
|-----------|------------|
| Eliminates duplication | Partial — shared types extracted, but test-level overlap remains |
| Structural disruption | Lower than D |
| MOD-DOMAIN | Still fails — "benchmarking" and "performance testing" are one domain |

---

## Formal Comparison

| Criterion | A: Merge | B: Sample<T> | C: Aggregate | D: Both+Merge | E: Both+Keep |
|-----------|----------|-------------|-------------|----------------|-------------|
| Duplication eliminated | Yes | Yes | No | **Yes** | Partial |
| Ecosystem reuse | No | **Strong** | Medium | **Maximum** | Strong |
| Layer correctness | Neutral | **Strong** | Strong | **Strong** | Strong |
| Prior art alignment | Weak | Strong | N/A | **Strongest** | Strong |
| Covers both archetypes | No | Batch only | Stream only | **Both** | Both |
| Structural disruption | Low | Medium | Low | **High** | Medium |
| Migration effort | Low | Medium | Low | **High** | Medium |
| MOD-DOMAIN compliance | Questionable | N/A | N/A | **Yes** | No |

---

## Empirical Validation [RES-025]

Cognitive Dimensions Framework assessment for Option D:

| Dimension | Assessment |
|-----------|------------|
| **Visibility** | Strong. `Sample<Duration>` makes the data model visible at the type level. Current `[Duration]` hidden inside opaque structs. |
| **Consistency** | Strong. One `Sample` type everywhere vs two near-identical `Measurement` types. Follows Semantic Uniform Ecosystem Principle. |
| **Viscosity** | Medium. Initial migration has cost. But future changes to statistical methods propagate from one location. |
| **Role-expressiveness** | Strong. `Sample<T>` signals "collection of observations" at the type level. Generic parameter makes the measured quantity explicit. |
| **Error-proneness** | Improved. Eliminates the current risk of Benchmark vs Performance `Measurement` divergence. |
| **Abstraction** | Appropriate. Tier 0 (`Comparable`-only) barrier is low. Duration-specific extensions don't pollute generic consumers. |

---

## Outcome

**Status**: MOSTLY IMPLEMENTED (Phases 1 and 3 complete; Phase 2 open)

### Recommended: Option D — `Sample<T>` + `Aggregate` + Unified Test Module

### Phase 1: `swift-sample-primitives` (Layer 1) — IMPLEMENTED

Package created at `/Users/coen/Developer/swift-primitives/swift-sample-primitives/`. Types in use across the ecosystem:

| Type | Description | Status |
|------|-------------|--------|
| `Sample.Batch<T: Comparable & Sendable>` | Sorted collection with order statistics | ✅ In use |
| `Sample.Metric` | Selector enum with `extract(from:using:)` | ✅ In use |
| `Sample.Comparison<T>` | Percentage-change with polarity | ✅ In use |
| `Sample.Averaging<T>` | Value witness for type-generic arithmetic | ✅ In use |
| `Sample.Polarity` | `.lowerIsBetter` / `.higherIsBetter` | ✅ In use |
| `Sample.Accumulator` | Streaming O(1) monoid for UInt64 | ✅ In use |
| `Sample.Batch.coefficientOfVariation` | CV as `Double?` | ✅ Added for diagnostics |
| `Sample.Batch.medianAbsoluteDeviation` | MAD as `Element?` | ✅ Added for diagnostics |
| `Sample.Batch.outlierCount(threshold:)` | Count beyond k × MAD | ✅ Added for diagnostics |

Tiered extensions implemented as recommended:
- Tier 0 (`Comparable`): min, max, percentile, median, p50–p999
- Tier 1 (`Comparable & AdditiveArithmetic`): mean
- Duration-specific: standardDeviation (via `.components` conversion, no Foundation)

### Phase 2: Extract `Aggregate` (Layer 1) — OPEN

`Sample.Accumulator` exists at Layer 1 (streaming O(1) monoid for UInt64). However, `IO.Blocking.Threads.Aggregate` in swift-io has NOT been migrated to use it. Pool metrics and Abandoning Lane metrics also not yet wired. This is the remaining deduplication opportunity.

### Phase 3: Merge Benchmark + Performance → `Tests Performance` (Layer 3) — IMPLEMENTED

Single `Tests Performance` module in swift-tests. No separate `Tests Benchmark` target. All test-specific APIs consolidated:

| API | Source | Status |
|-----|--------|--------|
| `.timed()` trait | Benchmark | ✅ Integrated |
| `Test.Runner` | Benchmark | ✅ Integrated |
| `Tests.Suite` | Performance | ✅ Integrated |
| `Tests.Comparison` | Performance | ✅ Uses `Sample.Comparison` |
| `Tests.expectPerformance()` | Performance | ✅ Integrated |
| `Tests.expectNoRegression()` | Performance | ✅ Integrated |
| Console reporting | Performance | ✅ Integrated |
| Allocation tracking | Performance | ✅ Integrated |
| `Tests.Diagnostic` | New | ✅ Rich diagnostic output |
| `Tests.Trend` (Mann-Kendall) | New | ✅ Trend analysis |

### Naming Decision

**`Sample<T>`** over `Measurement`:
1. Statistically correct — a sample is a collection of observations from a population
2. Avoids `Foundation.Measurement<UnitType>` collision (Foundation's type is a single scalar with units)
3. Generic-friendly — `Sample<Duration>`, `Sample<Int>`, `Sample<Double>` all read naturally
4. Follows Haskell precedent (criterion uses `Sample` for the raw data vector)
5. Compliant with [API-NAME-001] — `Sample` is not a compound name

**Note**: The Layer 3 type `Tests.Measurement` still wraps `Sample.Batch<Duration>` as `measurement.batch` rather than being replaced by it directly. This is acceptable — `Tests.Measurement` adds the raw `durations` array (temporal order) alongside the sorted batch.

### Deferred

- Reservoir/sampling strategies (Dropwizard pattern) — no current need
- HDR histogram / t-digest for Aggregate — noted in IO as future v2 work
- Confidence intervals / bootstrap (Kalibera & Jones methodology) — beyond current scope
- Multi-level measurement hierarchy (builds > executions > iterations) — future enhancement

---

## References

### Academic
- Georges, D., Buytaert, D., Eeckhout, L. (2007). "Statistically Rigorous Java Performance Evaluation." OOPSLA '07.
- Kalibera, T., Jones, R.E. (2013). "Rigorous Benchmarking in Reasonable Time." ISMM '13. https://kar.kent.ac.uk/33611/
- Parnas, D.L. (1972). "On the Criteria To Be Used in Decomposing Systems into Modules." CACM 15(12).

### Ecosystem Prior Art
- Rust criterion: https://github.com/bheisler/criterion.rs — `Measurement` trait, `stats/` module
- Haskell criterion: https://hackage.haskell.org/package/criterion — three-package split
- Haskell statistics: https://hackage.haskell.org/package/statistics — generic `Estimate e a`
- Go benchstat: https://pkg.go.dev/golang.org/x/perf/cmd/benchstat
- BenchmarkDotNet: https://github.com/dotnet/BenchmarkDotNet — `Statistics` class, `Measurement` struct
- OpenTelemetry metrics data model: https://opentelemetry.io/docs/specs/otel/metrics/data-model/
- Dropwizard Metrics: reservoir pattern for histogram sampling

### Swift Institute
- Modularization skill: [MOD-DOMAIN], [MOD-003], [MOD-006], [MOD-008]
- Five-Layer Architecture: swift-institute Documentation.docc
- Primitives Layering: swift-primitives Documentation.docc

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-28 | Initial Tier 2 analysis with 4 options |
| 2.0.0 | 2026-02-28 | Elevated to Tier 3. Added: prior art survey (6 ecosystems), formal semantics (algebraic structure, constraint tiers), ecosystem metrics survey (9 metric types across IO/Pools/Memory), empirical validation (Cognitive Dimensions), academic references. Refined to Option D with `Sample<T>` naming. Added `Aggregate` extraction as Phase 2. |
