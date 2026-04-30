---
date: 2026-04-23
session_objective: Continue Phase II.5 of Swift Institute ecosystem finalization — consolidate the heritage-transfer plan into a canonical Research doc, absorb user direction + supervisor review, execute the first wave of coenttb → swift-institute transfers.
packages:
  - swift-institute
  - coenttb
  - swift-foundations
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: research-process
    description: "[RES-024] Empirical-Reproduction Requirement for Git-Recipe Claims — research/handoffs prescribing git command sequences MUST empirically reproduce in scratch repo before publishing."
  - type: skill_update
    target: swift-package
    description: "[PKG-NAME-010] GitHub Release vs Git Tag — Different Questions. gh repo view latestRelease returns null when tag exists without Release; git describe --tags is the right API for tag-existence."
  - type: skill_update
    target: supervise
    description: "[SUPER-030] Bounded Final-Exchange for Supervisor Review Cycles — pre-frame final exchange with numbered questions + word cap + 'no further discussion' framing."
---

# Phase 1 Heritage Transfers and Multi-Round Plan Consolidation

## What Happened

Continuation session from the multi-week ecosystem-finalization arc. Started from HANDOFF.md's Phase II.5 position with the investigation doc `HANDOFF-heritage-transfers-and-history-strategy.md` as the original operational plan.

**Archives (3)**: `coenttb/swift-{html,css,svg}-types` archived as superseded by body-org spec packages (`swift-whatwg/swift-whatwg-html` v0.1.6, `swift-w3c/swift-w3c-css` v0.1.4, `swift-w3c/swift-w3c-svg` v0.2.0). `gh api PATCH archived=true` per repo under explicit user auth.

**Plan consolidation (v1.0 → v1.3, same-day)**: merged HANDOFF-heritage-transfers-and-history-strategy.md + session findings into new Research doc `swift-institute/Research/coenttb-ecosystem-heritage-transfer-plan.md` (Tier 2, RECOMMENDATION, scope=ecosystem-wide). Four revisions:
- v1.0 initial consolidation
- v1.1 absorb-and-verify pass (corrected swift-html-prism row mis-classified as "no tag" — `gh release` absent but `git tag 0.1.0` present; added swift-foundations Sibling Inventory confirming all 13 in-scope counterparts PRIVATE, 2 MISSING)
- v1.2 user direction absorption: **coenttb history NEVER squashed** (only ecosystem squashed; applied on top as single commit); posture A (accept PUBLIC on transfer); per-sibling launches are separate processes; swift-renderable destination resolved to `swift-primitives/swift-render-primitives`; swift-html-to-pdf → likely `swift-foundations/swift-pdf` (deferred, refactor prereq)
- v1.3 supervisor-review absorption: critical union-not-replace bug fixed in apply-on-top recipe (`git rm -rf . && git checkout ecosystem/main -- . && git add -A` replaces bare `git checkout ecosystem/main -- .`); new Phase 4 (URL-hygiene sweep, Phase-V analog per `github-organization-migration-swift-file-system.md` precedent); phases restructured 1–5

**Supervisor reviews (2 rounds)**: independent reviewer dispatched via copy-paste to fresh chat. Round 1 flagged critical recipe bug + path-dep hazard + stale "force-push points" text + cosmetic items. Round 2 was a bounded final-exchange (2 questions + optional closing note, capped at 250 words) converging on Option B for the path-dep hazard (post-transfer Phase-V sweep, matching swift-file-system precedent) and rm+checkout primary / plumbing footnote for the recipe fix.

**Phase 1 executions (4 transfers)**: W7 ABSENT-destination siblings transferred cleanly.
- swift-html-chart: 51184a8..bc76535 ff, 4 hygiene ahead (swiftlint, swift-format, LICENSE reformat, .swift-format indent)
- swift-html-prism: ef3e673..fe033cf ff, same 4 hygiene
- swift-html-css-pointfree: dbda286..d0ced83 ff, 8 ahead including structural `swift-html-types → swift-html-standard` migration (cf02fdc; supervisor-verified target PUBLIC + URL-deps only — no visibility/path-dep hazard)
- swift-html-fontawesome: 452af0d..8dd9488 ff, 1 hygiene ahead

Recipe per repo: `gh api transfer` → `git remote set-url` → `git fetch` → `git merge --no-edit origin/main` (no-op — local strictly ahead in each case) → regular `git push`. **Zero force-push, zero coenttb history rewrite** across all 4. 1★ preserved each; dependabot PRs moved with repos; coenttb URLs 301-redirect to swift-foundations.

**HANDOFF.md re-stamped** post-Phase-1 per [SUPER-011]: Ground Rules 1–6 all verified (Rule 2 exercised on 17 local-only commits across 4 repos, all fell default-commit); Phase 2 entry requirements carried forward (swift-renderable WIP disposition + Stage 1 dep-visibility audit on primitives destination).

**Final `/handoff` produced copy-pastable resumption prompt** for Phase 2 in a fresh session.

**HANDOFF scan per [REFL-009]**: 18 files at workspace root. 2 in-session-scope: `HANDOFF.md` (re-stamped; Phase 2 work in flight; annotated-and-left), `HANDOFF-heritage-transfers-and-history-strategy.md` (SUPERSEDED header added v1.0 consolidation; absorbed into Research plan; annotated-and-left — deletion is the [REFL-009]-prescribed outcome but deferred pending user auth, since the workspace root is not git-tracked and auto-mode requires explicit confirmation for non-recoverable deletion). 16 out-of-session-scope: HANDOFF-{borrow-protocol-unification-phase-9, borrow-protocol-unification-plan, ci-centralization, ci-rollout, executor-main-platform-runloop, io-completion-migration, migration-audit, package-refactor, path-decomposition, primitive-protocol-audit, self-projection-default-pattern, standards-org-migration, swift-testing-successor-migration, tagged-primitives-rename, tagged-unchecked-inventory, worker-id-typed-retype}.md — not touched this session, no cleanup authority per [REFL-009] bounded-cleanup rule.

## What Worked and What Didn't

**Worked**:
- **Iterative absorb-verify-review on the plan doc**. v1.0 → v1.3 in one session sounds like churn but each revision was triggered by distinct new information (verification pass; user direction; supervisor review). Frontmatter changelog absorbed the history cleanly. By v1.3 the recipe was correct, the phases were clean, and execution was straightforward.
- **Per-repo Rule 6 auth discipline**. 4 transfers + 3 archives all gated on explicit user authorization. No surprise actions. When the system denied a PR-close op without auth, the denial was correct and I adjusted.
- **Phase 1 mechanic validated across blast-radius spectrum**. Simplest (swift-html-fontawesome: 1 hygiene commit) through largest-drift (swift-html-css-pointfree: 8 commits including structural migration). Gives confidence that Phase 2's harder rename-and-reconcile recipe stands on a proven base.
- **Bounded final-exchange with supervisor**. The "2 questions + optional closing note, 250 words, no meta-commentary" framing converged the review cycle in one round with actionable output.
- **The handoff resumption prompt** integrates the v1.3.0 Research plan as the canonical strategy anchor, lets the next session verify-and-continue without re-consolidating.

**Didn't work initially**:
- **The apply-on-top recipe had a critical bug** I didn't catch before the supervisor did. Bare `git checkout ecosystem/main -- .` produces UNION (coenttb-only files remain), not REPLACE. A 3-line scratch repo empirically reproduces the failure in ~10 seconds. I wrote the recipe from mental model without validating it.
- **swift-html-prism mis-classified as "no tag"**. I used `gh repo view --json latestRelease` which returned null (no GitHub Release published) and concluded "no tag." `git describe --tags --abbrev=0` returned `0.1.0`. Two different API surfaces answering different questions; I conflated them.
- **swift-html-fontawesome PR #3 mis-classified as "substantive"** on first scan. Branch name `dependabot/swift/github.com/coenttb/swift-html-0.17.2` makes it obviously dependabot-generated; I was thrown by the subject ("bump swift-html 0.11.1 → 0.17.2") sounding more meaningful than the typical `actions/checkout`.
- **Path-dep hazard framed as binary initially**. I matched supervisor's binary framing (URL-ify or monorepo-only). Only after pushing back did I produce the 4-option space (A pre-transfer URL-ify / B post-transfer sweep / C inline / D preserve coenttb Package.swift). Supervisor endorsed B. First-framing bias — whoever frames first anchors.
- **Over-corrected on "getting complicated" signal**. When user said "getting complicated very quickly," I swung to an archive-heavy recommendation. User pushed back: archive wasn't wanted; repurpose-at-swift-institute is personally important. My response mistook "this feels complex" for "abandon the goal" when the user wanted "find a simpler path to the same goal."

## Patterns and Root Causes

**1. Recipes with git mechanics need empirical verification before becoming canonical.** The apply-on-top bug was catchable in 10 seconds with a `/tmp/scratch && git init && ...` loop. I wrote the recipe from mental model; the supervisor ran a scratch test. The cost of mental-model recipes is that they look correct under reading (the `git checkout ref -- .` command exists, takes valid arguments, doesn't error) while being wrong under execution. Mental-model review by readers (including me, multiple times) won't catch it. Pattern: any "step N: `git command X` produces state Y" claim should be empirically reproduced before being written into a plan or handoff. The session's v1.3.0 recipe is fine; the v1.0–v1.2 versions had the bug.

**2. gh-API-layer vs git-concept-layer conflation.** `gh repo view --json latestRelease` answers "what GitHub Release is published?" — a curated, user-facing artifact. `git describe --tags --abbrev=0` answers "what tag exists in this repo's git history?" — a repo-intrinsic marker. Repositories can have git tags without GitHub Releases (releases must be manually created); less commonly, the reverse. For heritage-transfer recipes that use `git describe --tags`, the `gh release` API is the wrong classifier. Broader pattern: when the question is about git state, use git; when about GitHub state, use gh. Don't substitute one for the other.

**3. First-framing bias in collaborator-exchange.** The supervisor framed the path-dep hazard as binary; I mirrored. The 4-option space surfaced only after I stopped matching the supervisor's frame and forced enumeration. Had neither of us pushed beyond the binary, option D ("preserve coenttb Package.swift, apply only Sources/Tests") would have remained invisible and might have been a better fit for some cases. Pattern: when a trade-off is framed as A-or-B by a collaborator (including yourself in an earlier turn), explicitly enumerate options before accepting the frame.

**4. "Complex" is not "abandon the goal."** User signaled complexity with "getting quite complicated very quickly"; I heard "abandon transfer, archive instead." User's actual meaning was "find a simpler path to the same goal" — which eventually became the phased plan that keeps transfer-at-swift-institute as the direction while deferring the hardest parts. Pattern: when a principal user expresses overwhelm on a complex workstream, the right first response is to surface simpler mechanics toward the same goal, not to pivot to a different goal.

**5. Same-day rapid plan revision works when each revision has a distinct trigger.** v1.0 → v1.3 would be alarming churn if each revision were revising the same information. Here: v1.1 triggered by verification; v1.2 triggered by user direction; v1.3 triggered by supervisor review. Each revision captured genuinely-new constraints. The changelog discipline (frontmatter comment enumerating what each version captured) makes the trajectory legible. Pattern: rapid revision is fine when constraints are still surfacing; revision for revision's sake is not.

## Action Items

- [ ] **[skill]** research-process: add a requirement that git-mechanic claims in recipes (`step N: command X produces state Y`) MUST be empirically reproduced in a scratch repo before being written into a Research doc or handoff. Provenance: this session's v1.0–v1.2 apply-on-top recipe had a union-not-replace bug (bare `git checkout ref -- .` does not propagate deletions); 10-second scratch repo reproduces the failure; supervisor-caught; v1.3 patched to `git rm -rf . && git checkout ref -- . && git add -A`. Scope: any research or handoff doc that prescribes a git command sequence.
- [ ] **[skill]** swift-package (or a new gh-vs-git lookup doc): add a note on the GitHub Release vs git tag distinction — they answer different questions, and for heritage-transfer / squash recipes that use `git describe --tags --abbrev=0`, the `gh repo view --json latestRelease` API is the wrong classifier. Provenance: swift-html-prism mis-classified as "no tag" based on gh-release absence; `git describe --tags` returned 0.1.0.
- [ ] **[skill]** supervise: add a "bounded final-exchange" sub-rule to [SUPER-*] for terminating supervisor review cycles in one round — pre-frame the exchange as "no further discussion," ask explicit numbered questions, cap output length (e.g., 250 words), and forbid meta-commentary. Worked cleanly this session: supervisor converged on decisions (Option B for path-dep + rm+checkout primary) in one round, no drift. Provenance: supervisor's Q1+Q2+optional-closing-note reply pattern.
