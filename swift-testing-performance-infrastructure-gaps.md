# Performance Testing Infrastructure: Gaps and Fixes

<!--
---
version: 1.0.0
last_updated: 2026-03-14
status: DECISION
tier: 2
---
-->

## Summary

Investigation of four issues blocking reliable performance testing across the Swift Institute ecosystem, discovered during the `rendering-context-protocol-vs-witness` experiment (2026-03-14). The issues span the full severity range: a compiler crash in release builds (P0), unattributable diagnostic output (P1), cross-suite concurrency interference (P2), and missing tabular comparison output (P3). All four have been resolved — one via compiler-bug workaround, one via diagnostic enrichment, one via documentation of an existing capability, and one via a new collector/formatter.

## Background

Swift Institute uses a nested testing package pattern ([INST-TEST-001]) where every ecosystem package has a `Tests/Package.swift` depending on `swift-foundations/swift-tests` for `.timed()` and `#snapshot`. This infrastructure provides performance measurement through scope providers that emit `PERFORMANCE_DIAGNOSTIC` JSON blocks, which downstream tooling and humans consume for regression detection.

The `rendering-context-protocol-vs-witness` experiment (2026-03-14) exercised this infrastructure at scale for the first time: 5 suites, 4 test methods each, across debug and release configurations. Four distinct failures emerged:

1. Debug `.timed()` tests worked but release builds crashed (signal 6 in swift-path-primitives)
2. Diagnostic output was unattributable (no qualified test names)
3. Performance tests ran concurrently across suites (noisy measurements)
4. Manual comparison tables were needed to interpret results

## Investigation

### Issue 1: Compiler Crash on Release Build (P0)

**File**: `swift-path-primitives/Sources/Path Primitives/Path.String.swift`

**Root cause**: Expression-level `unsafe` on `for-in` loops over `[UnsafeMutablePointer<Path.Char>]` arrays crashes the SIL optimizer in release mode with StrictMemorySafety enabled.

**Pattern**:
```swift
defer { for buffer in unsafe buffers { unsafe buffer.deallocate() } }
```

The compiler needs to thread `unsafe` through the Iterator protocol's `next()` call, which involves `inout IndexingIterator<[UnsafeMutablePointer<...>]>`. The SIL optimizer crashes (signal 6) processing this in release mode. Debug mode succeeds because the SIL optimizer pipeline differs.

**Scope**: 18 instances found — 9 defer deallocation patterns and 9 enumerated pointer copy loops. No instances in swift-standards or swift-foundations.

**Fix**: Replace for-in iteration with index-based `for i in 0..<count` loops, which bypass the Iterator protocol entirely. Each unsafe operation is individually annotated:

```swift
// Before (crashes release SIL optimizer):
defer { for buffer in unsafe buffers { unsafe buffer.deallocate() } }

// After (works in both debug and release):
defer { for i in 0..<buffers.count { unsafe buffers[i].deallocate() } }
```

**Note on `unsafe` syntax**: `unsafe` in Swift 6.2.4 is an expression-level keyword, NOT a block construct. `unsafe { ... }` creates an unused closure (compiler warns "function is unused"). There is no block-level unsafe form.

**Note on compiler behavior**: Signal 6 during compilation is always a compiler bug regardless of whether the source code is correct. The compiler should emit a diagnostic, not crash. This should be filed as a Swift bug with a minimal reproduction case.

---

### Issue 2: Unattributable Diagnostic Names (P1)

**Problem**: The `PERFORMANCE_DIAGNOSTIC` JSON blocks emitted `"test": "_10_elements"` — just the function name. With 5 suites each having identically-named test methods (e.g., `_10_elements`, `_100_elements`, `_1000_elements`, `_10000_elements`), 20 diagnostic blocks were completely unattributable. There was no way to determine which suite produced which measurement.

**Analysis**: `Test.ID` already has `module`, `suite`, and `fullyQualifiedName` properties. The scope provider simply was not passing them through.

**Fix**: Added `suiteName` (optional) and `qualifiedName` to `Tests.Diagnostic`. The timed scope provider now passes `entry.id.suite` and `entry.id.fullyQualifiedName`. JSON output includes `"suite"` and `"qualified_name"` fields alongside the existing `"test"` field (non-breaking — `"test"` preserved for backward compatibility). Human-readable format now shows the qualified name.

**Before**:
```json
{"type": "PERFORMANCE_DIAGNOSTIC", "test": "_10_elements", "median_ns": 1234}
```

**After**:
```json
{"type": "PERFORMANCE_DIAGNOSTIC", "test": "_10_elements", "suite": "ProtocolRendering", "qualified_name": "ProtocolRendering/_10_elements", "median_ns": 1234}
```

---

### Issue 3: Cross-Suite Serialization (P2)

**Problem**: Each suite's `.serialized` trait only serializes within that suite. Suites themselves run in parallel, causing CPU contention, thermal throttling, and scheduler interference during benchmarks. Performance measurements from concurrent suites are unreliable.

**Investigation**: The nested `@Suite(.serialized)` wrapper pattern ALREADY WORKS in Swift Testing. `Test.Plan.Registry.propagate()` performs pre-order traversal merging parent modifiers into children. `Test.Runner.dispatch()` checks `traits[Test.Trait.Serialized.self]` and forces `.serial` concurrency for children, passing it recursively.

Wrapping multiple inner suites in a single outer suite with `.serialized` serializes ALL contained tests:

```swift
@Suite(.serialized)
enum AllBenchmarks {
    @Suite struct ProtocolRendering { ... }
    @Suite struct WitnessRendering { ... }
    @Suite struct DirectRendering { ... }
}
```

**Resolution**: No code change needed. The capability exists; it was undocumented in the Swift Institute context. The wrapper enum pattern is the recommended approach for existing performance test suites.

---

### Issue 4: Tabular Comparison Output (P3)

**Problem**: After 20+ `.timed()` tests complete, results are 20 separate diagnostic blocks scattered across test output. Extracting and comparing measurements requires manual work — copying values into a spreadsheet or text table. This is error-prone and does not scale.

**Design**: `Tests.Diagnostic.Collector` is a thread-safe singleton (via `Mutex`) that accumulates diagnostics during the test run. `Tests.Diagnostic.summary()` formats them as an aligned plaintext table. `Test.Runner.run()` drains the collector and prints the summary after all tests complete but before the reporter finishes.

**Implementation**: The summary table shows qualified test name, median, and min. Results are sorted by qualified name. Column widths are computed dynamically for alignment.

```
PERFORMANCE SUMMARY
─────────────────────────────────────────────────────────────────
Test                                          Median (ns)    Min (ns)
ProtocolRendering/_10_elements                      1,234       1,198
ProtocolRendering/_100_elements                    12,456      12,301
WitnessRendering/_10_elements                         892         871
WitnessRendering/_100_elements                      8,934       8,812
─────────────────────────────────────────────────────────────────
```

**Design choice**: The global singleton collector is pragmatic given that scope providers are stateless functions — there is no natural place to thread accumulation state through the provider API.

**Future work**: `.timed(baseline: true)` for comparison ratios, grouping by suffix/prefix, CSV/JSON export.

## Findings

| ID | Priority | Issue | Resolution |
|----|----------|-------|------------|
| F1 | P0 | Expression-level `unsafe` on for-in over pointer arrays crashes release SIL optimizer | Index-based loops bypass Iterator protocol; compiler bug to be filed |
| F2 | P1 | `PERFORMANCE_DIAGNOSTIC` emits only function name, not suite or qualified name | Added `suiteName` and `qualifiedName` to `Tests.Diagnostic`; non-breaking JSON enrichment |
| F3 | P2 | `.serialized` does not serialize across suites | Nested `@Suite(.serialized)` wrapper already works; document the pattern |
| F4 | P3 | No summary table after performance test runs | New `Tests.Diagnostic.Collector` singleton + `Tests.Diagnostic.summary()` formatter |

## Decisions

1. **Expression-level `unsafe` for-in over pointer arrays** is replaced with index-based loops ecosystem-wide. The for-in pattern is known-broken in release SIL and must not be reintroduced until the compiler bug is fixed.

2. **`"suite"` and `"qualified_name"` added alongside existing `"test"` field** (non-breaking JSON change). All existing consumers that parse `"test"` continue to work. New consumers should prefer `"qualified_name"` for unambiguous attribution.

3. **Nested `@Suite(.serialized)` wrapper** is the documented pattern for cross-suite serialization. No new API is needed — Swift Testing's trait propagation already handles this. Performance test suites in the ecosystem should adopt this wrapper pattern.

4. **Summary table uses a global singleton collector** — pragmatic given scope providers are stateless functions. The `Mutex`-protected `Collector` is the only shared mutable state, and it is drained exactly once after the run completes.

## Impact

- `swift build -c release` succeeds for all primitives packages (was: crash in `Path.String.swift`)
- Performance diagnostic output is machine-parseable with full test attribution
- Cross-suite serialization available via documented wrapper pattern
- Summary tables eliminate need for ad-hoc benchmark executables

### Files Changed

| File | Change |
|------|--------|
| `swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.String.swift` | 18 for-in patterns converted to index-based loops |
| `swift-foundations/swift-tests/Sources/Tests Performance/Tests.Diagnostic.swift` | Added `suiteName` and `qualifiedName` properties |
| `swift-foundations/swift-tests/Sources/Tests Performance/Tests.Diagnostic+Format.swift` | Added `suite` and `qualified_name` to JSON, qualified name in human output |
| `swift-foundations/swift-tests/Sources/Tests Performance/Test.Trait.Scope.Provider.timed.swift` | Pass full ID info, register with collector |
| `swift-foundations/swift-tests/Sources/Tests Performance/Test.Runner.swift` | Print summary after run |
| `swift-foundations/swift-tests/Sources/Tests Performance/Tests.Diagnostic.Collector.swift` | NEW: thread-safe diagnostic collector |
| `swift-foundations/swift-tests/Sources/Tests Performance/Tests.Diagnostic+Summary.swift` | NEW: summary table formatter |

### Related

- Swift compiler bug: expression-level `unsafe` on for-in over pointer arrays causes signal 6 in release SIL optimizer (to be filed)
- `swift-institute/Experiments/rendering-context-protocol-vs-witness/` — the experiment that uncovered these issues
