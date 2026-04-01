---
date: 2026-04-01
session_objective: Fresh code-surface re-audit of swift-async-primitives, fix all findings, triage secondary data structures against ecosystem catalog
packages:
  - swift-async-primitives
status: pending
---

# Async Primitives Audit Round Two — Agent Verification and Ecosystem Delegation

## What Happened

Resumed from HANDOFF.md to run a fresh strict code-surface audit of swift-async-primitives (89 files, 12 modules) after a prior 10-commit refactor. Used 5 parallel Explore agents to read all source files against every code-surface requirement. The agents returned ~40 raw findings. After manual verification against source, 18 survived (16 OPEN, 2 DEFERRED) — the rest were false positives from agents misapplying rules.

Implemented all 16 OPEN findings in 11 commits: type extractions ([API-IMPL-005]), method-to-extension moves ([API-IMPL-008]), compound name renames ([API-NAME-001]), and file renames ([API-IMPL-006]). All compiled clean on first build after each step except Step 1 (Broadcast Subscription extraction), which needed two fixes: widening `_state` from private to internal, and adding `Dictionary_Primitives` import for Swift 6 member import visibility.

Then triaged all secondary data structures against the ecosystem-data-structures catalog. Found that nearly everything already delegates to ecosystem primitives (Deque, Dictionary.Ordered, Buffer.Arena.Bounded, Ownership.Slot). One investigation target: the Timer Wheel's ad-hoc intrusive linked list (Slot/Node) — possibly replaceable by `List.Linked<E, 2>` from `List_Primitives`.

## What Worked and What Didn't

**Worked well**: Parallel agents for initial file reading was effective — 5 agents covered 89 files in ~2 minutes. The audit template and systematic per-file reporting caught real violations that visual scanning would miss.

**Didn't work**: Agent finding accuracy was ~45% (18 real out of ~40 reported). Three categories of false positives:
1. **Hallucinated types**: One agent reported `struct Free` in Storage.swift that doesn't exist
2. **Misapplied rules**: Agents flagged `typealias Gate = Promise<Void>` and `typealias ID = Handle<_Entry>` as [API-NAME-004] violations, missing the [PATTERN-024] generic instantiation exception
3. **Over-application**: Agents flagged `isFinished` as [API-NAME-002] compound identifier, not recognizing Swift's `is` + adjective boolean naming convention

**Key surprise**: Extracting a type to a separate file can cascade into access-level and import changes. The Broadcast Subscription extraction required both `private → internal` for `_state` and a new `import Dictionary_Primitives` — neither visible from reading the type declaration alone.

## Patterns and Root Causes

**Agent verification is non-negotiable for audits.** The ~45% accuracy rate means raw agent output would produce an audit with more false positives than real findings. The pattern: use agents for coverage (reading all files), verify every finding against source before committing to the audit table. This is a structural limitation — agents apply rules literally without understanding exceptions or cross-cutting conventions like [PATTERN-024].

**Type extraction creates access-level cascades.** When types move from the same file to a new file, they lose access to `private` members. This is a systematic pattern: [API-IMPL-005] compliance (separate files) sometimes forces [API-IMPL-010]-adjacent access widening. The fix is mechanical (widen to internal) but must be anticipated.

**Ecosystem delegation is already high.** The data structure triage was faster than expected because async-primitives already uses ecosystem types pervasively. The one remaining ad-hoc structure (intrusive linked list) is tightly coupled to arena generation tokens — it may be intentionally lower-level than `List.Linked`. The investigation handoff will determine this.

## Action Items

- [ ] **[skill]** audit: Add guidance that agent-reported findings must be verified against source before inclusion — raw agent accuracy is ~45% for code-surface rules with exceptions ([PATTERN-024], [MEM-COPY-006], [IMPL-024])
- [ ] **[skill]** code-surface: Add note to [API-NAME-002] that Swift boolean naming convention (`is` + adjective: `isEmpty`, `isFinished`) is not a compound identifier violation
- [ ] **[package]** swift-async-primitives: Timer Wheel intrusive list investigation may reveal that `List.Linked<E, 2>` can replace ~120 lines of manual list management — track via HANDOFF-timer-wheel-intrusive-list.md
