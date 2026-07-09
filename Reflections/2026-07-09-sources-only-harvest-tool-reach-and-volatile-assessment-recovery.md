---
date: 2026-07-09
session_objective: Close the executor's leg of the swift-linter remediation arc — verify the CI-harvest fix, preserve an independent assessment, and correct the Fable handoff before the chat closes.
packages:
  - swift-w3c-css
  - swift-ieee-754
status: pending
---

# The Sources-only harvest: a verification tool that under-reached its "complete" claim

## What Happened

This session was the executor's closeout of the swift-linter remediation arc, handing it to a fresh Fable session. An independent Fable sub-agent assessment (task `a8cfb65`), commissioned by the principal to reassess the arc without prejudice, had returned in-chat with one critical finding: `endgame/harvest-findings.sh` matched only `consumer/Sources/…`, so **SWIFT-TEST-002 (~1,748 sites / 191 repos) and SWIFT-TEST-005 (~3,163 sites / 64 repos)** — both of which live exclusively under `Tests/` — were never harvested from any CI-covered repo. Every "tier complete" in the ledger was really "Sources-complete."

I re-verified independently (all harvested TSVs carried zero `Tests/` lines; every CI harvest returned exactly 3 of the 5 rule classes), then fixed both regex branches to `(Sources|Tests)/` with the sed capture groups renumbered. I tested the fix on `swift-ieee-754`: the patched script now harvests **668 test-side findings (492 SWIFT-TEST-005 + 176 SWIFT-TEST-002)** straight from CI — exactly the load the assessment predicted.

Concurrently the `swift-w3c-css` chunk-8 worker returned green (`dafdc2d`, API-IMPL-008:182, 2183 tests) — not the dead-worker recovery the prior handoff had assumed. I updated the ledger (now 225 lines) and chunk tracker.

Fable's assessment existed **only in chat** and would have been destroyed at chat close. I recovered its verbatim text by parsing the session JSONL transcript and preserved it as `endgame/FABLE-ASSESSMENT-2026-07-09.md`. I also copied five worker patches off ephemeral `/tmp` into `endgame/parked/patches/`.

I rewrote `HANDOFF-fable-remediation-arc.md`: corrected the headline to "Sources-complete only," re-ordered Next Steps around a fleet test-side re-harvest wave (dispatch SWIFT-TEST-005 now; **hold SWIFT-TEST-002** for the principal's shape ruling per assessment A2), and added the headSha exit-audit gate, the ~51-site IMPL-075 catch-body audit, the wave-0 straggler flip, and a principal-escalation list. I committed 205 endgame artifact files to the private Workspace repo — most first-tracked in this batch (the accumulated harvest scaffolding), plus the preserved assessment, the five patches, and the updated ledger and handoff (`14adc05b`, pushed) — and provided the copy-pastable resumption prompt.

**Handoff triage (this reflect-session, [REFL-009]):** scanned 61 top-level `*.md` files in `Workspace/handoffs/`. Deleted `HANDOFF-opus-remediation-arc.md` — its header self-marks `⛔ SUPERSEDED 2026-07-09 by HANDOFF-fable-remediation-arc.md`, and I authored that successor this session, so it is in-authority per [HANDOFF-039]. Left every other file untouched (out of authority, or in-flight — the live `HANDOFF-fable-remediation-arc.md` that Fable is about to consume). `check-handoffs.sh` is red at 61 > 40 (the documented, report-only store overage; the CLAUDE.md ruling is hold-40-and-drain-per-arc, not force-the-number, so no bulk drain); `check-memory-corpus.sh` green (zero topic files).

## What Worked and What Didn't

**Worked.** The independent-assessment move earned its cost: a fresh pass caught a coverage hole that the executor's own "the loop is idempotent, a re-harvest re-surfaces anything skipped" mental model actively concealed. Adversarial second-eyes on a "we're basically done" claim is exactly where the value sits. And [REFL-011] primary-source re-derivation paid off *within this reflect-session*: I had believed Workspace HEAD was `14adc05b` with two dirty files; a fresh read showed HEAD had moved to `1c75bbf3` (a concurrent repotraffic commit) with one dirty file. Transcribing from memory would have shipped a false state-claim into the reflection itself. And the handoff proved immediately actionable: within the hour a successor session had picked it up and begun executing the reordered Next Steps 3–4 — the Workspace working tree showed the headSha exit-audit gate added to `harvest-findings.sh` (with a `STRICT=1` refinement) and a populated `endgame/testside/` fleet re-harvest directory, matching the plan.

**Didn't.** The harvest tool shipped with a Sources-only regex and it went unnoticed for the entire arc (~160 repos drained). The "nothing-to-fix" and "complete" statuses on every CI-harvested repo were half-truths the whole time. Worse, the executor (me, earlier) propagated that into the handoff as "all 3 tiers COMPLETE" — a first-assertion state-claim that could have driven arc-closure had the assessment not intervened. Separately, Fable's assessment sat in volatile chat context between its return and its preservation — a window in which a chat close would have destroyed a critical, fact-verified finding.

## Patterns and Root Causes

The core failure is a **verification tool under-reaching its apparent claim** — precisely [REFL-011]'s tool-reach class. `harvest-findings.sh` answers "what findings exist in this repo?", but its regex reads only `Sources/`. Two of the five rule classes live exclusively in `Tests/`. So the tool's *reach* (Sources) was strictly narrower than the *claim* it fed ("this repo's findings are drained"), and an empty harvest was read as "clean" when it meant "clean where I looked." This is the same shape as a stale-cache "cold" build or a narrow gate-grep: the instrument's coverage silently bounds the assertion while the assertion is stated at full scope. The tell was available from day one — the rule catalog has five classes and every CI harvest returned exactly three. A one-line coverage cross-check (harvested classes ⊆ catalog, and every catalog class's home root ⊆ harvested roots) would have surfaced it before the first drain.

The second pattern: **a sub-agent's highest-value output is volatile until it is written down.** The assessment was commissioned specifically to inform the handoff, yet it was delivered as chat text — the one medium that does not survive the chat. Grepping the JSONL to recover it worked but is fragile (depends on the transcript still existing on disk and the finding being greppable) and expensive. The handoff skill already states the durable-record axiom ("git is ground truth, not agent memory"); it extends cleanly to sub-agent findings — an assessment that drives a handoff must be persisted at receipt, not left in context to be paraphrased or recovered later.

A quieter third thread ties the two together: the "loop is idempotent, so a re-harvest re-surfaces anything skipped" reassurance was **false under the buggy regex** — re-running a Sources-only harvest can never surface a `Tests/` finding. A process is only as idempotent as its detector is wide. Any completeness argument that leans on "the loop will catch it next time" has to first prove the loop's detector reaches the thing it claims to eventually catch. Here it did not, and that unproven assumption is what let a two-of-five-classes hole read as done.

## Action Items

- [ ] **[skill]** reflect-session: add a tool-reach operational instance to [REFL-011] — a path-scoped finding-harvest under-reaches when its regex omits a source root (a Sources-only harvest missed every `Tests/`-resident SWIFT-TEST-002/005 finding across the fleet); before reading a harvest's empty/clean result as "complete," verify the harvested rule-classes and file-roots cover the full rule catalog — and do not treat a re-runnable "idempotent" loop as self-correcting for any class its detector cannot reach.
- [ ] **[skill]** handoff: add a rule that a commissioned sub-agent assessment whose findings inform a handoff MUST be persisted verbatim to the artifact store at receipt — in-chat delivery is volatile, and recovering it from the session transcript is fragile and expensive.
