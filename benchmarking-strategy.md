# Benchmarking Strategy

<!--
---
version: 2.0.0
last_updated: 2026-03-10
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute ecosystem uses `swift-foundations/swift-testing` for performance and snapshot testing, with `swift-foundations/swift-tests` providing the underlying infrastructure. This framework is part of an AI improvement feedback loop:

1. AI generates code
2. Unit tests validate correctness (Apple Testing, in `Tests/`)
3. Performance + snapshot tests validate quality (`Tests/Testing/`, using swift-testing)
4. AI reads structured output → iterates

### Existing Infrastructure

The current `.timed()` infrastructure is more mature than initially apparent:

| Capability | Status | Location |
|-----------|--------|----------|
| Warmup iterations | ✅ Exists | `_timedScope` in scope provider |
| Configurable iterations | ✅ Exists | `Test.Benchmark.Configuration` |
| Threshold enforcement | ✅ Exists | Pass/fail against Duration budget |
| Metric selection (median, mean, p50–p999, min, max) | ✅ Exists | `Sample.Metric` (10 cases) |
| Allocation tracking | ✅ Exists | `Memory.Allocation.Statistics` |
| Baseline storage | ✅ Exists | `.benchmarks/` dir, JSON, env-fingerprinted |
| Baseline regression detection | ✅ Exists | `Tests.Comparison`, configurable tolerance |
| Recording modes (normal/all/never) | ✅ Exists | `SWIFT_BENCHMARK_RECORD` env var |
| Statistical diagnostics | ✅ Exists | CV, MAD, outlier count, Mann-Kendall trend |
| Percentile reporting | ✅ Exists | p50, p75, p90, p95, p99, p999 via `Sample.Batch` |
| AI-parseable JSON output | ✅ Exists | `jsonBlock()` with `PERFORMANCE_DIAGNOSTIC_BEGIN/END` markers |
| Console diagnostics | ✅ Exists | `formatted()` with color-coded output |
| Environment fingerprinting | ✅ Exists | arch, cores, optimization, feature flags, OS |
| Standalone `Test.Benchmark.measure {}` | ✅ Exists | `Test.Benchmark+measure.swift` |
| Dependency injection via `Dependency.Scope` | ✅ Exists | `swift-dependency-primitives` |

A standalone measurement API already provides setup isolation:

```swift
// Existing API — setup IS isolated from measurement
@Test("move files benchmark")
func moveFiles() async throws {
    let fixture = try await FileSystemFixture.make()  // not measured
    try Test.Benchmark.measure(iterations: 3, warmup: 1, name: "move x 1000") {
        for i in 0..<1000 { try moveFile(i) }        // measured
    }
}
```

However, `Test.Benchmark.measure {}` only prints basic stats and returns a `Measurement`. It does **not** connect to the baseline/comparison/diagnostic infrastructure that `.timed()` provides.

### Existing Dependency Injection Pattern

The snapshot scope provider demonstrates context injection via `Dependency.Scope` (L1):

```swift
// From Test.Trait.ScopeProvider.snapshot — existing L1 pattern
try await Dependency.Scope.with(
    { $0[Test.Snapshot.Configuration.Key.self] = config },
    operation: operation
)
```

Since `swift-testing` can depend on `swift-dependencies` (L3) and `swift-witnesses` (L3), the benchmark implementation can use the higher-level API:

```swift
// L3 pattern — better syntax via withDependencies + @Dependency
try await withDependencies {
    $0.benchmarkContext = context
} operation: {
    try await operation()
}

// Consumer reads via property wrapper
@Dependency(\.benchmarkContext) var context
```

## Question

How should the two existing measurement mechanisms — `.timed()` (rich diagnostics, no setup isolation) and `Test.Benchmark.measure {}` (setup isolation, no diagnostics) — be unified, and what additional infrastructure is needed for run history and AI consumption?

## Gap Analysis

### Gap 1: Disconnected Measurement APIs

**Problem**: Two independent measurement systems exist with complementary strengths:

| Feature | `.timed()` trait | `Test.Benchmark.measure {}` |
|---------|-----------------|----------------------------|
| Setup isolation | ❌ Measures full body | ✅ Only measures `body` closure |
| Baseline storage | ✅ `.benchmarks/` | ❌ None |
| Regression detection | ✅ `baselineTolerance` | ❌ None |
| Statistical diagnostics | ✅ CV, MAD, outliers, Mann-Kendall | ❌ Basic print only |
| AI-parseable JSON | ✅ `jsonBlock()` with markers | ❌ None |
| Environment fingerprinting | ✅ Full capture | ❌ None |
| Allocation tracking | ✅ `Memory.Allocation.Statistics` | ❌ None |
| Threshold enforcement | ✅ Throws on exceeded | ⚠️ Prints warning only |

**Impact**: To get setup isolation, you lose all the infrastructure. To get infrastructure, you lose setup isolation. There is no way to have both.

### Gap 2: Run History

**Problem**: Baseline storage is single-point. When a new measurement is recorded, the previous baseline is overwritten. There is no time-series accumulation.

```
.benchmarks/
  MyModule/
    MySuite/
      insertion-performance/
        arm64-10c-debug-nnbd-sms.json    ← one file, overwritten
```

**Impact**: Cannot answer "how has this function's performance changed over the last 20 runs?" Cannot detect gradual drift (each individual run is within tolerance, but the trend is upward). The Mann-Kendall trend analysis exists but only operates within a single run's iterations — not across runs.

### Gap 3: Structured Cross-Run Export

**Problem**: The `jsonBlock()` output goes to stdout per-test. There is no run-level summary file aggregating all benchmark results. The AI must parse stdout, find each `PERFORMANCE_DIAGNOSTIC_BEGIN/END` block, and reassemble.

**Impact**: Fragile for the AI feedback loop. If test output is interleaved (parallel execution), blocks may be mixed. No single file the AI can read to understand "what changed in this run vs. the previous run?"

## Analysis

### Option A: Single `.timed()` with Progressive Disclosure

Make the `.timed()` scope provider aware of `Test.Benchmark.measure {}`. If the test body calls `measure {}`: use those durations for diagnostics. If not: time the full body as today.

```swift
// Level 1: Simple — whole body timed
@Test(.timed(threshold: .milliseconds(50)))
func `fast path within budget`() {
    sut.fastPath()
}

// Level 2: Setup isolation — measure {} marks the hot path
@Test(.timed(threshold: .milliseconds(50), baselineTolerance: 0.10))
func `insertion performance`() {
    let data = generateTestData(count: 10_000)      // not measured
    Test.Benchmark.measure(iterations: 100) {
        sut.insert(contentsOf: data)                 // measured
    }
}

// Level 3: Full control
@Test(.timed(
    threshold: .milliseconds(100),
    metric: .p95,
    baselineTolerance: 0.10,
    trackAllocations: true
))
func `insertion throughput`() {
    let data = generateTestData(count: 10_000)
    Test.Benchmark.measure(iterations: 200, warmup: 10) {
        sut.insert(contentsOf: data)
    }
}
```

**Mechanism**: The `.timed()` scope provider injects a `Test.Benchmark` context via `Dependency.Scope.with()` (same pattern as the snapshot scope provider). `Test.Benchmark.measure {}` reads this context from `Dependency.Scope.current` and stores its `Measurement` on it. After `operation()` returns, the scope provider reads the measurement back. If no measurement was stored: the scope provider runs its own iteration loop (current behavior).

**Parameter resolution**:

| Scenario | Who iterates | Config source |
|----------|-------------|---------------|
| No `measure {}` | Scope provider | `.timed(iterations:warmup:)` |
| With `measure {}` | `measure {}` | `measure(iterations:warmup:)` |

When `measure {}` is used, `.timed()`'s `iterations`/`warmup` are ignored — `measure {}` already iterated. The scope provider runs `operation()` once (for setup + measure + teardown), then reads the result.

**Advantages**:
- One trait, one mental model: "time this test"
- Progressive disclosure: start simple, add `measure {}` when you need setup isolation
- Backward compatible — existing `.timed()` tests unchanged
- All diagnostic infrastructure (baseline, comparison, JSON, env fingerprint) applies to both paths
- All performance tests in one `.Performance` suite
- Uses existing `Dependency.Scope` pattern (proven by snapshot provider)
- `Test.Benchmark.measure {}` already exists — just needs to read/write the injected context

**Disadvantages**:
- `.timed()` behaves differently based on whether `measure {}` is called (progressive disclosure, not hidden mode — the user explicitly opted in by calling `measure {}`)
- When both `.timed(iterations:)` and `measure(iterations:)` are specified, `measure` wins silently

### Option B: Two-Tier System — `.timed()` + `.benchmarked()`

Keep `.timed()` for budget checks. New `.benchmarked()` trait requires `Test.Benchmark.measure {}`.

```swift
@Test(.timed(threshold: .milliseconds(50)))
func `fast path`() { sut.fastPath() }

@Test(.benchmarked(baselineTolerance: 0.10))
func `insertion`() {
    let data = setup()
    Test.Benchmark.measure(iterations: 100) { sut.insert(contentsOf: data) }
}
```

**Advantages**:
- Trait name declares behavior explicitly
- No parameter ambiguity

**Disadvantages**:
- Two traits for one concept (performance measurement)
- User must choose between them — naming ceremony
- New `.Benchmark` suite in `#Tests` macro
- Consumer confusion: "when do I use `.timed()` vs `.benchmarked()`?"

### Option C: Enhance `Test.Benchmark.measure {}` Directly

No trait involvement. Upgrade `measure {}` to include baseline storage and diagnostics.

```swift
@Test
func `insertion`() {
    let data = setup()
    try Test.Benchmark.measure(
        iterations: 100,
        baseline: .track(tolerance: 0.10)
    ) { sut.insert(contentsOf: data) }
}
```

**Advantages**:
- Simplest mental model: just a function call

**Disadvantages**:
- No trait-based test discovery (`swift test --filter Performance`)
- No `.serialized` / `.exclusive` traits applied automatically
- No `#Tests` scaffolding integration
- Each call must independently capture environment, resolve baseline path
- Test runner doesn't know it's a benchmark

### Option D: Integrate package-benchmark (Ordo One)

**Advantages**: Mature, production-tested, rich CLI, multiple export formats.

**Disadvantages**: External dependency, SwiftPM command plugins (not `swift test`), cannot share test fixtures, no `@Test` / `#Tests` integration, different mental model.

## Prior Art Survey

### Criterion.rs (Rust — Gold Standard)

Four-phase model: warmup → measurement → analysis → comparison. Setup isolation via `iter_with_large_setup()`. Named baselines with T-test + bootstrap confidence intervals for regression detection.

**Key insight**: Separates "is this a real regression?" (statistical test) from "how big is it?" (effect size).

### Package-benchmark (Ordo One / Swift)

Setup/teardown closures excluded from measurement. Baselines in `.benchmarkBaselines/`. CI integration via exit codes. GitHub Actions templates.

### XCTest (Apple — Legacy)

`measure {}` block within test function — only the block is timed. Per-machine `.xcbaselines/`.

**Key insight**: The "explicit measure block" pattern is well-understood and ergonomic.

### BenchmarkDotNet (C#)

`[IterationSetup]` / `[GlobalSetup]` attributes. Exports: Markdown, CSV, HTML, JSON. `ResultsComparer` for diffing baseline JSON.

**Key insight**: The "summary report as a single diffable file" pattern is valuable for automation.

## Comparison

| Criterion | A: Single `.timed()` | B: Two traits | C: Enhance `measure {}` | D: package-benchmark |
|-----------|---------------------|---------------|------------------------|---------------------|
| Setup isolation | ✅ Via `measure {}` | ✅ Via `measure {}` | ✅ Native | ✅ Setup closure |
| Mental model | ✅ One trait | ⚠️ Two traits, one concept | ✅ Just a function | ⚠️ Two systems |
| Backward compatible | ✅ Fully | ✅ `.timed()` unchanged | ✅ Additive | ❌ Different tool |
| Baseline/comparison | ✅ Existing pipeline | ✅ Existing pipeline | ⚠️ Must reimplement | ✅ Built-in |
| Test discovery | ✅ Via trait | ✅ Via trait | ❌ No trait | ❌ Separate CLI |
| `#Tests` scaffolding | ✅ Existing `.Performance` | ⚠️ New `.Benchmark` suite | ❌ None | ❌ Outside `@Test` |
| Change surface | Small | Medium | Medium | Large |
| Progressive disclosure | ✅ Natural | ❌ Choose upfront | N/A | N/A |

## Recommendation

**Option A: Single `.timed()` with progressive disclosure, bridged via `Dependency.Scope`.**

### Rationale

1. **One concept, one trait.** The user's intent is always "time this test." The distinction between budget and benchmark is configuration, not a different concept. `.timed()` with progressive disclosure matches intent-over-mechanism.

2. **Progressive disclosure, not hidden modes.** The user explicitly calls `Test.Benchmark.measure {}` to mark the hot path — that's an opt-in, not a surprise. Same pattern as XCTest's `measure {}`. If you don't call it, the whole body is measured. If you do, only the block is measured. Self-evident.

3. **Proven injection pattern.** The snapshot scope provider already uses `Dependency.Scope.with()` to inject `Test.Snapshot.Configuration` into the test body. The benchmark scope provider does the same with `Test.Benchmark` context. No new mechanism needed.

4. **Clean parameter ownership.** `.timed()` owns the "what to do with results" config: `threshold`, `metric`, `baselineTolerance`, `trackAllocations`, `printResults`. `measure()` owns the "how to iterate" config: `iterations`, `warmup`. Different concerns, different sites. When `measure {}` is present, the scope provider delegates iteration to it and only consumes the result.

5. **All performance tests stay in `.Performance`.** No new `#Tests` macro suite needed. `swift test --filter Performance` gets everything.

6. **Future: parameter injection.** The `Dependency.Scope` infrastructure also enables `func test(benchmark: Test.Benchmark)` parameter injection later — the macro reads from `Dependency.Scope.current[Test.Benchmark.Key.self]` and passes it as the argument. But `Test.Benchmark.measure {}` (static, reading from `Dependency.Scope.current`) is fine now.

### User Experience

```swift
extension MyType.Test.Performance {
    // Budget: whole body timed
    @Test(.timed(threshold: .milliseconds(50)))
    func `fast path within budget`() {
        sut.fastPath()
    }

    // Benchmark: setup isolated, tracked over time
    @Test(.timed(
        threshold: .milliseconds(100),
        baselineTolerance: 0.10
    ))
    func `insertion throughput`() {
        let data = generateTestData(count: 10_000)
        Test.Benchmark.measure(iterations: 100, warmup: 5) {
            sut.insert(contentsOf: data)
        }
    }
}
```

## Implementation

### Phase 1: Bridge `.timed()` with `Test.Benchmark.measure {}`

**Mechanism**: The `.timed()` scope provider injects a `Test.Benchmark.Runner` witness via `withDependencies`. The witness provides the `measure` capability with closures that capture a `Mutex<Measurement?>`. `Test.Benchmark.measure {}` delegates to `@Dependency(\.benchmarkRunner)`. After the operation returns, the scope provider reads the measurement from the captured `Mutex`. No reference type injection hack — output flows through standard closure capture semantics.

**Why witness, not reference type**: `Dependency.Scope` uses value semantics by design (downward propagation). Injecting a class to create a bidirectional channel circumvents this. The witness pattern is principled: the scope provider injects a *capability* (downward), the test body consumes it (downward), and the result flows through the closure's captured state — standard closure behavior. Validated empirically: `swift-institute/Experiments/dependency-scope-writeback/` (closure capture through `Dependency.Scope` is visible to the caller, all 6 variants CONFIRMED).

**1a. Define the witness** (in `swift-tests` or `swift-testing`):

```swift
extension Test.Benchmark {
    /// Injectable measurement capability.
    /// The `.timed()` scope provider overrides the default with a version
    /// that captures output for baseline comparison and diagnostics.
    @Witness
    public struct Runner: Sendable {
        public var measure: @Sendable (
            _ iterations: Int,
            _ warmup: Int,
            _ body: @Sendable () -> Void
        ) -> Measurement
    }
}

// Dependency key
extension Test.Benchmark.Runner: Dependency.Key {
    /// Default: measure + print (current behavior, no baseline tracking).
    public static var liveValue: Test.Benchmark.Runner {
        .init(measure: { iterations, warmup, body in
            for _ in 0..<warmup { body() }
            var durations: [Duration] = []
            for _ in 0..<iterations {
                let start = Clock.Continuous.now
                body()
                durations.append(Clock.Continuous.now - start)
            }
            return Measurement(durations: durations)
        })
    }
}

// KeyPath accessor
extension Dependency.Values {
    public var benchmarkRunner: Test.Benchmark.Runner {
        get { self[Test.Benchmark.Runner.self] }
        set { self[Test.Benchmark.Runner.self] = newValue }
    }
}
```

**1b. Modify `.timed()` scope provider** (in `swift-tests`, `Tests Performance`):

```swift
private static func _timedScope(
    _ entry: Test.Plan.Entry,
    _ traits: Test.Trait.Collection,
    _ operation: @Sendable () async throws(Error) -> Void
) async throws(Error) {
    let config = traits[Test.Trait.Timed.self]!

    // Create a Runner witness with closures that capture the output
    let output = Mutex<Test.Benchmark.Measurement?>(nil)

    let runner = Test.Benchmark.Runner(
        measure: { iterations, warmup, body in
            for _ in 0..<warmup { body() }
            var durations: [Duration] = []
            durations.reserveCapacity(iterations)
            for _ in 0..<iterations {
                let start = Clock_Primitives.Clock.Continuous.now
                body()
                durations.append(Clock_Primitives.Clock.Continuous.now - start)
            }
            let m = Test.Benchmark.Measurement(durations: durations)
            output.withLock { $0 = m }
            return m
        }
    )

    // Inject the runner and execute the test body
    try await withDependencies {
        $0.benchmarkRunner = runner
    } operation: {
        try await operation()
    }

    let measurement: Test.Benchmark.Measurement
    if let captured = output.withLock({ $0 }) {
        // measure {} was called — use its durations
        measurement = captured
    } else {
        // No measure {} — fall back to whole-body iteration (current behavior)
        // The first invocation above serves as additional warmup
        for _ in 0..<config.warmup {
            try await operation()
        }
        var durations: [Duration] = []
        durations.reserveCapacity(config.iterations)
        for _ in 0..<config.iterations {
            let start = Clock_Primitives.Clock.Continuous.now
            try await operation()
            durations.append(Clock_Primitives.Clock.Continuous.now - start)
        }
        measurement = Test.Benchmark.Measurement(durations: durations)
    }

    // ... existing diagnostic pipeline (environment, baseline, comparison, JSON) ...
}
```

**1c. Modify `Test.Benchmark.measure {}`** (in `swift-tests`):

Delegate to the injected witness:

```swift
@discardableResult
public static func measure<E: Swift.Error>(
    iterations: Int = 10,
    warmup: Int = 0,
    name: Swift.String? = nil,
    threshold: Duration? = nil,
    metric: Metric = .median,
    _ body: () throws(E) -> Void
) throws(E) -> Measurement {
    // Delegate to the injected runner (scope provider's version captures output;
    // default liveValue just measures and returns)
    @Dependency(\.benchmarkRunner) var runner
    let measurement = runner.measure(iterations, warmup, body)

    // Print and threshold check (existing behavior)
    let displayName = name ?? "Benchmark"
    printPerformance(displayName, measurement)

    if let threshold, metric.extract(from: measurement) > threshold {
        print("⚠️ Performance threshold exceeded in '\(displayName)'")
    }

    return measurement
}
```

### Phase 2: Run History

**Storage extension** (in `swift-tests`):

```
.benchmarks/
  {module}/{suite}/{test}/{fingerprint}/
    baseline.json        ← the reference point (as today)
    runs.jsonl           ← append-only, one JSON line per run
```

Each line in `runs.jsonl`:
```json
{"timestamp":"2026-03-10T14:30:00Z","metric":"median","value":0.042,"iterations":100,"cv":3.2,"p95":0.048,"p99":0.051}
```

**Trimming**: Keep last N runs (configurable, default 100). Trim on write.

**Cross-run trend**: Apply Mann-Kendall across `runs.jsonl` values (reuse existing `Tests.Trend.mannKendall`). Report in the diagnostic JSON: `"history_trend": "increasing"`, `"history_trend_z": 2.1`.

### Phase 3: Run-Level Summary + AI Export

After all tests in a run complete, write a consolidated summary:

```
.benchmarks/
  runs/
    {timestamp}.json
```

```json
{
  "run_id": "2026-03-10T14:30:00Z",
  "environment": { "arch": "arm64", "cores": 10, "optimization": "debug" },
  "benchmarks": [
    {
      "test": "MyModule/MySuite/insertion-throughput",
      "metric": "median",
      "value": 0.042,
      "baseline": 0.045,
      "change": -0.066,
      "status": "improvement",
      "cv": 3.2,
      "trend_z": -1.2,
      "trend": "no_trend"
    }
  ],
  "summary": {
    "total": 12,
    "regressions": 1,
    "improvements": 3,
    "unchanged": 8
  }
}
```

**AI consumption**: The AI reads `runs/{latest}.json`. Single file, deterministic structure, no stdout parsing.

**Delivery mechanism**: Reporter collects diagnostic events during the run and writes the summary at `finish()`. Aligns with existing reporter architecture.

## Open Questions

1. ~~**`Dependency.Scope` mutability**~~: **RESOLVED.** Witness pattern: scope provider injects `Test.Benchmark.Runner` witness with closures that capture a `Mutex<Measurement?>`. Output flows through closure capture — no reference type hack. Validated: `swift-institute/Experiments/dependency-scope-writeback/` (6 variants, all CONFIRMED).

2. **`measure {}` print suppression**: When running under `.timed()`, `measure {}` delegates to the injected `Runner` which does NOT print. The scope provider's diagnostic pipeline handles output. The `liveValue` (default, not under `.timed()`) retains the current print behavior.

3. **Multiple `measure {}` calls**: What if the test body calls `measure {}` twice? The `Mutex` captures the last write. Options: (a) last write wins (current), (b) error on second call, (c) aggregate. Recommendation: error — one measurement per test.

4. ~~**Async `measure {}`**~~: **RESOLVED.** `@TaskLocal` preserves the injected witness across `await` points. Validated in experiment variant 4.

5. **JSONL rotation**: Keep last 100 runs by default. Environment variable `SWIFT_BENCHMARK_HISTORY_LIMIT` for override.

6. **Cross-run trend**: Report automatically in the diagnostic JSON. The AI needs "trend: gradually increasing over 20 runs" without asking for it.

7. **`@Witness` macro availability**: The `Runner` witness needs `@Witness` from `swift-witnesses`. Verify that `swift-tests` (where the scope provider lives) can depend on `swift-witnesses`. If not, hand-roll the struct with closure properties — the `@Witness` macro is syntactic sugar over this pattern.

## References

- Existing research: `swift-institute/Research/nested-testing-package-structure.md` (DECISION)
- Existing research: `swift-institute/Research/comparative-swift-testing-frameworks.md` (IN_PROGRESS)
- Skill: `testing-institute` ([INST-TEST-*])
- `.timed()` scope provider: `swift-tests/Sources/Tests Performance/Test.Trait.ScopeProvider.timed.swift`
- `Test.Benchmark.measure {}`: `swift-tests/Sources/Tests Performance/Test.Benchmark+measure.swift`
- Snapshot scope provider (injection pattern): `swift-tests/Sources/Tests Snapshot/Test.Trait.ScopeProvider.snapshot.swift`
- `Dependency.Scope` (L1): `swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Scope.swift`
- `withDependencies` (L3): `swift-dependencies/Sources/Dependencies/withDependencies.swift`
- `@Dependency` (L3): `swift-dependencies/Sources/Dependencies/Dependency.swift`
- Experiment: `swift-institute/Experiments/dependency-scope-writeback/` (6 variants, all CONFIRMED)
- Baseline storage: `swift-tests/Sources/Tests Performance/Tests.Baseline.Storage.swift`
- Baseline recording: `swift-tests/Sources/Tests Performance/Tests.Baseline.Recording.swift`
- Diagnostics: `swift-tests/Sources/Tests Performance/Tests.Diagnostic+Format.swift`
- Comparison: `swift-tests/Sources/Tests Performance/Tests.Comparison.swift`
- Configuration: `swift-test-primitives/Sources/Test Primitives Core/Test.Benchmark.Configuration.swift`
- Metrics: `swift-sample-primitives/Sources/Sample Primitives Core/Sample.Metric.swift`
- Mann-Kendall: `swift-tests/Sources/Tests Performance/Tests.Trend+MannKendall.swift`
- `#Tests` macro: `swift-testing/Sources/Testing Macros Implementation/TestsMacro.swift`
- Test runner (scope chaining): `swift-tests/Sources/Tests Performance/Test.Runner.swift` (lines 422–451)
- Prior art: [Criterion.rs](https://bheisler.github.io/criterion.rs/book/) — four-phase model, bootstrap CI
- Prior art: [package-benchmark](https://github.com/ordo-one/package-benchmark) — setup/teardown, CI integration
- Prior art: [BenchmarkDotNet](https://github.com/dotnet/BenchmarkDotNet) — ResultsComparer for JSON diffing
