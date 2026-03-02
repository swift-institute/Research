# Witness-Based Trait Extensibility

<!--
---
version: 1.0.0
last_updated: 2026-03-01
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute's `swift-testing` framework currently uses an enum-based trait system defined at the primitives layer (`swift-test-primitives`). Traits are modeled as `Test.Trait`, a struct wrapping `Test.Trait.Kind`, which is a closed enum:

```swift
// swift-test-primitives/Sources/Test Primitives Core/Test.Trait.Kind.swift
public enum Kind: Sendable, Hashable, Codable {
    case timeLimit(Duration)
    case tag(String)
    case enabled(Bool, Test.Text?)
    case bug(String, Test.Text?)
    case serialized
    case custom(String, String?)
}
```

The `.custom(String, String?)` case serves as an escape hatch for extensibility. Two features in the foundations layer (`swift-tests`) use this escape hatch today:

1. **`.exclusive(group:)`** -- encoded as `.custom("__exclusive__", value: group)` in `Test.Trait.Exclusive.swift`
2. **`.timed(iterations:warmup:threshold:metric:)`** -- encoded as `.custom("__timed__", value: config.encode())` in `Test.Trait.Timed.swift`

Both features re-encode structured data into String payloads and then pattern-match on magic string constants (`"__exclusive__"`, `"__timed__"`) at the runner level. This approach has clear limitations:

- **Stringly-typed**: No compile-time safety on trait names or values
- **Closed extensibility**: Third-party consumers cannot add traits with runner behavior (scope wrapping, execution modification)
- **Serialization as workaround**: `Test.Benchmark.Configuration` must implement `encode()`/`decode(from:)` manually to round-trip through a `String?`
- **Fragile dispatch**: The runner's `runWithTraits` method uses hardcoded string comparisons

Apple's `swift-testing` uses a protocol-based trait system (`Trait`, `TestTrait`, `SuiteTrait`, `TestScoping`) that provides open extensibility. The Institute rejected protocols for capability abstraction (see `protocol-witness-effects-capability-abstraction.md`). The question is whether the Institute's own `swift-witnesses` package can provide the same extensibility without protocols.

**Trigger**: The `.custom` escape hatch is already being used for two foundational features. A third use (snapshot configuration) is anticipated. The pattern will not scale.

**Scope**: Ecosystem-wide. The trait system spans two layers (primitives and foundations) and affects every test target.

---

## Question

**Can swift-witnesses replace the current enum-based trait system in Swift Institute's swift-testing, providing open extensibility for traits (anyone can add new traits with runner behavior) without protocol conformance?**

Sub-questions:

1. How does the witness pattern map to trait extensibility?
2. How would trait registration work?
3. How would trait composition work (multiple traits on a test)?
4. How would scope providers work (wrapping test execution)?
5. What are the trade-offs vs the current enum approach?
6. What are the trade-offs vs Apple's protocol approach?

---

## Prior Art Survey

### Apple swift-testing Trait System

Apple's trait system uses four protocols:

| Protocol | Purpose |
|----------|---------|
| `Trait` | Base protocol. `comments`, `isRecursive` |
| `TestTrait: Trait` | Applied to individual `@Test` functions |
| `SuiteTrait: Trait` | Applied to `@Suite` types |
| `TestScoping: Trait` | Wraps test execution -- `provideScope(for:testCase:performing:)` |

Extensibility model: define a struct, conform to `TestTrait`/`SuiteTrait`, optionally conform to `TestScoping` for execution wrapping. The runner dynamically dispatches to `provideScope()`.

Strengths: fully open, type-safe, compositional.
Weaknesses: protocol conformance (global coherence), existential dispatch, associated type collision risk.

### Swift Institute Witness Pattern

The witness pattern (`swift-witnesses`) replaces protocol conformance with struct-of-closures + `Witness.Key` for dependency injection. Core components:

| Type | Purpose |
|------|---------|
| `Witness` (namespace) | Root namespace |
| `Witness.Key` | Type-keyed registration -- `liveValue`/`testValue`/`previewValue` |
| `Witness.Values` | Type-erased heterogeneous container (`ObjectIdentifier` -> value) |
| `Witness.Context` | Task-local scoped overrides via `Witness.Context.with` |
| `@Witness` macro | Generates methods, Action enum, `unimplemented()` from closure properties |
| `Witness.Scope` | `~Copyable` token for linear context consumption |

The key insight: `Witness.Values` uses `ObjectIdentifier` (the metatype identity of the `Witness.Key` conforming type) as the dictionary key, with `UnsafeRawPointer` storage for the value. This gives open extensibility -- anyone can define a new key type and store values without modifying the container.

### Existing Research

- `protocol-witness-effects-capability-abstraction.md` (IN_PROGRESS) -- establishes the theoretical foundation for preferring witnesses over protocols for capability abstraction.
- `comparative-swift-testing-frameworks.md` (IN_PROGRESS) -- compares the two testing frameworks; identifies the trait system as a key architectural divergence.
- `witness-noncopyable-nonescapable-support.md` (RECOMMENDATION) -- analyzes ~Copyable witness values; confirms feasibility.

---

## Analysis

### The Core Mapping

The witness pattern's `Witness.Key` + `Witness.Values` already implements a type-keyed heterogeneous container. A trait system needs exactly the same thing: a way to store arbitrary trait values (each with its own type), look them up by type identity, and compose multiple traits.

The mapping is:

| Trait Concept | Witness Concept |
|---------------|-----------------|
| Trait type definition | `Witness.Key` conforming struct |
| Trait value | The `Value` associated with the key |
| Trait collection | `Witness.Values` container |
| Trait lookup | `values[TraitKey.self]` subscript |
| Default behavior | `liveValue` / `testValue` |
| Scope wrapping | `Witness.Context.with { ... }` |

However, this mapping is not direct -- traits and dependency witnesses have different lifecycle semantics. Traits are declarative metadata attached to tests at definition time, while witnesses are runtime-resolved capabilities. The challenge is bridging these two models.

### Option A: Witness-Backed Traits (Recommended)

Replace `Test.Trait.Kind` enum with a witness-keyed extensible system while preserving the `Test.Trait` value type as the public API.

#### Trait Definition

Each trait capability is defined as a `Witness.Key` conforming struct:

```swift
// In swift-test-primitives (Layer 1) -- core trait keys

/// Marker for whether a trait provides execution scoping.
public struct Test.Trait.Scoping: Sendable {
    /// Called to wrap test execution.
    public var provideScope: @Sendable (
        Test.Plan.Entry,
        @Sendable () async throws(Test.Runner.Error) -> Void
    ) async throws(Test.Runner.Error) -> Void
}

// --- Built-in trait keys ---

/// Time limit trait key.
extension Test.Trait.TimeLimit: Witness.Key {
    public typealias Value = Duration
    public static var liveValue: Duration { .seconds(60) }
    public static var testValue: Duration { .seconds(60) }
}

/// Tag trait key.
extension Test.Trait.Tag: Witness.Key {
    public typealias Value = Set<String>
    public static var liveValue: Set<String> { [] }
    public static var testValue: Set<String> { [] }
}

/// Enabled condition trait key.
extension Test.Trait.Enabled: Witness.Key {
    public typealias Value = Test.Trait.Enabled
    public static var liveValue: Self { .init(isEnabled: true, comment: nil) }
    public static var testValue: Self { .init(isEnabled: true, comment: nil) }
}
```

#### Trait Collection

Replace `[Test.Trait]` with a heterogeneous trait bag:

```swift
extension Test.Trait {
    /// A type-safe, extensible collection of traits.
    ///
    /// Uses Witness.Values internally to store traits keyed by type.
    public struct Collection: Sendable {
        @usableFromInline
        internal var storage: Witness.Values

        public init() {
            self.storage = Witness.Values()
        }

        /// Gets the value for a trait key.
        public subscript<K: Witness.Key>(key: K.Type) -> K.Value
            where K.Value: Copyable {
            get { storage[key] }
            set { storage[key] = newValue }
        }

        /// Sets a trait value (consuming, supports ~Copyable).
        public mutating func set<K: Witness.Key>(
            _ key: K.Type,
            _ value: consuming K.Value
        ) {
            storage.set(key, value)
        }
    }
}
```

#### Third-Party Extensibility

Any package can define new traits:

```swift
// In a hypothetical swift-tests-snapshots package (Layer 3)
extension Test.Trait {
    public struct Snapshot: Sendable {
        public var recording: Test.Snapshot.Recording
        public var directory: String
    }
}

extension Test.Trait.Snapshot: Witness.Key {
    public typealias Value = Test.Trait.Snapshot
    public static var liveValue: Self { .init(recording: .missing, directory: "__Snapshots__") }
    public static var testValue: Self { .init(recording: .missing, directory: "__Snapshots__") }
}
```

#### Scope Provider Registration

For traits that wrap execution (like `.exclusive` or `.timed`), use a registered scope provider list:

```swift
extension Test.Trait {
    /// A scope provider that wraps test execution.
    public struct ScopeProvider: Sendable {
        /// Unique identifier for ordering and deduplication.
        public let id: String

        /// Priority for execution ordering (lower = outer wrapping).
        public let priority: Int

        /// Predicate: should this provider activate for the given traits?
        public var shouldActivate: @Sendable (Test.Trait.Collection) -> Bool

        /// The scope wrapping function.
        public var provideScope: @Sendable (
            Test.Plan.Entry,
            Test.Trait.Collection,
            @Sendable () async throws(Test.Runner.Error) -> Void
        ) async throws(Test.Runner.Error) -> Void
    }
}

extension Test.Trait.ScopeProvider: Witness.Key {
    public typealias Value = [Test.Trait.ScopeProvider]
    public static var liveValue: [Test.Trait.ScopeProvider] { [] }
    public static var testValue: [Test.Trait.ScopeProvider] { [] }
}
```

Registration:

```swift
// In swift-tests (Layer 3) -- register built-in scope providers
extension Test.Trait.ScopeProvider {
    /// Time limit scope provider.
    public static var timeLimit: Self {
        Self(
            id: "timeLimit",
            priority: 100,
            shouldActivate: { traits in
                traits[Test.Trait.TimeLimit.self] != Test.Trait.TimeLimit.liveValue
            },
            provideScope: { entry, traits, operation in
                let limit = traits[Test.Trait.TimeLimit.self]
                try await withTimeout(limit, operation: operation)
            }
        )
    }

    /// Exclusive access scope provider.
    public static var exclusive: Self {
        Self(
            id: "exclusive",
            priority: 200,
            shouldActivate: { traits in
                traits[Test.Trait.Exclusive.self] != nil
            },
            provideScope: { entry, traits, operation in
                let group = traits[Test.Trait.Exclusive.self]!.group
                try await Test.Exclusion.Controller.shared
                    .withExclusiveAccess(group: group, operation)
            }
        )
    }
}
```

#### Runner Integration

The runner composes scope providers automatically:

```swift
// In Test.Runner.runWithTraits
private func runWithTraits(_ entry: Plan.Entry) async throws(Error) {
    let providers = Witness.Context[Test.Trait.ScopeProvider.self]
        .filter { $0.shouldActivate(entry.traits) }
        .sorted { $0.priority < $1.priority }

    // Build the execution chain inside-out
    var chain: @Sendable () async throws(Error) -> Void = {
        try await Witness.Context.withTest(operation: entry.body.run)
    }

    for provider in providers.reversed() {
        let inner = chain
        chain = {
            try await provider.provideScope(entry, entry.traits, inner)
        }
    }

    try await chain()
}
```

#### Migration Path

1. Add `Test.Trait.Collection` alongside existing `[Test.Trait]`
2. Define `Witness.Key` conformances for each `Kind` case
3. Add `Test.Plan.Entry.traitCollection: Test.Trait.Collection` computed from existing `traits: [Test.Trait]`
4. Migrate runner to use `traitCollection` instead of switch-on-kind
5. Deprecate `Test.Trait.Kind` and `.custom` escape hatch
6. Remove `Kind` enum in next major version

### Option B: Direct Enum Extension (No Witnesses)

Keep the enum but add a structured extension point alongside `.custom`:

```swift
public enum Kind: Sendable, Hashable, Codable {
    case timeLimit(Duration)
    case tag(String)
    case enabled(Bool, Test.Text?)
    case bug(String, Test.Text?)
    case serialized
    case custom(String, String?)
    case extended(Test.Trait.Extended)  // New
}

public struct Extended: Sendable, Hashable, Codable {
    public let typeIdentifier: String
    public let data: Data  // Codable payload
}
```

**Assessment**: This is marginally better than `.custom` (structured data instead of raw strings) but still stringly-typed at the type identifier level, does not provide compile-time safety, and requires manual Codable plumbing. It does not solve the fundamental extensibility problem.

### Option C: Protocol-Based Traits (Apple's Approach)

Adopt Apple's `Trait`/`TestTrait`/`SuiteTrait`/`TestScoping` protocol hierarchy.

```swift
public protocol Trait: Sendable { }
public protocol TestTrait: Trait { }
public protocol SuiteTrait: Trait { }
public protocol TestScoping: Trait {
    func provideScope(
        for test: Test.Plan.Entry,
        performing operation: @Sendable () async throws -> Void
    ) async throws
}
```

**Assessment**: Maximally extensible and well-understood. However:

- Violates [API-ERR-001] -- `provideScope` uses untyped `throws`
- Introduces existential dispatch (`any Trait`) for trait storage
- Associated type collision risk per `protocol-witness-effects-capability-abstraction.md`
- Global coherence constraints (SE-0364) -- one conformance per type per process
- Requires `any`-boxing in trait arrays: `[any Trait]`

The Institute explicitly rejected protocol-based capability abstraction. Using protocols for traits while using witnesses for everything else creates an inconsistency.

### Option D: Hybrid -- Witness-Backed with Enum Core

Keep the enum for the closed set of primitives-layer traits but use `Witness.Values` for the foundations-layer extension mechanism:

```swift
// Layer 1: Test.Trait.Kind stays as-is (closed, Codable, Hashable)
// Layer 3: Test.Plan.Entry gains a Witness.Values for trait extensions

extension Test.Plan {
    public struct Entry: Sendable {
        public let id: Test.ID
        public let traits: [Test.Trait]         // Core traits (Layer 1)
        public let extensions: Witness.Values   // Extension traits (Layer 3)
        public let body: Test.Body
    }
}
```

**Assessment**: Preserves backward compatibility. No breaking changes to primitives layer. Extension traits are strongly-typed via `Witness.Key`. However, it creates a split model where some traits are enum cases and others are witness keys, which is conceptually messy and requires the runner to check both sources.

---

## Comparison

| Criterion | A: Witness-Backed | B: Enum Extension | C: Protocol-Based | D: Hybrid |
|-----------|-------------------|-------------------|-------------------|-----------|
| **Open extensibility** | Full (any `Witness.Key`) | Limited (still string-based) | Full (any conformance) | Partial (extensions only) |
| **Type safety** | Full (compile-time) | Partial (runtime decoding) | Full (compile-time) | Split (enum + witnesses) |
| **Scope providers** | Registered via `Witness.Key` | Manual string dispatch | `TestScoping` protocol | Registered via `Witness.Key` |
| **Codability** | Lost (ObjectIdentifier not Codable) | Preserved | Lost (existential) | Preserved for core |
| **Hashability** | Lost (closures) | Preserved | Lost (existential) | Preserved for core |
| **Consistency with ecosystem** | High (uses witnesses throughout) | N/A (enum-specific) | Low (protocols rejected) | Medium (mixed model) |
| **Migration cost** | High (new trait model) | Low (additive case) | High (new trait model) | Medium (additive property) |
| **Third-party UX** | Define struct + `Witness.Key` | Encode to string | Define struct + protocol | Define struct + `Witness.Key` |
| **Runner complexity** | Clean (provider chain) | Fragile (string matching) | Clean (dynamic dispatch) | Split (two dispatch paths) |
| **[API-ERR-001] compliance** | Yes (typed throws) | N/A | No (untyped `throws`) | Yes for extensions |
| **Foundation-free** | Yes | Yes | Yes | Yes |
| **Performance** | Dictionary lookup | Switch + string compare | Existential dispatch | Mixed |

---

## Key Design Considerations

### 1. Codability Loss

The current `Test.Trait.Kind` is `Codable` and `Hashable`. Witness-backed traits lose both properties because `Witness.Values` stores opaque pointers and closures cannot conform to `Codable`.

**Mitigation**: The trait system is used at runtime, not serialized across processes. The `Codable` conformance on `Kind` exists but is not actually used by the runner or reporters. If serialization is needed (e.g., for test plan export), a separate `Test.Trait.Description` value type can capture the string representation.

### 2. Layer Boundary

`Witness.Key` lives in `swift-witnesses` (Layer 3). `Test.Trait` lives in `swift-test-primitives` (Layer 1). The witness-backed trait collection cannot live at Layer 1.

**Resolution**: The extensible trait collection (`Test.Trait.Collection` backed by `Witness.Values`) lives at Layer 3 in `swift-tests`. The primitives layer retains `Test.Trait` as a descriptive value type (for events, serialization, display). The runner at Layer 3 converts `[Test.Trait]` to `Test.Trait.Collection` for execution. This preserves the layering: primitives define the interchange format, foundations define the execution model.

### 3. Scope Provider Ordering

Multiple scope providers may be active for a single test. The execution chain must be deterministic.

**Resolution**: Scope providers declare a `priority: Int`. Lower priority wraps outer (executes first/last). Built-in providers use well-known priorities (100 for timeLimit, 200 for exclusive, 300 for timed). Third-party providers choose priorities relative to built-ins. This is the same pattern as middleware ordering in HTTP frameworks.

### 4. Trait Composition

Multiple traits of the same type need a merge strategy. For example, multiple `.tag("x")` traits should union, while multiple `.timeLimit` traits should take the minimum.

**Resolution**: Each `Witness.Key` defines its merge behavior via its `Value` type. Tags use `Set<String>` (natural union via set insertion). Time limits use `Duration` (the setter can check and take minimum). This is more principled than the current `[Test.Trait]` array where duplicates are resolved by iteration order.

### 5. Default Values

`Witness.Key` requires `liveValue` and `testValue`. For traits, the "live" value is the default (no-op) behavior. A time limit's default is "no limit" (e.g., `.max` or a sentinel). An enabled trait's default is "enabled".

This maps cleanly: `liveValue` = "this trait is not applied" = default/no-op behavior.

---

## Concrete API Sketch

### Defining a Trait (Third-Party)

```swift
// Package: swift-tests-database (Layer 3)
import Tests

/// Trait that provisions a fresh database for each test.
extension Test.Trait {
    public struct Database: Sendable {
        public var schema: String
        public var seed: @Sendable () async throws(Test.Runner.Error) -> Void
        public var teardown: @Sendable () async throws(Test.Runner.Error) -> Void
    }
}

extension Test.Trait.Database: Witness.Key {
    public typealias Value = Test.Trait.Database?
    public static var liveValue: Value { nil }
    public static var testValue: Value { nil }
}

// Scope provider for database provisioning
extension Test.Trait.ScopeProvider {
    public static var database: Self {
        Self(
            id: "database",
            priority: 50,  // Before time limits
            shouldActivate: { $0[Test.Trait.Database.self] != nil },
            provideScope: { entry, traits, operation in
                let db = traits[Test.Trait.Database.self]!
                try await db.seed()
                defer { /* teardown */ }
                try await operation()
            }
        )
    }
}
```

### Using Traits

```swift
@Test(
    .timeLimit(.seconds(30)),
    .tag("integration"),
    .database(schema: "users", seed: { ... })
)
func testUserCreation() async throws { ... }
```

### Registering Scope Providers

```swift
// At app/test entry point:
Witness.Context.with { values in
    values[Test.Trait.ScopeProvider.self] = [
        .timeLimit,
        .exclusive,
        .timed,
        .database,  // Third-party
    ]
} operation: {
    await runner.run(plan)
}
```

---

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option A (Witness-Backed Traits) with the layer boundary design from the analysis.

**Rationale**:

1. **Ecosystem consistency**: The Institute uses witnesses for all capability abstraction. Using an enum with string escape hatches for traits creates an inconsistency that will deepen as more features need the `.custom` pattern.

2. **The `.custom` pattern is already failing**: Two features (`exclusive`, `timed`) are working around the closed enum by encoding structured data as strings. A third (snapshot configuration) is anticipated. The pattern scales linearly in runner complexity (one `if name ==` check per feature) and provides no compile-time safety.

3. **Witness.Values is purpose-built for this**: The `ObjectIdentifier`-keyed heterogeneous container with `UnsafeRawPointer` storage is exactly the data structure needed for an extensible trait bag. No new infrastructure is required.

4. **Scope providers solve the execution wrapping problem**: The registered provider list with priority ordering gives deterministic, composable execution wrapping -- equivalent to Apple's `TestScoping` protocol but without existentials or global coherence constraints.

5. **Layer boundary is clean**: Primitives (Layer 1) keep `Test.Trait` as an inert value type for interchange. Foundations (Layer 3) add `Test.Trait.Collection` backed by `Witness.Values` for execution. This matches the existing primitives/foundations split.

6. **Migration is incremental**: The new system can be introduced alongside the existing `[Test.Trait]` array. The runner can consume both during transition. No breaking changes required until the old system is deprecated.

**Risks**:

- **Codability loss**: Acceptable. The trait system is runtime-only; serialization needs can be met by a separate description type.
- **Complexity**: The scope provider registration model adds a concept (priority-ordered middleware chain) that the current system avoids. However, the current system's string-matching alternative is strictly worse.
- **Witness.Key ceremony**: Each trait requires a `Witness.Key` conformance with `liveValue`/`testValue`. This is more boilerplate than an enum case. The `@Witness` macro can potentially generate this.

**Dependencies**: Requires `swift-witnesses` (Layer 3), which is already a dependency of `swift-tests`.

**Next Steps**:

1. Create an experiment (`swift-institute/Experiments/witness-backed-traits/`) to validate the API sketch compiles and the scope provider chain works correctly.
2. If the experiment confirms, implement `Test.Trait.Collection` in `swift-tests`.
3. Migrate `exclusive` and `timed` from `.custom` string encoding to `Witness.Key`-based traits.
4. Deprecate `.custom` escape hatch.

---

## References

- `swift-witnesses` source: `/Users/coen/Developer/swift-foundations/swift-witnesses/Sources/Witnesses/`
- `swift-test-primitives` trait types: `/Users/coen/Developer/swift-primitives/swift-test-primitives/Sources/Test Primitives Core/Test.Trait.Kind.swift`
- `swift-tests` runner: `/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Core/Test.Runner.swift` (lines 160-223 -- `runWithTraits` method)
- `swift-tests` exclusive trait: `/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Core/Test.Trait.Exclusive.swift`
- `swift-tests` timed trait: `/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Performance/Test.Trait.Timed.swift`
- Related research: `protocol-witness-effects-capability-abstraction.md`, `comparative-swift-testing-frameworks.md`
- Apple swift-testing traits: `swiftlang/swift-testing` -- `Trait.swift`, `TestScoping.swift`
- Point-Free, "Protocol Witnesses" (Episodes 33-36, 2019)
- Wadler & Blott, "How to make ad-hoc polymorphism less ad hoc" (POPL 1989)
