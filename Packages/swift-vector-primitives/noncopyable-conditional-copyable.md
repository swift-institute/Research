# ~Copyable and Conditional Copyable for Vector Primitives

<!--
---
version: 1.1.0
last_updated: 2026-02-05
status: DECISION
tier: 2
applies_to: [swift-vector-primitives, swift-storage-primitives, swift-buffer-primitives]
normative: true
---
-->

## Context

During vector-primitives test execution, tests for `~Copyable` elements fail to compile:

```
error: referencing initializer 'init(_:)' on 'Vector.Inline' requires that 'TrackedValue' conform to 'Copyable'
```

The tests use `TrackedValue: ~Copyable` to track deinit calls for memory leak detection. The `Vector<TrackedValue, 3>.Inline(...)` initializer is constrained to `where Element: Copyable`, preventing use with `~Copyable` elements.

**Trigger**: [RES-001] Test failure blocking validation of `~Copyable` element support.

**Blocking question**: How should `Vector.Inline` support initialization with `~Copyable` elements?

---

## Question

How can `Vector.Inline` (and underlying `Storage.Inline`) support both:
1. Initialization with `~Copyable` elements
2. Conditional `Copyable` conformance when `Element: Copyable`

**Sub-questions**:
- SQ1: Why does `Storage.Inline` use `@_rawLayout` and what constraints does it impose?
- SQ2: Can `Storage.Inline` be conditionally `Copyable`?
- SQ3: What initialization patterns work for `~Copyable` elements?
- SQ4: Is the current architecture correct, or does it need restructuring?

---

## Prior Research Synthesis

### Existing Research Documents

| Document | Location | Key Findings |
|----------|----------|--------------|
| storage-ownership-reference-synthesis | swift-storage-primitives/Research/ | `@_rawLayout` requires `~Copyable`; conditional `Copyable` not achievable |
| inline-storage-read-pointer-escape | swift-storage-primitives/Research/ | Closure-based pointer access pattern for safe read access |
| theoretical-buffer-primitives-design | swift-buffer-primitives/Research/ | Three-layer design: Headers (pure state) + Static ops + Composed types |
| inline-storage-best-of-both-worlds | swift-storage-primitives/Experiments/ | Parameterized slot approach achieves zero overhead + conditional Copyable |
| rawlayout-noncopyable-elements | swift-storage-primitives/Experiments/ | `@_rawLayout` DOES support `~Copyable` elements |

### Key Findings from Prior Research

**1. `@_rawLayout` Constraint** (from storage-ownership-reference-synthesis.md):
> `@_rawLayout` types are always `~Copyable`. This is correct: `@_rawLayout` provides raw memory layout without initialization guarantees, which cannot be safely copied.

**2. Conditional Copyable is Blocked** (from Storage.swift comment):
```swift
// Note: Storage.Inline cannot be conditionally Copyable because _Raw
// (an @_rawLayout type) is always ~Copyable. This is acceptable since Storage.Inline
// manages initialization state and ~Copyable is the correct semantic.
```

**3. Alternative: InlineArray-Based Storage** (from inline-storage-best-of-both-worlds):
```swift
struct DirectStorage<Element: ~Copyable, let capacity: Int, Backing: BitwiseCopyable & Sendable>: ~Copyable {
    var _storage: InlineArray<capacity, Backing>
}

extension DirectStorage: Copyable where Element: Copyable {}
extension DirectStorage: Sendable where Element: Sendable {}
```

This approach achieves conditional `Copyable` conformance by using a `BitwiseCopyable` backing type instead of `@_rawLayout`.

---

## Analysis

### SQ1: Why `@_rawLayout`?

`@_rawLayout(likeArrayOf: Element, count: capacity)` provides:
- Automatic optimal layout computation: `size = stride(Element) × capacity`, `alignment = alignment(Element)`
- Support for ANY element type and size (no hardcoded slot sizes)
- Zero overhead — elements stored at natural stride

The trade-off: `@_rawLayout` types are unconditionally `~Copyable`.

### SQ2: Can `Storage.Inline` Be Conditionally Copyable?

**Current implementation (using `@_rawLayout`)**: NO.

The `_Raw` struct uses `@_rawLayout`, which is always `~Copyable`. A type containing `~Copyable` storage cannot itself be `Copyable`.

**Alternative (using `InlineArray<capacity, Backing>`)**: YES.

If storage uses `InlineArray<capacity, Backing>` where `Backing: BitwiseCopyable`, the storage type CAN be conditionally `Copyable`:

```swift
struct InlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, Int>  // Or computed Backing type
    var _initialization: Storage.Initialization
}

extension InlineStorage: Copyable where Element: Copyable {}
```

**Trade-off comparison**:

| Approach | Conditional Copyable | Zero Overhead | API Complexity |
|----------|---------------------|---------------|----------------|
| `@_rawLayout` | No | Yes (automatic) | Simple (2 params) |
| `InlineArray<N, Backing>` | Yes | Yes (manual) | Complex (backing type param) |
| `InlineArray<N, Int>` fixed | Yes | No (8B minimum) | Simple |

### SQ3: Initialization Patterns for `~Copyable` Elements

The current `Vector.Inline.init(_ elements: InlineArray<N, Element>)` requires `Element: Copyable` because:
1. `InlineArray` subscript access copies elements
2. Iteration copies elements

For `~Copyable` elements, we need **consuming initialization**:

**Option A: Closure-based initialization**
```swift
public init(initializing body: (inout UnsafeMutableBufferPointer<Element>) -> Void) where Element: ~Copyable {
    _storage = Storage<Element>.Inline<N>()
    withUnsafeMutablePointer(to: &_storage._storage) { ptr in
        var buffer = UnsafeMutableBufferPointer(start: ptr, count: N)
        body(&buffer)
    }
    _storage.initialization = .linear(count: Index<Element>.Count(Cardinal(UInt(N))))
}
```

**Option B: Repeated consuming initialization**
```swift
public init(
    _ e0: consuming Element,
    _ e1: consuming Element,
    _ e2: consuming Element
) where N == 3 {
    _storage = Storage<Element>.Inline<N>()
    _storage.initialize(to: e0, at: Index(Ordinal(0)))
    _storage.initialize(to: e1, at: Index(Ordinal(1)))
    _storage.initialize(to: e2, at: Index(Ordinal(2)))
    _storage.initialization = .linear(count: Index<Element>.Count(Cardinal(3)))
}
```

**Option C: withUnsafeUninitializedCapacity pattern** (mirrors stdlib)
```swift
public init(
    unsafeUninitializedCapacity: Int,
    initializingWith initializer: (
        _ buffer: inout UnsafeMutableBufferPointer<Element>,
        _ initializedCount: inout Int
    ) throws -> Void
) rethrows where Element: ~Copyable
```

### SQ4: Architecture Assessment

The current architecture is **correct** but **incomplete**:

| Component | Status | Issue |
|-----------|--------|-------|
| `Storage.Inline` with `@_rawLayout` | Correct | Unconditionally `~Copyable` (acceptable) |
| `Vector.Inline` deinit | Correct | Properly deinitializes all elements |
| `Vector.Inline` subscript | Correct | Works with `~Copyable` elements |
| `Vector.Inline` span | Correct | Works with `~Copyable` elements |
| `Vector.Inline.init(_:)` | **Missing** | No initializer for `~Copyable` elements |
| Conditional Copyable | **Blocked** | Cannot achieve with `@_rawLayout` |

---

## Options

### Option 1: Add ~Copyable Initializers (Minimal Fix)

Add initializers for `~Copyable` elements while keeping current `@_rawLayout` architecture:

```swift
extension Vector.Inline where Element: ~Copyable {
    /// Initialize with closure that receives uninitialized buffer.
    public init(
        unsafeUninitializedCapacity capacity: Int,
        initializingWith initializer: (
            inout UnsafeMutableBufferPointer<Element>,
            inout Int
        ) throws -> Void
    ) rethrows
}
```

**Pros**: Minimal change, unblocks tests
**Cons**: Conditional Copyable still blocked

### Option 2: Dual Storage Strategy

Provide two storage implementations:
- `Storage.Inline<E, N>` using `@_rawLayout` (current, always `~Copyable`)
- `Storage.Inline.Copyable<E, N>` using `InlineArray<N, Backing>` (conditionally `Copyable`)

**Pros**: Best of both worlds
**Cons**: Two parallel implementations, API complexity

### Option 3: Replace `@_rawLayout` with `InlineArray`

Replace `@_rawLayout` with `InlineArray<capacity, Backing>` parameterized storage:

```swift
public struct Inline<let capacity: Int, Backing: BitwiseCopyable & Sendable = Int>: ~Copyable {
    var _storage: InlineArray<capacity, Backing>
    var _initialization: Initialization
}

extension Inline: Copyable where Element: Copyable {}
```

**Pros**: Achieves conditional Copyable
**Cons**:
- Breaking API change (new `Backing` parameter)
- Consumer must compute optimal backing type
- 8-byte minimum cell size with `Int` default

### Option 4: Wait for Swift Language Evolution

Swift may eventually support:
- Conditional copyability for `@_rawLayout` types
- Better `~Copyable` collection patterns

**Pros**: No code changes needed
**Cons**: Indefinite timeline, tests remain broken

---

## Constraints

1. **`@_rawLayout` is always `~Copyable`** — This is a Swift language constraint, not changeable at library level.

2. **`InlineArray` subscript copies** — Cannot iterate/subscript `InlineArray<N, ~Copyable>` without consuming.

3. **Protocol conformance requires `Copyable`** — `Sequence`, `Collection`, `Equatable`, `Hashable` all require element copyability for most operations.

4. **Test infrastructure needs `~Copyable` elements** — Memory leak detection requires tracking deinit calls via `~Copyable` tracker types.

---

## Recommendation

### Immediate: Option 1 (Add ~Copyable Initializers)

Unblock tests with minimal change:

```swift
extension Vector.Inline where Element: ~Copyable {
    /// Creates a vector by initializing elements via closure.
    ///
    /// The closure receives an uninitialized buffer and must initialize
    /// exactly `N` elements before returning.
    @inlinable
    public init(
        _ initializer: (UnsafeMutablePointer<Element>) -> Void
    ) {
        self._storage = Storage<Element>.Inline<N>()
        unsafe withUnsafeMutablePointer(to: &_storage._storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: Element.self)
            initializer(ptr)
        }
        _storage.initialization = .linear(count: Index<Element>.Count(Cardinal(UInt(N))))
    }
}
```

### Future: Option 3 (Replace with InlineArray)

For full conditional Copyable support, migrate to `InlineArray`-based storage with sensible defaults at the ADT layer:

```swift
// Low-level: Consumer specifies backing
Storage.Inline<Element, capacity, Backing>

// High-level: Vector chooses optimal backing
Vector<Double, 4>.Inline  // Uses Int backing internally (8B slots)
Vector<UInt8, 16>.Inline  // Uses UInt8 backing internally (1B slots)
```

This requires research into automatic backing type selection at the ADT layer.

---

## Experiment Results

**Experiment**: `swift-vector-primitives/Experiments/noncopyable-inline-init/`

### Variant Results

| Variant | Description | Result |
|---------|-------------|--------|
| 1 | Closure-based init with `@_rawLayout` | **CONFIRMED** — All elements initialized, deinit count correct |
| 2 | Consuming params init with `@_rawLayout` | **CONFIRMED** — Works with direct pointer access (not closure) |
| 3 | stdlib pattern (`unsafeUninitializedCapacity`) | **CONFIRMED** — Works with return-count signature |
| 4 | Copyable elements compatibility | **CONFIRMED** — All patterns work for Copyable elements |
| 5 | `@_rawLayout` conditional Copyable | **CONFIRMED** — Compile error: always ~Copyable |
| 6 | `InlineArray` backing + deinit | **CRASHED** — swift_retain failure during deinit |
| 7 | Consuming params + closure capture | **CONFIRMED** — Cannot capture; must use direct pointer |

### Critical Finding: deinit + Conditional Copyable Incompatibility

**Swift constraint**: Types with `deinit` cannot conditionally conform to `Copyable`, even with generic parameters.

```swift
// This FAILS:
struct Storage<Element: ~Copyable>: ~Copyable {
    deinit { /* cleanup */ }
}
extension Storage: Copyable where Element: Copyable {}
// Error: deinitializer cannot be declared in generic struct that conforms to 'Copyable'
```

**Implication**: Any storage type that needs to clean up `~Copyable` elements:
1. MUST have a `deinit` (to call element destructors)
2. CANNOT conditionally conform to `Copyable` (Swift constraint)
3. Therefore MUST be unconditionally `~Copyable`

This is not a bug — it's a fundamental language constraint. The compiler cannot emit correct code for a type that is sometimes Copyable (trivially destructible) and sometimes has a deinit.

---

## Outcome

**Status**: DECISION

### Decision 1: The current architecture is correct

`Vector.Inline` uses `Storage.Inline` which uses `@_rawLayout` and has a `deinit`. This design is correct:
- `@_rawLayout` provides optimal memory layout for ANY element type
- `deinit` ensures proper cleanup of `~Copyable` elements
- The type is unconditionally `~Copyable`, which is the only possible design

### Decision 2: Add ~Copyable initializers

Add the following initializers to `Vector.Inline`:

```swift
extension Vector.Inline where Element: ~Copyable {
    /// Closure-based initialization for ~Copyable elements.
    public init(initializing body: (UnsafeMutablePointer<Element>) -> Void)
}
```

### Decision 3: Do NOT pursue conditional Copyable

Conditional `Copyable` conformance for `Vector.Inline` is **architecturally impossible** due to the Swift language constraint that types with `deinit` cannot conform to `Copyable`. This is not a limitation to work around — it's a fundamental property of the type system.

### Decision 4: Fix the failing tests

The test failure that triggered this research uses an initializer constrained to `Element: Copyable`. The fix is to either:
1. Add `~Copyable` initializers (Decision 2), or
2. Use the closure-based initialization pattern in tests

---

## Resolved Questions

| ID | Question | Resolution |
|----|----------|------------|
| OQ-1 | Should `Vector.Inline` have variadic `init` for small N? | Optional — closure-based init is sufficient |
| OQ-2 | Should backing type selection be automatic or explicit? | N/A — `@_rawLayout` handles this automatically |
| OQ-3 | Is conditional Copyable needed for Vector.Inline? | **IMPOSSIBLE** — deinit requirement blocks it |

---

## References

### Internal
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/storage-ownership-reference-synthesis.md`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Experiments/inline-storage-best-of-both-worlds/`
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Experiments/rawlayout-noncopyable-elements/`
- `/Users/coen/Developer/swift-institute/Skills/memory/SKILL.md` [MEM-COPY-004]
- `/Users/coen/Developer/swift-institute/Skills/copyable-remediation/SKILL.md`

### Swift Evolution
- SE-0390: Noncopyable Structs and Enums
- SE-0437: Noncopyable Standard Library Primitives
- SE-0447: Span — Safe Access to Contiguous Storage
