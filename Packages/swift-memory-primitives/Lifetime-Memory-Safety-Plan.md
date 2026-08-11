# Lifetime and Memory Safety: Experiment Results

<!--
---
status: COMPLETE
version: 2.0.0
date: 2026-01-26
author: Swift Institute
applies_to: [pointer-primitives]
---
-->

## Executive Summary

This document records the experiment-driven investigation into Swift's lifetime system for `~Escapable` types (`Span`, `MutableSpan`). The initial hypothesis was **refuted**—the `_overrideLifetime` function **is** available to external packages, enabling stdlib interop extensions.

---

## 1. Initial Hypothesis (REFUTED)

**Claim**: Extension initializers on `Span`/`MutableSpan` are not feasible because:
1. `@_lifetime(immortal)` alone doesn't prevent lifetime escape errors
2. `_overrideLifetime` is internal to stdlib and unavailable externally

**Conclusion**: Hypothesis **partially correct, partially wrong**.
- ✅ `@_lifetime(immortal)` alone does NOT work (confirmed by experiment)
- ❌ `_overrideLifetime` IS available externally (refuted by experiment)

---

## 2. Experiment Results

### 2.1 Variant 1-3: `@_lifetime(immortal)` Alone

**Test**:
```swift
extension Swift.Span where Element: ~Copyable {
    @_lifetime(immortal)
    init(testStart start: UnsafePointer<Element>, testCount count: Int) {
        unsafe self.init(_unsafeStart: start, count: count)
    }
}
```

**Result**: FAILED
```
error: lifetime-dependent variable 'self' escapes its scope
    init(testStart start: UnsafePointer<Element>, testCount count: Int) {
    |              `- note: it depends on the lifetime of argument 'start'
    `- error: lifetime-dependent variable 'self' escapes its scope
```

**Finding**: The compiler infers a lifetime dependency from parameters even with `@_lifetime(immortal)`.

### 2.2 Variant 4: `_overrideLifetime` Pattern

**Test**:
```swift
extension Swift.Span where Element: ~Copyable {
    @_lifetime(immortal)
    init(wrapperStart start: PointerWrapper<Element>, wrapperCount count: Int) {
        let span = unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(_unsafeStart: start.base, count: count)
        self = unsafe _overrideLifetime(span, borrowing: ())
    }
}
```

**Result**: PASSED
```
Build complete!
Span: Created with 5 elements, first = 1
MutableSpan: Modified first element to 999
Array after modification: [999, 20, 30]
```

**Finding**: `_overrideLifetime` is available externally and the pattern works.

---

## 3. Working Pattern

### 3.1 For Span Extensions

```swift
extension Swift.Span where Element: ~Copyable {
    @_lifetime(immortal)
    @inlinable
    public init(_unsafeStart start: Pointer<Element>, count: Int) {
        let span = unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(_unsafeStart: start.base, count: count)
        self = unsafe _overrideLifetime(span, borrowing: ())
    }
}
```

### 3.2 For MutableSpan Extensions

```swift
extension Swift.MutableSpan where Element: ~Copyable {
    @_lifetime(immortal)
    @inlinable
    public init(_unsafeStart start: Pointer<Element>.Mutable, count: Int) {
        let span = unsafe Swift.MutableSpan(_unsafeStart: start.base, count: count)
        self = unsafe _overrideLifetime(span, borrowing: ())
    }
}
```

### 3.3 Key Components

| Component | Required | Purpose |
|-----------|----------|---------|
| `@_lifetime(immortal)` | Yes | Declares no external lifetime dependency |
| `let span = unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(...)` | Yes | Create intermediate span |
| `self = unsafe _overrideLifetime(span, borrowing: ())` | Yes | Override inferred dependency |
| `borrowing: ()` | Yes | Unit type signals "immortal" (no dependency) |

---

## 4. Implementation Status

All four stdlib interop extension files now compile and work:

| File | Status |
|------|--------|
| `UnsafeBufferPointer+Pointer.swift` | ✅ Working |
| `UnsafeMutableBufferPointer+Pointer.swift` | ✅ Working |
| `Span+Pointer.swift` | ✅ Working |
| `MutableSpan+Pointer.swift` | ✅ Working |

Tests: **42/42 passed**

---

## 5. Methodology Notes

This investigation followed [EXP-011] Experiment-First Debugging:

1. **Trigger**: Production code failed with lifetime escape errors
2. **Experiment created**: `Experiments/span-lifetime-interop/`
3. **Incremental construction** ([EXP-004a]): Built up from simplest case
4. **Isolation**: Found that `@_lifetime(immortal)` alone fails
5. **Working pattern discovered**: `_overrideLifetime` is the missing piece
6. **Applied to production**: Extensions now work

**Key lesson**: Don't assume stdlib-internal functions are unavailable. Test empirically.

---

## References

- Experiment: `/Users/coen/Developer/swift-primitives/swift-pointer-primitives/Experiments/span-lifetime-interop/`
- [SE-0446: Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md)
- [Experimental Support for Lifetime Dependencies](https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638)
- [Swift stdlib CollectionOfOne.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/CollectionOfOne.swift) - shows the pattern
