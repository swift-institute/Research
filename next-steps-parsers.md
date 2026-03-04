# Next Steps: Parsers Ecosystem Adoption

<!--
---
version: 2.0.0
last_updated: 2026-03-04
status: IN_PROGRESS
source: adoption-implementation-review.md, parsers-ecosystem-adoption-audit.md
---
-->

## Status After First Pass

**Infrastructure:** `Parser.ASCII.Integer` module added to swift-parser-primitives.

**New parsers added (18 packages, all PARTIAL):** Parser combinator implementations were written in 18 standards packages but sit alongside the old hand-rolled code without replacing it. The old `.split()`, `.components(separatedBy:)`, and manual index-advancement code remains at all call sites.

**Fully done (1):** RFC 6750 Foundation removal (byte-level, not via combinators).

**Not started (57+ items):** RFC 9112 (9 HIGH items), RFC 3987, RFC 5890, RFC 1035, RFC 1123, RFC 4291, RFC 4007, RFC 6531, ISO 14496-22, W3C CSS, WHATWG HTML, Linux NUMA, plist, and more.

## Task 1: Replacement Pass — Wire New Parsers Into Existing APIs

This is the highest-priority task. 18 packages have new parser combinator implementations that are NOT wired into the public API. The old hand-rolled code must be replaced.

### Strategy

Use RFC 3986 as the template — it has the most complete integration (old `.split()` reduced to 1 occurrence). For each package:

1. Find the public `init(parsing:)` or `parse(_:)` or `init(_ string:)` entry point
2. Replace the body with a call to the new parser combinator
3. Remove the old `.split()`-based implementation
4. Remove any Foundation imports that become unused (`CharacterSet`, `components(separatedBy:)`)
5. Build and run tests

### Package-by-package checklist

Work in dependency order: shared parsers first, then consumers.

#### Tier 1: Shared infrastructure (do first)

| Package | New Parsers | Old Code Location | Action |
|---------|-------------|-------------------|--------|
| **swift-rfc-9110** | 8 files: OWS, Token, QuotedString, Parameter, ParameterList, CommaSeparated, QualityValue | `HTTP.MediaType.swift:101`, `HTTP.ContentNegotiation.swift:155`, `HTTP.ContentLanguage.swift:53`, `HTTP.ContentEncoding.swift:84`, `HTTP.Authentication.swift:164`, `HTTP.EntityTag.swift:110`, `HTTP.Precondition.swift:144` | Replace all `split(separator:)` calls (17 occurrences in 6 files) with new parsers. These are reusable building blocks — get them right. |

```bash
cd /Users/coen/Developer/swift-standards/swift-rfc-9110 && swift build && swift test
```

#### Tier 2: URI (unblocks many dependents)

| Package | New Parsers | Old Code Location | Action |
|---------|-------------|-------------------|--------|
| **swift-rfc-3986** | 10 files: Scheme, PercentEncoded, Port, Userinfo, Host, PathSegments, Query, Fragment, Authority | `RFC_3986.URI.swift`, `*.Authority.swift`, `*.Query.swift:170`, `*.Path.swift`, `*.Scheme.swift`, `*.Userinfo.swift` | Down to 1 remaining `.split()` — find and eliminate it. Verify all public inits delegate to combinators. |

```bash
cd /Users/coen/Developer/swift-standards/swift-rfc-3986 && swift build && swift test
```

#### Tier 3: Date/Time

| Package | New Parsers | Old Code Location | Action |
|---------|-------------|-------------------|--------|
| **swift-iso-8601** | 12 files: CalendarDate, DateTime, Duration, Interval, RecurringInterval, TimeOfDay, TimezoneOffset, WeekDate, OrdinalDate, Digits, Error | `ISO_8601.DateTime.swift:619-1011` (~400 lines), `ISO_8601.Duration.swift:186-324`, `ISO_8601.Time.swift:221-395`, `ISO_8601.RecurringInterval.swift:101`, `ISO_8601.Interval.swift:99` | Remove 12 `.split()` occurrences across 4 files. Replace init bodies with combinator calls. |

```bash
cd /Users/coen/Developer/swift-standards/swift-iso-8601 && swift build && swift test
```

#### Tier 4: Email/MIME

| Package | New Parsers | Action |
|---------|-------------|--------|
| **swift-rfc-5322** | DateTime, MessageID | Wire into existing parse entry points |
| **swift-rfc-2045** | ContentType | Replace `split(separator: .ascii.semicolon)` at line 190 |
| **swift-rfc-2183** | ContentDisposition | Replace `split(separator: .ascii.semicolon)` at line 248 |
| **swift-rfc-5321** | EmailAddress | Wire into init |
| **swift-rfc-2822** | EmailAddress parsers | Wire into AddrSpec, Mailbox |
| **swift-rfc-2388** | FormData pairs | Replace `split("&")` then `split("=")` at line 127 |

#### Tier 5: Security tokens

| Package | New Parsers | Action |
|---------|-------------|--------|
| **swift-rfc-7617** | Basic credentials | Replace `split(",")` at line 152, `user:password` parsing |
| **swift-rfc-7519** | JWT compact serialization | Replace manual period-finding loop at lines 174-220 |

#### Tier 6: Language/locale, links, RSS, SVG, WHATWG

| Package | New Parsers | Action |
|---------|-------------|--------|
| **swift-rfc-5646** | LanguageTag | Replace `split(separator: "-")` at lines 73-150 |
| **swift-rfc-9557** | Suffix annotations | Replace `split(separator: "-")` |
| **swift-rfc-6068** | Mailto URI | Wire into existing parse |
| **swift-rfc-2369** | List header URI | Wire into existing parse |
| **swift-rss-standard** | iTunes duration | Replace `split(separator: ":")` at line 40 |
| **swift-w3c-svg** | Number, Length, ViewBox, Color, Transform | Wire into existing SVG primitives. Note: 500-line hand-rolled path parser NOT yet replaced — lower priority. |
| **swift-whatwg-url** | Scheme only | Wire in; 7 more opportunities remain (see Task 2). |
| **swift-rfc-9111** | CharacterSet fix only | 1 fixed; `components(separatedBy:)` calls remain in 4+ files. |

### Verification

After each package: `swift build && swift test` in the submodule directory.

After all: `cd /Users/coen/Developer/swift-standards && swift build` (full monorepo build).

## Task 2: Gap Packages — Write New Parser Combinators

These packages have NO parser combinator code yet. Write new parsers AND wire them in (don't repeat the additive-only pattern).

### Priority order

#### HIGH — RFC 9112 (HTTP/1.1 message syntax, 9 items)

This is the single largest gap. The shared HTTP parsers from RFC 9110 (Task 1 Tier 1) are prerequisites.

| Item | File | Current Pattern |
|------|------|----------------|
| HTTP.Version | `Sources/RFC 9112/HTTP.Version.swift:26` | `split("/")` then `split(".")` |
| Request.Line | `Sources/RFC 9112/HTTP.Request.Line.swift:24` | `firstIndex(of: " ")`, `range(of: " HTTP/")` |
| Response.Line | `Sources/RFC 9112/HTTP.Response.Line.swift:24` | `split(" ", maxSplits: 2)` |
| Connection | `Sources/RFC 9112/HTTP.Connection.swift:108` | `components(separatedBy: ",")` |
| TransferEncoding | `Sources/RFC 9112/HTTP.TransferEncoding.swift:130` | `components(separatedBy: ",")` |
| ChunkedEncoding | `Sources/RFC 9112/HTTP.ChunkedEncoding.swift:90-280` | Manual `split(";")`, hex parsing (~190 lines) |
| Host | `Sources/RFC 9112/HTTP.Host.swift` | Manual host parsing |
| Field | `Sources/RFC 9112/HTTP.Field.swift` | Manual header field parsing |
| Message.Deserializer | `Sources/RFC 9112/HTTP.Message.Deserializer.swift:13` | Manual `split("?")` |

**Approach:** Import `Parser_Primitives`. Reuse `RFC_9110.Parse.OWS`, `RFC_9110.Parse.Token`, `RFC_9110.Parse.CommaSeparated` from the shared parsers. Create `RFC_9112.Parse` namespace with sub-parsers.

```bash
cd /Users/coen/Developer/swift-standards/swift-rfc-9112
# Add Parser_Primitives dependency to Package.swift
swift build && swift test
```

#### MEDIUM — Remaining packages

| Package | Items | Pattern |
|---------|-------|---------|
| **swift-rfc-9111** | CacheControl, Vary, Expires, Age, HeaderStorage (5) | `components(separatedBy:)`, Foundation CharacterSet |
| **swift-whatwg-url** | IPv4, IPv6, Path, FormData, PercentEncoding, Host, Authority (7) | `split(".")`, `split(":")`, `split("&")` |
| **swift-rfc-3987** | IRI parser (1) | Extend RFC 3986 URI parser for IRI character ranges |
| **swift-rfc-5890** | IDNA domain labels (1) | `split(".")` |
| **swift-rfc-1035** | Domain label parsing (1) | Manual index advancement |
| **swift-rfc-1123** | Domain validation (1) | Manual LDH validation |
| **swift-rfc-4291** | IPv6 address (1) | Binary.ASCII.Serializable |
| **swift-rfc-4007** | IPv6 scoped address (1) | Manual `%zone` suffix |
| **swift-rfc-6531** | Internationalized email (2) | Manual Unicode-aware scanning |
| **swift-iso-14496-22** | Font table binary parsing (1) | 11 manual `parseXxx` functions → Binary Parser Primitives |
| **swift-w3c-css** | Fonts, HexColor (2) | `split(",")`, manual hex |
| **swift-linux** | NUMA CPU list (1) | `split(",")` then `split("-")` |
| **swift-plist** | Binary plist (1) | Manual offset tables → Binary Parser Primitives |

#### LOW / DEFERRED

| Package | Reason |
|---------|--------|
| RFC 4648 (Base encoding) | Lookup tables are correct for fixed-alphabet decoding |
| RFC 3492 (Punycode) | State machine by spec; wrap don't restructure |
| RFC 1951 (DEFLATE) | Bit-level, outside byte-level combinator scope |
| W3C CSS MediaQueries, Cascade | Complex grammars, lower impact |
| WHATWG HTML FormData, Href | Low complexity, low impact |
| ISO 32000 (JPEG header, PDF binary) | Specialized binary, low volume |
| W3C SVG path parser | 500+ lines, complex command dispatch — significant effort |

## Task 3: Remove Foundation Imports

After parser combinators replace hand-rolled parsing, several packages can drop Foundation:

| Package | Foundation Usage | Removable After Parser Adoption |
|---------|-----------------|-------------------------------|
| swift-rfc-9111 | `CharacterSet`, `components(separatedBy:)` | Yes — after CacheControl/Vary/Expires rewrite |
| swift-w3c-svg | `Foundation` import | Partially — after Number/Length/Color parsers wired in. Path parser may still need it. |

Check each package after wiring in parsers: `grep -r "import Foundation" Sources/`.

## Naming Convention

New parser files MUST follow the `TypeName.Parse.swift` pattern (not `Parse.TypeName.swift`):

```
RFC_9112.HTTP.Version.Parse.swift      ✅
RFC_9112.Parse.HTTP.Version.swift      ❌
```

Parser types live in a `.Parse` sub-namespace:

```swift
extension RFC_9112.HTTP.Version {
    struct Parse: Parser.Protocol { ... }
}
```

---

## Revised Package Status (as of 2026-03-04)

The current audit reveals a more nuanced picture than "18 packages, all PARTIAL":

### Complete Migration (5 packages)

No manual `.split()` or `components(separatedBy:)` in main source:

| Package | Parse Files | Notes |
|---------|-------------|-------|
| swift-rfc-5321 | 2 | Email address parsing |
| swift-rfc-7519 | 2 | JWT compact serialization |
| swift-rfc-2369 | 2 | List header URI |
| swift-rfc-5322 | 3 | DateTime, MessageID (Foundation in separate bridge module) |
| swift-rfc-2822 | 3 | Email address (Foundation in separate bridge module) |

### Mostly Migrated (8 packages)

1–2 remaining `.split()` calls, typically in non-critical or secondary paths:

| Package | Parse Files | Remaining `.split()` | Location |
|---------|-------------|---------------------|----------|
| swift-rfc-3986 | 10 | 1 | To identify |
| swift-rfc-2045 | 4 | 1 | ContentType secondary path |
| swift-rfc-2183 | 2 | 1 | ContentDisposition secondary path |
| swift-rfc-2388 | 3 | 2 | FormData pair splitting |
| swift-rfc-5646 | 2 | 1 | LanguageTag subtag split |
| swift-rfc-7617 | 2 | 1 | Basic credentials |
| swift-rfc-9557 | 2 | 2 | Suffix annotations |
| swift-rss-standard | 2 | 1 | iTunes duration |

### Bifurcated Implementation (2 packages — CRITICAL)

Parser combinators exist but public entry points still use old code:

| Package | Parse Files | Active `.split()` | Problem |
|---------|-------------|-------------------|---------|
| **swift-rfc-9110** | 8 | **17** | HTTP.MediaType, ContentNegotiation, Authentication, Precondition, ContentEncoding, ContentLanguage all still use `.split()` in public methods. The 8 parser combinators (OWS, Token, QuotedString, Parameter, ParameterList, CommaSeparated, QualityValue) sit unused. |
| **swift-whatwg-url** | 2 | **6** | WHATWG_Form_URL_Encoded.parse() uses direct `.split("&")` then `.split("=")`. Minimal combinator work done. |

### Correctly Structured (1 package)

| Package | Parse Files | `.split()` in Parser | Notes |
|---------|-------------|---------------------|-------|
| swift-iso-8601 | 12 | 12 (internal) | All `.split()` contained within `ISO_8601.DateTime.Parser` enum. Public API delegates correctly. No action needed on these `.split()` calls. |

### Foundation Status

**Main package sources: ZERO Foundation imports across all 18 packages.** All 4 Foundation imports are properly segregated in separate bridge modules (RFC 5322, RFC 2822, RFC 6068, W3C SVG).

### Totals

| Metric | Count |
|--------|-------|
| Parse files created | 61 |
| Remaining `.split()` in non-Parse source | 60 |
| Remaining `.components(separatedBy:)` | 0 |
| Foundation in main source | 0 |

---

## Task 4: Validation Strategy

When wiring new parser combinators into existing public APIs, correctness must be verified systematically. The additive pattern (new parsers alongside old code) was an intentional intermediate state — validate before removing.

### Per-Package Validation Checklist

For each package in Task 1 (replacement pass):

1. **Capture current behavior** — Run existing tests, note pass/fail baseline
2. **Wire new parser** — Replace the old parsing body with a combinator call
3. **Run tests** — All existing tests must still pass
4. **Verify error types** — New parser's typed throws must be compatible with the public API's error type (see Task 5)
5. **Edge case audit** — Check behavior on:
   - Empty input
   - Malformed input (partial matches)
   - Maximum-length input
   - Unicode where ASCII is expected
6. **Remove old code** — Delete the `.split()`-based implementation only after validation passes
7. **Build monorepo** — `cd /Users/coen/Developer/swift-standards && swift build` to catch cross-package breakage

### What NOT to Do

- Do not replace old code and delete it in one step. Wire in, validate, then remove.
- Do not add comparison testing infrastructure (dual-path execution). The existing test suites are the validation — if they pass with the new parser, the replacement is correct.
- Do not add performance benchmarks unless the parser is in a hot path (HTTP header parsing qualifies; RSS duration parsing does not).

---

## Task 5: Error Type Compatibility

New parser combinators use typed throws via `Parser.Protocol`. When wiring them into existing public APIs, error types must align.

### Patterns

**Case 1: Public API already uses typed throws** — Match the error type.

```swift
// Existing public API
func parse(_ input: String) throws(RFC_9110.HTTP.Error) -> MediaType

// New parser must produce RFC_9110.HTTP.Error, not Parser.Error
extension HTTP.MediaType {
    struct Parse: Parser.Protocol {
        typealias Failure = RFC_9110.HTTP.Error  // Must match
    }
}
```

**Case 2: Public API uses `init?` (failable)** — Parser failure maps to `nil`.

```swift
// Existing
init?(_ string: String)

// Wiring: run parser, return nil on failure
init?(_ string: String) {
    guard let result = try? Parse().parse(&input) else { return nil }
    self = result
}
```

**Case 3: Public API uses untyped throws** — This is a migration opportunity. Replace `throws` with `throws(E)` in the same pass. Refer to the typed throws conversion work (MEMORY.md).

### Known Conflicts

- **RFC 9112**: Old hand-rolled code uses `HTTP.Error` variants that may not map 1:1 to new parser error types. Design the `RFC_9112.Parse` error type to be a superset.
- **ISO 8601**: Internal parser already uses `ISO_8601.Date.Error` and `ISO_8601.Time.Error` — these are correct and stable.

---

## Task 6: Transitive Dependency Map

Understanding which packages unblock others determines execution order beyond the tier structure in Task 1.

```
RFC 9110 (shared HTTP parsers)
├── RFC 9111 (cache control — reuses OWS, Token, CommaSeparated)
├── RFC 9112 (message syntax — reuses OWS, Token, CommaSeparated)
└── RFC 6750 (bearer tokens — DONE)

RFC 3986 (URI)
├── RFC 3987 (IRI — extends URI for Unicode)
│   └── WHATWG URL (depends on both URI and IRI)
├── RFC 6068 (mailto — DONE)
└── RFC 2369 (list header URI — DONE)

RFC 5322 (email datetime — DONE)
└── RFC 2822 (email address — DONE)

RFC 5646 (language tags)
└── RFC 9557 (suffix annotations)

RFC 2045 (content type)
└── RFC 2183 (content disposition)
```

**Key insight**: RFC 9110 unblocks the two largest remaining gap packages (RFC 9111 and RFC 9112). RFC 3986 → RFC 3987 → WHATWG URL is a strict sequence.

---

## Available Infrastructure

### Parser Primitives (33 modules in swift-parser-primitives)

The combinator library is mature. Available tools:

| Category | Combinators | Notes |
|----------|------------|-------|
| **Composition** | `OneOf`, `Take`, `Take.Builder` | Result builder for declarative pipelines |
| **Transformation** | `Map`, `FlatMap`, `Filter` | Standard functor/monad/filter |
| **Control** | `Conditional`, `Optional`, `Skip` | Branching and optional matching |
| **Repetition** | `Many`, `Prefix`, `First` | Zero-or-more, while-predicate, single element |
| **Lookahead** | `Peek`, `Not` | Non-consuming inspection |
| **Concrete** | `Byte`, `Literal`, `ASCII.Integer.Decimal`, `ASCII.Integer.Hexadecimal` | Byte matching, string literals, integer parsing |
| **Tracking** | `Tracked`, `Spanned`, `Span`, `Locate` | Position and range tracking |
| **Control flow** | `Backtrack`, `Lazy`, `Trace` | Save/restore, deferred construction, debug |
| **Terminals** | `End`, `Rest`, `Always`, `Fail` | End-of-input, consume rest, success, failure |

### Binary Parser Primitives (9 modules)

For ISO 14496-22 (font tables) and plist binary format:

| Module | Purpose |
|--------|---------|
| `Binary.Bytes.Input` | Owned byte cursor, `Parser.Protocol.Input` conformant |
| `Binary.LEB128.Unsigned` | Variable-length integer encoding |
| `Binary.Coder` | Witness-based bidirectional coding (decode + encode) |

### Parser Machine Primitives (6 modules)

Defunctionalized parser machines — runs without recursive stack growth. Available but not yet used in any standards package. Consider for:
- W3C SVG path parser (complex command dispatch)
- W3C CSS grammars (if promoted from LOW)

### `Parser.Protocol` Design

```swift
public protocol `Protocol`<Input, ParseOutput, Failure> {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype ParseOutput
    associatedtype Failure: Error & Sendable
    func parse(_ input: inout Input) throws(Failure) -> ParseOutput
}
```

Supports `~Copyable & ~Escapable` inputs (e.g., `Span<UInt8>` for zero-copy parsing). All parsers use typed throws.

### Pending Infrastructure: `Collection.Slice.Protocol`

8 parsers (`End`, `Rest`, `Prefix.While/UpTo/Through`, `Consume.Exactly`, `Discard.Exactly`) are currently constrained to stdlib `Collection`. A `Collection.Slice.Protocol` migration (documented in `swift-primitives/Research/parser-collection-protocol-migration.md`) will enable `~Copyable` element support. This is not blocking any current standards work but will matter for binary parsing paths.

---

## When NOT to Use Parser Combinators

Not every parsing problem benefits from combinators. The following are correctly deferred:

| Pattern | Why Combinators Don't Help | Examples |
|---------|---------------------------|----------|
| **Lookup tables** | Fixed-alphabet decoding is a table lookup, not a grammar | RFC 4648 (Base64/32/16) |
| **State machines by spec** | The specification defines a state machine; wrapping it in combinators adds indirection without clarity | RFC 3492 (Punycode) |
| **Bit-level parsing** | Byte-level combinators don't operate at sub-byte granularity | RFC 1951 (DEFLATE) |
| **Single-byte dispatch** | A `switch` on one byte is simpler than `OneOf` with 26 branches | W3C SVG path commands (M/L/C/S/Q/T/A/Z) |

**Rule**: If the existing code is a clear, correct implementation of the specification's own algorithm, wrapping it in combinators is over-engineering. Combinators win when replacing ad-hoc `.split()`/index-advancement code that obscures the grammar.

---

## Strategic Decision: W3C SVG Path Parser

The SVG path parser (`~500 lines`) in `swift-w3c-svg` is in a Foundation bridge module, not main source. It uses manual character dispatch for M/L/C/S/Q/T/A/Z commands.

**Options**:

1. **Keep as-is** — It works, it's isolated in a bridge module, and command dispatch is inherently a switch statement (see "When NOT to Use" above). Foundation dependency stays in the bridge module only.

2. **Rewrite with Parser Machine Primitives** — The defunctionalized machine model handles complex command dispatch without stack growth. This would be a showcase for Parser Machine Primitives but is significant effort.

3. **Hybrid** — Use `Parser.ASCII.Integer.Decimal` for coordinate parsing (replacing manual digit accumulation) but keep the command dispatch as a switch. Foundation import may still be removable.

**Recommendation**: Option 3 (hybrid). The coordinate parsing is clearly `.split()`-style ad-hoc code that benefits from combinators. The command dispatch does not. Defer to a future session.

---

## Execution Plan Summary

```
Phase 1: RFC 9110 replacement pass (17 splits → 0)
         ↓ unblocks
Phase 2: RFC 9112 gap parsers (9 items, ~400 lines)
         RFC 9111 gap parsers (5 items)
         ├── both reuse RFC 9110 shared parsers
         ↓
Phase 3: RFC 3986 final split elimination (1 split → 0)
         ↓ unblocks
Phase 4: RFC 3987 IRI extension
         ↓ unblocks
Phase 5: WHATWG URL (6 splits + 7 gap items)
         ↓
Phase 6: Remaining "mostly migrated" packages (8 packages, 10 splits total)
         ISO 8601 — no action needed (correctly structured)
         ↓
Phase 7: Foundation removal audit (re-check after all wiring complete)
         ↓
Phase 8: Binary parser migration (ISO 14496-22, plist — when Binary Parser Primitives mature)
```

**Estimated scope**: ~60 `.split()` eliminations across Task 1 + ~25 new parser files for Task 2 gap packages.

---

## Open Questions

1. **RFC 9110 error type**: What error type should the shared HTTP parsers use? The 8 existing parser files may already define one — verify before wiring.

2. **RFC 9112 ChunkedEncoding**: The 190-line manual parser includes hex digit accumulation, chunk extension parsing, and trailer field handling. Should this be one monolithic `ChunkedEncoding.Parse` or decomposed into `ChunkSize.Parse`, `ChunkExtension.Parse`, `TrailerField.Parse`?

3. **WHATWG URL scope**: The WHATWG URL Standard defines its own parsing algorithm distinct from RFC 3986. How much should the combinator implementation mirror the spec's state machine vs. compose from RFC 3986 building blocks?

4. **Performance-critical paths**: HTTP header parsing (RFC 9110, 9112) is latency-sensitive. Should we benchmark the combinator-based parsers against the `.split()`-based code before committing to the replacement?
