---
date: 2026-03-29
session_objective: Investigate 50GB memory crash in swift-io tests, commit @concurrent removal, audit the migration
packages:
  - swift-io
  - swift-witnesses
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-073] SE-0461 @concurrent inference is body-sensitive
  - type: package_insight
    target: swift-witnesses
    description: nonisolated(nonsending) closures skip observation — known limitation
  - type: skill_update
    target: testing
    description: Add [TEST-027] test target compilation gate
---

# SE-0461 @concurrent Inference and @Witness Macro Interaction

## What Happened

Session began investigating a 50GB memory crash that killed the laptop during swift-io test runs. Recovered context from the crashed conversation's JSONL file (301 messages, fully intact — the crash killed the process, not the data). The crash was caused by a cooperative pool deadlock: `@concurrent` on `IO.Blocking.Lane._run` forced inline lane operations through the cooperative pool, saturating it under stress test contention. The `fatalError("HANG iter 0")` watchdog fired, and the crash dump of hundreds of in-flight tasks caused the memory spike.

Committed the fix (removing `@concurrent`, adding `nonisolated(nonsending)` on Lane stored closures) and the corresponding `@Witness` macro changes to handle `nonisolated(nonsending)` closure types in code generation.

During the audit, discovered that `needsNonsendingAnnotation` on `ClosureProperty` was too broad — it matched ALL `@Sendable async` closures, not just those with explicit `nonisolated(nonsending)` in their type annotation. This broke `observe` for every standard async witness closure (TestAPI, MockableAPI, etc.). Fixed to check for explicit `nonisolated` attribute presence.

Also discovered that the initial audit findings (#10-#12) about `generateUnimplementedClosure`/`generateMockClosure`/`generateConstantMember` were false positives: these generate sync closure bodies (no `await`), and sync-to-async promotion does not trigger `@concurrent` inference under SE-0461.

## What Worked and What Didn't

**Worked well**: Recovering conversation context from JSONL files. The structured investigation in the lost session (documented in `HANDOFF-inline-lane-cooperative-pool-deadlock.md`) provided complete context — theory, verification, design options — without needing to re-derive anything. This validated the branching handoff pattern.

**Worked well**: The starvation audit was thorough — all 9 `@concurrent` sites analyzed, all actors verified to use custom executors. The architecture is genuinely sound.

**Did not work**: The initial `needsNonsendingAnnotation` implementation (from the crashed session) was wrong but wasn't caught because the test suite had a pre-existing compilation error (`Calls.Result` → `Result` rename) that prevented running tests. The bug shipped in commit `409b4ae` and was only caught when we ran the full test suite in this session.

**Did not work**: The audit agent's findings #10-#12 were false positives. The agent correctly identified that closure literals were generated for async parameters, but did not distinguish between sync closure bodies (promoted implicitly) and async closure bodies (containing `await`). This distinction is the crux of SE-0461 inference behavior.

## Patterns and Root Causes

**SE-0461 inference is body-sensitive, not parameter-sensitive.** The `@concurrent` default for `@Sendable async` closures only triggers when the closure literal itself is explicitly async (contains `await` in its body). A sync closure literal passed to an `async` parameter is promoted sync→async without triggering `@concurrent` inference. This is non-obvious and contradicts the simple rule "all `@Sendable async` closures default to `@concurrent`."

This distinction matters for macro code generation: `unimplemented()` closures (body is `fatalError()` — sync) are safe, but `observe` wrapper closures (body calls `await witness.property(args)`) trigger `@concurrent` inference and need the passthrough fix.

**"Absence of X" ≠ "presence of Y".** The initial `needsNonsendingAnnotation` checked `!isConcurrent && @Sendable && isAsync` — the absence of `@concurrent`. But under SE-0461, absence of `@concurrent` means the DEFAULT applies (`@concurrent` for `@Sendable async`). Only the explicit PRESENCE of `nonisolated(nonsending)` in the type annotation signals a non-default choice. This is the same category of error as checking `!isNil` when you need `isExplicitlySet`.

**Pre-existing test failures mask new bugs.** The `Calls.Result` compilation error in the test target meant no witness tests ran. The wrong `needsNonsendingAnnotation` shipped uncaught. This argues for zero-tolerance on test compilation: a single compilation error in a test target should be treated as a blocking issue, not a "pre-existing" deferral.

## Action Items

- [ ] **[skill]** implementation: Add guidance that SE-0461 `@concurrent` inference is body-sensitive — sync closure literals promoted to async do NOT trigger `@concurrent` default. Reference: only closure bodies containing `await` are inferred as `@concurrent` for `@Sendable async` types.
- [ ] **[package]** swift-witnesses: The `observe` passthrough for `nonisolated(nonsending)` closures silently skips observation. This is the only correct behavior given the compiler constraint, but it should be documented as a known limitation — users should know that `nonisolated(nonsending)` closures are not observable via the `observe` API.
- [ ] **[skill]** testing: Add requirement that test target compilation errors MUST be fixed before committing changes to the same package, even if the errors are pre-existing. A non-compiling test target masks new bugs.
