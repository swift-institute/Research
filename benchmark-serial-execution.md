# Benchmark Serial Execution

<!--
---
version: 1.0.0
last_updated: 2026-03-25
status: RECOMMENDATION
---
-->

## Context

io-bench runs 47 timed benchmarks across 13 suites. The runner's root dispatch
uses `.automatic` concurrency, which launches all suites concurrently via
`withTaskGroup`. This overwhelms the cooperative thread pool (~10 threads) with
thousands of concurrent tasks (contention: 2000, throughput: 1000, allocation
pressure: 1000 per suite), causing indefinite hangs.

The `.serialized` trait on each `Performance` sub-suite only serializes tests
**within** that suite. The module-level nil node (structural intermediate in
`Tree<Node?>.Keyed<String>`) always dispatches children with `.automatic`
because structural nil nodes pass `traits: nil` to `dispatch()`. The
`dispatch()` function checks `traits[Test.Trait.Serialized.self]` to override
to `.serial`, but this guard always fails when `traits` is `nil`.

`SWIFT_TEST_PARALLEL=1 swift test` resolves all hangs. Serial execution is
confirmed correct for benchmarks: measurement isolation requires exclusive
system resources.

**Trigger**: Implementation blocked — io-bench cannot run via `swift test`
without an environment variable. 10+ other performance test targets in the
ecosystem face the same structural risk.

**Scope**: Ecosystem-wide. Affects all packages with performance test targets:
io-bench, nio-bench, CSS, HTML Rendering, PDF, PDF Rendering, PDF HTML
Rendering, CSS HTML Rendering, SVG Rendering, Markdown HTML Rendering.

## Question

How should the Swift Institute ecosystem guarantee that benchmark targets
execute serially and deterministically, without requiring environment variables
or wrapper scripts?

## Constraints

- `swift test` must work without env vars or wrapper scripts
- `.automatic` must remain the default for unit test targets
- Benchmark targets must run all suites serially (measurement isolation)
- Solution must follow [API-NAME-\*], [IMPL-\*], and architectural layering
- Lane implementation (`IO.Blocking.Threads`) is confirmed correct — do not modify
- The `.timed()` iteration loop is confirmed correct — do not modify
- Swift Testing's `@Test`/`@Suite` macros are the test discovery mechanism

## Analysis

### The Root Cause: Structural Nil Nodes

The test tree for io-bench has this shape:

```
Root (nil — module "IO Performance Tests")
  ├─ Allocation (nil — enum, not @Suite)
  │  └─ Test (suite)
  │     ├─ Unit (suite, empty)
  │     ├─ EdgeCase (suite, empty)
  │     ├─ Integration (suite, empty)
  │     └─ Performance (suite, .serialized)
  │        ├─ test 1
  │        └─ test 2 ...
  ├─ Overhead (nil — enum)
  │  └─ Test (suite) → same nesting
  └─ ... 13 total
```

The root nil node dispatches 13 structural children with `.automatic`. Each
structural nil dispatches one `Test` suite. Each `Test` suite dispatches 4
sub-suites with `.automatic` (no `.serialized` on `Test`). Only `Performance`
has `.serialized`, so only tests within each Performance sub-suite run
serially. The 13 Performance sub-suites run in parallel with each other.

**Code path** (`Test.Runner.swift`):

| Line | Action |
|------|--------|
| 177–183 | `walk()` case `.some(nil)`: calls `dispatch(..., traits: nil, ...)` |
| 249–255 | `dispatch()`: `if let traits, traits[Serialized.self]` — fails for nil |
| 275–291 | `.automatic` case: `withTaskGroup` launches all children concurrently |

### Existing Ecosystem Pattern

8 rendering performance targets already solve this with a **single serialized
root suite**:

```swift
// Performance Tests.swift (e.g., swift-css, swift-html-rendering)
@Suite(.serialized)
struct `Performance Tests` {}

// Per-domain test files extend the root:
extension `Performance Tests` {
    @Test(.timed(iterations: 10, warmup: 3))
    func `property rendering throughput`() async throws { ... }
}
```

This creates a tree with the module nil node having **one child** (the
`Performance Tests` suite). Since there's only one child, `.automatic`
dispatch is harmless — one task in a task group is effectively serial. The
suite's `.serialized` trait then serializes all descendants.

io-bench does NOT follow this pattern. Its 13 top-level namespaces create 13
children under the nil root, all dispatched concurrently.

---

### Option A: Single Serialized Root Suite (Convention)

Restructure benchmark targets so all performance suites nest under a single
`@Suite(.serialized)` root type. This is the pattern already used by 8
rendering performance targets.

**For io-bench**, restructure from the four-tier namespace pattern to:

```swift
// Benchmarks.swift
@Suite(.serialized)
enum Benchmarks {}

// Allocation.swift
extension Benchmarks {
    @Suite struct Allocation {
        @Test(.timed(iterations: 10, warmup: 3))
        func `100 per-operation allocations`() async throws { ... }
    }
}

// Overhead.swift
extension Benchmarks {
    @Suite struct Overhead {
        @Test(.timed(iterations: 10, warmup: 3))
        func `single dispatch round-trip`() async throws { ... }
    }
}
```

**Tree result:**
```
Root (nil — module)
  └─ Benchmarks (suite, .serialized)
     ├─ Allocation (suite, inherits .serialized)
     │  └─ tests...
     ├─ Overhead (suite, inherits .serialized)
     └─ ... all serial
```

**Advantages:**
- Works today — zero infrastructure changes to swift-tests or swift-testing
- Already proven across 8 rendering targets
- Leverages existing trait propagation correctly
- Organizationally clean — domain grouping preserved via nested suites
- `.serialized` propagates to all descendants automatically

**Disadvantages:**
- Requires restructuring io-bench (and nio-bench) to drop the four-tier
  `Namespace.Test.{Unit,EdgeCase,Integration,Performance}` pattern
- Not self-documenting about WHY the root must be serialized — relies on
  convention knowledge
- Fragile if someone adds a second root suite (breaks the single-child
  invariant at the nil node level)

**Risk assessment**: Low. The fragility concern is mitigated by the fact that
dedicated benchmark targets (separate packages or test targets) should have
exactly one organizational root. Adding a second root suite to a benchmark
target is an unusual action that code review would catch.

---

### Option B: `Testing.main(concurrency:)` API + Custom `@main`

Add a `concurrency:` parameter to `Testing.main()` so benchmark targets can
explicitly set their execution mode from a custom entry point.

**API change** (`Testing.Main.swift`):

```swift
extension Testing {
    public static func main(
        concurrency: Test.Runner.Concurrency
    ) async throws(Run.Error) {
        try await run(registry: Discovery.all(), concurrency: concurrency)
    }

    private static func run(
        registry: consuming Test.Plan.Registry,
        concurrency: Test.Runner.Concurrency? = nil    // new parameter
    ) async throws(Run.Error) {
        var config = Configuration.current
        if let concurrency { config.concurrency = concurrency }
        // ... rest unchanged
    }
}
```

**Benchmark target usage:**

```swift
// main.swift (in benchmark target)
import Testing

@main
struct BenchmarkRunner {
    static func main() async throws {
        try await Testing.main(concurrency: .serial)
    }
}
```

**Advantages:**
- Explicit and self-documenting — intent is visible at the entry point
- Correct abstraction layer — target-level concern expressed at target level
- Works regardless of suite structure (no structural constraints)
- Small API surface (one new overload, ~5 lines)
- `@main` override confirmed working with SwiftPM (replaces generated runner)
- `Testing.Configuration` and `Test.Runner.Concurrency` are already public

**Disadvantages:**
- Requires a `@main` struct in every benchmark target (5 lines boilerplate × 10+ targets)
- New API surface on `Testing` — must be maintained
- No precedent in the codebase (zero existing `@main` overrides in test targets)
- Adds a second entry point pattern alongside `__swiftPMEntryPoint`

**Risk assessment**: Low. The API change is additive (new overload, backward
compatible). The `@main` pattern is documented in `Testing.Main.swift`'s
existing doc comments.

---

### Option C: Nil Node Dispatch Inference

Modify `dispatch()` to infer serial execution when all immediate children of
a nil node have the `.serialized` trait.

```swift
// In dispatch(), replace lines 249-255:
let effective: Concurrency
if let traits, traits[Test.Trait.Serialized.self] {
    effective = .serial
} else if traits == nil {
    // Nil node: infer from children
    let allSerialized = children.allSatisfy { (_, pos) in
        if case .some(.some(let node)) = tree.peek(at: pos) {
            return node.traits[Test.Trait.Serialized.self]
        }
        return false
    }
    effective = allSerialized ? .serial : concurrency
} else {
    effective = concurrency
}
```

**Advantages:**
- Self-healing — works automatically for any target where all suites are serialized
- No per-target configuration needed
- Fixes io-bench without restructuring

**Disadvantages:**
- Magical — behavior depends on the coincidence of ALL children being serialized
- Fragile — adding one non-serialized child (e.g., a unit test suite) silently
  breaks serialization for ALL siblings
- O(n) scan at each nil node (minor performance concern)
- Doesn't express intent — the user wants "this target runs serially," not
  "if all children happen to be serialized, then the parent should be too"
- Changes runner semantics for all users, not just benchmarks

**Risk assessment**: Medium-high. The fragility is the critical concern — it
creates a non-obvious invariant that code changes can silently violate.

---

### Option D: New `.benchmark` Trait with Runner Pre-Scan

Add a new trait (e.g., `.benchmark` or `.serializedTarget`) that, when present
on ANY suite in the plan, forces the runner to use serial dispatch at the root.

**Implementation sketch:**

```swift
// New trait key
extension Test.Trait {
    public enum Benchmark: Witness.Key {
        public typealias Value = Bool
        public static var liveValue: Bool { false }
    }
}

// New modifier
extension Test.Trait.Collection.Modifier {
    public static var benchmark: Self {
        Self { $0[Test.Trait.Benchmark.self] = true }
    }
}

// Runner pre-scan (in run()):
let hasBenchmark = plan.tree.contains { node in
    node?.traits[Test.Trait.Benchmark.self] == true
}
let effectiveConcurrency = hasBenchmark ? .serial : concurrency
```

**Advantages:**
- Declarative — `@Suite(.benchmark)` on any suite triggers serial target
- No structural constraints (works with any suite arrangement)
- Self-documenting at the suite level

**Disadvantages:**
- Conflates two concerns: "is benchmark" and "serial target dispatch"
- Introduces a new phase to execution (pre-scan), complicating the runner
- Trait system is per-node; this trait has per-target semantics (impedance mismatch)
- New trait key + modifier + runner scan = significant new infrastructure
- Precedent concern: this would be the first trait with "global effect"
  semantics, breaking the invariant that traits only affect their subtree

**Risk assessment**: Medium. The design is sound in isolation, but the
precedent of globally-effective traits introduces conceptual complexity that
may not justify itself for a single use case.

---

### Option E: `.exclusive(group:)` on All Benchmark Tests

Use the existing `.exclusive(group:)` trait to ensure mutual exclusion across
all benchmark tests without changing dispatch order.

```swift
@Test(.timed(iterations: 10, warmup: 3), .exclusive(group: "benchmark"))
func `single dispatch round-trip`() async throws { ... }
```

**Advantages:**
- Uses existing infrastructure (zero changes to swift-tests)
- Per-test granularity
- Conceptually correct (benchmarks need exclusive system resources)

**Disadvantages:**
- Boilerplate explosion — every benchmark test needs `.exclusive(group:)` (47 tests in io-bench alone)
- Doesn't prevent concurrent dispatch — suites still launch tasks via
  `withTaskGroup`. Tasks suspend on the lock instead of running, but the
  dispatch itself still creates hundreds of concurrent tasks
- Suite-level work (trait propagation, event emission) runs concurrently —
  only test body execution is serialized
- Measurement isolation is incomplete — background task scheduling, memory
  pressure from suspended tasks, and concurrent suite events can affect timing

**Risk assessment**: Medium. Solves the hang (suspended tasks don't exhaust
the pool) but doesn't achieve the measurement isolation that benchmarks
require.

---

### Option F: Configuration File

Add a `.swift-testing.json` or similar configuration file in the target
directory that specifies concurrency mode.

```json
{ "concurrency": "serial" }
```

**Advantages:**
- No code changes to test files
- Target-level configuration

**Disadvantages:**
- Introduces file-based configuration — un-Swifty, not type-checked
- New infrastructure for discovery, parsing, validation
- No precedent in Swift Testing ecosystem
- Configuration divorced from code (discoverability problem)

**Risk assessment**: High. Significant infrastructure for a narrow use case,
and file-based configuration conflicts with the ecosystem's code-first
philosophy.

---

### Option G: SwiftPM Build Plugin

A build plugin that generates the entry point with serial configuration for
targets that opt in (e.g., via a marker file or Package.swift annotation).

**Advantages:**
- Automatic — no per-target boilerplate beyond opting in
- Build-time configuration

**Disadvantages:**
- SwiftPM build plugins are complex infrastructure to maintain
- Opaque — generated code is hidden from the developer
- Build plugin API surface is limited and version-dependent
- Disproportionate complexity for a simple configuration need

**Risk assessment**: High. The engineering cost far exceeds the benefit.

---

### Comparison

| Criterion | A: Root Suite | B: @main API | C: Inference | D: New Trait | E: Exclusive | F: Config | G: Plugin |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Works without env vars | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| .automatic stays default | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Serial benchmark execution | ✓ | ✓ | ✓ | ✓ | partial | ✓ | ✓ |
| Measurement isolation | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| Zero infrastructure changes | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| Self-documenting | partial | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ |
| No per-target boilerplate | ✗ | ✗ | ✓ | partial | ✗ | partial | ✓ |
| Correct abstraction layer | suite | target | implicit | node→target | test | file | build |
| Ecosystem precedent | 8 targets | 0 targets | none | none | exists | none | none |
| Fragility risk | low | none | high | low | medium | low | low |
| Implementation cost | restructure | ~5 LOC | ~10 LOC | ~30 LOC | boilerplate | high | very high |

### Prior Art

**Apple swift-testing**: Uses `--parallel` / `--no-parallel` CLI flags passed
through `swift test`. The runner reads these from `__CommandLineArguments`.
Suite-level `.serialized` trait works identically to the Swift Institute
implementation. No target-level programmatic configuration exists — the CLI
flag is the only mechanism.

**XCTest**: `defaultTestSuite` can be overridden per target, but concurrency
is controlled by `XCTestCase.defaultPerformanceMetrics` and the
`-XCTest.parallelize` flag. No per-target programmatic configuration.

**Rust criterion**: Benchmark harness is a separate binary target with its own
`main()`. Each benchmark binary controls its own execution. This maps to
Option B (custom entry point per target).

**Go testing.B**: Benchmarks run via `go test -bench`. The test binary's
`TestMain` function can customize execution. Serial execution is the default
for benchmarks. This also maps to Option B.

**Common pattern**: In Rust and Go, benchmarks are separate binaries with
explicit entry points that control execution mode. This validates the
entry-point approach (Option B) as the industry standard for benchmark
targets.

## Outcome

**Status**: RECOMMENDATION

### Recommended: Two-Track Approach

#### Track 1 — Convention (Immediate, Zero Infrastructure)

Adopt the **single serialized root suite** pattern (Option A) as the canonical
structure for all performance test targets. This is already proven across 8
rendering targets.

**For io-bench**, restructure to:

```swift
// Benchmarks.swift
@Suite(.serialized)
enum Benchmarks {}

// Allocation.swift
extension Benchmarks {
    @Suite struct Allocation { /* .timed() tests */ }
}

// Overhead.swift
extension Benchmarks {
    @Suite struct Overhead { /* .timed() tests */ }
}
// ... one file per domain
```

**For existing rendering targets**: No changes needed — they already follow
this pattern.

**Convention rule**: Every dedicated performance test target MUST have a
single `@Suite(.serialized)` root type. All benchmark suites MUST be nested
under this root (directly or via extensions). This ensures the module's
structural nil node has exactly one child, making `.automatic` dispatch
harmless, and `.serialized` propagation handles the rest.

This convention should be documented in the **testing** skill under a new
section for benchmark target structure.

#### Track 2 — API Enhancement (Low-Effort, Deferred)

Add `Testing.main(concurrency:)` overload (Option B) for explicit target-level
control. This is ~5 lines of code in `Testing.Main.swift`:

```swift
public static func main(
    concurrency: Test.Runner.Concurrency
) async throws(Run.Error) {
    try await run(registry: Discovery.all(), concurrency: concurrency)
}
```

Plus a `concurrency:` parameter on the private `run(registry:)` method.

**When to implement**: When a benchmark target legitimately cannot use the
single-root-suite pattern (e.g., a target that mixes performance and
non-performance test suites that must coexist), or when explicit programmatic
control is needed for a new use case.

**Not needed for io-bench** — Track 1 fully solves it.

### Rejected Options

| Option | Reason |
|--------|--------|
| C: Nil node inference | Fragile — adding one non-serialized suite silently breaks all benchmark isolation. Doesn't express intent. |
| D: New `.benchmark` trait | First trait with global-effect semantics. Impedance mismatch between per-node trait system and per-target concern. Disproportionate infrastructure. |
| E: `.exclusive(group:)` | Doesn't achieve measurement isolation — concurrent dispatch, suite events, and task scheduling still create noise. Solves hang but not the design problem. |
| F: Configuration file | Un-Swifty. New infrastructure for narrow use case. Configuration divorced from code. |
| G: Build plugin | Disproportionate engineering cost. Opaque generated code. |

### Implementation Path

1. Restructure io-bench to use single `@Suite(.serialized) enum Benchmarks {}` root
2. Restructure nio-bench identically
3. Verify `swift test` works without `SWIFT_TEST_PARALLEL` in both targets
4. Document the convention in the testing skill
5. (Deferred) Implement `Testing.main(concurrency:)` if a future target requires it

## References

- `swift-tests/Sources/Tests Performance/Test.Runner.swift:166–329` — walk/dispatch
- `swift-tests/Sources/Tests Core/Test.Plan.Registry.swift:178–200` — trait propagation
- `swift-testing/Sources/Testing/Testing.Main.swift:81–132` — entry point + runner invocation
- `swift-testing/Sources/Testing/Testing.Configuration.swift:46–85` — env var configuration
- `swift-io/HANDOFF-post-test-hang.md` — full investigation of cooperative pool exhaustion
- `swift-io/HANDOFF-benchmark-serial-execution.md` — this investigation's charter
- `swift-css/Tests/CSS Performance Tests/Performance Tests.swift` — existing rendering pattern
- `swift-html-rendering/Tests/HTML Renderable Performance Tests/Performance Tests.swift` — existing rendering pattern
