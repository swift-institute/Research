# Parsers Adoption Implementation Plan

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: SUPERSEDED
tier: 2
superseded_by: next-steps-parsers.md
---
-->

> **Status**: SUPERSEDED (2026-03-15)
> **Superseded by**: **next-steps-parsers.md** (v2.0.0)
> This implementation plan (tiers, prerequisites, execution order, naming conventions, error type compatibility, validation strategy) is fully absorbed into the next-steps tracking document.
> It remains as historical reference for the architectural reasoning behind the adoption strategy.

## Context

The [parsers-ecosystem-adoption-audit](parsers-ecosystem-adoption-audit.md) identified 95 opportunities (52 HIGH priority) to replace hand-rolled parsing across ~30 standards packages with the parser combinator system from `swift-parser-primitives` (Layer 1). Only 3 packages currently use parser-primitives: RFC 8259 (JSON), W3C XML, and INCITS 4-1986.

This document plans the execution order, shared infrastructure, and per-package scope for adopting parser combinators ecosystem-wide.

## Question

In what order, with what shared infrastructure, and to what depth should parser combinators be adopted across the Swift Institute ecosystem?

## Analysis

### Architectural Constraints

1. **Layer 2 cannot import Layer 3.** Standards packages can depend on `swift-parser-primitives` (Layer 1) but NOT `swift-parsers` (Layer 3). Any parser needed by standards must exist at Layer 1.

2. **No ASCII integer parser at Layer 1.** `Parsers.Integer` lives at Layer 3. At Layer 1, only `ASCII.Parsing.digit` / `ASCII.Parsing.hexDigit` (byte→value) exist in `swift-ascii-primitives`. Binary integer parsers exist in `swift-binary-parser-primitives` but parse binary-encoded integers, not ASCII text.

3. **Individual Package.swift files.** Each standards package has its own `Package.swift`. Adding `swift-parser-primitives` as a dependency requires modifying each package's manifest individually.

4. **Existing input pattern.** Standards packages use `init<Bytes: Collection>(ascii bytes: Bytes, in _: Bytes.Type) throws(Error)` — generic over byte collections. The parser combinator system uses `Parser.CollectionInput<[UInt8]>` (`Input.Slice<[UInt8]>`). Bridging these is straightforward: wrap the byte collection into `Parser.CollectionInput` at the entry point.

5. **Reference patterns.** W3C XML defines parsers as `struct Name<Input: Parser.Input>: Parser.Parser, Sendable where Input: Sendable, Input.Element == UInt8`. RFC 8259 prototype uses `ArraySlice<UInt8>` directly. Both patterns are valid; the generic `Input: Parser.Input` approach is preferred for reusability.

### Prerequisite: Layer 1 ASCII Integer Parser

**Problem.** Decimal and hexadecimal integer parsing from ASCII byte streams is needed by virtually every standards package:

| Package | Integer parsing sites |
|---------|----------------------|
| RFC 9112 | HTTP version (`1.1`), status code (`200`), chunk size (hex) |
| RFC 9111 | Cache-Control max-age, Age header |
| ISO 8601 | Year, month, day, hour, minute, second (all decimal) |
| RFC 3986 | Port number |
| RFC 5322 | Day, year in date-time |
| RFC 5646 | (none — subtag lengths, not values) |
| RFC 7519 | (none — structural only) |

**Solution.** Create two new parser types in `swift-parser-primitives`:

```
swift-parser-primitives/Sources/Parser ASCII Integer Primitives/
    Parser.ASCII.Integer.Decimal.swift
    Parser.ASCII.Integer.Hexadecimal.swift
    Parser.ASCII.Integer.swift      (namespace)
    exports.swift
```

API:
```swift
extension Parser.ASCII {
    public enum Integer {}
}

extension Parser.ASCII.Integer {
    /// Parses a decimal integer from ASCII bytes.
    /// Consumes 1+ digit bytes (0x30–0x39), accumulates into T.
    public struct Decimal<Input: Parser.Input, T: FixedWidthInteger>: Parser.Parser, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public init()
        public func parse(_ input: inout Input) throws(Error) -> T
    }

    /// Parses a hexadecimal integer from ASCII bytes.
    /// Consumes 1+ hex digit bytes, accumulates into T.
    public struct Hexadecimal<Input: Parser.Input, T: FixedWidthInteger>: Parser.Parser, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public init()
        public func parse(_ input: inout Input) throws(Error) -> T
    }
}
```

**Dependencies:** `swift-ascii-primitives` (for `ASCII.Parsing.digit` / `ASCII.Parsing.hexDigit`), `swift-input-primitives`.

This module must be created and tested **before** any standards package adoption begins.

### Shared Infrastructure Identification

Several parsing patterns recur across multiple packages. Building these once prevents duplication.

#### HTTP Shared Parsers (in RFC 9110)

RFC 9110 is the dependency root for all HTTP packages (RFC 9111 depends on RFC 9110, RFC 9112 depends on RFC 9110). Shared HTTP parsers belong here.

| Parser | Grammar (RFC 9110 ABNF) | Used by |
|--------|-------------------------|---------|
| `HTTP.Parse.OWS` | `*( SP / HTAB )` | Every header parser |
| `HTTP.Parse.Token` | `1*tchar` where tchar = `!#$%&'*+-.^_`\|~` / DIGIT / ALPHA | MediaType, Authentication, CacheControl, Connection, TransferEncoding |
| `HTTP.Parse.QuotedString` | `DQUOTE *( qdtext / quoted-pair ) DQUOTE` | MediaType parameters, Authentication, CacheControl, EntityTag |
| `HTTP.Parse.Parameter` | `token "=" ( token / quoted-string )` | MediaType, ContentNegotiation, Authentication, CacheControl |
| `HTTP.Parse.ParameterList` | `*( OWS ";" OWS parameter )` | MediaType, ContentNegotiation, RFC 2045, RFC 2183 |
| `HTTP.Parse.CommaSeparated<Element>` | `#element = [ 1#element ] = *( "," OWS ) element *( OWS "," [ OWS element ] )` | ContentLanguage, ContentEncoding, Connection, TransferEncoding, Vary, Precondition, CacheControl |
| `HTTP.Parse.QualityValue` | `weight = OWS ";" OWS "q=" qvalue` | ContentNegotiation (Accept, Accept-Encoding, Accept-Language, Accept-Charset) |

New files in `swift-rfc-9110/Sources/RFC 9110/`:

```
HTTP.Parse.swift                     (namespace + error type)
HTTP.Parse.OWS.swift                 (optional whitespace)
HTTP.Parse.Token.swift               (HTTP token)
HTTP.Parse.QuotedString.swift        (quoted-string)
HTTP.Parse.Parameter.swift           (token "=" value)
HTTP.Parse.ParameterList.swift       (semicolon-separated parameters)
HTTP.Parse.CommaSeparated.swift      (comma-separated list, generic over Element parser)
HTTP.Parse.QualityValue.swift        (quality value weight)
```

#### MIME Parameter Parsers (in RFC 2045)

RFC 2045 defines MIME media type syntax that RFC 2183 (Content-Disposition) reuses. RFC 2045's existing parameter parsing already handles semicolon-separated `name=value` pairs at the byte level. After rewriting RFC 2045 with combinators, RFC 2183 can import and reuse these parsers.

**Decision:** No separate shared module needed. RFC 2045's `ContentType` parser already serves as the shared infrastructure for MIME parameters. RFC 2183 already depends on RFC 2045.

#### URI Sub-Parsers (in RFC 3986)

RFC 3986 defines URI syntax reused by WHATWG URL, RFC 6068 (mailto), RFC 6570 (URI templates), RFC 6455 (WebSocket). Sub-parsers to expose:

| Parser | Grammar | Used by |
|--------|---------|---------|
| `RFC_3986.Parse.Scheme` | `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )` | RFC 6068, WHATWG URL |
| `RFC_3986.Parse.Authority` | `[ userinfo "@" ] host [ ":" port ]` | RFC 6068, RFC 6455 |
| `RFC_3986.Parse.Host` | `IP-literal / IPv4address / reg-name` | WHATWG URL |
| `RFC_3986.Parse.Path` | `path-abempty / path-absolute / ...` | WHATWG URL, RFC 6068 |
| `RFC_3986.Parse.Query` | `*( pchar / "/" / "?" )` | WHATWG URL, RFC 6068 |
| `RFC_3986.Parse.PercentEncoded` | `"%" HEXDIG HEXDIG` | All URI-using packages |

New files in `swift-rfc-3986/Sources/RFC 3986/`:

```
RFC_3986.Parse.swift                 (namespace + error type)
RFC_3986.Parse.Scheme.swift
RFC_3986.Parse.Authority.swift
RFC_3986.Parse.Host.swift
RFC_3986.Parse.Port.swift
RFC_3986.Parse.Path.swift
RFC_3986.Parse.Query.swift
RFC_3986.Parse.Fragment.swift
RFC_3986.Parse.Userinfo.swift
RFC_3986.Parse.PercentEncoded.swift
```

### Phased Execution Plan

Ordered leaf-first (packages with fewest dependents first), building shared infrastructure as we go up the dependency tree.

---

### Phase 0: Layer 1 ASCII Integer Parser

**Package:** `swift-parser-primitives`
**Path:** `https://github.com/swift-primitives/swift-parser-primitives`
**Scope:** New module, ~4 files, ~150 lines

**Deliverables:**
1. `Parser ASCII Integer Primitives` target in Package.swift
2. `Parser.ASCII.Integer.Decimal<Input, T>` — parses 1+ ASCII decimal digits into `T: FixedWidthInteger`
3. `Parser.ASCII.Integer.Hexadecimal<Input, T>` — parses 1+ ASCII hex digits into `T: FixedWidthInteger`
4. Both support optional `minDigits` / `maxDigits` constraints
5. Error type: `Parser.ASCII.Integer.Error` (`.unexpectedEndOfInput`, `.invalidDigit`, `.overflow`)
6. Tests for each type with edge cases (overflow, empty, leading zeros)

**Dependencies to add:** `swift-ascii-primitives` (for digit/hexDigit conversion functions).

**Blocks:** All subsequent phases.

---

### Phase 1: RFC 9110 HTTP Shared Parsers

**Package:** `swift-rfc-9110`
**Path:** `https://github.com/swift-standards/swift-rfc-9110`
**Scope:** ~8 new shared parser files + rewrite 7 existing files (30 parse functions total)

**Step 1.1: Add parser-primitives dependency**

Add to `swift-rfc-9110/Package.swift`:
```swift
.package(path: "../swift-primitives/swift-parser-primitives")
```

Add `"Parser Primitives"` to the `RFC 9110` target's dependencies.

**Step 1.2: Create shared HTTP parsers**

| New file | Type | Combinator composition |
|----------|------|----------------------|
| `HTTP.Parse.swift` | Namespace enum + `HTTP.Parse.Error` | — |
| `HTTP.Parse.OWS.swift` | `HTTP.Parse.OWS<Input>` | `Parser.Prefix.While { $0 == 0x20 \|\| $0 == 0x09 }` (Failure = Never) |
| `HTTP.Parse.Token.swift` | `HTTP.Parse.Token<Input>` | `Parser.Prefix.While(minLength: 1) { isTchar($0) }` |
| `HTTP.Parse.QuotedString.swift` | `HTTP.Parse.QuotedString<Input>` | Manual byte walk for escape handling (conforming to `Parser.Parser`) |
| `HTTP.Parse.Parameter.swift` | `HTTP.Parse.Parameter<Input>` | `Token`, skip `Parser.Byte(0x3D)`, `Parser.OneOf { QuotedString; Token }` |
| `HTTP.Parse.ParameterList.swift` | `HTTP.Parse.ParameterList<Input>` | `Parser.Many.Separated(separator: { OWS; Byte(0x3B); OWS }) { Parameter }` |
| `HTTP.Parse.CommaSeparated.swift` | `HTTP.Parse.CommaSeparated<Input, Element>` | Generic over Element parser. `Parser.Many.Separated(separator: { OWS; Byte(0x2C); OWS }) { element }` |
| `HTTP.Parse.QualityValue.swift` | `HTTP.Parse.QualityValue<Input>` | `OWS; Byte(0x3B); OWS; Literal("q="); digit-dot-digits` |

**Step 1.3: Rewrite existing parsers**

| File | Current parse fns | Combinator replacement | Scope |
|------|-------------------|----------------------|-------|
| `HTTP.MediaType.swift` | 1 (`parse(_ string:)`) | `Token`, `/`, `Token`, `ParameterList` | ~40 lines → ~15 |
| `HTTP.ContentNegotiation.swift` | 5 (Accept, Accept-Encoding, Accept-Language, Accept-Charset, QualityValue) | `CommaSeparated { element; Optionally { QualityValue } }` — one generic pattern for all 4 | ~200 lines → ~60 |
| `HTTP.ContentLanguage.swift` | 1 | `CommaSeparated { Token }` | ~7 lines → ~3 |
| `HTTP.ContentEncoding.swift` | 1 | `CommaSeparated { Token }` | ~6 lines → ~3 |
| `HTTP.Authentication.swift` | 2 (Challenge, Credentials) | `Token` (scheme), `OWS`, `CommaSeparated { Parameter }` or `Rest` for token68 | ~70 lines → ~30 |
| `HTTP.EntityTag.swift` | 1 | `Parser.OneOf { Literal("W/"); Always(()) }`, `QuotedString` | ~25 lines → ~10 |
| `HTTP.Precondition.swift` | 5 | `CommaSeparated { EntityTag }`, delegates to RFC 5322 for dates | ~45 lines → ~20 |

**Side effects:**
- `HTTP.CacheControl.swift` (RFC 9111) will use the same shared parsers — but that's Phase 2.

**Foundation elimination:** None needed (no Foundation imports in RFC 9110).

**Blocks:** Phase 2 (RFC 9111, RFC 9112).

---

### Phase 2: RFC 9111 + RFC 9112

**Packages:** `swift-rfc-9111`, `swift-rfc-9112`
**Paths:** `https://github.com/swift-standards/swift-rfc-9111`, `https://github.com/swift-standards/swift-rfc-9112`
**Scope:** Rewrite 14 parse functions across 12 files

These packages depend on RFC 9110, so Phase 1's shared parsers are available.

#### RFC 9111 (3 files, 3 parse functions)

| File | Current | Replacement | Notes |
|------|---------|-------------|-------|
| `HTTP.CacheControl.swift` | `components(separatedBy: ",")`, `components(separatedBy: "=")`, `CharacterSet` (Foundation leak at line 287) | `HTTP.Parse.CommaSeparated { Token; Optionally { Byte(0x3D); OneOf { QuotedString; Token } } }` + switch on directive name | **Eliminates Foundation `CharacterSet` leak** |
| `HTTP.Vary.swift` | `components(separatedBy: ",")` | `HTTP.Parse.CommaSeparated { Token }` | |
| `HTTP.Age.swift` | `Int(trimmed)` | `HTTP.Parse.OWS`, `Parser.ASCII.Integer.Decimal<_, Int>`, `Parser.End` | |

**Foundation elimination:** Yes — removes `CharacterSet(charactersIn: "\"")` and `.trimmingCharacters(in:)` from `HTTP.CacheControl.swift:287`.

#### RFC 9112 (9 files, 11 parse functions)

Add `swift-parser-primitives` dependency to `swift-rfc-9112/Package.swift`.

| File | Current parse fns | Replacement |
|------|-------------------|-------------|
| `HTTP.Version.swift` | 1 | `Literal("HTTP/")`, `ASCII.Integer.Decimal`, `Byte(0x2E)`, `ASCII.Integer.Decimal` |
| `HTTP.Request.Line.swift` | 1 (+ 1 stub) | `Token` (method), `Byte(0x20)`, `Prefix.While { $0 != 0x20 }` (target), `Byte(0x20)`, Version parser |
| `HTTP.Response.Line.swift` | 1 (+ 1 stub) | Version parser, `Byte(0x20)`, `ASCII.Integer.Decimal` (status), `Byte(0x20)`, `Rest` (reason) |
| `HTTP.Field.swift` | 4 | `Prefix.While(minLength: 1) { isFieldNameChar($0) }` (name), `Byte(0x3A)`, `OWS`, `Rest` (value). Obs-fold handling as `Parser.Many`. |
| `HTTP.ChunkedEncoding.swift` | 2 | Chunk-size: `ASCII.Integer.Hexadecimal`, `Optionally { Byte(0x3B); ParameterList }` (extensions), `Literal("\r\n")`. Trailer: reuse Field parser. |
| `HTTP.Connection.swift` | 1 | `HTTP.Parse.CommaSeparated { Token }` |
| `HTTP.TransferEncoding.swift` | 1 | `HTTP.Parse.CommaSeparated { Token }` |
| `HTTP.Host.swift` | (audit says MEDIUM) | Reuse RFC 3986 authority parser after Phase 3; defer to Phase 4 |
| `HTTP.Message.Deserializer.swift` | (audit says MEDIUM) | Compose Request.Line + Field parser + body; defer detailed design |

**Stub functions:** `Request.Line.parse(_ data: [UInt8])` and `Response.Line.parse(_ data: [UInt8])` at line 67/70 currently `fatalError`. These become the primary implementations (byte-level parser combinators), while the String overloads become wrappers.

---

### Phase 3: RFC 3986 URI Parser

**Package:** `swift-rfc-3986`
**Path:** `https://github.com/swift-standards/swift-rfc-3986`
**Scope:** Rewrite 9+ parse functions, ~430 lines of hand-rolled parsing → combinator-based, eliminate duplicate Authority parser

Add `swift-parser-primitives` dependency to `swift-rfc-3986/Package.swift`.

**Step 3.1: Create URI sub-parsers (new files)**

| Parser struct | Composition | Notes |
|---------------|-------------|-------|
| `RFC_3986.Parse.Scheme` | `First.Where { isAlpha($0) }`, `Prefix.While { isSchemeChar($0) }` | Already has character-class functions in `RFC_3986.CharacterSet.swift` |
| `RFC_3986.Parse.PercentEncoded` | `Byte(0x25)`, `First.Where { isHexDigit }`, `First.Where { isHexDigit }` | Shared by all URI sub-parsers |
| `RFC_3986.Parse.Userinfo` | `Prefix.While { isUserinfoChar($0) }`, terminated by `@` | |
| `RFC_3986.Parse.Host` | `OneOf { IPLiteral; IPv4Address; RegName }` | Delegates to RFC 4291 for IPv6, RFC 791 for IPv4 |
| `RFC_3986.Parse.Port` | `ASCII.Integer.Decimal<_, UInt16>` | After `Byte(0x3A)` |
| `RFC_3986.Parse.Authority` | `Optionally { Userinfo; Byte(0x40) }`, `Host`, `Optionally { Byte(0x3A); Port }` | **Eliminates the duplicate Authority parser** (currently has both `init(ascii:in:)` and `init(_ string:)` with identical logic) |
| `RFC_3986.Parse.Path` | `Many.Separated(separator: { Byte(0x2F) }) { Prefix.While { isPchar($0) } }` | |
| `RFC_3986.Parse.Query` | `Prefix.While { isQueryChar($0) }` (raw), plus `Many.Separated(separator: { Byte(0x26) }) { KeyValue }` for parameters | |
| `RFC_3986.Parse.Fragment` | `Prefix.While { isFragmentChar($0) }` | |

**Step 3.2: Top-level URI parser**

`RFC_3986.Parse.URI` composes all sub-parsers:
```
Scheme, Literal("://"), Authority, Path, Optionally { Byte(0x3F); Query }, Optionally { Byte(0x23); Fragment }
```

For relative references (no scheme), use `Parser.OneOf` with backtracking.

**Step 3.3: Rewrite existing init methods**

Each existing `init<Bytes>(ascii:in:)` on `URI`, `URI.Authority`, `URI.Host`, etc. becomes a thin wrapper that constructs `Parser.CollectionInput`, runs the appropriate combinator parser, and maps the output.

**Eliminates:**
- Duplicate `Authority` parser (two nearly identical implementations)
- Uncached `userinfo` computed property that re-parses the URI on every access
- `removeDotSegments` can remain as a post-processing step (path normalization, not parsing)

---

### Phase 4: URI-Dependent Packages

These packages depend on RFC 3986 and can reuse its sub-parsers.

#### 4A: WHATWG URL

**Package:** `swift-whatwg-url`
**Path:** `https://github.com/swift-standards/swift-whatwg-url`
**Scope:** 5 files, ~6 parse functions

| File | Current | Replacement |
|------|---------|-------------|
| `WHATWG_URL.URL.Path.swift` | `split(separator: "/")` | `Parser.Many.Separated(separator: { Byte(0x2F) })` or reuse `RFC_3986.Parse.Path` |
| `RFC_791+WHATWG.swift` | `String.split(separator: ".")`, manual hex/octal detection | `Parser.Many.Separated(separator: { Byte(0x2E) }) { ASCII.Integer.Decimal }` with WHATWG-specific radix handling |
| `RFC_4291+WHATWG.swift` | `String.split(separator: ":")` preprocessing | `Parser.Many.Separated(separator: { Byte(0x3A) }) { ASCII.Integer.Hexadecimal }` with `::` compression |
| `URLEncoding.swift` | `split("&")` then `split("=")` | `Many.Separated(separator: { Byte(0x26) }) { Prefix.UpTo([0x3D]); Byte(0x3D); Rest }` |
| `WHATWG_URL.PercentEncoding.swift` | Manual percent-decode loop | `Parser.OneOf { PercentEncoded; First.Element }` in a `Parser.Many` |

**Dependencies to add:** `swift-parser-primitives`.

#### 4B: RFC 6570 URI Templates

**Package:** `swift-rfc-6570`
**Path:** `https://github.com/swift-standards/swift-rfc-6570`
**Scope:** 3 parse functions, ~140 lines

| Function | Current | Replacement |
|----------|---------|-------------|
| `Template.parse(_:)` | Manual `String.Index` walk | `Parser.Many { OneOf { LiteralText; Expression } }` where Expression = `Between("{", "}") { Optionally { operator }; Many.Separated(separator: Byte(0x2C)) { VarSpec } }` |
| `parseExpression` | `remaining.split(separator: ",")`, `remaining.first` | Composed into Template parser above |
| `parseVarSpec` | `hasSuffix("*")`, `firstIndex(of: ":")` | `Token`, `OneOf { Literal("*"); Sequence { Byte(0x3A); ASCII.Integer.Decimal } }` |

**Note:** This package currently operates on `String`, not `[UInt8]`. The combinator rewrite should use byte-level input. Templates are ASCII-only by spec.

**Dependencies to add:** `swift-parser-primitives`.

#### 4C: RFC 6068 Mailto

**Package:** `swift-rfc-6068`
**Path:** `https://github.com/swift-standards/swift-rfc-6068`
**Scope:** 1 main parse function with internal byte loops

| Function | Current | Replacement |
|----------|---------|-------------|
| `Mailto.init<Bytes>(ascii:in:)` | Manual byte walk for `?` boundary, comma-split loop for addresses, ampersand-split loop for headers | `Literal("mailto:")`, `Many.Separated(separator: Byte(0x2C)) { Prefix.While { isMailtoPathChar } }` (addresses), `Optionally { Byte(0x3F); Many.Separated(separator: Byte(0x26)) { Header } }` |

**Dependencies to add:** `swift-parser-primitives`.

#### 4D: RFC 2369 List Headers

**Package:** `swift-rfc-2369`
**Path:** `https://github.com/swift-standards/swift-rfc-2369`
**Scope:** 2 parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `List.Header.init<Bytes>(ascii:in:)` | Manual CRLF split, angle-bracket scanner | `Many.Separated(separator: OWS+Byte(0x2C)+OWS) { Between(Byte(0x3C), Byte(0x3E)) { Prefix.While { $0 != 0x3E } } }` |
| `List.Post.init<Bytes>(ascii:in:)` | Similar angle-bracket scanner + `"NO"` check | `OneOf { Literal("NO"); AngleBracketedIRI }` |

**Dependencies to add:** `swift-parser-primitives`.

---

### Phase 5: ISO 8601 + Date/Time

**Package:** `swift-iso-8601`
**Path:** `https://github.com/swift-standards/swift-iso-8601`
**Scope:** ~15 parse functions, ~500 lines → combinator-based

This is the single most impactful rewrite by line count. All parsing is ASCII digit extraction with separators.

Add `swift-parser-primitives` dependency.

**Step 5.1: Create ISO 8601 sub-parsers (new files)**

| Parser struct | Composition |
|---------------|-------------|
| `ISO_8601.Parse.Year` | `ASCII.Integer.Decimal<_, Int>` (4 digits for extended, or variable for basic) |
| `ISO_8601.Parse.Month` | `ASCII.Integer.Decimal<_, Int>` (2 digits), validate 1–12 |
| `ISO_8601.Parse.Day` | `ASCII.Integer.Decimal<_, Int>` (2 digits), validate 1–31 |
| `ISO_8601.Parse.Hour` | `ASCII.Integer.Decimal<_, Int>` (2 digits), validate 0–23 |
| `ISO_8601.Parse.Minute` | `ASCII.Integer.Decimal<_, Int>` (2 digits), validate 0–59 |
| `ISO_8601.Parse.Second` | `ASCII.Integer.Decimal<_, Int>` (2 digits), validate 0–60 (leap second) |
| `ISO_8601.Parse.FractionalSeconds` | `OneOf { Byte(0x2E); Byte(0x2C) }`, `Prefix.While(minLength: 1) { isDigit }` |
| `ISO_8601.Parse.TimezoneOffset` | `OneOf { Byte(0x5A)→UTC; Byte(0x2B)/Byte(0x2D) + Hour + Optionally { Byte(0x3A); Minute } }` |
| `ISO_8601.Parse.Date` | Extended: `Year`, `-`, `Month`, `-`, `Day`. Basic: fixed-width digit groups. `OneOf` for calendar/week/ordinal. |
| `ISO_8601.Parse.Time` | `Hour`, `:`, `Minute`, `:`, `Second`, `Optionally { FractionalSeconds }`, `Optionally { TimezoneOffset }` |
| `ISO_8601.Parse.DateTime` | `Date`, `Literal("T")`, `Time` |

**Step 5.2: Duration, Interval, RecurringInterval parsers**

| Parser struct | Composition |
|---------------|-------------|
| `ISO_8601.Parse.Duration` | `Literal("P")`, repeated `{ ASCII.Integer.Decimal; OneOf { Byte(Y/M/D/H/M/S) } }` with `T` separator |
| `ISO_8601.Parse.Interval` | `OneOf { start/end; start/duration; duration/end; duration-only }` with `/` separator |
| `ISO_8601.Parse.RecurringInterval` | `Literal("R")`, `Optionally { ASCII.Integer.Decimal }`, `Literal("/")`, Interval |

**Step 5.3: Rewrite existing parser enums**

The existing `DateTime.Parser`, `Time.Parser`, `Duration.Parser`, `Interval.Parser`, `RecurringInterval.Parser` nested enums are replaced by the combinator structs. The public `init` methods become thin wrappers.

**Basic vs Extended format:** ISO 8601 supports both `2024-01-15` (extended) and `20240115` (basic). Use `Parser.OneOf` at the `Date` level to try extended first (with `-` separators), then basic (fixed-width groups).

**Transitive benefits:**
- RFC 3339 (at `https://github.com/swift-standards/swift-rfc-3339`) delegates to ISO 8601 parsing — benefits automatically.

#### RFC 5322 Date/Time

**Package:** `swift-rfc-5322`
**Path:** `https://github.com/swift-standards/swift-rfc-5322`
**Scope:** 7 working parse functions + 1 stub

Add `swift-parser-primitives` dependency.

| Function | Current | Replacement |
|----------|---------|-------------|
| `DateTime.init(ascii:in:)` | Manual byte-accumulate-flush loop for space-splitting, colon-splitting | `Optionally { DayName; Byte(0x2C) }`, `OWS`, `ASCII.Integer.Decimal` (day), `OWS`, `MonthName`, `OWS`, `ASCII.Integer.Decimal` (year), `OWS`, Time, `OWS`, Timezone |
| `EmailAddress.init(ascii:in:)` | Manual `<`/`>` scanning with enumerated(), quote handling | `OneOf { AngleBracketFormat; BareFormat }` with sub-parsers for display-name, local-part, domain |
| `EmailAddress.LocalPart.init(ascii:in:)` | Manual byte-by-byte with flags | `OneOf { QuotedString; DotAtom }` |
| `Header.init(ascii:in:)`, `Header.Name`, `Header.Value` | `firstIndex(of: colon)`, index walk for folding | `Prefix.While { isFieldNameChar }`, `Byte(0x3A)`, fold-aware value parser |
| `Message.ID.init(ascii:in:)` | Manual angle-bracket + `@` detection | `Byte(0x3C)`, `Prefix.While { $0 != 0x40 }`, `Byte(0x40)`, `Prefix.While { $0 != 0x3E }`, `Byte(0x3E)` |

#### RFC 9557 Timezone Suffix

**Package:** `swift-rfc-9557`
**Path:** `https://github.com/swift-standards/swift-rfc-9557`
**Scope:** 2 parse functions, minimal changes needed (already mostly byte-level)

Only the `split(separator: "-")` in `RFC_9557.Suffix.swift:207` for multi-value tag parsing would change to `Parser.Many.Separated`. Low priority within this phase.

---

### Phase 6: Email/MIME

#### 6A: RFC 5321 SMTP Email

**Package:** `swift-rfc-5321`
**Path:** `https://github.com/swift-standards/swift-rfc-5321`
**Scope:** 2 parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `EmailAddress.init(ascii:in:)` | Angle-bracket detection, `@` split, display name unescaping | `OneOf { AngleBracketFormat; BareFormat }` — similar to RFC 5322 but with SMTP-specific validation |
| `LocalPart.init(ascii:in:)` | Manual byte-by-byte with `insideQuotes`/`escaped` flags | `OneOf { QuotedString; DotAtom }` with SMTP character set |

Add `swift-parser-primitives` dependency.

#### 6B: RFC 2045 Content-Type

**Package:** `swift-rfc-2045`
**Path:** `https://github.com/swift-standards/swift-rfc-2045`
**Scope:** 4 parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `ContentType.init(ascii:in:)` | Semicolon split, solidus split, parameter iteration | `Token`, `Byte(0x2F)`, `Token`, `ParameterList` (can define own or reuse HTTP pattern adapted for MIME) |
| `ContentTransferEncoding.init(ascii:in:)` | Byte-level switch on count + lowercased comparison | `Prefix.While { isVisible }` then `.map { ... }` — already efficient, minimal benefit from combinators |
| `Charset.init(ascii:in:)` | Byte validation + uppercase | `Prefix.While(minLength: 1) { isCharsetChar }` |
| `Parameter.Name.init(ascii:in:)` | Byte validation against tspecials set | `Prefix.While(minLength: 1) { !isTspecial($0) && isVisible($0) }` |

Add `swift-parser-primitives` dependency.

#### 6C: RFC 2183 Content-Disposition

**Package:** `swift-rfc-2183`
**Path:** `https://github.com/swift-standards/swift-rfc-2183`
**Scope:** 3 parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `ContentDisposition.init(ascii:in:)` | Semicolon split, equals split, quote handling, backslash-escape unquoting | `Token` (disposition type), `ParameterList` — reuse MIME parameter parsing from RFC 2045 |
| `Filename.init(ascii:in:)` | Byte validation for path-safety | `Prefix.While { isFilenameChar }` with `.tryMap` for validation |
| `Size.init(ascii:in:)` | `Int(string)` | `ASCII.Integer.Decimal` |

Already depends on RFC 2045 — shared parameter parsing available.

#### 6D: RFC 2388 Form Data

**Package:** `swift-rfc-2388`
**Path:** `https://github.com/swift-standards/swift-rfc-2388`
**Scope:** 1 public + 4 private parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `extractPairs(from:sort:)` | `split("&")` then `split("=", maxSplits: 1)` | `Many.Separated(separator: Byte(0x26)) { Prefix.UpTo([0x3D]); Byte(0x3D); Prefix.While { $0 != 0x26 } }` |
| `extractPath(from:)` | Character-by-character `reduce` for bracket notation | `Many { OneOf { BracketedKey; BareKey } }` |

Lower priority — currently non-throwing (lenient parsing). Combinator rewrite would add structured error reporting.

#### 6E: RFC 2822 Email Format

**Package:** `swift-rfc-2822`
**Path:** `https://github.com/swift-standards/swift-rfc-2822`
**Scope:** 4 working parsers + 1 stub (`Timestamp`)

| Function | Current | Replacement | Notes |
|----------|---------|-------------|-------|
| `AddrSpec.init(ascii:in:)` | Linear scan for last `@` | `OneOf { DotAtom; QuotedString }`, `Byte(0x40)`, `OneOf { DotAtom; DomainLiteral }` | |
| `Mailbox.init(ascii:in:)` | `lastIndex` for angle brackets | `OneOf { AngleBracket { AddrSpec }; AddrSpec }` with optional display name | |
| `Fields.init(ascii:in:)` | Full manual CRLF-folding header parser | `Many { Field }` with fold-aware value parser | Substantial rewrite |
| `Message.init(ascii:in:)` | CRLF+CRLF boundary scan | `Many { Field }`, `Literal("\r\n")`, `Rest` | |
| `Timestamp` | **STUB** — parses `Double`, not date-time | Implement using RFC 5322 `DateTime` parser from Phase 5 | Bug fix, not just adoption |

Add `swift-parser-primitives` dependency.

---

### Phase 7: Security + Standalone Packages

These are leaf packages with no dependents among candidates. Order within this phase is flexible.

#### 7A: RFC 6750 Bearer Tokens — Foundation Elimination

**Package:** `swift-rfc-6750`
**Path:** `https://github.com/swift-standards/swift-rfc-6750`
**Scope:** 4 parse functions, **removes `import Foundation`**

This is the highest-priority Foundation elimination target. The package has `public import Foundation` at line 8 of `RFC_6750.swift`, uses `trimmingCharacters(in:)`, `components(separatedBy:)`, `URLQueryItem`, and `LocalizedError`.

| Function | Current | Replacement |
|----------|---------|-------------|
| `Bearer.parse(from:)` | `trimmingCharacters`, `lowercased().hasPrefix("bearer ")`, `dropFirst(7)` | `OWS`, case-insensitive `Literal("bearer")` or `Literal("Bearer")`, `Byte(0x20)`, `Prefix.While { isTokenChar }` |
| `Bearer.parse(fromFormParameters:)` | Foundation `[String:String]` lookup | Keep as `[String:String]` input — not a parsing operation |
| `Bearer.parse(fromQueryItems:)` | Foundation `[URLQueryItem]` lookup | **Remove** or replace with `[(String, String?)]` parameter |
| `Bearer.Challenge.parse(from:)` | `components(separatedBy: ",")`, `hasPrefix` loops, `extractQuotedValue` | `Literal("Bearer")`, `CommaSeparated { Parameter }` (reuse HTTP shared parsers from Phase 1 via dependency on RFC 9110, or inline) |

**Critical changes:**
1. Remove `import Foundation`
2. Remove `URLQueryItem` from public API (breaking change — allowed per constraints)
3. Remove `LocalizedError` conformance, keep `Swift.Error` + `CustomStringConvertible`
4. Replace `trimmingCharacters(in: .whitespacesAndNewlines)` with byte-level OWS parser
5. Use `ASCII` library's character classification instead of `Character.isASCII`

**Dependencies to add:** `swift-parser-primitives`. Consider also depending on `swift-rfc-9110` for shared HTTP parsers if Challenge parsing reuses the parameter format.

#### 7B: RFC 7617 Basic Auth

**Package:** `swift-rfc-7617`
**Path:** `https://github.com/swift-standards/swift-rfc-7617`
**Scope:** 2 parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `Basic.init(ascii:in:)` | Manual 6-byte prefix check, base64 decode, colon split | Case-insensitive `Literal("basic")`, `Byte(0x20)`, `Prefix.While { isBase64Char }` → base64 decode → `Prefix.UpTo([0x3A])`, `Byte(0x3A)`, `Rest` |
| `Basic.Challenge.init(ascii:in:)` | Mixed byte/String with manual `removeFirst/removeLast` whitespace loops | `Literal("Basic")`, `OWS`, `CommaSeparated { Parameter }` |

Add `swift-parser-primitives` dependency.

#### 7C: RFC 7519 JWT

**Package:** `swift-rfc-7519`
**Path:** `https://github.com/swift-standards/swift-rfc-7519`
**Scope:** 1 parse function

| Function | Current | Replacement |
|----------|---------|-------------|
| `JWT.init(ascii:in:)` | Linear scan with `enumerated()` to find exactly 2 periods | `Prefix.While { $0 != 0x2E }` (header), `Byte(0x2E)`, `Prefix.While { $0 != 0x2E }` (payload), `Byte(0x2E)`, `Rest` (signature) |

Minimal change — the current implementation is already clean. The combinator version is marginally more declarative.

Add `swift-parser-primitives` dependency.

#### 7D: RFC 5646 Language Tags

**Package:** `swift-rfc-5646`
**Path:** `https://github.com/swift-standards/swift-rfc-5646`
**Scope:** 1 public + 6 private parse functions

| Function | Current | Replacement |
|----------|---------|-------------|
| `LanguageTag.init(_:)` | `split(separator: "-")`, walk with index counter, structural predicates | `Many.Separated(separator: Byte(0x2D)) { Prefix.While { $0 != 0x2D } }` then map each subtag through length-based dispatch |

The current implementation is String-level, not byte-level. Moving to byte-level combinators requires converting the entry point from `StringProtocol` to a byte-based `init<Bytes>(ascii:in:)`.

Add `swift-parser-primitives` dependency.

#### 7E: RSS Standard Duration

**Package:** `swift-rss-standard`
**Path:** `https://github.com/swift-standards/swift-rss-standard`
**Scope:** 1 parse function

| Function | Current | Replacement |
|----------|---------|-------------|
| `iTunes.Duration.init?(string:)` | `split(separator: ":")`, `Int()` per component | `Many.Separated(separator: Byte(0x3A)) { ASCII.Integer.Decimal }` then validate 1–3 components |

Add `swift-parser-primitives` dependency.

#### 7F: W3C SVG Path Parser

**Package:** `swift-w3c-svg`
**Path:** `https://github.com/swift-standards/swift-w3c-svg`
**Scope:** ~500 lines of manual parsing, 1 parse entry + helpers

| Function | Current | Replacement |
|----------|---------|-------------|
| `Path.Parser.parse(_:)` | Manual `String.Index` walk, `Character.isLetter/isNumber`, `Double(String)` | `Many { CommandParser }` where `CommandParser = OneOf { M, L, H, V, C, S, Q, T, A, Z }`, each parsing its specific argument pattern |
| `parseNumber()` | Manual digit scan + `Double()` | Could use a dedicated floating-point parser (would need creation at Layer 1) or keep as `Prefix.While { isNumberChar }` + `Double(String.init)` |
| `skipWhitespaceAndCommas()` | Character equality checks | `Prefix.While { isWSOrComma }` (Failure = Never) |

**Foundation elimination:** Removes the dead `import Foundation` at line 8.

**Note:** This package depends on `swift-formatting-primitives` and `swift-geometry-primitives`, not on `swift-ascii`. May need to add `swift-ascii-primitives` if byte-level character classification is needed, or rely on inline predicates.

Add `swift-parser-primitives` dependency.

---

### Phase 8: Domain/IP + Low Priority

These are MEDIUM/LOW priority items. Some packages already have exemplary byte-level implementations (RFC 1035, RFC 4291) that need only a `Parser.Protocol` conformance wrapper rather than a rewrite.

#### 8A: RFC 1035 Domain Names

Already has clean byte-level parsing. Wrap existing logic in `Parser.Parser` conforming struct to enable composition. No functional change needed.

#### 8B: RFC 4291 IPv6 Addresses

Already has clean byte-level parsing. Same approach as RFC 1035 — wrap in `Parser.Parser` conformance.

#### 8C: RFC 5890 IDNA

String-level `split(separator: ".")`. Could use `Many.Separated`, but the larger gap is unimplemented NFC normalization. Defer parser adoption until NFC is addressed.

#### 8D: W3C CSS

Multiple small parsing sites (`split(",")` in font lists, hex color parsing, media queries). Low priority. Defer.

#### 8E: RFC 4122 UUID

Platform-native `uuid_parse` is the fast path. Pure-Swift hex parser is the fallback. LOW priority for combinator adoption.

### Deferred (No Action)

| Package | Reason |
|---------|--------|
| RFC 4648 (Base64/32/16) | Lookup table approach is correct for fixed-alphabet decoding |
| RFC 3492 (Punycode) | State machine algorithm by spec — wrap as `Parser.Protocol` but keep core |
| RFC 1951 (DEFLATE) | Bit-level operations outside byte-level parser scope |
| ISO 32000 (PDF) | Binary format — use Binary Parser Primitives separately |
| ISO 14496-22 (Fonts) | Binary table parsing — use Binary Parser Primitives separately |

---

### Comparison: Before and After

| Metric | Before | After |
|--------|--------|-------|
| Packages using parser-primitives | 3 | ~30 |
| Hand-rolled `.split()` chains | ~45 | ~5 (deferred packages only) |
| `.components(separatedBy:)` calls | ~12 | 0 |
| Manual index advancement sites | ~15 | ~3 (deferred) |
| Foundation imports in standards | 2 (RFC 6750, W3C SVG dead) | 0 |
| `CharacterSet` usage | 1 (RFC 9111 leak) | 0 |
| Duplicate parser implementations | 1 (RFC 3986 Authority) | 0 |
| Shared reusable parser types | 0 | ~25 (HTTP + URI + date sub-parsers) |

### Dependency Graph

```
Phase 0: Parser.ASCII.Integer (Layer 1)
    │
    ├─── Phase 1: RFC 9110 HTTP Shared Parsers
    │        │
    │        ├─── Phase 2: RFC 9111 (Foundation leak fix)
    │        └─── Phase 2: RFC 9112
    │
    ├─── Phase 3: RFC 3986 URI
    │        │
    │        ├─── Phase 4A: WHATWG URL
    │        ├─── Phase 4B: RFC 6570 URI Templates
    │        ├─── Phase 4C: RFC 6068 Mailto
    │        └─── Phase 4D: RFC 2369 List Headers
    │
    ├─── Phase 5: ISO 8601 + RFC 5322 + RFC 9557
    │
    ├─── Phase 6: RFC 5321, RFC 2045, RFC 2183, RFC 2388, RFC 2822
    │
    ├─── Phase 7: RFC 6750 (Foundation removal), RFC 7617, RFC 7519,
    │             RFC 5646, RSS Standard, W3C SVG (Foundation removal)
    │
    └─── Phase 8: RFC 1035, RFC 4291, RFC 5890, W3C CSS, RFC 4122
```

Phases 5, 6, and 7 are independent of each other and can be executed in parallel after Phase 0 completes. Phases 1→2 and 3→4 are sequential chains.

## Outcome

**Status**: RECOMMENDATION

### Conclusions

1. **Phase 0 (ASCII integer parser) is the critical prerequisite.** Without decimal/hexadecimal integer parsing at Layer 1, virtually no standards package can be converted. This is a small, focused deliverable (~4 files) that unblocks everything.

2. **Phase 1 (HTTP shared parsers) has the highest reuse multiplier.** The 8 shared HTTP parser types (`OWS`, `Token`, `QuotedString`, `Parameter`, `ParameterList`, `CommaSeparated`, `QualityValue`) are used by 20+ parse sites across 3 packages and the MIME family.

3. **Phase 5 (ISO 8601) is the highest line-count reduction.** ~500 lines of manual `split`/`prefix`/`dropFirst` date-time parsing replaced by composable integer+separator combinators.

4. **Foundation elimination is a side effect, not a goal.** But it resolves 3 violations: RFC 6750 (`import Foundation`), W3C SVG (dead import), RFC 9111 (`CharacterSet` leak).

5. **Binary format parsing is out of scope.** ISO 14496-22 (fonts) and ISO 32000 (PDF) should use `Binary Parser Primitives`, not text parser combinators. These are separate work items.

6. **Phases 5–7 are parallelizable.** Once Phase 0 lands, ISO 8601, email/MIME, and security packages can be worked on independently. The HTTP chain (Phases 1→2) and URI chain (Phases 3→4) are the only sequential dependencies.

### Estimated Scope

| Phase | New files | Rewritten files | Parse functions affected |
|-------|-----------|-----------------|------------------------|
| 0 | ~4 | 0 | 0 (new infrastructure) |
| 1 | ~8 | 7 | 30 |
| 2 | 0 | 12 | 14 |
| 3 | ~10 | 8 | 9+ |
| 4 | ~4 | 8 | ~12 |
| 5 | ~12 | 10 | ~24 |
| 6 | ~5 | 10 | ~16 |
| 7 | ~6 | 8 | ~12 |
| 8 | ~2 | 4 | ~6 |
| **Total** | **~51** | **~67** | **~123** |

## References

- [parsers-ecosystem-adoption-audit.md](parsers-ecosystem-adoption-audit.md) — Audit identifying 95 adoption opportunities
- RFC 8259 `ParserPrinter.Prototype` — `https://github.com/swift-standards/swift-rfc-8259/blob/main/Sources/RFC 8259/RFC_8259.ParserPrinter.Prototype.swift`
- W3C XML parser (most advanced adoption) — `https://github.com/swift-standards/swift-w3c-xml/blob/main/Sources/W3C XML/W3C_XML.Parse.*.swift`
- Parser Primitives API — `https://github.com/swift-primitives/swift-parser-primitives/tree/main/Sources/`
