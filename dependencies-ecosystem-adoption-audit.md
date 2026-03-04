# Dependencies Ecosystem Adoption Audit

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: RECOMMENDATION
tier: 1
---
-->

## Context

The Swift Institute provides two packages for dependency injection:

- **swift-dependency-primitives** (Layer 1): Core building blocks — `Dependency.Key`, `Dependency.Values`, `Dependency.Scope` with TaskLocal scoping
- **swift-dependencies** (Layer 3): Full-featured DI — `@Dependency` property wrapper, `withDependencies`, `prepareDependencies`, `Dependency.Context` (mode detection), `Dependency.Key.Strict`, `Dependency.Continuation`, `Dependency.Error`, plus `Clocks Dependency` module

This audit identifies where across the ecosystem ad-hoc patterns can be replaced by the formal dependency injection system.

## Question

Where across the Swift Institute ecosystem are there opportunities to use the dependency injection system instead of ad-hoc solutions?

## Current API Surface

### Layer 1: swift-dependency-primitives

| Type | Purpose |
|------|---------|
| `Dependency` | Namespace enum |
| `Dependency.Key` | Protocol with `liveValue`/`testValue`, `associatedtype Value: Sendable` |
| `Dependency.Values` | Heterogeneous storage keyed by `ObjectIdentifier`, `isTestContext` flag |
| `Dependency.Scope` | TaskLocal-based scoping via `with(_:operation:)` (sync + async + typed throws) |

### Layer 3: swift-dependencies

| Type | Purpose |
|------|---------|
| `@Dependency(\.keyPath)` | Property wrapper for KeyPath-based access |
| `Dependency.Key` | Typealias to `Witness.Key` (extends primitives' Key with `previewValue`) |
| `Dependency.Key.Strict` | Fail-fast keys that `fatalError` if not overridden in tests |
| `Dependency.Values` (`__DependencyValues`) | Wrapper around `Witness.Values` with subscript access |
| `Dependency.Context` | Mode detection (live/test/preview) via environment variables |
| `Dependency.Continuation` | Escaped context for non-structured concurrency |
| `Dependency.Error` | Typealias to `Witness.Unimplemented.Error` |
| `withDependencies` | Free function for scoped overrides (sync + async, with optional mode) |
| `prepareDependencies` | One-time app-wide setup |
| `Clocks Dependency` | Clock dependency key (`\.clock`) with live=Continuous, test=Immediate |

## Findings

### Category 1: Raw @TaskLocal Usage (Evaluated)

These sites use `@TaskLocal` directly for scoped state. Evaluated for `Dependency.Key` migration.

| Package | File | Line | Current Pattern | Verdict | Priority |
|---------|------|------|----------------|---------|----------|
| swift-html-rendering | `Sources/HTML Renderable/HTML.Style.Context.swift` | 62 | `@TaskLocal public static var current: Context = .default` | **KEEP @TaskLocal** — ambient rendering parameter, not an injectable dependency. Context merges as scopes nest (`.dark { .hover { ... } }`). Tests already work via `$current.withValue`. Dependency.Key adds registration boilerplate and a package dependency for zero functional gain. | **N/A** |
| swift-html-rendering | `Sources/HTML Renderable/HTML.Context.Configuration.swift` | 139 | `@TaskLocal public static var current: Self = .default` | **KEEP @TaskLocal** — pure value configuration (indentation, newlines, `forceImportant`). Nothing to mock. `.pretty` and `.email` are preset values, not implementations. `$current.withValue(.pretty) { ... }` is the correct tool. | **N/A** |
| swift-tests | `Sources/Tests Core/Test.Expectation.Collector.swift` | 33 | `@TaskLocal public static var current: Collector?` | Define `Test.Expectation.CollectorKey: Dependency.Key` with `liveValue: nil`, `testValue: nil`, scoped via `Dependency.Scope.with` | **MEDIUM** |

**Rationale for HTML rendering exclusion**: These are scoped rendering parameters — pure value types set for a rendering pass via `$current.withValue`. They are ambient context, not service dependencies. There is nothing to substitute in tests (no mock configurations needed), no centralized resolution benefit, and the existing `@TaskLocal` API is more concise. `Dependency.Key` adds value for injectable services/implementations, not value-type configuration propagation.

### Category 2: Process-Global Singletons (Should Use Dependency.Key for Testability)

These are intentional process-scoped singletons. While they document their global-state rationale (PATTERN REQUIREMENTS §6.6), they are untestable in isolation. Making them dependency keys enables test doubles without affecting the process-global default.

| Package | File | Line | Current Pattern | Proposed Change | Priority |
|---------|------|------|----------------|-----------------|----------|
| swift-io | `Sources/IO Blocking Threads/IO.Blocking.Lane.shared.swift` | 40 | `public static let shared: IO.Blocking.Lane = .threads()` | Define `IO.Blocking.LaneKey: Dependency.Key` with `liveValue: .threads()`, `testValue: .inline` | **MEDIUM** |
| swift-io | `Sources/IO/IO.Lane.swift` | 185 | `public static let shared = Self(IO.Blocking.Lane.shared)` | Define `IO.LaneKey: Dependency.Key` that wraps `IO.Blocking.LaneKey` | **MEDIUM** |
| swift-io | `Sources/IO/IO.Executor.swift` | 43 | `internal static let shared: Kernel.Thread.Executors = ...` | Define internal `IO.ExecutorKey: Dependency.Key` | **LOW** |
| swift-io | `Sources/IO Events/IO.Event.Selector.shared.swift` | 40 | `public static func shared() async throws(Make.Error) -> IO.Event.Selector` | Define `IO.Event.SelectorKey: Dependency.Key` (async initialization complicates this) | **LOW** |
| swift-io | `Sources/IO Completions/IO.Completion.Queue.shared.swift` | 47 | `public static func shared() async throws(...) -> IO.Completion.Queue` | Define `IO.Completion.QueueKey: Dependency.Key` (async init, platform-conditional) | **LOW** |
| swift-io | `Sources/IO Events/IO.Event.Registry.swift` | 17 | `static let shared = IO.Event.Registry([:])` | Define `IO.Event.RegistryKey: Dependency.Key` | **LOW** |
| swift-tests | `Sources/Tests Core/Test.Exclusion.Controller.swift` | 17 | `public static let shared = Controller()` | Define `Test.Exclusion.ControllerKey: Dependency.Key` | **LOW** |
| swift-tests | `Sources/Tests Inline Snapshot/Test.Snapshot.Inline.Configuration.swift` | 19 | `public static let state = State()` | Define `Test.Snapshot.Inline.StateKey: Dependency.Key` | **LOW** |

**Notes on IO singletons**: The IO singletons have async failable initialization (`throws(Make.Error)`). `Dependency.Key.liveValue` is synchronous. Two approaches: (a) wrap in a lazy actor that caches the result (current pattern), then the key returns the actor; or (b) use `prepareDependencies` at app startup to inject a pre-initialized instance. Approach (b) is cleaner but requires the caller to do setup. Priority is LOW because these are genuine process-global resources (kernel handles, thread pools) where per-test instances are expensive.

### Category 3: Already Using Dependency.Key (Validate Correct Usage)

These sites already use `Dependency.Key` and `Dependency.Scope` correctly. Listed for completeness.

| Package | File | Line | Current Pattern | Status |
|---------|------|------|----------------|--------|
| swift-tests | `Sources/Tests Snapshot/Test.Snapshot.Configuration.swift` | 65-68 | `enum Key: Dependency.Key { ... }`, accessed via `Dependency.Scope.current[Key.self]` | **CORRECT** |
| swift-tests | `Sources/Tests Snapshot/Test.Snapshot.Counter.swift` | 66-69 | `enum CounterKey: Dependency.Key { ... }`, scoped via `Dependency.Scope.with` | **CORRECT** |
| swift-tests | `Sources/Tests Snapshot/Test.Snapshot.RecordingTrait.swift` | 46 | Uses `Dependency.Scope.with` for trait scoping | **CORRECT** |
| swift-tests | `Sources/Tests Snapshot/Test.Trait.ScopeProvider.snapshot.swift` | 33 | Uses `Dependency.Scope.with` for scope provider | **CORRECT** |
| swift-tests | `Sources/Tests Performance/Test.Runner.swift` | 430 | `Dependency.Scope.with({ $0.isTestContext = true }, ...)` | **CORRECT** |
| swift-effects | `Sources/Effects/Effect.Context.swift` | 46-154 | Thin wrapper over `Dependency.Scope` | **CORRECT** |
| swift-effects | `Sources/Effects/Effect.perform.swift` | 17 | `Effect.Context.current[E.HandlerKey.self]` | **CORRECT** |
| swift-dependencies | `Sources/Clocks Dependency/Dependency+Clock.swift` | 29-41 | `ClockKey: Dependency.Key` with live/test/preview | **CORRECT** |
| swift-testing | `Sources/Testing/Testing.Main.swift` | 134 | `Witness.Context.with(mode: .test)` for test execution | **CORRECT** |
| swift-testing | `Sources/Testing/Test+withDependencies.swift` | 41-78 | `Test.withDependencies` convenience | **CORRECT** |

### Category 4: Provider Protocols (Candidates for Witness + Dependency.Key)

These protocols exist solely to abstract implementations for swappability (hash providers, random providers, HMAC providers). They are prime candidates for the `@Witness` + `Dependency.Key` pattern.

| Package | File | Line | Current Pattern | Proposed Change | Priority |
|---------|------|------|----------------|-----------------|----------|
| swift-rfc-4122 | `Sources/RFC 4122/RFC_4122.UUID.Generation.swift` | 25-37 | `protocol HashProvider: Sendable { func md5(...); func sha1(...) }` -- passed as generic parameter to `v3`/`v5` | Define as `Dependency.Key` with `liveValue` using a real crypto impl, `testValue` using a deterministic impl; access via `Dependency.Scope.current` instead of parameter passing | **MEDIUM** |
| swift-rfc-4122 | `Sources/RFC 4122/RFC_4122.UUID.Generation.swift` | 231-237 | `protocol RandomProvider: Sendable { func fill(...) }` -- passed as generic parameter to `v4` | Define as `Dependency.Key`; enables `RFC_4122.UUID.v4()` without explicit provider | **MEDIUM** |
| swift-rfc-9562 | `Sources/RFC 9562/RFC_9562.UUID.Generation.swift` | 23-32 | `protocol RandomProvider: Sendable { func fill(...) }` -- passed as generic parameter to `v7` | Define as `Dependency.Key`; enables `RFC_9562.UUID.v7(unixMilliseconds:)` without explicit provider | **MEDIUM** |
| swift-rfc-6238 | `Sources/RFC 6238/RFC 6238.swift` | 296-303 | `protocol HMACProvider { func hmac(...) }` -- passed as parameter | Define as `Dependency.Key` for HMAC provider injection | **MEDIUM** |

**Notes on Layer 2 constraints**: Standards packages (Layer 2) cannot depend on Layer 3 (`swift-dependencies`). They CAN depend on Layer 1 (`swift-dependency-primitives`). However, `Dependency.Key` at Layer 1 only has `liveValue`/`testValue` -- no `previewValue`, no `@Dependency` property wrapper. For these providers, Layer 1's `Dependency.Scope.with` + `Dependency.Scope.current[Key.self]` would work. The existing generic-parameter-passing API should be RETAINED as the primary API; the dependency key approach adds a convenience overload that resolves the provider from context.

### Category 5: Environment Variable Access (Could Use Dependency for Testability)

These sites read environment variables for configuration. While `swift-environment` provides `Environment.withOverlay` for test isolation, the configuration resolution could alternatively be modeled as dependency keys.

| Package | File | Line | Current Pattern | Proposed Change | Priority |
|---------|------|------|----------------|-----------------|----------|
| swift-testing | `Sources/Testing/Testing.Configuration.swift` | 50-83 | `Configuration.fromEnvironment()` reads 5 env vars | Model `Testing.Configuration` as `Dependency.Key` with `liveValue` reading env vars, `testValue` using defaults | **LOW** |
| swift-tests | `Sources/Tests Performance/Tests.Baseline.Recording.swift` | 33-43 | `Recording.fromEnvironment()` reads `SWIFT_BENCHMARK_RECORD` | Model as `Dependency.Key` | **LOW** |
| swift-tests | `Sources/Tests Performance/Tests.Baseline.Storage.swift` | 39-44 | `Storage.root()` reads `SWIFT_BENCHMARK_DIR` | Model baseline root as `Dependency.Key` | **LOW** |
| swift-file-system | `Sources/File System Primitives/File.Path.swift` | 94 | `Environment.read("HOME")` for tilde expansion | Not a candidate -- this is path resolution, not configuration | N/A |
| swift-dependencies | `Sources/Dependencies/Dependency.Context.swift` | 53-64 | `Dependency.Context.detect()` reads env vars for mode | Already well-placed -- this IS the dependency infrastructure | N/A |

**Notes**: These are all LOW priority because `Environment.withOverlay` already provides test isolation for environment reads. The dependency key approach would be slightly more ergonomic (`withDependencies { $0.benchmarkRecording = .all }` vs `Environment.withOverlay(["SWIFT_BENCHMARK_RECORD": "all"])`), but both work.

### Category 6: Global Mutable State (Should Use Dependency.Key for Test Isolation)

| Package | File | Line | Current Pattern | Proposed Change | Priority |
|---------|------|------|----------------|-----------------|----------|
| swift-ieee-754 | `Sources/IEEE 754/IEEE_754.Exceptions.swift` | 193 | `static let sharedState = ExceptionState()` -- process-global Mutex-protected flags | Model as `Dependency.Key` using TaskLocal scoping; `liveValue` uses process-global, `testValue` uses per-test instance | **MEDIUM** |

**Notes**: IEEE 754 exception state is a genuine global-mutable-state concern. The spec (IEEE 754-2019 clause 8) defines exception flags as thread-local state. The current implementation uses a process-global `Mutex`, which is incorrect for concurrent tests. A `Dependency.Key` with per-scope instances would fix the concurrency issue AND match the spec's thread-local semantics. However, this is a Layer 2 package that cannot import Layer 3 -- it can only use `Dependency.Scope` from Layer 1 primitives.

### Category 7: Effect.Context Wrapper (Already Aligned)

The `swift-effects` package (`Effect.Context`) is already a thin wrapper around `Dependency.Scope`. No changes needed.

| Package | File | Status |
|---------|------|--------|
| swift-effects | `Sources/Effects/Effect.Context.swift` | Wraps `Dependency.Scope` -- fully aligned |
| swift-effects | `Sources/Effects/EffectWithHandler.swift` | Uses `Dependency.Key` for handler keys -- fully aligned |
| swift-effect-primitives | `Sources/Effect Primitives/Effect.Context.swift` | Wraps `Dependency.Scope` at primitives layer -- fully aligned |

### Category 8: Decimal.Context (Not a Candidate)

| Package | File | Status |
|---------|------|--------|
| swift-decimals | `Sources/Decimals/Decimal.Context.swift` | Value-type configuration (precision, rounding, exponent bounds). Passed as parameter to arithmetic operations. NOT a dependency -- it is domain data, not an injectable service. | N/A |

### Category 9: Streaming/IO Contexts (Not Candidates)

| Package | File | Status |
|---------|------|--------|
| swift-kernel | `Sources/Kernel/Kernel.File.Write.Streaming.Context.swift` | Holds fd + paths for multi-phase write. This is operation state, not a dependency. | N/A |
| swift-io | `Sources/IO Completions/IO.Completion.Poll.Context.swift` | ~Copyable polling context. Operation state. | N/A |
| swift-io | `Sources/IO Events/IO.Event.Poll.Loop.Context.swift` | ~Copyable event loop context. Operation state. | N/A |
| swift-file-system | `Sources/File System Primitives/File.Directory.Walk.Undecodable.Context.swift` | Error context for directory walking. Domain data. | N/A |

## Summary Statistics

| Priority | Count | Description |
|----------|-------|-------------|
| **HIGH** | 0 | — |
| **MEDIUM** | 7 | IO singletons (2), provider protocols (4), IEEE 754 state (1) |
| **LOW** | 9 | IO subsystem singletons (4), test infrastructure singletons (2), env var configs (3) |
| **N/A** | 12 | Already correct (10 sites), not candidates (5 sites), HTML rendering KEEP @TaskLocal (2), or the dependency system itself |

**Total actionable findings: 16** (7 MEDIUM + 9 LOW)

## Prioritized Action Plan

### Phase 1: MEDIUM Priority (Refactoring Needed)

> **Note**: The original audit incorrectly listed HTML rendering TaskLocals as HIGH priority
> for migration. Category 1 analysis (§ Findings, Category 1) correctly concluded these
> should KEEP @TaskLocal — they are ambient rendering parameters, not injectable dependencies.
> No action needed for `HTML.Context.Configuration` or `HTML.Style.Context`.

1. **IO.Blocking.Lane and IO.Lane singletons**
   - Add `Dependency.Key` conformance alongside existing `.shared` for backward compatibility
   - `testValue` returns `.inline` (non-blocking mock lane)
   - Enables IO testing without spawning kernel threads

2. **Provider protocols -> Dependency.Key convenience overloads**
   - Add zero-parameter convenience methods: `RFC_4122.UUID.v4()`, `RFC_9562.UUID.v7(unixMilliseconds:)`
   - These resolve the provider from `Dependency.Scope.current`
   - Keep existing generic-parameter APIs as the primary interface
   - Requires `swift-dependency-primitives` as a dependency in `swift-rfc-4122`, `swift-rfc-9562`, `swift-rfc-6238`

3. **IEEE 754 exception state scoping**
   - Model `ExceptionState` as `Dependency.Key` at Layer 1 (`Dependency.Scope`)
   - `liveValue` returns process-global instance, `testValue` returns fresh per-scope instance
   - Fixes concurrent test isolation bug

### Phase 2: LOW Priority (Design Discussion Needed)

4. **IO subsystem singletons** (Selector, Completion Queue, Executor, Registry)
   - These have async failable initialization
   - Requires `prepareDependencies` pattern at app startup
   - Significant API surface change -- defer to separate design document

5. **Test infrastructure singletons** (Exclusion Controller, Inline Snapshot State)
   - Test-only infrastructure; benefit is marginal
   - Consider only if testing-the-test-framework becomes a priority

6. **Environment-based configuration** (Testing.Configuration, Baseline.Recording/Storage)
   - Already testable via `Environment.withOverlay`
   - Dependency.Key would be slightly more ergonomic but not essential

## Outcome

**Status**: RECOMMENDATION

The audit found **16 actionable opportunities** across the ecosystem:

1. **7 MEDIUM-priority** items spanning IO testability (2), provider protocol convenience APIs (4), and IEEE 754 correctness (1). The provider protocol items are particularly interesting -- they would allow `RFC_4122.UUID.v4()` to work without explicitly passing a random provider, by resolving it from the dependency context.

2. **9 LOW-priority** items where the current patterns work but could benefit from dependency injection for consistency or marginal testability improvements.

The HTML rendering `@TaskLocal` usages (`HTML.Context.Configuration`, `HTML.Style.Context`) were evaluated and correctly determined to KEEP `@TaskLocal` — they are ambient rendering parameters, not injectable services.

The ecosystem already has **strong adoption** in the right places:
- `swift-tests` snapshot testing uses `Dependency.Key` correctly (3 keys)
- `swift-effects` is a clean wrapper around `Dependency.Scope`
- `swift-testing` uses `withDependencies` and `Witness.Context` for test mode
- The `Clocks Dependency` module provides the canonical example of a dependency key

**Key architectural observation**: Layer 2 (standards) packages can use `swift-dependency-primitives` (Layer 1) but NOT `swift-dependencies` (Layer 3). This means standards packages get `Dependency.Scope.with` and `Dependency.Key` (with `liveValue`/`testValue`) but NOT `@Dependency` property wrapper, `withDependencies` convenience, or mode detection. This is sufficient for the provider protocol convenience overloads proposed in Phase 2.

**Next steps**:
- Design RFC for Phase 1 provider protocol pattern -- determine whether `swift-dependency-primitives` should be added as a dependency to `swift-rfc-4122`, `swift-rfc-9562`, `swift-rfc-6238`
- Separate design document for IO singleton testability (Phase 2)
