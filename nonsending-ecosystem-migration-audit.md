# Nonsending Ecosystem Migration Audit

<!--
---
version: 2.0.0
last_updated: 2026-03-31
status: IN PROGRESS
tier: 2
trigger: nonsending-compiler-patterns.md identified stdlib deprecated isolation: parameter pattern; audit ecosystem for migration candidates
---
-->

## Context

`nonsending-compiler-patterns.md` discovered that the Swift stdlib has deprecated `isolation: isolated (any Actor)? = #isolation` parameter overloads across all concurrency primitives in favor of `nonisolated(nonsending)` on the function itself. This audit systematically examines the entire Swift Institute ecosystem (252 packages across 3 monorepos) to identify all migration candidates and validate existing patterns against the compiler's canonical usage.

## Question

Where does the Swift Institute ecosystem use the deprecated `isolation:` parameter pattern, and what is the full migration surface?

## Analysis

### Ecosystem Health Assessment

| Criterion | Status | Evidence |
|-----------|--------|---------|
| `NonisolatedNonsendingByDefault` enabled | 252/252 packages | Universal adoption |
| `AsyncIteratorProtocol` conformances protected | 7/7 types | All implement `next(isolation:)` per SE-0421 |
| `Clock.sleep()` implementations | 9/9 types | All use `nonisolated(nonsending)` |
| Stdlib bridges provided | 3 functions | `withCheckedContinuation`, `withUnsafeContinuation`, `withTaskCancellationHandler` |
| `@concurrent` usage | 13 files | All genuine executor-boundary crossings (IO layer + test traits) |

The ecosystem is in strong shape. The migration surface is precisely scoped.

### Classification: Migration Surface

**42 total occurrences** across the ecosystem. Each classified as:

| Classification | Count | Action | Status |
|---------------|-------|--------|--------|
| SE-0421 protocol conformance (`next(isolation:)`) | 10 | KEEP — canonical pattern | — |
| Deprecated `isolation:` parameter (Tier 2) | 14 | MIGRATE to `nonisolated(nonsending)` | **COMPLETE** |
| Deprecated `isolation:` + `sending` parameter (Tier 2) | 1 | MIGRATE with care | **COMPLETE** |
| Test fixture with `isolation:` (Tier 2) | 1 | MIGRATE to match production | **COMPLETE** |
| Bare `() async` closure parameter (Tier 3) | 16 | Add explicit `nonisolated(nonsending)` | PENDING |

### Tier 1: SE-0421 Protocol Conformances — KEEP

These implement `AsyncIteratorProtocol.next(isolation:)` per SE-0421. This is the NEW protocol requirement, NOT the deprecated convenience pattern. **No action needed.**

| Type | Package | File |
|------|---------|------|
| `Async.Channel.Unbounded.Receiver.Iterator` | swift-async-primitives | `Async.Channel.Unbounded.Receiver.swift:202` |
| `Async.Channel.Bounded.Receiver.Iterator` | swift-async-primitives | `Async.Channel.Bounded.Receiver.swift:235` |
| `Async.Broadcast.AsyncIterator` | swift-async-primitives | `Async.Broadcast.swift:239` |
| `Async.Map.Iterator` | swift-async (foundations) | `Async.Map.swift:59` |
| `Async.Filter.Iterator` | swift-async (foundations) | `Async.Filter.swift:58` |
| `Async.CompactMap.Iterator` | swift-async (foundations) | `Async.CompactMap.swift:58` |
| `Async.FlatMap.Iterator` | swift-async (foundations) | `Async.FlatMap.swift:63` |
| `Async.Stream.Iterator` | swift-async (foundations) | `Async.Stream.Iterator.swift` |
| `Produce.Iterator` (test fixture) | swift-async (foundations) | `Produce.swift:28` |

Plus 2 `receive(isolation:)` methods that are `next(isolation:)` wrappers:
- `Async.Channel.Unbounded.Receiver.receive` (`:72`)
- `Async.Channel.Bounded.Receiver.receive` (`:69`)

### Tier 2: Migration Candidates — DEPRECATED PATTERN (16) — COMPLETE

These convenience functions used `isolation: isolated (any Actor)? = #isolation` as a parameter. All have been migrated to `nonisolated(nonsending)` with the double-nonsending pattern on closure parameters.

#### Layer 1: Primitives (7 functions)

| Function | File | Signature |
|----------|------|-----------|
| `Async.Callback.callAsFunction` | `Async.Callback.swift:76` | `func callAsFunction(isolation: isolated (any Actor)? = #isolation) async -> Value` |
| `Async.Promise.value` | `Async.Promise.swift:151` | `func value(isolation: isolated (any Actor)? = #isolation) async -> Value` |
| `Async.Promise.wait` | `Async.Promise.swift:238` | `func wait(isolation: isolated (any Actor)? = #isolation) async` |
| `Async.Barrier.arrive` | `Async.Barrier.swift:151` | `func arrive(isolation: isolated (any Actor)? = #isolation) async` |
| `Async.Bridge.next` | `Async.Bridge.swift:166` | `func next(isolation: isolated (any Actor)? = #isolation) async -> Element?` |
| `Async.Channel.Bounded.Sender.send` | `Async.Channel.Bounded.Sender.swift:105` | `func send(_ element: sending Element, isolation: isolated (any Actor)? = #isolation) async throws(...)` |
| `Pool.Bounded.Shutdown.wait` | `Pool.Bounded.Shutdown.swift:188` | `func wait(isolation: isolated (any Actor)? = #isolation) async` |

#### Layer 3: Foundations (8 functions)

| Function | File | Signature |
|----------|------|-----------|
| `withDependencies` (async overload 1) | `withDependencies.swift:93` | `func withDependencies<T, E>(isolation:, _, operation:) async throws(E) -> T` |
| `withDependencies` (async overload 2) | `withDependencies.swift:156` | `func withDependencies<T, E>(isolation:, mode:, _, operation:) async throws(E) -> T` |
| `Test.withDependencies` | `Test+withDependencies.swift:73` | `static func withDependencies<T, E>(isolation:, _, operation:) async throws(E) -> T` |
| `Witness.Preparation.with` | `Witness.Preparation.swift:72` | `static func with<T, E>(isolation:, _, operation:) async throws(E) -> T` |
| `Witness.Context._withScope` | `Witness.Context.swift:218` | `static func _withScope<T, E>(isolation:, mode:, _, operation:) async throws(E) -> T` |
| `Witness.Context.with` (overload 1) | `Witness.Context.swift:292` | `static func with<T, E>(isolation:, _, operation:) async throws(E) -> T` |
| `Witness.Context.with` (overload 2) | `Witness.Context.swift:311` | `static func with<T, E>(isolation:, mode:, _, operation:) async throws(E) -> T` |
| `withWitnesses` | `withWitnesses.swift:66` | `func withWitnesses<T, E>(isolation:, _, operation:) async throws(E) -> T` |

#### Test Infrastructure (1 function)

| Function | File | Signature |
|----------|------|-----------|
| `Dependency.Test.Scope.withOverrides` | `Dependency.Test.Scope.swift:63` | `static func withOverrides<T, E>(isolation:, _, operation:) async throws(E) -> T` |

### Tier 3: Convention 4 Compliance — BARE CLOSURE PARAMETERS (16) — PENDING

These functions take `() async` closure parameters without explicit `nonisolated(nonsending)` annotation on the closure type. Under `NonisolatedNonsendingByDefault` (SE-0461, enabled across all 252 packages), bare closure types are **implicitly** `nonisolated(nonsending)` — so these are functionally correct. The explicit annotation is required by Convention 4 for:

1. **Readability** — documents that isolation inheritance is intended
2. **Consistency** — matches the already-migrated Tier 2 functions
3. **Forward safety** — protects against future feature-flag changes

Unlike Tier 2 (which removed a deprecated parameter — a correctness fix), Tier 3 adds an explicit annotation that matches the implicit default — a consistency fix.

#### Layer 1: Primitives (4 functions)

| Function | Package | File | Closure Type |
|----------|---------|------|-------------|
| `Dependency.Scope.with` | swift-dependency-primitives | `Dependency.Scope.swift:143` | `operation: () async throws(E) -> T` |
| `Effect.Context.with` (throwing) | swift-effect-primitives | `Effect.Context.swift:135` | `operation: () async throws(E) -> T` |
| `Effect.Context.with` (non-throwing) | swift-effect-primitives | `Effect.Context.swift:148` | `operation: () async -> T` |
| `withTaskCancellationHandler` | swift-standard-library-extensions | `withTaskCancellationHandler.swift:19` | `operation: () async throws(E) -> T` |

#### Layer 3: Foundations — Witness infrastructure (7 functions)

| Function | Package | File | Closure Type |
|----------|---------|------|-------------|
| `Witness.Context.withTest` | swift-witnesses | `Witness.Context.swift:371` | `operation: () async throws(E) -> T` |
| `Witness.Context.withPreview` | swift-witnesses | `Witness.Context.swift:389` | `operation: () async throws(E) -> T` |
| `Witness.CapturedContext.withValues` | swift-witnesses | `Witness.CapturedContext.swift:74` | `operation: () async throws(E) -> R` |
| `Witness.Context.Escaped.yield` | swift-witnesses | `Witness.Context.Escaped.swift:76` | `operation: () async throws(E) -> R` |
| `Witness.Scope.run` | swift-witnesses | `Witness.Scope.swift:87` | `operation: () async throws(E) -> R` |
| `Witness.Resolution.Stack.withPushed` | swift-witnesses | `Witness.Resolution.Stack.swift:100` | `operation: () async -> Result<T, ...>` |
| `prepareDependencies` | swift-dependencies | `prepareDependencies.swift:49` | `operation: () async throws(E) -> T` |

#### Layer 3: Foundations — CSS theming (3 functions)

| Function | Package | File | Closure Type |
|----------|---------|------|-------------|
| `DarkModeColor.Theme.withValue` | swift-css | `Color.Theme.swift:327` | `operation: () async throws -> R` |
| `Font.Defaults.withValue` | swift-css | `Font.Theme.swift:252` | `operation: () async throws -> R` |
| `withDependencies` (CSS) | swift-css | `exports.swift:76` | `operation: () async throws -> R` |

#### Layer 3: Foundations — Memory (2 functions)

| Function | Package | File | Closure Type |
|----------|---------|------|-------------|
| `Memory.Allocation.Tracker.measure` | swift-memory | `Memory.Allocation.Tracker.swift:28` | `operation: () async throws(E) -> T` |
| `Memory.Allocation.Profiler.profile` | swift-memory | `Memory.Allocation.Profiler.swift:72` | `operation: () async throws(E) -> T` |

### The Double-Nonsending Pattern

The stdlib's canonical form for operation-taking functions marks **both** the function AND the closure parameter as `nonisolated(nonsending)`:

**Stdlib canonical** (`TaskCancellation.swift:77-79`):
```swift
public nonisolated(nonsending) func withTaskCancellationHandler<Return, Failure>(
    operation: nonisolated(nonsending) () async throws(Failure) -> Return,
    onCancel handler: sending () -> Void
) async throws(Failure) -> Return
```

**Tier 2 migration** (completed): Removed deprecated `isolation:` parameter, added double-nonsending:
```swift
// Before (deprecated pattern):
public func withDependencies<T, E: Error>(
    isolation: isolated (any Actor)? = #isolation,
    _ modify: (inout __DependencyValues) -> Void,
    operation: () async throws(E) -> T
) async throws(E) -> T

// After (migrated):
nonisolated(nonsending)
public func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: nonisolated(nonsending) () async throws(E) -> T
) async throws(E) -> T
```

**Tier 3 migration** (pending): Add explicit annotation to bare closure parameters:
```swift
// Before (implicit nonsending via feature flag):
public static func with<T, E: Error>(
    _ modify: (inout Dependency.Values) -> Void,
    operation: () async throws(E) -> T
) async throws(E) -> T

// After (explicit annotation per Convention 4):
nonisolated(nonsending)
public static func with<T, E: Error>(
    _ modify: (inout Dependency.Values) -> Void,
    operation: nonisolated(nonsending) () async throws(E) -> T
) async throws(E) -> T
```

The `operation` closure is annotated `nonisolated(nonsending)` because:
1. It runs within the caller's isolation domain
2. It should inherit the caller's actor for deterministic execution
3. The `modify` closure is synchronous (no annotation needed)

### Existing Strengths

| Pattern | Count | Assessment |
|---------|-------|------------|
| Clock `nonisolated(nonsending)` sleep | 9 types | Exemplary — both stored closure and method annotated |
| `Async.Callback` stored `nonisolated(nonsending)` closure | 1 type | Exemplary — correct closure-level annotation |
| Stdlib bridges (`withCheckedContinuation` etc.) | 3 functions | Correct — pre-6.4 nonsending overloads |
| `@Sendable` on stream operator closures | 38+ sites | Correct — closures stored in actors require `@Sendable` |
| `@concurrent` on IO executor methods | 13 files | Correct — genuine executor boundary crossings |
| Effect handler witness closures | 5+ types | Correct — `@Sendable` appropriate for cross-isolation handlers |
| `sending` parameters/returns | 2+ types | Correct — `Cache.Storage.withLock`, `Async.Stream.unfold` |

### Non-Candidates

| Pattern | Reason |
|---------|--------|
| `@Sendable` on `Async.Stream.Iterator._next` | Type-erased stream is `Sendable`; closure must be `@Sendable` |
| `@Sendable` on stream operator closures (map, filter, etc.) | Stored in actors; `@Sendable` is correct |
| `@Sendable` on Effect handler closures | Cross-isolation by design |
| `@Sendable` on Pool/Cache creation closures | User-provided, potentially cross-isolation |
| `@Sendable` on test body closures | Concurrent test execution requires `@Sendable` |
| `sending` on continuation return types | Values cross isolation (continuation resumes from arbitrary context) |

## Outcome

**Status**: IN PROGRESS

### Completed Work

**Phase 1: Deprecated `isolation:` parameter removal (16 functions) — COMPLETE**

All functions that used the deprecated `isolation: isolated (any Actor)? = #isolation` parameter have been migrated to `nonisolated(nonsending)` with the double-nonsending pattern on closure parameters.

| Phase | Scope | Functions | Status |
|-------|-------|-----------|--------|
| 1a | Primitives (swift-async-primitives) | 7 | **COMPLETE** |
| 1b | Foundations (swift-dependencies, swift-witnesses, swift-testing) | 8 | **COMPLETE** |
| 1c | Test infrastructure | 1 | **COMPLETE** |

**Phase 2: Validation — COMPLETE**

Validated via build + test that `nonisolated(nonsending)` works correctly for:
1. `callAsFunction()` — `await self()` propagates isolation
2. Double-nonsending pattern — operation closures inherit caller isolation
3. `sending Element` + `nonisolated(nonsending)` — Channel.send works correctly

### Remaining Work

**Phase 3: Convention 4 compliance — bare closure parameters (16 functions) — PENDING**

These functions take `() async` closure parameters without explicit `nonisolated(nonsending)` on the closure type. Under `NonisolatedNonsendingByDefault`, the implicit default is already correct — this is an explicit annotation pass for Convention 4 compliance.

**Phase 3a: Primitives (4 functions)**

| Priority | Function | Package | Risk |
|----------|----------|---------|------|
| 1 | `Dependency.Scope.with` | swift-dependency-primitives | Low — core scoping function, delegates to `TaskLocal.withValue` |
| 2 | `Effect.Context.with` (throwing) | swift-effect-primitives | Low — delegates to `Dependency.Scope.with` |
| 3 | `Effect.Context.with` (non-throwing) | swift-effect-primitives | Low — same delegation |
| 4 | `withTaskCancellationHandler` | swift-standard-library-extensions | Low — stdlib bridge, mirrors stdlib's own double-nonsending |

**Phase 3b: Foundations — Witness infrastructure (7 functions)**

| Priority | Function | Package | Risk |
|----------|----------|---------|------|
| 1 | `Witness.Context.withTest` | swift-witnesses | Low — delegates to `_withScope` (already migrated) |
| 2 | `Witness.Context.withPreview` | swift-witnesses | Low — same delegation |
| 3 | `Witness.CapturedContext.withValues` | swift-witnesses | Low — delegates to `Witness.Context.with` (already migrated) |
| 4 | `Witness.Context.Escaped.yield` | swift-witnesses | Low — delegates to `Witness.Context.with` (already migrated) |
| 5 | `Witness.Scope.run` | swift-witnesses | Low — `consuming func`, delegates to `Witness.Context.with` |
| 6 | `Witness.Resolution.Stack.withPushed` | swift-witnesses | Low — internal resolution machinery |
| 7 | `prepareDependencies` | swift-dependencies | Low — delegates to `Witness.Preparation.with` (already migrated) |

**Phase 3c: Foundations — CSS theming (3 functions)**

| Priority | Function | Package | Risk |
|----------|----------|---------|------|
| 1 | `DarkModeColor.Theme.withValue` | swift-css | Low — `TaskLocal.withValue` wrapper |
| 2 | `Font.Defaults.withValue` | swift-css | Low — same pattern |
| 3 | `withDependencies` (CSS) | swift-css | Low — composes the above two |

**Phase 3d: Foundations — Memory (2 functions)**

| Priority | Function | Package | Risk |
|----------|----------|---------|------|
| 1 | `Memory.Allocation.Tracker.measure` | swift-memory | Low — measurement wrapper |
| 2 | `Memory.Allocation.Profiler.profile` | swift-memory | Low — delegates to `measure` |

### What NOT to Change

- **SE-0421 `next(isolation:)` conformances** — these are the canonical protocol requirement
- **`@Sendable` on actor-stored closures** — required for `Sendable` type safety
- **`@concurrent` on IO executor methods** — genuine executor boundary crossings
- **Effect handler `@Sendable` closures** — cross-isolation by design
- **Test body `@Sendable` closures** — concurrent execution requires it

## References

- `nonsending-compiler-patterns.md` — Compiler source analysis establishing the deprecated pattern
- `callback-isolated-nonsending-design.md` (v3.1) — Async.Callback specific migration note
- `concurrent-expansion-audit.md` — `@concurrent` placement (validated: zero in stdlib)
- `nonsending-adoption-audit.md` — Original @Sendable site inventory
- `modern-concurrency-conventions.md` — Convention 4: double-nonsending pattern requirement
- Swift stdlib `CheckedContinuation.swift:304-332` — Canonical deprecation pattern
- Swift stdlib `TaskCancellation.swift:77-79` — Double-nonsending pattern
