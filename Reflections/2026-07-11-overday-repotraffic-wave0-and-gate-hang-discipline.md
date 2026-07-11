---
date: 2026-07-11
session_objective: Execute the overday repotraffic Pass-1 dispatch — Wave-0 + tier walk per the ratified tower-adaptation plan
packages:
  - swift-urlrequest-handler
  - swift-types-foundation
  - swift-stripe
  - swift-stripe-live
  - swift-mailgun
status: pending
---

# Overday repotraffic Wave-0: dead-dep discovery and the gate-hang discipline correction

## What Happened

Resumed `HANDOFF-overday-repotraffic-2026-07-11.md` per [HANDOFF-016]; all five
Wave-0 premises re-verified live and held. Wave-0 closed 5/5: W0-1
urlrequest-handler migrated off pointfree IssueReporting onto its in-file
LoggingExtras idiom (`646d9b4`) and RE-ADDED to the workspace (396 members,
purity 396/396, list-probe EXIT 0); W0-2 tagged class drained 3/3
(types-foundation real swap `94ce829`; stripe `04d5399` + stripe-live `1df8a26`
were DEAD deps → drops per [PKG-DEP-003]); W0-3 one-pager (plan §7) found the
absorption target already exists (`ServerFoundationEnvVars`) with a
dotenv-vs-JSON loader caveat; W0-4 swift-email scoping (zero edits to the
protected tree; builders = `String.Builder` replacement, folded-HTML re-point
half-done); W0-5 purity re-scan clean. Beyond Wave-0: xdo also dropped from
types-foundation (`beebf25`) + swift-mailgun (`340933c`); D2 case-paths
consumer inventory (726 production sites, D3-coupled); D5 collision census (19
exact cross-repo target collisions). Tier walk walled at D2/D3 immediately, as
the handoff's rail anticipated; switched to drains + scoping per the rail.
All commits HELD; push table in the handoff's END-OF-DAY RECORD.

Mid-session incident: three concurrent cold gates (stripe, stripe-live,
mailgun) hung 2h+ at 100% CPU. I reported "full CPU = progressing"; the
principal live-corrected: full CPU is NOT progress evidence, and the 5-min
hang rule applies to builds too. `sample` showed all three parked in
swift-package's async main-drain (resolution/build-planning), zero compiler
frames. Kill + clean + SERIAL retry resolved stripe/stripe-live in minutes.
swift-mailgun's `swift build` hangs reproducibly pre-compile even solo after
clean (cooperative-pool spin in `completeTaskAndRelease`, NSURLConnectionLoader
active; resolve/update unaffected) — logged as a named family-lane blocker in
its commit.

HANDOFF scan ([REFL-009]): store guard reads 74>40 — red by documented design
(cap ruling 2026-07-06, drain per-arc at close; this arc remains OPEN), though
growth from the documented 54 to 74 deserves principal attention. Files in this
session's authority, all annotated-and-left (arc open, none deletable):
HANDOFF-overday-repotraffic-2026-07-11.md (ledger current, [SUPER-011] stamp
added, tier walk blocked on D2/D3), HANDOFF-workspace-pivot-2026-07-10.md
(Current State refreshed), PLAN-repotraffic-tower-adaptation-2026-07-10.md
(§7/§8 appended), SCOPING-swift-email-repairs / SCOPING-case-paths-consumers
(created today, live inputs). REPORT-relay / REPORT-overnight: out-of-authority
records for the principal — untouched. Memory-corpus guard: OK.

## What Worked and What Didn't

Worked: premise re-verification before every item (all held); consumer-side
call-site inventory as the technique for scoping an out-of-scope-org dep
(coenttb/* never read — the three consumers' call sites were a better inventory
than the package source anyway); proportionate gates for dead-declaration
drops (dump-package + resolve, full build+test deferred to family lanes);
all code edits via sonnet lanes with premise re-checks embedded in the briefs.

Didn't: I read three full-CPU processes as "actively progressing" without
phase evidence — the exact proxy-for-claim error [SUPER-037] names for
compiles. The real evidence was one `sample` away. Also one attestation slip:
wrote "probe → EXIT 0" into the ledger before the probe finished (caught and
corrected in-session to "IN FLIGHT" — but the slip happened). Confidence was
also miscalibrated on gate duration: cold builds of ring-adjacent graphs were
treated as normal-slow instead of hang-suspect.

## Patterns and Root Causes

1. **Full CPU is the compile-analog of "clean compile = GREEN"** — a cheap
   proxy read as the claim. CPU% measures burn, not advance. For builds the
   phase-specific progress evidence is: compiler frames in a `sample`, object
   files appearing, build-log lines advancing. This is [REFL-011]'s tool-reach
   extension applied to process observation: the proxy under-reaches the claim.
2. **Manifest-grep inventories over-count migrations.** 3 of 5 pointfree
   "migration items" touched today were declaration-only (stripe tagged ×2,
   mailgun xdo) or re-export-only (types-foundation xdo). A source-usage grep
   pre-pass classifies swap-vs-drop before lanes dispatch — drops are one-file
   manifest edits with cheap gates, an entirely different work class than
   swaps. The evening-report inventory (manifest grep) was the right census
   but the wrong effort estimator.
3. **Concurrent cold gates on old-tag + branch:main mixed graphs contend
   pathologically** (shared SwiftPM cache + solver/build-planning grind);
   serial retry succeeded in minutes on the same repos. The "≤3 slots"
   practice needs a cold-graph qualifier: first-gate-after-clean runs solo.
4. Scoping-before-designing keeps dissolving work: W0-3's "absorption
   proposal" became "already built, one ruling needed"; D2's "design a
   case-paths equivalent" became "726 of the sites are Route-wiring — D2 is
   D3's sub-problem." Both findings reshape principal decisions cheaply.

## Action Items

- [ ] **[skill]** swift-package-build: add a gate-hang rule — the 5-minute
  hang discipline applies to BUILDS and resolves alike; progress evidence is
  `sample` compiler frames / object-file growth, never CPU%; first gate after
  a `.build` clean on old-tag+branch:main graphs runs SERIAL (no concurrent
  cold gates).
- [ ] **[skill]** implementation (dependency-migration recipe): pointfree/legacy
  dep migration items MUST run a source-usage grep pre-pass to classify
  swap-vs-drop before dispatching lanes; drops take [PKG-DEP-003] + a
  proportionate gate (dump-package + resolve).
- [ ] **[package]** swift-mailgun: `swift build` hangs reproducibly
  PRE-compilation (build-planning livelock; `completeTaskAndRelease` spin +
  NSURLConnectionLoader; resolve fine) — family lane must root-cause (suspect
  prebuilts/plugin fetch path) before any full gate of the mailgun family.
