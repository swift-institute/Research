---
date: 2026-07-12
session_objective: Overnight orchestration of routing W3 (consumer wave) → W4 (arc close) → tower T3 un-walls, per HANDOFF-overnight-orchestrator-2026-07-11.md, to the /goal completion condition
packages:
  - swift-url-routing
  - swift-dual
  - swift-github-types
  - swift-stripe-types
  - swift-mailgun-types
  - swift-identities-types
  - swift-types-foundation
  - swift-favicon
  - swift-server-foundation
  - swift-cache-primitives
  - swift-environment
status: pending
---

# Overnight Routing-Arc Close: Additive Gap-Fills Worked; Unattended Gates Have Two Blind Spots

## What Happened

A single ~15-hour orchestration session (23:23 → 14:10, well past its
planned 07:30 boundary after the goal arbiter reopened the run) executed
the full staged program: all ten 0.6.x url-routing consumers migrated off
pointfree case-paths/swift-parsing onto the institute rewrite (standalone
green, purity 405/405, pushed rev-list 0); ROUTING ARC CLOSED with a
supervisor-re-scoped W4 gate (sqp carried to the T5 ring on a verified
KeyPath-vs-witness precondition failure); Cache.Bounded born in
cache-primitives behind a [DS-020] compose-first gate; swift-server-
foundation taken from never-green to 65/65; four authenticating-consumer
terminal states (two migration-green, one accepted livelock, one walled).
Five consumer-demand-evidenced ADDITIVE engine changes landed in
url-routing/swift-environment (Optionally, form-route proof tests,
Authenticating conveniences, Sendable pair, dotenv hyphen grammar), each
via the charter's ASK channel, each with tests and full-suite green; the
principal later minted the pattern as a standing class grant.

The coordinator ran gates + git + ledgers only; ~14 opus/sonnet lanes did
all code work. Ten supervisor ASKs were adjudicated in-ledger overnight.
Notable saves: the E2 lane's probe-before-shape reclassified a
"`.form` Body broken" consumer report as tests-only (the engine was never
broken; the real class was bare-sequence composition, fixed consumer-side
with a mechanically-neutral re-spell) — zero engine surgery on a false
premise. Notable incidents: two coordinator clock-drift corrections; an
ASK answered 2.5h before the coordinator noticed (three deliveries); the
mailgun-live full test suite executed 3× against the principal's live
Mailgun account (later verified sandbox-only — luck of the env file, not
gate design); a mega-build gate retired by principal ruling after four
runs produced three distinct infra-corruption classes and zero source
defects; a stripe-live SwiftPM planning livelock (84 targets × 40
products, never exits planning) documented with forensics.

HANDOFF scan ([REFL-009]): guards run — check-memory-corpus OK (zero
topic files, inbox within cadence); check-handoffs VIOLATION 81>40 WIP
cap, known report-only state whose per-arc drain is explicitly the
supervisor's morning job (charter: "do NOT drain the store yourself"),
including the routing-arc rows ruled OPEN. Files triaged: 2 in session
authority — HANDOFF-overnight-orchestrator-2026-07-11.md (annotated
COMPLETE — terminal stamp; retained: consumed by the Stage-B sprint
charter and the morning drain) and HANDOFF-routing-w3-2026-07-11.md
(annotated COMPLETE-BY-SUPERSESSION — its wave closed in the overnight
ledger; retained for the same drain). All other store files
out-of-session-scope; not touched. lane-evidence-w3-overnight/ (15
files) is a labeled drain-fodder archive committed with the ledger.

## What Worked and What Didn't

The additively-on-demand mechanism was the night's engine: five times a
consumer wall became a scoped grant became a green additive commit within
the hour, with the consumer call sites — not the unreadable legacy
package — defining each contract. Confidence in those five changes is
high: each has tests, each was absorbed by every in-wave consumer, and
the supervisor countersigned each. Probe-before-shape (E2) and
compose-first ([DS-020], Cache.Bounded) both fired exactly as designed
and prevented two classes of unnecessary engine surgery.

What didn't work, in order of cost: (1) coordinator wall-clock
discipline — hand-stamped ledger times drifted hours from `date` twice,
first compressing the program artificially, then closing it prematurely;
(2) the ASK-answer monitors — literal grep-count watchers broke silently
when the supervisor compacted the ledger, and the coordinator bumped an
ASK whose answer had sat in the file 2.5 hours; (3) the unattended test
gates' credential model — the #12 ruling reasoned about live credentials
FAILING (401s); nobody enumerated the case where they WORK and the suite
MUTATES, so discovery mode was the principal's inbox; (4) subagent
foreground discipline — lanes ended turns to "wait" on backgrounded
builds 8+ times despite explicit foreground-only orders; every nudge
worked, but each stall cost 5–50 minutes until a process watchdog
bounded it.

## Patterns and Root Causes

Three of the four failures are ONE epistemic class: a stale proxy
standing in for a primary source. Hand-stamped timestamps are a proxy
for `date`; a grep-count monitor is a proxy for reading the channel; "the
401 assumption" is a proxy for checking what the credential actually
reaches. This is [REFL-011] (primary-source re-derivation) applied to
three surfaces the rule's table doesn't yet name: TIME (pacing decisions
are state claims about the clock), CHANNELS (an un-reread ledger is a
stale snapshot of the conversation), and CREDENTIAL REACH (a live key's
blast radius is the tool-reach extension exactly — sandbox DOMAIN does
not bound ACCOUNT-scoped endpoints like keys/subaccounts/users/IPs; the
suite's reach exceeded the gate's assumed scope). The general fix is the
same in all three: re-derive at the decision point, don't trust the
snapshot.

The mailgun incident deserves its own paragraph because the lesson
survives the benign outcome. The account proved sandbox-only, keys
intact, damage nil — but the gate design was wrong independent of that:
an unattended gate ran a suite whose 54/59 files call a live API, three
times, on credentials nobody had classified. "Green-if-it-fails-uniformly"
is not a safety posture for suites that can SUCCEED at mutating. The
suite also leaked fixture orphans in a PRIOR session (stale 2025-08-06
test keys found on the account) — the class predates tonight.

A positive pattern worth naming: verify-first mandates written INTO
charters paid for themselves twice (Lane K's sqp precondition check
refuted the W4 gate before any edits; Lane L's phase-A shape verdict
surfaced three design ambiguities before any code). The cost is one
read-only lane pass; the payoff both times was zero wasted implementation
on a false premise. The charters that lacked such a gate (the R4 test
assumption, the boiler "six sites" claim) are where premises failed
undetected until execution.

The subagent background-wait stall is a harness-behavior pattern, not a
convention gap: instructions alone don't hold; only a coordinator-side
watchdog (process-based, ownership-filtered after it false-positived on
the supervisor's foreign build) bounded the loss. Codifying "watchdog +
hard time budget per lane gate" in supervise dispatch guidance would
mechanize what took eight ad-hoc nudges to learn (noted here, deferred
past the action-item cap).

## Action Items

- [ ] **[skill]** testing: add a rule — live-mutating test suites (any
  suite calling a real external API with ambient credentials) are OUT of
  unattended/overnight gates BY DEFAULT; gate = build + provably-offline
  suites; sandbox DOMAINS do not bound ACCOUNT-scoped endpoints
  (keys/subaccounts/users/IPs); credential classification (expired /
  live-sandbox / live-production) is a dispatch precondition. (Supervisor
  R3 proposal, mailgun incident 2026-07-12.)
- [ ] **[skill]** supervise: add wall-clock anchoring to coordinator
  conduct — pacing/boundary decisions are state claims about time and
  MUST re-derive from `date` at the decision point, never from
  event-flow feel; long-run ledger entries carry `date`-derived stamps
  (two same-night drift corrections, 2026-07-12).
- [ ] **[skill]** supervise: ASK-channel discipline — before bumping an
  unanswered ASK, re-read the channel backlog from primary source;
  answer-watch mechanisms MUST tolerate concurrent file restructuring
  (grep-count monitors broke silently; answer sat 2.5h × 3 deliveries,
  2026-07-12).
