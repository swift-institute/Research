# Revalidation: Swift Testing Discovery with Backticks and Nested Types

## Context

The testing skill (`Skills/testing/SKILL.md`) documents workarounds for two Swift Testing limitations:

1. **Backticked test function names** — Xcode test discovery reportedly failed to find `@Test func \`my test name\`()` style tests
2. **Nested test suites inside generic types** — `@Suite` structs nested inside generic outer types were not discovered

These limitations forced compromises:
- Test functions use camelCase instead of backticked descriptive names
- Test suites use flat or parallel namespace patterns instead of proper nesting inside the types they test
- Compound type names like `KernelThreadTest` exist because proper nesting (`Kernel.Thread.Test`) interacted badly with discovery

The testing skill contains rules [TEST-025] and [TEST-026] that document these workarounds. A recent naming audit updated the skill's examples to show the *correct* Nest.Name pattern, but the actual source code still uses compound names.

## Task

### Phase 1: Find existing research

Search for prior research and experiments on this topic:
- `Research/` — look for documents about test discovery, backticks, Xcode, Swift Testing
- `Experiments/` — look for experiments testing discovery behavior
- `https://github.com/swift-primitives` — any package's Research/ or Experiments/ related to testing discovery
- `https://github.com/swift-foundations/swift-tests/tree/main/Research/` — test infrastructure research
- Check git log across repos for commits mentioning "discovery", "backtick", "Xcode", "test naming"

Compile what was found, what was concluded, and which Swift/Xcode version it was tested against.

### Phase 2: Revalidation experiment

Create an experiment at `Experiments/testing-discovery-revalidation/` that tests whether these limitations still exist in the current toolchain. The experiment should:

1. **Backticked function names**: Create `@Test func \`descriptive test name\`()` — does `swift test` find it? Does Xcode discover it?
2. **Nested suites**: Create `@Suite struct Outer { @Suite struct Inner { @Test func example() {} } }` — discovered?
3. **Generic nesting**: Create `enum Container<T> { @Suite struct Tests { @Test func example() {} } }` — discovered?
4. **Backticked suite names**: Create `@Suite struct \`My Suite\` { @Test func example() {} }` — discovered?
5. **Deep nesting**: `A.B.C.Tests` with 3+ levels — discovered?
6. **Combined**: Backticked names inside nested generic types — discovered?

Run `swift test` and capture results. Note the Swift version (`swift --version`).

### Phase 3: Report and recommendation

If the limitations are resolved:
- Document which Swift version fixed them
- Draft a plan for ecosystem-wide test rename audit:
  - Scope: all test targets across swift-primitives, swift-standards, swift-foundations
  - Pattern: compound names → Nest.Name, camelCase test funcs → backticked descriptive names
  - Estimate: number of test files, test functions, test suites affected
- Update the testing skill's workaround rules to reflect current reality

If the limitations persist:
- Document exact failure mode with current toolchain version
- Note what works vs what doesn't
- Update existing research with fresh data

Write the report to `Research/testing-discovery-revalidation-2026-03.md` following [RES-003] conventions. Update `Research/_index.md`.

## Key files

- Testing skill: `Skills/testing/SKILL.md`
- Testing institute skill: `Skills/testing-institute/SKILL.md`
- Test infrastructure: `https://github.com/swift-foundations/swift-tests`
- Experiment process: `/experiment-process` skill for [EXP-002], [EXP-003]
- Research process: `/research-process` skill for [RES-003]
