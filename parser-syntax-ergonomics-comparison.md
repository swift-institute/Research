# Parser Syntax & Ergonomics Comparison

<!--
---
status: RECOMMENDATION
tier: 2
date: 2026-03-05
scope: swift-parser-primitives, swift-ascii-parser-primitives
question: How does our parser composition syntax compare to pointfreeco/swift-parsing?
---
-->

> **Research Question**: How does our parser composition syntax compare to pointfreeco/swift-parsing in ergonomics, readability, and boilerplate?

## Executive Summary

Our `var body` parser composition syntax is architecturally stronger (typed throws, `~Copyable` input support, generic `Input`) but syntactically heavier than pointfree's. The gap is largest in **error handling** (our `Either` tree switching is verbose), **parser definition boilerplate** (our generic constraints add ceremony), and **ad-hoc parsing** (we lack a lightweight inline entry point). The gap is smallest in **builder body readability** (nearly equivalent) and **tuple/Void handling** (parameter pack flattening is elegant). Several concrete improvements are identified that preserve our architectural constraints.

---

## Systems Under Comparison

### Our System (swift-parser-primitives + swift-ascii-parser-primitives)

- **Protocol**: `Parser.Protocol<Input, Output, Failure>` — three associated types
- **Body pattern**: `var body` for composed parsers, `func parse` for leaf parsers
- **Error composition**: `Parser.Error.Either<L, R>` — typed, nested, exhaustive
- **Input**: Generic with `~Copyable & ~Escapable` support (Span-compatible)
- **Literals**: `Parser.Literal` + `ExpressibleByStringLiteral` (requires `buildExpression` overload)
- **Entry point**: `Parser.Take.Sequence { ... }`
- **Reference**: `swift-ascii-parser-primitives/Tests/Declarative Parser Syntax Tests/`

### pointfree/swift-parsing (v0.13+, main branch)

- **Protocol**: `Parser<Input, Output>` — two associated types
- **Body pattern**: `var body` for composed parsers, `func parse` for leaf parsers
- **Error handling**: Untyped `throws` with `ParsingError` (runtime location info)
- **Input**: `Collection where SubSequence == Self` (defaults to `Substring`)
- **Literals**: `String` conforms to `Parser` directly
- **Entry point**: `Parse { ... }` or `Parse(.memberwise(T.init)) { ... }`
- **Additional**: Parser-printer duality via `ParserPrinter` protocol

---

## Dimension 1: Parser Definition Boilerplate

### pointfree — Ad-hoc (no type definition needed)

```swift
let endpoint = Parse(.memberwise(Endpoint.init)) {
    Int.parser()
    ":"
    Int.parser()
}
```

**Lines**: 5. **Type declarations**: 0. **Typealiases**: 0. **Generic constraints**: 0.

### pointfree — Reusable parser type

```swift
struct EndpointParser: Parser {
    var body: some Parser<Substring, Endpoint> {
        Parse(.memberwise(Endpoint.init)) {
            Int.parser()
            ":"
            Int.parser()
        }
    }
}
```

**Lines**: 9. **Type declarations**: 1. **Typealiases**: 0. **Generic constraints**: 0.

### Ours — Reusable parser type (canonical form)

```swift
extension Network.Endpoint {
    struct Parser<Input: Collection.Slice.Protocol & Parser.Streaming>: Sendable
    where Input: Sendable, Input.Element == UInt8 {
        init() {}
    }
}

extension Network.Endpoint.Parser: Parser_Primitives.Parser.Protocol {
    typealias Output = Network.Endpoint
    typealias Failure = Network.Endpoint.Error

    var body: some Parser_Primitives.Parser.Protocol<
        Input, Network.Endpoint, Network.Endpoint.Error
    > {
        Parser_Primitives.Parser.Take.Sequence {
            ASCII.Decimal.Parser<_, UInt16>()
            ":"
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

**Lines**: 25. **Type declarations**: 1 + 2 extensions. **Typealiases**: 2. **Generic constraints**: 4.

### Verdict

| Metric | pointfree (ad-hoc) | pointfree (reusable) | Ours |
|--------|-------------------|---------------------|------|
| Lines | 5 | 9 | 25 |
| Type declarations | 0 | 1 | 1 + 2 extensions |
| Typealiases | 0 | 0 | 2 |
| Generic parameters | 0 | 0 | 1 (Input) |
| Generic constraints | 0 | 0 | 4 |

**pointfree is significantly less boilerplate** for both ad-hoc and reusable parsers. However, our ceremony pays for: typed errors (`Failure`), generic input (`Input`), and subject-first naming (`Network.Endpoint.Parser`). These are architectural features, not accidental verbosity.

**What accounts for the difference**:

| Source of ceremony | Lines | Architectural reason |
|--------------------|-------|---------------------|
| Generic `Input` + constraints | 3 | Span/zero-copy support |
| `typealias Output/Failure` | 2 | Typed throws |
| Separate struct + extension | 4 | Subject-first naming [API-NAME-001] |
| Module-qualified `Parser_Primitives.Parser.Protocol` | 1 | Name clash with `Subject.Parser` |
| `.error.map { ... }` block | 6 | Exhaustive error mapping |
| `init() {}` | 1 | No stored properties |

---

## Dimension 2: Builder Body Readability

### pointfree

```swift
Int.parser()
":"
Int.parser()
```

### Ours

```swift
ASCII.Decimal.Parser<_, UInt16>()
":"
ASCII.Decimal.Parser<_, UInt16>()
```

### Comparison

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Leaf parser reference | `Int.parser()` | `ASCII.Decimal.Parser<_, UInt16>()` |
| Type information | Implicit (Int inferred from context) | Explicit (`UInt16` output type visible) |
| Delimiter syntax | `":"` (String is Parser) | `":"` (Parser.Literal + ExpressibleByStringLiteral) |
| Namespace noise | None | `ASCII.Decimal.` prefix |
| Generic noise | None | `<_, UInt16>` placeholder |

**Verdict**: pointfree reads more naturally for casual use. Ours is more explicit: `ASCII.Decimal.Parser<_, UInt16>()` tells you exactly what specification is being parsed and to what type. The `<_, UInt16>` placeholder is syntactic noise that carries real information (the output type).

The fundamental difference is design philosophy: pointfree extends stdlib types (`Int.parser()`), while we use specification-mirroring names (`ASCII.Decimal.Parser`) per [API-NAME-003]. Neither is wrong — they serve different goals.

---

## Dimension 3: Error Handling Ergonomics

### pointfree

```swift
// No error mapping needed. Errors are ParsingError with location info.
let endpoint = Parse(.memberwise(Endpoint.init)) {
    Int.parser()
    ":"
    Int.parser()
}
// Error on failure: ParsingError.failed("expected integer", at: input position)
```

**Error boilerplate**: 0 lines.
**Error type**: Runtime `ParsingError` with formatted location info.
**Exhaustiveness**: None (runtime inspection only).

### Ours — Two parsers (3 components)

```swift
.error.map { (either) -> Network.Endpoint.Error in
    switch either {
    case .right:        .invalidPort
    case .left(.left):  .invalidHost
    case .left(.right): .expectedColon
    }
}
```

**Error boilerplate**: 6 lines.

### Ours — Three parsers (5 components)

```swift
.error.map { (either) -> Geometry.Point.Error in
    switch either {
    case .right:                        return .invalidZ
    case .left(.right):                 return .expectedComma
    case .left(.left(.right)):          return .invalidY
    case .left(.left(.left(.right))):   return .expectedComma
    case .left(.left(.left(.left))):    return .invalidX
    }
}
```

**Error boilerplate**: 9 lines. **Nesting depth**: 4.

### Analysis

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Boilerplate | None | 6-9+ lines per parser |
| Type safety | Runtime (untyped throws) | Compile-time (typed throws + Either) |
| Exhaustiveness | No | Yes (switch must cover all cases) |
| Domain errors | Requires manual try/catch wrapping | Built-in via `.error.map` |
| Growth | Constant (0 lines) | Linear with parser count |
| Error location info | Rich (source position, context) | Structural (Either position encodes which parser failed) |

**Verdict**: This is the biggest ergonomic gap. pointfree requires zero error ceremony. Ours provides compile-time exhaustiveness but at severe verbosity cost. The nested `Either` patterns (`.left(.left(.left(.right)))`) are difficult to read and write correctly. For 5 components, the deepest nesting is 4 levels.

**Key insight**: The Either tree is left-nested because `buildPartialBlock(accumulated:next:)` composes left-to-right, wrapping the accumulated result. So the *first* parser's error is at the deepest nesting level (`.left(.left(.left(.left)))`) while the *last* parser's error is at the top (`.right`). This is counterintuitive — the first thing parsed has the deepest error path.

---

## Dimension 4: String Literal / Delimiter Syntax

### pointfree

```swift
// String conforms to Parser. Works everywhere, all input types.
Int.parser()
","
Int.parser()
```

No special infrastructure needed. `String`, `String.UTF8View`, `String.UnicodeScalarView`, and `[Element]` all conform to `Parser` directly.

### Ours

```swift
// Requires buildExpression overload for type inference
ASCII.Decimal.Parser<_, UInt16>()
":"
ASCII.Decimal.Parser<_, UInt16>()
```

Without the `buildExpression` overload:

```swift
// Explicit cast needed
":" as Parser.Literal<Input>
```

The `buildExpression` overload must be added per input constraint set:

```swift
extension Parser.Take.Builder
where Input: Parser.Streaming & Sendable, Input.Element == UInt8 {
    static func buildExpression(
        _ literal: Parser.Literal<Input>
    ) -> Parser.Literal<Input> {
        literal
    }
}
```

### Verdict

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Works out of the box | Yes | No (requires buildExpression) |
| Type inference | Automatic | Needs concrete overload |
| Input type coverage | All (String, UTF8, ArraySlice) | Per-constraint-set |
| Underlying mechanism | String: Parser conformance | ExpressibleByStringLiteral |

**pointfree is slightly better** because their approach works universally without special builder extensions. Once our `buildExpression` overload is promoted from the test suite to `Parser Literal Primitives` (or `Parser Take Primitives`), the difference disappears at the call site.

**Action item**: Promote the `buildExpression` overload to production code.

---

## Dimension 5: Output Mapping / Tuple Handling

### pointfree

```swift
// Option 1: memberwise conversion (unsafeBitCast-based)
Parse(.memberwise(Coordinate.init)) {
    Double.parser()
    ","
    Double.parser()
}

// Option 2: explicit map
Parse {
    Double.parser()
    ","
    Double.parser()
}
.map { Coordinate(x: $0, y: $1) }
```

Void-skipping is built into the builder. Tuple flattening via builder overloads.

`.memberwise` uses `unsafeBitCast` internally — fragile for custom initializers or reordered fields. Can crash at runtime.

### Ours

```swift
Parser.Take.Sequence {
    ASCII.Decimal.Parser<_, UInt16>()
    ","
    ASCII.Decimal.Parser<_, UInt16>()
}
.map { x, y in Coordinate(x: x, y: y) }
```

Void-skipping is built into the builder. Tuple flattening via parameter packs (`(repeat each O1, O2)`).

No `.memberwise` equivalent — explicit `.map` closure always required.

### Verdict

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Void-skipping | Yes (builder overloads) | Yes (Skip.First/Skip.Second) |
| Tuple flattening | Yes (builder overloads, fixed arity) | Yes (parameter packs, unlimited) |
| Struct construction | `.memberwise(T.init)` or `.map` | `.map { ... }` only |
| Safety | `.memberwise` uses unsafeBitCast (fragile) | Always safe |
| Conciseness | `.memberwise` saves ~1 line | Explicit closure |

**Roughly equivalent**. pointfree's `.memberwise` is a minor convenience that trades safety for brevity. Our parameter pack approach to tuple flattening is more principled than pointfree's fixed-arity builder overloads.

---

## Dimension 6: Nested Composition

### pointfree

```swift
let weighted = Parse(WeightedEndpoint.init) {
    endpointParser
    "/"
    Int.parser()
}
```

Parsers are values. Just reference them in the builder.

### Ours

```swift
Parser.Take.Sequence {
    Network.Endpoint.Parser<Input>()
    "/"
    ASCII.Decimal.Parser<_, UInt16>()
}
.map { endpoint, weight in Weighted.Endpoint(endpoint: endpoint, weight: weight) }
```

Parsers are types. Must construct with `<Input>()`.

### Verdict

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Referencing nested parser | Variable name | Type constructor + `<Input>()` |
| Input threading | Implicit | Explicit generic parameter |
| Readability | Very clean | `<Input>()` is noise |

**pointfree is cleaner** for nested composition because parsers are values, not types requiring generic instantiation. The `<Input>()` parameter is necessary in our system (Input is generic per-parser) but adds friction.

---

## Dimension 7: Generic Constraints / Input Abstraction

### pointfree

```swift
// Default: Input = Substring, no constraints needed
struct MyParser: Parser {
    var body: some Parser<Substring, MyOutput> { ... }
}

// UTF8: specify Input
struct MyParser: Parser {
    var body: some Parser<Substring.UTF8View, MyOutput> { ... }
}
```

Input defaults to `Substring` in practice. Most parsers work with `Substring` or `Substring.UTF8View`. `ArraySlice<UInt8>` also supported.

Input constraint: `Collection where SubSequence == Self`.

### Ours

```swift
// Always generic, always constrained
struct Parser<Input: Collection.Slice.Protocol & Parser.Streaming>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}
```

Input is always a generic parameter with compound constraints. This enables Span-based zero-copy parsing but requires every parser definition to carry the constraint boilerplate.

### Verdict

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Common case ceremony | None (Substring default) | 2 lines of constraints |
| Supported input types | Collection where SubSequence == Self | Collection.Slice.Protocol & Streaming |
| Span/zero-copy support | No | Yes (~Copyable & ~Escapable) |
| Embedded support | No (uses Foundation-adjacent types) | Yes |

**pointfree wins on simplicity for the common case**. Ours is more general (Span support, embedded compatibility) but pays with verbosity on every parser definition.

---

## Dimension 8: Ad-hoc / Inline Parsing

### pointfree

```swift
var input = "80:443"[...]
let (host, port) = try Parse {
    Int.parser()
    ":"
    Int.parser()
}.parse(&input)
```

Two steps: construct parser, then call `.parse`. `Parse { ... }` is a parser value.

### Ours (current)

No direct equivalent. `Parser.Take.Sequence` works but requires explicit input types in bare `let` bindings since the `<_, UInt16>` placeholder can't infer Input without builder context.

### Ours (proposed — `input.parse { ... }`)

```swift
// Mutating — preserves remaining input
var input = Parser.ByteInput(utf8: "80:443/path")
let (host, port) = try input.parse {
    ASCII.Decimal.Parser<_, UInt16>()
    ":"
    ASCII.Decimal.Parser<_, UInt16>()
}
// input now contains "/path"

// One-shot — discards remaining input
let (host, port) = try Parser.ByteInput(utf8: "80:443").parsing {
    ASCII.Decimal.Parser<_, UInt16>()
    ":"
    ASCII.Decimal.Parser<_, UInt16>()
}
```

The receiver provides the `Input` type, so `<_, UInt16>` inference works — the builder context knows `Input == ByteInput`. Single call instead of construct-then-parse.

### Verdict

**Proposed design is better than pointfree.** `input.parse { ... }` is one step vs pointfree's two (`Parse { ... }.parse(&input)`). Input type is inferred from the receiver rather than hardcoded to Substring. See Priority 5 for full design and comparison table.

---

## Summary Comparison Table

| Dimension | pointfree | Ours | Winner |
|-----------|-----------|------|--------|
| 1. Definition boilerplate | 5-9 lines | 25+ lines | pointfree |
| 2. Builder body readability | Clean, implicit | Explicit, specification-mirroring | Comparable (different goals) |
| 3. Error handling | 0 lines (untyped) | 6-9+ lines (typed, exhaustive) | pointfree (ergonomics) / Ours (safety) |
| 4. String literal syntax | Works everywhere | Needs buildExpression overload | pointfree (slight) |
| 5. Output mapping / tuples | `.memberwise` or `.map` | `.map` only | Comparable |
| 6. Nested composition | Variable reference | Type constructor + `<Input>()` | pointfree |
| 7. Generic constraints | None (Substring default) | Always generic, always constrained | pointfree (simplicity) / Ours (generality) |
| 8. Ad-hoc inline parsing | `Parse { ... }.parse(&input)` | `input.parse { ... }` (proposed) | Ours (proposed) |

---

## Actionable Improvements

Prioritized by impact and compatibility with our constraints.

### Priority 1: Promote `buildExpression` for Literals

**Problem**: String literals in builder bodies require a manually-added `buildExpression` overload.
**Fix**: Move the `buildExpression` overload from the test suite to `Parser Take Primitives` (or `Parser Literal Primitives`).
**Impact**: Eliminates the need for `":" as Parser.Literal<Input>` everywhere.
**Cost**: One extension with **two** methods (see finding below).
**Compatibility**: Full. No architectural constraints affected.

**Critical finding (validated in experiment)**: The `buildExpression` for `Parser.Literal` must include a companion generic `buildExpression` in the **same constrained extension**. Without it, the Literal overload shadows the generic one from the unconstrained extension, breaking non-literal parsers in builder bodies:

```swift
extension Parser.Take.Builder
where Input: Parser.Streaming & Sendable, Input.Element == UInt8 {
    // Concrete: enables bare ":" string literals
    static func buildExpression(
        _ literal: Parser.Literal<Input>
    ) -> Parser.Literal<Input> { literal }

    // Generic: MUST be re-declared here to prevent shadowing
    static func buildExpression<P: Parser.`Protocol`>(
        _ parser: P
    ) -> P where P.Input == Input { parser }
}
```

See: `swift-parser-primitives/Experiments/inline-parse-ergonomics/`

### Priority 2: Reduce `error.map` Verbosity with Positional Helpers

**Problem**: Nested `Either` switching (`.left(.left(.left(.right)))`) is the largest single source of verbosity and error-proneness.

**Option A — Named positional accessors on composed types**:

The `Parser.Error.Either` type already has `.first`, `.second`, `.third`, etc. chain accessors. However, these return `Optional` values and don't help with exhaustive switching. Consider adding a parallel set of throwing extractors or a specialized `mapError` that takes positional closures:

```swift
// Hypothetical: positional error mapping
Parser.Take.Sequence { ... }
    .map { host, port in Endpoint(host: host, port: port) }
    .error.mapPositional(
        .invalidHost,      // first parser (leftmost)
        .expectedColon,    // second parser
        .invalidPort       // third parser
    )
```

This would require the error type to be an enum with matching arity — but that's what `Failure` already is in practice.

**Option B — Auto-generated `switch` ordering comment**:

Document the `Either` tree layout (leftmost parser = deepest nesting) and provide a builder that emits the case ordering as a compile-time diagnostic or doc comment.

**Impact**: Reduces error mapping from 6-9 lines to 1-4 lines.
**Cost**: New API surface, needs design work.
**Compatibility**: Full. Typed throws preserved, Either structure unchanged internally.

### Priority 3: Type Alias for Common Input Constraints

**Problem**: `Collection.Slice.Protocol & Parser.Streaming` with `Sendable` and `Element == UInt8` is repeated on every parser definition.

**Fix**: Introduce a typealias that bundles the common constraint set:

```swift
// In Parser Primitives Core
extension Parser {
    public typealias ByteStream = Collection.Slice.`Protocol` & Parser.Streaming & Sendable
}

// Usage — before:
struct Parser<Input: Collection.Slice.Protocol & Parser.Streaming>: Sendable
where Input: Sendable, Input.Element == UInt8 { ... }

// Usage — after:
struct Parser<Input: Parser.ByteStream>: Sendable
where Input.Element == UInt8 { ... }
```

The `Element == UInt8` constraint cannot be part of the typealias (Swift typealiases don't support `where` clauses), but bundling the three-protocol composition into one name eliminates the longest line of constraint boilerplate.

**Impact**: Reduces constraint declaration from 2 lines to 1 shorter line.
**Cost**: One typealias. Zero retroactive conformances needed — existing types already conform to the composition.
**Compatibility**: Full. Existing parsers can migrate incrementally.

### Priority 4: Consider `init`-Forwarding `.map` Overload

**Problem**: `.map { host, port in Endpoint(host: host, port: port) }` is a common pattern where the closure just calls an initializer.

**Fix**: Add a `.map` overload that accepts an initializer reference:

```swift
.map(Network.Endpoint.init(host:port:))
```

This already works today if the initializer has the right arity, because `(UInt16, UInt16) -> Endpoint` matches the `.map` closure type. The user just needs to know they can pass the init reference directly.

**Impact**: Minor — saves a few characters when applicable.
**Cost**: Documentation only (already works).
**Compatibility**: Full.

### Priority 5: Lightweight Inline Parsing via `input.parse { ... }`

**Problem**: No equivalent to pointfree's `Parse { ... }` for ad-hoc parsing without defining a type.

**Design**: Add a `parse` method on input types that takes a `@Parser.Take.Builder` closure. The receiver's type provides the `Input` generic parameter, so all parsers in the builder body inherit it automatically — no explicit type annotations needed.

```swift
// Mutating — advances input past consumed portion
extension Collection.Slice.`Protocol` where Self: Parser.Streaming & Sendable {
    @inlinable
    public mutating func parse<Body: Parser.`Protocol`>(
        @Parser.Take.Builder<Self> _ build: () -> Body
    ) throws(Body.Failure) -> Body.Output where Body.Input == Self {
        try build().parse(&self)
    }
}
```

**Usage — mutating (keeps remaining input)**:

```swift
var input = Parser.ByteInput(utf8: "80:443/path")
let (host, port) = try input.parse {
    ASCII.Decimal.Parser<_, UInt16>()
    ":"
    ASCII.Decimal.Parser<_, UInt16>()
}
// input now contains "/path"
```

**Usage — one-shot (discards remaining input)**:

```swift
// Non-mutating convenience for one-shot parsing
extension Collection.Slice.`Protocol` where Self: Parser.Streaming & Sendable {
    @inlinable
    public func parsing<Body: Parser.`Protocol`>(
        @Parser.Take.Builder<Self> _ build: () -> Body
    ) throws(Body.Failure) -> Body.Output where Body.Input == Self {
        var copy = self
        return try build().parse(&copy)
    }
}

let (host, port) = try Parser.ByteInput(utf8: "80:443").parsing {
    ASCII.Decimal.Parser<_, UInt16>()
    ":"
    ASCII.Decimal.Parser<_, UInt16>()
}
```

**Why this is better than pointfree**:

| Aspect | pointfree | Ours |
|--------|-----------|------|
| Syntax | `Parse { ... }.parse(&input)` | `input.parse { ... }` |
| Steps | 2 (construct parser, then call parse) | 1 (single call) |
| Input type | Hardcoded default (Substring) | Inferred from receiver (any input type) |
| Type placeholder `<_, T>` | N/A (uses `Int.parser()`) | Works — builder context provides Input |
| Remaining input access | Separate `var input` required | Mutating variant preserves it |
| One-shot convenience | `.parse("string")` (copies internally) | `.parsing { ... }` (copies internally) |

pointfree requires constructing a parser value then calling `.parse` on it. Our design inverts this: you call `.parse` on the input and provide the grammar inline. This is both shorter and more natural — "parse this input with this grammar" vs "build this parser then feed it this input".

**Impact**: Closes the ad-hoc parsing gap entirely. Two small extensions, no new types.
**Cost**: Two extension methods on `Collection.Slice.Protocol`.
**Compatibility**: Full. Does not affect the `var body` canonical pattern for named parsers.
**Status**: Validated. See `swift-parser-primitives/Experiments/inline-parse-ergonomics/`

### Non-Recommendations (Rejected)

| Idea | Why rejected |
|------|-------------|
| Drop typed throws for simpler errors | Core architectural requirement. Typed throws enable exhaustive error handling at compile time. |
| Use `String: Parser` instead of `Parser.Literal` | Would require Foundation or String dependency in primitives layer. Violates [PRIM-FOUND-001]. |
| Default Input to Substring | Would abandon Span/zero-copy/embedded support. |
| Use `.memberwise(T.init)` pattern | Uses `unsafeBitCast` internally. Violates strict memory safety. |
| Extend stdlib types with `.parser()` | Violates subject-first naming [API-NAME-003]. `Int.parser()` is not specification-mirroring. |

---

## Conclusions

1. **Our syntax is architecturally justified but ergonomically heavier.** The extra ceremony directly corresponds to features pointfree lacks: typed throws, generic Input, ~Copyable support, specification-mirroring names, strict memory safety.

2. **The biggest improvement opportunity is error mapping.** The nested `Either` switching accounts for ~25% of parser definition lines and is the most error-prone part to write. A positional error mapping API (Priority 2) would have the highest impact on day-to-day ergonomics.

3. **The `buildExpression` promotion (Priority 1) is a no-cost win** that should be done immediately.

4. **We should not adopt pointfree's design for its simplicity.** Their simpler syntax comes from architectural decisions incompatible with our requirements (untyped throws, no ~Copyable, Foundation-adjacent, no specification-mirroring names). The right approach is to reduce our ceremony where possible without compromising these properties.

5. **Ad-hoc parsing parity achieved via `input.parse { ... }`.** The proposed `input.parse { ... }` design (Priority 5) is strictly better than pointfree's `Parse { ... }.parse(&input)` — fewer steps, Input inferred from receiver, works with any input type. Two small extensions, no new types needed.
