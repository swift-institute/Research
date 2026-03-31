---
date: 2026-03-31
session_objective: Cascade ~Copyable through IO Completions (Success/Outcome/Event), replace stdlib arrays with ecosystem Array, switch Bridge to individual delivery
packages:
  - swift-io
  - swift-async-primitives
  - swift-witnesses
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: experiment-process
    description: Added build verification guidance to [EXP-004] — verify rm -rf .build succeeded
  - type: no_action
    description: "Check 6.4-dev first" — already captured in [ISSUE-001]
  - type: no_action
    description: "@_optimize(none) removal — merged into Entry 4 copypropagation package insight"
---

# ~Copyable IO Completion Cascade and SILGen Bug Discovery

## What Happened

The session had two major arcs: implementing the ~Copyable cascade through IO Completions, and discovering a Swift compiler bug that blocked release-mode benchmarks.

**Arc 1 — IO Completions cascade (committed as `67a320d`).** Made Success/Outcome/Event ~Copyable. The accepted descriptor now lives in `Success.accepted(descriptor: Kernel.Descriptor)` — not a Storage side-channel. Bridge switched from batch `[Event]` to individual `Async.Bridge<Event>`. Poll buffer changed to ecosystem `Array_Primitives_Core.Array<Event>`. 16 files changed across the IO Completions module. Key patterns established: borrow outcome for error paths (Copyable associated values), consume for descriptor extraction; `storage.completion.take()` for ~Copyable extraction from class storage; module-qualified `Array_Primitives_Core.Array` to disambiguate from `Swift.Array`. The `@Witness` macro on Driver was preserved — the macro handles the ~Copyable closure types correctly.

**Arc 2 — CopyPropagation crash investigation.** Release-mode builds of swift-async-primitives crashed with "Found ownership error?!" in CopyPropagation. Initial hypothesis: context-sensitive bug like Bug 2 (#88022). Applied `@_optimize(none)` to 8 channel functions as workaround. Bisected to commit `6f04280` ("Restructure channel state machines for ~Copyable element flow"). Extensive experimentation failed to reproduce in isolation — tried 2-module, single-module, with/without async, with/without Mutex, generic/non-generic combinations. Breakthrough: SIL dump from production build showed `load [take]` on trivial `Optional<Int>` field within ~Copyable enum tuple payload. Eventually achieved standalone reproduction in 7 lines. Found it crashes in BOTH debug and release (earlier "debug OK" results were stale `.build` artifacts). Verified against Swift 6.4-dev: **passes** — bug already fixed. Traced to commit `e93ea1db266` by Benjamin Levine, fixing swiftlang/swift#85743.

## What Worked and What Didn't

**Worked well:**
- The IO Completions cascade was clean. The borrow/consume separation pattern (borrow outcome for scalar values, consume for owned descriptor) solved the exclusivity violation naturally.
- The bisect of swift-async-primitives was fast (5 iterations, ~2 min each) and precisely identified the introducing commit.
- Reading the SIL error output (`-sil-print-around=CopyPropagation`) gave the exact error signature that guided the investigation.
- Systematic reduction per [EXP-004] found the absolute minimum: generic ~Copyable enum + tuple payload with trivial field + consuming switch.

**What didn't work:**
- **Stale `.build` caches caused false positives.** Multiple "successful" reductions were actually running against cached builds from earlier variants. The `rm -rf .build` command sometimes failed silently (`Directory not empty`), leaving stale artifacts. This wasted significant time and produced misleading results (e.g., `print("hello")` appeared to crash). The lesson: ALWAYS verify `rm -rf .build` succeeded before trusting a build result.
- **Initial hypothesis was wrong.** The first SIL analysis concluded the bug was about mixed trivial/non-trivial fields, SILCloner forwarding ownership, or generic specialization. The actual root cause was simpler: SILGen's `emitDestructiveCaseBlocks()` used `B.createLoad(...Take)` unconditionally instead of `TypeLowering::emitLoad()`. The hypothesis was constructed to fit the evidence but overcomplicated the mechanism.
- **Experiment reproduction took many iterations.** 8+ variants tested before achieving standalone reproduction. The key insight that unlocked it was testing with `swiftc` directly (no SwiftPM) — this eliminated the caching variable entirely.

## Patterns and Root Causes

**Pattern: stale build caches as investigation hazard.** This is the second time stale `.build` artifacts produced misleading results (first was the earlier Bug 2 investigation). The `rm -rf .build` idiom is unreliable — Swift's `.build` directory can contain locked files or nested structures that prevent deletion. A reliable alternative: build in a fresh temporary directory, or verify the directory is actually gone after deletion.

**Pattern: hypothesis escalation before evidence.** The investigation jumped from "CopyPropagation bug" to "SILCloner forwarding ownership in generic specialization" to "multi-pass interaction" — each hypothesis more complex than needed. The actual fix was a 3-line change in SILGen. The SIL dump evidence was available early but was interpreted through the lens of the prior Bug 2 investigation (mark_dependence, PointerEscape, etc.). Fresh eyes would have seen "load [take] on trivial type" immediately.

**Pattern: checking 6.4-dev should be step 1, not step N.** The bug was already fixed. Verifying against the development branch would have immediately revealed this, saving the deep-dive into compiler source. For future compiler bugs: check the latest dev toolchain first.

## Action Items

- [ ] **[feedback]** memory: When investigating compiler crashes, check Swift 6.4-dev FIRST before deep-diving into compiler source. The bug may already be fixed on main.
- [ ] **[package]** swift-async-primitives: Remove the 8 `@_optimize(none)` workarounds once Xcode ships Swift 6.3.1+ or 6.4 with the fix (swiftlang/swift#85743, commit `e93ea1db266`). Track in audit.md.
- [ ] **[skill]** experiment-process: Add guidance that `rm -rf .build` must be VERIFIED (check exit code or confirm directory gone) before trusting build results. Stale caches have caused false positives in multiple investigations.
