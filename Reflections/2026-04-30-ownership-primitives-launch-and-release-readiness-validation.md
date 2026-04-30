---
date: 2026-04-30
session_objective: Apply the release-readiness skill to swift-ownership-primitives 0.1.0 as the first non-pilot validation case (carrier was the pilot, shipped 2026-04-29). Capture skill-validation lessons for the remaining cohort packages (tagged + property).
packages:
  - swift-ownership-primitives
  - swift-institute (Research/carrier-launch-skill-incorporation-backlog.md as backlog reference; Skills/release-readiness as canonical workflow)
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: release-readiness
    description: "[RELEASE-002] Phase 6 amended — backlog row status verification MUST re-derive each row's claim from current source, not just read row text. Cross-references [HANDOFF-021] + [AUDIT-029]."
  - type: skill_update
    target: swift-forums-review
    description: "[FREVIEW-020] Delta Re-Simulation Mode for Low-Change Windows — ~10% cost of full [FREVIEW-019] when (a) prior sim exists, (b) <10 commits, (c) <10% LOC delta."
  - type: package_action
    target: swift-ownership-primitives
    description: "AI 3 — file upstream swiftlang/swift issue for @inlinable + withUnsafePointer + ~Copyable Value release-mode miscompile. Captured here as triage outcome; actual filing is package-owner action, not /reflections-processing scope."
---

# Ownership-Primitives Launch and Release-Readiness Skill Validation

## What Happened

Single dispatch executing the seven-phase final pre-release scan ([RELEASE-002]) of the **release-readiness** skill against `swift-ownership-primitives` 0.1.0. The skill itself was created from the carrier-launch arc (committed at `swift-institute/Skills@35dce3e` and amended at `ffc1b92`). Ownership is the second package in the swift-primitives 0.1.0 release cohort; this scan is the skill's first non-pilot validation.

**Inputs**:
- The pre-existing `swift-ownership-primitives/AUDIT-0.1.0-release-readiness.md` (authored 2026-04-24, **before the skill existed**).
- The pre-existing `Audits/audit.md` (32909 bytes; 9 memory-safety findings + 36-item Design Review across clusters A–G; 2026-04-23 / 2026-04-24).
- The carrier reference templates at `swift-carrier-primitives/AUDIT-0.1.0-{release-readiness,final-pre-release-scan}.md`.
- The carrier-launch skill-incorporation backlog (Tier 1 11/12 LANDED at `Skills@ffc1b92`; #1.8 OPEN per the row but stale per state).

**Phase-by-phase work**:

- **Phase 0 (Baseline)**: working tree clean, on `main`, up-to-date with `origin/main` (handoff's stale "ahead of origin" claim disproved). `swift build` and `swift test` clean modulo 2 [MEM-SAFE-002] warnings on `Ownership.Borrow.swift` lines 125 and 205. 113/47 tests pass in both debug and release; release-mode test pass confirms the `@inlinable`-removal workaround (`ece5d7e`) holds. Repo visibility PRIVATE; CI workflows still `state: disabled_manually` since 2026-03-04.

- **Phase 1 (Re-audit prior findings)**: each of the 9 memory-safety findings + 36 design-review items re-verified against current source. 7 RE-VERIFIED (Memory Safety), 8 RE-VERIFIED RESOLVED (Design Review clusters A1–A5/B1–B2/D7/F1), 7 still DEFERRED (unchanged), 6 EXPLORATORY (unchanged). No regression on any prior remediation.

- **Phase 2 (Independent fresh-eyes sweep)**: 3 new MEDIUM findings + 1 LOW. The MEDIUMs all cluster on `Ownership.Borrow.swift` and trace to commits `a02e96c` (heap-owning class for Copyable Value path) + `ece5d7e` (@inlinable removal). NEW-1/NEW-2 are [MEM-SAFE-002] strict-memory-safety warnings (mechanical fixes); NEW-3 is [API-IMPL-005] one-type-per-file (the new internal class shares the file with `Ownership.Borrow`). NEW-4 LOW is README internal rule-ID citation consistency vs carrier's stripped-citation precedent.

- **Phase 3 (Recent-change regression check)**: 6 commits since 2026-04-24; all behavior-verified. The Borrow refactor (`a02e96c` + `ece5d7e`) solves a real release-mode miscompile but introduces the Phase 2 NEW-1/NEW-2/NEW-3 violations.

- **Phase 4 (Forums-review re-simulation)**: ran in delta-mode against the 2026-04-24 simulation rather than full re-sim. The 5 prior angle scores are unchanged in priority; angle #4 (ownership/memory safety) and angle #5 (performance) are AMPLIFIED by the Borrow refactor (the public Warning docstring on `Ownership.Borrow.swift:173–188` introduces a HIGH-severity day-one probe absent an upstream issue ID; the heap-owning class adds a performance probe).

- **Phase 5 (Tag-procedure prep)**: 9 release-readiness items refreshed; same posture as 2026-04-23 (CI gate is the only external blocker).

- **Phase 6 (Backlog status)**: Tier 1 11/12 LANDED at `Skills@ffc1b92`. Backlog row #1.8 (cross-package Test Support relocation) is **STALE** — claims ownership currently places Test Support under `Sources/...Test Support/`, but `Tests/Support/exports.swift` exists and `Package.swift:198` declares `path: "Tests/Support"` correctly. Property and tagged also have `Tests/Support/` (verified). The row is a snapshot from before the carrier audit's "2026-04-29 reversal" annotation; should be annotated `RESOLVED 2026-04-30` once principal authorizes the backlog amendment.

- **Phase 7 (Recommendation)**: **CONDITIONAL GO** subject to (a) accepting-as-known or resolving 3 MEDIUM Phase 2 findings, (b) Phase 4 N1 mitigation (upstream bug filing), (c) external CI/visibility/per-action gates.

The audit append landed in `Audits/audit.md` as `## 0.1.0 Final Pre-Release Scan — 2026-04-30`. `Audits/_index.json` updated with refreshed scope text and date. No source code, tests, README, Package.swift, .github/workflows, or .gitignore modified per the [RELEASE-002] "Do Not Touch" boundary.

## What Worked and What Didn't

**Worked**:

- **Skill structure was easy to follow**. The seven-phase scan template gave clear scaffolding for what to check at each step. The "Do Not Touch" boundary cleanly separated audit work from remediation work; never once was there ambiguity about whether a finding warranted an in-session edit vs an escalation.

- **Re-audit-against-current-source caught a violation that would otherwise drift**. NEW-3 [API-IMPL-005] (the `_Ownership_Borrow_OwnedBuffer` class sharing the file) was introduced post-prior-audit by `a02e96c`. The "reproduce conclusions, don't trust prior verdicts" framing of [RELEASE-002] Phase 1 is what surfaced it. A scan that just read `Audits/audit.md`'s "Verified clean" assertions would have missed this entirely.

- **PREMISE-STALE classification was already in [AUDIT-025] and worked exactly as designed**. The 2026-04-23 audit's `[MEM-SAFE-002]` "Verified clean" line is now PREMISE-STALE — correct at audit-write time, invalidated by subsequent commits. The classification let the new scan say "the prior audit was right; the world moved" without overclaiming on either FALSE_POSITIVE or RESOLVED.

- **Delta-mode forums-review re-simulation captured most of the value**. Full corpus-grounded re-sim requires the swift-forums-review skill's Python pipeline against the 900+-thread corpus. A delta against the 2026-04-24 artifacts re-validated angle scores and surfaced two new probes (N1: upstream-bug public surface; N2: heap-allocation framing) at maybe 10% of the cost.

**Didn't work / friction**:

- **Backlog row #1.8 was stale and would have wasted a Phase 1 cycle if I had trusted it**. The handoff itself echoed the stale claim ("Phase 1 of ownership's brief MUST address Test Support relocation"). State verification took 30 seconds (`ls Tests/Support/` + Package.swift inspection) and returned the row was already-resolved. If I had blindly followed the handoff and queued a relocation that wasn't needed, the next half-hour would have been wasted on a no-op git diff. The skill's [RELEASE-001] doesn't currently mandate state-verification at Phase 6 backlog inspection.

- **The handoff's quoted state ("local main ahead of origin; awaiting make-public + CI") was outdated**. `git status` showed up-to-date with origin. The handoff was correctly framed as "to investigate: read this file for full context, then verify state" — that framing saved me from acting on outdated assumptions, but only because I checked. A handoff that ASSUMES the quoted state is current would mislead.

- **The `@inlinable`-removal commit's docstring forbids `@inlinable` but doesn't cite an upstream issue ID**. This is a launch-blocker-class community-reception risk (Phase 4 N1) that wasn't visible at audit-time of the original 2026-04-23 brief because the commit hadn't landed yet. Catching it required reading the commit body and the Warning docstring side-by-side. A general "cite upstream issue when documenting a compiler bug" rule would have caught this earlier.

- **Forums-review delta-mode is undocumented in the skill**. I improvised the delta-validation framing because full re-sim would have been expensive and the corpus tooling wasn't loaded into context. The result was useful, but the skill currently treats [FREVIEW-019] as "MUST run a re-simulation"; there's no codified delta-mode that captures the pragmatic shortcut for low-change windows.

## Patterns and Root Causes

**Pattern 1 — Backlog rows decay faster than the underlying state**. The skill-incorporation backlog is a snapshot artifact. Carrier-launch authored it on 2026-04-29; by 2026-04-30 the swift-carrier-primitives Audits/audit.md Testing #6 row had been updated to reverse the original OPEN classification (per the backlog's own footnote "2026-04-29 reversal"). The backlog row text was never re-edited. This is a structural feature, not a defect — the backlog is supposed to be an enumerated rather than computed view — but it means downstream skills that consume the backlog cannot trust the row text alone. **The fix is structural**: at Phase 6 of the final pre-release scan, the audit MUST re-derive the row's claim from current source, not just read the row's status text. This is parallel to [HANDOFF-021] (don't trust the agent's recall; re-derive from source) and [AUDIT-029] (empirical census before options matrix). The same discipline applies here: empirical-census-before-trusting-row-status.

**Pattern 2 — "Verified clean" is a snapshot, not an invariant**. The 2026-04-23 memory-safety audit said `[MEM-SAFE-002]` was Verified clean. By 2026-04-30, two new [MEM-SAFE-002] warnings existed because a refactor landed that introduced them. The audit was correct at write-time; the world moved. This is the [AUDIT-025] PREMISE-STALE case, and it worked. The pattern observation is meta: the SKILL of writing audits and the SKILL of re-running them later compose well only if the re-run knows it cannot trust prior verdicts. The seven-phase scan structure ([RELEASE-002] Phase 1 = "every entry re-verified; do NOT trust prior verdicts") explicitly demands re-derivation. This is the right design — but it depends on the discipline being held during re-audit, which the skill must keep enforcing in the rule text.

**Pattern 3 — Substantial recent changes amplify forums-review angles even when scores don't move**. The 2026-04-24 forums-review simulation predicted angle #4 (ownership/memory safety) at score 52.81. The Borrow refactor that landed minutes after that simulation introduced a public Warning docstring documenting an upstream Swift miscompile. The angle's *score* didn't change because the LOC / public-decl-count / unsafe-mention metrics that feed `score = venue × era × package_weight` only shifted slightly. But the *probe surface* changed materially: reviewers now have a specific concrete artifact ("there's a Warning docstring forbidding @inlinable; show me the upstream issue") to drive their post into. The score-vs-substance distinction (per `reference_swift_forums_review_score_vs_substance.md`) is exactly this case — the score-layer is code-shape-only; substance shifts under it. Delta-mode re-simulation needs an "amplification" axis distinct from the "score" axis to capture this.

**Pattern 4 — Non-pilot launches benefit from the pilot's instrumentation overhead**. Carrier-the-pilot accumulated significant overhead: the four-phase brief + seven-phase final scan + skill-incorporation gate + 12-item Tier 1 backlog. Ownership-the-non-pilot inherits the gating discipline but skips Phase 4 of [RELEASE-001] (skill-incorporation gate is pilot-only per [RELEASE-003]). The "first-time validation" framing applied to me here (run the skill against the second package; see what breaks) is actually a meta-pilot — ownership is piloting the *skill*, not the *cohort*. This is a different kind of pilot than carrier was, and the lessons feed forward to tagged + property without needing to wear the same overhead each time.

## Action Items

- [ ] **[skill]** release-readiness: amend [RELEASE-002] Phase 6 to require the audit to re-derive each backlog row's claim from current source before recording status, not just read the row's text. Cite ownership-primitives backlog #1.8 as the worked example: row claimed Test Support relocation needed, current state showed `Tests/Support/exports.swift` already in place. Without the cross-check, an auditor following the row blindly would queue a no-op relocation. Cross-reference [HANDOFF-021] and [AUDIT-029] as parallel discipline rules.

- [ ] **[skill]** swift-forums-review: codify a "delta re-simulation" mode at [FREVIEW-019] for low-change windows. Mode: re-score the prior simulation's top angles against current state, then add new probes introduced by commits-since-prior-sim under an "amplification" axis distinct from "score." Mode applies when (a) prior simulation exists at `Audits/forums-review/`, (b) <10 commits since prior sim, (c) no LOC / public-decl-count change >10%. Output is a single delta-validation section in `Audits/audit.md` rather than new sim/objections/triage files. Captures most of the value at ~10% of the cost; keeps the full skill invocation available for substantial-change windows. Worked example: the ownership-primitives 2026-04-30 final scan Phase 4 ran this mode against the 2026-04-24 simulation.

- [ ] **[package]** swift-ownership-primitives: file upstream `swiftlang/swift` GitHub issue for the `@inlinable` + `withUnsafePointer(to: borrowing _)` + `~Copyable Value` release-mode miscompile (referenced from `Ownership.Borrow.swift:173–188` Warning block + `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`). Cite the issue ID in the Warning docstring. Pre-launch action — without the issue ID, the docstring is "we found a bug; trust us"; with it, "we found a bug; here's the upstream conversation." This is the Phase 4 N1 mitigation; converts the day-one HIGH-severity community-reception probe to a manageable answer-with-link.
