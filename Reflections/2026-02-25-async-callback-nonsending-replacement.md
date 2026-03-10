---
date: 2026-02-25
session_objective: Replace CPS-based Async.Callback with nonsending direct-style type and add comprehensive tests
packages:
  - swift-async-primitives
  - swift-test-primitives
  - swift-institute
status: processed
---

# Async.Callback Nonsending Replacement — Research-to-Production Pipeline

## What Happened

Replaced the CPS-based `Async.Callback<Value: Sendable>: Sendable` (164 lines, `@Sendable` closures, `run` property) with a direct-style `Async.Callback<Value>` using `nonisolated(nonsending)` closures and `callAsFunction(isolation:)`. This was Option E / Approach C from the `callback-isolated-nonsending-design.md` research (v2.1, RECOMMENDATION status).

**Three commits across two packages:**
1. `swift-async-primitives` — complete rewrite of `Async.Callback.swift` (164 → 135 lines). Removed: `Value: Sendable`, `: Sendable`, CPS `run`, `var value`, `.async()` factory, all `@Sendable` closures. Added: `nonisolated(nonsending)` stored closure, `callAsFunction(isolation:)`, `@inlinable` on all public API, `init(wrapping:)` CPS bridge.
2. `swift-test-primitives` — migrated 4 call sites in `Test.Snapshot.Strategy.swift`: `asyncPullback` CPS chain → await chaining, `capture` `.value` → `()`, doc example and comments.
3. `swift-async-primitives` — 23 tests in new `Async.Callback Tests.swift` (255 lines), ported from experiment T1–T15. Unit (11), EdgeCase (7), Integration/isolation (6). All 88 async-primitives tests pass.

Also updated `callback-isolated-nonsending-design.md` from RECOMMENDATION → IMPLEMENTED (v3.0.0) with implementation record.

Scope was confirmed by grep: `Async.Callback` referenced in exactly 2 source files across the entire monorepo. Pool, cache, and foundations import `Async_Primitives` for channels/promises/bridges but never touch `Callback`.

## What Worked and What Didn't

**What worked well:**
- **Research → implementation was nearly frictionless.** The research document (v2.1) had an exact implementation sketch that matched the final code almost line-for-line. The experiment had already validated every design decision (D1–D7) and the `callAsFunction` approach (T15, 12 subtests). No design ambiguity remained at implementation time.
- **Scope validation via grep was fast and definitive.** The plan claimed exactly 2 files; grep confirmed it. No surprises during migration.
- **Isolation testing without Foundation.** Used `pthread_main_np()` from Darwin — no Foundation import needed for tests. Clean separation between "test needs system call" and "production code uses Foundation."

**What didn't work:**
- **`#expect(await lhs() == await rhs())` doesn't compile.** Swift doesn't allow `await` on both sides of a non-assignment operator, and the `#expect` macro expansion amplifies this. Had to extract both sides into `let` bindings first. Hit this twice (monad law tests). This is a Swift Testing interaction, not a callback issue, but it's a recurring pattern when testing async types.
- **Test filter mismatch.** `swift test --filter "Async Primitives Tests"` matched 0 tests — the filter string didn't match any Swift Testing suite names. Fell back to running all tests. The mismatch is between SPM test target names and Swift Testing `@Suite` names.

**Confidence was high throughout** because the experiment had already proven every critical path. The only uncertainty was whether non-Sendable values would compile in the test closures (they did — `nonisolated(nonsending)` closures can capture non-Sendable values within the same isolation domain).

## Patterns and Root Causes

**Pattern: research-experiment-implementation pipeline eliminates implementation risk.** This session had zero design decisions to make — every question had already been answered by the research document and validated by the experiment. The research identified 5 approaches and narrowed to 1. The experiment tested 15 scenarios and confirmed the approach. Implementation was mechanical transcription. This is the ideal flow: the expensive cognitive work happens in research/experiment phases where iteration is cheap; the production phase is a confident, low-risk commit.

The total research investment (research document v1.0–v2.1, 496 lines; experiment with 5 approaches and 15 tests) was substantial. But the implementation session was fast, confident, and produced zero bugs. The ROI pattern: front-load analysis, minimize implementation surprises.

**Pattern: `await` on both sides of operators is a recurring async testing friction.** The `#expect` macro expands to `Testing.__checkValue(expr)` which cannot handle `await` on both sides of `==`. This isn't specific to `Async.Callback` — it affects any test comparing two async results. The workaround (extract to `let` bindings) is mechanical but adds boilerplate. Worth noting for the testing skill.

**Pattern: `pthread_main_np()` as Foundation-free isolation check.** The primitives layer forbids Foundation, but isolation tests need thread identity checks. `pthread_main_np()` from Darwin solves this cleanly. This is reusable across any primitives package that needs isolation testing.

## Action Items

- [ ] **[skill]** testing: Add guidance for async comparisons in `#expect` — extract both sides to `let` bindings when comparing two `await` expressions. The `#expect` macro cannot handle `await` on both sides of a non-assignment operator. [TEST-007 addendum]
- [ ] **[skill]** testing: Document `pthread_main_np()` as the Foundation-free pattern for isolation verification in primitives-layer tests. Guard with `#if canImport(Darwin)`. [TEST-022 Category 3 addendum]
- [ ] **[package]** swift-async-primitives: The `swift test --filter` pattern for Swift Testing suites needs investigation — SPM target names don't match `@Suite` discovery names. May need filter by module or regex.
