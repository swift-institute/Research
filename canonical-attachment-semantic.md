# Canonical-Attachment Semantic

<!--
---
version: 1.0.0
last_updated: 2026-05-22
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---

Changelog:
- v1.0.0 (2026-05-22): initial RECOMMENDATION. Tier 2 ecosystem-wide
  investigation resolving axis B (canonical-attachment semantic) deferred
  by `sibling-refines-canonical-attachment.md` v1.1.0 §10a. Recommends
  path (c) — additive `Common.Codable` peer alongside the existing
  canonical attachment trio, sanctioned-but-deferred until a live
  consumer surfaces a currency-type need or Apple's New Codable proposal
  reaches a formal Swift Evolution pitch. [FAM-002]'s type-commitment
  semantic stays intact for the existing canonical trio; [FAM-003]'s
  guarded-use rule continues scoping conformance to spec-value types.
  Pre-codified as [FAM-011] pending principal authorization.
-->

## Context

The parent investigation `sibling-refines-canonical-attachment.md` v1.1.0
(2026-05-22) split a single design question into two independent axes:

- **Axis A — structural**: should format-specific sibling attachment protocols
  refine the canonical attachment protocols of the same family? Resolved as
  **[FAM-010] NO** — siblings remain flat per [FAM-001]; canonicals stay at
  peer rank per [FAM-006]; the diagonal is closed by [FAM-010]. v1.1.0 of the
  parent doc reinforced this axis via an independent outside-view review
  (`HANDOFF-multi-format-serialization-fresh-review.md` — 36-system survey +
  corpus-grounded /swift-forums-review simulation + Phase 2 synthesis per
  [RES-020]).

- **Axis B — semantic**: what does conformance to the canonical attachment
  protocol *mean*? The parent v1.1.0 deferred this axis to a successor arc
  because the fresh-view review surfaced an empirical convergence (Go's
  `encoding.*` 2013 + Apple's New Codable prototype 2025) on *author-choice-
  with-fallback* semantics that challenges [FAM-002]'s current statement of
  *"ONE inherent canonical codec per spec-value type."*

This document resolves axis B. v1.1.0 §10a enumerates three structurally-
distinct resolution paths, each consistent with [FAM-010]:

| Path | Semantic | Rule changes | Surface change |
|---|---|---|---|
| **(a)** Preserve [FAM-002] type-commitment scoped via [FAM-003] | "ONE inherent codec per spec-value type"; non-spec-value types decline canonical | None | None |
| **(b)** Reframe canonical to author-choice-with-fallback per fresh view | "minimum-common shape any encoder can serialize"; [FAM-002] rewritten; [FAM-003] potentially relaxed | [FAM-002] rewritten; [FAM-003] relaxed | Existing conformers re-interpreted |
| **(c)** Introduce a thin `Common.Codable` analogue alongside existing canonical | Two semantics coexist: existing canonical (type-commitment) + new `Common.Codable` (author-choice-with-fallback) | [FAM-002] unchanged; new rule [FAM-011] added | New peer protocol added |

Per the brief: recommend ONE path (or a hybrid) with structural + migration
analysis, plus a concrete answer to the fresh-view's tipping question — *can a
sufficiently-rich canonical container API absorb every format's native concerns
(CBOR tags, protobuf field numbers, plist data types, JSON null-vs-missing-key,
MessagePack ext types, XML attribute-vs-element) without translation loss?*

**Trigger**: branching handoff `HANDOFF-canonical-semantic-axis-b.md` (2026-05-22)
dispatched immediately after v1.1.0 of the parent doc shipped its axis-B
deferral. Per [RES-020] this arc is Tier 2 ecosystem-wide; the conclusion
either reinforces an existing canonical-attachment commitment ([FAM-002]) or
opens a new attachment-tier protocol. Either way the question deserves the
discipline of empirical inventory + structural argument + cognitive-
dimensions analysis rather than being closed by inference.

**Predecessors retired**: none. Novel Tier 2 investigation per [HANDOFF-039]
of the handoff brief. Parent v1.1.0 doc and the fresh-view findings handoff
are INPUTS, not retired predecessors.

## Question

**What semantic should the institute's canonical attachment protocols
(`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`,
`Serializer_Primitives_Core.Serializable`) carry?**

Sub-questions:

1. **Inventory.** What does the current set of canonical-attachment
   conformances look like? Per [HANDOFF-021] include the enumeration command +
   live output. Per [RES-023] verify each file:line at write time. For each
   conformer, classify its semantic against the three readings.

2. **Live-state survey.** What is the current shape of Apple's New Codable
   prototype against paths (a)/(b)/(c)? Per [RES-031] verify version-pinned
   claims against primary sources before quoting.

3. **The tipping question.** Can a sufficiently-rich canonical container API
   absorb every format's native concerns without translation loss? If yes,
   the canonical can be a *rich primary surface* (path b's effective shape).
   If no, the canonical is a *thin floor* — compatible with (a) or (c) but
   not (b).

4. **Per-path migration analysis.** Which conformers change under each path?
   What does the [FAM-002]/[FAM-003] rewrite cost look like under (b)? What
   does the new protocol's [FAM-009] placement and [FAM-010] no-refinement
   composition look like under (c)?

5. **Recommendation.** ONE path (or a hybrid) with structural + migration
   analysis.

## Methodology

Per **[RES-019] internal grep first** (executed at write time, 2026-05-22):

```bash
# Ecosystem-wide
grep -rl "canonical-attachment-semantic" swift-institute/Research/    # zero hits
grep -rl "CommonCodable" swift-institute/Research/                    # parent only
grep -rl "axis B"          swift-institute/Research/                  # parent only
grep -rl "author-choice-with-fallback" swift-institute/Research/      # parent only
ls swift-institute/Research/*-canonical-*.md                          # zero hits beyond parent
# Per-package per [HANDOFF-013a]
grep -rl "canonical-attachment-semantic" swift-foundations/swift-json/Research/  # zero
grep -rl "canonical-attachment-semantic" swift-primitives/*/Research/            # zero
```

No prior research addresses axis B / canonical-semantic / `Common.Codable`
directly. Parent v1.1.0 surfaced the question; the per-package
family-codable-convention.md v1.1.4 §9 cites Apple's `CommonCodable` as a
"structural distinction" the institute lacks an analog of, but does not
choose between paths (a)/(b)/(c). Multi-format-codable-readiness.md v1.0.0
CROSS-1 audits the canonical-attachment associated-type latent risk
(generic-conformance trap) but addresses neither the semantic question nor
the CommonCodable analog.

Per **[RES-021] prior art survey with contextualization**: the parent v1.1.0
incorporated a 36-system fresh-view survey (Rust serde; Haskell aeson family;
OCaml ppx_deriving + atdgen; Scala circe/play-json/upickle/scodec/avro4s/
scala-pickling; Java Jackson/Gson/Moshi/Kryo; Kotlin kotlinx.serialization;
Python pydantic/marshmallow/msgspec/cattrs; Go encoding.* + protobuf-go +
easyjson; .NET System.Text.Json + Newtonsoft + MessagePack-CSharp + protobuf-
net; JS/TS zod/io-ts/class-transformer/superjson/cbor-x; Protocol Buffers
cross-language; Apple Foundation Codable + New Codable prototype). This doc
cites that survey directly rather than re-running it; the citation discipline
per [RES-013a] applies — each carried-forward finding is verified against
the source.

Per **[RES-022] structural-correctness framing**: the recommendation drives
on structural identity (which semantic accurately describes the existing
conformer reality, and what protocol surface follows). Cost / migration /
pragmatism axes serve as tiebreakers only.

Per **[RES-023] empirical-claim verification**: every file:line citation and
every empirical claim about the current source state is verified inline at
write time. The verification commands are reproduced in §1 + §3.

Per **[RES-025] Cognitive Dimensions analysis**: applied in §8 to the
recommended path against alternatives.

Per **[RES-029] framing-challenge for binding/membership/placement questions**:
axis B is a *binding* question (which semantic *is* the canonical's contract),
not a cost-ranking question. Semantic identity ranks first; cross-ecosystem
operational behavior ranks second; cost/pragmatism is tiebreaker only.

Per **[RES-031] independent verification of version-pinned claims**: live-
state claims about Apple's New Codable prototype (thread reply counts, dates,
quoted text) are verified against forums.swift.org directly at write time.

Per **[HANDOFF-013a] writer-side prior-research grep**: applied to
`swift-institute/Research/`, `swift-foundations/swift-json/Research/`, and
each L1 primitives `Research/` corpus before drafting. No conflicting prior
research surfaced.

---

## Analysis

### 1. Inventory of canonical-attachment conformances

Per [HANDOFF-021] / [RES-023] the enumeration command and live output are
included verbatim; per [HANDOFF-040] generic-instantiated forms are included.

#### Enumeration command (re-runnable)

```bash
# Direct (qualified) canonical-attachment conformances
grep -rn --include='*.swift' \
  -E '@retroactive (Coder_Primitives|Parser_Primitives_Core|Serializer_Primitives_Core)\.(Codable|Parseable|Serializable)\b' \
  swift-primitives swift-standards swift-foundations swift-ietf

# Unqualified (in-package extension) canonical-attachment conformances
grep -rn --include='*.swift' \
  -E 'extension .+:\s*(Codable|Parseable|Serializable)\b' \
  swift-primitives swift-standards swift-foundations swift-ietf

# Generic-instantiated forms (Tagged, Optional, wrappers)
grep -rn --include='*.swift' \
  -E 'extension .+:\s*(Codable|Parseable|Serializable)\s+where' \
  swift-primitives swift-standards swift-foundations swift-ietf
```

#### Live output — canonical-attachment conformances (verified 2026-05-22)

The grep returns a finite set of files; each was inspected to filter out
`Swift.Codable` conformances (which use existential `Decoder`/`Encoder` and
untyped `throws`, distinguishable by the file's `swiftlint:disable
no_any_protocol_existential typed_throws_required` markers) from the
institute's `Coder_Primitives.Codable` / `Parser_Primitives_Core.Parseable` /
`Serializer_Primitives_Core.Serializable` conformances.

**Direct canonical-attachment conformances on concrete types:**

| Conformer | Protocol | File:line | Semantic flavor |
|---|---|---|---|
| `RFC_8259.Value` | `Coder_Primitives.Codable` (via `@retroactive`) | `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:125` | **Type-commitment**: carries [FAM-003] justification *"RFC_8259.Value has exactly one inherent canonical codec — JSON ... cannot meaningfully be encoded as anything other than its JSON representation; it IS the JSON tree value type."* |
| `Version.Semantic` | `Parser_Primitives_Core.Parseable` | `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Semantic+Parseable.swift:16` | **Type-commitment**: SemVer 2.0.0 byte-stream parser is the one inherent canonical parser per the SemVer spec |
| `Version.Tools` | `Parser_Primitives_Core.Parseable` | `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Tools+Parseable.swift:16` | **Type-commitment**: SE-0152 string form is the one inherent canonical parser per the Swift package-manager spec |
| `Version.Calendar` | `Parser_Primitives_Core.Parseable` | `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Calendar+Parseable.swift:16` | **Type-commitment**: calver.org form is the one inherent canonical parser per the CalVer spec |
| `Glob.Pattern` | `Parser_Primitives_Core.Parseable` | `swift-primitives/swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern+Parseable.swift:16` | **Type-commitment**: glob byte-stream parser is the one inherent canonical parser per the glob spec |
| `FixedWidthInteger` (10 stdlib integers: `Int`, `UInt`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`) | `Serializer_Primitives_Core.Serializable` (via `@retroactive`) | `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift:8–44` | **[FAM-002] VIOLATION — RECOMMENDED-FOR-MIGRATION per Φ.3**: `Int` has no inherent canonical codec; pin to ASCII decimal is the legacy shape the convention's [FAM-001]+[FAM-002] structural argument was designed to escape |
| `FixedWidthInteger` (same 10 stdlib integers) | `Parser_Primitives_Core.Parseable` (via `@retroactive`) | `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift:11+` | **[FAM-002] VIOLATION — RECOMMENDED-FOR-MIGRATION per Φ.3**: same reasoning as the serializer pin |

**Generic-instantiated (delegating) conformances** per [HANDOFF-040]:

| Conformer (generic) | Protocol | Where condition | File:line | Semantic flavor |
|---|---|---|---|---|
| `Tagged<Tag, Underlying>` | `Parser_Primitives_Core.Parseable` | `Underlying: Parseable, Underlying.Parser.Output == Underlying` | `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Tagged+Parseable.swift:43` | **Delegation, not commitment**: Tagged's `Parser` lifts the underlying's parser via `UnderlyingParser`; conformance is "Tagged IS Parseable iff Underlying IS Parseable." Tagged adds no commitment of its own. |
| `Tagged<Tag, Underlying>` | `Serializer_Primitives_Core.Serializable` | `Underlying: Serializable, Underlying.Serializer.Output == Underlying` | `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Tagged+Serializable.swift:44` | **Delegation, not commitment**: same lifting pattern as Tagged+Parseable. |
| `Swift.Optional<Wrapped>` | `Serializer_Primitives_Core.Serializable` | `Wrapped: Serializable` | `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Standard Library Integration/Optional+Serializable.swift:21` | **Delegation, not commitment**: Optional's `Serializer` is `Serializer.Optionally<Wrapped.Serializer>`; the conformance lifts the wrapped's commitment into an Optional context. Optional itself has no inherent canonical codec. |

#### Classification summary

The current set of canonical-attachment conformances falls into three
classes:

| Class | Members | Semantic |
|---|---|---|
| **Class I — Spec-value-type commitments** ([FAM-002] textbook cases) | `RFC_8259.Value`, `Version.Semantic`, `Version.Tools`, `Version.Calendar`, `Glob.Pattern` | Each carries ONE inherent canonical codec by its specification. The conformance accurately commits the type. |
| **Class II — Generic-instantiated delegations** ([HANDOFF-040] case) | `Tagged<Tag, Underlying>` (parser + serializer), `Swift.Optional<Wrapped>` (serializer) | The wrapper inherits the underlying's commitment; the wrapper itself carries no commitment. |
| **Class III — Legacy stdlib pins** (RECOMMENDED-FOR-MIGRATION) | 10 stdlib integer types via `FixedWidthInteger` canonical Parseable + Serializable pins | These pin stdlib integers to ASCII-decimal codec at the canonical layer — exactly the [FAM-002] violation the convention was designed to escape. Φ.3 of `swift-foundations/swift-ascii/Research/ascii-codable-unification.md` already targets removal. |

**Key empirical reading**: every Class I conformance carries a [FAM-003]-style
justification (sometimes inline, sometimes implicit in the type's spec
identity); every Class II conformance is structurally a *lift* rather than a
*commitment*; Class III is on a migration path to extinction. **The institute's
existing canonical-attachment conformer surface is fully consistent with
type-commitment semantic scoped to spec-value types, with one in-flight
migration removing the residual stdlib pins.** Path (a) is not aspirational —
it is the operational state.

### 2. Semantic classification against the three readings

For each class above, the three readings interact differently:

#### Class I — Spec-value-type commitments

| Reading | Fit | Why |
|---|---|---|
| (a) Type-commitment | EXACT FIT | Each conformer's justification language explicitly says "type X has one inherent canonical codec" — RFC_8259.Value is the JSON tree value; Version.Semantic is the SemVer 2.0.0 form; etc. The semantic accurately describes the structural identity. |
| (b) Author-choice-with-fallback | POOR FIT (misreads identity) | Reframing RFC_8259.Value's canonical conformance as "fallback floor" would require the type to potentially also have *other* codecs the canonical falls back from. But RFC_8259.Value cannot be encoded as anything other than its JSON representation by definition (it IS the JSON tree value). There is no "author choice" — there is only the spec. |
| (c) Coexist: existing canonical + new `Common.Codable` peer | EXACT FIT | Class I conformers keep their commitment via the existing canonical; the new peer addresses non-spec-value types (Class II/III shape) without disturbing Class I. |

#### Class II — Generic-instantiated delegations

| Reading | Fit | Why |
|---|---|---|
| (a) Type-commitment | INDIRECT FIT | `Tagged<Tag, Underlying>` and `Optional<Wrapped>` don't *themselves* commit; they *lift* the underlying's commitment. Under (a), the lifting is a structural delegation pattern that respects [FAM-002] (the underlying still has ONE inherent codec when Tagged-conforms). |
| (b) Author-choice-with-fallback | INDIRECT FIT (same logic, different label) | The lifting is independent of the underlying's commitment semantic; both readings work mechanically. |
| (c) Coexist | INDIRECT FIT | The lifting pattern applies symmetrically to either canonical attachment. If a new `Common.Codable` peer is introduced, the wrapper types can opt-in to lifting either or both. |

Class II is *semantically neutral* — the wrapper-lift pattern works under
any axis-B reading. It does not bias the choice between paths.

#### Class III — Legacy stdlib pins (RECOMMENDED-FOR-MIGRATION)

| Reading | Fit | Why |
|---|---|---|
| (a) Type-commitment | DEFECT — already targeted by Φ.3 | Pinning `Int` to ASCII-decimal at the canonical layer is the failure mode [FAM-002] was designed to prevent: `Int` has no inherent canonical codec. The Φ.3 migration removes these pins; under (a), the residual cleanup completes the path. |
| (b) Author-choice-with-fallback | "saved-by-reframing" | If the canonical's semantic is reframed to fallback-floor, the existing stdlib pins arguably become legitimate fallback conformances (`Int` falls back to ASCII-decimal across formats). But this *retains* the pins that the institute has already decided to remove — and accepts the consumer-confusing layer where `Int` carries a canonical codec that's used as a fallback in some contexts and ignored in others (sibling conformances on `Int` declare format-specific representations that override the fallback). |
| (c) Coexist | DEFECT — same Φ.3 migration applies | Under (c), the existing canonical retains its [FAM-002] type-commitment semantic; `Int`'s pin is still a [FAM-002] violation; Φ.3 still applies. The new `Common.Codable` peer is independent. |

Class III is the decisive class: paths (a) and (c) both treat the residual
pins as defects to be removed; path (b) effectively re-legitimizes them, in
contradiction with the institute's already-active Φ.3 cleanup.

#### Semantic-classification verdict

The current conformer reality strongly aligns with **type-commitment scoped
to spec-value types** (path (a)'s reading) with a residual cleanup
(Class III → Φ.3) in flight. Path (b) would require either accepting the
residual pins as legitimate fallback conformances (reversing the Φ.3
decision) or re-interpreting the spec-value-type commitments as fallbacks
(misreading their identity). Path (c) preserves Class I commitments
unchanged and addresses the non-spec-value-type gap additively.

### 3. Live-state survey of Apple's New Codable prototype

Per [RES-031] each version-pinned claim is verified against the primary
source at write time. The two relevant threads:

#### Thread 1: forums.swift.org/t/78585 "The future of serialization & deserialization APIs"

**Live state verified 2026-05-22**:

- Total posts: 178
- Last reply: 2026-03-06
- Status: ongoing discussion phase; no formal Swift Evolution pitch

**Verbatim quotes (from primary source, verified)**:

- Opening post (Kevin Perry, 2025-03-17): *"we should encourage each
  serialization format that has native support for data types that aren't
  represented in the format-agnostic interface to produce its own protocol
  variant that includes explicit support for these types, e.g. `JSONCodable`
  or `PropertyListCodable`. … These format-specialized protocols are expected
  to be entirely distinct from the format-agnostic one, but they should share
  the same basic structure and patterns."*

  The phrase *"entirely distinct from the format-agnostic one"* is load-
  bearing: it explicitly disclaims a refinement relationship between the
  format-specialized protocols (`JSONCodable`, `PropertyListCodable`) and the
  format-agnostic protocol (`CommonCodable`). The two layers are peers.

- Reply #33 (Perry, in response to a question about cross-format types like
  Range and CGRect): *"Range and CGRect can, in similar fashion to Codable,
  describe their serializable members abstractly, allowing a specific
  encoder/decoder to interpret those instructions."*

  The currency-type framing: `Range` and `CGRect` *do not have one inherent
  canonical codec* but *do have a serializable shape* that any encoder can
  interpret. This is the author-choice-with-fallback semantic — the type
  describes itself abstractly; the encoder picks the format-specific
  interpretation.

#### Thread 2: forums.swift.org/t/85186 "New Codable prototype available for feedback"

**Live state verified 2026-05-22**:

- Total posts: 71
- Last reply: 2026-05-22 (active within the past day; per [RES-031]
  re-verified via direct primary-source fetch on the same date)
- Status: active prototype feedback phase; the prototype is shipped (open-
  source repo accessible) but the design conversation is live

**Protocols named in the prototype** (per opening post and subsequent design
discussion):

| Protocol/type | Role |
|---|---|
| `CommonEncodable` / `CommonDecodable` | Format-agnostic peers — the abstract self-describing surface for currency types |
| `JSONEncodable` / `JSONDecodable` | Format-specialized siblings — JSON-native expressiveness (per [FAM-010]: peers, not refinements) |
| `CommonEncoder` / `CommonDecoder` | The encoder/decoder driver protocols (operational layer) |
| `JSONParserDecoder` / `JSONPrimitiveDecoder` | Concrete decoder implementations |
| `JSONDirectEncoder` | Concrete encoder implementation |
| `NewJSONEncoder` / `NewJSONDecoder` | Top-level public APIs |

**Verbatim observations from the prototype design**:

- Perry (opening post t/85186): the JSON variants have *"modifications that
  are specific to JSON, including certain performance optimizations."*

- Perry (t/85186): the existential-Encoder cost is a primary motivation: the
  prototype reports approximately 6× throughput improvement over JSONDecoder
  when decoding large JSON files. This is the macro-specialization argument
  the fresh view surveyed; it suggests the per-format protocol's primary
  unique role is *enabling format-specialized macro synthesis*, not
  expressing a different semantic per se.

- Perry (t/85186): there are *"unanswered questions about how what level of
  support we want in NewJSONDecoder for Data and Date... It's hard to
  implement this in a way that allows Foundation to layer it on top."* —
  evidence that even within Apple's design context, the format-agnostic +
  format-specialized split is *not* a clean architectural separation; some
  format-native concerns (Data, Date strategies) bleed across the boundary.

- Post #71 (user `tera`, 2026-05-22): the active conversation has moved to
  discussing default-value handling — *"while the current Codable allows
  optional fields to be absent when decoding, the new Codable could support
  missing 'defaulted' fields (fields with default values)."* — this signals
  the prototype is still pre-pitch and the design is responsive to community
  input on cross-cutting decisions.

#### Mapping the New Codable prototype against paths (a)/(b)/(c)

| Apple element | Path-equivalent | Notes |
|---|---|---|
| `CommonEncodable` / `CommonDecodable` (peers of format-specialized; "describe abstractly, let encoder interpret") | **Path (c)** new peer — exactly the additive `Common.Codable` analogue's role | Apple's design IS path (c) from the institute's perspective: the format-agnostic protocol is additive, not a reframing of an existing canonical |
| `JSONEncodable` / `JSONDecodable` (format-specialized siblings; "entirely distinct from the format-agnostic one") | **Path-orthogonal** — corresponds to the institute's existing format siblings under [FAM-010] | The institute already has this layer ([FAM-001], [FAM-005], [FAM-010]); axis B doesn't disturb it |
| 6× throughput from per-format specialization | Path-orthogonal; relevant to *whether per-format protocols carry independent semantic content* (yes — macro-specialization is the unique role) | Reinforces axis A's [FAM-010] (siblings stand alone with format-native semantics) |
| Currency-type framing for Range/CGRect | The motivating use case for path (c)'s new peer | Currency types are the gap that the existing institute canonical attachment doesn't address — Range, CGRect, UUID have no inherent canonical codec but *do* have a cross-format fallback shape |

**Per [RES-031] verification status**: every quoted phrase in this section
was verified against the primary thread URL on 2026-05-22. The post counts
(178 and 71) and last-reply dates (2026-03-06 and 2026-05-22) reflect the
live state as of write time.

#### Live-state verdict

Apple's New Codable design IS structurally path (c): an additive format-
agnostic protocol peer alongside format-specialized siblings, with the
format-agnostic layer carrying the author-choice-with-fallback semantic for
currency types. The institute is currently *behind* on path (c) only in the
sense that the corresponding peer protocol has not been authored; the rest
of the design (per-format siblings via [FAM-010], operational-layer
refinement via [FAM-006]) parallels Apple's framing.

Apple has NOT settled on:
- whether the format-specialized protocols formally refine the format-
  agnostic one — Perry's "entirely distinct" language makes the peer
  relationship the structural intent, but no formal proposal text codifies
  this yet
- the exact naming (`CommonEncodable` / `CommonDecodable` / `CommonCodable`)
- the richness of the format-agnostic surface (Data, Date strategies remain
  open per Perry's t/85186 quote)

This means the institute's path (c) implementation, if pursued, has *design
latitude* — the institute does not need to lock-step with Apple's prototype
naming or surface until Apple settles a formal pitch. But the *structural
shape* (additive peer, no refinement, currency-type semantic) is convergent.

### 4. The tipping question

The fresh-view's tipping question:

> Can a sufficiently-rich canonical container API absorb every format's
> native concerns (CBOR tags, protobuf field numbers, plist data types, JSON
> null-vs-missing-key, MessagePack ext types, XML attribute-vs-element)
> without translation loss?

A direct enumeration of the named concerns against any sufficiently-rich
canonical:

| Format-native concern | What it expresses | Can a single rich canonical absorb it? |
|---|---|---|
| **CBOR tags** | Semantic-typed wrappers around CBOR's base types (RFC 8949 §3.4). Tag 0 = date/time string; tag 1 = epoch-based date/time; tag 42 = IPLD CID; user-defined tags carry arbitrary application semantics. The tag is part of the encoded representation; not absorbing it loses information. | **PARTIAL — at high cost**. The canonical would need a `taggedValue(tag: UInt64, value: Self)` container kind. JSON has no analog (no tag concept); kotlinx.serialization handles this via per-format annotation `@CborLabel`. Putting it on the canonical leaks CBOR-shape concerns into every encoder. |
| **Protobuf field numbers** | Each protobuf message field has an explicit field number that drives wire format. The field number IS the field identity on the wire; field names are an in-language convenience that doesn't survive encoding. | **NO — categorical mismatch**. JSON / plist / XML encode by name; protobuf encodes by number. A unified container surface would need to carry *both* a name AND a field number simultaneously per field. kotlinx.serialization handles this via `@ProtoNumber` — *per-format* annotation, not container-API absorption. |
| **Plist data types** | Plist distinguishes `Data` (binary blob), `Date` (date type with strategy), `Number` (split between Integer and Real), `Array`, `Dictionary`, `Boolean`, `String`. JSON has only `Object`, `Array`, `String`, `Number`, `Boolean`, `Null` — no `Data`, no `Date`. | **NO**. A canonical that includes `Data` and `Date` as first-class container kinds becomes either (a) richer than JSON can express (forcing encoding-time translation losses for JSON), or (b) plist-shape-biased (the same Codable-design-leaks-JSON-shape problem the fresh-view @reviewer-c8 critiqued in reverse). Either choice loses. |
| **JSON null-vs-missing-key** | JSON distinguishes `{"x": null}` from `{}` (missing key). Codable today encodes both as `Optional<X>.none`, losing the distinction. The Codable v6 pain forum thread (t/69542) explicitly cites this as a long-standing limitation. | **PARTIAL — but at the cost of every other format**. A canonical container that distinguishes `null` from `missing` would force every encoder (plist, CBOR, MessagePack, XML) to either represent the distinction (most can't natively) or collapse it (losing data on round-trip). The asymmetry is structural — JSON has the distinction, most formats don't. |
| **MessagePack ext types** | MessagePack reserves tag bytes 0xc7/0xc8/0xc9 (ext 8/16/32) for application-defined extension types. Each ext type is identified by a `(type_byte: Int8, data: Data)` pair. | **PARTIAL — same shape as CBOR tags**. Would need an `extValue(type: Int8, data: Data)` container kind. Same cost as CBOR tags: leaks MessagePack-shape concerns into every encoder. |
| **XML attribute-vs-element** | XML's `<user name="alice">42</user>` vs `<user><name>alice</name><value>42</value></user>` distinguishes attribute (1-per-key) from element (n-per-key, ordered, mixed-content-capable). The choice is part of the XML semantic, not a stylistic detail. | **NO — categorically distinct from key-value formats**. JSON / CBOR / MessagePack / plist all use unordered key-value maps. XML's attribute-vs-element split has no analog. kotlinx.serialization handles this via `@XmlElement` / `@XmlAttribute` — per-format annotations again. |

**Cross-cutting evidence the fresh-view cited**:

- Codable snake_case ambiguity ([t/69542](https://forums.swift.org/t/future-of-codable-and-json-coders-in-swift-6-hoping-for-a-rework/69542)): *"2 different names can have the same snake_case representation, which can result in JSONDecoder not being able to decode what JSONEncoder has encoded."* The single Codable's keyEncodingStrategy can't disambiguate per-format — fragmentation is real.

- [serde-rs/serde#1556](https://github.com/serde-rs/serde/issues/1556) on PDF data-type loss in serde's fixed 29-type data model: the unified canonical *cannot* express PDF's full type system. The workaround is per-format "fake deserializer" boilerplate.

- Jackson's per-format annotation packages (`@JacksonXmlElementWrapper`,
  `@JsonAlias`, etc.) and kotlinx.serialization's per-format annotation
  namespaces (`@ProtoNumber`, `@JsonNames`, `@CborLabel`, `@XmlElement`)
  both demonstrate the same pattern: the canonical *de facto* fragments
  along format even when *de jure* it doesn't — because format-native
  concerns *must* be expressible somewhere, and if not at the protocol
  layer, then at the annotation layer.

#### Tipping-question answer

**No — a sufficiently-rich canonical container API cannot absorb every
format's native concerns without translation loss.** The evidence is
overwhelming and structural:

1. Two named concerns (protobuf field numbers, XML attribute-vs-element) are
   *categorically distinct* from key-value-map formats and have no canonical
   analog without distorting other formats.

2. Three named concerns (CBOR tags, MessagePack ext types, plist Data/Date
   types) can be absorbed only at the cost of leaking format-shape into the
   canonical — exactly the design failure SE-0166's `KeyedEncodingContainer`
   triad exhibits (JSON-shaped canonical), now reversed (any rich canonical
   becomes format-X-biased).

3. The one partial absorption (JSON null-vs-missing-key) imposes an
   asymmetric cost on every non-JSON encoder.

4. Empirically, every multi-format ecosystem with a unified canonical
   (Codable, serde, kotlinx) has *de facto* fragmented along format at some
   syntactic layer (Codable's `keyEncodingStrategy`; serde's per-format
   crates; kotlinx's per-format annotation namespaces). The protocol-layer
   absence of fragmentation does not mean the *system* doesn't fragment;
   it means the system fragments somewhere else.

**Implication for axis B**: the canonical CANNOT be a *rich primary surface*
(which is path (b)'s effective shape if the reframing is to mean anything).
The canonical must be either:

- A *narrow type-commitment surface* (path a) — reserved for spec-value
  types that genuinely have one inherent codec, where the canonical doesn't
  need to absorb format-native concerns because there is no "other format";
  OR

- A *thin floor* (path c's new peer) — explicitly carrying the minimum
  common shape, with per-format siblings ([FAM-010]) absorbing format-native
  concerns where the format owns them.

Path (b)'s reframing of the existing canonical to fallback semantics
without introducing a separate peer collapses the institute's *two existing
shapes* (canonical as type-commitment + sibling per-format) into one
muddled shape (canonical as floor *and* type-commitment, depending on
conformer) — the worst of both worlds.

### 5. Per-path mechanical analysis

#### Path (a) — Preserve [FAM-002] type-commitment

**Mechanics**: no changes. [FAM-002] remains "ONE inherent canonical codec
per spec-value type." [FAM-003]'s guarded-use rule continues scoping
conformance to types that genuinely have one. Class III stdlib pins
continue their Φ.3 removal path. The "gap" at consumer call sites for
non-spec-value types (Class II/wrapper-only paths or wrapper-promotion
under parent v1.1.0's path C from §9) remains a deliberate consumer
discipline.

**Conformer impact**:

| Class | Action under (a) |
|---|---|
| Class I (spec-value-type commitments) | Unchanged — already aligned |
| Class II (wrapper delegations) | Unchanged — already aligned |
| Class III (stdlib pins) | Continue Φ.3 removal |

**Migration cost**: zero (the operational state already matches the rule).

**Reversibility**: trivial — no new shape is introduced; future axis-B
reconsideration costs only a rule-version bump.

**Pros**:
- Zero implementation cost.
- Matches operational reality exactly.
- Preserves the institute's distinctive structural call against Codable's
  lockout: stdlib types stay free of canonical commitments by design.
- The "gap" the parent v1.1.0 § 9 documented (path B explicit conformance;
  path C wrapper promotion) remains a deliberate discipline rather than a
  bug.

**Cons**:
- The fresh-view's "consumer triage cost" critique persists: a consumer who
  wants a generic-canonical bound on stdlib types still faces the
  documented gap, with the workarounds (format-specific generic bounds,
  explicit conformance, wrapper promotion) being more verbose than a
  fallback-canonical-conformance.
- Apple's New Codable currency-type case (Range, CGRect) has no institute
  analog — the institute cannot use the same shape as Apple settles on for
  these types without authoring a new peer protocol.
- The structural distinction between "type-commitment" (institute's
  canonical) and "author-choice-with-fallback" (Apple's CommonCodable)
  remains a *positive* design decision but means the institute's
  vocabulary diverges from Foundation's eventual vocabulary, creating
  user-facing naming/concept friction at the ecosystem boundary.

#### Path (b) — Reframe canonical to author-choice-with-fallback

**Mechanics**: [FAM-002] rewritten. The canonical's semantic becomes "this
type can be serialized to a minimum-common shape that any encoder driver
supports." [FAM-003]'s guarded-use rule is relaxed — conformance is no
longer reserved for spec-value types but available to any type with a
cross-format floor representation. The Class I conformers are re-interpreted
as either still type-commitments (with `RFC_8259.Value`'s spec identity
making it a degenerate case) OR as fallback conformances (semantically
muddled). Class III stdlib pins arguably become legitimate fallback
conformances, undoing the Φ.3 migration.

**Conformer impact**:

| Class | Action under (b) |
|---|---|
| Class I | Semantic re-read: from "type X HAS one inherent codec" to "type X can fall back to one shape." [FAM-003] justification template needs rewriting. RFC_8259.Value's justification (*"cannot meaningfully be encoded as anything other than its JSON representation"*) becomes inconsistent with the new semantic — it's not a fallback; it's THE representation. Either the conformer's justification is wrong under the new semantic, or the new semantic doesn't actually apply to RFC_8259.Value. |
| Class II (wrappers) | Semantically neutral — lifting works under either semantic. |
| Class III (stdlib pins) | The Φ.3 migration LOSES its structural argument. `Int`'s ASCII-decimal pin is now arguably a legitimate fallback ("Int can be serialized as ASCII-decimal across formats"). Removing it requires a new structural argument (substrate-friction? format-specificity?). |

**Migration cost**: substantial:

1. **[FAM-002] rewrite**: the rule statement, examples, and reasoning all
   need revision. Cross-references in [FAM-001] (which cites [FAM-002] as
   the structural enforcement of the no-associatedtype rule), [FAM-003]
   (guarded-use), [FAM-006] (refinement asymmetry's "attachment slots stay
   independent"), [FAM-009] (sibling placement's substrate logic), and
   [FAM-010] (parent v1.1.0's rule body) all interact with [FAM-002] and
   need re-reading for coherence.

2. **Class I justification rewrites**: each existing conformer's [FAM-003]
   justification comment was authored to express type-commitment. Under
   (b), each needs a new justification that expresses fallback semantics
   — which for spec-value types like RFC_8259.Value is a structurally
   awkward fit.

3. **Φ.3 re-litigation**: the in-flight stdlib-pin removal arc (per
   `swift-foundations/swift-ascii/Research/ascii-codable-unification.md`)
   has a structural argument grounded in [FAM-002]. Path (b) invalidates
   that argument; the arc either continues for non-[FAM-002] reasons
   (which need to be articulated) or stalls.

4. **Skill cascade**: family-codable-convention.md v1.1.4, 2026-05-15-
   family-codable-convention.md v1.0.0, sibling-refines-canonical-
   attachment.md v1.1.0, and any future skill that codifies the FAM
   catalog all reason about [FAM-002]'s commitment semantic. Each needs
   re-review for coherence with the new semantic.

5. **External naming alignment cost**: if the institute's canonical now
   carries author-choice-with-fallback semantics, the natural name is
   `Common.Codable` (or similar) — not `Codable`. Either the institute
   keeps `Codable` as the protocol name (semantically misleading — the
   stdlib `Codable` shadowed by it carries the OPPOSITE semantic) or
   renames to align with the new semantic (massive ecosystem-wide
   conformance-call-site rename).

**Reversibility**: hard — every Class I conformer's justification has been
rewritten; Φ.3 has been stalled or re-argued; downstream skill bodies have
been amended; the rule version has been bumped. Reverting requires
restoring all of those.

**Pros**:
- Aligns the institute's canonical with Apple's CommonCodable semantic
  directly (without authoring a new peer protocol).
- Closes the "gap" for stdlib types at the consumer call site without
  requiring per-call-site wrapper promotion.
- The semantic-rewrite would force a one-time discipline check across the
  FAM catalog that might surface other latent issues.

**Cons** (load-bearing):
- **Misreads Class I conformer identity**: RFC_8259.Value, Version.Semantic,
  etc., are not "fallback floors" — they are spec-value types whose
  representation IS the codec. Path (b) requires either rewriting their
  justifications to misdescribe them or accepting semantic muddle.
- **Re-legitimizes Class III pins**: the stdlib `Int` ASCII-decimal pin —
  the explicit motivator for the convention's design — becomes arguably a
  fallback. Either Φ.3 stalls or the convention develops a separate
  argument for removing it.
- **Cascading skill rewrites**: [FAM-002] is cited as foundational reasoning
  in [FAM-001], [FAM-003], [FAM-006], [FAM-009], [FAM-010]. Each cross-
  reference becomes a re-read.
- **Conflates two genuinely-distinct semantics**: the existing canonical
  CAN carry type-commitment semantics for spec-value types AND the
  ecosystem CAN benefit from a fallback-shape peer for currency types.
  These are different roles. Reframing one to be the other loses one.
- **Naming friction**: the existing canonical's name is `Codable` /
  `Parseable` / `Serializable`. Under (b), the natural name for the new
  semantic is `CommonCodable` (or similar). Keeping the existing names
  with the new semantic is misleading; renaming is a massive cost.

#### Path (c) — Introduce a thin `Common.Codable` analogue peer

**Mechanics**: [FAM-002] unchanged. The existing canonical attachment trio
(`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`,
`Serializer_Primitives_Core.Serializable`) retains its type-commitment
semantic. A new peer protocol (or family of three peer protocols) is
introduced: `Common.Codable` (or split: `Common.Parseable` +
`Common.Serializable`), carrying the author-choice-with-fallback semantic.
Both layers coexist; types choose which to conform to based on their
identity:

| Conformer identity | Conforms to | Reasoning |
|---|---|---|
| Spec-value type with one inherent canonical codec (RFC_8259.Value, Version.Semantic, etc.) | Existing canonical attachment ([FAM-002] semantic preserved) | Already does so today; no change |
| Currency type with no inherent canonical codec but a clean cross-format floor (Range, CGRect, UUID per Apple's framing) | New `Common.Codable` peer ([FAM-011] author-choice-with-fallback) | The gap the existing canonical leaves; addressed by the new peer |
| Stdlib type with multiple format-specific representations (Int, String, Optional, Array, Dictionary) | Per-format siblings ([FAM-010]); CAN optionally conform to `Common.Codable` for the cross-format fallback case | Sibling conformance remains the primary surface; common conformance is opt-in for consumers wanting the floor |
| Generic wrapper (Tagged, Optional) | Lifts the underlying's conformance (existing canonical OR new peer OR both) | Class II delegation pattern works under either canonical |

**Conformer impact**:

| Class | Action under (c) |
|---|---|
| Class I (spec-value-type commitments) | Unchanged — continue conforming to existing canonical |
| Class II (wrappers) | Optionally extend lifting to also cover the new peer (additive default extensions, no breaking change) |
| Class III (stdlib pins) | Continue Φ.3 removal — the new peer does NOT re-legitimize them (the new peer's semantic is "this type has a cross-format floor shape," and `Int`'s ASCII-decimal pin is not that — it's a format-specific representation pinned to canonical) |
| New: currency types (Range, CGRect, UUID, etc.) | Opt-in conformance to the new peer becomes possible |

**Migration cost**:

1. **Author the new peer protocol(s)**. Naming TBD per §6. Minimal new
   source code: one (or three split) protocol declarations + associated
   operational-layer linkage.

2. **Codify [FAM-011]** — the new rule expressing the peer's semantic and
   its non-refinement relationship with the existing canonical (per
   [FAM-006]) and per-format siblings (per [FAM-010]).

3. **Document the path-choice guidance** — when does a type author
   conform to the existing canonical vs the new peer vs both vs neither?
   (Existing canonical: spec-value type with one inherent codec; new peer:
   currency type with cross-format floor; sibling: format-specific
   expressiveness; lift: wrapper of any of the above.)

**Reversibility**: easy — if the new peer turns out to be premature, it
can be deprecated without disturbing the existing canonical or sibling
layers. The existing conformers continue to conform to their existing
attachments; no rewrite of justifications, no Φ.3 re-litigation.

**Pros**:
- **Preserves Class I conformer identity**: spec-value types continue to
  carry type-commitment semantics; their existing [FAM-003] justifications
  remain accurate.
- **Closes the non-spec-value-type gap additively**: currency types gain
  a cross-format fallback option without disturbing existing rules.
- **Aligns with Apple's New Codable architecturally**: the institute's
  shape matches Apple's CommonCodable + per-format siblings structure;
  ecosystem-boundary friction is minimized when Apple eventually ships.
- **Preserves Φ.3**: the stdlib pin removal continues with its [FAM-002]
  argument intact.
- **Composable with [FAM-010]**: per-format siblings remain peers of both
  canonical attachments; no refinement relationship; the anchor-merging
  trap stays closed.
- **Composable with [FAM-006]**: attachment protocols continue to stay
  flat at the attachment layer; the new peer doesn't refine the existing
  canonical.
- **Composable with [FAM-009]**: the new peer's [FAM-009] placement is
  governed by the existing rule — namespace-rooted, with substrate-
  friction exception. The "Common" namespace is naturally L1-rooted (no
  substrate boundary; the peer's surface is abstract container-API
  reach).

**Cons**:
- **Cumulative load**: the institute already has Codable + Parseable +
  Serializable + per-format siblings. Adding a fourth attachment-tier
  protocol family (3 more protocols if split decode/encode like the
  canonical trio) increases the surface that authors must triage. The
  fresh-view's @reviewer-c5 critique partially applies: "you've taken
  what was one annotation (Codable) and made it 6+ co-existing surfaces."
- **Naming question is open**: the institute uses `Codable` / `Parseable`
  / `Serializable` for type-commitment; the new peer needs a different
  prefix or namespace. `Common.Codable` is one option (mirrors Apple's
  `CommonCodable`); `Cross.Codable` is another (emphasizes cross-format);
  `Fallback.Codable` is a third (emphasizes the floor semantic).
- **Premature without consumer demand**: per [RES-027] loose-end
  follow-up, a new shape should be backed by either an extant experiment
  or an immediate experiment that would refute the framing. Today,
  no live institute consumer has surfaced a genuine currency-type need —
  Apple's framing motivates the design space but the institute's own
  consumer surface hasn't produced the empirical pull.

### 6. Path interactions with existing FAM rules

For path (c) — the recommended path — the interactions with existing FAM
rules are enumerated explicitly:

#### Interaction with [FAM-001] (no associatedtype on top-level siblings)

[FAM-001] forbids associated types on format-specific sibling protocols.
The new `Common.Codable` peer is NOT a format-specific sibling — it sits
at the canonical attachment tier alongside `Codable` / `Parseable` /
`Serializable`. [FAM-001] does not fire. The new peer MAY carry
`associatedtype` slots (`Coder` / `Parser` / `Serializer`) symmetric to the
existing canonical's slots — or it MAY be method-only with no associated
types (Apple's `CommonEncodable`-style abstract container surface). The
design choice is open and informed by what the peer's operational role
actually requires; both shapes are compatible with [FAM-001].

If the new peer carries `associatedtype` slots with the SAME NAMES as the
existing canonical (`Coder`, `Parser`, `Serializer`), the anchor-merging
mechanism would unify the slots on any type conforming to BOTH — which
prevents a type from carrying two different canonical codecs (its
type-committed one and its fallback one) at the type level. The
`@_implements` escape hatch per [BLOG-IDEA-031] handles the rare case
where this matters.

If the new peer is method-only (no associated types), the anchor-merging
trap doesn't fire at all — a type can freely carry both the existing
canonical commitment and the new peer's floor declaration. This is the
structurally cleaner default; the slot-bearing variant is reserved for
cases where the operational coupling is genuinely required.

**Recommendation within path (c)**: start with the **method-only shape** for
the new peer. The peer's role is to express "this type CAN be serialized
to a cross-format floor"; the actual coder/parser/serializer instances
remain attached via the existing canonical or per-format siblings.

#### Interaction with [FAM-002] (canonical = "ONE inherent codec")

[FAM-002] scopes the EXISTING canonical attachment. The new peer carries a
DIFFERENT semantic (author-choice-with-fallback). The two semantics
coexist because they apply to two different protocols. [FAM-002] is
extended by clarifying it applies *to the existing canonical only*; the
new peer's semantic is codified by the new [FAM-011] rule.

#### Interaction with [FAM-003] (guarded-use of canonical attachments)

[FAM-003] scopes the EXISTING canonical's conformance discipline. The new
peer's conformance has its own discipline ([FAM-011]) — conformance is
appropriate when the type has a cross-format floor representation but no
single inherent codec. The two disciplines coexist; conformers consult
the rule corresponding to the protocol they're conforming to.

#### Interaction with [FAM-004] (call-site disambiguation)

[FAM-004] codifies that consumers use format-specific instance accessors
(`u.json`, `u.bytes`) when multiple sibling conformances are in scope. The
new peer's call-site shape is symmetric to the existing canonical's
(`T.coder`, `T.serializer`, `T.parser` for the existing canonical; the
new peer's accessors are TBD — likely method-based per the recommendation
above). [FAM-004] applies to per-format siblings; it doesn't disturb the
new peer's call-site shape.

#### Interaction with [FAM-005] (siblings = format-level distinctions)

[FAM-005] scopes per-format siblings. The new peer is NOT a per-format
sibling — it sits at the canonical attachment tier. [FAM-005] doesn't
fire.

#### Interaction with [FAM-006] (refinement asymmetry)

[FAM-006] permits operational-layer refinement (`Coder.Protocol:
Parser.Protocol, Serializer.Protocol`) but FORBIDS attachment-layer
refinement (attachment protocols stay flat). The new peer is at the
attachment layer; per [FAM-006], it MUST NOT refine the existing canonical
(or vice versa). The two are peers. This is exactly Apple's "entirely
distinct from the format-agnostic one" framing applied symmetrically.

#### Interaction with [FAM-007] (sub-sibling carve-out)

[FAM-007] permits sub-siblings (refinements of a top-level sibling without
associated types) to carry domain-specific associated types. The new peer
is NOT a sub-sibling — it's a top-level attachment. [FAM-007] doesn't
fire.

#### Interaction with [FAM-008] (operational-layer family shape)

[FAM-008] codifies the operational-layer family shape (enum namespace +
nested Protocol + nested Witness + nested combinators). If the new peer
declares operational-layer linkage (associated types refining an
operational protocol), it follows [FAM-008]'s shape. If it's method-only
(per the §6 recommendation), [FAM-008] doesn't fire at the new peer's own
layer but governs any operational protocol the new peer's eventual
implementations rely on.

#### Interaction with [FAM-009] (sibling placement)

[FAM-009] places format-specific siblings — it doesn't directly fire on
the new peer. By analogy, the new peer's placement follows from:
- Its namespace root. If `Common.Codable`, the `Common` namespace's root.
- Its substrate. The new peer's required methods would operate on an
  abstract container API (no `Swift.String` substrate at the protocol
  level), so [PRIM-FOUND-004] does not gate it.

The natural placement is **L1 alongside the existing canonical attachment
trio** — a new `swift-common-codable-primitives` package (or symmetric
trio if split parser+serializer+codable) sibling to `swift-coder-primitives`,
`swift-parser-primitives`, `swift-serializer-primitives`. The
existing-canonical / new-peer relationship is layer-mirrored: both at L1,
neither refining the other.

#### Interaction with [FAM-010] (no sibling-refines-canonical)

[FAM-010] applies to per-format siblings. By extension to the new peer:
per-format siblings ALSO must not refine the new peer. The reasoning is
identical — anchor-merging trap, coherence concerns, format-specific
expressiveness incompatible with author-choice-with-fallback floor.

The composition: per-format siblings sit at peer rank with BOTH the
existing canonical AND the new peer. None of the three layers refines any
of the others. The institute's family-Codable architecture under path (c)
becomes a three-layer flat structure:

```
Per-format siblings  ([FAM-001], [FAM-010] — no refinement of either canonical tier)
        ↕ peers ↕
Existing canonical attachment  ([FAM-002] type-commitment)
        ↕ peers ↕
New Common.Codable peer  ([FAM-011] author-choice-with-fallback)
```

All three layers are independent; conformers freely conform to any
combination based on their identity.

### 7. The structural argument

Per [RES-022], structural correctness drives the recommendation; cost /
migration / pragmatism serves as tiebreaker only.

**The structural argument for path (c)**:

1. **Two distinct semantics exist and address two distinct conformer
   classes.** Spec-value types (RFC_8259.Value, Version.Semantic, etc.)
   carry ONE inherent canonical codec — type-commitment is their
   structural identity. Currency types (Range, CGRect, UUID per Apple's
   framing) carry a cross-format floor representation but no single
   inherent codec — author-choice-with-fallback is their structural
   identity. These are not the same semantic; collapsing them into one
   protocol (path b) creates muddle.

2. **The existing conformer reality is operationally Class I + Class II
   + Class III**, with Class III on the Φ.3 removal path. Class I is the
   load-bearing class; it carries type-commitment semantic explicitly via
   [FAM-003] justifications. Reframing the canonical to fallback semantic
   (path b) makes those justifications inaccurate. Preserving
   type-commitment (paths a and c) keeps them accurate.

3. **The tipping question (§4) settles the canonical's depth**. A rich
   canonical that absorbs every format's native concerns is structurally
   impossible without translation loss or format-shape leakage. The
   canonical must be either narrow type-commitment (a) or thin floor (c's
   peer) — not the rich primary surface that path b's reframing would
   functionally produce.

4. **Apple's New Codable empirically validates path (c)'s shape**. The
   prototype is structurally path (c): an additive format-agnostic
   protocol peer alongside format-specialized siblings. The institute's
   pre-existing canonical + per-format-sibling structure already matches
   the right half of Apple's shape; path (c) completes the left half with
   the new peer.

5. **Path (c) is the only path that preserves every existing FAM rule
   intact** while addressing the genuine non-spec-value-type gap. Paths
   (a) and (b) both have specific structural costs (the gap or the
   muddle); (c) trades the cumulative-load cost for clean composition.

**The structural argument against path (b) is decisive**: it misreads
Class I conformer identity, re-legitimizes Class III pins (undoing Φ.3),
forces cascading skill rewrites, and produces semantic muddle at exactly
the layer the convention's structural design was built to clarify.

**The structural argument against path (a) is partial**: (a) is
operationally correct today but leaves the currency-type gap unaddressed.
Apple's design space pressure (Range, CGRect, UUID need *something*) and
the institute's eventual need for currency-type cross-format interop will
re-litigate axis B in the future. (a) defers the question; (c) settles it.

**Decision under [RES-022] structural-correctness framing**: path (c) is
structurally correct; path (a) is structurally adjacent (defers an
acknowledged gap); path (b) is structurally defective.

### 8. Cognitive Dimensions analysis

Per [RES-025], applied to paths (a) and (c) — the two non-defective
candidates from §7. Reference: Green & Petre's *Cognitive Dimensions of
Notations*.

#### Visibility

**(a)**: HIGH for spec-value types (the canonical conformance is the
authoritative statement of "this type has one inherent codec"). MEDIUM for
the gap at non-spec-value-type consumer call sites — the gap is loud
(compile error), and the workarounds are documented per parent v1.1.0 §9,
but the consumer must know to look for them.

**(c)**: HIGH for spec-value types (unchanged from (a)). HIGH for currency
types (the new peer is the loud signal — "this type has a cross-format
floor"). The gap previously requiring workaround in (a) is closed for
genuinely-currency-type cases.

Verdict: (c) > (a).

#### Viscosity

**(a)**: LOW — no new shape to maintain; existing rules are stable.

**(c)**: MEDIUM — one new protocol family (or single protocol) to author
and maintain; FAM-rule additions; conformer-class triage rule documented.

Verdict: (a) > (c). The cumulative-load concern materializes as viscosity.

#### Role-expressiveness

**(a)**: HIGH for Class I (the canonical conformance reads as
type-commitment; the [FAM-003] justification reinforces it). LOW for
non-spec-value-type consumers (the absence of conformance is informative
only to readers who know [FAM-002]/[FAM-003] — to consumers who don't,
the gap looks like an oversight).

**(c)**: HIGH for Class I (unchanged). HIGH for currency types (the new
peer expresses their identity directly). MEDIUM for stdlib types — the
sibling conformances ([FAM-010] peer rank with both canonical attachments)
remain the primary surface; the new peer is opt-in for the floor case.

Verdict: (c) > (a). Adding a name for the currency-type case turns an
"absent gap" into an "explicit kind of conformance."

#### Error-proneness

**(a)**: LOW. The anchor-merging trap stays closed (the canonical's
associatedtype slot is reserved for spec-value commitment; non-spec-value
types decline conformance). No new failure modes.

**(c)**: LOW-MEDIUM. The anchor-merging trap stays closed if the new peer
is method-only (recommended per §6) — same shape as the existing
canonical's safety, just on a different protocol. If the new peer carries
associated types with the same names as the existing canonical (`Coder`,
`Parser`, `Serializer`), the trap re-fires for any type conforming to
both — handled via `@_implements` per [BLOG-IDEA-031], but adds per-
conformer cost. Method-only design (recommended) keeps error-proneness at
(a)'s level.

Verdict: (a) ≈ (c) under the recommended method-only design; (a) > (c)
if associated-type slot design is chosen.

#### Abstraction (right level)

**(a)**: MEDIUM. The canonical attachment expresses type-commitment; for
spec-value types this is the right level. For non-spec-value types
(currency types like Range, CGRect), the absence of a place to express
their cross-format floor identity is a missing abstraction at the
attachment layer.

**(c)**: HIGH. Each conformer class has a place to express its identity:
spec-value-type commitment via the existing canonical; currency-type
floor via the new peer; format-specific expressiveness via the sibling.
Three semantically-distinct slots; one per identity class. The
abstraction is at the right level for each.

Verdict: (c) > (a).

#### Cognitive-dimensions verdict

| Dimension | (a) | (c) | Winner |
|---|---|---|---|
| Visibility | medium (gap is loud but workaround discovery costs) | high (currency-type case has explicit signal) | (c) |
| Viscosity | low (no new shape) | medium (one new protocol family + rule) | (a) |
| Role-expressiveness | partial (Class I HIGH; gap CONFUSING) | high (every conformer class has explicit signal) | (c) |
| Error-proneness | low | low (under method-only design) | tie |
| Abstraction | partial (Class I right, gap missing) | high (every class at right level) | (c) |

(c) wins on 3 dimensions; (a) wins on 1 (viscosity); 1 tie. The viscosity
cost is real but is bounded by the **sanctioned-but-deferred** discipline
(see §9 recommendation).

### 9. Recommendation — Path (c) sanctioned-but-deferred

The structural and cognitive-dimensions arguments converge on path (c):
an additive `Common.Codable` peer alongside the existing canonical
attachment trio.

However, per [RES-027] loose-end follow-up, a new shape should not be
authored ahead of empirical pull. Today:

- No live institute consumer has surfaced a genuine currency-type need.
  The motivating use case (Range, CGRect, UUID cross-format interop) comes
  from Apple's framing of Foundation's eventual successor; the institute's
  own consumer surface has not produced parallel pressure.

- Apple's New Codable prototype is still in active design conversation
  (t/85186 last reply 2026-05-22; t/78585 last reply 2026-03-06); the
  formal Swift Evolution pitch has not landed; the exact naming
  (`CommonCodable` vs `CommonEncodable`/`CommonDecodable` split) and the
  richness of the format-agnostic surface (Data, Date strategies open per
  Perry t/85186) are not settled.

**Therefore the recommendation is path (c) — sanctioned-but-deferred**:

> **[FAM-011] An additive `Common.Codable` peer protocol is the
> architecturally correct shape for expressing the author-choice-with-
> fallback semantic alongside the existing canonical attachment trio.**
>
> The peer's role is to express *"this type has a cross-format floor
> representation"* for currency types (Range, CGRect, UUID, etc.) that
> have no single inherent canonical codec but do have a clean cross-
> format shape.
>
> The peer sits at peer rank with the existing canonical attachment
> trio (`Coder_Primitives.Codable`, `Parser_Primitives_Core.Parseable`,
> `Serializer_Primitives_Core.Serializable`) per [FAM-006] (attachment
> protocols stay flat) and at peer rank with per-format siblings per
> [FAM-010] (siblings do not refine the new peer; the new peer does not
> refine siblings).
>
> The peer's authoring is **deferred** until either:
>
> 1. An institute consumer surfaces a genuine currency-type need (a
>    type with no inherent canonical codec but a clean cross-format
>    floor representation that the existing canonical + sibling
>    composition does not adequately express).
> 2. Apple's New Codable proposal reaches a formal Swift Evolution
>    pitch (currently discussion phase as of 2026-05-22), at which
>    point the institute's peer's naming and semantic alignment can
>    track the formal pitch.
>
> In the interim, the existing canonical attachment trio ([FAM-002]
> type-commitment) retains its semantic UNCHANGED; the gap for non-
> spec-value types remains intentional per parent v1.1.0 §9's documented
> consumer alternatives (format-specific generic bounds, explicit
> canonical conformance with [FAM-003] justification, or Option W
> wrapper promotion).

**[FAM-011]** is the proposed rule codifying path (c). Pending principal
authorization, this Research arc publishes [FAM-011] as RECOMMENDATION and
the rule is immediately applicable as a *design-space reservation*: future
discussions of "should X conform to canonical?" can route currency-type
candidates to "this is the case [FAM-011] reserves; defer authoring until
trigger fires."

#### Why sanctioned-but-deferred rather than authored-immediately

1. **No empirical pull yet**: per [RES-027], a premise that no consumer
   demand exists should not commit the convention to a new shape ahead of
   evidence. Authoring `Common.Codable` today would be designing for a
   hypothetical consumer.

2. **Apple's design alignment cost**: if the institute authors a peer
   protocol with `Common.Codable` naming and Apple ships a formal pitch
   with different naming (e.g., the split `CommonEncodable` /
   `CommonDecodable` per the prototype), the institute either renames or
   accepts ecosystem-boundary friction. Waiting for Apple's formal pitch
   lets the institute match without re-litigating.

3. **The viscosity cost is real**: per §8, the cumulative load of a
   fourth attachment-tier protocol family is the one cognitive-dimension
   where (c) loses to (a). Deferring authoring bounds the viscosity to a
   *rule reservation* (low cost) rather than a *protocol family
   addition* (medium cost).

4. **Reversibility is preserved**: the rule reservation is trivially
   removable if axis B's resolution turns out to be different. Authored
   protocols, once shipped, are harder to retract.

#### Trigger conditions (explicit, per [RES-027])

The deferral remains in force until **any one** of the following fires:

1. An institute consumer authors a type with no inherent canonical codec
   but a clean cross-format floor representation, and surfaces friction
   from the absence of `Common.Codable`. The friction must be empirical
   (a use case demonstrating that the existing canonical + sibling
   composition does not adequately express the type's identity), not
   hypothetical.

2. Apple's New Codable proposal reaches a formal Swift Evolution pitch
   on swift-evolution. At that point the institute's `Common.Codable`
   peer's naming and surface align with the formal pitch.

3. The institute's `swift-arguments` ecosystem (per
   `2026-05-15-swift-arguments-ecosystem-design.md`) or another L3 codec
   ecosystem surfaces a consumer-driven request for a cross-format
   floor protocol. The argument-parser arc's currency-type cases
   (`Argument.Codable` for `Int`, `String`, `Bool`, etc.) are
   substrate-friction-driven L3 conformances per [FAM-009]; they are
   structurally distinct from the [FAM-011] case (Apple's
   `Common.Codable` is layer-agnostic, not L3-bound).

**On trigger**: spin up a follow-on Tier 2 ecosystem-wide investigation
arc to (a) finalize the peer's naming, (b) decide method-only vs
associated-type-bearing surface, (c) author the protocol, (d) document
the cross-conformer interaction patterns, and (e) update [FAM-011] from
RECOMMENDATION to DECISION status.

#### Concrete decisions today

1. **No source code changes**. The existing canonical attachment trio
   continues unchanged; no new protocol is authored.

2. **[FAM-002] is unchanged**. The existing canonical's type-commitment
   semantic stays intact; the residual stdlib pins (Class III) continue
   their Φ.3 removal path.

3. **[FAM-011] is reserved as a RECOMMENDATION**. Future discussions of
   "should X conform to canonical?" route currency-type candidates to
   "deferred under [FAM-011] pending trigger."

4. **Parent v1.1.0's axis B disposition updates** from
   `DEFERRED-PENDING-SUCCESSOR-ARC` to `RESOLVED-VIA-PATH-(c)-DEFERRED`,
   with this doc cited as the resolution.

### 10. Migration analysis under path (c)

Per the brief's required migration analysis dimension:

#### Which conformers change?

**None today**. Path (c) is sanctioned-but-deferred; no protocol is
authored, so no conformer changes.

**Eventually (on trigger)**: when the peer is authored, the conformer
impact is:

| Class | Action |
|---|---|
| Class I (spec-value-type commitments) | Unchanged. Continue conforming to existing canonical. |
| Class II (wrappers) | OPTIONALLY extend to lift the new peer via default extensions (additive; no breaking change). |
| Class III (stdlib pins) | Continue Φ.3 removal. The new peer does NOT re-legitimize these pins; `Int`'s ASCII-decimal pin is not a cross-format floor (it's a format-specific representation pinned at the canonical layer). |
| New: currency types | OPTIONALLY conform to the new peer. Adoption is opt-in per author. |
| Per-format siblings | Unchanged. Continue per-format expressiveness via [FAM-010] peer rank with both canonical attachments. |

#### [FAM-002]/[FAM-003] rewrite cost

**Zero** under path (c) — [FAM-002] and [FAM-003] are unchanged; the new
[FAM-011] rule adds the peer's semantic statement without modifying any
existing rule.

#### Composition of the new protocol with existing rules

Per §6: the new peer composes additively with [FAM-001] (method-only
shape recommended; trap cannot fire), [FAM-002] (existing canonical
unchanged; new peer's semantic is distinct), [FAM-003] (existing guarded-
use applies to existing canonical only; new peer has its own discipline
per [FAM-011]), [FAM-004]–[FAM-008] (per-format siblings unchanged),
[FAM-009] (new peer's placement L1 alongside existing canonical), and
[FAM-010] (per-format siblings do not refine new peer).

#### Naming question (deferred)

The new peer's exact name is deferred until trigger condition 2 (Apple's
formal pitch) or independent institute decision. Working name in this
doc: `Common.Codable`. Alternatives:

- **`Common.Codable`** — mirrors Apple's CommonCodable directly. Reads
  naturally; minimal ecosystem-boundary friction when Apple ships.
- **`Cross.Codable`** — emphasizes cross-format reach. Distances from
  Apple's specific naming.
- **`Fallback.Codable`** — emphasizes floor semantic. May read as
  pejorative (fallback implies "less preferred").

The naming question is left open per trigger condition 2.

#### Layer placement (per [FAM-009])

The new peer's namespace `Common` (or alternative) is rooted at L1
alongside the existing canonical's `Coder` / `Parser` / `Serializer`
namespaces. No substrate-friction exception fires ([PRIM-FOUND-004] does
not gate the new peer's surface, which is abstract container-API reach
without `Swift.String` substrate). Per [FAM-009] default, namespace-rooted
placement at L1 applies.

Concretely, on trigger, a new `swift-common-codable-primitives` package
(or symmetric trio if split parser+serializer+codable) is added to
swift-primitives, sibling to swift-coder-primitives,
swift-parser-primitives, swift-serializer-primitives. The existing-
canonical / new-peer relationship is layer-mirrored: both at L1, neither
refining the other.

### 11. Loose ends (per [RES-027])

#### Premise items (require empirical backing)

None. The recommendation is structurally derived; no premise about external
state is asserted that would benefit from a verification spike at this
revision. The deferral discipline itself ([FAM-011] sanctioned-but-deferred)
is the mechanism by which any future empirical premise (trigger condition
1's "consumer surfaces friction") gets surfaced explicitly.

#### Direction items (deferred, not load-bearing)

1. **Naming the new peer**. Deferred until trigger condition 2 (Apple's
   formal pitch) or independent institute decision. Working names listed
   in §10.

2. **Method-only vs associated-type-bearing surface**. Recommended in §6
   as method-only for the default case; final decision deferred to the
   trigger-time follow-on arc.

3. **Split vs unified shape**. Apple's prototype splits into
   `CommonEncodable` + `CommonDecodable`; the institute's existing
   canonical also splits (`Parseable` + `Serializable`) with a
   bidirectional `Codable` peer. The new peer's shape under (c) is
   open: single `Common.Codable` (simplest), or split `Common.Parseable`
   + `Common.Serializable` with bidirectional `Common.Codable` peer
   (symmetric to the existing canonical trio). Defer to trigger.

4. **Stdlib type opt-in policy**. When the peer is authored, should
   stdlib types like `Int`, `String`, `Optional`, `Array`, `Dictionary`
   opt into `Common.Codable`? Per the tipping question, the stdlib's
   stdlib-Codable conformance already pins to existential-Codable shape
   that institute's existing convention rejects per [FAM-002]; the
   institute's stdlib conformances are via per-format siblings
   ([FAM-010]). Whether to ALSO add `Common.Codable` conformance to
   stdlib types is a separate decision deferred to trigger.

5. **Skill-promotion of [FAM-011]**. Per [RES-006a], [FAM-011] is a
   candidate for promotion to the eventual ecosystem-wide
   family-codable-convention skill. Deferred per the skill-lifecycle
   process. [FAM-011] is the fourth FAM-rule (after [FAM-009] in
   `2026-05-15-family-codable-convention.md` and [FAM-010] in parent
   v1.1.0 of `sibling-refines-canonical-attachment.md`) to live
   exclusively in research notes; cumulative load argues for eventual
   consolidation into a single ecosystem-wide doc + skill.

6. **Cross-monitor Apple's New Codable**. When Apple's proposal reaches
   a formal swift-evolution pitch, the institute SHOULD re-audit
   [FAM-011] against the formal-pitch shape. If Apple's `CommonCodable`
   is positioned such that per-format protocols *do* refine it
   contrary to the prototype's "entirely distinct" framing, the
   institute's [FAM-010] (axis A; siblings don't refine canonical) may
   need a contrasting-design amendment, and [FAM-011]'s peer-relation
   discipline may need re-statement. Current expectation: Apple's
   siblings will remain peers (per the prototype's framing through
   2026-05-22), but the pitch's formal text governs.

7. **The institute's existing `JSON.Serializable` etc. siblings'
   relationship to the new peer**. Once the new peer is authored, do
   per-format siblings automatically have any structural relationship
   to it? Per §6, NO — siblings are peers of both canonical attachments
   under [FAM-010]'s extension. But this composition deserves explicit
   codification at trigger time.

---

## Outcome

**Status**: RECOMMENDATION (initial publication; ready for promotion to
skill on principal authorization).

### Conclusion

Path (c) — additive `Common.Codable` peer alongside the existing canonical
attachment trio — is the architecturally correct resolution of axis B. The
peer's role is to express author-choice-with-fallback semantics for
currency types (Range, CGRect, UUID, etc.) that have no single inherent
canonical codec but do have a clean cross-format floor representation.
The existing canonical attachment trio retains its type-commitment
semantic ([FAM-002] unchanged); the per-format sibling layer continues
per [FAM-010]; the new peer composes additively per [FAM-006]
(attachment-layer flatness preserved) and per [FAM-010]'s extension to
the new peer (siblings remain peers of both canonical attachments;
neither refines either).

The peer's authoring is **deferred** until empirical pull surfaces — either
an institute consumer's currency-type need or Apple's New Codable proposal
reaching a formal Swift Evolution pitch. In the interim, [FAM-011] is a
**rule reservation** rather than an authored protocol family.

### The tipping question, settled

The fresh-view's tipping question (*can a sufficiently-rich canonical
container API absorb every format's native concerns without translation
loss?*) is answered **NO** per §4's concrete enumeration:

| Format-native concern | Absorbable? |
|---|---|
| CBOR tags | Partial — at the cost of leaking CBOR-shape into the canonical |
| Protobuf field numbers | NO — categorically distinct from key-value formats |
| Plist Data/Date types | NO — JSON has no `Data` or `Date` analog |
| JSON null-vs-missing-key | Partial — at the cost of every non-JSON encoder |
| MessagePack ext types | Partial — same shape as CBOR tags |
| XML attribute-vs-element | NO — categorically distinct from key-value formats |

This empirical answer implies the canonical CANNOT be a rich primary
surface (which is path (b)'s effective shape). The canonical must be
either narrow type-commitment (a) or thin floor (c's new peer) — not the
rich primary surface that path (b) would functionally require.

### Concrete decisions

1. **Path (c) is the recommended resolution of axis B**. The existing
   canonical attachment trio retains [FAM-002] type-commitment semantic
   unchanged; an additive `Common.Codable` peer is reserved for the
   author-choice-with-fallback case (currency types).

2. **No source code changes today**. The new peer is sanctioned-but-
   deferred. Existing conformers (Class I + Class II + Class III) are
   unchanged. The Φ.3 stdlib-pin removal continues.

3. **[FAM-011] is published as RECOMMENDATION** — the rule reserving
   path (c) and codifying its discipline.

4. **Parent v1.1.0's axis-B Disposition updates** from
   `DEFERRED-PENDING-SUCCESSOR-ARC` to `RESOLVED-VIA-PATH-(c)-DEFERRED`,
   with this doc cited as the resolution. The amendment to the parent
   doc is v1.2.0.

### Next steps

1. **Principal review of this RECOMMENDATION**. On acceptance, [FAM-011]
   is reserved as a sanctioned-but-deferred rule; no protocol is
   authored.

2. **Apple New Codable cross-monitoring**. When the prototype reaches a
   formal swift-evolution pitch, re-audit [FAM-011] against the formal
   pitch per §11 direction item 6. Re-evaluate trigger condition 2.

3. **Consumer-driven re-evaluation**. If an institute consumer surfaces
   a genuine currency-type need (trigger condition 1), spin up a
   follow-on Tier 2 ecosystem-wide arc to finalize the peer's
   naming/surface/placement and author the protocol family.

4. **Skill-promotion alongside [FAM-009] + [FAM-010]**. Per [RES-006a],
   [FAM-011] is a candidate for inclusion in the eventual ecosystem-wide
   family-codable-convention skill alongside [FAM-009] (sibling
   placement) and [FAM-010] (no sibling-refines-canonical). Deferred to
   skill-lifecycle process.

### Cross-references

- Parent investigation (this arc resolves its open question):
  `swift-institute/Research/sibling-refines-canonical-attachment.md`
  v1.1.0 §10a — axis B deferred to this arc; v1.2.0 amendment will cite
  this doc and update Disposition.
- Fresh-view outside-view findings (38-system survey + forums-review
  simulation + Phase 2 synthesis): `HANDOFF-multi-format-serialization-fresh-review.md`
  Findings section — input to this arc per parent v1.1.0; cited freely
  but not modified.
- Per-package convention codifying [FAM-001]–[FAM-008]:
  `swift-foundations/swift-json/Research/family-codable-convention.md`
  v1.1.4.
- Ecosystem-wide [FAM-009] sibling placement:
  `swift-institute/Research/2026-05-15-family-codable-convention.md`
  v1.0.0.
- Multi-format readiness audit (CROSS-1 canonical-attachment
  associated-type latent risk):
  `swift-foundations/swift-json/Research/multi-format-codable-readiness.md`
  v1.0.0.
- Associated-type-trap mechanism (load-bearing for the §6 method-only
  shape recommendation):
  `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md`
  ([BLOG-IDEA-031]).
- Primitives substrate-friction rule (informs [FAM-009] placement of
  the eventual peer):
  `swift-institute/Skills/primitives/SKILL.md` [PRIM-FOUND-004].

## References

### Internal (primary)

- `swift-institute/Research/sibling-refines-canonical-attachment.md` v1.1.0 — parent investigation; §10a defines axis B + three resolution paths
- `swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4 — [FAM-001]–[FAM-008]
- `swift-institute/Research/2026-05-15-family-codable-convention.md` v1.0.0 — [FAM-009] sibling placement
- `swift-foundations/swift-json/Research/multi-format-codable-readiness.md` v1.0.0 — CROSS-1 canonical-attachment associated-type latent risk + 36-system competitive context
- `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` ([BLOG-IDEA-031]) — anchor-merging language mechanism + `@_implements` escape hatch
- `HANDOFF-multi-format-serialization-fresh-review.md` Findings section — 38-system external survey + forums-review simulation + Phase 2 independent synthesis (used as input per parent v1.1.0; cited freely, not modified)
- `HANDOFF-canonical-semantic-axis-b.md` — the branching brief that authorized this investigation

### Empirical anchors (verified file:line at write time per [RES-023])

#### Canonical attachment protocol declarations

- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:29–35` — canonical `Codable` with `associatedtype Coder`
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:26–32` — canonical `Parseable` with `associatedtype Parser`
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19–25` — canonical `Serializable` with `associatedtype Serializer`

#### Class I — Spec-value-type commitments

- `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:125` — `RFC_8259.Value: @retroactive Coder_Primitives.Codable` with [FAM-003] justification
- `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Semantic+Parseable.swift:16` — `Version.Semantic: Parseable` (SemVer 2.0.0 spec)
- `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Tools+Parseable.swift:16` — `Version.Tools: Parseable` (SE-0152 spec)
- `swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Calendar+Parseable.swift:16` — `Version.Calendar: Parseable` (CalVer spec)
- `swift-primitives/swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern+Parseable.swift:16` — `Glob.Pattern: Parseable` (glob spec)

#### Class II — Generic-instantiated delegations

- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Tagged+Parseable.swift:43` — `Tagged: Parseable where Underlying: Parseable, ...`
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Tagged+Serializable.swift:44` — `Tagged: Serializable where Underlying: Serializable, ...`
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Standard Library Integration/Optional+Serializable.swift:21` — `Swift.Optional: Serializable where Wrapped: Serializable`

#### Class III — Legacy stdlib pins (RECOMMENDED-FOR-MIGRATION per Φ.3)

- `swift-primitives/swift-ascii-serializer-primitives/Sources/Serializable Integer Primitives/FixedWidthInteger+Serializable.swift:8–44` — 10 stdlib integer pins to canonical `Serializable`
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift:11+` — 10 stdlib integer pins to canonical `Parseable`
- `swift-foundations/swift-ascii/Research/ascii-codable-unification.md` Φ.3 — migration arc removing the above pins

### External (per [RES-021] contextualization; per [RES-031] verified at write time)

- [Apple/Foundation Codable-successor proposal](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585) — Kevin Perry, 2025-03-17 → 2026-03-06 (178 posts as of 2026-05-22); per-format specialized + format-agnostic peer protocols; verbatim Perry quote (opening post): *"these format-specialized protocols are expected to be entirely distinct from the format-agnostic one, but they should share the same basic structure and patterns."*
- [New Codable prototype available for feedback](https://forums.swift.org/t/new-codable-prototype-available-for-feedback/85186) — Kevin Perry, opened 2025-08-XX → 2026-05-22 (71 posts as of 2026-05-22; active); names `CommonEncodable`/`CommonDecodable` + `JSONEncodable`/`JSONDecodable` siblings; reports ~6× throughput improvement via per-format specialization; Data/Date strategies remain open design questions per Perry
- [Codable v6 pain catalog](https://forums.swift.org/t/future-of-codable-and-json-coders-in-swift-6-hoping-for-a-rework/69542) — community thread documenting Codable's snake_case ambiguity, null-vs-missing-key collapse, Sendable conformance limitations
- [SE-0166: Swift Archival & Serialization](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0166-swift-archival-serialization.md) — single canonical Codable, format-driver dispatch (the lockout the institute's convention explicitly rejects per [FAM-002] / [FAM-010])
- [Rust serde](https://serde.rs/) — single `Serialize` / `Deserialize` traits with format-driver dispatch; cited in §6.4 of FAM-009 doc for the contextualization step
- [serde-rs/serde issue #1556](https://github.com/serde-rs/serde/issues/1556) — PDF data-type loss in the fixed 29-type data model; cited in §4 as evidence that even rich canonicals have fixed expressive limits
- [kotlinx.serialization KEEP](https://github.com/Kotlin/KEEP/blob/master/proposals/extensions/serialization.md) — per-format annotation namespaces (`@ProtoNumber`, `@JsonNames`, `@CborLabel`); cited in §4 as evidence of de-facto format-layer fragmentation

### Theoretical anchors (per [RES-022])

- Bottu et al. (2019), *Coherence of Type Class Resolution*, arXiv:1907.00844 — coherence-theoretic argument against refinement-based type-class hierarchies (cited by parent v1.1.0 as reinforcing [FAM-010] axis A)
- Racordon (2025), arXiv:2502.20546 — type-class coherence in modern type systems (cited by parent v1.1.0 in the same context)
- ezyang (2014), *Type Classes: Confluence, Coherence, Global Uniqueness*, http://blog.ezyang.com/2014/07/type-classes-confluence-coherence-global-uniqueness/ — accessible exposition of the coherence concerns

### Process anchors

- [RES-002a] Research triage — ecosystem-wide scope per [META-005]
- [RES-003] Document structure
- [RES-003c] Research index entry per `_index.json`
- [RES-006a] Documentation promotion — research findings to skill
- [RES-013a] Synthesis verification — carry-forward claims verified
- [RES-019] Internal grep — applied at write time
- [RES-020] Tier classification — Tier 2 (cross-package, reversible, codifies an additive design-space reservation)
- [RES-021] Prior art contextualization — applied via parent v1.1.0's 38-system survey
- [RES-022] Structural correctness framing — applied in §7
- [RES-023] Empirical claim verification — applied to every file:line citation in §1
- [RES-025] Cognitive Dimensions analysis — applied in §8
- [RES-027] Loose-end follow-up — §11 distinguishes premise items (none) from direction items (six deferred)
- [RES-029] Framing-challenge for binding/placement questions — axis B framed as semantic identity, not cost-ranking
- [RES-031] Independent verification of version-pinned claims — applied to Apple New Codable thread quotes in §3
- [HANDOFF-013a] Writer-side prior-research grep — applied to swift-institute, swift-foundations/swift-json, each L1 primitives Research/
- [HANDOFF-021] Scope enumeration at write time — applied to §1 inventory
- [HANDOFF-040] Generic-instantiated forms — applied to Tagged + Optional inclusion in §1
