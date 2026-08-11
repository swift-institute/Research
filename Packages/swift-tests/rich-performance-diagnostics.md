# Rich Performance Diagnostics

<!--
---
version: 1.2.0
last_updated: 2026-04-01
status: DEFERRED
tier: 2
---
-->

## Context

We migrated swift-html-rendering to Swift Institute foundations. The Package.swift enables `NonisolatedNonsendingByDefault` + `strictMemorySafety()`, which the original version did not have. All 17 performance tests now fail with 2-4x threshold exceedance (one at 21.7x). The current diagnostics told us:

```
performanceThresholdExceeded(test: "...", metric: .median, expected: 3.0 seconds, actual: 11.055 seconds)
```

That's it. We had to manually compute ratios, check variance stability, and reason about what changed. An AI agent seeing these failures would have no actionable path to diagnose the cause.

**Trigger**: [RES-001] Design question arose during implementation -- the performance testing system lacks sufficient diagnostic output for autonomous root-cause analysis.

**Scope**: Cross-package (Layer 1 swift-sample-primitives, Layer 1 swift-test-primitives, Layer 3 swift-tests). Tier 2 per [RES-020]: cross-package, reversible decisions, medium cost of error.

## Question

What enrichments to the performance testing system would provide enough detail for an AI agent or developer to autonomously identify the root cause of performance regressions?

## Current Architecture

The performance testing system spans three layers:

### Layer 1: swift-sample-primitives

`/Users/coen/Developer/swift-primitives/swift-sample-primitives/Sources/Sample Primitives Core/`

| Type | Purpose |
|------|---------|
| `Sample.Batch<T: ~Copyable>` | Sorted sample storage with percentile access (min, max, median, mean, p50/p75/p90/p95/p99/p999). Supports `~Copyable` elements via class-backed storage. |
| `Sample.Batch.standardDeviation(using:)` | Bessel-corrected sample standard deviation. |
| `Sample.Metric` | Enum selector (min/max/median/mean/p50-p999) with `extract(from:using:)`. Codable. |
| `Sample.Comparison<T>` | Computes `change` (relative %), `isRegression`, `isImprovement`, `exceedsTolerance`. |
| `Sample.Averaging<T>` | Value witness for type-generic arithmetic. Pre-configured for Duration, Double, Int, UInt64. |
| `Sample.Polarity` | `.lowerIsBetter` / `.higherIsBetter`. |
| `Sample.Accumulator` | Streaming O(1) monoid for UInt64 values. |

### Layer 1: swift-test-primitives

`/Users/coen/Developer/swift-primitives/swift-test-primitives/Sources/Test Primitives Core/`

| Type | Purpose |
|------|---------|
| `Test.Benchmark.Configuration` | `iterations`, `warmup`, `printResults`, `threshold` (Duration?), `metric`. Sendable, Codable, Hashable. |
| `Test.Event` | Neutral envelope: `id`, `caseID`, `kind`, `elapsed`. Sendable, Codable. |
| `Test.Event.Kind` | runStarted/planCreated/testStarted/expectationChecked/issueRecorded/testEnded/runEnded/custom(name:payload:). |

### Layer 3: swift-tests (Tests Performance module)

`/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Performance/`

| File | Purpose |
|------|---------|
| `Measurement.swift` | `Tests.Measurement` wrapping `[Duration]` + `Sample.Batch<Duration>`. All percentile accessors. Codable, Comparable. |
| `Tests.Metric.swift` | Typealias to `Sample.Metric` + `extract(from: Tests.Measurement)` convenience. |
| `Tests.Comparison.swift` | Wraps `Sample.Comparison`, formatted output with arrows/colors. |
| `Tests.Error.swift` | 6 cases including `thresholdExceeded`, `regressionDetected`, allocation/memory errors. |
| `Test.Benchmark.Error.swift` | Simpler `thresholdExceeded(test:metric:expected:actual:)`. |
| `Test.Benchmark+measure.swift` | `Test.Benchmark.measure(iterations:warmup:name:threshold:metric:body:)` sync+async. |
| `Reporting.swift` | `Tests.printPerformance(_:_:allocations:peakMemory:)` with allocation/peak memory support. |
| `Tests.Suite.swift` | Collects named benchmarks, prints tabular report. |
| `Assertions.swift` | `Tests.expectPerformance(lessThan:...)` and `Tests.expectNoRegression(...)`. |
| `Test.Trait.ScopeProvider.timed.swift` | The `.timed` scope provider: warmup loop, measure loop, calls `printPerformance`, throws `performanceThresholdExceeded`. |
| `Test.Runner.swift` | Walks test plan tree, executes with scope providers, emits events via reporter. |

### Layer 3: swift-tests (Tests Core module)

| File | Purpose |
|------|---------|
| `Test.Trait.ScopeProvider.Error.swift` | `bodyFailed`, `timeLimitExceeded`, `performanceThresholdExceeded(test:metric:expected:actual:)`. |
| `Test.Trait.Key.Timed.swift` | Witness key storing `Test.Benchmark.Configuration?`. |
| `Test.Trait.Collection.Modifier.builtins.swift` | `.timed(iterations:warmup:threshold:metric:)` factory. |

## Gap Analysis

### Gap 1: No ratio/factor in output

**Current**: `expected: 3.0 seconds, actual: 11.055 seconds` -- requires mental math.

**Impact**: An AI agent must parse two durations and compute the ratio itself. Humans must do the same.

**Location**: `Test.Trait.ScopeProvider.Error.performanceThresholdExceeded` at `Test.Trait.ScopeProvider.Error.swift` and `Test.Benchmark.Error.swift`.

### Gap 2: No stability indicator

**Current**: StdDev is printed in `printPerformance` but coefficient of variation (CV = StdDev/Mean) is never computed. CV=2% means trustworthy; CV=50% means noise.

**Impact**: Critical for determining whether to investigate further or dismiss as environmental noise.

**Location**: `Reporting.swift:37` prints StdDev but nothing else. `Sample.Batch.standardDeviation(using:)` exists at Layer 1 but CV computation does not.

### Gap 3: No per-iteration data in the error

**Current**: `performanceThresholdExceeded` carries 4 scalars (test name, metric, expected, actual). The full `Measurement` (with all durations) is printed to stdout and then discarded.

**Impact**: Error handlers, reporters, and AI agents cannot access the distribution. Only the summary is available programmatically.

**Location**: `Test.Trait.ScopeProvider.timed.swift:47-53` -- measurement is created but not attached to the error.

### Gap 4: No iteration trend analysis

**Current**: No analysis of whether durations are flat (stable regression), ramping up (thermal throttle), or have outliers. The `[Duration]` array exists in `Measurement.durations` but nobody analyzes its shape.

**Impact**: Without trend analysis, thermal throttling and warmup effects cannot be distinguished from real regressions.

### Gap 5: No environment fingerprint

**Current**: No record of optimization level, Swift version, enabled feature flags, hardware, or OS version.

**Impact**: This is exactly what would have explained the html-rendering regression. The tests pass under the original build settings but fail under Swift Institute settings with strict concurrency features.

### Gap 6: No stored baselines

**Current**: `.timed()` only supports absolute thresholds. `Tests.Comparison`, `Tests.expectNoRegression`, and `Tests.Error.regressionDetected` all exist but are completely disconnected from the `.timed()` trait. `Measurement` is already Codable but there is no storage mechanism.

**Impact**: Every test must hardcode absolute time thresholds, which are fragile across machines and configurations.

### Gap 7: No stack traces or profiling hooks

**Current**: When a test is 3.7x slower, there is no way to determine WHERE the time is spent. No integration with signposts, backtraces, or any drill-down mechanism.

### Gap 8: Unused allocation/memory parameters

**Current**: `Reporting.swift:28-29` `Tests.printPerformance` accepts `allocations: [Int]?` and `peakMemory: Int?` but the `.timed` scope provider never collects or passes them.

### Gap 9: Disconnected APIs

**Current**: `Tests.Comparison`, `Tests.expectNoRegression`, `Tests.Error.regressionDetected` are all implemented but unreachable from the `.timed()` trait path. Two parallel worlds exist: the trait system and the manual assertion API.

### Gap 10: Unused event system for performance data

**Current**: `Test.Event.Kind.custom(name:payload:)` exists but is not used for performance measurements. Performance data is printed to stdout rather than flowing through the structured event system.

## Prior Art Survey

### Apple swift-testing

No built-in performance/benchmark support. The `TimeLimit` trait sets a maximum duration but does not measure. Performance testing is acknowledged as "a future direction" with no milestone.

### ordo-one/package-benchmark (recommended Swift benchmarking tool)

| Feature | Implementation |
|---------|---------------|
| Baseline storage | `.benchmarkBaselines/` directory, private format |
| Statistical analysis | Percentile-based (HDR Histogram), not mean/stddev |
| Metrics | 20+: CPU, memory, ARC, I/O, syscalls, custom |
| Regression detection | CI threshold comparison (absolute + relative per metric) |
| Output | JMH, HDR Histogram, histogramPercentiles, histogramSamples |
| Environment | Not explicitly documented |

### XCTest measure {} blocks

| Feature | Implementation |
|---------|---------------|
| Baseline storage | `.xcodeproj/xcbaselines/` plist files, keyed by (host hardware specs UUID, target device) |
| Statistical analysis | Average + stddev across 10 runs |
| Pass/fail | Stddev more than 10% off from baseline |
| Metrics | Clock, CPU, memory, storage, signposts (iOS 13+) |
| Output | Xcode GUI only, no machine-readable export |

### Rust criterion crate

The most sophisticated framework surveyed.

| Feature | Implementation |
|---------|---------------|
| Baseline storage | `target/criterion/<name>/` with JSON files |
| Statistical analysis | 100,000 bootstrap resamples, linear regression, confidence intervals |
| Outlier classification | Modified Tukey's method (mild/severe, classified but not removed) |
| Change detection | Bootstrapped T-test, p-value, significance level (0.05), noise threshold (1%) |
| HTML reports | PDF plots, regression plots, violin plots, KDE, change visualizations |
| Environment | Warmup-based stabilization, no explicit fingerprinting |

### Go benchstat

| Feature | Implementation |
|---------|---------------|
| Baseline storage | External text files (user-managed) |
| Statistical analysis | Median with 95% CI, Mann-Whitney U test (nonparametric) |
| Regression detection | p-value + `~` indicator (p > 0.05 = no significant change) |
| Output | Human-readable table + HTML table. No JSON. |
| Recommended sample size | 10+ runs, ideally 20+ |

### pytest-benchmark

| Feature | Implementation |
|---------|---------------|
| Baseline storage | `.benchmarks/<Platform>-<Python>-<Version>-<Arch>/` JSON files with commit hash |
| Statistical analysis | min/max/mean/stddev/median/iqr/outliers/ops/rounds/iterations |
| Outlier detection | Modified Tukey box-and-whisker |
| Environment | Full CPU info + commit info in JSON; warns if machine_info differs between runs |
| Regression detection | `--benchmark-compare-fail=<stat>:<threshold>` with percentage or absolute |

### Summary Matrix

| Capability | Our System | criterion | benchstat | pytest-benchmark |
|------------|-----------|-----------|-----------|-----------------|
| Stability metric | StdDev only | Bootstrap CI | CI on median | CV implied via iqr |
| Trend analysis | None | None | None | None |
| Outlier detection | None | Modified Tukey | Median-robust | Modified Tukey |
| Environment capture | None | None | goos/goarch | Full machine_info |
| Baseline storage | None (Codable exists) | JSON files | External files | JSON with commit hash |
| Machine-readable | None | JSON (private) | Text only | Full JSON |
| Statistical comparison | None (API exists) | Bootstrapped T-test | Mann-Whitney U | Threshold comparison |

**Key insight**: No surveyed framework performs trend analysis. All handle outliers at the statistical level but none diagnose the cause (thermal throttle, warmup effect, contention). This is a differentiation opportunity.

## Research Questions

### RQ1: Stack Traces and Profiling Integration

**Findings**:

**SE-0419 Swift Backtrace API** (shipped in Swift 6.2):
- `import Runtime` provides `Backtrace.capture(algorithm:limit:offset:top:)`.
- Algorithms: `.auto`, `.fast` (frame-pointer walking), `.precise` (DWARF unwind).
- Symbolication via `backtrace.symbolicated(options:)` yields demangled names, source locations, inline frames.
- Available on macOS and Linux. Not yet on iOS.
- Not async-signal-safe; designed for programmatic capture during normal execution.
- Symbolication is expensive; raw capture is cheaper.
- Frame pointers require `-Xcc -fno-omit-frame-pointer`.

**OSSignposter** (`import os`):
- Available on Darwin only (`#if canImport(os)`), not Foundation.
- `OSSignposter(subsystem:category:)` with `beginInterval`/`endInterval` or `withIntervalSignpost`.
- Points of Interest category appears in Instruments.
- Overhead: "very close to a no-op" when logging is disabled; builds up with thousands per second.
- `.trace` files can be captured via `xctrace record`.

**Recommendation**: Neither mechanism should be in the hot path. Both should be opt-in diagnostic enrichment:

1. **Backtrace capture on failure**: When a threshold is exceeded, capture a backtrace at the measurement site. Attach it to the diagnostic report. Cost: one capture per failure, not per iteration.
2. **Signpost bracketing**: Optional `.timed(signpost: true)` parameter that emits signposts around each iteration. Darwin-only behind `#if canImport(os)`. Enables Instruments profiling of the test run.
3. **Neither belongs at Layer 1**. Both require platform-specific imports. They belong at Layer 3 (swift-tests) or as optional enrichment modules.

### RQ2: Environment Fingerprinting

**Findings**:

All of the following are available **without Foundation**:

| Information | Darwin | Linux | Mechanism |
|-------------|--------|-------|-----------|
| Physical memory | `sysctlbyname("hw.memsize")` | `sysinfo().totalram` | `import Darwin` / `import Glibc` |
| Physical CPU count | `sysctlbyname("hw.physicalcpu")` | `sysconf(_SC_NPROCESSORS_ONLN)` | Same |
| Logical CPU count | `sysctlbyname("hw.logicalcpu")` | Same | Same |
| Machine model | `sysctlbyname("hw.model")` | `/proc/cpuinfo` | Same |
| Architecture | `sysctlbyname("hw.machine")` | `uname()` | Same |
| Swift version | `#if swift(>=6.2)` | Same | Compile-time |
| Feature flags | `#if hasFeature(NonisolatedNonsendingByDefault)` | Same | Compile-time |
| Optimization level | `#if DEBUG` or assert-probing | Same | Compile-time / runtime |
| OS version | `uname()` | `uname()` | `import Darwin` / `import Glibc` |

**Compile-time detection of feature flags**:

```swift
#if hasFeature(NonisolatedNonsendingByDefault)
    static let nonisolatedNonsendingByDefault = true
#else
    static let nonisolatedNonsendingByDefault = false
#endif

#if hasFeature(StrictMemorySafety)
    static let strictMemorySafety = true
#else
    static let strictMemorySafety = false
#endif
```

**Optimization level detection** (runtime, zero-cost in release):

```swift
static var isDebugBuild: Bool {
    var debug = false
    assert({ debug = true; return true }())
    return debug
}
```

**Recommendation**: Define a `Test.Environment` type at Layer 3 that captures all available information. Make it Codable for storage alongside baselines. The compile-time flags are the most critical -- they would have immediately explained the html-rendering regression.

### RQ3: Baseline Storage

**Findings from prior art**:

| Framework | Location | Format | Keying |
|-----------|----------|--------|--------|
| XCTest | `.xcodeproj/xcbaselines/` | plist | Hardware specs UUID + target device |
| criterion | `target/criterion/<name>/` | JSON | Benchmark name |
| pytest-benchmark | `.benchmarks/<Platform-Python-Arch>/` | JSON | Platform + commit hash |
| package-benchmark | `.benchmarkBaselines/` | Private binary | Named baselines |

**Design for swift-tests**:

| Aspect | Recommendation | Rationale |
|--------|---------------|-----------|
| Directory | `.benchmarks/` at package root | Discoverable, git-trackable |
| Format | JSON (Codable) | `Tests.Measurement` is already Codable; human-readable diffs |
| Keying | `{test-name}/{environment-hash}.json` | Same test on different machines = different baselines |
| Environment hash | SHA-256 of `(arch, cpuCount, optimization, featureFlags)` | Captures the factors that actually affect performance |
| Git behavior | Committed to repo | Enables CI regression detection; reviewable in PRs |

**File structure**:

```
.benchmarks/
  {module}/{suite}/{test-name}/
    {environment-hash}.json      # Serialized Tests.Measurement
    environment.json             # Human-readable environment description
```

**Threshold coexistence**: `.timed(threshold:)` remains for absolute budgets. A new `.timed(baseline: .stored)` mode compares against stored baselines using `Tests.Comparison` infrastructure that already exists.

**Storage API** (Layer 3):

```swift
extension Tests.Measurement {
    static func load(for testID: Test.ID, environment: Test.Environment) throws -> Self?
    func save(for testID: Test.ID, environment: Test.Environment) throws
}
```

### RQ4: Distribution Analysis for AI Consumption

**Findings**:

| Statistic | Formula | Diagnostic Signal | Priority |
|-----------|---------|-------------------|----------|
| **CV** (Coefficient of Variation) | `stddev / mean * 100` | CV <= 5%: trustworthy. CV > 10%: unreliable, environmental noise | MUST |
| **MAD** (Median Absolute Deviation) | `median(\|xi - median(X)\|)` | Outlier if `\|xi - median\| > 3 * MAD`. Robust to single spikes | MUST |
| **Mann-Kendall Z** | Pairwise comparison of sequential iterations | \|Z\| > 1.96: significant monotonic trend (thermal throttle if increasing) | MUST |
| **Exceedance factor** | `actual / threshold` | 3.7x immediately communicates severity | MUST |
| **Bimodal detection** | Gap between p25 and p75 vs range | Two distinct clusters suggest intermittent contention | SHOULD |
| **Mann-Whitney U** | Rank-sum comparison of two distributions | p < 0.05 + effect size >= 0.3: real difference between baseline and current | SHOULD (for baseline comparison) |

**Minimal set for AI-actionable diagnostics** (what should be in every failure report):

```
PERFORMANCE THRESHOLD EXCEEDED
  Test:    "fast path - simple attributes 10K renders"
  Metric:  median
  Expected: < 4.000s
  Actual:   11.055s
  Factor:   2.76x threshold

  Distribution:
    Median: 11.055s  Mean: 11.203s  StdDev: 0.412s
    CV:     3.68% (STABLE - result is trustworthy)
    Min:    10.621s  Max: 12.044s
    p95:    11.892s  p99: 12.044s
    MAD:    0.198s   Outliers: 0 of 10

  Trend:
    Mann-Kendall Z: 0.42 (NO TREND - not thermal throttle)

  Environment:
    Architecture:  arm64
    CPU Cores:     10 (physical) / 10 (logical)
    Memory:        32 GB
    Swift:         6.2
    Optimization:  debug (-Onone)
    Feature Flags: NonisolatedNonsendingByDefault=true, StrictMemorySafety=true
    OS:            macOS 15.3
```

An AI agent reading this can immediately determine:
1. The regression is real (low CV, no trend)
2. It's 2.76x the threshold
3. Feature flags are enabled that weren't before -- likely root cause
4. It's a debug build -- optimization level may contribute
5. No thermal throttle (no monotonic increase)
6. No outliers contaminating the measurement

### RQ5: Allocation Tracking Integration

**Findings**:

**Darwin** (`import Darwin`, no Foundation):
- `malloc_zone_statistics(nil, &stats)` provides process-wide: `blocks_in_use`, `size_in_use`, `size_allocated`, `max_size_in_use`.
- `task_info(mach_task_self_, TASK_VM_INFO, ...)` provides: `phys_footprint`, `resident_size`, `resident_size_peak`, `virtual_size`.

**Linux** (`import Glibc`):
- `mallinfo2()` (glibc 2.33+): `arena`, `uordblks` (allocated), `fordblks` (free).
- `/proc/self/statm` for resident/virtual memory.
- `getrusage(RUSAGE_SELF, &usage)` for `ru_maxrss` (peak RSS).

**Before/after pattern**:

```swift
let before = malloc_zone_statistics(nil, &beforeStats)
// ... benchmark iteration ...
let after = malloc_zone_statistics(nil, &afterStats)
let bytesDelta = after.size_allocated - before.size_allocated
```

**Caveat**: Process-wide statistics. Concurrent tests contaminate measurements. Must serialize allocation-tracked benchmarks.

**Recommendation**: Add an optional `.timed(trackAllocations: true)` parameter. When enabled:
1. Forces serial execution for that test (via `.serialized` trait)
2. Captures before/after `malloc_zone_statistics` per iteration
3. Passes `allocations` and `peakMemory` to `printPerformance` (already supported)
4. Platform-gated behind `#if canImport(Darwin)` / `#if canImport(Glibc)`

The `Tests.Error.allocationLimitExceeded`, `memoryLeakDetected`, and `peakMemoryExceeded` cases already exist in `Tests.Error` but are never thrown. Wire them up.

### RQ6: Event System Integration

**Current state**: Performance measurements are printed to stdout in `_timedScope` and then discarded. The event system (`Test.Event`) has a `.custom(name:payload:)` escape hatch that is never used for performance data.

**Option A: Use `.custom` with JSON payload**

```swift
case .custom(name: "performanceMeasured", payload: jsonEncodedMeasurement)
```

Pros: No Layer 1 changes. Works today.
Cons: Stringly-typed. Requires JSON encode/decode. `.custom` payload is `String?`, not structured.

**Option B: Add `.performanceMeasured` to `Test.Event.Kind` at Layer 1**

```swift
case performanceMeasured(name: String, payload: String)
```

Pros: Type-safe discovery. Reporters can pattern-match.
Cons: Requires Layer 1 change for a Layer 3 concern. Violates layering if the payload type is Layer 3.

**Option C: Keep `.custom` but define a structured payload convention**

The `.custom` case already exists for exactly this purpose. Define a payload schema at Layer 3:

```swift
// Layer 3 defines the schema
struct PerformancePayload: Codable {
    let measurement: Tests.Measurement
    let environment: Test.Environment
    let analysis: Tests.Analysis
}

// Emit via existing .custom
let payload = try JSONEncoder().encode(performancePayload)
sender.send(Test.Event(
    id: entry.id,
    kind: .custom(name: "performance.measured", payload: String(data: payload, encoding: .utf8)),
    elapsed: elapsed
))
```

Reporters can check for `case .custom(name: "performance.measured", let payload)` and decode.

**Recommendation**: Option C. It respects layering, uses the existing extension point, and provides structured data without Layer 1 changes. The `name` prefix `"performance."` acts as a namespace. Define constants:

```swift
extension Test.Event.Kind {
    static let performanceMeasuredName = "performance.measured"
    static let performanceBaselineUpdatedName = "performance.baseline.updated"
}
```

### RQ7: Structured Output for AI Agents

**Findings**: The primary consumers of performance diagnostics are:
1. **Humans** reading console output
2. **AI agents** (Claude, etc.) reading test failure output
3. **CI systems** checking pass/fail status

**Human output** (current): Emoji-decorated table in `printPerformance`. Good for humans, unparseable by machines.

**Machine-readable approach**: Emit a structured block alongside the human-readable output. The block uses a delimiter that AI agents can detect:

```
<!-- PERFORMANCE_DIAGNOSTIC_BEGIN -->
{
  "test": "fast path - simple attributes 10K renders",
  "status": "THRESHOLD_EXCEEDED",
  "metric": "median",
  "threshold": 4.0,
  "actual": 11.055,
  "factor": 2.76,
  "distribution": {
    "count": 10,
    "min": 10.621,
    "median": 11.055,
    "mean": 11.203,
    "max": 12.044,
    "stddev": 0.412,
    "cv": 3.68,
    "mad": 0.198,
    "p95": 11.892,
    "p99": 12.044,
    "outliers": 0
  },
  "trend": {
    "mann_kendall_z": 0.42,
    "interpretation": "NO_TREND"
  },
  "environment": {
    "arch": "arm64",
    "physical_cores": 10,
    "logical_cores": 10,
    "memory_gb": 32,
    "swift_version": "6.2",
    "optimization": "debug",
    "feature_flags": {
      "NonisolatedNonsendingByDefault": true,
      "StrictMemorySafety": true
    },
    "os": "macOS 15.3"
  },
  "durations_seconds": [10.621, 10.832, ...]
}
<!-- PERFORMANCE_DIAGNOSTIC_END -->
```

**Alternative**: A JSON reporter (`Test.Reporter.json`) that emits all events as JSON lines. Performance events (via `.custom`) flow through naturally. This is more architectural but requires a new reporter implementation.

**Recommendation**: Both. The structured block in console output is quick and serves AI agents reading test output. The JSON reporter serves CI pipelines and post-processing tools.

## Analysis: Phased Implementation

### Phase 1: Enrich Error Output (Layer 3 only, no API changes)

**Effort**: Small. **Impact**: High. **Risk**: None.

Modify `_timedScope` in `Test.Trait.ScopeProvider.timed.swift` to:

1. Compute and print exceedance factor (`actual / threshold`)
2. Compute and print CV (`stddev / mean`)
3. Compute and print MAD with outlier count
4. Compute and print Mann-Kendall Z with interpretation
5. Print environment fingerprint (compile-time flags + runtime hardware)
6. Include full measurement in the structured diagnostic block

No new types needed. All computation uses existing `Sample.Batch` and `Sample.Averaging`. Environment data via `sysctlbyname` / `#if hasFeature(...)`.

### Phase 2: New Primitive Types (Layer 1)

**Effort**: Medium. **Impact**: Medium. **Risk**: Low.

Add to **swift-sample-primitives**:

| Type | Purpose |
|------|---------|
| `Sample.Batch.coefficientOfVariation(using:)` | CV computation. Returns `Double?`. |
| `Sample.Batch.medianAbsoluteDeviation(using:)` | MAD computation. Returns `Element?`. |
| `Sample.Batch.outlierCount(using:threshold:)` | Count of values beyond `k * MAD` from median. |
| `Sample.Batch.mannKendall` | Mann-Kendall Z statistic on the original (unsorted) iteration order. **Problem**: `Batch` sorts at construction time. See below. |

**Mann-Kendall challenge**: `Sample.Batch` sorts elements at construction time. Mann-Kendall requires the original temporal ordering. Options:

- **A)** Compute Mann-Kendall on the raw `[Duration]` array in `Tests.Measurement` at Layer 3 (not in `Batch`). This is the correct layering -- `Batch` is for order statistics, trend analysis operates on time series.
- **B)** Add a `Sample.TimeSeries<T>` type at Layer 1 that preserves insertion order.

**Recommendation**: Option A for now. Mann-Kendall belongs at Layer 3 where the raw duration array is available. If time-series analysis grows, extract to Layer 1 later.

### Phase 3: Environment Type (Layer 3)

**Effort**: Medium. **Impact**: High. **Risk**: Low.

Define `Test.Environment`:

```swift
extension Test {
    struct Environment: Sendable, Codable, Hashable {
        var architecture: String          // arm64, x86_64
        var physicalCPUCount: Int
        var logicalCPUCount: Int
        var memoryBytes: UInt64
        var osVersion: String
        var swiftVersion: String          // Compile-time #if swift(>=N.M)
        var optimization: Optimization    // .debug, .release
        var featureFlags: FeatureFlags    // Compile-time #if hasFeature(...)
    }
}
```

Platform-specific capture behind `#if canImport(Darwin)` / `#if canImport(Glibc)`. Falls back to partial data when unavailable.

### Phase 4: Baseline Storage (Layer 3)

**Effort**: Large. **Impact**: High. **Risk**: Medium.

Wire up `Tests.Measurement` (already Codable) + `Test.Environment` (Phase 3) into a storage system:

1. `.benchmarks/{module}/{suite}/{test}/{environment-hash}.json` directory convention
2. `Tests.Baseline.load(for:environment:)` / `.save(for:environment:)`
3. `.timed(baseline: .stored, tolerance: 0.10)` modifier that uses `Tests.Comparison` (already implemented)
4. Connect `Tests.expectNoRegression` (already implemented) to the `.timed` trait

This bridges Gap 6 (no stored baselines) and Gap 9 (disconnected APIs).

### Phase 5: Event Integration (Layer 3)

**Effort**: Medium. **Impact**: Medium. **Risk**: Low.

Emit performance measurements as `.custom(name: "performance.measured", payload: json)` events. Implement a JSON reporter that consumes these events. This bridges Gap 10.

### Phase 6: Allocation Tracking (Layer 3, platform-gated)

**Effort**: Medium. **Impact**: Medium. **Risk**: Low.

Optional `.timed(trackAllocations: true)` that captures `malloc_zone_statistics` before/after each iteration. Wire into existing `printPerformance(allocations:peakMemory:)` parameters. Platform-gated behind `#if canImport(Darwin)`.

### Phase 7: Profiling Hooks (Layer 3, optional)

**Effort**: Small. **Impact**: Low (diagnostic enrichment). **Risk**: None.

1. `Backtrace.capture()` on threshold exceedance (SE-0419, requires `import Runtime`)
2. Optional signpost bracketing via `OSSignposter` (`#if canImport(os)`)
3. Both strictly opt-in and platform-gated

## Comparison of Options

### Error Enrichment Strategy

| Criterion | Minimal (ratio only) | Statistical (CV+MAD+trend) | Full (+ environment + structured) |
|-----------|---------------------|---------------------------|----------------------------------|
| AI actionability | Low | Medium | High |
| Implementation effort | Trivial | Small | Medium |
| Layer 1 changes | None | Optional (CV, MAD on Batch) | Optional |
| Breaking changes | None | None | None |
| Diagnostic value for humans | Marginal | Good | Excellent |

**Recommendation**: Full enrichment. The additional effort over "statistical" is primarily the environment fingerprint, which is straightforward and delivers the highest diagnostic value per line of code.

### Baseline Storage Strategy

| Criterion | No baselines (status quo) | Absolute thresholds only | Stored baselines |
|-----------|--------------------------|------------------------|-----------------|
| Machine portability | N/A | Fragile | Good (environment-keyed) |
| CI regression detection | None | Coarse | Fine-grained |
| API surface change | None | None | New storage API |
| Existing infrastructure reuse | N/A | N/A | Full (Codable Measurement, Comparison, expectNoRegression) |

**Recommendation**: Stored baselines. The infrastructure already exists and just needs wiring.

### Event Integration Strategy

| Criterion | Print to stdout (status quo) | .custom payload | New .performanceMeasured case |
|-----------|------------------------------|-----------------|-------------------------------|
| Layering | OK | OK | Violates (Layer 3 concern at Layer 1) |
| Type safety | None | String-typed | Enum-typed |
| Reporter integration | None | Full | Full |
| Layer 1 change | None | None | Required |

**Recommendation**: `.custom` payload at Layer 3.

## Outcome

**Status**: PARTIALLY IMPLEMENTED (Phases 1-3, 6 complete; Phases 4-5, 7 open)

### Phase 1: Enrich Error Output — IMPLEMENTED

`Tests.Diagnostic` struct aggregates all enrichment data. `_timedScope` in `Test.Trait.ScopeProvider.timed.swift` builds the diagnostic after measurement and emits both:
- `diagnostic.formatted()` — human-readable console output with color-coded CV/trend interpretation
- `diagnostic.jsonBlock()` — structured JSON between `<!-- PERFORMANCE_DIAGNOSTIC_BEGIN/END -->` markers

All six enrichments delivered:
- Exceedance factor (`exceedanceFactor: Double?`)
- CV with STABLE/MODERATE/NOISY interpretation
- MAD with outlier count (> 3 MAD from median)
- Mann-Kendall Z with increasing/decreasing/none interpretation
- Environment fingerprint (architecture, cores, memory, Swift version, optimization, feature flags, OS)
- Structured JSON diagnostic block

### Phase 2: New Primitive Types — IMPLEMENTED

Added to `swift-sample-primitives` at Layer 1:
- `Sample.Batch.coefficientOfVariation` — CV as `Double?`
- `Sample.Batch.medianAbsoluteDeviation` — MAD as `Element?`
- `Sample.Batch.outlierCount(threshold:)` — count beyond k × MAD

Mann-Kendall implemented at Layer 3 (`Tests.Trend.mannKendall`) per Option A — operates on raw `[Duration]` temporal order, not sorted `Batch`.

### Phase 3: Environment Type — IMPLEMENTED

`Test.Environment` at Layer 3 with:
- `Test.Environment.Features` — compile-time `#if hasFeature(...)` detection
- `Test.Environment.Optimization` — runtime assert-probing for debug/release
- `Test.Environment.capture()` — runtime hardware + OS via `import Kernel`
- `Test.Environment.fingerprint` — human-readable key (e.g., `"arm64-10c-debug-nnbd-sms"`)

Platform syscalls migrated from raw `import Darwin`/`import Glibc` to unified `import Kernel` (2026-03-03). New platform primitives added across all layers:
- L1: `Kernel.System.Memory.Capacity`, `Kernel.System.Name`, `Kernel.System.Processor.Physical`
- L2: `ISO_9945.Kernel.System.name` (POSIX `uname()`)
- L3: `Darwin.System.Processor.Physical.count`, `Darwin.System.Memory.total`, `Linux.System.Memory.total`
- L3: Unified routing via `Kernel.System.Processor.Physical.count`, `Kernel.System.Memory.total`, `Kernel.System.name`

### Phase 4: Baseline Storage — NOT STARTED

No `.benchmarks/` directory convention, no `Tests.Measurement.load/save` API, no `.timed(baseline: .stored)` modifier. The infrastructure exists (`Tests.Measurement` is Codable, `Tests.Comparison` and `Tests.expectNoRegression` are implemented) but remains disconnected from the `.timed()` trait path.

### Phase 5: Event Integration — NOT STARTED

Performance data is printed to stdout but does not flow through the `Test.Event` system. No `.custom(name: "performance.measured", payload: json)` events. No JSON reporter.

### Phase 6: Allocation Tracking — IMPLEMENTED

`_timedScope` supports `config.trackAllocations`:
- Captures `Memory.Allocation.Statistics` before/after each iteration
- Computes deltas and passes to `Tests.Diagnostic.allocations`
- Gated behind `trackAllocations` configuration flag

### Phase 7: Profiling Hooks — NOT STARTED

No backtrace capture on threshold exceedance (SE-0419). No signpost bracketing. Both remain deferred as opt-in enrichments.

### Non-Goals

- Full HTML report generation (like criterion) -- out of scope for a test framework; this belongs in external tooling
- Bootstrapped resampling (like criterion) -- too expensive for test execution; keep statistics simple and fast
- Automatic threshold calibration -- complex and error-prone; explicit thresholds are more maintainable

## References

- [SE-0419: Swift Backtrace API](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0419-backtrace-api.md)
- [ordo-one/package-benchmark](https://github.com/ordo-one/package-benchmark)
- [criterion.rs Analysis Process](https://bheisler.github.io/criterion.rs/book/analysis.html)
- [benchstat: Go benchmark comparison tool](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat)
- [pytest-benchmark documentation](https://pytest-benchmark.readthedocs.io/en/latest/)
- [WWDC 2018 Session 405: Measuring Performance Using Logging](https://asciiwwdc.com/2018/sessions/405)
- [Mann-Kendall Test for Monotonic Trend](https://vsp.pnnl.gov/help/vsample/design_trend_mann_kendall.htm)
- [Using the Median Absolute Deviation to Find Outliers](https://eurekastatistics.com/using-the-median-absolute-deviation-to-find-outliers/)
