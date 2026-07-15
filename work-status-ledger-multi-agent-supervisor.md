# Work-Status Ledger for the Multi-Agent Supervisor System

<!--
---
version: 1.0.0
last_updated: 2026-07-15
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger.** On 2026-07-14, three separate planned "waves" of work dissolved on contact with the
disk — one chartered by the L1 supervisor, one the principal explicitly asked for, all three
already done or void — inside a single overnight run. The same night produced a cluster of
instrument failures in the supervision machinery itself (two ledger watches dead for 40 minutes;
a correct rule deleted on the strength of a broken probe; a status report rendered against a
dead run's log). The closing reflection reduced all of it to one sentence, since promoted to two
supervise rules:

> **A record is not a work item, and a stale record is indistinguishable from a live one at
> read-time.** A work item is *recorded* in one place (a carry-forward, a banked flag, a
> `Project Status (live)` bullet) and *closed* in another (a git commit), and **nothing
> mechanically connects them.**
> — `Reflections/2026-07-14-supervisor-overnight-three-dissolved-waves-and-a-deleted-rule.md:93-102`

[SUPER-072] (verify OPEN at dispatch) and [SUPER-073] (stamp the flag at close) were authored
against exactly this failure. They are **disciplinary rules enforced by recall** — and the same
reflection records the supervisor authoring [SUPER-072] and then *nearly violating it one hour
later*. Its conclusion is the thesis of this document:

> **Guards belong in the check, not in memory.** Knowing a rule by name does not immunize you
> against violating it; the rule has to live in a *mechanical gate at the moment of action*.
> — same reflection, `:115-122`

**This document extends an open internal artifact, not a closed one.** `corpus-drift-taxonomy.md`
(status **DEFERRED**, v0.1.0, 2026-07-02) is the ecosystem's existing, self-declared-incomplete
inventory of record-vs-reality *drift classes* with detection mechanisms; its owning rules are
"partial" or "gap" for exactly the classes this ledger addresses (Class 1 index-vs-disk, Class 2
frontmatter-vs-index status, Class 10 derived-view-vs-source). This doc supplies the design that
closes those gaps; it does not compete with a settled position.

**Constraints.** This is a design-research document issuing a **RECOMMENDATION**. It is explicitly
**not** implementation and **not** the supervise/handoff skill amendments — those are separate,
later-authorized `skill-lifecycle` follow-ons. The design must live inside the workspace's *actual
substrate*: markdown ledger files, a git working set, POSIX shell scripts under
`swift-institute/Scripts/`, and AI-agent seats sharing no state except the filesystem, git, and
memory. It must **not** assume a daemon, a database, or a running service — the workspace
deliberately has none (`agent-supervision-patterns.md:12-13,24-28`).

**Skills loaded** ([RES-033]): `supervise` (`channel.md` [SUPER-059..068]; [SUPER-070]/[SUPER-071];
[SUPER-072]/[SUPER-073]; [SUPER-009]/[SUPER-035]/[SUPER-038]/[SUPER-052]), `research-process`
([RES-*]), `handoff` ([HANDOFF-038]/[HANDOFF-039]), `reflect-session`/`corpus-meta-analysis`
([META-001]/[META-021]/[META-022]/[META-027]).

**Stakeholders.** The L1 workspace supervisor, the L2 general orchestrator, and any L3 arc session
— every seat "boots" on the same status artifacts and inherits their claims.

---

## Question

How should the L1/L2/L3 supervisor system maintain a trustworthy, self-maintaining ledger of
work/project status, such that:

- **(a) Divergence-proof** — a record cannot silently diverge from disk truth;
- **(b) Boot-safe** — a stale status line cannot mislead the next boot;
- **(c) Liveness-verifiable** — watch/channel liveness is independently verifiable (a silent
  watch is distinguishable from a dead one);
- **(d) Mechanically reconcilable** — a work item's OPEN/DONE state is mechanically reconcilable
  against the disk, not asserted by a human mark.

The design must be **self-maintaining**: it fails closed the moment a record and reality diverge,
*at the moment of action*, without depending on an agent remembering to check.

### The grounding set — last night's concrete failures (ground rule 3)

Ground rule 3 and the [RES-036] "state the failing case the change must handle" discipline require
every option to be scored against the *actual* failures, and to state what it would **and would
not** have prevented. The canonical seven, cited to source:

| # | Failure | Source | Class |
|---|---------|--------|-------|
| **F1** | **E-6 wave** — 6 items chartered from **retired charters in `handoffs/.trash/`**; all 6 already done or void on disk. | reflection `:22-32`; CLAUDE.md Gotchas "AN HONEST STALE RECORD…" | record/close disconnect; `.trash/` as source |
| **F2** | **`@Cases` void task** — L1 chartered a task on a frame **it built itself**; premise false (failability direction); the regression control it *chose* would have **passed on a green no-op**. | reflection `:34-40`,`:84-86`; Gotchas "A CONTROL THAT CANNOT FAIL…" | wrong close-oracle |
| **F3** | **Lint wave-0** — dispatched-and-authorized, but **complete since 2026-07-07 (`995a237`)**; `Project Status (live)` called it *pending* for a week. | reflection `:42-46` | recorded-here / closed-there |
| **F4** | **Stale `Project Status (live)` line** — the highest-leverage stale record; **every seat boots on it**; never stamped at close. | reflection `:97-102` | stale materialized view |
| **F5** | **Dead `\|\| echo 0` watch** — two doorbell watches poisoned at arm-time; supervision **blind for 40 min**; silence read as progress. | reflection `:74-78`; Gotchas "A `\|\| echo 0` FALLBACK…" | unverifiable liveness |
| **F6** | **Report-against-a-corpse** — a status report rendered against a **dead run's log**. | charter §0; reflection `:104-113` | liveness / stale source |
| **F7** | **Deleted a correct rule** — a well-argued refutation built on a **broken probe** (`pgrep -c`, absent on macOS) struck a correct rule and pushed it. | reflection `:79-83` | refutation-as-claim (out of ledger scope) |

**Honesty note.** A work-status-ledger design is the right fix for the *record-vs-reality* family
(F1, F3, F4) and, via a machine-checkable close predicate, for the *wrong-oracle* family (F2). It
is a **partial** fix for the *liveness* family (F5, F6) — it supplies the mechanism, which must
then be armed and positive-controlled. It is **not** a fix for F7 (a refutation-verification
failure orthogonal to status tracking, owned by the [SUPER-054]-family "a refutation is a claim"
discipline). Claiming otherwise would itself be "a control that cannot fail on the defect you are
hunting."

---

## Analysis

### Framing: an event log with a stale materialized view — and a snapshot mistaken for live state

The workspace already *is* an append-only, event-sourced system, unnamed as such: every RUN LEDGER
is an append-only log; every git commit is a content-addressed, immutable event; the mechanical
stamper (`ledger-append.sh`) forbids history rewrite ([SUPER-059]). The defect is not the log — it
is that **`Project Status (live)` is a hand-maintained materialized view over that log that nobody
recomputes**, with **no reconciliation** between the view and the source of truth (git + disk). The
PostgreSQL framing is exact: a materialized view is a cache with an explicit invalidation
obligation; *"(live)"* is a promise the mechanism does not keep when no `REFRESH` is wired to
base-data change.

The deeper internal frame is epistemic and unifying
(`Reflections/2026-07-14-stripe-reuse…snapshot-as-live-state.md:124-142`): **every stored status is
a *snapshot of belief at write-time*; treating it as live state is the root failure** — and it
recurs across data, processes, protocol, and code. [SUPER-009]'s "verify named blockers exist"
(a HALT doc encodes belief at write-time, not live state) and [SUPER-035]/[SUPER-038] (enumerated
state moves under a brief; briefs copy stale text forward) are the same lesson in the supervise
corpus. The ledger's job is to make **re-verification-against-disk the default before any record is
acted on.**

### Evaluation criteria

| Criterion | Definition | Maps to |
|-----------|------------|---------|
| **C1 Divergence-proof** | Record cannot silently diverge from disk; divergence surfaces mechanically. | (a) |
| **C2 Boot-safe** | A stale line cannot mislead the next boot; the boot reads a derived-or-checked status. | (b) |
| **C3 Liveness-verifiable** | Watch/channel liveness is a positive, ageable signal. | (c) |
| **C4 Mechanically reconcilable** | OPEN/DONE is defined by a probe against disk, not a human mark. | (d) |
| **C5 Gate-at-action** | The check fires at dispatch/close/boot — not by recall. | meta-lesson |
| **C6 Substrate-fit** | Implementable in markdown + git + shell; no daemon/DB/service. | constraint |
| **C7 Cost** | Authoring + maintenance + per-action overhead. | [RES-020] |

### Prior Art Survey — Internal ([RES-019], **governs**)

The internal corpus already holds strong, load-bearing positions; where they conflict with the
external survey, they govern (ground rule 1). The positions this design builds on:

1. **A stored status is a snapshot of belief at write-time, not live state** — the single
   most-repeated internal conclusion ([SUPER-009] "verify named blockers"; [SUPER-035]/[SUPER-038];
   the four-level snapshot-as-live-state reflection). *(goals a, b)*
2. **The canonical staleness mechanism is an age-threshold on a metadata date that grants triage
   authority** — [META-001]/[META-002] (IN_PROGRESS `last_updated` threshold), [META-022]
   (experiment staleness), [SKILL-LIFE-004]/[SKILL-LIFE-005] (git mtime vs `last_reviewed`),
   [HANDOFF-038] (>14-day untouched → MUST triage; annotate `// Last active: YYYY-MM-DD`).
   *(goal b)*
3. **Record-vs-disk reconciliation is a `diff`/`find`/`parser` check, and it is under-specified
   today** — `corpus-drift-taxonomy.md` Class 1 (`diff <(ls) <(jq index)`), Class 2
   (frontmatter-status vs index-status), Class 10 (routing-table vs actual IDs); owning rules
   "partial"/"gap". This doc extends that open taxonomy. *(goals a, d)*
4. **Provenance-linking already has a record-level idiom** — [HANDOFF-039]
   `## Superseded By: {successor} ({date})`, written into the retired record by the successor's
   creator; `corpus-drift` Q2 "every predicate cites a single canonical authority"; the reflection
   action-item "wave-close `⚠️ ERRATUM / OUTCOME` stamping." The ledger adopts commit/flag→record
   back-links in the same shape. *(goal a; the "commit↔flag" ask)*
5. **A summary/aggregate/derived view is a cross-check, never the authority** — [SUPER-009]
   read-the-artifact, [SUPER-031] aggregator-is-not-evidence, [SUPER-040] a build cache is a stale
   derived view. Any rolled-up ledger status MUST be re-derivable from disk. *(goals a, c)*
6. **Mechanical enforcement at the point of use beats a rule in a reference file** — both 2026-07-14
   reflections + CLAUDE.md P3 ("a rule in a gotchas file is advice; a rule at the line where the
   mistake is made is a guardrail") — **but mechanical guards produce false positives and must be
   human-adjudicable (report-only), not auto-acted** ([BET-EVAL]; the `endstate`-substring guard
   false positive). *(meta-lesson)*
7. **OPEN/DONE is a disk/git fact, not a self-report** — [SUPER-009] acceptance testable from
   disk/git/build; "subordinate attestation is not acceptance"; [SUPER-052] membership-not-`ahead>0`
   (never infer state from a proxy). *(goal d)*
8. **The substrate is filesystem + git only; the ledger survives compaction because it is on disk;
   watches are file-path-anchored, count-based** ([REFL-009a]; filesystem-as-state-machine ratified
   bet, `agent-harness-engineering-comparative-analysis.md:808-816`). *(constraint, goal c)*
9. **Watch/channel liveness is not inferable — not from silence, not from having-sent** ([SUPER-061]
   and its converse). A channel is a count-based watch on a file path; liveness must be positively
   probed. *(goal c)*
10. **Internally-cited external models** — Magentic-One's **dual ledger** (Task Ledger =
    facts/guesses/plan; Progress Ledger = per-agent progress + a stall counter, drift detection
    counter-based and separate from the work — `agent-supervision-patterns.md:53`); **OpenHands**
    event-sourced architecture where compaction/verification/stuck-detection are *services
    subscribing to* the append-only event log rather than mutating it
    (`agent-harness-engineering-state-of-the-art.md:390-398`).

**Conflicts internal prior art imposes on this design (internal governs):**

- **[K1] No-auto-mutation.** The 2026-05-10 comparative-analysis ratified "harness-as-corpus:
  durable text + **human** edits, **not** auto-mutation" and "skill-layer (non-hook) enforcement"
  (`:913-922`). Reconcilable with P3 only if: **durable records stay human-authored text**,
  **reconciliation checks are mechanical and report-only**, and **derived views are generated
  (never hand- or auto-mutated in place)**. A ledger that auto-rewrites status records violates the
  bet; a ledger enforced only by hooks reopens the resolved non-hook bet. Every feature below states
  which side it lands on.
- **[K2] Staleness triage is gated on close, not age alone.** [HANDOFF-038]'s 14-day auto-triage
  sweep collides with the 2026-07-14 topology: live-channel handoffs are **no-touch** (moving or
  deleting them breaks a live watch), and CLAUDE.md now rules "drain per-arc at each close, **never
  batch-triage**." A TTL check may **flag** (report-only) but MUST NOT move/delete/auto-triage a
  live-channel record.
- **[K3] Derived views are cross-checks, re-derivable, never the close authority** ([SUPER-009]/
  [SUPER-031]). No gate closes on a rolled-up view alone.
- **[K4] Count-bearing status lines carry their qualifier inline + `⚠️ ERRATUM/OUTCOME` on
  falsification** — the 938-roots trap ("a count in a table outlives its qualifier in a paragraph")
  applies with special force because the ledger *is* a table of counts in the boot-read path.
- **[K5] The old "no inter-session channel cannot be assumed" position (2026-04-15) is superseded**
  by the live file-path channels; the design must therefore carry the watch-liveness burden that
  position dodged (Option F).

### Prior Art Survey — External (Tier 2, [RES-021]/[RES-034])

Surveyed by parallel subagents against **fetched primary sources**; each load-bearing claim carries
`[Verified: 2026-07-15]` where the primary was read, `(unverified)` otherwise (full survey files
retained as working notes). Per [RES-021] contextualization: each pattern is assessed for what it
would **cost** in a markdown+git+shell substrate — universal industry adoption of daemons/DBs does
**not** imply we should adopt one; the deliberate absence of a service is a design constraint, not a
gap.

**Cluster 1 — append-only log + derived state (the source-of-truth principle).**
- **Event Sourcing / CQRS** — current state is a *fold over an append-only event log*; the log is
  the write-model and single source of truth, and every read-model/materialized view is a disposable
  projection regenerable by replay (Fowler; Microsoft Azure Architecture Center)
  `[Verified: 2026-07-15]`. *Names the anti-pattern we are in: a hand-maintained read model.* Cost:
  eventual consistency and "immutability of mistakes" — corrections are **compensating events**, not
  edits (which matches [SUPER-059] "never rewrite; errata as new entries") `[Verified: 2026-07-15]`.
- **Log compaction + materialized-view REFRESH** — keep the *latest value per key*; a `null`-payload
  **tombstone** is a first-class delete event; PostgreSQL `REFRESH MATERIALIZED VIEW` re-runs the
  backing query and is *not* auto-synced (Confluent Kafka docs; PostgreSQL docs)
  `[Verified: 2026-07-15]`. *Sharpest diagnosis: "Project Status (live)" is a materialized view that
  went stale for want of a REFRESH; compaction keyed on work-item identity gives "latest-per-item
  wins."*
- **Datomic** — accumulate-only; closure is a **retraction datom**; "as-of" queries answer "what did
  we believe when" (Datomic docs) `[Verified: 2026-07-15]`. *The mature end-state; append-only is
  necessary but not sufficient — you also need latest-per-key/retraction or F3 recurs inside an
  append-only log.*

**Cluster 2 — reconciliation & content-addressed truth (the strongest anchors).**
- **Reconciliation / control loop (Kubernetes controllers)** — a non-terminating loop drives
  *observed* state toward *declared* state and **never assumes it is stable**; a divergence is an
  input to a correcting loop, not an undetected end-state (Kubernetes "Controllers" docs)
  `[Verified: 2026-07-15]`. *The direct answer to "a record cannot silently diverge from disk": the
  ledger's declared-open items are the spec; disk is the observed state; a reconcile pass keyed on
  `git log -S` would have found the closing commit before any wave was chartered (F1/F3).* Cost: only
  as good as a **cheap, correct observed-state probe** — a mis-anchored probe reconciles to a lie.
- **Content-addressed provenance (git objects + pickaxe)** — git is content-addressable (identity =
  hash of content); `git log -S<token>` finds the exact commit that added/removed a token (Pro Git;
  git-diff docs) `[Verified: 2026-07-15]`. *Supplies the observed-state probe and redefines "done":
  an item is DONE iff `git log -S<closing-token>` returns the closing commit — this is exactly
  [SUPER-072]'s prescribed probe.* Cost: `-S` counts occurrences (a count-preserving refactor is
  invisible; use `-G`); one repo at a time; SHAs move under squash.

**Cluster 3 — durable execution & explicit state (workflow engines).**
- **Temporal durable execution** — workflow state is *replayed from an append-only Event History*
  that the service (not the worker) owns; replay requires **determinism** (docs.temporal.io)
  `[Verified: 2026-07-15]`. *Maps to: the git repo is the source of truth; the ledger is a derived
  projection replayed from it by a **pure** reconciliation function (same repo ⇒ same OPEN/DONE
  verdict).*
- **Explicit state enumeration (Airflow / Argo)** — task state is a *stored, observable field* drawn
  from a closed enum, not inferred; the enums include a **terminal "did-not-need-doing" state**
  (Airflow `upstream_failed`, Argo `Omitted`) alongside `success`/`failed`/`skipped` (Airflow Tasks
  docs; Argo field reference) `[Verified: 2026-07-15]`. **★ The key upgrade:** last night's
  dissolved-on-contact items (F1/F3) were neither *open* nor *done-here* — they were **OBVIATED**;
  collapsing that into binary OPEN/DONE is what makes a stale item look live. Cost: a stored field is
  only as fresh as its last writer — it gives observability, not reconciliation (still needs
  Cluster 2 to stay honest).

**Cluster 4 — atomic close-with-the-work (issue trackers).**
- **GitHub closing keywords** — the verbatim set `close, closes, closed, fix, fixes, fixed, resolve,
  resolves, resolved`; the fix-carrying commit/PR names the item and the **merge to the default
  branch performs the close** (GitHub Docs) `[Verified: 2026-07-15]`. *The exact external precedent
  for [SUPER-073]: the same commit that lands the fix stamps the item it closes — no window where the
  fix has landed but the flag is still open.* Together with `git log -S` (the probe half), this is
  the stamp half. Cost: only as reliable as the discipline of writing the token → **must be enforced
  by a commit-message gate, not convention**, or it degrades to the honest-but-stale record
  [SUPER-072] warns of; and it handles *close*, not *reopen-on-regression* (needs a second pass).
- **Jira guarded transitions** — OPEN→DONE is not a free assignment but a **transition with a
  validator** (fails ⇒ item does not progress) and a **post function** (stamps the SHA / appends
  history in the same act); **triggers** fire transitions from dev-tool events (Atlassian docs)
  `[Verified: 2026-07-15]`. *Closing is the gate; the record update is part of the transition.* Cost:
  heavyweight if over-modeled — take the *shape*, not Jira's full configurability tax.

**Cluster 5 — liveness (independent of work-state).**
- **Kubernetes `Lease` heartbeat ★** — liveness is a **periodically-renewed timestamp** (`renewTime`);
  the control plane reads the stamp's freshness to judge availability; a lease not renewed within its
  TTL ⇒ holder presumed dead (Kubernetes Leases docs) `[Verified: 2026-07-15]`. *The direct fix for
  F5/F6: a watch/seat writes a renew-stamp on a cadence; a stamp older than the TTL is a positive
  DARK verdict, not "quiet-therefore-fine."*
- **ZooKeeper ephemeral / etcd lease** — a registration bound to a renewed session **self-expires and
  notifies** when heartbeats lapse; **one-time watches must be re-armed or a missed event is
  indistinguishable from a dead watch** (ZooKeeper; etcd docs) `[Verified: 2026-07-15]`. *"Re-arm the
  doorbell" is a first-class hazard for our own count-based watches.*
- **Liveness-vs-readiness + Prometheus staleness** — a process can be *running yet hung* (liveness ≠
  progress); absence of a fresh sample past a **staleness horizon** resolves to *stale → unknown*,
  never *stale → last-known-good* (Kubernetes probes; Prometheus docs) `[Verified: 2026-07-15]`.
  *Bounds the silence and forbids the `|| echo 0` inversion where a broken probe manufactured a
  healthy-looking zero; liveness (watch alive) and progress (work advancing) are **distinct axes**.*

**Verified-count and honest gaps:** across the three external clusters, ~103 load-bearing claims were
primary-source-verified and 7 explicitly flagged `(unverified)` (e.g., LangGraph's "every super-step"
checkpoint cadence; K8s default lease-renewal/grace-period *numbers*; Cadence sharing Temporal's model
— none load-bearing here). No claim is asserted beyond its verification.

### Design options

The options are points on an axis from pure discipline to fully-mechanical-and-derived; they
**compose** (every surveyed durable-execution/controller platform composes the same layers). Per
[RES-036], structural correctness dominates diff-size.

**Option A — Status quo: disciplinary rules enforced by recall (baseline).** Keep [SUPER-072]/
[SUPER-073] as recalled rules + hand-maintained `Project Status (live)`. *Advantage:* zero new
machinery. *Disadvantage:* this is the configuration that produced F1/F3/F4 — the supervisor
authored [SUPER-072] then nearly violated it within the hour. *Prevents:* nothing mechanically.
*Does not prevent:* F1, F3, F4, F5, F6. **Rejected** — it is the failure, not the fix.

**Option B — Freshness-dated records + report-only staleness gate (TTL tripwire).** Every record
carries `last-verified: YYYY-MM-DD`; a gate in the shape of the existing report-only
`check-memory-corpus.sh` ([META-027], "never mutates; triage stays human") flags records past a TTL.
Reuses the canonical internal staleness mechanism (internal position 2). *Honors [K1]* (report-only),
*[K2]* (flags, never auto-triages; live-channel-aware). *Disadvantage:* TTL flags **age, not
divergence** — a freshly-restamped-but-wrong record passes. *Prevents:* F4 (a week-stale line trips
the TTL). *Does not prevent:* F1/F3 when recent-but-wrong, F5/F6, F2. **Keep as the tripwire for
un-mechanizable (judgment) items**, not as the fix.

**Option C — Machine-checkable close predicate per work item (provenance-linked "done") — keystone.**
Promote the unit of work from a prose bullet to a **structured record carrying a close predicate**: a
command that evaluates true **iff** the work is done on disk — `git log -S"<token>"` (the [SUPER-072]
probe), `Scripts/gate.sh <pkg>`, a file/grep probe with a **positive control** (and negative controls
per the "predicate not heuristic" internal rule). **DONE is defined by the predicate, not by a human
mark** (internal position 7). The commit that lands the fix carries the closing token (the GitHub
closing-keyword / [SUPER-073] stamp half); the probe is the reconciliation half. Records may also
carry the supervisor's derived **count/sub-item inventory**, reconciled on mismatch (the "25 sites,
not the sites" save; LangGraph pending-writes). *Honors [K1]* (the record is human-authored; the
predicate is mechanical). *Advantage:* kills the record/close disconnect at its root and forces the
F2 discipline — the close predicate *is* the "currently-failing case the change must make pass" oracle
whose absence made F2's control a rubber stamp; `git log -S` is the exact probe that would have found
`995a237`. *Disadvantage:* judgment-shaped items need a predicate-of-last-resort (named reviewer +
date) and fall back to B. *Prevents:* F1, F3, F2. *Does not prevent:* F5, F6, F7. **Keystone
component.**

**Option D — Append-only event log + generated status view (event sourcing).** Make the ledger the
single **event log** of typed work-item events (`OPENED` / `CLOSED@<sha>` / `OBVIATED@<sha>` /
`SUPERSEDED@<sha>` / `BLOCKED`), including the **OBVIATED** terminal state (Airflow/Argo) that F1/F3
lacked. **Demote `Project Status (live)` to a *generated* view** recomputed from the event log + the
Option-C predicates by a runnable generator (the shape of `sync-skills.sh` regenerating symlinks) —
**never hand- or auto-mutated in place**, and marked as generated so it is never mistaken for an
authored source. *Honors [K1]* (generated ≠ auto-mutation of a human record), *[K3]* (the view is a
cross-check, re-derivable from disk on demand; no gate closes on the view alone), *[K4]* (count-lines
carry inline qualifiers + `⚠️ ERRATUM/OUTCOME`). OpenHands' "services subscribe to the log" is the
internal-cited precedent. *Advantage:* F4 cannot recur by construction — a regenerated view cannot be
hand-edited into staleness. *Disadvantage:* needs C to compute honestly and E to run the regeneration;
one-time migration of the prose status into typed events. *Prevents:* F4 structurally. *Does not
prevent:* F5, F6, F7 alone. **Structural component.**

**Option E — Reconciliation gate (declared vs observed) — engine.** A **report-only** checker (the
Kubernetes reconcile pattern; the guarded-transition *validator*) that at **boot and at every close
boundary** runs each item's Option-C predicate against disk and reports the two divergence classes:
*recorded OPEN but predicate TRUE* ⇒ "already done — do not charter" (kills F1/F3 at dispatch), and
*recorded DONE but predicate FALSE* ⇒ "regressed/reopened." This is [SUPER-072]/[SUPER-073] promoted
from recall to a gate — the "guards belong in the check" move. *Honors [K1]/[K2]* (report-only;
human triage per [BET-EVAL]; never auto-mutates or moves live-channel files), *[K3]* (re-runs the
primary probe, not a cached view). *Disadvantage:* only as good as its predicates — **its own probes
must be positive-controlled across degenerate states (empty/one/missing)** or it becomes the next
`|| echo 0` lying instrument (F5/F7). *Prevents:* F1, F3 at dispatch; surfaces F4. *Does not prevent:*
F5, F6 directly, F7. **Engine component.**

**Option F — Renewable liveness lease for watches and seats (liveness axis).** A watch/seat writes a
mechanically-`date`-stamped **renew line** on each poll (K8s `Lease.renewTime`); a stamp older than a
per-class TTL ⇒ **presumed DARK** (Prometheus staleness horizon: stale → *unknown*, never
*last-known-good*). Liveness and progress are **distinct axes** — a lease proves the renewer is
*running*, not doing *useful* work — so a progress signal stays separate ([SUPER-061] made
mechanical). "Re-arm the doorbell" (ZooKeeper one-time-watch hazard) is a named requirement — note the
orchestrator's own doorbell already re-reads the ledger in full on each fire rather than deciding from
the notification. *Honors [K5].* *Prevents:* F5 (a poisoned watch stops renewing and is detected by
lease age), F6 (a report checks the source's lease before trusting it). *Does not prevent:* F1–F4, F7.
**Liveness component.**

### Comparison

| Criterion | A discipline | B TTL | C predicate | D event-view | E reconcile | F lease |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| C1 Divergence-proof | ✗ | ~ | ✓ | ✓ | ✓ | n/a |
| C2 Boot-safe | ✗ | ~ | ✓ | ✓ | ✓ | n/a |
| C3 Liveness-verifiable | ✗ | ✗ | ✗ | ✗ | ~ | ✓ |
| C4 Mechanically reconcilable | ✗ | ✗ | ✓ | ✓ (w/ C) | ✓ | n/a |
| C5 Gate-at-action | ✗ | ✓ | ✓ (via E) | ✓ (via E) | ✓ | ✓ |
| C6 Substrate-fit | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| C7 Cost | lowest | low | medium | med-high | medium | low |
| **Failures prevented** | — | F4 | **F1,F2,F3** | F4 | **F1,F3**,F4 | **F5,F6** |

---

## Outcome

**Status: RECOMMENDATION.**

Adopt a **composite work-status ledger**, layered so each layer makes the next honest and the whole
**fails closed at the moment of action** rather than by recall. Each layer names the internal
constraint it honors:

1. **[C — keystone] Work items become structured, human-authored records carrying a machine-checkable
   close predicate.** DONE is defined by the predicate against disk (`git log -S`, `gate.sh`,
   positive+negative-controlled probe), not a human mark. Judgment items carry a
   predicate-of-last-resort (named reviewer + date) and inherit the B tripwire. *Honors [K1]* (record
   authored by a human; predicate mechanical).

2. **[E — engine] A report-only reconciliation gate runs the predicates at boot and every close
   boundary,** surfacing OPEN-but-done and DONE-but-regressed. This is [SUPER-072]/[SUPER-073]
   promoted from memory to a check. *Honors [K1]/[K2]* — it **never mutates or moves** records; triage
   stays human ([BET-EVAL]); *[K3]* — it re-runs the primary probe, never a cached view. Its own
   probes MUST be positive-controlled across degenerate states.

3. **[D — structure] `Project Status (live)` is demoted to a *generated*, clearly-labelled view**
   recomputed from the event log + predicates by a runnable generator, never hand- or auto-mutated in
   place — so F4 cannot recur by construction. The event vocabulary includes the **OBVIATED** terminal
   state (the class F1/F3 lacked). *Honors [K1]* (generated ≠ auto-mutation), *[K3]* (re-derivable
   cross-check; no close on the view alone), *[K4]* (count-lines carry qualifiers + `⚠️ ERRATUM`).

4. **[B — tripwire] Every record carries `last-verified: DATE`; a report-only TTL gate flags stale
   records,** as the net for items whose truth is not fully mechanizable. *Honors [K2]* — flags,
   never auto-triages; live-channel-aware.

5. **[F — liveness] Watches and seats renew a liveness lease;** the supervisor verifies liveness by
   lease age, never by silence, with progress kept as a separate axis. *Honors [K5].*

6. **[A rejected]** Pure discipline is explicitly rejected: it is the configuration that failed.

**Why composite, not a single option ([RES-036]).** C without E is a predicate nobody runs; E without
C reconciles unverified marks; D without C/E is a view over lies; B alone flags age not divergence; F
secures the channel not the ledger. The failure set spans record-vs-reality (F1/F3/F4), wrong-oracle
(F2), and liveness (F5/F6); no single option covers it, and every surveyed industry system composes
these exact layers.

**Coverage against the grounding set.** F1 ✓ (E at dispatch), F2 ✓ (C is the real oracle), F3 ✓
(C/E find `995a237`), F4 ✓ (D by construction + B tripwire), F5 ✓ (F lease age), F6 ✓ (F, check
source lease before reporting). **F7 explicitly out of scope** — a refutation-verification failure,
owned by the existing [SUPER-054]-family discipline, not by a status ledger. Stating this
non-coverage is itself the F2 lesson applied.

**Caveats / what would change this recommendation.**
- **Predicate honesty is load-bearing, not a footnote.** The reconciler's own probes are subject to
  the `|| echo 0` / broken-probe family (F5, F7); the implementation MUST positive-control every probe
  across its degenerate states (empty / one-entry / missing-file) and prefer negative controls
  ("a catalog with only positive instances is a heuristic; with negative controls it is a predicate").
  Without this, the ledger becomes the next lying instrument.
- **No-auto-mutation is a hard boundary [K1].** Durable records stay human-authored; only *checks* and
  *generated views* are mechanical; nothing rewrites a status record behind a human's back.
- **Substrate discipline ([RES-021] contextualization).** The design stays in markdown + git + shell
  by deliberate constraint — no daemon, no DB. The workspace lacks the server that ZooKeeper/etcd
  assume, so the "reaper that expires a lease" role must be *simulated* by the boot/close reconcile
  pass, and can never be silently disabled.
- **This doc extends `corpus-drift-taxonomy.md` (DEFERRED)**; adopting the design should also close
  that taxonomy's open Class-1/2/10 gap-rules — but as a separate, later step.
- **Scope wall.** This document recommends the *design*. The record schema, the reconcile/generator
  scripts, the lease format, and the corresponding `supervise`/`handoff` skill amendments are
  **separate, later-authorized follow-ons** — deliberately not begun here (charter §1).

**Follow-on (not authorized by this doc).** (i) `skill-lifecycle` amendments promoting [SUPER-072]/
[SUPER-073] to reference the mechanical gate, and closing `corpus-drift-taxonomy.md`'s Class-1/2/10
gaps; (ii) an implementation spike of the reconcile gate + view generator + lease format,
positive-controlled per the caveat; (iii) a one-time migration of the prose `Project Status (live)`
into typed work-item records with the OBVIATED state.

---

## References

**Internal (cited, [RES-019] — governs):**
- `Reflections/2026-07-14-supervisor-overnight-three-dissolved-waves-and-a-deleted-rule.md` (failure catalog; root cause; "guards belong in the check")
- `Reflections/2026-07-14-supervisor-seat-both-goals-closed-and-the-rules-we-already-had.md` (938-roots trap; mechanical-enforcement-at-point-of-use)
- `Reflections/2026-07-14-stripe-reuse-seat-a9-discriminator-and-snapshot-as-live-state.md` (snapshot-as-live-state; positive/negative controls)
- `corpus-drift-taxonomy.md` (DEFERRED — the drift-class taxonomy this doc extends)
- `supervise` skill: `channel.md` [SUPER-059..068]; [SUPER-070]/[SUPER-071]; [SUPER-072]/[SUPER-073]; and [SUPER-009]/[SUPER-031]/[SUPER-035]/[SUPER-038]/[SUPER-040]/[SUPER-052] via `supervise-skill-rationale.md`
- `agent-supervision-patterns.md` (Magentic-One dual-ledger; substrate = FS/git/memory)
- `agent-harness-engineering-comparative-analysis.md` (ratified bets [K1]/[K5]); `agent-harness-engineering-state-of-the-art.md` (OpenHands event-sourced subscribers; append-only convergence)
- `handoff-lifecycle-and-retention.md` ([HANDOFF-038]/[HANDOFF-039]; staleness-threshold-grants-triage-authority)
- `swift-institute/Workspace/CLAUDE.md` — Gotchas table (failure catalog) + "Project Status (live)"
- `swift-institute/Scripts/ledger-append.sh`, `check-memory-corpus.sh` ([META-027] report-only precedent)

**External (Tier 2, [RES-021]/[RES-034], primary-source verified 2026-07-15):**
- Event sourcing: Martin Fowler, "Event Sourcing" (martinfowler.com/eaaDev/EventSourcing.html); Microsoft Azure Architecture Center, "Event Sourcing" + "CQRS"
- Log compaction / views: Confluent, "Kafka Log Compaction"; PostgreSQL, "REFRESH MATERIALIZED VIEW"
- Reconciliation: Kubernetes, "Controllers" (kubernetes.io/docs/concepts/architecture/controller/)
- Provenance: Pro Git, "Git Internals — Git Objects"; git-diff pickaxe `-S`/`-G`
- Datomic: "Datomic Overview" (docs.datomic.com)
- Durable execution: Temporal, "Event History" + "Workflows" (docs.temporal.io)
- Explicit state: Apache Airflow, "Tasks" (task-instance states); Argo Workflows field reference (NodePhase)
- Atomic close: GitHub Docs, "Linking a pull request to an issue" (closing keywords); GitHub REST — Check Runs + Commit Statuses; Atlassian, "Configure advanced issue workflows" (Jira transitions/validators/post-functions/triggers)
- Liveness: Kubernetes, "Leases" + "Liveness/Readiness/Startup Probes"; Apache ZooKeeper Programmer's Guide (ephemeral znodes); etcd API (leases); Prometheus, "Querying basics" (staleness)
- Agent state: LangGraph persistence/checkpoints (langchain); Claude Agent SDK todo/task tracking (code.claude.com)
