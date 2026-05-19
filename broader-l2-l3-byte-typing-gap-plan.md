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

### W2+W3 unification (principal direction 2026-05-19, post-execution-surfacing)

W2 execution surfaced a structural inconsistency (full report at `swift-institute/Research/2026-05-19-w2-byte-cascade-structural-issue.md`): W2 protocol retype breaks compile on ~50 consumers whose Pattern A/B witness bodies append element-by-element from `UInt8` storage. The original W3 cohort (6 named packages) covered only the container-retype subset, not the wider witness-signature cascade.

**Disposition**: W2 + W3 **BUNDLE** into a single unified cascade. Cohort: ~35–40 packages enumerated by the workspace-wide grep in the issue report § "Recommended scope expansion". Strict ordering W2-before-W3 dropped (the two are mechanically coupled). Subsequent waves W4 (Phase 3 deletion) / W5 (promote-rule) / W6 (audit-site migration) unaffected.

**Termination criterion** (revised): ecosystem-wide `swift build --build-tests` clean across all ~35–40 cascade packages, AND workspace-wide grep showing zero residual `Buffer.Element == UInt8` outside the discriminated "must stay UInt8" exceptions below.

**Discrimination criteria — MUST stay UInt8** (principal-signed-off 2026-05-19):

- Stdlib boundary types (`String.UTF8View.Element`, `Substring.utf8`, etc.)
- Stdlib protocol witnesses where stdlib defines the signature (`String(decoding: bytes, as: UTF8.self)`)
- FFI / C interop (`read(2)` / `write(2)` syscalls taking `UnsafeMutablePointer<UInt8>`)
- File I/O raw read buffers (POSIX boundary)
- Internal helper utilities for stdlib idioms (e.g., `swift-strings/Array.String.Char+PlatformNativeUTF8.appendUTF8(into:)`)

**Discrimination criteria — MUST retype to Byte** (principal-signed-off 2026-05-19):

- `Binary.Serializable` / `Binary.Parseable` witness signatures
- Domain-typed enum `rawValue: UInt8` (e.g., `File.Directory.Entry.Kind.rawValue`)
- Domain-typed struct field `xxx: UInt8` (e.g., `RFC_791.Flags.rawValue`)
- Octet tuples representing addresses (`RFC_791.IPv4.Address.octets`)
- Opaque byte payloads (`RFC_7519.JWT.payload`, etc.)
- `Buffer.Element == UInt8` in any institute extension
- Wrappers around byte values (e.g., `Binary.ASCII.Wrapper.bytes`)
- **Test bodies comparing serialized output** (use `[Byte]` literal inference per W1's test-syntax convention)
- **`BinaryInteger.bytes(endianness:)`** — primary returns `[Byte]`; `[UInt8]` form retained as `@_disfavoredOverload` (it's an institute extension, byte-domain output; eliminating the BSLI bridge at every integer-RawValue conformer is the structural win this cascade enables)

**Ambiguous-case dispositions** (principal-signed-off 2026-05-19):

| Site | Disposition |
|---|---|
| `BinaryInteger.bytes(endianness:)` | Primary `-> [Byte]`; `-> [UInt8]` forwarder as `@_disfavoredOverload`. Lands in `Standard_Library_Extensions` (or current home); add to W2 scope. |
| `withBytes(_:Span<Byte>)` on File.Name | Primary Span<Byte>; Span<UInt8> as `@_disfavoredOverload` for POSIX-FFI callers. |
| Test bodies | Convert to `[Byte]` literal comparisons. |
| `String(decoding:as:)` in conformer bodies | Stays UInt8 (stdlib idiom); source can stay `[Byte]` via existing `Sequence.underlying: [UInt8]` BSLI accessor at the boundary. |

**Forwarder scope on Binary.Serializable** (principal-signed-off 2026-05-19, all `@_disfavoredOverload`):

- `serialize(into:) where Buffer.Element == UInt8`
- `Array.init<S: Binary.Serializable>(_:) where Element == UInt8`
- `ContiguousArray.init<S: Binary.Serializable>(_:) where Element == UInt8`
- `RangeReplaceableCollection<UInt8>.append<S: Binary.Serializable>(_:)`
- `withSerializedBytes(_:(borrowing Span<UInt8>) throws -> R)` — primary becomes `Span<Byte>`; UInt8 form forwards
- `var bytes: [UInt8]` default convenience — primary `var bytes: [Byte]`; callers reach for `.bytes.underlying` via existing BSLI accessor to get `[UInt8]`

**State at direction time** (2026-05-19):

- swift-binary-primitives `b121c0e` — protocol retype landed; in-package tests pass (337/337). Keep.
- swift-ascii-serializer-primitives `06613af` — bridge simplified. Keep.
- swift-foundations/swift-paths `db3de1c` (reverts `6e440f9`) — REDO under expanded W2+W3 scope.
- swift-foundations/swift-file-system `040e97b` (reverts `c790c1d`) — REDO under expanded W2+W3 scope.

Ecosystem build currently red on ~50 consumer files; nothing pushed. Proceed with bundled cascade.

### Wave 2 — Outcome (2026-05-19, revised)

**Status**: PARTIAL — protocol retype + foundational cascade landed; per-package consumer
container retype SURFACED A SECOND STRUCTURAL BLOCKER (Byte not Codable). Ecosystem build
remains red on ~50 consumer files. Per-package execution dispatched as focused subordinate
work per the supervisor's W2+W3 unification direction; this Wave 2 outcome captures
foundational landing + the new structural blocker.

**Foundational cascade landed**:

| Repo | Commit | Notes |
|---|---|---|
| `swift-binary-primitives` | `b121c0e`, `31395d8`, `d12142e` | Protocol retype; `BinaryInteger.bytes(endianness:)` → `[Byte]` primary with `[UInt8]` `@_disfavoredOverload` forwarder; `Span<UInt8>` `withSerializedBytes` forwarder added; `RangeReplaceableCollection<UInt8>.append(utf8:)/append(_:)` utility retype to Byte primary + UInt8 forwarders. **337/337 tests pass.** |
| `swift-ascii-serializer-primitives` | `06613af` | Sibling-family `Binary.ASCII.Serializable → Binary.Serializable` bridge simplification (direct delegation now that parent is Byte). |
| `swift-foundations/swift-paths` | `3b3f5f4` | `Path` + `Path.Component` Binary.Serializable witness retype to `Buffer.Element == Byte`. Body uses BSLI cross-domain bridge (`string.utf8` → `Buffer<Byte>`). |
| `swift-foundations/swift-file-system` | `6f0ef45` | 5 conformer retypes: `File.Directory.Entry.Kind` and `File.System.Metadata.Kind` get container-retype `rawValue: UInt8 → Byte` (enums auto-synthesize Codable via raw value, and these are simple enums); `File.System.Metadata.Permissions` / `Ownership` / `File.Name` witness signatures retyped with body BSLI bridges (`.bytes()` and `appendUTF8` UInt8-tmp-buffer). |
| `swift-foundations/swift-ascii` | `5f426f8` | `String<T: Binary.ASCII.Serializable>(_:)` body routes through BSLI `.underlying` at the `String(decoding:as:)` boundary (stdlib idiom carve-out). |

**Second structural blocker — Byte does not conform to Codable**: per-file inspection of `swift-rfc-791` cascade revealed that retyping `rawValue: UInt8 → Byte` on structs that conform to `Codable` (e.g., `RFC_791.Precedence`, `RFC_791.TTL`, `RFC_791.Flags`) breaks Codable auto-synthesis because `Byte` itself is not `Codable`. `Byte` is its own `struct` (per `byte-primitive-extraction-and-domain-naming.md`), not a `Tagged` typealias — so the existing `Tagged: Codable where Underlying: Codable` conformance does not apply.

**Question for supervisor**: should `Byte` gain `Codable` conformance in `swift-byte-primitives`? It would route encode/decode through `UInt8.rawValue` (single-byte wire form). The capability-marker recipe doesn't currently mention Codable; it focuses on byte-domain identity vs arithmetic. Adding Codable to Byte unblocks the W2+W3 cascade for every consumer with `rawValue: Byte` + `Codable` conformance.

**Disposition (supervisor, 2026-05-19)**: option (a) — add `extension Byte: Codable` in swift-byte-primitives. **Landed at `swift-byte-primitives@ffc1510`**. Also bundled `extension Byte: CustomStringConvertible` (decimal description). 94/94 tests pass.

**Third structural blocker — Byte has no arithmetic** (anticipated, surfaced post-Codable): per-file inspection of `swift-rfc-791` cascade post-Codable revealed types like `RFC_791.TTL` whose `rawValue: UInt8` is **arithmetic-domain** (`rawValue - 1` for decrement). Per `byte-arithmetic-conformance.md` v1.0.0 RECOMMENDATION ζ, `Byte` does NOT gain arithmetic. So such consumers' `rawValue` MUST stay `UInt8` — falls under "MUST stay UInt8 (truly appropriate)" per the supervisor's discrimination amendment: **arithmetic-domain byte storage stays UInt8**.

**Discrimination refinement (added 2026-05-19, post-cascade-attempt)**:

| Pattern | Disposition |
|---|---|
| `rawValue: UInt8` participating in arithmetic (`-`, `+`, increment/decrement, modular roll-over) | **STAYS UInt8** — Byte has no arithmetic by design (byte-arithmetic-conformance.md). Adding `.underlying` bridges at arithmetic call sites IS the discipline. |
| `rawValue: UInt8` purely bit-field / kind-tag / opaque-byte (no arithmetic on it) | **RETYPE to Byte** |
| 16-bit field (`rawValue: UInt16`) | Stays UInt16; serialization uses the new Byte-primary `bytes(endianness:)`. |
| 32-bit field (`rawValue: UInt32`) | Same as 16-bit. |
| Tuple `(UInt8, UInt8, UInt8, UInt8)` (octets) | Per-case judgment — if octets are byte-domain identifiers (IP address) **retype to Byte**; if arithmetic carriers (digest byte counters) stay UInt8. |

Concrete RFC 791 type-by-type analysis:

| Type | rawValue | Arithmetic? | Disposition |
|---|---|---|---|
| Flags | UInt8 (bit field) | bitwise only | retype to Byte |
| HeaderChecksum | UInt16 | arithmetic (sum) | UInt16 stays; serialize via bytes(endianness:) |
| IHL | UInt8 (count) | `* 4` (header-length multiplier) | **STAYS UInt8** |
| IPv4.Address | UInt32 | bitwise | UInt32 stays |
| Identification | UInt16 | none (opaque ID) | UInt16 stays |
| FragmentOffset | UInt16 (13-bit) | shift / mask | UInt16 stays |
| Precedence | UInt8 (3-bit) | bitwise only | retype to Byte |
| Protocol | UInt8 (catalog) | none (lookup) | retype to Byte |
| TTL | UInt8 (count) | `- 1` (decrement) | **STAYS UInt8** |
| TotalLength | UInt16 | arithmetic (sum/check) | UInt16 stays |
| TypeOfService | UInt8 (bit field) | bitwise | retype to Byte |
| Version | UInt8 (literal) | none | retype to Byte |

Per-RFC, the analysis differs. Per-package cascade work is **not mechanical** — it requires per-type judgment.

**Cascade execution progress (2026-05-19)**:

Two representative patterns established at `swift-ietf/swift-rfc-791@cde98cb`:

- **Byte-domain (storage retype)**: `RFC_791.Flags` — storage retypes to Byte, error case associated value retypes, `[UInt8]` extension becomes `[Byte]` primary + `[UInt8]` `@_disfavoredOverload` forwarder. Pure bitwise → clean retype.
- **Arithmetic-domain (witness-only retype)**: `RFC_791.TTL` — storage stays `UInt8` (decremented per hop), witness signature retypes to `Buffer.Element == Byte`, body bridges via `firstByte.underlying` at the conformance boundary + `bytes(endianness: .big)` for serialization.

The two patterns cover the universe; remaining ~50 files each fit one or the other after per-type analysis. Per-file work is **NOT mechanical** — each requires inspecting the rawValue usage (arithmetic-domain? bit-field? opaque?) before applying the appropriate pattern.

**Remaining cascade scope** (~50 files):

| Package | Files | Predominant pattern |
|---|---|---|
| swift-ietf/swift-rfc-768 | 6 | UInt16 (Port/Length/Checksum) — witness retype + `bytes(endianness:)` |
| swift-ietf/swift-rfc-791 | 10 (Flags/TTL done) | Mixed — needs per-type judgment per table above |
| swift-ietf/swift-rfc-3596 | 1 | UInt32 (IPv6 AAAA — bitwise) |
| swift-ietf/swift-rfc-4291 | 1 | UInt32 (IPv6 — bitwise) |
| swift-ietf/swift-rfc-4648 | 11 | Base16/32/64 encoders — likely [Byte] payload retypes |
| swift-ietf/swift-rfc-5952 | 1 | IPv6 formatting — witness only |
| swift-ietf/swift-rfc-6068 / 6531 | 2 | Email/mailto — likely string-domain witnesses |
| swift-ietf/swift-rfc-6455 | 1 | WebSocket Frame — UInt16/UInt32 fields |
| swift-ietf/swift-rfc-6891 | 2 | DNS OPT — UInt16 fields |
| swift-ietf/swift-rfc-7301 | 2 | TLS ALPN — opaque bytes |
| swift-ietf/swift-rfc-7519 | 1 | JWT — opaque `[UInt8]` payloads → `[Byte]` |
| swift-ietf/swift-rfc-8200 | 2 | IPv6 ext header — UInt8/UInt16 fields |
| swift-ietf/swift-rfc-8446 | 4 | TLS — opaque + UInt16/UInt32 |
| swift-ietf/swift-rfc-9293 | 7 | TCP — UInt16/UInt32 fields + flags |
| swift-incits/swift-incits-4-1986 | 1 | INCITS_4_1986.ASCII surface |
| swift-iso/swift-iso-21320 | 1 | ISO 21320 CRC32 |
| swift-iso/swift-iso-32000 | 10 | PDF — mixed (some [UInt8] opaque payloads, some character processing) |
| swift-primitives/swift-ascii-primitives | 2 | ASCII.Classification + ASCII.Serialization — likely byte-domain |

Total: ~55 remaining files. Each gets ~10–30 minutes of per-type analysis + edit + build verification + commit. **Estimated total**: 12–25 hours of focused execution work.

**Per-package execution pattern** (established as the rubric for remaining work):

1. List Binary.Serializable conformers in the package.
2. For each, classify rawValue domain: arithmetic / bit-field / opaque / 16+-bit / tuple-of-octets / [UInt8]-payload.
3. Apply the appropriate pattern per the discrimination table above.
4. `swift build` in the package; fix any consumer-site bridges that surface.
5. Commit per package with the pattern citation.

### Wave 2 — PAUSED 2026-05-19 (principal direction)

**Meaningful W2 deliverables complete**:

- Protocol surface retype landed at `swift-binary-primitives@b121c0e` + downstream commits.
- `extension Byte: Codable` + `CustomStringConvertible` landed at `swift-byte-primitives@ffc1510` (unblocks consumer Codable auto-synthesis).
- Two cascade patterns proven: byte-domain (Flags) + arithmetic-domain (TTL) at `swift-rfc-791@cde98cb`.
- Discrimination rubric documented (per-type table for RFC 791 + per-package rubric for remaining 17 packages).

**Remaining cascade re-framed as post-swift-linter mechanical cleanup**: the ~50 file sweep across IETF / ISO / INCITS / ascii-primitives becomes a downstream arc once **swift-linter restoration + UInt8/Byte lint rules** land. The lint rules will encode the discrimination criteria (storage UInt8 stays / Buffer.Element == UInt8 retypes / arithmetic-domain rawValue stays / bit-field rawValue retypes) and surface every site mechanically. Each rule firing becomes a deterministic per-site retype, not a per-package judgment call.

**Sequencing post-pause**:

1. swift-linter restoration arc (separate program).
2. Author lint rules encoding the W2 discrimination criteria.
3. Mechanical sweep: rule fires per site → deterministic retype → commit.
4. End-of-sweep build gate + grep verification (the [HANDOFF-035] cascade-termination criterion W2 originally specified, but now reachable mechanically rather than judgmentally).

The W2+W3 unification (supervisor sign-off 2026-05-19) remains the structural framing; the lint-rule-driven sweep is the **execution mechanism** for the unified cascade.

| Disposition option | Implication |
|---|---|
| (a) Add `Codable` to Byte | Unblocks cascade. Byte gains stdlib-Codable conformance routing through UInt8 wire form. Single-commit change in swift-byte-primitives. |
| (b) Manual Codable per consumer | Each affected struct needs explicit `init(from:)` / `encode(to:)` that routes through `rawValue.underlying`. Mass per-consumer boilerplate. |
| (c) Drop Codable conformance | Consumers like `RFC_791.Precedence: Codable` lose the auto-synthesized conformance. Likely unacceptable for spec types. |

**RESOLVED 2026-05-19** (principal direction): **Option (a) — add `extension Byte: Codable`** in swift-byte-primitives, UInt8 wire form (encode as a JSON number identical to UInt8's encoding). Rationale:

- No identity-discipline violation. Codable is a serialization conformance, orthogonal to the byte-vs-arithmetic axis. Q1 (UInt8 ≢ Byte.Protocol) and Q3 (Byte has no arithmetic) both intact.
- Right level of conformance. Byte already has the foundational stdlib conformances (Equatable, Hashable, Comparable, ExpressibleByIntegerLiteral, Sendable, bitwise). Codable belongs in that same set — it's part of what makes a stdlib-respectable value type.
- Tagged<X, Byte> inherits via Tagged's existing `Codable where Underlying: Codable` conditional conformance once Byte gains it.
- Wire form: UInt8 number representation (`42`, not `{"underlying": 42}` or `"0x2A"`). Preserves wire compatibility with existing `[UInt8]` fields in spec-mirroring types — senders can migrate to `[Byte]` without breaking JSON consumers.

**Implementation sketch**:

```swift
// swift-byte-primitives/Sources/Byte Primitives/Byte+Codable.swift
extension Byte: Codable {
    @inlinable
    public init(from decoder: Decoder) throws {
        try self.init(UInt8(from: decoder))
    }

    @inlinable
    public func encode(to encoder: Encoder) throws {
        try underlying.encode(to: encoder)
    }
}
```

Plus a round-trip test (encode → decode → equality).

**Proactive audit while at it** — quick once-over of other likely-missing stdlib conformances on Byte before resuming the cascade. If the subordinate hits any of these as cascade blockers, bundle into the same commit as Codable (saves round-trips):

| Conformance | Should Byte have it? | Note |
|---|---|---|
| Codable | **YES** (this disposition) | UInt8 wire form |
| CustomStringConvertible | Verify — probably already has it | Decimal or hex representation? |
| CustomDebugStringConvertible | YES if missing | Usually hex-formatted for byte values |
| LosslessStringConvertible | Verify — if UInt8 has it, Byte should too (symmetric) | |
| Strideable | **NO** | Stride would imply arithmetic — Q3 territory; intentional absence |
| CaseIterable | **NO** | 256 cases is a misuse of the protocol |

**Adjacent (NOT in this commit's scope)**: per `feedback_json_serializable_canonical.md`, the institute prefers `swift-json`'s `JSON.Serializable` over `Swift.Codable` for institute consumer types. Adding JSON.Serializable to Byte is a separate, smaller addition. Subordinate may bundle it with Codable in the same commit (recommended; both are foundational) or land separately later. Default: bundle.

**Remaining cascade scope** (workspace-wide grep after foundational landing): **~50 files** across IETF (rfc-768, rfc-791, rfc-3596, rfc-4291, rfc-4648, rfc-5952, rfc-6068, rfc-6455, rfc-6531, rfc-6891, rfc-7301, rfc-7519, rfc-8200, rfc-8446, rfc-9293), ISO (iso-21320, iso-32000), INCITS (4-1986), and `swift-primitives/swift-ascii-primitives`. Each requires per-package container retype + body bridges; the Codable resolution above is the gating decision.

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

**Codable blocker — RESOLVED 2026-05-19** (principal direction): `extension Byte: Codable` AUTHORIZED with UInt8 wire form. See § Wave 2 — Outcome above for full disposition + implementation sketch + proactive audit guidance. Subordinate proceeds with: (1) land Byte+Codable in swift-byte-primitives; (2) bundle any other surfaced stdlib conformance gaps from the proactive audit table; (3) optionally bundle JSON.Serializable in the same commit; (4) resume per-package cascade across the ~50 remaining files.

### Wave 3 — Outcome

*To be stamped by W3 executor.*

## Post-W2 swift-linter byte-discipline arc (parallel arc A)

> Companion arc to the consumer cascade sweep (arc B). Authors six
> UInt8/Byte discipline lint rules that encode the W2 discrimination
> rubric mechanically, plus a new `byte-discipline` skill housing
> `[API-BYTE-001..006]`. Per `HANDOFF-swift-linter-byte-discipline.md`
> (2026-05-19). Arc A's output drives arc B's per-package prioritization;
> the two arcs are complementary.

### Phase 1 — swift-linter CLI restoration: DEFERRED structurally

Diagnosis (full trace in `HANDOFF-swift-linter-byte-discipline.md` §
Findings): swift-linter CLI build fails because its transitive
dependency graph reaches `swift-rfc-791/Sources/RFC 791/RFC_791.TypeOfService.swift`
(a W2 cascade-broken consumer file) via the chain
`swift-linter → swift-uri-standard → swift-rfc-3986 → swift-ipv4-standard → swift-rfc-791`.
Cascade-broken files are Do-Not-Touch; the structural fix is W2
completion (arc B's work). All three rule packages
(`swift-linter-rules`, `swift-institute-linter-rules`,
`swift-primitives-linter-rules`) build clean independently — Phase 2
deliverable path unaffected.

### Phase 2 — Six byte-discipline lint rules: COMPLETE

New pack `Institute Linter Rule Byte` at
`swift-foundations/swift-institute-linter-rules`. All six rules
registered in `Lint.Rule.Bundle.institute` per [PROMOTE-006] atomic
landing. **51 tests in 34 suites pass** via `swift test --filter Byte`
(0.055 s).

| ID | Rule | Encodes |
|---|---|---|
| [API-BYTE-001] | `uint8 conforms to byte protocol` | Q1 guard — byte-protocol-capability-marker v1.1.0 |
| [API-BYTE-002] | `byte conforms to arithmetic protocol` | Q3 guard — byte-arithmetic-conformance v1.0.0 RECOMMENDATION ζ |
| [API-BYTE-003] | `binary serializable uint8 witness` | W2 protocol-retype cascade guard |
| [API-BYTE-004] | `binary serializable rawvalue uint8` | W2 discrimination-rubric per-site review-prompt |
| [API-BYTE-005] | `uint8 ascii extension` | W5 wrapper-regression guard |
| [API-BYTE-006] | `uint8 forwarder missing disfavored` | Stdlib-interop forwarder attribute discipline |

Per-rule outcome records:
`swift-institute/Audits/PROMOTE-API-BYTE-{001..006}-2026-05-19.md`.
Validation receipts:
`swift-foundations/swift-linter/Research/promote-API-BYTE-{001..006}-validation-2026-05-19.md`.

### Ground-truth probe table (PRE-arc-B-checkpoint-1 snapshot)

Snapshot timestamp: **2026-05-19, early in the day, before arc B's
Checkpoint 1 landings** (`b6b95f8` / `74da3d5` / `21892e2` / `ba16b6d` /
`b5a3bf6` per arc B § Checkpoint 1). Regex pre-scan upper bound (AST
fire counts after `@_disfavoredOverload` exemption will be lower). Read-
only `grep` against `Sources/` — no source modifications by arc A.

| Package | R1 (UInt8:Byte.Protocol) | R2 (Byte:arithmetic) | R3 (Element==UInt8) | R4 (rawValue:UInt8) | R5 (UInt8.ASCII) | R6 (Byte-domain ext) |
|---------|---:|---:|---:|---:|---:|---:|
| swift-rfc-791 | 0 | 0 | 0 | **7** | 0 | 0 |
| swift-rfc-768 | 0 | 0 | 0 | 0 | 0 | 0 |
| swift-rfc-9293 | 0 | 0 | **13** | **6** | 0 | 0 |
| swift-rfc-7519 | 0 | 0 | **1** | 0 | 0 | 0 |
| swift-rfc-4648 | 0 | 0 | **52** | 0 | 0 | 0 |
| swift-iso-32000 | 0 | 0 | **73** | 0 | 0 | 0 |
| swift-incits-4-1986 | 0 | 0 | **6** | 0 | 0 | 0 |
| swift-ascii-primitives | 0 | 0 | **15** | 0 | 0 | 0 |
| swift-binary-primitives | 0 | 0 | 3 | 0 | 0 | 8 |
| swift-foundations/swift-ascii | 0 | 0 | **1** | 0 | 0 | 0 |

**Arc-B coordination note**: Arc B's Checkpoint 1 (after this snapshot)
landed `swift-rfc-791` (10 remaining types per arc B's Checkpoint 1
table), `swift-rfc-768`, `swift-rfc-4291`, `swift-rfc-8200`, and
`swift-ascii-primitives`. Arc B's End-of-tier-0 workspace grep shows
rfc-791 / rfc-768 / rfc-4291 / rfc-8200 / ascii-primitives at 0 post-
Checkpoint-1. The arc A probe table above represents pre-sweep state
and is preserved verbatim as the leverage-point baseline for the rules'
calibration. Future arc B checkpoints can compare against the same
baseline.

R1/R2/R5 = 0 ecosystem-wide both pre- and post-Checkpoint-1 (no
existing UInt8→Byte.Protocol or Byte→arithmetic violations; W5 wrapper
not re-introduced post-W4-deletion).

### Skill landing

New skill `byte-discipline` at
`swift-institute/Skills/byte-discipline/SKILL.md` houses
`[API-BYTE-001]` through `[API-BYTE-006]`. The `[API-BYTE-004]` body
carries the W2 discrimination rubric (byte-vs-arithmetic-domain axis)
as the load-bearing principle the six rules collectively encode.
`swift-institute/CLAUDE.md` Skill Routing table updated to route
"byte-domain API surface decisions" → `byte-discipline`, IDs
`[API-BYTE-*]`.

Skill citation chain:
- `byte-protocol-capability-marker.md` v1.1.0 (Q1) → [API-BYTE-001] + [API-BYTE-005]
- `byte-arithmetic-conformance.md` v1.0.0 (Q3) → [API-BYTE-002] + [API-BYTE-004] arithmetic-domain disposition
- W2 protocol-retype cascade (`swift-binary-primitives@b121c0e`) → [API-BYTE-003] + [API-BYTE-004] byte-domain disposition
- W1 BSLI forwarder pattern → [API-BYTE-006]

### Arc-A / Arc-B coordination

Arc A produces rules; arc B consumes them as work prioritization. The
ground-truth probe table above is arc B's calibration baseline.
Specifically:

| Rule | Arc-B usage |
|---|---|
| [API-BYTE-001] | Future-prevention; arc B does not encounter active firings |
| [API-BYTE-002] | Future-prevention; arc B does not encounter active firings |
| [API-BYTE-003] | **Primary surfacing mechanism** — fires at every Wave 2 witness signature still on UInt8 substrate; per-package fire-count is the work-queue prioritization input |
| [API-BYTE-004] | **Per-site disposition surfacing** — fires at every conformer whose `rawValue: UInt8` needs domain classification under the W2 rubric (arithmetic-domain stays UInt8; byte-domain retypes to Byte) |
| [API-BYTE-005] | Future-prevention; arc B does not re-introduce the wrapper |
| [API-BYTE-006] | Future-prevention with low-batch-fix risk; arc B should preserve the `@_disfavoredOverload` discipline when adding new byte-domain extensions |

The downstream sweep arc (arc B) requires linter-CLI availability OR
test-target validation harness per `lint-rule-promotion` Phase 6
Detection method. swift-linter CLI restoration depends on (a)
completing the sweep (chicken-and-egg) OR (b) one-off harness execution
per sweep target. Arc B chose path (b) — manual per-package execution
under the rubric without depending on CLI. The arc-A rules remain as
mechanical regression guards for any future drift.

## Post-W2 consumer cascade sweep (parallel arc B)

> Parallel arc to the swift-linter byte-discipline arc (A) per
> `HANDOFF-uint8-byte-consumer-cascade.md`. Mechanical ~50-file sweep
> applying the W2 discrimination rubric (pinned commit `0fbc860`) to ~17
> consumer packages across IETF/ISO/foundations. Reference patterns:
> `swift-rfc-791@cde98cb` (Flags + TTL). Per-package commit + checkpoint
> every 5 packages per [HANDOFF-019] + [HANDOFF-035].

### Checkpoint 1 (after 5 packages, 2026-05-19)

**Landed** (per-package SHAs + discrimination axis):

| Package | SHA | Files | Discrimination |
|---|---|---|---|
| `swift-rfc-4291` | `b6b95f8` | 1 src + 1 test | Pattern B (UInt16 segments stay, witness retype, `bytes(endianness: .big)` body) |
| `swift-primitives/swift-ascii-primitives` | `74da3d5` | 2 src | Sequence-predicate `Bytes.Element` retype to Byte; `.underlying` bridge to single-byte `isXxx(UInt8)` impls; `serializeDecimal` `Buffer.Element` retype with internal UInt8 digit-calc storage + `Byte()` bridge at append boundary; 13 `@_disfavoredOverload` UInt8 forwarders |
| `swift-rfc-791` (10 remaining types) | `21892e2` | 10 src + 11 test + 2 Error | Pattern A: Precedence/TypeOfService/Version/Protocol (3–8-bit bitwise, no arithmetic) — storage retype to Byte. Pattern B: Identification/HeaderChecksum/TotalLength/FragmentOffset (UInt16) + IPv4.Address (UInt32 + octet tuple retype to Byte + `init(_ octet: Byte, ...)` primary + UInt8 forwarder) + IHL (UInt8 arithmetic, × 4 multiplier — STAYS UInt8) |
| `swift-rfc-768` (UDP) | `ba16b6d` | 6 src + 1 test | Pattern B for Port/Length/Checksum (UInt16); `compute/verify/sumWords` static helpers retype `Bytes.Element` to Byte; Header aggregate parse+serialize; Datagram opaque payload `data: [Byte]` (primary) + `[UInt8]` forwarder; PseudoHeader bridges `RFC_768.protocolNumber` (UInt8 stays in Constants) via `Byte()` |
| `swift-rfc-8200` (IPv6 ext header) | `b5a3bf6` | 2 src + 1 test | Header witness retype; internal arithmetic-domain UInt8/UInt32 bitwise calc with `Byte()` bridge at `buffer.append` boundary; `payloadLength` via `bytes(endianness:)`. Fragment witness retype; UInt16/UInt32 fields via `bytes(endianness:)` |

**Tests**: 36 (rfc-4291) + 0 (ascii-primitives, no tests) + 225 (rfc-791) + 19 (rfc-768) + 20 (rfc-8200) = **300/300 pass**.

**End-of-tier-0 workspace grep** (`Buffer.Element == UInt8` in scope packages):

```
rfc-768:                0  (✓ done)
rfc-791:                0  (✓ done)
rfc-3596:               1  (BLOCKED on rfc-1035 baseline)
rfc-4291:               0  (✓ done)
rfc-4648:               6  (tier 3, untouched — gates rfc-5952, rfc-7519)
rfc-5952:               1  (BLOCKED on rfc-4648)
rfc-6068:               0  (different pattern; deps on rfc-3986/5322 out of scope)
rfc-6455:               1  (untouched)
rfc-6531:               0  (different pattern; multiple out-of-scope deps)
rfc-6891:               2  (BLOCKED on rfc-1035 baseline)
rfc-7301:               2  (BLOCKED on rfc-8446 tier 3)
rfc-7519:               1  (BLOCKED on rfc-4648)
rfc-8200:               0  (✓ done)
rfc-8446:               4  (tier 3, untouched — gates rfc-7301)
rfc-9293:               7  (tier 3, untouched)
iso-21320:              0  (deps on rfc-1951; needs verify)
iso-32000:              6  (tier 4, untouched)
incits-4-1986:          0  (OQ-1 ascii surface pattern, separate)
ascii-primitives:       1  (forwarder; effectively done)
```

**Blockers surfaced** (class-c surface, not auto-fixed per
`feedback_orchestrator_match_subordinate_stop.md`):

| Blocker | Affected | Disposition |
|---|---|---|
| `swift-rfc-1035` baseline broken at `f4925e9 refactor: retype ASCII Buffer.Element to Byte` — 4 errors `Byte == ASCII.Code` in `RFC_1035.Domain.Label.swift` lines 142/161/177 + `RFC_1035.Domain.swift:145`. rfc-1035 is OUT of arc cohort per pinned plan. | rfc-3596, rfc-6891 (transitive deps via Package.swift) | DEFERRED — surface to principal; not auto-fixed (parallel-session WIP, sibling arc) |
| Tier-3 packages gate tier-0/1/2 leaves | rfc-5952 (waits rfc-4648), rfc-7301 (waits rfc-8446), rfc-7519 (waits rfc-4648) | EASY-TIER-FIRST violated by dep order; proceeding with rfc-4648 + rfc-8446 next to unblock leaves |

**Remaining file count** (post-checkpoint-1): ~30 in-scope files across 9
packages.

**Continuing**: tier 3 (rfc-4648, rfc-8446, rfc-9293) to unblock leaves +
tier 4 (iso-32000, incits-4-1986, iso-21320). rfc-3596/rfc-6891 remain
DEFERRED pending principal direction on rfc-1035 baseline.

### Checkpoint 2 / Final (2026-05-19)

**Total landed: 10 packages**, ~38 source files retyped, ~10+ test files updated.

| Package | SHA | Files | Discrimination |
|---|---|---|---|
| `swift-rfc-4291` | `b6b95f8` | 1 src + 1 test | UInt16 segments stay, witness retype, `bytes(endianness: .big)` body |
| `swift-ascii-primitives` | `74da3d5` | 2 src | Sequence predicates `Bytes.Element` retype + `.underlying` bridge; `serializeDecimal` retype + Byte() append-boundary bridge; 13 `@_disfavoredOverload` UInt8 forwarders |
| `swift-rfc-791` (10 types) | `21892e2` | 10 src + 11 test + 2 Error | Pattern A bitwise: Precedence/TypeOfService/Version/Protocol (storage retype). Pattern B arithmetic: Identification/HeaderChecksum/TotalLength/FragmentOffset (UInt16) + IPv4.Address (UInt32 + octet tuple + UInt8 forwarder) + IHL (UInt8 arithmetic STAYS) |
| `swift-rfc-768` | `ba16b6d` | 6 src + 1 test | UInt16 fields (Port/Length/Checksum) witness retype; compute/verify static helpers retype Bytes.Element; Datagram `data: [Byte]` + [UInt8] forwarder; PseudoHeader bridges protocolNumber via Byte() |
| `swift-rfc-8200` | `b5a3bf6` | 2 src + 1 test | Header witness retype; internal arithmetic-domain UInt8/UInt32 bitwise calc with Byte() bridge at append boundary; payloadLength via bytes(endianness:). Fragment witness retype |
| `swift-rfc-9293` | `7538429` | 7 src + 1 test | TCP: Port/SequenceNumber (UInt16/UInt32 stay); Flags STAYS UInt8 (OptionSet RawValue: FixedWidthInteger); DataOffset STAYS UInt8 arithmetic; Header aggregate parse+serialize with options: [Byte]; Option enum unknown(kind: UInt8, data: [Byte]); Segment data: [Byte] + [UInt8] forwarder |
| `swift-rfc-8446` | `16e5677` | 4 src + 1 test | TLS: Alert witness retype with Byte() level/description; Extension.Data opaque `data: [Byte]` + [UInt8] forwarder, UInt16 wire forms via bytes(endianness:); Handshake.Message opaque body, manual uint24 split; Record opaque fragment + [UInt8] forwarder + init(binary:) internal next() bridge |
| `swift-rfc-7301` | `3736b6c` | 4 src + 1 test | ALPN: ProtocolIdentifier opaque `rawValue: [Byte]` + [UInt8] forwarder; description bridges via .underlying for stdlib UTF-8; WellKnown 17 constants use Array<Byte>; Extension serialize with UInt16 wire forms |
| `swift-rfc-6455` | `f4a09ce` | 1 src + 1 test | WebSocket Frame opaque `payload: [Byte]` + [UInt8] forwarder; serialize byte0/byte1 bitwise UInt8 internal with Byte() bridges; 16/64-bit length via bytes(endianness:); mask.applying bridge via .underlying; convenience constructors retyped |
| `swift-iso-21320` | `d6e15ec` | 1 src + Package.swift | CRC32 checksum<Bytes> generic helper Bytes.Element retype; UInt32 accumulator with .underlying bridge; [UInt8] @_disfavoredOverload forwarder. Package.swift gained `swift-byte-primitives` dep (Standard_Library_Extensions does NOT re-export Byte; transitively absent in this package's dep graph) |

**Tests**: 36 + 0 + 225 + 19 + 20 + ~25 (rfc-9293) + 23 + 15 + 22 + 5 = **~390/390 pass** across 10 packages.

**End-of-arc workspace grep** (`Buffer.Element == UInt8` in scope packages):

```
rfc-768:                0  (✓ done)
rfc-791:                0  (✓ done)
rfc-3596:               1  (DEFERRED: blocked on rfc-1035 baseline)
rfc-4291:               0  (✓ done)
rfc-4648:               6  (DEFERRED: codec split design — encoded ASCII.Code vs decoded Byte)
rfc-5952:               1  (DEFERRED: gated on rfc-4648 Base16.encode)
rfc-6068:               0  (no Buffer.Element pattern in source; out of scope or already-typed)
rfc-6455:               0  (✓ done)
rfc-6531:               0  (no Buffer.Element pattern in source)
rfc-6891:               2  (DEFERRED: blocked on rfc-1035 baseline)
rfc-7301:               0  (✓ done)
rfc-7519:               1  (DEFERRED: gated on rfc-4648 Base64URL.encode)
rfc-8200:               0  (✓ done)
rfc-8446:               0  (✓ done)
rfc-9293:               0  (✓ done)
iso-21320:              0  (✓ done — Package.swift dep added)
iso-32000:              6  (DEFERRED: 9 files including ContentStream/Writer; substantive per-file design — out of mechanical scope)
incits-4-1986:          0  (different pattern; OQ-1 deferred — needs coordinated file rename [UInt8]+ → [ASCII.Code]+ + workspace-wide consumer migration)
ascii-primitives:       1  (forwarder; effectively done)
```

**Total reduced**: 51 → 18 (`Buffer.Element == UInt8` files), 33 files retyped across 10 packages.

**Deferred items** (require separate focused arcs):

| Package | Reason | Estimated work |
|---|---|---|
| `swift-rfc-1035` baseline broken at `f4925e9` | Outside arc cohort per pinned plan; parallel-session WIP | 4 `Byte == ASCII.Code` sites in Domain*.swift; needs accessor-style fix |
| `swift-rfc-3596`, `swift-rfc-6891` | Transitive dep on rfc-1035 | Unblocks once rfc-1035 fixed; each is mechanical retype (1 + 2 files) |
| `swift-rfc-4648` | Codec split design (encoded ASCII.Code vs decoded Byte per file/method) | 6 source files; per-direction discrimination is meaningful design work, not mechanical |
| `swift-rfc-5952`, `swift-rfc-7519` | Gated on rfc-4648 (`Base16.encode`/`Base64URL.encode` calls) | 1 file each; mechanical after rfc-4648 lands |
| `swift-iso-32000` | 9 files (more than plan's 6); 1000+ line ContentStream/Writer with intricate PDF serialize bodies | Substantive per-file design work; needs focused arc |
| `swift-incits-4-1986` (OQ-1) | File rename + workspace-wide consumer migration coordinated with W4 wrapper deletion | Best done as part of W4 arc rather than W3 |
| `swift-rfc-6068`, `swift-rfc-6531` | Different pattern (no `Buffer.Element == UInt8` per source grep); deps on out-of-arc rfc-3986/5322/1123/5321 | Need pattern-by-pattern audit; out of obvious mechanical scope |

**Class-c surface for principal**: rfc-1035 baseline (parallel-session WIP at `f4925e9 refactor: retype ASCII Buffer.Element to Byte` left 4 errors `Byte == ASCII.Code` in `RFC_1035.Domain.Label.swift:142/161/177` + `RFC_1035.Domain.swift:145`). Blocks rfc-3596, rfc-6891. Per `feedback_orchestrator_match_subordinate_stop.md`, not auto-fixed.

**Discrimination patterns established / refined**:

- UInt16/UInt32 arithmetic-domain stays; witness `Buffer.Element` retypes; bodies bridge via `.underlying` for stdlib integer reconstruction; `BinaryInteger.bytes(endianness: .big)` for Byte-primary serialize emission.
- UInt8 arithmetic-domain (TTL decrement, IHL × 4 multiplier, HopLimit, DataOffset) STAYS UInt8 + witness-only retype.
- OptionSet rawValue STAYS UInt8 (RawValue: FixedWidthInteger; Byte ≢ FixedWidthInteger per Q3).
- Enum raw-value catalogs (Kind, ContentType, MessageType, ExtensionType) STAY UInt8/UInt16 in separate files; bridge via `Byte()` at witness boundary.
- Opaque byte-domain payloads (TCP Options data, TLS Extension/Handshake/Record fragment, ALPN ProtocolIdentifier rawValue, WebSocket payload) → `[Byte]` storage primary + `[UInt8]` @_disfavoredOverload forwarder init.
- Test sweep: `[UInt8]` → `[Byte]` for serialize-buffer comparisons; `Byte(value)` bridge in UInt8-iteration test loops (Byte not Strideable per Q3).
- Stdlib idioms (`String(ascii:)`, `String(decoding:as:UTF8.self)`, MaskingKey.apply that takes UInt8) bridged via `.underlying` at consumer call site rather than retyping the stdlib-shaped API.
- Package.swift dep gap surfaced for iso-21320: `Standard_Library_Extensions` does NOT re-export `Byte`; packages without transitive byte-primitives must add it as direct dep.

## Post-W2 L1 byte-domain cleanup (parallel arc C)

> Companion arc to swift-linter byte-discipline (A) and consumer cascade (B).
> Disjoint territory: L1 only (`swift-primitives/*`). Targets the
> parameter / storage / return surface that survived W2's witness-signature
> retype. Per `HANDOFF-l1-byte-domain-cleanup.md` (2026-05-19).
>
> **Migration principle** — INPUT-side wins on generic relaxation:
> 1. `some Sequence<some Byte.\`Protocol\`>` (most permissive)
> 2. `some Collection<some Byte.\`Protocol\`>`
> 3. `some Sequence<Byte>` / `some Collection<Byte>`
> 4. `[Byte]` (concrete; fallback when caller necessarily passes Array)
>
> Storage + returns: concrete (`[Byte]` / `ContiguousArray<Byte>`).
> ~Copyable element support: institute `Sequence.\`Protocol\`` /
> `Collection.\`Protocol\`` (NOT Swift.Sequence/Collection).
> No push (program rule).

### Checkpoint — Final (2026-05-19)

**12 commits across 11 packages** — all on `main`, no push.

| # | Package | Commit | Tier | Files |
|---|---|---|---|---|
| 1 | swift-byte-parser-primitives | `1438f1b` | B | Byte.Input.View.swift (`starts(with:)` INPUT relaxation, `copyToOwned` storage retype) + Parser.Builder+Literal.swift (`Input == ArraySlice<Byte>`) |
| 2 | swift-byte-serializer-primitives | `860ca99` | B + folded | Byte.Literal.Serializer + Byte.Serializer (sibling) + Serializer.Builder + 2 test files |
| 3 | swift-input-primitives | `0636fa5` | B (doc) | Input.Slice.swift — generic Collection, only doc-example UInt8→Byte |
| 4 | swift-binary-parser-primitives | `379d148d` | B + D | Parser.Parser+parse.swift (doc) + Byte.Input.View Tests.swift (`as [Byte]` disambig) |
| 5 | swift-byte-parser-primitives | `a22a871` | B (Wave 3 pattern) | Parser.Builder+Literal.swift — relocated Parser.Take.Builder byte-array overload (`Input == ArraySlice<Byte>`) |
| 6 | swift-parser-primitives | `5aba2a8` | B | Parser.Take.Builder.swift — byte-array literal overload moved out (no byte-domain dep) |
| 7 | swift-serializer-primitives | `e7a22c7` | B | Serializer.Literal.swift (Buffer + storage + init) + tests + Package.swift dep |
| 8 | swift-binary-base-primitives | `d8a6d80` | B + D + folded decode | 3 Encode + 3 Decode (folded sibling) + Binary.Base.16.Tests + Package.swift dep |
| 9 | swift-render-primitives | `cd4b975` | B + folded protocol | Sink.Protocol + Buffered + Chunked + Package.swift dep |
| 10 | swift-input-primitives | `89cfcbf` | D | Input.Buffer Tests.swift — byte parsing scenario `[Byte]` + Package.swift dep |
| 11 | swift-ascii-primitives | `6a00928` | G | ASCII.Classification+Collection.swift — primary retype `Byte` → `ASCII.Code` (UInt8 forwarders preserved) |
| 12 | swift-test-primitives | `d3a48d6` | G | Test.Attachment.swift (storage + init INPUT relaxation) + Tests + Package.swift dep |

### Per-site discrimination axis + generic-constraint choice

**Tier B (12 enumerated source files + sibling folds)**:

| File | Site | Axis | Generic-constraint choice |
|---|---|---|---|
| Byte.Input.View.swift | `starts(with:)` parameter | byte-domain | `some Sequence<some Byte.\`Protocol\`>` (1: most permissive) |
| Byte.Input.View.swift | `copyToOwned()` accumulator | byte-domain storage | `[Byte]` concrete (4: storage rule); boundary via `.map(\.underlying)` for Byte.Input init |
| Parser.Builder+Literal.swift | `Input == ArraySlice<UInt8>` constraint | byte-domain | `ArraySlice<Byte>` concrete (4) |
| Byte.Literal.Serializer.swift | Buffer.Element constraint | byte-domain | `Buffer.Element == Byte` concrete (4 of brief variant for type-level constraint) |
| Byte.Literal.Serializer.swift | storage `bytes: [UInt8]` | byte-domain storage | `[Byte]` concrete |
| Byte.Literal.Serializer.swift | `init(_ bytes:)` | byte-domain | `some Sequence<some Byte.\`Protocol\`>` (1) |
| Byte.Serializer.swift (folded) | Buffer.Element constraint | byte-domain | `Buffer.Element == Byte` concrete |
| Serializer.Builder+Literal.swift | `where B.Element == UInt8` constraint | byte-domain | `B.Element == Byte` concrete |
| Input.Slice.swift | none (generic over `Base: ~Copyable`); doc example only | n/a | doc example UInt8→Byte |
| Parser.Parser+parse.swift | none (generic over Parser.Protocol); doc example only | n/a | doc example UInt8→Byte |
| Parser.Take.Builder.swift | byte-array literal overload | byte-domain | RELOCATED to swift-byte-parser-primitives per Wave 3 byte-extraction pattern |
| Serializer.Literal.swift | Buffer constraint + storage + init | byte-domain | `Buffer.Element == Byte` + `[Byte]` storage + `some Sequence<some Byte.\`Protocol\`>` init |
| Property+Binary.Base.16.Encode.swift | bytes + alphabet parameters | byte-domain | `borrowing [Byte]` concrete (4: hot-path encoders) |
| Property+Binary.Base.32.Encode.swift | bytes + alphabet + pad | byte-domain | `borrowing [Byte]`, `pad: Byte?` |
| Property+Binary.Base.64.Encode.swift | bytes + alphabet + pad | byte-domain | `borrowing [Byte]`, `pad: Byte?` |
| Property+Binary.Base.{16,32,64}.Decode.swift (folded) | alphabet + pad + return | byte-domain | `borrowing [Byte]`, `pad: Byte?`, return `[Byte]?` |
| Render.Async.Sink.Protocol.swift (folded) | write requirements | byte-domain | `some Sequence<Byte> & Sendable`, `byte: Byte` (concrete; protocol requirement clarity) |
| Render.Async.Sink.Buffered.swift | channel element + buffer + write | byte-domain | `ArraySlice<Byte>` channel, `[Byte]` storage |
| Render.Async.Sink.Chunked.swift | stream element + buffer + append | byte-domain | `AsyncStream<ArraySlice<Byte>>`, `[Byte]` storage, `S.Element == Byte` |

**Tier D (test files)**:

| File | Disposition |
|---|---|
| Byte.Input.View Tests.swift | DONE (in 379d148d) — `as [Byte]` disambiguation on 2 array-literal call sites |
| Binary.Base.16.Tests.swift | DONE (in d8a6d80) — `hexAlphabet: [Byte]`, bytes literal `[Byte]` |
| Input.Buffer Tests.swift | DONE (in 89cfcbf) — `byte parsing scenario` test only (rest is generic over Int) |
| Parser.Test.Bytes.swift | **SURFACE-AND-STOP** (class-c) — test support type with cross-package consumers in swift-parser-machine-primitives `Helpers.swift`; migration to Byte cascades into out-of-arc test infrastructure |
| Byte.Input Tests.swift | **SURFACE-AND-STOP** (non-breaking) — test compiles unchanged because Byte.Input's `init(_ bytes: [UInt8])` accepts UInt8 literals; identity-only retype has no Tier B baseline dependency |

**Tier G (ASCII-domain or special)**:

| File | Disposition |
|---|---|
| ASCII.Classification+Collection.swift | DONE (in 6a00928) — 11 primary predicates retype `Bytes.Element == Byte` → `Bytes.Element == ASCII.Code`; existing 11 @_disfavoredOverload UInt8 forwarders preserved |
| Test.Attachment.swift | DONE (in d3a48d6) — `bytes: [UInt8]` storage → `[Byte]`; INPUT `some Sequence<some Byte.\`Protocol\`>`; brief's "surface-and-stop if ambiguous" check passed (zero workspace consumers) |
| ASCII.Decimal.Float.Parser.swift | **SURFACE-AND-STOP** (class-c) — public `static func parse(_ span: borrowing Swift.Span<UInt8>)` has cross-package consumer in `swift-foundations/swift-json/Sources/JSON/JSON.Decode.Implementation.swift:671`. Body uses extensive UInt8 arithmetic (`b &- 0x30` digit extraction); ASCII.Code retype forces `.underlying` rewrites throughout. Both factors push migration into arc B's IETF/ISO/foundations consumer-cascade territory. |
| ASCII.Decimal.Float.Slow.swift | **SURFACE-AND-STOP** — `slowPath` is the fallback for Parser.swift's Span entry; migrating in isolation desynchronizes the call signature. Defer to coordinated Tier-G follow-up alongside Parser.swift. |
| Binary.Base.62.Alphabet.swift | **SURFACE-AND-STOP** (class-c cascade) — rubric "Base62 alphabet = ASCII.Code; raw input = Byte" requires retyping `init(_ bytes: [UInt8])` + `encode(_:UInt8)` + `decode(_:UInt8) -> UInt8?` + `isValid(_:UInt8)` + `encodeTable: [UInt8]` to ASCII.Code substrate. The cascade pulls in Property+Binary.Base.62.Encode.swift (`standardAlphabet`, `gmpAlphabet`, `invertedAlphabet` named alphabets + `callAsFunction(alphabet:)`) and Property+Binary.Base.62.Decode.swift (`digit(_:byte:)`, `isValid(_:byte:)`), plus extensive test rewrites in Binary.Base.62.{Alphabet,}.Tests.swift (which heavily use `UInt8(ascii: "X")` patterns). Substantive design work beyond the file's explicit enumeration in Tier G. |

### Discrimination patterns established / refined

- **INPUT-side most-permissive form**: `some Sequence<some Byte.\`Protocol\`>` is the spec preference; works whenever the body only iterates (`for byte in bytes`). Compares via `.byte` accessor to unify with concrete `Byte` (`observed == byte.byte`).
- **Storage rule applies to type-field storage, not transient local accumulators in function bodies** — when a function's local `var bytes` immediately feeds an out-of-scope init taking `[UInt8]`, accumulating `[Byte]` with `.map(\.underlying)` bridge at the boundary is the right shape (preserves byte-domain identity in the visible code path without forcing out-of-scope edits).
- **Concrete `[Byte]` (option 4) is justified** for hot-path encoders/decoders where the algorithms require RandomAccessCollection with Int Index (`bytes[i]`, `bytes[i+1]`, `bytes[i+2]` peek-ahead in Base64). Generic `some Collection<Byte>` doesn't satisfy without Int-Index constraint; Array is the natural input shape from callers.
- **Sibling fold pattern**: when a Tier B file's public API is the type-level constraint of a struct with sibling files in the same package (e.g., Byte.Literal.Serializer ↔ Byte.Serializer; Property+Binary.Base.N.Encode ↔ Property+Binary.Base.N.Decode; Sink.Buffered ↔ Sink.Chunked ↔ Sink.Protocol), folding the sibling preserves package coherence at commit time per [HANDOFF-019] commit-as-you-go and [SUPER-046] alpha-pace.
- **Wave 3 byte-extraction pattern carried forward**: byte-domain overloads in byte-domain-agnostic packages (swift-parser-primitives, formerly swift-serializer-primitives) move out to byte-aware packages rather than adding `swift-byte-primitives` as a new architectural dep upstream. swift-parser-primitives' Parser.Take.Builder byte-array literal overload relocated to swift-byte-parser-primitives' Parser.Builder+Literal.swift.
- **Package.swift dep additions** (per-package, path-form per swift-package skill pre-publishable default): swift-serializer-primitives, swift-binary-base-primitives, swift-render-primitives, swift-input-primitives, swift-test-primitives each add `swift-byte-primitives` path dep + `Byte Primitives` product to the affected target. Each test target additionally needs `Byte Primitives` because `MemberImportVisibility` requires test files importing `Byte` directly.
- **Test-fix bundle scope**: tests that BREAK from Tier B source migrations (Byte.Input.View Tests, Binary.Base.16.Tests, Byte.Literal.Serializer Tests, Byte.Serializer Tests, Serializer.Literal Tests) are bundled with the source migration in the same commit. Tests that need only byte-domain identity clarification (Byte.Input Tests, Parser.Test.Bytes) without breaking are left for arc-coordinated follow-up.

### Class-c surface for principal

1. **Parser.Test.Bytes.swift** — Tier D entry on the brief but its cascade through swift-parser-primitives/Tests/Support/{Parser.Test.Iterator,Parser.Test.Input}.swift AND swift-parser-machine-primitives' Helpers.swift (cross-package test helpers) makes migration scope substantially larger than a single-file retype. Recommend: bundle Parser.Test.Bytes + Iterator + Input + cross-package Helpers into a single coordinated test-infrastructure migration arc after lint rules ([API-BYTE-003] / [API-BYTE-004]) have surfaced the broader cascade scope.
2. **ASCII.Decimal.Float.{Parser,Slow}.swift** — Tier G "→ ASCII.Code" rubric. Cross-package consumer in swift-foundations/swift-json's JSON.Decode.Implementation.swift:671 (`ASCII.Decimal.Float.parse(span)` with `Span<UInt8>`) puts this in arc B's foundations consumer-cascade territory by structural necessity. Defer to coordinated arc-B + arc-C handoff or post-W4 arc.
3. **Binary.Base.62.Alphabet.swift** — Tier G "Base62 alphabet = ASCII.Code; raw input = Byte" rubric. Single-file enumeration in brief but the type's API surface is consumed by Property+Binary.Base.62.{Encode,Decode}.swift (named alphabets, byte-level lookup APIs) AND extensively used in Base62 tests with `UInt8(ascii: "X")` patterns. Migration requires 3 source files + 2 test files coordinated, plus consumer-call-site retypes — beyond the explicit brief enumeration.

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
