---
date: 2026-03-30
session_objective: Audit IO.Lane / IO.Blocking.Lane boundary, produce findings, and converge on a remediation plan via Claude-ChatGPT collaborative discussion
packages:
  - swift-io
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-074] shared-vocabulary test for cross-layer type references
  - type: skill_update
    target: code-surface
    description: Add [API-IMPL-011] wrapper completeness requirement
  - type: package_insight
    target: swift-io
    description: Batch 2A public contract audit — @_exported + shared-vocabulary test
---

# IO.Lane Boundary Audit and Collaborative API Review

## What Happened

The session had three phases. First, a systematic audit of the IO.Lane / IO.Blocking.Lane boundary in swift-io's IO Executor module, checking 11 source files against [IMPL-INTENT], [API-LAYER-001], [IMPL-060], [PATTERN-017], and [API-NAME-002]. The audit produced 6 findings (3 HIGH, 3 MEDIUM) and recommended Option A: give IO.Lane its own `run` surface.

Second, ChatGPT reviewed the full swift-io source bundle (~177K tokens) and provided broad feedback covering API surface discipline, platform error handling, nomenclature drift, lifecycle ergonomics, and typed-throws bridging. ChatGPT independently and firmly agreed with Option A.

Third, a structured collaborative discussion (3 rounds, EXPLORING → NARROWING → CONVERGED) produced a batched implementation plan: Batch 1A (lane boundary completion), Batch 1B (same-touch nomenclature cleanup), Batch 2A (public contract audit including IO.Pending re-parameterization), Batch 2B (internal hygiene).

## What Worked and What Didn't

**Worked well**: The audit methodology — reading all files first, then checking each against specific requirement IDs — produced precise findings with file:line citations. The handoff file format (`HANDOFF-io-lane-boundary-audit.md`) with its three-phase structure (audit, design evaluation, recommendation) was effective for organizing the investigation.

**Worked well**: The collaborative discussion converged in 3 rounds because both parties had read the same code. ChatGPT's refinements were substantive — splitting batches into 1A/1B and 2A/2B, proposing the shared-vocabulary three-condition test, and reframing "accepted leaks" as "shared vocabulary deliberately retained." These were genuine improvements, not rubber-stamping.

**Worked well**: ChatGPT's broad package review surfaced issues the scoped audit wouldn't have found — particularly the systemic `IO.Blocking.*` leakage across 5 public API sites (not just IO.Pending) and the observation that "the implementation is more mature than the public API boundary."

**Didn't work well**: The initial package export at 177K tokens was too large for ChatGPT's context. The user had already provided it separately, but the export skill should probably warn more aggressively or offer module-scoped exports for large packages.

## Patterns and Root Causes

**Pattern: Incomplete boundary layers create worse impressions than no boundary at all.** IO.Lane provides genuine value (factories, error domain, Handle wrapping, DI conformance) but the absence of `run` — the primary operation — makes the entire wrapper look fake. Every consumer must reach through `_backing`, which reads as if the wrapper is useless. The fix is small (3 method overloads), but the damage to API perception is disproportionate. This pattern generalizes: a wrapper that encapsulates 90% of an interface is worse than one that encapsulates 100% or 0%, because the 10% escape hatch dominates the user's experience.

**Pattern: Shared-vocabulary test for cross-layer type references.** The collaborative discussion produced a reusable decision rule: a lower-layer type is acceptable in a higher-layer public signature if (1) it denotes a stable concept not specific to the lower layer's mechanics, (2) it doesn't force callers to reason about the hidden boundary, and (3) wrapping it would add indirection without changing semantics. This separates `IO.Pending<IO.Blocking.Lane>` (fails condition 2) from `IO.Blocking.Threads.Options` (passes all three). This test should be documented as a general architectural principle, not just an IO-specific decision.

**Root cause of the dead IO.Executor.run**: It was designed for the Pool actor's error hierarchy (`IO.Error<E>`), but the actual consumers needed different error types (`IO.Lane.Error`, `IO.Failure.Work`). When the error hierarchy diverges from the call sites, bridge code dies on the vine. The lesson: error mapping belongs at the type boundary that owns the error domain, not in an intermediate bridge.

## Action Items

- [ ] **[skill]** implementation: Add shared-vocabulary test as a corollary of [API-LAYER-001] — three conditions for retaining lower-layer types in higher-layer signatures
- [ ] **[skill]** code-surface: Add guidance on wrapper completeness — a wrapper that owns construction, invariants, and error domain MUST also own the primary operation
- [ ] **[package]** swift-io: Batch 2A public contract audit — systematic review of all `@_exported import` and `public import`, apply shared-vocabulary test to each `IO.Blocking.*` type in public signatures
