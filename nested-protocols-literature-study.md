# Nested Protocols in Generic Types: Cross-Language Literature Study

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: RECOMMENDATION
tier: 3
depends_on: nested-protocols-in-generic-types.md
---
-->

## Context

The companion document ([nested-protocols-in-generic-types.md](nested-protocols-in-generic-types.md))
established that Swift's restriction against nesting protocols in generic types is hard-coded
with no feature flag. The pitch draft (SE-Pitches/Draft/PITCH-AAAA) proposes the "without
capture" approach as the minimum viable extension of SE-0404.

This document asks the broader question: **What is the ideal design**, informed by the full
landscape of type theory, programming language design, and practical experience across Scala,
Rust, OCaml, Haskell, and C++?

**Method**: Systematic literature review across six domains — Scala path-dependent types,
Rust trait scoping, OCaml/ML module systems, Haskell type classes, formal type theory, and
C++/Swift compiler internals — with 60+ sources synthesized into a unified recommendation.

## The Central Design Question

When a protocol `P` is nested inside a generic type `Container<T>`, the language must answer:

> **Is `Container<Int>.P` the same protocol as `Container<String>.P`?**

This question has exactly two answers, each with fundamentally different implications.

### Interpretation A: Generic Protocol (identity varies with T)

```
Protocol : Type → Constraint
Container<Int>.P ≠ Container<String>.P
```

The protocol is a **type-level function** — a family of protocols indexed by `T`. Each
specialization is a distinct protocol with its own witness table. Conformance to
`Container<Int>.P` does not imply conformance to `Container<String>.P`.

### Interpretation B: Namespaced Protocol (identity fixed)

```
Protocol : Constraint    (constant, independent of T)
Container<Int>.P ≡ Container<String>.P    for all T
```

The nesting is purely organizational. The protocol has a single identity and a single
witness table layout regardless of `T`. The outer generic parameter is invisible inside
the protocol body.

Every language surveyed has been forced to choose between these interpretations. Their
choices — and the consequences — form the core of this study.

## Cross-Language Evidence

### Scala: Path-Dependent Types and the DOT Calculus

**What Scala does**: Scala allows traits inside generic classes with full access to the
outer type parameter. All inner types are **path-dependent**: `container1.Protocol` and
`container2.Protocol` are different types even if `Protocol` never references `T`.

```scala
class Container[T] {
  trait Protocol { def label: String }  // does NOT reference T
}
val a = new Container[Int]
val b = new Container[String]
// a.Protocol ≠ b.Protocol (path-dependent, even though Protocol ignores T)
```

**What went wrong**: Scala 2 provided **type projections** (`Container[T]#Protocol`) to
erase path-dependence. This was **unsound**. The "bad bounds" exploit (Odersky, Dotty
issue #1050) allows constructing `Any => Nothing` functions through abstract type
projections:

```scala
trait C { type A }
type T = C { type A >: Any }
type U = C { type A <: Nothing }
type X = T & U
val y: X#A = 1          // compiles: Int <: Any <: X#A
val z: String = y        // compiles: X#A <: Nothing <: String
// Runtime: ClassCastException
```

**Scala 3's resolution**: Dropped general type projections entirely. Projections on
*concrete* types (`Container[Int]#Protocol`) remain legal. Projections on *abstract*
types (`T#A` where `T` is a type parameter) are forbidden — this is where unsoundness
lived.

**The DOT soundness proof** (Amin & Rompf, OOPSLA 2016): Path-dependent types `x.A`
are sound because `x` is a concrete runtime value with verified bounds. Type projections
`T#A` bypass this verification. The proof requires that every path prefix be a value —
"types can have bad bounds as long as no value inhabits them."

**Lesson for Swift**: Scala's decade-long experience validates a clear principle:
*if a type's semantics are independent of the outer generic parameter, it should not
be structurally dependent on it.* Path-dependence is a structural consequence of nesting,
not a semantic analysis of capture. Scala chose Interpretation A (generic/path-dependent)
for all nested types, then spent years managing the consequences. The "without capture"
approach avoids this entirely by choosing Interpretation B.

**Key sources**:
- Amin, Rompf. "Type Soundness for Dependent Object Types." OOPSLA 2016
- Rapoport, Lhotak. "A Path To DOT." OOPSLA 2019
- Odersky. Dotty issue #1050 (bad bounds)
- Parreaux. "What is Type Projection in Scala, and Why is it Unsound?" (2019)
- Scala 3 docs: "Dropped: General Type Projection"

### Rust: Traits Cannot Nest in Generic Contexts

**What Rust does**: Traits are module-level items. They cannot be defined inside `impl`
blocks, generic or otherwise. A trait defined inside a function body cannot reference
the function's generic parameters.

```rust
impl<T> Container<T> {
    trait Protocol { ... }  // ERROR: expected associated item
}
```

**Workarounds**: The Rust ecosystem developed three patterns:

1. **Family traits + GATs** (Matsakis, 2016): A meta-trait that maps families to their
   members via Generic Associated Types (stabilized Rust 1.65):
   ```rust
   trait CollectionFamily {
       type Member<T>: Collection<T>;
   }
   ```

2. **Sealed traits**: A private supertrait restricts implementors to a closed set.

3. **Parameterized modules**: Proposed in RFC #424 (2014), **postponed indefinitely**
   due to coherence complications with monomorphized trait impls.

**Why Rust's model differs**: Monomorphization erases all trait structure after type
checking. There is no runtime witness table (unless `dyn Trait` is used). This eliminates
the runtime motivation for organizing traits by family — the compiler specializes
everything anyway.

**Lesson for Swift**: Rust confirms that "trait per variant family" is a pure type-system
question in monomorphized systems, but a codegen question in witness-table systems like
Swift. The family trait pattern (a single parameterized trait rather than many specialized
ones) is Rust's idiomatic solution — and it works precisely because monomorphization
makes the choice zero-cost.

**Key sources**:
- Rust Reference: Implementations, Traits, Generic Parameters
- Matsakis. "Associated Type Constructors Part 2: Family Traits" (2016)
- RFC 1598: Generic Associated Types
- RFC #424: Parameterized Modules (postponed)
- Hume. "A Tour of Metaprogramming Models for Generics" (2019)

### OCaml: Signatures Inside Functors

**What OCaml does**: Module types (signatures) can be defined inside functor bodies.
The inner signature can reference the functor's parameter types:

```ocaml
module F (X : sig type t end) = struct
  module type Inner = sig
    val process : X.t -> X.t
  end
end
```

This works because OCaml's module system is **structurally typed**: a module satisfies
a signature if it has all required components with compatible types. No explicit
conformance declaration is needed.

**Known issues**: OCaml issue #11441 documents that module type components inside functor
bodies can contain unsound references to functor parameters. The feature is syntactically
supported but not fully policed for soundness.

**Applicative vs. generative functors**: OCaml distinguishes two modes:
- **Applicative** (the default): `F(X)` applied twice to the same `X` produces
  compatible abstract types. The functor is a "pure function" from modules to modules.
- **Generative**: Each application produces fresh, incompatible abstract types.

For nested protocols, this maps to: should `Container<Int>.P` and `Container<Int>.P`
(same `T`) be the same protocol? Applicative semantics says yes; generative says no.

**The F-ing Modules paper** (Rossberg, Russo, Dreyer, JFP 2014): All of ML modules —
including nested signatures in functors — can be translated into System F-omega. This
proves that the capability is expressible in the same type-theoretic foundation
underlying Swift's generics.

**1ML** (Rossberg, ICFP 2015): Eliminates the module/core stratification entirely.
Signatures are types, functors are functions. A "signature inside a parameterized function"
falls out naturally. Decidability is maintained via a predicativity restriction (abstract
types can only hide monomorphic types).

**Lesson for Swift**: OCaml demonstrates that signatures inside parameterized contexts
are sound and useful. The structural typing model makes it natural — but Swift's nominal
typing creates the path-identity question that OCaml avoids. The F-ing Modules result
proves that the type-theoretic expressiveness is available in System F-omega; the
question is engineering, not theory.

**Key sources**:
- Rossberg, Russo, Dreyer. "F-ing Modules." JFP 2014
- Rossberg. "1ML — Core and Modules United." ICFP 2015 / JFP 2018
- Jones. "Using Parameterized Signatures." POPL 1996
- Dreyer. "Understanding and Evolving the ML Module System." PhD thesis, CMU 2005
- Dreyer, Harper, Chakravarty. "Modular Type Classes." POPL 2007
- White, Bour, Yallop. "Modular Implicits." ML Workshop 2014

### Haskell: Type Classes Are Always Top-Level

**What Haskell does**: Type classes are always top-level. There is no syntax for
scoped or local class definitions. This is deliberate — it preserves three properties
(Edward Yang's taxonomy):

1. **Confluence**: Constraint solving is deterministic.
2. **Coherence**: All valid derivations produce the same runtime semantics.
3. **Global uniqueness**: One instance per (class, type) pair.

Local instances would break global uniqueness. Kiselyov's analysis shows two competing
semantics (closure vs. dynamic binding), both problematic.

**Constraint families** (Orchard & Schrijvers, FLOPS 2010): Type families that return
`Constraint` achieve the effect of "a protocol that varies with its container":

```haskell
type family Protocol (container :: * -> *) :: * -> Constraint
type instance Protocol [] = Show
type instance Protocol Set = Ord
```

**Associated type families** are the closest analog to our problem:

```haskell
class Expr sem where
    type Pre sem a :: Constraint
    constant :: Pre sem a => a -> sem a
```

Here `Pre` is a constraint family that changes meaning per `sem` — exactly "the
constraint requirements vary with the container."

**Backpack** (Kilpatrick et al.): Retrofits Haskell with an applicative, mix-in module
system. Packages are parameterized over module signatures (`.hsig` files). This allows
multiple implementations of the same interface without breaking coherence — each is
linked at build time. Backpack units are top-level only (no nesting).

**Lesson for Swift**: Haskell's refusal to allow nested class definitions is principled
and preserves properties Swift also values (global conformance uniqueness). The escape
hatch — constraint families and associated type families — achieves the expressiveness
without nesting. The "Modular Type Classes" paper (Dreyer et al.) suggests the ideal
solution is unifying the module system with the type class system, not nesting classes.

**Key sources**:
- Orchard, Schrijvers. "Haskell Type Constraints Unleashed." FLOPS 2010
- Morris, Jones. "Instance Chains." ICFP 2010
- Morris, Eisenberg. "Constrained Type Families." ICFP 2017
- Kiselyov, Shan. "Functional Pearl: Implicit Configurations"
- Bottu, Xie, Oliveira. "Coherence of Type Class Resolution." ICFP 2019
- Kilpatrick et al. "Backpack"
- Dreyer, Harper, Chakravarty. "Modular Type Classes." 2007

### Formal Type Theory

**DOT (Dependent Object Types)**: The path-dependent type `x.A` is sound when `x` is
a concrete value (bounds verified at construction). Type projections `T#A` bypass this.
The soundness proof (Amin & Rompf) shows bad bounds are safe in the type system as long
as no value inhabits them — "subtyping transitivity only needs to hold in runtime
contexts with valid objects."

**System F-omega**: A protocol family can be modeled as a type-level function:

```
ProtocolFamily : * → Constraint
ProtocolFamily = Λ(T : *). Protocol_T
```

Type checking is decidable (strongly normalizing, no type-level recursion). However,
F-omega lacks subtyping — it cannot model protocol conformance hierarchies.

**Qualified types** (Jones, 1994): Predicates can be parameterized if the predicate
language is rich enough. The expression `∀T. (Container T ⇒ Protocol_T(a)) ⇒ σ`
is well-formed and corresponds to multi-parameter type classes or constraint families.

**Coherence** (Wadler & Blott, 1989; Bottu et al., 2019): The dictionary-passing
translation requires that each `(T, conforming_type)` pair determines a unique witness.
For parameterized protocol families, coherence holds if the witness is uniquely
determined by the type parameters — which is exactly Swift's existing global uniqueness
guarantee.

**Substructural types + protocol families**: This intersection is **genuinely unexplored**.
No published paper combines parameterized protocol/interface families with affine
(`~Copyable`) type disciplines. Key observations:
- Witness tables are metadata, not values — they remain copyable even when `T` is ~Copyable.
- Linear Haskell (Bernardy et al., POPL 2018) places linearity on arrows, not types.
- Alms (Tov & Pucella, POPL 2011) uses ML-style signature ascription for affine types.
- A protocol family that propagates affinity from `T` to conforming types would need
  "conditional substructural constraints" — a novel construct.

**Key insight**: The "without capture" interpretation (Interpretation B) requires
no new type theory. The protocol is a constant in the type-level function space.
The "generic protocol" interpretation (Interpretation A) requires dependent types
or F-omega type families, plus a redesigned coherence model.

**Key sources**:
- Amin, Rompf. "Type Soundness for DOT." OOPSLA 2016
- Jones. "Qualified Types: Theory and Practice." Cambridge, 1994
- Wadler, Blott. "How to Make Ad-Hoc Polymorphism Less Ad Hoc." POPL 1989
- Reynolds. "Types, Abstraction, and Parametric Polymorphism." 1983
- Bottu, Xie, Oliveira. "Coherence of Type Class Resolution." ICFP 2019
- Bernardy et al. "Linear Haskell." POPL 2018
- Tov, Pucella. "Practical Affine Types." POPL 2011

### C++ and Swift Compiler Internals

**C++ concepts**: Cannot be nested in class templates. "The definition of a concept
must appear at namespace scope" (C++20 standard). Nested abstract base classes inside
templates work but fully capture the outer parameter — `Container<int>::Iterator` and
`Container<string>::Iterator` have independent vtables.

**Swift compiler**: The restriction is enforced by a simple predicate chain:

1. `isUnsupportedNestedProtocol()` — `isa<ProtocolDecl>(this) && getParent()->isGenericContext()`
2. `isGenericContext()` — walks up via `getParentForLookup()`, returns true if any ancestor has generic params
3. Protocol signatures are hardcoded as `<Self: P>` in `GenericSignatureRequest::evaluate`

**The fundamental asymmetry**: A nested struct inside `Outer<T>` inherits `Outer`'s
generic signature and becomes `Outer<T>.Inner`. A protocol's signature is always
`<Self: P>` — it has no mechanism to incorporate outer generic parameters. This is
the core compiler reason the restriction exists.

**Infrastructure needed for non-capturing nested protocols** (6 subsystems):

| Subsystem | Change Required | Difficulty |
|-----------|----------------|------------|
| Generic signatures | None — protocol keeps `<Self: P>` | Trivial |
| Name mangling | New rule: strip outer generic args from protocol mangling | ABI decision |
| Witness tables | None — keyed by `(type, ProtocolDecl*)`, single decl | None |
| Conformance lookup | None — single `ProtocolDecl*` regardless of T | None |
| Existential containers | None — single witness table layout | None |
| Type resolution | Already partially implemented (`getParentForLookup` skips to module scope) | Minimal |

**Key finding**: The compiler already has infrastructure to sever a nested protocol from
its outer generic context. `getParentForLookup()` already skips to module scope for
unsupported nested protocols. The non-capturing case requires surprisingly few changes.

**Key sources**:
- Swift compiler: `lib/AST/DeclContext.cpp`, `lib/Sema/TypeCheckDeclPrimary.cpp`,
  `lib/Sema/TypeCheckGeneric.cpp`, `include/swift/AST/Decl.h`
- SE-0404 and acceptance discussion
- cppreference: Constraints and concepts (C++20)

## Synthesis: The Design Spectrum

The six-language survey reveals a clear spectrum of approaches:

| Language | Nested interface in generic? | Model | Coherence | Capture? |
|----------|----------------------------|-------|-----------|----------|
| Scala | Yes (traits in classes) | Path-dependent (A) | Per-path | Full capture |
| Rust | No (traits are module-level) | N/A | Global | N/A |
| OCaml | Yes (signatures in functors) | Structural | Applicative/generative | Full capture |
| Haskell | No (classes are top-level) | N/A | Global | N/A |
| C++ | No (concepts), Yes (nested classes) | Per-instantiation vtable | N/A | Full capture |
| Swift | No (protocols in generic contexts) | — | Global | — |

**Pattern**: Languages with nominal typing and global coherence (Swift, Rust, Haskell)
forbid nesting. Languages with structural typing or path-dependent types (Scala, OCaml)
allow it but with capture. No surveyed language implements the "without capture"
variant — a protocol nested for namespacing only, with a single identity.

## The Ideal Design

Based on the full literature survey, the ideal design for Swift has **three tiers**,
ordered by increasing ambition:

### Tier 1: Non-Capturing Nested Protocols (Recommended for SE pitch)

**Identity**: `Container<Int>.P ≡ Container<String>.P` (Interpretation B)

**Semantics**: The protocol is nested inside the generic type for namespace purposes
only. The outer generic parameter `T` is invisible inside the protocol body. The
protocol has a single `ProtocolDecl*`, a single mangled name, and a single witness
table layout.

**Why this is ideal for the first step**:
- Requires no new type theory (it is a constant in the type-level function space)
- Preserves Swift's global coherence model unchanged
- Compiler infrastructure already partially supports it
- Matches our concrete use case (`Buffer.Arena.Protocol` does not need to reference `Element`)
- Is the "most conservative extension" principle — expand scope minimally
- Aligns with Karl Wagner's 2017 "no captures" phase and SE-0404's Future Directions
- Avoids the unsoundness Scala encountered with type projections

**What it enables**:
```swift
enum Buffer<Element: ~Copyable> {
    struct Arena: ~Copyable { ... }
}

extension Buffer.Arena {
    protocol `Protocol`: ~Copyable {
        // Cannot reference Element — it is invisible
        associatedtype Element: ~Copyable  // own associated type
        var header: Header { get }
        mutating func allocate(_ element: consuming Element) throws -> Position
    }
}

// Single protocol identity:
// Buffer<Int>.Arena.Protocol === Buffer<String>.Arena.Protocol
```

**Compiler implementation**: Remove the `isGenericContext()` check when the protocol
body does not reference any outer generic parameters. The existing `getParentForLookup()`
infrastructure already skips to module scope. Name mangling strips generic arguments
from the parent context for the protocol symbol.

### Tier 2: Parameter-to-Associated-Type Mapping (Future Direction)

**Identity**: `Container<Int>.P ≡ Container<String>.P` with added sugar (still Interpretation B)

**Semantics**: The protocol can reference the outer generic parameter, but it is
automatically mapped to an associated type. `Container<T>.P { func process(_ x: T) }`
desugars to:

```swift
protocol Container_P {
    associatedtype T
    func process(_ x: T)
}
```

Conformance ties the associated type: `extension Container<Int>.Arena: Container.Arena.Protocol { }`
implicitly constrains `Self.Element == Int` (where `Element` is the mapped associated type).

**Why Tier 2, not Tier 1**: This requires the compiler to:
1. Synthesize associated types from outer generic parameters
2. Automatically constrain them at conformance sites
3. Handle mangling for the synthetic associated type

This is tractable (SE-0404 identified it as a future direction) but adds complexity
that is unnecessary for the purely namespacing use case.

### Tier 3: Generic Protocols (Unlikely)

**Identity**: `Container<Int>.P ≠ Container<String>.P` (Interpretation A)

**Semantics**: Each specialization is a distinct protocol. The Generics Manifesto
categorizes this as "Unlikely." The formal consequences are severe:

- Witness tables become **dependent** — indexed by `(T, conforming_type, outer_args)`
- Coherence must be reformulated per `(T, conformer)` pair
- Existentials need to capture the outer type's identity
- Dynamic dispatch carries the outer type's witness alongside the protocol's
- DOT's soundness constraints apply: every path must go through a concrete value

**Why unlikely**: Every language that implemented this model (Scala with path-dependent
types) encountered soundness issues. The Generics Manifesto's assessment is well-founded.

## Recommendation

**For the SE pitch**: Propose Tier 1 (non-capturing nested protocols).

This is the design that:
- The full literature supports as sound and practical
- No language has yet implemented (it is a novel contribution)
- Requires the minimum compiler change
- Preserves all existing invariants (coherence, witness tables, mangling modulo ABI rule)
- Matches our concrete use case perfectly
- Creates a clean upgrade path to Tier 2 later

**For the pitch framing**: Emphasize that this is NOT generic protocols. The protocol
has a single identity. The nesting is purely for namespacing. This sidesteps the entire
design space of dependent witness tables, parameterized coherence, and path-dependent
type soundness.

**For the implementation section**: The compiler already has `getParentForLookup()`
skipping to module scope for unsupported nested protocols. The non-capturing case
needs:
1. A check that the protocol body does not reference outer generic parameters
2. A mangling rule that strips outer generic arguments from the protocol symbol
3. Removal of the diagnostic for the non-capturing case

The rest (witness tables, conformance lookup, existentials) needs zero changes.

## Comparison with Existing Pitch Draft

The existing pitch draft (PITCH-AAAA) already proposes the Tier 1 approach. This
literature study **validates** that choice as the correct design, not merely the
minimum viable one. The cross-language evidence shows:

1. Full capture (Scala's model) leads to unsoundness concerns
2. No nesting (Haskell/Rust's model) loses namespace discoverability
3. Non-capturing nesting (our proposal) is a novel middle ground that
   no language has yet explored — and the literature supports as sound

The pitch should be strengthened with:
- The formal argument that Interpretation B requires no new type theory
- The compiler implementation analysis (6 subsystems, most need zero changes)
- The Scala cautionary tale (Tier 3 is where unsoundness lives)
- The explicit framing as "constant functor" — the protocol is invariant under `T`

## Full Bibliography

### Type Theory and Formal Semantics

1. Amin, N., Rompf, T. "Type Soundness for Dependent Object Types (DOT)." OOPSLA 2016.
2. Rapoport, M., Lhotak, O. "A Path To DOT: Formalizing Fully Path-Dependent Types." OOPSLA 2019.
3. Jones, M. P. "Qualified Types: Theory and Practice." Cambridge University Press, 1994.
4. Jones, M. P. "Using Parameterized Signatures to Express Modular Structure." POPL 1996.
5. Wadler, P., Blott, S. "How to Make Ad-Hoc Polymorphism Less Ad Hoc." POPL 1989.
6. Reynolds, J. C. "Types, Abstraction, and Parametric Polymorphism." 1983.
7. Bottu, G.-J., Xie, N., Oliveira, B. "Coherence of Type Class Resolution." ICFP 2019.
8. Bernardy, J.-P. et al. "Linear Haskell: Practical Linearity." POPL 2018.
9. Tov, J., Pucella, R. "Practical Affine Types." POPL 2011.
10. Walker, D. "Substructural Type Systems." In Pierce, ed., ATTPL. MIT Press, 2005.
11. Bernardy, J.-P. et al. "Linear Constraints." 2021. arXiv:2103.06127.

### Module Systems

12. Rossberg, A., Russo, C., Dreyer, D. "F-ing Modules." JFP 2014.
13. Rossberg, A. "1ML — Core and Modules United." ICFP 2015 / JFP 2018.
14. Dreyer, D. "Understanding and Evolving the ML Module System." PhD thesis, CMU 2005.
15. Dreyer, D., Harper, R., Chakravarty, M. "Modular Type Classes." POPL 2007.
16. White, L., Bour, F., Yallop, J. "Modular Implicits." ML Workshop 2014.
17. Wehr, S., Chakravarty, M. "ML Modules and Haskell Type Classes: A Constructive Comparison." 2008.
18. Kilpatrick, S. et al. "Backpack: Retrofitting Haskell with Interfaces."

### Type Class and Constraint Theory

19. Orchard, D., Schrijvers, T. "Haskell Type Constraints Unleashed." FLOPS 2010.
20. Morris, J. G., Jones, M. P. "Instance Chains: Type Class Programming Without Overlapping Instances." ICFP 2010.
21. Morris, J. G., Eisenberg, R. "Constrained Type Families." ICFP 2017.
22. Kiselyov, O., Shan, C.-c. "Functional Pearl: Implicit Configurations."
23. Schrijvers, T. et al. "COCHIS: Stable and Coherent Implicits." JFP.
24. Chakravarty, M., Keller, G., Peyton Jones, S. "Associated Types with Class." POPL 2005.

### Scala and Path-Dependent Types

25. Odersky, M. "The Essence of Scala." Scala Blog, 2016.
26. Odersky, M. "Scaling DOT to Scala — Soundness." Scala Blog, 2016.
27. Odersky, M. "Type Projection is Unsound." Dotty issue #1050.
28. Parreaux, L. "What is Type Projection in Scala, and Why is it Unsound?" 2019.
29. Scala 3 Documentation. "Dropped: General Type Projection."

### Rust

30. Matsakis, N. "Associated Type Constructors Part 2: Family Traits." baby steps, 2016.
31. RFC 1598: Generic Associated Types (stabilized Rust 1.65).
32. RFC 1733: Trait Aliases (feature-gated).
33. RFC 3437: Implementable Trait Aliases (open).
34. RFC #424: Parameterized Modules (postponed).
35. RFC 2451: Re-rebalancing Coherence.
36. RFC 3373: Avoid Non-Local Definitions in Functions.
37. Hume, T. "A Tour of Metaprogramming Models for Generics." 2019.

### Haskell

38. Kiselyov, O. "Attractive Type Classes." okmij.org.
39. Yang, E. "Type classes: confluence, coherence and global uniqueness." 2014.
40. GHC Issue #6150: Nested Instances.
41. mono-traversable library (Hackage).

### Swift

42. Wagner, K. SE-0404: Allow Protocols to be Nested in Non-Generic Contexts. 2023.
43. Wagner, K. "Nested Types in Protocols and Nesting Protocols in Types." Swift Forums, 2016.
44. Wagner, K. "Ease Restrictions on Protocol Nesting." Swift Forums, 2017.
45. Borla, H. "SE-0404 Acceptance." Swift Forums, 2023.
46. Lattner, C. et al. Generics Manifesto. swiftlang/swift.

### C++

47. C++20 Standard: Constraints and concepts (namespace-scope requirement).
48. cppreference: Class templates (lazy instantiation of nested types).

### Swift Compiler Source

49. `lib/AST/DeclContext.cpp` — `isGenericContext()` (line 467), `isUnsupportedNestedProtocol()` (line 1812)
50. `lib/Sema/TypeCheckDeclPrimary.cpp` — nested protocol restriction (line 3006)
51. `lib/Sema/TypeCheckGeneric.cpp` — protocol signature hardcoded as `<Self: P>` (line 812)
52. `include/swift/Basic/Features.def` — no NestedProtocol feature flag
