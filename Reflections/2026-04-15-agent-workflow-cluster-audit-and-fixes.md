---
date: 2026-04-15
session_objective: Audit the agent-workflow skill cluster (handoff / supervise / reflect-session / skill-lifecycle) for inter-skill consistency and apply fixes across five severity-batched edits
packages:
  - swift-institute
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: skill_update
    target: audit
    description: "Added [AUDIT-019] Skill-vs-skill cluster consistency mode (/audit cluster ...)"
  - type: skill_update
    target: skill-lifecycle
    description: "Added [SKILL-LIFE-030/031] Phase 8 Cluster Review (triggers + procedure)"
  - type: research_topic
    target: compose-then-trace-skill-design-phase.md
    description: "Compose-then-trace pattern for skill design"
---

# Agent-Workflow Cluster Audit and Composition Refinement

## What Happened

Continuation of the same session that created `/supervise` (prior reflection: `2026-04-15-supervise-skill-creation-from-handoff.md`). After the supervise skill shipped and self-review caught 9 internal issues, the user asked for an audit of "the whole setup" — meaning inter-skill consistency across the agent-workflow cluster.

`/audit` itself is scope-bounded to code-vs-skill compliance per `[AUDIT-001]`, so I dispatched an independent research agent to perform a Discovery-style skill-vs-skill audit per `[RES-012]`. Output at `swift-institute/Research/agent-workflow-skill-consistency-audit.md` — 26 findings (7 HIGH, 13 MEDIUM, 6 LOW), grouped into three meta-patterns: live-principal assumption bleed, terminology drift at composition boundaries, procedural gaps at edges.

Worked the findings in five severity-batched waves:

| Batch | Scope | Edits |
|---|---|---|
| 1 — Trivial | D.3 (`requires:` violations), D.1 (prefix-list redirect), D.4 (`last_reviewed` clarification), A.2 (cross-refs), A.4 (CLAUDE.md composition row) | 6 small edits across handoff / supervise / skill-lifecycle / CLAUDE.md |
| 2 — Terminology canonicalization | B.1 (heading Title Case), B.2 (Constraints / Do Not Touch / Task boundaries map), B.3 (research doc rename), B.4 (principal/subordinate glossary) | Coordinated rename + glossary additions across handoff / supervise / reflect-session / research |
| 3 — Live-principal design | B.5, E.2, G.1 — required design call (option A/B/C). User chose A-with-refinement: escalate class (b) → (c) in absentia, with pre-escalation re-read of the block. Encoded as new `[SUPER-014a]` Supervisor in Absentia with explicit interaction-vs-constraint model split | 1 new requirement + soften `[HANDOFF-012]` rationale + cross-link from `[SUPER-005]` |
| 4 — Edge-case procedural fixes | C.1 (escalation persistence), C.2 (entry-type evidence forms), E.1 (success verification stamp), G.2 (escalation-resolved cleanup) | Added persistence-target table to `[SUPER-012]`, evidence-form table + success-stamp requirement to `[SUPER-011]`, three new disposition rows to `[REFL-009]`, updated `[HANDOFF-010]` step 5 to require stamp on all three termination paths |
| 5 — Remaining | A.1, A.3, C.4, D.2, E.3, F.1, F.2, G.3, G.4 — 9 small edits, including supersession notation on block compression (`(merges #N, #M)`), sub-agent intervention-point collapse, mid-flight no-HANDOFF.md case, workflow-skill self-reference rule, empty-block detection | 9 mostly-mechanical edits |

Final coverage: 25 of 26 findings addressed in some form. B.4 was partly addressed via Batch 2's principal/subordinate glossary in `[HANDOFF-012]` rather than the audit-suggested separate change.

**Handoff triage** (per `[REFL-009]`): no new handoffs created during the audit/fix work. `HANDOFF-supervise-skill-creation.md` at `swift-foundations/swift-io/` remains in place — same disposition as the prior reflection (the file is its own Findings Destination; parent session has not yet consumed it).

**Audit-doc disposition** (per `[REFL-010]` spirit, applied to the Discovery-research audit doc rather than `Research/audit.md`): I'll annotate the audit doc with per-finding disposition before this session ends.

## What Worked and What Didn't

**Worked**:

- **Independent audit agent caught 26 things in one pass.** My own self-review (after authoring) caught 9. Independence + focused brief = much higher signal. The agent quoted line numbers, distinguished severity, and labelled three meta-patterns I would not have synthesized on my own.
- **Five-batch severity ordering scaled cleanly.** Trivial → canonicalization → design → edges → remaining. The first two batches were mechanical; the design batch was the sole user-input gate; the edges and remaining batches restored coherence without re-architecting. Pacing was right.
- **Pausing for the design call (G.1) was correct.** The three options (A/B/C) had real trade-offs and the user's choice (A-with-refinement) was substantively different from what I would have picked unprompted. Self-deciding would have been overreach.
- **Composition design (handoff↔supervise) surfaced gaps single-skill design didn't predict.** "Supervisor in absentia" only became a question once the two skills were composed and a workflow was traced across them. The result (`[SUPER-014a]` + class-b downgrade rule) is materially better than what either skill would have specified alone.
- **`[SKILL-LIFE-001/002]` (minimal revision + provenance) made each batch traceable.** Every Batch's edits cite today's reflection as provenance; future readers can grep for the date and find the rationale.
- **The audit's "What's working well" section was honest and balanced** — praising 4-entry typing, three-way termination, `[SUPER-001a]` boundary table. This calibrated severity (catching the high-value finds, not pathologizing the working parts) and made the recommendations easier to accept.

**Didn't work**:

- **I miscounted remaining findings as 6, then corrected to 9 once questioned.** Sloppy bookkeeping — I synthesized from memory rather than from the audit doc's structured list. The audit doc was right there. Should have re-read it before claiming a count.
- **`/audit`'s strict code-vs-skill scope forced me to use Discovery research instead.** The output is good but it lives in `agent-workflow-skill-consistency-audit.md`, not the `Research/audit.md` that `[AUDIT-001]` mandates. There is no current home for skill-vs-skill audits in the canonical infrastructure. This is an action item.
- **I introduced "supervisor in absentia" in `[HANDOFF-012]` without first specifying its mechanics in `/supervise` (finding E.2).** Recurring failure mode: introduce a concept where it's locally needed, forget to back-fill its definition where it semantically belongs. Same shape as the "Task boundaries" terminology collision I caught in self-review.
- **Skill-lifecycle was modified externally twice during the session** (visible via system reminders). One Edit failed because the file had drifted; I re-read and re-applied. Healthier than coordinated locking but worth noting — skills under active development have a high baseline edit-conflict rate.

## Patterns and Root Causes

**Pattern 1 — Independent cross-skill audit catches what self-review can't.** Self-review of `/supervise` (9 findings) was bounded by the author's own mental model. The independent agent reading four skills as a cluster found 26 issues, including all the high-value composition gaps (`[SUPER-014a]` absentia, `[SUPER-012]` escalation persistence, `[HANDOFF-010]` verification stamp). The pattern: self-review catches *intra-skill* errors; only an independent reader of the *cluster* catches *inter-skill* errors. This is structural — single-skill mental models cannot see composition gaps the way a fresh reader can. Implication: any future skill cluster (e.g., if `research-process` / `experiment-process` / `blog-process` are unified) deserves an independent cross-skill audit pass after individual skills stabilize. Action item below.

**Pattern 2 — Composition design surfaces design questions invisible in single-skill design.** `/supervise` alone made sense. `/handoff` alone made sense. The composition surfaced "what does the subordinate do when the principal's session has ended?" — a question with no good first-principles answer until the two skills were both in play and a workflow was traced. The G.1 finding forced an explicit option-A/B/C choice; the chosen rule (`[SUPER-014a]`) is now load-bearing for the entire absentia case. The generalization: when two skills are designed to compose, allocate explicit time for "compose them, trace 2-3 end-to-end workflows, verify each step has a real requirement." Today this happened reactively (audit caught it). Doing it proactively in `skill-lifecycle` would prevent the gap from existing in the first place. Action item below.

**Pattern 3 — Severity-batched fix-application protocol scales.** Five batches, ~25 fixes, one user-input gate (Batch 3). The discipline: trivial first (clear queue, build momentum, no decision cost), canonicalization second (mechanical, no decisions), design third (the load-bearing call requires user input, pause here), edges fourth (small individually but materially raises coherence), remaining last (polish). The protocol kept user attention on the one decision that needed it (the absentia rule) and didn't burn user time on cross-reference numbering or empty-block detection. Worth codifying as a recommended pattern when working through audit findings — possibly a sub-rule of `/audit` or a new sub-skill.

**Pattern 4 — Workflow-skill cluster forms a tight coupling that needs explicit handling.** The four skills now cite each other extensively: `[SUPER-014a]` cites `[HANDOFF-012]` and `[REFL-009]`; `[HANDOFF-010]` cites `[SUPER-011]` and `[SUPER-012]`; `[REFL-009]` cites `[SUPER-002]` and `[SUPER-011]` and `[HANDOFF-012]`. This is intentional — composition needs explicit cross-references — but it creates a recursive update problem: modifying one skill may require updating cross-references in three others. Today's batch handled this manually; the G.3 finding ("queue workflow-skill updates outside the session that surfaced them") gave a heuristic but not a procedure. The exception clause (in-session updates allowed when the session is *about* the cluster, as today was) covers the immediate case but doesn't generalize. The deeper issue: cluster updates need a coordinated edit pass, not a per-skill pass.

## Action Items

- [ ] **[skill]** audit: Decide whether skill-vs-skill consistency audits should be a first-class mode of `/audit` (e.g., `/audit cluster handoff supervise reflect-session`) writing to `Research/audit.md` per `[AUDIT-001]`, or remain Discovery research per `[RES-012]` written to topic-specific files. Today's audit went to `agent-workflow-skill-consistency-audit.md` because `/audit`'s scope explicitly excludes investigative work without requirement IDs to check against. If cross-skill audits become recurring, `/audit` should grow this mode.

- [ ] **[research]** Compose-then-trace pattern for skill design. Today's audit revealed gaps invisible in single-skill design but obvious when tracing a workflow across the composition. Codify the pattern in `skill-lifecycle` as a phase between `[SKILL-CREATE-006]` (content) and `[SKILL-CREATE-007]` (integration): for skills that compose with siblings, trace 2-3 end-to-end workflows across the composition and verify each step has a real backing requirement. This is the proactive form of what the audit did reactively. Needs scope before applying — would be a new `[SKILL-CREATE-006a]` or a sub-section.

- [ ] **[skill]** skill-lifecycle: Add a Phase 8 "Cluster review" applicable when 2+ skills compose. Schedule an independent cross-skill audit when the cluster reaches stability or after 90 days. Today's audit at 26 findings on a freshly-shipped four-skill cluster demonstrates the value. Without this, cluster-level drift accumulates silently between individual-skill reviews.
