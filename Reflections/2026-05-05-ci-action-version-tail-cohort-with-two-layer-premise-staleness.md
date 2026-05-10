---
date: 2026-05-05
session_objective: Execute HANDOFF-ci-action-version-tail.md (3 deferred CI items from the deduplication cohort)
packages:
  - swift-institute/.github
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction research-workflow-mirrors-production-shape captured in feedback memory. NoAction canary-verify-real-data-path captured in feedback memory. NoAction [HANDOFF-016] cross-reference candidate for future amendment.
---

# CI action-version-tail cohort with two-layer premise-staleness correction

## What Happened

Executed HANDOFF-ci-action-version-tail.md to closure: Step 1
(`download-artifact@v4` → `@v8` migration), Step 2 (`app-id` →
`client-id` deprecation cleanup), Step 3 (submit-dep-graph
cron-base candidacy revisit). Final disposition: Step 1 LANDED,
Step 2 LANDED, Step 3 CLOSED-DON'T-REFACTOR.

**Step 1 followed a falsification → revert → redesign → re-land arc.**

The handoff cited a prior session's revert message attributing v7+v8
download-artifact failures to layout incompatibility. Independent
verification (a post-revert v4 run that ALSO failed with the same
error) proved the actual cause was an unrelated `dep-graph`
label-missing bug independently fixed at `ddf3b59`. **Layer 1**
of premise-staleness corrected.

A v1.0.0 research workflow (run 25377059431) used a 2-artifact
fixture and found "layout identical across v4..v8." The conclusion
was correct *for the fixture*. Production matrix legs are 1-artifact;
v8 has an `artifacts.length === 1 → resolvedPath` flatten branch
the 2-artifact fixture never exercised. Production canaries falsified
the v1.0.0 RECOMMENDATION within hours of the migration commits
landing — `submit-dep-graph-weekly` hard-failed (`/tmp/counts/*/*-counts.txt`
glob no-match), `lint-license-header-weekly` silently false-positive-succeeded
(`[[ -e "$f" ]] || continue` guard absorbed the empty glob; report
job emitted "All counts zero" while the sweep had real findings).
**Layer 2** of premise-staleness — generated mid-session — corrected.

Reverts at `1092349` + `d2c7e3d` restored v4. v2.0.0 research
(run 25378551607) deliberately exercised single + multi-artifact
cases against v8 with a v4 control. Path A (`find /tmp/counts -type f
-name '*-counts.txt'` + filename `basename %-counts.txt$` for org
extraction) recovered the file in v8 single-artifact-flatten where
the original glob misses, and matched v4 in all nested cases.
Production migration re-landed bundled with the consumer-script
rewrite at `2b817a3` + `a94f7b1`. v2.0.0 canaries verified real-data
path exercised (license-header updated tracking issue #9; dep-graph
dry-run aggregated 5 sweep successes correctly).

**Step 2 was straightforward** after Step 1's discipline: single
batched commit `2d61367` mechanically replaced 9 `app-id:` occurrences
across 7 tracked workflow files with `client-id:`; principal
configured `SWIFT_INSTITUTE_BOT_APP_CLIENT_ID` org-level secret
(value `Iv23liyRxajKWQDxorCp`) out-of-band. Canaries verified
token-mint succeeds with `client-id` and no `app-id` deprecation
warning anywhere.

**Step 3 closed without refactor:** the per-target POST-to-`dependency-graph/snapshots`
in submit-dep-graph-weekly is a structurally different abstraction
class from "audit + count + report"; absorbing it into cron-audit-base
would require +1 input (`aux-filename-suffix`) plus 2-layer dry-run
disambiguation; the API expansion outweighs ~176 lines saved.

**Memory entry added during the session**:
`feedback_workspace_scope_l1_only.md` — when the user clarified
"limit scope to swift-primitives. L2/L3 is NOT YET refactored,"
the scope-discipline rule was pinned: cross-org canary failures from
not-yet-refactored layers are baseline noise, not migration regressions.

**HANDOFF triage (per [REFL-009])**: 1 file in this session's
cleanup authority (`HANDOFF-ci-action-version-tail.md`) — closure-
stamped at top + closure summary appended at bottom per principal
directive ("preserve the file — do NOT delete; mirror the
deduplication-cohort shape"). ~29 other workspace-root HANDOFF files
out-of-authority; left unchanged.

## What Worked and What Didn't

**Worked:**

- **Principal verification gate.** When I requested push #2 cold (no
  receipts), the principal demanded the empirical evidence + Research
  doc + commit diffs before authorizing — exactly the [SUPER-006] drift
  signal #6 ("silent decision on an open question"). This gate caught
  nothing of substance the first time (push #2 went through), but the
  pattern of "surface receipts before push" became reflexive for the
  v2.0.0 cycle and Step 2.
- **Revert-on-falsification was clean and fast.** Two `git revert
  --no-edit` + push, post-revert canaries verified v4 restoration
  within ~5 minutes of canary-time falsification. The "if mint fails:
  revert immediately" precondition was extended naturally to
  "if any canary fails: revert immediately" by the principal.
- **v2.0.0 research design** deliberately exercised the *production
  shape* (single-artifact + pattern-filtered multi-artifact) plus a
  v4 control, plus per-file org-extraction sanity-check. The match-set
  table in the Research doc made the validation gate testable in a
  glance.
- **Bundled migration commits** (bump + Path A rewrite per file)
  prevented the prior-failure single-line shape from recurring.

**Didn't work:**

- **v1.0.0 research fixture diverged from production shape.** Two
  artifacts vs one. The fixture confirmed an invariant for the
  irrelevant case while missing the case production exercises on
  every cron firing. A research workflow that produces a "layout
  identical" finding for one fixture and breaks production within
  hours is the worst-of-both: it generates RECOMMENDATIONs that
  empirically falsify.
- **First push request lacked receipts.** I asked "OK to push?" with
  empirical evidence sitting in the run logs, the Research doc
  freshly committed, and commit diffs ready to surface — but didn't
  surface any of it preemptively. The principal's [SUPER-006] check
  was load-bearing.
- **Initial canary verification didn't notice silent miscount in
  `lint-license-header-weekly`.** The canary returned "success" and I
  reported success without looking at whether the report job actually
  read data or guard-skipped. The hard-fail in `submit-dep-graph-weekly`
  forced the deeper investigation that surfaced the silent miscount;
  if both canaries had used the `[[ -e ]]` guard pattern, the regression
  would have rolled into production undetected.
- **Cross-org investigation expanded beyond migration scope.** When
  sync-metadata-nightly's swift-ietf + swift-primitives matrix legs
  failed with HTTP 502/504/401 on api.github.com/graphql, I started
  investigating root cause. The user course-corrected: "limit scope
  to swift-primitives. L2/L3 is NOT YET refactored." Saved as memory.

## Patterns and Root Causes

**Premise-staleness compounds across sessions.** [HANDOFF-016] codifies
the premise-staleness defect for handoffs: a handoff inherits a
premise from the prior session; if the premise was wrong, the receiving
session executes the right discipline against the wrong question. This
session is a worked example of the pattern compounding — Layer 1
(inherited from a prior session's misdiagnosis) caused the handoff to
frame Step 1 as a "ladder walk" against a non-existent layout
incompatibility; Layer 2 (generated mid-session) caused the v1.0.0
research recommendation to be correct-for-its-fixture but inapplicable
to production. The structural fix is: research fixtures must mirror
production shape AT THE SHAPE LEVEL — not just "exercise the API",
but "exercise the API with the same artifact count, matrix size,
payload structure that production uses."

**Silent-success is a worse failure mode than hard-fail.** The
`lint-license-header-weekly` canary's silent miscount (returning
green while emitting "All counts zero across orgs" from a guard-skip
on an empty glob) was worse than the hard-fail in
`submit-dep-graph-weekly` because it would have rolled through 5+
weekly cron schedules undetected before the absent tracking-issue
gap got noticed. Migrations whose consumers have empty-input guards
need verification that the guard wasn't tripped. The mechanical
verification is: did the loop iterate at least once on real data?
A `find -ls` of the artifact directory + a check that `total_*`
counters are non-zero (when the sweep produced data) is the correct
shape.

**Verification gates are load-bearing on volatile work.** The
principal's "show receipts before push" gate caught zero defects on
push #2 (where receipts confirmed the migration was correct) but
established the discipline that surfaced the v2.0.0 redesign
correctly on push #4. Volatile work — anything where canary signal
diverges from research signal — needs the gate. Routine work doesn't.
The challenge for a subordinate is recognizing volatile work in
advance; a useful proxy is "is there a recent prior-art failure cited
in the handoff?" (here, `5bdef3f`'s revert).

**Scope discipline beats issue-by-issue investigation in
multi-layer ecosystems.** When a cross-org canary surfaces failures
from layers that aren't yet in scope, investigating each one expands
agent context for no benefit. The user's "L2/L3 is NOT YET refactored"
directive saved a debugging tangent on swift-ietf's HTTP 504 (would
have led to an organizational-permission rabbit hole irrelevant to
this work).

## Action Items

- [ ] **[memory]** feedback_research_workflow_must_mirror_production_shape: When a research workflow validates an action's behavior against a production case, the test fixtures MUST mirror the production shape (artifact count, matrix size, payload structure) at the shape level — not just "exercise the API." A 2-artifact fixture for a 1-artifact production case is the worst-of-both: confirms invariants for the irrelevant case while missing the actual production behavior. Verified empirically 2026-05-05 via the v1.0.0 → v2.0.0 download-artifact research arc.
- [ ] **[memory]** feedback_canary_verify_real_data_path: When a workflow has guard-skip patterns (`[[ -e "$f" ]] || continue`, `set -uo pipefail` empty-glob behavior, etc.), canary verification MUST exercise the real-data path — find the data, parse it, confirm non-zero loop iterations or non-zero counter increments when the upstream produced data. A green canary that silently guard-skipped is a worse outcome than hard-fail because it masks the regression. Verified 2026-05-05 via the lint-license-header silent-miscount cycle.
- [ ] **[skill]** handoff: Add cross-reference from `[HANDOFF-016]` to `Research/Reflections/2026-05-05-ci-action-version-tail-cohort-with-two-layer-premise-staleness.md` as a worked example of premise-staleness compounding across sessions (Layer 1 inherited + Layer 2 generated mid-session).
