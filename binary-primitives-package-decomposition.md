# Binary Primitives Package Decomposition

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

`swift-binary-primitives` (private; HEAD `55b6217` at write time) ships seven library products: `Binary Namespace` (anchor), `Binary Primitives Core` (~30 files; Span/Cursor/~Escapable substrate, the `Binary.Serializable` protocol's foundations layer, Tagged conformances), `Binary Cursor Primitives`, `Binary LEB128 Primitives`, `Binary Format Primitives`, `Binary Serializable Primitives`, and the umbrella `Binary Primitives`. Earlier today (2026-05-07) the user authored `swift-primitives/swift-binary-base-primitives` as a sibling L1 package using the precedent established in [`binary-base-n-encoding-family-architecture.md`](binary-base-n-encoding-family-architecture.md): a closed-radix family extracted into its own L1 package, depending only on `Binary Namespace` + `swift-property-primitives`.

The user proposes a continuation of that refactor: split additional sub-products of `swift-binary-primitives` into their own L1 packages, and reshape some of them as part of the split. The candidate slate, as stated in `swift-binary-primitives/HANDOFF.md`:

| Current sub-product | Proposed package | Reshape signal |
|---------------------|-------------------|----------------|
| `Binary LEB128 Primitives` | `swift-binary-leb128-primitives` | none — split only |
| `Binary Format Primitives` | `swift-binary-formatter-primitives` | rename: format → formatter |
| `Binary Serializable Primitives` | `swift-binary-serializer-primitives` | protocol → witness shape |
| (new) | `swift-binary-coder-primitives` | new — symmetric encode+decode pair |

The user explicitly requested that this analysis "argue both sides per angle" rather than advocate for splitting, AND requested research-first per [RES-011]: research before any package creation.

### Trigger

Continuation of the Phase 1 swift-binary-base-primitives precedent landed today. The user wants a coherent answer for the remaining sub-products before any further repo creation, and explicitly flagged that the protocol-to-witness shift signaled by `swift-binary-serializer-primitives` (vs `…-serializable-…`) is a deeper architectural question than the package boundary alone.

### Constraints

- [PRIM-FOUND-001] No Foundation in any L1 package.
- [MOD-DOMAIN] One semantic domain per package; targets created for code-organization reasons are forbidden.
- [MOD-RENT] Three-criteria primitive-package rent test: capability + consumer + theoretical content. Failing any is a bar to existence.
- [RES-018] Premature primitive anti-pattern: new primitives must demonstrate composition impossibility AND a second consumer.
- [RES-020a] Total-taxonomy carve-out does NOT apply here — these candidates are not lattice-completeness primitives; merit-via-adoption is the right framing.
- [API-NAME-001] Nest.Name; [API-NAME-008] Property.View vs labeled methods.
- [PKG-NAME-001] Noun form for packages and namespaces; [PKG-NAME-002] canonical capability protocol via `Namespace.\`Protocol\``.
- [feedback_no_public_or_tag_without_explicit_yes.md] — recommendations only; implementation requires per-action authorization.
- [feedback_no_layer_level_artifact_containers.md] — this doc lives at `swift-institute/Research/`, never `swift-primitives/Research/`.

### Stakeholders

`swift-binary-primitives` (subject), `swift-binary-parser-primitives` (parser-side mirror; depends on the LEB128 product today), `swift-binary-base-primitives` (today's precedent), `swift-format-primitives` (substrate of `Binary.Format`), `swift-serializer-primitives` (substrate of `Binary.Serializable`), `swift-coder-primitives` (canonical `Coder.\`Protocol\``). Downstream: nine consumers of `Binary.Serializable` across IETF RFCs, ISO 32000 PDF, swift-cpu-primitives, swift-x86-standard, swift-sockets, swift-file-system tests, rule-legal-nl PDF generation.

## Question

For each of {LEB128, Format/Formatter, Serializable/Serializer, Coder}, should it be:

1. **Split**, on the swift-binary-base-primitives precedent, into its own L1 package; AND
2. **Reshaped** in the move (Format → Formatter rename; Serializable protocol → Serializer witness; Coder as a new symmetric pair); OR
3. **Kept** as a sub-product of `swift-binary-primitives`?

Each candidate decomposes into:

- (a) Is the boundary semantically a separate domain, or a different aspect of the binary-data domain?
- (b) Does the proposed reshape (where applicable) reflect a real shape change vs cosmetic naming?
- (c) Does the second-consumer test pass for the candidate as proposed?
- (d) What does migration cost the existing consumer set?

## Internal Research Survey [per [RES-019]]

```bash
grep -rln -i "leb128\|binary.format\|formatter\|binary.serializable\|binary.serializer\|binary.coder" \
  /Users/coen/Developer/swift-institute/Research/ \
  /Users/coen/Developer/swift-primitives/swift-binary-primitives/Research/
```

[Verified: 2026-05-07] Prior art surfaced:

| Document | Relevance |
|---|---|
| [`binary-base-n-encoding-family-architecture.md`](binary-base-n-encoding-family-architecture.md) (RECOMMENDATION, 2026-05-07) | Today's split precedent. Establishes closed-radix `Binary.Base.\`N\`` + Property witness pattern. The relevant template for "L1 mechanism + L2 spec packages." |
| [`binary-base-n-rfc-4648-reconciliation.md`](binary-base-n-rfc-4648-reconciliation.md) (RECOMMENDATION, 2026-05-07) | Today's "standards delegate to primitives" finding (BLOG-IDEA-085). Codifies the directional discipline applicable here. |
| [`canonical-witness-capability-attachment.md`](canonical-witness-capability-attachment.md) (DECISION v1.2.0, 2026-03-04) | Establishes the institute's canonical `Parseable`/`Serializable`/`Codable` + Pattern 2 (domain-owned witness types). Resolves what "Serializable → Serializer" should mean architecturally. 10/10 experiment variants CONFIRMED. |
| [`ascii-serialization-migration.md`](ascii-serialization-migration.md) (DECISION, 2026-03-25; DEFERRED post-release) | The exact ASCII analog of the proposed Binary migration — 77 conformers across 15 packages, separate Parser + Serializer types per type, 8-phase rollout, deprecate the domain protocol. Direct precedent for the Binary case. |
| [`parsing-serialization-capability-organization.md`](parsing-serialization-capability-organization.md) (SUPERSEDED) | Original three-strategy analysis. Identifies `Binary.Coder<Output>` as already existing in `swift-binary-parser-primitives`, not a new construct. |
| [`transformation-domain-architecture.md`](transformation-domain-architecture.md) (DECISION) | The umbrella decision on three independent capability packages (parser-primitives, serializer-primitives, coder-primitives). |
| [`algebra-primitives-package-split.md`](algebra-primitives-package-split.md) (RECOMMENDATION, 2026-02-04) | Prior package-split precedent. Establishes the cost model (10 packages vs 1) and the tier-inversion-as-trigger criterion. |
| [`swift-binary-primitives/Research/binary-primitives-rawvalue-underlying-rename.md`](../../swift-primitives/swift-binary-primitives/Research/binary-primitives-rawvalue-underlying-rename.md) (2026-05-03) | This week's status note: "The package is already modularised into Core / Cursor / LEB128 / Format / Serializable variants plus a Namespace target. No drift from the L1 vocabulary mission." This is the do-not-split position's strongest internal anchor. |
| [`swift-binary-primitives/Research/Comparative Analysis swift-binary-primitives.md`](../../swift-primitives/swift-binary-primitives/Research/Comparative%20Analysis%20swift-binary-primitives.md) | Establishes Core's identity: "binary data manipulation" — Span/Cursor/~Escapable/@unsafe escape hatches. Format/Serializable/LEB128 are arguably orthogonal to that core mission. |

## Empirical State Verification [per [RES-023]]

| Claim | Verification | Result |
|---|---|---|
| `swift-binary-primitives` HEAD = `55b6217` | `git -C swift-binary-primitives rev-parse HEAD` | [Verified: 2026-05-07] confirmed |
| Build clean from HEAD | `cd swift-binary-primitives && swift build` | [Verified: 2026-05-07] `Build complete! (17.12s)` |
| `Binary.Coder<Output>` already exists | `ls swift-binary-parser-primitives/Sources/Binary\ Coder\ Primitives/` | [Verified: 2026-05-07] `Binary.Coder.swift`, `Binary.Coder+Coder.Protocol.swift`, `exports.swift`. Plain witness struct conforming to `Coder.\`Protocol\``. Output-generic. **Not a new construct.** |
| `Binary LEB128 Primitives` is the serialization half; parser half lives elsewhere | Read `Binary.LEB128.swift` doc comment + `swift-binary-parser-primitives/Sources/Binary\ LEB128\ Parser\ Primitives/` | [Verified: 2026-05-07] explicit: "Serialization (this module)" vs "Parsing (requires Binary Parsing Primitives)." The Parser/Serializer split is intentional and symmetric. |
| `Binary LEB128 Primitives` is consumed by an external package today | Grep `swift-binary-parser-primitives/Package.swift` | [Verified: 2026-05-07] yes — `Binary LEB128 Parser Primitives` declares `.product(name: "Binary LEB128 Primitives", package: "swift-binary-primitives")` as a dep. **Second-consumer test [RES-018] passes for LEB128.** |
| `Binary.Serializable` consumer surface | `grep -rln "Binary\.Serializable\|Binary_Serializable_Primitives" --include="*.swift" --include="Package.swift"` | [Verified: 2026-05-07] 9+ external consumers: `swift-iso-32000` (4 files), `swift-rfc-8446`, `swift-rfc-6455` (via Binary.Format), `swift-cpu-primitives` (3 files), `swift-x86-standard` (6 files), `swift-sockets`, `swift-file-system` tests (10 files), `rule-legal-nl`, `swift-pdf-standard` Test Support, `swift-base62-primitives` (deprecated parallel). Migration-impactful surface. |
| `Binary.Format` consumer surface | Grep | [Verified: 2026-05-07] 2 external consumers: `swift-rfc-8446`, `swift-rfc-6455`. Low surface. |
| `Binary.LEB128` consumer surface (beyond the parser-primitives sibling) | Grep | [Verified: 2026-05-07] zero external direct consumers; all consumption is via `swift-binary-parser-primitives`. |
| `swift-format-primitives` exists with `Format.\*` namespace | `ls swift-primitives/swift-format-primitives/Sources/` | [Verified: 2026-05-07] yes — `Format.swift`, `Format.Decimal.swift`, `Format.Numeric.\*.swift`, `Format.Case.\*.swift`, `FormatStyle.swift`. Binary.Format depends on it. |
| `swift-serializer-primitives` exists with canonical `Serializable` | `ls swift-primitives/swift-serializer-primitives/Sources/` | [Verified: 2026-05-07] yes — `Serialization Primitives`, `Serializer Namespace`, `Serializer Primitives`, `Serializer Primitives Core`. Binary.Serializable's package already depends on this. |
| `swift-coder-primitives` exists with canonical `Coder.\`Protocol\`` | `ls swift-primitives/swift-coder-primitives/Sources/` | [Verified: 2026-05-07] yes — `Coder Primitives`. `Binary.Coder` already conforms via `Binary.Coder+Coder.Protocol.swift`. |
| `swift-binary-base-primitives` precedent dependencies | Read its Package.swift | [Verified: 2026-05-07] depends on `swift-property-primitives` + `swift-binary-primitives` (only the `Binary Namespace` target). Single-product (`Binary Base Primitives`) + Test Support. The reusable structural template. |

## Prior Art Survey [per [RES-021]]

| System | Pattern for {LEB128, Format, Serializable, Coder} package shape |
|---|---|
| LLVM/Clang | LEB128 lives in `llvm/Support/LEB128.h` — a single header in the support library. Not a separate package. Used directly by DWARF (`llvm/DebugInfo/DWARF/...`), WebAssembly backend, Protobuf-style codegen. **One mechanism, multi-spec-consumer pattern.** |
| Rust `leb128` crate | Standalone crate ([`crates.io/crates/leb128`](https://crates.io/crates/leb128)). Used by `wasm-encoder`, `gimli` (DWARF), `protobuf`. **Confirms the multi-spec consumer pattern justifies an independent package.** |
| Rust `bytes` crate | A dedicated crate for byte buffer manipulation — analogous to swift-binary-primitives Core. **Pattern: byte-substrate has its own crate; encodings have their own.** |
| Apple Foundation | `Data.base64EncodedString(options:)` co-locates encoding with the byte type itself. No LEB128. Format styles (`IntegerFormatStyle`, `ByteCountFormatStyle`) are separate types in `FoundationEssentials`. **Pattern: format styles factored out.** |
| Swift Codable | `Encodable`/`Decodable` are stdlib protocols; concrete coders (`JSONEncoder`, `PropertyListEncoder`) are separate types in adjacent packages. **Pattern: protocol single-canonical + multiple concrete strategies.** |
| Rust serde | `Serialize`/`Deserialize` traits + per-format crates (`serde_json`, `serde_yaml`, `bincode`). **Pattern: protocol in core crate, format-specific implementations in their own crates.** |
| Haskell `binary` | `Binary` typeclass + `Put`/`Get` monads. One package; LEB128-style varint encoding lives in `binary` itself. **Pattern: one binary-substrate package, encodings as extensions.** |

[Contextualization step per [RES-021]]: The cross-system pattern "byte substrate is one package, named encoding families are separate packages" is real (LLVM, Rust). It is NOT universal — Haskell's `binary` and Swift's existing `swift-binary-primitives` co-locate encodings with the substrate. The decision is whether the institute prefers the "byte substrate + named encoding sibling packages" model (Rust-style) over the "one substrate package with all encodings" model (Haskell-style). The existing precedent of `swift-binary-base-primitives` (created today) signals the institute prefers the Rust-style decomposition.

## Premature Primitive Check [per [RES-018]]

For each candidate, the rule asks: (1) Why not compose existing primitives? (2) Is there a second consumer beyond the originating investigation?

| Candidate | (1) Compose existing? | (2) Second consumer? |
|---|---|---|
| LEB128 split | Cannot — Binary.LEB128.Serialize is the mechanism. The question is package boundary, not invention. | YES — `swift-binary-parser-primitives/Binary LEB128 Parser Primitives` already declares this product as a Package.swift dependency. Future DWARF/WASM/Protobuf L2 spec packages would each be a third+ consumer. |
| Format → Formatter | The mechanism (Format styles for byte counts and radix) is genuinely a thin layer over `swift-format-primitives`'s `Format` namespace. Composition is the existing shape. | Two known consumers (swift-rfc-8446, swift-rfc-6455). Borderline — passes the second-consumer hurdle but barely. |
| Serializable → Serializer | The institute already has the canonical `Serializable` protocol (in `swift-serializer-primitives`) AND domain-owned witness types (Pattern 2 from canonical-witness-capability-attachment.md DECISION). What's proposed isn't a new mechanism; it's a reshape of `Binary.Serializable` into a `Binary.Serializer<T>` witness. | YES — 9+ external consumers of `Binary.Serializable`. |
| Coder (new package) | **Cannot create — Binary.Coder ALREADY EXISTS** at `swift-binary-parser-primitives/Sources/Binary Coder Primitives/`. The handoff frames this as a new package; the empirical claim per [RES-023] is that it's an *extraction* candidate, not a new construct. | Existing consumers of `Binary.Coder` would need to be enumerated; this candidate, if reframed as extraction, requires its own second-consumer check separate from the Binary.Coder construct itself. |

## Per-Candidate Analysis

### Candidate 1: LEB128 — `swift-binary-leb128-primitives`

#### Both-sides arguments

**For split:**

1. **Today's precedent matches.** `swift-binary-base-primitives` was created today as L1 leaf for a named encoding family (RFC 4648 family). LEB128 is a named encoding family with three independent specifications: DWARF v5 §7.6, WebAssembly Core 1.0 §5.2.2, Protocol Buffers wire format. The same architectural argument that justified swift-binary-base-primitives (closed-mechanism + open authorities; mechanism is Foundation-free, deserves its own package) applies symmetrically to LEB128.
2. **Multi-spec authority pattern.** The L1 mechanism + L2 spec packages pattern (per `binary-base-n-rfc-4648-reconciliation.md`) maps cleanly: `swift-binary-leb128-primitives` provides the mechanism; future `swift-dwarf-leb128`, `swift-wasm-leb128`, `swift-protobuf-leb128` (or unified spec packages) consume it without dragging in the rest of `swift-binary-primitives`.
3. **Tier liberation.** The current `Binary LEB128 Primitives` target depends on `Binary Primitives Core` (which itself depends on bit/cardinal/carrier/dimension/index/memory/std-lib-extensions — seven primitives). The actual algorithmic content of LEB128 (sign-aware variable-length integer encoding) needs only stdlib `FixedWidthInteger`, byte arithmetic, and bit shifts. A standalone package could be a tier-0 leaf depending on `Binary Namespace` only, similar to swift-binary-base-primitives' tier shape.
4. **Rust precedent.** [`leb128` crate on crates.io](https://crates.io/crates/leb128) is standalone with consumers including `wasm-encoder`, `gimli` (DWARF), `prost` (protobuf). [Verified: 2026-05-07 via crates.io URL]. External ecosystem confirms the boundary.
5. **Second-consumer test passes [RES-018].** `swift-binary-parser-primitives/Binary LEB128 Parser Primitives` already declares `Binary LEB128 Primitives` as a Package.swift product dependency [Verified: 2026-05-07]. Plus the future DWARF/WASM/Protobuf L2 packages.
6. **Mission focus.** Per the package's Comparative Analysis, Core's identity is "binary data manipulation" — Span, Cursor, ~Escapable, @unsafe escape hatches. LEB128 is a specific encoding scheme orthogonal to that core mission.

**Against split:**

1. **Already well-modularized.** The 2026-05-03 rawvalue-underlying-rename research explicitly notes "the package is already modularised into Core / Cursor / LEB128 / Format / Serializable variants… No drift from the L1 vocabulary mission." This is a recent, in-package status assessment that argues the current sub-product organization is sufficient.
2. **No urgent external consumer.** Outside `swift-binary-parser-primitives`'s sibling consumption, there is no current external direct consumer of `Binary.LEB128` [Verified: 2026-05-07]. The future-DWARF/WASM/Protobuf consumers are speculative — neither package exists in the workspace today. [MOD-RENT] criterion (3) — theoretical content — passes; criterion (2) — current consumer — passes via swift-binary-parser-primitives but is single-consumer.
3. **Cost of N+1 packages.** Per `algebra-primitives-package-split.md`, going from 1 to N packages is non-trivial: each adds a Package.swift, README, CHANGELOG, CI runner config, dep entry per downstream package. Today's `swift-binary-primitives` umbrella consumers (e.g., `swift-binary-parser-primitives`) would need to update from `Binary Primitives` → `Binary Primitives` + `Binary LEB128 Primitives` (separately).
4. **Asymmetry-with-parser-side counterargument.** `swift-binary-parser-primitives` keeps `Binary LEB128 Parser Primitives` as a sub-product, not a standalone package. Symmetry argues for keeping the serializer side as a sub-product unless we also split the parser side (which is out of scope and would touch a much larger consumer set).
5. **No tier inversion.** The algebra-primitives split was driven by a hard tier inversion (`numeric-primitives` could not depend on the abstract algebraic hierarchy because the aggregate was too high). No equivalent tier inversion exists for LEB128 today — every consumer is at higher tiers than the LEB128 sub-product would be.

#### Decision criteria

| Criterion | Argues for | Argues against |
|---|---|---|
| Multi-spec authority | ✓ DWARF, WASM, Protobuf | speculative until L2 packages exist |
| swift-binary-base-primitives precedent | ✓ same shape | this week's "no drift" note |
| Tier liberation | ✓ tier-0 leaf possible | Binary Primitives Core dep currently |
| External ecosystem confirmation | ✓ Rust `leb128` crate | Haskell `binary` keeps it bundled |
| [RES-018] second-consumer | ✓ swift-binary-parser-primitives | only one current external consumer |
| [MOD-RENT] (1) capability | ✓ named, well-defined encoding | — |
| [MOD-RENT] (2) consumer | ✓ at least one | weak signal — single |
| [MOD-RENT] (3) theoretical content | ✓ formal encoding spec | — |
| Cost of new package | — | +1 Package.swift / README / CI / consumers update |

#### Verdict

**RECOMMENDATION: SPLIT, conditional on second-consumer confirmation.**

The architectural argument for splitting is structurally identical to the argument that produced swift-binary-base-primitives this week. The counter-argument is practical (cost) and timing (no L2 spec consumer in flight). The decisive consideration is that even today, one external sibling package consumes `Binary LEB128 Primitives` as a Package.swift dependency — the [RES-018] second-consumer hurdle is met (just barely). The institute pattern is to make L1 mechanism packages independently consumable so L2 spec packages can compose them; LEB128 fits the pattern.

**Caveat:** if the user prefers to defer until at least one L2 spec package is in flight, deferral is also valid — the cost asymmetry favors waiting for a second use case rather than authoring on speculation. The recommendation is split-when-ready; the trigger condition is "first L2 LEB128 spec package authored or planned, OR ecosystem-wide reduction of swift-binary-primitives umbrella surface."

### Candidate 2: Format → Formatter — `swift-binary-formatter-primitives`

#### Both-sides arguments

**For split-with-rename:**

1. **Existing dependency drag.** `Binary Format Primitives` already pulls in `swift-format-primitives`. Pulling in `swift-format-primitives` is the package's actual purpose, but it means the dependency arrow goes from `swift-binary-primitives` → `swift-format-primitives`. Splitting Binary.Format out lets a future consumer (e.g., a logging library) take Binary.Format without taking the rest of swift-binary-primitives.
2. **Naming alignment under [PKG-NAME-001].** Apple's Foundation introduced `Formatter`-style types (`IntegerFormatStyle`, `ByteCountFormatStyle`); Swift's evolution proposals talk about formatters. "Formatter" as a noun is the agent-noun reading of "format" — symmetric with Parser/parse, Serializer/serialize. The ecosystem has `swift-format-primitives` with namespace `Format`; a `Binary.Formatter` adopts the agent-noun for the operation specifically, distinct from the `Format` namespace for format-style values.
3. **Tier-lowering.** `Binary Format Primitives` is currently in the Core dependency closure of the umbrella. A consumer importing only `Binary Primitives` for Cursor/Span/Buffer pays the format-primitives compile cost. Split would let consumers pay only when they import the formatter package.
4. **Bigger philosophical question — "format" vs "formatter".** The current `Binary.Format` namespace contains *style values* (`Binary.Format.bytes`, `Binary.Format.hex`). These are formatted-output specifications, structurally similar to Foundation's `FormatStyle`. The renaming question is whether the package should ship style values (Formatter package contains `Binary.Format.hex` style) OR ship formatter operations as a witness shape (`Binary.Formatter<Input, Output>` struct). The former is cosmetic; the latter is a real shape change.

**Against split-with-rename:**

1. **Two consumers — borderline [RES-018].** Only `swift-rfc-8446` and `swift-rfc-6455` consume `Binary.Format` externally. The minimum hurdle is met but weakly.
2. **Small surface.** `Binary Format Primitives` is approximately 8 files, all thin layers over `swift-format-primitives`'s Format namespace. The package would be very small — possibly small enough that the [MOD-RENT] (3) "theoretical content" criterion fails (the binary-data-formatting concept is just composition of Format primitives with `[UInt8]`/`UInt` types).
3. **Rename signal ambiguity.** The handoff explicitly flags this. Is "Formatter" just an agent-noun rename of "Format"? Or is it a witness-shape shift, with `Binary.Formatter<UInt32>` being a witness struct distinct from `Binary.Format.hex` style? Without empirical experimentation (à la `binary-base-n-poc/`), the rename signal can mean either; landing it without resolving the question creates rework.
4. **Existing canonical path.** Formatting numeric values is what `swift-format-primitives`'s `Format.Decimal`, `Format.Numeric` already do. The "binary" specialization is byte counts and integer radix-views; both are arguably feature-additions to swift-format-primitives, not a separate package. The minimum-viable change is to absorb `Binary.Format` content into `swift-format-primitives` as an extension and delete the Binary.Format sub-product.
5. **Asymmetric naming pressure.** If `Binary.Format` becomes `Binary.Formatter`, downstream the question becomes: should `swift-format-primitives` be renamed to `swift-formatter-primitives`? The handoff explicitly calls this out as an open question. A rename cascade across two packages is a much larger change than a sub-product split.

#### Decision criteria

| Criterion | Argues for | Argues against |
|---|---|---|
| Dependency-drag relief | ✓ removes format-primitives from Binary core closure | Binary Primitives already depends on it via the Format sub-product; removing would also need to remove the umbrella re-export |
| Second-consumer | ✓ 2 (rfc-8446, rfc-6455) | weak signal; both via small surfaces |
| Rename clarifies architecture | ambiguous — depends on shape | rename without shape change is cosmetic, violates [API-NAME-004] |
| External convention | Apple uses `FormatStyle`, not `Formatter`-as-noun | the Formatter rename is institute-internal preference |
| [MOD-RENT] (3) theoretical content | ✓ binary-specific format styles are coherent | so-thin a layer that absorption into swift-format-primitives may be cleaner |
| Cost of rename cascade | — | possible cascade to swift-format-primitives → swift-formatter-primitives |

#### Verdict

**RECOMMENDATION: HOLD as sub-product. Re-evaluate when a third consumer surfaces or the witness-shape question is resolved.**

The strongest-against argument is rename signal ambiguity. Splitting AND renaming the same week without empirical experimentation on the witness shape (binary-base-n had V1–V7 to land on V7) repeats the failure mode that v1.0.0 of `binary-base-n-encoding-family-architecture.md` tripped on (untested empirical claim about external state). The rename to "Formatter" should be triggered by either (a) a witness-shape experiment confirming `Binary.Formatter<T>` is the right shape, OR (b) a swift-format-primitives → swift-formatter-primitives upstream rename. Neither is in flight.

**The minimum-cost alternative**: keep `Binary.Format` as a sub-product (current state) until a third external consumer arrives or the rename cascade is sorted upstream. If the user wants the dependency-drag relief, the smaller move is to drop `Binary Format Primitives` from the umbrella's default re-exports (consumers opt in explicitly), without a package split.

### Candidate 3: Serializable → Serializer — `swift-binary-serializer-primitives`

#### Both-sides arguments

**For split-with-shape-shift:**

1. **The institute already decided this architecturally.** [`canonical-witness-capability-attachment.md`](canonical-witness-capability-attachment.md) v1.2.0 (DECISION, 10/10 experiment variants CONFIRMED) established Pattern 2: cross-format alternatives are domain-owned witness types, not properties on the subject. `Binary.Serializer<T>` IS the binary-domain witness for serialization — symmetric with `Binary.Coder<T>` (which already exists). The current `Binary.Serializable` protocol is the OLD shape; the witness is the NEW shape per the canonical decision.
2. **ASCII migration precedent.** [`ascii-serialization-migration.md`](ascii-serialization-migration.md) (DECISION, 2026-03-25) documents the exact analog migration for `Binary.ASCII.Serializable`: 77 conformers across 15 packages, separate Parser + Serializer types per type, deprecate the domain protocol. The Binary case is structurally identical with a smaller consumer set (~9 packages).
3. **Compose with canonical Serializable.** Per the canonical-witness-capability decision, types adopt the canonical `Serializable` protocol from `swift-serializer-primitives` and provide `Binary.Serializer<Self>` as their `static var serializer: Self.Serializer`. This unifies the binary-domain shape with the canonical institute shape.
4. **Naming under [PKG-NAME-001].** "Serializer" is the agent noun for "serialize"; "Serializable" is the capability adjective. Per the institute's noun-form convention, the package and namespace should take the noun form. `swift-binary-serializer-primitives` aligns; `swift-binary-serializable-primitives` doesn't (Serializable isn't a noun, it's an adjective).
5. **Mirrors Binary.Coder shape.** `Binary.Coder<Output>` is a plain witness struct (closures + Witness.Protocol conformance + Coder.Protocol conformance) [Verified: 2026-05-07]. `Binary.Serializer<T>` should mirror this exact shape: a closure-based witness struct, conforming to `Serializer.Protocol` from `swift-serializer-primitives`. Architectural symmetry.

**Against split-with-shape-shift (per the principal's "argue both sides" mandate):**

1. **Migration impact is non-trivial.** 9+ external consumer packages currently conform to `Binary.Serializable` [Verified: 2026-05-07]. Migration cost: each conformer replaces protocol conformance with a `Binary.Serializer<Self>` witness AND (likely) adds canonical `Serializable` conformance. The ASCII precedent took 8 phases and remained DEFERRED post-release.
2. **The protocol form has affordances the witness doesn't.** `Binary.Serializable`'s `RawRepresentable` defaults (the Tagged conformance, Array/ContiguousArray/ArraySlice byte conformances) leverage Swift's protocol conformance system to provide free implementations. A pure witness shape needs explicit per-type witnesses; the "free defaults" become per-type ceremony unless they're factored into helpers.
3. **Tagged `where Underlying: Binary.Serializable` survives only if there's still a protocol.** The current code includes:
   ```swift
   extension Tagged: Binary.Serializable where Underlying: Binary.Serializable
   ```
   If the protocol disappears, this extension disappears. Tagged values lose automatic delegation to their Underlying's serializer. The replacement is per-Tagged-instance witness construction at the call site OR a `Binary.Serializer.delegated(to:)` factory that takes `Binary.Serializer<Underlying>` and returns `Binary.Serializer<Tagged<Tag, Underlying>>`. Possible, but it's reshape-of-affordance, not free-from-conformance.
4. **Pre-1.0 break vs 0.x evolution.** swift-binary-primitives is currently private, no public release. A breaking change is mechanically clean — no semver concerns — but the 9+ consumer packages span IETF RFCs (some public), ISO 32000 (public), and others. Coordinating the migration across orgs is more involved than a single-repo change.
5. **The protocol exists for a reason.** Per the original protocol-vs-witness analysis in `canonical-witness-capability-attachment.md`, the protocol provides generic constrainability: `func serialize<T: Binary.Serializable>(_ value: T) -> [UInt8]`. The witness alone doesn't — but the canonical `Serializable` protocol from swift-serializer-primitives DOES, AND it uses `static var serializer: Self.Serializer` to attach the witness. So the generic constrainability is preserved through the canonical protocol; the binary-specific protocol is redundant.

#### Decision criteria

| Criterion | Argues for | Argues against |
|---|---|---|
| Canonical institute decision | ✓ canonical-witness-capability v1.2.0 DECISION | requires migration to land the decision |
| ASCII precedent | ✓ direct structural analog | ASCII migration is DEFERRED post-release |
| Generic constrainability | preserved via canonical Serializable | binary-specific protocol gone, but canonical replaces |
| RawRepresentable / Tagged free defaults | reshape into helpers / static factories | adds ceremony per type |
| Consumer migration cost | bounded — 9 packages | non-trivial coordination |
| Mirrors Binary.Coder shape | ✓ symmetric | — |
| [MOD-RENT] (1)(2)(3) | ✓ all three pass | — |

#### Verdict

**RECOMMENDATION: SPLIT-WITH-SHAPE-SHIFT, but staged.** Ship `swift-binary-serializer-primitives` as L1 with `Binary.Serializer<T>` witness struct. Deprecate `Binary.Serializable` in `swift-binary-primitives` with a migration window pointing at the new package. Stage the consumer migration over multiple coordination cycles, mirroring `ascii-serialization-migration.md`'s 8-phase approach.

**The shape**: `Binary.Serializer<T>` is a plain witness struct with closures (analogous to `Binary.Coder<Output>`), conforming to:
- `Witness.\`Protocol\`` (institute witness convention)
- `Serializer.\`Protocol\`` (canonical capability) from `swift-serializer-primitives`

```swift
// Sketch — to be verified by an experiment before commitment
extension Binary {
    public struct Serializer<Value>: Sendable, Witness.`Protocol` {
        public var serialize: @Sendable (Value, inout [UInt8]) -> Void
        public init(serialize: @escaping @Sendable (Value, inout [UInt8]) -> Void) {
            self.serialize = serialize
        }
    }
}

extension Binary.Serializer: Serializer.`Protocol` {
    public typealias Buffer = [UInt8]
    public typealias Failure = Never
    public func serialize(_ value: Value, into buffer: inout [UInt8]) {
        self.serialize(value, &buffer)
    }
}
```

**Property<Binary.Serialize, T> alternative — REJECTED** as a candidate witness shape. `Property<Tag, Base>.View` is the canonical shape per [API-NAME-008] for *multi-form operations under one root* — `instance.encode.hex`, `instance.encode.url` style. Single-operation serialization is not multi-form; the plain witness struct shape (matching `Binary.Coder<Output>`) is correct. Per [API-NAME-008]'s decision rule: single-form operations use direct labeled methods (or here, plain witness fields); multi-form uses Property.View.

**Migration path** (mirroring ascii-serialization-migration.md):

1. Author `swift-binary-serializer-primitives` (this candidate).
2. Add canonical `Serializable` conformance + `static var serializer: Binary.Serializer<Self>` to each existing `Binary.Serializable` conformer in IETF / ISO / CPU / sockets / file-system packages.
3. Mark `Binary.Serializable` `@available(*, deprecated, message: "...")` with migration pointer.
4. Each consumer package migrates on its own schedule.
5. Remove `Binary.Serializable` once consumer migration completes (or persists indefinitely as a deprecated bridge).

This is a multi-cycle process; pre-1.0 status of `swift-binary-primitives` makes it mechanically tractable but requires per-action authorization for each org-touching step (each IETF / ISO / etc. coordination is a separate authorization).

### Candidate 4: Coder — `swift-binary-coder-primitives`

#### Empirical reframing

**Critical empirical claim correction per [RES-023]**: the handoff classifies this candidate as "(new) — not a current sub-product." This is correct *for swift-binary-primitives* (no Coder sub-product there) but wrong *for the ecosystem*: `Binary.Coder<Output>` already exists at `swift-primitives/swift-binary-parser-primitives/Sources/Binary Coder Primitives/` [Verified: 2026-05-07] as a plain witness struct conforming to `Coder.\`Protocol\``.

The accurate framing is: should `Binary.Coder` be **EXTRACTED** from `swift-binary-parser-primitives` into its own package?

#### Both-sides arguments

**For extraction:**

1. **Symmetry with the proposed Serializer split.** If `swift-binary-serializer-primitives` is its own package, the symmetric expectation is `swift-binary-coder-primitives` exists too. Otherwise the ecosystem has Serializer in its own package but Coder bundled with parsers.
2. **Consumer-side pattern.** Consumers of `Binary.Coder` may not always need the full parser machinery. Currently importing `Binary Coder Primitives` from `swift-binary-parser-primitives` means transitively pulling in input/parser/integer/leb128-parser/machine machinery. Extraction lets consumers take only the coder.
3. **Aligns with canonical `Coder.\`Protocol\``.** The institute has `swift-coder-primitives` (canonical capability protocol); a `swift-binary-coder-primitives` (binary-domain witness) maps cleanly onto the institute's package-per-domain pattern.

**Against extraction:**

1. **Coder needs the parser substrate.** Per `Binary.Coder.swift` [Verified: 2026-05-07], the type's `decode` field has signature `(inout Binary.Bytes.Input) throws(Binary.Bytes.Machine.Fault) -> Output`. `Binary.Bytes.Input` is the parser cursor (in `Binary Input Primitives`); `Binary.Bytes.Machine.Fault` is the parser error machine (in `Binary Machine Primitives`). The Coder cannot be extracted without also extracting Input + Machine, OR without restructuring its decode signature to use a different cursor type. **The current placement is structurally correct — Coder is in the parser-primitives package because its decode contract IS the parser's contract.**
2. **Symmetry argument cuts the other way.** `Binary.Coder` is a SYMMETRIC encode+decode pair. Encode is serialization, decode is parsing. The ecosystem already has separate parser-primitives and serializer-primitives because parsing and serialization are *asymmetric* operations (per `parsing-serialization-capability-organization.md`). A Coder type that bundles both into one witness sits naturally at the parser layer (which has the heavier substrate); it does NOT live independent of either parser or serializer substrates.
3. **Cost without benefit.** Extracting Coder would either require dragging Input + Machine into the new package (effectively repackaging part of swift-binary-parser-primitives) OR rewriting Coder's decode signature. Neither produces a clean, low-dep tier-0 leaf — it produces a tier-N package with the same substrate dependencies, just renamed.
4. **No second consumer signaling extraction urgency.** The principle motivator for swift-binary-base-primitives was lifting the encoding mechanism out of the high-tier swift-base62-primitives into a tier-0 leaf accessible to spec packages. No equivalent driver for Binary.Coder exists — it's already accessible to consumers via swift-binary-parser-primitives, and no consumer has signaled "I need Binary.Coder without the parser machinery."

#### Decision criteria

| Criterion | Argues for | Argues against |
|---|---|---|
| Symmetry with Serializer split | ✓ ecosystem looks regular | symmetry argument is cosmetic |
| Tier liberation | — | substrate deps (Input + Machine) prevent tier-0 leaf |
| Consumer demand | none signaled | none |
| Architectural fit | binary-domain Coder is its own "thing" | Coder's decode contract IS the parser cursor's contract |
| [MOD-RENT] (2) consumer | unknown — would need enumeration | none signaled today |
| [RES-018] second-consumer test | not yet checked | likely fails |

#### Verdict

**RECOMMENDATION: DO NOT extract. Coder stays in `swift-binary-parser-primitives`.**

The architectural fit is wrong for extraction. `Binary.Coder<Output>`'s `decode` field is parameterized over `Binary.Bytes.Input` — the parser cursor — which lives in `Binary Input Primitives`. Extracting Coder to its own package would either (a) require a dependency arrow from coder-primitives → parser-primitives substrate (defeating the extraction's tier-liberation purpose) or (b) require rewriting decode's signature (changing the API surface for unclear benefit).

**The right alternative if consumers signal a "Coder without parser machinery" need**: introduce a NEW witness shape in a new package that takes a less-coupled cursor type. That's not Binary.Coder; it's a distinct construct. The handoff's "swift-binary-coder-primitives" framing as a new package is best read as DEFERRED pending a real consumer driver that motivates a particular cursor decoupling.

The existing `Binary.Coder<Output>` placement is correct.

## Cross-Cutting Open Questions [from handoff]

### Per-package vs per-sub-product (handoff OQ-5)

The institute pattern, per the precedents surveyed, is:

- **Sub-products** when the variants are *aspect axes of a single semantic domain* (e.g., the buffer-primitives variant shapes — Linear, Ring, Slab — are storage-strategy aspects of the buffer domain).
- **Sibling packages** when the variants are *different semantic domains that share an anchor* (e.g., binary-primitives and binary-base-primitives both extend the `Binary` namespace but are different domains: byte manipulation vs base-N text encoding).

The decisive question is: *can the sub-product's domain stand alone with a coherent identity?* For LEB128 (named encoding spec, multi-spec authority), yes — sibling package fits. For Binary.Format (thin formatting layer over swift-format-primitives), the domain identity is borderline. For Binary.Cursor (intrinsic to walking Binary.Bytes), no — sub-product.

### Namespace anchor strategy (handoff OQ-6)

`Binary Namespace` is already factored as its own target per [MOD-017] and exposed as a library product. Each new sibling package re-exports it via `@_exported public import Binary_Namespace` — exactly the swift-binary-base-primitives pattern. The strategy is correct as-is; no further extraction needed. With 5+ sibling packages eventually extending `Binary.*`, the anchor target's discipline (no external deps; layer-invariant naming per MOD-017) becomes more important, not less.

### Migration impact (handoff OQ-7)

| Move | External consumers | Migration cost |
|------|--------------------|-----------------|
| LEB128 split | 1 (swift-binary-parser-primitives) | trivial — Package.swift dep change |
| Format/Formatter split-and-rename | 2 (swift-rfc-8446, swift-rfc-6455) | low — Package.swift + rename references |
| Serializable → Serializer | 9+ (IETF, ISO, CPU, sockets, file-system, base62, rule-legal-nl) | non-trivial — multi-org coordination, multi-phase |
| Coder extraction | unknown (deferred) | n/a — recommended NOT to do |

The Serializer migration is the largest cost. Pre-1.0 status of swift-binary-primitives makes the protocol break mechanically clean (no semver), but coordinating across the IETF/ISO orgs requires per-action authorization and staged execution.

## Outcome

**Status**: RECOMMENDATION

### Per-Candidate Summary

| Candidate | Verdict | Trigger condition |
|-----------|---------|-------------------|
| LEB128 split | **RECOMMEND SPLIT** as `swift-binary-leb128-primitives` (split-only, no reshape) | Ready now — second-consumer test passes via swift-binary-parser-primitives. May be deferred to first L2 spec consumer (DWARF/WASM/Protobuf) on principal's preference. |
| Format → Formatter split-and-rename | **HOLD** as sub-product | Re-evaluate when (a) a third external consumer surfaces, OR (b) witness-shape experiment confirms `Binary.Formatter<T>` shape, OR (c) swift-format-primitives → swift-formatter-primitives upstream rename. |
| Serializable → Serializer split-and-shape-shift | **RECOMMEND SPLIT** as `swift-binary-serializer-primitives` (witness reshape, multi-phase migration) | Authorization gates: (1) author the package + experiment validating witness shape; (2) per-org consumer migration each requires its own authorization; (3) `Binary.Serializable` deprecation period, then removal. |
| Coder extraction | **DO NOT EXTRACT** | Architectural fit is wrong; existing placement at swift-binary-parser-primitives is correct. Reframe as DEFERRED pending an actual cursor-decoupling consumer driver. |

### What this means for the active session

No package creation in this session. Per the user's `feedback_no_public_or_tag_without_explicit_yes.md`, every step beyond this research requires explicit per-action authorization. The recommendations above identify which steps would be candidates for that authorization:

1. **Cheap path (low coordination)**: author `swift-binary-leb128-primitives` as sibling package, mirroring swift-binary-base-primitives' shape. One Package.swift, ~2 source files moved, 1 consumer Package.swift updated (swift-binary-parser-primitives).
2. **Medium path**: experiment authoring `Binary.Serializer<T>` witness struct in a scratch experiment package (analogous to `binary-base-n-poc/`), validating the shape before package creation.
3. **High-coordination path**: swift-binary-serializer-primitives package + multi-phase consumer migration. Each phase requires its own authorization.
4. **Holds**: Format/Formatter and Coder are not actioned.

### Conventions established

- **L1 mechanism + L2 spec packages** (from `binary-base-n-rfc-4648-reconciliation.md`) generalizes to LEB128: L1 owns the bit-level encoding; future L2 spec packages (DWARF, WASM, Protobuf) own their spec-literal consumption and delegate algorithms to L1. Same pattern, same discipline.
- **Domain-owned witness types** (Pattern 2 from `canonical-witness-capability-attachment.md`) is the canonical institute shape for binary-domain serialization. `Binary.Serializer<T>` joins `Binary.Coder<Output>` (existing) as the witness pair for this domain.
- **Plain witness struct over Property<Tag, Base>** for single-form operations (per [API-NAME-008]'s decision rule). Property witness is reserved for multi-form operations under one root (as in `Binary.Base.\`16\`.encode.hex`); single-operation serialization uses plain witness fields.

## Open Questions for the User

Before any implementation step is authorized:

1. **Does the user prefer to act on the LEB128 split now, or defer to first L2 spec package?** Both are valid; the cost-asymmetry argument prefers waiting for an L2 driver, but the precedent argument prefers acting now.
2. **For `swift-binary-coder-primitives` as raised in the handoff**: confirm the correction that `Binary.Coder` already exists in swift-binary-parser-primitives and the recommendation to NOT extract. If there's an unstated consumer driver the principal had in mind, surface it before deferring this candidate.
3. **For `swift-binary-serializer-primitives`**: is the witness-shape experiment (the scratch package validating `Binary.Serializer<T>`'s shape against existing Binary.Serializable conformers) the right next step before authorizing the package, mirroring the V1–V7 binary-base-n-poc cycle?
4. **For Format/Formatter rename specifically**: is a `Formatter` rename of `swift-format-primitives` itself in flight or planned? If yes, the cascade dictates `Binary.Formatter` follows; if no, the rename should not be made unilaterally for the binary case.

## References

### Internal artifacts

- Today's split precedent: `swift-primitives/swift-binary-base-primitives` (private 2026-05-07) — the structural template.
- Canonical witness decision: [`canonical-witness-capability-attachment.md`](canonical-witness-capability-attachment.md) v1.2.0 (DECISION).
- ASCII migration analog: [`ascii-serialization-migration.md`](ascii-serialization-migration.md) (DECISION).
- Architecture pattern: [`binary-base-n-rfc-4648-reconciliation.md`](binary-base-n-rfc-4648-reconciliation.md) (RECOMMENDATION) — L1/L2/L3 directional discipline.
- Family architecture: [`binary-base-n-encoding-family-architecture.md`](binary-base-n-encoding-family-architecture.md) (RECOMMENDATION) — closed-mechanism + open-authorities pattern.
- Split cost model: [`algebra-primitives-package-split.md`](algebra-primitives-package-split.md) (RECOMMENDATION).
- Transformation domains umbrella: [`transformation-domain-architecture.md`](transformation-domain-architecture.md) (DECISION).
- Capability organization: [`parsing-serialization-capability-organization.md`](parsing-serialization-capability-organization.md) (SUPERSEDED by transformation-domain-architecture, but still authoritative on the parsing/serialization asymmetry argument).
- Package status note: [`swift-binary-primitives/Research/binary-primitives-rawvalue-underlying-rename.md`](../../swift-primitives/swift-binary-primitives/Research/binary-primitives-rawvalue-underlying-rename.md) — "no drift from L1 vocabulary mission" (the do-not-split anchor).
- Comparative analysis: [`swift-binary-primitives/Research/Comparative Analysis swift-binary-primitives.md`](../../swift-primitives/swift-binary-primitives/Research/Comparative%20Analysis%20swift-binary-primitives.md) — Core's identity as binary-data-manipulation.

### Skills + conventions

- [PRIM-FOUND-001] No Foundation in L1.
- [MOD-DOMAIN] One semantic domain per package.
- [MOD-RENT] Three-criteria primitive-package rent test.
- [MOD-017] Namespace target naming.
- [PKG-NAME-001] Noun form for packages and namespaces.
- [PKG-NAME-002] Canonical capability protocol via `Namespace.\`Protocol\``.
- [API-NAME-008] Property.View vs labeled method decision rule.
- [RES-018] Premature primitive anti-pattern.
- [RES-023] Empirical-claim verification for dependent-package state.

### External primary sources

- [`leb128` crate (crates.io)](https://crates.io/crates/leb128) — Rust precedent for standalone LEB128 package; consumers `wasm-encoder`, `gimli`, `prost`.
- [LLVM `Support/LEB128.h`](https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/Support/LEB128.h) — single-header, multi-spec-consumer pattern.
- [DWARF v5 §7.6](https://dwarfstd.org/doc/DWARF5.pdf) — LEB128 specification (one of three independent authorities).
- [WebAssembly Core 1.0 §5.2.2](https://www.w3.org/TR/wasm-core-1/#binary-int) — LEB128 in WASM binary format.
- [Protocol Buffers Encoding](https://protobuf.dev/programming-guides/encoding/#varints) — LEB128-style varint encoding (Protobuf calls them "varints" but the encoding is LEB128).
