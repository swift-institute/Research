---
date: 2026-04-01
session_objective: Investigate test runner hang after Handle refactor, design principled lifecycle fix
packages:
  - swift-io
  - swift-kernel
status: pending
---

# Test Hang Investigation — Executor Ownership as Architectural Question

## What Happened

The session began with a clear handoff: the Handle refactor (Kernel.Descriptor ownership) was complete, all kqueue tests passed, but the test process hung after all suites reported. The task was to investigate the hang and fix it.

**Investigation phase** was successful. `sample` of the hung process identified 7 leaked OS threads: 4 from `IO.Executor.shared` (triggered by Handle Registry tests using the singleton), 3 from IO.Completion.Queue tests that threw before calling `queue.shutdown()`. Research document written: `swift-io/Research/thread-ownership-lifecycle-refactor.md`.

**Fix phase** went through several iterations, each rejected:
1. `Selector.make()` self-owned executor + `_makeCore()` returning components — clean API, accepted
2. Completion test do/catch wrapping — mechanical, accepted
3. `atexit` handler on `IO.Executor.shared` — rejected (hack, violates [PLAT-ARCH-*], requires platform import)
4. Making `IO.Handle.Registry.init(lane:)` create per-registry executor — rejected (breaks production Shards semantics)
5. Two-executor `_make(driver:executor:ownedExecutor:)` — rejected (semantically confusing)

The session ended with a handoff because the user identified a deeper issue: the problem isn't "how to shut down executors" but "why does the ownership graph require so many independent executor lifecycles?"

## What Worked and What Didn't

**Worked well**: The diagnostic investigation was thorough and accurate. Sampling the correct process (child `swiftpm-testing-helper`, not parent `swift-package`) required two attempts but yielded clear root cause identification. The research document is comprehensive.

**Didn't work**: The fix iterations applied patches without questioning the architecture. Each fix addressed a symptom (leaked executor threads) without asking why the executor ownership model produces leaks in the first place. The user had to intervene twice to point out that the patches were unprincipled:
- First: "this code seems like a workaround/patch" (about atexit)
- Second: "I dont see why it needs TWO executors?? something systematic is going wrong"

The session spent too long on patch-level thinking and not enough on architectural analysis. The `_make(driver:executor:ownedExecutor:)` API — passing the same object as two different parameters — was a clear signal that the abstraction was wrong, but it took the user's challenge to see it.

## Patterns and Root Causes

**Pattern: Patch cascade from misidentified abstraction level.** The session correctly identified WHAT was leaking (executor threads) but misidentified the fix level. The real question isn't "how to ensure shutdown is called" but "why does each actor need an independently-managed executor thread, and who should own the executor lifecycle?"

The IO framework deliberately keeps work off the cooperative pool — dedicated threads are architecturally correct. But the ownership model is tangled: some types create executors, some borrow them, some use a global singleton. There's no single-owner principle. The result: dual-shutdown footguns, singleton leaks, and no clean way to express "this resource manages its own thread."

**Pattern: `~Escapable` as the principled scope mechanism.** The research identified `~Escapable` scope types as the theoretical ideal, and the ecosystem experiments validate the pattern. But the session didn't reach implementation because it got stuck on the executor ownership question — which is a prerequisite. You can't design a scope type until you know what it owns.

**Root cause of session friction**: The session tried to fix the executor ownership problem from the CONSUMER side (tests, convenience inits) instead of from the PRODUCER side (who creates executors and why). The `IO.Executor.shared` singleton exists because the original design assumed executors are shared infrastructure. But tests need isolated infrastructure. The tension between shared-in-production and isolated-in-tests is the core architectural question.

## Action Items

- [ ] **[research]** swift-io: Investigate whether a single "IO runtime" type should own all executor threads (poll threads + actor executors), replacing the current fragmented ownership where Selector, Handle Registry, and the shared pool each manage executors independently
- [ ] **[skill]** implementation: Add guidance for recognizing when a "patch cascade" signals a wrong abstraction level — if a fix requires passing the same object as two parameters, the abstraction boundary is wrong
- [ ] **[package]** swift-io: The `IO.Completion.Queue.Runtime` running on the cooperative pool is the architectural outlier — it should use a dedicated thread like Selector.Runtime, per the principle that IO stays off the cooperative pool
