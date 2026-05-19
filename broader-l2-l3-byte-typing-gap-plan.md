# Broader L2/L3 Byte-Typing Gap — Plan + Per-Wave Outcomes

<!--
---
version: 1.0.0
last_updated: 2026-05-19
status: IN_PROGRESS
tier: 2
scope: ecosystem-wide
applies_to:
  - swift-byte-primitives
  - swift-binary-primitives
  - swift-ascii-primitives
  - swift-ascii-serializer-primitives
  - swift-iso-32000
  - swift-rfc-7519
  - swift-rfc-4648
  - swift-incits-4-1986
  - swift-foundations/swift-ascii
depends_on:
  - swift-institute/Research/byte-arithmetic-conformance.md
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
companion_to: byte-arithmetic-conformance.md
---
-->

## Context

The ASCII-domain retyping arc (2026-05-19, `HANDOFF-ascii-domain-retyping.md`)
migrated ~30 cohort packages to `Byte` / `ASCII.Code` substrate via BSLI-backed
typed bridges. Two execution sub-arcs landed: foundation work (BSLI lifts,
`Binary.ASCII.Serializable` child protocol retype) plus per-package cohort
retypes across ~110 files / ~31 commits.

**Phase 3 wrapper deletion attempted then reverted** [Verified: 2026-05-19]:
`b41d6f5` on swift-ascii-primitives + `531aa36` on swift-rfc-7519 attempted
deletion of `UInt8+ASCII.swift` plus mass `.underlying` patching at consumer
sites. Both were reverted after surfacing a class-(c) ecosystem reveal: the
correct migration shape is **type-up at CONTAINER + CONFORMING-PROTOCOL
level**, not mass `.underlying` patching at call sites.

This document is the investigation record and per-wave execution plan for
closing the gap.

## Question

How should the remaining ~6 UInt8-substrate consumer packages migrate to
`Byte` substrate without triggering the `.underlying`-mass-patching failure
mode that forced the Phase 3 revert?

**Sub-questions**:

- Q1: What protocol-level retype is required?
- Q2: What BSLI helpers must land first?
- Q3: How do the 6 cohort consumer packages decompose into independently-dispatchable migrations?
- Q4: What enforcement prevents regression after deletion?
- Q5: How do the ~38 audit-marked sites migrate now that byte-arithmetic-conformance has settled?

## Investigation

### Current state (verified 2026-05-19)

**Binary.Serializable parent protocol** [Verified: 2026-05-19]:
`swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift`
declares `Buffer.Element == UInt8` at lines 49, 73, 88, 113, 121, 135, 215,
229, 271, 291, 312, 333, 353. `Span<UInt8>` at lines 110, 119, 240, 252, 297,
320, 339. Extension blocks `extension Array where Element == UInt8`,
`extension ContiguousArray where Element == UInt8`,
`extension ArraySlice where Element == UInt8`,
`extension RangeReplaceableCollection<UInt8>`.

**Workspace-wide consumer cascade** [Verified: 2026-05-19]: `grep -rln
"Binary\.Serializable\b" {swift-primitives,swift-standards,swift-foundations,
swift-incits,swift-iso,swift-ietf}/` returns **89 files** across the workspace.

**BSLI current state** [Verified: 2026-05-19]:
- `Array+Byte.swift`: lifted to `Byte.Protocol` (foundation commits `3565c74`, `a532836`, `7e02854`)
- `Carrier+Byte.swift`, `Integer+Byte.swift`, `String+Byte.swift`: present
- **Missing helpers** (W1 scope): Set<Byte> trimming, firstIndex(of:) byte-subsequence lift, value→ASCII serialize without String intermediate

**Phase 3 wrappers** [Verified: 2026-05-19]:
- `UInt8+ASCII.swift`: present (revert successful) — slated for W4 deletion
- `Carrier.Protocol+ASCII.swift`: present — **KEEP** per principal direction
- `swift-ascii-serializer-primitives/.../Binary.ASCII.swift`: present, holds `let byte: UInt8` wrapper struct (separate from `UInt8+ASCII.swift`; in W3 cohort scope)

**Cohort packages — UInt8 substrate verified** [Verified: 2026-05-19]:

| Package | Substrate sites |
|---|---|
| swift-iso-32000 / 7.3 Objects.swift | `[UInt8: [UInt8]] escapeTable:55`, `[UInt8] escapeCharLookup:73`, `data: [UInt8]:689` |
| swift-rfc-7519 / RFC_7519.JWT.swift | 5× `[UInt8]` storage props (header/payload/signature + 2 Base64URL package-scoped) + init signatures |
| swift-rfc-4648 / RFC 4648/*.swift | Function signatures `Bytes.Element == UInt8`, `Buffer.Element == UInt8`, return `[UInt8]?` / `[UInt8]` |
| swift-incits-4-1986 / [UInt8]+INCITS_4_1986.ASCII.swift | Deliberate `extension [UInt8]` namespace (open question on retype shape) |
| swift-foundations/swift-ascii / UInt8+INCITS_4_1986.swift | Byte-level ops on Binary.ASCII namespace |
| swift-foundations/swift-ascii / Binary.ASCII.Base62.swift | Base62 alphabet decode |
| swift-ascii-serializer-primitives / Binary.ASCII.swift | Wrapper struct `let byte: UInt8` |

### Prior research consulted (per [HANDOFF-013])

| Doc | Status | Bearing on this plan |
|---|---|---|
| `byte-arithmetic-conformance.md` v1.0.0 | RECOMMENDATION ζ (2026-05-19) | Settles W6 — Byte does NOT gain arithmetic; audit-marked sites migrate to `ASCII.Code.digitValue` / `.hexValue` / classification predicates already in production |
| `byte-protocol-capability-marker.md` v1.1.0 | RECOMMENDATION (2026-05-15) | Settles `UInt8` non-conformance to `Byte.Protocol` — anchors the W4 deletion + W5 promote-rule |
| `byte-primitive-extraction-and-domain-naming.md` v1.0.1 | RECOMMENDATION | Byte type identity vs UInt8 — informs container retype shape |
| `byte-cursor-primitive-unification.md` | (varies) | Cursor<Byte> substrate alignment |
| `binary-primitives-package-decomposition.md` | (varies) | Binary.Serializable lineage |
| `bsli-gap-inventory.md` (swift-byte-primitives/Research/) | inventory | Open friction notes drive W1 helper scope |

No prior research document covers the *broader L2/L3 byte-typing gap*
specifically; this document is the first.

### Decision frame

The Phase 3 revert (2026-05-19) and prior cycle's mass-`.underlying`-patching
attempts demonstrate that **container typing AND parent protocol substrate**
are the load-bearing axes. The plan decomposes the gap into 6 independently-
dispatchable waves with strict ordering (W1 must land before W2; W2 before
W3; W3 before W4; W5 + W6 may proceed after W4 in either order).

| Wave | Topic | Token-budget | Gate |
|---|---|---|---|
| W1 | BSLI follow-ups (Set<Byte> trim, firstIndex byte-subseq, value→ASCII serialize) | ≤500 | none (first wave) |
| W2 | `Binary.Serializable` parent protocol retype `Buffer.Element == UInt8 → Byte` + extensions | ≤500 | W1 land |
| W3 | 6 cohort packages' UInt8 container retype to Byte | ≤500 | W2 land |
| W4 | Phase 3 wrapper deletion (`UInt8+ASCII.swift` only; keep `Carrier.Protocol+ASCII.swift`) | ≤300 | W3 land |
| W5 | `/promote-rule` `[PREFIX-NNN]` forbid `UInt8.ascii.X` regression | ≤300 | W4 land |
| W6 | ~38 audit-marked sites → `ASCII.Code.digitValue/hexValue` | ≤500 | W4 land |

W5 and W6 may execute in parallel post-W4.

### Open questions

| ID | Question | Disposition |
|---|---|---|
| OQ-1 | swift-incits-4-1986 `[UInt8]+INCITS_4_1986.ASCII.swift` — retype to what? | **RESOLVED 2026-05-19** (principal direction, revised). **RETYPE TO `ASCII.Code` substrate** — NOT `[Byte]`. INCITS 4-1986 IS the US-ASCII spec; canonical typed substrate is `ASCII.Code` (per byte-protocol-capability-marker + byte-arithmetic-conformance + ascii-code-structural-shape research). Parent-arc framing of "deliberate UInt8" was incorrect — the file uses the UInt8.ascii wrapper being deprecated in W4. Precedent: `swift-foundations/swift-ascii/Sources/ASCII/ASCII.Code+INCITS_4_1986.swift` already exists as canonical pattern. Migration: `[UInt8]+INCITS_4_1986.ASCII.swift` → `[ASCII.Code]+INCITS_4_1986.ASCII.swift` (extension target retyped); `UInt8.ascii.lf` consumer call sites → `ASCII.Code.lf` |
| OQ-2 | `swift-binary-primitives/Binary.Parseable.swift` symmetric UInt8 lock — W2 scope? | **PRINCIPAL-CONFIRMED 2026-05-19**. **INCLUDE in W2** (atomic cascade, NOT W2.5 split). Rationale: same-package symmetric protocol; atomic cascade preserves coherence. Splitting risks a temporary state where `Serializable` expects `Buffer.Element == Byte` and `Parseable` expects `Bytes.Element == UInt8`, which downstream conformers (RFC packages already migrated in the parent arc) would observe as an internal inconsistency |
| OQ-3 | `swift-foundations/swift-file-system/.../Binary.Serializable.swift` extension — in scope? | **PRINCIPAL-CONFIRMED 2026-05-19**. **INCLUDE in W2**. Rationale: it's a conformance authoring site — compile-forced by the protocol substrate change; MUST be in the build gate |
| OQ-2b | `swift-parser-primitives` Parser combinators — in scope? | **PRINCIPAL-CONFIRMED 2026-05-19**. **OUT of scope**. Different protocol family (`Parser_Primitives.Parser.\`Protocol\`` is `Input.Element`-typed, not `Binary.Serializable`). Previous cohort subagents already flagged this as a separate retyping arc; consistent disposition here |
| OQ-4 | W5 host skill — `byte-protocol-capability-marker` or sibling? | **RESOLVED 2026-05-19** (principal direction). **`code-surface` skill, new `[API-NAME-NNN]`** — rule constrains namespace shapes (forbids `extension UInt8` with `static var ascii`), squarely [API-NAME-*] domain. Cite byte-protocol-capability-marker research as provenance. Reserve dedicated byte-substrate skill if >2 rules accrue in this domain |
| OQ-5 | swift-rfc-7519 JWT public `[UInt8]` storage — retype (breaking) or bridge? | **RESOLVED 2026-05-19** (principal direction). **RETYPE to `[Byte]`** (breaking public API accepted). Pre-1.0 per `feedback_correctness_and_evergreen.md`; JWT bytes are byte-domain. Consumers constructing from `[UInt8]` use BSLI bridge `[Byte](source)` at FFI boundary |

### Cohort domain classification (revised 2026-05-19)

W3 retyping is NOT a blanket `UInt8 → Byte`. Each site classifies by domain:

| Site / Package | Domain | Substrate |
|---|---|---|
| swift-iso-32000 PDF `7.3 Objects.swift` | mixed (ASCII syntax + binary content) | `escapeTable: [ASCII.Code: [Byte]]`, `escapeCharLookup: [Byte]`, `data: [Byte]` |
| swift-rfc-7519 JWT | byte-domain (post-decode opaque) | `[Byte]` (5× public storage; breaking API change per Q3 disposition) |
| swift-rfc-4648 Base64/32 | bidirectional codec | encoded form `[ASCII.Code]`; decoded form `[Byte]` |
| swift-incits-4-1986 (US-ASCII spec) | ASCII-strict | **`ASCII.Code`** (per OQ-1 revised disposition) |
| swift-foundations/swift-ascii `UInt8+INCITS_4_1986.swift` | ASCII-strict | **`ASCII.Code`** |
| swift-foundations/swift-ascii `Binary.ASCII.Base62.swift` | ASCII alphabet + byte input | alphabet `[ASCII.Code]`; raw input `[Byte]` |
| swift-ascii-serializer-primitives `Binary.ASCII.swift` | ASCII wrapper struct | wrapper field `code: ASCII.Code` (was `byte: UInt8`) |

**Classification rule**: ASCII-strict spec / wrapper → `ASCII.Code`; byte-domain (opaque / UTF-8 / FFI) → `Byte`; codecs split per-direction.

## Outcome

**Status**: IN_PROGRESS (plan landed; per-wave execution pending dispatch)

**Plan**: 6-wave program decomposition with strict W1→W2→W3→W4 ordering;
W5 and W6 parallel post-W4. Per-wave handoffs at workspace root
([HANDOFF-007] program-shape exception):

- `HANDOFF-broader-l2-l3-byte-typing-gap-overview.md`
- `HANDOFF-broader-l2-l3-w1-bsli-followups.md`
- `HANDOFF-broader-l2-l3-w2-binary-serializable-retype.md`
- `HANDOFF-broader-l2-l3-w3-consumer-container-retype.md`
- `HANDOFF-broader-l2-l3-w4-phase-3-wrapper-deletion.md`
- `HANDOFF-broader-l2-l3-w5-promote-rule.md`
- `HANDOFF-broader-l2-l3-w6-audit-site-migration.md`

**Hard rules across all waves**:

- Type-up at CONTAINER + CONFORMING-PROTOCOL level, NOT call-sites. `.underlying` mass-patching is a stop-and-surface signal.
- `.underlying` carve-out only for genuine stdlib-interop boundaries (FFI, file I/O raw reads).
- [HANDOFF-035] cascade-termination: workspace-wide grep + ecosystem build gate (including Package.swift declarations) at end of each wave.
- No push without explicit principal authorization.

## Per-Wave Outcomes (stamped by executing subordinates)

### Wave 1 — Outcome (2026-05-19)

**Status**: COMPLETE (local-only; not yet pushed per program hard rule).

**Helpers landed** (3 — generic over `Byte.\`Protocol\``):

| Helper | File | Test outcome |
|---|---|---|
| `Collection.trimming(_ Set<Element>)` + `.trimming(where:)` | `Sources/Byte Primitives Standard Library Integration/Collection+Byte.swift` | 6 unit tests, 3 edge cases — all pass |
| `Collection.firstIndex<C>(of: C)` + `.contains<C>(_: C)` byte-subseq | same file | 4 unit tests, 3 edge cases — all pass |
| `RangeReplaceableCollection.append<I: BinaryInteger>(contentsOf: I)` | `Sources/Byte Primitives Standard Library Integration/Numeric+Byte.swift` | 7 unit tests, 2 edge cases (UInt64.max + Int64.min) — all pass |

**Build + test verification**:

- swift-byte-primitives: `swift build` clean; `swift test` — **88 tests in 27 suites pass** [Verified: 2026-05-19].
- swift-binary-primitives (downstream consumer): `swift build` clean; `swift test` — **337 tests in 111 suites pass** [Verified: 2026-05-19].

**Inventory update**: `swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md` gained sections 7 (Byte-domain Collection trimming + subsequence search) and 8 (BinaryInteger → ASCII decimal digits). "Open friction note: ASCII-arithmetic ergonomics" marked RESOLVED 2026-05-19 (settled by companion `byte-arithmetic-conformance.md` v1.0.0 RECOMMENDATION ζ; migration via W6).

**Design notes** (surfaced inline; nothing blocking):

- Trimming requires `Element: Byte.\`Protocol\` & Hashable` (Set membership); the `& Hashable` constraint is satisfied by all current conformers (Byte, ASCII.Code, Tagged<_, Byte>).
- firstIndex requires `Element: Byte.\`Protocol\` & Equatable` — same conformer set; the `needle: C` parameter constrains `C.Element == Element` (same-type byte subsequence).
- The `BinaryInteger → ASCII digits` overload is `@_disfavoredOverload` so existing byte-domain `append(contentsOf: Sequence)` overloads continue to win for sequence sources; the new overload fires when `value: some BinaryInteger`.
- Impl stays in a single `[UInt8]` buffer (sign + digits) and bridges to typed Element via existing BSLI `append(contentsOf:) where S.Element == UInt8` at one boundary call — no per-element Element ceremony, no `as` casts.

**BSLI structural refactor** (in-scope housekeeping, 2026-05-19):

- `Array+Byte.swift` BSLI inits #1, #2, #3 moved from `extension Array` to `extension RangeReplaceableCollection` per "least restrictive" guidance — now fires uniformly on `Array`, `ContiguousArray`, `Deque`, and any other `RangeReplaceableCollection` conformer.
- BSLI #3 (`init<S>(_:) where Element == UInt8, S.Element: Byte.Protocol`) gained `@_disfavoredOverload` to resolve Element-type inference ambiguity at unannotated `Array(byteSlice)` call sites. Stdlib same-type path wins for unannotated callers; explicit-type callers (`Array<UInt8>(bytes)`) continue to resolve via BSLI.
- Downstream consumers verified: `swift-foundations/swift-ascii`, `swift-ietf/swift-rfc-3986` (both use `Array<ASCII.Code>(bytes)` pattern) build clean post-refactor.

**Commit** (local, not pushed per program hard rule):

- swift-byte-primitives `b2d2668` — phase boundary checkpoint per [HANDOFF-019] commit-as-you-go; all 6 W1 files in a single commit (Array+Byte refactor + Collection+Byte + Numeric+Byte + 2 test files + bsli-gap-inventory.md update). Reviewed clean by principal 2026-05-19.

**Gates W2 dispatch**: W2 **AUTHORIZED 2026-05-19** by principal. Scope confirmed:
- `Binary.Serializable` parent retype (89 workspace consumers)
- `Binary.Parseable` symmetric retype (same package, atomic cascade per OQ-2)
- `swift-foundations/swift-file-system/.../Binary.Serializable.swift` extension (per OQ-3)
- swift-parser-primitives Parser combinators **EXCLUDED** (per OQ-2b — different protocol family)

**W2 termination criterion**: ecosystem-wide build gate covers Binary.Serializable consumers + Parseable consumers (same-package atomic) + file-system extension. Parser_Primitives consumers excluded.

### Wave 2 — Outcome (2026-05-19)

**Status**: PARTIAL — protocol retype landed; consumer cascade SURFACED + STOPPED for principal
adjudication. Ecosystem build INTENTIONALLY broken pending unified W2+W3 path decision.

**Landed (kept)**:

| Repo | Commit | What |
|---|---|---|
| `swift-binary-primitives` | `b121c0e` | Protocol retype: `Binary.Serializable.Buffer.Element` and `Binary.Parseable.Source.Element` from `UInt8 → Byte`. Tagged conformance, FixedWidthInteger-RawValue defaults, StringProtocol-RawValue defaults, byte-collection conformances ([Byte]/ContiguousArray<Byte>/ArraySlice<Byte>) retyped. Stdlib-interop forwarders preserved as `@_disfavoredOverload` (`serialize(into:) where Buffer.Element == UInt8`, `[UInt8].init<S: Binary.Serializable>(_:)`, etc.). In-package test fixtures retyped. Package.swift adds `Byte Primitives` + `Byte Primitives Standard Library Integration` to Serializable + Parseable targets; exports.swift re-exports both for transitive visibility. Build + test verified: **337/337 tests pass in 111 suites**. |
| `swift-ascii-serializer-primitives` | `06613af` | Sibling-family bridge simplification: `Binary.ASCII.Serializable → Binary.Serializable` direct delegation now that parent is Byte-typed too (was a `byteBuffer.underlying` workaround during the parent-arc partial state). |

**Reverted (out of W2 scope per principal direction 2026-05-19)**:

| Repo | Reverted commit | Reason |
|---|---|---|
| `swift-foundations/swift-paths` | `db3de1c` reverts `6e440f9` | Consumer witness retype on `Path` / `Path.Component` — stdlib-`.utf8` BSLI bridge OK in isolation, but consumer-witness cascade falls outside W2 scope per principal. |
| `swift-foundations/swift-file-system` | `040e97b` reverts `c790c1d` | Consumer witness retypes on 5 file-system types — `Byte(value.rawValue)` wraps on Kind enums hit mass-patching pattern. |

**Workspace cascade results**:

- Workspace-wide grep at W2 start: **89 files** with `Binary.Serializable` references; **95 files** with `Buffer.Element == UInt8`; **2 Package.swift** with `Binary Serializable Primitives` product references. [Verified: 2026-05-19]
- After protocol retype + reverts: **~50 consumer files** fail to compile against the new Byte-typed protocol — their witnesses retain `Buffer.Element == UInt8` signatures or their bodies append from `rawValue: UInt8` internal storage element-by-element.
- Sequence-level appends (`buffer.append(contentsOf: str.utf8)`, `buffer.append(contentsOf: rawValue.bytes())`) bridge cleanly via the BSLI cross-domain extension. Element-level appends (`buffer.append(value.rawValue)`) do NOT — fixing them requires either `Byte(...)` mass-patching (forbidden by hard rule) OR consumer container retype (W3's job).

**Structural issue surfaced**: the brief's three constraints are jointly inconsistent —
- W2 termination "ecosystem build clean" requires every consumer's witness to compile
- W2→W3 strict ordering requires W2 to land before W3 begins
- W3 cohort enumerates only 6 packages, not the ~50 actually affected by the protocol retype

**Report for supervisor review**: `swift-institute/Research/2026-05-19-w2-byte-cascade-structural-issue.md` — proposes discrimination criterion ("full UInt8 → Byte, only UInt8 where truly appropriate") with sites-that-MUST-stay-UInt8 vs sites-that-MUST-retype-to-Byte tables, and recommends unifying W2+W3 into a single coupled cascade per consumer package.

**Gates W3 dispatch**: BLOCKED pending principal adjudication on report's open questions (W2+W3 unification, scope expansion, `bytes(endianness:)` Byte-companion, ambiguous-case treatment).

### Wave 3 — Outcome

*To be stamped by W3 executor.*

### Wave 4 — Outcome

*To be stamped by W4 executor.*

### Wave 5 — Outcome

*To be stamped by W5 executor.*

### Wave 6 — Outcome

*To be stamped by W6 executor.*

## References

- Parent arc: `/Users/coen/Developer/HANDOFF-ascii-domain-retyping.md` (Phase-2 execution sections + principal direction 2026-05-19)
- Original program brief (superseded by overview + wave files): `/Users/coen/Developer/HANDOFF-broader-l2-l3-byte-typing-gap-program.md`
- `swift-institute/Research/byte-arithmetic-conformance.md` v1.0.0 RECOMMENDATION ζ
- `swift-institute/Research/byte-protocol-capability-marker.md` v1.1.0 RECOMMENDATION
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.0.1
- `swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md`

## Changelog

- **v1.0.0 (2026-05-19)** — Initial investigation outcome + plan. Pre-split into 7 per-wave handoff files at workspace root per [HANDOFF-007] program-shape exception. Per-wave outcome stamps pending execution.
