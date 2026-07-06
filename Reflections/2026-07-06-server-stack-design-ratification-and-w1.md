---
date: 2026-07-06
session_objective: Finalize the institute server-stack layering design (repotraffic as forcing consumer), obtain ratification, and execute wave W1
packages:
  - swift-server
  - swift-http-standard
  - swift-rfc-9110
  - swift-rfc-9111
  - swift-rfc-9112
  - swift-http-headers
status: pending
---

# Server-Stack Design Ratification and W1 Execution

## What Happened

Consumed `HANDOFF-institute-server-stack-design.md` (design-finalization arc; all prior
repotraffic work reframed as pre-research). Resume-time verification (two Explore sweeps +
in-chat probes) overturned two load-bearing pre-research claims before any design text was
written: (1) the L2 HTTP/network model is NOT absent — swift-ietf carries real RFC
9110/9111/9112 implementations (~11k LOC, Foundation-free, spec-mirroring) plus TCP/UDP/IP/
TLS/WebSocket/URI packages, so Q1 became "adopt + converge," not "populate"; (2)
swift-postgresql-standard's Foundation exposure is 72 of 132 main-target files, ~5× the
handoff's "~15" claim, changing Q7's cost calculus.

Authored `Research/institute-server-stack-architecture.md` (Tier 2, ecosystem-wide):
eight open questions resolved into one layering — L2 spec vocabulary (existing RFC family +
new thin `swift-http-standard` converger), engine-free L3 interfaces (swift-sql,
swift-migrations, swift-scheduler — fill now), L4 `swift-server` as the single
engine-quarantine zone (`internal import` only), engines-behind-interfaces with the
swap-corollary; interfaces-now-engines-later as the revenue line; no `swift-networking`
(coenttb QUIC-fork name collision + already-decomposed missions). Principal ratified same
day → v1.1.0 DECISION.

Post-ratification re-assessment of the ADT-tower/torn-mains state found the ownership-shared
tear healed end-to-end (rfc-9110 builds green on 6.3.2 — but only after `swift package
update`; stale SwiftPM caches reproduce the OLD failure after manifests heal), rfc-7519
manifest-healed, and the windows tear MOVED into consumer `swift-foundations/swift-windows`
(`package: "swift-windows-32"` vs resolution identity `swift-windows-standard`), still
blocking postgresql-standard (gates W4, not W1–W3).

W1 executed under pre-granted YESes: `swift-standards/swift-http-standard` created
(private; `@_exported` converger; 4 smoke tests); `swift-http-headers` retired (verified
dead → GitHub archive + retirement-pointer description; hard delete blocked on missing
`delete_repo` token scope); swift-server slimmed by a sonnet subagent (`2af9dee..836c821`,
31/31 green — Server Shared vocabulary dissolved onto `HTTP.Method/Status/Headers/
Header.Field`, Foundation `Server.Environment` replaced by L3 swift-environment, lossless
Method↔NIOHTTP1 bridge replacing the prototype's lossy GET-fallback); HTTP typealias
relocated to the converger by a second subagent (code-position respells to `RFC_9110.` —
100/7/15 sites across 9110/9111/9112, prose and wire-format literals preserved, one
test-alias file per test module; acceptance gates included a swift-server consumer build).
Batch push of five repos under the principal's conditional YES after independent sample
verification.

CI triage of the three public runs (all red): macOS 6.3 legs green on all three; the Ubuntu
(Swift 6.3, release) reds are a signal-6 SIL-assertion compiler crash
(`!type.hasTypeParameter()`, SILArgument.cpp:40) compiling untouched dependency `RFC_3986`
(same crash in the DocC jobs) — inboxed as a compiler-bug-catalog candidate; format/SwiftLint
legs were red pre-push (pre-existing queues). Our own delta — 10 swift-format violations from
the 5-char-longer qualifier — was isolated via worktree lint-diff + per-line blame, hand-
wrapped, verified delta-zero, and pushed (`906ef16`, `f1fc090`) as same-wave correctives.

HANDOFF scan ([REFL-009]): store guard red at its documented 54>40 overage (cap ruling:
per-arc drains; this arc's file drained today). 57 files found; 1 retired this session
(`HANDOFF-institute-server-stack-design.md` → `.trash/`, consumed on ratification);
`PROMPT-repotraffic-rebuild-phase-1.md` annotated (gate cleared: design ratified, W1
landed; resumes at W2+ dispatch); `SCOPING-repotraffic-rebuild.md` left (retires at
program close); `HANDOFF-overnight-lint-quality-arc.md` NO-TOUCH (in-flight, another
session, [REFL-009a]); remaining ~53 files out of this session's cleanup authority.
No `/audit` ran; [REFL-010] not applicable.

## What Worked and What Didn't

**Worked.** Resume-time verification before design synthesis was the session's highest-value
move — both pre-research corrections re-shaped the design's central resolutions, and the
step-0 source-shape sweep ([RES-019]) is what found the RFC family. Call-site-derived
interface scoping (SQL/jobs get L3 interfaces now; outbound HTTP with zero direct call
sites does not) kept the design honest. Sequential subagent dispatch with typed ground
rules produced clean, verifiable work in both cases; the lint-delta-via-worktree +
per-line-blame method separated our format fallout from pre-existing queues precisely.
Same-day annotation of my own inbox entry (blast-radius RESOLVED) prevented the rename
wave chasing a healed tear.

**Didn't.** (1) My handoff-retirement commit used `git commit -- handoffs` (directory
scope) and swept in the public-flipping arc's in-flight WIP — the explicit-per-file-adds
preference existed and I violated it; inboxed for the owning arc. (2) The design doc's Q1
called the alias relocation a "mechanical follow-up" without measuring internal usage —
live measurement later showed `HTTP.` in public signatures forcing a real respell
(~122 code sites), a [RES-037]-class miss caught only at execution. (3) The first
rfc-9110 build "succeeded" with exit 0 through a `| tail` pipe while actually failing on a
corrupt Package.resolved — reading the output, not the exit code, caught it. (4) The
relocation subagent backgrounded its gating build and ended its turn — subagents are not
re-woken by their own background tasks; it needed a manual resume with
foreground-execution instructions. (5) The stale-SwiftPM-cache trap fired twice in one
session (my rfc-9110 build, the subagent's 9112 resolve) before being systematized.

## Patterns and Root Causes

**Pre-research errs directional, not random.** Both overturned claims understated the same
thing — existing institute assets and existing debt — because the maturity sweeps sampled
the orgs the arc lived in (swift-foundations, swift-standards) and never swept swift-ietf.
The layer-placement question "where does X live?" cannot be answered by sweeping the org
you expect the answer in; the sweep set must be all layer orgs. This is [RES-019]'s
source-shape sweep generalized from "does X exist?" to "which org owns X?".

**Mechanical respells have non-semantic fallout, and it is measurable pre-push.** A
qualifier rename that lengthens an identifier (`HTTP.` → `RFC_9110.`) pushes lines over
format width — 10 violations across two public repos, discovered only by CI. The worktree
lint-diff (lint at HEAD vs lint at pre-change commit, line-agnostic compare, blame-filter
to changed lines) is cheap, deterministic, and would have shipped the respell clean. This
belongs in the rename-wave Phase-0/acceptance family alongside [PKG-NAME-007]'s greps.

**Belief-state vs world-state, three costumes.** The stale SwiftPM cache reproducing a
healed tear, the pipe-masked exit code, and the loop-counter class ([REFL-012]) are one
failure family: a proxy for state (cache, pipe status, counter) consulted instead of state.
The cache instance is nastiest because it reproduces a *formerly true* error — perfectly
plausible, freshly falsified. "Manifests healed but resolution still fails → refresh the
cache before believing the failure" is now inboxed for other sessions.

**Subagents + background tasks don't compose.** An agent that backgrounds a long command
and ends its turn waiting is permanently stalled — the notification goes nowhere. The
supervisor sees a "completed" agent whose result message reveals the stall. Dispatch
prompts for gating commands must mandate foreground execution; [REFL-017] covers the
inverse (redundant polling), not this.

## Action Items

- [ ] **[skill]** supervise: add a dispatch-block guidance entry (dispatch.md, near
  [SUPER-049]) — sub-agent prompts MUST require foreground execution of gating
  commands (build/test/verify): background-task notifications do not re-wake a
  returned sub-agent, so a backgrounded gate = a stalled dispatch needing manual resume.
- [ ] **[skill]** swift-package: extend the rename/respell Phase-0 family ([PKG-NAME-007])
  with a post-respell format-delta acceptance gate — worktree lint at pre-change SHA vs
  HEAD, line-agnostic diff, blame-filter; fires whenever a mechanical rename changes
  identifier length in width-limited public repos.
- [ ] **[research]** Linux-6.3-release-only SIL assertion `!type.hasTypeParameter()`
  (SILArgument.cpp:40) crashing `RFC_3986.CharacterSet.swift` — /issue-investigation +
  swift-compiler-bug-catalog entry (macOS 6.3 + local builds green; blocks the swift-ietf
  HTTP family's Linux release legs; reproduced on two independent runs).
