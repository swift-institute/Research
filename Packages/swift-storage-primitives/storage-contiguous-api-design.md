# Storage Contiguous API Design

<!--
---
version: 1.1.0
last_updated: 2026-02-05
status: DECISION
---
-->

## Context

With the addition of `Span.Protocol` conformance to `Storage.Heap` and `Storage.Inline`, we now have overlapping APIs for contiguous memory access. This research determines the optimal API surface for "timeless infrastructure" quality.

**Trigger**: API audit revealed potential redundancy between:
- New `span` / `mutableSpan` property-based access (Span.Protocol)
- Existing `withSpan(range:_:)` closure-based access
- Various copy/move operations

**Scope**: Package-specific (swift-storage-primitives)

**Tier**: Tier 2 (Standard) — affects public API surface, reversible but creates migration burden

**Supersession Note**: `Storage.Span` is superseded by `Range<Index<Storage>>`. This document uses `Range<Index<Storage>>` for slot ranges and `Swift.Span<Element>` for memory views.

---

## Question

**What is the ideal public API surface for contiguous memory access on Storage.Heap and Storage.Inline?**

Sub-questions:
1. Which access patterns should be property-based vs closure-based?
2. Should range-based access be supported, or only linear (0..<count)?
3. How should Copyable vs ~Copyable elements affect the API?
4. What is the role of unsafe APIs alongside safe Span-based APIs?

---

## Analysis

### Terminology

| Term | Type | Meaning |
|------|------|---------|
| Slot range | `Range<Index<Storage>>` | Physical slot coordinates [start, end) |
| Memory view | `Swift.Span<Element>` | Safe bounds-checked view into contiguous memory |
| Linear initialization | `.empty` or `.one(0..<n)` | Elements occupy slots 0..<count contiguously |
| Non-linear initialization | `.two(first, second)` | Disjoint ranges (e.g., ring buffer wrap) |

### Current API Inventory

#### Storage.Heap (class)

| API | Constraint | Access Pattern | Range |
|-----|------------|----------------|-------|
| `span` | Copyable | Property | 0..<count |
| `withMutableSpan(_:)` | Copyable | Closure | 0..<count |
| `withSpan(range:_:)` | ~Copyable* | Closure | Arbitrary |
| `withUnsafeBufferPointer(_:)` | Copyable | Closure | 0..<count |
| `withUnsafeMutableBufferPointer(_:)` | Copyable | Closure | 0..<count |
| `pointer(at:)` | ~Copyable | Direct | Single slot |

*Note: `withSpan(range:_:)` is in ~Copyable extension but `Swift.Span` requires Copyable.

#### Storage.Inline (struct)

| API | Constraint | Access Pattern | Range |
|-----|------------|----------------|-------|
| `span` | Copyable | Property | 0..<count |
| `mutableSpan` | Copyable | Property | 0..<count |
| `withUnsafeBufferPointer(_:)` | Copyable | Closure | 0..<count |
| `withUnsafeMutableBufferPointer(_:)` | Copyable | Closure | 0..<count |
| `pointer(at:)` | ~Copyable | Direct | Single slot |

---

### Option A: Minimal Surface (Linear-Only Span)

**Philosophy**: Span properties serve the common case (linear initialization). Arbitrary range access is a higher-layer concern or uses primitives.

**API Surface**:

```swift
// Span.Protocol (read-only, linear)
var span: Span<Element> { get }                    // 0..<count
func withUnsafeBufferPointer(_:)                   // C interop

// Type-specific mutable (linear)
var mutableSpan: MutableSpan<Element> { mutating get }  // Struct only
func withMutableSpan(_:)                                 // Class only
func withUnsafeMutableBufferPointer(_:)                  // C interop

// Low-level primitives (~Copyable support)
func pointer(at:) -> UnsafePointer<Element>        // Single slot read
mutating func pointer(at:) -> UnsafeMutablePointer<Element>  // Single slot write
```

**Removed**:
- `withSpan(range:_:)` — ring buffer layer creates Span from `pointer(at:)`

**Advantages**:
- Minimal API surface
- Clear hierarchy: Span (safe, linear) → pointer (primitive, arbitrary)
- No closure overhead for common case
- Separation of concerns: storage = linear, buffer = ring discipline

**Disadvantages**:
- Ring buffer implementations must create Span manually (unsafe operation)
- Loss of safe arbitrary-range access

---

### Option B: Complete Safe Surface

**Philosophy**: Storage primitives should provide ALL safe access patterns. Consumers should never need to drop to unsafe for standard operations.

**API Surface**:

```swift
// Span.Protocol (linear initialization)
var span: Span<Element> { get }
func withUnsafeBufferPointer(_:)

// Type-specific mutable (linear)
var mutableSpan: MutableSpan<Element> { mutating get }  // Struct
func withMutableSpan(_:)                                 // Class
func withUnsafeMutableBufferPointer(_:)

// Range-based safe access (arbitrary ranges, Copyable only)
func span(range:) -> Span<Element>                  // Read (property-like)
func withSpan(range:_:)                             // Read (closure)
mutating func mutableSpan(range:) -> MutableSpan    // Struct write
func withMutableSpan(range:_:)                      // Class/closure write

// Low-level primitives (~Copyable)
func pointer(at:)
```

**Advantages**:
- Complete safe API at storage layer
- Ring buffer implementations stay safe
- Symmetry between linear and range-based access

**Disadvantages**:
- Larger API surface (property + closure variants for each)
- Potential confusion: when to use property vs closure?
- Range-based APIs only work for Copyable (Span limitation)

---

### Option C: Pragmatic Layered Surface

**Philosophy**: Separate concerns by layer. Protocol provides universal linear access. Range-based access uses closure pattern for safety.

**Layer 1: Span.Protocol (Universal Linear Access)**

```swift
public protocol `Protocol`: ~Copyable {
    associatedtype Element
    var span: Span<Element> { get }
    func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R
}
```

- Read-only by design
- Assumes linear initialization (0..<count)
- Safe + unsafe escape hatch

**Layer 2: Type-Specific Mutable Access (Linear)**

```swift
// Storage.Inline (struct — property-based)
extension Storage.Inline where Element: Copyable {
    var mutableSpan: MutableSpan<Element> { mutating get }
    mutating func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R
}

// Storage.Heap (class — closure-based)
extension Storage.Heap where Element: Copyable {
    func withMutableSpan<R, E>(_:) throws(E) -> R
    func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R
}
```

**Layer 3: Range-Based Safe Access (Copyable, Arbitrary Ranges)**

```swift
// Both types — closure-based for arbitrary ranges
extension Storage.Heap where Element: Copyable {
    func withSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R
    func withMutableSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R
}

extension Storage.Inline where Element: Copyable {
    func withSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R
    mutating func withMutableSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R
}
```

- Closure-based (Span cannot escape arbitrary-lifetime storage)
- Supports ring buffer segments safely
- Copyable constraint explicit (moved from ~Copyable extension)

**Layer 4: Low-Level Primitives (~Copyable Support)**

```swift
// Both types
func pointer(at: Index<Storage>) -> UnsafePointer<Element>
mutating func pointer(at: Index<Storage>) -> UnsafeMutablePointer<Element>
func initialize(to: consuming Element, at: Index<Storage>)
func move(at: Index<Storage>) -> Element
func deinitialize(at: Index<Storage>)
```

- Single-slot operations
- Required for ~Copyable elements
- Building blocks for higher-level operations

**Layer 5: Bulk Operations**

```swift
// Deinitialization
func deinitialize(range: Range<Index<Storage>>)
func deinitialize()  // All tracked slots

// Cross-storage transfer
func move(range:to:)
func copy(range:to:)  // Copyable only
func copy()           // Copyable only
func copy(to:)        // Copyable only
```

- Operate on initialization tracking
- Handle `.two` patterns internally
- Not Span-based (work with raw slots)

**Changes from Current**:
- **MOVE** `withSpan(range:_:)` from ~Copyable to Copyable extension (constraint was implicit)
- **ADD** `withMutableSpan(range:_:)` for symmetry

**Advantages**:
- Clear separation: property (linear) vs closure (arbitrary range)
- Complete safe API surface
- ~Copyable support via primitives
- Ring buffers stay safe

**Disadvantages**:
- Slightly larger API surface than Option A
- Two access patterns to learn (property vs closure)

---

### Evaluation Criteria

| Criterion | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| API minimality | High | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| Conceptual clarity | High | ★★★★☆ | ★★★☆☆ | ★★★★★ |
| ~Copyable support | High | ★★★★★ | ★★★☆☆ | ★★★★★ |
| Ring buffer support | High | ★★☆☆☆ | ★★★★★ | ★★★★★ |
| Protocol alignment | High | ★★★★★ | ★★★☆☆ | ★★★★★ |
| Safety completeness | High | ★★★☆☆ | ★★★★★ | ★★★★★ |
| Future-proofing | High | ★★★★☆ | ★★★☆☆ | ★★★★★ |

**Weighted Analysis**:
- Option A sacrifices ring buffer safety for minimality
- Option B has redundant APIs (property + closure for same thing)
- Option C achieves completeness with clear separation (property=linear, closure=range)

---

### Theoretical Analysis

#### The Property vs Closure Distinction

**Property-based access** (`span`, `mutableSpan`):
- Returns value with lifetime tied to `self`
- Requires `@_lifetime` annotations
- Works when range is statically known (0..<count)
- Cannot work for arbitrary ranges (lifetime of range unknown)

**Closure-based access** (`withSpan(range:_:)`):
- Span lifetime bounded by closure scope
- No lifetime annotation needed
- Works for any range (closure provides scope)
- Required when range is dynamic

**Conclusion**: This is not redundancy — it's complementary. Properties for linear, closures for ranges.

#### The ~Copyable Constraint

`Swift.Span<Element>` requires `Element: Copyable` (SE-0447 limitation). This means:
- Span-based APIs are Copyable-only
- ~Copyable elements must use `pointer(at:)` primitives

**Experiment**: `Experiments/span-copyable-constraint/` validated that:
- Placing `withSpan` in ~Copyable extension is **NOT a compiler bug**
- The method declaration compiles (Element is generic)
- The method can only be CALLED when `Element: Copyable` (Span constraint at call site)
- However, this is **misleading API design** — move to Copyable extension for clarity

#### The Ring Buffer Use Case

Ring buffers with `.two` initialization:
```
Slots: [0][1][2][3][4][5][6][7]
Data:   X  X  X  -  -  -  X  X
        └──┴──┘           └──┴── two segments
```

Access patterns needed:
1. **First segment**: `withSpan(0..<3, _:)`
2. **Second segment**: `withSpan(6..<8, _:)`

Without range-based Span access, ring buffer must:
```swift
let ptr = storage.pointer(at: range.lowerBound)
let span = Span(_unsafeStart: ptr, count: range.count)  // UNSAFE
```

With range-based access:
```swift
storage.withSpan(range) { span in  // SAFE
    // use span
}
```

**Conclusion**: Range-based Span access is essential for safe ring buffer implementations.

---

### Prior Art

**Swift Standard Library** (Array, ContiguousArray):
- `withUnsafeBufferPointer(_:)` — closure-based
- `withUnsafeMutableBufferPointer(_:)` — closure-based
- No range-based variants
- SE-0456 adds `span` and `mutableSpan` properties

**Rust** (Vec, slice):
- `as_slice()` / `as_mut_slice()` — returns slice (similar to Span)
- `get(range)` — returns Option<&[T]> for range
- `split_at(mid)` — for non-contiguous access patterns

**C++** (std::span, std::vector):
- `std::span` constructor from pointer + size
- `subspan(offset, count)` — range-based view
- No special ring buffer support

**Key Insight**: No major language provides special APIs for non-linear initialization patterns at the container level. Ring buffers are typically separate abstractions built on top of linear storage.

---

### Constraint: Ring Buffer Patterns

The `.two` initialization pattern exists for ring buffers:

```
Slots: [0][1][2][3][4][5][6][7]
Data:   X  X  X  -  -  -  X  X
        └──┴──┘           └──┴── initialized
Initialization: .two(first: [0,3), second: [6,8))
```

**Question**: Should Storage primitives provide Span access to these segments?

**Analysis**:
- Storage.Heap/Inline are **storage primitives**, not ring buffer ADTs
- Ring buffer is a **data structure** built on storage
- The ADT layer (e.g., `RingBuffer<T>`) should handle segment iteration
- Storage layer provides: raw access, initialization tracking, bulk operations

**Conclusion**: Storage primitives should NOT provide range-based Span access. The ADT layer owns that abstraction.

---

## Outcome

**Status**: DECISION

### Decision: Option C (Pragmatic Layered Surface)

**Rationale**:
1. **Property vs closure is not redundancy** — properties for linear (0..<count), closures for arbitrary ranges
2. **Safety completeness** — ring buffers should not need unsafe code for standard operations
3. **~Copyable first-class** — primitives work for all element types; Span is Copyable overlay
4. **Protocol alignment** — `Span.Protocol` represents universal linear access

### Implemented Changes

**API Clarity (not a bug, but misleading)**:
- [x] **MOVED** `withSpan(range:_:)` from ~Copyable extension to Copyable extension
  - Method compiled in ~Copyable but was only callable for Copyable elements
  - Moving makes the constraint explicit in the extension header

**Add (Symmetry)**:
- [x] **ADDED** `withSpan(range:_:)` for Storage.Inline (was missing)
- [x] **ADDED** `withMutableSpan(range:_:)` for Storage.Heap (class, arbitrary range)
- [x] **ADDED** `withMutableSpan(range:_:)` for Storage.Inline (struct, arbitrary range)

**Keep**:
- [x] `span` property (Span.Protocol, linear)
- [x] `mutableSpan` property (Storage.Inline) / `withMutableSpan(_:)` (Storage.Heap) — linear
- [x] `withUnsafeBufferPointer`, `withUnsafeMutableBufferPointer` (C interop)
- [x] `pointer(at:)` variants (low-level primitive, ~Copyable)
- [x] `initialize`, `move`, `deinitialize` (ownership operations, ~Copyable)
- [x] Bulk operations: `copy`, `move(range:to:)`, `deinitialize(range:)`

### API Layering Summary

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Span.Protocol (Linear Read)                    │
│   var span: Span<Element>                               │
│   func withUnsafeBufferPointer(_:)                      │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Type-Specific Mutable (Linear Write)           │
│   var mutableSpan (struct) / func withMutableSpan (class)│
│   func withUnsafeMutableBufferPointer(_:)               │
├─────────────────────────────────────────────────────────┤
│ Layer 3: Range-Based Safe Access (Arbitrary, Copyable)  │
│   func withSpan(range:_:)                               │
│   func withMutableSpan(range:_:)                        │
├─────────────────────────────────────────────────────────┤
│ Layer 4: Low-Level Primitives (~Copyable)               │
│   pointer(at:), initialize, move, deinitialize          │
├─────────────────────────────────────────────────────────┤
│ Layer 5: Bulk Operations                                │
│   copy, move(range:to:), deinitialize(range:)           │
└─────────────────────────────────────────────────────────┘
```

### Complete API Surface (Post-Change)

#### Storage.Heap

```swift
// Layer 1: Span.Protocol (Copyable)
var span: Span<Element> { get }
func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R

// Layer 2: Mutable Linear (Copyable)
func withMutableSpan<R, E>(_:) throws(E) -> R
func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R

// Layer 3: Range-Based (Copyable)
func withSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R
func withMutableSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R  // NEW

// Layer 4: Primitives (~Copyable)
func pointer(at:) -> UnsafeMutablePointer<Element>
func initialize(to:at:)
func move(at:) -> Element
func deinitialize(at:)

// Layer 5: Bulk (~Copyable)
func deinitialize(range:)
func deinitialize()
func move(range:to:)

// Layer 5: Bulk (Copyable)
func copy() -> Storage.Heap
func copy(to:)
func copy(range:to:)
```

#### Storage.Inline<Element, capacity>

```swift
// Layer 1: Span.Protocol (Copyable)
var span: Span<Element> { get }
func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R

// Layer 2: Mutable Linear (Copyable)
var mutableSpan: MutableSpan<Element> { mutating get }
mutating func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R

// Layer 3: Range-Based (Copyable)
func withSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R        // NEW
mutating func withMutableSpan<R, E>(_ range: Range<Index<Storage>>, _:) throws(E) -> R  // NEW

// Layer 4: Primitives (~Copyable)
func pointer(at:) -> UnsafePointer<Element>
mutating func pointer(at:) -> UnsafeMutablePointer<Element>
mutating func initialize(to:at:)
mutating func move(at:) -> Element
func deinitialize(at:)

// Layer 5: Bulk (~Copyable)
func deinitialize(range:)
mutating func deinitialize()
mutating func move(range:to:)

// Layer 5: Bulk (Copyable)
func copy(range:to:)
```

---

## Open Questions

1. Should `withUnsafeBufferPointer` be renamed to distinguish from range-based variants?
2. Should range-based APIs use different naming (e.g., `withSpan(over:_:)` vs `withSpan(_:)`)?
3. Is the full API surface (28 methods on Heap, 26 on Inline) acceptable, or should some move to buffer layer?

---

## References

- [SE-0447: Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [SE-0456: Span-providing Properties](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md)
- Research: `storage-contiguous-protocol-conformance.md`
- Experiment: `Experiments/contiguous-protocol-conformance/`
