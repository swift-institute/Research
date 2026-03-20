# Testing Discovery Revalidation

<!--
---
version: 1.0.0
last_updated: 2026-03-20
status: DECISION
---
-->

## Context

The testing skill documents workarounds for two Swift Testing discovery limitations:

1. **Backticked test function names** — Xcode/`swift test` discovery reportedly failed to find `` @Test func `my test name`() ``
2. **Nested test suites inside generic types** — `@Suite` structs nested inside extensions of generic type specializations were not discovered

These limitations forced compromises across the ecosystem:
- Test functions use camelCase instead of backticked descriptive names
- Test suites use compound names (`MemoryBufferTests`) instead of proper Nest.Name nesting (`Memory.Buffer.Test`)
- [TEST-004] mandates a parallel namespace workaround for generic types

Prior experiment `suite-discovery-generic-extension` (Swift 6.2.3, 2026-01-28) confirmed the generic nesting limitation. Issue [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) was filed and subsequently closed.

## Question

Which of these limitations still exist in Swift 6.2.4, and what can be unblocked?

## Analysis

### Experiment: testing-discovery-revalidation

**Toolchain**: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
**Platform**: macOS 26.0 (arm64)
**Location**: `Experiments/testing-discovery-revalidation/`

Six variants tested via `swift test list` and `swift test`:

| Variant | Pattern | Discovered? | Passes? |
|---------|---------|-------------|---------|
| V1 | `` @Test func `backticked name`() `` | **YES** | YES |
| V2 | `enum Outer { @Suite struct Inner { @Test ... } }` | **YES** | YES |
| V3a | `extension Pointer<Int> { @Suite struct ... }` (typealias) | **NO** | N/A |
| V3b | `extension Tagged<String, Int> { @Suite struct ... }` (direct) | **NO** | N/A |
| V4 | `` @Suite struct `Backticked Suite Name` { ... } `` | **YES** | YES |
| V5 | `LevelA.LevelB.LevelC.Tests` (3-level deep nesting) | **YES** | YES |
| V6 | Backticked names inside nested non-generic types | **YES** | YES |

### `swift test list` output

```
testing_discovery_revalidation.BacktickedFunctionNames/`another backticked name with special chars 123`()
testing_discovery_revalidation.BacktickedFunctionNames/`backticked test name is discovered`()
testing_discovery_revalidation.Container/Tests/`combined nested and backticked`()
testing_discovery_revalidation.LevelA/LevelB/LevelC/Tests/`deeply nested test is discovered`()
testing_discovery_revalidation.Outer/Inner/`nested suite test is discovered`()
testing_discovery_revalidation.`Backticked Suite Name`/`test inside backticked suite`()
```

V3a (`Pointer<Int>/Arithmetic`) and V3b (`Tagged<String,Int>/DirectTests`) are **absent** — they compile but are invisible to the test runner.

### What works (resolved or never broken)

1. **Backticked function names** — fully discovered by `swift test`. No evidence this was ever broken in the `swift test` runner; the original concern may have been Xcode-specific or pre-Swift-Testing.
2. **Backticked suite names** — fully discovered.
3. **Non-generic nested suites** — fully discovered at arbitrary depth. The [API-NAME-001] Nest.Name pattern works perfectly for non-generic test organization.
4. **Deep nesting** — 3+ levels discovered without issue.

### What remains broken

**Generic type extension nesting** — `@Suite`/`@Test` in extensions of generic type specializations (both via typealias and direct) are silently not discovered. Unchanged from Swift 6.2.3. The `@Test` macro expands to `static let` properties, which either:
- Fail to compile (unconstrained generic context), or
- Compile but are invisible to the test runner (concrete specialization)

[TEST-004]'s parallel namespace workaround remains necessary for generic types.

## Outcome

**Status**: DECISION

### Resolved: backticked names and non-generic nesting

The testing skill already mandates backticked function names ([TEST-007]) and type extension nesting ([TEST-003]). This experiment confirms both work correctly in Swift 6.2.4. No skill changes needed for these rules.

### Persistent: generic type exception

[TEST-004] remains correct. The parallel namespace workaround is still required for generic types.

### Ecosystem rename audit scope

The real debt is in the source code — compound test names that predate the current conventions. Estimated scope:

| Metric | swift-primitives | swift-standards | swift-foundations | Total |
|--------|------------------|-----------------|-------------------|-------|
| Test files | ~4,800 | ~2,200 | ~16,900 | ~23,900 |
| @Test functions | ~3,500 | ~480 | ~5,000 | ~9,000 |
| Compound suite names | ~390 | ~22 | ~241 | ~653 |
| camelCase test funcs | ~28 | ~11 | ~84 | ~123 |

**Recommended audit plan**:

1. **Phase A — Suite renames** (~653 sites): Rename compound test suite names (`FooBarTests` → nested `Foo.Bar.Test` via extension). This is the high-impact change. Excludes generic types (keep [TEST-004] workaround).
2. **Phase B — Function renames** (~123 sites): Convert remaining camelCase `@Test` functions to backticked descriptive names per [TEST-007].
3. **Execution order**: swift-standards first (smallest, ~22 compound names), then swift-primitives, then swift-foundations.
4. **Constraint**: Each rename batch must be verified with `swift test` to ensure discovery is preserved.

### No skill updates required

- [TEST-003] (type extension pattern): Already correct, already mandates nesting.
- [TEST-004] (generic type exception): Still necessary, still correct.
- [TEST-007] (backticked names): Already correct, already mandates backticks.

The skills describe the target state accurately. The gap is source code compliance, not skill accuracy.

## References

- Prior experiment: `Experiments/suite-discovery-generic-extension/` (Swift 6.2.3, 2026-01-28)
- Revalidation experiment: `Experiments/testing-discovery-revalidation/` (Swift 6.2.4, 2026-03-20)
- Testing skill: `Skills/testing/SKILL.md` — [TEST-003], [TEST-004], [TEST-007]
- Upstream issue: [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508)
- Research prompt: `Research/prompts/testing-discovery-backtick-nesting-revalidation.md`
