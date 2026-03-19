---
title: "Test Expectation Failure Reporting Bridge"
version: 1.0.0
status: SUPERSEDED
last_updated: 2026-03-03
---

# Test Expectation Failure Reporting Bridge

<!--
---
tier: 2
version: 1.0.0
status: SUPERSEDED
created: 2026-03-03
packages: [swift-tests, swift-testing]
skills: [testing, design, platform]
---
-->

## Abstract

`assertInlineSnapshot` (and all assertion functions in swift-tests that use `Test.Expectation.record(failing:...)`) silently drop failures when tests run under Apple's Swift Testing runner. A second, related problem: the inline snapshot source rewriter never fires under Apple's runner, so recording mode cannot write captured values back to source files. This document analyzes both problems and recommends solutions.

---

## Problem Statement

### Problem 1: Failure Reporting

`Test.Expectation.record(failing:...)` at `Sources/Tests Core/Test.Expectation+Factory.swift:106-114` records failures via a `@TaskLocal` collector:

```swift
Collector.current?.record(result)    // nil under Apple's runner → no-op
```

The collector is only installed by `Test.Runner.execute(...)` at `Sources/Tests Performance/Test.Runner.swift:314-319`. Apple's Swift Testing runner does not instantiate `Test.Runner`, so `Collector.current` is `nil`. The optional chain silently discards the failure. **Every test that uses `assertInlineSnapshot`, `assertSnapshot`, or any assertion built on `record(failing:...)` passes spuriously.**

### Problem 2: Rewriter Lifecycle

The inline snapshot rewriter depends on three components:

1. **State accumulation** — `Test.Snapshot.Inline.state` (process-global singleton at `Sources/Tests Inline Snapshot/Test.Snapshot.Inline.Configuration.swift:19`) collects entries via `register()` during test execution. This works regardless of runner — entries are registered before the failure path.

2. **Rewriter trigger** — Assembled in `swift-testing/Sources/Testing/Testing.Main.swift:115-130`, which appends a closure to `Test.Runner.postRunActions` that calls `state.drain()` → `Rewriter.writeAll()`.

3. **Rewriter execution** — `Test.Runner.run()` at `Sources/Tests Performance/Test.Runner.swift:106-109` iterates `postRunActions` after all tests complete.

Under Apple's Swift Testing runner, steps 2 and 3 never happen. State accumulates but is never drained. Source files are never rewritten. The user gets a failing test (if Problem 1 is fixed) but no automatic source file update — defeating the purpose of recording mode.

### Combined Effect

Without both bridges:

| Scenario | Failure reported? | Source rewritten? | User experience |
|----------|:-:|:-:|---|
| Institute runner | Yes | Yes | Correct |
| Apple runner, no bridge | **No** | **No** | Silent pass, source unchanged |
| Apple runner, failure bridge only | Yes | **No** | Failing test, but no way to auto-fix |
| Apple runner, both bridges | Yes | Yes | Correct |

---

## Root Cause Analysis

Both problems share a root cause: `swift-tests` (Layer 3) was designed around its own `Test.Runner` as the sole execution environment. The integration with Apple's Swift Testing happens in `swift-testing` (a separate Layer 3 package), which depends on `swift-tests` — not the reverse. When `swift-tests` assertions are used directly under Apple's runner (the common case for most consumers), both the collector-based failure reporting and the runner-based rewriter lifecycle are absent.

### Dependency Architecture

```
Apple's Testing (toolchain)    swift-testing (Institute, Layer 3)
         |                            |
         |  ← consumer test targets   |  ← composes Test.Runner + postRunActions
         |    import both             |
         v                            v
                    swift-tests (Layer 3)
                    ├─ Tests Core         (Collector, Expectation, record())
                    ├─ Tests Inline Snapshot (State, Rewriter, assertInlineSnapshot)
                    ├─ Tests Snapshot      (assertSnapshot)
                    └─ Tests Performance   (Test.Runner, postRunActions)
```

`swift-tests` has zero references to Apple's `Testing` module in `Sources/`. Only the `Tests/` test targets import it. This is the correct layering — but it means `swift-tests` cannot directly call `Testing.Issue.record` without an architectural change.

---

## Options Analysis: Failure Reporting Bridge

### Option A: `#if canImport(Testing)` Fallback in `record(failing:...)`

Add conditional compilation in the single funnel point:

```swift
// Test.Expectation+Factory.swift
@discardableResult
public static func record(
    failing message: Swift.String,
    sourceCode: Swift.String,
    at location: Source.Location
) -> Self {
    let result = failing(message, sourceCode: sourceCode, at: location)
    Collector.current?.record(result)
    #if canImport(Testing)
    if Collector.current == nil {
        _bridgeFailureToSwiftTesting(message, at: location)
    }
    #endif
    return result
}
```

With a private bridge function:

```swift
#if canImport(Testing)
import Testing

private func _bridgeFailureToSwiftTesting(
    _ message: Swift.String,
    at location: Source.Location
) {
    Testing.Issue.record(
        Testing.Comment(rawValue: message),
        sourceLocation: Testing.SourceLocation(
            fileID: location.fileID,
            filePath: location.filePath ?? location.fileID,
            line: location.line,
            column: location.column
        )
    )
}
#endif
```

**Analysis**:

- **Automatic**: Zero user configuration. Works the moment `swift-tests` is compiled with a Swift 5.10+ toolchain (which ships Apple's `Testing` module).
- **No double-reporting**: The `Collector.current == nil` guard ensures the bridge only fires when the Institute's runner is absent.
- **Correct scope**: `record(failing:...)` is the single funnel for ALL assertion functions. One bridge point covers `assertInlineSnapshot`, `assertSnapshot`, and any future assertions.
- **Module resolution**: `swift-tests` does not depend on `swift-testing` (Institute). The `#if canImport(Testing)` resolves to Apple's toolchain `Testing` module because SPM only makes declared dependencies visible to each target. No collision.
- **Minimal API surface**: Uses only `Testing.Issue.record(_:sourceLocation:)` and `Testing.SourceLocation` — both stable public API.
- **`@discardableResult` preserved**: The return value is unaffected. The bridge is a side effect only.
- **Conversion**: `Source.Location` → `Testing.SourceLocation` is straightforward. The only wrinkle: `filePath` is optional in `Source.Location`, non-optional in `Testing.SourceLocation`. Falling back to `fileID` is reasonable.

**Risk**: Couples `Tests Core` to Apple's `Testing` at compile time (conditionally). If Apple changes `Issue.record` signatures, `Tests Core` breaks when compiled with that toolchain version. Mitigation: the conditional compilation can be version-gated with `#if swift(>=5.10)` or similar.

### Option B: Static Failure Hook

```swift
extension Test.Expectation {
    public static var externalFailureHandler:
        (@Sendable (Swift.String, Source.Location) -> Void)?
}
```

A bridging module or user code installs the handler. `record(failing:...)` calls it when the collector is nil.

**Analysis**:

- **Fully decoupled**: `Tests Core` has zero knowledge of Apple's `Testing`.
- **Requires explicit installation**: Users must install the handler before tests run. If they forget, failures are still silently dropped — the exact problem we're solving. This makes the failure mode identical to the current bug.
- **Global mutable state**: A `static var` is a process-global mutable. Thread safety requires `Mutex` or `Atomic` wrapper. Not compatible with `@TaskLocal` (which would require per-task installation).
- **Discoverability**: Users must know this hook exists and how to install it. Documentation alone is insufficient for a correctness-critical path.

### Option C: Bridge Module with Swift Testing Trait

New target `Tests Swift Testing Bridge` importing both `Tests Core` and Apple's `Testing`. Provides a `TestScoping` trait that installs a collector and bridges failures:

```swift
// In Tests Swift Testing Bridge module
import Tests_Core
import Testing

struct ExpectationBridge: TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let collector = Test.Expectation.Collector()
        try await Test.Expectation.Collector.$current.withValue(collector) {
            try await function()
        }
        for expectation in collector.drain() where expectation.isFailing {
            Issue.record(Comment(rawValue: expectation.message))
        }
    }
}
```

**Analysis**:

- **Clean separation**: Neither `Tests Core` nor Apple's `Testing` is modified.
- **Requires user action**: Users must apply the trait to every test or suite. If they forget — silent failures.
- **Collector-based**: Re-uses the existing collector pattern, reporting failures after test body completes (not inline). This changes failure timing semantics: under Option A, the `Testing.Issue.record` call happens at the point of failure; under Option C, it happens after the test body returns.
- **New package target**: Increases maintenance surface. Must track changes in both `Tests Core` and Apple's `Testing` APIs.

### Option D: Unconditional `Testing.Issue.record`

Always call `Testing.Issue.record` in addition to the collector, with no guard.

**Analysis**:

- **Double-reporting**: When the Institute's `Test.Runner` is active, failures would be reported to BOTH the collector (Institute path) AND `Testing.Issue.record` (Apple path). If Apple's runner is also active in the process, this produces duplicate failure output.
- **Behavioral assumption**: Relies on `Testing.Issue.record` being benign when no Apple test is active. This is an undocumented implementation detail that could change.
- **Rejected**: Double-reporting is a worse failure mode than the current silent-drop for users of the Institute's runner.

### Evaluation Matrix: Failure Reporting

| Criterion | A (canImport) | B (Hook) | C (Bridge Module) | D (Unconditional) |
|-----------|:---:|:---:|:---:|:---:|
| Automatic (zero config) | **Yes** | No | No | Yes |
| No double-reporting | **Yes** | Yes | Yes | **No** |
| Covers all assertions | **Yes** | Yes | Yes | Yes |
| No coupling to Apple | No | **Yes** | Partial | No |
| Failure at point of origin | **Yes** | Yes | No | Yes |
| Silent-failure-proof | **Yes** | **No** | **No** | Yes |

---

## Options Analysis: Rewriter Lifecycle Bridge

### Option R1: `atexit` Handler

Register an `atexit` handler on first `State.register()` call:

```swift
// Test.Snapshot.Inline.State.swift
extension Test.Snapshot.Inline.State {
    private static let _installExitHandler: Void = {
        atexit {
            let state = Test.Snapshot.Inline.state
            guard !state.isEmpty else { return }
            do {
                try Test.Snapshot.Inline.Rewriter.writeAll(
                    from: state.drain()
                )
            } catch {
                // Error is not typed — atexit is @convention(c)
                // Best effort: print to stderr
            }
        }
    }()

    public func register(_ entry: Entry) {
        _ = Self._installExitHandler   // one-time, lazy
        mutex.withLock { entries in
            entries[entry.filePath, default: []].append(entry)
        }
    }
}
```

**Analysis**:

- **Runner-agnostic**: Fires at process exit regardless of which test runner was used. Works with Apple's runner, the Institute's runner, XCTest, or any future runner.
- **Safely composable with `postRunActions`**: `drain()` is destructive. If the Institute's runner already drained via `postRunActions`, the `atexit` handler sees empty state and does nothing. If no runner drained, `atexit` handles it. They are mutually exclusive by timing.
- **Synchronous**: `Rewriter.writeAll()` is synchronous (`throws(Error)`, not `async`). It reads files, parses with SwiftSyntax, rewrites syntax trees, and writes files atomically. All of this works in an `atexit` context — no structured concurrency or async runtime needed.
- **Lazy registration**: The `atexit` handler is only registered when inline snapshot functionality is actually used (first `register()` call). Non-snapshot tests pay zero cost.
- **Error handling**: `atexit` is `@convention(c) () -> Void` — no typed throws. Errors must be caught and handled non-fatally (e.g., `fputs` to stderr). This matches the current behavior in `Testing.Main.swift` where write failures print a warning.
- **Platform**: `atexit` is C standard library (`<stdlib.h>`), available through `Darwin`/`Glibc`/`WinSDK`. The `Tests Inline Snapshot` module already depends on SwiftSyntax and performs file I/O, so this is not a purity concern.
- **Ordering**: `atexit` handlers execute in LIFO order. The rewriter handler should be one of the last registered (registered lazily on first use, which is during test execution). Other `atexit` handlers (e.g., Swift runtime cleanup) registered earlier in process lifetime run after the rewriter.
- **Runtime lifetime**: Module-level `let` globals (like `Test.Snapshot.Inline.state`) survive until `atexit` handlers complete. SwiftSyntax types are heap-allocated and survive similarly. No use-after-free risk.

### Option R2: Swift Testing `CustomExecutionTrait` per-Suite Wrapper

Provide a custom trait that wraps each suite's execution and triggers the rewriter on suite teardown.

**Analysis**:

- **Wrong granularity**: `CustomExecutionTrait` and `TestScoping` wrap individual tests or suites, not the entire test run. The rewriter must run ONCE after ALL tests complete, not per-test or per-suite. Running the rewriter per-suite would re-parse and re-write files multiple times, and concurrent suites could produce file write races.
- **Cannot solve the problem**: There is no per-run lifecycle hook in Apple's Swift Testing. No `RunTrait` or `RunScoping` protocol exists.
- **Rejected**: Architectural mismatch.

### Option R3: Bridge Module Entry Point Replacement

A bridging module provides a custom entry point (e.g., `TestingBridge.main()`) that wraps `Testing.__swiftPMEntryPoint()` and adds `atexit` registration.

**Analysis**:

- **Requires build system changes**: Users must configure their test target to use the custom entry point instead of the default SwiftPM test runner.
- **Fragile**: Depends on `__swiftPMEntryPoint()` being public and stable. This is an implementation detail.
- **Unnecessary**: If `atexit` (Option R1) works within the module itself, there's no need for an external entry point.
- **Rejected**: Over-engineered, fragile, user-hostile.

### Evaluation Matrix: Rewriter Lifecycle

| Criterion | R1 (atexit) | R2 (Per-suite trait) | R3 (Entry point) |
|-----------|:---:|:---:|:---:|
| Runner-agnostic | **Yes** | No | Partially |
| Correct granularity (per-run) | **Yes** | **No** | Yes |
| Zero user configuration | **Yes** | No | No |
| Composable with postRunActions | **Yes** | N/A | Yes |
| No new dependencies | **Yes** | Needs bridge | Needs bridge |

---

## Recommendation

### Failure Reporting: Option A

**`#if canImport(Testing)` fallback in `record(failing:...)`** with `Collector.current == nil` guard.

Rationale:
1. It is the only option that is both automatic AND silent-failure-proof. Options B and C reintroduce the possibility of silent failures through misconfiguration.
2. The bridge point (`record(failing:...)`) is the single funnel for all assertions. One change, complete coverage.
3. The `Collector.current == nil` guard prevents double-reporting under the Institute's runner.
4. The coupling to Apple's `Testing` is conditional (`#if canImport`) and minimal (one function: `Issue.record`).
5. Failure is reported at the point of origin, preserving source location accuracy.

### Rewriter Lifecycle: Option R1

**`atexit` handler registered lazily on first `State.register()` call.**

Rationale:
1. Runner-agnostic — works with any test runner, current or future.
2. Safely composable with the existing `postRunActions` path via destructive `drain()`.
3. Self-contained within `Tests Inline Snapshot` — no new modules, no user configuration.
4. The rewriter is synchronous, so `atexit` context is fully adequate.
5. Lazy registration ensures zero cost for non-snapshot tests.

### Combined Effect

With both bridges:

| Runner | Collector installed? | Failure reported via | Rewriter triggered via |
|--------|:---:|---|---|
| Institute `Test.Runner` | Yes | Collector → Institute events | `postRunActions` (drains state) |
| Apple Swift Testing | No | `Testing.Issue.record` (bridge) | `atexit` (drains state) |
| Both active | Yes | Collector only (guard skips bridge) | `postRunActions` (atexit sees empty) |
| No runner (direct call) | No | `Testing.Issue.record` (bridge) | `atexit` (drains state) |

---

## Recording Mode Lifecycle Verification

The handoff specifically asks about recording mode (`.missing`). Here is the complete lifecycle under Apple's runner with both bridges:

1. User writes `assertInlineSnapshot(of: value, as: .dump)` — no trailing closure.
2. `_processInlineSnapshot` detects missing expected value (recording mode `.missing`).
3. Entry is registered in `Test.Snapshot.Inline.state` — captures actual value, file path, line/column. **This happens BEFORE the failure path, so state accumulation is independent of the failure bridge.**
4. Returns failure message: `"Automatically recorded inline snapshot. Re-run to assert."`
5. `makeInlineFailingExpectation` calls `record(failing: message, ...)`.
6. `Collector.current` is nil → optional chain is no-op.
7. Bridge detects nil collector → calls `Testing.Issue.record(comment, sourceLocation:)`.
8. Apple's runner reports the failure — test fails visibly. **User sees something happened.**
9. All tests complete. Process begins exit.
10. `atexit` handler fires → `state.drain()` returns accumulated entries.
11. `Rewriter.writeAll()` parses source files, locates call sites, inserts trailing closures with captured values.
12. Source files are updated on disk.
13. Second run: trailing closure now exists, comparison succeeds, test passes.

Every step in the chain works. The critical insight is that state registration (step 3) is unconditional — it does not depend on the collector or the failure bridge. The `atexit` handler (step 10) drains this state regardless of how (or whether) failures were reported.

---

## Implementation Plan

### Phase 1: Failure Reporting Bridge

**File**: `swift-tests/Sources/Tests Core/Test.Expectation+Factory.swift`

1. Add `#if canImport(Testing)` block with `import Testing`.
2. Add private `_bridgeFailureToSwiftTesting(_:at:)` function converting `Source.Location` to `Testing.SourceLocation` and calling `Testing.Issue.record`.
3. In `record(failing:sourceCode:at:)`, after the collector optional chain, add:
   ```swift
   #if canImport(Testing)
   if Collector.current == nil {
       _bridgeFailureToSwiftTesting(message, at: location)
   }
   #endif
   ```

**Scope**: 1 file modified, ~15 lines added.

### Phase 2: Rewriter Lifecycle Bridge

**File**: `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.State.swift`

1. Add lazy `_installExitHandler` static property that registers an `atexit` handler.
2. The handler: guard `!state.isEmpty`, drain, call `Rewriter.writeAll()`, catch errors to stderr.
3. In `register(_ entry:)`, reference `Self._installExitHandler` to trigger one-time registration.

**Scope**: 1 file modified, ~15 lines added.

### Phase 3: Verification

Tests should cover:
- `assertInlineSnapshot` under Apple's runner reports failure (not silent pass).
- `assertInlineSnapshot` in recording mode writes source files under Apple's runner.
- No double-reporting when both runners are active.
- `atexit` handler is benign (no-op) when `postRunActions` already drained.

Note: The existing test targets (`Tests/Tests Tests/`) already import Apple's `Testing` and run under Apple's runner. Any `@Test` function calling `assertInlineSnapshot` will exercise the bridge.

---

## Open Questions

1. **`record(passing:...)` bridge**: The passing path also records to the collector. Apple's Swift Testing tracks passing implicitly — there is no `Testing.Issue.record` equivalent for passing expectations. No bridge needed for passing expectations.

2. **`Test.expect` and `Test.require` macros**: These also use the collector pattern (via different code paths in `Test.expect.swift` and `Test.require.swift`). If they use `record(failing:...)` internally, they get the bridge for free. If they have separate failure paths, those need auditing.

3. **`#if canImport(Testing)` version gating**: Apple's `Testing` module is available since Swift 5.10 (Xcode 16). If `swift-tests` must support Swift 5.9, the conditional should be `#if canImport(Testing) && swift(>=5.10)`. However, `swift-tests` currently requires Swift 6.0+ (per NonisolatedNonsendingByDefault), so this is not a concern.

4. **`atexit` and Swift 6 strict concurrency**: The `atexit` closure captures a reference to the process-global `state` singleton. This is a `Sendable` type (`@unchecked Sendable` via `Mutex`). The closure itself is `@convention(c)`, which has no `Sendable` requirement. No concurrency issues.

5. **Testing.Issue.record thread safety**: `Testing.Issue.record` is documented as safe to call from any context. When called outside of an active test, the behavior is implementation-defined but observed to be benign (no crash, no output). The `Collector.current == nil` guard should prevent this case, but it's worth noting.

6. **Redundancy with Institute runner**: With the `atexit` handler in place, the `postRunActions` closure in `Testing.Main.swift` becomes redundant (both drain and rewrite; `atexit` would handle it if `postRunActions` didn't). The `postRunActions` path can be retained for explicitness and earlier execution timing (during run, not at process exit), or removed to eliminate redundancy. Recommend retaining — `postRunActions` fires earlier, giving the runner opportunity to report write errors through its event system.

---

## Superseded

**Date**: 2026-03-03

Option A (`#if canImport(Testing)` in `Tests Core`) creates a circular dependency
when `swift-tests` and `swift-testing` coexist in the same build graph. The
ecosystem's `Testing` module shadows Apple's toolchain module, causing
`canImport(Testing)` to resolve to the ecosystem's module and forming a cycle:
`Testing → Testing_Core → Tests → Tests_Core → import Testing → Testing`.

The bridge functionality has been moved to a separate, optional target
`Tests Apple Testing Bridge` in `swift-tests`. This target is NOT part of
the `Tests` umbrella product, so it is never in the dependency chain of the
ecosystem's `Testing` module. Consumers who use `swift-tests` directly
(without the ecosystem's `swift-testing`) can depend on this bridge target
to get Apple runner integration.

---

## References

- `swift-tests/Sources/Tests Core/Test.Expectation+Factory.swift:106-114` — `record(failing:...)` funnel point
- `swift-tests/Sources/Tests Core/Test.Expectation.Collector.swift:33` — `@TaskLocal` collector declaration
- `swift-tests/Sources/Tests Performance/Test.Runner.swift:314-319` — collector installation
- `swift-tests/Sources/Tests Performance/Test.Runner.swift:106-109` — `postRunActions` execution
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.Configuration.swift:19` — state singleton
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.State.swift` — state accumulation and drain
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.Rewriter.swift:20-39` — `writeAll(from:)`
- `swift-testing/Sources/Testing/Testing.Main.swift:115-130` — `postRunActions` assembly
- `swift-institute/Research/comparative-swift-testing-frameworks.md` — comparative analysis context
- `swift-institute/Research/witness-based-trait-extensibility.md` — trait system architecture context
- `swift-institute/Research/snapshot-testing-literature-study.md` — snapshot testing formal semantics
