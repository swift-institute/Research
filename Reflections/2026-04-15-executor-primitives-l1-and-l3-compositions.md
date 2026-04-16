---
date: 2026-04-15
session_objective: Implement swift-executor-primitives (L1) and refactor swift-executors (L3) with 5 new compositions
packages:
  - swift-executor-primitives
  - swift-executors
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: skill_update
    target: implementation
    description: "Added [IMPL-088] Lock-Ordering Analysis for Multi-Lock Compositions (ABBA prevention)"
  - type: skill_update
    target: implementation
    description: "Added [PATTERN-055] @usableFromInline + internal import error pair"
  - type: package_insight
    target: swift-heap-primitives
    description: "Added 'Heap.Min Is a Stub — Implement or Remove' to Research/_Package-Insights.md"
---

# Executor Primitives L1 and L3 Compositions — Layering Discoveries and ~Copyable Atomics

## What Happened

Created `swift-executor-primitives` (L1, tier 20) as a new package in swift-primitives with 6 modules and 13 tests: Job.Queue, Job.Deque, Job.Priority, Shutdown.Flag, Wait.Event.Source, plus namespace enums in Core. Then refactored swift-executors (L3) to depend on these primitives: deleted the old internal Job.Queue, rewrote Kernel.Thread.Executor internals, added Executor.Wait.Condvar at L3, and implemented 5 new compositions (Cooperative, Main, Scheduled, Stealing, Polling). 18 tests passing at L3.

Three deviations from the research doc emerged during implementation:

1. **Condvar cannot live at L1** — `Kernel.Thread.Condition` and `Kernel.Thread.Mutex` at L1 are empty stubs pointing to L2/L3 implementations. The research doc placed Condvar at L1 without checking this. Moved to L3 where `Kernel.Thread.Synchronization<1>` is available. Zero downstream impact since all Condvar consumers are L3.

2. **`Shutdown.Flag` must be `~Copyable`** — `Atomic<Bool>` from stdlib `Synchronization` is `~Copyable`. The research doc declared `struct Flag: Sendable` without `~Copyable`. Supervised and confirmed: `~Copyable, Sendable` struct is the correct posture per `feedback_no_degrade_noncopyable.md`.

3. **`Heap.Min` is a stub** — fatalErrors on init. Used base `Heap<Entry>` with `order: .ascending` instead.

Two critical bugs were caught by supervision review: ABBA deadlock in Stealing's lock ordering (trySteal under own lock), and base.enqueue under Scheduled's lock (fragile lock ordering). Both fixed by separating lock scopes.

## What Worked and What Didn't

**Worked well**: The research doc's taxonomy held up — all 7 compositions compiled and tested without structural changes to the composition architecture. The L1/L3 split was cleaner than expected. The modularization (per-type variant targets with distinct dependency sets) proved correct: Event.Source needs kernel-primitives, Priority needs heap-primitives, Queue/Deque need queue-primitives. No wasted dependencies.

**Didn't work**: The research doc contained three tier-level errors (Condvar placement, Heap.Min availability, Shutdown.Flag copyability) that were only discoverable by reading the actual L1 source code. The research phase validated the taxonomy's logical structure but never compiled against the real primitives layer. A "compile the L1 skeleton first, then validate the research doc" order would have caught these earlier.

**Mixed**: Supervision reviews added genuine value (ABBA deadlock, lock ordering, Entry visibility) but also raised one point (Polling `#if !os(Windows)` as a violation) that contradicted the user's ratified decision. The HANDOFF's directive correctly took precedence.

## Patterns and Root Causes

**Research docs validate logic but not layers.** The Condvar/Heap.Min/Flag errors share a root cause: the research phase reasoned about type relationships and API shapes without checking whether the underlying types actually exist at the assumed layer. This is a category of error specific to multi-layer architectures — a type name can appear in documentation and discussion long before its implementation is verified at a specific tier. The fix is mechanical: before ratifying any L1 placement decision, `swift build` the type's init against the actual L1 package. A 30-second compile check would have prevented three deviation discoveries mid-implementation.

**Lock ordering in concurrent compositions is under-specified by the research doc.** The ABBA deadlock (Stealing) and nested-lock fragility (Scheduled) were invisible in the pseudo-code because the research doc described lock scopes implicitly via indentation, not explicitly via scope analysis. V5's race-safety table lists per-type arguments but doesn't analyze cross-lock interactions within a type. Adding a "lock ordering" column to V5 would have caught both issues.

**`@usableFromInline` + `internal import` is a common error pair.** The Condvar's first compile attempt failed because `@usableFromInline` on a property requires the property's type to be at least `@usableFromInline`, but `internal import Thread_Synchronization` made the type invisible. This is the third time this pair has caused a first-compile failure in ecosystem work. The fix (downgrade to `private` + remove `@inlinable`) is always the same.

## Action Items

- [ ] **[skill]** implementation: Add guidance on lock-ordering analysis for compositions that hold multiple locks — specifically: "Never acquire lock B while holding lock A unless a total ordering is documented. Separate lock scopes by default." Reference the Stealing ABBA fix as canonical example.
- [ ] **[skill]** implementation: Add `@usableFromInline` + `internal import` to the "common compile errors" quick-reference (alongside the existing `~Copyable` constraint patterns). Pattern: "If the property is `@usableFromInline`, the type must be publicly visible; `internal import` prevents this."
- [ ] **[package]** swift-heap-primitives: `Heap.Min` is a non-functional stub. Either implement it or remove the type declaration to prevent research docs from assuming it works.
