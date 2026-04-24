---
date: 2026-04-22
session_objective: Investigate three linked ecosystem-finalization questions (swift-standards monorepo split consumer migration, coenttb/swift-html tree transfer to swift-foundations, git-history squash recipes) and produce a strategy-only branching-handoff Findings artifact
packages:
  - swift-institute/Research
  - swift-foundations
  - coenttb
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Heritage-transfers investigation and the placeholder-verification gap

## What Happened

The session ran as a three-round branching investigation driven by
`HANDOFF-heritage-transfers-and-history-strategy.md` and two
user-authored extensions. Round 1 produced the core Findings +
a new Tier-2 research doc (`git-history-transfer-patterns.md`).
Round 2 resolved six follow-ups: per-package metadata
verification, StandardsTestSupport relocation, dependency-aware
transfer sequencing, dry-run candidate nomination, `-rendering`
→ `-render` naming recommendation, and an 18-row per-package
execution checklist. Round 3 added a Wave-0 row for
`swift-testing-performance` and updated the cheat-sheet's
test-support migration entry to point at
`swift-foundations/swift-testing` post-Phase-II.5.

Strategy-only scope was honored throughout. Zero transfers,
squashes, deletions, force-pushes, or `git remote set-url` were
executed. The Tier-2 doc landed at
`swift-institute/Research/git-history-transfer-patterns.md`
(v1.0.0, RECOMMENDATION, research_tier 2) and was registered in
`_index.json` at the alphabetically-correct position between
`foundations-dependency-utilization-audit.md` and
`git-subtree-publication-pattern.md`.

Key concrete artifacts produced:

- 18→19-row per-package execution checklist with 9 columns
  (visibility, target, rename?, delete-placeholder?, drain-PRs,
  sub-bump, dry-run, notes)
- 8+1-wave sequencing (W0 for swift-testing-performance + W1–W8
  for the html tree)
- Swift-standards monorepo split consumer migration cheat sheet
  (20 old monorepo products → new primitives homes)
- Transfer-vs-fork-then-merge comparison (8 axes)
- 6 squash-recipe options with per-scenario composition

The load-bearing finding surfaced in Round 3: the user directed
me to verify whether `swift-foundations/swift-testing` was
"scaffold-only" before recommending placeholder delete.
Inspection via `gh api repos/.../commits` returned a history
containing two substantive commits
(`3f3818d3 Remove __TestingRunner XCTest bridge`,
`8b6589d2 Fix @Suite and @Test macros to build fully-qualified
suite names from lexical context`) plus populated `Audits/`,
`Experiments/`, `Research/`, `Sources/`, `Tests/` directories.
The row was written with `delete placeholder: **user-decide**`
and a full flagging paragraph, instead of the default
auto-delete recommendation that would have been the
first-instinct answer.

HANDOFF triage per [REFL-009]: 14 workspace-root `HANDOFF*.md`
files scanned; this session's authority was bounded to
`HANDOFF-heritage-transfers-and-history-strategy.md` alone. That
file was annotated in place rather than deleted because the
principal's `HANDOFF.md` now references its locked decisions and
its operational artifacts (checklist, wave table, verification
data) are the execution-phase reference for Phase II.5. The
other 13 handoffs are out-of-session-scope and were left
untouched. No `/audit` invocation this session, so [REFL-010]
was a no-op.

## What Worked and What Didn't

### Worked

- **Batch-gathering per-package metadata via one shell loop**
  produced clean tabular output (visibility, stars, tag,
  post-tag count, PRs, issues, local/origin SHAs) for 18
  packages in a single pass. Much cheaper than per-row `gh`
  calls and cleaner than deferring any row to follow-up.
- **Running [HANDOFF-013] up front** immediately surfaced
  `github-organization-migration-swift-file-system.md` (prior
  Tier-2 transfer doc) and `git-subtree-publication-pattern.md`
  (prior Tier-2 subtree-rejection doc). Citing both in the
  Tier-2 output rather than drafting parallel content avoided a
  duplicate-research defect.
- **Writing the Tier-2 doc + registering `_index.json` in the
  same investigation** closed the follow-up loop before it
  could drift. [RES-003c]'s index discipline was honored on
  first pass.
- **Round-3 placeholder verification** was load-bearing. The
  instinct was to write "placeholder — safe to delete" (matching
  Round-1's casual label on the html-tree placeholders); reading
  the actual commits turned up the two substantive macros-side
  commits that would have been silently lost to an auto-delete
  recommendation.

### Didn't

- **Round 1 left 13 rows as "(verify)" in the swift-html tree
  table.** Every row was resolvable by a 2–5 second shell call,
  but I batched the data-gathering only when Round 2 forced it.
  Same pattern for StandardsTestSupport — Round 1 said "flag
  for follow-up" instead of running the 3-second
  cross-superrepo grep that would have resolved it inline.
- **The "placeholder = scaffold" assumption was applied
  casually in Round 1.** I wrote "delete placeholder — safe"
  for all 5 html-tree rendering-family collisions without
  reading a single placeholder's commit log. Only because the
  user explicitly asked to verify the Round-3 placeholder did
  the heuristic get tested. The 5 rendering-family placeholders
  MAY also carry non-scaffold content that my early
  recommendation would have discarded.
- **The initial `refs/tags` query** returned lexically-sorted
  results (`0.9.5` sorted after `0.30.1` because "9" > "3"), and
  I silently worked around it using the separately-queried
  `/tags` endpoint. I didn't flag the footgun at the time — a
  future investigator using the same approach might not notice.

## Patterns and Root Causes

**Pattern 1 — "verify-later" in cheat sheets is usually a
misclassification of "verify-now-if-cheap".** Both
StandardsTestSupport resolution and the Wave-0 placeholder
scaffold check came back as user-driven extensions. In both
cases the underlying check was ≤30 seconds of shell:
`grep -r StandardsTestSupport swift-*/*/Package.swift` and
`gh api repos/swift-foundations/swift-testing/commits`.
Annotating "(verify)" in the output instead of running the
check creates follow-up cost the user pays — and the "flag for
follow-up" annotation looks diligent (flags the unknown) while
being operationally equivalent to "haven't looked yet". The
parallel to [HANDOFF-013a] writer-side grep is close: that rule
mandates grepping before prescribing NEW types; an analogous
rule for CHEAT SHEETS / ENUMERATIONS / CHECKLISTS would mandate
verifying existing targets before listing them. The threshold
should be cost-based: if the check is ≤30 seconds shell, defer
is a defect.

**Pattern 2 — "Placeholder" is a label applied by the
investigator, not a fact about the repo.** The Round-3 finding
(swift-foundations/swift-testing has real dev work) is the
concrete manifestation. The failure mode is that a
scaffold-looking listing
(`~10 commits titled 'chore: sync canonical X'`) biases the
investigator toward "safe to delete" without reading what's
actually in the commits or tree. The protocol-level fix: before
recommending `gh repo delete` on any ecosystem repo, run a
check list — (a) non-scaffold commit-message tokens?
(b) Sources/ population? (c) tags? Any hit → flag for user
decision. The heuristic the Round-3 scan implicitly used:
"commit messages containing 'Fix', 'Remove', or 'Add' beyond
the first N rows" catches non-scaffold work. This protocol, if
codified, would also apply to the 5 html-tree
rendering-family placeholders whose content I did NOT inspect
before recommending delete.

**Pattern 3 — Branching investigation output that's "strategy
only" is frequently re-used as execution reference.** The
heritage-transfers handoff's Findings + Extension subsections
ended up as the operational artifact for the upcoming Phase
II.5 + html-tree-transfer execution — not a one-shot input to
the parent's decision-making. The deletion-vs-retain call under
[REFL-009] gets awkward for this class: the investigation's
*task* is done, but the document is the execution phase's
*reference*. Current resolution was to annotate and leave, which
matches the spirit of [REFL-010] (audit findings get status
updates, not deletion) more than the letter of [REFL-009]'s
"delete when all items complete". The distinction worth codifying:
investigation-output handoffs with durable operational content
(cheat sheets, checklists, verification tables) belong to a
third class not yet named by the handoff skill — "reference
handoff" or similar — that should be promoted to research or
documentation, or retained with an explicit "INVESTIGATION
COMPLETE / EXECUTION REFERENCE" banner, rather than deleted.

## Action Items

- [ ] **[skill]** handoff: Add an anti-defer rule for cheat
      sheets / enumerations / checklists. Shape: "when a
      findings artifact lists targets whose existence /
      location / state is trivially verifiable (≤30s shell),
      'flag for follow-up' or '(verify)' annotations are
      defects; run the check and write the verified result on
      first pass." Provenance: this session's StandardsTestSupport
      and Wave-0 placeholder both round-tripped as user-driven
      extensions because Round 1 deferred ~30-second checks.
      Cross-reference [HANDOFF-013a] (writer-side grep for new
      types) as the nearest existing rule.

- [ ] **[research]** swift-institute/Research/placeholder-pre-delete-verification.md:
      Codify a protocol for verifying GitHub placeholder repos
      before recommending `gh repo delete`. Inputs: (a) commit
      log scanned for non-scaffold tokens (`Fix`, `Remove`,
      `Add`, macro/API-shape verbs); (b) non-empty Sources/
      tree; (c) any tags; (d) issues/PRs. Output: safe-to-
      delete vs flag-for-user-decision. 2026-04-22
      swift-foundations/swift-testing is the provenance case —
      two substantive commits (macro fixes + XCTest bridge
      removal) in a repo the investigator had casually labeled
      "placeholder". Applies to the ~9 placeholder deletes
      currently sitting in the html-tree transfer checklist,
      none of whose contents have been verified.

- [ ] **[skill]** handoff: Extend [REFL-009] / handoff-disposition
      rules to name a "reference handoff" disposition —
      investigation-output handoffs whose Findings contain
      durable operational content (cheat sheets, execution
      checklists, verification tables) that is live-needed by
      an upcoming execution phase. Current rule flips between
      "delete" (items complete) and "leave annotated" (items
      remain) but doesn't address the common case where the
      investigation is done AND the output is the execution
      reference. Proposed shape: annotate the file with
      `INVESTIGATION CONCLUDED — EXECUTION REFERENCE` at the
      top; leave in place; revisit at end of the referenced
      execution phase. Alternative: promote operational content
      to a Research doc and then delete the handoff.
