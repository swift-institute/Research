# Control Plane v3 — Provenance and Failure Corpus

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: PROVENANCE RECORD
scope: workspace control plane (v2 → v3)
changelog:
  - 0.1.0 (2026-07-16): Initial v2 inspection record, failure-mechanism map, retain/reject
    dispositions. Authored by the Control-Plane-V3 bootstrap task (outside the v2 scheduler,
    per Principal direction and policy `v2-audit-only-direct-execution` r1).
---
-->

## Context

Workspace v2 coordinates interactive Claude/Codex sessions through filesystem JSONL event
stores plus ad-hoc "park" waiter subprocesses. The Principal directed a clean v3 bootstrap
outside that scheduler: a Swift-native control-plane kernel whose worker loop is owned by our
own durable process, with model backends as adapters, evolvable into a multi-tenant SaaS.

This record fixes the evidence: what v2 actually is, the mechanism behind each observed
failure, and which v2 concepts v3 retains versus rejects. The companion `design.md` carries
the v3 design decisions. Neither document authorizes outward actions (no pushes, no repo
creation, no deployment).

## Question

Which parts of v2 are substrate-compensation (and dissolve under an owned worker loop over a
durable store), and which parts are load-bearing domain semantics that v3 must preserve?

## Evidence scope

v2 implementation, inspected read-only on 2026-07-16:

- `swift-institute/Scripts/workspace-control.py` (1,335 lines — CLI dispatch)
- `swift-institute/Scripts/workspace_control/runtime.py` (5,143 lines — channels, cursors,
  authority, runners, commands, receipts, notifications, park loops, report/ready/check)
- `swift-institute/Scripts/workspace_control/common.py` (298 lines — atomic_write,
  append_jsonl, flock lifetime locks, read_jsonl)
- `swift-institute/Scripts/workspace_control/governance.py` (1,246 lines — claims, policies,
  acknowledgments)
- `swift-institute/Scripts/workspace_control/boot.py` (BootPlanner — cold-start plans,
  launch manifests)
- `swift-institute/Scripts/workspace-state.py` (1,815 lines — canonical work/seat
  projections, generated views)

Durable data: `Workspace/control/*.jsonl` (authority, runner, command, receipt,
notification, work, seat, claim, policy event logs) plus generated views. Volatile data:
`Workspace/runtime/` (per-waiter coverage files, mux state, flock sidecars).

Corroborating live-failure provenance:
`Research/Reflections/2026-07-15-workspace-seat-control-plane-and-cold-start-boundary.md` —
the measured channel defects and the root-cause statement that "the protocol's reliable
state depends on a multi-step behavioral epilogue" (process → ack → re-arm → verify), i.e.
correctness rests on disciplined end-of-turn conduct by interactive sessions rather than on
a mechanism.

## v2 architecture in one paragraph

There is no daemon. Every operation is an ad-hoc CLI invocation serialized by a single
workspace-wide transaction flock (`runtime.py:74-76`). The only long-lived processes are
polling "park" loops (`park_endpoint` `runtime.py:3819`, `park_workspace` `:4099`) that an
interactive session launches as background tasks; wake-up relies on the harness re-invoking
the model when that subprocess exits (`boot.py:649-655`). Delivery acknowledgment is a
durable receipt layer (RECEIVED → PROCESSED) keyed by cursor position; readiness is proved
by two-cycle canaries counting FIRED notifications; cold start pins a digest over every
byte of `control/` and `channels/` and aborts on any change.

## Failure mechanism map

The nine observed failures, each with its code-level mechanism (file:line cites are into the
v2 sources above):

| # | Observed failure | Mechanism |
|---|------------------|-----------|
| a | Waiter fires but interactive model task does not resume | `_fired_endpoint` durably records FIRED and the park process exits (`runtime.py:4061-4097`); nothing pushes to the model. Resumption is delegated entirely to the session substrate re-invoking the model on background-task completion (`boot.py:649-655`). Wake is decoupled from the durable FIRED record. |
| b | Dead waiter leaves stale/green-looking coverage | Coverage files are passive artifacts (`write_runtime` `runtime.py:2872`); nothing actively invalidates a dead waiter's file. Health is pull-derived on demand (`_coverage_health` `:4547`) from flock presence + heartbeat age; a waiter dying just after a heartbeat reads green until someone runs `report` after `max_age`. |
| c | One ambiguous arc blocks unrelated launches | A single transaction flock serializes every mutation (`runtime.py:76` et al.); `report`/`ready` aggregate failures globally and fail whole-workspace readiness on any endpoint (`:4717-4726`, `:5098-5113`); boot forces `mode="BLOCKED"` with empty `next_commands` on any ambiguity (`boot.py:517-519`). |
| d | Invalid `reply_to` references | `_validate_reply` (`runtime.py:2005-2021`) checks only that `reply_to` is *some* opposite-direction message id in the current generation — not newest, unanswered, or current-runner. Semantic validity is re-checked only at report time (`:4915-4931`), after the append. |
| e | Command succeeds but response/task wake is lost | `send` (`runtime.py:2323`) appends the message and completes the command durably (`:2483`) with zero coupling to the recipient's waiter. A message to an absent endpoint sits pending with no active wake. |
| f | Global plans become stale through unrelated traffic | `horizon()` digests every file under `control/` and `channels/` (`runtime.py:5121-5131`); boot plans pin that digest (`boot.py:526`) and `ready` aborts on any byte change (`workspace-control.py:859-891`). Any unrelated append invalidates every in-flight plan. |
| g | Restart during receipt processing | The RECEIVED receipt is durable with no liveness signal (`runtime.py:2598`). Replay is idempotent (`:3396-3409`, `:3890-3902`), but if the runner is gone, the outstanding receipt can only be cleared by an explicit Principal-evidenced `recover_seat`/`recover_workspace` (`:3600`/`:3469`) — liveness resolution is manual and authority-gated. |
| h | Duplicate delivery | Notification is at-least-once by design: the park loop re-fires on any pending (`runtime.py:4005-4009`). Dedup exists only positionally at the receipt/cursor layer (`message_ids` + `batch_sha256`, `:2569-2581`; PROCESSED requires `cursor == from_seq-1`, `:3782-3786`). There is no delivery id. |
| i | Controller/runner death while locks/state live | Lifetime locks are flock-based and auto-release on death (`common.py:193`), but the durable state they guarded (authority ACQUIRED, runner ACTIVATED, PROCESSING receipt, ARMED coverage) stays "live". Liveness is inferred from flock + heartbeat age only — `pid_alive` is defined (`common.py:183`) and imported (`runtime.py:32`) but never called. Clearing requires a human-authorized fence command (`takeover` `:1574`). |

**The two-gap summary.** Every failure above reduces to one of two substrate gaps:

1. **No durable owned worker.** "Wake" is a best-effort relay through background-task
   completion into an interactive session that may or may not resume (failures a, e, h).
2. **Liveness is inferred, not owned.** flock + heartbeat age stand in for a supervising
   loop; dead owners leave live-looking durable state until a human fences them out
   (failures b, g, i). The compensating machinery — global locks, whole-horizon digests,
   canaries — then creates its own failures (c, f), and validation deferred past append
   admits poison records (d).

## What v2 got right (retain in v3)

The durable core is sound and v3 keeps its shape:

- **Command-id idempotency.** Every mutating operation takes a caller-supplied
  `command_id`; re-running with the same payload digest returns the recorded outcome;
  a different payload under the same id fails closed (`runtime.py:856-894`). v3 keeps
  caller-supplied command ids with recorded outcomes as the primary idempotency key.
- **Event-sourced, fail-closed projections.** Reducers are pure functions over seq-ordered
  logs, validating `seq == expected` and unique `event_id` (`workspace-state.py:197`,
  `runtime.py:1462, :2496`). Replay of a durable log is deterministic because timestamps
  and ids are captured into events at write time. v3 keeps: canonical state is a
  deterministic fold; the kernel never reads a clock or RNG during the fold.
- **Crash-safe append discipline.** Single `os.write` of a full canonical line under
  `O_APPEND` + fsync; parent-directory fsync on creation; metadata via
  temp+fsync+rename (`common.py:89-163`). v3 keeps the discipline, and improves the
  torn-tail story: v2's `read_jsonl` fails closed on a newline-less final line and requires
  manual truncation (`common.py:127-128`); v3 recovery self-heals by truncating a torn tail
  before reopening for append.
- **Authority epochs / fencing.** Single-writer authority as a `(controller_id, epoch,
  fence)` tuple with monotonic epochs (`runtime.py:49, :1462`). v3 generalizes this into
  per-job lease fencing tokens (a stale lease id can never complete a job) and a
  daemon-instance epoch.
- **Acceptance / DoD gates.** Work OPEN requires title + acceptance + verification + oracle;
  DONE requires evidence and terminal-governance MET (`workspace-state.py:207, :276`).
  Retained as job-payload/outcome contract concepts (kernel-opaque in the first slice).
- **Evidence digests.** Content digests threaded through claims, work DONE, receipts,
  commands. Load-bearing where they bind an outcome to bytes; v3 keeps outcome digests on
  job completion, and drops the re-digesting of the same bytes at every relay layer
  (receipt/notification/report), which was ceremony induced by the relay chain itself.
- **Work identity/ownership from the event log.** Ownership derives from canonical events,
  not from the channel (`runtime.py:2035-2095`). Retained: the job aggregate is the only
  owner of job state.
- **Policy/authority claims with independent attestation** (`governance.py:233-308`).
  Retained as a later Policy aggregate; not in the first vertical slice.
- **Edit zones** — currently vestigial in v2 (`boot.py:669-670` always emits
  `edit_zones: []`, and the gate can only block, never grant). The *concept* (a declared
  write-scope per job, enforced at the runner boundary) is retained in the design; the v2
  implementation is not.

## What v3 rejects (and why each dissolves)

Machinery that exists only to compensate for the filesystem/interactive-session substrate.
Under an owned worker loop consuming an event-sourced store, each becomes unnecessary:

| Rejected concept | Why it dissolves |
|------------------|------------------|
| Park waiters | A blocking poll simulating a subscription. An owned worker awaits the next event in-process. |
| Wake relays (background-task completion surfacing into a model task) | Exists only because an interactive model cannot block on a queue. The daemon's loops are the consumers; interactive sessions become clients. |
| Mux coverage | One waiter multiplexing N spokes because a session cannot hold N waiters. A real consumer reads all streams natively. |
| Receipt files as durable outstanding claims | Needed because file delivery had no ack channel. With consumer offsets in the store, the offset is the only ack; job effects are deduped by command id, not by delivery position. |
| Boot-plan readiness + horizon preconditions | Compensates for non-transactional cold start. The daemon resumes by folding the log; there is nothing to "plan". |
| Two-cycle canaries | A self-test that the substrate re-invokes the model on wake. Pointless when consumption is in-process. |
| Global transaction lock + whole-workspace horizon digest | Serialization moves into the kernel actor (and later per-aggregate optimistic concurrency); staleness is scoped per aggregate, so unrelated traffic cannot invalidate anything. |
| ARMED/FIRED/DISARMED notification bookkeeping | Notifications in v3 are advisory by axiom; correctness never depends on them, so their lifecycle needs no durable ledger. |
| INTENT→COMPLETED two-phase command ledger | v2 needed a write-ahead INTENT because effect and completion were separate appends across layers, with `recover_command` to resolve dangling intents (`runtime.py:1181`). v3 appends a command's full event batch in one atomic write: the event **is** the receipt. Crash before append = command never happened (client retries; dedup finds nothing; re-executes). Crash after append before reply = retry finds the recorded events by command id and returns the recorded outcome. No dangling-intent state exists. |

## Limits and uncertainties

- Line-number cites are into the v2 sources at inspection time (2026-07-16); v2 remains
  live under policy `v2-audit-only-direct-execution` and may drift.
- The inspection was performed by one agent pass plus targeted re-reads; counts and cites
  were not independently re-derived line-by-line. Nothing in the v3 design depends on a
  specific v2 line number — only on the mechanism classes, which match the live-failure
  reflection independently.
- v2's claim/policy governance layer was inspected for shape, not exhaustively; its v3
  port is deferred design (see `design.md` §6) and will re-read the source at port time.

## Outcome

v3 keeps v2's event-sourced, command-id-idempotent, fail-closed durable core and deletes
its entire notification/park/receipt/readiness compensation layer, by moving the worker
loop into a process we own and making all liveness lease-based. The design is in
`design.md` (same directory).

## References

- `Research/Reflections/2026-07-15-workspace-seat-control-plane-and-cold-start-boundary.md`
- `Research/SaaS-Vertical-Substrate/provenance-and-architecture.md` (canonical layering
  premises reused here; server-stack record: `swift-scheduler` is the L3 engine-free
  *scheduled recurring job* interface — a different concern from a durable at-least-once
  work queue; see `design.md` §8 for the reuse adjudication)
- Workspace governance policy `v2-audit-only-direct-execution` r1 (CLAUDE.md, generated
  block) — authorizes direct execution of this bootstrap outside the v2 scheduler.
