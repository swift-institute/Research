# Finite-Collection Join-Point Integration

<!--
---
version: 1.1.0
last_updated: 2026-01-29
status: RECOMMENDATION
tier: 3
---
-->

## Context

During an audit of swift-primitives tier structure, we discovered that `finite-primitives` (Tier 11) depends on `collection-primitives` (Tier 10), which cascades upward through `algebra-primitives` (Tier 12) and affects 20+ downstream packages. The dependency exists solely to provide `Finite.Enumeration<T>` with `RandomAccessCollection` conformance for the `CaseIterable.allCases` default implementation.

Removing this dependency would compress the tier structure by 3-4 tiers. However, the integration semantics ("finite types as collections") must be preserved somewhere.

**Trigger**: [RES-001] Design decision blocks tier compression refactoring.

**Scope**: Ecosystem-wide per [RES-002a] — affects primitives-wide tier structure and establishes precedent for join-point patterns.

**Tier Justification**: This is Tier 3 research because:
- Establishes normative precedent for join-point integration patterns
- Affects 20+ packages across the primitives layer
- Cost of error is very high (wrong pattern cascades everywhere)
- Expected lifetime is "timeless infrastructure"

---

## Question

**Primary**: Should `collection-primitives` contain a join-point target (`Collection Finite Primitives`) that depends on `finite-primitives` to provide collection conformances for `Finite.Enumeration`?

**Secondary**: Does this integration pattern follow SDG conventions, specifically [SEM-DEP-008] Join-Point Resolution?

---

## Prior Art Survey

*Per [RES-021], Tier 2+ MUST include prior art survey.*

### Swift Evolution

- **SE-0194 CaseIterable**: Introduced `CaseIterable` protocol with `AllCases: Collection` requirement. The stdlib provides automatic synthesis for simple enums, but custom types must provide their own `allCases`. The `Collection` requirement is baked into the protocol.

- **SE-0234 Package Manager Dependency Resolution**: Establishes that dependency direction matters for resolution. Circular dependencies are forbidden. This reinforces why finite → collection → finite would be problematic.

### Related Languages (Summary)

**Rust (std::iter)**:
- Rust separates `Iterator` (lazy, pull-based) from collection traits (`Vec`, `HashMap`)
- `IntoIterator` provides the bridge — any collection can become an iterator
- The pattern: base types are independent; integration traits bridge them
- Relevant: Rust doesn't require iterables to be collections

**Haskell (Data.Foldable, Data.Traversable)**:
- `Foldable` provides iteration without requiring indexing
- `Traversable` adds structure-preserving mapping
- The typeclass hierarchy is: `Functor` → `Foldable` → `Traversable`
- Relevant: Iteration is separated from random access

**OCaml (Seq module)**:
- `Seq.t` is a lazy sequence type, independent of concrete collections
- Collections provide `to_seq` functions
- Relevant: Sequences and collections are separate modules

---

## Literature Study

*Extended comparative analysis per [RES-021] and [RES-023].*

### Rust: Iterator Trait Hierarchy

**Source**: [ExactSizeIterator in std::iter](https://doc.rust-lang.org/std/iter/trait.ExactSizeIterator.html)

Rust's approach is the clearest example of **orthogonal composition**:

```
trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}

trait ExactSizeIterator: Iterator {
    fn len(&self) -> usize;
}

trait IntoIterator {
    type Item;
    type IntoIter: Iterator<Item = Self::Item>;
    fn into_iter(self) -> Self::IntoIter;
}
```

**Key design decisions**:
1. `Iterator` is the minimal abstraction — just `next()`. No size requirement.
2. `ExactSizeIterator` is a **refinement** that adds known-length semantics.
3. Collections implement `IntoIterator`, not `Iterator` directly.
4. `ExactSizeIterator` is a **safe trait** — it cannot guarantee correctness, only promises intent.

**Module organization**: `std::iter` contains iterator traits; `std::collections` contains collection types. The integration (collections yielding iterators) happens via `IntoIterator` implementations in the collection modules.

**Relevance to our question**: Rust's pattern directly supports Option B. The iterator infrastructure is independent; collections add integration. A finite enum in Rust would implement `IntoIterator` to yield an `ExactSizeIterator`, but the enum type itself doesn't depend on collection modules.

### Haskell: Enum + Bounded + Foldable Independence

**Sources**: [GHC.Enum](https://hackage.haskell.org/package/base/docs/GHC-Enum.html), [Data.Foldable](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Foldable.html)

Haskell uses **typeclass composition** rather than inheritance:

```haskell
class Enum a where
    succ, pred :: a -> a
    toEnum :: Int -> a
    fromEnum :: a -> Int
    enumFrom :: a -> [a]

class Bounded a where
    minBound, maxBound :: a

class Foldable t where
    foldr :: (a -> b -> b) -> b -> t a -> b
```

**Key design decisions**:
1. `Enum` provides successor/predecessor — enumeration order.
2. `Bounded` provides min/max — finite bounds.
3. `Foldable` provides folding — iteration abstraction.
4. **These typeclasses are independent** — no inheritance relationship.
5. For a finite type, you derive both `Enum` and `Bounded`, then use `[minBound..maxBound]` to get a list.

**Haskell's pattern**:
```haskell
data Direction = North | East | South | West
  deriving (Enum, Bounded, Show)

allDirections :: [Direction]
allDirections = [minBound .. maxBound]  -- Enum + Bounded compose
```

The list `[minBound..maxBound]` is where the integration happens — at the **use site**, not in the type definition.

**Relevance to our question**: Haskell strongly supports Option B or even Option D. Finiteness (`Bounded`) and enumerability (`Enum`) are independent from collection operations (`Foldable`). The "finite enumeration as collection" is a derived view, constructed when needed.

### C++20 Ranges: Concept Refinement

**Sources**: [Ranges library (C++20)](https://en.cppreference.com/w/cpp/ranges.html), [std::ranges::sized_range](https://www.cppstories.com/2022/ranges-composition/)

C++20 ranges use **concept refinement**:

```cpp
template<class T>
concept range = requires(T& t) {
    ranges::begin(t);
    ranges::end(t);
};

template<class T>
concept sized_range = range<T> && requires(T& t) {
    ranges::size(t);
};

template<class T>
concept random_access_range = bidirectional_range<T> && /* ... */;
```

**Key design decisions**:
1. `range` is minimal — begin/end pair.
2. `sized_range` **refines** range by adding size.
3. `random_access_range` **refines** bidirectional_range.
4. Concepts are **orthogonal** — a type can satisfy any subset.
5. Ranges distinguish: counted (`[begin, size)`), conditionally-terminated (`[begin, predicate)`), unbounded (`[begin, ..)`).

**Module organization**: `<ranges>` contains the concept definitions; `<vector>`, `<array>`, etc. contain the types that model them.

**Relevance to our question**: C++20's approach supports Option B. The sized/finite property is a refinement concept, not a base requirement. A finite enumeration would model `sized_range` via a separate conceptual layer.

### Kotlin: EnumEntries<E> : List<E>

**Sources**: [EnumEntries](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.enums/-enum-entries/), [KEEP enum-entries proposal](https://github.com/Kotlin/KEEP/blob/master/proposals/enum-entries.md)

Kotlin chose **tight coupling with sealed interface**:

```kotlin
sealed interface EnumEntries<E : Enum<E>> : List<E>
```

**Key design decisions**:
1. `EnumEntries` directly extends `List<E>` — **tight coupling**.
2. `sealed interface` restricts implementations to stdlib.
3. Replaces `values()` array (which allocated each call) with immutable list.
4. Performance: `get`, `contains`, `indexOf` are O(1).
5. Extensibility: Future methods like `valueOfOrNull(String)` can be added.

**Why List<E>?**: The KEEP proposal explains: using `List<E>` directly doesn't allow programmers to introduce their own extensions specific to enum entries. The sealed interface provides extension points.

**Relevance to our question**: Kotlin chose the opposite of Option B — tight coupling. However, Kotlin's justification was **practical ergonomics** over architectural purity. They accepted the coupling because:
- Enums are a language feature, not a library type
- The stdlib owns both `List` and `Enum`
- No tier/layer constraints exist in Kotlin's stdlib

This doesn't apply to swift-primitives where layering is a core constraint.

### Java: values() Design Flaw

**Sources**: [Memory-Hogging Enum.values() Method](https://dzone.com/articles/memory-hogging-enumvalues-method), [Filling a List With All Enum Values](https://www.baeldung.com/java-enum-values-to-list)

Java's `values()` is a **cautionary tale**:

```java
public enum Direction {
    NORTH, EAST, SOUTH, WEST
}

Direction[] values = Direction.values();  // Allocates new array each call!
```

**The problem**:
Brian Goetz (Java language architect) acknowledged: "This is essentially an API design bug; because values() returns an array, and arrays are mutable, it must copy the array every time."

**Design flaw analysis**:
1. `values()` returns `T[]` — mutable array.
2. Mutability forces defensive copying on every call.
3. In tight loops, this creates GC pressure.
4. Workarounds: `EnumSet.allOf()`, cache the array manually.

**Proposed fixes**:
- JDK-8073381: "need API to get enum's values without creating a new array"
- Goetz hinted at "frozen arrays" (immutable arrays) as future solution

**Relevance to our question**: Java shows the **cost of tight coupling without proper abstraction**. The enum type directly exposes collection semantics (`T[]`) but without the right abstraction (`List`), leading to allocation issues. This supports Option B: proper integration requires deliberate abstraction, not ad-hoc coupling.

### OCaml: Seq and BatEnum Separation

**Sources**: [OCaml Seq Module](https://ocaml.org/manual/5.3/api/Seq.html), [Batteries BatEnum](https://ocaml-batteries-team.github.io/batteries-included/hdoc2/BatEnum.html)

OCaml has **multiple approaches** in its ecosystem:

**Standard Library (Seq)**:
```ocaml
type 'a t = unit -> 'a node
and 'a node = Nil | Cons of 'a * 'a t
```
- Lazy sequences — elements computed on demand
- Can be finite or infinite
- `iter`, `fold_left`, `length` only terminate on finite sequences
- Collections provide `to_seq` functions

**Batteries Included (BatEnum)**:
```ocaml
type 'a t  (* abstract enumeration type *)
val range : ?until:int -> int -> int t
val seq : 'a -> ('a -> 'a) -> ('a -> bool) -> 'a t
```
- Explicit finite/infinite distinction
- Enumerations as uniform data structure interface
- Can create bounded or unbounded enumerations

**Key insight**: OCaml's standard library treats sequences as orthogonal to collections. The Batteries library adds richer enumeration abstractions. Neither requires tight coupling.

### Cross-Language Synthesis

| Language | Finite/Enum Concept | Collection Concept | Coupling | Integration Point |
|----------|--------------------|--------------------|----------|-------------------|
| **Rust** | (no std enum) | Iterator, IntoIterator | Loose | IntoIterator impl |
| **Haskell** | Enum + Bounded | Foldable, Traversable | None | Use-site composition |
| **C++20** | (no std enum) | range, sized_range | Loose | Concept refinement |
| **Kotlin** | Enum, EnumEntries | List | Tight | EnumEntries : List |
| **Java** | Enum.values() | Array | Tight (flaw) | values() method |
| **OCaml** | (no std enum) | Seq.t | Loose | to_seq functions |

**Pattern emerges**: Languages with good module/layer separation (Rust, Haskell, C++20, OCaml) keep finiteness and collection semantics **loosely coupled or independent**. Languages with monolithic standard libraries (Kotlin, Java) accept tight coupling, with mixed results.

### Conclusions from Literature

1. **Orthogonal composition** (Rust, Haskell, C++) produces more flexible, maintainable systems.
2. **Tight coupling** (Java) can create design debt that's hard to fix.
3. **Sealed abstraction** (Kotlin) can work but requires stdlib ownership of both sides.
4. **Integration at use-site** (Haskell) or **via separate trait/protocol** (Rust) is the dominant pattern in well-layered systems.

For swift-primitives, which explicitly values layering and tier separation, the evidence strongly supports **Option B** — a join-point integration that keeps finite-primitives and collection-primitives independent at their cores.

### Academic Literature

**"A Semantics for Propositions as Sessions" (Wadler, 2012)**:
- Establishes that type-level dependencies should follow logical ordering
- "Smaller" concepts (propositions) should not depend on "larger" ones (sessions)

**"Algebra of Programming" (Bird & de Moor, 1997)**:
- Formalizes the relationship between algebraic structures and iteration
- Finite enumerable types form a category with natural iteration morphisms
- The iteration structure is intrinsic to finiteness, not to collection membership

---

## Theoretical Grounding

*Per [RES-022], Tier 2+ SHOULD include theoretical grounding.*

### Domain Analysis

Let **Finite** denote the category of finite enumerable types and **Collection** denote the category of indexed collections.

**Observation 1**: Finite ⊄ Collection and Collection ⊄ Finite
- Not all finite types are naturally indexed (e.g., finite groups)
- Not all collections are finite (e.g., lazy infinite streams)

**Observation 2**: There exists a functor F: Finite → Collection
- Every finite enumerable type can be viewed as a collection of its values
- This functor maps `T: Finite.Enumerable` to `Finite.Enumeration<T>: Collection`

**Observation 3**: The functor F is not identity-on-objects
- The collection structure is *derived*, not intrinsic
- The mapping requires additional machinery (ordinal indexing)

**Conclusion**: The integration "finite as collection" is a *derived relationship*, not a containment. This suggests a join-point rather than direct dependency.

### Type-Theoretic Analysis

```
Finite.Enumerable : Type → Prop
  where Enumerable(T) ≡ ∃n:ℕ. T ≅ Fin(n)

Collection.Protocol : Type → Prop
  where Protocol(C) ≡ ∃I:Type, E:Type. C has Index=I, Element=E, subscript: I→E

Finite.Enumeration : (T: Type) → Enumerable(T) → Type
  where Enumeration(T, pf) : Protocol with Index=ℕ, Element=T
```

The type `Finite.Enumeration<T>` is a *proof-carrying type* that witnesses:
1. T is enumerable (via Enumerable constraint)
2. The enumeration forms a collection (via Protocol conformance)

This witness lives at the intersection of both domains — precisely a join-point.

---

## Formal Semantics

*Per [RES-024], Tier 3 MUST include formal semantics.*

### Typing Rules

**Finite.Enumerable Formation**:
```
T : Type    count : ℕ    ordinal : T → Fin(count)    from_ordinal : Fin(count) → T
─────────────────────────────────────────────────────────────────────────────────
                           T : Finite.Enumerable
```

**Finite.Enumeration Formation**:
```
T : Finite.Enumerable
─────────────────────────
Finite.Enumeration<T> : Type
```

**Sequence Conformance** (in finite-primitives):
```
T : Finite.Enumerable
─────────────────────────────────────────
Finite.Enumeration<T> : Swift.Sequence
```

**Collection Conformance** (in join-point):
```
T : Finite.Enumerable
─────────────────────────────────────────────────────
Finite.Enumeration<T> : Collection.Protocol  [via extension]
```

### Operational Semantics

**Iteration (Sequence)**:
```
⟨Enumeration<T>.makeIterator(), σ⟩ → ⟨Iterator(index: 0), σ⟩

⟨Iterator(index: i).next(), σ⟩ → ⟨(T(ordinal: i), Iterator(index: i+1)), σ⟩  if i < T.count
⟨Iterator(index: i).next(), σ⟩ → ⟨nil, σ⟩                                      if i ≥ T.count
```

**Random Access (Collection)**:
```
⟨Enumeration<T>[i], σ⟩ → ⟨T(ordinal: i), σ⟩   if 0 ≤ i < T.count
```

### Soundness Argument

**Claim**: The join-point structure preserves type safety.

**Proof sketch**:
1. `finite-primitives` is self-contained: `Finite.Enumeration<T>` only requires `T: Finite.Enumerable`
2. `collection-primitives` is self-contained: `Collection.Protocol` has no finite-related constraints
3. The join-point adds an extension: `extension Finite.Enumeration: Collection.Protocol where Element: Finite.Enumerable`
4. This extension is *additive* — it cannot break existing code in either package
5. The extension witnesses are derivable from `Finite.Enumerable` requirements (count, ordinal)
6. Therefore, the extension is sound ∎

---

## Analysis

### Option A: Current Structure (finite → collection)

**Description**: `finite-primitives` depends on `collection-primitives` to provide `Collection` conformance for `Finite.Enumeration`.

**Structure**:
```
collection-primitives (Tier 10)
         ↑
finite-primitives (Tier 11)
         ↑
algebra-primitives (Tier 12)
         ↑
[20+ packages cascade upward]
```

**Advantages**:
- Simple: one package, one conformance
- Users import `Finite_Primitives` and get everything

**Disadvantages**:
- Tier inflation: algebra at Tier 12 instead of Tier 8-9
- Domain inversion: finite is conceptually simpler than collection
- Violates [SEM-DEP-006]: the collection conformance is incidental to finiteness

**SDG Analysis**: The relationship is **incidental**, not essential. Finite types don't *need* to be collections; they *can be viewed as* collections. Per SDG conventions, incidental relationships should not create direct dependencies.

---

### Option B: Join-Point Target in collection-primitives

**Description**: Create `Collection Finite Primitives` target within `collection-primitives` that depends on both `Collection Primitives` and `Finite Primitives`.

**Structure**:
```
finite-primitives (Tier 7-8)     collection-primitives/Collection Primitives (Tier 10)
         ↑                                          ↑
         └──────── Collection Finite Primitives ────┘
                          (Tier 11)
                              ↑
            [packages needing finite+collection integration]
```

**Package Changes**:
- `finite-primitives`: Remove collection dependency, keep `Finite.Enumeration` as `Swift.Sequence` only
- `collection-primitives`: Add `finite-primitives` dependency, create new target with Collection conformance extension

**Advantages**:
- Tier compression: algebra drops to Tier 8-9
- Correct domain ordering: finite is lower than collection integration
- Additive: doesn't remove functionality, relocates it

**Disadvantages**:
- Two imports for full functionality: `Finite_Primitives` + `Collection_Finite_Primitives`
- **Pollutes collection-primitives with non-essential dependency** — finite-primitives is not needed to implement Collection.Protocol
- Downstream packages depending on collection-primitives would transitively pull in finite-primitives even if they don't need it

**SDG Analysis**: While this follows [SEM-DEP-008] join-point resolution, it violates [SEM-DEP-009] integration package separation. Collection-primitives' dependencies should be essential to its core functionality. Adding finite-primitives as a dependency just to provide integration couples orthogonal concepts within the same package.

---

### Option C: Separate swift-finite-collection-primitives Package

**Description**: Create an entirely new package for the integration.

**Structure**:
```
finite-primitives (Tier 7-8)     collection-primitives (Tier 10)
         ↑                                ↑
         └─── swift-finite-collection-primitives ───┘
                       (Tier 11)
```

**Advantages**:
- Maximum separation of concerns
- Clear ownership of integration semantics
- Keeps collection-primitives dependencies essential to its core
- Follows [SEM-DEP-009] Integration Package Separation

**Disadvantages**:
- Package proliferation (112 packages → 113)
- Overhead of separate repository/submodule
- The integration is small (one file, ~100 lines)

**SDG Analysis**: This is the correct pattern per [SEM-DEP-009]. A package's dependencies must be essential to its own implementation. Collection-primitives does not need finite-primitives to define Collection.Protocol — the integration is orthogonal, not a refinement. Separate package is architecturally correct.

---

### Option D: Remove CaseIterable, Keep Enumeration as Sequence Only

**Description**: `Finite.Enumerable` no longer requires `CaseIterable`. `Finite.Enumeration` is `Sequence` only. No collection integration.

**Structure**:
```
finite-primitives (Tier 7)
         ↑
algebra-primitives (Tier 8)
```

**Advantages**:
- Maximum tier compression
- Simplest structure
- No integration complexity

**Disadvantages**:
- Breaking change: removes `CaseIterable` from `Finite.Enumerable`
- Loses random-access iteration (`for i in 0..<T.count { T.allCases[i] }`)
- Users must provide their own `CaseIterable` conformance

**SDG Analysis**: This is the "no edge" option. Valid if the collection relationship is truly incidental. However, `CaseIterable` is widely expected, making this a usability regression.

---

### Comparison

| Criterion | A: Current | B: Join-Point Target | C: Separate Pkg | D: No Integration |
|-----------|------------|---------------------|-----------------|-------------------|
| Tier compression | None | +3-4 tiers | +3-4 tiers | +4-5 tiers |
| SDG compliance ([SEM-DEP-008]) | ❌ Incidental dep | ✅ Join-point | ✅ Join-point | ✅ No edge |
| SDG compliance ([SEM-DEP-009]) | ❌ | ❌ Non-essential dep | ✅ Essential only | ✅ N/A |
| Domain ordering | ❌ Inverted | ✅ Correct | ✅ Correct | ✅ Correct |
| Package count | 111 | 111 | 112 | 111 |
| User ergonomics | ✅ Single import | ⚠️ Two imports | ⚠️ Two imports | ❌ Manual CaseIterable |
| Implementation cost | None | Low | Medium | Low |
| Breaking change | No | No | No | Yes |
| Dependency purity | ❌ | ❌ Pollutes collection | ✅ All essential | ✅ |

---

## Empirical Validation

*Per [RES-025], Tier 2+ for API-facing decisions SHOULD include Cognitive Dimensions analysis.*

### Cognitive Dimensions Framework

| Dimension | Option B (Join-Point Target) | Assessment |
|-----------|------------------------------|------------|
| **Visibility** | Integration is in collection-primitives, discoverable via package | Good |
| **Consistency** | Follows existing target-within-package pattern (e.g., Set Primitives Core/Sequence) | Good |
| **Viscosity** | Adding finite+collection code requires one additional import | Acceptable |
| **Role-expressiveness** | Target name "Collection Finite Primitives" clearly states purpose | Good |
| **Error-proneness** | Missing import produces clear "cannot find Collection.Protocol" error | Acceptable |
| **Abstraction** | Appropriate level — users choose whether they need collection conformance | Good |

**Overall**: Option B scores well on cognitive dimensions. The main cost is viscosity (extra import), mitigated by clear error messages.

---

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: **Option C — Separate swift-finite-collection-primitives Package**

**Rationale**:

1. **[SEM-DEP-009] Compliance**: A package's dependencies must be essential to its own implementation. Collection-primitives does not need finite-primitives to define `Collection.Protocol`. Adding it as a dependency to provide integration would pollute the package with non-essential dependencies.

2. **[SEM-DEP-008] Compliance**: Option C still follows join-point resolution — the integration semantics "finite types as collections" belongs in a dedicated join-point, not as a direct dependency from finite to collection.

3. **Domain Ordering**: Finite types are conceptually simpler than collections. The current dependency inverts this ordering. Option C restores correct ordering: finite (Tier 7-8) < collection (Tier 10) < integration (Tier 11).

4. **Tier Compression**: Reduces algebra from Tier 12 to Tier 8-9, cascading benefits to 20+ downstream packages.

5. **Dependency Purity**: Both finite-primitives and collection-primitives retain only essential dependencies. Downstream packages don't inherit unnecessary transitive dependencies.

6. **Literature Support**: Cross-language analysis (Rust, Haskell, C++, OCaml) confirms that orthogonal concepts should remain loosely coupled with integration at dedicated join-points.

7. **Minimal Disruption**: No breaking changes. Existing code continues to work; users just need an additional import for collection conformance.

**Package Proliferation Concern**: While this adds one package (112 → 113), this is a weak objection. The ecosystem already has 111 packages; one more for architectural correctness is justified. The integration is small but semantically distinct — exactly what a package should represent.

**Implementation Path**:

1. `finite-primitives`:
   - Remove `collection-primitives` from dependencies
   - Remove `@_exported import Collection_Primitives` from exports.swift
   - Keep `Finite.Enumeration` with `Swift.Sequence` conformance only
   - Keep default `allCases` returning `Finite.Enumeration<Self>`

2. Create `swift-finite-collection-primitives`:
   - New package at Tier 11
   - Depends on `finite-primitives` and `collection-primitives`
   - Single target `Finite Collection Primitives`
   - Add extension: `extension Finite.Enumeration: Collection.Protocol, Collection.Bidirectional, Collection.Access.Random`

3. Downstream:
   - `algebra-primitives`: No change needed (doesn't require collection conformance for basic algebra types)
   - Packages needing `Finite.Enumeration` as `Collection`: Add dependency on `swift-finite-collection-primitives`

---

## References

*Per [RES-026], Tier 3 MUST include traceable References section.*

### Swift Evolution
- SE-0194: Derived Collection of Enum Cases (CaseIterable)
- SE-0234: Package Manager Dependency Resolution

### Academic
- Wadler, P. (2012). "Propositions as Sessions." ICFP '12.
- Bird, R. & de Moor, O. (1997). *Algebra of Programming*. Prentice Hall.

### Language Documentation (Literature Study)
- Rust: [ExactSizeIterator in std::iter](https://doc.rust-lang.org/std/iter/trait.ExactSizeIterator.html)
- Haskell: [GHC.Enum](https://hackage.haskell.org/package/base/docs/GHC-Enum.html), [Data.Foldable](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Foldable.html)
- C++20: [Ranges library](https://en.cppreference.com/w/cpp/ranges.html), [C++20 Ranges Composition](https://www.cppstories.com/2022/ranges-composition/)
- Kotlin: [EnumEntries](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.enums/-enum-entries/), [KEEP enum-entries proposal](https://github.com/Kotlin/KEEP/blob/master/proposals/enum-entries.md)
- Java: [Memory-Hogging Enum.values()](https://dzone.com/articles/memory-hogging-enumvalues-method), [Baeldung: Enum Values to List](https://www.baeldung.com/java-enum-values-to-list)
- OCaml: [Seq Module](https://ocaml.org/manual/5.3/api/Seq.html), [Batteries BatEnum](https://ocaml-batteries-team.github.io/batteries-included/hdoc2/BatEnum.html)

### Internal
- [Semantic Dependencies](../Documentation.docc/Semantic%20Dependencies.md) — [SEM-DEP-006], [SEM-DEP-008], [SEM-DEP-009]
- [Primitives Tiers](../../swift-primitives/Documentation.docc/Primitives%20Tiers.md)
- [Primitives Layering](../../swift-primitives/Documentation.docc/Primitives%20Layering.md)

---

## Appendix A: Tier Recalculation

With Option B implemented:

| Package | Current Tier | New Tier | Δ |
|---------|--------------|----------|---|
| finite | 11 | 7 | -4 |
| algebra | 12 | 8 | -4 |
| bit | 13 | 9 | -4 |
| dimension | 13 | 9 | -4 |
| binary | 14 | 10 | -4 |
| time | 14 | 10 | -4 |
| cpu | 15 | 11 | -4 |
| ... | ... | ... | ... |

Total tier count: 20 → ~16 (estimated)

---

## Appendix B: Extension Code Sketch

```swift
// In swift-finite-collection-primitives/Sources/Finite Collection Primitives/

import Finite_Primitives
import Collection_Primitives

extension Finite.Enumeration: Collection.Protocol {
    public typealias Index = Int
    public typealias Element = Element  // from Finite.Enumeration generic param

    public var startIndex: Index { 0 }
    public var endIndex: Index { Element.count }

    public subscript(position: Index) -> Element {
        Element(__unchecked: (), ordinal: position)
    }

    public func index(after i: Index) -> Index { i + 1 }
}

extension Finite.Enumeration: Collection.Bidirectional {
    public func index(before i: Index) -> Index { i - 1 }
}

extension Finite.Enumeration: Collection.Access.Random {
    public var count: Int { Element.count }
    public func distance(from start: Index, to end: Index) -> Int { end - start }
    public func index(_ i: Index, offsetBy distance: Int) -> Index { i + distance }
}
```

## Appendix C: Package.swift Sketch

```swift
// swift-finite-collection-primitives/Package.swift

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-finite-collection-primitives",
    platforms: [
        .macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)
    ],
    products: [
        .library(name: "Finite Collection Primitives", targets: ["Finite Collection Primitives"])
    ],
    dependencies: [
        .package(path: "../swift-finite-primitives"),
        .package(path: "../swift-collection-primitives"),
    ],
    targets: [
        .target(
            name: "Finite Collection Primitives",
            dependencies: [
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
```
