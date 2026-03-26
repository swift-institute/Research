# Naming + Implementation Audit: swift-tests & swift-testing

<!--
---
version: 1.0.0
last_updated: 2026-03-26
status: RECOMMENDATION
tier: 1
packages: [swift-tests, swift-testing]
skills: [naming, implementation]
---
-->

## Context

A 100%-strict audit of `swift-tests` and `swift-testing` against the `/naming` and `/implementation` skills identified **88 violations** (26 compound type names, 36 compound methods/properties, 26 implementation rule violations). This document serves as the remediation tracker.

## Packages

| Package | Path | Layer |
|---------|------|-------|
| swift-tests | `/Users/coen/Developer/swift-foundations/swift-tests/` | L3 Foundations |
| swift-testing | `/Users/coen/Developer/swift-foundations/swift-testing/` | L3 Foundations |

---

## Priority 1 — Active Defects & Dead Code

### I15. `reason.plainText` discards styling (BEHAVIORAL DEFECT)

**File**: `swift-testing/Sources/Testing/Testing.Reporter.Console.swift:87`

```swift
if let reason {
    message += dimmed(": \(reason.plainText)")
}
```

`reason` is `Test.Text` (styled). The `ConsoleSink` already has `render(_ text: Test.Text) -> String` at line 178 that maps segment styles through `Console.Style`. Using `.plainText` strips all styling. Fix: `render(reason)`.

### I9. Dead binding `nodeColumn`

**File**: `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.Rewriter.swift:112`

```swift
let nodeColumn = location.column  // extracted but never used — comment on line 115 says "Column is not checked"
```

Remove the dead binding entirely.

---

## Priority 2 — Public Compound Type Names [API-NAME-001]

These are public types with compound names that violate the Nest.Name pattern.

### swift-tests

| ID | File | Line | Current | Fix |
|----|------|------|---------|-----|
| N1 | `Tests Apple Testing Bridge/Test.Expectation.AppleBridge.swift` | 24 | `AppleTestingBridge` | Rename to nested type. Since this lives in a `#if canImport(Testing)` block and is a standalone enum, consider `Apple.Bridge` or restructure as an extension with a static `install()` on a properly nested namespace |
| N2 | `Tests Apple Testing Bridge/Test.Snapshot.RecordingTrait.swift` | 28 | `SnapshotRecordingTrait` | Rename to `Snapshot.Recording.Trait` or nest under `Test.Snapshot.Recording` |
| N3 | `Tests Snapshot/Test.Snapshot.Counter.swift` | 66 | `CounterKey` | Move into `extension Test.Snapshot.Counter { enum Key: Dependency.Key }` |
| N4 | `Tests Inline Snapshot/Test.Snapshot.Inline.Rewriter.swift` | 89 | `InlineSnapshotSyntaxRewriter` (private) | Rename to nested form even though private |
| N5 | `Tests Performance/Tests.Error.swift` | 21-30 | `AllocationStats`, `AllocationTracker`, `LeakDetector`, `PeakTracker` | These are compound typealiases of already-nested types (`Memory.Allocation.Statistics` etc). Either remove (consumers use the nested form) or re-export properly |

### swift-testing

| ID | File | Line | Current | Fix |
|----|------|------|---------|-----|
| N33 | `Testing Macros Implementation/ExpectMacro.swift` | 37 | `ExpectMacro` | `Expect.Macro` |
| N34 | `Testing Macros Implementation/ExpectMacro.swift` | 67 | `ExpectMacroError` | Nest as `Error` inside the renamed parent |
| N35 | `Testing Macros Implementation/RequireMacro.swift` | 30 | `RequireMacro` | `Require.Macro` |
| N36 | `Testing Macros Implementation/RequireMacro.swift` | 62 | `RequireMacroError` | Nest as `Error` inside the renamed parent |
| N37 | `Testing Macros Implementation/TestMacro.swift` | 20 | `TestMacro` | `Test.Macro` |
| N38 | `Testing Macros Implementation/TestMacro.swift` | 182 | `MacroError` | Nest as `Test.Macro.Error` or `Macro.Error` |
| N39 | `Testing Macros Implementation/TestsMacro.swift` | 50 | `TestsMacro` | `Tests.Macro` |
| N40 | `Testing Macros Implementation/SuiteMacro.swift` | 29 | `SuiteMacro` | `Suite.Macro` |
| N41 | `Testing Macros Implementation/SnapshotMacro.swift` | 22 | `SnapshotMacro` | `Snapshot.Macro` |
| N42 | `Testing Macros Implementation/SnapshotMacro.swift` | 115 | `SnapshotMacroError` | Nest as `Error` inside parent |
| N43 | `Testing Macros Implementation/Plugin.swift` | 16 | `TestingMacrosPlugin` | `Testing.Macros.Plugin` or `Plugin` (it's the only one) |
| N44 | `Testing/Testing.Reporter.JSONSink.swift` | 26 | `JSONSink` (internal) | Nest under reporter namespace |
| N45 | `Testing/Testing.Reporter.Console.swift` | 35 | `ConsoleSink` (private) | Nest under reporter namespace |
| N46 | `Testing/Testing.MacroSupport.swift` | 48 | `SuiteRegistration` | Remove or nest properly |
| N47 | `Testing/Testing.MacroSupport.swift` | 93 | `FactoryFunction` | Nest as `Factory.Function` or similar |
| N49 | `Testing Umbrella/Testing.XCTestBridge.swift` | 32 | `__TestingRunner` | Compound. Constrained by XCTest bridge ABI — document as [PATTERN-016] conscious debt if cannot rename |

**ABI-constrained** (flag but may require [PATTERN-016] documentation rather than rename):

| ID | File | Line | Identifiers |
|----|------|------|-------------|
| N48 | `Testing/Testing.MacroSupport.swift` | 23-54 | `__TestID`, `__TestSourceLocation`, `__TestTrait`, `__TestBody`, `__TestContentRecord`, `__TestContentRecordAccessor`, `__TestContentKind`, `__TestTraitCollectionModifier`, `__TestContentRecordContainer` |

These are `public typealias` declarations referenced from macro-generated code across module boundaries. The `__` prefix marks them as ABI. Renaming requires updating all macro codegen sites. Evaluate whether renaming is feasible; if not, document per [PATTERN-016].

---

## Priority 3 — Deprecated Typealiases to Delete

These are deprecated compound typealiases pointing at correctly-named types. Delete them.

| ID | File | Line | Identifier | Points to |
|----|------|------|-----------|-----------|
| N6 | `Tests Core/Test.Exclusion.Controller.swift` | 81 | `ExclusionController` | `Test.Exclusion.Controller` |
| N7 | `Tests Snapshot/Test.Snapshot.Storage.swift` | 213 | `StorageError` | `Test.Snapshot.Storage.Error` |
| N8 | `Tests Performance/Tests.Suite.swift` | 82 | `PerformanceSuite` | `Tests.Suite` |
| N9 | `Tests Performance/Tests.Comparison.swift` | 79 | `PerformanceComparison` | `Tests.Comparison` |

---

## Priority 4 — Public Compound Methods/Properties [API-NAME-002]

### swift-tests

| ID | File | Line | Current | Suggested |
|----|------|------|---------|-----------|
| N10 | `Tests Core/Test.Reporter.swift` | 56 | `makeSink()` | `sink()` |
| N11 | `Tests Core/Test.Manifest.swift` | 41 | `getFactoryNames()` | Computed property `factoryNames` or `names()` |
| N12 | `Tests Snapshot/Test.Snapshot.Configuration.swift` | 90 | `resolveRecording(explicit:)` | `resolve(recording:)` |
| N13 | `Tests Snapshot/Test.Snapshot.Storage.swift` | 107 | `readReference(at:)` | `reference(at:)` |
| N14 | `Tests Snapshot/Test.Snapshot.Storage.swift` | 164 | `ensureDirectory(at:)` | `ensure(directory:)` |
| N15 | `Tests Performance/Assertions.swift` | 24, 55 | `expectPerformance(lessThan:...)` | Restructure under `Tests.Performance` or `expect(lessThan:...)` |
| N16 | `Tests Performance/Assertions.swift` | 98 | `expectNoRegression(...)` | `expect(noRegression:...)` |
| N17 | `Tests Performance/Reporting.swift` | 25 | `printPerformance(...)` | Restructure |
| N18 | `Tests Performance/Reporting.swift` | 117 | `printComparisonReport(_:)` | `print(comparisons:)` |
| N19 | `Tests Performance/Tests.Suite.swift` | 55 | `printReport(metric:)` | `print(metric:)` |
| N20 | `Tests Performance/Tests.Baseline.Recording.swift` | 33 | `fromEnvironment()` | Static property `.current` or `init()` |
| N21 | `Tests Performance/Test.Runner.swift` | 526, 531 | `hasFailures`, `allPassed` | Restructure |

### swift-testing

| ID | File | Line | Current | Suggested |
|----|------|------|---------|-----------|
| N50 | `Testing/Testing.Configuration.swift` | 50 | `fromEnvironment()` | Static property `.current` or `init()` |
| N51 | `Testing/Testing.Discovery.swift` | 31 | `discoverFromSections()` | `discover(from: .sections)` or restructure |
| N52 | `Testing/Testing.Discovery.swift` | 124 | `discoverFromTypeMetadata()` | `discover(from: .typeMetadata)` |
| N53 | `Testing/Testing.Discovery.swift` | 223 | `discoverAll(fallbackFactoryNames:)` | `discover(all:)` |
| N54 | `Testing/Testing.Main.swift` | 85 | `runAll()` | `run()` (context is `Testing.Main`) |
| N55 | `Testing/Testing.Configuration.swift` | 35 | `outputFormat` | Nest as `output.format` |
| N56 | `Testing/Testing.Configuration.swift` | 38 | `outputPath` | Nest as `output.path` |

### Scoping methods — `with*` pattern (discussion needed)

These use the standard Swift `with*` scoping idiom (`withUnsafePointer`, `withTaskGroup`, etc). Technically compound under [API-NAME-002] but the `with` prefix is a language-level convention for scope-based execution. Decide: exempt the `with*` pattern, or rename to `with(_:operation:)` where the argument type disambiguates.

| ID | File | Line | Current |
|----|------|------|---------|
| N22 | `Tests Snapshot/Test.Snapshot.Configuration.swift` | 123, 136 | `withConfiguration(_:operation:)` |
| N23 | `Tests Snapshot/Test.Snapshot.Counter.swift` | 109, 122 | `withCounter(_:operation:)` |
| N24 | `Tests Core/Test.Exclusion.Controller.swift` | 38 | `withExclusiveAccess(group:_:)` |
| N25 | `Tests Core/SerialExecutor.swift` | 28, 43 | `withSerialExecutor(operation:)` |

---

## Priority 5 — Private (Non-Static) Compound Methods [API-NAME-002]

[IMPL-024] exempts `private static` methods. These are `private` instance methods or private free functions — not exempted. Lower priority since they don't affect public API, but still violations.

### swift-tests

| ID | File | Line | Current |
|----|------|------|---------|
| N26 | `Tests Snapshot/Test.Snapshot.assert.swift` | 714 | `resultToFailureMessage(_:)` |
| N27 | `Tests Snapshot/Test.Snapshot.assert.swift` | 742, 754 | `makePassingExpectation(...)`, `makeFailingExpectation(...)` |
| N28 | `Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift` | 560, 572 | `makeInlinePassingExpectation(...)`, `makeInlineFailingExpectation(...)` |
| N29 | `Tests Performance/Test.Runner.swift` | 403 | `disabledReason(_:)` |
| N30 | `Tests Performance/Test.Runner.swift` | 422 | `runWithTraits(_:traits:)` |
| N31 | `Tests Performance/Tests.Suite.swift` | 74 | `padRight(_:toLength:)` |
| N32 | `Tests Performance/Reporting.swift` | 103 | `centerText(_:width:)` |

### swift-testing

| ID | File | Line | Current |
|----|------|------|---------|
| N57 | `Testing/Testing.Reporter.JSONSink.swift` | 55 | `buildJSON()` |
| N58 | `Testing/Testing.Reporter.JSONSink.swift` | 68 | `eventToJSON(_:)` |
| N59 | `Testing/Testing.Reporter.JSONSink.swift` | 82 | `writeToFile(path:bytes:)` |
| N60 | `Testing/Testing.Reporter.JSONSink.swift` | 107 | `writeToStdout(bytes:)` |
| N61 | `Testing/Testing.Reporter.Console.swift` | 180 | `consoleStyle(for:)` |
| N62 | `Testing/Testing.Reporter.Console.swift` | 189 | `printIndented(_:indent:)` |

---

## Priority 6 — Implementation Violations [IMPL-*]

### `.rawValue` at call sites [PATTERN-017]

| ID | File | Line | Violation |
|----|------|------|-----------|
| I2 | `swift-tests: Tests Performance/Test.Environment+Capture.swift` | 24 | `optimization.rawValue` — type has `.description` |
| I3 | `swift-tests: Tests Performance/Test.Environment+JSON.swift` | 29 | `value.optimization.rawValue` |
| I4 | `swift-tests: Tests Performance/Tests.Diagnostic+Format.swift` | 111, 180, 190 | `.rawValue` on `Optimization` and `Trend.Interpretation` |
| I16 | `swift-testing: Testing/Testing.Discovery.swift` | 86, 136 | `record.kind == Test.__TestContentKind.test.rawValue` |
| I17 | `swift-testing: Testing Macros Implementation/SuiteMacro.swift` | 87 | `.rawValue` in tuple construction |
| I18 | `swift-testing: Testing Macros Implementation/TestMacro.swift` | 141 | `.rawValue` in tuple construction |

### `Int(...)` / raw conversions at call sites [IMPL-010] / [IMPL-002]

| ID | File | Line | Violation |
|----|------|------|-----------|
| I5 | `swift-tests: Tests Performance/Test.Environment+Capture.swift` | 9-11 | `Int(Kernel.System.Processor.Physical.count)`, `UInt64(Kernel.System.Memory.total)` |
| I6 | `swift-tests: Tests Performance/Test.Environment+JSON.swift` | 26, 66 | `Int(value.memoryBytes)` / `UInt64(memoryBytes)` |
| I7 | `swift-tests: Tests Performance/Tests.Diagnostic+Format.swift` | 108-109 | `Double(environment.memoryBytes) / (1024*1024*1024)` then `Int(memGB.rounded())` |
| I8 | `swift-tests: Tests Core/Test.__TestContentKind.swift` | 34 | FourCC `UInt32(a) << 24 \| ...` |
| I19 | `swift-testing: Testing Umbrella/Testing.AssertMacroExpansion.swift` | 83-84 | `Int(spec.location.line)`, `Int(spec.location.column)` |
| I20 | `swift-testing: Testing/Testing.Discovery.swift` | 98, 147 | `UnsafeRawPointer(bitPattern: 1)!` sentinel |
| I26 | `swift-testing: Testing/Testing.Reporter.JSONSink.swift` | 74-75 | `attoseconds / 1_000_000_000` raw unit conversion |
| I14 | `swift-tests: Tests Performance/Tests.Trend+MannKendall.swift` | 39-49 | `Double(n * (n-1) * (2*n+5))` integer-first then convert |

### Unnecessary intermediate bindings [IMPL-EXPR-001] / [IMPL-030]

| ID | File | Line | Violation |
|----|------|------|-----------|
| I10 | `swift-tests: Tests Performance/Reporting.swift` | 103-110 | `let padding`, `let leftPad`, `let rightPad` — single-use |
| I11 | `swift-tests: Tests Performance/Reporting.swift` | 43-45 | `let minAlloc`, `let maxAlloc`, `let avgAlloc` — single-use |
| I12 | `swift-tests: Tests Performance/Tests.Diagnostic+Format.swift` | 8 | `let m = measurement` — pure rename |
| I21 | `swift-testing: Testing/Testing.Discovery.swift` | 109, 157, 191 | `let reg = boxed.value` — single-use x3 |
| I22 | `swift-testing: Testing/Testing.Discovery.swift` | 96-100, 145-149 | `let success` — single-use, immediately guarded x2 |
| I23 | `swift-testing: ExpectMacro.swift` / `RequireMacro.swift` | 47-52 / 40-45 | Two-branch `let comment` — should be ternary |
| I24 | `swift-testing: Testing.Reporter.Console.swift` | 94, 102 | `let marker` — single-use x2, inline |
| I25 | `swift-testing: Testing.Reporter.Console.swift` | 141-159 | `let passed`, `let failed`, `let issues` — inline; inconsistent with `dimmed()` in same block |

### Other

| ID | File | Line | Rule | Violation |
|----|------|------|------|-----------|
| I1 | `swift-tests: Tests Inline Snapshot/Test.Snapshot.Inline.Rewriter.swift` | 12 | [PATTERN-009] | `import Foundation` — rest of package uses `File_System` |
| I13 | `swift-tests: Tests Snapshot/RFC_8259.Value+TreeKeyed.swift` | 107-112 | [IMPL-INTENT] | Redundant bounds check; two branches with identical effect |

---

## Summary

| Category | swift-tests | swift-testing | Total |
|----------|:-----------:|:-------------:|:-----:|
| [API-NAME-001] compound types | 9 | 17 | **26** |
| [API-NAME-002] compound methods/properties | 23 | 13 | **36** |
| [IMPL-*] implementation | 14 | 12 | **26** |
| **Total** | **46** | **42** | **88** |
