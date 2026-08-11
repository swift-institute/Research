# Architectural Patterns in Swift Collection Primitives: A Design Analysis
<!--
---
version: 1.0.0
last_updated: 2026-01-20
status: IMPLEMENTED
---
-->

**Abstract.** This paper analyzes the architectural patterns underlying the Swift Institute's collection primitives—Deque, Heap, and Queue—with emphasis on their support for move-only (`~Copyable`) elements, typed error handling, and variant-based capacity strategies. We examine the design decisions that enable these primitives to serve as foundational building blocks while maintaining zero-cost abstractions and strict memory safety. The patterns documented here establish a replicable framework for implementing additional collection primitives.

---

## 1. Introduction

The Swift Institute's collection primitives occupy Layer 1 of the Five-Layer Architecture: atomic building blocks with no external dependencies beyond the Swift standard library. These primitives must satisfy competing requirements:

1. **Generality**: Support both `Copyable` and `~Copyable` element types
2. **Performance**: Zero-cost abstractions with predictable memory behavior
3. **Safety**: Compile-time guarantees via Swift's ownership system
4. **Ergonomics**: Idiomatic Swift APIs following the Nest.Name pattern

Traditional collection libraries assume copyable elements, precluding their use with move-only resources like file descriptors, unique handles, or linear types. The primitives analyzed here demonstrate that full `~Copyable` support is achievable without sacrificing API ergonomics for the common `Copyable` case.

### 1.1 Scope

This analysis covers three collection primitives:

| Primitive | Structure | Access Pattern |
|-----------|-----------|----------------|
| **Deque** | Ring buffer | Double-ended (front/back) |
| **Heap** | Min-max heap | Priority-based (min/max) |
| **Queue** | Ring buffer | FIFO (enqueue/dequeue) |

Each primitive provides four variants addressing different capacity constraints:

| Variant | Storage | Capacity | Use Case |
|---------|---------|----------|----------|
| Base | Heap-allocated | Unbounded | General purpose |
| Bounded | Heap-allocated | Fixed | Predictable memory |
| Inline | Stack-allocated | Compile-time | Zero allocation |
| Small | Stack → Heap | Hybrid | Small-buffer optimization |

---

## 2. Core Architectural Patterns

### 2.1 Nested Storage Class

All three primitives use a `ManagedBuffer`-based storage class declared as a nested type within the outer struct:

```swift
public struct Queue<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    final class Storage: ManagedBuffer<Header, Element> {
        // ...
    }

    var _storage: Storage
    var _cachedPtr: UnsafeMutablePointer<Element>
}
```

**Rationale**: Declaring `Storage` inside the generic `~Copyable` struct ensures the `Element` generic parameter inherits the `~Copyable` suppression. A module-level class would default to `Element: Copyable`, requiring explicit suppression and creating maintenance burden.

The nested declaration also follows [API-NAME-001]: the type path `Queue.Storage` accurately reflects the ownership relationship.

### 2.2 Cached Pointer Pattern

Each primitive stores a cached pointer alongside the storage reference:

```swift
var _storage: Storage
var _cachedPtr: UnsafeMutablePointer<Element>
```

This enables property-based Span access per SE-0456:

```swift
var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get {
        unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span
unsafe Swift.Span(_unsafeStart: _cachedPtr, count: count)
    }
}
```

**Rationale**: Swift's lifetime checker cannot prove that a pointer obtained from `ManagedBuffer.withUnsafeMutablePointerToElements` survives beyond the closure scope. By caching the pointer as a stored property, its lifetime becomes tied to the struct's lifetime, enabling property-based access.

**Discipline Required**: The cached pointer must be updated on every storage reallocation:
- Initial allocation
- Capacity growth
- Copy-on-Write copy
- Clear with deallocation

Failure to update causes use-after-free.

### 2.3 Conditional Copyable

All primitives are conditionally `Copyable`:

```swift
public struct Deque<Element: ~Copyable>: ~Copyable { ... }
extension Deque: Copyable where Element: Copyable {}
```

This provides:
- **Move-only containers** for `~Copyable` elements
- **Value semantics with CoW** for `Copyable` elements
- **Backward compatibility** with existing code expecting copyable collections

The conditional conformance is not merely syntactic sugar—it enables `Sequence` conformance, which requires `Copyable`:

```swift
extension Queue: Swift.Sequence where Element: Copyable { ... }
```

### 2.4 Method Shadowing for CoW

Primitives provide two implementations of mutating methods:

```swift
// Base implementation (~Copyable elements)
extension Queue where Element: ~Copyable {
    public mutating func enqueue(_ element: consuming Element) { ... }
}

// CoW-aware implementation (Copyable elements)
extension Queue where Element: Copyable {
    public mutating func enqueue(_ element: Element) {
        makeUnique()  // CoW check
        // ... same logic
    }
}
```

Swift's overload resolution selects the more specific `Copyable` extension when applicable. This provides:
- Transparent CoW for `Copyable` elements
- No CoW overhead for `~Copyable` elements (which can't be copied anyway)
- Identical API surface for both cases

---

## 3. The Variant System

### 3.1 Design Philosophy

Each primitive offers four variants addressing the capacity-allocation spectrum:

```
Allocation:  None ←————————————————————————→ Dynamic
             Inline    Small    Bounded    Base
Capacity:    Fixed     Hybrid   Fixed      Unbounded
             (compile) (spill)  (runtime)
```

This is not feature creep—each variant serves a distinct use case:

| Variant | When to Use |
|---------|-------------|
| **Base** | General purpose; capacity unknown |
| **Bounded** | Embedded/real-time; predictable memory |
| **Inline** | Hot paths; zero allocation overhead |
| **Small** | Common case small, occasional large |

### 3.2 Bounded Variant

`Deque.Bounded`, `Queue.Fixed` allocate storage upfront and throw on overflow:

```swift
public struct Fixed: ~Copyable {
    var _storage: Storage
    var _cachedPtr: UnsafeMutablePointer<Element>
    let capacity: Int

    public init(capacity: Int) throws(Deque<Element>.Bounded.Error) {
        guard capacity >= 0 else { throw .invalidCapacity }
        self._storage = Storage.create(minimumCapacity: capacity)
        // ...
    }

    public mutating func push(_ element: consuming Element,
                              to position: Position) throws(Deque<Element>.Bounded.Error) {
        guard !isFull else { throw .overflow }
        // ...
    }
}
```

**Key Properties**:
- Capacity fixed at initialization
- Throws typed error on overflow (not crash)
- Shares `Storage` class with base variant
- Conditional `Copyable` when `Element: Copyable`

### 3.3 Inline Variant

`Deque.Inline<let capacity: Int>` uses compile-time generic parameters for zero-allocation storage:

```swift
public struct Inline<let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _head: Int
    var _tail: Int
    var _count: Int

    deinit {
        // Manual cleanup of inline storage
    }
}
```

**Key Properties**:
- Capacity is a compile-time constant (value generic)
- Storage is part of the struct's memory layout
- **Unconditionally `~Copyable`** due to `deinit` requirement
- Maximum element stride limited by slot size (64 bytes)

**Declaration Site Constraint**: Due to a Swift compiler bug, `Inline` must be declared inside the struct body, not in an extension. Extensions don't properly inherit `~Copyable` from the outer type's generic parameter.

### 3.4 Small Variant

`Deque.Small<let inlineCapacity: Int>` combines inline and heap storage:

```swift
public struct Small<let inlineCapacity: Int>: ~Copyable {
    var _inline: InlineArray<inlineCapacity, ...>
    var _head: Int
    var _tail: Int
    var _count: Int
    var _heap: Storage?
    var _heapPtr: UnsafeMutablePointer<Element>?

    public var isSpilled: Bool { _heap != nil }
}
```

**Behavior**:
1. Elements stored inline up to `inlineCapacity`
2. On overflow, allocates heap storage and moves all elements
3. Once spilled, remains on heap (no compaction back to inline)

**Key Properties**:
- Unconditionally `~Copyable` due to `deinit`
- Optimal for "usually small, sometimes large" patterns
- Shares heap `Storage` class with base variant

---

## 4. Error Handling Architecture

### 4.1 Hoisted Error Types with Typealiases

Swift does not allow nested types inside generic types to be easily referenced in typed throws signatures. The primitives use a hoisting pattern:

```swift
// Module-level (hoisted)
public enum __DequeBoundedError: Error, Sendable, Equatable {
    case invalidCapacity
    case overflow
    case empty
    case bounds(index: Int, count: Int)
}

// Typealias provides Nest.Name API
extension Deque.Bounded where Element: ~Copyable {
    public typealias Error = __DequeBoundedError
}
```

**Critical Constraint**: The extension defining the typealias must include `where Element: ~Copyable`. Without this, Swift's implicit `Copyable` constraint on extensions causes the typealias to require `Element: Copyable`, breaking use in `~Copyable` contexts.

### 4.2 Typed Throws in Public API

All public throwing methods use typed throws with the typealias form:

```swift
public init(capacity: Int) throws(Deque<Element>.Bounded.Error) { ... }
public mutating func push(_ element: consuming Element,
                          to position: Position) throws(Deque<Element>.Bounded.Error) { ... }
```

**Benefits**:
- Compile-time exhaustiveness checking in `catch` blocks
- No existential boxing overhead
- API shows `Deque.Bounded.Error` (not `__DequeBoundedError`)

### 4.3 Error Type Taxonomy

Each variant has error types appropriate to its failure modes:

| Variant | Error Cases | Rationale |
|---------|-------------|-----------|
| **Base** | `empty`, `bounds`, `invalidCapacity` | Never overflows (grows) |
| **Bounded** | `empty`, `bounds`, `invalidCapacity`, `overflow` | Fixed capacity |
| **Inline** | `empty`, `overflow` | Capacity fixed at compile-time |
| **Small** | `empty` | Cannot overflow (spills to heap) |

This is not redundancy—unified error types would include cases that can never occur for some variants, complicating exhaustiveness checking.

---

## 5. ~Copyable Support Patterns

### 5.1 The Three-Bug Taxonomy

Supporting `~Copyable` elements requires navigating three Swift compiler limitations:

**Bug 1: Extension Declaration Site**
```swift
// BROKEN: Nested type doesn't inherit ~Copyable
extension Outer<Element: ~Copyable> {
    struct Nested: ~Copyable { }  // Element implicitly Copyable!
}

// FIXED: Declare inside struct body
struct Outer<Element: ~Copyable>: ~Copyable {
    struct Nested: ~Copyable { }  // Element inherits ~Copyable
}
```

**Bug 2: Implicit Copyable in Extensions**
```swift
// BROKEN: Implicit Copyable constraint
extension Deque.Bounded {
    func foo() { }  // Only works with Copyable elements
}

// FIXED: Explicit suppression
extension Deque.Bounded where Element: ~Copyable {
    func foo() { }  // Works with all elements
}
```

**Bug 3: Protocol Conformance File Locality**
```swift
// BROKEN: Conformance in separate file
// File: Bounded.swift
extension Deque.Bounded: Swift.Sequence where Element: Copyable { }
// Causes: "type 'Element' does not conform to 'Copyable'" in main file

// FIXED: Conformance in same file as declaration
// File: Deque.swift (same file as Deque.Bounded declaration)
extension Deque.Bounded: Swift.Sequence where Element: Copyable { }
```

### 5.2 Ownership-Aware Method Signatures

Methods use explicit ownership annotations:

```swift
// Consuming: Takes ownership of element
public mutating func push(_ element: consuming Element, to position: Position)

// Borrowing: Temporary access without ownership transfer
public func peek<R>(_ body: (borrowing Element) -> R) -> R?

// Move return: Transfers ownership to caller
public mutating func pop(from position: Position) -> Element?
```

For `Copyable` elements, these annotations are transparent—the compiler handles copies. For `~Copyable` elements, they enforce correct ownership transfer.

### 5.3 Dual API Pattern

Primitives provide two access patterns for the same operation:

```swift
// For ~Copyable elements: Closure-based borrowing
public func peek<R>(_ body: (borrowing Element) -> R) -> R?

// For Copyable elements: Direct return
public func peek() -> Element?
```

The closure-based API works for all elements; the direct return is a convenience for `Copyable` elements. Both are provided because:
- Closure-based is more verbose for simple access
- Direct return cannot work with `~Copyable` (would require copy)

---

## 6. Heap-Specific Patterns

### 6.1 Min-Max Heap Structure

`Heap` implements a min-max heap (Atkinson et al., 1986), providing O(1) access to both minimum and maximum:

```swift
heap.peek.min  // O(1)
heap.peek.max  // O(1)
heap.pop.min() // O(log n)
heap.pop.max() // O(log n)
```

**Storage**: Standard array-based heap with alternating min/max levels.

### 6.2 Ordering Protocol

Unlike Deque and Queue, Heap requires element ordering:

```swift
public protocol __HeapOrdering {
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

extension Heap {
    public typealias Ordering = __HeapOrdering
}
```

**Why not `Comparable`?** The `Comparable` protocol requires `Copyable` conformers. By defining a custom protocol with `borrowing` parameters, Heap supports `~Copyable` elements that can be compared without copying.

Default conformance is provided for `Comparable` types:

```swift
extension Comparable where Self: ~Copyable {
    public static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs < rhs
    }
}
```

### 6.3 Nested Error Type (Non-Hoisted)

Unlike Deque and Queue, Heap uses a true nested error type:

```swift
extension Heap {
    public enum Error: Swift.Error, Sendable, Equatable {
        case empty(Empty)
    }
}
```

This works because `Heap.Error` doesn't reference the `Element` generic parameter. The error type is invariant across element types, so the implicit `Copyable` constraint on the extension doesn't cause issues.

---

## 7. Ring Buffer Implementation Details

### 7.1 Header Structure

Deque and Queue use ring buffer storage with a three-field header:

```swift
final class Storage: ManagedBuffer<(head: Int, tail: Int, count: Int), Element> {
    // head: Index of next element to dequeue/pop-front
    // tail: Index where next element will be enqueued/push-back
    // count: Number of valid elements
}
```

**Why `count` instead of computing `(tail - head) % capacity`?**
- Distinguishes empty (`count == 0`) from full (`count == capacity`)
- Avoids modular arithmetic edge cases
- O(1) `count` property without computation

### 7.2 Wrap-Around Semantics

Elements wrap around the buffer end:

```swift
// Enqueue at tail
_storage._initializeElement(at: tail, to: element)
_storage.header.tail = (tail + 1) % capacity

// Dequeue from head
let element = _storage._moveElement(at: head)
_storage.header.head = (head + 1) % capacity
```

**Linearization on Growth**: When capacity increases, elements are copied to the new buffer in logical order (head to tail), resetting `head = 0` and `tail = count`. This linearizes the ring buffer, avoiding complex wrap-around copies.

---

## 8. Design Principles Extracted

### 8.1 Principle of Structural Parity

All collection primitives should offer the same variant taxonomy:
- Base (unbounded)
- Bounded (fixed, runtime)
- Inline (fixed, compile-time)
- Small (hybrid)

This provides predictable API surface and enables code reuse patterns.

### 8.2 Principle of Conditional Capability

Features are conditionally available based on element constraints:

| Constraint | Capability |
|------------|------------|
| `Element: Copyable` | CoW, `Sequence` conformance, direct-return peek |
| `Element: Sendable` | `@unchecked Sendable` conformance |
| `Element: Equatable` | `Equatable` conformance |
| `Element: Hashable` | `Hashable` conformance |

### 8.3 Principle of Explicit Constraints

Every extension must explicitly declare its constraint context:

```swift
extension Deque.Bounded where Element: ~Copyable { ... }  // Works with all
extension Deque.Bounded where Element: Copyable { ... }   // CoW methods
extension Deque.Bounded { ... }  // AVOID: Implicit Copyable
```

### 8.4 Principle of Typed Errors

All throwing operations use typed throws with variant-specific error types. The error type taxonomy matches the variant's failure modes—no phantom cases.

### 8.5 Principle of Storage Sharing

Variants share the underlying `Storage` class where possible:
- Base and Bounded share `Storage`
- Small uses `Storage` for spill-over

This reduces code duplication and ensures consistent memory management.

---

## 9. Conclusion

The collection primitives analyzed here demonstrate that full `~Copyable` support is achievable in Swift 6 without sacrificing API ergonomics. The key patterns are:

1. **Nested storage classes** for `~Copyable` constraint propagation
2. **Cached pointers** for property-based Span access
3. **Conditional conformances** for capability-based feature availability
4. **Method shadowing** for transparent CoW
5. **Hoisted types with typealiases** for typed throws compatibility
6. **Explicit constraint declarations** on all extensions

These patterns form a replicable framework for implementing additional collection primitives. The List primitive, currently lacking `~Copyable` support and the variant system, can be refactored following this architecture to achieve full parity with Deque, Queue, and Heap.

---

## References

- Atkinson, M.D., et al. (1986). "Min-Max Heaps and Generalized Priority Queues." *Communications of the ACM*.
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
- SE-0456: Span: Safe Access to Contiguous Storage
- Swift Institute API Naming ([API-NAME-001])
- Swift Institute API Errors ([API-ERR-001])
- Swift Institute Memory Copyable ([MEM-COPY-*])

---

*Swift Institute Collection Primitives, Layer 1*
*Document Version: 1.0.0*
*Date: 2026-01-20*
