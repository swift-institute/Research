# Comparative Analysis: swift-stack-primitives vs Industry Stack Implementations
<!--
---
version: 1.0.0
last_updated: 2026-03-16
status: RECOMMENDATION
---
-->

## Executive Summary

This analysis compares `swift-stack-primitives` against stack implementations in Rust, C++, Zig, Go, and Swift's standard library. The goal is to identify gaps and opportunities for improvement.

**Overall Assessment**: swift-stack-primitives provides a modern, well-designed stack primitive with excellent `~Copyable` support and proper memory ownership semantics. However, several features common in other implementations are absent.

---

## Current swift-stack-primitives API

### Types
| Type | Description | Comparable To |
|------|-------------|---------------|
| `Stack<Element>` | Dynamic growth, amortized O(1) push | Rust `Vec`, C++ `std::vector` |
| `Stack.Bounded` | Fixed capacity, throws on overflow | Rust `ArrayVec`, Zig `BoundedArray` |
| `Stack.Inline<N>` | Zero-allocation, compile-time capacity | Rust `SmallVec` (inline-only mode), Zig `BoundedArray` |

### Operations
| Operation | Stack | Bounded | Inline | Notes |
|-----------|-------|---------|--------|-------|
| `push` | O(1)* | O(1) throws | O(1) throws | *amortized |
| `pop` | O(1) | O(1) | O(1) | Returns Optional |
| `peek` | O(1) | O(1) | O(1) | Borrowing closure for ~Copyable |
| `clear` | O(n) | O(n) | O(n) | Optional keepCapacity |
| `count` | O(1) | O(1) | O(1) | |
| `isEmpty` | O(1) | O(1) | O(1) | |
| `isFull` | — | O(1) | O(1) | |
| `capacity` | O(1) | O(1) | compile-time | |
| `reserve` | O(n) | — | — | |
| `span` | O(1) | O(1) | O(1) | SE-0456 compliant |
| `mutableSpan` | O(1) | O(1) | O(1) | SE-0456 compliant |

---

## Comparison: Rust

### Rust `Vec<T>` (used as stack)
[Documentation](https://doc.rust-lang.org/std/vec/struct.Vec.html)

| Feature | Rust Vec | swift-stack-primitives | Gap? |
|---------|----------|------------------------|------|
| `push` / `pop` | ✓ | ✓ | — |
| `peek` (via `.last()`) | ✓ | ✓ | — |
| `clear` | ✓ | ✓ | — |
| `reserve` / `reserve_exact` | ✓ | `reserve` only | Minor |
| `shrink_to_fit` | ✓ | ✗ | **GAP** |
| `truncate(len)` | ✓ | ✗ | **GAP** |
| `drain(range)` | ✓ | ✗ | **GAP** |
| `retain(predicate)` | ✓ | ✗ | **GAP** |
| `swap_remove(index)` | ✓ | ✗ | Minor (via mutableSpan) |
| `is_empty` | ✓ | ✓ | — |
| `len` / `capacity` | ✓ | ✓ | — |
| Iteration | ✓ (Iterator trait) | ✗ | **GAP** |
| Index access | ✓ | Via span | — |
| `with_capacity` | ✓ | `init(reservingCapacity:)` | — |
| Move semantics | ✓ (ownership) | ✓ (~Copyable) | — |
| `extend` | ✓ | ✗ | **GAP** |
| `append(&mut other)` | ✓ | ✗ | **GAP** |

### Rust `SmallVec<[T; N]>`
[servo/rust-smallvec](https://github.com/servo/rust-smallvec)

| Feature | SmallVec | swift-stack-primitives | Gap? |
|---------|----------|------------------------|------|
| Inline storage with heap fallback | ✓ | ✗ (separate types) | Design choice |
| Spill to heap when full | ✓ | ✗ | Design choice |
| `inline_size()` | ✓ | `capacity` (compile-time) | — |

**Design Note**: swift-stack-primitives separates `Stack.Inline` (never allocates) from `Stack` (always heap). SmallVec combines both. The Swift approach is more explicit but requires choosing upfront.

### Rust `ArrayVec<T, const N: usize>`
[arrayvec crate](https://docs.rs/arrayvec/latest/arrayvec/struct.ArrayVec.html)

| Feature | ArrayVec | Stack.Inline | Gap? |
|---------|----------|--------------|------|
| Fixed capacity | ✓ | ✓ | — |
| No heap allocation | ✓ | ✓ | — |
| `try_push` | ✓ | `push` throws | — |
| `truncate` | ✓ | ✗ | **GAP** |
| `drain` | ✓ | ✗ | **GAP** |
| `retain` | ✓ | ✗ | **GAP** |
| Iteration | ✓ | ✗ | **GAP** |
| `pop_at(index)` | ✓ | ✗ | Minor |

---

## Comparison: C++

### `std::stack<T, Container>`
[cppreference](https://en.cppreference.com/w/cpp/container/stack.html)

| Feature | std::stack | swift-stack-primitives | Gap? |
|---------|------------|------------------------|------|
| `push` / `pop` | ✓ | ✓ | — |
| `top` (peek) | ✓ | ✓ | — |
| `emplace` (construct in-place) | ✓ | ✗ | **GAP** |
| `swap` | ✓ | ✗ | **GAP** |
| `size` / `empty` | ✓ | ✓ | — |
| Configurable underlying container | ✓ | ✗ | Design choice |

**Note on `emplace`**: C++ `emplace` constructs an element in-place, avoiding a copy/move. In Swift, this would be analogous to an initializer that constructs directly into stack storage. With `consuming` parameters and move semantics, Swift already avoids unnecessary copies, but explicit in-place construction APIs could still be valuable.

### `std::vector<T>` (as stack)
[cplusplus.com](https://cplusplus.com/reference/stack/stack/)

| Feature | std::vector | swift-stack-primitives | Gap? |
|---------|-------------|------------------------|------|
| `shrink_to_fit` | ✓ | ✗ | **GAP** |
| `resize` | ✓ | ✗ | **GAP** |
| `erase` | ✓ | ✗ | Minor |
| Iterators | ✓ | ✗ | **GAP** |

---

## Comparison: Zig

### `std.ArrayList` / `std.ArrayListUnmanaged`
[zig.guide](https://zig.guide/standard-library/arraylist/)

| Feature | Zig ArrayList | swift-stack-primitives | Gap? |
|---------|---------------|------------------------|------|
| `append` / `pop` | ✓ | ✓ | — |
| `appendSlice` | ✓ | ✗ | **GAP** |
| `clearRetainingCapacity` | ✓ | `clear(keepingCapacity: true)` | — |
| `clearAndFree` | ✓ | `clear(keepingCapacity: false)` | — |
| `shrinkAndFree` | ✓ | ✗ | **GAP** |
| `resize` | ✓ | ✗ | **GAP** |
| Bounded variants | ✓ (since 0.15) | ✓ (`Stack.Bounded`) | — |
| Explicit allocator passing | ✓ (Unmanaged) | Not applicable | Design choice |

### `std.BoundedArray`
[openmymind.net](https://www.openmymind.net/Zigs-BoundedArray/)

| Feature | BoundedArray | Stack.Inline | Gap? |
|---------|--------------|--------------|------|
| Compile-time capacity | ✓ | ✓ | — |
| No allocation | ✓ | ✓ | — |
| `get` / `set` by index | ✓ | Via span | — |
| `clear` | ✓ | ✓ | — |

---

## Comparison: Go

### Slice-based Stack
[yourbasic.org](https://yourbasic.org/golang/implement-stack/)

| Feature | Go slice | swift-stack-primitives | Gap? |
|---------|----------|------------------------|------|
| `append` / slice pop | ✓ | ✓ | — |
| Pre-allocation (`make`) | ✓ | `init(reservingCapacity:)` | — |
| Memory leak prevention | Manual | Automatic (deinit) | Swift advantage |
| Bounds checking | Runtime (~12% overhead) | Runtime | — |
| Cache locality | ✓ | ✓ | — |
| Type safety | Via generics | Via generics | — |

**Note**: Go's slice-based stacks have no dedicated type—they're just slices used with append/slice patterns. swift-stack-primitives provides a proper abstraction with enforced LIFO semantics.

---

## Comparison: Swift Standard Library

### `Array<Element>` (as stack)
[kodeco.com](https://www.kodeco.com/books/data-structures-algorithms-in-swift/v4.0/chapters/4-stacks)

| Feature | Swift Array | swift-stack-primitives | Gap? |
|---------|-------------|------------------------|------|
| `append` / `popLast` | ✓ | `push` / `pop` | — |
| `removeLast` | ✓ | ✗ (pop returns Optional) | Design choice |
| `last` (peek) | ✓ | `peek` | — |
| `removeAll` | ✓ | `clear` | — |
| `reserveCapacity` | ✓ | `reserve` | — |
| Copy-on-Write | ✓ | ✗ | Design choice |
| `~Copyable` elements | ✗ | ✓ | **Swift-stack advantage** |
| Iteration (Sequence) | ✓ | ✗ | **GAP** |
| Subscript access | ✓ | Via span | — |
| `contains` | ✓ | ✗ | Minor |
| `filter` / `map` | ✓ | ✗ | Minor |

**Key Differentiator**: swift-stack-primitives supports `~Copyable` elements, which Swift's `Array` does not. This is a significant advantage for resource management types like file handles.

---

## Identified Gaps

### Priority 1: Core Missing Features

| Feature | Description | Precedent |
|---------|-------------|-----------|
| **`Sequence` conformance** | Enable `for element in stack` iteration | Swift Array, Rust Iterator |
| **`shrinkToFit()`** | Release unused capacity | Rust, C++, Zig |
| **`truncate(to:)`** | Remove elements beyond index, keeping capacity | Rust, Zig |

### Priority 2: Bulk Operations

| Feature | Description | Precedent |
|---------|-------------|-----------|
| **`extend(contentsOf:)`** | Push multiple elements from sequence | Rust `extend` |
| **`append(contentsOf:)`** | Alias for extend (Swift naming) | Swift Array |
| **`drain(_:)` / `popMultiple(_:)`** | Remove and return multiple elements | Rust `drain` |

### Priority 3: Filtering & Transformation

| Feature | Description | Precedent |
|---------|-------------|-----------|
| **`retain(where:)`** | Keep only elements matching predicate | Rust `retain` |
| **`removeAll(where:)`** | Remove elements matching predicate | Swift Array |

### Priority 4: Interoperability

| Feature | Description | Precedent |
|---------|-------------|-----------|
| **`swap(with:)`** | Exchange contents with another stack | C++ `swap` |
| **`resize(to:)`** | Change count, filling/truncating as needed | Zig, C++ |

### Priority 5: Convenience (Lower Priority)

| Feature | Description | Precedent |
|---------|-------------|-----------|
| **`contains(where:)`** | Check if any element matches | Swift Array |
| **`first(where:)`** | Find first matching element | Swift Array |
| **In-place construction** | Construct element directly in storage | C++ `emplace` |

---

## Opportunities for Improvement

### 1. Sequence Conformance (High Value)

**Problem**: Cannot iterate over stack elements without accessing span.

**Current workaround**:
```swift
for i in 0..<stack.count {
    let element = stack.span[i]
    // ...
}
```

**Desired**:
```swift
for element in stack {
    // ...
}
```

**Consideration**: For `~Copyable` elements, iteration must be borrowing. Swift's `Sequence` protocol assumes copying. This may require a custom `BorrowingSequence` or waiting for language evolution.

**Recommendation**: Add `Sequence` conformance constrained to `where Element: Copyable`. Document the limitation for `~Copyable` elements.

### 2. Shrink-to-Fit (Medium Value)

**Problem**: After clearing or popping many elements, memory remains allocated.

**Proposed API**:
```swift
extension Stack where Element: ~Copyable {
    /// Reduces capacity to match count, releasing unused memory.
    public mutating func shrinkToFit()

    /// Reduces capacity to at least the specified value.
    public mutating func shrink(to minimumCapacity: Int)
}
```

### 3. Truncate (Medium Value)

**Problem**: No way to remove multiple trailing elements efficiently.

**Proposed API**:
```swift
extension Stack where Element: ~Copyable {
    /// Removes elements beyond the specified count.
    /// - Complexity: O(k) where k is the number of removed elements.
    public mutating func truncate(to newCount: Int)
}
```

**Implementation**: Deinitialize elements from `newCount..<count`, update count.

### 4. Bulk Append (Medium Value)

**Problem**: Adding multiple elements requires repeated `push` calls.

**Proposed API**:
```swift
extension Stack where Element: Copyable {
    /// Pushes elements from a sequence onto the stack.
    public mutating func append(contentsOf elements: some Swift.Sequence<Element>)
}
```

**Note**: For `~Copyable`, this would require `consuming` sequence iteration, which Swift doesn't yet support well.

### 5. Retain/Filter (Lower Value)

**Problem**: No in-place filtering without rebuilding.

**Proposed API**:
```swift
extension Stack where Element: ~Copyable {
    /// Removes elements that don't satisfy the predicate.
    public mutating func retain(where shouldKeep: (borrowing Element) -> Bool)
}
```

### 6. SmallVec-style Hybrid Type (Design Consideration)

**Question**: Should there be a `Stack.Small<N>` that stores up to N elements inline, then spills to heap?

**Rust precedent**: `SmallVec<[T; N]>` is popular because it optimizes the common case (small collections) while handling the uncommon case (growth).

**Arguments for**:
- Eliminates allocation for typical usage
- Single type instead of choosing between `Stack` and `Stack.Inline`

**Arguments against**:
- Adds complexity (must check inline vs heap on every operation)
- Slightly slower for all operations due to branching
- Swift's `InlineArray` + value generics make `Stack.Inline` ergonomic

**Recommendation**: Document the pattern of using `Stack.Inline` when size is bounded, `Stack` when unbounded. Consider `Stack.Small` only if demand materializes.

---

## Summary of Recommendations

### Immediate (High Confidence)

1. **Add `Sequence` conformance** for `Element: Copyable`
2. **Add `shrinkToFit()`** to release unused memory
3. **Add `truncate(to:)`** for bulk removal

### Short-term (Medium Confidence)

4. **Add `append(contentsOf:)`** for bulk insertion
5. **Add `retain(where:)`** for in-place filtering
6. **Add `swap(with:)`** for exchanging contents

### Long-term (Requires Language Evolution)

7. **Borrowing iteration** for `~Copyable` elements (needs Swift language support)
8. **`consuming` sequence iteration** for bulk append of `~Copyable` elements

---

## Sources

### Rust
- [Vec Documentation](https://doc.rust-lang.org/std/vec/struct.Vec.html)
- [SmallVec GitHub](https://github.com/servo/rust-smallvec)
- [ArrayVec Documentation](https://docs.rs/arrayvec/latest/arrayvec/struct.ArrayVec.html)
- [SmallVec vs Vec Performance](https://mcmah309.github.io/posts/ArrayVec-or-SmallVec-or-TinyVec/)
- [Rust Performance Book - Heap Allocations](https://nnethercote.github.io/perf-book/heap-allocations.html)

### C++
- [std::stack Reference](https://en.cppreference.com/w/cpp/container/stack.html)
- [std::vector and Stack Behavior](https://www.learncpp.com/cpp-tutorial/stdvector-and-stack-behavior/)
- [Stack vs Vector Discussion](https://www.studyplan.dev/pro-cpp/stacks/q/stack-vs-vector)

### Zig
- [ArrayList Guide](https://zig.guide/standard-library/arraylist/)
- [BoundedArray Overview](https://www.openmymind.net/Zigs-BoundedArray/)
- [Zig 0.15 Release Notes](https://ziglang.org/download/0.15.1/release-notes.html)

### Go
- [Implement Stack in Go](https://yourbasic.org/golang/implement-stack/)
- [Slices: Grow Big or Go Home](https://victoriametrics.com/blog/go-slice/)
- [Go Slice Tricks](https://go.dev/wiki/SliceTricks)

### Swift
- [Data Structures & Algorithms - Stacks](https://www.kodeco.com/books/data-structures-algorithms-in-swift/v4.0/chapters/4-stacks)
- [Array Performance Discussion](https://developer.apple.com/forums/thread/64785)
