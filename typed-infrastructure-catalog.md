# Typed Infrastructure Catalog: Primitives Tiers 0–15

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: SUPERSEDED
tier: 3
superseded_by: existing-infrastructure skill [INFRA-*]
---
-->

## Context

The Swift Institute primitives layer contains 116 packages across 20 tiers. These packages provide a typed infrastructure system where quantities (counts, positions, offsets, sizes) are expressed as phantom-typed wrappers rather than bare integers. The infrastructure is designed so that implementation code reads as intent, not mechanism ([IMPL-INTENT]).

A recurring problem is that agents writing implementation code against this infrastructure **reimimplement existing operations** rather than using the typed infrastructure already available. Common symptoms include:

- Writing `Int(bitPattern: count)` at call sites instead of using stdlib integration overloads
- Extracting `.rawValue.rawValue` chains instead of using `.map()` or `.retag()`
- Constructing manual `while` loops instead of using `.forEach` / `.reduce` iteration
- Hand-rolling pointer arithmetic instead of using `pointer(at:)` primitives
- Implementing ad-hoc property accessors instead of using `Property<Tag, Base>` / `Property<Tag, Base>.View`

The `existing-infrastructure` skill was created to address this by cataloging available infrastructure. However, it was assembled quickly as a side project and has significant gaps. This research conducts a systematic, tier-by-tier audit of all infrastructure from tier 0 (identity-primitives) through tier 15 (buffer-primitives), producing a complete catalog that the skill can be rebuilt from.

**Trigger**: Ecosystem-wide infrastructure gap causing implementation quality regression.

**Scope**: Ecosystem-wide (Tier 3). This catalog establishes the authoritative inventory of typed infrastructure that all implementation code depends on. Expected lifetime: updated incrementally as packages evolve, but the structural organization is timeless.

## Question

What is the complete inventory of reusable typed infrastructure across primitives tiers 0–15, organized so that an implementing agent can:

1. Find any existing operation before writing new code
2. Understand which package provides each operation
3. Apply the correct infrastructure pattern at each call site
4. Identify principled absences vs. infrastructure gaps

## Prior Art Survey

### 1. Phantom-Typed Wrappers in Programming Languages

The primitives infrastructure is built on phantom-typed wrappers — a pattern with deep roots in type theory and language design.

| Year | Contribution | Relevance |
|------|-------------|-----------|
| 1999 | Leijen & Meijer, "Domain Specific Embedded Compilers" (DSL'99) | Pioneered phantom type variables for well-typedness in embedded languages |
| 2003 | Hinze, "Fun with Phantom Types" | Demonstrated type-safe printf, Leibniz equality via phantom types |
| 2004 | Cheney & Hinze, "First-Class Phantom Types" (ICFP) | Type equations for phantom types, precursor to GADTs |
| 2006 | Fluet & Pucella, "Phantom Types and Subtyping" (JFP) | Phantom types encode arbitrary finite subtyping hierarchies |
| 2014 | Breitner et al., "Safe Zero-cost Coercions for Haskell" (ICFP) | Formalized roles: nominal, representational, phantom |

The key insight from Breitner et al. is the **role system**: in `Tagged<Tag, RawValue>`, the `Tag` parameter has phantom role (irrelevant to representation) while `RawValue` has representational role (the actual data). Operations that depend only on `RawValue` should lift across `Tag` changes — this is exactly what `.retag()` provides.

### 2. Units-of-Measure Systems

The typed arithmetic system (Cardinal for counts, Ordinal for positions, Offset for displacements) mirrors units-of-measure type systems:

| System | Approach | Relation |
|--------|----------|----------|
| F# Units of Measure (Kennedy 2009) | Compiler-integrated dimensional analysis | Same goal: prevent mixing meters with feet |
| Boost.Units (C++) | Template metaprogramming for SI units | Same structure: base types + phantom tags |
| Haskell dimensional | Type-level dimensional analysis | Same algebra: quantities compose with dimensional rules |

The primitives system uses affine space theory rather than dimensional analysis, but the purpose is identical: the type system prevents mixing incompatible quantities.

### 3. Affine Space Foundations

The pointer arithmetic model directly implements affine geometry:

| Concept | Mathematical | Primitives |
|---------|-------------|------------|
| Point | Element of affine space | `Ordinal`, `Index<T>` |
| Vector | Element of translation group | `Affine.Discrete.Vector`, `Index<T>.Offset` |
| Point + Vector → Point | Affine translation | `Index<T> + Index<T>.Offset → Index<T>` |
| Point - Point → Vector | Affine displacement | `Index<T> - Index<T> → Index<T>.Offset` |
| Scalar | Element of base field | `Cardinal`, `Index<T>.Count` |
| Scalar × Vector → Vector | Scaling | `Affine.Discrete.Ratio<From, To>` |

This is not an analogy — the types enforce affine space axioms. Adding two points (`Index + Index`) does not type-check. Adding a vector to a point (`Index + Offset`) does. Subtracting points yields a vector. These are [IMPL-001] principled absences.

### 4. Property Accessor Patterns

The `Property<Tag, Base>` pattern is a variant of the Builder/Fluent Interface pattern adapted for value semantics and `~Copyable` types:

| Pattern | Language | Relation |
|---------|----------|----------|
| Fluent Interface (Fowler 2005) | OOP | Method chaining for readability |
| Lens/Optic (van Laarhoven 2009) | Haskell | Composable accessors |
| KeyPath (Swift) | Swift | Type-safe property references |
| Property<Tag, Base> | Primitives | Verb-as-property with `callAsFunction` |

The Property pattern is unique in combining phantom-tag dispatch, `callAsFunction` for the common case, and `_read`/`_modify` coroutines for `~Copyable` access.

## Theoretical Grounding

### Type Algebra

The primitives infrastructure forms a coherent type algebra with four base types and one wrapper:

```
Base Types:
  Cardinal : UInt          -- quantities (non-negative)
  Ordinal  : UInt          -- positions (non-negative)
  Vector   : Int           -- displacements (signed)
  Ratio<F,T> : Int         -- scaling factors (signed)

Wrapper:
  Tagged<Tag, RawValue>    -- phantom-typed wrapper (zero-cost)

Composed Types:
  Index<T>         = Tagged<T, Ordinal>           -- typed position
  Index<T>.Count   = Tagged<T, Cardinal>          -- typed quantity
  Index<T>.Offset  = Tagged<T, Vector>            -- typed displacement
  Memory.Address   = Tagged<Memory, Ordinal>      -- byte position
  Memory.Address.Count = Tagged<Memory, Cardinal>  -- byte quantity
  Ordinal.Finite<N> = Tagged<Finite.Bound<N>, Ordinal>  -- bounded position
  Index<T>.Bounded<N> = Tagged<T, Ordinal.Finite<N>>    -- bounded typed position
```

### Functor Laws

`Tagged` satisfies the functor laws for `.map()`:

```
Identity:    tagged.map { $0 }  ≡  tagged
Composition: tagged.map(f).map(g)  ≡  tagged.map { g(f($0)) }
```

And `.retag()` is a natural transformation between `Tagged<A, ->` and `Tagged<B, ->`:

```
Naturality:  tagged.retag(B.self).map(f)  ≡  tagged.map(f).retag(B.self)
```

These laws guarantee that functor operations compose predictably and that `.retag()` commutes with `.map()`.

### Affine Space Axioms

The typed arithmetic enforces:

```
1. Point + Vector → Point        (translation)
2. Point - Point → Vector        (displacement)
3. Vector + Vector → Vector      (vector addition)
4. Scalar × Vector → Vector      (scaling)
5. ¬(Point + Point)              (not defined — principled absence)
6. ¬(Point × Point)              (not defined — principled absence)
7. ¬(Scalar - Scalar) as total   (Cardinal subtraction is partial — monus)
```

### Property Accessor Dispatch

The Property pattern uses Swift's type system for static dispatch:

```
Property<Tag, Base> where Tag == T.Move, Base == T
  → callAsFunction dispatches to move operation
  → .last() dispatches to tracked move-last

Property<Tag, Base>.View where Tag == T.Initialize, Base == T
  → callAsFunction dispatches to initialize operation
  → .next() dispatches to tracked initialize-next
```

No runtime dispatch. The tag determines the operation namespace at compile time.

## Formal Semantics

### Typing Rules

```
Γ ⊢ e : Tagged<Tag, A>    Γ ⊢ f : A → B
──────────────────────────────────────────── [T-MAP]
         Γ ⊢ e.map(f) : Tagged<Tag, B>

Γ ⊢ e : Tagged<A, R>
──────────────────────────────────── [T-RETAG]
  Γ ⊢ e.retag(B.self) : Tagged<B, R>

Γ ⊢ p : Tagged<T, Ordinal>    Γ ⊢ v : Tagged<T, Vector>
─────────────────────────────────────────────────────────── [T-TRANSLATE]
           Γ ⊢ p + v : Tagged<T, Ordinal>

Γ ⊢ p₁ : Tagged<T, Ordinal>    Γ ⊢ p₂ : Tagged<T, Ordinal>
──────────────────────────────────────────────────────────────── [T-DISPLACE]
             Γ ⊢ p₁ - p₂ : Tagged<T, Vector>

Γ ⊢ c₁ : Tagged<T, Cardinal>    Γ ⊢ c₂ : Tagged<T, Cardinal>
──────────────────────────────────────────────────────────────── [T-ADD-CARD]
            Γ ⊢ c₁ + c₂ : Tagged<T, Cardinal>

Γ ⊢ c₁ : Tagged<T, Cardinal>    Γ ⊢ c₂ : Tagged<T, Cardinal>
──────────────────────────────────────────────────────────────── [T-SUB-CARD]
     Γ ⊢ c₁.subtract.exact(c₂) : Tagged<T, Cardinal>  throws

Γ ⊢ c : Tagged<T, Cardinal>
──────────────────────────────── [T-COUNT-TO-INDEX]
  Γ ⊢ c.map(Ordinal.init) : Tagged<T, Ordinal>

Γ ⊢ i : Tagged<T, Ordinal>    N : Int
──────────────────────────────────────── [T-NARROW]
  Γ ⊢ Bounded<N>(i) : Tagged<T, Ordinal.Finite<N>>?

Γ ⊢ b : Tagged<T, Ordinal.Finite<N>>
──────────────────────────────────────── [T-WIDEN]
     Γ ⊢ Index<T>(b) : Tagged<T, Ordinal>
```

### Operational Semantics (Small-Step)

```
⟨Tagged(__unchecked: (), v)⟩.rawValue  →  v                    [E-RAWVALUE]
⟨Tagged(__unchecked: (), v)⟩.map(f)    →  Tagged(__unchecked: (), f(v))  [E-MAP]
⟨Tagged(__unchecked: (), v)⟩.retag(_)  →  Tagged(__unchecked: (), v)     [E-RETAG]

⟨Cardinal(a)⟩ + ⟨Cardinal(b)⟩  →  Cardinal(a +ᵤ b)            [E-CARD-ADD]
  where +ᵤ is UInt addition (traps on overflow)

⟨Cardinal(a)⟩.subtract.saturating(⟨Cardinal(b)⟩)  →           [E-CARD-SUB-SAT]
  Cardinal(a ≥ b ? a - b : 0)

⟨Cardinal(a)⟩.subtract.exact(⟨Cardinal(b)⟩)  →               [E-CARD-SUB-EXACT]
  a ≥ b ? Cardinal(a - b) : throw .underflow

⟨Ordinal(p)⟩.successor.saturating()  →  Ordinal(min(p + 1, UInt.max))  [E-SUCC-SAT]
⟨Ordinal(p)⟩.successor.exact()       →                                  [E-SUCC-EXACT]
  p < UInt.max ? Ordinal(p + 1) : throw .overflow

⟨Ordinal.Finite<N>(p)⟩.successor()  →                         [E-FIN-SUCC]
  p + 1 < N ? Ordinal.Finite<N>(p + 1) : nil
```

### Soundness Argument

**Claim**: The typed infrastructure prevents dimension mixing at compile time.

**Proof sketch**: By the typing rules above, the only way to produce a `Tagged<T, Ordinal>` is:
1. Construction via `__unchecked` (package-internal only, per [PATTERN-017])
2. Translation: `Tagged<T, Ordinal> + Tagged<T, Vector>` [T-TRANSLATE]
3. Map from cardinal: `Tagged<T, Cardinal>.map(Ordinal.init)` [T-MAP, T-COUNT-TO-INDEX]
4. Retag from another ordinal: `Tagged<U, Ordinal>.retag(T.self)` [T-RETAG]

In all cases, the phantom tag `T` is preserved or explicitly changed. There is no well-typed expression that produces `Tagged<T, Ordinal>` from a `Tagged<U, Cardinal>` without explicit `.map()` or `.retag()`. Dimension mixing requires raw value extraction, which [PATTERN-017] confines to package-internal code. At public call sites, the type system is sound. ∎

## Analysis

### Infrastructure Inventory by Tier

The following inventory catalogs every reusable operation available from tier 0 through tier 15. The inventory is organized by the question an implementer would ask.

---

#### Tier 0: Identity Primitives (`swift-identity-primitives`)

**Package**: `Identity Primitives`
**Types**: `Tagged<Tag, RawValue>`

| Operation | Signature | Use |
|-----------|-----------|-----|
| Construction | `Tagged(__unchecked: (), rawValue)` | Package-internal only |
| Raw access | `.rawValue` | Package-internal per [PATTERN-017] |
| Map raw value | `.map { transform }` | Transform value, preserve tag |
| Change tag | `.retag(NewTag.self)` | Change tag, preserve value |
| Comparison | `<`, `<=`, `>`, `>=`, `==` | Via conditional `Comparable`/`Equatable` |
| Static min/max | `Type.min(a, b)`, `Type.max(a, b)` | Typed min/max without `Swift.min()` |
| Modify in place | `.modify { &rawValue in }` | Package-internal mutation |

**Decision tree — before writing `.rawValue`**:

| You want | Use instead |
|----------|-------------|
| Cross-domain same value | `.retag(NewTag.self)` |
| Transform value | `.map { transform }` |
| Count → Index | `.map(Ordinal.init)` |
| Compare | Typed operators directly |
| Min/max | `Type.min(a, b)` / `Type.max(a, b)` |

---

#### Tier 0: Property Primitives (`swift-property-primitives`)

**Package**: `Property Primitives`
**Types**: `Property<Tag, Base>`, `Property<Tag, Base>.Typed<Element>`, `Property<Tag, Base>.View`, `Property<Tag, Base>.View.Typed<Element>`, `Property<Tag, Base>.View.Read`, `Property<Tag, Base>.View.Read.Typed<Element>`, `Property<Tag, Base>.Consuming<Element>`

| Type | Use Case | Base Requirement |
|------|----------|-----------------|
| `Property<Tag, Base>` | Copyable base, method extensions | `Base: Copyable` |
| `Property<Tag, Base>.Typed<E>` | Copyable base, property extensions | `Base: Copyable` |
| `Property<Tag, Base>.View` | `~Copyable` base, mutable access | `Base: ~Copyable` |
| `Property<Tag, Base>.View.Typed<E>` | `~Copyable` base + Element | `Base: ~Copyable` |
| `Property<Tag, Base>.View.Read` | `~Copyable` base, read-only | `Base: ~Copyable` |
| `Property<Tag, Base>.View.Read.Typed<E>` | `~Copyable` read-only + Element | `Base: ~Copyable` |
| `Property<Tag, Base>.Consuming<E>` | State-tracking consuming | Consuming access |

**Decision tree — before hand-rolling an accessor struct**:

| Your base is | You need | Use |
|-------------|----------|-----|
| Copyable | Methods only | `Property<Tag, Base>` |
| Copyable | Properties too | `Property<Tag, Base>.Typed<E>` |
| ~Copyable | Mutable methods | `Property<Tag, Base>.View` |
| ~Copyable | Mutable + Element | `Property<Tag, Base>.View.Typed<E>` |
| ~Copyable | Read-only | `Property<Tag, Base>.View.Read` |

---

#### Tier 3: Cardinal Primitives (`swift-cardinal-primitives`)

**Package**: `Cardinal Primitives Core`
**Types**: `Cardinal`, `Cardinal.Protocol`

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Construction | `Cardinal(_ value: UInt)` | Direct |
| Zero constant | `.zero` | Via `Cardinal.Protocol` |
| One constant | `.one` | Via `Cardinal.Protocol` |
| Addition | `c1 + c2`, `c1 += c2` | Trapping (total for non-overflow) |
| Subtract saturating | `.subtract.saturating(other)` | Monus: clamps at zero |
| Subtract exact | `.subtract.exact(other)` | Throws `.underflow` |
| Comparison | `<`, `<=`, `>`, `>=`, `==` | All operators |

**Protocol**: `Cardinal.Protocol` — conformance lifts all operations to `Tagged<Tag, Cardinal>` types.

| Conformer | Typealias |
|-----------|-----------|
| `Cardinal` | (itself) |
| `Tagged<T, Cardinal>` for any `T: ~Copyable` | `Index<T>.Count`, `Memory.Address.Count`, etc. |

**Decision tree — before writing `Cardinal(0)` or `Cardinal(1)`**:

Use `.zero` and `.one`. These are available on ALL `Cardinal.Protocol` conformers, including `Index<T>.Count`.

---

#### Tier 3: Hash Primitives (`swift-hash-primitives`)

**Package**: `Hash Primitives`
**Types**: `Hash.Value`, `Hash.Protocol`

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Hash value | `Hash.Value` | UInt-backed hash |
| Protocol | `Hash.Protocol` | Hashing without `Hashable` |

---

#### Tier 4: Ordinal Primitives (`swift-ordinal-primitives`)

**Package**: `Ordinal Primitives Core`
**Types**: `Ordinal`, `Ordinal.Protocol`, `Ordinal.Error`

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Construction | `Ordinal(_ value: UInt)` | Direct |
| Zero constant | `.zero` | Static property |
| Successor saturating | `.successor.saturating()` | Clamps at UInt.max |
| Successor exact | `.successor.exact()` | Throws `.overflow` |
| Predecessor saturating | `.predecessor.saturating()` | Clamps at zero |
| Predecessor exact | `.predecessor.exact()` | Throws `.underflow` |
| Advance saturating | `.advance.saturating(by: count)` | Advance by cardinal |
| Advance exact | `.advance.exact(by: count)` | Throws `.overflow` |
| Advance clamped | `.advance.clamped(by: count, to: bound)` | Clamps at bound |
| Retreat saturating | `.retreat.saturating(by: count)` | Retreat by cardinal |
| Retreat exact | `.retreat.exact(by: count)` | Throws `.underflow` |
| Distance forward | `.distance.forward(to: other)` | Returns `Count`, throws `.notForward` |
| Point + Count | `ordinal + count` | Via `Ordinal.Protocol` |
| Point += Count | `ordinal += count` | In-place |

**Protocol**: `Ordinal.Protocol` — conformance lifts all operations to `Tagged<Tag, Ordinal>` types.

| Conformer | Typealias |
|-----------|-----------|
| `Ordinal` | (itself) |
| `Tagged<T, Ordinal>` for any `T: ~Copyable` | `Index<T>`, `Memory.Address`, etc. |

**Errors**: `Ordinal.Error` — `.overflow`, `.underflow`, `.notForward`

**Decision tree — before writing a manual increment loop**:

| You want | Use |
|----------|-----|
| Next position (might overflow) | `.successor.exact()` |
| Next position (saturate) | `.successor.saturating()` |
| Move forward by N | `.advance.exact(by: n)` |
| Move backward by N | `.retreat.exact(by: n)` |
| Distance between positions | `.distance.forward(to: other)` |

---

#### Tier 5: Affine Primitives (`swift-affine-primitives`)

**Package**: `Affine Primitives Core`
**Types**: `Affine.Discrete.Vector`, `Affine.Discrete.Ratio<From, To>`

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Vector construction | `Affine.Discrete.Vector(_ rawValue: Int)` | Signed displacement |
| Vector from zero | `Offset(fromZero: position)` | Ordinal → Offset |
| Ratio construction | `Affine.Discrete.Ratio<F, T>(_ factor: Int)` | Scaling factor |
| Identity ratio | `Affine.Discrete.Ratio<T, T>.identity` | Factor 1 |
| Cardinal scaling | `count * ratio` | `Tagged<F, Cardinal> * Ratio<F, T> → Tagged<T, Cardinal>` |
| Vector scaling | `offset * ratio` | `Tagged<F, Vector> * Ratio<F, T> → Tagged<T, Vector>` |
| Ratio composition | `ratio1 * ratio2` | `Ratio<A,B> * Ratio<B,C> → Ratio<A,C>` |
| Quotient/remainder | `.quotientAndRemainder(dividingBy:)` | Inverse scaling |

**Stdlib integration** (`Affine Primitives Standard Library Integration`):

| Overload | Use |
|----------|-----|
| `UnsafePointer + Tagged<Pointee, Ordinal>.Offset` | Typed pointer advance |
| `UnsafePointer - Tagged<Pointee, Ordinal>.Offset` | Typed pointer retreat |
| `UnsafePointer - UnsafePointer → Offset` | Typed distance |
| `UnsafePointer[Tagged<Pointee, Ordinal>]` subscript | Typed element access |

**Decision tree — before writing capacity doubling**:

```swift
// Mechanism (wrong):
Cardinal(count.rawValue &<< 1)

// Intent (correct):
count * Affine.Discrete.Ratio<Element, Element>(2)
```

---

#### Tier 6: Index Primitives (`swift-index-primitives`)

**Package**: `Index Primitives Core`
**Types**: `Index<T>` (typealias), `Index<T>.Count`, `Index<T>.Offset`

| Type | Definition | Meaning |
|------|-----------|---------|
| `Index<Element>` | `Tagged<Element, Ordinal>` | Typed position |
| `Index<Element>.Count` | `Tagged<Element, Cardinal>` | Typed quantity |
| `Index<Element>.Offset` | `Tagged<Element, Affine.Discrete.Vector>` | Typed displacement |

All operations from `Cardinal.Protocol`, `Ordinal.Protocol`, and `Affine` lift automatically via protocol conformance. No additional API is needed — the type aliases compose.

**Key conversions**:

| From | To | Method |
|------|-----|--------|
| `Index<T>.Count` → `Index<T>` | Count → position | `.map(Ordinal.init)` |
| `Index<T>` → `Bit.Index` | Cross-domain same position | `.retag(Bit.self)` |
| `Index<T>.Count` → `Index<U>.Count` | Cross-domain same count | `.retag(U.self)` |

---

#### Tier 7: Finite Primitives (`swift-finite-primitives`)

**Package**: `Finite Primitives`
**Types**: `Finite.Bound<N>`, `Ordinal.Finite<N>`, `Index<T>.Bounded<N>`

| Type | Definition | Meaning |
|------|-----------|---------|
| `Ordinal.Finite<N>` | `Tagged<Finite.Bound<N>, Ordinal>` | Position bounded by N |
| `Index<T>.Bounded<N>` | `Tagged<T, Ordinal.Finite<N>>` | Typed bounded position |

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Narrowing | `Ordinal.Finite<N>(position)` | Returns `Optional` |
| Narrowing (int) | `Ordinal.Finite<N>(intValue)` | Returns `Optional` |
| Widening | `Index<T>(bounded)` | Always succeeds |
| Successor | `.successor()` → `Self?` | Partial (at max → nil) |
| Predecessor | `.predecessor()` → `Self?` | Partial (at zero → nil) |
| Offset | `.offset(by: delta)` → `Self?` | Partial (out of bounds → nil) |
| Clamped offset | `.clamped(offsetBy: delta)` | Clamps to bounds |
| Distance | `.distance(to: other)` → `Int` | Signed distance |
| Complement | `.complement()` → `Self` | N - 1 - self |
| Injection | `.injected<M>()` | Safe upcast (N → M where M >= N) |
| Projection | `.projected<M>()` → `Optional` | Checked downcast |
| Decompose | `.decomposed<Rows, Cols>()` | Row-major decomposition |
| Compose | `.composed(row:, column:)` | Row-major composition |
| Capacity | `Self.capacity()` → `Cardinal` | The bound N as cardinal |
| Max | `Self.max()` → `Self?` | N - 1, or nil if N == 0 |

**Decision tree — before using unbounded `Index<T>` in static-capacity types**:

All static-capacity types (`Buffer.Linear.Inline<N>`, `Hash.Table.Static<N>`, etc.) MUST use `Index<T>.Bounded<N>`. This eliminates runtime bounds checks that are provable at compile time.

---

#### Tier 7: Sequence Primitives (`swift-sequence-primitives`)

**Package**: `Sequence Primitives`
**Types**: `Sequence.Protocol`, iteration tags

| Tag | Operation | Signature |
|-----|-----------|-----------|
| `Sequence.ForEach` | For-each iteration | `.forEach { element in }` |
| `Sequence.Reduce` | Reduction | `.reduce.into(initial) { acc, elem in }` |
| `Sequence.Map` | Mapping | `.map { transform }` |
| `Sequence.Drain` | Consuming iteration | `.drain { element in }` |
| `Sequence.Filter` | Filtering | `.filter { predicate }` |
| `Sequence.Satisfies` | Quantification | `.satisfies { predicate }` |

**Decision tree — before writing a manual `while` loop at a call site**:

Per [IMPL-033], use the highest-level abstraction. Manual loops are only acceptable inside iteration infrastructure implementation.

---

#### Tier 8: Cyclic Primitives (`swift-cyclic-primitives`)

**Package**: `Cyclic Primitives`
**Types**: `Cyclic.Group<let N: Int>`, `Cyclic.Position`

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Modular position | `Cyclic.Group<N>` | Position modulo N |
| `.position` | Extracts linear `Ordinal` | For conversion to non-cyclic |

---

#### Tier 9: Cyclic Index Primitives (`swift-cyclic-index-primitives`)

**Package**: `Cyclic Index Primitives`
**Types**: Cyclic index for ring buffers

Used by `Buffer.Ring` for circular position tracking.

---

#### Tier 9: Bit Primitives (`swift-bit-primitives`)

**Package**: `Bit Primitives Core`
**Types**: `Bit`, `Bit.Index`

| Type | Definition |
|------|-----------|
| `Bit` | Single bit value |
| `Bit.Index` | `Index<Bit>` — position within a bit collection |

**Key conversion**: `index.retag(Bit.self)` converts any `Index<T>` to `Bit.Index` (same numeric position, different domain).

---

#### Tier 10: Vector Primitives (`swift-vector-primitives`)

**Package**: `Vector Primitives`
**Types**: Vector iteration infrastructure

Provides typed iteration over contiguous memory using the sequence tag system:

| Operation | Signature | Notes |
|-----------|-----------|-------|
| ForEach | `vector.forEach { index, element in }` | Position + element |
| Reduce | `vector.reduce.into { }` | Accumulator pattern |
| Map | `vector.map { }` | Transform elements |

---

#### Tier 11: Bit Pack Primitives (`swift-bit-pack-primitives`)

**Package**: `Bit Pack Primitives`
**Types**: `Bit.Pack` (fixed-width bit storage within a UInt)

| Operation | Signature |
|-----------|-----------|
| Get bit | `pack[bitIndex]` |
| Set bit | `pack[bitIndex] = bit` |
| Popcount | `pack.popcount` |

---

#### Tier 12: Bit Vector Primitives (`swift-bit-vector-primitives`)

**Package**: `Bit Vector Primitives`
**Types**: `Bit.Vector`, `Bit.Vector.Static<N>`

| Operation | Accessor | Signature | Notes |
|-----------|----------|-----------|-------|
| Set bit | `.set(at:)` | `callAsFunction` | Set single bit |
| Set range | `.set.range(range)` | Named method | Bulk set |
| Clear bit | `.clear(at:)` | `callAsFunction` | Clear single bit |
| Clear range | `.clear.range(range)` | Named method | Bulk clear |
| Clear all | `.clear.all()` | Named method | Reset all |
| Iterate ones | `.ones.forEach { }` | Wegner/Kernighan | Iterate set bits |
| Popcount | `.popcount` | Property | Count of set bits |
| Pop first | `.pop.first()` | Named method | Remove lowest set bit |

**Decision tree — before iterating bits manually**:

| You want | Use |
|----------|-----|
| Set a range of bits | `.set.range(range)` |
| Clear all bits | `.clear.all()` |
| Visit each set bit | `.ones.forEach { bitIndex in }` |
| Count set bits | `.popcount` |
| Check if bit is set | subscript `bitvector[bitIndex]` |

---

#### Tier 13: Memory Primitives (`swift-memory-primitives`)

**Package**: `Memory Primitives Core`
**Types**: `Memory.Address`, `Memory.Address.Count`, `Memory.Address.Offset`

| Type | Definition | Meaning |
|------|-----------|---------|
| `Memory.Address` | `Tagged<Memory, Ordinal>` | Byte position |
| `Memory.Address.Count` | `Tagged<Memory, Cardinal>` | Byte quantity |
| `Memory.Address.Offset` | `Tagged<Memory, Affine.Discrete.Vector>` | Byte displacement |

**Stdlib integration** (`Memory Primitives Standard Library Integration`):

| Overload | File | Use Case |
|----------|------|----------|
| `memory.initialize(as:, repeating:, count: Index<T>.Count)` | Typed element init |
| `memory.initialize(as:, from:, count: Index<T>.Count)` | Typed copy-init |
| `memory.move.initialize(as:, from:, count: Index<T>.Count)` | Typed move-init |
| `memory.bind(to:, capacity: Index<T>.Count)` | Typed bind |
| `memory.copy(from:, count: Memory.Address.Count)` | Typed byte copy |
| `store.bytes(of:, at: Memory.Address.Offset, as:)` | Typed byte store |

---

#### Tier 14: Storage Primitives (`swift-storage-primitives`)

**Package**: `Storage Primitives Core`, `Storage Primitives Heap`, `Storage Primitives Inline`, `Storage Primitives Split`
**Types**: `Storage<Element>`, `Storage.Heap`, `Storage.Inline<N>`, `Storage.Split`, `Storage.Error`

| Operation | Accessor | Signature | Notes |
|-----------|----------|-----------|-------|
| Pointer access | `pointer(at:)` | `→ UnsafeMutablePointer<Element>` | Core primitive |
| Initialize | `.initialize(to:, at:)` | `callAsFunction` | Direct init |
| Initialize next | `.initialize.next(to:)` | Named method | Tracked init |
| Move | `.move(at:)` | `callAsFunction` | Direct move |
| Move last | `.move.last()` | Named method | Tracked move |
| Deinitialize | `.deinitialize(at:)` | `callAsFunction` | Direct deinit |
| Deinitialize all | `.deinitialize.all()` | Named method | Bulk deinit |
| Copy | `.copy(range:, to:)` | `callAsFunction` | Range copy |
| Copy clone | `.copy()` | `callAsFunction` | Full clone |

**Errors**: `Storage.Error` — `.capacityExceeded`, `.empty`

**Split storage**: `Storage.Split` — dual-lane storage with typed field handles and `pointer(field:, at:)`.

**Decision tree — before writing manual pointer arithmetic**:

| You want | Use |
|----------|-----|
| Get pointer to element | `storage.pointer(at: slot)` |
| Initialize an element | `storage.initialize(to: value, at: slot)` |
| Move an element out | `storage.move(at: slot)` |
| Deinitialize an element | `storage.deinitialize(at: slot)` |
| Copy elements | `storage.copy(range: range, to: destination)` |
| Track next init position | `storage.initialize.next(to: value)` |
| Track last element | `storage.move.last()` |

---

#### Tier 15: Buffer Primitives (`swift-buffer-primitives`)

**Package**: `Buffer Primitives Core`, `Buffer Ring Primitives`, `Buffer Linear Primitives`, `Buffer Slab Primitives`, `Buffer Linked Primitives`, `Buffer Slots Primitives`, `Buffer Arena Primitives`
**Types**: `Buffer.Linear`, `Buffer.Ring`, `Buffer.Slab`, `Buffer.Linked`, `Buffer.Slots`, `Buffer.Arena`

Buffer-primitives is the primary consumer of all lower-tier infrastructure. It demonstrates the canonical usage patterns:

**Infrastructure usage observed in buffer-primitives**:

| Pattern | Infrastructure Used | Example |
|---------|-------------------|---------|
| Typed counting | `.one`, `.zero` from Cardinal.Protocol | `count += .one`, `count.subtract.saturating(.one)` |
| Count → Index | `.map(Ordinal.init)` | `currentCount.map(Ordinal.init)` for slot computation |
| Cross-domain tag | `.retag(Bit.self)` | `slot.retag(Bit.self)` for bit vector indexing |
| Range transformation | `.map.bounds { }` | `range.map.bounds { .retag(Bit.self) }` |
| Property accessors | `Property<Tag, Base>.View` | `storage.initialize.next(to:)`, `storage.move.last()` |
| Static methods | `Buffer.Linear.append(...)` | Core logic in statics per [IMPL-023] |
| Typed throws | `throws(Storage.Error)` | `.capacityExceeded`, `.empty` |
| Pointer access | `storage.pointer(at: slot)` | Never manual `base + offset` |
| Bulk operations | `.set.range()`, `.clear.range()` | Bit vector bulk ops |
| Iteration | `.forEach { }`, `.linearize { }` | Enum iteration for initialization state |

---

### Gap Analysis: Existing Skill vs. Complete Inventory

The current `existing-infrastructure` SKILL.md covers:

| Section | IDs | Coverage |
|---------|-----|----------|
| Stdlib integration modules | INFRA-001 | 10 modules listed ✓ |
| Cardinal integration | INFRA-002 | Span, BufferPointer, ContiguousArray overloads ✓ |
| Ordinal integration | INFRA-003 | Pointer subscripts, Range operations ✓ |
| Affine integration | INFRA-004 | Pointer arithmetic overloads ✓ |
| Memory integration | INFRA-005 | Raw pointer operations ✓ |
| Tagged functors | INFRA-010 | `.map()`, `.retag()` ✓ |
| Ratio scaling | INFRA-011 | `Affine.Discrete.Ratio` ✓ |
| Cardinal constants | INFRA-012 | `.zero`, `.one` ✓ |
| Bounded indices | INFRA-013 | `Index<T>.Bounded<N>` ✓ |
| Decision trees | INFRA-020, INFRA-021 | `Int(bitPattern:)`, `.rawValue` ✓ |

**Critical gaps** (infrastructure that exists but is NOT in the skill):

| Gap | Infrastructure | Impact |
|-----|---------------|--------|
| Property accessor pattern | `Property<Tag, Base>`, `.View`, `.View.Typed`, `.View.Read` | Agents hand-roll accessor structs |
| Ordinal policy accessors | `.successor`, `.predecessor`, `.advance`, `.retreat`, `.distance` with `.saturating()`, `.exact()`, `.clamped()` | Agents write manual increment/decrement |
| Cardinal subtraction | `.subtract.saturating()`, `.subtract.exact()` — no `-` operator (principled) | Agents try `count - 1` (won't compile) or use `.rawValue` |
| Bit vector bulk ops | `.set.range()`, `.clear.range()`, `.clear.all()`, `.ones.forEach {}`, `.popcount` | Agents write per-element loops |
| Storage primitives | `pointer(at:)`, `.initialize`, `.move`, `.deinitialize`, `.copy` | Agents write manual `withUnsafe*` closures |
| Static method architecture | [IMPL-023] pattern for ~Copyable overloads | Agents use instance method delegation (infinite recursion) |
| Finite operations | `.successor()`, `.predecessor()`, `.offset(by:)`, `.complement()`, `.injected()`, `.projected()`, `.decomposed()`, `.composed()` | Agents extract rawValue for bounded arithmetic |
| Sequence iteration | `.forEach`, `.reduce.into`, `.map`, `.drain`, `.filter`, `.satisfies` tags | Agents write `while` loops at call sites |
| Vector iteration | Position + element forEach/reduce/map | Agents write manual indexed loops |
| `Tagged.min()` / `Tagged.max()` | `Type.min(a, b)` / `Type.max(a, b)` | Agents use `Swift.min()` with rawValue extraction |
| Cyclic group | `Cyclic.Group<N>` for ring buffer positions | Agents implement modular arithmetic manually |
| Enum iteration | `.forEach { range in }`, `.linearize { range, offset in }` on initialization enums | Agents write manual switch statements |
| `Ordinal.Protocol` / `Cardinal.Protocol` | Protocol-lifted operations work on ALL tagged types | Agents add operations to specific tagged types |
| Index type algebra | `Index<T>.Count`, `Index<T>.Offset` — composed from base types | Agents construct manual type chains |
| Principled absences | No `Cardinal - Cardinal`, no `Index * 2`, no `pointer + count` | Agents propose adding these operations |

**Structural gaps** (organization problems in the skill):

| Gap | Description |
|-----|-------------|
| No tier organization | Infrastructure listed by feature, not by package/tier — hard to find |
| No protocol coverage | `Cardinal.Protocol`, `Ordinal.Protocol` not mentioned — agents miss that operations lift automatically |
| No principled absence catalog | Agents don't know which absences are intentional |
| No Property pattern documentation | The accessor pattern is completely absent |
| No static method architecture | [IMPL-023] not referenced — critical for ~Copyable types |
| No usage examples from buffer-primitives | No "this is what correct usage looks like" |
| No iteration infrastructure | Sequence/vector iteration completely missing |

### Pattern Taxonomy

The infrastructure provides eight distinct reusable patterns:

| # | Pattern | Package(s) | Description |
|---|---------|-----------|-------------|
| 1 | Phantom-typed wrapper | identity | `Tagged<Tag, RawValue>` with functor ops |
| 2 | Protocol-lifted arithmetic | cardinal, ordinal | Operations defined once, lifted to all tagged forms |
| 3 | Policy-aware accessors | ordinal, cardinal | `.operation.policy()` via Property |
| 4 | Verb-as-property | property, storage, buffer | `instance.verb(args)` + `instance.verb.variant()` |
| 5 | Stdlib boundary overloads | 10 integration modules | Typed overloads hiding `Int(bitPattern:)` |
| 6 | Affine space arithmetic | affine, index | Points, vectors, ratios with dimensional rules |
| 7 | Static method delegation | (pattern, not package) | Core logic in statics for ~Copyable overloads |
| 8 | Compile-time bounded indices | finite | `Ordinal.Finite<N>`, `Index<T>.Bounded<N>` |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: The `existing-infrastructure` skill MUST be restructured as follows:

### 1. Reorganize by Decision Context

Replace the current feature-oriented structure with a **decision-oriented** structure. The skill should be organized around the questions an implementer asks:

| Section | Question | Current Coverage | Recommended |
|---------|----------|-----------------|-------------|
| "I need to count" | How do I express quantities? | Partial (INFRA-012) | Full: Cardinal, .zero/.one, .subtract policy, Cardinal.Protocol |
| "I need a position" | How do I express indices? | Missing | Full: Ordinal, Index<T>, .successor/.predecessor/.advance/.retreat |
| "I need to scale" | How do I double capacity? | Partial (INFRA-011) | Full: Affine.Discrete.Ratio with examples |
| "I need pointer access" | How do I access elements? | Partial (INFRA-003/004) | Full: pointer(at:), stdlib integration, Storage delegation |
| "I need to iterate" | How do I loop over elements? | Missing | Full: .forEach, .reduce, .drain, enum iteration |
| "I need to convert" | How do I cross domains? | Partial (INFRA-010) | Full: .map(), .retag(), protocol conformance |
| "I need mutation" | How do I express operations? | Missing | Full: Property<Tag,Base>, Property.View, callAsFunction |
| "I need bounds" | How do I prove capacity? | Partial (INFRA-013) | Full: Finite<N>, Bounded<N>, narrowing/widening |
| "I need bits" | How do I track occupancy? | Missing | Full: Bit.Vector, .set/.clear/.ones/.pop |
| "I need raw memory" | How do I initialize/move/copy? | Partial (INFRA-005) | Full: Storage, Memory integration |

### 2. Add Principled Absence Section

Document what does NOT exist and WHY. This prevents agents from proposing operations that violate mathematical properties:

| Absent Operation | Why | What To Write Instead |
|-----------------|-----|----------------------|
| `Cardinal - Cardinal` | Subtraction on naturals isn't total | `.subtract.saturating()` or `.subtract.exact()` |
| `Index * 2` | Scaling a position is meaningless | `offset * ratio` or rethink the operation |
| `pointer + count` | Counts are scalars, not vectors | `pointer + offset` where offset is computed correctly |
| `Bounded<N> + .one → Bounded<N>` | Addition on bounded ordinals is partial | `.successor()` returns `Optional` |
| `count * count` | Multiplying same-dimension quantities changes dimension | `count.scale(by: ratio)` |

### 3. Add Protocol Lifting Section

Document that `Cardinal.Protocol` and `Ordinal.Protocol` conformances mean ALL operations automatically work on tagged types. Agents must understand that `Index<T>.Count + .one` works because `Tagged<T, Cardinal>` conforms to `Cardinal.Protocol`, not because someone added a `+` operator to `Index<T>.Count`.

### 4. Add Complete Infrastructure Reference

The full inventory from the Analysis section should be included as an appendix, organized by tier. This serves as the definitive lookup table.

### 5. Add Buffer-Primitives Usage Gallery

Include 5–10 annotated code examples from buffer-primitives showing correct infrastructure usage. These serve as canonical "this is what good code looks like" references.

### 6. Retain and Expand Decision Trees

The existing INFRA-020 and INFRA-021 decision trees are effective. Add:

- INFRA-022: Before writing a `while` loop (use iteration infrastructure)
- INFRA-023: Before hand-rolling an accessor struct (use Property)
- INFRA-024: Before writing `withUnsafe*` closures (use `pointer(at:)`)
- INFRA-025: Before writing a switch on initialization state (use `.forEach`/`.linearize`)
- INFRA-026: Before writing `count - 1` (use `.subtract.saturating(.one)`)

**Implementation path**:

1. Create the restructured skill document based on this research
2. Organize by decision context (what the implementer is trying to do)
3. Include the principled absence catalog
4. Add protocol lifting explanation
5. Include the tier-organized infrastructure reference
6. Add buffer-primitives usage gallery
7. Expand decision trees to cover all common mistakes
8. Update the research index

## References

### Academic Literature

1. Leijen, D. & Meijer, E. (1999). "Domain Specific Embedded Compilers." *DSL'99*, Springer LNCS.
2. Hinze, R. (2003). "Fun with Phantom Types." *The Fun of Programming*, Palgrave Macmillan.
3. Cheney, J. & Hinze, R. (2004). "First-Class Phantom Types." *ICFP 2004*, ACM.
4. Fowler, M. (2005). "FluentInterface." martinfowler.com.
5. Fluet, M. & Pucella, R. (2006). "Phantom Types and Subtyping." *Journal of Functional Programming*, 16(6), 775-791.
6. Kennedy, A. (2009). "Types for Units-of-Measure: Theory and Practice." *CEFP 2009*, Springer LNCS.
7. van Laarhoven, T. (2009). "CPS based functional references." Blog post.
8. Breitner, J. et al. (2014). "Safe Zero-cost Coercions for Haskell." *ICFP 2014*, ACM.
9. Breitner, J. et al. (2016). "Safe Zero-cost Coercions for Haskell." *Journal of Functional Programming*, 26.

### Swift Evolution

10. SE-0255 (2019). "Implicit Returns from Single-Expression Functions."
11. SE-0380 (2023). "if and switch Expressions."
12. SE-0390 (2023). "Noncopyable structs and enums."
13. SE-0427 (2024). "Noncopyable generics."

### Internal References

14. `swift-institute/Skills/implementation/SKILL.md` — [IMPL-INTENT], [IMPL-000], [IMPL-001], [IMPL-002], [IMPL-003], [IMPL-010], [IMPL-023], [IMPL-033], [IMPL-050–053], [PATTERN-017–019]
15. `swift-institute/Skills/conversions/SKILL.md` — [IDX-*], [CONV-*]
16. `swift-institute/Skills/existing-infrastructure/SKILL.md` — [INFRA-001–021]
17. `swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md` — Protocol lifting analysis
18. `swift-institute/Research/intent-over-mechanism-expression-first.md` — Expression-first axiom
19. `swift-primitives/Documentation.docc/Primitives Tiers.md` — Tier assignments
20. `swift-primitives/Documentation.docc/Primitives Layering.md` — Semantic domain analysis
