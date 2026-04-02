# Benchmark Inline Strategy

<!--
---
version: 1.0.1
last_updated: 2026-04-01
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute testing framework (`swift-tests` + `swift-testing`) has a mature `#snapshot` macro with two modes:

| `named:` | Trailing closure | Behavior |
|----------|-----------------|----------|
| absent   | absent          | **Inline record**: capture value, rewrite source with trailing closure |
| absent   | present         | **Inline compare**: compare against inline expected value |
| present  | absent          | **File-backed**: compare against named file in `__Snapshots__/` |
| present  | present         | **Compile error** |

The `#snapshot` inline pattern works because snapshot values are **deterministic** — same input always produces same output. The inline text IS the test assertion.

Separately, `benchmarking-strategy.md` (v2.0, RECOMMENDATION) proposes bridging `.timed()` with `Test.Benchmark.measure {}` via dependency injection. That document defers two design questions to this research:

1. **Parameter ownership**: What configuration belongs on `.timed()` (declaration site) vs `measure {}`/`#benchmark` (call site)?
2. **Inline results**: Should benchmarks have an inline mode paralleling `#snapshot`, and if so, what does the inline value represent?

### Constraint: Benchmarks Are Not Deterministic

The fundamental tension: snapshot values are deterministic and environment-independent. Benchmark values are **noisy** (vary between runs) and **environment-dependent** (M1 vs M4, debug vs release). This constraint shapes every option.

The existing baseline infrastructure handles this with:
- Environment fingerprinting (`arm64-10c-debug-nnbd-sms.json`)
- Tolerance-based comparison (`baselineTolerance: 0.10` = 10%)
- Statistical analysis (CV, MAD, outlier detection, Mann-Kendall trends)

### Stakeholders

- **Test authors**: Write `@Test(.timed(...))` functions with setup isolation
- **AI feedback loop**: Reads test results to iterate on code quality
- **Code reviewers**: Review performance changes in pull requests

## Question

Two linked questions:

**Q1**: How should configuration be split between `.timed()` (declaration-site trait) and the measurement call site (`Test.Benchmark.measure {}` or `#benchmark`)?

**Q2**: Should benchmarks have a `#benchmark` macro with inline source rewriting paralleling `#snapshot`? If so, what does the inline value represent — a test assertion, a baseline, or documentation?

## Analysis

### Q1: Parameter Ownership

#### Current State (Overlap)

| Parameter | On `.timed()` | On `measure {}` | Nature |
|-----------|:---:|:---:|--------|
| `iterations` | ✅ | ✅ | Measurement mechanic |
| `warmup` | ✅ | ✅ | Measurement mechanic |
| `threshold` | ✅ | ✅ | Evaluation policy |
| `metric` | ✅ | ✅ | Evaluation policy |
| `baselineTolerance` | ✅ | ❌ | Evaluation policy |
| `trackAllocations` | ✅ | ❌ | Evaluation policy |
| `printResults` | ✅ | ❌ | Output policy |
| `name` | ❌ | ✅ | Identity |
| `body` | ❌ | ✅ | Measurement target |

Six parameters appear on both sites. This creates ambiguity when both are present.

#### Proposed Split

**Principle**: The call site knows **what** to measure and **how often**. The trait knows **what to do** with the results.

**Call site** (`measure {}` or `#benchmark`) — measurement mechanics:
- `iterations: Int` — how many timed runs
- `warmup: Int` — how many untimed warmup runs
- `body` — the code to measure

**Declaration site** (`.timed()`) — evaluation policy:
- `threshold: Duration?` — pass/fail budget
- `metric: Metric` — which statistic to evaluate (median, p95, etc.)
- `baselineTolerance: Double?` — regression detection tolerance
- `trackAllocations: Bool` — whether to capture memory statistics
- `printResults: Bool` — whether to print diagnostics

**Removed from call site**: `threshold`, `metric`, `name`. When running under `.timed()`, the trait provides these. When running standalone (no `.timed()`), the standalone `measure {}` retains `name`/`threshold`/`metric` for backward compatibility — but these are convenience parameters for the standalone path, not the primary API.

**Retained on `.timed()`**: `iterations`/`warmup` as defaults for whole-body timing (no `measure {}`). When `measure {}` is present, it overrides `.timed()`'s iterations — `measure {}` already ran the iterations, the scope provider just reads the result.

| Scenario | Who iterates | Config source |
|----------|-------------|---------------|
| `.timed()` only (no `measure {}`) | Scope provider | `.timed(iterations:warmup:)` |
| `.timed()` + `measure {}` | `measure {}` | `measure(iterations:warmup:)` |
| `measure {}` only (no `.timed()`) | `measure {}` | `measure(iterations:warmup:)` |

This is clean: `.timed()` delegates iteration to `measure {}` when present, and only uses its own `iterations`/`warmup` as a fallback.

### Q2: Inline Results

#### Option A: Static Method Only — No Macro, No Inline

Keep `Test.Benchmark.measure {}` as a static method. No source rewriting. Results flow through `.timed()`'s diagnostic pipeline (console, JSON, `.benchmarks/` files).

```swift
@Test(.timed(threshold: .milliseconds(50), baselineTolerance: 0.10))
func insertion() {
    let data = setup()
    Test.Benchmark.measure(iterations: 100) {
        sut.insert(contentsOf: data)
    }
}
```

**Advantages**:
- Simplest implementation — no macro needed
- No source modification
- All results flow through existing diagnostic pipeline
- AI reads results from `.benchmarks/` files or JSON output

**Disadvantages**:
- No inline visibility in the test body
- AI must look outside the test file for results
- Code reviewers don't see performance numbers in the diff
- Asymmetric with `#snapshot` — snapshots have inline, benchmarks don't

#### Option B: `#benchmark` Macro — Inline Documentary (No Assertion)

`#benchmark` replaces `Test.Benchmark.measure {}`. Source rewriting inserts a formatted summary as a trailing closure, but the inline text is **documentary only** — it does not participate in pass/fail. The `.timed()` trait's baseline infrastructure handles comparison.

```swift
// First run (no trailing closure) — records and rewrites source:
@Test(.timed(baselineTolerance: 0.10))
func insertion() {
    let data = setup()
    #benchmark(iterations: 100) {
        sut.insert(contentsOf: data)
    }
}

// After recording, source becomes:
@Test(.timed(baselineTolerance: 0.10))
func insertion() {
    let data = setup()
    #benchmark(iterations: 100) {
        sut.insert(contentsOf: data)
    } results: {
        """
        median: 42.3ms | p95: 48.1ms | cv: 3.2%
        """
    }
}
```

The trailing `results:` closure is human/AI-readable documentation. The rewriter updates it when recording mode is active. The actual pass/fail assertion comes from `.timed()`'s threshold and baseline comparison (file-backed, fingerprinted).

**Advantages**:
- Inline visibility in test body
- AI reads test file, sees performance numbers directly
- Code reviewers see performance changes in diff
- Symmetric with `#snapshot` in ergonomics
- No assertion on noisy values — pass/fail stays in `.timed()` where it belongs
- Recording mode controls when source is modified (same as `#snapshot`)

**Disadvantages**:
- Macro + rewriter implementation cost
- Source modification on record (git noise)
- Inline values are stale on different environments (M1 numbers shown when running on M4)
- The inline text doesn't DO anything — it's just a comment with extra infrastructure

#### Option C: `#benchmark` Macro — Inline As Baseline

The inline value IS the baseline, with tolerance-based comparison. No separate `.benchmarks/` file needed for this test.

```swift
// After recording:
@Test(.timed(baselineTolerance: 0.10))
func insertion() {
    let data = setup()
    #benchmark(iterations: 100) {
        sut.insert(contentsOf: data)
    } baseline: {
        """
        {"median_ns":42300000,"p95_ns":48100000,"env":"arm64-10c-debug"}
        """
    }
}
```

Comparison: parse the inline JSON, check if current median is within `baselineTolerance` of the recorded median, but ONLY if the current environment matches the recorded environment.

**Advantages**:
- Self-contained — baseline lives in the test file
- No separate `.benchmarks/` directory for inline benchmarks
- Everything visible in code review
- Symmetric with `#snapshot` (inline value IS the expected value)

**Disadvantages**:
- Environment coupling — inline baseline only valid for one environment
- Environment mismatch handling: skip comparison? warn? always re-record?
- JSON in source code is ugly and fragile
- Parsing inline JSON back to durations adds complexity
- The inline `#snapshot` comparison is exact; inline `#benchmark` is tolerance-based — fundamentally different assertion semantics under the same pattern
- Multiple environments would require multiple inline baselines (absurd)

#### Option D: Full `#snapshot` Parallel — Inline + Named

Mirror `#snapshot` exactly: `#benchmark` without `named:` does inline (documentary or baseline); with `named:` does file-backed.

```swift
// Inline (documentary results in source)
#benchmark(iterations: 100) {
    sut.insert(contentsOf: data)
} results: {
    """
    median: 42.3ms | p95: 48.1ms
    """
}

// File-backed (baseline comparison via .benchmarks/)
#benchmark(iterations: 100, named: "insertion") {
    sut.insert(contentsOf: data)
}
```

**Advantages**:
- Perfect symmetry with `#snapshot`
- User chooses inline (visibility) vs named (comparison)
- Named variant uses existing fingerprinted baseline infrastructure

**Disadvantages**:
- Two modes on one macro — what does each mode DO for the user?
- For `#snapshot`: inline = assertion, named = assertion (both compare). Clear.
- For `#benchmark`: inline = documentation(?), named = comparison(?). Asymmetric semantics behind symmetric syntax.
- Implementation doubles: inline rewriter + file-backed baseline, both through the macro

#### Option E: `#benchmark` Macro — Unified

`#benchmark` always rewrites source with results. Comparison always uses `.timed()`'s infrastructure (file-backed baselines). No `named:` parameter — the macro is always inline.

```swift
@Test(.timed(baselineTolerance: 0.10))
func insertion() {
    let data = setup()
    #benchmark(iterations: 100) {
        sut.insert(contentsOf: data)
    } results: {
        """
        median: 42.3ms | p95: 48.1ms | cv: 3.2%
        2026-03-10 arm64-10c-debug
        """
    }
}
```

The macro does ONE thing: measure and show results inline. The trait does ONE thing: evaluate and compare. No named/inline dichotomy.

**Advantages**:
- One concept, one behavior — `#benchmark` always shows inline results
- Clear separation: macro = measurement + visibility, trait = evaluation + comparison
- Same recording mode as `#snapshot` for controlling when source is rewritten
- Simpler than Option D

**Disadvantages**:
- No "file-backed only" mode (but `.timed()` already handles file-backed baselines)
- Inline results always present once recorded (source modification)

## Comparison

### Q1: Parameter Ownership (no options — clear principle)

The split is unambiguous: measurement mechanics → call site, evaluation policy → declaration site. This is not a design choice but a separation of concerns.

### Q2: Inline Results

| Criterion | A: Static | B: Inline Doc | C: Inline Baseline | D: Full Parallel | E: Unified |
|-----------|-----------|--------------|-------------------|-----------------|------------|
| Implementation cost | None | Medium | High | Very high | Medium |
| Inline visibility | ❌ | ✅ | ✅ | ✅ | ✅ |
| AI readability | ⚠️ via files | ✅ in source | ✅ in source | ✅ in source | ✅ in source |
| Code review value | ❌ | ✅ | ✅ | ✅ | ✅ |
| `#snapshot` symmetry | ❌ | Ergonomic | Semantic | Full | Ergonomic |
| Environment handling | N/A (file-backed) | Stale but harmless | Problematic | Mixed | Stale but harmless |
| Assertion clarity | Clear (`.timed()`) | Clear (`.timed()`) | Confusing (tolerance in source) | Confusing (two modes) | Clear (`.timed()`) |
| Concept count | 1 (method) | 2 (macro + trait) | 2 (macro + trait) | 3 (macro inline + macro named + trait) | 2 (macro + trait) |

### Key Insight: Snapshots and Benchmarks Have Different Assertion Semantics

`#snapshot` inline works because the inline value IS the assertion — exact match. The value is deterministic and environment-independent.

`#benchmark` inline CANNOT work the same way because:
1. Values are noisy (42ms vs 43ms is the same performance)
2. Values are environment-dependent (42ms on M1 vs 28ms on M4)
3. Comparison requires tolerance, not exact match

Therefore, trying to make `#benchmark` inline serve as a baseline (Option C) forces tolerance-based comparison into a pattern designed for exact comparison. It's a false parallel.

The honest acknowledgment: `#benchmark` inline values are DOCUMENTARY. They show what was measured for human eyes and AI consumption. The actual assertion comes from `.timed()`'s baseline comparison infrastructure, which is file-backed and fingerprinted.

This means Options B and E are the principled choices — they acknowledge the documentary nature of inline benchmark results rather than forcing them into an assertion role they can't fill.

## Prior Art

### XCTest `measure {}`
No inline results. Results shown in Xcode's gutter annotations and performance result files. Baselines stored in `.xcbaselines/`.

### Criterion.rs
No inline results. HTML reports generated separately. Baselines stored in `target/criterion/`.

### Jest Snapshots
Inline snapshots via `toMatchInlineSnapshot()`. Source rewriting. Only for deterministic values — no equivalent for performance.

### Point-Free swift-snapshot-testing
The original inline snapshot pattern. `assertInlineSnapshot` with trailing closure. Deterministic values only — no performance equivalent.

**No prior art exists for inline benchmark results.** This is novel territory. The absence is itself evidence that the determinism gap is a real barrier.

## Outcome

**Status**: RECOMMENDATION

### Q1: Parameter Ownership — DECIDED

| Site | Parameters | Principle |
|------|-----------|-----------|
| Call site (`#benchmark`/`measure {}`) | `iterations`, `warmup`, `body` | Measurement mechanics |
| Declaration site (`.timed()`) | `threshold`, `metric`, `baselineTolerance`, `trackAllocations`, `printResults` | Evaluation policy |
| `.timed()` fallback | `iterations`, `warmup` (only when no `measure {}`) | Default mechanics |

### Q2: Inline Results — RECOMMENDATION

**Recommend Option E: Unified `#benchmark` macro with inline documentary results.**

Rationale:

1. **Documentary, not assertion.** The inline text shows "what this measured" for humans and AI. It does not participate in pass/fail. This honestly reflects the non-deterministic nature of benchmarks.

2. **One macro, one behavior.** `#benchmark` always measures and shows results inline. No `named:`/inline dichotomy. Simpler mental model than Option D.

3. **Clean separation from `.timed()`.** The macro handles measurement + visibility. The trait handles evaluation + comparison. No overlap.

4. **AI feedback loop.** The AI reads the test file and sees performance numbers inline — no need to parse separate files. The inline text includes the environment tag so the AI knows which machine produced the numbers.

5. **Recording mode alignment.** Same `record:` parameter as `#snapshot`. Source is only rewritten when recording is active. Default: `.missing` (record on first run, then freeze).

6. **Code review value.** PR diffs show performance changes inline:
   ```diff
    } results: {
   -    """
   -    median: 45.1ms | p95: 52.3ms | cv: 4.1%
   -    """
   +    """
   +    median: 42.3ms | p95: 48.1ms | cv: 3.2%
   +    """
    }
   ```

7. **Staleness is acceptable.** The inline results may be from a different environment or a previous run. This is fine — they're documentation, not assertions. The `.timed()` trait's file-backed baselines (fingerprinted, tolerance-based) handle the actual regression detection.

### Phasing

**Phase 1** (from `benchmarking-strategy.md`): Bridge `.timed()` with `Test.Benchmark.measure {}` via DI. Static method, no macro. This delivers the core value (setup isolation + full diagnostics) without macro work.

**Phase 2**: Introduce `#benchmark` macro. Replace `Test.Benchmark.measure {}` call sites with `#benchmark`. Add inline rewriter for documentary results. Recording mode controls source rewriting.

**Phase 3** (from `benchmarking-strategy.md`): Run history (JSONL) and run-level summary (AI export JSON).

### User Experience (Phase 2)

```swift
// Budget: whole body timed, no macro needed
@Test(.timed(threshold: .milliseconds(50)))
func `fast path within budget`() {
    sut.fastPath()
}

// Benchmark with setup isolation + inline results
@Test(.timed(
    threshold: .milliseconds(100),
    metric: .p95,
    baselineTolerance: 0.10
))
func `insertion throughput`() {
    let data = generateTestData(count: 10_000)
    #benchmark(iterations: 100, warmup: 5) {
        sut.insert(contentsOf: data)
    } results: {
        """
        median: 42.3ms | p95: 48.1ms | cv: 3.2%
        2026-03-10 arm64-10c-debug
        """
    }
}
```

### Implementation Notes

1. **`BenchmarkMacro`**: New `ExpressionMacro` in `Testing Macros Implementation`. Expands to `Testing.__benchmarkInline(...)` bridge function, passing `#filePath`, `#line`, `#column` for rewriter.

2. **Rewriter reuse**: The inline benchmark rewriter can share infrastructure with `Test.Snapshot.Inline.Rewriter` — same `atexit` deferred-write pattern, same SwiftSyntax machinery. Consider extracting a shared `Test.Inline.Rewriter` base.

3. **Result format**: The inline string is human-readable, not JSON. Format: `"metric: value | metric: value | ...\ndate environment"`. Standardized format enables the AI to parse if needed, but the primary purpose is human readability.

4. **`#benchmark` without `.timed()`**: Works standalone (like `Test.Benchmark.measure {}` today). Measures, prints, rewrites source. No baseline comparison, no threshold enforcement.

5. **`#benchmark` with `.timed()`**: The scope provider injects the DI witness. `#benchmark` delegates iteration to the witness. After the test body returns, the scope provider reads the measurement and runs the full diagnostic pipeline. The rewriter also records the inline text.

## References

- `swift-institute/Research/benchmarking-strategy.md` — parent research (RECOMMENDATION)
- `swift-institute/Experiments/dependency-scope-writeback/` — DI writeback validation
- `swift-testing/Sources/Testing Macros Implementation/SnapshotMacro.swift` — `#snapshot` macro
- `swift-testing/Sources/Testing Umbrella/Snapshot.swift` — `#snapshot` declaration + bridge
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.Rewriter.swift` — source rewriter
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift` — inline assertion
- `swift-tests/Sources/Tests Snapshot/Test.Trait.ScopeProvider.snapshot.swift` — snapshot scope provider
- `swift-tests/Sources/Tests Performance/Test.Trait.ScopeProvider.timed.swift` — timed scope provider
- `swift-tests/Sources/Tests Performance/Test.Benchmark+measure.swift` — existing measure API
- `swift-test-primitives/Sources/Test Primitives Core/Test.Benchmark.Configuration.swift` — config
