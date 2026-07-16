# Control Plane v3 — Kernel Design

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: DESIGN RECORD (first vertical slice authorized; SaaS sections are direction, not commitment)
scope: swift-institute/swift-control-plane
changelog:
  - 0.1.0 (2026-07-16): Initial design. Companion to provenance-and-failure-corpus.md.
---
-->

## Context

Companion to `provenance-and-failure-corpus.md`, which fixes the v2 evidence. This document
is the design of the smallest useful Swift-native control-plane kernel that eliminates v2's
failure classes and can evolve into a multi-tenant SaaS.

## Axioms (from the failure corpus)

1. **The worker loop is owned by our process.** Interactive Claude/Codex sessions are
   clients, never load-bearing workers. There is a daemon; its loops are the consumers.
2. **Notifications are advisory.** No push, wake, doorbell, or file-watch is ever on the
   correctness path. Polling by owned loops is the correctness path; push is a latency
   optimization layered on top later.
3. **Commands are idempotent.** Every command carries a client-generated command id.
   Delivery is at-least-once; effects are exactly-once by dedup on the command id.
4. **Events are the only truth.** Canonical state is a deterministic, clock-free,
   RNG-free fold over an append-only event log. Replay reconstructs everything.
5. **Liveness is lease-based and per-job.** A dead or stuck runner affects exactly the
   jobs it holds leases on, and only until expiry. No global locks, no global readiness,
   no whole-store staleness digest.

## 1. Commands, events, aggregates, terminal states

**Namespace**: `Control.Plane` (Nest.Name per [API-NAME-001]; precedent: `File.System` in
swift-file-system). All types below live under it.

**Aggregates**

| Aggregate | Identity | State |
|-----------|----------|-------|
| `Job` | `Job.ID` (client-supplied string, stable) | phase, attempt, policy, payload, current lease, cancellation-requested flag |
| `Runner` | `Runner.ID` | active / retired (informational registry; job leases carry the load-bearing liveness) |

Plus one projection-level index that is not an aggregate: the **command index**
(`Command.ID` → seqs of the events it produced), rebuilt from event envelopes; it is the
dedup table.

**Job phases**

```
                    ┌────────────────────────────────────┐
submit ──▶ queued ──claim──▶ running ──report(success)──▶ succeeded   [terminal]
             ▲                  │ ├──report(failure, terminal)──▶ failed      [terminal]
             │                  │ ├──report(failure, retryable)─┐
             │                  │ ├──lease expiry (sweep)───────┤
             │                  │ └──attempt timeout (sweep)────┤
             │                  │                               ▼
             └──────(attempts remain: requeued, backoff)◀───────┤
                                │                               │ (attempts exhausted)
        cancel (queued) ──▶ canceled [terminal]                 ▼
        cancel (running) ─▶ cancellation requested ─▶ … ─▶  parked  [dead letter, inert]
                                                              │
                                     admin requeue ───────────┘ (attempt reset, reason recorded)
```

Terminal: `succeeded`, `failed`, `canceled`. `parked` is inert (dead letter): the
automatic loop never touches it; only an explicit `requeue` command revives it.

**Events** (`Control.Plane.Event`) — every recorded event carries an envelope
`(seq, at: Instant, command: Command.ID)` plus the aggregate id:

| Event | Payload | Meaning |
|-------|---------|---------|
| `submitted` | job id, payload, policy | job enters `queued` (attempt 1) |
| `claimed` | runner id, lease id, attempt, expires | job enters `running`; lease created |
| `renewed` | lease id, expires | lease extended |
| `succeeded` | lease id, outcome | terminal |
| `failed` | lease id, reason | terminal (non-retryable report, or policy forbids retry) |
| `requeued` | reason (`expired` / `timedOut` / `retryableFailure` / `revived`), attempt, notBefore | back to `queued` with backoff gate |
| `parked` | reason | dead-lettered (attempts exhausted, or cancel of an expired job) |
| `canceled` | reason | terminal |
| `cancellation.requested` | — | running job flagged; runner learns at next renew/report |
| `runner.registered` / `runner.retired` | runner id | registry |

Design choice: there is no separate `expired` event — the `requeued`/`parked` event's
`reason` carries it. Fewer event kinds, same information, simpler fold.

**Commands** (`Control.Plane.Command`) — every command carries
`(id: Command.ID, at: Instant)` stamped at ingress by the shell; the kernel never reads a
clock:

| Command | Effect |
|---------|--------|
| `submit(job:payload:policy:)` | append `submitted` (reject if job id exists) |
| `claim(runner:duration:)` | pick first eligible queued job (FIFO by seq, `notBefore <= at`), append `claimed`; if none eligible: outcome `idle`, no events |
| `renew(job:lease:)` | append `renewed`; reply tells the runner `renewed` or `cancelRequested`; stale lease → rejected |
| `report(job:lease:outcome:)` | append `succeeded` / `failed` / `requeued` / `parked` per policy; stale lease → rejected |
| `cancel(job:reason:)` | queued → `canceled`; running → `cancellation.requested` |
| `requeue(job:)` | parked → `requeued(reason: revived)` (admin revive) |
| `sweep()` | for every running job: lease expired or attempt timed out → `requeued` or `parked`; naturally idempotent (no-op if nothing expired) |
| `register(runner:)` / `retire(runner:)` | registry |

**Command outcomes** (`Control.Plane.Receipt`): `accepted(events)`, `duplicate(original)`,
`idle` (claim found nothing; no events), `rejected(reason)` (no events). Typed reject
reasons: `jobExists`, `unknownJob`, `unknownRunner`, `staleLease`,
`invalidPhase(current:)`, `payloadMismatch` (same command id, different payload bytes —
fails closed, as v2 did).

**Idempotency semantics, precisely.** A command whose id is in the command index returns
`duplicate` with the recorded outcome — it never re-executes. A command that produced no
events (rejected / idle) is not recorded; a retry re-evaluates against current state.
That is correct under at-least-once delivery: no-effect outcomes are safe to recompute,
and the recomputation may legitimately differ if the world moved (e.g. an `idle` claim
retried after a submit now claims a job — desired behavior for a polling claim).

## 2. Per-job ownership and lease semantics

- A **lease** is `(Lease.ID, job, runner, expires: Instant)`, created by `claim`,
  extended by `renew`, checked by everything.
- **Fencing**: the current lease id is the fencing token. `renew` and `report` with any
  other lease id are `rejected(staleLease)` and append nothing. A zombie runner (paused,
  partitioned, killed-and-restarted) whose lease expired and whose job was reclaimed can
  never corrupt the job — its reports bounce off the fence.
- **Expiry is the requeue trigger**, evaluated only inside `sweep` with the command's
  `at` instant — never inside the fold, never against a live clock. Replay determinism
  follows: the same log folds to the same state on any machine at any time.
- **Ownership is exclusive and total**: exactly one live lease per running job; queued /
  parked / terminal jobs have none. Runner-level health does not exist as a correctness
  concept — only leases do. (v2's inverse bet — infer job health from seat/waiter
  health — is what produced stale-green coverage.)
- Daemon restart does not release or extend leases: they ride the log. Jobs whose leases
  expired during downtime requeue at the first post-restart sweep. Jobs whose runners
  died with the daemon requeue at expiry. No manual fencing command is ever required
  (v2 failure i).

## 3. Queue, retry, cancellation, timeout, dead-letter

- **Queue**: FIFO over `queued` jobs by original submission seq, gated by `notBefore`.
  Deterministic: seq is a total order. No priorities in slice 1 (policy field reserved).
- **Retry**: `Job.Policy` carries `attempts.max` and `backoff` (fixed duration in slice 1).
  Retryable failure / expiry / timeout with attempts remaining →
  `requeued(attempt+1, notBefore: at + backoff)`. Attempts exhausted → `parked`.
- **Cancellation**: two-phase for running jobs. `cancel` appends
  `cancellation.requested`; the runner's next `renew` or `report` reply carries the
  directive; a compliant runner stops and reports; a dead runner's lease expires and the
  flagged job goes to `canceled` (not requeued) at sweep. Queued jobs cancel immediately.
- **Timeout**: per-attempt wall-time bound in policy, enforced by `sweep` against the
  claim instant — catches the hung-backend-with-dutiful-runner case that lease renewal
  alone cannot (the runner keeps renewing while the backend hangs forever).
- **Dead letter**: `parked` keeps the full event history (reason, attempts). Revival is
  an explicit `requeue` command that resets the attempt counter and records `revived`.
- **Isolation invariant** (v2 failure c): eligibility is evaluated per job; a parked,
  stuck, or ambiguous job is simply ineligible. There is no global lock, no global
  readiness aggregate, and no cross-job precondition anywhere in the kernel. One failed
  or unreachable job can never block an unrelated claim.

## 4. Runner lifecycle and model/backend adapters

**Runner loop** (owned by the daemon, one structured `Task` per runner):

```
register → loop {
    claim(duration: lease)                      // poll; idle → sleep(pollInterval), continue
    concurrently:
      heartbeat: every lease/3 → renew          // observes cancelRequested directive
      execute:   backend.run(job)               // the only await on foreign code
    report(outcome, lease)                      // fenced by lease id
} → retire
```

- The kernel actor never awaits a backend; runner loops do. A hung backend hangs its
  runner task only; the lease expires; the job requeues; other runners are untouched.
- **Backend protocol** (`Control.Plane.Runner.Backend`): `run(job) async → Outcome`,
  cancellation-cooperative. Adapters:
  - `Backend.Fake` (slice 1): scriptable — succeed after N, fail retryably/terminally,
    hang forever. Drives every failure-mode test without process machinery.
  - `Backend.Process` (next): spawns a headless model CLI (`claude -p`, codex exec) via
    swift-process; the subprocess is the model session. This is where Claude/Codex
    plug in — as adapters, exactly as the constraint requires.
  - `Backend.Remote` (SaaS): the runner fleet endpoint (§9).
- Interactive UI sessions never appear in this loop. They submit commands and read
  projections through the CLI (later the API), and may receive advisory notifications.

## 5. Event persistence and transactional projection invariants

**Store abstraction** (`Control.Plane.Store`): `append(events) → assigned seqs` and
`read(from:)`. Implementations:

- `Store.Memory` (slice 1): array under the kernel actor. Deterministic; the reference
  implementation for tests.
- `Store.File` (slice 1): JSON Lines, one event per line, canonical encoding
  (sorted keys) via swift-json; append via swift-file-system.
- `Store.Postgres` (designed now, built later): §9.

**Invariants** (these are the crash-boundary contract, each with a test):

1. **Atomic command batch**: all events of one command are appended in one write
   (single buffer, single syscall under `O_APPEND`). A crash boundary can never split a
   command's effects.
2. **Monotonic seq**: strictly `+1` per event; the fold rejects gaps or duplicates
   (fail-closed, as v2's reducers did).
3. **Append before apply**: the projection is updated only after the durable append
   returns. In-memory state is always a suffix-fold of durable truth, never ahead of it.
4. **Pure fold**: `State.apply(Recorded)` reads no clock, no RNG, no filesystem. All
   nondeterminism is captured in the event at decision time (v2 got this right).
5. **Replay equivalence**: fold(read(from: 0)) == live state, checked by `Equatable`
   on the whole canonical state.
6. **Torn-tail self-healing**: `Store.File` recovery scans, validates every line, and
   truncates a torn final line before reopening for append (improves on v2's fail-closed
   manual truncation). A torn tail is provably not a committed command (invariant 1 +
   single-writer), so truncation never discards an acknowledged effect.
7. **Single writer**: the kernel actor serializes decide→append→apply. *(Amended at
   implementation, 2026-07-16: the single-instance lock at `Store.File` open is
   DEFERRED in slice 1 — single-instance is by operational convention until then.)*
   *(CORRECTED 2026-07-16, Principal pointer + re-probe: the first amendment claimed
   "swift-file-system vends no flock surface" and framed an upstream ADDITION as the
   fix. That was a token-grep false zero over the wrong scope: the institute lock
   surface already EXISTS at L2 — `ISO 9945 Kernel Lock` (fcntl record locking:
   shared/exclusive kinds, whole-file range, blocking F_SETLKW and non-blocking
   F_SETLK, unlock, and a `~Copyable Token` with deinit-release backstop), wrapped by
   `POSIX Kernel Lock`, with a multi-process contention harness in ISO 9945 Kernel
   Test Support. fcntl locks release on process death — exactly the required
   semantics. The remaining work is CONSUMPTION, not invention: `Store.File` holds an
   open descriptor for its lifetime and takes the exclusive whole-file lock
   non-blocking at open (second daemon fails fast). This lands with the
   multi-daemon/production graduation gate; a File-level convenience in
   swift-file-system remains a nice-to-have, not a prerequisite.)*
8. **The event is the receipt**: dedup is derived from event envelopes; there is no
   separate intent/receipt ledger to desynchronize (rejects v2's INTENT→COMPLETED
   two-phase shape; see provenance §rejects). Crash after append, before reply →
   the client's retry finds the recorded outcome by command id.

Snapshots/compaction: deferred by design (log volumes at institute scale are trivial);
the shape is reserved — snapshot = canonical state at seq N, then tail replay.

## 6. Retained v2 concepts (evidence, policy, edit zones, acceptance)

Adjudicated in provenance §"What v2 got right". Summary of how each lands in v3:

- **Command-id idempotency** — kernel-native (§1), including v2's payload-digest
  fail-closed check (`payloadMismatch`).
- **Evidence digests** — `succeeded.outcome` carries an opaque result plus optional
  content digest; the relay-layer re-digesting dies with the relay layers.
- **Acceptance / DoD / oracle** — job payload and outcome are kernel-opaque contracts in
  slice 1; the acceptance-gate vocabulary returns as a `Policy` aggregate when workspace
  work-items migrate onto jobs (§10), not as kernel hardcoding.
- **Authority epochs / fencing** — generalized into per-job lease fencing (§2) plus the
  daemon flock; the human-gated `takeover` ceremony dissolves.
- **Edit zones** — retained as a *declared write-scope in the job payload, enforced at
  the runner boundary* (the runner constrains the backend's working tree — worktree
  isolation), not as kernel state. v2's implementation was vestigial (always `[]`).
- **Policy/claims governance** — deferred aggregate; port re-reads v2's
  `governance.py` at port time.

## 7. Rejected v2 concepts

Full table with dissolution reasons in provenance §"What v3 rejects": park waiters, wake
relays, mux coverage, receipt files, boot-plan readiness/horizon digests, two-cycle
canaries, the global transaction lock, notification lifecycle ledgers, and the two-phase
command ledger. None of these has a v3 successor; they are not "ported later" — the
axioms make them unrepresentable.

## 8. Package/target decomposition and dependency graph

One package: `swift-institute/swift-control-plane` (private prototype; org home decided
at graduation, not now). Targets (spaces in names, underscores in imports, [MOD-012]):

```
Control Plane Kernel        zero dependencies (pure stdlib)
  vocabulary: Instant, Job, Job.ID/Payload/Policy/Phase, Lease, Runner.ID,
              Command, Event, Receipt, Reject
  kernel:     Control.Plane.Kernel (actor: decide → append → apply),
              Control.Plane.State (the fold), Store protocol, Store.Memory

Control Plane Store File    deps: Kernel, swift-json, swift-file-system
  Store.File (JSONL, canonical sort-keys encoding, torn-tail recovery, flock),
  JSON.Serializable conformances for Event/envelope (retroactive, this target only)

Control Plane Runner        deps: Kernel
  Runner loop, Backend protocol, Backend.Fake
  (Backend.Process lands here later, adding swift-process)

Control Plane Daemon        deps: Kernel, Store File, Runner
  composition: kernel over chosen store, sweep ticker, runner supervision,
  graceful shutdown

control-plane (executable)  deps: Daemon, swift-uuids
  demo/ops CLI: submit / run / status / replay
```

Dependency direction is strictly downward onto `Kernel`; the daemon is the only
composition point. Tests: one test target per source target ([TEST-033]).

**Reuse adjudication** (per [ARCH-LAYER-011] and "reuse where they genuinely fit"):

| Package | Verdict | Reason |
|---------|---------|--------|
| swift-json | USE | canonical JSON value + `JSON.Serializable`, deterministic `sortKeys` encoding, typed throws |
| swift-file-system | USE | append, atomic write with fsync modes (`File.System.Write+Shared.swift:188-189`), directory ops |
| swift-uuids | USE (CLI only) | client-side command/job id generation (v4); the kernel never generates ids |
| swift-scheduler | NOT FIT | ratified as the L3 engine-free *recurring scheduled job* interface (cron-shaped); v3 is a durable at-least-once queue with leases — different concern. Revisit only if v3 grows cron-style triggers, which would then *consume* swift-scheduler. |
| swift-records / swift-sql-postgres | NOT NOW | both currently ride vapor/postgres-nio, excluded by the no-NIO constraint; the Postgres adapter targets swift-postgresql-standard (§9) |
| swift-arguments | DEFERRED | slice-1 CLI is three demo subcommands; adopt when the daemon control API and real operator CLI land. Recorded as debt, revisit at that phase. |
| swift-dependencies | NOT NEEDED | the kernel's only ambient dependencies (clock, ids) are already externalized into command envelopes by design; there is nothing to inject |

**Extraction posture**: no extraction now ("do not invent packages"). The kernel target
is zero-dep by construction, so the future boundary is already measured: if/when the
event-sourcing substrate (store protocol + fold discipline) proves domain-coherent
independently of job orchestration, it extracts along the existing target seam per
[ARCH-LAYER-008] (correctness-driven, never consumer-count-driven). Until then, one
package, internally proven targets.

**Two recorded deviations** (surfaced for Principal review, per collaboration protocol):

1. **Testing**: plain `.testTarget` + toolchain-bundled Swift Testing, not the institute
   nested `Tests/Package.swift` pattern ([INST-TEST-001]/[TEST-024]). Reason: prototype
   outside the published ecosystem orgs; no snapshot-testing need; keeps the resolve
   graph minimal for the crash/replay test matrix. Migrates to the nested pattern at
   graduation.
2. **Namespace**: `Control.Plane` transliterates the two-word domain term at the word
   boundary (precedent: `File.System`). Alternatives (`Orchestrator`, bare `Plane`)
   rejected: the first breaks package↔namespace correspondence with the given package
   path, the second is meaningless alone.

## 9. Local-to-SaaS evolution

The kernel is transport-, tenant-, and backend-agnostic by construction; SaaS is
adapters plus one new envelope field family. Direction, not commitment:

- **Tenancy**: `Tenant.ID` on the command/event envelope and on every aggregate id
  (jobs become `(tenant, job)`); the fold partitions by tenant; the store partitions
  streams by tenant. Single-tenant local mode is the degenerate case (fixed tenant).
- **Authentication**: institute identity stack (swift-identities, swift-oauth,
  swift-basic-auth) at the API edge; the kernel sees only an authenticated
  `Actor.ID` stamped into the command envelope (as `at` is today).
- **Authorization**: the Policy aggregate (§6 port of v2 governance): policies are
  events too; the decide step consults the policy projection — same idempotency and
  replay properties as everything else. Edit-zone/scope enforcement stays at the runner
  boundary.
- **Secrets**: swift-secrets at the daemon/runner edge (backend credentials); never in
  events (events are the audit log; secrets in events would make replay a leak).
- **Audit**: the event log *is* the audit log — append-only, actor-stamped,
  content-digested. A read-model formats it; no parallel audit pipeline.
- **Billing**: a billing projection over the same events (job-seconds, attempts,
  backend tokens from outcome metadata) per tenant; swift-stripe at the edge. Projections
  are replayable, so billing is retro-computable and disputable from first principles.
- **Regional isolation**: one store per region; tenants pinned to regions at the routing
  edge; no cross-region streams. The kernel is region-blind.
- **API**: the command/receipt/projection surface is the API; HTTP is a codec over it
  (swift-http + swift-uri-routing when warranted — explicitly not Vapor/NIO). Local mode
  keeps the Unix-socket/CLI transport.
- **Dashboard**: read-only projection views (swift-html/swift-server-foundation stack);
  advisory live updates via long-poll on projection versions — notifications stay
  advisory even in the UI.
- **Remote runner fleet**: runners authenticate as actors, `claim` over long-poll HTTPS
  (poll is already the correctness path, so remote runners change nothing semantically),
  lease fencing already covers partitions/zombies. Backend adapters run fleet-side.
- **PostgreSQL adapter**: `Store.Postgres` over the pure institute stack
  (swift-postgresql-standard L2 wire protocol + swift-sockets + swift-transport-layer-security;
  explicitly not PostgresNIO). Schema: `events(global_seq bigserial, tenant, aggregate,
  aggregate_seq, command_id, at, kind, payload jsonb)` with a **unique index on
  (tenant, command_id)** — the dedup invariant becomes a database constraint, and
  append+dedup becomes one transaction. Projections move to transactional read models
  when scale demands; until then the fold-on-boot model carries over unchanged.

## 10. Migration / shadow / cutover from v2

- **Phase 0 — coexistence (now)**: v3 is a sibling; v2 stays audit-only per policy
  `v2-audit-only-direct-execution`. No shared state.
- **Phase 1 — shadow reads**: a v3 importer folds v2's `work-events.jsonl` /
  `seat-events.jsonl` into v3 read models (v2 event shapes are seq-ordered JSONL with
  stable kinds — mechanical mapping). Dashboards/status read v3 projections; writes stay
  v2. Parity check: v3-generated STATUS view vs v2 `workspace-state.py` output over the
  same log.
- **Phase 2 — new work on v3**: new arcs/jobs are submitted to v3; v2 items drain to
  terminal states. The v2 work-item vocabulary (acceptance, oracle, evidence) maps onto
  job payload/outcome contracts; the Policy aggregate ports v2 governance claims.
- **Phase 3 — cutover**: when no OPEN v2 work remains, v2 logs are archived read-only
  (they stay replayable forever); the park/channel machinery is retired. Rollback at any
  phase = stop submitting to v3; v2 was never modified.
- Explicitly out: no in-place mutation of v2 stores, no bidirectional sync (one-way
  import only), no big-bang identity migration (v2 work ids become v3 job ids verbatim).

## First vertical slice (the executable claim of this design)

Two independent jobs submitted; two owned runner loops claim them; one runner is stalled
or killed; the other job completes unaffected; the failed job's lease expires and it
requeues safely; the daemon restarts and replays to identical state; a repeated command
id proves idempotent; and nothing in any of that depends on a filesystem watcher or an
interactive-session wake.

**Verification matrix** (each row = tests in the slice):

| Claim | Verification |
|-------|--------------|
| State machine sound | exhaustive transition tests: every command × every phase, accepted and rejected paths |
| Replay determinism | fold(log) == live state after arbitrary command sequences; file-store reopen equivalence |
| Idempotency | duplicate command ids return recorded outcomes, zero new events; payload mismatch fails closed |
| Lease/fencing | expiry requeues; stale-lease renew/report rejected; reclaim-then-zombie-report rejected |
| Cross-job isolation | killed/hung runner leaves the other job's full lifecycle unaffected |
| Crash boundaries | torn-tail truncation; append-then-crash-before-reply → retry dedups; no partial command batches observable |
| No-wake correctness | the whole suite runs with zero watchers/signals; sweep driven by explicit instants |

## Outcome

Design fixed; implementation of the vertical slice proceeds under this record. Deviations
from this document require amending it first (no-drift rule).
