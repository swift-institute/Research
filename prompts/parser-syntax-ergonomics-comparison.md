# Research Prompt: Parser Syntax & Ergonomics Comparison

## Instructions

Execute `/research-process` (Investigation workflow, Tier 2) to produce a comparative analysis between **pointfreeco/swift-parsing** and our **swift-parser-primitives** + **swift-ascii-parser-primitives** packages. Focus exclusively on syntax and ergonomics — not performance, not architecture philosophy.

Output: `swift-institute/Research/parser-syntax-ergonomics-comparison.md`

---

## Context

We are establishing `var body` as the canonical pattern for composed parsers in our ecosystem. Before documenting this as PATTERN-023 in our implementation skill, we need a clear-eyed comparison against the leading Swift parsing library to understand where our syntax is better, equivalent, or worse — and what we can learn.

We just completed a reference test suite (`swift-ascii-parser-primitives/Tests/Declarative Parser Syntax Tests/`) demonstrating our canonical `var body` syntax. This is the baseline for "our best."

---

## Research Question

**How does our parser composition syntax compare to pointfreeco/swift-parsing in ergonomics, readability, and boilerplate?**

Sub-questions:
1. What does equivalent functionality look like side-by-side?
2. Where is our syntax strictly better (less boilerplate, more readable)?
3. Where is pointfree's syntax strictly better?
4. What specific improvements could we adopt without compromising our architectural constraints (typed throws, ~Copyable support, no Foundation)?

---

## Our System (provide to the new chat)

### Core Protocol

```swift
// Parser.Protocol — three associated types
public protocol Protocol<Input, Output, Failure> {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Error & Sendable
    associatedtype Body

    @Parser.Builder<Input>
    var body: Body { get }

    func parse(_ input: inout Input) throws(Failure) -> Output
}
```

- **Leaf parsers**: implement `func parse` directly, `Body == Never`
- **Composed parsers**: implement `var body`, default `parse` delegates to body
- **Typed throws**: `Failure` associated type, composed errors use `Parser.Error.Either<L, R>`
- **Input**: generic, supports `~Copyable & ~Escapable` (Span-based zero-copy)

### Composition Syntax (our canonical form)

```swift
// Domain type: Nest.Name pattern
struct Network {
    struct Endpoint: Equatable, Sendable {
        let host: UInt16
        let port: UInt16
    }
}

// Parser lives on the domain type
extension Network.Endpoint {
    struct Parser<Input: Collection.Slice.Protocol & Parser.Streaming>: Sendable
    where Input: Sendable, Input.Element == UInt8 {
        init() {}
    }
}

extension Network.Endpoint.Parser: Parser.Protocol {
    typealias Output = Network.Endpoint
    typealias Failure = Network.Endpoint.Error

    var body: some Parser.Protocol<Input, Network.Endpoint, Network.Endpoint.Error> {
        Parser.Take.Sequence {
            ASCII.Decimal.Parser<_, UInt16>()    // type placeholder inference
            ":"                                    // string literal → Parser.Literal
            ASCII.Decimal.Parser<_, UInt16>()
        }
        .map { host, port in Network.Endpoint(host: host, port: port) }
        .error.map { (either) -> Network.Endpoint.Error in
            switch either {
            case .right:        .invalidPort
            case .left(.left):  .invalidHost
            case .left(.right): .expectedColon
            }
        }
    }
}
```

### Three-value composition (tuple flattening via parameter packs)

```swift
Parser.Take.Sequence {
    ASCII.Decimal.Parser<_, UInt16>()
    ","
    ASCII.Decimal.Parser<_, UInt16>()
    ","
    ASCII.Decimal.Parser<_, UInt16>()
}
.map { x, y, z in Geometry.Point(x: x, y: y, z: z) }
```

### Nested composition (composed parser inside composed parser)

```swift
Parser.Take.Sequence {
    Network.Endpoint.Parser<Input>()
    "/"
    ASCII.Decimal.Parser<_, UInt16>()
}
.map { endpoint, weight in Weighted.Endpoint(endpoint: endpoint, weight: weight) }
```

### Key Infrastructure

| Module | Purpose |
|--------|---------|
| Parser Primitives Core | Protocol, Builder, Input types |
| Parser Take Primitives | Sequential composition, tuple flattening, Void-skipping |
| Parser Skip Primitives | Discard Void-producing parser outputs |
| Parser Map Primitives | Output transformation |
| Parser Error Primitives | Either<L,R> error composition, .error.map |
| Parser Literal Primitives | Byte sequence matching, ExpressibleByStringLiteral |
| Parser OneOf Primitives | Alternative/choice composition |
| Parser Many Primitives | Repetition |
| Parser Prefix Primitives | Prefix consumption |
| Parser Backtrack Primitives | Checkpoint/restore |
| ASCII Decimal Parser Primitives | ASCII.Decimal.Parser leaf |
| ASCII Hexadecimal Parser Primitives | ASCII.Hexadecimal.Parser leaf |

### Findings from our test suite

1. Bare `":"` string literals work in builders — but required adding a concrete `buildExpression` overload for `Parser.Literal` (the generic overload causes compiler inference failure)
2. `<_, UInt16>` type placeholder works for Input inference from builder context
3. Compound constraint `Collection.Slice.Protocol & Parser.Streaming` is required when mixing ASCII parsers with Literal
4. Module qualification (`Parser_Primitives.Parser.Protocol`) is needed when the type is named `Subject.Parser` (clashes with the `Parser` namespace)
5. `.error.map` with nested `Either` switching is verbose but provides exhaustive typed error handling

---

## Comparison Dimensions

Evaluate these specific dimensions:

### 1. Parser Definition Boilerplate
How much scaffolding is needed to define a composed parser? Count: type declarations, typealiases, generic constraints, protocol conformance ceremony.

### 2. Builder Body Readability
Compare the DSL inside the builder body. How natural does the grammar read? How much noise is there from type annotations, qualifications, explicit generics?

### 3. Error Handling Ergonomics
Compare error composition. Our `Either<L,R>` tree + `.error.map` vs pointfree's approach. Which gives better diagnostics? Which requires less boilerplate?

### 4. String Literal / Delimiter Syntax
How do both handle literal matching in builder bodies?

### 5. Output Mapping / Tuple Handling
How do both handle converting parsed tuples to domain types? Void-skipping mechanics?

### 6. Nested Composition
How do both handle a composed parser using another composed parser?

### 7. Generic Constraints / Input Abstraction
How constrained are the types? Can parsers be written without specifying Input?

### 8. Ad-hoc / Inline Parsing
Can you parse something quickly without defining a new type?

---

## Methodology

1. **Read pointfree/swift-parsing source** — specifically `Parser.swift`, `ParserBuilder.swift`, `Parsers/` directory. Use the `main` branch on GitHub (`pointfreeco/swift-parsing`).
2. **Read our test suite** at `swift-ascii-parser-primitives/Tests/Declarative Parser Syntax Tests/Declarative Parser Syntax Tests.swift` and the builder infrastructure at `swift-parser-primitives/Sources/Parser Take Primitives/Parser.Builder+Take.swift`.
3. **Write equivalent parsers in both syntaxes** for the same problems (host:port, x,y,z coordinate, nested composition).
4. **Produce comparison tables** for each dimension.
5. **Identify concrete improvements** we could adopt, with cost/benefit assessment.

---

## Constraints on Recommendations

Any proposed improvement MUST be compatible with:
- Typed throws (`Failure` associated type, no `any Error`)
- `~Copyable & ~Escapable` input support
- No Foundation dependency
- Subject-first naming (`ASCII.Decimal.Parser`, not `Parsers.ASCII.Decimal`)
- Strict memory safety
- The existing builder infrastructure (result builders, not macros)

---

## Deliverable

A research document at `swift-institute/Research/parser-syntax-ergonomics-comparison.md` following [RES-003] structure with:
- Side-by-side code examples for each dimension
- Comparison table summarizing strengths/weaknesses
- Prioritized list of actionable improvements
- Status: RECOMMENDATION
