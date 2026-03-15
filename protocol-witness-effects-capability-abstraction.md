# Protocol vs Witness vs Effects for Capability Abstraction

<!--
---
version: 1.0.0
last_updated: 2026-02-10
status: RECOMMENDATION
tier: 3
---
-->

## Context

During the migration of `swift-html-rendering` from `INCITS_4_1986` (Layer 2) to `swift-ascii` (Layer 3), a build failure exposed a fundamental design flaw in how capabilities are abstracted across the Swift Institute ecosystem.

`Parser.Protocol` (in `swift-parser-primitives`) and `Rendering.Protocol` (in `swift-renderable`) both declare `associatedtype Output`. When `String` conforms to both -- `String: Parser.Protocol` with `Output = Void` and `String: Renderable` with `Output = UInt8` -- the Swift compiler cannot resolve the conflicting typealias. A type can only have one `typealias Output`.

This is not a naming accident. It is a **structural limitation of protocol-based capability abstraction** that will recur whenever:

1. Two protocols share an associated type name, AND
2. A type conforms to both with different concrete types, AND
3. Both protocols appear in the same dependency graph (even transitively)

The problem is compounded by Swift's global coherence rule: protocol conformances are unique per type per process (SE-0364). Retroactive conformances on stdlib types (`String`, `Array`, `Int`) are inherently fragile because they occupy a global namespace that any transitive dependency can pollute.

**Trigger**: [RES-001] Design decision cannot be made without systematic analysis.
**Scope**: [RES-002a] Ecosystem-wide -- affects primitives (L1), standards (L2), foundations (L3), and components (L4).
**Tier justification**: [RES-020] Precedent-setting, normative, hard to undo, timeless infrastructure.

## Question

**Should the Swift Institute ecosystem replace protocol-based capability abstraction (where types conform to `Parser.Protocol`, `Rendering.Protocol`, etc.) with witness-based, effects-based, or hybrid approaches to avoid global coherence conflicts?**

Sub-questions:

1. What are the precise typing rules that make the current design unsound?
2. What alternatives exist, and how do they trade off coherence, flexibility, performance, and ergonomics?
3. Which alternative best fits the five-layer architecture's constraints?
4. What is the migration path from the current protocol-based design?

## Prior Art Survey

### Type-Theoretic Foundations

| Source | Year | Key Insight |
|--------|------|-------------|
| Wadler & Blott, "How to make ad-hoc polymorphism less ad hoc" (POPL 1989) | 1989 | Typeclasses are syntactic sugar over dictionary passing. The dictionary (witness) is the primary concept; implicit dispatch is a convenience layer. |
| Dreyer et al., "Modular Type Classes" (POPL 2007) | 2007 | ML modules strictly subsume typeclasses. Modules support multiple implementations, explicit parameterization, and first-class abstraction. Typeclasses add only implicit resolution, at the cost of global coherence. |
| Wehr & Chakravarty, "ML Modules and Haskell Type Classes" (APLAS 2008) | 2008 | Type-preserving translations in both directions prove modules are strictly more expressive. |
| Schrijvers et al., "COCHIS: Stable and Coherent Implicits" (JFP 2019) | 2019 | Local flexibility and coherence are compatible if resolution is deterministic (stack discipline) rather than search-based. Formal foundation for Scala 3's `given` instances. |

### Algebraic Effects

| Source | Year | Key Insight |
|--------|------|-------------|
| Plotkin & Power, "Algebraic Operations and Generic Effects" (2003) | 2003 | Effects as algebraic operations on free algebras. Interface/handler separation: handlers are local and composable, not global. |
| Plotkin & Pretnar, "Handlers of Algebraic Effects" (ESOP 2009) | 2009 | Effect handlers as structured interpreters. Multiple different interpretations of the same operation can coexist in the same program via lexical scoping. |
| Leijen, "Type Directed Compilation of Row-Typed Algebraic Effects" (POPL 2017) | 2017 | Row-typed effects compose without interference. Each handler addresses exactly its declared operations. |
| Lindley, McBride & McLaughlin, "Do Be Do Be Do" (POPL 2017) | 2017 | Frank language unifies functions and handlers. Ambient ability propagation eliminates explicit effect variables. |

### Language Implementations

| Language | Mechanism | Coherence | Flexibility | Limitation |
|----------|-----------|-----------|-------------|------------|
| Swift protocols | Global conformance | Enforced (SE-0364) | None (one per type) | Associated type collisions |
| Haskell typeclasses | Global instances | Assumed | Orphan instances (unsafe) | Silent coherence violations |
| Rust traits | Global impls | Enforced (orphan rule) | Newtype pattern (manual) | Boilerplate; ecosystem friction |
| Scala 3 `given` | Scope-based | Deterministic (COCHIS) | High | Resolution complexity |
| OCaml modular implicits | Module-based | Local | Full | Unmerged proposal |
| Koka/Eff/Frank | Effect handlers | Lexically scoped | Full | Requires language support |

### Swift-Specific

| Source | Insight |
|--------|---------|
| SE-0364 (Retroactive Conformance Warning, 2022) | Conformances are globally unique per process. Retroactive conformances are hazardous. |
| SE-0335 (Existential `any`, 2022) | Makes protocol abstraction costs explicit. Exposes where the mechanism breaks down. |
| Swift Forums: "Multiple protocols associatedtype name collision" (2018) | No disambiguation syntax exists. The compiler picks one arbitrarily. This is a known, unfixed limitation. |
| Point-Free, "Protocol Witnesses" (Episodes 33-36, 2019) | Mechanical translation from protocol to struct-of-closures. Eliminates associated type collisions entirely. |
| Tweag, "Deconstructing classes" (2021) | Typeclasses conflate four roles: grouping, canonical instances, overloading, type computation. Only canonical instances require coherence. |

## Formal Analysis

### The Unsoundness

Swift's type system enforces:

```
forall T, P: T : P  =>  exists! (T.AssocType_i for each i in P.associatedtypes)
```

That is, for each protocol conformance, there is exactly one binding for each associated type. When two protocols `P` and `Q` both declare `associatedtype Output`, and `T : P` with `Output = A` and `T : Q` with `Output = B` where `A != B`, the compiler cannot produce a well-typed program because:

```
T.Output = A   (from P)
T.Output = B   (from Q)
A != B
=> contradiction
```

This is not a bug but a **design invariant**: Swift's protocol witness tables use a single flat namespace per type. There is no mechanism to scope an associated type binding to a specific protocol.

### Why Witnesses Avoid This

A witness is a struct with generic parameters instead of associated types:

```swift
// Protocol approach (global, singular):
protocol Parseable {
    associatedtype Output
    func parse(_ input: inout Substring) throws -> Output
}
// String can only have ONE Output

// Witness approach (local, plural):
struct Parsing<Input, Output, Failure: Error> {
    var parse: (inout Input) throws(Failure) -> Output
}
// String can have as many Parsing instances as desired:
let stringAsVoidParser = Parsing<Substring, Void, Parser.Match.Error> { ... }
let stringAsUInt8Renderer = Parsing<Substring, UInt8, Never> { ... }
```

The key structural difference: protocols bind associated types to the **conforming type** (one binding per type per protocol). Witnesses bind generic parameters to the **witness value** (unlimited bindings per type).

### Why Effects Provide Further Structure

Algebraic effects add lexical scoping to the witness model:

```swift
// Effect approach (lexically scoped):
effect Parse {
    func parse(_ input: inout Substring) -> Output
}

// Handler A (in scope for HTML rendering):
handle Parse { ... returns UInt8 ... }

// Handler B (in scope for parser combinators):
handle Parse { ... returns Void ... }
```

The handler model ensures that capability resolution is **deterministic by scope** rather than **unique by type**. This aligns with Swift Institute's existing `Effect.Protocol` / `Effect.Handler` / `Effect.Continuation` infrastructure in `swift-effect-primitives`.

## Options

### Option A: Rename Conflicting Associated Types

**Description**: Rename `Rendering.Protocol.Output` to `Rendering.Protocol.Element` (or similar). Keep protocol-based design.

**Advantages**:
- Minimal change. Fixes the immediate collision.
- No architectural shift required.

**Disadvantages**:
- Treats the symptom, not the disease. The next collision is one transitive dependency away.
- Still cannot have `String: Parser.Protocol` and `String: SomeOtherProtocolWithOutput` simultaneously.
- Retroactive conformances on stdlib types remain fragile.
- Does not address the deeper issue that protocols are the wrong abstraction for capabilities that a type may participate in multiple ways.

**Scope of change**: ~20 files in `swift-renderable` and its consumers.

### Option B: Remove Retroactive Conformances on Stdlib Types

**Description**: Replace `String: Parser.Protocol` and `String: Renderable` with wrapper types (`Parser.Literal`, `HTML.Text`). Keep protocols for user-defined types.

**Advantages**:
- Eliminates the collision by removing the conflicting conformances.
- Follows Rust's newtype pattern (proven at scale).
- Retroactive conformances are already warned by SE-0364.

**Disadvantages**:
- Ergonomic cost. `"hello"` can no longer be used directly where a parser or renderable is expected.
- Viral: every call site that passes `String` to a generic `<T: Renderable>` needs wrapping.
- Does not prevent future collisions on user-defined types that conform to many protocols.

**Scope of change**: All call sites using `String` as `Parser.Protocol` or `Renderable`.

### Option C: Witness-Based Capability Abstraction

**Description**: Replace `Parser.Protocol` and `Rendering.Protocol` with witness structs. Use the existing `@Witness` macro and `Witness.Protocol` infrastructure.

**Parser witness**:
```swift
// Instead of: extension String: Parser.Protocol { ... }
// Define:
struct Parser<Input, Output, Failure: Error>: Witness.Protocol {
    var parse: (inout Input) throws(Failure) -> Output
}

// Multiple witnesses for String:
extension Parser where Input == Substring, Output == Void, Failure == Parser.Match.Error {
    static var literal: Self { ... }  // matches prefix
}

extension Parser where Input == Binary.Bytes.Input, Output == UInt8, Failure == Never {
    static var byteRenderer: Self { ... }  // renders to bytes
}
```

**Rendering witness**:
```swift
struct Rendering<Content, Context, Output>: Witness.Protocol {
    var body: (Content) -> Content
    var render: (Content, inout some RangeReplaceableCollection<Output>, inout Context) -> Void
}
```

**Advantages**:
- Eliminates associated type collisions entirely.
- Multiple implementations per type without wrappers.
- Composable via `map`, `pullback`, `contramap` (Point-Free's insight).
- Testable via `Witness.unimplemented()` and `Witness.Context.Mode.test`.
- Aligns with existing `swift-witness-primitives` and `swift-witnesses` infrastructure.
- Values are first-class: storable, passable, constructible at runtime.
- Macro support via `@Witness` already exists.

**Disadvantages**:
- Loss of implicit dispatch. `func render<T: Renderable>(_ t: T)` becomes `func render<T>(_ t: T, using witness: Rendering<...>)` unless combined with `Witness.Context` for implicit resolution.
- Significant migration effort across the ecosystem.
- Generic constraints become witness parameters (changes all signatures).
- Swift's generics system is optimized for protocol dispatch (specialization, witness table devirtualization). Closure-based witnesses may not inline as aggressively.

**Scope of change**: All parsing and rendering APIs across L1-L4.

### Option D: Effect-Based Capability Abstraction

**Description**: Model parsing and rendering as algebraic effects using `swift-effect-primitives`. Handlers provide implementations.

```swift
// Define effects:
struct ParseEffect: Effect.Protocol {
    typealias Value = Output
    typealias Failure = ParseError
    let input: inout Substring
}

// Use:
let result = try await Effect.perform(ParseEffect(input: &substring))
```

**Advantages**:
- Lexically scoped handlers: different regions handle the same effect differently.
- Natural composition via handler nesting.
- Aligns with `Effect.Protocol` / `Effect.Handler` / `Effect.Continuation` infrastructure.
- Conceptually clean separation of interface and implementation.

**Disadvantages**:
- Effects are `async` (require suspension/continuation). Parsing and rendering are synchronous hot paths. The CPS overhead is unacceptable for byte-level operations.
- `~Copyable` one-shot continuations add ownership complexity.
- The effect primitives are not yet at the maturity level needed for production parsing.
- Conceptual mismatch: parsing and rendering are pure transformations, not side effects. Modeling them as effects is category-theoretically incorrect (they're morphisms in a category of parsers, not operations on a state machine).

**Scope of change**: Fundamental redesign of parsing and rendering.

### Option E: Hybrid — Witnesses with Protocol Sugar

**Description**: Use witness structs as the primary abstraction. Provide a thin protocol layer for ergonomic conformance syntax, with the protocol's `Output` resolved from the witness.

```swift
// Witness (primary):
struct Parsing.Witness<Input, Output, Failure: Error>: Witness.Protocol {
    var parse: (inout Input) throws(Failure) -> Output
}

// Protocol (sugar, no Output associated type — uses the witness):
protocol Parseable {
    associatedtype Input
    static var parsingWitness: Parsing.Witness<Input, ???, ???> { get }
}
```

**Advantages**:
- Witnesses for flexibility, protocol for discoverability.
- Migration can be incremental.

**Disadvantages**:
- The protocol still has associated types that must be unique per type.
- Does not fundamentally solve the problem — just moves where the collision happens.
- Two parallel abstractions create confusion about which to use.

**Scope of change**: Moderate — new witness types plus optional protocol wrappers.

## Comparison

| Criterion | A: Rename | B: No Retroactive | C: Witnesses | D: Effects | E: Hybrid |
|-----------|-----------|-------------------|--------------|------------|-----------|
| Fixes immediate collision | Yes | Yes | Yes | Yes | Yes |
| Prevents future collisions | No | Partially | Yes | Yes | Partially |
| Performance impact | None | None | Possible (closures) | Severe (CPS) | Possible |
| Migration effort | Low | Medium | High | Very High | Medium |
| Ergonomic impact | None | Moderate (wrappers) | Moderate (witness params) | High (async) | Low |
| Aligns with existing infra | N/A | N/A | Yes (`@Witness`, `Witness.Context`) | Yes (`Effect.Protocol`) | Partial |
| Theoretical soundness | Unsound (postpones) | Sound (within scope) | Sound | Sound (but misapplied) | Partially sound |
| Composability | Protocol inheritance | Protocol inheritance | Value composition | Handler nesting | Mixed |
| Testability | Mock types | Mock types | Mock values | Mock handlers | Mock values |
| Precedent in literature | N/A | Rust newtype | ML modules, COCHIS | Koka, Eff, Frank | Scala 3 |

### Cognitive Dimensions Analysis (per [RES-025])

| Dimension | A | B | C | D | E |
|-----------|---|---|---|---|---|
| **Visibility** (can I see what's happening?) | Low — collision hidden in transitive deps | Medium — wrappers explicit | High — witnesses explicit | High — handlers explicit | Medium |
| **Consistency** (do similar things look similar?) | High — same protocol syntax | Medium — wrappers differ from direct use | High — all capabilities are witnesses | Low — sync ops modeled as async | Medium |
| **Viscosity** (how hard to change?) | Low — rename only | Medium — wrapper propagation | High — signature changes | Very high — fundamental redesign | Medium |
| **Role-expressiveness** (can I tell what something does?) | Low — `Output` is ambiguous | Medium — wrapper names clarify | High — witness struct names are explicit | High — effect names clear | Medium |
| **Error-proneness** (easy to make mistakes?) | High — next collision imminent | Medium — might forget wrapper | Low — no global state | Low — typed effects | Medium |
| **Abstraction** (can I work at the right level?) | Yes — protocols familiar | Yes — wrappers are standard | Yes — witnesses well-understood | No — effects are wrong abstraction for parsing | Partial |

## Constraints

1. **Performance**: Parsing and rendering are hot paths. Byte-level operations must remain inlineable. Closure-based witnesses are acceptable only if `@inlinable` and `@_transparent` optimizations apply.

2. **Five-layer architecture**: The solution must respect layer boundaries. Witness primitives are at L1; witnesses at L3. Any solution must not create upward dependencies.

3. **Existing codebase**: `swift-parser-primitives` uses `Parser.Protocol` extensively with result builders, typed throws, and `~Copyable` continuations. Migration must be incremental.

4. **Swift language**: No custom effect handler syntax exists in Swift. `swift-effect-primitives` provides the types but `Effect.perform` requires async/await, which is unsuitable for synchronous parsing.

5. **`@Witness` macro**: Already exists and generates init, Action enum, observe, unimplemented. Could generate parser/rendering witness infrastructure.

## Outcome

**Status**: IN_PROGRESS

### Preliminary Recommendation

**Option C (Witness-Based) for new capabilities, Option B (No Retroactive Conformances) as immediate fix.**

**Rationale**:

1. **Option D (Effects) is eliminated.** Parsing and rendering are synchronous pure transformations. Modeling them as effects introduces async overhead and is category-theoretically inappropriate. The effect infrastructure is valuable for actual side effects (I/O, networking, state), not for pure algebraic operations.

2. **Option A (Rename) is eliminated.** It postpones the problem. With 60+ primitives packages, the transitive dependency graph will inevitably produce more collisions as the ecosystem grows.

3. **Option E (Hybrid) is eliminated.** It creates two parallel abstraction mechanisms without fully solving the problem.

4. **Option B provides the immediate fix.** Remove `String: Parser.Protocol` and `String: Renderable`. Replace with `Parser.Match.Literal` (or `Parser.Literal`) and keep `HTML.Text` (already exists). This unblocks the current build immediately and follows SE-0364's guidance that retroactive conformances are hazardous.

5. **Option C is the long-term direction.** The witness pattern is already infrastructure in this ecosystem (`swift-witness-primitives`, `swift-witnesses`, `@Witness` macro). The prior art strongly supports witnesses over protocols for capability abstraction: Dreyer (2007) proves modules subsume typeclasses; COCHIS (2019) proves local flexibility and coherence are compatible; Point-Free (2019) demonstrates the mechanical translation in Swift.

### Immediate Action (Option B)

1. Remove `extension String: Parser.Protocol` from `swift-parser-primitives`.
2. Add `Parser.Match.Literal` struct (or similar) as the replacement.
3. Remove `extension String: @retroactive Renderable` from `swift-html-rendering`.
4. Route all `String` rendering through `HTML.Text` (already the `body` type).
5. Remove `extension Array: Parser.Protocol` (same pattern).

### Long-term Direction (Option C)

Requires further research on:

- Performance characterization: benchmark witness closures vs protocol dispatch for parsing hot paths.
- Migration strategy: incremental path from `Parser.Protocol` to `Parser.Witness` without breaking consumers.
- Implicit resolution: whether `Witness.Context` (TaskLocal-based) is suitable for synchronous parsing, or whether a compile-time mechanism is needed.
- `@Witness` macro extensions: whether the macro can generate parser combinator infrastructure (result builders, typed throws composition).

### Open Questions

1. Should `Parser.Protocol` itself become a witness? Or should it remain a protocol with retroactive conformances removed?
2. What is the performance delta between `@inlinable` closure witnesses and protocol witness tables for parsing?
3. Can `Witness.Context` resolution work synchronously (it currently uses `@TaskLocal`)?
4. Should `Rendering.Protocol` become a witness? The `body`-based recursive structure maps naturally to protocols but could work as witnesses with `@resultBuilder`.

## References

### Foundational

- Wadler, P. & Blott, S. (1989). "How to make ad-hoc polymorphism less ad hoc." POPL 1989, ACM, pp. 60-76.
- Dreyer, D., Harper, R., Chakravarty, M.M.T. & Keller, G. (2007). "Modular Type Classes." POPL 2007.
- Wehr, S. & Chakravarty, M.M.T. (2008). "ML Modules and Haskell Type Classes: A Constructive Comparison." APLAS 2008, LNCS 5356.
- Schrijvers, T., Oliveira, B.C.D.S., Wadler, P. & Marntirosian, K. (2019). "COCHIS: Stable and Coherent Implicits." Journal of Functional Programming, 29, e3.

### Algebraic Effects

- Plotkin, G. & Power, J. (2003). "Algebraic Operations and Generic Effects." Applied Categorical Structures, 11, pp. 69-94.
- Plotkin, G. & Pretnar, M. (2009). "Handlers of Algebraic Effects." ESOP 2009, LNCS.
- Leijen, D. (2017). "Type Directed Compilation of Row-Typed Algebraic Effects." POPL 2017.
- Lindley, S., McBride, C. & McLaughlin, C. (2017). "Do Be Do Be Do." POPL 2017.
- Bauer, A. & Pretnar, M. (2015). "Programming with Algebraic Effects and Handlers." JLAMP, 84(1), pp. 108-123.

### Language Design

- White, L., Bour, F. & Yallop, J. (2014). "Modular Implicits." ML Family Workshop 2014, EPTCS 198.
- Odersky, M. et al. (2020-present). "Contextual Abstractions." Scala 3 Reference.
- Yang, E.Z. (2014). "Type classes: confluence, coherence and global uniqueness." Blog post.
- Chiusano, P. (2018). "The trouble with typeclasses." Blog post.
- Tweag (2021). "Deconstructing classes." Blog post.

### Swift-Specific

- SE-0364 (2022). "Warning for Retroactive Conformances of External Types."
- SE-0335 (2022). "Introduce existential `any`."
- SE-0309 (2021). "Unlock existential types for all protocols."
- Williams, B. & Celis, S. (2019). "Protocol Witnesses." Point-Free Episodes 33-36.
- Swift Forums (2018). "Multiple protocols associatedtype name collision." Thread #13612.

### Internal

- `swift-witness-primitives` — `Witness.Protocol`, `Witness.Composition`
- `swift-witnesses` — `Witness.Key`, `Witness.Values`, `Witness.Context`, `@Witness` macro
- `swift-effect-primitives` — `Effect.Protocol`, `Effect.Handler`, `Effect.Continuation`
