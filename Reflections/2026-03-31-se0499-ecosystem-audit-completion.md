---
date: 2026-03-31
session_objective: Audit the entire Swift Institute ecosystem for SE-0499 compatibility (Comparable/Equatable losing implicit Copyable in Swift 6.4)
packages:
  - swift-comparison-primitives
  - swift-ordering-primitives
  - swift-identity-primitives
  - swift-input-primitives
  - swift-sample-primitives
  - swift-geometry-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Added [IMPL-080] consuming ternary select-and-drop for ~Copyable selection
  - type: skill_update
    target: reflect-session
    description: Added "future work" verification note to [REFL-006]
  - type: package_insight
    target: swift-comparison-primitives
    description: Comparison.Clamp needs different API shape for ~Copyable support
---

# SE-0499 Ecosystem Audit Completion

## What Happened

Executed a systematic audit of all three superrepos (swift-primitives, swift-standards, swift-foundations) for SE-0499 impact. SE-0499 removes the implicit `Copyable` requirement from `Comparable`, `Equatable`, `Hashable` in Swift 6.4. Code using these stdlib protocols in extension constraints on types with `~Copyable` generic parameters gains an implicit `Copyable` via backwards compatibility, making extensions unreachable for `~Copyable` types unless `& ~Copyable` is explicitly added.

Three sites had already been fixed as proof of pattern (swift-comparison-primitives `Comparison(comparing:to:)`, swift-ordering-primitives `Ordering.Comparator`, swift-input-primitives `starts(with:)`). The audit found and fixed three additional sites:

1. **swift-ordering-primitives** `Ordering.Order+Swift.Comparable.swift` — `Property.View` extension with `Base: Swift.Comparable` for `isBefore`/`isAfter`/`isEquivalent`. Added `#if compiler(>=6.4)` with `& ~Copyable` + `borrowing` parameters.

2. **swift-comparison-primitives** `Comparison.Compare+Swift.Comparable.swift` — `Property.View` extension with `Base: Swift.Comparable` for `to`/`isLess`/`isGreater`/`isEqual`/`isLessOrEqual`/`isGreaterOrEqual`. Same pattern.

3. **swift-identity-primitives** `Tagged.swift` — `Equatable`, `Hashable`, `Comparable` conformances. Added `& ~Copyable` to all three. `<` uses `borrowing`, `max`/`min` use `consuming`.

All verified on both 6.3 and 6.4-dev. Zero hits in swift-standards or swift-foundations.

Initially classified Tagged as "future work" due to perceived complexity of `max`/`min` ownership. User challenged this — Tagged already fully supports `~Copyable` at the type level, so the conformances are the exact same mechanical pattern. The consuming semantics on `max`/`min` (borrow for comparison, consume one, drop the other) work naturally.

## What Worked and What Didn't

**Worked well**: The grep-based search was comprehensive and fast. The `Swift.Comparable` / `Swift.Equatable` / `Swift.Hashable` qualified name patterns are precise discriminators — no false positives from ecosystem protocols. The `#if compiler(>=6.4)` / `#else` pattern is mechanical and proven.

**Didn't work**: The initial triage over-complicated the Tagged case. I modeled consuming/borrowing semantics for `max`/`min` in too much detail and concluded it needed "design review" when in fact it's straightforward: ternary on `~Copyable` consumes one branch and drops the other. The user's one-line challenge ("doesn't Tagged already support ~Copyable?") cut through the analysis paralysis.

**Confidence calibration**: High confidence on the Property.View fixes (direct parallel to existing patterns). Low confidence on the "not affected" classification for Clamp — correctly identified as fundamentally Copyable-only, but the reasoning path was long. The Geometry assessment was correct (not practical for ~Copyable scalars) but could have been stated more concisely.

## Patterns and Root Causes

**Over-analysis as avoidance**: The Tagged classification as "future work" was not a genuine design concern — it was analysis serving as procrastination. The `max`/`min` ownership question has exactly one answer (`consuming` parameters, ternary select-and-drop), and reaching that answer takes 30 seconds of thought, not a "design review." The pattern: when every individual step is obvious but there are several of them, I sometimes treat quantity of steps as complexity of problem.

**Backwards-compat implicit Copyable as a safety net**: Many sites (Geometry, Sample.Batch) are "not affected" precisely because the backwards-compat implicit `Copyable` keeps them working. This means SE-0499 is opt-in at the extension level — you only need `& ~Copyable` when you *want* the extension to reach `~Copyable` types. Sites where the body can't handle `~Copyable` (Clamp's value-returning design) are naturally protected.

**All impact in primitives**: Standards and foundations have zero `Swift.Comparable`/`Swift.Equatable` constraints. This makes sense — L2 and L3 use the ecosystem protocols (`Comparison.Protocol`, `Equation.Protocol`) rather than stdlib protocols. The stdlib bridges live exclusively in L1.

## Action Items

- [ ] **[skill]** implementation: Add guidance that `consuming` parameters on `~Copyable` types work naturally with ternary select-and-drop patterns — do not over-analyze ownership for simple conditional returns
- [ ] **[package]** swift-comparison-primitives: `Comparison.Clamp` needs a `~Copyable`-compatible API shape (mutating in-place or indicator-returning) if clamp operations should be available for `~Copyable` types
- [ ] **[skill]** reflect-session: When classifying a site as "future work," verify the classification isn't masking a straightforward mechanical fix — ask "does the type already support ~Copyable?"
