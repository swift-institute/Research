# Sequence Operator Unification

<!--
---
version: 2.1.1
last_updated: 2026-02-25
status: RECOMMENDATION
---
-->

## Changelog

- **v2.1.1** (2026-02-25): Corrected ~Escapable iterator design — `@_lifetime(self: immortal)` on `next()` is the correct pattern (matches `Swift.Span.Iterator`), NOT removing ~Escapable from iterator protocol. Added V7-V9 (3 new variants). Total: 20/20 across 3 experiments.
- **v2.1.0** (2026-02-25): All experiments confirmed — 17/17 variants across 3 experiments. ~Escapable borrowing chain (6/6), compiler inlining (4/4, lazy matches hand-rolled within 2%), no remaining experiments.
- **v2.0.1** (2026-02-25): Promoted experiment results — 7/7 variants CONFIRMED. Dual conformance, ~Copyable chaining, and isolation preservation all validated.
- **v2.0.0** (2026-02-25): Reframed with ~Copyable-first design principle. Added lazy-by-default analysis. Added Rust/Kotlin prior art on lazy + move-only compatibility. New options F and G. Recommendation changed from "keep separate" to "lazy-by-default enables structural alignment and conditional sharing."
- **v1.0.0** (2026-02-25): Initial analysis concluding unification is not feasible. Preserved in full below.

## Context

We have concrete operator types in two places:

| Package | Layer | Operators | Evaluation | Protocol | ~Copyable |
|---------|-------|-----------|------------|----------|-----------|
| swift-sequence-primitives | 1 (Primitives) | Map, Filter, Reduce, ForEach, First, Contains, Satisfies, Count, Drop, Prefix, Drain, Span, Consume | **Eager** — return `[U]`, `Bool`, scalar | `Sequence.Protocol` (custom) | First-class |
| swift-async | 3 (Foundations) | Map, Filter, CompactMap, FlatMap | **Lazy** — return concrete `AsyncSequence` types | `AsyncSequence` (stdlib) | Not supported |

The async operators accept both sync and async closures via a Transform enum (see `isolation-preserving-entry-point-api.md`).

**Design principle**: ~Copyable is first-class, Copyable is second. This applies to both sync and async.

**Trigger**: After implementing sync-closure support in async operators, the question is whether the sync and async worlds can align or share — and whether the current eager evaluation in sequence-primitives is the right default given the ~Copyable-first principle.

## Questions

1. Can and should the concrete operator types be unified across sync and async?
2. Should sequence-primitives operators be lazy by default?
3. What is the value of alignment, even without full unification?

## The ~Copyable Constraint Audit

An audit of sequence-primitives reveals which operators require `Element: Copyable` and why:

| Operator | Copyable Required | Root Cause | Return Type |
|----------|-------------------|------------|-------------|
| **Map** | No | Borrows element, transforms to `U` | `[U]` |
| **Filter** | **Yes** | Copies matching elements into array | `[Element]` |
| **Drop** | **Yes** | Copies remaining elements into array | `[Element]` |
| **Prefix** | **Yes** | Copies taken elements into array | `[Element]` |
| **First** | Implicit* | `Optional<Element>` requires Copyable (SE-0427) | `Element?` |
| **Reduce** | No | Borrows elements, returns accumulator | `Result` |
| **ForEach** | No | Borrows or consumes elements in closure | `Void` |
| **Contains** | No | Borrows elements for predicate | `Bool` |
| **Satisfies** | No | Borrows elements for predicate | `Bool` |
| **Count** | No | Borrows elements, returns count | `Cardinal` |
| **CompactMap** | — | Not implemented | — |
| **FlatMap** | — | Not implemented | — |

*`First` has no explicit constraint but `Optional<Element>` imposes it implicitly.

**Key finding**: Every operator that requires `Element: Copyable` does so because it **collects results into an array**. The Copyable constraint is not inherent to the operation — it is an artifact of eager evaluation.

A lazy `Filter` that yields one element at a time would not need to copy into an array. The Copyable constraint vanishes.

## Analysis

### v1.0 Options (Preserved)

The v1.0 analysis evaluated five approaches assuming eager evaluation was fixed:

| Option | v1.0 Verdict | v2.0 Reassessment |
|--------|--------------|-------------------|
| A: Unified generic type (effect-polymorphic) | Not feasible (no HKT) | Still not feasible |
| B: Lazy sync types + shared protocol | Not valuable (no consumer) | **Reframed as Option F** — valuable when ~Copyable is the goal |
| C: Shared namespace, separate types | Harmful (violates layering) | Still harmful |
| D: Functor/monad abstraction layer | Not possible (no HKT) | Still not possible |
| E: Keep separate, document relationship | Recommended | Insufficient — does not address the Copyable constraint |

The v1.0 conclusion that "eager vs lazy is a fixed constraint" was wrong. Eager evaluation is a **choice** that actively works against the ~Copyable-first principle. v2.0 addresses this.

### Option F: Lazy-by-Default Sync Operators

Make sequence-primitives operators return lazy intermediate types instead of arrays:

```swift
// Current (eager): returns [U], requires iteration + allocation
source.map { $0 * 2 }        // → [Int]
source.filter { $0 > 5 }     // → [Int], requires Element: Copyable

// Proposed (lazy): returns intermediate type, zero allocation
source.map { $0 * 2 }        // → Sequence.Map<Source, Int>
source.filter { $0 > 5 }     // → Sequence.Filter<Source>
```

**Why this removes the Copyable constraint**:

A lazy `Filter` does not collect results. It yields elements one at a time from `next()`:

```swift
extension Sequence {
    struct Filter<Base: Sequence.Protocol>: Sequence.Protocol {
        let base: Base
        let predicate: (borrowing Base.Element) -> Bool

        struct Iterator: Sequence.Iterator.Protocol {
            var base: Base.Iterator
            let predicate: (borrowing Base.Element) -> Bool

            mutating func next() -> Base.Element? {
                while let e = base.next() {
                    if predicate(e) { return e }  // yield, not copy
                }
                return nil
            }
        }
    }
}
```

No array. No copy. `Element: Copyable` constraint vanishes. Filter now works with ~Copyable elements.

The same applies to Drop (skip N, then yield) and Prefix (yield N, then stop). All three operators that currently require Copyable would lose that constraint under lazy evaluation.

**Rust validates this**: Rust's `Iterator::filter` receives `&Self::Item` (borrow), not the owned value. It works with non-Copy, non-Clone types. Every Rust iterator adapter is lazy. This has been stable for 10+ years.

**Eager becomes a terminal operation**:

```swift
// Lazy pipeline, no Copyable constraint, zero allocation
let pipeline = source.filter { $0 > 5 }.map { $0 * 2 }

// Eager materialization — this is where Copyable appears
let array: [Int] = pipeline.collect()  // requires Element: Copyable

// But you often don't need to materialize:
pipeline.reduce.into(0) { $0 += $1 }  // no array, no Copyable needed
pipeline.forEach { process($0) }       // no array, no Copyable needed
pipeline.first { $0 > 20 }            // stops early, no Copyable needed
```

**Advantages**:
- Removes Copyable constraint from Filter, Drop, Prefix — directly supports ~Copyable-first
- Zero-allocation chaining: `source.filter { }.map { }.first { }` produces no intermediate arrays
- Short-circuit evaluation: `first`, `contains`, `prefix` stop early
- Compiler can inline the entire pipeline (concrete types with known layout)
- Aligns structural shape with async operators (both return concrete intermediate types)
- Enables sharing with async operators (see Option G)

**Disadvantages**:
- Lazy types borrow the base, creating lifetime dependencies. For ~Copyable bases, the lazy operator is ~Escapable (can't outlive the base). But this aligns with how ~Copyable already works — `Sequence.Borrowing.Protocol` is already `~Escapable`.
- More complex type signatures in return position: `Sequence.Filter<Sequence.Map<Source, Int>>` instead of `[Int]`
- Developers accustomed to eager `.filter` returning arrays must learn the new model

**Lifetime model**:

| Iteration Mode | Lazy Operator Lifetime | Precedent |
|----------------|----------------------|-----------|
| Borrowing (`for x in source.filter { }`) | ~Escapable, borrows base | `Sequence.Borrowing.Protocol` |
| Consuming (`source.consume().filter { }`) | Owns base, no lifetime dependency | `Sequence.Consume.Protocol` |
| Collecting (`source.filter { }.collect()`) | Transient — pipeline consumed during collect | Rust `Iterator::collect()` |

### Option G: Lazy Sync Types with Conditional Async Conformance

Build on Option F. Define lazy operator types at Layer 1 (sequence-primitives). Add `AsyncSequence` conformance at Layer 3 (swift-async) via conditional conformance:

```swift
// Layer 1: Sequence.Map defined, conforms to Sequence.Protocol
extension Sequence {
    struct Map<Base, Input, Output> {
        let base: Base
        let transform: (Input) -> Output
    }
}

extension Sequence.Map: Sequence.Protocol
    where Base: Sequence.Protocol, Base.Element == Input
{
    struct Iterator: Sequence.Iterator.Protocol {
        var base: Base.Iterator
        let transform: (Input) -> Output
        mutating func next() -> Output? {
            base.next().map(transform)
        }
    }
}

// Layer 3: Same type gains AsyncSequence conformance
extension Sequence.Map: AsyncSequence
    where Base: AsyncSequence, Base.Element == Input
{
    typealias Element = Output
    struct AsyncIterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        let transform: (Input) -> Output
        mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async -> Output? {
            guard let e = try? await base.next(isolation: actor) else { return nil }
            return transform(e)
        }
    }
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), transform: transform)
    }
}
```

One struct definition. Two iterator types. Conformances added at appropriate layers. The sync closure `(Input) -> Output` is identical in both paths.

**What this achieves**:

| Property | Status |
|----------|--------|
| Single type for the concept "map" | Yes — `Sequence.Map<Base, Input, Output>` |
| ~Copyable support | Yes — no array materialization |
| Sync iteration | Yes — via `Sequence.Protocol` conformance (Layer 1) |
| Async iteration with isolation | Yes — via `AsyncSequence` conformance (Layer 3) |
| Layering compliance | Yes — Layer 1 defines type, Layer 3 adds async conformance |
| Zero-allocation chaining | Yes — both sync and async pipelines |

**What this does NOT cover**:

The async-closure path `(Element) async -> Output` has no sync counterpart. For async closures, the async module would still need either:
- A separate `Async.Map` type (current design) for the async-closure case, or
- An `Async.Map` that wraps `Sequence.Map` and adds the Transform enum

This means the sync-closure path is shared, the async-closure path is async-only. That's a natural split — sync closures are the common case (and the one that wins overload resolution).

**Separate iterators is correct**: A single type cannot conform to both `IteratorProtocol` and `AsyncIteratorProtocol`. But a single *sequence* type can have two nested iterator types, one for each protocol. This is not a workaround — it's the correct design. The iteration mechanism differs; the data and transform do not.

### Comparison (v2.0)

| Criterion | E: Keep Separate | F: Lazy-by-Default (Separate) | G: Lazy + Conditional Sharing |
|-----------|-----------------|------------------------------|-------------------------------|
| ~Copyable support | Split (sync yes, async no) | Full for sync | Full for sync; async via same type |
| Copyable constraint on Filter/Drop/Prefix | Remains (eager) | Removed (lazy) | Removed (lazy) |
| Zero-allocation chaining | Async only | Both sync and async | Both sync and async |
| Shared type definition | No | No | Yes (sync-closure path) |
| Layering compliance | Clean | Clean | Clean (Layer 3 adds conformance) |
| Async-closure support | Async-only type | Async-only type | Async-only type (separate) |
| Complexity | Lowest | Moderate | Moderate-high |
| Breaking change to sequence-primitives | None | Significant (eager → lazy) | Significant (eager → lazy) |

## Prior Art

### v1.0 Prior Art (type separation)

| Language | Approach | Outcome |
|----------|----------|---------|
| Swift stdlib | `LazyMapSequence` and `AsyncMapSequence` completely separate | Precedent for separation |
| Rust | `Iterator::map` and `Stream::map` different traits, different types | Precedent for separation |
| Kotlin | `Sequence.map` and `Flow.map` independent | Precedent for separation |
| Haskell | `fmap` for all Functors via HKT | Only possible with HKT |
| Scala | Cats `Functor[F[_]]` via HKT | Only possible with HKT |

### v2.0 Prior Art (lazy-by-default + move-only)

| Language | Lazy Default? | Move-Only Support | Key Design |
|----------|--------------|-------------------|------------|
| **Rust** | Yes — all iterator adapters are lazy | Full — `filter` borrows (`&Item`), `map` takes ownership (`Item`). No Copy/Clone needed. | Transforming adapters consume, inspecting adapters borrow. `collect()` is the materialization terminal. Stable 10+ years. |
| **Kotlin** | `Sequence` is lazy, `List` is eager | N/A (no move-only types) | `asSequence()` converts eager to lazy. Terminal operations (`toList()`, `fold()`, etc.) materialize. |
| **Swift stdlib** | `LazySequence` is lazy (opt-in via `.lazy`), default is eager | No ~Copyable support | `Array.map` is eager, `Array.lazy.map` is lazy. Two separate APIs. |
| **Haskell** | Everything is lazy | N/A (GC, no ownership) | Laziness is the default. `seq`/`deepSeq` force evaluation. |

**Rust is the critical prior art**: It proves that lazy iterator adapters and move-only types are fully compatible when you:

1. **Transforming adapters** (`map`, `flat_map`, `filter_map`) — take ownership of each element, transform, produce new value. No Copy needed because each element flows through exactly once.
2. **Inspecting adapters** (`filter`, `take_while`, `skip_while`, `inspect`) — borrow via `&Self::Item`. No Copy needed because the element is observed but not consumed by the predicate.
3. **Materialization** (`collect()`, `fold()`, `for_each()`) — terminal operations that consume the pipeline.

This maps directly to Swift's ownership model: `borrowing` for inspecting adapters, consuming/owned for transforming adapters.

### Rust's Adapter Ownership Model Applied to Swift

| Rust Adapter | Rust Receives | Swift Equivalent | Swift Closure |
|--------------|---------------|------------------|---------------|
| `map` | `Item` (owned) | `Sequence.Map` | `(consuming Element) -> Output` |
| `filter` | `&Item` (borrow) | `Sequence.Filter` | `(borrowing Element) -> Bool` |
| `flat_map` | `Item` (owned) | `Sequence.FlatMap` | `(consuming Element) -> Segment` |
| `filter_map` | `Item` (owned) | `Sequence.CompactMap` | `(consuming Element) -> Output?` |
| `take_while` | `&Item` (borrow) | `Sequence.Prefix` | `(borrowing Element) -> Bool` |
| `skip_while` | `&Item` (borrow) | `Sequence.Drop` | `(borrowing Element) -> Bool` |

This separation — consuming for transforms, borrowing for predicates — is exactly how sequence-primitives already models closures (e.g., `Sequence.Filter` takes `(borrowing Base.Element) -> Bool`). The pattern is already in place; only the evaluation strategy (eager → lazy) needs to change.

## Theoretical Grounding

The sync/async distinction is an instance of **effect polymorphism**. Map, Filter, CompactMap, and FlatMap are natural transformations on functors (or monads) that are independent of the computational effect (sync, async, throwing, etc.).

In category theory terms:
- `Sequence` and `AsyncSequence` are both endofunctors on the category of Swift types
- `map` is a natural transformation preserving functor structure
- `flatMap` is the monadic bind
- `filter` is the MonadPlus `mzero`/`mplus` guard

Swift cannot express effect polymorphism (no HKT, no effect system). But it CAN express the shared structure through **conditional conformance**: one type, multiple protocol conformances depending on the base type's capabilities. This is Swift's closest approximation to effect polymorphism — and it's sufficient for the sync-closure case.

## Outcome

**Status**: RECOMMENDATION

### Primary Recommendation: Lazy-by-Default (Option F)

Sequence-primitives operators that produce sequences (Map, Filter, CompactMap, FlatMap, Drop, Prefix) should return lazy intermediate types, not arrays.

**Rationale**: Eager evaluation forces `Element: Copyable` on Filter, Drop, and Prefix. This directly contradicts the ~Copyable-first design principle. Lazy evaluation removes this constraint, enables zero-allocation chaining, and aligns the structural shape with async operators. Every major language with ownership semantics (Rust) uses lazy iteration by default.

Eager materialization becomes a terminal operation (`.collect()`) where the Copyable constraint naturally belongs — at the boundary where elements must be copied into a container, not at every intermediate step.

### Secondary Recommendation: Conditional Async Conformance (Option G)

Once lazy sync types exist, add `AsyncSequence` conformance at Layer 3 for the sync-closure path. This shares the type definition without violating layering.

**Rationale**: The sync closure `(Element) -> Output` is identical in both sync and async paths. A single `Sequence.Map<Base, Input, Output>` type can serve both via conditional conformance, with separate iterator types for sync and async. The async-closure path `(Element) async -> Output` remains async-only — this is a natural split, not a compromise.

### What This Does NOT Recommend

- Unifying async-closure operators with sync operators (impossible — different closure types)
- Shared protocols for operator types (no consumer exists)
- HKT or effect polymorphism (language doesn't support it)
- Removing eager operations (they remain as `.collect()` and similar terminals)

### Implementation Sequence

1. **Design lazy intermediate types** for sequence-primitives (Sequence.Map, Sequence.Filter, etc.) with ~Copyable + ~Escapable support
2. **Add terminal operations** (`.collect()`, or integrate with existing `.reduce`, `.forEach`, `.first`)
3. **Migrate existing eager operators** to convenience methods that chain lazy + collect
4. **Add `AsyncSequence` conformance** at Layer 3 via conditional conformance on shared types
5. **Evaluate whether `Async.Map` can be replaced** by `Sequence.Map` + async conformance for the sync-closure path, keeping a separate type only for async closures

### Experiment Results

Validated by `Experiments/lazy-sequence-operator-unification/` (2026-02-25, Apple Swift 6.2.3). All 7 variants CONFIRMED:

| Claim | Variant | Result |
|-------|---------|--------|
| Dual conformance: one type conforms to both `SyncSequence` and `AsyncSequence` | V1-sync, V1-async | **CONFIRMED** — `Mapped<Base, Input, Output>` iterates correctly via both paths |
| Chained dual conformance: `filter(map(...))` works for both sync and async | V1b-sync, V1b-async | **CONFIRMED** — `Filtered<Mapped<...>>` chains correctly in both modes |
| ~Copyable container with lazy map (consuming chain) | V2 | **CONFIRMED** — `Mapped<NCSequence, Int, Int>` works with ~Copyable base |
| ~Copyable container with chained lazy operators | V2b | **CONFIRMED** — `Filtered<Mapped<NCSequence, ...>>` chains with ~Copyable base |
| Async isolation preservation through shared type | V6 | **CONFIRMED** — sync closure in shared type preserves @MainActor isolation via `next(isolation:)` |

Feature flags required: `SuppressedAssociatedTypes`, `SuppressedAssociatedTypesWithDefaults`, `Lifetimes`, `LifetimeDependence`, `NonisolatedNonsendingByDefault`.

Validated by `Experiments/escapable-lazy-sequence-borrowing/` (2026-02-25, Apple Swift 6.2.3). All 9 variants CONFIRMED:

| Claim | Variant | Result |
|-------|---------|--------|
| ~Escapable struct with `@_lifetime(borrow)` | V1 | **CONFIRMED** — basic lifetime machinery works |
| Protocol with ~Copyable & ~Escapable suppression | V2 | **CONFIRMED** — Copyable types conform to suppressed protocol |
| ~Escapable consuming lazy map with iteration | V3 | **CONFIRMED** — `EscMapped` conforms to `EscSequence`, iterates correctly |
| Chained ~Escapable operators | V4 | **CONFIRMED** — `EscFiltered<EscMapped<...>>` composes |
| for-in desugaring with inline ~Escapable temporary | V5 | **CONFIRMED** — temporary consumed by `makeIterator()` within scope |
| `@_lifetime(borrow self)` extension returns ~Escapable | V6 | **CONFIRMED** — borrowing method returns scoped adapter |
| ~Escapable iterator with `@_lifetime(self: immortal)` | V7 | **CONFIRMED** — matches `Swift.Span.Iterator` pattern |
| ~Escapable lazy map with ~Escapable iterator | V8 | **CONFIRMED** — full ~Escapable design for lazy operators |
| Chained full ~Escapable operators + iterators | V9 | **CONFIRMED** — `FullEscFiltered<FullEscMapped<...>>` composes |

**Correct design**: Both sequence AND iterator protocols suppress `~Escapable`. `@_lifetime(self: immortal)` on `mutating func next()` tells the compiler the mutation is a pure state transition — the returned element doesn't borrow self. This matches `Swift.Span.Iterator` and `Sequence.Iterator.Borrowing.Protocol` in sequence-primitives.

**`@_lifetime(copy self)` on `consuming func makeIterator()`**: Valid for ~Escapable conformers. Escapable conformers MUST omit the annotation ("invalid lifetime dependence on Escapable value with consuming ownership"). The protocol declares it for the ~Escapable case.

Validated by `Experiments/lazy-pipeline-release-mode/` (2026-02-25, Apple Swift 6.2.3). All 4 variants CONFIRMED:

| Claim | Variant | Result |
|-------|---------|--------|
| Lazy pipeline correctness | V1 | **CONFIRMED** — identical results to hand-rolled |
| Eager pipeline correctness | V2 | **CONFIRMED** — identical results |
| Hand-rolled loop correctness | V3 | **CONFIRMED** — baseline |
| Compiler inlines lazy pipelines | V4 | **CONFIRMED** — lazy 5.0ms, hand-rolled 4.9ms, eager 34ms (release, 10M elements) |

Lazy matches hand-rolled within 2%. Eager (stdlib `.map`/`.filter` with intermediate arrays) is **7x slower**. The compiler fully eliminates lazy intermediate type overhead in `-O` mode.

### No Experiments Remaining

All three originally listed experiments are now confirmed. The consuming chain, ~Escapable chain, and compiler inlining all work as hypothesized.

## References

- `Experiments/lazy-sequence-operator-unification/` — dual conformance + ~Copyable (7/7 CONFIRMED)
- `Experiments/escapable-lazy-sequence-borrowing/` — ~Escapable composition + borrowing (9/9 CONFIRMED)
- `Experiments/lazy-pipeline-release-mode/` — compiler inlining (4/4 CONFIRMED, lazy = hand-rolled in -O)
- `isolation-preserving-entry-point-api.md` — async operator Transform enum design
- `stream-isolation-preserving-operators.md` — why concrete async types exist
- `parser-combinator-algebraic-foundations.md` — prior analysis of algebraic abstractions
- `sequence-iterator-borrowing-primitive.md` — borrowing iteration design in sequence-primitives
- SE-0421 — `next(isolation:)` on `AsyncIteratorProtocol`
- SE-0427 — Noncopyable generics
- SE-0298 — Async/Await: Sequences (established AsyncSequence as parallel to Sequence)
- Rust `Iterator` trait — lazy-by-default, non-Copy support via ownership/borrowing split
- Kotlin `Sequence` — lazy-by-default with `toList()` terminal
