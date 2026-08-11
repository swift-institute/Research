# Modular Arithmetic Design

<!--
---
version: 1.1.0
last_updated: 2026-02-05
status: RECOMMENDATION
tier: 3
---
-->

## Context

Following the decision to unify cyclic-primitives under algebra-modular-primitives, we must design the API for modular arithmetic (Z/nZ) that handles both:

1. **Compile-time modulus**: `n` known at compile time (value generics)
2. **Runtime modulus**: `n` supplied as a parameter

The current design has `Algebra.Z<n>` as the primary type (compile-time), with a proposal to add `Algebra.Z.Dynamic` for runtime. This violates a pattern observed across the codebase:

**Convention**: Dynamic/runtime is the default; static/compile-time is the nested specialization.

## Question

What is the correct design for modular arithmetic that:
1. Treats dynamic as the conceptually primary case
2. Provides compile-time specialization where beneficial
3. Maintains mathematical clarity
4. Follows established patterns

## Mathematical Foundation

### The Object

Z/nZ is the quotient ring of integers modulo n. Elements are equivalence classes:
```
[a]_n = { ..., a-2n, a-n, a, a+n, a+2n, ... }
```

We represent each class by its canonical representative in [0, n).

### Key Observation

**The element representation is identical regardless of whether n is compile-time or runtime.**

An element of Z/nZ is simply an ordinal in [0, n). The modulus determines:
- Which ordinals are valid (must be < n)
- How operations wrap (addition, subtraction)
- Whether ring/field structure exists

The modulus is **configuration**, not **data**. This suggests the element type need not differ between static and dynamic cases.

## Prior Art Survey

### Swift Standard Library

- `Int` vs `Int64` — size is compile-time, but same operations
- `SIMD<Scalar>` vs `SIMD2<Scalar>` — width can be generic or concrete
- `Array<T>` — size is runtime; no compile-time sized array in stdlib

### Rust

```rust
// No standard modular arithmetic, but generic const pattern:
struct Array<T, const N: usize>([T; N]);  // Compile-time size
Vec<T>                                      // Runtime size
```

### Haskell

```haskell
-- Type-level naturals for compile-time
newtype Mod (n :: Nat) = Mod Integer

-- Runtime modulus would use a reader monad or explicit parameter
withMod :: Integer -> (forall n. KnownNat n => Mod n -> a) -> a
```

### C++ (Boost)

```cpp
// Compile-time modulus
template<unsigned N> class mod_int;

// Runtime modulus - separate class with stored modulus
class dynamic_mod_int;
```

### Pattern Analysis

| Language | Compile-time | Runtime | Relationship |
|----------|--------------|---------|--------------|
| Rust | `[T; N]` | `Vec<T>` | Different types |
| Haskell | `Mod n` | CPS/explicit | Type erasure |
| C++ | `mod_int<N>` | `dynamic_mod_int` | Different types |

**Observation**: Most systems treat these as separate types because the compile-time version can be zero-sized (modulus not stored).

## Design Analysis

### The Core Tension

1. **Static advantage**: Zero storage for modulus, operations can be inlined/specialized
2. **Dynamic advantage**: General, works with runtime-determined modulus
3. **Naming convention**: Dynamic should be "primary", static should be "specialized"

### Insight: Element vs Operations

The element in both cases is just an `Ordinal` in [0, n). What differs is **how we access n**:

| Aspect | Compile-time | Runtime |
|--------|--------------|---------|
| Element storage | `Ordinal` | `Ordinal` |
| Modulus storage | In type (`Z<5>`) | External (`Modulus` parameter) |
| Operations | Methods on type | Static functions with modulus param |

This suggests a design where:
- The **element** is uniform (just stores residue)
- The **modulus** is either type-level or value-level
- **Operations** are parameterized appropriately

### Option 1: Separate Types (Current Direction)

```swift
Algebra.Z<n>          // Compile-time, element + modulus in type
Algebra.Z.Dynamic     // Runtime, element only, modulus external
```

**Problem**: Violates "dynamic is default" convention. `Z.Dynamic` suggests dynamic is secondary.

### Option 2: Flip the Nesting

```swift
Algebra.Z             // Namespace for modular arithmetic
Algebra.Z.Element     // Runtime element (residue only)
Algebra.Z.Modulus     // Runtime modulus wrapper
Algebra.Z.Static<n>   // Compile-time element (typealias or struct)
```

**Analysis**:
- `Z` becomes a namespace, not a type
- Dynamic operations live at `Algebra.Z.add(_:_:modulus:)`
- Static type is explicitly marked as specialization

**Problem**: Loses the elegant `Algebra.Z<5>` syntax. Would need `Algebra.Z.Static<5>`.

### Option 3: Parallel Namespaces

```swift
Algebra.Modular           // Dynamic operations namespace
Algebra.Modular.Element   // Runtime element (stores residue)
Algebra.Modular.Modulus   // Runtime modulus

Algebra.Z<n>              // Compile-time type (elegant syntax preserved)
// Defined as: typealias Z<let n: Int> = Tagged<Modular.Residue<n>, Ordinal>
```

**Analysis**:
- `Algebra.Modular` is the general/dynamic case
- `Algebra.Z<n>` is syntactic sugar for the compile-time specialization
- Clear conceptual hierarchy: Modular is the concept, Z<n> is the specialized form

**Advantage**: Preserves `Z<5>` syntax while making dynamic the "main" namespace.

### Option 4: No Separate Dynamic Type

```swift
Algebra.Modular               // Namespace only
Algebra.Modular.Modulus       // Runtime modulus wrapper
Algebra.Modular.add(_:_:modulus:)  // Operations on raw Ordinal
Algebra.Modular.successor(_:modulus:)

Algebra.Z<n>                  // Compile-time type with methods
```

**Analysis**:
- Dynamic case uses `Ordinal` directly, not a wrapper type
- Operations are free functions taking modulus parameter
- Compile-time case wraps `Ordinal` in `Tagged` for type safety

**Advantage**: No "dynamic element" type at all. Minimal API surface.

**Disadvantage**: Loses type safety for dynamic case — any `Ordinal` could be passed.

### Option 5: Unified Element, Stratified Access

```swift
Algebra.Modular               // The mathematical concept
Algebra.Modular.Residue       // Element type (just wraps Ordinal)
Algebra.Modular.Modulus       // Runtime modulus

// Dynamic operations (modulus as parameter)
extension Algebra.Modular {
    static func add(_ a: Residue, _ b: Residue, modulus: Modulus) -> Residue
    static func successor(_ a: Residue, modulus: Modulus) -> Residue
}

// Compile-time specialization
extension Algebra {
    typealias Z<let n: Int> = Tagged<Modular.Static<n>, Modular.Residue>
}

// Static operations (modulus in type)
extension Tagged where Tag == Algebra.Modular.Static<n>, RawValue == Algebra.Modular.Residue {
    static func + (lhs: Self, rhs: Self) -> Self
    var successor: Self { get }
}
```

**Analysis**:
- `Modular.Residue` is the universal element type (dynamic case)
- `Algebra.Z<n>` tags it with compile-time modulus
- Operations exist at both levels

**Problem**: `Tagged<..., Modular.Residue>` where `Residue` wraps `Ordinal` — extra indirection.

### Option 6: Ordinal IS the Element

The most minimal design:

```swift
extension Algebra {
    /// Modular arithmetic operations.
    ///
    /// Elements are `Ordinal` values in [0, modulus).
    /// The modulus is either compile-time (via `Z<n>`) or runtime (via `Modulus`).
    enum Modular {
        /// A validated positive modulus for runtime modular arithmetic.
        struct Modulus: Hashable, Sendable {
            public let value: Cardinal
            public init(_ value: Cardinal) throws(Error)
        }

        /// Modular addition.
        @inlinable
        public static func add(_ a: Ordinal, _ b: Ordinal, modulus: Modulus) -> Ordinal

        /// Modular successor.
        @inlinable
        public static func successor(_ a: Ordinal, modulus: Modulus) -> Ordinal

        // ... other operations
    }
}

extension Algebra {
    /// The ring Z/nZ with compile-time modulus.
    ///
    /// This is the compile-time specialization of modular arithmetic.
    /// For runtime modulus, use `Algebra.Modular` operations directly on `Ordinal`.
    public typealias Z<let n: Int> = Tagged<Residue<n>, Ordinal>
}
```

**Key insight**: For dynamic case, the element IS just `Ordinal`. No wrapper needed.

**Advantages**:
- Minimal API: no `Dynamic` type, no `Element` wrapper
- `Ordinal` is already a well-understood type
- `Algebra.Z<n>` provides type safety for compile-time case
- `Algebra.Modular` provides operations for runtime case
- Clear conceptual model: Modular is general, Z<n> is specialized

**Disadvantages**:
- Dynamic case has no type safety (any `Ordinal` can be passed)
- Caller must ensure `Ordinal < modulus`

## Theoretical Grounding

### Type-Theoretic View

The modulus `n` is a **parameter** to the type Z/nZ. In dependent type theory:

```
Z : (n : Nat) → Type
Z n = { x : Nat | x < n }
```

For compile-time `n`, Swift's value generics give us `Z<n>`.
For runtime `n`, we have a **dependent pair** (Σ-type): the modulus and a proof that elements are bounded.

In Swift, we can't express the proof, so we rely on:
- Validated construction (`init` that checks bounds)
- Trusting operations to maintain the invariant

### Category-Theoretic View

Z/nZ is an object in the category of rings. The forgetful functor to sets gives us the underlying set {0, 1, ..., n-1}.

Both compile-time and runtime representations map to the same mathematical object. The difference is **how we track the parameter n** — in the type system or in values.

### Operational Semantics

For element `a` and modulus `n`:
```
succ(a, n) = (a + 1) mod n
add(a, b, n) = (a + b) mod n
neg(a, n) = (n - a) mod n
```

These operations are identical regardless of how `n` is provided.

## Recommendation

### Option 6: Ordinal IS the Element

This is the correct design because:

1. **Mathematical truth**: An element of Z/nZ is just a natural number in [0, n). `Ordinal` represents exactly this.

2. **Dynamic is primary**: `Algebra.Modular` operations work on `Ordinal` directly. No special "dynamic" type.

3. **Static is specialization**: `Algebra.Z<n>` wraps `Ordinal` in `Tagged` to carry the modulus in the type. This is explicitly a compile-time specialization.

4. **Minimal API**: No redundant wrapper types. `Ordinal` + `Modulus` + operations = complete dynamic API.

5. **Follows convention**: The namespace `Algebra.Modular` is the general case; `Algebra.Z<n>` is nested/derived.

### Proposed API

```swift
// ===== Dynamic (Primary) =====

extension Algebra {
    /// Modular arithmetic with runtime modulus.
    enum Modular {}
}

extension Algebra.Modular {
    /// A validated positive modulus.
    public struct Modulus: Hashable, Comparable, Sendable {
        public let value: Cardinal

        public init(_ value: Cardinal) throws(Error)
        public init(__unchecked value: Cardinal)

        public enum Error: Swift.Error, Sendable {
            case zeroModulus
        }
    }
}

extension Algebra.Modular {
    /// Modular successor: (a + 1) mod n
    @inlinable
    public static func successor(_ a: Ordinal, modulus: Modulus) -> Ordinal

    /// Modular predecessor: (a - 1 + n) mod n
    @inlinable
    public static func predecessor(_ a: Ordinal, modulus: Modulus) -> Ordinal

    /// Modular addition: (a + b) mod n
    @inlinable
    public static func add(_ a: Ordinal, _ b: Ordinal, modulus: Modulus) -> Ordinal

    /// Modular subtraction: (a - b + n) mod n
    @inlinable
    public static func subtract(_ a: Ordinal, _ b: Ordinal, modulus: Modulus) -> Ordinal

    /// Modular negation: (n - a) mod n
    @inlinable
    public static func negate(_ a: Ordinal, modulus: Modulus) -> Ordinal

    /// Advance by signed offset with wrapping.
    @inlinable
    public static func advanced(_ a: Ordinal, by offset: Int, modulus: Modulus) -> Ordinal

    /// Reduce any ordinal to canonical representative in [0, n).
    @inlinable
    public static func reduce(_ a: Ordinal, modulus: Modulus) -> Ordinal
}

// ===== Static (Specialization) =====

extension Algebra {
    /// The ring Z/nZ with compile-time modulus.
    ///
    /// This is the compile-time specialization of `Algebra.Modular`.
    /// Elements carry the modulus in their type, enabling:
    /// - Zero storage overhead for modulus
    /// - Type-safe operations (can't mix Z<5> with Z<7>)
    /// - Ring and field witnesses
    ///
    /// For runtime modulus, use `Algebra.Modular` operations on `Ordinal`.
    public typealias Z<let n: Int> = Tagged<Residue<n>, Ordinal>
}

// Existing: Residue<n>, Z operations, ring/field witnesses
```

### Naming Rationale

| Name | Role |
|------|------|
| `Algebra.Modular` | The general concept (runtime modulus) |
| `Algebra.Modular.Modulus` | Validated positive modulus |
| `Algebra.Modular.add(_:_:modulus:)` | Dynamic operation |
| `Algebra.Z<n>` | Compile-time specialization |
| `Algebra.Z<n>.ring` | Algebraic witness |

The namespace `Modular` is deliberately general. `Z<n>` is the specialized, type-safe form.

### Migration from cyclic-primitives

| cyclic-primitives | algebra-modular-primitives |
|-------------------|---------------------------|
| `Cyclic.Group.Static<N>.Element` | `Algebra.Z<N>` |
| `Cyclic.Group.Element` | `Ordinal` |
| `Cyclic.Group.Modulus` | `Algebra.Modular.Modulus` |
| `Cyclic.Group.successor(_:modulus:)` | `Algebra.Modular.successor(_:modulus:)` |
| `Cyclic.Group.add(_:_:modulus:)` | `Algebra.Modular.add(_:_:modulus:)` |

## Outcome

**Status**: RECOMMENDATION

**Decision**: Implement Option 6 (Ordinal IS the Element), with operations specific to `Ordinal` (not generic over `Ordinal.Protocol`).

### Summary

1. **`Algebra.Modular`** is the primary namespace for runtime modular arithmetic
2. **`Algebra.Modular.Modulus`** wraps `Cardinal`, validates > 0
3. **Operations** take `Ordinal` (not `Ordinal.Protocol`) to maintain semantic clarity
4. **`Algebra.Z<n>`** is the compile-time specialization with type-embedded modulus
5. **`Ordinal.Protocol`** enables interop but doesn't blur boundaries

### Rationale

- **Dynamic is default**: `Algebra.Modular` operations on `Ordinal` — no wrapper type
- **Static is specialization**: `Algebra.Z<n>` = `Tagged<Residue<n>, Ordinal>`
- **No generic operations**: `Algebra.Modular` operations are NOT generic over `Ordinal.Protocol` because using typed `Z<n>` values with arbitrary runtime modulus is semantically wrong
- **Explicit interop**: Extract via `.ordinal`, re-tag via `init(_ ordinal:)` when needed

### The Model

```
Ordinal                          Raw ordinal position
    │
    ├─── Algebra.Modular         Runtime modular arithmetic on Ordinal
    │    └── Modulus             Validated positive modulus
    │
    └─── Algebra.Z<n>            Compile-time modular arithmetic
         = Tagged<Residue<n>, Ordinal>
         └── ring, field         Algebraic witnesses
```

## Implementation Checklist

- [ ] Create `Algebra.Modular` namespace (`Algebra.Modular.swift`)
- [ ] Add `Algebra.Modular.Modulus` type (`Algebra.Modular.Modulus.swift`)
- [ ] Add `Algebra.Modular.Modulus.Error` (`Algebra.Modular.Modulus.Error.swift`)
- [ ] Add `Algebra.Modular` operations:
  - [ ] `successor(_:modulus:)` (`Algebra.Modular+Successor.swift`)
  - [ ] `predecessor(_:modulus:)` (`Algebra.Modular+Predecessor.swift`)
  - [ ] `add(_:_:modulus:)` (`Algebra.Modular+Add.swift`)
  - [ ] `subtract(_:_:modulus:)` (`Algebra.Modular+Subtract.swift`)
  - [ ] `negate(_:modulus:)` (`Algebra.Modular+Negate.swift`)
  - [ ] `advanced(_:by:modulus:)` (`Algebra.Modular+Advanced.swift`)
  - [ ] `reduce(_:modulus:)` (`Algebra.Modular+Reduce.swift`)
- [ ] Verify `Algebra.Z<n>` works as compile-time specialization
- [ ] Update consumers (vector-primitives, etc.) to use `Algebra.Z<n>`
- [ ] Delete `swift-cyclic-primitives`
- [ ] Delete `swift-cyclic-index-primitives`

## Ordinal.Protocol Integration

### The Protocol

`ordinal-primitives` defines `Ordinal.Protocol` as an abstraction over ordinal-carrying types:

```swift
extension Ordinal {
    public protocol `Protocol` {
        var ordinal: Ordinal { get }
        init(_ ordinal: Ordinal)
    }
}
```

**Conformers**:
- `Ordinal` — identity (self-conformance)
- `Tagged<Tag, Ordinal>` — phantom-typed ordinal wrapper (includes `Algebra.Z<n>`)

This enables generic functions that work on any ordinal-carrying type:

```swift
func next<O: Ordinal.`Protocol`>(_ value: O) -> O {
    O(value.ordinal + 1)
}
```

### Existing Modular Operations on Tagged

`Tagged+Ordinal.swift` already provides modular operations:

```swift
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    /// Projects a tagged ordinal into a bounded range.
    /// `position % capacity` yields a position within `[0, capacity)`.
    public static func % (lhs: Self, rhs: Tagged<Tag, Cardinal>) -> Self {
        Self(__unchecked: (), lhs.rawValue % rhs.rawValue)
    }
}
```

This is ring-buffer wrap-around: position within capacity.

### Analysis: Should Algebra.Modular Operations Be Generic?

**Option A: Generic over Ordinal.Protocol**

```swift
extension Algebra.Modular {
    static func successor<T: Ordinal.Protocol>(_ a: T, modulus: Modulus) -> T {
        let result = (a.ordinal.rawValue + 1) % modulus.value.rawValue
        return T(Ordinal(__unchecked: result))
    }
}
```

**Advantages**:
- Works with any ordinal-carrying type
- Tag preserved automatically
- Flexible

**Disadvantages**:
- **Semantic confusion**: `Algebra.Z<5>` already carries modulus in its type. Calling `Algebra.Modular.add(z5, z5, modulus: Modulus(3))` compiles but is semantically wrong — treating Z/5Z elements as Z/3Z elements.
- **Type safety illusion**: Same-type constraint prevents mixing `Z<5>` with `Z<7>`, but allows misusing a typed element with a different runtime modulus.
- **Conceptual muddling**: Compile-time and runtime modulus concepts become intertwined.

**Option B: Specific to Ordinal (Recommended)**

```swift
extension Algebra.Modular {
    static func successor(_ a: Ordinal, modulus: Modulus) -> Ordinal
}
```

**Advantages**:
- Clear separation: dynamic ops on `Ordinal`, static ops on `Algebra.Z<n>`
- No semantic confusion
- If you have a tagged value, explicit extraction (`.ordinal`) signals intent

**Disadvantages**:
- Less flexible — must extract ordinal from tagged types

### Recommendation: Option B (Specific to Ordinal)

The `Ordinal.Protocol` is valuable for:
1. **Extraction**: `.ordinal` property gets the underlying value
2. **Construction**: `init(_ ordinal: Ordinal)` creates a new typed value

But `Algebra.Modular` operations should work on raw `Ordinal` because:

1. **Semantic clarity**: Dynamic modular operations are for when the modulus is unknown at compile time. If you have an `Algebra.Z<n>`, you already have compile-time modulus — use the type's methods.

2. **Explicit intent**: If you must use a `Z<n>` value with a different runtime modulus, extracting `.ordinal` makes the semantic break explicit:

   ```swift
   let z5: Algebra.Z<5> = ...
   // Explicit: I'm treating this as a raw ordinal now
   let raw = z5.ordinal
   let result = Algebra.Modular.successor(raw, modulus: someModulus)
   ```

3. **No false safety**: Type-checking `T == T` doesn't prevent misuse; it just catches accidental mixing of different types while allowing the same type to be misused.

### Integration with Existing Tagged+Ordinal

The existing `%` operator in `Tagged+Ordinal.swift` serves a different purpose:

```swift
position % capacity  // Ring buffer wrap-around
```

This is **index bounding**, not modular arithmetic in the Z/nZ sense. The semantics are:
- Input: position in arbitrary range
- Output: position in `[0, capacity)`
- Tag preserved because the domain (e.g., `Index<Buffer>`) is unchanged

This is appropriate for `Tagged+Ordinal` because the tag represents the domain (buffer, array, etc.), not an algebraic structure.

For `Algebra.Z<n>`, the tag (`Residue<n>`) represents the algebraic structure itself. Applying a different modulus would change the structure, which should require a type change.

### Final Design with Ordinal.Protocol Context

```swift
// ===== Ordinal.Protocol (existing in ordinal-primitives) =====
// Provides: .ordinal extraction, init(_ ordinal:) construction

// ===== Algebra.Modular (dynamic operations) =====
// Works on raw Ordinal — no tagging, no compile-time modulus
extension Algebra.Modular {
    static func successor(_ a: Ordinal, modulus: Modulus) -> Ordinal
    static func add(_ a: Ordinal, _ b: Ordinal, modulus: Modulus) -> Ordinal
    // etc.
}

// ===== Algebra.Z<n> (static operations) =====
// Tagged<Residue<n>, Ordinal> — compile-time modulus in type
extension Algebra.Z<n> {
    static func + (lhs: Self, rhs: Self) -> Self  // Uses n from type
    var successor: Self { get }                    // Uses n from type
}

// ===== Interop via Ordinal.Protocol =====
// To use Z<n> with dynamic operations (semantic break!):
let z5: Algebra.Z<5> = ...
let raw = z5.ordinal                               // Extract via protocol
let result = Algebra.Modular.add(raw, raw, modulus: m)
let retagged = Algebra.Z<5>(result)               // Re-construct via protocol
```

The `Ordinal.Protocol` enables the bridge but doesn't blur the semantic boundary.

## References

- Swift Evolution: SE-0393 Value and Type Parameter Packs
- Swift Evolution: SE-0396 Typed throws (for Modulus.init)
- Haskell `mod-n` package design
- Rust `num-modular` crate design
- ordinal-primitives `Ordinal.Protocol` — abstraction over ordinal-carrying types
