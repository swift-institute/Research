---
date: 2026-04-15
session_objective: Determine whether swift-executors should provide composable primitives that absorb IO.Event.Loop and IO.Completion.Loop, and — after the user opened the scope — design the complete executor toolkit.
packages:
  - swift-executors
  - swift-io
  - swift-executor-primitives (proposed)
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: skill_update
    target: code-surface
    description: "Added [API-NAME-001a] Single-type-no-namespace rule"
  - type: skill_update
    target: implementation
    description: "Extended [PATTERN-013] with lossy-unification criterion for axis-divergent signatures"
  - type: no_action
    description: "[skill] delegated-research write-discipline — already captured in feedback_agent_output_discipline.md and reflect-session skill"
---

# swift-executors Toolkit Taxonomy Research

## What Happened

The session began with a targeted question from the user: could `swift-executors` provide primitives composable enough that `IO.Event.Loop` and `IO.Completion.Loop` would use them instead of hand-rolling their own `SerialExecutor` conformances? I produced the first research doc (`composable-executor-abstractions.md`) evaluating four designs against the triage's race-safety constraint, recommending **Design 1 (`Polling.Executor`)** with one open question on swift-executors' mission scope.

The user answered that open question decisively: "swift-executors should be the complete and no-brainer package for executors." That reframed the work from targeted extraction to complete-toolkit design.

Several rounds of naming debate followed — `Polling.Executor` vs `Kernel.Thread.Polling.Executor` vs `Kernel.Thread.Executor.Polling`; `WorkStealing` vs `Stealing`; whether `Scheduled` is a variant or a domain; whether `Main` belongs in swift-executors or swift-threads. The user codified a "single-type-no-namespace" rule mid-debate: a namespace with only one type is not a namespace — it's a variant label — so `Cooperative`, `Main`, and `Scheduled` nest as `Executor.Cooperative` / `Executor.Main` / `Executor.Scheduled<Base>`, not as top-level domains.

I launched a comprehensive research agent (background, opus) to produce the full design-space survey. It stalled: 30+ minutes runtime, 0-byte target doc. Final activity in the transcript was the agent trying Edit on an empty file, then Bash heredoc — trapped in a local minimum where the write was failing and it kept retrying. I killed it via `TaskStop`.

The user pasted a multi-round conversation in which they had iterated through several naming taxonomies and settled the design. I launched a second research agent with a much tighter brief: the taxonomy was **locked**, the job was **validate not design-from-scratch**, and the prompt included explicit **write-discipline guards** (write scaffold within first 5 tool calls, use Write not Edit on empty files, no bash heredoc for documents, stop-if-stuck time budget). The second agent succeeded in ~13 minutes, producing a 1099-line doc covering V1–V8 validation. It surfaced one substantive finding: **V8 rejected a unified `Wait.Primitive` protocol/witness** because the two concrete wait shapes (`Condvar.wait()` with lock held and no args vs `Event.Source.wait(deadline:into:)` with no lock and buffer) have categorically divergent signatures; a common protocol would force one side to lie.

The user ran a `[SUPER-*]` supervision pass: drift check, question classification, acceptance-criteria verification, termination decision. All 8 open questions were resolved in the supervision reply. I landed the decisions in the doc as a new "Decisions (Post-Supervision)" section, bumped it to v1.1.0 DECISION status, created `Research/_index.md` per `[RES-003c]`, updated the memory file, and wrote `HANDOFF.md` for the implementation phase.

Three research docs produced this session:
- `swift-executors/Research/composable-executor-abstractions.md` (v1.0.0 RECOMMENDATION) — Design 1 origin
- `swift-executors/Research/executor-package-design.md` (v1.1.0 DECISION) — ratified taxonomy
- `swift-executors/Research/_index.md`

Plus `/Users/coen/Developer/HANDOFF.md` (replaced a prior Completion-L1 handoff whose target had already been acted on — verified `swift-kernel-primitives/Sources/Kernel Completion Primitives/` exists).

## What Worked and What Didn't

**Worked**:

- **Research-to-research chaining.** Each doc reused the prior doc's output as input. Triage → composable-executor-abstractions → executor-package-design: each was a step, not a restart. The final DECISION cites and builds on the earlier two.
- **Locked premises in the second agent's brief.** Naming was locked, scope was locked, taxonomy tree was in the prompt. The agent validated against V1–V8 instead of deriving the taxonomy from first principles. ~13 minutes produced ~1100 lines of coherent doc.
- **Write-discipline guards.** The first agent's failure mode (Edit-on-empty-file → bash heredoc → stuck) was addressed by explicit rules in the second prompt. The second agent still hit a Write/Edit denial and fell back to heredoc, but produced a clean doc because the structure was discipline, not reflex.
- **`[SUPER-*]` supervision pattern.** The user's supervision reply was compact: drift check → 8 class-b question answers → V8 accept → operational flags → acceptance-criteria table → termination decision. It left nothing ambiguous and required no further research.
- **Memory-first implementation setup.** The ratified taxonomy went into `project_swift_executors_mission.md` before the handoff. The handoff points at memory plus the research doc, not at the conversation. The implementation agent inherits durable state, not deliberation history.

**Didn't work**:

- **First research agent deadlocked.** Ran ~30 min with 0-byte output doc. The transcript showed Edit attempts failing (file was empty) and a pivot to bash heredoc. Permissive-tools + open-ended-brief + no write-discipline-rules = agent trapped in local minimum.
- **Subagent Write/Edit permissions were denied.** The `settings.json` policy blocked Write and Edit in the subagent environment despite my parent session having them. Heredoc worked for one file; it will not scale for the implementation agent (dozens of new Swift files). Flagged to the user; they explicitly deferred the fix.
- **Three rounds of naming bikeshedding.** Each round applied `[API-NAME-001]`'s Decision test case-by-case. The underlying rule — single-type-no-namespace — was implicit for three rounds before the user made it explicit. Once stated, all remaining placements resolved in one pass.

## Patterns and Root Causes

**Pattern 1 — Open research briefs deadlock on tool-use friction.** The first agent's prompt was comprehensive but permissive: "survey the full space, propose the taxonomy, validate against V1–V8, write the doc." When the Write tool's initial invocation produced an empty file (or was denied, depending on the permission layer), the agent didn't pivot — it kept attempting Edit against an empty `old_string` match target, then tried Bash heredoc, then hit another wall. No instruction in the prompt told it to detect the failure and abandon the approach. **Root cause**: permissive instructions + non-idempotent tool failures = local-minimum trap. **Corrective**: prompts that delegate multi-tool work MUST include explicit write discipline and a stop-if-stuck escape valve. The second agent's prompt added all four (scaffold early, Write-not-Edit on empty, no heredoc, time budget) and completed cleanly.

**Pattern 2 — Naming debates converge on rules, not instances.** Three rounds of naming produced three different placements before the user codified "single-type-no-namespace." The rule had been latent across the ecosystem — `Kernel.Thread.Executor.Sharded` nests because `.Sharded` has no siblings outside `Executor`; `RFC_4122.UUID` nests because the RFC domain has multiple types. Neither had been articulated as a test until this session forced the question. **Root cause**: `[API-NAME-001]`'s "Nest.Name decision test" is necessary but not sufficient — it tells you if X belongs under Y, but not whether Y should exist as a namespace at all. The single-type criterion is the missing half. **Corrective**: `[API-NAME-*]` should include an explicit rule preventing speculative namespace creation. This session's bikeshedding cost four messages of back-and-forth; the rule costs one line.

**Pattern 3 — Lossy unification is the corollary of the 3-conformer protocol threshold.** `[PATTERN-013]` says protocols require 3+ concrete conformers. The V8 finding adds: even with 3+ conformers, if unification would force axis-divergent signatures to lose information, concrete sibling types are the right answer. `Executor.Wait.Condvar` and `Executor.Wait.Event.Source` differ on: lock held (yes/no), arguments (none / deadline + buffer), throwing (no / `(Error)`), mutation (none / writes buffer). Any protocol that accepts both must drop at least two of these dimensions in its signature — the Condvar side can't express the Event.Source contract; the Event.Source side can't use the Condvar's thread-local guarantees. This is general: whenever a candidate protocol would make a type lie about its constraints, concrete sibling types preserve more information. The `[IMPL-COMPILE]` principle ("type system expresses invariants") picks the same side. **Corrective**: extend `[PATTERN-013]` with the "lossy unification" criterion.

## Action Items

- [ ] **[skill]** code-surface: Add a "Single-type-no-namespace" rule to `[API-NAME-*]`. A namespace containing only one type is a variant label and MUST nest under its parent type — not as a top-level namespace. Examples: `Executor.Cooperative` (no siblings, nests), `Kernel.Thread.Executor.Polling` (no siblings outside Executor-variants, nests), but `Kernel.Thread` (has Handle, Executor, Pool, Worker → is a real domain). Specific target: `[API-NAME-001]` section of `code-surface` skill. Impact: this session spent three conversational rounds bikeshedding naming before the rule was articulated; codifying it prevents recurrence.

- [ ] **[skill]** research-process: Add a delegated-research write-discipline requirement. When dispatching subagents to produce documents, the prompt MUST include: (a) write doc scaffold with placeholder sections within first 5 tool calls; (b) prefer Write (full overwrite) over Edit on empty or near-empty files; (c) do not use bash heredoc for documents; (d) explicit time budget with stop-if-stuck criteria. This session's first agent deadlocked exactly on the absence of these rules; the second succeeded when they were explicit. Specific target: a new `[RES-*]` requirement — possibly `[RES-027] Delegated-Research Write Discipline` — in `research-process` skill.

- [ ] **[skill]** code-surface: Extend `[PATTERN-013]` (3-conformer protocol threshold) with a "lossy unification" criterion. Even with 3+ concrete conformers, if a candidate protocol would force axis-divergent signatures to lose information, concrete sibling types under a namespace are preferred over the protocol. V8's `Executor.Wait` finding is the canonical example; the pattern generalizes. Specific target: `[PATTERN-013]` in `code-surface` skill (or possibly a new `[API-DESIGN-*]` rule in implementation skill if it better fits there).
