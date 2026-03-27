# Benchmark Result Storage

<!--
---
version: 1.0.0
last_updated: 2026-03-27
status: DECISION
---
-->

## Context

The Swift Institute ecosystem uses `.timed()` from swift-testing for performance benchmarks. Results are stored in `.benchmarks/` directories as JSONL files keyed by test name and environment fingerprint. The question is whether these files should be committed to version control or gitignored.

## Question

Should benchmark result data (`.benchmarks/` JSONL files) be committed to git?

## Prior Art Survey

### Taxonomy

| Approach | What is committed | Examples |
|----------|------------------|----------|
| **Nothing** | Only benchmark source code | swift-protobuf, Vapor, benchmark.js, Go benchstat |
| **Thresholds only** | Deterministic bounds (allocation counts) | swift-nio, swift-certificates, ordo-one consumers |
| **Curated documentation** | One-time announcement data | swift-collections announcement benchmarks |
| **gh-pages branch** | Historical time-series (separate branch) | github-action-benchmark users |
| **External service** | Nothing in repo | Bencher.dev, CodSpeed |

### Swift Ecosystem

**ordo-one/package-benchmark** (community standard): Distinguishes *baselines* from *thresholds*. `.benchmarkBaselines/` is explicitly gitignored — format is internal, machine-specific. `Thresholds/` is committed — static performance bounds for CI enforcement. This is the canonical Swift pattern, adopted by apple/swift-nio and apple/swift-certificates.

**apple/swift-nio**: Commits allocation count thresholds (`Thresholds/{swift-version}.json`) but gitignores timing baselines (`.benchmarkBaselines/`). Allocation counts are deterministic (machine-independent); timing data is not.

**apple/swift-collections**: Commits curated benchmark results only for documentation purposes (`Documentation/Announcement-benchmarks/results.json`). No ongoing benchmark data committed.

### Rust (criterion.rs)

`.criterion/` (baseline storage) is gitignored. All benchmark output goes to `target/` which is universally gitignored. Baselines are machine-specific, used only for local A/B comparison.

### Go (benchstat)

Results are ephemeral text (`go test -bench > old.txt`). `benchstat` compares transient files. CI uses `actions/cache`, not commits.

### Universal Rule

**Machine-dependent timing data is never committed to the main branch.** Every surveyed project either gitignores it or does not persist it. The one exception is deterministic metrics (allocation counts, syscall limits) which some projects commit as thresholds.

## Analysis

### Option A: Commit `.benchmarks/` (JSONL timing data)

**Advantages**: Historical tracking, trend detection across commits, AI-consumable baselines.

**Disadvantages**: Machine-specific data pollutes VCS. Results from M1 vs M2 vs CI are incomparable. Every benchmark run changes files, creating noise in diffs. Goes against universal ecosystem consensus.

### Option B: Gitignore `.benchmarks/` (align with ecosystem)

**Advantages**: Matches ordo-one, swift-nio, criterion.rs, Go, JS consensus. Clean diffs. No machine-specific data in repo.

**Disadvantages**: Loses historical data between sessions. No baseline comparison without external tooling.

### Option C: Commit thresholds, gitignore baselines (ordo-one pattern)

**Advantages**: Deterministic thresholds enable CI regression detection. Timing baselines stay local. Best of both worlds — matches the community standard.

**Disadvantages**: Requires separating threshold definition from measurement. Our `.timed()` system stores timing data, not allocation counts.

## Outcome

**Status**: DECISION

**Gitignore `.benchmarks/`**. The ecosystem consensus is unambiguous: timing-based benchmark data is machine-specific and should not be committed. Our `.benchmarks/` JSONL files contain wall-clock measurements that vary by machine, load, and configuration.

The `.timed()` threshold system (`.timed(threshold: .milliseconds(50))`) already provides the committed-to-source regression detection that the ordo-one threshold pattern offers — thresholds live in the test source code, not in result files.

**Action**: Add `.benchmarks/` to the canonical gitignore in `sync-gitignore.sh`.

## References

- ordo-one/package-benchmark: baselines gitignored, thresholds committed
- apple/swift-nio: allocation thresholds committed, timing baselines gitignored
- apple/swift-certificates: same ordo-one pattern
- criterion.rs: `.criterion/` gitignored, all output under `target/`
- Go benchstat: ephemeral text files, CI uses cache not commits
- github-action-benchmark: stores results on gh-pages branch, not source branch
- Bencher.dev: fully external storage, zero in-repo results
