# Control Plane v3 — Slice 2A Interim Report / Handoff

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: INTERIM (implementation complete + compiling; final gate + live smoke +
        review-fold + commit pending). Written for handoff to Codex 5.6 Sol per
        Principal instruction (>10-minute gate cycles).
scope: swift-institute/swift-control-plane — Backend.Process
---
-->

## TL;DR

Slice 2A (Backend.Process) is **implemented and compiles clean**; on the last full
gate **87 of 88 tests passed**, and the single failure was a test-fixture bug (not a
product defect), now fixed. What remains is mechanical: confirm the re-gate is green,
fold in the independent-review findings, run the opt-in live smoke for `claude`, then
commit and write the checkpoint. This document is a complete handoff so any operator
(or Codex 5.6 Sol) can finish without reconstructing context.

## State of the world

**Committed** (nothing from slice 2A is committed yet):
- `swift-control-plane`: HEAD `e66e3d7` (slice 1 green). Slice-2A code is all in the
  working tree, uncommitted.
- `Research`: slice-2A design at `a2f7274`; lock-claim correction at `f877b1c`.

**Uncommitted working tree** (`swift-control-plane`):
- Modified (kernel schema extension): `Package.swift`,
  `Sources/Control Plane Kernel/Control.Plane.Job.Payload.swift` (+`directory`,
  +`session`), `…/Control.Plane.Job.Outcome.swift` (+`session`),
  `…/Control.Plane.Command.Kind+fingerprint.swift` (new fields in the canonical
  string), `Sources/Control Plane Store File/Control.Plane.Event+JSON.swift`
  (null-tolerant codec for the new fields), and the two touched test files
  (`…/Control.Plane.State Tests.swift`, `…/Control.Plane.Store.File Tests.swift`).
- New: `Sources/Control Plane Backend Process/` (host engine + adapters),
  `Sources/control-plane-exec/` (trampoline), `Tests/Control Plane Backend Process
  Tests/`.

**Build/test status**: the whole package compiles and links clean
(`swift build --package-path <pkg> --build-tests` → "Build complete!", exit 0). Last
full `gate.sh --test`: 87/88 passed; the one failure
(`cancellation TERMs a cooperative child promptly`) was fixed by making the fixture
`exec sleep 60` (see "Known issues"). A re-gate is running at handoff time.

## What was built (design: `design-slice-2a-backend-process.md`)

1. **Kernel schema extension** (additive, nil-default — no call-site churn):
   `Job.Payload.directory` (edit zone) + `.session` (continuation input);
   `Job.Outcome.session` (continuation output). Fingerprint + JSON codec + tests
   updated. Old demo logs are invalidated by the fingerprint change (pre-1.0,
   acceptable).

2. **`control-plane-exec` trampoline** (`Sources/control-plane-exec/main.swift`):
   `setsid` → `chdir(zone)` → `execv(target)`. Gives the child its own
   session/process group (pgid == pid) so `kill(-pid)` owns the whole tree. Exists
   because the institute spawn stack passes `attrp: nil` (no
   `POSIX_SPAWN_SETSID/SETPGROUP`) — flagged upstream improvement; trampoline retires
   when spawn attributes land. `execv` (not `execve`) deliberately inherits the
   sanitized environment the host constructed.

3. **Host engine** (`Control.Plane.Runner.Host`): direct argv `posix_spawn` via the
   trampoline (no shell); environment allowlist (names imported from the daemon env +
   explicit pairs, nothing else; values never logged); bounded concurrent `poll(2)`
   capture with truncation marker; TERM→grace→KILL escalation on task cancellation;
   always-reap (WNOHANG loop); pure lexical edit-zone containment (`Host.Zone`).

4. **Adapters** `Control.Plane.Runner.Claude` and `.Codex` over a shared `Provider`:
   pure argv builders (`argv(prompt:session:extra:)`, `package`-visible for tests),
   output parsers (`parse`), uniform failure mapping (zone/spawn → terminal; nonzero
   exit / signal → retryable), and durable session retention
   (`outcome.session` → next job's `payload.session`).
   - **Claude**: `claude -p <prompt> --output-format json [--resume <s>]`.
     Live-verified CLI is claude 2.1.211 at `~/.local/bin/claude`.
   - **Codex**: `codex exec --json <prompt>` / `codex exec resume <s> --json`.
     ⚠️ **UNVERIFIED-LIVE**: codex CLI is NOT installed on this machine (checked PATH,
     cargo, brew, ~/.local/bin). Argv + JSONL parse are fixture-tested only.

## Remaining work to close Slice 2A (in order)

1. **Confirm re-gate green.** Watch `gate.sh --test` (running at handoff, task in the
   session). If red, read the log (not the exit code); the only outstanding test was
   the fixture, now `exec sleep 60`. Expect 88/88.
2. **Fold in independent-review findings.** A `general-purpose` review agent was
   launched over the backend + trampoline files (adversarial: zone escape, reap
   gaps, capture bounds, secret leakage, escalation races). When it returns, triage:
   fix real CRITICAL/HIGH, note MEDIUM/LOW in the checkpoint, re-gate after any fix.
   Its output file: `tasks/afcdeeee750eb7e20.output` (subagent transcript — do NOT
   cat it; the agent's final message arrives as a task notification).
3. **Live smoke (`claude`), opt-in.** Default-out per [TEST-040]. To run:
   ```
   CONTROL_PLANE_LIVE_SMOKE=1 CONTROL_PLANE_CLAUDE=$(command -v claude) \
     env TOOLCHAINS=org.swift.633202606251a swift test \
     --package-path ~/Developer/swift-institute/swift-control-plane \
     --filter "live smoke: claude"
   ```
   Asserts a trivial no-tool prompt in an empty temp zone returns exit 0, non-empty
   body, and a session id; then a continuation on that session. Record the outcome in
   the checkpoint (spends real tokens — a vacuous skip must NOT be reported as a pass).
   Codex live smoke stays SKIPPED (CLI absent) — report as a limitation.
4. **Commit** (path-scoped, two commits): kernel schema extension; then the backend +
   trampoline + tests. Keep the slice-1 commits intact. Push is NOT authorized.
5. **Checkpoint report** `REPORT-slice-2a.md`: gate result, live-smoke result,
   review disposition, limitations, and the **exact Slice 2B recommendation**
   (below). Relay block for the Principal.

## Known issues / decisions already made

- **Cooperative-TERM fixture**: a bare `sleep 60` under `#!/bin/sh` is not killed by a
  group SIGTERM (the non-interactive shell survives; the product then correctly
  escalates to SIGKILL). Fixed by `exec sleep 60` (process image *is* sleep, dies on
  TERM). The product behavior was correct throughout; only the test's notion of
  "cooperative" was wrong.
- **Stale-object linker errors** bit twice during iteration (kernel ABI changed under
  incremental test `.o`s). Resolution: `find Sources Tests -name '*.swift' -exec touch
  {} +` before the gate, or a clean build. The gate of record should be clean.
- **Institute-`String` shadowing** appears in every backend/test file that imports the
  POSIX/ISO-9945/File_System closure — spell `Swift.String` (or a file-scope
  `private typealias String = Swift.String`) in those files.
- **Lock deferral corrected** (Principal pointer): the institute already vends fcntl
  record locking (`ISO 9945 Kernel Lock`, `~Copyable Token`, process-death release,
  wrapped by `POSIX Kernel Lock`). The multi-daemon graduation gate CONSUMES it in
  `Store.File`; it is not an upstream build. (design.md §5 invariant 7.)

## Exact Slice 2B recommendation

**Slice 2B = the daemon control API + swift-arguments, over a Unix-domain socket,
consuming the process backend from 2A.** Rationale and scope:

- **Why this next**: 2A gives owned model subprocesses but they are only reachable
  in-process. 2B makes the daemon a real service an operator (and, later, a remote
  runner fleet) can drive — the first of the three graduation gates the Principal
  attached to slice 1 (swift-arguments + user-facing daemon control API). It does NOT
  require the socket-less internals to change; it wraps them.
- **Build**: (a) a `control-plane` daemon subcommand that boots a `Daemon` with N
  `Runner.Loop`s whose backends are `Claude`/`Codex` `Host`s, over the durable
  `Store.File`; (b) a Unix-domain-socket control endpoint (institute swift-sockets;
  explicitly NOT NIO) speaking the command/receipt/projection surface as a length-
  prefixed JSON frame protocol — submit, cancel, status, tail; (c) swift-arguments
  for the operator CLI (`control-plane daemon`, `submit`, `status`, `cancel`), retiring
  the hand-rolled `CommandLine.arguments` switch.
- **Ship the single-instance lock with it**: 2B is the "multi-daemon or production
  operation" trigger for graduation gate 2 — so `Store.File` takes the exclusive
  whole-file fcntl lock at open (consume `ISO 9945 Kernel Lock` / `POSIX Kernel
  Lock`), second daemon fails fast.
- **Out of 2B**: Workspace-v2 integration; HTTP/TLS transport; the remote runner
  fleet; Store.Postgres. Those are later slices (2C+).
- **Precondition**: none beyond 2A; the seam (`Backend`, `Host`, `Daemon`, `Store`) is
  already the boundary 2B builds on.

## Reproduce / verify commands

```
# Compile everything incl. tests (fast; keeps compiled deps):
env TOOLCHAINS=org.swift.633202606251a swift build \
  --package-path ~/Developer/swift-institute/swift-control-plane --build-tests

# Gate of record (resolves + clean-ish build + runs tests + cross-checks):
~/Developer/swift-institute/Scripts/gate.sh --test \
  ~/Developer/swift-institute/swift-control-plane

# Live smoke (opt-in; claude present, codex absent) — see step 3 above.
```
