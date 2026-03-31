---
date: 2026-03-30
session_objective: Implement IO.Lane boundary completion (Batches 1A-2B) from converged Claude-ChatGPT plan
packages:
  - swift-io
status: pending
---

# IO.Lane Boundary Completion and `do throws(E)` Discovery

## What Happened

Implemented the full converged plan for IO.Lane boundary completion in 3 commits:

- **Batch 1A+1B** (`77a0e36`): Added 3 `run` overloads + 1 `open` forwarder to IO.Lane. IO.run and IO.open simplified to thin delegation. IO.Executor.run.swift deleted (dead code). No stale "Pool" terminology found.
- **Batch 2A** (`740546f`): Re-parameterized IO.Pending/IO.Ready from `IO.Blocking.Lane` to `IO.Lane`. Added `IO.Lane.Count` typealias. Visibility audit confirmed all `public import IO_Blocking` needed for `@inlinable`. Added IO.Ready `where L == IO.Lane` execution extension.
- **Batch 2B** (`50ceb60`): Replaced all 18 `catch let e as E` + `fatalError("Unexpected error type")` instances with `do throws(E) { }` typed catch blocks. Zero runtime traps remaining.

Separately investigated the flaky `IO.Event.Selector.Iteration.Tests` (EBADF/EPIPE). Root cause: fd recycling race. Designed dup() + ~Copyable ownership fix. User refined the design — Kernel.Descriptor should be natively ~Copyable instead of an `Owned<Tag>` wrapper. Handoff created.

## What Worked and What Didn't

**Worked well:**
- The converged plan's batching was exactly right. Batch 1A created the foundation (IO.Lane.run), making Batch 2A mechanical (re-parameterize Pending/Ready). Each batch was a clean commit.
- IO.Lane.Handle was the correct model. Recognizing "IO.Lane is incomplete, not unnecessary" was the key insight from the audit.
- The handoff documents from the prior session were precise enough to implement without re-investigation.

**Didn't work initially:**
- First attempt at `catch as E` cleanup used plain `catch { error }` — compiler inferred `any Error`. Needed `do throws(E) { }` to give the catch block the concrete type. The user provided the key hint.
- Initially assessed Batch 2B as "no changes needed" for the catch pattern. Wrong — `do throws(E)` was the fix, I just didn't know the syntax existed.

**Confidence gaps:**
- Visibility audit: I correctly identified that `public import IO_Blocking` is required by `@inlinable`, but only after considering and rejecting narrowing. The relationship between `@inlinable` and import visibility is non-obvious.

## Patterns and Root Causes

**Pattern: "The main type should be owned."** The user's refinement of the fd ownership design — from `Owned<Tag>` wrapper to native ~Copyable `Kernel.Descriptor` — follows the same principle as String (owned, not a wrapper around UnsafeBufferPointer). When a type represents a resource with lifecycle, ownership should be native to the type, not bolted on via a wrapper. The wrapper pattern (`Owned<Tag>`) duplicates what the type should express natively.

**Pattern: `@inlinable` constrains visibility.** The `public import IO_Blocking` in exports.swift looked like a layer leak. It's actually required by the inlining contract — @inlinable code that references IO.Blocking types must have those types visible at the downstream call site. This means boundary narrowing (making IO.Blocking invisible) requires either: (a) removing @inlinable from affected methods, or (b) accepting the visibility. Since @inlinable is load-bearing for performance, (b) is correct.

**Pattern: `do throws(E)` completes the typed-throws story.** Swift 6 has `throws(E)` on functions and closures, but catch blocks inside non-throwing closures still infer `any Error`. `do throws(E) { }` is the missing piece — it tells the compiler "this do block only throws E, so the catch block gets E." This eliminates the `catch let e as E` + `fatalError` pattern entirely. The pattern was a workaround for a feature that existed but we didn't know about.

## Action Items

- [ ] **[skill]** implementation: Add `do throws(E) { }` as the canonical pattern for typed catch blocks inside non-throwing contexts. Reference [IMPL-060] (centralized error handling). The `catch let e as E` + `fatalError` pattern is now a known anti-pattern.
- [ ] **[skill]** memory-safety: Add guidance that resource types (fd, handle) should be natively ~Copyable, not wrapped in an `Owned<Tag>`. The main type should express ownership. Wrapper pattern is for cross-module adaptation, not for types you control.
- [ ] **[package]** swift-io: The IO.open scoped overload (IO.open.swift:104-186) duplicates IO.Ready.callAsFunction. After re-parameterization both use IO.Lane.run. Deduplication would require adding `deadline` to the builder — deferred but tracked.
