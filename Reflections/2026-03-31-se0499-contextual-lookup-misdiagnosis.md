---
date: 2026-03-31
session_objective: Investigate and resolve .ascending contextual member lookup rejection on Swift 6.4-dev
packages:
  - swift-comparison-primitives
  - swift-ordering-primitives
  - swift-input-primitives
  - swift-collection-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: issue-investigation
    description: Added [ISSUE-020] SE-proposal constraint check between Step 0 and Step 1
  - type: no_action
    description: "SE-0499 ecosystem audit research — already completed by Entry 10"
  - type: package_insight
    target: swift-buffer-primitives
    description: DeinitDevirtualizer ICE on Buffer.Unbounded — needs investigation handoff
---

# SE-0499 Contextual Lookup Misdiagnosis — Constraint Landscape Shift, Not Compiler Regression

## What Happened

Started from a handoff: `Collection Primitives` rejected `.ascending` on 6.4-dev with `contextual_member_ref_on_protocol_requires_self_requirement`. The diagnostic said "protocol extension Self constraint" on a struct extension. Looked like a textbook rejects-valid regression.

Followed the issue-investigation skill. Classified as rejects-valid. Built five standalone reproducer variants — none triggered the bug. Searched compiler source: found two commits in `CSSimplify.cpp` that changed the `attemptInvalidStaticMemberRefOnMetatypeFix` path. Spent significant time pursuing a constraint-solver regression theory.

Then the user pointed at SE-0499. One test (`struct NC: ~Copyable, Comparable`) confirmed SE-0499 was active in 6.4-dev. The entire investigation pivoted.

The real cause: SE-0499 removes implicit `Copyable` from `Comparable`/`Equatable`. The extension `Ordering.Comparator where T: Swift.Comparable` gained implicit `where T: Copyable` on 6.4 (backwards-compatibility default), making `.ascending` unreachable for `~Copyable` associated types. The "protocol extension" diagnostic was the constraint solver's confused response to no viable overload, not a regression in the solver itself.

**Fix** (3 commits):
1. comparison-primitives: `Comparison(comparing:to:)` → `T: Comparable & ~Copyable` + `borrowing` (6.4 variant via `#if compiler(>=6.4)`)
2. ordering-primitives: `extension where T: Comparable` → `& ~Copyable` (6.4 variant)
3. input-primitives: `starts(with element:)` → `borrowing` (SE-0499 `Equatable` no longer implies `Copyable`)

No workaround needed in collection-primitives — `.ascending` resolves correctly with the upstream fixes.

## What Worked and What Didn't

**What worked**: The issue-investigation skill's step 1 (verify on dev toolchain) correctly identified the 6.4-dev failure. The diagnostic name extraction (`-debug-diagnostic-names`) gave the exact diagnostic ID. The parallel agent search found the emitting source code and identified the commits that changed it.

**What didn't work**: Five reproducer variants all compiled clean because the bug was never in the compiler — it was in our code's assumptions about `Comparable` implying `Copyable`. Every reproducer faithfully modeled a constraint-solver bug that didn't exist. Three workaround attempts (`Ordering.Comparator<Base.Element>.ascending`, `.init(swift: ())`, inline closure) each hit "requires Copyable" errors that I attributed to secondary regressions rather than recognizing them as the primary signal.

**Confidence was low** on: why the reproducer wouldn't trigger. The cross-module theory and the associated-type-indirection theory were both reasonable but wrong. The actual discriminant (SE-0499 changing what `Comparable` implies) was invisible until externally supplied.

## Patterns and Root Causes

**The "cascade of workaround failures" pattern is diagnostic.** When three different workarounds all fail with the same class of error ("requires Copyable"), the common denominator is the real bug — not three separate regressions. I treated each failure as a new obstacle rather than recognizing the pattern: every path that touched `Swift.Comparable` hit `Copyable`. That's one bug, not three.

**SE-0499's backwards-compatibility mechanism creates a novel failure mode.** `T: Comparable` adds implicit `Copyable` in generic context, but `T: Comparable & ~Copyable` suppresses it. This means code that worked on 6.3 (where `Comparable` always implied `Copyable`) can break on 6.4 when the associated type's `~Copyable` declaration is no longer overridden by the `Comparable` constraint. The fix isn't a workaround — it's updating the generic constraint to reflect the new semantics.

**The issue-investigation skill's reproducer step has a blind spot for semantic changes.** The skill assumes bugs are in the compiler. When the bug is in the code's reliance on an implicit guarantee that a language evolution proposal removed, no standalone reproducer can trigger it — the implicit guarantee was correct at the time the code was written. The skill needs a step 0.5: "check if the failing code depends on a guarantee that a recent SE proposal changed."

## Action Items

- [ ] **[skill]** issue-investigation: Add SE-proposal check between Step 0 (classify) and Step 1 (dev toolchain). When a 6.N-dev failure doesn't reproduce standalone, check whether recent SE proposals changed protocol constraints (especially Copyable/Escapable implications) before pursuing compiler-source investigation.
- [ ] **[research]** SE-0499 ecosystem audit: grep `where.*Swift\.(Comparable|Equatable|Hashable)` across all three superrepos to find other extensions that need `& ~Copyable` for 6.4 compatibility. The comparison/ordering fixes are the template.
- [ ] **[package]** swift-buffer-primitives: The Async Channel build hits a pre-existing `DeinitDevirtualizer` ICE on `Buffer.Unbounded.swift:40`. This is a separate optimizer bug (pass #45472, SIL assertion on substitutions vs generic signature). Needs its own investigation handoff.
