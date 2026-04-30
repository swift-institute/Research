---
date: 2026-04-30
session_objective: Execute handoff-lifecycle-and-retention RECOMMENDATION — three skill amendments diagnosing why [REFL-009] does not prevent HANDOFF-*.md accumulation, plus retroactive triage of the 26-file workspace-root backlog.
packages:
  - swift-institute
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: research-process
    description: "[RES-023] extended with plan-time-prediction table row + procedure step 5 (Q4/Execution Plan/Next Steps sections subject to empirical verification); cross-references [HANDOFF-021]/[HANDOFF-029]. Provenance: action item #1."
  - type: skill_update
    target: reflect-session
    description: "[REFL-008] extended with Execution-session-analysis-output row in artifact-type table; threshold ~50 lines / 10 dispositions for reflection-vs-separate-artifact decision. Provenance: action item #2."
  - type: research_update
    target: recurring-handoff-triage-skill-candidate
    description: Outcome section appended with 2026-04-30 update noting prevention-side complement landed; codification priority lowered. Provenance: action item #3.
---

# HANDOFF Lifecycle and Retention — Execution

## What Happened

The session began as a branching investigation dispatched by today's parent
session via `HANDOFF-handoff-lifecycle-research.md`. The brief asked a meta
question: 25 `HANDOFF-*.md` files had accumulated at `/Users/coen/Developer/`
despite `[REFL-009] Handoff Cleanup` existing — and despite a bulk-triage
cycle the day before reducing the count from 35 to 20. Why does the rule
fail to prevent re-accumulation?

The investigation produced
`swift-institute/Research/handoff-lifecycle-and-retention.md` (v1.0.0
RECOMMENDATION, Tier 2): five-hypothesis Q1 diagnosis grounded in 8
recent reflection entries (Apr 25 / 26 / 28 / 29 / 30); six-option Q2
design space; Q3 recommendation = composition of B (cadence rule analog
`[META-022]`) + F (dispatch-side predecessor retirement) + amendment to
`[REFL-009]` adding stale-override exception; Q4 execution plan in four
phases. The principal authorized execution in the same chat with
"use your common sense, be an expert."

Phase 1 landed the three skill amendments:

- `[HANDOFF-038] HANDOFF Staleness Threshold` — 14-day threshold for any
  `HANDOFF-*.md` at any working-dir root, mirroring `[META-001]`/`[META-022]`
  triage cadence; outcomes (delete / annotate-still-active / annotate-multi-cycle).
- `[HANDOFF-039] Predecessor Retirement at Dispatch` — dispatcher MUST
  identify and either delete or annotate-superseded each predecessor;
  `## Predecessors Retired` enumeration in the new HANDOFF body; mirrors
  `[HANDOFF-013a]`/`[HANDOFF-021]`/`[HANDOFF-032]` writer-side discipline
  pattern.
- `[REFL-009]` stale-override exception paragraph — when a file meets
  `[HANDOFF-038]`'s threshold AND closure signals are determinable from
  current session context, the current session MAY triage it even if not
  in original cleanup authority; conservative path explicit; existing
  bounded-authority preserved as default for fresh handoffs.

Both skill source files (`swift-institute/Skills/handoff/SKILL.md` and
`swift-institute/Skills/reflect-session/SKILL.md`) were edited in place per
`[SKILL-LIFE-001]` Minimal Revision Principle. `last_updated` bumped on
the handoff skill (`2026-04-24` → `2026-04-30`); `last_reviewed` was
already `2026-04-30` on both. `Scripts/sync-skills.sh` ran cleanly (49
skills synced); the new rules are visible via the `.claude/skills/`
symlinks. Phase 2 cross-skill consistency check found 4 skills referencing
`[REFL-009]` (handoff, reflect-session, skill-lifecycle, supervise); none
contradict the new stale-override clause.

Phase 3 produced an unanticipated empirical finding that altered the
plan. The execution handoff's Q4 had estimated "10-15 stale files" today
based on the assumption that the Apr-29 cycle's preservation set carried
the original authoring mtimes. Re-running `stat` against the live workspace
showed: zero files meet the 14-day threshold. The Apr-29 cycle's annotation
pass on the F-files updated their mtimes to 2026-04-29, and the G-files
have been continuously active. The oldest file at workspace root today is
2026-04-23 (`HANDOFF-tagged-primitives-rename.md`, 7 days old). The 14-day
cutoff (2026-04-16) catches nothing.

The expert decision was to apply `[REFL-009]` strictly without stretching
`[HANDOFF-039]` retroactively to a non-dispatch context. Retroactive
[HANDOFF-039] application would have required reconstructing the Path X
dispatch context (which is in the past and currently in flight) and
authorizing deletions on behalf of a dispatcher who is not present.
That stretch is exactly the kind of authority drift bounded-cleanup-authority
was designed to prevent. The rules will fire naturally:

- 5 of the Apr-29 F+G files become eligible for `[HANDOFF-038]` review on
  2026-05-13 (mtime 2026-04-29 + 14d).
- The 4 SGR-unverified-but-superseded F-files become deletable when Path X
  completes (their closure signal is Path X completion).
- Future Path X dispatches that supersede prior handoffs will be caught by
  `[HANDOFF-039]` at dispatch time.

Phase 3 staged two deletions, both authored-and-completed in this session,
qualifying for `[REFL-009]` clause (a):
- `HANDOFF-handoff-lifecycle-research.md` — research deliverable landed
  at the cited destination.
- `HANDOFF-handoff-lifecycle-execution.md` — execution deliverable landed
  in the skill commits and this reflection.

Phase 4 (this reflection) captures the analysis and authorizes the two
self-deletions per [REFL-008] cleanup scope.

The 24 other handoffs at workspace root are out of this session's authority.
The Apr-29 triage table (`HANDOFF-handoff-files-triage-and-cleanup-table.md`)
remains the durable record of their dispositions.

**HANDOFF scan per [REFL-009]**: 26 `HANDOFF-*.md` files at
`/Users/coen/Developer/` working-directory root.

| Disposition | Count | Files |
|-------------|------:|-------|
| DELETE (clause a — wrote it; work complete) | 2 | `HANDOFF-handoff-lifecycle-research.md`, `HANDOFF-handoff-lifecycle-execution.md` |
| LEAVE — out-of-session-authority (Apr-29 carry-over preserved by prior triage) | 17 | The 6 F + 11 G files from the Apr-29 triage table |
| LEAVE — Apr-29 triage table (durable record) | 1 | `HANDOFF-handoff-files-triage-and-cleanup-table.md` |
| LEAVE — out-of-session-authority (other Apr-30 fresh dispatches) | 5 | `HANDOFF-corpus-phase-1b-experiment-staleness.md`, `HANDOFF-corpus-phase-7a-toolchain-revalidation.md`, `HANDOFF-ownership-primitives-launch.md`, `HANDOFF-phase-1c-no-main-experiments.md`, `HANDOFF-tier-2-skill-corpus-cleanup.md` |
| LEAVE — Do-Not-Touch (parallel work) | 1 | `HANDOFF.md` |

Total: 2 deleted, 24 left.

## What Worked and What Didn't

### Worked

- **Five-hypothesis Q1 framework against empirical reflection data.** The
  brief enumerated 5 hypotheses; grepping recent /reflect-session HANDOFF
  scans across 8 reflections (Apr 25 / 26 / 28 / 29 / 30) cleanly partitioned
  the cause: HYP1 (not firing) was wrong — /reflect-session IS firing in
  every recent reflection; HYP2 (bounded-cleanup-authority orphan zone)
  was confirmed dominant from the quantitative pattern (28 scanned / 0
  deleted on 2026-04-28; 33 scanned / 0 deleted on 2026-04-29). The Q1
  evidence had the right shape: data per-reflection compiled into an
  in-authority-vs-out-of-authority table that made the pattern unambiguous.
- **Composition design (B + F) fit the failure-mode partition.** Q2
  enumerated 6 options; the comparison table mapped each option to the
  hypotheses it addressed; the recommendation came out cleanly because no
  single option covered all four real failure modes (HYP2/HYP3/HYP4) but
  composition B+F covered them with low friction and high reversibility.
  Option A (Stop hook) and Option D (relocate) were transparently rejected
  with rationale.
- **Strict-vs-pragmatic Phase 3 honesty.** Discovering at execution time
  that no files met the 14-day threshold was a calculation error in the
  research doc, not a rule failure. Reporting transparently rather than
  fabricating a stale-list, then choosing the strict-application path
  (no retroactive [HANDOFF-039]), preserved authority discipline at the
  cost of one round-trip with the principal. The principal's response
  ("use your common sense, be an expert") authorized the discretion.
- **Skill-lifecycle pre-edit checkpoint loaded.** Per `[REFL-003]`'s
  pre-edit checkpoint requirement, `skill-lifecycle` was loaded before
  the SKILL.md edits. The checkpoint surfaced `[SKILL-LIFE-001]`
  Minimal Revision (small targeted edits, not rewrites), `[SKILL-LIFE-002]`
  Update Provenance (cite the research doc), `[SKILL-LIFE-003]` Backward
  Compat Classification (Additive — adding new rules + adding an
  exception clause to existing rule, no behavior change for prior cases).
  The checkpoint had material effect on the edit shape.

### Didn't work

- **Q4 estimation error in the research doc.** The execution handoff
  said "Estimated stale files: ~10-15 of the 20 carry-over files from
  Apr-29." That estimate was based on the assumption that mtime = original
  authoring date, which was wrong: the Apr-29 annotation pass (preserving
  F files with `## Triage Status — 2026-04-29` sections) updated those
  mtimes. A pre-Q4 `stat` run against the live workspace would have
  surfaced this. Reflection action item below.
- **Phase 3 plan presumed retroactive deletion authority I didn't write
  into the rules.** The execution handoff's Phase 3 prescribed authoring
  a retroactive triage table and applying the new rules to "the current
  26-file backlog." But [HANDOFF-038] specifies a temporal threshold
  that doesn't fire today; [HANDOFF-039] specifies dispatch-time authority
  that doesn't apply to past dispatches. The plan implicitly assumed
  authority the rules don't grant. The execution didn't drift into
  unauthorized deletions, but the plan-as-written would have. Reflection
  action item below.
- **Triage table as artifact added orphan-zone bloat.** The execution
  plan called for authoring `HANDOFF-handoff-files-retroactive-triage-2026-04-30.md`
  at workspace root. On reflection, that file would have replicated the
  Apr-29 table without new actionable content (no stale files; no
  retroactive [HANDOFF-039]) and would have added to the very orphan zone
  the work is dissolving. Skipping the artifact and capturing analysis in
  this reflection is structurally cleaner. Action item below.

## Patterns and Root Causes

### Pattern — Plan-vs-data divergence at retroactive boundaries

The Q4 execution plan in the research doc described retroactive application
of the new rules to a 26-file backlog. The plan was confident: rules apply,
files get classified, deletions stage. At execution time the data diverged:
no files meet the temporal threshold, the retroactive application of
[HANDOFF-039] requires dispatch context that doesn't exist for past
dispatches, and the Apr-29 cycle's annotation pass already absorbed the
preservation work the new rules would have done.

This is a recurring pattern in skill-rule rollout: the rule's mental model
during authorship presumes a point-in-time snapshot of the corpus that was
true when the diagnosis was performed but is no longer true when the rule
ships. The Apr-29 cycle's annotation pass changed the mtime distribution;
my analysis still imagined the original-authoring mtime distribution.

The corrective discipline: at Q4 plan-time, run the same enumeration
command the rule's procedure prescribes and validate the plan against the
LIVE data, not the diagnosis-time data. Per `[HANDOFF-021]` Scope Enumeration
at Write-Time: include the command in the handoff and run it. The execution
handoff's Phase 3 should have included `find . -maxdepth 1 -name "HANDOFF*.md"
-mtime +14 -ls` as the enumeration command and run it once before
prescribing 10-15 stale files. The Empirical-Reproduction discipline
([RES-024]) for git-recipes generalizes here: the same "run-the-recipe-in-a-scratch"
pattern applies to scope-estimation in Q4 plans.

### Pattern — Retroactive-stretch as authority drift

When a session designs new rules to fix a specific problem, the immediate
temptation is to apply those rules retroactively to the current state of
the problem. This stretches the rules beyond their as-written scope and
produces a hidden authority claim: "I have authority because I wrote the
rules that grant the authority." That recursion is exactly the kind of
authority drift bounded-cleanup-authority was designed to prevent.

Retroactive application is appropriate when the rule's text explicitly
authorizes it (e.g., a one-time migration clause). When the rule is
forward-looking (cadence threshold; dispatch-time enumeration), retroactive
application requires either (a) the rule's text to authorize, or (b) the
principal to grant an explicit one-time exception. Neither applied today.

The expert call was to apply the rules strictly and document the natural
firing schedule (orphan zone reverses over 2-4 weeks as files age past
2026-05-13 + Path X completes its cycles). The strict application is
slower than retroactive bulk-triage but preserves the rule's authority
shape.

### Pattern — Reflection as-the-record vs separate-artifact

The original Q4 plan called for an artifact (`HANDOFF-*-retroactive-triage-2026-04-30.md`)
distinct from the reflection. On reflection (literally), the analysis
belongs in the reflection: the durable record is the research doc + skill
commits + reflection together; a separate triage artifact at workspace root
would have added bloat without distinct content. The Apr-29 table preserved
itself because it carried 32 file rows and per-file rationale that the
reflection couldn't compactly contain; today's analysis is small enough
that the reflection's prose IS the record.

This generalizes: when an execution session's analysis is small (≤1
disposition matrix that fits in a reflection's "What Happened" section),
prefer the reflection over a separate workspace-root artifact. When the
analysis is large (>10 distinct dispositions with per-file rationale, like
the Apr-29 cycle's 32 files × 5 rubric questions), the separate artifact
is justified. The threshold maps to `[HANDOFF-007]` token-budget logic:
if the analysis fits in a reflection's section, it doesn't need its own
file.

## Action Items

1. **[skill]** handoff: add a writer-side Q4-validation rule to the
   handoff skill cluster — when a handoff's Next Steps / Q4 plan
   prescribes triage of a file set defined by a temporal or content
   predicate (e.g., "all files older than N days," "all packages with
   pattern X"), the writer MUST run the enumeration command at plan-time
   and validate the predicted-set against the live state. Generalizes
   `[HANDOFF-021]` Scope Enumeration to predictive-scope cases and
   `[RES-024]` Empirical-Reproduction to plan-validation. Provenance:
   this reflection's Q4 estimation error.

2. **[skill]** reflect-session: when /reflect-session's `[REFL-008]`
   cleanup scope is broader than the immediate session's handoff (e.g.,
   the session shipped rules that would change cleanup outcomes for
   files outside its authority), the reflection MUST capture the
   per-file natural-firing schedule rather than authoring a separate
   workspace-root triage artifact. Restated: when the rules are
   forward-looking and the existing data does not yet meet the rule's
   trigger, the cleanup scope is "document, don't delete." Provenance:
   this reflection's "reflection as-the-record" pattern.

3. **[research]** Update `swift-institute/Research/recurring-handoff-triage-skill-candidate.md`
   Outcome section: this session is the second-cycle evidence the doc
   was waiting for. The prevention rules (`[HANDOFF-038]`, `[HANDOFF-039]`,
   `[REFL-009]` amendment) reduce the cadence at which the bulk-triage
   framework needs to fire from "every ~2 weeks" to "ecosystem-wide
   audit pass at semi-annual cadence or major milestone." Codification
   of the bulk-triage framework as a standalone skill (the doc's Option C)
   is now lower priority. The doc remains IN_PROGRESS pending observation
   of how often the bulk-triage framework fires post-prevention-rules; if
   it fires zero times in the next 6 months, the doc concludes the framework
   doesn't need codification (the prevention rules dissolved its primary
   use case).
