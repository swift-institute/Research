---
date: 2026-07-05
session_objective: Use the Fable window to put the meta-ecosystem in its best possible starting state — prune, promote, restructure, and dissolve untracked state into tracked artifacts (the Origin State arc)
packages: []
status: pending
---

# Origin State — memory dissolution, canon consolidation, and the day the guards started biting

## What Happened

A single Fable session ran the full meta-ecosystem consolidation ahead of the bottom-up
compliance program. Memory corpus: 146 files verified per-entry against repo reality; ~90
stale/superseded tombstoned; ~50 rules promoted into skills across three waves (including one
BREAKING amendment — [ISSUE-008]/[ISSUE-021] now forbid `@_optimize(none)` per the principal's
2026-06-26 directive); then, on the principal's ruling that trackedness beats thin-residue, the
remaining 56 entries were migrated to tracked homes (CLAUDE.md status/preferences/gotchas,
Workspace/BACKLOG.md, verified Research coverage) and the corpus went to ZERO with the guard
converted to target-zero + inbox-staleness mode. Handoff corpus: 290 files classified, ~125
retired across evidence-gated passes; the store moved into the new tracked private
`swift-institute/Workspace` repo (with CLAUDE.md; symlinks preserve all paths). Five monolith
skills (platform, supervise, handoff, modularization, ci-cd-workflows) split into hub+companion
form with byte-level content-preservation verification. Coordination with the parallel ADT-tower
arc: F3(c) ruled under delegation, the front-door brief folded into the tower seat, W1.6 go
relayed with riders. One CI Phase-3 relay absorbed (four verified corrections + a rider commit).

HANDOFF scan ([REFL-009] step 5): root scan — 0 loose handoffs. The 106-file store was triaged
exhaustively earlier this session (first pass: 40 retired on self-declared closure; second pass:
35 retired on cross-document evidence; per-file enumeration lives in the session's retirement
reports and handoffs/HANDOFF-meta-ecosystem-followups.md). In-flight tower files
(PROMPT-adt-tower-*, BRIEF-adt-tower-*) no-touch per [REFL-009a]. check-handoffs.sh was found
green-by-blindness after the store move (symlink not traversed) — fixed this session; it now
fires WIP-cap 106>40, and the enforce-or-amend question is chartered to the corpus-review seat.

## What Worked and What Didn't

Worked: charter-driven autonomy (guard → classify → adjudicate → promote-then-delete →
verify-to-zero) with seat sampling and full review reserved for breaking changes; parallel
drafters with exclusive file ownership + one serialized committer (zero commit races across ~40
commits in 6 repos); evidence gates that caught two false recon claims and one wrong seat brief
(the ".build wipes" mischaracterization — the drafting agent correctly challenged its own
instructions against the primary source). The mechanical gates caught the session's own
violations: the skill-size ratchet flagged 6 files the session itself had bloated, forcing the
§D1 eviction discipline into the authoring templates.

Didn't: one irreversible loss — the tail of an untracked, gitignored readiness handoff was rm'd
minutes before the principal's "public ≠ launched" correction arrived; restoration recovered
only 60 lines from transcript. The retirement spec assumed `git rm` recoverability that
untracked files don't have. Also: the first promotion wave wrote verbose provenance-rich rules
(caught post-hoc, 436 lines evicted); lean-§D1 should have been in the drafting template from
wave one. Confidence was lowest, correctly, around closure evidence — "the file says done" and
"the repo is public" both proved unreliable proxies.

## Patterns and Root Causes

**Self-declared state drifts from reality; only primary sources adjudicate.** The day's defects
were overwhelmingly one class: a document's claims about the world (memory hooks, handoff
status lines, spike evidence, "fixed on branch" assertions, changelog claims about rules never
written, a guard's green output) had decayed while the world moved. Every fix was the same
move: re-derive from the primary source ([REFL-011] generalizes this; today added the
guard-blindness instance — a tool's green is also a state claim bounded by its reach, and the
check-handoffs symlink regression is the purest specimen: structural change silently narrowed a
guard's reach to zero).

**Structural moves shed stale references at a predictable rate.** Splitting skills, moving
stores, and retiring corpora each left path-shaped references pointing at the old world
(grep-this-file instructions ×2, a memory-grep step, a guard's find-path, [REFL-016]'s citation
of the now-reversed stash pattern). The class is mechanically detectable: after any
restructure, sweep for path-based references to the moved/split/retired artifact. This belongs
in corpus-meta-analysis as a standing drift detector, not in session vigilance.

**Recovery mechanisms must precede retirement mechanics.** The one data loss happened exactly
where no safety net existed (untracked + gitignored + rm). The session's later inventions —
trash-moves for untracked files, the tracked Workspace store, git history as recovery — are the
generalization: never retire anything whose recovery story you haven't verified first.

## Action Items

- [ ] **[skill]** reflect-session: align [REFL-016] with the reversed [HANDOFF-049] — it still
  prescribes stash-edit-commit-pop and cites the retired `feedback_triage_dirty_worktree`
  memory; the canonical disposition is now commit-first (or leave-in-tree + surface).
- [ ] **[skill]** corpus-meta-analysis: add a post-restructure stale-reference detector — after
  any file move/split/retirement, grep the corpus for path-based references to the old shape
  (four instances today: two skill grep-instructions, one memory-grep step, one guard find-path).
- [ ] **[blog]** "Dissolving AI session memory into tracked artifacts": the target-zero design,
  why prose-only guardrails decay (the corpus re-grew 137→146 after a completed triage), and
  the guard-with-teeth pattern that replaced it.
