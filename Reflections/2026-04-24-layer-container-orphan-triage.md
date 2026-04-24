---
date: 2026-04-24
session_objective: Triage 49 experiment orphans + other artifact-container orphans left at three dismantled superrepo layer-containers; codify the "no layer-level artifact containers" rule in skills before executing relocations
packages:
  - swift-institute
  - swift-primitives
  - swift-standards
  - swift-foundations
status: pending
---

# Layer-Container Orphan Triage

## What Happened

The 2026-04-23 superrepo dismantle (`rm -rf .git` on `swift-primitives/`, `swift-standards/`, `swift-foundations/`) left orphan content at each layer-container root: files and directories previously tracked by the container's own `.git/` now had no version-control home. 49 experiment dirs enumerated in the originating handoff plus ~80 research docs, ~16 audit artifacts, 3 DocC catalogs, 3 CLAUDE.md files, 7 HANDOFF-*.md files.

Executed per the four-stage plan in `HANDOFF-layer-container-orphan-triage.md`:

**Stage 0** — Prior-research grep of `swift-institute/Research/` for orphan-triage / layer-container / post-dismantle keywords. Only tangential hits (`coenttb-ecosystem-heritage-transfer-plan.md`, `file-handle-writeall-l2-l3-layering.md`); no prior orphan-triage doc.

**Stage 1** — Full inventory + per-file classification. Corrected orphan counts (handoff said 32+3+14=49; actual was 31+2+13=46 after parent's own Next Step 9 moved `property-view-lifetime-escape-reproduction`). Per-experiment classification using [EXP-002c] highest-layer-dep rule: 35 → `swift-institute/Experiments/` (standalone + cross-cutting + SUPERSEDED breadcrumbs), 9 → per-package (8 primitives + 1 foundations), 1 → Research (collection-ordering-analysis was analysis doc, not experiment). Critical verification: handoff's Constraint 3 on path-dep rewrites was **empirically incorrect**. The claim "`../../swift-X` still resolves" at the new destination was wrong; `python3 os.path.normpath` showed it resolves to a non-existent subdir. Correct rewrite is `../../../swift-X-primitives` (3 levels, per precedent at `swift-ownership-primitives/Experiments/*` using commit `992eb03`).

**Stage 2** — Codified "no layer-level artifact containers" rule in three skills + memory:
- `experiment-process`: [EXP-002] explicit forbiddance + [EXP-002a] decision rule rewrite + [EXP-002c] worked example table + [EXP-003e] valid-index-locations table
- `research-process`: [RES-002] explicit forbiddance + post-dismantle anti-pattern + [RES-002a] decision rule + [RES-003c] valid-index-locations + extended forbidden-subdirectory to cover non-underscore topical subdirs (e.g., `data structures/`)
- `audit`: [AUDIT-002] rewrote scope table (no more "superrepo-wide" row since superrepos no longer exist)
- Memory: updated `feedback_experiment_placement_by_dep_layer` to make forbiddance explicit + created new `feedback_no_layer_level_artifact_containers` covering the rule uniformly across all four artifact domains + MEMORY.md index updated

**Stage 3** — Executed 46 experiment relocations + 88 research docs + 16 audit artifacts + 7 handoff triage decisions + 5 deletions (3 CLAUDE.md + 2 empty audit.md). Committed across 10 git repos via 11 commits. Two `swift package resolve` samples verified the path-dep rewrites. Documentation.docc migration deferred as a separate substantial scope; `_index.json` rebuilds at swift-institute/Research/ + swift-institute/Audits/ deferred due to prior-session WIP on those files.

## What Worked and What Didn't

**Worked**: The four-stage gated sequence (Stage 2 MUST precede Stage 3) avoided the anti-pattern where execution precedes codification. With the skills updated first, the execution had a clear convention to cite in each commit. The Python script for bulk index manipulation scaled across 10 destination indexes. The handoff's Constraint 3 being verified before execution caught the path-dep math error before it caused 8 broken moves. The SUPERSEDED-breadcrumb preservation ([EXP-018] in-place archival) was correct — the system blocked my initial attempt to `rm -rf` the 9 SUPERSEDED dirs, which forced me back to the canonical [EXP-018] move-and-preserve pattern.

**Didn't work**: The `for d in $NEW_DIRS; do git add "$d"; done` shell pattern failed to word-split the variable under zsh/bash interaction; the full multi-word string was treated as a single pathspec. Had to redo with `printf | xargs -n1 git add`. Lost ~1 commit's worth of time. Index-vs-disk drift pre-existed the session — 4 experiment dirs at source had no matching index entries (orphan disk state), and 11 index entries at source had no matching dirs (orphan index state). The drift was invisible until the Python script flagged "not found in source index" warnings.

**Confidence was low around**: the scope of Research migration (61 primitives research files, many cross-primitives but some per-package-scoped). Bulk-moved all to swift-institute/Research/ with a deferred note that per-file per-package routing remains a follow-up. This traded thoroughness for forward progress; a future audit pass per-package will naturally re-route the clearly-package-scoped ones.

**Confidence was high around**: the experiment relocations (mechanical per [EXP-002c] rule, verified by `swift package resolve` samples) and the skill updates (authored against direct reading of the existing rule text, with specific examples from this session's triage).

## Patterns and Root Causes

**Dismantle-leaves-orphan-content pattern**: when a superrepo is dismantled (`rm -rf .git`), three distinct orphan classes emerge simultaneously: (a) artifacts tracked by the container's git that now have no home (the "in-scope" orphans of this task), (b) artifacts that were in the container's working tree but never tracked (handled by an earlier Phase 0.5a per parent's HANDOFF), (c) superrepo-level infrastructure (Package.swift, umbrella Sources/, IDE workspace files, scripts tied to the umbrella build) that has no equivalent in the sibling-packages model. This task covered class (a); class (b) was covered pre-dismantle; class (c) was flagged for follow-up. The pattern recurs for every dismantle; the general shape is: inventory all three classes, route each to its canonical home per the dep-graph owner rule, delete only when canonically subsumed elsewhere.

**Codification-first discipline**: stage 2 existed specifically because executing relocations before the rule lands in skills means the next session can reintroduce the anti-pattern. The discipline costs little (~30 minutes of skill edits) and pays repeatedly: future sessions encounter the skill text, not the ghost of a past session's choices. Contrast with the alternative where Stage 3 executes first and Stage 2 happens "later" — that later never arrives because the execution output LOOKS like a correct state, so no one re-asks whether the rule landed.

**Empirically-verify-path-math claims**: the handoff's Constraint 3 was written by the handoff author with a plausible but wrong mental model. The actual resolution math is straightforward Unix relative-path semantics but diverged from the author's intent. This specific error class (an author writing a "fact:" or "constraint:" claim involving relative-path arithmetic) should always be verified with `python3 os.path.normpath` or a similar deterministic check before encoding in a handoff. The cost of verification is seconds; the cost of 8 broken moves cascades into follow-up sessions.

**Index-vs-disk drift as a recurrence signal**: the pre-existing index drift (some entries without dirs, some dirs without entries) indicates that prior sessions updated one but not the other. Per the new [EXP-003e] valid-index-locations rule, the source index for orphan-dir-without-entry cases should have been updated in the same commit as the move. Future sessions that do relocations MUST update both index and disk in the same commit wave; detecting drift at source time would have surfaced these 15 inconsistencies before this triage and required their resolution alongside the moves.

## Action Items

- [ ] **[skill]** handoff: add rule requiring empirical verification of path-math / dep-graph claims in Constraints before encoding (the Constraint 3 failure pattern — author encodes a plausible-but-unverified claim about relative-path arithmetic; future sessions execute against the wrong math). Minimal: a one-line convention rule under [HANDOFF-016] or a new [HANDOFF-021] pointing to `python3 os.path.normpath` or equivalent as the verification mechanism.
- [ ] **[research]** Draft a "superrepo dismantle remediation playbook" at `swift-institute/Research/superrepo-dismantle-remediation-playbook.md` capturing the three orphan classes (tracked, untracked-pre-dismantle, infrastructure), the stage-gated execution pattern (codify → execute), the index-vs-disk drift check, and the corrected path-dep-rewrite math. Tier 2 (ecosystem-wide, RECOMMENDATION). Future dismantle cycles (if any) would consume this.
- [ ] **[package]** swift-institute (Research + Audits): rebuild `_index.json` at both repos after merging with prior-session WIP; 88 research additions + 16 audit additions currently lack index entries pending that coordination.
