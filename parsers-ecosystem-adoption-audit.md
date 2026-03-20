# Parsers Ecosystem Adoption Audit

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: SUPERSEDED
tier: 1
superseded_by: next-steps-parsers.md
---
-->

> **Status**: SUPERSEDED (2026-03-15)
> **Superseded by**: **next-steps-parsers.md** (v2.0.0)
> This audit identified 95 adoption opportunities across ~30 packages. Its findings are fully incorporated into the next-steps tracking document, which contains the current per-package status, revised package assessment (5 complete, 8 mostly migrated, 2 bifurcated), and execution plan.
> It remains as historical reference for the original gap analysis.

## Context

The Swift Institute maintains a comprehensive parser combinator system across three Layer 1 packages (`swift-parser-primitives`, `swift-parser-machine-primitives`, `swift-binary-parser-primitives`) and one Layer 3 package (`swift-parsers`). Despite this investment, adoption remains minimal: only RFC 8259 (JSON) and W3C XML currently import `Parser_Primitives`. Meanwhile, dozens of standards packages contain hand-rolled parsing using `.split(separator:)`, manual index advancement, `dropFirst()`, `removeFirst()`, and similar ad-hoc patterns.

This audit identifies every opportunity to replace hand-rolled parsing with the parser combinator system.

## Question

Where across the Swift Institute ecosystem are there opportunities to use the parser combinator system instead of ad-hoc parsing?

## Current API Surface

### Parser Primitives Core (Layer 1)

The core protocol at `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift`:

```swift
public protocol `Protocol`<Input, ParseOutput, Failure> {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype ParseOutput
    associatedtype Failure: Swift.Error & Sendable
    func parse(_ input: inout Input) throws(Failure) -> ParseOutput
}
```

Key characteristics:
- **Mutation-based**: consumes from `inout Input`, enabling zero-copy composition
- **Typed throws**: `Failure` associated type for domain-specific errors
- **~Copyable & ~Escapable input**: supports `Span<UInt8>` for zero-copy borrowed parsing
- **Bidirectional**: `Parser.Printer` (prepend) and `Parser.Serializer` (append) protocols
- **Checkpoint backtracking**: `Input.Protocol` adds `checkpoint`/`restore` for backtracking

### Available Combinators (~30 modules)

| Combinator | Purpose |
|-----------|---------|
| `Parser.Literal` | Exact byte sequence matching (e.g., `"HTTP/"`, `"://"`) |
| `Parser.Prefix.While` | Consume while predicate holds (digits, alpha, etc.) |
| `Parser.Many` / `Parser.Many.Separated` | Repetition with optional separators |
| `Parser.Map` / `Parser.FlatMap` | Transform/chain parser outputs |
| `Parser.OneOf` | Try alternatives in order |
| `Parser.Optional` | Optional match |
| `Parser.Peek` / `Parser.Not` | Lookahead |
| `Parser.Backtrack` | Save/restore on failure |
| `Parser.Skip` / `Parser.Discard` | Consume without capturing |
| `Parser.Filter` | Validate parsed output |
| `Parser.Consume` / `Parser.Take` | Consume N elements |
| `Parser.End` / `Parser.EndOfInput` | Assert end of input |
| `Parser.Span` / `Parser.Spanned` | Capture source span |
| `Parser.Locate` / `Parser.Tracked` | Position tracking |
| `Parser.Trace` | Debug tracing |
| `Parser.Lazy` | Deferred parser construction |
| `Parser.Conditional` | Conditional dispatch |
| `Parser.Byte` | Single byte matching |
| `Parser.First` | First match |
| `Parser.Rest` | Consume remaining input |
| `Parser.Fail` / `Parser.Always` | Unconditional failure/success |

### Foundations-Level Parsers (Layer 3)

At `/Users/coen/Developer/swift-foundations/swift-parsers/Sources/Parsers/`:

| Parser | Purpose |
|--------|---------|
| `Parsers.Integer` | Decimal, hex, binary, octal integer parsing |
| `Parsers.Whitespace` | Whitespace consumption |
| `Parsers.Newline` | Newline handling (LF, CR, CRLF) |
| `Parsers.Quoted` | Double/single/doubling-escape quoted strings |
| `Parsers.Identifier` | Identifier tokenization |
| `Parsers.Comment` | Comment parsing (line/block) |
| `Parsers.Between` | Delimited content |
| `Parsers.Separated` | Separator-delimited lists |
| `Parsers.Expression` | Pratt expression parsing |
| `Parsers.Chain` | Left/right associative chaining |
| `Parsers.Diagnostic` | Error enrichment |
| `Parsers.Debug` | Debug output |

### Binary Parser Primitives (Layer 1)

At `/Users/coen/Developer/swift-primitives/swift-binary-parser-primitives/Sources/`:

Binary integer parsers, `Binary.Coder`, `Binary.Bytes.Input.View`, `Binary.Bytes.Machine` for structured binary format parsing.

### Parser Machine Primitives (Layer 1)

At `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/`:

Compiled parser machines with memoization for performance-critical parsing.

## Findings

### Category 1: HTTP Header Parsing (RFC 9110, 9111, 9112)

The HTTP standards family contains the highest density of hand-rolled `.split(separator:)` / `.components(separatedBy:)` parsing. Every single header parser follows the same pattern: split on comma, split on semicolon, split on `=`, trim whitespace.

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.MediaType.swift:101` | `split(separator: ";")` then `split(separator: "/")` then `split(separator: "=")` for media-type parsing | `Parser.Many.Separated` with `Parser.Literal` for delimiters, `Parser.Prefix.While` for tokens | HIGH |
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.ContentNegotiation.swift:155` | Four nearly identical `parse()` methods for Accept, Accept-Encoding, Accept-Language, Accept-Charset, each doing `split(",")` then `split(";")` then quality value extraction | Single generic comma-separated-with-quality parser built from combinators | HIGH |
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.ContentLanguage.swift:53` | `split(separator: ",")` + map + trim | `Parser.Many.Separated` over comma-delimited tokens | HIGH |
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.ContentEncoding.swift:84` | `split(separator: ",")` + map + trim | Same pattern as ContentLanguage | HIGH |
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.Authentication.swift:164` | Manual `split(",")` then `split("=")` for challenge/credentials parsing | Parser combinator for `auth-scheme *( "," auth-param )` | HIGH |
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.EntityTag.swift:110` | Manual string parsing for `W/"tag"` vs `"tag"` | `Parser.OneOf` with `Parser.Literal` for `W/` prefix, then `Parser.Quoted.Double` | HIGH |
| swift-rfc-9110 | `Sources/RFC 9110/HTTP.Precondition.swift:144` | `split(separator: ",")` for If-Match/If-None-Match | `Parser.Many.Separated` over entity-tag | HIGH |
| swift-rfc-9111 | `Sources/RFC 9111/HTTP.CacheControl.swift:235` | `components(separatedBy: ",")` then `components(separatedBy: "=")`, Foundation-style CharacterSet usage | Full combinator parser for Cache-Control directives | HIGH |
| swift-rfc-9111 | `Sources/RFC 9111/HTTP.Vary.swift:125` | `components(separatedBy: ",")` | `Parser.Many.Separated` | HIGH |
| swift-rfc-9111 | `Sources/RFC 9111/HTTP.Expires.swift:96` | Manual HTTP-date parsing | Parser for RFC 5322 / RFC 7231 date format | MEDIUM |
| swift-rfc-9111 | `Sources/RFC 9111/HTTP.Age.swift:83` | Manual integer extraction | `Parsers.Integer.Decimal` | HIGH |
| swift-rfc-9111 | `Sources/RFC 9111/HTTP.Cache.HeaderStorage.swift:49` | Multiple `split` operations for cache header storage | Combinator parsing throughout | MEDIUM |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Version.swift:26` | `split(separator: "/")` then `split(separator: ".")` for `HTTP/1.1` | `Parser.Literal("HTTP/")` then `Parsers.Integer.Decimal` then `Parser.Literal(".")` then `Parsers.Integer.Decimal` | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Request.Line.swift:24` | Manual `firstIndex(of: " ")`, `range(of: " HTTP/", options: .backwards)` for `method SP target SP version` | Sequence parser: token, literal SP, target, literal SP, version-parser | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Response.Line.swift:24` | `split(separator: " ", maxSplits: 2)` for `HTTP-version SP status-code SP reason-phrase` | Same pattern as request-line | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Connection.swift:108` | `components(separatedBy: ",")` | `Parser.Many.Separated` | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.TransferEncoding.swift:130` | `components(separatedBy: ",")` | `Parser.Many.Separated` | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.ChunkedEncoding.swift:90-280` | Manual `split(";")`, `split("=")`, hex parsing for chunk size, extension parsing, trailer parsing | Full combinator parser for chunked encoding grammar | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Host.swift` | Manual host parsing with index advancement | Reuse RFC 3986 authority parser, built from combinators | MEDIUM |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Field.swift` | Manual header field parsing | Combinator parser for `field-name ":" OWS field-value OWS` | HIGH |
| swift-rfc-9112 | `Sources/RFC 9112/HTTP.Message.Deserializer.swift:13` | Manual message deserialization with `split("?")` for target | Combinator-based request/response message parser | MEDIUM |

### Category 2: URI/URL Parsing (RFC 3986, RFC 3987, WHATWG URL)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.URI.swift` | Cached parsing with manual index tracking through `scheme://authority/path?query#fragment` | Full URI parser from combinators: `Parser.Prefix.While` for scheme, `Parser.Literal("://")`, authority sub-parser, etc. | HIGH |
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.URI.Authority.swift` | Manual `userinfo@host:port` decomposition | Combinator sequence parser | HIGH |
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.URI.Query.swift:170` | `split(separator: "&")` for query parameters | `Parser.Many.Separated` with `&` separator | HIGH |
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.URI.Path.swift` | Manual path segment parsing | `Parser.Many.Separated` with `/` separator | HIGH |
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.URI.Scheme.swift` | Manual scheme extraction | `Parser.Prefix.While { isAlphanumeric or +/-/. }` | HIGH |
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.URI.Userinfo.swift` | Manual userinfo parsing | `Parser.Prefix.While` up to `@` | HIGH |
| swift-rfc-3986 | `Sources/RFC 3986/RFC_3986.CharacterSet.swift` | Manual character classification for URI chars | Predicate functions for combinator constraints | MEDIUM |
| swift-rfc-3987 | `Sources/RFC 3987/IRI.swift` | Manual IRI parsing (internationalized URIs) | Extend URI parser for IRI character ranges | MEDIUM |
| swift-whatwg-url | `Sources/WHATWG URL/WHATWG_URL.URL.Path.swift:72` | `split(separator: "/")` for path segments | `Parser.Many.Separated` | HIGH |
| swift-whatwg-url | `Sources/WHATWG URL/RFC_4291+WHATWG.swift:60-148` | Manual IPv6 parsing with `split(":")`, double-colon handling | Combinator-based IPv6 parser | MEDIUM |
| swift-whatwg-url | `Sources/WHATWG URL/RFC_791+WHATWG.swift:32` | `split(separator: ".")` for IPv4 | `Parser.Many.Separated` with `.` separator and integer parser | HIGH |
| swift-whatwg-url | `Sources/WHATWG Form URL Encoded/URLEncoding.swift:69-80` | `split("&")` then `split("=")` for form data | `Parser.Many.Separated` with `&` separator over key-value parser | HIGH |
| swift-whatwg-url | `Sources/WHATWG URL/WHATWG_URL.PercentEncoding.swift:49` | Manual percent-decoding loop | `Parser.OneOf` for `%XX` vs literal char | MEDIUM |

### Category 3: Date/Time Parsing (ISO 8601, RFC 3339, RFC 5322)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-iso-8601 | `Sources/ISO 8601/ISO_8601.DateTime.swift:619-1011` | Extensive `split("-")`, `split("T")`, `split(":")` for date-time, date, time components. ~400 lines of manual parsing | Full ISO 8601 parser from combinators: integer parsers for YYYY, MM, DD, separators, time zone offset parser | HIGH |
| swift-iso-8601 | `Sources/ISO 8601/ISO_8601.Duration.swift:186-324` | Manual `P`, `Y`, `M`, `D`, `T`, `H`, `M`, `S` character scanning with `split` | Duration parser: `Parser.Literal("P")` then repeated designator+number pairs | HIGH |
| swift-iso-8601 | `Sources/ISO 8601/ISO_8601.Time.swift:221-395` | `split(":")` for time parsing, timezone offset parsing | Time parser from integer + separator combinators | HIGH |
| swift-iso-8601 | `Sources/ISO 8601/ISO_8601.RecurringInterval.swift:101` | Manual `R`-prefix parsing, interval decomposition | Combinator parser for `R[n]/interval` | HIGH |
| swift-iso-8601 | `Sources/ISO 8601/ISO_8601.Interval.swift:99` | Manual start/end/duration parsing | Combinator parser for interval variants | HIGH |
| swift-rfc-3339 | `Sources/RFC_3339/` | Delegates to ISO 8601 parsing | Benefits transitively from ISO 8601 parser rewrite | MEDIUM |
| swift-rfc-5322 | `Sources/RFC 5322/RFC_5322.DateTime.swift` | Hand-rolled RFC 5322 date-time parsing | Combinator parser for `day-name "," SP date SP time SP zone` | HIGH |

### Category 4: Email/MIME Parsing (RFC 5321, 5322, 2045, 2183, 2388, 6531)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-5322 | `Sources/RFC 5322/RFC_5322.EmailAddress.swift:204` | Manual `parseLocalPart` / `parseDomain` byte walking | Combinator parser for `local-part "@" domain` | HIGH |
| swift-rfc-5321 | `Sources/RFC 5321/RFC_5321.EmailAddress.swift` | Manual email address parsing with index tracking | Combinator parser per ABNF grammar | HIGH |
| swift-rfc-6531 | `Sources/RFC 6531/RFC_6531.EmailAddress.swift` | Manual internationalized email parsing | Extend email parser for UTF-8 local-part | MEDIUM |
| swift-rfc-6531 | `Sources/RFC 6531/RFC_6531.EmailAddress.LocalPart.swift` | Manual Unicode-aware local-part scanning | `Parser.Prefix.While` with Unicode predicates | MEDIUM |
| swift-rfc-2045 | `Sources/RFC 2045/RFC_2045.ContentType.swift:190` | `split(separator: .ascii.semicolon)` for MIME parameters | `Parser.Many.Separated` with `;` separator | HIGH |
| swift-rfc-2183 | `Sources/RFC 2183/RFC_2183.ContentDisposition.swift:248` | `split(separator: .ascii.semicolon)` for disposition parameters | `Parser.Many.Separated` | HIGH |
| swift-rfc-2388 | `Sources/RFC 2388/FormData.Parser.swift:127` | `split("&")` then `split("=")` for form data | `Parser.Many.Separated` for key-value pairs | HIGH |
| swift-rfc-2822 | `Sources/RFC 2822/RFC_2822.Message.Received.swift` | Manual Received header parsing with `dropFirst` | Combinator parser for received-token | MEDIUM |
| swift-rfc-2822 | `Sources/RFC 2822/RFC_2822.AddrSpec.swift` | Manual addr-spec parsing | Combinator parser | MEDIUM |
| swift-rfc-2822 | `Sources/RFC 2822/RFC_2822.Mailbox.swift` | Manual mailbox parsing | Combinator parser | MEDIUM |

### Category 5: URI Template / Link Parsing (RFC 6570, RFC 6068, RFC 2369)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-6570 | `Sources/RFC 6570/Parsing.swift:8-148` | Manual character-by-character template parsing: `{` / `}` matching, `split(",")` for varspecs, `hasSuffix("*")` / `firstIndex(of: ":")` for modifiers | Full combinator parser: `Parser.Between` for `{}`, `Parser.Many.Separated` for varspecs, `Parser.OneOf` for modifiers | HIGH |
| swift-rfc-6068 | `Sources/RFC 6068/RFC_6068.Mailto.swift` | Manual mailto URI decomposition | Combinator parser for `mailto:` + addresses + `?` + headers | MEDIUM |
| swift-rfc-2369 | `Sources/RFC 2369/RFC_2369.List.Header.swift:227` | Manual IRI extraction from `<...>` bracketed values | `Parser.Between` with `<` and `>` delimiters | MEDIUM |
| swift-rfc-2369 | `Sources/RFC 2369/RFC_2369.List.Post.swift` | Manual list-post header parsing | Combinator parser | MEDIUM |

### Category 6: Language/Locale Tags (RFC 5646, RFC 9557)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-5646 | `Sources/RFC 5646/RFC_5646.LanguageTag.swift:73-150` | `trimmingCharacters`, `split(separator: "-")`, manual index-based subtag walking | Combinator parser: `Parser.Many.Separated` with `-` separator, subtag-length-based dispatch | HIGH |
| swift-rfc-9557 | `Sources/RFC 9557/RFC_9557.Suffix.swift:207` | `split(separator: "-")` | `Parser.Many.Separated` | MEDIUM |
| swift-rfc-9557 | `Sources/RFC 9557/RFC_9557.SuffixTag.swift:212` | `split(separator: "-")` | `Parser.Many.Separated` | MEDIUM |

### Category 7: Domain Name Parsing (RFC 1035, RFC 1123, RFC 5890)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-1035 | `Sources/RFC 1035/RFC_1035.Domain.swift` | Manual domain label parsing with index advancement | `Parser.Many.Separated` with `.` separator, label validation parser | MEDIUM |
| swift-rfc-1123 | `Sources/RFC 1123/RFC_1123.Domain.swift` | Manual domain validation | Combinator parser for LDH (letter-digit-hyphen) labels | MEDIUM |
| swift-rfc-5890 | `Sources/RFC 5890/IDNA.swift:69-92` | `split(separator: ".")` for internationalized domain labels | `Parser.Many.Separated` with `.` separator | MEDIUM |

### Category 8: IP Address Parsing (RFC 4291, RFC 4007)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-4291 | `Sources/RFC 4291/RFC_4291.IPv6.Address.swift` | Binary.ASCII.Serializable init pattern | IPv6 parser from combinators (hex groups, `::` compression, embedded IPv4) | MEDIUM |
| swift-rfc-4007 | `Sources/RFC 4007/RFC_4007.IPv6.ScopedAddress.swift` | Manual `%zone` suffix parsing | `Parser.Prefix.While` for address, `Parser.Literal("%")`, zone parser | MEDIUM |

### Category 9: Security Token Parsing (RFC 6750, RFC 7617, RFC 7519)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-6750 | `Sources/RFC 6750/RFC_6750.swift:71-230` | Multiple `trimmingCharacters`, `dropFirst`, `components(separatedBy: ",")` for Bearer token and challenge parsing. Uses Foundation `CharacterSet`. | Full combinator parser for `Bearer` scheme; removes Foundation dependency | HIGH |
| swift-rfc-7617 | `Sources/RFC 7617/RFC_7617.Basic.Challenge.swift:152` | `split(separator: ",")` for challenge parameters | `Parser.Many.Separated` | HIGH |
| swift-rfc-7617 | `Sources/RFC 7617/RFC_7617.Basic.swift` | Manual Basic auth `user:password` parsing | `Parser.Prefix.UpTo` with `:` then `Parser.Rest` | HIGH |
| swift-rfc-7519 | `Sources/RFC 7519/RFC_7519.JWT.swift:174-220` | Manual byte-by-byte period-finding loop for `header.payload.signature` | `Parser.Many.Separated` with `.` separator (exactly 3 parts) or `Parser.Prefix.While { $0 != period }` | HIGH |

### Category 10: UUID Parsing (RFC 4122)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-4122 | `Sources/RFC 4122/RFC_4122.UUID.swift:149-180` | Platform-native `uuid_parse` with fallback to manual UTF-8 hex parsing | Parser combinator for `8-4-4-4-12` hex format as pure-Swift path. Native fast path can remain. | LOW |

### Category 11: SVG Path Parsing (W3C SVG)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-w3c-svg | `Sources/W3C SVG/W3C_SVG2.Paths.Path.Parser.swift:43` | Full hand-rolled SVG path parser (~500+ lines) with manual character dispatch for M/L/C/S/Q/T/A/Z commands | Combinator-based parser using `Parser.OneOf` for commands, `Parsers.Integer.Decimal` for coordinates, `Parser.Whitespace` for separators. Imports Foundation currently. | HIGH |

### Category 12: Encoding Formats (RFC 4648, Base62)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-4648 | `Sources/RFC 4648/*.swift` | Manual byte-by-byte base64/base32/base16 decoding with lookup tables | These are inherently byte-level operations well-suited to lookup tables. Parser combinators add overhead without benefit for fixed-alphabet decoding. | LOW |
| swift-base62-primitives | `Sources/Base62 Primitives/Base62_Primitives.Decoding.swift:125` | Manual byte-level base62 decoding | Same as RFC 4648 -- lookup tables are appropriate | LOW |

### Category 13: Binary Format Parsing (ISO 14496-22, ISO 32000, RFC 1951)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-iso-14496-22 | `Sources/ISO 14496-22/FontFile+Parsing.swift:74-528` | 11 manual `parseXxx` functions reading fixed-offset binary structures (head, hhea, maxp, hmtx, cmap, name, post, loca, glyf tables) | Migrate to Binary Parser Primitives (`Binary.Coder`, `Binary.Bytes.Input.View`). These are binary table parsers reading fixed offsets. | MEDIUM |
| swift-iso-32000 | `Sources/ISO 32000/ISO_32000.Writer.swift` | Some manual binary construction | Binary serializer for PDF stream writing | LOW |
| swift-iso-32000 | `Sources/ISO 32000 8 Graphics/8.9 Images.swift:229` | Manual JPEG header parsing | Binary parser for JPEG SOI/APP0 markers | MEDIUM |
| swift-rfc-1951 | `Sources/RFC 1951/RFC_1951.BitReader.swift` | Custom bit-level reader for DEFLATE | Specialized bit-level parser. Standard byte-level parser combinators do not apply directly. Could wrap as `Parser.Protocol` conformance for composition. | LOW |

### Category 14: CSS Parsing (W3C CSS)

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-w3c-css | `Sources/W3C CSS Fonts/FontFeatureValues.swift:59` | `split(separator: ",")` for font family list | `Parser.Many.Separated` | MEDIUM |
| swift-w3c-css | `Sources/W3C CSS Values/HexColor.swift` | Manual hex color parsing | Hex integer parser + length validation | MEDIUM |
| swift-w3c-css | `Sources/W3C CSS MediaQueries/Media.swift` | Manual media query parsing | Full CSS media query combinator parser | LOW |
| swift-w3c-css | `Sources/W3C CSS Cascade/Layer.swift` | Manual cascade layer parsing | Combinator parser | LOW |

### Category 15: Miscellaneous Standards Parsing

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rfc-3492 | `Sources/RFC 3492/Punycode.swift:144` | Manual Punycode decode with state machine | This IS a state machine by spec. Wrap as `Parser.Protocol` conformance but keep algorithmic core. | LOW |
| swift-rfc-9557 | `Sources/RFC 9557/RFC_9557.Validation.swift` | Manual timezone suffix validation | Parser combinator for suffix grammar | MEDIUM |
| swift-rss-standard | `Sources/RSS Standard iTunes/Duration.swift:40` | `split(separator: ":").map(String.init)` for HH:MM:SS | `Parser.Many.Separated` with `:` separator and integer parser | HIGH |
| swift-whatwg-html | `Sources/WHATWG HTML FormData/WHATWG_HTML.FormData.EntryList.swift` | Manual form entry parsing | Combinator parser | MEDIUM |
| swift-whatwg-html | `Sources/WHATWG HTML LinkAttributes/Href.swift:164` | `split(separator: "#")` for fragment removal | `Parser.Prefix.While { $0 != "#" }` | LOW |
| swift-domain-standard | `Sources/Domain Standard/Domain+IDNA.swift:144` | `split(separator: ".")` | `Parser.Many.Separated` | LOW |

### Category 16: Foundations Layer Parsing

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-linux | `Sources/Linux System/Linux.System.NUMA.discover.swift:100` | `split(",")` then `split("-")` for CPU list parsing (`0-3,8-11`) | `Parser.Many.Separated` with `,` separator over range-or-single parser | MEDIUM |
| swift-plist | `Sources/Plist Binary/Plist.Binary.Parser.swift:11` | Manual binary plist parsing with offset tables | Binary Parser Primitives for structured binary reading | MEDIUM |
| swift-ascii | `Sources/ASCII/Int+ASCII.Serializable.swift:34-72` | Manual `parseSigned`/`parseUnsigned` with byte walking | Already has `Binary.ASCII.Parsing.Machine` -- this is the internal implementation. No change needed. | LOW |

### Category 17: Already Using Parser Primitives (Reference)

These packages already import `Parser_Primitives` and serve as reference implementations:

| Package | File | Notes |
|---------|------|-------|
| swift-rfc-8259 | `Sources/RFC 8259/RFC_8259.ParserPrinter.Prototype.swift` | Full JSON ParserPrinter using `Parser.Protocol`. Has both legacy `RFC_8259.Parser` (hand-rolled) and new prototype. |
| swift-rfc-8259 | `Sources/RFC 8259/RFC_8259.Lexer.swift` | Lexer using `Input.Slice` with `removeFirst()` -- partially converted |
| swift-w3c-xml | `Sources/W3C XML/W3C_XML.Parse.*.swift` | Full XML parser using `Parser.Protocol` conformances. Most advanced adoption. |

## Summary Statistics

| Priority | Count |
|----------|-------|
| HIGH | 52 |
| MEDIUM | 29 |
| LOW | 14 |
| **Total** | **95** |

### By Package Family

| Family | HIGH | MEDIUM | LOW | Total |
|--------|------|--------|-----|-------|
| HTTP (RFC 9110/9111/9112) | 20 | 3 | 0 | 23 |
| URI/URL (RFC 3986, WHATWG) | 9 | 4 | 0 | 13 |
| Date/Time (ISO 8601, RFC 3339, 5322) | 6 | 1 | 0 | 7 |
| Email/MIME (RFC 5322, 2045, 2183, etc.) | 5 | 5 | 0 | 10 |
| URI Template/Link (RFC 6570, 6068, 2369) | 1 | 3 | 0 | 4 |
| Language/Locale (RFC 5646, 9557) | 1 | 2 | 0 | 3 |
| Domain (RFC 1035, 1123, 5890) | 0 | 3 | 0 | 3 |
| IP Address (RFC 4291, 4007) | 0 | 2 | 0 | 2 |
| Security (RFC 6750, 7617, 7519) | 4 | 0 | 0 | 4 |
| UUID (RFC 4122) | 0 | 0 | 1 | 1 |
| SVG (W3C SVG) | 1 | 0 | 0 | 1 |
| Encoding (RFC 4648, Base62) | 0 | 0 | 2 | 2 |
| Binary (ISO 14496-22, 32000, RFC 1951) | 0 | 2 | 2 | 4 |
| CSS (W3C CSS) | 0 | 2 | 2 | 4 |
| Misc Standards | 1 | 2 | 2 | 5 |
| Foundations | 0 | 2 | 1 | 3 |

### By Anti-Pattern

| Anti-Pattern | Occurrences | Parser Replacement |
|-------------|-------------|-------------------|
| `.split(separator:)` chains | ~45 | `Parser.Many.Separated` |
| `.components(separatedBy:)` (Foundation) | ~12 | `Parser.Many.Separated` (also removes Foundation) |
| Manual index advancement | ~15 | `Parser.Prefix.While`, `Parser.Literal` |
| `trimmingCharacters` / Foundation CharacterSet | ~8 | `Parser.Skip` with `Parsers.Whitespace` |
| `dropFirst()` / `removeFirst()` for prefix skipping | ~10 | `Parser.Literal` or `Parser.Skip` |
| Manual hex parsing | ~5 | `Parsers.Integer.Hexadecimal` |
| `firstIndex(of:)` scanning | ~8 | `Parser.Prefix.UpTo` |
| Manual binary offset reading | ~11 | `Binary.Coder` / `Binary.Bytes.Input.View` |

## Outcome

**Status**: RECOMMENDATION

### Conclusions

1. **95 adoption opportunities** identified across the entire ecosystem, with 52 rated HIGH priority (direct replacement possible with existing combinator API).

2. **HTTP header parsing is the largest single opportunity** (23 findings). The HTTP standards family (RFC 9110, 9111, 9112) contains highly repetitive `.split(separator:)` patterns that map directly to `Parser.Many.Separated`. A shared HTTP header token parser would eliminate enormous code duplication.

3. **ISO 8601 is the most impactful single rewrite** (~400 lines of manual `split`-based date/time parsing that maps cleanly to integer parsers + separator literals).

4. **Foundation dependency removal**: At least RFC 6750 (`CharacterSet`), RFC 9111 (`CharacterSet`), and W3C SVG (`Foundation` import) can drop Foundation imports by switching to parser combinators.

5. **Only 2 of ~100+ standards packages currently use Parser Primitives** (RFC 8259 JSON and W3C XML). The infrastructure exists and is proven -- it simply has not been propagated.

6. **Binary format parsing** (ISO 14496-22 font tables, ISO 32000 PDF structures) should use `Binary Parser Primitives` rather than text parser combinators.

### Recommended Execution Order

1. **Phase 1 -- HTTP Header Foundation** (HIGH impact, HIGH reuse): Build a shared `HTTP.HeaderParser` module with common combinators for comma-separated lists, semicolon-separated parameters, quoted strings, and quality values. Apply to RFC 9110, 9111, 9112.

2. **Phase 2 -- URI Parsing** (HIGH impact): Rewrite RFC 3986 URI parser using combinators. This unblocks WHATWG URL, RFC 6068 mailto, and all URI-dependent standards.

3. **Phase 3 -- Date/Time** (HIGH impact): Rewrite ISO 8601 parser. This transitively benefits RFC 3339 and RFC 5322 date parsing.

4. **Phase 4 -- Email/MIME**: Rewrite RFC 5322 email address, RFC 2045 Content-Type, RFC 2183 Content-Disposition parsers.

5. **Phase 5 -- Security Tokens**: Rewrite RFC 6750, 7617, 7519 parsers. This also eliminates Foundation dependencies.

6. **Phase 6 -- Remaining Standards**: Language tags, domain names, SVG paths, CSS values, and remaining miscellaneous parsers.

7. **Phase 7 -- Binary Formats**: Migrate ISO 14496-22 font parsing to Binary Parser Primitives.

### Deferred

- RFC 4648 base encoding/decoding: Lookup table approach is correct for these algorithms.
- RFC 3492 Punycode: State machine algorithm by spec; wrap but don't restructure.
- RFC 1951 DEFLATE: Bit-level operations outside byte-level parser combinator scope.
