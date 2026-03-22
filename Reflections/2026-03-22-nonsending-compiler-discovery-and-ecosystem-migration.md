---
date: 2026-03-22
session_objective: Inventorize nonsending research/experiments, refactor corpus, discover compiler patterns, migrate ecosystem
packages:
  - swift-async-primitives
  - swift-pool-primitives
  - swift-witnesses
  - swift-dependencies
  - swift-testing
  - swift-institute
status: pending
---

# Nonsending Compiler Discovery and Ecosystem Migration

## What Happened

Three-phase session: corpus hygiene, compiler research, production migration.

**Phase 1: Corpus refactoring.** Inventoried all 10 research documents and 7 experiments related to `nonisolated(nonsending)`. Found `nonsending-blocker-validation` was a catch-all experiment testing 5 independent topics (closure storage, sync restriction, continuation isolation, cancellation handler, ~Escapable, NonsendingClock). Split it into 4 primitively scoped experiments. Absorbed `nonsending-blocker-validation-negative` (actually about ~Escapable, not nonsending) into `nonescapable-closure-storage`. Updated cross-references in 6 research documents. Marked `sendable-in-rendering-and-snapshot-infrastructure.md` as SUPERSEDED.

**Phase 2: Compiler source discovery.** Explored `swiftlang/swift` to understand how the compiler represents and uses `nonisolated(nonsending)`. Three parallel agents examined: (1) AST/type system (`FunctionTypeIsolation::Kind::NonIsolatedNonsending`, implicit `Builtin.ImplicitActor` parameter), (2) Sema/SIL (isolation inference, hop optimization, region analysis), (3) stdlib usage patterns. Key discovery: the stdlib has **deprecated** `isolation: isolated (any Actor)? = #isolation` parameter overloads on all concurrency primitives (`withCheckedContinuation`, `withTaskCancellationHandler`, etc.) in favor of `nonisolated(nonsending)` on the function itself. Also found zero `@concurrent` in stdlib, the double-nonsending pattern, `sending` return types, and compiler test evidence for the conformance trap.

**Phase 3: Ecosystem audit and migration.** Audited the entire ecosystem (252 packages) for migration candidates. Found 26 `isolation:` parameter occurrences: 10 are SE-0421 protocol conformances (correct), 14 are deprecated convenience functions, 1 call site forwarding, 1 test fixture. Created validation experiment (`nonsending-method-annotation`) — 7/7 tests passed confirming method-level `nonisolated(nonsending)` propagates isolation identically to the `isolation:` parameter, including through `await self()` in map/flatMap (#83812 workaround). Migrated all 14 functions across 5 packages. 208 tests pass (88 async-primitives + 120 dependencies).

## What Worked and What Didn't

**What worked well:**

- **Parallel agent exploration of compiler source was highly effective.** Three agents simultaneously exploring AST, Sema/SIL, and stdlib produced comprehensive findings in ~3 minutes. Each agent had a distinct search focus with no overlap. The combined output gave a complete picture of the feature's implementation.

- **The validation experiment was decisive.** 7 tests covering basic isolation, map, chained map, flatMap, non-Sendable Value, double-nonsending, and sending parameters — all passed on first run. This gave full confidence to proceed with migration. The experiment compared old (isolation:) and new (nonisolated(nonsending)) patterns side-by-side, proving behavioral equivalence.

- **Breaking changes simplified the migration.** No deprecation shims, no backwards compatibility. Remove parameter, add annotation. Each function was a 2-line edit. The user's directive to "make breaking changes" was the right call — the stdlib's 3-layer deprecation pattern (disfavoredOverload + backDeployed + deprecated) would have been pure overhead for an ecosystem we control entirely.

- **Corpus refactoring before research was the right sequencing.** Having clean, primitively scoped experiments made the later cross-referencing from the compiler patterns research much cleaner. Each finding could point to a specific experiment rather than "B5 in the catch-all."

**What didn't work:**

- **`callAsFunction` with `nonisolated(nonsending)` triggers a function-value inference quirk.** When writing `let result = await callback()`, the compiler inferred `result` as `() -> Value` (the callAsFunction method reference) rather than `Value`. The string interpolation warning was the canary. Using explicit `.callAsFunction()` or type annotation resolves it. This is a toolchain quirk, not a semantic issue — runtime behavior was correct.

- **One call site (`Dependency.Test.Trait`) was missed by the agent.** It passed `isolation: nil` explicitly. The automated migration removed the parameter from the declaration but not from this caller. Caught by the build, fixed in 1 line.

## Patterns and Root Causes

**Pattern: Compiler source is the canonical reference for "should we do X?"** The entire `isolation:` parameter debate was resolved instantly by reading the stdlib source. No forum posts, no blog analysis, no speculation — the stdlib had already deprecated the pattern with a clear migration. This is a repeatable discovery method: when a Swift concurrency question is ambiguous, check `stdlib/public/Concurrency/` for the canonical answer.

**Pattern: The implicit parameter is the key mechanism.** The compiler inserts `@sil_isolated @sil_implicit_leading_param @guaranteed Builtin.ImplicitActor` for `nonisolated(nonsending)` functions. This is the same mechanism whether the function is a free function, a method, or a `callAsFunction`. Understanding this explains why methods propagate isolation but stored closures don't (#83812) — the thunk generation for method dispatch forwards the implicit parameter, but closure-in-closure dispatch does not.

**Pattern: Ecosystem-wide audits are fast with grep.** 252 packages, 26 occurrences, categorized in minutes. The superrepo structure makes `grep -r` across the entire codebase trivial. The audit would have been much harder with scattered repositories.

## Action Items

- [ ] **[skill]** implementation: Add guidance that `nonisolated(nonsending)` on async methods is preferred over `isolation: isolated (any Actor)? = #isolation` parameters. The `isolation:` parameter is the stdlib-deprecated pattern. Reference `nonsending-compiler-patterns.md`. Exception: SE-0421 `next(isolation:)` on `AsyncIteratorProtocol` conformances.
- [ ] **[research]** Does `nonisolated(nonsending)` on `callAsFunction` interact with the function-value inference quirk at call sites using sugar syntax `await callback()`? The experiment showed `() -> Value` type inference on `let result = await callbackNew()`. Investigate whether this affects production usage or is only visible in type reflection.
- [ ] **[package]** swift-async-primitives: The `Async.Callback` doc comments still reference SE-0420 in the `callAsFunction` section — update to reflect the `nonisolated(nonsending)` method pattern.
