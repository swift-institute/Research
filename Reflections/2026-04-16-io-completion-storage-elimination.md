---
date: 2026-04-16
session_objective: Determine whether IO.Completion.Storage can be eliminated, restructured, or pushed to the kernel layer
packages:
  - swift-io
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Added [IMPL-093] Optional-capture reinitialization for ~Copyable async closure boundaries
  - type: package_insight
    target: swift-io
    description: Stale README.md in Sources/IO Completions/ — references Storage, Unmanaged, old dispatch flow (noted for follow-up)
  - type: experiment_topic
    target: swift-io
    description: Linux io_uring CQE dispatch verification (deferred — Linux-only testable)
---

# IO.Completion.Storage Elimination — Dictionary as Sole Correlation and Lifetime Manager

## What Happened

Fresh-take investigation into whether `IO.Completion.Storage` (a 145 LOC `final class` bridging the submit-to-complete window in the proactor) could be eliminated. The handoff prescribed investigating five sub-questions in a specific order: typed throwing continuations (Q5) first, then checkCancellations redesign (Q3), with remaining sub-questions as needed.

**Q5 finding**: `CheckedContinuation<Kernel.Completion.Event?, Never>` carries the event directly. No typed throws needed — the non-throwing continuation accepts any `Sendable` return type, and `Kernel.Completion.Event` is `Sendable`. This eliminated Storage's result-slot purpose (the `event` side-channel).

**Q3 finding**: `checkCancellations` can be eliminated entirely. The flag check moves into `dispatch()`: when a CQE arrives for a flagged entry, resolve as cancelled. Entries survive in the dictionary until CQE arrival, keeping the dup'd descriptor alive across the kernel's custody window. This eliminated Storage's retained-pointer purpose (`Unmanaged.passRetained`/`takeRetainedValue`).

**Latent bug discovered**: The prior session's refactor deleted `translateEvent` (which converted pointer-based CQE tokens to counter-based dictionary keys) but left `dispatch()` looking up entries by the raw kernel token (a pointer). Entries were stored under counter keys. Pointer != counter — `entries.remove(event.token)` never matched on the io_uring path. Same mismatch in the cancel target. Masked by macOS-only test coverage. The redesign fixed this by using the counter as both the dictionary key and the submission token.

**Implementation**: Deleted Storage.swift. Entry absorbed all per-operation state. Continuation changed to `Event?`. `dispatch()` integrated the flag check. `submit()` sets `submission.token = id` (counter). One compiler issue: `consuming Kernel.Descriptor?` cannot be captured by the async `withTaskCancellationHandler` closure. Fix: `descriptor = nil` reinitializes the Optional capture after the consuming move into Entry — pure language semantics, no new types needed.

Result: 3 files changed, 177 insertions, 276 deletions. 53/53 tests pass. Zero `@_spi(Syscall)`. Zero `Unmanaged`.

## What Worked and What Didn't

**Worked — investigation order**: Q5 before Q3 was the right call. The typed-continuation finding (Event? carries the result) shaped the Q3 approach (entries as sole record, no side-channel). If Q3 had been investigated first, the side-channel would have remained as a constraint.

**Worked — fresh-take framing**: Starting from "what does the proactor crossing point NEED?" instead of "how do we improve Storage?" surfaced the latent token-correlation bug. The prior session anchored on Storage as given and missed the pointer-counter mismatch because it was debugging within Storage's frame, not questioning the frame itself.

**Worked — language semantics over new types**: The `descriptor = nil` reinitialization was initially surprising — the compiler error message ("missing reinitialization of closure capture after consume") literally prescribed the fix. No `DescriptorBox` class, no ownership-primitives import, no new types. The consuming parameter becomes a local Optional, consumed into Entry, then reinitialized to nil. The compiler's ownership checker saw a valid state for the rest of the function body.

**Didn't work initially — assumed typed throws needed**: The first instinct for Q5 was to investigate `CheckedContinuation<Int, IO.Error>` (typed throwing continuation). This led to discovering the overload-resolution bug in `withCheckedThrowingContinuation` where the compiler prefers the untyped overload. But the insight that mattered was simpler: `CheckedContinuation<Event?, Never>` — encode cancellation as `nil`, not as a thrown error. Optional is the right discriminator for "event arrived vs. cancelled."

## Patterns and Root Causes

**Pattern: retained-pointer as symptom of premature entry removal.** The `Unmanaged.passRetained` pattern existed because `checkCancellations` removed entries before the CQE arrived. The retained pointer kept Storage (and its fd) alive across this gap. Eliminating early removal eliminated the gap. The retained pointer was a workaround for a design choice (eager cancellation resolution), not an intrinsic requirement of the proactor model. The question "is this invariant load-bearing?" ([IMPL-086]) applied at the mechanism level: the retained pointer defended the invariant "fd survives until CQE," but the invariant could be maintained by a simpler mechanism (dictionary retention).

**Pattern: token identity conflation.** Using a pointer as both a correlation token and a retention mechanism (ARC reference count) conflated two concerns. When `translateEvent` was removed, the correlation half broke silently because the retention half still worked (the CQE's pointer could still be recovered for `takeRetainedValue`). Single-purpose tokens (a counter is ONLY a correlation key) are immune to this class of silent breakage.

**Pattern: Optional capture reinitialization for ~Copyable async boundaries.** The `descriptor = nil` pattern is the minimal bridge for moving a `~Copyable` value into a closure body that the compiler treats as an async (implicitly escaping) capture context. The consuming move transfers ownership to Entry; the nil reinitialization satisfies the ownership checker that the capture slot is valid for the closure's remaining lifetime. This is a language-level pattern, not an ecosystem-level abstraction.

## Action Items

- [ ] **[skill]** implementation: Add [IMPL-093] documenting the Optional-capture reinitialization pattern for ~Copyable values crossing async closure boundaries (`descriptor = nil` after `consume descriptor` in async closure body)
- [ ] **[package]** swift-io: Update stale README.md in Sources/IO Completions/ — still references Storage, Unmanaged, and the old dispatch flow
- [ ] **[experiment]** Verify IO.Completion dispatch path on Linux (io_uring) — the token-correlation fix is load-bearing but only testable on Linux; macOS tests don't exercise CQE dispatch
