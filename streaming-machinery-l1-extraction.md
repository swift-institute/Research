# Streaming-Parser Machinery — L1 Extraction

<!--
---
version: 1.0.0
last_updated: 2026-05-14
status: DEFERRED
tier: 2
scope: ecosystem-wide
---
-->

## Context

The placement audit (`swift-institute/Audits/streaming-deserialize-placement-audit.md`, 2026-05-14) dispositioned `JSON.Assemble` as a re-home from L3 (`swift-json`) to L2 (`swift-rfc-8259`), and left `RFC_8259.Span.EventStream` in place at L2. During the subsequent T-1 + T-2 implementation session, the principal raised that **the audit's framing under-classified the placement question** — both `RFC_8259.Span.Assemble` and `RFC_8259.Span.EventStream` are **generic streaming-parser machinery**, not RFC-8259-specific spec content. Under a stricter reading of `[ARCH-LAYER-*]` (each package solely concerned with its domain), neither should live at L2.

What `swift-rfc-8259` *should* contain (RFC 8259 specification implementation):

- `RFC_8259.Value` — the JSON data model (RFC 8259 §3)
- `RFC_8259.Object` / `RFC_8259.Array` / `RFC_8259.Number` / `RFC_8259.Position` — the spec's data types
- `RFC_8259.Error` and its `Expected` enum — diagnostics framed in spec vocabulary
- `RFC_8259.Lexer<Input>` / `RFC_8259.Parser<Input>` (generic) and `RFC_8259.Span.Parser` (Span-specialised) — translate bytes to spec values
- `RFC_8259.Encode` / `RFC_8259.Decode` — public entry points

What is generic streaming machinery, *not* spec content (currently misplaced at L2):

- `RFC_8259.Span.EventStream` — pull-driven cursor pattern over a Span lexer, with depth tracking, `skipValue()` structural skip, and `consumeAsParseValue()` short-circuit. None of these are RFC-8259-specific; the pattern composes over any structural format (JSON, XML, YAML, TOML, CBOR, MessagePack).
- `RFC_8259.Span.Assemble` — event-to-tree assembler with FAST/SLOW paths. The pattern is also generic (build any tree from a token stream + a value-construction strategy).

The lifecycle features (`~Copyable & ~Escapable`, depth tracking, structural skip) are format-agnostic; only the lexer beneath the cursor + the value type being assembled are format-specific.

## Question

Should the institute extract a generic streaming-parser machinery primitive — `EventStream` + `Assemble` patterns — to a new (or existing) L1 primitives package, with `swift-rfc-8259` becoming a thin RFC-8259-specific specialisation?

Equivalently: under what conditions does the cost of keeping the streaming machinery in `swift-rfc-8259` (where it conflates spec-implementation with generic infrastructure) exceed the cost of extracting it to L1 (where it can be reused by future structural-format packages)?

## Status

**DEFERRED.** Not blocking any current arc. Surfaced for future inventory awareness:

- **`[RES-018]` second-consumer hurdle**: swift-rfc-8259 is the only structural-format-with-streaming-deserialize consumer today. swift-xml exists but uses a different parser architecture (DOM-shaped, not event-stream); swift-yaml and swift-toml are L3 consumers, not L2 streaming-parser implementations. Until a second L2 structural-format package adopts an event-stream pattern, the L1 extraction lacks the demonstrated reuse that `[RES-018]` requires.
- **Orthogonal to the performance regression** raised at the same session: the +25% event-grain wedge on the T-1 + T-2 landing is a cross-module inlining / Tracker integration concern, not a placement concern. Extracting the machinery to L1 would *add* a module boundary, not remove one — it would make the inlining situation worse before it gets better. The performance fix must come first or be done concurrently with the extraction; doing the extraction speculatively while a performance regression is unresolved compounds the failure mode.
- **`[BENCH-010]` discipline**: extraction without consumer pull is exactly the speculative-architecture pattern the rule warns against. swift-rfc-8259 owning the machinery today is suboptimal but not broken; the cost of correctness-now exceeds the benefit until reuse is demonstrated.

## Likely follow-on arc shape

When this is revisited:

1. **Phase 1 — Second-consumer inventory.** Catalog structural-format consumers in the institute today and over the next 12 months. Candidates: swift-xml (if migrating from DOM to streaming), swift-yaml, swift-toml, swift-cbor (if any institute interest), swift-messagepack (if any interest), `swift-protobuf`-style wire-format parsers. Identify which (if any) would adopt an event-stream + tree-assembler pattern. If the inventory yields zero genuine second consumers, the arc halts here with disposition "extraction not justified."
2. **Phase 2 — Comparative shape analysis.** If Phase 1 yields a second consumer, enumerate the substrate-shared core of `RFC_8259.Span.EventStream` + `RFC_8259.Span.Assemble` vs the domain-specific overlays. Determine whether the shared core is genuinely format-agnostic or smuggles in JSON-specific assumptions (e.g., what does `skipValue()` look like in XML's tag-balanced grammar?).
3. **Phase 3 — Extraction design.** Propose the L1 package name + shape. Candidates: `swift-event-stream-primitives` standalone, OR absorption into `swift-parser-primitives` as a new submodule. Apply `[BENCH-011]` integration probe to both consumers before any migration arc fires.
4. **Phase 4 — Migration.** swift-rfc-8259's `Span.EventStream` + `Span.Assemble` become thin RFC-8259-specialisations of the L1 primitives. swift-json's wrapper stays thin (same shape, deeper substrate).

## Out of scope for this note

- The actual extraction design — Phase 2/3 work of a future arc.
- The performance regression diagnosed at the T-1 + T-2 implementation session (commits `b4ec277` + `1f4647e` + `90cba4c` + `0960da6`) — separately tracked; profile-first investigation in progress.
- The JSON-serialization cohesion question (`JSON.Serializable` vs `Coder.Codable`) — separately tracked in the placement audit's Ticket T-3 (different question, different `[RES-018]` gate; mentioned at `swift-institute/Audits/streaming-deserialize-placement-audit.md` §Phase 2 T-3).
- The byte-cursor primitive unification question — separately tracked at `swift-institute/Research/byte-cursor-primitive-unification.md` (DEFERRED).

## References

- `swift-institute/Audits/streaming-deserialize-placement-audit.md` (2026-05-14, commit `e8a06b7`) — placement audit that dispositioned T-2 as L2 re-home; the addendum here is the deeper question that surfaced post-audit.
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.EventStream.swift` — the EventStream living at L2 today.
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Span.Assemble.swift` — the Assemble living at L2 today (committed as T-2 at `90cba4c`).
- `swift-primitives/swift-parser-primitives/` — candidate absorption package for the L1 primitives if Phase 3 takes that shape.
- `swift-institute/Research/byte-cursor-primitive-unification.md` — sibling DEFERRED record; same shape of "ecosystem has parallel implementations / generic substrate plausible / second-consumer gate not yet clear."

## Provenance

Surfaced 2026-05-14 by principal during the T-1 + T-2 implementation session's Step 5 disposition discussion. The implementer's Step 5 report quoted the principal's framing verbatim ("swift-rfc-8259 should implement the RFC 8259 specification and nothing else…"). The principal's addendum offered three adjudication options (A: accept as landed; B: plan follow-up T-4; C: roll back T-1 + T-2 and re-plan); principal direction at session close was option A-equivalent — accept the current landing while recording the architectural observation as deferred research for future inventory awareness. Recorded here as a durable parking-lot so the question doesn't get lost on the next L2 streaming-format-parser addition.
