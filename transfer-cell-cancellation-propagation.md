# Transfer.Cell and Task Cancellation Propagation

<!--
---
title: Transfer.Cell and Task Cancellation Propagation
status: IN_PROGRESS
tier: 2
created: 2026-03-31
applies_to: [swift-ownership-primitives, swift-io, swift-async-primitives]
---
-->

## Context

`Task.detached` cancellation does not propagate through `Ownership.Transfer.Cell.take()`. A detached task that takes a ~Copyable value via Transfer.Cell, then suspends in an async operation (e.g., `Async.Channel.Unbounded.Receiver.receive()`), does not receive cancellation when `task.cancel()` is called. The cancellation tests hang indefinitely.

## Question

Is this a Transfer.Cell implementation issue, a Receiver.receive() issue, or a fundamental limitation of the ~Copyable task transfer pattern? Where in the chain does cancellation propagation break?

## Analysis

**Cancellation chain**: `task.cancel()` → sets task cancellation flag → `withTaskCancellationHandler` in `receive()` should fire → handler calls `cancel()` on the channel subscription → subscriber unblocked.

**Hypothesis 1 — Transfer.Cell blocks cancel propagation**: `Transfer.Cell.take()` suspends waiting for the cell to be populated. If this suspension doesn't register a cancellation handler, the task's cancellation flag is set but nobody checks it until `take()` completes. The subsequent `receive()` call would then see the flag immediately — but never gets the chance to execute.

**Hypothesis 2 — Timing issue**: The `withTaskCancellationHandler` in `receive()` registers the handler AFTER the function starts. If `cancel()` fires before the handler is registered, the cancellation is already set (flag-based) but the handler was never installed to act on it. `receive()` should check `Task.isCancelled` at the start — does it?

**Hypothesis 3 — @Sendable closure barrier**: Transfer.Cell requires a `@Sendable` closure for the continuation. ~Copyable values cannot be captured in `@Sendable` closures. If the internal implementation uses a continuation-based suspension, the cancellation handler might not compose correctly.

## Outcome

*Pending investigation — requires reading Transfer.Cell implementation and tracing the cancellation path through a debugger or targeted experiment.*

## References

- `swift-io/Research/split-cancellation-propagation.md` — related investigation already in swift-io
- [MEM-COPY-006] Category 6 — closure capture issues with ~Copyable
- 2026-03-30-split-tests-and-test-infrastructure-limits.md — discovery session
