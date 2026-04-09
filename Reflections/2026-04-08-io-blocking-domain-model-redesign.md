---
date: 2026-04-08
session_objective: Deep dive into IO.Blocking subsystem — identify bloat, design minimal public API, restructure to mirror IO.Event Driver pattern
packages:
  - swift-io
  - swift-pools
  - swift-pool-primitives
  - swift-kernel
  - swift-async-primitives
  - swift-executors
status: pending
---

# IO.Blocking Domain Model Redesign — From Surface Cleanup to Category-Error Discovery

## What Happened

Session spanned 2026-04-07 to 2026-04-08. Started as a "deep dive into
IO.Blocking bloat" and evolved into an ecosystem-wide domain-model
correction across six packages.

**Phase 1 — Surface audit.** Catalogued the current IO.Blocking surface:
~50 public types across 56 files in `IO Blocking` and `IO Blocking Threads`
modules. Identified triple-layered duplication (IO.Blocking.Threads →
IO.Blocking.Lane → IO.Lane), the Abandoning subsystem (17 types, doc
disclaim says "production code should never use this"), and the overloaded
"Blocking" namespace collision.

**Phase 2 — Driver pattern proposal.** User asked "why isn't Blocking a
Driver like Events and Completions?" This shifted the work from surface
cleanup to structural alignment. Proposed IO.Blocking.Driver (~Copyable
struct) mirroring IO.Event.Driver, plus IO.Blocking.Loop (rejected — no
polling to integrate, unlike Events).

**Phase 3 — Kernel.Thread.Pool proposal (rejected).** Proposed adding a
new Kernel.Thread.Pool primitive to swift-kernel. User pushed back: "keep
swift-kernel lean." Pivoted to using existing Kernel.Thread.Executors +
Pool.Bounded for admission control.

**Phase 4 — Pool.Blocking → Semaphore discovery.** Investigated Pool.Blocking
and Pool.Bounded to verify they could compose into the IO layer. Discovered:
(a) Pool.Bounded and Pool.Blocking have ZERO production consumers anywhere
in the monorepo — the Extended Findings investigation confirmed this via
grep. (b) Pool.Blocking is operationally a counting semaphore, not a pool —
proved via line-by-line Dijkstra mapping. (c) Pool.Bounded<Slot> with empty
Slot is a degenerate counting semaphore — the Slot is phantom, the pool
machinery is vestigial. These are category errors in the current naming.

**Phase 5 — "Pedantic professor" domain model review.** User asked me to
assume the role of a pedantic university professor. This produced the
sharpest insights of the session: three category errors (Pool.Semaphore is
not a pool; Pool.Worker.Sharded is not a pool; shared vocabulary types are
in the wrong home), the principled decomposition into three concurrency
families (synchronization primitives, resource pools, execution dispatchers),
and the recommendation to place types in their honest families rather than a
shared Pool.* namespace.

**Phase 6 — Final architecture.** After multiple iterations, converged on:
- `Kernel.Thread.Semaphore` in swift-kernel (thread-blocking, ports Pool.Blocking)
- `Async.Semaphore` in swift-async-primitives (task-suspending, replaces Pool.Bounded<Slot> hack)
- `Kernel.Thread.Executor.Sharded` in new swift-executors package (moved from swift-kernel)
- swift-pools DELETED (sole type relocated)
- swift-io IO.Blocking refactor composes Async.Semaphore + Executor.Sharded

Dispatched three execution handoffs for parallel agent work on 1, 2, 3.
Also completed: Pool.Bounded ownership-transfer-conventions (commit bb9771b,
79 tests green).

## What Worked and What Didn't

**What worked:**

The user's progressive questioning pattern was the highest-value contributor.
Each pushback revealed a deeper structural issue:
- "Why not a Driver?" → exposed the Lane/Threads duplication
- "Keep kernel lean" → forced reuse of existing primitives
- "Isn't IO.Lane just an implementation detail?" → collapsed the wrapper layer
- "Why not one IO.Driver?" → surfaced the unified reactor vision
- "Review as a pedantic professor" → exposed category errors in Pool.*

The handoff pattern worked well for delegation: the ownership-transfer-conventions
handoff completed independently (bb9771b), the validation handoff returned
substantive findings (Extended Findings: "FRAGMENTED — worse than parent thinks"),
and the parallel execution handoffs were dispatched cleanly.

**What didn't work:**

I accepted the Pool.* namespace for too long. Multiple iterations proposed
Pool.Semaphore, Pool.Worker.Sharded, Pool.Executor.Sharded — all of which
are category errors. I should have questioned the namespace at the same time
I questioned the types. The professor framing forced this; I didn't do it
voluntarily.

I repeatedly confused Pool.Bounded's package location (L1 swift-pool-primitives)
with swift-pools (L3) — a factual error the validation agent caught. This
indicates I was reasoning about the packages abstractly without verifying
the physical layout.

The initial "surface cleanup" framing was far too shallow. The session needed
to go to the domain-model level from the start. The surface bloat was a
symptom of category errors in the underlying design, not a cause.

## Patterns and Root Causes

**Pattern: "Name it what it is, not where it used to live."** Pool.Blocking
was always a semaphore. Nobody questioned the name because it lived in
swift-pools. The name-as-address pattern — types named for their package
rather than their concept — is a recurring source of confusion. The fix is
the same every time: ask "what IS this type, independent of where it lives?"

**Pattern: "Degenerate usage reveals the wrong primitive."** Pool.Bounded<Slot>
with an empty Slot type is using a resource pool as a counting semaphore.
When a type parameter is phantom (no state, no identity, no lifecycle),
the generic type is being used in its degenerate mode, and the degenerate
mode usually has a proper name. The proper name is the honest type.
Recognizing degenerate usage is a general skill: if you have to explain
"the Slot is actually nothing" to a reader, the abstraction is wrong.

**Pattern: "Category errors compound through layers."** The Pool.Blocking
category error (semaphore filed as pool) propagated upward: swift-io built
its own admission queue rather than importing Pool.Blocking (because
Pool.Blocking is sync and swift-io needs async), and the proposed refactor
initially proposed Pool.Bounded<Slot> as the replacement (inheriting the
category confusion from Pool.Bounded's own API). Each layer that consumed
the wrong primitive added more mechanism to compensate for the mismatch.

**Root cause: the ecosystem's synchronization-primitive families are named
for their blocking model (Kernel.Thread.* / Async.*), not for their
primitive category (Sync.*).** This historical naming makes it non-obvious
that Kernel.Thread.Gate and Async.Gate are the same concept in two
concurrency models. Adding Semaphore to both families is correct within
this historical scheme; the full fix (Sync.* unification) is a separate
project.

## Action Items

- [ ] **[skill]** implementation: Add [IMPL-083] "Degenerate Usage Detection" — when a generic type parameter is phantom (empty struct, no state, no lifecycle), the type is being used in its degenerate mode. The degenerate mode usually has a proper name. Recognize and replace.
- [ ] **[research]** Sync.* namespace unification — design the ecosystem-wide migration from {Kernel.Thread.*, Async.*} to a unified Sync.{Mutex, Gate, Barrier, Semaphore, Waiter}.{Thread, Task} taxonomy. Scope: swift-kernel-primitives, swift-kernel, swift-async-primitives. Not urgent; schedule when someone has budget for the full migration.
- [ ] **[package]** swift-pools: Track deletion. Once Kernel.Thread.Semaphore lands and swift-io no longer depends on Pool.Blocking, delete the package entirely. Pool.Bounded stays in swift-pool-primitives (genuine resource pool, awaiting first real consumer).
