---
date: 2026-07-13
session_objective: Repotraffic BOOT arc orchestration — UI wave to exe green to boot to one live GitHub traffic pull (mission REPOTRAFFIC RUNNING)
packages:
  - repotraffic-com-server
  - swift-authentication
  - swift-mailgun
  - swift-mailgun-live
  - swift-dependencies
  - boiler
status: pending
---

# Repotraffic BOOT Arc: Runtime DI Topology, Loopback Shadowing, and the Fabricated-Plausible-Value Family

## What Happened

Single orchestrator seat under the workspace supervisor chat, ledger-channel protocol
([SUPER-059..066]) throughout. All four goal conditions met; the arc closed Success
[SUPER-010] at 11:09:40: `com_repotraffic_app` builds exit 0 (Swift 6.3.3 stable lane),
boots against the sprint recipes (three documented amendments), and completed a live
smoke — GitHub account connected, 100 repositories tracked, 100/100 live traffic
fetches completed and stored (89 non-zero; top line clones=17775). Closure
coenttb=0/pointfreeco=0 held at every wave gate (304 pins).

Wave arc: W-1 UI (RepoTrafficUI 1063 error lines → 0 in five per-class commits;
shim triage per the principal's adoption ruling). W-2 exe green (identity gate
`7d66f4b`; presentation + app-owned scaffold `451e879`/`c516481` after overruling a
lane STOP on the charter's own shim doctrine — supervisor countersigned; mop-up
1619 → 0). W-3 runtime — the first true exercise of the natively-ported persistence
and DI stack: five boot fatals fixed serially, then the request-scope discovery
(app-level `withDependencies` does not reach NIO request tasks), then an app-wide
DI-accessor sweep (8 of 10 Interface/Live domains had the split-conformance defect).
Two supervisor-authorized dev stubs (identity `require`, §A9 Stripe catalog sync)
carry loud markers and ride the carry-forward register as removal units.

Two incidents, both self-caught and adjudicated in-ledger: an orchestrator push with a
hand-expanded (fabricated) full SHA — failed closed exactly as the SHA-refspec guard
intends, corrected with a rev-parse-substitution standing rule; and one lane `git stash`
on the working tree — reversed lossless, rule restated verbatim in later briefs.

Mid-arc the principal joined live, asked why code was relocating, and ruled: the
Interface/Live module separation is a kept design value; the accessor relocations are
temporary Pass-1 scaffolding; a committed post-boot design round evaluates the durable
idiom. Ruling countersigned and mirrored to `Workspace/inbox.md` by the supervisor.

HANDOFF scan ([REFL-009]): guards run — no loose root handoffs; memory corpus target-zero
OK; `.handoffs/` WIP cap 92>40 is the documented-design overage (drain-per-arc-close
ruling stands; not forced). Files in this session's authority: 1 —
`Workspace/handoffs/CHARTER-repotraffic-boot-2026-07-13.md`, LEFT UNCHANGED (arc closed
Success but the file is live successor inheritance: pending supervisor ANSWER to the
principal-directed how-to-proceed ASK plus the carry-forward register). Lane reports are
session-scratchpad ephemera whose durable content is in the ledger. No `/audit` ran; no
audit statuses to update ([REFL-010] no-op).

## What Worked and What Didn't

Worked: the ledger channel carried 4+ adjudications at ~1-minute latency, one standing
authorization (identity stub, five conditions), two overrule/countersign cycles, and a
live principal ruling — with zero hand-stamps. Per-wave orchestrator verification from
disk (own gates, closure greps, rev-parse remote checks) caught what mattered, including
my own failed push. The corrected-class-map dispatch pattern — orchestrator classifies
errors into named classes with worked-example citations, lanes execute — kept six lanes
convergent; the one lane given no class map for a novel surface (W-2b) drifted into a
wrong-direction recommendation (`@CasePathable`, the banned pointfree macro) that the
class-map correction fixed before dispatch. Coordinator-side monitoring compensated
twice for the known subagent background-task tracking unreliability.

Didn't: the W-2c boot-wiring commit's claim that a `withDependencies` wrap "survives to
request handling" was accepted at face value — falsified a full smoke-layer later. The
claim was compile-plausible and configure-time reads masked it; nothing exercised
request scope until the stub failed to bite. That is the [SUPER-009a] partial-as-full
class on the runtime axis, and the supervisor recorded the acceptance as its own miss
too. Runtime discovery then proceeded serially (invalidToken → sweep) one restart round
longer than needed: the systemic class was *predicted* by the debug lane at 09:47 and
confirmed on the second domain at 10:23 — the whole-scope sweep should have been
dispatched at the second instance, not the third layer.

## Patterns and Root Causes

**One DI class, three presentations.** Institute swift-dependencies resolves a key at
the module where the `Dependency.Values` accessor is declared (static witness tables, no
runtime conformance casts — load-bearing for the Embedded stance). The app's pf-era
topology (accessor + test default upstream, retroactive liveValue downstream) encoded the
pf runtime's dynamic lookup semantics in its file layout. The identical defect presented
as: a hard crash (`fatalError` testValue — Router), a loud unimplemented error (Billing),
and — the insidious variant — a *plausible domain error* (`Account.GitHub`'s default
throws `invalidToken`), where a resolution failure is indistinguishable from a legitimate
bad-token failure and cost a full debugging round. Corollary: witness defaults must fail
as `unimplemented()`, never as domain errors. The same root also produced the
request-scope gap: institute `prepareDependencies` is TaskLocal by design
([API-IMPL-010]), NIO request tasks sit outside `main`'s task tree, so the membrane's
implicit contract is per-request injection at the app's `use:` closure — currently a
hand-rolled wrapper that boiler should probably vend first-class. All upstream questions
are homed in the principal-committed design round (inbox 2026-07-13 ~11:01 entry);
this reflection deliberately does not duplicate them as action items.

**The fabricated-plausible-value family.** The hand-expanded push SHA is the
content-clock drift's git twin: a human-plausible value produced from memory instead of
derived mechanically, passing casual inspection, caught only by a fail-closed mechanism.
Family members now: hand-written timestamps ([SUPER-059], fixed by the stamper),
hand-expanded SHAs (fixed by rev-parse command substitution), loop counters
([REFL-012], fixed by state checks). The general fix shape is identical: derive the
value mechanically at use time; never transcribe from the model's internal sense of it.
The compounding defect — piping a push through `tail` and letting `&&` ride the pipe's
exit — shows `${pipestatus[1]}` discipline applies to *pushes*, not just builds, and
that a ledger claim is a verification statement, not an intention statement.

**The loopback-shadow environment class (three instances, one session).** Host-local
postgres shadowed the docker port mapping on BOTH loopback stacks (::1 and 127.0.0.1);
host redis same on 6379; Vapor binds IPv4-only while curl resolves `localhost` to ::1
first. Root cause in [REFL-011] tool-reach terms: the recipe's preconditions were
verified *container-internally* (`docker exec pg_isready`), which proves nothing about
the host path the app actually takes. Environment probes have reach exactly like
verification tools; a green from inside the container is a narrow tool read as a broad
claim.

**Runtime is a distinct verification surface.** With the test suite parked (accepted
weakening from the RUN arc), compile-green was the only pre-boot signal — and the boot
surfaced four sequential runtime walls that no build could see. The smoke *was* the
arc's test suite, per the weakening's own terms, and it did its job. The generalizable
heuristic: when the same runtime fix class fires twice, dispatch the whole-scope sweep
immediately ([SUPER-063]'s second-instance rule generalizes from ASK classes to fix
classes).

## Action Items

- [ ] **[skill]** supervise: amend conduct.md near [SUPER-052]/[SUPER-054] — push refspecs MUST be command-substituted from `git rev-parse` at invocation (hand-expanded SHAs are the content-clock class's git twin); push exit captured bare, never through a pipe; remote re-verified (fetch + rev-parse) BEFORE any ledger/report "pushed" claim.
- [ ] **[doc]** Workspace/CLAUDE.md Gotchas: add the loopback-shadow row — host services shadow docker loopback port mappings (postgres 5432, redis 6379 observed 2026-07-13); Vapor binds IPv4 127.0.0.1 while curl `localhost` resolves ::1 first; container-internal probes are NOT host-path evidence — probe from the host and target 127.0.0.1 / the en0 IPv4 explicitly.
- [ ] **[skill]** supervise: oversight.md — second-instance sweep heuristic: when the same runtime fix class fires on a second independent site, dispatch a proactive whole-scope sweep instead of continuing serial per-site discovery (generalizes [SUPER-063]'s two-instance grant rule to fix classes; would have saved one restart round this arc).
