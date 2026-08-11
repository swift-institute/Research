# Supporting ~Copyable Elements in Hash-Based Collections
<!--
---
version: 1.0.0
last_updated: 2026-03-16
status: IN_PROGRESS
---
-->

## Abstract

Swift's `Hashable` protocol implicitly requires `Copyable` conformance, preventing the use of move-only types as dictionary keys or set elements. This document presents a comprehensive architecture for supporting `~Copyable` elements in hash-based collections through a new `Hash.Protocol` that uses borrowing semantics, a module boundary pattern to prevent constraint poisoning, and a unified approach across the swift-primitives ecosystem.

## 1. Problem Statement

### 1.1 The Hashable-Copyable Coupling

In Swift's standard library, `Hashable` inherits from `Equatable`, and both protocols have method signatures that implicitly require `Copyable`:

```swift
// Swift.Equatable - implicit Copyable requirement
public protocol Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool  // Parameters are copied
}

// Swift.Hashable - inherits Equatable's Copyable requirement
public protocol Hashable: Equatable {
    func hash(into hasher: inout Hasher)
}
```

This coupling means that any type used as a `Set` element or `Dictionary` key must be `Copyable`. Move-only types like file handles, unique tokens, or linear resources cannot participate in hash-based collections.

### 1.2 The Constraint Poisoning Problem

Even when defining custom protocols with `~Copyable` support, conformances to protocols that require `Copyable` (like `Sequence` or `Collection`) can "poison" the generic constraints:

```swift
// This extension adds Sequence conformance
extension Set.Ordered: Sequence where Element: Copyable { ... }

// But now ANY code that sees Set.Ordered in a Sequence context
// will infer Element: Copyable, even for unrelated operations
```

This poisoning propagates through the type system, making it impossible to use the same type definition for both `Copyable` and `~Copyable` elements.

### 1.3 Current Limitations

The existing swift-primitives packages face these constraints:

| Package | Current Constraint | Limitation |
|---------|-------------------|------------|
| swift-set-primitives | `Element: Hashable` | No ~Copyable elements |
| swift-dictionary-primitives | `Key: Hashable, Value: ~Copyable` | No ~Copyable keys |
| swift-array-primitives | `Element: ~Copyable` | Full support (no hashing needed) |

## 2. Solution Architecture

### 2.1 Hash.Protocol: A Hashable Fork

The foundation is `Hash.Protocol` in swift-hash-primitives, which mirrors `Hashable` but uses `borrowing` parameter semantics:

```swift
extension Hash {
    public protocol `Protocol`: ~Copyable {
        /// Equality using borrowing semantics - no copy required
        static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool

        /// Hashing using borrowing semantics - no copy required
        borrowing func hash(into hasher: inout Hasher)
    }
}
```

Key differences from `Swift.Hashable`:
- Explicitly supports `~Copyable` via the `: ~Copyable` constraint suppression
- Uses `borrowing` parameters to enable comparison without consumption
- Provides `hashValue` computed property via default implementation

### 2.2 Bridging Swift.Hashable Types

All standard library `Hashable` types automatically satisfy `Hash.Protocol` requirements because their existing `==` and `hash(into:)` methods are compatible:

```swift
// In Hash Primitives
extension Int: Hash.`Protocol` {}
extension String: Hash.`Protocol` {}
extension Bool: Hash.`Protocol` {}
// ... all Hashable types
```

This ensures backward compatibility - existing `Hashable` types work with the new protocol.

### 2.3 The Module Boundary Solution

To prevent constraint poisoning, types are split across module boundaries:

```
Package/
├── Sources/
│   ├── Core/              # Type definitions with ~Copyable support
│   │   └── Element: Hash.Protocol & ~Copyable
│   ├── Sequence/          # Conformances requiring Copyable
│   │   └── extension Type: Sequence where Element: Copyable
│   └── Public/            # Re-exports both modules
│       └── @_exported import Core
│       └── @_exported import Sequence
```

**Why this works:**
- The `Core` module defines types with `Element: Hash.Protocol & ~Copyable`
- The `Sequence` module imports `Core` and adds conformances with `where Element: Copyable`
- The conformances are in a *separate compilation unit*, so they cannot poison the Core type definitions
- Users import the `Public` module and get everything

### 2.4 Ownership Semantics in Set Operations

With `~Copyable` elements, set operations must use explicit ownership:

| Operation | Ownership | Rationale |
|-----------|-----------|-----------|
| `contains(_:)` | `borrowing Element` | Only needs to check membership |
| `insert(_:)` | `consuming Element` | Takes ownership if inserted |
| `remove(_:)` | `borrowing Element` | Lookup key is borrowed, removed element is returned |
| `forEach(_:)` | `(borrowing Element) -> Void` | Iteration borrows elements |
| `drain(_:)` | `(consuming Element) -> Void` | Consuming iteration |

Example implementation:

```swift
/// Check membership using borrowing - element is not consumed
borrowing func contains(_ element: borrowing Element) -> Bool {
    let targetHash = element.hashValue
    for i in 0..<_count {
        if storage[i].hashValue == targetHash && storage[i] == element {
            return true
        }
    }
    return false
}

/// Insert using consuming - element is consumed if new, destroyed if duplicate
mutating func insert(_ element: consuming Element) -> Bool {
    let targetHash = element.hashValue
    for i in 0..<_count {
        if storage[i].hashValue == targetHash && storage[i] == element {
            _ = consume element  // Duplicate - consume and discard
            return false
        }
    }
    // New element - take ownership
    storage.advanced(by: _count).initialize(to: element)
    _count += 1
    return true
}
```

## 3. Implementation Considerations

### 3.1 Index Lookup Complexity

The current `Set.Ordered` uses `[Element: Int]` (Swift Dictionary) for O(1) index lookup. This requires `Element: Hashable`, which implies `Copyable`.

**Options for ~Copyable support:**

| Approach | Complexity | Trade-off |
|----------|------------|-----------|
| Linear scan with hash comparison | O(n) | Simple, correct, slower |
| Custom hash table with UnsafePointer | O(1) | Complex, requires careful memory management |
| Conditional: Dict when Copyable, scan otherwise | O(1) / O(n) | Complex API surface |

For initial implementation, linear scan with hash comparison provides correctness:

```swift
// O(n) but works with ~Copyable
func index(_ element: borrowing Element) -> Int? {
    let targetHash = element.hashValue
    for i in 0..<count {
        if storage[i].hashValue == targetHash && storage[i] == element {
            return i
        }
    }
    return nil
}
```

The hash comparison acts as a fast-path filter (cheap Int comparison before expensive equality).

### 3.2 Copy-on-Write Considerations

Copy-on-Write (CoW) only applies when `Element: Copyable`:

```swift
// CoW requires copying elements - only valid for Copyable
extension Set.Ordered where Element: Copyable {
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_elementStorage) {
            _elementStorage = _elementStorage.copy()
        }
    }
}

// For ~Copyable elements, storage is always unique (no sharing)
extension Set.Ordered where Element: ~Copyable {
    // No CoW - moves only
}
```

### 3.3 Conditional Copyability

The set container itself can be conditionally `Copyable`:

```swift
// Copyable when elements are Copyable (allows CoW)
extension Set.Ordered: Copyable where Element: Copyable {}

// Inline/Small variants are always ~Copyable due to deinit requirement
// (they have custom deinitializers for cleanup)
```

## 4. Dependency Graph

### 4.1 Current Dependencies

```
swift-hash-primitives
    ├── swift-bit-primitives (for Bit: Hash.Protocol)
    ├── swift-comparison-primitives
    └── swift-property-primitives

swift-set-primitives
    ├── swift-hash-primitives (NEW)
    ├── swift-bit-primitives
    ├── swift-index-primitives
    └── swift-collection-primitives

swift-dictionary-primitives
    ├── swift-set-primitives (uses Set.Ordered for keys)
    ├── swift-index-primitives
    └── swift-collection-primitives
```

### 4.2 The Dictionary Question

Currently, `swift-dictionary-primitives` uses:
- `Key: Hashable` (implies Copyable)
- `Value: ~Copyable` (move-only values supported)

To support `~Copyable` keys, dictionary-primitives should also adopt `Hash.Protocol`:

```swift
// Current
public enum Dictionary<Key: Hashable, Value: ~Copyable>: ~Copyable

// Proposed
public enum Dictionary<Key: Hash.`Protocol` & ~Copyable, Value: ~Copyable>: ~Copyable
```

**However**, dictionary-primitives currently depends on set-primitives for key storage:

```swift
// In Dictionary.Ordered
var _keys: Set<Key>.Ordered  // Uses set-primitives
```

This creates a coordination requirement:
1. set-primitives must migrate to `Hash.Protocol` first
2. dictionary-primitives can then adopt the same constraint
3. Both packages need module splits to avoid constraint poisoning

### 4.3 Circular Dependency Considerations

The dependency chain is:
```
hash-primitives → bit-primitives (Bit: Hash.Protocol conformance)
set-primitives → hash-primitives
dictionary-primitives → set-primitives
```

This is acyclic and well-ordered. The `Bit: Hash.Protocol` conformance lives in hash-primitives (which already depends on bit-primitives), avoiding any circularity.

## 5. Migration Path

### Phase 1: Hash.Protocol Foundation (Complete)
- [x] Create `Hash.Protocol` in swift-hash-primitives
- [x] Bridge all `Hashable` standard library types
- [x] Add `Bit: Hash.Protocol` conformance
- [x] Validate with experiment

### Phase 2: Set Primitives Migration (In Progress)
- [x] Update Package.swift with module split (Core/Sequence/Public)
- [x] Add hash-primitives dependency
- [ ] Update `Set<Element: Hashable>` to `Set<Element: Hash.Protocol & ~Copyable>`
- [ ] Rewrite Set.Ordered without Dictionary-based index lookup
- [ ] Update ownership semantics (borrowing/consuming)
- [ ] Move Sequence/Collection conformances to Sequence module
- [ ] Update variant types (Fixed, Inline, Small)
- [ ] Update tests

### Phase 3: Dictionary Primitives Migration
- [ ] Update Package.swift with module split
- [ ] Change `Key: Hashable` to `Key: Hash.Protocol & ~Copyable`
- [ ] Update key storage (currently uses Set.Ordered)
- [ ] Update ownership semantics for keys
- [ ] Move Sequence/Collection conformances
- [ ] Update tests

### Phase 4: Documentation and Stabilization
- [ ] Update API documentation
- [ ] Add migration guide for users
- [ ] Performance benchmarks
- [ ] Consider custom hash table for O(1) lookup

## 6. API Impact

### 6.1 Breaking Changes

Users will need to update their code:

```swift
// Before: Element must be Hashable (Copyable)
struct Token: Hashable { let id: Int }
var set = Set<Token>.Ordered()

// After: Element can be Hash.Protocol (supports ~Copyable)
struct Token: Hash.`Protocol` {
    let id: Int
    static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.id == rhs.id
    }
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
var set = Set<Token>.Ordered()
```

For existing `Hashable` types, the migration is minimal since the bridge conformances make them automatically satisfy `Hash.Protocol`.

### 6.2 New Capabilities

```swift
// Now possible: ~Copyable set elements
struct FileHandle: ~Copyable, Hash.`Protocol` {
    let fd: Int32
    static func == (lhs: borrowing FileHandle, rhs: borrowing FileHandle) -> Bool {
        lhs.fd == rhs.fd
    }
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(fd)
    }
    deinit { close(fd) }
}

var handles = Set<FileHandle>.Ordered()
handles.insert(FileHandle(fd: open("/tmp/a", O_RDONLY)))
handles.insert(FileHandle(fd: open("/tmp/b", O_RDONLY)))

// Borrowing iteration - handles are not consumed
handles.forEach { handle in
    print("FD: \(handle.fd)")
}

// Consuming iteration - handles are moved out and closed
handles.drain { handle in
    // handle is consumed here, deinit runs after
}
```

## 7. Complexity Analysis

### 7.1 Time Complexity Changes

| Operation | Before (Dictionary) | After (Linear Scan) |
|-----------|--------------------|--------------------|
| `contains` | O(1) average | O(n) |
| `insert` | O(1) average | O(n) |
| `remove` | O(n)* | O(n) |
| `index(_:)` | O(1) average | O(n) |
| `element(at:)` | O(1) | O(1) |

*Remove was already O(n) due to element shifting.

### 7.2 Space Complexity Changes

| Aspect | Before | After |
|--------|--------|-------|
| Per-element overhead | ~24 bytes (Dictionary entry) | 0 bytes |
| Total overhead | O(n) for index dictionary | O(1) |

The linear scan approach trades time for space and simplicity.

### 7.3 Future Optimization Path

A custom hash table using `UnsafeMutablePointer<Int>` for indices could restore O(1) lookup:

```swift
// Conceptual custom hash table for ~Copyable keys
struct HashTable<Key: Hash.`Protocol` & ~Copyable> {
    // Stores indices into the element array, not keys
    private var buckets: UnsafeMutablePointer<Int?>
    private var bucketCount: Int

    func index(for element: borrowing Key) -> Int? {
        let hash = element.hashValue
        let bucket = hash % bucketCount
        // Probe and compare with actual elements in storage
    }
}
```

This optimization can be added later without changing the public API.

## 8. Conclusion

Supporting `~Copyable` elements in hash-based collections requires:

1. **Protocol redesign**: `Hash.Protocol` with `borrowing` semantics
2. **Module boundaries**: Core/Sequence split to prevent constraint poisoning
3. **Ownership clarity**: Explicit `borrowing`/`consuming` in APIs
4. **Complexity trade-offs**: O(n) linear scan vs O(1) custom hash table

The swift-primitives ecosystem is well-positioned for this migration due to its modular architecture and existing patterns from swift-array-primitives and swift-comparison-primitives.

This refactor enables a new class of use cases where unique, non-copyable resources can participate in set membership and dictionary keying - a capability not available in Swift's standard library.

## References

- Swift Evolution SE-0390: Noncopyable structs and enums
- Swift Evolution SE-0427: Noncopyable generics
- swift-primitives Memory Copyable documentation
- swift-array-primitives module split implementation
