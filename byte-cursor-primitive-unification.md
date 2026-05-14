# Byte-Cursor Primitive Unification (`Span<UInt8>`)

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

The ecosystem currently contains **two parallel `~Copyable & ~Escapable` byte-cursor implementations** over `Swift.Span<UInt8>`:

| Primitive | Package | Layer | Purpose |
|-----------|---------|-------|---------|
| `Binary.Bytes.Input.View` | `swift-binary-parser-primitives` | L1 primitives | Binary-format parsing |
| `Lexer.Scanner` | `swift-lexer-primitives` | L1 primitives | Text-format lexing |

Both share substantively identical structure: `let bytes: Swift.Span<UInt8>` (or equivalent), `var position` cursor, `@_lifetime(borrow source)`-annotated init, peek/advance API, `@safe`-attributed. The Scanner additionally integrates `Text.Location.Tracker` for O(1) line:column tracking — a text-domain capability the binary cursor doesn't need.

Surfaced as out-of-scope observation in `swift-institute/Audits/streaming-deserialize-placement-audit.md` (2026-05-14, Phase 2 §Out-of-Scope) during the placement audit of the streaming-JSON-deserialize arc. Ticket T-1 of that audit chose to compose `RFC_8259.Span.Lexer` with `Lexer.Scanner` (correct for the text domain), but the deeper question of whether the byte-cursor pattern itself should be a single generic L1 primitive — with `Lexer.Scanner` and `Binary.Bytes.Input.View` as composed text/binary specialisations on top — is gated by `[DS-020]` (second-consumer rule for new ecosystem primitives) and was not addressed in that arc.

## Question

Should the institute extract a single generic `~Copyable & ~Escapable` byte-cursor-over-`Swift.Span<UInt8>` primitive — likely at L1 in a new or existing primitives package — that both `Binary.Bytes.Input.View` and `Lexer.Scanner` ride on top of?

Equivalently: under what conditions does the cost of maintaining two parallel cursor implementations exceed the cost of one generalised primitive plus two domain-specific specialisations?

## Status

**Reclassified 2026-05-14 under the [RES-018] amendment.** Under the four-case framing in research-process SKILL.md (2026-05-14), this arc is **case (a) — Cross-cutting primitive (Memory/Storage/Buffer/Collection grade, intended for re-use across unrelated domains)**. Binary parsing and text lexing are explicitly distinct domains; the proposal targets a substrate that would be shared across both.

The case (a) gate is **composition check + cross-domain fit check**, not a raw consumer count. Triage against the new gate:

- **Cross-domain fit**: prima facie satisfied. `Binary.Bytes.Input.View` (binary parsing — endian concerns, structural reads) and `Lexer.Scanner` (text lexing — `Text.Location.Tracker` integration) are unrelated domains with already-existing parallel implementations. The unified primitive's audience is exactly the cross-domain audience case (a) tests for.
- **Composition check**: NOT yet performed. The substrate-shared core (cursor scaffolding minus domain features) must be enumerated against the two existing consumers, and an explicit composition shape proposed (generic-Element / protocol-shaped / composition-adapter). This is the substantive remaining gate under case (a), inheriting from the v1.0.0 "Phase 1 — Comparative shape analysis" below.
- **`[DS-020]` second-consumer rule** (companion to [RES-018]; substance unchanged per the 2026-05-14 amendment notice): the surface count of two consumers exists. The institute's "demonstrated reuse-without-domain-knowledge" discipline is the same shape as case (a)'s composition check.
- **`[BENCH-011]` integration-probe rule**: any unification arc must measure both binary and text consumers post-unification to verify no regression in either domain.

The v1.0.0 [RES-018] "generalisation discipline" citation is dropped — under the amendment, [RES-018] does not gate this arc independently of the case (a) classification.

**Status**: DEFERRED — gated on the composition check (Phase 1 below). The second-consumer hurdle as a *blocking* concern is retired; remaining gates are technical (shape, cost-benefit, integration probe).

## Likely follow-on arc shape

When this is revisited:

1. **Phase 1 — Comparative shape analysis.** Read `Binary.Bytes.Input.View.swift` and `Lexer.Scanner.swift` in detail; identify the substrate-shared core vs the domain-specific overlays. Enumerate at least 3 candidate unification shapes (e.g., generic-Element cursor with concrete Element=UInt8; protocol-shaped cursor with two conforming structs; new primitive with composition adapters in each consumer).
2. **Phase 2 — Cost/benefit analysis.** Migration cost for each consumer + cost of the new primitive + maintenance benefit of unification. Apply `[BENCH-011]` integration-probe requirement.
3. **Phase 3 — Recommendation.** If the composition check (Phase 1) and cost-benefit (Phase 2) both favour unification, propose the consolidation arc. Otherwise document the duplication as accepted — the case (a) gate doesn't mandate unification, only requires that the analysis is genuine when one is proposed.

## Out of scope for this note

- The actual unification design — that's the Phase 1 work of a future arc.
- Whether `Lexer.Scanner` and `Binary.Bytes.Input.View` are themselves correctly placed in their respective packages — they are (text vs binary domain separation is clean).
- The JSON-serialization cohesion question (`JSON.Serializable` vs `Coder.Codable`) — separately tracked in the placement audit's Ticket T-3 (different question, different `[RES-018]` gate).

## References

- `swift-institute/Audits/streaming-deserialize-placement-audit.md` (2026-05-14) — Phase 2 out-of-scope observation that surfaced this question.
- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift` — text-domain cursor.
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift` — binary-domain cursor.
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Location.Tracker.swift` — text-domain capability the binary cursor doesn't have.

## Provenance

Surfaced during the streaming-JSON-deserialize Phase 2 audit (2026-05-14) as out-of-scope ecosystem observation. Recorded here as a durable parking lot so the question doesn't get lost the next time a binary parser or text lexer touches `Swift.Span<UInt8>`. Parent session has confirmed this will be the subject of a separate future research arc.

**v1.1.0 reclassification 2026-05-14**: the [RES-018] amendment (same date) introduced a four-case classification for primitive-extraction proposals. This arc fits case (a) — cross-cutting primitive intended for re-use across unrelated domains. The v1.0.0 [RES-018] citation as a generalisation discipline is dropped; [DS-020] remains operative as the companion second-consumer rule (substance unchanged per the amendment notice). The cross-domain fit appears satisfied prima facie; the composition check is the substantive remaining gate.
