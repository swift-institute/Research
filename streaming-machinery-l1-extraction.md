# Streaming-Parser Machinery — L1 Extraction

<!--
---
version: 1.1.0
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

**Reclassified 2026-05-14 under the [RES-018] amendment.** This arc is now **case (c) — Layer-agnostic primitive surfaced inside an L2/L3 package** under the four-case framing in research-process SKILL.md (2026-05-14). Pull-down to L1 is the architecturally mandated default; swift-rfc-8259 IS the first consumer. The second-consumer hurdle that previously gated this arc (the v1.0.0 framing here) is no longer operative.

The arc therefore moves from "speculative-architecture deferral" to "scheduled pull-down gated on remaining technical concerns." Two gates persist before the extraction fires:

- **Performance-residual gate**: the +25% event-grain wedge on the T-1 + T-2 landing was profiled (`swift-institute/Audits/streaming-deserialize-regression-profile.md`, commit `de3e3c8`) and materially closed (~37%) by Options A+B (swift-lexer-primitives `3fbf66f` + swift-rfc-8259 `94c1616`). ~12 ms residual remains above pre-T-1 baseline, with no fire point identified for it in the profile. Extracting `EventStream` + `Assemble` to L1 *adds* a module boundary while an integration-shape cost is still unresolved — the failure mode the profile flagged. The extraction MUST be sequenced after the residual is dispositioned (either isolated and resolved, or accepted as known with rationale).
- **Phase 2 shape-analysis gate**: the comparative shape analysis below must classify which parts of `RFC_8259.Span.EventStream` + `RFC_8259.Span.Assemble` are genuinely format-agnostic vs which smuggle in JSON-specific assumptions (e.g., what does `skipValue()` look like in XML's tag-balanced grammar?). `[BENCH-011]` integration-probe applies post-extraction.

**Status**: DEFERRED — gated on performance-residual disposition + Phase 2 shape-analysis. The v1.0.0 second-consumer-hurdle framing is retired.

## Likely follow-on arc shape

Under case (c), Phase 1 of the v1.0.0 plan (second-consumer inventory) is no longer required — pull-down is the default. The revised plan:

1. **Phase 1 — Performance-residual disposition.** Resolve or accept the ~12 ms post-A+B residual flagged in `parse-performance.md` v1.3.0. Without this, adding the L1 module boundary risks compounding the unidentified integration-shape cost.
2. **Phase 2 — Comparative shape analysis.** Enumerate the substrate-shared core of `RFC_8259.Span.EventStream` + `RFC_8259.Span.Assemble` vs the JSON-specific overlays. Question: does `skipValue()` smuggle JSON assumptions (recursive nesting via `{` / `[` / `}` / `]`)? Does the depth-tracking discipline encode anything format-specific? Does the FAST/SLOW path split in `Assemble` rely on JSON-value-tree shape? Output: a "shared-vs-overlay" decomposition table.
3. **Phase 3 — Extraction design.** Propose the L1 package shape: standalone `swift-event-stream-primitives` vs absorption into `swift-parser-primitives` as a new submodule. Apply `[BENCH-011]` integration probe before migration.
4. **Phase 4 — Migration.** swift-rfc-8259's `Span.EventStream` + `Span.Assemble` become thin RFC-8259-specialisations of the L1 primitives. swift-json's wrapper stays thin (same shape, deeper substrate).

## Out of scope for this note

- The actual extraction design — Phase 2/3 work of a future arc.
- The performance regression diagnosed at the T-1 + T-2 implementation session (commits `b4ec277` + `1f4647e` + `90cba4c` + `0960da6`) — separately tracked. Profile committed at `swift-institute/Audits/streaming-deserialize-regression-profile.md` (`de3e3c8`); Options A+B landed (swift-lexer-primitives `3fbf66f` + swift-rfc-8259 `94c1616`); ~12 ms residual remains as a Phase 1 gate above.
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

**v1.1.0 reclassification 2026-05-14**: the [RES-018] amendment (same date) introduced a four-case classification for primitive-extraction proposals. This arc fits case (c) — layer-agnostic primitive surfacing inside an L2 package — where pull-down to L1 is the architecturally mandated default and the originating package counts as the first consumer. The v1.0.0 "second-consumer hurdle" framing is retired. The remaining gates are technical (performance residual, shape analysis), not policy (consumer-count threshold).
