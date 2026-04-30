# Test Console Output: From Functional to Elegant

<!--
---
tier: 2
version: 1.1.0
status: RECOMMENDATION
created: 2026-03-27
last_updated: 2026-04-30
packages: [swift-tests, swift-testing, swift-console, swift-test-primitives]
skills: [testing, testing-institute, design]
related: [test-output-quality-parity.md, benchmark-implementation-conventions.md]
---
-->

## Context

The Swift Institute ecosystem has a complete testing infrastructure: `swift-testing` (fork with custom reporters, `#Tests` macro, `.timed()` trait, `#snapshot`), `swift-tests` (performance diagnostics, snapshot engine), `swift-console` (ANSI-capable terminal styling), and `Test_Primitives` (event types, styled `Test.Text`). The prior research document `test-output-quality-parity.md` (2026-03-03, status: DECISION) focused narrowly on **failure output** — making assertion failures informative by rendering source locations, expected/actual values, and structured diffs. That work identified that the data was already captured but discarded by the reporter.

This research addresses a broader concern: **the overall visual experience** of running tests and benchmarks. When a developer runs `swift test` in an ecosystem package, the console output should be clear, well-structured, and aesthetically satisfying — not merely functional. The benchmark examples at `swift-io/Benchmarks/io-bench` and `swift-io/Benchmarks/nio-bench` demonstrate the issue: rich performance data is collected via `.timed()`, but the output lacks visual polish. The comparison script (`run-benchmarks.sh`) wraps `swift test` with `echo "========"` headers.

The trigger: Apple's upstream `swift-testing` has invested in an `AdvancedConsoleOutputRecorder` (experimental, behind `SWT_ENABLE_EXPERIMENTAL_CONSOLE_OUTPUT`) that renders hierarchical tree views with box-drawing characters, right-aligned durations, and deferred summary output. Our fork has none of this. The question is not "how to match Apple" but "what is the ideal end-state for test output in this ecosystem?"

## Question

What should the complete test console output experience look like — from `swift test` invocation through final summary — across unit tests, performance benchmarks, and snapshot tests? How does the current state compare to Apple's approach, and what would the theoretical ideal look like?

---

## Current State Analysis

### 1. Terminal Reporter (`Test.Reporter.Terminal`)

**File**: `swift-tests/Sources/Tests Reporter/Test.Reporter.Terminal.swift` (217 lines)

The current reporter is event-streaming: each event is printed as it occurs.

**Output format**:
```
Test run started
  ▶ ModuleName.SuiteName.TestName
  ✓ TestName (1.234 ms)
  ✓ AnotherTest (0.456 ms)
  ✗ FailingTest (2.001 ms)
    ✗ lhs == rhs
      at TestFile.swift:42:5
      expected: 42
      actual:   41

Test run complete:
  Passed:  47
  Failed:  1
  Skipped: 3
```

**Strengths**:
- Colors via `Console.Capability.detect()` — respects `NO_COLOR`, `FORCE_COLOR`, `COLORTERM`, CI environments
- Semantic style mapping: 13 `Test.Text.Segment.Style` variants → `Console.Style` (cyan for identifiers, yellow for values, magenta for keywords, etc.)
- Structured diff rendering with expected/actual and `Test.Text` segments
- Immediate output: failures visible as they happen

**Weaknesses**:
- **Flat structure**: No hierarchy. Suites are not visually grouped. A test run with nested suites (`Type.Test.Unit`, `Type.Test.EdgeCase`, `Type.Test.Performance`) renders as a flat list of test names
- **No tree rendering**: No box-drawing characters, no visual parent-child relationships
- **No suite-level aggregation**: No "Suite X: 12/12 passed" summaries. Cannot tell at a glance which suite had the failure
- **No progress indication**: No test count progress ("Running test 14/47..."), no elapsed wall-clock, no ETA
- **No terminal width awareness**: Long test names wrap awkwardly, durations are not right-aligned
- **Plain summary**: Just counts. No duration total, no slowest-test highlight, no comparison to previous run
- **Emoji in performance reporting**: `Tests.report()` uses `⏱️` — inconsistent with the Unicode symbol vocabulary (✓, ✗, ○, ⚠, ▶)

### 2. Performance Output (`Tests.Diagnostic+Format`)

**File**: `swift-tests/Sources/Tests Performance/Tests.Diagnostic+Format.swift` (274 lines)

Two output modes:

**Human-readable (`formatted()`)** — verbose diagnostic block:
```
PERFORMANCE MEASUREMENT
  Test:     Module.Suite.test
  Metric:   median
  Value:    15.234 ms

  Distribution:
    Median: 15.234 ms  Mean: 16.102 ms  StdDev: 1.234 ms
    CV:     8.12% (MODERATE - consider more iterations)
    Min:    14.001 ms  Max: 22.456 ms
    p95:    19.876 ms  p99: 22.100 ms
    MAD:    0.876 ms   Outliers: 1 of 10

  Trend:
    Mann-Kendall Z: 0.45 (NO TREND - not thermal throttle)

  Environment:
    Architecture:  arm64
    CPU Cores:     10 (physical) / 10 (logical)
    Memory:        36 GB
    Swift:         6.2
    Optimization:  release
    Feature Flags: NonisolatedNonsendingByDefault=true
    OS:            macOS 26.0
```

**Summary table (`summary()`)** — compact comparison:
```
PERFORMANCE SUMMARY

| Test               |     Median |        Min |
|--------------------|------------|------------|
| Throughput.seq     |  20.750 ms |  19.234 ms |
| Throughput.conc    |  15.123 ms |  14.001 ms |
| Overhead.100       |   1.590 ms |   1.456 ms |
```

**Strengths**:
- Comprehensive statistical data (distribution, trend, baseline, history, environment)
- JSON block output for AI agent consumption
- Markdown-style table with aligned columns
- Common prefix stripping for compact display names

**Weaknesses**:
- **Wall of text**: The full diagnostic dumps ~25 lines per test. For a benchmark suite with 20 tests, that's 500 lines of output before you can scan results
- **No visual density**: The summary table is good but minimal — no sparklines, no bar charts, no change indicators
- **No side-by-side comparison**: `run-benchmarks.sh` runs io-bench and nio-bench sequentially. No merged comparison table. You must scroll between two separate outputs
- **Mixed formatting vocabulary**: Box-drawing (`╔══╗`) in `Tests.report(comparisons:)`, markdown table in `summary()`, plain key-value in `formatted()`. Three different visual languages

### 3. Benchmark Script (`run-benchmarks.sh`)

**File**: `swift-io/Benchmarks/run-benchmarks.sh` (58 lines)

```bash
echo "========================================"
echo " swift-io vs NIO Benchmark Suite"
echo "========================================"
```

**Weaknesses**:
- `echo` headers, no colors, no terminal capability detection
- No merged output — runs two `swift test` commands sequentially
- No post-processing of results into a comparison view
- Build output suppressed to `tail -1` — loses error context on failure

---

## Apple's Approach

### Standard `ConsoleOutputRecorder`

**File**: `swiftlang/swift-testing/.../Event.ConsoleOutputRecorder.swift` (381 lines)

Event-streaming with per-message formatting:

```
◇ Test "My Test" started.
✔ Test "My Test" passed after 0.153 seconds.
✘ Test "Failing Test" recorded an issue at File.swift:42:5
  ± Expected "abc", found "xyz"
  ↳ Values are not equal
```

**Symbol vocabulary**: ◇ (default), ✔ (pass), ✘ (fail), ➜ (skip), ⚠ (warning), ± (difference), ↳ (details), ⎙ (attachment). Each with a dedicated ANSI color.

**Key features**:
- SF Symbols support on macOS (Private Use Area Unicode → SF Pro font glyphs)
- Tag colors: colored bullets (●) from a predefined palette (red, orange, yellow, green, blue, purple)
- 4 color bit depths: 1-bit (none), 4-bit (16), 8-bit (256), 24-bit (true color)
- Verbosity levels: negative (issues only), 0 (normal), positive (expression details, version info)

### `AdvancedConsoleOutputRecorder` (Experimental)

**File**: `swiftlang/swift-testing/.../Event.AdvancedConsoleOutputRecorder.swift` (~900 lines)

Deferred hierarchical output. Silent during the run, renders a complete tree at `runEnded`:

```
══════════════════════════════════════ HIERARCHICAL TEST RESULTS ══════════════════════════════════════

TestingTests
   ├─ ClockAPITests
   │  ├─ ✔ testCurrentInstant                                                              (0.05s)
   │  ├─ ✔ testSleep                                                                       (1.23s)
   │  ╰─ ✔ testAdvanced                                                                    (0.08s)
   │
   ╰─ AnotherSuite
      ├─ ✔ testCase1                                                                       (0.02s)
      ╰─ ✘ testCase2                                                                       (0.15s)
         ╰─ Expectation failed: Expected 42, found 41
            at TestFile.swift:15

12 tests completed in 3.45s (✔ pass: 11, ✘ fail: 1)

══════════════════════════════════════ FAILED TEST DETAILS (1) ══════════════════════════════════════

✘ TestingTests.AnotherSuite/testCase2()
  Expected 42, found 41

  Location: TestFile.swift:15:5

                                                                                              [1/1]
```

**Key design decisions**:
1. **Deferred rendering**: Collects all events into a `Graph<String, _HierarchyNode?>`, renders at the end. Trades real-time feedback for structural clarity
2. **Box-drawing characters**: 3-tier fallback (Unicode `├─╰─│` → Windows CP437 `├─└─│` → ASCII `|-``-|`)
3. **Right-aligned durations**: Terminal-width-aware padding with ANSI-escape-aware character counting
4. **Two-section layout**: Hierarchy tree (overview) + Failed test details (deep dive)
5. **Concise inline issues**: In the tree, shows one-line issue summary; full details in the bottom section

**Strengths**:
- **Scannable**: The tree structure lets you immediately see which suites passed/failed
- **Progressive disclosure**: Overview tree → detailed failures
- **Terminal-aware**: Reads COLUMNS, falls back to 120

**Weaknesses**:
- **No real-time feedback**: Completely silent during the run. For a 5-minute test suite, the developer sees nothing until it's done
- **No performance awareness**: No special handling for `.timed()` results, baselines, or trends
- **Experimental**: Behind an environment variable, not production
- **No snapshot output**: No special rendering for snapshot diff results

---

## Prior Art Beyond Apple

### Rust `cargo test`

```
running 47 tests
test buffer::ring::test_push ... ok
test buffer::ring::test_pop ... ok
test buffer::linear::test_alloc ... FAILED
...
test result: FAILED. 46 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 2.34s

---- buffer::linear::test_alloc stdout ----
thread 'buffer::linear::test_alloc' panicked at 'assertion failed'
```

Pattern: progress line → results → failure details at bottom.

### Jest (JavaScript)

```
 PASS  src/components/Button.test.tsx (1.234 s)
 FAIL  src/utils/format.test.tsx (0.567 s)
  ● format › should handle null

    expect(received).toBe(expected)

    Expected: "N/A"
    Received: null

      12 |   it('should handle null', () => {
    > 13 |     expect(format(null)).toBe('N/A')
         |                          ^
      14 |   })

Test Suites: 1 failed, 3 passed, 4 total
Tests:       1 failed, 47 passed, 48 total
Snapshots:   12 passed, 12 total
Time:        3.456 s
```

Pattern: per-file pass/fail with timing → inline failure with source context → summary with totals. Jest is widely considered the gold standard for test output aesthetics.

### `criterion.rs` (Rust Benchmarks)

```
Benchmarking buffer/push_1000
                        time:   [14.234 µs 15.012 µs 15.891 µs]
                        change: [-2.1234% +0.5678% +3.2109%] (p = 0.42 > 0.05)
                        No change in performance detected.
Found 1 outlier among 100 measurements (1.00%)
  1 (1.00%) high mild
```

Pattern: test name → confidence interval → change from baseline → outlier detection. Dense, information-rich, statistically rigorous.

### `hyperfine` (Command-Line Benchmarks)

```
Benchmark 1: io-bench
  Time (mean ± σ):     15.234 ms ±  1.123 ms    [User: 12.345 ms, System: 2.889 ms]
  Range (min … max):   14.001 ms … 22.456 ms    100 runs

Benchmark 2: nio-bench
  Time (mean ± σ):      7.891 ms ±  0.456 ms    [User: 6.123 ms, System: 1.768 ms]
  Range (min … max):    7.234 ms … 9.012 ms     100 runs

Summary
  nio-bench ran
    1.93 ± 0.17 times faster than io-bench
```

Pattern: per-benchmark stats → relative comparison summary. Clean, focused, memorable final line.

---

## Theoretical Ideal End-State

### Design Principles

1. **Progressive disclosure**: Show the minimum needed at each stage; details available on demand
2. **Structural clarity**: Hierarchy is visible. You can tell which suite a test belongs to at a glance
3. **Temporal feedback**: The developer knows something is happening during long runs
4. **Statistical rigor**: Performance results show confidence, not just point estimates
5. **Comparison as a first-class concept**: Benchmark suites exist to compare. The output format should make comparison effortless
6. **Consistent visual language**: One symbol vocabulary, one color palette, one formatting convention across all test types
7. **Terminal-native**: Use the terminal's capabilities (color, width, cursor control) but degrade gracefully
8. **Machine-readable parallel channel**: Human output and structured data should coexist (the `.tee` reporter already does this)

### Phase 1: Real-Time Progress with Suite Grouping

During the run, show suite-level progress with immediate failure surfacing:

```
Buffer.Ring.Test
  Unit ·········· 12/12 ✓                                                          (0.234s)
  EdgeCase ······  8/8  ✓                                                          (0.156s)
  Integration ···  3/3  ✓                                                          (0.892s)
  Performance ··· ■■■□□  3/5                                                           ...

Buffer.Linear.Test
  Unit ·········· 11/12 ✗                                                          (0.345s)
    ✗ allocate creates buffer with specified size
      at Buffer.Linear Tests.swift:42:5
      expected: 1024
      actual:   0
  EdgeCase ······  0/6                                                                 ...
```

**Key choices**:
- **Suite-grouped**: Tests within a suite are collapsed to a progress line; only failures expand inline
- **Progress indicator**: Dots fill as tests complete; `■` blocks for in-progress (performance tests run serially, so show individual progress)
- **Duration right-aligned**: Terminal-width-aware, consistent column
- **Immediate failure**: Failed tests expand inline under their suite, so the developer can see the failure while subsequent suites continue running
- **No "Test run started" preamble**: Waste of a line. Start with content

### Phase 2: Hierarchical Summary at End

After all tests complete, render a tree summary (similar to Apple's approach but with our ecosystem's additions):

```

  Buffer.Ring.Test                                                           (1.282s)
  ├─ Unit ················ 12/12 ✓                                           (0.234s)
  ├─ EdgeCase ············  8/8  ✓                                           (0.156s)
  ├─ Integration ·········  3/3  ✓                                           (0.892s)
  ╰─ Performance
     ├─ ✓ 1000 sequential ops ·················· 20.750 ms                   (0.450s)
     ├─ ✓ 1000 concurrent ops ·················· 15.123 ms                   (0.380s)
     ╰─ ✓ 100 sequential dispatches ············  1.590 ms                   (0.234s)

  Buffer.Linear.Test                                                         (0.501s)
  ├─ Unit ················ 11/12 ✗                                           (0.345s)
  │  ╰─ ✗ allocate creates buffer with specified size
  ├─ EdgeCase ············  6/6  ✓                                           (0.089s)
  ├─ Integration ·········  2/2  ✓                                           (0.067s)
  ╰─ Performance ·········  0/0  ○

  47 tests completed in 1.783s (46 passed, 1 failed, 0 skipped)
  Slowest: Buffer.Ring.Test.Integration.file system round trip (0.892s)
```

**Key choices**:
- **Suite-level aggregation**: `12/12 ✓` is denser than 12 individual lines. Expand only suites with failures
- **Performance tests show metrics**: For `.timed()` tests, show the measured value (median) alongside the test name, not just pass/fail
- **Slowest test callout**: One line identifying the bottleneck — actionable information
- **Total duration**: Wall-clock time for the entire run

### Phase 3: Performance Summary Table

For benchmark suites (`.timed()` tests), append a focused comparison table:

```
  PERFORMANCE RESULTS

  ┌─────────────────────────────────────┬────────────┬────────────┬──────────┐
  │ Test                                │     Median │        Min │   vs Run │
  ├─────────────────────────────────────┼────────────┼────────────┼──────────┤
  │ Throughput.1000 sequential          │  20.750 ms │  19.234 ms │          │
  │ Throughput.1000 concurrent          │  15.123 ms │  14.001 ms │          │
  │ Overhead.100 dispatches             │   1.590 ms │   1.456 ms │   -3.2%  │
  │ Overhead.single dispatch            │   0.016 ms │   0.015 ms │          │
  │ Lifecycle.create warm shutdown      │   2.210 ms │   2.001 ms │  +12.1%  │
  │ Contention.40 tasks                 │   4.567 ms │   4.234 ms │          │
  │ Contention.400 tasks                │  12.345 ms │  11.890 ms │          │
  │ Contention.2000 tasks               │  45.678 ms │  43.210 ms │          │
  └─────────────────────────────────────┴────────────┴────────────┴──────────┘

  8 benchmarks, median CV: 4.2% (stable)
  Regressions: 1 (Lifecycle.create warm shutdown +12.1%)
```

**Key choices**:
- **Box-drawn table**: Proper Unicode box-drawing, not markdown `|---|`. Visually distinct from prose output
- **Right-aligned numbers**: Decimal points align for quick scanning
- **Change column**: Only shown when baseline data exists. Empty cells for first run
- **One-line summary**: Total count, overall stability assessment, regression callout
- **Common prefix stripped**: `Buffer.Ring.Test.Performance.` removed for density

### Phase 4: Side-by-Side Benchmark Comparison

For the `run-benchmarks.sh` use case (comparing two implementations):

```
  swift-io vs NIO Benchmark Comparison

  ┌──────────────────────────────┬──────────────┬──────────────┬───────────────┐
  │ Test                         │      swift-io│          NIO │        Factor │
  ├──────────────────────────────┼──────────────┼──────────────┼───────────────┤
  │ Throughput.1000 sequential   │    20.750 ms │    18.234 ms │   1.14x       │
  │ Throughput.1000 concurrent   │    15.123 ms │    12.456 ms │   1.21x       │
  │ Overhead.100 dispatches      │     1.590 ms │     0.779 ms │   2.04x       │
  │ Lifecycle.create shutdown    │     2.210 ms │     0.213 ms │  10.38x       │
  │ Contention.40 tasks          │     4.567 ms │     3.890 ms │   1.17x       │
  │ Channel.1000 echo           │    45.678 ms │    42.345 ms │   1.08x       │
  └──────────────────────────────┴──────────────┴──────────────┴───────────────┤

  Summary: NIO faster in 6/6 tests. Largest gap: Lifecycle (10.38x)
```

**Key choices**:
- **Factor column**: The most actionable number. "How many times faster/slower?"
- **Color**: Factor > 2x in red (if our implementation is slower), green for parity or better
- **Summary line**: One sentence capturing the overall story — what a developer needs to remember

### Phase 5: Snapshot Test Output

For `#snapshot` tests, render inline diffs with proper context:

```
  Snapshot ········  4/5  ✗                                                  (0.234s)
    ✗ AtRule media snapshot - mixed media queries
      at AtRuleSnapshotTests.swift:42:5
      Inline snapshot does not match (1 line removed, 1 line added)

      @@ -1,3 +1,3 @@
       @media screen and (min-width: 768px) {
      -  color: red;
      +  color: blue;
       }
```

Where `-` lines are red, `+` lines are green, context lines are dim gray.

---

## Comparison Matrix

| Dimension | Current (Institute) | Apple Standard | Apple Advanced | Theoretical Ideal |
|-----------|:---:|:---:|:---:|:---:|
| Real-time feedback | Yes (flat stream) | Yes (flat stream) | **No** (deferred) | Yes (suite-grouped) |
| Suite hierarchy | **No** | Indented by depth | **Tree (├─╰─)** | Tree + suite aggregation |
| Suite-level aggregation | **No** | **No** | **No** | **12/12 ✓** counts |
| Terminal width awareness | **No** | **No** | Yes (COLUMNS) | Yes |
| Right-aligned durations | **No** | **No** | Yes | Yes |
| Progress indication | **No** | **No** | **No** | Dot/block progress |
| Failure expansion | Inline (flat) | Inline (flat) | Deferred section | Inline under suite |
| Performance metrics in tree | **No** | **No** | **No** | Median alongside name |
| Performance summary table | Markdown `\|` | **No** | **No** | Box-drawn Unicode |
| Side-by-side comparison | **No** | **No** | **No** | Factor column |
| Baseline change tracking | `+12.1%` text | **No** | **No** | Colored change column |
| Snapshot diff rendering | Via `Test.Text` | Via ANSI | N/A | Colored unified diff |
| Slowest test callout | **No** | **No** | **No** | One-line at summary |
| CI-friendly structured output | JSONL (`.tee`) | **No** | **No** | JSONL (existing) |
| Symbol vocabulary | ✓✗○⚠▶ | ◇✔✘➜⚠±↳⎙ | Same as standard | ✓✗○⚠ (minimal) |
| Color capability detection | Full (Console) | Full (built-in) | Same | Full (Console) |
| `NO_COLOR` / `FORCE_COLOR` | Yes | Yes | Yes | Yes |
| Box-drawing fallback tiers | **No** | **No** | Unicode/CP437/ASCII | Unicode/ASCII |

---

## Architecture Implications

### What Exists and Can Be Reused

| Component | Location | Capability |
|-----------|----------|------------|
| `Console.Capability.detect()` | swift-console | TTY, NO_COLOR, FORCE_COLOR, CI, COLORTERM, TERM |
| `Console.Style.apply()` | swift-console | ANSI escape with capability degradation |
| `Test.Text` → `Console.Style` mapping | Terminal reporter | 13 semantic styles → ANSI |
| `Test.Event` pipeline | swift-tests/Testing | Event-driven, reporter-pluggable |
| `.tee` reporter | swift-testing | Dual console + JSONL already works |
| `Tests.Diagnostic` | swift-tests | Full statistical analysis already computed |
| `Tests.Diagnostic.summary()` | swift-tests | Table formatting, prefix stripping |
| `Graph<K,V>` | swift-testing (upstream) | Hierarchical tree data structure |

### What Needs to Be Built

| Component | Purpose | Effort |
|-----------|---------|--------|
| Suite-level aggregation in reporter | Collect per-suite pass/fail/skip counts | Medium |
| Tree renderer with box-drawing | Render `Graph` as terminal tree | Medium (Apple's is ~400 lines) |
| Terminal width detection | `ioctl(TIOCGWINSZ)` or COLUMNS | Low (add to Console) |
| Right-aligned duration formatter | Width-aware padding with ANSI counting | Low (Apple's `_padWithDuration` is ~25 lines) |
| Progress indicator (dots/blocks) | Real-time suite progress | Medium |
| Box-drawn table renderer | Replace markdown tables for performance | Medium |
| Comparison table formatter | Side-by-side with factor column | Medium |
| Benchmark comparison CLI | Post-process two JSONL files into comparison | Medium |

### Reporter Architecture Decision

**Option A: Enhance `Test.Reporter.Terminal`**

Add hierarchy, aggregation, and progress to the existing streaming reporter. Real-time feedback preserved. Complexity: the reporter must buffer suite state while streaming.

**Option B: Separate reporters for streaming vs summary**

A streaming reporter for real-time feedback (current) + a deferred reporter for end-of-run summary (like Apple's Advanced). The `.tee` pattern already supports dual reporters.

**Option C: Hybrid reporter**

Stream suite-level progress in real time; render full tree summary at the end. Buffer per-suite state during the run, emit suite-completion lines as they finish, then render the complete tree.

**Recommendation**: Option C. It provides both real-time feedback (suites completing as they run) and structural overview (tree at end). The `.tee` reporter pattern means we can layer this without disrupting the JSONL structured output.

---

## Implementation Sketch

### Phasing

| Phase | Scope | Effort | Value |
|-------|-------|--------|-------|
| 1 | Suite-level aggregation + summary tree | Medium | High — transforms the output from flat to structured |
| 2 | Right-aligned durations + terminal width | Low | Medium — polishes visual alignment |
| 3 | Performance summary as box-drawn table | Medium | High — makes benchmark results scannable |
| 4 | Real-time suite progress (dots/blocks) | Medium | Medium — temporal feedback during long runs |
| 5 | Side-by-side benchmark comparison | Medium | High — benchmark suites exist to compare |
| 6 | Benchmark comparison CLI tool | Medium | Medium — replaces `run-benchmarks.sh` |

Phases 1-3 deliver the highest value. Phase 4 requires cursor control (moving back to update a line), which adds platform complexity. Phases 5-6 could be deferred or handled by a separate tool that reads JSONL output.

### Terminal Width Detection

The `Console` module currently does not detect terminal width. Add:

```swift
extension Console {
    public static func terminalWidth(fallback: Int = 120) -> Int {
        // 1. COLUMNS environment variable
        // 2. ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize)
        // 3. fallback
    }
}
```

This is a small addition to `swift-console` that multiple reporters can share.

### Box-Drawing Table Renderer

A general-purpose table renderer for the Console module:

```swift
Console.Table(
    columns: [
        .init(header: "Test", alignment: .left),
        .init(header: "Median", alignment: .right),
        .init(header: "Min", alignment: .right),
        .init(header: "vs Run", alignment: .right),
    ],
    rows: diagnostics.map { d in
        [d.displayName, d.median.formatted(), d.min.formatted(), d.change ?? ""]
    },
    style: .boxDrawing  // or .ascii, .markdown
)
```

This is reusable beyond test output — any CLI tool in the ecosystem could use it.

---

## Open Questions

1. **Real-time progress vs deferred summary**: Apple chose fully deferred. Jest uses real-time per-file. Should we support both modes (configurable via environment variable)?

2. **Performance diagnostic verbosity**: The full `Tests.Diagnostic.formatted()` dumps 25 lines per test. Should the default be the compact table, with full diagnostics available via `SWIFT_TEST_VERBOSE=1` or similar?

3. **Comparison source**: Side-by-side comparison requires two result sets. Should this be (a) a CLI tool that reads two JSONL files, (b) built into the reporter with a "reference" JSONL path, or (c) a `swift test --compare-to <baseline.jsonl>` flag?

4. **Terminal width detection placement**: Should `Console.terminalWidth()` live in `swift-console` (Layer 3) or `Terminal_Primitives` (Layer 1)?

5. **Box-drawing table as reusable component**: Should the table renderer be part of `swift-console`, a separate `Console.Table` module, or private to the test reporter?

---

## Outcome

**Status**: IN_PROGRESS

This document establishes the current state, surveys prior art, and proposes a theoretical ideal end-state with six implementation phases. The core insight is that most of the data is already captured — the gap is purely in how it's rendered.

Key decisions to make before implementation:
- Reporter architecture: hybrid (Option C) recommended
- Phasing: Phases 1-3 deliver the most value
- Terminal width detection: needed in Console module first
- Box-drawn tables: needed for performance summary, possibly reusable

## References

- `swift-institute/Research/test-output-quality-parity.md` — Prior research on failure output quality (DECISION, 2026-03-03)
- `swift-institute/Research/benchmark-implementation-conventions.md` — Benchmark organization patterns
- `swift-tests/Sources/Tests Reporter/Test.Reporter.Terminal.swift` — Current terminal reporter (217 lines)
- `swift-tests/Sources/Tests Performance/Tests.Diagnostic+Format.swift` — Performance diagnostic formatting (274 lines)
- `swift-tests/Sources/Tests Performance/Tests.Diagnostic+Summary.swift` — Summary table formatter (90 lines)
- `swift-tests/Sources/Tests Performance/Reporting.swift` — Manual reporting API (109 lines)
- `swift-foundations/swift-io/Benchmarks/run-benchmarks.sh` — Benchmark comparison script (58 lines)
- `swift-foundations/swift-console/Sources/Console/` — Terminal capability detection and styling
- `swiftlang/swift-testing/.../Event.ConsoleOutputRecorder.swift` — Apple standard reporter (381 lines)
- `swiftlang/swift-testing/.../Event.AdvancedConsoleOutputRecorder.swift` — Apple experimental tree reporter (~900 lines)
- `swiftlang/swift-testing/.../Event.Symbol.swift` — Apple symbol vocabulary (191 lines)
