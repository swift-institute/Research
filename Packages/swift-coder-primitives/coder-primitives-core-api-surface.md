# Coder Primitives Core — Complete API Surface

<!--
---
version: 1.1.0
last_updated: 2026-03-05
status: RECOMMENDATION
tier: 2
---
-->

## Context

The transformation domain architecture ([v3.2.0, DECISION]) establishes three
top-level namespace packages:

| Package | Protocol | Attachment | Direction |
|---------|----------|------------|-----------|
| swift-parser-primitives | `Parser.Protocol` | `Parseable` | Input → Value |
| swift-serializer-primitives | `Serializer.Protocol` | `Serializable` | Value → Buffer |
| swift-coder-primitives | `Coder.Protocol` | `Codable` | Bidirectional |

Key design decisions already made (DECISION status):

- **No Body/Builder** — Coders are leaf types, one per format × value pair
- **Independent** — Does not refine Parser.Protocol or Serializer.Protocol
- **Separate failure types** — `DecodeFailure` and `EncodeFailure` are independent
- **`~Copyable & ~Escapable` input** — `DecodeInput` supports borrowed spans
- **Shadows `Swift.Codable`** — intentional, different semantics

Current state: 3 source files (namespace, protocol, attachment). The question is
whether the core module is complete.

### Trigger

[RES-012] Discovery — proactive verification that the core API surface is minimal,
complete, and correct before downstream adoption begins.

## Question

What constitutes the minimal, complete, and correct API surface for the
`Coder Primitives` core module, following all Swift Institute conventions?

---

## Analysis

### A. Current State Inventory

**`Coder.swift`** — Namespace enum.

```swift
public enum Coder {}
```

**`Coder.Protocol.swift`** — Bidirectional protocol with 5 associated types.

```swift
extension Coder {
    public protocol `Protocol`<DecodeInput, EncodeBuffer, Output> {
        associatedtype DecodeInput: ~Copyable & ~Escapable
        associatedtype EncodeBuffer
        associatedtype Output
        associatedtype DecodeFailure: Swift.Error
        associatedtype EncodeFailure: Swift.Error

        func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> Output
        func encode(_ output: Output, into buffer: inout EncodeBuffer) throws(EncodeFailure)
    }
}
```

**`Codable.swift`** — Canonical attachment protocol.

```swift
public protocol Codable {
    associatedtype Coder: Coder_Primitives.Coder.`Protocol`
    static var coder: Coder { get }
}
```

**Total**: 3 files, 0 convenience extensions, 0 dependencies.

---

### B. Sibling Core Comparison

What do Parser Primitives Core and Serializer Primitives Core provide beyond
their base protocols?

| Element | Parser Core | Serializer Core | Coder Core |
|---------|-------------|-----------------|------------|
| Namespace enum | `Parser` | `Serializer` | `Coder` ✓ |
| Protocol | `Parser.Protocol` | `Serializer.Protocol` | `Coder.Protocol` ✓ |
| Body + Builder | ✓ | ✓ | ✗ (by design) |
| Attachment protocol | `Parseable` | `Serializable` | `Codable` ✓ |
| Buffer-constructing convenience | — | `serialize(_:) → Buffer` | **missing** |
| Attachment convenience (instance) | `init(ascii:)` | `.asciiBytes` | **missing** |
| Attachment convenience (into) | — | — | **missing** |
| `exports.swift` | ✓ (re-exports deps) | ✓ | ✗ (no deps) |

The gaps are in **convenience extensions** — forwarding methods that compose the
protocol's inout-based API into ergonomic call-site patterns.

---

### C. Theoretical Foundation — Relationship to `Optic.Prism`

`Coder.Protocol` is the **effectful streaming analog** of `Optic.Prism`
from `swift-optic-primitives`. The structural correspondence:

| `Optic.Prism<Whole, Part>` | `Coder.Protocol` | Correspondence |
|----------------------------|-------------------|----------------|
| `embed: (Part) → Whole` | `encode(_:into:)` | Total injection |
| `extract: (Whole) → Part?` | `decode(_:)` | Partial extraction |
| Pure values | `inout` streaming I/O | Computational context |
| Failure via `Optional` | Failure via typed throws | Error channel |

The key difference is the **computational context**: `Optic.Prism` operates on
pure values (`embed`/`extract`), while `Coder.Protocol` operates on streaming
resources (`inout DecodeInput` / `inout EncodeBuffer`). They share the same
algebraic laws but different interfaces:

**Prism laws** (pure):
- `extract(embed(part)) == part`
- `embed(extract(whole)) == whole` when extract succeeds

**Coder laws** (effectful):
- `decode(encode(value)) ≡ value` (round-trip decode)
- `encode(decode(input)) ≡ input` (round-trip encode, when decode succeeds)

When both failures are `Never`, the Coder is an effectful `Optic.Iso` — total in
both directions.

The buffer-constructing encode convenience relies on the **monoid structure** of
`RangeReplaceableCollection`: identity element (`init()`) and associative combine
(`append`). This justifies the constraint.

**Bridging**: A future integration module (`Coder Optic Primitives`) could bridge
`Optic.Prism` ↔ `Coder.Protocol` for pure-context coders where `DecodeInput` and
`EncodeBuffer` share a representation. This is outside core scope.

**Conclusion**: The protocol design is theoretically sound — it is the correct
effectful lifting of `Optic.Prism` to streaming I/O. No structural changes needed.

---

### D. Gap Analysis

#### D.1 Buffer-Constructing Encode Convenience

**Serializer has this**:
```swift
extension Serializer.Protocol where Buffer: RangeReplaceableCollection {
    public func serialize(_ output: Output) throws(Failure) -> Buffer
}
```

**Coder lacks the parallel**. Users must write:
```swift
var buffer = [UInt8]()
try coder.encode(value, into: &buffer)
```

Instead of:
```swift
let buffer = try coder.encode(value)
```

**Verdict**: **Add**. Universal ergonomic improvement. Single constraint
(`EncodeBuffer: RangeReplaceableCollection`). No separate infallible overload
needed — `throws(Never)` is non-throwing at call sites.

#### D.2 Codable Instance-Level Encode

Users should be able to write `value.encode(into: &buffer)` and `value.encoded()`
instead of routing through the static coder accessor.

**Three methods**:

| Method | Constraint | Purpose |
|--------|-----------|---------|
| `encode(into:)` | `Output == Self` | Append to existing buffer |
| `encoded()` | `Output == Self`, `EncodeBuffer: RangeReplaceableCollection` | Buffer-constructing |
| `init(decoding:)` | `Output == Self` | Constructor from input |

**Naming analysis** per Swift API Guidelines:

- `encode(into:)` — imperative verb, mutates buffer parameter ✓
- `encoded()` — past participle, returns new value ✓ [IMPL-EXPR-001]
- `init(decoding:)` — gerund label describing construction action ✓ (parallel to
  `Parseable.init(ascii:)`)

**Verdict**: **Add all three**.

---

### E. Candidate Additions — Rejected

#### E.1 Decode/Encode Sub-Protocols

Split `Coder.Protocol` into `Coder.Decode` + `Coder.Encode`, with
`Coder.Protocol` refining both.

**Rejection**: Creates redundancy with `Parser.Protocol` and `Serializer.Protocol`.
The transformation-domain-architecture research (v3.2.0) explicitly chose
independence — Coder is the bidirectional conjunction, not a composition of
two halves. Types needing one direction use Parser or Serializer directly.

#### E.2 Error Namespace

`Coder.Error` with error composition types.

**Placed in satellite**: Parser places `Parser.Error.Either` in `Parser Error
Primitives`. `Coder.Error.Either<L, R>` belongs in `Coder Error Primitives`.
This is a Tier 1 satellite — required by Map (throwing), Filter, OneOf, and
FlatMap for error composition. Domain-specific error types (binary format
errors, etc.) come from concrete coder implementations, not from this module.
See Satellite Modules section.

#### E.3 Map Combinator

`Coder.Map<Base, NewOutput>` for bijective output transformation.

**Placed in satellite**: Correct type, wrong location for core. Parser places
`Parser.Map` in `Parser Map Primitives` (separate module per [MOD-*]).
`Coder.Map` belongs in `Coder Map Primitives`. This is the most important
satellite module — it is how users derive new coders from existing ones without
hand-rolling a new struct. See Satellite Modules section for full design.

#### E.4 Format Protocol

`Coder.Format` — a type that produces coders for any Codable value (like
`JSONDecoder`/`JSONEncoder`).

**Rejection**: Higher-layer abstraction. Primitives provide leaf coders per
format × value pair. Format-level discovery belongs in Foundations (Layer 3).

#### E.5 Sendable Marker Protocol

`Coder.Sendable` refining both `Coder.Protocol` and `Swift.Sendable`.

**Rejection**: Unnecessary — conformers add `Sendable` directly. A marker
protocol adds no behavior.

#### E.6 `exports.swift`

Re-export file for dependencies.

**Rejection**: Core has zero dependencies. Creating a placeholder violates
[IMPL-INTENT] — don't write code for hypothetical futures.

---

### F. Convention Compliance

| Convention | Status | Notes |
|------------|--------|-------|
| [API-NAME-001] Nest.Name | ✓ | `Coder.Protocol` |
| [API-NAME-002] No compounds | ✓ | `encode(into:)` not `encodeInto()` |
| [API-ERR-001] Typed throws | ✓ | `throws(DecodeFailure)`, `throws(EncodeFailure)` |
| [API-IMPL-005] One type per file | ✓ | Extensions in parent type's file |
| [PRIM-FOUND-001] No Foundation | ✓ | Zero imports |
| [IMPL-INTENT] Intent over mechanism | ✓ | Call sites read as intent |
| [IMPL-EXPR-001] Single expressions | ✓ | All conveniences except buffer-constructing |
| [IMPL-000] Call-site-first | ✓ | `value.encoded()`, `value.encode(into:)` |
| [PATTERN-010] No Foundation types | ✓ | No `Data`, `Date`, etc. |

---

## Outcome

**Status**: RECOMMENDATION

The core is **structurally complete** — no protocols, types, or dependencies are
missing. The gap is **convenience extensions only**: three methods on `Codable`
and one on `Coder.Protocol`.

### Complete Source — `Coder.swift` (unchanged)

```swift
//
//  Coder.swift
//  swift-coder-primitives
//
//  Namespace for bidirectional coding primitives.
//

/// Namespace for bidirectional coding primitives.
public enum Coder {}
```

### Complete Source — `Coder.Protocol.swift`

```swift
//
//  Coder.Protocol.swift
//  swift-coder-primitives
//
//  Core Coder protocol definition.
//

extension Coder {
    /// A type that can both decode and encode a value.
    ///
    /// Coders are bidirectional transformations — they decode from an input
    /// and encode into a buffer. The key insight is that decode and encode
    /// use **different types**: decode uses a cursor (read-only, with
    /// checkpoint/restore), encode appends to a mutable buffer.
    ///
    /// ## Separate Failure Types
    ///
    /// Decode may fail (malformed input); encode may be infallible
    /// (well-typed value always serializes). `DecodeFailure` and
    /// `EncodeFailure` are independent — use `Never` for infallible
    /// directions.
    ///
    /// ## No Body/Builder
    ///
    /// Unlike `Parser.Protocol` and `Serializer.Protocol`, `Coder.Protocol`
    /// does not include declarative composition via `Body`/`Builder`.
    /// Coders are typically leaf types — one per format x value pair.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct UInt32Coder: Coder.`Protocol` {
    ///     typealias DecodeInput = Binary.Bytes.Input
    ///     typealias EncodeBuffer = [UInt8]
    ///     typealias Output = UInt32
    ///     typealias DecodeFailure = Binary.Bytes.Machine.Fault
    ///     typealias EncodeFailure = Never
    ///
    ///     func decode(_ input: inout Binary.Bytes.Input)
    ///         throws(Binary.Bytes.Machine.Fault) -> UInt32 { ... }
    ///
    ///     func encode(_ output: UInt32, into buffer: inout [UInt8]) { ... }
    /// }
    /// ```
    public protocol `Protocol`<DecodeInput, EncodeBuffer, Output> {
        /// The input type for decoding (typically a cursor or byte span).
        associatedtype DecodeInput: ~Copyable & ~Escapable

        /// The buffer type for encoding (typically a mutable byte array).
        associatedtype EncodeBuffer

        /// The value type that is decoded/encoded.
        associatedtype Output

        /// The error type for decode failures.
        ///
        /// Use `Never` for infallible decoders.
        associatedtype DecodeFailure: Swift.Error

        /// The error type for encode failures.
        ///
        /// Use `Never` for infallible encoders.
        associatedtype EncodeFailure: Swift.Error

        /// Decodes a value from the input.
        ///
        /// On success, consumes the decoded portion from input and returns
        /// the result. On failure, throws an error.
        ///
        /// - Parameter input: The input to decode from. Modified to reflect consumption.
        /// - Returns: The decoded value.
        /// - Throws: `DecodeFailure` if decoding fails.
        func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> Output

        /// Encodes a value by appending to the buffer.
        ///
        /// On success, appends the encoded representation to buffer.
        /// On failure, throws an error.
        ///
        /// - Parameters:
        ///   - output: The value to encode.
        ///   - buffer: The buffer to append to.
        /// - Throws: `EncodeFailure` if encoding fails.
        func encode(_ output: Output, into buffer: inout EncodeBuffer) throws(EncodeFailure)
    }
}

// MARK: - Buffer-constructing encode convenience

extension Coder.`Protocol` where EncodeBuffer: RangeReplaceableCollection {

    /// Encodes a value, returning a new buffer.
    ///
    /// Creates an empty buffer, encodes the value into it, and returns
    /// the result. For appending to an existing buffer, use
    /// ``encode(_:into:)`` directly.
    ///
    /// - Parameter output: The value to encode.
    /// - Returns: A new buffer containing the encoded representation.
    /// - Throws: `EncodeFailure` if encoding fails.
    @inlinable
    public func encode(_ output: Output) throws(EncodeFailure) -> EncodeBuffer {
        var buffer = EncodeBuffer()
        try encode(output, into: &buffer)
        return buffer
    }
}
```

### Complete Source — `Codable.swift`

```swift
//
//  Codable.swift
//  swift-coder-primitives
//
//  Canonical attachment protocol for bidirectional coding.
//

/// A type that has a canonical coder.
///
/// Conforming types declare their canonical ``Coder`` and provide a static
/// accessor to obtain it. This enables generic algorithms to discover the
/// coder for any `Codable` type.
///
/// This protocol shadows `Swift.Codable`. Types that need Swift's built-in
/// `Codable` should use `Swift.Codable` explicitly.
///
/// `Codable` is independent of `Parseable` and `Serializable` — a Coder
/// handles both directions internally. Forcing decomposition into separate
/// Parser + Serializer is artificial for bidirectional types.
///
/// ```swift
/// extension UInt32: Codable {
///     static var coder: Binary.UInt32Coder { .init() }
/// }
/// ```
public protocol Codable {
    /// The canonical coder type for this value.
    associatedtype Coder: Coder_Primitives.Coder.`Protocol`

    /// The canonical coder instance.
    static var coder: Coder { get }
}

// MARK: - Instance-level encode

extension Codable where Coder.Output == Self {

    /// Encodes this value by appending to a buffer.
    ///
    /// - Parameter buffer: The buffer to append to.
    /// - Throws: `Coder.EncodeFailure` if encoding fails.
    @inlinable
    public func encode(into buffer: inout Coder.EncodeBuffer) throws(Coder.EncodeFailure) {
        try Self.coder.encode(self, into: &buffer)
    }

    /// Decodes a value from the input using the canonical coder.
    ///
    /// - Parameter input: The input to decode from. Modified to reflect consumption.
    /// - Throws: `Coder.DecodeFailure` if decoding fails.
    @inlinable
    public init(decoding input: inout Coder.DecodeInput) throws(Coder.DecodeFailure) {
        self = try Self.coder.decode(&input)
    }
}

// MARK: - Buffer-constructing encode

extension Codable where Coder.Output == Self, Coder.EncodeBuffer: RangeReplaceableCollection {

    /// Encodes this value, returning a new buffer.
    ///
    /// - Returns: A new buffer containing the encoded representation.
    /// - Throws: `Coder.EncodeFailure` if encoding fails.
    @inlinable
    public func encoded() throws(Coder.EncodeFailure) -> Coder.EncodeBuffer {
        try Self.coder.encode(self)
    }
}
```

---

### File Inventory — Complete Core

| File | Contents | Status |
|------|----------|--------|
| `Coder.swift` | Namespace enum | Unchanged |
| `Coder.Protocol.swift` | Protocol + buffer-constructing convenience | **+1 extension** |
| `Codable.swift` | Attachment + 3 convenience methods | **+3 methods** |

**Total additions**: 4 methods across 2 files. Zero new files. Zero new types.
Zero new dependencies.

### Satellite Modules — Complete Surface

Coder has no Body/Builder (leaf types), but that does not mean no combinators.
Combinators produce new coders from existing coders — they are how users derive
`MyIDCoder` from `UInt32Coder` without hand-rolling a new struct. A primitives
library serving millions of users must provide these transformations.

The satellite surface follows the same modular pattern as `swift-parser-primitives`
(36 modules). Each combinator is its own SwiftPM target per [MOD-*].

#### Tier 1: Foundation (required by other satellites)

| Module | Type | Purpose |
|--------|------|---------|
| `Coder Error Primitives` | `Coder.Error.Either<L, R>` | Error composition for combinators that introduce a second failure domain. Parser-primitives has `Parser.Error.Either` for the same purpose. Required by Map (throwing), Filter, OneOf, FlatMap. |

#### Tier 2: Output Transformation

| Module | Type | Extension | Purpose |
|--------|------|-----------|---------|
| `Coder Map Primitives` | `Coder.Map<Base, NewOutput>` | `.map(forward:backward:)` | Bijective output transform (isomorphism). **The #1 combinator.** `uint32Coder.map(forward: MyID.init, backward: \.rawValue)`. This IS the optic Iso bridge — same type, not two separate types. A convenience init taking `Optic.Iso` lives in the optic integration module. |
| `Coder Map Primitives` | `Coder.Map.Throwing<Base, NewOutput, E>` | `.tryMap(forward:backward:)` | Fallible output transform (prism shape). Decode can fail additionally; encode may fail additionally. Error composition via `Either<Base.DecodeFailure, E>`. |
| `Coder Filter Primitives` | `Coder.Filter<Base>` | `.filter(_:)` | Validate decoded output. Decode: parse then validate, throw on failure. Encode: validate then encode. Error via `Either<Base.DecodeFailure, Constraint.Error>`. |

#### Tier 3: Structural Composition

| Module | Type | Purpose |
|--------|------|---------|
| `Coder Optional Primitives` | `Coder.Optional<Base>` | Optional value coding. Decode: try base, return `nil` on failure (swallow error). Encode: encode if `.some`, no-op if `.none`. Output: `Base.Output?`. Extension: `.optional()`. |
| `Coder OneOf Primitives` | `Coder.OneOf.Two<C0, C1>` | Alternative/choice. Decode: try first coder, fall back to second. Encode: requires discriminator — the Output must indicate which branch to encode through. Natural fit for enum types. Error: `Either<C0.DecodeFailure, C1.DecodeFailure>` when both fail. **Needs design research**: the encode-direction discriminator is the key challenge. Parser.OneOf only decodes; Coder.OneOf must be bidirectional. |
| `Coder Conditional Primitives` | `Coder.Conditional<First, Second>` | Conditional branching. Output: enum `.first(First.Output)` / `.second(Second.Output)`. Bidirectional: encode dispatches on case. Simpler than OneOf because the branch is explicit in the output type. |

#### Tier 4: Repetition & Sequencing

| Module | Type | Purpose |
|--------|------|---------|
| `Coder Many Primitives` | `Coder.Many<Base>` | Repeat coder for collections. Decode: repeat base coder, collecting into array. Encode: iterate array, encode each. Count handling: fixed count, range, delimiter-terminated. **Needs design research**: termination strategy (count-prefixed vs. delimiter vs. exhaustive). |
| `Coder FlatMap Primitives` | `Coder.FlatMap<Base, Derived>` | Dependent coding. Decode: parse discriminator with base, choose derived coder based on result. Encode: extract discriminator from value, encode with base. Common in TLV (type-length-value) binary formats. **Needs design research**: the encode direction requires `(Derived.Output) -> Base.Output` inverse discriminator. |

#### Tier 5: Terminals

| Module | Type | Purpose |
|--------|------|---------|
| `Coder Always Primitives` | `Coder.Always<Input, Buffer, Output>` | Constant-value coder. Decode: return constant, consume nothing. Encode: no-op. Failure: `Never`. |
| `Coder Fail Primitives` | `Coder.Fail<Input, Buffer, Output, E>` | Unconditional failure. Always throws. Used in conditional composition branches. |

#### Tier 6: Utilities

| Module | Type | Purpose |
|--------|------|---------|
| `Coder Lazy Primitives` | `Coder.Lazy<Base>` | Deferred construction for recursive formats. Coder rebuilt on each call. |
| `Coder Trace Primitives` | `Coder.Trace<Base>` | Debug tracing. Logs decode/encode entry, success, failure. Extension: `.trace("label")`. |

#### Tier 7: Integration

| Module | Type | Purpose |
|--------|------|---------|
| `Coder Optic Primitives` | Extensions on `Coder.Map` | Convenience inits that accept `Optic.Iso` and (unified) `Optic.Prism`. Not a separate type — extends `Coder.Map` and `Coder.Map.Throwing` with optic-accepting constructors. Depends on `swift-optic-primitives`. |
| `Coder Conformance Primitives` | `Coder.RawRepresentable<Base>` | Adapter for `RawRepresentable` types. Structurally a `Coder.Map` specialized to `RawRepresentable` constraints. Could be a convenience extension on `Coder.Map` instead of a separate type. |

#### Not Applicable (Parser-only)

These parser-primitives modules have no meaningful bidirectional analog:

| Parser Module | Why N/A for Coder |
|---------------|-------------------|
| Take (sequential composition) | No Builder DSL — sequential composition is explicit struct composition |
| Skip | Void-output elision for Builder — no Builder in Coder |
| Consume / Discard | Raw input consumption — parsers read bytes, coders transform values |
| Prefix (While/UpTo/Through) | Predicate-based input scanning — parser-specific |
| First (Element/Where) | Single-element extraction — parser-specific |
| Peek / Not (lookahead) | Non-consuming lookahead — parser-specific |
| Span / Locate / Tracked | Position tracking — parser-specific |
| Backtrack | Multi-shot continuation exploration — parser-specific |
| Byte / Literal | Concrete byte matchers — parser-specific |
| Parse (compiled/prepared) | Execution variants — parser-specific |

#### Summary

| Tier | Modules | Status |
|------|---------|--------|
| 1: Foundation | 1 (Error) | Ready to implement |
| 2: Output Transform | 2 (Map, Filter) | Ready to implement |
| 3: Structural | 3 (Optional, OneOf, Conditional) | OneOf needs design research |
| 4: Repetition | 2 (Many, FlatMap) | Both need design research |
| 5: Terminals | 2 (Always, Fail) | Ready to implement |
| 6: Utilities | 2 (Lazy, Trace) | Ready to implement |
| 7: Integration | 2 (Optic, Conformance) | Blocked on unified Prism migration |
| **Total** | **14 modules** | **9 ready, 3 need design, 2 blocked** |

**Implementation order**: Error → Map → Optional → Filter → Always → Fail →
Lazy → Trace → Conditional → Optic → Conformance → OneOf → Many → FlatMap.

The first 8 modules are straightforward and can proceed immediately. OneOf,
Many, and FlatMap require design research for their bidirectional semantics
(the encode direction introduces discriminator and termination challenges that
parsers don't face).

---

## References

- `swift-institute/Research/transformation-domain-architecture.md` (v3.2.0, DECISION)
- `swift-institute/Research/canonical-witness-capability-attachment.md` (v1.2.0, DECISION)
- `swift-institute/Research/parsing-serialization-capability-organization.md` (v1.3.0, RECOMMENDATION)
- `swift-primitives/swift-optic-primitives/` — `Optic.Prism`, `Optic.Iso` (pure optics)
- `swift-primitives/swift-optic-primitives/Research/optics-streaming-io-bridge.md` (v1.1.0, RECOMMENDATION)
- `swift-primitives/swift-optic-primitives/Experiments/unified-throwing-prism/` (CONFIRMED)
- `swift-primitives/swift-parser-primitives/` — 36 modules, full combinator surface (reference)
- `swift-primitives/swift-serializer-primitives/` — 3 modules, witness-based (reference)
- Swift API Design Guidelines — Naming conventions for mutating/nonmutating methods
