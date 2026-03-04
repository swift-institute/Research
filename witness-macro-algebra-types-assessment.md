# @Witness Macro Adoption for Algebra Types

<!--
---
version: 1.0.0
last_updated: 2026-03-04
status: DECISION
source: source-level audit of 14 @frozen witness types across swift-primitives
verified_by: Tier 1 investigation 2026-03-04
---
-->

## Context

The `next-steps-witnesses.md` document rated `@Witness` macro adoption for algebra types as LOW priority, citing three blockers: "@frozen, performance-critical, unlabeled closures." Since that assessment, five macro improvements have shipped:

1. **`let` closure support** -- macro now handles `let` bindings (not just `var`)
2. **`_` prefix stripping** -- internal naming convention support
3. **`firstName` labels** -- labeled parameter method generation
4. **`skip-init`** -- skips init generation when one already exists
5. **Non-closure properties** -- handles mixed closure/value stored properties

The question is whether these improvements change the calculus for 14 `@frozen` algebra-style witness types.

## Question

Should the `@Witness` macro be applied to the 14 algebra-style `@frozen` witness types currently using manual `Witness.Protocol` conformance?

## Analysis

### The 14 Types

All types were identified by searching for `Witness.Protocol` conformance across `swift-primitives`, then filtering to `@frozen` algebra-style witnesses:

| # | Type | Package | File | @frozen | Closure Properties | Non-Closure Properties |
|---|------|---------|------|---------|-------------------|----------------------|
| 1 | `Algebra.Magma` | swift-algebra-magma-primitives | `Algebra.Magma.swift:19` | Yes | `combining: (Element, Element) -> Element` | -- |
| 2 | `Algebra.Semigroup` | swift-algebra-magma-primitives | `Algebra.Semigroup.swift:22` | Yes | `combining: (Element, Element) -> Element` | -- |
| 3 | `Algebra.Monoid` | swift-algebra-monoid-primitives | `Algebra.Monoid.swift:19` | Yes | `combining: (Element, Element) -> Element` | `identity: Element` |
| 4 | `Algebra.Monoid.Commutative` | swift-algebra-monoid-primitives | `Algebra.Monoid.Commutative.swift:12` | Yes | -- | `monoid: Algebra.Monoid<Element>` |
| 5 | `Algebra.Group` | swift-algebra-group-primitives | `Algebra.Group.swift:23` | Yes | `combining: (Element, Element) -> Element`, `inverting: (Element) -> Element` | `identity: Element` |
| 6 | `Algebra.Group.Abelian` | swift-algebra-group-primitives | `Algebra.Group.Abelian.swift:16` | Yes | -- | `group: Algebra.Group<Element>` |
| 7 | `Algebra.Semiring` | swift-algebra-semiring-primitives | `Algebra.Semiring.swift:19` | Yes | -- | `additive: Algebra.Monoid<Element>.Commutative`, `multiplicative: Algebra.Monoid<Element>` |
| 8 | `Algebra.Semiring.Commutative` | swift-algebra-semiring-primitives | `Algebra.Semiring.Commutative.swift:12` | Yes | -- | `semiring: Algebra.Semiring<Element>` |
| 9 | `Algebra.Ring` | swift-algebra-ring-primitives | `Algebra.Ring.swift:28` | Yes | -- | `additive: Algebra.Group<Element>.Abelian`, `multiplicative: Algebra.Monoid<Element>` |
| 10 | `Algebra.Ring.Commutative` | swift-algebra-ring-primitives | `Algebra.Ring.Commutative.swift:12` | Yes | -- | `ring: Algebra.Ring<Element>` |
| 11 | `Algebra.Field` | swift-algebra-field-primitives | `Algebra.Field.swift:32` | Yes | `reciprocal: (Element) throws(Error) -> Element` | `additive: Algebra.Group<Element>.Abelian`, `multiplicative: Algebra.Monoid<Element>.Commutative` |
| 12 | `Algebra.Module` | swift-algebra-module-primitives | `Algebra.Module.swift:20` | Yes | `scaling: (Scalar, Vector) -> Vector` | `scalars: Algebra.Ring<Scalar>`, `vectors: Algebra.Group<Vector>.Abelian` |
| 13 | `Algebra.VectorSpace` | swift-algebra-module-primitives | `Algebra.VectorSpace.swift:13` | Yes | `scaling: (Scalar, Vector) -> Vector` | `scalars: Algebra.Field<Scalar>`, `vectors: Algebra.Group<Vector>.Abelian` |
| 14 | `Sample.Averaging` | swift-sample-primitives | `Sample.Averaging.swift:18` | Yes | `adding: (Element, Element) -> Element`, `dividing: (Element, Int) -> Element`, `project: (Element) -> Double`, `embed: (Double) -> Element` | `zero: Element` |

### Structural Categories

The 14 types fall into two structural categories:

**Category A: Direct closure witnesses (8 types)**
Types with at least one closure stored property directly on the struct: Magma, Semigroup, Monoid, Group, Field, Module, VectorSpace, Sample.Averaging.

**Category B: Pure wrappers (6 types)**
Types with ONLY non-closure properties that wrap a lower-level algebra witness: Monoid.Commutative, Group.Abelian, Semiring, Semiring.Commutative, Ring, Ring.Commutative.

**Note:** Category B types have zero closure properties. The `@Witness` macro requires at least one closure property and emits a diagnostic error (`noClosureProperties`) when none are found. These 6 types are structurally incompatible with the macro.

### Per-Type Assessment

| # | Type | Category | Closures | Unlabeled? | `let`? | `@frozen`? | `inout`/`borrowing`? | Macro Viable? | Verdict |
|---|------|----------|----------|------------|--------|-----------|---------------------|--------------|---------|
| 1 | Magma | A | 1 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 2 | Semigroup | A | 1 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 3 | Monoid | A | 1 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 4 | Monoid.Commutative | B | 0 | N/A | N/A | Yes | No | **No** -- no closures | BLOCKED |
| 5 | Group | A | 2 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 6 | Group.Abelian | B | 0 | N/A | N/A | Yes | No | **No** -- no closures | BLOCKED |
| 7 | Semiring | B | 0 | N/A | N/A | Yes | No | **No** -- no closures | BLOCKED |
| 8 | Semiring.Commutative | B | 0 | N/A | N/A | Yes | No | **No** -- no closures | BLOCKED |
| 9 | Ring | B | 0 | N/A | N/A | Yes | No | **No** -- no closures | BLOCKED |
| 10 | Ring.Commutative | B | 0 | N/A | N/A | Yes | No | **No** -- no closures | BLOCKED |
| 11 | Field | A | 1 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 12 | Module | A | 1 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 13 | VectorSpace | A | 1 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |
| 14 | Sample.Averaging | A | 4 | Yes | No (`var`) | Yes | No | Technically yes | NOT WORTH IT |

### Blocker Analysis

**Blocker 1: `@frozen` incompatibility**

The `@Witness` macro is an `@attached(member)` macro that generates members into the struct. For `@frozen` types, the ABI layout is fixed. The macro generates:
- A public `init` (skipped if one exists -- all 14 types already have `@inlinable public init`)
- Methods for labeled closures (none here -- all closures are unlabeled)
- An `Action` enum (new nested type -- compatible with `@frozen` since nested types do not affect layout)
- An `Observe` struct and property (new members -- the `observe` property is computed, so does not violate layout)

The macro also generates `Witness.Protocol` conformance and `unimplemented()` via `@attached(extension)`, which are extensions and compatible with `@frozen`.

**Verdict on @frozen:** Not a hard blocker per se, but the macro was not designed with `@frozen` in mind and this combination has not been tested.

**Blocker 2: Unlabeled closures**

ALL closure properties across these 14 types use unlabeled parameters:
- `combining: (Element, Element) -> Element` -- no labels
- `inverting: (Element) -> Element` -- no labels
- `scaling: (Scalar, Vector) -> Vector` -- no labels
- `reciprocal: (Element) throws(Error) -> Element` -- no labels
- etc.

The `@Witness` macro's primary value proposition for closures is generating labeled methods from `(_ label: Type)` syntax. With unlabeled closures, the macro generates NO methods (the `property.hasLabels` check returns false). The only generated artifacts would be:
- `Action` enum (useful for observation/middleware)
- `observe` accessor
- `unimplemented()` static method

These features have minimal value for algebra types, which are mathematical structures, not service clients. Nobody needs to observe or mock a semigroup operation.

**Blocker 3: Pure wrapper types are structurally incompatible**

6 of 14 types (Monoid.Commutative, Group.Abelian, Semiring, Semiring.Commutative, Ring, Ring.Commutative) contain zero closure properties. They are pure wrappers around lower-level algebra types. The macro requires at least one closure property and will emit a diagnostic error for these types.

**Blocker 4: Layer violation**

The `@Witness` macro lives in `swift-witnesses` (Layer 3, Foundations). The algebra types live in Layer 1 (Primitives). Primitives cannot depend on Foundations. Applying `@Witness` would require either:
- Moving the macro to Layer 1 (wrong -- macros are too heavy for primitives)
- Moving algebra types to Layer 3 (wrong -- they are atomic building blocks)

This is a hard architectural blocker, independent of all other considerations.

### What the Macro Would Generate (Category A types only)

For a type like `Algebra.Magma<Element>` with one unlabeled closure:

| Generated Artifact | Value for Algebra Types |
|---|---|
| Public init | Already exists manually |
| Labeled methods | None -- closures are unlabeled |
| `Action` enum | `enum Action { case combining(Element, Element) }` -- minimal value |
| `Observe` accessor | Wraps combining with observer -- not needed for math |
| `unimplemented()` | Throws for combining -- not needed, these are always constructed with real closures |
| `Witness.Protocol` conformance | Already declared manually |

Net value: effectively zero.

## Comparison

| Approach | Pros | Cons |
|----------|------|------|
| Apply `@Witness` macro | Consistency with other witness types; auto-generated `unimplemented()` | Layer violation; 6/14 types incompatible; no labeled methods; no real value for math types; `@frozen` untested with macro; adds swift-witnesses dependency to L1 |
| Keep manual conformance | Zero risk; already working; correct layering; minimal code; no macro dependency at L1 | Slight inconsistency with L3 witness types that use the macro |

## Outcome

**DECISION: Do not apply `@Witness` macro to the 14 algebra types. The original LOW assessment was correct and remains correct.**

### Rationale

1. **Hard architectural blocker**: The macro lives at Layer 3; algebra types live at Layer 1. This alone is disqualifying.

2. **6/14 types structurally incompatible**: Pure wrapper types (Monoid.Commutative, Group.Abelian, Semiring, Semiring.Commutative, Ring, Ring.Commutative) have zero closure properties. The macro would emit a diagnostic error.

3. **Zero value for remaining 8 types**: All closures are unlabeled, so no methods are generated. The `Action` enum, `observe`, and `unimplemented()` provide no meaningful benefit for mathematical algebra structures. These are not service clients that need mocking or observation.

4. **The five macro improvements do not change the calculus**:
   - `let` closures: All algebra types use `var`, not `let`. Even if they used `let`, the value proposition remains zero.
   - `_` prefix stripping: Not relevant -- no prefixed names.
   - `firstName` labels: Not relevant -- no labeled closure parameters.
   - `skip-init`: Helpful but moot since the macro provides no other value.
   - Non-closure properties: Helpful for mixed types (Monoid, Group, Field, Module, VectorSpace, Sample.Averaging all have non-closure + closure properties), but again moot since the macro provides no other value.

### Action Items

None. The current manual `Witness.Protocol` conformance is the correct design for these types.

### Future Reconsideration Triggers

This decision should only be revisited if ALL of the following change:
- The macro is available at Layer 1 (e.g., via a lightweight macro-only package)
- Algebra types gain labeled closure parameters (unlikely -- math operations are positional)
- A concrete use case emerges for observing or mocking algebra operations
