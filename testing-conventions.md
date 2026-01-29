# Testing Conventions

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: IN_PROGRESS
tier: 3
---
-->

## Context

The Swift Institute ecosystem includes 61+ packages in swift-primitives, with more in swift-standards and swift-foundations. Each package requires tests. Existing documentation (`Documentation.docc/Testing Requirements.md`) and current tests in pointer-primitives and memory-primitives demonstrate emergent patterns that should be codified into a skill.

**Constraints**:
- Swift Testing framework (not XCTest)
- Current: `#TestSuites` macro from [swift-testing-extras](https://github.com/coenttb/swift-testing-extras)
- Future: `#Tests` macro from [swift-foundations/swift-testing](https://github.com/coenttb/swift-testing) (not yet finalized)
- Must align with [API-NAME-001] Nest.Name pattern
- Must handle `~Copyable` types (can't naively copy into assertions)
- **Critical constraint**: `@Suite` in extensions of generic type specializations is silently not discovered (see [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508))

**Trigger**: Proactive pattern extraction per [RES-017] — similar test structures appear across multiple packages.

## Question

What testing conventions should the Swift Institute ecosystem adopt for:
1. Test file organization and naming
2. Test suite structure (namespacing via nested `@Suite`)
3. Test categorization (Unit, EdgeCase, Integration, Performance)
4. Test naming conventions
5. Test Support targets
6. Testing `~Copyable` types

---

## Prior Art Survey

### Swift Testing Framework

Per [Swift Testing documentation](https://developer.apple.com/xcode/swift-testing), the framework provides:

- `@Test` macro for individual tests with optional display names
- `@Suite` macro for grouping tests (implicit when type contains `@Test` functions)
- Nested suites for hierarchical organization
- Traits: `.disabled`, `.tags`, `.bug`, `.enabled(if:)`, `.timeLimit`, `.serialized`
- Setup via initializers (no `setUp()`/`tearDown()`)

Key recommendations from [Mastering Swift Testing](https://fatbobman.com/en/posts/mastering-the-swift-testing-framework/):
- Nested suites avoid long test names like `SUT_functionName_given_when_then()`
- Global `@Test` functions recommended when only one test exists (no wrapper Suite)
- Custom display names via `@Test("description")` and `@Suite("name")`

### Rust Testing Organization

Per [Rust Book - Test Organization](https://doc.rust-lang.org/book/ch11-03-test-organization.html):

- **Unit tests**: In same file as code, under `#[cfg(test)] mod tests`
- **Integration tests**: In separate `tests/` directory
- Nested modules within test blocks for organization
- Shared utilities in `tests/common/mod.rs`

Relevant patterns:
```rust
#[cfg(test)]
mod tests {
    mod creation { /* tests */ }
    mod validation { /* tests */ }
}
```

### Existing Swift Institute Documentation

`Documentation.docc/Testing Requirements.md` defines the target state:

**Current** (`#TestSuites` from swift-testing-extras):
```swift
import Testing_Extras

extension YourType {
    #TestSuites
}
// Generates:
// YourType.Test.Unit
// YourType.Test.EdgeCase
// YourType.Test.Integration
// YourType.Test.Performance (serialized)
```

**Future** (`#Tests` from swift-testing):
```swift
import Testing

extension YourType {
    #Tests
}
// Adds: YourType.Test.Snapshot
```

The macro automates the nested suite creation, but is not yet available in all packages.

### Current Swift Institute Patterns (Empirical)

Extracted from pointer-primitives and memory-primitives (manual, no macro):

**Pattern A: Type Extension with Nested Test Suite**
```swift
extension Memory.Buffer {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}
```

**Pattern B: Top-Level Suite with Nested Categories**
```swift
@Suite("Pointer")
struct PointerTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}
```

**Pattern A** places `Test` as a nested type of the SUT itself, mirroring Nest.Name.
**Pattern B** uses a separate `*Tests` struct at top level.

---

## Analysis

### Decision 1: Test Suite Namespacing

#### Option A: Type Extension Pattern

```swift
extension Memory.Buffer {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension Memory.Buffer.Test.Unit {
    @Test("init creates empty buffer")
    func initEmpty() { /* ... */ }
}
```

**Advantages**:
- Mirrors [API-NAME-001] Nest.Name — `Memory.Buffer.Test.Unit`
- Test hierarchy matches type hierarchy
- Clear ownership: `Memory.Buffer` owns its tests
- Future-proof: `@Tests` macro can generate `Memory.Buffer.Test`

**Disadvantages**:
- Requires `@testable import` to extend internal types
- Extension constraint: can't add stored properties to Suite

#### Option B: Parallel Namespace Pattern

```swift
@Suite("Memory.Buffer")
struct MemoryBufferTests {
    @Suite struct Unit {}
}

extension MemoryBufferTests.Unit {
    @Test("init creates empty buffer")
    func initEmpty() { /* ... */ }
}
```

**Advantages**:
- Independent of SUT's access level
- Familiar XCTest-style naming

**Disadvantages**:
- Violates [API-NAME-002] — compound identifier `MemoryBufferTests`
- Namespace drift: tests don't track type renames
- Inconsistent with Nest.Name philosophy

#### Option C: Hybrid Pattern

```swift
extension Memory.Buffer {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

// For cross-cutting tests
@Suite("Memory.Arithmetic")
struct MemoryArithmeticTests {
    @Suite struct Basics {}
}
```

Use Option A for type-specific tests, Option B for cross-cutting concerns.

**Comparison**:

| Criterion | Option A (Extension) | Option B (Parallel) | Option C (Hybrid) |
|-----------|---------------------|--------------------|--------------------|
| Nest.Name compliance | Full | None | Partial |
| Future macro compatibility | High | Low | High |
| Cross-cutting tests | Awkward | Natural | Natural |
| Access level coupling | Yes | No | Partial |
| Namespace tracking | Automatic | Manual | Mixed |

**Recommendation**: Option C (Hybrid) — Extension pattern for type tests, parallel pattern only for cross-cutting.

**Critical Exception**: Generic type specializations cannot use Option A due to [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508).

---

### Decision 1b: Generic Type Test Suite Limitation

**Issue**: [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508)

`@Test` and `@Suite` macros compile without error inside extensions of concrete generic type specializations (e.g., `extension Container<Int>`), but the resulting tests are **silently invisible** to `swift test list` and never execute.

**Reproduction**:
```swift
struct Container<T> {}

extension Container<Int> {
    @Suite struct Tests {
        @Test("never discovered")
        func bug() { #expect(Bool(true)) }
    }
}
```

This compiles but the test is **never executed**.

**Workaround**: For generic types, use parallel namespace pattern:

```swift
// Generic type
struct Container<T> { ... }

// Tests use parallel pattern (not extension)
@Suite("Container<Int>")
struct ContainerIntTests {
    @Suite struct Unit {}
}
```

**Status**: Issue filed 2026-01-28, closed (likely as duplicate or working-as-intended). Workaround required until fixed.

---

### Decision 2: Test Categories

Current observed categories:
- `Unit` — isolated functionality tests
- `EdgeCase` — boundary conditions, error paths
- `Integration` — cross-component behavior
- `Performance` — with `.serialized` trait

#### Option A: Four Fixed Categories

```swift
@Suite struct Unit {}
@Suite struct EdgeCase {}
@Suite struct Integration {}
@Suite(.serialized) struct Performance {}
```

**Advantages**:
- Consistent across all packages
- Clear semantic distinction
- Performance tests run serialized (no parallelism interference)

**Disadvantages**:
- May be overkill for simple types
- Rigid structure

#### Option B: Minimum Required + Optional

Required: `Unit`
Optional: `EdgeCase`, `Integration`, `Performance`

**Advantages**:
- Flexibility for simple types
- Still provides structure

**Disadvantages**:
- Inconsistent appearance across packages

#### Option C: Semantic Categories Based on Content

Use descriptive names like:
```swift
@Suite struct Basics {}
@Suite struct Advance {}
@Suite struct Distance {}
```

**Advantages**:
- Self-documenting
- Natural grouping

**Disadvantages**:
- No cross-package consistency
- Hard to find "all edge cases" across codebase

**Comparison**:

| Criterion | Option A (Fixed 4) | Option B (Min+Opt) | Option C (Semantic) |
|-----------|-------------------|-------------------|---------------------|
| Consistency | High | Medium | Low |
| Discoverability | High | Medium | Low (per-type) |
| Flexibility | Low | High | High |
| Cross-package grep | Easy | Medium | Hard |

**Recommendation**: Option A (Fixed 4) with allowance for additional semantic sub-suites within.

---

### Decision 3: Test Function Naming

#### Option A: Descriptive Test Attribute + Short Function

```swift
@Test("init creates empty buffer with sentinel")
func initEmpty() { /* ... */ }
```

**Advantages**:
- Human-readable display name
- Short function name for code navigation
- Function name can be terse

**Disadvantages**:
- Duplication if description restates function name

#### Option B: Descriptive Function Name Only

```swift
@Test
func initCreatesEmptyBufferWithSentinel() { /* ... */ }
```

**Advantages**:
- Single source of truth
- Function name is searchable

**Disadvantages**:
- Long function names
- Violates terse identifier preference

#### Option C: Action-Outcome Pattern

```swift
@Test("init from nil throws")
func initFromNilThrows() { /* ... */ }

@Test("allocate updates offset")
func allocateUpdatesOffset() { /* ... */ }
```

Pattern: `<action>` + `<outcome/assertion>`

**Comparison**:

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Display readability | High | Medium | High |
| Code searchability | Medium | High | High |
| Consistency | Low | High | High |

**Recommendation**: Option C (Action-Outcome) — Provides both readable display and searchable function name.

---

### Decision 4: Test File Organization

#### Option A: One File Per Type

```
Tests/Memory Primitives Tests/
├── Memory.Buffer Tests.swift
├── Memory.Buffer.Mutable Tests.swift
├── Memory.Arena Tests.swift
└── Memory Arithmetic Tests.swift
```

**Advantages**:
- Mirrors source organization
- Easy to locate tests for a type
- Parallel structure with `Sources/`

**Disadvantages**:
- Many small files for many types

#### Option B: One File Per Logical Group

```
Tests/Memory Primitives Tests/
├── Buffer Tests.swift       // Buffer + Buffer.Mutable
├── Arena Tests.swift
└── Arithmetic Tests.swift
```

**Advantages**:
- Fewer files
- Related types together

**Disadvantages**:
- Larger files
- Harder to find specific type's tests

**Recommendation**: Option A — Mirrors [API-IMPL-005] one type per file.

---

### Decision 5: Test Support Targets

Current pattern: `{Module} Test Support` target in `Tests/Support/`.

**Structure**:
```
Package.swift:
  .library(name: "Pointer Primitives Test Support", ...)

Tests/Support/
├── exports.swift
└── Pointer Primitives Test Support.swift  // Shared utilities
```

**Purpose**:
- Re-export dependencies' test support (transitive)
- Provide test fixtures/factories
- Share common test utilities

**Recommendation**: Formalize as standard pattern:
- Every package MAY have `{Module} Test Support` library
- Test Support MUST re-export dependency test support modules
- Test Support SHOULD NOT contain tests (tests go in test target)

---

### Decision 6: Testing ~Copyable Types

**Challenge**: ~Copyable types cannot be copied, which affects assertion patterns:

```swift
// PROBLEM: Cannot copy noncopyable value
let buffer = Memory.Buffer(...)  // ~Copyable
#expect(buffer == expected)       // May attempt copy

// SOLUTION: Test via properties/methods that don't consume
#expect(buffer.count == 5)
#expect(buffer.isEmpty == false)
```

**Patterns**:

1. **Test Observable Properties**
```swift
@Test func initWithCapacity() {
    let arena = Memory.Arena(capacity: 1024)
    #expect(arena.capacity.rawValue == 1024)
    #expect(arena.allocated.rawValue == 0)
}
```

2. **Consume at End of Test**
```swift
@Test func moveTransfersOwnership() {
    let ptr = Pointer<Int>.Mutable.allocate(capacity: 1)
    defer { ptr.deallocate() }
    ptr.initialize(to: 42)
    let moved = ptr.move()  // Consumes initialization
    #expect(moved == 42)
}
```

3. **Borrowing Assertions**
```swift
@Test func bufferContents() {
    let buffer = Memory.Buffer(...)
    buffer.withBorrowed { borrowed in
        #expect(borrowed[0] == expected)
    }
}
```

4. **Inout Parameters for Mutation Tests**
```swift
@Test func resetRestoresCapacity() {
    var arena = Memory.Arena(capacity: 1024)
    _ = arena.allocate(count: 500, alignment: 8)
    arena.reset()  // Mutates in place
    #expect(arena.allocated.rawValue == 0)
}
```

**Recommendation**: Document these patterns in skill with examples.

---

## Formal Structure

### Test Suite Typing Rules

Let `T` be a type under test. The test suite structure follows:

```
T.Test               : TestSuite
T.Test.Unit          : TestSuite
T.Test.EdgeCase      : TestSuite
T.Test.Integration   : TestSuite
T.Test.Performance   : TestSuite (serialized)
```

### File Naming Grammar

```
TestFileName := TypePath " Tests.swift"
TypePath     := Namespace ("." Name)*
Namespace    := Module
Name         := Identifier
```

Example: `Memory.Buffer.Mutable Tests.swift`

### Test Function Naming Grammar

```
TestFunc := action outcome?
action   := verb noun?
outcome  := verb | adjective | noun
```

Example: `initEmpty`, `allocateUpdatesOffset`, `sliceOutOfBounds`

---

## Outcome

**Status**: IN_PROGRESS

### Recommendations

1. **Test Suite Namespacing**: Use type extension pattern `T.Test` for type-specific tests; parallel pattern for cross-cutting and generic type specializations (due to [#1508](https://github.com/swiftlang/swift-testing/issues/1508)).

2. **Test Categories**: Fixed four categories (Unit, EdgeCase, Integration, Performance), with semantic sub-suites allowed within. Future: add Snapshot when `#Tests` macro is available.

3. **Test Function Naming**: Action-Outcome pattern with `@Test("description")` for display names.

4. **Test File Organization**: One file per type, named `{TypePath} Tests.swift`.

5. **Test Support**: Standard `{Module} Test Support` library pattern with transitive re-exports.

6. **~Copyable Testing**: Document borrowing patterns; test via observable properties; consume only at assertion point.

### Next Steps

1. Validate recommendations against additional packages (swift-index-primitives, swift-set-primitives)
2. Conduct SLR per [RES-023] for testing ~Copyable types
3. Draft formal semantics per [RES-024]
4. Create `testing` skill with requirement IDs `[TEST-*]`

---

## References

### Swift Institute Internal
- `Documentation.docc/Testing Requirements.md` — Existing testing requirements documentation
- [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) — Generic type suite discovery bug
- [swift-testing-extras](https://github.com/coenttb/swift-testing-extras) — Current `#TestSuites` macro
- [swift-testing](https://github.com/coenttb/swift-testing) — Future `#Tests` macro (in development)
- pointer-primitives: `/Users/coen/Developer/swift-primitives/swift-pointer-primitives/Tests/`
- memory-primitives: `/Users/coen/Developer/swift-primitives/swift-memory-primitives/Tests/`
- swift-testing-crash experiment: `/Users/coen/Developer/swift-primitives/swift-set-primitives/Experiments/swift-testing-crash/`

### External
- [Swift Testing - Apple Developer](https://developer.apple.com/xcode/swift-testing)
- [Mastering Swift Testing - Fat Bob Man](https://fatbobman.com/en/posts/mastering-the-swift-testing-framework/)
- [Swift Testing Lifecycle - Swift with Majid](https://swiftwithmajid.com/2024/10/29/introducing-swift-testing-lifecycle/)
- [Rust Test Organization](https://doc.rust-lang.org/book/ch11-03-test-organization.html)
- [How to Organize Rust Tests - LogRocket](https://blog.logrocket.com/how-to-organize-rust-tests/)
