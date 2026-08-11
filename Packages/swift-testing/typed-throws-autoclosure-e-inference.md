# Typed Throws Autoclosure E Inference

<!--
---
version: 1.0.0
last_updated: 2026-02-28
status: DECISION
---
-->

## Context

The `assertSnapshot` API in swift-tests uses the signature:

```swift
func assertSnapshot<Value: Sendable, Format: Sendable, E: Swift.Error>(
    of value: @autoclosure () throws(E) -> Value,
    as strategy: Test.Snapshot.Strategy<Value, Format>,
    ...
) -> Test.Expectation
```

When `__expectSnapshot` in swift-testing calls `assertSnapshot(of: value, ...)` where `value` is a plain `Value` (non-throwing expression), the compiler fails with:

> generic parameter 'E' could not be inferred

This blocks the entire swift-testing build.

## Question

Can Swift 6.2 infer `E = Never` (or any concrete error type) when passing expressions to `@autoclosure () throws(E) -> Value` where `E: Error`? What is the root cause, and what is the correct fix that maintains 100% typed throws per [API-ERR-001]?

## Analysis

### Prior Art

**SE-0413** (Typed Throws) originally included closure thrown type inference behind the `FullTypedThrows` feature flag. This inference was **not implemented** in Swift 6.0 and was moved to "Future Directions":

> "These type inference changes did not get implemented in Swift 6.0, and have therefore been removed from this proposal and placed into 'Future Directions' so they can be revisited once implemented."
> — SE-0413, as amended

**swiftlang/swift#75430** — Open bug filed 2024-07-23, titled "Type inference breaking with generic typed throws and autoclosures". Labels: `bug`, `type checker`, `type inference`, `typed throws`. Status: **OPEN** as of 2026-02-28. Multiple community members report the same issue across Swift 6.0 through 6.2.

Key comment from **@xwu** (Swift collaborator, 2025-08-19):

> "full typed throws" was proposed and accepted in SE-0413 but could not be implemented in time for Swift 6. As a result, it was subject to our "shrink-to-fit" policy and became a future direction which will need re-review if/when it can be implemented.

Key comment from **@tbkka** (Apple contributor, 2025-08-18):

> Full inference of typed throws for closures is not yet implemented. It's listed as a "Future Direction" in SE-0413.

### Root Cause: Five-Part Compiler Failure

Investigation of the Swift compiler source at `/Users/coen/Developer/swiftlang/swift/` reveals five interconnected causes:

#### 1. `FullTypedThrows` is experimental-only

**File**: `include/swift/Basic/Features.def:342`
```cpp
EXPERIMENTAL_FEATURE(FullTypedThrows, false)
```

The feature flag that gates thrown error type inference is disabled by default and only available in asserts builds. Without it, the constraint solver does not infer thrown error types from throw sites.

#### 2. Autoclosure coerces result type only, not thrown error type

**File**: `lib/Sema/CSApply.cpp:6419-6448`
```cpp
if (argRequiresAutoClosureExpr(param, argType)) {
    auto *closureType = param.getPlainType()->castTo<FunctionType>();
    // Only coerces to closureType->getResult() — the return type
    argExpr = coerceToType(
        argExpr, closureType->getResult(),
        argLoc.withPathElement(ConstraintLocator::AutoclosureResult));
    convertedArg = cs.buildAutoClosureExpr(argExpr, closureType, dc);
}
```

The autoclosure argument is coerced to `closureType->getResult()` (the `Value` type) only. The thrown error type `E` in `() throws(E) -> Value` is **never examined** during argument matching. No constraint is generated to bind `E`.

#### 3. Closure thrown type propagation skips type variables

**File**: `lib/Sema/CSSimplify.cpp:12458-12473` (added by PR #87360, 2026-02-13)
```cpp
if (inferredThrownErrorType->isErrorExistentialType()) {
    auto errorTy = contextualFnType->getEffectiveThrownErrorTypeOrNever();
    // Don't propagate if the contextual error type:
    //   - requires inference;        ← THIS BLOCKS OUR CASE
    //   - is `Never` ...
    //   - is `any Error` ...
    if (!(errorTy->hasTypeVariable() || errorTy->isNever() ||
          errorTy->isErrorExistentialType()))
        closureExtInfo = closureExtInfo.withThrows(/*throws=*/true, errorTy);
}
```

The recent fix (PR #87360 by Pavel Yaskevich) propagates typed throws from contextual type into closures — but **only when the error type is fully resolved**. When `E` is still a type variable (our case), propagation is skipped.

#### 4. `getCaughtErrorType` acknowledges the gap

**File**: `lib/Sema/ConstraintSystem.cpp:505-511`
```cpp
// Retrieve the thrown error type of a closure.
// FIXME: This will need to change when we do inference of thrown error
// types in closures.
if (auto closure = catchNode.dyn_cast<ClosureExpr *>()) {
    auto closureTy = simplifyType(getType(closure))->castTo<FunctionType>();
    return closureTy->getEffectiveThrownErrorTypeOrNever();
}
```

The FIXME explicitly acknowledges that closure thrown error type inference is incomplete.

#### 5. `matchFunctionThrowing` handles type variables correctly — but never reaches them

**File**: `lib/Sema/CSSimplify.cpp:2870-2946`

The `matchFunctionThrowing` function does handle the `Dependent` case where type variables exist — it generates a constraint `matchTypes(thrownError1, thrownError2, ...)`. However, for autoclosures, this matching never occurs because the autoclosure is built after argument coercion (cause #2), and the constraint solver never generates the function type match that would trigger `matchFunctionThrowing`.

### Experimental Verification

**Experiment**: `Experiments/typed-throws-autoclosure-inference/`

| Variant | Signature | Result |
|---------|-----------|--------|
| Non-throwing expression (`42`) | `@autoclosure () throws(E) -> Value` | FAILS — E cannot be inferred |
| Typed-throwing expression (`try mayThrow()`) | `@autoclosure () throws(E) -> Value` | FAILS — E cannot be inferred |
| Plain `Value` parameter | `capturing value: Value` | CONFIRMED — works |
| Bridge through generics | `_ value: Value` → `capturing value: Value` | CONFIRMED — works |
| Caller-site typed throws | `throws(TestError)` caller uses `try` | CONFIRMED — typed throws preserved |

The E inference failure is **total**: it fails not just for `E = Never` but for any E, including when the expression explicitly throws a typed error.

### Options

#### Option A: Add non-throwing overloads

Add `@autoclosure () -> Value` overloads alongside `@autoclosure () throws(E) -> Value`.

- **Violates**: [API-ERR-001] — introduces API surface without typed throws
- **Doubles**: every function signature (sync + async × throwing + non-throwing = 8 functions)
- **Rejected** by user constraint

#### Option B: Use untyped `throws`

Replace `throws(E)` with untyped `throws`.

- **Violates**: [API-ERR-001] — `throws` erases to existential `any Error`
- **Rejected** by user constraint

#### Option C: Remove `@autoclosure`, use `capturing:` label

Replace `@autoclosure () throws(E) -> Value` with plain `Value` parameter using `capturing:` label. The value is evaluated eagerly at the call site.

- **Preserves**: 100% typed throws — caller's `try` site propagates typed error
- **Semantics**: Eager evaluation (acceptable for snapshot testing — no lazy evaluation needed)
- **API clarity**: `capturing:` label communicates intent
- **Future-proof**: When Swift implements `FullTypedThrows`, the `@autoclosure` version can be reinstated alongside
- **No duplication**: Single set of functions

#### Option D: Wait for `FullTypedThrows`

Do nothing, wait for the Swift team to implement full typed throws inference.

- **Status**: `FullTypedThrows` is an experimental feature, not scheduled for any Swift release
- **Impact**: swift-testing cannot build until resolved
- **Rejected** — blocks all development

### Comparison

| Criterion | A: Non-throwing overloads | B: Untyped throws | C: `capturing:` | D: Wait |
|-----------|--------------------------|-------------------|-----------------|---------|
| [API-ERR-001] compliance | NO | NO | YES | N/A |
| Typed throws preserved | Partial | NO | YES (at call site) | N/A |
| API surface growth | 2x | None | None | None |
| Blocks development | No | No | No | YES |
| Reversible | Yes | Yes | Yes | N/A |
| Future-compatible | Yes | Yes | Yes | N/A |

## Outcome

**Status**: DECISION

**Choice**: Option C — Replace `@autoclosure () throws(E) -> Value` with plain `Value` parameter using `capturing:` label.

**Rationale**:

1. **100% typed throws**: The only option that fully complies with [API-ERR-001]. Typed errors propagate through the caller's `try` site without erasure.

2. **Eager evaluation is correct for snapshot testing**: The `assertSnapshot` function does not need lazy evaluation semantics. The value expression is always evaluated exactly once, immediately. The `@autoclosure` was a stylistic choice (matching Apple's `#expect` pattern), not a semantic requirement.

3. **The bug is acknowledged but unscheduled**: The Swift compiler team (via @xwu, @tbkka) confirms this is a known gap in SE-0413 implementation. `FullTypedThrows` is experimental-only with no release timeline.

4. **Reversible**: When `FullTypedThrows` ships, the `@autoclosure` signature can be reinstated.

**Implementation**:

In swift-tests (`Test.Snapshot.assert.swift`):
```swift
// New entry point — bypasses E inference entirely
@discardableResult
public func assertSnapshot<Value: Sendable, Format: Sendable>(
    capturing value: Value,
    as strategy: Test.Snapshot.Strategy<Value, Format>,
    ...
) -> Test.Expectation

// Keep existing @autoclosure versions for future use when FullTypedThrows ships
```

In swift-testing (`ExpectSnapshot.swift`):
```swift
// __expectSnapshot calls capturing: instead of of:
public func __expectSnapshot<Value: Sendable, Format: Sendable>(
    _ value: Value,
    ...
) -> Test.Expectation {
    assertSnapshot(capturing: value, as: strategy, ...)
}
```

## References

- [SE-0413: Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) — Section "Closure thrown type inference" (Future Direction)
- [swiftlang/swift#75430](https://github.com/swiftlang/swift/issues/75430) — "Type inference breaking with generic typed throws and autoclosures" (OPEN)
- [PR #87360](https://github.com/swiftlang/swift/pull/87360) — Partial fix: propagates typed throws into closures (not autoclosures, not type variables)
- `include/swift/Basic/Features.def:342` — `FullTypedThrows` experimental feature flag
- `lib/Sema/CSApply.cpp:6419-6448` — Autoclosure coercion to result type only
- `lib/Sema/CSSimplify.cpp:12458-12473` — Closure thrown type propagation (skips type variables)
- `lib/Sema/ConstraintSystem.cpp:505-511` — FIXME acknowledging incomplete closure error inference
- Experiment: `Experiments/typed-throws-autoclosure-inference/`
