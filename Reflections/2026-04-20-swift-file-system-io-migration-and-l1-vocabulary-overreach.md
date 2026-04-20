---
date: 2026-04-20
session_objective: Analyze swift-file-system for the new swift-io work and move it toward release readiness
packages:
  - swift-file-system
  - swift-io
  - swift-threads
  - swift-kernel-primitives
  - swift-kernel
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: handoff
    description: [HANDOFF-013a] writer-side prior-research grep (symmetric to [HANDOFF-013])
  - type: no_action
    description: Implementation strengthening for "new L1 type vs existing view.span": covered by combining [HANDOFF-013a] writer-side grep with [IMPL-060] ecosystem-dependencies; the root cause is the missing pre-write grep, already codified
  - type: package_insight
    target: swift-file-system
    description: 30 #if os(...) count across 12 files as release-blocker inventory — noted for D1 unification follow-up
---

# swift-file-system IO migration and the L1-vocabulary overreach

## What Happened

Session opened with a dual goal: analyze swift-file-system in preparation for the new swift-io work, and improve swift-file-system toward release. Loaded `/platform`, `/implementation`, `/code-surface`, `/modularization` per the workspace CLAUDE.md.

Four distinct arcs landed during the session:

**Arc 1 — IO → swift-threads migration.** Clean rebuild surfaced that swift-file-system referenced deprecated `IO.Blocking.shared.run` / `IO.Blocking.Error` across 15 files / 87 call sites. Initially I proposed re-adding `IO.run(.blocking)` to swift-io as a replacement. The user's handoff (`HANDOFF-swift-io-migration.md`) correctly rejected that — the dispatch primitive had been extracted to `Kernel.Thread.Pool` in swift-threads by the 2026-04-14 strict-mission refactor. Verified the handoff's claims against `swift-threads/Sources/Thread Pool/Kernel.Thread.Pool+Run.swift:47-50`; migrated all 15 files mechanically. Commit `49c0f23`.

**Arc 2 — Durability test rename.** Clean rebuild of the library passed but tests failed on references to `File.System.Write.Atomic.Durability`. The type had moved to `File.System.Write.Durability` in an earlier refactor. Single-file `replace_all` fix. Commit `86f83ef`. A transient ISO_9899 lifetime error appeared and disappeared after `rm -rf .build` — `feedback_clean_build_first.md` was the right move, but I had to be prompted to apply it.

**Arc 3 — NUL-leak diagnosis.** Full test run: 277 passed, 18 failed, 1 fatal crash. All failures traced to `File.Name.init(from: Kernel.Directory.Entry)` copying `entry.rawName` (null-terminated by L1 convention) verbatim into `File.Name.rawEncoding`. The NUL byte then broke `File.Path.Component(utf8:)` → `Walk` yielded 0 entries → `Copy.Recursive`/`Delete.recursive` cascade-failed.

**Arc 4 — L1 overreach and correction.** My first fix proposal was a `.dropLast()` patch at the consumer site. User rejected: "feels like a patch; swift-file-system should ideally have zero platform checks; kernel is the unification layer." I then proposed a bigger L1 move — promote `Kernel.File.System.Name` from namespace enum to typed value, expose `Kernel.Directory.Entry.filename`, push `.rawName` off the public surface. Wrote a handoff `HANDOFF-directory-entry-platform-neutral-name.md` in swift-kernel-primitives dispatching the work. A sibling agent started executing it, paused, and diagnosed the proposal as the fourth parallel owning string type flagged by `swift-institute/Research/string-type-ecosystem-model.md` §D1. The correct fix was a three-line consumer-side change: `File.Name.init(from:)` goes through `entry.nameView.span` — which already exists on the pre-existing `Kernel.Path.View` type and is NUL-excluded by construction (the view stores `count` explicitly, excluding the terminator, at `swift-path-primitives/.../Path.View.swift:39,98`).

End state: the IO-migration commits are landed; the Durability test is fixed; the NUL-leak bug is *diagnosed* but not fixed; the kernel-primitives WIP is uncommitted and stale; a fresh consolidated `HANDOFF.md` at the swift-file-system root dispatches a new agent with sole authority to execute the consumer-side fix and delete the stale handoffs. Superseded: `HANDOFF-swift-io-migration.md` (IO migration done) and `HANDOFF-directory-entry-platform-neutral-name.md` in kernel-primitives (wrong direction, rejected).

## What Worked and What Didn't

**Worked** — verification before action. Three times in the session I verified another agent's claims against sources before acting: (a) the IO-migration handoff's type table against `swift-threads/Sources/...`; (b) the status note on Swift.String+Kernel.swift against `git log` showing commit `5180afc`; (c) the sibling agent's diagnosis that `nameView.span` exists by reading `Path.View.swift` directly. Each verification caught or confirmed something. The discipline from `feedback_verify_prior_findings.md` was applied to incoming information.

**Worked** — correction-acceptance. When the sibling agent's D1 diagnosis landed, I agreed with it rather than defending my prior handoff. The pivot was fast: acknowledge wrong direction, consolidate into a fresh handoff with the correct consumer-side fix + explicit dead-end list so the new agent doesn't retread.

**Didn't work** — I applied verify-before-action to *others*' claims but not to my own advice. When the user asked "how should we proceed?" about the NUL leak, I went straight to design ("new typed value at L1"). I did not grep the canonical ecosystem doc (`string-type-ecosystem-model.md`) before writing the handoff. That doc would have told me — by name — that three parallel owning string types already exist and a fourth is the highest-stakes concern. Skipping that grep was the root of Arc 4.

**Didn't work** — I misread "fix at the right level." The user's push was toward correctness: "swift-file-system ideally has NO platform compiler checks; kernel is the unification layer." I mapped that to "go up one layer, add typed vocabulary at L1." The correct reading was "check whether a typed API already exists before inventing one." `nameView.span` was right there.

**Didn't work** — I needed a prompt to clean-rebuild. After the Durability fix, ISO_9899 compile errors appeared in the incremental test build. I reflexively went to investigate iso-9899 instead of running `rm -rf .build` first. `feedback_clean_build_first.md` exists precisely for this class of mistake. User said "try a clean build first" and the error evaporated. Memory exists; application lagged.

## Patterns and Root Causes

**The advisor's verify-gap.** My discipline around verifying *incoming* handoffs is strong — grep the sources, check the commit, confirm the claim. My discipline around verifying my own *outgoing* prescriptions is weaker. The sibling agent's D1 catch was the check I should have performed on my own proposal before sending it. Formally: `[HANDOFF-013]` ("Prior research check") is written from the perspective of the *investigation receiver*. The symmetric rule — the *writer* of a handoff prescribing new types or structural changes must grep the relevant `Research/` before writing the prescription — is not written down. Sessions that write handoffs regularly produce prescriptions that would have been caught by the receiver's grep; the writer-side grep is cheaper than the receiver-side revert cycle.

**The over-escalation trap.** The user corrected me from "small patch" to "fix at the right level." I heard this as "go bigger / higher / more structural." That move was wrong by one layer: "right level" meant "consumer site using the correct existing API," not "L1 vocabulary addition." When directed to fix up a level, the first check is not "design the bigger thing"; it is "is there already a thing that does this, one level up, that I've been bypassing?" `entry.nameView` existed at the same level as the bug, with the right semantics, and I walked past it twice — once during my initial diagnosis, again when the user asked me to elevate the fix. The pattern: when guidance says "right level," the grep for existing APIs is still step zero.

**Memory consultation asymmetry.** I loaded skills (`/platform`, `/implementation`, `/code-surface`, `/modularization`) at session start — design-pattern skills. The relevant *records* (Research/string-type-ecosystem-model.md) were not loaded because nothing in the skill-loading protocol pointed at them. Skills tell me how to think; research records tell me what the ecosystem has already decided. Both are needed. The gap is that session-prep loads the former but not the latter. The `feedback_grep_research_before_new_types.md` memory I wrote during the session codifies this, but it's a lagging indicator.

**Cheap check, expensive miss.** The grep that would have prevented Arc 4 would have cost ~30 seconds. The cost of not running it: one wrong handoff, one sibling agent's rolled-back WIP, one sibling's forced D1 diagnosis, one user intervention asking me to re-read the research doc, one re-written handoff. Easily an hour of compounded re-work. The cost asymmetry is extreme; the discipline is tiny; the missing piece is a structural prompt that fires *before* prescription, not after correction.

**What the session got right about the broader picture.** The IO-migration arc and the Durability arc both succeeded because the correct prior work was already inscribed: the 2026-04-14 strict-mission reflection documented the `Kernel.Thread.Pool` extraction; the status note documented commit `5180afc`. When the upstream had already written down the canonical answer, verification worked. The NUL-leak arc failed the same check — D1 is inscribed in `string-type-ecosystem-model.md` — because I didn't read the inscription. The system is working correctly at the level of "inscribe decisions in research"; the gap is at "consult inscription before prescribing."

## Action Items

- [ ] **[skill]** handoff: Add a symmetric counterpart to `[HANDOFF-013]` for handoff *writers*. When a sequential or branching handoff prescribes new types, modules, vocabulary, or structural changes, the writer MUST grep the relevant package's `Research/` and the ecosystem-wide `swift-institute/Research/` before writing the prescription. The rule should cite `string-type-ecosystem-model.md` §D1 as the canonical "cost of skipping this" case study. Suggest `[HANDOFF-013a]` or a new sibling rule.

- [ ] **[skill]** implementation: Strengthen guidance that before proposing new L1 vocabulary to solve a consumer bug, consumers MUST be checked for existing typed APIs that already carry the needed semantics. Existing rules ([IMPL-060] ecosystem dependencies, [IMPL-000] call-site-first, [INFRA-*] existing infrastructure) cover nearby territory but do not crisply forbid "new L1 type to hide raw bytes" when `view.span` already exists. Consider a rule shaped like: "before adding a public accessor that returns an existing vocabulary type, check whether the type's existing View/Span accessors already provide the NUL-excluded / typed / platform-neutral access the consumer needs."

- [ ] **[package]** swift-file-system: Capture the 30 `#if os(...)` count across 12 files as a release-blocker inventory. The NUL-leak cascade is the first observed consequence; the broader pattern is that consumer packages inherit platform splits from L1 types that leak conditional storage (`rawName: [UInt8]`/`[UInt16]`). Release readiness requires either the D1 unification landing or per-call-site migrations to view-based APIs.

## Session Artifact Cleanup

**Handoff files triaged:**

- `/Users/coen/Developer/swift-foundations/swift-file-system/HANDOFF.md` — FRESH, written this session as dispatch for the next agent. Not this session's work. **Leave in place.**
- `/Users/coen/Developer/swift-foundations/swift-file-system/HANDOFF-swift-io-migration.md` — Prescribed the IO→Threads migration. All Next Steps completed (commits `49c0f23`, `86f83ef`). No supervisor block. **Delete** per [REFL-009] standard rule; the new HANDOFF.md already supersedes it explicitly.
- `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/HANDOFF-directory-entry-platform-neutral-name.md` — Prescribed an L1 change now rejected per D1. The sibling agent partially executed; their WIP is uncommitted. **Leave in place** — tied to the revert-and-delete transaction that the new agent will execute in Step 1 of the fresh HANDOFF.md. Deleting it separately would orphan the uncommitted kernel-primitives WIP from its explanation.

**Audit:** `/audit` was not invoked this session. No audit findings to update.
