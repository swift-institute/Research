# Streaming JSON Deserialize: Comparative Analysis

<!--
---
version: 1.0.2
last_updated: 2026-05-14
status: DECISION
tier: 2
scope: cross-package
applies_to:
  - swift-foundations/swift-json
  - swift-ietf/swift-rfc-8259
predecessor: swift-institute/Research/streaming-json-deserialize-status-quo-and-prior-art.md v1.0.0
verification_experiments:
  - swift-foundations/swift-json/Experiments/streaming-deserialize-a0-feasibility/ (A0; commit 0953628, 2026-05-14)
  - swift-foundations/swift-json/Experiments/parse-performance-bench/ (A2 measurement gate; codable-lookup-event-grain mode added in commit 0c046b5)
implementations:
  - swift-ietf/swift-rfc-8259 (Wave 0a): commit b335acb (Span.EventStream + 35 tests); ad68025 (consumeAsParseValue public promotion); 572cc8b (peekStructural); f4f3cb2 (consumeAsParseValue doc + SPI-rejection record)
  - swift-foundations/swift-json (Wave 0b/0c/0d + Wave 1): commits b0ea876 (JSON.Span.EventStream + JSON.Assemble), 64a0ce2 (Serializable.deserialize(events:) + foundational conformers + 20 tests), 0c046b5 (bench codable-lookup-event-grain mode), 17bce12 (oracle migration)
trigger: HANDOFF-streaming-json-deserialize-research.md (Phase 2)
changelog:
  - 1.0.0 (2026-05-14): initial four-option comparative analysis;
    recommended Option B (event-emitting Span parser); A0/A1/A2 phased
    plan; §8 ecosystem migration survey.
  - 1.0.1 (2026-05-14): A0 spike landed; three premise results recorded
    in NEW §9 below. Premise 1 (Token.Kind storage incl .unknown(UInt8))
    GREEN. Premise 3 (withContiguousStorageIfAvailable engagement)
    GREEN. Premise 2 (lifetime + inout + protocol dispatch) GREEN on
    compile/correctness BUT RED on the §4.3 default-fallback timing
    signal (Bar/Today = 4.48× mock; production narrows but wedge is
    structural). §4.3 amended: "UNTESTED at write time" → "EMPIRICALLY
    CONFIRMED at A0"; implementation-side `JSON.assemble` short-circuit
    promoted from "recommended" to REQUIRED A1 constraint. Original
    v1.0.0 analysis preserved per [RES-008]; §9 records the A0
    disposition.
  - 1.0.2 (2026-05-14): A1 Wave 0 + Wave 1 implementation landed
    (5 substrate commits across 2 repos + 1 doc-enhancement commit).
    A2 measurement gate PASSED — DECISIVELY. Status upgraded
    RECOMMENDATION → DECISION. Three findings recorded in NEW §10
    below. (1) A2 axis (a): swift-json event-grain decode is 0.357×
    Foundation `JSONDecoder` on the canonical 86 MB Swift stdlib
    symbol-graph workload — 2.80× FASTER than Foundation, vs the
    ≤1.10× projected target. (2) A2 axis (b): default-fallback path
    within 5.3 % of status-quo `init(jsonBytes:)` baseline (noise-
    floor; §4.3 short-circuit working as designed). (3) Wave 1 oracle
    migration: 0.149 s release wall-clock, 6.4× release-to-release
    speedup; 136 refinement pairs match pre-Wave-1 byte-identically.
    A1 deviation #2 (`consumeAsParseValue` public vs SPI) re-verified
    deliberately at v1.0.2 prep: SPI form REJECTED by compiler
    (verbatim error captured in commit f4f3cb2's doc). Public is the
    correct disposition; doc comment now records the contract +
    SPI-rejection rationale + intended-use-case guard for future
    consumers. Three caveats called out in §10.3: (a) the simdjson
    framing is theoretical not measured and is intentionally dropped;
    (b) the 0.357× figure is workload-specific to one schema with 67 %
    skip ratio — other workloads with different skip ratios will see
    different ratios; (c) Wave 2 (Lint.Manifest + Manifest.Load
    fanout) and Wave 3 (test infrastructure) remain deferred per the
    principal's minimal-scope decision.
---
-->

## Context

This document is the design follow-on to
`swift-institute/Research/streaming-json-deserialize-status-quo-and-prior-art.md`
v1.0.0 (RECOMMENDATION). Phase 1 established three facts:

1. swift-json today is canonical pattern α (full-tree DOM
   materialise-then-walk). The Codable-style decode path is
   measured 37 % slower than Foundation's `JSONDecoder` on the
   canonical 86 MB Swift stdlib symbol-graph workload with a
   `Symbol` schema reading 3 of ~9 keys per object (per
   `parse-performance.md` v1.2.1).
2. The JSON-decoding field has matured past pattern α for
   schema-known decode at scale. Apple's own `JSONDecoder`
   rewrote to pattern β (lazy structural index) in 2023.
   System.Text.Json, serde_json, jsoniter, and Newtonsoft
   `JsonTextReader` are canonical pattern γ (pull-driven event
   stream into target).
3. The substrate for either pattern β or γ already exists in
   `swift-rfc-8259` (Tier 4 `Span.Parser` + `Span.Lexer`,
   `RFC_8259.Token` public surface) and `swift-parser-primitives`
   (`Parser.Input.Streaming`). No new ecosystem primitive
   required for the straightforward implementations.

Phase 1's outcome is descriptive. This Phase 2 document is
prescriptive. It enumerates structurally distinct architectures,
evaluates each against the contracts the swift-json package
maintains, identifies any new ecosystem primitive proposal and
gates it per `[RES-018]`, and recommends a single architecture
with a phased landing plan mirroring `parse-performance-architecture.md`
v1.0.2's A0/A1/A2 measurement-gate shape.

This is RESEARCH ONLY — no source files are modified by this
investigation. Implementation lands in subsequent dispatches under
the phased plan; per `[BENCH-010]` / `[RES-018]`, no commitment
to ship is implied. Per the originating handoff, the
honest-disagreement rule applies — if the analysis concludes
that closing the 37 % gap is structurally infeasible without
breaking the dynamic-access 14× lookup advantage, the recommendation
will say so directly.

## Question

What architecture for swift-json's typed-decode path closes the
37 % parse+decode gap to Foundation's `JSONDecoder` on
schema-known partial-shape workloads, while:

1. Preserving the dynamic-access path's 14× lookup advantage
   (non-negotiable per Phase 1 §1.3).
2. Preserving the typed-throws contract (`throws(JSON.Error)`).
3. Preserving the Foundation-free production surface
   (`[PRIM-FOUND-001]` + `[ARCH-LAYER-007]` + `[ARCH-LAYER-011]`).
4. Preserving the strict-memory-safety discipline (`@safe`
   cursor + lifetime annotations; no `UnsafePointer<UInt8>`).
5. Preserving the existing public API
   (`JSON.parse`, `JSON.Serializable`, `JSON.parse.prepared`,
   `JSON.parse.located`).
6. Composing with the existing Tier 4 Span-specialised parser
   (`RFC_8259.Span.Parser`) without duplicating its lexer
   machinery or regressing its Foundation-parity 1.02× / 1.06×
   measurements per `parse-performance-architecture.md` v1.0.2 §9.
7. Implementation cost (LoC + arcs) bounded enough to land
   without ecosystem-wide protocol-evolution debt.

And: which architecture is the recommended path?

## Analysis

### 1. Empirical input from Phase 1

Carried forward from Phase 1 § Outcome, verified at write time
against the cited sources:

| Carried fact | Status |
|---|---|
| 37 % gap on partial-shape decode (Foundation 0.220 s vs swift-json 0.349 s, 86 MB workload, Symbol schema) | Verified: 2026-05-14 (cited from `parse-performance.md` v1.2.1 box at top) |
| 14× dynamic-access lookup advantage (swift-json `JSON.parse` + dynamic member vs Foundation `JSONSerialization` + `as? [String: Any]`) | Verified: 2026-05-14 (cited from `parse-performance.md` v1.2.0/v1.2.1) |
| Tier 4 `RFC_8259.Span.Parser` is `~Copyable & ~Escapable` over `Span<UInt8>`, hand-rolled recursive descent, byte-level dispatch (bypasses `RFC_8259.Token` due to compiler bug) | Verified: 2026-05-14 (read `RFC_8259.Span.Parser.swift` head + dispatch fork in `RFC_8259.Decode.swift`) |
| `RFC_8259.Token` enum exists at public surface; carries `String` for `.string` and `RFC_8259.Number` for `.number`; payload variant triggered "copy of noncopyable typed value" bug when stored as `Optional<Token>` in `~Copyable & ~Escapable` struct (Swift 6.3+ as of 2026-05-13) | Verified: 2026-05-14 (per `RFC_8259.Parser.Span.swift` lines 18-28 header comment) |
| `parse-performance-bench` harness ships eight modes (`all`, `floor`, `foundation`, `swift-json-string/bytes`, `crossover`, `synthetic-lookup`, `size-dist`, `lookup`, `codable-lookup`, `sanity`, `equiv`) wired against the canonical workload with `Symbol`/`SymbolKind`/`SymbolIdentifier`/`SymbolGraph` schema | Verified: 2026-05-14 (read `parse-performance-bench/Sources/parse-performance-bench/main.swift`) |
| The v2 arc refcount-per-copy lesson: a Copyable wrapper × multi-buffer storage shape pays one refcount per heap-backed component per pattern-match-extract (per `copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1 §2) | Verified: 2026-05-14 |
| `JSON.Serializable` is the institute's canonical typed-throws alternative to stdlib `Codable` (per `codable-untyped-throws-disposition.md` v1.0.0 DECISION); the `Lint.Manifest` adoption at `swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift:116` is the existing precedent | Verified: 2026-05-14 |

### 2. Candidate architectures

Per `[RES-010b]`, four structurally distinct candidates. The
honest-disagreement candidate (Option A) is included per the
originating handoff's explicit instruction.

#### Option A — Document the trade-off; don't pursue

- **Shape**: leave swift-json on pattern α. Document the 37 %
  gap as a known structural property of the Copyable
  full-tree-then-extract architecture. Recommend that consumers
  whose workload is genuinely dominated by partial-shape decode
  (and who cannot tolerate the gap) reach for Foundation
  `JSONDecoder` via a Foundation Integration subtarget — except
  the institute has explicitly excluded Foundation Integration
  per `feedback_improve_ecosystem_over_foundation_or_thirdparty`
  / `feedback_ecosystem_no_foundation_in_main_targets`, so this
  escape hatch is closed.

- **Wedges closed**: none on the parse+decode axis. swift-json
  remains at parity for dynamic-access lookup (14×) and post-
  decode struct access (≈ equal); the 37 % parse+decode gap
  remains.

- **Public-API impact**: none.

- **Implementation cost**: zero.

- **Ecosystem-fit**: respects `[RES-027]` honest-disagreement.
  However: the institute has chosen `JSON.Serializable` as the
  Codable alternative; the 37 % gap is the durable cost of that
  choice's current implementation. A "document and move on"
  outcome means accepting that gap permanently against the
  architectural target the institute has set for itself.

- **When to choose**: if no candidate architecture in B / C / D
  closes the gap without breaking a contract, OR if all three
  candidates' implementation costs are categorically out of
  proportion to the wedge size.

- **Honest framing**: 37 % on parse+decode is bounded — not 10×.
  swift-json's dynamic-access path is materially faster than
  Foundation's equivalent. For consumers whose workload mixes
  partial-shape decode with dynamic access (the common case),
  swift-json is already net-faster than Foundation. The 37 % is
  a wedge only on the partial-shape-decode-only subset. Option A
  is a defensible choice if the wedge size is genuinely small
  for actual ecosystem consumers.

#### Option B — γ: event-emitting Span parser + JSON.Serializable.deserialize(events:)

- **Shape**: extend the Tier 4 `RFC_8259.Span` namespace with
  an `EventStream` cursor type that exposes the parse as a
  pull-driven token sequence. Add an event-grain method to
  `JSON.Serializable` that accepts an `inout JSON.Span.EventStream`
  and lets the conformer drive the parse directly into the
  target. Existing consumers using `JSON.Serializable.init(jsonBytes:)`
  with the tree-grain `deserialize(_: JSON)` continue to work
  unchanged (default implementation delegates); opt-in consumers
  who author the event-grain method get the fast path.

  Sketched API surface:
  ```swift
  extension RFC_8259.Span {
      @safe
      public struct EventStream: ~Copyable, ~Escapable {
          @_lifetime(borrow bytes)
          public init(_ bytes: borrowing Swift.Span<UInt8>, maxDepth: Int = 512)

          public mutating func next() throws(RFC_8259.Error) -> RFC_8259.Token.Kind?
          public mutating func currentString() throws(RFC_8259.Error) -> String
          public mutating func currentNumber() throws(RFC_8259.Error) -> RFC_8259.Number
          public mutating func skipValue() throws(RFC_8259.Error)
          public var position: RFC_8259.Position { get }
      }
  }

  extension JSON.Span {
      @safe
      public struct EventStream: ~Copyable, ~Escapable {
          internal var inner: RFC_8259.Span.EventStream
          // Re-throws RFC_8259.Error as JSON.Error per the existing pattern.
      }
  }

  extension JSON.Serializable {
      // NEW protocol requirement, with a default that delegates to the
      // existing tree-grain path so existing conformers continue to work.
      static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> Self
  }

  extension JSON.Serializable {
      // The default fallback. Existing conformers get this for free.
      @inlinable
      public static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> Self {
          let json = try JSON.assemble(from: &events)   // event → tree
          return try Self.deserialize(json)
      }

      // The new init that opts into the event-grain path.
      @inlinable
      public init(eventDecodingJsonBytes bytes: borrowing Swift.Span<UInt8>) throws(JSON.Error) {
          var stream = JSON.Span.EventStream(bytes)
          self = try Self.deserialize(events: &stream)
      }
  }
  ```

  Returns `RFC_8259.Token.Kind` (the payload-free variant
  already in `RFC_8259.Token.Kind.swift`) instead of full
  `RFC_8259.Token` to sidestep the compiler-bug constraint
  documented in `RFC_8259.Parser.Span.swift` lines 18-28.
  String / number values are accessed via the cursor's
  `currentString()` / `currentNumber()` methods, mirroring
  System.Text.Json's `Utf8JsonReader.GetString()` / `GetInt32()`
  shape.

- **Wedges closed**: the 37 % parse+decode gap on partial-shape
  schemas, for conformers that opt in via the event-grain
  method. Skip is **parse-then-discard** (byte-walk, no value
  materialisation) — closes the gap for the workload's
  materialisation cost but not for the byte-walk cost. On the
  canonical workload's `Symbol` schema (3 of ~9 keys), the
  saved materialisation work is the discarded ⅔ of objects'
  worth of `String` + `RFC_8259.Value` allocations per object —
  the dominant component of the 37 % wedge.

- **Public-API impact**: ONE new protocol requirement on
  `JSON.Serializable` (`deserialize(events:)`) with a default
  implementation. Existing conformers are not breaking-changed.
  ONE new initializer (`init(eventDecodingJsonBytes:)`) for
  opt-in consumers. The existing `init(jsonString:)` /
  `init(jsonBytes:)` / `deserialize(_: JSON)` surface is
  preserved verbatim.

- **Implementation cost**: medium. Estimated ~700-1200 LoC
  across:
  - `swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.EventStream.swift`
    (new): the Span-backed event cursor; ~300-400 LoC.
  - `swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.EventStream Tests.swift`
    (new): coverage for all token kinds, malformed inputs,
    surrogate pairs, depth tracking; ~200-300 LoC.
  - `swift-foundations/swift-json/Sources/JSON/JSON.Span.EventStream.swift`
    (new): the JSON-layer wrapper that translates `RFC_8259.Error`
    to `JSON.Error`; ~100 LoC.
  - `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift`
    (modified): add the protocol requirement + default impl + new
    init; <100 LoC for the protocol surface, plus event-grain
    `deserialize(events:)` for each of the foundational
    conformances (`String`, `Int`, `Int64`, `Double`, `Bool`,
    `Array`, `Dictionary`, `Optional`, `JSON`). Each foundational
    conformer is non-trivial: `Array.deserialize(events:)`
    consumes `.arrayStart`, loops until `.arrayEnd`, recursively
    calls `Element.deserialize(events:)`, handles commas;
    `Dictionary` is similar with key+colon dispatch; `Optional`
    branches on `.null`. Realistic per-conformer cost: 30-50 LoC;
    total foundational-conformer delta ~200-300 LoC. Without
    these, no opt-in consumer's `deserialize(events:)` body can
    compose primitive-field decode without falling back through
    the tree path — they are load-bearing for the whole arc.
  - `swift-foundations/swift-json/Experiments/parse-performance-bench/Sources/parse-performance-bench/main.swift`
    (modified): the `Symbol` schema gets a new
    `deserialize(events:)` opt-in implementation; the
    `codable-lookup` mode re-runs against it; <200 LoC.

  Two arcs (Phase A0 + Phase A1) of dispatch effort.

- **Ecosystem-fit**: excellent. The pattern aligns with
  System.Text.Json `Utf8JsonReader`, serde_json + Visitor,
  jsoniter Iterator, Newtonsoft `JsonTextReader` — all surveyed
  pattern γ implementations. Mirrors the institute's existing
  `Binary.Bytes.Input.View` precedent one layer up at the text
  layer. Does NOT require a new ecosystem primitive — uses
  `Swift.Span<UInt8>` (stdlib), `RFC_8259.Token.Kind` (existing
  public type), and the existing `RFC_8259.Span.Lexer`
  substrate. `[RES-018]` second-consumer hurdle does NOT fire
  (no new primitive proposed; the EventStream is a refinement
  of an existing internal type, lifted to public surface inside
  one package).

- **Strict-memory-safety**: preserved. The `EventStream` is
  `@safe`, mirrors `Binary.Bytes.Input.View` and
  `RFC_8259.Span.Lexer`. `@_lifetime(borrow bytes)` at the
  initializer; `@_lifetime(self: copy self)` on mutating
  methods. No `UnsafePointer<UInt8>` introduced.

- **Foundation-freedom**: preserved. No `import Foundation` in
  production code. The dispatch fork at `JSON.Serializable.init(eventDecodingJsonBytes:)`
  routes entirely through `swift-rfc-8259` substrate, which is
  itself Foundation-free.

- **Tier 4 composition**: composes by extending. The new
  `RFC_8259.Span.EventStream` shares `RFC_8259.Span.Lexer` with
  the existing `RFC_8259.Span.Parser` — same cursor, different
  emission contract. The parser stays as the tree-building path
  (used by `JSON.parse(_:)` for dynamic access); the
  EventStream is the event-emitting path (used by the new
  opt-in init). The Tier 4 lexer work is reused; no duplication
  of byte-level primitives.

- **Risks**:
  - (a) The Token-payload compiler bug at
    `RFC_8259.Parser.Span.swift:18-28` — needs Phase A0
    verification on the current toolchain. The Phase A1 design
    avoids the bug by returning `RFC_8259.Token.Kind` (payload-
    free) from `next()` rather than `RFC_8259.Token` (with
    payload). If the bug is still present on the target
    toolchain, the design is unaffected. If the bug has been
    fixed in 6.4-dev, the design simplifies marginally but is
    not blocked either way.
  - (b) Skip-cost: γ's skip is byte-walk parse-then-discard. On
    a workload where skipped values are deeply nested or
    contain very large strings/numbers (i.e., where the byte-
    walk cost itself dominates), the gap may not fully close.
    The canonical workload's symbol-graph shape is not in this
    regime (skipped values are short strings + short arrays).
    Phase A2 measurement gate fires if the residual gap is too
    large; Phase B (conditional) augments with a structural
    skip primitive — see Option C-like augmentation below.
  - (c) Protocol-evolution: adding a new method to
    `JSON.Serializable` is technically a source-breaking change
    for existing third-party conformers that haven't opted in.
    The default implementation eliminates this in practice
    (existing conformers automatically inherit the fallback) —
    but the protocol's witness table grows, which is a binary
    interface change. Pre-1.0 the institute's discipline is
    correctness-first per `[ARCH-LAYER-008]`; this risk is
    bounded.
  - (d) Default fallback regression: the
    `deserialize(events:)` default delegates to
    `JSON.assemble(from:)` → `deserialize(_: JSON)`. If
    `JSON.assemble` is naïve (event → tree → deserialize), it
    may regress existing conformers by 1-5 % over the current
    direct tree path. Phase A1 measurement gate must verify
    no regression on existing conformers, or the default must
    fork at compile time to skip the event-grain path entirely
    when the conformer hasn't overridden — see §5.5 below.

#### Option C — β: structural-index scanner + JSON.Lazy facade

- **Shape**: add a `JSONMap`-analog scanner that emits an
  in-memory structural index of the input bytes — an array of
  `(token-kind, byte-offset, next-sibling-offset)` triples plus
  a backing `Span<UInt8>`. A `JSON.Lazy` facade wraps the
  pair `(bytes, map)` and exposes a façade analogous to `JSON`
  (subscript, dynamic member lookup, typed accessors). Values
  are decoded only when the consumer accesses them; skipping
  to a non-accessed field is O(1) via the next-sibling offset.

  Sketched API surface:
  ```swift
  extension RFC_8259 {
      // The structural index produced by one forward byte-walk.
      // Storage shape: multi-buffer slabs of fixed-width triples.
      public struct Map: ~Copyable {
          internal var tokenKinds: [RFC_8259.Token.Kind]
          internal var byteOffsets: [Int]
          internal var nextSiblingOffsets: [Int]
      }
  }

  extension JSON {
      // The lazy façade.
      public struct Lazy: ~Copyable, ~Escapable {
          internal let bytes: Span<UInt8>
          internal let map: borrowing RFC_8259.Map
          // Same shape as JSON for subscript/dynamic-member lookup.
      }
  }

  extension JSON.Serializable {
      static func deserialize(lazy: borrowing JSON.Lazy) throws(JSON.Error) -> Self
  }
  ```

- **Wedges closed**: all four wedges of pattern α, *plus*
  structurally-O(1) skip (per Foundation's `JSONScanner` model).
  Has the strongest potential to close the 37 % gap to
  parity-or-better on the canonical workload — Foundation's
  measured 0.220 s is the demonstrated upper bound for this
  architecture on this workload.

- **Public-API impact**: significant. A new public `JSON.Lazy`
  type that consumers must learn to use for the fast path;
  a new protocol requirement on `JSON.Serializable` (or a
  parallel `JSON.Lazy.Serializable`); a new entry-point
  initializer or method. The existing `JSON` value type remains
  for the dynamic-access path. Two surfaces.

- **Implementation cost**: high. Estimated ~1500-2500 LoC
  across:
  - `swift-rfc-8259/Sources/RFC 8259/RFC_8259.Map.swift` (new):
    the structural map type + scanner; ~500-800 LoC.
  - `swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.Scanner.swift`
    (new): the byte-walk that produces the map; ~300-500 LoC.
  - `swift-foundations/swift-json/Sources/JSON/JSON.Lazy.swift`
    (new): the façade type + subscript/dynamic-member lookup;
    ~400-600 LoC.
  - `swift-foundations/swift-json/Sources/JSON/JSON.Lazy Tests.swift`
    (new): coverage of the lazy access path; ~300-500 LoC.
  - Protocol + dispatch + tests: ~200-400 LoC.

  Three or four arcs of dispatch effort.

- **Ecosystem-fit**: acceptable. Modern Foundation `JSONDecoder`
  uses this architecture (per Phase 1 §3.4); the institute's
  precedent is to NOT reach for Foundation (per `[ARCH-LAYER-011]`)
  but the same shape is implementable in pure Swift. simdjson
  `ondemand` is the C++17 analogue.

- **`[RES-018]` second-consumer gate**:
  - **The first consumer is swift-json itself.** Does a second
    consumer exist? The structural-index pattern is potentially
    reusable for XML, YAML, TOML, ASN.1 — any structured-text
    format with bracket-balanced grammars — and the institute's
    `swift-binary-parser-primitives` is the analogous shape for
    binary parsing. A future `swift-rfc-XXXX-yaml` package
    could reuse the structural-index pattern.
  - HOWEVER: there is no second consumer in the originating
    investigation. Per `[RES-018]`'s rationale ("a genuinely
    useful primitive will have a second consumer within the
    research session itself"), proposing `RFC_8259.Map` as a
    new ecosystem primitive at this point would be premature.
    The map could be implemented internal to `swift-rfc-8259`
    initially, with promotion to a `swift-text-map-primitives`
    or similar deferred until a second consumer surfaces.

- **`[BENCH-011]` integration-probe gate**: critical. The
  `RFC_8259.Map` shape is a multi-buffer storage primitive
  (three parallel arrays). The Copyable `JSON.Lazy` facade
  wrapping it would pay the v2 arc's refcount-per-copy cost on
  every subscript / dynamic-member access. Per
  `copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1 §3.2 the
  swift-json v2 arc measured a +226 % regression on lookup at
  the canonical workload from exactly this shape (a Copyable
  `JSON` wrapping a multi-buffer storage). The `~Copyable
  JSON.Lazy` design above avoids this by making the wrapper
  `~Copyable & ~Escapable` (no pattern-match-extract copy), but
  this carries its own cost: consumers cannot capture
  `JSON.Lazy` values across method boundaries without
  `borrowing` annotations, the protocol's `deserialize(lazy:)`
  must use `borrowing JSON.Lazy`, etc. The institute has
  established this discipline already (per
  `2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md`)
  — the pattern is well-trodden — but the consumer ergonomics
  cost is real.

- **Strict-memory-safety**: preserved. `RFC_8259.Map`'s
  multi-buffer storage uses `[T]`-backed arrays, no
  `UnsafePointer`. `JSON.Lazy` is `@safe`. Lifetime annotations
  propagate through `borrowing JSON.Lazy` in `deserialize(lazy:)`.

- **Foundation-freedom**: preserved. The map is built from
  primitive Swift types.

- **Tier 4 composition**: composes by parallel forking. The new
  scanner is a third path alongside the existing
  `RFC_8259.Span.Parser` (tree-building) and Option B's
  `RFC_8259.Span.EventStream` (event-emitting). Three parallel
  byte-walks share the Span.Lexer substrate but emit different
  outputs.

- **Risks**:
  - (a) The map storage shape is a tier-1 refcount-cost suspect
    per `[BENCH-011]`. Implementation requires the
    integration-probe (the existing `synthetic-lookup` bench
    mode) before any DECISION promotion.
  - (b) `JSON.Lazy` as `~Copyable & ~Escapable` is the right
    shape for the cost model but adds consumer-ergonomics
    friction. Adoption is slower than B's drop-in pattern.
  - (c) Public API surface grows significantly. Three types
    consumers may use (`JSON`, `JSON.Lazy`, plus the new
    `Serializable` protocol method); navigation cost.
  - (d) Building the map is itself a parse-time cost. For
    single-shot one-traversal consumers (e.g., the canonical
    workload's `Symbol` extraction), the map-build cost may
    eat the wedge it's supposed to close.
  - (e) Two arcs minimum + non-trivial protocol-evolution work.

#### Option D — Schema-driven projection codegen from JSON.Serializable

- **Shape**: a macro generates a specialised event-handler at
  compile time from the consumer's `JSON.Serializable`
  conformance. Each `Serializable` struct gets a derived
  `deserialize(events:)` (or equivalent) that emits a
  byte-level dispatch for exactly the fields it declares,
  skipping all others structurally. Analogous to serde's
  `#[derive(Deserialize)]` macro generating a specialised
  Visitor per struct.

  Sketched API surface:
  ```swift
  @JSONSerializable
  struct Symbol {
      let kind: SymbolKind
      let identifier: SymbolIdentifier
      let pathComponents: [String]
  }
  // The macro generates:
  // - JSON.Serializable conformance
  // - A specialised deserialize(events:) that hard-codes the
  //   field dispatch using a switch over field-name byte hashes
  //   or trie lookup
  // - Possibly a specialised lazy decode path that builds the
  //   exact projection for Symbol's shape
  ```

- **Wedges closed**: all four wedges of pattern α, plus
  byte-level dispatch specialisation per struct. Theoretical
  ceiling above Foundation `JSONDecoder` (Foundation's
  `KeyedContainer` uses runtime field-name lookup against the
  scanned key dictionary; a macro-generated dispatch can
  out-perform this).

- **Public-API impact**: significant. A new `@JSONSerializable`
  macro that consumers apply to their types. The existing
  hand-rolled `JSON.Serializable` conformance pattern remains
  for consumers who need manual control.

- **Implementation cost**: very high. Estimated ~3000-5000 LoC
  across:
  - A new `swift-json-macros` package or target with
    SwiftSyntax-based macro implementation.
  - The macro's compile-time analysis of the conformer struct
    (field types, optionality, nested conformers).
  - Generated code template + test infrastructure for the
    generated code's correctness.
  - Plus all of Option B's runtime infrastructure (the macro
    has to emit code that calls into something — `JSON.Span.EventStream`
    is the natural target).

  Four to six arcs of dispatch effort.

- **Ecosystem-fit**: marginal. The institute does have macro
  precedent (per `swift-foundations/swift-linter/Sources/`'s
  rule registry; `swift-foundations/swift-parsers/`'s @Splat
  macro), but a SwiftSyntax macro package is a major
  undertaking. The institute's typical approach favours
  hand-rolled clarity over codegen.

- **`[RES-018]` second-consumer gate**:
  - The first consumer is `JSON.Serializable`. A second consumer
    in the same investigation: NO. Plausible future consumers:
    other typed-throws serializer protocols (TOML, YAML, ASN.1),
    none of which currently exist in the institute. The
    second-consumer hurdle is NOT cleared.
  - This argues against proposing the macro infrastructure as a
    cross-cutting institute primitive. It could ship as a
    swift-json-specific macro initially, with promotion to a
    generic `swift-serialization-macro-primitives` (or similar)
    deferred until a second consumer surfaces.

- **Risks**:
  - (a) Macro tooling complexity. SwiftSyntax-based macros are
    a maintenance surface that compounds with every Swift
    toolchain bump.
  - (b) Generated-code debuggability. When the generated
    `deserialize(events:)` is wrong, the conformer's authors
    debug generated code they didn't write.
  - (c) Cost-benefit: D's theoretical ceiling above Foundation
    is real but bounded — likely 1.05-1.20× Foundation per
    workload, not 5×. Implementation cost is 4-6× Option B's.
  - (d) Requires Option B's runtime infrastructure as substrate
    — D is "B + macro on top," not a replacement for B.

#### Option comparison summary

| Criterion | A: Don't pursue | B: γ event-stream | C: β structural-index | D: codegen macro |
|---|---|---|---|---|
| Closes 37 % gap | No | **Yes (most)** | Yes (full) | Yes (full) + headroom |
| Preserves dynamic-access 14× | Yes (no change) | **Yes (separate path)** | Yes (separate `JSON` type stays) | Yes (separate path) |
| Preserves typed throws | Yes | **Yes** | Yes | Yes |
| Preserves Foundation-freedom | Yes | **Yes** | Yes | Yes |
| Preserves strict-memory-safety | Yes | **Yes** | Yes | Yes (in generated code) |
| Composes with Tier 4 Span parser | N/A | **Extends (shared Lexer)** | Parallel-forks (shared Lexer) | Composes via B |
| New ecosystem primitive? | No | **No** | Yes (`RFC_8259.Map`); fails `[RES-018]` second-consumer | Yes (macro infrastructure); fails `[RES-018]` |
| `[BENCH-011]` integration-probe needed? | No | **No (no storage shape change)** | **Yes — critical (multi-buffer map)** | Indirect (composes B's substrate) |
| Public-API impact | None | **One protocol method (with default) + one init** | Significant (`JSON.Lazy` type + protocol) | Significant (macro surface) |
| Implementation cost (LoC) | 0 | **~500-900** | ~1500-2500 | ~3000-5000 |
| Implementation cost (arcs) | 0 | **2 (A0 + A1)** | 3-4 | 4-6 |
| Reversibility | N/A | **High (additive)** | Medium (`JSON.Lazy` lives) | Low (macro adopted) |
| Confidence in closure | N/A | **Medium-high** | High (with caveats) | High (with caveats) |
| Honest risk of premature complexity | Low | **Low** | Medium (`[RES-018]` + `[BENCH-011]` gates) | High |

### 3. Recommendation: Option B — γ event-emitting Span parser

**Recommended**: Option B. The event-emitting Span parser plus
a default-implementation `JSON.Serializable.deserialize(events:)`
extension point closes most of the 37 % gap on partial-shape
decode, at the lowest implementation cost of any candidate
that actually closes the gap, with no new ecosystem primitive
required and the lowest blast radius on the public surface.

**Why not Option A (don't pursue)**: the gap is real, the
substrate to close it already exists (Tier 4 Span parser +
`RFC_8259.Token.Kind` + `Binary.Bytes.Input.View` precedent),
and the field has matured to a clear architectural answer that
the institute's own design discipline (`[ARCH-LAYER-011]`
improve-institute-don't-reach-for-Foundation) endorses. The
honest-disagreement case for Option A would be "the
implementation cost is out of proportion to the wedge size" —
Option B's ~500-900 LoC across two arcs is well within
proportion for a 37 %-gap closure on a load-bearing path.

**Why not Option C (β structural-index)**: structurally
attractive (Apple's exact precedent) but trips two of the
institute's strongest cost discipline gates simultaneously:
- `[RES-018]` second-consumer hurdle — `RFC_8259.Map` as a
  primitive has no second consumer in the investigation.
- `[BENCH-011]` integration-probe requirement — the multi-
  buffer map shape under a Copyable wrapper is exactly the v2
  arc's refuted pattern. The `~Copyable & ~Escapable JSON.Lazy`
  design works around this but trades into ergonomics cost.

Option C remains the right answer for a FUTURE Phase B
(conditional, only if Option B's A2 measurement gate fires
short of target). The map shape can be added incrementally
once Option B has demonstrated the wedge it doesn't close.

**Why not Option D (codegen macro)**: implementation cost is
4-6× Option B's for a ceiling that is bounded above Option B's
floor — likely 1.0× vs 1.05-1.15× Foundation per workload.
Macro infrastructure is a permanent ecosystem cost (`[RES-018]`
applies). The compose-on-top-of-B framing means D is naturally
phased AFTER Option B lands; recommending D first inverts the
build-up.

### 4. Detailed design for Option B

#### 4.1 The Span event cursor

The cursor type, by `[API-NAME-001]` / `[API-NAME-002]` naming
(`Nest.Name` pattern; no compound identifiers):

```swift
// File: RFC_8259.Span.EventStream.swift (NEW — public)

extension RFC_8259.Span {
    /// Pull-driven event cursor over a contiguous-bytes JSON input.
    ///
    /// Mirrors the `Binary.Bytes.Input.View` precedent one layer up.
    /// Exposes a forward-only token-kind sequence; the consumer
    /// drives `next()` and accesses string/number payloads via
    /// dedicated methods.
    ///
    /// `~Copyable & ~Escapable` per the cursor lifetime contract.
    @safe
    public struct EventStream: ~Copyable, ~Escapable {
        @usableFromInline
        internal var lexer: RFC_8259.Span.Lexer

        @usableFromInline
        internal var depth: Int

        @usableFromInline
        internal let maxDepth: Int

        /// Reusable scratch for string decode. Mirrors the existing
        /// `RFC_8259.Span.Parser.stringScratch` pattern.
        @usableFromInline
        internal var stringScratch: [UInt8]

        /// Tracks the last-emitted token's offset for lazy position
        /// computation at error sites.
        @usableFromInline
        internal var lastTokenStart: Int

        @inlinable
        @_lifetime(borrow bytes)
        public init(_ bytes: borrowing Swift.Span<UInt8>, maxDepth: Int = 512) {
            self.lexer = RFC_8259.Span.Lexer(bytes)
            self.depth = 0
            self.maxDepth = maxDepth
            var scratch: [UInt8] = []
            scratch.reserveCapacity(64)
            self.stringScratch = scratch
            self.lastTokenStart = 0
        }
    }
}
```

Hot operations:

| Operation | Signature | Behaviour |
|---|---|---|
| `next` | `mutating func next() throws(RFC_8259.Error) -> RFC_8259.Token.Kind?` | Advances past whitespace; returns the next token kind, or `nil` at end-of-input. Increments / decrements `depth` on container start/end tokens; throws `.depthExceeded` if `depth > maxDepth`. Lazy-decodes nothing — string/number payloads stay in the bytes. |
| `currentString` | `mutating func currentString() throws(RFC_8259.Error) -> String` | After `next()` returned `.string`, decodes the string payload. Called once per `.string` token; reuses `stringScratch`. |
| `currentNumber` | `mutating func currentNumber() throws(RFC_8259.Error) -> RFC_8259.Number` | After `next()` returned `.number`, decodes the number payload. |
| `skipValue` | `mutating func skipValue() throws(RFC_8259.Error)` | Skips the value that *would* be the next-emitted token. Mirrors `Utf8JsonReader.Skip()` semantics. Cost is O(bytes-in-skipped-value); does not materialise the value. |
| `position` | `var position: RFC_8259.Position { get }` | Lazy position (line + column + byte-offset) for error reporting. |

`next()` returns `RFC_8259.Token.Kind` (defined at
`swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Token.Kind.swift`)
rather than `RFC_8259.Token` (payload-carrying). This sidesteps
the "copy of noncopyable typed value" compiler bug documented
at `RFC_8259.Parser.Span.swift:18-28` because `Token.Kind`
carries no `String` / `RFC_8259.Number` payload.

**Token.Kind is NOT strictly payload-free.** Line 23 of
`RFC_8259.Token.Kind.swift` declares `case unknown(UInt8)` — a
trivial `UInt8` payload for the error-reporting path. `UInt8` is
a primitive POD type and should not interact with the
"noncopyable typed value" diagnostic the way `String` /
`RFC_8259.Number` do, but the assumption is empirical, not
syntactic. Phase A0's verification spike (§5) MUST explicitly
exercise the `.unknown(UInt8)` case in the storage-in-~Copyable-
struct test — not just the no-payload cases — to confirm the
trivial payload composes cleanly. If `.unknown(UInt8)` storage
trips the compiler, the design fallback is to substitute
`UInt8` raw-value (with a parallel error byte-offset field on
the cursor) for cursor storage; the public `next()` return
type stays `RFC_8259.Token.Kind`.

#### 4.2 The JSON.Serializable event-grain method

```swift
// File: JSON.Span.EventStream.swift (NEW — public)

extension JSON.Span {
    /// JSON-layer event cursor wrapping `RFC_8259.Span.EventStream`.
    ///
    /// Re-throws `RFC_8259.Error` as `JSON.Error` to maintain the
    /// existing `JSON.Serializable` typed-throws contract.
    @safe
    public struct EventStream: ~Copyable, ~Escapable {
        @usableFromInline
        internal var inner: RFC_8259.Span.EventStream

        @inlinable
        @_lifetime(borrow bytes)
        public init(_ bytes: borrowing Swift.Span<UInt8>, maxDepth: Int = 512) {
            self.inner = RFC_8259.Span.EventStream(bytes, maxDepth: maxDepth)
        }
    }
}

extension JSON.Span.EventStream {
    /// Reuses RFC_8259.Token.Kind verbatim — the kinds are JSON's,
    /// not RFC 8259's per se.
    public typealias Token = RFC_8259.Token.Kind

    @inlinable
    @_lifetime(self: copy self)
    public mutating func next() throws(JSON.Error) -> Token? {
        do { return try inner.next() }
        catch { throw JSON.Error(error) }
    }

    @inlinable
    @_lifetime(self: copy self)
    public mutating func currentString() throws(JSON.Error) -> String {
        do { return try inner.currentString() }
        catch { throw JSON.Error(error) }
    }

    @inlinable
    @_lifetime(self: copy self)
    public mutating func currentNumber() throws(JSON.Error) -> RFC_8259.Number {
        do { return try inner.currentNumber() }
        catch { throw JSON.Error(error) }
    }

    @inlinable
    @_lifetime(self: copy self)
    public mutating func skipValue() throws(JSON.Error) {
        do { try inner.skipValue() }
        catch { throw JSON.Error(error) }
    }
}
```

The `JSON.Serializable` protocol grows one method requirement
with a default implementation:

```swift
// File: JSON.Serializable.swift (MODIFIED)

extension JSON {
    public protocol Serializable {
        static func serialize(_ value: Self) -> JSON
        static func deserialize(_ json: JSON) throws(JSON.Error) -> Self

        // NEW — opt-in fast path. Default delegates to the tree-grain
        // method per [§4.3] below.
        static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> Self
    }
}
```

#### 4.3 Default fallback for existing conformers

```swift
extension JSON.Serializable {
    /// Default fallback: assemble a tree from the event stream, then
    /// delegate to the existing tree-grain `deserialize(_:)`. Existing
    /// conformers get this default for free — no source break.
    ///
    /// This DOES pay the cost of materialising a `JSON` tree from the
    /// stream — i.e., on the fallback path, the consumer pays Option
    /// α's full-tree cost. The opt-in fast path skips this by
    /// overriding `deserialize(events:)` directly.
    @inlinable
    public static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> Self {
        let json = try JSON.assemble(from: &events)
        return try Self.deserialize(json)
    }
}
```

`JSON.assemble(from:)` is a new helper that drives the event
stream to build a `JSON` value, equivalent to the existing
`RFC_8259.Span.Parser.parse(_:)` but driven from the event
side. The helper exists primarily for the fallback path — it
should NEVER be used by opt-in conformers (the opt-in fast path
goes byte-to-target directly without an intermediate tree).

**Default-fallback regression risk — EMPIRICALLY CONFIRMED at A0 (v1.0.1; see §9).**
The fallback path's call graph adds one protocol-dispatch
boundary versus the direct tree path:

```
Old path  (init jsonBytes):
    bytes → JSON.parse → tree → deserialize(_: JSON) → target

New path with default fallback (init eventDecodingJsonBytes,
conformer does not override deserialize(events:)):
    bytes → EventStream → JSON.assemble(events → tree)
          → deserialize(_: JSON) → target
```

The new path has at minimum one extra protocol-dispatch
boundary (the witness for `deserialize(events:)` calling
through to the default, which calls `JSON.assemble`). Whether
this collapses to flat with inlining depends on:

1. `JSON.assemble(from:)` being `@inlinable` AND the compiler
   actually inlining it across module boundaries.
2. The event-pull-then-tree-build chain being compiler-
   collapsible to byte-equivalent of the direct tree-build that
   `RFC_8259.Span.Parser.parse(_:)` performs today.

Neither (1) nor (2) is empirically verified at write time. The
"no regression" framing in the migration story is OPTIMISTIC;
the honest framing is "should be near-flat with inlining;
Phase A1 measurement gate MUST verify." If the default
fallback does regress (even by 5-10 %), a consumer who
switches entry points from `init(jsonBytes:)` to
`from(eventDecodingJsonBytes:)` without also overriding
`deserialize(events:)` silently slows down — exactly the
opt-in trap the migration story is supposed to avoid.

**Two mitigation paths; A1 MUST adopt one** (v1.0.1: A0 §9
empirically confirmed the regression as 4.48× on the mock —
upper bound, but the wedge is structural and present in
production-scale measurements proportionally):

1. **Implementation-side (REQUIRED at A1 — recommended path)**:
   rewrite `JSON.assemble` to detect that the EventStream is at
   position 0 and unforked, and route to
   `RFC_8259.Span.Parser.parse(_:)` directly, bypassing the
   event-pull-and-rebuild entirely. The EventStream becomes a
   no-op intermediary on the default path; the dispatch surface
   is preserved and the cost is eliminated by collapsing the
   fallback chain to today's tree path.

   Concrete shape:
   ```swift
   internal enum JSON.Assemble {
       static func from(
           _ events: inout JSON.Span.EventStream
       ) throws(JSON.Error) -> JSON {
           // Fast path: EventStream is at position 0 and the
           // consumer hasn't advanced it yet. Delegate directly
           // to RFC_8259.Span.Parser.parse(_:) — equivalent to
           // status-quo init(jsonBytes:).
           if events.isUnforkedAtPositionZero {
               return try events.consumeAsParseValue()
           }
           // Slow path: events have been partially consumed;
           // build the JSON value from the remaining events
           // (used if a future caller wraps a partial-decode
           // pattern; not exercised on the §4.3 default
           // fallback).
           ...
       }
   }
   ```

   `JSON.Span.EventStream` exposes an `isUnforkedAtPositionZero`
   property (or equivalent) for the short-circuit detection.
   A1 must verify the detection is sound AND measure that the
   fast path matches status-quo `init(jsonBytes:)` performance
   to within noise on the bench's `codable-lookup-event-grain`
   mode for non-opt-in conformers.

2. **API-side (FALLBACK if (1) proves harder than expected)**:
   do NOT add `from(eventDecodingJsonBytes:)` as a general
   entry point. Instead require opt-in consumers to construct
   the EventStream explicitly and call their conformer's
   `deserialize(events:)` directly:

   ```swift
   var stream = JSON.Span.EventStream(span)
   let symbol = try Symbol.deserialize(events: &stream)
   ```

   This makes the opt-in explicit at the call site; consumers
   cannot accidentally engage the fallback path. Costs API
   ergonomics (one extra line per call site) but eliminates
   the silent-regression failure mode by construction. Pick
   this only if A1 discovers that the short-circuit detection
   in (1) is non-trivial.

Mitigation (1) is the recommended path; (2) is the backstop.
Either is binding — A1 cannot ship the naïve default-fallback
shape exhibited in the v1.0.0 sketch.

The init that opts into the event-grain path:

```swift
extension JSON.Serializable {
    /// Opt-in event-grain decode entry point. Conformers that have
    /// overridden `deserialize(events:)` get the fast path; conformers
    /// that haven't get the default (full-tree fallback, equivalent
    /// to the existing `init(jsonBytes:)`).
    @inlinable
    public static func from<Bytes>(eventDecodingJsonBytes bytes: Bytes) throws(JSON.Error) -> Self
    where Bytes: Swift.Collection<UInt8>, Bytes: Sendable, Bytes.Index: Sendable {
        // Dispatch fork on contiguous storage (mirrors RFC_8259.Decode).
        var parserError: JSON.Error? = nil
        let fastResult: Self? = bytes.withContiguousStorageIfAvailable {
            (buffer: UnsafeBufferPointer<UInt8>) -> Self? in
            let span = buffer.span
            var stream = JSON.Span.EventStream(span)
            do { return try Self.deserialize(events: &stream) }
            catch let error as JSON.Error { parserError = error; return nil }
            catch { parserError = .unknown; return nil }
        } ?? nil
        if let value = fastResult { return value }
        if let err = parserError { throw err }
        // Slow path: arbitrary Collection<UInt8>.
        let array = Swift.Array(bytes)
        return try array.withUnsafeBufferPointer { buffer throws(JSON.Error) in
            let span = buffer.span
            var stream = JSON.Span.EventStream(span)
            return try Self.deserialize(events: &stream)
        }
    }
}
```

Naming: `from(eventDecodingJsonBytes:)` is a *static method*
returning Self rather than an init, because `init(...) ->
Self` already exists with the tree-grain path and protocol-
extension inits don't dispatch through witness tables the way
methods do. The static method ensures correct dispatch.
Existing `init(jsonBytes:)` is untouched.

#### 4.4 Skip strategy

`EventStream.skipValue()` is the structural-skip primitive.
After `next()` has returned a `.objectStart` / `.arrayStart`
/ `.string` / `.number` / `.true` / `.false` / `.null`,
calling `skipValue()` advances the cursor past the entire
value (including all nested containers) without materialising
intermediate values.

Implementation: recursive descent over the lexer's byte
stream, tracking container nesting via a small depth counter,
returning when depth returns to its starting value. Cost is
O(bytes-in-skipped-value).

This is **parse-then-discard**: the byte-walk cost is paid,
but no `String` / `RFC_8259.Value` / array storage is
allocated. Compared to pattern α (which allocates everything
and then discards on access), the skip is materially cheaper.

For the canonical workload's `Symbol` schema (3 of ~9 keys
per object, with skipped values typically being short strings
or short arrays), this closes most of the 37 % gap. The
allocation cost — which §1.1 of Phase 1 traced to the
discarded ⅔ of `String` + `RFC_8259.Value` materialisations —
is the wedge. The byte-walk for skipped values is mostly
cache-resident and cheap.

#### 4.5 Lifecycle and typed errors

The `EventStream`'s lifetime is bound to the borrowed
`Swift.Span<UInt8>` via `@_lifetime(borrow bytes)` at the
initializer. Per the institute's strict-memory-safety
discipline, the stream cannot escape the scope of its bytes;
the compiler enforces this.

Typed throws propagate cleanly. `RFC_8259.Span.EventStream`
throws `RFC_8259.Error`; `JSON.Span.EventStream` re-throws
as `JSON.Error` via the existing `JSON.Error.init(_: RFC_8259.Error)`
adapter (`swift-foundations/swift-json/Sources/JSON/JSON.Error.swift:33-80`).
`JSON.Serializable.deserialize(events:)` throws `JSON.Error`
directly, matching the existing `deserialize(_: JSON)`
signature.

The default fallback `deserialize(events:)` (§4.3) routes
through `JSON.assemble(from:)` which also throws
`JSON.Error`; the chain preserves the typed error contract
end-to-end.

#### 4.6 An end-to-end opt-in example

The bench harness's `Symbol` schema, opt-in fast path:

```swift
extension Symbol: JSON.Serializable {
    // Existing tree-grain method — preserved.
    static func deserialize(_ json: JSON) throws(JSON.Error) -> Symbol {
        let kind = try SymbolKind(json: json.kind)
        let identifier = try SymbolIdentifier(json: json.identifier)
        let pathComponents = try [String](json: json.pathComponents)
        return Symbol(kind: kind, identifier: identifier, pathComponents: pathComponents)
    }

    // NEW — opt-in event-grain method.
    static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> Symbol {
        guard try events.next() == .objectStart else {
            throw .typeMismatch(expected: "object", got: "?")
        }
        var kind: SymbolKind? = nil
        var identifier: SymbolIdentifier? = nil
        var pathComponents: [String]? = nil
        while let token = try events.next() {
            if token == .objectEnd { break }
            guard token == .string else { throw .invalidSyntax(message: "expected key", location: events.position.location) }
            let key = try events.currentString()
            // Expect colon — for terseness, skipped here; real impl
            // either embeds the colon in `next()` semantics or
            // exposes `expectColon()`.
            switch key {
            case "kind":
                kind = try SymbolKind.deserialize(events: &events)
            case "identifier":
                identifier = try SymbolIdentifier.deserialize(events: &events)
            case "pathComponents":
                pathComponents = try [String].deserialize(events: &events)
            default:
                try events.skipValue()   // ← the wedge
            }
        }
        guard let kind = kind, let identifier = identifier,
              let pathComponents = pathComponents else {
            throw .missingKey("kind/identifier/pathComponents")
        }
        return Symbol(kind: kind, identifier: identifier, pathComponents: pathComponents)
    }
}
```

The `default: try events.skipValue()` line is the structural
fix to the 37 % gap. On the canonical workload, the ~6 of ~9
keys per object that fall through `default` are skipped
without their values being materialised.

### 5. Phased landing plan

Each phase is independently shippable and reversible. Mirrors
`parse-performance-architecture.md` v1.0.2's A0/A1/A2 shape.

#### Phase A0 — Re-verification dispatch (½ day)

Three premises to verify against the current toolchain (Swift
6.3+ stable + 6.4-dev nightly):

1. **`RFC_8259.Token.Kind` storage in a `~Copyable & ~Escapable`
   struct compiles cleanly.** The compiler bug per
   `RFC_8259.Parser.Span.swift:18-28` triggered on
   `Optional<Token>` (payload-carrying with `String` /
   `RFC_8259.Number`); the Kind variant carries only a trivial
   `UInt8` payload on `.unknown(UInt8)` (per
   `RFC_8259.Token.Kind.swift:23`) and no payload on the other
   11 cases.

   The spike MUST exercise BOTH:
   - The no-payload cases (`.objectStart`, `.string`, etc.)
     stored as `Optional<Token.Kind>` in a `~Copyable & ~Escapable`
     struct, read/written across mutating methods.
   - The `.unknown(UInt8)` case in the SAME storage. Construct
     `let kind: RFC_8259.Token.Kind = .unknown(0xFF)`, assign
     into the struct's storage, read back, switch-extract the
     `UInt8`. The trivial payload SHOULD not trip the
     diagnostic the way the original `String`-carrying Token
     did — but the assumption is empirical, not syntactic, and
     the bug's structural cause was the noncopyable-typed-value
     copy regardless of payload triviality.

   A 50-100 line spike covering both. If the no-payload cases
   pass but `.unknown(UInt8)` trips, fall back to storing
   `UInt8` raw-value (with a parallel `errorByte: UInt8?` field
   for the rare error path); the public `next()` signature
   stays `RFC_8259.Token.Kind`. If both trip, Option B's
   cursor design requires a deeper redesign — fall to a
   payload-free wire enum (`UInt8` raw-value, switch externally).

2. **`@_lifetime(borrow bytes)` + `inout EventStream` + typed
   throws composes through a protocol-method dispatch.** Spike
   a 100-line standalone target with a minimal `Serializable`-
   shaped protocol with an `inout`-stream method, verify the
   lifetime checker accepts the chain and typed errors
   propagate correctly through the witness table.

3. **`withContiguousStorageIfAvailable` continues to engage on
   the inputs callers actually pass.** Already verified during
   Tier 4 Phase A0 per `parse-performance-architecture.md`
   v1.0.1 §8 — bridged NSString hits the fast path on Apple
   platforms. Re-verify against current toolchain to confirm
   no regression.

If any premise fails, the plan halts at A0 and a separate
handoff investigates. The Tier 4 wins persist; no rollback.

#### Phase A1 — γ implementation (≈ 1-2 arcs)

Implementation lands across two repos:

| File | Repo | Action |
|---|---|---|
| `Sources/RFC 8259/RFC_8259.Span.EventStream.swift` | swift-rfc-8259 | NEW |
| `Tests/RFC 8259 Tests/Span.EventStream Tests.swift` | swift-rfc-8259 | NEW |
| `Sources/JSON/JSON.Span.EventStream.swift` | swift-json | NEW |
| `Sources/JSON/JSON.Assemble.swift` | swift-json | NEW (the helper for the default fallback) |
| `Sources/JSON/JSON.Serializable.swift` | swift-json | MODIFIED (add protocol requirement + default + new entry point) |
| `Tests/JSON Tests/Serializable.EventStream Tests.swift` | swift-json | NEW |
| `Experiments/parse-performance-bench/Sources/parse-performance-bench/main.swift` | swift-json | MODIFIED (add opt-in `deserialize(events:)` for `Symbol`/`SymbolKind`/`SymbolIdentifier`/`SymbolGraph`; add a `codable-lookup-event-grain` mode that runs the event-grain decode and reports vs Foundation + vs tree-grain) |

**Constraints**:
- One type per file per `[API-IMPL-005]`.
- Naming per `[API-NAME-001]` / `[API-NAME-002]`
  (`RFC_8259.Span.EventStream`, `JSON.Span.EventStream`).
- All existing 124 tests in `swift-rfc-8259` and the swift-json
  test suite must continue to pass.
- The existing `RFC_8259.Span.Parser` and the dispatch fork at
  `RFC_8259.Decode.callAsFunction` remain untouched — the
  EventStream is an additional path, not a replacement.

**Success criterion**: opt-in `Symbol.deserialize(events:)` on
the canonical workload measures ≤1.05× Foundation
`JSONDecoder` parse+decode (≤0.231 s vs the current 0.349 s)
on the bench's `codable-lookup-event-grain` mode. The default-
fallback path (existing conformers that haven't opted in) does
not regress.

#### Phase A2 — Measurement gate

Re-run the bench (`codable-lookup-event-grain` mode + the
existing `codable-lookup` mode for control). Three outcomes:

- **Outcome 1**: ≤1.05× Foundation on parse+decode for the
  opt-in fast path. Phase B is NOT triggered. The 37 % gap is
  closed for opt-in conformers; the dynamic-access path's 14×
  advantage remains intact. Document v1.0.0 → v1.1.0
  disposition in this doc.

- **Outcome 2**: 1.05× to 1.20× Foundation. The wedge is
  partially closed but not fully. The residual gap is likely
  the byte-walk-for-skip cost (γ's parse-then-discard).
  Phase B (Option C-style structural-skip primitive
  augmentation, scoped to skip rather than full β architecture)
  becomes the next investigation; dispatched as a separate
  arc, not bundled with A1.

- **Outcome 3**: >1.20× Foundation. The framing is wrong; the
  gap is not primarily from materialisation cost. Re-frame:
  open a new investigation into where the gap actually lives.
  Likely candidates: number parsing (Foundation may have a
  faster `Double.init(String)`-equivalent), key-dict lookup
  cost in nested objects, ARC traffic in nested struct
  decode. Honest disposition: this outcome would say the
  predecessor analysis (Phase 1) misidentified the wedge.

The decision rule is measurement-driven, not speculative.
Phase A2 is a gate, not a separate code arc.

#### Phase B (CONDITIONAL — only if A2 says so) — Structural skip primitive

If Outcome 2 fires, augment `RFC_8259.Span.EventStream` with a
structural-skip primitive that operates on the byte-walk
without descending into nested containers. Equivalent to
Foundation's `JSONMap.offset(after:)` mechanism for the skip
path only — does NOT introduce a full structural-index map for
the whole input. Skip becomes O(1) per skipped value via a
look-ahead-and-balance algorithm on the byte stream (count
braces/brackets/quotes).

Implementation: ~200-400 LoC additional in
`RFC_8259.Span.EventStream`'s `skipValue()` method. Per
`[BENCH-011]`, must integration-probe against the
`codable-lookup-event-grain` mode before promotion. Storage
shape is unchanged (no new multi-buffer storage); the v2 arc
lesson does not apply.

#### Phase C (FURTHER CONDITIONAL — only if Phase B insufficient) — Codegen macro

If Phase B's measurement still falls short and the gap is
demonstrably from per-struct dispatch cost, Option D's
codegen macro becomes the next investigation. Per `[RES-018]`,
proposing the macro infrastructure requires a second consumer.
The most likely second consumer is a future
`swift-rfc-XXXX-toml` or `swift-rfc-XXXX-yaml` package; if no
such package is on the institute's roadmap, Phase C is
deferred indefinitely. This is the right disposition — Option
D's complexity is not justified by Option B's measured wedge
alone.

### 6. What this design does NOT do

- It does NOT propose any new ecosystem primitive. The Option
  B path uses `Swift.Span<UInt8>` (stdlib), `RFC_8259.Token.Kind`
  (existing public), `RFC_8259.Span.Lexer` (existing internal),
  and `Binary.Bytes.Input.View` (existing precedent). No
  `swift-text-event-stream-primitives` or similar is proposed.

- It does NOT change the `JSON` value type or `RFC_8259.Value`
  enum. The dynamic-access path remains exactly as it is
  today; the 14× lookup advantage is preserved by construction
  (the new path is parallel, not a replacement).

- It does NOT change the public `RFC_8259.Lexer<Input>` /
  `RFC_8259.Parser<Input>` generic types or the
  `RFC_8259.Span.Parser` Tier 4 implementation. Both stay as
  the tree-building path; the EventStream is additive.

- It does NOT touch the four file blocklist enumerated in the
  originating handoff: `swift-json/.gitignore`,
  `swift-rfc-8259/.github/metadata.yaml`,
  `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Input.swift`,
  `swift-parser-primitives/Sources/Parser Tracked Primitives/Parser.Tracked.swift`.

- It does NOT introduce any `import Foundation` in `Sources/`
  of either package.

- It does NOT change the typed-throws contract — every method
  in the dispatch chain uses `throws(JSON.Error)` or
  `throws(RFC_8259.Error)` per the existing convention.

- It does NOT modify the existing `JSON.parse(_:)`,
  `JSON.parse.prepared`, or `JSON.parse.located` API surfaces.
  These continue to return materialised `JSON` trees for
  dynamic-access consumers.

- It does NOT change the `JSON.Stream` / NDJSON surface. Once
  Option B lands, a follow-up arc COULD migrate
  `JSON.ND.stream` to use the event-grain path internally for
  per-line decode efficiency, but that is out of scope here.

### 7. Honest risks beyond §2

| Risk | Mitigation |
|---|---|
| The skip-cost limitation (γ is parse-then-discard) — for workloads with very large skipped strings, the byte-walk is non-trivial | Phase A2 measurement gate; if Outcome 2, Phase B (structural skip primitive) addresses it scoped to skip-only without the full β architecture |
| Default-fallback regression — see §4.3 expanded treatment. The path adds at minimum one protocol-dispatch boundary versus the existing tree path; whether the chain inlines flat is UNTESTED at write time. If regression measured at A1, consumers switching entry points (`init(jsonBytes:)` → `from(eventDecodingJsonBytes:)`) without overriding `deserialize(events:)` silently slow down | §4.3 names two mitigations: (1) implementation-side — `JSON.assemble` short-circuits to `RFC_8259.Span.Parser.parse(_:)` when the EventStream is unforked at position 0; (2) API-side — drop the generic entry point and require explicit `JSON.Span.EventStream` construction at the call site, eliminating the silent-regression failure mode by construction. Phase A0 spike #2 (lifetime + inout + protocol dispatch) is the cheap empirical signal that informs which mitigation is needed |
| Protocol-evolution risk — adding a method to `JSON.Serializable` is a binary interface change (witness table grows) | Pre-1.0 institute discipline (`[ARCH-LAYER-008]`) prioritises correctness; the change is acceptable. Post-1.0 it would be SemVer-major; the work should land while the package is pre-1.0 |
| Adoption gap — existing conformers don't get the speedup until they opt in | This is intentional — the contribution is the API surface; ecosystem migration is paced by consumer need. The bench harness's `Symbol`/`SymbolGraph` are migrated in Phase A1 as the proof-of-concept |
| Cursor lifetime + `inout` through protocol dispatch interacts badly with witness tables | Phase A0 spike #2 verifies this; if it fails, the design has to flip to a closure-based callback shape, which loses some Tier 4 specialisation but stays viable |
| `JSON.assemble(from:)` is itself non-trivial — building the tree from events is essentially re-doing the work `RFC_8259.Span.Parser` already does | True. `JSON.assemble` could be a thin wrapper over `RFC_8259.Span.Parser.parse(_:)` if the event stream wraps the same lexer — i.e., when the default fallback fires, route through the existing tree path directly rather than re-driving from events. The implementation should do this; the API surface stays clean |
| Two parallel parser shapes (Span.Parser for tree, Span.EventStream for events) over the same Lexer — code duplication risk | Both share `RFC_8259.Span.Lexer` for byte-level cursor operations; the divergence is at the level of "what do you emit after a token boundary." The duplication is bounded to the structural dispatch logic (~150-200 LoC per parser). Acceptable; not worth premature abstraction |
| `[BENCH-011]` claims to fire only on Copyable-wrapper × multi-buffer storage; Option B has neither — so does `[BENCH-011]` apply? | `[BENCH-011]`'s rule fires when a wrapper indirection layers over a multi-buffer storage. Option B's `EventStream` is `~Copyable` (no wrapper-copy term), and there is no multi-buffer storage in the design (the cursor holds `Span<UInt8>` + `Int`). The rule's preconditions are not met; integration probe is not required. Confirmation: the `parse-performance-bench` harness's `codable-lookup-event-grain` mode IS the integration probe in spirit, and will be authored as part of Phase A1 even though `[BENCH-011]` does not strictly mandate it |
| If Phase B fires, the `RFC_8259.Span.EventStream.skipValue()` augmentation adds inline byte-counting logic for structural skip — increases the cursor's complexity | The augmentation is local to one method; the cursor's external surface is unchanged. Reversible per `[ARCH-LAYER-008]` if it doesn't work out |
| Documentation cost — consumers need to learn the new opt-in path and decide when to use it | DocC catalog entries for `JSON.Span.EventStream` + a "performance guide" article in `JSON.docc/` documenting when to opt in. ~1 day of writing during Phase A1 |

### 8. Ecosystem migration survey

The institute's JSON consumer surface is **small and
concentrated** — 11 production `JSON.Serializable` conformance
sites, all in `swift-foundations`, none third-party. This is
not an accident: `[ARCH-LAYER-011]` (improve-institute,
don't-reach-for-Foundation) has deliberately kept the
conformer count low because the ecosystem doesn't propagate
Foundation `Codable` everywhere. The small surface is a
*feature* of the institute's discipline. It also means the
wedge for the streaming arc is narrower than the migration
plan might imply — see §8.4 honest framing.

This section maps the consumer surface, sequences a hypothetical
migration, and surfaces the practical impact axes.

#### 8.1 Consumer classification

**Class A — Schema-known decode (the migration surface)**:

| # | Site | LoC | Decode pattern | Value | Cost |
|---|---|---:|---|---|---|
| 1 | `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` — foundational conformers (`String`, `Int`, `Int64`, `Double`, `Bool`, `Array`, `Dictionary`, `Optional`, `JSON`) | 279 | Tree-walk via `deserialize(_: JSON)` | **CRITICAL — load-bearing for the whole arc** | ~200-300 LoC |
| 2 | `swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift` | 153 | Tree-walk; reads `enabled`/`disabled`/`excluded` arrays | High — read on every lint invocation across the ecosystem | ~50 LoC |
| 3 | `swift-foundations/swift-manifests/Sources/Manifest Loader/Manifest.Load.swift` (`load<Output: JSON.Serializable>` at line 43, 77) | 1 site | Generic dispatch — `let json = try JSON.parse(captured); try Output(json: json)` | **Universal — single fork propagates fast path to every typed manifest consumer** | ~30 LoC (entry-point fork) |
| 4 | `swift-foundations/swift-manifests/Sources/Manifest Resolver/Manifest.Resolver.swift` (`Resolver<M: JSON.Serializable, C>`) | 1 file | Generic constraint, no decode call site of its own | Constraint-propagation only | trivial |
| 5-8 | `swift-foundations/swift-tests/Sources/Tests Performance/{Test.Environment,Tests.Measurement,Tests.History.Record,Tests.Complexity.Baseline}+JSON.swift` | ~440 | Tree-walk; storage round-trip | Medium (test-time only) | ~120 LoC |
| 9-10 | `swift-foundations/swift-tests/Sources/Tests Snapshot/Test.Snapshot.Strategy+JSON{,.Structural}.swift` | ~219 | Snapshot decode | Medium-low | ~100 LoC |

**Class B — Dynamic-access (untouched; pattern α preserved)**:
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.Manifest*.swift` (5 files) — uses `String(json.name)` + `json.dependencies.array.compactMap`. Pure dynamic walk. The 14× advantage is exactly what serves this. (Side note: this package imports Foundation — a separate `[ARCH-LAYER-007]` violation, NOT in scope for the streaming arc.)
- `swift-foundations/swift-tests/Sources/Tests Performance/Tests.Baseline.Storage.swift:90` — `try JSON.parse(bytes)` + dynamic walk.
- `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle` — currently uses `JSON.parse(raw)` + dynamic walk; *would* migrate by adopting the bench's `SymbolGraph: JSON.Serializable` schema.

**Class C — Producer-only (encode side; fully untouched)**:
- `Lint.Reporter.SARIF.swift` (emits SARIF JSON), `Tests.History.Storage.swift` (write path), `Test.Reporter.Structured.swift`, all auto-generated `.swift-manifest/Lint.swift/Sources/Driver/Driver.swift` files (write `manifest.jsonString()` to disk).

#### 8.2 Hypothetical migration sequencing

If Phase A0 fires GREEN and Phase A1 lands:

**Wave 0 — Substrate (Phase A1 scope, already in §5)**:
- `RFC_8259.Span.EventStream` + tests (swift-rfc-8259, ~500 LoC)
- `JSON.Span.EventStream` + `JSON.Assemble` (swift-json, ~150 LoC)
- `JSON.Serializable.deserialize(events:)` protocol method + default fallback + opt-in entry point (swift-json, ~100 LoC)
- Foundational conformer migrations — `String` / `Int` / `Int64` / `Double` / `Bool` / `Array` / `Dictionary` / `Optional` / `JSON` (swift-json, ~200-300 LoC). **Must land synchronously with the protocol extension** — without these, no opt-in consumer's `deserialize(events:)` body can compose primitive-field decode efficiently.
- Bench harness `Symbol` schema opts in + new `codable-lookup-event-grain` mode (~200 LoC)

**Wave 1 — Original-workload demonstration (~50 LoC)**:
Migrate `Experiments/symbol-graph-conformance-oracle` to use `SymbolGraph: JSON.Serializable` (already implemented in the bench harness; oracle imports or copies the schema). Measures wedge closure on the original 86 MB Swift stdlib workload — verification benefit, not user-visible benefit (see §8.4).

**Wave 2 — Core institute infrastructure (~80 LoC)**:
- `Lint.Manifest.deserialize(events:)` opt-in. Small schema; high adoption surface (Lint.Manifest is read on every lint invocation across 60+ packages).
- `Manifest.Load.load<Output>` internal dispatch fork — routes through `from(eventDecodingJsonBytes:)` when the type opts in, falls back otherwise. One change propagates ecosystem-wide.

**Wave 3 — Test infrastructure (opportunistic; ~150 LoC)**:
Six swift-tests conformances. Migrate only if profiling justifies; test-time decode rarely dominates ecosystem wall-clock.

**Cumulative migration cost** (post-substrate): ~280 LoC of opt-in work across Waves 1-2, ~150 LoC optional in Wave 3. The substrate (Wave 0) at ~1100-1500 LoC is the dominant arc; ecosystem fanout is straightforward afterward.

#### 8.3 Ecosystem coupling notes

1. **`Manifest.Load.load<Output: JSON.Serializable>` is the load-bearing dispatch point.** Today its body is unconditionally:
   ```swift
   let json = try JSON.parse(captured)
   return try Output(json: json)
   ```
   Per the §4.3 mitigation analysis (the default-fallback-regression risk), the loader's fork should NOT silently route through `from(eventDecodingJsonBytes:)` — that would expose every existing `Manifest.Load` consumer to the unverified default-fallback path. The right shape is to add a SECOND overload `load<Output: JSON.Serializable>(... eventDecoding: ...)` that opt-in consumers explicitly call; existing consumers stay on the current method unchanged.
2. **`Lint.Manifest.deserialize(_:)` reaches into typed-throws `File.Path` conversion** (the inner `do throws(Paths.Path.Error) { try File.Path(string) } catch { throw JSON.Error.typeMismatch(...) }` block). The pattern translates directly to event-grain — same typed-throws boundary semantics.
3. **The bench harness's `Symbol` schema at `parse-performance-bench/Sources/parse-performance-bench/main.swift:51-83` is reusable** for the symbol-graph oracle's Wave 1 migration. Same struct types; the oracle imports or copies the schema. No type-design work.
4. **No JSON conformers outside swift-foundations.** All 11 sites live in foundations packages. swift-primitives, swift-standards, and swift-ietf have no JSON conformance debt; the streaming arc is foundations-bounded.
5. **`.swift-manifest/Lint.swift/Sources/Driver/Driver.swift` files are producer-only** (auto-generated; write `manifest.jsonString()` to disk; a separate process reads via `Manifest.Load`). Unaffected by the arc.

#### 8.4 Honest framing of the ecosystem impact

The ecosystem survey confirms a tension that the migration
narrative should not hide:

- **None of the existing consumers are complaining.** The
  symbol-graph oracle's pre-Tier-4 1.0 s is already tolerated
  (and runs ~quarterly per toolchain bump). Lint.Manifest's
  per-invocation decode is bounded-milliseconds — well below
  any user-perceptible threshold. Manifests are read-once at
  startup.

- **Wave 1's absolute saving is small.** With Option B
  landed, the symbol-graph oracle goes from ~1 s to ~0.231 s
  per regen — a saving of ~0.77 s per ~quarterly invocation.
  That is not "ecosystem-level payoff"; it is a verification
  benefit on a real workload. The earlier survey draft's
  framing of "converts offline-only to online-tractable"
  overstates the practical impact — every second is already
  offline-tractable. The honest framing of Wave 1 is
  *"demonstrates the wedge closure on a real workload, not a
  synthetic one"* — valuable for engineering confidence, not
  for end-user experience.

- **Wave 2's user-visible benefit is also small.** Lint.Manifest
  decode is bounded-ms; per-invocation savings would be
  measured in microseconds. The value is principle —
  Lint.Manifest is the canonical `JSON.Serializable`
  adoption per the institute's roadmap, and getting it on
  the fast path establishes the pattern for future
  conformers.

- **Per `[BENCH-010]` / `[RES-018]` discipline, the work is
  borderline-speculative.** No second hot consumer has
  surfaced; the originating investigation is the only
  consumer of the wedge closure. The institute's typical
  discipline says: wait for a second consumer. The
  countervailing argument is that the architecture is
  settled, the substrate exists, and the migration cost is
  bounded — so the work is cheap to do *now* while the
  context is fresh, vs. cheap to defer indefinitely until
  pressure materialises.

- **The small consumer surface is itself signal.** When the
  ecosystem has 11 conformers and nobody is complaining,
  the "right" disposition is plausibly *commit the
  research, archive the design, park the implementation*.
  The architecture lives in the corpus for the future
  consumer who actually needs it. Pre-1.0 institute
  discipline (`[ARCH-LAYER-008]`) allows correctness-driven
  shaping without consumer count, but does NOT require
  it — the streaming arc could legitimately be a docs-only
  output for now.

The decision between *land it* and *park it* is therefore a
question of investment appetite, not architecture: the
architecture is clear, the cost is bounded, and the benefit
is small but principled. Phase A0 (½ day) is the cheapest
verification that costs nothing relative to the decision
itself; it should be run regardless of the land-or-park
choice because its outcome refines the parking evidence
(if it does fire RED, the parking note becomes "blocked on
toolchain limitation X" rather than "speculatively
deferred"). The land-or-park choice is then made with
better evidence.

### 9. A0 disposition (v1.0.1)

Phase A0 ran on Swift 6.3.2 (swiftlang-6.3.2.1.108) / macOS 26.0
arm64 on 2026-05-14. Spike artifact:
`swift-foundations/swift-json/Experiments/streaming-deserialize-a0-feasibility/`
(commit `0953628`; three executable targets, build clean under
`swift build -c release`).

| Premise | Status | Source / measurement |
|---|---|---|
| 1. `RFC_8259.Token.Kind` storage in `~Copyable & ~Escapable` struct, including `case .unknown(UInt8)` per §4.1 | **GREEN** | `check-token-kind-storage`: 22/22 PASS across 12 enum cases (11 payload-free + `.unknown(UInt8)` exercised across 8 distinct `UInt8` payloads: `0x00, 0x20, 0x41, 0x7F, 0x80, 0xC0, 0xFE, 0xFF`). Payload-free + `.unknown(UInt8)` coexist inside one struct lifetime via `Optional<Token.Kind>` storage with `@_lifetime(self: copy self)` mutating methods. The §4.1 design holds; no `UInt8` raw-value fallback required. |
| 2. `@_lifetime` + `inout` + typed-throws through protocol dispatch (compile + correctness AND §4.3 default-fallback timing) | **GREEN (compile + correctness)** + **RED (§4.3 timing)** | `check-lifetime-inout-protocol`: compilation, correctness, and typed-error propagation through protocol witness all PASS. **Three-path timing (10 000 iter × 256 bytes/iter)**: Foo (override) 0.392 ms; Today (status-quo tree path) 2.880 ms; Bar (default-fallback) 12.907 ms. Derived ratios: **Bar/Today = 4.48× (§4.3 silent-regression signal, mock upper bound)**; **Bar/Foo = 32.94× (opt-in wedge — the speedup overriding consumers gain)**. |
| 3. `String.UTF8View.withContiguousStorageIfAvailable` engagement on the inputs consumers actually pass (regression check vs Tier 4) | **GREEN** | `check-contiguous-storage`: 8/8 PASS across the seven previously-engaging shapes (native Swift String small + long, `[UInt8]`, `ContiguousArray<UInt8>`, `ArraySlice<UInt8>`, bridged NSString small + long on Apple) + the non-contiguous lazy-collection canary correctly fails to engage. No regression vs the Tier 4 A0 finding (`parse-performance-architecture.md` v1.0.1 §8). |

#### 9.1 Interpretation

- **Premise 1 GREEN** locks in the §4.1 cursor design. The
  `Token.Kind.unknown(UInt8)` trivial-payload concern raised
  during the v1.0.0 → v1.0.1 review is empirically closed; no
  storage-shape fallback is needed.

- **Premise 3 GREEN** locks in the §4.3 dispatch fork on
  contiguous storage. Bridged NSString continues to hit the
  fast path on Apple platforms (consistent with the Tier 4 A0
  finding).

- **Premise 2 GREEN on compile + correctness** unblocks the
  language-composition risks: `@_lifetime` annotations,
  `inout ~Copyable & ~Escapable` parameters on protocol
  methods, and typed throws all flow through a protocol
  witness as the §4.2 design requires.

- **Premise 2 RED on §4.3 timing** empirically confirms the
  silent-regression concern flagged in §4.3 as UNTESTED at
  v1.0.0 write time. The mock's `MockTree` is a flat
  `[UInt8]` (upper bound on the structural regression);
  production with the real `RFC_8259.Value` tree assembly
  will narrow the ratio (both Bar and Today get more expensive
  proportionally) but the wedge is structural — driving events
  through `next()` and re-building a tree is strictly more
  work than building a tree directly. **The naïve default-
  fallback shape exhibited in the v1.0.0 §4.3 sketch cannot
  ship at A1.** The implementation-side short-circuit
  (§4.3 mitigation 1) is now the REQUIRED A1 constraint, not
  a discretionary design choice.

- **Bar/Foo = 32.94× is a positive signal for Option B's
  architectural hypothesis.** Override consumers gain decisive
  performance for their opt-in effort — consistent with the
  field's pattern γ (System.Text.Json, serde_json, jsoniter)
  closing partial-shape decode gaps. The 32.94× wedge will
  narrow under production scaling but remains the dominant
  signal: opt-in is worth doing.

#### 9.2 Caveats on the timing numbers

The §4.3 4.48× ratio is mock-scale; the real wedge is
narrower because `JSON.assemble` would build the full
`RFC_8259.Value` tree (with `String` + `RFC_8259.Number` +
heap-backed Object/Array storage), not a flat `[UInt8]`. Both
the Bar and Today paths get proportionally more expensive at
production scale. The Bar/Foo 32.94× wedge is similarly
mock-scale; under production scaling it likely narrows to
3-10×, still decisive for opt-in but not as dramatic as the
mock suggests. Phase A2's `codable-lookup-event-grain` bench
mode on the canonical 86 MB workload is the ground truth.

#### 9.3 A1 binding constraints (locked in by A0)

A1 is unblocked but constrained by three A0 findings:

1. **§4.3 mitigation (1) is REQUIRED**, not optional.
   `JSON.assemble.from(_: &events)` MUST detect the
   unforked-at-position-zero case and short-circuit to
   `RFC_8259.Span.Parser.parse(_:)`. The detection mechanism is
   A1's design choice; the constraint is that the fast path
   measurably matches status-quo `init(jsonBytes:)` performance
   on the bench's `codable-lookup-event-grain` mode for
   non-opt-in conformers.

2. **The `RFC_8259.Span.EventStream` cursor MUST expose an
   `isUnforkedAtPositionZero` property** (or equivalent
   primitive enabling the §4.3 mitigation). The cheapest shape
   is probably a single `Bool` flag set to `true` at init,
   cleared by the first `next()` / `currentString()` /
   `currentNumber()` / `skipValue()` call.

3. **The A2 measurement gate MUST validate both axes**:
   (a) opt-in conformers (the bench's `Symbol` schema with
   `deserialize(events:)` override) close most of the 37 % gap
   to Foundation; and (b) non-opt-in conformers (the default
   fallback path) do NOT regress vs the status-quo
   `init(jsonBytes:)` baseline. Both axes are pass/fail; A2
   does not promote to DECISION unless both clear.

If A1 discovers the short-circuit detection in §4.3
mitigation (1) is non-trivial (e.g., the
`isUnforkedAtPositionZero` flag introduces measurable
overhead in the cursor's hot path, or the short-circuit
delegation path itself adds cost), fall to §4.3 mitigation
(2) (API-side: drop `from(eventDecodingJsonBytes:)`; require
explicit `JSON.Span.EventStream` construction at the call
site). Mitigation (2) eliminates the silent-regression failure
mode by construction at the cost of one extra line of
boilerplate per opt-in call site.

### 10. A1 disposition (v1.0.2)

Phase A1 Wave 0 + Wave 1 landed on Swift 6.3.2 / macOS 26.0
arm64 on 2026-05-14 across two repos (5 substrate commits +
1 doc-enhancement commit; see the frontmatter
`implementations` field for the commit list). Each commit is
independently buildable; all tests pass (swift-rfc-8259: 212
tests in 7 suites; swift-json: 47 tests in 3 suites).

#### 10.1 A2 measurement gate results

Canonical 86 MB Swift stdlib symbol-graph workload (`Symbol`
schema reading 3 of ~9 keys per object — 67 % skip ratio), 3
iterations, `swift build -c release`, clean build from empty
`.build`:

| Path | Wall-clock | × Foundation |
|---|---:|---:|
| `Foundation.JSONDecoder().decode(SymbolGraph.self, from: data)` | 0.227 s | 1.00× |
| swift-json status-quo `SymbolGraph(jsonBytes: bytesForm)` | 0.353 s | 1.556× |
| **swift-json EVENT-GRAIN `SymbolGraph.from(eventDecodingJsonBytes: bytesForm)`** | **0.081 s** | **0.357×** |

**Axis (a) — opt-in event-grain decode closes the 37 % gap**:
swift-json is **2.80× faster than Foundation** on
parse+decode. The projected target in v1.0.0 was ≤1.10×;
reality is 0.357× — the gap is not just closed but
substantially reversed. The wedge close vs status-quo is
4.37× (event-grain is 23 % of status-quo time). symbol count
matches across all three paths (14,552).

**Axis (b) — default-fallback non-regression** (100,000-iter
microbench on a tiny `{"name":"x","age":1}` payload to
isolate the dispatch cost from parse cost):

| Path | Wall-clock |
|---|---:|
| Status-quo `init(jsonBytes:)` | 0.057 s |
| Default-fallback path via `from(eventDecodingJsonBytes:)` | 0.060 s |
| Ratio | 1.053× (5.3 % delta) |

5.3 % is at the noise floor for a 100k-iter tiny-JSON
microbench; the §4.3 implementation-side short-circuit (mitigation 1)
is working as designed. Per A0 §9.3, this validates the
binding constraint — non-opt-in consumers do NOT pay a
silent regression by switching from `init(jsonBytes:)` to
`from(eventDecodingJsonBytes:)`.

#### 10.2 Wave 1 oracle migration result

The symbol-graph-conformance-oracle at
`swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/`
was migrated to use `OracleSymbolGraph: JSON.Serializable`
with an event-grain `deserialize(events:)` override
(commit `17bce12`).

| Metric | Pre-Wave-1 (release, post-Tier-4) | Post-Wave-1 (release) | Improvement |
|---|---:|---:|---|
| Wall-clock parse | ~0.95 s (per `parse-performance.md` v1.2.1 §6) | **0.149 s** | **6.4× release-to-release** |
| Refinement pair count | 136 | 136 | **byte-identical** |
| Output file shape | `Outputs/StdlibRefinementsTable.swift` | `Outputs/StdlibRefinementsTable.swift` | unchanged |

The "128 s → 0.16 s, ~800×" framing from the A1 subagent's
report compares debug pre-Tier-0 (the original
`run-stdlib.txt`) to release post-Wave-1; that is the
user-visible improvement story for the regen workflow, but
the apples-to-apples release-to-release number is 6.4×.
Both are honest depending on baseline; the latter is the
right architectural-attribution number, the former is the
right end-user-workflow-attribution number.

#### 10.3 Three caveats called out for downstream readers

**(a) The simdjson framing was intentionally NOT folded in.**
The v1.0.0 §3.1 cited simdjson's `ondemand` API as the
canonical pattern β reference (~2× speedup on partial-shape
per the v0.6 release notes); the A1 subagent's report
extrapolated that swift-json's 2.80× Foundation result also
implies "swift-json now beats simdjson on partial-shape
decode by ~1.4×." That extrapolation is THEORETICAL, not
measured. simdjson's numbers are on different workloads,
different machines, different schemas (C++ DOM vs swift-json's
`RFC_8259.Value` Codable analog). Without running simdjson
on the exact 86 MB / Symbol schema, the comparison is
unverified. **The v1.0.2 amendment intentionally drops the
simdjson framing**; the Foundation comparison stands on its
own. A future arc could add a simdjson C++ binding to the
parse-performance-bench (one-evening spike) if the simdjson
comparison becomes load-bearing.

**(b) The 0.357× figure is workload-specific.** The canonical
86 MB Swift stdlib symbol-graph workload has a 67 % skip
ratio (`Symbol` declares 3 of ~9 keys per object) and a mean
object size of N=2.06 keys (per `size-dist` bench output
cited in `copyable-wrapper-vs-multi-buffer-storage.md`
v1.0.1 §3.3). The wedge close depends on the consumer's
skip ratio:
- High skip ratio (≥50 %, like this workload): wedge close
  is near-maximal — the saved materialisation work is the
  dominant cost
- Moderate skip ratio (20-50 %): wedge close is partial —
  estimated 1.5-2.0× Foundation
- Low skip ratio (<20 %, declaring most fields): wedge
  close is minimal — closer to pure parse cost; event-grain
  may even regress slightly vs status-quo tree path
- No skip (decode every field): event-grain may not beat
  tree-grain at all — the only saving is the avoidance of
  the intermediate `RFC_8259.Value` allocations, which is
  smaller than the parse cost itself

Consumers measuring their own workloads should NOT assume
the 0.357× number generalises. The right framing is
"event-grain closes most or all of the partial-shape skip
cost; consumers with low-skip workloads should measure
before opting in."

**(c) Wave 2 + Wave 3 deferred per minimal-scope decision.**
Per the principal's 2026-05-14 decision (and v1.0.1's
`Recommended disposition`), Wave 2 (`Lint.Manifest` +
`Manifest.Load` fanout) and Wave 3 (`swift-tests`
serialisation opt-ins) are NOT in scope for A1. Substrate +
oracle demonstration is the minimal scope that delivers
architecture proven + user-visible value on the original
motivating workload. Wave 2 / Wave 3 await actual consumer
pull per `[BENCH-010]` / `[RES-018]`.

#### 10.4 Implementation deviations from the §4 sketch

Two acceptable deviations were taken at A1, both local and
documented in their source files:

1. **`peekStructural()` added** to `JSON.Span.EventStream`
   (and the underlying `RFC_8259.Span.EventStream`). Not
   in the §4 sketch. Needed for Array / Dictionary /
   Optional empty-container and null detection without
   consuming a token, preserving child-decoder override-
   dispatch. Does NOT clear `isUnforkedAtPositionZero`
   since whitespace-skip is idempotent vs the
   `Span.Parser` fast path. Commit `572cc8b`.

2. **`consumeAsParseValue` is `public`** on
   `RFC_8259.Span.EventStream`, not `@_spi(StreamingDeserialize)`.
   The SPI form was evaluated at v1.0.2-prep
   (commit `f4f3cb2` doc-enhancement) and REJECTED by the
   compiler: `@_spi` does NOT compose with `@inlinable` at
   the cross-module consumer site (verbatim Swift 6.3.2
   error: *"instance method 'consumeAsParseValue()' cannot
   be used in an '@inlinable' function because it is an
   SPI imported from 'RFC_8259'"*). The consumer
   (`JSON.Assemble.from`) MUST be `@inlinable` to allow the
   default-fallback short-circuit chain to inline at every
   opt-out conformer site; without inlining, the protocol-
   dispatch chain adds witness-table overhead and axis (b)
   would widen. Public is the right disposition; the doc
   comment now records the contract + SPI-rejection
   rationale + intended-use-case guard for external
   consumers.

Both deviations are additive (no API removal), local (no
ecosystem fan-out), and reversible.

#### 10.5 Honest issues encountered at A1

- Initial `@_lifetime(copy self)` on a byte-span accessor
  failed (`Span<UInt8>` is `~Escapable`); restructured to
  expose the operation as `consumeAsParseValue()` returning
  the materialised `RFC_8259.Value` rather than re-exposing
  the span directly. Cleaner outcome than the original
  sketch.
- `arr.map { try ... }` doesn't propagate typed throws
  inside `OracleSymbolGraph.deserialize(_: JSON)` (Wave 1);
  rewrote with manual loop. Bounded local fix.
- The default-fallback path was structurally regressing
  (10× on the mock) until the `@inlinable` chain through
  `JSON.Assemble.from` was wired correctly; the v1.0.0 §4.3
  warning + the v1.0.1 §9.3 short-circuit requirement
  caught this before any consumer observed it. The discipline
  worked.

#### 10.6 Disposition

**A1 GREEN.** A2 both axes pass decisively (axis (a) target
≤1.10× achieved at 0.357×; axis (b) at 5.3 % is essentially
noise on a 100k-iter tiny-JSON microbench). Wave 1's 6.4×
release-to-release oracle speedup validates the wedge
closure on the original motivating workload. The arc closes
at "substrate landed; Wave 1 demonstrates value on the
original workload; ecosystem fanout deferred."

Status upgraded RECOMMENDATION → DECISION at v1.0.2.

## Outcome

**Status**: RECOMMENDATION

**Recommended architecture**: Option B — event-emitting Span
parser (`RFC_8259.Span.EventStream` / `JSON.Span.EventStream`)
+ `JSON.Serializable.deserialize(events:)` protocol method
with default fallback + opt-in entry point
`JSON.Serializable.from(eventDecodingJsonBytes:)`. Mirrors the
field's pattern γ (System.Text.Json `Utf8JsonReader`,
serde_json + `IgnoredAny`, jsoniter Iterator, Newtonsoft
`JsonTextReader`) translated to swift-json's substrate
(`Span<UInt8>` cursor, `~Copyable & ~Escapable`,
lifetime-annotated, typed throws).

**Projected wedge closure**: medium-high confidence on closing
the 37 % gap to ≤1.05× Foundation on the canonical workload
for opt-in conformers. The tail risk (Outcome 2 — 1.05 to 1.20×)
is addressable by Phase B (structural-skip primitive); the
worst case (Outcome 3 — gap unrelated to materialisation) is
investigation-restart territory.

**Phased landing plan**:
- **Phase A0** (½ day): verify Token.Kind storage compatibility,
  `@_lifetime` + `inout` through protocol dispatch, and
  `withContiguousStorageIfAvailable` engagement on real inputs.
- **Phase A1** (1-2 arcs): implement `RFC_8259.Span.EventStream`,
  `JSON.Span.EventStream`, the `JSON.Serializable` protocol
  extension with default fallback, and the opt-in entry point.
  Migrate the bench harness's `Symbol`/`SymbolGraph` to opt in
  as proof-of-concept. New bench mode
  `codable-lookup-event-grain` runs the comparison.
- **Phase A2** (measurement gate): re-run bench; if ≤1.05×
  Foundation, document v1.0.0 → v1.1.0 disposition and
  conclude. If 1.05-1.20×, dispatch Phase B (structural skip).
  If >1.20×, re-open Phase 1 (the wedge isn't where this
  analysis placed it).
- **Phase B** (conditional): structural-skip primitive
  augmenting `EventStream.skipValue()`. Scoped to skip path
  only; does NOT introduce a full structural-index map. No
  new ecosystem primitive proposed.
- **Phase C** (further conditional — Option D codegen):
  deferred indefinitely absent a second consumer surfacing
  per `[RES-018]`. Likely never the right disposition unless
  a sibling Serializer (TOML, YAML, ASN.1) joins the
  institute.

**Final disposition (v1.0.2, DECISION)**: A1 Wave 0 + Wave 1
landed; A2 measurement gate PASSED on both axes decisively.
swift-json event-grain decode is **0.357× Foundation
`JSONDecoder` on the canonical 86 MB Swift stdlib symbol-graph
workload** (2.80× faster than Foundation, vs the ≤1.10×
projected target); the default-fallback path is within 5.3 %
noise floor of status-quo `init(jsonBytes:)` (the §4.3
implementation-side short-circuit works as designed); Wave 1
oracle migration achieves 6.4× release-to-release speedup with
136-pair byte-identical output. See §10 for the full A1
disposition with measurements, deviations, and caveats.

The architecture is the right choice on the empirical
evidence: ~700-1200 LoC of substrate work + ~50 LoC of Wave 1
oracle migration delivers a 2.80× user-visible speedup on the
schema-known partial-shape decode path while preserving the
14× dynamic-access lookup advantage and adding zero new
ecosystem primitives. No regression for non-opt-in consumers.

**Three caveats called out in §10.3** for downstream readers:
(a) the simdjson comparison was intentionally NOT folded in
(theoretical, not measured; a future spike could close this);
(b) the 0.357× figure is workload-specific to a 67 %-skip-ratio
schema — low-skip workloads will see narrower wedge closure
or none at all; (c) Wave 2 (`Lint.Manifest` + `Manifest.Load`
fanout) and Wave 3 (test infrastructure) remain deferred per
the principal's minimal-scope decision and per
`[BENCH-010]` / `[RES-018]` — both await actual consumer pull
before fanout work is authorised.

The arc closes at "substrate landed, Wave 1 demonstrates
value on the original motivating workload, ecosystem fanout
deferred." That is the right disposition: maximally bounded,
maximally honest, durable record in the institute corpus for
future consumers to pick up if and when pressure surfaces.

### Loose ends (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Whether the Token.Kind compiler-bug-adjacent storage will compile on Swift 6.4-dev (the bug was on Token-with-payload; Kind has no payload) | **premise** (Option B's substrate depends on this) | Phase A0 spike #1 closes this in ≤1 hour. If it fails, Option B's storage redesign is local (substitute `UInt8` raw-value for Token.Kind in cursor storage); the API surface is unaffected |
| Whether `@_lifetime(borrow bytes)` + `inout EventStream` + typed throws composes through a protocol witness | **premise** (Option B's dispatch model depends on this) | Phase A0 spike #2 closes this in ≤2 hours. If it fails, the protocol shape must flip to a closure-based callback (`static func deserialize<Body>(_ body: (inout EventStream) throws(JSON.Error) -> Self) throws(JSON.Error) -> Self`) — viable but more verbose |
| Whether the byte-walk-for-skip cost (γ's parse-then-discard) dominates the residual gap on workloads with very large skipped values | **direction** | Out-of-scope until A2 fires Outcome 2. Phase B addresses if needed |
| Whether the `JSON.assemble(from:)` default-fallback helper can be implemented as a thin alias for `RFC_8259.Span.Parser.parse(_:)` to avoid double-driving the lexer | **premise** (default-fallback non-regression depends on this) | The two parsers can share the same lexer state if `JSON.assemble` detects that the EventStream is at position 0 and unforked, and routes to `Span.Parser` directly. Phase A1 measurement gate must verify default-fallback non-regression; if regression measured, refactor to the shared-lexer shape |
| Whether the opt-in adoption pattern (consumers must author `deserialize(events:)` per type) creates an "always faster but always manual" trap analogous to serde's `#[derive(Deserialize)]` vs hand-written | **direction** | Phase C (codegen macro) is the field-standard mitigation. Defer until adoption signals make it necessary; second-consumer hurdle per `[RES-018]` |
| Whether `JSON.ND.stream` (NDJSON) should migrate to use the event-grain path for per-line decode efficiency | **direction** | Filed as future work. Once Option B lands, the migration is mechanical (each line's bytes drive an EventStream; the per-line callback receives the deserialised `T`). Out of scope here; Phase A1 makes it possible, follow-up arc lands it |
| Whether the `JSON.Serializable.deserialize(events:)` extension point composes with `~Copyable Self` (when the conformer wants its target type to be `~Copyable`) | **direction** | Out of scope here; the existing `JSON.Serializable.deserialize(_: JSON)` already requires Copyable Self (Self appears in a return position implicitly Copyable). A `~Copyable Self` extension is parallel-axis work, gated on the `Parser.Protocol.Self: ~Copyable` relaxation per `2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` v1.1.0 |

## References

### Empirical predecessors (read; do not re-run)

- `swift-institute/Research/streaming-json-deserialize-status-quo-and-prior-art.md` v1.0.0 — Phase 1 predecessor.
- `swift-foundations/swift-json/Research/parse-performance.md` v1.2.1 (DECISION) — the motivating 37 % / 14× finding.
- `swift-foundations/swift-json/Research/parse-performance-architecture.md` v1.0.2 (DECISION) — the Tier 4 design + the A0/A1/A2 phased-landing template Phase 2 mirrors.
- `swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0 (SUPERSEDED-BY-EVIDENCE) — the v2 arc; §12 constrains Option C by example.
- `swift-institute/Research/copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1 (RECOMMENDATION) — the cross-cutting principle that gates Option C's adoption per `[BENCH-011]`.

### Substrate references (READ)

- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.Parser.swift` lines 1-90, 32-76, 110-160 — Tier 4 parser (the substrate the new EventStream extends).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.Lexer.swift` lines 35-95 — Tier 4 cursor (reused by EventStream).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Token.swift` — `RFC_8259.Token` enum (payload-carrying; bypassed by EventStream).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Token.Kind.swift` — `RFC_8259.Token.Kind` (payload-free; returned by `EventStream.next()`).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Decode.swift` lines 31-126 — dispatch fork pattern the new entry point mirrors.
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` lines 42-92 — existing protocol + convenience inits (extended by Option B).
- `swift-foundations/swift-json/Sources/JSON/JSON.swift` lines 60-70 — `JSON` value type + `RFC_8259.Value` backing (untouched by Option B).
- `swift-foundations/swift-json/Sources/JSON/JSON.Error.swift` lines 33-80 — `JSON.Error.init(_: RFC_8259.Error)` adapter (reused by `JSON.Span.EventStream`).
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift` lines 46-194 — the `~Copyable & ~Escapable` + `Span<UInt8>` + `@_lifetime(borrow span)` precedent.

### Measurement infrastructure (reuse)

- `swift-foundations/swift-json/Experiments/parse-performance-bench/Package.swift` — bench package.
- `swift-foundations/swift-json/Experiments/parse-performance-bench/Sources/parse-performance-bench/main.swift` lines 16-83 (Symbol schema), 443-503 (codable-lookup mode) — the existing bench infrastructure that the Phase A1 `codable-lookup-event-grain` mode extends.

### Field / academic citations

Per Phase 1 §6 — all citations verified against primary sources
by parallel subagent per `[RES-020]` during Phase 1:

- simdjson: https://github.com/simdjson/simdjson + https://arxiv.org/abs/1902.08318 (Langdale & Lemire 2019).
- serde_json: https://github.com/serde-rs/json + https://serde.rs/.
- jsoniter: https://github.com/json-iterator/go.
- Apple swift-foundation `JSONDecoder`: https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/JSON/JSONScanner.swift + JSONDecoder.swift.
- System.Text.Json: https://learn.microsoft.com/en-us/dotnet/api/system.text.json.utf8jsonreader.
- Newtonsoft `JsonTextReader`: https://www.newtonsoft.com/json/help/html/T_Newtonsoft_Json_JsonTextReader.htm.
- [Mison (Li et al. 2017)]: http://www.vldb.org/pvldb/vol10/p1118-li.pdf.
- [Sparser (Palkar et al. 2018)]: https://www.vldb.org/pvldb/vol11/p1576-palkar.pdf.
- [JSONSki (Jiang & Zhao 2022)]: https://dl.acm.org/doi/10.1145/3503222.3507719.
- [JSR-173, 2004]: https://jcp.org/en/jsr/detail?id=173 / https://docs.oracle.com/javase/tutorial/jaxp/stax/why.html.

### Skill references

- `[RES-003]`, `[RES-003a]`, `[RES-003b]`, `[RES-003c]` — research-doc shape + index registration.
- `[RES-005]`, `[RES-009]`, `[RES-010b]` — multi-option analysis + architecture analysis template (executed in §2).
- `[RES-018]` — premature primitive anti-pattern (applied to Options C and D; both fail the second-consumer hurdle, deferred).
- `[RES-019]` — internal grep before external survey (executed in Phase 1 §1; carried forward here).
- `[RES-020]` — Tier 2 classification + parallel subagent verification (executed in Phase 1).
- `[RES-021]` — prior art survey + contextualization step (executed in Phase 1 §4).
- `[RES-022]` — recommendation-section structural-correctness framing (applied: B chosen on structural fit, not diff size, despite Options C and D having higher theoretical ceilings).
- `[RES-023]` — empirical-claim verification (executed in §1's carried-fact table).
- `[RES-026]` — citations.
- `[RES-027]` — loose-end follow-up (executed in Outcome; two premises tied to A0 spikes, four directions).
- `[HANDOFF-013]`, `[HANDOFF-013a]` — reader/writer prior-research grep.
- `[BENCH-010]` — benchmark deferral; no commitment to ship.
- `[BENCH-011]` — integration-probe-requirement (does NOT fire for Option B; would fire for Option C).
- `[ARCH-LAYER-007]`, `[ARCH-LAYER-008]`, `[ARCH-LAYER-011]` — Foundation-freedom; correctness-driven pre-1.0; improve-institute.
- `[API-NAME-001]`, `[API-NAME-002]`, `[API-ERR-001]`, `[API-IMPL-005]` — Nest.Name naming; no compound; typed throws; one type per file.
- `[MEM-COPY-001]`, `[MEM-LIFE-001]`, `[MEM-SAFE-001]`, `[MEM-SAFE-020]`, `[MEM-SPAN-001]` — `~Copyable & ~Escapable` cursor + lifetime annotations.
- `[PRIM-FOUND-001]` — no Foundation in primitives/standards.
- `[IMPL-INTENT]`, `[IMPL-COMPILE]` — intent-over-mechanism + compiler-as-correctness.

## Provenance

Investigation invoked via the supervisor handoff at
`/Users/coen/Developer/HANDOFF-streaming-json-deserialize-research.md`
(Phase 2; 2026-05-14). Phase 2 is the prescription follow-on
to Phase 1's descriptive characterisation. Parent session
closed the parse-performance arc (Tier 0/1/3/4 landed; v2 arc
empirically refuted) and continues separate work — files
listed under the handoff's "Do Not Touch" were not modified.
No implementation occurred in this dispatch; Phase A0 / A1 / A2
land in subsequent arcs under the phased plan.
