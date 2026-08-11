# Inline Slot Type Organization

<!--
---
version: 3.0.0
last_updated: 2026-02-05
status: RECOMMENDATION
tier: 2
---
-->

## Context

Two experiments investigated how `Storage.Inline` can achieve zero-overhead dense packing:

1. **`inline-storage-best-of-both-worlds`** (CONFIRMED, 2026-02-05): Parameterized slot types achieve zero overhead when slot stride matches element stride.

2. **`rawlayout-automatic-sizing`** (CONFIRMED, 2026-02-05): `@_rawLayout(likeArrayOf: Element, count: capacity)` computes optimal layout AUTOMATICALLY — no slot parameter needed.

**Key discovery**: Swift's `@_rawLayout` attribute eliminates the need for any slot parameterization. The compiler derives `size = stride(Element) × capacity` and `alignment = alignment(Element)` at compile time for ANY element type, including `~Copyable`.

This supersedes the parameterized slot approach (v2.x) which required consumers to specify slot types.

**Trigger**: Compiler-level solution discovered; reassess organizational options.

## Question

What is the simplest correct design for `Storage.Inline` given that `@_rawLayout` can compute optimal layout automatically?

## Experiment Results Summary

From `inline-storage-best-of-both-worlds` (2026-02-05):

| Approach | Signature | Zero Overhead | ~Copyable | Complexity |
|----------|-----------|:-------------:|:---------:|:----------:|
| **A**: Cell<count, Base> | `Cell<let count: Int, Base: BitwiseCopyable & Sendable>` | ✓ All sizes | ✓ | 1 type |
| **B**: DirectStorage | `Storage.Inline<Element, capacity, Backing>` | ✓ All sizes | ✓ | 0 types |
| **C**: StorageV3 | `Storage.Inline<Element, capacity, cellCount, CellBase>` | ✓ All sizes | ✓ | 1 type |
| **E**: No wrapper | Use `UInt8`/`Int`/`InlineArray<N, Int>` directly as slot | ✓ All sizes | ✓ | 0 types |

**Measured results**:

| Element | Slot/Backing | Storage Size | Ideal | Overhead |
|---------|--------------|-------------:|------:|---------:|
| UInt8 × 16 | `UInt8` | 16 B | 16 B | 0% |
| Double × 4 | `Int` | 32 B | 32 B | 0% |
| Int32 × 8 | `UInt32` | 32 B | 32 B | 0% |
| 16B ~Copyable × 4 | `Cell<2, Int>` | 64 B | 64 B | 0% |
| Double × 4 (64B slots) | `Cell<8, Int>` | 256 B | 32 B | 700% |

## Analysis

### Option A (Previous): 7 Concrete Cell Types

**Status**: SUPERSEDED

The original analysis proposed `Memory.Alignment.Cell` protocol with 7 concrete types (`Byte`, `HalfWord`, `Word`, `DoubleWord`, `QuadWord`, `Block32`, `Block64`).

This is **unnecessary complexity**. The experiment proves a single generic type or no wrapper at all achieves the same result with:
- Fewer types to maintain
- No protocol boilerplate
- More flexibility (any count × base combination)

### Option B: Single Generic Cell Type

Define one generic type in memory-primitives:

```swift
extension Memory {
    /// A fixed-width Copyable cell for backing inline storage.
    ///
    /// The cell's byte width is `count × MemoryLayout<Base>.stride`.
    /// The cell's alignment equals `MemoryLayout<Base>.alignment`.
    public struct Cell<let count: Int, Base: BitwiseCopyable & Sendable>: Copyable, Sendable {
        @usableFromInline
        var _backing: InlineArray<count, Base>

        /// The cell's byte width.
        @inlinable
        public static var byteWidth: Int { count * MemoryLayout<Base>.stride }

        /// The cell's alignment.
        @inlinable
        public static var alignment: Int { MemoryLayout<Base>.alignment }
    }
}

// Constrained inits for common base types
extension Memory.Cell where Base == UInt8 {
    @inlinable public init() { _backing = InlineArray(repeating: 0) }
}
extension Memory.Cell where Base == UInt16 {
    @inlinable public init() { _backing = InlineArray(repeating: 0) }
}
extension Memory.Cell where Base == UInt32 {
    @inlinable public init() { _backing = InlineArray(repeating: 0) }
}
extension Memory.Cell where Base == Int {
    @inlinable public init() { _backing = InlineArray(repeating: 0) }
}
```

Then Storage.Inline becomes:

```swift
Storage.Inline<Double, 4, Memory.Cell<1, Int>>       // 32 bytes (ideal)
Storage.Inline<UInt8, 16, Memory.Cell<1, UInt8>>     // 16 bytes (ideal)
Storage.Inline<Resource, 4, Memory.Cell<2, Int>>     // 64 bytes (ideal for 16B element)
Storage.Inline<Any, 8, Memory.Cell<8, Int>>          // 512 bytes (current 64B slot behavior)
```

**Advantages**:
- ONE type instead of 7
- Flexible: any power-of-2 size is just a parameter choice
- Base type controls alignment naturally
- Cell<1, Int> = 8B, Cell<2, Int> = 16B, Cell<8, Int> = 64B — clear mental model
- Integrates with existing `BitwiseCopyable` ecosystem

**Disadvantages**:
- Adds one type to memory-primitives
- Slightly longer parameter: `Cell<1, Int>` vs `DoubleWord`
- The `Cell` name is unfamiliar (but precise)

### Option C: No Wrapper — Use Backing Directly

The simplest design: eliminate the Cell wrapper entirely. Storage.Inline takes the backing type directly:

```swift
Storage.Inline<Double, 4, Int>           // Backing = Int, 32 bytes
Storage.Inline<UInt8, 16, UInt8>         // Backing = UInt8, 16 bytes
Storage.Inline<Resource, 4, (Int, Int)>  // Backing = tuple, 64 bytes
```

For multi-word slots, use nested InlineArray:

```swift
Storage.Inline<LargeStruct, 4, InlineArray<2, Int>>   // 16-byte slots
Storage.Inline<HugeStruct, 4, InlineArray<8, Int>>    // 64-byte slots
```

**Advantages**:
- ZERO new types
- Maximum simplicity
- Users already know `Int`, `UInt8`, etc.
- Tuples and InlineArray are standard

**Disadvantages**:
- `InlineArray<8, Int>` is verbose for 64-byte slot
- No documentation on the backing type explaining its purpose
- Harder to enforce BitwiseCopyable + Sendable constraints (must be on Storage.Inline)

### Option D: Typealiases Only

Provide typealiases for common slot sizes without a new struct:

```swift
extension Memory {
    public typealias Cell1 = UInt8
    public typealias Cell2 = UInt16
    public typealias Cell4 = UInt32
    public typealias Cell8 = Int
    public typealias Cell16 = InlineArray<2, Int>
    public typealias Cell32 = InlineArray<4, Int>
    public typealias Cell64 = InlineArray<8, Int>
}
```

Then: `Storage.Inline<Double, 4, Memory.Cell8>`

**Advantages**:
- No new struct types
- Familiar underlying types
- Short names for common cases

**Disadvantages**:
- Numeric suffixes violate [API-NAME-001]
- Typealiases don't carry documentation as well as structs
- Less type safety (any Int can be used where Memory.Cell8 is expected)

## Comparison

| Criterion | A (7 types) | B (Cell generic) | C (No wrapper) | D (Typealiases) |
|-----------|:-----------:|:----------------:|:--------------:|:---------------:|
| Types added | 7 | 1 | 0 | 0 |
| [API-NAME-001] | Compliant | Compliant | Compliant | `Cell8` ✗ |
| Flexibility | Fixed set | Any count×base | Any backing | Fixed set |
| Discoverability | High | High | Medium | Medium |
| Documentation | Per-type | Generic docs | None | Minimal |
| Complexity | High | Low | Lowest | Low |

## Constraints

1. **`@_rawLayout` is underscored**: Not ABI-stable. Acceptable for internal storage backing but not for public API.

2. **`@_rawLayout` types are always `~Copyable`**: Cannot conditionally conform to `Copyable`. This is acceptable since `Storage.Inline` already manages initialization state.

3. **Element access requires `Builtin.addressOfRawLayout`**: Only available in stdlib. External packages must use `withUnsafePointer` tricks.

4. **Backward compatibility**: Current `Storage.Inline` uses 64-byte slots. Migration path needed.

## Recommendation

**Option E: `@_rawLayout(likeArrayOf: Element, count: capacity)` — automatic layout.**

### Rationale

1. **Zero parameters**: No slot type to specify. `Storage.Inline<Element, capacity>` is the complete signature.

2. **Zero overhead by definition**: The compiler computes `size = stride(Element) × capacity` exactly. No possibility of mismatch.

3. **Works with ALL elements**: Any `~Copyable` type, any size, any alignment — automatically correct.

4. **No types to add**: No `Cell`, no wrapper, no typealiases.

5. **Proven in stdlib**: `Atomic<Value>`, `_Cell<Value>`, and test cases like `Vector<T, let N: Int>` use this pattern.

### Trade-offs

| Concern | Assessment |
|---------|------------|
| Underscored attribute | Acceptable — Storage.Inline is internal infrastructure, not public API |
| Always ~Copyable | Acceptable — storage wrapper controls initialization anyway |
| Builtin access | Solvable with `withUnsafePointer(to: &self)` pattern |

### API Shape

```swift
// storage-primitives (Tier 14)
@_rawLayout(likeArrayOf: Element, count: capacity)
public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
    // No stored properties — layout computed automatically

    public var _address: UnsafeMutablePointer<Element> {
        withUnsafeMutablePointer(to: &self) { ptr in
            UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: Element.self)
        }
    }
}

// Usage — no slot parameter!
typealias DoubleStorage4 = Storage.Inline<Double, 4>     // 32B automatic
typealias ByteStorage16 = Storage.Inline<UInt8, 16>      // 16B automatic
typealias ResourceStorage = Storage.Inline<Resource, 4>  // 64B automatic
```

### Fallback: Option C (Parameterized Slot)

If `@_rawLayout` is rejected (e.g., policy against underscored attributes), use:

```swift
public struct Inline<
    Element: ~Copyable,
    let capacity: Int,
    Slot: BitwiseCopyable & Sendable
>: ~Copyable {
    var _storage: InlineArray<capacity, Slot>
}
```

This achieves equivalent results but requires consumers to specify the slot type.

### Implementation Path

| Step | Package | Change |
|------|---------|--------|
| 1 | storage-primitives | Replace `Storage.Inline` backing with `@_rawLayout` |
| 2 | storage-primitives | Remove `_storage` property (no stored properties needed) |
| 3 | storage-primitives | Update pointer access to use address-of-self pattern |
| 4 | storage-primitives | Remove `Affine.Discrete.Ratio` hardcoding (stride is now automatic) |
| 5 | vector-primitives | Simplify to `Storage.Inline<Element, N>` (no slot parameter) |

**Note**: No changes to memory-primitives required. No new types.

## Prior Art

### Internal

- `Memory.Alignment` — power-of-2 byte values
- `Memory.Pool._slotStride` — runtime slot stride concept
- `InlineArray<count, Element>` — the underlying mechanism

### External

- **Rust `MaybeUninit<T>`**: Generic uninitialized storage — no fixed slots needed
- **C++ `std::aligned_storage<Len, Align>`**: Fixed size/alignment storage (deprecated in C++23)
- **Swift `ManagedBuffer<Header, Element>`**: Heap equivalent with typed storage

## References

- `rawlayout-automatic-sizing/Sources/main.swift` — experiment proving @_rawLayout automatic sizing
- `inline-storage-best-of-both-worlds/Sources/main.swift` — experiment proving parameterized slot approach
- `Storage.Inline.swift:46-48` — current 64-byte tuple slot
- `Affine.Discrete.Ratio+Storage.swift:19-23` — hardcoded 64-byte ratio
- Swift compiler tests: `/swiftlang/swift/test/IRGen/raw_layout.swift` — `Vector<T, let N: Int>` pattern

## Changelog

### v3.0.0 (2026-02-05)
- NEW: `@_rawLayout(likeArrayOf: Element, count: capacity)` discovered as ideal solution
- Changed recommendation from Option C (parameterized slot) to Option E (@_rawLayout)
- Option C retained as fallback if underscored attributes are rejected
- Rationale: @_rawLayout eliminates slot parameter entirely — automatic optimal layout

### v2.1.0 (2026-02-05)
- Changed recommendation from Option B (Cell wrapper) to Option C (no wrapper)
- Rationale: Cell's only benefit is documentation for a hidden parameter — insufficient to justify adding a type

### v2.0.0 (2026-02-05)
- SUPERSEDED v1.0.0 recommendation of 7 concrete types
- NEW: Single generic `Cell<count, Base>` recommendation based on experiment results
- NEW: Option C (no wrapper) documented as viable alternative
- Updated experiment findings with measured byte sizes
