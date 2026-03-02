# Comparative Analysis: Apple swift-testing vs Swift Institute swift-testing

<!--
---
version: 1.0.0
last_updated: 2026-03-01
status: IN_PROGRESS
tier: 3
---
-->

## Context

The Swift Institute ecosystem maintains its own testing framework at `swift-foundations/swift-testing`, while Apple provides the canonical `swift-testing` framework at `swiftlang/swift-testing`. Both share the same macro surface (`@Test`, `@Suite`, `#expect`, `#require`) but diverge significantly in architecture, layering, error handling discipline, and capability scope.

Understanding the precise relationship — where the Institute framework extends, constrains, or reimplements Apple's design — is critical for:

1. **Semantic commitment**: The Institute framework establishes testing conventions that all 61+ primitives, standards, and foundations packages depend on.
2. **Precedent risk**: Design decisions here propagate to every test target in the ecosystem.
3. **Interoperability**: Users may encounter both frameworks; behavioral differences must be documented.
4. **Long-term maintainability**: Maintaining a parallel framework requires clear justification for each divergence.

**Trigger**: Proactive discovery per [RES-012] — the Institute's swift-testing has matured to the point where a systematic comparison against Apple's canonical implementation is warranted.

**Scope**: Ecosystem-wide (Tier 3 per [RES-020]). This analysis establishes normative guidance for the testing layer.

---

## Question

What are the architectural, semantic, and API-level differences between Apple's `swift-testing` and the Swift Institute's `swift-testing`, and which divergences are justified by the Institute's design principles?

Sub-questions:
1. How do the module architectures compare?
2. Where does the Institute framework extend Apple's capabilities?
3. Where does it constrain or restrict?
4. What are the error handling differences and their implications?
5. How do discovery mechanisms compare?
6. What capabilities exist in one but not the other?
7. Are there soundness or safety differences?

---

## Prior Art Survey

### Swift Evolution & Forums

| Proposal | Relevance |
|----------|-----------|
| [SE-0382](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0382-expression-macros.md) | Expression macros — foundation for `#expect`, `#require` |
| [SE-0389](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md) | Attached macros — foundation for `@Test`, `@Suite` |
| [SE-0390](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) | Noncopyable types — affects test assertions on `~Copyable` values |
| [SE-0413](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) | Typed throws — Institute requires; Apple does not enforce |
| [SE-0414](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md) | Region-based isolation — affects test parallelism |
| [SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring.md) | `sending` — affects test body closures |
| [SE-0450](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-trait-based-dependencies.md) | Trait-gated targets — Institute's cross-package integration strategy |
| [swift-testing vision](https://github.com/swiftlang/swift-testing/blob/main/Documentation/Vision.md) | Canonical design intent |
| [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) | Generic type suite discovery failure — motivates workarounds |

### Related Language Testing Frameworks

| Framework | Language | Key Design |
|-----------|----------|------------|
| `#[test]` / `#[cfg(test)]` | Rust | Attribute macro, in-module tests, `cargo test` runner |
| HUnit / Tasty | Haskell | Composable test trees, typed test assertions |
| OUnit / Alcotest | OCaml | Functor-based test suites, typed expectations |
| JUnit 5 | Java | `@Test`, `@ParameterizedTest`, extension model, lifecycle callbacks |
| pytest | Python | Decorator-based, fixtures, parametrize, plugin architecture |
| Catch2 | C++ | `TEST_CASE`, `SECTION`, `REQUIRE`, expression decomposition |

### Theoretical Foundations

Testing frameworks encode a theory of **test specification** and **test execution**. The relevant formalisms are:

1. **Algebraic specification testing** (Goguen & Meseguer, 1982): Tests as ground equations in an initial algebra.
2. **Property-based testing** (Claessen & Hughes, 2000): QuickCheck's approach — generators, shrinking, universally quantified properties.
3. **Parametericity and free theorems** (Wadler, 1989): Polymorphic test properties that hold by construction.
4. **Effect handlers for testing** (Plotkin & Pretnar, 2009; Bauer & Pretnar, 2015): Algebraic effects as a model for dependency injection in tests.
5. **Substructural type systems** (Walker, 2005): Linear/affine types constraining test resource management (`~Copyable`).

---

## Systematic Literature Review

### Research Questions

| ID | Question |
|----|----------|
| RQ1 | What architectural patterns exist for layered testing frameworks? |
| RQ2 | How do typed error systems affect testing framework design? |
| RQ3 | What approaches exist for testing move-only/linear types? |
| RQ4 | How do snapshot testing systems integrate with test runners? |
| RQ5 | What models exist for dependency injection in test contexts? |

### Search Strategy

- **Databases**: ACM DL, arXiv, Swift Forums, GitHub repositories
- **Keywords**: "testing framework architecture", "typed throws testing", "noncopyable testing", "snapshot testing design", "effect handler testing"
- **Inclusion criteria**: Peer-reviewed or production-deployed; addresses typed/safe testing; post-2015
- **Exclusion criteria**: Non-typed languages; unit testing tutorials; framework-specific migration guides

### Key Findings

**RQ1 (Layered architecture)**: Production testing frameworks (JUnit 5, Tasty, pytest) separate discovery, planning, execution, and reporting into distinct phases. JUnit 5's `TestEngine` SPI mirrors the Institute's three-layer split (primitives → standards → foundations). No surveyed framework achieves the Institute's degree of layered decomposition.

**RQ2 (Typed errors)**: Apple's swift-testing erases error types to `any Error` throughout. The Institute enforces typed throws per [API-ERR-001]. This is novel — no surveyed testing framework in any language enforces typed error propagation in the test runner. Haskell's Tasty uses `IO ()` (untyped effect). Rust's `#[test]` uses `Result<(), Box<dyn Error>>` (erased).

**RQ3 (Move-only testing)**: Rust's testing framework handles `!Copy` types natively through ownership. No other surveyed framework addresses this. The Institute's patterns (test via observable properties, borrowing assertions, consume-at-end) are documented in `testing-conventions.md` and are comparable to Rust's approach.

**RQ4 (Snapshot testing)**: Point-Free's `swift-snapshot-testing` (Haskell `sydtest` lineage) established the `Strategy<Value, Format>` pattern. The Institute integrates this directly into the test runner via `#expectSnapshot` macro and `Test.Snapshot.Configuration`. Apple's framework has no built-in snapshot testing.

**RQ5 (Dependency injection)**: The Institute's witness/dependency injection (`Witness.Context.with(mode: .test)`, `Test.withDependencies`) follows the algebraic effects model. Tests run in a `test` mode where all `@Dependency` values resolve to their test variants. Apple's framework has no dependency injection system.

---

## Analysis

### Dimension 1: Module Architecture

#### Apple's Architecture (Monolithic)

```
swift-testing (single repo, single library)
├── Testing (main library)
│   ├── Core types: Test, Trait, Event, Issue, Runner, Configuration
│   ├── Macros: @Test, @Suite, #expect, #require
│   ├── Discovery: section-based + legacy type metadata
│   ├── Attachments: Attachable, AttachableAsImage
│   ├── Exit tests: ExitTest (~Copyable)
│   └── Reporting: ConsoleOutputRecorder, JUnitXMLRecorder
├── TestingMacros (compiler plugin)
├── _TestDiscovery (static lib)
├── _TestingInternals (C++ support)
└── Platform overlays: Foundation, CoreGraphics, UIKit, AppKit, WinSDK
```

**Characteristics**:
- Single library product (`Testing`)
- Vertical integration: all concerns in one module
- Platform overlays via cross-import
- C++ interop via `_TestingInternals` (backtrace, process spawning)
- Swift tools version: 6.2
- Minimum deployment: macOS 14+, iOS 17+
- Dependencies: swift-syntax only

#### Institute's Architecture (Layered)

```
Layer 1: swift-test-primitives (Primitives)
├── Test Primitives         → Test.ID, Test.Trait, Test.Event, Test.Text
├── Test Snapshot Primitives → Test.Snapshot.Strategy, Recording, Diffing

Layer 2: swift-tests (Standards)
├── Tests Core             → Test.Runner, Test.Plan, Test.Registry (~Copyable)
├── Tests Performance      → Test.Runner execution engine
├── Tests Snapshot          → Test.Snapshot.assert()

Layer 3: swift-testing (Foundations)
├── Testing Umbrella       → Macros (@Test, @Suite, #Tests, #expect, #require, #expectSnapshot)
├── Testing Core           → Discovery, Configuration, Reporter, Main entry
├── Testing Effects        → Effect handler testing (spy, handler)
└── Testing Test Support   → Test infrastructure helpers
```

**Characteristics**:
- Four library products (`Testing`, `Testing Core`, `Testing Effects`, `Testing Test Support`)
- Three-layer decomposition across three repositories
- Each layer independently consumable
- No Foundation dependency
- Swift tools version: 6.2
- Minimum deployment: macOS 26+, iOS 26+
- Dependencies: swift-syntax + 8 internal packages

#### Comparison

| Criterion | Apple | Institute |
|-----------|-------|-----------|
| Module count | 1 library + 4 internal | 4 libraries across 3 layers |
| Layer independence | No separation | Full: primitives → standards → foundations |
| Minimum consumption | All of `Testing` | `Test Primitives` only (for types) |
| Foundation dependency | Optional (overlay) | Forbidden ([PRIM-FOUND-001]) |
| C/C++ interop | Yes (_TestingInternals, C++20) | No (pure Swift via swift-kernel) |
| Swift version floor | Swift 6.0+ | Swift 6.2+ |
| Platform floor | macOS 14+ | macOS 26+ |
| Macro plugin | TestingMacros | Testing Macros Implementation |

**Assessment**: The Institute's layered architecture enables consuming test data types (IDs, traits, events) without pulling in the runner or macros. This is essential for packages like `swift-tests` (the runner itself) that need test types but cannot depend on the macro layer. Apple's monolithic design makes this impossible. **Justified divergence.**

---

### Dimension 2: Macro System

#### Shared Surface

Both frameworks declare equivalent macros:

| Macro | Apple | Institute | Equivalent? |
|-------|-------|-----------|-------------|
| `@Test` | `@attached(peer)` | `@attached(peer, names: prefixed(__swift_test_accessor_), prefixed(__swift_test_record_))` | Functionally equivalent |
| `@Suite` | `@attached(peer)` | `@attached(member, names: prefixed(__swift_suite_factory_))` + `@attached(memberAttribute)` | Functionally equivalent |
| `#expect` | `@freestanding(expression)` | `@freestanding(expression)` | Functionally equivalent |
| `#require` | `@freestanding(expression)` | `@freestanding(expression)` (2 overloads: Bool, Optional) | Functionally equivalent |

#### Institute-Only Macros

| Macro | Purpose | Apple Equivalent |
|-------|---------|-----------------|
| `#Tests` | `@freestanding(declaration)` — generates `Test.Unit`, `.EdgeCase`, `.Integration`, `.Performance`, `.Snapshot` suites | None |
| `#expectSnapshot` | `@freestanding(expression)` — snapshot assertion | None |

#### Expansion Differences

**Apple's `@Test` expansion** generates:
- A generic accessor function with `@_section` annotation
- Uses `__TestContentRecord` directly from compiler support
- Expression decomposition in `#expect`/`#require` captures subexpressions

**Institute's `@Test` expansion** generates:
- `__swift_test_accessor_<N>`: `@convention(c)` accessor returning boxed `Test.Registration`
- `__swift_test_record_<N>`: Section record with magic bytes `0x74657374` ('test')
- Section annotation: `@_section("__DATA_CONST,__swift5_tests")` on Darwin
- Registration boxed in `Test.Box<T>` (backed by `Ownership.Shared`)

**Key Difference**: The Institute uses `Test.Box` (shared ownership primitive) for passing registrations through C-convention accessors, while Apple uses `Allocated<_Properties>` (indirect storage). The Institute's approach reuses existing infrastructure (`Ownership.Shared` from swift-ownership-primitives).

**Assessment**: The `#Tests` macro is a significant Institute extension that codifies the four-category test suite structure. The `#expectSnapshot` macro integrates snapshot testing at the language level. Both are **justified extensions** that encode Institute conventions into the macro system.

---

### Dimension 3: Type System & Safety

#### Error Handling

| Aspect | Apple | Institute |
|--------|-------|-----------|
| `#require` throws | `ExpectationFailedError` (untyped) | `Test.Requirement.Failed` (typed) |
| Runner error propagation | `any Error` throughout | Typed throws per [API-ERR-001] |
| Issue error capture | `indirect case errorCaught(_ error: any Error)` | Typed error wrapping in `Test.Body.Error.caught(type:description:)` |
| Configuration errors | Untyped | Typed |

**Apple's approach**: Error types are existential (`any Error`) at every boundary. This provides maximum flexibility but loses compile-time error type information.

**Institute's approach**: All throwing functions use typed throws. `Test.Body` wraps typed errors into a unified `Test.Body.Error` enum, preserving type names as strings for diagnostics while maintaining typed throw signatures.

**Formal characterization**:

Let `τ_err` denote the error type parameter. Apple's system is:
```
throw : ∀α. α → ⊥    where α : any Error
```

The Institute's system is:
```
throw : E → ⊥    where E : Error, E is statically known
```

The Institute's approach is strictly more informative — it preserves the error type at every call site, enabling exhaustive `catch` patterns. The trade-off is reduced flexibility when composing heterogeneous error sources.

**Assessment**: **Justified constraint.** Typed throws aligns with [API-ERR-001] and provides strictly more information to the compiler and developer. The `Test.Body.Error` wrapper handles the composition problem at the runner boundary.

#### Memory Safety

| Aspect | Apple | Institute |
|--------|-------|-----------|
| `strictMemorySafety()` | Enabled (MemorySafeTestingTests target) | Enabled (all targets) |
| `~Copyable` usage | `ExitTest`, `Attachment<T>` | `Test.Plan.Registry` |
| `Sendable` enforcement | All public types | All public types |
| `NonisolatedNonsendingByDefault` | Not enabled | Enabled |
| Unsafe access | Via `_TestingInternals` (C++) | Via swift-kernel abstractions |

**Notable**: The Institute marks `Test.Plan.Registry` as `~Copyable`, ensuring each registry produces exactly one plan via `consuming func finalize() -> Test.Plan`. This is a substructural type discipline that prevents accidental test registration duplication — a category of bug that Apple's framework does not prevent at the type level.

**Assessment**: The Institute's `~Copyable` registry is a **novel safety contribution**. Apple's `Attachment<T>` is also `~Copyable` (preventing accidental attachment duplication), but Apple does not apply this discipline to the registry/plan pipeline.

#### Naming Conventions

| Aspect | Apple | Institute |
|--------|-------|-----------|
| Type naming | Flat: `Test`, `Runner`, `Configuration` | Nested: `Test.Runner`, `Testing.Configuration`, `Testing.Discovery` |
| Compound names | `ConditionTrait`, `ParallelizationTrait`, `HumanReadableOutputRecorder` | None ([API-NAME-002] prohibition) |
| Namespace structure | `Runner.Plan.Step.Action` (partial nesting) | Full [API-NAME-001] compliance |
| File naming | `ConditionTrait.swift`, `Runner.Plan.swift` | `Testing.Configuration.swift`, `Testing.Discovery.swift` |
| SPI markers | `@_spi(ForToolsIntegrationOnly)`, `@_spi(Experimental)` | None (clean public/internal boundary) |

**Assessment**: The Institute's naming strictly follows [API-NAME-001] and [API-NAME-002]. Apple uses compound identifiers (e.g., `ConditionTrait`, `ParallelizationTrait`) that the Institute's conventions prohibit. **Justified divergence** per established naming rules.

---

### Dimension 4: Capabilities Comparison

#### Apple-Only Capabilities

| Capability | Description | Institute Status |
|------------|-------------|------------------|
| **Exit tests** | `#expect(processExitsWith:)` — spawn child process, verify exit status | Not implemented |
| **Attachments** | `Attachment<T: Attachable>` — attach files/images to test results | Not implemented |
| **Image attachments** | Platform overlays for UIImage, NSImage, CGImage, CIImage, WinSDK | Not implemented |
| **Parameterized tests** | `@Test(arguments: collection)` — run test for each argument | Not implemented |
| **Known issues** | `withKnownIssue { }` — mark expected failures | Not implemented |
| **Confirmations** | `confirmation(expectedCount:) { confirm in }` — verify event counts | Not implemented |
| **Bug tracking** | `.bug(url:)` trait — link tests to bug reports | Not implemented |
| **Time limits** | `.timeLimit(.minutes(1))` — per-test timeout | Not implemented (runner handles) |
| **Expression decomposition** | `#expect(a == b)` captures subexpressions on failure | Not implemented (simple bool check) |
| **JUnit XML output** | CI-compatible XML reporting | Not implemented |
| **XCTest interop** | `xcTestCompatibleSelector` — bridge to Objective-C | Not applicable |
| **Backtrace symbolication** | Stack trace capture and symbol resolution | Not implemented |
| **Repetition policy** | Run tests multiple times until/while failure | Not implemented |
| **Broad platform support** | macOS 14+, iOS 17+, Embedded Swift, WASI, Linux, Windows, FreeBSD | macOS 26+ only |

#### Institute-Only Capabilities

| Capability | Description | Apple Status |
|------------|-------------|--------------|
| **Snapshot testing** | `#expectSnapshot(value, as: .lines)` — integrated snapshot assertions with recording modes | Not built-in |
| **`#Tests` macro** | Generates standardized 5-category test suite structure | Not available |
| **Dependency injection** | `Test.withDependencies { }` — witness-based DI with test mode | Not available |
| **Effects testing** | `Test.spy(for:)`, `Test.handler(for:)` — algebraic effect mocking | Not available |
| **Witness context** | `Witness.Context.with(mode: .test)` — global test/live mode switching | Not available |
| **Mutual exclusion groups** | `.exclusive(group:)` — named exclusion groups per test suite | Limited (`.serialized` only) |
| **Layered consumption** | Use `Test Primitives` without pulling runner or macros | Not possible |
| **`~Copyable` registry** | `Test.Plan.Registry` prevents accidental plan duplication | Not enforced |

#### Shared Capabilities

| Capability | Both Provide |
|------------|-------------|
| `@Test` / `@Suite` macros | Test and suite declaration |
| `#expect` / `#require` | Non-fatal / fatal assertions |
| Section-based discovery | `__swift5_tests` binary section enumeration |
| Symbol-based fallback | dlsym-based discovery for older toolchains |
| Trait system | Configurable test behavior |
| Console reporting | Human-readable test output |
| JSON reporting | Machine-readable event stream |
| Serial execution | `.serialized` trait |
| Tag-based filtering | Environment variable filtering |
| Test planning | Registry → Plan → Execution pipeline |

---

### Dimension 5: Discovery Architecture

Both frameworks use the same low-level mechanism:

```
@_section("__DATA_CONST,__swift5_tests")   // Darwin
@_section("swift5_tests")                   // Linux
@_section(".sw5test$B")                     // Windows
```

**Apple's implementation**:
- Dual-mode: New `TestContentRecord` system + legacy type metadata scanning
- Both run in parallel via task groups
- Deduplication via `Set<Test>`
- Discovery is internal to `Testing` module

**Institute's implementation**:
- Primary: `Loader.Section.all(.swiftTestContent)` — uses `swift-loader` abstraction
- Fallback: `Loader.Symbol.lookup(name:in:)` — dlsym-based
- Strategy: section-based first → dlsym only if section returns empty
- Discovery exposed as `Testing.Discovery` public API
- Registration boxed in `Test.Box<T>` (shared ownership)

**Key Difference**: The Institute abstracts section enumeration through `swift-loader` (a foundations-layer package that wraps Darwin/Linux/Windows section APIs), while Apple uses direct platform calls through `_TestingInternals` (C++). The Institute's approach avoids C++ interop entirely.

**Assessment**: Functionally equivalent discovery. The Institute's `swift-loader` abstraction is consistent with the no-C++ design principle. **Neither approach is superior** — they achieve identical results through different platform abstraction strategies.

---

### Dimension 6: Trait System

#### Apple's Trait Protocol Hierarchy

```swift
protocol Trait: Sendable {
    func prepare(for test: Test) async throws
    var comments: [Comment] { get }
    associatedtype TestScopeProvider: TestScoping = Never
    func scopeProvider(for: Test, testCase: Test.Case?) -> TestScopeProvider?
}

protocol TestScoping: Sendable {
    func provideScope(for: Test, testCase: Test.Case?,
                      performing: @Sendable () async throws -> Void) async throws
}

protocol TestTrait: Trait {}
protocol SuiteTrait: Trait { var isRecursive: Bool { get } }
```

**Design**: Traits are protocols with an associated type for scope providers. Scope providers wrap test execution (middleware pattern). Traits compose through nested async closures, outermost-first.

**Built-in traits**: `ConditionTrait`, `ParallelizationTrait`, `Tag`, `Bug`, `TimeLimitTrait`, `HiddenTrait`, `IssueHandlingTrait`, `AttachmentSavingTrait`.

#### Institute's Trait System

```swift
public struct Test.Trait: Sendable {
    public enum Kind: Sendable {
        case tag(String)
        case enabled(Bool)
        case disabled
        case serialized
        case exclusive(group: String?)
        case timeLimit(Duration)
        case timed(...)
        case custom(String, value: String?)
    }
}
```

**Design**: Traits are a value type with an enum kind — not a protocol hierarchy. This is a fundamentally different design choice:

| Aspect | Apple (Protocol-based) | Institute (Enum-based) |
|--------|----------------------|----------------------|
| Extensibility | Open (anyone can add traits) | Closed (fixed enum cases + `.custom`) |
| Type safety | Associated types enforce scope provider contracts | Pattern matching enforces handling |
| Composition | Async closure nesting | Sequential trait application |
| Custom traits | Implement `Trait` protocol | Use `.custom(name, value:)` case |
| Scope providers | `TestScoping` protocol | Not supported (execution wrapping handled by runner) |

**Assessment**: Apple's protocol-based traits are more extensible but more complex. The Institute's enum-based traits are simpler and exhaustively checkable but limited to predefined kinds plus a generic `.custom` escape hatch. The Institute's approach trades extensibility for exhaustiveness — consistent with the "timeless infrastructure" philosophy where the trait vocabulary is intentionally finite. **Justified design choice** given different goals (ecosystem framework vs. general-purpose framework).

---

### Dimension 7: Runner Architecture

#### Apple's Runner

```swift
public struct Runner: Sendable {
    public var plan: Plan
    public var configuration: Configuration

    public func run() async
}
```

**Execution model**:
1. Plan construction: Graph-based (`Graph<String, Step?>`) with synthesized suites
2. Action propagation: `.skip`/`.recordIssue` recursive; `.run` non-recursive
3. Parallelization: Bounded parallelization width (default: 2× CPU cores)
4. Trait scoping: Nested async closures, outermost-first
5. Event posting: Task-local `Configuration.current` for event routing
6. Repetition: Configurable iteration with continuation conditions

**State management**: Task-local `Configuration.current` provides ambient access to event handlers and settings. `Mutex<Bool>` tracks whether issues were recorded per test.

#### Institute's Runner

```swift
public struct Runner: Sendable {
    public let reporter: Reporter

    public func run(_ plan: Plan, concurrency: Concurrency) async -> Result
}
```

**Execution model**:
1. Plan construction: Linear registry → `consuming finalize()` → plan
2. Entry evaluation: Sequential trait checking (enabled, exclusive, serialized, timed)
3. Concurrency: `.automatic`, `.serial`, `.limited(N)` enum
4. Dependency scope: `Witness.Context.with(mode: .test)` wraps entire run
5. Exclusion: Trait-based with named groups (per-type + global)
6. Result: Typed `Result` with pass/fail/skip counts

**State management**: Runner is pure — takes a plan and reporter, returns a result. No task-local ambient state for configuration.

**Comparison**:

| Aspect | Apple | Institute |
|--------|-------|-----------|
| Plan structure | Graph-based hierarchy | Linear entry list |
| Suite synthesis | Runtime synthesis for missing hierarchy nodes | Macro-generated at compile time |
| Parallelization | Width-bounded with shuffle | Concurrency enum |
| State model | Task-local ambient configuration | Pure function (plan → result) |
| Repetition | Built-in iteration policy | Not supported |
| Trait scoping | Middleware closure nesting | Direct trait interpretation |
| Return type | `Void` (events communicate results) | `Result` struct |

**Assessment**: Apple's graph-based plan with runtime suite synthesis is more sophisticated but also more complex. The Institute's linear plan with compile-time suite generation (via `#Tests` macro) is simpler and more predictable. The Institute's pure-function runner (no ambient state) is architecturally cleaner. **Both approaches are valid** for their respective scopes; the Institute's approach is better suited to a controlled ecosystem where the macro generates the hierarchy structure.

---

### Dimension 8: Reporting System

| Aspect | Apple | Institute |
|--------|-------|-----------|
| Console output | `ConsoleOutputRecorder`, `HumanReadableOutputRecorder`, `AdvancedConsoleOutputRecorder` | `ConsoleSink` |
| JSON output | Built-in serialization via ABI types | `JSONSink` (Foundation-free) |
| JUnit XML | `JUnitXMLRecorder` | Not supported |
| Symbols | `✓`, `✗`, `○` (+ SF Symbols on macOS) | `✓`, `✗`, `○` |
| ANSI colors | Configurable bit depth (4-bit, 8-bit, 24-bit) | Basic support |
| Event protocol | `Event.Handler = @Sendable (borrowing Event, borrowing Context) -> Void` | `Test.Reporter.SinkImplementation` protocol |
| Event granularity | 17 event kinds (including `iterationStarted`, `planStepStarted`, `testCaseCancelled`) | Fewer event kinds |

**Assessment**: Apple has significantly richer reporting infrastructure. The Institute's reporting is functional but minimal. JUnit XML support would be valuable for CI integration. **Gap identified.**

---

## Formal Semantics

### Test Specification Language

We define a minimal formal language for test specifications to precisely characterize the differences.

#### Syntax

```
TestSpec := Suite | Test
Suite    := suite(id, traits, children: [TestSpec])
Test     := test(id, traits, body: Body)
Body     := sync(() throws(E) -> Void) | async(() async throws(E) -> Void)
Trait    := tag(s) | enabled(b) | serialized | exclusive(g) | timed(c) | custom(k,v)
```

#### Typing Rules

**Apple's error discipline** (untyped):

```
Γ ⊢ body : () throws -> Void
────────────────────────────────
Γ ⊢ test(id, traits, body) : Test
```

Errors are existentially quantified at the test boundary:

```
Γ ⊢ e : E where E : Error
──────────────────────────────────
Γ ⊢ throw e : ⊥   (erased to any Error)
```

**Institute's error discipline** (typed):

```
Γ ⊢ body : () throws(E) -> Void    E : Error
──────────────────────────────────────────────
Γ ⊢ test(id, traits, body) : Test<E>
```

At the runner boundary, typed errors are wrapped:

```
Γ ⊢ body : () throws(E) -> Void
Γ ⊢ wrap : E -> Test.Body.Error
────────────────────────────────────────────────
Γ ⊢ Test.Body.sync(body) : Test.Body   (throws(Test.Body.Error))
```

This preserves type information as runtime strings while unifying the error type for the runner:

```
Test.Body.Error.caught(type: String(describing: E.self), description: String(describing: e))
```

#### Operational Semantics

**Plan finalization** (Institute's `~Copyable` registry):

```
registry : Registry (~Copyable)
──────────────────────────────────────
consume(registry.finalize()) : Plan

registry : Registry (~Copyable)    finalize(registry) already called
──────────────────────────────────────────────────────────────────────
use(registry) : ⊥   (compile error: value consumed)
```

This guarantees at the type level that each registry produces exactly one plan. Apple's `Runner.Plan` can be freely copied, which does not cause bugs in practice but provides weaker formal guarantees.

**Discovery** (section enumeration):

```
∀ section ∈ Loader.Section.all(.swiftTestContent):
  ∀ record ∈ parse(section.buffer):
    record.kind = 0x74657374 ⟹
      accessor = record.accessor
      box = accessor() : Unmanaged<Test.Box<Registration>>
      registration = box.takeRetainedValue().value
      registry.add(registration.id, registration.traits, registration.body)
```

Both frameworks implement this identically — the formal semantics of discovery are shared.

#### Soundness Properties

**Property 1 (Registration uniqueness)**: Under the Institute's `~Copyable` registry, each registration is added to exactly one plan. Under Apple's approach, this is a runtime invariant (enforced by calling convention) rather than a compile-time guarantee.

**Property 2 (Error information preservation)**: Under the Institute's typed throws, the error type is known at each call site. Under Apple's erased approach, error type information is lost at the `any Error` boundary and must be recovered via runtime reflection (`type(of: error)`).

**Property 3 (Exhaustive trait handling)**: Under the Institute's enum-based traits, the compiler enforces exhaustive `switch` over all trait kinds. Under Apple's protocol-based traits, new trait conformances cannot be exhaustively checked.

---

## Empirical Validation (Cognitive Dimensions Framework)

Assessment of both frameworks against Nielsen's Cognitive Dimensions of Notations (Green & Petre, 1996):

| Dimension | Apple | Institute | Winner |
|-----------|-------|-----------|--------|
| **Visibility** | Event handler provides all runtime state; `@_spi` hides internals | Reporter + pure Result; clean public/internal boundary | Institute (cleaner boundaries) |
| **Consistency** | Mixed naming (`ConditionTrait` vs `Test.Case`) | Uniform [API-NAME-001] throughout | Institute |
| **Viscosity** | Adding new trait = new protocol conformance (low ceremony) | Adding new trait = enum case + runner handling (higher ceremony) | Apple (more extensible) |
| **Role-expressiveness** | Test/Suite distinction clear; traits are opaque | Test/Suite/Snapshot categories explicit; traits are transparent enums | Institute (more explicit) |
| **Error-proneness** | `any Error` allows unintended type erasure; registry copyable | Typed throws catch errors at compile time; `~Copyable` registry prevents duplication | Institute (safer) |
| **Abstraction** | `TestScoping` enables arbitrary middleware | Fixed execution model; no middleware hooks | Apple (more abstract) |
| **Hidden dependencies** | Task-local `Configuration.current` is ambient | Pure function runner; explicit dependency injection | Institute (fewer hidden deps) |
| **Progressive evaluation** | Can run individual test functions | `#Tests` generates full suite hierarchy | Apple (more incremental) |

**Summary**: The Institute framework scores higher on safety, consistency, and explicitness. Apple's framework scores higher on extensibility, abstraction, and progressive evaluation. These trade-offs align with their respective design goals: the Institute prioritizes correctness and convention enforcement; Apple prioritizes flexibility and broad adoption.

---

## Capability Gap Analysis

### Critical Gaps (Institute lacks, high value)

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| **Expression decomposition** | `#expect(a == b)` cannot show `a` and `b` values on failure | HIGH — implement expression capture in `ExpectMacro` |
| **Parameterized tests** | No `@Test(arguments:)` support | HIGH — reduces test boilerplate significantly |
| **Broad platform support** | macOS 26+ only vs macOS 14+ | MEDIUM — limits adoption but acceptable for Institute's ecosystem |
| **JUnit XML output** | No CI integration format | MEDIUM — add `JUnitXMLSink` to reporter system |

### Moderate Gaps (Apple lacks, Institute provides)

| Gap | Impact | Status |
|-----|--------|--------|
| **Snapshot testing** | Apple has no built-in snapshot testing | Institute provides integrated `#expectSnapshot` |
| **Dependency injection** | Apple has no DI system | Institute provides `Test.withDependencies` + witness mode |
| **Effects testing** | Apple has no effect mocking | Institute provides `Test.spy`/`Test.handler` |
| **Suite categories** | Apple does not prescribe test categories | Institute's `#Tests` generates 5 standard categories |
| **Layered consumption** | Apple cannot provide test types without runner | Institute's primitives layer enables this |

### Low-Priority Gaps

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| Exit tests | Niche usage; platform-restricted even in Apple | DEFER |
| Attachments | File/image attachment to test results | DEFER |
| Known issues | `withKnownIssue { }` for expected failures | DEFER (can use `.enabled(false)` + comment) |
| Confirmations | Event count verification | DEFER |
| Repetition policy | Flaky test retry | DEFER |

---

## Outcome

**Status**: IN_PROGRESS

### Key Findings

1. **The Institute's swift-testing is not a fork or wrapper** — it is a clean-room reimplementation with shared macro surface (`@Test`, `@Suite`, `#expect`, `#require`) and shared discovery mechanism (section-based), but independent architecture.

2. **Layered decomposition is the primary architectural innovation** — the three-layer split (primitives → standards → foundations) enables consuming test types independently of the runner, which is impossible in Apple's monolithic design.

3. **Typed throws and `~Copyable` registry are novel safety contributions** — no other surveyed testing framework in any language enforces typed error propagation or uses substructural types to prevent registration duplication.

4. **The Institute framework extends Apple's capability set** with snapshot testing, dependency injection, effects testing, and standardized suite categories.

5. **The Institute framework has significant gaps** in expression decomposition, parameterized tests, and reporting richness that should be addressed.

6. **Design divergences are justified** — every difference traces to either [API-ERR-001] (typed throws), [API-NAME-001] (naming), [PRIM-FOUND-001] (no Foundation), or the five-layer architecture.

### Recommendations

1. **Expression decomposition** (Priority: HIGH): Implement subexpression capture in `ExpectMacro` to show operand values on failure. This is the most impactful usability gap.

2. **Parameterized tests** (Priority: HIGH): Add `@Test(arguments:)` support for collection-driven test generation.

3. **JUnit XML reporter** (Priority: MEDIUM): Add `JUnitXMLSink` for CI integration.

4. **Document the relationship** (Priority: MEDIUM): Create a `Documentation.docc` article explaining how the Institute's framework relates to Apple's canonical implementation, for contributor orientation.

5. **Monitor Apple's evolution** (Priority: ONGOING): Track changes to `swiftlang/swift-testing` for new capabilities that should be adopted or divergences that should be documented.

### Next Steps

1. Conduct formal verification of the `~Copyable` registry soundness property
2. Prototype expression decomposition in `ExpectMacro`
3. Evaluate parameterized test implementation strategies
4. Create documentation article per recommendation 4

---

## References

### Swift Institute Internal
- [testing-conventions.md](testing-conventions.md) — Testing conventions research (Tier 3, DECISION)
- `/Users/coen/Developer/swift-institute/Skills/testing/skill.md` — Testing skill (canonical)
- `/Users/coen/Developer/swift-institute/Documentation.docc/Testing Requirements.md` — Testing requirements documentation
- `/Users/coen/Developer/swift-foundations/swift-testing/` — Institute swift-testing source
- `/Users/coen/Developer/swiftlang/swift-testing/` — Apple swift-testing source

### Swift Evolution
- SE-0382: Expression macros
- SE-0389: Attached macros
- SE-0390: Noncopyable structs and enums
- SE-0413: Typed throws
- SE-0414: Region-based isolation
- SE-0430: `sending` parameter modifier
- SE-0450: Trait-gated dependencies
- [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) — Generic type suite discovery

### Academic & Industry
- Goguen, J. & Meseguer, J. (1982). "Completeness of many-sorted equational logic." *Houston J. Math.*, 8(2), 245–271.
- Claessen, K. & Hughes, J. (2000). "QuickCheck: A lightweight tool for random testing of Haskell programs." *ICFP 2000*.
- Wadler, P. (1989). "Theorems for free!" *FPCA '89*.
- Plotkin, G. & Pretnar, M. (2009). "Handlers of algebraic effects." *ESOP 2009*.
- Bauer, A. & Pretnar, M. (2015). "Programming with algebraic effects and handlers." *J. Log. Algebr. Meth. Program.*, 84(1), 108–123.
- Walker, D. (2005). "Substructural type systems." In *Advanced Topics in Types and Programming Languages*, Pierce (ed.), MIT Press.
- Green, T.R.G. & Petre, M. (1996). "Usability analysis of visual programming environments." *J. Visual Languages & Computing*, 7(2), 131–174.
- Schankin, A., Berber, A., Bacher, C., Biesalski, B., & Maalej, W. (2018). "Descriptiveness, log, and jargon: automatically detecting identifier name quality." *ICPC 2018*.

### Framework Sources
- [swiftlang/swift-testing](https://github.com/swiftlang/swift-testing) — Apple's Swift Testing framework
- [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — Snapshot testing prior art
- [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies) — Dependency injection prior art
- JUnit 5 documentation — `TestEngine` SPI architecture
- Rust `#[test]` — Attribute-based test declaration
- Haskell Tasty — Composable test tree framework
