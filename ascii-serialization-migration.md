# ASCII Serialization Migration

> **DEFERRED POST-RELEASE** (2026-04-08) — this full 8-phase `Parseable`/`Serializable`
> witness migration is explicitly DEFERRED while the Category B release-readiness work
> executes Strategy (c) (protocol relocation only). See
> [`../../swift-primitives/swift-ascii-primitives/Research/ascii-migration-category-b.md`](../../swift-primitives/swift-ascii-primitives/Research/ascii-migration-category-b.md)
> for the release-scoped plan. This document remains the canonical plan for the full
> witness migration and is NOT superseded for that purpose.

<!--
---
version: 2.0.0
last_updated: 2026-03-25
status: DEFERRED (post-release)
tier: 2
---
-->

## Context

`Binary.ASCII.Serializable` is a deprecated domain protocol in swift-ascii (L3) with
77 conformers across 15 IETF/WHATWG packages plus swift-ascii itself. The deprecation
message directs users to witness properties, but no concrete migration plan existed.

The transformation domain architecture (v3.2.0 DECISION) and canonical-witness
capability attachment (v1.2.0 DECISION) now provide the target architecture:

- `Parser.Protocol` / `Serializer.Protocol` / `Coder.Protocol` — capability protocols
- `Parseable` / `Serializable` / `Codable` — canonical attachment protocols
- Witness properties for alternatives

This document resolves the migration: what replaces `Binary.ASCII.Serializable`,
how each conformer migrates, and in what order.

### Trigger

[RES-001] Architecture choice — deferred open item from
[parsing-serialization-capability-organization.md](parsing-serialization-capability-organization.md)
v1.2.0: "Binary.ASCII.Serializable migration."

### Constraints

- [MOD-DOMAIN] One domain per package
- [PRIM-FOUND-001] No Foundation
- [API-NAME-001] `Nest.Name` pattern
- transformation-domain-architecture v3.2.0 (DECISION) — three independent packages
- canonical-witness-capability-attachment v1.2.0 (DECISION) — protocol canonical + witness alternatives
- parsers-adoption-implementation-plan — 8-phase parser rollout already planned
- All 77 conformers must migrate — no partial deprecation

### Stakeholders

IETF packages (`swift-ietf/swift-rfc-*`) and WHATWG packages (`swift-whatwg/`) with
`Binary.ASCII.Serializable` conformances. swift-ascii (L3) as the protocol owner.

## Question

**How should ~83 `Binary.ASCII.Serializable` conformers migrate to the
Parseable/Serializable/Codable architecture?**

Sub-questions:
1. Does a replacement domain protocol exist, or do types independently adopt
   Parseable + Serializable?
2. How do the ~12 convenience features (String conversion, literals, etc.) migrate?
3. What is the phasing relative to the parser adoption plan?
4. What happens to `Binary.ASCII.Wrapper`, `Binary.ASCII.RawRepresentable`?

## Analysis

### What Binary.ASCII.Serializable Provides

The protocol is a **bidirectional domain protocol** (Strategy C from
parsing-serialization-capability-organization.md) with 12 features:

| # | Feature | Mechanism |
|---|---------|-----------|
| F1 | Serialize value to bytes | `static func serialize(ascii:into:)` |
| F2 | Parse value from bytes | `init(ascii:in:)` throws(Error) |
| F3 | Context-dependent parsing | `associatedtype Context: Sendable` |
| F4 | Typed throws | `associatedtype Error: Swift.Error` |
| F5 | String → value | `init(_: StringProtocol)` (extension, Context == Void) |
| F6 | Value → String | `StringProtocol.init(ascii:)` (extension) |
| F7 | CustomStringConvertible | Three variants (extension) |
| F8 | ExpressibleByStringLiteral | Force-try parsing (extension) |
| F9 | ExpressibleByIntegerLiteral | For numeric types (extension) |
| F10 | `[UInt8]` initializer | `[UInt8](ascii:)` (extension) |
| F11 | Buffer append | `buffer.append(ascii:)` (extension) |
| F12 | Binary.Serializable bridge | Inherits `Binary.Serializable`, delegates serialize |

Additionally:
- `Binary.ASCII.Wrapper<T>` — instance accessor `.ascii.serialize(into:)`, `.ascii.withSerializedBytes { }`
- `Binary.ASCII.RawRepresentable` — synthesized `RawRepresentable` for `String` / `[UInt8]` raw values

### Generic Constraint Audit

Generic constraints on `Binary.ASCII.Serializable` are **entirely self-contained**
in swift-ascii:

| Site | File | Type |
|------|------|------|
| `Wrapper<Wrapped: Binary.ASCII.Serializable>` | Binary.ASCII.Wrapper.swift | Struct constraint |
| `init<T: Binary.ASCII.Serializable>(_ value: T)` | StringProtocol+INCITS_4_1986.swift | Initializer |
| `init<S: Binary.ASCII.Serializable>(ascii:)` | Binary.ASCII.Serializable.swift | Extension |
| `init<T: Binary.ASCII.Serializable>(ascii:)` | Binary.ASCII.Serializable.swift | Extension |
| `append<S: Binary.ASCII.Serializable>(ascii:)` | Binary.ASCII.Serializable.swift | Extension |

**Zero external generic constraints.** No standards or primitives code constrains on
`Binary.ASCII.Serializable`. All 81 standards files are pure conformances.

### Target Architecture

Each conformer gets **separate Parser + Serializer types** (not a single Coder):

```swift
// Before (deprecated):
extension RFC_3986.URI: Binary.ASCII.Serializable {
    static func serialize<Buffer>(ascii uri: Self, into buffer: inout Buffer) { ... }
    init<Bytes>(ascii bytes: Bytes, in context: Void) throws(Error) { ... }
}

// After:
extension RFC_3986.URI {
    struct Parser<Input: Collection.Slice.Protocol>: Parser.Protocol
    where Input.Element == UInt8 { ... }

    struct Serializer: Serializer.Protocol {
        typealias Output = RFC_3986.URI
        typealias Buffer = [UInt8]
        typealias Failure = Never
        func serialize(_ uri: RFC_3986.URI, into buffer: inout [UInt8]) { ... }
    }
}

extension RFC_3986.URI: Parseable {
    static var parser: RFC_3986.URI.Parser<Parser.ByteInput> { .init() }
}

extension RFC_3986.URI: Serializable {
    static var serializer: RFC_3986.URI.Serializer { .init() }
}
```

**Why separate Parser + Serializer, not Coder**:

1. Parsing and serialization are **genuinely asymmetric** for text formats — parsing
   has complex grammars (lookahead, alternatives, error recovery); serialization is
   simple concatenation
2. Many standards types **already have** or are planned to have `Parser.Protocol`
   conformers (per parsers-adoption-implementation-plan — 95 opportunities)
3. `Coder.Protocol` has separate `DecodeInput` / `EncodeBuffer` types, which is right
   for binary coders but over-engineered for ASCII text where both sides use `[UInt8]`
4. Separate types allow independent evolution — a parser can gain builder composition
   without affecting the serializer

### Option A: No Replacement Domain Protocol

Each type independently conforms to `Parseable` + `Serializable`. Convenience
extensions (String conversion, literals) are per-type or on constrained protocol
extensions.

**Advantages**:
- No new abstractions — uses only the decided architecture
- Each type explicitly declares what it provides
- No "one protocol gives you everything" coupling
- Aligns with prior art: Swift Codable has no `JSONCodable` domain protocol

**Disadvantages**:
- Convenience boilerplate per type (CustomStringConvertible, literal conformances)
- No way to express "this type round-trips through ASCII" as a single constraint

### Option B: Lightweight Domain Protocol

```swift
// In swift-ascii:
protocol ASCII.Textual: Parseable, Serializable
where Parser.Input == Parser.ByteInput, Serializer.Buffer == [UInt8] {}

extension ASCII.Textual {
    // All convenience defaults:
    var description: String { ... }
    init(_ string: some StringProtocol) throws { ... }
}
```

**Advantages**:
- Single conformance gives all ~12 features back
- Generic constrainability for ASCII types: `func f<T: ASCII.Textual>()`
- Centralizes convenience — no per-type boilerplate

**Disadvantages**:
- Adds a domain protocol — what we're trying to move away from (Strategy C)
- Constrains `Parser.Input` and `Serializer.Buffer` — overly specific
- Creates a coupling between parsing and serialization that the architecture deliberately decoupled

### Option C: Convenience Extensions on Parseable/Serializable

No domain protocol. Instead, constrained extensions on `Parseable` and `Serializable`
provide convenience where the buffer/input type is bytes:

```swift
// In swift-ascii or swift-serializer-primitives:
extension Serializable where Serializer.Buffer == [UInt8] {
    var asciiBytes: [UInt8] {
        var buffer: [UInt8] = []
        Self.serializer.serialize(self, into: &buffer)
        return buffer
    }
}

// In swift-ascii (L3, can import Foundation-free String utilities):
extension Serializable where Serializer.Buffer == [UInt8] {
    var description: String {
        String(decoding: asciiBytes, as: UTF8.self)
    }
}

extension Parseable where Parser.Input == Parser.ByteInput {
    init(_ string: some StringProtocol) throws(Parser.Failure) {
        var input = Parser.ByteInput(Array(string.utf8)[...])
        self = try Self.parser.parse(&input)
    }
}
```

**Advantages**:
- No new protocols
- Any `Serializable` type with byte buffer gets convenience for free
- Works for non-ASCII types too (any byte-serializable type)
- Composable — types opt into `Parseable`, `Serializable`, or both independently

**Disadvantages**:
- Constraints are on buffer/input types, not on "ASCII-ness" — a binary serializer
  with `Buffer == [UInt8]` would also get `description` (probably wrong)
- `CustomStringConvertible` conformance must still be declared per type
- Literal conformances remain per-type

### Comparison

| Criterion | A: No Protocol | B: Domain Protocol | C: Constrained Extensions |
|-----------|:-:|:-:|:-:|
| No new abstractions | **Pass** | Fail | **Pass** |
| Convenience centralization | Fail | **Pass** | Moderate |
| Architecture alignment | **Pass** | Fail | **Pass** |
| Generic constrainability (ASCII) | Fail | **Pass** | Fail |
| Avoids false positives | Pass | Pass | **Fail** (binary types get String) |
| Per-type boilerplate | High | **Low** | Moderate |
| Future flexibility | **Pass** | Moderate | **Pass** |

### Decision: Option C + Per-Type CustomStringConvertible

Option C provides the best balance:

1. **Constrained extensions** on `Serializable where Serializer.Buffer == [UInt8]`
   and `Parseable where Parser.Input == Parser.ByteInput` provide core convenience
2. **`CustomStringConvertible`** is declared per-type (one line, delegates to serializer)
3. **Literal conformances** remain per-type where desired (opt-in, not automatic)
4. **No domain protocol** — the architecture stays clean

The "false positive" concern (binary types getting String methods) is manageable:
binary serializers typically use `Serializer.Buffer == [UInt8]` too, but the methods
would produce binary gibberish as strings — which is harmless (they wouldn't conform
to `CustomStringConvertible` without explicit opt-in).

### Convenience Migration Map

| # | Binary.ASCII.Serializable Feature | Replacement | Location |
|---|-----------------------------------|-------------|----------|
| F1 | `serialize(ascii:into:)` | `T.serializer.serialize(value, into: &buffer)` | Serializable protocol |
| F2 | `init(ascii:in:)` | `T.parser.parse(&input)` | Parseable protocol |
| F3 | Context-dependent parsing | Parser struct stores context, or generic over Context | Per-type parser |
| F4 | Typed throws | `Parser.Failure` / `Serializer.Failure` | Already in architecture |
| F5 | `init(_: StringProtocol)` | Extension on `Parseable where Parser.Input == Parser.ByteInput` | swift-ascii or parser-primitives |
| F6 | `String(ascii:)` | Extension on `Serializable where Serializer.Buffer == [UInt8]` | swift-ascii |
| F7 | CustomStringConvertible | Per-type, one-line delegation | Per standards package |
| F8 | ExpressibleByStringLiteral | Per-type, opt-in | Per standards package |
| F9 | ExpressibleByIntegerLiteral | Per-type, opt-in | Per standards package |
| F10 | `[UInt8](ascii:)` | `T.serializer.serialize(value)` returning `[UInt8]` | Serializable extension |
| F11 | `buffer.append(ascii:)` | `T.serializer.serialize(value, into: &buffer)` | Direct call |
| F12 | Binary.Serializable bridge | Extension `Serializable: Binary.Serializable` where Buffer == [UInt8] | swift-binary-primitives |

### Conformer Inventory (Verified 2026-03-25)

Conformers live in `swift-ietf/`, `swift-whatwg/`, and `swift-foundations/swift-ascii/`.
None in `swift-standards/`.

| Package Group | Location | Types | Parseable | Serializable | Phase |
|--------------|----------|-------|-----------|-------------|-------|
| swift-ascii (Int, UInt, Int64, UInt64) | `swift-foundations/swift-ascii/` | 4 | DONE (L1) | DONE (L1) | 1 |
| RFC 791/4291/4007 (IPv4, IPv6) | `swift-ietf/` | 3 | — | — | 2 |
| RFC 1035/1123 (Domain, Label) | `swift-ietf/` | 4 | — | — | 2 |
| RFC 3986 (URI, Authority, Host, Path, ...) | `swift-ietf/` | 9 | — | — | 3 |
| RFC 3339 (DateTime, Offset) | `swift-ietf/` | 2 | — | — | 4 |
| RFC 2822 (Message, Mailbox, Address, ...) | `swift-ietf/` | 12 | — | — | 5 |
| RFC 5322 (Message, Header, EmailAddress, ...) | `swift-ietf/` | 8 | — | — | 5 |
| RFC 5321/6531 (EmailAddress, LocalPart) | `swift-ietf/` | 4 | — | — | 5 |
| RFC 6068 (Mailto, Mailto.Header) | `swift-ietf/` | 2 | — | — | 5 |
| RFC 2045 (Charset, ContentType, ...) | `swift-ietf/` | 4 | — | — | 6 |
| RFC 2046 (Multipart, Boundary, BodyPart, ...) | `swift-ietf/` | 6 | — | — | 6 |
| RFC 2183/2369/2387 (Disposition, List, Related) | `swift-ietf/` | 6 | — | — | 6 |
| RFC 3987 (IRI) | `swift-ietf/` | 1 | — | — | 7 |
| RFC 7519/7617 (JWT, Basic Auth) | `swift-ietf/` | 3 | — | — | 7 |
| RFC 9557 (Suffix, SuffixTag, Timestamp) | `swift-ietf/` | 3 | — | — | 7 |
| WHATWG URL/Form (URL, Host, Href, ...) | `swift-whatwg/` | 6 | — | — | 7 |
| **Total** | | **77** | **4 done** | **4 done** | |

### Phasing

The migration aligns with parsers-adoption-implementation-plan phases, extended
to include serializer creation.

#### Phase 0: Infrastructure (Prerequisites)

| Task | Package | Status |
|------|---------|--------|
| `Parseable` protocol | swift-parser-primitives | **DONE** |
| `Serializable` protocol + `@Serializer.Builder` | swift-serializer-primitives | **DONE** |
| `Codable` protocol | swift-coder-primitives | **DONE** |
| `Parseable.init(ascii: [UInt8])` convenience | swift-parser-primitives | **DONE** |
| `Serializable.asciiBytes: [UInt8]` convenience | swift-serializer-primitives | **DONE** |
| `Parseable.init(_: StringProtocol)` convenience | swift-parser-primitives or swift-ascii | TODO |
| `Serializable` → String conversion | swift-serializer-primitives or swift-ascii | TODO |
| `Serializable` → `Binary.Serializable` bridge | swift-binary-primitives or swift-ascii | TODO |
| `ASCII.Decimal.Parser<Input, T>` | swift-ascii-parser-primitives | **DONE** |
| `ASCII.Decimal.Serializer<T>` | swift-ascii-serializer-primitives | **DONE** |
| `ASCII.Hexadecimal.Parser` | swift-ascii-parser-primitives | **DONE** |
| `ASCII.Hexadecimal.Serializer` | swift-ascii-serializer-primitives | **DONE** |

#### Phase 1: Primitive Types (4 types) — PARTIALLY DONE

Migrate `Int`, `UInt`, `Int64`, `UInt64` (plus Int8, Int16, Int32, UInt8, UInt16, UInt32):

| Task | Status |
|------|--------|
| `ASCII.Decimal.Parser` | **DONE** (swift-ascii-parser-primitives) |
| `ASCII.Decimal.Serializer<T>` | **DONE** (swift-ascii-serializer-primitives) |
| `Parseable` conformances (all 10 integer types) | **DONE** (FixedWidthInteger+Parseable.swift) |
| `Serializable` conformances (all 10 integer types) | **DONE** (FixedWidthInteger+Serializable.swift) |
| Remove `Binary.ASCII.Serializable` from Int/Int64/UInt/UInt64 | TODO (Int+ASCII.Serializable.swift) |
| `CustomStringConvertible` per-type | N/A (stdlib provides) |
| `ExpressibleByIntegerLiteral` per-type | N/A (stdlib provides) |
| Update tests | TODO |

**Remaining work**: Delete the 4 retroactive `Binary.ASCII.Serializable` conformances
in `swift-ascii/Sources/ASCII/Int+ASCII.Serializable.swift` (lines 103-183). The
`Binary.ASCII.Decimal` namespace, error type, and parsing functions (lines 10-99) may
also be removable if no other code depends on them.

#### Phase 2: Simple Formats (7 types)

IPv4, IPv6, DNS domains:
- `RFC_791.IPv4.Address`, `RFC_4291.IPv6.Address`, `RFC_4007.IPv6.ScopedAddress`
- `RFC_1035.Domain`, `RFC_1035.Domain.Label`, `RFC_1123.Domain`, `RFC_1123.Domain.Label`

#### Phase 3: URI (9 types)

RFC 3986 URI components — most complex grammar, highest reuse:
- Parser types planned in parsers-adoption-implementation-plan Phase 3
- Add Serializer types alongside

#### Phase 4: Date/Time (2 types)

RFC 3339 DateTime, Offset.

#### Phase 5: Email (26 types)

RFC 2822 (12), 5322 (8), 5321 (2), 6531 (2), 6068 (2) — email ecosystem.

#### Phase 6: MIME (16 types)

RFC 2045 (4), 2046 (6), 2183 (3), 2369 (2), 2387 (1) — MIME types.

#### Phase 7: Remaining (13 types)

RFC 3987 (1), 7519 (1), 7617 (2), 9557 (3), WHATWG URL/Form (6).

**Note**: Base62 (`UInt8.Base62.Serializable`) is a separate protocol in
swift-base62-primitives, NOT a `Binary.ASCII.Serializable` conformer. It follows
the same pattern but requires its own migration.

#### Phase 8: Cleanup

- Remove `Binary.ASCII.Serializable` protocol
- Remove `Binary.ASCII.Wrapper`
- Remove `Binary.ASCII.RawRepresentable`
- Remove all extensions in Binary.ASCII.Serializable.swift
- Remove deprecated annotations
- Remove `Binary.ASCII.Decimal` namespace (if unused)

### swift-ascii Warning Status (2026-03-25)

22 deprecation warnings in `swift-ascii/Sources/ASCII/`:

| File | Warnings | Root Cause |
|------|----------|------------|
| `Binary.ASCII.Serializable.swift` | 14 | Extensions on deprecated protocol |
| `Int+ASCII.Serializable.swift` | 4 | Conformances to deprecated protocol |
| `Binary.ASCII.Wrapper.swift` | 2 | References deprecated protocol |
| `Binary.ASCII.RawRepresentable.swift` | 1 | Inherits from deprecated protocol |
| `StringProtocol+INCITS_4_1986.swift` | 1 | Generic constraint on deprecated protocol |

**Int+ASCII.Serializable.swift** (4 warnings): These conformances are fully redundant
with L1 `Parseable` + `Serializable`. Can be deleted once Phase 1 cleanup is done.

**Remaining 18 warnings**: These come from the deprecated protocol infrastructure
that Phases 2-7 conformers still depend on. These warnings persist until Phase 8
(full protocol removal). They must be silenced with `@available(*, deprecated)`
annotations on each extension/reference — the standard Swift deprecation cascade
pattern.

### What Gets Deleted

| File | Contents | Replaced By |
|------|----------|-------------|
| `Binary.ASCII.Serializable.swift` | Protocol + 10 extension groups | Parseable/Serializable + constrained extensions |
| `Binary.ASCII.Wrapper.swift` | `.ascii` instance accessor | Direct `.serializer` / `.parser` access |
| `Binary.ASCII.RawRepresentable.swift` | Synthesized RawRepresentable | Per-type, if still needed |
| `StringProtocol+INCITS_4_1986.swift` (partial) | `init<T: Binary.ASCII.Serializable>` | Extension on Parseable |

## Outcome

**Status**: DECISION

### Decision

1. **No replacement domain protocol** — types independently adopt `Parseable` +
   `Serializable` (or `Codable` for simple symmetric types)
2. **Separate Parser + Serializer per type** — parsing is asymmetric from serialization;
   most parsers already planned
3. **Constrained convenience extensions** on `Parseable` and `Serializable` replace
   protocol extension features (String conversion, byte-buffer helpers)
4. **Per-type opt-in** for `CustomStringConvertible`, literal conformances
5. **8-phase rollout** aligned with parsers-adoption-implementation-plan
6. **Full cleanup** in Phase 8: delete `Binary.ASCII.Serializable`, Wrapper,
   RawRepresentable

### Serializer Creation Scope

Each of the ~82 conformers needs a `*.Serializer: Serializer.Protocol` type.
Serializers for ASCII text formats are typically trivial (concatenate components
to buffer), so this is high-volume but low-complexity work.

### Migration Per-Type Checklist

For each `Binary.ASCII.Serializable` conformer:

- [ ] Create `*.Parser<Input>: Parser.Protocol` (or use existing)
- [ ] Create `*.Serializer: Serializer.Protocol`
- [ ] Conform to `Parseable` (canonical parser)
- [ ] Conform to `Serializable` (canonical serializer)
- [ ] Conform to `CustomStringConvertible` (one-line, delegates to serializer)
- [ ] Conform to literal protocols if previously supported
- [ ] Remove `Binary.ASCII.Serializable` conformance
- [ ] Update tests

## Changelog

- **v2.0.0** (2026-03-25): Status audit. Phase 0 infrastructure largely DONE:
  Parseable, Serializable, Codable protocols all exist; ASCII.Decimal.Parser and
  Serializer exist; integer Parseable/Serializable conformances exist at L1.
  Three Phase 0 convenience extensions remain TODO (StringProtocol init, String
  conversion, Binary.Serializable bridge). Phase 1 partially done — L1 conformances
  exist but L3 deprecated conformances not yet removed. Corrected conformer count:
  77 (not ~83). Corrected locations: conformers in swift-ietf/ and swift-whatwg/
  (not swift-standards/). Corrected Phase 5 count: 26 (not 24). Corrected Phase 7
  count: 13 (not 20). Base62 is separate protocol, not a conformer. Added swift-ascii
  warning status section. Status DECISION → IN_PROGRESS.
- **v1.0.0** (2026-03-04): Initial analysis and decision. ~83 conformers inventoried
  across 16+ standards packages. Zero external generic constraints — migration is clean.
  Three options: no protocol, domain protocol, constrained extensions. Decision:
  Option C (constrained extensions) + per-type CustomStringConvertible. 8-phase
  rollout aligned with parser adoption plan. Full cleanup: delete
  Binary.ASCII.Serializable, Wrapper, RawRepresentable.

## References

- transformation-domain-architecture: [transformation-domain-architecture.md](transformation-domain-architecture.md) (v3.2.0, DECISION)
- canonical-witness-capability-attachment: [canonical-witness-capability-attachment.md](canonical-witness-capability-attachment.md) (v1.2.0, DECISION)
- parsing-serialization-capability-organization: [parsing-serialization-capability-organization.md](parsing-serialization-capability-organization.md) (v1.2.0, RECOMMENDATION)
- parsers-adoption-implementation-plan: [parsers-adoption-implementation-plan.md](parsers-adoption-implementation-plan.md)
- Binary.ASCII.Serializable: `/Users/coen/Developer/swift-foundations/swift-ascii/Sources/ASCII/Binary.ASCII.Serializable.swift`
- Binary.ASCII.Wrapper: `/Users/coen/Developer/swift-foundations/swift-ascii/Sources/ASCII/Binary.ASCII.Wrapper.swift`
- Serialization witnesses: `/Users/coen/Developer/swift-primitives/swift-serialization-primitives/Sources/Serialization Primitives/`
- parsers-ecosystem-adoption-audit: [parsers-ecosystem-adoption-audit.md](parsers-ecosystem-adoption-audit.md)
- [API-NAME-001] Namespace Structure
- [MOD-DOMAIN] One domain per package
- [RES-001] Investigation Triggers
