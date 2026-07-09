---
date: 2026-07-09
session_objective: Resume the repotraffic → institute migration arc (session 2) — close ordered actions 1–2, finish the W1.5a family-repo ports, gate and commit them
packages:
  - swift-sql-postgres
  - swift-tagged-primitives
  - swift-url-form-coding
  - swift-stripe-types
  - swift-mailgun-types
  - swift-identities-types
  - swift-favicon
  - swift-authentication
status: pending
---

# Repotraffic Session 2: Fast Edit Lanes, Stalled Gates, and Answers That Never Landed

## What Happened

Resumed from `Workspace/handoffs/HANDOFF-repotraffic-arc-2026-07-09.md` (18:00 closeout). Re-verified
state from git first ([HANDOFF-016/-029]) and found real deltas: three held commits (witnesses
`9f44420`, dependencies `dcdee06`, parser-primitives `f22479a`) had been pushed by the parallel lint
arc under the new CLAUDE.md standing grant — the held list had silently shrunk.

Closed ordered actions #1 and #2: swift-sql-postgres landed and pushed (`3ccc30e`, 13 tests green;
two fix rounds — Swift.String pins against the institute-String shadow via Environment→Kernel
re-export, then a boundary overload replacing an illegal default-argument reference to an
internal-imported symbol) and swift-tagged-primitives' Codable fixed (`671a653` held; bare-value
singleValueContainer replacing member-synthesized `{"underlying":…}`, 125 tests).

All five remaining W1.5a port lanes completed as edit-only subagent workflows (agents forbidden to
build; orchestrator gates). Real defects were caught by the review lane: six aggregate Client
structs where `@DependencyClient`→`@Witness` was invalid (zero closure properties — `@Witness`
hard-errors), plus two cross-lane coherence bugs (favicon pointed url-routing at the institute fork
whose main is a held incompatible rewrite; stripe kept a coenttb url-form-coding URL). Restored the
deleted `URLFormCodingURLRouting` target/product into institute swift-url-form-coding verbatim from
its own git history (`b6dcfc2^`).

Gates then stalled: two cold builds ran 75 minutes without visibly leaving SwiftPM resolution, were
killed by the 10-minute Bash tool cap (children survived as orphans), and re-runs re-stalled. Root
causes eventually isolated: (1) ~300-package cold resolves are 20–60+ min and near-silent; (2) the
deprecated swift-standards monolith enters graphs via old tags (url-form-coding's rfc-2388@0.1.x →
whatwg-url@0.2.x → monolith), colliding its `Parsing` target with pointfree swift-parsing's when
URLRouting is present. Fix pattern: flip tagged institute deps to `branch:"main"` + local mirror —
applied to url-form-coding (uncommitted; committing it fixes mailgun/identities/stripe graphs at
once). Also detected a parallel Claude session (PID 99111) actively editing the W1.5b repo set —
halted W1.5b here per [SUPER-055/056].

The principal asked twice mid-turn whether progress was stalling; my answers were embedded as
mid-turn text between tool calls and never landed as replies. The principal aborted the session and
directed an overnight handoff (`/goal` resume form). Closeout: handoff updated with per-repo truth
table + ordered overnight list, committed and pushed (Workspace `ee3c67c2`).

**HANDOFF scan**: store `Workspace/handoffs/` has 63 live files (cap-red 63>40 — documented
by-design overage; this arc is NOT closing, no drain). 1 file in session authority
(`HANDOFF-repotraffic-arc-2026-07-09.md`) — annotated in place with the session-2 closeout,
left as the live resume source. Remaining files out of session authority — untouched.
Audit findings: none opened this session.

## What Worked and What Didn't

Worked: edit-only subagent lanes with structured returns (5 ports reviewed/completed in parallel,
~15 min, zero build contention); state re-verification catching the shrunken held list; the
review-and-complete lane catching six compile-blockers a "mechanically complete" claim had hidden;
recovering deleted source from the repo's own history instead of guessing; agents refusing to guess
past the SwiftPM identity collision and stopping with options.

Didn't work, in order of cost:
1. **Communication**: two direct principal questions received answers only as mid-turn text between
   tool calls — effectively unanswered from the principal's seat. The session was aborted over it.
   Confidence in the technical state was high; the trust cost came from the reply channel, not the work.
2. **Gate economics misjudged**: I treated gates as ~5-minute operations. Cold institute graphs make
   resolve the dominant cost. Sequencing two mega-gates before a 1-minute nearly-green gate
   (sql-postgres) delayed the arc's first closable action by an hour.
3. **Phantom green**: the first sql-postgres gate read exit-0 from a `| tail` pipe as build-green
   while the log carried a hard error — caught only by reading the artifact ([SUPER-037]).
4. **Tool-cap orphaning**: 10-minute Bash cap killed gate shells mid-build twice before I switched
   to detached `nohup` gates with `BUILD_EXIT=` markers; a zsh `grep -c ... || echo` bug then wasted
   one full poll cycle.

## Patterns and Root Causes

**The reply channel is part of the deliverable.** Mid-turn user messages arrive alongside tool
results; answering them inside a working turn (text between tool calls) does not reach the user.
The pattern generalizes: a question from the principal is an intervention point ([SUPER-007]) — the
correct move is stop-and-reply (end the working burst with the answer as the visible message), then
resume. Working "through" the question optimizes the wrong variable: task latency over principal trust.

**Tool-reach, again ([REFL-011])**: exit-code-through-pipe is the same epistemic failure as the
stale-cache cold build in [PKG-BUILD-013] — the tool's reach (pipe's last command) is narrower than
the claim ("build green"). The detached-gate pattern (exit markers written by the same shell that
ran the build) aligns reach with claim. Gate status must never be derived from anything but the
build's own recorded exit code plus the log.

**Old tags resurrect deprecated architecture.** The monolith was deprecated on mains, but any
`from:`-pinned institute dep can pull a tag whose manifest predates the deprecation — reintroducing
it into 2026 graphs where it collides with pointfree's `Parsing`. The house rule ("advance pins to
latest main; leave no pin behind") is not just hygiene; it is what keeps deprecations effective.
Every `from:` pin on an institute package found mid-arc should be treated as a latent graph bomb.

**Cold-resolve cost should drive orchestration shape.** Correct order is: smallest-graph gates
first (close actions early), one mega-resolve at a time (they are resolver-CPU-bound, not
compile-bound), and dependency-ordered commits (url-form-coding before its three consumers) so each
downstream resolve sees the fixed manifest. This was all derivable up front from pin counts.

## Action Items

- [ ] **[skill]** swift-package-build: add a rule for orchestrated build gates — detached
      (`nohup … ; echo BUILD_EXIT=$? >> log`) so shell-tool timeouts cannot orphan builds; status read
      ONLY from recorded exit markers (never piped exit codes); expect 20–60 min cold resolves on
      large institute graphs; sequence smallest-graph gates first; stale `Package.resolved` deletion
      before re-gating branch-dep consumers.
- [ ] **[skill]** supervise: pre-dispatch parallel-actor scan — before dispatching a wave over an
      enumerated repo set, `ps`/`lsof` for live swift/git processes and check `git status` dirt in
      those repos; a foreign editor in the set converts the wave to class-(c) surface-and-stop
      (extends [SUPER-036] edit-zone non-overlap to cross-session detection).
- [ ] **[package]** swift-url-form-coding: clean up the vestigial `URLRouting` trait — exports.swift
      carries `#if URLRouting @_exported import URLRouting` with no trait-conditional dependency on
      the main target, so enabling the trait breaks the build; either wire the dep or delete the
      trait + guard (noted while restoring URLFormCodingURLRouting).
