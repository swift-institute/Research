---
date: 2026-05-07
session_objective: Remove per-package lint workflow from swift-tagged-primitives to stop advisory-noise and restore centralized CI pattern
packages:
  - swift-primitives/swift-tagged-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: informational
    target: n/a
    description: "Clean tactical execution; no action items surfaced"
---

# Tagged-Primitives Lint Workflow Removal

## What Happened

Tactical dispatch from `HANDOFF-stop-lint-advisory-noise.md` (workspace
root): delete `swift-tagged-primitives/.github/workflows/lint.yml`, the
architecture-cohort consumer workflow that violated the institute's
centralized + hierarchical CI/CD pattern ([CI-001], [CI-002], [CI-003]).
The workflow `uses:`-called `swift-foundations/swift-linter`'s reusable;
it fired red on every push because the cross-repo private-repo checkout
failed (per `feedback_private_repos_no_ci_runs`). Lint integration is
slated to land as a JOB inside the centralized swift-ci.yml when ready,
not as per-package consumer files.

Execution trace:

1. State verification per [HANDOFF-016]: HEAD at `91a82b9` (matches
   handoff cite); working tree clean.
2. Constraint-5 reference scan: three matches surfaced (`.swiftlint.yml`,
   `Lint/Package.swift`, `Lint/Sources/Lint/main.swift`); classified as
   non-triggers per [SUPER-028] decision matrix axis B (`.swiftlint.yml`
   is incidental "lint" substring; the Lint/ executable package is the
   consumer-side artifact the workflow was designed to invoke and the
   handoff explicitly acknowledges it).
3. `git rm` + single deletion-only commit `361bcf1` (1 file changed, 25
   deletions).
4. Per-action push authorization gate fired (handoff specified
   "per-action push authorization at terminal"); user confirmed.
5. Push: `91a82b9..361bcf1  main -> main`.
6. Empirical CI verification via `gh run list`: HEAD `361bcf1` triggered
   ONLY workflowName `CI`; prior commit `91a82b9` had triggered BOTH
   `CI` and `.github/workflows/lint.yml` (latter always failing). The
   advisory-noise source is empirically eliminated.
7. [SUPER-011] verification stamp landed in the handoff before reflection
   trigger; all five supervisor entries verified end-to-end with explicit
   evidence per the [SUPER-011] entry-type→evidence-form table.

Total wall-clock: ~10 minutes, matching the handoff's estimate.

**HANDOFF scan ([REFL-009])**: 40 files found at workspace root.

| Outcome | Count | Files |
|---|---|---|
| Deleted | 1 | `HANDOFF-stop-lint-advisory-noise.md` (all Next Steps complete; all 5 supervisor entries verified per the [SUPER-011] stamp; no pending escalation) |
| Annotated-and-left | 0 | — |
| Out-of-session-scope | 39 | Authored by other sessions; this session did not work their items, did not write them, and did not encounter their completion signals. Per [REFL-009] bounded-cleanup-authority + [REFL-009a] in-flight conservativism, left in place without annotation. |

The 39-file out-of-scope set is the orphan zone [HANDOFF-038] /
[HANDOFF-039] were designed to dissolve. Triaging it would require
per-file verification (closure signals, predecessor relationships,
≥14-day staleness applicability) that this dispatch's scope did not
include — flagged as an observation, not bundled.

## What Worked and What Didn't

**Worked**:

- Pre-deletion reference scan correctly classified the three substring
  matches as non-triggers. The handoff's `ask:` constraint #5 specified
  "the workflow file" — by intent, not by substring — and per
  [HANDOFF-018]'s "is my situation the class of case the author had in
  mind?" test the Lint/ executable package matches were obviously not
  the author's "unexpected reference" class.
- Empirical CI verification (compare HEAD's run-set to the prior
  commit's run-set via `gh run list`) is a clean, attestation-free way
  to verify acceptance criterion #3 ("subsequent push doesn't trigger
  swift-linter advisory job"). Direct observation of state, per
  [SUPER-022] / [REFL-012] discipline.
- The [SUPER-011] verification stamp (per-entry evidence in a table)
  closes the handoff's accountability trail before the reflection-and-
  delete cycle. Without the stamp, [REFL-009] would correctly leave the
  file in place pending verification.

**Didn't apply** (no friction surfaced):

- Zero drift signals fired ([SUPER-006] enumeration ran clean across
  all subordinate-side decisions).
- Zero class-(b)→(c) escalations needed; the pre-deletion scan did not
  surface any unexpected references.
- Handoff was fresh (~hours old); no [HANDOFF-016] staleness axes
  triggered.

## Patterns and Root Causes

The session is a clean tail of the broader 2026-05-07 swift-linter
architecture cohort (see `2026-05-07-swift-linter-architecture-cohort-execution.md`).
That cohort introduced a per-package consumer-workflow shape under
deadline pressure; this session is the cleanup that restores the
centralized + hierarchical CI/CD pattern the cohort temporarily violated.
The pattern is not novel — [CI-001]–[CI-003] codify it explicitly — but
the recurrence is informative: even with the architecture documented,
deadline-pressure authoring drifted into the per-package shape. The
institute's discipline is that such drift gets reverted promptly rather
than left as ecosystem state, which this dispatch executed.

The Lint/ executable package itself remains at the repo root, awaiting
the future centralized integration (`swift-linter` joining swift-ci.yml
as a job). The reusable workflow at `swift-foundations/swift-linter/.github/workflows/lint.yml`
is preserved for that future integration. Nothing about the linter
machinery is being abandoned — only the per-package wiring is being
peeled back to the centralized pattern's seam.

The decision matrix at [SUPER-028] (axis A classification + axis B
compliance form) worked smoothly on the Constraint-5 reference scan:
each substring match was classified as class-(a) "the handoff already
acknowledges this artifact class" → in-action compliant per [SUPER-024].
No escalation cluttering the user's queue for trivial substring matches.

## Action Items

(None — routine execution of a well-authored tactical dispatch; no
skill gaps, doc gaps, or research questions surfaced. The dispatch's
own provenance is captured in the cohort-execution reflection cited
above; this entry is the closing record.)
