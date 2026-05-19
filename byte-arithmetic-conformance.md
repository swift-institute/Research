# Byte Arithmetic Conformance — Lift, Target, or Stay

<!--
---
version: 1.0.0
last_updated: 2026-05-19
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
applies_to:
  - swift-byte-primitives
  - swift-byte-parser-primitives
  - swift-ascii-primitives
  - swift-binary-parser-primitives
  - future-byte-domain-types
normative: true
depends_on:
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
  - swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md
  - swift-institute/Research/byte-cursor-primitive-unification.md
companion_to: byte-protocol-capability-marker.md
---
-->

## Context

`Byte` deliberately lacks `+ - * /` arithmetic. The intent is documented
inline at `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift`
lines 26–35:

> - **Bitwise**: `& | ^ ~ << >>` forwarded to the underlying byte
> - **Arithmetic**: NOT forwarded — `+`, `-`, `*`, `/` are absent by design
> - **Literal**: `ExpressibleByIntegerLiteral` for `0xFF`-style construction

The companion Tier 3 research [`byte-protocol-capability-marker.md`](./byte-protocol-capability-marker.md)
v1.1.0 (RECOMMENDATION, 2026-05-15) settled Q1: `UInt8` MUST NOT conform to
`Byte.Protocol`. The verdict's rationale — preserving the byte-vs-arithmetic
identity separation — explicitly DEFERRED the symmetric question to the
arithmetic axis ([`byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md)
v1.0.1 §"Open question (deferred)" framed the UInt8-conformance side; the
Byte-arithmetic side was left open by the same identity-separation principle).

The byte-adoption arc (β, 2026-05-18) plus the substrate migration (2026-05-19)
exposed two empirical friction families at `.underlying` extraction sites
where the absence of byte arithmetic forces explicit unwrapping. The
recurring shape is `byte.underlying <op> constant` (ASCII decimal decode,
LEB128 bit manipulation, endianness widening). The live inventory in
[`swift-byte-primitives/Research/bsli-gap-inventory.md`](../../swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md)
documents the explicit-rejection-with-friction state:

> **Byte arithmetic operators (`+`, `-`, `*`, `/`)**: Why: Byte is the
> byte-domain twin of UInt8, NOT the arithmetic type. … Adding arithmetic
> dissolves the byte-vs-arithmetic identity separation. Consumers needing
> arithmetic extract `.underlying`.

AND the "Open friction note: ASCII-arithmetic ergonomics" (same file):

> Sites doing ASCII digit decoding (`value = value * 10 + Int(byte.underlying - 0x30)`)
> hit friction because Byte deliberately has no arithmetic (MUST NOT ground
> rule per byte-protocol-capability-marker.md Q1=Option B). … Resolution
> requires re-examining the no-arithmetic-on-Byte decision OR introducing a
> separate ASCII-digit numeric type. Not in current scope; recorded for
> principal review.

This document is the principal-review disposition of that note. The
question is precedent-setting because (a) Byte is the first L1 capability
marker whose adjacency to a Numeric-bearing stdlib carrier raises this
shape (Cardinal/Ordinal/Vector are themselves the institute's arithmetic
algebras over `UInt`/`Int`; Byte is the first capability marker that is
NOT an algebra), and (b) the same question will resurface for every
future byte-domain value type (`Char`/`Codepoint`/`Word`/`Line`, etc.).
The decision frame and verdict here govern those future arcs.

## Question

**Q3** (this document): Should `Byte` gain arithmetic operators, and if so,
which shape?

Q3 is structurally symmetric to Q1 (byte-protocol-capability-marker.md):
Q1 asked whether the stdlib carrier (UInt8) should carry the byte-domain
bundle; Q3 asks whether the byte-domain twin (Byte) should carry the
arithmetic-algebras bundle. Both questions test the byte-vs-arithmetic
identity separation from one side each.

Sub-questions resolved as part of Q3:

| ID | Question | Resolution path |
|----|----------|------------------|
| Q3.1 | Which algebraic shape best models Byte's intrinsic semantics, if any? | §Algebra comparison |
| Q3.2 | Does the `.underlying` site inventory empirically support an arithmetic shape? | §`.underlying` site inventory |
| Q3.3 | If arithmetic lands, on `Byte` directly or on `Byte.Protocol`? | §Cross-cutting / protocol-vs-type placement |
| Q3.4 | How does `ExpressibleByIntegerLiteral` interact with each option's resolution of `byte + 1`? | §Cross-cutting / integer-literal interaction |
| Q3.5 | How does the recommendation partition the inventory between BSLI overloads, Byte arithmetic, and domain-specific helpers? | §Cross-cutting / BSLI partition |
| Q3.6 | Does Q3's verdict preserve, amend, or supersede the parent doc's framing? | §Supersession status |

## Prior Art

### Internal — Authoritative

Per [RES-019] (Step-0 Internal Research Grep), the internal corpus is
load-bearing for this question; external prior art adds context but
internal research governs pending explicit override. Six documents are
directly relevant.

#### 1. byte-protocol-capability-marker.md v1.1.0 (the parent)

This is the Tier 3 RECOMMENDATION (2026-05-15) that settled Q1 and Q2 of
the byte-extraction arc. Q1's verdict — `UInt8` MUST NOT conform to
`Byte.Protocol` — is the structural anchor Q3 mirrors. The parent's
§"Recommendation Q1" justifies the verdict on three axes:

1. **Semantic identity (Tier 1 per [RES-029])**: UInt8 is the
   arithmetic-algebras type; Byte is the byte-domain twin. Conforming
   UInt8 dissolves the separation.
2. **Adjacent-type consensus (Tier 2)**: UInt does NOT conform to
   `Cardinal.Protocol`; Int does NOT conform to `Affine.Discrete.Vector.Protocol`.
   The institute's stdlib carriers never conform to the domain protocol.
3. **Bundle-conflict avoidance**: operator shadow, API-surface broadening,
   `Tagged<_, UInt8>` composition pollution.

Q3 asks the symmetric question from the other side: should Byte carry
arithmetic? The same three-axis analysis applies, with the symmetry
analyzed in §"Identity preservation" below.

#### 2. byte-primitive-extraction-and-domain-naming.md v1.0.1

The byte-extraction arc (DECISION, 2026-05-15). §"Decisions Cemented",
Decision #2 ("Byte Location Split"), records the architectural framing
that motivates the no-arithmetic stance:

> Why two packages instead of one: a downstream consumer that only needs
> the byte concept (e.g., a binary format describing a header field)
> should not be forced to pull in parser combinators. The Foundation-free,
> parser-free `Byte` is reusable in serializer contexts, coder contexts,
> schema contexts — none of which need `Parser.Protocol`.

Symmetric reading for arithmetic: a downstream consumer that needs a byte
concept should not be forced to inherit arithmetic semantics that have
no byte-domain interpretation. The split is between the byte value type
(opaque 8-bit datum) and arithmetic (numeric operations on widened
integers). Decision #4 ("Byte.Protocol as Refinement") notes the deferred
question — superseded by v1.1.0's sibling-form refactor — and identifies
`UInt8: Byte.Protocol` as the open question, which v1.1.0 resolved.

#### 3. bsli-gap-inventory.md (the live empirical state)

This is the canonical empirical record of which `.underlying` sites have
been absorbed by BSLI bridges, which remain, and which are explicit-reject.
The relevant rejections (verbatim, with file:line citations into the
live doc):

> **Byte arithmetic operators (`+`, `-`, `*`, `/`)** — lines 110–115:
> Why: Byte is the byte-domain twin of UInt8, NOT the arithmetic type.
> Per byte-protocol-capability-marker.md Q1=Option B. Adding arithmetic
> dissolves the byte-vs-arithmetic identity separation.

> **Byte.hex / Byte.binary rendering accessors** — lines 117–125:
> Why: Explicitly ruled out … L1 String-conversion friction is
> intentional per `[PRIM-FOUND-004]`.

And the open friction (lines 242–258):

> Sites doing ASCII digit decoding (`value = value * 10 + Int(byte.underlying - 0x30)`)
> hit friction … Resolution requires re-examining the no-arithmetic-on-Byte
> decision OR introducing a separate ASCII-digit numeric type. Not in
> current scope; recorded for principal review.

The triage table at lines 162–180 enumerates the eight specific
`.underlying` sites from the 2026-05-19 substrate migration arc with
per-site dispositions. The categories that landed: **LEAVE** (3 — `.u8`
output, LEB128 bitwise, hex rendering bridge), **FOLLOW-UP** (2 — ASCII
classification migration, ASCII-arithmetic ergonomics), **REVISIT** (1 —
Manifest.Parent storage migration), **PERMANENT** (1 — hex rendering),
**RESOLVED via BSLI** (2 — `Int8(bitPattern:byte)`, `UInt16/32/64(byte)`).
This triage is the load-bearing empirical input to Q3.

#### 4. Cardinal precedent (live precedent in production)

`Cardinal` is the closest existing precedent for "principled-partial
unsigned algebra" in the institute. `swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.swift`
lines 32–37 (inline doc):

> - **Backing**: `UInt` (machine word) ensures non-negativity at the type level
> - **Addition**: Trapping `+` operator matches Swift integer semantics
> - **Subtraction**: No `-` operator; use `.subtract.saturating` (monus) or `.subtract.exact`

And `Cardinal.Subtract.swift:14`:

> There is no `-` operator because subtraction on cardinals is not total.

`Cardinal` exposes `+` (trapping, `Cardinal.swift:91-95`) and Property.View
`.subtract.saturating(_:)` / `.subtract.exact(_:)` (`Cardinal.Subtract.swift:37-55`)
but NOT a `-` operator. This is the canonical institute pattern for
"unsigned domain that COULD wrap but deliberately doesn't expose unchecked
subtraction." Cardinal's discipline is the closest analog to Byte's
adjacency to UInt8, and the Cardinal precedent's lesson — expose `+`
where the operation is total AND the result type is structurally
coherent; expose partial operations via Property.View — directly applies.

The structural premise that makes Cardinal's `+` admissible is that
**Cardinal IS a quantity**: adding two cardinalities IS a cardinality.
The result type is structurally coherent with the operand types. The
Byte test for that premise is decisive (§Algebra comparison): Byte is
not a quantity.

#### 5. Ordinal + Affine.Discrete.Vector + Affine.Discrete.Ratio precedents

`Ordinal` exposes typed `Position + Count = Position` (`Ordinal.Protocol.swift:140-142`)
and `Position - Position = Vector` (`Affine.Discrete+Arithmetic.swift:86-102`).
The `Position + Count` operation is total because `Count: Carrier.Protocol<Cardinal>`
is unsigned and addition with an unsigned displacement preserves the
position invariant. The `Position - Position` operation returns a Vector
(signed displacement), not a Position, because subtracting two positions
yields a directed distance.

`Affine.Discrete.Vector` (`Affine.Discrete.Vector.swift:35-44`,
`Affine.Discrete.Vector+Carrier.swift:46-73`) exposes full `+`, `-`, `+=`,
`-=`, prefix `-` (negation). Vector is a signed displacement — it forms
a closed additive group (and a Z-module under Ratio scaling).

`Affine.Discrete.Ratio<From, To>` (`Affine.Discrete.Ratio.swift:45-56`,
`Tagged+Affine.swift:235-287`) provides typed scaling: `Tagged<From, Cardinal> * Ratio<From, To> = Tagged<To, Cardinal>`
and `Tagged<From, Vector> * Ratio<From, To> = Tagged<To, Vector>`. The
doc explicitly excludes position scaling:

> ## Type Safety: The type system prevents invalid operations:
> - `Offset<A> * Ratio<A,B>` → compiles, returns `Offset<B>`
> - `Offset<A> * Ratio<B,C>` → compile error (domain mismatch)
> - `Index<A> * Ratio<A,B>` → compile error (position scaling undefined)
>
> (`Affine.Discrete.Ratio.swift:36-39`)

The Ratio infrastructure is designed for unit scaling between *quantity
domains* (bits-per-byte, bytes-per-cache-line) — not for ad-hoc value
transformations like "convert from byte-offset to ASCII-digit-value." The
Affine machinery applies to Byte ONLY if a byte-domain typed-offset
(Byte.Offset = Tagged<Byte, Vector>) is introduced AND that offset has
genuine cross-domain consumers — both conditions evaluated in
§"Option γ" below.

#### 6. Tagged conformances (the recursive surface)

`Tagged<Tag, Underlying>` (per `swift-primitives/swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift`)
provides conditional `Equatable` / `Hashable` / `Comparable` / `Sendable`
conformances when `Underlying` conforms, and conditional
`ExpressibleByIntegerLiteral` when `Underlying: ExpressibleByIntegerLiteral`
(via `Tagged+Literals.swift:44-54`, `@_disfavoredOverload`). Today
`Tagged<Tag, Byte>` inherits comparison, equality, hashing, and literal
construction from Byte's stdlib conformances.

Any decision to lift arithmetic onto `Byte.Protocol` propagates to
`Tagged<Tag, Byte>` via the recursive conformance at
`swift-byte-primitives/Sources/Byte Primitives/Tagged+Byte.Protocol.swift:27-47`.
The lift to Protocol is therefore an over-applies risk for every future
phantom-tagged byte type (`Tagged<DeviceID, Byte>`, `Tagged<MessageOpcode, Byte>`, …).

### External — Inherited from byte-protocol-capability-marker.md v1.1.0

The parent's external survey covered:
- **Rust** trait coherence, orphan rule, newtype pattern (verified
  Rust Book ch10-02 + ch20-02, 2026-05-15);
- **Haskell** typeclass composition, newtype convention (verified
  HaskellWiki/Newtype, 2026-05-15);
- **Scala 3** `given`/`using` scoped conformance;
- **Swift** Numeric / BinaryInteger / FixedWidthInteger hierarchy
  (verified `swiftlang/swift Integers.swift`, 2026-05-15).

The parent's contextualization step ([RES-021]) established that the
cross-system convention for "different typeclass instances on the same
underlying value" is newtype wrapping — Sum/Product wrap Int because they
need a different `Monoid` instance from Int's default. The same shape
applies symmetrically to Q3: Byte adds byte-domain semantics that are
NOT UInt8's arithmetic semantics. Wrapping (Byte over UInt8) is the
right shape; *and* inviting arithmetic back into the wrapper undoes the
wrap.

The transitively-cited foundational SLR
([`phantom-typed-value-wrappers-literature-study.md`](./phantom-typed-value-wrappers-literature-study.md)
v1.0.0, 36 papers including Reynolds 1983, Wadler 1989, Hinze 2003,
Kennedy 1997) is inherited per [RES-019]/[RES-026]; this document does
not re-derive that material.

### Contextualization step ([RES-021])

**Pattern observed across external systems**: stdlib byte/octet types
in surveyed systems (Rust `u8`, Haskell `Word8`, Swift `UInt8`)
universally conform to their numeric typeclass hierarchies. One could
read this as "byte-domain types in surveyed systems support arithmetic,"
and infer that Byte should too.

**The contextualization step rejects this inference**:

1. **The surveyed systems do not have a separate byte-domain type from
   their arithmetic type.** `u8`/`Word8`/`UInt8` are simultaneously the
   arithmetic representation AND the byte-domain representation. There
   is no analog of the institute's `Byte` ↔ `UInt8` separation. The
   pattern "byte types support arithmetic" in those systems is a
   tautology: the byte type IS the arithmetic type.

2. **The institute deliberately introduced the separation.** Per
   [byte-primitive-extraction-and-domain-naming.md](./byte-primitive-extraction-and-domain-naming.md)
   §Context, the byte concept was extracted to its own L1 package
   *because* "UInt8 is the stdlib's byte representation, which carries
   semantics the institute deliberately avoids (Numeric, BinaryInteger,
   FixedWidthInteger)" (parent doc §4 "Open question"). The extraction
   IS the architectural commitment to separate the two surfaces.

3. **The pattern's domain in the institute is the Cardinal/Ordinal/Vector
   family, not Byte.** The institute already has a Numeric-equivalent
   surface — `Cardinal` (`+`, no `-`), `Ordinal` (`+ Count`, `-` via
   Affine), `Affine.Discrete.Vector` (full additive group). Each has its
   own typed semantics. Byte is structurally adjacent to but
   categorically distinct from those algebras — it is a capability
   marker, not an algebra.

The cross-system pattern "byte types support arithmetic" is therefore
NOT a gap in the institute's ecosystem — it is a deliberate design
decision visible in the institute's own architectural choices and
documented inline at multiple sources. The absence of arithmetic on Byte
is principled, not oversight.

## Algebra Comparison

The handoff brief identifies four ecosystem algebras (plus the
`Tagged<T, V>` lifting layer and the stdlib `FixedWidthInteger`) as
comparison targets. The comparison drives Q3.1 ("which algebraic shape
best models Byte's intrinsic semantics, if any?").

| Algebra | Total operators | Partial / Property.View | Identity / structural premise | Closed under group? |
|---------|----------------|-------------------------|--------------------------------|---------------------|
| `Cardinal` | `+`, `+=`, comparison, literal | `.subtract.saturating`, `.subtract.exact` (Property.View) | IS a quantity (cardinality) | No: `-` partial (underflow) |
| `Ordinal` | `+ Count = Self`, `+=` | `.successor`/`.predecessor` (Property.View), `.advance`, `.distance` | IS a position | No: addition is total only with Count; subtraction yields Vector, not Self |
| `Affine.Discrete.Vector` | `+`, `-`, `+=`, `-=`, prefix `-`, comparison, literal | — | IS a signed displacement | Yes: closed additive group on Z |
| `Tagged<T, V>` | Inherits from V (lifted) | Inherits | Phantom-typed wrapper | Inherits from V |
| stdlib `FixedWidthInteger` | Full Numeric + bitwise + wrapping | — | IS an arithmetic integer | Yes: closed under modular arithmetic |
| **Byte (current)** | comparison, literal, bitwise (`& \| ^ ~ << >>`) | — | IS an opaque 8-bit datum | N/A: not an arithmetic algebra |

The discipline-per-algebra distillation:

- **Cardinal**: total `+` is admissible because adding cardinalities IS a
  cardinality. Partial `-` is principled-NO at the operator level because
  subtraction on naturals is not total; the institute exposes it as a
  Property.View instead so the saturation policy is explicit at the call
  site. The Cardinal precedent is the **closest existing analogue** for
  "unsigned domain whose underlying wraps but where unchecked subtraction
  is principled-NO." That analogy is what the handoff brief anchored
  Option β on; the test for Option β below evaluates whether Byte fits
  Cardinal's structural premise.

- **Ordinal**: arithmetic is typed (`+ Count`, `- → Vector`). Position
  arithmetic is total only when the displacement is unsigned (Count) and
  the result remains a position. Mixed-domain operations route through
  Vector. The Ordinal precedent applies if Byte is a position-like
  entity; it is not (§Q3.1 below).

- **Affine.Discrete.Vector**: full closed group because Vector IS a
  directional displacement. The precedent applies if Byte is a directed
  quantity; it is not.

- **Tagged**: lifts whichever surface its Underlying provides. Tagged is
  not its own algebra; it is the discipline of "preserve the algebra,
  add a phantom dimension." Tagged does not constrain Q3.

- **FixedWidthInteger**: full numeric + bitwise + wrapping. The precedent
  applies if Byte IS UInt8-in-different-clothes; the institute's existing
  position (byte-protocol-capability-marker.md Q1) rejects that framing.
  Re-litigating it is Q3's structural test.

### Q3.1 — Byte's intrinsic semantics

The institute's documented framing of Byte (across Byte.swift,
Byte.Protocol.swift, byte-extraction-arc-doc, byte-protocol-capability-marker.md,
bsli-gap-inventory.md):

> `Byte` answers "what is one byte of data?" — distinct from `UInt8`,
> which answers "what is one 8-bit unsigned integer?" The semantic
> separation matters in the institute's type system: `UInt8` participates
> in arithmetic algebras; `Byte` participates in byte-stream domains
> (file content, network payloads, hex encodings, parser inputs).
> (`Byte.swift:3-9`)

Byte's intrinsic semantics include:

| Capability | Reason |
|-----------|--------|
| Identity (`==`) | Two bytes are equal iff their bit patterns coincide |
| Ordering (`<` `<=` `>` `>=`) | Total order on UInt8 — used in byte-stream parsing (range checks `b >= 0x30 && b <= 0x39`) |
| Bitwise (`& \| ^ ~ << >>`) | Bit-level structure of an 8-bit datum is meaningful |
| Literal expression (`0xFF`) | Byte constants in tests and parsers |
| Hashing | Bytes are hash table keys (byte-stream matching, parser-state hashing) |
| Sendability | Bytes are value types with no reference semantics |

Byte's intrinsic semantics do NOT include:

| Operation | Why not |
|-----------|---------|
| `Byte + Byte = Byte` | No intrinsic byte-domain interpretation of "two bytes added." The numeric sum has integer-domain meaning, not byte-domain meaning. The bitwise composition that *could* mean "byte-wise add modulo 256" is wrap-around UInt8 arithmetic, which is `UInt8 &+ UInt8` (the carrier's operator), not a byte-domain operation. |
| `Byte - Byte` | Two bytes have no intrinsic directed distance. The difference between '9' (0x39) and '0' (0x30) is meaningful only in the ASCII encoding interpretation — i.e., as a domain *layered on top of* the byte representation, not as byte semantics. Cardinal's principled-NO on `-` is structural (subtraction on naturals is partial); Byte's principled-NO is categorical (subtraction on opaque data has no result type — it can't be Byte). |
| `Byte * Cardinal` | No intrinsic "scale a byte" operation. Multiplying a byte by 4 is either (a) widening the byte to integer and multiplying (arithmetic-domain operation) or (b) replicating the byte four times (storage-domain operation, returning `[Byte]` or `Buffer<Byte>`, not `Byte`). Neither result type is `Byte`. |
| `Byte * Byte` | No intrinsic meaning. The numeric product overflows UInt8 for most operand pairs. |
| `byte &+ 1` (wrapping increment) | Wrapping increment treats the byte as a counter. Counters are positions on a number line — `Index<Byte>` or `Tagged<CounterTag, Cardinal>` is the right type, not `Byte`. |

The test for an arithmetic shape (Cardinal-shaped, Ordinal-shaped,
Vector-shaped) is whether Byte's structural premise admits the operation
in a coherent codomain. The test **fails for every shape** on Byte:

| Shape | Test | Outcome |
|-------|------|---------|
| Cardinal-shaped (`+`, no `-`) | Does adding two Bytes yield a coherent Byte? | No — sum is integer-domain |
| Ordinal-shaped (`+ Count`, `- → Offset`) | Is Byte a position? | No — Byte is an opaque datum, not a position |
| Vector-shaped (closed `+ - *`) | Is Byte a signed displacement? | No — Byte has no directionality |
| FixedWidthInteger | Is Byte an arithmetic integer? | No — that's UInt8; Byte is the byte-domain twin |

The intrinsic-semantics analysis is decisive on Q3.1: **none of the
arithmetic algebras model Byte.** Adopting any of them onto Byte
imposes a structural premise Byte does not satisfy; the resulting type
becomes "Byte plus a borrowed semantics from a different algebra,"
which is the bundle-conflict shape Q1 rejected.

### Note on the Cardinal precedent (specific)

The Cardinal precedent is the closest analog because Cardinal — like
Byte — wraps an unsigned stdlib carrier (UInt vs UInt8) and exposes
operators that the stdlib carrier supports. But the Cardinal `+` lift
rests on Cardinal IS a quantity: two `Cardinal(3) + Cardinal(4)`
quantities IS a `Cardinal(7)` quantity. Byte fails the same test:
`Byte(0x30) + Byte(0x39)` — what byte does that produce? The numerical
sum (0x69) is byte 'i'. That's not a meaningful byte-domain operation;
the operation that produced 'i' is arithmetic-domain widening +
subtraction, not byte-domain composition.

The Cardinal precedent rules out Option β specifically: Cardinal-shape
requires Cardinal's structural premise; Byte does not satisfy it.

## `.underlying` Site Inventory

Per [HANDOFF-013] / [RES-019], a workspace-wide grep was conducted to
enumerate every `.underlying` access on a `Byte`-typed value across the
swift-primitives / swift-standards / swift-foundations packages. Sites
in test code and same-package internal Byte machinery are excluded. The
categorization follows the handoff brief's six-category taxonomy plus
three categories surfaced during inventory (C6 comparison-only, C7
bit-field-extraction, C8 stdlib-property-access).

### Inventory at HEAD (2026-05-19)

Verified workspace-wide grep at HEAD 2026-05-19; test code excluded;
`.underlying` accessor on Byte-typed receiver only. **Aggregate:**
114 site-categorizations across 86 unique source lines (some lines
carry two categorizations — LEB128 sites combine "bit-field via lifted
Byte `&`" with "byte→Int widening via the BSLI constructor"). The live
empirical record of substrate-migration triage is at
[`swift-byte-primitives/Research/bsli-gap-inventory.md`](../../swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md)
§"`.underlying` triage from the Byte substrate migration arc."

A category surfaced during inventory that the handoff brief's taxonomy
did not anticipate: **[C1c]** — byte→wider-int widening via the existing
landed BSLI constructors (`UInt16(byte)`, `Int8(bitPattern: byte)`,
etc.). These sites do NOT use `.underlying` — they prove the BSLI
absorption shape WORKS at scale. They are listed because the brief's
Task 3 asked for "Byte arithmetic done via something OTHER than
`.underlying`":

| Category | Pattern | Production sites | Top files | Disposition |
|----------|---------|------------------|-----------|-------------|
| **C1** Up-conversion via `.underlying` (`Int64(byte.underlying)`) | Endianness decode, LEB128 widening | **0** direct sites | — | Subsumed by [C1c] |
| **[C1c]** Up-conversion via byte-domain constructor (the replacement-pattern that displaced what C1 would have been) | `UInt16(byte)`, `UInt32(byte)`, `Int8(bitPattern: byte)`, `UInt64(byte)` | **73** | `Binary.Bytes.withBorrowed.swift` (50), `Binary.Bytes.Machine.Run.swift` (23) | **Already covered by landed BSLI** ([`Integer+Byte.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives%20Standard%20Library%20Integration/Integer%2BByte.swift)) |
| **C2** Pure byte+byte arithmetic returning byte (`byte1 + byte2 = byte`) | — | **0** | — | No demand exists in production |
| **C3** Bounded subtraction via `.underlying` (`byte.underlying - 0x30` for ASCII digit decode) | ASCII decimal digit decode | **2** | [`Binary.ASCII.Parsing.Machine.Decimal.swift:58`, `:119`](../../swift-foundations/swift-ascii/Sources/ASCII/Binary.ASCII.Parsing.Machine.Decimal.swift) (`return T(byte.underlying - 0x30)`) | **MIGRATE** — use existing `ASCII.Code.digitValue` accessor |
| **C4** Mixed bitwise + arithmetic (`UInt64(byte & 0x7F) << shift` LEB128 7-bit payload) | LEB128 ULEB128/SLEB128 accumulator | **6** (each line also tagged [C1c]) | `Binary.Bytes.withBorrowed.swift:613, 639, 1137, 1163`, `Binary.Bytes.Machine.Run.swift:439, 465` | **Already covered**: `byte & 0x7F` is `Byte.Protocol+Bitwise`'s lifted `&`; the `UInt64(...)` is BSLI [C1c]. No `.underlying` required. |
| **C5** Wrapping arithmetic (`byte.underlying &- 0x30`) | ASCII digit decode (wrapping variant of C3) | **1** | [`ASCII.Decimal.Parser.swift:43`](../../swift-primitives/swift-ascii-parser-primitives/Sources/ASCII%20Decimal%20Parser%20Primitives/ASCII.Decimal.Parser.swift) | **MIGRATE** — same `ASCII.Code.digitValue` route as C3 |
| **C6** Comparison via `.underlying` (`observed.underlying == byte`) | Cross-stdlib-boundary UInt8 compare | **1** | [`Byte.Input.View.swift:106`](../../swift-primitives/swift-byte-parser-primitives/Sources/Byte%20Parser%20Primitives/Byte.Input.View.swift) | Migration debt; resolvable via `Byte: Comparable`. Not an arithmetic gap. |
| **C7** Bit-field via `.underlying` (`byte.underlying & mask`) | — | **0** | — | Byte.Protocol+Bitwise lifts these; byte-level `&`/`\|`/`^`/`~`/`<<`/`>>` already returns Byte |
| **C8** stdlib FixedWidthInteger property (`byte.underlying.nonzeroBitCount`) | — | **0** | — | Future BSLI candidate if demand appears |
| **C9a** Predicate forwarding (`ASCII.Classification.isDigit(byte.underlying)`) | Version / Lexer ASCII classification | **17** | `Version.*.Parser.swift` (13), `Lexer.Classify.swift` (4) | **MIGRATE** — use existing `ASCII.Code.isDigit` / `.isLetter` / `.isAlphanumeric` / `.isHexDigit` (already live in `ASCII.Code+Classification.swift`) |
| **C9b** String-radix rendering (`String(byte.underlying, radix: 16)`) | Diagnostic hex format | **5** | `Binary.Bytes.Machine.Error.swift` (3), `Byte.Parser.swift:47` (1), `Byte.Literal.Parser.swift:67` (1) | **PERMANENT** — Byte hex rendering explicitly excluded per byte-protocol-capability-marker.md |
| **C9c** Extract for `[UInt8]`/buffer storage | Buffer serializer, URL byte staging, u8-reinterpret | **5** | `Byte.Serializer.swift:44`, `Byte.Input.View.swift:130`, `Manifest.Parent.swift:96`, `withBorrowed.swift:461, 985`, `Run.swift:293` u8 reinterpret | **PERMANENT or REVISIT** — serializer/manifest boundary sites; u8 reinterpret is `.u8` decoder output (semantically integer-domain) |
| **C9d** Diagnostic byte-array repacking (`[expected.underlying, actual.underlying]`) | Error message construction | **2 lines, 4 accesses** | `Byte.Parser.swift:51`, `Byte.Literal.Parser.swift:71` | **PERMANENT** — diagnostic payloads use stdlib `[UInt8]` |
| **C9e** Cross-type init forward | ASCII.Code(Byte) → ASCII.Code(UInt8) bridge | **1** | `ASCII.Code+Byte.Protocol.swift:36` | Designed boundary — ASCII.Code conformance to Byte.Protocol |
| **C9f** Bound-then-switch (extract once, route via switch) | ASCII hex digit decode | **1** | [`ASCII.Hexadecimal.Parser.swift:59`](../../swift-primitives/swift-ascii-parser-primitives/Sources/ASCII%20Hexadecimal%20Parser%20Primitives/ASCII.Hexadecimal.Parser.swift) (`let raw = byte.underlying` then `switch raw { case 0x30...0x39: ... }`) | **MIGRATE** — use existing `ASCII.Code.hexValue` (already live in `ASCII.Code+Parsing.swift`) |

### Inventory summary

| Category | Production sites | Direct arithmetic beneficiary? | Resolution |
|----------|------------------|--------------------------------|------------|
| C1 → [C1c] up-conversion | 73 | No (BSLI-resolved) | landed `UInt16/32/64(byte)`, `Int8/16/32/64(byte)`, `Int*.init(bitPattern:byte)` |
| C2 pure byte+byte | **0** | n/a (zero demand) | nothing to address |
| C3 bounded subtraction | **2** | **Yes** | escalate to ASCII.Code arc |
| C4 mixed bitwise + arithmetic | 6 | No (already covered) | Byte.Protocol+Bitwise `&` + BSLI [C1c] |
| C5 wrapping arithmetic | **1** | **Yes** | escalate to ASCII.Code arc (variant of C3) |
| C6 comparison via `.underlying` | 1 | No | migration debt |
| C7 bit-field via `.underlying` | **0** | No (Byte.Protocol+Bitwise) | already lifted |
| C8 stdlib FixedWidthInteger property | **0** | No | future BSLI candidate |
| C9a predicate forwarding | 17 | No (sibling-overload opportunity) | ASCII.Code arc |
| C9b string-radix render | 5 | No | **PERMANENT** |
| C9c buffer extract | 5 | No | **PERMANENT** (stdlib interop) |
| C9d diagnostic repack | 4 accesses on 2 lines | No | **PERMANENT** (diagnostic payload) |
| C9e cross-type init forward | 1 | No | designed boundary |
| C9f bound-then-switch | 1 | No (switch on UInt8 post-extract) | ASCII.Code arc |

**Direct arithmetic beneficiaries**: **3 production sites** —
2 × C3 (`Binary.ASCII.Parsing.Machine.Decimal.swift:58, 119`) and
1 × C5 (`ASCII.Decimal.Parser.swift:43`). All three are ASCII digit
decode; **all three migrate to the already-existing
`ASCII.Code.digitValue` accessor** in
[`ASCII.Code+Parsing.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BParsing.swift).

**Category-distribution conclusion**: the empirical record is
unambiguous. **C2 has zero sites** (no demand for `Byte + Byte = Byte`).
**C7 has zero sites** (Byte.Protocol+Bitwise covers what's needed).
**C8 has zero sites**. The 73 [C1c] sites prove the BSLI absorption
shape WORKS at scale — that pattern is the institute's existing
ergonomic answer to widening. The 17 C9a predicate-forwarding sites +
3 ASCII-arithmetic sites (C3 + C5) + 1 C9f bound-then-switch site all
route to a single architectural home: **a ASCII.Code migration arc in
swift-ascii-primitives**. The remaining PERMANENT sites (C9b/c/d =
13 stdlib-interop bridges) are intentional. Across 86 unique
`.underlying` lines, **0 sites require byte arithmetic ON BYTE**.

### Note on the C3/C5 ASCII-decode shape

The two `Binary.ASCII.Parsing.Machine.Decimal.swift` sites (lines 58, 119)
plus the parallel `ASCII.Decimal.Parser.swift:43` (which uses `&-`
instead of `-`) are the canonical exemplars of the question. The
current shape (from `Binary.ASCII.Parsing.Machine.Decimal.swift:46-58`):

```swift
let digit = M.take1(in: &builder).tryMap({ byte throws(M.Fault) -> T in
    guard byte >= 0x30 && byte <= 0x39 else {
        throw .predicateFailed(byte: byte)
    }
    return T(byte.underlying - 0x30)
}, in: &builder)
```

The `byte >= 0x30 && byte <= 0x39` guard relies on `Byte: Comparable + ExpressibleByIntegerLiteral`
(both already present). The arithmetic `byte.underlying - 0x30` is
UInt8 arithmetic; the result is converted to `T` (the target integer
type, parameterized as `T: UnsignedInteger & FixedWidthInteger`).

The mathematical operation is `decode_ascii_digit: Byte → Int` defined
only for ASCII-digit bytes. This is a **boundary operation** between
the byte-domain and the integer-domain. Three structural shapes can
host it:

1. **In-byte-domain arithmetic** (Options α/β/γ/δ): Byte gains
   subtraction; `byte - 0x30 = Byte`; consumer converts `T(byte)` via
   BSLI #1. Cost: dissolves byte-vs-arithmetic separation; introduces
   a `Byte` value whose interpretation depends on context.
2. **Boundary helper on Byte** (Option ε): `byte.asciiDigit: Int?` or
   similar BSLI overload returning a typed integer at the byte → integer
   boundary. Cost: ASCII-specific helper on the byte-domain type misplaces
   the ASCII abstraction.
3. **Domain-specific type** (Option ζ-with-migration): `ASCII.Code`
   already exists in `swift-ascii-primitives` ([`ASCII.Code.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code.swift)),
   already conforms to `Byte.Protocol` ([`ASCII.Code+Byte.Protocol.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BByte.Protocol.swift)),
   and already exposes the ASCII-domain decode operations: `digitValue: UInt8?`
   and `hexValue: UInt8?` (in [`ASCII.Code+Parsing.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BParsing.swift)),
   plus the full `isDigit` / `isLetter` / `isAlphanumeric` / `isHexDigit` /
   `isUppercase` / `isLowercase` / `lowercased()` / `uppercased()` surface
   in [`ASCII.Code+Classification.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BClassification.swift).
   Cost: migrate consumer sites — typing decisions, no new types or
   accessors.

Option ζ-with-migration is structurally preferred per the discipline
already established by [byte-primitive-extraction-and-domain-naming.md](./byte-primitive-extraction-and-domain-naming.md)
Decision #1 (LargerDomain.Subdomain): ASCII is the larger domain, byte
is the byte-domain substrate, "the role is the leaf; the subject owns
the namespace." ASCII-domain digit decoding lives in the ASCII
namespace — and the live API surface already does. The post-migration
shape of the canonical site is:

```swift
let digit = M.take1(in: &builder).tryMap({ byte throws(M.Fault) -> T in
    guard let value = ASCII.Code(byte).digitValue else {
        throw .predicateFailed(byte: byte)
    }
    return T(value)
}, in: &builder)
```

No arithmetic on Byte; `ASCII.Code.digitValue` encapsulates the
byte → digit conversion in its proper home. The guard becomes an
optional-binding because `digitValue` already returns `UInt8?`.

## Design Space — Options Enumeration

Per [RES-009] / [RES-022], all viable options are enumerated and
evaluated against the Task-3 inventory and the §Algebra comparison
criteria, with structural correctness prioritized.

### Option α — Full BinaryInteger / Numeric conformance

```swift
extension Byte: AdditiveArithmetic, Numeric, BinaryInteger, FixedWidthInteger { ... }
```

Byte gains the entire stdlib numeric hierarchy: `+`, `-`, `*`, `/`, `%`,
`&+`, `&-`, `&*`, `<<`, `>>` (overlapping with existing bitwise lifts),
`init(integerLiteral:)`, Strideable, bitWidth, etc.

**Smell-site elimination count** (from inventory):
- C1 (up-conversion): unchanged — BSLI #1 already covers; Numeric does
  not add anything.
- C2 (byte+byte): 0 sites become 0 sites. No elimination because no sites.
- C3 (bounded subtraction): 2 sites become `T(byte - 0x30)` (where `byte - 0x30`
  is `Byte - Byte = Byte`). 2 sites resolved syntactically; semantic
  dilution introduced.
- C4 (mixed bitwise + arith): unchanged — composition of `& 0x7F` + `<<`
  + widening already works; arithmetic doesn't add value.
- C5 (wrapping): wrapping add `&+ 1` becomes available; 0 sites in
  inventory.
- C6 (comparison): unchanged (already covered by Comparable).
- C7 (bit-field): unchanged.
- C8 (FixedWidthInteger properties): now reachable as `byte.nonzeroBitCount`
  directly. Eliminates the `UInt8(byte).nonzeroBitCount` BSLI bridge.
- C9 (hex / diagnostic): hex would be reachable via Numeric's
  `String(_:radix:)`. **This contradicts byte-protocol-capability-marker.md's
  explicit hex-rendering rejection.**

**Semantic-dilution cost**: maximum. Byte becomes structurally
indistinguishable from UInt8 modulo nominal type. Q1's bundle-conflict
analysis applies symmetrically — operator shadow inverts (Byte's
Numeric defaults shadow byte-domain operators), API surface broadens
(Numeric-generic algorithms now accept Byte), Tagged composition
pollutes (`Tagged<Tag, Byte>` becomes Numeric and `tag1 + tag2` admits
arithmetic across phantom domains).

**Operator-shadow risk with `ExpressibleByIntegerLiteral`**: `byte + 1`
resolves via integer-literal init on Byte → `Byte + Byte = Byte`. The
boundary disappears entirely; the author writes byte arithmetic without
noticing the semantic shift.

**`Byte.Protocol` lift**: if conformance is on Byte directly (not on
Byte.Protocol), `Tagged<Tag, Byte>` and future byte-domain types
(ASCII.Code, UTF8.Code_Unit) do NOT inherit. If on Byte.Protocol, all
conform — including ASCII.Code which wants ASCII-domain `digit:` accessors
not byte arithmetic. **Lift to Protocol is structurally wrong**; lift
to Byte alone preserves the divergence but adds Byte-only arithmetic
that doesn't compose with the Byte.Protocol generic surface.

**`Carrier.Protocol<UInt8>` interaction**: ASCII.Code (future Byte.Protocol
conformer) ALSO conforms to `Carrier.Protocol<UInt8>` per parent doc
§Open Question 4.B. If arithmetic lives on Byte.Protocol, ASCII.Code
inherits unwanted arithmetic; if on Byte alone, ASCII.Code does not
gain arithmetic but consumers writing `<B: Byte.Protocol>(_ b: B)` cannot
use byte arithmetic generically — defeating the lift's purpose.

**Verdict**: REJECTED. Dissolves the byte-vs-arithmetic separation,
contradicts byte-protocol-capability-marker.md's symmetric framing,
forces a per-site Byte-vs-Protocol placement decision that has no
correct answer.

### Option β — Cardinal-shaped (`+`, `+=`, `.subtract.saturating()`, `.subtract.exact()`, comparison; NO `-`, NO `*`, NO `/`)

```swift
extension Byte.`Protocol` {
    public static func + (lhs: Self, rhs: Self) -> Self { ... }   // trapping
    public static func += (lhs: inout Self, rhs: Self) { ... }
    public var subtract: Property<Subtract, Self> { ... }          // Property.View
}
extension Property where Tag == Byte.Subtract, Base: Byte.`Protocol` {
    public func saturating(_ other: Base) -> Base { ... }          // monus
    public func exact(_ other: Base) throws(Byte.Error) -> Base { ... }
}
```

Mirrors Cardinal's discipline exactly: `+` total, `-` Property.View'd.

**Smell-site elimination count**:
- C1 (up-conversion): unchanged.
- C2: 0 sites — no elimination.
- C3 (bounded subtraction): 2 sites become `T(byte.subtract.exact(0x30))` (throws),
  or `T(byte.subtract.saturating(0x30))` (silently zeros invalid input).
  **Both forms are worse than the current `T(byte.underlying - 0x30)` after
  a `byte >= 0x30` guard**: the guard already precludes underflow; the
  Property.View form re-checks at runtime or silently saturates. The
  current site's guard-and-arithmetic pattern is *more efficient* and *more
  type-safe* than Property.View'd subtraction.
- C4, C5, C6, C7: unchanged.
- C8: unchanged.
- C9: unchanged.

**Semantic-dilution cost**: high. Cardinal-shape requires Cardinal's
structural premise ("IS a quantity"). Byte is NOT a quantity. Adopting
Cardinal-shape attaches quantity-semantics to byte values where they
don't belong.

**Cardinal precedent fit test**: Cardinal's `+` is admissible because
two cardinalities IS a cardinality. Two bytes added is NOT a byte (it's
an integer-domain sum). The structural premise that justifies Cardinal's
`+` does not hold for Byte; transferring the shape is mechanical
mimicry, not semantic alignment.

**Verdict**: REJECTED. The Cardinal shape requires a structural premise
Byte does not satisfy. Mechanically transferring the shape attaches
quantity semantics to a non-quantity, which is a category error.

### Option γ — Ordinal-shaped (`+ Byte.Offset = Byte`, `Byte - Byte = Byte.Offset`)

Introduces `Byte.Offset = Tagged<Byte, Affine.Discrete.Vector>` (parallel
to `Index<T>.Offset`).

```swift
extension Byte {
    public typealias Offset = Tagged<Byte, Affine.Discrete.Vector>
}
extension Byte.`Protocol` {
    public static func + (lhs: Self, rhs: Self.Offset) throws -> Self { ... }
    public static func - (lhs: Self, rhs: Self) -> Self.Offset { ... }
}
```

**Pre-condition**: requires Byte to be a *position* on a number line. The
LEB128 bit-shift accumulator pattern treats bytes as 7-bit "digits" being
shifted; one could argue that admits a position interpretation. The ASCII
decimal decode treats '0'…'9' as a contiguous range; one could argue that
admits a position interpretation.

**Both arguments fail the structural test**:
- LEB128 treats *widened* values (Int64) as positions on the accumulator's
  number line; the byte is the input alphabet, not the position. The
  accumulator is the position; `Index<Bit>` or `Index<Byte>` could model
  the bit/byte position within the encoded payload. The Ordinal precedent
  applies to those positions, not to the byte alphabet itself.
- ASCII decimal decoding wants the *integer value* of a digit byte, not a
  *displacement within the byte alphabet*. The conversion from `byte` to
  `digit: Int` is decoding — a semantic mapping — not a position
  displacement.

**Affine.Discrete.Ratio angle (per principal's added hint)**: Could
`Byte * Affine.Discrete.Ratio<Byte, Int> → Int` model ASCII decode? No,
for two reasons:
1. `Affine.Discrete.Ratio.swift:36-39` documents that Ratios act on
   vectors/counts (signed displacements and unsigned quantities), NOT on
   positions: "`Index<A> * Ratio<A,B>` → compile error (position scaling
   undefined)." Byte-as-position would also fall under that exclusion.
2. The ASCII-decimal-decode mapping (byte → integer-digit-value) is NOT
   a multiplicative scaling. It is an affine subtraction (`byte - '0'`)
   followed by a domain-cast. Ratio scales by a factor; ASCII decode
   subtracts by an offset. The Ratio shape does not apply.

**Smell-site elimination count**:
- C3 (bounded subtraction): 2 sites become `T(byte - 0x30)` if Byte.Offset
  is convertible to T. The `byte - 0x30` is `Byte - Byte = Byte.Offset`; the
  `T(byte - 0x30)` requires `T.init(_:Byte.Offset)` BSLI overloads (new
  surface — not currently in BSLI inventory). Net new infrastructure cost:
  Byte.Offset type + per-T BSLI overload set.
- C2, C5: still 0 sites.
- C1, C4, C7: unchanged.
- C6: unchanged.

**Semantic-dilution cost**: medium-high. Byte.Offset is a new typed-offset
type that has no cross-domain consumer (Byte is not a position; no other
domain wants to scale into Byte's number line). Per [RES-018] case-(a)
cross-cutting primitive gate: would need a second-domain consumer.

**Verdict**: REJECTED. Byte is not a position; Byte.Offset has no
cross-domain consumer beyond the synthetic ASCII-decode use case;
Affine.Discrete.Ratio is structurally not applicable; the per-T BSLI
overload set is new infrastructure with no proportionate benefit.

### Option δ — Targeted operators only (`+`, `-`, `&+`, `&-`, `<<`, `>>` returning `Byte`; NO protocol conformance to Numeric / BinaryInteger)

```swift
extension Byte {
    public static func + (lhs: Self, rhs: Self) -> Self { ... }
    public static func - (lhs: Self, rhs: Self) -> Self { ... }
    public static func &+ (lhs: Self, rhs: Self) -> Self { ... }
    public static func &- (lhs: Self, rhs: Self) -> Self { ... }
}
```

Operators without protocol conformance to Numeric. Byte gains byte-arithmetic
*syntax* but does not surface in Numeric-generic algorithms.

**Smell-site elimination count**: same as Option α at the syntactic level
(C3 sites resolved as `T(byte - 0x30)`); same as Option ζ at the
generic-algorithm level (Byte still does not work in Numeric-generic
code).

**Semantic-dilution cost**: high. δ is "Byte has byte-arithmetic operators
but isn't a Numeric type." This is the **worst of both worlds**: byte
arithmetic that *looks like* it has a semantic foundation (matching
Numeric's operator syntax) but *doesn't actually* have one (no Numeric
conformance to anchor it). Authors writing `byte + byte` get a result
they assume is byte-arithmetic-semantic; the result is actually `UInt8 + UInt8`
wrapped in Byte clothes.

**Verdict**: REJECTED. Splits the difference badly — the syntactic gain
is offset by the semantic confusion. Worse than either α (full
Numeric) or ζ (no arithmetic), without the structural justification of
either extreme.

### Option ε — BSLI helpers only (`Byte.asciiDigit: Int?`, `Byte.shifted(by:)`, `Byte.advanced(by:)`, etc.)

```swift
extension Byte {
    public var asciiDigit: Int? { ... }          // ASCII-specific helper on Byte
    public func shifted(by: UInt8) -> Byte { ... }   // duplicate of `<<`/`>>`
    public func advanced(by: Int) -> Byte { ... }    // wrapping advance
}
```

**Smell-site elimination count**:
- C3 (ASCII bounded subtraction): 2 sites become
  `byte.asciiDigit.map(T.init)` or similar. **But Byte is the wrong
  namespace** — the ASCII-digit concept belongs in the ASCII namespace
  (per [byte-primitive-extraction-and-domain-naming.md](./byte-primitive-extraction-and-domain-naming.md)
  Decision #1 LargerDomain.Subdomain). Placing `asciiDigit` on Byte
  inverts the architecture: ASCII is the larger domain, Byte is the
  byte-domain substrate; helpers should live on `ASCII.Code.digit`, not
  on `Byte.asciiDigit`.
- `byte.shifted(by:)` duplicates `byte << amount` (already on
  Byte.Protocol).
- `byte.advanced(by:)` is meaningless on Byte (not a position).

**Semantic-dilution cost**: medium. Adds domain-specific accessors to
the byte-domain type, where they don't belong. The ASCII case in
particular is **structurally a misplacement** per the LargerDomain
discipline.

**Verdict**: REJECTED *as proposed for Byte*. The PARTIAL form of ε —
where ASCII-domain helpers live in `swift-ascii-primitives` on a
`Byte.Protocol`-conforming `ASCII.Code` type — IS the recommended path
(see Option ζ-with-migration). **`ASCII.Code` and the relevant
helpers already exist in `swift-ascii-primitives`**; the migration is
to USE them, not BUILD them. The misplacement is what makes Option
ε wrong; reaching for the live ASCII-namespace API is what makes
Option ζ-with-migration work.

### Option ζ — Status quo (`.underlying` ceremony stays; ASCII-arithmetic consumer-migrates to existing ASCII.Code)

No arithmetic operators are added to Byte or Byte.Protocol.

**`.underlying` extraction at boundary sites** is preserved as the
explicit byte-domain → arithmetic-domain conversion. Per [IMPL-010]
(boundary-conversion-at-method-boundary discipline), the boundary IS
where conversion lives; the explicit extraction makes the boundary
syntactically visible.

**Smell-site elimination count**:
- C1: covered by landed BSLI (`UInt16/32/64(byte)`, `Int8/16/32/64(byte)`,
  `Int*.init(bitPattern:byte)`).
- C2: no sites; nothing to eliminate.
- C3: **migrate** to the already-live `ASCII.Code` API in
  `swift-ascii-primitives`. `ASCII.Code` is a Byte.Protocol conformer
  ([`ASCII.Code+Byte.Protocol.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BByte.Protocol.swift))
  with these accessors already in production
  ([`ASCII.Code+Parsing.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BParsing.swift)):

  ```swift
  extension ASCII.Code {
      /// The decimal digit value (0-9) if this code is an ASCII digit, nil otherwise.
      public var digitValue: UInt8? { ASCII.Parsing.digit(underlying) }
      /// The hex digit value (0-15) if this code is an ASCII hex digit, nil otherwise.
      public var hexValue: UInt8? { ASCII.Parsing.hexDigit(underlying) }
  }
  ```

  The full `isDigit` / `isHexDigit` / `isLetter` / `isAlphanumeric` /
  `isUppercase` / `isLowercase` / `lowercased()` / `uppercased()`
  surface also already lives in
  [`ASCII.Code+Classification.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BClassification.swift).

  The ASCII decimal-decode site becomes:

  ```swift
  let digit = M.take1(in: &builder).tryMap({ byte throws(M.Fault) -> T in
      guard let value = ASCII.Code(byte).digitValue else {
          throw .predicateFailed(byte: byte)
      }
      return T(value)
  }, in: &builder)
  ```

  No arithmetic on Byte; the live ASCII-domain accessor encapsulates the
  byte → digit conversion in its proper home. The 2 sites currently in
  `Binary.ASCII.Parsing.Machine.Decimal.swift` move with the ASCII-domain
  arc, not as part of this doc.

- C4, C5, C6, C7: covered by existing infrastructure (BSLI bridges +
  Byte.Protocol bitwise + Byte Comparable + Byte ExpressibleByIntegerLiteral).
- C8: bridges via the `UInt8(byte)` chain (future BSLI candidate per
  bsli-gap-inventory.md "Future Candidates" section).
- C9: PERMANENT bridge (explicit per parent doc).

**Semantic-dilution cost**: ZERO. The byte-vs-arithmetic identity
separation is preserved. Byte remains the byte-domain twin; UInt8
remains the arithmetic carrier; ASCII.Code remains the live byte-domain
ASCII conformer with `digitValue` / `hexValue` / classification
accessors already in production.

**Verdict**: RECOMMENDED. Preserves Q1's structural framing from the
other side; routes the residual friction to its architecturally correct
home.

### Comparison matrix

| Criterion | α | β | γ | δ | ε | **ζ (recommended)** |
|-----------|---|---|---|---|---|----|
| [C1c] sites covered (73) | already landed | already landed | already landed | already landed | already landed | **already landed** |
| C2 sites resolved (0) | 0/0 | 0/0 | 0/0 | 0/0 | 0/0 | **0/0** |
| C3 sites resolved (2) | 2/2 (in Byte) | 2/2 (in Byte) | 2/2 (in Byte) | 2/2 (in Byte) | 2/2 (in Byte, wrong namespace) | **2/2 (in ASCII.Code)** |
| C5 sites resolved (1) | 1/1 (`&-` on Byte) | partial (no `-`, only `.subtract`) | partial (Offset path) | 1/1 (`&-` on Byte) | 1/1 (helper) | **1/1 (in ASCII.Code)** |
| C7 sites resolved (0) | existing | existing | existing | existing | existing | **existing** |
| C9a predicate forwarding (17) | unchanged | unchanged | unchanged | unchanged | unchanged | **resolved via ASCII.Code overloads** |
| Byte-vs-arithmetic separation preserved | ✗ | ✗ | ✗ | ✗ | ✗ (misplaced) | **✓** |
| Cardinal-precedent structural fit | n/a | ✗ | n/a | n/a | n/a | **n/a** |
| Operator-shadow with `ExpressibleByIntegerLiteral` | ✗ collapses | ✗ collapses | partial | ✗ collapses | ✓ | **✓** |
| Byte.Protocol lift safety (ASCII.Code, UTF8.Code_Unit) | ✗ over-applies | ✗ over-applies | ✗ over-applies | n/a | n/a | **✓** |
| Carrier.Protocol<UInt8> composition | ✗ pollutes | ✗ pollutes | ✗ pollutes | ✗ pollutes | n/a | **✓** |
| New infrastructure cost | — | Property.View Subtract | Byte.Offset + per-T BSLI | — | helpers on wrong type | **none — ASCII.Code with `digitValue`/`hexValue`/classification accessors already lives** |

## Cross-Cutting

### Q3.4 — Integer-literal interaction (`byte + 1`)

Per the parent doc's §"Operator-shadow risk with ExpressibleByIntegerLiteral",
this question is load-bearing for any option that admits a `+` operator
between Byte values, because integer literals make every constant
syntactically polymorphic.

**Under ζ (recommended)**: `byte + 1` does NOT compile. There is no `+`
on Byte or Byte.Protocol. The compiler error makes the boundary visible;
the author writes either:

```swift
byte.underlying + 1        // UInt8 arithmetic (wraps in &+, traps in +)
UInt32(byte) + 1           // widened arithmetic (BSLI bridge)
```

Both forms make the arithmetic-domain reading explicit at the call site.

**Under α / β / γ / δ**: `byte + 1` resolves to `Byte + Byte` via
integer-literal init on Byte (`Byte: ExpressibleByIntegerLiteral`
already; `1` infers as `Byte(0x01)`). The boundary disappears; the
author writes byte arithmetic without noticing the semantic shift. The
Cardinal precedent's analog problem (`cardinal + 1` resolving to
`Cardinal + Cardinal`) is benign for Cardinal because Cardinal IS a
quantity and addition IS a quantity operation; for Byte the same
resolution is semantically misleading because Byte is not a quantity.

The Ordinal precedent (`slot + .one` resolves via the `Count` associatedtype's
concrete type) does not transfer: Ordinal's `+` takes `Self.Count`, not
`Self`, so the integer literal must resolve to a Count, not a Self.
Byte has no analog Count type because Byte is not a position.

**Verdict**: ζ preserves the boundary-visibility property; α/β/γ/δ
collapse it. The visibility property is itself a load-bearing
architectural invariant per [IMPL-010] / [byte-primitive-extraction-and-domain-naming.md](./byte-primitive-extraction-and-domain-naming.md)
§"The Cost IS the Contract."

### Q3.3 — Protocol-vs-type placement (Byte vs Byte.Protocol)

The placement question is moot under ζ (no arithmetic anywhere). Under
α/β/γ/δ it has no correct answer:

| Placement | Effect | Verdict |
|-----------|--------|---------|
| On `Byte` directly (the concrete type) | Only Byte gets arithmetic; future `ASCII.Code` does not (unless it re-implements); `Tagged<Tag, Byte>` does not (unless a per-Tagged-conformance extension is added). | Splits the byte-domain surface inconsistently. |
| On `Byte.Protocol` (the capability marker) | Every conformer gets arithmetic — Byte, `Tagged<Tag, Byte>`, ASCII.Code consumer migration, UTF8.Code_Unit, RFC-byte types. ASCII.Code wants `digit:` accessors not arithmetic; UTF8.Code_Unit wants UTF-8 semantics not byte arithmetic. | Over-applies; pollutes the Byte.Protocol surface for all future conformers. |
| Both | Adds the worst-of-both surface: arithmetic on Byte AND on Byte.Protocol generic call sites, with the future-conformers over-apply problem. | Strictly worse. |

The placement question's no-correct-answer property is itself an
argument for ζ: if there is no right place to put arithmetic, the
arithmetic shouldn't exist.

### Q3.5 — BSLI partition

Of the inventory's `.underlying` sites, the partition under ζ:

| Partition | Sites in inventory | Resolution |
|-----------|---------------------|------------|
| **(a) Resolved by landed BSLI** ([`Integer+Byte.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives%20Standard%20Library%20Integration/Integer%2BByte.swift)) | [C1c] (73 sites) | `UInt16/32/64(byte)`, `Int8/16/32/64(byte)`, `Int*.init(bitPattern:byte)` — the institute's existing ergonomic answer to widening |
| **(b) Resolved by Byte.Protocol bitwise** ([`Byte.Protocol+Bitwise.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol%2BBitwise.swift)) | C4 bitwise half (6 LEB128 lines combined with [C1c] widening), C7 (0 sites) | `byte & mask`, `byte \| mask`, `byte ^ mask`, `~byte`, `byte << shift`, `byte >> shift` |
| **(c) Resolved by Byte's stdlib conformances** | C6 (1 site, migration debt) | `byte >= 0x30`, `byte == 0x7F` work directly via `Byte: Comparable + ExpressibleByIntegerLiteral`; `observed.underlying == byte` resolvable by typing the parameter as Byte |
| **(d) Migrate consumers to existing ASCII.Code (swift-ascii-primitives)** | C3 (2 sites), C5 (1 site), C9a (17 predicate-forwarding sites), C9f (1 bound-then-switch site) — **21 sites total** | `ASCII.Code` already exists in [`swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code.swift) with Byte.Protocol conformance ([`ASCII.Code+Byte.Protocol.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BByte.Protocol.swift)). Decode/classification accessors already live: `digitValue: UInt8?`, `hexValue: UInt8?` ([`ASCII.Code+Parsing.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BParsing.swift)); `isDigit`, `isHexDigit`, `isLetter`, `isAlphanumeric`, `isUppercase`, `isLowercase` ([`ASCII.Code+Classification.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BClassification.swift)). The arc is consumer-site migration, not type creation. |
| **(e) Future BSLI candidates** | C8 (0 sites currently) | bsli-gap-inventory.md "Future Candidates" section (`Sequence<UInt8>.asBytes`, single-element `UInt8(_:Byte)` if needed) |
| **(f) PERMANENT** | C9b (5 sites hex rendering), C9c (5 sites buffer extract / u8-reinterpret), C9d (4 accesses on 2 lines diagnostic), C9e (1 site cross-type init) — **13 PERMANENT sites + 1 designed boundary** | Excluded from Byte per parent doc; bridges via `byte.underlying` are intentional stdlib-interop or designed-boundary |

Partition coverage is **100%** — every `.underlying` arithmetic site
in the inventory is either resolved by existing infrastructure (73 + 6 + 1
= 80 sites), escalated to the ASCII.Code arc (21 sites), or permanent
stdlib-interop bridges (14 sites). **No category requires Byte arithmetic
to land**.

### Identity preservation (symmetric to Q1)

The parent doc's Q1 analysis articulated three bundle-conflict sites
that would arise from `UInt8: Byte.Protocol`. The symmetric analysis
for "Byte gains arithmetic":

| Bundle-conflict site | Q1 (UInt8 gains byte-domain) | Q3 (Byte gains arithmetic) | Symmetry verdict |
|----------------------|------------------------------|----------------------------|-------------------|
| **(1) Operator shadow** | Byte.Protocol's `==`/`<`/`hash` defaults shadow stdlib UInt8 ops. | Byte's `+`/`-` (under α/β/γ/δ) shadows NOTHING on UInt8 (different nominal type) — but `+` between Byte and integer literal shadows nothing in the source, but elides the byte-vs-arithmetic boundary at call sites. | **Asymmetric** (Q3 cost smaller on this axis; the cost is *boundary-visibility loss*, not literal operator shadowing). |
| **(2) API surface broadening** | Functions `<B: Byte.Protocol>(_ b: B)` would accept arbitrary UInt8. | Functions `<T: Numeric>(_ t: T)` would accept arbitrary Byte. | **Symmetric**. Both dissolve the byte-vs-arithmetic separation from one side each. |
| **(3) Carrier-protocol composition** | `Tagged<Tag, UInt8>` would conform to Byte.Protocol. | `Tagged<Tag, Byte>` would inherit Numeric (under α) or Cardinal-shape (under β) or Vector-shape (under γ). | **Symmetric**. Phantom-tagged domains shouldn't add (e.g., `tag1 + tag1` admits cross-domain operations that the phantom typing is designed to prevent). |

The asymmetry on axis (1) reduces Q3's bundle-conflict cost compared
to Q1 (no nominal operator shadow). But axes (2) and (3) are
symmetric and individually decisive. The parent doc's Q1 verdict
rested primarily on (2) and (3); the same axes are equally decisive
here. **The symmetric verdict on Q3 is the same: preserve the
byte-vs-arithmetic separation; no arithmetic on Byte.**

### A note on the asymmetric axis

The `operator shadow` axis is the asymmetry that makes Q3 *look*
softer than Q1 — "after all, Byte's `+` doesn't shadow anything." But
the axis under Q3 is **boundary-visibility loss**, not literal operator
shadow. Under any arithmetic option, `byte + 1` reads as byte
arithmetic at the call site. The author has no syntactic cue that the
operation is semantically suspect. The byte-vs-arithmetic separation
the parent doc protected is dissolved at every call site that admits
literal byte arithmetic. The axis is differently shaped from Q1's
operator shadow but functionally equivalent in cost.

## Recommendation

**RECOMMEND Option ζ. Byte does NOT gain arithmetic operators. The
ASCII-arithmetic friction documented in
[`swift-byte-primitives/Research/bsli-gap-inventory.md`](../../swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md)
"Open friction note: ASCII-arithmetic ergonomics" is resolved by
escalating to a future `ASCII.Code` arc in `swift-ascii-primitives` —
out of scope for this document and for swift-byte-primitives.**

Rationale anchored on the four criteria from the handoff brief:

1. **Inventory (Task 3) — sites eliminated vs sites unaffected**: ζ
   resolves 100% of the `.underlying` arithmetic friction by routing
   C1 → landed BSLI [C1c] (73 sites), C3/C5 → ASCII.Code migration arc
   (3 sites), C4/C7 → existing Byte.Protocol+Bitwise (6 LEB128 sites,
   0 standalone), C6 → Byte's stdlib conformances (1 site), C8 → future
   BSLI candidates (0 sites currently), C9a → ASCII.Code arc
   (17 predicate-forwarding sites), C9f → ASCII.Code arc
   (1 bound-then-switch site), and C9b/c/d/e → PERMANENT or
   designed-boundary (14 sites). **C2 has zero sites** — there is no
   actual demand for `Byte + Byte = Byte` in production code anywhere
   in the workspace. The categories that would benefit DIRECTLY from
   byte arithmetic (C2, C5-add) have either zero or one site, and the
   one-site C5 case is the same ASCII-digit-decode pattern as C3 —
   architecturally routed to ASCII.Code. **Every arithmetic option
   (α/β/γ/δ) introduces new infrastructure to address 3 production
   sites that belong in a different package's namespace.**

2. **Cardinal no-`-` precedent**: ζ HONORS the Cardinal precedent's
   underlying discipline: "add operators only when the operation is
   total AND the result type is structurally coherent." Cardinal's `+`
   passes both gates (adding cardinalities IS a cardinality);
   Cardinal's `-` fails the totality gate. Byte fails the
   *structural-coherence* gate from the start: two bytes added have
   no byte-domain result type. Honoring the precedent means recognizing
   that the structural-coherence gate disqualifies Byte from any
   arithmetic shape, including Cardinal's. The precedent is honored,
   not deviated from.

3. **Protocol-lift discipline (Q3.3)**: ζ places no arithmetic at
   either Byte or Byte.Protocol. Under α/β/γ/δ, the lift question has
   no correct answer — Byte-only is inconsistent; Protocol over-applies
   to future conformers (ASCII.Code, UTF8.Code_Unit) that want
   domain-specific accessors not byte arithmetic. ζ avoids the
   no-correct-answer entirely.

4. **BSLI partition (Q3.5)**: ζ produces a clean 100%-coverage partition.
   Every inventory site has a designated home: landed BSLI, existing
   bitwise lift, existing stdlib conformance, ASCII.Code migration arc,
   future BSLI candidate, or PERMANENT bridge. No arithmetic on Byte
   is needed for any partition.

### Supersession status

**This recommendation does NOT supersede `byte-protocol-capability-marker.md`
v1.1.0. It is a COMPANION document.**

The parent doc settled Q1 (UInt8 conformance — Option B = no) and Q2
(meta-pattern — manual recipe canonical). This doc settles Q3 (Byte
arithmetic — Option ζ = no). The two verdicts are structurally
symmetric: both preserve the byte-vs-arithmetic identity separation
from one side each (Q1 protects UInt8's arithmetic identity from
byte-domain bundle pollution; Q3 protects Byte's byte-domain identity
from arithmetic-algebras bundle pollution).

**Amendment to parent doc**: a one-line cross-reference will be added
to [`byte-protocol-capability-marker.md`](./byte-protocol-capability-marker.md)
§"What This Closes / What Remains Open" → "Open (Follow-on)" pointing
to this document as the resolution of the symmetric Q3 question. No
substantive section in the parent doc requires amendment; the parent's
verdict was framed on Q1 alone and Q3 is a separate (symmetric)
question with its own verdict. The cross-reference is a discoverability
addition, not a substantive amendment.

A supersession note is therefore appropriately framed as **complement**,
not **supersession**.

### Side-effect: closing the BSLI Open friction note

This recommendation closes the [`swift-byte-primitives/Research/bsli-gap-inventory.md`](../../swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md)
"Open friction note: ASCII-arithmetic ergonomics" with the verdict
**migrate consumer sites to the existing `ASCII.Code` API** in
swift-ascii-primitives. The inventory's "ASCII.Classification predicate
signatures" row (currently FOLLOW-UP) is bundled into the same migration
arc. **No new types or accessors are required** — `ASCII.Code`,
`ASCII.Code.digitValue`, `ASCII.Code.hexValue`, and the full
classification surface (`isDigit`, `isHexDigit`, `isLetter`,
`isAlphanumeric`, `isUppercase`, `isLowercase`, `lowercased()`,
`uppercased()`) all live in production today. The substantive work is
typing-decision migration at consumer sites.

## What This Closes / What Remains Open

### Closed

- **Q3.1 (intrinsic algebraic shape)**: closed. None of the ecosystem
  algebras (Cardinal, Ordinal, Vector, FixedWidthInteger) model Byte's
  intrinsic semantics; the structural-coherence test fails for each.
- **Q3.2 (inventory empirical support)**: closed. The inventory's
  category distribution does NOT support an arithmetic shape on Byte —
  C2/C5 have zero sites, C1/C4/C6/C7 are already covered, C3 routes
  to ASCII.Code, C8/C9 route to future / permanent.
- **Q3.3 (protocol-vs-type placement)**: closed. No arithmetic; no
  placement.
- **Q3.4 (integer-literal interaction)**: closed. ζ preserves
  boundary visibility; every other option collapses it.
- **Q3.5 (BSLI partition)**: closed. 100% partition coverage under ζ.
- **Q3.6 (supersession status)**: closed. Complements parent doc; no
  amendment beyond cross-reference.

### Open (downstream of this doc)

- **The ASCII.Code consumer-migration arc in `swift-ascii-primitives`**:
  `ASCII.Code` already exists, already conforms to `Byte.Protocol`
  ([`ASCII.Code+Byte.Protocol.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BByte.Protocol.swift)),
  and already exposes the relevant decode/classification accessors
  (`digitValue: UInt8?`, `hexValue: UInt8?` in [`ASCII.Code+Parsing.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BParsing.swift);
  `isDigit`, `isHexDigit`, `isLetter`, `isAlphanumeric`, `isUppercase`,
  `isLowercase`, `lowercased()`, `uppercased()` in
  [`ASCII.Code+Classification.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BClassification.swift)).
  The arc is **consumer-site migration, not type creation**. It will
  migrate **21 sites** in 4 files:
  - `Binary.ASCII.Parsing.Machine.Decimal.swift:58, :119` (2 × C3 bounded
    subtraction)
  - `ASCII.Decimal.Parser.swift:43` (1 × C5 wrapping subtraction)
  - `Lexer.Classify.swift` (4 × C9a `ASCII.Classification.isLetter`/`isAlphanumeric`/`isDigit`/`isHexDigit`)
  - `Version.*.Parser.swift` (13 × C9a — Version.Tools.Parser, Version.Calendar.Parser,
    Version.Semantic.Parser)
  - `ASCII.Hexadecimal.Parser.swift:59` (1 × C9f bound-then-switch)

  Out of scope for this Tier 3 doc; a separate handoff will dispatch the arc.
- **Future BSLI candidates** (per bsli-gap-inventory.md "Future
  Candidates"): `Sequence<UInt8>.asBytes` lazy bridge, `Byte.init(clamping:)`,
  `Byte.init(truncatingIfNeeded:)`, single-element `UInt8(_:Byte)` for
  the FixedWidthInteger-property bridge. These are not arithmetic on
  Byte; they are stdlib-bridge BSLI additions that the future-candidates
  process governs.
- **The downstream `.underlying`-audit arc** (queued post-this-research):
  with Q3 settled, the audit's Category 2 surface (the "bounded
  subtraction" sites) is empty in the byte-primitives consumer set; the
  audit primarily addresses the C9 PERMANENT category (intentional UInt8
  bridges) and confirms-clean for C1/C4/C6/C7.

### What This Does NOT Recommend

- **No arithmetic operators on `Byte` (any form)** — Options α, β, γ, δ
  are all REJECTED.
- **No domain-specific helpers on Byte that belong in ASCII namespace**
  — Option ε rejected as proposed for Byte; the variant that places
  helpers on `ASCII.Code` (in swift-ascii-primitives) is part of ζ's
  escalation.
- **No new `Byte.Offset` typed-offset type** — Byte is not a position;
  Byte.Offset would have no cross-domain consumer.
- **No re-litigation of byte-protocol-capability-marker.md Q1 or Q2** —
  the parent doc's verdicts are preserved.
- **No supersession of byte-protocol-capability-marker.md or any other
  prior research** — this is a companion document.

## References

### Internal — Authoritative

- [`swift-institute/Research/byte-protocol-capability-marker.md`](./byte-protocol-capability-marker.md)
  v1.1.0 (RECOMMENDATION, Tier 3, 2026-05-15) — parent doc; Q1 and Q2
  verdicts. **Companion to this document.**
- [`swift-institute/Research/byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md)
  v1.0.1 (DECISION, Tier 2, 2026-05-15) — byte extraction arc;
  Decision #1 LargerDomain.Subdomain governs the ASCII.Code escalation
  routing.
- [`swift-byte-primitives/Research/bsli-gap-inventory.md`](../../swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md)
  (LANDED 2026-05-19) — empirical inventory of `.underlying` sites and
  explicit rejection of Byte arithmetic. "Open friction note:
  ASCII-arithmetic ergonomics" is the question this doc resolves.
- [`swift-institute/Research/byte-cursor-primitive-unification.md`](./byte-cursor-primitive-unification.md)
  v1.3.0 → IN_PROGRESS (2026-05-17 downgrade) — cursor unification arc;
  confirms `Index<Byte>` (= `Tagged<Byte, Ordinal>`) is the byte-domain
  parallel of `Text.Position` (= `Tagged<Text, Ordinal>`). Confirms
  Byte is the substrate domain, not a position; positions are
  `Index<Byte>`.
- [`swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md`](./protocol-abstraction-for-phantom-typed-wrappers.md)
  v1.4.0 (DECISION/IMPLEMENTED, Tier 3, 2026-02-13) — per-type protocol
  pattern; rejected unified-protocol alternative.
- [`swift-institute/Research/cardinal-protocol-unification-memo.md`](./cardinal-protocol-unification-memo.md)
  (SUPERSEDED 2026-05-04) — Cardinal.Protocol live-fire precedent.

### Source files (verified inline documentation)

- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.swift):3–35 — Byte's intent ("not forwarded — `+`, `-`, `*`, `/` are absent by design").
- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol.swift):11–84 — sibling-to-Carrier protocol shape; UInt8 non-conformance rationale; future-conformers list.
- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol+Bitwise.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol+Bitwise.swift):6–12 — bitwise-lift rationale ("Arithmetic is NOT forwarded — bytes are not numbers").
- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives Standard Library Integration/Integer+Byte.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives%20Standard%20Library%20Integration/Integer+Byte.swift) — landed BSLI bridges (C1 resolution).
- [`swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.swift`](../../swift-primitives/swift-cardinal-primitives/Sources/Cardinal%20Primitives%20Core/Cardinal.swift):32–37, :91–95 — Cardinal `+` trapping addition, principled-NO on `-`.
- [`swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Subtract.swift`](../../swift-primitives/swift-cardinal-primitives/Sources/Cardinal%20Primitives%20Core/Cardinal.Subtract.swift):14, :16–55 — Property.View Subtract pattern; "There is no `-` operator because subtraction on cardinals is not total."
- [`swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift`](../../swift-primitives/swift-ordinal-primitives/Sources/Ordinal%20Primitives%20Core/Ordinal.Protocol.swift):71, :140–142 — Ordinal's associatedtype Count + `Self + Count = Self`.
- [`swift-primitives/swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Vector.swift`](../../swift-primitives/swift-affine-primitives/Sources/Affine%20Primitives%20Core/Affine.Discrete.Vector.swift):14–34 — Vector intent ("vectors form a group under addition … positions do not").
- [`swift-primitives/swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Ratio.swift`](../../swift-primitives/swift-affine-primitives/Sources/Affine%20Primitives%20Core/Affine.Discrete.Ratio.swift):14–44 — Ratio intent ("Ratios act on vectors (offsets/counts), not on points (indices)"); position-scaling-undefined exclusion.
- [`swift-primitives/swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift`](../../swift-primitives/swift-affine-primitives/Sources/Affine%20Primitives%20Core/Affine.Discrete+Arithmetic.swift):26–102 — Position±Vector, Position-Position=Vector.
- [`swift-primitives/swift-affine-primitives/Sources/Affine Primitives Core/Tagged+Affine.swift`](../../swift-primitives/swift-affine-primitives/Sources/Affine%20Primitives%20Core/Tagged+Affine.swift):57, :244–287 — Tagged<Tag, Vector> Offset typealias; Tagged Cardinal/Vector * Ratio scaling.
- [`swift-foundations/swift-ascii/Sources/ASCII/Binary.ASCII.Parsing.Machine.Decimal.swift`](../../swift-foundations/swift-ascii/Sources/ASCII/Binary.ASCII.Parsing.Machine.Decimal.swift):58, :119 — the canonical C3 friction sites (`return T(byte.underlying - 0x30)`).
- [`swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code.swift) — the live `ASCII.Code` value type wrapping `UInt8`.
- [`swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Byte.Protocol.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BByte.Protocol.swift) — ASCII.Code's Byte.Protocol conformance (already in production).
- [`swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Parsing.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BParsing.swift):14–35 — `digitValue: UInt8?` and `hexValue: UInt8?` accessors (already in production — the migration target for C3 / C5 sites).
- [`swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Classification.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Code%2BClassification.swift) — `isDigit`, `isHexDigit`, `isLetter`, `isAlphanumeric`, `isUppercase`, `isLowercase`, `lowercased()`, `uppercased()` (already in production — the migration target for C9a / C9f sites).

### External — Inherited (verified per `byte-protocol-capability-marker.md` v1.1.0 §"External — Verified Primary Sources")

- Rust Book ch10-02 + ch20-02 — orphan rule + newtype pattern.
- HaskellWiki/Newtype — newtype convention.
- swiftlang/swift Integers.swift — Numeric / BinaryInteger / FixedWidthInteger hierarchy.

The foundational SLR (`phantom-typed-value-wrappers-literature-study.md`
v1.0.0, 36 papers including Reynolds 1983, Wadler 1989, Hinze 2003,
Kennedy 1997) is inherited transitively per [RES-019] / [RES-026];
this document does not re-derive that material.

### Skill rules

- `[RES-001]` Investigation Triggers — research-process.
- `[RES-002]` Document Location Convention — research-process.
- `[RES-003]` Document Structure — research-process.
- `[RES-009]` Multi-Option Analysis — research-process.
- `[RES-018]` Premature Cross-Cutting Primitive Anti-Pattern — research-process.
- `[RES-019]` Step-0 Internal Research Grep — research-process.
- `[RES-020]` Research Tiers (Tier 3 classification) — research-process.
- `[RES-021]` Prior Art Survey + contextualization step — research-process.
- `[RES-022]` Recommendation-Section Framing Heuristic — research-process.
- `[RES-023]` Empirical-Claim Verification — research-process.
- `[RES-026]` Citations — research-process.
- `[RES-029]` Framing-Challenge for Binding/Membership/Placement Questions — research-process.
- `[API-NAME-001b]` LargerDomain.Subdomain — code-surface (governs ASCII.Code migration routing: ASCII is the larger domain).
- `[API-NAME-001c]` Per-Domain Capability-Marker Protocol — code-surface (the recipe Byte.Protocol instantiates; ASCII.Code consumer migration follows).
- `[IMPL-010]` Boundary-Conversion-at-Method discipline (preserves boundary visibility under ζ).
- `[HANDOFF-013]` Prior Research Check for Branching Investigations — handoff.

## Changelog

- **v1.0.0** (2026-05-19) — Initial recommendation. Settles Q3 (Byte
  arithmetic): Option ζ (status quo). Companions
  [byte-protocol-capability-marker.md](./byte-protocol-capability-marker.md)
  v1.1.0 — Q1 verdict (UInt8 non-conformance) and this doc's Q3 verdict
  (no Byte arithmetic) are structurally symmetric; both preserve the
  byte-vs-arithmetic identity separation. Closes the
  [`bsli-gap-inventory.md`](../../swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md)
  "Open friction note: ASCII-arithmetic ergonomics" by routing
  ASCII-domain digit/letter decode to the **already-existing**
  `ASCII.Code` API in swift-ascii-primitives — `ASCII.Code`,
  `ASCII.Code.digitValue: UInt8?`, `ASCII.Code.hexValue: UInt8?`,
  classification accessors, and `Byte.Protocol` conformance all live
  in production today; the downstream arc is consumer-site migration,
  not type creation.
