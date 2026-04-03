---
date: 2026-04-02
session_objective: Consolidate ~30 ownership/memory-safety experiments into 5 topic-based packages per EXP-018 and META-024
packages:
  - swift-institute
  - swift-primitives
status: pending
---

# Experiment Consolidation — 29 Scattered Packages to 5 Topic-Based Packages

## What Happened

Executed the second phase of the corpus meta-analysis (first phase consolidated 22 research documents into 4 topic-based documents). This phase consolidated 29 individual experiment packages across swift-institute/Experiments/ (21) and swift-primitives/Experiments/ (8) into 5 topic-based packages:

1. **noncopyable-constraint-behavior** (8 absorbed) — Sequence conformance constraint poisoning, cross-module propagation
2. **noncopyable-access-patterns** (7 absorbed, cross-repo) — Consuming, borrowing, iteration, Optional unwrap for ~Copyable
3. **nonescapable-patterns** (7 absorbed) — ~Escapable accessor, storage, protocol, lazy sequence patterns
4. **ownership-transfer-patterns** (3 absorbed) — Mutex coroutine, ~Escapable accessor, bridge ownership
5. **nonsending-dispatch** (4 absorbed) — nonisolated(nonsending) dispatch contexts

All 5 packages build cleanly. Each uses library targets with enum-namespaced variants (V{NN}_{ShortName}). Multi-module experiments (4 of 29) got internal library targets. Bug reproduction code that intentionally fails to compile was commented out with `// COMPILE ERROR (expected):` annotations. Original experiments marked SUPERSEDED; both repo indexes updated.

## What Worked and What Didn't

**Worked well**:
- Parallel agent execution for the 5 packages cut wall-clock time significantly (~11 minutes total for all 5 packages vs sequential). Each agent independently read source experiments, created the package, and built it.
- The handoff document format (from the parent session's corpus meta-analysis) provided unambiguous instructions — every experiment was assigned to exactly one package, all confirmed.
- The enum namespace pattern (`enum V{NN}_{ShortName} { ... }`) cleanly solved cross-file name collisions. Every experiment defines types like `Buffer`, `Container`, `Resource` — without namespacing, the library target would have dozens of collisions.

**Didn't work as smoothly**:
- Protocol conformance extensions cannot be nested inside enums. Swift requires extensions to be at file scope with fully-qualified type paths (e.g., `extension V05_LazySequenceBorrowing.EscMapped: V05_LazySequenceBorrowing.EscSequence`). This is a recurring Swift limitation that each agent had to discover independently.
- Experiments referencing real primitives types (Property_Primitives, Property.View) had to be made self-contained with standalone type definitions. This loses the "tests against real types" value of the originals — a trade-off documented but not avoided.

## Patterns and Root Causes

**Cross-module test semantics are load-bearing**: 4 of 29 experiments existed specifically to test cross-module behavior (constraint propagation across module boundaries, cross-module protocol conformance, cross-module consuming chains). Naively merging them into a single target would destroy the very behavior they test. The internal library target pattern (e.g., `CrossModuleLib` as a dependency of the main target) preserves this correctly. This pattern should be documented in the experiment-process skill as the canonical approach for consolidating cross-module experiments.

**Bug reproduction experiments are documentation, not executable code**: Package 1's experiments exist to demonstrate constraint poisoning bugs. Their value is in showing *what breaks* — the commented-out Sequence conformances ARE the experiment. This is different from experiments that validate working patterns. The `// COMPILE ERROR (expected):` annotation convention makes this distinction explicit, but the corpus-meta-analysis and experiment-process skills don't currently distinguish between "works" experiments and "breaks" experiments.

**Consolidation parallelizes perfectly**: Each package consolidation is fully independent (different output directories, no shared state). The 5-agent parallel approach is the right pattern for future consolidation rounds.

## Action Items

- [ ] **[skill]** experiment-process: Add [EXP-018] consolidation procedure details — enum namespace pattern, internal library targets for cross-module experiments, COMPILE ERROR annotation convention for bug reproductions
- [ ] **[skill]** corpus-meta-analysis: Add experiment status taxonomy distinguishing "confirms working pattern" (code compiles) from "reproduces bug" (code intentionally fails) to guide consolidation handling
- [ ] **[doc]** Experiments/_index.md: The "Consolidated Packages" section was added ad-hoc — consider standardizing this as a permanent section in the experiment index format
