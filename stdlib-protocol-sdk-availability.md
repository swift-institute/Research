# Stdlib Protocol Availability in SDK .swiftinterface

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

A 2026-04-16 cooperative-donation session discovered that `RunLoopExecutor`, `SchedulingExecutor`, and `MainExecutor` are absent from the macOS 26.4 SDK's compiled `_Concurrency.swiftinterface`, even though they are `public` in `swiftlang/swift` stdlib source (`Executor.swift:64`, `Executor.swift:561`). `@_spi(ExperimentalCustomExecutors) import _Concurrency` compiles with a warning but does not surface the missing symbols.

The observed gap led to the failure of two attempted protocol conformances at compile time, despite source-level evidence the protocols existed. The fix posture (per the resulting [INFRA-026] / [RES-021] amendments) is "infrastructure-ready, conformance-deferred" — implement the method signatures, document the gap, defer the conformance until the SDK ships the symbol. But the underlying mechanism — *when* and *under what conditions* a stdlib protocol becomes available in the `.swiftinterface` — is unverified.

This Doc scopes that question and aims to produce a mechanical check that any research/implementation can run before authoring conformances.

## Question

When do new stdlib protocols (introduced in Swift 6.x) become available in `.swiftinterface` files shipped with Xcode SDKs? Possible triggers:

- The Xcode version (e.g., Xcode 17.x ships 6.3-protocols)
- The deployment target (e.g., macOS 26 ships 6.3-protocols)
- The toolchain version used to compile the SDK
- An availability annotation on the protocol declaration in stdlib source
- Some combination of the above

## Analysis

### Observed cases (2026-04-16)

| Protocol | Source location | Source visibility | macOS 26.4 SDK presence | Compile result |
|----------|-----------------|-------------------|-------------------------|----------------|
| `Executor` | `Executor.swift` | public | Present | OK |
| `SerialExecutor` | `Executor.swift` | public | Present | OK |
| `TaskExecutor` | `Executor.swift` | public | Present | OK |
| `RunLoopExecutor` | `Executor.swift:64` | public (stated) | Absent | Compile failure |
| `SchedulingExecutor` | `Executor.swift:561` | public (stated) | Absent | Compile failure |
| `MainExecutor` | `Executor.swift` | public (stated) | Absent | Compile failure |

The first three are present, the last three are absent — same source file, same visibility level. The discriminator is not source-visibility but something downstream.

### Open analysis

| Question | Approach |
|----------|----------|
| Are the absent protocols guarded by an availability annotation? | Read `Executor.swift` in the swiftlang/swift commit corresponding to macOS 26.4 SDK; check for `@available` annotations |
| Are the absent protocols conditionally compiled (#if INTERNAL_CONCURRENCY or similar)? | Read the source for conditional compilation directives |
| Does the `.swiftinterface` generation strip availability-gated declarations below the SDK's deployment target? | Spike: check a multi-SDK trial — does iOS 18 SDK ship them? Linux Swift toolchain SDK? |
| Is there a public roadmap for when these protocols will ship in Apple SDKs? | Search Swift Evolution + Apple developer documentation |

### Two-mechanism model (the held finding)

[RES-021] and [INFRA-026] both encode the same operational fact: source presence ≠ SDK presence. Two distinct stripping mechanisms produce the same failure mode:

| Mechanism | Trigger | Detection |
|-----------|---------|-----------|
| `@_spi` stripping | Declaration is `@_spi`-gated; `.swiftinterface` strips on export | Grep `.swiftinterface` for the symbol; check for `@_spi(...)` in source |
| Availability lag | Declaration is public but availability-gated below the SDK's target | Grep `.swiftinterface` for the symbol; check `@available(...)` in source |

Both are detectable by the same mechanical check: `grep` the SDK's `.swiftinterface` for the protocol declaration before authoring a conformance. The two-mechanism model lets future readers diagnose which stripping fired; the [INFRA-026] / [RES-021] check is sufficient regardless of which one is firing.

## Outcome

**Status**: IN_PROGRESS

**Held finding** (operational, applies regardless of mechanism): grep the target SDK's `.swiftinterface` for the protocol declaration before authoring a conformance. If the protocol is absent, follow infrastructure-ready, conformance-deferred posture per [INFRA-026].

**Pending empirical work**:

1. **Multi-SDK spike**: build a minimal conformance attempt against macOS 26.4 / iOS 18 / Linux Swift 6.3 SDKs to identify which produce the symbols
2. **Source archaeology**: check the swiftlang/swift commit for the absent protocols and document availability annotations / conditional-compilation gates
3. **Apple roadmap search**: confirm or refute a documented release plan for `RunLoopExecutor`, `SchedulingExecutor`, `MainExecutor` in Apple SDKs

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. The operational rule ([INFRA-026] / [RES-021]) is sufficient for current ecosystem needs; deeper analysis would refine the rule's diagnostic guidance but does not unblock present work.

## References

- Reflection: [Research/Reflections/2026-04-16-cooperative-donation-contract-and-sdk-interface-gap.md](Reflections/2026-04-16-cooperative-donation-contract-and-sdk-interface-gap.md)
- Reflection: `2026-04-16-supervision-spi-stripping-and-cooperative-landing.md` (SPI counterpart)
- Skills: [INFRA-026], [RES-021], [SKILL-LIFE-027]
