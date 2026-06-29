# ASCII Parse/Serialize Domain — Evergreen End-State

<!--
---
version: 1.3.0
last_updated: 2026-06-29
status: RECOMMENDATION (W0–W2 EXECUTED + pushed; W3 decisions principal-ratified 2026-06-29, source execution dispatched to a fresh Cleave; W4 pending)
tier: 2
scope: ecosystem-wide
changelog:
  - "1.3.0 (2026-06-29): W3/W4 open questions RESOLVED by compile-probed + adversarially-verified recon; principal-ratified. OQ1 (witness ambiguity) CONFIRMED + RESOLVED: a [Byte]-RawRepresentable type declaring Serializable+ASCII.Serializable+Binary.Serializable with no per-conformer serialize witness fails to compile (Binary.Serializable.serialize has two constraint-INCOMPARABLE defaults — binary-serializer Binary.Serializable.swift:208-218 vs W0 bridge Binary.Serializable+ASCII.swift:19-36; the ASCII.RawRepresentable twin resolves ONLY the separate serializer requirement). DECISION: per-conformer canonical serialize(_:into:) witness, retargeting each conformer's existing hand-written serialize(ascii:into:) as part of the conformance swap (conformer member out-ranks all defaults, uniform across RawValue kinds). W0 bridge LEFT UNTOUCHED (out of W3 scope; concrete witness out-ranks it; if dead post-migration → post-W3 cleanup NOTE only). RawValue-generality: collision is NOT [Byte]-exclusive — binary-serializer ships 4 incomparable defaults (StringProtocol:199, [Byte]:212, [UInt8]:224, FixedWidthInteger:269). OQ2 (non-Void context): plan's OQ4 'all Void-context' is FALSE — 5 non-Void conformers (WHATWG_URL.URL/.Host/.Path, RFC_2046.Multipart, RFC_2387.Related). W3 mechanics unchanged (write twins + plain concrete init(ascii:in:) reader); context handling DEFERRED with the principal-corrected shape: add associatedtype Context = Void to the EXISTING Parseable/ASCII.Parseable (opt-in, Void-default unaffected) — NOT a separate ContextualParseable sibling. OQ3 (linter rule): doc-comment-only (Lint.Rule.Byte.BinarySerializableUInt8Witness.swift:16); fold the stale-comment fix into the W4 deletion commit (same for swift-parser-primitives Parser.swift:53); [API-BYTE-003] stays load-bearing. C2: precise count 59 (not ~40); swift-string-primitives + swift-loader-primitives DROPPED as false positives (own String(ascii: StaticString), no ascii-serializer dep); swift-email-standard hit is the INCITS [Byte]->String? init (excluded); NO typealias re-exporters exist (INCITS-precedent shape absent across all 24). Cohort: rfc-5322 is the 5-dependent hub → early; upstream-first; swift-ascii = reference-only tail. See § 'W3 Execution Decisions'."
  - "1.2.0 (2026-06-29): W2 (OQ3) EXECUTED + pushed — ASCII.Parsing/ASCII.Serialization dissolved into ASCII.Decimal (code/serialize), ASCII.Hexadecimal (code(_:case: ASCII.Case)), and inlined ASCII.Code.digitValue/.hexValue; 12 repos pushed, all green (swift-ascii 501 tests). KEY FINDING (lesson for W3): the call-site consumer inventory under-counted TWICE — a grep anchored on the method-call form 'ASCII.Serialization.' (trailing dot) missed (a) swift-iec-61966 (a single hex call, in the swift-iec org-dir I had not scoped) and (b) swift-incits-4-1986, an L2 spec package that re-exported the dissolved namespaces via 'typealias Numeric.Serialization = ASCII.Serialization' (a TYPE reference, no call token). The authoritative consumer finder for a namespace dissolution is the loose word-boundary grep 'ASCII.(Parsing|Serialization)' (no trailing dot) across ALL per-authority org-dirs (swift-ietf/iso/iec/whatwg/incits/…), not just primitives/standards/foundations. INCITS migrated per principal decision (option A): gerund aliases → subject-domain aliases (Numeric.Decimal = ASCII.Decimal, Numeric.Hexadecimal = ASCII.Hexadecimal), parse via ASCII.Code accessors; downstream swift-ascii followed. Also surfaced: transitive-pin cascade — iso-32000 needed a full 'swift package update' to pick up the already-migrated rfc-4648, not just the L1/INCITS pins. The Step-3 subagent hit the weekly usage limit mid-run; W2 completed in-chat under principal authorization."
  - "1.1.0 (2026-06-29): W0 + W1 executed and pushed (autonomous posture, standing push authorization). W1 refined from §OQ1 by recon — see the Execution log: the Binary.ASCII parse/access facade was dead AND redundant with canonical Binary.Parse.* → DELETED (not moved); Base62 + Equals DELETED (redundant with binary-base's Binary.Base.62 and ISO_9899.String.Comparison.equals); the Decimal-machine was the one unique capability → MOVED to swift-ascii-parser-primitives as ASCII.Decimal.Machine. Binary.ASCII fully dissolved at L3 (rg→0). KEY FINDING: the parser×machine split is the owned/borrowed (Escapable/~Escapable) input duality, not primarily stack-safety — spawns the owned/borrowed parser-unification design (tracked follow-up). Two dep-hygiene follow-ups logged."
  - "1.0.0 (2026-06-29): initial. Direction principal-ratified 2026-06-29. Re-derived from first principles per explicit directive (everything in scope; prior deferral verdicts superseded). Two pressure-test corrections folded after ratification: (1) OQ1 — the Binary.Machine-bound parsing facade routes to swift-binary-parser-primitives, NOT swift-byte-parser-primitives, because binary-parser → byte-parser is an existing one-way edge and the reverse closes a [MOD-032] cycle; (2) Wave-4 deletion is gated by the @_exported umbrella blast-radius (~40 hidden convenience call sites a namespace grep misses), with a clean ecosystem build as the only sufficient proof. Supersedes the cost-gated DEFER verdicts of ascii-serialization-migration.md v2.0.0 and ascii-migration-category-b.md v3.0.0 (those deferrals were cost-driven, not architectural)."
supersedes_verdict_only:
  - ascii-serialization-migration.md            # its DEFER/Strategy-(c) verdict; analysis retained
  - ascii-migration-category-b.md               # its relocate-not-split verdict; cost analysis retained
governing_conventions:
  - operation-domain-naming-and-organization.md  # v1.1.2 DECISION — agent-noun namespace, gerund-as-alias, subject-first
  - 2026-05-15-family-codable-convention.md       # [FAM-001..009] — sibling protocol shape + namespace-rooted placement
---
-->

> **Status**: W0–W2 EXECUTED + pushed; W3 decisions principal-ratified 2026-06-29 (source execution dispatched to a fresh Cleave; see § "W3 Execution Decisions"); W4 pending. See the **Execution log (W0–W1)** section below for what actually landed — W1 was refined from §OQ1 by recon (delete-not-move). This document is the evergreen end-state plan for the ASCII parse/serialize domain across L1→L3, treating as one coherent target: (a) the `Binary.ASCII.*` L3 re-homing, (b) the deprecated `Binary.ASCII.Serializable` family retirement + ecosystem migration, (c) the L1 ASCII gerund-namespace cleanup. The single sentence: **`Binary.ASCII` ceases to exist** — its byte-domain machinery descends to the byte/binary parser layer, its genuinely-ASCII content rejoins the `ASCII` subject domain, and its value-attachment role is replaced by the family-Codable twins `ASCII.Serializable` + `ASCII.Parseable`.

## Execution log (W0–W1) — landed & refined

**W0 ✅ pushed** — `ASCII.Serializable` marker (write peer of `ASCII.Parseable`) + `Binary.Serializable` bridge + `.serialized`/`append(serialized:)` + RawRepresentable-backed default serializer `ASCII.RawRepresentable.Serializer` (swift-ascii-serializer-primitives `ff27979`+`6bf9a6c`). Deferred → W3: a RawRep type *also* declaring `: Binary.Serializable` hits a witness ambiguity vs binary-serializer's pre-existing RawRep defaults — a family-Codable convention call settled when conformers need it.

**W1 ✅ pushed — refined from §OQ1 by recon.** §OQ1 planned "move the byte-generic facade to binary-parser." Recon showed the `Binary.ASCII.Parsing/Access/Machine` facade is dead (zero consumers) AND redundant with canonical `Binary.Parse.Access.{prefix,whole}` / `Binary.withInput` / `Binary.Machine`, so it was **DELETED, not moved** (swift-ascii `81b5299`). `Binary.ASCII.Equals` **DELETED** (`74d75b3`, redundant w/ `ISO_9899.String.Comparison.equals`); `Binary.ASCII.Base62` **DELETED** (`d462499`, redundant w/ binary-base's complete `Binary.Base.62` codec — the "preserve" premise was recon-falsified). The Decimal-machine was the one genuinely-unique capability → **MOVED** to swift-ascii-parser-primitives as **`ASCII.Decimal.Machine`** (`f920455`/`bbf5078`). `Binary.ASCII` is **fully dissolved at L3** (`rg → 0`); its namespace enum + the deprecated `Serializable/RawRepresentable/Wrapper` family remain in swift-ascii-serializer-primitives → **W4**.

### Finding — parser × machine is the owned/borrowed input duality (not stack-safety)

`Binary.Machine.swift:11-35`: the Machine exists primarily because a `~Escapable` borrowed cursor/`Span` **cannot be captured in an escaping closure**, so closure-based combinators are structurally impossible over borrowed input — Reynolds defunctionalization to an `Instruction` IR is the fix; stack-safety on recursive grammars is a co-benefit, not the driver. Two execution **worlds**: **owned** (Escapable `Byte.Input`, closure-leaf `Parser.Protocol`) and **borrowed** (`~Escapable` `Cursor`/`Span`, defunctionalized `Binary.Machine`). ASCII is **grammar** specialized over either world, never a separate machine; `ASCII.Decimal.Parser` (owned) and `ASCII.Decimal.Machine` (borrowed) are today the same grammar written twice — the duplication a unification collapses.

### Tracked follow-ups (design/ratification-gated; NOT executed)

1. **Owned/borrowed parser unification** — Tier-2/3 design: one grammar authored once → lowered to both backends (owned-closure + borrowed-IR); ASCII-as-grammar; the `Binary.Machine` engine is byte-level (the `Binary.*` home/name is questionable). To be written up as a research doc reconciled with the two-world-traversal corpus and **ratified before any execution**.
2. **Flag 1 — `ASCII.Decimal.Machine` dep-weight**: co-located in the `ASCII Decimal Parser Primitives` target, it pulls binary-parser's closure onto owned-world `ASCII.Decimal.Parser` consumers; resolve via a target-split (dedicated `ASCII Decimal Machine Primitives`) within the unification design.
3. **Flag 2 — swift-ascii unused-dep cleanup** ([MOD-025]/[PKG-DEP-003]): the W1 deletions left unused `Binary Parser`/`Binary Base` products + the now-obviated binary-parser transitive-collision-override cluster (`Package.swift:33-54`); a dedicated [MOD-025] pass (transitive-closure analysis + clean-build). Harmless meanwhile (resolved-but-unused; builds green).

## Context

Phase A landed and is green (`swift-ascii-serializer-primitives@8b81428` retired the `Binary.ASCII` value-struct to a caseless enum; `swift-ascii@80562e7` deleted the dead 834-line `UInt8+INCITS_4_1986` twin; `swift build` of swift-ascii exits 0; all five ASCII/byte repos clean at `origin/main`). The directive is to reassess from first principles with **everything in scope** — the prior research's "deferred / Strategy-(c) / relocate-to-L1" verdicts are superseded.

The reassessment produced three corrections to the originating handoff's framing, each evidence-backed:

1. **`Binary.ASCII.Equals` is byte equality, not ASCII content.** `Equals.swift:23` is `equals.nulTerminated(pointer, "apfs")` — a byte-buffer compare with zero ASCII semantics. The handoff grouped it with Base62/Decimal as "ASCII"; it is not.
2. **OQ2's serialize half is already canonical.** The deprecated `protocol Binary.ASCII.Serializable: Binary.Serializable` (`Binary.ASCII.Serializable.swift:17`) already refines the canonical protocol and delegates serialize (`:40-49`). Only the **whole-buffer decode** `init(ascii:in:) throws(Error)` (`:31-34`) is non-canonical.
3. **The prior DEFER verdicts were cost-gated, never architectural.** `ascii-migration-category-b.md` chose relocation because the split is "≈300+ file changes… an order of magnitude more work" — while its own analysis favored the split. With the cost gate lifted, the split is the correct evergreen end-state.

## The two governing constraints (first-class)

These are not footnotes. They are the load-bearing structural facts that determine where code may move and how the deprecated family may be deleted. Both were established empirically and confirmed independently by the principal.

### C1 — `swift-binary-parser-primitives → swift-byte-parser-primitives` is a one-way edge; the reverse is a [MOD-032] cycle

`swift-binary-parser-primitives` **depends on** `swift-byte-parser-primitives` (`Package.swift:63` `.package(url:…/swift-byte-parser-primitives)`; product deps at `:104, :114, :128` — `"Byte Parser Primitives"`). The reverse edge does not exist: `swift-byte-parser-primitives`'s deps (`Package.swift:25,32–45`) are parser/byte/either/input/array/column/shared/buffer-linear/storage/memory/cursor/index/collection/span — **no binary-parser** — and the ecosystem builds green, proving the edge is one-way. `Binary.Machine.Parser` / `Binary.Machine.Fault` are declared in swift-binary-parser-primitives (`Sources/Binary Machine Primitives/`).

**Consequence**: any code that binds `Binary.Machine` (or `Binary.withInput`) MUST NOT be routed into swift-byte-parser-primitives — that would add `byte-parser → binary-parser`, closing a package-level cycle, which **[MOD-032]** forbids and SwiftPM rejects outright (not a tier smell — a hard build failure). Byte-parser may host *only* `Binary.Machine`-free code. `[Verified: 2026-06-29]`.

### C2 — the `@_exported` umbrella re-export makes a Sources namespace-grep necessary but **not sufficient** for deletion

The umbrella re-exports the deprecated family: `ASCII Serializer Primitives/exports.swift:5` = `@_exported public import Binary_ASCII_Serializable_Primitives`. Every consumer that `import`s `ASCII_Serializer_Primitives` therefore sees the deprecated **convenience surface** transitively and uses it **without naming `Binary.ASCII`**. An `rg "Binary\.ASCII\."` Sources grep catches the conformances and explicit references but misses these call sites entirely.

Empirically, ~40 such hidden call sites exist (`String(ascii:)` / `buffer.append(ascii:)` / `.ascii.bytes`): swift-whatwg-url (5), rfc-2822 (3), rfc-5321 (2), rfc-4291 (2 src + 13 tests), rfc-3986/4007/2387/2369 (1 each), swift-ascii (7) — and, critically, **swift-string-primitives (1)** and **swift-loader-primitives (1)**, which *call but do not conform* and so are absent from the 120-conformer set. `[Verified: 2026-06-29]`. **[CORRECTED v1.3.0 — precise decontaminated enumeration]**: the precise count is **59 deprecated-surface call sites** (swift-ietf 34, swift-whatwg 12, swift-ascii tests 13), all confined to the conformer packages + swift-ascii tests. **swift-string-primitives and swift-loader-primitives are FALSE POSITIVES** — both call swift-string-primitives' own `String(ascii: StaticString)` (`String.swift:133`), with zero dependency on the ascii-serializer. `swift-email-standard`'s `String(ascii: message.body)` resolves to the INCITS `[Byte]→String?` init (excluded). See § "W3 Execution Decisions" → C2.

**Consequence**: (i) the migration surface (Wave 3) is 120 conformances **+ ~40 convenience call sites** across the union of conformer and call-site packages; (ii) deletion (Wave 4) is gated by a three-part pre-flight — namespace grep + convenience-surface grep + a **clean ecosystem `swift build` with the target already removed**, the last being the only sufficient proof, per **[HANDOFF-013b]**.

## The four open questions

### OQ1 — `Binary.ASCII.*` L3 split

The `Binary.ASCII.*` subsystem (20 files in `swift-ascii/Sources/ASCII/`) is mislabeled: it carries essentially no ASCII content (`isDigit`/`ASCII.Code`/Base62 appear in only 2 files). It is a **byte-input parser-execution facade over `Binary.withInput` / `Binary.Machine`**, plus two genuinely-ASCII files and a dead byte-equality helper. Routing by *substrate*, governed by C1:

| File(s) | Substrate (evidence, `[Verified: 2026-06-29]`) | Home |
|---|---|---|
| `Parsing.Machine(+call)`, `Machine.Access(.Prefix/.Whole)`, `Machine.Parser+ascii`, `Parsing.Error`, `Parsing.Prefix(+call)`, `Parsing.Whole(+call)`, `Access(+prefix/+whole)`, `Parsing.Parser+ascii`, `Parsing` | byte-input parser execution over `Binary_Parser_Primitives.Binary.withInput` (`Prefix+call.swift:13`, `Whole+call.swift:13`); accessor surface routes through the Machine path (coupling trace below) | **swift-binary-parser-primitives** — renamed subject-first `Byte.Parser.{Whole,Prefix,Access}` (+ `Binary.Machine.*` for the pure-Machine execution), declared there as the only package where both `Byte.Parser` and `Binary.withInput` resolve |
| `Parsing.Machine.Decimal` | ASCII decimal digits (`0x30..0x39`) **+** `Binary.Machine` (BinMachine=5) | **swift-ascii-parser-primitives** (with `ASCII.Decimal.Parser`; verify its `→ binary-parser` edge exists at execution time) |
| `Base62` | pure ASCII alphabet (`Binary_Base_Primitives` only; no Machine, no Byte.Input) | **swift-ascii-primitives** (`ASCII.Base62`) |
| `Equals`, `Equals+nulTerminated` | byte-buffer compare; **zero consumers** (see OQ-adjacent (i)) | **delete** |
| `Parsing` (namespace enum) | empty | dissolves with `Binary.ASCII` |

**The coupling trace (settles whether byte-parser gains a clean surface).** The `Access` accessor family does *not* stay `Binary.Machine`-free: `parser.ascii` → `Binary.ASCII.Access<Self>` (`Parsing.Parser+ascii.swift:17`); `Access.prefix`/`.whole` → `Binary.ASCII.Parsing.Prefix/Whole(parser).call(…)` (`Access+prefix.swift:9,17,24`; `Access+whole.swift:9,17,24`); `Prefix/Whole.call` → `Binary_Parser_Primitives.Binary.withInput{…}` (`Prefix+call.swift:13`; `Whole+call.swift:13`); and `Access.whole` throws `Either<P.Failure, Binary.ASCII.Parsing.Error>` where `Parsing.Error` is itself binary-parser-bound. The base `Access` type holds only a `parser`; its *entire* surface is `.prefix`/`.whole`. **Therefore byte-parser gains nothing** — the whole `Parsing.* + Access` subsystem collapses cleanly into binary-parser, with no accessor surface split across packages. This is the desired outcome: one coherent home, zero fragmentation.

**Verdict**: the byte-generic machinery is real but is **binary-parser substrate**, not byte-parser. The `Binary.ASCII` namespace was a misnomer for byte/binary-Machine parsing ergonomics. Subject-first naming (`Byte.Parser.*`, [API-NAME-001b]) applies to the *names*; C1 fixes the *package* to binary-parser.

### OQ2 — migration target for the deprecated family

**Verdict**: complete the **family-Codable split-pair** at L1 — land `ASCII.Serializable` (write marker), keep `ASCII.Parseable` (read marker, already landed flat), migrate each conformer to the twins; **reject** a unified `Coder`.

Scope (`[Verified: 2026-06-29]`): 120 production conformance sites across 22 packages — rfc-2822=24, rfc-3986=14, rfc-5322=11, rfc-2046=9, rfc-2045/9557/whatwg-url=6, … rfc-791/4007/2387=1. (Two further references in swift-parser-primitives `Parser.swift:53` and a swift-institute-linter-rules byte-rule are doc-comments, not conformances.)

Grounding:
- The canonical family is already built and Byte-typed: `Binary.Serializable` (`Binary.Serializable.swift:42`), `Binary.Parseable` (`Binary.Parseable.swift:61`), `ASCII.Parseable` flat marker (`ASCII.Parseable.swift:32`). The **only missing half is `ASCII.Serializable`** — named in `ASCII.Parseable.swift:24-31` as the planned write peer ("per Φ.1 of the ASCII codable unification plan").
- **[FAM-009]** (`2026-05-15-family-codable-convention.md:684`): siblings are namespace-rooted; ASCII is L1 + byte-substrate → the twins correctly live at L1 (no [PRIM-FOUND-004] friction; both directions are `[Byte]`/`[ASCII.Code]`, never `Swift.String`).
- Serialize and parse are **deliberately decoupled** in the canonical layer ("Serializer has no dual"); the conformer bodies confirm the asymmetry (`RFC_3986.URI.Scheme` serialize = `append(rawValue.utf8)`; decode = multi-line RFC-3986 §3.1 validation).
- **Coder rejected**: `Binary.Coder` (`Coder.Protocol`, Byte.Input/[Byte]) imposes round-trip *symmetry* this asymmetric text domain lacks, and its separate DecodeInput/EncodeBuffer is over-engineered when both sides are bytes. Conformers are value-attachments (conform to passive `-able` markers), not witness-holders. The prior research's preference for Coder-over-`ParserPrinter` does not transfer to split-vs-Coder.

Per-conformer shape (family-Codable [FAM-001/006/008]): `: Serializable` (canonical, `static var serializer`) + `: ASCII.Serializable` (marker) ∥ `: Parseable` (canonical, `static var parser`, carrying the per-type `Error`) + `: ASCII.Parseable` (marker); `Binary.Serializable`/`Binary.Parseable` derived via the family bridge; `Swift.RawRepresentable` re-derived. Convenience defaults (RawRepresentable-backed) keep trivial conformers ~3 lines; bespoke `ASCII.<T>.{Parser,Serializer}` witnesses only where validation is non-trivial.

### OQ3 — L1 gerund-namespace cleanup

**Verdict**: dissolve `ASCII.Parsing {}` (`ASCII.Parsing.swift:17`) and `ASCII.Serialization {}` (`ASCII.Serialization.swift:23`). Both are `enum` namespaces of pure stateless digit↔value functions — gerund namespaces are categorically forbidden ([PKG-NAME-001]; gerund is only a typealias onto `.Protocol`, [PKG-NAME-002]). They are not machines (the machines `ASCII.Parser`/`ASCII.Serializer`/`ASCII.<Format>.{Parser,Serializer}` already exist correctly).

Destination — the **existing digit subject-domain** (no new namespace): `ASCII.Decimal` (`ASCII.Decimal.swift:15`) and `ASCII.Hexadecimal` (`ASCII.Hexadecimal.swift:15`) are already correct subject namespaces. The parse-direction accessors already live on `ASCII.Code` (`.digitValue`/`.hexValue`, `ASCII.Code+Parsing.swift:16,33`, currently delegating to `ASCII.Parsing.digit`); inline that logic and add the serialize-direction converters to `ASCII.Decimal`/`ASCII.Hexadecimal`, checking `ASCII.Serialization.serializeDecimal` for redundancy against the existing `ASCII.Decimal.Serializer`.

### OQ4 — the demonstration test suite

**Verdict**: delete with the protocol. `swift-ascii/Tests/ASCII Tests/UInt8.ASCII.Serializable Tests.swift`'s conformers (`Token:55`, `DelimitedMessage:87`, `CorrectEmailAddress:651`) are synthetic types whose only purpose is exercising `Binary.ASCII.Serializable`. The one behavior worth preserving is the **context-carrying decode** (`DelimitedMessage.Context{delimiter}`): if the family-Codable parser keeps a context-parameterized parser, re-demonstrate it once in swift-ascii-parser-primitives' tests; otherwise it dies with the protocol. **[CORRECTED v1.3.0]** the OQ4 premise that *all* conformers are Void-context is FALSE — **5 conformers are non-Void**: `WHATWG_URL.URL` (`ParsingContext{base:URL?}`), `WHATWG_URL.URL.Host` (`Context{isSpecial}`), `WHATWG_URL.URL.Path` (`Context{isOpaque}`), `RFC_2046.Multipart` (`Context{boundary,subtype}`), `RFC_2387.Related` (`Context{boundary}`). Their context handling is a DEFERRED gap — see § "W3 Execution Decisions" → OQ2.

### Adjacent sub-decisions

- **(i) `Binary.ASCII.Equals` → delete.** `rg "\.equals\.nulTerminated"` finds only the declaration and two doc-comment examples — **zero call sites**. Decided on capability, not consumer count ([ARCH-LAYER-006]): it is a thin NUL-terminated byte-compare likely redundant with `Span<Byte>` equality, and mislabeled under `Binary.ASCII`. Delete (git-recoverable, verified-dead, [ARCH-LAYER-009]); confirm redundancy with `Span<Byte>` equality in Wave 1 and re-home to swift-byte-primitives only if the capability proves novel.
- **(ii) Base62 → swift-ascii-primitives; Decimal-machine → swift-ascii-parser-primitives.** Base62 is pure (clean at tier-0). The Decimal *machine* is `Binary.Machine`-bound (BinMachine=5) and cannot sit at tier-0 ascii-primitives (same C1 inversion) — it joins `ASCII.Decimal.Parser` at the capability tier.
- **(iii) defaults + bespoke-where-non-trivial** — adopted.

## Evergreen end-state (namespace tree)

```
L1 swift-binary-parser-primitives   ← Binary.ASCII.Parsing.* + Access facade collapses here
       Byte.Parser.{Whole, Prefix, Access}   (subject-first ergonomics over Binary.withInput)
       Binary.Machine.*                       (the pure-Machine execution bits)
L1 swift-byte-parser-primitives     UNCHANGED — Byte.Input, Byte.Parser, Byte.Literal.Parser (gains nothing)
L1 swift-ascii-primitives           ASCII.Base62 · ASCII.Decimal/.Hexadecimal digit converters (OQ3) · ASCII.Code.digitValue/.hexValue
L1 swift-ascii-parser-primitives    ASCII.Parseable (read marker) · ASCII.<T>.Parser · ASCII.Decimal.Machine
L1 swift-ascii-serializer-primitives ASCII.Serializable (NEW write marker) · ASCII.<T>.Serializer · .serialized: [Byte] convenience
                                     DELETE: "Binary ASCII Serializable Primitives" target
                                             (Serializable / RawRepresentable / Wrapper + the Binary.ASCII enum)
L2 swift-ietf/* · swift-whatwg      each conformer: Serializable + ASCII.Serializable  ∥  Parseable + ASCII.Parseable
                                     String call sites → String(decoding: x.serialized, as: UTF8.self)
L3 swift-ascii                      ASCII foundation, free of Binary.ASCII.*
DELETED                             Binary.ASCII.Equals (dead) · the Binary.ASCII namespace (no members remain)
```

## Execution waves (correctness-phased)

Commit-as-you-go per phase ([HANDOFF-019]); public-repo pushes only on explicit per-arc YES; deprecation warnings persist until Wave 4 and are expected. Waves 1/3/4 run as fresh Cleave sessions (context hygiene + seat/executor split).

| Wave | Scope | Gate |
|---|---|---|
| **0** | Land `ASCII.Serializable` flat marker ([FAM-001]) symmetric with `ASCII.Parseable`; the `Binary.Serializable` bridge; **and the replacement conveniences** — `.serialized: [Byte]` accessor + `append(serialized:)` at L1 (byte-substrate, [PRIM-FOUND-004]-clean), so Wave 3 lands against an existing target for both conformances and call sites | swift-ascii-serializer-primitives builds green |
| **1** | OQ1: substrate-routed split — `Binary.ASCII.Parsing.* + Access` facade → swift-binary-parser-primitives (`Byte.Parser.*` / `Binary.Machine.*`); Decimal-machine → swift-ascii-parser-primitives; Base62 → swift-ascii-primitives; Equals deleted (redundancy-confirmed); `Binary.ASCII.Parsing` namespace dissolved | each touched package builds green; **no new package edge violates C1** |
| **2** | OQ3: dissolve `ASCII.Parsing`/`ASCII.Serialization` into `ASCII.Decimal`/`.Hexadecimal`/`ASCII.Code` (parallelizable with W1) | swift-ascii-primitives + dependents green |
| **3** | OQ2: terminal consumer pass ([HANDOFF-017/034]) — the **union consumer set** (below) to the family-Codable twins + convenience call-site migration; multi-cohort ([HANDOFF-043]); protocol-API sweep ([HANDOFF-050]) | workspace grep clean + ecosystem `swift build` ([HANDOFF-035]) |
| **4** | OQ4 + **join**: delete demo tests; delete the deprecated target + product + umbrella `@_exported`; fix the `Parser.swift:53` doc-comment; confirm `Binary.ASCII` fully dissolved | three-part C2 pre-flight: namespace grep → 0 · convenience grep → 0 · **clean ecosystem build with the target removed** |

**Sequencing constraints**: Wave 0 unblocks Wave 3 (the twins must exist). Wave 1 must precede Wave 4 (the L3 `Binary.ASCII.*` machinery must leave the `Binary.ASCII` namespace before the enum is deleted). Wave 3 must precede Wave 4 (no conformers may remain).

## W2 execution record (2026-06-29)

**W2 (OQ3) complete — 12 repos pushed, all green, HEAD==origin verified on each.** L1 `swift-ascii-primitives` dissolved (`756a782`): the parse statics inlined into `ASCII.Code.{digitValue,hexValue}`; the serialize direction folded to `ASCII.Decimal.code(_:) -> ASCII.Code?`, `ASCII.Decimal.serialize(_:into:)` (un/signed, `Buffer.Element == Byte`), and `ASCII.Hexadecimal.code(_ value:, `case`: ASCII.Case = .upper)`. Consumers migrated: swift-rfc-4122 (`c3eea53`), -6238 (`942216f`), swift-iec-61966 (`904a156`), swift-json (`f638e2c`), swift-rfc-4648 (`ba6398d`), -3986 (`be5dd92`), swift-whatwg-url (`6868553`), swift-version-primitives (`e21786f`), swift-iso-32000 (`0510ecb`), **swift-incits-4-1986** (`c16a8bb`, L2 re-export), **swift-ascii** (`a5d0dcd`, L3 — 501 tests pass).

**Inventory correction — three lessons that carry to W3's larger conformer sweep:**
1. **Loose grep, all org-dirs.** A method-call-anchored grep (`ASCII.Serialization.`) under-counted twice: it missed swift-iec-61966 (one hex call, in an org-dir not initially scoped) and swift-incits-4-1986 (a `typealias` re-export — a *type* reference with no call token). Use `ASCII.(Parsing|Serialization)` (word-boundary, no trailing dot) across **all** per-authority org-dirs (swift-ietf/iso/iec/whatwg/incits/…), not just primitives/standards/foundations. W3 must expect type-reference re-exporters (typealias/extension), not only conformers/callers.
2. **Transitive-pin cascade.** A high-layer consumer (iso-32000) builds its *dependencies'* checkouts too; updating only the directly-named pins left a stale pre-migration `swift-rfc-4648`. A full `swift package update` was required to pull all already-migrated transitive deps.
3. **INCITS shape (principal decision, option A).** The L2 spec package mirrors the dissolution: `INCITS_4_1986.Numeric.{Decimal,Hexadecimal}` subject-domain aliases replace the gerund `Numeric.{Serialization,Parsing}` aliases; parse moves to `ASCII.Code` accessors; its downstream (swift-ascii `Int+Serializable`) follows. The same gerund-alias question will recur for any other spec package that re-exported `Binary.ASCII.*`.

## W3 Execution Decisions (v1.3.0, 2026-06-29 — principal-ratified)

Empirical recon (compile-probed in scratch SwiftPM packages against the real primitives, then adversarially re-built from scratch) resolved the four W3/W4 open questions. Live state at decision time: **26 packages / 87 files / 49 RawRep-variant / 1 Wrapper / 0 `Binary.ASCII.Parseable` refs** (no drift from the handoff).

### OQ1 — witness ambiguity: RESOLVED → per-conformer canonical witness
The ambiguity MANIFESTS (independently reproduced from scratch, deprecated product excluded). A `[Byte]`-RawRepresentable type declaring `Serializable + ASCII.Serializable + Binary.Serializable` with **no per-conformer serialize witness** fails to compile: `Binary.Serializable.serialize(_:into:)` has two **constraint-incomparable** defaults — binary-serializer's `where Self: RawRepresentable, RawValue == [Byte]` (`Binary.Serializable.swift:208-218`) and the W0 ASCII bridge `where Self: Serializable, ASCII.Serializable, …` (`Binary.Serializable+ASCII.swift:19-36`). Neither subsumes the other → `does-not-conform` at the decl + `ambiguous use of serialize` at the call. The W0 `ASCII.RawRepresentable` twin resolves **only** the *separate* `serializer` requirement (its `serializer` default is a strict superset and out-specializes binary's), **not** `serialize`.
- **RawValue-generality**: the collision is NOT `[Byte]`-exclusive. binary-serializer ships **4** incomparable RawValue-keyed serialize defaults — `StringProtocol:199`, `[Byte]:212`, `[UInt8]:224`, `FixedWidthInteger:269` — each incomparable with the bridge; a String-RawValue conformer fails identically. The dominant RFC conformer shape is in fact `RawValue == String` and already hand-writes serialize.
- **DECISION**: each conformer declares the canonical `static func serialize<Buffer>(_:into:) where Buffer.Element == Byte` directly, **retargeting its existing hand-written `serialize(ascii:into:)` witness** (drop the `ascii` arg label, keep the body) as part of the conformance swap. A conformer-declared member out-ranks all protocol defaults → silences the ambiguity uniformly across all RawValue kinds. Verified build-clean as an extension on the real type; **no `serializer` rider needed** (twin supplies it).
- **W0 bridge LEFT UNTOUCHED** (`Binary.Serializable+ASCII.swift`) — do NOT narrow or delete it in W3 (out of scope); the concrete witness out-ranks it. If the bridge looks fully dead post-migration, record a **post-W3 cleanup NOTE only** — do not act in W3.
- **Per-package proof**: a green build after the retarget IS the proof the ambiguity resolved.

### OQ2 — non-Void context (5 conformers): DEFERRED (honest gap)
W0's OQ4 "all conformers Void-context" was FALSE. Non-Void (parse-side context) set:

| Conformer | Context | Parse witness |
|---|---|---|
| `WHATWG_URL.URL` | `ParsingContext{ base: URL? }` | `WHATWG_URL.URL+Serializable.swift:168` |
| `WHATWG_URL.URL.Host` | `Context{ isSpecial }` | `WHATWG_URL.URL.Host.swift:109` |
| `WHATWG_URL.URL.Path` | `Context{ isOpaque }` | `WHATWG_URL.URL.Path.swift:60` |
| `RFC_2046.Multipart` | `Context{ boundary, subtype }` | `RFC_2046.Multipart.swift:330` |
| `RFC_2387.Related` | `Context{ boundary }` | `RFC_2387.Related.swift:321` |

Neither twin carries a context slot (`ASCII.Parseable` = flat marker `ASCII.Parseable.swift:32`; `Binary.Parseable.parse(from:)` no context, `Binary.Parseable.swift:61-76`).
- **W3 mechanics (UNCHANGED)**: conform the write twins (`Binary.Serializable + ASCII.Serializable`); **keep a plain concrete `init(ascii:in:)` reader** on each of the 5 types (non-protocol API). Keep the 5 concrete readers **uniformly shaped** so a future retrofit is a *declaration change, not a rewrite*.
- **DEFERRED context shape (principal correction — NOT a separate `ContextualParseable` sibling)**: when built, add `associatedtype Context = Void` to the **existing** `Parseable` / `ASCII.Parseable` (context opt-in; Void-default conformers unaffected). This is the deprecated protocol's already-proven shape.
- **Trigger to build it**: first need to parse the 5 generically, or a decision to make them first-class.
- **Open check at that time**: any `any Parseable` / `any ASCII.Parseable` existential usage, + how `Context` threads through `parse(from:)` and the `Binary.Parseable` parent.

### OQ3 — linter-rule: RESOLVED → fold into W4
`Lint.Rule.Byte.BinarySerializableUInt8Witness.swift:16` references `Binary.ASCII` only in a doc-comment (imports only `Linter_Primitives` + `SwiftSyntax`; detection table `:54-57` excludes `Binary.ASCII`; cannot fire). Deleting the namespace in W4 breaks nothing. **DECISION**: drop the stale parenthetical in the **W4 deletion commit**; rule [API-BYTE-003] stays load-bearing. Same for `swift-parser-primitives/Sources/Parser Primitive/Parser.swift:53` (lone doc comment).

### C2 surface — 59 sites (decontaminated)
Precise count **59** (swift-ietf 34, swift-whatwg 12, swift-ascii tests 13; handoff's "~40" undercounted the test-side `.ascii.bytes` blast — rfc-4291 ×13, swift-ascii ×12), none naming `Binary.ASCII` (umbrella `@_exported` re-export). Three distinct `String(ascii:)` inits share the spelling — only the `String(ascii: <Serializable>)` form is the deprecated surface; the INCITS `[Byte]→String?` and swift-string-primitives' `String(ascii: StaticString)` forms are excluded. Corrections: **swift-string-primitives + swift-loader-primitives DROPPED** (false positives); `swift-email-standard`'s `String(ascii: message.body)` is the INCITS init (excluded); `.serialized` is the KEPT `Binary.Serializable` property (different symbol). **NO typealias re-exporters exist** — INCITS-precedent shape absent across all 24 (`specReExporters = ∅`).

### Cohort plan
Conformer shape is dominantly **mixed** (hand-written byte witness + `RawRepresentable` marker, mostly `RawValue == String`). Upstream-first; **`rfc-5322` is the deep hub (8 conformers; 5 downstream packages depend on it) → land early**. `swift-ascii` (L3) is a **reference-only tail** (doc comments; already migrated off in a prior W4 note) — verification canary, not migration work. Topological order: defining `swift-ascii-serializer-primitives` → leaves (`rfc-1035, 3339, 3987, 3986, 791, 4291, 4007, 7617, 7519, 2822`) → `rfc-1123, 9557, 2369, whatwg-url` → `rfc-5321, 5322, 6068, 6531` → email/MIME chain (`rfc-2045, 2183, 2046, 2387`) → reference-only tail (`swift-ascii`, `swift-parser-primitives`, `swift-institute-linter-rules`).

## Consumer set (union)

Wave 3 migrates the **union** of:
- **22 conformer packages** (`: Binary.ASCII.Serializable`/`RawRepresentable`): swift-ietf/{rfc-2822, rfc-3986, rfc-5322, rfc-2046, rfc-2045, rfc-9557, rfc-7617, rfc-6531, rfc-6068, rfc-5321, rfc-3339, rfc-2369, rfc-1123, rfc-1035, rfc-2183, rfc-7519, rfc-4291, rfc-3987, rfc-791, rfc-4007, rfc-2387} + swift-whatwg/swift-whatwg-url.
- **the convenience-call-site packages** (C2): the above (most also call). **[CORRECTED v1.3.0]** the net-new packages named in W0 (**swift-string-primitives**, **swift-loader-primitives**) are **false positives** — both call swift-string-primitives' own `String(ascii: StaticString)`, with no ascii-serializer dependency — and are NOT in the W3 set. The C2 surface is **59 call sites** confined to the conformer packages above + swift-ascii tests; **no typealias re-exporter exists** (the INCITS-precedent shape is absent across all 24 conformer packages).

## Outcome

**Status**: RECOMMENDATION; direction principal-ratified 2026-06-29. The plan completes the ASCII codable unification (lands `ASCII.Serializable`, Φ.1) and dissolves the `Binary.ASCII` namespace. Two corrections from post-ratification pressure-testing are folded as first-class constraints (C1, C2).

**Next steps**: (1) await per-wave green-light; (2) Wave 0 (land `ASCII.Serializable` + conveniences); (3) Waves 1–4 as above. Execution does not begin until the principal green-lights Wave 0.

## References

- `operation-domain-naming-and-organization.md` v1.1.2 — agent-noun namespace / gerund-as-alias / subject-first ([PKG-NAME-001/002], [API-NAME-001b])
- `2026-05-15-family-codable-convention.md` — [FAM-001..009], namespace-rooted placement + substrate-friction exception
- `ascii-serialization-migration.md`, `ascii-migration-category-b.md` — prior analysis (DEFER verdicts superseded; the 12-feature decomposition and the cost figures retained)
- Skills: **modularization** [MOD-032] (no package cycles), [MOD-DOMAIN]; **byte-discipline** [API-BYTE-004]; **swift-package** [PKG-NAME-*]; **code-surface** [API-NAME-001b]; **handoff** [HANDOFF-013b/017/034/035/043/050]; **swift-institute** [ARCH-LAYER-006/009]; **primitives** [PRIM-FOUND-004]
- Empirical anchors (`[Verified: 2026-06-29]`): `swift-binary-parser-primitives/Package.swift:63,104,114,128`; `swift-byte-parser-primitives/Package.swift:25,32–45`; `ASCII Serializer Primitives/exports.swift:5`; `Binary.ASCII.Serializable.swift:17,31-34,40-49`; `Access+prefix.swift:9`; `Whole+call.swift:13`; `ASCII.Parseable.swift:24-32`; `Binary.Serializable.swift:42`; `Binary.Parseable.swift:61`
