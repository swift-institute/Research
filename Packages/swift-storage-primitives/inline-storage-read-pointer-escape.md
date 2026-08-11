# Inline Storage Read Pointer Escape

<!--
---
version: 1.1.0
last_updated: 2026-01-29
status: DECISION
---
-->

## Context

During refactoring of `swift-stack-primitives` to use `swift-storage-primitives`, tests for `Stack.Inline` and `Stack.Small` began failing with garbage values when reading from inline storage. The `peek()` and `forEach()` operations returned invalid data despite `push()` and `pop()` working correctly.

**Trigger**: Stack primitives tests failing with garbage values (e.g., `stack.peek() → 6137504152` instead of `42`).

**Observation**: Operations using the mutating `pointer(at:)` method work correctly. Operations using the non-mutating `read(at:)` method return garbage.

## Question

How should `Storage.Static` provide non-mutating read access to stored elements without undefined behavior from pointer escape?

## Analysis

### The Bug

The current `read(at:)` implementation in `Storage.Static`:

```swift
@inlinable
@unsafe
public func read(at index: Index<Element>) -> Pointer<Element> {
    unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(base)
        return address.pointer(at: index, stride: Self.slotStride, as: Element.self)
    }
}
```

**Problem**: The pointer returned from `address.pointer(...)` is derived from `base`, which is only valid within the `withUnsafePointer` closure. When the closure returns, `base` becomes invalid, and any pointer derived from it becomes a dangling pointer.

Per [Apple's documentation](https://developer.apple.com/documentation/swift/withunsafepointer(to:_:)-35wrn):
> "The pointer argument to body is valid only during the execution of withUnsafePointer(to:_:). Do not store or return the pointer for later use."

### Why `pointer(at:)` Works

The mutating version uses `withUnsafeMutablePointer(to: &_storage)`:

```swift
public mutating func pointer(at index: Index<Element>) -> Pointer<Element> {
    unsafe withUnsafeMutablePointer(to: &_storage) { base in
        let address = unsafe Memory.Address(base)
        return address.pointer(at: index, stride: Self.slotStride, as: Element.self).immutable
    }
}
```

This also escapes a pointer from the closure, but the `&_storage` inout parameter establishes an exclusivity scope that extends beyond the closure. The memory layout of `_storage` is stable during the method call, and the caller maintains exclusive access.

However, this is still technically undefined behavior per Swift's documentation—it just happens to work in practice because:
1. The inout exclusivity prevents other access during the call
2. `_storage` is a stored property with stable address within the struct's lifetime
3. The caller typically uses the pointer immediately

### Option A: Closure-Based Read API

Change `read` to accept a closure that receives the pointer:

```swift
@inlinable
public func read<R>(at index: Index<Element>, _ body: (Pointer<Element>) -> R) -> R {
    unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(base)
        let ptr = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
        return body(ptr)
    }
}
```

**Advantages**:
- Pointer cannot escape the valid scope
- Matches Swift's `withUnsafe*` patterns
- Compiler can verify non-escape

**Disadvantages**:
- API change breaks existing callers
- More verbose for simple reads
- Closures have performance overhead
- Doesn't compose well with `~Copyable` elements

### Option B: Return Copied Value (Copyable only)

For `Copyable` elements, return the value directly:

```swift
@inlinable
public func read(at index: Index<Element>) -> Element where Element: Copyable {
    unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(base)
        return address.pointer(at: index, stride: Self.slotStride, as: Element.self).pointee
    }
}
```

**Advantages**:
- No pointer escape
- Simple API
- Value semantics

**Disadvantages**:
- Only works for `Copyable` elements
- Copies potentially large values
- Doesn't help `~Copyable` use cases

### Option C: Use `_read` Coroutine Accessor

Use Swift's `_read` accessor (SE-0474) to yield a borrowed reference:

```swift
@inlinable
public var element: Element {
    _read {
        // yield borrow to element
    }
}
```

Or provide subscript access:

```swift
public subscript(index: Index<Element>) -> Element {
    _read {
        unsafe withUnsafePointer(to: _storage) { base in
            let address = unsafe Memory.Address(base)
            yield address.pointer(at: index, stride: Self.slotStride, as: Element.self).pointee
        }
    }
}
```

**Advantages**:
- Yields borrowed access without copying
- Coroutine keeps scope alive until caller done
- Works with `~Copyable` elements
- Modern Swift pattern (SE-0474)

**Disadvantages**:
- `_read` is still evolving (underscored)
- Performance concerns documented in [Swift Forums](https://forums.swift.org/t/pitch-modify-and-read-accessors/75627)
- Requires caller to use the yielded value in-place

### Option D: Require Mutating Context

Remove `read(at:)` entirely; require callers to use the mutating `pointer(at:)`:

```swift
// Remove this method entirely
// public func read(at index: Index<Element>) -> Pointer<Element>

// Callers must use:
public mutating func pointer(at index: Index<Element>) -> Pointer<Element>
```

**Advantages**:
- Eliminates the UB
- Forces callers to think about mutation context
- Simpler API surface

**Disadvantages**:
- Breaks `forEach` from non-mutating contexts
- Breaks `peek` from borrowing contexts
- Breaks `deinit` (already uses workaround with `mutating` cast)
- Semantic mismatch: reading shouldn't require mutation rights

### Option E: Direct Pointer via Stored Property Pattern

Store a pointer to inline storage as a property, similar to how `Stack` caches `_cachedPtr`:

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, Slot>

    // Can't store pointer to self in init - address not stable yet
}
```

**Problem**: Cannot obtain pointer to `_storage` during `init` because the struct's memory layout isn't stable until init completes. Would require two-phase initialization or unsafe patterns.

### Option F: Span-Based Access

Provide a `Span<Element>` view property using `_read`:

```swift
public var span: Span<Element> {
    @_lifetime(borrow self)
    _read {
        unsafe withUnsafePointer(to: _storage) { base in
            let ptr = UnsafePointer<Element>(...)  // compute from base
            yield Span(_unsafeStart: ptr, count: count)
        }
    }
}
```

**Advantages**:
- Provides safe, bounded access
- Modern Swift pattern
- Works with `~Copyable`

**Disadvantages**:
- Requires caller to provide count
- Storage doesn't track count (by design)
- Same coroutine performance concerns

## Comparison

| Criterion | A: Closure | B: Copy | C: _read | D: Mutating | E: Cached | F: Span |
|-----------|------------|---------|----------|-------------|-----------|---------|
| ~Copyable support | Partial | No | Yes | Yes | N/A | Yes |
| No UB | Yes | Yes | Yes | Yes | N/A | Yes |
| Non-mutating | Yes | Yes | Yes | No | N/A | Yes |
| Simple call site | No | Yes | Yes | Yes | N/A | Moderate |
| No copy overhead | Yes | No | Yes | Yes | N/A | Yes |
| Stable ABI | Yes | Yes | No* | Yes | N/A | No* |
| Works in deinit | Yes | Partial | Uncertain | No | N/A | Uncertain |

*`_read` is underscored, not yet stable

## Constraints

1. **`~Copyable` support is required**: Many inline storage users have move-only elements
2. **Non-mutating read is required**: `peek()`, `forEach()`, `deinit` need read access without mutation rights
3. **Performance sensitive**: Inline storage is used for avoiding heap allocation; closure/coroutine overhead matters
4. **deinit context**: `deinitialize()` must work from deinit, which is non-mutating

## Current Workarounds in Codebase

The `deinitialize` methods already use a workaround:

```swift
public func deinitialize(count: Index<Element>.Count) {
    _ = unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(UnsafeMutableRawPointer(mutating: base))
        // ... uses the address within closure
    }
}
```

This works because:
1. The pointer is used entirely within the closure (doesn't escape)
2. The `mutating` cast is safe because we're in deinit (exclusive access)

## Recommendation

### Principled Swift 6.2+ Solution

Based on comprehensive analysis of the `memory` and `memory-safety` skills, and existing research on lifetime-dependent borrowed cursors, the principled solution combines:

1. **[MEM-SPAN-001]**: Property-based Span access, not closure-based
2. **[MEM-SAFE-014]**: Closure scope for unsafe operations
3. **SE-0474**: `_read` yielding accessor for borrowed access

**The key insight**: The `_read` accessor IS the correct Swift 6.2+ pattern. The bug is not in how callers use `read(at:)`, but in `read(at:)` itself returning an escaped pointer. The fix is to make `read(at:)` closure-based so the pointer NEVER escapes, and callers that need property-based access use `_read` accessors in their own API.

### Immediate Fix: Closure-Based Read API

Change `read(at:)` to accept a closure:

```swift
@inlinable
@unsafe
public func read<R>(at index: Index<Element>, _ body: (Pointer<Element>) -> R) -> R {
    unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(base)
        let ptr = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
        return body(ptr)
    }
}
```

### Callers Use `_read` for Property-Based Access

Stack types that need property-based span access implement it using `_read`:

```swift
// Stack.Inline.span - the principled pattern
public var span: Span<Element> {
    _read {
        // Use closure-based read, yield within _read scope
        _storage.read(at: .zero) { basePtr in
            yield unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(_unsafeStart: basePtr.base, count: _count)
        }
    }
}
```

Wait - this doesn't work because `yield` cannot be inside a closure.

### Correct Pattern: `_read` with withUnsafePointer

The `_read` accessor must call `withUnsafePointer` directly:

```swift
// Stack.Inline.span - correct pattern
public var span: Span<Element> {
    _read {
        unsafe withUnsafePointer(to: _storage._storage) { base in
            let address = unsafe Memory.Address(base)
            let ptr = address.pointer(at: .zero, stride: Storage<Element>.Static<capacity>.slotStride, as: Element.self)
            yield unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(_unsafeStart: ptr.base, count: _count)
        }
    }
}
```

This works because:
1. `_read` is a coroutine - it yields and waits
2. The `withUnsafePointer` closure doesn't return until `_read` resumes
3. The pointer remains valid during the entire borrow

### The Two-Layer Pattern

**Layer 1 (Storage.Static)**: Closure-based read for safe element access

```swift
// Storage.Static - closure-based, pointer never escapes
@inlinable
@unsafe
public func read<R>(at index: Index<Element>, _ body: (Pointer<Element>) -> R) -> R {
    unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(base)
        let ptr = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
        return body(ptr)
    }
}
```

**Layer 2 (Stack.Inline)**: `_read` accessor for property-based span access

The caller (Stack) implements `_read` accessors that call `withUnsafePointer` directly, yielding the span while the pointer scope is active.

### Why This Is Principally Correct

1. **[MEM-SAFE-014] Closure Scope Over Property Access**: The unsafe `withUnsafePointer` operation is scoped by the closure at Layer 1
2. **[MEM-SPAN-001] Property-Based Span Access**: Callers get clean `span` property via `_read` at Layer 2
3. **No pointer escape**: The pointer from `withUnsafePointer` never outlives its closure
4. **`_read` coroutine semantics**: The yield keeps the closure active until the caller finishes borrowing
5. **Works with `~Copyable`**: No copies required, just borrows

### Implementation Strategy

Since Stack.Inline's `span` property already uses `_read` correctly, the fix is simpler than expected:

**Option 1**: Make Stack.Inline access `_storage._storage` directly via `withUnsafePointer`

**Option 2**: Change `Storage.Static.read(at:)` to closure-based AND keep the existing `read(at:)` signature but mark it deprecated, implementing it via the closure version for compatibility during migration

**Option 3 (Recommended)**: Provide BOTH APIs:
- `read(at:_:)` - closure-based, safe
- Keep `read(at:)` but fix it to use the closure version internally (still UB but documents the escape)

Actually, looking more carefully at the Stack.Inline code, the `span` property directly calls `_storage.read(at: .zero).base` - this IS the bug. The fix is to change how `span` accesses the storage.

### Final Recommendation

**Fix Stack.Inline.span** to not use `_storage.read(at:)`:

```swift
public var span: Span<Element> {
    _read {
        // Access _storage._storage directly via withUnsafePointer
        // The yield happens INSIDE the withUnsafePointer closure,
        // keeping the pointer valid for the entire _read duration
        unsafe withUnsafePointer(to: _storage._storage) { base in
            let address = unsafe Memory.Address(base)
            let ptr = address.pointer(at: .zero, stride: Storage<Element>.Static<capacity>.slotStride, as: Element.self)
            yield unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(_unsafeStart: ptr.base, count: _count)
        }
    }
}
```

And fix `peek()` and `forEach()` similarly - they must use `withUnsafePointer` directly with the operation inside the closure.

**Storage.Static.read(at:)** should be changed to closure-based to prevent future misuse:

```swift
@inlinable
@unsafe
public func read<R>(at index: Index<Element>, _ body: (Pointer<Element>) -> R) -> R {
    unsafe withUnsafePointer(to: _storage) { base in
        let address = unsafe Memory.Address(base)
        let ptr = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
        return body(ptr)
    }
}
```

## Outcome

**Status**: DECISION

The bug is confirmed. `Storage.Static.read(at:)` returns a pointer that escapes the `withUnsafePointer` closure scope, causing undefined behavior.

**Decision**: Implement two-layer fix:

1. **Storage.Static**: Change `read(at:)` to closure-based API
2. **Stack.Inline**: Fix `span`, `peek()`, `forEach()` to either:
   - Use the new closure-based `read(at:_:)`, OR
   - Access `_storage._storage` directly via `withUnsafePointer` with operations inside the closure

**Implementation steps**:
1. Add closure-based `read(at:_:)` to Storage.Static
2. Deprecate pointer-returning `read(at:)`
3. Update Stack.Inline callers
4. Verify tests pass
5. Document the pattern for other inline storage users

## References

- [Apple: withUnsafePointer(to:_:)](https://developer.apple.com/documentation/swift/withunsafepointer(to:_:)-35wrn) - pointer validity scope
- [WWDC20: Safely manage pointers in Swift](https://developer.apple.com/videos/play/wwdc2020/10167/) - pointer safety patterns
- [SE-0474: Yielding Accessors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0474-yielding-accessors.md) - `_read`/`_modify` evolution
- [Swift Forums: Modify and read accessors](https://forums.swift.org/t/pitch-modify-and-read-accessors/75627) - performance discussion
- [Trycombine: Yielding accessors in Swift](https://trycombine.com/posts/swift-read-modify-coroutines/) - practical guide
