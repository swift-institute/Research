<!--
---
title: treereduce-swift Feasibility
version: 1.0.0
last_updated: 2026-03-31
status: IN_PROGRESS
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

(Pending investigation)

## Provenance

- Source reflection: 2026-03-31-issue-investigation-literature-study.md
- Research document: Research/issue-investigation-best-practices.md
