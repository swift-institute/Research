---
date: 2026-04-08
session_objective: Complete IO.Blocking refactor execution, identify regressions, plan follow-ups
packages:
  - swift-io
  - swift-executors
  - swift-async-primitives
  - swift-collection-primitives
status: pending
---

# IO.Blocking Refactor Regressions — Honest Post-Completion Assessment

## What Happened

Continuation of the 2026-04-07/08 session. Four parallel agents completed
execution: Async.Semaphore (15 tests), Kernel.Thread.Semaphore (15 tests),
Kernel.Thread.Executor.Sharded creation (8 tests), Executor consolidation
(18 tests). A fifth agent executed the IO.Blocking refactor itself (Phase
1-4: delete swift-pools, create IO.Blocking.Driver, update Tier 0, delete
~114 files of bespoke machinery). The refactor completed successfully —
zero build errors, zero warnings.

Post-completion, an honest regressions analysis identified 4 real behavioral
regressions and 2 compiler-workaround concerns. A sixth agent was dispatched
to address the sync-path regression. A Cycle<Element> primitive was designed
(thread-safe round-robin selector) and a handoff written for
swift-collection-primitives.

## What Worked and What Didn't

**What worked**: The handoff-based delegation pattern scaled to 6 parallel
agents across 5 packages. Each agent received a self-contained execution
brief, loaded skills independently, and reported via Completion sections.
The "pedantic professor" framing early in the session produced the domain
model that made all subsequent decisions clean.

**What didn't work**: The regressions were discovered AFTER the refactor
landed, not during design. Three regressions (shared queue → round-robin,
sync path touching cooperative pool, T: Sendable on sync path) should have
been identified during the design phase. The root cause: I compared the
NEW design against the REQUIREMENTS (minimal API, honest naming, clean
architecture) but not against the OLD design's RUNTIME PROPERTIES (shared
queue load balancing, truly-sync submission, non-Sendable result types).

## Patterns and Root Causes

**Pattern: "Architecture reviews check structure; regression reviews check
behavior."** The design session spent hours on naming, layering, and type
placement — which produced a genuinely better architecture. But nobody asked
"does the new code do everything the old code did, at the same quality?"
until after it shipped. Structure and behavior are separate concerns; a
review that checks only one will miss regressions in the other.

**Root cause of the sync-path regression**: `Task<T, Error>` was used as a
convenience for wrapping the async path. But Task requires T: Sendable AND
runs on the cooperative pool. The old `_enqueue` path was purpose-built to
avoid both. The refactor optimized for simplicity (one path, not two) at
the cost of the sync path's defining property (zero cooperative pool
involvement). The lesson: when a code path exists for a SPECIFIC REASON
(avoiding the cooperative pool), the refactor must preserve that reason,
not just the API shape.

**Root cause of the shared-queue regression**: we chose Kernel.Thread.Executors
(round-robin to N independent serial executors) over a new
Kernel.Thread.Pool (N threads sharing one queue) to keep swift-kernel lean.
The trade-off was explicit but the severity was underestimated — round-robin
under high-variance workloads can leave capacity idle while jobs queue
behind a slow worker.

## Action Items

- [ ] **[skill]** implementation: Add [IMPL-084] "Regression Review Discipline" — after any refactor that replaces >10 files, enumerate the old code's RUNTIME PROPERTIES (not just API shape) and verify each is preserved, degraded-with-justification, or deliberately removed. Structure reviews catch structure bugs; behavior reviews catch behavior bugs. Do both.
- [ ] **[research]** Shared-queue executor variant — investigate whether `Kernel.Thread.Executor.Shared` (N threads consuming from one queue, work-stealing-like) should be added to swift-executors alongside the round-robin `Sharded`. Would address the load-balancing regression. Benchmark first.
- [ ] **[package]** swift-io: Track sync-path regression fix (another agent is working on it). The fix should restore zero-cooperative-pool submission via direct executor.enqueue(UnownedJob) without Task wrapping.
