---
date: 2026-04-03
session_objective: Audit and classify 10 @unchecked Sendable types in swift-io, eliminating those that can be replaced with principled alternatives
packages:
  - swift-io
status: pending
---

# @unchecked Sendable Audit — Classification Taxonomy and Layer-Boundary Discipline

## What Happened

Worked through all 9 suspects from HANDOFF-unchecked-sendable-audit.md (the 10th,
IO.Executor, was a comment reference confirmed as non-suspect). For each type: read
the file and safety invariant, classified the synchronization pattern, determined
whether the `@unchecked Sendable` could be removed.

**Results**: 1 fixed, 1 deferred, 7 upstream limitations.

The one fixable type — `IO.Completion.Driver.Handle` (#9) — turned out to have been
already fixed in a prior session (commit `9b846805`). The prior sending-over-sendable
migration had removed `@Sendable` from Driver witness closures and Poll.Context had
already dropped Sendable, so Handle's Sendable conformance was entirely unused. The
audit confirmed this was correct.

For suspect #6 (Abandoning.Job), initially proposed replacing `Kernel.Thread.Mutex`
with `Synchronization.Mutex` to make the class properly Sendable. User challenged
this: `Kernel.Thread.Mutex` is deliberate for kernel thread context — the Abandoning
lane runs on raw kernel threads, not the cooperative pool. The fix was retracted.

The 7 upstream limitations fall into three categories:
1. **Custom mutex verification** (#2, #3, #5, #6): `Kernel.Thread.DualSync` and
   `Kernel.Thread.Mutex` provide real synchronization but can't be verified by the
   compiler. DualSync adds condition variables that `Synchronization.Mutex` lacks.
2. **Continuation happens-before** (#1): `resume()` provides happens-before but the
   type system can't express it.
3. **Pointer non-Sendability** (#7, #8): `UnsafePointer` is unconditionally
   non-Sendable even with exclusive sequential ownership.

## What Worked and What Didn't

**Worked**: Parallel exploration agents traced transfer paths efficiently — the
Event.Batch bridge constraint, Driver.Handle Cell transfer, and Job.Instance field
Sendability were all answered in one round. The four-way classification framework
(mutex-protected, single-owner transfer, raw-pointer wrapper, continuation-synchronized)
mapped cleanly onto all 9 suspects.

**Didn't work**: The Synchronization.Mutex proposal for #6 was a type-system-motivated
refactoring that ignored the infrastructure layer's deliberate mutex choice. The user
caught this before it shipped. The lesson: satisfying the type checker is not a goal
unto itself when it means changing the synchronization primitive.

**Confidence gap**: Initially high confidence that #6 was fixable. The fields were
all Sendable, the pattern was textbook Mutex wrapping. But the question was wrong —
it wasn't "can this become properly Sendable?" but "should the mutex type change?"

## Patterns and Root Causes

**Most @unchecked Sendable in swift-io is principled.** The audit expected to find
fixable types; instead it found that 7/9 are genuinely blocked by compiler limitations.
The codebase's synchronization patterns — DualSync with condition variables, atomic
CAS protocols, continuation happens-before — are correct but unverifiable. This isn't
tech debt; it's the boundary between what the type system can express and what the
runtime requires.

**Layer boundaries constrain type-level fixes.** The #6 incident reveals a pattern:
when infrastructure layers choose specific synchronization primitives (kernel mutexes
vs cooperative mutexes, DualSync vs Mutex), those choices encode non-functional
requirements (thread context, condition variable support, priority inheritance) that
type-system refactoring must respect. "Use Synchronization.Mutex so the class becomes
Sendable" is the same category of error as "use Foundation so you get Codable for free"
— it's trading infrastructure invariants for type-level convenience.

**Cascade effects create fixability.** The only fixable type (#9) was fixable because
the prior sending-over-sendable migration removed the constraints (witness @Sendable,
Context Sendable) that forced Handle to be Sendable. Without that prior work, Handle
would still need @unchecked Sendable. This suggests that @unchecked Sendable
elimination is best done as a cascade from broader isolation redesign, not as an
isolated audit.

## Action Items

- [ ] **[skill]** memory-safety: Add guidance that replacing `Kernel.Thread.Mutex` with `Synchronization.Mutex` is forbidden when code runs on raw kernel threads — mutex type encodes thread-context requirements, not just mutual exclusion
- [ ] **[research]** What Swift language features would be needed to verify custom mutex discipline? Survey SE proposals and pitch threads for lock-isolation protocols
- [ ] **[package]** swift-io: The nonsendable-operation-closures investigation (HANDOFF-nonsendable-operation-closures.md) is the highest-leverage remaining work — it unblocks #4, affects #6, and improves the public API
