# Parse Performance

<!--
---
version: 1.3.0
last_updated: 2026-05-14
status: DECISION
tier: 1
---
-->

> **v1.3.0 (2026-05-14)**: Streaming-deserialize placement landing
> (`swift-institute/Audits/streaming-deserialize-placement-audit.md`,
> commit `e8a06b7`) brought T-1 (rebase `RFC_8259.Span` cursor onto
> `Lexer.Scanner` — swift-rfc-8259 `b4ec277`) and T-2 (re-home
> `JSON.Assemble` to `RFC_8259.Span.Assemble` — swift-rfc-8259
> `90cba4c` + swift-json `0960da6`). The standing [BENCH-011] probe
> at `codable-lookup-event-grain` mode flagged a +25% event-grain
> regression on the same 86 MB workload: pre-T-1 0.082 s -> post-T-1
> 0.101 s (median 8 runs, σ ≈ 1 ms).
>
> Profile investigation
> (`swift-institute/Audits/streaming-deserialize-regression-profile.md`,
> commit `de3e3c8`) refuted the cross-module inlining hypothesis and
> identified `Text.Location.Tracker` integration as the dominant cost
> centre at two fire points: ~3.8 M `tracker.newline(at:)` calls per
> parse in `skipWhitespace` (4.2 %-newline workload), and ~90 K
> `let startLocation = lexer.scanner.location` token-start captures.
> The audit's [INFRA-003] zero-cost defence was structurally correct
> at the substrate level (typed primitives compile to identical
> assembly) but the migration relocated position work from the error
> path (rare) to the hot path (per-byte / per-token) — an
> integration-shape failure rather than a substrate failure.
>
> Remediation landed in two surgical changes:
>
> - **Option A** — defer `startLocation` capture to error-throw
>   sites. Adds `Lexer.Scanner.location(at: Text.Position)` to
>   swift-lexer-primitives (`3fbf66f`) for on-demand resolution; the
>   Span parser captures only the cheap `Text.Position` cursor on
>   the hot path and routes throws through a new `position(at:)`
>   helper. Closes ~2 ms of the 19 ms wedge (~11 %).
> - **Option B** — elide per-newline tracker updates in
>   `skipWhitespace`. JSON tokens cannot contain raw 0x0A / 0x0D
>   (RFC 8259 §7), so the parser can skip Tracker maintenance
>   entirely and pay an O(N) source scan at error-throw sites via
>   `Lexer.Scanner.location(at:)` (made scan-based to keep the L1
>   surface non-compound per [API-NAME-002]). Lands together with
>   A on swift-rfc-8259 (`94c1616`). Closes an additional ~5 ms
>   (~26 % of the wedge), bringing the median to **0.094 s**.
>
> **Outcome**: ~37 % of the wedge closed; ~12 ms residual above
> pre-T-1 baseline. Event-grain absolute position unchanged in
> spirit — 2.37× Foundation, 3.78× swift-json status-quo on the
> canonical workload. 216 swift-rfc-8259 tests pass; symbol-count
> parity (14 552) preserved across all three paths.
>
> **Follow-up surfaced**: the residual ~12 ms is not predicted by
> either fire point identified in the profile. Cause not yet
> isolated. Open as a separate investigation when prioritised.
>
> **Institute-wide consequence**: [INFRA-003] zero-cost expectation
> needs a substrate-vs-integration-shape distinction. Migration arcs
> that relocate work from cold to hot paths MUST measure at the hot
> path, not at the substrate. Skill-lifecycle amendment queued.
>
> **Update (same day, 2026-05-14)**: residual closed. The follow-up
> investigation at `swift-institute/Audits/streaming-deserialize-
> residual-investigation.md` identified the ~12 ms residual as a
> switch-shape carryover in `skipWhitespace` — the two-arm + CRLF-
> special-case structure was vestigial under Option B (no tracker
> maintenance) and produced different optimized code than pre-T-1's
> single-arm switch. The fix at swift-rfc-8259 `8a92f3a` replaces
> the two-arm structure with a single-arm switch over all four
> whitespace bytes. Final gate (median 8 runs): **0.080 s** — below
> pre-T-1 baseline (0.082 s), event-grain is now **2.62× faster than
> Foundation** and **4.11× faster than swift-json's status-quo path**
> on the canonical workload. Lesson for the integration-shape skill
> amendment: sample-frame tick attribution does not resolve fine-
> grained code-shape costs (register allocation, branch prediction);
> wall-clock at the integration entry point is the load-bearing
> evidence.
>
> **v1.2.1 (2026-05-14)**: Honest-framing amendment after a
> first-reader challenge to the v1.2.0 Foundation-comparison framing.
> The "14× faster than Foundation on lookup" claim was specific to
> the dynamic-access path (`JSONSerialization` → `as? [String: Any]`
> casts vs swift-json's typed dynamic-member-lookup). A new
> `codable-lookup` mode in `Experiments/parse-performance-bench`
> measured the schema-known path (Foundation's `JSONDecoder` + Codable
> vs swift-json's `JSON.Serializable` extension). On the same 86 MB
> workload, with a `Symbol` struct declaring `kind.identifier +
> identifier.precise + pathComponents`:
>
> | Use case | Foundation | swift-json | Outcome |
> |----------|-----------|------------|---------|
> | Dynamic / schema-less (the v1.2.0 measurement) | `JSONSerialization` 0.30 s parse + 46 ms/iter lookup | `JSON.parse` 0.30 s + 3.16 ms/iter | swift-json **14× faster on lookup** |
> | Schema-known (Codable) | `JSONDecoder().decode(T.self, …)` **0.220 s** parse+decode + 1.6 ms/iter | `T(jsonBytes: …)` **0.349 s** + 1.72 ms/iter | Foundation **37% faster on parse+decode**; ≈ equal on lookup |
>
> Root cause of the Codable gap: `JSONDecoder` parses selectively
> (only fields the `Decodable` declares). swift-json's
> `JSON.Serializable.init(jsonBytes:)` parses the **full** JSON tree
> via `JSON.parse(...)` first, then extracts the declared fields —
> strictly more work for partial-shape decodes.
>
> Honest blanket framing: **swift-json wins on dynamic-access
> workloads; Foundation wins on schema-known partial-shape decodes;
> they're equivalent on native-struct lookup once data is decoded**.
> No code change; no roll-back. The v1.2.0 DECISION stands for the
> parse-side parity work; the Codable gap is a documented structural
> property of the current architecture, not a regression.
>
> **v1.2.0 (2026-05-13)**: **Tier 4 LANDED. Foundation parity
> achieved.** Release-mode 86 MB parse: 0.67 s → 0.304 s on the
> `[UInt8]` path (1.02× Foundation) and 0.316 s on the `String` path
> (1.06× Foundation). Implementation lives at
> `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.{Lexer,Parser}.Span*.swift`;
> the public API surface is unchanged; the generic
> `RFC_8259.Parser<Input>` slow path is preserved for non-contiguous
> inputs. Full A1 measured outcomes + design refinements recorded
> at `parse-performance-architecture.md` v1.0.2 §9. Status upgraded
> RECOMMENDATION → DECISION. Tiers 2 (ASCII.Decimal.Parser) and 5
> (Input.Borrowed) remain HELD; no further work planned absent a
> second hot consumer surfacing.
>
> **v1.1.0 (2026-05-13)**: Tiers 0, 1, 3 landed. Release-mode 86 MB
> parse: 0.96 s → 0.70 s (String path), 0.91 s → 0.67 s (`[UInt8]`
> path). Profile after the change confirms `skipWhitespace`,
> `Input.Buffer.advance`, and `lexString` hotspots collapsed as
> predicted. Foundation gap closed from 3.05× to 2.33×. See "§6
> Measured outcomes after Tiers 0/1/3" appended below. Tiers 2/4/5
> remain RECOMMENDATION (Tier 4 specifically queued behind a
> demonstrated second hot consumer).

## Context

The `symbol-graph-conformance-oracle` experiment under
`swift-foundations/swift-json/Experiments/` reported a 129 s parse of the
86 MB pretty-printed Swift stdlib symbol graph emitted by
`swift symbolgraph-extract`. Wall-clock breakdown from
`Experiments/symbol-graph-conformance-oracle/Outputs/run-stdlib.txt`:

```
=== Timing ===
Read:       0.062s
Parse:      129.210s
Reduce:     0.071s
Total:      129.343s
```

The reducer walks the parsed tree in 0.07 s; the parse appeared to be
≈99.95 % of total time. swift-json is broadly imported across the
ecosystem, and the regen workflow runs once per toolchain bump, so
"faster parse" was framed as a path to (a) more frequent regeneration
and (b) better ad-hoc usability.

The package is older than several ecosystem improvements
(`Span<T>` / `RawSpan`, the `~Escapable`-on-associated-types
confirmation in
`swift-parser-primitives/Experiments/suppressed-escapable-associated-types/`,
`swift-ascii-parser-primitives`, `swift-binary-parser-primitives`). The
investigation surveyed which of these apply and what's achievable.

## Question

How much of the 129 s parse is intrinsic to swift-json's parser shape,
and what changes — by cost and structural depth — would reduce it?

## Analysis

### 1. Premise audit ([HANDOFF-016] premise-staleness, [RES-028] smallest-isolation-first)

The 129 s observation came from `swift run symbol-graph-conformance-oracle`
without `-c release`. The matching log line:

> `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/Outputs/run-stdlib.txt:4`
> ```
> Building for debugging...
> ```

The regen script invokes the experiment in default (debug) mode at
`swift-foundations/swift-linter-rules/Scripts/regenerate-stdlib-refinements.sh:71`:

```bash
swift run symbol-graph-conformance-oracle Outputs/swift-stdlib/Swift.symbols.json
```

Re-running the same experiment under `-c release` on the same input
file, same host:

```
=== Timing ===
Total wall-clock:  0.971s
  Swift                                        0.952s (parse)
```

The 129 s → 0.95 s ratio is **~135×**. The parser is generic over the
~Copyable `Parser_Primitives.Parser.Input.Protocol` chain with typed
`Position` / `Cardinal` arithmetic at every byte; without inlining and
generic specialization, every per-byte cursor advance traverses a chain
of protocol-witness dispatches. Release-mode specialization collapses
that chain, producing a 100×+ speed gap that is consistent with what
heavily-generic Swift parsers exhibit under `-Onone`. The 129 s figure
is **build-config-conditioned**, not parser-intrinsic.

This was caught by a one-iteration release-mode benchmark in
`/tmp/json-parse-bench` (Package.swift depending on swift-json by
path); the experiment was then rebuilt with `swift build -c release`
and the timing reproduced inside the experiment itself.

### 2. Standalone benchmark (release, single iteration)

`/tmp/json-parse-bench`, executable depending on `JSON` by path,
single iteration, 86 MB `Swift.symbols.json` on macOS 26 / arm64:

```
input size: 90,251,496 bytes (86.07 MB)

[FLOOR]   byte-iterate Data                           0.243s
[FLOOR]   byte-iterate [UInt8]                        0.006s
Foundation.JSONSerialization.jsonObject(with:)        0.297s
swift-json JSON.parse(String)                         0.959s
swift-json JSON.parse([UInt8])                        0.907s
```

Three iterations confirmed linear scaling (2.86 s / 2.89 s / 0.91 s
respectively). Translating to throughput on this input:

| Path                                  | Wall-clock | Throughput  | Ratio vs Foundation |
|---------------------------------------|-----------:|------------:|--------------------:|
| `[UInt8]` iterate (memory-bandwidth floor) | 0.006 s | 14,345 MB/s | —                   |
| `Data` iterate (boxed-Sequence floor) | 0.243 s    |    354 MB/s | —                   |
| Foundation.JSONSerialization          | 0.297 s    |    290 MB/s | 1.0×                |
| swift-json `JSON.parse([UInt8])`      | 0.907 s    |     95 MB/s | 3.05× slower        |
| swift-json `JSON.parse(String)`       | 0.959 s    |     90 MB/s | 3.23× slower        |

The Data-iteration floor (0.24 s) is roughly Foundation's wall-clock —
Foundation's parser is bound by the memory it has to touch, while
swift-json spends an additional ~0.6 s on per-byte cursor work, string
construction, and value-tree allocation beyond touching the input.

### 3. Profile attribution (`sample`, 10-iteration release run)

`sample <pid> 6 1` against `swift-json JSON.parse([UInt8])` (10 × 86 MB):

Distinct named hotspots, ordered approximately by inclusive cost (the
sample tool counts per-frame ticks; tallies are approximate):

| Cost center                                          | Ticks | Description |
|------------------------------------------------------|------:|-------------|
| `RFC_8259.Lexer.skipWhitespace` (all sites)          | ~310  | Per-byte peek+advance loop over whitespace; pretty-printed input is ≈30–40% whitespace |
| `RFC_8259.Lexer.next` (all sites)                    | ~220  | Token dispatch + peek per byte |
| `Input.Buffer.advance()`                             | ~150  | Position increment + bounds check (called from peek+advance everywhere) |
| `RFC_8259.Lexer.lexString` (all sites)               | ~200  | Per-string `var result: [UInt8] = []` + `result.append(byte)` per char |
| `Array.append<A>(contentsOf:)`                        | ~125  | `String` and `Object._storage` array growth |
| `_ArrayBuffer._consumeAndCreateNew`                   | ~100  | Array reallocation as `_storage` grows |
| `swift_release` / `swift_allocObject` / `slowAlloc`   | ~250  | ARC traffic from per-value allocation |
| `outlined destroy of RFC_8259.Value`                  | ~242  | Per-iteration tree teardown (recursive Object/Array deinit) |
| `String._fromUTF8Repairing` / `_allASCII`             | ~70   | `String(decoding: …, as: UTF8.self)` per JSON string |

The hot patterns the profile localizes:

**(a) The peek pattern is needlessly expensive.** `RFC_8259.Lexer.peek`
(`swift-rfc-8259/Sources/RFC 8259/RFC_8259.Lexer.swift:62-70`) is:

```swift
internal var peek: UInt8? {
    mutating get {
        guard !input.isEmpty else { return nil }
        let cp = input.checkpoint
        let byte = try! input.advance()
        input.setPosition(to: cp)
        return byte
    }
}
```

Every byte goes through: bounds check, save checkpoint, advance
(typed-Position store + Cardinal arithmetic + saturating addition,
line/column update), restore checkpoint (typed-Position store). Then
the lexer's own `advance` (`RFC_8259.Lexer.swift:73-90`) does
*another* full typed-Position update. For 86 MB that's hundreds of
millions of position-stores.

`Input.Buffer` already exposes `first: Element?` (a `_read` accessor
yielding the byte without mutating position — see
`swift-input-primitives/Sources/Input Primitives/Input.Buffer+Input.Protocol.swift:40-49`).
Switching `RFC_8259.Lexer.peek` to `input.first` removes the
checkpoint/restore round-trip entirely.

**(b) `skipWhitespace` peeks twice per whitespace byte.** Each iteration
calls `peek` (three position-ops) then `advance` (one position-op).
A specialized fast-path that reads consecutive whitespace via a tight
`while position < count && isWhitespace(storage[position])` loop on
the underlying buffer (or `Span<UInt8>`) collapses to one bounds check
+ one load per whitespace byte. For pretty-printed JSON this is a
material wedge (whitespace is a meaningful fraction of bytes).

**(c) `lexString` allocates per JSON string.**
`RFC_8259.Lexer.swift:229`:

```swift
var result: [UInt8] = []
```

Then `result.append(byte)` per char and finally
`String(decoding: result, as: UTF8.self)`. The 86 MB symbol graph
contains millions of small JSON strings (every identifier, doc
comment, kind name); each string allocates a fresh growing buffer plus
the final `String`. A per-Lexer reusable scratch buffer cleared with
`removeAll(keepingCapacity: true)` between strings eliminates the
allocation churn for the buffer half. For ASCII-only strings (the
overwhelming majority in symbol graphs), the `String(decoding:)` path
goes through `_fromUTF8Repairing` / `_allASCII` and could short-circuit
through `String(unsafeUninitializedCapacity:)` over the byte range
directly — saving the per-string heap allocation entirely when no
escapes appeared.

**(d) `lexNumber` does two byte-copies + a String.**
`RFC_8259.Lexer.swift:426-437`:

```swift
let byteArray: [UInt8] = {
    let span = bytes.span
    var arr: [UInt8] = []
    arr.reserveCapacity(span.count)
    for i in 0..<span.count { arr.append(span[i]) }
    return arr
}()
let original = RFC_8259.Number.Original(byteArray)
let numStr = String(decoding: byteArray, as: UTF8.self)

if isFloat {
    guard let value = Double(numStr), value.isFinite else { … }
} else {
    if let value = Int64(numStr) { … }
    else if let value = UInt64(numStr) { … }
    else if let value = Double(numStr), value.isFinite { … }
}
```

The manual span→`[UInt8]` copy is unnecessary —
`RFC_8259.Number.Original(_:)`
(`RFC_8259.Number.Original.swift:24-31`) accepts any
`Swift.Collection` with `Element == UInt8`, so the
`Array.Small<24>.span` could be passed directly (or via a single
`[UInt8](unsafeUninitializedCapacity:initializingWith:)` initialiser
that copies once).

The `String(decoding:)` → `Int64(numStr)` / `UInt64(numStr)` /
`Double(numStr)` path is also costly: each goes through Swift's
character-by-character `LosslessStringConvertible` parser. swift-primitives
ships `ASCII.Decimal.Parser<Input, T: FixedWidthInteger>`
(`swift-ascii-parser-primitives/Sources/ASCII Decimal Parser Primitives/ASCII.Decimal.Parser.swift:27-57`)
which parses ASCII bytes directly into integers without the String
round-trip and with overflow-aware multiplication. Adopting it for
the integer case eliminates one allocation + one parse pass per
number. Doubles are harder (Swift's `Double.init(_: String)` is the
shortest path until an Eisel-Lemire-class fast-path lands in stdlib or
swift-primitives), but only the float branch needs the String form.

The `RFC_8259.Number.Original` String accessor is computed lazily
(`RFC_8259.Number.Original.swift:44-46`), so deferring construction
costs nothing on the read side — the bytes are sufficient.

### 4. Upstream improvements available NOW

Surveyed against swift-json's current Package.swift dependency pins:

| Improvement                                                                                                 | Status                                                                                                                                 | Applicability to swift-json                                                                                                                                                                                |
|-------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Span<T>` / `RawSpan` for zero-copy parsing                                                                 | Available in Swift 6.x stdlib; used by `swift-binary-parser-primitives` (`Binary.Bytes.Input.View` wraps `Span<UInt8>`)                  | Not directly droppable into `RFC_8259.Lexer`'s generic `Parser.Input.Protocol` chain — Input.Protocol's associated types are not `~Escapable` yet. A Span-specialized internal lexer is the cheapest path. |
| `~Escapable` on protocol associated types                                                                   | CONFIRMED working in Swift 6.2.3+ per `swift-parser-primitives/Experiments/suppressed-escapable-associated-types/Sources/main.swift`    | The blocker for `Input.Borrowed`. `Input.swift:55-63` documents that an `Input.Borrowed` (analogous to `Binary.Bytes.Input.View`) is "planned but deferred" — the experiment has cleared the language gap. |
| `Input.Borrowed` / `Input.Span` over `Span<UInt8>`                                                          | Not yet present in `swift-input-primitives`                                                                                            | When it lands, swift-rfc-8259 can switch from `Input.Buffer<ContiguousArray<UInt8>>` to the borrowed view; eliminates the input-materialisation copy and the typed-Position arithmetic on the hot path.    |
| `swift-ascii-parser-primitives` (`ASCII.Decimal.Parser`, `ASCII.Hexadecimal.Parser`)                        | Available; not currently a swift-rfc-8259 dep                                                                                          | Replaces String-route integer parsing in `lexNumber`; would also replace the bespoke hex loop in `lexUnicodeEscape` (`RFC_8259.Lexer.swift:280-352`).                                                       |
| `swift-binary-parser-primitives` `Binary.Bytes.Input.View` (Span-backed cursor)                             | Available; binary-focused                                                                                                              | Proof-of-concept for the Span-cursor pattern. A text-side analogue can be modeled on it.                                                                                                                   |
| `swift-utf-8-primitives`                                                                                    | Not present in this workspace (no such package)                                                                                        | N/A as of 2026-05-13.                                                                                                                                                                                      |

### 5. The 3.05× gap to Foundation

After release-mode building, swift-json takes 0.96 s on the file where
`JSONSerialization` takes 0.30 s. The gap is structural rather than
algorithmic — both implementations are recursive-descent over UTF-8
bytes. The differences:

| Axis                | Foundation (CF-backed)                           | swift-json                                                                                                                                       |
|---------------------|--------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| Cursor              | Direct pointer arithmetic over the input bytes   | Generic `Parser.Input.Protocol` chain with typed `Position` + `Cardinal` arithmetic, monotonic line/column tracking on every byte                |
| Input form          | Raw bytes, no copy                               | `Swift.Array(bytes)` materialises a ContiguousArray; `Input.Buffer` wraps that array (one full input-size copy at entry)                          |
| Per-string buffer   | Reused scratch storage                           | Fresh `var result: [UInt8] = []` per JSON string, plus a `String(decoding: …, as: UTF8.self)` over the bytes                                     |
| Per-number          | Inline ASCII digit accumulation; lazy String     | Two byte-copies + a String + `Int64/UInt64/Double` parsing from String + `RFC_8259.Number.Original` allocation                                   |
| Per-object          | Hash-table member storage                        | `[(key: String, value: Value)]` linear array (no parse-time cost beyond append; pays at lookup, out of scope here)                               |
| Backtracking model  | Single-pointer cursor with no checkpoint pattern | Checkpoint/restore over `Input.Protocol`; lexer uses the round-trip even for one-byte peeks                                                       |
| Position tracking   | Computed once on error                           | Maintained every advance, including saturating arithmetic and line/column rebuild                                                                |

The Foundation parser is structurally simpler at the cost of generality
(no streaming, no typed-error inputs, no checkpoint API). swift-json
trades structural simplicity for the typed-throws + ~Copyable cursor +
generic Input.Protocol substrate. Most of the gap is the price of that
abstraction layer when it cannot inline through; the rest is the
allocation strategy in `lexString` / `lexNumber`.

## Outcome

**Status**: RECOMMENDATION. Five-tier path forward, cheapest first.
The first item alone resolves the framing that motivated this
investigation; tiers 2–4 close most of the residual 3× gap to
Foundation; tier 5 requires upstream `Input.Borrowed` to land first.

### Tier 0 — Immediate (no code change in swift-json or swift-rfc-8259)

Fix the regen script in `swift-foundations/swift-linter-rules`:

```diff
-swift run symbol-graph-conformance-oracle Outputs/swift-stdlib/Swift.symbols.json
+swift run -c release symbol-graph-conformance-oracle Outputs/swift-stdlib/Swift.symbols.json
```

(`Scripts/regenerate-stdlib-refinements.sh:71`)

Effect: 129 s → ~1 s parse on the 86 MB input — a ~130× speedup with
one flag. The first build adds ~80 s of compile time for release-mode
generic specialization; subsequent runs are cached. The script's
"typically 1–3 min wall-clock" comment on line 70 should be updated
to reflect this. The regen workflow runs once per toolchain bump; the
"swift-json text-parser bottleneck" framing becomes a non-issue.

### Tier 1 — Cheap allocation reduction in `swift-rfc-8259`

In `RFC_8259.Lexer.swift`:

1. **Replace `peek`'s checkpoint round-trip with `input.first`.**
   `Input.Buffer+Input.Protocol.swift:40-49` exposes `first: Element?`
   as a `_read` accessor; the current peek pays for checkpoint+restore
   every byte. This removes ~3 position-ops per byte across the whole
   input.

2. **Add a fast-path `skipWhitespace` that reads via the underlying
   storage when available.** The current per-byte peek+advance over
   whitespace is the largest single cost in the profile (≈310 ticks).
   The hot loop can run as a tight `while !input.isEmpty && isWS(input.first!) { advance() }`
   or, when the Input.Protocol substrate ever exposes a
   "skip-while-predicate" primitive, defer the loop to the cursor.

3. **Reuse a per-Lexer scratch `[UInt8]`** in `lexString` cleared with
   `removeAll(keepingCapacity: true)` between strings. Eliminates one
   `Array` allocation per JSON string. For symbol-graph-scale inputs
   that is millions of avoided allocations.

4. **Skip the manual span→`[UInt8]` copy in `lexNumber`.** Pass
   `bytes.span` directly to `RFC_8259.Number.Original(_:)`
   (whose initializer is already generic over `Collection<UInt8>`),
   or use `[UInt8](unsafeUninitializedCapacity:initializingWith:)`
   to copy once. Eliminates one `Array` allocation per number.

These are local edits in one file, behind no protocol changes. They do
not move the public API.

### Tier 2 — Adopt `swift-ascii-parser-primitives` for integer parsing

In `lexNumber`, drop the `String(decoding:)` → `Int64(numStr)` /
`UInt64(numStr)` route in the integer branch and call
`ASCII.Decimal.Parser` from `swift-ascii-parser-primitives` (an
existing peer of `swift-parser-primitives`) directly on the byte
buffer. Keep the String route for the float branch until a faster
float parser exists in the ecosystem. This adds one dependency to
`swift-rfc-8259`.

### Tier 3 — String construction without re-walking the UTF-8 bytes

For JSON strings with no escape sequences (the vast majority in
symbol-graph-class inputs), construct the `String` directly with
`String(unsafeUninitializedCapacity:initializingWith:)` over the
contiguous byte range. Skip the `_fromUTF8Repairing` + `_allASCII`
detour. Strings with escapes keep the current path because they
require character-level rewriting anyway.

### Tier 4 — Span-specialized internal lexer (medium rewrite)

Add an internal Span-based lexer alongside the current generic one,
gated on the input being a contiguous byte buffer (the public APIs
all accept `String` or `[UInt8]`, both of which have contiguous
storage). Public API stays as-is; the byte-Collection and String
overloads dispatch to the specialized path when available. This
closes most of the remaining gap to Foundation without waiting for
ecosystem-wide `Input.Borrowed`.

### Tier 5 — Move to `Input.Borrowed` when it lands

When `swift-input-primitives` adds `Input.Borrowed` / `Input.Span`
(currently deferred per `Input.swift:55-63` and not yet present but
language-unblocked per the suppressed-escapable-associated-types
experiment), swift-rfc-8259 can switch its `Input` substrate to the
borrowed view. The internal Span specialization of Tier 4 becomes the
generic path; the owned-buffer path remains for callers that need to
keep the input alive across the parse result.

### Out-of-scope alternative: "use Foundation for hot consumers"

Given that the framing "parse is 99.95% of total time" was
build-config-conditioned, the case for "tell hot-path consumers to use
Foundation.JSONDecoder" is weaker than the original handoff implied —
in release mode the gap is 3×, not 1000×. The right line is probably:
ship Tier 0 immediately, do Tiers 1–3 as ergonomic local cleanups, and
let Tier 4 wait until either a second performance-sensitive consumer
surfaces or `Input.Borrowed` is closer to landing.

## 6. Measured outcomes after Tiers 0/1/3 (v1.1.0)

The implementation landed in three repos:

| Tier | Where | Change |
|------|-------|--------|
| 0 | `swift-foundations/swift-linter-rules/Scripts/regenerate-stdlib-refinements.sh` | `swift run` → `swift run -c release` on line 71; comment on line 70 updated |
| 1 + 3 | `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Lexer.swift` | Constraint tightening (`Input: … & Input.Access.Random`); cheap `peek` via the random-access subscript; tight `skipWhitespace`; reusable `_stringScratch` member with `isASCII` tracking and `String(unsafeUninitializedCapacity:initializingUTF8With:)` on the ASCII path in `lexString`; collapsed double byte-copy in `lexNumber` to a single `init(unsafeUninitializedCapacity:initializingWith:)` |
| 1 (matching constraint) | `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Parser.swift` | `Input: … & Input.Access.Random` propagated through the `Parser` generic parameter |

All 124 tests in `swift-rfc-8259` pass after the changes.

### Before vs after — single iteration, 86 MB `Swift.symbols.json`, release build

```
input size: 90,251,496 bytes (86.07 MB)

                                                  BEFORE       AFTER     Δ
[FLOOR]   byte-iterate Data                       0.243 s      0.245 s    ≈
[FLOOR]   byte-iterate [UInt8]                    0.006 s      0.006 s    ≈
Foundation.JSONSerialization.jsonObject(with:)    0.297 s      0.302 s    ≈
swift-json JSON.parse(String)                     0.959 s      0.703 s   −27 %
swift-json JSON.parse([UInt8])                    0.907 s      0.672 s   −26 %
```

Throughput on the bytes path: 95 MB/s → 128 MB/s. The gap to
`Foundation.JSONSerialization` is now 2.33× (down from 3.05×).
Three-iteration runs scale linearly (2.00 s and 2.14 s for the two
swift-json paths respectively), confirming the single-iter number is
stable.

### Hotspot collapse confirmed by `sample` profile (10 × parse)

Comparing before/after `sample` runs against the same workload (same
input, same host, 10-iter loop, sampling 6 s at 1 ms):

| Cost center                              | Before (ticks) | After (ticks) | Δ                                    |
|------------------------------------------|---------------:|--------------:|--------------------------------------|
| `Lexer.skipWhitespace` (all sites)       | ~310           | ~237          | −24 % (cheap-peek + tight loop)      |
| `Input.Buffer.advance()`                 | ~150           | ~97           | −36 % (peek no longer triggers extra advances) |
| `Lexer.lexString` direct + Array growth   | ~200 + ~125    | ~59 + 0       | scratch buffer eliminates the per-string `[UInt8]` allocation; `_ArrayBuffer._consumeAndCreateNew` disappears from the top-30 |
| `_platform_memmove` (new in after)       | —              | 62            | the `update(from:count:)` memcpy that replaces byte-by-byte append in `lexString`'s ASCII path |
| `Lexer.next()` dispatch                  | ~220           | ~220          | unchanged — pure dispatch cost survives |
| `outlined destroy of RFC_8259.Value`     | ~242           | ~361          | absolute time ≈unchanged; ratio rises because total parse time fell |

The skipWhitespace and Lexer.advance reductions account for most of
the wall-clock improvement. The lexString change shows up in the
profile primarily as the absence of allocation churn (per-iteration
heap traffic dropped substantially), with the residual cost shifting
to a single `memmove` for the ASCII fast-path copy.

### Residual gap

The remaining 2.33× gap to Foundation is concentrated in:

- **Tree destruction** (≈7 % per iteration in the new profile) —
  recursive `[(String, Value)]` / `[Value]` deinit; would only
  shrink by changing the tree shape (out of scope).
- **`Lexer.next()` dispatch** (≈4 %) — the switch-based token
  dispatch over every leading byte; Foundation uses a faster
  table-lookup or pointer-arithmetic equivalent.
- **Typed-Position arithmetic in `advance()`** — line/column tracking
  on every byte; could be deferred to error sites if a "fast position"
  mode is added.
- **Generic-Input.Protocol dispatch overhead** — even after
  specialization, the cursor sits behind a protocol chain. The Tier 4
  Span-specialized internal lexer remains the way to close this.

### Disposition

- Tier 0: **DONE**. The regen workflow now runs in ~1 s on subsequent
  invocations (first invocation pays ~1 min compile-cache cost).
- Tier 1: **DONE**. Local edits in one file (`RFC_8259.Lexer.swift`)
  plus a matching constraint on `RFC_8259.Parser`. No public API
  surface beyond constraining the generic parameter (all current
  callers use `Input.Buffer`, which already conforms to
  `Input.Access.Random`).
- Tier 3: **DONE** (partial). `String(unsafeUninitializedCapacity:)`
  is engaged on the ASCII fast-path inside `lexString`. The
  "build String directly from the input span without copying via
  scratch" variant remains DEFERRED — it needs either an
  `Input.Borrowed` substrate (Tier 5) or an extra primitive on
  `Input.Access.Random` to slice between checkpoints. Neither is in
  scope here.
- Tier 2, Tier 4, Tier 5: **HELD**. Tier 4 specifically waits on a
  second demonstrated hot consumer beyond the symbol-graph oracle
  (which is now sub-second under the Tier 0 fix). Tier 5 waits on
  `Input.Borrowed` landing in `swift-input-primitives`.

## References

- `swift-foundations/swift-json/Sources/JSON/JSON.Parse.swift` — public API surface
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Parser.swift` — parser
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Lexer.swift` — lexer (hotspots in lines 62–98, 220–352, 357–457)
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Decode.swift` — input entry; the `Swift.Array(bytes)` materialisation lives at line 45
- `swift-primitives/swift-input-primitives/Sources/Input Primitives/Input.swift` — Input.Borrowed "future direction" note
- `swift-primitives/swift-input-primitives/Sources/Input Primitives/Input.Buffer+Input.Protocol.swift` — the `first` accessor that the lexer's `peek` should be using
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Decimal Parser Primitives/ASCII.Decimal.Parser.swift` — drop-in integer parser
- `swift-primitives/swift-cursor-primitives/Sources/Cursor Primitives Core/` + `swift-primitives/swift-byte-parser-primitives/Sources/Byte Parser Primitives/Cursor+Byte.swift` — Span-backed typed cursor pattern (`Cursor<Byte>`)
- `swift-primitives/swift-parser-primitives/Experiments/suppressed-escapable-associated-types/Sources/main.swift` — confirms `~Escapable` on associated types works in Swift 6.2.3+
- `swift-foundations/swift-linter-rules/Scripts/regenerate-stdlib-refinements.sh:71` — the regen script line that runs the experiment in debug mode
- `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/Outputs/run-stdlib.txt` — committed evidence of the 129 s debug-mode run
- Benchmark harness: `/tmp/json-parse-bench/` (scratch, not committed) — Package depending on swift-json by path; numbers in §2 are reproducible from this harness against `Outputs/swift-stdlib/Swift.symbols.json`

## Provenance

Investigation invoked via the branching `/handoff` mechanism
([HANDOFF-005]); the branching brief at
`/Users/coen/Developer/HANDOFF-swift-json-parse-performance.md` framed
the question as "why is the parse 99.95 % of total time?". The
investigation surfaced that the framing itself was build-config
staleness ([HANDOFF-016] premise-staleness axis) and re-framed
accordingly per [RES-028] (smallest-isolation-first reproduction in
single-target release mode).
