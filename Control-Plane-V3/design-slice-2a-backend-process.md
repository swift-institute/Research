# Control Plane v3 — Slice 2A Design: Backend.Process

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: DESIGN RECORD (Slice 2A authorized by Principal; deviations 1–3 of slice 1
        accepted under graduation gates: canonical test arrangement before
        publication; filesystem lock before multi-daemon/production; swift-arguments
        with the daemon control API)
scope: swift-institute/swift-control-plane — Control Plane Backend Process target
changelog:
  - 0.1.0 (2026-07-16): Initial design. Companion to design.md (whose §4 backend
    seam this implements) and REPORT-slice-1.md.
---
-->

## Mission

Owned headless-process adapters for Claude and Codex behind the existing
`Control.Plane.Runner.Backend` seam. The subprocess is fully owned: direct argv
spawn, sanitized environment, bounded capture, its own session/process group,
graceful-then-hard kill, always reaped. No Workspace-v2 integration; no socket API.

## Recon facts this design stands on (verified 2026-07-16)

- Institute stack: `ISO_9945.Kernel.Process.Spawn.spawn(path:argv:envp:actions:)`
  with `Actions` supporting `dup2`/`close`/`chdir`/`open`; **no spawn attributes**
  (`attrp` is `nil` at `ISO 9945.Kernel.Process.Spawn.swift:92,157`) — so no
  `POSIX_SPAWN_SETPGROUP` through the stack today. `Session.create()` (setsid),
  `Execute.execve`, `Kill.kill(ID, Signal.Number)` with `ID(rawValue: Int32)`
  public (negative pid ⇒ POSIX group kill), `Wait` with `.group` selector, and
  `Kernel.Pipe` (ISO 9945 Core) are all public. `Environment.read(_:)`
  (swift-environment) reads single variables by name.
- `swift-process`'s public `run` is synchronous full-drain with a
  SIGKILL-child-only deadline: no process group, no TERM grace, no bounded
  capture, not cancellation-aware. Its internal `_spawnWithActions` is not public.
- CLIs on this machine: `claude` 2.1.211 at `~/.local/bin/claude`
  (`-p/--print`, `--output-format json`, `-r/--resume <session-id>`,
  `--permission-mode`); **`codex` is not installed** (PATH, cargo, brew, local
  checked).

## Process-group ownership: the trampoline decision

Adding spawn-attribute support upstream (ISO 9945 → swift-posix → swift-process)
is the canonical fix but a three-package cascade mid-slice. Slice 2A instead ships
a ~20-line trampoline executable in this package:

- `control-plane-exec`: `argv = [self, executable, args…]` → `Session.create()`
  (setsid: new session, new process group, no controlling terminal) →
  `execve(argv[1], argv[1…], environ)`. The host spawns the trampoline with the
  already-sanitized envp, so the trampoline's own environ is exactly the child's
  intended environment.
- The child is therefore its own session/group **leader**, pgid == pid, and
  `kill(-pid, SIG*)` owns the entire tree (model CLIs spawn grandchildren).
- Flagged upstream improvement (sibling of the flock flag): spawn `Attributes`
  (`POSIX_SPAWN_SETPGROUP`/`SETSID`) in swift-iso-9945 + pass-throughs; the
  trampoline retires when that lands.

## Host engine (`Control.Plane.Runner.Host`)

The process-execution engine both adapters share. New target
`Control Plane Backend Process` (deps: Kernel, Runner, JSON, Environment,
POSIX Kernel Process/Signal, ISO 9945 Core).

- **Direct spawn only**: argv arrays end-to-end; no shell anywhere in the adapter
  path. (Test fixtures may exec `/bin/sh` with FIXED literal scripts to obtain
  signal-ignoring behavior; fixtures never interpolate data into shell strings.)
- **Environment allowlist**: child env = values of `Configuration.allowlist`
  names read from the daemon's environment (via swift-environment) + explicit
  `Configuration.environment` pairs. Nothing else. Failures and diagnostics may
  name variable NAMES, never values — no secret logging by construction (the
  host has no logging surface at all).
- **Bounded capture**: stdout/stderr drained concurrently (one blocking-read
  task per pipe — cancellation-safe because the group kill forces EOF, which
  unblocks the readers) into per-stream buffers capped at `Configuration.limit`
  bytes; overflow is discarded with a `truncated` marker. Reader threads: two
  per running job; acceptable at slice scale, noted as a later `poll(2)` upgrade.
- **Cancellation escalation**: `withTaskCancellationHandler` — on cancel:
  `kill(-pid, .terminate)`; an escalation task waits `Configuration.grace` then
  `kill(-pid, .kill)`. The child is ALWAYS reaped (`Wait`) — no zombies; ESRCH
  races are tolerated.
- **Edit-zone enforcement**: `Request.directory` must be an existing directory
  whose normalized absolute path sits under one of `Configuration.roots`
  (component-boundary prefix check on a pure normalizer — no Foundation). The
  child chdirs there via a spawn file action. Violations never spawn: terminal
  failure.
- **Result**: exit status (exited(code) / signaled(signal)), bounded stdout,
  bounded stderr, truncation flags. Timeouts are NOT host policy — the kernel's
  per-attempt timeout (sweep) and lease loss cancel the backend task, which is
  the kill path (slice-1 semantics unchanged).

## Provider adapters

`Control.Plane.Runner.Claude` and `Control.Plane.Runner.Codex`, each a `Backend`
over a `Host`. Argv builders are pure functions (unit-tested without spawning).

- **Claude**: `[claude, -p, <prompt>, --output-format, json]`
  (+ `[--resume, <session>]` when the payload carries one). Stdout parses as one
  JSON object; `result` → outcome body (bounded), `session_id` → outcome session,
  `is_error` → failure. Live-verified against claude 2.1.211.
- **Codex**: `[codex, exec, --json, <prompt>]`
  (+ resume via `[codex, exec, resume, <session>, <prompt>]`). Stdout is JSONL;
  the adapter extracts the thread/session identifier and final agent message
  best-effort, falling back to raw bounded output as the body. **UNVERIFIED-LIVE**
  (CLI not installed here): shape from the documented interface, fixture-tested;
  the live control runs on a machine with codex present before this adapter is
  relied on.
- Failure mapping: spawn-not-found / zone violation / payload missing directory →
  terminal (`retryable: false`); nonzero exit or signal → `retryable: true`
  (bounded by `attempts.max`; stderr tail in the reason, bounded); task
  cancellation → the runner discards the report anyway (hard-kill fidelity).
- **Session retention for continuation**: outcome carries the provider session
  identifier durably; a follow-up job carries it back in its payload
  (`outcome.session` of job N → `payload.session` of job N+1).

## Kernel schema extension (amends design.md §1/§6 shapes)

Kernel stays interpretation-free; two vocabulary slots widen:

- `Job.Payload` gains `directory: String?` (the declared edit zone — design.md §6
  already names the concept; enforcement stays at the runner boundary) and
  `session: String?` (provider-session continuation input).
- `Job.Outcome` gains `session: String?` (provider-session continuation output).
- Ripples: submit fingerprint canonical string, JSON codec (null-tolerant),
  round-trip tests. Pre-1.0 prototype: no persisted-log migration owed; noted
  that old demo logs are invalidated by the fingerprint change.

## Verification plan

- Host: spawn/cwd (pwd in temp dir), allowlist (env fixture sees only allowed
  names), bounded capture + truncation, exit/signal mapping, TERM-graceful death,
  TERM-ignoring fixture forces KILL escalation within grace bound, group kill
  reaps the whole fixture tree, zone violations (outside root, relative,
  nonexistent) never spawn, reap-always (no zombie after any path).
- Adapters: argv builders (with/without resume), stdout parsing (canned strings:
  success, error, malformed), end-to-end against a canned-JSON fixture script,
  runner-loop integration to `succeeded` with session retained in the event log.
- Kernel: schema round-trips; fingerprint sensitivity to the new fields.
- Live smoke (opt-in: `CONTROL_PLANE_LIVE_SMOKE=1`, default-out per [TEST-040]
  discipline; skipped cleanly when the CLI is absent): trivial no-tool prompt in
  an empty temp zone; assert exit 0, non-empty body, session id captured. Claude:
  runnable here. Codex: reported absent.
- Kill/fence/crash properties re-verified at the kernel level are NOT re-proven
  per-adapter (slice-1 suites own them); the process slice proves the OS-side
  halves (group kill, reap, EOF-on-death).

## Explicitly out of slice 2A

Workspace-v2 integration; socket API; upstream spawn-attributes cascade
(flagged); poll(2)-based drain; codex live verification (machine lacks the CLI);
OS-orphan adoption after a daemon crash (lease fencing already makes such
orphans harmless to correctness — they burn compute only; documented limitation
for the ops story).
