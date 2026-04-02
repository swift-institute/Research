---
date: 2026-04-01
session_objective: Condense the implementation skill from ~2300 lines to ~1000 while losing no actionable information
packages:
  - swift-institute
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: reflect-session
    description: "Add 'experiment-rule bidirectional audit' as optional step for skill maintenance sessions"
  - type: skill_update
    target: skill-lifecycle
    description: "Add condensation guidance distinguishing 'illustrative examples' (trimmable) from 'implementation recipes' (must keep)"
  - type: research
    target: experiment-index-reverse-mapping
    description: "Should _index.md track which skill rule each experiment validates? Reverse index would make bidirectional audit cheaper"
---

# Implementation Skill Condensation — Experiment Audit as Quality Gate

## What Happened

The implementation skill had grown to 2305 lines (~28K tokens). Session objective: condense it without information loss.

**Phase 1 — Condensation** (2305 → 948 lines, 59% reduction):
- Deleted 6 PATTERN rules that were pure cross-references to other skills (009, 010, 011, 015, 018, 021)
- Merged overlapping rules: IMPL-EXPR-001+030, IMPL-002/003/003a/004/005, IMPL-031/032→033, IMPL-050/051/052/053, IMPL-040+041
- Collapsed absorbed anti-patterns and design patterns into compact reference tables
- Trimmed academic provenance, verbose prose, redundant code examples

**Phase 2 — Self-review** identified 5 genuine losses:
1. IMPL-000's infrastructure routing tree (WHERE to add things)
2. IMPL-001's "Gap — DO add" contrast table
3. PATTERN-022's ManagedBuffer nesting code example
4. COPY-FIX-009's deinit workaround code (the `withUnsafePointer` trick)
5. PATTERN-015 (macro naming exception) — not captured in code-surface

Items 1–4 restored with improvements (routing tree became a table with new Property.View category; gap table updated — removed `range.map.bounds` which is now filled). Item 5 moved to code-surface as an API-NAME-001 exception.

**Phase 3 — Experiment audit** checked every compiler-behavior claim against experiment coverage:
- 7 rules already had experiments (references restored as "Validated by" lines)
- 2 rules had NO experiment (IMPL-073, IMPL-082) — created and confirmed both
- 1 experiment reference was stale (IMPL-023) — located at correct path

**Phase 4 — Reverse audit** (experiments → rules) scanned ~250 experiments across swift-institute and swift-primitives. Found 4 uncaptured findings:
- Ownership modifiers are not an overload axis (IMPL-067 amendment)
- `nonisolated(nonsending)` async-only scope (IMPL-062 amendment)
- Protocol coroutine accessor limitation with ~Copyable (IMPL-026 amendment)
- Property.View fails for class-backed bases (IMPL-021 table updated)

Refactored `ownership-overloading-limitation` experiment from a narrow ownership test to a comprehensive overloading catalog (Q1–Q10).

Final: 2305 → 1017 lines (56% reduction).

## What Worked and What Didn't

**Worked well**:
- The self-review caught real losses. The initial 59% cut was too aggressive in 5 specific places — each identifiable by "someone implementing this would be stuck without the dropped content."
- The experiment audit was high-value. It exposed 2 unvalidated claims and 4 uncaptured findings. The reverse audit (experiments → rules) was something I hadn't planned but surfaced real gaps.
- Merging rules that state the same principle with different examples (typed arithmetic, iteration, bounded indexing) was the highest-ROI condensation. The tables are more scannable than the separate rules.

**Didn't work well**:
- First pass was too aggressive on code examples. The ManagedBuffer CORRECT/INCORRECT example and the COPY-FIX-009 deinit code are not prose — they're the actual implementation pattern. "Describe it in words" doesn't work for non-obvious pointer tricks.
- The agent search for IMPL-023's experiment initially reported "NOT FOUND" when the experiment did exist at the expected path. Agent search reliability for deep directory structures is inconsistent.

## Patterns and Root Causes

**Pattern: Code examples serve different purposes**. Some examples illustrate a principle (these can be trimmed or tabled). Others ARE the implementation — the reader needs to copy them verbatim (ManagedBuffer nesting, deinit workaround). The condensation heuristic should distinguish: "Would someone be stuck without this code?" If yes, it's not an example — it's a recipe.

**Pattern: Experiment-rule bidirectional audit as quality gate**. Checking rules → experiments catches unvalidated claims. Checking experiments → rules catches uncaptured knowledge. Neither direction alone is sufficient. The ownership-overloading finding sat in an experiment for 2+ months without being captured as a rule constraint. The reverse direction is underutilized.

**Pattern: Skill condensation creates an opportunity for domain migration**. PATTERN-015 (macro naming) was in the wrong skill for its entire existence. The condensation exercise forced reviewing each rule's canonical home — something that never happens during incremental growth.

## Action Items

- [ ] **[skill]** reflect-session: Add "experiment-rule bidirectional audit" as an optional step when reflecting on skill maintenance sessions — it catches both unvalidated claims and uncaptured knowledge
- [ ] **[skill]** skill-lifecycle: Add condensation guidance — distinguish "illustrative examples" (trimmable) from "implementation recipes" (must keep) when compressing
- [ ] **[research]** Should the experiment index (_index.md) track which skill rule each experiment validates? Currently this mapping only exists as "Validated by" lines in skills — a reverse index would make the bidirectional audit cheaper
