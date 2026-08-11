# Action Type Naming: Literature Survey

<!--
---
version: 1.1.0
last_updated: 2026-05-31
status: RECOMMENDATION
statusDetail: "Frontmatter reconciled to the Outcome's self-declared RECOMMENDATION (Keep `Action`). Triaged 2026-05-31 per [META-002]; was IN_PROGRESS."
tier: 2
---
-->

## Context

The `@Witness` macro generates companion types when applied to structs and enums:

- **Struct → Enum**: A struct with closure properties (product of functions) generates an `Action` enum with one case per closure. This enum is used for observation, middleware, and type-safe case matching.
- **Enum → Prism infrastructure**: An enum with cases generates computed extraction properties, a `Case` discriminant enum, and a `Prisms` struct.

The question arose whether `Action` is the right name for the struct-generated enum, and whether both directions should use a unified name like `Dual`.

## Question

What does the literature call the transformation between a product of functions (struct with closures) and a sum type (enum of cases)? Should we rename `Action` to `Dual` for both directions?

## Analysis

### Prior Art Survey

#### Defunctionalization / Refunctionalization (Reynolds 1972, Danvy & Nielsen 2001)

The most directly relevant transformation pair in the literature:

- **Defunctionalization** (Reynolds 1972): Replacing higher-order functions with first-order data — an enum of all possible function values plus a single `apply` function. This is exactly what the struct→Action transformation does: closures become enum cases.
- **Refunctionalization** (Danvy & Nielsen 2001): The inverse — converting first-order data representations back to higher-order functions.

The literature treats these as a **left inverse** relationship, not a full duality. Refunctionalization only works on programs that are in the image of defunctionalization.

Rendel, Trieflinger & Ostermann (ICFP 2015) generalized this as **matrix transposition**: programs can be viewed as matrices where rows are constructors and columns are observations, and the two transformations correspond to transposing this matrix.

#### Church / Böhm-Berarducci Encoding

In lambda calculus and type theory:

- **Church encoding** (Church 1941): A sum type encoded as its eliminator — a polymorphic function accepting one handler per case. The eliminator is a product of functions.
- **Böhm-Berarducci encoding** (1985): The typed variant in System F.
- **Scott encoding** (Mogensen 1988): Case analysis without recursion — each constructor selects one handler from a product of handlers.

The relationship is an **isomorphism**: `(ΣᵢFᵢ) → X ≅ Πᵢ(Fᵢ → X)`. The literature says "Church-encode" and "decode" — no standalone name for the bidirectional relationship.

#### Data / Codata Duality (Abel & Pientka, POPL 2013)

Type theory formalizes the duality as:

- **Data types**: Defined by constructors, consumed by pattern matching.
- **Codata types**: Defined by destructors/observations, produced by copattern matching.

A struct with closure fields is a **codata type** (defined by its observations). The Action enum is the corresponding **data type** (defined by its constructors). The term **copattern** is the dual of pattern.

#### Visitor Pattern (OOP Literature)

The Visitor pattern is the OOP manifestation of Church encoding:

- Palsberg & Jay (1998): "The Essence of the Visitor Pattern"
- Gonzalez (2021): "The Visitor pattern is essentially the same thing as Church encoding"
- Seemann (2018): Demonstrated step-by-step isomorphic refactoring between sum types and Visitor interfaces

No separate name beyond "applying the Visitor pattern."

#### Category Theory: Product / Coproduct

Products and coproducts are **dual** in the categorical sense — defined by universal properties in opposite categories. The standard naming convention uses the **"co-" prefix**: product/coproduct, monad/comonad, limit/colimit, pattern/copattern.

#### Expression Problem (Wadler 1998, Reynolds 1975, Cook 1990)

The pragmatic consequence of the duality: functional languages favor case analysis (new functions over fixed cases), OOP languages favor representation extension (new cases with fixed methods). Reynolds (1975) called these "User-Defined Types" vs. "Procedural Data Structures."

#### Swift Ecosystem

- **TCA/Redux**: `Action` is the standard name for the enum of all possible state events.
- **Point-Free Protocol Witnesses** (Episodes 33-36, 2019): No specific term for the generated enum. Uses "witness" for the struct.
- **objc.io** (2019): Used Reynolds' term "defunctionalization" directly.

### The Term "Dual" in Programming

**Haskell's `Data.Monoid.Dual`**: A newtype wrapper that reverses monoid arguments: `Dual x <> Dual y = Dual (y <> x)`. This implements the **opposite monoid**, not the sum/product transformation.

**`Data.Functor.Contravariant.Op`**: The opposite function arrow. Again, "opposite/reversed," not sum↔product.

**No mainstream library** (Swift, Kotlin, Scala, Haskell, Rust) uses `Dual` as a type name for the sum-to-product-of-handlers transformation. In existing codebases, `Dual` uniformly means "the opposite/reversed structure."

### Asymmetry in Current Implementation

A critical observation: **the current enum expansion is NOT a true dual**. When `@Witness` is applied to:

- A **struct**: Generates an `Action` **enum** (true product→coproduct transformation)
- An **enum**: Generates **prism infrastructure** (extraction properties, `Prisms` struct, `Case` discriminant) — NOT a dual struct with one closure per case

A true enum dual would be its **Scott encoding**: a struct with one closure per case (the eliminator). For example:

```swift
// Source enum
enum Route: Sendable {
    case home
    case profile(id: Int)
    case settings
}

// True dual (Scott encoding / eliminator) — NOT what we generate
struct Route.Dual<R> {
    var home: () -> R
    var profile: (Int) -> R
    var settings: () -> R
}
```

The current enum expansion generates prism *access* infrastructure, not the categorical dual. Using `Dual` would therefore be inaccurate for the enum direction.

### Option Comparison

| Name | Struct→Enum | Enum→Struct | Literature basis | Swift familiarity | Accuracy |
|------|-------------|-------------|------------------|-------------------|----------|
| `Action` | Clear intent | N/A | TCA/Redux | High | Good for struct direction |
| `Dual` | Mathematically motivated | Misleading (not a true dual) | Category theory | Low (means "reversed") | Inaccurate for enum direction |
| `Cases` | Reads as "case decomposition" | N/A | General | Medium | Descriptive |
| `Defunctionalized` | Precise | Too long | Reynolds 1972 | Very low | Precise but impractical |
| `Codata` / `Data` | Type-theoretically precise | Abel & Pientka 2013 | Very low | Precise but obscure |

### Evaluation Criteria

1. **Accuracy**: Does the name correctly describe the generated type?
2. **Familiarity**: Will Swift developers understand it without explanation?
3. **Uniformity**: Does it work for both struct→enum and enum→struct?
4. **Discoverability**: Does the name help developers find and use it?
5. **Precedent risk**: Does it commit to a semantic contract we might regret?

### Detailed Evaluation

#### Option A: Keep `Action` (current)

- **Accuracy**: Good. The enum cases represent the actions/operations a witness can perform.
- **Familiarity**: High. TCA developers immediately understand. General Swift developers can infer meaning.
- **Uniformity**: Does NOT generalize to enum→struct direction. But the current enum expansion doesn't generate a dual type anyway.
- **Discoverability**: `APIClient.Action.fetch` reads naturally.
- **Precedent risk**: Low. If we later add true enum duals, we can choose a name then.

#### Option B: Rename to `Dual`

- **Accuracy**: Mathematically motivated for struct→enum, but inaccurate for enum direction (we don't generate the categorical dual of an enum).
- **Familiarity**: Low. In programming, `Dual` means "reversed/opposite" (monoid, arrow), not "the other kind of type." `APIClient.Dual` is opaque.
- **Uniformity**: Appears uniform, but masks a fundamental asymmetry.
- **Discoverability**: Poor. A developer seeing `APIClient.Dual` has no idea it's an enum of operations.
- **Precedent risk**: High. Commits to "Dual" semantics that don't accurately describe either direction.

#### Option C: Rename to `Cases`

- **Accuracy**: Descriptive — the enum enumerates the cases (operations) of the witness.
- **Familiarity**: Medium. `APIClient.Cases.fetch` is clear.
- **Uniformity**: Clashes with the enum direction where the source type already has cases.
- **Discoverability**: Reasonable.
- **Precedent risk**: Medium. "Cases" is generic.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Keep `Action`.

**Rationale**:

1. **The transformation is asymmetric.** The struct→enum and enum→prisms expansions are fundamentally different operations. Trying to unify them under one name (`Dual`) masks this asymmetry and creates false expectations.

2. **"Dual" is inaccurate for the enum direction.** The current enum expansion generates prism infrastructure, NOT a Scott-encoding struct. Calling it `Dual` would be technically wrong.

3. **"Dual" is misleading in programming.** In every major language ecosystem, `Dual` means "reversed structure" (opposite monoid, contravariant functor), not "the corresponding sum/product type." Using it differently would confuse developers familiar with the established meaning.

4. **"Action" communicates purpose.** `APIClient.Action.fetch(id: 42)` immediately tells you what happened. `APIClient.Dual.fetch(id: 42)` tells you nothing about the domain.

5. **The literature provides no single name.** Defunctionalization, Church encoding, data/codata duality, the Expression Problem, and the Visitor pattern all describe the same transformation from different angles, but none has produced a universally accepted type-level name. `Action` is as good as any pragmatic choice, and has Swift ecosystem precedent.

6. **If we later add true enum duals** (Scott-encoding structs with one closure per case), we can choose a name that accurately describes THAT specific construction at that time — perhaps `Eliminator`, `Match`, or `Handler`.

## References

- Reynolds, J.C. (1972). "Definitional Interpreters for Higher-Order Programming Languages." ACM Conference Proceedings.
- Reynolds, J.C. (1975). "User-Defined Types and Procedural Data Structures as Complementary Approaches to Data Abstraction."
- Danvy, O. & Nielsen, L.R. (2001). "Defunctionalization at Work." PPDP 2001.
- Danvy, O. & Millikin, R. (2009). "Refunctionalization at Work." Science of Computer Programming.
- Rendel, T., Trieflinger, J. & Ostermann, K. (2015). "Automatic Refunctionalization to a Language with Copattern Matching." ICFP 2015.
- Böhm, C. & Berarducci, A. (1985). "Automatic Synthesis of Typed Lambda-Programs on Term Algebras." Theoretical Computer Science.
- Abel, A. & Pientka, B. et al. (2013). "Copatterns: Programming Infinite Structures by Observations." POPL 2013.
- Palsberg, J. & Jay, C.B. (1998). "The Essence of the Visitor Pattern." COMPSAC 1998.
- Gonzalez, G. (2021). "The Visitor Pattern is Essentially the Same Thing as Church Encoding." Haskell for All.
- Seemann, M. (2018). "Visitor as a Sum Type." ploeh blog.
- Wadler, P. (1998). "The Expression Problem."
- Cook, W.R. (1990). "Object-Oriented Programming Versus Abstract Data Types."
- Church, A. (1941). The Calculi of Lambda Conversion.
- Brandon Williams & Stephen Celis. "Protocol Witnesses: Parts 1-4." Point-Free Episodes 33-36 (2019).
- objc.io (2019). "Defunctionalization." Blog, September 10, 2019.
