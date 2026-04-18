---
date: 2026-04-18
session_objective: Continue Phase 4b (Paths.Path byte scanning) from HANDOFF-path-decomposition.md; re-audit Path Type Compliance after ecosystem restructuring
packages:
  - swift-paths
  - swift-path-primitives
  - swift-iso-9945
  - swift-file-system
  - swift-kernel
  - swift-posix
status: pending
---

# Path Type Compliance Audit Refresh and Architecture Decisions

## What Happened

Session began by verifying HANDOFF-path-decomposition.md state (Phase 4a complete, Phase 4b queued). Read all relevant files across L1 (Path.Protocol, Path.View, Path.swift), L2 (POSIX conformance), and L3 (Paths.Path, Path.Navigation.swift, Path.View.swift).

Identified the dependency chain problem: to call `view.parent` via the L1 protocol, swift-paths would need to import `swift-iso-9945` (L2) for the retroactive conformance. This pulls 6 transitive deps (algebra, loader, string, clock, terminal primitives + ascii) for 15 lines of separator scanning. The user confirmed this was wrong.

Reframed the problem through a "pedantic domain modeling professor" lens: path decomposition is a pure function of bytes + separator, not a platform capability requiring protocol conformance from another package. The algebra is the same; the representation differs by layer. L3 scans its `[Char]` storage directly.

Three architectural decisions landed:
1. No swift-iso-9945 dep for swift-paths
2. Direct `[Char]` byte scanning for Phase 4b
3. Phase 4c should use `Paths.Path` (not `Kernel.Path.View`) since atomic-write relocated to L3

Re-audited Path Type Compliance at `swift-institute/Audits/audit.md`. Major ecosystem restructuring since 2026-03-31: atomic-write code moved from swift-kernel to swift-file-system, swift-iso-9945 decomposed into ~16 sub-targets, Windows.Loader moved to swift-microsoft superrepo. Updated all 58 findings with current file paths and statuses. 2 RESOLVED (POSIX glob directory parameter), 49 OPEN, 7 DEFERRED carried.

Wrote handoff with supervisor block per /supervise skill for fresh agent session. Phase 4b implementation was started (parent + appending byte-scanning edits drafted) but the user interrupted to request a broader ecosystem model investigation first.

## What Worked and What Didn't

**Worked**: The domain-modeling reframe ("path decomposition is a function of the path algebra, not the operating system") cut through layers of architectural indirection and made the right answer obvious. The audit refresh was thorough — parallel agents verified all 58 findings against current source, catching file relocations that would have silently broken future references.

**Didn't work**: Spent too long analyzing whether to add swift-iso-9945 as a dep before realizing the answer was "don't use the protocol at all." The analysis was correct but over-invested — the 6-transitive-dep count should have been a terminal signal immediately. Also, the Phase 4b implementation was started without the user's broader context (they wanted an ecosystem model first, not a jump to implementation).

## Patterns and Root Causes

**"Single implementation" != "single code path"**: The audit said "single implementation at L1; Paths.Path delegates to it — no double implementations." This was interpreted as "L3 must call L1 code." The correct reading is "single algebra" — the byte-scanning algorithm is the same, but each layer applies it to its own storage representation. L1's protocol serves L1 types; L3 scans its own `[Char]` directly. These are not duplicated implementations any more than sorting an Array and sorting a Deque are duplicated.

**Relocation changes architectural constraints**: When Kernel.File.Write moved from swift-kernel to swift-file-system (2026-04-09), it went from L3-kernel (can't depend on swift-paths) to L3-user-facing (already depends on swift-paths). The original Phase 4c design (use Kernel.Path.View internally) was designed around the old location's constraints. The new location makes Paths.Path the natural internal type. Architectural decisions must be re-evaluated when the code they govern moves.

**Audit refresh as discovery tool**: The re-audit wasn't just status-checking — it revealed the atomic-write relocation, which in turn revealed the Phase 4c calculus change. Running audits after restructuring catches architecture-level consequences that git diffs alone miss.

## Action Items

- [ ] **[skill]** implementation: Add guidance that "single implementation" in architecture documents means "single algebra/approach" not "single call site" — L3 may apply the same algorithm to its own representation without violating the principle
- [ ] **[package]** swift-paths: Phase 4b implementation ready to execute — byte scanning on `_storage.buffer` for `parent` and three `appending` overloads, ~50 lines, no new deps
- [ ] **[research]** Evaluate whether `lastComponent` should align with L1 `component` semantics (empty for trailing separators) or preserve current L3 behavior (last non-empty component) — needs test coverage for trailing-separator edge cases first
