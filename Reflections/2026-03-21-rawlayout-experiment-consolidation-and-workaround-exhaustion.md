---
date: 2026-03-21
session_objective: Consolidate ~14 scattered @_rawLayout experiments into coherent corpus, then investigate paths to eliminate .unsafeFlags from Package.swift for SPM compatibility
packages:
  - swift-buffer-primitives
  - swift-storage-primitives
status: pending
---

# @_rawLayout Experiment Consolidation and Workaround Exhaustion

> **UPDATE (2026-03-22)**: Bug 2's root cause was identified: `~Escapable` + `@_lifetime(borrow)` on Property.View generates `mark_dependence` classified as `PointerEscape` by CopyPropagation. Fixed by removing `~Escapable` from Property.View. The "workaround exhaustion" finding below was correct — all code-level workarounds *for the `@_optimize(none)` approach* were exhausted. The actual fix was eliminating the root cause at the type level. See [2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md](2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md).

## What Happened

The session had two phases.

**Phase 1: Experiment consolidation.** 14 experiments across swift-buffer-primitives (6) and swift-storage-primitives (8) were consolidated into 3 experiments plus a standalone reproducer:
- `rawlayout-llvm-verifier-crash/` — 8 variants covering Bug 1 (LLVM verifier crash)
- `rawlayout-sil-ownership-crash/` — 3 variants covering Bug 2 (SIL ownership) + enum _modify limitation
- `rawlayout-deinit-alternatives/` — 4 variants covering workaround approaches
- `rawlayout-minimal-reproducer/` — standalone Bug 1 reproducer (Bug 2 does not reproduce)

Originals archived with SUPERSEDED.md notes (not deleted). Cross-references updated in 6 research documents and both _index.md files. Comment posted to swiftlang/swift#86652 with verified reproducer showing consumer-module 2-field trigger path.

**Phase 2: Workaround investigation.** Explored every path from `release-build-resolution-handoff-v2.md`:
- Validated experiment variants (11 of 16 match, 4 have minor packaging defects)
- Investigated Bug 2 triggers: hits Ring Primitives, Ring Inline Primitives, Slab Inline Primitives
- Tested removing `@inlinable` (WMO still optimizes → doesn't help)
- Tested `@_transparent` (functions too complex → not applicable)
- Built minimal reproducer: Bug 1 reproduces (3-module chain, 11 lines), Bug 2 does not
- **Tested AnyObject? workaround empirically**: fixes the minimal reproducer but NOT the production crash

The session ended with all known code-level workarounds exhausted. A fresh-eyes handoff was written for a new agent to approach laterally.

## What Worked and What Didn't

**Worked well:**
- Parallel agent dispatch for experiment writing (3 experiments created simultaneously) — significant time saving
- The minimal reproducer discovery: cross-module threshold is 2 fields, crash is in consumer module. This was a genuinely new finding not in any prior investigation.
- Empirically testing AnyObject? in the real codebase rather than theorizing. The test took 5 minutes and conclusively invalidated an option that looked promising on paper.
- Posting the verified reproducer to #86652 immediately after validation.

**Didn't work well:**
- The first SIL investigation agent incorrectly attributed Bug 2 to Property.View + @_lifetime coroutines. A second agent reading the actual source code contradicted this. The error was: the first agent examined SIL output from a build with flags enabled (successful build) and found correlated patterns, not causal ones. Lesson: SIL from a PASSING build shows what the optimizer does, not what causes the crash.
- The AnyObject? workaround seemed promising because it's proven for the simpler trigger path (#86652's own workaround). But the production code uses a completely different trigger path (extension-defined types under WMO) that AnyObject? doesn't fix. The mental model of "one bug, one workaround" was wrong — same root cause, multiple trigger paths, workaround only covers one.

## Patterns and Root Causes

**Multiple trigger paths for one root cause.** The @_rawLayout triviality misclassification manifests through at least 3 distinct LLVM IR lowering paths:
1. Consumer-module with 2+ fields of the type (minimal reproducer — AnyObject? fixes)
2. Extension-defined types in same module under WMO (production — AnyObject? doesn't fix)
3. Downstream SIL ownership in CopyPropagation (Bug 2 — nothing fixes, can't even reproduce standalone)

This is a recurring pattern with compiler bugs: the root cause is singular (triviality misclassification) but the symptoms are plural and independently triggered. Fixing one symptom (path 1 via AnyObject?) doesn't address the others.

**Agent SIL analysis is unreliable for crash diagnosis.** When an agent examines SIL from a successful build, it finds what the optimizer DID, not what CAUSED a crash. The CopyPropagation patterns the agent identified (Property.View + @_lifetime) were real SIL patterns but were not the crash trigger. Production code review by a second agent showed the attributed functions didn't even use Property.View in the way described. For compiler crash diagnosis, agents should examine the CRASHING build's output, not infer from successful builds.

**Experiment consolidation reveals the investigation's actual structure.** The 14 scattered experiments made it hard to see that the investigation had three clear threads (Bug 1, Bug 2, workarounds). Consolidation into 3 experiments + a reproducer made the evidence structure visible. This should be done earlier in future investigations — consolidate first, then investigate.

## Action Items

- [ ] **[skill]** experiment-process: Add guidance for consolidation of related experiments — when to consolidate (>5 experiments on same bug family), the SUPERSEDED.md pattern, and the distinction between standalone-reproducible and context-sensitive experiments per [EXP-004a]
- [ ] **[package]** swift-buffer-primitives: Fix 4 consolidation packaging defects in experiment variants (V04 missing public init, V08 Sendable, V01 visibility, V03 attribute)
- [ ] **[research]** Investigate whether SwiftPM build plugins can inject `-Xfrontend` flags without `.unsafeFlags` — this is the most promising lateral path for SPM compatibility that wasn't explored in this session
