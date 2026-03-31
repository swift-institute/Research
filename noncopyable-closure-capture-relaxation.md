# ~Copyable Closure Capture Consumption Relaxation

<!--
---
title: ~Copyable Closure Capture Consumption Relaxation
status: IN_PROGRESS
tier: 2
created: 2026-03-31
applies_to: [swift-async-primitives, swift-io, swift-ownership-primitives]
---
-->

## Context

Non-escaping closures in Swift cannot consume a `~Copyable` capture without reinitializing it, even when the callee guarantees total consumption. This forces an `Ownership.Slot` heap allocation per closure invocation in patterns like `withLock { state in state.send(consuming element) }`.

## Question

Can the closure capture reinitialization rule be relaxed for non-escaping closures where the consuming callee guarantees total consumption? If so, would a Swift Evolution pitch eliminate the Slot-per-send overhead?

## Analysis

**Current behavior**: The compiler sees a captured `~Copyable` value passed to a `consuming` parameter inside a closure body. It requires the capture to be reinitialized after the consuming call, regardless of:
- Whether the closure is `@escaping` or non-escaping
- Whether the consuming function is total (guaranteed to consume on all paths)
- Whether the capture is consumed exactly once on all lexical paths

**The workaround**: Stage through `Ownership.Slot` (a `@unchecked Sendable` class wrapper). The Slot is `Copyable`, so closure capture is unaffected. The `~Copyable` element is stored in the Slot before the closure, then `.take()`'d inside.

**Cost of workaround**: One class allocation + two atomic CAS operations per send on the fast path (Slot init + take). For high-throughput channels, this is measurable.

**Possible relaxation**: If the compiler could verify that a non-escaping closure consumes a capture exactly once on all paths (no reinitializing, no skipping), the capture could be allowed to move through without Slot wrapping. This would require:
1. Extending the move checker to track closure captures through non-escaping calls
2. Possibly a new attribute or inference rule for "totally consuming" closures

## Outcome

*Pending investigation — requires compiler expertise to assess feasibility.*

## References

- [MEM-COPY-006] Category 6 — documents the limitation and workaround
- [MEM-OWN-010] — ecosystem pattern that works around this
- [IMPL-070] — end-state coroutine pattern that avoids closures entirely
- 2026-03-27-async-channel-noncopyable-restructure.md — discovery session
