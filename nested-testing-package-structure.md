# Nested Testing Package Structure

<!--
---
version: 1.0.0
last_updated: 2026-03-05
status: DECISION
---
-->

## Context

The Swift Institute ecosystem has two testing frameworks:

1. **Apple Testing** (from the Swift toolchain) — provides `@Test`, `@Suite`, `#expect`, `#require`. Available everywhere with zero dependencies.
2. **swift-foundations/swift-testing** — extends Apple Testing with `.timed()` performance traits, `#snapshot` macro, `#Tests` scaffolding macro, reporters, and baseline tracking. Depends on ~20 packages across primitives and foundations.

Most ecosystem packages are transitive dependencies of swift-testing. This creates a circular dependency: a package cannot depend on swift-testing if swift-testing already depends on it. The validated solution is a **nested Swift package** inside the parent's `Tests/` directory.

The question is: **how should the nested package be structured** when it needs to support both performance testing and snapshot testing?

## Question

What is the optimal directory layout and package structure for a nested testing package that provides both `.timed()` performance tests and `#snapshot` snapshot tests?

## Constraints

| Constraint | Impact |
|-----------|--------|
| SwiftPM ignores subdirectories with their own `Package.swift` | Nested packages are invisible to the parent build |
| swift-testing pulls in swift-syntax (~40MB compiled) | Each nested package with its own `.build/` duplicates this cost |
| `#snapshot` stores reference files in `__Snapshots__/` relative to test source | Snapshot reference files must be committed alongside test sources |
| `#Tests` macro generates Unit/EdgeCase/Integration/Performance/Snapshot suites | Provides ready-made scaffolding but includes categories we may not use in the nested package |
| Unit and edge case tests use Apple Testing in main `Package.swift` | No duplication — these stay in the parent |
| `swift test` only discovers tests in the current package | Each nested package requires separate `swift test` invocation |

## Analysis

### Option A: Single Nested Package at `Tests/Testing/`

All tests requiring swift-testing features go in one nested package with multiple test targets.

```
swift-{pkg}/
  Package.swift
  Sources/{Module}/
  Tests/
    {Module} Tests/                          ← Apple Testing (unit + edge case)
    Testing/
      Package.swift                          ← depends on parent + swift-testing
      Tests/
        {Module} Performance Tests/
          {Type} Performance Tests.swift
        {Module} Snapshot Tests/
          {Type} Snapshot Tests.swift
          __Snapshots__/                     ← committed reference files
```

**Advantages:**
- One dependency resolution, one `.build/` directory (~40MB swift-syntax compiled once)
- Clear organizing principle: "needs swift-testing" → goes here
- Single `swift test` invocation runs all extended tests
- Can filter: `swift test --filter Performance` or `swift test --filter Snapshot`
- Naturally accommodates future test types needing swift-testing (integration tests, fuzz tests with custom traits)
- `#Tests` macro can be used if desired (just populate `.Performance` and `.Snapshot` extensions)

**Disadvantages:**
- Name `Testing/` is slightly redundant inside `Tests/`
- Developers must know to `cd Tests/Testing/` for extended tests

**CI integration:**
```bash
# Unit tests
cd swift-{pkg} && swift test

# Extended tests (performance + snapshots)
cd swift-{pkg}/Tests/Testing && swift test
```

---

### Option B: Separate Nested Packages Per Concern

Each test category gets its own nested package.

```
swift-{pkg}/
  Package.swift
  Sources/{Module}/
  Tests/
    {Module} Tests/                          ← Apple Testing
    Performance/
      Package.swift                          ← depends on parent + swift-testing
      Tests/
        {Module} Performance Tests/
    Snapshots/
      Package.swift                          ← depends on parent + swift-testing
      Tests/
        {Module} Snapshot Tests/
          __Snapshots__/
```

**Advantages:**
- Clear separation: `cd Tests/Performance` or `cd Tests/Snapshots`
- Each concern can evolve independently
- Can selectively skip one category in CI

**Disadvantages:**
- Two dependency resolutions of swift-testing (and swift-syntax, ~40MB each)
- Two `.build/` directories — significant disk overhead
- First build is ~2x slower (resolves and compiles swift-syntax twice)
- More `Package.swift` files to maintain
- Each new test category needing swift-testing requires a new nested package
- Redundant boilerplate across Package.swift files

---

### Option C: Single Nested Package at `Tests/Performance/` (Status Quo + Expansion)

Keep the current `Tests/Performance/` directory but add snapshot test targets to it.

```
swift-{pkg}/
  Package.swift
  Sources/{Module}/
  Tests/
    {Module} Tests/                          ← Apple Testing
    Performance/
      Package.swift                          ← depends on parent + swift-testing
      Tests/
        {Module} Performance Tests/
        {Module} Snapshot Tests/
          __Snapshots__/
```

**Advantages:**
- No restructuring needed — builds on what we already have
- Single `.build/` directory

**Disadvantages:**
- Directory name `Performance/` is misleading when it contains snapshot tests
- Future test types make the name increasingly wrong
- Package name `performance-tests` in Package.swift doesn't match content

---

### Option D: Single Nested Package Using `#Tests` Macro Scaffolding

Use `#Tests` to generate the full test structure. Only populate Performance and Snapshot extensions.

```
swift-{pkg}/
  Package.swift
  Sources/{Module}/
  Tests/
    {Module} Tests/                          ← Apple Testing (unit + edge case)
    Testing/
      Package.swift
      Tests/
        {Module} Extended Tests/
          {Type} Tests.swift                 ← uses #Tests macro
          __Snapshots__/
```

Test file structure:
```swift
import Testing
@testable import {Module}

extension {Type} {
    #Tests(snapshots: .init(recording: .missing))
}

extension {Type}.Test.Performance {
    @Test(.timed(threshold: .milliseconds(50)))
    func `operation within budget`() { ... }
}

extension {Type}.Test.Snapshot {
    @Test
    func `output format`() {
        #snapshot(instance.render(), as: .lines)
    }
}
```

**Advantages:**
- All advantages of Option A
- `#Tests` provides standardized scaffolding with serialization traits already applied
- `.Performance` and `.Snapshot` are auto-generated with correct traits (`.serialized`, `.exclusive`)
- Snapshot configuration is centralized in the `#Tests` call
- Consistent with the showcase pattern from swift-testing

**Disadvantages:**
- The `#Tests` macro also generates `.Unit`, `.EdgeCase`, `.Integration` suites that would go unused (they live in the main package)
- May be confusing to see empty scaffolding suites
- Tighter coupling to swift-testing's macro conventions

---

## Comparison

| Criterion | A: Single `Testing/` | B: Separate Packages | C: Expand `Performance/` | D: `#Tests` Macro |
|-----------|----------------------|---------------------|--------------------------|-------------------|
| Disk overhead | Low (one `.build/`) | High (N × `.build/`) | Low (one `.build/`) | Low (one `.build/`) |
| First build time | ~35s | ~35s × N | ~35s | ~35s |
| Naming accuracy | Good | Excellent | Poor after expansion | Good |
| Future-proof | Yes (add targets) | No (add packages) | No (name misleads) | Yes (add extensions) |
| Maintenance burden | Low (one Package.swift) | High (N Package.swift) | Low | Low |
| CI granularity | Filter by target | Separate invocations | Filter by target | Filter by target |
| Scaffolding | Manual `@Suite` | Manual `@Suite` | Manual `@Suite` | Automatic `#Tests` |
| Snapshot config | Per-suite | Per-suite | Per-suite | Centralized |
| Unused scaffolding | None | None | None | Unit/EdgeCase/Integration empty |

## Recommendation

**Option A: Single Nested Package at `Tests/Testing/`** with Option D's `#Tests` macro as an optional enhancement.

**Rationale:**

1. **One `.build/` directory** is the strongest practical argument. swift-syntax compilation is the dominant cost. Duplicating it per concern is wasteful.

2. **The organizing principle is the dependency, not the test type.** "Needs swift-testing" is the binary decision that determines where a test lives. Within that boundary, multiple test targets provide clean separation.

3. **`Testing/` as the directory name** directly communicates "this uses our Testing framework." It's self-documenting.

4. **`#Tests` macro is optional.** Packages with simple performance tests can use manual `@Suite(.serialized)`. Packages with rich snapshot workflows benefit from `#Tests` scaffolding. Both approaches work within the same nested package.

5. **Future-proof.** When new test types emerge (integration tests needing dependency injection, fuzz tests with custom traits), they slot in as additional test targets without restructuring.

**Migration from current `Tests/Performance/`:**

Rename `Tests/Performance/` → `Tests/Testing/`. Update `Package.swift` name from `performance-tests` to `testing`. Add snapshot test targets.

## Decisions Made

- **Directory name**: `Tests/Testing/` — directly communicates the framework dependency
- **`#Tests` macro**: recommended default for packages defining their own types; manual `@Suite` for stdlib extension tests
- **Skill**: renamed `testing-performance` → `testing-institute` with broadened scope (IDs: `[INST-TEST-*]`)
- **Migration**: `Tests/Performance/` → `Tests/Testing/`, snapshot test target added
- **Package name**: always `testing` (in nested `Package.swift`)

## References

- Validated prototype: `swift-standard-library-extensions/Tests/Performance/`
- Showcase examples: `swift-testing/Experiments/syntax-showcase/`
- `#Tests` macro: `swift-testing/Sources/Testing Umbrella/Tests.swift`
- Snapshot storage: `swift-tests/Sources/Tests Snapshot/Test.Snapshot.Storage.swift`
- `testing-performance` skill: `swift-institute/Skills/testing-performance/SKILL.md`
