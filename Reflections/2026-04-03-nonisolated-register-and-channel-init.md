---
date: 2026-04-03
session_objective: Investigate and fix io-bench Channel benchmark hang, then implement nonisolated register/deregister from converged plan
packages:
  - swift-io
  - swift-async-primitives
status: processed
---

# Nonisolated Register/Deregister and Channel.init — From Diagnosis to Regression

## What Happened

Session began with investigating the io-bench Channel echo benchmark hang (HANDOFF blamed cooperative pool starvation). Structural analysis proved starvation impossible (~3 tasks on 8+ pool threads). The real cause: pipelined write buffer deadlock — 64KB of writes against 8KB AF_UNIX socket buffers. This was already documented in `channel-full-duplex-split.md` as Phase 5 (never implemented). Fixed with `split()` + concurrent reader/writer via `Ownership.Transfer.Cell`.

Then implemented the converged plan's nonisolated register/deregister:
1. Renamed `Registration.Continuation` → `Registration.Waiter` with `resolve(with:)`
2. Created `Selector.Admission` gate (packed `Atomic<UInt64>` + `Async.Gate`)
3. Moved `withCheckedContinuation` from Runtime actor to nonisolated Selector methods (4→2 thread crossings)
4. Eliminated `receivers(for:)` — receivers returned directly via `Register.Bundle` (~Copyable struct with Optional take() pattern)
5. Runtime actor slimmed to shutdown-only

Then validated via experiment (`noncopyable-async-init`) that `~Copyable` structs support `async throws` init in Swift 6.3. Replaced `Channel.wrap()` static factory with `Channel.init`.

Five commits landed. Tests passed mid-session. But at session end, `swift test` hangs again. Session ended with a HANDOFF for investigation. User also made uncommitted changes to `IO.Event.Queue.Operations.swift` (kqueue backend) which may be the cause.

## What Worked and What Didn't

**Worked**: The structural analysis methodology for the benchmark hang. Systematically tracing every cooperative pool consumption point disproved the HANDOFF hypothesis in minutes. The `sysctl` buffer size check immediately confirmed the deadlock math. Prior research (`channel-full-duplex-split.md`) had the answer — the fix was mechanical.

**Worked**: The experiment-first approach for Channel.init. A 5-variant experiment confirmed the capability in 2 minutes, replacing speculative discussion with empirical proof.

**Worked**: The opposing-view exercise. When asked to argue against the API redesign, it revealed that forced split doesn't actually prevent the deadlock at the type level (same-task sequential write-then-read still deadlocks). This prevented an over-engineered refactor.

**Didn't work**: ~Copyable values in Mutex.withLock closures. The plan assumed receivers could be stored in a Mutex-protected Dictionary. Swift 6.3 treats the closure as escaping for ~Copyable analysis, blocking consumption. Had to pivot to returning receivers directly — which was actually cleaner but wasn't the plan.

**Didn't work**: End-of-session stability. Five commits landed, tests passed, but the final `swift test` run hangs. The regression may be from the user's concurrent changes to the kqueue backend, from the nonisolated register, or from an interaction. Not enough time to diagnose.

## Patterns and Root Causes

**~Copyable closure capture is the recurring constraint**. This session hit it in Mutex.withLock (can't consume captured ~Copyable in the closure body). Previous sessions hit it in Task.detached (needed Ownership.Transfer.Cell) and in withTaskCancellationHandler (cancellation propagation). The pattern: any API that takes a closure creates a boundary that ~Copyable values can't cross by consumption. The workaround is always to restructure so the ~Copyable value moves via return or parameter rather than closure capture.

**Inherited hypotheses carry unearned authority**. The HANDOFF said "cooperative pool starvation" and the investigation initially followed that framing. The structural analysis that disproved it came from stepping back and asking "is this even possible?" The same pattern appeared in previous sessions (CopyPropagation misattribution, SILGen root cause). Handoffs should frame problems as questions, not hypotheses.

**Experiment validation before API changes pays off**. The `noncopyable-async-init` experiment took 2 minutes and definitively answered whether Channel.init was viable. Without it, the decision would have been speculative. This is the [EXP-011] experiment-first pattern working as designed.

## Action Items

- [ ] **[skill]** handoff: Add guidance to frame problems as open questions rather than hypotheses — "why does the benchmark hang?" not "the hang is caused by cooperative pool starvation"
- [ ] **[package]** swift-io: Admission gate `enter()`/`leave()` pairing needs audit — a missing `leave()` on any error path would block shutdown forever. The `defer` in register covers the happy path but throwing before `enter()` returns means no `defer` fires
- [ ] **[skill]** memory-safety: Document the ~Copyable closure capture constraint — consumption inside `withLock`/`withCheckedContinuation`/`Task.detached` closures is blocked; workaround is return-path or Ownership.Transfer.Cell
