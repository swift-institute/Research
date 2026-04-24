# swift-testing-performance → swift-testing API Migration Map

<!--
---
version: 1.0.0
last_updated: 2026-04-22
status: DECISION
tier: 2
scope: ecosystem-wide
---
-->

## Summary

Durable symbol-by-symbol mapping from `coenttb/swift-testing-performance`
(PUBLIC, 6 stars, tag 0.3.1) to the successor `swift-foundations/swift-testing`
monorepo. The successor is decomposed into three layers (`swift-test-primitives`,
`swift-tests`, `swift-testing`) and re-exports the performance infrastructure
through `Tests Performance` (transitively exposed by the `Testing` umbrella
module). This table is the canonical reference for all future migrations of
ecosystem packages whose test targets currently import `TestingPerformance`.

## Scope

- **Source package** (deprecation target): `coenttb/swift-testing-performance`,
  single target `TestingPerformance`.
- **Destination stack**:
  - `swift-foundations/swift-testing` — umbrella products `Testing`, `Testing Core`,
    `Testing Effects`, `Testing Test Support`.
  - `swift-foundations/swift-tests` — transitively re-exports `Tests`,
    `Tests Core`, `Tests Performance`, `Tests Snapshot`, `Tests Reporter`,
    `Tests Apple Testing Bridge`.
  - `swift-primitives/swift-test-primitives` — `Test Primitives` + `Test Primitives Core`
    (`Test.Benchmark.*` data types).
- **Consumer cohort (7 packages)**: swift-css, swift-html-css-pointfree,
  swift-html-rendering, swift-pdf, swift-pdf-rendering, swift-renderable,
  swift-file-system.
- **Scope exclusion**: `TestingPerformance` symbols related to platform-specific
  `Threshold` struct and `PerformanceSuite`/`PerformanceComparison` types that
  have no public consumer in the 7-package cohort (see "Unused public surface").

## Consumer-facing module change

| Before | After |
|--------|-------|
| `import TestingPerformance` | `import Testing` (umbrella; re-exports `Tests_Performance` + `Test_Primitives`) |
| `.package(url: "https://github.com/coenttb/swift-testing-performance", from: "0.1.0")` | `.package(path: "../../swift-foundations/swift-testing")` (local) or `.package(url: "https://github.com/swift-foundations/swift-testing", …)` |
| `.product(name: "TestingPerformance", package: "swift-testing-performance")` | `.product(name: "Testing", package: "swift-testing")` |

All `TestingPerformance` usage in the 7-package cohort sits inside test targets
(see `nested-testing-package-structure.md` and `nested-testing-package-flattening.md`
— the ecosystem already routes test targets to a nested `Tests/Package.swift`
that depends on `swift-foundations/swift-testing`). No Sources/ target imports
`TestingPerformance` except `swift-renderable`'s `Rendering TestSupport`
umbrella, which re-exports it.

## Full symbol mapping

Columns:
- **Old symbol** — fully-qualified path in `TestingPerformance`.
- **New symbol** — fully-qualified path in the successor stack.
- **Class** — `clean` (mechanical rename or near-identical), `shape-shift`
  (requires consumer-side edit beyond rename), `breaking` (semantic delta
  that changes test authorship), `deprecated-drop` (removed; no replacement
  needed).
- **Notes** — consumer-visible behaviour change; recommended rewrite.

### A. Namespace + Trait API (used by all 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `enum TestingPerformance` | `enum Tests` (in `Tests Core`) — runtime namespace; `enum Testing` — library facade | shape-shift | The old package is both namespace and API surface. In the new stack, `Testing` is the library-level facade (umbrella) while `Tests` / `Test` / `Test.Benchmark` hold the actual types. Consumers rarely reference the namespace directly; only the trait matters for the cohort. |
| `.timed(iterations:warmup:threshold:trackAllocations:maxAllocations:metric:detectLeaks:peakMemoryLimit:sourceLocation:)` on `Trait` | `.timed(iterations:warmup:threshold:metric:trackAllocations:baselineTolerance:)` on `Test.Trait.Collection.Modifier` | **breaking** | New signature drops `maxAllocations`, `detectLeaks`, `peakMemoryLimit`, `sourceLocation`; adds `baselineTolerance`. Default for `trackAllocations` changed `true → false`. Parameter order changed (`metric` moved before `trackAllocations`). All 7 consumers use only `iterations`, `warmup`, `threshold`, `trackAllocations` — a clean subset. See "Parameter-level delta" below. |
| `.detectLeaks(sourceLocation:)` on `Trait` | (no direct equivalent) | **breaking** | Removed. Recommended pattern: consumers relying on leak detection should drop the call; the new stack's `.timed(trackAllocations:)` surfaces allocation statistics via `Tests.Diagnostic`. If strict leak-failure is required, escalate. **Unused in the 7-package cohort.** |
| `.trackPeakMemory(limit:sourceLocation:)` on `Trait` | (no direct equivalent) | **breaking** | Removed. No replacement in the new stack's public surface. **Unused in the 7-package cohort.** |
| `_PerformanceTrait` struct | `Test.Trait.Timed` witness-key + `Test.Benchmark.Configuration` value + `Test.Trait.Scope.Provider.timed` | shape-shift | Internal type. Not referenced by consumers — no migration work. |
| `TestingPerformance.Configuration` (internal) | `Test.Benchmark.Configuration` (public) with nested `Iteration` / `Evaluation` | shape-shift | Internal → public in new stack; structure changed. No consumer migration work. |

### B. Measurement API (used by 0 of 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `TestingPerformance.measure<T>(warmup:iterations:operation: () -> T)` (sync) | `Tests.measure<T>(warmup:iterations:operation: () -> T)` | clean | Signature identical; return tuple changed from `(result: T, measurement: TestingPerformance.Measurement)` to `(result: T, measurement: Test.Benchmark.Measurement)`. |
| `TestingPerformance.measure<T>(…operation: () async throws -> T)` (async rethrows) | `Tests.measure<T, E: Swift.Error>(…operation: () async throws(E) -> T)` (typed throws) | shape-shift | Typed throws is the only semantic change; existing call sites re-type automatically under inference. |
| `TestingPerformance.time<T>(operation:)` (sync + async) | `Tests.time<T>(operation:)` (sync + async) | clean | Identical shape; typed throws on the async variant. |
| `Test.Benchmark.measure<E>(iterations:warmup:name:threshold:metric:_:)` | (existed only in new stack) | new | Optional new convenience; same-state (in-function) measurement variant alongside the trait-based per-iteration form. |

### C. Assertions (used by 0 of 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `TestingPerformance.expectPerformance<T>(lessThan:warmup:iterations:metric:operation:)` (sync + async) | `Tests.expect<T>(lessThan:warmup:iterations:metric:operation:)` | shape-shift | Renamed `expectPerformance` → `expect`. Error type changed from `TestingPerformance.Error.performanceExpectationFailed` to `Tests.Error.benchmarkFailed(.thresholdExceeded(…))`. Return tuple's measurement type changes per B. |
| `TestingPerformance.expectNoRegression(current:baseline:tolerance:metric:)` | `Tests.expectNoRegression(current:baseline:tolerance:metric:)` | clean | Identical API; measurement type + error type shift per B and below. |

### D. Measurement data type (used by 0 of 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `TestingPerformance.Measurement` (struct, `Sendable & Codable`) | `Test.Benchmark.Measurement` (struct, `Sendable & Codable`) | clean | Same public shape: `durations`, `init(durations:)`. Adds pre-computed `batch: Sample.Batch<Duration>`. All statistical accessors preserved (`min`, `max`, `median`, `mean`, `p50` – `p999`, `percentile(_:)`, `standardDeviation`); plus new `coefficientOfVariation`, `medianAbsoluteDeviation`, `outlierCount(threshold:)`. |
| `TestingPerformance.Measurement: Comparable` (by median) | `Test.Benchmark.Measurement: Comparable` (by median) | clean | Identical. |
| `Measurement.isSignificantlyDifferent(from:confidenceLevel:)`, `.isSignificantlyFaster(than:…)`, `.isSignificantlySlower(than:…)` (Welch's t-test) | (no direct equivalent) | **breaking** | No public Welch's t-test in the new stack. The new stack's `coefficientOfVariation` and `Tests.Comparison` cover the common case; for rigorous significance testing, escalate. **Unused in the 7-package cohort.** |

### E. Metric enum (used indirectly by all 7 via default `.median`)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `TestingPerformance.Metric` (`enum: String, Sendable`) cases `.min` / `.max` / `.median` / `.mean` / `.p95` / `.p99` | `Test.Benchmark.Metric` = `Sample.Metric` (typealias) | shape-shift | Case parity present. The new `Sample.Metric` extends with p50, p75, p90, p999 and arbitrary percentiles. Existing `.median` / `.p95` / `.p99` call sites are source-compatible. |
| `Metric.extract(from: Measurement)` | `Sample.Metric.extract(from: Test.Benchmark.Measurement)` via extension in `swift-test-primitives` | clean | Same method name + shape. |

### F. Reporting + Suite (used by 0 of 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `TestingPerformance.printPerformance(_:_:allocations:peakMemory:)` | `Test.Benchmark.printPerformance(_:_:)` (internal / `@usableFromInline`) | **breaking (surface)** | Now internal in new stack; printing is done automatically by `Tests.Diagnostic.Collector` after the run. Public consumers who previously called this manually should drop the call. **Unused in the 7-package cohort.** |
| `TestingPerformance.formatDuration(_:_:)` and `TestingPerformance.Format` | `Duration.formatted()` (stdlib / `Time_Primitives`) | shape-shift | Replaced by stdlib `Duration.formatted()` — drop the wrapper. |
| `struct PerformanceComparison` (top-level public) | `Tests.Comparison` | shape-shift | Renamed + moved under `Tests` namespace. Same roles: `name`, `current`, `baseline`, `metric`, `change`, `currentValue`, `baselineValue`, `isRegression`, `isImprovement`, `formatted()`. **Unused in the 7-package cohort.** |
| `TestingPerformance.printComparisonReport(_:)` | (no direct equivalent) | **breaking** | Removed. Collector / Reporter in new stack prints automatically; standalone batch report has no replacement. **Unused in the 7-package cohort.** |
| `struct PerformanceSuite` (top-level public) with `.benchmark(_:warmup:iterations:operation:)` and `.printReport(metric:)` | (no direct equivalent) | **breaking** | Removed. The new stack's pattern is trait-based: wrap tests in a `@Suite(.serialized)` and let `Tests.Diagnostic.Collector` emit the summary table. **Unused in the 7-package cohort.** |

### G. AllocationTracking (used by 0 of 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `typealias TestingPerformance.AllocationStats = MemoryAllocation.AllocationStats` | `Memory.Allocation.Statistics` (in `swift-foundations/swift-memory`) | shape-shift | Renamed; package moved from `coenttb/swift-memory-allocation` (external) to ecosystem-internal `Memory` namespace. Exposed via `Tests.Diagnostic.allocations` in new stack. **Unused in the 7-package cohort.** |
| `@_exported import MemoryAllocation` from `TestingPerformance` | not re-exported in new stack | shape-shift | Consumers wanting allocation types must `import Memory` directly (foundations package). **Unused in the 7-package cohort.** |
| `TestingPerformance.startTracking()` / `.stopTracking()` (Linux only) | (no direct public equivalent) | **deprecated-drop** | New stack handles allocation tracking inline from `.timed(trackAllocations: true)`; there is no explicit start/stop. **Unused in the 7-package cohort.** |

### H. Threshold (used by 0 of 7 consumers)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `struct Threshold` (top-level, platform-specific) with `.all(_:)`, `.apple(_:)`, `.darwin(_:)`, `.current`, `ExpressibleByNilLiteral` | (no direct equivalent) | **breaking** | No platform-specific threshold struct in the new stack. `.timed(threshold:)` takes a plain `Duration?`. Recommended consumer pattern if needed: gate the `@Test(.timed(…))` attribute with `#if os(…)` compilation conditions. **Unused in the 7-package cohort.** |

### I. Error type (used by 0 of 7 consumers as a value)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `TestingPerformance.Error` with cases `.thresholdExceeded`, `.allocationLimitExceeded`, `.memoryLeakDetected`, `.peakMemoryExceeded`, `.performanceExpectationFailed`, `.regressionDetected` | `Tests.Error` (`Tests Performance` module) with nested `.benchmarkFailed(Test.Benchmark.Error)` — see `Test.Benchmark.Error` in `swift-test-primitives` | shape-shift | Case set is a near-superset (`.thresholdExceeded`, `.regressionDetected`, `.baselineMissing`). `.allocationLimitExceeded`, `.memoryLeakDetected`, `.peakMemoryExceeded`, `.performanceExpectationFailed` have no direct cases (the first three because the corresponding traits are dropped; the fourth is folded into `.thresholdExceeded`). Per [API-ERR-001], the new error is typed-throws-aware. **Unused in the 7-package cohort.** |

### J. Duration extension (internal)

| Old symbol | New symbol | Class | Notes |
|---|---|---|---|
| `extension Duration { var inSeconds / inMilliseconds / inMicroseconds / inNanoseconds: Double }` (internal utilities) | Same extension in `swift-time-primitives` / `Time_Primitives` (public) | clean | Semantic parity; location shifts. No consumer migration work. |

## Parameter-level delta on `.timed()`

Only this one API is actually used by the 7-package cohort. All migration work flows through this row.

| Parameter | Old default | New default | Delta | Cohort impact |
|---|---|---|---|---|
| `iterations: Int` | 10 | 10 | none | used by all 7 cohort files; source-compatible |
| `warmup: Int` | 0 | 0 | none | used by cohort; source-compatible |
| `threshold: Duration?` | nil | nil | none | used by cohort; source-compatible |
| `metric: Metric` | `.median` | `.median` | type path changes: `TestingPerformance.Metric` → `Test.Benchmark.Metric`; callers use `.median` literal only | source-compatible via literal inference |
| `trackAllocations: Bool` | **true** | **false** | default flipped | cohort files that call `.timed(trackAllocations: false)` remain correct; cohort files that do not pass `trackAllocations` will silently lose allocation tracking on migration — acceptable because none read allocation stats |
| `maxAllocations: Int?` | nil | *removed* | **hard break** | unused by cohort |
| `detectLeaks: Bool` | false | *removed* | **hard break** | unused by cohort |
| `peakMemoryLimit: Int?` | nil | *removed* | **hard break** | unused by cohort |
| `sourceLocation: SourceLocation` | `#_sourceLocation` | *removed* (handled by macro attribution) | soft break | unused by cohort |
| `baselineTolerance: Double?` | (absent) | nil | new feature | not required; opt-in per test |

**Net conclusion for cohort**: every `.timed()` call site in the 7-package cohort is either
(a) source-compatible after the module swap, or (b) requires deletion of a
parameter (`maxAllocations:`) that none of them pass. A full scan of the 12
cohort files confirms only `iterations`, `warmup`, `threshold`, `trackAllocations`
are used — all 4 survive with identical semantics except for the `trackAllocations`
default flip, which is immaterial here because nothing in the cohort reads the
allocation output.

## Unused public surface (informational)

Symbols below exist in `TestingPerformance` but are not referenced by any of
the 7 cohort packages. They shape disposition (archive is acceptable precisely
because no consumer depends on them) but do not drive migration work:

- `.detectLeaks()` trait
- `.trackPeakMemory(limit:)` trait
- `TestingPerformance.measure(…)` / `.time(…)` (all 4 overloads)
- `TestingPerformance.expectPerformance(…)` (sync + async)
- `TestingPerformance.expectNoRegression(…)`
- `TestingPerformance.Measurement` direct construction / statistical accessors
- `TestingPerformance.Measurement.isSignificantlyDifferent(…)` and friends (Welch's t-test)
- `TestingPerformance.Metric` as a value (e.g., passed as argument)
- `TestingPerformance.printPerformance(…)`, `.printComparisonReport(…)`, `.formatDuration(…)`, `.Format`
- `struct PerformanceSuite`, `struct PerformanceComparison`
- `struct Threshold` and all factory methods
- `TestingPerformance.Error` as a caught value
- `typealias AllocationStats`; `startTracking()` / `stopTracking()` (Linux)

## Counts

- **`TestingPerformance` public symbol count**: 44
  (1 namespace + 7 error cases + 1 trait extension with 3 factory methods +
  8 measurement accessors + 4 measurement methods + 2 measurement API overloads ×2 +
  2 assertion functions ×2 + 1 regression function + 1 Metric enum with 6 cases +
  1 extract method + 1 Format enum + 1 formatDuration method + 1 print function +
  1 struct PerformanceComparison with 7 members + 1 struct PerformanceSuite
  with 4 methods + 1 struct Threshold with 4 factory methods + `current` + 1 typealias +
  2 tracking functions + Welch's 3 methods + internal Duration extensions).
- **New-stack public symbol count (replacement surface actually reached by
  the migration)**: 28 (focused on `Tests.measure`, `Tests.time`, `Tests.expect`,
  `Tests.expectNoRegression`, `Test.Benchmark.Measurement` + accessors,
  `Test.Benchmark.Metric`, `.timed()` modifier, `Tests.Error`, `Tests.Comparison`,
  `Tests.Diagnostic`).
- **Clean mappings**: 9.
- **Shape-shifts (require edits beyond rename)**: 10.
- **Hard breaks (no replacement, consumer must drop use)**: 8.
- **Deprecated-drop (removed, no consumer need)**: 1.

## Migration recipe for a single consumer file

1. Replace `import TestingPerformance` with nothing (if the file also imports
   `Testing`, TestingPerformance's trait surface is already covered by the
   umbrella). If the file was relying on `@_exported import Testing` from
   `TestingPerformance`, add an explicit `import Testing`.
2. Remove any `maxAllocations:` / `detectLeaks` / `peakMemoryLimit:` /
   `sourceLocation:` parameters from `.timed(…)` calls (none present in the
   7-package cohort).
3. If the file references `TestingPerformance.Metric.*` as a named value, rename
   to `Test.Benchmark.Metric.*` (none present in the cohort).
4. If the file constructs `TestingPerformance.Measurement`, `PerformanceSuite`,
   `PerformanceComparison`, or `Threshold` directly, consult the migration map
   (none present in the cohort).
5. Remove the `TestingPerformance` product + package from the nearest
   `Tests/Package.swift` (or `Package.swift` for `swift-renderable`'s
   `Rendering TestSupport`) and drop the `.package(url: …/swift-testing-performance, …)`
   dependency.

## Cross-references

- [comparative-swift-testing-frameworks.md](comparative-swift-testing-frameworks.md)
  — Tier 3 architectural comparison of Apple vs Institute `swift-testing`.
- [swift-testing-performance-infrastructure-gaps.md](swift-testing-performance-infrastructure-gaps.md)
  — Tier 2 prior art on performance testing infrastructure (4 issues resolved
  within the new `Tests Performance` module).
- [nested-testing-package-structure.md](nested-testing-package-structure.md)
  — Tier 1 layout pattern for tests that depend on `swift-testing`.
- [nested-testing-package-flattening.md](nested-testing-package-flattening.md)
  — follow-up flattening of the nested `Tests/` layout.
- `HANDOFF-swift-testing-successor-migration.md` — per-consumer migration plan
  and disposition recommendation that references this document.

## Status notes

- Signed off for consumer rollout against current `main` of both source and
  destination repositories as of 2026-04-22.
- Migration execution is a separate workstream; this document is strategy-only.
- Durable beyond the current 7-consumer cohort: future packages adopting
  `TestingPerformance` (there should be none, but audits will reveal any
  hold-outs) will reuse this table verbatim.
