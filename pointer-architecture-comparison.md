# Pointer Architecture Comparison

<!--
---
version: 1.0.0
last_updated: 2026-01-28
status: DECISION
tier: 3
---
-->

## Context

Swift Institute is refactoring `swift-memory-primitives` and `swift-pointer-primitives` to provide typed arithmetic, non-null guarantees, and provenance-correct empty buffers. Before finalizing the design, we need to understand how Swift's stdlib implements its native pointer types and whether there are special compiler treatments we must account for.

**Trigger**: Ongoing refactoring of memory and pointer primitives raised the question of whether Swift's pointers receive special compiler treatment that our wrappers cannot replicate.

**Constraints**:
- Must maintain zero runtime overhead
- Must support ~Copyable types
- Must be Swift 6.2+ strict memory safety compliant
- Must not duplicate compiler-level safety mechanisms

**Scope**: Ecosystem-wide—affects primitives layer and all dependent packages.

## Question

Does Swift treat its native pointer types (`UnsafePointer`, `UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeMutableRawPointer`) as special compiler-level primitives, or are they regular Swift types? What implications does this have for the design of `swift-memory-primitives` and `swift-pointer-primitives`?

---

## Prior Art Survey

### Swift Stdlib Implementation

**Source**: `/swiftlang/swift/stdlib/public/core/UnsafePointer.swift`, `UnsafeRawPointer.swift`, `Pointer.swift`

Swift's pointer types are **regular `@frozen` structs**, not compiler-special-cased primitives:

```swift
// UnsafePointer.swift:206-221
@frozen @unsafe
public struct UnsafePointer<Pointee: ~Copyable>: Copyable {
  @_preInverseGenerics
  @safe
  public let _rawValue: Builtin.RawPointer

  @_transparent
  @_preInverseGenerics
  public init(_ _rawValue: Builtin.RawPointer) {
    self._rawValue = _rawValue
  }
}
```

All four pointer types store a single `Builtin.RawPointer` field and delegate operations to the `Builtin` module.

### The Builtin Module

**Source**: `/swiftlang/swift/include/swift/AST/Builtins.def`

The "magic" resides entirely in `Builtin`, a compiler-provided namespace:

| Builtin Operation | Purpose |
|-------------------|---------|
| `Builtin.gep_Word` | Typed pointer arithmetic (address + n × stride) |
| `Builtin.gepRaw_Word` | Raw byte-offset arithmetic |
| `Builtin.bindMemory` | Associate memory region with type |
| `Builtin.rebindMemory` | Restore previous type binding |
| `Builtin.initialize` | Write value to uninitialized memory |
| `Builtin.copyArray` | Bulk copy operation |
| `Builtin.ptrtoint_Word` | Pointer-to-integer conversion |
| `Builtin.inttoptr_Word` | Integer-to-pointer conversion |

These are SIL-level operations, not LLVM builtins. The compiler tracks memory bindings for strict aliasing optimization.

### Rust Comparison

Rust's pointer model provides relevant prior art:

| Rust Concept | Swift Equivalent | Primitives Equivalent |
|--------------|------------------|----------------------|
| `*const T` | `UnsafePointer<T>` | `Pointer<T>` |
| `*mut T` | `UnsafeMutablePointer<T>` | `Pointer<T>.Mutable` |
| `NonNull<T>` | None (optional) | `Memory.Address` |
| Pointer provenance | Strict aliasing | Sentinel-backed empty buffers |

Rust's `NonNull<T>` is particularly relevant—it guarantees non-null at the type level, which Swift lacks but our primitives provide.

### Academic Literature

**Affine Types**: Memory primitives' typed index system aligns with affine type theory, where values can be used at most once. The `Index<T>.Offset` vs `Index<T>.Count` distinction prevents category errors through phantom typing.

**Provenance**: Memarian et al. (2019), "Exploring C Semantics and Pointer Provenance," establishes that manufactured pointers (e.g., from integer literals) violate provenance rules. Swift 6.2+ strict memory safety will likely enforce similar constraints, validating our sentinel-based empty buffer design.

---

## Theoretical Grounding

### Type-Theoretic Analysis

**Swift Stdlib Pointer Typing**:
```
UnsafePointer<T> : Type
  where T : ~Copyable

_rawValue : Builtin.RawPointer
advanced(by: Int) → UnsafePointer<T>
distance(to: UnsafePointer<T>) → Int
subscript(Int) → T
```

The typing is straightforward but **untyped at the index level**—`Int` carries no domain information.

**Primitives Pointer Typing**:
```
Pointer<T> = Tagged<T, Memory.Address>
  where T : ~Copyable

Memory.Address = Tagged<Memory, Ordinal>
Index<T> : Type
Index<T>.Offset = Tagged<T, Affine.Discrete.Vector>
Index<T>.Count = Tagged<T, Cardinal>

advanced(by: Index<T>.Offset) → Pointer<T>
distance(to: Pointer<T>) → Index<T>.Offset
subscript(Index<T>) → T
```

The phantom type `T` in `Index<T>` creates a **domain-separated index space**. Operations between incompatible domains fail at compile time.

### Category-Theoretic Perspective

The distinction between `Count`, `Offset`, and `Ratio` reflects a categorical structure:

| Type | Category | Composition |
|------|----------|-------------|
| `Index<T>` | Object (position) | Identity |
| `Index<T>.Count` | Cardinal (magnitude) | Addition |
| `Index<T>.Offset` | Vector (displacement) | Addition, scaling |
| `Ratio<T, U>` | Morphism (stride) | Composition |

A `Ratio<Int, UInt8>` represents the morphism from `Int`-space to `UInt8`-space (4 bytes per Int). This categorical clarity prevents the semantic confusion that stdlib's untyped `Int` permits.

### Affine Type Integration

The primitives leverage affine type semantics for memory safety:

```
Memory.Address : Affine.Point
Memory.Address.Offset : Affine.Vector

Point + Vector → Point    ✓ (advance)
Point - Point → Vector    ✓ (distance)
Vector + Vector → Vector  ✓ (combine offsets)
Point + Point → ???       ✗ (undefined)
```

This prevents meaningless operations like adding two addresses.

---

## Analysis

### Option 1: Mirror Stdlib Exactly

**Approach**: Create typealiases to stdlib pointers with no additional abstractions.

**Structure**:
```swift
public typealias Pointer<T> = UnsafePointer<T>
public typealias MutablePointer<T> = UnsafeMutablePointer<T>
```

**Advantages**:
- Zero learning curve
- Guaranteed identical behavior
- No wrapper overhead

**Disadvantages**:
- No non-null guarantees
- No typed index safety
- Empty buffers still use nil baseAddress
- No semantic distinction between Count/Offset/Ratio

**Assessment**: Rejected—provides no value over using stdlib directly.

### Option 2: Thin Wrappers with Typed Arithmetic (Current Design)

**Approach**: Wrap stdlib pointers, add phantom-typed indices, enforce non-null.

**Structure**:
```swift
public typealias Pointer<T> = Tagged<T, Memory.Address>
public typealias Memory.Address = Tagged<Memory, Ordinal>

// Typed arithmetic
func advanced(by: Index<T>.Offset) → Pointer<T>
func distance(to:) → Index<T>.Offset
subscript(Index<T>) → T
```

**Advantages**:
- Non-null guarantees at type level
- Compile-time prevention of index category errors
- Provenance-correct empty buffers
- Semantic distinction Count/Offset/Ratio
- Zero runtime overhead (all inlined)

**Disadvantages**:
- Learning curve for typed indices
- Additional import required
- Cannot intercept compiler builtins (bindMemory, etc.)

**Assessment**: Selected—provides meaningful safety improvements without performance cost.

### Option 3: Complete Reimplementation

**Approach**: Implement pointers from scratch without using stdlib types.

**Structure**:
```swift
public struct Pointer<T: ~Copyable>: ~Copyable {
  let bits: UInt
  // Reimplement all operations
}
```

**Advantages**:
- Complete control over semantics
- Could enforce additional invariants

**Disadvantages**:
- Cannot access `Builtin` module (compiler-internal)
- Would lose SIL-level memory binding tracking
- Would lose strict aliasing optimization opportunities
- Massive implementation effort for no gain

**Assessment**: Rejected—impossible to match stdlib's compiler integration.

### Comparison

| Criterion | Option 1: Mirror | Option 2: Wrappers | Option 3: Reimplement |
|-----------|------------------|--------------------|-----------------------|
| Non-null guarantee | ✗ | ✓ | ✓ |
| Typed indices | ✗ | ✓ | ✓ |
| Provenance-correct | ✗ | ✓ | ✓ |
| Memory binding tracking | ✓ | ✓ | ✗ |
| Strict aliasing optimization | ✓ | ✓ | ✗ |
| Zero runtime overhead | ✓ | ✓ | ? |
| Implementation feasibility | ✓ | ✓ | ✗ |

---

## Key Technical Findings

### Finding 1: Pointers Are Not Compiler Magic

Swift's pointer types are regular structs. The compiler provides no special syntax or treatment beyond what any `@frozen` struct receives. This means wrapper types can achieve identical performance.

### Finding 2: Builtin Operations Are Inaccessible

The `Builtin` module is compiler-internal and cannot be imported by user code. This means:
- We cannot implement our own `gep` operations
- We must delegate to stdlib for arithmetic
- Memory binding tracking happens automatically through stdlib calls

This is acceptable because stdlib's operations are correct; we only need to add type-level safety on top.

### Finding 3: Provenance Will Become Stricter

Swift 6.2+ strict memory safety will likely reject manufactured pointers (e.g., `UnsafeRawPointer(bitPattern: 0x1000)!`). Our sentinel-based empty buffer design is future-proof:

```swift
// Manufactured pointer (may violate provenance)
let manufactured = UnsafeRawPointer(bitPattern: 0x1000)!  // ⚠️

// Provenance-correct sentinel
private let _sentinel = UnsafeMutableRawPointer.allocate(
  byteCount: 1, alignment: 4096)
let sentinel = Memory.Address(pointer: _sentinel)  // ✓
```

### Finding 4: Typed Indices Prevent Category Errors

Stdlib permits semantically nonsensical operations:

```swift
// Stdlib allows this:
let count = ptr.distance(to: end)  // Returns Int
let newPtr = ptr.advanced(by: count * 2)  // count is a distance, not a scalar!
```

Primitives catch this at compile time:

```swift
let offset: Index<T>.Offset = ptr.distance(to: end)
let scaled = offset * 2  // Type error: Offset × Int → ???
// Must use: offset.scaled(by: 2) → Offset
```

### Finding 5: Stride Is a Ratio, Not a Count

A stride (bytes per element) is semantically a ratio between two unit systems:

```swift
// Wrong semantic:
stride: Index<UInt8>.Count  // "How many bytes?"

// Correct semantic:
stride: Affine.Discrete.Ratio<Element, UInt8>  // "Bytes per Element"
```

This distinction enables type-safe stride composition and prevents unit confusion.

---

## Outcome

**Status**: DECISION

**Choice**: Option 2 (Thin Wrappers with Typed Arithmetic)

**Rationale**:

1. **Swift pointers are not magic**. They are regular structs wrapping `Builtin.RawPointer`. Wrappers incur no performance penalty because all operations inline completely.

2. **Compiler integration is preserved**. By delegating to stdlib pointers, we retain memory binding tracking and strict aliasing optimization—features that require SIL-level compiler support.

3. **Type-level safety adds real value**. The three key innovations—non-null guarantees, typed indices, and provenance-correct sentinels—prevent entire categories of bugs that stdlib cannot express.

4. **The design is future-proof**. Swift 6.2+ strict memory safety will validate our provenance-correct approach to empty buffers.

**Implementation Guidance**:

1. `Memory.Address` wraps stdlib pointers, stores bit pattern as `Ordinal` (UInt)
2. `Pointer<T>` is `Tagged<T, Memory.Address>` (phantom-typed)
3. All arithmetic uses `Index<T>.Offset`, not raw `Int`
4. Empty buffers use allocated sentinel, never nil
5. All operations delegate to stdlib for actual memory operations

**Scope Boundaries**:

| Our Responsibility | Stdlib Responsibility |
|-------------------|----------------------|
| Non-null invariants | Memory binding (SIL) |
| Typed index arithmetic | Strict aliasing optimization |
| Provenance-correct sentinels | Bulk operation codegen |
| Semantic type distinctions | Builtin operations |

---

## References

### Swift Sources
- `/swiftlang/swift/stdlib/public/core/UnsafePointer.swift`
- `/swiftlang/swift/stdlib/public/core/UnsafeRawPointer.swift`
- `/swiftlang/swift/stdlib/public/core/Pointer.swift`
- `/swiftlang/swift/include/swift/AST/Builtins.def`

### Related Research
- Memarian, K., et al. (2019). "Exploring C Semantics and Pointer Provenance." POPL 2019.
- Wadler, P. (1990). "Linear Types Can Change the World!" Programming Concepts and Methods.

### Cross-References
- [API-NAME-001] Namespace Structure (nested type pattern)
- [PRIM-FOUND-001] No Foundation (primitives cannot import Foundation)
- [MEM-COPY-*] ~Copyable type handling

### Internal Documents
- `swift-memory-primitives/Research/` (package-specific decisions)
- `swift-pointer-primitives/Research/` (package-specific decisions)
