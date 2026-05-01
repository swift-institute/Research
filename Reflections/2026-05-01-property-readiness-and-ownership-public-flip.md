---
date: 2026-05-01
session_objective: Run /release-readiness for swift-property-primitives, run /swift-forums-review against current state, then pivot to flip swift-ownership-primitives public via the squash-and-flip flow
packages:
  - swift-property-primitives
  - swift-ownership-primitives
status: pending
---

# Property readiness and ownership public flip

## What Happened

Long, two-package session.

**Property arc**: Authored four-phase release-readiness brief +
seven-phase final pre-release scan (`AUDIT-0.1.0-*.md`, gitignored)
+ appended `## 0.1.0 Final Pre-Release Scan — 2026-05-01` section
to `Audits/audit.md`. Verified Tier 1 backlog 12/12 LANDED.
Authored full forums-review re-simulation (12 archetypes, 11
reviewer voices) + objections + triage at
`Audits/forums-review/forums-review-{simulation,objections,triage}-2026-05-01.md`.
Critically re-assessed surviving findings after user pushback on
three-package-split and `swift-storage-primitives` namespace
collision; downgraded 6 of 11 critiques as anchor-correct /
conclusion-wrong per [FREVIEW-018]. Applied 4 surviving findings
+ described description trim. Committed `f63dd57` (still unpushed).

**Ownership arc**: Pivoted to existing brief + uncommitted scan
in `Audits/audit.md`; pushed prior `8046cca` + dep URL conversion
`2cda921` + forums-review-derived `6b6397b` + revalidation to
prepare. User authorized "ALL commits squashed to one"; squashed
78 commits → single parentless `Initial publication` commit
(`28f32ba`) via `git commit-tree HEAD^{tree}` + `git reset --hard`.
Force-pushed. Flipped to PUBLIC via `gh repo edit --visibility`.

**Post-flip CI churn**: First public CI run reported failure. I
reacted by patching `Optional+take.swift` for a Linux 6.4-dev
nightly RegionIsolation diagnostic. Patched again for the
SwiftLint config gap (184 trailing_comma violations because
`.swiftlint.yml` was never tracked — cohort siblings have it
with `parent_config` from swift-standards). Patched again for
`orphaned_doc_comment`. User asked "should we ignore the
RegionIsolation, considering it's on the nightly?" Investigation
revealed (a) the centralized `swift-ci.yml` sets
`continue-on-error: true` on the nightly job, (b) my Optional+take
"fix" didn't even fix the diagnostic on the moving nightly
target. Reverted the Optional+take change with a doc Note
documenting the nightly diagnostic as known + gated.

**Re-squash + cleanup**: Re-squashed all post-flip churn into a
single `0d5b399 Initial publication` commit. Force-pushed. CI
green on every blocking gate (macOS / Ubuntu 6.3 / Windows / DocC);
nightly red but `continue-on-error`-gated. Deleted 39 stale
workflow runs via `xargs -I {} -n 1 gh run delete`, keeping only
the 3 on the launch commit.

**Forums-review caught a real bug**: Post 9 cluster-7's question
about abandoned-Outgoing paths surfaced a missing
`deinit { Unmanaged.fromOpaque(raw).release() }` on
`Ownership.Transfer.Retained.Outgoing`. Source-verification per
[FREVIEW-018] confirmed: dropping an `Outgoing` without `consume()`
leaked the +1 retained pointer. Fix added the deinit + `discard
self` in `consume()` (otherwise the consumed path also fires the
deinit and double-releases) + regression test using a weak-ref
probe. Test count: 113 → 114.

**Authored property HANDOFF.md** for next-session continuation
of the same flow on property (squash → force-push → flip → CI
watch → Actions cleanup), including supervisor ground-rules block
per [HANDOFF-012].

**Final state**: ownership-primitives PUBLIC at single parentless
`0d5b399 Initial publication` commit; Actions tab shows 3 green
runs only; description trimmed. Property unchanged in remote;
HANDOFF.md staged for next session.

**HANDOFF scan**: 2 files found across the two working dirs;
1 deleted, 1 left in-flight, 0 out-of-scope.

## What Worked and What Didn't

**Worked**:

- The orphan-branch squash via `git commit-tree HEAD^{tree}` is
  clean, mechanical, and reproducible. Same incantation works for
  property next session.
- `xargs -I {} -n 1 gh run delete` for bulk Actions cleanup —
  the `for id in $LIST` shell-quoting pitfall consistently failed,
  even with explicit `"$id"` quoting; xargs split correctly.
- Forums-review skill produced a real bug catch
  (Transfer.Retained.Outgoing leak) on its first invocation
  against ownership-primitives. The Post-9 cluster-7
  init/deinit/lifecycle archetype's question wasn't a
  load-bearing prescription on its face, but the
  source-verification step per [FREVIEW-018] traced it to a
  genuine defect.
- User's framing "should we ignore it, considering it's on the
  nightly?" was the load-bearing intervention. It caught the
  authorization-gate confusion in one question.

**Didn't work**:

- I reacted to a CI run that was reported as `failed` without
  checking the run-level `conclusion` — which was actually
  `cancelled`, with the only true failure on a `continue-on-error: true`
  job. Patched source for two iterations before the user surfaced
  the gating. The diagnostic was real (Swift 6.4-dev nightly's
  RegionIsolation analyzer), but it didn't block, and my fix
  didn't even resolve it.
- Critical re-assessment after user pushback was the second-pass
  filter that downgraded 6 of 11 forums-review critiques. The
  first-pass [FREVIEW-018] anchor verification catches surface
  correctness; it does NOT catch "anchor correct, prescription
  conflicts with the type's purpose" or "anchor correct,
  prescription conflicts with existing ecosystem namespaces."
  Without the user's pushback, I might have applied destructive
  fixes (rename Copyable Borrow init, add Sendable conditional that
  defeats Mutable.Unchecked's purpose, propose three-package split
  over an existing storage-primitives namespace).
- The description-trim divergence between
  `gh repo edit --description` (immediate) and the centralized
  metadata-sync workflow (re-pushes origin's `metadata.yaml` on
  cron) caused a desync I noticed when authoring property's
  HANDOFF.md. Manual gh-edit doesn't survive when the unpushed
  commit hasn't propagated.

## Patterns and Root Causes

**Authorization-gate visibility lives at run-level, not job-level**.
A workflow run with N jobs and 1 `continue-on-error: true` job is
indistinguishable, at the GitHub PR-status level, from a workflow
run with N jobs and zero such gating — both can report job-level
failures. The run-level `conclusion` field is the only place the
distinction lives. Reactive source-patching on a job-level failure
can patch the wrong target; if the patched job is gated, the
patch was unnecessary churn. The discipline is: before patching
source for a CI failure, query `gh run view <id> --json conclusion`
and check the run-level outcome; if `success`, the failure is gated
and the source patch is optional at best. This generalizes
[FREVIEW-018]'s anchor-correctness-vs-conclusion-correctness pattern
to CI gates: the surface signal (job failed) can be true while the
conclusion drawn from it (run failed, must fix) is false.

**Forums-review's value is twofold and asymmetric**: (a) it
surfaces probes that prompt source-verification; (b) the
prescriptions it generates are mostly archetype-shaped noise that
needs filtering. The two values use different parts of the skill —
(a) is the simulation phase + the post-triage anchor verification;
(b) requires a critical re-assessment pass after triage, ideally
with user pushback or against existing-ecosystem fact-checks. The
2026-05-01 ownership pass produced one real bug fix (Transfer
abandoned-Outgoing leak) and zero applied destructive fixes; both
outcomes were good. The destructive-fix counterfactual (had the
session applied all surviving critiques) would have been: rename
half the Borrow API, add a Sendable conditional that defeats
Unchecked's intent, propose a three-package split. Each was
surface-correct and conclusion-wrong.

**Description-trim survives commit, not gh-edit**. The metadata-sync
workflow treats origin's `.github/metadata.yaml` as canonical; manual
`gh repo edit --description` is overwritten on the next sync run.
Property's description shows the OLD long form right now because
`f63dd57` (which contains the trimmed metadata.yaml) is unpushed.
The mental model "gh edit takes effect immediately" is only true
locally on GitHub; the metadata-sync workflow eventually re-asserts
the file-on-origin's version. Codifying this would save a
"why doesn't my edit stick?" diagnostic round-trip in any future
session that touches metadata before the commit lands.

## Action Items

- [ ] **[skill]** release-readiness: Add a post-flip "first-public-CI
  baseline" verification step covering (a) cohort-canonical lint
  configs (`.swiftlint.yml`, `.swift-format`) match sibling
  packages — strict-default lint without parent_config produces
  hundreds of violations that the disabled-manually workflow
  hides, surfacing only after public flip + workflow re-enable;
  (b) the centralized workflow's continue-on-error matrix is
  understood — run-level `conclusion` is the gate, not
  job-level status; reactive source-patching on gated job
  failures is unnecessary churn. The 2026-05-01 ownership flip
  exhibited both gaps.
- [ ] **[skill]** swift-forums-review: Add a post-triage critical
  re-assessment step. After [FREVIEW-018] anchor verification,
  ask of each load-bearing critique: "does the prescribed fix
  translate cleanly?" Specific shapes to catch — (i) prescription
  conflicts with the type's stated purpose (e.g., adding
  `Sendable where Value: Sendable` to a type whose existence is to
  be Sendable when Value is not); (ii) prescription conflicts with
  existing-ecosystem namespaces (e.g., proposed package split into
  `swift-storage-primitives` when that name is already taken);
  (iii) prescription creates new API consistency problems (e.g.,
  rename split that breaks generic-over-Copyable-status code). The
  2026-05-01 ownership pass downgraded 6 of 11 critiques on this
  second pass.
- [ ] **[package]** swift-ownership-primitives: Forums-review
  caught a real bug — Transfer.Retained.Outgoing missing
  abandoned-path deinit. Fix shipped in `0d5b399` along with a
  regression test. Lesson recorded: `~Copyable struct` holding an
  unbalanced ARC retain MUST carry an explicit deinit + use
  `discard self` in any `consuming func` that balances the retain
  itself, otherwise the consumed path double-releases. Verify same
  pattern doesn't exist elsewhere in ownership's `~Copyable`
  surface (siblings already verified: Transfer.Value uses Latch's
  deinit; Transfer.Erased uses explicit destroy; only Retained
  had the gap).
