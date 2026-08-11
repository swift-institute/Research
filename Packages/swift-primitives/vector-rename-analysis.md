# Vector Rename Analysis

<!--
---
version: 4.0.0
last_updated: 2026-02-08
status: DECISION
tier: 2
---
-->

## Context

The range-lazy-semantic-identity research (v2.0.0, RECOMMENDATION) concluded that `Range.Lazy` should keep its name despite the mathematical analysis pointing to "Vector" as the precise identity. An adversarial critique (external review) identified this as status quo bias — the document's own strongest findings contradict its recommendation:

1. **Internalist naming**: "Range provides all structure" names the type by its internal mechanism (integer domain), not by what users interact with (an indexed collection of values). This is like naming a HashMap "IntArray.Lazy" because it's backed by an array of hash buckets.

2. **Unargued rejection of Vector**: The claim that "Vector is pragmatically wrong for Swift" due to SIMD confusion was asserted without evidence. No user study, no API audit, no precedent showing actual confusion.

3. **Status quo bias**: The recommendation keeps Range.Lazy not because the analysis supports it, but because it already exists. Every analytical dimension (mathematical, prior art, structural) points away from "Range."

4. **Contradicts its own findings**: The five-way comparison shows Vector as the exact mathematical match. The prior art survey shows every ecosystem that independently names this concept uses "Vector" or "Tabulate." Then the recommendation keeps "Range."

This document takes the critique seriously and investigates: what would a Vector-based rename actually look like? What are the concrete costs, benefits, and architectural implications?

### Trigger

[RES-001] Architecture choice prompted by adversarial critique of range-lazy-semantic-identity.md. User is leaning toward Vector.

### Scope

[RES-002a] Primitives-wide — affects range-primitives (Tier 9), vector-primitives (Tier 10), and 9 dependent packages. Tier 2 per [RES-020]: affects multiple packages, reversible with effort but establishes naming precedent.

### Inputs

- `Research/range-lazy-semantic-identity.md` v2.0.0 — prior art and mathematical identity
- `Research/vector-primitives-role-and-dependency-analysis.md` — vector-primitives role analysis
- `Research/zip-primitive-placement.md` v2.0.0 — zip lives with the functor
- External adversarial critique (8 points) of the semantic identity research
- `swift-range-primitives/Experiments/parallel-iteration-test/` — 17/19 CONFIRMED
- Structural comparison of `Vector<Element, N>` vs array-primitives types

## Question

What would renaming `Range.Lazy<Bound>` to a Vector-based name look like? What are the concrete options, costs, and recommended path?

## The Two "Vector" Concepts

The primitives ecosystem currently has two distinct concepts that map to "vector":

| Aspect | `Range.Lazy<Bound>` | `Vector<Element, N>` |
|--------|---------------------|---------------------|
| Package | swift-range-primitives (Tier 9) | swift-vector-primitives (Tier 10) |
| Structure | `(count, transform: Index -> Bound)` | `Buffer<Element>.Linear.Bounded` |
| Size | Runtime (`count: Count`) | Compile-time (`let N: Int`) |
| Storage | None — computed on demand | Heap, copy-on-write |
| ~Copyable | Full support (`Bound: ~Copyable`) | Full support (`Element: ~Copyable`) |
| Consumers | 9 external packages, 271 references | 0 active consumers |
| Math identity | `Vec n A = Fin n -> A` (functional) | `Vec N A` (stored) |

In dependent type theory, these are two **representations** of the same concept:

- **Stored (push) vector**: `data Vec : Nat -> Set -> Set where [] : Vec 0 A; _::_ : A -> Vec n A -> Vec (n+1) A`
- **Functional (pull) vector**: `Vector A n = Fin n -> A`

Agda's standard library has both: `Data.Vec` (stored, inductive) and `Data.Vec.Functional` (pull, functional). Haskell's `vec` package has `Data.Vec.Lazy` (stored) and `Data.Vec.Pull` (functional). The isomorphism is witnessed by `tabulate`/`index`.

**Key insight**: These two types are not in conflict. They are representations of the same mathematical object. Both rightfully belong under a "Vector" umbrella.

### The Stored Vector and array-primitives Overlap

The stored `Vector<Element, N>` is structurally similar to existing array-primitives types:

| Stored Vector | Array Equivalent | Shared Properties |
|--------------|-----------------|-------------------|
| `Vector<Element, N>` (heap, CoW) | `Array.Fixed<Element>` (heap, CoW) | Fixed count, fully initialized, ~Copyable elements, span access |
| `Vector<Element, N>.Inline` (stack) | `Array.Static<Element, capacity>` (stack) | Inline storage, fixed capacity, ~Copyable elements |

**Key differences**: Vector uses compile-time `N` with `Algebra.Z<N>` indexing (preventing invalid indices at compile time). Array types use runtime counts with `Index<Element>` and runtime bounds checking. Vector does NOT conform to Collection/Sequence; Array types do. Vector uses Buffer primitives; Array uses Storage primitives.

**Implication**: The stored vector's unique contribution is compile-time dimension safety. Everything else — heap CoW, inline storage, ~Copyable support, span access — already exists in array-primitives. The stored vector concept is largely covered by the array family, especially as array-primitives matures through planned refactoring.

This is significant for the architectural question: the stored vector does not require dedicated package-level infrastructure. Its functionality is subsumed by array-primitives plus (potentially) compile-time-N indexing extensions. The "Vector" package name is free to serve the functional representation — the concept that genuinely HAS no equivalent elsewhere in the ecosystem.

## The Type Name: `Vector<Bound>` — Not `Vector.Lazy<Bound>`

### Why Not a Namespace Enum

The v1.0 and v2.0 drafts assumed a namespace enum pattern:

```swift
public enum Vector {}
extension Vector {
    public struct Lazy<Bound: ~Copyable> { ... }  // nested under namespace
    public enum ForEach {}   // non-generic tag
    public enum Drain {}     // non-generic tag
}
```

This was motivated by the concern that a generic `Vector<Bound>` would force nested types to inherit the `<Bound>` parameter. But this pattern already exists throughout the ecosystem and is not a problem.

### Why `Vector<Bound>` Works

With `Vector<Bound>` as a generic struct:

```swift
public struct Vector<Bound: ~Copyable>: ~Copyable {
    public var start: Vector<Bound>.Index
    public var end: Vector<Bound>.Index
    public var count: Vector<Bound>.Index.Count
    let transform: @Sendable (Vector<Bound>.Index) -> Bound

    public enum ForEach {}
    public enum Drain {}
    public enum Error: Swift.Error, Hashable, Sendable { ... }
    public typealias Index = Index_Primitives.Index<Vector>
}
```

**Nested types inheriting `<Bound>` is a feature, not a problem:**

- `Vector<Bound>.ForEach`, `Vector<Bound>.Drain`, `Vector<Bound>.Error` — the generic parameter is carried but unused. This pattern already exists in the ecosystem.
- `Vector<Bound>.Index` = `Index<Vector<Bound>>` — the generic parameter provides **stronger phantom typing**. Each `Vector<A>` has its own index type, preventing accidental cross-vector index misuse.

### Phantom-Typed Indices: A Feature

Under the old `Range.Lazy` design:

```swift
var a: Range.Lazy<Index<Node>>   // a.start is Range.Index = Index<Range>
var b: Range.Lazy<Index<Edge>>   // b.start is Range.Index = Index<Range> — SAME type
// Nothing prevents mixing positions from a into b
```

Under `Vector<Bound>`:

```swift
var a: Vector<Index<Node>>   // a.start is Index<Vector<Index<Node>>>
var b: Vector<Index<Edge>>   // b.start is Index<Vector<Index<Edge>>> — DIFFERENT types
// Type system prevents accidental cross-vector position misuse
```

This is phantom typing doing what it's designed to do. Cross-vector operations like `zip` use `retag()` at the boundary — the same mechanism already used throughout the ecosystem for cross-domain index conversion:

```swift
func zip<A: ~Copyable, B: ~Copyable>(
    _ a: Vector<A>, _ b: Vector<B>
) -> Vector<Pair<A, B>> {
    let count = min(a.count.vector, b.count.vector)
    return Vector<Pair<A, B>>(count: count) { position in
        Pair(a.transform(position.retag()), b.transform(position.retag()))
    }
}
```

The `..<` operator uses the same pattern:

```swift
public func ..< <Tag: ~Copyable>(
    lhs: Index<Tag>, rhs: Index<Tag>.Count
) -> Vector<Index<Tag>> {
    let start: Vector<Index<Tag>>.Index = lhs.retag()
    let end: Vector<Index<Tag>>.Index = rhs.map(Ordinal.init).retag()
    return Vector<Index<Tag>>(
        __unchecked: (),
        start: start,
        end: end,
        transform: { $0.retag() }
    )
}
```

### Naming Comparison

| Name | Pros | Cons |
|------|------|------|
| **`Vector<Bound>`** | The mathematical name (`Vec n A`); simplest; no namespace indirection; stronger phantom-typed indices; matches Agda's `Vector A n` | — |
| `Vector.Lazy<Bound>` | Signals "not stored"; accommodates future `Vector.Stored` | Requires namespace enum; weaker index typing; the `.Lazy` suffix is an implementation detail, not an identity |
| `Vector.Tabulate<Bound>` | Scala precedent | Names construction, not identity; requires namespace enum |
| `Vector.Functional<Bound>` | Agda precedent | "Functional" overloaded; requires namespace enum |
| `Vector.Pull<Bound>` | Haskell precedent | Jargon; requires namespace enum |

**Recommended**: **`Vector<Bound>`**. It is the mathematically correct name. The type IS a vector — `Vec n A = Fin n -> A`. Adding `.Lazy` would be an implementation qualifier on top of an identity, like naming Array "Array.Stored". The absence of stored elements is communicated by the doc comment and by the type's API (no subscript set, no append, no storage-related operations).

## Option Analysis

### Option A: Rename in-place — `Range.Lazy` → `Vector<Bound>` within range-primitives

**Description**: Replace the `Range` namespace enum with a generic `Vector<Bound>` struct within swift-range-primitives. Package name unchanged.

**Advantages**:
- Minimal disruption: import statements across ecosystem don't change
- Package stays at Tier 9

**Disadvantages**:
- Package name (`range-primitives`) contradicts type name (`Vector`)
- Half-measure

### Option B: Rename package — swift-range-primitives → swift-vector-primitives

**Description**: Full rename. The current swift-vector-primitives is eliminated. swift-range-primitives is renamed to swift-vector-primitives.

**Advantages**:
- Complete alignment: package name, module name, and type name all say "Vector"

**Disadvantages**:
- 10 Package.swift files need dependency path changes
- 45 source files need import changes
- No deprecation path — all 9 consumers break simultaneously

### Option E: Repurpose vector-primitives for `Vector<Bound>`, deprecate range-primitives

**Description**: Gut the current swift-vector-primitives — remove the stored `Vector<Element, N>` and all its heavy dependencies (buffer, algebra-modular, equation, hash). Replace with `Vector<Bound>` and its lightweight dependencies (index, cyclic, property, sequence). Deprecate swift-range-primitives as a thin re-export shim.

The lazy/functional variant is more fundamental than the stored variant:
- **Lower tier**: `Vector<Bound>` needs Tier 9 dependencies; stored Vector needs Tier 15+ (buffer-primitives)
- **More consumers**: 9 packages depend on Range.Lazy; 0 depend on stored Vector
- **Fewer dependencies**: 4 lightweight packages vs 5 heavy packages
- **Unique concept**: `Vector<Bound>` has no equivalent elsewhere in the ecosystem; stored Vector overlaps with array-primitives

The functional variant should own the name and the package.

**Concrete changes to swift-vector-primitives**:

| Current | New |
|---------|-----|
| Dependencies: buffer, algebra-modular, index, equation, hash | Dependencies: index, cyclic, property, sequence |
| Tier: 10 | Tier: 9 (drops) |
| Primary type: `Vector<Element, N>` (stored) | Primary type: `Vector<Bound>` (functional) |
| Modules: Vector Primitives Core, Vector Fixed, Vector Inline, umbrella | Modules: Vector Primitives Core, Vector Primitives, Vector Primitives Standard Library Integration |
| Consumers: 0 | Consumers: 9 (migrated from range-primitives) |

**Type mapping**:

| Current (Range) | New (Vector) |
|-----------------|--------------|
| `enum Range {}` | `struct Vector<Bound: ~Copyable>: ~Copyable {}` |
| `Range.Lazy<Bound>` | `Vector<Bound>` |
| `Range.Index` = `Index<Range>` | `Vector<Bound>.Index` = `Index<Vector<Bound>>` |
| `Range.ForEach` | `Vector<Bound>.ForEach` |
| `Range.Drain` | `Vector<Bound>.Drain` |
| `Range.Error` | `Vector<Bound>.Error` |
| `Range.Lazy<Bound>.Iterator` | `Vector<Bound>.Iterator` |
| `Range.Lazy<Bound>.Reversed` | `Vector<Bound>.Reversed` |
| `(.zero..<count)` → `Range.Lazy<Index<Tag>>` | `(.zero..<count)` → `Vector<Index<Tag>>` |

**What happens to swift-range-primitives**:

Becomes a deprecated compatibility shim:

```swift
// swift-range-primitives/Sources/Range Primitives/exports.swift
@_exported public import Vector_Primitives

@available(*, deprecated, message: "Use Vector<Bound> from Vector_Primitives instead")
public enum Range {
    @available(*, deprecated, renamed: "Vector")
    public typealias Lazy<Bound: ~Copyable> = Vector<Bound>
}
```

Consumers migrate at their own pace. Once all consumers have migrated, the shim is removed.

**What happens to the stored `Vector<Element, N>`**:

The stored variant's functionality is largely covered by array-primitives (`Array.Fixed`, `Array.Static`). Its unique value — compile-time dimension safety via `Algebra.Z<N>` — is an indexing strategy, not a storage strategy. It could be an overlay on array-primitives rather than a separate container type.

| Path | When | Form |
|------|------|------|
| Archive | Default | Git history preserves the code. Reintroduce when needed. |
| Separate package | If a use case emerges | New package depending on vector-primitives + buffer-primitives. Tier 15+. |
| Array integration | During array-primitives refactoring | Add compile-time-N indexing as an extension to `Array.Fixed` or `Array.Static`. |

This is a provisional bet, not a final disposition. Compile-time dimension safety is a distinct and valuable abstraction. Re-introducing it later may be harder once the `Vector` name is taken by the functional representation. The assumption that array-primitives will absorb this responsibility is plausible but unproven. This decision is deferred to the array-primitives refactoring, and should be revisited explicitly at that time.

**Migration path**:

**Phase 1: Rebuild vector-primitives**
1. Archive current vector-primitives source (git preserves history)
2. Replace Package.swift: new dependencies (index, cyclic, property, sequence), new module structure
3. Create `Vector<Bound>` as a generic struct with nested ForEach, Drain, Error, Iterator, Reversed types
4. Port Range.Lazy logic to Vector, adapting index phantom typing
5. `swift build` to verify

**Phase 2: Create deprecation shim in range-primitives**
6. Update range-primitives Package.swift: add dependency on swift-vector-primitives
7. Replace source with re-export + deprecated typealiases
8. `swift build` to verify existing consumers compile unchanged

**Phase 3: Migrate consumers (9 packages)**
9. Update Package.swift: `swift-range-primitives` → `swift-vector-primitives`
10. Update imports: `Range_Primitives` → `Vector_Primitives`
11. Update type references: `Range.Lazy<T>` → `Vector<T>`, `Range.ForEach` → `Vector<T>.ForEach`, etc.
12. `swift build` each package

**Phase 4: Update research documents**
13. Update `zip-primitive-placement.md` references
14. Mark `range-lazy-semantic-identity.md` as SUPERSEDED
15. Update `_index.json`

**Phase 5: Verify**
16. `swift build` across all affected packages
17. `swift test` for vector primitives

### Comparison

| Criterion | A: Rename type | B: Rename package | E: Repurpose vector-primitives |
|-----------|---------------|-------------------|-------------------------------|
| Naming honesty | Partial (module says Range) | Complete | Complete |
| Migration effort | Low (16 files) | Medium (45+ files) | Medium (45+ files, phased) |
| Package.swift changes | 0 | 10 | 10 |
| Import statement changes | 0 | 45 | 45 |
| Type reference changes | 271 | 271 | 271 |
| Tier impact | None | None | Drops from 10 → 9 |
| Deprecation path | None | None | Yes (range-primitives becomes shim) |
| Stored vector fate | Unaddressed | Eliminated | Archived or separate package |
| Index phantom typing | Weak (shared Index<Range>) | Weak (shared Index<Vector>) | **Strong** (Index<Vector<Bound>>) |
| Naming contradiction | Module vs type | None | None |

## The `..<` Operator Question

The custom `..<` operator currently returns `Range.Lazy<Index<Tag>>`. Under the rename:

```swift
public func ..< <Tag: ~Copyable>(
    lhs: Index<Tag>, rhs: Index<Tag>.Count
) -> Vector<Index<Tag>>
```

**Does this read well?** Yes. The operator `..<` constructs a value from bounds. The result is a vector (indexed collection of values), not a range (interval of numbers). Saying "the range operator produces a vector" is like saying "the list literal `[1,2,3]` produces an Array" — the construction syntax is distinct from the result type.

Swift itself does this: `0..<10` returns `Range<Int>`, but `(0..<10).lazy.map(f)` returns `LazyMapSequence<Range<Int>, T>`. The construction syntax doesn't constrain the result type name.

## The SIMD Confusion Argument — Examined

The semantic identity research dismissed "Vector" with: "In Swift's ecosystem, 'Vector' strongly connotes SIMD/geometry." Let's test this claim:

**What Swift developers encounter as "Vector":**
- `SIMD2`, `SIMD3`, `SIMD4` — NOT named "Vector"
- `simd_float3`, `simd_double4` — NOT named "Vector"
- SwiftUI has no `Vector` type
- There is no `Vector` type in the Swift standard library
- Apple's Accelerate framework: `vDSP` (not Vector)
- GameplayKit: no Vector type
- Metal: `float2`, `float3`, `float4` — NOT named "Vector"

**The only "Vector" in Apple's Swift ecosystem**: `CGVector` (Core Graphics), a 2D displacement with `dx`/`dy`. This is a Foundation type — irrelevant to primitives (no Foundation imports).

**Verdict**: The SIMD/geometry confusion risk is lower than previously claimed, and acceptable given the gains. "Vector" does carry mathematical/geometric connotations for some developers, and `Vector<T>` without a dimension parameter may surprise those expecting numeric semantics. But Swift's own APIs do not use "Vector" for SIMD, and the confusion risk does not outweigh the correctness, type safety, and prior art alignment benefits of the rename.

## Addressing the Adversarial Critique

The critique raised 8 points. Here's how the recommended option addresses them:

| Critique Point | Resolution |
|---------------|------------|
| 1. Category theory ≠ naming criterion | Agreed. The recommendation is based on prior art + structural identity, not category theory alone. |
| 2. Prior art overfitted to exotic languages | The recommendation doesn't rest on exotic languages — it rests on the structural analysis and the fact that "Vector" is available in Swift. |
| 3. "Sequence is worst" overstated | Irrelevant — Sequence is already eliminated. |
| 4. Internalist naming | **Decisive.** `Vector<Bound>` names the type by what it IS (a vector — function from finite domain to values), not by internal mechanism (integer domain). |
| 5. Vector rejection unargued | See SIMD analysis — the concern is weaker than claimed. |
| 6. Status quo bias | Eliminated. The recommendation follows the analysis to its conclusion. |
| 7. Taxonomy vs usability | The architectural argument (type safety, tier reduction, prior art) is stronger than the ergonomic one. Whether `Vector<Bound>` is clearer than `Range.Lazy<Bound>` at call sites, in error messages, and in autocomplete is not fully demonstrated. But the architectural gains are sufficient — the usability case does not need to carry the conclusion alone. |
| 8. Contradicts own findings | Resolved. The rename follows the findings. |

## Outcome

**Status**: DECISION

### Decision

**Option E — Repurpose swift-vector-primitives for `Vector<Bound>`, deprecate swift-range-primitives as a compatibility shim.** Implemented 2026-02-08.

The type is `Vector<Bound: ~Copyable>` — a generic struct, not a nested type under a namespace enum.

### Rationale

1. **`Vector<Bound>` is the mathematically correct name.** The type IS `Vec n A = Fin n -> A`. Agda calls it `Vector A n`. No qualifier needed — a vector is a vector.

2. **No namespace enum needed.** Nested types inherit `<Bound>`, which is either harmless (ForEach, Drain, Error) or actively beneficial (Index gets phantom typing per Bound, preventing cross-vector position misuse).

3. **The functional variant should own the package.** Lower tier (9 vs 10), more consumers (9 vs 0), fewer dependencies (4 lightweight vs 5 heavy), unique concept (no equivalent elsewhere in the ecosystem). The stored variant's functionality overlaps with array-primitives.

4. **The SIMD confusion concern is weak.** Swift uses `SIMD*`, not `Vector`. `CGVector` is Foundation-only. The word is available.

5. **Deprecation provides a migration path.** `import Range_Primitives` keeps working; `Range.Lazy` keeps compiling with a deprecation warning. Consumers migrate at their own pace.

6. **Stronger type safety.** `Index<Vector<Index<Node>>>` and `Index<Vector<Index<Edge>>>` are different types — phantom typing prevents accidental cross-vector position misuse. The current `Index<Range>` is shared across all instances, providing no such safety.

### Cascade: What Else Changes

| Document/Decision | Impact |
|-------------------|--------|
| `zip-primitive-placement.md` | zip lives with the functor → still correct, now in vector-primitives |
| `parallel-iteration-primitives.md` | References change: `Range.Lazy` → `Vector<Bound>` |
| `range-lazy-semantic-identity.md` | Status → SUPERSEDED BY this document |
| `vector-primitives-role-and-dependency-analysis.md` | Status → SUPERSEDED — vector-primitives repurposed, not eliminated |
| `sequence-primitives-ecosystem-adoption.md` | References to Range.Lazy update |
| Plan: Pair ~Copyable + zip | Package target changes to vector-primitives |

### What Happens to `Range`

The `Range` namespace enum disappears from primitives. There is no residual need:
- The `..<` operator is a free function — no namespace required
- `Range.Index` → `Vector<Bound>.Index` (phantom-typed per instantiation)
- `Range.Error` → `Vector<Bound>.Error`
- `Range.ForEach` → `Vector<Bound>.ForEach`
- `Range.Drain` → `Vector<Bound>.Drain`

During the deprecation period, `Range.Lazy<T>` is a typealias to `Vector<T>` in the range-primitives shim.

If a future need arises for an explicit "range" type (an interval, not a function), it would be a different concept and a different package.

## References

- `Research/range-lazy-semantic-identity.md` v2.0.0 — mathematical identity and prior art
- `Research/vector-primitives-role-and-dependency-analysis.md` — vector-primitives role analysis
- `Research/zip-primitive-placement.md` v2.0.0 — zip placement with the functor
- `swift-range-primitives/Experiments/parallel-iteration-test/` — empirical validation
- Agda `Data.Vec.Functional`: `Vector A n = Fin n -> A`
- Haskell `Data.Vec.Pull`: `Vec n a = Fin n -> a`
- Scala `View.Tabulate`: `(n: Int, f: Int => A)`
- Gibbons, J. "APLicative Programming with Naperian Functors." ESOP 2017.

## Changelog

### v4.0.0 (2026-02-08)

- **Status changed**: RECOMMENDATION → DECISION. Implementation complete.
- **Implemented**: Option E fully executed. `Vector<Bound>` ported to swift-vector-primitives with inline nested types (ForEach, Drain, Error) per [PATTERN-022].
- **Implemented**: Deprecation shim in swift-range-primitives (`Range.Lazy<Bound> = Vector<Bound>`).
- **Implemented**: All 9 consumer packages migrated (Package.swift + source imports + type references).
- **Key design resolution**: `Index<Tag>` in `UnsafeRawBufferPointer`/`UnsafeMutableRawBufferPointer` extensions required full qualification as `Index_Primitives.Index<Tag>` to avoid name collision with stdlib's `BufferPointer.Index` typealias.
- **Verified**: vector-primitives builds and passes 106 tests. Range-primitives deprecation shim builds. Consumer packages that don't have pre-existing errors build successfully.

### v3.1.0 (2026-02-07)

- **Refined**: SIMD confusion argument — acknowledged residual geometric connotation risk while maintaining the conclusion is acceptable given gains.
- **Refined**: Usability vs architecture — acknowledged the architectural argument is stronger than the ergonomic one; the usability case does not need to carry the conclusion alone.
- **Refined**: Stored vector disposition — framed as provisional bet, not final. Compile-time dimension safety may be harder to reintroduce later. To be revisited during array-primitives refactoring.

### v3.0.0 (2026-02-07)

- **Type name changed**: `Vector.Lazy<Bound>` → `Vector<Bound>`. The type IS a vector; no `.Lazy` qualifier needed.
- **No namespace enum**: `Vector<Bound>` is a generic struct. Nested types inherit `<Bound>` — harmless for tags, beneficial for Index (phantom typing per Bound).
- **Added**: Phantom-typed index analysis — `Index<Vector<Bound>>` provides stronger type safety than shared `Index<Range>`.
- **Added**: zip implementation showing `retag()` at boundaries.
- **Updated**: Type mapping table, migration path, comparison table, adversarial critique responses.
- **Removed**: Options C and D (superseded by the simpler Vector<Bound> design).

### v2.0.0 (2026-02-07)

- **Recommendation changed**: Option B (hard rename) → Option E (repurpose vector-primitives, deprecate range-primitives)
- **Added**: Stored vector vs array-primitives overlap analysis
- **Added**: Architectural argument that lazy variant should own the package

### v1.0.0 (2026-02-07)

- Initial analysis. Recommended Option B (hard package rename) with `Vector.Lazy<Bound>`.
