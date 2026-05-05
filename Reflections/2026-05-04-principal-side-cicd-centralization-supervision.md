---
date: 2026-05-04
session_objective: Channel the user as principal directing a separate subordinate session through the L1 swift-primitives CI/CD centralization rollout — multi-phase, multi-day, ~700+ commits — with per-action authorization discipline
packages:
  - swift-institute
  - swift-primitives
status: pending
---

# Principal-Side Supervisory Reflection — L1 CI/CD Centralization Rollout

## What Happened

This session served the principal-relay role for the multi-phase L1 swift-primitives CI/CD centralization rollout. The user channeled me-as-principal directing a separate subordinate session through Phases A → B2/B3.5/B4 → B6.5 R-chain → C → D → B8 → F-now (~700+ commits across 132 swift-primitives packages + swift-institute/.github + swift-primitives/.github + swift-institute/Skills). Subordinate-side reflections at `2026-05-04-per-repo-workflow-drift-rollout-c-d-b8-fnow.md` + `2026-05-04-primitives-ci-cd-straggler-cleanup-and-private-repo-creation.md` capture the executor perspective; this entry captures the distinct principal/supervisory perspective.

Key supervisory decisions that the subordinate executed:
- B5 deferral when subordinate halted on the sibling-org callers discovery (155 callers in foundations + standards still reference the standalone reusables; deletion would break their CI).
- B6.5b R-chain authorization after `UseShorthandTypeNames` rewrote `Array<X>` → `[X]` ecosystem-wide and broke 6 packages (compiler hardcodes `[X]` to `Swift.Array<X>` regardless of module shadowing — verified at `swiftlang/swift @ 6f265bdcad8` `KnownStdlibTypes.def` + `TypeCheckType.cpp:5599`).
- B7 halt + Required Workflows pivot consideration when subordinate caught my secrets-inheritance mental-model error.
- Phase F-now/F-deferred split when audit findings made it clear that codifying skill rules speculatively (before B7 lands) would produce wrong-shaped rules.

Active principal-side errors caught by subordinate:
- **B7 secrets framing wrong-shaped.** I instructed mass-removal of per-repo `secrets:` blocks based on a wrong mental model: "org-level secrets eliminate the need to pass anything." Subordinate empirically verified that GitHub Actions reusables don't auto-inherit caller secrets across the `workflow_call` boundary; minimum functional shape is `secrets: inherit`. Cost: ~2 correction turns + a near-miss 132-repo broken-CI fan-out.
- **Required Workflows initial dismissal.** First audit pass dismissed RW based on (correctly identified) trigger limitations. User pushed back; on reconsideration, RW dissolves the secrets-inheritance problem entirely (one central workflow vs 132 callers each with `secrets: inherit`). Reversed recommendation.
- **B5 implicit-scope authorization.** Authorized B5 framed as "verify zero remaining callers via grep across all 132 consumer ci.yml files" — implicit assumption swift-primitives org was the only org with callers. False; sibling orgs had 155 additional callers. Subordinate caught and halted before deletion.

State at session end: B7 + F-deferred + G remain outstanding. Required Workflows audit dispatched to subordinate, pending findings. User has set org-level `PRIVATE_REPO_TOKEN` (free-plan public-only, which architecturally aligns with visibility gate). HANDOFF-eliminate-per-repo-workflow-drift.md updated with current state; not deleted (outstanding work remains).

Handoff scan: 10 `HANDOFF*.md` files at `/Users/coen/Developer/`. Triage outcome:
- `HANDOFF-eliminate-per-repo-workflow-drift.md` — actively this rollout's tracking artifact; outstanding B7 + F-deferred + G; **annotated, left in place** (subordinate already updated per `[HANDOFF-009]`).
- All 9 others — **out of cleanup authority** per `[REFL-009]` bounded-cleanup rule (this session neither wrote them nor encountered their completion signals); left untouched.

## What Worked and What Didn't

What worked:
- **Per-action authorization discipline held cleanly across 700+ commits.** Each shared-infra push was a per-action gate; mass-fan-outs were authorized as bounded chains with explicit stop conditions. No unauthorized scope escalations. The `[CI-050]` discipline pattern that landed in the prior session continued holding through scale.
- **Subordinate halt-and-surface pattern caught three near-misses.** B5 (sibling-org callers), B7 (secrets-inheritance correction), B6.5b (UseShorthandTypeNames bug) all surfaced as halts before catastrophic fan-out. The "investigate before commit" framing produced compounding value.
- **Empirical canary verification (carrier-primitives) at every phase boundary** caught issues before they propagated. Particularly in B2-B4 where the duplicate-run window was confidence-validated empirically rather than reasoned-about-only.
- **Progressive HANDOFF.md capture across the multi-session arc.** `[HANDOFF-009]` discipline kept the cross-session bridge accurate; the new agent at session N+1 would start from a precise current-state snapshot, not from inference.
- **Decisive scope discipline on out-of-scope items.** Repeatedly surfaced + parked: graph-primitives compiler SIGABRT, README-lint untracked workflows, sibling-org cleanup, standalone-Swift-Format silent no-op, swift-base62 false-positive Package.resolved. Each could have been pulled in mid-rollout; each stayed where it belonged.

What didn't work:
- **My initial B7 framing was wrong.** I didn't empirically verify the GitHub Actions secrets-passing semantics before encoding the recommendation. Should have done a 5-minute test on a canary repo before authorizing the 132-repo mass-edit. The cost of "trust the mental model" is high when the mental model is wrong about a platform API.
- **Required Workflows dismissed too quickly on first pass.** I weighted the trigger limitation correctly but didn't weight the secrets-inheritance dissolution benefit. The user's second push reframed the trade-off; should have surfaced both factors in the first pass.
- **Build-verify-before-push gap during mass format.** B6.5b's R-chain incident: format-in-place across 132 packages without per-package `swift build` between format and commit. The UseShorthandTypeNames bug propagated to 132 repos before recovery. A local build verification step would have caught it on the first package (array-primitives) before fan-out propagated. Now codified as `[CI-056]`, but at the cost of the actual fan-out incident.
- **Implicit-count scope expressions ("132 consumers") leaked into authorizations.** B5's framing implied swift-primitives was the only relevant org. The right framing is explicit-org-list ("swift-primitives only; sibling orgs out of scope") at every shared-infra mass operation.
- **Prior-art skim on Required Workflows was shallow.** I cited "PR-only triggers" from outdated mental model of the original feature; current ruleset model has evolved. Rather than stating capability surface from memory, should have asked subordinate to verify before recommending.

## Patterns and Root Causes

**Pattern 1 — Mental-model-vs-runtime gap on platform APIs.** Three instances this session: secrets-inheritance, UseShorthandTypeNames hardcoding, standalone-Swift-Format silent no-op. The common failure mode is trusting a documented or inferred behavior over empirical verification. The remediation pattern that worked: subordinate empirically traced execution (re-running commands, reading compiler source, testing alternatives) before recommending. The principal-side pattern that failed: encoding a recommendation from mental model directly into authorization without canary verification. Mitigation: when authorizing a fan-out that depends on a platform API behavior, require a single-canary empirical test BEFORE the fan-out fires. The cost of the canary (5 min) is dominated by the cost of recovery from a wrong fan-out (hours + ecosystem disruption).

**Pattern 2 — Implicit scope expressions in shared-infra authorizations.** "132 consumers" is implicit-org-scoped; "all 132 swift-primitives consumers" is explicit-org-scoped. The B5 incident shows the implicit form leaks the principal's mental scope into the executable plan, where it can mismatch reality (sibling orgs exist; weren't in the count; would have broken). Mitigation: when authorizing operations on shared infrastructure, name the orgs/repos explicitly that ARE in scope, AND name the orgs/repos explicitly that are OUT of scope. The pre-Step-4 audit subordinate did naturally produced this framing; principal-side authorization frequently didn't.

**Pattern 3 — The cleanup pass surfaces pre-existing conditions.** B6.5 was authorized as "format pass to clear baseline." It actually exposed (a) ecosystem-wide formatting drift, (b) standalone Swift Format silent no-op since package creation, (c) UseShorthandTypeNames incompatibility, (d) 6 broken-on-remote packages requiring composite recovery. None of these were caused by the rollout; all were exposed by the new lint-strict enforcement contract. Generalizes: any "tighten the verification net" rollout should be planned with the expectation that the new net will catch pre-existing conditions, and the recovery work should be budgeted alongside the architectural cleanup.

**Pattern 4 — Principal-relay supervisory pattern works at scale, but principal-side cognitive load is the bottleneck.** Across this session the user channeled me directing a subordinate through ~700 commits. The pattern produced clean execution AND good defect-catching at the subordinate-halt boundaries. But the principal-side errors (B7, RW dismissal, B5 framing) all came from me carrying state across many turns of conversation. The principal-side equivalent of the subordinate's empirical-verification discipline would be: when about to authorize a fan-out, FRESHLY re-derive the architectural target from primary sources (skill rules, recent canary outcomes) rather than from accumulated conversation context. This is hard to do under conversation length pressure but is the right mitigation for the mental-model-drift class of error.

## Action Items

- [ ] **[skill]** ci-cd-workflows: Add a rule (or amend `[CI-050]`/`[CI-056]` cluster) requiring empirical canary verification of platform API runtime semantics (GitHub Actions secret-passing, `workflow_call` boundaries, `actions/checkout` interactions, etc.) BEFORE authorizing mass rollouts that depend on those semantics. The B7 secrets-inheritance episode shows how a wrong mental model on a platform API can author a 132-repo broken-CI fan-out if not caught. The verification should be a small single-canary empirical test, not docs-reading.
- [ ] **[research]** Standalone Swift Format silent no-op root-cause investigation. Pre-rollout standalone reusable was 0.235s no-op on at least property-primitives (CI step listed, status SUCCESS, files unmodified). Needs minimal-reproducer + diagnosis BEFORE the deferred B5 deletes the broken pattern (so we understand what we're deleting + whether the same defect class affects other reusables we keep). Likely suspects: `actions/checkout@v6 ref: main` interaction, container path mapping, working-directory mismatch.
- [ ] **[skill]** supervise (or handoff): Add a rule on explicit-scope expression in shared-infra authorizations. When authorizing a mass operation on shared infrastructure, name the orgs/repos explicitly that ARE in scope, and (when the operation could plausibly extend to sibling orgs) name the orgs/repos explicitly that are OUT of scope. Implicit-count phrasing ("all 132 consumers") leaks mental scope into the executable plan and risks sibling-scope mismatches like the B5 sibling-org callers incident.
