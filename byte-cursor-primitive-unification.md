# Byte-Cursor Primitive Unification (`Span<UInt8>`)

<!--
---
version: 1.3.0
last_updated: 2026-05-17
status: IN_PROGRESS
tier: 2
scope: ecosystem-wide
---
-->

## Context

The ecosystem contains **two parallel `~Copyable & ~Escapable` byte-cursor implementations** over `Swift.Span<UInt8>`:

| Primitive | Package | Layer | Purpose |
|-----------|---------|-------|---------|
| `Binary.Bytes.Input.View` | `swift-binary-parser-primitives` | L1 primitives | Binary-format parsing |
| `Lexer.Scanner` | `swift-lexer-primitives` | L1 primitives | Text-format lexing |

Both share a `Span<UInt8>` + integer-offset model, `@_lifetime(borrow source)`-annotated init, peek/advance API, and `@safe` attribution.

Surfaced 2026-05-14 by the streaming-deserialize placement audit. v1.1.0 reclassified the question under the `[RES-018]` amendment as case (a) cross-cutting primitive with composition check pending. v1.2.0 (2026-05-17) executed the composition check as Wave 1 Item 1 of the byte-ecosystem finalization arc and landed a principled-refuse DECISION; principal review identified three structural gaps in v1.2.0's grounding (recorded under §"v1.3.0 — Corrections to v1.2.0 analysis" below). v1.3.0 re-executes Phase 1 with the corrected lenses and lands a RECOMMENDATION.

## Question

Should the institute extract a single generic `~Copyable & ~Escapable` Span<UInt8>-cursor primitive that both `Binary.Bytes.Input.View` and `Lexer.Scanner` ride on top of?

Equivalently under the first-principles decompose-compose-reuse framing: can the position-type discipline be aligned across both domains by decomposition, allowing a parameterized cursor primitive to host both consumers without compromise?

## v1.3.0 — Corrections to v1.2.0 analysis

Three principled gaps in v1.2.0's Phase 1/2/3 grounding, identified by principal review:

1. **[API-NAME-001c] was misapplied to Shape B.** `[API-NAME-001c]` (the byte-protocol-capability-marker resolution per `byte-protocol-capability-marker.md` v1.1.0) declined meta-protocols **over capability markers** — i.e., one Carrier-meta protocol with `Byte.Protocol`, `Char.Protocol`, `Word.Protocol`, … all conforming. The cursor question is structurally different: it is "should two near-identical implementations be ONE primitive?", not "should every cursor conform to one meta-protocol?". The [API-NAME-001c] precedent does not transfer. Shape B may still be wrong, but for principled reasons that need to be found (or dropped), not for the cited reason.

2. **Shape C evaluated the wrong parameterization axis.** v1.2.0's Shape C asked "parameterize over element type (UInt8)?" — but Element is fixed in both consumers; of course no cross-domain pressure exists on that axis. The interesting axis is POSITION-TYPE. Re-evaluation needs Shape C′ — parameterize over position type — where the demand IS exactly the two existing position-types.

3. **Position-type "load-bearing" needs the decomposition lens before it stands.** v1.2.0 called the Int vs Text.Position divergence load-bearing per-domain typing discipline without probing whether `Text.Position` decomposes into (a) a generic typed-offset primitive + (b) a text-domain overlay (line/column accounting). If yes, the cursor parameterizes over the typed-offset and both domains use it — decompose-compose-reuse applied directly to the alleged load-bearing divergence.

v1.3.0 re-executes Phase 1 with the corrected lenses. Findings 1–2 (substrate symmetry; Text.Location.Tracker as overlay; Item 1 ≠ Item 2 layer separation) survive independently and are retained.

## Analysis

### Phase 1 — Comparative shape analysis

Source files read at HEAD on 2026-05-17 (commits cited match HANDOFF.md):

- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift`
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input Primitives/Binary.Bytes.Input.swift`
- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift`
- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner+Lexing.swift`
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Position.swift`
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Count.swift`
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Offset.swift`
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Location.Tracker.swift`
- `swift-primitives/swift-byte-parser-primitives/Sources/Byte Parser Primitives/Byte.Input.swift`
- `swift-primitives/swift-index-primitives/Sources/Index Primitives Core/Index.swift`
- `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift`

#### Substrate-shared core

Both Span-cursors share the following mechanics, mechanically near-identical modulo naming (~50 LOC each, ~100 LOC total):

| Capability | `Binary.Bytes.Input.View` | `Lexer.Scanner` |
|-----------|---------------------------|-----------------|
| Type kind | `struct: ~Copyable, ~Escapable, @safe` | `struct: ~Copyable, ~Escapable, @safe` |
| Backing storage | `let span: Span<UInt8>` | `let source: Span<UInt8>` |
| Lifetime init | `@_lifetime(borrow span)` | `@_lifetime(borrow source)` |
| Sendable | Not Sendable | Not Sendable |
| End-of-input check | `isEmpty` | `isAtEnd` (via `!contains(cursor)`) |
| Peek current byte | `first` (Optional) | `peek()` (Optional) |
| Peek at offset | `subscript(offset:Int)` (preconditioned) | `peek(at: Text.Count)` (Optional) |
| Advance by 1 | `removeFirst() -> UInt8` (fused) | `advance() -> Void` + `consume() -> UInt8` (fused, separate methods) |
| Advance by N | `removeFirst(_ n: Int)` | `advance(by: Text.Count)` |

#### Decomposition probe (CORRECTION #3 from v1.3.0)

The probe asks: can `Text.Position` be decomposed into (a) a generic typed-offset primitive + (b) a text-domain overlay (line/column accounting)?

**Empirical answer: it already is.** Source-grounded:

```swift
// Text.Position.swift:27
public typealias Position = Tagged<Text, Ordinal>

// Text.Count.swift:22
public typealias Count = Tagged<Text, Cardinal>

// Text.Offset.swift:25
public typealias Offset = Tagged<Text, Affine.Discrete.Vector>
```

Text's position/count/offset family is *already* decomposed: they are typealiases over the generic typed-offset primitives (`Ordinal`, `Cardinal`, `Affine.Discrete.Vector`) in `swift-ordinal-primitives` / `swift-cardinal-primitives` / `swift-affine-primitives` respectively. `Text` is a phantom domain tag carrying no text-specific structural content — the text-domain content (line/column tracking) lives entirely in `Text.Location.Tracker` (which Phase 1 already identified as a composable overlay, not a structural constraint).

Symmetrically:

```swift
// Index.swift:38 (swift-index-primitives)
public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>
```

So `Index<Byte>` ≡ `Tagged<Byte, Ordinal>` — structurally identical in form to `Text.Position`, with `Byte` replacing `Text` as the phantom domain tag. The Binary-domain "byte position primitive" already exists under the `Index<Element>` name.

**Decomposition outcome**: the typed-byte-offset / typed-byte-count / typed-byte-vector substrate exists at L1 as the `Ordinal` / `Cardinal` / `Affine.Discrete.Vector` family. Both domains' position types decompose to the same generic shape `Tagged<DomainTag, Ordinal>`. The "load-bearing position-type divergence" claim from v1.2.0 does not survive this probe: the divergence is at the phantom-tag level (`Text` vs `Byte`), not at the structural-shape level. Phantom-tag divergence is exactly what type-domain-tagging exists to express WHILE sharing implementation.

**Binary's raw-Int position is the un-decomposed analog.** `Binary.Bytes.Input.View.position: Int` is implementation-historical, not principled — `Binary.Bytes.Input` (the owned/typed sibling at the Input.Protocol layer) already uses `Index<UInt8>` per `swift-binary-parser-primitives/Research/full-internal-typing-interpreter.md` (DECISION, 2026-01-29). The View's raw Int is an artifact of the Span<UInt8> boundary (per [IMPL-010] boundary-at-method conversion), parallel to Lexer.Scanner's own internal `Int(bitPattern: cursor)` at the Span boundary (Lexer.Scanner.swift:182-218). The principled decomposition for the View is `Index<Byte>` (≡ `Tagged<Byte, Ordinal>`), parallel to Text.Position (`Tagged<Text, Ordinal>`).

#### `~Copyable & ~Escapable` protocol ergonomics (CORRECTION #1 from v1.3.0)

v1.2.0 cited `[API-NAME-001c]` against Shape B (the protocol-shaped option). That citation does not transfer — `[API-NAME-001c]` declined meta-protocols over capability markers (one super-protocol with multiple per-domain capability markers conforming), not unification protocols over near-identical implementations. The Shape B question has to be re-evaluated on its own merits.

Empirical state of `~Copyable & ~Escapable` protocols in the ecosystem (grep-verified at HEAD on 2026-05-17):

| Protocol | Package |
|---|---|
| `Carrier.Protocol<Underlying>` | swift-carrier-primitives — foundational |
| `Sequence.Protocol<Element>` | swift-sequence-primitives |
| `Sequence.Iterator.Protocol<Element>` | swift-sequence-primitives |
| `Sequence.Borrowing.Protocol<Element>` | swift-sequence-primitives |
| `Equation.Protocol` | swift-equation-primitives |
| `Observation.Protocol` | swift-observation-primitives |
| `Ownership.Borrow.Protocol` | swift-ownership-primitives |
| `Path.Modification` | swift-path-primitives |
| `Path.Decomposition` | swift-path-primitives |

`~Copyable & ~Escapable` protocols are an established ecosystem pattern, not novel compiler territory. The swift-sequence-primitives DocC catalog (`Sequence-Protocol.md:17`) codifies the discipline: *"All three protocols declare `associatedtype Element: ~Copyable, ~Escapable`. The constraint flows through the entire chain: iterators are `~Copyable & ~Escapable`, closures over elements take `borrowing` parameters, and span-typed return values carry the lifetime of the iterator state."* Shape B's "novel territory" framing from v1.2.0 was wrong.

Shape B's principled blocker is therefore *not* compiler-novelty. The real question is: what does Shape B (protocol-shaped interface) provide that Shape C′ (struct-shared implementation) doesn't? See Phase 2.

#### Structural divergence between cursors

| Axis | `Binary.Bytes.Input.View` | `Lexer.Scanner` | Status under decomposition |
|---|---|---|---|
| Position type | `position: Int` (raw) | `cursor: Text.Position` (`Tagged<Text, Ordinal>`) | Both decompose to `Tagged<DomainTag, Ordinal>`; binary's raw Int is un-decomposed analog of `Index<Byte>` |
| Domain overlays | `starts(with:)`, `copyToOwned()` | `newline(at:)`, `location`, `location(at:)`, all of `Scanner+Lexing.swift` | Domain-specific overlays sit ABOVE the cursor primitive — not part of the substrate |
| Extra state | none | `tracker: Text.Location.Tracker`, `hasEmittedEndOfFile: Bool` | Tracker is composable overlay (see below); EOF flag is lexer-specific bookkeeping above the cursor primitive |

#### Text.Location.Tracker — composable overlay (retained from v1.2.0)

The principal's specific empirical question — *"is Lexer.Scanner's Text.Location.Tracker integration a composable overlay on a generic cursor, or a structural constraint that prevents Scanner from being one?"* — was answered in v1.2.0 and that finding survives v1.3.0's corrections. **Composable overlay.** Evidence from source (Lexer.Scanner.swift, Text.Location.Tracker.swift):

1. `Text.Location.Tracker` is a separate `Sendable, Equatable, Hashable` struct in swift-text-primitives, maintaining its own `(line, lineStart)` state independent of any cursor.
2. The Scanner's lower-layer cursor primitives (`peek`, `peek(at:)`, `advance`, `advance(by:)`, `consume`, `isAtEnd`) operate purely on `Text.Position + Span<UInt8>`; tracker is not involved.
3. `newline(at:)` is a public Scanner API (Lexer.Scanner.swift:154-172) precisely so external callers can drive the cursor at the primitive layer and update the tracker manually.
4. `location(at: Text.Position) -> Text.Location` (Lexer.Scanner.swift:90-101) bypasses the tracker entirely, re-scanning newlines through the source.
5. The Scanner's documentation at lines 84-89 contemplates parsers that "MAY skip per-newline `newline(at:)` updates entirely and pay this scan once per error site instead."

A unified `Cursor<DomainTag>` primitive WITHOUT `Text.Location.Tracker` can fully host Lexer.Scanner's cursor mechanics; the Scanner composes the tracker on top.

#### Item 1 vs Item 2 (D5) — different layers, do NOT collapse (retained from v1.2.0)

The Span-cursor layer (Item 1) and the Input.Protocol-conforming Copyable layer (Item 2) are structurally distinct:

| Layer | Members | Lifetime | Position |
|---|---|---|---|
| Span-cursor (Item 1) | `Binary.Bytes.Input.View`, `Lexer.Scanner` | `~Copyable & ~Escapable`, borrow-only | `Int` / `Text.Position` |
| Input.Protocol (Item 2/D5) | `Binary.Bytes.Input` (owned `[UInt8]` + `Index<UInt8>`), `Byte.Input` (= `Input.Slice<Array<UInt8>.Indexed<UInt8>>`) | Copyable, owned/sliced | `Index<UInt8>` and Input.Slice's indexing |

Lexer-primitives-scope.md D2 (2026-03-15) decided the Span-cursor layer does NOT couple to Input.Protocol. v1.3.0 confirms that layer-separation decision still holds. **Item 2 (D5) remains a separate arc** at HANDOFF.md Wave 1 Item 2; this RECOMMENDATION on Item 1 does not pre-determine Item 2.

#### Unification shape enumeration (corrected)

Five viable shapes:

**Shape A — Concrete Span-cursor primitive at L1 + composition adapters.** Extract a new struct `Cursor: ~Copyable, ~Escapable` with a *fixed* position type (e.g., raw `Int` OR `Tagged<SomeFixedTag, Ordinal>`); both consumers wrap or alias. Forces a position-type choice; subsumed by Shape F when the type is `Tagged<DomainTag, Ordinal>` with DomainTag parameterized.

**Shape B — Protocol-shaped abstraction with two conformers.** Define `BorrowedByteCursor: ~Copyable, ~Escapable` with an `associatedtype Position`; both structs conform. The struct *implementations remain parallel* — Shape B unifies the *interface*, not the *implementation*.

**Shape C — Generic-Element cursor.** `Cursor<Element>: ~Copyable, ~Escapable` parameterized over the span's element type. **Premature generalization** — Element = UInt8 is fixed in both consumers; the element-type axis carries no cross-domain pressure (only one element type ever).

**Shape C′ — Position-parameterized cursor (the right axis).** `Cursor<Position>: ~Copyable, ~Escapable` parameterized over the position type, with constraints (Position must support `+= .one`, `+= Count`, comparison, etc.). Both consumers ride: `Cursor<Int>` for Binary today; `Cursor<Text.Position>` for Lexer. The "no demand" objection v1.2.0 raised on Shape C doesn't transfer — the demand IS the two existing position types.

**Shape D — Pull Span-cursor to swift-byte-primitives.** Add `Byte.Cursor` to byte-primitives. Tier-shift consequence (parallel to R4 ASCII.Code Tier 0 → Tier 2). Mission-boundary tension with the "pure value layer" stance from byte-extraction arc.

**Shape F — Decompose + parameterize (the principled application of decompose-compose-reuse).**

1. **Decompose** (already done): position-types decompose to `Tagged<DomainTag, Ordinal>`. `Text.Position` already is this. `Index<Byte>` already is this for the byte domain. No new typealiases need to be invented (though a `Byte.Position` alias could be added for naming clarity if desired).

2. **Compose**: introduce a `Cursor<DomainTag>: ~Copyable, ~Escapable` primitive at L1, with `position: Tagged<DomainTag, Ordinal>` (≡ `Index<DomainTag>`). The Position type is computed from the DomainTag generic parameter via the existing `Tagged` infrastructure — no separate Position generic needed.

3. **Reuse**: 
   - `Binary.Bytes.Input.View` = `Cursor<Byte>` (typealias or thin wrapper with `starts(with:)` / `copyToOwned()` overlays)
   - `Lexer.Scanner` = `Cursor<Text>` composed with `Text.Location.Tracker` overlay + lexer helpers (`Scanner+Lexing.swift` continues unchanged conceptually)

Shape F is Shape C′ specialized to the institute's Tagged-based position-type discipline. It unifies BOTH the cursor implementation (single struct) AND the typing discipline (both domains use `Tagged<DomainTag, Ordinal>`).

### Phase 2 — Cost / benefit analysis (corrected)

#### Per-shape evaluation

| Shape | What it unifies | What it leaves alone | Principled status |
|---|---|---|---|
| A — concrete + adapters | Cursor mechanics under one struct | — | Subsumed by Shape F when position-type is the generic axis |
| B — protocol-shaped | Interface only | Struct implementations | Dominated by Shape C′/F: B unifies the interface without unifying the code; consumer-pull for generic-over-protocol algorithms is the only delta justifier, and no such consumer exists in the byte/text-parsing surface today |
| C — generic-element | (premature) | — | Element axis is unused; reject — premature generalization per the spirit of [RES-018] (no second-element demand) |
| **C′ — position-parameterized** | Cursor mechanics under one struct with Position generic | — | Structurally valid; demand IS the two existing position types |
| D — pull to swift-byte-primitives | Cursor mechanics inside byte-primitives | — | Mission-boundary tension with byte-primitives' pure-value-layer stance; tier shift; doesn't address the position-type alignment |
| **F — decompose + parameterize** | Cursor mechanics AND typing discipline | Domain-specific overlays (binary's `starts(with:)`/`copyToOwned`, text's tracker + lexer helpers) | The principled decompose-compose-reuse answer |

#### `[RES-018]` case (a) gate re-evaluation

- **Cross-domain fit**: binary parsing and text lexing are distinct domains. ✓ (unchanged from v1.1.0)
- **Composition check**: under v1.3.0's decomposition probe, the substrate-shared core composes cleanly into `Cursor<DomainTag>: ~Copyable, ~Escapable` with `position: Tagged<DomainTag, Ordinal>`. Both consumers ride without compromise to their typing discipline (Binary aligns to `Index<Byte>`; Text keeps `Text.Position` — both are `Tagged<DomainTag, Ordinal>`). **The composition check PASSES** under Shape F.

v1.2.0 reported the composition check failing; v1.3.0's empirical decomposition probe overrides that finding. The probe was the missing piece.

#### Cost-side framing

The implementation cost of Shape F:
- Add the unified `Cursor<DomainTag>` primitive at L1 (new package OR add to an existing package — implementation choice; not pre-determined by this RECOMMENDATION).
- Optionally add `Byte.Position` / `Byte.Count` / `Byte.Offset` typealiases to swift-byte-primitives for naming-symmetry with `Text.Position` / `Text.Count` / `Text.Offset` (or use `Index<Byte>` / its `.Count` / `.Offset` directly — the existing names already work).
- Migrate `Binary.Bytes.Input.View` and `Lexer.Scanner` to ride on the unified primitive.

These are implementation concerns. The RECOMMENDATION declares the structural answer; the *plan* is gated on principal authorization (per ground rule #1 — research only, no source modifications). Sequencing, naming, and the unified-primitive's package home are open implementation questions tracked separately.

#### `[BENCH-011]` integration probe

Implementation of Shape F will need a `[BENCH-011]` integration probe across both binary and text consumers before landing: cursor performance is on the hot path of every parser/lexer that uses these primitives, and generic specialization through `~Copyable & ~Escapable` types is a perf-sensitive area. The probe is required at implementation time, not at RECOMMENDATION time. v1.3.0's RECOMMENDATION does not gate on perf measurements; an implementation dispatch will.

### Phase 3 — Recommendation

**RECOMMENDATION: Shape F — Unify via decompose-compose-reuse.**

The position-type divergence between `Binary.Bytes.Input.View` (raw Int) and `Lexer.Scanner` (Text.Position = `Tagged<Text, Ordinal>`) is NOT load-bearing under decomposition. Binary's raw Int is the un-decomposed analog of `Index<Byte>` = `Tagged<Byte, Ordinal>`, structurally parallel to `Text.Position` = `Tagged<Text, Ordinal>`. Both decompose to the same generic shape; the divergence is at the phantom-domain-tag level, which is exactly what type-domain-tagging exists to express WHILE sharing implementation.

The institute already invests heavily in the Tagged-of-Ordinal/Cardinal/Vector pattern for typed positions, counts, and offsets across domains (Text's family, swift-index-primitives' Index<Element>, the Cardinal.Protocol family migrated in 2026-05-04). A unified `Cursor<DomainTag>: ~Copyable, ~Escapable` primitive at L1 is the natural extension of this discipline to Span-cursor mechanics. `~Copyable & ~Escapable` protocols are established (Sequence.Protocol et al.), so the cursor itself can declare an interface and the implementation can be generic.

Phase 3 rationale, evergreen-correctness anchored:

1. **Decompose-compose-reuse applied correctly.** Text.Position is already decomposed (Tagged<Text, Ordinal>). Index<Byte> is already the byte-domain parallel (Tagged<Byte, Ordinal>). The cursor primitive composes over Tagged<DomainTag, Ordinal>; both domains reuse with no compromise.

2. **The `[RES-018]` case (a) composition check PASSES.** Cross-domain fit was already satisfied; the composition check passes under Shape F because the institute's existing typed-offset primitives (Ordinal, Cardinal, Affine.Discrete.Vector) provide the substrate without per-domain compromise.

3. **`~Copyable & ~Escapable` protocols and generics are established ecosystem patterns.** Carrier.Protocol, Sequence.Protocol, Sequence.Iterator.Protocol, Sequence.Borrowing.Protocol, Equation.Protocol, Observation.Protocol, Ownership.Borrow.Protocol, Path.Modification, Path.Decomposition — all live in production. Shape F's compiler ergonomics ride on the same foundation.

4. **Item 2 (D5) remains separate.** The layer-separation finding from v1.2.0 (Phase 1 §"Item 1 vs Item 2") survives v1.3.0's corrections independently. Item 2 stays its own arc at HANDOFF.md Wave 1 Item 2.

5. **Implementation is gated on principal authorization.** Per ground rule #1 (research only), v1.3.0 does NOT modify source. The RECOMMENDATION declares the structural answer; an implementation dispatch will follow once the principal approves the recommendation and authorizes the implementation arc.

## Outcome

**Status**: IN_PROGRESS.

> **2026-05-17 downgrade**: this Outcome is preserved as v1.3.0's recorded analytical state but is no longer authoritative. v1.3.0's RECOMMENDATION (Shape F) was downgraded to IN_PROGRESS the same day after Phase 0 prior-research grep surfaced load-bearing prior artifacts v1.3.0 did not engage. See §Successor for the forwarding path.

Unify `Binary.Bytes.Input.View` and `Lexer.Scanner` via decompose-compose-reuse:

1. Treat `Tagged<DomainTag, Ordinal>` as the canonical typed-byte-position type (already in production as `Text.Position` and `Index<Byte>`).
2. Introduce a unified `Cursor<DomainTag>: ~Copyable, ~Escapable` Span-cursor primitive at L1, with `position: Tagged<DomainTag, Ordinal>`, hosting peek / peek(at:) / advance / advance(by:) / consume / isAtEnd.
3. Migrate `Binary.Bytes.Input.View` to ride on `Cursor<Byte>` with binary-domain overlays (`starts(with:)`, `copyToOwned()`).
4. Migrate `Lexer.Scanner` to ride on `Cursor<Text>` with the existing `Text.Location.Tracker` overlay + the lexer-specific `Scanner+Lexing.swift` helpers unchanged conceptually.

The unified primitive's package home, naming (Cursor vs Span.Cursor vs Input.Span.Cursor vs another), and the optional `Byte.Position`/`Byte.Count`/`Byte.Offset` typealias additions to swift-byte-primitives are implementation choices left to the follow-up dispatch.

`Text.Location.Tracker` is a composable overlay (Phase 1 §Text.Location.Tracker), confirmed empirically. Item 2 (D5 Binary.Bytes.Input vs Byte.Input unification) is a separate arc at HANDOFF.md Wave 1 Item 2 (Phase 1 §"Item 1 vs Item 2"), unaffected by this RECOMMENDATION.

## Successor

This document is superseded as the canonical answer on cursor unification by a forthcoming **Tier 3 `/research-process` arc** on cursor abstractions across the institute L1 ecosystem (working title: *"Cursor Abstractions Across the Institute L1 Ecosystem"*). v1.3.0's analytical content remains as *input* to the successor arc, NOT as the canonical answer.

- **Shape F decomposition insight survives as INPUT to the Tier 3 arc**, not as a decided answer. The empirical decomposition probe (`Text.Position` ≡ `Tagged<Text, Ordinal>` at `swift-text-primitives/Sources/Text Primitives/Text.Position.swift:27`; `Index<Element>` ≡ `Tagged<Element, Ordinal>` at `swift-index-primitives/Sources/Index Primitives Core/Index.swift:38`; therefore `Index<Byte>` ≡ `Tagged<Byte, Ordinal>` as the byte-domain parallel of `Text.Position`) is verified at the source level and is part of what the Tier 3 arc inherits.

- **The Tier 3 arc engages**:
  - **(a)** `Binary.Cursor` in `swift-binary-primitives` (`Sources/Binary Cursor Primitives/Binary.Cursor.swift`) as a *third* cursor abstraction missed by v1.3.0 — `~Copyable & Escapable` (NOT `~Escapable`) owned reader-writer over `Storage: Memory.Contiguous.Protocol & ~Copyable where Storage.Element == UInt8`, with dual `Index<Storage>` reader/writer indices, `throws(Binary.Error)` move/set operations, `readableBytes: Span<UInt8>` accessor. Structurally distinct from the two `~Copyable & ~Escapable` borrow-only Span-cursors v1.3.0 evaluated.
  - **(b)** `swift-binary-primitives/Research/Lifetime Dependent Borrowed Cursors.md` (RECOMMENDATION, 2026-01-19, Tier 2+, ~1200 lines) — prior research arguing the protocol-based dispatch (`Binary.Bytes.Parser`) is *structurally required* for `~Escapable` borrowed cursor APIs under Swift 6.x (the closure integration gap; §5–§7). The doc's *Two Worlds Architecture* (§8.5: owned `Binary.Bytes.Input` + `Parsing.Parser` vs borrowed `Binary.Bytes.Input.View` + `Binary.Bytes.Parser`) and reuse strategies (§8.6: bridge layer, defunctionalized machine execution) are the institute's prior position that v1.3.0's Shape F framing did not engage.
  - **(c)** Academic prior art on cursor abstractions: iteratees (Oleg Kiselyov), parsing combinators (Hutton/Meijer, Parsec, swift-parsing), Conduit/Pipes (Haskell streaming libraries), the Rust borrow-checker's cursor patterns (`std::io::Cursor`, `slice::Iter`, `bytes::Buf`), linear/affine types in research languages.

- **HANDOFF.md Wave 1 Items 2 / 3 / 4 / 5 are on hold pending the Tier 3 arc's outcome**:
  - Item 2 (D5 `Binary.Bytes.Input` vs `Byte.Input` typed-input unification)
  - Item 3 (R3 `Word16.Protocol` / `Word32.Protocol` / `Word64.Protocol` viability)
  - Item 4 (D6 serializer-side parallel extraction)
  - Item 5 (F2 non-Byte conformers proliferation)

  Each may be informed by — or composed into — the Tier 3 arc's recommendation. The byte-ecosystem finalization arc resumes from Wave 2 onward contingent on the Tier 3 disposition.

## Implementation prerequisites and risks (for follow-up dispatch)

Not gates on the RECOMMENDATION — flags for the implementation dispatch that follows principal authorization.

| Concern | Disposition at implementation time |
|---|---|
| Position-type constraint set on Cursor<DomainTag>'s `position` field | Identify the minimum protocol constraint required for cursor arithmetic; likely existing Ordinal.Protocol + Cardinal.Protocol surface suffices |
| Package home for the unified primitive | Decide between (a) new package (`swift-cursor-primitives` or similar), (b) extension of `swift-input-primitives`, (c) extension of another existing package. Each has tradeoffs |
| Naming question on `Byte.Position`/`Byte.Count`/`Byte.Offset` typealiases | Add for naming-symmetry with `Text.*` family, OR rely on `Index<Byte>` / its Count/Offset machinery directly |
| Generic specialization perf on `~Copyable & ~Escapable` Cursor | `[BENCH-011]` integration probe required before landing |
| Existing-consumer compatibility | Both `Binary.Bytes.Input.View` and `Lexer.Scanner` remain public API; migrations should be source-transparent for downstream consumers (likely typealias-based) |

## Revisit conditions

The RECOMMENDATION is closed. Revisit conditions for the implementation plan, NOT for the recommendation itself:

1. If the integration probe per `[BENCH-011]` surfaces a perf regression that's not addressable through generic specialization tuning, the implementation may stage differently (or this RECOMMENDATION may need amendment).
2. If `~Copyable & ~Escapable` generic specialization hits a compiler limitation specific to the cursor pattern not visible from the ecosystem's existing usage of the same pattern (Sequence.Protocol et al.), the implementation may need to fall back to Shape B (protocol-shaped) or stage Shape F over multiple compiler releases.
3. If a fourth structural concern surfaces that v1.3.0 didn't address, the RECOMMENDATION may need a v1.4.0 revision.

## Out of scope for this RECOMMENDATION

- **Item 2 / D5** (Binary.Bytes.Input vs Byte.Input typed Input-iterator unification) — different layer; separate arc at HANDOFF.md Wave 1 Item 2.
- **Whether `Lexer.Scanner` belongs in `swift-lexer-primitives` vs another package** — answered in `swift-lexer-primitives/Research/lexer-primitives-scope.md` (DEFERRED, 2026-03-15).
- **The exact constraint set on the Cursor<DomainTag>'s Position** — implementation detail.
- **The package home for the unified primitive** — implementation detail.

## References

- `swift-institute/Audits/streaming-deserialize-placement-audit.md` (2026-05-14) — Phase 2 out-of-scope observation that surfaced this question.
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift` — binary-domain Span-cursor.
- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift`, `Lexer.Scanner+Lexing.swift` — text-domain Span-cursor and lexing helpers.
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Position.swift`, `Text.Count.swift`, `Text.Offset.swift`, `Text.Location.Tracker.swift` — text-domain typed-offset family and overlay.
- `swift-primitives/swift-byte-parser-primitives/Sources/Byte Parser Primitives/Byte.Input.swift` — Item 2 typealias.
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input Primitives/Binary.Bytes.Input.swift` — Item 2 owned-form.
- `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift` — byte value type (no Position/Count/Offset family yet).
- `swift-primitives/swift-index-primitives/Sources/Index Primitives Core/Index.swift` — `Index<Element> = Tagged<Element, Ordinal>` (line 38).
- `swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives/Sequence Primitives.docc/Sequence-Protocol.md` — codification of `~Copyable & ~Escapable` protocol discipline ecosystem-wide.
- `swift-primitives/swift-lexer-primitives/Research/lexer-primitives-scope.md` (2026-03-15, DEFERRED) — D2 prior decision: lexer cursor stays separate from Input.Protocol layer.
- `swift-primitives/swift-binary-parser-primitives/Research/full-internal-typing-interpreter.md` (2026-01-29, DECISION) — typed-index discipline (Index<UInt8>) applied to Binary.Bytes.withBorrowed interpreter.
- `swift-institute/Research/byte-protocol-capability-marker.md` v1.1.0 — `[API-NAME-001c]` capability-marker resolution (the doc v1.2.0 mis-cited; v1.3.0 retracts the citation).
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.0.1 — parent byte-arc decisions cemented.

## Provenance

Surfaced 2026-05-14 by the streaming-JSON-deserialize Phase 2 audit. v1.0.0 / v1.1.0 staged the question. v1.2.0 (2026-05-17) executed the composition check as Wave 1 Item 1 of the byte-ecosystem finalization arc and landed a principled-refuse DECISION; principal review identified three structural gaps: [API-NAME-001c] miscite, Shape C wrong-axis evaluation, missing decomposition probe. v1.3.0 (2026-05-17) re-executed Phase 1 with the corrected lenses; the decomposition probe succeeded (Text.Position is already Tagged<Text, Ordinal>; Index<Byte> is the parallel byte-domain typed-position); `~Copyable & ~Escapable` protocols/generics are established ecosystem patterns; the composition check passes under Shape F. RECOMMENDATION: Shape F — unify via decompose-compose-reuse, implementation gated on principal authorization.

## Changelog

- **v1.3.0 → IN_PROGRESS (2026-05-17 downgrade)**: Status downgraded `RECOMMENDATION → IN_PROGRESS` after the byte-arc finalization arc's Phase 0 prior-research grep (scheduled by the principal for the boundary between Wave 1 Item 1 closure and the implementation arc per `[HANDOFF-013a]`) surfaced two load-bearing prior artifacts that v1.3.0's analysis did not engage: **(a)** `Binary.Cursor` in `swift-binary-primitives` (`Sources/Binary Cursor Primitives/Binary.Cursor.swift`) — a *third* cursor abstraction (`~Copyable & Escapable` owned reader-writer over `Storage: Memory.Contiguous.Protocol`, dual `Index<Storage>` reader/writer indices, throws `Binary.Error` move/set operations), structurally distinct from the two `~Copyable & ~Escapable` Span-cursors v1.3.0 evaluated; **(b)** `swift-binary-primitives/Research/Lifetime Dependent Borrowed Cursors.md` (RECOMMENDATION, 2026-01-19, ~1200 lines) — prior research arguing protocol-based dispatch (`Binary.Bytes.Parser`) is *structurally required* for `~Escapable` borrowed cursors under Swift 6.x, plus a Two Worlds architecture (owned `Binary.Bytes.Input` + `Parsing.Parser` vs borrowed `Binary.Bytes.Input.View` + `Binary.Bytes.Parser`) that v1.3.0's Shape F framing did not engage. v1.3.0's prior-research grep was ecosystem-wide only; the per-package grep that surfaced these ran AFTER v1.3.0 was authored. RECOMMENDATION status was structurally unreliable on incomplete analysis. Shape F's decomposition insight (Tagged<DomainTag, Ordinal> as already-decomposed substrate; `Index<Byte>` as Binary's parallel of `Text.Position`) survives as analytical INPUT to the forthcoming Tier 3 `/research-process` arc — see §Successor. HANDOFF.md Wave 1 Items 2 / 3 / 4 / 5 are on hold pending the Tier 3 arc's outcome.
- **v1.3.0** (2026-05-17): RECOMMENDATION — Shape F (unify via decompose-compose-reuse). Re-executes Phase 1/2/3 with three corrections to v1.2.0: drops the `[API-NAME-001c]` miscite (the capability-marker arc declined meta-protocols over capability-markers, not unification protocols over near-identical implementations); re-evaluates Shape C on the correct parameterization axis (position-type, not element-type) as new Shape C′; adds the decomposition probe on Text.Position (succeeds — Text.Position is already Tagged<Text, Ordinal>; Index<Byte> is its byte-domain parallel). The composition check passes under Shape F. v1.2.0's principled-refuse DECISION is retracted.
- **v1.2.0** (2026-05-17): DECISION — principled refuse (RETRACTED by v1.3.0). Phase 1 comparative shape analysis identified ~100 LOC of mechanically-symmetric scaffolding and verified Text.Location.Tracker as a composable overlay; Phase 2 evaluated five shapes (A–E); Phase 3 landed principled refuse. Principal review on 2026-05-17 identified three structural gaps in the grounding (preserved in v1.3.0 §"v1.3.0 — Corrections to v1.2.0 analysis").
- **v1.1.0** (2026-05-14): DEFERRED — reclassified under the `[RES-018]` amendment as case (a) cross-cutting primitive; composition check named as substantive remaining gate.
- **v1.0.0** (2026-05-14): DEFERRED — original parking-lot entry surfaced from the streaming-JSON-deserialize Phase 2 audit.
