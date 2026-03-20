# swift-cache-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Skills**: implementation, naming, errors
**Scope**: All 6 source files in `Sources/Cache Primitives/`

---

## Summary

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| CACHE-001 | **CRITICAL** | [API-ERR-001] | Cache.swift | 153-154 | `value(for:compute:)` uses untyped `async throws` |
| CACHE-002 | **CRITICAL** | [API-ERR-001] | Cache.swift | 210 | `waitForValue(entry:)` uses untyped `async throws` |
| CACHE-003 | **CRITICAL** | [API-ERR-001] | Cache.swift | 279-280 | `computeAndPublish(key:entry:compute:)` uses untyped `async throws` |
| CACHE-004 | **CRITICAL** | [API-ERR-001] | Cache.swift | 493-494 | `value(for:if:compute:)` uses untyped `async throws` |
| CACHE-005 | **CRITICAL** | [API-ERR-001] | Cache.swift | 153, 279, 493 | Compute closure parameter uses untyped `throws` |
| CACHE-006 | **HIGH** | [API-IMPL-005] | Cache.swift | 55, 75, 96, 112 | 4 type declarations in one file (Cache, Storage, State, Action) |
| CACHE-007 | **HIGH** | [API-IMPL-005] | Cache.Entry.swift | 20, 69, 95 | 3 type declarations in one file (Entry, State, Waiters) |
| CACHE-008 | **HIGH** | [API-NAME-001] | Cache.Evict.swift | 37 | `__CacheEvict` is a compound name with underscore prefix |
| CACHE-009 | **HIGH** | [API-NAME-001] | Cache.Compute.swift | 66 | `__CacheCompute` is a compound name with underscore prefix |
| CACHE-010 | **MEDIUM** | [API-NAME-002] | Cache.swift | 341 | `cachedValue(for:)` is a compound method name |
| CACHE-011 | **MEDIUM** | [API-NAME-002] | Cache.swift | 394 | `setValue(_:for:)` is a compound method name |
| CACHE-012 | **MEDIUM** | [API-NAME-002] | Cache.swift | 423 | `removeValue(for:)` is a compound method name |
| CACHE-013 | **MEDIUM** | [API-NAME-002] | Cache.swift | 456 | `removeAll()` is a compound method name |
| CACHE-014 | **MEDIUM** | [API-NAME-002] | Cache.swift | 276 | `computeAndPublish(...)` internal compound method name |
| CACHE-015 | **MEDIUM** | [API-NAME-002] | Cache.swift | 210 | `waitForValue(...)` internal compound method name |
| CACHE-016 | **LOW** | [IMPL-INTENT] | Cache.swift | 114 | `any Swift.Error` in Action enum's `.throwError` case |
| CACHE-017 | **LOW** | [IMPL-INTENT] | Cache.Entry.swift | 84 | `any Error` in Entry.State `.failed` case |
| CACHE-018 | **LOW** | [PATTERN-016] | Cache.Evict.swift | 19, 37 | Hoisted type lacks WORKAROUND comment per [PATTERN-016] |
| CACHE-019 | **LOW** | [PATTERN-016] | Cache.Compute.swift | 17, 66 | Hoisted type lacks WORKAROUND comment per [PATTERN-016] |

**Totals**: 5 CRITICAL, 4 HIGH, 6 MEDIUM, 4 LOW

---

## Detailed Findings

### CACHE-001 through CACHE-005: Untyped Throws [API-ERR-001] — CRITICAL

**Location**: `Cache.swift` lines 151-154, 210, 276-280, 490-494

All 7 untyped `throws` in the ecosystem originate here. There are two distinct categories:

#### (A) Method signatures (CACHE-001 through CACHE-004)

```swift
// Line 154
) async throws -> Value {

// Line 210
func waitForValue(entry: Entry) async throws -> Value {

// Line 280
) async throws -> Value {

// Line 494
) async throws -> Value? {
```

All four should be `throws(Cache.Error)`. The methods already only throw `Error.computeFailed(...)` and `Error.cancelled`, which are `Cache.Error` cases. The typed throw is a mechanical change.

#### (B) Compute closure parameter (CACHE-005)

```swift
// Lines 153, 279, 493
compute: @Sendable () async throws -> Value
```

The compute closure is user-provided and can throw arbitrary errors. There are two remediation paths:

1. **Keep `any Error` wrapped**: The closure stays `async throws` (or becomes `async throws(any Error)`), and `computeAndPublish` wraps the arbitrary error into `Cache.Error.computeFailed(error)` as it already does. The outer methods then throw `Cache.Error` only. This is the path of least resistance — the wrapping already exists at lines 282-288 and 325.

2. **Generic error parameter**: `func value<E: Error>(for:compute: () async throws(E) -> Value) async throws(CompositeError<E>) -> Value`. This preserves the caller's error type but adds complexity and a new error type.

**Recommendation**: Path 1 — the wrapping into `Cache.Error.computeFailed` is already done. The only change needed is adding `throws(Cache.Error)` to the four method signatures. The closure parameter can remain `throws` (untyped) because it is an *input* whose error is caught and wrapped, not propagated.

**However**, `waitForValue` at line 245 also does `continuation.resume(throwing: Error.cancelled)` through a `CheckedContinuation<Entry.Waiters.Outcome, any Error>` — the continuation itself uses untyped throws. This is a deeper issue: `withCheckedThrowingContinuation` is stdlib and uses untyped throws. The workaround is to never throw through the continuation directly — always resume with a `Result` value (which `waitForValue` partially does already). Lines 213-252 mix `resume(returning: .success(...))` with `resume(throwing: ...)`, which leaks untyped errors. Unifying to always resume with `.failure(...)` wrapped in the `Outcome` type would allow the continuation to be non-throwing.

---

### CACHE-006: Multiple Types in Cache.swift [API-IMPL-005] — HIGH

**Location**: `Cache.swift` lines 55, 75, 96, 112

Four distinct type declarations in one file:
- `Cache` (line 55) — the main public struct
- `Cache.Storage` (line 75) — internal reference wrapper
- `Cache.State` (line 96) — internal synchronized state
- `Cache.Action` (line 112) — internal action enum

Per [API-IMPL-005], each should be in its own file:
- `Cache.swift` — `Cache` only
- `Cache.Storage.swift` — `Cache.Storage`
- `Cache.State.swift` — `Cache.State`
- `Cache.Action.swift` — `Cache.Action`

---

### CACHE-007: Multiple Types in Cache.Entry.swift [API-IMPL-005] — HIGH

**Location**: `Cache.Entry.swift` lines 20, 69, 95

Three type declarations:
- `Cache.Entry` (line 20)
- `Cache.Entry.State` (line 69)
- `Cache.Entry.Waiters` (line 95)

Each should be in its own file:
- `Cache.Entry.swift` — `Cache.Entry` only
- `Cache.Entry.State.swift` — `Cache.Entry.State`
- `Cache.Entry.Waiters.swift` — `Cache.Entry.Waiters`

---

### CACHE-008, CACHE-009: Compound Hoisted Names [API-NAME-001] — HIGH

**Location**: `Cache.Evict.swift` line 37, `Cache.Compute.swift` line 66

```swift
public struct __CacheEvict<Key: Hashable & Sendable, V: Sendable>
public struct __CacheCompute<Key: Hashable & Sendable, Value: Sendable, E: Swift.Error & Sendable>
```

`__CacheEvict` and `__CacheCompute` are compound names violating [API-NAME-001]. The comment says "hoisted to module level due to Swift generic limitations." If hoisting is genuinely required (generic constraints on nested types within a generic type), these are conscious technical debt per [PATTERN-016] and should be documented with the required WORKAROUND/WHY/WHEN TO REMOVE/TRACKING block.

The names should also avoid the double-underscore prefix convention, which is reserved by Swift/C for implementation internals and can conflict with future compiler-generated symbols.

---

### CACHE-010 through CACHE-015: Compound Method Names [API-NAME-002] — MEDIUM

**Public API** (CACHE-010 through CACHE-013):

| Current | Nested accessor alternative |
|---------|----------------------------|
| `cachedValue(for:)` | `cache.value.cached(for:)` or subscript |
| `setValue(_:for:)` | `cache.value.set(_:for:)` or `cache.set.value(_:for:)` |
| `removeValue(for:)` | `cache.remove.value(for:)` |
| `removeAll()` | `cache.remove.all()` |

Note: `cachedValue`, `setValue`, `removeValue`, `removeAll` are all compound identifiers. The Property.View pattern would namespace these under `.value`, `.remove`, etc.

**Internal API** (CACHE-014, CACHE-015):

| Current | Note |
|---------|------|
| `computeAndPublish(...)` | Internal method — per [IMPL-024], compound names are acceptable in the static/implementation layer. However, this is an instance method, not a static. If refactored to a static, the compound name is acceptable. |
| `waitForValue(...)` | Same as above — compound instance method. |

These are less urgent because they are `@usableFromInline` internal, not public API. Per [IMPL-024], if moved to statics, compound names are explicitly permitted.

---

### CACHE-016, CACHE-017: `any Error` in State Enums — LOW

**Location**: `Cache.swift` line 114 (`Action.throwError(any Swift.Error)`), `Cache.Entry.swift` line 84 (`.failed(any Error)`)

Both state enums store `any Error` as associated values. This is necessary because the compute closure's error type is erased. Once the compute closure is typed (or the wrapping strategy from CACHE-001 is adopted), these could potentially become `Cache.Error` instead of `any Error`, improving type safety of the internal state machine.

This is a consequence of the untyped throws in CACHE-001/CACHE-005 — fixing those may cascade to fixing these.

---

### CACHE-018, CACHE-019: Missing WORKAROUND Documentation [PATTERN-016] — LOW

**Location**: `Cache.Evict.swift` lines 19, 37; `Cache.Compute.swift` lines 17, 66

Both files have a `- Note:` comment explaining the hoisting but lack the required [PATTERN-016] WORKAROUND block:

```swift
// WORKAROUND: Type hoisted to module level because Swift does not support
//   generic nested types with independent generic parameters inside generic types.
// WHY: Cache.Evict needs <Key, Value> from Cache plus its own constraints,
//   which Swift cannot express as a nested type.
// WHEN TO REMOVE: When Swift supports nested types with independent generic parameters.
// TRACKING: Swift evolution / compiler limitation — no specific issue.
```

---

## Non-Findings (Verified Compliant)

| Rule | Status | Notes |
|------|--------|-------|
| [API-NAME-001] `Cache`, `Cache.Entry`, `Cache.Error` | PASS | Proper Nest.Name pattern |
| [API-NAME-001] `Cache.Evict.Reason` | PASS | Proper nesting |
| [PRIM-FOUND-001] No Foundation | PASS | No Foundation imports |
| [IMPL-020] Property.View | N/A | Cache is Copyable + reference-semantics; Property.View not required |
| [IMPL-002] Typed arithmetic | N/A | No arithmetic operations in this package |
| [IMPL-010] Int(bitPattern:) | PASS | No Int conversions |
| [IMPL-040] Throws vs preconditions | PASS | No preconditions used; all failures are throws |
| [API-ERR-002] `Cache.Error` nesting | PASS | Error is properly nested under Cache |
| [API-ERR-003] Error cases | PASS | `computeFailed`, `cancelled` describe failures |
| `Cache.Storage.withLock` | PASS | Uses `throws(E)` — already typed |

---

## Remediation Priority

1. **CACHE-001 through CACHE-005** — Add `throws(Cache.Error)` to 4 method signatures. Unify `waitForValue` continuation to always resume with `Result` values, eliminating the untyped `resume(throwing:)` path. This resolves all 7 untyped throws.
2. **CACHE-006, CACHE-007** — Split into one-type-per-file. Mechanical refactor.
3. **CACHE-008, CACHE-009** — Add [PATTERN-016] documentation block to hoisted types.
4. **CACHE-010 through CACHE-013** — Consider Property.View nested accessor pattern for public API. Lower priority as this is a design-level change.
