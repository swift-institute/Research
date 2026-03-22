# Nonsending Ecosystem Migration Audit

<!--
---
version: 1.0.0
last_updated: 2026-03-22
status: RECOMMENDATION
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

### Classification: `isolation:` Parameter Usage

**26 total occurrences** across the ecosystem. Each classified as:

| Classification | Count | Action |
|---------------|-------|--------|
| SE-0421 protocol conformance (`next(isolation:)`) | 10 | KEEP — canonical pattern |
| Convenience function (deprecated pattern) | 14 | MIGRATE to `nonisolated(nonsending)` |
| Convenience function with `sending` parameter | 1 | MIGRATE with care |
| Test fixture | 1 | MIGRATE to match production |

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

### Tier 2: Migration Candidates — DEPRECATED PATTERN (14)

These are convenience functions that use `isolation: isolated (any Actor)? = #isolation` as a parameter when the function could instead be `nonisolated(nonsending)`.

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

### The Double-Nonsending Pattern

8 of the 14 migration candidates follow the `withTaskCancellationHandler` pattern: a function that takes an `operation` closure. The stdlib's canonical form marks **both** the function AND the closure as `nonisolated(nonsending)`:

**Stdlib canonical** (`TaskCancellation.swift:77-79`):
```swift
public nonisolated(nonsending) func withTaskCancellationHandler<Return, Failure>(
    operation: nonisolated(nonsending) () async throws(Failure) -> Return,
    onCancel handler: sending () -> Void
) async throws(Failure) -> Return
```

**Our current pattern** (e.g., `withDependencies`):
```swift
public func withDependencies<T, E: Error>(
    isolation: isolated (any Actor)? = #isolation,
    _ modify: (inout __DependencyValues) -> Void,
    operation: () async throws(E) -> T
) async throws(E) -> T
```

**Proposed migration**:
```swift
public nonisolated(nonsending) func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: nonisolated(nonsending) () async throws(E) -> T
) async throws(E) -> T
```

The `operation` closure should also be `nonisolated(nonsending)` because:
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

**Status**: RECOMMENDATION

### Migration Plan

**Phase 1: Primitives (7 functions)**

Low risk — we control all consumers. Clean break (no deprecation shim needed).

| Priority | Function | Complexity |
|----------|----------|------------|
| 1 | `Async.Callback.callAsFunction` | Low — experiment required to validate `await self()` still works |
| 2 | `Async.Promise.value` | Low — direct suspension, no composition |
| 3 | `Async.Promise.wait` | Low — void return, simplest case |
| 4 | `Async.Barrier.arrive` | Low — void return |
| 5 | `Async.Bridge.next` | Medium — implements `AsyncIteratorProtocol.next` indirectly |
| 6 | `Async.Channel.Bounded.Sender.send` | Medium — has `sending Element` parameter, needs validation |
| 7 | `Pool.Bounded.Shutdown.wait` | Low — void return |

**Phase 2: Foundations — Witness/Dependency infrastructure (8 functions)**

These share the double-nonsending pattern. Should be migrated together.

| Priority | Function | Complexity |
|----------|----------|------------|
| 1 | `withWitnesses` | Medium — public free function, double-nonsending pattern |
| 2 | `Witness.Context.with` (2 overloads) | Medium — same pattern |
| 3 | `Witness.Context._withScope` | Low — internal API |
| 4 | `Witness.Preparation.with` | Medium — same pattern |
| 5 | `withDependencies` (2 overloads) | Medium — same pattern |
| 6 | `Test.withDependencies` | Low — test support |
| 7 | `Dependency.Test.Scope.withOverrides` | Low — test helper |

**Phase 3: Validation**

Before production migration, create an experiment validating:
1. `nonisolated(nonsending)` on `callAsFunction()` — does `await self()` in `map`/`flatMap` still propagate isolation?
2. Double-nonsending pattern on `withWitnesses` — does `operation` closure inherit caller isolation?
3. `sending Element` parameter with `nonisolated(nonsending)` function — does `Channel.send` work correctly?

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
- Swift stdlib `CheckedContinuation.swift:304-332` — Canonical deprecation pattern
- Swift stdlib `TaskCancellation.swift:77-79` — Double-nonsending pattern
