# Measurement from First Principles

<!--
---
version: 1.0.0
last_updated: 2026-02-28
status: RECOMMENDATION
tier: 3
---
-->

## Context

The companion document ([benchmark-performance-modularization](benchmark-performance-modularization.md)) approaches the measurement design question bottom-up: what exists, what's duplicated, where should it move? This document approaches the same question top-down: if we could design the measurement and statistical analysis system from scratch — ignoring all existing code — what would the ideal design look like?

The two documents converge on the same answer from opposite directions.

**Trigger**: [RES-011] Research-first design — approaching a precedent-setting decision from first principles before committing to implementation.
**Scope**: Ecosystem-wide. Establishes the measurement data model for all layers.
**Tier**: 3 — Normative, long-lived, hard to undo.

## Question

What is the mathematically correct, type-theoretically sound, and ergonomically optimal design for a measurement and statistical analysis system in a typed language?

---

## 1. The Observation Pipeline

Every measurement system — from Go's `testing.B` to Haskell's `criterion` to Prometheus — follows a universal five-stage pipeline:

```
Observe  →  Collect  →  Reduce  →  Analyze  →  Present
   T       Sample<T>    Summary    Comparison    String
```

| Stage | Input | Output | Concern |
|-------|-------|--------|---------|
| **Observe** | System under test | Single value `T` | What to measure |
| **Collect** | Stream of `T` | `Sample<T>` or `Accumulator` | How to store |
| **Reduce** | Collection | Summary statistics | What to compute |
| **Analyze** | Two summaries | Comparison / regression | What changed |
| **Present** | Analysis | Formatted output | How to display |

### The Pipeline Independence Principle

Each stage must be implementable without knowledge of the stages before or after it. `Sample<T>` must not know about `ContinuousClock`. `Comparison` must not know about ANSI escape codes. Violations of this principle produce the anti-patterns catalogued in Section 8.

### Observation is not a type

An observation is just `T`. No wrapper needed. Metadata (timestamp, thread ID, context) is orthogonal — attaching it to the observation couples the measurement domain to the observation context. When the observation *is* composite (duration + allocation count), the correct move is a product type at the observation level, not a metadata wrapper.

This matches Go's `BenchmarkResult` (just numbers), Haskell's `criterion-measurement` (just a `Measured` record of numbers), and Rust criterion's approach (just `f64` values).

---

## 2. The Mathematical Foundation

### Gray's Three-Way Classification

Gray et al. (1996, "Data Cube") established the canonical taxonomy of aggregate functions:

| Category | Definition | Examples | Space |
|----------|-----------|----------|-------|
| **Distributive** | `f(X ∪ Y) = g(f(X), f(Y))` for fixed `g` | count, sum, min, max | O(1) |
| **Algebraic** | Computable from a bounded tuple of distributive aggregates | mean, variance, stddev | O(1) |
| **Holistic** | No bounded partial state suffices for exact computation | median, percentiles, mode | O(n) |

This classification maps directly onto algebraic structure:

- **Distributive** = monoid homomorphism from the free commutative monoid on observations to a result monoid
- **Algebraic** = monoid homomorphism into a *product* of monoids, followed by finalization
- **Holistic** = no finite-dimensional monoid homomorphism exists

### Formal Statement

Let `M(X)` be the free commutative monoid (= finite multisets) over observation type `X`. A statistic `f: M(X) → R` is **decomposable** iff there exists:

1. A commutative monoid `(S, e, ⊕)`
2. A monoid homomorphism `h: M(X) → S`
3. A finalization function `π: S → R`

such that `f = π ∘ h`.

### The Impossibility Result for Exact Percentiles

**Theorem** (Munro & Paterson 1980): Exact computation of the median in a single pass requires `Ω(n)` space.

**Proof sketch**: Suppose a commutative monoid `(S, e, ⊕)` with bounded `|S|` could factor percentile computation. The multisets `{1}, {2}, ..., {n}` each have distinct percentile behavior when merged with arbitrary other multisets. By pigeonhole, for sufficiently large `n`, two multisets map to the same `S`-element but produce different percentiles when merged with a third — contradiction.

This means: **there is no streaming percentile algorithm with bounded memory.** Approximate sketches (DDSketch, t-digest, HdrHistogram) trade exactness for bounded space.

### The Decomposable Statistics

| Statistic | Accumulator Monoid | Dimension | Finalization |
|-----------|--------------------|-----------|-------------|
| count | `(ℕ, +, 0)` | 1 | identity |
| sum | `(T, +, zero)` | 1 | identity |
| min | `(T ∪ {+∞}, min, +∞)` | 1 | identity |
| max | `(T ∪ {-∞}, max, -∞)` | 1 | identity |
| mean | `(ℕ × T, +, (0,zero))` | 2 | `sum / count` |
| variance | `(ℕ × ℝ × ℝ, CGL, (0,0,0))` | 3 | `M2 / (n-1)` |
| stddev | same as variance | 3 | `√(M2 / (n-1))` |

The product `(count, sum, min, max)` is itself a commutative monoid under componentwise operation. This is the **aggregate** pattern — compute all distributive statistics in a single traversal.

The variance accumulator uses Chan-Golub-LeVeque's (1979/1983) parallel merge formula on `(count, mean, M2)`. This is associative and commutative, with identity `(0, 0, 0)`.

---

## 3. Two Archetypes

The mathematical foundation reveals two fundamentally different measurement architectures:

### Archetype 1: Batch (Sample)

- Stores all observations
- O(n) space
- Enables holistic statistics (percentiles, median)
- Post-hoc analysis — statistics computed on demand
- Use case: benchmarking, experiment analysis, small-n offline analysis

### Archetype 2: Streaming (Accumulator)

- Stores bounded accumulator state
- O(1) space (or O(log n) for approximate percentiles)
- Limited to decomposable statistics
- Real-time analysis — statistics available immediately
- Use case: production telemetry, high-throughput monitoring, request latency tracking

These are not design alternatives — they are categorically different objects. A `Sample` is an element of `FreeCommMon(T)` (the free commutative monoid — a multiset). An `Accumulator` is an element of a target monoid `M`. The `fold` operation is the canonical surjection from one to the other. It is lossy and irreversible.

```
Sample<T>  ----fold--->  Accumulator
    |                        |
    | holistic stats         | decomposable stats
    | (percentiles)          | (mean, min, max)
    v                        v
    T                        UInt64
```

Both archetypes belong in the same system. A well-designed measurement library provides both, with a clear boundary between them.

---

## 4. The Constraint Lattice

The minimum type constraint for each statistic forms a strict hierarchy:

```
                    Any type
                       │
                     count
                       │
                  ┌────┴────┐
                  │         │
             Comparable   Hashable
                  │         │
           min, max,      mode
           percentile,
           median
                  │
         AdditiveArithmetic
           (+ Comparable)
                  │
               sum
                  │
          "divisible by ℕ"
                  │
               mean
                  │
          embeddable in ℝ
                  │
          variance, stddev
```

### In Swift's type system

| Tier | Constraint | Unlocked operations |
|------|-----------|-------------------|
| 0 | `Comparable` | min, max, percentile, median, p50–p999 |
| 1 | `Comparable & AdditiveArithmetic` + `/ Int` | + sum, mean |
| 2 | Tier 1 + `Double` conversion | + variance, stddev |

The gap in Swift's protocol hierarchy: there is no protocol between `AdditiveArithmetic` and `FloatingPoint` that captures "divisible by integer." `Duration` supports `/ Int` but this is not part of any protocol. This requires a custom protocol — call it `Averageable` — with a single requirement: `static func / (lhs: Self, rhs: Int) -> Self`.

### The type-preserving principle

Order statistics (min, max, percentile, median) operate on the *order structure* of data. They need only `Comparable` and naturally return `T`.

Moment statistics (mean, variance, stddev) operate on the *algebraic structure* of data. They inherently involve floating-point arithmetic and may change the return type.

This split is not arbitrary — it reflects the mathematical structure. A well-designed API makes this distinction visible:

```swift
// Tier 0: returns T (order statistics)
sample.min        // T?
sample.percentile(0.99)  // T?

// Tier 1: returns T (location statistics, T must support division)
sample.mean       // T

// Tier 2: returns Double (dispersion statistics)
sample.standardDeviation  // Double
// ... with Duration-specific override:
sample.standardDeviation  // Duration (when Element == Duration)
```

Every ecosystem eventually funnels to `Double` for moment statistics. The question is when. The answer: **as late as possible.** Narrow to `Double` only at the statistics that require it. Preserve `T` for everything that doesn't.

---

## 5. The Fundamental Types

### 5.1 `Sample<T: Comparable>`

The central type. An immutable collection of observations with derived statistics.

**Key design decisions:**

1. **Store both insertion-order and sorted arrays.** Insertion order preserves temporal information (warmup detection, trend analysis). Sorted order enables O(1) percentile access after O(n log n) init. The 2x memory cost is negligible for benchmarking sample sizes (10–10,000).

2. **Sort at init, not at access.** The current ecosystem sorts on every `.percentile()` call — O(n log n) per access. Sorting once at init amortizes this. (Rust's `statrs` takes the opposite approach: `OrderStatistics` methods take `&mut self` because they sort in-place. This is honest but destructive.)

3. **`Comparable` as the base constraint, not `Comparable & Sendable`.** `Sendable` is a concurrency concern, not a measurement concern. Add it via conditional conformance where needed.

4. **Statistics return `Optional` for empty samples.** Returning `.zero` for an empty sample silently produces a meaningful-looking fabricated value. The `measure()` function always produces non-empty samples, so callers after measurement can safely unwrap.

### 5.2 `Accumulator`

The O(1) streaming counterpart. Concrete on `UInt64`.

**Why not generic?**
- Nanosecond timestamps are the universal unit for time-based metrics
- `UInt64` enables wrapping arithmetic (`&+=`) for zero-cost accumulation
- Allocation counts, byte counts, event counts are all naturally `UInt64`
- Genericizing adds overhead (no wrapping arithmetic on generic `AdditiveArithmetic`)
- All known ecosystem use sites (IO.Blocking.Threads.Aggregate, Pool.Blocking.Metrics) operate on integers

**Why no percentiles?**
Percentiles require either all values (Sample) or approximation (sketch). The Accumulator captures decomposable statistics only. Approximate percentiles belong in a separate `Histogram` type (DDSketch or HdrHistogram), which would be a future addition.

**Fields:** `count: UInt64`, `sum: UInt64`, `min: UInt64`, `max: UInt64`

**Operations:** `record(_:)`, `merged(with:)`, computed `mean`

This is exactly the commutative monoid `(ℕ × ℕ × ℕ_min × ℕ_max)` from Section 2, concretized.

### 5.3 `Metric`

A selector — a first-class function `Sample<T> → T?`. An enum with cases for each standard statistic (min, max, median, mean, p50, p75, p90, p95, p99, p999).

The `extract(from:)` method is constrained to `T: Averageable` because `.mean` requires it. In practice, you never use `Metric` with a type that doesn't support mean — the whole point is to select among available statistics for comparison.

### 5.4 `Comparison<T>`

Relates two samples via a selected metric and a polarity.

**Polarity is essential.** The current implementation hardcodes `isRegression = change > 0`, which assumes lower-is-better. This silently produces wrong results for throughput benchmarks. The correct design:

```
Polarity.lowerIsBetter   → positive change = regression (latency went up)
Polarity.higherIsBetter  → negative change = regression (throughput went down)
```

### 5.5 `Summary<T>` (optional convenience)

A named tuple of all standard statistics, computed eagerly from a `Sample`. Primarily a presentation type — exists to be formatted into reports. Less important than the lazy per-statistic accessors on `Sample`.

---

## 6. Composition Laws

| Operation | Type | Properties |
|-----------|------|-----------|
| `Sample + Sample → Sample` | Concatenation | Associative, identity = `Sample([])` |
| `Accumulator + Accumulator → Accumulator` | Monoid merge | Commutative, associative, identity = `.empty` |
| `Sample → Accumulator` | Fold (lossy surjection) | Preserves decomposable stats, discards rank info |
| `Accumulator → Sample` | **Impossible** | Information is irreversibly lost |
| `Sample → Summary` | Eager reduction | Non-invertible |
| `Sample × Metric → T` | Selection | Extracts one statistic |
| `(Sample, Sample, Metric, Polarity) → Comparison` | Construction | Pure function |

The key insight: `Sample` is the free object (retains all information). `Accumulator` is the quotient (collapses to decomposable aggregates). The fold is the canonical surjection. Any statistic computable from an `Accumulator` is also computable from a `Sample`, but not vice versa.

### The foldMap connection

In Haskell, `foldMap :: (Foldable t, Monoid m) => (a -> m) -> t a -> m` is the universal aggregation primitive. Every streaming statistic is an instance:

```
foldMap (\x -> (Min x, Max x, Sum x, Count 1)) observations
```

The product of monoids is a monoid. This gives the aggregate pattern for free: compute N statistics simultaneously in a single traversal. In Swift, this maps to `Sequence.reduce(into:_:)`.

---

## 7. The Unit/Dimension Problem

If observations have dimension `[D]`:

| Statistic | Output dimension | Same type as input? |
|-----------|-----------------|-------------------|
| min, max, percentile, median | `[D]` | Yes |
| sum, mean | `[D]` | Yes |
| standard deviation | `[D]` | Yes |
| **variance** | **`[D]²`** | **No** |
| correlation, coefficient of variation | dimensionless | No |

Variance is the only common statistic with a unit-dimension mismatch. `variance(durations)` has units of seconds² — but `Duration²` is not `Duration`.

### Resolution

Three approaches exist:

1. **F# Units of Measure** — Compile-time unit exponent tracking (`float<m^2>`). Gold standard but requires language support.
2. **Opaque `Variance<T>` wrapper** — Type with sole public operation `squareRoot() → T`. Makes squared-unit nature visible without general unit algebra.
3. **Return `Double` with documentation** — Pragmatic. Caller knows units are `[T]²`.

For Swift, option 3 (return `Double`) is the pragmatic choice. `standardDeviation` returns `T` — it is `√(variance)` which restores the original dimension. Variance as `Double` loses unit information but variance is rarely used directly; standard deviation is the common API.

---

## 8. Anti-Patterns

Catalogued from prior art analysis across six ecosystems:

### 8.1 Coupling collection to analysis (Go `testing.B`)

Go's `testing.B` is both runner and result container. You cannot extract raw timings for offline analysis. The benchmark result is inseparable from execution.

**Avoid**: `measure()` returns `Sample<Duration>`. The caller decides what to do with it.

### 8.2 Coupling analysis to presentation (JMH)

JMH's `Result` hierarchy bundles statistical computation with formatting. You cannot get numbers without presentation overhead.

**Avoid**: `Sample<T>` and `Summary<T>` are presentation-free value types. Formatting lives in a separate module.

### 8.3 Over-computation

Computing all statistics when you only need one. The current `printPerformance` computes seven statistics even for a threshold check that needs only one.

**Avoid**: Statistics are lazy properties computed on demand. `sample.p99` computes only p99. `sample.summary` computes everything (opt-in).

### 8.4 Premature Double conversion

Converting to `Double` too early loses type information. If `measure()` returns `Double` instead of `Duration`, the caller cannot format with appropriate units.

**Avoid**: Generic `Sample<T>` preserves `T` throughout. Conversion to `Double` happens only for statistics that require it.

### 8.5 DRY violation across measurement contexts

The current codebase has `Tests.Measurement` and `Test.Benchmark.Measurement` — near-identical types in two modules, each with their own `Metric` and `printPerformance`.

**Avoid**: One `Sample<T>` at the correct layer. Duplication is structurally impossible.

### 8.6 Hardcoded polarity

Assuming lower-is-better works for latency but fails for throughput. `isRegression = change > 0` is wrong 50% of the time.

**Avoid**: Explicit `Polarity` parameter.

### 8.7 Empty-sample silent zeroing

Returning `.zero` for empty samples hides bugs. An accidentally empty measurement looks like an impossibly fast benchmark.

**Avoid**: Optional returns from statistical methods. Or non-empty enforcement at init.

---

## 9. The Platonic Layering

### What lives where

```
Layer 3 (Foundations): Test Integration
    - Test runner trait integration (.timed)
    - measure() function (ContinuousClock)
    - Regression assertions (expectNoRegression)
    - Console reporting (printPerformance)
    - Warmup logic, multi-iteration collection
    - Baseline storage, CI tooling

         ↑ depends on

Layer 1 (Primitives): Statistical Data Model
    - Sample<T: Comparable>
    - Accumulator
    - Metric (enum)
    - Comparison<T>
    - Summary<T>
    - Averageable protocol
```

### Why Layer 1?

The statistical data model belongs at the primitives layer because:

1. **Zero external dependencies** — pure `Comparable` computation, no Foundation, no system clock
2. **Reusable by any layer** — IO metrics, pool metrics, PDF rendering benchmarks, application telemetry
3. **Domain-independent** — works for `Duration`, `Int`, `Double`, `UInt64`, any `Comparable`
4. **Timeless** — the mathematics of order statistics and commutative monoids does not change

### Why not Layer 0 algebraic abstractions?

A `Monoid` protocol would let us express `Sample.merged` and `Accumulator.merged` as monoid instances. But:

1. Swift has no standard `Monoid` protocol, and introducing one creates ecosystem fragmentation
2. The concrete merge methods are self-documenting
3. Even Haskell's `statistics` package does not abstract over monoid structure for this — it just uses `Semigroup`/`Monoid` from `base`

Document the monoidal structure in comments; do not encode it in types.

### The Haskell three-package pattern

Haskell achieves the cleanest separation in any ecosystem:

| Package | Contents | Dependencies |
|---------|----------|-------------|
| `criterion-measurement` | `Measured` record, `measure` | minimal (base, vector) |
| `statistics` | All statistical computation | independent of benchmarking |
| `criterion` | Runner, analysis, reporting | depends on both |

The extraction of `criterion-measurement` was explicitly motivated by enabling "alternative analysis front-ends." This is the strongest prior art for the data-collection/analysis separation.

Our equivalent:

| Package | Contents | Layer |
|---------|----------|-------|
| `swift-sample-primitives` | `Sample<T>`, `Accumulator`, `Metric`, `Comparison` | 1 (Primitives) |
| `swift-tests` | `measure()`, assertions, reporting, trait integration | 3 (Foundations) |

The middle layer (`statistics` equivalent) collapses into `swift-sample-primitives` because Swift's conditional extensions let the same type provide tiered statistics without a separate package.

---

## 10. Ideal Call Sites

### Benchmarking

```swift
let sample: Sample<Duration> = measure(iterations: 1000) { doWork() }

sample.min              // Duration?
sample.p99              // Duration?
sample.percentile(0.99) // Duration?
sample.mean             // Duration
sample.standardDeviation // Duration
```

### Comparison / Regression

```swift
let comparison = Comparison(
    baseline: oldSample,
    current: newSample,
    metric: .p99,
    polarity: .lowerIsBetter
)

comparison.change               // Double (0.15 = 15% increase)
comparison.isRegression          // Bool
comparison.exceedsTolerance(0.10) // Bool
```

### Streaming telemetry

```swift
var acc = Accumulator.empty
acc.record(elapsedNs)
acc.record(elapsedNs)

let snapshot = acc  // value type — copy is the snapshot
snapshot.count      // UInt64
snapshot.mean       // UInt64
snapshot.min        // UInt64

let merged = thread1Acc.merged(with: thread2Acc)
```

### Generic (non-Duration)

```swift
let allocSample = Sample<Int>([1024, 2048, 1024, 4096, 2048])
allocSample.p95     // Int?
allocSample.mean    // Int

let opsSample = Sample<Double>([1_000_000, 1_100_000, 950_000])
opsSample.median    // Double?
opsSample.mean      // Double
```

---

## 11. Convergence with Bottom-Up Analysis

The first-principles design converges with the ecosystem analysis from the companion document:

| First-principles conclusion | Ecosystem evidence |
|---------------------------|-------------------|
| Two archetypes: batch + streaming | `Sample<T>` maps to `Tests.Measurement`; `Accumulator` maps to `IO.Blocking.Threads.Aggregate` |
| Batch type is generic over `Comparable` | 80% of statistical operations need only `Comparable` (companion §5) |
| Streaming type is concrete on `UInt64` | All ecosystem accumulators use `UInt64` nanoseconds |
| Data model at Layer 1, runner at Layer 3 | Haskell three-package split validates this layering |
| Polarity in comparison | Current code hardcodes lower-is-better — confirmed anti-pattern |
| DRY violation is structural | Two near-identical `Measurement` types exist today |
| `Averageable` protocol needed | Swift has no protocol for `T / Int` |

The bottom-up analysis identifies *what to extract*. The first-principles analysis identifies *what the ideal extraction looks like*. They agree.

---

## Outcome

**Status**: RECOMMENDATION

### The Ideal Design

1. **`Sample<T: Comparable>`** at Layer 1 — generic batch measurement with tiered conditional extensions:
   - Tier 0 (`Comparable`): min, max, percentile, median, p50–p999
   - Tier 1 (`Averageable`): sum, mean
   - Tier 2 (`Averageable` + `ConvertibleToDouble`): variance, standardDeviation
   - Tier D (`Element == Duration`): typed Duration returns for stddev

2. **`Accumulator`** at Layer 1 — concrete `UInt64` streaming monoid with `record`, `merged`, computed `mean`

3. **`Metric`** at Layer 1 — enum selector with `extract(from:)` constrained to `Averageable`

4. **`Comparison<T>`** at Layer 1 — relates two samples via metric + polarity

5. **`measure()`**, assertions, and reporting at Layer 3 — depends on `Sample<Duration>`, `ContinuousClock`, test framework

6. **Single test module** at Layer 3 — merge the current Benchmark and Performance modules (they are one semantic domain split along an implementation axis)

### Properties of this design

- **Mathematically grounded**: constraint tiers match the algebraic requirements exactly
- **Type-preserving**: order statistics return `T`, not `Double`
- **Composable**: samples merge, accumulators merge, both follow monoid laws
- **Pipeline-independent**: each stage has no knowledge of adjacent stages
- **Anti-pattern-free**: addresses all seven catalogued anti-patterns
- **Ecosystem-uniform**: one `Sample<T>` replaces all ad-hoc measurement types
- **Layered correctly**: domain-independent math at L1, domain-specific tooling at L3

---

## References

### Academic

- Chan, T.F., Golub, G.H., & LeVeque, R.J. (1983). "Algorithms for Computing the Sample Variance: Analysis and Recommendations." *The American Statistician* 37(3), 242-247.
- Gray, J. et al. (1996). "Data Cube: A Relational Aggregation Operator Generalizing Group-By, Cross-Tab, and Sub-Total." *Proc. ICDE 1996*.
- Munro, J.I. & Paterson, M.S. (1980). "Selection and Sorting with Limited Storage." *Theoretical Computer Science* 12(3), 315-323.
- Welford, B.P. (1962). "Note on a Method for Calculating Corrected Sums of Squares and Products." *Technometrics* 4(3), 419-420.
- Masson, C., Rim, J.E., & Lee, H.K. (2019). "DDSketch: A Fast and Fully-Mergeable Quantile Sketch." *Proc. VLDB Endowment* 12(12).
- Dunning, T. & Ertl, O. (2019). "Computing Extremely Accurate Quantiles Using t-Digests." arXiv:1902.04023.
- Georges, D., Buytaert, D., Eeckhout, L. (2007). "Statistically Rigorous Java Performance Evaluation." *OOPSLA '07*.
- Kalibera, T., Jones, R.E. (2013). "Rigorous Benchmarking in Reasonable Time." *ISMM '13*.

### Prior Art

- Haskell `statistics` package — O'Sullivan. Monomorphic `Vector Double`, `Estimate e a` parameterized error.
- Haskell `criterion-measurement` — Data collection separated from analysis.
- Rust `criterion.rs` — `Measurement` trait with `to_f64()` lossy funnel.
- Rust `statrs` — `Statistics<T>` trait (generic interface, `f64` implementation).
- Go `testing.B` — Stdlib runner with no statistical types. `benchstat` as separate process.
- JMH — Runner + analysis + reporting coupled in class hierarchy.
- BenchmarkDotNet — `Statistics(double[])` with `perfolizer` analysis engine.
- OpenTelemetry — Histogram (decomposable, server-side quantiles) vs Summary (non-decomposable, client-side).
- Dropwizard Metrics — Reservoir pattern separating sample retention from statistic computation.
- Julia StatsBase.jl — Multiple dispatch, type-preserving `SummaryStats{T}`.
- Gonzalez, Gabriel — Composable streaming folds via `Fold` type with `Applicative` instance.
