---
date: 2026-03-31
session_objective: Investigate CopyPropagation crash on ~Copyable enum consume, create minimal reproducer, file upstream issue
packages:
  - swift-async-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: issue-investigation
    description: Added -sil-verify-all pipeline-stage disambiguator guidance to [ISSUE-005]
  - type: skill_update
    target: issue-investigation
    description: Added "blocked ≠ distinct" note to [ISSUE-001]
  - type: package_insight
    target: swift-async-primitives
    description: "@_optimize(none) workarounds for #85743 — remove when Xcode ships 6.4+ (merged with Entry 6)"
---

# CopyPropagation ~Copyable Enum Crash — Already Fixed Upstream, Prior Misattribution Corrected

## What Happened

Set out to create a standalone reproducer for a CopyPropagation crash affecting
`switch consume` on ~Copyable enums in release mode, then file it upstream.
The crash affects 8 functions across Bounded and Unbounded channels in
swift-async-primitives, currently worked around with `@_optimize(none)`.

The investigation followed [ISSUE-001] through [ISSUE-007]:

1. Created progressively more specific reproducers — simple ~Copyable enum,
   generic enum, Mutex+closure pattern, exact `Receive.Action` field layout.
2. None crashed at `-O` in a single file. Added `-Xfrontend -sil-verify-all`
   to force SIL ownership verification at every pipeline stage.
3. Xcode 6.3 with `-sil-verify-all`: **crashed** — `load [take] $*Optional<Cont>`
   on a trivial type. Exact match for swiftlang/swift#85743.
4. Swift 6.4-dev with `-sil-verify-all`: **passed clean** (exit 0).
5. Searched GitHub — #85743 already filed, fixed by PR #85745 (merged 2025-12-04),
   commit `e93ea1db266`.
6. The prior audit note (same day, earlier session) stated this was "distinct from
   #85743." Corrected: that claim was based on inability to test on 6.4-dev
   (DeinitDevirtualizer blocked the superrepo build), not positive evidence.
   The standalone reproducer bypassing that blocker proves the fix resolves it.

Updated `HANDOFF-copypropagation-noncopyable-enum.md` with full findings and
`swift-async-primitives/Research/audit.md` with corrected attribution and
follow-up actions.

## What Worked and What Didn't

**Worked well**:
- [ISSUE-001] dev toolchain check was the right first move — immediately
  established the fix exists.
- `-sil-verify-all` as a verification tool. Without it, the bad SIL never
  manifests in single-file compilation because CopyPropagation's internal
  checks only catch it in complex cross-module patterns. With it, the SIL
  verifier catches the violation before any pass runs — conclusive evidence
  in seconds.
- GitHub issue search via `gh api` and `gh issue view` — found #85743 and
  confirmed it matched the exact SIL pattern.

**Didn't work**:
- Four rounds of reproducer escalation (simple → generic → Mutex → cross-module)
  all failed to trigger CopyPropagation's internal crash at `-O` without
  `-sil-verify-all`. The CopyPropagation manifestation requires code patterns
  that prevent the optimizer from simplifying away the bad ownership before
  CopyPropagation encounters it — likely the closure boundary from
  `Mutex.withLock` combined with cross-module inlining.
- Should have reached for `-sil-verify-all` sooner. The handoff's crash
  description ("CopyPropagation") and the actual root cause (SILGen) are at
  different pipeline stages — the verifier bridges that gap directly.

## Patterns and Root Causes

**Assertion vs non-assertion builds create different crash signatures for the same
bug.** SILGen generates `load [take]` on trivial fields (incorrect). In assertion
builds, `ManagedValue.h:210` catches it immediately. In Xcode's non-assertion
build, the bad SIL propagates until CopyPropagation's canonicalization detects
the ownership violation. The crash message says "CopyPropagation" but the root
cause is SILGen. This mismatch led the prior session to conclude it was a
"distinct CopyPropagation issue."

**"Cannot confirm on dev" is not evidence of distinctness.** The earlier audit note
based its "distinct" claim on a negative: the DeinitDevirtualizer crash blocked
6.4-dev testing, so the fix couldn't be verified. A standalone reproducer
bypassing the blocker immediately resolved the question. When a blocker prevents
end-to-end verification, targeted reproduction with the specific trigger pattern
is the correct technique — not concluding distinctness from absence.

**`-sil-verify-all` is the definitive ownership verification tool.** For any
crash attributed to an optimization pass, `-sil-verify-all` shows whether
the bad SIL is present before that pass runs. If it is, the root cause is
earlier in the pipeline (SILGen or a mandatory pass), and the optimization
pass is just the messenger.

## Action Items

- [ ] **[skill]** issue-investigation: Add guidance for `-sil-verify-all` as first diagnostic when the crash pass differs from the suspected root cause stage. The current [ISSUE-005] lists it but doesn't emphasize it as a pipeline-stage disambiguator.
- [ ] **[skill]** issue-investigation: Add note under [ISSUE-001] that "blocked by unrelated crash" is not evidence of distinctness — use targeted standalone reproduction to bypass blockers.
- [ ] **[package]** swift-async-primitives: When Xcode ships Swift 6.4+, remove 7 `@_optimize(none)` workarounds (tracked in audit follow-up actions).
