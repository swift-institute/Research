---
date: 2026-05-12
session_objective: Orchestrate the pointer-arithmetic miscompile investigation + Issues per-issue precedent setting + extension dispatch from the orchestrator role (subordinate executes; user authorizes per-action gates).
packages:
  - swift-affine-primitives
  - swift-institute/.github
  - swift-institute/Issues
  - swift-institute/Experiments
  - swift-institute/Research
status: pending
---

# Orchestrator meta-process: independent audits catch review blind spots; per-action YES gating needs cross-session codification

## What Happened

Multi-dispatch arc spanning ~36 hours from the orchestrator role:

1. **Affine publication** of `swift-affine-primitives` (canonical institute/stdlib conformance layout matching pair/either; Atomic conformance) surfaced a Linux test failure (`unsafeMutablePointerMinusTypedOffset()`) that gated CI's `ci-ok` aggregator. Sibling `+` operator passed; only `-` failed.

2. **Three-round investigation** with two false trails before convergence:
   - Round 1: hypothesized Linux + `unsafe` keyword + custom prefix `-` for Carrier<Vector> + operator resolution → instrumentation masked the bug (Heisenbug) → first inversion
   - Round 2: pivoted to `unsafe` keyword + SwiftPM-test-runner build flags → instrumentation still masked → second inversion
   - Round 3: `/collaborative-discussion` (independent Claude+ChatGPT) converged on toolchain DSE bug + identified existing `swiftlang/swift#77558` that the in-session `[ISSUE-001]` upstream-search had missed across 8 keyword combinations

3. **Comment authoring**: drafted upstream comment per the converged template. Orchestrator review approved. Two independent fresh-chat pre-publication audits ran before posting and caught two HIGH-severity defects the orchestrator review missed: (a) wrong Docker tag (`swiftlang/swift:6.3.1-RELEASE` doesn't exist; correct is `swift:6.3-jammy`), (b) synthetic SIL excerpt (verbatim value numbers `%18`, `%19`, … presented as factual evidence; actually illustrative). Both would have embarrassed on posting. Body-only file extracted; comment posted under `coenttb` at `#issuecomment-4425028051`.

4. **Per-issue restructure precedent** established at `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/`: 1 testTarget (`withKnownIssue` flip-on-upstream-fix) + 1 executableTarget (local probe) + `evidence/` (retired bisection scaffolding) + dynamic-matrix CI calling shared reusable via new `test-filter` input on `swift-institute/.github`'s universal `swift-ci.yml`. Shared infra change is backwards-compatible (empty default preserves all consumers); `fail-fast: false` is load-bearing.

5. **Extension dispatch** applied the precedent to 3 sibling triage dirs + Experiments. Per-dir Phase 1 triage surfaced four no-fit outcomes (each blocked by a different precedent assumption); all four routed to defer-with-note. Subordinate's reflection `2026-05-12-per-issue-precedent-extension-deferred.md` captures that arc.

6. **Forward-looking constraint codified mid-arc**: prior dispatch's SGR #6 ("ISSUE-77558-COMMENT.md posting is a SEPARATE authorization") was generalized to "ALL `swiftlang/*` upstream interactions require fresh per-action YES — applies to this session AND beyond." The rule only lived in dispatch text; both dispatch handoffs are now deleted. No durable codification exists.

## What Worked and What Didn't

**Worked**:

- **Independent verification at multiple ranks closed real defects**: `/collaborative-discussion` confirmed novelty and identified the existing #77558 the upstream-search missed; two fresh-chat audits caught the wrong-Docker-tag + synthetic-SIL defects in my approved comment. Each rank had a different blind spot; running them in series produced a stronger artifact than any single review.
- **Per-action YES gating discipline held**: ~10 distinct push / `gh issue comment` / cross-link authorizations, each surfaced as a separate gate, no bundling. The subordinate's [REFL-009a] in-flight conservativism prevented annotating files in flight. [GIT-012] dirty-worktree discipline preserved `Experiments/.github/metadata.yaml` prior-session WIP cleanly.
- **`/handoff` skill produced durable dispatch artifacts**: each dispatch's HANDOFF.md carried Goal + Current State + SGR + Next Steps; verification stamps closed each dispatch's termination per [SUPER-011]. No orphan handoffs accumulated — both dispatch handoffs deleted at end-of-cycle per Q1=yes via stamp + [REFL-009].
- **Heisenbug recovery via inversion**: when instrumentation masked the bug twice (37fac39, b1206cb), the subordinate correctly inverted the diagnosis rather than persisting on the prior hypothesis — first to "call-site init resolution," then to "release-mode optimizer," finally to the converged "DSE of live element stores." The discipline to surface "my prior hypothesis was wrong" before iterating prevented compounding the original mis-diagnosis.

**Didn't**:

- **`[ISSUE-001]` upstream-search keyword set was too narrow**: 8 keyword combinations did not surface `swiftlang/swift#77558` despite it being a 2024-11 issue with the same root cause. Required keyword variants that surfaced post-convergence: "miscompile array literal", "dead store elimination + Swift", "release mode pointer wrong value", "advanced(by:) miscompile". The pre-existing `[ISSUE-001]` rule's keyword guidance is generic; this session's empirical evidence justifies broadening.
- **Orchestrator review missed two HIGH-severity defects** in the upstream comment body (wrong Docker tag + synthetic SIL excerpt). Both were verifiable mechanically (`docker pull` on the cited tag would 404; `swiftc -emit-sil` on the repro produces different value numbers). The orchestrator role had loaded the comment body context from drafting earlier; the fresh-chat audits had no such context and re-read with fresh eyes. The asymmetry is decisive: review-by-author-of-adjacent-content carries blind spots that fresh-chat-audit-with-no-context catches cheaply.
- **The session-spanning rule ("all `swiftlang/*` upstream interactions require fresh per-action YES") has no durable home**. Currently it lives only in dispatch handoff text (now deleted). Next session won't see it unless promoted to a skill rule (`handoff` or `git-operations`) or a memory entry. Without codification, the rule decays.

## Patterns and Root Causes

**Pattern: independent verification at staggered ranks catches different defect classes.** Orchestrator-review has loaded context from drafting → cognitive lock-in on the content's intended meaning. Fresh-chat audit reads cold → catches surface defects (wrong tag, synthetic excerpt) the author's mind glosses over. `/collaborative-discussion` adds an independent reasoning chain → catches novelty defects (missed existing upstream). Three staggered ranks; three different defect classes caught. This is the same shape as `[HANDOFF-013a]` writer-side prior-research grep / `[REFL-011]` primary-source re-derivation — shift verification to the rank that hasn't loaded the artifact's interpretive context yet.

**Pattern: session-spanning rules need pre-emptive skill codification, not post-hoc memory recovery.** The per-action YES gating rule was load-bearing for the dispatch arc (10+ authorizations, no bundling). It survived the session because the dispatch handoff carried it as SGR. But the handoff was deleted at end-of-cycle; the rule is now unanchored. The pattern: any rule that's binding *beyond the originating session* must land in a skill before the dispatch artifact is retired. The dispatch artifact is ephemeral by design ([REFL-009] MUST-delete on completion); rules that needed the dispatch artifact's protection are now homeless.

**Pattern: Heisenbug inversion requires explicit hypothesis-disposal turns.** When instrumentation masks the bug, the temptation is to refine the instrumentation. The discipline that worked here: when the empirical signal contradicts the prior hypothesis, *retire the hypothesis entirely* and treat the new evidence as defining a new investigation rather than refining the old. The subordinate did this twice (call-site init → release-mode optimizer → DSE of live element stores), each time naming the prior hypothesis as superseded rather than carrying forward partial belief. This kept the investigation honest at the cost of three full rounds.

The connecting thread across these patterns: **verification cost is asymmetric, and the cheapest verification rank is the one with the least interpretive context loaded**. Author-review > orchestrator-review > fresh-chat-audit > /collaborative-discussion in terms of context-loading; the reverse order is the cheapness ranking for catching new defects. The discipline is to route verification to the cheapest rank that still has sufficient domain knowledge — not the rank that's most loaded.

## Action Items

- [ ] **[skill]** `handoff`: codify the session-spanning rule "ALL `swiftlang/*` upstream interactions (issue creation, comments, PRs, swift-evolution pitches, swift-testing issues, swift-package-manager issues, etc.) require fresh per-action YES" as a new `[HANDOFF-NN]` rule cross-referencing `[GIT-001]` and `[SUPER-002]`. Currently the rule only lived in the deleted dispatch text; without skill codification the rule decays at the next session boundary. Worked example: this session's #77558 comment posting required a separate explicit YES after the comment-revision push, despite the prior pushes having been authorized.

- [ ] **[skill]** `issue-investigation`: broaden `[ISSUE-001]` upstream-search keyword guidance with empirical additions from this session — for compiler-codegen-bug searches, include variant keywords: "miscompile array literal" / "dead store elimination + Swift" / "release mode pointer wrong value" / `<op-name>` miscompile (e.g., `advanced(by:) miscompile`) / SIL pass name + miscompile / `<SIL-pass>: support the new array literal initialization pattern`. The current `[ISSUE-001]` rule states "use ≥3 distinct keywords" without examples; this session's 8-combination miss against `#77558` justifies adding a worked-example keyword-broadening table.

- [ ] **[skill]** `release-readiness` (or `supervise`): codify "pre-publication independent fresh-chat audit pass" as a discipline for any artifact that posts to a public external surface (upstream issue tracker, swift-evolution, public blog, etc.). This session's two pre-publication audits caught two HIGH-severity defects in an orchestrator-approved comment body (wrong Docker tag + synthetic SIL excerpt). The discipline is cheap (one /collaborative-discussion or sibling agent prompt with the artifact body, no other context) and the cost-asymmetry is decisive — orchestrator review carries context-loading blind spots that fresh-chat audit catches in minutes.
