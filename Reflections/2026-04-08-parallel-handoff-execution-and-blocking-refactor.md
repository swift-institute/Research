---
date: 2026-04-08
session_objective: Execute 5 handoffs in parallel (Async.Semaphore, Kernel.Thread.Semaphore, swift-executors creation, executor consolidation, IO.Blocking refactor)
packages:
  - swift-async-primitives
  - swift-kernel
  - swift-executors
  - swift-io
  - swift-pools
status: processed
---

# Parallel Handoff Execution and IO.Blocking Refactor

## What Happened

Executed 5 handoff documents across 4 packages. Three ran as background agents in parallel (Async.Semaphore, Kernel.Thread.Semaphore, swift-executors). Two ran sequentially in the main chat (executor consolidation, IO.Blocking refactor).

**Parallel agents (background):**
- Async.Semaphore: 9 source + 1 test in swift-async-primitives. 135 tool uses, ~27 min.
- Kernel.Thread.Semaphore: 12 source + 1 test in swift-kernel. 90 tool uses, ~9 min.
- swift-executors creation: new package, moved Kernel.Thread.Executors → Executor.Sharded. 63 tool uses, ~9 min.

**Main chat (sequential):**
- Executor consolidation: moved singular Kernel.Thread.Executor from swift-kernel to swift-executors. Proved cross-module extension of namespace enum works for class definitions.
- IO.Blocking refactor: replaced ~114 files of Lane/Threads with IO.Blocking.Driver composing Async.Semaphore + Kernel.Thread.Executor.Sharded. Expanded scope from handoff estimate to include 12 IO Executor files + 4 test files. User identified 6 runtime regressions post-completion.

**Final state:** 4 repos committed. swift-pools deleted. Two follow-up handoffs remain open (P0 sync-path fix, kernel type relocation research).

## What Worked and What Didn't

**Worked:**
- Parallel agent dispatch: three independent packages, no file conflicts. All three completed successfully. The orchestrating chat could do other work while waiting.
- Flagging blast radius before implementing: I identified 7 IO Executor files that referenced IO.Blocking.Lane before the handoff mentioned them. User confirmed Option A (full replacement) rather than a shim. This prevented a mid-implementation discovery that would have been much more expensive.
- Build-driven error fixing: after the big deletion pass (Phase 4), iterating on `swift build` errors was faster than trying to predict and fix every reference upfront.
- IO.Failure relocation: moving pure generic types from IO Executor to IO Core resolved a module boundary issue cleanly.

**Didn't work:**
- Initial `sending` vs `@Sendable` mistake: I defaulted to `@Sendable` on closure parameters and `T: Sendable` bounds. User corrected immediately. The ecosystem uses `sending` throughout — I should have picked this up from the loaded skills.
- Underestimated the IO.Blocking refactor scope: the handoff estimated ~7 IO Executor files to update. Actual was 12 source files + 4 test files + moving IO.Failure types.
- The sync path regression: I used `Task { }` wrapping for convenience (Option C from the handoff) without recognizing it contradicts the subsystem's purpose ("don't starve the cooperative pool"). The user's post-completion regression analysis caught this — it should have been caught during design.
- Worktree isolation failed: `<workspace root>` isn't a git repo, so `isolation: "worktree"` couldn't create git worktrees. Fell back to regular agents, which worked because the packages were independent.

## Patterns and Root Causes

**Pattern: "Convenience wrapping" hides semantic regression.** The sync path went from "lock → push → return Handle" (truly synchronous, zero cooperative pool) to "spawn Task → admission → dispatch → return Handle" (touches cooperative pool). The wrapping made the code shorter and the API simpler — but it broke the semantic contract. This is the same pattern as the shim discussion: layering that looks like simplification can mask behavioral changes. The user's test: "Does the fundamental operation still have the same runtime properties?" Not just "Does it compile?"

**Pattern: Blast radius underestimation in subtractive refactors.** When deleting a widely-used internal type (IO.Blocking.Lane), the handoff catalogued what the type *exports* but not what *consumes* it internally. The consumer graph is what determines blast radius. Grep for the type before estimating scope — not just in the deletion target, but in all modules that import it.

**Pattern: The continuation dispatch pattern is ecosystem infrastructure.** `withCheckedContinuation` + `Task<Void, Never>(executorPreference:)` is a general solution for "dispatch to a specific executor without T: Sendable." This pattern should live in a primitives package, not be reinvented at every call site. It's the async equivalent of the boxing pattern the old code used — but type-safe.

## Action Items

- [ ] **[skill]** implementation: Add rule for sync-path purity — when a subsystem's purpose is "avoid touching X," the sync submission path MUST NOT touch X. Convenience wrapping that violates the stated purpose is a regression even if the API is simpler.
- [ ] **[package]** swift-async-primitives: The continuation dispatch pattern (`withCheckedContinuation` + `Task<Void, Never>`) should be extracted as a reusable primitive (e.g., `Async.Executor.run(on:operation:)`) rather than hand-written at each call site.
- [ ] **[research]** Should `Kernel.Thread.Executor.Sharded` support work-stealing or a shared-queue variant? The round-robin dispatch regression (idle executors when one is slow) is a known trade-off — benchmark to quantify before deciding.
