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

## ADDENDUM 2026-07-23b — combined TypesFoundation + ssf edge-cut confirmation

Principal directive (Opus session): schedule full TypesFoundation removal (incl. from
ssf) and ssf removal; "could very well be an edge cut — trust prior adjudication if it
exists." It exists (ssf: Decomposition Wave-3, 2026-07-14, Reflections/2026-07-14-w3-ssf-
dissolution-orchestrator-seat.md; TypesFoundation: W2). Two fresh censuses (types-foundation
+ ssf) at main confirm and refine:

**TypesFoundation = pure edge-cut.** Zero original code (exports.swift only). SOLE live
consumer = swift-server-foundation (Package.swift:54,77 dep + exports.swift:22
`@_exported import TypesFoundation`). repotraffic: ZERO hits. identities-types ref is
commented-dead. → C10 removes the last manifest consumer.

**ssf = consumer edge-cut DONE, archival GATED on 3 parked originals.** No ecosystem
Package.swift depends on ssf (manifest edge-cut already complete ecosystem-wide;
repotraffic repointed to swift-urlrequest-handler at Package.swift:211). But ssf is NOT
an empty shell — 3 TRUE originals are intentionally parked by the Wave-3 adjudication:
- `MainEventLoopGroup` (Sources/ServerFoundation/EventLoopGroup.swift:6) — DI co-location
  constraint (di-composition-root-design §4.3 rule 2).
- `InMemoryStore` (InMemoryStore.swift:14) — W3-PARKED C5, header: stays pending the
  swift-time-to-live stub population (principal ⚑); Any-erasure defect dropped at the fill.
- `URL.canonical` + `URLCanonicalError` (URLOptional.canonical.swift:12,20) — W3-PARKED C6,
  header: home is the swift-uri fill (RFC 3986 canonicalization), ASK-3 ruling 22:41.
Remaining ecosystem `import ServerFoundation` sites: 1 active in coenttb/boiler example
(hands-off, likely dead like repotraffic's — unproven) + 1 dead commented import in
repotraffic. `-vapor` companion (pkg swift-server-vapor): zero ssf edges, not a consumer.

**C10 branch state:** `c10-umbrella-deletion` tip 5e5deca, +1 over main (92b196d); touches
only Package.swift + ServerFoundation/exports.swift; removes the swift-types-foundation dep
+ `@_exported import TypesFoundation`. On main TODAY the TypesFoundation edge is STILL PRESENT.
Branch note: "branch-held for the RepoTraffic gate."

### Derived schedule (from trusting the prior adjudication — no new principal decision needed)

1. **repotraffic app cutover → green** (spawned compile session, task chip). This IS the
   RepoTraffic gate. The macro-plugin/module-cache failure is the current blocker.
2. **Merge C10 to main** once repotraffic compiles green (gate = green consumer, not merely
   repointed). Drops ssf's swift-types-foundation dep + `@_exported`. After this: TypesFoundation
   has ZERO manifest consumers; only its URLRouting/URLRoutingTranslating linkage stub remains,
   gated on the app cutover (step 1).
3. **Archive TypesFoundation shell** (W-3-STUB) once step 1 kills the linkage stub — principal-gated
   archival; tombstone→archive per prior DECISION.
4. **ssf stays a MINIMAL RESIDENCE package** holding the 3 parked originals. Full ssf archival is
   NOT in this arc — it is gated on the downstream fills:
   - swift-time-to-live fill → relocate InMemoryStore (principal ⚑ — fill not yet scheduled).
   - swift-uri fill → relocate URL.canonical (design item — fill not yet scheduled).
   - MainEventLoopGroup → its DI home (co-location constraint).
   These fills are the real ssf-archival unblockers; track as their own future arc, not here.
5. Prove/remove the coenttb/boiler example `import ServerFoundation` (hands-off; owner-adjudicated).

### Fills SCHEDULED 2026-07-23b (principal: "schedule those two package fills") — overnight

Both fill targets EXIST (fills, not repo creation): swift-time-to-live + swift-uri /
swift-uri-standard (all under swift-foundations/swift-standards). Dedicated boot-and-hold
sessions spawned (task chips):
- swift-time-to-live fill (task #16) → typed TTL store, drop InMemoryStore's Any-erasure at
  the fill, then relocate ssf InMemoryStore out. Phase-2 relocation on lead GO.
- swift-uri fill (task #17) → RFC 3986 §6 canonicalization (law in swift-uri-standard if
  Foundation-free; URL convenience in swift-uri FI), then relocate ssf URL.canonical out.
- MainEventLoopGroup (3rd parked original) → DI-home adjudication folded into the grab-bag
  edge-cut execution session.
Net: ssf archival is now SCHEDULED (not deferred) — it completes once #16 + #17 land their
Phase-2 relocations and MainEventLoopGroup finds its DI home, after which the ssf shell is
empty and archival is a principal-gated action.

Net: the "removal" the principal asked to schedule is, for the immediate arc, (1) repotraffic
green → (2) C10 merge → (3) TypesFoundation archival. ssf archival is a LATER arc gated on two
package fills that do not yet exist; trusting the prior adjudication means ssf remains as a
minimal residence package until then, exactly as its own headers instruct.
