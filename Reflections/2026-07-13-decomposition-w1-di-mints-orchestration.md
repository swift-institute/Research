---
date: 2026-07-13
session_objective: Orchestrate Decomposition Wave 1 — mint four private DI-/integration packages from four disjoint L3 donors, thin each donor, migrate consumers, keep every touched package and the app oracle green
packages:
  - swift-clocks-dependencies
  - swift-dependencies
  - swift-async
  - swift-stripe-live
  - swift-github-live
  - swift-url-routing-form-coding
  - swift-url-form-coding
  - swift-stripe-types
  - swift-identities-types
  - swift-sql-dependencies
  - swift-sql
status: pending
---

# Decomposition Wave 1: DI-Integration Mints, Two Structural Deferrals-Averted, and the Trait Cushion

## What Happened

Fresh orchestrator seat under the two-tier model, chartered by
`Workspace/handoffs/CHARTER-decomposition-w1-di-mints-2026-07-13.md` (its RUN LEDGER
is the complete channel record). Four rows: extract the in-package integration modules
from swift-dependencies (M7), swift-translating (M5), swift-url-form-coding (M6), and
swift-sql (M2a) into four pre-created private repos.

Outcome: three rows complete end-to-end (R-1 `swift-clocks-dependencies` c5e9f17,
R-3 `swift-url-routing-form-coding` 72bc267, R-4 `swift-sql-dependencies` 482684e —
each mint standalone-green, donor thinned green, consumers re-pointed green, all
pushed under guards), one row (R-2 `swift-translating-dependencies`) deferred to
Wave 3 by supervisor adjudication with its complete concern manifest delivered as the
W3 work order. Both app oracles green (full build 970s after R-1; combined 141s after
R-3+R-4); zero app edits; the S6 package swift-identities-types received exactly one
13-line mechanical commit under an explicitly amended supervisor grant. M2b stayed
parked. One process erratum (a push batched before its closure-guard read) was
self-reported, verified benign, and its corrective (read-then-push as separate
commands) ratified and applied.

Artifact cleanup per [REFL-009]: no root `HANDOFF*.md` files; `check-memory-corpus.sh`
clean (zero topic files, inbox within cadence); `check-handoffs.sh` red on the
`.handoffs/` WIP cap (108>40 — the documented red-by-design overage under the standing
per-arc-drain ruling) and 6 filename-terminal residents, all E-program files owned by
a live sibling arc — out of this seat's cleanup authority, left untouched. This seat's
own charter stays in the store as the arc record per the supervisor's close ruling.
The Workspace repo's uncommitted charter-ledger appends are the shared channel file —
left for the supervisor seat per [REFL-016] (shared-file, multi-writer).

## What Worked and What Didn't

Worked: source-contact recon before every row. The inventory's rows M5 and M6 both
failed on contact — M5's "low churn one-module extraction" hid DI coupling in the
donor's flagship public API plus transitive S6/app reach, and M6's concern turned out
to have a second host (swift-url-routing carries an internalized near-verbatim twin of
the form-coding integration, same doc text). Rendering the evidence with options and a
recommendation got minutes-latency supervisor rulings every time; no ASK sat
unanswered. The INT-1..4 precedent ledger was load-bearing: the standing
skills-compliance self-check gate, the family naming template, and the Witness.Key
explicit-`typealias Value` gotcha all transferred directly and prevented repeat
drift-corrections.

Also worked: the no-op-trait cushion. The app passes `traits: ["Clocks"]` to
swift-dependencies; dropping the donor's trait declaration would have broken the app's
resolve (an out-of-zone edit). Keeping a declared-but-referent-free trait with a
TEMPORARY marker let the app and five trait-only consumers stay untouched and green —
the charter's marked-re-export cushion generalized to the SPM trait mechanism.

Didn't work: my first test hosting for the clock key (extension-hosted suite on
`Dependency.Values`) compiled as source but failed in the `@Test` macro expansion —
and my first Unit test encoded a false premise (that a bare test runs in test mode),
costing a real 60-second sleep before failing. Also the one guard-sequencing erratum:
batching a closure-grep and a push in one command means the guard cannot gate the
action; and that same over-broad grep (Sources prose rather than dependency closure)
false-positived on sanctioned heritage-attribution URLs.

Confidence was lowest, correctly, around cushionability: both R-2 and R-3 initially
looked like the charter's re-export cushion could cover out-of-zone consumers, and in
both cases the cushion turned out to be structurally impossible.

## Patterns and Root Causes

**Cushionability is decidable before chartering, and it is the real feasibility test
for overnight extraction.** A donor-side compat cushion (re-export target or no-op
trait) requires donor→mint; an integration mint almost always has mint→donor; so a
re-export cushion is cycle-forbidden ([MOD-032]) exactly when the donor itself — or an
untouchable consumer — still needs the moving surface. R-1 was overnight-safe because
the app needed only the *trait*, which can be cushioned without any dependency edge.
R-2 was structurally blocked because the donor's own public API consumes the moving
keys. The general rule: enumerate (a) donor-internal consumption and (b)
untouchable-consumer reach FIRST; if either is non-empty and the mint depends on the
donor, the row is not an overnight row. This is a one-grep-plus-one-manifest-read
check that would have re-classified M5 at inventory time.

**Duplicated integrations drift silently and were found three times in one day**
(url-routing's form-coding twin here; two more by sibling arcs). The root cause is the
pre-[MOD-014]-tightening era: a package internalizes a bridge for convenience, the
provider keeps its own copy, and nothing forces convergence. Both copies compile
because Swift's shadowing rules let direct imports win over transitive ones — so the
duplication is invisible until someone greps. The mint-first doctrine is the fix, but
the census habit (grep the RECIPIENT for the concern, not just the named donor) is
what actually catches existing twins.

**The @Test macro re-emits type paths as spelled, which creates a new
[SWIFT-TEST-003] host class**: a non-generic struct reached through a typealias nested
in a generic type (`Dependency.Values` = `Dependency<...>.Values` →
`__DependencyValues`). Sources compile; the macro's emitted
`Dependency.Values.Test.Unit.self` cannot infer the outer generic parameter. The
parallel-namespace (b) form is the escape, and dots in raw identifiers are fine (the
`Buffer.Ring Tests` precedent).

**The institute DI system has no ambient test-mode detection** — a bare `@Test` runs
in live mode, unlike the pointfree ancestor. The un-overridden `\.clock` slept a real
60 seconds inside a test. Every consumer porting pointfree-era tests will hit this
class; tests must either apply a `.dependency`/`.dependencies` trait or enter
`withDependencies(mode: .test)` explicitly. Whether ambient detection SHOULD exist is
a design question now on the principal's DI agenda.

**Inventory rows decay between authorship and execution** (M2b's destination archived
hours after the plan's ✓exists check; M5/M6 falsified on source contact). The plan's
existence checks verified the wrong properties — existence, not archive-state; module
presence, not coupling. The morning plan amendment (supervisor-routed) mandates
source-contact verification at every wave boot, which this seat modeled.

## Action Items

- [ ] **[skill]** testing-swiftlang: Add the generic-nested-typealias host class to
  [SWIFT-TEST-003]'s host-class table — non-generic struct via a typealias nested in a
  generic type (`Dependency.Values`): sources compile, `@Test` macro expansion fails on
  "generic parameter could not be inferred"; parallel-namespace (b) is the remedy
  (evidence: swift-clocks-dependencies gate #1, 2026-07-13).
- [ ] **[skill]** modularization: Add a cushionability pre-check companion to
  [MOD-014]/[MOD-033] — before chartering an extraction whose consumers include
  untouchable packages, verify a donor-side cushion is structurally possible
  (donor→mint edge must not complete a cycle; a referent-free SPM trait is a sanctioned
  cushion for trait-only consumers, per the swift-dependencies no-op-Clocks precedent).
- [ ] **[research]** Should the institute DI system detect test context ambiently
  (bare `@Test` currently resolves liveValue)? Worked example: un-overridden `\.clock`
  sleeping a real 60s in a test; weigh against Witness.Context's explicit-mode design
  and the pointfree ancestor's detection behavior.
