# swift-pool-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming [API-NAME-*], implementation [IMPL-*], errors [API-ERR-001], code-organization [API-IMPL-005]
**Scope**: All `.swift` files under `Sources/`
**Status**: READ-ONLY audit -- findings only

---

## Summary Table

| ID | Severity | Rule | File | Description |
|----|----------|------|------|-------------|
| POOL-001 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.Try.swift | `TryAcquire` is a compound type name |
| POOL-002 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.Callback.swift | `CallbackAcquire` is a compound type name |
| POOL-003 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.Timeout.swift | `TimeoutAcquire` is a compound type name |
| POOL-004 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.swift | `AcquireAction` is a compound type name |
| POOL-005 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.swift | `ReleaseAction` is a compound type name |
| POOL-006 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.Try.swift | `TryAcquireAction` is a compound type name |
| POOL-007 | HIGH | [API-NAME-001] | Pool.Bounded.Acquire.Callback.swift | `CallbackAcquireAction` is a compound type name |
| POOL-008 | HIGH | [API-NAME-001] | Pool.Bounded.Fill.swift | `CommitAction` is a compound type name |
| POOL-009 | HIGH | [API-NAME-001] | Pool.Bounded.Shutdown.swift | `DrainAction` is a compound type name |
| POOL-010 | HIGH | [API-ERR-001] | Pool.Bounded.Creation.swift:13 | Untyped `async throws -> Resource` on `create` closure |
| POOL-011 | HIGH | [API-ERR-001] | Pool.Bounded.Creation.swift:20 | Untyped `async throws -> Resource` on `create` parameter |
| POOL-012 | HIGH | [API-ERR-001] | Pool.Bounded.swift:106 | Untyped `async throws -> Resource` on public `init` `create` parameter |
| POOL-013 | LOW | [API-IMPL-005] | Pool.Bounded.swift | Multiple type sections: `Bounded` class + metrics extension + effect execution + manual waiter pumping (acceptable -- extensions on same type) |
| POOL-014 | LOW | [API-IMPL-005] | Pool.Bounded.Acquire.swift | Contains both `AcquireAction` enum and `ReleaseAction` enum in addition to acquire logic (3 types in 1 file) |
| POOL-015 | LOW | [IMPL-INTENT] | Pool.Bounded.State.swift:66-67 | `__unchecked` constructor for `slotCapacity` -- mechanism at init site |
| POOL-016 | INFO | [IMPL-040] | Pool.Bounded.State.swift:70-71 | `try!` on `Slot.Index.Count` and `Array<Slot>.Fixed` -- capacity already validated by `Pool.Capacity`, so `try!` is acceptable but the force-try obscures the invariant chain |
| POOL-017 | INFO | [IMPL-040] | Pool.Bounded.swift:84,116 | `try!` on `Array<Entry>.Fixed` -- same pattern as POOL-016, capacity pre-validated |
| POOL-018 | INFO | [IMPL-040] | Pool.Bounded.State.swift:246 | `try!` on `available.push(index)` -- invariant-guaranteed but force-try hides the reasoning |

---

## Detailed Findings

### POOL-001 through POOL-003: Compound Public Type Names [API-NAME-001]

**Files**:
- `Pool.Bounded.Acquire.Try.swift:29` -- `TryAcquire`
- `Pool.Bounded.Acquire.Callback.swift:32` -- `CallbackAcquire`
- `Pool.Bounded.Acquire.Timeout.swift:93` -- `TimeoutAcquire`

**Current**:
```swift
public struct TryAcquire: Sendable { ... }
public struct CallbackAcquire: Sendable { ... }
public struct TimeoutAcquire: Sendable { ... }
```

**Expected** (Nest.Name pattern): These should be nested under `Acquire`:
```swift
// Inside Pool.Bounded.Acquire:
public struct Try: Sendable { ... }
public struct Callback: Sendable { ... }
public struct Timeout: Sendable { ... }
```

This would yield paths `Pool.Bounded.Acquire.Try`, `Pool.Bounded.Acquire.Callback`, `Pool.Bounded.Acquire.Timeout`, which read naturally ("a try operation within acquire within bounded pool").

**Note**: The accessor properties already use the correct nested naming pattern (`acquire.try`, `acquire.callback`, `acquire.timeout`). The type names are the only violation.

---

### POOL-004 through POOL-009: Compound Internal Enum Names [API-NAME-001]

**Files and lines**:
- `Pool.Bounded.Acquire.swift:117` -- `AcquireAction`
- `Pool.Bounded.Acquire.swift:307` -- `ReleaseAction`
- `Pool.Bounded.Acquire.Try.swift:61` -- `TryAcquireAction`
- `Pool.Bounded.Acquire.Callback.swift:70` -- `CallbackAcquireAction`
- `Pool.Bounded.Fill.swift:88` -- `CommitAction`
- `Pool.Bounded.Shutdown.swift:52` -- `DrainAction`

These are all `@usableFromInline` internal enums, not public API. Per [IMPL-024], compound names in the static/implementation layer are permitted. However, these are type names, not static method names. [API-NAME-001] applies to ALL types, not just public ones -- "All types MUST use the Nest.Name pattern."

**Mitigation**: [IMPL-024] explicitly exempts the "static (implementation) layer" for compound names, but speaks to methods. For internal enum types that serve as action discriminators, this is a grey area. These are never visible at consumer call sites.

**Recommendation**: Nest under their parent operation namespace:
- `Acquire.Action` instead of `AcquireAction`
- `Release.Action` instead of `ReleaseAction`
- `TryAcquire.Action` (or `Acquire.Try.Action`) instead of `TryAcquireAction`
- `CallbackAcquire.Action` (or `Acquire.Callback.Action`) instead of `CallbackAcquireAction`
- `Fill.Commit` or `Fill.Action.Commit` instead of `CommitAction`
- `Shutdown.Drain` or `Shutdown.Action.Drain` instead of `DrainAction`

---

### POOL-010 through POOL-012: Untyped Throws on Lazy Creation Closure [API-ERR-001]

**Files and lines**:
- `Pool.Bounded.Creation.swift:13` -- `let create: @Sendable () async throws -> Resource`
- `Pool.Bounded.Creation.swift:20` -- `create: @Sendable @escaping () async throws -> Resource`
- `Pool.Bounded.swift:106` -- `create: @Sendable @escaping () async throws -> Resource`

**Rule**: [API-ERR-001] "All throwing functions MUST use typed throws."

The `create` closure uses untyped `throws` in all three locations: the stored property, the `Creation.init` parameter, and the `Pool.Bounded.init` parameter.

**Challenge**: The `create` closure is user-supplied. The pool does not inspect the error -- it catches any failure and maps it to `Pool.Lifecycle.Error.creationFailed` (see `Pool.Bounded.Acquire.swift:213-222`). The thrown error is discarded:

```swift
do {
    resource = try await creator.value.create()
} catch {
    // Creation failed - release reservation, check shutdown
    ...
    throw .creationFailed
}
```

**Options**:
1. Make `create` generic over error type: `@Sendable () async throws(E) -> Resource` -- but `E` would need to be stored in `Creation`, making `Bounded` generic over `E` as well. This is a significant API surface change.
2. Accept the untyped throws as principled since the error is immediately erased to `.creationFailed`. Document the design choice per [PATTERN-016].
3. Use `any Error` explicitly to make the erasure visible in the signature.

**Recommendation**: Option 2 with a `// DESIGN: ...` comment explaining the intentional erasure. The pool's contract is that creation either succeeds or produces `.creationFailed` -- the user's error type is not part of the pool's error domain.

---

### POOL-014: Multiple Types in Pool.Bounded.Acquire.swift [API-IMPL-005]

**File**: `Pool.Bounded.Acquire.swift`

This file contains three distinct type declarations:
1. `AcquireAction` enum (line 117)
2. `ReleaseAction` enum (line 307)
3. Various method extensions on `Pool.Bounded`

Per [API-IMPL-005] "Each `.swift` file MUST contain exactly one type declaration." The `AcquireAction` and `ReleaseAction` enums should each be in their own file. `ReleaseAction` is especially misplaced -- it belongs with release logic, not acquire logic.

**Recommended file structure**:
- `Pool.Bounded.Acquire.Action.swift` -- `AcquireAction`
- `Pool.Bounded.Release.Action.swift` -- `ReleaseAction` (plus `releaseSlot` and `pumpWaiters`)

---

### POOL-015: `__unchecked` Constructor at Init Site [IMPL-INTENT]

**File**: `Pool.Bounded.State.swift:65-67`

```swift
let slotCapacity = Stack<Slot.Index>.Index.Count(
    __unchecked: (), Cardinal(UInt(capacity))
)
```

This is mechanism: raw value extraction through `UInt` and `Cardinal` to construct a count. The `capacity` is an `Int` that has already been validated by `Pool.Capacity`. A cleaner path would be a direct conversion from `Int` to `Stack.Index.Count` that preserves the validation invariant.

---

### POOL-016 through POOL-018: `try!` Usage [IMPL-040]

All five `try!` sites are guarded by upstream invariants:
- `Pool.Capacity` validates `value > 0` at construction
- `pushAvailable` is bounded by slot count equaling stack capacity

The `try!` is technically correct but hides the invariant chain. A `// INVARIANT:` comment at each site would make the reasoning explicit. These are INFO-level since the code is correct.

---

## Compliant Areas

The following areas are fully compliant with audited rules:

1. **Namespace structure**: `Pool`, `Pool.Bounded`, `Pool.Lifecycle`, `Pool.Bounded.State`, `Pool.Bounded.Slot`, `Pool.Bounded.Slot.State`, `Pool.Bounded.Effect`, `Pool.Bounded.Waiter`, `Pool.Bounded.Fill`, `Pool.Bounded.Shutdown`, `Pool.Bounded.Acquire` -- all use correct Nest.Name pattern.

2. **Typed throws**: All public throwing functions use `throws(Pool.Lifecycle.Error)`, `throws(Pool.Error)`, or `throws(Fill.Error)`. The only untyped throws are the user-supplied `create` closure (POOL-010/011/012).

3. **Nested accessors**: `pool.acquire.try { }`, `pool.acquire.callback { }`, `pool.acquire.timeout(.seconds(5)) { }`, `pool.fill(resource)`, `pool.shutdown()`, `pool.shutdown.wait()` -- all follow [API-NAME-002].

4. **callAsFunction pattern**: `Pool.Bounded`, `TryAcquire`, `CallbackAcquire`, `TimeoutAcquire`, `Fill`, `Shutdown` all use `callAsFunction` correctly per [IMPL-020].

5. **One type per file**: Most files comply. `Pool.swift`, `Pool.Lifecycle.swift`, `Pool.Bounded.Slot.swift`, `Pool.Bounded.Slot.State.swift`, `Pool.Bounded.Entry.swift`, etc. are all single-type files. Exception noted in POOL-014.

6. **No Foundation imports**: Verified across all source files.

7. **Error types**: `Pool.Error`, `Pool.Lifecycle.Error`, `Pool.Bounded.Fill.Error` are all properly nested enums with typed cases per [IMPL-041].

8. **Effect pattern**: The `Effect` enum with `perform(_:)` as the single resumption funnel is excellent implementation quality -- clean separation of lock-protected decisions from outside-lock execution.

9. **Two-phase commit**: All state mutations follow the strict stance (compute action under lock, execute outside lock). This is exemplary [IMPL-INTENT] compliance.

---

## Statistics

- **Files audited**: 33
- **Total findings**: 18
- **HIGH**: 12 (9 naming, 3 untyped throws)
- **LOW**: 3
- **INFO**: 3
