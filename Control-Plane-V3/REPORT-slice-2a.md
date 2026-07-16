# Control Plane V3 — Slice 2A checkpoint report

Date: 2026-07-16

Status: **accepted**. The clean gate and both actual provider continuation
smokes are green. Slice 2B has not started.

## Immutable inputs and commits

- Research handoff: `c65f6386b3438c7337d3c2941b4d7ef81a37e761`.
- `swift-control-plane` Slice 1 base:
  `e66e3d760bc7c1bf39aa23a76ca0ba00bc60fbff`.
- Slice 2A kernel schema/codec/fingerprint commit:
  `e2380f377a8a2f88541b2ab8f171e9c67e995d72`.
- Slice 2A backend/trampoline/adapters/targets/tests commit:
  `4f61558a8190d9e82baaf22a754bd7bdf79f22cf`.
- Research design/checkpoint commit:
  `131accade5c6a70d224077a85f4e6e5afa080b7e` (parent
  `4594999b3c595a610bcb513e21e479b7c45ca061`).
- Final Claude acceptance evidence: the commit containing the current report
  revision, with parent `131accade5c6a70d224077a85f4e6e5afa080b7e`.
- No push or other outward mutation was performed.

## Owned changed files

Kernel/schema commit:

- `Sources/Control Plane Kernel/Control.Plane.Command.Kind+fingerprint.swift`
- `Sources/Control Plane Kernel/Control.Plane.Job.Outcome.swift`
- `Sources/Control Plane Kernel/Control.Plane.Job.Payload.swift`
- `Sources/Control Plane Store File/Control.Plane.Event+JSON.swift`
- `Tests/Control Plane Kernel Tests/Control.Plane.State Tests.swift`
- `Tests/Control Plane Store File Tests/Control.Plane.Store.File Tests.swift`

Backend commit:

- `Package.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Claude.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Codex.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Host.Configuration.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Host.Failure.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Host.Request.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Host.Result.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Host.Zone.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Host.swift`
- `Sources/Control Plane Backend Process/Control.Plane.Runner.Provider.swift`
- `Sources/control-plane-exec/main.swift`
- `Tests/Control Plane Backend Process Tests/Control.Plane.Runner.Claude Tests.swift`
- `Tests/Control Plane Backend Process Tests/Control.Plane.Runner.Host Tests.swift`

Research checkpoint paths:

- `Control-Plane-V3/design-slice-2a-backend-process.md`
- `Control-Plane-V3/REPORT-slice-2a.md`

## Gate of record and focused verification

The final gate was run from a freshly deleted `.build` using the required
command:

```sh
rm -rf /Users/coen/Developer/swift-institute/swift-control-plane/.build
/Users/coen/Developer/swift-institute/Scripts/gate.sh --test /Users/coen/Developer/swift-institute/swift-control-plane
```

Final result:

- Requested/resolved toolchain: `org.swift.633202606251a`, Apple Swift 6.3.3.
- Gate exit: `0`; `GATE-BUNDLE-EXIT=0`.
- Error lines: `0` compiler diagnostics and `0` other error lines.
- Fresh compile steps: `3265`.
- Build completion: `Build complete! (310.67s)`.
- Exact test total: **90 tests in 32 suites passed after 1.478 seconds**.
- Gate log:
  `/var/folders/zh/1w0zshh16kl26vbbnj4v9q000000gn/T/institute-gate/swift-control-plane/gate-package.log`.

The first clean gate exposed a real test synchronization defect rather than a
stale artifact: the TERM-ignoring fixture was canceled before its shell had
installed `trap '' TERM`, so it died cooperatively on signal 15 in about 45 ms.
That run executed 90 tests in 32 suites and failed one test with two issues. The
fixture now writes a readiness marker only after installing the trap, and the
test waits for that marker before cancellation. Focused verification:

```sh
env TOOLCHAINS=org.swift.633202606251a swift test \
  --package-path /Users/coen/Developer/swift-institute/swift-control-plane \
  --filter 'a TERM-ignoring child is KILLed after the grace window'
```

Result: **1 test in 2 suites passed after 0.847 seconds**.

The Codex live smoke then exposed a second real defect: fixed exec-level options
such as `--sandbox` had been placed after `resume <thread-id>`, where codex-cli
rejects them. The builder now emits exec-level options before the `resume`
subcommand. Its pure regression command was:

```sh
env TOOLCHAINS=org.swift.633202606251a swift test \
  --package-path /Users/coen/Developer/swift-institute/swift-control-plane \
  --skip-build \
  --filter 'codex argv shapes for fresh and resumed runs'
```

Result: **1 test in 2 suites passed after 0.001 seconds**. The resumed shape with
the smoke's fixed options is:

```text
exec --sandbox read-only --skip-git-repo-check resume <thread-id> <prompt> --json
```

## Actual live continuation smokes

### Codex — passed

Command:

```sh
CONTROL_PLANE_LIVE_SMOKE=1 \
CONTROL_PLANE_CODEX=/Applications/Codex.app/Contents/Resources/codex \
  env TOOLCHAINS=org.swift.633202606251a swift test \
  --package-path /Users/coen/Developer/swift-institute/swift-control-plane \
  --filter 'live smoke: codex'
```

Final result: **1 test in 2 suites passed after 8.079 seconds**. This was an
actual live run, not a default-out skip. The passing test proves all four
continuation facts in one path:

1. The first provider report was `.success` with a non-empty response body.
2. A non-nil durable Codex thread identifier was parsed from
   `thread.started.thread_id` and copied into the second payload's `session`.
3. The corrected resume argv above was accepted by codex-cli 0.144.2.
4. The resumed provider report was `.success` with a non-empty second response.

The fixed prompts were the test's harmless `ok`/`ok again` requests. Response
text and the full durable thread identifier were intentionally not printed to
the checkpoint log; the success/session/non-empty assertions are the retained
evidence without persisting conversation identifiers or prompt-bearing argv.

For completeness, the preceding live attempt proved the first response and
thread-id parsing but failed the new second-response assertion because codex-cli
rejected the misplaced `--sandbox`; it failed 1 test in 2 suites after 6.509
seconds. The final pass is after the argv correction.

### Claude — passed after re-authentication

Command:

```sh
CONTROL_PLANE_LIVE_SMOKE=1 CONTROL_PLANE_CLAUDE=$(command -v claude) \
  env TOOLCHAINS=org.swift.633202606251a swift test \
  --package-path /Users/coen/Developer/swift-institute/swift-control-plane \
  --filter 'live smoke: claude'
```

The first attempt returned `exit 1` with empty captured stderr; the live test
failed **1 test in 2 suites after 6.079 seconds**. No session id existed, so no
resume argv or second response could be verified. This was not a skip.

The same safe fixed prompt was then reproduced directly against Claude Code
2.1.211, both with the host-equivalent sanitized environment and with the full
current environment. Claude returned `Not logged in · Please run /login` and
exit 1. The non-secret diagnostic command:

```sh
claude auth status
```

returned:

```json
{"loggedIn":false,"authMethod":"none","apiProvider":"firstParty"}
```

Per controller disposition, Claude was not retried while logged out. After user
authorization, a stale credential was cleared and the Claude-subscription OAuth
flow was completed:

```sh
claude auth logout
claude auth login --claudeai
claude auth status
```

The authoritative status then reported `"loggedIn": true` with auth method
`claude.ai`. The exact live-smoke command above was rerun and passed **1 test in
2 suites after 6.303 seconds**. This was an actual live run, not a default-out
skip. The passing test proves a non-empty first response, retained Claude
session id, successful `--resume <session-id>`, and a non-empty second response.
The fixed harmless response text and full session identifier were not printed
to the checkpoint log.

## Independent-review dispositions

- **H1 — trampoline sentinel classification:** fixed. Exit 71 (`chdir`) and 72
  (`execv`) are terminal, and missing-directory/missing-executable coverage
  prevents retry-budget burn.
- **M1 — lexical edit-zone escape:** accepted as a blocking production
  limitation, not papered over. Documentation and tests describe only lexical
  containment; no sandbox claim is made.
- **Inherited signal state:** fixed. The trampoline clears the signal mask and
  resets TERM/INT/HUP/QUIT/PIPE/TSTP before exec. Cooperative TERM,
  TERM-to-KILL escalation, and whole-group termination are covered.
- **Codex JSONL parser:** fixed against live codex-cli output. It retains
  `thread.started.thread_id`, selects the last completed `agent_message`, and
  fails when no agent message exists instead of treating raw JSONL as success.
- **Advisory L2:** latent pipe-descriptor collision with standard descriptors is
  accepted/deferred; it is not a Slice 2A production claim.
- **Advisory L6:** the host does not log environment values, but a provider can
  print sensitive material on stderr and the bounded failure reason can retain
  that child-produced tail. Accepted/deferred for the later diagnostics policy.
- **Advisory N2:** Claude `is_error` reports remain retryable. Accepted for the
  bounded attempt policy in this slice.
- Remaining L1–L8/N1–N5 review notes were accepted or deferred as non-blocking
  refinements. No advisory was silently promoted into a sandbox or production
  guarantee.
- Completion-run findings were folded with focused coverage: readiness-based
  TERM fixture synchronization and exec-level Codex option placement.

## Required boundary adjudications

### 1. Edit-zone symlink/TOCTOU escape

It is **not prevented**. The zone check is purely lexical: component-boundary
containment on a normalized absolute path. It does not resolve symlinks, while
the trampoline's kernel `chdir` does. A symlink inside an allowed root can point
outside it, and a check/use race can change the target after validation.

Therefore Slice 2A is **non-production**. The edit zone is a cooperative
boundary, not an enforced sandbox. Graduation is blocked until real production
isolation lands: a sandbox/chroot, or canonicalization plus an enforced
no-symlink roots policy, or an OS sandbox profile. This implementation must not
run untrusted model output in production as though lexical containment were
isolation.

### 2. Prompt visibility through argv

The prompt is a distinct argv element, never a shell string, so this path does
not create shell interpolation/injection. The prompt is nevertheless visible
through process inspection (`ps` and, on relevant systems, `/proc`) to other
local users. That is acceptable only for the current single-tenant/local use.
Multi-tenant deployment requires moving prompts to stdin or another
non-process-list transport.

### 3. Truncated-success parsing

Capture is bounded (default 256 KiB); overflow sets `Result.truncated`. Exit 0
still enters provider parsing even when capture was truncated. Claude/Codex
control answers should be small, but a truncated JSON/JSONL document can become
unparseable or lose its final answer. Both adapters then return failure, not a
raw-output false success. Truncation therefore degrades safely, although it can
turn an otherwise successful CLI invocation into a retryable provider failure.

### 4. Signal reset, process-tree termination, and crash orphaning

The trampoline creates a new session/process group, resets inherited signal
mask/dispositions, attaches `/dev/null` to stdin, enters the edit zone, and
execs the provider. `kill(-pid)` addresses the whole owned process group;
cancellation escalates TERM → grace → KILL; the direct child is always reaped.
Tests prove cooperative TERM, stubborn-child KILL after grace, and removal of a
backgrounded grandchild.

This is cooperative containment, not a sandbox. A daemon crash can still orphan
the running process tree because Slice 2A has no OS-level orphan adoption.
Lease fencing preserves control-plane correctness, but the orphan can burn
compute. That operational limitation remains for a later slice.

## Remaining dirty state after the checkpoint commit

Expected post-commit state:

- `swift-control-plane`: clean.
- Research: only pre-existing unrelated work remains and is not staged or
  committed:
  - modified `Reflections/.cadence.log`
  - modified `_index.json`
  - modified `skill-corpus-holistic-review.md`
  - untracked
    `Reflections/2026-07-15-workspace-seat-control-plane-and-cold-start-boundary.md`
  - untracked `layout-render-decomposition.md`
  - untracked
    `sendable-requirement-to-sending-region-isolation-parsing-stack.md`

No stash, reset, clean, discard, or unrelated-path staging was used.

## Institute-first gate before Slice 2B

Before daemon sockets, arguments, locks, or any other Slice 2B code, produce a
one-page **reuse vs. build** table with layer placement for every new seam. At
minimum it must adjudicate:

- `swift-arguments` for the operator CLI;
- `swift-sockets` for Unix-domain transport (not NIO);
- `swift-environment` / `swift-secrets` for configuration and credentials;
- ISO 9945 Kernel Lock / POSIX Kernel Lock for the single-instance `fcntl` lock;
- existing `swift-json` for the socket-frame protocol; and
- daemon/scheduler records, explicitly keeping engine-free recurring
  `swift-scheduler` distinct from the durable queue.

The purpose is to keep the control product a thin SaaS layer over Institute
foundations. This recommendation is a design gate only; Slice 2B implementation
was intentionally not started.
