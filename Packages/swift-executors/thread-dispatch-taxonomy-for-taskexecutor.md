---
title: Thread-Dispatch Taxonomy for TaskExecutor Conformance
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-foundations
  - swift-threads
  - swift-executors
  - swift-io
---

# Context

The strict-mission thread-layer refactor extracted `Kernel.Thread.Pool`
to a new `swift-threads` package with fine-grained per-type targets.
Along the way, several distinct thread-dispatch patterns surfaced:
direct (one thread per call), pooled (admission-gated), queued
(serialized, FIFO), sharded (round-robin across N pools). Each maps
differently to Swift's `TaskExecutor` / `SerialExecutor` protocols, and
each has different guarantees around concurrency, ordering, and
fairness. Without a taxonomy, every new thread-dispatch consumer
re-derives the choice.

# Question

What are the canonical thread-dispatch patterns used in the
swift-foundations ecosystem, and how do they map to Swift's
`TaskExecutor` / `SerialExecutor` shapes? Specifically:

- Classify the patterns currently in use (direct, pooled, queued,
  sharded, stealing) with precise definitions.
- For each pattern, identify the right Swift executor shape
  (TaskExecutor vs SerialExecutor, pinned vs ambient, one-shot vs
  long-lived).
- Identify patterns that do NOT fit any existing executor shape and
  need a new primitive (if any).
- Document the trade-off matrix: concurrency, ordering, fairness,
  shutdown semantics, cancellation, admission.

# Prior Work

- `swift-foundations/swift-io/Research/executor-conformance-inventory.md`
- `swift-foundations/swift-io/Research/executor-conformance-triage.md`
- `swift-foundations/swift-io/Research/executor-lifecycle-literature-study.md`
- `swift-foundations/swift-io/Research/io-blocking-executor-binding.md`
- Source reflection: `swift-io/Research/Reflections/2026-04-14-strict-mission-thread-layer-refactor.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Do we need a distinct `Kernel.Thread.Executor.Direct` for the
  one-shot case, or is that `Task.detached` with a task-local
  executor preference?
- Sharded pools: currently `IO.Blocking` uses `Sharded<Kernel.Thread.Executor>`
  — is "sharded" itself an executor shape, or a pool-of-executors
  composition?
- Cross-platform mapping: Windows threadpool, Linux pthread, Darwin
  pthread/Mach — does the taxonomy survive the platform differences?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-foundations/swift-io/Research/Reflections/2026-04-14-strict-mission-thread-layer-refactor.md` action item.
