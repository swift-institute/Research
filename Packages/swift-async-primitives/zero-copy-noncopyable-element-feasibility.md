# Zero-Copy and ~Copyable Element Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-03-27
status: RECOMMENDATION
tier: 2
---
-->

## Context

The zero-copy pipeline audit (`Research/audit.md`, section "Zero-Copy Pipeline — 2026-03-27") identified that `~Copyable` Element support is blocked and classified the blockers as "5 independent constraints." This research re-examines each blocker against the current Swift compiler and stdlib to determine which are genuine constraints and which are already resolved.

Prompted by: zero-copy audit findings #8 (Sendable constraint) and ~Copyable Element Feasibility section.

## Question

How many of the 5 identified blockers for `~Copyable` channel elements are genuine, and what is the path to supporting `~Copyable` element transfer through async channels?

## Analysis

### Blocker Reassessment

The audit listed these 5 blockers:

| # | Claimed Blocker | Status After Research | Evidence |
|---|----------------|----------------------|----------|
| 1 | `Async.Channel<Element: Sendable>` — Sendable implies Copyable | **FALSE** | `Sendable` does NOT imply `Copyable`. Types can be `~Copyable & Sendable` (e.g., `Async.Waiter.Resumption: ~Copyable, Sendable`, `Job: Sendable, ~Copyable` in stdlib). The constraint is removable. |
| 2 | `Async.Continuation<T: Sendable>` — Sendable on T | **FALSE** | Same reasoning. `T: Sendable` does not block `~Copyable`. The continuation wrapper's generic constraint is under our control. |
| 3 | `UnsafeContinuation<T>` / `CheckedContinuation<T>` — stdlib requires T: Sendable | **PARTIALLY FALSE** | The stdlib does NOT have explicit `T: Sendable`. It has **implicit `T: Copyable`** (from not writing `~Copyable`). `Sendable` is not the issue — `Copyable` is. And this IS a genuine stdlib blocker. |
| 4 | `Optional` wrapping in receiver result | **FALSE** | `Optional<Wrapped: ~Copyable & ~Escapable>` is fully supported in stdlib (`Optional.swift:121`). Conditional `Copyable` conformance when `Wrapped: Copyable`. |
| 5 | Enum associated values require Copyable | **FALSE** | Fully supported. `Optional` and `Result` both use `~Copyable` associated values in stdlib. `~Copyable` enums support associated values (no `indirect`, no `@objc`, no raw types). |

**Genuine blocker count: 1** (not 5). Only the implicit `Copyable` constraint on stdlib continuation generics (`UnsafeContinuation<T>`, `CheckedContinuation<T>`, and `with*Continuation` free functions) prevents `~Copyable` element support.

### Option A: Wait for stdlib evolution

The stdlib continuation types currently declare:

```swift
// stdlib/public/Concurrency/PartialAsyncTask.swift:694
public struct UnsafeContinuation<T, E: Error>: Sendable { ... }

// T has implicit Copyable — no ~Copyable suppression
```

A test file at `test/ModuleInterface/Inputs/NoncopyableGenerics_Misc.swift:142` proves the compiler can handle a `~Copyable` continuation:

```swift
public struct Continuation<T: ~Copyable, E: Error> {
    public func resume(returning value: consuming T) where E == Never {}
}
```

This test (for `rdar://130179698`) validates that `~Copyable` generic parameters on continuation-like types compile and serialize correctly through `.swiftinterface` files.

**Pros**: Zero risk. When the stdlib evolves, our types automatically gain ~Copyable support if we've prepared the internal constraints.
**Cons**: No timeline. No visible Swift Evolution proposal or TODO in the codebase.

### Option B: Prepare internal constraints now, wait for stdlib

Make all package-internal types ~Copyable-ready so that when the stdlib constraint is relaxed, only the top-level `Element` constraint and the `withUnsafeContinuation` call sites need updating.

Changes:
1. All Action enum types: already work with ~Copyable associated values
2. `Deque<Element: ~Copyable>`: already supported by queue-primitives
3. `Receive.Outcome` enum: already works (just added in this audit cycle)
4. `Async.Continuation<T>` wrapper: change `T: Sendable` to `T: ~Copyable & Sendable` (or `~Copyable` with conditional `Sendable`)
5. State machine types: add `where Element: ~Copyable` to extensions
6. Add `consuming` annotations throughout the element pipeline (partially done in this audit)

The last mile — changing `Async.Channel<Element: Sendable>` to `Async.Channel<Element: ~Copyable & Sendable>` and the continuation call sites — would require stdlib evolution.

**Pros**: Maximizes readiness. When stdlib evolves, the change is a 2-line diff.
**Cons**: Requires careful constraint propagation work now. Some `consuming` annotations may interact with existing callers.

### Option C: Bypass stdlib continuations with custom implementation

Build a custom `~Copyable`-aware continuation wrapper that uses unsafe primitives to transfer ownership without going through `CheckedContinuation`/`UnsafeContinuation`.

The runtime mechanism is `swift_task_continuation_init` and `swift_continuation_resume` which operate on raw pointers. A custom wrapper could:
1. Accept a `consuming T: ~Copyable` value
2. Store it in a `Reference.Slot<T>` or `UnsafeMutablePointer<T>`
3. Signal the task runtime to resume
4. Have the resumed task extract the value from the slot

**Pros**: Achieves ~Copyable element support today.
**Cons**: Very high risk. Depends on non-public runtime internals. May break across Swift versions. Correctness is extremely hard to verify. The `UnsafeContinuation` type is special-cased by the compiler for coroutine lowering — a custom type would not receive the same compiler support.

### Option D: Submit Swift Evolution pitch

Pitch relaxing the continuation generic constraints:

```swift
// Proposed change
public struct UnsafeContinuation<T: ~Copyable, E: Error>: Sendable { ... }
public struct CheckedContinuation<T: ~Copyable, E: Error>: Sendable { ... }

// resume(returning:) would need consuming for ~Copyable T:
public func resume(returning value: consuming sending T) { ... }

// with*Continuation return type:
public func withUnsafeContinuation<T: ~Copyable>(...) async -> sending T { ... }
```

The compiler infrastructure already supports this (proven by the test case). The work is:
1. Update the generic parameter declarations
2. Add `consuming` to `resume(returning:)` for the `~Copyable` path
3. Update `with*Continuation` free function signatures
4. Ensure ABI stability (may require `@_alwaysEmitIntoClient` shims)

**Pros**: The principled path. Benefits the entire Swift ecosystem, not just our channels.
**Cons**: Requires engaging with Swift Evolution process. Timeline uncertain.

### resume(returning:) Convention

The stdlib uses `sending` (not `consuming`) on `resume(returning:)`:

```swift
public func resume(returning value: sending T)     // stdlib
public func resume(returning value: consuming T)    // our wrapper (as of this audit)
```

These serve different purposes:
- `sending`: region-based isolation transfer (SE-0430) — the value crosses isolation boundaries
- `consuming`: ownership transfer — the callee takes ownership, caller cannot reuse

For `~Copyable` element support, `consuming` becomes essential (you can't copy, so you must consume). The stdlib would need to add `consuming` for the `~Copyable` path:

```swift
public func resume(returning value: consuming sending T)
```

Our wrapper already has `consuming`, which is forward-compatible with this future signature.

## Constraints

1. **ABI stability**: Changing stdlib continuation generics is an ABI change. May require versioned availability or `@_alwaysEmitIntoClient`.
2. **Task runtime**: The continuation runtime (`swift_task_continuation_init`, `swift_continuation_resume`) handles values by pointer. It should be agnostic to `Copyable` since it doesn't copy values — it moves a pointer.
3. **Existing ecosystem**: Changing `Async.Channel<Element: Sendable>` to accept `~Copyable` elements changes existing overload resolution for callers.

## Recommendation

**Option B + D in parallel**: Prepare internal constraints now (Option B), and submit a Swift Evolution pitch (Option D).

### Immediate actions (Option B)

These changes make the package ready for ~Copyable elements with zero risk to current functionality:

1. **Already done**: `consuming` on `Continuation.resume(returning:)`, `consuming` on state machine send methods, `Receive.Outcome` tri-state enum
2. **Next**: Add `where Element: ~Copyable` extensions alongside existing extensions where the only operation is `consuming` push/take through Deque
3. **Next**: Consider making `Async.Continuation<T>` accept `T: ~Copyable & Sendable` — this doesn't affect `UnsafeContinuation` usage since the wrapper can still require `T: Sendable` for the stdlib call, but the Continuation type itself would be more flexible for callback-based usage

### Swift Evolution pitch (Option D)

Scope: Relax `Copyable` constraint on `UnsafeContinuation<T>` and `CheckedContinuation<T>` to `T: ~Copyable`.

Motivation: Move-only types (`~Copyable`) can represent unique resources (file handles, database connections, ownership tokens). These are precisely the values that benefit most from async channel transfer — yet they cannot be produced by `withUnsafeContinuation` today.

Prior art: `rdar://130179698` already has compiler infrastructure validation. `Optional`, `Result`, `Job`, `ExecutorJob` all support `~Copyable` in the stdlib.

## Outcome

**Status**: RECOMMENDATION

The path to `~Copyable` element support in async channels is clearer than originally assessed:

- **1 genuine blocker** (stdlib continuation generic constraint), not 5
- **Compiler infrastructure is ready** (proven by test case)
- **Package-level preparation can proceed immediately** (no stdlib dependency)
- **Swift Evolution pitch is the principled resolution** for the stdlib blocker

## References

- `swift-async-primitives/Research/audit.md` — Zero-Copy Pipeline audit section
- `swift-institute/Research/sending-expansion-audit.md` — Prior `sending` annotation audit
- `swift-institute/Research/witness-macro-noncopyable-support-design.md` — ~Copyable enum feasibility
- `swiftlang/swift/stdlib/public/Concurrency/PartialAsyncTask.swift` — UnsafeContinuation declaration
- `swiftlang/swift/stdlib/public/Concurrency/CheckedContinuation.swift` — CheckedContinuation declaration
- `swiftlang/swift/stdlib/public/core/Optional.swift` — Optional<T: ~Copyable> declaration
- `swiftlang/swift/test/ModuleInterface/Inputs/NoncopyableGenerics_Misc.swift:142` — ~Copyable continuation test case
