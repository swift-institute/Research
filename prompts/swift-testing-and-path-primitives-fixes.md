# Handoff: swift-testing Improvements + swift-path-primitives Compiler Crash Fix

## Assignment

Conduct a Tier 2 research investigation ([RES-004]) and implement fixes for two interconnected issues that block reliable performance testing across the Swift Institute ecosystem:

1. **swift-path-primitives**: Compiler crash (signal 6) in release builds with StrictMemorySafety
2. **swift-testing**: Three gaps that force experiments to use ad-hoc benchmark executables instead of `.timed()` tests

These issues were discovered during the `rendering-context-protocol-vs-witness` experiment (2026-03-14). The experiment successfully used swift-testing's `.timed()` in debug mode but was forced to fall back to a standalone `ContinuousClock`-based benchmark for release measurements due to (1), and produced interleaved, unattributable output due to (2).

### Deliverables

1. **Fix**: `swift-path-primitives` compiler crash in release + StrictMemorySafety
2. **Fix**: Fully qualified test names in swift-testing `PERFORMANCE_DIAGNOSTIC` JSON
3. **Fix**: Global serialization option for swift-testing performance suites
4. **Enhancement**: Tabular comparison output for `.timed()` multi-variant experiments
5. **Research document**: `swift-institute/Research/swift-testing-performance-infrastructure-gaps.md` per [RES-003]

### Priority Order

| Priority | Item | Impact |
|----------|------|--------|
| P0 | Path.String compiler crash | Blocks ALL release testing via nested packages |
| P1 | Fully qualified diagnostic names | Data correctness — unattributable results |
| P2 | Global serialization | Measurement reliability — cross-suite interference |
| P3 | Tabular comparison output | Developer experience — eliminates ad-hoc benchmarks |

---

## Context: Why This Matters

The Swift Institute uses a nested testing package pattern ([INST-TEST-001]) where every ecosystem package has a `Tests/Package.swift` that depends on `swift-foundations/swift-testing` for `.timed()` performance tests and `#snapshot` snapshot tests. This is the canonical testing infrastructure — ALL packages use it.

When `swift test -c release` crashes in the nested package, it means **no ecosystem package can run performance tests in release mode** through the standard infrastructure. This forces every experiment to create ad-hoc benchmark executables, duplicating measurement logic, losing the structured diagnostic output, and diverging from the standard test pattern.

The rendering-context experiment demonstrated this problem clearly:
- Debug tests via `.timed()`: worked, produced 34 structured diagnostic blocks
- Release tests via `.timed()`: compiler crash in `Path.String.swift` (transitive dependency)
- Workaround: standalone `Benchmark` executable with `ContinuousClock` — functional but ad-hoc

### Prior Art

| Document | Relevance |
|----------|-----------|
| `swift-institute/Experiments/rendering-context-protocol-vs-witness/` | The experiment that uncovered these issues |
| `swift-institute/Research/nested-testing-package-flattening.md` | Nested package pattern design |
| `swift-institute/Research/nested-testing-package-structure.md` | Test directory structure |

---

## Issue 1: swift-path-primitives Compiler Crash

### Symptom

```
error: compile command failed due to signal 6
<unknown>:0: error: fatal error encountered during compilation;
  please submit a bug report (https://swift.org/contributing/#reporting-bugs)
```

The crash occurs during release-mode compilation of `Path Primitives` module, specifically in `Path.String.swift`. It is deterministic — clean builds reproduce it.

### Root Cause Location

**File**: `/Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.String.swift`

**Lines**: Around 562–579

**Pattern**: `defer { for buffer in unsafe buffers { ... } }` with `UnsafeMutablePointer<Path.Char>` arrays.

```swift
var buffers1: [UnsafeMutablePointer<Path.Char>] = unsafe []
unsafe buffers1.reserveCapacity(strings1.count)
defer { for buffer in unsafe buffers1 { unsafe buffer.deallocate() } }
```

The compiler emits StrictMemorySafety warnings about the `for-in` loop:
- `argument 'self' in call to instance method 'next' has unsafe type 'inout IndexingIterator<[UnsafeMutablePointer<Path.Char>]>'`
- `reference to var '$buffer$generator' involves unsafe type`
- `reference to instance method 'next()' involves unsafe type`

Then crashes with signal 6 during SIL optimization in release mode.

### Diagnosis Steps

1. Read `Path.String.swift` in full — understand all the `unsafe` annotation patterns used
2. Identify EVERY location with `defer { for buffer in unsafe ... }` pattern
3. Check if the crash is in the `defer` specifically or in any `for-in` over `[UnsafeMutablePointer<...>]`
4. Check if the crash reproduces with just `for buffer in unsafe buffers1 { }` (without defer)
5. Check if the crash reproduces with `unsafe { for buffer in buffers1 { ... } }` block form

### Fix Strategy

The `unsafe` keyword in Swift 6.2.4 with StrictMemorySafety has two forms:

**Expression-level** (current, crashing):
```swift
defer { for buffer in unsafe buffers1 { unsafe buffer.deallocate() } }
```

**Block-level** (likely fix):
```swift
defer { unsafe { for buffer in buffers1 { buffer.deallocate() } } }
```

The block form wraps the entire unsafe scope, avoiding the compiler needing to thread `unsafe` through the `for-in` iteration machinery (which is where it crashes — the iterator's `next()` call involves unsafe types).

Alternative: use a `while` loop with manual index:
```swift
defer {
    for i in 0..<buffers1.count {
        unsafe buffers1[i].deallocate()
    }
}
```

This avoids the Iterator protocol machinery entirely.

### Verification

After fixing:
```bash
cd /Users/coen/Developer/swift-primitives
swift build -c release 2>&1 | grep -E "(error|Build complete)"
```

Then verify the nested test package can build in release:
```bash
cd /Users/coen/Developer/swift-institute/Experiments/rendering-context-protocol-vs-witness/Tests
rm -rf .build
swift test -c release 2>&1 | tail -5
```

### Scope Check

Before fixing `Path.String.swift`, grep the entire swift-primitives repo for similar patterns:
```bash
grep -rn "defer.*for.*unsafe\|unsafe.*for.*in.*unsafe" \
  /Users/coen/Developer/swift-primitives/ \
  --include="*.swift"
```

Fix ALL instances, not just the one in Path.String.swift. The same crash likely affects any `defer { for x in unsafe collection { ... } }` pattern.

Also check swift-standards and swift-foundations:
```bash
grep -rn "defer.*for.*unsafe\|unsafe.*for.*in.*unsafe" \
  /Users/coen/Developer/swift-standards/ \
  /Users/coen/Developer/swift-foundations/ \
  --include="*.swift"
```

### File a Swift Bug

After confirming the fix works, the compiler crash itself should be reported. Even if our code was technically using `unsafe` incorrectly, a compiler crash (signal 6) is always a bug — it should produce a diagnostic, not crash. Include:

- Minimal reproduction (extract the crashing pattern into a standalone file)
- Swift version: 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
- Flags: `-c release` + StrictMemorySafety
- Crash backtrace (from the build output)

---

## Issue 2: swift-testing — Fully Qualified Test Names in Diagnostics

### Symptom

When multiple `@Suite(.serialized)` types contain identically-named test methods (e.g., `_10_elements`, `_100_elements`), the `PERFORMANCE_DIAGNOSTIC` JSON blocks emit only the method name:

```json
{
  "test": "_10_elements",
  "status": "PASS",
  "metric": "median",
  "actual": 0.011125,
  ...
}
```

With 5 suites each having `_10_elements`, `_100_elements`, `_1000_elements`, `_10000_elements`, this produces 20 blocks where you cannot determine which block belongs to which variant.

### Expected Behavior

```json
{
  "test": "V1_Protocol._10_elements",
  "status": "PASS",
  "metric": "median",
  "actual": 0.011125,
  ...
}
```

Or fully qualified:
```json
{
  "test": "Performance_Tests.V1_Protocol._10_elements",
  ...
}
```

### Where to Fix

The `PERFORMANCE_DIAGNOSTIC` output is generated by swift-testing's `.timed()` trait implementation. Key files to investigate:

**swift-testing location**: `/Users/coen/Developer/swift-foundations/swift-testing/`

Search for:
```bash
grep -rn "PERFORMANCE_DIAGNOSTIC" \
  /Users/coen/Developer/swift-foundations/swift-testing/ \
  --include="*.swift"
```

This will locate the code that emits the JSON diagnostic blocks. The `"test"` field is populated from the test's name — it needs to include the suite hierarchy.

Also search for how the test name is resolved:
```bash
grep -rn "\.name\|displayName\|testName\|qualifiedName" \
  /Users/coen/Developer/swift-foundations/swift-testing/ \
  --include="*.swift" \
  | grep -i "timed\|performance\|diagnostic"
```

### Fix Strategy

The `.timed()` implementation likely accesses the current test's name via the Testing framework's test discovery API. The test object should have both a short name and a fully qualified name. The fix is to use the fully qualified name (including suite chain) in the diagnostic output.

If the test object only provides the short name at the point where diagnostics are emitted, you may need to:
1. Thread the suite context through to the diagnostic emitter
2. Or access the test's `id` property which is typically fully qualified

### Verification

After fixing, run the rendering-context experiment's debug tests:
```bash
cd /Users/coen/Developer/swift-institute/Experiments/rendering-context-protocol-vs-witness/Tests
swift test 2>&1 | grep '"test":' | sort
```

Expected output should show fully qualified names:
```
  "test": "V1_Protocol._10_elements",
  "test": "V1_Protocol._100_elements",
  "test": "V1_Protocol._1000_elements",
  ...
  "test": "V2_Witness._10_elements",
  ...
```

### Design Consideration

The `"test"` field is machine-readable JSON. Consider whether to:
- **A**: Include just `Suite.method` (two levels) — sufficient for disambiguation
- **B**: Include the full path `Module.Suite.method` — more robust but verbose
- **C**: Add a separate `"suite"` field alongside `"test"`

Option C is the most flexible — it preserves backward compatibility (the `"test"` field stays as-is) while adding the suite context:

```json
{
  "suite": "V1_Protocol",
  "test": "_10_elements",
  "qualified_name": "Performance_Tests.V1_Protocol._10_elements",
  ...
}
```

This is a non-breaking change.

---

## Issue 3: swift-testing — Global Serialization for Performance Suites

### Symptom

Each suite has `.serialized`, but suites run in parallel:

```swift
@Suite(.serialized)  // serializes within V1_Protocol
struct V1_Protocol { ... }

@Suite(.serialized)  // serializes within V2_Witness
struct V2_Witness { ... }
```

V1's `_10_elements` and V2's `_10_elements` can execute simultaneously, causing:
- CPU cache contention between benchmarks
- Thermal throttling from concurrent load
- Scheduler interference (context switches during measurement)
- Noisy, unreliable measurements

### Expected Behavior

A mechanism to serialize ALL performance tests across ALL suites:

```swift
// Option A: Global serialization trait
@Suite(.serialized(scope: .global))
struct V1_Protocol { ... }

// Option B: Serialization group
@Suite(.serialized(group: "rendering-benchmark"))
struct V1_Protocol { ... }

@Suite(.serialized(group: "rendering-benchmark"))
struct V2_Witness { ... }

// Option C: Top-level wrapper suite
@Suite(.serialized)
enum AllBenchmarks {
    @Suite struct V1_Protocol { ... }
    @Suite struct V2_Witness { ... }
}
```

### Where to Fix

Search for the serialization trait implementation:
```bash
grep -rn "serialized\|Serialized\|serial" \
  /Users/coen/Developer/swift-foundations/swift-testing/ \
  --include="*.swift" \
  | grep -iv "test\|spec\|snap"
```

The `.serialized` trait likely controls whether a suite's tests are dispatched sequentially. The fix needs to extend this to cross-suite coordination.

### Fix Strategy

**Recommended: Option C (wrapper suite) first, then Option B.**

Option C may already work — test whether a `@Suite(.serialized)` wrapper around nested `@Suite` types serializes ALL contained tests. If it does, no code change is needed; just document the pattern.

```swift
// Test this: does .serialized on the outer suite serialize inner suites?
@Suite(.serialized)
enum AllBenchmarks {
    @Suite
    struct V1 {
        @Test(.timed()) func small() { ... }
        @Test(.timed()) func large() { ... }
    }
    @Suite
    struct V2 {
        @Test(.timed()) func small() { ... }
        @Test(.timed()) func large() { ... }
    }
}
```

If inner suites DO run in parallel despite the outer `.serialized`, then we need a code change.

**Option B (serialization groups)** is more powerful but more complex. It introduces a named coordination primitive that cross-cuts the suite hierarchy. This is the right long-term solution but requires careful design:

- How do groups interact with `.serialized` on individual suites?
- Can a test be in multiple groups?
- What happens if group A and group B share a test?

### Verification

Create a small experiment that proves cross-suite serialization works:

```swift
@Suite(.serialized)
enum SerializationTest {
    @Suite struct A {
        @Test func first() { print("A.first start"); Thread.sleep(forTimeInterval: 0.1); print("A.first end") }
        @Test func second() { print("A.second start"); Thread.sleep(forTimeInterval: 0.1); print("A.second end") }
    }
    @Suite struct B {
        @Test func first() { print("B.first start"); Thread.sleep(forTimeInterval: 0.1); print("B.first end") }
        @Test func second() { print("B.second start"); Thread.sleep(forTimeInterval: 0.1); print("B.second end") }
    }
}
```

If serialized, output should show no overlap. If parallel, starts and ends will interleave.

### Immediate Workaround

Until fixed, the workaround is to put ALL performance tests in a single `@Suite(.serialized)` struct with prefixed method names:

```swift
@Suite(.serialized)
struct AllBenchmarks {
    @Test(.timed()) func v1_10_elements() { ... }
    @Test(.timed()) func v1_100_elements() { ... }
    @Test(.timed()) func v2_10_elements() { ... }
    ...
}
```

This is ugly but guarantees serialization and unique names. Document this as the recommended pattern until the global serialization fix lands.

---

## Issue 4: swift-testing — Tabular Comparison Output for `.timed()` Experiments

### Symptom

After running 20 performance tests (5 variants × 4 sizes), the output is 20 separate `PERFORMANCE MEASUREMENT` blocks. To compare variants, you must manually extract the median values, compute ratios, and build a table. This is exactly what the ad-hoc `Benchmark` executable does — it collects all results and prints a comparison table.

### Expected Behavior

After all `.timed()` tests in a suite (or global) complete, swift-testing should print a summary table:

```
PERFORMANCE COMPARISON

| Test                        |     Median |     vs V1_Protocol |
|-----------------------------|------------|---------------------|
| V1_Protocol._10_elements    |    2.00 µs |              1.00x |
| V2_Witness._10_elements     |    1.83 µs |              0.91x |
| V3_ActionBatch._10_elements |    1.79 µs |              0.89x |
| V4_ActionReuse._10_elements |    1.95 µs |              0.97x |
| V5_AnyView._10_elements     |    1.83 µs |              0.91x |
|                             |            |                     |
| V1_Protocol._100_elements   |   12.58 µs |              1.00x |
| V2_Witness._100_elements    |   13.16 µs |              1.04x |
...
```

### Design Questions

1. **Baseline selection**: How does the user indicate which test is the baseline? Options:
   - First test in the suite is baseline (implicit, fragile)
   - `.timed(baseline: true)` trait parameter (explicit)
   - `.timed(baselineGroup: "protocol")` for named grouping
   - No baseline — just show all medians, let the user compare

2. **Grouping**: How are tests grouped in the table?
   - By suite (each suite is a column)
   - By a shared suffix/prefix (e.g., all `*_10_elements` grouped together)
   - By a user-specified grouping trait

3. **Output format**: Where does the table appear?
   - stdout after all tests complete
   - A separate `.json` or `.csv` file in a configurable output directory
   - Both

### Recommended Design

Start simple:

1. After all `.timed()` tests in the run complete, print a `PERFORMANCE SUMMARY` section
2. Sort tests by suite name, then by test name
3. Show median and min for each test
4. If a `.timed(baseline: true)` trait is present, show ratios against the baseline at each size
5. Output as aligned plaintext table to stdout

No grouping heuristics, no CSV export, no fancy formatting. Just collect what's already measured and print it together.

### Where to Fix

The summary output should be emitted from the test runner's completion handler. Search for:
```bash
grep -rn "allTests\|testRun\|complete\|finish\|summary\|report" \
  /Users/coen/Developer/swift-foundations/swift-testing/ \
  --include="*.swift" \
  | grep -iv "snapshot\|spec"
```

The `.timed()` trait already collects all the data (durations, statistics). The summary table is just a formatter that runs after all tests finish.

### Verification

Run the rendering-context experiment's tests and verify the summary table appears after all individual test results:

```bash
cd /Users/coen/Developer/swift-institute/Experiments/rendering-context-protocol-vs-witness/Tests
swift test 2>&1 | tail -30
```

Should show the comparison table at the end.

---

## Implementation Order

### Phase 1: Path.String Crash Fix (P0)

1. Read `Path.String.swift` in full
2. Grep for all similar patterns across swift-primitives
3. Fix all instances (block-level `unsafe { }` or index-based loops)
4. Verify: `swift build -c release` from swift-primitives root
5. Verify: nested test package release build succeeds
6. Create minimal reproduction experiment in swift-institute/Experiments/
7. File Swift compiler bug with reproduction

### Phase 2: Diagnostic Names (P1)

1. Find the `PERFORMANCE_DIAGNOSTIC` emission code in swift-testing
2. Identify how the test name is resolved
3. Add fully qualified name (suite + method) to the JSON output
4. Add `"suite"` field for backward-compatible enrichment
5. Verify with rendering-context experiment

### Phase 3: Global Serialization (P2)

1. Test whether nested `@Suite(.serialized)` already serializes inner suites
2. If yes: document the pattern, add to testing-institute skill
3. If no: implement serialization groups or scope parameter
4. Verify with timing experiment (print-based overlap detection)

### Phase 4: Comparison Table (P3)

1. Design the summary formatter
2. Implement `.timed(baseline: true)` trait parameter
3. Add summary output after test run completion
4. Verify with rendering-context experiment

---

## Key Files

### swift-path-primitives

| File | Contains |
|------|----------|
| `/Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.String.swift` | Crashing `defer { for buffer in unsafe ... }` pattern (lines 562–579) |

### swift-testing

| File | Contains |
|------|----------|
| `/Users/coen/Developer/swift-foundations/swift-testing/` | Root of swift-testing package |
| Search: `PERFORMANCE_DIAGNOSTIC` | JSON diagnostic emission code |
| Search: `serialized` | Suite serialization trait implementation |
| Search: `.timed` | Performance measurement trait |

### Experiment (reference)

| File | Contains |
|------|----------|
| `/Users/coen/Developer/swift-institute/Experiments/rendering-context-protocol-vs-witness/Tests/Performance Tests/RenderingDispatchPerformanceTests.swift` | Test file that demonstrates all three swift-testing issues |
| `/Users/coen/Developer/swift-institute/Experiments/rendering-context-protocol-vs-witness/Sources/Benchmark/main.swift` | Ad-hoc benchmark that the swift-testing fixes should make unnecessary |

---

## Empirical Evidence from the Experiment

### Debug Test Output (swift-testing `.timed()`)

The debug run produced 34 `PERFORMANCE_DIAGNOSTIC` JSON blocks. Here is one example showing the structure:

```json
{
  "test": "_1000_elements",
  "status": "PASS",
  "metric": "median",
  "actual": 0.001810542,
  "distribution": {
    "count": 20,
    "min": 0.001457375,
    "median": 0.001810542,
    "mean": 0.0018066062,
    "max": 0.002352875,
    "stddev": 0.000301175,
    "cv": 16.67,
    "mad": 0.000322646,
    "p95": 0.002352875,
    "p99": 0.002352875,
    "outliers": 0
  },
  "trend": {
    "mann_kendall_z": 1.52,
    "interpretation": "none"
  },
  "environment": {
    "arch": "arm64",
    "physical_cores": 8,
    "logical_cores": 8,
    "memory_bytes": 25769803776,
    "swift_version": "6.2",
    "optimization": "debug",
    "feature_flags": {
      "NonisolatedNonsendingByDefault": true,
      "StrictMemorySafety": true
    },
    "os": "Darwin 25.2.0"
  },
  "durations_seconds": [0.001594, 0.001484, ...]
}
```

**Problem**: This block says `"test": "_1000_elements"` — which of the 5 variants does it belong to? Impossible to determine from the JSON alone. You must parse the surrounding `▶ Performance_Tests.V5_AnyView._1000_elements` line from the human-readable output and correlate it with the next JSON block — but with parallel suites, the ▶ lines interleave with JSON blocks from other suites.

### Standalone Benchmark Output (ad-hoc, what swift-testing should replace)

```
=== BENCHMARK (RELEASE) ===

| Variant        | Elements |     Median |        Min |        Max | vs V1  |
|----------------|----------|------------|------------|------------|--------|
| V1_Protocol    |       10 |    2.00 µs |    1.45 µs |   28.16 µs |  1.00x |
| V2_Witness     |       10 |    1.83 µs |    1.75 µs |    6.79 µs |  0.91x |
| V3_ActionBatch |       10 |    1.79 µs |    1.75 µs |    2.54 µs |  0.89x |
| V4_ActionReuse |       10 |    1.95 µs |    1.91 µs |    6.75 µs |  0.97x |
| V5_AnyView     |       10 |    1.83 µs |    1.75 µs |    6.04 µs |  0.91x |
| V1_Protocol    |      100 |   12.58 µs |   12.45 µs |   27.91 µs |  1.00x |
| V2_Witness     |      100 |   13.16 µs |   12.70 µs |   43.54 µs |  1.04x |
| V3_ActionBatch |      100 |   15.41 µs |   15.04 µs |   20.16 µs |  1.22x |
| V4_ActionReuse |      100 |   16.95 µs |   16.58 µs |   22.29 µs |  1.34x |
| V5_AnyView     |      100 |   13.58 µs |   13.20 µs |   21.54 µs |  1.07x |
| V1_Protocol    |     1000 |  128.95 µs |  125.41 µs |  151.83 µs |  1.00x |
| V2_Witness     |     1000 |  129.20 µs |  123.70 µs |  148.62 µs |  1.00x |
| V3_ActionBatch |     1000 |  157.37 µs |  151.00 µs |  224.54 µs |  1.22x |
| V4_ActionReuse |     1000 |  175.83 µs |  171.70 µs |  232.37 µs |  1.36x |
| V5_AnyView     |     1000 |  134.33 µs |  126.58 µs |  250.91 µs |  1.04x |
| V1_Protocol    |    10000 |   1.327 ms |   1.249 ms |   1.484 ms |  1.00x |
| V2_Witness     |    10000 |   1.322 ms |   1.285 ms |   1.545 ms |  0.99x |
| V3_ActionBatch |    10000 |   1.599 ms |   1.553 ms |   1.955 ms |  1.20x |
| V4_ActionReuse |    10000 |   1.763 ms |   1.666 ms |   1.870 ms |  1.32x |
| V5_AnyView     |    10000 |   1.378 ms |   1.289 ms |   1.853 ms |  1.03x |

Correctness: ALL VARIANTS MATCH
```

This is the output format that swift-testing's P3 enhancement should produce natively after a `.timed()` test run.

---

## Success Criteria

The work is complete when:

1. `swift build -c release` succeeds for swift-primitives (Path.String crash fixed)
2. `swift test -c release` succeeds from the rendering-context experiment's `Tests/` directory
3. `PERFORMANCE_DIAGNOSTIC` JSON blocks include fully qualified test names
4. A mechanism exists (wrapper suite or serialization groups) to serialize performance tests across suites
5. A comparison summary table is printed after `.timed()` test runs complete
6. The standalone `Benchmark` executable in the experiment becomes redundant
7. A minimal reproduction experiment exists for the compiler crash, with Swift bug filed
8. Research document written per [RES-003] documenting findings and decisions

---

## Constraints

1. **No Foundation** in swift-path-primitives fixes ([PRIM-FOUND-001])
2. **Backward compatibility** in swift-testing changes — existing `.timed()` tests must continue to work without modification
3. **Nested package pattern** must be preserved ([INST-TEST-001]) — the fix enables this pattern, not replaces it
4. **One type per file** ([API-IMPL-005]) for any new types added to swift-testing
5. **Typed throws** ([API-ERR-001]) for any new throwing functions
6. **Namespace nesting** ([API-NAME-001]) for any new types

---

## Package Locations

| Package | Path |
|---------|------|
| swift-primitives (monorepo) | `/Users/coen/Developer/swift-primitives/` |
| swift-path-primitives | `/Users/coen/Developer/swift-primitives/swift-path-primitives/` |
| swift-testing | `/Users/coen/Developer/swift-foundations/swift-testing/` |
| swift-institute | `/Users/coen/Developer/swift-institute/` |
| Experiment (reference) | `/Users/coen/Developer/swift-institute/Experiments/rendering-context-protocol-vs-witness/` |

---

## Notes

- **Do NOT modify the rendering-context experiment** — it serves as the validation fixture for these fixes
- **The compiler crash is a Swift bug**, not a swift-path-primitives bug. However, we fix our code first (to unblock ourselves) AND file the compiler bug (to fix the root cause)
- **swift-testing is our own package** (`swift-foundations/swift-testing`), not Apple's Swift Testing framework. We have full control over its implementation
- **The `PERFORMANCE_DIAGNOSTIC` format is our own design** — we can change it freely since it's not part of any external API contract
- **StrictMemorySafety** is enabled ecosystem-wide via Swift settings. Disabling it is not an option; all unsafe code must be correctly annotated
