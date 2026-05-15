---
date: 2026-05-14
session_objective: Execute prioritized recommendations from the 2026-05-14 CI infrastructure review (Phase A self-defect closures, Phase B validate-base centralization, Phase C cron-audit-base structured-inputs refactor) under principal-supervisor / relayed-subordinate model
packages:
  - swift-institute/.github
  - swift-institute/Skills
  - swift-institute/Audits
status: processed
processed_date: 2026-05-15
triage_outcomes:
  - type: skill_update
    target: handoff
    description: Extend [HANDOFF-021] Scope Enumeration with tracked-state pre-flight (git ls-files probe)
  - type: skill_update
    target: supervise
    description: Extend [SUPER-009] read-the-artifact with verify-named-blockers-exist sub-rule
  - type: skill_update
    target: handoff
    description: Extend [HANDOFF-009] Progressive Capture with unrelated-prior-task collision branch (rename to topic suffix)
---

# CI Review Arc — Phase A through Phase C: Supervision Gaps, Verification Discipline, and Relay Patterns

## What Happened

42-commit arc executed across `swift-institute/.github` (38) + `swift-institute/Skills` (1) + `swift-institute/Audits` (3), closing the prioritized recommendations from the 2026-05-14 unified CI review (`CI-REVIEW-2026-05-14.md`):

- **Phase A** (3 commits): self-defect closures — top-level `permissions:` on lint-org-bot-coverage.yml `workflow_call` reusable removed [CI-090]; yq install sha256sum gate [CI-082]; silent-SKIP gate in fixture-suite `run.sh`.
- **Phase B-1** (6 + outcome record `beaf55b`): authored `validate-base.yml` + `validate_lib.py` + `validators-manifest.yaml` + binding-validator pilot (checks 2+4 internal-consistency only — Skills cross-checks deferred to B-2 per supervisor adjudication); canary migration of validate-cache-policy.
- **Phase B-2** (17 commits): mechanical migration of 17 validators to thin callers of `validate-base.yml` + `validate_lib`; 2 skipped (validate-github-metadata + validate-package-structure — signature mismatch with the base contract); 5 manifest defects surfaced for follow-up.
- **Phase B-2 follow-up** (4 + outcome record `58e8eca`): Skills cross-checks 1+3 implemented via Option α (cross-repo Skills checkout via `swift-institute-bot` App-token); manifest defects remediated.
- **Phase B-3** (1 commit, after amend): harden-runner SHA pin uplift v2.12.2 → v2.19.1 across 3 standalone workflows.
- **Tracking-sweep** (2): pilot 7+17 validate-thin-callers and pilot 28 validate-sub-org-wrappers enforcement workflows tracked.
- **Phase C** (5 .github commits + 1 Skills commit + outcome record `616cc51`): cron-audit-base.yml refactored from free-form `audit-step:` shell-string to structured inputs; `cron-audit-runner.py` + `audit-setup-yamllint.py` authored; 3 callers migrated; [CI-081] body amended for no-branch-protection regime.

The user worked relay-style with a separate-chat subordinate throughout: I (principal) composed dispatch briefs with supervisor ground rules + acceptance criteria per [SUPER-002] / [SUPER-009]; the user pasted to the subordinate; the subordinate executed and reported back; I verified independently and adjudicated.

**Three principal decisions sealed via AskUserQuestion**:
- Q1=A — outcome-record visibility = status quo (`emit()` URL extension NOT pursued)
- Q2=B — cron-audit-base structured-inputs refactor (Phase C scope)
- Option α — Skills cross-repo auth via existing `swift-institute-bot` App-token (not β extract-and-mirror; not γ defer)

**Two notable supervision events**:

1. **Phase B-3 untracked-file gap** (commit `5ebcac5` → `1fb7604` amend). The Phase B-3 dispatch named `validate-thin-callers.yml` as a SHA-uplift target without my checking its tracked state. The subordinate's `git add` staged the entire 152-line untracked file alongside the 1-line intended change. Subordinate halted per ground rule #6, surfaced option γ (amend to drop), I approved. Amend used `git reset --soft HEAD~1` + `git restore --staged` + recommit with 3 files instead of 4. The untracked file later became its own deliberate tracking-sweep commit (`d9baf70`).

2. **Skills installation pre-existed**. Option α's adjudication framed swift-institute/Skills App-installation as "required admin op." User-side independent verification (and my own `gh api` re-check) showed the bot has had org-wide `contents: write` since 2026-04-29 (`installation_id: 128087060`) — months before this arc. The HALT doc's "Required extension" framing was operationally moot. CI self-firing for binding checks 1+3 worked immediately on next push.

## What Worked and What Didn't

**Worked**:
- **Per-phase verification discipline** ([SUPER-009] disk/git/build-output verifiable criteria) caught defects at boundaries rather than at end-of-arc. The Phase B-3 untracked-file gap was caught at the commit-shape verification step, not at end-of-arc audit.
- **Subordinate's pre-staged prep docs** (`CI-REVIEW-PHASE-A-DIFFS-2026-05-14.md`, `CI-REVIEW-PHASE-B-DESIGN-2026-05-14.md`, `CI-REVIEW-OPEN-QUESTIONS-2026-05-14.md`) under a bounded ~40-min prep window produced execution-ready dispatches. The "prep before dispatch" pattern was a force multiplier: when I authorized Phase A or B, the design doc was already in place; the dispatch became just supervisor ground rules + acceptance criteria + reference to the doc.
- **Boundary-triggered intervention** per [SUPER-007]: subordinate halted on the Skills auth-surface decision (class (c) per [SUPER-005] — affects user-stated constraints) and again on the 2 incompatible validators (signature mismatch from validate-base.yml contract). Both halts surfaced cleanly for adjudication; both adjudications were quick because the briefs framed the options well.
- **End-of-arc /handoff** producing a clean Phase C resumption brief — the subordinate executed Phase C from the HANDOFF.md without needing live supervision.

**Didn't work**:
- **Executor-vs-supervisor mode confusion**. Mid-session I started executing the Phase A edits inline (`Edit` calls on `lint-org-bot-coverage.yml`, `read-orgs/action.yml`, partial `run.sh`) instead of dispatching to the subordinate. User course-corrected: "I think its better if the subordinate does the work and you supervise." I had to switch modes. Cost: 4 edits I'd applied inline had to be communicated to the subordinate as "parent session applied these; verify against the design doc + finish the remaining 3 edits." Should have caught this earlier — the architecture (separate-chat subordinate via user relay) was clear from the first dispatch; I drifted.
- **Phase B-3 dispatch supervision gap** (the named-targets-not-state-targets failure detailed below). Confidence at dispatch-write time was high — the file was in the manifest, the v2.12.2 SHA was in it — but `git ls-files` would have revealed it wasn't tracked.
- **HANDOFF.md collision at end-of-arc**. When `/handoff` was invoked, a 22-day-stale unrelated `HANDOFF.md` was occupying the canonical filename slot (Property Primitives 0.1.0 launch, blocked on tag auth). [HANDOFF-009] progressive-capture only addresses same-goal updates; there's no codified procedure for unrelated-prior-HANDOFF.md overwriting. I ad-hoc renamed to topic-suffix to preserve the prior work and wrote a fresh `HANDOFF.md`. Ad-hoc resolution was correct but not codified.

## Patterns and Root Causes

The dominant pattern: **named-targets-not-state-targets**. Three distinct instances surfaced in one arc:

1. **Phase B-3 untracked-file gap**. I named `validate-thin-callers.yml` as a target by its identity (manifest entry, v2.12.2 presence) rather than its state (tracked vs untracked). The file existed in the manifest's `workflow-file:` field for [GH-REPO-074] etc., so it was "real" — but a manifest entry doesn't imply the file is tracked in git. The dispatch's mechanical scope (grep for v2.12.2) would have found the file regardless of tracked state; the scope didn't gate on tracked state.

2. **Skills installation as "required admin op"**. The HALT doc framed Option α as requiring an explicit App-install action. The framing assumed the bot's installation scope was per-repo selective and would need extension. Reality: the bot was installed org-wide with `contents: write` since 2026-04-29. The HALT doc named the admin op as a requirement based on its mental model of the auth surface, not on a live check of the installation state via `gh api /orgs/<org>/installations`.

3. **HANDOFF.md collision**. I named the destination `HANDOFF.md` without checking its current state (occupied by an unrelated 22-day-stale handoff). [HANDOFF-009] progressive-capture has a built-in state-check ("if HANDOFF.md exists, read it") but the rule's branches don't cover "unrelated-prior-task" — only same-task progressive update.

These three are variants of the same gap: the principal/writer named a target by its identity, the subordinate (or git, or the filesystem) executed against the target's state, and the gap between identity and state is where the defect lives. The principle generalizes [HANDOFF-013a]'s writer-side prior-research grep (same shape on the research-citation axis). The fix is symmetric: at dispatch-write time, run a **state probe** against each named target — `git ls-files`, `gh api`, `ls`, whatever the relevant state oracle is. Cost is seconds; cost of skipping cascades to mid-execution halts and amend cycles.

A secondary pattern: **per-phase verification scales linearly with phase count; per-arc verification scales with O(commits²) investigation radius**. The arc's 42 commits could have been verified once at end-of-arc — but verifying at end-of-arc means cascading failure investigation across all 42 if anything is off. Per-phase verification ([SUPER-009] discipline) bounds the investigation radius to the current phase. The fixture suite + binding-validator probes at each phase boundary cost ~30 seconds; without them, the Phase B-3 issue would have surfaced at end-of-arc with no clear bisect bound.

A tertiary pattern: **prep-before-dispatch as a force multiplier**. The subordinate's three pre-staged prep docs collapsed Phase A/B/C/Q1/Q2 from "design and dispatch" into "dispatch references prior design." This worked because the prep was bounded (~40 min cap), self-contained (each doc carried its own acceptance criteria), and principal-reviewable (I could read them in ~15 min before authorizing dispatch). The pattern is reusable for any multi-phase arc: pre-stage design docs in a bounded prep window, then dispatch executes them.

## Action Items

- [ ] **[skill]** handoff: extend [HANDOFF-021] (Scope Enumeration at Write-Time) with a **tracked-state pre-flight** requirement when the dispatched scope is "apply X to every file matching pattern P" — at handoff-write time, run `git ls-files <enumerated paths>` and flag any untracked targets in a `## Tracked-State Inventory` section (treatment label: tracked / untracked-leave-alone / untracked-but-to-track). Generalizes [HANDOFF-013a]'s writer-side prior-research grep to file-tracking state. Provenance: Phase B-3 `5ebcac5` → `1fb7604` amend.

- [ ] **[skill]** supervise: extend [SUPER-009]'s read-the-artifact rule with a **verify-named-blockers-exist** sub-rule — when a HALT doc or dispatch names an external action as a blocker (App-install, branch-creation, secret-rotation, manual UI step), the principal MUST run the relevant state probe (e.g., `gh api /orgs/<org>/installations` for App-installs) before adjudicating between options. Generalizes from artifact-summary-vs-content (which [SUPER-009] already covers) to operational-state-vs-claimed-state. Provenance: Skills installation pre-existing since 2026-04-29 contradicted Option α's "required admin op" framing.

- [ ] **[skill]** handoff: extend [HANDOFF-009] Progressive Capture with an **unrelated-prior-HANDOFF.md collision** branch — when `/handoff` is invoked and the existing `HANDOFF.md` is for a different task entirely (no goal-overlap, no shared scope, not stale-triage-eligible per [HANDOFF-038] alone), the procedure is rename-to-topic-suffix (preserve the prior task's work as `HANDOFF-<topic>.md`) + write fresh `HANDOFF.md` for the current task. Codifies the ad-hoc move performed at end of this session.
