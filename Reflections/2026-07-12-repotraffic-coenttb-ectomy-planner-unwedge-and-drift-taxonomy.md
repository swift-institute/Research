---
date: 2026-07-12
session_objective: Eliminate every coenttb/* dependency from the repotraffic app's closure at the source (manifests + code), then build, boot, and smoke the app
packages:
  - swift-stripe
  - swift-stripe-live
  - swift-email
  - repotraffic-com-server
status: pending
---

# Repotraffic coenttb-ectomy: planner unwedge, the drift-class onion, and ENOSPC gate-poisoning

## What Happened

Focused evening seat (20:20–21:10) executing CHARTER-repotraffic-ectomy-2026-07-12.
All three coenttb edges in the app closure were cut at the source and pushed:
swift-stripe:202 `coenttb/swift-authenticating` → institute swift-url-routing
`Authenticating` (78227a5, + platform floors 95c00e3); swift-stripe-live:286
`coenttb/swift-environment-variables` → `ServerFoundationEnvVars` with the
`.live()` requiredKeys drift adapted (553f768, + a pre-existing mangled-import
fix 42a57c3, target gate green); swift-email's builders cut (predecessor WIP
1fb478a) completed by parking the pf-html-era surface to `Parked/Email/` with a
restoration README, normalizing floors .v14→.v26, and covering the surviving
StringBuilder with tests (be59dce, fully green). The app's identities-mailgun
dep was gated W1-style (1192aef). Post-ectomy: Package.resolved = 304 pins,
coenttb=0, pointfreeco=0.

The headline: the afternoon's build-planner wedge (1h35m at 100% CPU; xcodebuild
escape also wedged) was root-caused BY the ectomy — the two coenttb TAG pins
(@0.1.2/@0.1.3) carried frozen manifests with unmirrored
`pointfreeco/swift-dependencies` URL edges → the catalog §A26 identity-conflict
path-enumeration hang. Post-cut: full resolve ~6 min, build-plan ~90 s, and the
entire ~300-package institute graph compiled green in ~7 min at -j8. The halt
moved into the app's own sources, where the import-level census (greps, not
serial rebuilds) produced the migration wave's work order: `import Records` ×~50
files (no declared dep vends it; swift-records rejected as home — it carries
coenttb + 2 pointfreeco edges), `Identity_Standalone` ×14, retired
`EnvironmentVariables` ×5, boiler API deltas across 81 importing files.
Boot+smoke honestly missed: the app was mid-surgery before the seat existed.
Two carry-forward wave charters sketched in the close report (ledger 21:10:28).

Mid-run: a disk-full incident (~20:45, 129 MB free of 926 GB) poisoned two
running gates; freed 21 GB by deleting two dead DerivedData trees; both
verdicts re-derived, neither trusted. Also answered a mis-routed principal
question by verifying the design-forge decomposition brief from disk (INT-1..4
package list present; execution ⚑-gated).

HANDOFF scan at session end: 0 loose root handoffs; `.handoffs/` store guard
red at 89>40 — the documented-by-design overage (per-arc drains at arc close);
this seat's charter is LIVE pending supervisor release, outside retire
authority. Memory guard OK (2 fresh inbox entries added: third-strike
undeclared-import class; ENOSPC gate-poisoning gotcha). No `/audit` this
session.

## What Worked and What Didn't

Worked: census-before-cutting ([HANDOFF-021]) — the predecessor's bequest was
accurate but the [HANDOFF-016] re-verification surfaced the bigger truth (the
Records gap dwarfed the bequeathed identity bomb) BEFORE any build was burned
on it; the ASK(supervisor) with full census landed exactly at the
design-authority boundary and was approved verbatim. Import-level greps as the
inventory instrument (unmasked, complete) instead of serial per-target builds
([PKG-BUILD-016]/[PKG-BUILD-020]) — the honest scope in seconds. Works-first
parking with restoration READMEs + zero-consumer verification before each park.
Compound watches never judged on silence; the one fast-fail (build #1, 90 s)
was read as the planner-unwedge datum it was.

Didn't: (1) I pinned the first gate to TOOLCHAINS=6.3.2 against a fleet
normalized to tools-version 6.3.3 — the workspace contract explicitly allows
the newer patch as default; one gate cycle burned. (2) Platform-floor drift was
discovered serially (swift-email, then swift-stripe two builds later) — the
closure-wide floor sweep I eventually ran should have fired at the FIRST
instance; it found the second-and-last blocker instantly. (3) Nobody (me
included) checked disk headroom before stacking three compile gates on a
98%-full volume; the ENOSPC failure mode was expensive to classify the first
time because compiler "fatal error" output looks like a source verdict.

## Patterns and Root Causes

**Legacy tag pins are identity-conflict carriers, not just staleness.** The
planner wedge was never graph size — it was `from:`-resolved TAGS whose frozen
manifests still spelled retired third-party URLs. A tag pin is an immutable
manifest snapshot: every retired-org or unmirrored URL it carries re-enters the
closure invisibly, and mirror-substitution (exact-string) cannot reach it. This
is [PKG-DEP-010]'s "old-tag graphs" clause made concrete: the cheapest census
for a planner hang is `jq` over Package.resolved for non-institute locations,
before any process sampling.

**Fresh-main drift is an onion with a fixed layer order.** Product-rename
errors (build-plan) mask platform-floor errors (build-plan) mask namespace-
semantics errors (compile: `HTML` protocol → WHATWG_HTML namespace) mask API
drift (compile: RFC_5322 typed Header.Name, init arg order, `.render()` →
`String(message)`). Each layer is invisible until the previous one is peeled,
so scope estimates from any single build are lower bounds — but GREP-level
census cuts across all layers at once for the import-shaped classes. The
sweep-on-first-instance rule (when error class X appears once, sweep the whole
closure for X before rebuilding) converts serial discovery into one cycle.

**A full disk turns every gate into a liar.** ENOSPC surfaces as compiler
"fatal error encountered during compilation" + SwiftPM "malformed target info
JSON" — both read as tool/source defects. Gate discipline needs a `df` pre-check
the same way it needs `swift package update` first; and any verdict obtained
while the volume was full is not a verdict ([REFL-011] tool-reach: the tool's
reach didn't include "disk had room").

## Action Items

- [ ] **[skill]** swift-package-build: add the ENOSPC failure signature + disk-headroom pre-check to the gate discipline (compiler "IO failure on output stream" / SwiftPM "malformed(json: error: other(28))" are disk verdicts, not source verdicts; re-gate after freeing space) — inbox 2026-07-12 entry has the raw material
- [ ] **[skill]** swift-package-build: sweep-on-first-instance rule extending [PKG-BUILD-016] — on the first build-plan error of a closure-wide class (platform floors, dead product refs), grep the closure's manifests for the whole class before the next build
- [ ] **[package]** swift-email: Parked/Email/* restoration is chartered as INT-4 (swift-email-html); the AppleMail repair drift map (typed Header.Name, date-before-subject, `.render()`→`String(message)`) lives in Parked/Email/README.md
