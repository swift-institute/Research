# Contiguous Memory Access Standardization

<!--
---
version: 1.0.0
last_updated: 2026-01-23
status: DECISION
tier: 3
---
-->

## Context

While implementing span access for `swift-set-primitives`, inconsistent patterns emerged across storage variants:

| Type | `span` | `mutableSpan` | `withSpan` | `withMutableSpan` | `withUnsafeBufferPointer` |
|------|--------|---------------|------------|-------------------|---------------------------|
| `Set.Ordered` | ✓ property | ✓ property | ✗ | ✗ | ✓ |
| `Set.Ordered.Bounded` | ✓ property | ✓ property | ✗ | ✗ | ✓ |
| `Set.Ordered.Small` | ✗ | ✗ | ✓ closure | ✓ closure | ✓ |
| `Set.Ordered.Inline` | ✗ | ✗ | ✓ closure | ✓ closure | ✓ |

**Trigger**: Need to establish a consistent API surface for contiguous memory access across all swift-primitives types.

**Constraints**:
- Must support `~Copyable` element types
- Must work with both heap-allocated and inline storage
- Must support C interop use cases
- Should follow [API-NAME-001] Nest.Name pattern
- Per prior research decision: ad-hoc methods, no protocol abstraction

**Precedent Risk**: HIGH - This decision establishes memory access patterns for 61+ primitives packages. Reversal requires coordinated ecosystem changes.

---

## Question

How should contiguous memory access be standardized across swift-primitives?

**Sub-questions**:
1. Should ALL types provide `span`/`mutableSpan` properties, or only heap-backed types?
2. What is the relationship between `Span` and `withUnsafeBufferPointer` for C interop?
3. Should `withUnsafeBufferPointer` be provided alongside `span`, or is it redundant?
4. What naming conventions should apply to these methods?

---

## Prior Art Survey

### Swift Standard Library (Swift 6.2)

**SE-0447: Span - Safe Access to Contiguous Storage** (Accepted):
- Introduces `Span<Element>` and `MutableSpan<Element>`
- `Span` is `Copyable` but `~Escapable` (cannot outlive source)
- `MutableSpan` is `~Copyable` and `~Escapable`
- Lifetime tied to source via `@lifetime` annotations

**SE-0456: Span-Providing Properties** (Accepted):
- Adds `.span` computed properties to stdlib types
- Types include: `Array`, `ContiguousArray`, `String`, `InlineArray`
- **Key insight**: Makes NO distinction between heap and inline storage

**SE-0453: InlineArray** (Accepted):
- `InlineArray` provides `.span` property despite inline storage
- Works because: "A value has a stable address until it is either consumed or moved. No value of any type in Swift can ever be moved while it is being borrowed or mutated."

**SE-0467: MutableSpan** (Accepted):
- Adds `.mutableSpan` properties for mutable access
- C++ `std::span<T>` (non-const) maps to `MutableSpan<T>`

### Swift C/C++ Interop

From [Swift Safe Interop Documentation](https://www.swift.org/documentation/cxx-interop/safe-interop/):

| C/C++ Annotation | Swift Overload Generated |
|------------------|-------------------------|
| `__counted_by(n)` + `__lifetimebound` | `Span<T>` |
| `__counted_by(n)` only | `UnsafeBufferPointer<T>` |
| `__sized_by(n)` + `__lifetimebound` | `RawSpan` |
| `std::span<T>` (const) | `Span<T>` |
| `std::span<T>` (non-const) | `MutableSpan<T>` |
| No annotations | Original unsafe signature |

**Key insight**: `UnsafeBufferPointer` is still generated when:
1. C API lacks lifetime annotations
2. Need to call completely unannotated C functions
3. Bridging to pre-6.2 code

### Rust

Rust's approach to memory views:

```rust
// Built-in slice types
&[T]      // immutable slice (≈ Span)
&mut [T]  // mutable slice (≈ MutableSpan)

// Traits for abstraction
trait AsRef<T: ?Sized> { fn as_ref(&self) -> &T; }
trait AsMut<T: ?Sized> { fn as_mut(&mut self) -> &mut T; }
```

**Usage patterns**:
```rust
// Generic code CAN use traits
fn process<T: AsRef<[u8]>>(data: T) { ... }

// But most code uses concrete slices
fn process(data: &[u8]) { ... }  // More common
```

**Key insight**: Despite having `AsRef<[T]>` trait, most Rust code uses concrete `&[T]` types directly. The trait exists but is not heavily used for memory view abstraction.

### C++20 Ranges

```cpp
template<typename T>
concept contiguous_range =
    random_access_range<T> &&
    contiguous_iterator<iterator_t<T>> &&
    requires(T& t) { ranges::data(t); };
```

**Key insight**: `contiguous_range` is a concept (compile-time predicate) that enables generic code. Types opt in by satisfying the requirements.

---

## Theoretical Grounding

### Lifetime Dependency Model

Swift 6.2's `@lifetime` annotation establishes borrowing relationships:

```
Γ ⊢ c : Container<E>    @lifetime(borrow c)
────────────────────────────────────────────── (T-SpanProperty)
Γ ⊢ c.span : Span<E>    lifetime(c.span) ⊆ borrow(c)
```

**Critical insight**: While a `Span` exists, the source container is *borrowed*, preventing:
- Mutation (exclusivity violation)
- Moving (would invalidate the span)
- Copying that would move storage (COW triggers copy, not move)

This means **inline storage CAN safely provide span properties** because:
1. Span creation borrows the container
2. Borrowing prevents moving
3. Therefore address is stable for span's lifetime

### Memory Access Hierarchy

```
                    Safe                          Unsafe
                     │                              │
         ┌───────────┴───────────┐      ┌──────────┴──────────┐
         │                       │      │                     │
    Span<E>              MutableSpan<E>  │                     │
    (read)                  (write)      │                     │
         │                       │      │                     │
         └───────────┬───────────┘      │                     │
                     │                  │                     │
              @lifetime enforced   UnsafeBufferPointer   UnsafeMutableBufferPointer
                     │                  │                     │
                     │                  └─────────┬───────────┘
                     │                            │
                     │                    No lifetime checking
                     │                            │
                     └────────────────────────────┘
                              Both provide:
                          - Contiguous memory view
                          - Bounds checking (span: always, UBP: debug only)
                          - Subscript access
```

### C Interop Requirements

For C interop, the function signature determines what's needed:

```swift
// C function: void process(const int* data, size_t count)
// Swift import: func process(_ data: UnsafePointer<CInt>?, _ count: Int)

// To call from Swift with Array:
array.withUnsafeBufferPointer { buffer in
    process(buffer.baseAddress, buffer.count)
}

// With annotated C (Swift 6.2+):
// C: void process(const int* __counted_by(count) __noescape data, size_t count)
// Swift overload: func process(_ data: Span<CInt>)
process(array.span)
```

**Conclusion**: `withUnsafeBufferPointer` is NOT redundant with `span`:
- `span` is for safe Swift code and annotated C APIs
- `withUnsafeBufferPointer` is for unannotated C APIs

---

## Systematic Literature Review

### Research Questions

**RQ1**: What API surface do languages provide for contiguous memory access?

**RQ2**: How do languages distinguish safe from unsafe memory access?

**RQ3**: What is the relationship between view types and C interop?

### Search Strategy

**Databases**: Swift Evolution, Swift Forums, ACM DL, Rust RFCs, C++ Standard Papers

**Keywords**: "span", "slice", "contiguous memory", "buffer pointer", "memory view", "C interop"

**Date range**: 2020-2026 (Swift 6 era through present)

### Inclusion/Exclusion Criteria

**Include**:
- Language evolution proposals for memory view types
- Standard library documentation for contiguous access
- C interop documentation

**Exclude**:
- Application-specific memory patterns
- Pre-2020 approaches (predates modern lifetime systems)

### Findings Synthesis

| Language | Safe View | Mutable View | Unsafe Escape Hatch | C Interop Primary |
|----------|-----------|--------------|---------------------|-------------------|
| Swift 6.2 | `Span<T>` | `MutableSpan<T>` | `withUnsafeBufferPointer` | UnsafeBufferPointer |
| Rust | `&[T]` | `&mut [T]` | `unsafe { }` blocks | raw pointers |
| C++20 | `std::span<T>` | `std::span<T>` | pointer arithmetic | direct |
| Go | `[]T` (slice) | `[]T` | `unsafe.Pointer` | cgo pointers |

**Key finding**: All languages provide:
1. A safe, bounds-checked view type
2. A mutable variant
3. An escape hatch for unsafe C interop

Swift is unique in having TWO parallel hierarchies:
- Safe: `Span` / `MutableSpan`
- Unsafe: `UnsafeBufferPointer` / `UnsafeMutableBufferPointer`

---

## Formal Semantics

### Type Definitions

```
Span<E>        : Copyable & ~Escapable
MutableSpan<E> : ~Copyable & ~Escapable

UnsafeBufferPointer<E>        : Copyable & Escapable
UnsafeMutableBufferPointer<E> : Copyable & Escapable
```

### Access Typing Rules

**Property-based span access**:

```
Γ ⊢ c : T    T has span: Span<E>
────────────────────────────────── (T-SpanProp)
Γ ⊢ c.span : Span<E>
borrow(c) active while c.span in scope
```

**Closure-based unsafe access**:

```
Γ ⊢ c : T    T has withUnsafeBufferPointer
Γ, buf : UnsafeBufferPointer<E> ⊢ body : R
───────────────────────────────────────────── (T-WithUBP)
Γ ⊢ c.withUnsafeBufferPointer(body) : R
```

### Soundness Argument

**Claim**: Property-based span access is memory-safe for both heap and inline storage.

**Proof sketch**:
1. `Span<E>` is `~Escapable`, so it cannot be stored or returned
2. While `span` exists, container is borrowed (exclusivity)
3. Borrowed values cannot be moved or mutated
4. Therefore: span's memory address remains stable
5. Bounds are checked at access time
6. Conclusion: no use-after-free, no out-of-bounds ∎

**For inline storage specifically**:
- Step 3 is critical: borrowing prevents the containing struct from moving
- The `@lifetime(borrow self)` annotation enforces this

---

## Analysis

### Option 1: Uniform span/mutableSpan Properties

**Description**: ALL types provide `span` and `mutableSpan` properties, regardless of storage strategy.

```swift
// Heap storage (existing)
extension Set.Ordered {
    var span: Span<Element> { ... }
    var mutableSpan: MutableSpan<Element> { ... }
}

// Inline storage (proposed addition)
extension Set.Ordered.Inline {
    var span: Span<Element> { ... }      // NEW
    var mutableSpan: MutableSpan<Element> { ... }  // NEW
}
```

**Advantages**:
- Consistent API across all types
- Matches Swift stdlib pattern (InlineArray has `.span`)
- No need to remember which types use properties vs closures
- Generic code can use `.span` on any container

**Disadvantages**:
- Requires `@lifetime` annotation (experimental in 6.2)
- May surprise users expecting closure for inline storage

### Option 2: Keep Current Split (Property vs Closure)

**Description**: Maintain heap→property, inline→closure distinction.

```swift
// Heap storage: property
var span: Span<Element> { ... }

// Inline storage: closure
func withSpan<R>(_ body: (Span<Element>) -> R) -> R { ... }
```

**Advantages**:
- No change to existing code
- Explicit about address stability concerns

**Disadvantages**:
- Inconsistent API surface
- Contradicts Swift stdlib pattern (InlineArray has `.span` property)
- Makes generic programming harder
- Based on outdated understanding of `@lifetime`

### Option 3: Provide Both Property AND Closure

**Description**: All types provide both `span` property AND `withSpan` closure.

```swift
extension Set.Ordered.Inline {
    var span: Span<Element> { ... }
    func withSpan<R>(_ body: (Span<Element>) -> R) -> R { ... }
}
```

**Advantages**:
- Maximum flexibility
- Backward compatible

**Disadvantages**:
- Redundant API surface
- Confusing: "which should I use?"
- Violates DRY principle

### withUnsafeBufferPointer Decision

**Question**: Should types provide `withUnsafeBufferPointer` alongside `span`?

**Analysis**:

| Use Case | `span` Sufficient? | `withUnsafeBufferPointer` Needed? |
|----------|-------------------|----------------------------------|
| Swift-only code | ✓ | No |
| Annotated C API | ✓ | No |
| Unannotated C API | ✗ | **Yes** |
| Pre-Swift 6.2 libraries | ✗ | **Yes** |
| Performance-critical (debug bounds) | ✗ | **Yes** |

**Conclusion**: `withUnsafeBufferPointer` is NOT redundant. It serves distinct purposes:
1. C interop with unannotated APIs
2. Interop with pre-6.2 code expecting UnsafeBufferPointer
3. Opting out of debug bounds checking (rare but valid)

### Comparison Table

| Criterion | Option 1 (Uniform) | Option 2 (Split) | Option 3 (Both) |
|-----------|-------------------|------------------|-----------------|
| API consistency | ✓✓ | ✗ | ✓ |
| Matches stdlib | ✓✓ | ✗ | ✓ |
| Simplicity | ✓ | ✓ | ✗ |
| Generic programming | ✓✓ | ✗ | ✓ |
| No redundancy | ✓ | ✓ | ✗ |
| Implementation effort | Medium | None | High |

---

## Empirical Validation (Cognitive Dimensions)

| Dimension | Option 1 (Uniform) | Option 2 (Split) |
|-----------|-------------------|------------------|
| **Visibility** | High - same API everywhere | Low - must know storage type |
| **Consistency** | High - one pattern | Low - two patterns |
| **Viscosity** | Low - easy to switch types | Medium - may need API changes |
| **Role-expressiveness** | High - `.span` = memory view | Medium - closure implies scoping |
| **Error-proneness** | Low - consistent | Medium - wrong API for type |
| **Abstraction** | Appropriate | Over-specific |

---

## Proposed Standard API Surface

Based on analysis, **Option 1 (Uniform span/mutableSpan properties)** with `withUnsafeBufferPointer` for C interop:

### Required Methods

| Method | Purpose | When Provided |
|--------|---------|---------------|
| `var span: Span<Element>` | Safe read access | All contiguous types |
| `var mutableSpan: MutableSpan<Element>` | Safe write access | All mutable contiguous types |
| `withUnsafeBufferPointer(_:)` | C interop escape hatch | All contiguous types |
| `withUnsafeMutableBufferPointer(_:)` | Mutable C interop | All mutable contiguous types |

### Naming Convention

Per [API-NAME-002], no compound names. The names above are already compliant:
- `span` - single word ✓
- `mutableSpan` - describes what it is (a mutable span) ✓
- `withUnsafeBufferPointer` - matches stdlib ✓

### Implementation Requirements

```swift
// All types MUST provide:
extension Container {
    /// Safe, bounds-checked read access to contiguous storage.
    @_lifetime(borrow self)
    var span: Span<Element> { get }

    /// Safe, bounds-checked write access to contiguous storage.
    @_lifetime(&self)
    var mutableSpan: MutableSpan<Element> { mutating get }

    /// Unsafe access for C interop with unannotated APIs.
    func withUnsafeBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R

    /// Mutable unsafe access for C interop.
    mutating func withUnsafeMutableBufferPointer<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R
}
```

### Migration Path

For types currently using `withSpan` closure pattern:

1. Add `span` property with `@lifetime(borrow self)`
2. Deprecate `withSpan` with fixup to use property
3. Remove `withSpan` in next major version

---

## Outcome

**Status**: DECISION

**Decision**: Option 1 - Uniform span/mutableSpan properties for ALL types

### Experimental Validation

Experiment `inline-span-property` (2026-01-23) confirmed:

```
Test 1: InlineArray provides .span property
  InlineArray count: 4
  Span count: 4
  ✅ InlineArray.span works as property (not closure)

Test 3: MutableSpan on inline storage
  After mutation: [100, 200, 3, 4]
  ✅ MutableSpan on inline storage works

Test 4: Array (heap) also provides .span property
  ✅ Both inline (InlineArray) and heap (Array) use same .span API
```

**Key finding**: Swift stdlib's `InlineArray` (inline storage) and `Array` (heap storage) BOTH provide `.span` as a computed property, not a closure. The API is uniform regardless of storage strategy.

### Rationale

1. **Swift stdlib validated**: InlineArray.span proves inline storage can safely provide span properties
2. **@lifetime enforced**: Borrowing prevents container movement while span exists
3. **API consistency**: Users don't need to know storage implementation details
4. **C interop covered**: `withUnsafeBufferPointer` remains for unannotated C APIs

### Standard API Surface

All contiguous storage types in swift-primitives MUST provide:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `span` | `var span: Span<Element> { get }` | Safe read access |
| `mutableSpan` | `var mutableSpan: MutableSpan<Element> { mutating get }` | Safe write access |
| `withUnsafeBufferPointer` | `func withUnsafeBufferPointer<R>(_: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R` | C interop |
| `withUnsafeMutableBufferPointer` | `mutating func withUnsafeMutableBufferPointer<R>(_: (inout UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R` | Mutable C interop |

### Migration Required

Types currently using closure-based span access:
- `Set.Ordered.Small` - change `withSpan` to `span` property
- `Set.Ordered.Inline` - change `withSpan` to `span` property

### Implementation Notes

1. Requires Swift 6.2+ with `Lifetimes` experimental feature
2. Use `@_lifetime(borrow self)` for `span` getter
3. Use `@_lifetime(&self)` for `mutableSpan` getter
4. `withUnsafeBufferPointer` is NOT redundant - needed for unannotated C APIs

**Decision date**: 2026-01-23

---

## References

- [SE-0447: Span - Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [SE-0456: Span-Providing Properties](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md)
- [SE-0453: InlineArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md)
- [SE-0467: MutableSpan](https://forums.swift.org/t/se-0467-mutablespan/78454)
- [Swift Safe C/C++ Interop](https://www.swift.org/documentation/cxx-interop/safe-interop/)
- [Property Lifetimes (atrick gist)](https://gist.github.com/atrick/9409356c89a5f67dd9f68f708f57262e)
- [Rust AsRef Trait](https://doc.rust-lang.org/std/convert/trait.AsRef.html)
- [C++20 contiguous_range](https://en.cppreference.com/w/cpp/ranges/contiguous_range)
- Kitchenham, B. (2004). Procedures for Performing Systematic Reviews
