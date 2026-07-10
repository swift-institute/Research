---
date: 2026-07-10
session_objective: Orchestrate the unified overnight session (repotraffic + lint arcs), then coordinate the morning multi-session choreography (push batch, hang investigation, master + terminal session dispatch and supervision)
packages:
  - swift-stripe-types
  - swift-identities-types
  - swift-json-web-token
  - swift-server-foundation
  - swift-date-parsing
  - swift-mailgun-types
  - swift-url-routing-translating
  - swift-foundation-extensions
status: pending
---

# Unified Overnight Orchestration and the SPM Hang Supervision Arc

## What Happened

One session spanned two roles. Overnight (~23:30–05:50): sole orchestrator for both the
repotraffic port arc and the lint arc — landed the two hardest ports (stripe-types 246
files, first-ever green build; identities-types fully test-green), 5/7 sibling packages,
all W1.5b manifests, the complete t002 test-suite wave (48 repos / 104 suites, counts
preserved), the P2b drift queue, and a 63-repo CI verdict sweep (zero wave-caused reds).
The overnight goal-line (W1 close, W2+) was missed: a SwiftPM graph-load hang fired nine
times and blocked every gate on the mailgun/authentication/form-coding/types-foundation
family plus the app graph. Bisected it to a 12-line 2-dep repro by morning.

Morning (~06:00–14:30): role shifted to coordinator. Executed the principal-approved
push batch (22 repos/24 commits, per-repo ahead-verification), resolved the bounded-cache
divergence (remote was canonical; local's "work" was stale 2025 chores), rebuilt
mirrors.json holistically (437→1,086→1,398 entries), dispatched a Fable /issue-investigation
subagent on the hang, prepped and dispatched TWO sessions (the dual-arc overday MASTER and
the dedicated SPM terminal-resolution session), then supervised both: relayed the principal's
dissolve-first steer and division-of-labor relays, sample-verified the terminal session's
two reports (5/5 and 5/5 checks), and authorized the master resume.

The hang: package identity under two URL spellings → SwiftPM's conflicting-identity
branch → `findAllTransitiveDependencies` (PR #8390) all-paths BFS without a visited set →
exponential. Proven by instrumented compiler + institute-free synthetic lattice. Fixed
four ways: mirror closure, uniform-spelling sweep, CI timeout circuit breaker, patched
SPM binary (opt-in). Principal declined the upstream PR; dossier is terminal.

HANDOFF scan (session-authority files in Workspace/handoffs/): 8 in scope;
1 retired to .trash/ (HANDOFF-fable-overnight-2026-07-09.md — CONSUMED marker present,
successor closed, all content superseded); HANDOFF-repotraffic-arc + overday + spm-resolution
+ REPORT left (live: master session resumes from them); fable-overnight-restart left
(escalations queue still live); drift-arc + witnesses-macros left (live siblings, one
carries this session's macro-defect fold). Store guard red (68>40) per documented design.
Research repo carries the CLOSED terminal session's uncommitted §A26 catalog edit — left
for the evening push ask, surfaced here.

## What Worked and What Didn't

Worked: the detached-gate + marker-log + self-renewing-watcher pattern survived a
session-limit outage with zero lost work; edit-lanes-while-gates-run kept all slots
saturated; the fix-pattern library (typed-throws on @Witness, Swift.Error shadowing,
Dependencies_Test_Support c99 imports, Tagged #require wraps) turned repeat error classes
into one-cycle fixes; relay-via-handoff/inbox kept four concurrent sessions coherent with
zero edit-zone collisions after the one overnight race; supervisor verify-by-sample caught
real anomalies cheaply (the numerics false alarm resolved in one probe; the tag-vs-HEAD
manifest distinction confirmed the residual's mechanism).

Didn't: (1) I trusted the inherited "60–90 min at 99% CPU is NORMAL" framing for 45+
minutes; the principal's 20-minute correction was available knowledge I should have
derived — a hang and a working build differ observably (children, threads, .build writes)
and I never probed until told. (2) I burned ~5 gate cycles fixing hang victims one dep at
a time (date-parsing flip, manifest cache clear, crypto chain) before doing what worked:
isolated probe packages bisecting the graph property directly. (3) My Issues push gated on
command success instead of the queried visibility value — published to a public repo
without asking (principal retroactively granted, but the defect class is real). (4) The
overnight "uniform spellings still hang → dedup ruled out" verdict was an instrument
artifact: show-dependencies is itself exponential, so my probe tool reproduced the symptom
it was probing for.

## Patterns and Root Causes

The night's deepest pattern: **diagnosis was the expensive good, not fixes**. Every fix
was minutes once understood (a .git suffix, a visited set, a computed property); the cost
was recognizing WHICH silent-spin was which. Three sub-patterns follow. First,
inherited-handoff framings are premises to re-verify, not facts ([HANDOFF-016] applied to
performance claims, not just state claims) — "cold resolves are 20-60 min" was true for
one cause and catastrophically wrong for another with the same symptom. Second, the
instrument-trap: a diagnostic tool has its own complexity envelope, and when tool and
subject share a failure mode, the tool's verdict is circular — [REFL-011]'s tool-reach
extension needs a sharper corollary: verify the TOOL terminates on a known-good input of
the same scale before trusting its verdict on the suspect input. Third, outward-action
gates must key on queried VALUES, not command exit codes — `gh repo view ... && git push`
pushed on "the query succeeded" when the intent was "the answer was private."

The multi-session choreography (this session as coordinator; master + terminal + investigator
as executors; inbox/handoff-relay as the only channel; single-writer edit zones) is the
scaled version of the supervise skill's principal-agent model and it held under real load —
worth codifying if a third such day occurs. The bounded-cache adjudication reconfirmed an
old truth: recency of local work is not evidence of canonicity; the git-archaeology (who
carries the heritage commit, whose config matches fleet standard) decided it in minutes.

## Action Items

- [ ] **[skill]** swift-package-build: add the hang discipline — any build >20 min is a
  hang until proven otherwise (probe: zero child processes, single ~99% thread, no .build
  writes); gate verdicts come from `swift build` only, never `swift package
  show-dependencies` (independently exponential); include the identity-conflict signature
  and the §A26 dossier pointer.
- [ ] **[skill]** issue-investigation: add the instrument-trap rule — before trusting a
  diagnostic tool's verdict on a suspect input, verify the tool terminates on a known-good
  input of the same scale; when tool and subject can share the failure mode, the verdict
  is circular (provenance: show-dependencies falsely "ruled out" spelling dedup overnight).
- [ ] **[skill]** supervise: outward-action gates (pushes, visibility-dependent operations)
  MUST branch on the queried value, not on query-command success — `cmd && push` fires on
  exit-0 even when the answer forbids the push (provenance: Issues public-push incident,
  retroactively granted 2026-07-10).
