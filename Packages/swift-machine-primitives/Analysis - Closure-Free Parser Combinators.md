# Closure-Free Parser Combinators: A Comparative Analysis of Defunctionalized Parsing in Swift 6

<!--
---
document_type: technical_analysis
version: 2.1.0
date: 2026-01-19
author: Swift Institute
status: RECOMMENDATION
word_count: ~6200
revision_notes: |
  v2.1.0:
  - Expanded Section 8.3 with pressure-test analysis (indentation-sensitive, length-prefixed)
  - Added borrowed output discipline as the remaining open question
  - Documented three resolution strategies with recommendation
  v2.0.0:
  - Integrated implementation details from swift-parsing-primitives
  - Corrected flatMap analysis (dynamic control boundary, not finite continuations)
  - Reframed Mode stratification (concurrency boundary, not memory safety)
  - Elevated incremental parsing from speculation to demonstrated capability
  - Added CPS/internal-machine analysis for Haskell comparison
  - Strengthened "categorical prohibition" framing
---
-->

## Abstract

Parser combinators traditionally rely on higher-order functions and closure captures to compose parsing operations. This design, while elegant, creates fundamental tensions with modern language features: borrowed data cannot escape into closures, closure captures complicate concurrency safety proofs, and opaque function objects resist inspection and optimization. We present a comparative analysis of `Machine.Program`—a defunctionalized parser representation for Swift 6—against parser combinator implementations in Rust, Haskell, OCaml, and C++. Unlike prior analyses that treat defunctionalization as a design choice, we demonstrate that Swift 6's `~Escapable` types create a *categorical prohibition* against closure-based combinators operating on borrowed views—defunctionalization is forced, not chosen. We examine the implemented system including working incremental parsing with memoization, identify error recovery as the primary open problem, and evaluate where this architecture advances beyond prior art.

---

## 1. Problem Statement

### 1.1 The Categorical Prohibition

Parser combinators achieve compositionality through higher-order functions. A `map` combinator transforms a parser's output by accepting a transformation function:

```swift
// Traditional closure-based design
func map<A, B>(_ parser: Parser<A>, _ transform: @escaping (A) -> B) -> Parser<B>
```

The `@escaping` annotation reveals the core tension: the transformation must outlive the call site, typically stored inside the returned `Parser<B>`. In Swift 6, this storage creates not merely tension but *categorical impossibility* for certain input types.

Swift's `~Escapable` types—values with non-static lifetimes that the compiler proves do not outlive their storage—cannot be captured by escaping closures. This is not an optimization limitation or a soft constraint that clever engineering might circumvent. The Swift Evolution proposal SE-0390 states explicitly: "Escaping closures cannot capture nonescapable values."

```swift
// This is rejected by the compiler—not warned, rejected
func parse(_ span: borrowing Span<UInt8>) -> Parser<Token> {
    return tokenParser.map { token in
        // ERROR: 'span' cannot be captured by an escaping closure
        token.validate(against: span)
    }
}
```

### 1.2 The Rust Contrast

Rust's ownership model is often compared to Swift's, but the constraints differ categorically. In Rust, a parser parameterized by input lifetime is expressible:

```rust
// Rust: parser type carries lifetime parameter
fn parse<'a>(input: &'a [u8]) -> impl Parser<&'a [u8], Token<'a>, Error> + 'a
```

The parser is not `'static`, but it *exists*. The type system tracks the lifetime, and composition proceeds within that lifetime's scope. Rust libraries advise against encoding input lifetime into parser types for ergonomic reasons, but the representation is *possible*.

In Swift 6 with `~Escapable`, the equivalent construction is rejected at compile time. There is no "non-static parser" escape hatch. A parser that stores closures cannot operate on borrowed views—period.

This categorical difference explains why defunctionalization is *forced* in Swift but merely *advisable* in Rust. The design space narrows not by preference but by type system constraint.

### 1.3 The Concurrency Dimension

Beyond borrowed data, Swift's `Sendable` protocol requires that values safely cross concurrency boundaries. A parser containing closures is `Sendable` only if all captured values are `Sendable`. When closures capture heterogeneous data, proving `Sendable` conformance requires either:

1. Constraining all captured types at the API boundary (infecting every generic signature)
2. Using `@unchecked Sendable` (abandoning compiler verification)
3. Requiring homogeneous capture types (limiting expressiveness)

Real parser programs capture diverse data—lookup tables, configuration, partial results—making options 1 and 3 impractical. Most implementations choose option 2, trading safety for ergonomics. The Swift forums are replete with developers hitting "Capture of non-sendable type in a @Sendable closure" warnings and reaching for escape hatches.

### 1.4 The Inspectability Requirement

Closures are opaque to inspection. A parser built from combinators cannot be:

- Serialized (closures have no canonical representation)
- Optimized post-construction (no access to internal structure)
- Debugged structurally (only execution traces available)
- Compared for equality (function identity is reference-based)
- Memoized efficiently (no structural identity for cache keys)

This last point matters most for incremental parsing. Tree-sitter and similar systems achieve fast re-parsing after edits by caching parse results keyed by (position, grammar-node). With closure-based parsers, there is no "grammar-node" to key against—only opaque function objects.

### 1.5 The Defunctionalized Response

The `Machine.Program` design responds to these constraints through defunctionalization:

- **Nodes are pure data** (no stored closures)
- **Operations store (CaptureID, non-capturing thunk)**, not closures with environments
- **All captured data lives in an explicit `Capture.Store`**, referenced by typed IDs
- **Heterogeneous captures are type-erased at the store boundary** but re-typed when accessed
- **Sendability derives structurally** from mode and capture constraints

This is not a novel technique—defunctionalization dates to Reynolds (1972). What is novel is being *compelled* into it by a mainstream language's type system, and building a complete parser combinator ecosystem on that foundation.

---

## 2. Design Space Survey

### 2.1 Rust: Ownership Helps, Enforcement Differs

Rust's parser combinator ecosystem—nom, chumsky, winnow—demonstrates that ownership systems can mitigate but not eliminate the closure-capture tension.

**nom** uses lifetime parameters to track input provenance:

```rust
pub trait Parser<I, O, E> {
    fn parse(&mut self, input: I) -> IResult<I, O, E>;
}
```

The `FnMut` bounds on combinator arguments permit closures that capture mutable state. nom achieves zero-copy parsing through lifetime tracking (`&'a [u8]`), but the `impl Parser` return type erases internal structure. Parsers cannot be inspected post-construction.

For concurrency, nom parsers are `Send + Sync` only when all captured data satisfies these bounds. The `FnMut` bound actually prevents `Sync` in many cases—mutable closures require exclusive access. nom parsers are typically constructed per-thread rather than shared.

**winnow** foregrounds a `Parser` trait with `parse_next(&mut self, input: &mut I)`:

```rust
pub trait Parser<I, O, E> {
    fn parse_next(&mut self, input: &mut I) -> PResult<O, E>;
}
```

The `&mut I` parameter makes input mutation explicit, supporting streaming scenarios. This trait-based style reduces some closure pressure because a parser can be a struct implementing the trait, not necessarily a closure.

**chumsky** emphasizes error recovery with combinators like `skip_until` and delimiter-aware recovery. Its `&self` receiver permits shared access, improving `Sync` compatibility by requiring stateless parsers.

**Key Rust observation**: Rust's ownership model enables zero-copy parsing through lifetime tracking—a capability Swift 6 matches with `~Escapable`. However, Rust parser libraries do not defunctionalize; they accept closure opacity as the cost of expressiveness. The `Send + Sync` problem is managed through construction patterns (per-thread parsers) rather than structural guarantees. Rust *can* express non-Send parsers; Swift's modern concurrency model strongly encourages making such properties explicit and mechanically enforced.

### 2.2 Haskell: The Machine Is Already There

Haskell's parser combinator tradition—parsec, megaparsec, attoparsec—benefits from referential transparency and sophisticated compiler optimization. But beneath the monadic surface, these libraries already implement explicit machines.

**Parsec's internal representation** is continuation-passing:

```haskell
newtype ParsecT s u m a = ParsecT {
    unParser :: forall b. State s u
             -> (a -> State s u -> ParseError -> m b)  -- consumed ok
             -> (ParseError -> m b)                     -- consumed err
             -> (a -> State s u -> ParseError -> m b)  -- empty ok
             -> (ParseError -> m b)                     -- empty err
             -> m b
}
```

This is already defunctionalization in disguise. The four continuation parameters replace what would be a single closure in direct style. The `forall b` quantification ensures continuations cannot be stored—they must be invoked immediately, preventing capture-related issues.

**megaparsec** extends parsec with typed, compositional error components:

```haskell
data Reply e s a = Reply (State s e) Consumption (Result e a)
```

The explicit `Reply` type reifies parser outcomes as data, improving debuggability. The explicit `State` threading resembles the Swift design's `Capture.Frozen` parameter.

**attoparsec** optimizes for performance with explicit position and streaming state:

```haskell
newtype Parser i a = Parser {
    runParser :: forall r. State i -> Pos -> More
              -> Failure i   r
              -> Success i a r
              -> IResult i r
}
```

**The key insight**: Many "monadic parser combinators" are already implemented as explicit continuation-passing evaluators internally. Users see a closure-friendly API because Haskell's purity, laziness, and optimizer make it cheap to expose "parser as monad" and compile away the abstraction. Swift cannot rely on these properties—eagerness means construction has immediate cost, mutability prevents referential transparency assumptions, and the optimizer is capable but not GHC. Swift surfaces the machine boundary explicitly because it cannot hide it implicitly.

### 2.3 OCaml: Effects as Alternative

OCaml's **angstrom** achieves zero-copy parsing through careful buffer management:

```ocaml
type 'a t = {
    run : 'r. (Buffering.t -> 'a -> 'r) -> (Buffering.t -> 'r) -> Buffering.t -> 'r
}
```

Like attoparsec, angstrom uses CPS with explicit buffer threading. The polymorphic `'r` ensures continuations cannot be stored.

**Algebraic effects** offer a different path:

```ocaml
effect Fail : exn -> 'a
effect Choose : bool

let rec parse input = match input with
    | [] -> perform Fail EndOfInput
    | c :: rest -> if perform Choose then c else parse rest
```

Effects separate computation description (the `perform` calls) from interpretation (the handler). A parser becomes a generator of effects; the interpreter decides how to handle backtracking, failure, and success. This is defunctionalization by another name—effects are data, handlers are interpreters.

If Swift gains algebraic effects, parser combinators could be expressed more naturally. Until then, explicit defunctionalization remains necessary.

### 2.4 C++: Compile-Time Defunctionalization

Boost.Spirit demonstrates template metaprogramming for parsing:

```cpp
template <typename Iterator>
struct calculator : qi::grammar<Iterator, int()> {
    calculator() : calculator::base_type(expression) {
        expression = term >> *(('+' >> term) | ('-' >> term));
        term = factor >> *(('*' >> factor) | ('/' >> factor));
        factor = qi::int_ | ('(' >> expression >> ')');
    }
    qi::rule<Iterator, int()> expression, term, factor;
};
```

Spirit parsers are expression templates—the grammar definition builds a type encoding the parse structure. This is compile-time defunctionalization: the parser is a type, not a runtime value.

**Benefits**: Zero runtime allocation, full inspectability via template introspection, optimal code generation.

**Costs**: Enormous compile times, incomprehensible error messages, no runtime parser construction.

Spirit represents one extreme—complete compile-time defunctionalization. The Swift design occupies a middle ground: runtime construction with structural inspectability, enabling use cases (dynamic grammars, plugin systems, incremental re-parsing) that Spirit cannot address.

---

## 3. Detailed Rust Comparison

Rust's ownership model is closest to Swift's, making detailed comparison instructive.

### 3.1 Lifetime Tracking vs. ~Escapable

Rust uses explicit lifetime parameters that compose through type parameters. Swift's `~Escapable` achieves similar goals through return type inference without explicit annotation.

**Rust advantage**: Lifetime parameters are explicit documentation. Developers see `Token<'a>` and understand the dependency.

**Swift advantage**: `~Escapable` requires no annotation at use sites, reducing syntactic overhead.

**Critical difference**: Rust lifetimes *enable* non-static parser values. Swift's `~Escapable` *prohibits* closure capture of such values. Rust's approach is more flexible; Swift's is more restrictive but aligns with the "if it compiles, it's safe" philosophy.

### 3.2 Sendability Comparison

Both languages use conditional conformance for thread safety. The difference lies in what is constrained.

**Rust**: Constrains closure types (`F`, `G`). Since closures have anonymous types, this works through `impl Trait` bounds.

**Swift (traditional)**: Would constrain captured values, but closure capture types are not exposed in the type signature—hence `@unchecked Sendable`.

**Swift (Machine.Program)**: Constrains the `Mode` parameter. `Mode.Reference` is `Sendable` only when all inserted captures satisfy `Value: Sendable` at construction time. The mode acts as a witness that the constraint was verified.

This lifts capture constraints from opaque closure types to an explicit mode parameter, enabling structural `Sendable` proofs without escape hatches.

### 3.3 Inspectability Gap

Consider implementing a parser optimizer that eliminates redundant operations:

**Rust (nom)**: Impossible. The `impl Parser` return type hides internal structure.

**Swift (Machine.Program)**: Direct inspection possible:

```swift
func optimize<L, F, M>(_ program: inout Machine.Program<L, F, M>) {
    for (index, node) in program.nodes.enumerated() {
        if case .map(let child, let t1) = node,
           case .map(let grandchild, let t2) = program[child] {
            // Compose transforms, eliminate intermediate node
            let composed = composeTransforms(t2, t1, using: program.captures)
            program.nodes[index] = .map(child: grandchild, transform: composed)
        }
    }
}
```

The explicit node representation enables structural transformations that closure-based designs preclude.

---

## 4. The Implemented System

Unlike analyses that treat capabilities as speculative, the Swift ecosystem includes a working implementation in `swift-parsing-primitives` that demonstrates these principles.

### 4.1 Two-Tier Architecture

The implementation provides two execution paths:

**Combinator API** (direct parsing):
```swift
var input = Parsing.CollectionInput(bytes[...])
let parser = Parsing.OneOf {
    Parsing.Literal("GET")
    Parsing.Literal("POST")
}
let method = try parser.parse(&input)
```

**Machine API** (stack-safe, incremental):
```swift
let compiled = parser.parse.compiled()  // Lazily compiles to Machine.Program
let result = try compiled.parse(&input)
```

Users write familiar combinators; the system compiles them to defunctionalized programs when stack safety or incremental parsing is needed. This confirms the "two-tier API" prediction—it is the actual architecture.

### 4.2 Incremental Parsing with Memoization

The implementation includes working incremental parsing:

```swift
var ctx = parser.parse.incremental

// Initial parse (populates memoization table)
let tree1 = try ctx(&input)

// After edit, invalidate affected entries
ctx.invalidate(edit)

// Re-parse (reuses cached results)
let tree2 = try ctx(&input2)
```

The memoization system caches parse results at (position, node-ID) keys—precisely what closure opacity would prevent. Cache entries store:

```swift
enum Entry<Checkpoint> {
    case success(output: Machine.Value, end: Checkpoint)
    case failure
}
```

Caching *failures* is essential for packrat parsing's linear-time guarantees. Edit invalidation uses checkpoint comparison to invalidate only affected entries:

- For success entries: invalidate if result spans the affected range
- For failure entries: invalidate only if at or after edit start

This enables efficient re-parsing of large documents after small edits—the capability that justifies defunctionalization overhead. IDE responsiveness depends on this.

### 4.3 Stack-Safe Execution

The machine uses explicit frame stacks instead of recursive function calls:

```swift
enum Frame<NodeID, Checkpoint, Failure: Error, Extra> {
    case map(transform: Transform.Erased)
    case tryMap(transform: Transform.Throwing<Failure>)
    case flatMap(next: Next.Erased<NodeID>)
    case sequence(Sequence)
    case oneOf(alternatives: [NodeID], index: Int, savedCheckpoint: Checkpoint)
    case many(child: NodeID, savedCheckpoint: Checkpoint, ...)
    case memoization(...)  // Extra frame for incremental parsing
    // ...
}
```

Frame stacks are pre-allocated based on `maxDepth`, preventing stack overflow on deeply nested grammars. This matters for production systems parsing user-provided input where nesting depth is untrusted.

### 4.4 Checkpoint-Based Backtracking

The `Input` protocol provides checkpoint/restore for backtracking:

```swift
public protocol Input: Streaming {
    associatedtype Checkpoint: Hashable & Sendable
    var checkpoint: Checkpoint { get }
    mutating func restore(to checkpoint: Checkpoint)
}
```

`Hashable` is required for memoization keys. `Sendable` enables concurrent parsing contexts. The `OneOf` combinator automatically saves/restores checkpoints when trying alternatives.

---

## 5. The FlatMap Question

### 5.1 What FlatMap Supports

Earlier analyses suggested flatMap "resists defunctionalization" by requiring either finite continuation sets or stored closures. This overstates the difficulty.

In the `Machine.Program` design, `flatMap` is:

```swift
case flatMap(child: ID, next: Next.Erased<Mode, ID>)
```

The `Next.Erased` stores a captured function `(Value) -> Node.ID` in `Capture.Frozen`, accessed via non-capturing thunk. This function can compute *any* `Node.ID` based on input—the set of possible targets is not declared upfront.

### 5.2 What FlatMap Cannot Do

FlatMap cannot construct *new nodes* at runtime:

```swift
// Impossible: runtime node construction
flatMap { value in
    Parser.literal(value.dynamicString)  // Creates new parser from value
}
```

Nodes are allocated at builder time, not execution time. But this limitation is shared by:

- Parser generators (yacc, ANTLR): Grammar is static
- Regex engines: Pattern is compiled before matching
- Boost.Spirit: Grammar is a compile-time type
- Rust's nom/winnow in practice: Idiomatic usage is static function composition

### 5.3 The Dynamic Control Boundary

The accurate characterization is:

> FlatMap is representable, but it becomes the place where dynamic control enters the otherwise structural graph, constraining optimization and analysis.

"Choose any Node.ID based on Value" is a control effect that interacts with:

- **Termination**: Arbitrary dispatch could loop
- **Memoization**: Cache validity depends on dispatch determinism
- **Error reporting**: Blame assignment must track dynamic paths
- **Optimization**: Rewrite rules must preserve semantics under arbitrary `Next`

For most practical grammars (programming languages, data formats, protocols), this constraint is acceptable. Dynamic parser construction is often an anti-pattern—it defeats optimization, complicates errors, and prevents incremental parsing.

Where it matters:
- Dependent parsing of length-prefixed formats where length determines inner parser
- Dynamically scoped grammars (custom operator tables, indentation-sensitive parsing)
- "Parse something, then use that to pick a parser family" beyond selecting a Node.ID

These can be emulated with preallocation and computed dispatch, but not all patterns translate cleanly.

---

## 6. Mode Stratification

### 6.1 Reference vs. Unchecked

The design provides two modes:

| Property | Mode.Reference | Mode.Unchecked |
|----------|----------------|----------------|
| Memory safety | Yes | Yes |
| Thread safety | Yes (Sendable) | No (single-threaded) |
| Capture constraint | `Value: Sendable` | Any `Value` |
| Use case | Shared parsers | Local/embedded parsers |

### 6.2 Concurrency Boundary, Not Memory Unsafety

`Mode.Unchecked` is not "unsafe" in the Rust sense—it does not permit memory unsafety or data races. It permits *non-Sendable* captures.

The distinction matters: `Mode.Unchecked` programs can be used safely in:
- Single-threaded contexts
- Scopes where sharing is impossible by construction
- Migration scenarios transitioning toward `Sendable` discipline

The type system prevents crossing isolation domains where races become possible. This is a *concurrency boundary*, not a safety escape hatch.

### 6.3 Comparison to Haskell's ST

The stratification resembles Haskell's `ST`/`IO` distinction:

```haskell
runST :: (forall s. ST s a) -> a
```

`ST` gives a non-escape guarantee for references via rank-2 polymorphism. `Mode.Unchecked` gives a non-share guarantee across concurrency boundaries.

Similar stratification, not identical mechanism. The parallel is directionally useful but should not be overstated.

---

## 7. Novel Contributions

### 7.1 Categorical Forcing Function

Prior parser combinator designs choose their representation based on ergonomics, performance, or taste. The Swift design is *forced* into defunctionalization by `~Escapable`'s prohibition on closure capture of borrowed views. This is not "Rust-like discipline" but a harder constraint that changes the design space.

### 7.2 Mode-Indexed Sendability

The `Mode.Reference` / `Mode.Unchecked` split enables:

```swift
extension Machine.Program: Sendable
    where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}
```

Sendability becomes a *structural property* derived from mode choice, not an `@unchecked` assertion. This is rare in parser combinator designs.

### 7.3 Systematic Thunk Exploitation

The distinction between "capturing closure" and "non-capturing function" exists in many systems. What is novel is *systematically exploiting this distinction for Sendability*: all behavior is either a non-capturing thunk (inherently Sendable) or data in a store that is itself conditionally Sendable.

### 7.4 Typed Heterogeneous Erasure

The capture store achieves:

- **Heterogeneous storage**: Different captures have different types
- **Typed access**: `ID<Value>` ensures retrieval matches storage
- **Runtime verification**: `ObjectIdentifier` check catches mismatches
- **No protocol existentials**: Avoids witness table overhead

This is "no existentials" in the protocol-witness-table sense, though `AnyObject` boxes are still used internally. The contribution is avoiding dynamic dispatch overhead while maintaining type safety.

### 7.5 Demonstrated Incremental Parsing

Unlike analyses that treat incremental parsing as speculative, the implementation demonstrates:

- Memoization keyed by (position, node-ID)
- Edit-based cache invalidation
- Linear-time re-parsing for small edits

This validates the claim that defunctionalization enables capabilities closure-based designs preclude.

---

## 8. Limitations

### 8.1 Error Recovery: The Primary Gap

Error recovery is the most significant open problem. The implementation provides:

- Backtracking via `OneOf` and checkpoint restoration
- Typed throws for precise error propagation
- Error transformation combinators

It does not yet provide:

- **Synchronization combinators**: Chumsky's `skip_until`, delimiter-aware recovery
- **Multiple error accumulation**: Megaparsec's approach to reporting several errors
- **Labeled expectations**: "Expected X at position Y" diagnostics
- **Recovery strategies as data**: Inspectable recovery policies

In practice, parser frameworks are judged by diagnostics and recovery at least as much as raw performance. Megaparsec and Chumsky set high bars. This remains the design's most pressing limitation.

### 8.2 Optimization Ownership

Closure-based combinators can be fast when monomorphic and inlineable—the compiler does the work. A defunctionalized interpreter shifts optimization ownership:

- **Closure-based**: Compiler handles fusion, inlining, specialization
- **Machine-based**: Implementation must provide optimization passes

The winner depends on regime: compilers excel when they can "see through" small, local code; explicit graphs excel at global rewrites and reducing abstraction overhead.

The implementation's interpreter involves:
- O(1) node fetch (array index)
- O(n) switch dispatch (n ≈ 12 node kinds)
- O(1) capture fetch
- One indirect call per operation

This overhead is measurable but typically dominated by actual parsing work. The graph representation enables optimizations (fusion, dead node elimination, lookahead computation) that closures preclude.

### 8.3 Expressiveness Boundary

The design enforces a precise boundary:

> **Runtime parameterization is admissible at leaf boundaries; runtime graph construction is not.**

The machine can express data-dependent control flow (via `Next`) and data-dependent consumption (via parameterized leaves), but not data-dependent syntax construction (building new composed parsers at runtime).

This boundary warrants examination through two cases that initially appear to require dynamic construction.

#### Case 1: Indentation-Sensitive Parsing

Languages like Python, Haskell, and YAML use indentation to delimit blocks. The naive approach seems to require dynamic parser construction:

```swift
// Apparent "impossible" pattern
flatMap { currentIndent in
    Parser.indentedBlock(minIndent: currentIndent + 1)
}
```

If `indentedBlock` were a composed parser whose topology depends on `currentIndent`, this would require runtime graph construction.

**The resolution**: Indentation sensitivity is not "need new grammar" but "need stateful constraint." The machine-native approach:

1. The `Input` layer exposes column/indent measurement
2. Parse state carries an indent stack (current baseline levels)
3. Leaf operations implement runtime-parameterized checks:
   - `measureIndent` → returns current column
   - `requireIndent(>= baseline + k)` → fails with labeled expectation if violated
   - `pushIndent` / `popIndent` → manage the indent stack

Then `indentedBlock(minIndent: x)` is a *static* graph that reads `x` from the value stack and uses runtime predicates—no dynamic construction required.

This matches industry practice: Python's lexer emits INDENT/DEDENT tokens; Haskell's layout rule is a stateful preprocessor. Both reduce indentation to state threading, not grammar synthesis.

#### Case 2: Length-Prefixed Binary Formats

Protocol Buffers, TLV structures, and similar formats parse a length field, then consume exactly that many bytes:

```swift
// Apparent "impossible" pattern
flatMap { length in
    Parser.bytes(count: length)
}
```

**The resolution**: `bytes(count:)` need not be a composed parser. It is a single leaf operation with a runtime parameter:

```swift
case consumeBytes(count: Value.Handle)  // count read from value stack at runtime
```

The leaf reads `count` from the value stack and advances input by that amount. Graph topology remains static; only the consumption amount varies.

#### The Remaining Open Question: Borrowed Output Discipline

Both cases resolve structurally—runtime-parameterized operations within static topology suffice. However, length-prefixed parsing surfaces a deeper question: **how should borrowed slices flow through the machine?**

Consider a leaf that consumes `n` bytes and returns a view into the input buffer. That view is borrowed—it cannot outlive the input. But `Machine.Value` currently uses `AnyObject` boxing, implying ownership transfer. Values flow through the stack, persist in memoization tables, and survive across interpreter steps.

A borrowed slice in that position would violate `~Escapable` constraints.

**Resolution strategies** (not yet adjudicated):

1. **Copy at leaf boundary**: Length-prefixed leaves return owned buffers. Zero-copy only within leaf execution, not across combinator boundaries. Safe but potentially expensive for large payloads.

2. **Stratified Value types**: Distinguish `Value.Owned` (flows anywhere) from `Value.Borrowed` (must be consumed within current frame). The interpreter enforces that borrowed values don't escape to memoization or cross frame boundaries.

3. **Input-relative handles**: Store `(start, count)` indices rather than data. Reconstruction happens at consumption sites from the still-live input. This is how tree-sitter represents parse results—ranges into the document, not extracted strings.

Option 3 aligns with incremental parsing requirements (results remain valid across re-parses of the same input) and avoids both copying and escape violations.

This is the only remaining place where Swift 6's `~Escapable` model materially constrains expressiveness beyond what the pressure tests initially suggested. The boundary is now precisely characterized: the question is not *whether* the machine can express these grammars, but *how* borrowed outputs should be represented when values flow through the machine.

---

## 9. Future Directions

### 9.1 Error Recovery as Explicit Nodes

Recovery strategies could become explicit node types:

```swift
case synchronize(delimiter: LeafPredicate, recover: ID)
case labeled(child: ID, expectation: String)
case accumulate(child: ID, maxErrors: Int)
```

This would make recovery inspectable and analyzable—potentially enabling optimization of recovery paths and better diagnostics.

### 9.2 Partial Evaluation

The explicit node representation enables partial evaluation—executing statically-known portions at compile time:

```swift
// Original
let parser = literal("HTTP/").then(version)

// After partial evaluation
// Optimized: match "HTTP/" as 5-byte prefix check, then parse version
```

This is conceptually similar to regex compilation to DFA.

### 9.3 Effects Integration

If Swift gains algebraic effects, parsers could be expressed as effect handlers:

```swift
// Hypothetical
effect Parser<Input, Failure> {
    func consume() -> Input.Element
    func fail(_ error: Failure) -> Never
    func checkpoint() -> Checkpoint
}
```

Effects are inherently defunctionalized and compose naturally, potentially recovering ergonomics lost to explicit machine construction.

### 9.4 Distributed Parsing

The serializable program representation suggests distributed parsing scenarios:

- Ship compiled parsers to edge nodes
- Cache compiled programs across process restarts
- Version and diff grammar changes

These require no architectural changes—they follow from the "parser as data" representation.

---

## 10. Trade-off Summary

| Axis | Closure-Based | Machine.Program |
|------|---------------|-----------------|
| Borrowed data | Prohibited by ~Escapable | Supported via non-capturing thunks |
| Sendability | @unchecked or infection | Structural via Mode |
| Inspectability | None | Full graph access |
| Incremental parsing | Requires external machinery | Native via memoization |
| Ergonomics | Direct closure syntax | Requires facade layer |
| Optimization | Compiler-driven | Implementation-driven |
| Error recovery | Mature ecosystem (chumsky, megaparsec) | Open problem |
| Dynamic construction | Supported | Prohibited |

---

## 11. Conclusion

The Swift `Machine.Program` design represents a principled response to constraints that other ecosystems can avoid. Swift 6's `~Escapable` creates a categorical prohibition—not a soft constraint—against closure-based combinators operating on borrowed views. Defunctionalization is forced, not chosen.

The implemented system demonstrates that the resulting architecture enables capabilities closure-based designs preclude:

- **Incremental parsing** with edit-aware cache invalidation
- **Structural Sendability** without escape hatches
- **Inspectable grammar graphs** supporting optimization and analysis

The primary limitation is error recovery—an area where Megaparsec and Chumsky set bars the current implementation does not meet. This should be the priority for future development.

The design's contribution is not defunctionalization itself (a 50-year-old technique) but being *compelled* into it by a mainstream language's type system and building a complete, working parser ecosystem on that foundation. The result is unusually aligned with concurrency safety and inspectability requirements that matter increasingly in production systems.

For library authors building parser infrastructure, `Machine.Program` provides a foundation that closure-based designs cannot match in Swift 6. For users writing grammars, the two-tier architecture preserves combinator ergonomics while compiling to the defunctionalized representation. This stratification—infrastructure versus interface—may be the design's most important insight: the right abstraction for implementers differs from the right abstraction for users, and a well-designed system provides both.

---

## References

1. Reynolds, J.C. (1972). Definitional interpreters for higher-order programming languages. *Proceedings of the ACM Annual Conference*.

2. Leijen, D., & Meijer, E. (2001). Parsec: Direct style monadic parser combinators for the real world. *Technical Report UU-CS-2001-35*, Universiteit Utrecht.

3. Ford, B. (2004). Parsing expression grammars: A recognition-based syntactic foundation. *POPL '04*.

4. Might, M., Darais, D., & Spiewak, D. (2011). Parsing with derivatives: A functional pearl. *ICFP '11*.

5. Krishnaswami, N. R., & Yallop, J. (2019). A typed, algebraic approach to parsing. *PLDI '19*.

6. Swift Evolution SE-0390: Noncopyable structs and enums.

7. Swift Evolution SE-NNNN: Primitives for ~Escapable types (draft).

8. The Rust nom library: https://github.com/rust-bakery/nom

9. The Rust chumsky library: https://github.com/zesterer/chumsky

10. The Rust winnow library: https://github.com/winnow-rs/winnow

11. The Haskell megaparsec library: https://github.com/mrkkrp/megaparsec

12. The OCaml angstrom library: https://github.com/inhabitedtype/angstrom

13. Boost.Spirit documentation: https://www.boost.org/doc/libs/release/libs/spirit/

---

*Document version 2.1.0. Last updated 2026-01-19.*
