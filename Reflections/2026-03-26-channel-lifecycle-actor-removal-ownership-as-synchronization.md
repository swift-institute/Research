---
date: 2026-03-26
session_objective: Investigate and fix swift-io channel I/O performance gaps vs SwiftNIO
packages:
  - swift-io
status: processed
processed_date: 2026-03-26
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-063] ownership subsumes synchronization — ~Copyable types need no actors/atomics for mutating state
  - type: research_topic
    target: noncopyable-synchronization-ecosystem-audit.md
    description: Audit ecosystem for ~Copyable types with unnecessary synchronization primitives
  - type: package_insight
    target: swift-io
    description: Remaining 2-3.5x channel gap is architectural (Selector actor hop) — evaluate EV_CLEAR and read-draining
---

# Channel Lifecycle Actor Removal — Ownership as Synchronization

## What Happened

Session started from a HANDOFF.md documenting 5-6x channel I/O gaps between swift-io and SwiftNIO. The io-bench and nio-bench suites were already in place with 15 matching tests. NIO won 10.

Explored three agents in parallel to map the full architecture: benchmark code, channel implementation, and fairness audit. Identified three compounding costs on the hot path: (1) `actor Lifecycle` hop on every read/write, (2) Selector actor hop per arm cycle, (3) one-shot re-arm overhead.

Key discovery: the NIO echo benchmark was unfair — it pipelined 1000 writes without reading echoed data, while IO did true round-trips.

Implemented Phase 1: replaced `actor Lifecycle` with a stored `HalfClose.State` property. Refactored `Shutdown` from actor-capturing struct to `@safe ~Escapable` view. Write throughput improved 3x (4.06ms → 1.36ms), read improved 1.6x (3.42ms → 2.17ms).

Attempted Phase 3: nonisolated Mutex permit fast-path on Selector. Reverted — permits are rare in throughput benchmarks, so the Mutex lock overhead on every processEvent() was pure cost.

## What Worked and What Didn't

**Worked**: The initial analysis correctly identified the lifecycle actor as the dominant per-call cost. The `~Copyable` ownership insight was the key — recognizing that an actor is mechanism for a concurrency problem that doesn't exist on a single-owner type. This wasn't just a performance optimization but a design correction.

**Worked**: Parallel agent exploration — three agents simultaneously mapping benchmarks, implementation, and fairness gave a comprehensive picture within minutes.

**Didn't work**: The Phase 3 nonisolated permit fast-path was wrong. The initial proposal (Mutex for permits) assumed permits would be common on the read hot path. In reality, for throughput benchmarks, events arrive AFTER arm (waiter path), not before (permit path). The optimization targeted the wrong branch. Should have profiled actual permit hit rates before implementing.

**Didn't work**: Initial Phase 1 proposal was `Atomic<UInt8>` — also wrong. An atomic provides synchronization for concurrent access, but `~Copyable` already prevents concurrent access. The correct fix was simpler: a plain stored property. The skills (`/implementation` [IMPL-INTENT], `/memory-safety` [MEM-COPY-001]) correctly guided away from the atomic approach when consulted.

## Patterns and Root Causes

**Ownership subsumes synchronization**: When a type is `~Copyable` with `mutating` methods, the compiler guarantees exclusive access. Adding actors, atomics, or locks to protect such state is mechanism without purpose. This pattern likely exists elsewhere in the ecosystem — any `~Copyable` type that uses actors or atomics for internal state protection is a candidate for the same fix.

**"Optimize the common path" requires knowing which path is common**: Phase 3 failed because the permit fast-path optimized a branch that's rarely taken in the benchmark. The arm path (waiter + suspend) is the common case for reads. The lesson: before implementing an optimization, instrument or reason about which branch dominates. A permit is a readiness-before-arm event — structurally rare when the reader is faster than the writer.

**Benchmark fairness is a prerequisite**: The NIO echo benchmark was measuring pipelined writes, not echo round-trips. Any comparison based on it was invalid. Fairness auditing should precede optimization work, not follow it.

## Action Items

- [ ] **[skill]** implementation: Add guidance that `~Copyable` types with `mutating` methods need no synchronization for stored state — actors/atomics are mechanism for a non-existent problem. Cross-ref [MEM-COPY-001].
- [ ] **[research]** Audit ecosystem for other `~Copyable` types that use actors or atomics for internal state protection — candidates for the same lifecycle actor removal pattern.
- [ ] **[package]** swift-io: The remaining 2-3.5x channel gap is architectural (Selector actor hop per arm). Evaluate EV_CLEAR (level-triggered) to reduce arm frequency, and read-draining to reduce arm count per transfer.
