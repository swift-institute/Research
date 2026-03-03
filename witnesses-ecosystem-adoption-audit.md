# Witnesses Ecosystem Adoption Audit

<!--
---
version: 2.0.0
last_updated: 2026-03-03
status: IN PROGRESS
tier: 1
---
-->

## Context

The `swift-witness-primitives` (Layer 1) and `swift-witnesses` (Layer 3) packages provide a canonical witness pattern for the Swift Institute ecosystem: structs with closure properties representing capabilities, paired with macros (`@Witness`), dependency injection (`Witness.Key`, `Witness.Context`), and test infrastructure (`Witness.Unimplemented`, `Witness.Recording`, `Witness.Sequence`, `Witness.Cycle`).

Currently, adoption is limited to the algebra packages (Magma, Semigroup, Monoid, Group, Ring, Semiring, Field, Module, VectorSpace) and Sample.Averaging, which all conform to `Witness.Protocol`. The IO drivers already use the closure-struct pattern but do not conform. Many other packages across the ecosystem use ad-hoc closure-struct patterns, type-erased wrappers, or protocol-based abstractions where witnesses would be more appropriate.

This audit identifies every opportunity to adopt `Witness.Protocol` conformance, `@Witness` macro usage, and `Witness.Key` registration across the entire ecosystem.

## Question

Where across the Swift Institute ecosystem are there opportunities to use the witness pattern instead of ad-hoc solutions?

## Current API Surface

### Primitives Layer (`swift-witness-primitives`)

| Type | Purpose |
|------|---------|
| `Witness` | Namespace enum |
| `Witness.Protocol` | Marker protocol for closure-struct witnesses (`Sendable`) |
| `Witness.Composition` | Enum: `.sequential`, `.racing`, `.fallback` |
| `Witness.DependencyKey` | Typealias to `Dependency.Key` |

### Foundations Layer (`swift-witnesses`)

| Type | Purpose |
|------|---------|
| `Witness.Key` | Protocol for dependency injection key with `liveValue`/`testValue`/`previewValue` |
| `Witness.Key.Test` | Protocol for test-only witnesses (no `liveValue`) |
| `Witness.Values` | Type-safe container keyed by `Witness.Key` type |
| `Witness.Context` | TaskLocal-based dependency injection context |
| `Witness.Context.Mode` | Enum: `.live`, `.preview`, `.test` |
| `Witness.Context.Escaped` | Context capture for escaping closures |
| `Witness.CapturedContext` | Context capture at init time |
| `Witness.Scope` | `~Copyable` move-only scope token |
| `Witness.Resolution` | Namespace for resolution infrastructure |
| `Witness.Resolution.Stack` | TaskLocal cycle detection |
| `Witness.Resolution.Error` | Typed resolution errors |
| `Witness.Resolution.Trace` | Structural trace of resolution path |
| `Witness.Unimplemented` | Namespace for unimplemented witness pattern |
| `Witness.Unimplemented.Error` | Typed error for unimplemented operations |
| `Witness.Recording<Args>` | Thread-safe call recorder for tests |
| `Witness.Sequence<T>` | Sequential value source for mocks |
| `Witness.Cycle<T>` | Cycling value source for mocks |
| `Witness.Access<Key>` | Property wrapper for witness access |
| `Witness.Preparation` | Scoped witness preparation infrastructure |
| `Witness.Preparation.Store` | Thread-safe prepared value store |
| `Witness.Derive` | OptionSet: `.mock`, `.generator` |
| `withWitnesses` | Free function convenience wrapper |
| `@Witness` | Macro: generates methods, Action enum, `unimplemented()`, `observe` |
| `@WitnessScope` | Macro: captures context at init |
| `@WitnessAccessors` | Macro: generates static service accessors |

## Findings

### Category 1: Closure-Struct Types Missing `Witness.Protocol` Conformance

These are structs with closure properties that follow the witness pattern but do not yet conform to `Witness.Protocol`.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-test-primitives | `Sources/Test Snapshot Primitives/Test.Snapshot.Strategy.swift:61` | `struct Strategy<Value, Format>: Sendable` with `var snapshot`, `var syncSnapshot` closures | Add `Witness.Protocol` conformance | HIGH |
| swift-test-primitives | `Sources/Test Snapshot Primitives/Test.Snapshot.Diffing.swift:38` | `struct Diffing<Format>: Sendable` with `var toBytes`, `var fromBytes`, `var diff` closures | Add `Witness.Protocol` conformance | HIGH |
| swift-binary-parser-primitives | `Sources/Binary Coder Primitives/Binary.Coder.swift:41` | `struct Coder<Output>: Sendable` with `var decode`, `var encode` closures | Add `Witness.Protocol` conformance | HIGH |
| swift-predicate-primitives | `Sources/Predicate Primitives/Predicate.swift:27` | `struct Predicate<T>: @unchecked Sendable` with `var evaluate` closure | Add `Witness.Protocol` conformance | HIGH |
| swift-optic-primitives | `Sources/Optic Primitives/Optic.Lens.swift:39` | `struct Lens<Whole, Part>: Sendable` with `let get`, `let set` closures | Add `Witness.Protocol` conformance (change `let` to `var` or add as-is) | HIGH |
| swift-optic-primitives | `Sources/Optic Primitives/Optic.Prism.swift` | `struct Prism<Whole, Part>: Sendable` with `let embed`, `let extract` closures | Add `Witness.Protocol` conformance | HIGH |
| swift-parser-machine-primitives | `Sources/Parser Machine Compile Primitives/Parser.Machine.Compile.Witness.swift:30` | `struct Witness<P>` with `_compile` closure, already named "Witness" | Add `Witness.Protocol` conformance, add `import Witness_Primitives` | HIGH |
| swift-iso-32000 (standards) | `Sources/ISO 32000/ISO_32000.Writer.swift:942` | `struct StreamCompression: Sendable` with `_compress` closure | Add `Witness.Protocol` conformance | MEDIUM |

### Category 2: IO Driver Witnesses Missing Conformance and `@Witness` Macro

These are the most significant witnesses in the ecosystem. They already describe themselves as "protocol witness structs" in their documentation but do not conform to `Witness.Protocol` or use the `@Witness` macro.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-io | `Sources/IO Events/IO.Event.Driver.swift:39` | `struct Driver: Sendable` with 8 closure properties (`_create`, `_register`, `_modify`, `_deregister`, `_arm`, `_poll`, `_close`, `_createWakeupChannel`), manual method forwarding | Add `Witness.Protocol` conformance. Consider `@Witness` macro if `borrowing`/`consuming` parameter support is available; otherwise manual conformance with `Witness.Protocol`. Register as `Witness.Key` with `.kqueue()` / `.epoll()` as platform live values. | HIGH |
| swift-io | `Sources/IO Completions/IO.Completion.Driver.swift:42` | `struct Driver: Sendable` with 6 closure properties (`_create`, `_submitStorage`, `_flush`, `_poll`, `_close`, `_createWakeupChannel`), manual method forwarding | Same as IO.Event.Driver above | HIGH |

**Note**: The `@Witness` macro currently generates methods for closures with labeled parameters using `(_ label: Type)` syntax. The IO drivers use `borrowing` and `consuming` parameter conventions which may not be supported by the macro. Manual `Witness.Protocol` conformance is the safe path; macro support is a follow-up.

### Category 3: Type-Erased Wrappers Replaceable by Witnesses

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-clock-primitives | `Sources/Clock Primitives/Clock.Any.swift:26` | `struct Any<D>: Clock` with `_now`, `_minimumResolution`, `_sleep` closures, plus internal `Box` class hierarchy for type erasure of `Instant` | This is a closure-struct witness for clocks. Add `Witness.Protocol` conformance. The existing test/unimplemented variants (`Clock.Test`, `Clock.Immediate`, `Clock.Unimplemented`) already follow the witness pattern of static factory methods. | MEDIUM |

### Category 4: Test Traits and Scope Providers as Witnesses

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-tests | `Sources/Tests Core/Test.Trait.ScopeProvider.swift:14` | `struct ScopeProvider: Sendable` with `var shouldActivate` and `var provideScope` closures | Add `Witness.Protocol` conformance | MEDIUM |

### Category 5: Effect Handlers as Witnesses

Effect handlers are closure-based structs that follow the witness pattern. They use `Dependency.Key` (which is `Witness.Key`) for injection but the handler structs themselves don't conform to `Witness.Protocol`.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-effects | `Sources/Effects Built-in/Effect.Yield.swift:23` | `struct Handler: __EffectHandler` with `_handle` closure, `Handler.Key: Dependency.Key` | Add `Witness.Protocol` conformance to `Handler` | MEDIUM |
| swift-effects | `Sources/Effects Built-in/Effect.Exit.swift:31` | `struct Handler: __EffectHandler` with `_handle` closure, `Handler.Key: Dependency.Key` | Add `Witness.Protocol` conformance to `Handler` | MEDIUM |

### Category 6: Existing `Witness.Protocol` Conformances Missing `@Witness` Macro

These types already conform to `Witness.Protocol` but do not use the `@Witness` macro, missing out on generated methods, `Action` enum, `observe`, and `unimplemented()`.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-algebra-magma-primitives | `Sources/Algebra Magma Primitives/Algebra.Magma.swift:19` | Manual `Witness.Protocol` conformance, manual `callAsFunction` | Evaluate `@Witness(.generator)` for single-closure types | LOW |
| swift-algebra-magma-primitives | `Sources/Algebra Magma Primitives/Algebra.Semigroup.swift:22` | Same as Magma | Same evaluation | LOW |
| swift-algebra-monoid-primitives | `Sources/Algebra Monoid Primitives/Algebra.Monoid.swift:19` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-monoid-primitives | `Sources/Algebra Monoid Primitives/Algebra.Monoid.Commutative.swift:12` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-group-primitives | `Sources/Algebra Group Primitives/Algebra.Group.swift:23` | Manual conformance with 3 properties | Evaluate `@Witness` | LOW |
| swift-algebra-group-primitives | `Sources/Algebra Group Primitives/Algebra.Group.Abelian.swift:16` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-ring-primitives | `Sources/Algebra Ring Primitives/Algebra.Ring.swift:28` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-ring-primitives | `Sources/Algebra Ring Primitives/Algebra.Ring.Commutative.swift:12` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-semiring-primitives | `Sources/Algebra Semiring Primitives/Algebra.Semiring.swift:19` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-semiring-primitives | `Sources/Algebra Semiring Primitives/Algebra.Semiring.Commutative.swift:12` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-field-primitives | `Sources/Algebra Field Primitives/Algebra.Field.swift:32` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-module-primitives | `Sources/Algebra Module Primitives/Algebra.Module.swift:20` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-algebra-module-primitives | `Sources/Algebra Module Primitives/Algebra.VectorSpace.swift:13` | Manual conformance | Evaluate `@Witness` | LOW |
| swift-sample-primitives | `Sources/Sample Primitives Core/Sample.Averaging.swift:18` | Manual conformance with 5 properties | Evaluate `@Witness` | LOW |

**Note**: The `@Witness` macro adds `Witness.Protocol` conformance automatically, generates `unimplemented()`, `Action` enum, `observe`, and optionally `.mock()`. However, the algebra types use unlabeled closure parameters (`(Element, Element) -> Element`) which means no method generation occurs. The macro benefit for these types is primarily `unimplemented()` generation and `Action` enum. Given these types are `@frozen` and performance-critical, the macro overhead (if any) needs evaluation. This is LOW priority because the current manual conformance is correct.

### Category 7: `Witness.Key` Registration Opportunities

Types that could benefit from `Witness.Key` conformance for dependency injection via `Witness.Context`.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-io | `Sources/IO Events/IO.Event.Driver.swift:39` | Platform factories (`.kqueue()`, `.epoll()`) | Add `Witness.Key` with platform-specific `liveValue`, fake `testValue` | HIGH |
| swift-io | `Sources/IO Completions/IO.Completion.Driver.swift:42` | Platform factories | Add `Witness.Key` with platform-specific `liveValue`, fake `testValue` | HIGH |
| swift-tests | `Sources/Tests Snapshot/Test.Snapshot.Counter.swift:66` | Already `Dependency.Key` (which is `Witness.Key`) | Already adopted | N/A |
| swift-tests | `Sources/Tests Snapshot/Test.Snapshot.Configuration.swift:65` | Already `Dependency.Key` | Already adopted | N/A |
| swift-tests | `Sources/Tests Core/Test.Trait.Key.Timed.swift:13` | Already `Witness.Key` | Already adopted | N/A |
| swift-tests | `Sources/Tests Core/Test.Trait.Key.Exclusive.swift:24` | Already `Witness.Key` | Already adopted | N/A |
| swift-tests | `Sources/Tests Core/Test.Trait.Key.Serialized.swift:13` | Already `Witness.Key` | Already adopted | N/A |
| swift-tests | `Sources/Tests Snapshot/Test.Trait.Key.Snapshot.swift:23` | Already `Witness.Key` | Already adopted | N/A |

### Category 8: File System Callback Witnesses

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-file-system | `Sources/File System Primitives/File.Directory.Walk.Options.swift:23` | `var onUndecodable: @Sendable (Undecodable.Context) -> Undecodable.Policy` embedded in Options struct | This is a single callback within an options struct, not a full witness type. No change recommended - the callback pattern is appropriate for options. | N/A |

### Category 9: Standards Layer Patterns

The standards layer (`swift-standards`) has minimal closure-struct patterns. Most types are pure data or stateful serializers.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-iso-32000 | `Sources/ISO 32000/ISO_32000.Writer.swift:942` | `struct StreamCompression: Sendable` with single `_compress` closure | Add `Witness.Protocol` conformance. This is a capability witness: "I can compress bytes". | MEDIUM |
| swift-rfc-1951 | `Sources/RFC 1951/RFC_1951.LZ77.swift` | Contains closure properties for LZ77 matching strategies | Investigate if these closures form a coherent witness | LOW |

### Category 10: Packages That Should Add `Witness_Primitives` Dependency

Packages that contain closure-struct types but currently do not depend on `swift-witness-primitives`. Adding the dependency enables `Witness.Protocol` conformance.

| Package | Current Tier | Needs Dependency Addition |
|---------|-------------|--------------------------|
| swift-test-primitives | Tier 9 | Yes - for `Test.Snapshot.Strategy`, `Test.Snapshot.Diffing` |
| swift-binary-parser-primitives | Tier 7 | Yes - for `Binary.Coder` |
| swift-predicate-primitives | Tier 2 | Yes - for `Predicate` |
| swift-optic-primitives | Tier 2 | Already has dependency (exports via macro conformance) |
| swift-clock-primitives | Tier 8 | Yes - for `Clock.Any` |
| swift-io (foundations) | Layer 3 | Yes - for `IO.Event.Driver`, `IO.Completion.Driver` |
| swift-effects (foundations) | Layer 3 | Already has via `swift-dependencies` which re-exports |
| swift-tests (foundations) | Layer 3 | Already has via existing `Witness.Key` usage |
| swift-iso-32000 (standards) | Layer 2 | Yes - for `StreamCompression` |

## Summary Statistics

| Priority | Count | Description |
|----------|-------|-------------|
| HIGH | 12 | Direct replacement possible with minimal refactoring |
| MEDIUM | 5 | Requires dependency addition or moderate refactoring |
| LOW | 15 | Design discussion needed (mostly macro adoption for existing conformances) |
| N/A | 7 | Already adopted or not applicable |

### HIGH Priority Breakdown

1. **`Witness.Protocol` conformance** (8 types): `Test.Snapshot.Strategy`, `Test.Snapshot.Diffing`, `Binary.Coder`, `Predicate`, `Optic.Lens`, `Optic.Prism`, `Parser.Machine.Compile.Witness`, `IO.Event.Driver`, `IO.Completion.Driver`
2. **`Witness.Key` registration** (2 types): `IO.Event.Driver`, `IO.Completion.Driver` (enables test fakes via `Witness.Context` instead of manual injection)

### What Is NOT a Candidate

The following patterns were investigated but are NOT candidates:

- **Enum-based strategies** (e.g., `Format.Numeric.DecimalSeparatorStrategy`, `Format.Numeric.SignDisplayStrategy`): These are simple enums without closures. Not witnesses.
- **Stateful serializers** (e.g., `W3C_XML.Encode`, `RFC_9112.HTTP.Message.Serializer`): These are imperative encoders with internal state, not capability abstractions.
- **Data types with stored closures in options** (e.g., `File.Directory.Walk.Options.onUndecodable`): Single callbacks embedded in configuration structs are not full witness types.
- **Pure data types** (e.g., `Async.Lifecycle.State`, `Async.Bridge`): Stateful types without closure-based abstraction boundaries.
- **`Effect.Protocol` types** (e.g., `Cache.Compute`, `Cache.Evict`, `Pool.Acquire`, `Pool.Release`, `Parser.Backtrack`): These are effect descriptors, not capability witnesses. They have associated types but no closure properties.
- **`Comparison.Protocol`**: This is a Swift protocol for ordering, not a closure-struct witness.
- **Test harnesses** (e.g., `Kernel.Thread.Test.Harness`): Concrete test utilities, not abstract capabilities.

## Outcome

**Status**: IN PROGRESS — Macro improvements complete, ecosystem adoption in progress.

### Part 1: Macro Improvements — COMPLETE (2026-03-03)

All five macro improvements implemented and verified (100 tests pass):
- 1a: `let` closure properties
- 1b: `_` prefix stripping for method/action names
- 1c: `firstName` label support
- 1d: Skip init when struct already has one
- 1e: Non-closure stored properties in init/unimplemented/mock/observe

### Part 2: Ecosystem Adoption — IN PROGRESS

#### Phase A: Simple `Witness.Protocol` Conformances (Primitives)

Each requires: (1) `Package.swift` dependency on `swift-witness-primitives`, (2) `import Witness_Primitives`, (3) `extension Type: Witness.Protocol {}`.

| Package | Type | Dep needed | Status |
|---|---|---|---|
| swift-optic-primitives | `Optic.Lens`, `Optic.Prism` | Yes (no deps currently) | PENDING |
| swift-clock-primitives | `Clock.Any` | Yes | PENDING |
| swift-predicate-primitives | `Predicate` | Yes | PENDING |
| swift-binary-parser-primitives | `Binary.Coder` | Yes (to `Binary Coder Primitives` target) | PENDING |
| swift-test-primitives | `Test.Snapshot.Strategy`, `Test.Snapshot.Diffing` | Yes (to `Test Snapshot Primitives` target) | PENDING |
| swift-parser-machine-primitives | `Parser.Machine.Compile.Witness` | BLOCKED: not `Sendable` | DEFERRED |

**Note on `Parser.Machine.Compile.Witness`**: This type and its `_compile` closure are not
`@Sendable`. Adding `Sendable` + `@Sendable` is a prerequisite but may break downstream.
Deferred pending Sendable audit.

#### Phase B: Simple `Witness.Protocol` Conformances (Standards/Foundations)

| Package | Type | Dep needed | Status |
|---|---|---|---|
| swift-iso-32000 | `ISO_32000.StreamCompression` | Yes | PENDING |
| swift-tests | `Test.Trait.ScopeProvider` | No (already has `swift-witnesses`) | PENDING |
| swift-effects | `Effect.Yield.Handler`, `Effect.Exit.Handler` | Yes (has `Dependency Primitives`, needs `Witness Primitives`) | PENDING |

#### Phase C: `@Witness` Macro Adoption (IO Drivers)

| Package | Type | Change | Status |
|---|---|---|---|
| swift-io | `IO.Event.Driver` | `@Witness` macro, remove manual forwarding | PENDING |
| swift-io | `IO.Completion.Driver` | `@Witness` macro, remove manual forwarding | PENDING |

### Deferred

| Item | Reason |
|---|---|
| `@Witness` macro for algebra types | LOW priority — `@frozen`, performance-critical, no labels |
| `Parser.Machine.Compile.Witness` | Not `Sendable`; requires Sendable audit first |

### Macro Improvements Completed (2026-03-03)

The `@Witness` macro has been enhanced with the following capabilities:

| Improvement | Status | Description |
|---|---|---|
| `borrowing`/`consuming`/`inout` parameters | DONE (prior session) | Full ownership convention support |
| Accept `let` closure properties | DONE | Macro now processes both `var` and `let` closure bindings |
| Strip `_` prefix from method names | DONE | `let _create` generates method `create()`, Action case `.create` |
| `firstName` label support | DONE | Defensive handling of firstName-only parameters in closure types |
| Skip init when struct has one | DONE | Detects existing `InitializerDeclSyntax` and skips generation |
| Non-closure stored properties | DONE | `generatePublicInit`, `unimplemented()`, `mock()`, and `observe` all handle non-closure stored properties |

**Remaining limitation**: `@frozen` attribute preservation is not supported. Algebra types (Category 6) remain LOW priority.

### Lateral Dependency Rule (Corrected)

Foundations MAY depend on other foundations packages. Primitives MAY depend on other primitives.
But primitives MAY NOT depend on foundations. Therefore:
- `swift-io` (Layer 3) CAN depend on `swift-witnesses` (Layer 3) — lateral OK within same layer
- `Witness.Key` registration for IO drivers is NOT blocked

### Tier Corrections

| Package | Audit v1.0 Tier | Actual Tier | Notes |
|---|---|---|---|
| swift-optic-primitives | "already has dependency" | Tier 0 | Does NOT have dependency; needs addition |
| swift-clock-primitives | Tier 8 | Tier 0 | Was mis-categorized |
| swift-test-primitives | Tier 9 | Tier 20 | Actual tier per primitives manifest |
| swift-binary-parser-primitives | Tier 7 | Tier 20 | Actual tier per primitives manifest |
| swift-parser-machine-primitives | — | Tier 20 | Was unlisted |
