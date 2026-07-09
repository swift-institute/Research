---
date: 2026-07-10
session_objective: Orchestrate the lint-arc overnight endgame (P0→P4) via workflow-dispatched workers; ended early into a re-handoff and a unified two-arc session
packages:
  - swift-rfc-5890
  - swift-rfc-9557
  - swift-rfc-4291
  - swift-w3c-css
  - swift-whatwg-url
status: pending
---

# Fable overnight session 1: CI conformance wave, the publish-surface incident, and multi-session choreography

## What Happened

Took over the lint-arc endgame from `HANDOFF-fable-overnight-2026-07-09.md` at ~22:10. P0
verification immediately corrected the handoff's central premise: "assume dead workers" was
wrong — a live sibling session (repotraffic, session 3) was mid-migration with two running
builds and ~16 repos of uncommitted/held state. All planned lanes were re-sized around a
shared 3-slot build budget.

Delivered: P1a 5/5 CI-red fixes (rfc-5890 `fb4d400`, rfc-9557 `2b5b1ca`, rfc-4291 `820b1e3`,
w3c-css `5f9517d`, whatwg-url `9702e5a`), each locally gated; workers' root-causing
reclassified 2 of the 5 as pre-existing (w3c-css: 17 test targets empty since March, masked
locally by untracked empty dirs; whatwg-url DocC red since ≥06-25). A mid-session principal
grant ("all packages same CI setup") triggered a fleet CI-conformance inventory (460 repos
already canonical, 39 deviants) and an alignment wave: 37/39 pushed. Three prep deliverables
landed via no-build workers: test-target repair inventory (790 held rows), witnesses-macros
consumer inventory (real macro surface = 5 packages, not 15; sibling already ~40% migrated),
and `derive-ledger-from-git.sh` (98.8% ledger reproduction; surfaced 60 hand-ledger omissions).

The incident: the CI wave pushed each repo's local main, and on 16 repos that ref was silently
ahead — publishing unpushed backlogs including 4 of session 3's deliberately-held port commits
(one an explicit WIP checkpoint). Root cause and corrective rule documented in
`Workspace/handoffs/lint-arc-artifacts/endgame/session3-relay-and-push-incident-2026-07-09.md`.
Three principal relays landed mid-session (build/gate practice; url-routing provenance,
twice-superseded); the 3-slots × `-j 4` env-sanitized `taskpolicy` regime was ratified.

Session ended early by principal direction: re-handoff authored
(`HANDOFF-fable-overnight-restart-2026-07-09.md`), then both arcs consolidated into one
unified session whose kickoff prompt this session compressed from ~5.6k to 3,987 chars by
replacing handoff-duplicated content with authoritative-section references.

HANDOFF scan: 5 files in session authority of 64 in store; 0 deleted, 1 annotated
(`HANDOFF-drift-arc.md` item 9 P0-verification note, in-session),
1 annotated at reflect-time (`HANDOFF-witnesses-macros-arc.md`: step-2 inventory pointer),
3 no-touch in-flight (`HANDOFF-fable-overnight-2026-07-09.md` CONSUMED but on the live
unified session's read-list; `HANDOFF-fable-overnight-restart-2026-07-09.md` and
`HANDOFF-repotraffic-arc-2026-07-09.md` actively executing). Store guard reads 64>40 — red by
the documented cap ruling; lint arc not yet closed, no forced triage. Memory guard OK.
No /audit ran this session.

## What Worked and What Didn't

Worked: verification-first P0 (git/ps before acting) caught the dead-workers premise within
minutes and prevented three lanes of build contention. Workflow workers with structured-output
schemas and hard rails consistently out-performed their briefs — the w3c-css worker refused the
dispatch premise ("wave-caused") and proved pre-existence from CI history before fixing; the
rfc-9557 worker found all 5 defect sites where CI logs showed 2. Inventory-before-wave (460/39)
made the grant-widened CI wave cheap to adjudicate. Parking 23 safety-net patches before any
lane ran cost minutes and covered every later surprise.

Didn't: the CI wave's safety check verified the edit surface (`.github/workflows` clean) but
not the publish surface (`origin/main..main` ahead-count) — 16 repos published backlogs they
were silently holding. Confidence was high precisely because the check that existed passed;
the check that mattered didn't exist. Also self-inflicted: an awk-quoting bug in the first
process-sweep, and early gates ran env-polluted (pre-relay) — both caught, neither costly.
The swift-bounded-cache push failure was the visible instance of the same divergence class
and was initially read as an isolated anomaly rather than a class signal — the relay, not my
own generalization, surfaced the class.

## Patterns and Root Causes

**A push publishes the ref, not your diff.** The incident is a tool-reach failure in the
[REFL-011] sense: "commit only CI files + push" reads as a narrow operation, but `git push`
publishes everything reachable from the ref — its reach exceeds the wave's authored scope
whenever local main is ahead. The invariant must be checked mechanically per-repo
(`git rev-list origin/main..main --count` == 0 before committing), because wave intent cannot
see per-repo ref state. This generalizes: any bulk operation whose primitive has wider reach
than the authored change (push, force-resolve, formatter-on-save) needs a pre-flight
reach==scope assertion per item, not per wave.

**Single-owner assumptions rot the moment sessions run concurrently.** The handoff's "assume
dead workers," the wave's "local main == what I authored," and CLAUDE.md's "pkill stale
swift-*" gotcha all encode a one-session world. Tonight three sessions shared the machine and
each assumption failed in its own way (live workers; held commits; a SIGTERM'd sibling build).
The durable fix is that handoffs and waves must carry explicit concurrency state — which
sibling sessions are live, what they hold unpushed, which processes are owned — plus a
verification command, never a prose assumption. Session 3's relay pattern (persistent
markers, registered PIDs, held-commit ledger) is the working model.

**Compression by authority-reference.** The unified kickoff prompt got under its 4k cap only
by deleting everything the two handoffs already owned and keeping inline only what existed
nowhere else (grants, inherited process state, lane priority, binding rulings). Same shape as
the leanness principle: one canonical home per fact; the prompt points, the handoff holds.

## Action Items

- [ ] **[skill]** ci-cd-workflows: add a mass-rollout requirement — every wave-push worker
  MUST assert `git rev-list origin/main..main --count` == 0 before committing (skip+flag
  otherwise); a push publishes the whole ref, so reach==scope must be asserted per repo.
  (Origin: tonight's 16-repo publish incident; corrective rule already in force in-session.)
- [ ] **[skill]** handoff: require a "Concurrent sessions" block in handoffs authored while
  sibling sessions may run — live sibling identity, their held-unpushed ledger, owned-PID
  registry, and a verification command for any liveness premise ("assume dead workers" must
  ship with the ps/git commands that test it).
- [ ] **[skill]** swift-package-build: codify the ratified gate regime as PKG-BUILD rules —
  ≤3 concurrent gates machine-wide, each `env -i … TOOLCHAINS=… taskpolicy -c utility
  swift build/test -j 4`; pin-advance via `swift package update <dep>` (never delete
  Package.resolved); never blind-pkill (registered PIDs only). Source:
  `Research/swiftpm-build-concurrency-and-caching.md` (34be472, held) — also retire the two
  contradicted CLAUDE.md gotchas when promoting.
