# Parser Bridge Ergonomics Assessment

<!--
---
version: 1.1.0
last_updated: 2026-03-04
status: RECOMMENDATION
tier: 2
---
-->

## Context

Standards packages contain two parallel parsing systems:

1. **Parser structs** — Generic `Parser.Protocol` conformers (`Token`, `OWS`, `ParameterList`, etc.) operating on `Collection.Slice.Protocol` inputs with typed throws
2. **Underscore helpers** — Procedural functions (`_skipOWS`, `_token`, `_splitOnComma`, etc.) operating on `[UInt8]` with index mutation

The MediaType exemplar (2026-03-04) bridged these systems: `HTTP.MediaType.Parser<Input>` composes Token + OWS + ParameterList, and `HTTP.MediaType.parse()` delegates to it via `Parser.ByteInput`. This research assesses the ergonomics of that bridge pattern before rolling it out to remaining domain types.

## Question

How ergonomic is the current parser bridge architecture? What friction points exist, and what improvements would reduce the cost of writing domain-level parsers?

## Analysis

### Inventory: Current State of RFC 9110

| Domain Type | Lines of Parse Logic | Uses Parser Structs | Uses `_` Helpers | Status |
|-------------|---------------------|--------------------|--------------------|--------|
| MediaType | 3 (bridge) + 77 (parser) | Token, OWS, ParameterList | None | **Migrated** |
| Authentication.Challenge | 44 | None | `_skipOWS`, `_token`, `_splitOnComma`, `_trimOWS`, `_tokenOrQuotedString` | Inline |
| ContentNegotiation.MediaTypePreference | 88 | None | `_splitOnComma`, `_trimOWS`, `_isTchar`, `_skipOWS`, `_quality` | Inline |
| ContentNegotiation.EncodingPreference | 22 | None | `_splitOnComma`, `_trimOWS`, `_token`, `_quality` | Inline |
| ContentNegotiation.LanguagePreference | 34 | None | `_splitOnComma`, `_trimOWS`, `_quality` | Inline |
| ContentNegotiation.CharsetPreference | 22 | None | `_splitOnComma`, `_trimOWS`, `_token`, `_quality` | Inline |
| ContentEncoding | 12 | None | `_splitOnComma`, `_trimOWS` | Inline |
| ContentLanguage | 12 | None | `_splitOnComma`, `_trimOWS` | Inline |
| EntityTag | 24 | None | None (String API) | Inline |
| Precondition (5 methods) | ~55 | None | `_splitOnComma`, `_trimOWS` | Inline |

**Total inline parsing**: ~313 lines across 10 domain types, using helpers that duplicate parser struct logic.

### Ecosystem Comparison

| Package | Parser Structs Defined | Used by Public API | Pattern |
|---------|----------------------|-------------------|---------|
| RFC 9110 | Token, OWS, QuotedString, Parameter, ParameterList, QualityValue, CommaSeparated | MediaType only (exemplar) | Bifurcated |
| RFC 3986 | Authority.Parse, Host.Parse, Path.Parse, Query.Parse | None | Dormant |
| ISO 8601 | DateTime.Parse, Time.Parse, Duration.Parse | **All** (via Parser facade) | **Unified** |

ISO 8601 demonstrates the target architecture: public `Parser` enum with static methods that delegate to generic `Parse<Input>` structs. Zero duplication.

### Friction Points Identified

#### F-1. ByteInput Construction Tax (HIGH)

Every bridge method pays:

```swift
var input = Parser_Primitives.Parser.ByteInput(utf8: string)
return try? Parser<Parser_Primitives.Parser.ByteInput>().parse(&input)
```

The type name `Parser_Primitives.Parser.ByteInput` is fully qualified because `Parser` is shadowed by the domain type's own nested `Parser`. This is 62 characters of type noise per call site.

**Measured cost**: 2 lines of boilerplate per bridge method. Acceptable for a single bridge, but multiplied across ~15 domain `parse()` methods it becomes significant visual overhead.

#### F-2. Dual Generic Constraint (HIGH)

The MediaType parser required `Input: Collection.Slice.Protocol & Swift.Collection`:

```swift
public struct Parser<Input: Collection.Slice.Protocol & Swift.Collection>: Sendable
where Input: Sendable, Input.Element == UInt8 {
```

This was necessary because `String(decoding:as:)` requires `Swift.Collection`, but `Collection.Slice.Protocol` doesn't imply it. We resolved this by adding `Swift.Collection` conformance to `Input.Slice` — a principled infrastructure fix. But the dual constraint remains visible in every domain parser that converts slices to strings.

**Assessment**: The `Swift.Collection` conformance on `Input.Slice` is now permanent infrastructure. Future parsers should constrain to `Swift.Collection` when they need string conversion. Grammar-level parsers (Token, OWS) that stay in byte-land need only `Collection.Slice.Protocol`.

#### F-3. Slice → String Conversion (MEDIUM)

Token returns `Input` (a byte slice). Domain code universally converts:

```swift
let type = String(decoding: typeSlice, as: UTF8.self).lowercased()
```

ParameterList returns `[(name: Input, value: [UInt8])]` — name is a slice, value is `[UInt8]`. Both need conversion:

```swift
let name = String(decoding: p.name, as: UTF8.self).lowercased()
let value = String(decoding: p.value, as: UTF8.self)
```

This is correct (no allocation until string materialization), but the `String(decoding:as: UTF8.self)` ceremony is verbose for a byte parser that always produces UTF-8.

#### F-4. Missing Grammar Combinators (HIGH)

The most-used underscore helpers have no parser struct equivalents:

| Helper | Usage Count | Parser Struct Equivalent |
|--------|------------|------------------------|
| `_splitOnComma` | 8 call sites | `CommaSeparated` exists but uses different model (transform closure, never used) |
| `_trimOWS` | 8 call sites | None |
| `_quality` | 3 call sites | `QualityValue` exists but returns `Int` (0-1000), not `Double?` |
| `_tokenOrQuotedString` | 2 call sites | None (Parameter composes Token + QuotedString but returns tuple, not String) |
| `_isTchar` | 2 call sites | `Token.isTchar` exists as static method |

**`_splitOnComma`** is the dominant pattern. 8 of 10 unmigrated domain types use it. The existing `CommaSeparated` parser struct is designed differently (takes a transform closure, generic over output `T`) and has **zero usage**. The helper's `[Range<Int>]` return type is fundamentally different from how a parser combinator should work.

The correct parser primitive for comma-separated lists would be something that composes with `Token` to parse elements between commas — not a standalone "split then transform" approach.

#### F-5. Parser Name Collision (LOW)

When a domain type nests a `Parser` struct (following `Nest.Name`), `Parser` inside that scope refers to Self, not `Parser_Primitives.Parser`. Conformance requires:

```swift
extension HTTP.MediaType.Parser: Parser_Primitives.Parser.`Protocol` {
```

This is ugly but consistent with how the codebase handles namespace collisions (fully qualified names). The backtick on `Protocol` adds to the visual noise.

**Assessment**: Structural, not solvable without language changes. The cost is one line per parser file.

#### F-6. No Declarative `var body` Composition (HIGH)

Our `Parser.Protocol` requires only `func parse(_ input: inout Input) throws(Failure) -> ParseOutput`. There is no `var body` property on the protocol.

Result builder infrastructure **does exist** in `swift-parser-primitives`:

| Builder | Entry Point | Purpose |
|---------|-------------|---------|
| `Parser.Take.Builder<Input>` | `Parser.Take.Sequence { }` | Sequential composition with automatic Void-skipping |
| `Parser.OneOf.Builder<Input, Output>` | `Parser.OneOf.Sequence { }` | Alternative composition with backtracking |
| `Parser.Take.Transform` | `Parser.Take.Transform(f) { }` | Sequential + output mapping |

Supporting combinators: `Parser.Skip.First/Second` (Void-skip), `Parser.Take.Two` (tuple capture), `Parser.Many.Simple` (repetition), `Parser.Literal` (byte matching → Void), `Parser.Optionally` (backtracking optional), `Parser.Conditional` (if/else). Parameter pack flattening prevents nested tuples.

But this infrastructure is **disconnected from the protocol**. Domain parsers cannot declare their composition declaratively — they must write imperative `func parse` with manual `do/catch` and index manipulation.

**Comparison with PointFree swift-parsing** (our original inspiration):

PointFree's `Parser` protocol has a `var body: Body` requirement annotated with `@ParserBuilder<Input>`. When `Body: Parser` with matching `Input`/`Output`, a default `func parse(_:)` delegates to `body.parse(&input)`. When `Body == Never`, you implement `parse(_:)` directly.

This gives domain parsers a SwiftUI-like declarative style:

```swift
// PointFree pattern
struct MediaTypeParser: Parser {
    var body: some Parser<Substring.UTF8View, MediaType> {
        Parse(.memberwise(MediaType.init)) {
            Whitespace()       // Void → skipped
            Token()            // String → captured
            "/".utf8           // Void → skipped
            Token()            // String → captured
            ParameterList()    // [(name, value)] → captured
        }
    }
}
```

Our MediaType parser instead uses 30 lines of imperative code with manual `do/catch` blocks, explicit `input[input.startIndex] == 0x2F` byte checks, and hand-written slice-to-string conversions.

**What adding `var body` to `Parser.Protocol` would require**:

1. Add `associatedtype _Body` and `typealias Body = _Body` to `Parser.Protocol`
2. Add `@Parser.Take.Builder<Input> var body: Body { get }` requirement
3. Add default `parse(_:)` when `Body: Parser.Protocol, Body.Input == Input, Body.ParseOutput == ParseOutput`
4. Add default `body` when `Body == Never` (fatal error, for leaf parsers)
5. Typed throws complication: the body's `Failure` type becomes `Parser.Error.Either<...>` (nested binary tree), not a clean domain error enum. This is the key tension — PointFree uses untyped `throws`, we use typed throws.

**Experiment Results** (`swift-institute/Experiments/declarative-parser-typed-throws/`):

The builder infrastructure was validated with 10 test variants:

| Variant | Description | Result |
|---------|-------------|--------|
| V1 | Imperative (baseline) | CONFIRMED — clean domain errors |
| V2 | 2 parsers: Void + Value | CONFIRMED — Skip.First, auto Void-skipping |
| V3 | 2 parsers: Value + Value | CONFIRMED — Take.Two tuple |
| V4 | 3 parsers: Void + Value + Void | CONFIRMED — both Voids skipped |
| V5 | 4 parsers: media-type skeleton | CONFIRMED — after `@_disfavoredOverload` fix |
| V6 | 5 parsers: full media-type | CONFIRMED — 3-element tuple output |
| V7 | Error type inspection | CONFIRMED — errors are `Either` trees, not domain enums |
| V8 | `var body` pattern | REFUTED — typed throws creates circular type inference |
| V9 | Builder-inside-imperative | CONFIRMED — works, but error mapping is stringly-typed |
| V10 | Imperative/hybrid parity | CONFIRMED — identical results |

**Infrastructure fix discovered**: `Parser.Take.Builder.buildPartialBlock(accumulated:next:)` had an overload ambiguity between the general `Take.Two` case and the tuple-flattening `Take.Two.Map` case. A single value `Input` can match `(repeat each O1)` with a 1-element pack, making both overloads equally viable. Fixed by adding `@_disfavoredOverload` to the general overload (same pattern PointFree uses).

**Assessment**: The `var body` pattern is **incompatible with typed throws** as currently designed. The fundamental issue: `Body.Failure` is an opaque `Parser.Error.Either<...>` tree inferred from the builder closure. The conforming type cannot write `typealias Failure = Body.Failure` because `Body` is opaque. PointFree avoids this by using untyped `throws` — no `Failure` associated type. Our `Parser.Protocol` requires `associatedtype Failure: Swift.Error & Sendable`.

The "hybrid" approach (V9) — using the builder internally within an imperative `func parse` — works but provides no ergonomic advantage: the `do { try inner.parse(&input) } catch { ... }` block catches `any Error` (typed information lost), forcing stringly-typed error mapping. This is worse than the imperative approach, which catches specific typed errors directly.

#### F-7. No Dead Underscore Helpers Removed (LOW)

`_quotedString` has zero call sites (superseded by `QuotedString` parser struct). Other helpers remain because unmigrated domain types depend on them. Post-migration, all underscore helpers should be deletable.

### What Works Well

1. **Composition is natural**: `HTTP.Parse.Token<Input>()`, `HTTP.Parse.OWS<Input>()`, `HTTP.Parse.ParameterList<Input>()` — zero-argument construction, composable, no configuration
2. **Typed throws propagate cleanly**: `do { try Token().parse(&input) } catch { throw .expectedType }` — catch and rethrow with domain-specific error
3. **Infallible parsers need no error handling**: `OWS().parse(&input)` — void return, never fails, just call it
4. **ParameterList composition**: Internally composes OWS + Parameter + backtracking — callers get `[(name, value)]` with zero protocol knowledge
5. **Generic Input**: Same parser works for any `Collection.Slice.Protocol` — streaming, buffered, zero-copy slices
6. **Builder infrastructure exists**: `Parser.Take.Builder` with Void-skipping, tuple flattening via parameter packs, `Parser.Many.Simple` with range bounds, `Parser.OneOf.Builder` with checkpoint-based backtracking — the combinators are production-ready, just not protocol-integrated

### Prior Art: ISO 8601 Pattern

ISO 8601 uses a two-tier pattern that fully eliminates duplication:

```swift
// Tier 1: Generic parser struct (in Parse file)
extension ISO_8601.DateTime {
    public struct Parse<Input: Collection.Slice.Protocol>: Parser.Protocol { ... }
}

// Tier 2: Public convenience (in domain file)
extension ISO_8601.DateTime {
    public static func parse(_ string: String) -> DateTime? {
        var input = Parser.ByteInput(utf8: string)
        return try? Parse<Parser.ByteInput>().parse(&input)
    }
}
```

This is exactly what we implemented for MediaType. The pattern is validated.

## Recommendations

### R-1. Adopt the MediaType Bridge Pattern for All Domain Types

Migrate remaining 10 domain types to delegate to parser structs. Priority order by complexity:

| Priority | Domain Type | Effort | Blocked By |
|----------|------------|--------|------------|
| 1 | ContentEncoding | Low | Nothing — simple Token + CommaSeparated |
| 2 | ContentLanguage | Low | Nothing — same pattern |
| 3 | EntityTag | Low | Needs new EntityTag.Parser |
| 4 | Precondition | Medium | Depends on EntityTag.Parser |
| 5 | Authentication.Challenge | Medium | Needs Token + ParameterList composition |
| 6 | Authentication.Credentials | Low | Simple split |
| 7-10 | ContentNegotiation.* | Medium | Need QualityValue integration |

### R-2. Add Missing Grammar Combinators

Before migrating, add parser structs that replace the underscore helpers:

| New Parser | Replaces | Grammar |
|-----------|----------|---------|
| `HTTP.Parse.TokenOrQuotedString<Input>` | `_tokenOrQuotedString` | `token / quoted-string` → `[UInt8]` |

`_splitOnComma` and `_trimOWS` should NOT get their own parser structs. Instead, the existing `CommaSeparated` parser should be redesigned or domain types should compose `OWS` + literal byte + `Token` directly.

`_quality` is correctly modeled by the `QualityValue` parser (returns `Int` 0–1000). Domain types should use it and convert from `Int` to their quality representation.

### R-3. Consider a `Parser.UTF8String` Output Wrapper

A thin wrapper that lazily converts `Input` slices to `String` could reduce F-3 friction:

```swift
extension Parser {
    struct UTF8String {
        let bytes: some Swift.Collection<UInt8>
        var string: String { String(decoding: bytes, as: UTF8.self) }
        var lowercased: String { string.lowercased() }
    }
}
```

**Assessment**: Premature. Evaluate after migrating 3-5 more domain types to see if the pattern is truly repetitive enough to warrant abstraction. The existing `String(decoding:as: UTF8.self)` is explicit and zero-magic.

### R-4. Delete Underscore Helpers Post-Migration

Once all domain types are migrated, `HTTP.Parse.swift` should contain only the `HTTP.Parse` namespace declaration. All `_`-prefixed helpers become dead code. Delete them.

Track deletion readiness:

| Helper | Blocked By |
|--------|-----------|
| `_isTchar` | MediaTypePreference, LanguagePreference (inline tchar checks) |
| `_skipOWS` | Authentication.Challenge, Precondition, MediaTypePreference |
| `_token` | EncodingPreference, CharsetPreference, Authentication.Challenge |
| `_quotedString` | Nothing — already zero call sites, **delete now** |
| `_tokenOrQuotedString` | MediaTypePreference, Authentication.Challenge |
| `_splitOnComma` | 8 domain types |
| `_trimOWS` | 8 domain types |
| `_quality` | 3 ContentNegotiation preferences |

### R-5. Declarative `var body` — Blocked by Typed Throws

**Status**: Experimentally validated as BLOCKED.

The experiment (`swift-institute/Experiments/declarative-parser-typed-throws/`) confirmed that the `var body` pattern is incompatible with typed throws:

- The builder produces `Parser.Error.Either<...>` trees as the `Failure` type
- Conforming types cannot write `typealias Failure = Body.Failure` because `Body` is opaque
- The "hybrid" approach (builder inside imperative `func parse`) provides no ergonomic advantage — error type information is lost at the `do/catch` boundary

**Unblocked by experiment**: The builder infrastructure itself works perfectly. `Parser.Take.Sequence { }` correctly composes 2-5+ parsers with automatic Void-skipping and tuple flattening (after the `@_disfavoredOverload` fix). The blocker is exclusively the typed throws ↔ `var body` interaction.

**Possible future resolution paths** (not actionable now):
1. Swift language evolution: if typed throws supports `throws(Body.Failure)` in default implementations with opaque body types
2. Error accessor pattern: `Parser.Error.Either` could provide `.first`, `.second`, `.third` typed accessors for positional error extraction
3. Accept untyped throws for the `var body` path only, typed throws for imperative `func parse`

### R-6. Swift.Collection Constraint Guidance

Document the constraint split:

- **Grammar-level parsers** (Token, OWS, etc.): Constrain to `Collection.Slice.Protocol` only
- **Domain-level parsers** (MediaType.Parser, etc.): Constrain to `Collection.Slice.Protocol & Swift.Collection` when string conversion is needed

This is a natural layering: grammar parsers work in bytes, domain parsers bridge to strings.

## Outcome

**Status**: DECISION

The parser bridge architecture is sound. The imperative pattern (MediaType exemplar) is the correct path forward.

**Key experiment finding**: The declarative `var body` pattern is incompatible with typed throws (`Parser.Protocol.Failure`). The PointFree pattern works because their `Parser` uses untyped `throws`. Our typed throws are non-negotiable ([API-ERR-001]). The builder infrastructure works perfectly for composition, but cannot replace `func parse` at the protocol level. This is a language-level constraint, not a design flaw.

**Infrastructure fix applied**: `@_disfavoredOverload` added to `Parser.Take.Builder.buildPartialBlock(accumulated:next:)` general overload. Without this, 3+ value-producing parsers in a builder cause ambiguity between `Take.Two` and the tuple-flattening `Take.Two.Map` overload (single values match parameter pack of 1). This fix unblocks internal use of builders within imperative parsers.

**Migration path** (imperative, validated):
1. Delete `_quotedString` (zero call sites)
2. Migrate simple domain types (ContentEncoding, ContentLanguage) to validate the pattern scales
3. Add `TokenOrQuotedString` combinator
4. Migrate complex domain types (Authentication, ContentNegotiation)
5. Delete remaining underscore helpers

The `Swift.Collection` conformance on `Input.Slice` was a principled infrastructure addition that unblocks all future domain parsers.

## References

- `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift` — `Parser.Protocol` definition (no `var body`)
- `swift-parser-primitives/Sources/Parser Primitives Core/Parser.ByteInput.swift` — ByteInput convenience inits
- `swift-parser-primitives/Sources/Parser Take Primitives/Parser.Take.Builder.swift` — Sequential result builder with Void-skipping
- `swift-parser-primitives/Sources/Parser Take Primitives/Parser.Take.Sequence.swift` — Entry point: `Parser.Take.Sequence { }`
- `swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Builder.swift` — Alternative result builder
- `swift-parser-primitives/Sources/Parser Skip Primitives/` — `Parser.Skip.First`, `Parser.Skip.Second` (Void-skipping combinators)
- `swift-rfc-9110/Sources/RFC 9110/HTTP.MediaType.Parser.swift` — Exemplar domain parser (imperative)
- `swift-rfc-9110/Sources/RFC 9110/HTTP.Parse.swift` — Underscore helpers (to be deprecated)
- `swift-iso-8601/Sources/ISO 8601/ISO_8601.DateTime.Parse.swift` — Prior art: unified pattern
- `swift-input-primitives/Sources/Input Primitives/Input.Slice+Collection.Slice.Protocol.swift` — Swift.Collection bridge
- `pointfreeco/swift-parsing/Sources/Parsing/Parser.swift` — Prior art: `var body` protocol pattern with `@ParserBuilder`
- `pointfreeco/swift-parsing/Sources/Parsing/Builders/ParserBuilder.swift` — Prior art: result builder with Void-skipping
- `swift-institute/Experiments/declarative-parser-typed-throws/` — Experiment: 10 variants testing builder composition + typed throws
