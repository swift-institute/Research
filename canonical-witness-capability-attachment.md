# Canonical and Witness Capability Attachment

<!--
---
version: 1.2.0
last_updated: 2026-03-04
status: DECISION
tier: 2
---
-->

## Context

The transformation domain architecture (v3.1.0) established three domain protocols
(`Parser.Protocol`, `Serializer.Protocol`, `Coder.Protocol`) and three associated-type
protocols for type-level capability attachment (`Parseable`, `Serializable`, `Codable`).

The associated-type protocols as currently designed give exactly ONE implementation
per type:

```swift
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    static var parser: Parser { get }
}
```

But the ecosystem already demonstrates that types often need MULTIPLE parsers,
serializers, or coders:

- `UInt32.coder(endianness: .little)` vs `.coder(endianness: .big)` — two Binary.Coders
- `IPv4.Address: Binary.Serializable` (raw bytes) AND `Binary.ASCII.Serializable`
  (dotted-decimal text) — two serialization formats
- `Int: Binary.ASCII.Serializable` — canonical decimal, but hex is also valid
- `Witness.Protocol` types with `.darwin`, `.linux`, `.mock` variants

The question is how to reconcile single-conformance protocols (generic constrainability)
with the witness pattern (multiplicity).

### Trigger

[RES-001] Pattern selection — during transformation domain architecture design,
identified tension between protocol-based single conformance and witness-based
multiplicity for `Parseable`/`Serializable`/`Codable`.

### Constraints

- [API-NAME-001] `Nest.Name` pattern
- `Witness.Protocol` and `Dependency.Key` are the established witness/DI infrastructure
- `Binary.Coder` already demonstrates parameterized witness pattern
- `Binary.Serializable` + `.serializing` bridge demonstrates protocol-to-witness lifting
- Protocol conformance is compile-time, single per type; witnesses are values, multiple per type
- Generic constrainability (`func f<T: Parseable>`) requires a protocol

### Stakeholders

All packages that define types with parsing, serialization, or coding capabilities.

## Question

**How should types attach transformation capabilities — protocol conformance (single
canonical), witness properties (multiple alternatives), or both?**

Sub-questions:
1. Is single-conformance a fundamental limitation or an acceptable design choice?
2. Can a protocol-based canonical coexist cleanly with witness-based alternatives?
3. What is the generic constrainability story for witness-based approaches?
4. How does `Dependency.Key` (live/test) relate to canonical/alternative?

## Prior Art Survey

### Within the Ecosystem

[RES-021] Existing patterns for canonical + alternative:

| Pattern | Canonical Mechanism | Alternative Mechanism | Example |
|---------|--------------------|-----------------------|---------|
| `Binary.Serializable` + `.serializing` | Protocol conformance | Bridge to `Serialization.Serializing.Buffer` witness | `RFC_9293.Header` |
| `Binary.Serializable` + `Binary.ASCII.Serializable` | Two separate protocols | Each gives one canonical per format | `IPv4.Address`, `Int` |
| `Binary.Coder` factory | None (no protocol) | Parameterized static factory `.coder(endianness:)` | `UInt32`, `Int64` |
| `Dependency.Key` | `liveValue` (production) | `testValue` + runtime override via `Dependency.Scope` | `CounterKey` |
| `Witness.Protocol` variants | `.darwin` or `.live` | `.linux`, `.mock`, `.test` as static properties | `FileSystem` |
| Strategy enums | Switch-based dispatch | Enum cases select algorithm | `FormData.ParsingStrategy` |

**Key observation**: The ecosystem already uses BOTH protocols (single canonical) and
witnesses (multiple alternatives). They coexist on the same types. `Binary.Serializable`
gives the canonical binary representation; `.serializing` bridges it to a witness for
functional composition. `Binary.Coder` is witness-only (no protocol) because coders are
inherently parameterized (endianness, alignment).

### External Prior Art

| System | Canonical | Alternatives | Multiplicity |
|--------|-----------|-------------|--------------|
| Swift `Codable` | Protocol conformance (`Encodable` + `Decodable`) | Strategy objects (`JSONEncoder`, `PropertyListEncoder`) | One conformance, multiple strategies |
| Rust serde | Trait impl (`Serialize` + `Deserialize`) | `#[serde(with = "module")]` attribute | One canonical, field-level overrides |
| Haskell aeson | Typeclass instance (`ToJSON` + `FromJSON`) | Newtype wrappers with different instances | One per type, newtypes for alternatives |
| Haskell binary | Typeclass instance (`Binary`) | `Put`/`Get` monad for custom | One per type, manual for alternatives |
| Go `encoding/json` | `json.Marshaler`/`json.Unmarshaler` interface | `encoding.TextMarshaler` for text format | One per interface, multiple interfaces |

**Universal pattern**: Every ecosystem uses single-conformance for the canonical
representation. Alternatives use either:
- **Strategy objects** (Swift Codable: `JSONEncoder` configures the format)
- **Newtype wrappers** (Haskell: `newtype Hex a = Hex a` with different instance)
- **Attribute overrides** (Rust serde: field-level `#[serde(with)]`)
- **Separate protocols/interfaces** (Go: `Marshaler` vs `TextMarshaler`)

None use multiple conformances to the same protocol for the same type. Single canonical
is universal.

## Analysis

### Option A: Protocol-Only (Single Canonical)

```swift
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    static var parser: Parser { get }
}

// One canonical parser per type:
extension UInt32: Parseable {
    static var parser: Binary.Coder<UInt32>.AsParser { ... }
}
```

**Advantages**:
- Simple — one protocol, one implementation per type
- Generic constrainability: `func parse<T: Parseable>(_ input: inout Input) -> T`
- Matches all external prior art
- Compile-time guaranteed availability

**Disadvantages**:
- Only ONE parser per type — which endianness? which format?
- The "canonical" choice may be arbitrary (is `UInt32` natively little-endian or
  big-endian? depends on platform)
- No way to express "parse this type from ASCII" vs "parse from binary" through
  the protocol alone
- Types needing multiple representations must use separate mechanisms anyway

### Option B: Witness-Only (No Protocol)

```swift
// No Parseable protocol. Types provide witness properties:
extension UInt32 {
    static var binaryParser: SomeParser { ... }
    static var asciiParser: SomeParser { ... }
}
```

**Advantages**:
- Multiple implementations per type — natural
- Explicit at call site: `UInt32.binaryParser` vs `UInt32.asciiParser`
- No arbitrary "canonical" choice forced
- Matches `Binary.Coder(endianness:)` existing pattern

**Disadvantages**:
- No generic constrainability — cannot write `func f<T: ???>()`
- No compile-time guarantee that a type provides a parser
- No standard naming convention for witness properties (`.parser`? `.binaryParser`?
  `.asciiParser`?)
- Discoverability: consumers must know the property names

### Option C: Protocol Canonical + Witness Alternatives

```swift
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    static var parser: Parser { get }  // THE canonical parser
}

// Canonical conformance:
extension UInt32: Parseable {
    static var parser: Binary.LittleEndian.Parser<UInt32> { ... }  // canonical
}

// Additional witnesses as static properties (no protocol):
extension UInt32 {
    static var bigEndianParser: Binary.BigEndian.Parser<UInt32> { ... }
    static var asciiDecimalParser: ASCII.Decimal.Parser<Input, UInt32> { ... }
}
```

**Advantages**:
- Generic constrainability via `Parseable` protocol
- Canonical provides a sensible default: `T.parser` always works
- Alternatives are explicitly named: `T.bigEndianParser`, `T.asciiDecimalParser`
- Matches existing ecosystem pattern (`Binary.Serializable` + additional witnesses)
- Matches external prior art (single canonical + strategies/variants)
- Consumers who don't care about format get the canonical; experts pick alternatives

**Disadvantages**:
- Must choose ONE canonical — could be contentious for some types
- Two mechanisms to learn (protocol + witness properties)
- Alternative witnesses have no standardized naming convention
- No generic constrainability for alternatives (cannot write
  `func f<T: ASCIIParseable>()` without another protocol)

### Option D: Parameterized Canonical

```swift
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    associatedtype ParserConfiguration
    static func parser(for configuration: ParserConfiguration) -> Parser
}

extension UInt32: Parseable {
    typealias ParserConfiguration = Binary.Endianness
    static func parser(for endianness: Binary.Endianness) -> Binary.Coder<UInt32>.AsParser {
        .init(Binary.Coder.machine(endianness == .little ? u32le : u32be, encode: ...))
    }
}
```

**Advantages**:
- Multiple implementations via parameter, all through the protocol
- Generic constrainability preserved
- No separate witness mechanism needed

**Disadvantages**:
- `ParserConfiguration` type varies per conformer — generic code can't call
  `T.parser(for:)` without knowing the configuration type
- Awkward for types with truly different formats (binary vs ASCII vs JSON)
  — `ParserConfiguration` becomes an enum of unrelated things
- Complicates the common case (types with only one parser still need a configuration)
- No prior art for this pattern

### Comparison

| Criterion | A: Protocol-Only | B: Witness-Only | C: Canonical + Witness | D: Parameterized |
|-----------|:---:|:---:|:---:|:---:|
| Generic constrainability | Pass | **Fail** | Pass | Pass (limited) |
| Multiple implementations | **Fail** | Pass | Pass | Pass (same config type) |
| Simplicity | Pass | Pass | Moderate | **Fail** |
| Matches prior art | Pass | Fail | **Pass** | Fail |
| Matches ecosystem patterns | Moderate | Moderate | **Pass** | Fail |
| Naming clarity | Pass | Moderate | Pass | Pass |
| Discoverable canonical | Pass | **Fail** | Pass | Pass |
| No arbitrary canonical | **Fail** | Pass | Fail | Moderate |

## Outcome

**Status**: DECISION

### Empirical Validation

Experiment `canonical-witness-capability` (2026-03-04, Swift 6.2.4) validated all aspects
of Option C with 10/10 variants CONFIRMED:

| Variant | What It Tests | Result |
|---------|--------------|--------|
| V1 | Basic Parseable conformance | CONFIRMED |
| V2 | Generic function constrained on Parseable | CONFIRMED |
| V3 | Canonical + witness alternatives coexistence | CONFIRMED |
| V4 | Serializable conformance | CONFIRMED |
| V5 | Our Codable shadows stdlib Codable | CONFIRMED |
| V6 | Triple conformance (Parseable & Serializable & Codable) | CONFIRMED |
| V7 | Separate failure types (EncodeFailure = Never, no try needed) | CONFIRMED |
| V8 | Generic canonical + specific alternative side by side | CONFIRMED |
| V9 | Parameterized coder factory (.coder(endianness:)) | CONFIRMED |
| V10 | Swift.Codable still accessible via qualification | CONFIRMED |

See: `swift-institute/Experiments/canonical-witness-capability/`

### Decision: Option C (Protocol Canonical + Witness Alternatives)

Option C is the principled choice:

1. **Generic constrainability** — `Parseable`, `Serializable`, `Codable` protocols
   enable `func f<T: Parseable>()`. This is essential for generic infrastructure.

2. **Single canonical** — `T.parser`, `T.serializer`, `T.coder` always provide a
   sensible default. The canonical is the most common/natural representation.

3. **Witness alternatives** — Additional representations are static properties or
   factory methods. No protocol needed — they're discoverable through documentation
   and autocomplete.

4. **Matches existing patterns** — `Binary.Serializable` (canonical) + `.serializing`
   (witness bridge) + `.coder(endianness:)` (parameterized alternatives) already
   demonstrate this hybrid.

5. **Matches all external prior art** — Single canonical with alternative strategies
   is the universal pattern across Swift Codable, Rust serde, Haskell aeson/binary.

### Protocol Design (Confirmed)

```swift
// In swift-parser-primitives:
protocol Parseable {
    associatedtype Parser: Parser.Protocol
    static var parser: Parser { get }
}

// In swift-serializer-primitives:
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

### Canonical Selection Guidance

When a type conforms to `Parseable`/`Serializable`/`Codable`, the canonical SHOULD be:

| Criterion | Canonical Choice |
|-----------|-----------------|
| Type has one natural representation | That representation |
| Type has platform-dependent representation | Platform-native (e.g., little-endian on x86) |
| Type has multiple format representations | The most common/wire format |
| Type is specification-defined | The specification's canonical encoding |

### Alternative Witness Convention

Three patterns for alternatives, in order of preference:

#### Pattern 1: Parameterized Factory (Same Dimension)

When alternatives vary along a single axis, expose a factory method on the subject type:

```swift
extension UInt32: Codable {
    // Canonical: platform-native endianness
    static var coder: Binary.Coder<UInt32> {
        .coder(endianness: .native)
    }
}

extension UInt32 {
    // Same-dimension alternatives via factory:
    static func coder(endianness: Binary.Endianness) -> Binary.Coder<UInt32> {
        .coder(endianness: endianness)
    }
}
```

#### Pattern 2: Domain-Owned Types (Cross-Format)

When the alternative is a different format entirely, it is a standalone domain-owned
type — not a property on the subject:

```swift
// Binary parsing is canonical:
extension UInt32: Parseable {
    static var parser: Binary.LittleEndian.Parser<UInt32> { ... }
}

// ASCII parsing is a domain-owned type, not a UInt32 property:
ASCII.Decimal.Parser<Input, UInt32>   // standalone type, used directly
```

#### Pattern 3: Descriptive Static Property (Exception)

When a simple named property is most ergonomic and no domain type exists:

```swift
extension UInt32 {
    static var bigEndianCoder: Binary.Coder<UInt32> {
        .coder(endianness: .big)
    }
}
```

This is the exception, not the rule. Prefer Pattern 1 (parameterized) or Pattern 2
(domain-owned) when possible.

### Resolved Questions

| # | Question | Resolution | Rationale |
|---|----------|-----------|-----------|
| 1 | **Naming convention for alternative witnesses** | Two patterns: parameterized factory + domain-owned types | Same-dimension variants use parameterized factory (`.coder(endianness: .big)` — existing `Binary.Coder` pattern). Cross-format alternatives are domain-owned types (`ASCII.Decimal.Parser<Input, UInt32>`) — not properties on the subject type. Flat alternative properties on the subject (e.g., `UInt32.bigEndianParser`) are the exception, not the rule. |
| 2 | **Should alternatives be discoverable via a protocol?** | No — over-engineering | Canonical is discoverable via `Parseable`/`Serializable`/`Codable`. Alternatives are either parameterized factories on the canonical (same dimension) or standalone domain-owned types (different format). Neither needs a protocol. |
| 3 | **Interaction with `Dependency.Key`** | Orthogonal — not injectable | Canonical protocol conformance (`T.coder`) is a compile-time constant, not injectable. A concrete Coder type (e.g., `JSON.Coder`) may independently conform to both `Coder.Protocol` AND `Dependency.Key` for runtime live/test selection — but that's the concrete type's concern, not the canonical attachment's. |

## Changelog

- **v1.2.0** (2026-03-04): Resolved all 3 open questions. Q1: two patterns —
  parameterized factory for same-dimension, domain-owned types for cross-format.
  Q2: no protocols for alternatives (over-engineering). Q3: Dependency.Key is
  orthogonal — canonical is compile-time, not injectable. Promoted Alternative
  Witness Convention to three-pattern hierarchy. Status RECOMMENDATION → DECISION.
- **v1.1.0** (2026-03-04): Added empirical validation section (10/10 CONFIRMED).
  Promoted status from IN_PROGRESS to RECOMMENDATION.
- **v1.0.0** (2026-03-04): Initial analysis. Four options: protocol-only, witness-only,
  canonical + witness hybrid, parameterized canonical. Ecosystem survey: 6 internal
  patterns, 5 external ecosystems. Recommends Option C (protocol canonical + witness
  alternatives). Confirmed Parseable/Serializable/Codable protocol design from
  transformation-domain-architecture v3.1.0. Added canonical selection guidance and
  alternative witness convention.

## References

- transformation-domain-architecture: [transformation-domain-architecture.md](transformation-domain-architecture.md) (v3.1.0)
- parsing-serialization-capability-organization: [parsing-serialization-capability-organization.md](parsing-serialization-capability-organization.md) (v1.1.0)
- Binary.Coder: `https://github.com/swift-primitives/swift-binary-parser-primitives/blob/main/Sources/Binary Coder Primitives/Binary.Coder.swift`
- Binary.Serializable: `https://github.com/swift-primitives/swift-binary-primitives/blob/main/Sources/Binary Serializable Primitives/Binary.Serializable.swift`
- Binary.Serializable witness bridge: `https://github.com/swift-primitives/swift-binary-primitives/blob/main/Sources/Binary Serializable Primitives/Binary.Serializable+Witness.swift`
- Witness.Protocol: `https://github.com/swift-primitives/swift-witness-primitives/blob/main/Sources/Witness Primitives/Witness.Protocol.swift`
- Dependency.Key: `https://github.com/swift-primitives/swift-dependency-primitives/blob/main/Sources/Dependency Primitives/Dependency.Key.swift`
- IPv4.Address dual conformance: `https://github.com/swift-standards/swift-rfc-791/blob/main/Sources/RFC 791/RFC_791.IPv4.Address.swift`
- UInt32 parameterized coder: `https://github.com/swift-primitives/swift-binary-parser-primitives/blob/main/Sources/Binary Integer Primitives/UInt32+Parser.swift`
- Experiment: `swift-institute/Experiments/canonical-witness-capability/` (10/10 CONFIRMED)
- [API-NAME-001] Namespace Structure
- [RES-001] Investigation Triggers
- [RES-021] Prior Art Survey
