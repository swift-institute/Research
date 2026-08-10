# Repeating Reference-Type Aliasing

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: DECISION
---
-->

## Context

`Array.Fixed(repeating:count:)` and `Array.Fixed.Indexed(repeating:count:)` accept any `Copyable` element. When the element is a **value type**, `repeating:` produces independent copies — each slot owns its own storage. When the element is a **reference type** (class), `repeating:` copies the *reference*, producing N aliases to the **same** object.

This was discovered in `swift-pool-primitives` where `Pool.Bounded` initialized its entries array with:

```swift
self.entries = Array<Entry>.Fixed.Indexed(
    repeating: Entry(), count: try! Slot.Index.Count(capacity.value)
)
```

`Entry` is `Ownership.Slot<Resource>` — a `final class`. All slots received the same object reference. The second `fill()` crashed:

```
Ownership_Primitives/Ownership.Slot.Store.swift:70:
Fatal error: Ownership.Slot.store(__unchecked:): already occupied
```

## Question

How should `Array.Fixed` handle the `repeating:` footgun for reference types?

## Analysis

### Option A: Document-Only

Leave the API unchanged. Add documentation warning that `repeating:` aliases reference types.

- **Pros**: No API change, no breakage.
- **Cons**: Silent bug at every call site. Identical to stdlib's `Array(repeating:count:)` footgun, which has a decades-long history of catching developers off guard.

### Option B: Deprecate or Remove `repeating:` for Reference Types

Add a compile-time constraint `where Element: ~AnyObject` (not possible in current Swift) or runtime check.

- **Pros**: Eliminates the bug category.
- **Cons**: Swift has no `~AnyObject` constraint. Runtime checks defeat the purpose.

### Option C: Provide Factory-Based Companion API

Keep `repeating:` for value types. Promote `init(count:initializingWith:)` as the canonical API for reference types, since the closure creates a fresh instance per slot.

- **Pros**: Both APIs exist. The closure variant is already available. Documentation guides users to the correct choice.
- **Cons**: Requires discipline. The footgun remains available.

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Eliminates bug | No | Yes | Partially |
| API breakage | None | Possible | None |
| Feasible today | Yes | No | Yes |
| Discoverability | Low | N/A | Medium |

## Outcome

**Status**: DECISION

**Chosen**: Option C — Factory-based companion with documentation.

The fix applied in `swift-pool-primitives`:

```swift
// Before (bug): one Entry() shared by all slots
self.entries = Array<Entry>.Fixed.Indexed(
    repeating: Entry(), count: try! Slot.Index.Count(capacity.value)
)

// After (correct): fresh Entry() per slot
self.entries = Array<Entry>.Fixed.Indexed(
    try! Array<Entry>.Fixed(
        count: Index<Entry>.Count(capacity.value),
        initializingWith: { _ in Entry() }
    )
)
```

### Implementation Notes

1. **`Array.Fixed.Indexed` lacks `init(count:initializingWith:)`** — the fix constructs `Array.Fixed` first and wraps. Consider adding a forwarding initializer to `Array.Fixed.Indexed` for ergonomics.
2. **Documentation**: `repeating:` should document that reference types produce aliased slots.
3. **Audit**: Any future use of `repeating:` with class-typed elements is suspect.

### Diagnostic Rule

> If `Element` conforms to `AnyObject` (or is known to be a class), `repeating:` produces N references to ONE object. Use `init(count:initializingWith:)` instead.

## References

- `swift-pool-primitives` commit: fix `Pool.Bounded` entry initialization
- `swift-array-primitives/Sources/Array Fixed Primitives/Array.Fixed Repeating.swift`
- `swift-array-primitives/Sources/Array Primitives Core/Array.Fixed.swift` (closure-based init)
- Swift stdlib `Array(repeating:count:)` — same semantics, same footgun
