# Benchmark Implementation Conventions

<!--
---
version: 1.2.0
last_updated: 2026-04-16
status: SUPERSEDED
tier: 2
superseded_by: benchmark skill [BENCH-001..009]
---
-->

## Context

The Swift Institute ecosystem has mature benchmarking *infrastructure* — `swift-testing`'s `.timed()` trait provides warmup, iteration control, statistical diagnostics, baseline comparison, and environment fingerprinting (see `benchmarking-strategy.md`, `benchmark-performance-modularization.md`, `benchmark-inline-strategy.md`).

What's missing is a convention for how benchmark *code* should be organized. The `testing` and `testing-institute` skills define comprehensive patterns for test suites (suite hierarchy, naming, file organization), but these were designed for correctness testing, not performance benchmarking.

**Trigger**: [RES-001] The swift-io vs NIO benchmark suite required design decisions about structure, naming, fixture management, and cross-framework comparison that no existing convention addressed.

**Case study**: `swift-io/Benchmarks/` — two isolated packages (`io-bench`, `nio-bench`) with 10 benchmark suites measuring throughput, overhead, contention, lifecycle, backpressure, cancellation, memory allocation, and scheduling latency.

**Scope**: [RES-002a] Ecosystem-wide. Establishes benchmark implementation patterns applicable to any package.

## Question

What implementation conventions should govern benchmark suites in the Swift Institute ecosystem, extending the `testing` and `testing-institute` skills?

Specifically:
1. **Suite hierarchy**: How should benchmark suites be structured?
2. **Categorization**: How should benchmark tests be categorized?
3. **Naming**: What naming conventions should benchmark tests follow?
4. **File organization**: How should benchmark files be organized?
5. **Fixture management**: How should shared benchmark state be managed?
6. **Comparison benchmarks**: How should cross-framework comparison suites be structured?
7. **Package structure**: How should benchmark packages relate to their parent?

## Analysis

### Pattern 1: Suite Hierarchy

**Options considered:**

| Option | Structure | Rationale |
|--------|-----------|-----------|
| A: Flat `@Suite` struct | `@Suite(.serialized) struct ThroughputBenchmarks { @Test func ... }` | Minimal boilerplate |
| B: Full Test hierarchy | `enum Throughput { @Suite struct Test { Unit, EdgeCase, Integration, Performance } }` | Consistent with testing conventions |
| C: Performance-only hierarchy | `enum Throughput { @Suite struct Test { @Suite(.serialized) struct Performance {} } }` | Benchmarks only need Performance |

**Decision: Option B** — Full Test hierarchy, matching [TEST-003]/[TEST-005].

**Rationale**: The four-category split proved valuable in the case study:
- **Performance**: Idempotent microbenchmarks with `.timed()` — the primary benchmark content
- **Integration**: Complex scenario tests with non-idempotent setup (latches, saturation probing) — no `.timed()`
- **Unit**: Infrastructure validation (WorkSimulator timing accuracy) — correctness, not performance
- **EdgeCase**: Reserved (boundary conditions in benchmark infrastructure)

Option A loses this categorization. Option C creates an inconsistent pattern that diverges from the testing conventions. Option B is "mutatis mutandi" — same structure, different content emphasis.

### Pattern 2: `.timed()` Configuration

**Options considered:**

| Option | Configuration | Tradeoff |
|--------|--------------|----------|
| A: Bare `.timed()` | Framework defaults (10 iterations, 0 warmup) | Cold-start variance in first iterations |
| B: Standard explicit | `.timed(iterations: 10, warmup: 3)` everywhere | Predictable, self-documenting |
| C: Tiered by weight | Standard/heavy/scenario with different params | Adapts to workload but less consistent |

**Decision: Option C** — Tiered configuration with two levels. All benchmarks MUST use `.timed()`.

| Tier | Config | Use case |
|------|--------|----------|
| Standard | `.timed(iterations: 10, warmup: 3)` | Most microbenchmarks |
| Heavy | `.timed(iterations: 5, warmup: 1)` | Benchmarks >100ms per iteration |

**Rationale**: Every benchmark MUST use `.timed()` — no exceptions. Benchmarks that require expensive setup (saturated queues, filled pools) MUST use shared fixtures (`static let` with async bridging) so that setup runs once and `.timed()` iterations measure only the hot path. This eliminates the need for a "scenario" tier without `.timed()`. Heavy benchmarks use fewer iterations to keep total runtime reasonable.

**Setup isolation pattern** — For benchmarks requiring pre-configured state (e.g., a saturated lane for rejection latency), use a shared fixture class:

```swift
final class SaturatedLaneFixture: @unchecked Sendable {
    let lane: IO.Blocking.Lane
    static let shared: SaturatedLaneFixture = {
        let fixture = SaturatedLaneFixture()
        let semaphore = DispatchSemaphore(value: 0)
        Task { @Sendable in
            try? await fixture.saturate()
            semaphore.signal()
        }
        semaphore.wait()
        return fixture
    }()
}

@Test(.timed(iterations: 10, warmup: 3))
func `pure rejection latency on saturated queue`() async throws {
    let lane = SaturatedLaneFixture.shared.lane
    // Only measurement code here — setup already done
}
```

This pattern bridges async setup into a synchronous `static let` initializer via `DispatchSemaphore`. The fixture creates long-lived blocker tasks that maintain the saturated state across all `.timed()` iterations.

### Pattern 3: Test Naming

**Options considered:**

| Option | Example | Rationale |
|--------|---------|-----------|
| A: Short camelCase | `func sequential()` | Compact but undescriptive |
| B: Backtick with params | `` func `1000 sequential ops with 10µs work`() `` | Self-documenting, matches TEST-007 |
| C: Backtick behavioral | `` func `sequential throughput exceeds 10K ops/sec`() `` | Intention-driven but couples to environment |

**Decision: Option B** — Backtick descriptive names including workload parameters.

**Rationale**: Benchmark test names appear in output tables. Including workload parameters (`1000 ops`, `10µs work`, `4 threads`) makes the output self-documenting. Names should describe WHAT is measured, not WHAT the result should be (Option C couples names to hardware). For comparison benchmarks, identical names between packages enable direct side-by-side comparison:

```
io-bench:  Throughput.Test.Performance.`1000 sequential ops with 10µs work`  → 22ms
nio-bench: Throughput.Test.Performance.`1000 sequential ops with 10µs work`  → 26ms
```

### Pattern 4: Category Namespace

**Options considered:**

| Option | Namespace | File name |
|--------|-----------|-----------|
| A: `ThroughputBenchmarks` | Compound name | `ThroughputBenchmarks.swift` |
| B: `Throughput` | Clean namespace | `Throughput Benchmarks.swift` |
| C: `IO.Blocking.Lane` extension | Type under test | `IO.Blocking.Lane Tests.swift` |

**Decision: Option B** — Clean namespace enum, file named `{Category} Benchmarks.swift`.

**Rationale**: Option A violates [API-NAME-001] (compound names). Option C doesn't work for comparison benchmarks (NIO doesn't expose the same types). Clean namespace enums (`Throughput`, `Overhead`, `Contention`, `Lifecycle`) parallel the testing pattern of one type per file, with the file suffix `Benchmarks` distinguishing from `Tests`.

### Pattern 5: Fixture Management

**Options considered:**

| Option | Pattern | Tradeoff |
|--------|---------|----------|
| A: Global `let` | `let sharedFixture = ...` | Simple but hard to discover |
| B: Static on Performance | `static let fixture = IOBenchmarkFixture.shared` | Scoped, discoverable |
| C: Test Support library | Fixture in `IO Test Support` product | Cross-package reusable |

**Decision: Both B and C** — Test Support library provides the canonical fixture (Option C per [TEST-010]). Performance suites reference it via `static let` (Option B).

**Rationale**: The IO Test Support library already provides `IOBenchmarkFixture`. Benchmark tests import it and use `static let fixture = IOBenchmarkFixture.shared` on the Performance suite. This follows the existing testing convention where Test Support provides infrastructure and tests consume it.

For per-test resources (lifecycle benchmarks creating fresh pools), create inline — no fixture needed.

### Pattern 6: WorkSimulator (Comparison Benchmarks)

**Options considered:**

| Option | Pattern | Tradeoff |
|--------|---------|----------|
| A: Framework-native work | Each framework uses its own work simulation | Unfair — different work costs |
| B: Shared WorkSimulator | Byte-identical file in both packages | Fair but duplicated |
| C: Shared SPM package | WorkSimulator in a third package | Clean but adds dependency complexity |

**Decision: Option B** — Byte-identical `WorkSimulator.swift` in both comparison packages.

**Rationale**: The `System` module collision that necessitates separate packages also prevents a shared dependency. Byte-identical files ensure identical work simulation. The file is small (~30 lines) and stable — duplication cost is minimal. Unit tests in both packages validate timing accuracy.

### Pattern 7: Package Structure

**Options considered:**

| Option | Structure | Tradeoff |
|--------|-----------|----------|
| A: Single nested package | `Benchmarks/Package.swift` (like `Tests/Package.swift`) | Simple but can't handle module collisions |
| B: Sub-packages | `Benchmarks/io-bench/`, `Benchmarks/nio-bench/` | Handles isolation, more complex |
| C: Separate top-level repo | `swift-io-benchmarks/` at workspace root | Maximum isolation but scattered |

**Decision: Option B for comparison benchmarks, Option A for single-framework benchmarks.**

**Rationale**: The NIO `System` module collision forced separate package graphs. `Benchmarks/` at the package root (not `Tests/`) avoids confusion with the parent's `Tests/` directory. Sub-packages follow the testing-institute flat layout (test sources at package root, explicit `path:` in Package.swift). For packages that don't need comparison against external frameworks, a single `Benchmarks/Package.swift` (Option A) suffices.

The parent `Package.swift` must whitelist `!/Benchmarks/` in `.gitignore` (opt-in pattern).

## Outcome

**Status**: RECOMMENDATION

Seven implementation conventions extracted from the swift-io case study, ready for codification as a `benchmark-implementation` skill:

| # | Convention | Source |
|---|-----------|--------|
| 1 | Full Test hierarchy (`enum {Category} { @Suite struct Test { Unit, EdgeCase, Integration, Performance } }`) | TEST-003/TEST-005 adapted |
| 2 | All benchmarks `.timed()`: standard (10/3), heavy (5/1); shared fixtures for setup isolation | TEST-015 adapted |
| 3 | Backtick names with workload params | TEST-007 adapted |
| 4 | Clean namespace + `{Category} Benchmarks.swift` file naming | API-NAME-001, TEST-009 adapted |
| 5 | Test Support fixture via `static let` on Performance suite | TEST-010, TEST-025 |
| 6 | Byte-identical WorkSimulator for comparison benchmarks | Novel (comparison fairness) |
| 7 | `Benchmarks/` directory with sub-packages for isolation, single package otherwise | INST-TEST-001 adapted |

### Implementation Path

1. Create `benchmark-implementation` skill codifying these 7 conventions
2. Add skill to CLAUDE.md skill routing table under Implementation Skills
3. Validate against swift-io case study (already conforms)
4. Apply to next benchmark suite as second validation

### Relationship to Existing Research

| Document | Relationship |
|----------|-------------|
| `benchmarking-strategy.md` | Infrastructure (how `.timed()` works) → this document is implementation (how to write benchmark code) |
| `benchmark-performance-modularization.md` | Where measurement types live → this document is where benchmark tests live |
| `benchmark-inline-strategy.md` | Parameter ownership → this document is suite-level organization |

## References

- `swift-io/Benchmarks/` — case study implementation
- `testing` skill — [TEST-001] through [TEST-028]
- `testing-institute` skill — [INST-TEST-001] through [INST-TEST-012]
- `benchmarking-strategy.md` — measurement infrastructure
- `benchmark-performance-modularization.md` — type placement
- `benchmark-inline-strategy.md` — parameter ownership
