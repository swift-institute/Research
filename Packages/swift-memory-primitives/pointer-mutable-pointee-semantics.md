# Pointer.Mutable.pointee Mutation Semantics

<!--
---
version: 1.0.0
last_updated: 2026-01-26
status: DECISION
package: swift-pointer-primitives
affects: [Pointer.Mutable, Pointer.Buffer.Mutable]
---
-->

## Context

While implementing view types in swift-collection-primitives that hold `Pointer<T>.Mutable` as internal storage, compilation failed with:

```
error: cannot use mutating member on immutable value: 'base' is a get-only property
```

**Trigger**: View types declared `let _base: Pointer<Base>.Mutable` and attempted `_base.pointee.mutatingMethod()`.

**Current implementation** uses `unsafeMutableAddress`:

```swift
public var pointee: Tag {
    @inline(__always)
    unsafeAddress { unsafe UnsafePointer(_base) }
    @inline(__always)
    unsafeMutableAddress { unsafe _base }
}
```

This requires the pointer variable to be `var` to call mutating methods on `pointee`:

```swift
var ptr: Pointer<MyType>.Mutable = ...
ptr.pointee.mutatingMethod()  // Works

let ptr: Pointer<MyType>.Mutable = ...
ptr.pointee.mutatingMethod()  // Error: cannot use mutating member on immutable value
```

**Stdlib behavior**: `UnsafeMutablePointer.pointee` has `nonmutating set`, allowing mutation through `let` pointers:

```swift
let ptr: UnsafeMutablePointer<MyType> = ...
ptr.pointee.mutatingMethod()  // Works
```

**Constraints**:
1. Must work with `~Copyable` pointee types
2. Must support `~Escapable` view patterns
3. Should maintain performance parity with stdlib pointers

## Question

Should `Pointer<T>.Mutable.pointee` use `nonmutating` accessors (matching stdlib `UnsafeMutablePointer`) or require the pointer variable to be `var` when mutating the pointee?

## Analysis

### Option 1: Match stdlib (`nonmutating _modify`)

Use `nonmutating _modify` to allow mutation through `let` pointers:

```swift
public var pointee: Tag {
    _read { yield unsafe _base.pointee }
    nonmutating _modify { yield &_base.pointee }
}
```

**Advantages**:
- Semantically correct: the pointer value (the address) does not change when mutating the pointee
- Matches `UnsafeMutablePointer.pointee` behavior—familiar to developers
- Enables view patterns where borrowed pointers are stored as `let`:
  ```swift
  struct View<Base> {
      let _base: Pointer<Base>.Mutable  // Works with nonmutating

      func mutate() {
          _base.pointee.mutatingMethod()  // Works
      }
  }
  ```
- Critical for `~Escapable` borrowed views

**Disadvantages**:
- Mutation through `let` may be less visible at declaration site
- However, type name `Mutable` already signals mutation capability

### Option 2: Require `var` (current behavior)

Keep current `unsafeMutableAddress` requiring `var`:

```swift
public var pointee: Tag {
    unsafeAddress { unsafe UnsafePointer(_base) }
    unsafeMutableAddress { unsafe _base }
}
```

**Advantages**:
- Requiring `var` makes mutation visible at the declaration site
- More explicit about what can happen

**Disadvantages**:
- Technically incorrect: the pointer isn't being mutated, only the pointee
- Surprises developers familiar with stdlib
- Requires `var` in view types, conflicting with `~Escapable` patterns
- Creates awkward semantics (the view's pointer isn't changing)

### Comparison

| Criterion | Weight | Option 1 (nonmutating) | Option 2 (require var) |
|-----------|--------|------------------------|------------------------|
| Semantic correctness | High | Correct | Technically incorrect |
| Familiarity | Medium | Matches stdlib | Surprises developers |
| Safety indication | Medium | Less explicit | More explicit |
| Use case support | High | Enables view patterns | Requires workarounds |
| Performance | Low | Equal (yields address) | Equal (yields address) |

## Outcome

**Status**: DECISION

**Choice**: Option 1 — Use `nonmutating _modify`

**Rationale**:
1. **Semantically correct**: The pointer value (the address) doesn't change when mutating the pointee
2. **Matches stdlib behavior**: Familiar to developers using `UnsafeMutablePointer`
3. **Enables view patterns**: Critical for `~Escapable` borrowed views
4. **Type name communicates intent**: `Pointer<T>.Mutable` already signals mutation capability

**Implementation**:

```swift
public var pointee: Tag {
    _read { yield unsafe _base.pointee }
    nonmutating _modify { yield &_base.pointee }
}
```

Applied to:
- `Pointer<T>.Mutable.pointee`
- `Pointer<T>.Mutable.subscript(index:)`
- `Pointer<T>.Buffer.Mutable.subscript(index:)` (if applicable)

**Date**: 2026-01-26

## Additional Finding: View Types Internal Storage

During investigation, discovered that **View types** should use `UnsafeMutablePointer<Base>` internally rather than `Pointer<Base>.Mutable`.

**Trigger**: Attempting to use `View(&self)` syntax with `Pointer<Base>.Mutable` init.

**Problem**: The `&self` syntax produces `UnsafeMutablePointer<Self>`, not `Pointer<Self>.Mutable`. The `&` operator is compiler magic and cannot be overloaded.

**Resolution**: View type inits should accept `UnsafeMutablePointer<Base>` directly to enable clean `View(&self)` syntax without requiring explicit wrapper construction (`View(Pointer<Self>.Mutable(&self))`).

**Guideline**:
- **User-facing APIs**: Use `Pointer<T>.Mutable` for non-null guarantee and typed semantics
- **Internal View machinery**: Use `UnsafeMutablePointer<T>` for clean `&self` syntax

This finding is escalated to primitives-wide research: `swift-primitives/Research/stdlib-pointer-migration.md`

## References

- Swift stdlib `UnsafeMutablePointer` implementation
- [RES-001] Investigation Triggers
- [RES-004] Investigation Methodology
