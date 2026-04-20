# String Type Ecosystem — Top-to-Bottom Model

Pre-correction-cycle reference model for the string types that span swift-primitives (L1), swift-iso / swift-incits / swift-ietf / swift-whatwg / swift-ecma / swift-microsoft (L2), and swift-foundations (L3). Confirmed from source on 2026-04-18.

---

## 1. Overview

Three distinct owned string families coexist in L1 — `String_Primitives.String` (OS-native, platform-sensitive Char width), `ISO_9899.String` (pure C byte string, Char=UInt8 always), and `ASCII` (value-classification namespace over `UInt8`, no ownership type). L1 has no protocol bundling these — each is a concrete struct with its own `View`. L2 adds specification encoders (URI, IRI, URL, IDN, Punycode, SGR) that mostly build on `Swift.String` + `[UInt8]` ASCII bytes, plus the POSIX (`ISO_9945`) and Windows (`swift-windows-standard`) syscall-shim layers that pass `Kernel.String.View` (= `String.View`) and raw `WCHAR*` across syscalls. L3 (`swift-strings`, `swift-ascii`, `swift-kernel/Kernel File`) is conversion glue between `Swift.String` and the three L1 owned types. There is no concrete `Strings.String` L3 owned type analogous to `Paths.Path` — L3 for strings is bridges, not a new owning struct.

Critical absences: no UTF-8 spec package (RFC 3629), no Unicode / ISO 10646 package, no `Windows.Kernel.String` conformance file. The ecosystem leans on Swift stdlib for Unicode normalization, case folding, segmentation, and UTF-8/UTF-16 decoding.

```
L3 FOUNDATIONS
  ┌────────────────────────────────────────────────────────────────────┐
  │ swift-strings / Strings                                            │
  │   (no own String type — only extensions + bridges)                 │
  │   Swift.String.init(_ view: String_Primitives.String.View)         │
  │   Swift.String.init(_ owned: consuming String_Primitives.String)   │
  │   Swift.String.init(_ view: ISO_9899.String.View)                  │
  │   Swift.String.init(_ span: Span<UInt8>) throws(UTF8.ValidationError)│
  │   Swift.String.withPrimitivesView(_:), .withISO9899View(_:)        │
  │   Swift.String.strictUTF8(_:), .strictUTF16(_:)                    │
  │   String_Primitives.String.init(_ string: Swift.String)            │
  │   ISO_9899.String.init(_ string: Swift.String)                     │
  │   cross: ISO_9899.String ↔ String_Primitives.String (POSIX only)   │
  ├────────────────────────────────────────────────────────────────────┤
  │ swift-ascii / ASCII                                                │
  │   (no own String type — extensions + ASCII literal init)           │
  │   String_Primitives.String.init(ascii literal: StaticString)       │
  ├────────────────────────────────────────────────────────────────────┤
  │ swift-kernel / Kernel File (unification layer)                     │
  │   Swift.String.init(_ path: borrowing Kernel.Path) — public        │
  │   Swift.String.init(_ view: borrowing Kernel.Path.View) — public   │
  │   Swift.String.init(_ string: borrowing Kernel.String) — package   │
  └────────────────────────────────────────────────────────────────────┘
                      ↑ bridges via init forms (no common protocol)
L2 STANDARDS
  ┌────────────────────────────────────────────────────────────────────┐
  │ swift-incits-4-1986 (ASCII spec)                                   │
  │   INCITS_4_1986 (enum namespace, re-exports ASCII_Primitives)      │
  │   INCITS_4_1986.ASCII<Source> (generic wrapper)                    │
  │   INCITS_4_1986.Case (= ASCII.Case typealias)                      │
  │                                                                    │
  │ swift-iso-9945 (POSIX) — uses Kernel.String.View at syscall edges  │
  │   ISO_9945.Kernel.Environment.withValue(_:_:) → Kernel.String.View │
  │   ISO_9945.Kernel.Environment.get(_:) → Kernel.String?             │
  │   ISO_9945.Kernel.Path.View + Path.Decomposition / Path.Modification│
  │   (no Kernel.String.View+Protocol conformance anywhere)            │
  │                                                                    │
  │ swift-microsoft/swift-windows-standard                             │
  │   Windows.Kernel.Environment.get(name:) → [UInt16] (!)             │
  │   Windows.Kernel.Path.Canonical.resolve (WCHAR* via WinSDK)        │
  │   NO Kernel.String or String_Primitives use anywhere               │
  │                                                                    │
  │ swift-ietf (URI / IRI / IDN / ABNF / Punycode)                     │
  │   RFC_3986.URI.{Scheme, Authority, Host, Path, Query, Fragment,    │
  │                  Port, Userinfo}  — all Copyable, Swift.String     │
  │   RFC_3987.IRI, .ValidationMode                                    │
  │   RFC_5234.{Rule, Terminal, Validator, CoreRules}  (ABNF)          │
  │   RFC_3492.Punycode                                                │
  │   RFC_5890.IDNA                                                    │
  │                                                                    │
  │ swift-whatwg (Living specs)                                        │
  │   WHATWG_URL.{URL, URL.Scheme, URL.Host, URL.Path, URL.Search,     │
  │               PercentEncoding, URL.Href, URL.Path.Context}         │
  │   WHATWG Form URL Encoded                                          │
  │                                                                    │
  │ swift-ecma/swift-ecma-48 (Terminal control)                        │
  │   ECMA_48.{Cursor, SGR.{Attribute, Color, Palette}, Screen}        │
  │                                                                    │
  │ swift-iso (Code standards — NOT string types; code enums only)     │
  │   ISO_639.{LanguageCode, Alpha2, Alpha3}                           │
  │   ISO_15924.{Alpha4, Numeric}                                      │
  │   ISO_3166.{Alpha2, Alpha3, Numeric, Code}                         │
  │   ISO_9899.String (see below — straddles L1-style owning & L2 spec)│
  └────────────────────────────────────────────────────────────────────┘
                      ↑ retroactive on L1 or L1 types consumed directly
L1 PRIMITIVES
  ┌────────────────────────────────────────────────────────────────────┐
  │ swift-kernel-primitives / Kernel String Primitives                 │
  │   Kernel.String      typealias = Tagged<Kernel, Primitives.String> │
  │   Kernel.String.View = Tagged<…>.View = String.View                │
  │                      (via Tagged: Viewable — identity preserved)   │
  ├────────────────────────────────────────────────────────────────────┤
  │ swift-string-primitives / String Primitives                        │
  │   String_Primitives.String        ~Copyable, @unsafe @unchecked    │
  │                                    Sendable; _storage: Memory.     │
  │                                    Contiguous<Char> (NUL-term.)    │
  │   String_Primitives.String.View   ~Copyable, ~Escapable; pointer+  │
  │                                    count                           │
  │   String_Primitives.String.Char   UInt8 POSIX / UInt16 Windows     │
  │   String_Primitives.String.CodeUnit = Char                         │
  │   String_Primitives.String.terminator: Char = 0                    │
  │   (no Protocol type — each String is concrete)                     │
  │                                                                    │
  │ swift-ascii-primitives / ASCII Primitives                          │
  │   ASCII                enum namespace                              │
  │   ASCII.Byte           struct (wraps UInt8, Sendable)              │
  │   ASCII.Case           enum (.upper/.lower, Sendable)              │
  │   ASCII.Character      enum namespace                              │
  │   ASCII.Character.Control, .Graphic, .Control.cr/lf/htab/…         │
  │   ASCII.Classification enum namespace — isWhitespace/isDigit/…     │
  │   ASCII.Validation     enum namespace — isASCII/isAllASCII         │
  │   ASCII.Decimal, .Hexadecimal, .Line.Ending, .SPACE namespaces     │
  │   ASCII.Case.Conversion namespace — byte-level upper/lower         │
  │   ASCII.Parsing, .Serialization namespaces (classification only)   │
  │                                                                    │
  │ swift-ascii-parser-primitives / ASCII Parser Primitives            │
  │   ASCII.Parser enum namespace (umbrella)                           │
  │   ASCII.Decimal.Parser, ASCII.Hexadecimal.Parser                   │
  │                                                                    │
  │ swift-ascii-serializer-primitives / ASCII Serializer Primitives    │
  │   ASCII.Serializer enum namespace (umbrella)                       │
  │                                                                    │
  │ swift-text-primitives / Text Primitives   (aux text cursor types)  │
  │   Text, Text.Line, Text.Position, .Offset, .Count, .Range,         │
  │   .Location, .Line.{Number, Column, Map}, .Location.Tracker        │
  │                                                                    │
  │ swift-token-primitives / Token Primitives (lex output vocabulary)  │
  │   Token (struct), Token.Kind (enum), Token.Keyword (enum)          │
  │                                                                    │
  │ swift-input-primitives / Input Primitives (cursor infrastructure)  │
  │   Input namespace; Input.Protocol, Input.Stream.Protocol,          │
  │   Input.Access.Random, Input.Slice, Input.Buffer                   │
  │                                                                    │
  │ swift-lexer-primitives / Lexer Primitives                          │
  │   Lexer namespace; Lexer.Scanner (~Copyable, ~Escapable),          │
  │   Lexer.Lexeme, Lexer.Trivia, Lexer.Error                          │
  └────────────────────────────────────────────────────────────────────┘

  ┌────────────────────────────────────────────────────────────────────┐
  │ ISO 9899 String family (straddles L1/L2 — see §7/Q7)               │
  │   ISO_9899.String      struct ~Copyable; pointer + count           │
  │   ISO_9899.String.View struct ~Copyable, ~Escapable; pointer only  │
  │   ISO_9899.String.Char typealias = UInt8 (always, all platforms)   │
  │   ISO_9899.String.terminator: Char = 0                             │
  │   ISO_9899.String.{Comparison, Concatenation, Copy, Length,        │
  │                    Memory, Search, Order} (strchr/strcmp/strlen)   │
  └────────────────────────────────────────────────────────────────────┘
```

---

## 2. Type Reference Table

| # | Qualified Name | Layer | Source | Storage | Own. | NUL-term? | Copyable | Escapable | Encoding | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `String_Primitives.String` | L1 | `swift-primitives/swift-string-primitives/Sources/String Primitives/String.swift:47` | `Memory.Contiguous<Char>` (heap, adopts) | owned value | **yes**, excluded from `count` | `~Copyable` | Escapable | UTF-8 POSIX / UTF-16 Windows | `@safe @unsafe @unchecked Sendable`. API: `init(adopting:count:)`, `init(copying: View)`, `init(_ span: Span<Char>)`, `init(ascii literal: StaticString)`, `count`, `span`, `view`, `take()`, `withUnsafePointer(_:)`. Conforms `Memory.Contiguous.Protocol`. |
| 2 | `String_Primitives.String.View` | L1 | `swift-primitives/swift-string-primitives/Sources/String Primitives/String.View.swift:33` | `UnsafePointer<Char>` + `count: Int` | borrowed view | **yes**, excluded from `count` | `~Copyable` | `~Escapable` | same as parent | `@safe`. API: `pointer`, `count`, `length`, `span`, `withUnsafePointer(_:)`. Debug-validates NUL in DEBUG only (scan cap 16 MiB). |
| 3 | `String_Primitives.String.Char` | L1 | `String.Char.swift:23/25` | typealias | — | — | — | — | `UInt8` POSIX / `UInt16` Windows | `#if os(Windows)` switch. |
| 4 | `String_Primitives.String.CodeUnit` | L1 | `String.Char.swift:31` | typealias | — | — | — | — | = Char | Semantic alias; doc recommends it for new code. |
| 5 | `String_Primitives.String.terminator` | L1 | `String.Char.swift:35` | static let | — | — | — | — | — | `Char = 0`. |
| 6 | `Kernel.String` | L1 | `swift-primitives/swift-kernel-primitives/Sources/Kernel String Primitives/Kernel.String.swift:34` | typealias → `Tagged<Kernel, String_Primitives.String>` | owned (tagged) | yes | `~Copyable` (via RawValue) | Escapable | platform-native | Zero-cost phantom wrapper. All String APIs forwarded via `Tagged+String.swift` and `Tagged+String.View.swift`. |
| 7 | `Kernel.String.View` | L1 | resolves via `Tagged: Viewable` → `swift-primitives/swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift:20` | `= String_Primitives.String.View` (typealias identity) | borrowed | yes | `~Copyable` | `~Escapable` | platform-native | **Type identity preserved**: `Kernel.String.View` IS `String_Primitives.String.View`, not a wrapper. |
| 8 | `ISO_9899.String` | L2 (or L1-style; see Q7) | `swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.swift:30` | `pointer: UnsafeMutablePointer<Char>` + `count: Int` (NOT via `Memory.Contiguous`) | owned value | **yes**, excluded from `count` | `~Copyable` (`@frozen @safe`) | Escapable | ISO C byte semantics (no declared encoding) | `deinit` deallocates. API: `init(adopting:count:)`, `init(copying: View)`, `init(copying pointer:)`, `view`, `take()`, `withUnsafePointer(_:)`, `withUnsafeMutablePointer(_:)`. |
| 9 | `ISO_9899.String.View` | L2 | `ISO_9899.String.View.swift:16` | `pointer: UnsafePointer<Char>` (NO count stored) | borrowed | yes | `~Copyable` | `~Escapable` | ISO C byte | `@safe`. API: `pointer`, `length` (computes via strlen), `withUnsafePointer(_:)`. Debug-validates NUL (scan cap 16 MiB). |
| 10 | `ISO_9899.String.Char` | L2 | `ISO_9899.String.Char.swift:21` | typealias | — | — | — | — | `UInt8` (all platforms) | **Platform-invariant**. Doc at lines 18-20: "different domain from String_Primitives.String.Char". |
| 11 | `ISO_9899.String.terminator` | L2 | `ISO_9899.String.Char.swift:25` | static let | — | — | — | — | — | `Char = 0`. |
| 12 | `ISO_9899.String.Length` (namespace) | L2 | `ISO_9899.String.Length.swift:12` | enum namespace | — | — | — | — | — | `strlen(_:)` calls C; `length(of:)` pure Swift. |
| 13 | `ISO_9899.String.Comparison` (namespace) | L2 | `ISO_9899.String.Comparison.swift:21` | enum namespace | — | — | — | — | — | `compare(_:_:) → ISO_9899.String.Order`, `compare(_:_:count:)`. |
| 14 | `ISO_9899.String.Concatenation` (namespace) | L2 | `ISO_9899.String.Concatenation.swift` | enum namespace | — | — | — | — | — | `strcat/strncat` wrappers. |
| 15 | `ISO_9899.String.Copy` (namespace) | L2 | `ISO_9899.String.Copy.swift:26` | enum namespace | — | — | — | — | — | `strcpy/strncpy`. |
| 16 | `ISO_9899.String.Memory` (namespace) | L2 | `ISO_9899.String.Memory.swift` | enum namespace | — | — | — | — | — | `memcpy/memmove/memset/memcmp`. |
| 17 | `ISO_9899.String.Search` (namespace) | L2 | `ISO_9899.String.Search.swift:20` | enum namespace | — | — | — | — | — | `strchr/strrchr/strstr/strcspn/strpbrk/strspn/strtok`. |
| 18 | `ISO_9899.String.Order` | L2 | `ISO_9899.String.Order.swift` | enum | — | — | `Sendable, Equatable, Hashable` | — | — | `.less/.equal/.greater`. Cross-platform C integer wrapper. |
| 19 | `ASCII` | L1 | `swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.swift:55` | enum namespace | — | — | — | — | — | Root namespace. Nests `Character`, `Case`, `Classification`, `Validation`, `Byte`, `SPACE`, etc. |
| 20 | `ASCII.Byte` | L1 | `ASCII.Byte.swift:24` | `rawValue: UInt8` | value | — | `Sendable` (+ implicit Equatable) | Escapable | ASCII 0x00-0x7F | Typed wrapper obtained via `UInt8.ascii` accessor. |
| 21 | `ASCII.Case` | L1 | `ASCII.swift:68` | enum | — | — | `Sendable` | — | — | `.upper/.lower`. |
| 22 | `ASCII.Character` | L1 | `ASCII.swift:59` | enum namespace | — | — | — | — | — | Nests `Control`, `Graphic`. |
| 23 | `ASCII.Character.Control` | L1 | `ASCII.Character.Control.swift` | enum namespace | — | — | — | — | — | Constants `.nul`, `.soh`, …, `.lf`, `.cr`, `.htab`, `.del`, `.crlf` (2-byte sequence). Values are `UInt8` literals. |
| 24 | `ASCII.Character.Graphic` | L1 | `ASCII.Character.Graphic.swift` | enum namespace | — | — | — | — | — | Constants `.A`-`.Z`, `.a`-`.z`, `.zero`-`.nine`, punctuation, `.sp`. |
| 25 | `ASCII.Classification` | L1 | `ASCII.Classification.swift:24` | enum namespace | — | — | — | — | — | 128-entry pre-computed lookup table. Predicates: `isWhitespace/isControl/isVisible/isPrintable/isDigit/isHexDigit/isLetter/isUppercase/isLowercase/isAlphanumeric`. |
| 26 | `ASCII.Validation` | L1 | `ASCII.Validation.swift:11` | enum namespace | — | — | — | — | — | `isASCII(_:)`, `isAllASCII(_:)` with SIMD fast-path (8-bytes-at-a-time high-bit test). |
| 27 | `ASCII.Case.Conversion` | L1 | `ASCII.Case.Conversion.swift` | enum namespace | — | — | — | — | — | `convert(_:to:)` byte-level case flip via XOR 0x20. |
| 28 | `ASCII.SPACE` | L1 | `ASCII.SPACE.swift` | enum namespace | — | — | — | — | — | `.sp: UInt8 = 0x20`. Dual-role (graphic + whitespace). |
| 29 | `ASCII.Decimal`, `ASCII.Hexadecimal`, `ASCII.Line.Ending`, `ASCII.Parsing`, `ASCII.Serialization` | L1 | various | enum namespaces | — | — | — | — | — | Sibling classification / byte-level parser families. |
| 30 | `INCITS_4_1986` | L2 | `swift-incits/swift-incits-4-1986/Sources/INCITS_4_1986/INCITS_4_1986.swift:16` | enum namespace | — | — | — | — | — | L2 spec namespace re-exporting `ASCII_Primitives` via `@_exported`. Delegates `Case = ASCII.Case`, `whitespaces = ASCII.whitespaces`. |
| 31 | `INCITS_4_1986.ASCII<Source>` | L2 | `INCITS_4_1986.ASCII.swift:36` | `source: Source` | value | — | inherits from Source | Escapable | ASCII-as-bytes | Generic wrapper providing conditional API over `Collection<UInt8>` or `StringProtocol`. |
| 32 | `INCITS_4_1986.Case` | L2 | `INCITS_4_1986.swift:22` | typealias | — | — | — | — | — | `= ASCII.Case`. |
| 33 | `INCITS_4_1986.ByteArray` | L2 | `INCITS_4_1986.ByteArray.swift` | struct | — | — | — | — | — | Namespace for byte-array classification / case. |
| 34 | `INCITS_4_1986.Character`, `.Classification`, `.Validation`, etc. | L2 | various | namespace mirror of L1 ASCII | — | — | — | — | — | Re-export with INCITS_4_1986-qualified access. |
| 35 | `Text` (namespace + phantom tag) | L1 | `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.swift:37` | enum namespace | — | — | — | — | UTF-8 assumed | Used as phantom tag for Text.Position/Offset/Count. |
| 36 | `Text.Position` | L1 | `Text.Position.swift:27` | typealias = `Tagged<Text, Ordinal>` | value | — | Copyable, Sendable, Hashable, Comparable | Escapable | byte offset | Zero-based UTF-8 byte offset. |
| 37 | `Text.Count` | L1 | `Text.Count.swift:22` | typealias = `Tagged<Text, Cardinal>` | value | — | Copyable, Sendable, Hashable | Escapable | byte count | |
| 38 | `Text.Offset` | L1 | `Text.Offset.swift:25` | typealias = `Tagged<Text, Affine.Discrete.Vector>` | value | — | Copyable, Sendable, Hashable | Escapable | signed byte displacement | |
| 39 | `Text.Range`, `.Location`, `.Line.Number`, `.Line.Column`, `.Line.Map`, `.Location.Tracker` | L1 | `Text.Range.swift:32`, etc. | structs/typealiases | — | — | all Copyable, Sendable, Hashable | Escapable | UTF-8 | Line-map infrastructure for lexers/parsers. |
| 40 | `Token` | L1 | `swift-primitives/swift-token-primitives/Sources/Token Primitives/Token.swift:29` | `kind: Kind`, `range: Text.Range` | value | — | `Sendable, Equatable, Hashable` | Escapable | — | Classified byte-range over source text. |
| 41 | `Token.Kind`, `Token.Keyword` | L1 | various | enums | — | — | `Sendable, Equatable, Hashable` | — | — | Vocabulary for lexing. |
| 42 | `Input` (namespace) | L1 | `swift-primitives/swift-input-primitives/Sources/Input Primitives/Input.swift:64` | enum namespace | — | — | — | — | — | Cursor infrastructure. Nests `Slice`, `Buffer`, `Protocol`, `Stream.Protocol`, `Access.Random`. |
| 43 | `Input.Slice`, `Input.Buffer` | L1 | `Input.Slice.swift`, `Input.Buffer.swift` | structs | value | — | Copyable | Escapable | — | Concrete cursors for consumable input. |
| 44 | `Lexer.Scanner` | L1 | `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift:36` | `source: Span<UInt8>`, `cursor: Text.Position`, `tracker: Text.Location.Tracker` | borrowed view | — | `~Copyable, ~Escapable` | `~Escapable` | UTF-8 | Byte scanner; `peek/advance/advance(by:)`. |
| 45 | `Lexer.Lexeme`, `Lexer.Trivia`, `Lexer.Error` | L1 | various | structs/enums | value | — | Copyable, Sendable, Equatable | Escapable | — | Output of lexer. |
| 46 | `Parser.Byte<Input>` | L1 | `swift-primitives/swift-parser-primitives/Sources/Parser Byte Primitives/Parser.Byte.swift:15` | `expected: UInt8` | value | — | Sendable | Escapable | — | Single-byte matcher combinator. **Scope note: out of scope** (parser combinator, not a string type). |
| 47 | `Parser.Literal<Input>` | L1 | `Parser Literal Primitives/Parser.Literal.swift:19` | `bytes: [UInt8]` | value | — | Sendable | Escapable | — | Multi-byte literal matcher. **Scope: out of scope**. |
| 48 | `Parser.Span<Input>` | L1 | `Parser Span Primitives/Parser.Span.swift` | span slot | value | — | Sendable | Escapable | — | Byte-span capture combinator. **Scope: out of scope**. |
| 49 | `RFC_3986.URI.Scheme` | L2 | `swift-ietf/swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Scheme.swift:30` | `rawValue: String` | value | — | `Sendable, Equatable, Hashable, Codable, Comparable` | Escapable | Swift.String (ASCII-only) | `CustomStringConvertible`. `Binary.ASCII.Serializable`, `Binary.ASCII.RawRepresentable`. Normalized to lowercase. |
| 50 | `RFC_3986.URI.{Authority, Host, Path, Query, Fragment, Port, Userinfo}` | L2 | `RFC 3986/*.swift` | structs over `Swift.String` | value | — | `Sendable, Equatable, Hashable` | Escapable | Swift.String with percent-encoding | Each has `.Error`, `.Parse` submodule, `Binary.ASCII.Serializable` conformance. |
| 51 | `RFC_3987.IRI` | L2 | `swift-ietf/swift-rfc-3987/Sources/RFC 3987/IRI.swift` | struct over `Swift.String` | value | — | `Sendable, Equatable, Hashable` | Escapable | Unicode (internationalized) | Wraps URL; `ValidationMode` gates strict vs lenient. |
| 52 | `RFC_3492.Punycode` | L2 | `swift-ietf/swift-rfc-3492/Sources/RFC 3492/Punycode.swift` | enum namespace | — | — | — | — | — | Encode/decode to/from `Swift.String`. |
| 53 | `RFC_5234.{Rule, Terminal, Validator, CoreRules}` | L2 | `swift-ietf/swift-rfc-5234/Sources/RFC_5234/*` | structs/enums | value | — | Sendable | Escapable | — | ABNF grammar infrastructure. |
| 54 | `RFC_5890.IDNA` | L2 | `swift-ietf/swift-rfc-5890/Sources/RFC 5890/IDNA.swift` | enum namespace | — | — | — | — | — | IDN encoding; wraps Punycode. |
| 55 | `WHATWG_URL.URL`, `.Scheme`, `.Host`, `.Path`, `.Search`, `.Href`, `.Path.Context` | L2 | `swift-whatwg/swift-whatwg-url/Sources/WHATWG URL/*.swift` | structs over `Swift.String` | value | — | `Sendable, Equatable, Hashable` | Escapable | WHATWG URL (Unicode + percent-enc) | Normalized per WHATWG; `.Error`, `.Parse`, `.Serializable`. |
| 56 | `WHATWG_URL.PercentEncoding` | L2 | `WHATWG URL/WHATWG_URL.PercentEncoding.swift` | enum namespace | — | — | — | — | — | Character-set constants + encode/decode. |
| 57 | `ECMA_48.SGR`, `.Cursor`, `.Screen` (and nested) | L2 | `swift-ecma/swift-ecma-48/Sources/ECMA 48/*.swift` | enum namespaces | — | — | — | — | ASCII escape sequences | Serialize to bytes; no String type. |
| 58 | `ISO_639.LanguageCode`, `.Alpha2`, `.Alpha3` | L2 | `swift-iso/swift-iso-639/Sources/ISO 639/*.swift` | structs | value | — | `Sendable, Equatable, Hashable` | Escapable | — | **Code-enum, not a string family member**. Flagged out-of-family. |
| 59 | `ISO_15924.{Alpha4, Numeric}`, `ISO_3166.*` | L2 | similar | structs/enums | value | — | `Sendable, Equatable, Hashable` | Escapable | — | Script, country codes. **Out-of-family**. |
| 60 | `Windows.Kernel.Path.Canonical` / `.Environment` / `.Console` | L2 | `swift-microsoft/swift-windows-standard/Sources/Windows Kernel .../*.swift` | enum/struct namespaces | — | — | — | — | UTF-16 via WCHAR | Operates on raw `UnsafePointer<WCHAR>` / `[UInt16]`. **Does NOT use `Kernel.String` or `String_Primitives.String`**. |
| 61 | `Swift.String` family bridges (L3) | L3 | `swift-foundations/swift-strings/Sources/Strings/*.swift` | extension methods | — | — | — | — | UTF-8/UTF-16 | See §3 edge list. No new concrete type introduced. |
| 62 | `Strings` module (swift-strings) | L3 | `swift-foundations/swift-strings/Sources/Strings/exports.swift` | module | — | — | — | — | — | Re-exports `String_Primitives`, `ISO_9899`. |
| 63 | `ASCII` module (swift-ascii) | L3 | `swift-foundations/swift-ascii/Sources/ASCII/exports.swift` | module | — | — | — | — | — | Re-exports `INCITS_4_1986`, `ASCII_Primitives`, `Binary_Primitives`, `Binary_ASCII_Serializable_Primitives`, `Serialization_Primitives`. |
| 64 | `Lexer.Tokenized` | L3 | `swift-foundations/swift-lexer/Sources/Lexer/Lexer.Tokenized.swift:18` | `lexemes: [Lexer.Lexeme]`, `diagnostics: [Lexer.Error]` | value | — | `Sendable, Equatable` | Escapable | — | Owned tokenization result. **Scope note: out of core string family** — composition of Token + Text primitives. |
| 65 | `Parsers.{Between, Chain, Comment, Debug, Diagnostic, Expression, Identifier, Integer, Newline, Quoted, Separated, Whitespace}` | L3 | `swift-foundations/swift-parsers/Sources/Parsers/*.swift` | combinator structs | value | — | Sendable | Escapable | — | **Scope: out of scope** — parser combinator library. |

### Storage invariants summary

| Type | Allocation | NUL terminator? | Count excludes NUL? | Char Width | Owner |
|---|---|---|---|---|---|
| `String_Primitives.String` | `Memory.Contiguous<Char>` (single heap) | **yes** (precondition in `adopting`, asserted in `copying`) | **yes** (`count = _storage.count`) | `UInt8` POSIX / `UInt16` Win | value (consumed on destruction) |
| `String_Primitives.String.View` | pointer + stored count | yes (invariant) | yes | same as parent | borrowed (`~Escapable`) |
| `ISO_9899.String` | raw `UnsafeMutablePointer<UInt8>` + count (NOT via Memory.Contiguous) | **yes** (precondition, debug-asserted) | **yes** | `UInt8` always | value; `deinit` deallocates |
| `ISO_9899.String.View` | pointer only (NO stored count) | yes (invariant) | computed via `length` (scans) | `UInt8` always | borrowed (`~Escapable`) |
| `ASCII.Byte` | single `UInt8` | n/a | n/a | `UInt8` | value |
| `Text.Position / Offset / Count` | `Tagged<Text, Affine.*>` | n/a | n/a | byte | value |
| `Lexer.Scanner` | `Span<UInt8>` + cursor | NO (not a string, borrows bytes) | — | `UInt8` | `~Escapable` |

**Asymmetry A1**: `String_Primitives.String.View` stores `count`, `ISO_9899.String.View` does NOT. The latter computes `length` via a scan on every access. The L1/L2 split is deliberate (see ISO_9899.String.View.swift:16 — no `count` field), but it means ISO_9899 consumers pay O(n) per `.length` call. *(Mirrors the Path cycle Q7 — `Paths.Path.View` had no stored count; root cause was the same L3-trust-the-NUL convention.)*

**Asymmetry A2**: `String_Primitives.String` adopts via `Memory.Contiguous<Char>`, which holds a "tracked count + NUL outside region" invariant. `ISO_9899.String` holds `pointer + count` directly and manages its own deinit deallocation. The two types use structurally different storage — there is **no shared Memory.Contiguous backing** between them. Even on POSIX where both are `UInt8`, a bridge requires full copy (edge E14 below).

### Encoding / char-width matrix

| Layer | Type | Char | Encoding | Validation at Construction | NUL-terminated? | Interior-NUL Rejection |
|---|---|---|---|---|---|---|
| L1 | `String_Primitives.String` | `UInt8` POSIX / `UInt16` Win | UTF-8 / UTF-16 *by convention* — NO runtime check | NONE | yes (required; precondition) | **NOT checked** — adopting init trusts caller |
| L1 | `String_Primitives.String.View` | same | same | DEBUG-only NUL scan (16 MiB cap) | yes | NOT checked |
| L1 | `Kernel.String` | inherited (typealias) | inherited | inherited | yes | inherited |
| L2 | `ISO_9899.String` | `UInt8` always | ISO C byte (no encoding declared) | NONE | yes (required; precondition) | NOT checked |
| L2 | `ISO_9899.String.View` | `UInt8` always | ISO C byte | DEBUG-only NUL scan (16 MiB cap) | yes | NOT checked |
| L1 | `ASCII.Byte` | `UInt8` | 7-bit ASCII | n/a (single byte) | n/a | n/a |
| L2 | `INCITS_4_1986.ASCII<Source>` | `UInt8` | 7-bit ASCII | conditional `isAllASCII` predicate (not enforced at init) | n/a | n/a |
| L2 | `RFC_3986.URI.Scheme` | (Swift.String) | Swift.String ASCII-only subset | **YES** — letters, digits, +, -, . validated in `init(ascii:in:)` | via Swift.String | — |
| L3 | `Swift.String.init(_ view: Primitives.String.View)` | Swift.String | POSIX: UTF-8 decoded via cString; Windows: UTF-16 scalar-by-scalar; replacement on invalid | POSIX uses `String(cString:)` — invalid UTF-8 replaced with U+FFFD; Windows manually iterates | — | — |
| L3 | `Swift.String.strictUTF8(_:)` | Swift.String | UTF-8 | returns `nil` on invalid sequences (strict, not lossy) | — | — |
| L3 | `Swift.String.init(_ span: Span<UInt8>) throws(UTF8.ValidationError)` | Swift.String | UTF-8 | throws `UTF8.ValidationError` on invalid; uses `UTF8Span(validating:)` | — | — |

**Encoding asymmetry flag (see §6/D4)**: No L1/L2 type validates its payload encoding. All three owned types (`String_Primitives.String`, `Kernel.String`, `ISO_9899.String`) trust the caller to supply correctly encoded bytes. UTF-8 / UTF-16 validation lives exclusively at L3 boundaries via Swift.String (which either uses cString → lossy replacement, or `strictUTF8` / `Span<UInt8>` init → strict).

---

## 3. Conversion Graph

```
                    ┌─────────────────┐
                    │ Swift.String    │ (Unicode; Ref-Counted COW)
                    └─┬─┬─┬─┬─┬─┬─┬───┘
                      │ │ │ │ │ │ │
            ┌─────────┘ │ │ │ │ │ └─────────┐
           E2a          │ │ │ │ └─E2b─┐     │
         (init-view)    │ │ │ │   (init-owned)│
            │           │ │ │ │              │
            ▼           │ │ │ │              ▼
    ┌──────────────┐    │ │ │ │    ┌──────────────┐
    │ Primitives.  │◄E6─┘ │ │ │    │ ISO_9899.    │
    │ .String.View │      │ │ │    │ .String.View │
    │ (~Esc, L1)   │      │ │ │    │ (~Esc, L2)   │
    └──┬───────────┘      │ │ │    └──┬───────────┘
       │                  │ │ │       │
    E1 │                  │ │ │    E5 │
       ▼                  │ │ │       ▼
    ┌──────────────┐◄E9───┘ │ │    ┌──────────────┐◄E10
    │ Primitives.  │        │ │    │ ISO_9899.    │
    │ .String      │───E11──┘ │    │ .String      │
    │ (~Copy, L1)  │◄───E14───┼────┤ (~Copy, L2)  │
    └──────┬───────┘          │    └──────────────┘
           │                  │           ▲
           │ E15 (tagged)     │           │
           ▼                  │           │
    ┌──────────────┐          │           │ E16 (span; POSIX only)
    │ Kernel.      │          │           │
    │ .String      │──────E17─┘           │
    │ (tagged, L1) │                      │
    └──────────────┘                      │
                                          │
                            ┌─────────────┘
                            │
                   Span<UInt8>
                   (borrowed bytes)
                            │
                   ┌────────┼─────────┐
                   ▼        ▼         ▼
                E6 alloc  E4 alloc   Parser.Byte/Literal input
                 (L1)      (validate)
```

### Edge list (public, verified against source)

| # | From | To | Mechanism | Alloc | Layer | Source |
|---|---|---|---|---|---|---|
| E1 | `Primitives.String.View` | `Primitives.String` | `init(copying:)` | yes (buffer+NUL) | L1 | `swift-string-primitives/Sources/String Primitives/String.swift:87` |
| E2a | `Swift.String` | `Primitives.String.View` (scoped) | `withPrimitivesView(_:)` | yes (scoped alloc + free) | L3 | `swift-strings/Sources/Strings/Swift.String+Primitives.swift:127` |
| E2b | `Swift.String` | `Primitives.String` | `init(_ string: Swift.String)` | yes (`[Char]` copy + NUL) | L3 | `Swift.String+Primitives.swift:87` |
| E3 | `Span<Char>` | `Primitives.String` | `init(_ span:)` | yes (alloc + copy + NUL) | L1 | `String.swift:99` |
| E4 | `Span<UInt8>` | `Swift.String` | `init(_ span:) throws(UTF8.ValidationError)` | yes (validates via `UTF8Span`) | L3 | `Swift.String+Primitives.swift:72` |
| E5 | `Primitives.String.View` | `Swift.String` | `init(_ view:)` | yes (POSIX: cString decode, lossy; Windows: scalar loop) | L3 | `Swift.String+Primitives.swift:19` |
| E6 | `StaticString` (ASCII only) | `Primitives.String` | `init(ascii literal: StaticString)` | yes (alloc + copy + NUL + widen-on-Win) | L1 / L3 | `String.swift:115` and `swift-ascii/Sources/ASCII/String_Primitives.String+ASCII.swift:31` |
| E7 | `UnsafeMutablePointer<Char>` + count | `Primitives.String` | `init(adopting:count:)` | adopts (no alloc) | L1 | `String.swift:76` |
| E8 | `Primitives.String` | consuming → `Swift.String` | `init(_ owned: consuming Primitives.String)` | yes (decode) | L3 | `Swift.String+Primitives.swift:43` |
| E9 | `Primitives.String` | `Primitives.String.View` | `view` property | no (borrow) | L1 | `String.swift:150` |
| E10 | `ISO_9899.String` | `ISO_9899.String.View` | `view` property | no (borrow) | L2 | `ISO_9899.String.swift:115` |
| E11 | `Primitives.String` | consuming → ptr + count | `take()` | no | L1 | `String.swift:178` |
| E12 | `Swift.String` | `ISO_9899.String` | `init(_ string: Swift.String)` | yes (UTF-8 buffer + NUL) | L3 | `Swift.String+ISO_9899.swift:43` |
| E13 | `Swift.String` | `ISO_9899.String.View` (scoped) | `withISO9899View(_:)` | yes (scoped) | L3 | `Swift.String+ISO_9899.swift:70` |
| E14 | `ISO_9899.String.View` | `Primitives.String` (POSIX only) | `init(_ view:)` | yes (byte copy + NUL) | L3 | `ISO_9899.String+Primitives.swift:44` |
| E15 | `Primitives.String` ↔ `Kernel.String` | lift/unwrap via `Tagged` | `init(__unchecked:_:)` / `rawValue` | zero-cost | L1 | `Tagged+String.swift:47` |
| E16 | `Primitives.String.View` ↔ `ISO_9899.String.View` (POSIX only) | `ISO_9899.String.init(_ view:)` etc. | yes (byte copy) | — | L3 | `ISO_9899.String+Primitives.swift:23` |
| E17 | `Kernel.String.View` | `Swift.String` | `Swift.String.init(_ string: borrowing Kernel.String)` | yes (decode) | L3 | `swift-kernel/Sources/Kernel File/Swift.String+Kernel.swift:57` (**package**, not public) |
| E18 | `Kernel.Path.View` | `Swift.String` | `Swift.String.init(_ view: borrowing Kernel.Path.View)` | yes (decode) | L3 | `Swift.String+Kernel.swift:41` (public) |
| E19 | `ISO_9899.String` consumed | `Swift.String` | `init(_ owned: consuming ISO_9899.String)` | yes | L3 | `Swift.String+ISO_9899.swift:29` |
| E20 | `getenv(3)` (POSIX libc) | `Kernel.String.View` (scoped) | `ISO_9945.Kernel.Environment.withValue(_:_:)` | no (borrows process-global) | L2 | `ISO 9945.Kernel.Environment.swift:74` |
| E21 | `getenv(3)` | `Kernel.String` (owned copy) | `ISO_9945.Kernel.Environment.get(_:)` | yes (`Kernel.String(copying: view)`) | L2 | `ISO 9945.Kernel.Environment.swift:99` |
| E22 | `GetEnvironmentVariableW` (Win32) | `[UInt16]?` | `Windows.Kernel.Environment.get(name:)` | yes (Array) | L2 | `Windows.Kernel.Environment.swift:48` (**does NOT go through Kernel.String**) |
| E23 | `realpath(3)` (libc) | `Kernel.String` | `ISO_9945.Kernel.Path.Canonical.canonicalize(_:)` | yes (libc-freed after copy) | L2 | `ISO 9945.Kernel.Path.Canonical.swift:127` |

### Conversion asymmetries

- **`Primitives.String` ↔ `ISO_9899.String`: no zero-copy bridge**, even on POSIX where both are `UInt8`. Must go through Swift.String or re-allocate (E12 + E14). This is by design per doc at `ISO_9899.String+Primitives.swift:62-78`: on Windows, encoding decisions are explicit; on POSIX, deliberately keeps domains separate.
- **Swift.String ↔ everything**: Swift.String is the universal converter; costs one allocation per edge.
- **Kernel.String ↔ Swift.String is `package`**: `Swift.String.init(_ string: borrowing Kernel.String)` at `Swift.String+Kernel.swift:57` is `package`-scope, not `public`. Contrast with `Swift.String.init(_ path: Kernel.Path)` at line 24 (public). This is intentional — see Q4.
- **Windows completely bypasses the Kernel.String abstraction**: `Windows.Kernel.Environment` uses raw `UnsafePointer<WCHAR>` + `[UInt16]` directly against WinSDK (lines 25-69). There is no bridge from `Windows.Kernel.Environment.get(name:)` result into `Kernel.String`. Asymmetric with `ISO_9945.Kernel.Environment.get(_:)` which returns `Kernel.String`.
- **No ASCII typed char bridge at L1/L2**: `ASCII.Byte` wraps `UInt8` but has no corresponding `ASCII.String` or `ASCII.View` owned type. `String_Primitives.String.init(ascii:)` goes bytes→Primitives, but the reverse (`Primitives.String` → `ASCII.Byte`s) is a custom scan — no first-class `.ascii` accessor.

---

## 4. Boundary Summary (Protocol / Conformance State)

### Protocols declared for strings

**None.** Unlike paths (which have `Path.Decomposition` + `Path.Modification` at L1 after the path cycle), strings have no protocol bundling:

- **No `String.Protocol`** analogous to `Path.Decomposition` exists.
- **No `String.Validation.Protocol`** to unify UTF-8 / UTF-16 / ASCII validation shapes.
- **No `String.Encoded.Protocol`** to generalize `Primitives.String` / `ISO_9899.String` / `Kernel.String`.
- **No `String.View.Protocol`** to generalize view types over shared `Char` + `count/length` access.

Conforming types share a *structural* pattern:
1. Owned type with `pointer` (or `Memory.Contiguous<Char>`) + NUL-terminator + `count`.
2. View struct `~Copyable, ~Escapable` with `pointer` + optionally `count`.
3. `init(copying: View)`, `view` accessor, `take()` consuming.
4. Debug validation scanning for NUL in view constructors.

But this pattern is duplicated by convention, not enforced by a protocol.

### Sub-view extension protocols

- `Primitives.String` conforms to `Memory.Contiguous.Protocol` via `withUnsafeBufferPointer(_:)` (`String.swift:185`).
- `Tagged` where `RawValue == String, Tag: ~Copyable` conforms `@retroactive Memory.Contiguous.Protocol` (`Tagged+String.swift:100`).
- `ISO_9899.String` does NOT conform to `Memory.Contiguous.Protocol` (uses raw pointer+count, not `Memory.Contiguous`).
- `RFC_3986.URI.Scheme` conforms `Binary.ASCII.Serializable`, `Binary.ASCII.RawRepresentable` (`RFC_3986.URI.Scheme.swift:122`). Other RFC_3986 / WHATWG types follow the same pattern.

### Platform-specific conformances (syscall-adjacent)

| Conformer | Location | Status |
|---|---|---|
| Path.View conformances: `Path.Decomposition`, `Path.Modification` (POSIX) | `swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.View+Path.Decomposition.swift`, `+Path.Modification.swift` | **DONE** (path cycle) |
| Path.View conformances: Windows | (not present) | **missing** (known, path cycle Phase 4a Windows pending) |
| `Kernel.String.View`: any protocol conformance | — | **No protocol exists** to conform to |

### Missing Windows bridges (flag)

| Missing file | Analogy to POSIX |
|---|---|
| `Windows.Kernel.Environment` → `Kernel.String` bridge | `ISO_9945.Kernel.Environment.get(_:) -> Kernel.String?` exists on POSIX; Windows version returns `[UInt16]` |
| `Windows.Kernel.Path.Canonical` → `Kernel.String` bridge | `ISO_9945.Kernel.Path.Canonical.canonicalize(_:) -> Kernel.String` exists on POSIX; Windows version returns written-count into caller's `UnsafeMutableBufferPointer<UInt16>` |
| Any Windows use of `String_Primitives.String` | zero — the Windows stack uses WCHAR pointers exclusively |

**Finding**: The `Kernel.String` abstraction (meant to be platform-agnostic per its doc-claim of UTF-8/UTF-16 encoding) is **not actually used on Windows**. `Windows.Kernel.Environment` sidesteps it entirely. The platform equivalence implied by `String_Primitives.String.Char` being `UInt16` on Windows is not exercised in the Windows L2 syscall layer.

---

## 5. Method/API Surface at High-Risk Entry Points

### 5.1 Encoding validation at the L3 → L1 boundary

`Swift.String(_ view: borrowing String_Primitives.String.View)` — `Swift.String+Primitives.swift:19-35`:

- **POSIX branch** (line 33): `Swift.String(cString: view.pointer)`. This is the standard library's lossy UTF-8 decoder — invalid sequences become U+FFFD. No thrown error.
- **Windows branch** (line 23-30): manual loop, `Unicode.Scalar(current.pointee)` returns `nil` for lone surrogates → **silently dropped**, no error.
- **Stakes**: The round-trip `Swift.String → Primitives.String → Swift.String` is lossy on malformed input on BOTH platforms. Contrast `Swift.String.strictUTF8(_:)` which returns `nil` on invalid.

`Swift.String.init(_ span: Span<UInt8>) throws(UTF8.ValidationError)` — `Swift.String+Primitives.swift:72`:

- Uses `UTF8Span(validating: span)` → `Swift.String(copying:)`. Strict. Fails loudly. **This is the right shape**; existing lossy edges don't share it.

### 5.2 ASCII literal init on `Primitives.String`

- `init(ascii literal: StaticString)` at `String.swift:115` (L1) and `swift-ascii/Sources/ASCII/String_Primitives.String+ASCII.swift:31` (L3).
- **L1 version**: does NOT precondition-check ASCII range. Trusts the literal on POSIX; on Windows widens each UTF-8 byte to UTF-16 (line 121) assuming byte < 0x80.
- **L3 version**: preconditions `byte < 0x80` for each byte (line 38). Explicitly rejects non-ASCII.
- **Divergence**: two `init(ascii:)` methods exist (L1 in `swift-string-primitives`, L3 in `swift-ascii`). The L3 one shadows the L1 one when both imports are present. The L3 one is stricter.

### 5.3 `ISO_9899.String.Length.strlen` vs pure Swift `length(of:)`

`ISO_9899.String.Length.swift:15-42`:

- `strlen(_:)` calls `iso9899_strlen` (C shim via `CISO9899String`).
- `length(of:)` is identical semantics in pure Swift (line 36-43).
- **Two functions do the same thing**. The pure-Swift one also exists at `String_Primitives.String.length(of:)` (`String.Length.swift:20-26`). **Triplicated scan** across L1/L2.

### 5.4 Environment variable fetch

- POSIX: `ISO_9945.Kernel.Environment.withValue(_:_:)` wraps `getenv` result as `Kernel.String.View` (line 84).
- POSIX: `ISO_9945.Kernel.Environment.get(_:)` uses `Kernel.String(copying: view)` (line 101) — owned copy.
- Windows: `Windows.Kernel.Environment.get(name:) -> [UInt16]?` allocates `[UInt16]` directly (line 48-69). **Never produces a `Kernel.String`**.

**Risk**: downstream code that needs to use an environment variable portably must either (a) branch per platform, or (b) go through `Swift.String` (which requires L3), or (c) reinvent a cross-platform wrapper.

### 5.5 RFC / WHATWG parse entry points

All L2 spec types (`RFC_3986.URI.Scheme`, `URL.Host`, etc.) have `init<Bytes: Collection>(ascii bytes:)` that validates per-spec grammar (e.g., `RFC_3986.URI.Scheme.swift:89-117`). The parse logic uses:
- Per-byte classification via `byte.ascii.isLetter` / `.isDigit` / explicit byte comparisons.
- On failure, throws `Self.Error` with the bytes embedded as `Swift.String(decoding: bytes, as: UTF8.self)` in the error message (line 96, 107).

**Observation**: L2 parse paths depend on ASCII classification from `ASCII_Primitives.ASCII.Byte` (via `byte.ascii` accessor from `swift-ascii-primitives/Sources/ASCII Primitives/UInt8+ASCII.swift`), not on `INCITS_4_1986.ASCII<Source>`. Meaning `INCITS_4_1986.ASCII<Source>` at L2 is a **parallel namespace** serving a different use case (collection-level API) from the L1 byte-level API that RFC parsers actually use.

### 5.6 Lexer scanning

`Lexer.Scanner.peek` / `.advance` / `.advance(by:)` (`Lexer.Scanner.swift:78-105`) operates on `Span<UInt8>` — **byte-level**, not character-level. Line tracking via `Text.Location.Tracker` maintains `Text.Line.Number` / `Text.Line.Column` separately. The scanner does NOT know about Unicode grapheme boundaries; consumers must handle those out-of-band.

---

## 6. Divergence Flags — Highest Stakes First

### D1 — Three parallel owning string types with no unification protocol (**highest stakes**)

`Primitives.String`, `ISO_9899.String`, and `Kernel.String` (plus `Swift.String`) are four distinct concrete types with overlapping-but-divergent shapes. There is no `String.Protocol` abstracting `Char`, `view`, `init(copying:)`, `take()` — so generic code over "owned NUL-terminated string" cannot be written. Every bridge is a concrete pair-wise conversion (§3 edges E1–E23), producing an N² fan-out of bridge methods.

**Stakes**: every new L2 package that needs to own a string must pick one of the three, and every bridge costs an alloc + copy even when the byte representation is identical. The L2 ASCII byte chain (`swift-ascii-primitives` → `swift-incits-4-1986` → `swift-ascii`) has its own typed `ASCII.Byte` which doesn't appear in any string type's interface.

### D2 — `ISO_9899.String.View` has no stored count (scan-on-every-length)

`ISO_9899.String.View.swift:16-19` stores only `pointer: UnsafePointer<Char>`. Every `.length` call (line 77-79) does `ISO_9899.String.length(of: pointer)` — an O(n) scan.

Contrast `Primitives.String.View.swift:33-38` which stores both `pointer` and `count`. `Paths.Path.View` had the same issue (see path-type-ecosystem-model.md §7/Q7); it was left unresolved in the path cycle.

### D3 — Windows backend completely bypasses `Kernel.String` / `Primitives.String`

`Windows.Kernel.Environment` (line 25-69) uses raw `UnsafePointer<WCHAR>` and returns `[UInt16]?`. No use of `Kernel.String`. No use of `String_Primitives.String`. The two families co-exist without meeting on Windows. Meanwhile `ISO_9945.Kernel.Environment.get(_:) -> Kernel.String?` on POSIX.

**Stakes**: `Kernel.String` claims to be platform-agnostic (UTF-8 POSIX / UTF-16 Windows) per its doc at `Kernel.String.swift:30-33`, but the Windows shim layer doesn't use it. The claim is aspirational, not actual.

### D4 — No encoding validation on owned string construction

`Primitives.String.init(adopting:count:)`, `ISO_9899.String.init(adopting:count:)`, `Kernel.String.init(adopting:count:)` all **trust the caller** to supply correctly encoded bytes. Only NUL termination is precondition-checked, and only in DEBUG (`String.swift:78`, `ISO_9899.String.swift:61`).

UTF-8 / UTF-16 validation lives exclusively at L3 (Swift.String bridges). If L2 syscall results (e.g., `realpath` on macOS with legacy filenames) return bytes that aren't valid UTF-8, they'll be silently accepted at L1 and silently replaced at L3. No type carries an "encoding invariant is verified" marker.

### D5 — Duplicated `strlen`-equivalent across three layers

- L1: `String_Primitives.String.length(of:)` (pure Swift)
- L2: `ISO_9899.String.length(of:)` (pure Swift, same algorithm)
- L2: `ISO_9899.String.Length.strlen(_:)` (C shim)

All three compute `strlen(str)`. No shared implementation. Path cycle lesson: centralize via a canonical scan at the lowest applicable layer. Candidate: `Primitives.String.length(of:)` as canonical, ISO_9899 delegates.

### D6 — ASCII literal constructor diverges between L1 and L3

`String_Primitives.String.init(ascii:)`:
- **L1** (`String.swift:115`): trusts the literal on POSIX; widens to UTF-16 on Windows (**assuming** byte < 0x80 without checking).
- **L3** (`swift-ascii/Sources/ASCII/String_Primitives.String+ASCII.swift:31`): precondition-checks `byte < 0x80`.

Both live under the same `init(ascii literal: StaticString)` signature. The L1 version is the fallback when `swift-ascii` isn't imported. Compound-method naming is fine here, but two competing implementations on the same init is a layering smell.

### D7 — `Swift.String(Kernel.String)` is `package`-scope, not `public`

`Swift.String+Kernel.swift:57`: `package init(_ string: borrowing Kernel.String)`. Adjacent `init(_ path: Kernel.Path)` and `init(_ view: Kernel.Path.View)` are both `public`. The demotion was deliberate (commit `46dd8eb`, message "Demote Kernel_String_Primitives import in Kernel File"). **Effect**: external consumers cannot render a `Kernel.String` to `Swift.String` directly; they must go through `.view.pointer` + `cString` manually, or go up through `String_Primitives.String`. This is unusual given the symmetry break.

### D8 — `Primitives.String` is `@unsafe @unchecked Sendable`, `ISO_9899.String` has no Sendable

`String_Primitives.String`: `@safe public struct String: ~Copyable, @unsafe @unchecked Sendable` (`String.swift:47`).

`ISO_9899.String`: `@frozen @safe public struct String: ~Copyable` (`ISO_9899.String.swift:30`). No Sendable conformance.

**Stakes**: ~Copyable types don't need `Sendable` to move across isolation boundaries (move relinquishes access). But the asymmetry is noticeable — if both are pointer-backed owned buffers, why does one need `@unchecked Sendable` and the other not? Possibly intentional (Primitives is meant for cross-thread OS paths; ISO_9899 is meant for C interop and stays on one thread). Worth documenting.

### D9 — `bytes` convention not well-defined for strings

Path cycle resolved `.bytes` ambiguity by renaming L1 `.bytes` → `.content`. For strings, there is no `bytes` property on `Primitives.String` or `ISO_9899.String` — consumers use `.span` (excluding NUL, on both `Primitives.String.span` line 159 and `Primitives.String.View.span` line 100). But the L2 `ISO_9899.String` doesn't expose `.span` at all — consumers must go via `.view.pointer` + `withUnsafePointer` (line 97) or `view.span` (which does NOT exist in ISO_9899). **This is asymmetric**.

Mirror-check: `Paths.Path.bytes` included NUL; `Path_Primitives.Path.bytes` excluded NUL. For strings, `Primitives.String.span` excludes NUL. No L3 string has a `.bytes` — but the equivalent decision (L2 `ISO_9899.String` has no `.span` at all) will surface the same ambiguity when one is added.

### D10 — No cross-platform `Kernel.String.View: Protocol` equivalent of `Path.View: Protocol`

Path cycle added `Path.View+Path.Decomposition.swift` conformances at L2. For strings there is no corresponding `String.Protocol` to conform to, so L2 has no `Kernel.String.View+StringOps.swift` etc. **If the correction cycle introduces a protocol**, a second L2 file per platform will be needed (POSIX + Windows). Windows lacks the platform coverage (D3) to do this cleanly.

### D11 — Compound identifier violations (spot-check)

Grepped for `firstOccurrence`, `firstIndex`, `lastIndex`, `substring`, `replacing`, `trimming` in both `swift-string-primitives` and `swift-strings`. **Zero matches.** The string L1/L3 core is clean of `[API-NAME-002]` violations. (INCITS_4_1986.ASCII trims — `.trimming(_:)` — but that's a verb method, not a compound identifier.) ASCII predicates use `is*` which is idiomatic-method form, not compound identifier.

### D12 — `Lexer.Scanner` borrows `Span<UInt8>` but `Primitives.String.span` is `Span<Char>` (Char ≠ UInt8 on Windows)

On Windows, `String_Primitives.String.span: Span<Char> = Span<UInt16>`. But `Lexer.Scanner` is defined over `Span<UInt8>` (`Lexer.Scanner.swift:38`). **Bridging a String into a Scanner on Windows requires UTF-16 → UTF-8 re-encode**. No existing bridge does this; it's a latent constraint.

---

## 7. Open Questions / Uncertainties

### Q1 — Should there be a `String.Protocol` (or `String.Encoded.Protocol`)?

Three owned string types with overlapping API surface (§4). A protocol bundling `Char`, `count`, `view`, `init(copying: View)`, `take()`, and maybe `withUnsafePointer(_:)` would:

- unify generic code over strings
- document the invariants (NUL-terminated, `count` excludes NUL)
- enable cross-type retroactive conformances at L2 (e.g., `ISO_9899.String.View: @retroactive String.Decomposition`)

But the shapes differ (stored count vs scan; `Memory.Contiguous` vs raw pointer) enough that a single protocol might force one side to adopt the other's cost model. Alternative: an abstract `String.Strict.Protocol` (validated UTF-8) distinct from `String.Lenient.Protocol` (arbitrary bytes).

### Q2 — Should `ISO_9899.String` be at L1 or L2?

Its storage model is distinct from `Primitives.String` (no `Memory.Contiguous`). Its doc emphasizes it's "different domain" (ISO_9899.String.Char.swift:18-20). It is imported by `swift-strings` at L3 alongside `String_Primitives` (see `exports.swift`). But its location (`swift-iso/swift-iso-9899/`) says L2 (specification). If this is "the C byte string type", arguably it's a tier-0 primitive (the C standard is the most foundational spec). **The placement is consistent with "L2 = spec implementations"** — ISO 9899 is a spec — but the type itself feels L1-shaped.

### Q3 — Are `swift-text-primitives`, `swift-token-primitives`, `swift-input-primitives`, `swift-lexer-primitives` string family members?

**Judgment: partial.** Call these "lexing infrastructure":

- `swift-text-primitives`: types for tracking positions/ranges in text. **Adjacent to strings** (it's byte-offset accounting), but not itself a string type. → Include in the family (auxiliary tier).
- `swift-token-primitives`: `Token` pairs a `Kind` with a `Text.Range`. Not a string. → Include (auxiliary).
- `swift-input-primitives`: generic consumable cursor over any `Collection`. Not string-specific. → **Exclude from family** (it's a collection-iteration primitive that happens to be used by lexers).
- `swift-lexer-primitives`: `Scanner` over `Span<UInt8>`, producing `Lexeme`. String-specific consumer. → Include.

Rationale: string family = types describing OR validating OR slicing string-shaped bytes. Input primitives generalizes to non-byte collections.

### Q4 — Should `Swift.String(Kernel.String)` be promoted from `package` back to `public`?

Commit `46dd8eb` demoted it. The change message ("Demote Kernel_String_Primitives import in Kernel File") implies the demotion was for module-visibility reasons (the `public import Kernel_String_Primitives` leaked through). Alternative: keep `Kernel_String_Primitives` internal + add a `public` init that manually opens the typealias. Worth asking the user whether `Kernel.String` is a public vocabulary type (then the bridge should be public) or an internal implementation detail (then fine).

### Q5 — Is `INCITS_4_1986.ASCII<Source>` duplicative of `ASCII.Classification`?

`INCITS_4_1986.ASCII<Source>.isAllWhitespace` (L2, `INCITS_4_1986.ASCII.swift:358-360`) delegates to `INCITS_4_1986.ByteArray.Classification.isAllWhitespace(source)`. But the same predicate exists at L1 as `ASCII.Classification.isWhitespace(_:)` over a single byte. The L2 generic wrapper provides collection-level API that doesn't exist at L1. **Not redundant.** But `INCITS_4_1986.ByteArray.Classification` contains byte-level predicates mirroring L1 — possibly redundant. Need deeper check.

### Q6 — Should `ASCII_Primitives.ASCII.Byte` be replaced by a tagged type?

`ASCII.Byte` is a struct wrapping `UInt8` with `init(rawValue:)` and `@_transparent`. It has no Tagged conformance. `Tagged<ASCII, UInt8>` or similar could give it phantom-type safety + free Equatable/Hashable/Comparable. But `ASCII.Byte` adds no Tagged features — it's a manually-defined single-purpose wrapper. Is this a legacy type predating Tagged, or is there a reason (maybe conformance shape) to keep it bespoke?

### Q7 — Does `ISO_9899.String` belong in `swift-iso-9899`?

It's the only type in ISO 9899 that's not a pure C-function namespace. It has behavior (`init(adopting:)`, `deinit`, `take`) that's spec-independent. Yet the C standard's `<string.h>` requires having *some* string type to operate on. **Placement is defensible** (it's the canonical C byte string) but the type itself is more of a primitive than a spec. Mirror of Q2.

### Q8 — What is the scope boundary of swift-parsers / swift-lexer?

`swift-parsers` (L3 foundation) offers parser combinators over any `Input.Protocol`-conforming source. It's downstream of strings — it *consumes* string-shaped bytes but doesn't add new string types. Scope: **out of string family**. Same for `swift-parser-primitives` (35 sub-targets) and `swift-parser-machine-primitives`.

`swift-lexer` (L3) offers `Lexer.tokenize(_:) -> Lexer.Tokenized`. Same kind — consumes bytes. Scope: **out of string family** (belongs to a lexing family).

**Scope decision**: model includes `swift-text-primitives`, `swift-token-primitives`, `swift-lexer-primitives` as auxiliary (row 35-45 in type table, tagged "auxiliary"). `swift-input-primitives`, `swift-parser-*-primitives`, `swift-binary-parser-primitives`, `swift-parser-machine-primitives`, `swift-lexer` (L3), `swift-parsers` (L3) are excluded from the string family.

### Q9 — Should UTF-8 / Unicode have their own L2 packages?

**No RFC 3629, no Unicode 15, no ISO 10646.** The ecosystem leans on Swift stdlib for `UTF8()`, `UTF8Span`, `UTF8.ValidationError`, Unicode normalization. This means:

- UTF-8 validation is in Swift stdlib (`UTF8.decode`, `String(_ span:) throws(UTF8.ValidationError)`)
- Unicode grapheme boundaries are in Swift stdlib (`Character`, `Unicode.Scalar`)
- Unicode case folding (full fold, not ASCII-only) is in Swift stdlib (`String.lowercased()`)

**Decision point**: is Swift stdlib's Unicode sufficient? If yes, the absence is a feature (no duplication with stdlib). If no, a `swift-rfc-3629` (UTF-8) and `swift-unicode-15-1-0` (or whatever the Unicode version is targeted) would be needed. The precedent in path cycle was NOT to duplicate stdlib; paths use `Swift.String(cString:)` rather than re-implementing UTF-8 decoding. Suggest the same here.

### Q10 — Stale build-error claim

The handoff says `swift-file-system` has a `Swift.String(Kernel.String)` compile failure. **Verification: stale.** `swift-file-system` contains zero references to `Kernel.String` or `Kernel_String_Primitives` anywhere in its sources (verified via grep on 2026-04-18). The `package`-scoped init at `Swift.String+Kernel.swift:57` is the *only* `Kernel.String → Swift.String` bridge in the ecosystem; it appears not to block any L3 package. The correction-cycle prompt should remove this claim before downstream phases.

### Q11 — Scope of `swift-text-primitives` (pure Tagged aliases or something more?)

`Text` is a phantom tag, `Text.Position/Offset/Count/Range/Location/Line.*` are typealiases and small structs. Not a string type. Included as auxiliary because lexer/parser code can't work without it. Alternative: treat as a byte-position family separate from strings.

---

## Appendix A — Canonical file paths for agents

```
L1 string-primitives:
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/String.swift
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/String.View.swift
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/String.Char.swift
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/String.Length.swift
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/Tagged+String.swift
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/Tagged+String.View.swift
  /Users/coen/Developer/swift-primitives/swift-string-primitives/Package.swift

L1 kernel-primitives (Kernel.String tagged wrapper):
  /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel String Primitives/Kernel.String.swift
  /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel String Primitives/exports.swift

L1 ascii-primitives:
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Byte.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Classification.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Validation.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Character.Control.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Character.Graphic.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Case.Conversion.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/UInt8+ASCII.swift
  /Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/Character+ASCII.swift

L1 text / token / lexer primitives (auxiliary):
  /Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.swift
  /Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Position.swift
  /Users/coen/Developer/swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Line.swift
  /Users/coen/Developer/swift-primitives/swift-token-primitives/Sources/Token Primitives/Token.swift
  /Users/coen/Developer/swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift

L2 ISO 9899:
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.swift
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.View.swift
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.Char.swift
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.Length.swift
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.Comparison.swift
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.Copy.swift
  /Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.Search.swift

L2 ISO 9945 (POSIX Kernel.String consumers):
  /Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Environment/ISO 9945.Kernel.Environment.swift
  /Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.Canonical.swift

L2 INCITS 4-1986:
  /Users/coen/Developer/swift-incits/swift-incits-4-1986/Sources/INCITS_4_1986/INCITS_4_1986.swift
  /Users/coen/Developer/swift-incits/swift-incits-4-1986/Sources/INCITS_4_1986/INCITS_4_1986.ASCII.swift
  /Users/coen/Developer/swift-incits/swift-incits-4-1986/Sources/INCITS_4_1986/INCITS_4_1986.ByteArray.swift

L2 IETF (URI / IRI / ABNF / Punycode / IDN):
  /Users/coen/Developer/swift-ietf/swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Scheme.swift
  /Users/coen/Developer/swift-ietf/swift-rfc-3987/Sources/RFC 3987/IRI.swift
  /Users/coen/Developer/swift-ietf/swift-rfc-3492/Sources/RFC 3492/Punycode.swift
  /Users/coen/Developer/swift-ietf/swift-rfc-5234/Sources/RFC_5234/RFC_5234.Rule.swift
  /Users/coen/Developer/swift-ietf/swift-rfc-5890/Sources/RFC 5890/IDNA.swift

L2 WHATWG:
  /Users/coen/Developer/swift-whatwg/swift-whatwg-url/Sources/WHATWG URL/WHATWG_URL.URL.swift

L2 ECMA 48:
  /Users/coen/Developer/swift-ecma/swift-ecma-48/Sources/ECMA 48/ECMA_48.swift

L2 Windows standard (absent Kernel.String):
  /Users/coen/Developer/swift-microsoft/swift-windows-standard/Sources/Windows Kernel Environment Standard/Windows.Kernel.Environment.swift
  /Users/coen/Developer/swift-microsoft/swift-windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Path.Canonical.swift

L3 strings / ascii / kernel:
  /Users/coen/Developer/swift-foundations/swift-strings/Sources/Strings/Swift.String+Primitives.swift
  /Users/coen/Developer/swift-foundations/swift-strings/Sources/Strings/Swift.String+ISO_9899.swift
  /Users/coen/Developer/swift-foundations/swift-strings/Sources/Strings/ISO_9899.String+Primitives.swift
  /Users/coen/Developer/swift-foundations/swift-strings/Sources/Strings/Swift.String+StrictDecode.swift
  /Users/coen/Developer/swift-foundations/swift-strings/Sources/Strings/exports.swift
  /Users/coen/Developer/swift-foundations/swift-ascii/Sources/ASCII/String_Primitives.String+ASCII.swift
  /Users/coen/Developer/swift-foundations/swift-ascii/Sources/ASCII/exports.swift
  /Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel File/Swift.String+Kernel.swift

L3 lexer / parsers (auxiliary; scope-borderline):
  /Users/coen/Developer/swift-foundations/swift-lexer/Sources/Lexer/Lexer.Tokenized.swift
  /Users/coen/Developer/swift-foundations/swift-parsers/Sources/Parsers/exports.swift
```

---

## Appendix B — Recent commit evidence

**swift-string-primitives** (recent string-touching commits):
- `3ec03cc` — Mark String @unsafe (Category B, 1 site)
- `26f8fbe` — Add String.init(_ span: Span<Char>) — prism inverse of .span

**swift-kernel-primitives** (Kernel.String history):
- `8d9b9fa` — Make Segment.literal and Atom.literal byte-oriented
- `eaeff96` — Extract Descriptor, String, and Random into dedicated satellites
- `58077a4` — Migrate Kernel.Path to owned storage backed by String_Primitives.String
- `8cdec42` — Refactor Kernel.Path.Char from CChar to UInt8 on POSIX
- `943e26a` — Remove deprecated Kernel.String helper types
- `5bda14e` — Add Error_Primitives and String_Primitives dependencies

**swift-ascii-primitives** (recent ASCII-layer work):
- `a00aca5` — Audit: Category B migration complete, Step 5 blocked on ecosystem regression
- `0c66479` — Resolve OQ1 (B + α) and complete Step 0 verification

**swift-foundations/swift-kernel** (Kernel.String bridge demotion):
- `46dd8eb` — Demote Kernel_String_Primitives import in Kernel File *(the `package` init introduction)*
- `aea2d88` — Remove Kernel.File.Write and Kernel.Continuation subsystems, widen String(Path) visibility

**swift-foundations/swift-strings** (bridges):
- `33f32fc` — Add Swift.String.init(_ span: Span<UInt8>) throws(UTF8.ValidationError)
- `2d01c04` — Suppress SIL CopyPropagation false positive on withISO9899View/withPrimitivesView

**swift-foundations/swift-file-system** (verified stale handoff claim):
- `74002b7` — Migrate path.lastComponent callers to path.components.last *(path cycle output; no string changes)*
- `9f9ca41` — Fix type conversions and platform-conditional random generation *(no string-related changes)*
- `524e9d7` — Fix String type shadowing from String_Primitives transitive imports *(the actual issue — resolved earlier)*

---

*Model complete. Verified by reading each cited source file. No code changes made; no builds run.*
