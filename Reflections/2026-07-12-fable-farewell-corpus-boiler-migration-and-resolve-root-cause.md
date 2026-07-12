---
date: 2026-07-12
session_objective: Convert the expiring Fable subscription into a durable 438-package audit corpus, then execute Phase-B (boiler migration, app-resolve root cause, coenttb-ectomy start) until seat retirement
packages:
  - boiler
  - swift-email
  - swift-url-routing
  - swift-dual
  - swift-parser-primitives
  - swift-stripe-live
  - swift-stripe
  - repotraffic-com-server
status: pending
---

# Fable Farewell: Audit Corpus, Boiler Migration, and the Resolve Root Cause

## What Happened

The session ran three distinct mandates on the last day of Fable subscription access.

**Mandate 1 (farewell audit)**: A supervisor charter re-scoped my in-progress plan into the
fable-farewell audit seat. 29 read-only lanes (25 census + 2 depth + 2 adversarial) covered
438 institute packages; Fable synthesized six cluster findings files + Opus wave charters
(W1–W10) + a ranked principal queue into `Audits/fable-farewell-2026-07-12/`. Three principal
rulings on vendor-enum case-addressing landed mid-run (L1 re-home REJECTED → raw-API external
composition probed feasible via a three-module `swiftc -typecheck` probe → external
composition ALSO rejected as unmaintainable → FINAL: attached `@Cases` under a codified
[ARCH-LAYER-015] narrow-edge exception with a swift-dual product split). Endgame: 22/22
attacked findings survived adversarial re-derivation (2 severity/scope corrections, 0
refuted). Close accepted in Success mode.

**Mandate 2 (execution orchestrator)**: A3 wave-charter hardening landed; the inherited
chain4 app build was ruled wedged (supervisor probe) and killed; the ordered xcodebuild
escape ALSO wedged post-checkout — root understanding: xcodebuild-on-a-package embeds the
same libSwiftPM planner that wedges swift-build.

**Principal-preempted endgame**: The principal took the build into Xcode, found boiler red
on fresh mains, and ordered a Fable-direct fix. Boiler went fully green (build 0 /
build-tests 0 / suite passed; commits `e84da17`+`80c6e3d`, push held on the reword gate)
after a ground-truthed migration: `Witness.Key`/`Dependency.Values` renames, throwing
`envVars.baseUrl()/port()`, scoped `prepareDependencies`, the URLRouting namespace-enum
shadowing fix, an eager-encode mount redesign (DeferredResponse deleted), and region-isolation
constraints. In parallel a Fable investigation lane cracked the app's "never resolves"
mystery: duplicate identity `swift-dependencies` via the unmirrored
`pointfreeco/swift-dependencies` URL, carried by exactly the two unlanded W3 stragglers the
corpus had already flagged (FS-17); plus a wipe-retry amplifier (`rm -rf .build` → 10-minute
silent re-clone) and the discovery that Xcode had actually completed resolution. The
principal ruled source-level ectomy over mirror aliasing; swift-email's ectomy got underway
(coenttb/swift-builders dropped, StringBuilder inlined, product renames absorbed) and was
committed honestly as does-not-build-yet WIP (`1fb478a`+`a52a34d`) when the retirement order
landed. Seat retired with the ectomy census in the close report; a fresh
CHARTER-repotraffic-ectomy seat inherits.

**Artifact cleanup ([REFL-008]–[REFL-010])**: Guards run — memory corpus OK (0 topic files,
inbox within cadence); no loose root handoffs; `.handoffs/` WIP cap red (85>40) — the
documented per-arc-drain overage per the standing cap ruling, with tonight's arcs (sprint
succession, ectomy) live; left to arc closes per [REFL-009a] in-flight conservativism.
HANDOFF scan: root files found 0; store files in my authority: my charter ledger
(retained by explicit retirement order as the permanent record — leave), the
`fable-2026-07-12/` census-input pack (worklist/inventory/exports cited by committed corpus
lanes — leave; its draft charter already carries a SUPERSEDED stamp). Sprint handoff +
ectomy charter: supervisor-owned, in-flight — no-touch. Audit statuses: `/audit` was not
invoked; the farewell corpus's finding statuses are wave-managed and nothing tonight
resolved a corpus row (FS-17 remains open with the ectomy seat).

## What Worked and What Didn't

**Worked**: (1) Pre-flattened package exports — recognizing that agent round-trips, not file
sizes, dominate quota cost let 438 packages get audited in ~25 lanes in about two hours.
(2) The census/synthesis split (opus/sonnet legwork, Fable judgment) held up: lane facts were
file:line-cited and survived adversarial attack 22/22. (3) Probe-before-brief: one
three-module typecheck probe settled the case-addressing design space in minutes and remained
the stable evidence base across three ruling reversals. (4) The ledger channel
([SUPER-059..066]) carried ~15 cross-session adjudications at minutes-latency, including two
mid-run design rulings and a clean retirement. (5) The corpus paid off same-day: the resolve
investigation's root cause was a confirmation of corpus rows (FS-17, the purity blacklist),
not a fresh discovery.

**Didn't**: (1) My watch v2's stall clock initialized at its own arm time, blind to the
pre-existing log silence — the supervisor's world-clock read fired 11 minutes earlier; my
implementation encoded belief-at-arm, not observed state. (2) I left a stray `xcodebuild
-list` burning half the machine for ~16 minutes (auto-backgrounded side probe, never
reaped — a [SUPER-065]-shaped miss on my own side probe). (3) The overnight ledger's
"mailgun-types" attribution propagated into corpus row FS-05 until a cross-lane check
corrected it to mailgun-live — transcription-without-re-derivation, exactly the [REFL-011]
class. (4) My mechanical keypath→call-site conversion in boiler made a lazy read eager
(`try boiler.baseUrl`), breaking the test environment — caught by the suite, but the
semantic (property-wrapper reads are deferred; call sites are not) should have been
foreseen. (5) Two skeptic lanes died to auth blips before landing; the third dispatch
carried explicit spaces-in-paths and speed hardening.

## Patterns and Root Causes

**Fresh-main rename waves are the drift class of the day.** Every red surface tonight traced
to producers renaming public products/modules on `main` while branch-pinned consumers rode
along: "Email Type"→"Email Standard", `RFC_5322`→"RFC 5322", swift-html's product collapse,
`DependenciesTestSupport`→`Dependencies_Test_Support`, plus the API-level drift in
swift-dependencies (scoped `prepareDependencies`) and ssf (throwing env accessors). The
pre-tag, branch:"main" pin model makes every producer rename instantly breaking — and the
corpus's doc-drift belt (F3-22) is the same phenomenon on the README axis. The ecosystem has
a consumer-sweep discipline for repo renames ([PKG-NAME-012]) but nothing binds
product/module renames to same-arc consumer sweeps; tonight demonstrates that gap serially.

**A monitor is a state-claim generator, and its epoch must come from the world.** Three
incidents this arc — SwiftPM's buffered logs defeating log-keyed watches (sprint), prebuilt
swiftmodules read as compile progress (sprint errata), and my arm-time stall clock — are one
class: the watch initialized its belief from its own start conditions rather than from
observed world state (file mtimes, artifact inventories). This is [REFL-012]'s
belief-vs-state gap generalized from loop counters to monitors. A watch on a pre-existing
process must anchor its clocks to the process's observable last-activity, not to when the
watcher showed up.

**The advisor–executor pattern closed its loop in one day.** The corpus was built as
judgment-for-later-execution; within hours it was consumed in anger — FS-17 named the exact
manifests behind the resolve wedge before any investigation ran, and the wave charters
absorbed each mid-run ruling with dated supersession notes instead of rewrites. The
additions-not-rewrites discipline (supersession notes stacking three rulings in one decision
doc) is what kept three reversals navigable; the decision doc reads as history, not as churn.

## Action Items

- [ ] **[skill]** supervise: Extend the watch-craft guidance ([SUPER-061]) — a watch armed
  over a pre-existing process MUST initialize stall/fork clocks from observed world state
  (log mtime, artifact timestamps), never from watch arm time; and side probes that load
  full package graphs (`xcodebuild -list`) are registrable long-running processes under
  [SUPER-065], to be reaped like builds. Origin: the 18:29 v2 stall-clock defect + the
  49328 stray.
- [ ] **[skill]** swift-package: Add a product/module-rename consumer-sweep rule adjacent to
  [PKG-NAME-012] — in the pre-tag branch-pin ecosystem, renaming a public product or module
  on `main` MUST sweep manifest-level consumers in the same arc (grep `.product(name:` +
  module imports fleet-wide). Origin: the Email Standard / RFC 5322 / swift-html /
  Dependencies_Test_Support serial breakage, 2026-07-12.
- [ ] **[skill]** implementation: Mechanical `@Dependency(\.keyPath)`→call-site conversions
  change evaluation semantics — property-wrapper reads are deferred to `wrappedValue` access;
  converted call sites evaluate eagerly. Conversions MUST preserve the original laziness
  where the read sat behind a conditional. Origin: the boiler `try boiler.baseUrl` regression.
