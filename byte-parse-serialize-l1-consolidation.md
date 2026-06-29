# Byte Parse / Serialize — L1 Single-Source-of-Truth Consolidation

<!--
---
version: 1.0.0
last_updated: 2026-06-26
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

> **Gating design for the byte parser/serializer reuse program.** Locks the complete L1
> parse/serialize family BEFORE any consumer migration, per `[RES-011]` (research-first:
> do not migrate ~40 consumers onto an L1 whose shape is still moving). Backed by
> `Audits/byte-binary-reuse-audit.md` (both altitudes). Principal directive (2026-06-26):
> **the principally-correct architecture, no matter refactor effort.**

## Context

The reuse audit found two altitudes of duplication:
- **Leaf** — hand-rolled digit/nibble conversion (26 spots) → `ASCII.Serialization`/`Parsing`.
- **Whole-operation** — entire integer parsers / serializers re-implemented (5 clean swaps
  + 10 case-(c) duplicates) → the L1 `ASCII.{Decimal,Hexadecimal}.Parser`/`Serializer`,
  `Binary.Machine`.

Adoption asymmetry: `ascii-serializer-primitives` has 23 consumers; `ascii-parser-primitives`
**4**. The **parse side is the under-adopted gap**, and several consumers cannot delegate
today because **L1 is incomplete** (missing radixes / count modes / generic input) or because
a **parallel L1+L2 stack** exists (`INCITS_4_1986.Numeric`).

## Question

What is the complete, principally-correct **L1 parse/serialize family**, and how does every
higher-layer consumer delegate to it — such that no parse/serialize *algorithm* is
implemented more than once in the ecosystem?

## Governing principle

**Every parse/serialize algorithm lives once, at its lowest correct layer (L1).** Higher
layers keep only spec framing, combinator policy, and spec-mirroring public names
(`[API-NAME-003]`); they delegate the algorithm down (`[ARCH-LAYER-001]`,
`[ARCH-LAYER-008]`). Where L1 is incomplete, **complete L1** — never hand-roll in a consumer.

Naming follows the live operation-domain DECISIONs (`operation-domain-naming-and-organization.md`
v1.1.2, `transformation-domain-architecture.md` v3.4.0): subject-first agent-noun namespaces
(`ASCII.Decimal.Parser`), `Parser`/`Serializer` as **separate** namespaces, `Parser.Protocol`
/ `Serializer.Protocol`, passive `Parseable`/`Serializable`.

## Analysis

### 1. The complete L1 ASCII parse/serialize family — target vs current

Current L1 coverage (`swift-ascii-parser-primitives` / `swift-ascii-serializer-primitives`):

| Operation | Decimal | Hex | Binary | Octal | Float |
|-----------|:-------:|:---:|:------:|:-----:|:-----:|
| Parser | ✅ `ASCII.Decimal.Parser` | ✅ `ASCII.Hexadecimal.Parser` | ❌ | ❌ | ✅ `ASCII.Decimal.Float.Parser` |
| Serializer | ✅ `ASCII.Decimal.Serializer` | ✅ `ASCII.Hexadecimal.Serializer` | ❌ | ❌ | ❌ |

Axis gaps on the existing parsers/serializers:
- **Sign**: `ASCII.Decimal.Parser` is digit-only (no leading `+`/`-`). Consumers needing
  signed integers (`swift-parsers`, `swift-ascii` `Int+ASCII.Serializable`) re-derive sign.
- **Count mode**: parsers are **greedy-only** (consume all digits). Fixed-width / max-count
  parsing (exactly-N or up-to-N digits) — needed by every date/time/fixed-field parser
  (`iso-8601 Parse.Digits`, the duration/recurring loops) — has no L1 expression.
- **Input element**: parsers constrain `Input.Element == Byte`; several consumers are still
  `UInt8` (couples to the UInt8-elimination program).

**Target (complete family):** `ASCII.{Decimal,Hexadecimal,Binary,Octal}.{Parser,Serializer}`
+ `ASCII.Decimal.Float.{Parser,Serializer}`, each carrying:
- signed/unsigned (sign is a **parse/emit policy on the parser/serializer**, not a separate
  type — recommended shape: an `init` configuration `sign:` / `allowSign`, mirroring the
  existing `swift-parsers` policy surface, so combinator composition stays a sign-prefix +
  unsigned-digit chain where preferred);
- a **count policy** (`.greedy` / `.exactly(n)` / `.upTo(n)`) on the parser — **the single
  highest-leverage addition**; it collapses `iso-8601 Parse.Digits` plus the W4/W5 greedy
  loops plus other fixed-width date fields onto L1;
- `Input.Element == Byte` (the byte-discipline substrate).

> **D-i — RATIFIED 2026-06-26: configuration.** Sign and count are *configuration on the
> existing parser/serializer types* (`ASCII.Decimal.Parser(sign:, count: .greedy/.exactly(n)/.upTo(n))`),
> not separate manner-variant types. Unsigned/greedy is the zero-config default so existing
> call sites stay source-stable.

### 2. The binary-field reader — generalize the input

`Binary.Machine` (the fixed-width u16be/u32le field-parse machine) and `Binary.Cursor`/`Reader`
accept only `Span`/`Byte` input. Consumers that walk a generic `Collection<UInt8>` at a mutable
index (`swift-plist` `Trailer`/`Parser`, `swift-rfc-9293` TCP header) therefore **cannot
delegate** and hand-roll the field reads. The decode algorithm is byte-identical
(`(result << 8) | next`), so this is a substrate-shape gap, not an algorithm difference.

> **D-ii — RATIFIED 2026-06-26: consumers adapt to the Span/Byte substrate; L1 is unchanged.**
> `Binary.Machine` / `Binary.Cursor` / `Binary.Reader` stay `Span`/`Byte`-only — the L1
> primitive's substrate is correct and is **not** weakened to accommodate consumers. Instead,
> the generic-`Collection<UInt8>` parsers (`swift-plist` `Trailer`/`Parser`, `swift-rfc-9293`
> TCP header) **adapt**: materialize a `Span<Byte>` (the input is already contiguous bytes)
> and run the existing machine/cursor. This is strictly better — it also drags those consumers
> onto correct `Byte` typing (the `UInt8`-walking-a-`Collection` shape was itself the
> anti-pattern). Principal direction: *"the higher packages should adapt to the Span/Byte
> approach, not the other way around."*

### 3. The two-ASCII-stacks resolution — layering-forced

`INCITS_4_1986` (L2) builds on `swift-ascii-primitives` (L1) but carries its **own**
`Numeric.Parsing` / `Numeric.Serialization` — a parallel re-implementation that does **not**
depend on the L1 `ascii-parser`/`ascii-serializer` primitives (verified). `swift-ascii` (L3)
consumes the L2 INCITS path; other consumers use the L1 path. Two algorithm homes for one
operation.

This is **not** a discretionary "which wins" — `[ARCH-LAYER-001]` decides it: the L1 parser/
serializer primitives cannot depend up onto L2 INCITS, so **the canonical algorithmic home is
L1**. INCITS 4-1986 is a *character-set* specification (it mandates `0x30 == '0'`, already
owned by `ASCII.Code`); integer parse/serialize is an *algorithm*, not a spec obligation of
INCITS. Therefore `INCITS_4_1986.Numeric.Parsing`/`Serialization` **delegates down to the L1
parsers/serializers** (add the dep; thin the bodies) — or dissolves where it adds nothing over
L1.

> **D-iii — RATIFIED 2026-06-26: thin to a delegating spec-layer.** `INCITS_4_1986.Numeric.Parsing`/
> `Serialization` keeps its spec-mirroring public names; the bodies delegate **down** to the L1
> `ASCII.{Decimal,Hexadecimal}.Parser`/`Serializer` (add the `ascii-parser`/`ascii-serializer`
> dep; replace the algorithm with a delegating call). One algorithm home (L1), spec surface
> preserved. This also unblocks UInt8-elimination subprogram-2 (the swift-ascii dual-constant
> surface) since INCITS becomes a pass-through rather than a parallel implementation.

### 4. Consumer migration map (keyed off the completed L1)

| Consumer | Delegates to | Altitude |
|----------|--------------|----------|
| rfc-3986 Port, rfc-5322 DateTime, w3c-svg Color, iso-8601 Duration/RecurringInterval | `ASCII.Decimal.Parser` (+ count policy for the fixed-width ones) | whole-parser swap |
| iso-8601 `Parse.Digits` | `ASCII.Decimal.Parser(.exactly(n))` | case-(c) → collapses once count mode lands |
| swift-parsers `Parser.Integer.Decimal`/`Hexadecimal` | core → `ASCII.Decimal/Hexadecimal.Parser`; keep sign/leading-zero/combinator shell | case-(c) thin-wrap |
| swift-parsers `Parser.Integer.Binary`/`Octal` | new `ASCII.Binary/Octal.Parser` | case-(c) → collapses once radixes land at L1 |
| w3c-svg `Parse.Number` | `ASCII.Decimal.Float.Parser` (keep spec name; **regenerate snapshots** — L1 is correctly-rounded) | case-(c) thin-wrap |
| rfc-4648 `Base16.decode/encode<T>` | `ASCII.Hexadecimal.Parser`/`Serializer`; keep prefix/whitespace/case framing | case-(c) thin-wrap (also: Base-N byte codec → `swift-binary-base-primitives`, per pass-1 overlap) |
| INCITS_4_1986 `Numeric.*` | `ASCII.{Decimal,Hexadecimal}.Parser`/`Serializer` (thin-delegate, keep names) | case-(c) delegate-down |
| swift-ascii `Binary.ASCII.Parsing.Machine.Decimal`, `Int+ASCII.Serializable` | L1 ASCII parser/serializer (via the thinned INCITS path) | case-(c) |
| swift-rfc-9293 TCP header, swift-plist Trailer/Parser | **existing** `Binary.Machine` over a materialized `Span<Byte>` (consumer adapts; `UInt8→Byte`) | adapt-to-substrate |
| the 26 leaf spots | `ASCII.Serialization`/`Parsing` | leaf |
| swift-decimals render/parse, rss duration, IPv6 segment, wire bitfields | leaf (`ASCII.Serialization`/`Parsing`); surrounding parser legitimately differs | leaf |

Recurring prerequisite for the parse-side swaps: `Input.Element: UInt8 → Byte` retype — a
localized, per-parser byte-discipline change shared with the UInt8-elimination program.

## Outcome

**Status: DECISION on D-i/D-ii/D-iii (ratified 2026-06-26); RECOMMENDATION on the migration**
(not yet executed).

**Phased execution (settle-L1-then-migrate):**

1. ~~Ratify D-i / D-ii / D-iii~~ — **done 2026-06-26** (configuration; consumers adapt to
   Span/Byte; INCITS thin-delegates).
2. **Complete L1** per §1 (additive — no consumer breaks). **DONE 2026-06-26 for the integer
   family:** `ASCII.Digits.Count` (`c55b06c`) + `ASCII.Digits.Sign` (`995df6c`) policies wired
   into the Decimal/Hex parsers (`5b1cba6`, `d178bf9`); `ASCII.Binary`/`Octal` namespaces
   (`f0bb007`); `ASCII.Binary/Octal.Parser` (`6ba81ca`) and `ASCII.Binary/Octal.Serializer`
   (`f58049a`), both sign+count-complete and re-exported from the umbrellas; a pre-existing
   ascii-parser test-baseline break (UInt8-substrate vs Byte parsers) was repaired en route.
   (Per D-ii, **no** `Binary.Machine` input change.) **DEFERRED:** `ASCII.Decimal.Float.Serializer`
   — a correct `Double→ASCII` serializer is a Ryū/Grisu-class algorithm, not a mirror, and no
   consumer needs it (consumers need the float *parser*, which exists). Build it as its own
   scoped effort if/when a `Double→ASCII` consumer appears.
3. **Migrate consumers** onto the completed L1 (the whole-parser swaps, the case-(c) cores,
   INCITS thin-delegate, the `UInt8→Byte` retypes, the 26 leaf spots), one commit per site,
   dependency-ordered, byte-for-byte parity gate. Start canary: **rfc-5322** (`Input` already
   `Byte`).
4. **Adapt** TCP/plist to a materialized `Span<Byte>` + the **existing** `Binary.Machine` (per
   D-ii).
5. **Checksum primitive** (Track-B gap: Adler-32 / RFC-1071 / CRC-32 duplication) — separate
   design.

**Verification gate per migrated site:** byte-for-byte output parity (the supersets *add*
overflow safety / correct rounding — those deltas are corrections, recorded), typed-throws
error remap, and a clean build. No site lands without parity.

## References

- `Audits/byte-binary-reuse-audit.md` — both altitudes, the 26 leaf + 5 whole + 10 case-(c) findings.
- `operation-domain-naming-and-organization.md` v1.1.2 (DECISION) — agent-noun namespace, `Parser`/`Serializer` forms.
- `transformation-domain-architecture.md` v3.4.0 (DECISION) — `Parser.Protocol`/`Serializer.Protocol` separation.
- `uint8-elimination-inventory.md` v1.0.0 — the `UInt8→Byte` retype program (now ownerless; subprogram-2 = the swift-ascii dual stack).
- `ascii-serialization-migration.md` (DEFERRED) — the `Binary.ASCII.Serializable` witness migration (rfc-791 / swift-ascii overlap).
- Live source: `swift-ascii-parser-primitives` / `swift-ascii-serializer-primitives` (current family); `swift-incits-4-1986/.../INCITS_4_1986.Numeric.{Parsing,Serialization}.swift` (parallel stack); `swift-binary-parser-primitives` Binary Machine (Span/Byte input).
