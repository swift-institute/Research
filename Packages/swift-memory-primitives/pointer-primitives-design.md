# Pointer Primitives Design

<!--
---
version: 1.0.0
last_updated: 2026-01-26
status: DECISION
tier: 2
---
-->

## Context

While implementing `swift-pointer-primitives` for use by `swift-heap-primitives`, the question arose of what constitutes a "best-in-class" pointer primitives design. The user explicitly requested wrapper types rather than simple typealiases, indicating a desire for richer abstractions.

**Trigger**: Implementation of Pointer_Primitives for Heap storage management.

**Constraints**:
- Must support `~Copyable` pointee types (Heap stores `~Copyable` elements)
- Must follow [API-NAME-001] Nest.Name pattern
- Must not import Foundation [PRIM-FOUND-001]
- Should integrate with Index_Primitives for phantom-typed pointer arithmetic
- Should follow established patterns in swift-primitives ecosystem

## Question

What is the best-in-class architecture for Pointer_Primitives that wraps Swift's stdlib pointer types?

## Prior Art Survey

### Swift Stdlib Pointer Hierarchy

Swift organizes pointers along two orthogonal dimensions:

| Dimension | Values |
|-----------|--------|
| Mutability | Immutable (`UnsafePointer`) / Mutable (`UnsafeMutablePointer`) |
| Typing | Typed (`<T>`) / Raw (untyped) |
| Cardinality | Single / Buffer |

**Complete Type Matrix:**

| | Typed | Raw |
|---|-------|-----|
| **Immutable Single** | `UnsafePointer<T>` | `UnsafeRawPointer` |
| **Mutable Single** | `UnsafeMutablePointer<T>` | `UnsafeMutableRawPointer` |
| **Immutable Buffer** | `UnsafeBufferPointer<T>` | `UnsafeRawBufferPointer` |
| **Mutable Buffer** | `UnsafeMutableBufferPointer<T>` | `UnsafeMutableRawBufferPointer` |

### ~Copyable Support (SE-0437)

All stdlib pointer types now support `~Copyable` pointees:

```swift
struct UnsafePointer<Pointee: ~Copyable>: Copyable, ...
struct UnsafeMutablePointer<Pointee: ~Copyable>: Copyable, ...
```

Key operations for `~Copyable`:
- `move()` - Transfer ownership from pointer
- `initialize(to: consuming Pointee)` - Move-semantic initialization
- `deinitialize(count:)` - Destroy without deallocation

### ~Escapable Limitation

Pointers to `~Escapable` values are **structurally impossible**:
- A pointer is an unconstrained handle
- Acquiring a pointer to a `~Escapable` value constitutes an escape
- This is not a missing feature; it's type-theoretically incoherent

### Tagged Pattern (Tagged_Primitives)

```swift
public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _storage: RawValue

    public var rawValue: RawValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }
}
```

Used by Index_Primitives:
```swift
public typealias Index<Element: ~Copyable> = Tagged<Element, Affine.Discrete.Position>
```

### Swift Evolution Proposals

| Proposal | Relevance |
|----------|-----------|
| SE-0107 | Raw/typed pointer distinction |
| SE-0184 | Completed pointer API surface |
| SE-0334 | Alignment, property pointers, cross-type comparison |
| SE-0437 | ~Copyable support for pointers |

## Analysis

### Option 1: Namespace + Typealiases (Current)

**Approach:**
```swift
public struct Pointer<Pointee: ~Copyable>: ~Copyable {
    public typealias Mutable = Swift.UnsafeMutablePointer<Pointee>
    public typealias Immutable = Swift.UnsafePointer<Pointee>
}
```

**Advantages:**
- Zero runtime overhead
- Simple implementation
- Direct access to stdlib API
- Phantom type carries through (`Pointer<Element>.Mutable`)

**Disadvantages:**
- No opportunity to add methods or properties
- Cannot enforce additional invariants
- No integration layer for Index arithmetic
- Not a true wrapper—just naming indirection

### Option 2: Full Wrapper Structs

**Approach:**
```swift
public struct Pointer<Pointee: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _base: Swift.UnsafeMutablePointer<Pointee>

    public init(_ base: Swift.UnsafeMutablePointer<Pointee>) {
        self._base = base
    }

    // Forward all stdlib methods
    @inlinable
    public var pointee: Pointee {
        _read { yield _base.pointee }
        _modify { yield &_base.pointee }
    }

    @inlinable
    public func initialize(to value: consuming Pointee) {
        _base.initialize(to: value)
    }

    // ... many more forwarding methods
}
```

**Advantages:**
- True abstraction layer
- Can add custom methods
- Can integrate with Index arithmetic natively
- Future-proof for API extensions

**Disadvantages:**
- Large API surface to forward (~30+ methods per type)
- Maintenance burden tracking stdlib changes
- Risk of incomplete forwarding
- 8 types needed for full matrix coverage

### Option 3: Phantom-Tagged Wrappers

**Approach:**
```swift
// Use Tagged pattern from Tagged_Primitives
public typealias Pointer<Pointee: ~Copyable> =
    Tagged<Pointee, Swift.UnsafeMutablePointer<Pointee>>

// Extensions add pointer-specific behavior
extension Tagged where RawValue == Swift.UnsafeMutablePointer<Tag> {
    public var pointee: Tag {
        _read { yield rawValue.pointee }
        _modify { yield &rawValue.pointee }
    }
}
```

**Advantages:**
- Leverages existing Tagged infrastructure
- Consistent with Index pattern
- Phantom type naturally integrated
- Smaller implementation

**Disadvantages:**
- `Tag` and `Pointee` conflated (same type parameter)
- Less intuitive for pointer-specific semantics
- Extensions on Tagged may conflict with other uses
- Doesn't match mental model of "pointer to T"

### Option 4: Dimension Matrix with Nest.Name

**Approach:**
```swift
public enum Pointer {}

extension Pointer {
    public struct Typed<Pointee: ~Copyable>: ~Copyable {
        public struct Mutable: Copyable { ... }
        public struct Immutable: Copyable { ... }
    }

    public enum Raw {
        public struct Mutable: Copyable { ... }
        public struct Immutable: Copyable { ... }
    }
}

extension Pointer.Typed {
    public struct Buffer {
        public struct Mutable: ~Copyable { ... }
        public struct Immutable: ~Copyable { ... }
    }
}
```

**Usage:**
```swift
let ptr: Pointer.Typed<Element>.Mutable = ...
let rawPtr: Pointer.Raw.Mutable = ...
let buffer: Pointer.Typed<Element>.Buffer.Mutable = ...
```

**Advantages:**
- Full Nest.Name compliance
- Complete type coverage
- Clear dimensional organization
- Self-documenting API

**Disadvantages:**
- Deep nesting (`Pointer.Typed<T>.Buffer.Mutable`)
- Verbose for common cases
- 8 wrapper types to implement and maintain
- May be over-engineered for primitives layer

### Option 5: Pragmatic Hybrid

**Approach:**
```swift
// Primary types as full wrappers
public struct Pointer<Pointee: ~Copyable>: Copyable {
    public var base: Swift.UnsafeMutablePointer<Pointee>

    // Core operations forwarded
    // Index integration built-in
}

extension Pointer {
    public struct Immutable: Copyable {
        public var base: Swift.UnsafePointer<Pointee>
    }
}

// Buffer variants
extension Pointer {
    public struct Buffer: ~Copyable {
        public var base: Swift.UnsafeMutableBufferPointer<Pointee>
    }
}

extension Pointer.Buffer {
    public struct Immutable: ~Copyable {
        public var base: Swift.UnsafeBufferPointer<Pointee>
    }
}

// Raw pointers as separate namespace (non-generic)
public enum Raw {
    public struct Pointer: Copyable { ... }
    public struct MutablePointer: Copyable { ... }
    public struct Buffer: ~Copyable { ... }
    public struct MutableBuffer: ~Copyable { ... }
}
```

**Advantages:**
- Primary case (`Pointer<T>`) is the mutable typed pointer (most common)
- Nested variants follow Nest.Name
- Raw pointers separate (different use case)
- Practical balance of completeness and usability

**Disadvantages:**
- Asymmetric (mutable is default, immutable is nested)
- Still significant implementation effort
- Raw namespace introduces second top-level type

## Comparison

| Criterion | Option 1 | Option 2 | Option 3 | Option 4 | Option 5 |
|-----------|----------|----------|----------|----------|----------|
| [API-NAME-001] compliance | ✓ | ✓ | ✓ | ✓✓ | ✓ |
| Implementation effort | Low | Very High | Medium | Very High | High |
| Extensibility | ✗ | ✓✓ | ✓ | ✓✓ | ✓ |
| Index integration | ✗ | ✓✓ | ✓ | ✓✓ | ✓ |
| Ergonomics | ✓ | ✓ | ✗ | ✗ | ✓ |
| Maintenance burden | None | High | Low | Very High | Medium |
| ~Copyable support | ✓ | ✓ | ✓ | ✓ | ✓ |
| Runtime overhead | None | ~None | ~None | ~None | ~None |

## Constraints

1. **Heap's Immediate Need**: Heap only needs mutable typed single-element pointers
2. **Primitives Philosophy**: Atomic building blocks, not comprehensive frameworks
3. **Layering**: Buffer operations may belong in a higher layer (Collections)
4. **Foundation-Free**: Cannot use Foundation types

## Recommendation

**Option 5 (Pragmatic Hybrid)** with phased implementation:

### Phase 1: Core Typed Pointers (Immediate)
```swift
public struct Pointer<Pointee: ~Copyable>: Copyable {
    public var base: Swift.UnsafeMutablePointer<Pointee>
}

extension Pointer {
    public struct Immutable: Copyable {
        public var base: Swift.UnsafePointer<Pointee>
    }
}
```

### Phase 2: Buffer Variants (When Needed)
```swift
extension Pointer {
    public struct Buffer: ~Copyable { ... }
}
extension Pointer.Buffer {
    public struct Immutable: ~Copyable { ... }
}
```

### Phase 3: Raw Pointers (When Needed)
```swift
public enum Raw {
    public struct Pointer: Copyable { ... }
    // ...
}
```

### Rationale

1. **Mutable-First**: In systems code, mutable pointers are the primary case; immutable is the restriction
2. **Nest.Name**: `Pointer<T>.Immutable`, `Pointer<T>.Buffer` follow the pattern
3. **Incremental**: Start with what Heap needs, expand as required
4. **Wrapper Benefit**: Can add Index integration, safety checks, documentation
5. **Not Over-Engineered**: Primitives should be atomic, not comprehensive

### API Design

```swift
// Usage
public typealias Pointer = Pointer_Primitives.Pointer<Element>
var ptr: Pointer = ...
ptr.base.initialize(to: element)  // Access underlying pointer
let immutable: Pointer.Immutable = Pointer.Immutable(ptr.base)

// With Index integration (future)
let idx: Index<Element> = ...
let value = ptr[idx]  // Subscript via Index
```

## Implementation Notes

### Core Wrapper Structure

```swift
public struct Pointer<Pointee: ~Copyable>: Copyable, Sendable {
    /// The underlying Swift stdlib pointer.
    public var base: Swift.UnsafeMutablePointer<Pointee>

    /// Creates a pointer wrapping the given stdlib pointer.
    @inlinable
    public init(_ base: Swift.UnsafeMutablePointer<Pointee>) {
        self.base = base
    }
}
```

### Key Forwarded Operations

Priority operations to forward:
- `pointee` (read/modify)
- `initialize(to:)`, `initialize(repeating:count:)`
- `move()`, `moveInitialize(from:count:)`
- `deinitialize(count:)`
- `assign(repeating:count:)`
- Arithmetic: `advanced(by:)`, `distance(to:)`, `predecessor()`, `successor()`
- Comparison: `==`, `<`

### Index Integration

```swift
extension Pointer where Pointee: ~Copyable {
    @inlinable
    public subscript(index: Index<Pointee>) -> Pointee {
        _read { yield base[index.position] }
        _modify { yield &base[index.position] }
    }

    @inlinable
    public static func + (lhs: Self, rhs: Index<Pointee>) -> Self {
        Self(lhs.base.advanced(by: rhs.position))
    }
}
```

## Outcome

**Status**: DECISION

**Choice**: Option 5 (Pragmatic Hybrid) with architectural refinement.

**Implementation**:
- `Pointer<Pointee>` - Full wrapper struct for `UnsafeMutablePointer`
- `Pointer<Pointee>.Immutable` - Nested wrapper for `UnsafePointer`
- `Raw.Pointer.Mutable` - Wrapper for `UnsafeMutableRawPointer`
- All wrappers expose `.base` for stdlib boundary access

**Dependency Direction**:
- Pointer_Primitives depends only on Tagged_Primitives
- Index integration lives in Index_Primitives (Index is smaller domain than Pointer)
- Consumers import both and use `.base` at stdlib boundaries

**Rationale**:
Following the principle "N.M where N is larger conceptual domain than M means M depends on N":
- Pointer is a larger/more general concept
- Index is a smaller/more specific concept
- Therefore Index_Primitives should integrate with Pointer, not vice versa

**Files Created**:
- `Pointer.swift` - Main wrapper with forwarded operations
- `Pointer.Immutable.swift` - Nested immutable variant
- `Raw.swift` - Namespace for raw pointers
- `Raw.Pointer.swift` - Nested namespace
- `Raw.Pointer.Mutable.swift` - Raw pointer wrapper
- `exports.swift` - Re-exports Tagged_Primitives

## References

- [SE-0107: UnsafeRawPointer](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0107-unsaferawpointer.md)
- [SE-0184: Unsafe Pointers - Add Missing Methods](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0184-unsafe-pointers-add-missing.md)
- [SE-0334: Pointer Usability Improvements](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0334-pointer-usability-improvements.md)
- [SE-0437: Noncopyable Stdlib Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- Blog: `escapable-pointer-primitives.md` (~Escapable limitation analysis)
- Index_Primitives: Tagged phantom type pattern
