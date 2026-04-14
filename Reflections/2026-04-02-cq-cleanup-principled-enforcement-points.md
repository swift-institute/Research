---
date: 2026-04-02
session_objective: CQ redesign cleanup — verify state, apply remaining guards, tidy artifacts
packages:
  - swift-io
  - swift-kernel
status: processed
---

# CQ Cleanup — Principled Enforcement Points and the Nonisolated Guard Reversal

## What Happened

Session began with the CQ redesign handoff (HANDOFF.md) and a post-test-hang investigation (HANDOFF-post-test-process-hang.md). The handoff recommended applying *more* nonisolated lifecycle guards as defense-in-depth. A second document (HANDOFF-channel-io-performance.md) identified those same guards as causing a 15% register/deregister regression.

The tension was resolved by going to first principles: the `SerialExecutor` contract requires every enqueued job to eventually run. Fix A (`Kernel.Thread.Executor.enqueue()` runs jobs inline when dead) honors that contract at the executor level — one correct executor makes all actors on it correct automatically. The nonisolated guards were caller-side workarounds that duplicated lifecycle checks, forced explicit actor hops via `@concurrent`, and missed any new method added later. They were removed: `register()`, `transaction()` restored as direct actor-isolated methods; Selector halt guards removed.

Also fixed a missing brace in `Kernel.Thread.Executor.deinit` (the accidental revert flagged in the handoff). Verified 350 tests pass with clean exit. Audited public API (unchanged). Wrote three handoff files for future work (benchmark investigation, Selector Waiter pattern, poll-side dispatch). Mapped the full cancellation story across all swift-io subsystems. Discussed bounded registration and concluded current design is correct — transaction backpressure handles resource contention, capacity management belongs above the registration primitive.

## What Worked and What Didn't

**Worked: competing documents surfaced the real question.** The CQ handoff and performance handoff disagreed. Without the performance data, the guards would have been extended (adding `handle()`, `compareExchange` in `shutdown()`). The conflict forced a principled analysis rather than mechanical checkbox completion.

**Worked: first-principles resolution.** "Where should the invariant be enforced?" → "At the lowest level that can enforce it completely." This dissolved the entire guard/performance tradeoff — both sides were arguing about a layer that shouldn't own the invariant.

**Didn't work: the original handoff was wrong.** The CQ handoff was written before Fix A existed and recommended more guards as the path forward. The performance handoff claimed the guards were "fully reverted at HEAD" — also wrong (they were still present). Both documents had stale or incorrect claims. Verification against actual code state was essential.

## Patterns and Root Causes

**Enforcement point selection is a recurring architectural question.** The nonisolated guard pattern is "every caller checks before calling." The executor inline pattern is "the callee handles all cases." This maps to the general principle: push invariant enforcement to the narrowest bottleneck. For actor lifecycle, that's the executor (all actor hops go through it). For handle lifecycle, that's the actor itself (all handle access goes through it). Caller-side guards are appropriate only when the callee *cannot* enforce the invariant (e.g., `run()` bypassing the actor entirely for stateless lane operations).

**Handoff documents decay faster than code.** Two handoff files had incorrect claims about current state. The code is always ground truth. Handoffs are hypotheses about the code — useful for orientation, dangerous as directives.

**Cancellation coverage correlates with wait duration.** Subsystems that may block indefinitely (lane acceptance, transaction waiter parking, completion I/O) have full cancellation. Subsystems that complete in microseconds (registration, deregistration) don't. This is correct — the cancellation cost (handler setup, flag allocation, drain complexity) exceeds the operation duration.

## Action Items

- [ ] **[skill]** handoff: Add guidance that handoff claims about code state must be verified, not trusted — handoff documents are orientation, not directives
- [ ] **[research]** Should swift-io offer a bounded capacity manager (Layer 4 component) that composes register/transaction/semaphore for fd-limited use cases?
- [ ] **[package]** swift-io: The `@_optimize(none)` on `Async.Channel.Unbounded` send/receive is a Swift 6.3 CopyPropagation SIL crash workaround — revisit removal on Swift 6.4+
