# Transformation Domain Architecture

<!--
---
version: 3.2.0
last_updated: 2026-03-04
status: DECISION
tier: 2
---
-->

## Context

The Swift Institute ecosystem currently nests all transformation capabilities under the
`Parser` namespace: `Parser.Protocol`, `Parser.Serializer`, `Parser.Printer`,
`Parser.ParserPrinter`. This is architecturally wrong — a serializer is not a parser,
and the name implies it is. The previous research
([parsing-serialization-capability-organization.md](parsing-serialization-capability-organization.md))
established that there are three fundamental capabilities (parsing, serialization,
printing/formatting) plus one conjunction (coding/bidirectional).

The direction is to promote these to top-level namespaces, each with their own
`.Protocol`:

```swift
Parser.Protocol          // consume input -> value
Serializer.Protocol      // value -> append to buffer
Coder.Protocol           // bidirectional: decode + encode (separate types)
```

This follows the pattern already established by `Parser` — an empty enum namespace
containing a `.Protocol`, `.Builder`, `.Error`, and combinator types.

Printer remains internal to Parser (see Part 1 analysis). Formatter is deferred
until concrete use cases emerge.

Additionally, associated-type protocols are planned:

```swift
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    static var parser: Parser { get }
}
```

### Trigger

[RES-001] Architecture choice — transformation capability domains need their own
top-level namespaces and package homes. Cannot be resolved without systematic analysis
of package structure options, dependency direction, and combinator sharing.

### Constraints

- [API-NAME-001] `Nest.Name` pattern — each domain needs its own namespace enum
- [MOD-DOMAIN] One domain per package
- [PRIM-FOUND-001] No Foundation imports — absolute prohibition across all layers
- Five-layer architecture — downward-only dependencies
- 18 combinator modules currently have conditional `Parser.Printer` conformances
- Current `Parser.Protocol` includes `Body` and `@Parser.Builder` (declarative composition)
- `Coder.Protocol` requires different types for decode and encode (the `Binary.Coder`
  insight: cursor for reading, mutable buffer for writing)
- `Coder.Protocol` requires different failure types for decode and encode
  (`Binary.Coder`: decode throws `Fault`, encode is infallible)
- Concrete transformation types SHOULD integrate with `Witness.Protocol` (marker) and
  MAY integrate with `Dependency.Key` (injection) from swift-witness-primitives and
  swift-dependency-primitives

### Principles

Architectural correctness governs all evaluation. Migration cost, adoption convenience,
and ecosystem churn are explicitly excluded from the analysis.

| # | Principle | Rationale |
|---|-----------|-----------|
| P1 | **Correctness over convenience** | Package boundaries must reflect domain boundaries. Migration cost is not a factor. |
| P2 | **No Foundation** | [PRIM-FOUND-001] applies absolutely. No package at any layer imports Foundation. |
| P3 | **Witness integration** | Concrete types SHOULD conform to `Witness.Protocol` when they follow the struct-with-closures pattern. Protocol definitions need NOT import witness-primitives. |
| P4 | **[MOD-DOMAIN] domain separation** | Each transformation domain gets its own package. |
| P5 | **Clean naming** | Associated types use domain-appropriate names (`Output` not `ParseOutput`). No legacy names from Parser ancestry. |
| P6 | **Separate concerns** | Protocol definitions define contracts. Witness markers are orthogonal. Dependency injection is orthogonal. |

### Stakeholders

All packages that parse, serialize, code, or format data across the ecosystem.

## Question

**How should `Parser.Protocol`, `Serializer.Protocol`, and `Coder.Protocol` be
organized into packages?**

Sub-questions:
1. One shared package or separate packages per domain?
2. How do cross-domain conditional conformances work (18 parser combinators that also
   conform to `Printer`)?
3. Where do `Parseable`, `Serializable`, `Codable` live?
4. What is the relationship between Parser/Decoder/Deserializer (terminology)?
5. Does Serializer have a structural dual (like Printer is to Parser)?
6. How do transformation domains integrate with witness and dependency infrastructure?

## Conceptual Foundations

### The Five Transformation Concepts

Five terms recur across ecosystems. They sit on orthogonal axes:

#### 1. Parsing

**Definition**: Consuming unstructured input (bytes, text) from the front of a stream
to produce a structured value. The input is "used up" as parsing proceeds.

```swift
func parse(_ input: inout Input) throws(Failure) -> Output
//                       ^ advances forward, consuming bytes
```

**Who drives the reading**: The parser struct owns the reading logic. It knows both the
format (how bytes are structured) and the output type (what value to produce).

#### 2. Serializing

**Definition**: Taking a structured value and appending its representation to an output
buffer. One-way, machine-readable, canonical.

```swift
func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
//                                             ^ appends — O(1) amortized
```

A serialized representation is deterministic and parseable — you can always recover the
original value.

#### 3. Printing

**Definition**: The structural inverse of parsing. Takes a value and **prepends** to
an input buffer, so that `parse(print(value)) == value` by construction.

```swift
func print(_ output: Output, into input: inout Input) throws(Failure)
//                                       ^ prepends at startIndex — O(n) per operation
```

**Why prepend**: Parser consumes from the front (`removeFirst()`). For a composed
parser `Take(A, B)` that parses A then B, the printer must reconstruct the input with
A's bytes at the front and B's bytes after. The composition achieves this by printing
in **reverse order** (print B first, then print A), with each sub-printer prepending.
This compositional pattern — reverse order + prepend — guarantees round-trip symmetry
without the composition needing to track byte boundaries.

If printers appended instead, reverse-order printing would produce `[B][A]` — wrong.
Forward-order printing with append would require tracking where each sub-parser's
contribution ends in the buffer, breaking the compositional property.

**Cost**: Each prepend (`insert(contentsOf:, at: startIndex)`) shifts all existing
elements right -> O(n). For k operations, total cost is O(n*k) -> O(n^2).

**Implication**: Printer is parser-algebra machinery. It exists to give combinators
round-trip properties. Users wanting bidirectional transformation should use Coder
(append-based, O(n)) rather than ParserPrinter (prepend-based, O(n^2)).

#### 4. Coding

**Definition**: Bidirectional transformation — decode (read) and encode (write) in one
type. The key insight (`Binary.Coder`): decode and encode use **different types**.

```swift
func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> Output
func encode(_ output: Output, into buffer: inout EncodeBuffer) throws(EncodeFailure)
```

**Decode** uses a cursor (read-only, with checkpoint/restore). **Encode** appends to a
mutable buffer. These are fundamentally different data structures. `Parser.ParserPrinter`
forces the same `Input` type for both, which is why it needs prepend semantics and
pays O(n^2). Coder avoids this.

**Separate failure types**: Decode may fail (malformed input); encode may be infallible
(well-typed value always serializes). `Binary.Coder` demonstrates: decode throws
`Binary.Bytes.Machine.Fault`, encode is non-throwing. Forcing a single `Failure` type
would require the Coder to declare `throws(Fault)` on encode even when it cannot fail.

**Round-trip guarantee**: By convention/testing, not by structural enforcement.
`decode(encode(v)) == v` must be verified, but the types don't structurally guarantee it.

#### 5. Formatting

**Definition**: Producing a human-readable representation. Distinct from serialization:
- Output may be locale-dependent (`"1,234.50"` vs `"1.234,50"`)
- Output may lose information (precision, structure)
- Output may not be machine-parseable
- Output is typically `String`, not arbitrary buffer
- Extensive configuration (locale, style, precision, padding)

**Relationship to Serializer**: Mechanically, `Serializer.Protocol where Buffer == String`
covers the append-to-string case. Semantically, serialization produces canonical
machine-readable output; formatting produces human-readable display output. The
distinction is real but may not need its own protocol domain yet.

### Relationship Map

```
                    Parsing <--structural dual--> Printing
                      |                              |
                      | same domain (Parser)         | prepend-based
                      | shared Input type             | O(n^2), round-trip
                      |                              | by construction
                      |                              |
                   Coding -------------------------  |
                      |                              |
                      | bidirectional                 |
                      | separate types               |
                      | append-based, O(n)           |
                      | round-trip by testing        |
                      |                              |
                  Serializing ......................> Formatting
                                different:
                              * machine vs human
                              * lossless vs lossy
                              * canonical vs locale-dependent
                              * parseable vs display-only
```

### Axis Analysis

| Axis | Parsing | Serializing | Printing | Coding | Formatting |
|------|---------|-------------|----------|--------|------------|
| **Direction** | Read | Write | Write | Both | Write |
| **Buffer op** | Consume front | Append back | Prepend front | Decode: consume; Encode: append | Return complete |
| **Performance** | O(n) | O(n) | O(n^2) aggregate | O(n) | O(n) |
| **Round-trip** | — | No | Yes (structural) | Yes (by testing) | No |
| **Coupled to** | Printer (dual) | Nothing | Parser (dual) | Self (internal) | Nothing |
| **Audience** | Machine | Machine | Machine | Machine | Human |
| **Lossless** | N/A (reading) | Yes | Yes | Yes | May lose info |
| **Locale** | No | No | No | No | Yes |
| **Buffer type** | Generic Input | Generic Buffer | Same as Parser's Input | Separate Decode + Encode | String (typically) |

### Parser vs Decoder vs Deserializer

These three terms describe reading from representations, but they differ in **who
drives the reading**:

| Term | Who owns format logic? | Who owns value structure? | Interface |
|------|------------------------|--------------------------|-----------|
| **Parser** | The parser struct | The parser struct | `parser.parse(&input) -> Value` |
| **Decoder** | The format (Decoder) | The value type (Decodable) | `Value(from: decoder)` |
| **Deserializer** | The format (Deserializer) | The value type (via Visitor) | `deserializer.deserialize(visitor)` |

**Parser** (our ecosystem): The parser IS the transformation. `ASCII.Decimal.Parser`
knows both the format (ASCII digit bytes) and the output type (`T: FixedWidthInteger`).
It's a self-contained struct with `parse(_: inout Input)`. The parser owns all logic.

**Decoder** (Swift Codable): The format provides navigation infrastructure
(`JSONDecoder` creates containers). The value type navigates via
`init(from: Decoder)` — asking "give me a string for key 'name'." The type doesn't
know about bytes; the decoder doesn't know about the type's fields. Responsibility
is split.

**Deserializer** (Rust serde): The format drives a visitor pattern. The
deserializer calls `visitor.visit_str("hello")` — the value type reacts. Like
Decoder but with an inverted control flow (deserializer pushes, visitor receives).

**Our ecosystem**: We use Parser (self-contained structs). We do not have Decoder or
Deserializer — those are patterns for schema-driven formats (JSON, Protobuf, CBOR)
where format navigation and value construction are separate concerns. If schema-driven
decoding is needed, it would be a separate domain from Parser, likely at L3.

### Does Serializer Have a Structural Dual?

Parser and Printer are structural duals:
- Parser consumes from front; Printer prepends to front
- They share the same `Input` type
- Round-trip is guaranteed by construction: `parse(print(v)) == v`

**Does Serializer have an analogous dual?** A "Deserializer" that consumes from the
*back* (since Serializer appends to the back)?

**No.** Consuming from the back is unnatural for streaming data. Nobody reads bytes
in reverse. The "read" counterpart of serialization is just parsing — you serialize
with a Serializer, you parse it back with a Parser. But they use different buffer
types (`Buffer` vs `Input`), so there is no structural round-trip guarantee. The
guarantee is by convention: "this Parser is the inverse of that Serializer" — verified
by testing.

```
Parser  <-- structural dual -->  Printer      (same Input, prepend, O(n^2))
Serializer  <-- no dual -->      (none)       (read counterpart is just Parser,
                                                different types, no structural
                                                guarantee)
```

**Implication for package organization**: Parser and Printer are inherently coupled
(shared `Input` type, compositional duality). They belong together. Serializer is
independent — no dual, no shared types with Parser. It can live in its own package
without creating a gap.

## Witness and Dependency Integration

### Witness.Protocol — Pure Marker

`Witness.Protocol` is a zero-requirement marker protocol in swift-witness-primitives:

```swift
extension Witness {
    public protocol `Protocol` {}
}
```

It marks struct-with-closures types that represent capabilities. The `@Witness` macro
generates conformance along with methods, `Action` enum, and `observe` accessor.

### Dependency.Key — Injection

`Dependency.Key` in swift-dependency-primitives provides live/test variants with
TaskLocal-based scoping:

```swift
extension Dependency {
    public protocol Key: Sendable {
        associatedtype Value: ~Copyable & Sendable
        static var liveValue: Value { get }
        static var testValue: Value { get }
    }
}
```

Supports `~Copyable` values. `testValue` defaults to `liveValue`.

### Binary.Coder — The Existing Pattern

`Binary.Coder<Output>` already demonstrates the target pattern for bidirectional
transformation types:

```swift
public struct Coder<Output>: Sendable, Witness.`Protocol` {
    public var decode: @Sendable (inout Binary.Bytes.Input)
        throws(Binary.Bytes.Machine.Fault) -> Output
    public var encode: @Sendable (Output, inout [UInt8]) -> Void
}
```

Key properties:
- Conforms to `Witness.Protocol` (it is a struct with closures)
- `Sendable`
- Separate decode/encode types (cursor vs mutable buffer)
- Separate failure types (decode throws `Fault`, encode is infallible)
- Machine IR integration (`.machine(_:encode:)`)

### Serialization.Serializing.Buffer — Witness Bridge

`Binary.Serializable` provides a `.serializing` bridge to `Serialization.Serializing.Buffer`:

```swift
extension Binary.Serializable {
    public static var serializing: Serialization.Serializing.Buffer<Self, UInt8, Void> {
        .init { value, _, buffer in Self.serialize(value, into: &buffer) }
    }
}
```

This bridge pattern generalizes: any `Serializer.Protocol` conformer can be lifted to
a `Serialization.Serializing.Buffer` witness, and vice versa.

### Integration Principle

Three concerns are orthogonal:

1. **Protocol conformance** (Parser.Protocol, Serializer.Protocol, Coder.Protocol) —
   defines the transformation contract
2. **Witness marker** (Witness.Protocol) — marks struct-with-closures capability pattern
3. **Dependency injection** (Dependency.Key) — provides live/test/scoped variants

A concrete type can adopt any combination:

```swift
// Coder with full witness + DI integration:
struct JSON.Coder: Coder.Protocol, Witness.Protocol, Dependency.Key { ... }

// Parser — algebraic type, NOT a witness (no closures):
struct ASCII.Decimal.Parser<Input, T>: Parser.Protocol { ... }

// Existing witness that predates Coder.Protocol:
struct Binary.Coder<Output>: Witness.Protocol { ... }
```

**Protocol definitions need NOT import witness-primitives.** Witness conformance happens
at the concrete type site, not at the protocol definition. This keeps the protocol
packages dependency-free and the witness integration opt-in.

## Prior Art Survey

### Cross-Ecosystem Package Organization

[RES-021] Survey of how mature ecosystems organize parse/serialize domains:

| Ecosystem | Same Package? | Internal Namespaces? | Bidirectional Type | Bidirectional Location |
|-----------|:---:|:---:|---|---|
| Swift Codable | Yes (stdlib) | No (flat peers) | `Codable` (typealias) | Same module |
| pointfreeco/swift-parsing | Yes (one module) | No (flat) | `ParserPrinter` (refines `Parser`) | Same module |
| Rust serde | Yes (one crate) | Yes (`ser`/`de`) | None | N/A |
| Haskell aeson | Yes (one package) | Yes (`Encoding`/`Decoding`) | None | N/A |
| Haskell binary | Yes (one package) | Yes (`Get`/`Put`) | `Binary` (typeclass) | Parent module |
| Boost.Spirit | Yes (one library) | Yes (`qi`/`karma`/`lex`) | None (implicit via shared attributes) | N/A |

**Universal pattern**: Every ecosystem keeps parse and serialize in the same
distribution unit. Mature ecosystems (serde, Spirit, binary) give each direction its
own namespace/submodule within that unit.

**Note on prior art weight**: Co-location is universal, but our ecosystem has a
constraint most others don't: [MOD-DOMAIN] requires one domain per package. This is a
deliberate architectural decision that trades co-location convenience for domain
boundary enforcement. Prior art informs but does not override [MOD-DOMAIN].

**Bidirectional types are rare**: Only 3 of 6 ecosystems provide an explicit
bidirectional protocol. When present, it always lives alongside the directional ones.

**Concrete formats are always separate**: `serde_json`, `JSONEncoder`, format-specific
crates/modules are never in the abstract framework package.

### Current Parser-Primitives Architecture

parser-primitives (37 targets) defines all four current protocols in
`Parser Primitives Core`:

```
Parser Primitives Core/
+-- Parser.swift                 -> public enum Parser {}
+-- Parser.Parser.swift          -> Parser.Protocol
+-- Parser.Serializer.swift      -> Parser.Serializer
+-- Parser.Printer.swift         -> Parser.Printer
+-- Parser.ParserPrinter.swift   -> Parser.ParserPrinter
+-- Parser.Builder.swift         -> @Parser.Builder result builder
+-- Parser.Input.swift           -> Input typealiases
+-- Parser.ByteInput.swift       -> ByteInput convenience
+-- exports.swift                -> re-exports Input/Collection/Sequence/Array Primitives
```

**Critical**: 18 of 33 combinator modules have conditional `Parser.Printer`
conformances. These enable automatic Printer support through composition — if all
components of a composed parser implement Printer, the composition does too:

| Combinators with Printer conformance |
|--------------------------------------|
| OneOf.Two, OneOf.Three, Optional, Optionally, Skip.First, Skip.Second, Take.Two, Many.Simple, Many.Separated, Conditional, Always, Literal, First.Element, Byte, End, String, Array |

| Combinators WITHOUT Printer conformance |
|-----------------------------------------|
| Map, FlatMap, Filter (these break round-trip symmetry) |

The Printer conformances use **reverse-order printing**: `Take.Two` prints p1 output
first, then p0 output, because Parser consumes from front while Printer prepends to
front.

## Analysis

### Part 1: Printer Stays Internal to Parser — Rationale

Printer is the structural dual of Parser. They share the same `Input` type and form
a compositional pair: 18 of 33 parser combinators have conditional Printer
conformances that propagate printability through composition.

Printer uses **prepend semantics** (O(n^2)) because this is the only way to maintain
compositional round-trip symmetry with Parser's consume-from-front semantics (see
Conceptual Foundations above). This makes Printer inherently coupled to Parser —
it has no independent existence.

For users wanting bidirectional transformation:
- **Within parser-combinator composition**: Use `Parser.ParserPrinter` (structural
  round-trip via prepend, accepted O(n^2) cost)
- **For general bidirectional coding**: Use `Coder.Protocol` (append-based, O(n),
  separate decode/encode types, round-trip by testing)

`Parser.Printer` and `Parser.ParserPrinter` remain nested under `Parser`. They are
not promoted to top-level namespaces. Formatter.Protocol is deferred until concrete
use cases emerge (see Conceptual Foundations — Formatting).

**Decision**: Three top-level domains: **Parser**, **Serializer**, **Coder**.
Printer is Parser-internal. Formatter is deferred.

### Part 2: Package Structure

#### Evaluation Criteria

Migration cost is explicitly excluded (Principle P1). The criteria:

| # | Criterion | Weight | Source |
|---|-----------|--------|--------|
| C1 | **Domain separation** — one domain per package | Required | [MOD-DOMAIN] |
| C2 | **Dependency acyclicity** — no circular or diamond dependencies | Required | Five-layer architecture |
| C3 | **Structural coupling** — coupled types (duals) belong together | High | Duality analysis |
| C4 | **Foundation independence** — no Foundation imports | Required | [PRIM-FOUND-001] |
| C5 | **Witness integration** — concrete types can conform to `Witness.Protocol` | High | P3 |
| C6 | **Naming accuracy** — package name describes contents | Medium | [API-NAME-001] |
| C7 | **Protocol home** — each associated-type protocol has a natural home | High | P6 |
| C8 | **Builder containment** — `@Parser.Builder` stays with parser combinators | Medium | Separation of concerns |

#### Option A: Three Independent Packages

```
swift-parser-primitives       -> Parser.Protocol (with Body/Builder), Parser.Printer,
   (existing)                    Parser.ParserPrinter, combinators, Parseable

swift-serializer-primitives   -> Serializer.Protocol, Serializer.Builder, Serializable,
   (renamed from swift-serialization-primitives)             Serialization.Serializing.Buffer (existing witnesses)
                                    (no dependency on parser-primitives)

swift-coder-primitives        -> Coder.Protocol, Codable
   (new)                         (no dependency on parser-primitives or serializer-primitives)
```

**Key insight**: `Coder.Protocol` is independent. It does NOT refine `Parser.Protocol`
or `Serializer.Protocol` because:
- Decode and encode have **separate failure types** (Binary.Coder: `Fault` vs `Never`)
- Coder defines its own `decode(_:)` and `encode(_:into:)` methods
- Convenience projections (`.asParser`, `.asSerializer`) handle interop without
  protocol refinement

All three packages are structurally independent. No diamonds. No shared core needed.

Each associated-type protocol lives with its domain:
- `Parseable` in swift-parser-primitives (references only `Parser.Protocol`)
- `Serializable` in swift-serializer-primitives (references only `Serializer.Protocol`)
- `Codable` in swift-coder-primitives (references only `Coder.Protocol`; shadows stdlib's `Codable`)

**Evaluation**:

| C1 Domain | C2 Acyclic | C3 Coupling | C4 Foundation | C5 Witness | C6 Naming | C7 Home | C8 Builder |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |

All criteria met. Parser + Printer stay together (structural duals). Serializer is
independent (no dual). Coder is independent (separate failure types, no refinement).
Body/Builder stays in parser-primitives (no split needed).

#### Option B: Shared Core + Separate Combinators

```
swift-transformation-primitives  -> Parser.Protocol (stripped: no Body), Serializer.Protocol,
   (new, minimal)                   Coder.Protocol, Parseable, Serializable, Codable

swift-parser-primitives          -> Parser.Declarative (adds Body/Builder), combinators,
   (existing, depends on core)      Printer, ParserPrinter

swift-serializer-primitives      -> Serializer combinators (future)
   (new, depends on core)

swift-coder-primitives           -> Coder combinators (future)
   (new, depends on core)
```

**Evaluation**:

| C1 Domain | C2 Acyclic | C3 Coupling | C4 Foundation | C5 Witness | C6 Naming | C7 Home | C8 Builder |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Fail** | Pass | Pass | Pass | Pass | Pass | Pass | Pass (split) |

Violates [MOD-DOMAIN]: core package contains three domains. Also requires Body/Builder
split (`Parser.Protocol` -> `Parser.Declarative` refinement), adding a two-protocol
hierarchy. The split IS principled (Body is composition machinery, not parsing contract),
but it's unnecessary complexity when Option A avoids it entirely.

#### Option C: Unified Package (Keep Name)

```
swift-parser-primitives          -> Parser.Protocol, Serializer.Protocol, Coder.Protocol,
   (renamed from swift-serialization-primitives)             Printer, combinators, Parseable, Serializable, Codable
```

**Evaluation**:

| C1 Domain | C2 Acyclic | C3 Coupling | C4 Foundation | C5 Witness | C6 Naming | C7 Home | C8 Builder |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Fail** | Pass | Pass | Pass | Pass | **Fail** | Pass | Pass |

Violates [MOD-DOMAIN] (three domains in one package) and [C6] (package named "parser"
contains Serializer and Coder). Matches serde/Spirit prior art but conflicts with our
modularization conventions.

#### Option D: Unified Package (Renamed)

```
swift-codec-primitives           -> Parser.Protocol, Serializer.Protocol, Coder.Protocol,
   (renamed)                        Printer, combinators, Parseable, Serializable, Codable
```

**Evaluation**:

| C1 Domain | C2 Acyclic | C3 Coupling | C4 Foundation | C5 Witness | C6 Naming | C7 Home | C8 Builder |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Fail** | Pass | Pass | Pass | Pass | Marginal | Pass | Pass |

Better naming than C ("codec" encompasses all three) but still violates [MOD-DOMAIN].
"Codec" is also ambiguous — could mean `Coder` specifically rather than the umbrella.

#### Comparison

| Criterion | A: Three Independent | B: Core + Combinators | C: Unified | D: Renamed |
|-----------|:---:|:---:|:---:|:---:|
| [MOD-DOMAIN] | **Pass** | Fail | Fail | Fail |
| Acyclic dependencies | **Pass** | Pass | Pass | Pass |
| Structural coupling | **Pass** (duals together) | Pass | Pass | Pass |
| No Foundation | **Pass** | Pass | Pass | Pass |
| Witness integration | **Pass** | Pass | Pass | Pass |
| Naming accuracy | **Pass** | Pass | Fail | Marginal |
| Protocol home clarity | **Pass** (each in own domain) | Pass (all in core) | Pass | Pass |
| Body/Builder containment | **Pass** (no split needed) | Pass (split) | Pass | Pass |
| New packages | 2 | 1 core + 2 | 0 | 0 |
| Prior art alignment | Diverges (see note) | Partial | serde, Spirit | serde, Spirit |

**Prior art divergence**: Option A is the only option that separates parse and
serialize into different packages. Every surveyed ecosystem co-locates them. However,
our ecosystem uniquely enforces [MOD-DOMAIN] (one domain per package), which none of
the surveyed ecosystems do. The duality analysis confirms this separation is principled:
Parser and Serializer share no structural coupling (no dual, no shared types).

### Part 3: Protocol Design

#### Parser.Protocol (Clean Naming)

```swift
extension Parser {
    protocol Protocol<Input, Output, Failure> {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output
        associatedtype Failure: Error & Sendable
        associatedtype Body

        @Parser.Builder<Input>
        var body: Body { get }

        func parse(_ input: inout Input) throws(Failure) -> Output
    }
}
```

Change from current: `ParseOutput` -> `Output`. Everything else unchanged.
Body/Builder stays — parser-primitives is the sole home for parser composition.

#### Serializer.Protocol (New)

```swift
extension Serializer {
    protocol Protocol<Output, Buffer, Failure> {
        associatedtype Output
        associatedtype Buffer
        associatedtype Failure: Error & Sendable
        associatedtype Body

        @Serializer.Builder<Buffer>
        var body: Body { get }

        func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
    }
}
```

Derived from current `Parser.Serializer` with:
- Lives in `Serializer` namespace (not `Parser`)
- `ParseOutput` -> `Output`
- `Body` + `@Serializer.Builder` included from the start (follows Parser.Protocol
  pattern — declarative composition for composed serializers, `Body == Never` for
  leaf serializers)
- Lives in existing `swift-serializer-primitives` alongside `Serialization.*` witnesses

#### Coder.Protocol (New, Separate Failures)

```swift
extension Coder {
    protocol Protocol<DecodeInput, EncodeBuffer, Output> {
        associatedtype DecodeInput: ~Copyable & ~Escapable
        associatedtype EncodeBuffer
        associatedtype Output
        associatedtype DecodeFailure: Error & Sendable
        associatedtype EncodeFailure: Error & Sendable

        func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> Output
        func encode(_ output: Output, into buffer: inout EncodeBuffer) throws(EncodeFailure)
    }
}
```

Design decisions:

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Independent** — does NOT refine Parser.Protocol or Serializer.Protocol | Separate failure types; Parser has Body/Builder which Coder doesn't need |
| 2 | **Separate failure types** — `DecodeFailure` and `EncodeFailure` | Binary.Coder: decode throws `Fault`, encode is infallible (`EncodeFailure = Never`) |
| 3 | **Separate input/output types** — `DecodeInput` vs `EncodeBuffer` | Binary.Coder insight: cursor (read-only) vs mutable buffer (appendable) |
| 4 | **`decode`/`encode` naming** — not `parse`/`serialize` | Coder's methods are inherently coupled (inverse pair). Parser and Serializer are independent operations. |
| 5 | **No Body/Builder** | Coders are typically leaf types (one per format x value pair) |
| 6 | **3 primary type params** — `DecodeInput`, `EncodeBuffer`, `Output` | Failure types are non-primary associated types (not in generic parameter clause) |

**Cross-domain use**: A Coder's `decode` IS parsing and its `encode` IS serializing.
Types that have a canonical Coder can expose it through `Parseable` and `Serializable`
as well — the canonical/witness research
([canonical-witness-capability-attachment.md](canonical-witness-capability-attachment.md))
addresses this pattern.

### Part 4: Parseable / Serializable / Codable

Each associated-type protocol lives in its domain package:

```swift
// In swift-parser-primitives:
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    static var parser: Parser { get }
}

// In swift-serializer-primitives (renamed from swift-serialization-primitives):
protocol Serializable {
    associatedtype Serializer: Serializer.Protocol
    static var serializer: Serializer { get }
}

// In swift-coder-primitives:
protocol Codable {
    associatedtype Coder: Coder.Protocol
    static var coder: Coder { get }
}
```

**Three independent protocols**. `Codable` does NOT refine `Parseable & Serializable`:

- A type may be `Codable` without being separately `Parseable` (the coder handles both
  directions internally)
- A type may be `Parseable` without being `Codable` (parse-only use case)
- A type may conform to all three independently

This avoids the Swift Codable anti-pattern where `Codable` forces a type to declare
both `init(from:)` and `encode(to:)` even when only one direction is needed.

**Name collision**: `Codable` shadows Swift stdlib's `Codable` (= `Encodable &
Decodable`). Our module's `Codable` takes precedence within the ecosystem. Consumers
needing stdlib's version disambiguate with `Swift.Codable`.

### Part 5: Body/Builder Analysis

`Parser.Protocol` currently includes `associatedtype Body` and
`@Parser.Builder<Input> var body: Body { get }`. Under Option A, this stays as-is in
parser-primitives — no split needed.

**Is this principally correct?** From first principles, `Body` is composition machinery
(how a parser is assembled), not the parsing contract (what a parser does). Leaf parsers
already use `Body == Never` with a fatalError body. A minimal `Parser.Protocol` would
have only `func parse(_:)`.

However, splitting `Body` from the protocol creates a two-protocol hierarchy
(`Parser.Protocol` + `Parser.Declarative`) that adds complexity without enabling
anything new. Every existing parser would need to change conformance. The benefit
(conceptual purity) does not justify the cost (complexity increase) when the status quo
works correctly.

**`Serializer.Builder` included from the start**: `Serializer.Protocol` includes
`Body` + `@Serializer.Builder` following Parser's pattern. This enables declarative
composition of serializers without a future protocol-breaking change. Leaf serializers
use `Body == Never` (same pattern as leaf parsers).

**Coder does NOT get a Builder**: Coders are leaf types (one per format x value pair).
If compositional coders emerge, add `Coder.Builder` at that time — but this is
unlikely given that decode and encode have different type parameters.

### Part 6: Witness Integration Model

The three-layer integration model:

```
Layer 3: Associated-type protocols (Parseable, Serializable, Codable)
         "Types that CAN BE parsed/serialized/coded"
              |
              | implementations reference
              v
Layer 2: Capability protocols (Parser.Protocol, Serializer.Protocol, Coder.Protocol)
         "Types that ARE parsers/serializers/coders"
              |
              | concrete types MAY also conform to
              v
Layer 1: Witness marker (Witness.Protocol) + DI (Dependency.Key)
         "Types that are struct-with-closures capabilities, injectable"
```

**Coders and Serializers** typically conform to `Witness.Protocol`:
- They follow the struct-with-closures pattern (closures for operations)
- They benefit from `@Witness` macro generation
- They can integrate with `Dependency.Key` for scoped injection

```swift
struct JSON.Coder: Coder.Protocol, Witness.Protocol, Dependency.Key {
    var decode: ...
    var encode: ...
    static var liveValue: Self { ... }
    static var testValue: Self { .mock }
}
```

**Parsers typically do NOT conform to `Witness.Protocol`**:
- Parser combinators are algebraic types (stateless structs composed via Builder)
- They compose via result builder, not via closure injection
- They have `Body` + `@Parser.Builder` — a different composition model

**Bridge to Serialization witnesses**: Any `Serializer.Protocol` conformer can be
lifted to a `Serialization.Serializing.Buffer`:

```swift
extension Serializer.Protocol {
    var asSerializationWitness: Serialization.Serializing.Buffer<Output, Buffer.Element, Void> {
        .init { value, _, buffer in
            try? self.serialize(value, into: &buffer)
        }
    }
}
```

This generalizes the existing `Binary.Serializable.serializing` bridge.

### Recommendation

**Option A (Three Independent Packages)** is the principled choice.

The duality analysis established:
- Parser <-> Printer are structural duals -> coupled -> same package
- Serializer has no dual -> independent -> own package
- Coder has separate decode/encode types and failure types -> independent -> own package

The witness integration analysis confirmed:
- Protocol definitions don't import witness-primitives (orthogonal concerns)
- Concrete types opt into `Witness.Protocol` and `Dependency.Key` at the conformance site
- This works identically regardless of package structure

Each domain is self-contained:

| Package | Contents |
|---------|----------|
| `swift-parser-primitives` (existing) | `Parser.Protocol` (with Body/Builder), `Parser.Printer`, `Parser.ParserPrinter`, `Parser.Builder`, combinators, `Parseable` |
| `swift-serializer-primitives` (renamed from swift-serialization-primitives) | `Serializer.Protocol` (with Body/Builder), `Serializer.Builder`, `Serializable`, existing `Serialization.*` witnesses |
| `swift-coder-primitives` (new) | `Coder.Protocol`, `Codable` (shadows stdlib) |

Only ONE new package (`swift-coder-primitives`). `swift-serializer-primitives`
already exists and is expanded with the protocol + builder. No shared core needed.
No Body/Builder split needed. No diamonds. [MOD-DOMAIN] satisfied.

## Outcome

**Status**: DECISION

### Decisions Made

| Decision | Rationale |
|----------|-----------|
| Three top-level namespaces: Parser, Serializer, Coder | Each independent domain deserves its own namespace enum |
| **Three independent packages** (Option A) | [MOD-DOMAIN], duality alignment, no diamonds, no Body/Builder split. Prior art divergence acknowledged but [MOD-DOMAIN] overrides co-location precedent. |
| Printer stays internal to Parser (`Parser.Printer`) | Structural dual — coupled by shared `Input` type, prepend semantics, 18 combinator conformances |
| Formatter deferred | Semantically distinct from Serializer but no concrete infrastructure yet |
| `.Parser` naming (not `.Parse`) | Type names describe what a type IS |
| `ParseOutput` -> `Output` | Clean naming — no Parser legacy in Serializer/Coder |
| `Coder.Protocol` with separate decode/encode types | Binary.Coder insight — cursor vs mutable buffer, avoids O(n^2) prepend |
| `Coder.Protocol` with separate failure types | Binary.Coder: decode throws `Fault`, encode is infallible. `DecodeFailure`/`EncodeFailure` |
| `Coder.Protocol` is independent (not refinement) | Separate failure types; Parser has Body/Builder; convenience projections handle interop |
| Serializer has no structural dual | Read counterpart is just parsing with different buffer types |
| No Foundation — absolute | [PRIM-FOUND-001] applies across all layers |
| `Witness.Protocol` conformance is orthogonal | Concrete types opt in at conformance site. Protocol definitions don't import witness-primitives. |
| `Parseable`/`Serializable`/`Codable` each in own domain | Each references only its own domain's protocol. No cross-domain imports needed. |
| `Codable` independent of `Parseable & Serializable` | A Coder handles both directions internally. Forcing decomposition into separate Parser + Serializer is artificial for bidirectional types. |
| Body/Builder stays in `Parser.Protocol` | Principally, Body is composition machinery not contract — but splitting adds unjustified complexity. |
| `@Serializer.Builder` included from the start | Follows Parser's pattern. Avoids future protocol-breaking change. Leaf serializers use `Body == Never`. |
| `decode`/`encode` naming for Coder | Signals inherent coupling (inverse pair). `parse`/`serialize` reserved for the independent operations. |
| Shadow stdlib's `Codable` | Our ecosystem's `Codable` takes precedence within our modules. `Swift.Codable` for disambiguation. |
| ONE serialization package | Rename `swift-serialization-primitives` to `swift-serializer-primitives`. Add protocol + builder alongside existing witnesses. |
| Coder projections unnecessary | A Coder's `decode` IS parsing. Types expose canonical Coder through `Parseable`/`Serializable` directly. See [canonical-witness-capability-attachment.md](canonical-witness-capability-attachment.md). |

### Resolved Questions (v3.1.0)

| # | Question | Resolution | Rationale |
|---|----------|-----------|-----------|
| 1 | **`Codable` name collision** | Shadow stdlib's `Codable` | Our ecosystem's `Codable` takes precedence. Consumers use `Swift.Codable` to disambiguate. |
| 2 | **Serializer combinator algebra** | Include combinators | If it doesn't hurt, provide them. Follows Parser's pattern. |
| 3 | **Coder.Protocol method naming** | `decode`/`encode` | Signals inherent coupling (inverse pair). `parse`/`serialize` reserved for the independent Parser/Serializer operations. |
| 4 | **serialization-primitives relationship** | ONE package — rename | Rename `swift-serialization-primitives` to `swift-serializer-primitives`. Add `Serializer.Protocol` + Builder alongside existing `Serialization.*` witnesses. `Serializer` and `Serialization` namespaces coexist. |
| 5 | **Serializer.Protocol Body/Builder** | `@Serializer.Builder` from the start | Follows Parser's pattern. Avoids future protocol-breaking change. Leaf serializers use `Body == Never`. |
| 6 | **Coder convenience projections** | Unnecessary | A Coder's `decode` IS parsing. Types with a canonical Coder expose it through `Parseable`/`Serializable` directly. No wrapper types needed. See [canonical-witness-capability-attachment.md](canonical-witness-capability-attachment.md). |

### Next Steps

1. Add `Serializer.Protocol` + `Serializer.Builder` + `Serializable` to existing
   `swift-serializer-primitives`
2. Create `swift-coder-primitives` package with `Coder.Protocol` + `Codable`
3. Migrate `Parser.Serializer` -> `Serializer.Protocol` (remove from parser-primitives)
4. Rename `ParseOutput` -> `Output` in `Parser.Protocol`
5. Add `Parseable` to parser-primitives
6. Build `Binary.Coder` conformance to `Coder.Protocol`
7. ~~Define canonical selection guidance~~ DONE — see [canonical-witness-capability-attachment.md](canonical-witness-capability-attachment.md) (DECISION)

## Changelog

- **v3.2.0** (2026-03-04): Canonical-witness capability attachment research concluded
  (DECISION). All open questions resolved, empirically validated (10/10 experiment
  variants CONFIRMED). Next step 7 marked done. Status RECOMMENDATION → DECISION.
- **v3.1.0** (2026-03-04): All 6 open questions resolved. Q1: shadow stdlib's
  `Codable`. Q2: include serializer combinators. Q3: `decode`/`encode` confirmed.
  Q4: ONE package — rename `swift-serialization-primitives` to `swift-serializer-primitives`,
  add `Serializer.Protocol` + Builder alongside existing witnesses (1 new package, 1 rename).
  Q5: `@Serializer.Builder` from the start. Q6: extension init pattern per [IMPL-INTENT]
  (`Coder.AsParser(coder)` not `coder.asParser()`). Updated Serializer.Protocol signature
  with Body/Builder. Status -> RECOMMENDATION.
- **v3.0.0** (2026-03-04): Reframed around principled correctness — migration cost
  explicitly excluded from evaluation (Principle P1). Added Foundation prohibition as
  absolute constraint. Added Witness and Dependency Integration section: `Witness.Protocol`
  as pure marker, `Dependency.Key` for DI, `Binary.Coder` as existing pattern, three-layer
  integration model (protocol conformance + witness marker + dependency injection are
  orthogonal). Added evaluation criteria table with weighted principled criteria.
  Refined Option A: Coder.Protocol is independent (separate failure types eliminate
  diamond dependency that was listed as disadvantage in v2.0). Eliminated Option E
  (subsumed by refined Option A — both are three independent packages, but Option A is
  cleaner framing). `ParseOutput` -> `Output` throughout. Coder.Protocol with separate
  `DecodeFailure`/`EncodeFailure`. Parseable/Serializable/Codable each live in their
  domain package. Added Codable name collision as open question. Added witness integration
  model section. Added prior art divergence note (all ecosystems co-locate, but none
  enforce [MOD-DOMAIN]). Reduced open questions to 6 focused items.
- **v2.0.0** (2026-03-04): Added Conceptual Foundations section with five-axis
  analysis (parsing, serializing, printing, coding, formatting), prepend vs append
  explanation (why Printer uses reverse-order prepend for compositional round-trip),
  Parser vs Decoder vs Deserializer terminology distinction, duality analysis
  (Parser<->Printer are structural duals; Serializer has no dual). Resolved: Printer
  stays Parser-internal, Formatter deferred, three top-level domains. Added Option E
  (Parser stays + Serializer separate + Coder bridges) as recommended package
  structure. Replaced four-option fourth-domain analysis with settled rationale.
  Reduced open questions from 7 to 6.
- **v1.0.0** (2026-03-04): Initial analysis. Four options for package structure,
  four options for fourth domain identity. Cross-ecosystem prior art survey
  (6 ecosystems, universal co-location pattern). 18 conditional Printer conformances
  documented as key constraint. Coder.Protocol design with separate decode/encode
  types. Parseable/Serializable/Codable associated-type protocol layer.

## References

- parsing-serialization-capability-organization: [parsing-serialization-capability-organization.md](parsing-serialization-capability-organization.md)
- ascii-parsing-domain-ownership: [ascii-parsing-domain-ownership.md](ascii-parsing-domain-ownership.md)
- parser-primitives protocols: `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/`
- Binary.Coder: `/Users/coen/Developer/swift-primitives/swift-binary-parser-primitives/Sources/Binary Coder Primitives/Binary.Coder.swift`
- Witness.Protocol: `/Users/coen/Developer/swift-primitives/swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift`
- Dependency.Key: `/Users/coen/Developer/swift-primitives/swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Key.swift`
- Binary.Serializable: `/Users/coen/Developer/swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift`
- serialization-primitives witnesses: `/Users/coen/Developer/swift-primitives/swift-serializer-primitives/Sources/Serialization Primitives/`
- Rust serde: https://docs.rs/serde
- pointfreeco/swift-parsing: https://github.com/pointfreeco/swift-parsing
- Boost.Spirit: https://www.boost.org/doc/libs/release/libs/spirit/
- Haskell binary: https://hackage.haskell.org/package/binary
- [API-NAME-001] Namespace Structure
- [MOD-DOMAIN] One domain per package
- [PRIM-FOUND-001] No Foundation
- [RES-001] Investigation Triggers
- [RES-021] Prior Art Survey
