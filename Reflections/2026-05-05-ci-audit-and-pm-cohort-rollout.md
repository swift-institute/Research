---
date: 2026-05-05
session_objective: Independent fresh-eyes audit of the 3-cohort CI corpus that closed today, plus autonomous execution of the resulting refactor PM cohorts under canary verification
packages:
  - swift-institute/.github
  - swift-primitives/.github
status: pending
---

# CI audit + PM cohort rollout — refactor framework, composite-tech-stack constraints, and the danger of changelog skimming

## What Happened

Session started as a read-only audit of the centralized CI corpus that the
parent session closed today across three cohorts (perfecting / deduplication /
action-version-tail). The audit brief
(`AUDIT-centralized-ci-quality-and-refactor-inventory.md`) requested two
deliverables: a quality check against the canonical `[CI-001]–[CI-060]`
rules in `Skills/ci-cd-workflows`, and a refactor inventory biased toward
primitive composables.

Quality check produced 4 actionable findings (F1 lychee version stale, F2/F3
header-comment drift in universal + L1 wrapper post-uniformity-sweep, F4
permissions-block parity gap on submit-dep-graph-weekly's report job) plus 7
LOW/OBSERVATIONs. Refactor inventory produced 4 PM candidates (PM #1
`enumerate-org-public-repos`, PM #2 `clone-repo-with-app-token`, PM #3
`upsert-tracking-issue`, PM #4 `orgs.yaml` data file).

Read-only audit completed; verdict CONDITIONAL GO. Then the principal
authorized autonomous execution. Three sub-arcs followed.

**F-series + O2 mechanical fixes (5 commits + 1 fix-forward).** Lychee bump
0.20.1 → 0.24.2 regressed the canary because I misread the 0.24.0/0.24.1
changelog: "Restore naming convention of released files" was filename-only,
not internal-structure. The 0.24+ tarball nests the binary under
`lychee-x86_64-unknown-linux-gnu/lychee` while 0.20.x had it flat. Fixed
forward (commit `762e1b4`); inline comment now warns the next bumper.
Canary green post-fix.

**Refactor framework (mid-session deliverable).** Principal asked for "a
framework with which to decide the structural and principally correct
direction." Authored a 7-axis evaluation: dup×class-boundary, tech-stack
fit, pattern stability, blast-radius vs reversibility, tier-coherence,
population maturity, cohort discipline. Applied to the 4 PMs, the framework
yielded PM #1 PROCEED, PM #2 RE-SCOPE (Axis 2 fail — composites can't be
in shell for-loops), PM #3 PROCEED-with-partial-scope (1 of 5 sites is
in-loop), PM #4 DEFER (Axis 6 population-maturity). Principal then
overrode Axis 6 with "we're in alpha development phase! ignore population
maturity and similar." PM #4 promoted to PROCEED.

**Cohort 1 (PM #1 — `enumerate-org-public-repos`).** Composite + 3 caller
conversions. Initial conversion used `./.github/actions/...` local paths;
canary on submit-dep-graph-weekly (which runs in a `swift:6.3` container
without `actions/checkout`) failed with "Can't find 'action.yml' under
/home/runner/work/.github/.github/.github/actions/...". Fix-forward
(`a8d8687`) switched all 3 callers to cross-repo
`swift-institute/.github/.github/actions/...@main` refs — same pattern as
the existing `configure-private-repos` and `install-swift-sdk` callers.
3 canaries green in org-mode (the original repo-mode canaries skipped the
composite via the `if: ${{ inputs.repo == '' }}` gate, which I missed
on first dispatch).

**F5 — sync-metadata public-only scoping.** Mid-Cohort-2, sync-metadata
canary failed with HTTP 504 on the per-repo loop after ~50 swift-primitives
repos. User asked: *"only carrier/tagged/property are public; CI should
only run for public repos. So why are we getting rate limits?"*
Investigation showed the pre-existing all-visibility sweep was an oversight
(visibility field fetched but never filtered on); the principal clarified
*"we don't have billing, so private repos NEVER get CI cycles and always
fail. We just want metadata.yaml respected in a way that works."* One-line
fix to `visibility: 'public'` (commit `1dc2e06`); sync now completes in
6 seconds with 6 public repos vs prior 504 mid-loop.

**Cohort 2 (PM #3 — `upsert-tracking-issue`).** Composite + 4 caller
conversions; link-check.yml's per-target site stayed inline (Axis 2).
End-to-end verification was indirect: dry-run dispatches early-exit before
the upsert path. The transient 504 on swift-primitives during sync canary
actually triggered sync-metadata-nightly's report job into the
sweep_result=failure branch, exercising my upsert composite end-to-end —
issue #10 created on swift-institute/.github confirmed the create path
worked. Local shell test against test issue #11 confirmed close + edit
subsystems.

**Cohort 3 (PM #4 — `read-orgs` + `orgs.yaml`).** Composite + 17-org
manifest + 7 orchestrator conversions to the config-job pattern. All 7
canaries green; spot-check confirmed read-orgs returns the expected JSON
array.

**Coordination ping at end.** Another agent (running
HANDOFF-rollout-phase-1.md, SwiftLint/swift-format tiered architecture)
asked V1-V5 verification on file-edit-window conflicts. Surfaced one
critical defect in their plan: their DELETE list named the per-PR γ-1a
workflow + audit-foundation-import.py script, but missed the WEEKLY
orchestrator that ALSO curl-fetches the same script. Wave 1 as proposed
would have left the corpus broken between Wave 1 and Wave 5.

**Net commit count: 25 across 2 repos, all canary-verified.**

**HANDOFF scan**: 24 `HANDOFF-*.md` files at `~/Developer/` root; 0 deleted,
0 annotated, 24 out-of-scope. The audit brief explicitly listed three
closed-stamped handoffs (`HANDOFF-centralized-ci-deduplication.md`,
`HANDOFF-ci-action-version-tail.md`, `HANDOFF-ci-rollout-complete-2026-05-05.md`)
as reference-only-not-authoritative — I encountered their completion
signals during the audit but the brief's "do not consult as authoritative"
clause excluded them from this session's cleanup authority. Two active
in-flight handoffs (`HANDOFF-swift-primitives-ci-cd-perfection.md`,
`HANDOFF-rollout-phase-1.md`) excluded per [REFL-009a]
in-flight-conservativism (the latter's authoring agent pinged me
mid-session for V1-V5 verification on overlapping CI files; clearly
in-flight). Remaining 19 handoffs untouched and outside this session's
working scope. Per [REFL-009] bounded cleanup authority I am NOT
applying the [HANDOFF-038] stale-override here — none of the 24 fall
within (a) wrote, (b) actively worked, or (c) encountered-completion-
signals as primary work product. **AUDIT findings**: per [REFL-010],
already updated in-session — F1-F5 + O2 carry RESOLVED + commit refs
+ canary run IDs; PM #1/#3/#4 carry RESOLVED + cohort summaries; PM #2
carries NOT EXTRACTED with re-scope rationale; OBSERVATIONs preserved
with no status change.

## What Worked and What Didn't

**Worked**

- The framework crystallization mid-session was the right move. Without it,
  I would have proceeded into PM #2 design and discovered the composite-
  in-shell-loop constraint mid-implementation (~30 min wasted). The
  framework caught it pre-design (Axis 2). Principal-driven prompt for
  the framework was the load-bearing input.
- Canary discipline caught two regressions before they hit Monday's cron:
  F1 fix-forward (lychee install path), Cohort 1 fix-forward (cross-repo
  @main). Both single-line fixes; both shipped before any user-visible
  effect.
- The 504 surprise on sync-metadata was actually productive — it
  inadvertently exercised the upsert composite's create path on a real
  workload, providing the end-to-end verification I couldn't get from
  dry-run dispatches.
- Existing-corpus-pattern matching as a default. When the cross-repo
  composite-ref question came up, looking at how `configure-private-repos`
  was already referenced (`swift-institute/.github/.github/actions/
  configure-private-repos@main`) gave the answer immediately. The corpus
  had already solved the problem; I just had to read it.

**Didn't work**

- I read the lychee 0.24.1 changelog line "Restore naming convention of
  released files" and concluded the 0.24.0 break was fully reverted. It
  was filename-only. The actual archive STRUCTURE (binary nested in
  subdirectory vs flat at root) was NOT reverted. This was a confident
  misread that the canary caught — but I had already shipped the bump
  commit. Cost: 1 fix-forward commit + ~5 minutes of reverification.
  The defect was in changelog SKIMMING — I didn't tar-list the archive
  before claiming compatibility.
- First Cohort 1 canary scoping. I dispatched link-check.yml with
  `repo=swift-primitives/swift-carrier-primitives` (single-repo mode)
  to verify, but my composite call was gated `if: ${{ inputs.repo == '' }}`
  for org-mode-only. So the canary "succeeded" without exercising the
  composite. submit-dep-graph (no skip path, container) caught the
  cross-repo-ref bug instead. Cost: false-positive on link-check + an
  extra org-mode dispatch round.
- Initial sync-metadata canary on Cohort 2: I dispatched expecting
  end-to-end upsert verification, didn't realize all the dry-run paths
  early-exit before composite call. Spent ~10 minutes re-thinking
  verification strategy before realizing the 504 had inadvertently fired
  the composite.

**Confidence calibration**

High confidence on: corpus reads, audit findings, framework axes,
mechanical edits.

Low confidence (correctly): canary verification of upsert-only paths.
Articulated this in the user-facing report ("residual risk: real-world
verification happens on first findings").

Low confidence (incorrectly): lychee changelog interpretation. Should
have been "I have not verified the tarball structure," not "no breaking
changes affect my flags."

## Patterns and Root Causes

**Pattern 1: composite actions are second-class to inline shell in two
specific cases.** GitHub Actions composites cannot be invoked inside
shell for-loops, AND `./local/path` references require the calling repo
to be checked out. Both bit me (PM #2 axis-2 prediction; Cohort 1
fix-forward). The deeper pattern: a composite action looks like a
function call but is structurally a workflow step — it inherits all of
GH Actions' execution model constraints. When extracting a primitive,
the question is not just "does this pattern recur 5+ times" but "can
the recurrence shape be expressed as a top-level step." Per-iteration
work (in-loop) cannot. Per-step work in containers without checkout
needs cross-repo `@main` refs.

This generalizes Axis 2 of my framework: tech-stack-fit isn't just a
binary check; it's a multi-dimensional check across (a) callsite
position (top-level vs in-loop), (b) runner environment (host vs
container), (c) checkout state. The framework as stated covered (a)
explicitly and (b)+(c) implicitly. The next refactor should make all
three explicit.

**Pattern 2: the changelog skim is the "I read it" lie.** I read the
0.24.0 + 0.24.1 release notes, formed a mental model ("breaking change
reverted by point release"), and shipped a bump on that mental model.
The mental model was wrong because I extrapolated from the SUMMARY
LINE without reading what was actually reverted. The defect class:
relying on summary-level changelog reads to predict tarball/binary/CLI
behavior. The fix: when bumping a tool whose release notes describe
behavioral or structural changes, run the actual probe (`tar -tzf`,
`--help`, `--version` against current flags) before claiming
compatibility. The cost is seconds; the cost of the wrong claim is a
fix-forward commit and reviewer credibility.

This connects to `[REFL-011]` Correction-from-Primary-Source rule —
my failure here was at the AUTHORING stage, not the correcting stage,
but the same root cause: mental model from artifact, not value from
primary source.

**Pattern 3: principal-driven-framework as catalyst for design quality.**
The framework wasn't requested in the original audit brief; it emerged
mid-session when the principal asked "framework to decide structural and
principally correct direction." The act of articulating axes forced me
to confront that PM #2 wasn't actually feasible (Axis 2), preempting
~30 min of wasted design work. Without the framework, I would have
discovered the constraint at the implementation step.

The pattern: when stuck between "do all of it autonomously" and "stop
and ask," the principal-prompted framework articulation is the
synthesis. It externalizes the decision criteria so they can be
reviewed before action commits. This is the same shape as
`[CI-050]` mass-rollout authorization gating but at a deeper level —
the framework is the per-action authorization criterion, articulated
once.

**Pattern 4: canary scoping must exercise the new code path.** Two
distinct false-positive canaries this session (link-check repo-mode +
all dry-run-mode upsert canaries). Both passed because the new code
was gated off in the dispatched mode. The pattern: "dispatch a workflow
to verify changes" is necessary but not sufficient — the dispatch must
exercise the changed code path. For new composites, this means
dispatching with parameters that route into the composite's branch.
For new branches, dispatching with conditions that fire the branch.

This is `[REFL-012]` "loop-counter verification is state verification"
applied to canary verification: dispatching a workflow and seeing
"green" is a counter-shaped verification (the workflow ran and didn't
fail). The state-shaped verification is "the new code branch executed
and produced the expected effect." The canary log inspection step
(grep for "Resolved orgs:" / "Created issue #10" / etc.) is the
state-shaped check.

## Action Items

- [ ] **[skill]** ci-cd-workflows: Add a rule capturing composite-action tech-stack constraints — (a) composites cannot be invoked inside shell for-loops; (b) `./local/path` refs require `actions/checkout` earlier in the job; (c) cross-repo `swift-institute/.github/.github/actions/<name>@main` refs avoid the checkout requirement and are the corpus's standard pattern (existing precedent: `configure-private-repos`, `install-swift-sdk`). All three constraints bit during PM #1+#2; codifying preempts re-derivation.
- [ ] **[research]** Refactor decision framework for CI primitives — 7-axis evaluation (dup×class, tech-stack fit, stability, blast/reversibility, tier-coherence, pop-maturity, cohort discipline) with priority order for override conflicts. Authored ad-hoc this session; would benefit from a Research/ doc that future audits can cite. Includes the principal's "alpha-mode override on Axis 6" precedent.
- [ ] **[skill]** reflect-session: Extend `[REFL-006]`'s re-verify-after-edit discipline to canary scoping — dispatched workflows must exercise the changed code path, not just complete green. Counter-shaped vs state-shaped verification distinction (parallel to `[REFL-012]`).
