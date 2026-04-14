# Parser Bridge Architecture

<!--
---
version: 1.0.1
last_updated: 2026-04-01
status: RECOMMENDATION
tier: 2
---
-->

## Context

Swift Institute standards packages have a bifurcated parsing architecture:

1. **Parse struct files** — properly composed parser combinators (`HTTP.Parse.Token<Input>`, `ISO_8601.Parse.Digits<Input>`, etc.) constrained to `Collection.Slice.Protocol`
2. **Public API files** — ad-hoc byte-level parsing on `[UInt8]` with `Int` indices that duplicates the logic in the parse structs

The parse structs exist in ~25 packages (80+ files import `Parser_Primitives`), but zero public APIs delegate to them. Instead, every public `init(ascii:)` or `parse()` method reinvents the same scanning patterns inline.

This wastes the composable parser infrastructure and creates maintenance burden: fixing a bug in token parsing requires updating both the Parse struct AND the inline copy.

## Question

How should public APIs bridge from `String` / `Collection<UInt8>` to the `Collection.Slice.Protocol`-constrained parser combinators?

## Analysis

### Type System Topology

```
Public API world                    Parser combinator world
─────────────────                   ──────────────────────
String
  ↓ .utf8
[UInt8]
  ↓ ???                             Input: Collection.Slice.Protocol
                                      where Input.Element == UInt8
                                      where Input.Index == Index<UInt8>
```

The gap: `[UInt8]` uses `Int` indices. `Collection.Slice.Protocol` requires `Index<Element>` (phantom-typed indices from `Index_Primitives`).

### Bridge Chain (Discovered)

```
[UInt8]
  ↓ Array<UInt8>.Indexed<UInt8>(_:)     // from Array_Dynamic_Primitives
Input.Slice<Array<UInt8>.Indexed<UInt8>>
  ↓ Input.Slice(_:)                     // from Input_Primitives
Collection.Slice.Protocol ✓             // conforms when Base: Collection.Protocol & Copyable
```

Concrete:
```swift
let bytes: [UInt8] = Array(string.utf8)
let indexed = Array<UInt8>.Indexed<UInt8>(bytes)
var input = Input.Slice(indexed)
let result = try HTTP.Parse.Token<Input.Slice<Array<UInt8>.Indexed<UInt8>>>().parse(&input)
```

### Protocol Hierarchy

Two parallel input systems exist in the primitives:

| Protocol | Source | Purpose | Key Capability |
|----------|--------|---------|----------------|
| `Collection.Slice.Protocol` | collection-primitives | Self-slicing collections | Range subscript returns `Self` |
| `Parser.Input` (= `Input.Protocol`) | input-primitives | Backtracking parser input | `checkpoint` / `restore(to:)` |
| `Parser.Streaming` (= `Input.Streaming`) | input-primitives | Forward-only input | `isEmpty`, `advance()` |

`Input.Slice<Base>` conforms to ALL THREE when `Base: Collection.Protocol & Copyable`.

Standards parsers use `Collection.Slice.Protocol` — the lightest constraint. This is correct: HTTP/MIME/URI parsing is forward-only, no backtracking needed.

### Dependencies Required

To use the bridge, a standards package needs:

| Dependency | Currently Imported? | Required For |
|------------|-------------------|--------------|
| `Parser_Primitives` | Yes (80+ files) | Parser.Protocol, combinators |
| `Input_Primitives` | Transitive via Parser_Primitives | `Input.Slice` |
| `Collection_Primitives` | Transitive via Parser_Primitives | `Collection.Slice.Protocol` |
| `Array_Dynamic_Primitives` | **NO** | `Array.Indexed` wrapper |
| `Index_Primitives` | Transitive | Phantom-typed indices |

**Missing dependency**: `Array_Dynamic_Primitives` (from `swift-array-primitives`).

### Option A: Add Array_Dynamic_Primitives, Wire Bridge Manually

Each public API manually constructs the bridge:

```swift
public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void) throws(Error)
where Bytes.Element == UInt8 {
    let indexed = Array<UInt8>.Indexed<UInt8>(Array(bytes))
    var input = Input.Slice(indexed)
    // delegate to parser combinator
    let parsed = try MyType.Parse<Input.Slice<Array<UInt8>.Indexed<UInt8>>>().parse(&input)
    self.init(__unchecked: (), ...)
}
```

**Pro**: No new infrastructure needed — just add dependency and wire.
**Con**: Verbose type signatures. Bridge code repeated in every public init.

### Option B: Add Convenience Typealias + Init in Parser Primitives

Add to `swift-parser-primitives`:

```swift
extension Parser {
    /// Concrete input type for parsing byte arrays.
    ///
    /// Use this for the common case of parsing `[UInt8]` with combinators.
    public typealias ByteInput = Input.Slice<Array<UInt8>.Indexed<UInt8>>
}

extension Parser.ByteInput {
    /// Creates parser input from a byte array.
    public init(_ bytes: [UInt8]) {
        self = Input.Slice(Array<UInt8>.Indexed<UInt8>(bytes))
    }

    /// Creates parser input from a string's UTF-8 bytes.
    public init(utf8 string: String) {
        self.init(Array(string.utf8))
    }
}
```

Then in standards packages:

```swift
public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void) throws(Error)
where Bytes.Element == UInt8 {
    var input = Parser.ByteInput(Array(bytes))
    let parsed = try MyType.Parse<Parser.ByteInput>().parse(&input)
    self.init(__unchecked: (), ...)
}
```

**Pro**: Clean call sites. Single canonical bridge type. `Parser.ByteInput` is self-documenting.
**Con**: Adds `Array_Dynamic_Primitives` as dependency to parser-primitives (currently not there).

### Option C: Make parse structs accept [UInt8] directly

Add a convenience extension on every parse struct:

```swift
extension HTTP.Parse.Token where Input == Parser.ByteInput {
    static func parse(_ bytes: [UInt8]) throws(Error) -> String {
        var input = Parser.ByteInput(bytes)
        let result = try Self().parse(&input)
        return String(decoding: result, as: UTF8.self)
    }
}
```

**Pro**: Most ergonomic call sites.
**Con**: One overload per parser per concrete output type. Explosion of methods.

### Option D: Protocol extension with default bridge

Add to `Parser.Protocol`:

```swift
extension Parser.Protocol where Input == Parser.ByteInput {
    func parse(bytes: [UInt8]) throws(Failure) -> ParseOutput {
        var input = Parser.ByteInput(bytes)
        return try parse(&input)
    }
}
```

**Pro**: Single extension covers ALL parsers. Zero per-type work.
**Con**: Only works for "parse entire input" semantics (no partial parse + continue).

### Comparison

| Criterion | A: Manual | B: Typealias | C: Per-parser | D: Protocol ext |
|-----------|-----------|-------------|---------------|-----------------|
| Call-site clarity | Poor | Good | Excellent | Good |
| New infrastructure | None | 1 typealias + init | N overloads | 1 extension |
| Dependency impact | Per-package | Parser-primitives | Per-package | Parser-primitives |
| Supports partial parse | Yes | Yes | No | No |
| Supports composition | Yes | Yes | No | Limited |
| Maintenance burden | High | Low | Very high | Low |

## Constraints

1. **Parser primitives do not currently depend on Array_Dynamic_Primitives.** Adding it is a tier dependency change.
2. **`Collection.Slice.Protocol` is the correct constraint** for standards parsers — they don't need backtracking.
3. **Public APIs must remain String/Collection-accepting** — we cannot force callers to construct `Input.Slice`.
4. **The bridge is per-parse-call, not per-type** — a single method call wraps `[UInt8]` before delegation.

## Recommendation

**Option B** (convenience typealias in parser-primitives) combined with **Option D** (protocol extension for full-parse convenience).

### Implementation Plan

#### Phase 1: Infrastructure (parser-primitives)

1. Add `Array_Dynamic_Primitives` dependency to `swift-parser-primitives`
2. Create `Parser.ByteInput` typealias
3. Add `init(_ bytes: [UInt8])` and `init(utf8: String)` convenience inits
4. Add `parse(bytes:)` protocol extension for full-parse convenience

#### Phase 2: Exemplar Package (RFC 9110)

1. Wire `HTTP.MediaType.parse()` to delegate to `HTTP.Parse.Token`, `HTTP.Parse.ParameterList`, etc. via `Parser.ByteInput`
2. Remove inline `_skipOWS`, `_token`, `_quotedString` helper functions from `HTTP.Parse.swift`
3. Verify all tests pass
4. Measure: compile time, binary size, test coverage

#### Phase 3: Roll Out

Apply the same pattern to all packages with existing parse structs:
- RFC 3986 (Scheme, Authority, Host, Port, Path, Query, Fragment)
- RFC 2045 (Token, QuotedString, ContentType)
- RFC 2183 (ContentDisposition)
- ISO 8601 (Digits, CalendarDate, Time, DateTime, Duration, etc.)
- RFC 5322 (DateTime, MessageID)
- RFC 5646 (LanguageTag)
- RFC 9557 (Suffix)
- RFC 7617 (Basic)
- RFC 2388 (FormData)
- RFC 8259 (already uses Input.Buffer — verify alignment)
- RSS Standard (Duration)
- W3C SVG (ViewBox, Number, Length, Transform, Color)
- WHATWG URL (Scheme)

#### Phase 4: Remaining .split() Packages

For packages that still have `.split()` calls AND no parse structs yet:
- RFC 9112: Create parse structs (ChunkedEncoding, Version, RequestLine, ResponseLine)
- RFC 9111: Create parse structs (CacheControl, CacheDirective)
- RFC 5890/IDNA: Create parse structs (Label splitting)
- WHATWG URL: Create parse structs (IPv4, IPv6, Path, URLEncoded)
- ISO 8601: Wire existing parse structs, eliminate string-level .split()

## Open Questions

1. **Should `Parser.ByteInput` live in parser-primitives or in a new `Parser Bridge Primitives` target?** If the dependency on `Array_Dynamic_Primitives` is too heavy for the core, it could be isolated.

2. **Should `Array<UInt8>.Indexed<UInt8>` be the bridge Base, or should we create a simpler `Bytes.Indexed` wrapper?** The double-generic `Array<UInt8>.Indexed<UInt8>` is ugly. A dedicated wrapper could be cleaner.

3. **How should partial-parse results be handled?** Some public APIs parse a prefix and need the remaining bytes (e.g., HTTP message deserializer). The protocol extension approach doesn't cover this — those need manual bridge code.

4. **Error mapping**: Parser combinators use typed errors (`HTTP.Parse.Token.Error`). Public APIs use their own error types (`HTTP.MediaType.Error`). Each bridge site needs `do { try parser } catch { throw publicError }`. Should there be a standard pattern?

## References

- `swift-parser-primitives`: `https://github.com/swift-primitives/swift-parser-primitives`
- `swift-input-primitives`: `https://github.com/swift-primitives/swift-input-primitives`
- `swift-collection-primitives`: `https://github.com/swift-primitives/swift-collection-primitives`
- `swift-array-primitives`: `https://github.com/swift-primitives/swift-array-primitives`
- Previous research: `Research/next-steps-parsers.md`
