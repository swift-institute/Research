# Parse Performance — Canada Anomaly (Numeric-Heavy Workload)

<!--
---
version: 1.4.1
last_updated: 2026-05-20
status: RECOMMENDATION (post-supervisor-review: pre-gates run; targeted @_specialize on lexer-primitives + cursor-primitives + tagged-primitives; ecosystem class-(c); honest Foundation-parity framing — Lever 1 brings 17× → ~13×, not parity)
tier: 1
---
-->

## Context

The `codec-throughput-vs-newcodable` cross-decoder benchmark
(`swift-foundations/swift-json/Experiments/codec-throughput-vs-newcodable/RESULTS.md`)
shipped 2026-05-19 with a workload-conditioned anomaly on the
canonical `canada.json` corpus (2.15 MB GeoJSON FeatureCollection of
deeply-nested `[[Double]]` coordinate arrays):

| Path | per-iter | MB/s | vs Foundation.JSONSerialization |
|---|---:|---:|---:|
| Foundation.JSONSerialization (bytes → tree) | 14.4 ms | 156 | 1.0× |
| **swift-json `JSON.parse([UInt8])` (bytes → tree)** | **253.3 ms** | **9** | **17× slower** |
| Apple NewCodable `JSONDecodable` (bytes → struct) | 5.43 ms | 414 | 0.36× (faster) |

The same swift-json parser is **1.4× slower** than
`JSONSerialization` on `twitter.json` (consistent with the
post-Tier-4 baseline in `parse-performance.md` v1.2.0 — 1.02× on the
86 MB Swift stdlib symbol graph) and **4.7× slower** on
`citm_catalog.json`. Canada is in a different regime entirely.

Methodology note: the institute harness uses SUM-over-256 (≈ mean),
Apple uses MIN-of-256. The methodology gap accounts for at most
~10–20%, not the 17× observed. The anomaly is real.

The post-Tier-4 status quo per `parse-performance.md` v1.2.0
("Foundation parity achieved on the bytes path; 1.06× on the String
path — both well below the 1.3× target") was measured on the
**symbol-graph workload** (86 MB, predominantly string-heavy with
identifiers, kind names, doc comments). The Tier-4 Span lexer + lazy
position closed the cursor wedges and the tree-teardown wedge moved
from ~7 % to ~15 % (Amdahl shift, predicted and accepted in
`parse-performance-architecture.md` §7). Canada exposes a different
workload regime — numeric-heavy rather than string-heavy — where the
post-Tier-4 hot path is dominated not by cursor, not by tree teardown,
but by the **per-number construction path** in `lexNumberValue`.

This document identifies the exact code path, sizes the cost against
the canada workload, compares to NewCodable's parser-driven design,
and recommends a small targeted patch.

## Question

What in swift-json's parse pipeline makes `canada.json` 17× slower
than Foundation, and is the fix a small targeted patch or does it
require waiting for the streaming-deserialize event-grain arc?

## Hypothesis

Per-element allocation in the array path — either per-Double,
per-inner-array, or per-Number-token — dominates the wall-clock on
numeric-heavy workloads.

## Workload characterization

`canada.json`:

| Statistic | Value | vs twitter.json | vs citm_catalog.json |
|---|---:|---:|---:|
| Size | 2,251,051 bytes (2.15 MB) | 3.6× | 1.3× |
| Number tokens | 111,126 | 14.2× | 7.4× |
| Number density | 50.6 / KB | 4.0× | 5.7× |
| Avg number length | 18.25 bytes | — | — |
| Numbers > 16 bytes | 108,562 (97.7 %) | — | — |
| Arrays (`[`) | 56,045 | 53× | 5.4× |
| Objects (`{`) | 4 | — | — |
| Max nesting depth | 7 (Polygon coords up to `[[[Double]]]`) | — | — |
| Leaf `[Double, Double]` arrays | 55,563 | — | — |
| Doubles per leaf array | 2.00 (mean) | — | — |

[Verified: 2026-05-19] enumerated against
`/Users/coen/Developer/swiftlang/swift-foundation/Tests/NewCodableBenchmarks/Resources/canada.json`
with a one-shot Python regex scan.

Two-thirds of the file's tokens are JSON numbers. The remaining work
is the array brackets and commas that wrap them. There are essentially
no objects, no strings beyond a handful of top-level keys, and no
escapes. It is the parser's **per-number cost** at scale that matters.

## Findings — what the parser actually does per Number

The current contiguous-bytes parse path lives at
`/Users/coen/Developer/swift-foundations/swift-json/Sources/JSON/JSON.Decode.Implementation.swift`.
(Note: this is the Span-specialized fast path that replaced the old
`RFC_8259.Lexer.swift` per Arc 1.6 namespace correction + streaming-
deserialize placement audit Ticket T-1; the `RFC_8259.Lexer.swift`
file the historical docs cite no longer exists in the live tree.)

The hot loop runs `parseValue` → `lexNumberValue` (lines 557–661 of
`JSON.Decode.Implementation.swift`). Each Number does:

### Step 1 — Stack-only digit accumulation (cheap)

Line 559:
```swift
var bytes = Array_Primitives.Array<UInt8>.Small<24>()
```

`Array.Small<24>` is institute inline-only storage. Bytes are
appended via `scanner.consume()` in tight loops at lines 562–626.
This is stack-only — no heap allocation. **Cost ≈ free.**

### Step 2 — First heap allocation: `byteArray: [UInt8]`

Lines 629–635:
```swift
let span = bytes.span
let byteArray: [UInt8] = .init(unsafeUninitializedCapacity: span.count) { dst, initialized in
    for i in 0..<span.count {
        dst[i] = span[i]
    }
    initialized = span.count
}
```

For canada's 111,126 numbers averaging 18.25 bytes each, this is
**111,126 `Swift.Array<UInt8>` allocations of ~20-byte payload**. Each
allocation goes through `swift_allocObject` / `slowAlloc`.

### Step 3 — Second heap allocation: `RFC_8259.Number.Original(byteArray)`

Line 636 calls into
`/Users/coen/Developer/swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Number.Original.swift:24-31`:

```swift
public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == UInt8 {
    let array = Swift.Array(bytes)
    if array.count <= 23 {
        self.init(storage: .inline(Inline(array)))
    } else {
        self.init(storage: .heap(array))
    }
}
```

This **re-allocates** the bytes a *second* time as `Swift.Array(bytes)`.
The receiver `bytes` is already a contiguous `Swift.Array<UInt8>` from
step 2, but the generic initializer takes a `Collection`, sees no
specialization opportunity (release-mode generic specialization may or
may not collapse this — but a verbatim re-`Array(bytes)` is the
specified semantics regardless of whether the optimizer elides it).

The Inline path (`Inline.init(bytes:)` at
`RFC_8259.Number.Original.Inline.swift:40-66`) then copies the array
contents into 23 individual `UInt8` slots via 23 sequential
`if bytes.count > N { bN = bytes[N] }` statements. **Three allocations
on this path** so far per Number: the L1 byte-array, the L1 re-array,
and the inline struct itself (stack — free).

### Step 4 — Third heap allocation: `numStr`

Line 637:
```swift
let numStr = String(decoding: byteArray, as: UTF8.self)
```

For ASCII-only bytes (which JSON numbers always are — they are
`-?[0-9.eE+]+`), `String(decoding:as:)` allocates a fresh `String`
backing store. **Per number, one `String` allocation of ~20 bytes.**

### Step 5 — Per-number `Double(numStr)`

Lines 640–660:
```swift
if isFloat {
    guard let value = Double(numStr), value.isFinite else { ... }
    return RFC_8259.Number(value, original: original)
} else {
    if let value = Int64(numStr) { ... }
    else if let value = UInt64(numStr) { ... }
    else if let value = Double(numStr), value.isFinite { ... }
}
```

`Double.init(_: String)` walks the string character-by-character
through the LosslessStringConvertible parser path. For canada's
`-65.613616999999977`-style coordinates (15-decimal-digit precision),
this is the dominant per-number CPU cost.

### Step 6 — Per-element `[RFC_8259.Value].append`

`parseArray` (lines 187–227) starts with `var elements: [RFC_8259.Value] = []`
**with no `reserveCapacity` hint** (line 194). For canada's 55,563 leaf
`[lng, lat]` arrays this is fine (only 2 appends each), but for the
intermediate ring-of-points arrays (which can be hundreds of points
each) this triggers Array doubling — 4, 8, 16, 32, … — and each
doubling reallocates the storage buffer. Foundation pre-sizes its
output array using a single forward scan, or uses a growable buffer.
**Cost: O(log n) doublings per array × 56,045 arrays.**

### Aggregate per-parse on canada

| Step | Allocs per parse | Bytes allocated per parse (rough) |
|---|---:|---:|
| 1. `Array.Small<24>` | 0 (stack) | 0 |
| 2. `byteArray: [UInt8]` | **111,126** | ~2.2 MB (avg 20 B + Array overhead) |
| 3. `Swift.Array(bytes)` re-allocation inside `Original.init` | **111,126** | ~2.2 MB |
| 4. `numStr: String` | **111,126** | ~2.2 MB |
| 5. `Double.init(_: String)` ARC traffic | (no alloc, but per-char loop) | — |
| 6. `[RFC_8259.Value].append` doublings | ~O(arrays · log size) | growing |
| **Total** | **≥ 333,000 heap allocations** | **≥ 6.6 MB** |

For a 2.15 MB input. The parser's allocator traffic alone is **3× the
size of the input** before the value tree itself is materialized.

Numbers > 23 bytes (the heap fallback in `Original.init`) are zero on
this workload — all 111,126 numbers fit inline — so the **only** uses
of the byteArray and the re-allocated `Swift.Array(bytes)` are to be
copied into the 23-byte inline struct and then *discarded*. They are
write-and-throw-away allocations.

## Comparison

### Foundation.JSONSerialization

C-backed (`CoreFoundation` under the hood, `_NSJSONReader`). Parses
numbers directly into `NSNumber` via inline character-by-character
accumulation against the underlying byte pointer; allocates the
output value once. Arrays grow via `CFArray`'s growable buffer with
geometric reallocation but with the buffer reused across the value
tree (one buffer, not one per array). No String round-trip, no
double-allocation for byte storage.

Result: 156 MB/s on canada — same regime as twitter (250 MB/s),
within the linear scaling of input size.

### Apple NewCodable JSONDecodable (`bytes → struct`)

The structurally different design: it is **parser-driven**, not
tree-driven. The parser visits each value and the consumer's
`JSONDecodable` conformance pulls the value into a target field
directly. Arrays of `Double`: the parser sees `[`, then on each
element calls back to `Double.init(jsonContents:)` which reads the
digit bytes off the parser cursor and produces a Double in-place.
No `RFC_8259.Value` is ever materialized.

In `JSONParserDecoder.ArrayDecoder` at
`/Users/coen/Developer/swiftlang/swift-foundation/Sources/NewCodable/JSON/JSONParserDecoder.swift:379-446`,
each element is consumed via `prepareForArrayElement` (line 412/431)
and emitted into the consumer's `~Copyable` storage directly. The
`InlineArray` types at lines 257/275/494 are stack-allocated path
nodes for diagnostics, not storage for parsed values. Numbers are
parsed via the cursor's number-parsing path without ever forming a
`String` or a `Number` wrapper enum.

Result: 414 MB/s on canada. The per-number cost is the digit-scan
plus the Double conversion; nothing else.

### swift-json — where the cost goes

The 17× gap to Foundation on canada decomposes (approximately, from
the alloc-count + scan-cost analysis above) as:

- **Allocator traffic**: 333,000+ heap allocations across 256 iter ≈
  85 million allocations in the SUM-over-256 measurement. Even at
  10ns/allocation (optimistic for Swift's `swift_allocObject` with
  ARC), that's ~850 ms across 256 iterations or **~3.3 ms per parse
  attributable to allocator alone**. The observed 253.3 ms per parse
  is dominated by something else (likely the string-round-trip
  Double parsing and the array doublings) but allocator pressure is
  a substantial contributor.
- **`Double.init(_: String)`** character-by-character parsing on
  111,126 strings per parse. At ~15 characters × ~5ns per character
  = ~75ns × 111,126 = **~8.3 ms per parse on the float-parsing
  alone**. Likely understated; the LosslessStringConvertible path is
  not aggressively optimized.
- **`[RFC_8259.Value].append` doublings** across 56,045 arrays. The
  leaf 2-element arrays are cheap; the intermediate ring arrays
  (hundreds to thousands of points each) trigger many doublings.
- **`outlined destroy of RFC_8259.Value`** recursive teardown per
  iteration — the post-Tier-4 profile attributed ~15 % of the symbol-
  graph parse to this; on canada's 333,338+ Values (1 per number +
  array nodes + nesting) this is materially more dominant.

The hypothesis "per-element allocation in the array path" is
**partially confirmed** — the array path itself is not the worst
offender (Swift.Array doubling is well-optimized), but the
**per-Number construction path** with **three heap allocations per
number** plus the **`Double.init(_: String)` character-by-character
parse** is. On a 50.6-numbers-per-KB workload, those costs sit on the
critical path of every byte.

## Effort estimate

Three independent patches, each small. Land in this order — each is
independently shippable and reversible. Order is value-density × risk.

### Patch 1: Skip the redundant `byteArray` + the `numStr` (SMALL — ~30 LoC)

**Location**: `JSON.Decode.Implementation.swift:629-660`.

**Today**:
```swift
let span = bytes.span
let byteArray: [UInt8] = .init(unsafeUninitializedCapacity: ...) { ... }
let original = RFC_8259.Number.Original(byteArray)
let numStr = String(decoding: byteArray, as: UTF8.self)

if isFloat {
    guard let value = Double(numStr), value.isFinite else { ... }
    return RFC_8259.Number(value, original: original)
} else {
    if let value = Int64(numStr) { ... }
    ...
}
```

**Patch**:
- Pass `bytes.span` directly to a new
  `RFC_8259.Number.Original(_ bytes: borrowing Swift.Span<UInt8>)`
  initializer that constructs `Inline` directly from the span (no
  intermediate `Swift.Array`). Since `bytes` is already
  `Array.Small<24>`, its span is the inline storage; the Inline
  struct copy is 23 byte-field stores, no allocator involved.
- For the float branch, parse the Double off `bytes.span` directly
  via either:
  - A new `RFC_8259.Number.Parsed.float(fromASCII: borrowing Swift.Span<UInt8>) -> Double?`
    helper that does in-place digit accumulation (mirror the existing
    integer path's structure).
  - OR (faster to land): construct the `String` ONCE via
    `String(unsafeUninitializedCapacity:initializingUTF8With:)` from
    the span (same shape as `lexStringValue`'s ASCII fast path at
    line 413–420), use it once for `Double.init(_:)`, then discard.
    Saves one allocation per number, not three, but it's a one-line
    change.
- For the integer branch: prefer `ASCII.Decimal.Parser<Span<UInt8>, Int64>` from
  `swift-ascii-parser-primitives` (this is the Tier 2 of the
  predecessor `parse-performance.md` doc, still HELD). The integer
  branch fires on canada's `0`-token cases only (the leading `0` of
  each `0.xxx` longitude/latitude is the integer part, but the
  decimal point triggers `isFloat = true` so the integer-only branch
  doesn't fire). On canada, the integer branch may be cold — but
  citm and twitter exercise it.

**Saves**: 2 of 3 allocations per Number. For canada that's
~222,000 fewer allocations per parse. Estimated wall-clock savings:
~3-5 ms per parse from allocator alone, plus the cache-pressure
benefit of not touching ~4.4 MB of throwaway memory per parse.

### Patch 2: Pre-allocate `parseArray` storage when shape is predictable (SMALL — ~10 LoC)

**Location**: `JSON.Decode.Implementation.swift:194`.

**Today**:
```swift
var elements: [RFC_8259.Value] = []
```

**Patch**: it's impossible to know array size without a forward scan
(JSON is not length-prefixed), but a default reserve of e.g. 4 or 8
elements eliminates the early doublings that dominate the leaf-array
cost. For canada, where 55,563 of the 56,045 arrays have exactly 2
elements, `reserveCapacity(2)` matches the workload precisely. A
broader `reserveCapacity(4)` is a defensible default that doesn't
hurt large arrays.

```swift
var elements: [RFC_8259.Value] = []
elements.reserveCapacity(4)
```

**Saves**: 1-3 reallocation calls per leaf array × 55,563 arrays =
**~110,000 fewer Array reallocations per parse on canada**. Minor
effect per call but it's a high-frequency hot path.

### Patch 3 (longer): Fast-path the Double parser (MEDIUM — needs evaluation)

The institute does NOT currently have an Eisel-Lemire-class fast
Double parser. The predecessor doc's Tier 2
(`swift-ascii-parser-primitives/Sources/ASCII Decimal Parser Primitives/ASCII.Decimal.Parser.swift`)
covers integers only. The state of the art for fast Double parsing
(Eisel-Lemire 2020 / Lemire 2021) is a multi-hundred-line piece of
work; it does not yet exist in the ecosystem.

This is out of scope for "small targeted patch". Defer until either:
(a) a fast-Double primitive lands in `swift-ascii-parser-primitives` or
similar, OR (b) a structural change (the streaming-deserialize event-
grain path) bypasses the per-Number wrapper entirely on the consumer
side. See "Recommendation" below.

## Comparison summary

| Approach | Allocator traffic per Number | Per-Number CPU |
|---|---|---|
| Foundation.JSONSerialization | 1 alloc (the NSNumber) | Inline digit accumulation, C-coded Double parse |
| Apple NewCodable JSONDecodable | 0 (target field is consumer storage) | Inline digit accumulation, single Double materialize into the consumer field |
| swift-json **today** | **3 allocs** (byteArray, re-array, numStr) + 1 enum wrapping | `Double.init(_: String)` character-by-character |
| swift-json **with Patch 1+2** | 0-1 alloc | `Double.init(_: String)` (still) — patch 3 to remove |
| swift-json **with Patches 1+2+3** | 0-1 alloc | Fast Double parse |

## Outcome

**Status**: RECOMMENDATION.

**Hypothesis disposition**: PARTIALLY CONFIRMED. The "per-element
allocation" framing is right in spirit but wrong in specifics. The
array path itself is not the dominant cost — `Swift.Array` doubling
is well-optimized. The dominant cost is **per-Number construction
overhead**: three heap allocations per Number, all of which are
write-and-throw-away on canada's workload (where every number fits
inline in 24 bytes and the byteArray + re-allocated array exist only
to be copied into the inline struct and then discarded), plus the
String round-trip in the Double parsing path.

### Recommendation

**Patches 1 and 2 are small, surgical, and target-correct.** They
should land as a single arc against
`JSON.Decode.Implementation.swift` (and a new
`RFC_8259.Number.Original(_ bytes: borrowing Swift.Span<UInt8>)`
initializer at
`swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Number.Original.swift`).
Estimated total: ~40 LoC change, behind no API surface change,
preserves the typed-throws contract, preserves the existing public
`Number.Original(_ bytes:)` initializer for non-Span call sites.

**Estimated wall-clock impact on canada**: 253 ms → 100-150 ms per
parse (40-60 % reduction), bringing the gap to Foundation from 17×
to **~6-10×**. The remaining gap is dominated by `Double.init(_: String)`
(Patch 3, out of scope) and the value-tree teardown (which has no
small-patch fix — see `value-tree-redesign-v2.md` SUPERSEDED-BY-EVIDENCE).

**Estimated wall-clock impact on twitter / citm**: Smaller. Twitter
has 7,821 numbers in 631 KB; the per-Number savings × 7,821 ≈ 0.5 ms
saved on a 3.6 ms parse. Citm: 14,986 numbers; perhaps 1 ms saved on
19 ms. Symbol-graph (the canonical 86 MB workload from
parse-performance.md v1.2.0) has even lower number-density and is
unlikely to regress; if anything it benefits slightly.

### Answer to the load-bearing question

**"Is the canada anomaly fixable with a small patch, or does it
require waiting for the streaming-deserialize event-grain arc?"**

**Both, but the small patch closes most of the gap.** The streaming-
deserialize / event-grain path (`JSON.Span.EventStream` at
`swift-json/Sources/JSON/JSON.Span.EventStream.swift`) addresses a
**different** axis: it lets consumers bypass the
`RFC_8259.Value` materialization entirely for `JSON.Serializable`
conformances. That arc closes the gap to Apple's NewCodable-class
performance on `bytes → struct` workloads (consumer-typed shape) by
removing the tree allocation entirely. It does NOT address the per-
Number cost on the `bytes → tree` workload (which canada's benchmark
measures), because the tree workload still materializes every Value.

Patches 1+2 close most of the bytes-→-tree gap. Patches 1+2+3 close
all of it. The streaming-deserialize arc complements but does not
substitute for these patches: a consumer that wants
`RFC_8259.Value` (the symbol-graph oracle, JSONPath queries, dynamic-
member-lookup access) still goes through the tree path, where the
per-Number cost dominates on numeric-heavy inputs.

The framing "swift-json is slow on canada because the tree is the
wrong shape for numeric-heavy data" is partially right — but the
tree is **also** ~3× more allocator-pressured than it needs to be on
the per-Number path. Fix the per-Number path first (small patches,
this doc), then revisit the tree-shape question when a consumer
proves a workload that the per-Number fix doesn't close.

### Out of scope

- **Patch 3 (fast Double parser)**: deferred until a fast-Double
  primitive lands in `swift-ascii-parser-primitives` or similar.
  Closes the residual gap to Foundation on numeric workloads. The
  ecosystem does not have an Eisel-Lemire-class parser today
  ([Verified: 2026-05-19] — `swift-ascii-parser-primitives` has
  `ASCII.Decimal.Parser` for integers only; no fast float parser
  surfaced in any prior research doc).
- **Tree-shape redesign**: `value-tree-redesign-v2.md` is SUPERSEDED-
  BY-EVIDENCE — Copyable wrapper + multi-buffer storage refcount-per-
  copy dominates O(1) gains at small N. Not pursued.
- **Streaming-deserialize event-grain on `bytes → tree`**: by
  design, the event-grain path emits into consumer storage, not into
  `RFC_8259.Value`. It cannot speed up the `bytes → tree` workload
  without abandoning the tree as the output. That's a separate
  consumer-driven decision, not a parser optimization.

## References

### Predecessor and prior art (institute corpus)

- `swift-foundations/swift-json/Research/parse-performance.md` v1.3.0
  (DECISION) — Tier-4 LANDED, Foundation parity 1.02× on 86 MB
  symbol-graph; defines the post-Tier-4 baseline this doc analyses.
  §6 *Residual gap* enumerates the tree-teardown wedge that grew
  from ~7 % to ~15 % post-Tier-4 (Amdahl shift) — confirms tree
  teardown is also a residual concern on canada, but secondary to
  the per-Number cost.
- `swift-foundations/swift-json/Research/parse-performance-architecture.md` v1.0.2
  (DECISION) — Tier-4 architecture doc; defines Architecture A (Span
  cursor + existing tree) and notes "Phase B (arena tree) NOT triggered"
  on the symbol-graph workload. Canada's per-Number cost is a
  different wedge than Phase B's tree-shape question.
- `swift-foundations/swift-json/Research/value-tree-redesign-v2.md`
  (SUPERSEDED-BY-EVIDENCE 2026-05-13) — v2 tree was rolled back;
  parse +339 %, lookup +226 %. Refcount-per-copy dominates O(1)
  gains at small N. The tree shape stays.
- `swift-foundations/swift-json/Experiments/codec-throughput-vs-newcodable/RESULTS.md`
  (2026-05-19) — the data this doc analyses.

### Current parser surface (verified against live code)

- `/Users/coen/Developer/swift-foundations/swift-json/Sources/JSON/JSON.Parse.swift:48-72`
  — public `JSON.parse(_: String)` / `JSON.parse(_: Bytes)` entry,
  delegates to `JSON.Decode.parse`.
- `/Users/coen/Developer/swift-foundations/swift-json/Sources/JSON/JSON.Decode.swift:43-69`
  — `JSON.Decode.parse(_: C, maxDepth:)` Collection dispatcher;
  `withContiguousStorageIfAvailable` fast path; falls back to
  `Swift.Array(bytes)` materialization.
- `/Users/coen/Developer/swift-foundations/swift-json/Sources/JSON/JSON.Decode.Implementation.swift:557-661`
  — `lexNumberValue`. **The per-Number hot path. The patches in this
  doc target lines 629-660.**
- `/Users/coen/Developer/swift-foundations/swift-json/Sources/JSON/JSON.Decode.Implementation.swift:187-227`
  — `parseArray`. Patch 2 target at line 194.
- `/Users/coen/Developer/swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Number.Original.swift:24-31`
  — `Original.init(_ bytes:)`. **The redundant re-`Swift.Array(bytes)`
  is at line 25.** Patch 1 adds a sibling `init(_ bytes: borrowing Swift.Span<UInt8>)`.
- `/Users/coen/Developer/swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Number.Original.Inline.swift:40-66`
  — `Inline.init(_ bytes:)`. The 23-field byte-by-byte copy. Already
  Span-compatible in shape; a sibling Span-taking init is trivial.

### NewCodable comparison

- `/Users/coen/Developer/swiftlang/swift-foundation/Sources/NewCodable/JSON/JSONParserDecoder.swift:379-446`
  — `ArrayDecoder` parser-driven array consumption; no tree
  materialization.
- `/Users/coen/Developer/swiftlang/swift-foundation/Sources/NewCodable/JSON/ParserState.swift:1703-1710`
  — `expectBeginningOfArray` / `expectArrayComma`. The cursor-level
  array boundary detection; consumer code at line 412/431 of
  `JSONParserDecoder.swift` pulls each element into typed storage
  directly.

---

## v1.1.0 — Patch 3 LANDED, Predicted Wall-Clock Win Did NOT Materialize

Date: 2026-05-19. EL parser implemented + integrated + benchmarked.

### What landed

- `swift-primitives/swift-ascii-parser-primitives` commits `4f8f572` +
  `56bf873`:
  - `ASCII.Decimal.Float.Parser<Input>` (`Parser.Protocol` conformer)
    parses ASCII decimal floats from any `Collection.Slice.Protocol`
    byte source via three-tier strategy:
    (1) Clinger fast path for mantissa ≤ 2⁵³−1 and exponent in [−22, 22],
    (2) Eisel–Lemire core via `UInt64.multipliedFullWidth(by:)` + a
        verbatim port of fast_float's 128-bit power-of-five table
        (q ∈ [−342, +308], 651 entries × 2 UInt64 ≈ 10 KiB rodata),
    (3) Slow path — stdlib `Double.init(_: String)` for >19-digit
        literals (rare in JSON).
  - `ASCII.Decimal.Float.parse(_: borrowing Swift.Span<UInt8>)` static
    span entry for hot-path callers (`Swift.Span<UInt8>` does not
    conform to `Collection.Slice.Protocol` — separate entry point).
  - 30 stdlib-agreement tests passing on Swift 6.3.2 / macOS 26 arm64,
    including canada coordinate shape, subnormals, infinities,
    neg-zero, 19-digit boundary, 20-digit slow path, JSON-typical
    numbers, round-to-even edges.
- `swift-foundations/swift-json` (this doc's repo): `lexNumberValue`
  float branch now calls `ASCII.Decimal.Float.parse(span)` directly on
  the inline-storage span. `numStr: String` allocation is eliminated
  on the float branch (integer branch keeps it for
  `Int64`/`UInt64`/fallback `Double`).

### What the wall-clock said

Methodology: min-of-3, SUM over 256 iterations, same
`parse-performance-bench` harness as v1.0.0, same machine.

| Payload | Pre-EL (ms/iter) | Post-EL (ms/iter) | Δ |
|---|---:|---:|---:|
| Twitter (617 KB, 7821 floats) | 3.61 | 3.33 | −7.8% |
| Canada (2.15 MB, 111126 floats) | 253.3 | 239.5 | −5.5% |
| CITM (1.65 MB, 14986 floats) | 19.6 | 18.5 | −5.6% |

Predicted canada wall-clock per v1.0.0's "Comparison summary" table:
**30–60 ms/iter** (~2–4× Foundation). Observed: **239.5 ms/iter**
(~17× Foundation), virtually unchanged.

The handoff that authored Patches 1+2 framed `Double.init(_: String)`
as "the dominant cost (~111–222 ms per parse of the 246 ms)". This
framing is **empirically wrong**. The actual `Double.init(_: String)`
cost on canada is closer to ~10 ms per parse (the v1.0.0 doc's deep-
level estimate of ~75 ns × 111,126 calls ≈ 8.3 ms; the 111–222 ms
figure conflated total parse cost with float-parse cost).

### Where the 239 ms actually goes

Bounded empirically by what Patches 1, 2, and 3 collectively *failed*
to budge:

- Allocator traffic (Patches 1+2 attacked): −7 ms / 246 ms total
  (~3%). Real but minor.
- `Double.init(_: String)` (Patch 3 attacked): −7 ms / 246 ms total
  (~3%). Real but minor.
- **Remaining ~230 ms must be in the tree-construction layer**:
  - `RFC_8259.Value` enum allocation × 333K+ Values per parse (1 per
    Number + 1 per Array node + nesting).
  - `[RFC_8259.Value].append` doublings across the 56K intermediate
    arrays (Patch 2's `reserveCapacity(4)` covered the leaf-array
    case but not the longer ring arrays).
  - Tree teardown via `outlined destroy of RFC_8259.Value` — was
    ~15% on the symbol-graph workload, materially more on canada's
    deeper tree.

The framing "swift-json is slow on canada because the tree is the
wrong shape for numeric-heavy data" (v1.0.0 § Out of scope) is now
strongly supported by empirical bounds: the three small patches that
addressed everything *outside* the tree shape collectively saved
~14 ms; the remaining ~230 ms is structurally constrained by
`RFC_8259.Value`'s tree.

### What this means for the canada anomaly

The anomaly is **not closeable by faster float parsing**. It is also
**not closeable by faster allocator pressure** (Patch 1's framing was
already weak; v1.1.0 confirms). The 17× Foundation gap is a
**value-tree-shape** problem. Closing it requires one of:

- A different tree shape that doesn't pay `RFC_8259.Value` per
  Number. `value-tree-redesign-v2.md` was SUPERSEDED-BY-EVIDENCE
  (refcount-per-copy dominated O(1) gains at small N); a different
  shape may be needed. Out of scope here.
- A consumer-driven path that bypasses the tree entirely — the
  `JSON.Span.EventStream` event-grain arc (`bytes → consumer struct`
  via `JSON.Serializable` conformances). Closes the gap for
  consumers that don't need the tree; doesn't close it for those
  that do.

### What the EL landing *did* deliver

Independent of canada's wall-clock:

- L1 primitive (`ASCII.Decimal.Float.Parser`) reusable by every
  downstream JSON/TOML/CSV/YAML consumer.
- Allocator-traffic reduction: ~111K String allocations × ~20 bytes
  ≈ 2.2 MB per canada parse, eliminated.
- Twitter and CITM both pick up ~6–8% from the elimination, stable
  across runs.
- Correctness floor: 30 stdlib-agreement tests including subnormal,
  infinity, neg-zero, round-to-even. Future consumers parsing edge-
  case floats get a typed-throws-clean path.

### Hypothesis disposition (final)

- v1.0.0 hypothesis "per-element allocation in the array path
  dominates": PARTIALLY CONFIRMED — array allocator is a contributor
  but minor (~3%).
- v1.0.0 hypothesis "`Double.init(_: String)` IS the dominant cost":
  **REJECTED**. Float-parsing cost is ~10 ms, not ~100+ ms.
- v1.0.0 projection "Patches 1+2+3 close most of the bytes-→-tree
  gap, bringing canada to 30–60 ms": **REJECTED**. Patches 1+2+3
  delivered ~7% total improvement (~246 → ~239 ms). The bytes-→-tree
  gap is structurally bound by `RFC_8259.Value`-tree cost; no patch
  to allocator pressure or float parsing closes it.
- New hypothesis: "the residual 230 ms is `RFC_8259.Value` enum
  allocation + tree teardown + intermediate array doublings". Bounded
  empirically by elimination; not yet directly profiled.

### Recommendation (revised)

- Patches 1+2+3 have landed. They are correctness-positive and yield
  modest (~6–8%) speedups on numeric workloads — keep them.
- The canada anomaly is now a **tree-shape problem**, not a parser
  problem. Recommendations for closing the 17× gap belong in a
  separate research arc focused on `RFC_8259.Value` allocation /
  teardown / array growth.
- Consumers willing to bypass `RFC_8259.Value` entirely (consume
  events into typed structs via `JSON.Serializable`) should look at
  the `JSON.Span.EventStream` arc — that's the path to NewCodable-
  class performance on bytes → struct, independent of this anomaly.

### Skill references (v1.1.0 additions)

- [HANDOFF-016] (proposal-staleness, premise-staleness axes) —
  v1.0.0's premise about `Double.init(_: String)` cost was stale
  against the empirical 6 ms / 246 ms ratio.
- [RES-018] — correctness-and-evergreen judgment carried this work;
  the EL parser is the right L1 primitive regardless of whether it
  closes canada specifically.
- [BENCH-005] — comparison benchmark methodology preserved across
  v1.0.0 → v1.1.0; same harness, same payloads, same SUM-over-256.

### Skill references

- [API-NAME-001], [API-NAME-001a] — naming the new Span-taking
  initializer on `RFC_8259.Number.Original` (variant on the existing
  type, not a sibling type).
- [API-ERR-001] — typed throws preserved at every layer
  (`throws(RFC_8259.Error)`).
- [MEM-COPY-001], [MEM-LIFE-001], [MEM-SPAN-001] — `borrowing Swift.Span<UInt8>`
  + `@_lifetime` annotations on the new init.
- [IMPL-INTENT], [IMPL-COMPILE] — the patch removes mechanism
  (allocator pressure) without removing intent (lossless number
  preservation).
- [RES-019] — internal prior-art grep performed; this doc cites the
  parse-performance arc, value-tree-redesign-v2, and the codec-
  throughput experiment per [HANDOFF-013] / [RES-019].
- [RES-023] — empirical claims (workload counts, file:line citations)
  verified at write time per the rule.
- [RES-027] — loose-end follow-up is bound to a concrete patch path
  (Patches 1+2 → small arc, Patch 3 → deferred with explicit gating
  condition).

---

## v1.2.0 — Microbench Validation (2026-05-20)

Date: 2026-05-20. Per-call microbench of `ASCII.Decimal.Float.parse`
vs `Double(_: String)` on real canada float tokens. The v1.1.0
disposition rested on SUM-of-N noisy wall-clock data; this section
empirically validates the tree-shape claim at per-call granularity.

### Verdict: VALIDATED

v1.1.0's claim — that the residual ~240 ms canada parse time is
dominated by `RFC_8259.Value` enum allocation + tree teardown +
intermediate array growth, **not** by `Double` parsing — is
empirically validated by direct per-call measurement.

### Methodology

Extended `parse-performance-bench` (commit landing alongside this
section) with two CLI modes:

- `stats` — MIN/median/p90/mean per-iter, 16 warmup + 256 measured
  iters of Foundation.JSONSerialization and JSON.parse([UInt8])
  back-to-back. MIN-of-N + warmup is Apple's NewCodable canonical
  low-noise summary.
- `float-microbench` — scans the input for float-shaped numbers
  (numbers containing `.`, `e`, or `E` — the production set
  `lexNumberValue` routes through EL). Per token: verifies
  `ASCII.Decimal.Float.parse(span)` agrees bit-for-bit with
  `Double(_: String)`; times both per-call across 16 warmup + 256
  measured iters; reports per-call ns MIN/median/p90/mean and the
  derived wall-clock-savings ceiling `N × (t_stdlib − t_EL)`.

Run conditions: `caffeinate -i swift run -c release` on macOS 26
(arm64), Swift 6.3.2, swift-json HEAD at `1f4601f` (Patches 1+2+3
all landed). Bench commit + run pre-registered before adjudication.

Workload: `canada.json` (`/Users/coen/Developer/swiftlang/swift-foundation/Benchmarks/Benchmarks/JSON/Resources/canada.json`,
2.15 MB, 2 251 051 bytes). Path note: the v1.1.0 handoff cited an
older path under `Tests/NewCodableBenchmarks/Resources/`; the live
canonical source on this disk is under `Benchmarks/Benchmarks/JSON/`
(unchanged file, different in-repo location post-relocation in the
upstream).

### Results — stats (256 iters, MIN-of-N)

| Statistic | Foundation (ms/iter) | swift-json (ms/iter) | swift-json / Foundation |
|---|---:|---:|---:|
| min     | 13.600   | 235.616  | 17.32× |
| median  | 14.240   | 260.483  | 18.29× |
| p90     | 16.116   | 363.166  | 22.53× |
| mean    | 15.636   | 310.782  | 19.88× |

Methodology comparison: the brief's expected 12.1× was derived
against a Foundation baseline of 20.10 ms; on this machine
Foundation parses canada in 13.60 ms (faster baseline, same payload,
different system state) — the ratio inflates accordingly. Canonical
swift-json absolute time (235.6 ms) matches the brief's 243.9 ms
within ±3% noise. The 17× shape persists.

### Results — float-microbench (256 iters, 111 080 tokens)

Token collection: 111 080 float-shaped tokens in canada
(mean length 18.25 bytes; v1.1.0 cited 111 126 — small delta is
integer-valued numbers excluded by the `sawDot || sawExp` filter,
which mirrors `lexNumberValue`'s `isFloat` predicate).

Bit-pattern verification: **0 mismatches across all 111 080
tokens**. `ASCII.Decimal.Float.parse(span).bitPattern ==
Double(strForm)!.bitPattern` holds universally.

| Statistic | EL (ns/call) | stdlib (ns/call) | stdlib / EL |
|---|---:|---:|---:|
| min     | 21.300 | 23.488 | 1.10× |
| median  | 22.218 | 26.782 | 1.21× |
| p90     | 23.190 | 29.249 | 1.26× |
| mean    | 22.663 | 30.317 | 1.34× |

Wall-clock-savings ceiling per parse, `N × (t_stdlib − t_EL)`:

| Pairing | Savings (ms) | Fraction of 235.6 ms | Fraction of residual 220 ms |
|---|---:|---:|---:|
| min-vs-min       | 0.24 | 0.10% | 0.11% |
| median-vs-median | 0.51 | 0.20% | 0.23% |
| mean-vs-mean     | 0.85 | 0.36% | 0.39% |

### Adjudication

The v1.1.0 disposition table is:

- **VALIDATED**: float parsing is empirically a tiny fraction of
  total cost — wall-clock-savings-ceiling `≪ 220 ms`.
- **REFUTED**: savings ceiling `≥ 100 ms` (float parsing could have
  closed a meaningful chunk of the residual gap).
- **MIXED**: in between.

Observed savings ceiling: **0.24–0.85 ms** (min-pairing to
mean-pairing). That is **250×–900× smaller** than the 220 ms
residual gap and far below the 100 ms REFUTED threshold. Squarely
in the VALIDATED region.

Equivalently: total float-parse cost per canada parse is
**~2.6 ms** (stdlib floor) or **~2.4 ms** (EL floor) — ≈ **1.1%
of the 235.6 ms canada parse**. Even if the float parser were
reduced to zero cost (~the limit of any further float-parse
optimization, including SIMD), the maximum saving would be ~2.6 ms.

The remaining **~233 ms (99%)** of canada parse cost is
structurally not in float parsing. v1.1.0's diagnosis stands:
`RFC_8259.Value` enum allocation × ~333K Values per parse,
tree teardown via outlined-destroy, and intermediate
`[RFC_8259.Value].append` doublings collectively dominate the
canada workload.

### Why the EL landing delivered ~6% and not 30–60%

v1.0.0 projected Patches 1+2+3 collectively closing canada to
30–60 ms (~2–4× Foundation). The microbench shows the structural
bound:

- Patch 3 (EL) ceiling: ~2.6 ms. Observed Patch 3 contribution
  (per v1.1.0's table): ~7 ms (the difference between pre-EL
  246.3 ms and post-EL 239.5 ms). Patch 3's contribution exceeds
  its float-parse ceiling because EL also eliminated `numStr`
  String allocations (~111K × ~20 bytes ≈ 2.2 MB of allocator
  traffic), which contributes secondary savings outside the
  float-parse cost itself.
- Patches 1+2 ceiling: bounded by allocator-traffic reduction
  (eliminating `byteArray` + the redundant copy inside
  `RFC_8259.Number.Original.init`). Observed: ~7 ms collectively
  (per v1.1.0).
- Patches 1+2+3 combined: ~14 ms / 246 ms ≈ 5.7%. Matches v1.1.0's
  observed ~6%.

The 30–60 ms projection was structurally unachievable because
the dominant cost lives in `RFC_8259.Value` tree, not in
`lexNumberValue`'s per-Number construction path. v1.0.0's
projection was internally consistent under its (incorrect)
premise that `Double.init(_: String)` contributed ~111–222 ms;
the microbench shows the actual contribution is ~2.6 ms.

### Implication for the next canada-perf arc

- **Float-parse-targeted optimizations are exhausted.** SIMD float
  parsing, alternative algorithms, etc., cannot meaningfully close
  the 220 ms residual gap (theoretical ceiling: ~2.6 ms).
- **`ASCII.Decimal.Float.Parser` is correctness-positive and
  evergreen** — keep. It eliminates ~2.2 MB of allocator traffic
  per canada parse and delivers a ~30% per-call speedup vs stdlib
  for free; modest but real.
- **Next arc must target tree shape.** Candidates: (a) arena-allocated
  `RFC_8259.Value` storage to amortize per-Value allocation,
  (b) `~Copyable` `RFC_8259.Value` cascade (currently SUPERSEDED-BY-EVIDENCE
  at small N per `value-tree-redesign-v2.md`; may re-open with a
  different shape), (c) event-grain `JSON.Span.EventStream` for
  consumers that don't need the tree (already in progress).
- **Speculative tree-shape arcs MUST gate on this microbench.**
  Any proposal that doesn't move `N × (t_stdlib − t_tree)` past
  the 100 ms threshold is structurally bounded to deliver <0.4%
  improvement.

### Methodology cross-checks

- Per-call microbench measures **only** `ASCII.Decimal.Float.parse`
  + `Double.init(_: String)` in isolation. Production
  `lexNumberValue` does additional work per Number (cursor advance,
  byte accumulation, `RFC_8259.Number.Original` construction, enum
  case alloc). The microbench's per-call number is a **lower
  bound** on production float-parse cost; the production hot path
  is somewhat larger. Even doubling the per-call cost to account
  for surrounding work, the float-parse fraction stays under 3%.
- Bit-pattern agreement across 111 080 real-world float tokens is
  the strongest correctness floor available — covers Clinger fast
  path, Eisel–Lemire core, and the 19-digit boundary; zero
  disagreements means the EL landing has not introduced rounding
  regressions on this workload class.
- `caffeinate -i` + release mode + 16-iter warmup eliminates the
  power-gating + cold-cache + dispatch-fork-up confounds that
  inflate min-of-N when iter counts are small or system load is
  high.

### Hypothesis disposition (final, replaces v1.1.0's)

- **v1.1.0 hypothesis "the residual ~230 ms is `RFC_8259.Value`
  enum allocation + tree teardown + intermediate array doublings":
  CONFIRMED-BY-ELIMINATION.** Direct measurement of the float-parse
  contribution bounds it to ≤ ~2.6 ms (~1%). The remaining ~233 ms
  is structurally not in float code.
- **v1.0.0 hypothesis "Double.init(_: String) IS the dominant
  cost": empirically refuted with margin.** Microbench shows
  Double.init costs ~23 ns/call (~2.6 ms/parse), not the ~111-222 ms
  v1.0.0 framed.
- **EL parser itself is healthy.** EL achieves 1.10×–1.34× stdlib
  speedup with 0 bit-pattern disagreements on 111 080 real tokens.
  Stdlib's `Double(_: String)` is already well-optimized for the
  canada token shape (short literals, mantissa in 19-digit range);
  EL's gains are modest because stdlib was already close to the
  underlying hardware floor. The asymptotic case for EL is
  exotic-shape inputs (long literals, slow-path numerics), which
  canada doesn't exercise.

### Out of scope (preserved from v1.1.0)

- Tree-shape redesigns (arena, ~Copyable cascade, event-grain) —
  separate research arcs.
- Verification on `twitter.json` and `citm_catalog.json` — the
  microbench harness is workload-parametric; future arcs can run
  the same modes on those payloads to cross-validate the per-call
  ratios across workload classes.
- SIMD float parsing — bounded by the same 2.6 ms ceiling on
  canada; not a high-value pursuit absent a different workload.

### Skill references (v1.2.0 additions)

- [BENCH-005] — comparison benchmark methodology preserved
  end-to-end; same harness, same payload, same `caffeinate -i`
  release-mode, MIN-of-N statistics.
- [EXP-011] — workaround-validation trap: the `stats` mode alone
  could not distinguish "EL is slow" from "tree-shape dominates";
  the per-call float-microbench was required to discriminate.
- [HANDOFF-016] (premise staleness) — v1.0.0's
  `Double.init(_: String)` cost premise (~111-222 ms) is now
  refuted with margin; v1.0.0 reading was internally consistent
  under that premise but the premise is empirically false.
- [HANDOFF-047] (writer-side primary-source sampling) — v1.1.0's
  cost-distribution numbers (~3% allocator / ~3% Double / ~94%
  remaining) were arrived at by elimination; v1.2.0 grounds the
  ~3% Double figure in direct measurement.
- [RES-023] — empirical-claim verification: every per-call number
  in this section traces to a `parse-performance-bench` invocation
  recorded in the commit landing alongside.

---

## v1.3.0 — Tree Decomposition (2026-05-20)

Date: 2026-05-20 (same-day follow-on to v1.2.0). Tree-microbench
decomposes the residual ~233 ms canada tree-emit cost into per-Value
allocation, array growth, and tree teardown. **Reframes v1.1.0/v1.2.0's
"tree-shape dominates" claim: tree-emit components account for only
~4% of canada parse cost; ~96% is in something else (most likely the
lex layer).**

### Verdict: SUPERSEDED-BY-EVIDENCE

v1.1.0's hypothesis "the residual ~230 ms is `RFC_8259.Value` enum
allocation + tree teardown + intermediate array doublings"
(CONFIRMED-BY-ELIMINATION in v1.2.0) is now **partially refuted by
direct measurement**: those three components total ~9.73 ms, NOT
~233 ms. The "tree-shape dominates" framing was directionally right
on what *isn't* the bottleneck (float parsing — confirmed at ~1%)
but wrong on *what is*.

### Methodology

Extended `parse-performance-bench` (commit alongside this section)
with a `tree-microbench` mode running three sub-measurements at
16 warmup + N=256 measured iters under `caffeinate -i` +
`swift run -c release`:

- **alloc** — Construct `RFC_8259.Value.number(Number(value, original))`
  in a tight loop using canada's actual Number tokens (harvested via
  the float-microbench's token scanner) at fixed `value = 0.0` to
  factor out float-parse cost. Pure enum-init + `RFC_8259.Number`
  + `RFC_8259.Number.Original` construction cost in isolation.
- **grow** — Allocate fresh `[RFC_8259.Value]` arrays at canada's
  actual size distribution (harvested via a one-time
  `JSON.Decode.parse` walk over the live tree) and time the appends.
  Uses production `reserveCapacity(4)` heuristic at array creation.
- **teardown** — Parse canada once per iter to build the tree (cost
  outside the timing window), then time `tree = .null` reassignment
  which fires the recursive `outlined destroy of RFC_8259.Value`.

Workload counts (live measurement at startup):

- Number tokens: 111 126 (matches v1.0.0's regex-scan count exactly)
- Array nodes: 56 045
- Total appends across all arrays: 167 170
- Mean array size: 2.98 elements

Top size-distribution: 1 element (1 array), 2 elements (55 563
arrays — the canonical `[lon, lat]` coordinate pair), 9–14 elements
(~45 arrays at outer-coordinate-ring sizes).

### Results

| Statistic | ALLOC (ms) | GROW (ms) | TEARDOWN (ms) |
|---|---:|---:|---:|
| min     |  5.418 |  2.911 |  1.403 |
| median  |  5.513 |  2.962 |  1.510 |
| p90     |  5.784 |  3.028 |  1.597 |
| mean    |  5.590 |  2.970 |  1.531 |

Per-operation (min):

- ALLOC: 48.76 ns/Value (~111 126 Values)
- GROW: 17.41 ns/append (~167 170 appends)
- TEARDOWN: not per-op; the recursive destroy walks the full tree.

### Reference parse cost

For comparison (same machine, same conditions, same input):

| Statistic | Full JSON.parse([Byte]) (ms) |
|---|---:|
| min     | 234.199 |
| median  | 236.593 |
| p90     | 243.821 |
| mean    | 241.109 |

### Decomposition

Per-iter MIN (ms):

| Component | Cost | % of parse |
|---|---:|---:|
| alloc    |   5.42 |   2.3% |
| grow     |   2.91 |   1.2% |
| teardown |   1.40 |   0.6% |
| **sum**  |   **9.73** |   **4.2%** |
| **residual** | **224.47** | **95.8%** |
| parse min | 234.20 | (reference) |

The bench's automatic sanity check flagged the missing-component
blind spot: components sum to <50% of parse cost. The remaining
~224 ms must be in components NOT measured by the tree-microbench:

1. **Lexer scanner advancement** — `scanner.consume()` /
   `scanner.peek()` / position tracking / `Text.Location.Tracker`
   updates over 2.15 MB. Even at ~100 ns/byte this alone is
   ~215 ms — plausible dominant cost.
2. **skipWhitespace** — runs between every token; touches every
   whitespace byte.
3. **Token dispatch in `parseValue`** — `scanner.peek() as ASCII.Code`
   + switch over 6 cases per Value node (~333 K Value nodes).
4. **String tokenization** — lex of object keys and string values.
   Canada has ~5 distinct string keys repeated across nodes, plus a
   handful of literal string values; small absolute cost but per-key
   work scales with key count.

ALLOC's per-Value cost (48.76 ns) is *isolated*; in the production
path each Number allocation is preceded by ~18 bytes of scanner
work in `lexNumberValue` (peek + consume per digit/sign char,
position-tracker updates, isFloat flag tracking). The production
ratio between "alloc cost" and "scanner-around-alloc cost" is the
gap this decomposition surfaces.

### Adjudication

The previous Path A / Path B framing was:

- Path A (arena allocation): would close alloc cost.
- Path B (~Copyable Value cascade): would close teardown cost.
- Targeted array-growth fix: would close grow cost.
- Event-grain `JSON.Span.EventStream`: bypasses the tree.

The tree-microbench shows the three tree-emit components total
9.73 ms. Theoretical ceilings:

| Approach | Closes (ms) | % of parse | Worth it? |
|---|---:|---:|---|
| Path A (arena alloc) | ≤ 5.42 | ≤ 2.3% | Marginal at this workload |
| Path B (~Copyable Value) | ≤ 1.40 (teardown) + secondary | ≤ 1–2% | Not justified for canada |
| Array reserve heuristic | ≤ 2.91 | ≤ 1.2% | Trivial |
| **LEX-layer rework** | **≤ 224.47** | **≤ 95.8%** | **Where the cost lives** |
| Event-grain (typed-struct consumers only) | bypasses ≥ 9.73 ms tree work | depends on consumer | Right tool for typed decode; doesn't help bytes→Value consumers |

The next architectural lever for closing the canada anomaly is
**LEX-layer rework**, not arena allocation. Path A's L1 prerequisite
is shipped and remains correctness-positive for other workloads
(notably the string-heavy symbol-graph case, where allocation share
may be larger), but on canada specifically it is structurally bounded
to a small share.

### What "LEX-layer rework" would look like

Investigation candidates for a follow-on arc:

1. **Lazier position tracking.** Per the architecture doc, Tier 4
   already deferred line/column rebuild to error-time. Re-measure
   what's left: byte-offset tracking, scanner.position storage,
   `Text.Position` arithmetic per advance. SWAR (SIMD-within-a-register)
   whitespace skipping is a candidate; `RawSpan` cursor with bulk
   loads is another.
2. **Direct dispatch on the leading byte.** `parseValue`'s
   `peek() as ASCII.Code` lifts UInt8 to ASCII.Code before the
   switch. The lift might be amortizable; profile vs lifting once
   per parse vs lifting per token.
3. **`Lexer.Scanner` overhead audit.** The migration to `Span<Byte>`
   at the Scanner boundary landed in lexer-primitives `34a2f8b`
   (today). Need to confirm the post-migration scanner is at the
   per-byte floor on canada-class workloads. Symbol-graph's 1.02×
   Foundation parity (from `parse-performance.md` v1.2.0) shows the
   scanner is fine on string-heavy workloads. Canada's number-heavy
   workload may stress a different scanner-state path.
4. **`@inlinable` budget audit.** The current parser is heavily
   `@inlinable`; re-verify the inlining actually fires at consumer
   call sites under Swift 6.3.1 (canonical `swift build -c release`).

These are research candidates, not patches. The right next step is a
**lex-microbench** following the same shape as float-microbench and
tree-microbench: decompose the ~224 ms residual into per-byte cost
(scanner-only on canada bytes) + per-token cost (peek + dispatch over
333K Values) + per-Number-tokenization cost (lexNumberValue's
peek-loop overhead beyond what the EL parser itself does).

### Hypothesis disposition (final, replaces v1.2.0's)

- **v1.1.0 hypothesis "the residual ~230 ms is `RFC_8259.Value` enum
  allocation + tree teardown + intermediate array doublings":
  EMPIRICALLY REFUTED.** Direct measurement bounds tree-emit
  components at ~9.73 ms (~4% of parse). The remaining ~95.8% is
  structurally elsewhere — almost certainly the lex layer.
- **v1.0.0 hypothesis "Double.init(_: String) IS the dominant
  cost": refuted (v1.2.0). Stands.**
- **EL parser itself is healthy.** Stands (v1.2.0).
- **NEW: lex layer dominates canada parse cost.** Per-byte scanner
  overhead × 2.15 MB plus per-token dispatch overhead × 333K Values
  most plausibly accounts for the ~224 ms residual. Needs direct
  measurement (lex-microbench) to confirm and decompose further.
- **Path A (arena allocation) is not the right lever for canada.**
  Theoretical ceiling ~2.3% of parse cost. L1 primitive remains
  correctness-positive and may help string-heavy workloads where
  alloc share is larger; on canada specifically the ROI is small.

### Out of scope (preserved from v1.2.0; updated)

- Tree-shape redesigns (arena, ~Copyable cascade, event-grain) —
  separate research arcs. **Note**: deprioritized for canada
  specifically; may revisit for other workload regimes.
- Verification on `twitter.json` and `citm_catalog.json` — the
  microbench harness is workload-parametric; future arcs can run
  the same modes on those payloads to cross-validate the
  decomposition across workload classes.
- SIMD float parsing — bounded by the same ≤2.6 ms ceiling on
  canada; not a high-value pursuit.
- **NEW**: SIMD whitespace skipping — could be material on canada
  if the lex-microbench shows whitespace-traversal dominates. Defer
  to that measurement.

### Skill references (v1.3.0 additions)

- [BENCH-005] — methodology preserved end-to-end across float-microbench
  and tree-microbench.
- [BENCH-011] — wrapper refcount cost model: the ALLOC bench's
  ~48.76 ns/Value figure includes the Copyable enum's runtime
  case-discriminator construction. Production cost likely matches
  within ~2× (production has scanner overhead surrounding each
  alloc; isolated bench has none).
- [HANDOFF-016] (premise staleness) — v1.1.0's "tree-shape
  dominates" premise reframed by v1.3.0 measurement. v1.1.0
  preserved as historical record; v1.3.0 is the current best
  framing.
- [HANDOFF-047] (writer-side primary-source sampling) — every
  per-component number in this section traces to a tree-microbench
  invocation captured in the commit landing alongside.
- [RES-018] — correctness-and-evergreen judgment carries the L1
  byte cascade (swift-byte-primitives' Byte type, Buffer.Arena
  conditional Copyable) regardless of canada-specific ROI.

---

## v1.4.0 — Lex Decomposition + Time Profiler Localization (2026-05-20)

Date: 2026-05-20 (same-day follow-on to v1.3.0). Two complementary
findings on this date:

1. **Lex-microbench** decomposes the residual ~96% of canada parse
   cost that tree-microbench surfaced as not-in-tree-emit. All
   three measured lex-layer components are tiny (~3% combined).
2. **Time Profiler (xctrace)** localizes the residual to **Swift
   runtime generic-metadata machinery + Tagged/typed-index
   infrastructure + ARC traffic** — costs that synthetic
   microbenches do not isolate but Time Profiler captures
   directly from production.

### Verdict: METADATA MACHINERY + ARC DOMINATES

The v1.3.0 hypothesis "lex layer dominates" is empirically **refuted
by lex-microbench** (~3% of parse) and **replaced by Time Profiler
evidence**: the dominant cost is the Swift runtime's generic-protocol
metadata cache + Tagged/typed-index instantiation, not the parser
algorithm or value-tree shape.

### Methodology

Extended `parse-performance-bench` (commit alongside this section)
with `lex-microbench` mode running three sub-measurements against
the production `Lexer.Scanner` API at 16 warmup + N=256 measured
iters under `caffeinate -i` + `swift run -c release`:

- **scanner-walk** — Build `Lexer.Scanner(span)` over canada bytes;
  loop `while !scanner.isAtEnd { scanner.consume() }`. Sum byte
  values to defeat DCE. Pure per-byte advance cost: cursor + position
  tracker + byte read. Captures the canonical low-bound on
  scanner-traversal cost over 2.15 MB.
- **typed-dispatch** — For every byte, do `peek() as ASCII.Code`
  + 6-case switch mirroring `parseValue`'s leading-byte dispatch.
  Per-byte type-up + branch cost. **Upper bound**: production
  fires this once per Value node (~333K times on canada), not
  per byte (2.15M).
- **number-tokenize** — Replay `lexNumberValue`'s peek-and-consume
  loop on each canada Number token (harvested via the same scanner
  pass tree-microbench uses). Per-Number scanner overhead in
  isolation from EL parse and Number construction.

Workload counts:

- Total bytes: 2 251 051 (2.15 MB)
- Number tokens: 111 126 (matches v1.0.0 + v1.3.0 measurements)
- Mean number-token length: 18.25 bytes

### Results

| Component | min (ms) | median (ms) | p90 (ms) | mean (ms) | per-unit (min) |
|---|---:|---:|---:|---:|---:|
| (A) scanner-walk    |  0.893 |  0.901 |  0.930 |  0.908 | 0.40 ns/byte |
| (B) typed-dispatch  |  5.041 |  5.117 |  5.210 |  5.139 | 2.24 ns/byte |
| (C) number-tokenize |  1.581 |  1.615 |  1.649 |  1.618 | 14.23 ns/token |

Reference parse cost (same run, same machine):

| Statistic | Full JSON.parse([Byte]) (ms) |
|---|---:|
| min     | 235.148 |
| median  | 241.137 |
| p90     | 291.019 |
| mean    | 262.429 |

### Decomposition

(A) and (B) both walk every byte — they are **not** additive
(production blends them; canada's lexer reads each byte once for
its purposes). (C) is a separate per-Number axis.

Worst-case attribution (treat A as scanner cost, B as the per-Value
upper bound, C as additional per-Number cost):

| Path | Cost (ms) | % of parse |
|---|---:|---:|
| (A) scanner-walk        |  0.89 | 0.4% |
| (B) typed-dispatch      |  5.04 | 2.1% |
| (C) number-tokenize     |  1.58 | 0.7% |
| **Lex-layer maximum sum** | **~7 ms** | **~3%** |
| Float parse (v1.2.0)    |  2.6  | 1.1% |
| Tree-emit (v1.3.0)      |  9.7  | 4.2% |
| **Total accounted**     | **~19 ms** | **~8.4%** |
| **Residual (unaccounted)** | **~216 ms** | **~91.6%** |

### Where the ~92% lives — Time Profiler evidence

Tooling: `xctrace record --template 'Time Profiler'` against
`parse-performance-bench /path/to/canada.json 32 swift-json-bytes`,
1ms sample rate, release mode, on macOS 26 / arm64. ~8.95 sec
recording, 618 total samples with symbolicated user-callstacks.

Sample-frequency grouping by category (each sample's full
backtrace contributes one count to every named function it
contains — "inclusive time"-like):

| Category | Samples | % of total | % of attributable |
|---|---:|---:|---:|
| **Swift runtime metadata machinery** | 172 | 27.8% | 45.5% |
| **Allocation / ARC traffic** | 85 | 13.8% | 22.5% |
| **User JSON parser code** | 83 | 13.4% | 22.0% |
| **Tagged / typed-index infra** | 38 | 6.1% | 10.0% |
| Process startup / dyld / system | 240 | 38.8% | (excluded from attributable) |
| **Total** | 618 | 100% | 378 (100%) |

**The dominant cost on canada is the Swift runtime's generic-metadata
machinery (~46% of attributable parse time)**, not the parser
algorithm.

Top symbol hits (samples per symbol, sorted):

| Samples | Symbol | Category |
|---:|---|---|
| 26 | `specialized Buffer<>.Linear<>.Small<>.append(_:)` | alloc/ARC |
| 22 | `swift::_getWitnessTable(...)` | metadata |
| 22 | `swift::StableAddressConcurrentReadableHashMap<...>::getOrInsert<...>` | metadata |
| 19 | `swift::TargetContextDescriptor::getGenericContext()` | metadata |
| 18 | `getCache(...)` | metadata |
| 16 | `swift::MetadataCacheKey::operator==` | metadata |
| 16 | `specialized static ASCII.Decimal.Float.parse(_:)` | user |
| 16 | `Storage<>.Inline.deinit` | alloc/ARC |
| 13 | `LockingConcurrentMap<...>::getOrInsert<...>` | metadata |
| 13 | `_swift_getGenericMetadata(...)` | metadata |
| 13 | `_xzm_free` | alloc/ARC |
| 11 | `JSON.Decode.Implementation.parseValue()` | user |
| 10 | `JSON.Decode.Implementation.parseArray()` | user |
| 10 | `JSON.Decode.Implementation.lexNumberValue()` | user |
| 10 | `ConcurrentReadableHashMap<...>::find<...>` | metadata |
| 10 | `specialized Tagged<>.init<A>(fromZero:)` | tagged |
| 10 | `specialized Cursor<>.peek()` | user |
| 9 | `swift_arrayDestroy` | alloc/ARC |
| 9 | `static Tagged<>.retag<A>(_:to:)` | tagged |
| ... | (162 more) | ... |

### Interpretation

1. **Metadata-cache lookups (172 samples / 28% of total)** are the
   #1 hot path. Functions like `_getWitnessTable`,
   `getOrInsert<MetadataCacheKey, ...>`, `getCache`,
   `getGenericContext`, `_swift_getGenericMetadata` are Swift's
   runtime resolving generic-protocol conformances and instantiating
   generic types on the hot path. **Static specialization (compile-
   time monomorphization) is NOT firing for the canada parse's hot
   path** — the runtime is doing the work that should have been
   done at compile time.

2. **Tagged / typed-index infrastructure (38 samples / 6%)**.
   The institute's `Tagged<...>` phantom-typed wrapper fires
   per-byte-cursor-advance: `Tagged.init(fromZero:)`,
   `Tagged.retag(_:to:)`, `Tagged.init(_unchecked:)`,
   `_CarrierProtocol.vector.getter`. Each scanner advance pays
   Tagged construction overhead because Cursor/Text.Position
   types are Tagged-based.

3. **Allocation / ARC traffic (85 samples / 14%)**. Dominated by
   `Buffer<>.Linear<>.Small<>.append` (26 — likely scanner state
   buffering) and `Storage<>.Inline.deinit` (16 — Number.Original.Inline
   destructor firing per Number). `swift_arrayDestroy` (9),
   `swift_allocObject` (6), `swift_release` (4), `RefCounts::doDecrementSlow`
   (3) round out the ARC pressure.

4. **User JSON parser code is ~13% of total samples**. Of that,
   the EL float parser (16 samples), parseValue (11), parseArray
   (10), lexNumberValue (10), Cursor.peek (10), eiselLemire (6),
   Number.Original.Inline.init (5), skipWhitespace (4) account for
   most. Consistent with v1.1.0 + v1.2.0 + v1.3.0 microbench
   findings: user code itself is fast.

### Why this is structural, not algorithmic

The institute's parser is heavily generic:
- `Lexer.Scanner` is parameterized over `Cursor.Protocol` + `Text.Protocol`.
- `Cursor<Text>` is parameterized over `Span<Byte>` + position types.
- `Tagged<...>` propagates through Index, Position, Count types.
- `Byte.Protocol` is a refinement of `Carrier.Protocol<UInt8>`.
- Plus `Parser.Input.Protocol`, `Lexer.Pull.*`, etc.

At call sites, the optimizer would ideally specialize all these
generics into a single monomorphic hot path. The Time Profiler
shows that **specialization is incomplete**: ~46% of attributable
time is spent in the Swift runtime resolving these generic
relationships at runtime. Each `scanner.consume()` traverses
Cursor<Text>.consume → Tagged<...>.retag → CarrierProtocol.vector
getter — and Swift can't fully monomorphize this without
explicit `@_specialize` or `@inlinable` everywhere.

The microbenches did not surface this cost because:
- The bench's tight loops trigger one specialization pattern
  (Span<Byte> + canada bytes) and reuse it across all iterations.
- Once a generic instantiation's metadata cache entry is hot,
  subsequent calls bypass the slow path.
- Production has more diverse callsites (parseValue → parseArray →
  parseObject → parseValue → lexNumberValue → Number.Original →
  ASCII.Decimal.Float.parse) instantiating different `Self` /
  `Element` / `Input` combinations, each firing fresh metadata
  cache traffic.

### Implication for the next canada-perf arc

The Time Profiler localizes the residual to **a compiler/runtime
issue, not an algorithmic one**. The right architectural levers
are very different from what v1.1.0–v1.3.0 framed:

| Approach | Cost | What it closes | Confidence |
|---|---|---|---|
| **Aggressive specialization on the hot path** — `@_specialize(where Input == Span<Byte>, Cursor == Cursor<Text>)` on `Lexer.Scanner`'s methods, `JSON.Decode.Implementation`'s methods, `RFC_8259.Parser`'s methods, and recursively. Goal: force compile-time monomorphization so the runtime metadata cache is never queried during canada parse | Medium (~50–500 LoC of `@_specialize` annotations; iterate by profiling) | Up to ~46% of attributable parse cost (the metadata-machinery category) | High — this is the exact remedy for hot-path generic dispatch overhead |
| **Concrete Span<Byte>-typed inner Scanner** — drop generic constraints on the hot path entirely. Provide `RFC_8259.Span.Scanner` (or similar) that's hard-coded to `Swift.Span<Byte>` + `Int` position + `Byte`-typed peeks. Trade type-system uniformity for runtime monomorphism. Per `parse-performance-architecture.md` v1.0.2 §5, Architecture A's design intent was exactly this — but Architecture A's measured 1.02× parity was on the *string-heavy symbol-graph* workload, not canada. canada exposes a generic-instantiation hot path Architecture A didn't fully close. | High (~1500–2500 LoC of duplicated lexer + parser) | Theoretically ~46% (metadata) + ~6% (Tagged) + part of ARC. Could close 50%+ of canada parse | Medium — depends on whether Cursor<Text>'s Tagged infrastructure can be bypassed without losing correctness guarantees |
| **Tagged hot-path audit** — review every Tagged construction / retag on the parser hot path. Each `Tagged.init(fromZero:)` and `Tagged.retag(_:to:)` is a runtime cost; can any be lifted out of the inner loop or replaced with `Int` arithmetic at the inner-loop level? | Low–medium (audit + selective de-Tagging) | Up to ~10% (the Tagged/typed-index category) | High |
| **Reduce per-Number ARC pressure** — `Storage<>.Inline.deinit` at 16 samples is RFC_8259.Number.Original.Inline running its destructor per Number. Examine whether the Inline storage's deinit is needed at all (the type is mostly trivial UInt8 fields); a `@frozen struct { ... }` with no deinit might avoid the destructor traffic | Low (~20 LoC + audit) | Up to ~3% | High |
| **Event-grain consumption for typed-decode workloads** — `JSON.Span.EventStream` + `JSON.Serializable` per-conformer wedge | Already in progress | Bypasses the tree entirely for consumers that decode into Swift structs; doesn't help bytes→Value consumers | High |
| **Holistic architecture rewrite** — Architecture B or C from `parse-performance-architecture.md`. Likely also needs the specialization fixes above to avoid the same runtime metadata trap | Very high (~3000+ LoC) | Closes canada by replacing the value-tree shape AND avoiding generic dispatch | Low — too many gambles compounded |

**Recommendation**: pursue the **specialization audit** first
(highest-confidence, lowest-cost lever). Specifically:

1. Audit `JSON.Decode.Implementation`, `RFC_8259.Parser`,
   `Lexer.Scanner`, `Cursor<Text>` on the canada hot path.
2. Add `@_specialize` annotations forcing the
   `Span<Byte>` / `Cursor<Text>` / `Byte` instantiations to be
   monomorphized at compile time.
3. Re-run Time Profiler post-specialization. If metadata-machinery
   samples drop substantially, the lever is real.
4. Stop when metadata samples are <5% of total, or when the
   specialization annotations stop reducing the sample count.

After specialization, re-measure canada parse cost. If it drops
from 235 ms toward Foundation's 14 ms range, we're done. If
substantial residual remains, the next lever is the Tagged
hot-path audit followed by the per-Number ARC fix.

If specialization alone closes the gap to <5× Foundation, **the
Copyable-Value-tree architecture is fine for canada**; the
problem was compiler/runtime, not algorithmic.

If specialization closes only a fraction (say, to 100–150 ms),
the residual is genuinely in the value-tree shape and the
Architecture B/C question re-opens — but with a much smaller
residual to attack.

The event-grain path remains the right answer for **typed-decode
consumers** (`JSON.Serializable` conformers materializing into
Swift structs), independent of any canada-parse optimization.

### Hypothesis disposition (final, replaces v1.3.0's)

- **v1.3.0 hypothesis "lex layer dominates": EMPIRICALLY REFUTED.**
  Scanner advance + typed-dispatch + number-tokenize sum to ~3% of
  parse, not the ~96% the residual implied.
- **All prior algorithmic single-component hypotheses are now
  empirically refuted with margin** (float ~1%, tree-emit ~4%,
  lex ~3%, all combined ~8% of parse).
- **NEW: canada parse cost is dominated by Swift runtime metadata
  machinery.** Time Profiler locates the residual at
  `_getWitnessTable`, generic metadata cache lookups, Tagged
  instantiation, and ARC traffic — 34% of total samples / 56% of
  attributable parse time. The cost is **compiler/runtime, not
  algorithmic**.
- **Path A (arena alloc) ROI on canada: ≤ 2.3%** per v1.3.0.
- **Path B (~Copyable Value) ROI on canada: ≤ 1–2%** per v1.3.0.
- **Lex-layer algorithmic rework ROI: ≤ 3%** per this section.
- **NEW Path X (specialization audit) ROI: up to ~46% of attributable
  cost** if generic-protocol metadata-cache traffic can be eliminated
  via `@_specialize` annotations on the hot path.

The ordering of next-arc levers, by expected ROI:

1. **Specialization audit + @_specialize annotations** (≤46% of
   attributable cost; weeks of work)
2. Tagged hot-path audit (≤10%; days)
3. Per-Number ARC fix (≤3%; hours)
4. Path A / Path B / Architecture B/C (≤5% each; weeks-to-months)
5. Event-grain routing for typed-decode consumers (orthogonal to
   canada-parse-the-tree; already in progress)

### Cross-validation candidate

The microbench methodology can be applied to twitter, citm, and
symbol-graph workloads to verify that the residual-cost shape is
canada-specific or universal:

- **Twitter (617 KB, 7821 floats)**: 1.4× Foundation post-Tier-4.
  Probably string-dominated; Value alloc share likely larger fraction
  of total. Architecture A (already-shipped) probably the right
  framing.
- **Symbol-graph (86 MB, predominantly string-heavy)**: 1.02×
  Foundation per `parse-performance.md` v1.2.0. Already at parity;
  no anomaly.
- **CITM (1.65 MB, 14986 floats)**: 4.7× Foundation. Likely a
  middle-ground regime. Decomposition would clarify whether
  canada's "distributed cost" generalizes.

Running the tree-microbench, lex-microbench, and float-microbench
across all three would build the cross-workload picture. Deferred
to a follow-on arc.

### Tooling

- `xctrace record --template 'Time Profiler'` (Xcode 16.0, build
  17F42; macOS 26.2). CLI-driven, scriptable, no GUI required.
- Recording invoked via `xctrace record --template 'Time Profiler'
  --output /tmp/canada-parse.trace --no-prompt --launch -- <bench> <args>`.
- Trace exported via `xctrace export --xpath
  '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]'`.
- Hotspot frequencies computed by grep + sort + uniq + categorizing awk.

The Time Profiler trace is local at `/tmp/canada-parse.trace`; not
committed (Instruments .trace files are large multi-file bundles).
The categorized hotspot summary `/tmp/hotspots.txt` is the
durable derivation; this document captures the analysis.

### v1.4.1 — Supervisor pushback + pre-gate findings (2026-05-20)

Supervisor independent review of v1.4.0 surfaced four substantive
pushback points and required two pre-gates before authorizing
Lever 1 (specialization audit):

1. **"≤46% of attributable" overstates ROI.** Total parse 235 ms;
   27.8% of all samples in metadata machinery ≈ ~65 ms. Closing
   100% of metadata cost brings canada 17× → ~12× Foundation, not
   to parity.
2. **"Algorithm is fast" mis-classifies metadata cost.** Swift
   runtime metadata work IS user code's runtime overhead at the
   abstraction-layer boundary (Tagged.retag, Cursor.peek,
   CarrierProtocol.vector). Framing as "compiler problem" understates
   structural design cost.
3. **NewCodable counter-evidence.** Same Swift compiler; 0.36×
   Foundation. If metadata machinery were universal, NewCodable
   would face it. Speed comes from architectural choices, not
   from compiler immunity. The cost is institute-primitives-specific.
4. **618-sample basis is noisy** for a class-(c) architectural
   conclusion. 27.8% metadata rests on 172 samples.

Pre-gates authorized:

#### Pre-Gate 1: SIL spot-check (binary symbol inspection at -O)

Inspected `parse-performance-bench` release binary symbols
(65,356 demangled symbols). Counted specialized vs generic-only
instances for hot-path functions:

| Function | Specialized? | Implication |
|---|---|---|
| `Cursor.consume() -> Byte` | ✅ YES (`<serialized, Text>`) | Hot path inlined; supervisor's 2026-05-14 audit reaffirmed |
| `ASCII.Decimal.Float.parse(Span<Byte>)` | ✅ YES | EL parser monomorphized |
| `Cursor.peek() -> Byte?` | ❌ NO | Generic dispatch every call |
| `Lexer.Scanner.peek<X: Byte.Protocol>() -> X?` | ❌ NO | Witness table + closure forwarding |
| `Tagged.retag<A>(_:to:) -> Tagged<A1, B>` | ❌ NO | Generic dispatch on every retag |
| `_CarrierProtocol.vector` (witness) | ❌ NO | Per-call witness lookup |

**The supervisor's instinct was partially right and partially refuted.**
`Cursor.consume()` IS specialized (so the supervisor's previous-audit
finding stands), but `Cursor.peek()`, `Tagged.retag<A>`, the typed
`peek<X>()`, and `_CarrierProtocol.vector` witness are NOT. Each
unspecialized site fires runtime metadata-cache lookups per call.

This refutes my v1.4.0's broad "specialization audit" framing AND
the supervisor's strict "@_specialize is the wrong tool" pushback.
The right framing: **targeted @_specialize on the specific functions
the SIL spot-check identified as unspecialized**, not a blanket
audit, not abandoning the lever.

#### Pre-Gate 2: Cross-workload Time Profiler (twitter vs canada)

Ran Time Profiler on twitter.json (617 KB, ~7821 floats, mostly
strings, 256 iters, 5.6s total recording, 556 samples). Compared
to canada (2.15 MB, 111K floats, 32 iters, 8.95s recording, 618
samples). citm_catalog.json not available on disk locally.

Cross-workload category shares (% of attributable):

| Category | Twitter | Canada | Delta |
|---|---:|---:|---|
| **Metadata machinery** | 33.4% | 45.5% | +12.1 pp |
| Allocation / ARC | 30.3% | 22.5% | -7.8 pp |
| User JSON code | 28.6% | 22.0% | -6.6 pp |
| Tagged / typed-index | 7.7% | 10.1% | +2.4 pp |

Value-count ratio canada:twitter ≈ 50:1. Metadata%-ratio ≈ 1.6:1.

**Metadata cost scales SUBLINEARLY with Value count** — neither
of the supervisor's clean hypotheses is cleanly supported:

- **Pure specialization-issue diagnosis** would predict roughly
  CONSTANT metadata% across workloads. Observed: 33.4% (twitter)
  vs 45.5% (canada). NOT constant. **Refuted.**
- **Pure tree-shape diagnosis** would predict metadata% scales
  with per-Value volume. 50× Values → expected ~50× metadata%.
  Observed: 1.6× metadata%. Strongly **sublinear**.

**Composite diagnosis:** there's a workload-independent baseline
(~17–20% of total samples in metadata machinery) PLUS an additional
~7–10 pp on top that scales modestly with per-Value allocation
volume. Both interventions are warranted but the relative weights
differ from v1.4.0's framing.

#### Refined recommendation (replaces v1.4.0 Lever 1 framing)

| Lever | Target | Cost | Realistic ROI on canada | ROI on twitter |
|---|---|---|---:|---:|
| **1a. Targeted `@_specialize`** on `Tagged.retag<A>(_:to:)`, `Cursor.peek()`, `Lexer.Scanner.peek<X: Byte.Protocol>()`, `_CarrierProtocol.vector` witness — specifically for the canada hot-path instantiations (Text, Byte, Cardinal, Ordinal, ASCII.Code) | L1/L2 work on lexer-primitives / cursor-primitives / tagged-primitives | Medium (~100–300 LoC of @_specialize annotations) | ~17-23% of total samples → reduces canada from 17× → ~13× Foundation | ~17% of total samples → reduces twitter from 1.4× → ~1.2× Foundation |
| **1b. Tagged hot-path audit** — lift `Tagged.init(fromZero:)` and `Tagged.retag(_:to:)` out of inner loops where possible | swift-json + lexer-primitives | Low (audit + selective de-Tagging) | ≤ 10% (Tagged samples) | ≤ 8% |
| 2. Path A (Buffer.Arena tree storage) | swift-json + swift-rfc-8259 | High | ≤ 2.3% on canada | ≤ 5% on twitter (alloc share higher) |
| 3. Path B (~Copyable RFC_8259.Value cascade) | ~4000 LoC across 3 packages | Very high | ≤ 1–2% on canada | ≤ 2% on twitter |
| 4. Architecture B (arena tree + materialize) | ~3000 LoC | Very high | Theoretically ~50%+ on canada | ~10% on twitter |
| 5. Event-grain consumption | Already in progress | Bypasses tree | Orthogonal | Orthogonal |

**Class-(c) ecosystem flag (reinforced):** Lever 1a touches
**lexer-primitives + cursor-primitives + tagged-primitives** — these
are L1 packages used by every parser in the ecosystem (JSON, XML,
plist, CBOR, …). Specialization improvements there benefit every
tree-emitting parser, not just swift-json. This is the most
load-bearing finding in this investigation; v1.4.0 understated it.

#### Honest framing of the gap to Foundation

Canada 17× Foundation = ~221 ms residual to close.

| Lever | Closes | Remaining |
|---|---:|---:|
| 1a + 1b targeted specialization | ~50–65 ms | ~155–170 ms (10–12× Foundation) |
| + Tagged audit residual | ~10–15 ms | ~140–155 ms (10–11× Foundation) |
| + Path A/B + array reserve | ~10 ms | ~130–145 ms (~10× Foundation) |
| Architecture B (replaces above) | ~100–150 ms | ~70–120 ms (5–9× Foundation) |
| Event-grain (replaces tree entirely for typed-decode consumers) | bypasses tree | Foundation-class |

**Foundation parity (1.0×) is NOT a realistic outcome of any
single lever.** Lever 1a delivers a meaningful improvement
(~10–17× → ~10–13× on canada; ~1.4× → ~1.2× on twitter) at
moderate cost. The bigger question — Architecture B vs accepting
canada-class workloads route via event-grain — remains a separate
strategic decision.

#### What the supervisor's review got exactly right

- Confidence in v1.4.0 was overclaimed
- "Algorithm is fast" was misleading framing
- 618-sample basis was noisy
- Cross-workload validation as PRECONDITION (not Open Question) was the correct discipline
- Class-(c) ecosystem framing was understated
- SIL verification first was the right gate

#### What v1.4.0 + pre-gates surfaced beyond the supervisor's framing

- Specialization status is MIXED, not all-or-nothing (`Cursor.consume` ✓; `Cursor.peek` ✗; `Tagged.retag` ✗)
- The metadata cost has IDENTIFIABLE generic-dispatch source (specific functions, not amorphous)
- Twitter shares meaningful metadata cost (33.4% of attributable) — this is ecosystem-wide
- The right target packages are lexer-primitives + cursor-primitives + tagged-primitives, not swift-json alone

### Skill references (v1.4.0 additions)

- [BENCH-005] — methodology preserved end-to-end across the four
  microbench modes shipping this session.
- [BENCH-011] — wrapper refcount cost model partially validated: the
  Storage<>.Inline.deinit hot path (16 samples) and Buffer<>.Linear<>.Small<>.append
  (26 samples) confirm ARC traffic is real but smaller than the
  metadata-machinery cost. The "integration cost" hypothesis is
  refined: the integration cost lives in runtime metadata caches,
  not (only) in ARC retain/release.
- [HANDOFF-016] (premise staleness) — every prior framing in
  v1.0.0–v1.3.0 is reframed by Time Profiler evidence. Each
  version preserved as historical record; v1.4.0 is current best
  framing because it's grounded in production-shaped data
  (Time Profiler) rather than synthetic-shape microbenches.
- [RES-018] correctness-and-evergreen carries the byte cascade +
  Buffer.Arena conditional-Copyable work regardless of canada ROI.
- [EXP-011] — workaround-validation trap: synthetic microbenches
  validated component-level cost models but missed the integration
  cost (runtime metadata machinery). Time Profiler captured it
  because it samples actual production-shape callstacks. Reinforces
  the rule that synthetic microbenches must be paired with
  end-to-end production-shape measurement.

## Provenance

Investigation invoked via /research-process on the
`codec-throughput-vs-newcodable` empirical anomaly
(`swift-foundations/swift-json/Experiments/codec-throughput-vs-newcodable/RESULTS.md`,
2026-05-19). Scope: identify the per-Number cost path, size against
canada's workload, recommend patches. No code changes attempted by
this investigation; recommendations queue for a separate
implementation arc.

Verification at write time per [RES-023]:
- Workload counts via Python regex scan of canada.json
  ([Verified: 2026-05-19]).
- File:line citations grep'd against live source ([Verified: 2026-05-19])
  — note: the historical `RFC_8259.Lexer.swift` cited in
  `parse-performance.md` and `parse-performance-architecture.md`
  references no longer exists; the live hot path is in
  `JSON.Decode.Implementation.swift` per Arc 1.6 namespace
  correction + Ticket T-1. This is a benign documentation lag in
  the predecessor docs, not an error here.
- Ecosystem fast-Double parser absence ([Verified: 2026-05-19]) —
  `swift-ascii-parser-primitives` ships `ASCII.Decimal.Parser` for
  integers; no float counterpart surfaced in any prior research doc
  in `swift-json/Research/` or workspace-wide grep.

### v1.2.0 addendum (2026-05-20)

Per-call microbench session invoked via
`/Users/coen/Developer/HANDOFF-el-parser-microbench-validation.md`
(focused investigation brief). Scope: validate or supersede v1.1.0's
tree-shape claim via empirical per-call measurement of
`ASCII.Decimal.Float.parse` vs `Double(_: String)` on the canada
workload's actual float tokens.

Bench-harness extension: `parse-performance-bench` gained `stats`
and `float-microbench` CLI modes plus `swift-ascii-parser-primitives`
as an explicit dependency. Both modes run under `caffeinate -i` +
`swift run -c release` per [BENCH-005] / Apple's NewCodable
methodology.

No production `Sources/JSON/` edits this session — scope was
read-only on the live parser surface. Verdict (VALIDATED) updates
the v1.1.0 RECOMMENDATION status to v1.2.0 VALIDATED and bumps the
`Research/_index.json` entry.

### v1.3.0 addendum (2026-05-20, same-day follow-on)

Tree-microbench mode added to `parse-performance-bench` decomposes
the canada tree-emit cost into three components: per-`RFC_8259.Value`
allocation, intermediate array growth, and recursive tree teardown.
Companion to `float-microbench`; same MIN-of-N + warmup methodology.

W2 byte-cascade migration of swift-json + swift-rfc-8259 +
`ASCII.Decimal.Float.Parser` landed concurrently:
public-API surfaces (`JSON.parse`, `JSON.Decode.parse`,
`JSON.Span.EventStream`, `JSON.Coder.Input`, `JSON.Serializable.from(...)`,
`RFC_8259.Number.Original`, `ASCII.Decimal.Float.parse`) now accept
`Byte` / `Span<Byte>` / `Collection<Byte>` natively rather than
`UInt8` / `Span<UInt8>` / `Collection<UInt8>`. Internal storage
fields are likewise `Byte`-typed. Removes the `.underlying` ceremony
at every callsite within the parser; only legitimate uses remain
(stdlib boundaries where `String.init(unsafeUninitializedCapacity:)`
or `String(decoding:as:)` require UInt8).

Path A's L1 prerequisite (`Buffer.Arena: Copyable where Element: Copyable`,
`Tree.N: Copyable where Element: Copyable`) is also confirmed
implemented in production (per parallel sub-agent finding 2026-05-20;
`swift-institute/Research/buffer-arena-conditional-copyable.md` v1.2.0
IMPLEMENTED). The L1 primitive prerequisite for arena-backed tree
storage is satisfied.

The decomposition outcome reframes the next-arc priority — see
"v1.3.0 — Tree Decomposition" section.
