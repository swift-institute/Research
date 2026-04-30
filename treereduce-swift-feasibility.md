<!--
---
title: treereduce-swift Feasibility
version: 1.1.0
last_updated: 2026-04-30
status: DEFERRED
tier: 2
scope: ecosystem-wide
applies_to: [swift-institute, issue-investigation]
normative: false
---
-->

# treereduce-swift Feasibility

## Context

The issue-investigation literature study (2026-03-31) identified a significant tooling gap:
Swift lacks source-level automated test case reduction. Comparative analysis showed:

| Ecosystem | Source-Level Reducer | Toolchain Bisector |
|-----------|--------------------|--------------------|
| C/C++ | C-Reduce (25x better than delta debugging) | git bisect |
| Rust | treereduce, icemelter | cargo-bisect-rustc |
| GHC | Manual only (known gap) | — |
| Swift | **None** | **None** |

The `tree-sitter-swift` grammar exists. `treereduce` is language-generic given a grammar.

## Question

Is it feasible to build `treereduce-swift` using the existing `tree-sitter-swift` grammar,
and would it meaningfully improve the [ISSUE-003] reduction workflow?

## Analysis

### Sub-Questions

1. **Grammar completeness**: Does `tree-sitter-swift` cover Swift 6.x syntax (async/await,
   ~Copyable, macros, typed throws)?
2. **treereduce integration**: How much effort to integrate a new grammar into treereduce?
   Is it plug-and-play or does each language need custom reduction strategies?
3. **Effectiveness for compiler bugs**: C-Reduce is 25x better than generic delta debugging
   because it uses language-aware transformations. Would treereduce-swift achieve similar
   gains, or would tree-sitter's CST-level reductions miss important patterns?
4. **Alternative approaches**: Would a SIL-level reducer (extending `bug_reducer.py`) be
   more effective given that most ecosystem bugs are optimizer bugs?

## Outcome

**Status**: DEFERRED (2026-04-30)

**Disposition**: Investigation didn't advance past the four-sub-questions stub. The tooling gap is real — Swift uniquely lacks both source-level and IR-level automated test-case reduction — but the infrastructure cost of building `treereduce-swift` is non-trivial (grammar audit, treereduce integration, Swift-specific reduction strategies), and no current Swift compiler bug investigation has been blocked sufficiently to motivate the build.

**Blocker**: Tool-building investments need a forcing function. Until a specific compiler-bug investigation is blocked on inability to reduce a test case efficiently, the cost-benefit doesn't tilt. The 25× C-Reduce-vs-delta-debugging multiplier is real but hypothetical for the ecosystem until validated against actual Swift bugs.

**Resumption trigger** (any of):
- A specific compiler-bug investigation gets blocked on test-case reduction effort (sub-question 3 — effectiveness — answered empirically)
- `tree-sitter-swift` adds Swift 6.x coverage demonstrably (sub-question 1 answered)
- An ecosystem-wide compiler-bug audit produces a reduction-bottleneck finding (sub-question 4 — would SIL-level be more effective — answered with data)

**Held findings**:
- The grammar exists; the integration question (treereduce plug-and-play vs custom strategies) is the load-bearing technical unknown
- A SIL-level reducer extending `bug_reducer.py` may be a stronger investment given that most ecosystem bugs are optimizer bugs (sub-question 4) — but that's a separate Doc

## Provenance

- Source reflection: 2026-03-31-issue-investigation-literature-study.md
- Research document: Research/issue-investigation-best-practices.md
