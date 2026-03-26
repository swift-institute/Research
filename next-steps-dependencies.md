# Next Steps: Dependencies Ecosystem Adoption

<!--
---
version: 1.0.0
last_updated: 2026-03-26
status: DECISION
source: adoption-implementation-review.md, dependencies-ecosystem-adoption-audit.md
---
-->

## Status After First Pass

**Done (12):** L1 ~Copyable relaxation, typed throws Result-wrapping, withDependencies single-stack unification, L1 values bridge, prepareDependencies typed throws, IO.Blocking.Lane key, IO.Lane key, IEEE 754 ExceptionState key, RFC 4122 Hash/Random keys, RFC 9562 Random convenience, RFC 6238 HMAC key + Foundation removal, Test.Expectation.Collector @TaskLocal → Dependency.Key.

**Reverted then re-applied (1):** Test.Expectation.Collector — initially reverted due to circular module dependency; re-applied after bridge extraction was completed separately.

**Remaining (0 MEDIUM, 9 LOW).**

## Task 1: Re-attempt Collector Migration (MEDIUM) ✅ DONE

The Collector Dependency.Key migration was reverted due to a circular dependency between `Testing` and `Tests Core` when the Apple Testing bridge was extracted simultaneously. The bridge extraction has since been completed separately in commits `4ded6c5` and `c92eb44`. The Collector migration should now succeed in isolation.

### Files to modify

1. **`/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Core/Test.Expectation.Collector.swift`** (line 33)
   - Current: `@TaskLocal public static var current: Collector?`
   - Change to: Add nested `enum Key: Dependency.Key` with `liveValue: nil`, `testValue: nil`
   - Change `current` to resolve from `Dependency.Scope.current[Key.self]`

2. **`/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Core/`** — all call sites using `$current.withValue(collector)` → `Dependency.Scope.with({ $0[Key.self] = collector })`

3. **`/Users/coen/Developer/swift-foundations/swift-testing/`** — update test call sites similarly

4. **`/Users/coen/Developer/swift-foundations/swift-tests/Package.swift`** — add `swift-dependency-primitives` dependency to `Tests Core` target if not already present

### Verification

```bash
cd /Users/coen/Developer/swift-foundations/swift-tests && swift build
cd /Users/coen/Developer/swift-foundations/swift-testing && swift build
```

### Pitfall to avoid

Do NOT simultaneously extract or reorganize the Apple Testing bridge module. That work is already done. This migration should be a pure @TaskLocal → Dependency.Key substitution.

## Task 2: Fix Research Document Contradiction ✅ DONE

The research document `dependencies-ecosystem-adoption-audit.md` contains an internal contradiction:

- **Category 1 (lines 59-63):** Correctly evaluates HTML rendering @TaskLocal usages and concludes "KEEP @TaskLocal — N/A" for both `HTML.Context.Configuration` and `HTML.Style.Context`.
- **Phase 1 (lines 172-184):** Incorrectly lists these same items as "HIGH Priority (Direct Replacement)".
- **Summary (line 163):** Reports "2 HIGH" citing these items.

### Fix

In `/Users/coen/Developer/swift-institute/Research/dependencies-ecosystem-adoption-audit.md`:

1. Remove Phase 1 entirely (lines 172-184) or replace with a note: "Category 1 analysis concluded these should KEEP @TaskLocal. No action."
2. Change Summary Statistics HIGH from `2` to `0`
3. Change total actionable from `18` to `16`
4. Update Outcome section accordingly

The Category 1 analysis is correct: HTML rendering @TaskLocal values are ambient rendering parameters, not injectable services. They have no test doubles, no mock implementations, and `$current.withValue` is the right API.

## Task 3: LOW Priority Items (Defer)

These 9 items are correctly identified as LOW priority and should remain deferred. Listed for completeness:

| Item | Package | Reason to Defer |
|------|---------|----------------|
| IO.Executor | swift-io | Internal singleton, marginal testability gain |
| IO.Event.Selector | swift-io | Async failable init, needs `prepareDependencies` pattern |
| IO.Completion.Queue | swift-io | Async failable init, platform-conditional |
| IO.Event.Registry | swift-io | Internal, not user-facing |
| Test.Exclusion.Controller | swift-tests | Test-only infra, marginal benefit |
| Test.Snapshot.Inline.Configuration | swift-tests | Test-only infra |
| Testing.Configuration | swift-testing | Already testable via Environment.withOverlay |
| Tests.Baseline.Recording | swift-tests | Already testable via Environment.withOverlay |
| Tests.Baseline.Storage | swift-tests | Already testable via Environment.withOverlay |

No action needed unless IO singleton testability becomes a design priority (separate design document).
