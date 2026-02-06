# Protocol Abstraction for Phantom-Typed Wrappers

<!--
---
version: 1.3.0
last_updated: 2026-02-04
status: DECISION
tier: 3
supersedes: tagged-extension-duplication.md
changelog:
  - 1.3.0 (2026-02-04): Documented ~Copyable associated type limitation blocking
    Domain for tagged conformances where Tag: ~Copyable. Revised to phased plan:
    Phase 1 (now) unifies same-type operators (17/31); Phase 2 (when Swift supports
    associatedtype: ~Copyable) adds Domain for cross-type unification (31/31).
    Added noncopyable-associatedtype-domain experiment reference.
  - 1.2.0 (2026-02-04): Added tag-enforcing cross-type operations (§Tag-Enforcing),
    associatedtype Domain mechanism, companion types, revised duplication claims,
    updated formal semantics and implementation sequence.
  - 1.1.0 (2026-02-04): Added generalization analysis (§Generalization), Optic.Iso relationship,
    experiment results for unified protocol approaches, updated implementation sequence.
  - 1.0.0 (2026-02-04): Initial analysis and decision for per-type protocol pattern.
---
-->

## Context

The Swift Institute primitives layer uses `Tagged<Tag, RawValue>` (a phantom-typed wrapper from identity-primitives, Tier 0) to create type-safe variants of base types:

| Base Type | Tagged Form | Typealias |
|-----------|-------------|-----------|
| `Ordinal` | `Tagged<Element, Ordinal>` | `Index<Element>` |
| `Cardinal` | `Tagged<Element, Cardinal>` | `Index<Element>.Count` |
| `Ordinal` | `Tagged<Memory, Ordinal>` | `Memory.Address` |
| `Cardinal` | `Tagged<Memory, Cardinal>` | `Memory.Address.Count` |
| `Affine.Discrete.Vector` | `Tagged<Tag, Affine.Discrete.Vector>` | `Index<Tag>.Offset` |

Every operation (arithmetic, comparison, alignment, bounds-checking) on a base type must also work on its Tagged form. The current approach defines each operator twice: once for the bare type and once for the Tagged wrapper. This produces N types x M operators duplicated declarations with structurally identical implementations that only differ in wrapping/unwrapping.

This research was triggered by the `Memory.Alignment.alignUp` refactoring (2026-02-04), which exposed the duplication when narrowing from generic `FixedWidthInteger` to concrete `Cardinal`. The existing research document `tagged-extension-duplication.md` explored this problem space with different solutions (shared parameterized tags, macros, gyb). This document supersedes that analysis with a protocol-based approach that has been empirically verified.

## Question

How should the Swift Institute primitives layer define operations that must work on both bare types (`Cardinal`, `Ordinal`, `Affine.Discrete.Vector`) and their phantom-typed wrappers (`Tagged<Tag, _>`), such that:

1. Each operation is defined exactly once (zero duplication)
2. The return type is preserved (Tagged in, Tagged out)
3. `rawValue` access is confined per [CONV-001/002]
4. The pattern is consistent across all base types
5. The solution works within Swift 6.2's type system

## Prior Art

### Haskell: Coercible and DerivingVia

Haskell's `newtype` declarations create types that are distinct at compile time but share a runtime representation. `GeneralizedNewtypeDeriving` lifts type class instances from the underlying type to the newtype via the compiler-managed `Coercible` type class, which witnesses representational equality. `DerivingVia` (GHC 8.6+) generalizes further, allowing a type to inherit instances from any `Coercible` type.

**Relation.** `Tagged<Tag, Cardinal>` is representationally identical to `Cardinal`, just as Haskell's `newtype Age = Age Int` is to `Int`. Haskell solves the operator duplication problem completely: `deriving newtype (Num, Ord, Eq)` generates all operators with zero cost and zero boilerplate. Swift lacks both `Coercible` and `deriving`, forcing manual protocol conformances.

### Rust: The Newtype Pattern

Rust's newtype idiom uses single-field tuple structs with `#[repr(transparent)]` for ABI-level layout identity. However, Rust provides no automatic trait forwarding; every operator must be manually implemented or generated via procedural macros. The `Deref` trait offers implicit method forwarding but is considered an anti-pattern for general-purpose newtype delegation.

**Relation.** Rust's situation is structurally identical to ours. The community response -- procedural macros and RFC discussions -- confirms this is a recognized pain point with no elegant language-level solution.

### Point-Free swift-tagged

The [swift-tagged](https://github.com/pointfreeco/swift-tagged) library uses Swift's conditional conformances to forward standard library protocol implementations from `RawValue` to `Tagged`. Each forwarding conformance is hand-written once inside the `Tagged` type.

**Relation.** swift-tagged demonstrates both the power and limitation of conditional conformance. It works for standard library protocols but cannot be extended by downstream packages for custom operators due to the orphan rule. Our situation is more constrained: we define custom operators across multiple packages that cannot modify `Tagged`.

### Swift Forums: Phantom Type Coercion

The [Swift Forums discussion on coercing phantom types](https://forums.swift.org/t/coerce-phantom-types/17277) (October 2018) directly addresses this gap. Contributors noted Swift lacks Haskell's `coerce` and suggested `@inlinable` initializers as workarounds, trusting the optimizer to remove copies.

### Academic Literature

| Reference | Contribution |
|-----------|-------------|
| Fluet & Pucella, "Phantom Types and Subtyping," JFP 16(6), 2006 | Phantom types encode arbitrary finite subtyping hierarchies in HM type systems |
| Cheney & Hinze, "First-Class Phantom Types," ICFP 2004 | Type equations for phantom types, precursor to GADTs |
| Hinze, "Fun with Phantom Types," 2003 | Accessible demonstrations: type-safe printf, Leibniz equality |
| Leijen & Meijer, "Domain Specific Embedded Compilers," DSL'99 | Pioneered phantom type variables for well-typedness in embedded languages |
| Breitner et al., "Safe Zero-cost Coercions for Haskell," ICFP 2014 / JFP 26, 2016 | Formalized representational equality through roles (nominal, representational, phantom) |

## Theoretical Grounding

### Representational Isomorphism

A `Cardinal.Protocol` conformance establishes a *representational isomorphism* between the conforming type `C` and `Cardinal`:

```
  cardinal : C → Cardinal     (projection)
  init(_:) : Cardinal → C     (injection)
```

With the round-trip law: `C(x.cardinal) = x` for all `x: C`.

This is a weaker property than Haskell's `Coercible`, which guarantees bitwise identity. Our isomorphism is *semantic* -- the values are preserved, but the compiler may or may not eliminate the intermediate representation. With `@inlinable`, the optimizer reliably does so.

### Phantom Parameter Classification

Following Breitner et al., `Tagged<Tag, RawValue>` has:

- `Tag`: **phantom role** -- appears in the type but not the representation. Operations that depend only on `RawValue` should be liftable across `Tag` changes.
- `RawValue`: **representational role** -- the actual stored data. Operations are defined in terms of this.

Swift has no role system. The protocol abstraction manually encodes what a role system would provide automatically: the assertion that `Tag` is irrelevant for the operation being performed.

### Lifting Principle

Given a function `f : Cardinal → Cardinal`, the lifted function `f' : C → C` for any `C : Cardinal.Protocol` is:

```
  f'(x) = C(f(x.cardinal))
```

This is sound because:
1. `x.cardinal` extracts the representation (phantom-safe: ignores Tag)
2. `f` operates on the representation
3. `C(...)` reconstructs the original type (phantom-safe: restores Tag)

For binary operations `g : Cardinal × Cardinal → Cardinal`:

```
  g'(x, y) = C(g(x.cardinal, y.cardinal))
```

Type preservation holds because both `x` and `y` have type `C`, and the result is constructed via `C.init`.

## Formal Semantics

### Type Definitions

```
Types:
  Cardinal                     -- quantity (UInt-backed)
  Ordinal                      -- position (UInt-backed)
  Vector                       -- displacement (Int-backed)
  Tagged<Tag, T>               -- phantom-typed wrapper

Protocols:
  Cardinal.Protocol            -- { Domain, cardinal: Cardinal, init(_: Cardinal) }
  Ordinal.Protocol             -- { Domain, ordinal: Ordinal, init(_: Ordinal) }
  Vector.Protocol              -- { Domain, vector: Vector, init(_: Vector) }

Conformances (Phase 1 — without Domain):
  Cardinal : Cardinal.Protocol
  Tagged<Tag, Cardinal> : Cardinal.Protocol   (for all Tag: ~Copyable)
  Ordinal : Ordinal.Protocol
  Tagged<Tag, Ordinal> : Ordinal.Protocol     (for all Tag: ~Copyable)
  Vector : Vector.Protocol
  Tagged<Tag, Vector> : Vector.Protocol       (for all Tag: ~Copyable)

Conformances (Phase 2 — with Domain, requires associatedtype: ~Copyable):
  Cardinal : Cardinal.Protocol            (Domain = Never)
  Tagged<Tag, Cardinal> : Cardinal.Protocol  (Domain = Tag, for all Tag: ~Copyable)
  Ordinal : Ordinal.Protocol              (Domain = Never)
  Tagged<Tag, Ordinal> : Ordinal.Protocol    (Domain = Tag, for all Tag: ~Copyable)
  Vector : Vector.Protocol                (Domain = Never)
  Tagged<Tag, Vector> : Vector.Protocol      (Domain = Tag, for all Tag: ~Copyable)
```

The `Domain` associated type encodes the phantom tag at the protocol level:
- Bare types use `Never` — an uninhabited sentinel indicating "untagged / universal domain"
- Tagged types use their phantom `Tag` parameter

**Language limitation (Swift 6.2.3):** `associatedtype Domain: ~Copyable` does not compile — the compiler emits *"cannot suppress 'Copyable' requirement of an associated type."* Since `Tag` in `Tagged<Tag: ~Copyable, RawValue>` may be noncopyable, `typealias Domain = Tag` fails the implicit `Copyable` requirement. Domain is therefore deferred to Phase 2. See §Constraints and Limitations.

### Typing Rules

**Protocol extraction:**
```
  Γ ⊢ e : C    C : Cardinal.Protocol
  ────────────────────────────────────
  Γ ⊢ e.cardinal : Cardinal
```

**Protocol construction:**
```
  Γ ⊢ e : Cardinal    C : Cardinal.Protocol
  ──────────────────────────────────────────
  Γ ⊢ C(e) : C
```

**Type-preserving lift (unary):**
```
  Γ ⊢ f : Cardinal → Cardinal    Γ ⊢ x : C    C : Cardinal.Protocol
  ───────────────────────────────────────────────────────────────────
  Γ ⊢ C(f(x.cardinal)) : C
```

**Type-preserving lift (binary, same-type):**
```
  Γ ⊢ g : Cardinal × Cardinal → Cardinal
  Γ ⊢ x : C    Γ ⊢ y : C    C : Cardinal.Protocol
  ─────────────────────────────────────────────────
  Γ ⊢ C(g(x.cardinal, y.cardinal)) : C
```

**Cross-protocol lift (Ordinal ± Vector → Ordinal):**
```
  Γ ⊢ (+) : Ordinal × Vector → Ordinal
  Γ ⊢ x : O    O : Ordinal.Protocol
  Γ ⊢ v : Vector
  ─────────────────────────────────────
  Γ ⊢ O(x.ordinal + v) : O
```

**Tag-enforcing cross-type lift (Ordinal ± Cardinal → Ordinal):**
```
  Γ ⊢ (+) : Ordinal × Cardinal → Ordinal
  Γ ⊢ x : O    O : Ordinal.Protocol
  Γ ⊢ y : C    C : Cardinal.Protocol
  O.Domain == C.Domain
  ─────────────────────────────────────
  Γ ⊢ O(x.ordinal + y.cardinal) : O
```

The `O.Domain == C.Domain` constraint is the key addition. It enforces:
- `Never == Never` for bare types (trivially satisfied)
- `Tag == Tag` for tagged types with the same phantom tag (correctly unified)
- `Tag₁ ≠ Tag₂` rejection for tagged types with different phantom tags (compile error)

This prevents cross-domain mixing: `Tagged<Foo, Ordinal> + Tagged<Bar, Cardinal>` is rejected because `Foo ≠ Bar`.

**Tag-enforcing cross-type comparison:**
```
  Γ ⊢ (<) : Vector × Cardinal → Bool
  Γ ⊢ x : V    V : Vector.Protocol
  Γ ⊢ y : C    C : Cardinal.Protocol
  V.Domain == C.Domain
  ─────────────────────────────────────
  Γ ⊢ x.vector < y.cardinal : Bool
```

**Companion type lift (Ordinal - Ordinal → Vector with tag preservation):**
```
  Γ ⊢ (-) : Ordinal × Ordinal → Vector
  Γ ⊢ x : O    Γ ⊢ y : O    O : Ordinal.Protocol
  O.CompanionVector : Vector.Protocol
  ─────────────────────────────────────
  Γ ⊢ O.CompanionVector(x.ordinal - y.ordinal) : O.CompanionVector
```

Where `Ordinal.CompanionVector = Vector` and `Tagged<Tag, Ordinal>.CompanionVector = Tagged<Tag, Vector>`. The companion type maps operations whose return type differs between bare and tagged forms into the correct domain.

### Soundness Argument

The protocol abstraction is sound (does not introduce type confusion) because:

1. **Tag preservation**: The phantom tag is never inspected or modified. `C.init` reconstructs with the same `Tag` as was projected by `.cardinal`.

2. **Round-trip identity**: For `Cardinal`, `Cardinal(x.cardinal) = Cardinal(x) = x`. For `Tagged<Tag, Cardinal>`, `Tagged(x.cardinal) = Tagged(__unchecked: (), x.rawValue) = x` (by construction of the conformance).

3. **No tag leakage**: The protocol witnesses (`cardinal`, `init`) are the only points where `rawValue` is accessed. These are confined to the package defining the conformance, satisfying [CONV-001/002].

4. **Parametricity**: A function `f<C: Cardinal.Protocol>(_ x: C) -> C` cannot inspect `Tag` -- it can only operate through the protocol interface. This is the parametricity guarantee that makes phantom types safe.

5. **Domain coherence** *(Phase 2)*: The `Domain` associated type is assigned exactly once per conformance and is immutable. For bare types, `Domain = Never` forms a single equivalence class (all bare types interoperate). For tagged types, `Domain = Tag` partitions conforming types by their phantom tag. The `where O.Domain == C.Domain` constraint enforces that cross-type operations stay within a single domain. Since `Never ≠ Tag` for any inhabited `Tag`, bare and tagged types cannot be mixed in cross-type operations — this is correct, as such mixing would lose the tag on one side. *(Blocked until Swift supports `associatedtype: ~Copyable`. See §Constraints and Limitations.)*

6. **Companion type correctness** *(Phase 2)*: When `O.CompanionVector` maps `Ordinal → Vector` and `Tagged<Tag, Ordinal> → Tagged<Tag, Vector>`, the companion type preserves the same `Domain` as the input. This ensures the result type belongs to the same domain as its operands. *(Depends on Domain; blocked by the same language limitation.)*

## Tag-Enforcing Cross-Type Operations

### The Problem

The basic protocol abstraction (`Cardinal.Protocol`, `Ordinal.Protocol`) erases the phantom tag. A function constrained as `<O: Ordinal.Protocol, C: Cardinal.Protocol>` cannot enforce that `O` and `C` share the same `Tag`. This means `Tagged<Foo, Ordinal> + Tagged<Bar, Cardinal>` would compile — a cross-domain operation that should be a compile error.

Of the operator pairs identified across the primitives layer, three categories are structurally affected:

| Category | Count | Example | Constraint |
|----------|-------|---------|------------|
| Ordinal ± Cardinal | 4 | `Tagged<Tag, Ordinal> + Tagged<Tag, Cardinal>` | Same tag on both operands |
| Ordinal ↔ Cardinal comparisons | 2+ | `Tagged<Tag, Ordinal> < Tagged<Tag, Cardinal>` | Same tag on both operands |
| Vector ↔ Cardinal comparisons | 8 | `Tagged<Tag, Vector> < Tagged<Tag, Cardinal>` | Same tag on both operands |
| Ordinal - Ordinal → Vector | 1 | `Tagged<Tag, Ordinal> - Tagged<Tag, Ordinal> → Tagged<Tag, Vector>` | Same tag; different return type |

Additionally, the `Ordinal - Ordinal → Vector` case has a *structural* asymmetry: the bare version returns `Vector`, while the tagged version returns `Tagged<Tag, Vector>`. This is not a tag-enforcement issue but a return-type mapping issue.

### The `Domain` Mechanism (Phase 2 — Blocked)

Adding an `associatedtype Domain: ~Copyable` to each protocol recovers the same-tag guarantee. This mechanism is **design-validated** (see experiment evidence below) but **blocked** by the lack of `associatedtype: ~Copyable` support in Swift 6.2.3. The design is recorded here for implementation when the language supports it.

```swift
extension Cardinal {
    protocol `Protocol` {
        associatedtype Domain
        var cardinal: Cardinal { get }
        init(_ cardinal: Cardinal)
    }
}
```

Conformances assign `Domain` based on whether the type is bare or tagged:

```swift
extension Cardinal: Cardinal.`Protocol` {
    typealias Domain = Never        // bare: universal domain
}

extension Tagged: Cardinal.`Protocol` where RawValue == Cardinal, Tag: ~Copyable {
    typealias Domain = Tag           // tagged: phantom tag IS the domain
}
```

> **Note:** The above requires `associatedtype Domain: ~Copyable` in the protocol declaration, because `Tag` may be noncopyable. This does not compile in Swift 6.2.3. See §Constraints and Limitations for the blocking issue and the upstream pitch that addresses it.

Cross-type operators constrain `Domain` equality:

```swift
func + <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(Ordinal(lhs.ordinal.rawValue + rhs.cardinal.rawValue))
}
```

This resolves correctly in all cases:
- **Bare + Bare**: `Never == Never` — trivially satisfied
- **Tagged + Tagged (same tag)**: `Foo == Foo` — satisfied
- **Tagged + Tagged (different tag)**: `Foo ≠ Bar` — **compile error**: *"requires the types 'Foo' and 'Bar' be equivalent"*
- **Tagged + Bare**: `Foo ≠ Never` — **compile error** (correctly prevents cross-domain mixing)

### Companion Types for Different Return Types

The `Ordinal - Ordinal → Vector` case requires a *companion type* — an associated type that maps to the correct return type within the same domain:

```swift
extension Ordinal {
    typealias CompanionVector = Affine.Discrete.Vector
}

extension Tagged where RawValue == Ordinal {
    typealias CompanionVector = Tagged<Tag, Affine.Discrete.Vector>
}
```

The operator returns the companion type:

```swift
func - <O: OrdinalWithCompanions>(lhs: O, rhs: O) -> O.CompanionVector {
    O.CompanionVector(Vector(Int(lhs.ordinal.rawValue) - Int(rhs.ordinal.rawValue)))
}
```

This requires a richer protocol than the base `Ordinal.Protocol` — either a protocol refinement or a separate protocol for operations that produce companion types. The associated type is named `CompanionVector` in Swift (associated types cannot be nested), though the conceptual reading per [API-NAME-001] is "the Vector companion within the Ordinal domain."

### Experiment Evidence

The `tag-preserving-protocol-abstraction` experiment (2026-02-04, Swift 6.2.3) confirmed all variants:

| Variant | Result |
|---------|--------|
| V1a: Same-type ops (Domain ignored) | CONFIRMED |
| V1b: Cross-type ops with `where O.Domain == C.Domain` | CONFIRMED |
| V1c: Cross-type comparisons (Vector ↔ Cardinal, Ordinal ↔ Cardinal) | CONFIRMED |
| V1d: Companion types (`Ordinal - Ordinal → O.CompanionVector`) | CONFIRMED |
| V2: Primary associated type syntax (`where O.D == C.D`) | CONFIRMED |
| V3: `Never == Never` resolves for bare types | CONFIRMED |
| V4: Cross-domain rejection (`Foo ≠ Bar` compile error) | CONFIRMED |
| V5: Compound assignment (`+=`, `-=`) with tag enforcement | CONFIRMED |
| V6: Companion type return (`Ordinal → Vector`, `Tagged → Tagged`) | CONFIRMED |
| V7: Full comparison suite unified | CONFIRMED |

With the `Domain` mechanism, all operator pairs are unifiable — the count moves from 17/31 (protocol abstraction alone) to 31/31 (protocol abstraction + `Domain`).

**Important caveat:** The `tag-preserving-protocol-abstraction` experiment uses `Tag: Copyable` (not `~Copyable`) to isolate the Domain mechanism from the associated type limitation. This validates the *design* but not the *production deployment*, which requires `associatedtype Domain: ~Copyable`. The `noncopyable-associatedtype-domain` experiment (2026-02-04, Swift 6.2.3) confirmed this blocker:

| Variant | Result |
|---------|--------|
| V1: `associatedtype Domain` (plain) with `Tag: ~Copyable` | REFUTED — "does not conform to Copyable" |
| V2: `associatedtype Domain: ~Copyable` | REFUTED — "cannot suppress 'Copyable' requirement of an associated type" |
| V3: `associatedtype Domain: ~Copyable & ~Escapable` | REFUTED — both suppressions rejected |
| V6–V8: Workaround via `Witness<Tag>` wrapper | CONFIRMED — but rejected as non-timeless |

The Domain mechanism is sound in design. Its deployment is blocked by a language limitation with an active upstream pitch (see References).

## Analysis

### Option A: Per-Type Operator Duplication (Status Quo Ante)

Define each operator twice: once for bare type, once for `Tagged`.

```swift
// Bare (Affine.Discrete+Arithmetic.swift)
func + (lhs: Ordinal, rhs: Vector) throws(Ordinal.Error) -> Ordinal
// Tagged (Tagged+Affine.swift)
func + <Tag: ~Copyable>(lhs: Tagged<Tag, Ordinal>, rhs: Tagged<Tag, Vector>) throws(Ordinal.Error) -> Tagged<Tag, Ordinal>
```

| Criterion | Assessment |
|-----------|-----------|
| Duplication | N types x M operators = N*M pairs |
| Type safety | Full |
| Performance | Optimal (no abstraction) |
| Maintenance | Every change must be applied twice |
| rawValue confinement | Spread across many files |

### Option B: Protocol Abstraction with Domain (This Approach — Phased)

Define a protocol per base type. Write each operator once, generic over the protocol. In Phase 1, same-type operators are unified immediately. In Phase 2 (when Swift supports `associatedtype: ~Copyable`), add `associatedtype Domain` to each protocol and unify cross-type operators with `where O.Domain == C.Domain`.

```swift
// Phase 1 (now): Same-type operators unified
func + <C: Cardinal.`Protocol`>(lhs: C, rhs: C) -> C {
    C(Cardinal(lhs.cardinal.rawValue + rhs.cardinal.rawValue))
}

// Phase 2 (future): Cross-type operators unified via Domain
func + <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(Ordinal(lhs.ordinal.rawValue + rhs.cardinal.rawValue))
}
```

| Criterion | Assessment |
|-----------|-----------|
| Duplication | Phase 1: 17/31 unified; Phase 2: 31/31 unified |
| Type safety | Full (type-preserving generics; same-tag enforcement in Phase 2) |
| Performance | Equivalent after inlining (`@inlinable` + optimizer) |
| Maintenance | Single definition per same-type operation; cross-type duplicated until Phase 2 |
| rawValue confinement | Protocol conformance + operator body only |

### Option C: Shared Parameterized Tags (Previous Research)

Define shared arithmetic protocols (`PolicyAddable`, `PolicySubtractable`) and use `Property` views.

| Criterion | Assessment |
|-----------|-----------|
| Duplication | Low (protocol impls per type) |
| Type safety | Full |
| Performance | Equivalent after inlining |
| Maintenance | More complex (Property pattern, shared tags) |
| rawValue confinement | Good |

### Option D: Macros / Code Generation

Use Swift macros or gyb to generate the duplicate operators.

| Criterion | Assessment |
|-----------|-----------|
| Duplication | Generated (hidden, not eliminated) |
| Type safety | Full |
| Performance | Optimal |
| Maintenance | Template maintenance |
| rawValue confinement | Generated code touches rawValue |

### Comparison

| Criterion | A (Duplication) | B (Protocol — Phased) | C (Shared Tags) | D (Macros) |
|-----------|----------------|----------------------|-----------------|------------|
| Simplicity | High | High | Medium | Medium |
| Zero duplication | No | **Phase 1: 17/31; Phase 2: 31/31** | Nearly | Generated |
| Same-tag safety | Manual | **Phase 1: manual; Phase 2: `where O.Domain == C.Domain`** | Manual | Manual |
| Swift-native | Yes | **Yes** | Yes | Requires tooling |
| Type preservation | Manual | **Automatic** | Manual | Manual |
| Maintenance cost | O(N*M) | **Phase 1: O(M) same-type + O(N*M') cross-type; Phase 2: O(M)** | O(N+M) | O(M + template) |
| Optimizer dependency | None | Inlining | Inlining | None |

### Critical Distinction: `some` vs Explicit Generics

For **type-preserving** operations (input type = output type), explicit generics are required:

```swift
// CORRECT: type-preserving
func up<C: Cardinal.`Protocol`>(_ value: C) -> C

// INCORRECT: function chooses return type, not caller
func up(_ value: some Cardinal.`Protocol`) -> some Cardinal.`Protocol`
```

`some P` in return position creates an *opaque type* chosen by the function body. Explicit generic `<C: P>(_ x: C) -> C` constrains the return type to match the input. This distinction is critical for compound assignment (`lhs = try lhs + rhs`) and for preserving phantom tags.

For **non-preserving** operations (different return type), `some` is acceptable:

```swift
// OK: return type is independently determined
func - (lhs: some Ordinal.`Protocol`, rhs: some Ordinal.`Protocol`)
    throws(Affine.Discrete.Vector.Error) -> Affine.Discrete.Vector
```

### The Init Label Question

The protocol `init` must avoid collision with the base type's `init(_ value: UInt)`:

| Approach | Example | Collision? |
|----------|---------|-----------|
| Labeled `init(cardinal:)` | `C(cardinal: Cardinal(0))` | No |
| Unlabeled `init(_:)` | `C(Cardinal(0))` | In minimal reproductions; resolved in real modules |

Empirical finding: unlabeled `init(_: Cardinal)` compiles correctly in the real codebase (separate modules), but causes witness resolution failure in single-file experiments. The labeled form is safer for isolated experiments; the unlabeled form is acceptable in production where module boundaries disambiguate.

### Static Members on Protocols

`.zero` and `.one` moved to `Cardinal.Protocol` extension must avoid recursion:

```swift
// INCORRECT: Self(.zero) resolves .zero as Self.zero → infinite recursion
extension Cardinal.`Protocol` {
    static var zero: Self { Self(.zero) }
}

// CORRECT: Cardinal(0) calls Cardinal.init(_: UInt), no recursion
extension Cardinal.`Protocol` {
    static var zero: Self { Self(Cardinal(0)) }
    static var one: Self { Self(Cardinal(1)) }
}
```

## Empirical Validation

### Experiment Evidence

The `cardinal-protocol-abstraction` experiment (2026-02-04) confirmed all five variants:

| Variant | Result |
|---------|--------|
| V1: Protocol definition compiles | CONFIRMED |
| V2: Tagged conditional conformance compiles | CONFIRMED |
| V3: Generic function accepts both types, correct arithmetic | CONFIRMED |
| V4: Zero-guard pattern works in generic context | CONFIRMED |
| V5: Return type statically preserved (compile-time proof) | CONFIRMED |

### Build Verification

After implementing in production:

| Package | Build | Tests |
|---------|-------|-------|
| swift-cardinal-primitives | Clean | 21/21 pass |
| swift-ordinal-primitives | Clean | 25/25 pass |
| swift-memory-primitives | Clean | 122/122 pass |
| swift-affine-primitives | Clean | (via memory-primitives build) |

### Cognitive Dimensions Analysis (per [RES-025])

| Dimension | Assessment |
|-----------|-----------|
| **Visibility** | The protocol makes the abstraction explicit. `some Cardinal.Protocol` in a signature immediately communicates "this works with any cardinal quantity." |
| **Consistency** | The same pattern applies to Cardinal, Ordinal, and (future) Vector. Three protocols, three conformance pairs (bare + Tagged), uniform operator signatures. |
| **Viscosity** | Adding a new base type requires: (1) define `T.Protocol`, (2) conform `T`, (3) conform `Tagged<_, T>`. Three declarations, all mechanical. Adding a new operation requires one generic function. |
| **Role-expressiveness** | `<C: Cardinal.Protocol>(_ value: C) -> C` clearly expresses: "I operate on any cardinal-like quantity and preserve its type." The previous `<Scalar: FixedWidthInteger>` gave no semantic signal. |
| **Error-proneness** | Type preservation is enforced by the compiler. Passing `Index<A>.Count` returns `Index<A>.Count`, not `Cardinal` or `Index<B>.Count`. The `Domain` constraint prevents cross-domain mixing: `Index<A>.Count + Index<B>.Offset` is a compile error. The previous generic `FixedWidthInteger` accepted signed integers, negative values, and cross-domain operands. |
| **Abstraction** | Single level of abstraction. The previous approach required understanding both the bare and Tagged operator sets and their structural correspondence. |

## Generalization Analysis

### Question

Can the per-type protocol pattern (`Cardinal.Protocol`, `Ordinal.Protocol`, `Affine.Discrete.Vector.Protocol`) be unified into a single generic protocol, eliminating the need for N separate protocol definitions?

### Relationship to Optic.Iso

Each `X.Protocol` conformance is a *representational isomorphism* — structurally identical to `Optic.Iso<Self, X>`:

```
  X.Protocol ≅ Optic.Iso<Self, X>
    .cardinal  ↔  .forward   (projection)
    init(_:)   ↔  .backward  (injection)
```

`Optic.Iso` (optic-primitives, Tier 0) has zero dependencies and already provides composition, reversal, identity, and conversion to weaker optics. The protocol abstraction encodes the same mathematical structure, but as a protocol (with compiler-dispatched witnesses) rather than a value (with closure-based dispatch).

### Approaches Tested

The `generalized-protocol-abstraction` experiment (2026-02-04, Swift 6.2.3) tested 11 variants. All compile and run; key results:

#### Option E: Generic Protocol with Associated Type (`Representable`)

```swift
protocol Representable {
    associatedtype Representation
    var representation: Representation { get }
    init(representation: Representation)
}
```

Tagged conformance via transitive delegation:

```swift
extension Tagged: Representable where RawValue: Representable {
    typealias Representation = RawValue.Representation
    var representation: RawValue.Representation { rawValue.representation }
    init(representation: RawValue.Representation) { self.init(__unchecked: (), RawValue(representation: representation)) }
}
```

**Result: CONFIRMED.** Works, but constraint syntax is verbose: `<R: Representable> where R.Representation == Cardinal`.

#### Option F: Primary Associated Type (`RepresentedBy<Base>`)

```swift
protocol RepresentedBy<Underlying> {
    associatedtype Underlying
    var underlying: Underlying { get }
    init(underlying: Underlying)
}
```

**Result: CONFIRMED.** Cleanest unification — constraint reads `<R: RepresentedBy<Cardinal>>`. Transitive Tagged conformance works. Operators, mixed cross-type operations, and static members all function correctly.

#### Option G: Optic.Iso as Value Witness (No Protocol)

Pass `Optic.Iso<T, Cardinal>` explicitly to each function.

**Result: CONFIRMED but rejected.** Shifts complexity to every call site. Every function requires an additional `iso` parameter; operators cannot use this pattern.

#### Option H: Nested `Tagged.Protocol<Value>`

```swift
extension Tagged {
    protocol `Protocol`<Value> { ... }
}
```

**Result: REFUTED.** Swift compiler error: *"protocol cannot be nested in a generic context."* `Tagged<Tag, RawValue>` is generic, and Swift prohibits nesting protocols inside generic types. This is a hard language constraint with no workaround.

#### Option I: Top-Level Unified Protocol (e.g., `Taggable<Value>`)

Since nesting inside `Tagged` is impossible, define the protocol at the top level or inside a non-generic namespace:

```swift
protocol Taggable<Value> {
    associatedtype Value
    var value: Value { get }
    init(_ value: Value)
}
```

With domain-specific accessors recovered via conditional extensions:

```swift
extension Taggable where Value == Cardinal {
    var cardinal: Cardinal { value }
    static var zero: Self { Self(Cardinal(0)) }
    static var one: Self { Self(Cardinal(1)) }
}
```

**Result: CONFIRMED.** Full unification: type-preserving generics, single Tagged conformance, domain-specific accessors via conditional extension, static members. Both `.value` (generic) and `.cardinal` (domain-specific) are available simultaneously.

#### Coexistence

A type can conform to both the per-type protocol (`Cardinal.Protocol`) and a unified protocol (`RepresentedBy<Cardinal>` or `Taggable<Cardinal>`) simultaneously. Migration can be incremental.

### Generalization Comparison

| Criterion | Per-Type `X.Protocol` | Unified Protocol (F/I) |
|-----------|----------------------|----------------------|
| Protocol definitions | N (one per type) | 1 |
| Tagged conformances | N (one per type) | 1 (transitive) |
| New type cost | Define protocol + 2 conformances | Add 1 conformance |
| Accessor name | `.cardinal` (built-in) | `.value` + `.cardinal` (conditional) |
| Constraint syntax | `Cardinal.Protocol` | `Taggable<Cardinal>` or `RepresentedBy<Cardinal>` |
| Semantic clarity | Protocol name IS the domain | Protocol name is generic |
| Package location | Each type's own package | identity-primitives (Tier 0) |
| `Tagged.Protocol` nesting | N/A | **Impossible** (Swift limitation) |

### Naming Considerations (Open)

The unified protocol name is unresolved. Candidates and their trade-offs:

| Name | Reads as | Issue |
|------|----------|-------|
| `Taggable<Value>` | "can be tagged as Value" | Misleading: Cardinal isn't "taggable," it IS the base type |
| `RepresentedBy<Value>` | "represented by Value" | Direction ambiguity: Tagged is represented BY Cardinal, but Cardinal is not represented by itself |
| `Representable<Value>` | "representable as Value" | Generic, doesn't convey the Tagged relationship |
| `Transparent<Value>` | "transparent wrapper over Value" | Rust precedent (`repr(transparent)`), but Cardinal isn't a "wrapper" |
| `Representation.Protocol<Value>` | Nest.Name pattern | Requires creating a `Representation` namespace enum |

The per-type pattern avoids this naming problem entirely: `Cardinal.Protocol` says exactly what it means.

### Generalization Decision

**The per-type protocol pattern is retained as the primary approach.** Rationale:

1. **Semantic precision.** `Cardinal.Protocol` is self-documenting. A unified name inevitably trades domain meaning for generality, and no candidate name is satisfactory.

2. **Low absolute cost.** Each protocol is ~15 lines (protocol + 2 conformances). Three types × 15 lines = 45 lines. This is acceptable for timeless infrastructure.

3. **Hard language constraint.** `Tagged.Protocol<Value>` — the most natural unified name — is impossible due to Swift's prohibition on nesting protocols in generic types. Any alternative name is a compromise.

4. **Conditional extensions recover ergonomics but add indirection.** The `.cardinal` accessor via conditional extension on a unified protocol works, but it's a computed property that delegates to `.value`, adding a layer of indirection in the API surface.

5. **Optic.Iso is the theoretical unifier, not the implementation.** The Iso relationship provides the mathematical grounding, but the protocol witness table provides better codegen than closure-based dispatch.

The unified protocol approach remains viable as a future option if the number of protocol-abstracted types grows significantly (>>3). The experiment confirms coexistence, so adoption would be non-breaking.

## Outcome

**Status: DECISION**

### The Protocol Abstraction Pattern (Phased)

For each base type `T` used as a `Tagged` `RawValue`, define:

#### Phase 1 (Now — Swift 6.2.3)

1. **`T.Protocol`** -- a protocol in `T`'s package with:
   - `var t: T { get }` -- projection to base type
   - `init(_ t: T)` -- injection from base type

2. **Self-conformance** -- `T : T.Protocol`

3. **Tagged conformance** -- `Tagged<Tag, T> : T.Protocol where RawValue == T, Tag: ~Copyable`

4. **Same-type operators** generic over `T.Protocol` -- using explicit generics for type-preserving operations, `some T.Protocol` for non-preserving ones. This unifies 17/31 operator pairs.

5. **Cross-type operators remain duplicated** (bare + tagged) -- 14 operators that require same-tag enforcement cannot be unified without Domain.

#### Phase 2 (Future — When Swift Supports `associatedtype: ~Copyable`)

6. **Add `associatedtype Domain: ~Copyable`** to each `T.Protocol`.

7. **Update conformances** -- `Domain = Never` for bare types, `Domain = Tag` for tagged types.

8. **Unify cross-type operators** with `where O.Domain == C.Domain` -- enforces same-tag safety for operations spanning two protocol types. This completes the remaining 14/31 operator pairs.

9. **Companion types** (where needed) -- associated types that map return types across the bare/tagged boundary (e.g., `Ordinal - Ordinal → O.CompanionVector` where the companion is `Vector` for bare and `Tagged<Tag, Vector>` for tagged).

### Canonical Placement

| Component | Package | File |
|-----------|---------|------|
| `Cardinal.Protocol` + conformances | cardinal-primitives Core | `Cardinal.Protocol.swift` |
| `Ordinal.Protocol` + conformances | ordinal-primitives Core | `Ordinal.Protocol.swift` |
| `Affine.Discrete.Vector.Protocol` + conformances | affine-primitives | `Affine.Discrete.Vector.Protocol.swift` |
| Cardinal static members (`.zero`, `.one`) | cardinal-primitives Core | `Cardinal.swift` (protocol extension) |
| Affine operators (generic) | affine-primitives | single file, not bare + tagged pair |
| Alignment operations | memory-primitives Core | `Memory.Alignment.Align.swift` |

### What This Supersedes

- `tagged-extension-duplication.md` -- the protocol abstraction approach is simpler and more effective than shared parameterized tags (Option B in that document) or macros (Option C).
- All bare/tagged operator pairs in `Affine.Discrete+Arithmetic.swift` and `Tagged+Affine.swift` that can be unified through protocol generics.

### Implementation Sequence

#### Phase 1 (Now)

1. Define `Affine.Discrete.Vector.Protocol` (not yet created)
2. Unify same-type operators: merge bare and tagged arithmetic into single generic definitions using `T.Protocol` generics (17 operators)
3. Keep cross-type operators duplicated (bare + tagged) for the 14 operators requiring same-tag enforcement
4. Audit remaining operator pairs across all primitives packages
5. Remove superseded same-type duplicate declarations

#### Phase 2 (When `associatedtype: ~Copyable` Lands)

6. Add `associatedtype Domain: ~Copyable` to existing `Cardinal.Protocol`, `Ordinal.Protocol`, and `Affine.Discrete.Vector.Protocol`
7. Update conformances: `Domain = Never` for bare types, `Domain = Tag` for tagged types
8. Unify cross-type operators: add `where O.Domain == C.Domain` to Ordinal ± Cardinal, Vector ↔ Cardinal comparisons, Ordinal ↔ Cardinal comparisons (14 operators)
9. Define companion types for return-type-varying operations (Ordinal - Ordinal → CompanionVector)
10. Remove superseded cross-type duplicate declarations

### Constraints and Limitations

- **`associatedtype: ~Copyable` not yet supported (Phase 2 blocker)**: Swift 6.2.3 does not allow suppressing `Copyable` on associated types. The compiler emits *"cannot suppress 'Copyable' requirement of an associated type"* for `associatedtype Domain: ~Copyable`. Since `Tagged<Tag: ~Copyable, RawValue>` accepts noncopyable tags, `typealias Domain = Tag` fails the implicit `Copyable` requirement. This was carved out of [SE-0427](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) during its second review as "a large, open design problem." An active pitch — [Suppressed Associated Types With Defaults](https://forums.swift.org/t/pitch-suppressed-associated-types-with-defaults/83663) (Kavon Farvardin, December 2025) — proposes the exact syntax needed, with a working implementation in nightly toolchains (December 4, 2025+). No formal proposal number or target Swift version has been assigned. The `noncopyable-associatedtype-domain` experiment confirmed the blocker empirically.
- **Optimizer dependency**: The round-trip through `.cardinal`/`init` relies on `@inlinable` and the optimizer. In debug builds without optimization, there is a minimal overhead (function call + struct construction). This is acceptable for primitives infrastructure.
- **No deep lifting**: The pattern lifts operations one level (Cardinal ↔ Tagged). It does not compose: `Tagged<Tag, Tagged<Tag2, Cardinal>>` would require a separate conformance. This is not needed in practice.
- **Module boundary sensitivity**: Unlabeled `init(_: Cardinal)` resolves correctly across module boundaries but may collide in single-file contexts. The experiment confirmed this.
- **No protocol nesting in generic types**: `Tagged.Protocol<Value>` is impossible in Swift. This is a hard language constraint that prevents the most natural unified protocol name. See §Generalization Analysis.
- **Unified protocol naming gap**: No satisfactory name exists for a single protocol that replaces all `X.Protocol` definitions. See §Naming Considerations for the evaluation of candidates.

## References

### Language Design

- Breitner, J., Eisenberg, R. A., Peyton Jones, S., & Weirich, S. "Safe Zero-cost Coercions for Haskell." *ICFP 2014* / *JFP* 26, 2016.
- Blondal, B., Loh, A., & Scott, R. "Deriving Via." *Haskell Symposium 2018*, pp. 55--67.
- GHC User's Guide: [Roles](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/roles.html), [GeneralizedNewtypeDeriving](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/newtype_deriving.html), [DerivingVia](https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/deriving_via.html).
- Rust RFC 1758: [repr(transparent)](https://rust-lang.github.io/rfcs/1758-repr-transparent.html).

### Swift Evolution (Noncopyable Generics)

- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md). Accepted with amendments; `associatedtype: ~Copyable` carved out as future direction.
- [SE-0499: Support Non-Copyable Simple Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md). Notes protocols with associated types remain blocked.
- Farvardin, K. "[Pitch: Suppressed Associated Types With Defaults](https://forums.swift.org/t/pitch-suppressed-associated-types-with-defaults/83663)." Swift Forums, December 2025. Active pitch with working implementation in nightly toolchains.

### Phantom Types

- Fluet, M. & Pucella, R. "Phantom Types and Subtyping." *JFP* 16(6), pp. 751--791, 2006.
- Cheney, J. & Hinze, R. "First-Class Phantom Types." *ICFP 2004*, pp. 236--243.
- Hinze, R. "Fun with Phantom Types." In *The Fun of Programming*, 2003.
- Leijen, D. & Meijer, E. "Domain Specific Embedded Compilers." *DSL'99*, pp. 109--122, 1999.

### Swift Ecosystem

- Point-Free. [swift-tagged](https://github.com/pointfreeco/swift-tagged). GitHub.
- Swift Forums. "[Coerce phantom types](https://forums.swift.org/t/coerce-phantom-types/17277)." October 2018.

### Optics

- `swift-optic-primitives/Sources/Optic Primitives/Optic.Iso.swift` -- the Iso type that each `X.Protocol` conformance structurally mirrors

### Internal

- `swift-institute/Research/tagged-extension-duplication.md` (superseded)
- `swift-cardinal-primitives/Experiments/cardinal-protocol-abstraction/` (per-type protocol verification)
- `swift-cardinal-primitives/Experiments/generalized-protocol-abstraction/` (generalization experiment: 11 variants including unified protocol, Optic.Iso, Tagged.Protocol nesting)
- `swift-cardinal-primitives/Experiments/tag-preserving-protocol-abstraction/` (Domain mechanism, same-tag enforcement, companion types, cross-domain rejection)
- `swift-institute/Experiments/noncopyable-associatedtype-domain/` (~Copyable associated type limitation: direct approach REFUTED, Witness workaround CONFIRMED but rejected as non-timeless)
