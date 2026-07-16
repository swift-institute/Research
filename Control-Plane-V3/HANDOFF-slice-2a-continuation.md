# Control Plane v3 — Slice 2A Continuation Handoff (for Codex)

<!--
---
version: 1.0.0
last_updated: 2026-07-16
status: CONTINUATION HANDOFF — implementation + review-fold complete; clean gate
        running; live smokes + commit + final checkpoint report remain.
supersedes: INTERIM-slice-2a.md (this is the current state)
scope: swift-institute/swift-control-plane — Backend.Process (Slice 2A)
constraint: DO NOT START SLICE 2B. Finish 2A only.
---
-->

## Do this / don't

- **DO** finish Slice 2A only: clean gate result, both live smokes, commit path-scoped,
  write the final `REPORT-slice-2a.md`. **DO NOT** start Slice 2B (daemon/socket/args).
- **DO** preserve unrelated Research dirt: `Reflections/2026-07-15-*.md` is untracked and
  NOT ours — leave it.

## Current state (exact)

**Committed** `Research` (branch main): slice-2A design `a2f7274`; lock correction `f877b1c`;
interim/handoff `ee49cab`. Working-tree-dirty in Research (ours):
`Control-Plane-V3/design-slice-2a-backend-process.md` (review-fold corrections) and this file.

**Committed** `swift-control-plane`: HEAD `e66e3d7` (slice 1). ALL of slice 2A is UNCOMMITTED
in the working tree:
- Modified (kernel schema extension): `Package.swift`,
  `Sources/Control Plane Kernel/Control.Plane.Job.Payload.swift` (+`directory`,+`session`),
  `…/Control.Plane.Job.Outcome.swift` (+`session`), `…/Control.Plane.Command.Kind+fingerprint.swift`,
  `Sources/Control Plane Store File/Control.Plane.Event+JSON.swift`, and two touched kernel/store
  test files.
- New: `Sources/Control Plane Backend Process/` (9 files: Host{,.Zone,.Configuration,.Request,
  .Result,.Failure}, Provider, Claude, Codex), `Sources/control-plane-exec/main.swift`
  (trampoline), `Tests/Control Plane Backend Process Tests/` (Host Tests, Claude Tests).

**Build**: everything compiles + links clean (verified via `swift build --build-tests`).

## What is DONE (do not redo)

1. **Kernel schema extension**: `Payload.directory`/`.session`, `Outcome.session` — additive,
   nil-default, fingerprint + JSON codec + round-trip/fingerprint tests updated.
2. **Trampoline** (`control-plane-exec`): `setsid` → **signal reset** (empty mask +
   `SIG_DFL` for TERM/INT/HUP/QUIT/PIPE/TSTP) → **`/dev/null` stdin** → `chdir(zone)` →
   `execv`. Sentinel exits: 71 chdir/zone, 72 execv/not-found.
3. **Host engine**: direct argv `posix_spawn`, env allowlist (no value logging), bounded
   `poll(2)` capture + truncation, TERM→grace→KILL escalation, always-reap.
4. **Adapters**: Claude (`-p <prompt> --output-format json [--resume <s>]`), Codex
   (`exec --json <prompt>` / `exec resume <thread-id> <prompt> --json`), shared Provider.
5. **Independent review folded** (full review is in the git history of my session; key items):
   - **H1 (HIGH, FIXED)**: trampoline exit 71/72 now map to **terminal** (`retryable:false`)
     in `Provider` (`Trampoline.chdirFailed`/`execFailed`), + a test
     `a missing model CLI is a terminal failure…`. Previously misclassified as retryable.
   - **M1 (MEDIUM, adjudicated + doc-corrected)**: zone check is LEXICAL; symlink/TOCTOU
     escape is possible. `Zone.swift` comment + design doc now state this honestly. **This is
     the blocking graduation requirement** (see §Adjudications).
   - **Signal-inheritance bug (found + fixed, empirically proven)**: `posix_spawn` (attrp nil)
     makes the child inherit the parent's signal mask/dispositions, and `SIG_IGN` survives
     `execv`; a daemon that ignores SIGTERM would silently swallow the graceful-shutdown TERM
     (escalation degraded to always-SIGKILL). The trampoline signal reset fixes it. Verified:
     under `trap '' TERM` in the parent, a direct `/bin/sleep` child now dies on group-TERM.
   - **Codex parser (FIXED against LIVE output)**: real codex-cli 0.144.2 emits
     `{"type":"item.completed","item":{"type":"agent_message","text":"…"}}` and
     `{"type":"thread.started","thread_id":"…"}` — NOT a top-level `last_agent_message`. Parser
     rewritten to match, and **it now FAILS (never raw-output false-pass) when no agent_message
     is found**. Tests use the captured live shape + a no-message→failure test.
   - Lower findings (L1–L8, N1–N5): documented in the checkpoint as accepted/deferred; none
     block. Notable: L6 (child stderr can carry secrets into the reason string — host's OWN
     no-value-logging holds), L2 (pipe fd vs 0/1/2 collision — latent), N2 (Claude `is_error`
     always retryable).

## Remaining steps (finish these, in order)

1. **Clean gate (of record)** — RUNNING as of handoff (`rm -rf .build` was done, then
   `Scripts/gate.sh --test`). Confirm GREEN and record the EXACT `N tests in M suites passed`
   number (offline suite; live smokes are default-out / skipped here). If red, read the LOG
   not the exit code; the only historically-flaky test is the KILL-escalation one and it was
   proven correct (a stale build, not a real failure — a clean build fixes it).
2. **Update the Codex live-smoke to assert the CONTINUATION** (the Principal wants resumption
   verified): in `Tests/Control Plane Backend Process Tests/Control.Plane.Runner.Claude Tests.swift`,
   the `live smoke: codex` test currently asserts only `smoke.first`. Add the `smoke.second`
   (continuation) success assertion, mirroring the claude smoke (lines ~172-176). Then rebuild
   the test target.
3. **Claude live smoke**:
   ```
   CONTROL_PLANE_LIVE_SMOKE=1 CONTROL_PLANE_CLAUDE=$(command -v claude) \
     env TOOLCHAINS=org.swift.633202606251a swift test \
     --package-path ~/Developer/swift-institute/swift-control-plane \
     --filter "live smoke: claude"
   ```
4. **Codex live smoke** (installed at `/Applications/Codex.app/Contents/Resources/codex`,
   codex-cli 0.144.2):
   ```
   CONTROL_PLANE_LIVE_SMOKE=1 \
   CONTROL_PLANE_CODEX=/Applications/Codex.app/Contents/Resources/codex \
     env TOOLCHAINS=org.swift.633202606251a swift test \
     --package-path ~/Developer/swift-institute/swift-control-plane \
     --filter "live smoke: codex"
   ```
   The resume argv (`exec resume <thread-id> <prompt> --json`) + session continuity were
   validated live standalone; confirm the smoke passes end-to-end. Record both smokes' actual
   pass/fail — a skipped (env-var-absent) run is NOT a pass; the report must say which ran.
5. **Commit** (path-scoped, two commits in swift-control-plane): (a) kernel schema extension
   (Package.swift kernel/store bits + the 2 kernel/store test files); (b) backend + trampoline
   + backend tests + Package.swift target additions. Then commit the Research design-doc
   corrections + the final report. **No push** (not authorized). Preserve the untracked
   Reflections file.
6. **Final `REPORT-slice-2a.md`** (checkpoint): exact commits, changed/dirty files, commands,
   test totals, live-smoke evidence (actual bodies/thread-ids observed), review dispositions,
   the four adjudications (§below), and the **Institute-first reuse-census recommendation** for
   before Slice 2B (§below).

## The four required adjudications (put these in the report verbatim-equivalent)

1. **Symlink/TOCTOU escape from edit zones** — NOT prevented. The zone check is purely
   lexical (component-boundary containment on a normalized absolute path); it does not resolve
   symlinks, and the trampoline's `chdir` does. A symlink inside a root pointing outside it
   escapes the zone. **Therefore Slice 2A is NON-PRODUCTION**: the edit zone is a *cooperative*
   boundary, not an enforced sandbox. **Blocking graduation requirement**: production isolation
   (a real sandbox/chroot, or `realpath` canonicalization + a no-symlink policy on roots, or an
   OS sandbox profile) must land before this runs untrusted model output in production.
2. **Prompt leakage through process argv** — the prompt IS passed as a distinct argv element
   (never a shell string), so there is no shell-injection surface. But argv is world-readable
   via `ps`/`/proc` on a shared host, so a prompt is visible to other local users. Acceptable
   for single-tenant/local; for multi-tenant, pass the prompt via stdin instead (a later slice).
   State this explicitly.
3. **Successful commands whose output was truncated** — capture is bounded (default 256 KiB);
   overflow sets `Result.truncated`. A truncated success is still a success (exit 0), and the
   provider parses the (truncated) stdout. For Claude/Codex a control answer is tiny, so this
   is theoretical; but note: a truncated JSON/JSONL stream could fail to parse → the adapters
   now return a FAILURE (not a false pass), so a truncated-away answer degrades safely.
4. **Signal reset + process-tree termination** — the trampoline resets signal mask/dispositions
   so an inherited `SIG_IGN` cannot swallow SIGTERM; the child is a session leader (pgid==pid)
   so `kill(-pid)` owns the whole tree; escalation is TERM→grace→KILL; the child is always
   reaped. Verified empirically (group-kill clears a backgrounded grandchild; TERM-ignoring
   child escalates to KILL; cooperative child dies on TERM). Limitation: a daemon CRASH orphans
   a running child's tree (no OS-orphan adoption) — harmless to correctness (lease fencing) but
   burns compute; documented, a later slice.

## Institute-first reuse census (recommended gate BEFORE Slice 2B)

Before building the daemon/socket/arguments layer, run a short Institute-package reuse census +
design gate so the control product stays a THIN SaaS layer over Institute foundations, not a
re-implementation. Specifically enumerate and decide-to-reuse-or-justify:
- **swift-arguments** (operator CLI — already the accepted graduation path);
- **swift-sockets** (Unix-domain socket transport; explicitly NOT NIO);
- **swift-environment / swift-secrets** (config + backend credentials);
- **ISO 9945 Kernel Lock / POSIX Kernel Lock** (the single-instance fcntl lock — already
  identified; `Store.File` consumes it at the multi-daemon gate);
- **swift-json** (already used) for the socket frame protocol;
- the daemon/scheduler records (`swift-scheduler` is engine-free recurring — NOT the durable
  queue; do not conflate).
Output: a one-page "reuse vs. build" table with a layer placement for each new seam, so Slice 2B
is designed Institute-first.

## Reproduce / verify

```
# Clean gate of record:
cd ~/Developer/swift-institute/swift-control-plane && rm -rf .build
~/Developer/swift-institute/Scripts/gate.sh --test ~/Developer/swift-institute/swift-control-plane

# Live smokes: see steps 3–4 above.
```
