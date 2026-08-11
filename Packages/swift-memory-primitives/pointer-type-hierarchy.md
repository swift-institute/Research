# Pointer Type Hierarchy

<!--
---
version: 1.0.0
last_updated: 2026-01-26
status: DECISION
tier: 3
---
-->

## Context

While implementing `swift-pointer-primitives`, a fundamental design question arose: What should the pointer type hierarchy look like, and should raw (untyped) pointers be included?

**Trigger**: Build errors with phantom generic pollution when nesting `Pointer.Raw.Mutable` under `Pointer<Pointee>`.

**Constraints**:
- Must follow [API-NAME-001] Nest.Name pattern
- Must support `~Copyable` pointee types
- Must not import Foundation [PRIM-FOUND-001]
- Should provide principled abstraction over Swift's pointer hierarchy

## Research Questions

**RQ1**: Is it possible to always use typed pointers, avoiding raw pointers entirely?

**RQ2**: What should the type hierarchy look like?

## Prior Art Survey

### Swift Stdlib Pointer Hierarchy

| | Typed | Raw (Untyped) |
|---|-------|---------------|
| **Immutable** | `UnsafePointer<T>` | `UnsafeRawPointer` |
| **Mutable** | `UnsafeMutablePointer<T>` | `UnsafeMutableRawPointer` |

Key observation: Raw pointers have **no generic parameter**.

### When Raw Pointers Are Used

| Use Case | Can Use Typed Instead? |
|----------|------------------------|
| Initial allocation | Yes: `UnsafeMutablePointer<T>.allocate(capacity:)` |
| Deallocation | Yes: `pointer.deallocate()` works on typed |
| Byte buffers | Yes: Use `Pointer<UInt8>` |
| Type reinterpretation | Yes: `withMemoryRebound(to:capacity:)` |
| C interop (void*) | Yes: Cast or use `OpaquePointer` |

### Analysis

Raw pointers are fundamentally necessary at the **implementation layer** (e.g., platform allocators like `posix_memalign` return raw memory). However, they can be **hidden from the public API**.

Example from `Buffer.Aligned`:
```swift
var bytePointer: UnsafeMutablePointer<UInt8>  // Typed, not raw!
```

The raw pointer is used only internally during allocation, then immediately bound to `UInt8`.

## Outcome

**Status**: DECISION

**Choice**: Skip raw pointers in the public API. Use typed pointers only.

### Final Type Hierarchy

```swift
struct Pointer<Pointee: ~Copyable> { ... }      // Immutable typed
extension Pointer {
    struct Mutable { ... }                       // Mutable typed
    typealias Immutable = Pointer                // Symmetry alias
}
```

For byte/raw-like access, use `Pointer<UInt8>`:
```swift
typealias BytePointer = Pointer<UInt8>
typealias MutableBytePointer = Pointer<UInt8>.Mutable
```

### Rationale

1. **Simplicity**: No phantom generic pollution from nesting raw under typed
2. **Sufficiency**: All practical use cases can be served by typed pointers
3. **Consistency**: `Pointer<UInt8>` is semantically equivalent to a byte pointer
4. **Internal flexibility**: Implementation can use stdlib raw pointers internally if needed
5. **API cleanliness**: Single hierarchy with clear semantics

### Implementation Notes

The `deinitialize(count:)` method returns `Pointer<UInt8>.Mutable` instead of a raw pointer:

```swift
public func deinitialize(count: Int) -> Pointer<UInt8>.Mutable {
    unsafe Pointer<UInt8>.Mutable(
        base.deinitialize(count: count).assumingMemoryBound(to: UInt8.self)
    )
}
```

This maintains type safety while providing the same functionality.

## Files

```
Sources/Pointer Primitives/
├── Pointer.swift           # struct Pointer<Pointee>
├── Pointer.Mutable.swift   # extension Pointer { struct Mutable }
└── exports.swift           # Re-exports
```

## References

- [SE-0107: UnsafeRawPointer](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0107-unsaferawpointer.md)
- [SE-0437: Noncopyable Stdlib Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- Research: `pointer-primitives-design.md` (superseded by this document)
