# Implicit Member Init Resolution Hazard

<!--
---
version: 2.0.0
last_updated: 2026-03-10
status: DECISION
tier: 3
---
-->

## Context

On 2026-02-11, `swift-algebra-modular-primitives` failed to build. The error:

```
Algebra.Z+Arithmetic.swift:7:31: error: call can throw, but it is not marked with 'try'
    Self(__unchecked: (), Ordinal(.one) % Tag.capacity)
```

**Root cause**: `Affine_Primitives` (transitive via `Finite_Primitives → Index_Primitives → Affine_Primitives`) defines `Ordinal.init(_ vector: Affine.Discrete.Vector) throws(Error)` in `Ordinal+Affine.swift:21`. Since `Affine.Discrete.Vector` also provides `.one`, the implicit member expression `Ordinal(.one)` became ambiguous between:

1. `Ordinal(Cardinal.one)` — non-throwing
2. `Ordinal(Affine.Discrete.Vector.one)` — `throws(Ordinal.Error)`

The compiler selected the throwing overload. The code had worked previously because `Affine_Primitives` was not yet a transitive dependency.

**Experiment proof**: `swift-algebra-modular-primitives/Experiments/ordinal-modulo-throwing/` — CONFIRMED.

**Immediate fix**: Disambiguate with `Ordinal(Cardinal.one)`.

This incident is the third manifestation of a structural hazard in the ecosystem's cross-package init design. This research generalizes from three confirmed incidents to a principled prevention strategy.

### Prior Art Within Ecosystem

| Document | Date | Manifestation | Fix |
|----------|------|---------------|-----|
| `cross-domain-init-overload-resolution-footgun.md` | 2026-02-11 | `.map(Bit.Index.init)` selects byte-to-bit scaling init via literal inference | Argument labels on cross-domain inits |
| Index Primitives `_Package-Insights.md` | 2026-01-27 | `.one` resolves to `Offset.one` (throws) instead of `Count.one` (total) | `@_disfavoredOverload` on throwing overload |
| `zero-one-static-declarations.md` | 2026-02-06 | `Algebra.Z<n>.zero` ambiguous with `Tagged<_, Ordinal>.zero` from ordinal-primitives | Delete redundant declaration |
| **This incident** | 2026-02-11 | `Ordinal(.one)` resolves to `Affine.Discrete.Vector.one` instead of `Cardinal.one` | Explicit `Ordinal(Cardinal.one)` |

## Question

How should the Swift Institute ecosystem **principally prevent** implicit member expression resolution from selecting unintended init overloads when cross-package inits introduce competing parameter types?

## Analysis

### The Mechanism: Swift Implicit Member Expression Resolution

When the compiler encounters `T(.foo)`, it performs contextual type inference:

1. **Enumerate candidate inits**: Find all `T.init` overloads in scope (including cross-module extensions)
2. **For each init parameter type `P`**: Check if `P` has a static member `.foo`
3. **Rank candidates**: Apply overload resolution rules (specificity, throwing vs non-throwing, `@_disfavoredOverload`)
4. **Select**: If a single best candidate exists, use it; otherwise error

The hazard arises at step 1: as imports grow (directly or transitively), new `T.init` overloads enter scope, introducing new candidate parameter types. If those types have members with the same name (`.one`, `.zero`), previously unambiguous expressions become ambiguous or resolve to different overloads.

### Formal Characterization

Let `T` be a type with init overloads accepting parameter types `P₁, P₂, ..., Pₙ`. Let `m` be a static member name (e.g., `.one`). Define:

```
Candidates(T, m) = { Pᵢ | T.init(_ : Pᵢ) exists ∧ Pᵢ.m exists }
```

The expression `T(.m)` is **safe** when `|Candidates(T, m)| = 1`.

The expression `T(.m)` is **hazardous** when `|Candidates(T, m)| > 1` and the candidates differ in:
- **Throwing behavior**: One throws, another doesn't → silent `try` requirement
- **Semantic transformation**: One performs identity, another scales/transforms → silent wrong result
- **Domain**: Parameter types come from different mathematical domains → type confusion

The hazard is **latent** when `|Candidates(T, m)| = 1` in the current import set but a known package exists that would make it > 1. Latent hazards activate when dependency graphs evolve.

### Taxonomy of Manifestations

**Class 1: Throwing Ambiguity** (this incident)

```
Candidates(Ordinal, .one) = { Cardinal, Affine.Discrete.Vector }
- Ordinal(Cardinal.one) → non-throwing ✓
- Ordinal(Affine.Discrete.Vector.one) → throws(Error) ✗ selected
```

Compiler selects the throwing overload. Symptom: unexpected compilation error requiring `try`.

**Class 2: Semantic Transformation Ambiguity** (cross-domain-init footgun)

```
Candidates(Bit.Index, .init via literal) = { Int (direct), Index<UInt8> (×8 scaling) }
```

Compiler selects the scaling init. Symptom: silent runtime crash (indices ×8 too large).

**Class 3: Static Member Shadowing** (zero-one-static declarations)

```
Not init-based but the same pattern: two extensions on the same type provide
the same static member. Symptom: ambiguous member error.
```

**Class 4: Totality Inversion** (index-primitives @_disfavoredOverload)

```
Candidates(Index + .one) = { Count (total), Offset (throws) }
- Index + Count.one → total ✓
- Index + Offset.one → throws ✗ selected (before fix)
```

Compiler selects the partial operation. Symptom: unnecessary `try` propagation.

### Evaluation Criteria

| # | Criterion | Weight | Rationale |
|---|-----------|--------|-----------|
| C1 | **Prevention**: Eliminates the hazard structurally | Critical | A hazard that requires discipline to avoid will eventually be triggered |
| C2 | **Locality**: Fix is local to the init declaration, not all call sites | Critical | N call sites vs 1 declaration site |
| C3 | **Discoverability**: A developer adding a new init can tell they're creating a hazard | High | Convention must be teachable |
| C4 | **Compositionality**: Works regardless of import graph evolution | High | Latent hazards must not activate |
| C5 | **Convention alignment**: Consistent with existing [API-NAME-*], [IMPL-*] rules | High | Not a special case |
| C6 | **Migration cost**: Effort to apply retroactively | Medium | One-time cost |
| C7 | **Expressiveness**: Does not degrade the API at call sites | Medium | Must not over-label |

### Option A: `@_disfavoredOverload` on Cross-Domain Inits

Mark all cross-domain throwing inits with `@_disfavoredOverload` so the non-throwing, same-domain init is preferred.

```swift
extension Ordinal {
    @_disfavoredOverload
    @inlinable
    public init(_ vector: Affine.Discrete.Vector) throws(Error) { ... }
}
```

| Criterion | Assessment |
|-----------|------------|
| C1 Prevention | Partial — compiler still sees both candidates; disfavoring can be overridden by other resolution factors |
| C2 Locality | Yes — annotation is on the init declaration |
| C3 Discoverability | Weak — requires knowing when to apply the annotation |
| C4 Compositionality | No — fragile under import graph changes; if the preferred overload is itself disfavored for another reason, resolution inverts |
| C5 Convention alignment | Weak — `@_disfavoredOverload` is underscored, not part of stable Swift |
| C6 Migration cost | Minimal — add one annotation |
| C7 Expressiveness | No change to call sites |

**Verdict**: Tactical fix, not a principled solution. The Index Primitives insight already documents that disfavoring is a "blunt tool." It can fix individual cases but creates a fragile ordering dependency.

### Option B: Argument Labels on Cross-Domain Inits

Require all inits that perform cross-domain conversion to use an argument label. Only same-domain identity-preserving inits may be unlabeled.

```swift
// Same-domain (identity-preserving) — unlabeled ✓
extension Ordinal {
    public init(_ count: Cardinal) { ... }      // Cardinal → Ordinal (same numeric value, different type)
    public init(_ ordinal: Ordinal) { ... }     // Identity
}

// Cross-domain (transformation) — labeled ✓
extension Ordinal {
    public init(vector: Affine.Discrete.Vector) throws(Error) { ... }   // ℤ → ℕ (partial)
    public init(position: Int) throws(Error) { ... }                     // Signed → unsigned (partial)
}
```

| Criterion | Assessment |
|-----------|------------|
| C1 Prevention | **Yes** — labeled inits cannot participate in `T(.foo)` resolution; `Ordinal(.one)` can only match unlabeled inits |
| C2 Locality | **Yes** — the label is on the declaration |
| C3 Discoverability | **Yes** — clear rule: "is this a domain crossing? → add a label" |
| C4 Compositionality | **Yes** — labels are permanent; no import graph sensitivity |
| C5 Convention alignment | **Yes** — extends [PATTERN-019] and aligns with `cross-domain-init-overload-resolution-footgun.md` recommendation |
| C6 Migration cost | Medium — rename parameter labels, update call sites |
| C7 Expressiveness | Improved — label documents the transformation semantics |

**Verdict**: The strongest structural prevention. Removes cross-domain inits from implicit member resolution entirely. Already recommended by `cross-domain-init-overload-resolution-footgun.md` for the `.map(Type.init)` case.

### Option C: Explicit Member Expressions at Call Sites

Require all `.one`/`.zero` usage in init contexts to spell out the type: `Ordinal(Cardinal.one)` instead of `Ordinal(.one)`.

| Criterion | Assessment |
|-----------|------------|
| C1 Prevention | No — the hazard still exists; discipline prevents it |
| C2 Locality | **No** — fix is at every call site, not the declaration |
| C3 Discoverability | No — requires knowing which expressions are hazardous |
| C4 Compositionality | Partial — explicit types are immune to import changes, but nothing prevents implicit use |
| C5 Convention alignment | Conflicts with [IMPL-INTENT] — `Ordinal(Cardinal.one)` exposes the mechanism of which `.one` is intended |
| C6 Migration cost | High — every call site |
| C7 Expressiveness | Degraded — forces explicit types where Swift's inference should work |

**Verdict**: This is what we did as an immediate fix. It works but treats the symptom, not the cause. Every new call site must remember to be explicit.

### Option D: Init Taxonomy Convention

Establish a formal convention classifying all inits by their relationship to the target type:

| Category | Label | Throwing | Example |
|----------|-------|----------|---------|
| **Identity** | Unlabeled | Never | `Ordinal(_ : Ordinal)` |
| **Promotion** | Unlabeled | Never | `Ordinal(_ : Cardinal)` — same-domain, lossless |
| **Narrowing** | Unlabeled | May throw | `Cardinal(_ : Int)` — loses sign, may fail |
| **Cross-domain** | **Required label** | Usually | `Ordinal(vector: Affine.Discrete.Vector)` |
| **Bit-pattern** | `bitPattern:` | Never | `Int(bitPattern: Ordinal)` — reinterpretation |
| **Unchecked** | `__unchecked` | Never | `Self(__unchecked: (), rawValue)` — internal |

The key rule: **cross-domain inits MUST use argument labels**. This is Option B elevated to a formal taxonomy that covers all init categories.

The taxonomy also addresses the narrowing case. `Ordinal.init(_ value: Int) throws(Error)` is currently unlabeled. Under this taxonomy, `Int → Ordinal` is a narrowing conversion (loses sign), and the convention permits unlabeled narrowing inits. However, if a narrowing init creates ambiguity, it should be disfavored or labeled.

| Criterion | Assessment |
|-----------|------------|
| C1 Prevention | **Yes** — cross-domain inits structurally excluded from implicit resolution |
| C2 Locality | **Yes** — classification is at the declaration |
| C3 Discoverability | **Yes** — clear decision tree: classify the init → apply the rule |
| C4 Compositionality | **Yes** — taxonomy is independent of import graph |
| C5 Convention alignment | **Yes** — formalizes patterns already implicit in the ecosystem |
| C6 Migration cost | Medium-High — requires classifying and potentially relabeling existing inits |
| C7 Expressiveness | Improved — labels document transformation semantics |

**Verdict**: The most comprehensive option. Subsumes Option B and provides a framework for all future init design decisions.

### Option E: Remove `.one` from `Affine.Discrete.Vector`

The narrowest fix: delete the `.one` property from `Affine.Discrete.Vector`.

| Criterion | Assessment |
|-----------|------------|
| C1 Prevention | Partial — fixes this one case; doesn't prevent `.zero` ambiguity or future member collisions |
| C2 Locality | No — removes API from the wrong type; the hazard is in the init, not the member |
| C3 Discoverability | No — no general principle; whack-a-mole |
| C4 Compositionality | No — any future member addition can re-trigger the hazard |
| C5 Convention alignment | No — removes a legitimate API |
| C6 Migration cost | Low — few call sites for `Affine.Discrete.Vector.one` |
| C7 Expressiveness | Degraded — vectors losing `.one` is mathematically wrong (vectors form a group with identity 0, generator 1) |

**Verdict**: Rejected. Treats the wrong symptom. The vector legitimately has `.one`.

### Comparison Matrix

| Criterion | A: Disfavor | B: Labels | C: Explicit | D: Taxonomy | E: Remove .one |
|-----------|-------------|-----------|-------------|-------------|----------------|
| C1 Prevention | Partial | **Yes** | No | **Yes** | Partial |
| C2 Locality | Yes | **Yes** | No | **Yes** | No |
| C3 Discoverability | Weak | **Yes** | No | **Yes** | No |
| C4 Compositionality | No | **Yes** | Partial | **Yes** | No |
| C5 Convention alignment | Weak | **Yes** | Conflicts | **Yes** | No |
| C6 Migration cost | Minimal | Medium | High | Medium-High | Low |
| C7 Expressiveness | Neutral | Improved | Degraded | Improved | Degraded |

### Theoretical Grounding

The hazard is an instance of the **open world assumption** interacting with **overload resolution**. In a closed module, all inits are known at definition time, and ambiguity can be resolved once. In Swift's open extension model, any module can add inits to any type, creating an open set of candidates.

This is formally analogous to the **expression problem** (Wadler 1998): adding new cases (init overloads) to an existing type (Ordinal) without modifying existing code. Swift's extension mechanism solves the expression problem for types but does not address the resolution hazard that emerges when extensions from different modules create overlapping implicit member candidates.

The init taxonomy (Option D) addresses this by partitioning the init space into categories with different resolution rules. Cross-domain inits, being the most hazardous (they perform semantic transformation AND come from external modules), are excluded from implicit resolution via mandatory labels. This is a form of **type-directed name resolution** where the label disambiguates the domain.

From an **affine type theory** perspective, the taxonomy aligns with the distinction between:
- **Structural morphisms** (identity, promotion, narrowing) — preserve or restrict the value's domain
- **Cross-domain morphisms** (vector ↔ position, byte ↔ bit) — change the value's interpretation

Structural morphisms are safe for implicit resolution because they don't change meaning. Cross-domain morphisms change meaning and must be explicit.

### Prior Art Survey

**Rust**: Rust's `From`/`Into` traits provide explicit conversion. `From<T> for U` is always explicit: `U::from(value)`. No implicit resolution hazard because conversions are never implicit in expression position. The cost is verbosity.

**Haskell**: Haskell's type class resolution (instance selection) faces a similar problem. The solution is the **coherence requirement**: at most one instance of a class for any type. This prevents ambiguity but limits expressiveness. Swift has no coherence requirement for overload resolution.

**Swift Evolution**: SE-0299 (Extending Static Member Lookup in Generic Contexts) expanded where implicit member expressions work. The proposal acknowledges that "the compiler can find all possible types that have a matching static member" but does not address the hazard when this set grows across modules. No proposal has directly addressed cross-module init ambiguity.

**C++ ADL (Argument-Dependent Lookup)**: C++ faces a similar problem where `using namespace` directives bring functions into scope that can change overload resolution. The mitigation is the same: explicit namespacing at call sites or namespace isolation. The C++ community treats this as a known hazard of `using namespace`.

### Empirical Validation (Cognitive Dimensions)

Applying the Cognitive Dimensions Framework to Option D (Init Taxonomy):

| Dimension | Assessment |
|-----------|------------|
| **Visibility** | Improved — labels make the transformation visible at call sites |
| **Consistency** | Improved — uniform rule: cross-domain = labeled |
| **Viscosity** | Slightly increased — adding a cross-domain init requires choosing a label |
| **Role-expressiveness** | Improved — the label documents what the init does |
| **Error-proneness** | Significantly reduced — the primary class of errors (implicit resolution to wrong overload) is eliminated |
| **Abstraction** | Appropriate — the taxonomy matches the mathematical structure |

## Constraints

1. **`@_disfavoredOverload` is underscored**: It may change behavior or be removed in future Swift versions. Depending on it for correctness is fragile.

2. **Backward compatibility**: Relabeling existing inits is a source-breaking change for direct callers. Requires migration path.

3. **Swift's overload resolution is complex**: The interaction between throwing, `@_disfavoredOverload`, generic constraints, and implicit member expressions is not fully specified. The taxonomy must not depend on specific resolution tie-breaking rules.

4. **The ecosystem is layered**: Inits are defined at different layers (ordinal-primitives defines `Ordinal.init(_ : Cardinal)`; affine-primitives defines `Ordinal.init(_ : Vector)`). The convention must be enforceable at each layer independently.

5. **`Int` is a special case**: `Ordinal.init(_ : Int) throws` is a narrowing conversion (signed → unsigned). It's not cross-domain but it IS throwing and its parameter type (`Int`) will eventually gain `.one` from some protocol conformance. This is a latent Class 1 hazard.

## Outcome

**Status**: DECISION

**Resolved**: The Option D (Init Taxonomy) / Option B (argument labels on cross-domain inits) recommendation was adopted. The follow-up research `labeled-cross-domain-init-convention.md` (DECISION, 2026-03-04) formalized and implemented this convention across the ecosystem with a comprehensive inventory and labeling scheme.

### Recommendation: Option D (Init Taxonomy) with Option B as the actionable core

The init taxonomy provides the principled framework. The immediately actionable rule is:

> **Cross-domain conversion inits MUST use argument labels.** An init is cross-domain when the parameter type comes from a different mathematical domain than the target type (e.g., `Affine.Discrete.Vector → Ordinal`, `Index<UInt8> → Bit.Index`). Same-domain promotions (`Cardinal → Ordinal`) and identity inits may remain unlabeled.

### Proposed Convention: [INIT-LABEL-001] Init Labeling by Category

**Statement**: Init overloads on primitive types MUST follow the labeling taxonomy:

| Category | Definition | Label | May Throw | Implicit Resolution |
|----------|-----------|-------|-----------|---------------------|
| Identity | Same type | Unlabeled | No | Safe |
| Promotion | Same domain, lossless widening | Unlabeled | No | Safe |
| Narrowing | Same domain, lossy | Unlabeled or `exactly:` | Yes (`init?` or `throws`) | Safe if non-throwing variant exists |
| Cross-domain | Different mathematical domain | **Required descriptive label** | Usually | **Excluded from implicit resolution** |
| Bit-pattern | Reinterpretation without validation | `bitPattern:` | No | Excluded (labeled) |
| Unchecked | Internal, bypasses invariants | `__unchecked` | No | Excluded (labeled) |

**Test**: "Does this init change the mathematical meaning of the value?" If yes → cross-domain → label required.

### Immediate Actions

1. **Label `Ordinal.init(_ vector: Affine.Discrete.Vector)`** in `Ordinal+Affine.swift:21`:

   ```swift
   // Before:
   public init(_ vector: Affine.Discrete.Vector) throws(Error)

   // After:
   public init(vector: Affine.Discrete.Vector) throws(Error)
   ```

2. **Audit all cross-domain inits** across the ecosystem per the taxonomy. Priority:
   - Inits where the parameter type has `.one` or `.zero` (immediate ambiguity risk)
   - Inits that perform non-identity transformation (semantic risk)
   - Inits that throw (throwing ambiguity risk)

3. **Add `@_disfavoredOverload`** as a temporary mitigation on all throwing cross-domain inits until labels are applied. This is a belt-and-suspenders approach: labels prevent implicit resolution; disfavoring provides a fallback.

### Implemented

- Formal convention established in `labeled-cross-domain-init-convention.md` (primitives-wide, DECISION, 2026-03-04)
- Init taxonomy applied to all Tagged types across the ecosystem
- `Int` latent hazard — `Int` does not currently have `.one` in scope for primitives packages; monitor if this changes

## References

### Ecosystem Prior Art
- `Research/cross-domain-init-overload-resolution-footgun.md` — Class 2 manifestation, argument label recommendation
- `Research/blanket-tagged-init-audit.md` — Related anti-pattern (blanket inits bypassing invariants)
- `swift-index-primitives/Documentation.docc/_Package-Insights.md` — Class 4 manifestation, `@_disfavoredOverload` discovery
- `swift-algebra-modular-primitives/Research/zero-one-static-declarations.md` — Class 3 manifestation
- `swift-algebra-modular-primitives/Experiments/ordinal-modulo-throwing/` — This incident's experiment

### Swift Evolution
- SE-0299: Extending Static Member Lookup in Generic Contexts
- SE-0390: Noncopyable structs and enums

### Academic
- Wadler, P. (1998). "The Expression Problem." — Open extension and resolution hazards
- Kitchenham, B. (2004). "Procedures for Performing Systematic Reviews." — SLR methodology (applied to prior art survey)
- Green, T. R. G. (1989). "Cognitive Dimensions of Notations." — Framework applied in empirical validation

### Language Comparison
- Rust `From`/`Into` — explicit conversion, no implicit resolution
- Haskell instance coherence — at most one instance, prevents ambiguity
- C++ ADL — analogous cross-namespace resolution hazard
