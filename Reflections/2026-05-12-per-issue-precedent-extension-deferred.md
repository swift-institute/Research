---
date: 2026-05-12
session_objective: Apply the per-issue restructure precedent (set by swift-issue-pointer-arithmetic-linux-miscompile) to the three remaining sibling triage dirs in swift-institute/Issues, then extend the pattern to swift-institute/Experiments per HANDOFF-issues-experiments-restructure.md.
packages:
  - swift-institute/Issues
  - swift-institute/Experiments
status: processed
processed_date: 2026-05-31
triage_outcomes:
  - type: no_action
    description: "Action items are arc-specific process-discipline tweaks (handoff/supervise/issue-investigation/reflect-session/lint-rule-promotion) already substantially covered by existing rules, point-in-time/stale, or better preserved in this reflection than promoted. Not promoted per the 2026-05-31 institute leanness program (de-bloat triage) to avoid further [PREFIX-*] proliferation in an oversized corpus; research items deferred (spawn via /research-process when scheduled). Learning retained here; re-promote individually if a pattern recurs."
---

# Per-Issue Precedent Extension: Four Candidates, Four No-Fits

## What Happened

Resumed a dispatch (`HANDOFF-issues-experiments-restructure.md`, authored
2026-05-11) directing extension of the per-issue restructure precedent to
three Issues sibling triage dirs (`copypropagation-nonescapable-mark-dependence`,
`rawlayout-noncopyable-deinit`, `spm-planning-build-stall`) and to the
Experiments repo. The precedent is the converged shape at
`swift-issue-pointer-arithmetic-linux-miscompile/`: one testTarget wrapping
the minimum trigger in `withKnownIssue("swiftlang/swift#NNNN", when: { … })`
flip-on-upstream-fix gate, one executableTarget for standalone exit-code
probing, evidence/ scaffolding for retired investigation artifacts, plus
INVESTIGATION-ARC.md + ISSUE-NNNNN-COMMENT.md if applicable.

Phase 1 triage produced three independent reasons each sibling dir fails the
precedent's structural assumptions:

- **copypropagation-nonescapable-mark-dependence**: bug FIXED in Swift 6.3
  (Xcode 26.4) per `swift-compiler-bug-catalog.md` § A2. `withKnownIssue`
  works by being green when the bug fires and flipping red on fix-landing;
  here the fix has already landed across the entire supported matrix
  (Swift 6.3 stable + 6.4-dev nightly, macOS/Linux/Windows). A
  `withKnownIssue` harness would have no green state, no red flip — no
  signal. Forensic record (README + INVESTIGATION-ARC.md +
  PRE-FILING-BUG-REPORT.md + external repo) carries the audit trail.

- **rawlayout-noncopyable-deinit**: minimum reproducer requires ≥3 SwiftPM
  packages chained through cross-package value-generic `@_rawLayout`
  storage. INVESTIGATION-ARC.md records 11 simpler standalone variants
  that all PASS — the bug refuses to manifest without the real
  `Storage<Element>.Inline<capacity>` chain. The precedent's
  single-package, single-`Tests/Reproducer.swift`, single-`swiftc`
  buildable target shape cannot capture this surface.

- **spm-planning-build-stall**: minimum reproducer is a workspace
  topology (URL/local identity-dedup edges across ≥2 packages), not a
  Swift code snippet. The productionized workaround already lives at
  `coenttb/swift-package-mirrors`. A single-package per-issue Tests
  target adds no detection signal.

User dispositioned all three to **defer-with-note** via the SGR `ask:`
escalation pathway. Phase 2 collapsed to adding a status note at the top
of each per-dir README explaining the specific blocking reason (cited
upstream issue numbers, evidence references, no-fit rationale).
Phase 3 deleted the predecessor `HANDOFF-restructure-per-issue.md` at
Issues repo root (untracked artifact; rm only).

Phase 4 survey of Experiments returned a deeper structural divergence:
214 standalone SwiftPM packages (each its own `Package.swift`), no root
Package.swift, no existing CI workflows, 197 of 211 packages
executableTarget-only, descriptive directory names (no `experiment-*`
prefix), `_index.json` + swift-institute.org dashboard already canonical
for discovery, write-time outcomes (CONFIRMED / REFUTED / CONSOLIDATED)
rather than ongoing fix-detection signals. The precedent's
mechanism — `withKnownIssue` flip-on-upstream-fix — has no analogue in
hypothesis-verification fixtures whose outcomes resolve at authoring
time. User dispositioned to apply the same defer-with-note treatment
("see how we did this for /Issues"); Experiments README received a
short "Per-experiment CI convention: deferred 2026-05-12" section with
three-bullet rationale.

Two commits landed cleanly:
- `swift-institute/Issues` `f900311` (Phase 1+2+3)
- `swift-institute/Experiments` `26f23f8` (Phase 4)

Both pushes carried explicit per-action YES per the SGR. `.github/metadata.yaml`
in Experiments (pre-existing user-WIP from a parallel session adding
`readme: family: C`) was left untouched per [GIT-012] dirty-worktree
discipline (explicit `git add README.md`, NOT `git add -A`). SGR
verification stamp authored into the handoff file per [SUPER-011] /
[HANDOFF-010] step 5 — 13-row table covering all 6 MUST/MUST-NOTs +
4 facts + 3 asks.

**HANDOFF scan**: 9 files at org-mirror root + 17 at Developer root.
1 file in this session's cleanup authority
(`HANDOFF-issues-experiments-restructure.md` — deleted per [REFL-009]
standard rule: Q1=yes via verification stamp + no unverified entries).
The predecessor `HANDOFF-restructure-per-issue.md` was already deleted
in Phase 3 (untracked artifact). 25 files out of session authority —
left untouched.

## What Worked and What Didn't

**Worked**:

- The handoff's SGR `ask:` rule fired correctly all four times ("if
  Phase 1 reveals a dir has no reducible repro / already fixed /
  invalid, surface before retiring" + "if Phase 4 reveals Experiments
  structurally diverges, surface before adapting"). Without those
  asks codified, the natural pull would have been to grind through a
  forced restructure that produced four broken test targets and no
  detection signal.

- AskUserQuestion served the per-dir disposition surface well: a
  four-option question with the recommended option labeled produced a
  clean one-pick decision for Issues; the same shape served Phase 4
  even though the user answered "Other" with referential prose ("see
  how we did this for /Issues") — lowest-loss interpretation per
  [SUPER-033] (apply the analog of the prior pattern) worked.

- The [GIT-012] dirty-worktree discipline (explicit `git add <file>`,
  never `-A`) preserved the prior-session user-WIP on
  `.github/metadata.yaml` without surfacing it as a separate question.
  The principal's review note explicitly flagged this as one of the
  session's positive points.

- The SGR verification stamp made the handoff's
  termination unambiguous: 13 rows covering every entry type with
  Verified / N/A / cited-evidence disposition. The principal called
  it "the most disciplined I've seen this session." Q1=yes
  classification per [REFL-009] is now mechanical (work complete +
  verifiable in commits + on disk) — no guesswork for the next agent
  who scans the org-mirror root.

**Didn't (or didn't apply cleanly)**:

- The handoff's framing of Phase 2 ("Restructure each dir that passes
  Phase 1") and Phase 4 ("Extend to Experiments") implicitly expected
  the restructure-extension default. The reality was: zero of four
  candidates passed the fit test. The phases collapsed to two README
  edits + one file deletion. Phase numbering with "restructure" as
  the work-product label undersells the actual deliverable
  (documentation-of-deferral) that a no-fit outcome yields.

- The Issues repo's "Per-Issue Convention" section in README.md is a
  positive convention statement — what the convention IS. There's no
  symmetric "When the convention doesn't fit" section. A future
  contributor encountering a new bug class has no documented surface
  enumerating the precedent's load-bearing assumptions; the only way
  to know "this won't fit" is via the experience of running through
  Phase 1 triage. The session's three failure shapes (already-fixed-
  upstream / multi-package reproducer / workspace-topology bug) are
  reusable knowledge that's not yet in the README.

- `withKnownIssue` applicability isn't explicitly documented in the
  testing-swiftlang skill. The mechanism is mentioned in passing
  ([SWIFT-TEST-014] ~Copyable in #expect, etc.) but the
  is-`withKnownIssue`-the-right-mechanism decision lacks a rule. The
  applicability conditions surfaced clearly this session: the bug
  must fire on ≥1 platform in the supported matrix at write-time
  (else no green state), AND a fix landing on any matrix platform
  must produce an observable red flip (else no detection signal).
  Either failure makes the harness useless.

## Patterns and Root Causes

**The precedent's load-bearing assumptions are narrower than its
phrasing suggests.** The convention reads as a general per-issue
shape, but its `withKnownIssue` mechanism encodes three implicit
conditions:

1. Single-package, single-`swiftc`-buildable minimum reproducer.
2. Live upstream bug whose fix will eventually land on a matrix
   platform (so the flip-to-red has a future trigger).
3. At least one matrix platform that fires the bug at the time of
   harness authoring (so the harness has a current green state).

The precedent itself satisfies all three: `swift-issue-pointer-arithmetic-
linux-miscompile/` (1) reduces to an 8-line `swiftc`-buildable trigger,
(2) is fixed on 6.4-dev nightly but not yet on Swift 6.3 stable so the
flip-to-red is a future event when the fix backports, (3) fires on
Linux release 6.3 today. Three-for-three.

The three sibling dirs each fail a different condition:
- copypropagation fails (2) and (3) — fix already landed everywhere.
- rawlayout fails (1) — needs cross-package fixture.
- spm-planning fails (1) and arguably (3) — workspace-topology bug,
  not a single-`swiftc`-trigger.

Experiments fails the entire model: it's not even a bug-detection
repo. The decision rubric ("does my bug fit?") becomes ("does my
problem domain fit?") — and the answer is the precedent's mechanism
has no analogue here.

**Pattern: precedent extension is an empirical fit-test, not a
mechanical replication.** A precedent demonstrates a pattern works in
one place. "Fit" of the pattern to siblings is a per-candidate
question requiring per-candidate evidence. The handoff author was
prescient about this — both the per-dir `ask:` rule and the
Experiments-survey-first `MUST NOT apply blindly` rule built the fit-
test into the dispatch protocol. Without those rules, the failure
mode would have been: mechanical extension producing structurally-
broken test targets (no green state on copypropagation, single-
package Tests/Reproducer.swift that can't reproduce on rawlayout / spm-
planning, monolithic Package.swift on Experiments collapsing 211
standalone packages). The handoff's `ask:` discipline turned a
high-risk dispatch into a low-risk surface-the-finding dispatch.

This generalizes: **dispatches that anticipate "extend X to siblings"
should structurally anticipate "no fit" as a non-failure outcome.**
A "no fit" disposition isn't a dispatch failure — it's an empirically
correct result for the candidate set. The handoff's Open Question #1
already enumerated the three Phase-1 outcomes: (a) restructure /
(b) retire / (c) defer-with-note. The framing was right; reality
picked option (c) four times in a row.

**Related pattern: documentation of negative space.** A positive
convention statement ("the per-issue layout is X") doesn't make the
convention's failure-mode boundaries discoverable. The "When the
convention doesn't fit" subsection that's the obvious follow-up
(action item 1) is the negative-space documentation that makes the
fit-test cheaper for future contributors — they get to read the
failure shapes rather than re-derive them via Phase 1 triage.

The recurring discipline that worked across this session — surface
the empirical finding, codify it in a fix-it-once-instead-of-everyone
-rederives-it artifact (README note, README-section, eventually a
skill rule) — is the same shape as [HANDOFF-013a] writer-side prior-
research grep / [SUPER-035] pre-dispatch empirical state verification:
shift the verification cost to the cheapest moment (the moment of
authoring) and produce a reusable artifact downstream.

## Action Items

- [ ] **[doc]** `swift-institute/Issues/README.md`: add a "When the
  convention doesn't fit" subsection enumerating the three failure
  shapes surfaced this session (already-fixed-upstream → no green
  state for `withKnownIssue` / multi-package reproducer → can't
  reduce to single `swiftc`-buildable target / workspace-topology
  bug → no Swift-code minimum trigger). Position immediately after
  the existing "Per-Issue Convention" section so a contributor
  reaches it before authoring a new `swift-issue-*` dir.

- [ ] **[skill]** `testing-swiftlang`: codify `withKnownIssue`
  applicability as a new rule (likely [SWIFT-TEST-NN]). Conditions:
  (a) the bug must fire on ≥1 platform in the supported toolchain
  matrix at harness-authoring time (else no green state); (b) a fix
  landing on any matrix platform must produce an observable red flip
  (else no detection signal). When either condition fails, the
  harness is structurally inert — record the bug's status in the
  catalog + a forensic README, but don't author the harness. Cross-
  reference: `swift-institute/Issues/swift-issue-pointer-arithmetic-
  linux-miscompile/` for the positive precedent.
