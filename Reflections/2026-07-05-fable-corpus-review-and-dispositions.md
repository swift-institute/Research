---
date: 2026-07-05
session_objective: Full-corpus consistency review from a fresh Fable seat — find cross-skill contradictions, stale canon, velocity drag, and lint-coverage gaps; adjudicate; execute dispositions and the store triage
packages: []
status: pending
---

# Fable Corpus Review — Findings, Disposition Waves, and Store Triage

## What Happened

Booted from `BRIEF-fable-corpus-review.md` (retired at close) the same day five skill monoliths were split and the memory corpus was dissolved. Ran 7 mechanical sweeps (cross-ref census, stale paths, contradictions, description gates, hub-index completeness, drag evidence, lint gaps) over 62 skills / 123 files / 1501 defined IDs, plus in-loop reading of the five hubs, skill-lifecycle, and the core manifest. Found 8 fatal-class contradictions (worst: [RES-020]–[RES-025] each defined twice in one file; [REFL-016] prescribing the stash pattern its cited rule had just reversed; the toolchain contract inverted in swift-package-build), ~20 routing/index defects, ~30 dangling references, and the drag/coverage findings. Executed via 12 exclusive-ownership drafters + this seat as serialized committer: ~40 commits across Skills, Workspace, rule-institute, Engagement, .github (Research local-only per the tower push gate). The principal ruled on all 8 queued decisions same day; all executed, including the swift-kernel-primitives phantom sweep (~20 sites re-anchored on L3 `swift-kernel`) and three new principal-ratified rules ([SKILL-CREATE-015]/[SKILL-CREATE-016]/[ARCH-LAYER-013], plus [SUPER-058] re-homing an orphaned tombstone). Terminal record: `swift-institute/Audits/REPORT-corpus-review.md`.

HANDOFF scan (per [REFL-009], enumerated): 109 files in `Workspace/handoffs/` at triage time; 17 ADT/tower files frozen (parallel arc, incl. 4 with in-flight edits — untouched); 2 own-arc artifacts closed by class at session end (REPORT → Audits, BRIEF → `.trash/`); 89 triaged via 3-agent evidence sweep → 30 retired to `.trash/` on cited git/disk evidence, 4 closed-arc records moved to `swift-institute/Audits/`, 55 left in place (41 tower-family, ~28 open with named triggers, 2 UNSURE kept conservatively, 1 stray reference doc flagged for relocation). Store: 106→73 live; guard red (73>40) is documented-expected until the tower cluster drains; cap 40 kept (post-tower projection ~34–38). Guards at close: memory target-zero OK; no loose-root strays. No `/audit` invocation this session ([REFL-010] n/a).

*Post-reflection addendum (2026-07-06)*: after this entry was written, the closing conversation staged two dispatch briefs (store now 75 live): `BRIEF-post-tower-finalization.md` (fires at ADT/tower close — store drain, kernel residuals, Research push, book-closing) and `HANDOFF-mechanization-arc.md` (canon guard `check-canon.sh` + promote waves + promote-then-evict, per principal direction 2026-07-06 — explicitly a check-script, not a swift-linter rule). Both carry their own lifecycles; no new learning beyond the naming lesson that "canon linter" invited a tool-confusion the handoff now pre-empts.

## What Worked and What Didn't

Worked: the fresh-seat premise — a same-day outside reviewer found defects (six-row hook-shift in readme's index, an inverted checklist, the six-ID collision) that per-skill self-review had repeatedly passed over. Verify-by-sample earned its cost three times: sweep claims overturned on primary-source checks (a "missing" experiment that exists nested inside its package; phantom ledger rows a second sweep had taken at face value; a "no size gate exists" claim contradicted by the live guard). Drafter discipline held: exclusive file ownership produced zero collisions; the two exact-baseline files landed at exactly their caps. Parallel-arc discipline held throughout — zero ADT file touches.

Didn't: one sweep died mid-run on an API drop (resumed cleanly with context intact — resume-over-respawn was the right call). This seat's own slip: ran the size guard piped through `head` and briefly read `head`'s exit code as the guard's — caught within a minute by re-running unpiped; a second compound command committed while the guard printed red in the same chain (the red was another drafter's in-progress file, but the chain should have gated). My first reflection entry was written free-form instead of loading this skill first — exactly the pre-edit-checkpoint class the corpus warns about; this rewrite is the correction.

## Patterns and Root Causes

1. **Reversals rot the corpus through citing sites, not definitions.** Five of eight fatal contradictions were un-propagated 2026-05→07 reversals: the definition was amended, the quoting rules were not. Root cause was structural — [SKILL-LIFE-007] bound propagation to DEPRECATE/REMOVE only. Fixed by extending its trigger to REVERSED/Breaking-amended; the residual risk is behavioral (the grep must actually run), worth spot-checking on the next few breaking edits.
2. **Prose decays, mechanics hold — re-confirmed empirically.** Everything mechanically guarded (sizes, descriptions within gate scope, memory) was healthy; everything prose-only (citations, hub indexes, caps without wired guards) had rotted. The corollary found twice: a gate whose scope silently excludes part of the corpus (descriptions gate's root set; depth-2 size scan) reads as green while unmeasured — tool reach IS the claim's scope ([REFL-011]).
3. **Author-is-wrong-reviewer generalizes to agents**: sweep agents were productive finders but three verdicts failed primary-source verification. The working shape — cheap agents propose with cited evidence, the seat samples against primaries, class-table overrides at adjudication — is the same supervisor pattern the corpus already prescribes for humans, and it transferred unchanged.
4. **Evidence-based store triage is cheap and repeatable**: ~90 files cleared in one pass at ~2 min/file using a fixed probe rubric (in-file markers → artifact existence → git log), with UNSURE→keep as the default. The expensive-looking backlog was mostly an evidence problem, not a judgment problem.

## Action Items

None new — this session executed its own dispositions in-line; every residual is already queued in `Workspace/BACKLOG.md` with named triggers (tower-cluster store drain, L1 promote batch, [SKILL-LIFE-005] mechanization, [API-IMPL-008] linter fold, kernel validator residuals). Per [REFL-004], no untracked items are added here.

*Index note ([REFL-016])*: `Reflections/_index.json` carried another session's uncommitted entry at write time; this entry was appended in the working tree and left UNCOMMITTED alongside it (leave-in-tree disposition — commit-first is unavailable because the prior WIP belongs to a parallel session, [SUPER-056]). Index commit pending whichever session closes next with a clean tree.
