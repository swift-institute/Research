# Span Access Abstraction

<!--
---
version: 1.0.0
last_updated: 2026-01-23
status: DECISION
tier: 3
---
-->

## Context

While implementing span-based access patterns for `swift-set-primitives`, a fundamental design question arose: **Should span access be formalized via protocols, or should types simply provide span methods directly?**

This decision affects:
- All container types in swift-primitives (61+ packages)
- The ability to write generic code over span-providing types
- API consistency across the primitives layer
- Conceptual model for safe memory access

**Trigger**: Implementation of `Set.Ordered` span access revealed uncertainty about abstraction level.

**Constraints**:
- Must support `~Copyable` types
- Must work with both heap-allocated (stable address) and inline (moving) storage
- Should follow [API-NAME-001] Nest.Name pattern
- Should minimize unnecessary abstraction per YAGNI

**Precedent Risk**: HIGH - This decision establishes the pattern for safe memory access across the entire primitives ecosystem. Reversal would require coordinated changes to many packages.

---

## Question

How should span access be abstracted in swift-primitives?

**Sub-questions**:
1. Should there be protocols defining span access requirements?
2. If protocols exist, where should they live (which package/tier)?
3. What is the relationship between span access and sequence/collection protocols?
4. How should property-based vs closure-based access be distinguished?

---

## Prior Art Survey

### Swift Standard Library

Swift 6+ introduces `Span<Element>` and `MutableSpan<Element>` as safe views into contiguous memory:

```swift
struct Span<Element: ~Copyable>: Copyable, ~Escapable { ... }
struct MutableSpan<Element: ~Copyable>: ~Copyable, ~Escapable { ... }
```

**Key characteristics**:
- `Span` is `Copyable` but `~Escapable` (cannot outlive source)
- `MutableSpan` is `~Copyable` and `~Escapable` (unique access)
- Lifetime tied to source via `@_lifetime` annotations

**stdlib patterns**:
- `Array.withUnsafeBufferPointer(_:)` - closure-based unsafe access
- `ContiguousArray` provides direct buffer access
- No stdlib protocol for "types that provide span access"

### Swift Evolution

**SE-0447: Span - Safe Access to Contiguous Storage** (Accepted):
- Introduces `Span` and `MutableSpan` types
- Does NOT introduce protocols for span-providing types
- Relies on convention: types that can provide spans simply implement the methods

**SE-0437: Non-Copyable Standard Library Primitives**:
- Establishes `~Copyable` support patterns
- `Span` designed to work with non-copyable elements

### Rust

Rust's approach to contiguous memory views:

```rust
// Slice types are built into the language
&[T]      // immutable slice (comparable to Span)
&mut [T]  // mutable slice (comparable to MutableSpan)

// Traits for types that can deref to slices
trait Deref { type Target; fn deref(&self) -> &Self::Target; }
trait AsRef<T> { fn as_ref(&self) -> &T; }
```

**Key insight**: Rust uses `Deref` and `AsRef` traits to abstract over "types that can provide slice access." This enables generic programming:

```rust
fn process<T: AsRef<[u8]>>(data: T) {
    let slice: &[u8] = data.as_ref();
    // ...
}
```

### C++20 Ranges

C++ uses concepts (compile-time predicates) to constrain types:

```cpp
template<typename T>
concept contiguous_range =
    ranges::range<T> &&
    requires(T& t) { ranges::data(t); } &&
    // ...
```

**Key insight**: `contiguous_range` is a concept that containers opt into. Generic code can require `contiguous_range` to ensure `data()` availability.

### Haskell

Haskell's `vector` library uses type classes:

```haskell
class Vector v a where
    basicUnsafeSlice :: Int -> Int -> v a -> v a
    basicLength :: v a -> Int
    -- ...
```

**Key insight**: Type classes (Haskell's protocols) enable generic programming over vector-like types with different representations.

---

## Theoretical Grounding

### Type-Theoretic Perspective

Span access can be modeled as a **coercion** or **view** relationship:

```
SpanCoercible(T, E) ≡ ∃ span : T → Span<E>
```

A type `T` is span-coercible to element type `E` if there exists a (safe) function producing a `Span<E>`.

**Protocol abstraction** makes this relationship explicit in the type system:

```swift
protocol SpanProtocol {
    associatedtype Element
    var span: Span<Element> { get }
}
```

**Ad-hoc methods** leave the relationship implicit - types simply happen to have compatible methods.

### Parametricity and Generic Programming

From Reynolds' parametricity perspective, protocols enable **relational reasoning**:

- With protocol: `∀T: SpanProtocol. f(T)` - function works for ALL span-providing types
- Without protocol: Must enumerate specific types or use overloading

**Trade-off**: Protocol abstraction enables parametric polymorphism; ad-hoc methods require concrete type knowledge.

### Linear/Affine Type Theory

`MutableSpan` exhibits **affine** behavior (use at most once for exclusive access):

```
Γ, x: MutableSpan<E> ⊢ e : T
────────────────────────────── (Affine)
x not used after e
```

Protocol abstraction for mutable span access must preserve this affine discipline. The `~Copyable` marker on `MutableSpan` enforces this.

---

## Systematic Literature Review

### Research Questions

**RQ1**: What abstraction mechanisms do languages use for safe contiguous memory access?

**RQ2**: What are the trade-offs between protocol-based and ad-hoc abstraction for memory views?

**RQ3**: How do existing Swift packages abstract span-like access?

### Search Strategy

**Databases**: ACM DL, arXiv, Swift Forums, GitHub

**Keywords**: "span", "slice", "contiguous memory", "buffer protocol", "array view", "safe memory access"

**Date range**: 2015-2026 (covers Rust stabilization through Swift 6)

### Inclusion/Exclusion Criteria

**Include**:
- Language design documents for memory view types
- Academic papers on safe memory abstractions
- Major library implementations (stdlib, boost, etc.)

**Exclude**:
- Application-specific memory management
- Unsafe/unchecked access patterns
- Pre-2015 approaches (outdated memory models)

### Findings Synthesis

| Approach | Languages | Protocol-like Abstraction | Ergonomics | Generic Programming |
|----------|-----------|---------------------------|------------|---------------------|
| Built-in slice types | Rust, Go | Yes (Deref, AsRef) | High | Full support |
| Library view types | Swift, C++ | Optional (concepts) | Medium | With explicit opt-in |
| Type classes | Haskell | Yes (Vector class) | Medium | Full support |
| Ad-hoc methods | Swift stdlib | No | High for concrete | Limited |

**Key finding**: Languages that support robust generic programming over contiguous views **all** provide some form of protocol/trait/concept abstraction. Ad-hoc methods work for concrete usage but limit abstraction.

---

## Formal Semantics

### Typing Rules for Span Access

**Property-based access** (stable storage):

```
Γ ⊢ c : Container<E>    Container<E> : SpanProtocol
──────────────────────────────────────────────────── (T-Span)
Γ ⊢ c.span : Span<E>    lifetime(c.span) ⊆ lifetime(c)
```

**Closure-based access** (inline storage):

```
Γ ⊢ c : Container<E>    Container<E> : SpanScopedProtocol
Γ, s : Span<E> ⊢ body : R    lifetime(s) ⊆ scope(body)
──────────────────────────────────────────────────────────── (T-WithSpan)
Γ ⊢ c.withSpan(body) : R
```

### Soundness Argument

**Claim**: Protocol-based span access preserves memory safety.

**Argument sketch**:
1. `Span<E>` is `~Escapable`, preventing escape beyond source lifetime
2. Protocol requirement `var span: Span<E>` is satisfied by conforming types
3. Conforming types guarantee valid memory backing the span
4. Lifetime annotations (`@_lifetime(borrow self)`) enforce borrowing discipline
5. Therefore: span cannot outlive valid memory ∎

For closure-based access, the closure scope bounds the span lifetime explicitly.

---

## Analysis

### Option 1: Protocol Abstraction

**Description**: Define protocols in a dedicated package that types conform to.

```swift
// Span.Protocol - requires span property
// Span.Mutable.Protocol - requires mutableSpan property
// Span.Scoped.Protocol - requires withSpan method
// Span.Scoped.Mutable.Protocol - requires withMutableSpan method
```

**Advantages**:
- Enables generic programming: `func process<T: Span.Protocol>(_ c: T)`
- Documents capability in type system
- Consistent with Rust/Haskell approaches
- Enables protocol-based extensions

**Disadvantages**:
- Adds abstraction layer
- Requires separate package or placement decision
- Conformance ceremony for each type
- May be YAGNI if generic span code is rare

### Option 2: Ad-hoc Methods (No Protocol)

**Description**: Types simply provide `span`, `mutableSpan`, `withSpan`, `withMutableSpan` methods by convention.

```swift
extension Set.Ordered {
    var span: Span<Element> { ... }
    var mutableSpan: MutableSpan<Element> { ... }
}
```

**Advantages**:
- Simpler - no protocol ceremony
- Matches Swift stdlib approach
- Lower cognitive overhead
- YAGNI compliant if generic code is rare

**Disadvantages**:
- No generic programming over span-providers
- Convention-based (no compiler enforcement)
- Cannot write `where T: SpanProviding`
- Inconsistent with our protocol-heavy architecture

### Option 3: Extension on Sequence.Protocol

**Description**: Add span methods to `Sequence.Protocol` or as optional requirements.

```swift
extension Sequence.Protocol where Self: /* has contiguous storage */ {
    var span: Span<Element> { ... }
}
```

**Advantages**:
- Ties span to existing abstraction
- No new protocol

**Disadvantages**:
- Not all sequences have contiguous storage (linked lists, generators)
- Conflates iteration with memory layout
- Semantically incorrect - span is about storage, not iteration

### Option 4: Marker Protocol (Minimal)

**Description**: Single marker protocol indicating "this type provides span access" without specifying how.

```swift
protocol SpanProviding: ~Copyable {
    associatedtype Element
}

// Types conform but implement methods conventionally
extension Set.Ordered: SpanProviding { }
```

**Advantages**:
- Minimal ceremony
- Enables `where T: SpanProviding` constraints
- Methods remain conventional

**Disadvantages**:
- Marker only - no method requirements
- Still need convention for actual methods
- Halfway solution

### Comparison Table

| Criterion | Protocol | Ad-hoc | Sequence Ext | Marker |
|-----------|----------|--------|--------------|--------|
| Generic programming | ✓ | ✗ | ✗ | Partial |
| Type-system documentation | ✓ | ✗ | ✗ | ✓ |
| Simplicity | Low | High | Medium | Medium |
| Semantic correctness | ✓ | ✓ | ✗ | ✓ |
| Matches prior art | ✓ | Partial | ✗ | ✗ |
| YAGNI compliance | ? | ✓ | ✓ | ✓ |
| Compiler enforcement | ✓ | ✗ | ✗ | ✗ |

---

## Empirical Validation (Cognitive Dimensions)

| Dimension | Protocol | Ad-hoc | Assessment |
|-----------|----------|--------|------------|
| **Visibility** | High - protocol conformance visible | Medium - must check for methods | Protocol better for discovery |
| **Consistency** | High - all span types look same | Medium - convention-dependent | Protocol ensures consistency |
| **Viscosity** | Medium - conformance needed | Low - just add methods | Ad-hoc easier to change |
| **Role-expressiveness** | High - protocol states intent | Low - methods are implicit | Protocol clearer |
| **Error-proneness** | Low - compiler checks | Medium - convention violations | Protocol safer |
| **Abstraction** | Appropriate for generic code | Over-abstraction concern | Depends on use case |

---

## Critical Question: Is Generic Span Code Needed?

The protocol vs ad-hoc decision hinges on whether we need:

```swift
func process<T: Span.Protocol>(_ container: T) {
    let span = container.span
    // generic processing
}
```

**Evidence for generic span code**:
- Algorithms operating on contiguous memory (sorting, searching, copying)
- Serialization/deserialization working with any span-providing type
- Testing utilities that verify span behavior

**Evidence against**:
- Most span usage is concrete: `array.span`, `set.span`
- Swift stdlib doesn't provide span protocols
- YAGNI - can add protocols later if needed

---

## Outcome

**Status**: DECIDED

**Decision**: **Option 2 - Ad-hoc Methods (No Protocol)**

Types provide `span`, `mutableSpan`, `withSpan`, and `withMutableSpan` methods by convention, without protocol abstraction.

**Rationale**:

1. **YAGNI**: No concrete use case identified for generic span code in swift-primitives
2. **Prior art reality check**: Even Rust, despite providing `AsRef<[T]>`, uses concrete `&[T]` types in the vast majority of code. The "Full support" characterization in the literature review overstated actual usage patterns.
3. **Swift stdlib alignment**: Standard library uses ad-hoc approach for span access
4. **Reversibility**: Protocols can be added later if genuine need emerges
5. **Simplicity**: No ceremony, no hoisting workarounds, no additional packages

**Implementation**:

Container types in swift-primitives provide these methods directly:

| Storage Type | Access Pattern | Method |
|-------------|----------------|--------|
| Heap (stable address) | Read | `var span: Span<Element>` |
| Heap (stable address) | Write | `var mutableSpan: MutableSpan<Element>` |
| Inline (moving storage) | Read | `func withSpan<R>(_ body: (Span<Element>) -> R) -> R` |
| Inline (moving storage) | Write | `mutating func withMutableSpan<R>(_ body: (inout MutableSpan<Element>) -> R) -> R` |

**Artifacts removed**:
- `Property.Span.Protocol` and related protocols (property-primitives)
- `Sequence.Span.Protocol` and related protocols (sequence-primitives)
- All conformance extensions in set-primitives

**Decision date**: 2026-01-23

---

## References

- SE-0447: Span - Safe Access to Contiguous Storage
- SE-0437: Non-Copyable Standard Library Primitives
- Rust Reference: Slice types and Deref trait
- C++20 Ranges: contiguous_range concept
- Reynolds, J. (1983). Types, Abstraction and Parametric Polymorphism
- Kitchenham, B. (2004). Procedures for Performing Systematic Reviews
