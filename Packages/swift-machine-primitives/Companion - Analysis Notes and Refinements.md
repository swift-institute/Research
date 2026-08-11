# Companion Notes: Closure-Free Parser Combinators

<!--
---
document_type: supplementary_analysis
version: 1.1.0
date: 2026-01-19
author: Swift Institute
status: COMPLETE
accompanies: "Analysis - Closure-Free Parser Combinators.md"
revision_notes: Added Section 10 (Borrowed Output Discipline) with full design space analysis
---
-->

## Purpose

This document accompanies the comparative analysis of closure-free parser combinators in Swift 6. It provides additional context, documents key refinements that emerged during the analysis process, and offers deeper examination of specific technical points that merit extended discussion.

---

## 1. On "Categorical" vs. "Structural" Constraints

The main paper emphasizes that Swift 6's `~Escapable` creates a *categorical prohibition* against closure-based combinators. This framing was refined through analysis and deserves elaboration.

### The Distinction

**Structural constraint**: A design pressure that makes certain patterns difficult, expensive, or unidiomatic, but not impossible. Rust's ownership model creates structural constraints—you *can* write non-Send parsers, but the ecosystem discourages it.

**Categorical constraint**: A type system rule that makes certain patterns impossible to express. No amount of cleverness circumvents it; the compiler rejects the code.

Swift 6's treatment of `~Escapable` is categorical:

```swift
// This is not "hard to write" or "unidiomatic"
// It is rejected by the type checker
func capture(_ span: borrowing Span<UInt8>) -> @escaping () -> Void {
    return { _ = span }  // ERROR: cannot capture
}
```

### Why This Matters

The categorical nature of the constraint changes the design conversation. With structural constraints, you argue about trade-offs: "Is this worth the complexity?" With categorical constraints, you accept the boundary and design within it.

The defunctionalized `Machine.Program` architecture is not a preference—it is the only viable path for zero-copy parsing of borrowed views in Swift 6. This removes an entire class of "but what about..." objections from consideration.

---

## 2. FlatMap: Dynamic Control, Not Dynamic Construction

Early analyses suggested flatMap "resists defunctionalization" because it requires either finite continuation sets or stored closures. This was corrected during review.

### What the Design Actually Supports

```swift
case flatMap(child: ID, next: Next.Erased<Mode, ID>)
```

The `Next.Erased` contains a captured function `(Value) -> Node.ID` that can return *any* node based on the parsed value. The function is not limited to a declared set of targets.

### What It Cannot Do

Runtime node *construction* is prohibited:

```swift
// Cannot create new nodes based on parsed values
flatMap { length in
    Parser.bytes(count: length)  // Would require runtime allocation
}
```

### Why This Is Acceptable

1. **Shared by most parser systems**: yacc, ANTLR, regex engines, and Boost.Spirit all require static grammars.

2. **Idiomatic in practice**: Even in Haskell/Rust where dynamic construction is possible, most real parsers use static combinator composition.

3. **Required for key features**: Incremental parsing with memoization requires stable node identity. Dynamic construction would invalidate caches unpredictably.

### The Accurate Characterization

> FlatMap represents a *dynamic control boundary* within an otherwise structural graph. It supports arbitrary dispatch but not arbitrary construction.

This boundary has implications for optimization (rewrite rules must be dispatch-preserving) and analysis (control flow is data-dependent), but it does not fundamentally limit the expressible grammars.

---

## 3. Mode Stratification: Concurrency Boundaries, Not Safety Escapes

The `Mode.Reference` / `Mode.Unchecked` distinction requires careful framing.

### What Mode.Unchecked Is Not

It is not analogous to Rust's `unsafe`:

| Rust `unsafe` | Swift `Mode.Unchecked` |
|---------------|------------------------|
| Permits memory unsafety | Memory always safe |
| Permits data races | Data races still impossible |
| Compiler trusts programmer | Compiler still enforces rules |
| Can cause undefined behavior | Cannot cause UB |

### What Mode.Unchecked Is

A *concurrency stratification* that permits non-Sendable captures while preventing cross-isolation sharing:

```swift
// Mode.Unchecked program: captures non-Sendable data
let local: Machine.Program<L, F, Mode.Unchecked> = ...

// Cannot send across actor boundaries
await someActor.use(local)  // ERROR: not Sendable

// Safe within single-threaded context
local.execute(&input)  // OK
```

### Legitimate Use Cases

- **Embedded parsers**: Constructed and consumed within a single scope
- **Single-threaded applications**: No concurrency, no sharing needed
- **Migration**: Gradual adoption of Sendable discipline

### The Haskell ST Parallel

Haskell's `ST` monad provides region-based isolation via rank-2 types:

```haskell
runST :: (forall s. ST s a) -> a
```

`Mode.Unchecked` provides isolation via Sendable conformance absence. Similar stratification, different mechanism. The parallel is useful but should not be overstated—`ST` guarantees non-escape within a region; `Mode.Unchecked` guarantees non-sharing across isolation domains.

---

## 4. The Haskell CPS Insight

The main paper notes that Parsec, megaparsec, and attoparsec use continuation-passing internally. This deserves expansion.

### Parsec's Representation

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

The four continuation parameters are *explicit*. The `forall b` quantification prevents storing them—they must be invoked immediately.

### This Is Already Defunctionalization

CPS with rank-2 types is defunctionalization in disguise:

- Continuations are explicit parameters (not stored closures)
- Polymorphism enforces immediate invocation (no capture)
- State is explicitly threaded (not implicitly captured)

### Why Swift Cannot Hide This

Haskell's approach works because:

1. **Laziness**: Parser "construction" is cheap (deferred evaluation)
2. **Purity**: Compiler can inline and transform freely
3. **GHC**: World-class optimizer handles the abstraction

Swift has none of these. The machine boundary must be explicit because it cannot be hidden implicitly.

### The Design Lesson

Successful parser combinator implementations already tend toward explicit continuation/state management. `Machine.Program` makes this explicit in the *surface representation* rather than hiding it behind a monadic interface. This is not a departure from best practice—it is best practice made visible.

---

## 5. Incremental Parsing: The Implemented System

The main paper documents that swift-parsing-primitives includes working incremental parsing. This section provides additional implementation context.

### Memoization Architecture

Cache entries are keyed by `(Checkpoint, Node.ID)`:

```swift
struct Key<Checkpoint: Hashable> {
    let position: Checkpoint
    let node: Machine.Node.ID
}

enum Entry<Checkpoint> {
    case success(output: Machine.Value, end: Checkpoint)
    case failure
}
```

### Why Cache Failures?

Packrat parsing's linear-time guarantee requires caching *negative* results. Without failure caching:

```
expr → term (('+' | '-') term)*
term → factor (('*' | '/') factor)*
factor → number | '(' expr ')'
```

Parsing `1 + 2` would re-attempt `'(' expr ')'` at position 0 multiple times during backtracking. Failure caching ensures each (position, node) pair is computed exactly once.

### Edit Invalidation

The memoization table supports precise invalidation:

```swift
struct Edit<Checkpoint: Comparable> {
    let start: Checkpoint
    let oldEnd: Checkpoint
    let newEnd: Checkpoint
}
```

Invalidation logic:

- **Success entries**: Invalidate if the cached result's span overlaps the edit range
- **Failure entries**: Invalidate if at or after `edit.start`

This enables O(edit size + affected parses) re-parsing, not O(document size).

### Why This Requires Defunctionalization

Memoization keys require stable identity for grammar nodes. With closure-based parsers:

```swift
// No stable identity—new closure each time
let parser = input.map { $0.uppercased() }
```

With `Machine.Program`:

```swift
// Stable identity—node ID is an integer
let node = Node.ID(42)  // Same ID across parses
```

Incremental parsing is not merely *enabled* by defunctionalization—it *requires* it.

---

## 6. Error Recovery: The Primary Gap

The main paper identifies error recovery as the most significant limitation. This section catalogs specific missing capabilities.

### What Exists

- **Backtracking**: `OneOf` saves/restores checkpoints on failure
- **Typed throws**: `throws(Failure)` preserves error type information
- **Error transformation**: `.error.map()` and `.error.replace(with:)`

### What Is Missing

**Synchronization combinators** (Chumsky-style):

```swift
// Does not exist yet
case synchronize(until: LeafPredicate, then: ID)
case skipUntil(delimiter: LeafPredicate)
```

**Multiple error accumulation** (Megaparsec-style):

```swift
// Does not exist yet
case accumulate(child: ID, maxErrors: Int, recovery: ID)
```

**Labeled expectations**:

```swift
// Does not exist yet
case labeled(child: ID, expectation: String)
// Produces: "Expected <expectation> at position N"
```

**Commit/cut operators**:

```swift
// Does not exist yet
case commit(child: ID)  // Prevent backtracking after success
```

### Why This Matters

Parser frameworks are judged by diagnostic quality at least as much as raw performance. Users tolerate slower parsers with good error messages; they abandon fast parsers with cryptic failures.

Megaparsec and Chumsky set industry bars for error recovery. Meeting those bars requires extending the node vocabulary and frame types—real design work, not just implementation.

---

## 7. Optimization Ownership

The main paper notes that defunctionalization shifts optimization responsibility from compiler to implementation. This section provides context.

### The Closure-Based Baseline

Closure-based combinators *can* be fast when:

- Parsers remain monomorphic (no existential boxing)
- Closures remain non-escaping (inlining possible)
- Nesting stays shallow (optimizer can see through)

In practice, these conditions often fail:

- Protocol existentials (`any Parser`) defeat inlining
- Escaping closures prevent optimization
- Deep generic nesting stresses the optimizer

### The Machine-Based Model

The interpreter's per-operation cost:

| Operation | Cost |
|-----------|------|
| Node fetch | O(1) array index |
| Kind dispatch | O(1) switch on ~12 cases |
| Capture fetch | O(1) array index |
| Transform apply | 1 indirect call |

This is comparable to a closure chain's indirect call overhead, with better cache locality (contiguous arrays vs. scattered heap allocations).

### Enabled Optimizations

The explicit graph enables optimizations closures preclude:

| Optimization | Description |
|--------------|-------------|
| Map fusion | `map(map(x, f), g)` → `map(x, g∘f)` |
| Dead node elimination | Remove unreachable nodes |
| Lookahead computation | First/follow sets for predictive parsing |
| Common subexpression | Share identical subgraphs |

### The Honest Assessment

Neither representation dominates. Closures win when the compiler can see through them. Graphs win when global structure matters. The design bets that parser programs benefit from global analysis—a reasonable bet for non-trivial grammars.

---

## 8. Typed Heterogeneous Erasure

The capture store's type erasure strategy deserves separate attention as a contribution independent of parsing.

### The Problem

Store values of different types in a single container while:

- Preserving type safety at access sites
- Avoiding protocol existential overhead
- Supporting heterogeneous insertion order

### Traditional Approaches

| Approach | Drawback |
|----------|----------|
| `[any Protocol]` | Dynamic dispatch, witness tables |
| Enum with cases | Closed set, boilerplate |
| `[Any]` + casting | No compile-time safety |
| Generics | Homogeneous only |

### The Solution

```swift
struct ID<Value>: Hashable, Sendable {
    let raw: RawID
}

struct Entry {
    let box: AnyObject          // Type-erased storage
    let type: ObjectIdentifier  // Runtime type tag
}

func with<Value, R>(_ id: ID<Value>, _ body: (borrowing Value) -> R) -> R {
    let entry = entries[id.raw.rawValue]
    precondition(entry.type == ObjectIdentifier(Value.self))
    let box = entry.box as! Box<Value>
    return body(box.value)
}
```

### Properties Achieved

- **Heterogeneous**: Different `ID<T>` types coexist
- **Type-safe**: `ID<Value>` at call site ensures correct extraction
- **Verified**: Runtime check catches ID misuse (debug builds)
- **No existentials**: `AnyObject` + `ObjectIdentifier`, not protocol witnesses

This pattern is applicable beyond parsing—any system needing typed handles into heterogeneous storage.

---

## 9. The Two-Tier Architecture

The implemented system confirms the predicted two-tier structure.

### Tier 1: Combinator API

```swift
let parser = Parsing.OneOf {
    Parsing.Literal("GET")
    Parsing.Literal("POST")
}
let method = try parser.parse(&input)
```

Users write familiar combinators. No exposure to nodes, IDs, or captures.

### Tier 2: Machine API

```swift
let compiled = parser.parse.compiled()
var ctx = compiled.parse.incremental
let result = try ctx(&input)
ctx.invalidate(edit)
let updated = try ctx(&editedInput)
```

Advanced users access the compiled program for:

- Stack-safe execution (deeply nested grammars)
- Incremental parsing (IDE integration)
- Program inspection (debugging, optimization)

### The Design Principle

> The right abstraction for implementers differs from the right abstraction for users.

Library authors work with `Machine.Program`. Users work with combinators. The compilation boundary is explicit and crossable when needed.

---

## 10. Borrowed Output Discipline: Design Space Analysis

The main paper identifies borrowed output discipline as the remaining open question after pressure-testing against indentation-sensitive and length-prefixed parsing. This section provides the full design space analysis.

### The Problem in Detail

`Machine.Value` uses `AnyObject` boxing:

```swift
struct Value {
    let type: ObjectIdentifier
    let box: AnyObject  // Heap-allocated, reference-counted
}
```

This representation implies *ownership transfer*. When a leaf parser returns a `Value`, that value can:

- Flow through the interpreter's value stack
- Be stored in memoization tables (for incremental parsing)
- Persist across frame boundaries
- Survive arbitrary interpreter steps

For owned data (copies, computed results), this is fine. For *borrowed* data (slices/spans into the input buffer), this creates a lifetime violation: the borrowed view might outlive its source.

### Why Memoization Breaks Naive Borrows

Consider length-prefixed parsing with memoization enabled:

```
Input: [4, 'a', 'b', 'c', 'd', ...]
       ^
       Parse length (4), then parse 4 bytes
```

If `bytes(count: 4)` returns a borrowed slice, the memoization table would store:

```swift
cache[(position: 1, node: bytesNode)] = .success(
    output: borrowedSlice,  // Points into input buffer
    end: 5
)
```

Now suppose the input buffer is mutated (for incremental re-parsing) or deallocated. The cached `borrowedSlice` becomes a dangling reference.

With owned data (copies), the cache is self-contained. With borrowed data, the cache depends on external lifetime guarantees the type system cannot express through `AnyObject`.

### Resolution Strategy 1: Copy at Leaf Boundary

**Approach**: Leaves that consume variable-length input always return owned copies.

```swift
// Leaf implementation
func consumeBytes(count: Int, input: inout Input) -> Value {
    let slice = input.prefix(count)
    input.advance(by: count)
    return Value.make(Array(slice))  // Copy to owned buffer
}
```

**Properties**:

| Aspect | Assessment |
|--------|------------|
| Safety | Fully safe—no borrows escape |
| Performance | O(n) copy per variable-length parse |
| Memoization | Works correctly—cached values are self-contained |
| Memory | Higher usage—data duplicated in cache and final result |

**When appropriate**: Small payloads, infrequent variable-length parses, or when memoization benefits outweigh copy costs.

### Resolution Strategy 2: Stratified Value Types

**Approach**: Distinguish owned and borrowed values at the type level.

```swift
enum Value {
    case owned(type: ObjectIdentifier, box: AnyObject)
    case borrowed(type: ObjectIdentifier, slice: UnsafeBufferPointer<UInt8>)
}
```

The interpreter enforces discipline:

- Borrowed values *must* be consumed within the current frame
- Borrowed values *cannot* be stored in memoization tables
- Transforms on borrowed values must either consume immediately or copy

```swift
// Interpreter enforcement
case .map(let child, let transform):
    let childValue = evaluate(child)
    if case .borrowed = childValue {
        // Must consume or copy before frame exit
        let result = transform.apply(childValue)
        // result must be .owned (transform performed copy)
    }
```

**Properties**:

| Aspect | Assessment |
|--------|------------|
| Safety | Safe if discipline enforced correctly |
| Performance | Zero-copy where possible, copy only when escaping |
| Memoization | Only owned values cached; borrowed results not memoized |
| Memory | Lower than Strategy 1 for non-memoized paths |
| Complexity | Significant interpreter complexity; easy to get wrong |

**When appropriate**: Performance-critical parsing of large payloads where memoization is disabled or selective.

### Resolution Strategy 3: Input-Relative Handles

**Approach**: Never store actual data in `Value`. Store indices/ranges that reference the input.

```swift
struct ByteRange: Hashable, Sendable {
    let start: Int
    let count: Int
}

// Leaf returns range, not data
func consumeBytes(count: Int, input: inout Input) -> Value {
    let start = input.currentOffset
    input.advance(by: count)
    return Value.make(ByteRange(start: start, count: count))
}
```

Actual data extraction happens at *consumption sites*:

```swift
// When the parse result is finally used
let range: ByteRange = parseResult.extract()
let bytes = input[range.start ..< range.start + range.count]
```

**Properties**:

| Aspect | Assessment |
|--------|------------|
| Safety | Fully safe—ranges are pure data, no pointers |
| Performance | Zero-copy during parsing; extraction at use site |
| Memoization | Works correctly—ranges remain valid across re-parses |
| Memory | Minimal—only indices stored, not data |
| Incremental | Excellent—ranges into new input remain semantically valid |

**The tree-sitter parallel**: This is exactly how tree-sitter represents parse results. A syntax tree contains `(start, end)` ranges into the source document, not extracted strings. This enables:

- Efficient re-parsing (ranges are cheap to invalidate/update)
- Memory efficiency (one copy of source, ranges point into it)
- Incremental updates (edit shifts ranges, doesn't invalidate cache structure)

**When appropriate**: Most scenarios, especially when incremental parsing is a priority.

### Interaction with ~Escapable

Swift 6's `~Escapable` types (like `Span<UInt8>`) cannot be stored in `Value` regardless of strategy—they are non-escaping by definition. However, the *indices* that would reconstruct a `Span` can be stored.

The discipline becomes:

1. Leaves accept `borrowing Input` (non-escaping)
2. Leaves compute ranges/indices from the input
3. Leaves return owned `Value` containing ranges
4. Final consumers reconstruct borrowed views from ranges + input

This is compatible with `~Escapable` because the borrowed view is reconstructed at the final use site, not stored through the machine.

### Recommendation

**Strategy 3 (input-relative handles)** should be the default for several reasons:

1. **Aligns with incremental parsing**: The implemented memoization system already works with checkpoints (positions). Extending to ranges is natural.

2. **Zero runtime lifetime tracking**: No need for interpreter enforcement of borrow discipline.

3. **Proven at scale**: tree-sitter parses millions of lines of code using this approach.

4. **Composable**: Ranges compose (substring of substring is still a range) without pointer arithmetic.

Strategy 1 (copy) remains appropriate for small, frequently-accessed values where copy overhead is negligible.

Strategy 2 (stratified) is the most complex and should be avoided unless profiling demonstrates that Strategy 3's deferred extraction is a bottleneck.

### Open Design Questions

Even with Strategy 3, some questions remain:

1. **Range representation**: Should ranges be byte offsets, character offsets, or abstract positions? Byte offsets are simplest but complicate UTF-8 string handling.

2. **Input identity**: If multiple inputs are parsed, how do ranges identify their source? A generation counter or input ID may be needed.

3. **Lazy vs. eager extraction**: Should the final parse result be `ByteRange` (lazy) or should there be an explicit "materialize" step? Lazy is more flexible but pushes complexity to consumers.

These are implementation details rather than fundamental obstacles. The architecture supports all reasonable choices.

---

## 11. Summary of Refinements

This analysis process produced several key refinements to the paper's claims:

| Original Framing | Refined Framing |
|------------------|-----------------|
| "Tension" with closures | "Categorical prohibition" |
| FlatMap requires finite continuations | FlatMap supports dynamic dispatch, prohibits dynamic construction |
| Mode.Unchecked is an escape hatch | Mode.Unchecked is concurrency stratification |
| Thunk distinction is novel | Systematic exploitation for Sendability is novel |
| Incremental parsing is future work | Incremental parsing is implemented and working |
| Error recovery is a limitation | Error recovery is the *primary* limitation |
| Expressiveness boundary unclear | Runtime parameterization at leaves; no runtime graph construction |
| Borrowed outputs unaddressed | Input-relative handles as recommended discipline |

These refinements strengthen rather than weaken the paper's thesis: Swift 6 compels defunctionalization, and the resulting architecture enables capabilities—particularly incremental parsing—that closure-based designs cannot match.

---

*Document version 1.1.0. Last updated 2026-01-19.*
