---
date: 2026-07-13
session_objective: E-2 read-only research seat — produce the ratification-ready DI composition-root design (DECISIONS-pass2/di-composition-root-design.md) from the repotraffic arc evidence
packages:
  - boiler
  - swift-server-foundation
  - swift-server-foundation-vapor
  - swift-url-routing-vapor
  - swift-dependencies
  - swift-witnesses
  - repotraffic-com-server
status: pending
---

# E-2 DI Research Seat: Boundary Enumeration, Evidence-Pointer Verification, and a Composed One-Design Ruling

## What Happened

Read-only research orchestrator seat for end-state wave E-2
(`CHARTER-endstate-e2-di-research-2026-07-13.md`), on the ledger channel
([SUPER-059..066]) with the workspace supervisor. Boot handshake 14:16:24 →
channel live 14:16:51 → close accepted **Success** 14:39:45 → seat released →
deliverable **RATIFIED by the principal the same afternoon** (STATUS block
updated in-doc by the supervisor session). Total arc: ~23 minutes of channel
time, zero edits outside the deliverable and scratchpad.

Deliverable: `Workspace/handoffs/DECISIONS-pass2/di-composition-root-design.md`
— ONE design composing the three ruled candidates (boiler-vended composition
root `Boiler.execute(dependencies:)` re-applied at every boundary; loud-fail
naming the key on test-default-in-live; `unimplemented()` authoring rule +
two lint candidates) plus a resource-scope rule (root constructs, boundaries
resolve), the §A9 Stripe deferred-sync posture, and a four-wave execution
work order with every scaffold commit git-verified.

Method: two subagent read lanes (ledger-evidence extraction; a boundary
sweep that was scope-widened mid-flight via SendMessage when recon showed the
same-day E-1 cutovers had moved the membrane to
`swift-server-foundation{,-vapor}`) + orchestrator-side source recon of the
resolution mechanics (`Witness.Values.swift:178-181` silent test-default
channel; `Dependency.Key.Strict`; the store-coherence prior art). The
boundary enumeration (14 contexts, 2 landmines) converged across both sweeps
and reproduced both empirically-confirmed injection domains as calibration
cases.

One evidence ASK fired: the charter/supervisor pointer placed the
Redis-storm incident in the BOOT/RUN/STAB ledgers; lane A mechanically proved
absence (STAB closed 12:32:08, before the 13:00 tick). The ASK (four options
+ recommendation, non-blocking) was answered in 3 minutes: the evidence lives
in the **E-1 cutovers ledger** — "your grep discipline caught it; my pointer
was imprecise."

Count reconciliation: the charter's "nine accessor relocations" vs the BOOT
close report's "8 domains" vs commit file-lists (`490c1bc` = 6 domains,
`7759d53` = 3). Commits are primary: the sweep landed 9; the close-report "8"
was an arithmetic slip; three more same-class instances sit outside the sweep
(`12b1519`/`732f36a`/`a587d4b`).

HANDOFF scan ([REFL-009]): no loose root handoffs;
`check-memory-corpus.sh` GREEN (zero topic files). `check-handoffs.sh` RED —
99 live > 40 cap plus 4 filename-terminal residents. Triage: E-2 charter
(mine, case-(b) authority) — closed Success/released/ACK'd, terminal state
self-documenting in its own ledger; retirement to Audits/ left to the
supervisor's per-arc store drain (the store commit is supervisor-owned per
the acceptance entry, the supervisor's watch may still be armed on the file,
and sibling arcs are live) — **annotated-and-left (no annotation needed:
ledger ACK is the annotation)**. E-1/E-3 charters + PROGRAM record: live
parallel arcs, out of authority and in-flight — no-touch per [REFL-009a].
The 99>40 overage is the documented-by-design state under the standing cap
ruling (drain per-arc at close; multiple arcs live today). No `/audit` ran —
[REFL-010] n/a. Scratchpad artifacts (arc-evidence.md, boundary-sweep-b.md,
doc-skeleton.md) are session-scratchpad, self-cleaning.

## What Worked and What Didn't

**Worked.** The channel protocol end-to-end: mechanical stamps only, boot
handshake, two supervisor ANSWERs consumed, one ASK adjudicated without
blocking (parallelizable work continued per [SUPER-064]), close verified by
the supervisor per [SUPER-009] including its own sample re-verification at
source. Lane A's brief explicitly required "report BOTH the claimed count and
what you actually found" — that instruction is what surfaced the 9-vs-8
discrepancy instead of a silent reconciliation. Mid-flight lane widening via
SendMessage prevented a wasted read against arc-era paths. Sample
verification of subagent output ([SUPER-009]: git show on all eight commits,
direct reads of both landmine files) — every lane claim held.

**Didn't (minor, mine).** First grep for the `Boiler` type used
type-declaration patterns (`enum|struct|actor Boiler`) and missed that Boiler
is a *module* — one wasted round. An early multi-glob zsh command aborted on
its first no-match and silently skipped the later globs — the [REFL-012]
no-op-check class; caught only because the output looked truncated. And this
reflection's own index append first shipped at `indent=1` against the file's
2-space convention (6,400 lines of formatting churn) — caught by reading the
commit's diff stats, fixed by amend; diff-stat sanity-checking a structured
-file commit is the cheap [REFL-015] companion.

**Didn't (external, recorded blamelessly).** The supervisor's first evidence
pointer misattributed the Redis-storm ledger. Seat-side mechanical
verification before citing is what kept an unverifiable citation out of a
doc that was ratified hours later.

**Confidence.** High on the boundary table (two independent sweeps converged
+ calibration cases + explicit absence greps for websockets/lifecycle/
timers). The one mechanically-unproven seam — the Queues protocol-refinement
re-scope — is explicitly gated as a ≤1h spike in the work order rather than
asserted ([RES-027] premise discipline).

## Patterns and Root Causes

1. **Evidence pointers are state-claims — even the supervisor's.** A pointer
   to "where the evidence lives" ages exactly like a `Verified:` tag
   ([RES-013a]) and deserves the same treatment: grep the named artifact
   BEFORE citing it in durable output; on absence, ASK with enumerated
   options + a recommendation, and keep working. This is [SUPER-054]
   seat-symmetry running in reverse — the seat re-deriving the supervisor's
   claims. Cost: one grep + 3 channel minutes. Averted: an unverifiable
   citation in a ratified decision doc.

2. **Ledger tallies are loop counters; commits are state.** The BOOT close
   report's "8 domains" was the arc's belief about what happened; the commit
   file-lists were what happened. [REFL-012]'s counter-vs-state distinction
   applies verbatim to arc records: work orders MUST enumerate from commit
   evidence, and extraction briefs should mandate reporting claimed-vs-found
   counts as findings (lane A's did — that's why it worked).

3. **Completeness-critical enumerations want redundancy + calibration.**
   When "missing one = production fatal" (the noon crash was exactly a
   missed-boundary), a single sweep is not evidence of completeness. The
   working shape: two independent derivations (orchestrator recon + dedicated
   lane), named calibration cases the enumeration MUST reproduce (the two
   empirically-confirmed domains), and explicit absence checks for the
   categories not found. Same spirit as [RES-034] parallel verification, but
   for enumeration completeness rather than claim accuracy.

4. **Fix-the-instance vs fix-the-class.** The accessor sweep fixed
   resolution *homes*; the masquerade *authoring pattern* was still live at
   HEAD (`Account.GitHub.swift:43` still throws `invalidToken` as a test
   default). Before a doc claims an incident class open or closed, verify the
   class at HEAD — the incident's fix commit is evidence about the instance,
   not the class.

## Action Items

- [ ] **[skill]** supervise: channel.md — add seat-side evidence-pointer
      verification: grep the named artifact before citing supervisor/charter
      pointers in durable output; on absence, ASK with options +
      recommendation, non-blocking. Extends [SUPER-054]/[SUPER-061]; worked
      example: E-2 Redis-storm pointer corrected 2026-07-13 14:31:44.
- [ ] **[skill]** research-process: codify the completeness-critical
      enumeration gate (two independent derivations + calibration cases the
      enumeration must reproduce + explicit absence checks) as a [RES-*]
      rule; worked example: the E-2 boundary enumeration (14 boundaries, 2
      landmines, noon-fatal calibration).
- [ ] **[skill]** reflect-session: extend [REFL-012]'s counter-vs-state table
      with the arc-record row — "close report claims N items" → verify via
      commit file-lists (`git show --name-only`), never prose tallies; worked
      example: BOOT "8 domains" vs 9 by commits (2026-07-13).
