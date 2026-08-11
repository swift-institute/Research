# Storage Contiguous Protocol Conformance

<!--
---
version: 1.1.0
last_updated: 2026-02-05
status: DECISION
---
-->

> **See also**: `storage-contiguous-api-design.md` is the comprehensive API design decision that incorporates this document's conformance conclusion.

## Context

`Span.Protocol` defines a standard interface for types providing contiguous memory access.

**Question**: Can `Storage.Heap` and `Storage.Inline<Element, capacity>` conform to `Span.Protocol`?

**Trigger**: Architectural consistency—storage primitives should integrate with memory primitives' contiguous access protocol.

---

## Outcome

**Status**: DECISION

### Protocol Design

The protocol is **read-only by default**. Mutable access is type-specific.

```swift
extension Span {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element

        /// Safe read access via Span.
        var span: Span<Element> { get }

        /// Unsafe read access for C interop.
        func withUnsafeBufferPointer<R, E: Swift.Error>(
            _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
        ) throws(E) -> R
    }
}
```

**Rationale**:
- `mutableSpan { mutating get }` cannot be implemented by classes (no mutating getters)
- Read access is universally providable; write access varies by type
- Follows principle: protocol represents what ALL conforming types can provide

### Conformance

| Type | Protocol Conformance | Mutable Access |
|------|---------------------|----------------|
| `Storage.Inline` | ✅ `Span.Protocol` | `var mutableSpan` (struct can have `mutating get`) |
| `Storage.Heap` | ✅ `Span.Protocol` | `func withMutableSpan` (closure-based) |

### Implementation Pattern

Swift 6.2 enables property-based Span access via `@_lifetime` + `_overrideLifetime`:

```swift
// Storage.Inline - full property-based access
extension Storage.Inline: Span.`Protocol` where Element: Copyable {
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let ptr = unsafe withUnsafePointer(to: _storage) { base in
                unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            }
            let span = unsafe Span(_unsafeStart: ptr, count: _count)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    // Type-specific mutable access (not in protocol)
    var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let ptr = unsafe withUnsafeMutablePointer(to: &_storage) { base in
                unsafe UnsafeMutableRawPointer(base).assumingMemoryBound(to: Element.self)
            }
            let span = unsafe MutableSpan(_unsafeStart: ptr, count: _count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }
}

// Storage.Heap - span property + closure-based mutable
extension Storage.Heap: Span.`Protocol` where Element: Copyable {
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let (ptr, cnt) = unsafe withUnsafeMutablePointerToElements { base in
                (UnsafePointer(base), count)
            }
            let span = unsafe Span(_unsafeStart: ptr, count: cnt)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    // Type-specific mutable access (closure-based, not property)
    func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            var span = unsafe MutableSpan(_unsafeStart: base, count: count)
            return try body(&span)
        }
    }
}
```

---

## Key Findings

1. **Read-only protocol is correct** — Universal capability goes in protocol; type-specific capability goes in extensions.

2. **`_overrideLifetime` is required** — Non-Escapable types cannot be returned from closure-based APIs. Pattern:
   - Extract raw pointer value from closure
   - Create Span outside the closure
   - Use `_overrideLifetime(span, borrowing: self)` to establish lifetime dependency

3. **Classes cannot have `mutating get`** — `Storage.Heap` uses closure-based `withMutableSpan` instead of property.

4. **Lifetime safety works** — Compiler prevents overlapping access when span borrows storage.

---

## Constraints

1. **Element: Copyable required** — `Span<Element>` requires `Element: Copyable` (SE-0427 limitation)

2. **Linear initialization required** — Protocol assumes elements `0..<count` are initialized

3. **`_overrideLifetime` is underscored** — Currently available but not ABI-stable

---

## Experiment

Verified in: `Experiments/contiguous-protocol-conformance/`

```
Result: CONFIRMED
- Storage.Inline: full conformance works
- Storage.Heap: full conformance works (span property)
- Mutable access: type-specific (property for struct, closure for class)
```

---

## References

- [SE-0446: Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-nonescapable-types.md)
- [SE-0447: Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [SE-0456: Span-providing Properties](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md)
- [Property Lifetimes Design Doc](https://gist.github.com/atrick/9409356c89a5f67dd9f68f708f57262e)
