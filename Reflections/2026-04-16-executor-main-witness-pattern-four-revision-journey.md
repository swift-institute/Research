---
date: 2026-04-16
session_objective: Resolve the `import Dispatch` hard-line violation in `Executor.Main` by producing a timeless-infrastructure architecture for main-thread dispatch across Darwin, Linux, and Windows.
packages:
  - swift-executors
  - swift-kernel
  - swift-kernel-primitives
  - swift-darwin-standard
  - swift-institute
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: supervise
    description: [SUPER-002a] scope-lock-precedes-architecture-lock (merged with 2026-04-16-supervise-in-practice)
  - type: skill_update
    target: supervise
    description: [SUPER-015] operational compression trigger at pivot boundaries
  - type: no_action
    description: Architectural-need vs current-code rule for research-process: related pattern already covered by [RES-021] contextualization step; defer as potential research topic
---

# Executor.Main Witness Pattern — A Four-Revision Architectural Journey

## What Happened

Started with HANDOFF-executor-main-platform-runloop.md: eliminate `import Dispatch` from `Executor.Main.swift` (the last [PLAT-ARCH-008a] hard-line violation in the executor toolkit). Prerequisites verified, `unsafe-audit` branches merged to main by the user, handoff cleared to begin.

The architecture question went through four revisions before landing. Each revision was correct given the constraints in force at the time; each was superseded when a new constraint surfaced:

- **R1 (Option B)**: Minimal `Kernel.Main.Dispatch.async` wrapper in `swift-darwin-standard` + retained `#if os(...)` in `Executor.Main` justified by a [PLAT-ARCH-008a] four-criteria walkthrough. Locked. User subsequently imposed platform-agnostic-`Executor.Main` constraint. Superseded.
- **R2 (Option A)**: Per-platform L2 `Kernel.Main.Loop` variants in `swift-darwin-standard` / `swift-linux-standard` / `swift-windows-standard`, with `internal import Dispatch` + `internal import CoreFoundation` at Darwin. `Executor.Main` becomes fully unconditional. Documented analytical-error trail explaining why R1's rejection of A was wrong (conflating "what current code uses" with "what the abstraction needs"). Locked. User imposed no-Apple-framework-imports constraint. Superseded.
- **R3 (Option C)**: Uniform L3 condvar pump in `swift-kernel`; no platform variants; no Apple framework imports anywhere; scope narrowed to headless-only (Darwin GUI apps use `MainActor` instead). Meta-reviewer flagged an unasked gate question: are GUI consumers actually in scope? User's answer (post-alpha, theoretical-best framing): **yes**. Superseded.
- **R4 (witness-struct dependency inversion)**: `Kernel.Main.Loop` at L1 as a `Sendable` witness struct with three closure properties (`enqueue`/`run`/`shutdown`). Each platform contributes its own witness: Darwin at L2 (libdispatch + CFRunLoop, spec-mirror per [PLAT-ARCH-012]), condvar at L3 (Linux default; available on any platform as explicit choice), Windows deferrable (native or condvar). `Executor.Main` holds a `Kernel.Main.Loop` via DI; `shared` uses `.default`. User's insight: dependency-inverse via witness so each platform is first-class, not "the fallback."

Two additional decisions locked in R4:
- **α** `Executor.MainThread` global actor, nested under `Executor` per [API-NAME-001] (not top-level `@MainThread` despite stdlib `@MainActor` convention — ecosystem rule takes precedence over stdlib parity).
- **β** `Executor.Main` conforms to both `SerialExecutor` AND `TaskExecutor`; adds `asUnownedTaskExecutor()`.

A secondary meta-discovery surfaced mid-session: **Dispatch and CoreFoundation are genuinely L2 spec-mirror material** per [PLAT-ARCH-012] (Apple-authored, documented, stable ABI, even open-sourced for libdispatch). This changed what "no Apple frameworks" means — the correct rule is "no Foundation" (framework-with-opinions, banned ecosystem-wide), not "no Dispatch/CoreFoundation." The L2-spec-mirror framing unlocked R4 by making the Darwin witness layering-legitimate.

Output: canonical research doc at `swift-foundations/swift-executors/Research/executor-main-platform-architecture.md` (/research-process format, version 4.0.0, DECISION, tier 2), ~1050 lines covering R1→R4 supersession trail with analytical-error analysis for R1 and R2. Old `swift-foundations/swift-kernel/Research/main-thread-dispatch-abstraction.md` stubbed with redirect. `HANDOFF-executor-main-platform-runloop.md` updated with R4 locks; 32-entry historical ground-rules block compressed to 7 active entries (R4-1 through R4-7) per [SUPER-015].

No code written. All work is research + handoff updates. Step 2 (L1 declaration in `swift-kernel-primitives/Sources/Kernel Primitives Core/Kernel.Main.swift`) is pending — gated on user green-light.

### Handoff triage

Scanned `HANDOFF-*.md` at workspace root per [REFL-009]:

| File | Triage | Action |
|------|--------|--------|
| HANDOFF-executor-main-platform-runloop.md | Updated for R4. Step 2 not started. Ground rules R4-1 through R4-7 locked 2026-04-16; no work done yet. Per [REFL-009] "pending verification — fresh dispatch" case. | Annotated with [SUPER-011]-style verification-status note under the Active Ground Rules header; **leave file**. |
| HANDOFF-executor-audit-cleanup.md | Supervisor constraints #1–#6 verified per the file's own header ("#1–#2, #4–#6 positively; #3 escalated, user resolved as 'accept bundled commits as-is'"). AC #1 session-attested, #2/#4/#5 supervisor-verified, #3 resolved by escalation. Commits merged (verified earlier this session via `git log` on swift-executors submodule main; `unsafe-audit` branches — which bundled the audit-cleanup work per the #3 escalation — merged to swift-primitives and swift-foundations main branches per user confirmation). Meets [REFL-009] MUST-delete criteria: all items complete, all ground rules verified, no pending escalation. | **DELETED**. |
| HANDOFF-io-completion-migration.md, HANDOFF-migration-audit.md, HANDOFF-path-decomposition.md, HANDOFF-primitive-protocol-audit.md | Not touched this session; no session context to triage cleanly. | Leave. Future session with context on those workstreams can re-triage. |

Secondary index update: `swift-foundations/swift-kernel/Research/_index.md` previously didn't list `main-thread-dispatch-abstraction.md` at all. Added an entry marking it SUPERSEDED with a pointer to the canonical doc at `swift-executors/Research/executor-main-platform-architecture.md`. Without this, readers navigating the swift-kernel Research index would miss the relocation trail.

No audit findings were modified this session; no `/audit` cleanup needed.

## What Worked and What Didn't

### Worked

- **Analytical-error trail discipline**: documenting *why* R1 and R2 each selected a wrong architecture (with the test future maintainers should apply to avoid the same trap) produces higher-value artifacts than "we chose X because Y." The R3 doc's §5.4 and the R4 doc's §Analytical-Error Trail — the latter covering both errors explicitly — are the most durable parts of the final artifact.
- **User-directed reframing**: three pivots (no-Apple-framework constraint, GUI-in-scope-theoretical-best, witness-pattern dependency inversion) each came from the user, not from my own analysis. Each produced a better architecture. The pattern: when I was iterating within a frame, the user was re-examining the frame itself.
- **Meta-review catching contradictions**: after I claimed Revision 3 was internally consistent, a meta-review read the doc and surfaced five real contradictions (§3 vs §11 on naming, @inlinable vs internal-import compat, a misleading heading, an overbroad Criterion-2 wording, a missing pre-step for `InternalImportsByDefault` verification). I had approved based on self-summary without independent read. The meta-review corrected this.
- **/research-process format**: the target format (version/status/tier metadata, Question → Context → Prior Art → Analysis → Outcome → References) imposed structure that the sprawling R3 doc lacked. Matching `executor-package-design.md`'s style rather than inventing produced a more discoverable artifact.
- **Witness-struct pattern discovery**: once surfaced, the witness pattern satisfied every accumulated constraint simultaneously (no Apple-framework leaks, universal scope, per-platform first-class contribution, trivial testability, low reversibility cost). The pattern matches existing ecosystem infrastructure (`Kernel.Event.Driver`, `Kernel.Completion.Driver`, rendering witness migration).

### Didn't work

- **Scope question not asked early**: "are GUI consumers in scope?" was asked **after R3 locked**. Asking it before R1 would have pre-empted three revisions. The default move was to start generating architecture options; the better move was to pin scope first.
- **Ground-rules compression deferred**: the handoff's supervisor ground-rules block accumulated to 32 entries across four revisions before compression. [SUPER-015] prescribes compression at overflow; it didn't happen until the meta-reviewer flagged it. Each revision appended new rules without consolidating superseded ones. The compressed R4-1 through R4-7 block (7 entries) is what the full set collapsed to, which makes clear how much of the historical volume was redundant.
- **Accepting summary-approval without verification**: early in the session, the supervisor approved Revision 3 based on my summary of the doc, then later (on independent read) caught five real defects. The summary-as-verification anti-pattern is explicitly warned against by [SUPER-009]; the session exhibited it anyway.
- **Overclaiming in docstrings**: described R3 as achieving "zero workarounds" when `@unsafe @unchecked Sendable` still persisted on `Kernel.Main.Loop` (justified by internal mutex synchronization, but still a workaround-shape annotation). Meta-reviewer caught this.
- **Layering confusion in R1/R2 re: where Apple frameworks belong**: treated "Apple frameworks" as categorically banned without distinguishing Dispatch/CoreFoundation (L2 spec-mirror material) from Foundation (framework-with-opinions, genuinely banned). The user's "is libdispatch part of the spec?" question unlocked the distinction; the `/platform` skill's [PLAT-ARCH-012] had the rule all along, but I hadn't applied it until prompted.

## Patterns and Root Causes

### Pattern 1 — Locking architecture before locking scope

R1, R2, and R3 each locked an architecture against an implicit scope assumption that hadn't been explicitly surfaced:

- R1 assumed domain-authority conditionals in `Executor.Main` were acceptable — true until the user imposed platform-agnostic-`Executor.Main`.
- R2 assumed Darwin GUI integration was in-scope, axiomatically — true until the user imposed no-Apple-framework imports.
- R3 assumed Darwin GUI could be handed off to `MainActor` — true until the user clarified that GUI consumers of `Executor.Main` are intended (theoretical-best, disregarding current consumer count).

Each revision was correct given its scope assumption. The assumption was wrong. Architecture followed scope; when scope flipped, architecture flipped.

**Root cause**: the default cognitive move for architecture-shaped questions is to start generating options and comparing them — which pulls toward solution-space before problem-space is fully defined. Scope-boundary questions (what's in, what's out, what's deferred, what's explicitly rejected) feel like "setup work" compared to the "real work" of comparing architectural alternatives. But scope IS the real work; architecture comparison against an undefined scope is wasted analysis.

**Corrective test**: before locking any architecture for a multi-alternative design question, run the scope-boundary exercise explicitly. What's in scope? What's out of scope? What's deferred? What's explicitly rejected (γ lock-out)? Only then compare architectures. A 30-minute scope conversation saves multiple revision cycles.

This pattern matches [RES-001]/[RES-004]'s investigation methodology ("state the question precisely" → "enumerate options") but the skill doesn't currently make scope elicitation a pre-condition to the enumerate step. It's worth making explicit.

### Pattern 2 — Conflating current-code with architectural need

R1's rejection of Option A read: "The Linux condvar pump is executor-specific orchestration: uses `Executor.Wait.Condvar`, `Executor.Job.Queue`, `Executor.Shutdown.Flag` (L3 types). Moving it to the platform stack smuggles executor semantics into `Kernel.Main`."

This was wrong. The current `Executor.Main` happened to use those types because it was implemented with them, not because the abstraction architecturally requires them. A main-loop abstraction needs closure-queue + mutex + condvar + shutdown flag — all generic primitives at L1/L2.

**Root cause**: when rejecting an architecture based on "it would need type X," the rejection implicitly assumes "X" is an architectural requirement. But "X" is usually the *current implementation's choice*, not the architectural need. The current implementation's types are contingent; they reflect past decisions, not present necessity.

**Corrective test**: when rejecting an architecture because it requires type X, ask: "is X what the abstraction architecturally needs, or what the current code happens to use?" If the latter, what does the abstraction actually need? The answer is usually something lower-layer and more generic — which the rejecting architecture can in fact use without violating layering.

This pattern parallels [RES-021]'s "contextualization step" for prior art (universal adoption doesn't imply universal necessity). The same corrective shape applies here — at the level of "my current implementation's types" rather than "other ecosystems' patterns."

### Pattern 3 — Summary-as-verification across supervisor/subordinate boundary

The session exhibited a clear instance of [SUPER-009]'s warned-against pattern: I (subordinate) reported a revision as complete; the supervisor approved; the supervisor later read the actual artifact and caught five defects. Both sides contributed: my summary was honest but incomplete (I had missed the contradictions myself); the supervisor trusted the summary rather than reading.

The correction happened because the supervisor eventually did read the artifact. Without that read, the contradictions would have persisted.

**Root cause**: summaries are faster than reads, and summaries are usually directionally correct. The productivity gain from trusting summaries is real. But "usually" is the problem — when a summary is wrong, the wrongness doesn't present as a summary defect; it presents as a clean summary of a defective artifact. Only independent read catches it.

**Corrective test**: before locking any decision based on a subordinate's summary, the supervisor reads the artifact. Subordinate produces artifacts that survive independent read (complete sentences, no unexplained shorthand, cross-references resolvable). If the artifact is long, the supervisor at minimum reads the canonical-decision sections (§11 Locked Decisions in R3's case, §Outcome in the /research-process style). This is operational guidance for supervision beyond the abstract [SUPER-009] rule.

### Pattern 4 — Ground-rules compression deferred

[SUPER-015] prescribes compression of supervisor ground rules at overflow: "when the block grows beyond N entries, merge superseded rules into compressed ones with `(merges #N)` annotations." The session accumulated 32 entries (7 initial + 7 R1 + 10 R2 + 9 R3) before compression.

Each revision's new rules felt more urgent than compressing the superseded ones. The uncompressed block became unwieldy but the cost of the bloat was silent (future readers would fail to parse 32 entries, but the session's own work continued).

**Root cause**: compression is maintenance work; new rule creation is progress work. Maintenance is routinely deprioritized in favor of progress, even when the skill explicitly mandates it. [SUPER-015] is permissive ("compress on overflow") rather than operational (no defined trigger, no enforcement at pivot boundaries).

**Corrective test**: compression should be triggered at each pivot boundary, not deferred to "when the block feels too big." Concrete operational trigger: at a major architectural pivot (new revision locked) OR when entries exceed N (e.g., 10), compress to ≤ target (e.g., 6) with supersession annotations before adding new rules for the next revision.

## Action Items

1. **[skill]** supervise: add pre-condition to architecture-lock operations — "before locking any architecture, surface scope-boundary questions (what's in/out/deferred/rejected). Scope-lock precedes architecture-lock. This is operational guidance for [SUPER-002]'s ground-rules block content and for the supervisor's acceptance of subordinate architectural proposals." Motivation: this session's R1→R2→R3→R4 churn was driven entirely by implicit scope assumptions surfacing after architecture locked.

2. **[skill]** supervise: operationalize [SUPER-015] compression — add a concrete trigger: "at each major architectural pivot OR when the block exceeds 10 entries, compress to ≤6 active entries with `(merges #N, #M)` or `(supersedes #N)` annotations before adding new rules. Preserve superseded rules as historical record; the supersession map makes genealogy auditable." This session's 32→7 compression demonstrates the target ratio.

3. **[skill]** research-process: add "architectural-need vs current-code" contextualization rule parallel to [RES-021]'s contextualization step for prior art. "When analyzing an architectural alternative and rejecting it based on a type or constraint, verify the cited type/constraint is architecturally *required*, not what the current code happens to use. Concretize what the abstraction would need in its own terms; the answer is usually a lower-layer generic primitive, not an L3 domain type." Motivation: R1's rejection of Option A (on L3-executor-types grounds) was a category error; the rule would have caught it.
