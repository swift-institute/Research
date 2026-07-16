# Control Plane v3 — Slice-1 Report

<!--
---
version: 1.0.0
last_updated: 2026-07-16
status: CHECKPOINT REPORT (tested local kernel + CLI reached; no architectural blocker)
scope: swift-institute/swift-control-plane, Research/Control-Plane-V3
changelog:
  - 1.0.0 (2026-07-16): Slice-1 completion report. Authored by the Control-Plane-V3
    bootstrap task (outside the v2 scheduler, per Principal direction and policy
    `v2-audit-only-direct-execution` r1).
---
-->

## Verdict

The first vertical slice of Control Plane v3 exists, builds, and is verified: a
Swift-native, event-sourced, command-idempotent job-orchestration kernel with owned
runner loops, per-job lease fencing, a deterministic in-memory store, a durable local
JSONL store with torn-tail self-healing, a daemon composition root, and a minimal CLI.

- **Test gate: GREEN** — `Scripts/gate.sh --test` on `swift-control-plane`: exit 0,
  zero `error:` lines over the whole log, SwiftPM completion line present,
  **65 tests in 24 suites passed**, toolchain **asserted** as `swift-6.3.3-RELEASE`
  (`org.swift.633202606251a`) by the gate's preflight — not assumed.
- **Live demo: PASS (exit 0)** — `control-plane demo` executed the entire required
  scenario against a real file store with the real clock: two independent jobs, a
  hung runner isolated, a hard kill with no goodbye, lease-expiry requeue via sweep,
  completion by the surviving runner, a verbatim-replayed command id deduplicated
  (recorded effect at seqs 1...1, nothing re-executed), and a second kernel booted
  over the same log folding to identical state (13 events). No filesystem watcher,
  signal, or session wake anywhere.
- **No outward actions**: no pushes, no GitHub repo creation, no deploys, no v2
  modification (v2 was inspected read-only). All work is local commits.

## Mandate compliance

| Constraint | Status |
|---|---|
| Outside the v2 scheduler; no seats/channels/waiters/receipts | Honored — direct execution under policy `v2-audit-only-direct-execution` r1 |
| Read AGENTS.md; load canonical skills | Done (swift-institute-core → swift-institute → modularization, implementation, testing, existing-infrastructure) |
| Git/dirty-state recheck before writing | Done — Research was dirty only in unrelated files (untouched); prototype path did not exist |
| v2 inspected read-only | Done — no v2 file modified |
| Design/provenance record before substantive implementation | Done — committed `3a91b4f` before the first source file |
| Swift; no Vapor/SwiftNIO/PostgresNIO | Honored — dependency closure is institute-only (swift-json, swift-file-system, swift-uuids) + stdlib |
| Reuse institute packages where they genuinely fit; no invented packages | One package, five targets; reuse adjudication table in design.md §8 (incl. why swift-scheduler and swift-records do NOT fit) |
| Worker loop owned by our process; models as adapters | Kernel/Runner/Daemon design axiom 1; `Backend` protocol seam with `Fake` shipped, `Process` next |
| Idempotent commands; at-least-once-safe effects; durable replay; advisory notifications | Verified by tests (below) |
| Storage abstracted; memory + local durable now; institute-Postgres designed | `Store.Protocol` + `Memory` + `File`; Postgres schema designed (design.md §9), not built |
| No network transport in slice 1 | CLI/daemon only |

## Artifacts

**Design and provenance** (git: `swift-institute/Research`, branch `main`):

| Path | Commit |
|---|---|
| `/Users/coen/Developer/swift-institute/Research/Control-Plane-V3/provenance-and-failure-corpus.md` | `3a91b4f` |
| `/Users/coen/Developer/swift-institute/Research/Control-Plane-V3/design.md` | `3a91b4f`, amended `7d555e8` (flock deferral) |
| `/Users/coen/Developer/swift-institute/Research/Control-Plane-V3/REPORT-slice-1.md` | this file |

**Prototype repository** (new local git repo, no remote):

| Path | Commits |
|---|---|
| `/Users/coen/Developer/swift-institute/swift-control-plane/` | `da8b75e` (kernel + adapters + tests), `e66e3d7` (gate-green fixes; evidence in message) |

Inventory: 51 source files (~2,042 lines) across five targets — `Control Plane Kernel`
(zero dependencies), `Control Plane Store File`, `Control Plane Runner`,
`Control Plane Daemon`, `control-plane` (executable) — plus 6 test files
(~1,366 lines) in four test targets (one per source target per [TEST-033]).

## What the v2 inspection established (full record: provenance-and-failure-corpus.md)

All nine observed failures reduce to two substrate gaps: (1) **no durable owned
worker** — wake was a best-effort relay through background-task completion into
interactive sessions (failures: waiter-fires-no-resume, lost wake after command
success, duplicate delivery); (2) **liveness inferred, not owned** — flock presence +
heartbeat age, with `pid_alive` imported but never called (stale-green coverage,
manual receipt recovery, dead-owner state needing human fencing). The compensating
machinery caused the rest itself: a single workspace-wide transaction flock and
globally-aggregated readiness (head-of-line blocking), a whole-store horizon digest
(plans staled by unrelated traffic), and membership-only `reply_to` validation
(poison references admitted at append). Every mechanism is cited to file:line in the
provenance record.

v2's durable core was sound and v3 keeps its shape: caller-supplied command ids with
recorded outcomes and payload-digest fail-closed reuse; seq-validated fail-closed
reducers; single-write O_APPEND appends; canonical sorted-key JSON. v3 deletes the
park/mux/receipt/canary/boot-plan/notification-ledger layer entirely (dissolution
table in the provenance record) and collapses v2's INTENT→COMPLETED two-phase command
ledger into "the event is the receipt" (atomic per-command batch append; crash-before-
reply resolved by dedup on retry).

## Design essentials (full record: design.md)

Five axioms: owned worker loops; advisory-only notifications (polling is the
correctness path); idempotent commands; events as the only truth (clock-free,
RNG-free fold — every command carries its ingress instant; lease ids derive from
command ids); per-job lease-based liveness with fencing tokens, no global locks.

Job state machine: `queued → running → succeeded | failed | canceled` (terminal),
with `requeued` (expiry / timeout / retryable failure, backoff-gated) and `parked`
(dead letter, inert; explicit `requeue` revives). Commands: submit, claim (FIFO,
backoff-gated), renew (rejection with `.cancelRequested` is the stop directive),
report (lease-fenced), cancel (two-phase for running), requeue, sweep (naturally
idempotent), register/retire. Store contract: atomic per-command batch append,
strictly monotonic seqs, append-before-apply, replay equivalence, torn-tail
self-healing (improves on v2's fail-closed manual truncation).

Namespace: `Control.Plane` (precedent `File.System`). Typed throws throughout;
strict memory safety, ExistentialAny, InternalImportsByDefault, MemberImportVisibility,
NonisolatedNonsendingByDefault enabled; Foundation-free.

## Verification evidence

Gate command (self-verifying; asserts the resolved compiler, refreshes pins first,
cross-checks exit status vs `error:` lines vs completion line):

```
Scripts/gate.sh --test /Users/coen/Developer/swift-institute/swift-control-plane
→ GREEN — exit 0 · 'error:' lines 0 · "Build complete!" present
→ Test run with 65 tests in 24 suites passed
→ toolchain resolved: Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
```

(Gate logs land in `$TMPDIR/institute-gate/swift-control-plane/` — ephemeral; the
command above reproduces them. The durable evidence is the suite in the repo.)

| Required control | Where verified |
|---|---|
| Exhaustive state transitions | `Tests/Control Plane Kernel Tests/Control.Plane.Decision Tests.swift` — every command kind × phase, accepted and rejected paths: FIFO order, backoff gating (idle at t−1 ms, claimable at the boundary), attempt exhaustion → dead letter, revival resets attempts, two-phase cancel, register/retire no-ops |
| Fail-closed fold | `…/Control.Plane.State Tests.swift` — sequence gap, unknown-job event, duplicate submit, stale-lease terminal, non-contiguous command batch, double cancellation flag, double register, requeue-from-terminal: all throw |
| Duplicate-command controls | decide-level (`duplicate` returns recorded seqs, zero appends; same id + different payload → `payloadMismatch` fails closed) and kernel-level (repeat after restart still dedups — the index is derived from the log, not process memory) |
| Crash boundary: append → reply | `…/Control.Plane.Kernel Tests.swift` — kernel A appends and "dies" before replying; retry against kernel B over the same store returns `duplicate`, effect exists exactly once |
| Crash boundary: torn tail | `Tests/Control Plane Store File Tests/…` — a partial final line containing a two-event batch is dropped whole on reopen; the next append lands at the correct seq; a complete-but-invalid middle line is corruption (never truncated); a non-contiguous batch fails closed |
| Replay determinism | fold == live state after mixed command scenarios (memory and file stores); file-store reopen equivalence; encoding canonicalism (identical events → identical bytes) |
| Runner death / lease expiry | killed loop reports nothing (event count pinned); sweep requeues exactly the lapsed lease; zombie renew AND zombie report bounce off the lease fence after reclaim |
| Timeout vs renewal | a dutifully renewed lease cannot save a hung backend: sweep enforces the per-attempt timeout from the claim instant |
| Cross-job isolation | decide-level (sweep touches only the lapsed job) and loop-level (hung runner + healthy runner over two jobs; the other job completes; the abandoned one requeues and completes after the kill) |
| No wake on the correctness path | the entire suite runs on owned loops, explicit instants, and yield-based test clocks; the daemon's own sweeper recovers an orphaned lease in real time with no external signal |

Live CLI demo (real clock, real file store; run 2026-07-16):

```
.build/debug/control-plane demo <path>   → exit 0
  1. two independent jobs submitted (a, b)
  3. isolation proven: one job succeeded while the other is hung
  4. hard kill of the hung runner (no goodbye, no report)
  5–6. sweep expires the orphaned lease; surviving runner completes the job
  7. duplicate command id → recorded effect at seqs 1...1, nothing re-executed
  8. second kernel over the same log → identical state (13 events)
  final: a succeeded, b succeeded
.build/debug/control-plane replay <path> → "two independent folds of 13 events are identical"
.build/debug/control-plane status <path> → events: 13, jobs: 2, commands: 13
```

Reproduce end-to-end:

```
Scripts/gate.sh --test ~/Developer/swift-institute/swift-control-plane
cd ~/Developer/swift-institute/swift-control-plane
TOOLCHAINS=org.swift.633202606251a swift build --product control-plane
./.build/debug/control-plane demo /tmp/cp-demo-$$.jsonl
./.build/debug/control-plane replay /tmp/cp-demo-$$.jsonl
```

## Deviations surfaced for Principal review

1. **Testing pattern** — plain `.testTarget` + toolchain-bundled Swift Testing, not
   the institute nested `Tests/Package.swift` ([INST-TEST-001]/[TEST-024]). Reason:
   prototype outside the published orgs; no snapshot-testing need; smaller resolve
   graph for the crash/replay matrix. Migrates at graduation. (design.md §8)
2. **Single-instance lock deferred** — by operational convention in slice 1; design
   amended in place (`7d555e8`). *(⚠️ ERRATUM 2026-07-16, Principal pointer: this
   deviation originally claimed "swift-file-system vends no flock surface" and framed
   an upstream addition as the fix — a token-grep false zero over the wrong scope.
   The institute lock surface already exists: `ISO 9945 Kernel Lock` (fcntl record
   locking with a `~Copyable Token`; releases on process death) + `POSIX Kernel
   Lock`. The follow-up is CONSUMING it in `Store.File` at the multi-daemon
   graduation gate, not building it. Corrected in design.md §5 invariant 7.)*
3. **swift-arguments deferred** — the slice-1 CLI is four subcommands; adoption is
   scheduled with the daemon control API. (design.md §8)

Implementation choices consistent with the design but worth knowing: `Reject`
conforms to `Swift.Error` (enables `Result` plumbing in `decide`; rejections remain
receipt values, never kernel throws); `Store.Memory` is internally synchronized
(Mutex) and `Sendable` so crash-boundary tests can hand one log to a successor
kernel — the in-memory analogue of two daemon incarnations opening one file.

## Field notes (for the gotcha corpus)

- **Silent String rebinding fired twice, in two distinct shadow zones**: `import
  File_System` (via swift-strings) and the `UUIDs` `@_exported` chain (via
  String_Primitives) both rebind bare `String` to institute string types. Symptoms
  were two steps removed from the cause ("parameter of noncopyable type 'String'",
  "cannot infer contextual base"). Both zones are annotated in-source; fixes:
  fully-qualified `Swift.String` (Store File) and a file-scope
  `private typealias String = Swift.String` (CLI).
- The kernel caught one wrong **test expectation** (sweep backoff arithmetic) — the
  fold was right, the assertion was wrong; corrected with a comment.
- One real test race found and closed by reasoning, not flake-chasing: an in-flight
  lease renewal at kill time could extend the lease past a single manual sweep;
  fixed by awaiting the killed task's full termination before advancing test time.

## Follow-ups (dispatch stays with the Principal — none started)

1. `Backend.Process`: headless model CLI adapters (`claude -p`, codex exec) via
   swift-process; edit-zone enforcement at the runner boundary (worktrees).
2. Unix-domain-socket control API on the daemon (institute swift-sockets), so the
   CLI can talk to a live instance; then swift-arguments adoption.
3. Policy aggregate: port of v2 governance claims (re-read `governance.py` at port
   time), as events with the same idempotency/replay properties.
4. `Store.Postgres` over the pure institute stack (swift-postgresql-standard +
   swift-sockets + swift-transport-layer-security; explicitly not PostgresNIO).
   Schema designed: unique `(tenant, command_id)` makes dedup a DB constraint.
5. Migration Phase 1 (design.md §10): one-way importer folding v2
   `work-events.jsonl` / `seat-events.jsonl` into v3 read models; parity check
   against `workspace-state.py` output. v2 stays untouched throughout.
6. swift-file-system flock surface (deviation 2 above).
7. Snapshots/compaction: shape reserved (state at seq N + tail replay); not needed
   at institute log volumes.

## Migration position

Phase 0 (coexistence) is the current state: v3 is a sibling with no shared state; v2
remains live and audit-only per policy. Rollback at any later phase is "stop
submitting to v3" — v2 was never modified.
