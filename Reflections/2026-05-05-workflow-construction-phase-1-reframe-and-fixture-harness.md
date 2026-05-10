---
date: 2026-05-05
session_objective: Build / test / document phase-1 γ-class advisory CI workflows (γ-1a Foundation-import, γ-1b license-header advisory, γ-2 mechanical hygiene) per centralized-swift-ci-and-spine-gate.md v1.2.0 §3.4.2/§3.4.3/§3.4.5
packages:
  - swift-institute
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction [HANDOFF-013a] BUILD-framed extension already covered by [HANDOFF-046] proactive-read-before-copy stop-condition (landed Cluster F). NoAction Auto Mode + ask: composition rule covered by [SUPER-031] CI-Failure Attribution + [SUPER-024] ground-rule compliance via inaction. Audit-script-as-workflow-logic offline harness pattern research deferred.
---

# Workflow construction phase 1 — premise-staleness reframe and audit-script-as-workflow-logic harness

## What Happened

Dispatched per `HANDOFF-workflow-construction-phase-1.md` (2026-05-05) to build three deterministic reusable advisory workflows from v1.2.0's γ-roadmap, test each in scratch repo per [RES-024], and produce phase-1 results doc at `swift-institute/Research/workflow-construction-phase-1.md`. The dispatch's MUST clauses included "Build three reusable workflows" with prescribed filenames `foundation-import-check.yml` / `license-header-check.yml` / `mechanical-hygiene.yml` and "MUST SHA-pin all third-party actions."

On the second tool call (git log of `swift-institute/.github/.github/workflows/`), discovered:

- `lint-foundation-family-import.yml` (γ-1a) landed in commit `ea4128f`.
- `lint-license-header.yml` (γ-1b stage 1) landed in `ea4128f`.
- `lint-yaml.yml` (γ-2) landed in `6c3d726`; `lint-broken-symlink.yml` (γ-2) landed in `2480628` — split per §3.4.11 *separate-reusable-per-concern* shape.
- All four wired into universal `swift-ci.yml` lines 241–271 with `with: { advisory: true }`.
- v1.3.0 changelog (line 16 of design doc, dated 2026-05-05): "Phase β + γ-1a/b/c + γ-2 + γ-4 all landed advisory and verified green on swift-carrier-primitives + swift-tagged-primitives canaries on 2026-05-05."

The supervisor block's `ask:` clause ("if v1.2.0's design and the existing reusable-workflow architecture conflict in any non-trivial way, **escalate before authoring**") triggered on three counts: dispatch's prescribed filenames vs ecosystem `lint-*.yml` convention; dispatch's single `mechanical-hygiene.yml` vs §3.4.11 separate-per-concern (which the existing two-file split conforms to); dispatch's "MUST SHA-pin all third-party actions" vs `[CI-013]` + `feedback_latest_versions_only.md` latest-major-tag convention for `actions/*` (existing `actions/checkout@v6`).

Surfaced the conflict inline. Reframed dispatch from BUILD → AUDIT + TEST + DOCUMENT under Auto Mode + supervisor-block `ask:` composition. Did not modify any workflow file; did not push to any remote.

Authored:

- `swift-institute/Research/workflow-construction-phase-1.md` v1.0.0 RECOMMENDATION (Tier 1, ecosystem-wide). Sections: pre-existing rollout state, per-spec-clause conformance audit (each v1.2.0 §3.4 clause + v1.3.0 §3.5 lesson tabulated), empirical scratch-repo verification, per-rule inventory mapping, deployment plan, deployment-readiness verdict.
- Index entry at `swift-institute/Research/_index.json` position 1.
- `/tmp/wf-phase1-scratch/` 8 fixtures (4 γ-classes × positive + negative) + `run-tests.sh` harness mirroring each workflow's gating shell. 8/8 produce expected exit codes.
- `[SUPER-011]` verification stamp on `HANDOFF-workflow-construction-phase-1.md` enumerating each MUST / MUST NOT / `fact:` / `ask:` entry with entry-type-specific evidence (verified | reframed-with-citation | not-tempted | held | triggered-and-surfaced).

### Handoff cleanup ([REFL-009])

HANDOFF scan at `/Users/coen/Developer/`: 23 files found.

| File | Disposition |
|---|---|
| `HANDOFF-workflow-construction-phase-1.md` | This session's; verification stamp present + all Next Steps complete + ground rules verified or reframed-with-citation. **Deletable per [REFL-009] standard rule** — but holding back from autonomous delete since the user's most recent action (`/reflect-session` invocation) implicitly accepted the reframe but didn't explicitly authorize the file's deletion. Annotation-and-leave is the conservative read; the verification stamp serves as the durable record for next-session triage if this file persists. |
| 22 other `HANDOFF-*.md` + 6 `AUDIT-*.md` | Out-of-session-scope per [REFL-009] bounded cleanup authority — not authored, worked, or completion-signal-encountered by this session. None past 14-day staleness threshold (oldest is Apr 30 — within window). No annotation. |

No audit findings to update ([REFL-010] not applicable — no `/audit` invoked this session).

## What Worked and What Didn't

**Worked**:

- **Premise-staleness detection on the SECOND tool call**. The first tool call read the dispatch + loaded ci-cd-workflows skill in parallel; the second was `ls -la swift-institute/.github/.github/workflows/` which immediately showed `lint-foundation-family-import.yml`, `lint-license-header.yml`, `lint-yaml.yml`, `lint-broken-symlink.yml` already present. No workflow YAML was authored before the staleness was caught.
- **Dispatch's MUST-SHA-pin clause not followed literally**. The reframe-with-citation approach (rather than silent override) preserved auditability: results doc Part 2 cross-cutting section explicitly explains why the literal reading conflicts with `[CI-013]` + `feedback_latest_versions_only.md` and what was adopted instead.
- **Audit-script-as-workflow-logic harness**. The four reusables' gating logic IS the audit script (γ-1a, γ-1b) / yamllint invocation (γ-2a) / `find -L` command (γ-2b). Driving each against fixture directories with the gating shell mirrored produced 8/8 expected exit codes — empirically equivalent to running the workflows on a scratch GH repo, but no push required.
- **Per-rule mapping in workflow header comments was already present** (e.g., `lint-foundation-family-import.yml:19–20` cites research §3.4.2 + `[CI-022]` + `[CI-031]` + `[CI-032]` + `[PRIM-FOUND-001]`). The "MUST include per-rule mapping" clause was a verification check, not an authoring task.
- **`[SUPER-011]` entry-type-specific evidence forms applied cleanly to each ground-rules entry**. The verification stamp's table reads as a complete audit trail without ambiguity.

**Didn't work / harder than expected**:

- **macOS bash 3.2 `mapfile` builtin missing**. The harness's first run hit `mapfile: command not found` on γ-2b. The actual γ-2b reusable runs on ubuntu-latest (bash 5+) where `mapfile` works fine; the bug was in the harness's local-shell choice, not in the workflow. Patched with `find ... | wc -l | tr -d ' '`. Lesson: when mirroring a workflow's shell logic locally, verify the shell-feature compatibility for the local runner.
- **Two-pass dispatch read**. The first read missed v1.3.0's existence (changelog at line 16, dated 2026-05-05) and the canary-green status. The second read, prompted by git log evidence, surfaced both. Direct cause: skipped the design doc's recent changelog entries before reading the §3.4 content.

## Patterns and Root Causes

**Pattern 1 — dispatch BUILD framing on already-built infrastructure**. The dispatch was authored without [HANDOFF-013a] writer-side grep against the central reusable repo. The design doc's v1.3.0 changelog (also dated 2026-05-05) explicitly recorded the rollout; either the dispatcher didn't refresh against v1.3.0 or didn't grep `swift-institute/.github/.github/workflows/` at write time. The cost: one round of subordinate work spent surfacing staleness and reframing rather than executing forward.

This generalizes [HANDOFF-013a]'s writer-side discipline. The rule currently covers "prior research grep" — extending it to "prior implementation grep against central reusable repo when prescribing BUILD work" closes the symmetric gap. The cost of the extension at handoff-write time is seconds (`ls swift-institute/.github/.github/workflows/`); the cost without it is what just happened.

**Pattern 2 — Auto Mode + supervisor `ask:` clause composition**. Auto Mode says "execute, prefer action over planning, minimize interruptions." Supervisor block's `ask:` clause says "escalate before authoring." Resolution: the contentious portion (modifying workflows, pushing) decouples from the additive portion (audit, scratch tests, results doc). Surface inline + reframe + execute the additive portion + pause at the contentious boundary. The dispatch's stop-conditions become bounded scopes rather than full stops.

This is non-obvious because both rules are framed absolutely. Codifying the composition makes the resolution mechanical: when the dispatch's deliverable can be partitioned into AUDIT/TEST/DOCUMENT (additive, no infrastructure change) vs MODIFY/PUSH (contentious, infrastructure change), Auto Mode permits forward motion on the additive partition with inline `ask:` surfacing on the contentious partition.

**Pattern 3 — scratch-repo testing of reusable GHA workflows under no-push constraint reduces to fixture-vs-script-logic harness**. The reusable workflow's logic IS the audit script (or yamllint invocation, or find -L). Driving it against fixture directories with the gating shell mirrored is empirically equivalent to running the workflow on a scratch GH repo — modulo the workflow YAML's own parse-validity (which is verified at GHA runtime against the live workflow, not against fixtures).

This pattern generalizes to phase-2 / phase-3 γ-classes: γ-1c (API-breakage advisory pilot) drives `swift package diagnose-api-breaking-changes` against fixture packages; γ-3 (Wasm SDK) drives `swift build --swift-sdk` against fixture; γ-4 (PR-title lint) drives the title-format regex against fixture title strings. The fixture catalog itself is reusable: today's eight fixtures are a seed; future γ-classes extend rather than replicate.

The depth of these three patterns suggests the phase-1 dispatch was actually a productive forcing function for codifying writer-side BUILD-grep discipline + Auto-Mode-`ask:`-composition + offline-fixture-harness — even though the literal deliverable was already in place.

## Action Items

- [ ] **[skill]** handoff: extend [HANDOFF-013a] writer-side grep discipline to cover BUILD-framed dispatches — writer MUST `ls` (or equivalent) the central reusable repo for pre-existing implementation matching the prescribed γ-class / family / pattern before writing a BUILD-framed dispatch. Provenance: 2026-05-05 workflow-construction-phase-1 dispatch on already-built reusables; entire reframe was attributable to the dispatcher's missing prior-implementation grep.

- [ ] **[skill]** supervise: codify Auto Mode + supervisor block `ask:` clause composition — when the dispatch's deliverable partitions into additive (audit / test / document) vs contentious (modify / push) and Auto Mode is active, the subordinate MAY forward-execute the additive portion with inline `ask:` surfacing while pausing at the contentious boundary. New rule (e.g., `[SUPER-031]`) or extension to `[SUPER-014a]`. Provenance: this session.

- [ ] **[research]** swift-institute: document the audit-script-as-workflow-logic offline harness pattern — research doc on testing reusable GHA workflows under a no-push constraint by driving the workflow's underlying script/command against fixture directories with the gating shell mirrored. Generalizable to γ-1c / γ-3 / γ-3b / γ-4 phases. Includes the eight γ-1a/γ-1b/γ-2 fixtures from `/tmp/wf-phase1-scratch/` as the seed catalog (recommend git-tracked promotion to `swift-institute/.github/.github/scripts/test-fixtures/` when γ-1b Stage 2 codemod lands and needs its own validation set).
