# UInt8 Elimination — Phase 0 Inventory & Gap Analysis

<!--
---
version: 1.0.0
last_updated: 2026-05-25
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Executive Summary

This is the Phase 0 inventory + gap analysis for the **UInt8 elimination
program** — the work of confining `UInt8` to genuinely structurally-forced
sites and moving everything else to `Byte`, `ASCII.Code`,
`Unicode.UTF8.CodeUnit`, `Path.Char`, or other typed substrate per the
substrate matrix. It precedes (and sizes) any lint-rule-promotion arc,
API surgery, or migration cohort.

**Headline numbers** (verified via `rg` across the 7 active institute org
dirs on 2026-05-25; `swift-iec` contains zero `UInt8`):

| Measure | Count |
|---|---|
| Raw `\bUInt8\b` source lines | **5,867** across 944 files |
| In `Tests/` | 2,416 (41%) |
| Comment-leading | 1,089 (19%) |
| **Clean migratable universe** (source, non-test, non-comment) | **2,540** |
| Migration progress proxy — clean `Byte` : `UInt8` | 1,807 : 2,540 (~42% migrated, L1-heavy) |

**The four `ask:` conditions from the dispatch brief — adjudicated:**

| `ask:` condition | Triggered? | Finding |
|---|---|---|
| **#1** — any single package > 200 sites | **YES (2 pkgs, clean basis)** | `swift-iso-32000` (385 clean) and `swift-ascii-primitives` (360 clean) each exceed 200 *clean* sites → each is its own multi-wave program. On a *raw* basis `swift-ascii` (600→165 clean) and `swift-binary-primitives` (251→**25** clean) also exceed 200, but their migratable surface does not. |
| **#2** — Byte shift-API cascade > 100 sites | **NO** | The `rhs: UInt8` shift count appears in exactly **2 operator definitions** (`Byte.Protocol+Bitwise.swift:70,80`) and **zero** explicit `byte >> UInt8(…)` consumer sites. The cascade is ~2 sites; consumers pass integer literals that re-infer. A cheap, optional enabler — not a blocking subprogram. |
| **#3** — substrate-matrix gap (uncovered domain) | **YES** | **Legacy single-byte PDF text codecs** (31 sites in `swift-iso-32000`: WinAnsi/MacRoman/CP1252/Standard/Symbol/ZapfDingbats/MacExpert/PDFDoc) are `Unicode.Scalar ↔ byte` transforms over **non-Unicode** code pages. They fit neither `Byte` (they are codec contracts) nor the matrix's `CODEC` row (scoped to UTF-8/16/32). Needs a principal disposition / new matrix row. A second, smaller gap: ~13 IETF `struct { let rawValue: UInt8 }` wire-field carriers escape the mechanical `enum:UInt8` rule and need per-type `[API-BYTE-004]` disposition. |
| **#4** — AST-detectable coverage < 70% | **YES (decisively)** | Only **~8–10%** of clean sites are mechanically classifiable from AST alone (the forced allow-list: carrier/SLI paths, `@_disfavoredOverload`, enum/OptionSet syntax, typed pointer/buffer). The remaining **~90%** require domain judgment (byte vs ASCII vs codec vs arithmetic vs C-ABI-internal) that AST cannot resolve — the same limit `[API-BYTE-004]` and `[MOD-016]` already document. |

**Recommendation: PULL BACK to a gradual, migration-first lint shape.**
The aggressive "forbid `UInt8` by default; allow stdlib-protocol + C-ABI +
carrier-axis + per-site stamp" rule is **not feasible to land now** — it
would fire on the ~2,300-site semantic residual with high false-positive
density and replay the `[MOD-016]` validation-ladder revert. Instead,
sequence per §Outcome: (1) optional cheap Byte-shift-signature enabler;
(2) per-package migration of the BYTE/ASCII/CODEC zones (the six existing
`[API-BYTE-*]` rules already mechanically cover the witness/SLI/ascii-
extension/forwarder sub-zones); (3) principal disposition on the matrix gap
and the enum/struct-rawValue question; (4) **only then** a narrow
"forbid un-stamped `UInt8` outside the allow-list" rule against the
now-genuinely-forced residual.

---

## Context

`Byte` was introduced precisely to displace `UInt8` as the canonical
8-bit-data representation (`byte-primitive-extraction-and-domain-naming.md`
v1.0.1 DECISION; `byte-protocol-capability-marker.md` v1.1.0). The
substitution landed at L1 byte-IO primitives and cascaded partway up via
the W2/W3 program (`broader-l2-l3-byte-typing-gap-plan.md` v1.0.0
IN_PROGRESS), but stalled before reaching the bulk of L2/L3. Across the
rest of the ecosystem `UInt8` persists in many sites the byte-discipline +
substrate matrix would classify as vestigial — but also in many that are
genuinely forced.

The principal's end-state intent: **`UInt8` confined to genuinely
structurally-forced sites only** (stdlib closure/boundary protocols, C-ABI
declaration boundaries, `swift-byte-primitives`' own carrier-axis storage,
arithmetic-domain operands, and per-site-stamped carryovers). Everything
else moves to typed substrate.

Two 2026-05-22 dispatches grounded the substrate matrix operationally —
the **byte-IO migration** (`HANDOFF-byte-io-migration.md`, waves 1/2/4
landed) and **filename-storage Phase A/B** (`HANDOFF-filename-storage-phase-a.md`,
per-site `// substrate: <domain>` stamping proven mechanical). Principal
direction: **promote enforcement to mechanical lint rather than another
skill rule** (the skill should shrink, not grow). This inventory tells us
whether the aggressive shape is feasible and what upstream API surgery is
needed before it can be.

## Question

1. How many source-level `UInt8` mentions exist across the 8 institute org
   dirs, stratified by package, layer, and site shape?
2. How does each site classify against the substrate matrix?
3. What migration scope per substrate category, and what **subprograms**
   (upstream API changes, ASCII inventory, C-ABI audit, enum rawValue) does
   the inventory imply?
4. Given AST-only detection, is the **aggressive** lint rule feasible, or
   should the program pull back to a **gradual** shape?

## Methodology

- **Inventory** (Task 1): `rg '\bUInt8\b'` across the 7 non-empty org dirs,
  excluding `.build/`, `Experiments/`, `.worktrees/`, `Documentation.docc/`.
  Three count strata: *raw* (all matches), *non-test* (excl. `Tests/`),
  *clean* (non-test, with comment-leading lines `//`,`///`,`*` filtered
  out). "Clean" is the migratable universe; raw is reported for
  reconciliation.
- **Classification** (Task 2): pattern-stratified bucketing, then per-zone
  deep classification. Five parallel read-only sub-agents classified the
  heavy zones (ASCII packages; ISO/PDF; L1 binary/parser/serializer
  cluster; L3 foundations render/parse/IO; IETF RFC wire formats) against a
  verbatim-enumerated 12-class taxonomy (per `[RES-030]`, to prevent
  class force-fitting). The cross-cutting C-ABI audit, the carrier zone,
  the forced-zone allow-list counts, and the long tail were classified
  directly.
- **Empirical verification** (`[RES-023]`): every count was produced by a
  cited `rg` invocation on 2026-05-25; the `enum X: Byte` type-system claim
  was verified by a `swiftc -typecheck` spike in `/tmp` (not asserted from
  skill text, per `feedback_convention_vs_typesystem_constraint`); the
  normative substrate matrix was read from both source-of-truth handoffs.
- **No source modification.** Research-only; the only artifacts written are
  this doc, its `_index.json` entry (`[RES-003c]`), and the closeout
  appended to the dispatch brief.

### Caveats on the numbers

- Pattern buckets (`[UInt8]`, `: UInt8`, …) **overlap** and are line-counted
  (a line with N mentions counts once); they characterize composition, not
  a partition.
- Sub-agent per-class counts and the directly-measured clean totals diverge
  by ~1% (line-vs-occurrence counting; `Experiments/` handling). The
  per-zone tables are the precise source; aggregate class totals are stated
  as approximate.
- "Migration progress" (`Byte` : `UInt8`) uses a `\bByte\b` word-grep proxy
  that over-counts (type names, `Byte.Input`, etc.); it is a directional
  macro-indicator, not a site count.

## Prior Research Consulted (`[RES-019]` / `[HANDOFF-013]`)

Internal grep first; no near-duplicate exists (no prior `*uint8*` /
`*elimination*inventory*` doc). This doc **extends** the following; it does
not re-derive them:

| Doc | Status | Relationship |
|---|---|---|
| `broader-l2-l3-byte-typing-gap-plan.md` | v1.0.0 IN_PROGRESS | **Parent.** The W2/W3 cascade plan + per-wave outcomes + the post-W2 six-`[API-BYTE-*]`-rule arc + the discrimination-pattern catalog. This doc is the *ecosystem-wide* Phase-0 inventory that the parent's per-wave work implies. |
| `binary-byte-namespace-domain-foundations.md` | v3.1.0 IMPLEMENTED | The Bit/Byte/Binary three-layer model; `Binary.Serializable.Buffer.Element == Byte` retype. Grounds why witness signatures are already `Byte`. |
| `byte-primitive-extraction-and-domain-naming.md` | v1.0.1 DECISION | `Byte` type identity vs `UInt8`. |
| `byte-protocol-capability-marker.md` / `byte-arithmetic-conformance.md` | v1.1.0 / v1.0.0 | Q1/Q3 anchors: `UInt8` ⟂ `Byte.\`Protocol\``; `Byte` has no arithmetic. Source of the carrier-axis and arithmetic-domain forced classes. |
| `ascii-domain-ownership-audit.md` | SUPERSEDED | ASCII-domain ownership (superseded; cited for lineage only). |
| `feedback_byte_canonical_minimize_uint8`, `feedback_domain_classify_before_cohort_retype` | memory | The "UInt8 only where necessary/appropriate" rule and the ASCII-vs-byte-vs-codec discrimination. |
| `byte-discipline` skill `[API-BYTE-001..007]` | skill | The six mechanized rules + the `[API-BYTE-004]` W2 discrimination rubric (the substrate matrix's load-bearing principle). |

---

## Task 1 — Workspace-Wide UInt8 Inventory

### Per-layer (raw / non-test / clean)

| Layer | Org dirs | Raw | Non-test | Tests | Comment-leading |
|---|---|---:|---:|---:|---:|
| L1 Primitives | `swift-primitives` | 1,975 | 1,056 | 919 (47%) | 473 |
| L2 Standards | `swift-standards`, `swift-iso`, `swift-ietf`, `swift-ieee`, `swift-incits` | 1,894 | 1,442 | 452 (24%) | 314 |
| L3 Foundations | `swift-foundations` | 1,998 | 953 | 1,045 (52%) | 302 |
| **Total** | | **5,867** | **3,451** | **2,416** | **1,089** |

Clean (source, non-test, non-comment) total: **2,540**. (`swift-iec`: 0
sites.)

### Per-package (raw → clean), packages with the largest surfaces

| Package | Layer | Raw | Clean | >200 clean? |
|---|---|---:|---:|:---:|
| `swift-iso-32000` | L2 | 464 | **385** | ✅ |
| `swift-ascii-primitives` | L1 | 483 | **360** | ✅ |
| `swift-ascii` | L3 | 600 | 165 | — |
| `swift-decimals` | L3 | 164 | 149 | — |
| `swift-plist` | L3 | 91 | 70 | — |
| `swift-iso-14496-22` | L2 | 73 | 65 | — |
| `swift-html-render` | L3 | 161 | 62 | — |
| `swift-json` | L3 | 199 | 60 | — |
| `swift-lexer-primitives` | L1 | 62 | 59 | — |
| `swift-svg-render` | L3 | 62 | 32 | — |
| `swift-institute-linter-rules` | L3 | 195 | 32 (meta) | — |
| `swift-binary-primitives` | L1 | 251 | **25** | — |
| `swift-iso-9945` | L2 | 75 | 28 | — |
| (IETF, 43 pkgs) | L2 | 1,006 | 552 | — (none >200) |

**Key inversion:** raw counts badly overstate migration scope. `swift-binary-primitives`
(251 raw) is already ~migrated — **25** clean source sites remain, almost all
forwarders. `swift-ascii` (600 raw) is 379 test lines + 56 comments → 165
clean. The `ask:` #1 multi-wave-program signal applies on the **clean**
basis to exactly two packages: `swift-iso-32000` and `swift-ascii-primitives`.

### Pattern stratification (clean line counts; buckets overlap)

| Shape | Clean | Note |
|---|---:|---|
| `[UInt8]` array literal | **678** | dominant; the migration heart |
| `: UInt8` (param/property/typealias, broad) | 773 | superset of the next two |
| `UInt8(…)` construction | 387 | |
| `: UInt8 {` (rawValue/property decl) | 154 | |
| `-> UInt8` (return) | 61 | |
| `Unsafe*Pointer<UInt8>` | 55 | C-ABI + byte-cursor |
| `Unsafe*BufferPointer<UInt8>` / `Span<UInt8>` | 35 | stdlib boundary |
| `UInt8.self` (load/bind/rebind) | 26 | |
| `enum X: UInt8` (single-line) | 10 | + multi-line (rare) |
| `rhs: UInt8` (shift/bitwise operator defs) | 3 | subprogram 1 |

### Migration-progress macro indicator (clean `Byte` : `UInt8` proxy)

| Layer | `Byte` | `UInt8` | Reading |
|---|---:|---:|---|
| L1 Primitives | 800 | 636 | **Byte-majority** — well-migrated |
| L2 Standards | 805 | 1,146 | UInt8-majority — partially migrated |
| L3 Foundations | 202 | 758 | **Heavily UInt8** — barely started |

This confirms the brief's thesis directly: the byte substitution advanced
at L1 (byte-primitives + the W2 cascade) and thins going up the stack.

---

## Task 2 — Per-Site Classification Against the Substrate Matrix

### The normative substrate matrix

Read from both sources of truth (`HANDOFF-byte-io-migration.md` § Substrate
Matrix; `HANDOFF-filename-storage-phase-a.md` Amendment 2) — normative-equivalent,
verified 2026-05-25:

| Domain | Site characteristic | Substrate | Disposition |
|---|---|---|---|
| **Byte-domain** | file content, network payload, mmap region, opaque buffer | `Byte` | migrate |
| **Code-unit** | platform-native filename / path / string code units | `Path.Char` / `String.Char` / `String_Primitives.String(.Borrowed)` | migrate |
| **ASCII-strict** | validated US-ASCII (0x00–0x7F), INCITS, ASCII grammars | `ASCII.Code` | migrate |
| **Codec** | explicit UTF-8 / UTF-16 / UTF-32 code units | `Unicode.UTF{8,16,32}.CodeUnit` | migrate |
| **Stdlib boundary** | `withUnsafeBytes` callback, `UnsafeRawBufferPointer.Element`, `String.UTF8View.Element` | `UInt8` stays | forced |
| **Enum rawValue / OptionSet** | compact rawValue convention | `UInt8` stays | forced (idiom; see subprogram 4) |
| **Arithmetic / shift count / carrier** | bitwise op counts, bit-field constants, `Byte.underlying` | `UInt8` stays | forced |
| **C-ABI** | POSIX `char *`, `dlerror`, `getenv`, syscall struct field | `UInt8` at boundary, bridge via `.underlying` | forced |

The brief adds two operational rows: **Needs upstream API change** (TBD →
subprogram) and **Test-only** (stratified separately). The classification
taxonomy used `BYTE / CODEUNIT / ASCII / CODEC / FORCED-STDLIB / FORCED-ENUM
/ FORCED-ARITH / FORCED-CABI / FORWARDER / UPSTREAM / TEST / AMBIGUOUS`.

> **Load-bearing principle** (`[API-BYTE-004]`): the byte-vs-arithmetic-domain
> axis determines substrate, and *"AST cannot reliably distinguish
> arithmetic-domain vs byte-domain usage without cross-function-body
> analysis."* This is the crux of Task 4.

### Per-zone classification (clean source sites)

#### Zone A — ASCII packages (`swift-ascii-primitives`, `swift-ascii`, `swift-ascii-parser-primitives`) — 532 clean

| Class | Count | |
|---|---:|---|
| **ASCII** | **315** | migratable → `ASCII.Code` (predicates, named alphabet constants, vestigial `extension UInt8` / `Binary.ASCII` accessors) |
| FORCED-ARITH | 188 | carrier-axis constants (147 in `Carrier.Protocol+ASCII.swift`), bit-field flags, digit arithmetic |
| FORWARDER | 18 | `@_disfavoredOverload`, fully isolated in the two `* Standard Library Integration` dirs |
| FORCED-STDLIB | 7 | unsafe-pointer / literal-witness |
| AMBIGUOUS | 4 | parser-input byte-vs-ASCII-stream border |

Zero BYTE/CODEC/CODEUNIT/ENUM/CABI — confirming these are ASCII-strict, not
byte-substrate packages. **Design tension:** the package already carries a
*typed* ASCII-constant surface (`ASCII.Namespace<Owner>` carrier constants)
*alongside* the legacy raw-`UInt8` `ASCII.Character.Graphic/Control`
constants; reconciling the two — and deciding where digit/case arithmetic
(`Graphic.\`0\` + value`) lives once constants become `ASCII.Code` — is the
real subprogram-2 work, not a mechanical retype.

#### Zone B — ISO / PDF (`swift-iso-32000`, `swift-iso-9945`, `swift-iso-14496-22`) — 478 clean

| Class | iso-32000 | iso-9945 | iso-14496-22 | Σ |
|---|---:|---:|---:|---:|
| **BYTE** | 342 | 0 | 55 | **397** |
| AMBIGUOUS | 31 | 0 | 0 | 31 |
| FORCED-CABI | 0 | 20 | 0 | 20 |
| FORCED-ARITH | 5 | 1 | 8 | 14 |
| CODEC | 7 | 0 | 2 | 9 |
| FORCED-ENUM | 0 | 4 | 0 | 4 |
| CODEUNIT | 0 | 3 | 0 | 3 |

`swift-iso-32000` is 89% BYTE (PDF content streams, object/string/font/image/
signature buffers, Annex D byte constants). **Highest-leverage single edit:**
`ISO 32000 3 Terms and definitions/3.7 byte.swift:26 — public typealias Byte = UInt8`;
repointing it at the ecosystem `Byte` struct converts a large fraction of the
342 BYTE sites at once (but breaks every arithmetic/stdlib-interop call site
relying on `Byte == UInt8` — so it is a scoped decision, not a free swap).
The 31 AMBIGUOUS = the legacy single-byte-codec matrix gap (§ask #3).
`swift-iso-9945` is a pure forced-floor (C-ABI walled in `ISO 9945.ABI.CChar.swift`;
the typed `Path.Char` / `Span<Byte>` layer already sits on top).

#### Zone C — L1 binary/parser/serializer cluster + `swift-ieee-754` (12 pkgs) — 158 clean

| Class | Count | |
|---|---:|---|
| FORCED-ARITH | 80 | lexer raw-pointer keyword matchers (58), base-N decode tables/bit-accumulators, the `UInt8: Carrier.Protocol` axis |
| FORWARDER | 38 | `@_disfavoredOverload` bridges, already in SLI targets |
| **BYTE** | 32 | **31 in `swift-ieee-754`** (`[UInt8]` octet-serialization public API) + 1 (`Parser.Match.Error.byteMismatch`) |
| FORCED-STDLIB | 7 | `Span<UInt8>` interop views, `ManagedBuffer<_,UInt8>` |
| FORCED-ENUM | 2 | `Token.Keyword: UInt8`, `IEEE_754.Status` OptionSet |

**82% forced/forwarder.** The migratable BYTE surface is essentially one
package (`swift-ieee-754`'s public `[UInt8]` octet API — a breaking surface
rewrite, not internal cleanup). Confirms the `swift-lexer-primitives` 18
`UnsafePointer<UInt8>` sites are **byte-comparison keyword matchers
(FORCED-ARITH), not C-ABI**.

#### Zone D — L3 foundations render/parse/IO (11 pkgs) — 461 clean

| Class | Count | |
|---|---:|---|
| **BYTE** | 208 | render/JSON byte-stream payload (`Buffer.Element == UInt8`, `[UInt8]`) — codebase self-identifies these as "byte-stream payload" |
| FORCED-ARITH | 183 | **`swift-decimals` 144** (decimal-digit `byte − UInt8(ascii:"0")` math) + plist bit-field markers |
| FORCED-STDLIB | 35 | render targets, `AsyncSequence<UInt8>` elements |
| **CODEUNIT** | 16 | `swift-file-system` path/filename, `swift-strings` POSIX `String.Char` |
| **CODEC** | 10 | `String(decoding:as:UTF8.self)`, `swift-strings` UTF-8 validation |
| FORCED-ENUM | 6 | `File.System.Write.{Durability,Strategy,Phase}` + `Decimal.Status` OptionSet |
| **ASCII** | 3 | `swift-parsers` grammar predicates (gated on `Substring.UTF8View` element) |
| AMBIGUOUS | 3 | plist nibble extraction (byte-vs-arith border) |

51% migratable. **`swift-sockets` has no declaration-boundary C-ABI** (sockaddr
abstracted) — its `UInt8` is payload `Span<UInt8>` (BYTE) + IPv6 word→byte
packing (FORCED-ARITH). This refutes the "sockets = C-ABI" prior.

#### Zone E — IETF RFC wire formats (43 pkgs) — 552 clean

| Class | ≈Count | |
|---|---:|---|
| **BYTE** | ~205 | DEFLATE/zlib, HTTP bodies, MIME, crypto secrets, generic `Element == UInt8` streams |
| FORCED-ARITH | ~95 | byte-split `>> & 0xFF`, checksums, XOR masking, bit constants |
| FORCED-STDLIB | ~48 | `String(decoding:as:)`, `withUnsafeBytes`, `unsafeUninitializedCapacity` |
| **ASCII** | ~40 | Base16/32/64 alphabets, URI/HTTP/MIME grammar predicates |
| FORCED-ENUM | ~38 | incl. ~13 `struct {rawValue:UInt8}` wire carriers (see §ask #3) |
| AMBIGUOUS | ~18 | UUID 16-byte tuple storage; the rawValue-struct carriers |
| FORWARDER | ~19 | SLI bridges (rfc-791/768/6455) |
| CODEC | ~2 | near-absent (the `String.init(decoding:as:)` contract reads as FORCED-STDLIB) |

Zero FORCED-CABI / CODEUNIT (pure-Swift spec packages). **Only 4 true
`enum: UInt8`** — all wire-pinned (UUID version ×2, DEFLATE block-type, TCP
option-kind); **zero pure-Swift enums.** A stale "blocked on non-migrated
dep" comment in `swift-rfc-2046` was **refuted by verification** (the called
serializers already emit `Buffer.Element == Byte`); recommend flagging it
stale during migration.

#### Zone F — carrier, meta, and the long tail

| Sub-zone | Clean | Disposition |
|---|---:|---|
| `swift-byte-primitives` (carrier axis) | 16 | FORCED-ARITH — `Byte.underlying`, the `UInt8` backing; stays by definition |
| `swift-institute-linter-rules` (meta) | 32 | **Excluded** — these `UInt8` mentions are the byte-discipline *detector logic + fixtures*, not migration targets |
| Uncovered L1 primitives tail (~26 small pkgs) | ~126 | forced-dominant (carrier in bit/cpu/async/hash; stdlib in memory) + thin BYTE band (io/render/byte-parser/structured-queries) + ASCII band (ascii-serializer, glob) |
| Uncovered L3 foundations tail (`process`, `xml`, `io`, `source`, `console`, …) | ~100 | BYTE-dominant (`process` capture buffers, `xml` byte streams, `io`); `process` is **not** declaration-boundary C-ABI |
| L2 `swift-standards` + `swift-incits` tail | ~63 | `incits-4-1986`=ASCII; postgresql/email/color mixed BYTE/ASCII |

Tail coarse split (sampled): ~71 byte-ish vs ~43 forced vs ~33 arith-literal
— roughly half migratable, half forced; Phase-1 per-package classification
will refine.

### Aggregate class totals (clean, approximate)

| Class | ≈Count | % of clean | Disposition |
|---|---:|---:|---|
| **BYTE** | ~900 | ~35% | migrate → `Byte` |
| **ASCII** | ~385 | ~15% | migrate → `ASCII.Code` |
| **CODEUNIT** | ~22 | ~1% | migrate → `Path.Char`/`String.Char` (overlaps filename-storage program) |
| **CODEC** | ~21 | ~1% | migrate → `Unicode.UTF{8,16,32}.CodeUnit` |
| FORCED-ARITH | ~576 | ~23% | stays |
| FORCED-STDLIB | ~105 | ~4% | stays |
| FORWARDER | ~75 | ~3% | stays (already in SLI) |
| FORCED-ENUM | ~50 | ~2% | stays (idiom) / disposition (subprogram 4) |
| FORCED-CABI | ~27 | ~1% | stays (concentrated in iso-9945) |
| AMBIGUOUS | ~56 | ~2% | needs disposition (§ask #3) |
| (meta-excluded) | 32 | — | — |

**Migratable (BYTE+ASCII+CODEUNIT+CODEC) ≈ 1,328 (~52%); forced ≈ 833 (~33%);
ambiguous ≈ 56; meta-excluded 32; tail not-fully-split ≈ remainder.**

### Ambiguous sites (flagged, not dropped — per supervisor MUST)

| Cluster | Count | Border | Disambiguation needed |
|---|---:|---|---|
| Legacy single-byte PDF codecs (iso-32000) | 31 | byte-vs-codec | matrix gap — extend CODEC to non-Unicode codecs, or `Byte` + separate scalar map (§ask #3) |
| IETF `struct {rawValue:UInt8}` wire carriers | ~13 | enum-vs-`[API-BYTE-004]`-rawValue | per-type disposition: byte-domain → `Byte`, arithmetic → `UInt8` |
| UUID 16-byte tuple storage (rfc-4122/9562) | ~5 sites (~100 tokens) | byte-tuple-vs-interop | `(Byte ×16)` vs `UInt8` for `withUnsafeBytes` hashing interop |
| ASCII parser-input stream (ascii-parser, ascii validation) | 4 | ASCII-vs-byte-stream | does the parser screen arbitrary bytes (byte-in, ASCII.Code-out) or assume ASCII? |
| Plist binary nibble extraction | 3 | byte-vs-arith | does `Byte` expose nibble/bit-mask accessors? |

---

## Task 3 — Gap Analysis & Subprograms

### Per-category migration scope

| Category | In target shape | Needs migration | Scope concentration |
|---|---|---|---|
| Byte-domain | ~1,807 `Byte` sites (proxy) | ~900 `UInt8` BYTE | iso-32000 (342, via typealias), L3 render/json (208), IETF (205), ieee-754 (31 public API), iso-14496-22 (55), L3 tail (process/xml/io) |
| ASCII-strict | typed `ASCII.Code`/`Owner` surface exists | ~385 | ascii-primitives (157) + ascii (158) + IETF (40) + incits (13) — **multi-wave** |
| Code-unit | `Path.Char` in use | ~22 | file-system / strings — **overlaps the in-flight filename-storage program** |
| Codec | `Unicode.UTF8.CodeUnit` in use | ~21 (+31 ambiguous) | strings, iso UTF-16, pdf |

### Subprogram 1 — Byte shift-signature API revision **(NOT a blocker; cheap optional enabler)**

`Byte.\`Protocol\``'s shift operators take `rhs: UInt8`
(`Byte.Protocol+Bitwise.swift:70,80`); all other bitwise ops (`& | ^ ~`)
take `Self`. The brief flagged the `rhs: UInt8` count as vestigial.

- **Cascade size: ~2 sites.** Verified: **zero** `(<<|>>) UInt8(` consumer
  sites; only 3 `rhs: UInt8` operator definitions (2 are these shifts; 1 is
  an unrelated `Bit ^ UInt8`). Consumers pass integer literals (`byte >> 4`)
  that re-infer if the signature changes to `Int`. **`ask:` #2 (>100): NO.**
- **Tension to surface:** `feedback_byte_canonical_minimize_uint8` (2026-05-20)
  classifies the `Byte.\`Protocol\` << UInt8` shift count as *appropriate
  arithmetic-domain* (UInt8 stays); the brief classifies the same signature
  as *vestigial*. Both are coherent — the shift *count* is arithmetic, but
  spelling it `UInt8` rather than `Int` is a stylistic vestige. **Disposition:**
  changing `rhs: UInt8 → rhs: Int` is a ~2-line, non-breaking edit that
  removes a `UInt8` token without touching consumers. Recommended as a cheap
  early enabler **if** the principal wants the token gone; otherwise harmless
  to leave (it is genuinely forced-arithmetic and lint-exempt either way).
- **Sequence position:** first / standalone; no upstream dependency.

### Subprogram 2 — swift-ascii inventory **(largest single migration program)**

- **Scope: 532 clean** across 3 packages (the brief's "165" was `swift-ascii`
  alone; `swift-ascii-primitives` adds 360, `swift-ascii-parser-primitives` 7).
  315 ASCII.Code-migratable; `swift-ascii-primitives` (360 clean) **exceeds
  200 → multi-wave (`ask:` #1)**.
- **The real work is not a retype.** The package carries *two parallel
  ASCII-constant surfaces*: the typed `ASCII.Namespace<Owner>` carrier
  constants (147 FORCED-ARITH sites) and the legacy raw-`UInt8`
  `ASCII.Character.Graphic/Control` constants (164 ASCII sites). The legacy
  constants are arithmetic-coupled (`Graphic.\`0\` + value`,
  `Graphic.A + value − 10`), so retyping them to `ASCII.Code` forces a
  decision on **where digit/case arithmetic lives** once constants are typed
  — the same axis as the 4 ambiguous parser-input sites.
- **Upstream-gated subset:** 4 sites in `swift-ascii` (`Int+ASCII.Serializable.swift`)
  hold `[UInt8]` scratch buffers only because `INCITS_4_1986.Numeric.Serialization.serializeDecimal`
  targets `Buffer.Element == UInt8`. They cannot retype until that serializer
  gains a `Buffer.Element == Byte` (or `ASCII.Code`) overload. Small upstream dep.
- **Sequence position:** mid/late — depends on the constant-surface
  reconciliation decision; not blocked by subprograms 1/3/4.

### Subprogram 3 — C-ABI propagation audit **(CONTAINED; smaller than feared)**

- **Genuine declaration-boundary C-ABI `UInt8` is concentrated in
  `swift-iso-9945`** (~20 FORCED-CABI sites), and is already correctly
  walled off: the `ISO 9945.ABI.CChar` module is the documented
  `UnsafePointer<UInt8> ↔ UnsafePointer<CChar>` projection carrier, and the
  C-string boundary sites (`getenv`, `dlerror`, `realpath`, `readlink`, `d_name`)
  use the **boundary-rebind pattern** (`let u8Ptr = UnsafePointer<UInt8>(cstr)`)
  — i.e., they rebind *at* the boundary rather than propagating `UInt8`
  upward. **There is no widespread "propagates past the boundary without
  rebinding" anti-pattern.**
- The filename/path C-ABI subset (`dirent.d_name`, `realpath`, `readlink`)
  is **CODEUNIT-domain** and already in scope of the in-flight
  **filename-storage program** (→ `Path.Char`); the genuine C-string subset
  (`getenv` values, `dlerror`) stays `UInt8` at the boundary.
- `swift-process` capture buffers (`[UInt8]` stdout/stderr drain) are **BYTE**
  (uninterpreted output), not declaration-boundary C-ABI. `swift-sockets`
  has none (sockaddr abstracted). The platform packages (`swift-darwin`,
  `swift-kernel`, `swift-loader`, …) import C modules but were not deep-classified;
  a Phase-1 spot-check is advisable, but the iso-9945 pattern (rebind +
  `ABI.CChar` wall) is the template and the surface is small.
- **Sequence position:** largely *already handled* by iso-9945's existing
  wall + the filename-storage program; residual is a small Phase-1 spot-check.

### Subprogram 4 — Enum / struct rawValue audit **(principal-disposition, small cascade)**

- **Type-system fact (empirically verified, not asserted):** a `struct` with
  `Byte`'s conformance set (`Equatable, Hashable, Comparable, Sendable,
  ExpressibleByIntegerLiteral`) **is a legal raw-value-enum raw type** —
  `enum E: ReplicaByte { case a = 1 }` type-checks (`swiftc -typecheck`,
  `/tmp`, exit 0). So **`enum X: Byte` is expressible**; the matrix's "enum
  rawValue → UInt8 stays" is an *idiom/convention choice, not a language
  force* — **except OptionSet**, whose `RawValue: FixedWidthInteger`
  requirement `Byte` cannot satisfy (`[API-BYTE-002]`), so **OptionSet
  rawValue is hard-forced UInt8.**
- **Already underway:** 26 `rawValue: Byte` sites already exist ecosystem-wide
  — proof the rawValue→Byte migration is viable and partially done.
- **Remaining `UInt8` rawValues** (~69 clean): split into
  - **4 true `enum: UInt8`, all wire-pinned** (UUID version ×2, DEFLATE
    block-type, TCP option-kind) + a few pure-Swift (`File.System.Write.*`,
    `Token.Keyword`, `Bit`, `Async.Completion.State` — the last is
    `AtomicRepresentable`, hard-forced for atomics);
  - **~13 IETF `struct {rawValue:UInt8}` wire-field carriers** (Opcode,
    ContentType, Handshake, Alert.*, NextHeader, TTL, IHL, DataOffset, …)
    that are *not* `enum:UInt8` and so escape the mechanical FORCED-ENUM rule
    — each needs `[API-BYTE-004]` per-type disposition;
  - the **61 OptionSet** rawValues across UInt8/16/32/64 — UInt8 ones hard-forced.
- **Cascade:** small and bounded. **Disposition is a principal question**
  (flip pure-Swift enums to `: Byte`? keep the idiom?), not a mechanical sweep.

### `ask:` thresholds — summary for principal

- **#1 (>200/pkg): YES** — `swift-iso-32000` (385 clean) and
  `swift-ascii-primitives` (360 clean) are each multi-wave programs.
- **#2 (Byte-shift cascade >100): NO** — ~2 sites.
- **#3 (matrix gap): YES** — legacy single-byte PDF codecs (31), plus the
  rawValue-struct wire-carriers needing per-type disposition.
- **#4 (AST <70%): YES** — see Task 4.

---

## Task 4 — Lint Rule Feasibility

### AST-detectable vs semantically-classifiable split

The lint rule's detection target — *"is this `UInt8` a violation?"* — requires
the substrate **domain**, which is exactly what `[API-BYTE-004]` states AST
cannot resolve. Decompose the 2,540 clean sites by what AST *can* mechanically
adjudicate:

| Mechanically classifiable from AST/path/attribute alone | ≈Count | How |
|---|---:|---|
| Carrier-axis (path = `swift-byte-primitives`) | 16 | file-path |
| SLI forwarders (path = `* Standard Library Integration` + `@_disfavoredOverload`) | ~86 | path + attribute (already `[API-BYTE-007]`) |
| `@_disfavoredOverload` UInt8 forwarders (any path) | ~40 | attribute (already `[API-BYTE-006]`) |
| `enum X: UInt8` / OptionSet rawValue | ~50 | syntax |
| Typed `Unsafe*Pointer<UInt8>` / `*BufferPointer<UInt8>` / `Span<UInt8>` at boundary | ~90 | type syntax (but boundary-vs-internal is semantic) |
| **Mechanically allow-listable subtotal** | **~200–250 (~8–10%)** | |
| **Semantic residual** (byte vs ASCII vs codec vs arith-inline vs C-ABI-internal) | **~2,300 (~90%)** | requires domain judgment |

The semantic residual is dominated by `[UInt8]` (678), `: UInt8` params
(773), and `UInt8(…)` (387) — shapes whose class depends entirely on
surrounding domain context (the same `[UInt8]` is BYTE in a render buffer,
ASCII in an alphabet, codec at a UTF-8 boundary, or arithmetic in a digit
accumulator).

**`ask:` #4 (AST-detectable < 70%): TRIGGERED decisively** — mechanical
correct-classification is ~8–10%, far below 70%.

### Per-category false-positive density (aggressive "forbid UInt8 by default" rule)

| Category | ~Count | Behaviour under aggressive rule | FP? |
|---|---:|---|---|
| FORCED-ARITH | ~576 | fires; AST can't see the arithmetic (it's in a function body) | **false positive** |
| BYTE (migratable) | ~900 | fires; correct *that* it should change, but the migration hasn't happened | premature true-positive |
| ASCII / CODEC / CODEUNIT | ~428 | fires suggesting `Byte`, but the correct substrate is `ASCII.Code`/`UTF8.CodeUnit`/`Path.Char` | **wrong-fix true-positive** |
| FORCED-STDLIB / FORCED-CABI-internal | ~130 | fires; boundary-vs-internal not AST-resolvable | **false positive** |
| FORWARDER / carrier / enum / OptionSet | ~200 | allow-listed (mechanical) | correct |

An aggressive rule landed *now* fires on ~2,300 sites, of which a large
fraction (~700+ FORCED-ARITH/STDLIB + ~430 wrong-substrate) are false or
wrong-fix. This is **the `[MOD-016]` failure mode exactly** — `[MOD-016]`
reverted at the validation ladder because AST-only detection could not
distinguish intra-module `_storage` from cross-module SPI; here AST cannot
distinguish byte-domain from arithmetic-domain (and the migratable classes
need *different* substrates, which the rule cannot suggest). The
false-positive risk is **not bounded** until the migratable zones are
migrated.

### Migration prerequisites — sites that MUST be migrated before any aggressive rule

1. The ~900 BYTE sites (else the rule fires on legitimate not-yet-migrated code).
2. The ~428 ASCII/CODEC/CODEUNIT sites (else the rule mis-suggests `Byte`).
3. Principal disposition on the ~56 ambiguous + matrix-gap sites.
4. The rawValue/enum disposition (subprogram 4).

After (1)–(4), the residual is genuinely-forced and the per-site
`// substrate: forced-<reason>` stamp pattern (proven in the filename-storage
program) makes a *gradual* rule feasible: the rule checks for the **presence**
of a stamp on a `UInt8` site outside the mechanical allow-list (mechanical),
deferring the **domain** judgment to the human-written stamp (semantic). That
is the only AST-tractable aggressive-ish shape — but it presupposes the
migration, so it is the *end* of the program, not the start.

### Recommendation: gradual, migration-first

| Option | Verdict |
|---|---|
| **Aggressive now** ("forbid UInt8 by default") | **NO** — replays `[MOD-016]`; ~90% semantic residual; high FP density |
| **Gradual / migration-first** | **YES** — the six existing `[API-BYTE-*]` rules already mechanically cover the witness/SLI/ascii-extension/forwarder sub-zones; extend coverage *as zones migrate*; land the residual stamp-rule last |

---

## Outcome

**Status: RECOMMENDATION (Tier 2, ecosystem-wide).**

**Do not pursue the aggressive lint shape as Phase 1.** The inventory shows
~2,540 clean sites of which ~52% are migratable and ~33% genuinely forced,
but only ~8–10% are mechanically classifiable from AST alone — so an
aggressive "forbid by default" rule would fire on a ~2,300-site semantic
residual with high false-positive density and revert at the validation
ladder exactly as `[MOD-016]` did.

**Recommended program sequence:**

1. **(Optional, cheap) Byte shift-signature enabler** — `rhs: UInt8 → rhs: Int`
   at 2 sites; ~zero cascade. Removes a vestigial token if the principal wants it.
2. **Principal dispositions** (gate the migration):
   - the substrate-matrix gap — legacy single-byte PDF codecs (§ask #3);
   - the enum/`struct`-rawValue question (subprogram 4: flip pure-Swift to
     `: Byte`, or keep the idiom; OptionSet stays UInt8 regardless);
   - the ascii dual-constant-surface reconciliation (subprogram 2).
3. **Per-package BYTE migration**, ordered by leverage and dep-direction:
   `swift-iso-32000` (typealias repoint, ~342) → L3 render/json/xml/io (~250)
   → IETF byte zones (~205) → `swift-ieee-754` public API (~31) → tail.
4. **ASCII migration** (subprogram 2) — the largest program; multi-wave on
   `swift-ascii-primitives`.
5. **Then** a narrow, gradual lint rule on the genuinely-forced residual,
   using `// substrate:` stamps for the AST-opaque classes — extending the
   six existing `[API-BYTE-*]` rules rather than a single aggressive rule.

This keeps the skill shrinking (mechanical enforcement grows zone-by-zone
as migration lands) rather than adding one large rule that cannot hold.

## Open Questions for Principal Disposition

- **OQ1 (matrix gap, `ask:` #3):** how to classify legacy single-byte
  text codecs (PDF WinAnsi/MacRoman/CP1252/Standard/Symbol/ZapfDingbats/
  MacExpert/PDFDoc — 31 sites)? Options: (a) add a matrix row "legacy
  single-byte codec → a typed code-unit"; (b) treat the byte as `Byte` and
  the `Scalar↔byte` map as a separate concern. Resolving this also covers
  the analogous `winAnsi`/non-UTF encoding sites in `swift-pdf-render`.
- **OQ2 (rawValue carriers):** the ~13 IETF `struct {rawValue:UInt8}` wire
  carriers (Opcode/ContentType/TTL/IHL/…) are not `enum:UInt8` and need
  per-type `[API-BYTE-004]` disposition (byte-domain → `Byte`; arithmetic →
  `UInt8`). Mechanical sweep or per-type?
- **OQ3 (enum idiom):** flip pure-Swift `enum: UInt8` (`File.System.Write.*`,
  `Token.Keyword`) to `enum: Byte` (type-system-viable), or keep the compact
  idiom? 26 `rawValue: Byte` already exist as precedent.
- **OQ4 (UUID tuple):** is UUID's 16-byte storage `(Byte ×16)` or does it
  stay `(UInt8 ×16)` for `withUnsafeBytes` interop?
- **OQ5 (shift signature):** change `Byte.\`Protocol\`` shift `rhs: UInt8 → Int`
  (subprogram 1), or leave it (forced-arithmetic, lint-exempt either way)?

## References

- `swift-institute/Audits/HANDOFF-uint8-elimination-inventory.md` — this dispatch.
- `swift-institute/Audits/HANDOFF-byte-io-migration.md` § Substrate Matrix — normative matrix source.
- `swift-institute/Audits/HANDOFF-filename-storage-phase-a.md` Amendment 2 — normative matrix source; `// substrate:` stamp pattern.
- `swift-institute/Audits/PROMOTE-MOD-016-2026-05-13.md` — the AST-only semantic-classification revert precedent.
- `broader-l2-l3-byte-typing-gap-plan.md` v1.0.0 — parent W2/W3 cascade plan + six `[API-BYTE-*]` rules.
- `binary-byte-namespace-domain-foundations.md` v3.1.0; `byte-primitive-extraction-and-domain-naming.md` v1.0.1; `byte-protocol-capability-marker.md` v1.1.0; `byte-arithmetic-conformance.md` v1.0.0.
- `byte-discipline` skill `[API-BYTE-001..007]`; memories `feedback_byte_canonical_minimize_uint8`, `feedback_domain_classify_before_cohort_retype`, `feedback_convention_vs_typesystem_constraint`.
- Empirical spike: `/tmp/byte_enum_spike.swift` — `enum E: <struct with Byte's conformances>` type-checks (`swiftc -typecheck`, 2026-05-25).
- `swift-byte-primitives/Sources/Byte Protocol Primitives/Byte.Protocol+Bitwise.swift:70,80` — the `rhs: UInt8` shift definitions.
- `swift-iso-32000/Sources/ISO 32000 3 Terms and definitions/3.7 byte.swift:26` — `typealias Byte = UInt8` (highest-leverage repoint).
