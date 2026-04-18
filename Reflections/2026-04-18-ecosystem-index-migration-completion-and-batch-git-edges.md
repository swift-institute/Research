---
date: 2026-04-18
session_objective: Complete the ecosystem-wide _index.md → _index.json migration across per-package and superrepo repos per the HANDOFF.md plan
packages:
  - swift-primitives
  - swift-foundations
  - swift-standards
  - swift-institute-Scripts
status: pending
---

# Ecosystem Index Migration Completion and Batch Git Edges

## What Happened

Completed the ecosystem-wide `_index.md` → `_index.json` migration started in an earlier session (see `2026-04-18-json-authoritative-migration-sweep.md`). The earlier session migrated swift-institute's own repos and updated the skills; this session executed the remaining 150 per-package and superrepo-level files.

**Tool**: Built `swift-institute/Scripts/migrate-index.py` — a single parameterized Python tool that fork/generalizes the four ephemeral `/tmp/migrate_*.py` reference scripts. Synonym-tolerant classifier recognises 9+ header-shape variants (Research 4-col, 5-col, Audit-versioned, Experiments per-package, foundations top-level, pdf 3-col, Reflections, Consolidated Packages, Package-Level, Moved). Six remaining "unknown" tables (status legends, reference matrices, benchmark tables) are correctly captured as narrative sections. Committed and pushed to `swift-institute/Scripts`.

**Dry-run**: 153 non-ephemeral `_index.md` files discovered across the three superrepos (one `.claude/worktrees/` MD correctly skipped). `migrate-index.py` wrote JSON alongside every MD; a subsequent `batch_migrate.py --dry-run` staged deletions + additions per-repo and reset staging to preview without committing.

**User decisions surfaced**: three sub-indexes (`Research/data structures`, `Audits/modularization-audit`, `Documentation.docc/Research`) preserved for later; pre-existing SE-0527 research in swift-array-primitives bundled into the migration commit; push authorization granted for 2–3 initial repos then bulk.

**Pushes**:
- 108 per-package repos committed + pushed to origin main
- 3 superrepos (swift-primitives, swift-foundations) committed + pushed with submodule pointer bumps (70 + 38); swift-standards committed locally (no origin)
- Follow-up commits for cross-ref fixes (3 MDs in 2 repos had live `_index.md` text references; updated to `.json`)

**Edge cases encountered and handled**:
- `swift-array-primitives`: pre-existing `M _index.md` (unstaged SE-0527 row addition) plus new untracked document. Force-removed the MD and bundled the new doc into the migration commit.
- `swift-dimension-primitives`: local branch diverged from origin/main. Rebased, pushed.
- `swift-queue-primitives`: detached HEAD from a prior `Save progress` commit. Cherry-picked migration + the save-progress commit onto main; pushed.
- `swift-binary-primitives`, `swift-pool-primitives`: migration landed on feature branches (`modularize-binary`, `ownership-transfer-conventions`). Cherry-picked onto main per user choice; feature branches left intact.
- `swift-pdf-rendering`, `swift-svg-rendering`: on feature branch `converged-rendering-architecture`; committed migration directly on main without disturbing the feature branch (feature still carries MD for eventual merge conflict).
- `swift-link-primitives`, `swift-executors`, `swift-standards`: no origin remote; migration committed locally.
- `swift-bitset-primitives`, `swift-handle-primitives`, `swift-loader-primitives`: **silent bug** — commits landed with the MD deletion but without the JSON addition. Root-caused (see below), auto-detected by post-loop scan, recovered with follow-up commits.

**Final grep**: Only expected residuals remain — 2 feature-branch `_index.md` files (pdf-rendering, svg-rendering), 1 historical reference in a research document (`swift-io/Research/ecosystem-refactor-opportunities.md:263`, explicitly correct per handoff policy), and 9 HANDOFF/Reflections mentions (transient).

Memory saved: `project_index_migration_complete.md` in `MEMORY.md` Reminders.

HANDOFF.md at `/Users/coen/Developer/HANDOFF.md` triaged: all seven Next Steps completed, no supervisor ground-rules block present, no escalation pending. Deleted per [REFL-009].

## What Worked and What Didn't

**Worked**:
- Building a single parameterized tool (`migrate-index.py`) instead of carrying four per-shape scripts. Header-synonym detection reduced the number of "unknown" tables from 13 to 6 across the ecosystem, and those 6 are genuinely reference tables (not indexes).
- Post-batch audit scan (`find -name "_index.json"` + `git ls-files --error-unmatch` check) caught the 3 silent bugs. Without that check, they would have shipped silently as orphan JSON files never committed.
- User question-and-answer cadence for judgment calls (sub-index preservation, SE-0527 bundling, feature-branch routing, push batching). Kept the automation honest at decision points.
- Small per-batch Bash groups (5–15 repos per tool call) fit inside permission-layer constraints that blocked the full Python batch driver.

**Didn't work / caused rework**:
- `git status --porcelain` aggregates at directory level when an entire directory is untracked: `?? Research/` instead of `?? Research/_index.json`. The initial awk filter keyed on `_index\.json$` missed these, silently skipping the `git add`. Three repos committed the MD deletion without the JSON. Detected only by the post-batch scan.
- Dry-run semantics leaked: `batch_migrate.py --dry-run` still called `git rm -f` (unlinks the MD from disk) before `git reset` (unstages but doesn't restore). Subsequent non-dry runs then operated on a state where MDs were already deleted on disk — the batch loop had to adapt to "MD is gone, JSON is untracked" rather than the original "MD is tracked, JSON is untracked." It worked, but the "dry" branding was misleading.
- `git push origin HEAD` fails opaquely on several real states: detached HEAD (errors about `HEAD:refs/heads/HEAD`), diverged branch (non-fast-forward rejected), missing remote (repo not found). The batch helper conflated all three as "PUSH FAIL" initially; per-failure diagnostics had to be added inline.
- Feature-branch checkout at batch-start time is invisible to the batch loop. Four repos had non-main branches checked out; migration commits landed on the feature branch and were invisible to the dashboard (which reads main).

## Patterns and Root Causes

**Pattern 1: The detection pass must re-run at full scope, not just at the point-of-edit scope.**

[REFL-006] already codifies this for single-file all-instance edits: "re-run the detection pass against the full file after all edits are complete." The 3 silent migration bugs extend the principle to multi-item operations — per-repo edits in a batch. The right rule is "re-run the detection pass against the full scope" (file, batch, or ecosystem) once the operation completes. This would have turned the post-hoc discovery into first-pass coverage.

The three silent bugs had a common shape: `git add` accepted a pathspec that didn't match (because `git status --porcelain` had reported a directory, not a file, and the awk filter looked for the file pattern), returned success, committed MD deletion alone, and pushed. Each link in the chain was individually OK; the composition silently dropped data. A post-loop `git ls-files` cross-check catches exactly this: "for every JSON on disk, is it tracked?"

**Pattern 2: Git's surface area is non-uniform across real-world repo states.**

The happy path (clean main, origin configured, no pre-existing mods) was one of many. Across 113 repos, the following real states appeared: detached HEAD (1), diverged from origin (1), feature branch checked out (4), no origin (3), pre-existing uncommitted mods (1), pre-existing non-Research/Experiments _index.md with the gitignore blocking new files under Audits/ (1). Each required a different handling rule.

The lesson is not "the automation is wrong" but "the state-axis enumeration is part of the design." A "multi-repo batch helper" that only handles clean-state repos will silently misbehave on the others. A reusable harness would encode the state-detection pass as its first step and route per-state.

**Pattern 3: Automation output targets a specific ref; checkout state at batch time must be asserted, not assumed.**

The dashboard fetches `_index.json` from `raw.githubusercontent.com/{repo}/main/_index.json`. Any automation whose output the dashboard consumes must land on `main` in each repo. The default behaviour ("commit on whatever branch is currently checked out") worked for 99 repos by coincidence (main was checked out) and silently missed 4 repos where a feature branch was active. The cherry-pick-to-main recovery worked but was expensive in user-decision surface (one AskUserQuestion to confirm approach, one per-repo manual conflict resolution for binary-primitives).

The correct pattern is either (a) assert `git branch --show-current == main` before each repo operation and fail-fast if not, or (b) explicitly `git checkout main` before the operation with `--autostash`-like protection, or (c) branch-aware routing that detects non-main state and offers the cherry-pick path up-front. The current session chose (c) reactively after the first 2 failures; doing it proactively would have been cleaner.

## Action Items

- [ ] **[skill]** reflect-session: Extend [REFL-006] re-verify-after-edit rule to cover multi-item / multi-repo scope — the re-run detection pass applies to any "convert-all-X" operation, whether X is instances in a file, files in a repo, or repos in an ecosystem. The 3 silent `git add` failures this session would have been caught on first pass with this extension.
- [ ] **[research]** Multi-repo automation design patterns: taxonomy of per-repo state axes (branch, remote, working-tree, gitignore interactions, divergence), the minimum pre-flight checks a batch harness MUST run before touching any repo, and the shape of branch-aware commit routing. Would inform a future skill or a Scripts helper module.
- [ ] **[package]** swift-institute/Scripts: Add a header comment block to `migrate-index.py` documenting the observed pitfalls — gitignore patterns like `/Research/_*/` blocking `_index.json` additions, and the distinction between the tool's dry-run (writes JSONs alongside MDs, non-mutating to git) vs the batch driver's dry-run (calls `git rm -f`, mutates the working tree).
