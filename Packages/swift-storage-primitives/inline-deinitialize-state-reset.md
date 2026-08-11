# Inline Deinitialize State Reset

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
---
-->

> **Dependency**: This problem may be eliminated entirely by `per-slot-initialization-tracking.md` — if initialization is auto-tracked per-slot via BitVector, the double-free footgun disappears because deinit always knows exactly which slots are initialized.

## Context

**Trigger**: During testing of `Storage.Inline`, multiple tests crashed with double-free errors. The root cause: tests explicitly called `storage.deinitialize()` but did not reset `storage.initialization = .empty` afterward. When the storage went out of scope, `deinit` called `deinitialize()` again, attempting to free already-freed memory.

**Constraint**: `Storage.Inline.deinitialize()` is a non-mutating function because it must be callable from `deinit`. In Swift, `deinit` has consuming ownership of `self`, but we cannot make the function `mutating` because deinit cannot call mutating methods on structs.

**Comparison**: `Storage.Heap.deinitialize()` does NOT have this problem because:
1. `Storage.Heap` is a class (reference type)
2. Its `deinitialize()` can freely mutate `header.initialization = .empty`
3. The deinit is on the class, which can modify properties

**Current workaround**: All test code that explicitly calls `deinitialize()` on `Storage.Inline` must manually add `storage.initialization = .empty` afterward. This is error-prone and has caused multiple crashes during development.

## Question

How should `Storage.Inline` be designed to prevent double-free when `deinitialize()` is called explicitly before deinit runs?

## Analysis

### Option A: Document-Only (Status Quo)

**Description**: Keep current design. Document that callers of `deinitialize()` MUST reset `initialization = .empty` afterward.

**Advantages**:
- No code changes required
- Simple mental model: "deinitialize frees memory, caller manages state"
- Consistent with `deinitialize(range:)` which also requires caller to manage state

**Disadvantages**:
- Footgun: Easy to forget the reset
- Inconsistent with `Storage.Heap` which auto-resets
- Has already caused multiple test crashes
- Violates principle of least surprise

**Constraints**: None

---

### Option B: Internal Flag for Double-Call Protection

**Description**: Add an internal `_hasBeenDeinitialized: Bool` flag. The `deinitialize()` function checks this flag and returns early if already called.

```swift
@usableFromInline
package var _hasBeenDeinitialized: Bool = false

@inlinable
package func deinitialize() {
    guard !_hasBeenDeinitialized else { return }
    // ... existing logic ...
    // Can't set _hasBeenDeinitialized = true (non-mutating)
}
```

**Advantages**:
- Prevents double-free automatically
- No caller burden

**Disadvantages**:
- **FATAL FLAW**: Cannot set the flag from non-mutating function
- Adds memory overhead (1 byte + padding)
- Still can't actually implement this

**Constraints**: Non-mutating function cannot modify the flag.

---

### Option C: Consuming Deinitialize Method

**Description**: Make `deinitialize()` a `consuming` method that takes ownership of self, preventing any further use.

```swift
@inlinable
public consuming func deinitialize() {
    switch _initialization {
    case .empty: return
    case .one(let range): deinitializeRange(range)
    case .two(let first, let second):
        deinitializeRange(first)
        deinitializeRange(second)
    }
    discard self  // Prevents deinit from running
}
```

**Advantages**:
- Compile-time safety: Can't use storage after deinitialize
- `discard self` prevents deinit from running (no double-free)
- Clean ownership semantics

**Disadvantages**:
- Breaking API change
- Requires `discard self` which may not be available yet
- Tests would need to use `_ = consume storage` pattern
- Can't partially deinitialize and continue using storage

**Constraints**:
- Requires Swift's `discard` feature (experimental as of Swift 5.9)
- Changes method signature from `func` to `consuming func`

---

### Option D: Rename to Signal Finality

**Description**: Rename `deinitialize()` to something that clearly signals finality, like `deinitializeAndInvalidate()` or `finalCleanup()`.

**Advantages**:
- Name signals that this is a final operation
- Documentation through naming

**Disadvantages**:
- Doesn't actually prevent the bug
- Just makes it slightly more obvious
- Naming is awkward

**Constraints**: None

---

### Option E: Remove Public Deinitialize, Keep Only Deinit

**Description**: Make the bulk `deinitialize()` private/internal. External code uses only `deinitialize(at:)` or `deinitialize(range:)` for partial cleanup, and relies on deinit for full cleanup.

```swift
// Package-internal only, called by deinit
@inlinable
package func _deinitializeAll() { ... }

// Public: single slot, caller manages state
@inlinable
public func deinitialize(at slot: Index<Element>) { ... }

// Public: range, caller manages state
@inlinable
public func deinitialize(range: Range<Index<Element>>) { ... }
```

**Advantages**:
- Removes the footgun entirely for external callers
- Partial operations already require state management (expected)
- Deinit handles full cleanup automatically

**Disadvantages**:
- Tests need refactoring to use `do { }` blocks for scope-based cleanup
- Loses ability to explicitly trigger full cleanup for testing
- Less flexible API

**Constraints**: Test code would need restructuring.

---

### Option F: Check Initialization State in Deinitialize

**Description**: The current `deinitialize()` already checks `_initialization` and returns early if `.empty`. The issue is that it doesn't RESET the state. But what if deinit checked differently?

Wait - let me re-examine the current code:

```swift
package func deinitialize() {
    switch _initialization {
    case .empty:
        return  // Already returns early!
    case .one(let range):
        deinitialize(range: range)
    case .two(let first, let second):
        deinitialize(range: first)
        deinitialize(range: second)
    }
}
```

The function already returns early if `_initialization` is `.empty`. The problem is that after deinitializing, `_initialization` is NOT set to `.empty`, so the next call doesn't see `.empty`.

**INSIGHT**: If we could reset `_initialization` to `.empty` after deinitializing, the problem would be solved. But we can't because the function is non-mutating.

---

### Option G: Use UnsafeMutablePointer to Self

**Description**: Use unsafe pointer manipulation to modify `_initialization` from within the non-mutating function.

```swift
@inlinable
package func deinitialize() {
    switch _initialization {
    case .empty:
        return
    case .one(let range):
        deinitialize(range: range)
    case .two(let first, let second):
        deinitialize(range: first)
        deinitialize(range: second)
    }
    // Unsafe mutation of self
    withUnsafeMutablePointer(to: &self) { ptr in
        ptr.pointee._initialization = .empty
    }
}
```

**Advantages**:
- Solves the problem completely
- No API changes
- Automatic protection against double-free

**Disadvantages**:
- **FATAL FLAW**: Can't take `&self` in a non-mutating function
- Even if possible, extremely unsafe
- Violates Swift's memory safety guarantees

**Constraints**: Cannot get mutable pointer to self in non-mutating context.

---

### Option H: Wrapper Type with Explicit Lifecycle

**Description**: Instead of exposing `Storage.Inline` directly, provide a wrapper that manages lifecycle explicitly.

```swift
public struct ManagedStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    private var storage: Storage<Element>.Inline<capacity>
    private var isValid: Bool = true

    public mutating func deinitialize() {
        guard isValid else { return }
        storage.deinitialize()
        storage.initialization = .empty
        isValid = false
    }

    deinit {
        if isValid {
            storage.deinitialize()
        }
    }
}
```

**Advantages**:
- Complete safety
- Clear lifecycle semantics

**Disadvantages**:
- Additional wrapper type
- More complexity
- Doesn't fix existing `Storage.Inline` API

**Constraints**: Adds abstraction layer.

---

### Option I: Accept the Asymmetry

**Description**: Accept that `Storage.Inline` and `Storage.Heap` have different behavior, and document it clearly. The difference is inherent to value vs reference types.

**Rationale**:
- `Storage.Heap` is a class → can mutate in any method
- `Storage.Inline` is a struct → limited by value semantics
- This asymmetry is fundamental to Swift's type system
- Fighting it leads to complex workarounds

**Advantages**:
- Acknowledges reality of Swift's type system
- Clear documentation prevents surprises
- No complex workarounds

**Disadvantages**:
- Inconsistent API experience
- Footgun remains (mitigated by docs)

**Constraints**: None

---

## Comparison

| Criterion | A: Doc | B: Flag | C: Consuming | D: Rename | E: Private | F: N/A | G: Unsafe | H: Wrapper | I: Accept |
|-----------|--------|---------|--------------|-----------|------------|--------|-----------|------------|-----------|
| Prevents double-free | ❌ | ❌ (can't impl) | ✅ | ❌ | ✅ | N/A | ❌ (can't impl) | ✅ | ❌ |
| No API change | ✅ | ✅ | ❌ | ❌ | ❌ | N/A | ✅ | ❌ | ✅ |
| No overhead | ✅ | ❌ | ✅ | ✅ | ✅ | N/A | ✅ | ❌ | ✅ |
| Consistent with Heap | ❌ | ❌ | ❌ | ❌ | ❌ | N/A | ✅ | ✅ | ❌ |
| Implementable | ✅ | ❌ | ⚠️ (needs discard) | ✅ | ✅ | N/A | ❌ | ✅ | ✅ |
| Future-proof | ✅ | - | ✅ | ✅ | ✅ | N/A | - | ✅ | ✅ |

## Outcome

**Status**: RECOMMENDATION

### UPDATE 2026-02-05: `discard self` Experiments

Experiment `Experiments/discard-self-availability` (SUPERSEDED — consolidated into `swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/` V01-discard-self) thoroughly investigated `discard self`:

**What works:**
- `discard self` compiles and prevents deinit from running
- Works with types containing only trivially-destructible properties (Int, tuples of Int, etc.)
- Can store `~Copyable` elements in tuple storage and use `discard self` for cleanup

**What blocks Option C for Storage.Inline:**
1. `@_rawLayout` types are NOT trivially destructible (compiler error)
2. Reference types (`AnyObject?`, closures) are NOT trivially destructible
3. Alternative: tuple storage CAN use `discard self`, but deinit can't clean up elements
   without a type-aware deinitializer (which would break trivial destructibility)

**Fundamental limitation**: To support `discard self`, storage must be trivially-destructible.
But to properly clean up `~Copyable` elements in deinit, we need a type-aware deinitializer,
which requires either a closure (not trivially destructible) or `@_rawLayout` (not trivially destructible).

**Conclusion**: Option C is NOT viable for `Storage.Inline`. Revert to Option E + I.

---

### Recommended Approach: Option E + Option I

**Rationale**:

1. **Remove the footgun**: Make the bulk `deinitialize()` package-internal. External code should not be calling it directly - that's what deinit is for.

2. **Accept value/reference asymmetry**: The difference between `Storage.Inline` (struct) and `Storage.Heap` (class) is fundamental. Trying to make them behave identically leads to complex, unsafe workarounds.

3. **Document clearly**: Add documentation explaining:
   - `Storage.Inline.deinitialize()` is for deinit use only
   - Tests should use scope-based cleanup (`do { }` blocks)
   - For explicit partial cleanup, use `deinitialize(at:)` or `deinitialize(range:)` and manage state manually

### Implementation Notes

1. Change `package func deinitialize()` to `private func _deinitializeAll()` (or keep package-internal but rename with underscore prefix to signal internal use)

2. Update tests to use scope-based cleanup:
   ```swift
   // Before (footgun):
   storage.deinitialize()
   storage.initialization = .empty
   #expect(...)

   // After (safe):
   do {
       var storage = Storage<T>.Inline<N>()
       // ... initialize elements ...
       storage.initialization = .linear(count: n)
   } // deinit runs here, automatic cleanup
   #expect(tracker.count == 0)
   ```

3. For tests that MUST call deinitialize explicitly (e.g., testing deinitialize behavior itself), keep internal access but require the reset:
   ```swift
   // In test file, explicitly testing deinitialize behavior:
   storage.deinitialize()
   storage._initialization = .empty  // Required, documented
   ```

### Why Option C (discard self) Doesn't Work

`discard self` requires trivially-destructible stored properties. `Storage.Inline` uses
`@_rawLayout` which is NOT trivially destructible, even without a deinit on the inner type.

Attempted workaround (tuple-based storage) showed:
- CAN use `discard self` with tuple storage
- BUT deinit can't clean up elements without knowing the type
- Storing a deinitializer closure breaks trivial destructibility

See `Experiments/discard-self-availability` (SUPERSEDED — consolidated into `swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/` V01-discard-self) for detailed investigation.

## References

- Swift Evolution: [SE-0366 `consume` operator](https://github.com/apple/swift-evolution/blob/main/proposals/0366-move-function.md)
- Swift Evolution: [SE-0390 Noncopyable structs and enums](https://github.com/apple/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- Related: `@_rawLayout` cross-module deinit bug (swiftlang/swift#86652)

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status (Option E + I: make bulk `deinitialize()` package-internal and accept the value/reference asymmetry between Storage.Inline and Storage.Heap). The `discard self` experiment conclusively showed Option C is not viable due to `@_rawLayout` types not being trivially destructible. The ~Copyable value-generic deinit workaround (2026-03-10, using `UnsafeMutablePointer` in deinit) addresses a related but distinct problem. This document's recommendation stands as-is but implementation was deprioritized during the buffer inline module split.

**Resume when**: Storage.Inline API is being revised, or when Swift's `discard self` support for `@_rawLayout` types changes.
