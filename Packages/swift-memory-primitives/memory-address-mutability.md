# Memory Address Mutability: Capability vs Position

<!--
---
version: 1.1.0
last_updated: 2026-01-28
status: IMPLEMENTED
tier: 3
---
-->

## Context

While refactoring `swift-memory-primitives` to use the ordinal/cardinal/affine pattern, we discovered that `Memory.Address.Mutable` creates a type collision with `Pointer<T>.Mutable` when both define nested `struct Mutable` in `Tagged` extensions.

This raised a deeper question: Should mutable addresses exist as a separate type at all, or is mutability orthogonal to address representation?

**Trigger**: Type collision during swift-pointer-primitives integration
**Constraints**: Must align with primitives philosophy of "timeless infrastructure"
**Scope**: Ecosystem-wide (affects Memory, Pointer, Index primitives)
**Precedent Risk**: High—establishes foundational semantics for memory model

## Research Questions

**RQ1**: What is the semantic nature of a memory address—a *capability* (carrying permissions) or a *position* (neutral location)?

**RQ2**: What design patterns do related systems use for distinguishing read vs write memory access?

**RQ3**: Does separating mutable/immutable address types provide meaningful type safety, or does it conflate pointer semantics with address semantics?

**RQ4**: What formal type-theoretic model best captures the intended semantics?

---

## Systematic Literature Review

### Search Strategy

**Databases**: Swift Evolution, Rust RFC, C++ Standards, ACM Digital Library, arXiv
**Keywords**: "memory address", "pointer capability", "linear types", "affine types", "memory safety", "capability-based addressing"
**Date Range**: 2010-2026

### Inclusion Criteria

- Directly addresses memory address vs pointer distinction
- Discusses type-level representation of memory access permissions
- Relevant to systems programming language design

### Exclusion Criteria

- Pure hardware/architecture papers without type system implications
- Security-focused capability systems without type-level relevance

---

## Prior Art Survey

### Swift Evolution

**SE-0138 UnsafeRawPointer**: Introduced `UnsafeRawPointer` and `UnsafeMutableRawPointer` as separate types.

> "The type system should distinguish between typed and raw pointers, and between pointers that allow mutation and those that do not."

**Key insight**: Swift chose **separate types** for mutability at the **pointer** level, not the address level. An address is implicitly the bit pattern; the pointer type carries the capability.

**SE-0370 Typed throws**: Demonstrates Swift's pattern of encoding capability in type parameters rather than separate types when the underlying representation is identical.

### Rust

Rust uses `*const T` and `*mut T` as separate pointer types. However, Rust explicitly distinguishes:

- **Address**: The numeric value (obtainable via `addr()`)
- **Provenance**: The permission/capability attached to a pointer

From the Strict Provenance experiment (rust-lang/rust#95228):

> "A pointer is an *address* plus *provenance*. The address is just a number. The provenance tracks which allocation the pointer is allowed to access."

**Key insight**: Rust separates **address** (numeric) from **provenance** (capability). This aligns with treating addresses as positions, not capabilities.

### C/C++

C17 and C++20 define pointer types with mutability baked in (`const` qualification). However:

- `uintptr_t` represents an address as a pure integer
- Converting between `uintptr_t` and pointers is implementation-defined
- The address itself carries no capability—capability is in the pointer type

**Key insight**: C/C++ treat the numeric address as capability-free; capability lives in the pointer.

### CHERI (Capability Hardware Enhanced RISC Instructions)

CHERI is a capability-based security architecture where pointers are "fat" (carry bounds and permissions).

From "An Introduction to CHERI" (University of Cambridge):

> "A CHERI capability is a pointer augmented with bounds and permissions... The address alone does not grant access; the capability does."

**Key insight**: Even in explicit capability systems, the **address component** is just a number. Capability is metadata attached to the pointer, not inherent to the address.

### Academic Literature

**"Substructural Type Systems" (Walker, 2005)**:
Linear and affine type systems track resource usage at the type level. The key insight: tracking is about **what you can do** (capability), not **where something is** (position).

**"Separation Logic" (Reynolds, 2002)**:
Separation logic reasons about heap locations using assertions about **permissions** to access locations. The location itself is a value; access permission is a separate predicate.

---

## Theoretical Grounding

### Type-Theoretic Analysis

Consider two models:

**Model A: Address as Capability**
```
Address ≠ MutableAddress    (different types)
Address : Position × Permission
```

In this model, the address type encodes whether you can read or write. This conflates two orthogonal concerns:
1. Where something is (position)
2. What you can do with it (permission)

**Model B: Address as Position**
```
Address : Position          (just a number)
Pointer<T> : Address × Permission × Type
```

In this model:
- Address is purely positional (ordinal in affine space)
- Permission lives in the pointer type
- The address can be freely converted; the pointer enforces access control

### Affine Space Interpretation

Memory can be modeled as an affine space where:
- **Points** (addresses) are positions
- **Vectors** (offsets) are displacements
- **Torsor** structure: `Address + Offset → Address`, `Address - Address → Offset`

An affine point has no intrinsic "mutability"—it's just a location. Mutability is a property of the **operation** you perform at that location, not the location itself.

### Formal Typing Rules

**Model A** (Address encodes capability):
```
Γ ⊢ a : MutableAddress
─────────────────────────
Γ ⊢ store(a, v) : Unit

Γ ⊢ a : Address
───────────────────── (cannot store)
Γ ⊢ load(a) : T
```

**Model B** (Address is neutral, operation requires capability):
```
Γ ⊢ a : Address    Γ ⊢ p : WritePermission(a)
─────────────────────────────────────────────
Γ ⊢ store(p, v) : Unit

Γ ⊢ a : Address    Γ ⊢ p : ReadPermission(a)
────────────────────────────────────────────
Γ ⊢ load(p) : T
```

In Model B, the **permission** is explicit and tracked separately from the address.

### Soundness Argument

**Claim**: Model B (address as position) provides cleaner separation of concerns and aligns with the ordinal/affine architecture.

**Argument**:
1. `Memory.Address = Tagged<Memory, Ordinal>` represents a position in memory space
2. Ordinals are pure positions—they don't carry capabilities
3. Adding mutability to the address conflates position with permission
4. Permission should live in the pointer type (`UnsafeMutableRawPointer`)

**Counter-argument for Model A**:
- Type safety: Having `MutableAddress` prevents accidentally passing a "mutable handle" where an immutable one is expected
- API clarity: Methods that mutate memory only accept `MutableAddress`

**Rebuttal**: The counter-argument conflates addresses with pointers. A `Memory.Address` is not a handle—it's a numeric position. The handle is the `UnsafeMutableRawPointer` obtained from the address. Swift already enforces mutability at the pointer level.

---

## Empirical Validation (Cognitive Dimensions)

### Visibility
**Model A**: Two types (`Address`, `Address.Mutable`) may confuse users about when to use which
**Model B**: Single `Address` type with clear semantics—"it's just a position"

**Advantage**: Model B

### Consistency
**Model A**: Creates parallel hierarchies (`Address`/`Address.Mutable`, `Pointer`/`Pointer.Mutable`, `Buffer`/`Buffer.Mutable`)
**Model B**: Addresses are positions; only pointers/buffers have mutable variants (matching actual capability)

**Advantage**: Model B

### Role-Expressiveness
**Model A**: `MutableAddress` suggests the address itself is mutable (it's not—it's a value type)
**Model B**: `Address` clearly represents a location; what you do there depends on your pointer

**Advantage**: Model B

### Error-Proneness
**Model A**: Possible confusion between address mutability and pointee mutability
**Model B**: Clear distinction—address is where, pointer is how you access

**Advantage**: Model B

### Abstraction Level
**Model A**: Mixes position abstraction with capability abstraction
**Model B**: Clean separation—ordinal for position, pointer type for capability

**Advantage**: Model B

---

## Analysis of Current Implementation

### Current `Memory.Address.Mutable` Operations

| Operation | Semantics | Requires Mutable Pointer? |
|-----------|-----------|---------------------------|
| `allocate()` | Create new memory | Yes (returns mutable) |
| `deallocate()` | Free memory | Yes |
| `initialize()` | Write to uninitialized memory | Yes |
| `store()` | Write to memory | Yes |
| `read()` | Read from memory | No |
| `copy()` | Copy bytes | Yes (destination) |
| `bind()` | Bind memory to type | Yes |
| `advanced(by:)` | Pointer arithmetic | No (pure address math) |

**Observation**: Operations fall into two categories:
1. **Address operations** (arithmetic): Don't need mutability concept
2. **Pointer operations** (load/store/initialize): Require mutable pointer at stdlib level

The current `Memory.Address.Mutable` bundles both, but they're conceptually distinct.

### What Would Change

**If we remove `Memory.Address.Mutable`**:

1. `Memory.Address` remains as `Tagged<Memory, Ordinal>` (position only)
2. Allocation returns `Memory.Address` (the position of allocated memory)
3. To mutate, caller obtains `mutableRawPointer` from the address
4. Mutation operations live on stdlib pointer extensions (already exist)

**API comparison**:

```swift
// Current (with Memory.Address.Mutable)
let addr = Memory.Address.Mutable.allocate(count: 100, alignment: 8)
addr.store(42, as: Int.self)
addr.deallocate()

// Proposed (without Memory.Address.Mutable)
let addr = Memory.Address.allocate(count: 100, alignment: 8)
addr.mutableRawPointer.store.bytes(of: 42, as: Int.self)
addr.mutableRawPointer.deallocate()
```

**Trade-off**: Slightly more verbose, but semantically clearer.

---

## Synthesis

### Research Question Answers

**RQ1**: A memory address is semantically a **position**, not a capability. This aligns with:
- Rust's strict provenance model (address ≠ provenance)
- C/C++'s `uintptr_t` (address as number)
- CHERI's separation of address from capability
- Affine geometry (points are positions)

**RQ2**: Related systems universally separate address (position) from pointer (capability):
- Swift: `UnsafeRawPointer` vs `UnsafeMutableRawPointer`
- Rust: `*const T` vs `*mut T`, with address extraction via `addr()`
- C: `uintptr_t` for address, `const T*` vs `T*` for pointers

**RQ3**: Separating `Memory.Address` from `Memory.Address.Mutable` conflates address and pointer semantics. The type safety benefit is better provided by the stdlib pointer types (`UnsafeMutableRawPointer`), which is where capability actually lives.

**RQ4**: The ordinal model (`Memory.Address = Tagged<Memory, Ordinal>`) correctly captures address-as-position. Capability should be modeled at the pointer level, not the address level.

### Options

**Option A: Keep `Memory.Address.Mutable`**
- Provides type-level distinction
- Creates parallel hierarchies
- Conflates address with pointer semantics
- Causes type collision with `Pointer<T>.Mutable`

**Option B: Remove `Memory.Address.Mutable`**
- `Memory.Address` is purely positional
- Mutation requires explicit pointer access
- Aligns with ordinal/affine model
- Eliminates type collision
- Matches industry practice (Rust, CHERI)

**Option C: Refactor to namespace pattern**
- Keep both types but restructure to avoid collision
- Preserves existing API
- Doesn't address semantic concern

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Semantic correctness | Conflated | Clean | Conflated |
| Industry alignment | Partial | Strong | Partial |
| Type collision | Yes | No | No |
| API verbosity | Low | Medium | Low |
| Ordinal model fit | Poor | Excellent | Poor |
| Implementation effort | None | Medium | Medium |

---

## Outcome

**Status**: RECOMMENDATION

**Choice**: Option B — Remove `Memory.Address.Mutable`

**Rationale**:

1. **Semantic clarity**: An address is a position in memory space, not a capability. The ordinal model (`Tagged<Memory, Ordinal>`) correctly captures this.

2. **Industry precedent**: Rust's strict provenance, CHERI, and C's `uintptr_t` all separate address from capability.

3. **Type-theoretic soundness**: Affine points don't have intrinsic mutability. Capability belongs at the pointer level.

4. **Practical benefit**: Eliminates the `Tagged.Mutable` collision that blocks pointer-primitives.

5. **Consistency**: Memory addresses become purely positional, matching how `Index<T>` is purely positional for element indexing.

**Implementation Notes**:

1. Remove `Memory.Address.Mutable.swift` from umbrella target
2. Add `allocate()` as static method on `Memory.Address` returning the position
3. Update callers to use `.mutableRawPointer` for mutation operations
4. The stdlib extensions (`.memory.*`, `.store.*`) provide the mutation API

**Migration Path**:
```swift
// Before
let addr: Memory.Address.Mutable = .allocate(count: n, alignment: a)
addr.store(value, as: T.self)

// After
let addr: Memory.Address = .allocate(count: n, alignment: a)
addr.mutableRawPointer.store.bytes(of: value, as: T.self)
```

**Follow-up**: With `Memory.Address.Mutable` removed, `Pointer<T>.Mutable` can remain as a nested struct in `Tagged` extension without collision. The pointer-primitives refactoring becomes simpler.

---

## References

- SE-0138: UnsafeRawPointer API
- rust-lang/rust#95228: Strict Provenance experiment
- University of Cambridge: "An Introduction to CHERI"
- Walker, D. (2005): Substructural Type Systems
- Reynolds, J.C. (2002): Separation Logic: A Logic for Shared Mutable Data Structures
- Swift Institute: Affine Primitives documentation
