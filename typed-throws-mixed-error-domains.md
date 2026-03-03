# Typed Throws: Mixed Error Domains

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: RECOMMENDATION
---
-->

## Context

The typed throws conversion ([API-ERR-001]) across swift-standards has eliminated nearly all existential `throws`. Three sites remain because they call functions that throw different error types:

1. **rfc-9112 `Request.Deserializer.deserialize`** — aggregates 6 error types from parsing stages
2. **rfc-9112 `Response.Deserializer.deserialize`** — aggregates 5 error types from parsing stages
3. **iso-8601 `DateTime.init(year:month:day:...)`** — delegates to `Time_Primitives.Time` which `throws(Time.Error)`

The first two are intra-package mixed domains (all error types live in rfc-9112/9110). The third is a cross-layer foreign type (Layer 1 → Layer 2).

## Question

How should mixed error domains be typed? Specifically:

1. For aggregate functions that compose multiple typed-throws sub-operations, what error type should the outer function use?
2. For functions that delegate to a foreign typed error from a lower layer, should they re-throw the foreign error, wrap it, or unify?

## Analysis

### Concrete Error Landscape

#### rfc-9112 Deserializers

`Request.Deserializer.deserialize` calls:

| Step | Function | Error Type |
|------|----------|------------|
| Parse lines | `MessageParser.parseLines` | `MessageParser.ParsingError` |
| Parse request line | `Request.Line.parse` | `Request.Line.ParsingError` |
| Parse headers | `Header.Parser.parseFieldLines` | `Header.Parser.ParsingError` |
| Validate header values | `Header.Field(name:value:)` | `Header.Field.Error` |
| Parse target | `parseTarget` | `DeserializationError` |
| Decode chunked body | `ChunkedEncoding.decode` | `ChunkedDecodingError` |
| Own validation | explicit throws | `DeserializationError` |

`Response.Deserializer.deserialize` is structurally identical, substituting `Response.Line.ParsingError` for `Request.Line.ParsingError`.

#### iso-8601 DateTime

`DateTime.init(year:month:day:...)` calls exactly one external throwing function:

| Step | Function | Error Type |
|------|----------|------------|
| Calendar validation | `Time_Primitives.Time(year:month:day:...)` | `Time.Error` |

No other throws. The function is a thin delegation.

### Option A: Unified Error Enum (Wrap)

Create a single error enum per aggregate function. Each foreign error becomes a case with the original error as an associated value.

```swift
// rfc-9112
extension RFC_9110.Request.Deserializer {
    public enum Error: Swift.Error, Sendable {
        case messageParsing(RFC_9110.MessageParser.ParsingError)
        case requestLine(RFC_9110.Request.Line.ParsingError)
        case headerParsing(RFC_9110.Header.Parser.ParsingError)
        case headerValidation(RFC_9110.Header.Field.Error)
        case chunkedDecoding(RFC_9110.ChunkedEncoding.ChunkedDecodingError)
        case emptyMessage
        case missingHeaderBodySeparator
        case invalidTarget(String)
        case incompleteBody(expected: Int, available: Int)
    }
}

// iso-8601
extension ISO_8601.DateTime {
    // Already has ISO_8601.Date.Error — add a case:
    case invalidComponents(Time_Primitives.Time.Error)
}
```

**Advantages:**
- Single error type per function — clean `throws(Error)` signature
- Preserves full error detail (original error is nested)
- Caller can `switch` on the phase that failed
- Follows [API-ERR-001] and [IMPL-041] (typed enum)
- The wrapping IS the domain crossing — it names the phase

**Disadvantages:**
- Boilerplate: each `try` becomes `do { try ... } catch { throw .wrappedCase(error) }`
- Wrapper cases inflate the error enum
- Callers that only care about "did deserialization fail?" must still handle N cases

### Option B: Either / Sum Type (Structural)

Use a generic `Either<A, B>` (or `Error2<A, B>`, `Error3<A, B, C>`, etc.) to compose error types structurally.

```swift
// Structural sum
public func deserialize(...) throws(
    Either<DeserializationError,
    Either<MessageParser.ParsingError,
    Either<Request.Line.ParsingError,
    Either<Header.Parser.ParsingError,
    Either<Header.Field.Error,
           ChunkedDecodingError>>>>>
) -> ...
```

Or with a variadic-style alias:

```swift
typealias DeserializeError = Error6<
    DeserializationError,
    MessageParser.ParsingError,
    Request.Line.ParsingError,
    Header.Parser.ParsingError,
    Header.Field.Error,
    ChunkedDecodingError
>
```

**Advantages:**
- No wrapping boilerplate — each `try` site auto-infers
- No new error type needed — structural composition
- Preserves exact error types without erasure
- Theoretically zero-overhead (compiler can optimize)

**Disadvantages:**
- Deeply nested `Either` is unreadable in signatures and catch sites
- Swift has no variadic generics for errors — `Error6` would need manual definition
- Catching requires navigating `.left(.right(.left(...)))` — terrible ergonomics
- No semantic name for the failure phase (is `.right(.left(x))` a header error or a line error?)
- Not idiomatic Swift — no precedent in the ecosystem
- The type signature IS the implementation detail — it leaks mechanism [IMPL-INTENT]

### Option C: Catch-and-Wrap at Boundaries (Phased)

Keep the existing `DeserializationError` enum but add a generic wrapping case for sub-phase errors. Each `try` call is wrapped in a `do/catch` that maps to a phase.

```swift
extension RFC_9110.Request.Deserializer {
    public enum DeserializationError: Swift.Error, Sendable {
        case emptyMessage
        case missingHeaderBodySeparator
        case invalidTarget(String)
        case incompleteBody(expected: Int, available: Int)
        // Phase-tagged wrapping
        case parsingFailed(phase: Phase, underlying: any Error & Sendable)
    }

    public enum Phase: String, Sendable {
        case messageLines, requestLine, headers, headerValidation, chunkedDecoding
    }
}
```

**Advantages:**
- Preserves existing error cases (backwards compatible)
- Phase enum gives semantic context
- Single wrapping case instead of N cases

**Disadvantages:**
- `underlying: any Error` reintroduces existential — defeats the purpose
- Callers can't statically switch on the underlying error type
- Half-typed: the outer is typed, the inner is erased
- Violates [API-ERR-001] in spirit

### Option D: Foreign Re-throw (for iso-8601 specifically)

For the simple delegation case (one foreign error type), re-throw the foreign error directly.

```swift
// iso-8601
public init(year:month:day:...) throws(Time_Primitives.Time.Error) {
    let time = try Time_Primitives.Time(year:month:day:...)
    self.init(time: time, timezoneOffset: ...)
}
```

**Advantages:**
- Zero wrapping — direct pass-through
- Caller sees the exact error type from the authority
- Time owns calendar validation — ISO 8601 delegates, so the error IS Time's

**Disadvantages:**
- Exposes Layer 1 type in Layer 2 public API — tight cross-layer coupling
- If Time.Error changes, ISO 8601's public API changes
- Callers must import Time_Primitives to catch specific cases
- Inconsistent: all other ISO 8601 functions throw `ISO_8601.Date.Error`

### Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Type safety | High | Error type fully typed, no `any Error` |
| Readability | High | Signature and catch sites read as intent |
| Consistency | High | Same pattern across all mixed-domain sites |
| Boilerplate | Medium | Amount of wrapping code needed |
| Caller ergonomics | High | How easy is it to handle the error? |
| Layer isolation | Medium | Lower layers don't leak into higher layer APIs |
| Preserves detail | Medium | Original error information is accessible |

### Comparison

| Criterion | A: Unified Enum | B: Either | C: Phase-Tagged | D: Re-throw |
|-----------|----------------|-----------|-----------------|-------------|
| Type safety | Full | Full | Partial (existential) | Full |
| Readability | Good — named cases | Poor — nested generics | Good | Good |
| Consistency | Yes — same pattern everywhere | Possible but ugly | Yes | Only for single-foreign |
| Boilerplate | Medium (do/catch per try) | None | Medium | None |
| Caller ergonomics | Good — switch on phase | Poor — nested matching | OK — switch + cast | Good but leaky |
| Layer isolation | Full | Full | Full | None |
| Preserves detail | Full (associated value) | Full | Partial (erased) | Full |

## Outcome

**Status**: RECOMMENDATION

### Primary: Option A (Unified Error Enum) for all mixed-domain sites

Option A is the only approach that is fully typed, readable, consistent, and layer-isolating. The boilerplate cost is acceptable:

```swift
// Pattern: do { try sub() } catch { throw .phase(error) }
let lines = do { try MessageParser.parseLines(from: data) }
            catch { throw Error.messageParsing(error) }
```

The wrapping is not accidental complexity — it names the deserialization phase where failure occurred. "Message parsing failed" vs "header validation failed" vs "chunked decoding failed" is genuine domain information.

### For rfc-9112 Deserializers

Rename `DeserializationError` → `Error` (per [IMPL-041] nesting convention). Merge the original cases with wrapping cases:

```swift
extension RFC_9110.Request.Deserializer {
    public enum Error: Swift.Error, Sendable {
        // Deserialization-specific
        case emptyMessage
        case missingHeaderBodySeparator
        case invalidTarget(String)
        case incompleteBody(expected: Int, available: Int)
        // Phase delegation
        case messageParsing(RFC_9110.MessageParser.ParsingError)
        case requestLine(RFC_9110.Request.Line.ParsingError)
        case headerParsing(RFC_9110.Header.Parser.ParsingError)
        case headerValidation(RFC_9110.Header.Field.Error)
        case chunkedDecoding(RFC_9110.ChunkedEncoding.ChunkedDecodingError)
    }
}
```

Same pattern for `Response.Deserializer.Error`, substituting `Response.Line.ParsingError`.

### For iso-8601 DateTime

Add a wrapping case to the existing `ISO_8601.Date.Error`:

```swift
extension ISO_8601.Date {
    public enum Error: Swift.Error, Sendable {
        // existing cases...
        case invalidFormat(String)
        case invalidFractionalSecond(Int)
        // new: wraps Time validation errors
        case invalidComponents(Time_Primitives.Time.Error)
    }
}
```

Then `DateTime.init(year:month:day:...)` becomes:

```swift
public init(year:month:day:...) throws(ISO_8601.Date.Error) {
    let time: Time_Primitives.Time
    do { time = try Time_Primitives.Time(year:month:day:...) }
    catch { throw .invalidComponents(error) }
    self.init(time: time, timezoneOffset: ...)
}
```

This preserves the full `Time.Error` detail while keeping ISO 8601's public API consistently typed as `throws(ISO_8601.Date.Error)`.

### Why not Either

The Either approach (Option B) violates [IMPL-INTENT]: the type signature becomes mechanism (`Either<A, Either<B, Either<C, D>>>`) rather than intent. It has no precedent in Swift and produces unusable catch sites. It would require building and maintaining `Either` / `ErrorN` infrastructure in primitives for zero ergonomic benefit.

### Why not Re-throw

Option D (re-throw foreign error) works technically but breaks layer isolation. ISO 8601 (Layer 2) would expose `Time_Primitives.Time.Error` (Layer 1) in its public API. Every ISO 8601 consumer would need to know about Time primitives. The wrapping case `invalidComponents(Time.Error)` costs one line but buys clean layering.

## References

- [API-ERR-001] Typed throws requirement
- [IMPL-041] Error type nesting convention
- [IMPL-INTENT] Code reads as intent, not mechanism
- Five-layer architecture: upward dependency prohibition
