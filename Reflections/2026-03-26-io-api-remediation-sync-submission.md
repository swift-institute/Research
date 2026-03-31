---
date: 2026-03-26
session_objective: Execute HANDOFF-api-remediation.md — sync submission API, Handle type, visibility cleanup
packages:
  - swift-io
  - swift-kernel
  - swift-witnesses
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: package_insight
    target: swift-io
    description: IO.run sync/async overload ambiguity documented in _Package-Insights.md
  - type: skill_update
    target: testing-swiftlang
    description: Add [SWIFT-TEST-014] ~Copyable values in #expect
  - type: skill_update
    target: memory-safety
    description: Add [MEM-OWN-013] consuming does not suppress deinit
---

# IO API Remediation — Sync Submission and the Async Overload Ambiguity

## What Happened

Executed a 3-phase handoff document: Phase 1 (quick wins: visibility, placeholder, try! fixes), Phase 2 (sync submission + Handle — the main event, 9 implementation steps across two packages), Phase 3 (depublish IO.Blocking.Lane via @_exported removal). The compiler experiment confirmed `consuming func value() async throws(...)` compiles on `~Copyable` structs. The `Kernel.Continuation.Context` callback refactoring was a clean cross-package change. All factory implementations wired `_enqueue`. 361 tests pass, zero failures.

Key decisions made during implementation:
- **Handle stores `Atomic<Bool> _taken` flag** instead of relying on consuming semantics alone. A consuming func's deinit still runs on both success and error paths — the flag prevents double-free of the boxed result on the success path.
- **`Enqueue` type made `public`** (not `package`) because the `@Witness` macro generates a public `Result` enum with a `case enqueue(...)` that references it. The macro doesn't support visibility parameters.
- **`Async` dependency added to `IO Blocking`** module. Necessary for `Async.Promise` in the Handle. Semantically correct — the Handle bridges sync→async.
- **Abandoning.Job refactored to callback-based dispatch**, matching the Kernel.Continuation.Context pattern. `setContinuation` wraps in callback; new `setCallback` used by sync path.
- **W-5 (observation type visibility) resolved by I-9**: removing `@_exported` on `IO_Blocking` means the parent struct isn't re-exported, so its nested observation types are effectively hidden — no macro change needed.

## What Worked and What Didn't

**Worked well**: The handoff document was exceptionally well-structured. Each step had file paths, line numbers, and implementation sketches. The "Corrections to the Comparative Analysis" section prevented wasted work on W-6 and I-4. The compiler experiment was decisive — took 2 minutes, saved hours of design oscillation.

**Worked well**: The callback refactoring pattern (store `@Sendable callback` instead of `CheckedContinuation`) proved composable — applied identically to both `Kernel.Continuation.Context` and `IO.Blocking.Lane.Abandoning.Job`.

**Didn't work**: The sync `IO.run` overload is ambiguous with the async overload in async contexts. The async overload has `deadline: IO.Deadline? = nil` default parameter, so both match the call signature `IO.run(on: lane) { 42 }`. Swift prefers the async overload. Tests had to use `lane._backing.run { }` (the `Property<Run, Lane>` level) where sync/async are distinguished by presence/absence of the `deadline:` parameter.

**Didn't work**: `#expect(handle.isFulfilled)` fails because Swift Testing's `#expect` macro tries to copy the ~Copyable handle. Had to extract the Bool first: `let f = handle.isFulfilled; #expect(f)`.

**Didn't work**: `Array<IO.Blocking.Lane.Handle<Int>>` — arrays require Copyable elements. ~Copyable Handles can't be bulk-collected.

## Patterns and Root Causes

**The async overload ambiguity is a known tension in Swift's sync/async overload design.** When a sync function and an async function have overlapping signatures (differing only by a defaulted parameter), async contexts always prefer the async overload. The `deadline: ... = nil` default on the async `IO.run` creates this overlap. The lower-level `Property<Run, Lane>` API doesn't have this problem because the sync overload has *no* deadline parameter (it's structurally different). The fix at the `IO.run` level would be to either: (a) remove the default from `deadline` on the async overload (breaking change), or (b) add a differently-named static method (e.g., `IO.enqueue`). This is a design decision that should be resolved before 1.0.

**~Copyable types interact poorly with Swift Testing and collections.** The `#expect` macro, `Array`, and other generic infrastructure assume `Copyable`. This is not a bug — it's the current state of generics adoption. The workaround pattern (extract Copyable projections before passing to generic code) is mechanical but noisy. As stdlib and swift-testing adopt `~Copyable` generics, this friction will decrease.

**Consuming + deinit is not "consume prevents deinit."** The mental model "consuming func takes ownership, so deinit doesn't run" is wrong. In Swift, a consuming func that doesn't `discard self` still runs the deinit for any remaining fields. The `_taken` atomic flag is the correct pattern for "deinit should skip cleanup if value was already extracted." This is analogous to the `moved` flag pattern in Rust's pre-drop-flag-removal era.

## Action Items

- [ ] **[package]** swift-io: Resolve `IO.run` sync/async overload ambiguity — consider removing `deadline` default from async overload, or introducing `IO.enqueue` as the sync entry point
- [ ] **[skill]** testing: Add guidance for ~Copyable types — extract Copyable projections before `#expect`, avoid storing in Array [TEST-NONCOPYABLE]
- [ ] **[skill]** memory-safety: Document the consuming+deinit interaction — `_taken` flag pattern for "skip cleanup if already consumed" [MEM-CONSUME-DEINIT]
