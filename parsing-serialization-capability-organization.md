# Parsing and Serialization Capability Organization

<!--
---
version: 1.4.0
last_updated: 2026-03-15
status: SUPERSEDED
tier: 2
superseded_by: transformation-domain-architecture.md (DECISION incorporating this analysis)
---
-->

## Context

The Swift Institute ecosystem has three distinct systems for data transformation
(parsing structured values from bytes, serializing structured values into bytes):

1. **Capability protocols** in parser-primitives — `Parser.Protocol`, `Parser.Serializer`,
   `Parser.Printer`, `Parser.ParserPrinter` — composable struct-based types for grammar
   composition.

2. **Witness types** in serialization-primitives — `Serialization.Serializing.Buffer`,
   `Serialization.Serializing.Value`, `Serialization.Parsing.Whole`,
   `Serialization.Parsing.Prefix.Witness` — closure-based callable types for capability
   attachment.

3. **Ad-hoc serialization protocols** in domain packages — `Binary.ASCII.Serializable`
   (swift-ascii, L3), `JSON.Serializable` (swift-json, L3), `Plist.Serializable`
   (swift-plist, L3), `Binary.Serializable` (swift-ascii, L3) — type-level contracts
   for domain-specific round-trip conversion.

Additionally, binary-parser-primitives defines `Binary.Coder<Output>` — a witness-based
bidirectional coder with separate decode/encode types.

These systems evolved independently. This document analyzes them from first principles
to establish how they relate, where each belongs, and how domains should organize their
transformation capabilities across the five-layer architecture.

### Trigger

[RES-012] Discovery research. The ascii-parsing-domain-ownership research (v4.2)
established a "domains as namespaces, capabilities as nested types" principle for parser
namespace organization. This document generalizes that principle to the full
transformation landscape.

### Constraints

- Five-layer architecture: Primitives → Standards → Foundations → Components → Applications
- Downward-only dependencies
- [API-NAME-001] `Nest.Name` pattern
- [PRIM-FOUND-001] No Foundation imports in L1/L2
- parser-primitives at Tier 17, serialization-primitives at Tier 3

### Stakeholders

All packages that parse, serialize, print, or code data — nearly every package in the
ecosystem.

## Question

**From first principles, what are the fundamental data transformation domains, how do
the three implementation strategies (protocols, witnesses, ad-hoc protocols) relate,
and how should domains organize their transformation capabilities?**

Sub-questions:
1. What are the irreducible transformation operations? (Is there a fourth beyond
   parsing/serialization/printing?)
2. When should a domain use protocol-based parsers vs witness-based serialization vs
   ad-hoc Serializable protocols?
3. How should domain namespaces accommodate multiple transformation capabilities?
4. How do the transformation capabilities distribute across the five-layer architecture?
5. What is the relationship between execution models (leaf, declarative, Machine IR)?

## Prior Art Survey

### Within the Ecosystem

[RES-021] Existing research and infrastructure:

| Document/Package | Contribution |
|-----------------|--------------|
| ascii-parsing-domain-ownership (v4.2) | "Domains as namespaces, capabilities as nested types" principle |
| parser-combinator-algebraic-foundations | Parser algebra: functor/monad laws, semiring structure |
| parser-bridge-architecture | `Parser.ByteInput` typealias, `var body` declarative composition |
| parser-bridge-ergonomics-assessment | MediaType exemplar validates bridge pattern |
| parsers-ecosystem-adoption-audit | 95 opportunities, 52 HIGH across ~30 standards packages |
| parser-primitives (Tier 17) | Four capability protocols, 33 combinator modules |
| serialization-primitives (Tier 3) | Five witness types with context support |
| binary-parser-primitives (Tier 20) | `Binary.Coder`, Machine IR, `Binary.Parse.Access` |
| binary-primitives (Tier 11) | `[UInt8](leb128:)` — initializer-based serialization |

### External Prior Art

| System | Approach |
|--------|----------|
| Swift Codable | Protocol pair (`Encodable`/`Decodable`) with strategy objects (`JSONEncoder`) |
| Swift Parsing (pointfreeco) | `ParserPrinter` protocol, `Conversion` type for round-trip |
| Rust serde | Trait pair (`Serialize`/`Deserialize`) with visitor pattern |
| Haskell parsec/megaparsec | Monad transformers, no built-in printing counterpart |
| Haskell aeson | Typeclass pair (`ToJSON`/`FromJSON`), independent of parsec |
| Boost.Spirit | Expression template parser-generator with Karma (printer counterpart) |

**Key observation**: Every mature ecosystem separates parsing from serialization at the
type level. Round-trip (parser-printer) is always opt-in, never the default — because
most transformations are inherently asymmetric.

## Analysis

### Part 1: Fundamental Transformation Domains

From first principles, data transformation has two irreducible operations:

| Operation | Signature | Direction |
|-----------|-----------|-----------|
| **Decode** | `Input → Value` | bytes → structure |
| **Encode** | `Value → Output` | structure → bytes |

Everything else is a refinement along three orthogonal axes:

#### Axis 1: Consumption Model

| Model | Decode | Encode |
|-------|--------|--------|
| **Complete** | Consumes all input, fails if remainder | Produces complete output |
| **Streaming/Prefix** | Consumes prefix, leaves remainder | Appends to existing buffer |

#### Axis 2: Buffer Construction Order

| Order | Semantics | Performance | Use Case |
|-------|-----------|-------------|----------|
| **Append** | Write forward | O(1) amortized | Serialization (one-way) |
| **Prepend** | Write backward | O(n) per operation | Printing (round-trip with parser) |

#### Axis 3: Round-Trip Guarantee

| Guarantee | Constraint |
|-----------|------------|
| **One-way** | Decode only, or encode only |
| **Bidirectional** | `decode(encode(v)) == v` and `encode(decode(i)) == i` |

#### The Four Capability Protocols

The four protocols in parser-primitives map to specific positions in this space:

| Protocol | Operation | Consumption | Buffer Order | Round-Trip |
|----------|-----------|-------------|--------------|------------|
| `Parser.Protocol` | Decode | Streaming (prefix) | N/A | No |
| `Parser.Serializer` | Encode | Streaming (append) | Append | No |
| `Parser.Printer` | Encode | Streaming (prepend) | Prepend | Designed for it |
| `Parser.ParserPrinter` | Both | Streaming | Prepend (encode) | Yes |

**`Parser.ParserPrinter` is not a fourth domain** — it is the conjunction of
`Parser.Protocol` and `Parser.Printer`. It exists as a convenience protocol to
express that a single type satisfies both, enabling the compiler to enforce round-trip
guarantees structurally.

**`Parser.Serializer` IS a genuine third domain** alongside parsing and printing. It
exists because:

1. **Performance**: Append is O(1) amortized; prepend is O(n) per operation. For
   one-way serialization (JSON encoding, binary format emission, logging), prepend's
   O(n²) aggregate cost is unacceptable.

2. **Asymmetry**: Most serialization has no parsing counterpart in the same type. An
   HTTP response serializer and an HTTP request parser are different types with different
   error modes. Forcing them into a single `ParserPrinter` would be artificial.

3. **Buffer type independence**: `Serializer` has its own `Buffer` associated type (not
   constrained to `Input`). A JSON serializer might append to `[UInt8]`, `String`, or a
   rope — the buffer is the serializer's choice.

#### Summary: Three Fundamental Capabilities (Plus One Conjunction)

```
Parsing       ← consuming input to produce values    (Parser.Protocol)
Serialization ← appending values to output buffers   (Parser.Serializer)
Printing      ← prepending values to input buffers   (Parser.Printer)
                                                      ↑
Coding        ← parsing + printing in one type        (Parser.ParserPrinter)
```

The "fourth domain" is coding (bidirectional transformation), realized as the
conjunction of parsing and printing. It is not an independent capability — it inherits
its semantics from its constituents.

### Part 2: Three Implementation Strategies

The ecosystem has three strategies for attaching transformation capabilities to types.
They are not competing — they serve different roles.

#### Strategy A: Capability Protocols (parser-primitives)

**What**: Struct types that conform to `Parser.Protocol`, `Parser.Serializer`,
`Parser.Printer`, or `Parser.ParserPrinter`.

**When to use**: When the transformation IS the type's purpose — the type exists to
parse or serialize. These types compose via combinators (`map`, `flatMap`, `oneOf`,
`take`, `skip`) and the `@Parser.Builder` result builder.

**Characteristics**:
- Stateful structs with zero-allocation parsing loops
- `@inlinable` for specialization across module boundaries
- Generic over `Input` (supporting `~Copyable & ~Escapable`)
- Typed throws with domain-specific error types
- Declarative composition via `var body`

**Example**:
```swift
struct HTTP.MediaType.Parser<Input: Collection.Slice.Protocol>: Parser.Protocol
where Input.Element == UInt8 {
    var body: some Parser.Protocol<Input, MediaType, Error> {
        Parser.Take.Sequence {
            OWS<Input>()
            Token<Input>()
            Slash<Input>()
            Token<Input>()
        }
        .map { ... }
    }
}
```

**Layer**: Protocols defined at L1 (parser-primitives, Tier 17). Concrete parser structs
at any layer.

#### Strategy B: Witness Types (serialization-primitives)

**What**: Callable struct types storing closures — `Serialization.Serializing.Buffer`,
`Serialization.Parsing.Whole`, etc.

**When to use**: When a type HAS serialization capability as one of many concerns — the
capability is attached as a static property or stored value, not as the type's identity.

**Characteristics**:
- Closure-based (not protocol conformance)
- Context-parameterized (`Context` generic allows dependency injection)
- Sendable (closures are `@Sendable`)
- Multiple witnesses per type (a type can have `.ascii`, `.json`, `.binary` witnesses)
- No combinator algebra (witnesses don't compose with `map`/`flatMap`)

**Example**:
```swift
extension UInt16 {
    static var ascii: Serialization.Serializing.Buffer<UInt16, UInt8, Void> {
        .init { value, _, buffer in
            // append ASCII decimal digits
        }
    }
}
```

**Layer**: Witness types defined at L1 (serialization-primitives, Tier 3). Static
witness properties at any layer.

#### Strategy C: Domain Serializable Protocols (ad-hoc)

**What**: Protocol conformances declaring a type can round-trip through a specific
representation format.

**When to use**: When every conforming type follows the same serialization contract for
a specific format — `JSON.Serializable`, `Binary.ASCII.Serializable`, etc.

**Characteristics**:
- Compile-time conformance (one implementation per type per format)
- Round-trip by convention (both `init` and `serialize` required)
- Default implementations derived (e.g., `CustomStringConvertible` from ASCII)
- Typically context-free or with minimal context
- No compositional algebra

**Example**:
```swift
extension UInt16: Binary.ASCII.Serializable {
    init<Bytes: Collection>(ascii bytes: Bytes, in context: Void) throws(Error) { ... }
    static func serialize<Buffer>(ascii value: Self, into buffer: inout Buffer) { ... }
}
```

**Layer**: Protocol definitions at L3 (Foundations). Conformances at L2/L3.

#### Strategy Selection Matrix

| Criterion | A: Capability Protocol | B: Witness | C: Domain Protocol |
|-----------|:-----:|:-----:|:-----:|
| Type's primary purpose is transformation | **Yes** | No | No |
| Multiple formats per type | No (one conformance) | **Yes** (multiple witnesses) | No (one per protocol) |
| Grammar composition needed | **Yes** (combinators) | No | No |
| Context/configuration injection | Via struct properties | **Yes** (`Context` generic) | Limited |
| Round-trip guarantee | ParserPrinter only | No (separate witnesses) | By convention |
| Performance-critical inner loops | **Yes** (`@inlinable`) | Closure indirection | Protocol witness table |
| Streaming/prefix consumption | **Yes** | Prefix witness available | Typically complete |
| Multiple witnesses for same type | Separate struct types | **Yes** (separate properties) | No |

**The three strategies are complementary, not competing.**

A domain parser struct (`ASCII.Decimal.Parser`) conforms to `Parser.Protocol`
(Strategy A). That parser can be wrapped in a `Serialization.Parsing.Prefix.Witness`
for types that want to attach ASCII parsing as a property (Strategy B). And a higher-level
protocol (`Binary.ASCII.Serializable`) can provide the type-level contract that mandates
both parsing and serialization (Strategy C, using Strategy A or B internally).

### Part 3: Relationship Between Protocols and Witnesses

The capability protocols and witness types are not parallel systems — they sit at
different abstraction levels:

```
Layer 3: Domain Protocols (JSON.Serializable, Binary.ASCII.Serializable)
         "Types that conform can be serialized in format X"
              ↓ implementations use
Layer 2: Capability Protocols (Parser.Protocol, Parser.Serializer)
         "Types that ARE parsers/serializers"
              ↓ can be wrapped into
Layer 1: Witness Types (Serialization.Parsing.Whole, Serialization.Serializing.Buffer)
         "Callable values that perform parsing/serialization"
```

**From protocol to witness**: Any `Parser.Protocol` conformer can be lifted into a
`Serialization.Parsing.Prefix.Witness`:

```swift
extension Parser.Protocol {
    var asPrefixWitness: Serialization.Parsing.Prefix.Witness<ParseOutput, Int, Input, Void, Failure> {
        .init { input, _ in
            var mutableInput = input
            let startCount = mutableInput.remainingCount
            let value = try self.parse(&mutableInput)
            let consumed = startCount - mutableInput.remainingCount
            return .init(value: value, count: consumed)
        }
    }
}
```

**From witness to protocol**: A witness can be wrapped in a struct that conforms to
`Parser.Protocol` — but this is less natural, since witnesses typically lack the
compositional structure that makes protocol-based parsers valuable.

**The practical pattern**: Parser-primitives defines the compositional grammar algebra.
Serialization-primitives defines the attachment mechanism. Domain packages use both:
parser structs for complex grammars, witnesses for simple capability attachment.

#### Binary.Coder: A Witness That Bridges Both Directions

`Binary.Coder<Output>` is a witness-based bidirectional coder with a key design
insight: **decode and encode use different types**.

```swift
struct Coder<Output>: Sendable {
    var decode: (inout Binary.Bytes.Input) throws(Fault) -> Output  // read-only cursor
    var encode: (Output, inout [UInt8]) -> Void                     // mutable buffer
}
```

This is more practical than `Parser.ParserPrinter` for binary formats because:

1. **`ParserPrinter` requires the same `Input` type for both directions.** Decoding
   needs a cursor with checkpoint/restore; encoding needs a mutable buffer with append.
   These are fundamentally different data structures.

2. **Coder uses append semantics for encoding** (not prepend). This avoids the O(n²)
   cost of `Printer`'s prepend semantics.

3. **Coder is a witness** (stored value), not a protocol conformance. A type can have
   multiple coders (e.g., big-endian vs little-endian).

`Binary.Coder` occupies a niche: bidirectional binary coding where round-trip
correctness matters but `ParserPrinter`'s prepend-based symmetry is impractical. It
uses `Parser.Protocol`-compatible decoding (via `Binary.Bytes.Input`) with
`Serializer`-compatible encoding (append to `[UInt8]`).

### Part 4: Domain Namespace Organization

How should a domain organize its transformation capabilities? The answer depends on
the domain's complexity:

#### Case 1: Simple Domain (Degenerate Case)

When a domain's serialization is trivial — expressible as collection initializers or
simple conversions — the domain type MAY directly conform to `Parser.Protocol`:

```swift
// Binary.LEB128.Unsigned<T> conforms to Parser.Protocol
// Serialization is just [UInt8](leb128: value) at a lower layer
// No need for .Serializer, .Error, .Machine siblings
Binary.LEB128.Unsigned<T>
```

**Criterion**: No structured serialization concern requiring namespace siblings.
Collection initializers suffice at a lower layer.

#### Case 2: Complex Domain (General Case)

When a domain has multiple capabilities (parsing AND serialization, or complex error
types, or Machine IR alternatives), the domain namespace MUST remain open:

```swift
ASCII.Decimal                    // empty enum namespace
├── .Parser<Input, T>            // Parser.Protocol conformer
├── .Serializer<T>               // future: Parser.Serializer conformer
├── .Error                       // shared error type
└── .Machine                     // L3: Machine IR factories

HTTP.MediaType                   // struct (the domain value type)
├── .Parser<Input>               // Parser.Protocol conformer
├── .Serializer                  // future: serialization to wire format
└── .Parser.Error                // parser-specific error
```

**Principle**: Domains are namespaces; capabilities are nested types. A domain
namespace SHOULD NOT be consumed by a single capability type.

#### Case 3: Standards Domain

Standards packages (L2) follow the domain-owned pattern with subject-first naming:

```swift
RFC_9110.Request.Serializer      // "RFC 9110 request's serializer"
ISO_8601.DateTime.Parse<Input>   // "ISO 8601 datetime's parser"
RFC_3986.URI.Scheme.Parse<Input> // "RFC 3986 URI scheme's parser"
```

**Convention split**: Standards use both `.Parse` (verb, 22 instances) and `.Parser`
(noun, 25 instances). The ascii-parsing-domain-ownership research recommends `.Parser`
(noun) as a design choice. This convention should be unified — but the unification is
a separate effort.

#### Naming Pattern

| Pattern | Reading | When |
|---------|---------|------|
| `Domain.Subject.Parser` | "domain's subject's parser" | Subject needs its own namespace |
| `Domain.Parser` | "domain's parser" | Domain IS the subject |
| `Domain.Subject` (directly) | "domain's subject" | Degenerate: subject IS the parser |

### Part 5: Layer Distribution

#### L1 — Primitives: Mechanisms

| Package | Tier | Provides |
|---------|------|----------|
| serialization-primitives | 3 | Witness types (Parsing.Whole, Serializing.Buffer, Measuring) |
| parser-primitives | 17 | Capability protocols, combinators, result builder |
| ascii-parser-primitives | 18 | `ASCII.Decimal.Parser`, `ASCII.Hexadecimal.Parser` |
| binary-parser-primitives | 20 | `Binary.Coder`, `Binary.Bytes.Input`, Machine IR, `Binary.Parse.Access` |

**Principle**: L1 provides mechanisms — protocols, combinators, execution infrastructure.
No domain-specific serialization formats.

**Tier gap**: serialization-primitives (Tier 3) and parser-primitives (Tier 17) are
14 tiers apart. serialization-primitives has zero dependency on parser-primitives.
This is correct: witness-based serialization is a lower-level concept than composable
parsing. Witnesses are closures; parsers are algebraic types.

#### L2 — Standards: Domain Parsers

Standards packages define domain-owned parser structs:

```swift
// Each standard owns its parsers in its own namespace:
HTTP.MediaType.Parser<Input>          // RFC 9110
ISO_8601.DateTime.Parse<Input>        // ISO 8601
RFC_3986.URI.Scheme.Parse<Input>      // RFC 3986
RFC_8259.JSON.Parser                  // RFC 8259 (production)
RFC_8259.ParserPrinter.Prototype      // RFC 8259 (experimental)
```

Standards packages also define ad-hoc serializers (not yet protocol-based):

```swift
RFC_9110.Request.Serializer           // static methods, not Parser.Serializer conformer
W3C_SVG2.Paths.Path.Serializer       // static methods, not Parser.Serializer conformer
```

**Observation**: Serializers in L2 are ad-hoc static structs. None conform to
`Parser.Serializer`. This is an adoption gap — when these are migrated to
`Parser.Serializer` conformances, they gain the standard `serialize(_:into:)` →
`serialize(_:)` convenience chain.

#### L3 — Foundations: Policies and Integration

Foundations packages define:

1. **Domain serialization protocols**: `Binary.ASCII.Serializable` (60+ conformances),
   `JSON.Serializable`, `Plist.Serializable`
2. **Machine IR compositions**: `ASCII.Decimal.Machine` (compiled parser programs)
3. **Convenience APIs**: `.ascii.whole()`, `.json` property, `init(plist:)`
4. **Higher-level composition**: swift-parsers (expression parsers, Pratt climbing)

**Principle**: L3 provides policies — which serialization format, what error recovery
strategy, how to compose transformations for end-user convenience.

### Part 6: Execution Models

Three execution models exist for parsing:

| Model | Package | Characteristics |
|-------|---------|----------------|
| **Leaf** | parser-primitives | Direct `parse(_:)`, `@inlinable`, zero-allocation |
| **Declarative** | parser-primitives | `var body` with result builder, composes leaf parsers |
| **Machine IR** | binary-parser-primitives | Defunctionalized closures → instruction programs |

**Leaf parsers** are the primary execution model. They compile to tight loops with
full specialization. Suitable for all layers, likely embedded-compatible.

**Declarative parsers** compose leaf parsers via the `@Parser.Builder` result builder.
The `var body` property returns a composed parser that the default `parse(_:)` delegates
to. Error types compose via `Parser.Error.Either`.

**Machine IR** (via `Binary.Bytes.Machine.Builder`) compiles parser closures into
instruction data structures. This solves the `~Escapable` problem: closures cannot
capture `~Escapable` values, but defunctionalized instructions can. Machine IR enables
stack-safe recursive parsing at the cost of dispatch overhead.

**Relationship**: Leaf and declarative are the standard path. Machine IR is specialized
for:
- `~Escapable` borrowed input (`Binary.Bytes.Input.View`)
- Recursive grammars requiring stack safety
- Dynamic parser construction at runtime

Domains should default to leaf/declarative parsers. Machine IR is warranted when one
of the above constraints applies.

### Part 7: Deprecation Trajectory

`Binary.ASCII.Serializable` is deprecated in favor of witness-based properties:

```swift
// Deprecated protocol:
extension UInt16: Binary.ASCII.Serializable { ... }

// Modern witness:
extension UInt16 {
    static var ascii: Serialization.Serializing.Buffer<UInt16, UInt8, Void> { ... }
}
```

This signals a broader trajectory: **domain serialization protocols (Strategy C) are
being replaced by witness properties (Strategy B) for simple transformations**, while
**capability protocols (Strategy A) handle complex grammar composition**.

The remaining question is whether a replacement domain protocol is needed at all, or
whether witness properties alone suffice. This is the subject of the deferred
`ascii-serialization-migration.md` research.

### Part 8: Open Tensions

#### Tension 1: Naming Convention Split — RESOLVED

Standards packages use `.Parse` (verb, 22 instances) and `.Parser` (noun, 25 instances)
for nested parser types.

**Resolved**: `.Parser` (noun) is the decided convention. Type names describe what a
type IS, consistent with Swift naming guidelines. This decision is recorded in
[transformation-domain-architecture.md](transformation-domain-architecture.md) v3.0.0.
Migration of existing `.Parse` types is a separate implementation effort.

#### Tension 2: Serializer Protocol Adoption Gap — PARTIALLY RESOLVED

Zero standards-layer serializers conform to `Serializer.Protocol` (formerly
`Parser.Serializer`). All use ad-hoc static methods. This means they don't benefit
from the convenience chain (`serialize(_:into:)` → `serialize(_:)`).

**Resolution**: `Serializer.Protocol` now has its own package
(`swift-serializer-primitives`) with `@Serializer.Builder` from the start
(transformation-domain-architecture v3.2.0 DECISION). As parser adoption proceeds
(95 opportunities per audit), serializer adoption should follow.

#### Tension 3: ParserPrinter Prepend Cost

`Parser.ParserPrinter` uses prepend semantics (from `Parser.Printer`), causing O(n²)
aggregate cost. The RFC 8259 JSON prototype acknowledges this:

> "For pure serialization (no parsing counterpart), prepend semantics cause O(n)
> per operation, leading to O(n²) overall."

`Binary.Coder` solves this by using append for encoding — but it is a witness, not a
protocol conformance, and it is locked to `Binary.Bytes.Input` / `[UInt8]`.

**Implication**: For formats where round-trip is desired but prepend cost is
unacceptable, types should implement `Parser.Protocol` and `Parser.Serializer`
separately rather than `Parser.ParserPrinter`. The bidirectional guarantee is then
tested rather than structurally enforced.

#### Tension 4: Two Parallel Serialization Systems — RESOLVED

serialization-primitives (Tier 3, witnesses) and parser-primitives (Tier 17,
protocols) both address serialization. They are not redundant — witnesses are for
capability attachment, protocols are for compositional types — but the relationship
was undocumented.

**Resolution**: The three-independent-packages architecture (transformation-domain
v3.2.0 DECISION) resolves this:

1. `swift-serialization-primitives` renamed to `swift-serializer-primitives`
2. `Serializer.Protocol` + `@Serializer.Builder` + `Serializable` added alongside
   existing `Serialization.*` witnesses in the same package
3. The protocol-to-witness lifting pattern (Part 3 above) generalizes the existing
   `Binary.Serializable.serializing` bridge
4. Canonical/witness coexistence validated by
   [canonical-witness-capability-attachment.md](canonical-witness-capability-attachment.md)
   (DECISION, 10/10 experiment variants CONFIRMED)

One package, two namespaces (`Serializer` for protocols, `Serialization` for
witnesses), with bridge infrastructure between them.

## Outcome

**Status**: RECOMMENDATION

### Findings

#### Finding 1: Three Fundamental Capabilities

The ecosystem has three fundamental transformation capabilities, plus one conjunction:

| Capability | Protocol | Purpose |
|------------|----------|---------|
| Parsing | `Parser.Protocol` | Consume input → produce value |
| Serialization | `Parser.Serializer` | Append value → output buffer |
| Printing | `Parser.Printer` | Prepend value → input buffer (round-trip) |
| Coding | `Parser.ParserPrinter` | Parsing + Printing (conjunction, not independent) |

`ParserPrinter` is not a fourth domain — it is the structural conjunction of
`Parser.Protocol` and `Parser.Printer`, providing compile-time round-trip guarantees.

#### Finding 2: Three Complementary Implementation Strategies

| Strategy | For | Level |
|----------|-----|-------|
| Capability Protocols | Types that ARE parsers/serializers | Composition |
| Witness Types | Types that HAVE parsing/serialization | Attachment |
| Domain Protocols | Types that CONFORM to format contracts | Convention |

These are not competing. They compose: a domain protocol's implementation can delegate
to a capability protocol conformer, which can be lifted into a witness for attachment.

#### Finding 3: Domain Namespace Principle

**Domains are namespaces; capabilities are nested types.** When a domain has (or may
have) multiple transformation capabilities, the domain namespace must remain open:

```swift
Domain.Subject.Parser         // Parser.Protocol conformer
Domain.Subject.Serializer     // Parser.Serializer conformer
Domain.Subject.Error          // shared error type
```

**Degenerate exception**: When serialization is trivial (collection initializers at a
lower layer, no structured namespace siblings needed), the domain type may directly
conform to `Parser.Protocol` (e.g., `Binary.LEB128.Unsigned<T>`).

#### Finding 4: Layer Responsibilities

| Layer | Responsibility | Examples |
|-------|---------------|----------|
| L1 Primitives | Mechanisms — protocols, combinators, witnesses | parser-primitives, serialization-primitives |
| L2 Standards | Domain parsers — specification-specific transformations | `HTTP.MediaType.Parser`, `ISO_8601.DateTime.Parse` |
| L3 Foundations | Policies — format protocols, Machine IR, convenience | `Binary.ASCII.Serializable`, `ASCII.Decimal.Machine` |

#### Finding 5: Default Execution Model

Leaf/declarative parsers are the primary execution model. Machine IR is specialized
for `~Escapable` inputs, recursive grammars, and dynamic parser construction. Domains
should default to leaf parsers and escalate to Machine IR only when constrained.

### Recommendations

| # | Recommendation | Priority |
|---|---------------|----------|
| R1 | ~~Unify `.Parse` vs `.Parser` naming convention across standards~~ RESOLVED: `.Parser` decided | DONE |
| R2 | Migrate ad-hoc serializers to `Serializer.Protocol` conformances as parser adoption proceeds | MEDIUM |
| R3 | Document protocol-to-witness lifting pattern; consider bridge initializer | MEDIUM |
| R4 | Complete `ascii-serialization-migration.md` to resolve Strategy C → Strategy B transition | HIGH |
| R5 | For formats needing bidirectional with append semantics, prefer separate `Parser.Protocol` + `Parser.Serializer` over `Parser.ParserPrinter` | DESIGN GUIDANCE |
| R6 | Add `Serializer` nested types alongside `Parser` nested types as domains adopt serialization | LOW (follow parser adoption) |

### Open Items

| Item | Action | Tracking |
|------|--------|----------|
| ~~`.Parse` vs `.Parser` convention unification~~ | RESOLVED: `.Parser` decided (transformation-domain-architecture v3.0.0) | Migration task |
| ~~`Parser.Serializer` adoption in standards~~ | RESOLVED: Now `Serializer.Protocol` in own package with Builder | transformation-domain-architecture v3.2.0 |
| ~~Protocol-to-witness bridge module~~ | RESOLVED: Bridge pattern documented in transformation-domain-architecture Part 6 | Engineering task |
| ~~`Binary.ASCII.Serializable` migration~~ | RESOLVED: Full migration plan | [ascii-serialization-migration.md](ascii-serialization-migration.md) (DECISION) |
| ~~`Binary.Coder` generalization~~ | RESOLVED: `Coder.Protocol` in `swift-coder-primitives` (new package) | transformation-domain-architecture v3.2.0 |

## Changelog

- **v1.3.0** (2026-03-04): Binary.ASCII.Serializable migration open item resolved —
  full migration plan in ascii-serialization-migration.md (DECISION). All open items
  now resolved or tracked. Status remains RECOMMENDATION.
- **v1.2.0** (2026-03-04): Updated for transformation-domain-architecture v3.2.0
  (DECISION) and canonical-witness-capability-attachment v1.2.0 (DECISION). Tension 2
  partially resolved (Serializer.Protocol now in own package). Tension 4 fully resolved
  (one serializer-primitives package, protocol + witnesses, bridge pattern). Three
  open items resolved (Parser.Serializer → Serializer.Protocol, bridge module,
  Binary.Coder generalization → Coder.Protocol). Status IN_PROGRESS → RECOMMENDATION.
- **v1.1.0** (2026-03-04): Updated for transformation-domain-architecture v3.0.0
  alignment. Resolved Tension 1 (`.Parser` naming decided). Updated Tension 4 with
  witness integration bridge pattern and serializer-primitives package note. Updated
  R1 (resolved) and `.Parse`/`.Parser` open item (resolved).
- **v1.0.0** (2026-03-04): Initial from-first-principles analysis. Three fundamental
  capabilities (parsing, serialization, printing) plus one conjunction (coding). Three
  complementary implementation strategies (protocols, witnesses, domain protocols).
  Domain namespace principle. Layer distribution. Eight open tensions identified.

## References

- parser-primitives protocols: `https://github.com/swift-primitives/swift-parser-primitives/tree/main/Sources/Parser Primitives Core/`
- serialization-primitives witnesses: `https://github.com/swift-primitives/swift-serialization-primitives/tree/main/Sources/Serialization Primitives/`
- Binary.Coder: `https://github.com/swift-primitives/swift-binary-parser-primitives/blob/main/Sources/Binary Coder Primitives/Binary.Coder.swift`
- ascii-parsing-domain-ownership: [ascii-parsing-domain-ownership.md](ascii-parsing-domain-ownership.md)
- ascii-parsing-adversarial-review: [ascii-parsing-adversarial-review.md](ascii-parsing-adversarial-review.md)
- parser-combinator-algebraic-foundations: [parser-combinator-algebraic-foundations.md](parser-combinator-algebraic-foundations.md)
- parser-bridge-architecture: internal implementation plan
- parsers-ecosystem-adoption-audit: [parsers-ecosystem-adoption-audit.md](parsers-ecosystem-adoption-audit.md)
- parsers-adoption-implementation-plan: [parsers-adoption-implementation-plan.md](parsers-adoption-implementation-plan.md)
- [API-NAME-001] Namespace Structure
- [API-NAME-003] Specification-Mirroring Names
- [RES-012] Discovery Triggers
- [RES-021] Prior Art Survey
