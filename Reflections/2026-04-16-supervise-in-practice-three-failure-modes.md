---
date: 2026-04-16
session_objective: Supervise concurrent subordinate agents across the executor toolkit's remaining issues (unsafe audit, judgment calls, Dispatch removal) through multiple architecture revisions.
packages:
  - swift-executors
  - swift-kernel
  - swift-institute
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: supervise
    description: Strengthened [SUPER-009] with "read artifact not summary" discipline
  - type: skill_update
    target: supervise
    description: Added [SUPER-002a] scope-lock-precedes-architecture-lock; operationalized [SUPER-015] compression trigger
  - type: no_action
    description: Class (c) escalation rule already captured in [SUPER-005]
---

# Supervise-in-Practice — Three Failure Modes Across a Multi-Revision Dispatch

## What Happened

This session exercised the `/supervise` skill at scale: I supervised four concurrent subordinate agents across four workstreams — the ecosystem unsafe audit (Phase 0 → Phase 1 classification), the executor judgment calls (typed count / Windows visibility), the Polling error-handling deferral, and the Executor.Main Dispatch-removal research. The unsafe audit and judgment-calls workstreams completed cleanly. The Dispatch-removal workstream went through three architecture revisions during my supervision (R1 Option B → R2 Option A → R3 Option C) before a fourth revision (R4 witness pattern) emerged later from a meta-review the user ran. The agent-side reflection at `2026-04-16-executor-main-witness-pattern-four-revision-journey.md` covers the authored artifacts and the witness-pattern discovery. This entry focuses on the supervisor-side practice gaps that produced three specific failure modes.

### Handoff triage

Per `[REFL-009]`, scanned workspace root for handoff files. Four handoffs I created during this session — `HANDOFF-ecosystem-unsafe-audit.md`, `HANDOFF-polling-error-handling.md`, `HANDOFF-executor-judgment-calls.md`, plus the pre-existing `HANDOFF-executor-audit-cleanup.md` — are no longer present at workspace root; cleaned up by subsequent sessions (the agent-side reflection's triage table records the `audit-cleanup` deletion explicitly). `HANDOFF-executor-main-platform-runloop.md` remains present but was updated for R4 by the agent-side session; its triage is covered in that reflection ("fresh dispatch — 7 active ground rules R4-1 through R4-7, no work done yet, leave"). Not re-triaging. The four unrelated handoffs at workspace root (`HANDOFF-io-completion-migration.md`, `HANDOFF-migration-audit.md`, `HANDOFF-path-decomposition.md`, `HANDOFF-primitive-protocol-audit.md`) were not touched this session — no session context to triage, leave. No audit findings were modified this session; no `[REFL-010]` cleanup needed.

**Failure 1 — approved without reading.** After the agent reported Phase 0 research doc complete with locked decisions, I approved Step 2 based on the agent's summary alone. The user called this out directly: *"you should have read the doc."* When I read it, I found a §3/§11 contradiction (section still presenting naming as an open question with a different recommendation than the locked decision), a §7/§10 `@inlinable` contradiction that would have produced a compile error in Step 3, a misleading §4.2 heading, an overbroad Criterion-2 wording in the four-criteria walkthrough, and a missing pre-step for `InternalImportsByDefault` verification. Each was obvious on any careful read.

**Failure 2 — locked architecture before confirming scope.** R1 locked Option B before the platform-agnostic constraint had been articulated. R2 locked Option A before the no-Apple-framework constraint had been articulated. Each pivot was correct *given the new constraint* but avoidable with better pre-lock scoping. The meta-reviewer surfaced this after R3: three revisions would not have happened had scope been elicited on day one. R3's pivot needed only the scope reframe, not an architectural reversal.

**Failure 3 — ground-rules block not compressed at pivots.** The `HANDOFF-executor-main-platform-runloop.md` ground-rules block grew to 32 entries across three revisions (R1 #7–#13, R2 #14–#23, R3 #24–#32). `[SUPER-002]` caps active blocks at 4–6 entries ("larger blocks become wallpaper and stop being checked"). `[SUPER-015]` mandates compression-on-overflow via `(merges #N, #M)` annotations. I approved each `[SUPER-015]` append without enforcing the compression clause. The meta-reviewer flagged this, agent proposed a 6-entry compression, I adjusted to a slightly different 6-entry version, agent applied it. The subsequent R4 pivot re-compressed to 7 active entries per the agent's own `[SUPER-015]` discipline.

## What Worked and What Didn't

### Worked

- **Class (c) escalations per `[SUPER-005]`**: when the audit-cleanup agent asked for the typed count / Windows visibility decisions, I correctly escalated both to the user rather than answering from principal authority. Same for the `@globalExecutor` disambiguation (α/β/γ) — I analyzed the three options but handed the decision to the user.
- **Analytical-error-trail requirement**: requiring each superseded revision to document *why* the prior reasoning was wrong (with a "test future maintainers should apply" framing) produced artifacts that teach, not just decide. The R3 doc's §5.5 explicitly covering both R1's conflation and R2's unexamined premise was the highest-value section of that artifact.
- **Self-correction after being called out**: once the user surfaced Failure 1, subsequent approvals included actual artifact reads. The R3 re-read caught four substantive issues that the R3 agent's summary did not surface.
- **Drift-signal enforcement**: caught scope creep when the judgment-calls agent flagged "2 residual leaks outside declared sites." Directed the agent to treat the additional sites as scope creep and leave them flagged for future work rather than silently expanding scope. Clean `[SUPER-006]` signal #3 enforcement.

### Didn't work

- **"Trust but verify" collapsed into "trust"** at the approval boundary. The `/supervise` skill already names this failure (`[SUPER-009]`: *"Subordinate 'I'm done' reports are not acceptance"*) but naming it wasn't enough — under load across four concurrent supervisions, reading every artifact felt expensive and I took the shortcut. The shortcut produced the failure.
- **Architecture locks came before scope confirmations** on the Dispatch-removal workstream. R1's ground rules locked naming, architecture, and namespace target; none of these decisions was scope-confirmed first. Each subsequent user constraint reopened previously locked decisions. Three reversals downstream of one missing up-front question.
- **Ground-rules hygiene lost to append convenience**. `[SUPER-015]`'s compression clause is easy to skip at append time — "just one more entry" never feels worth the compression chore. The cumulative effect (32 entries) is unreadable. The agent's own instinct toward R4 compression (7 active entries) modeled the behavior I should have enforced at R2.
- **Meta-review was external, not internal**. The user ran a meta-review at the end that surfaced Array.removeFirst's O(n), the unasked scope gate question, the ground-rules bloat, and the workaround-framing overclaim. Each should have been caught during supervision, not post-session.

## Patterns and Root Causes

All three failures share a shape: **supervision shortcuts taken under parallel-dispatch load**. Reading every artifact, asking scope questions before architectural locks, and compressing ground rules at every pivot are each small individual investments. Under load across four concurrent agents, each shortcut felt marginal. The cumulative effect was large.

The underlying error: **assuming supervision scales by parallelism alone.** There is a per-agent cognitive tax that cannot be compressed without losing supervision quality. `/supervise` skill entries like `[SUPER-007]` (intervention points), `[SUPER-009]` (verify criteria, don't accept self-reports), and `[SUPER-015]` (compress at overflow) are named as behaviors, but they describe steady-state discipline. When load rises, these are the first disciplines to erode. The skill's prose doesn't inoculate against load-induced shortcuts.

A secondary pattern: **architecture-before-scope is the same error at every tier.** R1 and R2 each committed to an architecture before confirming the scope it was supposed to serve. This mirrors a pattern I've seen agent-side (the agent-side reflection calls it "conflating what the current code uses with what the abstraction needs"). Supervisor-side, the same conflation appears as "lock the architecture the user described, without first asking what the user needs the architecture to *do*." The correction is identical: ask scope questions before architecture questions. The meta-reviewer's single-question gate ("does any consumer rely on DispatchQueue.main auto-pumping on Darwin GUI?") is the concrete form of that correction for this specific work.

A tertiary pattern: **external meta-review catches what self-review misses.** The user's meta-review at the end of the session was structurally equivalent to a code reviewer reading the work fresh. It found things I didn't because my context was saturated with intermediate decisions. This suggests meta-review should be a supervision checkpoint, not an end-of-session privilege — ideally one per major pivot, routed to a different agent context so it reads fresh.

## Action Items

- [ ] **[skill]** supervise: strengthen `[SUPER-009]` verification requirement with a concrete test at phase-completion intervention points — "if the subordinate's completed deliverable is a document, the supervisor MUST read the document, not the agent's summary of the document, before approving." Summaries are attestations, not verification. This is already implicit in `[SUPER-009]` but wasn't strong enough to prevent the shortcut under load.
- [ ] **[skill]** supervise: add a pre-dispatch requirement that scope boundaries are confirmed with the user *before* architecture decisions are locked in the ground-rules block. Proposed wording target: an explicit `[SUPER-003a]` or extension to `[SUPER-003]` requiring the Task Boundaries field to answer "what scope questions were confirmed with the user, and what scope questions remain open?" — architectural locks on unconfirmed scope are forbidden.
- [ ] **[skill]** supervise: enforce `[SUPER-015]` compression at pivot boundaries, not at project end. Add a checkpoint: when the ground-rules block grows past 6 entries OR when a revision supersedes 3+ prior entries, compress immediately with `(merges #N, #M)` / `(supersedes #N–#M)` annotations. Skipping compression produces 32-entry unreadable blocks as a cumulative effect of "just one more entry" at each pivot.
