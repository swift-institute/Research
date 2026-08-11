# Ring Buffer Index Arithmetic: Type-Safe Modular Operations

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 3
applies_to: [swift-index-primitives, swift-queue-primitives, swift-deque-primitives]
---
-->

## Abstract

This research document analyzes the design of ring buffer arithmetic operators for the `Index<Element>` type system. Ring buffers require modular arithmetic patterns (`(index + 1) % capacity`) that must be expressed through typed operations while maintaining the affine space semantics that distinguish positions (points) from displacements (vectors). We examine three candidate designs, evaluate them against formal semantic criteria, and recommend an approach that preserves type safety without introducing unsafe operations.

---

## 1. Context

### 1.1 Trigger

During implementation of Queue Primitives variant modules (Queue.Bounded, Queue.Dynamic), the following pattern is needed repeatedly:

```swift
_storage.header.tail = (tail + 1) % capacity
_storage.header.count += 1
```

Where:
- `tail: Index<Element>` — typed position
- `capacity` — ring buffer size
- `count: Index<Element>.Count` — typed count

The existing `Index + Offset -> Index?` returns optional (guards against negative results), but ring buffer arithmetic has invariants that guarantee non-negative results when followed by modulo.

### 1.2 Constraints

1. **No unsafe Int arithmetic**: Adding `Index + Int -> Index` would bypass the affine type system
2. **Preserve affine semantics**: Points and vectors remain distinct types
3. **Maintain API ergonomics**: Clean syntax for common ring buffer patterns
4. **Type consistency**: `capacity` should be typed as `Index<Element>.Count` (same unit as `count`)

### 1.3 Design Question

How should the Index type system support ring buffer modular arithmetic while preserving type safety and affine semantics?

---

## 2. Prior Art Survey

### 2.1 Swift Evolution

**SE-0322 (Temporary Buffers)**: Uses raw `Int` indexing throughout. No typed index system.

**SE-0370 (Pointer Family Improvements)**: Introduces `UnsafePointer.distance(to:)` returning `Int`. Maintains Int-based pointer arithmetic.

**Swift Standard Library Ring Buffers**: `Deque` (swift-collections) uses raw `Int` for head/tail indices. No type-safe index abstraction.

### 2.2 Related Languages

#### Rust

Rust's `std::collections::VecDeque` uses `usize` (unsigned) for indices with wrapping arithmetic:

```rust
self.tail = self.wrap_add(self.tail, 1);

fn wrap_add(&self, idx: usize, addend: usize) -> usize {
    wrap_index(idx.wrapping_add(addend), self.cap())
}
```

Key insight: Rust encapsulates the wrap operation in a method rather than exposing raw modulo.

#### Haskell

Haskell's `Data.Sequence` uses finger trees, not ring buffers. The `vector` package uses raw `Int` indices.

#### OCaml

OCaml's `Queue` module uses a linked list internally. `Circular_buffer` in Jane Street's Core uses `int` with explicit modulo.

### 2.3 Academic Literature

**Affine Types for Memory Safety** (Tov & Pucella, 2011): Establishes that affine types track resource usage but does not address modular arithmetic on affine positions.

**Type-Safe Modular Arithmetic** (various): Most literature focuses on cryptographic contexts where modular arithmetic preserves type (mod n returns same type). Ring buffer indices have different semantics: `position mod capacity -> position`.

---

## 3. Theoretical Grounding

### 3.1 Two Distinct Algebraic Structures

**This section establishes a critical distinction**: `Index<E>` and `Index<E>.Bounded<N>` are not the same type with different constraints. They are **fundamentally different algebraic structures**.

#### Affine Space: `Index<E>`

`Index<E>` implements a 1-dimensional discrete affine space:

- **Points** (`Index<E>`): Positions in the space, non-negative
- **Vectors** (`Index<E>.Offset`): Displacements between points, signed
- **Scalars** (`Index<E>.Count`): Magnitudes, non-negative

Affine operations:
```
Point - Point → Vector     (displacement)
Point + Vector → Point     (translation, may fail if negative)
Point - Vector → Point     (reverse translation, may fail)
Vector + Vector → Vector   (vector addition)
```

Key property: **Points cannot be added to points.** This is intentional and mathematically correct.

#### Cyclic Group: `Index<E>.Bounded<N>`

`Index<E>.Bounded<N>` implements the cyclic group ℤ/Nℤ:

- **Elements**: Equivalence classes `[0], [1], ..., [N-1]`
- **Operation**: Addition modulo N
- **Identity**: `[0]` (`.zero`)
- **Generator**: `[1]` (`.one`)

Cyclic group operations:
```
Element + Element → Element    (group operation, wraps)
Element - Element → Element    (inverse operation, wraps)
```

Key property: **Elements can be added to elements.** This is the group operation in ℤ/Nℤ.

### 3.2 The Phase Transition

**Critical insight**: Moving from `Index<E>` to `Index<E>.Bounded<N>` is not "adding bounds" — it is a **change of algebraic category**.

| Property | `Index<E>` (Affine) | `Index<E>.Bounded<N>` (Cyclic) |
|----------|---------------------|--------------------------------|
| Domain | ℕ (non-negative integers) | ℤ/Nℤ (integers mod N) |
| Point + Point | Undefined | Defined (group operation) |
| Wrap-around | Never | Always |
| Partiality | Yes (translation may fail) | No (all operations total) |
| Use case | Linear iteration | Ring buffers |

This distinction must be explicit in documentation and naming. `Index.Bounded<N>` is not a constrained `Index`; it is a **different mathematical object** that happens to share a naming convention.

### 3.3 Ring Buffer Semantics

A ring buffer of capacity `C` operates in ℤ/Cℤ (integers modulo C). The key insight:

```
(position + offset) mod capacity
```

For **dynamic capacity** (runtime N), this is a **composite operation**:
1. `position + offset` → affine translation (may produce value ≥ capacity or < 0)
2. `mod capacity` → **projection** into valid range [0, capacity)

The `%` operator is a **projection**, not a translation. It discards information (the quotient). This is acceptable for ring buffers but must not be treated as general arithmetic.

For **static capacity** (compile-time N), we use `Index.Bounded<N>` directly, where addition is the native group operation — no projection needed.

### 3.3 Formal Typing

Let `P[E]` denote `Index<E>` (position), `V[E]` denote `Index<E>.Offset` (vector), `C[E]` denote `Index<E>.Count` (count/capacity).

**Existing operations**:
```
(+) : P[E] × V[E] → P[E]?        -- translation (partial: fails if negative)
(-) : P[E] × P[E] → V[E]         -- displacement (total)
(-) : P[E] × V[E] → P[E]?        -- reverse translation (partial)
```

**Proposed operation for ring buffers**:
```
wrapped : P[E] × V[E] × C[E] → P[E]    -- translation with modular wrap (total)
```

Or equivalently:
```
(%) : P[E] × C[E] → P[E]         -- modular projection (total)
```

Combined with existing `(+)`:
```
let intermediate = (position + offset)!  // safe when followed by mod
let result = intermediate % capacity      // projects to valid range
```

---

## 4. Analysis

### 4.1 Option A: Add `Index % Count -> Index` (Projection Operator)

**Description**: Add modulo operator as a **projection** from affine space into a bounded domain.

```swift
@inlinable
public func % <Element: ~Copyable>(
    lhs: Index<Element>,
    rhs: Index<Element>.Count
) -> Index<Element> {
    Index<Element>(__unchecked: (), position: lhs.position.rawValue % rhs.rawValue)
}
```

**Usage**:
```swift
_storage.header.tail = (tail + 1)! % capacity
```

**Advantages**:
- Minimal addition to type system
- Composable with existing `Index + Offset -> Index?`
- Necessary for dynamic-capacity collections where `N` is not compile-time

**Disadvantages**:
- Requires force-unwrap on `(tail + 1)!`
- The unwrap encodes an implicit invariant ("safe because I will immediately project")
- That invariant is not encoded in the type system
- `%` is a **lossy projection**, not a translation — it discards the quotient

**Semantic Constraints**:
- `%` is a **ring-buffer affordance**, not general arithmetic
- Must NOT leak into range iteration or linear traversal contexts
- Must be clearly documented as projection into a circular domain
- Should feel slightly awkward outside cyclic contexts (that's intentional)

**Acceptable for**: Runtime-bounded collections (`Queue.Bounded`, `Queue.Dynamic`)
**Not acceptable for**: Generic algorithms, linear ranges, non-cyclic contexts

### 4.2 Option B: Add Combined `Index.wrapped(by:capacity:) -> Index`

**Description**: Encapsulate the entire ring buffer advancement as a single operation.

```swift
extension Index where Element: ~Copyable {
    @inlinable
    public func wrapped(advancingBy offset: Offset, capacity: Count) -> Index {
        Index(__unchecked: (), position: (position.rawValue + offset.rawValue) % capacity.rawValue)
    }
}
```

**Usage**:
```swift
_storage.header.tail = tail.wrapped(advancingBy: 1, capacity: capacity)
```

**Advantages**:
- No intermediate optional
- Single atomic operation guarantees correctness
- Self-documenting: explicitly shows ring buffer semantic
- Handles negative offsets correctly (retreat with wrap)

**Disadvantages**:
- Longer syntax than `(tail + 1) % capacity`
- Specific to ring buffers (less general)

**Semantic Correctness**:
- Combines translation and projection atomically
- Result always valid regardless of offset sign
- Proper handling: `(position + offset).mod(capacity)` where mod handles negatives

### 4.3 Option C: Make `Index + Offset -> Index` Non-Optional (Unchecked)

**Description**: Add an unchecked variant that doesn't guard against negatives.

```swift
extension Index where Element: ~Copyable {
    @inlinable
    public func advanced(by offset: Offset) -> Index {
        Index(__unchecked: (), position: position.rawValue + offset.rawValue)
    }
}
```

**Usage**:
```swift
_storage.header.tail = tail.advanced(by: 1) % capacity
```

**Advantages**:
- Clean syntax
- General-purpose (not ring-buffer specific)

**Disadvantages**:
- **UNSAFE**: Can produce negative position if offset is negative
- Violates Index invariant (positions are non-negative)
- Caller must ensure safety (shifts burden to user)
- Can be misused outside ring buffer contexts

**Semantic Correctness**:
- **Violates type invariant**: Position can become negative
- Only safe when followed by appropriate modulo
- Not self-documenting: caller must know to apply modulo

### 4.4 Option D: Cyclic Group Arithmetic on `Index.Bounded<N>`

**Description**: Recognize `Index.Bounded<N>` as a **fundamentally different algebraic structure** — not "Index with bounds", but elements of the cyclic group ℤ/Nℤ where `+` and `-` are native group operations.

**Critical framing**: This is NOT an optimization or convenience. It is a **change of algebraic category**:
- `Index<E>`: Affine space — points and vectors are distinct
- `Index<E>.Bounded<N>`: Cyclic group — all elements are equivalent under the group operation

```swift
extension Tagged.Bounded where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    /// The unit element (1) in ℤ/Nℤ — the generator of the cyclic group.
    @inlinable
    public static var one: Self { Self(__unchecked: (), 1) }

    /// Cyclic group addition in ℤ/Nℤ.
    /// This is the GROUP OPERATION, not affine translation.
    @inlinable
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), (lhs.rawValue + rhs.rawValue) % N)
    }

    /// Cyclic group subtraction in ℤ/Nℤ.
    /// This is the INVERSE operation, not affine displacement.
    @inlinable
    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), ((lhs.rawValue - rhs.rawValue) % N + N) % N)
    }
}
```

**Usage** (for `Queue.Static<let capacity: Int>`):
```swift
var _head: Index<Element>.Bounded<capacity>
var _tail: Index<Element>.Bounded<capacity>

_tail = _tail + .one   // cyclic group operation, wraps at capacity
_head = _head + .one   // NOT affine translation — different algebra
```

**Advantages**:
- **Compile-time type safety**: Invalid states are unrepresentable
- **Algebraically correct**: Cyclic group semantics match ring buffer behavior exactly
- **Clean syntax**: `tail + .one` is natural and readable
- **Total operations**: No optionality — all operations are defined

**Disadvantages**:
- Only works when capacity is a compile-time constant
- Requires separate approach for dynamic-capacity collections

**Critical Documentation Requirement**:
The API and documentation MUST make the phase transition explicit:
```swift
/// Bounded indices form a cyclic group ℤ/Nℤ under addition.
///
/// Unlike unbounded `Index<E>` which uses affine space semantics
/// (Point + Vector → Point), bounded indices use cyclic group semantics
/// (Element + Element → Element). This is a different algebraic structure,
/// not merely "Index with bounds checking".
```

**Mathematical Foundation**:
- ℤ/Nℤ is the quotient group of integers modulo N
- Elements are equivalence classes `[0], [1], ..., [N-1]`
- Group operation: `[a] + [b] = [(a + b) mod N]`
- Identity: `[0]` (`.zero`)
- Generator: `[1]` (`.one`)
- Every element has an inverse: `-[a] = [N - a]`
- This is a **finite cyclic group of order N**

### 4.5 Comparison Table

| Criterion | Option A (%) | Option B (wrapped) | Option C (unchecked) | Option D (ℤ/Nℤ) |
|-----------|--------------|--------------------|-----------------------|------------------|
| Type safety | ✓ Runtime | ✓ Runtime | ✗ Can violate | ✓✓ Compile-time |
| Ergonomics | Medium (needs `!`) | Good | Good | Excellent (`tail + .one`) |
| Generality | High (any capacity) | Low | High | Limited (compile-time N) |
| Composability | High | Low | High | High |
| Self-documenting | Medium | High | Low | High (standard `+`/`-`) |
| Handles negatives | Via `!` failure | Correctly wraps | Violates invariant | Correctly wraps |
| Invalid states | Possible at runtime | Possible at runtime | Possible | Unrepresentable |
| Mathematical model | Ad-hoc projection | Ad-hoc | None | Cyclic group ℤ/Nℤ |

---

## 5. Formal Semantics

### 5.1 Typing Rules

**Option A: Modulo**

```
Γ ⊢ p : Position[E]    Γ ⊢ c : Count[E]    c > 0
─────────────────────────────────────────────────
           Γ ⊢ p % c : Position[E]
```

Operational semantics:
```
⟦ p % c ⟧ = Position(⟦p⟧.rawValue mod ⟦c⟧.rawValue)
```

**Option D: Cyclic Group Addition on Bounded**

```
Γ ⊢ a : Bounded[E, N]    Γ ⊢ b : Bounded[E, N]
──────────────────────────────────────────────
         Γ ⊢ a + b : Bounded[E, N]
```

Operational semantics (cyclic group ℤ/Nℤ):
```
⟦ a + b ⟧ = Bounded((⟦a⟧.rawValue + ⟦b⟧.rawValue) mod N)
⟦ a - b ⟧ = Bounded(((⟦a⟧.rawValue - ⟦b⟧.rawValue) mod N + N) mod N)
```

Note: The `((x mod n) + n) mod n` pattern correctly handles negative intermediate values.

**Key distinction**:
- `Index<E>` (unbounded): Affine space semantics — Position + Vector → Position
- `Index<E>.Bounded<N>`: Cyclic group semantics — Element + Element → Element (in ℤ/Nℤ)

### 5.2 Soundness Argument

**Proposition**: For both Option A and Option D, the output is always valid.

**Proof (Option A: `Index % Count`)**:
- Given `p ≥ 0` (Index invariant) and `c > 0` (Count invariant)
- `p mod c` is defined and returns value in `[0, c)`
- Therefore result is valid position ✓

**Proof (Option D: `Bounded + Bounded`)**:
- Given `a, b ∈ [0, N)` (Bounded invariant)
- `(a + b) mod N` returns value in `[0, N)`
- Therefore result is valid Bounded ✓
- For subtraction: `((a - b) mod N + N) mod N` returns value in `[0, N)` for any `a, b ∈ ℤ`
- Therefore result is valid Bounded ✓

**Option C Unsoundness**:
- Given `p ≥ 0`, `v < 0`, `|v| > p`
- `p + v < 0`
- Result violates Position invariant (must be ≥ 0) ✗

**Option D is stronger than Option A**:
- Option A: Runtime guarantee via modulo
- Option D: Compile-time guarantee via type — `Bounded<N>` can only hold values in `[0, N)`

---

## 6. Empirical Validation (Cognitive Dimensions)

### 6.1 Visibility

| Option | API Discovery |
|--------|---------------|
| A (%) | Operators are discoverable via code completion |
| B (wrapped) | Method visible on Index type |
| C (unchecked) | Method visible but danger not apparent |

### 6.2 Consistency

| Option | Consistent with existing APIs? |
|--------|--------------------------------|
| A (%) | Yes: follows Swift's `%` semantics |
| B (wrapped) | Introduces new pattern |
| C (unchecked) | Inconsistent: existing `+` is safe |

### 6.3 Error-Proneness

| Option | Likelihood of misuse |
|--------|----------------------|
| A (%) | Low: force-unwrap signals attention needed |
| B (wrapped) | Very low: encapsulates safety |
| C (unchecked) | **High**: easy to forget modulo |

### 6.4 Role-Expressiveness

| Option | Is purpose clear? |
|--------|-------------------|
| A (%) | Yes: "mod capacity" is clear |
| B (wrapped) | Yes: name explains intent |
| C (unchecked) | No: doesn't indicate ring buffer context |

---

## 7. Recommendation

### 7.1 Primary Recommendation: Option A + D Combined

Implement a **two-tier approach** based on whether capacity is compile-time or runtime:

1. **Compile-time capacity** (`Queue.Static<let capacity: Int>`):
   - Use `Index<Element>.Bounded<capacity>` for head/tail indices
   - Model as cyclic group ℤ/Nℤ with `+` and `-` operators
   - Add `.one` constant as the generator
   - **Type system guarantees** bounds — invalid states unrepresentable

2. **Runtime capacity** (`Queue.Bounded`, `Queue.Dynamic`):
   - Use `Index<Element>` with `Index<Element>.Count` for capacity
   - Add `Index % Count -> Index` for modular projection
   - Runtime bounds checking via typed operations

### 7.2 Rationale

- **Maximum type safety**: Compile-time bounds when possible, runtime bounds otherwise
- **No unsafe operations**: Option C (unchecked advancement) is explicitly rejected
- **No unclear wrappers**: Option B (`wrapped(advancingBy:capacity:)`) rejected — unclear naming
- **Clean syntax**: `tail + .one` for compile-time, `(tail + 1)! % capacity` for runtime
- **Mathematically sound**: Cyclic group semantics for bounded, affine + modulo for unbounded

### 7.3 Implementation Notes

**For `Index.Bounded<N>` (cyclic group ℤ/Nℤ)**:
```swift
extension Tagged.Bounded where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    public static var one: Self { Self(__unchecked: (), 1) }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), (lhs.rawValue + rhs.rawValue) % N)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), ((lhs.rawValue - rhs.rawValue) % N + N) % N)
    }
}
```

**For `Index % Count`**:
```swift
public func % <Element: ~Copyable>(
    lhs: Index<Element>,
    rhs: Index<Element>.Count
) -> Index<Element> {
    Index<Element>(__unchecked: (), position: lhs.position.rawValue % rhs.rawValue)
}
```

### 7.4 Typed Capacity Requirement

For runtime-bounded collections, `capacity` MUST be typed as `Index<Element>.Count`, not `Int`:
- Type consistency with `count`
- Prevents cross-collection capacity confusion
- Enables clean syntax: `count < capacity`, `count == capacity`

---

## 8. Open Questions

1. Should `Count` also support modulo (`Count % Count -> Count`)?
   - Not needed for ring buffers; defer unless use case emerges.

2. What about `Count += 1` and `Count -= 1` shortcuts?
   - These require `Count + Count` semantics with `.one` constant, similar to Bounded.
   - Consider adding `Count.one` and `Count + Count -> Count` in future work.

3. Should `Index.Bounded<N>` also have compound assignment (`+=`, `-=`)?
   - Natural extension: `tail += .one`
   - Implemented in this decision.

4. Should there be an "Algebraic Model" document?
   - Yes. A short document explicitly naming the domains and their allowed operators
   - Would prevent semantic blur as the library evolves
   - Recommended as follow-up work

---

## 9. Outcome

**Status**: DECISION

**Choice**: Implement Option A + D (two-tier approach) with explicit algebraic framing

- **Option A**: `Index % Count -> Index` — projection operator for runtime-bounded collections
- **Option D**: Cyclic group ℤ/Nℤ arithmetic on `Index.Bounded<N>` for compile-time bounded collections

**Accepted**:
- The affine model of `Index`, `Offset`, `Count`
- Optionality of translations (encodes domain validity)
- `Index.Bounded<N>` as a **distinct cyclic abstraction** (not "Index with bounds")
- Static and dynamic capacity as fundamentally different algebraic domains

**Accepted with constraints**:
- `Index % Count -> Index` only if:
  - Clearly documented as a ring-buffer projection
  - Not advertised as general arithmetic
  - Kept out of generic range algorithms

**Rejected**:
- **Option B** (`wrapped(advancingBy:capacity:)`): Layering violation — pushes collection semantics into Index
- **Option C** (unchecked `Index + Offset -> Index`): Dissolves the invariant that makes index-primitives valuable

**Strengthen**:
1. Explicitly frame `Index.Bounded<N>` as **cyclic, not affine** in documentation
2. Add doc comment: "Bounded indices form a cyclic group under addition"
3. Create follow-up "Algebraic Model" document naming domains and allowed operators
4. Ensure `%` does not leak into linear range contexts

**Rationale**:
- Affine for linear domains, cyclic for bounded static domains, explicit projection for dynamic domains
- This keeps index-primitives and range-primitives cleanly aligned
- Prevents collapse into "typed Int arithmetic"

**Implementation Path**:
1. Add `.one`, `+`, `-`, `+=`, `-=` to `Index.Bounded` with cyclic group documentation
2. Add `Index % Count -> Index` with projection semantics documentation
3. Type `Queue.Storage.capacity` as `Index<Element>.Count`
4. Update `Queue.Static` to use `Index<Element>.Bounded<capacity>` for head/tail
5. Update Queue variant modules to use typed operations
6. (Follow-up) Create "Algebraic Model" reference document

**Date**: 2026-01-26

---

## 10. References

- [Index Type Safety Audit](Index%20Type%20Safety%20Audit.md) — Prior research on Index type system
- Tov, J. A., & Pucella, R. (2011). Practical Affine Types. POPL.
- Rust `VecDeque` implementation: https://doc.rust-lang.org/src/alloc/collections/vec_deque/mod.rs.html
- Swift Evolution SE-0322, SE-0370


### Deferral

**Date**: 2026-03-15

**Reason**: The decision (Option A + D combined: `Index % Count` for runtime-bounded and cyclic group arithmetic on `Index.Bounded<N>` for compile-time bounded collections) was reached on 2026-01-26. Implementation was blocked by the subsequent buffer-primitives inline module split in February 2026, which restructured the queue and buffer packages that are the primary consumers of this design. The implementation path (steps 1-6 in Section 9) has not been started.

**Resume when**: Buffer-primitives inline module restructuring is stable and queue-primitives are ready to adopt the new index arithmetic operators.
