---
date: 2026-04-01
session_objective: Fresh strict /audit of swift-async-primitives against /code-surface after second refactor round, then commit, clean up handoffs, and re-audit Implementation section
packages:
  - swift-async-primitives
  - swift-institute
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: code-surface
    description: "Add guidance that marker protocol conformance declarations inline on type head are standard Swift — [API-IMPL-008] targets substantial conformances with method requirements"
  - type: skill_update
    target: code-surface
    description: "Add _Namespace = Namespace module disambiguation as documented justified exception pattern for [API-NAME-004]"
  - type: package_insight
    target: swift-async-primitives
    description: "handleReceive/handleSend WORKAROUND annotations should note [API-NAME-002] coupling alongside CopyPropagation crash documentation"
---

# Async Primitives Re-Audit — Agent Verification Discipline and Handoff Triage

## What Happened

Resumed from HANDOFF.md to run a third-pass code-surface audit of swift-async-primitives (87 files, 12 modules) after a second refactor round that resolved the 2 DEFERRED findings from round two. The session had three phases: audit, commit, and implementation re-audit.

**Phase 1 — Code-surface re-audit.** Checked two parallel investigations first: timer-wheel intrusive list (COMPLETE — verdict "keep current design", `List.Linked` lacks positional removal and ABA protection) and compound-methods restructuring (HANDOFF file had empty Findings section but a concurrent session had already implemented and committed the changes). Deployed 4 parallel agents to read all 87 source files against every code-surface requirement ID. Agents returned findings which were individually verified against current source before inclusion.

Approximately 15 agent-reported findings were rejected after manual verification:
- `_Async = Async` (Async.swift:20) — classified as module disambiguation escape hatch, not [API-NAME-004] violation
- `Tick = UInt64` — domain-semantic alias within single module, not cross-package unification
- Inline `Sendable` conformance declarations (Broadcast.Error, Is, Subscription) — marker protocol inline declarations are standard Swift, not [API-IMPL-008] violations
- `Flagged.Split` — already justified as [MEM-COPY-006] constraint poisoning

Four NEW findings survived verification that the prior audit missed:
1. `handleReceive`/`handleSend` in Channel Storage files — `@usableFromInline` compound methods extracted as CopyPropagation workaround
2. `typealias Result` in Completion.swift class body — rule gap (typealiases not categorized by [API-IMPL-008])
3. `setFlag(_:)` in Waiter.Flag — private compound CAS helper
4. Three new justified exceptions added (Promise/Barrier private State, `_Async` disambiguation)

**Phase 2 — Commit and cleanup.** Discovered a concurrent session had already committed source changes AND the audit.md edit. The timer-wheel package insight was corrected from "may replace" to "cannot replace" with the full investigation verdict.

**Phase 3 — Implementation re-audit.** All 6 prior findings from the 2026-03-27 implementation audit confirmed resolved (compound methods renamed, Config accessors restructured, `dividedRoundingDown(by:)` refactored). Two new LOW findings: 3-deep conversion chains in Timer.Wheel boundary methods (`Index<Node>.Count(Cardinal(UInt(capacity)))` and `Index<Node>(Ordinal(UInt(id.index)))`) due to missing direct `Count.init(Int)` and `Index.init(Int)` bridges in cardinal/index primitives.

## What Worked and What Didn't

**Worked well**: Four parallel agents for reading 87 files was efficient — total read time approximately 90 seconds instead of serial file-by-file reading. The HANDOFF.md was well-structured and accurate about what to check, enabling immediate orientation.

**Worked well**: Verifying each agent finding against current code before inclusion in the audit table. This caught a significant volume of false positives — roughly 15 out of approximately 19 raw findings. The verification step is now clearly the most important part of the audit methodology.

**Did not work**: The compound-methods HANDOFF file's empty Findings section was misleading. The work HAD been completed by a concurrent session but the handoff was not updated. This required re-reading the git log and current source to determine actual status — a minute or two of unnecessary investigation that accurate handoff maintenance would have prevented.

**Did not work**: Agents were overly strict on [API-IMPL-008] for inline `Sendable` conformance declarations. Marker protocols with no method requirements are standard Swift — the "protocol conformances in extensions" rule targets substantial conformances that add implementation, not empty declarations. This misapplication was consistent across multiple agents, indicating a systematic interpretation gap rather than an isolated error.

**Did not work**: Concurrent session modifications to the same audit.md file required re-reading mid-flow to avoid overwriting changes. Git resolved the content cleanly, but the workflow disruption was real.

## Patterns and Root Causes

**"Verify before trust" for agent findings is the single most important audit discipline.** This session confirms the pattern from the round-two audit: 4 agents times approximately 30 requirement IDs produces a high false positive rate when agents interpret rules literally without understanding exception categories, workaround annotations, and cross-cutting conventions like [PATTERN-024] or [MEM-COPY-006]. The raw agent accuracy across both audit rounds has been approximately 45-50%. Without verification, half the audit table would be noise.

The root cause is that agents apply each rule as an isolated predicate. Real code-surface compliance requires understanding the relationships between rules — a [MEM-COPY-006] exception to [API-IMPL-005], a [PATTERN-024] exception to [API-NAME-004], a CopyPropagation workaround that explains a [API-NAME-002] violation. Agents see the violation but not the justification chain.

**Concurrent sessions modifying shared files creates confusion but not data loss.** The pattern has appeared three times now: a concurrent session commits changes to files this session plans to modify. Git handles the content merging, but the session loses its mental model of the file's current state. The fix is to re-read after discovering concurrent changes — cheap but easy to forget.

**The `_Async = Async` module disambiguation pattern deserves formal recognition.** Module-level namespace enums in Swift routinely use `internal typealias _Module = Module` to disambiguate when the module name collides with a type name. This is not type unification (no two distinct types being aliased together) — it is a single-type disambiguation. The code-surface skill should document this as a justified exception category for [API-NAME-004] rather than requiring per-audit justification.

**Marker protocol conformances inline on the type head are standard Swift.** Writing `struct Foo: Sendable` is not the same class of decision as `extension Foo: Collection`. The former is a zero-implementation declaration; the latter adds substantial method requirements. [API-IMPL-008]'s "protocol conformances in extensions" guidance targets the latter. Agents cannot distinguish these without explicit guidance.

## Action Items

- [ ] **[skill]** code-surface: Add guidance that marker protocol conformance declarations inline on type head (e.g., `struct Foo: Sendable`) are standard Swift — [API-IMPL-008] "protocol conformances in extensions" targets substantial conformances with method requirements, not empty declarations
- [ ] **[skill]** code-surface: Add `_Namespace = Namespace` module disambiguation escape hatch as documented justified exception pattern for [API-NAME-004]
- [ ] **[package]** swift-async-primitives: `handleReceive`/`handleSend` WORKAROUND annotations should be extended to note the [API-NAME-002] coupling — currently they document the CopyPropagation crash but not the naming violation that is a side effect
