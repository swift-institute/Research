# Algebra and ADT Package Relationship

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
---
-->

## Context

The swift-primitives ecosystem has two families of packages that interact:

**Algebraic packages** (operations, structure):
- `algebra-primitives` (tier 8) — algebraic witness types: Magma, Semigroup, Monoid, Group, Ring, Field, Module, VectorSpace
- `algebra-linear-primitives` (tier 11) — linear algebra: `Linear.Vector<N>`, `Linear.Matrix<M,N>`, dot/cross products, norms, rotations
- `numeric-primitives` (tier 9) — numeric operations, Scale, transcendentals

**Container/ADT packages** (data structures):
- `vector-primitives` (tier 10) — fixed-dimension `Vector<Element, N>` with heap (CoW) and inline variants
- `matrix-primitives` (tier 12) — declared but empty
- `bit-vector-primitives` (tier 12) — packed bit storage
- `buffer-primitives` (tier 15) — ring, linear, slab buffers

The trigger: Analysis of vector-primitives (see `vector-primitives-role-and-dependency-analysis.md`) revealed that `algebra-linear-primitives` depends on `vector-primitives` but barely uses it — `Linear.Vector<N>` wraps `Vector<Scalar, N>.Inline` but only touches `.elements` (the `InlineArray`). Meanwhile, `vector-primitives` itself depends on `algebra-primitives` (pulling algebraic witnesses into a container package). The dependency arrows seem backwards or unnecessary.

This raises a fundamental architectural question: what should the relationship between algebra packages and ADT/container packages be?

## Question

What is the correct dependency relationship between algebraic operation packages and abstract data type (container) packages in the swift-primitives ecosystem?

## Analysis

### Option A: Containers depend on algebra (current partial state)

**Description**: ADT packages like vector-primitives import algebra-primitives to gain access to algebraic structures. The container "knows" it is an algebraic object.

**Current state**: vector-primitives depends on algebra-primitives (tier 8). However, it doesn't actually use any algebraic witnesses — the dependency exists but is functionally dead.

**How this would work fully realized**: `Vector<Element, N>` would conform to algebraic protocols or carry witness values. For example, `Vector<Scalar, N>` would provide an `Algebra.VectorSpace` witness when `Scalar: Field`.

**Advantages**:
- Container types are self-describing algebraically
- Consumer code gets both container and algebra from one import

**Disadvantages**:
- Violates separation of concerns: containers should be about storage, not algebra
- Creates upward pressure on tier numbers (container must be above algebra)
- Every container that could have algebraic structure must import algebra-primitives
- bit-vector-primitives has algebraic structure (Boolean algebra) but correctly does NOT import algebra-primitives — showing this pattern isn't followed consistently
- Not all consumers need algebraic operations on their containers

### Option B: Algebra depends on containers (current algebra-linear state)

**Description**: Algebra packages import container packages to use them as substrates. The algebra package "operates on" the container.

**Current state**: algebra-linear-primitives (tier 11) depends on vector-primitives (tier 10). `Linear.Vector<N>` wraps `Vector<Scalar, N>.Inline`.

**How this would work fully realized**: algebra-linear-primitives provides all vector/matrix operations and uses vector-primitives for storage.

**Advantages**:
- Algebra naturally layers on top of storage
- Container packages stay focused on data structure concerns
- Matches the mathematical intuition: operations act on objects

**Disadvantages**:
- As demonstrated, the substrate adds nothing — `Linear.Vector` only uses `InlineArray` through the wrapper
- Creates a dependency on a container package just for a thin wrapper
- The algebra package ends up reimplementing all operations (dot, cross, norm) without delegating to the container
- `matrix-primitives` exists as a separate package but `Linear.Matrix` lives in algebra-linear-primitives — confused ownership

### Option C: Independent packages with no cross-dependency

**Description**: Container packages and algebra packages are independent. Neither imports the other. Bridge packages or consumer packages compose them.

**Architecture**:
```
                    consumer code
                   /              \
     algebra-linear-primitives    vector-primitives
          |                           |
     algebra-primitives          cyclic-primitives
     dimension-primitives        index-primitives
     numeric-primitives
```

`algebra-linear-primitives` would use `InlineArray<N, Scalar>` directly (no vector-primitives dependency). `vector-primitives` would drop its algebra-primitives dependency (which it doesn't use anyway).

**Advantages**:
- Clean separation of concerns
- Minimal dependency graphs — each package imports only what it actually uses
- Consumers compose what they need
- Follows the five-layer architecture principle: primitives are atomic building blocks
- Each package can evolve independently

**Disadvantages**:
- No shared "vector type" between algebraic and container contexts
- Consumers must choose which vector type to use (or bridge between them)

### Option D: ADTs are pure containers; algebra provides operations via extensions or witnesses

**Description**: Container packages provide storage only. Algebra packages provide operations as extensions on container types (or as standalone functions/witnesses).

**Architecture**:
```
     algebra-linear-primitives (tier 11)
          |            \
     algebra-primitives  vector-primitives
                              |
                         cyclic-primitives
```

algebra-linear-primitives imports vector-primitives and extends `Vector<Scalar, N>` with algebraic operations (dot, cross, norm, etc.) rather than wrapping it in `Linear.Vector`.

**Advantages**:
- Single vector type: `Vector<Scalar, N>` with algebraic operations available when you import algebra-linear
- No wrapper overhead
- Container stays pure; algebra composes on top
- `Linear.Matrix` could similarly be an extension or alias

**Disadvantages**:
- Loses the `Space` phantom type that `Linear<Scalar, Space>` provides for coordinate-system safety
- Extensions can't add stored properties, limiting what algebra can layer on
- Not clear how to handle the `Space` parameter — it's fundamental to Linear's type safety
- Retroactive conformance limitations in Swift

## Comparison

| Criterion | A: Containers→Algebra | B: Algebra→Containers | C: Independent | D: Algebra extends Containers |
|-----------|----------------------|----------------------|----------------|------------------------------|
| Separation of concerns | Poor | Moderate | Excellent | Good |
| Dependency minimality | Poor (8 extra deps) | Poor (thin wrapper) | Excellent | Moderate |
| Tier pressure | High (containers above algebra) | Moderate | None | Moderate |
| Shared type | Container is the type | Wrapper hides container | No shared type | Container is the type |
| Space phantom type | Container needs it | Wrapper provides it | Each has own | Lost or complex |
| Current consistency | Inconsistent (bit-vector doesn't do this) | Inconsistent (wrapper unused) | Would require refactoring | Would require refactoring |
| Mathematical coherence | Container = algebraic object | Operations layered on storage | Orthogonal concerns | Operations decorate storage |

### The `Space` phantom type problem

This is the crux. `Linear<Scalar, Space>.Vector<N>` provides coordinate-system type safety — you can't add a vector in `UserSpace` to one in `DeviceSpace`. This is critical for correctness in geometry code.

If we go with Option C (independent), algebra-linear-primitives needs its own vector type with `Space`. It doesn't need vector-primitives at all — just `InlineArray<N, Scalar>`.

If we go with Option D (algebra extends containers), we'd need `Vector<Scalar, N>` to somehow carry a `Space` parameter, which is domain-specific and doesn't belong in a generic container.

This analysis points toward **Option C with a clarification**: the algebraic vector (`Linear.Vector`) and the container vector (`Vector<Element, N>`) are different types serving different purposes, and forcing one to wrap the other is architecturally wrong.

### Prior art

**Rust**: `nalgebra` (linear algebra) and `Vec<T>` (container) are completely independent. Mathematical vectors are `SVector<T, N>` with their own storage. No one wraps `Vec<T>` in a linear algebra type.

**Haskell**: `Data.Vector` (container) and `Linear.V` (linear algebra, from the `linear` package) are independent. `Linear.V` uses its own fixed-size storage.

**C++ (Eigen)**: `Eigen::Vector3d` and `std::vector<double>` are completely separate concepts. No inheritance or wrapping relationship.

**Swift SIMD**: `SIMD2<Float>`, `SIMD3<Float>` are independent from `Array<Float>`. The stdlib recognizes these are different abstractions.

Every major ecosystem separates mathematical vectors from container vectors. They share a name but not a type.

### The naming question

The word "vector" means different things:
1. **Mathematical vector**: element of a vector space, supports addition and scalar multiplication
2. **Container vector**: fixed-size collection of N elements of type Element
3. **Bit vector**: packed boolean array using word-level operations

These are distinct concepts that happen to share terminology. Forcing them into a shared type hierarchy conflates the abstractions.

## Outcome

**Status**: RECOMMENDATION

### Recommended approach: Option C (independent packages) with dependency cleanup

1. **`algebra-linear-primitives` should NOT depend on `vector-primitives`**.
   - Replace `_storage: Vector_Primitives.Vector<Scalar, N>.Inline` with `_components: InlineArray<N, Scalar>` directly
   - `Linear<Scalar, Space>.Vector<N>` is a mathematical vector with coordinate-space safety — it doesn't need a generic container substrate
   - Remove the vector-primitives dependency (and its 8 transitive deps)

2. **`vector-primitives` should NOT depend on `algebra-primitives`**.
   - The dependency is functionally dead — no algebraic witnesses are used
   - Remove it to reduce the tier footprint

3. **`matrix-primitives` should depend on `algebra-linear-primitives`**, not on vector-primitives directly.
   - `Linear.Matrix` already lives in algebra-linear-primitives
   - If matrix-primitives is meant to provide a container matrix (separate from Linear.Matrix), it should be independent of algebra
   - Clarify: is matrix-primitives an ADT or an algebra package?

4. **`bit-vector-primitives` remains independent** — it correctly does not import algebra despite having algebraic structure (Boolean algebra). The bit operations are domain-intrinsic.

### Resulting dependency graph

```
BEFORE (current):
  algebra-linear (11) → vector (10) → algebra (8)  ← circular conceptual dependency
  matrix (12) → vector (10), algebra-linear (11)

AFTER (recommended):
  algebra-linear (?) → algebra (8), dimension (9), numeric (9)
  vector (?) → cyclic (8), index (6)
  matrix (?) → depends on purpose (see point 3)
  bit-vector (12) → bit (9), bit-index, bit-pack, etc.
```

### Tier impact

- `algebra-linear-primitives` currently tier 11 (via vector at 10). Without the vector dependency, its highest dependency is dimension/numeric at tier 9, making it **tier 10**.
- `vector-primitives` currently tier 10 (via algebra/dimension at 8-9). Without algebra and dimension, its highest dependency is cyclic at tier 8, making it **tier 9**.
- Both packages move DOWN in the tier graph — a strict improvement.

### Design principle to codify

**Statement**: Mathematical types (vectors, matrices, quaternions) and container types (fixed-size arrays, bit vectors, buffers) SHOULD be independent packages. Mathematical types carry domain-specific semantics (coordinate spaces, algebraic structure) that don't belong in generic containers. Generic containers provide storage and access patterns that don't require algebraic knowledge.

This follows the five-layer architecture: primitives are *atomic* building blocks. An atom that is both "container" and "algebraic object" is a molecule, not an atom.

## References

- `swift-primitives/Research/vector-primitives-role-and-dependency-analysis.md` — vector-primitives analysis
- `swift-primitives/Experiments/generic-vector-bit-substrate/` — empirical verification of substrate viability
- `swift-primitives/Documentation.docc/Primitives Tiers.md` — tier definitions
- `swift-institute/Documentation.docc/Five Layer Architecture.md` — layer architecture
- Rust `nalgebra` vs `Vec<T>` — independent mathematical and container vector types
- Haskell `Data.Vector` vs `Linear.V` — independent packages
- C++ Eigen vs `std::vector` — independent types
- Swift SIMD vs Array — independent stdlib types

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status (Option C: independent packages with dependency cleanup). The two concrete actions -- (1) algebra-linear-primitives should drop the vector-primitives dependency and use InlineArray directly, (2) vector-primitives should drop its unused algebra-primitives dependency -- are straightforward refactoring tasks. Execution was deferred because both packages are stable and the dependency cleanup, while architecturally correct, does not unblock any active work.

**Resume when**: Either algebra-linear-primitives or vector-primitives undergoes significant changes that make the dependency cleanup natural to include, or when the tier hierarchy is being rationalized.
