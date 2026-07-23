# swift-types-foundation Dissolution Scoping

<!--
---
version: 1.0.0
last_updated: 2026-07-23
status: DECISION
tier: 2
scope: swift-types-foundation + swift-server-foundation + app cutover
---
-->

Principal directive (2026-07-23): "swift-types-foundation is also a grab bag and should be
decomposed." Read-only census at main `211d0c8` (census ran at 18fc6a6 + the in-flight
candidate-2 edge swap, since landed).

## Decisive finding

**The decomposition already happened at source level** (decomposition W2, plan S5,
commits `d833734` "Thin to W-3-STUB umbrella shell" + `2d6bf1b` linkage restore). The
package has ZERO own declarations: one source file (`exports.swift`, 40 lines) that
re-exports 9 foreign modules — including `Foundation` and `FoundationNetworking`
(exports.swift:32,38-40, ambient-interop injection the procedure forbids) — plus two
plain (non-exported) linkage imports of `URLRouting`/`URLRoutingTranslating` (:25-26).
Substantive content was already routed: Tagged parsers → swift-url-routing-tagged,
`ParserPrinter.transform` → swift-url-routing, Sendable conformances superseded.

"Grab bag" today = (a) a 9-module re-export umbrella, (b) an app-visibility linkage
crutch. What remains is a pure **edge-dissolution problem with one gated shell**, not a
content decomposition.

## The gate (must survive until E-4/W3 app cutover)

`exports.swift:18-26`: "W-3-STUB LOAD-BEARING LINKAGE (not re-exported; do not delete
before the APP CUTOVER): the app's modules reach extension members of these two modules
via transitive linkage of this target (pre-MemberImportVisibility member lookup —
oracle-verified 2026-07-13: dropping them broke app-internal WaitingList `.cases`). …
These edges dissolve only when the app's own imports are fixed (E-4 / W3 app-cutover),
not at this shell's C10 removal alone." Manifest twin: Package.swift:21-23.

## Consumers

- **swift-server-foundation** — sole in-scope manifest consumer (Package.swift:17,:54,:77)
  AND onward re-exporter (`ServerFoundation/exports.swift:22` `@_exported import
  TypesFoundation`) — the "ssf C10 umbrella" the gate names.
- **repotraffic** (hands-off): package dep at repotraffic-com-server/Package.swift:158,
  product consumed by **17 targets directly** (:412,:573,:590,:619,:647,:681,:704,:731,
  :886,:919,:928,:990,:1024,:1059,:1110,:1128,:1152) — the app cutover is larger than
  "fix the app's imports"; those direct product edges need repointing too.
- Dead references: swift-identities-types `Identity.Client.swift:12` (commented import);
  swift-authentication comment records completed re-point. coenttb/*: zero hits.

## Recommended candidate A — terminal dissolution, no successor package

Zero new packages. Procedure step 7 and exports.swift:15 ("Do NOT add surface here")
condemn the umbrella essence; a successor curated-prelude is explicitly rejected.

Migration order:
1. **ssf C10**: delete ServerFoundation's `@_exported import TypesFoundation` + its three
   manifest edges; ssf sources get direct deps. Needs the E-4 re-export-dissolution
   inventory (consumers may lean on the double re-export chain — esp. ambient Foundation).
2. **App cutover (E-4/W3, owned there)**: repoint repotraffic's 17 direct edges + fix the
   app's member-visibility imports so the linkage crutch dies.
3. **Only then**: remove the W-3-STUB shell (the gated edges go last).
4. Cleanup: dead identities-types reference; stale README (still advertises
   DateParsing/Builders/CasePaths and coenttb URLs); dead `#if swift(>=6.1) && swift(<6.3)`
   rfc-7578 block (Package.swift:86-92) under tools 6.3.3; stale local
   `Packages/swift-form-coding` symlink (inert after candidate-2 landed; local-only).

Candidate B (interim: strip the 9 re-exports, keep only the linkage stub) is a stage of A,
viable only post-ssf-C10 / pre-app-cutover if that gap is long.

Heritage: umbrella-bookkeeping history only; substantive history already carried by S5
destinations. End-state repo archive/delete/tombstone is an external mutation requiring
its own authorization.

## Open questions for the principal

1. End-state repo disposition: archive vs delete vs tombstone (principal-gated).
2. Does ssf C10 proceed independently, or bundled into the E-4 re-export-dissolution
   inventory?
3. Does E-4/W3 scope already include repotraffic's 17 direct product edges?
4. Should the migration inventory enumerate consumers silently depending on ambient
   Foundation via the `@_exported import Foundation` chain (they break on repoint)?
5. Test target dies with the shell (README-verification only)? (Its paren defect was
   already fixed and pushed at 65e7ab7.)

## DECISION (2026-07-23 — final adjudication under principal delegation)

**Candidate A (terminal dissolution, no successor package) is the plan of record.**
Per-question rulings:

1. End-state repo disposition: **tombstone until the app cutover completes, then
   archive** — archival remains a separately keyed principal action at that
   future point (standing ruling: archival/deletion stays principal-gated).
2. ssf C10 is **bundled with the E-4 re-export-dissolution inventory**: the
   inventory runs first (starting now), C10 executes from its findings.
3. repotraffic's 17 direct product edges **fold into the RepoTraffic gate**
   (handoff task #8) alongside the routing auth change-list — recorded there;
   hands-off until that gate.
4. **Yes** — the inventory explicitly enumerates consumers silently depending on
   ambient Foundation via the `@_exported import Foundation` chain.
5. **Yes** — the test target dies with the shell; nothing to migrate.

Interim guard: no new surface enters the shell (exports.swift:15 directive
stands); candidate B (re-export strip) executes only if the post-C10 →
app-cutover gap proves long.
