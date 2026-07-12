---
date: 2026-07-12
session_objective: >
  Dual-seat Fable-exit session: (1) convert the Pass-2/deferred design stack
  into ratification-ready decision documents; (2) repurposed mid-day as the
  repotraffic sprint orchestrator (app build → boot → live GitHub traffic
  smoke by hard close).
packages:
  - swift-url-routing
  - swift-server-foundation-vapor
  - boiler
  - swift-institute (Skills)
  - repotraffic-com-server
status: pending
---

# Fable Dual-Seat: Ratification Corpus + Sprint Orchestration

## What Happened

Seat 1 (fable-pass2, 09:43–13:08): produced 12 documents in
`Workspace/handoffs/DECISIONS-pass2/` — the 9-item charter stack, a
principal-correction rework of item 1, a corpus re-audit, the three
supervisor design briefs (@Cases real KeyPaths, multipart boundary,
Sendable strategy), and the Fable-exit package review (7 gaps). One
principal design correction landed mid-run and OVERRODE the shipped
item-1 recommendation (L2→L3 re-home REJECTED; corrected to L2-purity
via dependency dissolution). Under a one-item rails extension, the
correction's principle was canonicalized as **[ARCH-LAYER-014]** in the
swift-institute skill ("layer identity follows essence; dependencies
conform to the layer, never the package to its dependencies").

Seat 2 (sprint-repotraffic, 13:08–16:58 close): fought the app's
resolve/build to the compile threshold. Shipped: ssf-vapor's
pointfreeco/vapor-routing DISSOLUTION (native Vapor bridge port;
standalone gate 252→40→2→0 errors across four grant instances), boiler's
coenttb/swift-web-foundation DISSOLUTION (disjoint swift-crypto 3.x/4.x
solver conflict — impossible to reconcile by ranges), platform-floor +
tools-version fleet normalization on both, the app's missing-boiler-dep
manifest fix (four targets imported an undeclared module), and a
scope-cut of the marketing executable under a standing order. Done
definition NOT met (no binary by close); succession plan ledgered — the
farewell seat inherits the running build, a verbatim boot recipe
(Postgres/Redis pre-provisioned), and a pre-endorsed smoke plan.

Channel: ~14 ledger ASK/ANSWER exchanges at ~1-minute latency across
both seats; two standing class grants minted per [SUPER-063] and used;
all entries via the mechanical stamper.

HANDOFF scan ([REFL-009]): guards run — memory corpus clean (0 topic
files, inbox within cadence); zero loose root handoffs in any session
repo; store at 83 live > cap 40 (report-only guard) — red-by-design per
the standing cap ruling: this session's two arcs are both legitimately
undrainable (fable-pass2 charter + 12 DECISIONS-pass2 docs are LIVE
ratification inputs pending principal ⚑ glances; the sprint ledger is
INHERITED in-flight by the farewell seat — no-touch per [REFL-009a]).
Both drain at their arc closes per the per-arc pattern. Files scanned:
2 session ledgers (both annotated-in-place by their own close entries,
left in store); 0 deleted; no audit findings touched this session.

## What Worked and What Didn't

Worked: evidence-first decision documents (every claim carried a fresh
probe; the supervisor's countersigns cited the evidence shape as the
reason for fast approval). The static pre-check of VaporRouting's
source against the rewrite's compat surface proved incompatibility
~20 minutes before the compiler would have — converting a build-wait
into parallel patch-preparation. The ledger channel with mechanical
stamps caught MY OWN content-clock drift twice (T7 class) — the stamps
functioned as designed, against the writer.

Didn't: three premature build kills across two seats (mine ×1–2, the
supervisor's morning kills) on the SAME legitimate-silence class —
SwiftPM's ~35-minute single-threaded manifest load looks identical to
the known livelock signature without stack/artifact evidence. One
false-positive progress claim (72 "compiled" modules were PREBUILTS —
downloaded macro-support artifacts, not compilation output); errata'd
within 15 minutes but it briefly inverted the endgame assessment. My
watches died silently with a remote-control disconnect (the [SUPER-060]
failure mode, seat-side): 45 dark minutes until a supervisor nudge. And
the item-1 original recommendation resolved a layering mismatch by
moving the package to match its dependencies — exactly backwards, per
the principal's correction; notable because the whole corpus was built
essence-first and the inversion still slipped through on the one item
where the dependency graph was loudest.

## Patterns and Root Causes

**One-gate evidence, three-gate claims.** The mirror-alias finding
("§A26 already unified via mirrors") claimed resolution-, requirement-,
and source-compatibility from evidence covering only location
unification. The principal's challenge exposed it: mirrors unify
LOCATION; SwiftPM's root-override reconciles REQUIREMENTS; only the
compiler proves SOURCE. Same class as [REFL-011]'s tool-reach
extension — the claim's scope exceeded the probe's reach. The corrected
three-gate framing then paid off immediately: the source-gate was
pre-checked statically and drove the dissolution decision early.

**Belief-vs-state, four instances, one session**: prebuilts ≠ compiled
artifacts (belief from a filename glob); log-silence ≠ no-progress
(SwiftPM buffers non-TTY output — the "COMPILING" detector was
structurally blind); loop/content-clock ≠ wall clock (twice); killed
builds ≠ dead builds (CPU-accumulation + stack samples said healthy).
Every recovery came from a STATE check (stack sample, artifact census
with prebuilts excluded, mechanical stamp, `ps` deltas). The compound
progress signal that finally worked: artifact-growth + log + stack,
never any one alone.

**Corrections compound when the invariant is named.** The 10:49
correction wasn't just an item-1 fix — stated as an invariant ("essence
is the constant; dependencies conform"), it re-prioritized item 8's
burn-down queue, re-grounded item 3's framing, killed a bundling plan
in item 7, reopened the R3 amendment in brief 1, and then EXECUTED
twice in the sprint (both dissolutions are the invariant applied).
A correction captured as a rule ID did a day's work across two seats.

**The channel's economics**: ASK-with-recommendation + site-list +
evidence got ~1-minute approvals; the two standing grants eliminated
per-instance round-trips exactly at the second occurrence
([SUPER-063] fired as written). The honest boundary call (declaring
gate3's drift errors OUTSIDE the minted grant's predicate) cost one
round-trip and bought a widened grant — cheaper than one silent
overreach.

## Action Items

- [ ] **[skill]** swift-package-build: add a rule for large-graph build
      phenomenology — verified-silent vs quiet builds (kill verdicts
      require stack/artifact evidence, not log silence); SwiftPM buffers
      non-TTY progress; `--product` does NOT cut BuildPlan/planning
      cost; `.build/prebuilts/*.swiftmodule` are NOT compilation
      progress. Provenance: this session's three premature kills + two
      watch-model corrections.
- [ ] **[skill]** supervise (channel.md [SUPER-061]): add
      connection-loss (remote-control disconnect) to the enumerated
      session-level events requiring watch-liveness re-verification —
      the seat-side monitors die silently with the session transport.
- [ ] **[research]** SwiftPM manifest-load + planning cost at institute
      scale (~307 packages, ~35 min single-threaded, ×3 measured runs):
      quantify, find the caching/parallelization levers, decide the
      Issues-dossier question (close-report carry-forward row 7).
