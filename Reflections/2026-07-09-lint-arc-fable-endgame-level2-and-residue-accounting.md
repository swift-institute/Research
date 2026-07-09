---
date: 2026-07-09
session_objective: Take over the swift-linter remediation arc as Fable orchestrator — verify the independent assessment, drain the test-side gap, and drive the mechanical phase to an honest finish
packages:
  - swift-institute-linter-rules
  - swift-w3c-css
  - swift-ieee-754
  - swift-json-web-token
  - swift-time-based-one-time-password
  - swift-rfc-9293
status: pending
---

# Lint-Arc Fable Endgame: Level-2 Verification and Honest Residue Accounting

## What Happened

Fable took over the remediation arc from the Opus executor. Verified the independent assessment by
sample (its critical Tests/-harvest gap was real and already fixed), then ran the day as a wave
pipeline: test-side re-harvest (313 repos), SWIFT-TEST-005 drain (2,736 fixes / 86 repos), the
principal-ruled TEST-002 extension-pattern restructure (~250 suites), the swift-testing parking wave
(26 repos; ruling: refactor `#Tests` scaffolding to plain Swift Testing, park `.timed`/`#snapshot`
tests inert under `Tests/Testing/`), the third-party dependency inventory + M1 swaps, the NOJOB
CI-wiring sweep (mostly already wired), the §A6 amendment batch (principal-delegated adjudication),
an exit re-harvest with a new headSha staleness gate, and a Level-2 residue wave. Also reconciled
four principal-reserved items (rfc-9293's mystery diff = an unfinished module-split repair;
jwt manifest + rebuilt claims layer; swift-css worktree cherry-pick; OTP overload dedup). Session
survived a mid-day account-limit outage via an Opus-window handoff and workflow-cache resume.
Day total: ~9,700+ findings fixed and pushed across ~200 repos.

HANDOFF scan (Workspace/handoffs/): consumed `HANDOFF-fable-remediation-arc.md` and
`HANDOFF-opus-window-2026-07-09.md` retired to `.trash/`; live dispatches left in place:
`HANDOFF-drift-arc.md`, `HANDOFF-witnesses-macros-arc.md`, `HANDOFF-fable-overnight-2026-07-09.md`
(fresh successor, pending consumption); `HANDOFF-repotraffic-arc-2026-07-09.md` out of session
authority, untouched. The `.handoffs/` WIP-cap guard reads 63>40 — per the standing cap ruling
(2026-07-06, drain per-arc at close), the lint arc's `lint-arc-artifacts/` store drains at ARC close,
not tonight; overage noted, not force-triaged.

## What Worked and What Didn't

**Worked**: (1) Level-2 CI-verification — the principal's "can we rely more on CI?" led to the day's
biggest velocity gain: ~100 repos in 29 minutes vs a projected 8–12 hours at the 3-build local cap,
zero worker errors, because the fleet's CI matrix was already a stronger verifier than local macOS.
(2) Recovery machinery: exact-subject done-checks, workflow-cache resume, and git-truth
reconciliation made every failure cheap — two session-limit kills, two structured-output failures,
and two worker backgrounding violations all recovered without lost work. (3) Gate discipline:
M1's build+test gates correctly refused the drift-broken product repos rather than forcing swaps;
a residue worker refused mid-task "expanded push authority" messages and stuck to its brief.

**Didn't**: (1) The exit draft's "1,108 genuine misses" was ~53% adjudicated skip-residue
(generic-type API-IMPL-008 dominates at ~464 rows) — the raw count briefly misrepresented the
arc's true state until the fold named the classes. (2) Two agents violated FOREGROUND-only
despite explicit brief text (backgrounded a harvest; yielded to wait) — brief text alone does not
prevent this failure mode. (3) The NOJOB target list was largely stale (most repos already wired) —
a scout-refresh before dispatch would have saved a 46-agent wave's cost.

## Patterns and Root Causes

**Verification capacity should be matched to failure-mode visibility, not habit.** The 3-build
local cap was treated as the arc's law of physics for days, while every public repo carried a
multi-platform CI matrix idling. The correct decomposition was by failure mode: transforms whose
failures CI *can* see (build breaks, test failures) belong on CI; transforms whose failure is
invisible to green CI (TEST-002 silent test-discovery loss) keep the local baseline gate. Once
stated that way, the exception list wrote itself. The general form: before accepting a capacity
constraint, ask what property the constrained resource is actually providing, and whether a
larger idle resource provides it too.

**Residue accounting must classify by disposition, not count findings.** A CI count conflates
"missed work," "adjudicated skips," "drift-blocked," and "self-clearing after an amendment." Every
time this arc reported a raw number upward (the ~4,900 test-side estimate, the 1,108 misses), the
number shrank dramatically once classified. The ledger/exit-draft pattern that emerged — every
finding carries a disposition class — is what let the arc claim honest completion; it should be the
starting shape of any future sweep, not the ending one.

**Waves must be designed for death.** Session limits, output failures, and turn-boundary kills are
routine at this scale (six incidents today). Everything that made recovery cheap was decided at
dispatch time: idempotent worker steps, exact-subject done-check as step -1, workflow-level result
caching, patches-before-touching-dirt. Recovery cost correlated near-zero with incident severity
and entirely with whether the wave had these properties.

## Action Items

- [ ] **[skill]** ci-cd-workflows: design + codify the ratchet-after-convergence mechanism
      (per-class advisory→blocking flip on the CI linter job once the exit re-harvest shows a class
      at fleet-zero; principal-endorsed 2026-07-09, also in Workspace/inbox.md).
- [ ] **[skill]** supervise: codify the wave-resumability requirements for bulk subagent dispatch
      (exact-subject done-check, idempotent steps, journal/cache resume, patch-before-touching-dirt,
      git-truth reconciliation as the recovery entrypoint).
- [ ] **[skill]** swift-linter: add the Level-2 CI-verification mode with its exclusion classes
      (discovery-loss transforms, megas, weak-CI repos) and the `[Level-2: CI-verified]` commit-marker
      convention, so future arcs inherit it as a sanctioned gate rather than a session ruling.
