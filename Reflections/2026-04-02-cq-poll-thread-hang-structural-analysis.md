---
date: 2026-04-02
session_objective: Investigate CQ FakeDriver poll thread hang — why poll threads survive test completion
packages:
  - swift-io
  - swift-async-primitives
  - swift-kernel
status: processed
---

# CQ Poll Thread Hang — Structural Analysis via Code Tracing

## What Happened

Session began with a focused handoff (`HANDOFF-cq-poll-thread-hang.md`) documenting the poll thread hang: `swift test` hangs after all 350 tests pass because 3 CQ FakeDriver poll threads remain blocked in `pollBlocking()` → `pthread_cond_wait`. A previous session had applied a sticky-wakeup fix that reduced 3 stuck threads to 1 but didn't solve the root cause.

The investigation was pure code analysis — no reproduction attempts (the user explicitly stopped those since the hang would block the terminal). Read all relevant files: `Queue.swift`, `Scope.swift`, `Poll.swift`, `Queue.Runtime.swift`, `FakeDriver.swift`, `Async.Bridge.swift`, `Wakeup.Channel.swift`, the Event Selector's parallel implementation, and `Kernel.Thread.Handle` (tracing `.detach()` through to `pthread_detach`).

Identified three compounding structural issues:
1. `.detach()` discards the `~Copyable` thread handle — no join path exists
2. `Scope.deinit` signals shutdown but never calls `bridge.finish()` — drain loop Task runs forever
3. All 7 CQ integration tests have `close()` as the last line with `try` operations before it — any throw triggers the incomplete deinit path

Also discovered the Event Selector has the identical structural pattern (`Selector.Scope.deinit` does halt+wake without join, `Selector.swift:177` also detaches).

The user reported mid-session that "the hang is now fixed" (by another agent or manually), but the structural analysis remained valid. Findings were written to the handoff file with three recommended fixes prioritized: `withScope` closure API > retain handle > complete deinit.

## What Worked and What Didn't

**Worked well**: The systematic code tracing was effective. Reading `Async.Bridge` was the turning point — understanding that `push()` never blocks but `next()` suspends until `finish()` immediately revealed why the deinit path is incomplete: without `bridge.finish()`, the drain loop Task (`while let event = await bridge.next()`) suspends forever, holding Runtime alive via `self` capture. This is invisible from the Scope layer — you have to trace through Queue → Runtime → Bridge to see it.

**Worked well**: Cross-referencing with the Event Selector pattern elevated the finding from "CQ bug" to "systemic design gap." The Selector has the same `.detach()` + incomplete-deinit pattern, just hasn't manifested because kqueue tests are more stable than FakeDriver condition-variable tests.

**Didn't work**: Initial instinct was to launch three parallel Explore agents for Bridge, tests, and thread handle. The user rejected all three. In hindsight, direct tool calls (Read, Grep, Glob) were more appropriate for this investigation — the files were known, the questions were specific.

## Patterns and Root Causes

**Pattern: "fire-and-forget thread" is a lifecycle debt.** Both CQ and Event Selector call `.detach()` on their poll threads, converting a joinable handle into a fire-and-forget thread. This trades a lifecycle obligation (someone must join) for a runtime obligation (the thread must self-terminate reliably). The `exit` bridge (`Async.Bridge<Void>`) was designed to replace `pthread_join` with an async-compatible mechanism — but it only works when someone awaits `exit.next()`, which can't happen in deinit.

The fundamental tension: deinit can't `await`, and `join()` blocks. The `exit` bridge solves the async case (`close()` path). The deinit case has no solution because the handle was discarded. Retaining the handle restores the option to do a bounded-time synchronous `join()` in deinit — bounded because `shutdownFlag.set()` + `wakeupChannel.wake()` guarantees the poll thread exits in microseconds.

**Pattern: incomplete deinit as the root cause of test hangs.** This is the third test-hang investigation in recent sessions (the previous two: `Kernel.Descriptor` deinit/fd-corruption, executor ownership architecture). All three share the same shape: a Scope type's deinit fires because a test throws before `close()`, and the deinit doesn't clean up everything the `close()` path does. The `close()` path is well-tested; the deinit path is an afterthought.

**Root cause**: The `~Copyable ~Escapable` Scope pattern makes `close()` the expected path and deinit the "emergency fallback." But tests routinely throw, making deinit the *common* path in test code. The mismatch between "unlikely in production" and "routine in tests" is the source of all three hangs. A `withScope` closure API eliminates this mismatch by making `close()` unconditional.

## Action Items

- [ ] **[skill]** memory-safety: Add guidance that `~Copyable` scope types with consuming `close()` methods SHOULD provide a `withScope` closure API that guarantees cleanup. Deinit must be as complete as `close()` for the cases where the closure API isn't used.
- [ ] **[research]** swift-io: Audit all `Scope.deinit` paths (CQ and Event Selector) for completeness — every operation in `close()` that is omitted from `deinit` is a potential hang or leak. The `bridge.finish()` omission in CQ is confirmed; Event Selector may have analogous gaps.
- [ ] **[package]** swift-io: The `withScope` closure API should be the primary public API for both `IO.Completion.Queue` and `IO.Event.Selector`, with the raw `Scope` type available for advanced use cases.
