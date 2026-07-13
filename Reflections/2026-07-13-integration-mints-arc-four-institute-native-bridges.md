---
date: 2026-07-13
session_objective: Create and populate the four approved integration packages (INT-1..4), each green standalone, additive-only, under live ledger-channel supervision
packages:
  - swift-url-routing-authentication
  - swift-url-routing-vapor
  - swift-html-vapor
  - swift-email-html
status: pending
---

# Integration-Mints Arc: Four Institute-Native Bridges, One Mid-Arc Amendment

## What Happened

The seat executed the integration-mints charter (CHARTER-integration-mints-2026-07-12.md)
as the second live arc beside the repotraffic RUN arc: mint four integration packages
from read-only donors, each green standalone, committed, pushed private. All four
closed Success ([SUPER-010], supervisor sample-verified): swift-url-routing-authentication
@ 50df5bd (19/19 tests), swift-url-routing-vapor @ ceddd66 (6/6), swift-html-vapor
@ da90f1e (4/4), swift-email-html @ 151e460 (7/7).

Three structural events shaped the arc:

1. **Mid-arc principal amendment** (charter Common-rules rewrite, ~22:00): the original
   "copied surfaces keep their shapes / cutover is a manifest-only swap" clause was
   superseded by "institute norms govern the whole surface" — donors became semantic
   references, not shape references. INT-1's verbatim-copy first pass was re-derived
   into a two-target shape (Foundation-free `Authentication` core + `Authentication
   Foundation Integration` carrying the native typed-throwing `Authentication.Client`
   and a class-A `Authenticating` compat quarantine per url-routing-native-posture.md).
2. **SwiftPM independently falsified the pre-amendment plan**: the baseline gate failed
   on graph-wide target-name uniqueness (`Authenticating` collides with the donor's
   live target) — the "manifest-only swap" was never structurally possible while the
   donor stays fat. The amendment and the resolver agreed.
3. **Two supervisor drift corrections** (string-descriptor tests violating
   [SWIFT-TEST-002]/[SWIFT-TEST-005]; root cause: testing skills never loaded) were
   absorbed into a standing pre-green-gate skills-compliance self-check that then ran
   clean on all four mints.

FS-01 (the Authenticating silent-`try?` swallow) landed in the new home in the
adjudicated shape: typed-throwing native inits (`Authentication.Error<Failure>`,
.baseURL/.authorization), preconditionFailure only on deliberately-kept non-throwing
legacy conveniences, both paths tested (including two ST-0008 exit tests).

Notable per-mint findings, all banked in the ledger's close entries as cutover work
orders: MemberImportVisibility surfaced a real under-declared dependency
(OrderedCollections through URLRouting's request-data surface) that the donor never
sees; INT-3 was designed-from-demand (no donor carried the HTML×Vapor conformance —
`HTML.Document` lives in swift-html-render's core, conformed retroactively); INT-4's
drift map under-scoped by one package (donor *tests* had drifted against Email_Standard
too); the parameterless `RFC_4122.UUID.v4()` requires the L3 swift-uuids unifier (the
L2 liveValue deliberately traps) and was selected by typed throws against the L2
overload; UUIDs' re-export chain shadows `Swift.String` with the institute String, so
Email_HTML Swift-qualifies internally and deliberately does not re-export UUIDs.

HANDOFF scan at close: no loose root handoffs; `check-handoffs.sh` reports the
documented 95>40 store overage (standing ruling: drain per-arc at close, no forced
re-triage) plus one [HANDOFF-008a] filename-terminal resident
(PROGRAM-repotraffic-endstate-2026-07-13.md) — dated today, owned by the live RUN
arc, out of this session's cleanup authority per [REFL-009]/[REFL-009a]; left
untouched. This arc's charter stays in the store by explicit supervisor ruling (arc
record until the cutover waves consume the delta tables). Memory guard: clean. No
/audit was invoked.

## What Worked and What Didn't

**Worked.** The ledger channel ([SUPER-059..066]) carried the whole arc: boot
handshake, one consolidated ASK with rendered recommendations (answered with both
scopes unheld and pre-adjudications that avoided further round-trips), two drift
corrections, per-mint closes with delta tables, and a clean release. Probe-before-ASK
paid twice — the INT-3 addendum self-correcting a shallow-grep miss (HTML.Document
does exist, in swift-html-render) converted an ambiguous ASK into a confirmable
design, and the supervisor explicitly endorsed the re-probe discipline. The baseline
gate on the verbatim copy, run before the redesign, turned out to be cheap structural
evidence rather than waste: it caught the target-name collision at the moment the
design could still absorb it. Running every mint under the institute upcoming-feature
settings from birth acted as a free audit of copied surfaces (two real findings).

**Didn't.** (1) The seat loaded only the charter-listed skills at boot; the amendment
mandated [TEST-*] conventions and the tests violated them until the supervisor
intervened — the correction's phrasing ("one unloaded skill implies sibling misses")
proved out when the re-pass surfaced the Foundation-in-L3 policy as a second miss the
seat then caught itself. (2) One ledger entry cited INT-2's post-rename HEAD as a
"0e0a1e1-class" placeholder instead of re-deriving the SHA — a textbook [REFL-011]
violation the supervisor caught at verification; the erratum rode the close report.
(3) One gate was launched as a shell-orphaned `&` job inside a foreground tool call,
losing completion-notification semantics; self-caught within a minute and wrapped in
a proper watcher, but it was an unregistered-process near-miss of exactly the
[SUPER-065] class. (4) Confidence was lowest in typed-throws do/catch inference and
Swift Testing exit-test availability; both worked as hoped, but the design leaned on
gate-arbitration rather than certainty.

## Patterns and Root Causes

**Charter skill lists are floors, not ceilings.** The root cause of the arc's only
externally-caught drift was treating the charter's "Skills:" input as the complete
load set. The work's surface classes (tests, README, manifest, source naming) are
derivable at boot from the CLAUDE.md skill-routing map; a mechanical routing-map scan
against the classes the seat will touch would have loaded testing/testing-swiftlang
before the first test file was written. The standing self-check gate the correction
produced is the durable in-arc form; the boot-time scan is the missing complement.

**A resolver probe falsifies design-doc promises for free.** The "cutover is a
manifest-only swap" promise survived two design documents and a charter, and died in
the first `swift build` — SwiftPM's graph-wide target-name uniqueness makes
pre-cutover extraction staging with the donor's module name structurally impossible
whenever the new package depends on the donor. The general shape: extraction-staging
plans should carry a five-minute resolver probe before promising any compat property
the resolver adjudicates. This is [REFL-011]'s tool-reach lesson inverted — here the
tool (the resolver) had MORE reach than the design prose assumed.

**Interop boundaries form a coherent exception family.** Across all four mints the
same posture recurred: Vapor's untyped protocol witnesses, the `Authenticating`
gerund spelling, the compact donor module names, `AppleMail` as a brand token —
each is a [PKG-NAME-003]/[API-NAME-003]-class boundary where external vocabulary
legitimately overrides institute purity, and each stayed quarantined (compat files,
per-file heritage notices, conformance-only surfaces). The posture doc's invariant
("compat is a spelling layer, never a semantics layer") proved directly executable
as a design algorithm, including for code the doc never anticipated.

**Re-export chains are shadow vectors.** The UUIDs → Random → institute-String chain
shadowing `Swift.String` at every consumer import site is a general hazard of
`@_exported` self-containedness: a package that re-exports wholesale also re-exports
its suppliers' namespace collisions. The fix pattern (Swift-qualify internally, trim
the re-export, document why) is the consumer-protecting default whenever a re-export
chain carries stdlib-homonym types.

## Action Items

- [ ] **[skill]** supervise: dispatch.md — add a boot-time obligation for seats: run
      the CLAUDE.md skill-routing map against the surface classes the chartered work
      will touch (source/tests/manifest/README/etc.) and load every owning skill;
      charter "Skills:" lists are floors, not ceilings (origin: 2026-07-12 21:58
      drift correction; standing self-check gate then ran clean 4×).
- [ ] **[skill]** swift-package: [PKG-NAME-014]-adjacent corollary — pre-cutover
      extraction packages depending on their donor CANNOT reuse the donor's target
      name (graph-wide uniqueness); extraction staging plans must pick the native
      module name up front and treat consumer-side moduleAliases as the only
      import-compat cushion (origin: INT-1 baseline-gate collision, 2026-07-12).
- [ ] **[package]** swift-uuids: its re-export chain (Random →institute String)
      shadows Swift.String at every consumer import site; document the shadow in the
      package README and evaluate trimming `@_exported public import Random` so
      consumers opt into the shadow rather than inherit it (origin: swift-email-html
      gate, 2026-07-12).
