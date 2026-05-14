# Streaming JSON Deserialize: Status Quo and Prior Art

<!--
---
version: 1.0.0
last_updated: 2026-05-14
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to:
  - swift-foundations/swift-json
  - swift-ietf/swift-rfc-8259
  - swift-primitives/swift-parser-primitives
  - swift-primitives/swift-binary-parser-primitives
verification_experiment: parse-performance-bench (extant; codable-lookup mode produced the 37% finding)
trigger: HANDOFF-streaming-json-deserialize-research.md (Phase 1)
related:
  - swift-foundations/swift-json/Research/parse-performance.md v1.2.1 (DECISION)
  - swift-foundations/swift-json/Research/parse-performance-architecture.md v1.0.2 (DECISION)
  - swift-foundations/swift-json/Research/value-tree-redesign-v2.md v1.1.0 (SUPERSEDED-BY-EVIDENCE)
  - swift-institute/Research/copyable-wrapper-vs-multi-buffer-storage.md v1.0.1 (RECOMMENDATION)
---
-->

## Context

The v1.2.1 honest-framing amendment to
`swift-foundations/swift-json/Research/parse-performance.md`
(DECISION, 2026-05-14) measured a structural performance gap between
swift-json and Foundation on the schema-known decode path. The
canonical workload (86 MB pretty-printed Swift stdlib symbol graph,
`Symbol` schema declaring `kind.identifier + identifier.precise +
pathComponents` — three string fields per symbol against ~9 native
keys per symbol):

| Use case | Foundation | swift-json | Outcome |
|----------|-----------|------------|---------|
| Dynamic / schema-less | `JSONSerialization` 0.30 s parse + 46 ms/iter lookup | `JSON.parse` 0.30 s + 3.16 ms/iter | swift-json **14× faster on lookup** |
| Schema-known (Codable / Serializable) | `JSONDecoder().decode(T.self, …)` **0.220 s** parse+decode + 1.6 ms/iter | `T(jsonBytes: …)` **0.349 s** + 1.72 ms/iter | Foundation **37 % faster on parse+decode**; ≈ equal on lookup |

Diagnosed root cause (per the v1.2.1 amendment): `JSONDecoder` parses
selectively — only fields the `Decodable` declares are materialised.
swift-json's `JSON.Serializable.init(jsonBytes:)` calls
`JSON.parse(jsonBytes)` first, which fully materialises the
`RFC_8259.Value` tree, then runs `Self.deserialize(_:)` over that
tree to extract declared fields. On partial-shape schemas this is
strictly more work.

The v1.2.1 amendment proposed the resolution shape as "streaming
deserialize" — emit parser events directly into the target type, skip
JSON fields the type doesn't declare at the parser level. **No design
exists.** This document is the first phase of the design study; its
job is to characterise the status quo and the field, not to propose
a target architecture (Phase 2 does that). Per the originating
handoff brief, the **outcome is descriptive, not prescriptive**.

This is Tier 2 per [RES-020]: cross-package (swift-json,
swift-rfc-8259, possibly swift-parser-primitives or
swift-binary-parser-primitives in Phase 2's recommendations),
several-releases lifetime, reversible. Per [RES-021], a prior-art
survey across simdjson, serde_json, jsoniter, Apple
`JSONDecoder`, System.Text.Json `Utf8JsonReader`, and Newtonsoft
`JsonTextReader` is included with parallel-subagent primary-source
verification per [RES-020].

## Question

Two sub-questions, both purely descriptive:

1. **How does swift-json today perform the parse → typed-decode
   path?** What is the call graph from
   `T(jsonBytes:)` to the materialised `T`, what substrate already
   exists in `swift-rfc-8259` and `swift-parser-primitives` that a
   future streaming design could compose with, and what are the
   contracts (typed throws, dynamic-access, Foundation-freedom,
   strict memory safety, `~Copyable` cursor) that any redesign must
   preserve?

2. **What shapes does the JSON-decoding field use to perform the
   same task?** Where does each shape sit in the design space, what
   trade-offs does each accept, and what — concretely — would the
   shape look like translated into the swift-json substrate's
   terms?

Phase 2 takes the descriptive answers here and produces a
prescription: ranked architectural options, a recommended path, a
phased landing plan, and honest risks.

## Analysis

### 1. The swift-json status quo — full-tree-then-extract

#### 1.1 Public-surface call graph

The `JSON.Serializable` protocol at
`swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:42-52`
declares:

```swift
extension JSON {
    public protocol Serializable {
        static func serialize(_ value: Self) -> JSON
        static func deserialize(_ json: JSON) throws(JSON.Error) -> Self
    }
}
```

The deserialize convenience initializers at lines 78-92:

```swift
extension JSON.Serializable {
    @inlinable
    public init(jsonString: String) throws(JSON.Error) {
        let json = try JSON.parse(jsonString)   // [1] full tree
        self = try Self.deserialize(json)        // [2] re-walk to extract
    }

    @inlinable
    public init<Bytes>(jsonBytes: Bytes) throws(JSON.Error)
    where Bytes: Swift.Collection<UInt8>, Bytes: Sendable, Bytes.Index: Sendable {
        let json = try JSON.parse(jsonBytes)    // [1] full tree
        self = try Self.deserialize(json)        // [2] re-walk to extract
    }
}
```

Step [1] is `JSON.parse(_:)` → `RFC_8259.parse(_:)` →
`RFC_8259.Decode.callAsFunction(_:)` →
`RFC_8259.Span.Parser.parse(_:, maxDepth:)` (post-Tier-4 fast path
when storage is contiguous). The Span parser walks the input bytes
once, but its output is the full `RFC_8259.Value` tree —
`.string(_)`, `.number(_)`, `.array(RFC_8259.Array)`,
`.object(RFC_8259.Object)`. Every JSON string is materialised as a
Swift `String`; every JSON number is materialised as
`RFC_8259.Number` + `RFC_8259.Number.Original`; every container is
heap-allocated.

Step [2] re-walks that tree to extract the declared fields. The
canonical implementation pattern, from the `Symbol` schema in
`Experiments/parse-performance-bench/Sources/parse-performance-bench/main.swift:51-69`:

```swift
struct Symbol: JSON.Serializable {
    let kind: SymbolKind
    let identifier: SymbolIdentifier
    let pathComponents: [String]

    static func deserialize(_ json: JSON) throws(JSON.Error) -> Symbol {
        let kind = try SymbolKind(json: json.kind)
        let identifier = try SymbolIdentifier(json: json.identifier)
        let pathComponents = try [String](json: json.pathComponents)
        return Symbol(kind: kind, identifier: identifier, pathComponents: pathComponents)
    }
}
```

`json.kind` calls
`JSON.subscript(dynamicMember:)` →
`JSON.subscript(key: String)` →
`RFC_8259.Object.subscript(_: String)` (linear scan over the
`[(key: String, value: RFC_8259.Value)]` backing storage), then
re-wraps in a `JSON` value. The post-decode lookup pass on
canonical-workload `Symbol` is 1.72 ms/iter (v1.2.1) — within noise
of the post-`JSONDecoder` 1.6 ms/iter; native-struct access is
equivalent on both sides once the data is materialised.

#### 1.2 The full-tree property

Every key in the object — every key in every object — gets a Swift
`String` allocation at parse time. Every value gets a
`RFC_8259.Value` enum payload, with its own
`RFC_8259.Number.Original` + `[UInt8]` byte capture for numbers and
heap-allocated array storage for containers. Fields the consumer
will not declare on the target Decodable are paid for in full.

On the canonical workload, ~922 531 objects are parsed at mean N=2.06
keys/object (per `size-dist` mode of the bench, cited in
`copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1 §3.3). The
`Symbol` schema declares 3 fields per symbol; the on-disk shape
carries ~9 keys per symbol. **~⅔ of the keys parsed are immediately
discarded.** The full-tree-then-extract architecture pays for them
unconditionally.

#### 1.3 The dynamic-access advantage today

The 14× lookup advantage versus Foundation's `JSONSerialization` +
`as? [String: Any]` casts (v1.2.0) IS a property of this same
architecture. swift-json's `JSON` value is a typed
dynamic-member-lookup façade over `RFC_8259.Value`; one indirect
access (`json.user.name`) compiles to a chain of
`subscript(key:)` calls that each hit typed enum payloads with no
runtime cast. Foundation's `JSONSerialization` returns `Any`; the
same chain pays an existential cast at every hop.

This is non-negotiable. Any redesign that closes the 37 % gap on
schema-known decode by sacrificing the 14× lookup advantage on
dynamic-access workloads makes a worse trade than the status quo.
The architecture has to preserve both axes.

#### 1.4 The contracts a redesign must preserve

| Contract | Source | What it forbids |
|---|---|---|
| Typed throws | `Sources/JSON/JSON.Serializable.swift:51`: `throws(JSON.Error)` | Any rewrite that erases the error type or routes through `any Error` |
| Public API stability | `Sources/JSON/JSON.swift`, `JSON.Parse.swift`, `JSON.Serializable.swift` are the public surface | Breaking `JSON.parse(_:)`, `JSON.Serializable`, `JSON.parse.prepared()`, `JSON.parse.located()` |
| Foundation-free production code | `[PRIM-FOUND-001]` + [ARCH-LAYER-007] (no-Foundation across all five layers) | `import Foundation` in `Sources/` of any swift-json / swift-rfc-8259 target |
| `~Copyable & ~Escapable` cursor discipline | `RFC_8259.Span.Lexer` / `RFC_8259.Span.Parser` at `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.{Lexer,Parser}.Span.swift` | Reverting to Copyable cursor; introducing `UnsafePointer<UInt8>` parsers dressed up as safe Swift |
| Strict memory safety | `@safe` attribute on `RFC_8259.Span.Lexer` (line 61) + `@_lifetime(...)` annotations | Adding `@unsafe` blocks or escaping `Span<UInt8>` lifetimes |
| `JSON.Serializable` as the typed-throws Codable alternative | `swift-institute/Research/codable-untyped-throws-disposition.md` v1.0.0 (DECISION) + the `Lint.Manifest` adoption precedent at `swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift:116` | Replacing `JSON.Serializable` with a re-skinned `Codable`; reintroducing `throws(any Error)` on the deserialize surface |
| Composition with the Tier 4 Span parser | `swift-foundations/swift-json/Research/parse-performance-architecture.md` v1.0.2 (DECISION) | A redesign that bypasses the Span parser or duplicates its lexer machinery |

These contracts narrow Phase 2's design space sharply. They are not
negotiable for the Codable gap; Phase 2 evaluates options against
them as binary constraints.

### 2. The substrate

#### 2.1 `RFC_8259.Token` exists but is bypassed

`swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Token.swift:13-46`
defines an event-grain JSON token:

```swift
extension RFC_8259 {
    public enum Token: Sendable, Hashable {
        case objectStart, objectEnd
        case arrayStart, arrayEnd
        case colon, comma
        case null, `true`, `false`
        case string(String)
        case number(Number)
    }
}
```

This is the natural emission unit for a streaming JSON parser
(equivalent to System.Text.Json's `JsonTokenType` or
Newtonsoft's `JsonToken`). It already carries the materialised
`String` for `.string` and `RFC_8259.Number` for `.number`, so
event consumers do not have to re-extract the value from byte
offsets.

The Phase A1 Span parser (`RFC_8259.Span.Parser.swift`) **does not
emit these tokens**. Per the file's header comment (lines 18-28),
storing `Optional<Token>` in a `~Copyable & ~Escapable` struct
triggered a Swift 6.3+ compiler bug ("copy of noncopyable typed
value") at the time of Tier 4 implementation. The Span parser
sidesteps this by doing all dispatch at the byte level
(`parseValue` switches on `lexer.peek` directly) and calling
specialised `lexStringValue() -> String` /
`lexNumberValue() -> RFC_8259.Number` helpers that return value
types directly without wrapping in `Token`. The token enum is
preserved in the public surface (the generic
`RFC_8259.Lexer<Input>` slow path still uses it) but the fast path
through `Span.Parser` never produces a stream of tokens — it goes
straight from bytes to `RFC_8259.Value`.

This is load-bearing for Phase 2: the substrate for a token-emitting
streaming path **already exists at the public surface**, but the
high-performance path through it does not. Any streaming-deserialize
architecture that emits `RFC_8259.Token` events will need to
either (a) hit the generic slow path (losing Tier 4's gains) or
(b) extend the Span parser to emit tokens without the compiler-bug
trigger.

#### 2.2 The Tier 4 Span parser as the immediate substrate

`RFC_8259.Span.Parser` (`RFC_8259.Parser.Span.swift:32-76`) is
`~Copyable & ~Escapable`, holds `RFC_8259.Span.Lexer` plus depth +
maxDepth + `stringScratch: [UInt8]`, and is lifetime-bound to its
backing span via `@_lifetime(borrow bytes)`. Its hot loop is
`parseValue` → byte-level switch → recursive `parseObject` /
`parseArray` → `lexStringValue` / `lexNumberValue` for leaves.

The lexer (`RFC_8259.Lexer.Span.swift:35-95`) is the byte-level
cursor: `let bytes: Span<UInt8>` + `var position: Int` + lazy
position cache. It mirrors `Binary.Bytes.Input.View`
(`swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift`)
one layer up. The cursor's public operations are `peek`,
`peek(offset:)`, `advance()`, `advance(by:)`, `isEmpty`, `count`,
`startsWith`. Every operation is `@_lifetime(self: copy self)`.

This is the substrate a streaming-event design would compose with.
The lexer is already byte-oriented; the parser is already structured
as a recursive descent over the lexer. The architectural distance
from "recursive descent → `RFC_8259.Value` constructor" to
"recursive descent → event consumer" is small in mechanical-edit
terms but large in design-space terms — Phase 2 evaluates
specifically how to make that bridge.

#### 2.3 `swift-parser-primitives` — generic combinators

`swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift`
declares the institute-wide parser protocol:

```swift
public protocol `Protocol`<Input, Output, Failure> {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Swift.Error
    var body: Body { get }
    func parse(_ input: inout Input) throws(Failure) -> Output
}
```

`Input` is already `~Copyable & ~Escapable`. The combinator suite
(`Parser.OneOf`, `Parser.Take`, `Parser.Many`, `Parser.Map`,
`Parser.FlatMap`, `Parser.Skip`, `Parser.Optional`, etc.) is
extensive (catalogued at
`swift-institute/Research/data-structures-variant-catalog-parsers.md`).
`Parser.Input.Streaming` is a typealias to
`Input_Primitives.Input.Streaming` — the forward-only, no-checkpoint
variant. `Parser.Input.Protocol` adds checkpoint/restore for
backtracking.

The current Tier 4 Span parser does NOT use this combinator stack
— it is a hand-rolled recursive-descent specialised on
`Swift.Span<UInt8>` directly. Phase 2 may consider whether a
combinator-based event parser would be tractable. The
`2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`
v1.1.0 (RECOMMENDATION, Tier 3) addresses orthogonal questions
about `Self: ~Copyable` relaxation on the parser protocol; it does
not block Phase 2's event-emitting design.

#### 2.4 `swift-binary-parser-primitives` — the precedent

`Binary.Bytes.Input.View` (lines ~46-194 of
`swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift`)
is the canonical `~Copyable & ~Escapable` + `Span<UInt8>` +
`@_lifetime(borrow span)` cursor. The `Binary.Bytes.Parser`
protocol consumes it via
`mutating func parse(_ input: inout Binary.Bytes.Input.View) throws -> Output`.

`RFC_8259.Span.Lexer` mirrors this shape, one layer up. A
text-side equivalent at `swift-parser-primitives` level —
`Parser.Bytes.Input.View` or similar — does NOT yet exist; the
predecessor doc's Tier 5 "Move to `Input.Borrowed`" item
(`parse-performance.md` lines 417-424) is the version of this
that's been outlined but deferred pending `Input.Borrowed` landing
in `swift-input-primitives`. Phase 2's recommendations may touch
this question; if so, [RES-018] second-consumer hurdle applies.

#### 2.5 `JSON.Stream` — NDJSON streaming today

`swift-foundations/swift-json/Sources/JSON/JSON.Stream.swift`
provides `JSON.ND.stream(_:)` for newline-delimited JSON over
`AsyncSequence<UInt8>` and `JSON.parse(collecting:)` for
single-document collection from an async source. Both buffer per
unit (line for NDJSON, full document for `collecting:`) and then
invoke `JSON.parse(_:)` — i.e., they fall through to the
full-tree-then-extract path on each unit. They do not stream-decode
within a single document.

This is the *operational* shape of "streaming JSON" the package
currently provides. It is orthogonal to the streaming-deserialize
question — Phase 2's design is about *intra-document* streaming
(skip undeclared fields without materialising them), not
*inter-document* streaming (process one document at a time over an
async source). A streaming-deserialize architecture would compose
naturally with NDJSON (cheaper per-line decode), but the question
is not about reshaping the NDJSON surface itself.

#### 2.6 The bench harness — the measurement infrastructure

`swift-foundations/swift-json/Experiments/parse-performance-bench/`
ships eight modes (per
`Sources/parse-performance-bench/main.swift`):

| Mode | Measures |
|---|---|
| `all` | Floor + Foundation + swift-json String/bytes parse |
| `floor` | Byte-iteration cost on `Data` and `[UInt8]` |
| `foundation` | `JSONSerialization.jsonObject(with:)` |
| `swift-json-string` / `swift-json-bytes` | `JSON.parse(String/[UInt8])` |
| `crossover` | Isolated storage-only micro across `[(String, Int)]` / `Swift.Dictionary` / `Dictionary.Ordered` at N ∈ {1..1024} |
| `synthetic-lookup` | End-to-end lookup over a synthesised `[{k_0:0, k_1:1, …}]` document at varying object size |
| `size-dist` | Object-size histogram of the workload (mean N, max N) |
| `lookup` | Parse-once-then-traverse on the canonical workload: dynamic-access path (swift-json) vs Foundation `[String: Any]` |
| `codable-lookup` | Parse-once-then-traverse on the canonical workload: `Decodable` (Foundation) vs `JSON.Serializable` (swift-json) — **the mode that produced the 37 % finding** |
| `sanity` / `equiv` | Validation that both parsers built the same tree |

The harness is **already wired** with the `Symbol` schema (file
lines 27-83) and the `codable-lookup` mode (lines 443-503). Any
streaming-deserialize implementation arc in Phase 2 reuses this
infrastructure — no new bench is needed for A0/A1 measurement
gates, and per [BENCH-011] the harness's dual-mode `crossover` +
`synthetic-lookup` + `codable-lookup` shape already satisfies the
integration-probe-requirement that applies whenever a redesign
crosses the Copyable wrapper boundary (which any in-place
event-into-target architecture does).

### 3. Prior art — five-system survey

All claims in this section verified against primary sources by
parallel subagents per [RES-020] / [RES-021]. Citations are
inline.

#### 3.1 simdjson — DOM vs `ondemand`

simdjson ([Langdale & Lemire 2019]) was the first JSON parser to
exceed 1 GB/s on commodity cores. Two principal APIs:

- **DOM API**: traditional pre-built parse tree. Materialises
  every value. Verified architecture per the Langdale-Lemire 2019
  paper.
- **`ondemand` API**: introduced experimentally in v0.6 (October
  2020); stabilised by v1.0 (September 2021). Per the v0.6 release
  notes: 2.3 → 4.6 GB/s on a unique-identifier extraction
  benchmark — **2× speedup on partial-shape decode**.

The `ondemand` design (verified against
`github.com/simdjson/simdjson/blob/master/doc/ondemand_design.md`):
SIMD-driven preprocessing builds a structural classification of
the input (locations of `{ } [ ] : , " "`); the consumer-facing
iterator walks the classified input **lazily** — values are
decoded only when the consumer requests them. The 2021 v1.0
announcement (https://lemire.me/blog/2021/09/25/) frames it: *"if
you open a file containing 1000 numbers and you need just one of
these numbers, only one number is parsed."*

Forward-only iteration: per the design doc, *"only a single index
is maintained"* — array elements and string/number values can
only be parsed once in document order. **Object key lookup by
name** is supported via a wrap-around scan (`find_field_unordered`
/ `[]`); strict forward-only `find_field` is the fast path.

License: Apache-2.0 / MIT dual. Language: C++17.

#### 3.2 serde_json — Visitor-pattern pull decode

serde_json is the JSON format implementation for Rust's serde
framework (https://serde.rs). serde decouples data formats from
target types via two traits:

- **`Deserializer`** (implemented by the format crate — serde_json)
  drives the parse.
- **`Deserialize<'de>` / `Visitor`** (implemented by the target
  type, usually via `#[derive(Deserialize)]`) consumes events.

The Deserializer calls back into the Visitor with `visit_str`,
`visit_i64`, `visit_map`, etc. as the parse advances. The format
crate is a recursive-descent pull parser; the target type's
Visitor is the event-handler role. **There is no intermediate
`serde_json::Value` tree** unless the consumer explicitly asks
for one (`from_str::<serde_json::Value>(...)`).

Selective decode — when `#[derive(Deserialize)]` generates a
Visitor for a struct, the Visitor's `visit_map` calls
`map.next_value::<IgnoredAny>()` for keys the struct does not
declare. `IgnoredAny`
(https://docs.rs/serde/latest/serde/de/struct.IgnoredAny.html) is
a Visitor that **consumes any JSON value without materialising
it** — it counts braces/brackets, accumulates string lengths.
Critical nuance: this is **parse-then-discard**, not structural
skip. serde_json has no stage-1 structural index analogous to
simdjson's; skipping a nested object still walks every byte of it
at the parser level. The wedge serde_json closes is the
allocation + value-construction cost, not the byte-walk cost.

Zero-copy: serde supports `&'de str` borrowed strings — a
`Deserialize<'de>` whose target type borrows from the input buffer
gets `visit_borrowed_str` callbacks when no escape sequences are
present (https://serde.rs/lifetimes.html).

Untagged enums (`#[serde(untagged)]`) and `#[serde(flatten)]`
force serde to materialise an intermediate `Content<'de>` buffer
(serde's own type, in
`https://github.com/serde-rs/serde/blob/master/serde/src/private/de.rs`).
This is the principal exception to serde_json's streaming-pull
purity.

License: MIT / Apache-2.0 dual. Language: Rust.

#### 3.3 jsoniter — Go pull iterator

jsoniter (https://github.com/json-iterator/go) is the Go ecosystem's
high-performance JSON library. Its central type is `Iterator` with
pull methods: `ReadObject() string` (returns next field name; empty
string signals end of object), `ReadArray() bool`, `ReadString()`,
`ReadInt()`, `ReadFloat64()`, `Skip()` (skips a JSON object and
positions to the next).

Selective decode — the canonical loop pattern:

```go
for field := iter.ReadObject(); field != ""; field = iter.ReadObject() {
    switch field {
    case "kind":   ...
    case "ident":  ...
    default:        iter.Skip()
    }
}
```

jsoniter also provides a stdlib-compatible `Marshal` / `Unmarshal`
API for drop-in replacement of Go's `encoding/json` (`Replace
import "encoding/json" with import jsoniter "github.com/json-iterator/go"`).
Reported performance from the README's benchmark: **6.32× faster
decode** than stdlib (5 623 ns/op vs 35 510 ns/op; encode is
2.6× faster). Go stdlib `encoding/json` is slower partly because
it uses reflection-based struct decoding plus per-value buffering.

License: MIT. Language: Go.

#### 3.4 Apple Foundation `JSONDecoder` — selective decode via `JSONMap`

This is the strongest direct precedent for the architecture that
closes the 37 % gap. Verified against the swift-foundation source
tree (`https://github.com/swiftlang/swift-foundation`):

The modern `JSONDecoder` (post-2023 rewrite, in
`Sources/FoundationEssentials/JSON/`) is **two-phase**:

1. **`JSONScanner.scan() throws -> JSONMap`**
   (`JSONScanner.swift:344`) does ONE forward byte-walk producing
   a `JSONMap` — an array of `(token-type-marker, count,
   sourceByteOffset)` triples for scalar leaves and
   `(marker, nextSiblingOffset, count, …, .collectionEnd)` for
   containers. **Values are not materialised at scan time**: per
   the file's own header comment at lines 13-18, the scanner
   captures *"lengths of bytes and byte offsets into the input.
   This allows the full parsing to occur at decode time, or to be
   skipped if the value is not desired."*

2. **`JSONDecoderImpl`** (`JSONDecoder.swift:520`,
   `fileprivate class`) walks the map driven by the consumer's
   `Decodable`. When the consumer's `KeyedDecodingContainer`
   doesn't ask for a field, the decoder uses
   `JSONMap.offset(after:)` (`JSONScanner.swift:180-196`) to jump
   to the next sibling in **O(1) on the map**.

Per the file's header walkthrough (lines 47-53): *"Skip the key's
value by finding its type (array), and then its nextSiblingOffset
index (19)."* The structural skip is O(map-entries-in-the-skipped-subtree),
typically O(1) per skipped value, not O(bytes-in-the-skipped-subtree).

A nuance: at the keyed-container level, the decoder DOES walk all
keys at the current object level and UTF-8-decodes them to build a
`[String: JSONMap.Value]` dictionary
(`JSONDecoder.swift:1238`, `KeyedContainer.stringify(...)`). Key
UTF-8 decoding is paid; value bodies of skipped keys are not. For
the canonical workload's 9-keys-per-symbol shape this is still a
decisive win — UTF-8 decoding nine short ASCII keys is much cheaper
than parsing six nested values.

Inline comment at `JSONDecoder.swift:409`: *"Strings and numbers
are not completely parsed until decoding time."* This is the
mechanism behind the 37 % gap.

**Historical note**: pre-2023 `JSONDecoder` in
swift-corelibs-foundation used full-tree materialisation
(`JSONParser.parse() -> JSONValue` tree, then
`JSONDecoderImpl` walked it). The structural-skip architecture
was introduced in the 2023 swift-foundation Swift rewrite. Linux
swift-corelibs-foundation now re-exports swift-foundation, so the
selective-decode behaviour ships on Linux too.

**Public surface**: `JSONScanner`, `JSONMap`, `JSONDecoderImpl`
are all `internal` (or `fileprivate`). No public API surface
exposes the structural map. Consumers see only
`JSONDecoder.decode(_:from:)`.

License: Apache-2.0. Language: Swift.

#### 3.5 .NET `Utf8JsonReader` (System.Text.Json)

`System.Text.Json` (https://learn.microsoft.com/en-us/dotnet/api/system.text.json.utf8jsonreader)
ships `Utf8JsonReader` — a `ref struct` (stack-only, no boxing,
no heap allocation) that reads UTF-8 bytes via
`ReadOnlySpan<byte>` or `ReadOnlySequence<byte>`. The latter
supports multi-segment buffers (e.g., from
`System.IO.Pipelines`) for true streaming over arbitrary sources.

`Read()` advances forward; the consumer drives. `TokenType`
enum: `StartObject, EndObject, StartArray, EndArray, PropertyName,
String, Number, True, False, Null, Comment, None`. (Booleans
split into `True`/`False`; numbers are a single token.)
Accessors: `GetString()`, `GetInt32()`, `GetDouble()`, etc.

**`Skip()` advances past the children of the current token** —
the structural-skip primitive (the API doc page on Utf8JsonReader
lists it explicitly). The skip walks the input bytes structurally
without materialising values.

The high-level `JsonSerializer.Deserialize<T>(...)` is
implemented in terms of `Utf8JsonReader` + `JsonConverter<T>`
(per
https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/use-utf8jsonreader:
*"the `JsonSerializer.Deserialize` methods use `Utf8JsonReader`
under the covers."*). Pull-driven event iteration is the
foundational primitive; the serializer composes on top.

License: MIT. Language: C# / .NET.

#### 3.6 Newtonsoft `JsonTextReader` (JSON.NET)

Newtonsoft's `JsonTextReader`
(https://www.newtonsoft.com/json/help/html/T_Newtonsoft_Json_JsonTextReader.htm)
predates System.Text.Json by over a decade. It is a *"fast,
non-cached, forward-only"* reader over a `TextReader` source. The
abstract `JsonReader` base class is what `JsonSerializer` drives
against; `JsonTextReader` is the text-source concrete subclass.

Newtonsoft's `JsonReader.Skip()` is the structural-skip method.
The token enum is larger than System.Text.Json's (18 values
including `StartConstructor`, `Raw`, `Date`, `Bytes`), splits
numbers into `Integer` / `Float`, and uses a single `Boolean`
token. Architectural shape: the same pull-driven reader pattern,
older, with Newtonsoft's framing of the reader as a manual fast
path skipping the serializer's reflection overhead.

License: MIT. Language: C# / .NET.

### 4. The pattern taxonomy

Three structurally distinct architectures emerge from §3.

#### Pattern α — Full-tree DOM materialise-then-walk

- **Definition**: parse the full JSON tree into an owning value
  representation; then walk that tree to extract or query.
- **Examples**: pre-2023 Foundation `JSONDecoder`, simdjson DOM
  API, swift-json today (status quo), Newtonsoft's
  `JsonConvert.DeserializeObject<JObject>` path.
- **Strength**: simple consumer API; supports both dynamic-access
  (typed querying) and schema-known decode (extract by walking);
  one parse for many access patterns; full random-access lookup
  after parse.
- **Weakness**: pays for every field at parse time; partial-shape
  decode is strictly inefficient.

#### Pattern β — Pre-built structural index + lazy decode

- **Definition**: one forward pass produces an index of structural
  positions in the input bytes; value materialisation is deferred
  until consumer access; skipping uncovered fields is O(1) per
  skipped position via next-sibling offset.
- **Examples**: modern (post-2023) Foundation `JSONDecoder` +
  `JSONScanner` + `JSONMap`; simdjson `ondemand`. Academic
  ancestors include [Mison (Li et al. 2017)] (query-directed lazy
  parsing with SIMD); [JSONSki (Jiang & Zhao ASPLOS 2022)]
  (bit-parallel structural fast-forwarding).
- **Strength**: ~2× speedup on partial-shape decode workloads
  (simdjson v0.6 release notes); 37 % observed advantage on the
  canonical workload (Foundation vs swift-json — the wedge of
  this whole investigation). Retains random-access semantics — the
  index can be re-walked after parse. Compatible with dynamic
  access (the index plus the bytes is a lazy version of a typed
  tree).
- **Weakness**: index construction has nonzero cost; the index
  itself is a memory cost (typically <10 % of bytes for typical
  JSON). Single-shot iteration with no need to re-walk loses
  some of the benefit. Compounding: storing byte offsets + types
  is "an in-memory tree of byte references" — the SUPERSEDED v2
  arc's structural lesson applies (cf.
  `copyable-wrapper-vs-multi-buffer-storage.md`) and must be
  measured under [BENCH-011].

#### Pattern γ — Pull-driven event stream into target

- **Definition**: a forward-only pull iterator over JSON tokens
  drives the consumer directly into the target type. Consumer
  calls Read/Next; reader emits a token; consumer dispatches based
  on token; structurally-skipped values walk bytes without
  materialising. No intermediate tree.
- **Examples**: serde_json + Visitor + `IgnoredAny`; jsoniter
  Iterator; System.Text.Json `Utf8JsonReader`; Newtonsoft
  `JsonTextReader`; conceptual ancestor [JSR-173 StAX, 2004].
- **Strength**: minimal memory footprint — no tree, no index;
  cheapest possible architecture for write-once parse-once
  consumers (the schema-known decode case). Composes with
  multi-segment streaming inputs (`Utf8JsonReader` over
  `ReadOnlySequence<byte>`; serde_json over `IoRead`).
- **Weakness**: no random-access after parse — re-walking requires
  re-parsing or buffering. Skipping is parse-then-discard (byte-walk
  + dispatch overhead) unless the reader has a sub-linear
  structural skip primitive. Dynamic-access workloads (the 14×
  lookup advantage) are NOT served by this pattern alone — γ
  needs to compose with α or β to preserve them.

#### Contextualization in the swift-json substrate (per [RES-021])

This is the part [RES-021]'s contextualization step requires
**before** any prescription. What each pattern would look like in
swift-json's substrate's terms:

| Pattern | swift-json substrate translation |
|---|---|
| α (status quo) | `RFC_8259.Span.Parser.parse(_:_:) -> RFC_8259.Value` (the current Tier 4 implementation) |
| β | Run the Span parser in a "scan only" mode that emits an `RFC_8259.Map` analog (token-kind discriminator + byte offset + next-sibling jump). `JSON.Serializable.deserialize(_: JSON)` then becomes `deserialize(_: JSON.Lazy)` where `JSON.Lazy` is a façade over `(bytes: Span<UInt8>, map: RFC_8259.Map)`. Random-access lookup re-walks the map. Risks: refcount-per-copy under the lazy wrapper per `[BENCH-011]`; the map is a multi-buffer storage shape that must be integration-probed before adoption. |
| γ | Add a `RFC_8259.Span.EventParser` that emits `RFC_8259.Token` events (or a new `~Copyable` event enum) via an `inout consumer` callback or a streaming iterator. `JSON.Serializable` grows an event-grain protocol requirement: `static func deserialize(_ events: inout RFC_8259.Span.Lexer) throws(JSON.Error) -> Self` or similar. Dynamic-access does NOT flow through this path — the existing `JSON.parse(_:)` + `JSON.Value` tree remains the dynamic-access surface. |

Universal-adoption is not universal-necessity: every surveyed
high-performance system adopts β or γ for schema-known decode
because the field has matured past pattern α at scale, **but** the
swift-json design context's hard constraints (Foundation-free
typed-throws Copyable-`JSON` value + dynamic-access surface) mean
the answer is **not necessarily** "drop α." α may stay as the
dynamic-access surface while β or γ joins as the schema-known
fast path. The choice between β and γ — and whether to keep α
unchanged or fold it into β — is the subject of Phase 2.

### 5. Cross-cutting design dimensions

Phase 2's evaluation criteria operate along these axes. Phase 1
names them; Phase 2 ranks the architectures against them.

| Dimension | What varies | Why it matters for swift-json |
|---|---|---|
| Skip cost | O(bytes) [pattern α and γ-without-index] vs O(map-walk) [pattern β] vs O(0) [unreachable in any byte-walking parser] | Determines the wall-clock close of the 37 % gap on partial-shape decode |
| Allocation strategy at skip | Per-value heap (full tree) vs zero (structural skip) vs scratch-reuse (event with cleared buffer) | Determines garbage-collection / refcount-thrash cost on large workloads |
| Random-access vs forward-only | DOM (α) and indexed (β) support random access; pure event (γ) does not | The 14× dynamic-access lookup advantage requires random access; the Codable gap is forward-only sufficient |
| Owning vs borrowing target | The `Decodable` / `JSON.Serializable` either owns its decoded fields or borrows them from the input span | Determines whether the resulting struct can outlive the parser scope. swift-json's current contract is owning; Phase 2 may consider whether `~Escapable` decoded targets are in scope |
| Cursor copyability | The cursor is `~Copyable & ~Escapable` (Tier 4 substrate) vs copyable | A `~Copyable` cursor preserves Tier 4's specialisation; copyable cursors compose with combinator stacks more naturally |
| Typed-throws propagation | Errors flow through the event consumer chain | `throws(JSON.Error)` must survive every protocol witness, every pattern-match-extract, every Visitor-style callback. Per `codable-untyped-throws-disposition.md`, `JSON.Serializable` is the typed alternative to `Codable`; the architecture must not erode that |
| Foundation-freedom | Production `Sources/` cannot import Foundation | Forbids the easy answer of "expose `JSONDecoder` and let consumers use Codable." `[ARCH-LAYER-011]` (improve institute, don't reach for Foundation) governs |
| Strict-memory-safety | `@safe` cursor, no `UnsafePointer<UInt8>` in production code, all `Span<UInt8>` operations within their lifetime | Forbids the "fastest" answer of hand-rolled pointer arithmetic; lifetimes propagate through every step |
| Public API stability | Existing `JSON.parse`, `JSON.parse.prepared`, `JSON.parse.located`, `JSON.Serializable` signatures preserved | Per the originating handoff and per [API-IMPL-005]/[API-NAME-001], the public surface is frozen; the redesign lives behind the existing surface |
| Tier 4 composition | The Span parser is the post-Tier-4 fast path; reuses or duplicates? | Duplicating the lexer machinery is acceptable if scoped (the generic parser already does this); reusing requires either changing the Span parser's emission contract or adding a parallel `RFC_8259.Span.EventParser` |
| Combinator vs hand-rolled | `swift-parser-primitives` combinator stack vs the existing hand-rolled `RFC_8259.Span.Parser` | Phase 2 evaluates whether moving the parser to combinators would be tractable or whether the hand-rolled shape stays |
| Per-character UTF-8 handling | Strings with escape sequences vs ASCII fast-path | Already handled in `RFC_8259.Span.Parser.lexStringValue`; the streaming path must preserve the existing escape decoding |
| NDJSON / `AsyncSequence` composition | The streaming-deserialize path should compose with `JSON.ND.stream` and `JSON.parse(collecting:)` | NDJSON consumers should benefit naturally — per-line deserialize would replace the per-line full-tree parse |

### 6. Academic literature

Per [RES-021] / [RES-026], cited papers (verified against primary
sources by parallel subagent per [RES-020]):

- [Langdale & Lemire 2019]: *Parsing Gigabytes of JSON per Second*,
  Geoff Langdale, Daniel Lemire, **The VLDB Journal** vol. 28, no. 6
  (2019); arXiv:1902.08318 (DOI: 10.1007/s00778-019-00578-5).
  Establishes the canonical two-stage SIMD JSON-parsing
  architecture (stage 1 vectorised structural classification → stage
  2 validation and value conversion). Foundational reference for
  pattern β.

- [Mison (Li et al. 2017)]: *Mison: A Fast JSON Parser for Data
  Analytics*, Yinan Li, Nikos R. Katsipoulakis, Badrish
  Chandramouli, Jonathan Goldstein, Donald Kossmann, **Proc. VLDB
  Endowment** vol. 10, no. 10 (VLDB 2017), pp. 1118-1129.
  Introduces query-directed lazy parsing — analytical-query
  projection and filter predicates are pushed into the parser so
  it can jump directly to the byte offsets of queried fields.
  Reports >10× speedup vs FSM-based parsers on selective
  workloads. Canonical citation for schema-aware lazy projection.

- [Sparser (Palkar et al. 2018)]: *Filter Before You Parse: Faster
  Analytics on Raw Data with Sparser*, Shoumik Palkar, Firas
  Abuzaid, Peter Bailis, Matei Zaharia, **Proc. VLDB Endowment**
  vol. 11, no. 11 (VLDB 2018), pp. 1576-1589. Compiles query
  predicates into SIMD-efficient raw filters that scan raw bytes
  before any structural parsing; raw filters may yield false
  positives but never false negatives. Establishes the
  filter-before-parse pattern. Architectural relative of β
  with a more aggressive skip strategy.

- [JSONSki (Jiang & Zhao 2022)]: *JSONSki: Streaming
  Semi-Structured Data with Bit-Parallel Fast-Forwarding*, Lin
  Jiang, Zhijia Zhao, **ASPLOS 2022** (Best Paper). Bit-parallel
  SIMD operations fast-forward over substructures irrelevant to
  the active query without full tokenisation; introduces
  recursive-descent streaming and structural intervals. Relevant
  to any pull-style streaming JSON parser concerned with
  skip-ahead behaviour. Architectural relative of γ with an
  asymptotically-faster skip.

- [JSR-173, 2004]: *Streaming API for XML*, Java Community Process
  JSR-173, final release 25 January 2007 (v1.0 approved March
  2004). Canonical specification for the pull-parser pattern: a
  bidirectional, iterator-based, consumer-driven streaming API as
  the explicit counterpart to SAX's push/event-driven model. Cite
  for the StAX/pull-parsing terminology used in pattern γ.
  Authoritative current reference: Oracle JAXP tutorial
  (https://docs.oracle.com/javase/tutorial/jaxp/stax/why.html).

(SAX's origin is the XML-DEV mailing list, 1998, David Megginson
et al.; no peer-reviewed paper exists. Specification-only citation
is the standard practice for both StAX and SAX.)

## Outcome

**Status**: RECOMMENDATION (descriptive characterisation; not
prescriptive)

The status quo and the field are now characterised. Three
load-bearing findings:

1. **swift-json today is canonical pattern α** (full-tree DOM
   materialise-then-walk). Every byte of input becomes part of a
   materialised `RFC_8259.Value` tree before any consumer code
   runs. Fields the consumer's `JSON.Serializable` will not
   declare are paid for in full at parse time. On the canonical
   workload — `Symbol` schema reading 3 of ~9 keys per object,
   ~922 531 objects, mean N=2.06 keys/object — the discarded
   ~⅔ of work is the measurable 37 % gap to Foundation.

2. **The field has matured past pattern α for schema-known
   decode at scale.** Every surveyed high-performance system
   adopts pattern β (lazy structural index) or pattern γ
   (pull-driven event stream into target) for the partial-shape
   decode use case. Apple's own Foundation `JSONDecoder`
   rewrote to pattern β in 2023, abandoning its earlier full-tree
   architecture. Microsoft's `System.Text.Json` is canonical γ.
   simdjson `ondemand` is canonical β. Rust serde_json is canonical
   γ. Go jsoniter is canonical γ.

3. **The substrate for either pattern β or pattern γ already
   exists in `swift-rfc-8259` and `swift-parser-primitives`.** The
   Tier 4 `RFC_8259.Span.Parser` is `~Copyable & ~Escapable` over
   `Span<UInt8>` with lifetime-annotated cursor and lazy position
   computation — the exact shape both β (scan-only mode emitting
   a map) and γ (event-emitting parser) would build on.
   `RFC_8259.Token` exists at the public surface but is bypassed
   by the Phase A1 implementation. `swift-parser-primitives` has
   `Parser.Input.Streaming` for forward-only and
   `Parser.Input.Protocol` for checkpointing.
   `swift-binary-parser-primitives` ships
   `Binary.Bytes.Input.View` as the precedent for the
   `Span<UInt8>`-based event cursor pattern one layer down. The
   bench harness already wires the `Symbol` schema and the
   `codable-lookup` mode — no new measurement infrastructure is
   needed.

The 37 % gap is the measurable artifact of an architecture choice
the field has migrated past. The choice was load-bearing for the
14× dynamic-access lookup advantage; it remains load-bearing for
that path. The wedge is whether to add a second architecture for
the schema-known path — pattern β or γ alongside pattern α — and
which of β or γ better serves the constraints. Phase 2 produces
the prescription.

### Loose ends (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Whether the 37 % gap generalises to other partial-shape workloads (smaller documents, deeper schemas, larger N per object) | **direction** | The figure is workload-specific to the 86 MB symbol graph with mean N=2.06. A future synthetic-codable mode in the bench could characterise the gap's shape vs N. Filed as future work. |
| Whether pattern β's structural index would suffer the same refcount-per-copy wedge as the v2 arc's `Dictionary.Ordered` (per `copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1) | **premise** (would affect Phase 2's recommendation strength) | Per [BENCH-011], any β-shape implementation arc MUST integration-probe the map shape via the existing `synthetic-lookup` mode before promoting an isolated micro-bench. Premise is named here; Phase 2 must explicitly evaluate it. |
| Whether the Token-storage compiler bug (`RFC_8259.Span.Parser.swift` lines 18-28) remains a blocker on the current toolchain or has been fixed in 6.4-dev | **premise** (would affect Phase 2's pattern-γ feasibility) | The bug was documented mid-Phase-A1 (2026-05-13). A future re-verification spike (≤30 min) against Swift 6.4-dev nightly would close it. Filed as a Phase 2 verification gate, not as a Phase 1 follow-up — Phase 2 may need this answered before recommending γ. |
| Whether Apple's `JSON5Decoder` or any other Apple JSON tooling has a structurally different shape worth surveying | **direction** | Filed as future work; `JSON5Decoder` shares architecture with `JSONDecoder` (same `JSONMap` substrate with a `JSON5Scanner` variant per `swift-foundation/Sources/FoundationEssentials/JSON/JSON5Scanner.swift`). No new design-space contribution expected. |
| Whether `Parser.Protocol`'s `Self: ~Copyable` relaxation (per `2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` v1.1.0) would change the combinator-vs-hand-rolled question in Phase 2 | **direction** | The relaxation is Tier 3 deferred-until-second-consumer per [RES-018]; the streaming-deserialize arc does not depend on it. Phase 2 may note that combinator-based event parsers are foreclosed without this relaxation, but does not need to wait for it. |

## References

### Empirical predecessors (read; do not re-run)

- `swift-foundations/swift-json/Research/parse-performance.md` v1.2.1 (DECISION) — the motivating 37 % / 14× finding; §6 has the full Tier 0/1/3 outcomes.
- `swift-foundations/swift-json/Research/parse-performance-architecture.md` v1.0.2 (DECISION) — Tier 4 design; the phased-landing template Phase 2 will mirror.
- `swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0 (SUPERSEDED-BY-EVIDENCE) — the v2 arc; §12 constrains pattern β by example.
- `swift-institute/Research/copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1 (RECOMMENDATION) — the cross-cutting principle the v2 arc produced; Phase 2 storage-shape options must respect it.
- `swift-foundations/swift-json/Experiments/parse-performance-bench/Sources/parse-performance-bench/main.swift` — the standing measurement harness with `codable-lookup`, `crossover`, `synthetic-lookup`, `size-dist`, `lookup`, `sanity`, `equiv` modes.

### Current swift-json + swift-rfc-8259 surface

- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:42-92` — the `Serializable` protocol + the `init(jsonString:)` / `init(jsonBytes:)` convenience initializers (the call site this arc redesigns the call graph behind).
- `swift-foundations/swift-json/Sources/JSON/JSON.swift:60-70` — `JSON` value type + `RFC_8259.Value` backing storage.
- `swift-foundations/swift-json/Sources/JSON/JSON.Parse.swift` — `JSON.parse` accessor + `prepared()` + `located()` (public API surface to preserve).
- `swift-foundations/swift-json/Sources/JSON/JSON.Stream.swift` — `JSON.ND.stream` NDJSON + `JSON.parse(collecting:)` async surface (orthogonal to intra-document streaming).
- `swift-foundations/swift-json/Sources/JSON/JSON.Error.swift` — `JSON.Error` typed throws shape.
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.Parser.swift:32-76` — Tier 4 parser (the substrate for Phase 2).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.Lexer.swift:35-95` — Tier 4 cursor.
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Decode.swift:31-126` — dispatch fork on contiguous-bytes.
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Token.swift:13-46` — `RFC_8259.Token` enum (defined; bypassed by the Phase A1 Span parser).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Value.swift` — `RFC_8259.Value` enum (the output of the current pattern α parser).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Object.swift`, `RFC_8259.Array.swift` — container storage.

### Substrate references

- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift` — `Parser.Protocol` with `Input: ~Copyable & ~Escapable`.
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Input.swift` — `Parser.Input.Streaming` + `Parser.Input.Protocol` typealiases.
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift` — `Binary.Bytes.Input.View` precedent (the `~Copyable & ~Escapable` + `Span<UInt8>` + `@_lifetime(borrow span)` cursor).
- `swift-primitives/swift-input-primitives/Sources/Input Primitives/Input.swift:55-63` — the `Input.Borrowed` deferred future direction note.

### Prior institute research (cited in §1, §2)

- `swift-institute/Research/codable-untyped-throws-disposition.md` v1.0.0 (DECISION) — `JSON.Serializable` is the canonical typed-throws alternative to stdlib `Codable`; the `Lint.Manifest` adoption precedent.
- `swift-institute/Research/2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md` v1.2.0 — names `JSON.Serializable` as re-authorable on a `~Copyable` foundation (`Codable` cannot be).
- `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` v1.1.0 (Tier 3 RECOMMENDATION) — orthogonal Tier 3 work on `Parser.Protocol`'s `Self: ~Copyable` relaxation.
- `swift-institute/Research/data-structures-variant-catalog-parsers.md` — `swift-parser-primitives` variant catalog.

### Field / academic citations (primary sources)

- simdjson README + ondemand_design.md + v0.6 release notes:
  - https://github.com/simdjson/simdjson
  - https://github.com/simdjson/simdjson/blob/master/doc/ondemand_design.md
  - https://github.com/simdjson/simdjson/releases/tag/v0.6.0
  - https://lemire.me/blog/2021/09/25/new-release-of-the-simdjson-library-version-1-0/
- serde_json: https://github.com/serde-rs/json (License: MIT/Apache-2.0)
  - https://docs.rs/serde_json/latest/serde_json/
  - https://docs.rs/serde/latest/serde/
  - https://serde.rs/ (data-model, deserializer, lifetimes)
  - https://docs.rs/serde/latest/serde/de/struct.IgnoredAny.html
- jsoniter: https://github.com/json-iterator/go (License: MIT)
  - https://pkg.go.dev/github.com/json-iterator/go
- Apple swift-foundation `JSONDecoder`:
  - https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/JSON/JSONScanner.swift (`JSONMap` at line 65; `JSONScanner` at line 264; `offset(after:)` at lines 180-196; file header docs at lines 13-53)
  - https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/JSON/JSONDecoder.swift (`JSONDecoderImpl` at line 520; `KeyedContainer.stringify` at line 1238; two-phase dispatch at lines 401-422)
  - https://github.com/swiftlang/swift-corelibs-foundation/blob/main/Sources/Foundation/JSONDecoder.swift (Linux re-exports swift-foundation since 2023)
- System.Text.Json `Utf8JsonReader`:
  - https://learn.microsoft.com/en-us/dotnet/api/system.text.json.utf8jsonreader
  - https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/use-utf8jsonreader
- Newtonsoft `JsonTextReader`:
  - https://www.newtonsoft.com/json/help/html/T_Newtonsoft_Json_JsonTextReader.htm
  - https://www.newtonsoft.com/json/help/html/Performance.htm
- Academic papers:
  - [Langdale & Lemire 2019]: https://arxiv.org/abs/1902.08318 (DOI: 10.1007/s00778-019-00578-5)
  - [Mison (Li et al. 2017)]: http://www.vldb.org/pvldb/vol10/p1118-li.pdf (DOI: 10.14778/3115404.3115416)
  - [Sparser (Palkar et al. 2018)]: https://www.vldb.org/pvldb/vol11/p1576-palkar.pdf (DOI: 10.14778/3236187.3236207)
  - [JSONSki (Jiang & Zhao 2022)]: https://dl.acm.org/doi/10.1145/3503222.3507719 (DOI: 10.1145/3503222.3507719)
  - [JSR-173, 2004]: https://jcp.org/en/jsr/detail?id=173 and Oracle StAX tutorial https://docs.oracle.com/javase/tutorial/jaxp/stax/why.html

### Skill references

- [RES-003], [RES-003a], [RES-003b], [RES-003c] — research-doc shape + index registration
- [RES-005], [RES-010b] — analysis methodology + architecture analysis template
- [RES-018] — premature primitive anti-pattern; second-consumer hurdle
- [RES-019] — internal grep before external survey (executed; cited in §1)
- [RES-020] — Tier 2 classification + parallel subagent verification
- [RES-021] — prior art survey + contextualization step (executed in §4)
- [RES-023] — empirical-claim verification at write time
- [RES-026] — citations
- [RES-027] — loose-end follow-up (executed in Outcome)
- [HANDOFF-013], [HANDOFF-013a] — reader/writer prior-research grep
- [HANDOFF-049] — stash-edit-commit-pop for `_index.json` under cross-session contamination
- [BENCH-010], [BENCH-011] — benchmark deferral + integration-probe-requirement for storage benches under Copyable wrappers
- [ARCH-LAYER-007] — no-Foundation discipline across all five layers
- [ARCH-LAYER-011] — improve institute foundation; don't reach for Foundation or third-party libraries
- [API-NAME-001], [API-NAME-002], [API-ERR-001], [API-IMPL-005] — naming + typed throws + one-type-per-file conventions
- [PRIM-FOUND-001] — no Foundation in primitives/standards
- [MEM-COPY-001], [MEM-LIFE-001], [MEM-SAFE-001], [MEM-SAFE-020] — strict memory safety + lifetime annotations

## Provenance

Investigation invoked via the supervisor handoff at
`/Users/coen/Developer/HANDOFF-streaming-json-deserialize-research.md`
(Phase 1; 2026-05-14). Phase 1 is a descriptive characterisation;
Phase 2 (separate `/research-process` invocation) produces the
prescription. The parent session closed the parse-performance arc
(Tier 0/1/3/4 landed; v2 arc empirically refuted) and continues
separate work — files listed under the handoff's "Do Not Touch"
were read but not modified.
