---
date: 2026-05-10
session_objective: Process [coen:] inline annotations in BLOG-IDEA-102 draft (the-missing-fourth-corner.md) and reconcile Blog/_index.json with the shifted publish schedule
packages:
  - swift-coproduct-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [BLOG-023] Schedule-Shift Cohort Sweep (entry 3 AI 1; Tuesday to Monday cohort compression worked example with cohort-surface enumeration). NoAction swift-coproduct-primitives README staleness is package-implementation work tracked separately (cohort sweep before Monday launch).
---

# Blog Draft Annotation Processing and Schedule-Shift Cascade

## What Happened

Resumption of a context-compacted session. The prior turn had created the
Wednesday blog draft for BLOG-IDEA-102 (`the-missing-fourth-corner.md`). At the
top of this session the user updated the publish schedule: launch shifts from
Tuesday → **Monday 2026-05-11**, coproduct blog shifts from Wednesday →
**Tuesday 2026-05-12** (compressed by one day).

The user then added three `[coen:]` inline annotations to the draft:

1. After the H1, restating the Mon/Tue schedule (lede references "Tuesday's
   post" — needed flipping to "Monday's post")
2. Before the "package directory exists as a stub" paragraph: *"irrelevant to
   the reader; package stays private for now"*
3. At the top of "What we are watching for": *"irrelevant to readers. just
   mention we're watching for these features and if they materialize, we can
   provide a coproduct-primitives"*

Processed via six `Edit` calls:

- Lede: dropped the `[coen:]` marker, flipped two "Tuesday's post" / "Tuesday
  post" references to "Monday's post"
- Removed the `[coen:]` marker and the stub-package paragraph following the
  2×2 table
- Updated `Product`'s "since its 2026-05-09 launch" → "since its 2026-05-11
  launch" (Monday)
- Replaced the multi-bullet canary-list "Watching for" section with a single
  paragraph naming the two language lifts
- Closing: dropped "stub package and a research doc" phrase and the "read the
  research doc" sentence; flipped "landed on Tuesday" → "landed on Monday"
- Removed `[research]` and `[repo]` link defs (no longer referenced)

After flagging that `Blog/_index.json` BLOG-IDEA-102 notes still said
*"Target: Wed 2026-05-13, two days after the launch post"*, the user said
"update that" — mechanical fix to "Target: Tue 2026-05-12, one day after the
launch post."

**Handoff-file scan (per [REFL-009])**: 51 `HANDOFF-*.md` files at workspace
root + 1 at `swift-institute/Blog/`. All out-of-session-scope — this session
worked only on `the-missing-fourth-corner.md` and `Blog/_index.json`; none of
the listed handoffs describe related work. None touched, none deleted, none
annotated.

**Audit findings**: `/audit` not invoked this session; [REFL-010] does not
apply.

## What Worked and What Didn't

**Worked.** Direct annotation-processing was efficient. The implicit
implications of comment 2 ("package stays private") were caught: removing the
literal stub paragraph wasn't enough — the `[research]` and `[repo]` link
definitions at the bottom referenced the private repo, and Closing's "read the
[research doc]" sentence carried the same leak. Sweeping these out kept the
post coherent. The schedule-shift cascade caught the `Product` launch-date
reference (`2026-05-09` → `2026-05-11`) inside the body, not just the lede's
"Tuesday's post."

**Didn't.** No proactive sweep of cohort-sibling artifacts for the schedule
shift. The README of `swift-coproduct-primitives` says *"The first three
landed 2026-05-09"* — this remains stale and will ship Monday with the wrong
date unless updated. Pair/Either/Product READMEs and the launch post itself
(BLOG-IDEA-101) likely contain the same stale 2026-05-09 string and were not
checked. The `Blog/_index.json` drift was caught only because I flagged the
notes field at end-of-turn; the user had to explicitly request the fix
("update that"). Both gaps point at the same blind spot — the active edit
target gets attention; the upstream/sibling artifacts that share the same
source-of-truth schedule do not.

## Patterns and Root Causes

**Editorial annotations carry ripple cost.** A `[coen:]` marker is a
local-edit signal but rarely a local-edit task. *"Package stays private"*
attached to one paragraph implicates every other reference in the document
that exposes the private repo — link defs, citation prose in Closing,
incidental phrasing. The implementer must trace the marker's intent through
the rest of the document; literal-paragraph removal leaves the doc
incoherent. The same shape recurs on every editorial round: a one-line
trigger, a multi-site cleanup. The cost of missing it is text that contradicts
itself or names artifacts that no longer exist.

**Schedule-shift cascade across artifacts is wider than the active edit.**
The same date appears in many places: the draft frontmatter, the body, the
index entry's notes field, sibling-package READMEs that describe the cohort,
research docs that timestamp decisions. When the date shifts, only the active
file gets touched unless a deliberate sweep happens. The blog draft caught it
(via `[coen:]`); the index entry caught it (via my end-of-turn flag); the
cohort READMEs did not. The discipline this points at is: *any artifact whose
source-of-truth is the launch date is in cascade scope when that date moves*
— and the implementer should `grep` for the prior date string before declaring
the cascade done.

**Index-vs-draft drift is a planning-artifact symptom.** The `_index.json`
notes field is a planning artifact set at idea-capture time and stale by
default. Active drafts get attention; the index entry's notes do not, until
something forces a re-read. The pattern is structural — the same drift
appears across READMEs, blog ideas, research-doc Outcome sections, and
`_index.json` files generally. Consolidation isn't the answer (the index is
its own artifact); the answer is treating the index as a sweep target on
schedule changes.

## Action Items

- [ ] **[skill]** blog-process: Add a "schedule-shift sweep" rule. When a
      publish or launch date moves, the implementer MUST `grep` the prior
      date string across the draft, the `Blog/_index.json` entry notes,
      cohort-package READMEs, and any research/Documentation.docc references
      cross-cutting the launch — and update each. Single-file edits routinely
      miss the cascade.
- [ ] **[package]** swift-coproduct-primitives: README's *"The first three
      landed 2026-05-09"* line is stale; needs updating to `2026-05-11` before
      Monday launch. Same staleness likely affects `swift-pair-primitives`,
      `swift-either-primitives`, `swift-product-primitives` READMEs and the
      launch post draft (BLOG-IDEA-101) — sweep cohort-wide before Monday.
