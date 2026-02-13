---
date: 2026-02-12
session_objective: Complete remaining items from the Data Structures post-refactor plan
packages:
  - swift-bit-vector-primitives
  - swift-array-primitives
  - swift-hash-table-primitives
  - swift-list-primitives
  - swift-queue-primitives
  - swift-pool-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: copyable-remediation
    description: Strengthen [COPY-FIX-008] with silent failure mode warning for @unchecked Sendable
  - type: research_topic
    target: tagged-structural-sendable.md
    description: Can Tagged<Element, Cardinal> prove structural Sendable?
  - type: skill_update
    target: code-organization
    description: Clarify [API-IMPL-005] counts type declarations, not extension blocks
---

# Data Structures Plan Completion — Audit Staleness and Verification Depth

## What Happened

Continued executing the "Data Structures — Post-Refactor Next Steps" plan across two sessions. The plan had 6 phases (correctness, safety, typed throws, typed indices, file organization, cleanups) with 22 items total.

Session 1 completed: 1a (isFull fix), 2a (metadataPointer), 4a-4d (capacity → typed Index<Element>.Count), 6d (Pool dependency), plus creating List Primitives Test Support. Session 2 tackled the remaining 9 items: 1b/1c/1d (correctness), 5c/5d/5e (file splitting), 6a/6b/6c (cleanups).

Key outcome: of the 9 items investigated in session 2, only 4 required actual code changes. Three correctness bugs (1b, 1c, 1d) were already fixed during the buffer-primitives refactor. Two items (5e, 6a) were not real violations on closer inspection. The actual work was: splitting bit-vector files per [API-IMPL-005] (5c, 5d), adding Array Bounded Primitives product (6b), and narrowing Hash.Table Sendable (6c).

## What Worked and What Didn't

**Worked well**: Parallel agent investigation of all remaining items at once. All four agents returned in under 90 seconds, immediately revealing that 1b/1c/1d were already fixed. This prevented wasted effort — without parallel investigation, we might have spent time reading code for bugs that no longer existed.

**Worked well**: The file splitting for bit-vector was mechanical but clean. Each tag enum (Statistic, All, Capacity) paired naturally with its property accessor and Property extension into a self-contained file. The pattern was uniform across Dynamic, Bounded, and Inline variants.

**Didn't work well**: The original audit that produced the plan was run against pre-refactor code. Three of the highest-priority items (correctness bugs) were already resolved by the time we executed the plan. The plan had no mechanism to detect this staleness.

**Confidence was low**: On the Hash.Table Sendable change — `@unchecked` is needed because phantom-typed `Tagged<Element, Cardinal>` may not structurally prove Sendable. The constraint change from `~Copyable` to `Sendable` is clearly correct, but whether `@unchecked` can eventually be removed depends on how Tagged's Sendable conformance interacts with phantom type parameters.

## Patterns and Root Causes

**Audit-then-refactor creates stale plans.** The audit ran before the buffer-primitives refactor, which incidentally fixed 1b, 1c, and 1d. The plan captured symptoms (wrong error case, no-op assignment, duplicate init) without noting which code paths would be affected by the refactor. This is a structural problem: when a major refactor touches the same packages an audit covers, the audit findings need re-verification before execution.

The mitigation is simple: verify before fixing. The parallel agent pattern naturally provides this — sending agents to read the current state of each item before starting work. This session demonstrated the pattern working correctly, but the first session (which did the bulk of the work) proceeded more directly.

**"Not a real issue" items reveal audit granularity mismatch.** Item 5e (Dynamic+returning.swift) had only 1 type declaration plus method extensions — not a violation of [API-IMPL-005]. Item 6a (Stack subscripts) were on different types (Stack vs Stack.Static) — not duplicates. Both were flagged by an audit looking at surface-level patterns (multiple `extension` blocks, similar code shapes) rather than semantic content (type declarations vs method extensions, same type vs different types).

**Unconditional Sendable is a quiet correctness risk.** `@unchecked Sendable where Element: ~Copyable` made Hash.Table Sendable for ALL element types, including non-Sendable ones. This compiles without warning — the compiler trusts `@unchecked`. The Static variant already had the correct `where Element: Sendable` constraint, making the Dynamic variant's broader constraint an inconsistency that could have been caught by pattern comparison during the original audit.

## Action Items

- [ ] **[skill]** implementation: Add guidance that `@unchecked Sendable` conformances MUST constrain to `where Element: Sendable` (not `~Copyable`) — the compiler cannot catch this, so the skill must
- [ ] **[research]** Can `Tagged<Element, Cardinal>` prove structural Sendable when `Element: Sendable` and `Cardinal: Sendable`? If so, `@unchecked` could be removed from Hash.Table and similar phantom-typed containers
- [ ] **[skill]** code-organization: Clarify that [API-IMPL-005] counts type *declarations* (struct/enum/class), not method extensions — multiple `extension Property.View where ...` blocks adding methods to existing types are permitted in one file
