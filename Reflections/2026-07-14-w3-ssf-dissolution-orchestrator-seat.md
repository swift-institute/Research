---
date: 2026-07-14
session_objective: Run the Decomposition Wave-3 orchestrator seat — dissolve swift-server-foundation into concern packages with a nine-consumer cascade, under a supervisor ledger channel, overnight
packages:
  - swift-server-foundation
  - swift-clocks-dependencies
  - swift-throttling-dependencies
  - swift-environment-dependencies
  - swift-translating-dependencies
  - swift-translating
  - swift-logging-extras
  - swift-url-routing
  - swift-stripe
  - swift-stripe-live
  - swift-stripe-types
status: pending
---

# W3 ssf Dissolution: the Calibration Case, Orchestrated Over a Ledger Channel

## What Happened

The seat booted gate-held (W2 CLOSED note), ran source-contact verification FIRST per
the standing lesson, and pre-drafted every mint in scratchpad before the gate
discharged. Execution: C1 landed `\.date` on the W1 keystone; mints #6/#7 shipped
(throttling×deps, environment×deps — the latter absorbing the WHOLE legacy EnvVars
surface per ASK-5); the W1-deferred translating extraction executed in full (ASK-6
Option A: keys module + the bound init pair + Date pair + the cycle-forced list-joining
files + 50 tests); C2's dead `\.httpClient` surface was δ-deleted ecosystem-wide with
the NIO edge declared for the binding-no-touch C3 file; C4/C7 transferred with a
shadow-avoiding rename (ConsoleLogHandler) and a whole-file compat-surface landing;
C10 reduced ssf to a marked W3-SHELL. Six consumers were repointed off ssf (verified
manifest+source=0); the S6 pair discharged with the mechanical grant returned unused;
the app oracle ran green twice with zero app edits and the soak alive throughout.
Close accepted as Success with 11/11 SHAs remote-verified.

Six supervisor ASKs were filed and adjudicated at minutes-latency over the ledger
channel; four zone extensions were granted on evidence (boiler file, the four
translating consumers, stripe-types, and — declined-by-gate — mailgun-types). The
harness's auto-mode classifier blocked public pushes from this seat; the supervisor
executed them from its own pre-approved session under a "PUSH-QUEUED" ledger protocol
that worked on first use and for all ~15 subsequent pushes.

HANDOFF scan ([REFL-009]): 0 root handoff files; guards clean (memory target-zero,
inbox within cadence). The W3 charter in `Workspace/handoffs/` is the closed arc's
terminal record (close report + acceptance on its own ledger) and stays for the
morning review per the per-arc-drain cadence — out of this session's drain authority.
No `/audit` was invoked; no finding statuses to update.

## What Worked and What Didn't

**Worked.** (1) Gate-held recon converted dead waiting time into the source-contact
verification that reshaped five concern rows before any edit — every ASK the
verification pre-filed was answered before the gate discharged. (2) The build gates
were the arc's ground truth: the supervisor's greps misfired nine times (wrong module
spelling, wrong package, comment-substring matches, -A1 truncation); the gates were
wrong zero times. "Gate outranks grep" — enforced twice against the supervisor's own
recommendation (mailgun-types deletion declined; the module-locality rule emerged from
that decline). (3) Stopping was load-bearing: five STOPs (mailgun-types, Web Elements,
the S6 pair twice, the R-a rider contradiction) were each harder than proceeding and
each correct. (4) The Option-A shell pattern did exactly its job — auth gated green
UNCHANGED, and the app never noticed the dissolution.

**Didn't.** (1) The C8 thin missed `ProjectRootKey.swift` because the file lived in a
different TARGET than the concern's named target — file-scoped thins verified
target-scoped would have caught it; a consumer gate caught it instead (cheap, but
late). (2) One `git add -A` in swift-records slipped through before the supervisor's
dirty-`.env` finding hardened the explicit-paths constraint — the commit was clean by
luck, not by discipline. (3) A full-suite `swift test` on swift-mailgun fired four
REAL Mailgun API calls (live-class tests hiding in a non-`-live` package) — the
hermetic-only rule was honored in intent but the package's naming lied about its test
classes; the only outbound effects were server-rejected 400s and an empty reset suite,
verified from source without re-firing. (4) My first bulk-respell scripts used
exact-string asserts that broke on whitespace variants and computed-var manifest
shapes twice; the Edit-tool-with-verified-context path was more reliable than heredoc
string surgery.

## Patterns and Root Causes

**The night's dominant pattern: invisible transitive surface made visible.** Four
independent defect classes — `\.projectRoot` duplicated across targets, v1–v5 constant
copies in stripe-types, ~51 files riding types-foundation's `@_exported` Foundation,
and `\.uuid` tunnelling from an S6 module into stripe's view layer — are ONE
underlying phenomenon: `@_exported` re-export chains let coupling accumulate without
declaration, and only a dissolution that severs the chain forces the coupling into
manifests and import lines where it can be seen. This is the empirical backbone for
the [MOD-040] carve-out case; the R-c inventory numbers (3799→3813, a deliberate
temporary loan) plus these four exhibits belong together in that argument.

**Blast-radius direction inverts on visibility raises.** The cascade plan swept the
SOURCE package's consumers (ssf's), which is correct for moves that keep visibility
constant. C7 RAISED package-access constants to public in the destination module —
and the breakage surfaced in the DESTINATION's consumers (url-routing's), two of which
were never ssf consumers at all. A census keyed to key-READERS also missed consumers
of moved MEMBERS (labeled inits, conformances) — the [HANDOFF-040] wide-form lesson
recurring at arc scale. Both are sweep-scope rules, mechanical once stated.

**Module-locality, not access level, decides duplicate-symbol behavior.** stripe-types'
package-access v1–v5 COLLIDED with the canonical publics (call sites in sibling
modules: both candidates arrive cross-module and compete); mailgun-types' public v2
SHADOWED them (call sites in the declaring module: module-local wins). The supervisor
predicted both would collide; the gate falsified half the prediction, and the
resulting rule is now stated precisely enough to be a skills-grade mechanic.

**A charter line is an instruction, not a law of physics.** Rider R-a's parenthetical
("+ the donor's no-op trait") was authored before the app-freeze constraint existed;
following it literally would have broken the frozen production app's next resolve —
SwiftPM rejects a `traits:` argument against a trait-less package, a fact proven
earlier the same night by an unrelated flake. Reading riders literally, checking them
against standing constraints, executing the safe part, and surfacing the contradiction
was endorsed as the correct seat conduct. The general form: instructions age;
constraints compound; the seat owns the consistency check at execution time.

## Action Items

- [ ] **[skill]** swift-package: extend [PKG-DEP-012] — when a move RAISES a symbol's
  visibility (package/internal → public), the same-arc consumer sweep scopes to the
  DESTINATION module's consumers, not the source package's; and sweeps MUST grep moved
  MEMBERS (argument labels, conformance uses), not only key-reader forms.
- [ ] **[skill]** modularization (imports.md): document the module-locality rule for
  duplicate declarations — a duplicate in the same module as its call sites SHADOWS
  the imported canonical (no diagnostic); a duplicate in a sibling module COMPETES
  (ambiguity error) regardless of access level; with the stripe-types/mailgun-types
  pair as the worked example.
- [ ] **[skill]** supervise (dispatch.md): charter riders authored before later-added
  constraints can contradict them — the seat MUST verify each rider against the
  charter's own standing constraints at execution time and surface contradictions
  (execute the safe part, hold the unsafe part), with the R-a no-op-trait/app-freeze
  near-miss as the worked example.
